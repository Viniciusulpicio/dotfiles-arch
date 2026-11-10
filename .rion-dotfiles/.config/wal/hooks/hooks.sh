#!/bin/bash
~/.local/bin/discord-pywalsync.sh
~/.local/bin/cava-pywalsync.sh
~/.local/bin/wlogout-pywalsync.sh
if command -v pywalfox >/dev/null 2>&1; then
    pywalfox update
fi