# Diretrizes para Scripts Shell

Este documento define as diretrizes e boas práticas para desenvolvimento de scripts shell neste projeto. Estas diretrizes visam garantir segurança, acessibilidade e legibilidade do código.

## Segurança

### 1. Prevenção de Injeção de Comandos
- Sempre utilize aspas duplas ao redor de variáveis para evitar expansão inadequada
- Evite o uso de `eval` a menos que seja absolutamente necessário
- Valide e sanitize entradas do usuário antes de usá-las em comandos

```bash
# Ruim
command $input

# Bom
command "$input"
```

### 2. Verificação de Permissões
- Sempre verifique se o script está sendo executado com as permissões necessárias
- Use `sudo` apenas quando estritamente necessário e informe o usuário antes de solicitar credenciais

### 3. Tratamento de Erros
- Use `set -e` para interromper o script em caso de erro
- Implemente tratamento de erros específico para operações críticas
- Valide a existência de arquivos e diretórios antes de operar neles

### 4. Manipulação de Dados Sensíveis
- Evite armazenar senhas ou chaves diretamente no código
- Use variáveis de ambiente ou arquivos de configuração protegidos para dados sensíveis

## Acessibilidade

### 1. Cores e Contraste
- Use uma paleta de cores com contraste adequado para facilitar a leitura
- Forneça fallbacks para sistemas que não suportam cores
- Considere usuários com daltonismo ao escolher esquemas de cores

### 2. Mensagens Claras
- Use linguagem clara e objetiva nas mensagens de saída
- Forneça descrições úteis para erros e instruções de uso
- Evite jargões técnicos desnecessários

### 3. Internacionalização
- Considere a possibilidade de tradução das mensagens
- Use espaços reservados para valores dinâmicos em vez de concatenar strings

## Legibilidade do Código

### 1. Estrutura e Organização
- Divida o script em funções lógicas e bem definidas
- Use comentários para explicar decisões complexas ou não óbvias
- Mantenha funções curtas e com propósito único

### 2. Convenções de Nomenclatura
- Use nomes descritivos para variáveis e funções
- Prefira nomes em inglês para consistência internacional
- Use snake_case para nomes de variáveis e funções

### 3. Comentários
- Explique o "porquê" de decisões complexas, não o "o quê"
- Documente a finalidade de funções e scripts
- Atualize comentários quando alterar o código

### 4. Manipulação de Argumentos
- Use `getopts` ou construções similares para processar argumentos de forma robusta
- Forneça mensagens de ajuda claras com exemplos de uso

## Práticas Recomendadas

### 1. Portabilidade
- Verifique a disponibilidade de comandos antes de usá-los com `command -v`
- Considere diferentes shells e sistemas operacionais
- Evite extensões específicas de shell quando possível

### 2. Depuração
- Forneça opções de depuração para facilitar troubleshooting
- Use `set -x` para rastrear execução quando necessário
- Implemente logging adequado para operações complexas

### 3. Configuração
- Armazene configurações em locais apropriados (ex: `~/.config/nome_do_script/`)
- Use variáveis de ambiente para sobrescrever configurações padrão
- Permita que usuários personalizem comportamentos

### 4. Tratamento de Sinal
- Implemente manipuladores de sinal para encerramento limpo
- Limpe recursos temporários antes de sair

## Exemplo de Estrutura de Script

```bash
#!/usr/bin/env bash

# Descrição do script
# Autor: Nome do autor
# Data: Data de criação

set -e  # Sai em caso de erro

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

# --- Configurações ---
DEFAULT_VALUE="valor_padrao"
CONFIG_DIR="$HOME/.config/nome_do_script"

# --- Funções ---

# Função para fazer alguma coisa
do_something() {
    local param="$1"
    
    # Validação de entrada
    if [ -z "$param" ]; then
        echo "${RED}Erro: Parâmetro obrigatório não fornecido.${NC}" >&2
        return 1
    fi
    
    # Lógica da função
    echo "${GREEN}Operação concluída com sucesso!${NC}"
}

# Função para mostrar ajuda
show_help() {
    echo "${BLUE}Descrição do script${NC}"
    echo
    echo "${BOLD}Uso:${NC}"
    echo "  $0 ${YELLOW}[opções]${NC}"
    # Mais informações de uso...
}

# --- Ponto de Entrada ---
main() {
    # Processamento de argumentos
    case "$1" in
        help|--help|-h)
            show_help
            exit 0
            ;;
        "")
            show_help
            exit 1
            ;;
        *)
            do_something "$1"
            ;;
    esac
}

main "$@"
```

## Revisão e Manutenção

- Revise regularmente os scripts para garantir conformidade com estas diretrizes
- Atualize documentação conforme novas funcionalidades são adicionadas
- Realize testes em diferentes ambientes para garantir compatibilidade