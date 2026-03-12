#!/bin/bash
# Aguarda o GNOME carregar
sleep 5

# Terminal 1: ffa (Fastfetch)
gnome-terminal --class ffa_term --geometry=90x25+60+80 -- bash -c "ffa; exec bash"

# Aguarda um pouco para não sobrepor
sleep 1

# Terminal 2: cava (visualizador de áudio)
gnome-terminal --class cava_term --geometry=90x25-60+80 -- bash -c "cava; exec bash"

