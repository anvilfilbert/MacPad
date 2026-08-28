#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: compile-localizations.sh <catalog-directory> <output-directory>" >&2
    exit 64
fi

CATALOG_DIRECTORY="$1"
OUTPUT_DIRECTORY="$2"
LOCALIZABLE_CATALOG="$CATALOG_DIRECTORY/Localizable.xcstrings"
INFO_PLIST_CATALOG="$CATALOG_DIRECTORY/InfoPlist.xcstrings"

if [ ! -d "$CATALOG_DIRECTORY" ]; then
    echo "Catalog directory does not exist or is not a directory: $CATALOG_DIRECTORY" >&2
    exit 1
fi
if [ ! -d "$OUTPUT_DIRECTORY" ]; then
    echo "Localization output directory does not exist or is not a directory: $OUTPUT_DIRECTORY" >&2
    exit 1
fi

require_catalog() {
    catalog_path="$1"
    catalog_name="$2"
    if [ ! -e "$catalog_path" ]; then
        echo "Required $catalog_name catalog is absent: $catalog_path" >&2
        exit 1
    fi
    if [ ! -f "$catalog_path" ]; then
        echo "Required $catalog_name catalog is not a regular file: $catalog_path" >&2
        exit 1
    fi
    if [ ! -s "$catalog_path" ]; then
        echo "Required $catalog_name catalog is empty: $catalog_path" >&2
        exit 1
    fi
}

require_product() {
    product_path="$1"
    product_name="$2"
    if [ ! -e "$product_path" ]; then
        echo "Localization compilation did not produce $product_name: $product_path" >&2
        exit 1
    fi
    if [ ! -f "$product_path" ]; then
        echo "Compiled $product_name is not a regular file: $product_path" >&2
        exit 1
    fi
    if [ ! -s "$product_path" ]; then
        echo "Compiled $product_name is empty: $product_path" >&2
        exit 1
    fi
}

clear_product() {
    product_path="$1"
    product_name="$2"
    if [ -e "$product_path" ] || [ -L "$product_path" ]; then
        if ! /bin/rm -f "$product_path"; then
            echo "Could not clear old $product_name before localization compilation: $product_path" >&2
            exit 1
        fi
    fi
}

require_catalog "$LOCALIZABLE_CATALOG" "Localizable.xcstrings"
require_catalog "$INFO_PLIST_CATALOG" "InfoPlist.xcstrings"

clear_product "$OUTPUT_DIRECTORY/en.lproj/Localizable.strings" "en.lproj/Localizable.strings"
clear_product "$OUTPUT_DIRECTORY/de.lproj/Localizable.strings" "de.lproj/Localizable.strings"
clear_product "$OUTPUT_DIRECTORY/en.lproj/InfoPlist.strings" "en.lproj/InfoPlist.strings"
clear_product "$OUTPUT_DIRECTORY/de.lproj/InfoPlist.strings" "de.lproj/InfoPlist.strings"

xcrun xcstringstool compile "$LOCALIZABLE_CATALOG" \
    --output-directory "$OUTPUT_DIRECTORY" \
    --serialization-format text
xcrun xcstringstool compile "$INFO_PLIST_CATALOG" \
    --output-directory "$OUTPUT_DIRECTORY" \
    --serialization-format text

require_product "$OUTPUT_DIRECTORY/en.lproj/Localizable.strings" "en.lproj/Localizable.strings"
require_product "$OUTPUT_DIRECTORY/de.lproj/Localizable.strings" "de.lproj/Localizable.strings"
require_product "$OUTPUT_DIRECTORY/en.lproj/InfoPlist.strings" "en.lproj/InfoPlist.strings"
require_product "$OUTPUT_DIRECTORY/de.lproj/InfoPlist.strings" "de.lproj/InfoPlist.strings"
