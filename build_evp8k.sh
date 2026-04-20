#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Elysium Vanguard Pro Player 8K — Production Build System v16.0
# ═══════════════════════════════════════════════════════════════════
# 
# This script performs a clean Release build, assembles a native
# macOS .app bundle, installs it to /Applications, and registers
# it with Launch Services so it appears in Finder & Launchpad.
#
# Usage:  sh build_evp8k.sh
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────
APP_NAME="Elysium Vanguard Pro Player 8K"
BUNDLE_NAME="${APP_NAME}.app"
EXECUTABLE_NAME="ElysiumVanguardProPlayer8K"
PRODUCT_NAME="ProPlayer"                       # SPM executable target
BUNDLE_ID="com.jordelmir.ElysiumVanguardProPlayer8K"
VERSION="16.1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/.build"
RELEASE_BIN="${BUILD_DIR}/release/${PRODUCT_NAME}"
STAGING_DIR="${BUILD_DIR}/staging"
APP_BUNDLE="${STAGING_DIR}/${BUNDLE_NAME}"
INSTALL_DIR="/Applications"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  ⚡ ELYSIUM VANGUARD PRO PLAYER 8K — BUILD SYSTEM v16.0${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

step() {
    echo -e "${BOLD}${GREEN}▸ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

fail() {
    echo -e "${RED}✖ ERROR: $1${NC}"
    exit 1
}

ok() {
    echo -e "${GREEN}✔ $1${NC}"
}

banner

# ─── Phase 1: Deep Clean ─────────────────────────────────────────
step "Phase 1: Deep Clean"
cd "${SCRIPT_DIR}"

if [ -d "${BUILD_DIR}" ]; then
    rm -rf "${BUILD_DIR}"
    ok "Removed .build directory"
fi

swift package clean 2>/dev/null || true
ok "Swift package cache cleaned"
echo ""

# ─── Phase 2: Release Build ──────────────────────────────────────
step "Phase 2: Release Build (optimized for Apple Silicon)"
swift build -c release --product "${PRODUCT_NAME}" 2>&1

if [ ! -f "${RELEASE_BIN}" ]; then
    fail "Build failed — binary not found at ${RELEASE_BIN}"
fi

ok "Release binary compiled successfully"
echo ""

# ─── Phase 3: Assemble .app Bundle ────────────────────────────────
step "Phase 3: Assembling native .app bundle"

# Clean staging
rm -rf "${STAGING_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 3a. Copy and rename the executable
cp "${RELEASE_BIN}" "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"
ok "Executable: ${EXECUTABLE_NAME}"

# 3b. Copy Info.plist
cp "${SCRIPT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
ok "Info.plist (v${VERSION})"

# 3c. Create PkgInfo (standard macOS convention)
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"
ok "PkgInfo created"

# 3d. Copy Resource Bundles (SPM stores processed resources as .bundle)
RESOURCE_DIR="${BUILD_DIR}/release"
BUNDLES_COPIED=0
for bundle in "${RESOURCE_DIR}"/*.bundle; do
    if [ -d "${bundle}" ]; then
        cp -R "${bundle}" "${APP_BUNDLE}/Contents/Resources/"
        BUNDLES_COPIED=$((BUNDLES_COPIED + 1))
    fi
done

# Also check in artifacts path
for bundle in "${BUILD_DIR}"/artifacts/**/*.bundle; do
    if [ -d "${bundle}" 2>/dev/null ]; then
        cp -R "${bundle}" "${APP_BUNDLE}/Contents/Resources/"
        BUNDLES_COPIED=$((BUNDLES_COPIED + 1))
    fi
done
ok "Resource bundles copied: ${BUNDLES_COPIED}"

# 3e. Copy any app icons if present
if [ -f "${SCRIPT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${SCRIPT_DIR}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    ok "App icon copied"
fi

# 3f. Copy logo assets from ProPlayer Resources
for img in "${SCRIPT_DIR}/Sources/ProPlayer/Resources/"*; do
    if [ -f "${img}" ]; then
        cp "${img}" "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
    fi
done
ok "UI assets bundled"

echo ""

# ─── Phase 4: Validate Bundle ────────────────────────────────────
step "Phase 4: Bundle Validation"

# Check structure
[ -f "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}" ] || fail "Missing executable"
[ -f "${APP_BUNDLE}/Contents/Info.plist" ] || fail "Missing Info.plist"
[ -f "${APP_BUNDLE}/Contents/PkgInfo" ] || fail "Missing PkgInfo"

# Verify binary is a valid Mach-O
file "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}" | grep -q "Mach-O" || fail "Invalid binary format"

# Get architecture
ARCH=$(file "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}" | grep -o "arm64\|x86_64" | head -1)
ok "Valid Mach-O binary (${ARCH})"

# Bundle size
BUNDLE_SIZE=$(du -sh "${APP_BUNDLE}" | cut -f1)
ok "Bundle size: ${BUNDLE_SIZE}"

echo ""

# ─── Phase 5: Install to /Applications ───────────────────────────
if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
    step "Phase 5: Skipping Installation (CI Environment)"
else
    step "Phase 5: Installing to ${INSTALL_DIR}"
    
    # Remove old installation if exists
    if [ -d "${INSTALL_DIR}/${BUNDLE_NAME}" ]; then
        warn "Existing installation found — removing..."
        rm -rf "${INSTALL_DIR}/${BUNDLE_NAME}" 2>/dev/null || sudo rm -rf "${INSTALL_DIR}/${BUNDLE_NAME}"
    fi
    
    # Copy to Applications
    cp -R "${APP_BUNDLE}" "${INSTALL_DIR}/" 2>/dev/null || sudo cp -R "${APP_BUNDLE}" "${INSTALL_DIR}/"
    ok "Installed to ${INSTALL_DIR}/${BUNDLE_NAME}"
fi

echo ""

# ─── Phase 6: Register with Launch Services ──────────────────────
if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
    step "Phase 6: Skipping Registration (CI Environment)"
else
    step "Phase 6: Registering with macOS Launch Services"
    
    LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
    
    if [ -x "${LSREGISTER}" ]; then
        "${LSREGISTER}" -f "${INSTALL_DIR}/${BUNDLE_NAME}"
        ok "Registered — visible in Finder & Launchpad"
    else
        warn "lsregister not found — app will register on first launch"
    fi
fi

echo ""

# ─── Phase 7: Verify Installation ────────────────────────────────
step "Phase 7: Installation Verification"

if [ -d "${INSTALL_DIR}/${BUNDLE_NAME}" ]; then
    echo -e "  ${GREEN}✔${NC} Bundle exists:  ${INSTALL_DIR}/${BUNDLE_NAME}"
    echo -e "  ${GREEN}✔${NC} Executable:     $(ls -lh "${INSTALL_DIR}/${BUNDLE_NAME}/Contents/MacOS/${EXECUTABLE_NAME}" | awk '{print $5}')"
    echo -e "  ${GREEN}✔${NC} Architecture:   ${ARCH}"
    echo -e "  ${GREEN}✔${NC} Version:        ${VERSION}"
    echo -e "  ${GREEN}✔${NC} Bundle ID:      ${BUNDLE_ID}"
else
    fail "Installation verification failed!"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅ BUILD COMPLETE — ${APP_NAME} v${VERSION}${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Launch:  ${BOLD}open \"${INSTALL_DIR}/${BUNDLE_NAME}\"${NC}"
echo -e "  Finder:  ${BOLD}Applications → ${APP_NAME}${NC}"
echo ""

if [ -f "${SCRIPT_DIR}/create_dmg.sh" ]; then
    echo -e "${YELLOW}Packing into DMG via create_dmg.sh...${NC}"
    bash "${SCRIPT_DIR}/create_dmg.sh"
fi
