#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/lib/subses-app"

mkdir -p "$BIN_DIR" "$APP_DIR"

cp -a "$ROOT/.local/bin/." "$BIN_DIR/"
cp -a "$ROOT/.local/lib/subses-app/." "$APP_DIR/"

chmod +x "$BIN_DIR/subses" "$BIN_DIR/subses.sh" "$BIN_DIR/VSub.sh" "$BIN_DIR/youtube-subses" 2>/dev/null || true
chmod +x "$APP_DIR"/*.sh 2>/dev/null || true

# Dinle & Yaz and VSub keep their virtual environments next to their scripts.
# The browser extension is installed under the application data directory.

echo
echo "SUBSES kuruldu."
echo "CLI:        $BIN_DIR/subses"
echo "GUI:        $BIN_DIR/subses.sh"
echo "VSub:       $BIN_DIR/VSub.sh"
echo "Dinle Yaz:  $BIN_DIR/dinle.py"
echo "App:        $APP_DIR"
echo "Eklenti:    $APP_DIR/eklenti"
echo

case ":${PATH:-}:" in
  *":$BIN_DIR:"*) ;;
  *) echo "PATH içinde $BIN_DIR bulunmuyor. Gerekirse: export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac
