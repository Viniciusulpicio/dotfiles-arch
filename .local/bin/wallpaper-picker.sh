#!/bin/bash

# --- DETECÇÃO DINÂMICA DO MONITOR ATUAL ---
if [ -x "$HOME/.local/bin/monitor-info.sh" ]; then
    eval "$("$HOME/.local/bin/monitor-info.sh")"
fi
TARGET_RES="${PHYS_RES:-1920x1080}"
LOG_W="${LOG_W:-1920}"
LOG_H="${LOG_H:-1080}"

# --- CAMINHOS ---
WALLPAPERS="$HOME/Pictures/Wallpaper"
CACHE_DIR="$HOME/.cache/wallpaper-picker"
GENERATED_WALL="$HOME/.cache/current_wallpaper_fixed.png"

# Tamanho proporcional do menu Wofi e das miniaturas conforme o monitor atual
WOFI_W=$(( LOG_W * 60 / 100 ))
[ "$WOFI_W" -lt 680 ] && WOFI_W=680
[ "$WOFI_W" -gt 1400 ] && WOFI_W=1400

WOFI_H=$(( LOG_H * 65 / 100 ))
[ "$WOFI_H" -lt 420 ] && WOFI_H=420
[ "$WOFI_H" -gt 950 ] && WOFI_H=950

THUMB_WIDTH=$(( (WOFI_W - 140) / 3 ))
[ "$THUMB_WIDTH" -lt 160 ] && THUMB_WIDTH=160
THUMB_HEIGHT=$(( THUMB_WIDTH * 9 / 16 ))

WAL_BIN="$(command -v wal || echo /usr/local/bin/wal)"
HOOKS="$HOME/.config/wal/hooks/hooks.sh"

mkdir -p "$CACHE_DIR"

# --- FUNÇÕES ---
generate_thumbnail(){
    local input="$1"
    local output="$2"
    local input_path="$input"
    if [[ "$input" =~ \.(gif|GIF|webp|WEBP)$ ]]; then input_path="${input}[0]"; fi
    
    magick "$input_path" -thumbnail "${THUMB_WIDTH}x${THUMB_HEIGHT}^" \
        -gravity center -extent "${THUMB_WIDTH}x${THUMB_HEIGHT}" "$output"
}

generate_menu(){
    while IFS= read -r img; do
        [[ -f "$img" ]] || continue
        filename=$(basename "$img")
        thumb="$CACHE_DIR/${THUMB_WIDTH}x${THUMB_HEIGHT}_$filename"
        if [[ ! -f "$thumb" ]] || [[ "$img" -nt "$thumb" ]]; then
            generate_thumbnail "$img" "$thumb"
        fi
        echo -en "img:$thumb\x00$filename\n"
    done < <(find "$WALLPAPERS" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort -V)
}

# --- MENU ---
CHOICE=$(generate_menu | wofi --show dmenu \
    --cache-file /dev/null \
    --define "image-size=${THUMB_WIDTH}x${THUMB_HEIGHT}" \
    --columns 3 \
    --allow-images \
    --insensitive \
    --prompt "Wallpaper ($TARGET_RES)" \
    --location 0 --width "$WOFI_W" --height "$WOFI_H" \
    --conf ~/.config/wofi/wallpaper)

[ -z "$CHOICE" ] && exit 0

# --- LIMPEZA DE NOME ---
CLEAN_NAME=$(basename "$CHOICE")
CLEAN_NAME=${CLEAN_NAME#img:}
CLEAN_NAME=${CLEAN_NAME#${THUMB_WIDTH}x${THUMB_HEIGHT}_}
SELECTED="$WALLPAPERS/$CLEAN_NAME"

if [ ! -f "$SELECTED" ]; then
    notify-send "Erro" "Arquivo não encontrado: $SELECTED"
    exit 1
fi

notify-send "Ajustando..." "Maximizando imagem para o monitor atual ($TARGET_RES)"

magick "$SELECTED" \
    \( -clone 0 -filter Lanczos -resize "$TARGET_RES^" -gravity center -extent "$TARGET_RES" -blur 0x25 -brightness-contrast -30x0 \) \
    \( -clone 0 -filter Lanczos -resize "$TARGET_RES" \) \
    -delete 0 \
    -gravity center -compose over -composite \
    -quality 100 \
    "$GENERATED_WALL"

FINAL_WALLPAPER="$GENERATED_WALL"

# --- APLICAÇÃO ---
[ -x "$WAL_BIN" ] && "$WAL_BIN" -i "$FINAL_WALLPAPER" -n

URI_FILE=$(python3 -c "import urllib.parse, sys; print('file://' + urllib.parse.quote(sys.argv[1]))" "$FINAL_WALLPAPER")

gsettings set org.gnome.desktop.background picture-uri-dark "$URI_FILE"
gsettings set org.gnome.desktop.background picture-uri "$URI_FILE"
gsettings set org.gnome.desktop.screensaver picture-uri "$URI_FILE"

gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.screensaver picture-options 'zoom'

touch "$HOME/.config/fastfetch/.reload_flag"
if [ -f "$HOOKS" ]; then "$HOOKS"; fi

notify-send "Sucesso!" "Wallpaper ajustado em $TARGET_RES."
