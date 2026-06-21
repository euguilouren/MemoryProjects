#!/usr/bin/env bash
# setup.sh — preparo do ambiente do pipeline de ENTREGAVEIS (doc/PDF).
#
# Idempotente e TOLERANTE A FALHA: roda no SessionStart (.claude/settings.json)
# para que gerar.py rode "de fabrica". NUNCA derruba a sessao — se a rede/pip
# falhar, AVISA e segue (modo degradado: HTML intermediario), no mesmo espirito
# de sentinela/setup.sh. Cada projeto carrega o proprio ferramental (convencao
# do repo): este prepara so o pipeline de entregaveis.

set -uo pipefail
log() { printf '\033[36m[entregaveis:setup]\033[0m %s\n' "$*"; }
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQ="$AQUI/requirements.txt"

if python3 -c "import weasyprint, jinja2, markdown" 2>/dev/null; then
  log "dependencias Python ja presentes — nada a fazer."
  exit 0
fi

if [ ! -f "$REQ" ]; then
  log "AVISO: requirements.txt nao encontrado em $AQUI; pulando."
  exit 0
fi

log "instalando dependencias Python do pipeline (pip)..."
if ! pip3 install --quiet --user -r "$REQ" >/tmp/setup-entregaveis.log 2>&1; then
  log "AVISO: pip nao concluiu (rede bloqueada?) — pipeline em modo DEGRADADO (HTML intermediario)."
  log "  Libere na POLITICA DE REDE do ambiente: pypi.org, files.pythonhosted.org."
  log "  Detalhe: $(tail -1 /tmp/setup-entregaveis.log 2>/dev/null || echo 'sem log')"
  exit 0
fi

# pip concluiu, mas WeasyPrint so importa com libs de SISTEMA (libpango/cairo).
# Re-verifica o import para nao reportar "pronto" sem estar (honestidade > otimismo).
if python3 -c "import weasyprint, jinja2, markdown" 2>/dev/null; then
  log "OK: pipeline pronto (pip + libs de sistema presentes). PDF real disponivel."
else
  log "AVISO: pacotes pip instalados, mas WeasyPrint NAO importa — faltam libs de SISTEMA."
  log "  Pipeline em modo DEGRADADO (HTML intermediario). Para PDF real, instale no ambiente:"
  log "  Debian/Ubuntu: apt-get install -y libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf-2.0-0 libffi-dev"
  log "  (precisa de root/rede — configure no SETUP DO AMBIENTE web, nao so no pip)."
fi

exit 0  # sempre 0: o SessionStart nunca falha a sessao por causa do preparo
