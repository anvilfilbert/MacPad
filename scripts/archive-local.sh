#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_PARENT="${TMPDIR:-/tmp}"
TEMP_ROOT="$(mktemp -d "$TEMP_PARENT/macpad-store-archive.XXXXXX")"
DERIVED_DATA="$TEMP_ROOT/DerivedData"
SOURCE_PACKAGES="$TEMP_ROOT/SourcePackages"
ARCHIVE_PATH="$TEMP_ROOT/MacPad.xcarchive"
VERIFICATION_DIRECTORY="$TEMP_ROOT/Verification"
ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/MacPad.app"
VERIFICATION_APP="$VERIFICATION_DIRECTORY/MacPad.app"

cleanup() {
  case "$TEMP_ROOT" in
    "$TEMP_PARENT"/macpad-store-archive.*)
      rm -rf -- "$TEMP_ROOT"
      ;;
    *)
      echo "Refusing to remove unexpected archive temporary path: $TEMP_ROOT" >&2
      return 1
      ;;
  esac
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

fail() {
  echo "Unsigned archive verification failed: $1" >&2
  exit 1
}

require_nonempty_file() {
  local file_path="$1"
  [[ -s "$file_path" ]] || fail "required file is missing or empty: $file_path"
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
  [[ "$actual_value" == "$expected_value" ]] || fail "$key_path is '$actual_value'; expected '$expected_value'"
}

scan_file() {
  local file_path="$1"
  local customer_route_pattern='github[.]com|githubusercontent[.]com|sourceforge[.]net|anvilfilbert[.]github[.]io|deepwiki[.]com|/releases/latest'
  local email_separator='@'
  local approved_icon_filenames_pattern='^(icon_16x16'"$email_separator"'2x[.]png|icon_32x32'"$email_separator"'2x[.]png|icon_128x128'"$email_separator"'2x[.]png|icon_256x256'"$email_separator"'2x[.]png|icon_512x512'"$email_separator"'2x[.]png)$'
  local private_content_pattern='(/U''sers/[^/[:space:]]+|/ho''me/[^/[:space:]]+|[A-Za-z0-9._%+-]+'"$email_separator"'[A-Za-z0-9.-]+[.][A-Za-z]{2,}|github_''pat_[A-Za-z0-9_]+|gh[opusr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA |EC |OPENSSH )?PRIVATE ''KEY|(^|[^0-9])(10[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}|192[.]168[.][0-9]{1,3}[.][0-9]{1,3}|172[.](1[6-9]|2[0-9]|3[01])[.][0-9]{1,3}[.][0-9]{1,3})([^0-9]|$))'
  local strings_output
  local privacy_strings_output
  local route_status=0
  local filter_status=0
  local privacy_status=0

  if ! strings_output="$(mktemp "$TEMP_ROOT/scanned-strings.XXXXXX")"; then
    fail "could not create temporary strings output for Store artifact file: $file_path"
  fi

  if ! /usr/bin/strings -a "$file_path" >"$strings_output"; then
    fail "could not extract strings from Store artifact file: $file_path"
  fi

  LC_ALL=C /usr/bin/grep -Ei "$customer_route_pattern" "$strings_output" >/dev/null || route_status=$?
  case "$route_status" in
    0)
      fail "customer-route token found in Store artifact file: $file_path"
      ;;
    1)
      ;;
    *)
      fail "customer-route scan failed with grep status $route_status for Store artifact file: $file_path"
      ;;
  esac

  if ! privacy_strings_output="$(mktemp "$TEMP_ROOT/privacy-strings.XXXXXX")"; then
    fail "could not create temporary privacy-scan input for Store artifact file: $file_path"
  fi

  LC_ALL=C /usr/bin/grep -Ev "$approved_icon_filenames_pattern" "$strings_output" >"$privacy_strings_output" || filter_status=$?
  case "$filter_status" in
    0 | 1)
      ;;
    *)
      fail "approved icon filename filter failed with grep status $filter_status for Store artifact file: $file_path"
      ;;
  esac

  LC_ALL=C /usr/bin/grep -E "$private_content_pattern" "$privacy_strings_output" >/dev/null || privacy_status=$?
  case "$privacy_status" in
    0)
      fail "private path, email, credential, private key, or private IP found in Store artifact file: $file_path"
      ;;
    1)
      ;;
    *)
      fail "private-content scan failed with grep status $privacy_status for Store artifact file: $file_path"
      ;;
  esac
}

mkdir -p "$DERIVED_DATA" "$SOURCE_PACKAGES" "$VERIFICATION_DIRECTORY"

xcodebuild \
  -project "$ROOT_DIR/MacPad.xcodeproj" \
  -scheme MacPad-AppStore \
  -configuration AppStore \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  SWIFT_SUPPRESS_WARNINGS=NO \
  archive

[[ -d "$ARCHIVED_APP" ]] || fail "archive did not contain Products/Applications/MacPad.app"

archive_signature_directory="$(/usr/bin/find "$ARCHIVED_APP" -type d -name _CodeSignature -print -quit)"
[[ -z "$archive_signature_directory" ]] || fail "unsigned archive unexpectedly contains a signature directory: $archive_signature_directory"

/usr/bin/ditto "$ARCHIVED_APP" "$VERIFICATION_APP"

verification_signature_directory="$(/usr/bin/find "$VERIFICATION_APP" -type d -name _CodeSignature -print -quit)"
[[ -z "$verification_signature_directory" ]] || fail "unsigned verification copy unexpectedly contains a signature directory: $verification_signature_directory"

EXECUTABLE="$VERIFICATION_APP/Contents/MacOS/MacPad"
INFO_PLIST="$VERIFICATION_APP/Contents/Info.plist"
RESOURCE_DIRECTORY="$VERIFICATION_APP/Contents/Resources"

require_nonempty_file "$EXECUTABLE"
require_nonempty_file "$INFO_PLIST"
require_nonempty_file "$RESOURCE_DIRECTORY/AppIcon.icns"
require_nonempty_file "$RESOURCE_DIRECTORY/LICENSE"
require_nonempty_file "$RESOURCE_DIRECTORY/en.lproj/Localizable.strings"
require_nonempty_file "$RESOURCE_DIRECTORY/de.lproj/Localizable.strings"
require_nonempty_file "$RESOURCE_DIRECTORY/en.lproj/InfoPlist.strings"
require_nonempty_file "$RESOURCE_DIRECTORY/de.lproj/InfoPlist.strings"

/usr/bin/plutil -lint "$INFO_PLIST"
/usr/bin/cmp -s "$ROOT_DIR/LICENSE" "$RESOURCE_DIRECTORY/LICENSE" || fail "bundled LICENSE differs from repository LICENSE"

require_plist_value "$INFO_PLIST" CFBundleIdentifier local.macpad.app
require_plist_value "$INFO_PLIST" CFBundleShortVersionString 1.3.1
require_plist_value "$INFO_PLIST" CFBundleVersion 15
require_plist_value "$INFO_PLIST" LSApplicationCategoryType public.app-category.utilities
require_plist_value "$INFO_PLIST" LSMinimumSystemVersion 14.0
require_plist_value "$INFO_PLIST" CFBundleDevelopmentRegion en
require_plist_value "$INFO_PLIST" CFBundleLocalizations 2
require_plist_value "$INFO_PLIST" CFBundleLocalizations.0 en
require_plist_value "$INFO_PLIST" CFBundleLocalizations.1 de
require_plist_value "$INFO_PLIST" CFBundleDocumentTypes 1
require_plist_value "$INFO_PLIST" CFBundleDocumentTypes.0.CFBundleTypeName 'Plain Text'
require_plist_value "$INFO_PLIST" CFBundleDocumentTypes.0.CFBundleTypeRole Editor
require_plist_value "$INFO_PLIST" CFBundleDocumentTypes.0.LSItemContentTypes 2
require_plist_value "$INFO_PLIST" CFBundleDocumentTypes.0.LSItemContentTypes.0 public.plain-text
require_plist_value "$INFO_PLIST" CFBundleDocumentTypes.0.LSItemContentTypes.1 public.text

architectures="$(/usr/bin/lipo -archs "$EXECUTABLE" | /usr/bin/tr ' ' '\n' | LC_ALL=C /usr/bin/sort | /usr/bin/paste -sd ' ' -)"
[[ "$architectures" == "arm64 x86_64" ]] || fail "executable architectures are '$architectures'; expected 'arm64 x86_64'"

scan_file "$EXECUTABLE"
while IFS= read -r -d '' resource_path; do
  scan_file "$resource_path"
done < <(/usr/bin/find "$RESOURCE_DIRECTORY" -type f -print0)

echo "Unsigned archive verification passed. No signing, export, distribution, or App Store readiness was verified."
