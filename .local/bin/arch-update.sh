#!/usr/bin/env bash
echo "🔄 Atualizando repositórios oficiais e AUR..."
yay -Syu
if command -v flatpak &>/dev/null; then
    echo ""
    echo "📦 Atualizando Flatpaks..."
    flatpak update -y
fi
echo ""
echo "✅ Sistema e pacotes atualizados com sucesso!"
echo "Pressione Enter para fechar..."
read -r
