#!/bin/bash

# --- CONFIGURAÇÃO ---
TARGET_RES="1920x1080"  # Confirme se é a sua resolução

# --- CAMINHOS ---
WALLPAPERS="$HOME/Pictures/Wallpaper"
CACHE_DIR="$HOME/.cache/wallpaper-picker"
GENERATED_WALL="$HOME/.cache/current_wallpaper_fixed.png"
THUMB_WIDTH="250"
THUMB_HEIGHT="141"
WAL_BIN="/usr/local/bin/wal"
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
        ext="${img##*.}"
        thumb="$CACHE_DIR/$filename"
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
    --prompt "Wallpaper" \
    --location 0 --width 950 --height 600 \
    --conf ~/.config/wofi/wallpaper)

[ -z "$CHOICE" ] && exit 0

# --- LIMPEZA DE NOME ---
CLEAN_NAME=$(basename "$CHOICE")
CLEAN_NAME=${CLEAN_NAME#img:}
SELECTED="$WALLPAPERS/$CLEAN_NAME"

if [ ! -f "$SELECTED" ]; then
    notify-send "Erro" "Arquivo não encontrado: $SELECTED"
    exit 1
fi

notify-send "Ajustando..." "Maximizando imagem em $TARGET_RES"

# --- A MÁGICA (AQUI ESTÁ A MUDANÇA) ---
# Removi o caractere '>' que impedia imagens pequenas de crescerem.
# Agora ele vai forçar o crescimento até encostar na borda.

magick "$SELECTED" \
    \( -clone 0 -filter Lanczos -resize "$TARGET_RES^" -gravity center -extent "$TARGET_RES" -blur 0x25 -brightness-contrast -30x0 \) \
    \( -clone 0 -filter Lanczos -resize "$TARGET_RES" \) \
    -delete 0 \
    -gravity center -compose over -composite \
    -quality 100 \
    "$GENERATED_WALL"

# DICA: Se ainda achar que tem muita borda, troque a linha do meio acima por:
# \( -clone 0 -filter Lanczos -resize "$TARGET_RES^" -gravity center -crop "$TARGET_RES" +repage \) \
# (Isso vai forçar preencher TUDO, cortando o que sobrar, igual zoom normal)

FINAL_WALLPAPER="$GENERATED_WALL"

# --- APLICAÇÃO ---
"$WAL_BIN" -i "$FINAL_WALLPAPER" -n

URI_FILE=$(python3 -c "import urllib.parse, sys; print('file://' + urllib.parse.quote(sys.argv[1]))" "$FINAL_WALLPAPER")

gsettings set org.gnome.desktop.background picture-uri-dark "$URI_FILE"
gsettings set org.gnome.desktop.background picture-uri "$URI_FILE"
gsettings set org.gnome.desktop.screensaver picture-uri "$URI_FILE"

gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.screensaver picture-options 'zoom'

touch "$HOME/.config/fastfetch/.reload_flag"
if [ -f "$HOOKS" ]; then $HOOKS; fi

notify-send "Sucesso!" "Wallpaper ajustado."