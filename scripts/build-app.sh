#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_DIR="$ROOT_DIR/build/Notepad.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/$CONFIGURATION/NotepadMac" "$MACOS_DIR/Notepad"
chmod +x "$MACOS_DIR/Notepad"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "Built $APP_DIR"
