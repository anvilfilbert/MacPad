#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "Usage: $0 SOURCE_IMAGE OUTPUT_ICNS" >&2
  exit 64
fi

SOURCE_IMAGE="$1"
OUTPUT_ICNS="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/macpad-icon.XXXXXX")"
ICONSET_DIR="$TMP_DIR/AppIcon.iconset"

cleanup() {
  case "$TMP_DIR" in
    "${TMPDIR:-/tmp}"/macpad-icon.*)
      rm -rf -- "$TMP_DIR"
      ;;
    *)
      echo "Refusing to remove unexpected temporary icon path: $TMP_DIR" >&2
      return 1
      ;;
  esac
}
trap cleanup EXIT

mkdir -p "$ICONSET_DIR"
"$SCRIPT_DIR/create-app-icon-assets.sh" "$SOURCE_IMAGE" "$ICONSET_DIR"

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
