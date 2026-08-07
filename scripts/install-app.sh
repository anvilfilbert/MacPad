#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/MacPad.app"
INSTALL_DIR="/Applications"
INSTALL_PATH="$INSTALL_DIR/MacPad.app"
STAGED_INSTALL_PATH="$INSTALL_DIR/.MacPad.app.installing"

cleanup() {
  /bin/rm -rf "$STAGED_INSTALL_PATH"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/build-app.sh"
/bin/rm -rf "$STAGED_INSTALL_PATH"
COPYFILE_DISABLE=1 /usr/bin/ditto --norsrc "$APP_DIR" "$STAGED_INSTALL_PATH"
/usr/bin/xattr -cr "$STAGED_INSTALL_PATH"
/usr/bin/codesign --verify --deep --strict "$STAGED_INSTALL_PATH"
/bin/rm -rf "$INSTALL_PATH"
/bin/mv "$STAGED_INSTALL_PATH" "$INSTALL_PATH"
/usr/bin/codesign --verify --deep --strict "$INSTALL_PATH"

echo "Installed $INSTALL_PATH"
