#!/bin/bash
echo "=== Restaurando Rice + Full Stack Dev (V11 DIET) ==="
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
sudo pacman -S --needed --noconfirm fastfetch conky python-pywal imagemagick zsh gnome-shell-extensions jq curl gnome gdm
yay -S --needed --noconfirm wpgtk-git gnome-extensions-cli

# 3. INSTALAÇÃO DE APLICATIVOS
echo "📦 Instalando Stack de Desenvolvimento e Apps..."

# --- NATIVOS (Pacman) ---
APPS_NATIVE=(
    "git" "nodejs" "npm" "docker" "docker-compose" "mariadb" "postgresql" "code" "openssl" 
    "vlc" "discord" "firefox" "btop" "alacritty" "wezterm" "jdk-openjdk" "unzip"
)
for pkg in "${APPS_NATIVE[@]}"; do
    sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || echo "⚠️ Falha Nativo: $pkg"
done

# --- AUR (Yay) ---
APPS_AUR=(
    "google-chrome" "spotify" "postman-bin" "mysql-workbench" "notion-app-electron" 
    "wlogout" "wofi" "cava" 
    "gnome-shell-extension-tiling-assistant" 
    "gnome-shell-extension-pop-shell-git"
    "gnome-shell-extension-clipboard-indicator"
    "gnome-shell-extension-mediacontrols"
)
for pkg in "${APPS_AUR[@]}"; do
    yay -S --needed --noconfirm "$pkg" 2>/dev/null || echo "⚠️ Falha AUR: $pkg"
done

# 4. Configuração Pós-Instalação e Swap
echo "💾 Configurando Swap de 30GB (Segurança Máxima)..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 30G /swapfile && sudo chmod 600 /swapfile
    sudo mkswap /swapfile && sudo swapon /swapfile
    echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
fi

echo "🛠️ Configurando Serviços..."
sudo npm install -g typescript

# Habilita o GDM (Tela de login do GNOME)
sudo systemctl enable gdm.service

# Docker e Bancos instalados, mas NÃO habilitados no boot (rode manual via alias)
sudo usermod -aG docker $CURRENT_USER

if [ ! -d "/var/lib/mysql" ]; then
    echo "Inicializando MariaDB..."
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
fi

# 5. Restaurar Arquivos
echo "📂 Restaurando Dotfiles..."
cp .zshrc .p10k.zsh .bashrc .profile ~/ 
cp -r .config/* ~/.config/ 2>/dev/null
cp -r .rion-dotfiles ~/ 2>/dev/null
cp -r grub2-themes ~/ 2>/dev/null
mkdir -p ~/Pictures ~/.local/bin ~/.local/share
cp -r Pictures/Wallpaper ~/Pictures/ 2>/dev/null
cp -r .local/bin/* ~/.local/bin/ 2>/dev/null
chmod +x ~/.local/bin/* 2>/dev/null

# Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
[ -d ".oh-my-zsh/custom" ] && cp -r .oh-my-zsh/custom/* ~/.oh-my-zsh/custom/ 2>/dev/null

# Temas e Extensões Físicas
[ -d ".themes" ] && cp -r .themes ~/ 
[ -d ".icons" ] && cp -r .icons ~/ 
[ -d ".local/share/themes" ] && mkdir -p ~/.local/share && cp -r .local/share/themes ~/.local/share/
[ -d ".local/share/icons" ] && mkdir -p ~/.local/share && cp -r .local/share/icons ~/.local/share/
[ -d ".local/share/fonts" ] && mkdir -p ~/.local/share && cp -r .local/share/fonts ~/.local/share/
[ -d ".local/share/gnome-shell" ] && cp -r .local/share/gnome-shell ~/.local/share/

# VS Code Extensions
mkdir -p ~/.config/Code/User
[ -f ".config/Code/User/settings.json" ] && cp .config/Code/User/*.json ~/.config/Code/User/ 2>/dev/null
if command -v code &> /dev/null && [ -f "pkg-lists/vscode_extensions.txt" ]; then
    cat pkg-lists/vscode_extensions.txt | while read extension; do
        code --install-extension "$extension" --force 2>/dev/null
    done
fi

# 6. Ajustes Finais
if [ "$CURRENT_USER" != "vinicius" ]; then
    echo "⚠️ Ajustando usuário para $CURRENT_USER..."
    sed -i "s|/home/vinicius|/home/$CURRENT_USER|g" gnome-settings/gnome-shell-backup.dconf 2>/dev/null
    find ~/.config -type f -exec sed -i "s|/home/vinicius|/home/$CURRENT_USER|g" {} + 2>/dev/null
    find ~/.local/bin -type f -exec sed -i "s|/home/vinicius|/home/$CURRENT_USER|g" {} + 2>/dev/null
fi

if ! grep -q "fastfetch" ~/.zshrc; then
    echo -e "\n# Auto Fastfetch\nfastfetch" >> ~/.zshrc
fi

# Aplicar configurações do Dconf apenas se existirem
[ -f "gnome-settings/gnome-shell-backup.dconf" ] && dconf load /org/gnome/ < gnome-settings/gnome-shell-backup.dconf 2>/dev/null
[ -f "gnome-settings/github-extensions.dconf" ] && dconf load /com/github/ < gnome-settings/github-extensions.dconf 2>/dev/null

# Ativar Extensões via comando
gnome-extensions enable tiling-assistant@leleat-on-github 2>/dev/null
gnome-extensions enable pop-shell@system76.com 2>/dev/null
gnome-extensions enable clipboard-indicator@tudmotu.com 2>/dev/null
gnome-extensions enable mediacontrols@cliffniff.github.com 2>/dev/null

if [ -f "pkg-lists/gnome_extensions_enabled.txt" ]; then
    sort -u pkg-lists/gnome_extensions_enabled.txt | while read extension; do
        gnome-extensions enable "$extension" 2>/dev/null
    done 
fi

if command -v wpg &> /dev/null; then
    echo "🎨 Aplicando Wallpaper e Rice..."
    wpg -s "$(find ~/Pictures/Wallpaper -type f | head -n 1)" 2>/dev/null
fi

if [ "$SHELL" != "/bin/zsh" ]; then chsh -s /bin/zsh; fi
echo "=== PRONTO! REINICIE A MÁQUINA. Lembre-se de usar os aliases para subir os bancos de dados! ==="
