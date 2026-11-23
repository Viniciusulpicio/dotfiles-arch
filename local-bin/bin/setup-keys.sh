#!/bin/bash
# ==============================================================================
# setup-keys.sh - Assistente de Configuração de Chaves, APIs e Identidade
# ==============================================================================

TARGET_HOME="${TARGET_HOME:-$HOME}"
CONKY_DIR="$TARGET_HOME/.config/conky"
WEATHER_ENV="$CONKY_DIR/weather.env"
DEV_SECRETS="$TARGET_HOME/.env.secrets"

mkdir -p "$CONKY_DIR"

# Carregar valores atuais existentes como padrão
CURRENT_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "$USER")
CURRENT_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

CURRENT_CITY="Sao Paulo,br"
CURRENT_WEATHER_KEY=""
if [ -f "$WEATHER_ENV" ]; then
    CURRENT_CITY=$(grep -E '^CITY=' "$WEATHER_ENV" | cut -d'"' -f2 2>/dev/null)
    CURRENT_WEATHER_KEY=$(grep -E '^API_KEY=' "$WEATHER_ENV" | cut -d'"' -f2 2>/dev/null)
    [[ "$CURRENT_WEATHER_KEY" == "YOUR_OPENWEATHER_API_KEY" ]] && CURRENT_WEATHER_KEY=""
    [[ -z "$CURRENT_CITY" ]] && CURRENT_CITY="Sao Paulo,br"
fi

GIT_NAME=""
GIT_EMAIL=""
CITY=""
WEATHER_KEY=""
AI_KEY=""

# 1. Interface Gráfica via Zenity (GNOME) se houver display gráfico
if command -v zenity &>/dev/null && ([ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]); then
    OUTPUT=$(zenity --forms \
        --title="Assistente de Configuração - Dotfiles & APIs" \
        --text="Configure suas preferências e chaves de API pessoais.\n(Campos vazios usarão os valores padrão seguros)" \
        --add-entry="Seu Nome (Git user.name)" \
        --add-entry="Seu E-mail (Git user.email)" \
        --add-entry="Cidade do Clima (Ex: Marilia,br ou Sao Paulo,br)" \
        --add-password="Chave API OpenWeatherMap (Opcional)" \
        --add-password="Chave de API IA - Gemini / Claude / OpenAI (Opcional)" \
        --separator="|" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$OUTPUT" ]; then
        GIT_NAME=$(echo "$OUTPUT" | cut -d'|' -f1)
        GIT_EMAIL=$(echo "$OUTPUT" | cut -d'|' -f2)
        CITY=$(echo "$OUTPUT" | cut -d'|' -f3)
        WEATHER_KEY=$(echo "$OUTPUT" | cut -d'|' -f4)
        AI_KEY=$(echo "$OUTPUT" | cut -d'|' -f5)
    fi

# 2. Interface via YAD (se Zenity não responder)
elif command -v yad &>/dev/null && ([ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]); then
    OUTPUT=$(yad --form \
        --title="Assistente de Configuração - Dotfiles & APIs" \
        --text="Configure suas preferências e chaves de API pessoais." \
        --field="Nome (Git)":TEXT "$CURRENT_GIT_NAME" \
        --field="E-mail (Git)":TEXT "$CURRENT_GIT_EMAIL" \
        --field="Cidade (Clima)":TEXT "$CURRENT_CITY" \
        --field="OpenWeatherMap Key":H "$CURRENT_WEATHER_KEY" \
        --field="Chave IA (Gemini/Claude)":H "" \
        --separator="|" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$OUTPUT" ]; then
        GIT_NAME=$(echo "$OUTPUT" | cut -d'|' -f1)
        GIT_EMAIL=$(echo "$OUTPUT" | cut -d'|' -f2)
        CITY=$(echo "$OUTPUT" | cut -d'|' -f3)
        WEATHER_KEY=$(echo "$OUTPUT" | cut -d'|' -f4)
        AI_KEY=$(echo "$OUTPUT" | cut -d'|' -f5)
    fi

# 3. Fallback Interativo no Terminal
elif [ -t 0 ]; then
    echo ""
    echo "=========================================================="
    echo "  🔑 Assistente de Chaves, Identidade e APIs Pessoais"
    echo "=========================================================="
    echo "Pressione [ENTER] para aceitar o valor padrão entre colchetes."
    echo ""

    read -rp "1. Seu Nome para commits do Git [$CURRENT_GIT_NAME]: " in_git_name
    GIT_NAME="${in_git_name:-$CURRENT_GIT_NAME}"

    read -rp "2. Seu E-mail para o Git [$CURRENT_GIT_EMAIL]: " in_git_email
    GIT_EMAIL="${in_git_email:-$CURRENT_GIT_EMAIL}"

    read -rp "3. Cidade para previsão do tempo [$CURRENT_CITY]: " in_city
    CITY="${in_city:-$CURRENT_CITY}"

    read -rsp "4. Chave OpenWeatherMap API (ENTER para pular): " in_w_key
    echo ""
    WEATHER_KEY="${in_w_key:-$CURRENT_WEATHER_KEY}"

    read -rsp "5. Chave de API de IA (Gemini/Claude/OpenAI - ENTER para pular): " in_ai_key
    echo ""
    AI_KEY="${in_ai_key:-}"
fi

# 4. Aplicar valores e fallbacks seguros
GIT_NAME="${GIT_NAME:-$CURRENT_GIT_NAME}"
GIT_EMAIL="${GIT_EMAIL:-$CURRENT_GIT_EMAIL}"
CITY="${CITY:-$CURRENT_CITY}"
WEATHER_KEY="${WEATHER_KEY:-${CURRENT_WEATHER_KEY:-YOUR_OPENWEATHER_API_KEY}}"

# 5. Salvar Git Config
if [ -n "$GIT_NAME" ]; then
    git config --global user.name "$GIT_NAME" 2>/dev/null || true
fi
if [ -n "$GIT_EMAIL" ]; then
    git config --global user.email "$GIT_EMAIL" 2>/dev/null || true
fi

# 6. Salvar configuração do Conky Weather
cat << EOF > "$WEATHER_ENV"
# Configuração pessoal de clima (não versionada no Git)
CITY="$CITY"
API_KEY="$WEATHER_KEY"
EOF
chmod 600 "$WEATHER_ENV"

# 7. Salvar chaves de IA em ~/.env.secrets se fornecido
if [ -n "$AI_KEY" ]; then
    cat << EOF > "$DEV_SECRETS"
# Chaves de API de Desenvolvimento e IA (não versionadas)
export GEMINI_API_KEY="$AI_KEY"
export ANTHROPIC_API_KEY="$AI_KEY"
export OPENAI_API_KEY="$AI_KEY"
EOF
    chmod 600 "$DEV_SECRETS"
    
    # Garantir source no bashrc e zshrc
    for rc in "$TARGET_HOME/.bashrc" "$TARGET_HOME/.zshrc"; do
        if [ -f "$rc" ] && ! grep -q "env.secrets" "$rc"; then
            echo '[ -f "$HOME/.env.secrets" ] && source "$HOME/.env.secrets"' >> "$rc"
        fi
    done
fi

echo "✓ Identidade Git configurada: ${GIT_NAME} <${GIT_EMAIL}>"
echo "✓ Chaves e preferências salvas com sucesso em modo seguro (chmod 600)."
