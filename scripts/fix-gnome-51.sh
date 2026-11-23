#!/usr/bin/env bash
# ==============================================================================
# fix-gnome-51.sh: Correções essenciais para o GNOME 51 no Arch Linux
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔧 Aplicando correções do GNOME 51..."

# 1. Correção de Biometria no GDM 51 (G_RESOURCE_OVERLAYS)
# Permite autenticação instantânea por digital logo ao ligar (cold boot)
# sem necessidade de clicar em 'Voltar' e selecionar o perfil manualmente.
OVERLAY_SRC="$SCRIPT_DIR/gdm-overlay"
OVERLAY_DST="/usr/share/gnome-shell/gdm-overlay"

if [ -d "$OVERLAY_SRC" ]; then
    echo "  -> Instalando overlay GDM para suporte biométrico em $OVERLAY_DST..."
    sudo mkdir -p "$OVERLAY_DST"
    sudo cp -f "$OVERLAY_SRC/loginDialog.js" "$OVERLAY_DST/"
    sudo cp -f "$OVERLAY_SRC/authServicesLegacy.js" "$OVERLAY_DST/"
    sudo chmod 755 "$OVERLAY_DST"
    sudo chmod 644 "$OVERLAY_DST"/*

    # Configurar systemd user override para org.gnome.Shell@gdm.service
    sudo mkdir -p /etc/systemd/user/org.gnome.Shell@gdm.service.d/
    sudo tee /etc/systemd/user/org.gnome.Shell@gdm.service.d/override.conf >/dev/null << 'EOF'
[Service]
Environment="G_RESOURCE_OVERLAYS=/org/gnome/shell/gdm=/usr/share/gnome-shell/gdm-overlay"
EOF

    # Configurar systemd system override para gdm.service
    sudo mkdir -p /etc/systemd/system/gdm.service.d/
    sudo tee /etc/systemd/system/gdm.service.d/override.conf >/dev/null << 'EOF'
[Service]
Environment="G_RESOURCE_OVERLAYS=/org/gnome/shell/gdm=/usr/share/gnome-shell/gdm-overlay"
EOF

    sudo systemctl daemon-reload
    systemctl --user daemon-reload 2>/dev/null || true
    echo "  ✓ Overlay do GDM 51 configurado com sucesso!"
fi

# 2. Regra udev para evitar autosuspend do leitor de digital no boot
FPRINT_UDEV="/etc/udev/rules.d/50-fprint-power.rules"
if [ ! -f "$FPRINT_UDEV" ]; then
    echo "  -> Configurando regra udev para o leitor de digital..."
    sudo tee "$FPRINT_UDEV" >/dev/null << 'EOF'
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="06cb", ATTRS{idProduct}=="00bd", ATTR{power/control}="on"
EOF
    sudo udevadm control --reload-rules 2>/dev/null || true
    echo "  ✓ Regra udev para biometria criada."
fi

# 3. Correção de Biometria no Polkit (/etc/pam.d/polkit-1)
POLKIT_PAM="/etc/pam.d/polkit-1"
if [ -f "$POLKIT_PAM" ]; then
    if ! grep -q "pam_fprintd.so" "$POLKIT_PAM"; then
        echo "  -> Adicionando suporte a digital em $POLKIT_PAM..."
        sudo sed -i '1s/^/#%PAM-1.0\nauth       sufficient   pam_fprintd.so\n/' "$POLKIT_PAM"
        echo "  ✓ Suporte biométrico adicionado ao Polkit."
    else
        echo "  ✓ Polkit já possui suporte biométrico configurado."
    fi
fi

# 4. Correção de ciclo de inicialização do auto-power-profile
POWER_SVC="/etc/systemd/system/auto-power-profile.service"
if [ -f "$POWER_SVC" ]; then
    if grep -q "WantedBy=multi-user.target" "$POWER_SVC"; then
        echo "  -> Corrigindo dependência do $POWER_SVC para graphical.target..."
        sudo sed -i 's/WantedBy=multi-user.target/WantedBy=graphical.target/' "$POWER_SVC"
        sudo systemctl daemon-reload
        sudo systemctl reenable auto-power-profile.service 2>/dev/null || true
        echo "  ✓ Ciclo do auto-power-profile corrigido."
    fi
fi

# 5. Compilação de schemas das extensões
echo "  -> Compilando gschemas das extensões locais..."
for s in "$HOME"/.local/share/gnome-shell/extensions/*/schemas; do
    [ -d "$s" ] && glib-compile-schemas "$s" 2>/dev/null || true
done

echo "✅ Correções do GNOME 51 aplicadas com sucesso!"
