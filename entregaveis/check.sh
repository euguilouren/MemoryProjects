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
log "1/5 Compilando gerar.py (py_compile)..."
if python3 -m py_compile "$DIR/gerar.py"; then
  log "  OK: gerar.py sem erro de sintaxe."
else
  warn "  FALHA: erro de sintaxe em gerar.py."
  falhou=1
fi

# 2) tokens.json valido (JSON bem-formado).
log "2/5 Validando tokens.json..."
if python3 -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8'))" "$DIR/marca/tokens.json"; then
  log "  OK: tokens.json valido."
else
  warn "  FALHA: tokens.json invalido."
  falhou=1
fi

# 3) Dados de exemplo validos (deck.json e front-matter do relatorio.md).
log "3/5 Validando dados de exemplo..."
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
log "4/5 Checando templates e CSS..."
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

# 5) Render de fumaca - SO se as libs existirem (degrada com aviso).
log "5/5 Render de fumaca (se as libs existirem)..."
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

if [ "$falhou" -eq 0 ]; then
  log "Tudo OK (offline). Para PDF real: pip install -r entregaveis/requirements.txt"
  exit 0
else
  warn "Houve falha(s) acima."
  exit 1
fi
