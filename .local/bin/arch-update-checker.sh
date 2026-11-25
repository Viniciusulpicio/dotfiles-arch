#!/usr/bin/env bash
/usr/bin/checkupdates 2>/dev/null
if command -v yay &>/dev/null; then
    /usr/bin/yay -Qum 2>/dev/null
fi
if command -v flatpak &>/dev/null; then
    flatpak remote-ls --updates 2>/dev/null
fi
exit 0
