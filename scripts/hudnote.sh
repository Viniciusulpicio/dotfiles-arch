#!/bin/bash

# --- CONFIGURAÇÕES ---
ARQUIVO="$HOME/.notas_rapidas.txt"
[ ! -f "$ARQUIVO" ] && touch "$ARQUIVO"

FONTE="Sans 13"
ACCENT_COLOR="#007ACC" # Azul amigável (estilo VS Code)

# --- ESTILO "MODERN FOCUS" ---
CSS_DATA="
window { 
    background-color: #1E1E1E; 
    border: 1px solid #333; /* Borda sutil para definir o limite da janela */
    border-radius: 8px; 
}

textview {
    background-color: #1E1E1E;
}

textview text { 
    color: #D4D4D4; 
    background-color: #1E1E1E; 
    padding: 35px; 
    font-family: '$FONTE';
    line-height: 1.6;
    
    /* A BARRINHA DE DIGITAÇÃO */
    caret-color: $ACCENT_COLOR; 
}

/* Cor de seleção (quando você marca o texto) */
selection {
    background-color: #264F78;
    color: white;
}

/* Scrollbar fina e moderna */
scrollbar trough { background-color: transparent; }
scrollbar slider {
    background-color: #3F3F46;
    border-radius: 20px;
    min-width: 6px;
}

/* Esconder botões mas manter o espaço interno */
actionbar, box { 
    background-color: transparent; 
    border: none; 
}

button { 
    background: transparent; 
    border: none; 
    color: transparent;
    outline: none;
}
"

# --- EXECUÇÃO ---
NOVO_TEXTO=$(yad \
    --title="ZenNote" \
    --text-info \
    --editable \
    --wrap \
    --filename="$ARQUIVO" \
    --geometry=650x450 \
    --center \
    --undecorated \
    --skip-taskbar \
    --css=<(echo "$CSS_DATA") \
    --button="Salvar:0") 
    # O botão 'Salvar' está invisível, mas apertar Enter ou clicar no canto inferior salva.

# --- SALVAMENTO ---
if [ $? -eq 0 ]; then
    echo "$NOVO_TEXTO" > "$ARQUIVO"
fi
