#!/bin/bash

# Configuration
APP_NAME="Elysium Vanguard Pro Player"
APP_BUNDLE="/Applications/${APP_NAME}.app"
BUILD_DIR=".build/release"
TARGET_BINARY="${APP_BUNDLE}/Contents/MacOS/ElysiumVanguardProPlayer"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"

echo "🚀 Deploying v7.2 Hardened Engine to Applications..."

# 1. Update Binary
if [ -f "${BUILD_DIR}/ProPlayer" ]; then
    cp "${BUILD_DIR}/ProPlayer" "${TARGET_BINARY}"
    chmod +x "${TARGET_BINARY}"
    echo "✅ Binary updated: ${TARGET_BINARY}"
else
    echo "❌ Error: Release binary not found at ${BUILD_DIR}/ProPlayer"
    exit 1
fi

# 2. Update Resources (Bundles / Shaders)
echo "📦 Syncing resources..."
cp -r "${BUILD_DIR}/ProPlayer_ProPlayer.bundle" "${RESOURCES_DIR}/"
cp -r "${BUILD_DIR}/ProPlayer_ProPlayerEngine.bundle" "${RESOURCES_DIR}/"

# 3. Touch the app bundle to force macOS to recognize changes
touch "${APP_BUNDLE}"

echo "✨ Deployment complete! You can now launch '${APP_NAME}' from your Applications folder."
