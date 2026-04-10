#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# create_dmg.sh — Elysium Vanguard Pro DMG Packager
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

APP_NAME="Elysium Vanguard Pro Player 8K"
BUNDLE_NAME="${APP_NAME}.app"
VERSION="16.0"
DMG_NAME="ElysiumVanguardPro_${VERSION}_Mac.dmg"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="${SCRIPT_DIR}/.build/staging/${BUNDLE_NAME}"
DMG_STAGING="${SCRIPT_DIR}/.build/dmg_staging"
OUTPUT_DIR="${SCRIPT_DIR}/.build/release"

echo "📦 Packaging ${APP_NAME} into DMG..."

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: App bundle not found at ${APP_PATH}. Run build_evp8k.sh first."
    exit 1
fi

rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
mkdir -p "${OUTPUT_DIR}"

# Copy App to DMG Staging
cp -R "${APP_PATH}" "${DMG_STAGING}/"

# Create Applications Symlink
ln -s /Applications "${DMG_STAGING}/Applications"

# Create DMG Using hdiutil
echo "Disk image creation in progress..."
rm -f "${OUTPUT_DIR}/${DMG_NAME}"
hdiutil create -volname "${APP_NAME} Installer" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${OUTPUT_DIR}/${DMG_NAME}"

echo "✅ DMG successfully built: ${OUTPUT_DIR}/${DMG_NAME}"
