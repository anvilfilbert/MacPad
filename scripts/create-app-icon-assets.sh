#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "Usage: $0 SOURCE_IMAGE DESTINATION_DIRECTORY" >&2
  exit 64
fi

SOURCE_IMAGE="$1"
DESTINATION_DIRECTORY="$2"
SRGB_PROFILE="/System/Library/ColorSync/Profiles/sRGB Profile.icc"

if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "Source image does not exist: $SOURCE_IMAGE" >&2
  exit 66
fi

if [[ ! -f "$SRGB_PROFILE" ]]; then
  echo "Required sRGB profile does not exist: $SRGB_PROFILE" >&2
  exit 69
fi

mkdir -p "$DESTINATION_DIRECTORY"

generate_icon() {
  local pixels="$1"
  local filename="$2"

  /usr/bin/sips \
    -s format png \
    -z "$pixels" "$pixels" \
    -E "$SRGB_PROFILE" \
    "$SOURCE_IMAGE" \
    --out "$DESTINATION_DIRECTORY/$filename" \
    >/dev/null
}

generate_icon 16 icon_16x16.png
generate_icon 32 icon_16x16'@'2x.png
generate_icon 32 icon_32x32.png
generate_icon 64 icon_32x32'@'2x.png
generate_icon 128 icon_128x128.png
generate_icon 256 icon_128x128'@'2x.png
generate_icon 256 icon_256x256.png
generate_icon 512 icon_256x256'@'2x.png
generate_icon 512 icon_512x512.png
generate_icon 1024 icon_512x512'@'2x.png
