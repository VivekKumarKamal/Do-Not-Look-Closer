#!/bin/bash
set -e

# release.sh — Build, sign update, and generate appcast
# Usage: bash release.sh

APP_NAME="Don't look closer"
DMG_NAME="${APP_NAME}.dmg"
SPARKLE_BIN="./Frameworks/bin"

echo "=== Release Pipeline ==="
echo ""

# Step 1: Build the app and DMG
echo "📦 Step 1: Building app..."
bash build.sh
echo ""

# Step 2: Sign the DMG with Sparkle EdDSA key
echo "🔑 Step 2: Signing DMG with EdDSA key..."
SIGNATURE=$("${SPARKLE_BIN}/sign_update" "${DMG_NAME}" 2>&1)
echo "Signature: ${SIGNATURE}"
echo ""

# Step 3: Generate/update appcast.xml
echo "📡 Step 3: Generating appcast..."
mkdir -p docs
# Copy DMG to docs folder for GitHub Pages hosting (optional — you can also use GitHub Releases)
cp "${DMG_NAME}" docs/
"${SPARKLE_BIN}/generate_appcast" docs/ 2>&1
echo ""

# Show results
echo "=== Release Complete ==="
echo ""
echo "📋 Next steps:"
echo "  1. git add docs/appcast.xml"
echo "  2. git commit -m 'Release v$(grep -A1 CFBundleShortVersionString Info.plist | grep string | sed 's/.*<string>//' | sed 's/<\/string>//')'"
echo "  3. git push origin main"
echo "  4. Create a GitHub Release and attach: ${DMG_NAME}"
echo ""
echo "Users will be notified of the update automatically! 🎉"
