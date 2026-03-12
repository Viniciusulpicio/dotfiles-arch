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
