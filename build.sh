#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_NAME="Notion Widget"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Compiling '${APP_NAME}' with new Logo and Branding..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

swiftc -O -framework Cocoa -framework WebKit main.swift SettingsWindowController.swift -o "${MACOS_DIR}/NotionWidget"

cp Info.plist "${CONTENTS_DIR}/Info.plist"

# Copy new icons & branding assets
cp AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
cp MenuIcon.png "${RESOURCES_DIR}/MenuIcon.png"
cp MenuIcon@2x.png "${RESOURCES_DIR}/MenuIcon@2x.png"

# Copy local user configuration if present (git-ignored)
if [ -f "config.local.json" ]; then
    cp config.local.json "${RESOURCES_DIR}/config.local.json"
fi

# Hardened Runtime Code Signing
codesign -s - --options runtime --force --deep "${MACOS_DIR}/NotionWidget"
codesign -s - --options runtime --force --deep "${APP_BUNDLE}"

echo "✅ Successfully built hardened '${APP_BUNDLE}'"
