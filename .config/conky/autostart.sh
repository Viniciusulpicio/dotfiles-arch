#!/bin/bash
# Matar instâncias anteriores do conky
killall conky 2>/dev/null

sleep 1

# Iniciar as duas instâncias do conky desacopladas do terminal (nohup / disown)
DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 nohup conky -c ~/.config/conky/conky.conf >/dev/null 2>&1 &
DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 nohup conky -c ~/.config/conky/neofetch_conky.conf >/dev/null 2>&1 &
disown -a
