#!/usr/bin/env bash
# ==============================================================================
# fix-gnome-51.sh: Correções essenciais para o GNOME 51 no Arch Linux
# ==============================================================================
set -euo pipefail

echo "🔧 Aplicando correções do GNOME 51..."

# 1. Correção de Biometria no GDM 51 (libshell-51.so)
LIBSHELL="/usr/lib/gnome-shell/libshell-51.so"
if [ -f "$LIBSHELL" ]; then
    echo "  -> Verificando patch de biometria no GDM em $LIBSHELL..."
    python3 -c "
with open('$LIBSHELL', 'rb') as f:
    data = f.read()

target = b'\n        if (!this._reauthOnly)\n            return;\n'
replacement = b' ' * len(target)

if target in data:
    import subprocess
    print('    ⚡ Aplicando patch no libshell-51.so (criando backup .bak)...')
    subprocess.run(['sudo', 'cp', '-n', '$LIBSHELL', '$LIBSHELL.bak'], check=True)
    patched = data.replace(target, replacement, 1)
    with open('/tmp/libshell-51.so.patched', 'wb') as f:
        f.write(patched)
    subprocess.run(['sudo', 'cp', '-f', '/tmp/libshell-51.so.patched', '$LIBSHELL'], check=True)
    subprocess.run(['sudo', 'chmod', '755', '$LIBSHELL'], check=True)
    subprocess.run(['rm', '-f', '/tmp/libshell-51.so.patched'])
    print('    ✓ Patch aplicado com sucesso!')
else:
    print('    ✓ libshell-51.so já está com o patch aplicado ou não necessita de alteração.')
"
fi

# 2. Correção de Biometria no Polkit (/etc/pam.d/polkit-1)
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

# 3. Correção de ciclo de inicialização do auto-power-profile
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

# 4. Compilação de schemas das extensões
echo "  -> Compilando gschemas das extensões locais..."
for s in "$HOME"/.local/share/gnome-shell/extensions/*/schemas; do
    [ -d "$s" ] && glib-compile-schemas "$s" 2>/dev/null || true
done

echo "✅ Correções do GNOME 51 aplicadas com sucesso!"
