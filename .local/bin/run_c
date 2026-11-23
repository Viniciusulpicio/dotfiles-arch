#!/usr/bin/env bash
set -e

file="$1"
if [ -z "$file" ]; then
    echo "Uso: run_c <arquivo.c ou arquivo.cpp>"
    exit 1
fi

ext="${file##*.}"
name="${file%.*}"
compiler="gcc"
if [[ "$ext" == "cpp" || "$ext" == "cc" || "$ext" == "cxx" ]]; then
    compiler="g++"
fi

deps=("$file")

# 1. Dependências por #include "arquivo.h"
for _ in 1 2; do
    for src in "${deps[@]}"; do
        for f in $(grep -oP '#include\s*"\K[^"]+(?=\.(h|hpp))' "$src" 2>/dev/null); do
            for h_ext in c cpp cc; do
                if [ -f "$f.$h_ext" ] && [[ ! " ${deps[*]} " =~ " $f.$h_ext " ]]; then
                    deps+=("$f.$h_ext")
                fi
            done
        done
    done
done

# 2. Outros arquivos .c / .cpp na mesma pasta sem função main()
for f in *.c *.cpp; do
    if [ -f "$f" ] && [ "$f" != "$file" ] && ! grep -Eq '\bmain[[:space:]]*\(' "$f" 2>/dev/null; then
        if [[ ! " ${deps[*]} " =~ " $f " ]]; then
            deps+=("$f")
        fi
    fi
done

# 3. Compilação
"$compiler" "${deps[@]}" -o "$name" -lm -Wno-implicit-function-declaration

# 4. Execução
"./$name"
