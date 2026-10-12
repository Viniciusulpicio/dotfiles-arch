#!/usr/bin/env bash
# ==============================================================================
# apply-updates.sh: Atualização cirúrgica de extensões, scripts e GNOME 51
# Seguro para rodar em máquina em uso diário (não reinstala pacotes nem apaga dados)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_HOME="$HOME"

echo "================================================================="
echo " 🚀 Aplicando atualizações de Extensões, Scripts e GNOME 51"
echo " 👤 Usuário: $(whoami) | Home: $TARGET_HOME"
echo "================================================================="
echo ""

# 1. Correções do GNOME 51 (GDM fingerprint, Polkit PAM, auto-power-profile)
if [ -f "$SCRIPT_DIR/scripts/fix-gnome-51.sh" ]; then
    echo "🔧 1. Aplicando patches do GNOME 51..."
    bash "$SCRIPT_DIR/scripts/fix-gnome-51.sh"
fi

# 2. Atualizar extensões locais do GNOME
echo ""
echo "🧩 2. Atualizando extensões do GNOME Shell..."
mkdir -p "$TARGET_HOME/.local/share/gnome-shell/extensions"
rsync -av --exclude='.git' \
    "$SCRIPT_DIR/.local/share/gnome-shell/extensions/" \
    "$TARGET_HOME/.local/share/gnome-shell/extensions/"

# 3. Atualizar binários locais (dev-sync, clean-old-extensions, etc.)
echo ""
echo "🛠️ 3. Atualizando scripts em ~/.local/bin..."
mkdir -p "$TARGET_HOME/.local/bin"
cp -rf "$SCRIPT_DIR/.local/bin/"* "$TARGET_HOME/.local/bin/" 2>/dev/null || true
chmod +x "$TARGET_HOME/.local/bin/"* 2>/dev/null || true

# 4. Configurar filtro da pasta temp (Google Drive)
echo ""
echo "📁 4. Atualizando filtros do rclone (dev-sync)..."
mkdir -p "$TARGET_HOME/.config/rclone"
cp -f "$SCRIPT_DIR/.config/rclone/dev-filter.txt" "$TARGET_HOME/.config/rclone/" 2>/dev/null || true

# 5. Ativar timer de limpeza periódica de extensões antigas
echo ""
echo "⏱️ 5. Configurando limpeza periódica de extensões residuais..."
mkdir -p "$TARGET_HOME/.config/systemd/user"
cp -f "$SCRIPT_DIR/.config/systemd/user/clean-old-extensions."* "$TARGET_HOME/.config/systemd/user/" 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now clean-old-extensions.timer 2>/dev/null || true

# 6. Executar limpeza e recompilação inicial de schemas
echo ""
echo "🧹 6. Limpando resíduos e compilando schemas..."
if [ -f "$TARGET_HOME/.local/bin/clean-old-extensions" ]; then
    bash "$TARGET_HOME/.local/bin/clean-old-extensions"
fi

# 7. Carregar configurações do dconf das extensões
echo ""
echo "🎛️ 7. Restaurando configurações do GNOME Shell Extensions..."
if [ -f "$SCRIPT_DIR/gnome-settings/gnome-extensions.dconf" ]; then
    dconf load /org/gnome/shell/extensions/ < "$SCRIPT_DIR/gnome-settings/gnome-extensions.dconf" 2>/dev/null || true
fi

# Habilitar extensões ativas
if [ -f "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt" ] && command -v gnome-extensions &>/dev/null; then
    while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        gnome-extensions enable "$ext" 2>/dev/null || true
    done < "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt"
fi

echo ""
echo "================================================================="
echo " ✨ ATUALIZAÇÃO CONCLUÍDA COM SUCESSO! ✨"
echo " ℹ️ Não foi preciso mexer em nenhum dos seus pacotes ou arquivos."
echo " 🔄 Quando puder, apenas encerre a sessão (Log out) ou reinicie"
echo "    para carregar as extensões e os patches do GDM/Polkit."
echo "================================================================="
