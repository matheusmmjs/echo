#!/bin/bash
# Empacota o executável do SwiftPM num .app de verdade.
#
# Por quê: SwiftPM sozinho só gera um binário solto (.build/*/Echo). O
# macOS exige um bundle .app com Info.plist pra: (1) não matar o processo
# ao pedir microfone, (2) o TCC (sistema de permissões) conseguir associar
# permissões de Accessibility/Input Monitoring/Microfone a uma identidade
# estável, (3) você conseguir dar duplo-clique nele como qualquer app.
set -euo pipefail

CONFIG="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Echo"
APP_BUNDLE="$ROOT_DIR/$APP_NAME.app"

echo "==> Building ($CONFIG)..."
if [ "$CONFIG" = "release" ]; then
    swift build -c release --package-path "$ROOT_DIR"
    BIN_PATH="$ROOT_DIR/.build/release/$APP_NAME"
else
    swift build --package-path "$ROOT_DIR"
    BIN_PATH="$ROOT_DIR/.build/debug/$APP_NAME"
fi

echo "==> Montando $APP_BUNDLE ..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Assinatura com certificado local auto-assinado ("Echo Dev", criado uma
# vez no Keychain Access - ver ADR 0005). Diferente de assinatura ad-hoc
# (-), essa identidade é estável entre builds: o TCC (permissões do macOS)
# reconhece sempre o mesmo app, então Input Monitoring/Microfone não
# precisam ser reautorizados a cada recompilação.
codesign --force --deep --sign "Echo Dev" "$APP_BUNDLE"

echo "==> Pronto: $APP_BUNDLE"
