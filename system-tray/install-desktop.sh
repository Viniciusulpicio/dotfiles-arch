#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"

mkdir -p "$APP_DIR"
mkdir -p "$ICON_DIR"

cp "$DIR/static/icon.svg" "$ICON_DIR/system-tray.svg"

cat << DESKTOP_EOF > "$APP_DIR/system-tray.desktop"
[Desktop Entry]
Name=System Tray
Comment=Gerenciador Dinâmico de Serviços Linux (XAMPP-like)
Exec=python3 $DIR/app.py
Icon=system-tray
Terminal=false
Type=Application
Categories=Development;System;Settings;
StartupNotify=true
DESKTOP_EOF

chmod +x "$APP_DIR/system-tray.desktop"
update-desktop-database "$APP_DIR" 2>/dev/null || true

echo "✅ System Tray instalado com sucesso no menu de aplicativos do sistema!"
