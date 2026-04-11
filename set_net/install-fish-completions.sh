#!/usr/bin/env bash

# Script para instalar fish completions para set-net.sh

set -e

# Paleta de Cores
if command -v tput >/dev/null && tput setaf 1 >/dev/null; then
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RED=$(tput setaf 1)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    NC=$(tput sgr0)
else
    GREEN="" YELLOW="" RED="" BLUE="" BOLD="" NC=""
fi

# Determina diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPLETION_FILE="$SCRIPT_DIR/completions/set-net.fish"
SCRIPT_FILE="$SCRIPT_DIR/set-net.sh"

# Verifica se fish está instalado
if ! command -v fish >/dev/null 2>&1; then
    echo "${RED}Erro: fish shell não encontrado. Instale fish primeiro.${NC}"
    exit 1
fi

# Verifica se o arquivo de completions existe
if [ ! -f "$COMPLETION_FILE" ]; then
    echo "${RED}Erro: Arquivo de completions não encontrado em:${NC}"
    echo "  $COMPLETION_FILE"
    exit 1
fi

# Verifica se o script set-net.sh existe
if [ ! -f "$SCRIPT_FILE" ]; then
    echo "${RED}Erro: Script set-net.sh não encontrado em:${NC}"
    echo "  $SCRIPT_FILE"
    exit 1
fi

echo "${BLUE}Instalando fish completions e script set-net.sh...${NC}"
echo

# --- Instala completions ---
FISH_CONFIG_DIR="$HOME/.config/fish"
FISH_COMPLETIONS_DIR="$FISH_CONFIG_DIR/completions"
mkdir -p "$FISH_COMPLETIONS_DIR"

TARGET_FILE="$FISH_COMPLETIONS_DIR/set-net.fish"

if [ -L "$TARGET_FILE" ] || [ -f "$TARGET_FILE" ]; then
    echo "${YELLOW}Completions já instaladas. Reinstalando...${NC}"
    rm -f "$TARGET_FILE"
fi

ln -sf "$COMPLETION_FILE" "$TARGET_FILE"
echo "${GREEN}✓${NC} Completions instaladas em: ${BLUE}$TARGET_FILE${NC}"

# --- Instala script no PATH ---
USR_LOCAL_BIN="/usr/local/bin"
SCRIPT_TARGET="$USR_LOCAL_BIN/set-net.sh"

if [ ! -d "$USR_LOCAL_BIN" ]; then
    echo "${YELLOW}Aviso: /usr/local/bin não existe. Tentando criar...${NC}"
    sudo mkdir -p "$USR_LOCAL_BIN"
fi

if [ -w "$USR_LOCAL_BIN" ]; then
    if [ -L "$SCRIPT_TARGET" ] || [ -f "$SCRIPT_TARGET" ]; then
        echo "${YELLOW}Script já instalado. Reinstalando...${NC}"
        sudo rm -f "$SCRIPT_TARGET"
    fi
    
    sudo ln -sf "$SCRIPT_FILE" "$SCRIPT_TARGET"
    echo "${GREEN}✓${NC} Script instalado em: ${BLUE}$SCRIPT_TARGET${NC}"
else
    echo "${YELLOW}Aviso: Sem permissão para escrever em $USR_LOCAL_BIN${NC}"
    echo "Execute com sudo para instalar o script no PATH:"
    echo "  ${BLUE}sudo $0${NC}"
fi

echo
echo "${GREEN}${BOLD}Instalação concluída!${NC}"
echo
echo "${YELLOW}Próximos passos:${NC}"
echo "1. Recarregue o fish:"
echo "   ${BLUE}exec fish${NC}"
echo
echo "2. Ou recarregue apenas as completions:"
echo "   ${BLUE}source ~/.config/fish/config.fish${NC}"
echo
echo "${BLUE}Uso com TAB completion:${NC}"
echo "  set-net.sh <TAB>        # Lista comandos"
echo "  set-net.sh set <TAB>    # Lista perfis salvos"
echo "  set-net.sh save <TAB>   # Sugere argumentos"
echo "  set-net.sh delete <TAB> # Lista perfis para deletar"
echo "  set-net.sh set -i <TAB> # Lista interfaces de rede"
