# Fish shell completions for set-net.sh
# Suporta: set-net.sh, set-net, ou caminho completo

function __fish_set_net_commands
    # Retorna todos os comandos possíveis para set-net
    echo "set-net.sh"
    echo "set-net"
    # Adiciona caminho completo se existir
    for dir in $PATH
        if test -x "$dir/set-net.sh"
            echo "$dir/set-net.sh"
            break
        end
    end
end

function __fish_set_net_profiles
    # Lista perfis salvos para autocompletion
    local config_dir="$HOME/.config/set-net"
    local profile_file="$config_dir/profiles.conf"
    if test -f "$profile_file"
        awk -F: '{print $1}' "$profile_file" 2>/dev/null
    end
end

function __fish_set_net_interfaces
    # Lista interfaces de rede disponíveis
    ls /sys/class/net/ 2>/dev/null
end

# Configura completions para todas as variações do comando
for cmd in (__fish_set_net_commands)
    # Completions para o comando principal
    complete -c $cmd -f

    # Subcomandos principais
    complete -c $cmd -n "__fish_use_subcommand" -a "set" -d "Aplica configuração de rede"
    complete -c $cmd -n "__fish_use_subcommand" -a "save" -d "Salva um novo perfil"
    complete -c $cmd -n "__fish_use_subcommand" -a "list" -d "Lista perfis salvos"
    complete -c $cmd -n "__fish_use_subcommand" -a "delete" -d "Apaga um perfil"
    complete -c $cmd -n "__fish_use_subcommand" -a "help" -d "Mostra ajuda"

    # Completion para 'set' com perfis salvos
    complete -c $cmd -n "__fish_seen_subcommand_from set" -a "(__fish_set_net_profiles)" -d "Perfil salvo"

    # Completion para argumentos de set e save
    complete -c $cmd -n "__fish_seen_subcommand_from set save" -s i -d "Interface de rede"
    complete -c $cmd -n "__fish_seen_subcommand_from set save; and __fish_seen_argument -s i" -a "(__fish_set_net_interfaces)" -d "Interface disponível"

    # Completion para 'delete' com perfis
    complete -c $cmd -n "__fish_seen_subcommand_from delete" -a "(__fish_set_net_profiles)" -d "Perfil para deletar"

    # Máscaras comuns como sugestões
    complete -c $cmd -a "255.255.255.0" -d "Máscara /24"
    complete -c $cmd -a "255.255.0.0" -d "Máscara /16"
    complete -c $cmd -a "255.0.0.0" -d "Máscara /8"
    complete -c $cmd -a "255.255.255.128" -d "Máscara /25"
    complete -c $cmd -a "255.255.255.192" -d "Máscara /26"
    complete -c $cmd -a "255.255.255.224" -d "Máscara /27"
    complete -c $cmd -a "255.255.255.240" -d "Máscara /28"
    complete -c $cmd -a "24" -d "CIDR /24"
    complete -c $cmd -a "16" -d "CIDR /16"
    complete -c $cmd -a "8" -d "CIDR /8"
end
