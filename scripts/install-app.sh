#!/usr/bin/env bash
set -euo pipefail
plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target="${XDG_DATA_HOME:-$HOME/.local/share}/applications/io.github.tbogard.litra-lights.desktop"
icon_target="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps/io.github.tbogard.litra-lights.svg"
if [[ -e "$target" ]] && ! grep -Fxq 'X-Litra-Lights-Managed=true' "$target"; then
  printf 'Refusing to overwrite unmanaged desktop entry: %s\n' "$target" >&2
  exit 1
fi
install -Dm644 "$plugin_dir/assets/io.github.tbogard.litra-lights.desktop" "$target"
install -Dm644 "$plugin_dir/assets/litra-lights.svg" "$icon_target"
printf 'Installed application launcher: %s\n' "$target"
printf 'Installed application icon: %s\n' "$icon_target"
