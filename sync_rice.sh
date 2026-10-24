#!/bin/bash
# ==============================================================================
# Script de Sincronização Rápida entre PC Principal e Notebook (Arch Rice & Dev)
# Equipara pacotes novos, configs (incluindo agy), extensões e scripts sem
# apagar projetos, jogos ou reinstalar o sistema do zero.
# ==============================================================================
set -e

if [ "$EUID" -eq 0 ]; then
    echo "⚠️ Execute como seu usuário normal (./sync_rice.sh), sem sudo."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="$HOME"
BACKUP_DIR="$TARGET_HOME/.dotfiles-sync-backup-$(date +%Y%m%d_%H%M%S)"

echo "================================================================="
echo " 🔄 Sincronizando modificações do Repositório com esta máquina"
echo " 📁 Repositório: $SCRIPT_DIR"
echo "================================================================="

# 1. Atualizar repositório com o GitHub
echo "📥 1. Baixando últimas alterações do GitHub (git pull)..."
cd "$SCRIPT_DIR"
git pull --rebase origin main || git pull origin main

# 2. Instalar apenas pacotes faltantes (Pacman, AUR, Flatpak)
echo ""
echo "📦 2. Verificando pacotes novos para instalar..."
HAS_NVIDIA=false
if command -v lspci &>/dev/null && lspci | grep -qi "nvidia"; then
    HAS_NVIDIA=true
fi

INSTALLED_PKGS=$(pacman -Qq 2>/dev/null || true)
REPO_PKGS=$(pacman -Slq 2>/dev/null || true)

# 2.1 Pacotes Nativos
TO_INSTALL_PACMAN=()
if [ -f "$SCRIPT_DIR/pkg-lists/pacman_native.txt" ]; then
    while read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        if [ "$HAS_NVIDIA" = false ] && echo "$pkg" | grep -qE '^(nvidia|cuda|cudnn|libva-nvidia|lib32-nvidia|opencl-nvidia|python-pytorch-cuda)'; then
            continue
        fi
        if ! echo "$INSTALLED_PKGS" | grep -qx "$pkg" && echo "$REPO_PKGS" | grep -qx "$pkg"; then
            TO_INSTALL_PACMAN+=("$pkg")
        fi
    done < "$SCRIPT_DIR/pkg-lists/pacman_native.txt"
fi

if [ ${#TO_INSTALL_PACMAN[@]} -gt 0 ]; then
    echo "  -> Instalando ${#TO_INSTALL_PACMAN[@]} pacotes nativos novos: ${TO_INSTALL_PACMAN[*]}"
    sudo pacman -S --needed --noconfirm "${TO_INSTALL_PACMAN[@]}" || {
        for pkg in "${TO_INSTALL_PACMAN[@]}"; do
            sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || echo "  ⚠️ Ignorado: $pkg"
        done
    }
else
    echo "  ✓ Todos os pacotes nativos já estão em dia."
fi

# 2.2 Pacotes AUR
TO_INSTALL_AUR=()
INSTALLED_PKGS=$(pacman -Qq 2>/dev/null || true)
if [ -f "$SCRIPT_DIR/pkg-lists/aur_packages.txt" ] && command -v yay &>/dev/null; then
    while read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# || "$pkg" =~ -debug$ ]] && continue
        if [ "$HAS_NVIDIA" = false ] && echo "$pkg" | grep -qE '^(nvidia|cuda|cudnn)'; then
            continue
        fi
        if ! echo "$INSTALLED_PKGS" | grep -qx "$pkg" && ! echo "$REPO_PKGS" | grep -qx "$pkg"; then
            TO_INSTALL_AUR+=("$pkg")
        fi
    done < "$SCRIPT_DIR/pkg-lists/aur_packages.txt"
fi

if [ ${#TO_INSTALL_AUR[@]} -gt 0 ]; then
    echo "  -> Instalando ${#TO_INSTALL_AUR[@]} pacotes AUR novos: ${TO_INSTALL_AUR[*]}"
    for pkg in "${TO_INSTALL_AUR[@]}"; do
        yay -S --needed --noconfirm --answerclean None --answerdiff None "$pkg" || echo "  ⚠️ Ignorado AUR: $pkg"
    done
else
    echo "  ✓ Todos os pacotes AUR já estão em dia."
fi

# 2.3 Flatpaks
if command -v flatpak &>/dev/null && [ -f "$SCRIPT_DIR/pkg-lists/flatpak_list.txt" ]; then
    INSTALLED_FP=$(flatpak list --app --columns=application 2>/dev/null || true)
    while read -r fp; do
        [[ -z "$fp" || "$fp" =~ ^# ]] && continue
        if ! echo "$INSTALLED_FP" | grep -qx "$fp"; then
            echo "  -> Instalando Flatpak novo: $fp"
            flatpak install -y flathub "$fp" 2>/dev/null || true
        fi
    done < "$SCRIPT_DIR/pkg-lists/flatpak_list.txt"
fi

# 3. Sincronizar configurações do Antigravity (agy) em ~/.gemini
echo ""
echo "🤖 3. Sincronizando configurações, skills e plugins do Antigravity (agy)..."
if [ -d "$SCRIPT_DIR/.gemini" ]; then
    mkdir -p "$TARGET_HOME/.gemini/antigravity-cli"
    [ -f "$SCRIPT_DIR/.gemini/GEMINI.md" ] && cp -f "$SCRIPT_DIR/.gemini/GEMINI.md" "$TARGET_HOME/.gemini/"
    [ -f "$SCRIPT_DIR/.gemini/antigravity-cli/settings.json" ] && cp -f "$SCRIPT_DIR/.gemini/antigravity-cli/settings.json" "$TARGET_HOME/.gemini/antigravity-cli/"
    [ -d "$SCRIPT_DIR/.gemini/config" ] && cp -rf "$SCRIPT_DIR/.gemini/config" "$TARGET_HOME/.gemini/"
    echo "  ✓ Antigravity (agy) atualizado."
fi

# 4. Sincronizar ~/.config, ~/.local/bin, ~/.local/share e dotfiles
echo ""
echo "⚙️ 4. Atualizando dotfiles, scripts (~/.local/bin) e ~/.config (backup em $BACKUP_DIR)..."
for file in .zshrc .p10k.zsh .bashrc .bash_profile .profile .imwheelrc .gitconfig; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        cp -f "$SCRIPT_DIR/$file" "$TARGET_HOME/"
    fi
done

mkdir -p "$TARGET_HOME/.config"
for item in "$SCRIPT_DIR/.config"/*; do
    [ -e "$item" ] || continue
    base="$(basename "$item")"
    # Preservar monitors.xml específico de cada tela (PC vs Notebook)
    [[ "$base" == "monitors.xml" ]] && continue
    if [ -e "$TARGET_HOME/.config/$base" ]; then
        mkdir -p "$BACKUP_DIR/.config"
        cp -rf "$TARGET_HOME/.config/$base" "$BACKUP_DIR/.config/" 2>/dev/null || true
    fi
    cp -rf "$item" "$TARGET_HOME/.config/" 2>/dev/null || true
done

if [ -d "$SCRIPT_DIR/.local/bin" ]; then
    mkdir -p "$TARGET_HOME/.local/bin"
    cp -rf "$SCRIPT_DIR/.local/bin/"* "$TARGET_HOME/.local/bin/" 2>/dev/null || true
    chmod +x "$TARGET_HOME/.local/bin/"* 2>/dev/null || true
fi

if [ -d "$SCRIPT_DIR/.local/share" ]; then
    mkdir -p "$TARGET_HOME/.local/share"
    cp -rf "$SCRIPT_DIR/.local/share/"* "$TARGET_HOME/.local/share/" 2>/dev/null || true
fi

# Ajustar caminhos hardcoded em .config e .local/share/applications
find "$TARGET_HOME/.config" "$TARGET_HOME/.local/share/applications" -maxdepth 3 -type f \( -name "*.json" -o -name "*.conf" -o -name "*.ini" -o -name "*.sh" -o -name "*.desktop" \) -exec sed -i "s|/home/vinicius|$TARGET_HOME|g" {} + 2>/dev/null || true

# Atualizar caches de ícones e atalhos (.desktop) para Logisim, OpenWhip, etc.
if command -v gtk-update-icon-cache &>/dev/null && [ -d "$TARGET_HOME/.local/share/icons/hicolor" ]; then
    gtk-update-icon-cache -f -t "$TARGET_HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi
if command -v update-desktop-database &>/dev/null && [ -d "$TARGET_HOME/.local/share/applications" ]; then
    update-desktop-database "$TARGET_HOME/.local/share/applications" 2>/dev/null || true
fi

if [ -d "$SCRIPT_DIR/system-tray" ]; then
    mkdir -p "$TARGET_HOME/system-tray"
    cp -rf "$SCRIPT_DIR/system-tray/"* "$TARGET_HOME/system-tray/" 2>/dev/null || true
fi

if [ -d "$SCRIPT_DIR/openwhip-visual" ]; then
    mkdir -p "$TARGET_HOME/openwhip-visual"
    cp -rf "$SCRIPT_DIR/openwhip-visual/"* "$TARGET_HOME/openwhip-visual/" 2>/dev/null || true
    if [ ! -x "$TARGET_HOME/openwhip-visual/node_modules/electron/dist/electron" ] && command -v npm &>/dev/null; then
        echo "  -> Instalando binário Electron do OpenWhip Visual (Chicote)..."
        (
            cd "$TARGET_HOME/openwhip-visual" && \
            npm install --no-audit --no-fund && \
            node -e 'const {downloadArtifact}=require("./node_modules/@electron/get"); const {version}=require("./node_modules/electron/package.json"); downloadArtifact({version,artifactName:"electron",platform:"linux",arch:"x64"}).then(z=>{require("fs").mkdirSync("node_modules/electron/dist",{recursive:true}); require("child_process").execFileSync("unzip",["-o","-q",z,"-d","node_modules/electron/dist"]); require("fs").writeFileSync("node_modules/electron/path.txt","electron");});'
        ) || true
    fi
fi

# 5. Sincronizar extensões novas do VS Code
CODE_BIN=$(command -v code || command -v visual-studio-code || true)
if [ -n "$CODE_BIN" ] && [ -f "$SCRIPT_DIR/pkg-lists/vscode_extensions.txt" ]; then
    echo ""
    echo "💻 5. Verificando extensões novas do VS Code..."
    INSTALLED_EXT=$("$CODE_BIN" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)
    while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
        if ! echo "$INSTALLED_EXT" | grep -qx "$ext_lower"; then
            echo "  -> Instalando extensão VS Code: $ext"
            "$CODE_BIN" --install-extension "$ext" --force 2>/dev/null || true
        fi
    done < "$SCRIPT_DIR/pkg-lists/vscode_extensions.txt"
    echo "  ✓ Extensões do VS Code equiparadas."
fi

# 6. Compilar schemas GNOME, restaurar Grade de Apps (dconf) e iniciar Chicote
echo ""
echo "🔧 6. Atualizando schemas de extensões, Grade de Apps do GNOME e OpenWhip..."
for schema_dir in "$TARGET_HOME"/.local/share/gnome-shell/extensions/*/schemas; do
    [ -d "$schema_dir" ] && glib-compile-schemas "$schema_dir" 2>/dev/null || true
done

if command -v dconf &>/dev/null; then
    if [ -f "$SCRIPT_DIR/gnome-settings/gnome-extensions.dconf" ]; then
        sed "s|/home/vinicius|$TARGET_HOME|g" "$SCRIPT_DIR/gnome-settings/gnome-extensions.dconf" | dconf load /org/gnome/shell/extensions/ 2>/dev/null || true
    fi
    if [ -f "$SCRIPT_DIR/gnome-settings/app-folders.dconf" ]; then
        dconf load /org/gnome/desktop/app-folders/ < "$SCRIPT_DIR/gnome-settings/app-folders.dconf" 2>/dev/null || true
    fi
    if [ -f "$SCRIPT_DIR/gnome-settings/app-picker-layout.gv" ]; then
        dconf write /org/gnome/shell/app-picker-layout "$(cat "$SCRIPT_DIR/gnome-settings/app-picker-layout.gv")" 2>/dev/null || true
    fi
    echo "  ✓ Grade de aplicativos e pastas do GNOME sincronizadas."
fi

if [ -f "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt" ] && command -v gnome-extensions &>/dev/null; then
    while read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        gnome-extensions enable "$ext" 2>/dev/null || true
    done < "$SCRIPT_DIR/pkg-lists/gnome_extensions_enabled.txt"
    echo "  ✓ Extensões do GNOME (incluindo AppIndicator) ativadas."
fi

mkdir -p "$TARGET_HOME/GoogleDrive" "$TARGET_HOME/DriveUnimar"
rm -f "$TARGET_HOME/GoogleDrive/.trackerignore" "$TARGET_HOME/GoogleDrive/.nomedia" "$TARGET_HOME/DriveUnimar/.trackerignore" "$TARGET_HOME/DriveUnimar/.nomedia" 2>/dev/null || true
rm -f "$TARGET_HOME/.config/systemd/user/default.target.wants/rclone-googledrive.service" "$TARGET_HOME/.config/systemd/user/default.target.wants/rclone-driveunimar.service" 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true
if rclone listremotes 2>/dev/null | grep -q "^GoogleDrive:"; then
    systemctl --user enable --now rclone-googledrive.service 2>/dev/null || true
fi
if ! pgrep -f "$TARGET_HOME/openwhip-visual" >/dev/null 2>&1; then
    if [ -x "$TARGET_HOME/openwhip-visual/node_modules/electron/dist/electron" ]; then
        nohup "$TARGET_HOME/openwhip-visual/node_modules/electron/dist/electron" "$TARGET_HOME/openwhip-visual" >/dev/null 2>&1 &
        echo "  ✓ OpenWhip (Chicote) iniciado em segundo plano."
    elif command -v electron >/dev/null 2>&1 && [ -d "$TARGET_HOME/openwhip-visual" ]; then
        nohup electron "$TARGET_HOME/openwhip-visual" >/dev/null 2>&1 &
        echo "  ✓ OpenWhip (Chicote) iniciado via electron do sistema."
    fi
fi

echo ""
echo "================================================================="
echo " ✅ Máquina equiparada com sucesso!"
echo " 💡 Agora você também pode rodar ./backup_rice.sh aqui sem perder"
echo "    nenhum pacote da outra máquina (modo merge ativado)."
echo "================================================================="
