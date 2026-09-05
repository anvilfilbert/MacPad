#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPOSITORY_ROOT="$(dirname -- "$SCRIPT_DIR")"
LOCALIZABLE_CATALOG="$REPOSITORY_ROOT/Resources/Localizable.xcstrings"
TECHNICAL_TERMS_CATALOG="$REPOSITORY_ROOT/Resources/TechnicalTerms.xcstrings"
INFO_PLIST_CATALOG="$REPOSITORY_ROOT/Resources/InfoPlist.xcstrings"
LOCALIZATION_SOURCE="$REPOSITORY_ROOT/Sources/NotepadMacCore/Localization.swift"
TECHNICAL_TERMS_SOURCE="$REPOSITORY_ROOT/Sources/NotepadMacCore/TechnicalTerms.swift"
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR}macpad-localizations.XXXXXX")"

cleanup() {
    case "$TEMP_DIRECTORY" in
        "${TMPDIR}"macpad-localizations.*)
            rm -rf -- "$TEMP_DIRECTORY"
            ;;
        *)
            echo "Refusing to remove unexpected temporary localization path: $TEMP_DIRECTORY" >&2
            return 1
            ;;
    esac
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

xcrun swift "$SCRIPT_DIR/check-localizations.swift" \
    "$LOCALIZABLE_CATALOG" \
    "$TECHNICAL_TERMS_CATALOG" \
    "$INFO_PLIST_CATALOG" \
    "$LOCALIZATION_SOURCE" \
    "$TECHNICAL_TERMS_SOURCE"

xcrun xcstringstool compile "$LOCALIZABLE_CATALOG" \
    --output-directory "$TEMP_DIRECTORY" \
    --serialization-format text
xcrun xcstringstool compile "$TECHNICAL_TERMS_CATALOG" \
    --output-directory "$TEMP_DIRECTORY" \
    --serialization-format text
xcrun xcstringstool compile "$INFO_PLIST_CATALOG" \
    --output-directory "$TEMP_DIRECTORY" \
    --serialization-format text

for locale in en de; do
    localizable_output="$TEMP_DIRECTORY/$locale.lproj/Localizable.strings"
    technical_terms_output="$TEMP_DIRECTORY/$locale.lproj/TechnicalTerms.strings"
    info_plist_output="$TEMP_DIRECTORY/$locale.lproj/InfoPlist.strings"
    if [ ! -s "$localizable_output" ]; then
        echo "Localization compile did not produce a non-empty $localizable_output" >&2
        exit 1
    fi
    if [ ! -s "$info_plist_output" ]; then
        echo "Localization compile did not produce a non-empty $info_plist_output" >&2
        exit 1
    fi
    if [ ! -s "$technical_terms_output" ]; then
        echo "Localization compile did not produce a non-empty $technical_terms_output" >&2
        exit 1
    fi
    echo "$localizable_output"
    echo "$technical_terms_output"
    echo "$info_plist_output"
done
