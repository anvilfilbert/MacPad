#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_PARENT="${TMPDIR:-/tmp}"
TEMP_ROOT="$(mktemp -d "$TEMP_PARENT/macpad-store-preflight.XXXXXX")"
SOURCE_ICON="$ROOT_DIR/Resources/MacPadLogo.png"
ASSET_CATALOG="$ROOT_DIR/Resources/Assets.xcassets"
APP_ICON_SET="$ASSET_CATALOG/AppIcon.appiconset"
ENTITLEMENTS="$ROOT_DIR/Resources/AppStore.entitlements"

cleanup() {
  case "$TEMP_ROOT" in
    "$TEMP_PARENT"/macpad-store-preflight.*)
      rm -rf -- "$TEMP_ROOT"
      ;;
    *)
      echo "Refusing to remove unexpected preflight temporary path: $TEMP_ROOT" >&2
      return 1
      ;;
  esac
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

fail() {
  echo "App Store preflight failed: $1" >&2
  exit 1
}

plist_value() {
  local plist_path="$1"
  local key_path="$2"
  /usr/bin/plutil -extract "$key_path" raw -o - "$plist_path"
}

require_plist_value() {
  local plist_path="$1"
  local key_path="$2"
  local expected_value="$3"
  local actual_value
  actual_value="$(plist_value "$plist_path" "$key_path")"
  [[ "$actual_value" == "$expected_value" ]] || fail "$plist_path key $key_path is '$actual_value'; expected '$expected_value'"
}

validate_source_icon() {
  local expected_hash="b572225699c060beb2589b9dad3590b221cd3e45736aa6e51b03f0fa531a6a75"
  local actual_hash
  actual_hash="$(/usr/bin/shasum -a 256 "$SOURCE_ICON" | /usr/bin/awk '{print $1}')"

  [[ "$actual_hash" == "$expected_hash" ]] || fail "source icon hash changed: $actual_hash"

  local properties
  properties="$(/usr/bin/sips -g pixelWidth -g pixelHeight -g format -g space -g hasAlpha -g profile "$SOURCE_ICON")"
  [[ "$properties" == *"pixelWidth: 1254"* ]] || fail "source icon width is not 1254 pixels"
  [[ "$properties" == *"pixelHeight: 1254"* ]] || fail "source icon height is not 1254 pixels"
  [[ "$properties" == *"format: png"* ]] || fail "source icon is not PNG"
  [[ "$properties" == *"space: RGB"* ]] || fail "source icon is not RGB"
  [[ "$properties" == *"hasAlpha: no"* ]] || fail "source icon has an alpha channel"
  [[ "$properties" == *"profile: <nil>"* ]] || fail "source icon profile is not the approved untagged baseline"
}

lint_json_catalog() {
  local json_path="$1"
  local plist_name="$2"
  local converted_path="$TEMP_ROOT/$plist_name"

  /usr/bin/plutil -convert xml1 -o "$converted_path" "$json_path"
  /usr/bin/plutil -lint "$converted_path"
}

validate_rendition() {
  local file_path="$1"
  local expected_pixels="$2"
  local properties
  properties="$(/usr/bin/sips -g pixelWidth -g pixelHeight -g format -g space -g hasAlpha -g profile "$file_path")"

  [[ "$properties" == *"pixelWidth: $expected_pixels"* ]] || fail "$file_path width is not $expected_pixels pixels"
  [[ "$properties" == *"pixelHeight: $expected_pixels"* ]] || fail "$file_path height is not $expected_pixels pixels"
  [[ "$properties" == *"format: png"* ]] || fail "$file_path is not PNG"
  [[ "$properties" == *"space: RGB"* ]] || fail "$file_path is not RGB"
  [[ "$properties" == *"hasAlpha: no"* ]] || fail "$file_path has an alpha channel"
  [[ "$properties" == *"profile: sRGB IEC61966-2.1"* ]] || fail "$file_path does not use the required sRGB IEC61966-2.1 profile"
}

validate_icon_catalog() {
  [[ -d "$ASSET_CATALOG" ]] || fail "missing asset catalog: $ASSET_CATALOG"
  [[ -d "$APP_ICON_SET" ]] || fail "missing AppIcon set: $APP_ICON_SET"

  local root_contents="$ASSET_CATALOG/Contents.json"
  local icon_contents="$APP_ICON_SET/Contents.json"
  [[ -s "$root_contents" ]] || fail "missing asset catalog metadata: $root_contents"
  [[ -s "$icon_contents" ]] || fail "missing AppIcon metadata: $icon_contents"

  lint_json_catalog "$root_contents" AssetCatalog.plist
  lint_json_catalog "$icon_contents" AppIcon.plist
  require_plist_value "$root_contents" info.author xcode
  require_plist_value "$root_contents" info.version 1
  require_plist_value "$icon_contents" info.author xcode
  require_plist_value "$icon_contents" info.version 1
  require_plist_value "$icon_contents" images 10

  local expected_filenames=(
    icon_16x16.png
    icon_16x16'@'2x.png
    icon_32x32.png
    icon_32x32'@'2x.png
    icon_128x128.png
    icon_128x128'@'2x.png
    icon_256x256.png
    icon_256x256'@'2x.png
    icon_512x512.png
    icon_512x512'@'2x.png
  )
  local expected_sizes=(16x16 16x16 32x32 32x32 128x128 128x128 256x256 256x256 512x512 512x512)
  local expected_scales=(1x 2x 1x 2x 1x 2x 1x 2x 1x 2x)
  local expected_pixels=(16 32 32 64 128 256 256 512 512 1024)
  local index

  for index in "${!expected_filenames[@]}"; do
    require_plist_value "$icon_contents" "images.$index.filename" "${expected_filenames[$index]}"
    require_plist_value "$icon_contents" "images.$index.idiom" mac
    require_plist_value "$icon_contents" "images.$index.scale" "${expected_scales[$index]}"
    require_plist_value "$icon_contents" "images.$index.size" "${expected_sizes[$index]}"
    validate_rendition "$APP_ICON_SET/${expected_filenames[$index]}" "${expected_pixels[$index]}"
  done

  local png_count
  png_count="$(/usr/bin/find "$APP_ICON_SET" -maxdepth 1 -type f -name '*.png' -print | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')"
  [[ "$png_count" == "10" ]] || fail "AppIcon set contains $png_count PNG files; expected 10"

  local regenerated_directory="$TEMP_ROOT/RegeneratedIcons"
  "$ROOT_DIR/scripts/create-app-icon-assets.sh" "$SOURCE_ICON" "$regenerated_directory"
  for index in "${!expected_filenames[@]}"; do
    /usr/bin/cmp -s "$APP_ICON_SET/${expected_filenames[$index]}" "$regenerated_directory/${expected_filenames[$index]}" || fail "committed icon is not deterministic: ${expected_filenames[$index]}"
  done
}

validate_entitlements() {
  /usr/bin/plutil -lint "$ENTITLEMENTS"

  local converted_entitlements="$TEMP_ROOT/AppStore.entitlements.plist"
  /usr/bin/plutil -convert xml1 -o "$converted_entitlements" "$ENTITLEMENTS"
  local key_count
  key_count="$(/usr/bin/grep -c '<key>' "$converted_entitlements" | /usr/bin/tr -d '[:space:]')"
  [[ "$key_count" == "4" ]] || fail "Store entitlements contain $key_count keys; expected exactly 4"

  local entitlement_keys=(
    com.apple.security.app-sandbox
    com.apple.security.files.bookmarks.app-scope
    com.apple.security.files.user-selected.read-write
    com.apple.security.print
  )
  local entitlement_key
  local entitlement_value
  for entitlement_key in "${entitlement_keys[@]}"; do
    entitlement_value="$(/usr/libexec/PlistBuddy -c "Print :$entitlement_key" "$ENTITLEMENTS")"
    [[ "$entitlement_value" == "true" ]] || fail "entitlement $entitlement_key is not true"
  done
}

build_native_channel() {
  local channel_name="$1"
  local scheme_name="$2"
  local configuration_name="$3"
  local channel_directory="$TEMP_ROOT/$channel_name"
  local derived_data="$channel_directory/DerivedData"
  local source_packages="$channel_directory/SourcePackages"
  local build_log="$channel_directory/Build.log"
  local settings_path="$channel_directory/BuildSettings.txt"

  mkdir -p "$derived_data" "$source_packages"

  if ! xcodebuild \
    -project "$ROOT_DIR/MacPad.xcodeproj" \
    -scheme "$scheme_name" \
    -configuration "$configuration_name" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    -clonedSourcePackagesDirPath "$source_packages" \
    CODE_SIGNING_ALLOWED=NO \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    SWIFT_SUPPRESS_WARNINGS=NO \
    build \
    >"$build_log" 2>&1; then
    /bin/cat "$build_log" >&2
    fail "$channel_name native build failed"
  fi

  if ! xcodebuild \
    -project "$ROOT_DIR/MacPad.xcodeproj" \
    -scheme "$scheme_name" \
    -configuration "$configuration_name" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    -clonedSourcePackagesDirPath "$source_packages" \
    CODE_SIGNING_ALLOWED=NO \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    SWIFT_SUPPRESS_WARNINGS=NO \
    -showBuildSettings \
    >"$settings_path" 2>&1; then
    /bin/cat "$settings_path" >&2
    fail "$channel_name build-settings resolution failed"
  fi

  local app_path="$derived_data/Build/Products/$configuration_name/MacPad.app"
  [[ -d "$app_path" ]] || fail "$channel_name build did not produce $app_path"

  local signature_directory
  signature_directory="$(/usr/bin/find "$app_path" -type d -name _CodeSignature -print -quit)"
  [[ -z "$signature_directory" ]] || fail "$channel_name unsigned build unexpectedly contains a signature directory: $signature_directory"

  echo "$app_path|$settings_path"
}

build_setting() {
  local settings_path="$1"
  local setting_name="$2"
  local setting_line
  setting_line="$(LC_ALL=C /usr/bin/grep -m 1 -E "^[[:space:]]*$setting_name[[:space:]]*=" "$settings_path")" || fail "resolved build setting is missing: $setting_name"
  echo "$setting_line" | /usr/bin/sed -E "s/^[[:space:]]*$setting_name[[:space:]]*=[[:space:]]*//"
}

require_build_setting() {
  local settings_path="$1"
  local setting_name="$2"
  local expected_value="$3"
  local actual_value
  actual_value="$(build_setting "$settings_path" "$setting_name")"
  [[ "$actual_value" == "$expected_value" ]] || fail "resolved $setting_name is '$actual_value'; expected '$expected_value'"
}

require_unset_or_empty_build_setting() {
  local settings_path="$1"
  local setting_name="$2"
  local setting_line
  local grep_status=0

  setting_line="$(LC_ALL=C /usr/bin/grep -m 1 -E "^[[:space:]]*$setting_name[[:space:]]*=" "$settings_path")" || grep_status=$?
  case "$grep_status" in
    0)
      ;;
    1)
      return 0
      ;;
    *)
      fail "resolved build-setting lookup failed with grep status $grep_status for $setting_name in $settings_path"
      ;;
  esac

  local actual_value
  actual_value="$(echo "$setting_line" | /usr/bin/sed -E "s/^[[:space:]]*$setting_name[[:space:]]*=[[:space:]]*//")"
  [[ -z "$actual_value" ]] || fail "resolved $setting_name is '$actual_value'; expected it to be unset or empty"
}

validate_common_build_settings() {
  local settings_path="$1"
  require_unset_or_empty_build_setting "$settings_path" DEVELOPMENT_TEAM
  require_build_setting "$settings_path" ASSETCATALOG_COMPILER_APPICON_NAME AppIcon
  require_build_setting "$settings_path" SWIFT_TREAT_WARNINGS_AS_ERRORS YES
  require_build_setting "$settings_path" GCC_TREAT_WARNINGS_AS_ERRORS YES
  require_build_setting "$settings_path" SWIFT_VERSION 6.0
  require_build_setting "$settings_path" MACOSX_DEPLOYMENT_TARGET 14.0
  require_build_setting "$settings_path" ENABLE_HARDENED_RUNTIME YES
}

validate_localization_products() {
  local app_path="$1"
  local channel_name="$2"
  local locale
  local table

  for locale in en de; do
    for table in Localizable TechnicalTerms InfoPlist; do
      local product_path="$app_path/Contents/Resources/$locale.lproj/$table.strings"
      [[ -s "$product_path" ]] || fail "$channel_name build is missing a non-empty $locale.lproj/$table.strings product: $product_path"
    done
  done
}

validate_channel_builds() {
  local direct_result
  local store_result
  direct_result="$(build_native_channel Direct MacPad-Direct DirectRelease)"
  store_result="$(build_native_channel AppStore MacPad-AppStore AppStore)"

  local direct_app="${direct_result%%|*}"
  local direct_settings="${direct_result#*|}"
  local store_app="${store_result%%|*}"
  local store_settings="${store_result#*|}"

  validate_common_build_settings "$direct_settings"
  validate_common_build_settings "$store_settings"
  require_build_setting "$direct_settings" SWIFT_ACTIVE_COMPILATION_CONDITIONS MACPAD_DIRECT
  require_build_setting "$store_settings" SWIFT_ACTIVE_COMPILATION_CONDITIONS MACPAD_APP_STORE
  require_unset_or_empty_build_setting "$direct_settings" CODE_SIGN_ENTITLEMENTS
  require_build_setting "$store_settings" CODE_SIGN_ENTITLEMENTS Resources/AppStore.entitlements

  local direct_executable="$direct_app/Contents/MacOS/MacPad"
  [[ -s "$direct_executable" ]] || fail "Direct build executable is missing or empty: $direct_executable"
  /usr/bin/strings -a "$direct_executable" | /usr/bin/grep -F 'github.com/anvilfilbert/MacPad' >/dev/null || fail "Direct executable does not retain the GitHub transition route"
  /usr/bin/strings -a "$direct_executable" | /usr/bin/grep -F '/releases/latest' >/dev/null || fail "Direct executable does not retain the update transition route"
  /usr/bin/strings -a "$direct_executable" | /usr/bin/grep -F 'https://macpad.net/support' >/dev/null || fail "Direct executable is missing the approved support route"
  /usr/bin/strings -a "$direct_executable" | /usr/bin/grep -F 'mailto:support@macpad.net' >/dev/null || fail "Direct executable is missing the approved support email"
  /usr/bin/strings -a "$direct_executable" | /usr/bin/grep -F 'https://macpad.net/privacy' >/dev/null || fail "Direct executable is missing the approved privacy route"

  [[ -d "$store_app" ]] || fail "Store build app is missing: $store_app"
  local store_executable="$store_app/Contents/MacOS/MacPad"
  [[ -s "$store_executable" ]] || fail "Store build executable is missing or empty: $store_executable"
  /usr/bin/strings -a "$store_executable" | /usr/bin/grep -F 'https://macpad.net/support' >/dev/null || fail "Store executable is missing the approved support route"
  /usr/bin/strings -a "$store_executable" | /usr/bin/grep -F 'mailto:support@macpad.net' >/dev/null || fail "Store executable is missing the approved support email"
  /usr/bin/strings -a "$store_executable" | /usr/bin/grep -F 'https://macpad.net/privacy' >/dev/null || fail "Store executable is missing the approved privacy route"
  validate_localization_products "$direct_app" DirectRelease
  validate_localization_products "$store_app" AppStore
}

cd "$ROOT_DIR"

validate_source_icon
validate_icon_catalog
validate_entitlements
./scripts/verify-public-repo.sh
./scripts/check-localizations.sh
validate_channel_builds
./scripts/archive-local.sh
git diff --check
git diff --cached --check

echo "Credential-free unsigned App Store preflight passed. Signing, export, distribution, and App Store readiness remain unverified."
