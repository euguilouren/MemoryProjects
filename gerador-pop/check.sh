#!/usr/bin/env bash
# Rede de seguranca do Gerador de POP: valida a sintaxe do JS embutido no
# index.html (offline). E o gate que o revisor-de-codigo roda antes/depois de
# refatorar. Sai != 0 se houver erro de sintaxe.
#
# Uso:  bash gerador-pop/check.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log()  { printf '\033[36m[gerador-pop:check]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[gerador-pop:check] %s\033[0m\n' "$*"; }

if ! command -v node >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
  warn "node/python3 ausente. Pulado."
  exit 0
fi

log "Checando sintaxe do JS embutido..."
tmpjs="$(mktemp --suffix=.mjs)"
python3 - "$DIR/index.html" > "$tmpjs" <<'PY'
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
blocos = re.findall(r'<script\b([^>]*)>(.*?)</script>', html, re.DOTALL | re.IGNORECASE)
saida = []
for attrs, corpo in blocos:
    if re.search(r'type\s*=\s*["\']?(application/json|importmap)', attrs, re.IGNORECASE):
        continue
    saida.append(corpo)
sys.stdout.write("\n;\n".join(saida))
PY

if node --check "$tmpjs"; then
  log "Gerador de POP OK."
  rm -f "$tmpjs"
else
  warn "Gerador de POP FALHOU (erro de sintaxe no JS)."
  rm -f "$tmpjs"
  exit 1
fi
