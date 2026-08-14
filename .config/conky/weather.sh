#!/bin/bash

# --- CONFIGURAÇÃO ---
CITY="Marilia,br"
API_KEY="2ddd26983f7ffd6b7eef0b7331d1b3ca" # Chave da API OpenWeatherMap
# --------------------

# Obter dados da API com timeout
WEATHER_DATA=$(curl -s --connect-timeout 5 "https://api.openweathermap.org/data/2.5/weather?q=${CITY}&units=metric&appid=${API_KEY}&lang=pt_br")

# Verificar se a resposta é válida
COD=$(echo "$WEATHER_DATA" | jq -r '.cod' 2>/dev/null)

if [ "$COD" != "200" ]; then
    echo -e "\${font Fira Sans:bold:size=14}Clima: Indisponível\${font}"
    exit 0
fi

# Extrair informações usando jq
TEMP=$(echo "$WEATHER_DATA" | jq '.main.temp' | cut -d'.' -f1)
ICON_CODE=$(echo "$WEATHER_DATA" | jq -r '.weather[0].icon')
DESCRIPTION=$(echo "$WEATHER_DATA" | jq -r '.weather[0].description' | sed -e "s/\b\(.\)/\u\1/g") # Capitaliza a primeira letra de cada palavra
WIND_SPEED=$(echo "$WEATHER_DATA" | jq '.wind.speed')
HUMIDITY=$(echo "$WEATHER_DATA" | jq '.main.humidity')

# Mapear o código do ícone para Nerd Fonts (faixa \ue300-\ue3eb)
case "$ICON_CODE" in
    "01d") ICON="\ue30d";; # clear sky day
    "01n") ICON="\ue32b";; # clear sky night
    "02d") ICON="\ue302";; # few clouds day
    "02n") ICON="\ue379";; # few clouds night
    "03d") ICON="\ue312";; # scattered clouds day
    "03n") ICON="\ue312";; # scattered clouds night
    "04d") ICON="\ue312";; # broken clouds day
    "04n") ICON="\ue312";; # broken clouds night
    "09d") ICON="\ue318";; # shower rain day
    "09n") ICON="\ue318";; # shower rain night
    "10d") ICON="\ue308";; # rain day
    "10n") ICON="\ue325";; # rain night
    "11d") ICON="\ue31d";; # thunderstorm day
    "11n") ICON="\ue31d";; # thunderstorm night
    "13d") ICON="\ue31a";; # snow day
    "13n") ICON="\ue31a";; # snow night
    "50d") ICON="\ue313";; # mist day
    "50n") ICON="\ue313";; # mist night
    *) ICON="\ue312";;   # N/A
esac

# Imprimir a saída formatada para o Conky usando JetBrainsMono Nerd Font
echo -e "\${font JetBrainsMono Nerd Font:size=42}${ICON}\${font}\${voffset -22}   \${font Fira Sans:bold:size=38}${TEMP}°C \${alignr}\${font Fira Sans:bold:size=20}${DESCRIPTION}\${font}\n\${voffset 8}   Vento ${WIND_SPEED}m/s / Umidade ${HUMIDITY}%"

