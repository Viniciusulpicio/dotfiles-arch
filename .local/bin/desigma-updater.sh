#!/usr/bin/env bash
# Desigma Background Updater

STATE_DIR="$HOME/.local/share/desigma"
mkdir -p "$STATE_DIR"

VERSION_FILE="$STATE_DIR/current_version"
LAST_CHECK_FILE="$STATE_DIR/last_check"
BIN_TARGET="$HOME/.local/bin/desigma-bin"

CURRENT_VERSION="unknown"
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
fi

# Checa taxa de requisições: verifica se a última consulta foi há menos de 30 minutos
NOW=$(date +%s)
if [ -f "$LAST_CHECK_FILE" ]; then
    LAST_CHECK=$(cat "$LAST_CHECK_FILE")
    DIFF=$((NOW - LAST_CHECK))
    if [ "$DIFF" -lt 1800 ]; then
        exit 0
    fi
fi
echo "$NOW" > "$LAST_CHECK_FILE"

# Consulta a API do GitHub
RELEASE_JSON=$(curl -s --connect-timeout 4 --max-time 10 https://api.github.com/repos/deepfounder-ai/desigma/releases 2>/dev/null)
if [ -z "$RELEASE_JSON" ]; then
    exit 0
fi

# Extrai tag e url do tar.gz para Linux x86_64 usando python
INFO=$(python3 -c "
import json, sys

try:
    data = json.loads('''$RELEASE_JSON''')
    if isinstance(data, list) and len(data) > 0:
        latest = data[0]
        tag = latest.get('tag_name', '')
        tar_url = ''
        for asset in latest.get('assets', []):
            name = asset.get('name', '')
            if 'x86_64-unknown-linux-gnu.tar.gz' in name or ('linux' in name and name.endswith('.tar.gz')):
                tar_url = asset.get('browser_download_url', '')
                break
        print(f'{tag}|{tar_url}')
except Exception:
    pass
" 2>/dev/null)

if [ -z "$INFO" ]; then
    exit 0
fi

LATEST_TAG=$(echo "$INFO" | cut -d'|' -f1)
DOWNLOAD_URL=$(echo "$INFO" | cut -d'|' -f2)

if [ -z "$LATEST_TAG" ] || [ -z "$DOWNLOAD_URL" ]; then
    exit 0
fi

# Se a versão for mais recente que a atual
if [ "$LATEST_TAG" != "$CURRENT_VERSION" ]; then
    notify-send -i software-update-available "Desigma" "Nova atualização disponível ($LATEST_TAG)! Baixando em segundo plano..."
    
    TMP_DIR=$(mktemp -d)
    TAR_FILE="$TMP_DIR/desigma.tar.gz"
    
    if curl -sL --connect-timeout 5 --max-time 120 "$DOWNLOAD_URL" -o "$TAR_FILE"; then
        tar -xzf "$TAR_FILE" -C "$TMP_DIR"
        
        NEW_BIN=$(find "$TMP_DIR" -type f -name "desigma" -executable | head -n 1)
        if [ -n "$NEW_BIN" ]; then
            chmod +x "$NEW_BIN"
            cp "$NEW_BIN" "$BIN_TARGET.new"
            mv "$BIN_TARGET.new" "$BIN_TARGET"
            echo "$LATEST_TAG" > "$VERSION_FILE"
            notify-send -i software-update-available "Desigma Atualizado" "A versão $LATEST_TAG foi instalada com sucesso!"
        fi
    fi
    rm -rf "$TMP_DIR"
fi
