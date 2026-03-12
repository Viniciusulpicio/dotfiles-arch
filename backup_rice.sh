#!/bin/bash
REPO_DIR="/home/vinicius/temp/dotfiles-arch"
DATE=$(date +"%Y-%m-%d %H:%M:%S")
REMOTE_URL="https://github.com/Viniciusulpicio/dotfiles-arch.git"

# --- 0. PREPARAÇÃO GIT (PROTEÇÃO DO README) ---
# Se a pasta não existe, clona primeiro para garantir que pega o README
if [ ! -d "$REPO_DIR" ]; then
    echo "📥 Clonando repositório para baixar o README..."
    git clone "$REMOTE_URL" "$REPO_DIR"
else
    # Se já existe, entra e puxa o README antes de mexer
    cd "$REPO_DIR" || exit
    if [ -d ".git" ]; then
        echo "📥 Baixando atualizações do GitHub (README)..."
        git pull origin main --rebase || echo "⚠️ Nada para puxar ou repositório novo."
    fi
fi

# Volta para a home para continuar o script
cd ~

# Função copy_safe
copy_safe() {
    if [ -e "$1" ]; then
        echo "📂 Copiando: $(basename "$1")"
        # Filtros aplicados para Antigravity e Code conforme solicitado
        rsync -avL --exclude='.git' \
                  --exclude='node_modules' \
                  --exclude='Cache' \
                  --exclude='Cache_Data' \
                  --exclude='History' \
                  --exclude='workspaceStorage' \
                  --exclude='logs' \
                  --exclude='User' \
                  "$1" "$2" > /dev/null 2>&1
    fi
}

echo "--- 1. Preparando diretório: $REPO_DIR ---"
mkdir -p "$REPO_DIR/.config" "$REPO_DIR/pkg-lists" "$REPO_DIR/gnome-settings" "$REPO_DIR/Pictures" "$REPO_DIR/.local/bin" "$REPO_DIR/.local/share"

echo "--- 2. Copiando configurações ---"
# Pacotes
pacman -Qqe | grep -v "$(pacman -Qqm)" > "$REPO_DIR/pkg-lists/pacman_native.txt"
pacman -Qqm > "$REPO_DIR/pkg-lists/aur_packages.txt"
if command -v gnome-extensions &> /dev/null; then
    gnome-extensions list --enabled > "$REPO_DIR/pkg-lists/gnome_extensions_enabled.txt"
fi

# VS Code - Cópia Manual Controlada (Para evitar History e workspaceStorage)
if command -v code &> /dev/null; then
    echo "📝 Salvando lista de extensões do VS Code..."
    code --list-extensions > "$REPO_DIR/pkg-lists/vscode_extensions.txt"
    mkdir -p "$REPO_DIR/.config/Code/User"
    cp "$HOME/.config/Code/User/settings.json" "$REPO_DIR/.config/Code/User/" 2>/dev/null
    cp "$HOME/.config/Code/User/keybindings.json" "$REPO_DIR/.config/Code/User/" 2>/dev/null
    [ -d "$HOME/.config/Code/User/snippets" ] && cp -r "$HOME/.config/Code/User/snippets" "$REPO_DIR/.config/Code/User/"
fi

# Dconf e Arquivos Home
dconf dump /org/gnome/ > "$REPO_DIR/gnome-settings/gnome-shell-backup.dconf"
dconf dump /com/github/ > "$REPO_DIR/gnome-settings/github-extensions.dconf"
cp -L ~/.zshrc ~/.p10k.zsh ~/.bashrc ~/.profile "$REPO_DIR/" 2>/dev/null

echo "Salvando pastas Críticas..."
copy_safe "$HOME/.rion-dotfiles" "$REPO_DIR/"
copy_safe "$HOME/grub2-themes" "$REPO_DIR/"

# Extensões GNOME Físicas (Tiling, Menus e Clipboard)
if [ -d "$HOME/.local/share/gnome-shell" ]; then
    echo "📂 Salvando extensões do GNOME (Físico)..."
    mkdir -p "$REPO_DIR/.local/share"
    copy_safe "$HOME/.local/share/gnome-shell" "$REPO_DIR/.local/share/"
fi

# Oh-My-Zsh (Custom)
if [ -d "$HOME/.oh-my-zsh/custom" ]; then
    mkdir -p "$REPO_DIR/.oh-my-zsh"
    copy_safe "$HOME/.oh-my-zsh/custom" "$REPO_DIR/.oh-my-zsh/"
fi

# Scripts e Wallpapers
[ -d "$HOME/.local/bin" ] && rsync -avL "$HOME/.local/bin/" "$REPO_DIR/.local/bin/" > /dev/null 2>&1
if [ -d "$HOME/Pictures/Wallpaper" ]; then
    rm -rf "$REPO_DIR/Pictures/Wallpaper"
    copy_safe "$HOME/Pictures/Wallpaper" "$REPO_DIR/Pictures/"
fi

# Temas e Ícones
FOLDERS_EXTRA=(".themes" ".icons" ".local/share/themes" ".local/share/icons" ".local/share/fonts")
for folder in "${FOLDERS_EXTRA[@]}"; do
    if [ -d "$HOME/$folder" ]; then
        DEST="$REPO_DIR/$(dirname "$folder")"
        mkdir -p "$DEST"
        copy_safe "$HOME/$folder" "$DEST/"
    fi
done

# Configs
FOLDERS_CONFIG=("kitty" "wezterm" "fastfetch" "btop" "cava" "gtk-3.0" "gtk-4.0" "neofetch" "starship.toml" "wlogout" "wofi" "pop-shell" "tiling-assistant" "mimeapps.list" "user-dirs.dirs" "monitors.xml" "conky" "wpg" "wal" "alacritty" "autostart" "BetterDiscord" "MangoHud" "obs-studio" "rclone" "VirtualBox" "Postman" "arduino-ide" "spicetify" "TeamSpeak3" "Antigravity")

for item in "${FOLDERS_CONFIG[@]}"; do
    rm -rf "$REPO_DIR/.config/$item"
    copy_safe "$HOME/.config/$item" "$REPO_DIR/.config/"
done

echo "--- 3. Gerando Script de Instalação V11 (Com as Extensões Novas) ---"
cat << 'EOF' > "$REPO_DIR/install.sh"
#!/bin/bash
echo "=== Restaurando Rice + Full Stack Dev (V11) ==="
CURRENT_USER=$(whoami)

# 1. Base
sudo pacman -Sy --noconfirm archlinux-keyring
if ! command -v yay &> /dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git python-pipx wget unzip
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd -
fi

# 2. Rice Essencial
echo "🎨 Instalando base do Rice..."
sudo pacman -S --needed --noconfirm fastfetch conky python-pywal imagemagick zsh gnome-shell-extensions jq curl
yay -S --needed --noconfirm wpgtk-git gnome-extensions-cli

# 3. INSTALAÇÃO DE APLICATIVOS
echo "📦 Instalando Stack de Desenvolvimento e Apps..."

# --- NATIVOS (Pacman) ---
APPS_NATIVE=(
    "git" "nodejs" "npm" "docker" "docker-compose" "mariadb" "postgresql" "code" "openssl" 
    "vlc" "obs-studio" "discord" "steam" "firefox" "btop" "alacritty" "wezterm" "jdk-openjdk" "unzip"
)
for pkg in "${APPS_NATIVE[@]}"; do
    sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || echo "⚠️ Falha Nativo: $pkg"
done

# --- AUR (Yay) ---
APPS_AUR=(
    "google-chrome" "spotify" "postman-bin" "mysql-workbench" "notion-app-electron" 
    "heroic-games-launcher-bin" "teamspeak3"
    "mangohud" "goverlay" "wlogout" "wofi" "cava" 
    "gnome-shell-extension-tiling-assistant" 
    "gnome-shell-extension-pop-shell-git"
    "gnome-shell-extension-clipboard-indicator"
    "gnome-shell-extension-mediacontrols"
)
for pkg in "${APPS_AUR[@]}"; do
    yay -S --needed --noconfirm "$pkg" 2>/dev/null || echo "⚠️ Falha AUR: $pkg"
done

# 4. Configuração Pós-Instalação
echo "🛠️ Configurando Serviços..."
sudo npm install -g typescript
sudo systemctl enable --now docker.service
sudo usermod -aG docker $CURRENT_USER
if [ ! -d "/var/lib/mysql" ]; then
    echo "Inicializando MariaDB..."
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
fi
sudo systemctl enable --now mariadb.service
sudo systemctl enable --now postgresql.service

# 5. Restaurar Arquivos
echo "📂 Restaurando Dotfiles..."
cp .zshrc .p10k.zsh .bashrc .profile ~/ 
cp -r .config/* ~/.config/
cp -r .rion-dotfiles ~/ 
cp -r grub2-themes ~/ 
mkdir -p ~/Pictures ~/.local/bin ~/.local/share
cp -r Pictures/Wallpaper ~/Pictures/
cp -r .local/bin/* ~/.local/bin/
chmod +x ~/.local/bin/*

# Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
[ -d ".oh-my-zsh/custom" ] && cp -r .oh-my-zsh/custom/* ~/.oh-my-zsh/custom/

# Temas e Extensões Físicas
[ -d ".themes" ] && cp -r .themes ~/ 
[ -d ".icons" ] && cp -r .icons ~/ 
[ -d ".local/share/themes" ] && mkdir -p ~/.local/share && cp -r .local/share/themes ~/.local/share/
[ -d ".local/share/icons" ] && mkdir -p ~/.local/share && cp -r .local/share/icons ~/.local/share/
[ -d ".local/share/fonts" ] && mkdir -p ~/.local/share && cp -r .local/share/fonts ~/.local/share/
[ -d ".local/share/gnome-shell" ] && cp -r .local/share/gnome-shell ~/.local/share/

# VS Code Extensions
mkdir -p ~/.config/Code/User
[ -f ".config/Code/User/settings.json" ] && cp .config/Code/User/*.json ~/.config/Code/User/
if command -v code &> /dev/null; then
    cat pkg-lists/vscode_extensions.txt | while read extension; do
        code --install-extension "$extension" --force 2>/dev/null
    done
fi

# 6. Ajustes Finais
if [ "$CURRENT_USER" != "vinicius" ]; then
    echo "⚠️ Ajustando usuário para $CURRENT_USER..."
    sed -i "s|/home/vinicius|/home/$CURRENT_USER|g" gnome-settings/gnome-shell-backup.dconf
    find ~/.config -type f -exec sed -i "s|/home/vinicius|/home/$CURRENT_USER|g" {} +
    find ~/.local/bin -type f -exec sed -i "s|/home/vinicius|/home/$CURRENT_USER|g" {} +
fi

if ! grep -q "fastfetch" ~/.zshrc; then
    echo -e "\n# Auto Fastfetch\nfastfetch" >> ~/.zshrc
fi

dconf load /org/gnome/ < gnome-settings/gnome-shell-backup.dconf
dconf load /com/github/ < gnome-settings/github-extensions.dconf

# Ativar Extensões via comando
gnome-extensions enable tiling-assistant@leleat-on-github 2>/dev/null
gnome-extensions enable pop-shell@system76.com 2>/dev/null
gnome-extensions enable clipboard-indicator@tudmotu.com 2>/dev/null
gnome-extensions enable mediacontrols@cliffniff.github.com 2>/dev/null

sort -u pkg-lists/gnome_extensions_enabled.txt | while read extension; do
    gnome-extensions enable "$extension" 2>/dev/null
done 

if command -v wpg &> /dev/null; then
    echo "🎨 Aplicando Wallpaper..."
    wpg -s "$(find ~/Pictures/Wallpaper -type f | head -n 1)"
fi

if [ "$SHELL" != "/bin/zsh" ]; then chsh -s /bin/zsh; fi
echo "=== PRONTO! REINICIE A MÁQUINA. ==="
EOF
chmod +x "$REPO_DIR/install.sh"

# Git Push Inteligente
cd "$REPO_DIR" || exit
if [ ! -d ".git" ]; then
    git init
    git branch -M main
    git remote add origin "$REMOTE_URL"
fi

git add .
git commit -m "Backup V11: Limpeza de Histórico e Caches (Antigravity/Code)"
git push origin main
echo " Script V12 Completo! Históricos e pastas sensíveis removidos."