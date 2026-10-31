#!/bin/bash
# setup-keys.sh - Interface para configurar chaves e APIs pessoais (GUI com fallback para Terminal)

TARGET_HOME="${TARGET_HOME:-$HOME}"
CONKY_DIR="$TARGET_HOME/.config/conky"
ENV_FILE="$CONKY_DIR/weather.env"

mkdir -p "$CONKY_DIR"

# Carregar valores atuais se existirem
CURRENT_CITY="Sao Paulo,br"
CURRENT_KEY=""

if [ -f "$ENV_FILE" ]; then
    CURRENT_CITY=$(grep -E '^CITY=' "$ENV_FILE" | cut -d'"' -f2 2>/dev/null)
    CURRENT_KEY=$(grep -E '^API_KEY=' "$ENV_FILE" | cut -d'"' -f2 2>/dev/null)
    [[ "$CURRENT_KEY" == "YOUR_OPENWEATHER_API_KEY" ]] && CURRENT_KEY=""
    [[ -z "$CURRENT_CITY" ]] && CURRENT_CITY="Sao Paulo,br"
fi

CITY=""
API_KEY=""

# 1. Tentar interface gráfica via Zenity (GNOME) ou YAD se houver display gráfico
if command -v zenity &>/dev/null && ([ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]); then
    OUTPUT=$(zenity --forms \
        --title="Configuração de APIs Pessoais - Dotfiles" \
        --text="Configure sua cidade e chave do OpenWeatherMap para o widget do Conky.\n(Deixe em branco para pular e configurar depois)" \
        --add-entry="Cidade (Ex: Marilia,br ou Sao Paulo,br)" \
        --add-password="Chave API OpenWeatherMap" \
        --separator="|" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$OUTPUT" ]; then
        CITY=$(echo "$OUTPUT" | cut -d'|' -f1)
        API_KEY=$(echo "$OUTPUT" | cut -d'|' -f2)
    fi

elif command -v yad &>/dev/null && ([ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]); then
    OUTPUT=$(yad --form \
        --title="Configuração de APIs Pessoais - Dotfiles" \
        --text="Configure sua cidade e chave do OpenWeatherMap para o widget do Conky." \
        --field="Cidade":TEXT "$CURRENT_CITY" \
        --field="Chave API (OpenWeatherMap)":H "$CURRENT_KEY" \
        --separator="|" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$OUTPUT" ]; then
        CITY=$(echo "$OUTPUT" | cut -d'|' -f1)
        API_KEY=$(echo "$OUTPUT" | cut -d'|' -f2)
    fi

# 2. Fallback interativo no Terminal
elif [ -t 0 ]; then
    echo "=================================================="
    echo "  Configuração de APIs Pessoais (Opcional)"
    echo "=================================================="
    read -rp "Cidade para o clima (padrão: ${CURRENT_CITY}): " input_city
    CITY="${input_city:-$CURRENT_CITY}"
    
    read -rp "Chave da API OpenWeatherMap (ENTER para pular): " input_key
    API_KEY="${input_key:-$CURRENT_KEY}"
fi

# 3. Aplicar padrões se nada foi informado
CITY="${CITY:-$CURRENT_CITY}"
API_KEY="${API_KEY:-${CURRENT_KEY:-YOUR_OPENWEATHER_API_KEY}}"

# 4. Gravar arquivo .env com permissão segura (apenas o dono lê)
cat << EOF > "$ENV_FILE"
# Configuração pessoal de clima (não versionada no Git)
CITY="$CITY"
API_KEY="$API_KEY"
EOF

chmod 600 "$ENV_FILE"
chown -R "$USER:$USER" "$ENV_FILE" 2>/dev/null || true

echo "✓ Configurações de API salvas em: $ENV_FILE"
