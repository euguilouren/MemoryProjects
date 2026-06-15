#!/usr/bin/env bash
# Setup do Sentinela (Android/Gradle) para Claude Code na web.
#
# Idempotente e tolerante a falha: pode rodar em todo SessionStart sem derrubar a
# sessao. Instala o Android SDK quando a rede permite, escreve local.properties e
# aquece o Gradle.
#
# Uso:  bash sentinela/setup.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log()  { printf '\033[36m[sentinela:setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[sentinela:setup] %s\033[0m\n' "$*"; }

ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
SDKMGR="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
CLT_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
rede_google_ok() { curl -fsS -m 8 -o /dev/null "https://dl.google.com/android/repository/repository2-3.xml" 2>/dev/null; }

log "JDK: $(java -version 2>&1 | head -1)"

if [ -x "$SDKMGR" ]; then
  log "Android cmdline-tools ja instalado ($ANDROID_HOME)."
elif rede_google_ok; then
  log "Instalando Android cmdline-tools..."
  tmp="$(mktemp -d)"
  if curl -fsSL -m 120 "$CLT_URL" -o "$tmp/clt.zip"; then
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    unzip -q "$tmp/clt.zip" -d "$tmp"
    rm -rf "$ANDROID_HOME/cmdline-tools/latest"
    mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  else
    warn "Falha ao baixar os cmdline-tools."
  fi
  rm -rf "$tmp"
else
  warn "Rede para dl.google.com bloqueada (politica de rede do ambiente)."
  warn "Libere Google Maven + Android SDK + Gradle para compilar:"
  warn "dl.google.com, maven.google.com, services.gradle.org, repo.maven.apache.org, plugins.gradle.org"
fi

if [ -x "$SDKMGR" ]; then
  log "Aceitando licencas e instalando platform-34 + build-tools 34..."
  yes 2>/dev/null | "$SDKMGR" --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
  "$SDKMGR" --sdk_root="$ANDROID_HOME" "platform-tools" "platforms;android-34" "build-tools;34.0.0" >/dev/null 2>&1 \
    || warn "Nao consegui instalar todos os pacotes do SDK (rede?)."
  printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$DIR/local.properties"
  log "local.properties: sdk.dir=$ANDROID_HOME"
  log "Aquecendo o Gradle (baixa AGP/Compose/deps)..."
  ( cd "$DIR" && ANDROID_HOME="$ANDROID_HOME" ./gradlew --no-daemon help >/dev/null 2>&1 ) \
    || warn "Gradle nao aqueceu (rede/dependencias)."
fi

log "Setup do Sentinela concluido. Rede de seguranca: bash sentinela/test.sh"
