#!/bin/bash

# Define o ícone
ICON="" # Este é um ícone do Font Awesome, pode trocar por "Spotify" se não usar fontes de ícones

# Verifica o estado do playerctl
STATUS=$(playerctl status 2>/dev/null)

if [ "$STATUS" = "Playing" ]; then
    ARTIST=$(playerctl metadata artist)
    TITLE=$(playerctl metadata title)
    echo "$ICON $ARTIST - $TITLE | iconName=media-playback-start-symbolic"
elif [ "$STATUS" = "Paused" ]; then
    ARTIST=$(playerctl metadata artist)
    TITLE=$(playerctl metadata title)
    echo "$ICON $ARTIST - $TITLE | iconName=media-playback-pause-symbolic"
else
    # Isso cobre o '404 - Not Found' da sua imagem (quando nada está a tocar)
    echo "$ICON Not Found | iconName=media-playback-stop-symbolic"
fi

# Linhas para o menu dropdown (clicar)
echo "---"
echo "Play/Pause | bash='playerctl play-pause' terminal=false"
echo "Próxima | bash='playerctl next' terminal=false"
echo "Anterior | bash='playerctl previous' terminal=false"
