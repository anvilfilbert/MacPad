#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")}"
APP_DIR="$ROOT_DIR/build/MacPad.app"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/MacPad-${VERSION}-macOS-universal.zip"
TMP_ZIP="$DIST_DIR/MacPad-${VERSION}-macOS-universal.zip.tmp"
CHECKSUM_PATH="$ZIP_PATH.sha256"
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/macpad-release-verify.XXXXXX")"

cleanup() {
  rm -rf "$VERIFY_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/build-app.sh"
mkdir -p "$DIST_DIR"
/bin/rm -f "$ZIP_PATH" "$TMP_ZIP" "$CHECKSUM_PATH"
(
  cd "$ROOT_DIR/build"
  COPYFILE_DISABLE=1 /usr/bin/zip -qry "$TMP_ZIP" "MacPad.app"
)
/bin/mv "$TMP_ZIP" "$ZIP_PATH"
(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)
/usr/bin/ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
/usr/bin/codesign --verify --deep --strict "$VERIFY_DIR/MacPad.app"

echo "Packaged $ZIP_PATH"
echo "Wrote checksum $CHECKSUM_PATH"
