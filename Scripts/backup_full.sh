#!/bin/bash

# --- CONFIGURAÇÕES DO USUÁRIO ---
GITHUB_USER="Viniciusulpicio"
# ⚠️ COLE SEU TOKEN NOVO ABAIXO (Mantenha as aspas)
GITHUB_TOKEN=$(cat ~/.gh_token) 
REPO_NAME="dotfiles-arch"
REPO_DIR="/home/vinicius/Dotfiles-Arch"

# Monta a URL com autenticação
REMOTE_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# --- 0. PREPARAÇÃO GIT ---
if [ ! -d "$REPO_DIR" ]; then
    echo "📥 Clonando repositório..."
    git clone "https://github.com/${GITHUB_USER}/${REPO_NAME}.git" "$REPO_DIR"
    cd "$REPO_DIR" && git remote set-url origin "$REMOTE_URL" && cd ~
else
    cd "$REPO_DIR" || exit
    git remote set-url origin "$REMOTE_URL"
    if [ -d ".git" ]; then
        echo "📥 Baixando atualizações..."
        git pull origin main --rebase || echo "⚠️ Repositório novo."
    fi
fi
cd ~

# Função copy_safe
copy_safe() {
    if [ -e "$1" ]; then
        echo "📂 Copiando: $(basename "$1")"
        rsync -avL --exclude='.git' --exclude='node_modules' --exclude='Cache' "$1" "$2" > /dev/null 2>&1
    fi
}

echo "--- 1. Preparando diretórios ---"
mkdir -p "$REPO_DIR/.config" "$REPO_DIR/pkg-lists" "$REPO_DIR/gnome-settings" "$REPO_DIR/Pictures" "$REPO_DIR/.local/bin" "$REPO_DIR/.local/share"

echo "--- 2. Escaneando Sistema (Modo Dinâmico) ---"
echo "📝 Salvando o que está instalado hoje..."
pacman -Qqe | grep -v "$(pacman -Qqm)" > "$REPO_DIR/pkg-lists/pacman_native.txt"
pacman -Qqm > "$REPO_DIR/pkg-lists/aur_packages.txt"

if command -v gnome-extensions &> /dev/null; then
    gnome-extensions list --enabled > "$REPO_DIR/pkg-lists/gnome_extensions_enabled.txt"
fi

if command -v code &> /dev/null; then
    code --list-extensions > "$REPO_DIR/pkg-lists/vscode_extensions.txt"
    # Salva configs do VS Code
    mkdir -p "$REPO_DIR/.config/Code/User"
    cp "$HOME/.config/Code/User/settings.json" "$REPO_DIR/.config/Code/User/" 2>/dev/null
    cp "$HOME/.config/Code/User/keybindings.json" "$REPO_DIR/.config/Code/User/" 2>/dev/null
    cp -r "$HOME/.config/Code/User/snippets" "$REPO_DIR/.config/Code/User/" 2>/dev/null
fi

# Dotfiles
dconf dump /org/gnome/ > "$REPO_DIR/gnome-settings/gnome-shell-backup.dconf"
cp -L ~/.zshrc ~/.p10k.zsh ~/.bashrc ~/.profile "$REPO_DIR/" 2>/dev/null

echo "📂 Copiando Pastas Importantes..."
copy_safe "$HOME/.config/gallery-dl" "$REPO_DIR/"
copy_safe "$HOME/Scripts" "$REPO_DIR/"
copy_safe "$HOME/Scripts" "$REPO_DIR/"
copy_safe "$HOME/Scripts" "$REPO_DIR/"
copy_safe "$HOME/.rion-dotfiles" "$REPO_DIR/"
copy_safe "$HOME/grub2-themes" "$REPO_DIR/"
copy_safe "$HOME/.local/share/gnome-shell" "$REPO_DIR/.local/share/"
copy_safe "$HOME/.oh-my-zsh/custom" "$REPO_DIR/.oh-my-zsh/"
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

# Configs Gerais
FOLDERS_CONFIG=("kitty" "wezterm" "fastfetch" "btop" "cava" "gtk-3.0" "gtk-4.0" "neofetch" "starship.toml" "wlogout" "wofi" "pop-shell" "tiling-assistant" "mimeapps.list" "user-dirs.dirs" "monitors.xml" "conky" "wpg" "wal" "alacritty" "systemd" "systemd" "systemd" "autostart" "BetterDiscord" "MangoHud" "obs-studio" "rclone" "VirtualBox" "Postman" "arduino-ide" "spicetify" "TeamSpeak3")

for item in "${FOLDERS_CONFIG[@]}"; do
    rm -rf "$REPO_DIR/.config/$item"
    copy_safe "$HOME/.config/$item" "$REPO_DIR/.config/"
done

echo "--- 3. Gerando Script de Restauração V13 (Híbrido) ---"
cat << 'EOF' > "$REPO_DIR/install.sh"
#!/bin/bash
echo "=== Restaurando Dotfiles V13 (Auto + Lista Essencial) ==="
CURRENT_USER=$(whoami)

# 1. Base Arch
sudo pacman -Sy --noconfirm archlinux-keyring
if ! command -v yay &> /dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git python-pipx wget unzip
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd -
fi

# 2. Rice Essencial
sudo pacman -S --needed --noconfirm fastfetch conky python-pywal imagemagick zsh gnome-shell-extensions jq curl pavucontrol
yay -S --needed --noconfirm wpgtk-git gnome-extensions-cli

# 3. LISTA DE SEGURANÇA (Seus Apps Obrigatórios)
# Isso garante que sua lista personalizada seja instalada mesmo se o backup falhar
echo "🛡️ Instalando Apps Essenciais (Garantia)..."

# Nativos (Oficiais)
APPS_FORCE_NATIVE=(
    "git" "nodejs" "npm" "docker" "docker-compose" 
    "mariadb"            # MySQL Server
    "mysql-workbench"    # Workbench
    "postgresql" 
    "openssl" 
    "steam" 
    "vlc" 
    "obs-studio"
)
for pkg in "${APPS_FORCE_NATIVE[@]}"; do
    sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null
done

# AUR (Externos)
APPS_FORCE_AUR=(
    "visual-studio-code-bin"   # VS Code (Versão Microsoft com Loja)
    "postman-bin"              # Postman
    "notion-app-electron"      # Notion (App Desktop)
    "teamspeak3"               # TeamSpeak 3
    "google-chrome"            # Chrome
    "spotify"                  # Spotify
    "heroic-games-launcher-bin"# Heroic (Epic/GOG)
)
for pkg in "${APPS_FORCE_AUR[@]}"; do
    yay -S --needed --noconfirm "$pkg" 2>/dev/null
done

# 4. Restaura o resto da lista automática (Modo Dinâmico)
echo "📦 Baixando o restante dos apps salvos no backup..."
if [ -f "pkg-lists/pacman_native.txt" ]; then
    sudo pacman -S --needed --noconfirm - < pkg-lists/pacman_native.txt 2>/dev/null
fi
if [ -f "pkg-lists/aur_packages.txt" ]; then
    yay -S --needed --noconfirm - < pkg-lists/aur_packages.txt 2>/dev/null
fi

# 5. Configuração de Serviços
echo "🛠️ Configurando Serviços..."
[ -x "$(command -v npm)" ] && sudo npm install -g typescript  # TypeScript
sudo systemctl enable --now docker.service 2>/dev/null
sudo usermod -aG docker $CURRENT_USER 2>/dev/null

if [ ! -d "/var/lib/mysql" ] && command -v mariadb-install-db &> /dev/null; then
    echo "Inicializando MariaDB..."
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
fi
sudo systemctl enable --now mariadb.service 2>/dev/null
sudo systemctl enable --now postgresql.service 2>/dev/null

# 6. Restaurar Arquivos
echo "📂 Restaurando Dotfiles..."
cp .zshrc .p10k.zsh .bashrc .profile ~/ 
cp -r .config/* ~/.config/
cp -r .rion-dotfiles ~/ 2>/dev/null
cp -r grub2-themes ~/ 2>/dev/null
mkdir -p ~/Pictures ~/.local/bin ~/.local/share
[ -d "Pictures/Wallpaper" ] && cp -r Pictures/Wallpaper ~/Pictures/
cp -r .local/bin/* ~/.local/bin/ 2>/dev/null
chmod +x ~/.local/bin/*

# Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
[ -d ".oh-my-zsh/custom" ] && cp -r .oh-my-zsh/custom/* ~/.oh-my-zsh/custom/

# Temas
[ -d ".themes" ] && cp -r .themes ~/ 
[ -d ".icons" ] && cp -r .icons ~/ 
[ -d ".local/share/themes" ] && mkdir -p ~/.local/share && cp -r .local/share/themes ~/.local/share/
[ -d ".local/share/icons" ] && mkdir -p ~/.local/share && cp -r .local/share/icons ~/.local/share/
[ -d ".local/share/fonts" ] && mkdir -p ~/.local/share && cp -r .local/share/fonts ~/.local/share/
[ -d ".local/share/gnome-shell" ] && cp -r .local/share/gnome-shell ~/.local/share/

# VS Code Extensions
if command -v code &> /dev/null && [ -f "pkg-lists/vscode_extensions.txt" ]; then
    cat pkg-lists/vscode_extensions.txt | while read extension; do
        code --install-extension "$extension" --force 2>/dev/null
    done
    cp .config/Code/User/*.json ~/.config/Code/User/ 2>/dev/null
fi

# Ajustes Finais
if [ "$CURRENT_USER" != "vinicius" ]; then
    sed -i "s|/home/vinicius|/home/$CURRENT_USER|g" gnome-settings/gnome-shell-backup.dconf
fi
dconf load /org/gnome/ < gnome-settings/gnome-shell-backup.dconf
dconf load /com/github/ < gnome-settings/github-extensions.dconf

if [ -f "pkg-lists/gnome_extensions_enabled.txt" ]; then
    sort -u pkg-lists/gnome_extensions_enabled.txt | while read extension; do
        gnome-extensions enable "$extension" 2>/dev/null
    done
fi

if command -v wpg &> /dev/null; then
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

# --- IDENTIDADE DO GIT (Importante) ---
git config user.email "viniciusulpicio@gmail.com"
git config user.name "Viniciusulpicio"
# --------------------------------------

git add .
git commit -m "Backup V13: Lista Essencial Inclusa - $(date)"
git push origin main
echo "✅ Script atualizado! Lista de segurança adicionada no instalador."
