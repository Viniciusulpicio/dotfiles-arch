#!/bin/bash
# ==============================================================================
# Script de Instalação e Restauração Completa - Arch Linux GNOME Rice & Dev
# ==============================================================================
set -e
echo "=== Restaurando Rice + Configurações Completas (Arch Linux) ==="
CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Habilitar Multilib em /etc/pacman.conf se estiver desativado
if grep -q "^#\[multilib\]" /etc/pacman.conf; then
    echo "⚙️ Ativando repositório [multilib] em /etc/pacman.conf..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
fi

# 2. Atualizar Keyring e Base
echo "🔑 Atualizando keyring e base..."
sudo pacman -Sy --noconfirm archlinux-keyring
if ! command -v yay &> /dev/null; then
    echo "📦 Instalando base-devel e yay..."
    sudo pacman -S --needed --noconfirm base-devel git python-pipx wget unzip
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd -
fi

# 3. INSTALAÇÃO DE PACOTES NATIVOS (Pacman)
echo "📦 Instalando Pacotes Nativos do Pacman..."
INSTALLED_PKGS=$(pacman -Qq)
REPO_PKGS=$(pacman -Slq)

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
    echo "Instalando ${#TO_INSTALL_PACMAN[@]} pacotes nativos..."
    sudo pacman -S --needed --noconfirm "${TO_INSTALL_PACMAN[@]}"
else
    echo "Todos os pacotes nativos já estão instalados!"
fi

# 4. INSTALAÇÃO DE PACOTES AUR (Yay)
echo "🚀 Instalando Pacotes do AUR..."
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
    echo "Instalando ${#TO_INSTALL_AUR[@]} pacotes do AUR..."
    for pkg in "${TO_INSTALL_AUR[@]}"; do
        yay -S --needed --noconfirm "$pkg" 2>/dev/null || echo "⚠️ Falha ao instalar do AUR: $pkg"
    done
else
    echo "Todos os pacotes AUR já estão instalados!"
fi

# 5. INSTALAÇÃO DE FLATPAKS
if command -v flatpak &> /dev/null && [ -f "$SCRIPT_DIR/pkg-lists/flatpak_list.txt" ]; then
    echo "📦 Instalando Flatpaks..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    while read -r fp; do
        [[ -z "$fp" || "$fp" =~ ^# ]] && continue
        flatpak install -y flathub "$fp" 2>/dev/null || true
    done < "$SCRIPT_DIR/pkg-lists/flatpak_list.txt"
fi

# 6. CONFIGURAÇÃO DE SERVIÇOS DO SISTEMA
echo "🛠️ Configurando Serviços do Sistema..."
sudo npm install -g typescript 2>/dev/null || true
sudo systemctl enable --now docker.service 2>/dev/null || true
sudo usermod -aG docker "$CURRENT_USER" 2>/dev/null || true

if [ ! -d "/var/lib/mysql" ]; then
    echo "Inicializando MariaDB..."
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql 2>/dev/null || true
fi
sudo systemctl enable --now mariadb.service 2>/dev/null || true
sudo systemctl enable --now postgresql.service 2>/dev/null || true

# 7. RESTAURAR ARQUIVOS, RICE E DOTFILES
echo "📂 Restaurando Rice e Dotfiles..."
for file in .zshrc .p10k.zsh .bashrc .bash_profile .profile .imwheelrc .gitconfig .nvidia-settings-rc; do
    [ -f "$SCRIPT_DIR/$file" ] && cp -f "$SCRIPT_DIR/$file" "$HOME/"
done

mkdir -p "$HOME/.config" "$HOME/Pictures" "$HOME/.local/bin" "$HOME/.local/share"
cp -rf "$SCRIPT_DIR/.config/"* "$HOME/.config/" 2>/dev/null || true

[ -d "$SCRIPT_DIR/.rion-dotfiles" ] && cp -rf "$SCRIPT_DIR/.rion-dotfiles" "$HOME/"
[ -d "$SCRIPT_DIR/grub2-themes" ] && cp -rf "$SCRIPT_DIR/grub2-themes" "$HOME/"

if [ -d "$SCRIPT_DIR/Pictures" ]; then
    cp -rf "$SCRIPT_DIR/Pictures/"* "$HOME/Pictures/" 2>/dev/null || true
fi

if [ -d "$SCRIPT_DIR/.local/bin" ]; then
    cp -rf "$SCRIPT_DIR/.local/bin/"* "$HOME/.local/bin/" 2>/dev/null || true
    chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
fi

if [ -d "$SCRIPT_DIR/.local/share" ]; then
    cp -rf "$SCRIPT_DIR/.local/share/"* "$HOME/.local/share/" 2>/dev/null || true
fi

# Oh-My-Zsh Custom
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "⚡ Instalando Oh-My-Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || true
fi
[ -d "$SCRIPT_DIR/.oh-my-zsh/custom" ] && cp -rf "$SCRIPT_DIR/.oh-my-zsh/custom/"* "$HOME/.oh-my-zsh/custom/" 2>/dev/null || true

# 8. RESTAURAR CONFIGURAÇÕES DO VS CODE
mkdir -p "$HOME/.config/Code/User"
if [ -d "$SCRIPT_DIR/.config/Code/User" ]; then
    cp -rf "$SCRIPT_DIR/.config/Code/User/"* "$HOME/.config/Code/User/" 2>/dev/null || true
fi

CODE_BIN=$(command -v code || command -v visual-studio-code || true)
if [ -n "$CODE_BIN" ] && [ -f "$SCRIPT_DIR/pkg-lists/vscode_extensions.txt" ]; then
    echo "📝 Instalando Extensões do VS Code..."
    while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        "$CODE_BIN" --install-extension "$ext" --force 2>/dev/null || true
    done < "$SCRIPT_DIR/pkg-lists/vscode_extensions.txt"
fi

# 9. DCONF & CONFIGURAÇÕES DO GNOME
echo "🎛️ Restaurando Configurações do GNOME (dconf)..."
if [ -f "$SCRIPT_DIR/gnome-settings/full-backup.dconf" ]; then
    dconf load / < "$SCRIPT_DIR/gnome-settings/full-backup.dconf" 2>/dev/null || true
elif [ -f "$SCRIPT_DIR/gnome-settings/gnome-shell-backup.dconf" ]; then
    dconf load /org/gnome/ < "$SCRIPT_DIR/gnome-settings/gnome-shell-backup.dconf" 2>/dev/null || true
fi
[ -f "$SCRIPT_DIR/gnome-settings/github-extensions.dconf" ] && dconf load /com/github/ < "$SCRIPT_DIR/gnome-settings/github-extensions.dconf" 2>/dev/null || true
[ -f "$SCRIPT_DIR/gnome-settings/gnome-extensions.dconf" ] && dconf load /org/gnome/shell/extensions/ < "$SCRIPT_DIR/gnome-settings/gnome-extensions.dconf" 2>/dev/null || true

if [ -f "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt" ]; then
    echo "🧩 Ativando Extensões do GNOME..."
    while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        gnome-extensions enable "$ext" 2>/dev/null || true
    done < "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt"
fi

# 10. APLICAR WALLPAPER E TEMA
if [ -f "$SCRIPT_DIR/wallpaper_atual.jpg" ]; then
    cp -f "$SCRIPT_DIR/wallpaper_atual.jpg" "$HOME/Pictures/wallpaper_atual.jpg" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/wallpaper_atual.jpg" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$HOME/Pictures/wallpaper_atual.jpg" 2>/dev/null || true
fi

if command -v wpg &> /dev/null && [ -d "$HOME/Pictures/Wallpaper" ]; then
    echo "🎨 Aplicando Wpgtk / Pywal..."
    wpg -s "$(find "$HOME/Pictures/Wallpaper" -type f | head -n 1)" 2>/dev/null || true
fi

if [ "$SHELL" != "/bin/zsh" ] && command -v zsh &> /dev/null; then 
    chsh -s /bin/zsh "$CURRENT_USER" 2>/dev/null || true
fi

echo "=== ✅ RICE E AMBIENTE RESTAURADOS COM SUCESSO! ==="
