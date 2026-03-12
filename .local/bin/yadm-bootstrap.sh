#!/bin/bash
echo "🚀 Restaurando Rion Ricing..."

# 1. Instalar Base
if ! command -v yay &> /dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd ~
fi

# 2. Pacotes
[ -f ~/pacman_list.txt ] && sudo pacman -S --needed --noconfirm - < ~/pacman_list.txt
[ -f ~/aur_list.txt ] && yay -S --needed --noconfirm - < ~/aur_list.txt

# 3. CRÍTICO: Permissões do Rion
# O Rion falha se os scripts não forem executáveis. Isso corrige.
chmod -R +x ~/.local/bin/
[ -d ~/.rion-dotfiles ] && chmod -R +x ~/.rion-dotfiles/scripts/

# 4. Restaurar Dconf (Atalhos e Temas)
dconf load /org/gnome/shell/ < ~/dconf_shell.dconf
dconf load /org/gnome/desktop/ < ~/dconf_desktop.dconf
dconf load /org/gnome/settings-daemon/ < ~/dconf_settings.dconf
dconf load /org/gnome/desktop/wm/keybindings/ < ~/dconf_keybindings.dconf
# Restaura atalhos personalizados (ex: menu do Rion)
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < ~/dconf_custom_keybindings_full.dconf

# 5. Ativar Extensões (Que copiamos fisicamente)
gsettings set org.gnome.shell disable-user-extensions false
fc-cache -fv
chsh -s $(which zsh)

echo "✅ FIM! Reinicie o sistema."
