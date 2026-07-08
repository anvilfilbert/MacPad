#!/usr/bin/env bash
set -euo pipefail

SOURCE_IMAGE="$1"
OUTPUT_ICNS="$2"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/macpad-icon.XXXXXX")"
ICONSET_DIR="$TMP_DIR/AppIcon.iconset"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$ICONSET_DIR"

create_icon() {
  local points="$1"
  local scale="$2"
  local pixels=$((points * scale))
  local suffix=""

  if [[ "$scale" -eq 2 ]]; then
    suffix="@2x"
  fi

  /usr/bin/sips -s format png -z "$pixels" "$pixels" "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_${points}x${points}${suffix}.png" >/dev/null
}

create_icon 16 1
create_icon 16 2
create_icon 32 1
create_icon 32 2
create_icon 128 1
create_icon 128 2
create_icon 256 1
create_icon 256 2
create_icon 512 1
create_icon 512 2

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
