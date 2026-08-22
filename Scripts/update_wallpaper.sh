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
    echo "📥 Baixando em Qualidade MÁXIMA (Originals)..."
    
    # Adicionei --write-metadata: Salva um .json junto com a foto. 
    # Se a foto vier ruim, abra o .json e procure por "originals". 
    # Se tiver um link lá que o script não baixou, é bug da versão.
    
    # Adicionei --verbose: Mostra qual URL exata ele está pegando (ex: .../originals/...)
    
    gallery-dl --cookies "$COOKIES" \
               --directory "$OUTPUT_DIR" \
               --download-archive "$OUTPUT_DIR/history.sqlite" \
               --write-metadata \
               --verbose \
               "$PINTEREST_URL"
               
    echo "✅ Concluído! Verifique se as URLs baixadas contêm '/originals/' no log."
else
    echo "❌ Erro: gallery-dl não instalado ou não encontrado no PATH."
    exit 1
fi