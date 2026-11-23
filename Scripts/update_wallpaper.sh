#!/bin/bash
# Baixador Pinterest - Força Max Quality + Auto Update

PINTEREST_URL="https://www.pinterest.com/limasulpicio/wallpaper/"
OUTPUT_DIR="$HOME/Pictures/Wallpaper"
COOKIES="$HOME/.pinterest-cookies.txt"

# 1. ATUALIZAÇÃO AUTOMÁTICA (Essencial para o Pinterest)
# O Pinterest muda o layout toda semana. Se o gallery-dl estiver velho,
# ele não acha o link "originals" e baixa a miniatura.
echo "🔄 Verificando atualizações do gallery-dl..."
pip install -U gallery-dl > /dev/null 2>&1

if command -v gallery-dl &> /dev/null; then
    if [ -x "$HOME/.local/bin/monitor-info.sh" ]; then
        eval "$("$HOME/.local/bin/monitor-info.sh")"
    fi
    MIN_W="${PHYS_W:-1920}"
    echo "📥 Baixando em Qualidade MÁXIMA (Originals >= ${MIN_W}px)..."
    
    gallery-dl --cookies "$COOKIES" \
               --directory "$OUTPUT_DIR" \
               --download-archive "$OUTPUT_DIR/history.sqlite" \
               --filter "width >= ${MIN_W} and width > height" \
               --write-metadata \
               --verbose \
               "$PINTEREST_URL"
               
    echo "✅ Concluído! Verifique se as URLs baixadas contêm '/originals/' no log."
else
    echo "❌ Erro: gallery-dl não instalado ou não encontrado no PATH."
    exit 1
fi