#!/bin/bash
set -e

APP_NAME="Don't look closer"
BUNDLE_ID="com.vivekkumar.breakreminder"
VERSION="2.1.0"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
DMG_NAME="${APP_NAME}.dmg"

echo "🔨 Building ${APP_NAME} v${VERSION}..."
swift build -c release 2>&1

echo "📦 Creating app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${CONTENTS_DIR}/MacOS"
mkdir -p "${CONTENTS_DIR}/Resources"
mkdir -p "${CONTENTS_DIR}/Frameworks"

# Copy executable
cp "${BUILD_DIR}/BreakReminder" "${CONTENTS_DIR}/MacOS/BreakReminder"

# Copy Info.plist
cp "Info.plist" "${CONTENTS_DIR}/Info.plist"

# Copy app icon if it exists
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${CONTENTS_DIR}/Resources/AppIcon.icns"
    echo "🎨 App icon added!"
fi

# Copy Sparkle framework
if [ -d "Frameworks/Sparkle.framework" ]; then
    cp -R "Frameworks/Sparkle.framework" "${CONTENTS_DIR}/Frameworks/"
    echo "✨ Sparkle framework embedded!"
fi

# Create PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "🔏 Ad-hoc code signing..."
# Sign the Sparkle framework first
if [ -d "${CONTENTS_DIR}/Frameworks/Sparkle.framework" ]; then
    codesign --force --deep --sign - "${CONTENTS_DIR}/Frameworks/Sparkle.framework" 2>&1
fi
# Sign the app
codesign --force --deep --sign - \
    --entitlements "BreakReminder.entitlements" \
    "${APP_DIR}"

echo "✅ ${APP_NAME}.app created and signed!"

# Verify signature
echo "🔍 Verifying signature..."
codesign --verify --verbose "${APP_DIR}" 2>&1 || echo "⚠️ Signature verification note above"

echo ""
echo "📍 App location: $(pwd)/${APP_DIR}"
echo "🚀 To run: open \"${APP_DIR}\""
echo "📋 To install: cp -r \"${APP_DIR}\" /Applications/"

# Create DMG
echo ""
echo "💿 Creating DMG installer..."
rm -f "${DMG_NAME}"

DMG_TEMP="dmg_temp"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"
cp -r "${APP_DIR}" "${DMG_TEMP}/"

ln -s /Applications "${DMG_TEMP}/Applications"

hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    "${DMG_NAME}" 2>&1

rm -rf "${DMG_TEMP}"

echo "✅ ${DMG_NAME} created!"
echo "💿 DMG location: $(pwd)/${DMG_NAME}"
echo ""
echo "📤 Share this DMG file for distribution!"
