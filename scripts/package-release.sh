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

require_non_empty_regular_file() {
  local path="$1"
  local description="$2"
  if [[ ! -f "$path" ]]; then
    echo "Missing required $description: $path" >&2
    exit 1
  fi
  if [[ ! -s "$path" ]]; then
    echo "Required $description is empty: $path" >&2
    exit 1
  fi
}

require_plist_string() {
  local plist_path="$1"
  local key="$2"
  local expected_value="$3"
  local observed_value
  if ! observed_value="$(/usr/bin/plutil -extract "$key" raw -expect string "$plist_path" 2>&1)"; then
    echo "Could not read required string '$key' from $plist_path: $observed_value" >&2
    exit 1
  fi
  if [[ "$observed_value" != "$expected_value" ]]; then
    echo "Invalid '$key' in $plist_path: expected '$expected_value', found '$observed_value'." >&2
    exit 1
  fi
}

verify_plist_contract() {
  local plist_path="$1"
  local localization_count
  require_non_empty_regular_file "$plist_path" "extracted app Info.plist"
  require_plist_string "$plist_path" "CFBundleDevelopmentRegion" "en"
  require_plist_string "$plist_path" "CFBundleIdentifier" "local.macpad.app"
  require_plist_string "$plist_path" "LSApplicationCategoryType" "public.app-category.utilities"
  if ! localization_count="$(/usr/bin/plutil -extract CFBundleLocalizations raw -expect array "$plist_path" 2>&1)"; then
    echo "Could not read required array 'CFBundleLocalizations' from $plist_path: $localization_count" >&2
    exit 1
  fi
  if [[ "$localization_count" != "2" ]]; then
    echo "Invalid 'CFBundleLocalizations' in $plist_path: expected exactly 2 entries [en, de], found $localization_count." >&2
    exit 1
  fi
  require_plist_string "$plist_path" "CFBundleLocalizations.0" "en"
  require_plist_string "$plist_path" "CFBundleLocalizations.1" "de"
}

verify_localization_products() {
  local app_path="$1"
  require_non_empty_regular_file "$app_path/Contents/Resources/en.lproj/Localizable.strings" "extracted English Localizable.strings product"
  require_non_empty_regular_file "$app_path/Contents/Resources/de.lproj/Localizable.strings" "extracted German Localizable.strings product"
  require_non_empty_regular_file "$app_path/Contents/Resources/en.lproj/InfoPlist.strings" "extracted English InfoPlist.strings product"
  require_non_empty_regular_file "$app_path/Contents/Resources/de.lproj/InfoPlist.strings" "extracted German InfoPlist.strings product"
}

verify_hardened_runtime() {
  local app_path="$1"
  local signature_details
  if ! signature_details="$(/usr/bin/codesign -dv --verbose=4 "$app_path" 2>&1)"; then
    echo "Could not inspect the extracted app signature at $app_path: $signature_details" >&2
    exit 1
  fi
  if ! /usr/bin/grep -Eq 'flags=.*runtime' <<<"$signature_details"; then
    echo "Extracted app is missing the Hardened Runtime flag at $app_path: $signature_details" >&2
    exit 1
  fi
}

verify_universal_binary() {
  local binary_path="$1"
  local architectures
  if ! architectures="$(/usr/bin/lipo -archs "$binary_path" 2>&1)"; then
    echo "Could not inspect extracted release architectures at $binary_path: $architectures" >&2
    exit 1
  fi
  if [[ " $architectures " != *" arm64 "* || " $architectures " != *" x86_64 "* ]]; then
    echo "Extracted release binary is not universal: expected arm64 and x86_64, found '$architectures' at $binary_path." >&2
    exit 1
  fi
}

mkdir -p "$DIST_DIR"
/bin/rm -f "$ZIP_PATH" "$TMP_ZIP" "$CHECKSUM_PATH"
CONFIGURATION=release UNIVERSAL=1 "$ROOT_DIR/scripts/build-app.sh"
(
  cd "$ROOT_DIR/build"
  COPYFILE_DISABLE=1 /usr/bin/zip -qry "$TMP_ZIP" "MacPad.app"
)
/usr/bin/ditto -x -k "$TMP_ZIP" "$VERIFY_DIR"
EXTRACTED_APP="$VERIFY_DIR/MacPad.app"
/usr/bin/codesign --verify --deep --strict "$EXTRACTED_APP"
verify_localization_products "$EXTRACTED_APP"
verify_plist_contract "$EXTRACTED_APP/Contents/Info.plist"
verify_hardened_runtime "$EXTRACTED_APP"

BUNDLED_LICENSE="$EXTRACTED_APP/Contents/Resources/LICENSE"
if [[ ! -f "$BUNDLED_LICENSE" ]]; then
  echo "Release app does not include LICENSE." >&2
  exit 1
fi
if ! /usr/bin/cmp -s "$ROOT_DIR/LICENSE" "$BUNDLED_LICENSE"; then
  echo "Release app LICENSE does not match the repository license." >&2
  exit 1
fi

verify_universal_binary "$EXTRACTED_APP/Contents/MacOS/MacPad"

if /usr/bin/zipinfo -1 "$TMP_ZIP" | /usr/bin/grep -Eq '(^|/)(__MACOSX|\.DS_Store)(/|$)|/\._'; then
  echo "Release ZIP contains forbidden macOS metadata files." >&2
  exit 1
fi

if /usr/bin/strings "$EXTRACTED_APP/Contents/MacOS/MacPad" | /usr/bin/grep -Eq '/Users/[^/[:space:]]+|/home/[^/[:space:]]+'; then
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
