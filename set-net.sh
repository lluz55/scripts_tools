#!/usr/bin/env bash

# Script para configurar interface de rede estática e gerenciar perfis.
# Versão 3.0 com gerenciamento de perfis.

set -e

# --- Paleta de Cores (com fallback) ---
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

# --- Configurações de Arquivos ---
# Determina o diretório home correto, mesmo quando o script é executado com sudo.
# Se SUDO_USER estiver definido, significa que 'sudo' foi usado.
if [ -n "$SUDO_USER" ]; then
    # Obtém o diretório home do usuário que invocou o sudo
    EFFECTIVE_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    # Se não houver sudo, usa a variável HOME padrão
    EFFECTIVE_HOME=$HOME
fi

CONFIG_DIR="$EFFECTIVE_HOME/.config/set-net"
PROFILE_FILE="$CONFIG_DIR/profiles.conf"
DEFAULT_INTERFACE="enp2s0"

# --- Funções Auxiliares ---

# Mostra o menu de ajuda principal
show_help() {
    echo "${BLUE}Gerenciador de Perfis de Rede (v3.0)${NC}"
    echo
    echo "${BOLD}Uso:${NC}"
    echo "  $0 ${YELLOW}<comando>${NC} [argumentos...]"
    echo
    echo "${BOLD}Comandos:${NC}"
    echo "  ${YELLOW}set${NC} <perfil>              Aplica uma configuração de um perfil salvo."
    echo "  ${YELLOW}set${NC} <ip> <cidr> <gw> [-i <if>]  Aplica uma configuração manual."
    echo
    echo "  ${YELLOW}save${NC} <perfil> <ip> <cidr> <gw> [-i <if>]  Salva a configuração como um novo perfil."
    echo "  ${YELLOW}list${NC}                           Lista todos os perfis salvos."
    echo "  ${YELLOW}delete${NC} <perfil>              Apaga um perfil salvo."
    echo
    echo "  ${YELLOW}help${NC}                           Mostra este menu de ajuda."
    echo
    echo "${BOLD}Exemplos:${NC}"
    echo "  $0 save ${GREEN}casa${NC} 192.168.1.50 24 192.168.1.1"
    echo "  sudo $0 set ${GREEN}casa${NC}"
    echo "  sudo $0 set 10.0.0.99 8 10.0.0.1 -i eth1"
    echo "  $0 list"
}

# Garante que o diretório de configuração exista
ensure_config_dir() {
    mkdir -p "$CONFIG_DIR"
}

# --- Funções de Gerenciamento de Perfis ---

# Salva um novo perfil no arquivo de configuração
func_save() {
    local name="$1"
    local ip="$2"
    local cidr="$3"
    local gw="$4"
    local iface="$DEFAULT_INTERFACE"

    # Argument parsing para a interface opcional
    if [[ "$5" == "-i" && -n "$6" ]]; then
        iface="$6"
    fi

    if [ -z "$name" ] || [ -z "$ip" ] || [ -z "$cidr" ] || [ -z "$gw" ]; then
        echo "${RED}Erro: Argumentos insuficientes para 'save'.${NC}"
        echo "Uso: $0 save <nome> <ip> <cidr> <gateway> [-i <interface>]"
        return 1
    fi

    # --- Validação do Nome do Perfil ---
    if [[ "$name" =~ [:\ ] ]]; then
        echo "${RED}Erro: O nome do perfil não pode conter ':' ou espaços.${NC}"
        return 1
    fi

    # --- Validação do CIDR ---
    if ! [[ "$cidr" =~ ^[0-9]+$ ]] || [ "$cidr" -lt 0 ] || [ "$cidr" -gt 32 ]; then
        echo "${RED}Erro: CIDR inválido '${cidr}'. Deve ser um número entre 0 e 32.${NC}"
        return 1
    fi

    # --- Validação do Formato do IP ---
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if ! [[ "$ip" =~ $ip_regex ]]; then
        echo "${RED}Erro: Formato de IP inválido '${ip}'. Exemplo correto: 192.168.0.2${NC}"
        return 1
    fi

    # Valida cada octeto do IP
    local IFS='.'
    read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
            echo "${RED}Erro: Octeto inválido no IP '${ip}'. Cada valor deve estar entre 0 e 255.${NC}"
            return 1
        fi
    done

    # --- Validação do Formato do Gateway ---
    if ! [[ "$gw" =~ $ip_regex ]]; then
        echo "${RED}Erro: Formato de gateway inválido '${gw}'. Exemplo correto: 192.168.0.1${NC}"
        return 1
    fi

    # Valida cada octeto do gateway
    read -ra gw_octets <<< "$gw"
    for octet in "${gw_octets[@]}"; do
        if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
            echo "${RED}Erro: Octeto inválido no gateway '${gw}'. Cada valor deve estar entre 0 e 255.${NC}"
            return 1
        fi
    done

    # --- Validação da Interface (se especificada manualmente) ---
    if [[ "$5" == "-i" && -n "$6" ]]; then
        if [ ! -d "/sys/class/net/$iface" ]; then
            echo "${RED}Erro: Interface de rede '${iface}' não encontrada no sistema.${NC}"
            echo "Interfaces disponíveis:"
            ls /sys/class/net/ | sed 's/^/  - /'
            return 1
        fi
    fi

    # Verifica se o perfil já existe
    if grep -q "^${name}:" "$PROFILE_FILE" 2>/dev/null; then
        echo "${RED}Erro: O perfil '${name}' já existe.${NC}"
        echo "Use '${YELLOW}delete${NC}' primeiro se desejar substituí-lo."
        return 1
    fi

    # Salva o perfil após todas as validações passarem
    echo "${name}:${ip}:${cidr}:${gw}:${iface}" >> "$PROFILE_FILE"
    echo "${GREEN}Perfil '${name}' salvo com sucesso!${NC}"
    echo "  ${BLUE}Resumo:${NC}"
    echo "    - IP/CIDR:   ${ip}/${cidr}"
    echo "    - Gateway:   ${gw}"
    echo "    - Interface: ${iface}"
}

# Lista todos os perfis salvos
func_list() {
    if [ ! -f "$PROFILE_FILE" ] || [ ! -s "$PROFILE_FILE" ]; then
        echo "${YELLOW}Nenhum perfil salvo encontrado.${NC}"
        return 0
    fi

    echo "${BLUE}${BOLD}Perfis Salvos:${NC}"
    (echo "PERFIL:IP/CIDR:GATEWAY:INTERFACE"; cat "$PROFILE_FILE") | column -t -s ':'
}

# Apaga um perfil
func_delete() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "${RED}Erro: Especifique o nome do perfil a ser apagado.${NC}"
        return 1
    fi

    if [ ! -f "$PROFILE_FILE" ] || ! grep -q "^${name}:" "$PROFILE_FILE"; then
        echo "${RED}Erro: Perfil '${name}' não encontrado.${NC}"
        return 1
    fi

    # Cria um arquivo temporário sem a linha do perfil
    local tmp_file
    tmp_file=$(mktemp)
    grep -v "^${name}:" "$PROFILE_FILE" > "$tmp_file"
    mv "$tmp_file" "$PROFILE_FILE"

    echo "${GREEN}Perfil '${name}' apagado com sucesso.${NC}"
}

# --- Funções de Rede (requerem sudo) ---

# Verifica o SO e avisa sobre a natureza da configuração
check_os_and_warn() {
    local OS_NAME="Desconhecido"
    if [ -f /etc/os-release ]; then . /etc/os-release; OS_NAME=$NAME; fi
    
    echo "${BLUE}----------------------------------------------------------${NC}"
    echo "Sistema Detectado: ${GREEN}${OS_NAME}${NC}"

    if [ "${ID:-}" = "nixos" ] || [ -f /run/ostree-booted ]; then
        echo "${YELLOW}AVISO: Seu SO é imutável. As alterações são TEMPORÁRIAS.${NC}"
    else
        echo "${GREEN}INFO: Alterações podem ser sobrescritas pelo NetworkManager.${NC}"
    fi
    echo "${BLUE}----------------------------------------------------------${NC}"
}

# Aplica a configuração de rede usando o comando 'ip'
apply_network_config() {
    local ip="$1" cidr="$2" gw="$3" iface="$4"

    # VERIFICAÇÃO: Checa se a interface de rede existe antes de continuar.
    if [ ! -d "/sys/class/net/$iface" ]; then
        echo "${RED}Erro: A interface de rede '${iface}' não foi encontrada no sistema.${NC}"
        return 1
    fi

    check_os_and_warn

    echo "${BLUE}Aplicando configuração na interface '${iface}'...${NC}"
    echo "  - ${GREEN}IP:${NC}      ${ip}/${cidr}"
    echo "  - ${GREEN}Gateway:${NC} ${gw}"

    # Flush e aguarda interface ficar pronta
    ip addr flush dev "$iface"
    sleep 0.5
    
    # Adiciona IP e verifica se foi aplicado
    ip addr add "${ip}/${cidr}" dev "$iface"
    sleep 0.5
    
    # Verifica se o IP foi configurado corretamente
    if ! ip addr show dev "$iface" | grep -q "${ip}/${cidr}"; then
        echo "${RED}Erro: Falha ao aplicar IP ${ip}/${cidr} na interface '${iface}'.${NC}"
        echo "Verifique se a interface existe e está ativa."
        return 1
    fi
    
    ip link set dev "$iface" up
    ip route del default >/dev/null 2>&1 || true
    ip route add default via "$gw" dev "$iface"

    echo
    echo "${GREEN}Configuração de rede aplicada com sucesso!${NC}"
}

# Ponto de entrada para o comando 'set'
func_set() {
    # Somente este comando precisa de root
    if [ "$EUID" -ne 0 ]; then
      echo "${YELLOW}O comando 'set' requer privilégios de root. Re-executando com sudo...${NC}"
      exec sudo -- "$0" "$@"
    fi
    
    # Remove 'set' da lista de argumentos originais
    shift

    # Se o primeiro argumento não contém '.', '/' ou ':', é provavelmente um nome de perfil
    if [[ "$1" != *.* && "$1" != */* && "$1" != *:* && -n "$1" ]]; then
        local name="$1"
        if [ ! -f "$PROFILE_FILE" ] || ! grep -q "^${name}:" "$PROFILE_FILE"; then
            echo "${RED}Erro: Perfil '${name}' não encontrado.${NC}"
            return 1
        fi
        
        # Lê o perfil e valida o formato
        local profile_line
        profile_line=$(grep "^${name}:" "$PROFILE_FILE")
        
        # Conta o número de campos (deve ser exatamente 5)
        local field_count
        field_count=$(echo "$profile_line" | awk -F':' '{print NF}')
        
        if [ "$field_count" -ne 5 ]; then
            echo "${RED}Erro: Perfil '${name}' está corrompido (formato inválido).${NC}"
            echo "  Campo(s) encontrado(s): ${field_count} (esperado: 5)"
            echo "  Formato esperado: nome:ip:cidr:gateway:interface"
            echo "${YELLOW}Use 'delete' para remover este perfil e 'save' para recriá-lo corretamente.${NC}"
            return 1
        fi
        
        # CORREÇÃO: Usa uma variável '_' para consumir o nome do perfil do início da linha
        local _ ip cidr gw iface
        IFS=':' read -r _ ip cidr gw iface < <(grep "^${name}:" "$PROFILE_FILE")
        
        # Validação adicional: verifica se campos essenciais não estão vazios
        if [ -z "$ip" ] || [ -z "$cidr" ] || [ -z "$gw" ] || [ -z "$iface" ]; then
            echo "${RED}Erro: Perfil '${name}' contém campos vazios.${NC}"
            echo "  IP: ${ip:-VAZIO}"
            echo "  CIDR: ${cidr:-VAZIO}"
            echo "  Gateway: ${gw:-VAZIO}"
            echo "  Interface: ${iface:-VAZIO}"
            return 1
        fi
        
        # Valida CIDR numérico
        if ! [[ "$cidr" =~ ^[0-9]+$ ]]; then
            echo "${RED}Erro: Perfil '${name}' contém CIDR inválido: '${cidr}'.${NC}"
            return 1
        fi
        
        apply_network_config "$ip" "$cidr" "$gw" "$iface"
    else # Caso contrário, é uma configuração manual
        local ip="$1" cidr="$2" gw="$3" iface="$DEFAULT_INTERFACE"
        if [[ "$4" == "-i" && -n "$5" ]]; then iface="$5"; fi

        if [ -z "$ip" ] || [ -z "$cidr" ] || [ -z "$gw" ]; then
             echo "${RED}Erro: Argumentos insuficientes para 'set' manual.${NC}"
             show_help
             return 1
        fi
        apply_network_config "$ip" "$cidr" "$gw" "$iface"
    fi
}


# --- Ponto de Entrada Principal ---
main() {
    ensure_config_dir

    # Se nenhum comando for dado, mostra a ajuda
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi

    case "$1" in
        set)
            # Passa todos os argumentos para func_set, que gerenciará o sudo
            func_set "$@"
            ;;
        save)
            shift
            func_save "$@"
            ;;
        list)
            func_list
            ;;
        delete)
            shift
            func_delete "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "${RED}Erro: Comando '$1' desconhecido.${NC}"
            echo
            show_help
            exit 1
            ;;
    esac
}

main "$@"
