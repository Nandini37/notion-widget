#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🚀 Building and setting up Notion Widget from git..."

# 1. Ensure build.sh is executable and run it
chmod +x build.sh
./build.sh

# 2. Install to ~/Applications
DEST_DIR="$HOME/Applications"
mkdir -p "$DEST_DIR"

APP_NAME="Notion Widget.app"
echo "📦 Installing to ${DEST_DIR}/${APP_NAME}..."
rm -rf "${DEST_DIR}/${APP_NAME}"
cp -R "${APP_NAME}" "${DEST_DIR}/${APP_NAME}"

echo "✅ Notion Widget successfully installed in ${DEST_DIR}/${APP_NAME}"

# 3. Prompt or launch
if command -v open >/dev/null 2>&1; then
    echo "🎉 Launching Notion Widget..."
    open "${DEST_DIR}/${APP_NAME}"
fi
