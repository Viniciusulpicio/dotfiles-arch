#!/bin/bash
# SCRIPT DE BOOTSTRAP DO YADM (vFinal)
# Este script roda automaticamente quando você clona o repo em um novo PC.

echo "🚀 Iniciando a Restauração Automatizada (YADM)..."
echo "--------------------------------------------------------"

# --- 1. PREPARAÇÃO E AUR HELPER ---
echo "1. Verificando pré-requisitos..."

# Garante pacotes básicos
sudo pacman -S --noconfirm base-devel git stow

# Instala yay se não existir
if ! command -v yay &> /dev/null; then
    echo "Instalando yay..."
    cd /tmp || exit
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~ && rm -rf /tmp/yay
fi

# --- 2. LIMPEZA DE CONFLITOS (Para evitar erros na Home) ---
echo "2. Limpando arquivos padrão para evitar conflitos..."
rm -f ~/.bashrc ~/.bash_profile ~/.bash_logout 
rm -rf ~/.config/gtk-3.0 ~/.config/gtk-4.0

# --- 3. INSTALAR PACOTES ---
echo "3. Instalando pacotes do sistema e AUR..."
# Nota: Assumindo que você já adicionou os arquivos txt ao YADM na raiz da Home
if [ -f ~/pacman_list.txt ]; then
    sudo pacman -S --needed --noconfirm - < ~/pacman_list.txt
fi

if [ -f ~/aur_list.txt ]; then
    yay -S --needed --noconfirm - < ~/aur_list.txt
fi

# --- 4. RESTAURAR GNOME (DCONF) ---
echo "4. Restaurando configurações do GNOME..."

# Carrega configurações se os arquivos existirem
[ -f ~/dconf_shell.dconf ] && dconf load /org/gnome/shell/ < ~/dconf_shell.dconf
[ -f ~/dconf_desktop.dconf ] && dconf load /org/gnome/desktop/ < ~/dconf_desktop.dconf
[ -f ~/dconf_settings.dconf ] && dconf load /org/gnome/settings-daemon/ < ~/dconf_settings.dconf
[ -f ~/dconf_keybindings.dconf ] && dconf load /org/gnome/desktop/wm/keybindings/ < ~/dconf_keybindings.dconf
[ -f ~/dconf_custom_keys.dconf ] && dconf load /org/gnome/settings-daemon/plugins/media-keys/ < ~/dconf_custom_keys.dconf

# Instala extensões
if command -v extension-manager &> /dev/null && [ -f ~/gnome-extensions.json ]; then
    echo "Instalando extensões..."
    extension-manager install --json=~/gnome-extensions.json
fi

# --- 5. FINALIZAÇÃO ---
echo "5. Configurando Shell..."
chsh -s $(which zsh)

echo "--------------------------------------------------------"
echo "✅ Restauração concluída! REINICIE O SISTEMA AGORA."
