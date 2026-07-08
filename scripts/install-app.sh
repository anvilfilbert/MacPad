#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/MacPad.app"
INSTALL_DIR="/Applications"

"$ROOT_DIR/scripts/build-app.sh"
ditto "$APP_DIR" "$INSTALL_DIR/MacPad.app"

echo "Installed $INSTALL_DIR/MacPad.app"
