#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
UNIVERSAL="${UNIVERSAL:-1}"
APP_DIR="$ROOT_DIR/build/MacPad.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BINARY_PATH=".build/$CONFIGURATION/MacPad"

cd "$ROOT_DIR"
if [[ "$CONFIGURATION" == "release" && "$UNIVERSAL" == "1" ]]; then
  swift build -c "$CONFIGURATION" --arch arm64 --arch x86_64
  BINARY_PATH=".build/apple/Products/Release/MacPad"
else
  swift build -c "$CONFIGURATION"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY_PATH" "$MACOS_DIR/MacPad"
chmod +x "$MACOS_DIR/MacPad"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
"$ROOT_DIR/scripts/create-app-icon.sh" "$ROOT_DIR/Resources/MacPadLogo.jpeg" "$RESOURCES_DIR/AppIcon.icns"
/usr/bin/xattr -cr "$APP_DIR"
/usr/bin/codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "Built $APP_DIR"
