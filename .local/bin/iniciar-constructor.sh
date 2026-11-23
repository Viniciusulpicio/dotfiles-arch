#!/bin/bash
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
APP_DIR="$HOME/.local/share/constructor-virtual"
APP_EXE="$APP_DIR/ConstructorVirtualDeCircuitos.exe"

# Sincroniza o DPI do Wine com o monitor atual antes de iniciar
if [ -x "$HOME/.local/bin/wine-dpi-sync.sh" ]; then
    "$HOME/.local/bin/wine-dpi-sync.sh"
fi

cd "$APP_DIR" || exit 1

# Launch with XWayland to ensure child dialogs (ChooseColor) always stay on top
exec wine "$APP_EXE" "$@"
