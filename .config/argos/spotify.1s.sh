#!/bin/bash

# Script: ~/.config/argos/spotify.1s.sh
# Atualiza a cada 1s (por causa do sufixo .1s.sh)

STATUS=$(playerctl status 2>/dev/null)
TITLE=$(playerctl metadata xesam:title 2>/dev/null)
ARTIST=$(playerctl metadata xesam:artist 2>/dev/null)

if [ "$STATUS" = "Playing" ]; then
    ICON="▶️"
elif [ "$STATUS" = "Paused" ]; then
    ICON="⏸️"
else
    ICON="❌"
fi

echo "$ICON $TITLE - $ARTIST | click=playerctl play-pause scroll=playerctl next"
