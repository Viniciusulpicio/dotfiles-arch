#!/bin/bash

# Detecção dinâmica da resolução do monitor atual
if [ -x "$HOME/.local/bin/monitor-info.sh" ]; then
    eval "$("$HOME/.local/bin/monitor-info.sh")"
fi
TARGET_RES="${PHYS_RES:-1920x1080}"

# Path
WALLPAPER=$(gsettings get org.gnome.desktop.background picture-uri-dark \
    | sed -E "s/^'file:\/\///; s/^\"file:\/\///; s/'$//; s/\"$//")
WALL_DIR="$HOME/Pictures/Wallpaper"
WALL_NAME="$(basename "$WALLPAPER")"
SOURCE_IMG="$WALLPAPER"
[ ! -f "$SOURCE_IMG" ] && SOURCE_IMG="$WALL_DIR/$WALL_NAME"

BLUR_BG="$HOME/.config/wlogout/images/wallpaper_blurred.png"
WALCSS="$HOME/.cache/wal/colors-waybar.css"
WL_TEMPLATE="$HOME/.config/wlogout/style-template.css"
WLCSS="$HOME/.config/wlogout/style.css"

mkdir -p "$(dirname "$BLUR_BG")"

# Generate Blurred Wallpaper in the current monitor's resolution
if [ -f "$SOURCE_IMG" ]; then
    magick "$SOURCE_IMG" -resize "${TARGET_RES}^" -gravity center -extent "$TARGET_RES" -blur 0x8 -fill black -colorize 65% "$BLUR_BG"
fi

# === UPDATE STYLE.CSS ===
[ -f "$WL_TEMPLATE" ] && cat "$WL_TEMPLATE" > "$WLCSS"
