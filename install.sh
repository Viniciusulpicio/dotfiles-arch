#!/bin/bash
# ==============================================================================
# Script de Instalação e Restauração Completa - Arch Linux GNOME Rice & Dev
# ==============================================================================

# Validação: Não executar diretamente como root com sudo
if [ "$EUID" -eq 0 ]; then
    echo "⚠️ Por favor, execute o script como seu usuário normal:"
    echo "   ./install.sh"
    echo "O script solicitará privilégios sudo quando necessário."
    exit 1
fi

CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="$HOME"

echo "================================================================="
echo " 🚀 Iniciando Instalação do Rice e Ambiente Arch Linux Completo"
echo " 👤 Usuário: $CURRENT_USER | Home: $TARGET_HOME"
echo " 📁 Diretório do Repositório: $SCRIPT_DIR"
echo "================================================================="
echo ""

# 1. HABILITAR REPOSITÓRIO MULTILIB
echo "⚙️ 1. Habilitando repositório [multilib] em /etc/pacman.conf..."
if grep -q "^#\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    echo "  ✓ Multilib ativado."
else
    echo "  ✓ Multilib já estava ativo."
fi

# 2. ATUALIZAR CHAVES E INSTALAR YAY (AUR HELPER)
echo ""
echo "🔑 2. Atualizando base do sistema e verificando Yay..."
sudo pacman -Sy --noconfirm archlinux-keyring
if ! command -v yay &> /dev/null; then
    echo "  -> Instalando dependências para compilar o yay..."
    sudo pacman -S --needed --noconfirm base-devel git python-pipx wget unzip
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
    echo "  ✓ Yay instalado com sucesso!"
else
    echo "  ✓ Yay já está instalado."
fi

# 3. INSTALAÇÃO DE PACOTES NATIVOS (Pacman)
echo ""
echo "📦 3. Instalando pacotes nativos do repositório oficial..."
INSTALLED_PKGS=$(pacman -Qq 2>/dev/null || true)
REPO_PKGS=$(pacman -Slq 2>/dev/null || true)

REQUESTED_NATIVE=()
for f in "$SCRIPT_DIR/pkg-lists/pacman_native.txt" "$SCRIPT_DIR/pkg-lists/native_list.txt"; do
    if [ -f "$f" ]; then
        while read -r pkg; do
            [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
            REQUESTED_NATIVE+=("$pkg")
        done < "$f"
    fi
done

TO_INSTALL_PACMAN=()
for pkg in "${REQUESTED_NATIVE[@]}"; do
    if ! echo "$INSTALLED_PKGS" | grep -qx "$pkg" && echo "$REPO_PKGS" | grep -qx "$pkg"; then
        TO_INSTALL_PACMAN+=("$pkg")
    fi
done

if [ ${#TO_INSTALL_PACMAN[@]} -gt 0 ]; then
    echo "  -> Instalando ${#TO_INSTALL_PACMAN[@]} pacotes nativos via Pacman..."
    sudo pacman -S --needed --noconfirm "${TO_INSTALL_PACMAN[@]}" || true
else
    echo "  ✓ Todos os pacotes nativos necessários já estão instalados!"
fi

# 4. INSTALAÇÃO DE PACOTES AUR (Yay)
echo ""
echo "🚀 4. Instalando pacotes do AUR via Yay..."
REQUESTED_AUR=()
for f in "$SCRIPT_DIR/pkg-lists/aur_packages.txt" "$SCRIPT_DIR/pkg-lists/aur_list.txt"; do
    if [ -f "$f" ]; then
        while read -r pkg; do
            [[ -z "$pkg" || "$pkg" =~ ^# || "$pkg" =~ -debug$ ]] && continue
            REQUESTED_AUR+=("$pkg")
        done < "$f"
    fi
done

TO_INSTALL_AUR=()
for pkg in "${REQUESTED_AUR[@]}"; do
    if ! echo "$INSTALLED_PKGS" | grep -qx "$pkg" && ! echo "$REPO_PKGS" | grep -qx "$pkg"; then
        TO_INSTALL_AUR+=("$pkg")
    fi
done

if [ ${#TO_INSTALL_AUR[@]} -gt 0 ]; then
    echo "  -> Instalando ${#TO_INSTALL_AUR[@]} pacotes do AUR..."
    for pkg in "${TO_INSTALL_AUR[@]}"; do
        yay -S --needed --noconfirm "$pkg" || echo "⚠️ Aviso: Pacote AUR $pkg não pôde ser instalado de imediato."
    done
else
    echo "  ✓ Todos os pacotes AUR necessários já estão instalados!"
fi

# 5. INSTALAÇÃO DE FLATPAKS
echo ""
echo "📦 5. Verificando Flatpaks..."
if command -v flatpak &> /dev/null && [ -f "$SCRIPT_DIR/pkg-lists/flatpak_list.txt" ]; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    while read -r fp; do
        [[ -z "$fp" || "$fp" =~ ^# ]] && continue
        flatpak install -y flathub "$fp" 2>/dev/null || true
    done < "$SCRIPT_DIR/pkg-lists/flatpak_list.txt"
    echo "  ✓ Flatpaks processados."
fi

# 6. RESTAURAÇÃO DE ARQUIVOS DE PERFIL, SHELL E DOTFILES
echo ""
echo "🐚 6. Restaurando arquivos de ambiente Shell e Perfil..."
for file in .zshrc .p10k.zsh .bashrc .bash_profile .profile .imwheelrc .gitconfig .nvidia-settings-rc .notas_rapidas.txt; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        cp -f "$SCRIPT_DIR/$file" "$TARGET_HOME/"
        echo "  ✓ $file"
    fi
done

# 7. RESTAURAÇÃO DE CONFIGURAÇÕES (~/.config)
echo ""
echo "⚙️ 7. Restaurando configurações em ~/.config..."
mkdir -p "$TARGET_HOME/.config"
cp -rf "$SCRIPT_DIR/.config/"* "$TARGET_HOME/.config/" 2>/dev/null || true
# Limpa qualquer resquício acidental
rm -rf "$TARGET_HOME/.config/'*'" "$TARGET_HOME/.config/*" 2>/dev/null || true
echo "  ✓ Configurações de aplicativos e rice restauradas."

# 8. RESTAURAÇÃO DE ASSETS (Temas, Fontes, Ícones, Extensões e Wallpapers)
echo ""
echo "🎨 8. Restaurando assets visuais, fontes, ícones e extensões..."
[ -d "$SCRIPT_DIR/.rion-dotfiles" ] && cp -rf "$SCRIPT_DIR/.rion-dotfiles" "$TARGET_HOME/"
[ -d "$SCRIPT_DIR/grub2-themes" ] && cp -rf "$SCRIPT_DIR/grub2-themes" "$TARGET_HOME/"

mkdir -p "$TARGET_HOME/Pictures/Wallpaper" "$TARGET_HOME/.local/bin" "$TARGET_HOME/.local/share"
if [ -d "$SCRIPT_DIR/Pictures" ]; then
    cp -rf "$SCRIPT_DIR/Pictures/"* "$TARGET_HOME/Pictures/" 2>/dev/null || true
fi

if [ -d "$SCRIPT_DIR/.local/bin" ]; then
    cp -rf "$SCRIPT_DIR/.local/bin/"* "$TARGET_HOME/.local/bin/" 2>/dev/null || true
    chmod +x "$TARGET_HOME/.local/bin/"* 2>/dev/null || true
fi

if [ -d "$SCRIPT_DIR/.local/share" ]; then
    cp -rf "$SCRIPT_DIR/.local/share/"* "$TARGET_HOME/.local/share/" 2>/dev/null || true
fi

# Compilar schemas das extensões GNOME
for schema_dir in "$TARGET_HOME"/.local/share/gnome-shell/extensions/*/schemas; do
    if [ -d "$schema_dir" ]; then
        glib-compile-schemas "$schema_dir" 2>/dev/null || true
    fi
done
echo "  ✓ Schemas de extensões compilados."

# Atualizar cache de fontes
if command -v fc-cache &> /dev/null; then
    echo "  -> Atualizando cache de fontes..."
    fc-cache -f "$TARGET_HOME/.local/share/fonts" 2>/dev/null || true
    echo "  ✓ Fontes Nerd Fonts registradas."
fi

# 9. OH-MY-ZSH E POWERLEVEL10K
echo ""
echo "⚡ 9. Configurando Oh-My-Zsh..."
if [ ! -d "$TARGET_HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || true
fi
mkdir -p "$TARGET_HOME/.oh-my-zsh/custom"
[ -d "$SCRIPT_DIR/.oh-my-zsh/custom" ] && cp -rf "$SCRIPT_DIR/.oh-my-zsh/custom/"* "$TARGET_HOME/.oh-my-zsh/custom/" 2>/dev/null || true
echo "  ✓ Customizações do Zsh restauradas."

# 10. CONFIGURAÇÕES E EXTENSÕES DO VS CODE
echo ""
echo "💻 10. Restaurando configurações do VS Code..."
mkdir -p "$TARGET_HOME/.config/Code/User"
if [ -d "$SCRIPT_DIR/.config/Code/User" ]; then
    cp -rf "$SCRIPT_DIR/.config/Code/User/"* "$TARGET_HOME/.config/Code/User/" 2>/dev/null || true
fi

CODE_BIN=$(command -v code || command -v visual-studio-code || true)
if [ -n "$CODE_BIN" ] && [ -f "$SCRIPT_DIR/pkg-lists/vscode_extensions.txt" ]; then
    echo "  -> Instalando extensões do VS Code..."
    while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        "$CODE_BIN" --install-extension "$ext" --force 2>/dev/null || true
    done < "$SCRIPT_DIR/pkg-lists/vscode_extensions.txt"
    echo "  ✓ Extensões do VS Code instaladas."
fi

# 11. DCONF & CONFIGURAÇÕES DO GNOME
echo ""
echo "🎛️ 11. Restaurando banco de configurações do GNOME (dconf)..."
if [ -f "$SCRIPT_DIR/gnome-settings/full-backup.dconf" ]; then
    dconf load / < "$SCRIPT_DIR/gnome-settings/full-backup.dconf" 2>/dev/null || true
fi
if [ -f "$SCRIPT_DIR/gnome-settings/gnome-shell-backup.dconf" ]; then
    dconf load /org/gnome/ < "$SCRIPT_DIR/gnome-settings/gnome-shell-backup.dconf" 2>/dev/null || true
fi
if [ -f "$SCRIPT_DIR/gnome-settings/github-extensions.dconf" ]; then
    dconf load /com/github/ < "$SCRIPT_DIR/gnome-settings/github-extensions.dconf" 2>/dev/null || true
fi
if [ -f "$SCRIPT_DIR/gnome-settings/gnome-extensions.dconf" ]; then
    dconf load /org/gnome/shell/extensions/ < "$SCRIPT_DIR/gnome-settings/gnome-extensions.dconf" 2>/dev/null || true
fi

# Habilitar extensões do GNOME
if [ -f "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt" ] && command -v gnome-extensions &> /dev/null; then
    echo "  -> Habilitando extensões ativas..."
    while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        gnome-extensions enable "$ext" 2>/dev/null || true
    done < "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt"
    echo "  ✓ Extensões do GNOME ativadas."
fi

# 12. APLICAR WALLPAPER E WPGTK / PYWAL
echo ""
echo "🖼️ 12. Aplicando Wallpaper e Esquema de Cores Pywal..."
if [ -f "$SCRIPT_DIR/wallpaper_atual.jpg" ]; then
    cp -f "$SCRIPT_DIR/wallpaper_atual.jpg" "$TARGET_HOME/Pictures/wallpaper_atual.jpg" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-uri "file://$TARGET_HOME/Pictures/wallpaper_atual.jpg" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$TARGET_HOME/Pictures/wallpaper_atual.jpg" 2>/dev/null || true
fi

if command -v wpg &> /dev/null; then
    WALL_TO_APPLY="$TARGET_HOME/Pictures/wallpaper_atual.jpg"
    [ ! -f "$WALL_TO_APPLY" ] && WALL_TO_APPLY=$(find "$TARGET_HOME/Pictures/Wallpaper" -type f 2>/dev/null | head -n 1)
    if [ -n "$WALL_TO_APPLY" ] && [ -f "$WALL_TO_APPLY" ]; then
        wpg -a "$WALL_TO_APPLY" 2>/dev/null || true
        wpg -s "$WALL_TO_APPLY" 2>/dev/null || true
    fi
fi

# 13. SERVIÇOS DO SISTEMA E SHELL PADRÃO
echo ""
echo "🛠️ 13. Habilitando serviços do sistema..."
sudo systemctl enable --now docker.service 2>/dev/null || true
sudo usermod -aG docker "$CURRENT_USER" 2>/dev/null || true
sudo systemctl enable --now bluetooth.service 2>/dev/null || true
sudo systemctl enable --now NetworkManager.service 2>/dev/null || true

if [ ! -d "/var/lib/mysql" ] && command -v mariadb-install-db &> /dev/null; then
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql 2>/dev/null || true
fi
sudo systemctl enable --now mariadb.service 2>/dev/null || true
sudo systemctl enable --now postgresql.service 2>/dev/null || true

if [ "$SHELL" != "/bin/zsh" ] && command -v zsh &> /dev/null; then
    echo "  -> Definindo Zsh como shell padrão..."
    sudo chsh -s /bin/zsh "$CURRENT_USER" 2>/dev/null || chsh -s /bin/zsh 2>/dev/null || true
fi

echo ""
echo "================================================================="
echo " ✨ INSTALAÇÃO E RESTAURAÇÃO CONCLUÍDAS COM SUCESSO! ✨"
echo " 🔄 Recomendado reiniciar o computador para aplicar todas as"
echo "    alterações visuais, extensões e serviços do GNOME."
echo "================================================================="
