#!/usr/bin/env bash
# ==============================================================================
# wine-dpi-sync.sh — Ajusta automaticamente o DPI (LogPixels) do Wine de acordo
# com o monitor ativo (evitando janelas gigantes em 100% ou minúsculas em HiDPI)
# ==============================================================================

WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
USER_REG="$WINEPREFIX/user.reg"

if [ -x "$HOME/.local/bin/monitor-info.sh" ]; then
    eval "$("$HOME/.local/bin/monitor-info.sh")"
fi

DPI_HEX="${WINE_DPI_HEX:-00000060}"

if [ -f "$USER_REG" ]; then
    if grep -q '"LogPixels"=dword:' "$USER_REG"; then
        sed -i "s/\"LogPixels\"=dword:[0-9a-fA-F]*/\"LogPixels\"=dword:${DPI_HEX}/g" "$USER_REG"
    else
        wine reg add "HKCU\\Control Panel\\Desktop" /v LogPixels /t REG_DWORD /d "0x${DPI_HEX}" /f >/dev/null 2>&1 || true
    fi
fi
