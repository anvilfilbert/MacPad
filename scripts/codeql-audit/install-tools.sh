#!/usr/bin/env bash
# Pinned public downloads; no credentials, package cache, or global installation.
set -euo pipefail
AUDIT_TOOLS="$1"
mkdir "$AUDIT_TOOLS"

download_verified() {
  local url="$1" destination="$2" digest="$3"
  curl --fail --location --show-error --retry 3 --retry-all-errors \
    --output "$destination" "$url"
  echo "$digest  $destination" | shasum -a 256 --check
}

download_verified \
  https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.27.2/codeql-bundle-swift-osx64.tar.zst \
  "$AUDIT_TOOLS/codeql.tar.zst" \
  25a08dfd23997ccf6374b5a70d9aa27a510e027f1b5aed60e1a653f8a3596375
tar --zstd -xf "$AUDIT_TOOLS/codeql.tar.zst" -C "$AUDIT_TOOLS"

# Trail of Bits skill quality/suite guards, immutable upstream revision + hashes.
GUARD_ROOT=https://raw.githubusercontent.com/trailofbits/skills/304c81a8cefb6e3c029ebd0d12940ccf0713eccb/plugins/static-analysis/skills/codeql/scripts
download_verified "$GUARD_ROOT/check_db_quality.py" "$AUDIT_TOOLS/check_db_quality.py" \
  fca99a149eb4689730b7d3a3314527a5716823fb5f19b6b79114f4949b726c36
download_verified "$GUARD_ROOT/verify_query_suite.py" "$AUDIT_TOOLS/verify_query_suite.py" \
  ad1bb120201c9af5ae199d3d36a727ba12d897162f817045e8a8006e691154f8
