#!/bin/bash
# Matar instâncias anteriores do conky
killall conky 2>/dev/null

sleep 1

# Detectar monitor atual para ajustar margens (gap_x / gap_y) proporcionalmente
if [ -x "$HOME/.local/bin/monitor-info.sh" ]; then
    eval "$("$HOME/.local/bin/monitor-info.sh")"
fi
LOG_W="${LOG_W:-1920}"
LOG_H="${LOG_H:-1080}"

GAP_X_RIGHT=$(( LOG_W * 3 / 100 ))
GAP_Y_RIGHT=$(( LOG_H * 5 / 100 ))
GAP_X_LEFT=$(( LOG_W * 26 / 1000 ))
GAP_Y_LEFT=$(( LOG_H * 46 / 1000 ))

export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Iniciar as duas instâncias do conky ajustadas ao monitor atual
nohup conky -c "$HOME/.config/conky/conky.conf" -x "$GAP_X_RIGHT" -y "$GAP_Y_RIGHT" >/dev/null 2>&1 &
nohup conky -c "$HOME/.config/conky/neofetch_conky.conf" -x "$GAP_X_LEFT" -y "$GAP_Y_LEFT" >/dev/null 2>&1 &
disown -a
