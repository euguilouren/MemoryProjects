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

# 1) Sintaxe do gerar.py (compila sem executar).
log "1/7 Compilando gerar.py (py_compile)..."
if python3 -m py_compile "$DIR/gerar.py"; then
  log "  OK: gerar.py sem erro de sintaxe."
else
  warn "  FALHA: erro de sintaxe em gerar.py."
  falhou=1
fi

# 2) tokens.json valido (JSON bem-formado).
log "2/7 Validando tokens.json..."
if python3 -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "$DIR/marca/tokens.json"; then
  log "  OK: tokens.json valido."
else
  warn "  FALHA: tokens.json invalido."
  falhou=1
fi

# 3) Dados de exemplo validos (deck.json e front-matter do relatorio.md).
log "3/7 Validando dados de exemplo..."
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
log "4/7 Checando templates e CSS..."
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
log "1b/7 Compilando gerar-pptx.py (py_compile)..."
if python3 -m py_compile "$DIR/gerar-pptx.py"; then
  log "  OK: gerar-pptx.py sem erro de sintaxe."
else
  warn "  FALHA: erro de sintaxe em gerar-pptx.py."
  falhou=1
fi

# 1c) Sintaxe do gerar-web.py (caminho WEB/reveal.js, aditivo ao PDF/PPTX).
log "1c/7 Compilando gerar-web.py (py_compile)..."
if python3 -m py_compile "$DIR/gerar-web.py"; then
  log "  OK: gerar-web.py sem erro de sintaxe."
else
  warn "  FALHA: erro de sintaxe em gerar-web.py."
  falhou=1
fi

# 5) Render de fumaca - SO se as libs existirem (degrada com aviso).
log "5/7 Render de fumaca PDF (se as libs existirem)..."
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
log "6/7 Smoke do PPTX nativo (se python-pptx existir)..."
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
log "7/7 Smoke do deck WEB (reveal.js, sem libs externas)..."
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

if [ "$falhou" -eq 0 ]; then
  log "Tudo OK (offline). Para PDF real: pip install -r entregaveis/requirements.txt"
  exit 0
else
  warn "Houve falha(s) acima."
  exit 1
fi
