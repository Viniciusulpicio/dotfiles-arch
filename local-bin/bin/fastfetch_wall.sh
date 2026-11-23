#!/bin/bash
# Aguarda o GNOME carregar
sleep 5

# Detecta a resolução lógica do monitor ativo para dimensionar os terminais proporcionalmente
if [ -x "$HOME/.local/bin/monitor-info.sh" ]; then
    eval "$("$HOME/.local/bin/monitor-info.sh")"
fi
LOG_W="${LOG_W:-1920}"
LOG_H="${LOG_H:-1080}"

COLS=$(( LOG_W / 22 ))
[ "$COLS" -lt 70 ] && COLS=70
[ "$COLS" -gt 110 ] && COLS=110

ROWS=$(( LOG_H / 42 ))
[ "$ROWS" -lt 20 ] && ROWS=20
[ "$ROWS" -gt 32 ] && ROWS=32

MARGIN_X=$(( LOG_W * 3 / 100 ))
MARGIN_Y=$(( LOG_H * 7 / 100 ))

# Terminal 1: ffa (Fastfetch)
gnome-terminal --class ffa_term --geometry="${COLS}x${ROWS}+${MARGIN_X}+${MARGIN_Y}" -- bash -c "ffa; exec bash"

# Aguarda um pouco para não sobrepor
sleep 1

# Terminal 2: cava (visualizador de áudio)
gnome-terminal --class cava_term --geometry="${COLS}x${ROWS}-${MARGIN_X}+${MARGIN_Y}" -- bash -c "cava; exec bash"
