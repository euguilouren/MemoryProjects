#!/usr/bin/env bash
# Rede de seguranca do Sentinela: compila (assembleDebug) + testes unitarios JVM
# do cofre AES-256. E o gate que o revisor-de-codigo roda ANTES e DEPOIS de
# refatorar. Sai != 0 se a compilacao/teste falhar.
#
# Uso:  bash sentinela/test.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
log()  { printf '\033[36m[sentinela:test]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[sentinela:test] %s\033[0m\n' "$*"; }

if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  warn "Android SDK ausente — rode 'bash sentinela/setup.sh' com a rede liberada. Pulado."
  exit 0
fi

log "Compilando (assembleDebug) + testes unitarios..."
if ( cd "$DIR" && ANDROID_HOME="$ANDROID_HOME" ./gradlew --no-daemon :app:assembleDebug :app:testDebugUnitTest ); then
  log "Sentinela OK."
else
  warn "Sentinela FALHOU (compilacao/teste)."
  exit 1
fi
