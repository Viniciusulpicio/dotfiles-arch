#!/bin/bash
# ==============================================================================
# Script de Backup Automatizado do Rice e Dotfiles (Arch Linux + GNOME)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

echo "🚀 Iniciando Backup Completo do Rice e Dotfiles para: $REPO_DIR"
echo "📅 Data: $DATE"

# Função para cópia segura de arquivos/pastas com filtros de lixo/cache
copy_safe() {
    local src="$1"
    local dest="$2"
    if [ -e "$src" ]; then
        echo "  -> Copiando: $(basename "$src")"
        rsync -avL --delete \
                  --exclude='.git' \
                  --exclude='node_modules' \
                  --exclude='Cache' \
                  --exclude='Cache_Data' \
                  --exclude='CachedData' \
                  --exclude='CachedExtensionVSIXs' \
                  --exclude='GPUCache' \
                  --exclude='Code Cache' \
                  --exclude='DawnGraphiteCache' \
                  --exclude='DawnWebGPUCache' \
                  --exclude='Service Worker' \
                  --exclude='Partitions' \
                  --exclude='WidevineCdm' \
                  --exclude='Crashpad' \
                  --exclude='IndexedDB' \
                  --exclude='blob_storage' \
                  --exclude='Session Storage' \
                  --exclude='Local Storage' \
                  --exclude='WebStorage' \
                  --exclude='Dictionaries' \
                  --exclude='History' \
                  --exclude='workspaceStorage' \
                  --exclude='globalStorage' \
                  --exclude='logs' \
                  --exclude='Backups' \
                  --exclude='*.log' \
                  --exclude='*.tmp' \
                  --exclude='*.iso' \
                  --exclude='*.iso.tmp' \
                  --exclude='*-journal' \
                  --exclude='*-wal' \
                  --exclude='agy*' \
                  --exclude='rclone' \
                  --exclude='composer' \
                  "$src" "$dest" > /dev/null 2>&1 || true
    fi
}

# 1. PREPARANDO PASTAS DE DESTINO
echo "📁 1. Preparando estrutura de diretórios..."
mkdir -p "$REPO_DIR/.config" \
         "$REPO_DIR/pkg-lists" \
         "$REPO_DIR/gnome-settings" \
         "$REPO_DIR/Pictures/Wallpaper" \
         "$REPO_DIR/.local/bin" \
         "$REPO_DIR/.local/share" \
         "$REPO_DIR/.oh-my-zsh/custom"

# 2. EXPORTANDO LISTAS DE PACOTES E EXTENSÕES
echo "📦 2. Exportando listas de pacotes e extensões do sistema..."

# Pacotes nativos explicitamente instalados (excluindo AUR)
if command -v pacman &> /dev/null; then
    AUR_PKGS=$(pacman -Qqm 2>/dev/null || true)
    if [ -n "$AUR_PKGS" ]; then
        pacman -Qqe | grep -Fxv -f <(echo "$AUR_PKGS") | sort -u > "$REPO_DIR/pkg-lists/pacman_native.txt"
        echo "$AUR_PKGS" | sort -u > "$REPO_DIR/pkg-lists/aur_packages.txt"
    else
        pacman -Qqe | sort -u > "$REPO_DIR/pkg-lists/pacman_native.txt"
        > "$REPO_DIR/pkg-lists/aur_packages.txt"
    fi
    echo "  ✓ Pacman nativos salvos: $(wc -l < "$REPO_DIR/pkg-lists/pacman_native.txt") pacotes"
    echo "  ✓ AUR salvos: $(wc -l < "$REPO_DIR/pkg-lists/aur_packages.txt") pacotes"
fi

# Extensões GNOME ativadas e totais
if command -v gnome-extensions &> /dev/null; then
    gnome-extensions list --enabled | sort -u > "$REPO_DIR/pkg-lists/gnome_extensions_enabled.txt"
    gnome-extensions list | sort -u > "$REPO_DIR/pkg-lists/gnome_extensions_all.txt"
    echo "  ✓ Extensões GNOME ativas salvas: $(wc -l < "$REPO_DIR/pkg-lists/gnome_extensions_enabled.txt") extensões"
fi

# Extensões VS Code
if command -v code &> /dev/null; then
    code --list-extensions | sort -u > "$REPO_DIR/pkg-lists/vscode_extensions.txt"
    echo "  ✓ Extensões VS Code salvas: $(wc -l < "$REPO_DIR/pkg-lists/vscode_extensions.txt") extensões"
fi

# Flatpaks
if command -v flatpak &> /dev/null; then
    flatpak list --app --columns=application 2>/dev/null | sort -u > "$REPO_DIR/pkg-lists/flatpak_list.txt" || true
    echo "  ✓ Flatpaks salvos"
fi

# 3. BACKUP DE DCONF (GNOME E EXTENSÕES)
echo "🎛️ 3. Exportando configurações do GNOME (dconf)..."
if command -v dconf &> /dev/null; then
    dconf dump / > "$REPO_DIR/gnome-settings/full-backup.dconf" 2>/dev/null || true
    dconf dump /org/gnome/ > "$REPO_DIR/gnome-settings/gnome-shell-backup.dconf" 2>/dev/null || true
    dconf dump /com/github/ > "$REPO_DIR/gnome-settings/github-extensions.dconf" 2>/dev/null || true
    dconf dump /org/gnome/shell/extensions/ > "$REPO_DIR/gnome-settings/gnome-extensions.dconf" 2>/dev/null || true
    echo "  ✓ Dconf exportado com sucesso"
fi

# 4. BACKUP DE ARQUIVOS DE SHELL E PROFILE (HOME)
echo "🐚 4. Copiando arquivos de ambiente Shell e Perfil..."
for file in .zshrc .p10k.zsh .bashrc .bash_profile .profile .imwheelrc .gitconfig .nvidia-settings-rc .notas_rapidas.txt; do
    if [ -f "$HOME/$file" ]; then
        cp -f "$HOME/$file" "$REPO_DIR/"
        echo "  ✓ $file"
    fi
done

# 5. BACKUP DE RICE, TEMAS, GRUB E WALLPAPERS
echo "🎨 5. Copiando temas, rice, grub e wallpapers..."
[ -d "$HOME/.rion-dotfiles" ] && copy_safe "$HOME/.rion-dotfiles" "$REPO_DIR/"
[ -d "$HOME/grub2-themes" ] && copy_safe "$HOME/grub2-themes" "$REPO_DIR/"

# Wallpapers
if [ -d "$HOME/Pictures/Wallpaper" ]; then
    copy_safe "$HOME/Pictures/Wallpaper/" "$REPO_DIR/Pictures/Wallpaper/"
elif [ -d "$HOME/Imagens/Wallpaper" ]; then
    copy_safe "$HOME/Imagens/Wallpaper/" "$REPO_DIR/Pictures/Wallpaper/"
elif [ -d "$HOME/.config/wpg/wallpapers" ]; then
    copy_safe "$HOME/.config/wpg/wallpapers/" "$REPO_DIR/Pictures/Wallpaper/"
fi

# Wallpaper atual
CURRENT_WALL=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'" | sed 's|file://||')
if [ -n "$CURRENT_WALL" ] && [ -f "$CURRENT_WALL" ]; then
    if [ "$CURRENT_WALL" != "$REPO_DIR/wallpaper_atual.jpg" ]; then
        cp -f "$CURRENT_WALL" "$REPO_DIR/wallpaper_atual.jpg"
        echo "  ✓ Wallpaper atual copiado: $CURRENT_WALL"
    else
        echo "  ✓ Wallpaper atual já preservado no repositório"
    fi
fi

# 6. SCRIPTS LOCAIS (.local/bin)
echo "📜 6. Copiando scripts em ~/.local/bin (excluindo binários pesados)..."
if [ -d "$HOME/.local/bin" ]; then
    mkdir -p "$REPO_DIR/.local/bin"
    rsync -avL --exclude='agy*' --exclude='rclone' --exclude='composer' "$HOME/.local/bin/" "$REPO_DIR/.local/bin/" > /dev/null 2>&1 || true
fi

# 7. ASSETS EM .local/share (Fontes, Ícones, Extensões GNOME, Aplicações)
echo "🔤 7. Copiando assets em ~/.local/share..."
if [ -d "$HOME/.local/share/gnome-shell" ]; then
    copy_safe "$HOME/.local/share/gnome-shell" "$REPO_DIR/.local/share/"
fi
for share_dir in fonts icons themes applications; do
    if [ -d "$HOME/.local/share/$share_dir" ]; then
        copy_safe "$HOME/.local/share/$share_dir" "$REPO_DIR/.local/share/"
    fi
done

# 8. OH-MY-ZSH CUSTOM
if [ -d "$HOME/.oh-my-zsh/custom" ]; then
    echo "⚡ 8. Copiando customizações do Oh-My-Zsh..."
    mkdir -p "$REPO_DIR/.oh-my-zsh/custom"
    copy_safe "$HOME/.oh-my-zsh/custom" "$REPO_DIR/.oh-my-zsh/"
fi

# 9. CONFIGURAÇÕES EM ~/.config
echo "⚙️ 9. Copiando configurações de aplicativos em ~/.config..."
CONFIG_APPS=(
    "alacritty"
    "wezterm"
    "kitty"
    "fastfetch"
    "btop"
    "cava"
    "conky"
    "gtk-3.0"
    "gtk-4.0"
    "pop-shell"
    "tiling-assistant"
    "wlogout"
    "wofi"
    "wpg"
    "wal"
    "autostart"
    "BetterDiscord"
    "MangoHud"
    "obs-studio"
    "VirtualBox"
    "spicetify"
    "TeamSpeak3"
    "neofetch"
    "goverlay"
    "gamemode.ini"
    "mimeapps.list"
    "monitors.xml"
    "user-dirs.dirs"
    "user-dirs.locale"
    "connections.db"
    "gnome-xdg-terminals.list"
    "xdg-terminals.list"
    "argos"
    "input-remapper-2"
    "devilspie2"
    "freerdp"
    "gallery-dl"
    "gsconnect"
    "pamac"
    "pavucontrol.ini"
    "Pinta"
    "QtProject.conf"
    "systemd"
    "vesktop"
    "vkBasalt"
    "vlc"
    "winboat"
    "Arduino IDE"
)

for app in "${CONFIG_APPS[@]}"; do
    if [ -e "$HOME/.config/$app" ]; then
        copy_safe "$HOME/.config/$app" "$REPO_DIR/.config/"
    fi
done

# VS Code configs (Settings, Keybindings, Snippets e MCP)
if [ -d "$HOME/.config/Code/User" ]; then
    mkdir -p "$REPO_DIR/.config/Code/User"
    [ -f "$HOME/.config/Code/User/settings.json" ] && cp -f "$HOME/.config/Code/User/settings.json" "$REPO_DIR/.config/Code/User/" 2>/dev/null || true
    [ -f "$HOME/.config/Code/User/keybindings.json" ] && cp -f "$HOME/.config/Code/User/keybindings.json" "$REPO_DIR/.config/Code/User/" 2>/dev/null || true
    [ -f "$HOME/.config/Code/User/tasks.json" ] && cp -f "$HOME/.config/Code/User/tasks.json" "$REPO_DIR/.config/Code/User/" 2>/dev/null || true
    [ -f "$HOME/.config/Code/User/mcp.json" ] && cp -f "$HOME/.config/Code/User/mcp.json" "$REPO_DIR/.config/Code/User/" 2>/dev/null || true
    [ -d "$HOME/.config/Code/User/snippets" ] && copy_safe "$HOME/.config/Code/User/snippets" "$REPO_DIR/.config/Code/User/"
fi

# Limpeza profunda de bloat / caches / symlinks residuais na pasta de dotfiles
echo "🧹 Limpando caches e dados temporários do repositório..."
rm -rf "$REPO_DIR/.config/'*'" "$REPO_DIR/.config/*" 2>/dev/null || true
rm -rf "$REPO_DIR/.config/Code/Cookies"* "$REPO_DIR/.config/Code/DIPS"* "$REPO_DIR/.config/Code/Dawn"* \
       "$REPO_DIR/.config/Code/Dictionaries" "$REPO_DIR/.config/Code/GPUCache" "$REPO_DIR/.config/Code/Crashpad" \
       "$REPO_DIR/.config/Code/Local Storage" "$REPO_DIR/.config/Code/Preferences" "$REPO_DIR/.config/Code/Service Worker" \
       "$REPO_DIR/.config/Code/Session Storage" "$REPO_DIR/.config/Code/Shared Dictionary" "$REPO_DIR/.config/Code/SharedStorage"* \
       "$REPO_DIR/.config/Code/TransportSecurity" "$REPO_DIR/.config/Code/Trust Tokens"* "$REPO_DIR/.config/Code/WebStorage" \
       "$REPO_DIR/.config/Code/languagepacks.json" "$REPO_DIR/.config/Code/machineid" "$REPO_DIR/.config/Code/Network Persistent State" \
       "$REPO_DIR/.config/Code/User/globalStorage" "$REPO_DIR/.config/Code/User/workspaceStorage" "$REPO_DIR/.config/Code/User/History" \
       "$REPO_DIR/.config/discord" "$REPO_DIR/.config/arduino-ide" 2>/dev/null || true

# 10. VERIFICAÇÃO E COMMIT NO GIT
echo "🌿 10. Sincronizando com o Git..."
cd "$REPO_DIR"

chmod +x "$REPO_DIR/install.sh" "$REPO_DIR/backup_rice.sh" "$REPO_DIR/restore_full_system.py" 2>/dev/null || true

git add -A

if git diff --staged --quiet; then
    echo "✨ Nenhuma alteração detectada. Repositório já está 100% atualizado!"
else
    git commit -m "Rice Completo: Backup de todas as configurações, extensões, temas e dotfiles ($DATE)"
    echo "📤 Enviando alterações para o GitHub..."
    git push origin main
    echo "✅ Rice e dotfiles enviados para o GitHub com sucesso!"
fi
