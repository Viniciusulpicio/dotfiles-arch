#!/bin/bash
echo "=== Restaurando Rice + Full Stack Dev (GNOME DIET FINAL) ==="
CURRENT_USER=$(whoami)

# 1. Base e Yay
sudo pacman -Sy --noconfirm archlinux-keyring
if ! command -v yay &> /dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git python-pip python-pipx wget unzip curl jq
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd -
fi

# 2. Rice Essencial (GNOME Leve)
echo "🎨 Instalando base do ambiente gráfico..."
sudo pacman -S --needed --noconfirm fastfetch conky python-pywal imagemagick zsh gnome-shell-extensions gnome gdm
yay -S --needed --noconfirm wpgtk-git gnome-extensions-cli

# 3. INSTALAÇÃO DE APLICATIVOS (Full Stack + Tor)
echo "📦 Baixando Stack Completa de Desenvolvimento e Ferramentas..."

# --- NATIVOS (Pacman) ---
APPS_NATIVE=(
    "git" "nodejs" "npm" "docker" "docker-compose" "mariadb" "postgresql" "code" 
    "openssl" "vlc" "discord" "firefox" "btop" "wezterm" "jdk-openjdk" "unzip"
    "tor" "torbrowser-launcher" 
)
for pkg in "${APPS_NATIVE[@]}"; do
    sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || echo "⚠️ Falha Nativo: $pkg"
done

# --- AUR (Yay) ---
APPS_AUR=(
    "google-chrome" "spotify" "postman-bin" "mysql-workbench" "notion-app-electron" 
    "windsurf-bin" "antigravity" "gemini-cli-bin"
    "gnome-shell-extension-tiling-assistant" 
    "gnome-shell-extension-clipboard-indicator"
    "gnome-shell-extension-pop-shell-git"
)
for pkg in "${APPS_AUR[@]}"; do
    yay -S --needed --noconfirm "$pkg" 2>/dev/null || echo "⚠️ Falha AUR: $pkg"
done

# --- Ferramentas Globais (NPM / PIPX) ---
echo "⚙️ Instalando CLIs Globais..."
sudo npm install -g typescript ts-node nodemon
sudo npm install -g @google/generative-ai-cli 2>/dev/null 

# 4. Força Bruta: Swap de 30GB
echo "💾 Forçando a criação do Swap de 30GB no SSD..."
sudo swapoff -a 2>/dev/null
sudo rm -f /swapfile
# Tenta alocação rápida primeiro; se falhar, vai no método seguro bloco a bloco (dd)
sudo fallocate -l 30G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=30720 status=progress
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

if ! grep -q '/swapfile' /etc/fstab; then
    echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
fi

# 5. Configuração de Serviços (Otimizado para 4GB RAM)
echo "🛠️ Configurando Serviços..."
sudo systemctl enable gdm.service
sudo usermod -aG docker $CURRENT_USER

# Inicializa o MariaDB (mas não habilita no boot)
if [ ! -d "/var/lib/mysql" ]; then
    echo "Inicializando diretório do MariaDB..."
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
fi

# Desativa serviços pesados para poupar a RAM do Mini PC
sudo systemctl disable docker.service 2>/dev/null
sudo systemctl disable postgresql.service 2>/dev/null
sudo systemctl disable mariadb.service 2>/dev/null
sudo systemctl disable tor.service 2>/dev/null # O Tor também fica desligado no boot por padrão

# 6. Restaurar Dotfiles (Seu ambiente)
echo "📂 Restaurando configurações pessoais..."
cp .zshrc .p10k.zsh .bashrc .profile ~/ 2>/dev/null
cp -r .config/* ~/.config/ 2>/dev/null
mkdir -p ~/Pictures/Wallpaper ~/.local/bin ~/.local/share
cp -r Pictures/Wallpaper/* ~/Pictures/Wallpaper/ 2>/dev/null
cp -r .local/bin/* ~/.local/bin/ 2>/dev/null
chmod +x ~/.local/bin/* 2>/dev/null

# Oh-My-Zsh Automático
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Extensões do VS Code
mkdir -p ~/.config/Code/User
[ -f ".config/Code/User/settings.json" ] && cp .config/Code/User/*.json ~/.config/Code/User/ 2>/dev/null
if command -v code &> /dev/null && [ -f "pkg-lists/vscode_extensions.txt" ]; then
    echo "🧩 Instalando extensões do VS Code..."
    cat pkg-lists/vscode_extensions.txt | while read extension; do
        code --install-extension "$extension" --force 2>/dev/null
    done
fi

if ! grep -q "fastfetch" ~/.zshrc; then
    echo -e "\n# Auto Fastfetch\nfastfetch" >> ~/.zshrc
fi

if [ "$SHELL" != "/bin/zsh" ]; then chsh -s /bin/zsh; fi

echo "======================================================="
echo "✅ TUDO PRONTO! O AMBIENTE DE DEV ESTÁ ARMADO."
echo "Swap de 30GB configurado. Bancos, Docker e Tor em modo manual."
echo "======================================================="
