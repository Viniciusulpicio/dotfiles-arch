#!/bin/bash
echo "=== Restaurando Setup Lite-Máximo (XFCE + Full Stack) ==="
CURRENT_USER=$(whoami)

# 1. Base e Yay
sudo pacman -Sy --noconfirm archlinux-keyring
if ! command -v yay &> /dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git wget unzip
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd -
fi

# 2. Interface Leve (XFCE) e Base do Terminal
# XFCE consome ~500MB de RAM, contra ~1.5GB do GNOME.
echo "🎨 Instalando XFCE4 e base do sistema..."
sudo pacman -S --needed --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter zsh fastfetch jq curl imagemagick

# 3. INSTALAÇÃO DE APLICATIVOS (Sua Stack Completa)
echo "📦 Instalando Stack de Desenvolvimento e Apps..."

APPS_NATIVE=(
    "git" "nodejs" "npm" "postgresql" "mariadb" "docker" "docker-compose" 
    "code" "firefox" "discord" "vlc" "btop" "alacritty" "wezterm" 
    "jdk-openjdk" "unzip" "openssl"
)
for pkg in "${APPS_NATIVE[@]}"; do
    sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || echo "⚠️ Falha Nativo: $pkg"
done

APPS_AUR=(
    "google-chrome" "spotify" "postman-bin" "mysql-workbench" "notion-app-electron"
)
for pkg in "${APPS_AUR[@]}"; do
    yay -S --needed --noconfirm "$pkg" 2>/dev/null || echo "⚠️ Falha AUR: $pkg"
done

# 4. Configuração de Serviços e Swap
echo "💾 Configurando Swap de 30GB (Segurança Máxima)..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 30G /swapfile && sudo chmod 600 /swapfile
    sudo mkswap /swapfile && sudo swapon /swapfile
    echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
fi

echo "🛠️ Configurando Serviços..."
sudo npm install -g typescript
sudo systemctl enable lightdm.service
sudo systemctl enable postgresql.service
# Docker e MariaDB instalados, mas NÃO habilitados no boot (rode manual quando precisar)
sudo usermod -aG docker $CURRENT_USER

# Inicialização dos Bancos
sudo -u postgres initdb -D /var/lib/postgres/data 2>/dev/null
if [ ! -d "/var/lib/mysql" ]; then
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
fi

# 5. Restaurar Dotfiles (Seu toque pessoal)
echo "📂 Restaurando seu Terminal e Configurações..."
cp .zshrc .p10k.zsh .bashrc .profile ~/ 
cp -r .config/* ~/.config/ 2>/dev/null
mkdir -p ~/Pictures ~/.local/bin
cp -r Pictures/Wallpaper ~/Pictures/ 2>/dev/null
cp -r .local/bin/* ~/.local/bin/ 2>/dev/null
chmod +x ~/.local/bin/* 2>/dev/null

# Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# VS Code Sync
mkdir -p ~/.config/Code/User
[ -f ".config/Code/User/settings.json" ] && cp .config/Code/User/*.json ~/.config/Code/User/ 2>/dev/null

# 6. Ajustes de Ambiente
if [ "$SHELL" != "/bin/zsh" ]; then chsh -s /bin/zsh; fi

echo "=== TUDO PRONTO! ==="
echo "Dica: Como você tem 4GB de RAM, use 'sudo systemctl start docker' apenas quando for usar."
