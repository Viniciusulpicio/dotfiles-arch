#!/usr/bin/env bash
# ==============================================================================
# clean-old-extensions.sh: Limpeza periódica de versões antigas e duplicadas
# de extensões do GNOME Shell.
# ==============================================================================
set -euo pipefail

LOCAL_EXT="$HOME/.local/share/gnome-shell/extensions"
SYSTEM_EXT="/usr/share/gnome-shell/extensions"

echo "🧹 Iniciando varredura de extensões do GNOME Shell..."

if [ ! -d "$LOCAL_EXT" ]; then
    echo "ℹ️ Diretório $LOCAL_EXT não encontrado. Nada a limpar."
    exit 0
fi

# 1. Remover links simbólicos quebrados
echo "  -> Verificando symlinks quebrados em $LOCAL_EXT..."
find -L "$LOCAL_EXT" -maxdepth 1 -type l -exec rm -v {} + 2>/dev/null || true

# 2. Remover pastas temporárias e backups residuais (*.bak, *.old, *.tmp)
echo "  -> Removendo resíduos de versões antigas (*.bak, *.old, *.tmp)..."
find "$LOCAL_EXT" -maxdepth 1 -type d \( -name "*.bak" -o -name "*.old" -o -name "*.tmp" -o -name "*_backup*" \) -exec rm -rfv {} + 2>/dev/null || true

# 3. Remover pastas vazias residuais
find "$LOCAL_EXT" -maxdepth 1 -type d -empty -exec rmdir -v {} + 2>/dev/null || true

# 4. Verificar duplicatas entre /usr/share e ~/.local/share
if [ -d "$SYSTEM_EXT" ]; then
    echo "  -> Verificando duplicatas entre extensões de sistema e locais..."
    for sys_ext in "$SYSTEM_EXT"/*; do
        [ -d "$sys_ext" ] || continue
        uuid="$(basename "$sys_ext")"
        user_ext="$LOCAL_EXT/$uuid"
        if [ -d "$user_ext" ]; then
            # Se a extensão do usuário é idêntica à do sistema, remove a duplicata local
            if diff -rq "$sys_ext" "$user_ext" >/dev/null 2>&1; then
                echo "    🗑️ Removendo duplicata idêntica em ~/.local: $uuid"
                rm -rf "$user_ext"
            else
                echo "    ⚠️ Extensão customizada pelo usuário mantida em ~/.local: $uuid"
            fi
        fi
    done
fi

# 5. Recompilar schemas válidos
echo "  -> Recompilando gschemas das extensões ativas..."
for s in "$LOCAL_EXT"/*/schemas; do
    if [ -d "$s" ]; then
        glib-compile-schemas "$s" 2>/dev/null || true
    fi
done

echo "✅ Limpeza de extensões concluída com sucesso! [$(date +'%Y-%m-%d %H:%M:%S')]"
