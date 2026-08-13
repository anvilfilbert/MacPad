#!/bin/bash

set -euo pipefail

if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 <version> <changelog-path>" >&2
    exit 2
fi

version="$1"
changelog_path="$2"

if [[ ! -r "$changelog_path" ]]; then
    echo "Changelog is not readable: $changelog_path" >&2
    exit 3
fi

notes="$(awk -v version="$version" '
    BEGIN { heading = "## " version }
    /^## / {
        if (found) {
            exit
        }
        if ($0 == heading) {
            found = 1
            next
        }
    }
    found && !started && /^[[:space:]]*$/ { next }
    found {
        started = 1
        print
    }
    END {
        if (!found) {
            exit 4
        }
    }
' "$changelog_path")" || {
    echo "Version $version was not found in $changelog_path." >&2
    exit 4
}

if [[ ! "$notes" =~ [^[:space:]] ]]; then
    echo "Version $version has no release notes in $changelog_path." >&2
    exit 5
fi

printf '%s\n' "$notes"
