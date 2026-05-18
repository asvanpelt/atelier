#!/bin/bash
# Construye Atelier con SPM y empaqueta el ejecutable en un .app bundle ad-hoc
# firmado, instalado en /Applications.
#
# Uso:
#   ./Scripts/install-local.sh             # release (recomendado)
#   ./Scripts/install-local.sh debug

set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="Atelier"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST_APP="/Applications/${APP_NAME}.app"

cd "$REPO_ROOT"

echo "🛠  Compilando con SPM (${CONFIG})…"
swift build -c "$CONFIG"

BUILD_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN="${BUILD_DIR}/${APP_NAME}"
RESOURCE_BUNDLE="${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle"

if [ ! -f "$BIN" ]; then
    echo "❌ Binario no encontrado en $BIN"
    exit 1
fi

echo "🛑 Cerrando instancias activas…"
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

if [ -d "$DEST_APP" ]; then
    echo "🧹 Eliminando $DEST_APP"
    rm -rf "$DEST_APP"
fi

echo "📦 Empaquetando .app…"
mkdir -p "$DEST_APP/Contents/MacOS"
mkdir -p "$DEST_APP/Contents/Resources"

cp "$BIN" "$DEST_APP/Contents/MacOS/${APP_NAME}"

# Info.plist con EXECUTABLE_NAME resuelto
sed "s/\$(EXECUTABLE_NAME)/${APP_NAME}/g" "${REPO_ROOT}/Atelier/Info.plist" \
    > "$DEST_APP/Contents/Info.plist"

# Recursos del bundle de SPM (logo, models, etc.)
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$DEST_APP/Contents/Resources/"
fi

# Iconos sueltos
for asset in logo.png logo_trans.png; do
    if [ -f "${REPO_ROOT}/Atelier/Resources/${asset}" ]; then
        cp "${REPO_ROOT}/Atelier/Resources/${asset}" \
            "$DEST_APP/Contents/Resources/${asset}"
    fi
done

# Quitar quarantine y firmar ad-hoc
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true
echo "🔏 Firmando ad-hoc…"
codesign --force --deep --sign - "$DEST_APP"

# Re-registrar en Launch Services + Spotlight
echo "🔄 Refrescando Launch Services / Spotlight…"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
    -f "$DEST_APP" 2>/dev/null || true
mdimport "$DEST_APP" 2>/dev/null || true

echo "✅ Instalado en $DEST_APP"
echo "   Ábrelo con Spotlight (⌘Space → 'Atelier')."
