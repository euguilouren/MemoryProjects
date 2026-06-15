#!/usr/bin/env bash
# Rede de seguranca do MemoryProjects — roda os testes/checks disponiveis.
#
# E o gate que o revisor-de-codigo (portao de clean code do MemoryCode) executa
# ANTES e DEPOIS de refatorar: se nao passa, nao se entrega. Sai com codigo != 0
# se qualquer check falhar.
#
# Uso:  bash scripts/test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
log()  { printf '\033[36m[test]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[test] %s\033[0m\n' "$*"; }
falhou=0

# --- sentinela: compila + roda os testes unitarios JVM (rede de seguranca do refactor) ---
# Sem SDK (rede bloqueada), o build nao roda: avisa, nao falha o gate por ausencia de ambiente.
if [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ] && [ -f "$ROOT/sentinela/gradlew" ]; then
  log "sentinela: compilando (assembleDebug) + testes unitarios..."
  if ( cd "$ROOT/sentinela" && ANDROID_HOME="$ANDROID_HOME" ./gradlew --no-daemon :app:assembleDebug :app:testDebugUnitTest ); then
    log "sentinela OK."
  else
    warn "sentinela FALHOU (compilacao/teste)."; falhou=1
  fi
else
  warn "sentinela: Android SDK ausente — rode 'bash scripts/setup.sh' com a rede liberada. Pulado."
fi

# --- gerador-pop: valida a sintaxe do JS embutido (offline) ---
if command -v node >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  log "gerador-pop: checando sintaxe do JS embutido..."
  tmpjs="$(mktemp --suffix=.mjs)"
  python3 - "$ROOT/gerador-pop/index.html" > "$tmpjs" <<'PY'
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
# concatena o corpo das tags <script> que sao JS (ignora json/importmap)
blocos = re.findall(r'<script\b([^>]*)>(.*?)</script>', html, re.DOTALL | re.IGNORECASE)
saida = []
for attrs, corpo in blocos:
    if re.search(r'type\s*=\s*["\']?(application/json|importmap)', attrs, re.IGNORECASE):
        continue
    saida.append(corpo)
sys.stdout.write("\n;\n".join(saida))
PY
  if node --check "$tmpjs"; then
    log "gerador-pop OK."
  else
    warn "gerador-pop FALHOU (erro de sintaxe no JS)."; falhou=1
  fi
  rm -f "$tmpjs"
else
  warn "gerador-pop: node/python3 ausente. Pulado."
fi

if [ "$falhou" -eq 0 ]; then
  log "Tudo verde."
else
  warn "Ha falhas acima."
fi
exit "$falhou"
