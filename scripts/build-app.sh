#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
UNIVERSAL="${UNIVERSAL:-1}"
APP_DIR="$ROOT_DIR/build/MacPad.app"
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/macpad-build.XXXXXX")"
BUILD_SCRATCH_DIR="$STAGE_DIR/swift-build"
STAGED_APP="$STAGE_DIR/MacPad.app"
VERIFY_APP="$STAGE_DIR/verify/MacPad.app"
CONTENTS_DIR="$STAGED_APP/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cleanup() {
  rm -rf "$STAGE_DIR"
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
  require_non_empty_regular_file "$plist_path" "app Info.plist"
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

verify_direct_bundle_contract() {
  local app_path="$1"
  require_non_empty_regular_file "$app_path/Contents/Resources/en.lproj/Localizable.strings" "English Localizable.strings product"
  require_non_empty_regular_file "$app_path/Contents/Resources/de.lproj/Localizable.strings" "German Localizable.strings product"
  require_non_empty_regular_file "$app_path/Contents/Resources/en.lproj/InfoPlist.strings" "English InfoPlist.strings product"
  require_non_empty_regular_file "$app_path/Contents/Resources/de.lproj/InfoPlist.strings" "German InfoPlist.strings product"
  verify_plist_contract "$app_path/Contents/Info.plist"
}

verify_universal_binary() {
  local binary_path="$1"
  local description="$2"
  local architectures
  if ! architectures="$(/usr/bin/lipo -archs "$binary_path" 2>&1)"; then
    echo "Could not inspect architectures for $description at $binary_path: $architectures" >&2
    exit 1
  fi
  if [[ " $architectures " != *" arm64 "* || " $architectures " != *" x86_64 "* ]]; then
    echo "$description is not universal: expected arm64 and x86_64, found '$architectures' at $binary_path." >&2
    exit 1
  fi
}

verify_hardened_runtime() {
  local app_path="$1"
  local description="$2"
  local signature_details
  if ! signature_details="$(/usr/bin/codesign -dv --verbose=4 "$app_path" 2>&1)"; then
    echo "Could not inspect the $description signature at $app_path: $signature_details" >&2
    exit 1
  fi
  if ! /usr/bin/grep -Eq 'flags=.*runtime' <<<"$signature_details"; then
    echo "$description is missing the Hardened Runtime flag at $app_path: $signature_details" >&2
    exit 1
  fi
}

cd "$ROOT_DIR"
SWIFT_BUILD_ARGUMENTS=(--scratch-path "$BUILD_SCRATCH_DIR" -c "$CONFIGURATION")
if [[ "$CONFIGURATION" == "release" && "$UNIVERSAL" == "1" ]]; then
  SWIFT_BUILD_ARGUMENTS+=(--arch arm64 --arch x86_64)
fi
BINARY_DIRECTORY="$(swift build "${SWIFT_BUILD_ARGUMENTS[@]}" --show-bin-path)"
swift build "${SWIFT_BUILD_ARGUMENTS[@]}"
BINARY_PATH="$BINARY_DIRECTORY/MacPad"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY_PATH" "$MACOS_DIR/MacPad"
chmod +x "$MACOS_DIR/MacPad"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE"
"$ROOT_DIR/scripts/create-app-icon.sh" "$ROOT_DIR/Resources/MacPadLogo.png" "$RESOURCES_DIR/AppIcon.icns"
"$ROOT_DIR/scripts/compile-localizations.sh" "$ROOT_DIR/Resources" "$RESOURCES_DIR"
verify_direct_bundle_contract "$STAGED_APP"
if [[ "$CONFIGURATION" == "release" && "$UNIVERSAL" == "1" ]]; then
  verify_universal_binary "$MACOS_DIR/MacPad" "Staged direct-release binary"
fi
/usr/bin/xattr -cr "$STAGED_APP"
/usr/bin/codesign --force --options runtime --sign - "$STAGED_APP" >/dev/null
/usr/bin/codesign --verify --deep --strict "$STAGED_APP"
verify_hardened_runtime "$STAGED_APP" "staged direct app"

rm -rf "$APP_DIR"
mkdir -p "$(dirname "$APP_DIR")"
COPYFILE_DISABLE=1 /usr/bin/ditto --norsrc "$STAGED_APP" "$APP_DIR"
/usr/bin/xattr -cr "$APP_DIR"

# File Provider can immediately reapply FinderInfo to workspace copies.
# Verify a metadata-free copy of the final output instead.
COPYFILE_DISABLE=1 /usr/bin/ditto --norsrc "$APP_DIR" "$VERIFY_APP"
/usr/bin/xattr -cr "$VERIFY_APP"
verify_direct_bundle_contract "$VERIFY_APP"
/usr/bin/codesign --verify --deep --strict "$VERIFY_APP"
verify_hardened_runtime "$VERIFY_APP" "final direct verification copy"
if [[ "$CONFIGURATION" == "release" && "$UNIVERSAL" == "1" ]]; then
  verify_universal_binary "$VERIFY_APP/Contents/MacOS/MacPad" "Final direct-release binary"
fi

echo "Built $APP_DIR"
