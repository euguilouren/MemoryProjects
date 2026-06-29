#!/usr/bin/env bash
# Rede de seguranca do gerador de entregaveis. Valida OFFLINE o que der (sem
# rede, sem instalar nada) e, SE as libs existirem, faz um render de fumaca.
# Tolerante a falha: avisa e pula o que depende de dependencia/rede, sem
# derrubar. Idempotente. E o gate que o revisor-de-codigo roda antes/depois.
#
# Uso:  bash entregaveis/check.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log()  { printf '\033[36m[entregaveis:check]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[entregaveis:check] %s\033[0m\n' "$*"; }
falhou=0

if ! command -v python3 >/dev/null 2>&1; then
  warn "python3 ausente. Pulado."
  exit 0
fi

# 0) Lint (ruff): gate de estilo. Config versionada em pyproject.toml. No CI
#    (requirements instala ruff) e' gate de verdade; local degrada se ausente.
log "0/8 Lint (ruff)..."
if command -v ruff >/dev/null 2>&1 || python3 -m ruff --version >/dev/null 2>&1; then
  ruff_cmd() { if command -v ruff >/dev/null 2>&1; then ruff "$@"; else python3 -m ruff "$@"; fi; }
  if ruff_cmd check "$DIR"; then
    log "  OK: ruff sem violacoes."
  else
    warn "  FALHA: ruff encontrou violacoes de lint."
    falhou=1
  fi
else
  warn "  ruff ausente — lint pulado (instale: pip install -r requirements.txt)."
fi

# 1) Sintaxe do gerar.py (compila sem executar).
log "1/8 Compilando gerar.py (py_compile)..."
if python3 -m py_compile "$DIR/gerar.py"; then
  log "  OK: gerar.py sem erro de sintaxe."
else
  warn "  FALHA: erro de sintaxe em gerar.py."
  falhou=1
fi

# 2) tokens.json valido (JSON bem-formado).
log "2/8 Validando tokens.json..."
if python3 -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "$DIR/marca/tokens.json"; then
  log "  OK: tokens.json valido."
else
  warn "  FALHA: tokens.json invalido."
  falhou=1
fi

# 3) Dados de exemplo validos (deck.json e front-matter do relatorio.md).
log "3/8 Validando dados de exemplo..."
if python3 -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "$DIR/exemplos/deck.json"; then
  log "  OK: exemplos/deck.json valido."
else
  warn "  FALHA: exemplos/deck.json invalido."
  falhou=1
fi
if [ -f "$DIR/exemplos/relatorio.md" ]; then
  log "  OK: exemplos/relatorio.md presente."
else
  warn "  FALHA: exemplos/relatorio.md ausente."
  falhou=1
fi

# 4) HTML/CSS bem-formados (parse XML tolerante via stdlib; nao exige libs externas).
log "4/8 Checando templates e CSS..."
python3 - "$DIR" <<'PY'
import sys, re
from pathlib import Path
from html.parser import HTMLParser

raiz = Path(sys.argv[1])
problemas = 0

class _P(HTMLParser):
    """Parser tolerante: so confirma que o HTMLParser percorre o arquivo sem
    estourar. HTML real (com <!DOCTYPE>, atributos Jinja) nao e XML estrito,
    entao validamos parseabilidade, nao conformidade XML."""
    def error(self, message):  # py<3.5 compat; nao usado em 3.x
        raise RuntimeError(message)

for html in (raiz / "templates").glob("*.html"):
    try:
        _P().feed(html.read_text(encoding="utf-8"))
        print(f"  OK: {html.name} parseavel.")
    except Exception as e:  # noqa: BLE001 - queremos reportar qualquer falha
        print(f"  FALHA: {html.name}: {e}")
        problemas += 1

# CSS: checagem leve de chaves balanceadas (rede de seguranca, nao um parser CSS).
for css in list((raiz / "templates").glob("*.css")) + [raiz / "marca" / "tokens.css"]:
    txt = css.read_text(encoding="utf-8")
    sem_comentarios = re.sub(r"/\*.*?\*/", "", txt, flags=re.DOTALL)
    if sem_comentarios.count("{") == sem_comentarios.count("}"):
        print(f"  OK: {css.name} com chaves balanceadas.")
    else:
        print(f"  FALHA: {css.name}: chaves {{}} desbalanceadas.")
        problemas += 1

sys.exit(1 if problemas else 0)
PY
if [ $? -ne 0 ]; then falhou=1; fi

# 1b) Sintaxe do gerar-pptx.py (caminho PPTX, aditivo ao PDF).
log "1b/8 Compilando gerar-pptx.py (py_compile)..."
if python3 -m py_compile "$DIR/gerar-pptx.py"; then
  log "  OK: gerar-pptx.py sem erro de sintaxe."
else
  warn "  FALHA: erro de sintaxe em gerar-pptx.py."
  falhou=1
fi

# 1c) Sintaxe do gerar-web.py (caminho WEB/reveal.js, aditivo ao PDF/PPTX).
log "1c/8 Compilando gerar-web.py (py_compile)..."
if python3 -m py_compile "$DIR/gerar-web.py"; then
  log "  OK: gerar-web.py sem erro de sintaxe."
else
  warn "  FALHA: erro de sintaxe em gerar-web.py."
  falhou=1
fi

# 5) Render de fumaca - SO se as libs existirem (degrada com aviso).
log "5/8 Render de fumaca PDF (se as libs existirem)..."
if python3 -c "import jinja2, weasyprint" >/dev/null 2>&1; then
  if ( cd "$DIR" && python3 gerar.py demo ); then
    log "  OK: relatorio e deck renderizados em saida/."
  else
    warn "  FALHA: render de fumaca quebrou."
    falhou=1
  fi
elif python3 -c "import jinja2" >/dev/null 2>&1; then
  warn "  WeasyPrint ausente: gera HTML intermediario, nao PDF. Validando o HTML..."
  if ( cd "$DIR" && python3 gerar.py demo ); then
    log "  OK: HTML intermediario gerado (PDF pulado por falta de WeasyPrint)."
  else
    warn "  FALHA: montagem do HTML quebrou."
    falhou=1
  fi
else
  warn "  jinja2/weasyprint ausentes. Render pulado (instale requirements.txt para o PDF)."
fi

# 6) Smoke do PPTX NATIVO - SO se python-pptx existir (degrada sem quebrar).
#    Gera o .pptx do exemplo, REABRE com python-pptx e confere: N slides, e que
#    o slide do grafico tem um CHART NATIVO (nao imagem) com eixo de valor min=0.
log "6/8 Smoke do PPTX nativo (se python-pptx existir)..."
if python3 -c "import pptx" >/dev/null 2>&1; then
  if ( cd "$DIR" && python3 gerar-pptx.py >/dev/null ) && python3 - "$DIR" <<'PY'
import sys
from pathlib import Path
from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE_TYPE

saida = Path(sys.argv[1]) / "saida" / "deck.pptx"
pres = Presentation(str(saida))
slides = list(pres.slides)
if len(slides) < 2:
    print(f"  FALHA: deck com {len(slides)} slides (esperado >= 2).")
    sys.exit(1)

# Chart do tipo grafico deve ser NATIVO (GraphicFrame com chart), nao imagem.
charts = [sh for s in slides for sh in s.shapes if sh.has_chart]
if not charts:
    print("  FALHA: nenhum chart nativo (o grafico virou imagem?).")
    sys.exit(1)
imgs = [sh for s in slides for sh in s.shapes
        if sh.shape_type == MSO_SHAPE_TYPE.PICTURE]
if imgs:
    print(f"  FALHA: {len(imgs)} imagem(ns) no deck - deveria ser tudo nativo.")
    sys.exit(1)

va = charts[0].chart.value_axis
if va.minimum_scale not in (0, 0.0):
    print(f"  FALHA: eixo de valor min={va.minimum_scale} (regua: deve ser 0).")
    sys.exit(1)

print(f"  OK: {len(slides)} slides; chart NATIVO com eixo min=0; 0 imagens.")
PY
  then
    log "  OK: PPTX gerado e reaberto - slides + chart nativo (min=0) conferidos."
  else
    warn "  FALHA: smoke do PPTX quebrou."
    falhou=1
  fi
else
  warn "  python-pptx ausente. Smoke do PPTX pulado (pip install -r requirements.txt)."
fi

# 7) Smoke do deck WEB (reveal.js) - SEM dependencia externa (so stdlib), entao
#    roda SEMPRE. Gera o .html do exemplo, REABRE e confere: parseavel (HTML bem
#    -formado), 0 byte de controle (NUL quebra o site - licao do portal), N
#    <section> esperados (capa + slides), e a HONESTIDADE do grafico no DOM
#    gerado: rotulo de valor em cada barra, a barra de maior valor NAO toca o topo
#    quando `maximo` > maior valor, e a cor (destaque ambar) isolada a 1 barra.
log "7/8 Smoke do deck WEB (reveal.js, sem libs externas)..."
if ( cd "$DIR" && python3 gerar-web.py >/dev/null ) && python3 - "$DIR" <<'PY'
import re, sys
from pathlib import Path
from html.parser import HTMLParser

raiz = Path(sys.argv[1])
saida = raiz / "saida" / "deck.html"
deck = __import__("json").loads((raiz / "exemplos" / "deck.json").read_text(encoding="utf-8"))
n_slides_esperado = len(deck.get("slides", [])) + 1  # +1 = capa

h = saida.read_text(encoding="utf-8")

# 0 byte de controle (NUL): a licao do portal - NUL quebra o site servido.
if "\x00" in h:
    print("  FALHA: HTML contem byte NUL (quebraria o site).")
    sys.exit(1)

# HTML bem-formado: o HTMLParser percorre sem estourar.
class _P(HTMLParser):
    def __init__(self): super().__init__(); self.sec = 0
    def handle_starttag(self, t, a):
        if t == "section": self.sec += 1
p = _P()
try:
    p.feed(h)
except Exception as e:  # noqa: BLE001
    print(f"  FALHA: HTML nao parseavel: {e}")
    sys.exit(1)

if p.sec != n_slides_esperado:
    print(f"  FALHA: {p.sec} <section> (esperado {n_slides_esperado} = capa + slides).")
    sys.exit(1)

# O grafico do exemplo (maximo=5; maior valor 3.8) deve existir no DOM e ser honesto.
barras = re.findall(
    r'grafico__barra" style="height: ([\d.]+)%;">'
    r'<span class="grafico__valor">([^<]+)</span>', h)
if not barras:
    print("  FALHA: nenhuma barra de grafico com rotulo de valor no DOM.")
    sys.exit(1)

# Rotulo de valor presente em CADA barra (mesma contagem de barras e de rotulos).
cols = h.count('class="grafico__col"') + h.count('class="grafico__col grafico__col--destaque"')
if len(barras) != cols:
    print(f"  FALHA: {len(barras)} rotulos de valor para {cols} barras (deveria ter 1 por barra).")
    sys.exit(1)

# maximo=5 > maior valor (3.8) => NENHUMA barra toca o topo (base no zero, teto honesto).
alturas = [float(a) for a, _ in barras]
if max(alturas) >= 100:
    print(f"  FALHA: barra tocou o topo ({max(alturas)}%) com maximo > maior valor (eixo desonesto?).")
    sys.exit(1)
# 3.8/5*100 = 76.0 (a barra de maior valor)
if abs(max(alturas) - 76.0) > 0.1:
    print(f"  FALHA: maior barra em {max(alturas)}% (esperado 76.0 = 3.8/5).")
    sys.exit(1)

# Cor como excecao: exatamente 1 barra destaque (ambar) no exemplo (Dados=2.2).
# Contamos so a classe NO DOM (atributo da coluna), nao as regras da folha de estilo.
n_dest_dom = h.count('class="grafico__col grafico__col--destaque"')
if n_dest_dom != 1:
    print(f"  FALHA: {n_dest_dom} barra(s) destaque no DOM (esperado 1: cor como excecao).")
    sys.exit(1)

print(f"  OK: {p.sec} <section>; 0 NUL; grafico honesto "
      f"(maior barra 76% nao toca o topo; {len(barras)} rotulos; 1 barra ambar).")
PY
then
  log "  OK: deck WEB gerado e reaberto - secoes + grafico honesto conferidos."
else
  warn "  FALHA: smoke do deck WEB quebrou."
  falhou=1
fi

# 8) TEMAS (restyle por cor) - SEM dependencia externa (so stdlib), roda SEMPRE.
#    Prova a frente 4: (a) tema 'claro' BYTE-A-BYTE igual ao sem --tema (zero
#    regressao); (b) tema 'escuro' gera sem erro, 0 byte NUL, fundo escuro no DOM;
#    (c) tema inexistente falha com erro claro (exit !=0). Usa o gerar-web.py (sem
#    libs) como prova das 3; o tokens.css 'claro' tambem e conferido byte-a-byte.
log "8/8 Temas (restyle por cor: claro byte-identico, escuro acessivel, erro claro)..."
if python3 - "$DIR" <<'PY'
import subprocess, sys, json
from pathlib import Path

raiz = Path(sys.argv[1])
web = raiz / "gerar-web.py"
ger = raiz / "gerar.py"
falhas = 0

# As saidas ficam em saida/ (o --saida e CONFINADO a arvore do projeto por
# _resolver_saida; um tempdir em /tmp seria rejeitado). Prefixo _check_tema_*
# e limpo no fim. Escolho nomes proprios para nao colidir com os artefatos
# que os passos 5-7 deixaram em saida/.
sdir = raiz / "saida"
sdir.mkdir(exist_ok=True)
sem = sdir / "_check_tema_sem.html"
claro = sdir / "_check_tema_claro.html"
escuro = sdir / "_check_tema_escuro.html"
pptx_escuro = sdir / "_check_tema_escuro.pptx"
pdf_escuro = sdir / "_check_tema_escuro.pdf"
criados = [sem, claro, escuro, pptx_escuro, pdf_escuro]

# O CSS derivado do tema escuro (marca/tokens-<tema>.css) e gitignorado e pode
# pre-existir de uma execucao anterior. Lembramos se ja existia para restaurar o
# estado no finally (nao sujar nem apagar artefato legitimo de fora do teste).
derivado_escuro = raiz / "marca" / "tokens-escuro.css"
derivado_pre_existia = derivado_escuro.exists()

def run(args, **kw):
    return subprocess.run([sys.executable, *args], capture_output=True, text=True, **kw)

try:
    # (a) claro byte-a-byte == sem --tema (no deck WEB, saida deterministica).
    run([str(web), "--saida", str(sem.relative_to(raiz))], cwd=raiz)
    run([str(web), "--tema", "claro", "--saida", str(claro.relative_to(raiz))], cwd=raiz)
    if not (sem.exists() and claro.exists()):
        print("  FALHA: gerar-web nao produziu os HTML de comparacao."); falhas += 1
    elif sem.read_bytes() != claro.read_bytes():
        print("  FALHA: tema 'claro' difere do sem-tema (regressao no restyle)."); falhas += 1
    else:
        print("  OK: deck WEB 'claro' BYTE-A-BYTE identico ao sem --tema.")

    # (a2) tokens.css 'claro' byte-a-byte == o versionado (PDF nao regride).
    versionado = (raiz / "marca" / "tokens.css").read_bytes()
    run([str(ger), "sincronizar-tokens"], cwd=raiz)  # regenera default
    if (raiz / "marca" / "tokens.css").read_bytes() != versionado:
        print("  FALHA: tokens.css 'claro' divergiu do versionado."); falhas += 1
    else:
        print("  OK: tokens.css 'claro' byte-a-byte igual ao versionado.")

    # (b) escuro gera sem erro, 0 byte NUL, fundo escuro no DOM.
    r = run([str(web), "--tema", "escuro", "--saida", str(escuro.relative_to(raiz))], cwd=raiz)
    fundo = json.loads((raiz / "marca" / "tokens.json").read_text(encoding="utf-8"))
    fundo_escuro = fundo["temas"]["escuro"]["cor"]["fundo"]
    if r.returncode != 0 or not escuro.exists():
        print(f"  FALHA: tema 'escuro' nao gerou (rc={r.returncode}): {r.stderr.strip()}"); falhas += 1
    else:
        h = escuro.read_text(encoding="utf-8")
        if "\x00" in h:
            print("  FALHA: HTML do tema 'escuro' contem byte NUL."); falhas += 1
        elif fundo_escuro.upper() not in h.upper():
            print(f"  FALHA: fundo escuro {fundo_escuro} ausente no DOM do tema 'escuro'."); falhas += 1
        else:
            print(f"  OK: tema 'escuro' gerou, 0 NUL, fundo {fundo_escuro} aplicado.")

    # (c) tema inexistente -> erro claro com a lista, exit !=0 (nao silencioso).
    r = run([str(web), "--tema", "naoexiste",
             "--saida", str((sdir / "_check_tema_x.html").relative_to(raiz))], cwd=raiz)
    if r.returncode == 0:
        print("  FALHA: tema inexistente nao falhou (deveria exit !=0)."); falhas += 1
    elif "inexistente" not in (r.stderr + r.stdout).lower():
        print("  FALHA: erro de tema inexistente sem mensagem clara."); falhas += 1
    else:
        print("  OK: tema inexistente falha com erro claro (lista os disponiveis).")

    # (d) PPTX escuro - so com python-pptx (degrada com aviso, nao falha).
    #     Gera com --tema escuro, REABRE e prova: (i) honestidade preservada no
    #     escuro (chart com value_axis.minimum_scale == 0, base no zero independe
    #     do tema); (ii) tema aplicado (alguma forma da capa tem fill solido com a
    #     cor capa_fundo do tema escuro). Shapes sem fill solido sao ignorados.
    try:
        import pptx  # noqa: F401
        tem_pptx = True
    except ImportError:
        tem_pptx = False
    if not tem_pptx:
        print("  PULADO: PPTX escuro (python-pptx ausente).")
    else:
        from pptx import Presentation
        from pptx.enum.dml import MSO_FILL
        rp = run([str(raiz / "gerar-pptx.py"), "--tema", "escuro",
                  "--saida", str(pptx_escuro.relative_to(raiz))], cwd=raiz)
        if rp.returncode != 0 or not pptx_escuro.exists():
            print(f"  FALHA: PPTX 'escuro' nao gerou (rc={rp.returncode}): {rp.stderr.strip()}")
            falhas += 1
        else:
            cor_escuro = fundo["temas"]["escuro"]["cor"]
            capa_fundo = cor_escuro["capa_fundo"].lstrip("#").upper()
            pres = Presentation(str(pptx_escuro))
            slides = list(pres.slides)
            charts = [sh for s in slides for sh in s.shapes if sh.has_chart]
            if not charts:
                print("  FALHA: PPTX 'escuro' sem chart nativo para conferir a honestidade.")
                falhas += 1
            elif charts[0].chart.value_axis.minimum_scale not in (0, 0.0):
                ms = charts[0].chart.value_axis.minimum_scale
                print(f"  FALHA: PPTX 'escuro' com eixo min={ms} (honestidade: deve ser 0).")
                falhas += 1
            else:
                # Forma da CAPA (slide 0) com fill solido == capa_fundo do escuro.
                capa = slides[0]
                achou_fundo = False
                for sh in capa.shapes:
                    try:
                        fill = sh.fill
                        if fill.type == MSO_FILL.SOLID and \
                           str(fill.fore_color.rgb).upper() == capa_fundo:
                            achou_fundo = True
                            break
                    except Exception:  # noqa: BLE001 - shape sem fill solido: ignora
                        continue
                if not achou_fundo:
                    print(f"  FALHA: capa do PPTX 'escuro' sem forma com fundo {cor_escuro['capa_fundo']}.")
                    falhas += 1
                else:
                    print(f"  OK: PPTX 'escuro' - chart honesto (min=0) e capa com "
                          f"fundo {cor_escuro['capa_fundo']} aplicado.")

    # (e) PDF escuro - so com WeasyPrint (degrada com aviso, nao falha).
    #     Gera o deck com --tema escuro e prova: (i) o PDF foi criado nao-vazio;
    #     (ii) o CSS derivado que o PDF consome (marca/tokens-escuro.css) contem o
    #     `fundo` escuro do tema - prova deterministica, lib-a-parte, de que o PDF
    #     e escuro (o WeasyPrint le esse CSS via @import de tokens).
    try:
        import weasyprint  # noqa: F401
        tem_weasy = True
    except ImportError:
        tem_weasy = False
    if not tem_weasy:
        print("  PULADO: PDF escuro (WeasyPrint ausente).")
    else:
        rpdf = run([str(ger), "deck", "--tema", "escuro",
                    "--saida", str(pdf_escuro.relative_to(raiz))], cwd=raiz)
        if rpdf.returncode != 0 or not pdf_escuro.exists():
            print(f"  FALHA: PDF 'escuro' nao gerou (rc={rpdf.returncode}): {rpdf.stderr.strip()}")
            falhas += 1
        elif pdf_escuro.stat().st_size == 0:
            print("  FALHA: PDF 'escuro' foi criado vazio.")
            falhas += 1
        elif not derivado_escuro.exists():
            print(f"  FALHA: CSS derivado {derivado_escuro.name} ausente apos gerar o PDF escuro.")
            falhas += 1
        else:
            css = derivado_escuro.read_text(encoding="utf-8")
            if fundo_escuro.upper() not in css.upper():
                print(f"  FALHA: CSS derivado {derivado_escuro.name} sem o fundo escuro {fundo_escuro}.")
                falhas += 1
            else:
                print(f"  OK: PDF 'escuro' nao-vazio; CSS derivado {derivado_escuro.name} "
                      f"com fundo {fundo_escuro}.")
finally:
    for p in criados + [sdir / "_check_tema_x.html"]:
        p.unlink(missing_ok=True)
    # Restaura o estado do CSS derivado: so removemos se NAO pre-existia ao teste.
    if not derivado_pre_existia:
        derivado_escuro.unlink(missing_ok=True)

sys.exit(1 if falhas else 0)
PY
then
  log "  OK: temas conferidos - claro byte-identico, escuro acessivel, erro claro."
else
  warn "  FALHA: smoke de temas quebrou."
  falhou=1
fi

if [ "$falhou" -eq 0 ]; then
  log "Tudo OK (offline). Para PDF real: pip install -r entregaveis/requirements.txt"
  exit 0
else
  warn "Houve falha(s) acima."
  exit 1
fi
