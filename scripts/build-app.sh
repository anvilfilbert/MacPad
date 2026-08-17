#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
UNIVERSAL="${UNIVERSAL:-1}"
APP_DIR="$ROOT_DIR/build/MacPad.app"
BINARY_PATH=".build/$CONFIGURATION/MacPad"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/macpad-build.XXXXXX")"
STAGED_APP="$STAGE_DIR/MacPad.app"
VERIFY_APP="$STAGE_DIR/verify/MacPad.app"
CONTENTS_DIR="$STAGED_APP/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

cd "$ROOT_DIR"
if [[ "$CONFIGURATION" == "release" && "$UNIVERSAL" == "1" ]]; then
  swift build -c "$CONFIGURATION" --arch arm64 --arch x86_64
  BINARY_PATH=".build/apple/Products/Release/MacPad"
else
  swift build -c "$CONFIGURATION"
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY_PATH" "$MACOS_DIR/MacPad"
chmod +x "$MACOS_DIR/MacPad"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE"
"$ROOT_DIR/scripts/create-app-icon.sh" "$ROOT_DIR/Resources/MacPadLogo.png" "$RESOURCES_DIR/AppIcon.icns"
/usr/bin/xattr -cr "$STAGED_APP"
/usr/bin/codesign --force --sign - "$STAGED_APP" >/dev/null
/usr/bin/codesign --verify --deep --strict "$STAGED_APP"

rm -rf "$APP_DIR"
mkdir -p "$(dirname "$APP_DIR")"
COPYFILE_DISABLE=1 /usr/bin/ditto --norsrc "$STAGED_APP" "$APP_DIR"
/usr/bin/xattr -cr "$APP_DIR"

# File Provider can immediately reapply FinderInfo to workspace copies.
# Verify a metadata-free copy of the final output instead.
COPYFILE_DISABLE=1 /usr/bin/ditto --norsrc "$APP_DIR" "$VERIFY_APP"
/usr/bin/xattr -cr "$VERIFY_APP"
/usr/bin/codesign --verify --deep --strict "$VERIFY_APP"

echo "Built $APP_DIR"
