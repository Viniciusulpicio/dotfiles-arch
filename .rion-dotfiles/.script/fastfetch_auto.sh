#!/bin/bash

# ==== Fastfetch Auto ====

CFG="$HOME/.config/fastfetch/config.jsonc"
FLAG="$HOME/.config/fastfetch/.reload_flag"

clear
tput civis   # esconder cursor

cleanup() {
    tput cnorm
    clear
}
trap cleanup INT TERM EXIT

fastfetch
last_mod=$(stat -c %Y "$CFG" 2>/dev/null || echo 0)

while true; do
    # tecla q sai
    if read -r -n 1 -t 1 key; then
        [[ $key == "q" ]] && break
    fi

    # detecta mudança no config ou flag
    current_mod=$(stat -c %Y "$CFG" 2>/dev/null || echo 0)
    if [[ $current_mod -ne $last_mod ]] || [[ -f "$FLAG" ]]; then
        clear
        fastfetch
        rm -f "$FLAG"
        last_mod=$current_mod
    fi
done
