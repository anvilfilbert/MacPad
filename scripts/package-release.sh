#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/MacPad.app"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/MacPad-macOS-universal.zip"
TMP_ZIP="$DIST_DIR/MacPad-macOS-universal.zip.tmp"
CHECKSUM_PATH="$ZIP_PATH.sha256"
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/macpad-release-verify.XXXXXX")"

cleanup() {
  /bin/rm -f "$TMP_ZIP"
  rm -rf "$VERIFY_DIR"
}
trap cleanup EXIT

mkdir -p "$DIST_DIR"
/bin/rm -f "$ZIP_PATH" "$TMP_ZIP" "$CHECKSUM_PATH"
"$ROOT_DIR/scripts/build-app.sh"
(
  cd "$ROOT_DIR/build"
  COPYFILE_DISABLE=1 /usr/bin/zip -qry "$TMP_ZIP" "MacPad.app"
)
/usr/bin/ditto -x -k "$TMP_ZIP" "$VERIFY_DIR"
/usr/bin/codesign --verify --deep --strict "$VERIFY_DIR/MacPad.app"

BUNDLED_LICENSE="$VERIFY_DIR/MacPad.app/Contents/Resources/LICENSE"
if [[ ! -f "$BUNDLED_LICENSE" ]]; then
  echo "Release app does not include LICENSE." >&2
  exit 1
fi
if ! /usr/bin/cmp -s "$ROOT_DIR/LICENSE" "$BUNDLED_LICENSE"; then
  echo "Release app LICENSE does not match the repository license." >&2
  exit 1
fi

ARCHITECTURES="$(/usr/bin/lipo -archs "$VERIFY_DIR/MacPad.app/Contents/MacOS/MacPad")"
if [[ " $ARCHITECTURES " != *" arm64 "* || " $ARCHITECTURES " != *" x86_64 "* ]]; then
  echo "Release binary is not universal: $ARCHITECTURES" >&2
  exit 1
fi

if /usr/bin/zipinfo -1 "$TMP_ZIP" | /usr/bin/grep -Eq '(^|/)(__MACOSX|\.DS_Store)(/|$)|/\._'; then
  echo "Release ZIP contains forbidden macOS metadata files." >&2
  exit 1
fi

if /usr/bin/strings "$VERIFY_DIR/MacPad.app/Contents/MacOS/MacPad" | /usr/bin/grep -Eq '/Users/[^/[:space:]]+|/home/[^/[:space:]]+'; then
  echo "Release binary contains a local user path." >&2
  exit 1
fi

/bin/mv "$TMP_ZIP" "$ZIP_PATH"
(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)
(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 -c "$(basename "$CHECKSUM_PATH")"
)

echo "Packaged $ZIP_PATH"
echo "Wrote checksum $CHECKSUM_PATH"
