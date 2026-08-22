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

# Solicitar senha sudo logo no início e manter a sessão ativa em segundo plano
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEP_ALIVE_PID=$!
trap 'kill $SUDO_KEEP_ALIVE_PID 2>/dev/null' EXIT

# 1. HABILITAR REPOSITÓRIO MULTILIB E CONFIGURAR IDIOMA (pt_BR)
echo "⚙️ 1. Habilitando repositório [multilib] em /etc/pacman.conf..."
if grep -q "^#\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    echo "  ✓ Multilib ativado."
else
    echo "  ✓ Multilib já estava ativo."
fi

echo "🌐 Configurando idioma do sistema para Português (pt_BR.UTF-8)..."
sudo sed -i 's/^#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen > /dev/null 2>&1 || true
echo "LANG=pt_BR.UTF-8" | sudo tee /etc/locale.conf > /dev/null
export LANG=pt_BR.UTF-8
export LC_ALL=pt_BR.UTF-8
echo "  ✓ Idioma pt_BR.UTF-8 configurado."

# 2. ATUALIZAR CHAVES E BASE DO PACMAN
echo ""
echo "🔑 2. Atualizando chaves do sistema..."
sudo pacman -Sy --noconfirm archlinux-keyring

# Resolver conflito comum do jack2 com pipewire-jack
sudo pacman -Rdd --noconfirm jack2 2>/dev/null || true

# 3. INSTALAÇÃO DO YAY (AUR HELPER)
echo ""
echo "🛠️ 3. Verificando/Instalando Yay..."
if ! command -v yay &> /dev/null; then
    echo "  -> Instalando dependências básicas de compilação..."
    sudo pacman -S --needed --noconfirm base-devel git python-pipx wget unzip
    
    echo "  -> Baixando e instalando yay-bin (AUR)..."
    rm -rf /tmp/yay-bin
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -s --noconfirm)
    sudo pacman -U --noconfirm /tmp/yay-bin/yay-bin-*.pkg.tar.zst
    rm -rf /tmp/yay-bin
    echo "  ✓ Yay instalado com sucesso!"
else
    echo "  ✓ Yay já está instalado."
fi

# 4. INSTALAÇÃO DE PACOTES CRÍTICOS NATIVOS (Zsh, Ferramentas, Áudio, Imagens)
echo ""
echo "📦 4. Instalando pacotes base e essenciais..."
CRITICAL_PKGS=(
    "zsh" "zsh-autosuggestions" "zsh-syntax-highlighting"
    "git" "github-cli" "base-devel" "curl" "wget"
    "imagemagick" "fastfetch" "alacritty" "wezterm"
    "btop" "cava" "conky" "neofetch"
    "pipewire" "pipewire-alsa" "pipewire-jack" "pipewire-pulse" "wireplumber"
    "python-pywal" "dconf" "gnome-shell-extensions" "gnome-tweaks"
    "ttf-jetbrains-mono-nerd" "noto-fonts" "noto-fonts-cjk"
)
sudo pacman -S --needed --noconfirm "${CRITICAL_PKGS[@]}" || true

# 5. INSTALAÇÃO DOS DEMAIS PACOTES NATIVOS (Pacman)
echo ""
echo "📦 5. Instalando pacotes nativos do repositório oficial..."
INSTALLED_PKGS=$(pacman -Qq 2>/dev/null || true)
REPO_PKGS=$(pacman -Slq 2>/dev/null || true)

REQUESTED_NATIVE=()
if [ -f "$SCRIPT_DIR/pkg-lists/pacman_native.txt" ]; then
    while read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        REQUESTED_NATIVE+=("$pkg")
    done < "$SCRIPT_DIR/pkg-lists/pacman_native.txt"
fi

TO_INSTALL_PACMAN=()
for pkg in "${REQUESTED_NATIVE[@]}"; do
    if ! echo "$INSTALLED_PKGS" | grep -qx "$pkg" && echo "$REPO_PKGS" | grep -qx "$pkg"; then
        TO_INSTALL_PACMAN+=("$pkg")
    fi
done

if [ ${#TO_INSTALL_PACMAN[@]} -gt 0 ]; then
    echo "  -> Instalando ${#TO_INSTALL_PACMAN[@]} pacotes nativos..."
    if ! sudo pacman -S --needed --noconfirm "${TO_INSTALL_PACMAN[@]}"; then
        echo "  ⚠️ Instalando pacotes individualmente para contornar eventuais conflitos..."
        for pkg in "${TO_INSTALL_PACMAN[@]}"; do
            sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || echo "  ⚠️ Não foi possível instalar: $pkg"
        done
    fi
else
    echo "  ✓ Todos os pacotes nativos solicitados já estão instalados!"
fi

# 6. INSTALAÇÃO DE PACOTES AUR (Yay)
echo ""
echo "🚀 6. Instalando pacotes do AUR via Yay..."
REQUESTED_AUR=()
if [ -f "$SCRIPT_DIR/pkg-lists/aur_packages.txt" ]; then
    while read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# || "$pkg" =~ -debug$ ]] && continue
        REQUESTED_AUR+=("$pkg")
    done < "$SCRIPT_DIR/pkg-lists/aur_packages.txt"
fi

TO_INSTALL_AUR=()
INSTALLED_PKGS=$(pacman -Qq 2>/dev/null || true)
for pkg in "${REQUESTED_AUR[@]}"; do
    if ! echo "$INSTALLED_PKGS" | grep -qx "$pkg" && ! echo "$REPO_PKGS" | grep -qx "$pkg"; then
        TO_INSTALL_AUR+=("$pkg")
    fi
done

if [ ${#TO_INSTALL_AUR[@]} -gt 0 ]; then
    echo "  -> Instalando ${#TO_INSTALL_AUR[@]} pacotes do AUR..."
    for pkg in "${TO_INSTALL_AUR[@]}"; do
        echo "     -> AUR: $pkg"
        yay -S --needed --noconfirm --answerclean None --answerdiff None "$pkg" || echo "⚠️ Aviso: Pacote AUR $pkg não pôde ser instalado."
    done
else
    echo "  ✓ Todos os pacotes AUR necessários já estão instalados!"
fi

# 7. INSTALAÇÃO DE FLATPAKS
echo ""
echo "📦 7. Verificando Flatpaks..."
if command -v flatpak &> /dev/null && [ -f "$SCRIPT_DIR/pkg-lists/flatpak_list.txt" ]; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    while read -r fp; do
        [[ -z "$fp" || "$fp" =~ ^# ]] && continue
        flatpak install -y flathub "$fp" 2>/dev/null || true
    done < "$SCRIPT_DIR/pkg-lists/flatpak_list.txt"
    echo "  ✓ Flatpaks processados."
fi

# 8. RESTAURAÇÃO DE ARQUIVOS DE PERFIL, SHELL E DOTFILES
echo ""
echo "🐚 8. Restaurando arquivos de ambiente Shell e Perfil..."
for file in .zshrc .p10k.zsh .bashrc .bash_profile .profile .imwheelrc .gitconfig .nvidia-settings-rc .notas_rapidas.txt; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        cp -f "$SCRIPT_DIR/$file" "$TARGET_HOME/"
        echo "  ✓ $file"
    fi
done

# 9. RESTAURAÇÃO DE CONFIGURAÇÕES (~/.config) E PASTAS DO USUÁRIO
echo ""
echo "⚙️ 9. Restaurando configurações em ~/.config e organizando pastas em Português..."
mkdir -p "$TARGET_HOME/.config"
cp -rf "$SCRIPT_DIR/.config/"* "$TARGET_HOME/.config/" 2>/dev/null || true
rm -rf "$TARGET_HOME/.config/'*'" "$TARGET_HOME/.config/*" 2>/dev/null || true

# Criar pastas padrão em Português
mkdir -p "$TARGET_HOME/Área de trabalho" "$TARGET_HOME/Documentos" "$TARGET_HOME/Downloads" \
         "$TARGET_HOME/Imagens" "$TARGET_HOME/Músicas" "$TARGET_HOME/Vídeos" \
         "$TARGET_HOME/Modelos" "$TARGET_HOME/Público"

# Migrar conteúdo de pastas antigas em inglês se houver
[ -d "$TARGET_HOME/Desktop" ] && [ -n "$(ls -A "$TARGET_HOME/Desktop" 2>/dev/null)" ] && mv -n "$TARGET_HOME/Desktop/"* "$TARGET_HOME/Área de trabalho/" 2>/dev/null; rmdir "$TARGET_HOME/Desktop" 2>/dev/null || true
[ -d "$TARGET_HOME/Documents" ] && [ -n "$(ls -A "$TARGET_HOME/Documents" 2>/dev/null)" ] && mv -n "$TARGET_HOME/Documents/"* "$TARGET_HOME/Documentos/" 2>/dev/null; rmdir "$TARGET_HOME/Documents" 2>/dev/null || true
[ -d "$TARGET_HOME/Music" ] && [ -n "$(ls -A "$TARGET_HOME/Music" 2>/dev/null)" ] && mv -n "$TARGET_HOME/Music/"* "$TARGET_HOME/Músicas/" 2>/dev/null; rmdir "$TARGET_HOME/Music" 2>/dev/null || true
[ -d "$TARGET_HOME/Videos" ] && [ -n "$(ls -A "$TARGET_HOME/Videos" 2>/dev/null)" ] && mv -n "$TARGET_HOME/Videos/"* "$TARGET_HOME/Vídeos/" 2>/dev/null; rmdir "$TARGET_HOME/Videos" 2>/dev/null || true
[ -d "$TARGET_HOME/Templates" ] && [ -n "$(ls -A "$TARGET_HOME/Templates" 2>/dev/null)" ] && mv -n "$TARGET_HOME/Templates/"* "$TARGET_HOME/Modelos/" 2>/dev/null; rmdir "$TARGET_HOME/Templates" 2>/dev/null || true
[ -d "$TARGET_HOME/Public" ] && [ -n "$(ls -A "$TARGET_HOME/Public" 2>/dev/null)" ] && mv -n "$TARGET_HOME/Public/"* "$TARGET_HOME/Público/" 2>/dev/null; rmdir "$TARGET_HOME/Public" 2>/dev/null || true

# Atualizar mapeamento de diretórios do XDG
if command -v xdg-user-dirs-update &> /dev/null; then
    xdg-user-dirs-update --force 2>/dev/null || true
fi
if command -v xdg-user-dirs-gtk-update &> /dev/null; then
    xdg-user-dirs-gtk-update 2>/dev/null || true
fi
echo "  ✓ Pastas e configurações restauradas em Português."

# 10. RESTAURAÇÃO DE ASSETS (Temas, Fontes, Ícones, Extensões e Wallpapers)
echo ""
echo "🎨 10. Restaurando assets visuais, fontes, ícones e extensões..."
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

# 11. OH-MY-ZSH E POWERLEVEL10K
echo ""
echo "⚡ 11. Configurando Oh-My-Zsh..."
if [ ! -d "$TARGET_HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || true
fi
mkdir -p "$TARGET_HOME/.oh-my-zsh/custom"
[ -d "$SCRIPT_DIR/.oh-my-zsh/custom" ] && cp -rf "$SCRIPT_DIR/.oh-my-zsh/custom/"* "$TARGET_HOME/.oh-my-zsh/custom/" 2>/dev/null || true
echo "  ✓ Customizações do Zsh restauradas."

# 12. CONFIGURAÇÕES E EXTENSÕES DO VS CODE
echo ""
echo "💻 12. Restaurando configurações do VS Code..."
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

# 13. DCONF & CONFIGURAÇÕES DO GNOME
echo ""
echo "🎛️ 13. Restaurando banco de configurações do GNOME (dconf)..."
if [ -f "$SCRIPT_DIR/gnome-settings/full-backup.dconf" ]; then
    sed "s|/home/vinicius|$TARGET_HOME|g" "$SCRIPT_DIR/gnome-settings/full-backup.dconf" | dconf load / 2>/dev/null || true
fi
if [ -f "$SCRIPT_DIR/gnome-settings/gnome-shell-backup.dconf" ]; then
    sed "s|/home/vinicius|$TARGET_HOME|g" "$SCRIPT_DIR/gnome-settings/gnome-shell-backup.dconf" | dconf load /org/gnome/ 2>/dev/null || true
fi
if [ -f "$SCRIPT_DIR/gnome-settings/github-extensions.dconf" ]; then
    sed "s|/home/vinicius|$TARGET_HOME|g" "$SCRIPT_DIR/gnome-settings/github-extensions.dconf" | dconf load /com/github/ 2>/dev/null || true
fi
if [ -f "$SCRIPT_DIR/gnome-settings/gnome-extensions.dconf" ]; then
    sed "s|/home/vinicius|$TARGET_HOME|g" "$SCRIPT_DIR/gnome-settings/gnome-extensions.dconf" | dconf load /org/gnome/shell/extensions/ 2>/dev/null || true
fi

# Ajustar eventuais caminhos com usuário hardcoded nas configs restauradas
find "$TARGET_HOME/.config" -maxdepth 3 -type f \( -name "*.json" -o -name "*.conf" -o -name "*.ini" -o -name "*.sh" -o -name "*.desktop" \) -exec sed -i "s|/home/vinicius|$TARGET_HOME|g" {} + 2>/dev/null || true


# Habilitar extensões do GNOME
if [ -f "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt" ] && command -v gnome-extensions &> /dev/null; then
    echo "  -> Habilitando extensões ativas..."
    while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        gnome-extensions enable "$ext" 2>/dev/null || true
    done < "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt"
    echo "  ✓ Extensões do GNOME ativadas."
fi

# 14. APLICAR WALLPAPER E WPGTK / PYWAL
echo ""
echo "🖼️ 14. Aplicando Wallpaper e Esquema de Cores Pywal..."
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

# 15. SERVIÇOS DO SISTEMA E SHELL PADRÃO
echo ""
echo "🛠️ 15. Habilitando serviços do sistema..."
sudo systemctl enable --now docker.service 2>/dev/null || true
sudo usermod -aG docker "$CURRENT_USER" 2>/dev/null || true
sudo systemctl enable --now bluetooth.service 2>/dev/null || true
sudo systemctl enable --now NetworkManager.service 2>/dev/null || true

if [ ! -d "/var/lib/mysql" ] && command -v mariadb-install-db &> /dev/null; then
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql 2>/dev/null || true
fi
sudo systemctl enable --now mariadb.service 2>/dev/null || true
sudo systemctl enable --now postgresql.service 2>/dev/null || true

# Habilitar serviços de usuário (conky, etc.)
systemctl --user enable conky.service 2>/dev/null || true

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
