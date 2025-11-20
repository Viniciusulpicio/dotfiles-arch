#!/bin/bash

# --- CONFIGURAÇÃO ---
CITY="Marilia,br"
API_KEY="2ddd26983f7ffd6b7eef0b7331d1b3ca" # Sua chave da API OpenWeatherMap
# --------------------

# Obter dados da API
WEATHER_DATA=$(curl -s "https://api.openweathermap.org/data/2.5/weather?q=${CITY}&units=metric&appid=${API_KEY}&lang=pt_br")

# Extrair informações usando jq
TEMP=$(echo "$WEATHER_DATA" | jq '.main.temp' | cut -d'.' -f1)
ICON_CODE=$(echo "$WEATHER_DATA" | jq -r '.weather[0].icon')
DESCRIPTION=$(echo "$WEATHER_DATA" | jq -r '.weather[0].description' | sed -e "s/\b\(.\)/\u\1/g") # Capitaliza a primeira letra de cada palavra
WIND_SPEED=$(echo "$WEATHER_DATA" | jq '.wind.speed')
HUMIDITY=$(echo "$WEATHER_DATA" | jq '.main.humidity')

# Mapear o código do ícone para o caractere da fonte Weather Icons
case "$ICON_CODE" in
    "01d") ICON="\uf00d";; # clear sky day
    "01n") ICON="\uf02e";; # clear sky night
    "02d") ICON="\uf002";; # few clouds day
    "02n") ICON="\uf086";; # few clouds night
    "03d") ICON="\uf041";; # scattered clouds day
    "03n") ICON="\uf041";; # scattered clouds night
    "04d") ICON="\uf013";; # broken clouds day
    "04n") ICON="\uf013";; # broken clouds night
    "09d") ICON="\uf019";; # shower rain day
    "09n") ICON="\uf019";; # shower rain night
    "10d") ICON="\uf008";; # rain day
    "10n") ICON="\uf028";; # rain night
    "11d") ICON="\uf01d";; # thunderstorm day
    "11n") ICON="\uf01d";; # thunderstorm night
    "13d") ICON="\uf01b";; # snow day
    "13n") ICON="\uf01b";; # snow night
    "50d") ICON="\uf003";; # mist day
    "50n") ICON="\uf04a";; # mist night
    *) ICON="\uf07b";;   # N/A
esac

# Imprimir a saída formatada para o Conky
echo -e "\${font Weather Icons:size=50}${ICON}\${font}\${voffset -28}   \${font Fira Sans:bold:size=38}${TEMP}° \${alignr}\${font Fira Sans:bold:size=20}${DESCRIPTION}\${font}\n\${voffset 8}   Vento ${WIND_SPEED}m/s / Umidade ${HUMIDITY}%"
