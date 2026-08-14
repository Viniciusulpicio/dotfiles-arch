#!/bin/bash
# ==============================================================================
# Script de Instalação e Restauração Completa - Arch Linux GNOME Rice & Dev
# ==============================================================================
echo "=== Restaurando Rice + Full Stack Dev (Completo) ==="
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
    sudo pacman -S --needed --noconfirm base-devel git python-pipx wget unzip
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd -
fi

# 3. INSTALAÇÃO DE PACOTES NATIVOS (Pacman)
echo "📦 Instalando Pacotes Nativos do Pacman..."
INSTALLED_PKGS=$(pacman -Qq)
REPO_PKGS=$(pacman -Slq)

# Ler listas de pacotes nativos
REQUESTED_NATIVE=()
for f in "$SCRIPT_DIR/pkg-lists/pacman_native.txt" "$SCRIPT_DIR/pkg-lists/native_list.txt"; do
    if [ -f "$f" ]; then
        while read -r pkg; do
            [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
            REQUESTED_NATIVE+=("$pkg")
        done < "$f"
    fi
done

# Filtrar o que precisa ser instalado via Pacman
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
    echo "Todos os pacotes nativos solicitados já estão instalados!"
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
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    while read -r fp; do
        [[ -z "$fp" || "$fp" =~ ^# ]] && continue
        flatpak install -y flathub "$fp" 2>/dev/null
    done < "$SCRIPT_DIR/pkg-lists/flatpak_list.txt"
fi

# 6. CONFIGURAÇÃO DE SERVIÇOS
echo "🛠️ Configurando Serviços..."
sudo npm install -g typescript 2>/dev/null
sudo systemctl enable --now docker.service 2>/dev/null
sudo usermod -aG docker "$CURRENT_USER" 2>/dev/null

if [ ! -d "/var/lib/mysql" ]; then
    echo "Inicializando MariaDB..."
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
fi
sudo systemctl enable --now mariadb.service 2>/dev/null
sudo systemctl enable --now postgresql.service 2>/dev/null

# 7. RESTAURAR ARQUIVOS E DOTFILES
echo "📂 Restaurando Dotfiles..."
cp -f "$SCRIPT_DIR"/.zshrc "$SCRIPT_DIR"/.p10k.zsh "$SCRIPT_DIR"/.bashrc "$SCRIPT_DIR"/.profile ~/ 2>/dev/null || true
cp -rf "$SCRIPT_DIR"/.config/* ~/.config/ 2>/dev/null || true
[ -d "$SCRIPT_DIR/.rion-dotfiles" ] && cp -rf "$SCRIPT_DIR/.rion-dotfiles" ~/
[ -d "$SCRIPT_DIR/grub2-themes" ] && cp -rf "$SCRIPT_DIR/grub2-themes" ~/
mkdir -p ~/Pictures ~/.local/bin ~/.local/share
[ -d "$SCRIPT_DIR/Pictures" ] && cp -rf "$SCRIPT_DIR/Pictures/"* ~/Pictures/
[ -d "$SCRIPT_DIR/.local/bin" ] && cp -rf "$SCRIPT_DIR/.local/bin/"* ~/.local/bin/
chmod +x ~/.local/bin/* 2>/dev/null

# Oh-My-Zsh Custom
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
[ -d "$SCRIPT_DIR/.oh-my-zsh/custom" ] && cp -rf "$SCRIPT_DIR/.oh-my-zsh/custom/"* ~/.oh-my-zsh/custom/ 2>/dev/null

# 8. VS CODE EXTENSIONS
mkdir -p ~/.config/Code/User
[ -f "$SCRIPT_DIR/.config/Code/User/settings.json" ] && cp "$SCRIPT_DIR/.config/Code/User/"*.json ~/.config/Code/User/ 2>/dev/null

CODE_BIN=$(command -v code || command -v visual-studio-code)
if [ -n "$CODE_BIN" ] && [ -f "$SCRIPT_DIR/pkg-lists/vscode_extensions.txt" ]; then
    echo "📝 Instalando Extensões do VS Code..."
    while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        "$CODE_BIN" --install-extension "$ext" --force 2>/dev/null
    done < "$SCRIPT_DIR/pkg-lists/vscode_extensions.txt"
fi

# 9. DCONF & GNOME EXTENSIONS
echo "🎛️ Restaurando Configurações do GNOME (dconf)..."
if [ -f "$SCRIPT_DIR/gnome-settings/full-backup.dconf" ]; then
    dconf load / < "$SCRIPT_DIR/gnome-settings/full-backup.dconf"
elif [ -f "$SCRIPT_DIR/gnome-settings/org-gnome.dconf" ]; then
    dconf load /org/gnome/ < "$SCRIPT_DIR/gnome-settings/org-gnome.dconf"
elif [ -f "$SCRIPT_DIR/gnome-settings/gnome-shell-backup.dconf" ]; then
    dconf load /org/gnome/ < "$SCRIPT_DIR/gnome-settings/gnome-shell-backup.dconf"
fi
[ -f "$SCRIPT_DIR/gnome-settings/github-extensions.dconf" ] && dconf load /com/github/ < "$SCRIPT_DIR/gnome-settings/github-extensions.dconf"

if [ -f "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt" ]; then
    while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        gnome-extensions enable "$ext" 2>/dev/null
    done < "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt"
fi

# 10. AJUSTES FINAIS
if command -v wpg &> /dev/null && [ -d ~/Pictures/Wallpaper ]; then
    echo "🎨 Aplicando Wallpaper..."
    wpg -s "$(find ~/Pictures/Wallpaper -type f | head -n 1)" 2>/dev/null
fi

if [ "$SHELL" != "/bin/zsh" ] && command -v zsh &> /dev/null; then 
    chsh -s /bin/zsh 2>/dev/null || true
fi

echo "=== PRONTO! TUDO RESTAURADO E INSTALADO COM SUCESSO. ==="
