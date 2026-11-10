#!/bin/bash

# --- CONFIGURAÇÃO ---
ENV_FILE="$HOME/.config/conky/weather.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

# Coordenadas padrão (São Paulo) ou resolvidas por cidade
LAT="${LAT:-}"
LON="${LON:-}"
CITY="${CITY:-Sao Paulo}"

if [ -z "$LAT" ] || [ -z "$LON" ]; then
    # Limpa sufixo como ',br' para busca na geocoding API
    CLEAN_CITY=$(echo "$CITY" | cut -d',' -f1 | sed 's/ /%20/g')
    GEO_DATA=$(curl -s --connect-timeout 5 "https://geocoding-api.open-meteo.com/v1/search?name=${CLEAN_CITY}&count=1&language=pt&format=json")
    LAT=$(echo "$GEO_DATA" | jq -r '.results[0].latitude // empty' 2>/dev/null)
    LON=$(echo "$GEO_DATA" | jq -r '.results[0].longitude // empty' 2>/dev/null)
fi

# Fallback para São Paulo se geocoding falhar
LAT="${LAT:--23.5475}"
LON="${LON:--46.6361}"

# Obter dados de clima (Open-Meteo não requer chave de API)
WEATHER_DATA=$(curl -s --connect-timeout 5 "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,is_day&wind_speed_unit=ms&timezone=auto")

# Validação da resposta
if [ -z "$WEATHER_DATA" ] || [ "$(echo "$WEATHER_DATA" | jq 'has("current")' 2>/dev/null)" != "true" ]; then
    echo -e "\${font Fira Sans:bold:size=14}Clima: Indisponível\${font}"
    exit 0
fi

# Extrair informações usando jq
TEMP=$(echo "$WEATHER_DATA" | jq '.current.temperature_2m' | cut -d'.' -f1)
WEATHER_CODE=$(echo "$WEATHER_DATA" | jq -r '.current.weather_code')
IS_DAY=$(echo "$WEATHER_DATA" | jq -r '.current.is_day')
WIND_SPEED=$(echo "$WEATHER_DATA" | jq '.current.wind_speed_10m')
HUMIDITY=$(echo "$WEATHER_DATA" | jq '.current.relative_humidity_2m')

# Mapear WMO Weather Code para ícone Nerd Font e descrição
case "$WEATHER_CODE" in
    0)
        [ "$IS_DAY" = "1" ] && ICON="\ue30d" || ICON="\ue32b"
        DESCRIPTION="Céu Limpo"
        ;;
    1)
        [ "$IS_DAY" = "1" ] && ICON="\ue302" || ICON="\ue379"
        DESCRIPTION="Tempo Bom"
        ;;
    2)
        [ "$IS_DAY" = "1" ] && ICON="\ue302" || ICON="\ue379"
        DESCRIPTION="Parcialmente Nublado"
        ;;
    3)
        ICON="\ue312"
        DESCRIPTION="Nublado"
        ;;
    45|48)
        ICON="\ue313"
        DESCRIPTION="Nevoeiro"
        ;;
    51|53|55)
        ICON="\ue318"
        DESCRIPTION="Chuvisco"
        ;;
    61|63|65)
        [ "$IS_DAY" = "1" ] && ICON="\ue308" || ICON="\ue325"
        DESCRIPTION="Chuva"
        ;;
    71|73|75|77)
        ICON="\ue31a"
        DESCRIPTION="Neve"
        ;;
    80|81|82)
        ICON="\ue318"
        DESCRIPTION="Pancadas de Chuva"
        ;;
    85|86)
        ICON="\ue31a"
        DESCRIPTION="Pancadas de Neve"
        ;;
    95|96|99)
        ICON="\ue31d"
        DESCRIPTION="Tempestade"
        ;;
    *)
        ICON="\ue312"
        DESCRIPTION="Tempo Firme"
        ;;
esac

# Imprimir a saída formatada para o Conky usando JetBrainsMono Nerd Font
echo -e "\${font JetBrainsMono Nerd Font:size=42}${ICON}\${font}\${voffset -22}   \${font Fira Sans:bold:size=38}${TEMP}°C \${alignr}\${font Fira Sans:bold:size=20}${DESCRIPTION}\${font}\n\${voffset 8}   Vento ${WIND_SPEED}m/s / Umidade ${HUMIDITY}%"
