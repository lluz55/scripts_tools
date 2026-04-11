# Local Tools

This repository is a collection of useful scripts and tools for everyday tasks. Each script is designed to be a standalone tool that can be used to automate a specific task.

## Scripts

*   [set-net.sh](./set-net.sh): A script to configure network settings. For more details, see the [set-net.sh documentation](./README-set-net.md).

## Fish Shell Completions

Completions para o shell **fish** estão disponíveis em `completions/set-net.fish`.

### Instalação

Execute o script de instalação:

```bash
./install-fish-completions.sh
```

Ou copie manualmente para o diretório de completions do fish:

```bash
mkdir -p ~/.config/fish/completions
ln -s $(pwd)/completions/set-net.fish ~/.config/fish/completions/
```

### Uso

Após instalar, recarregue o fish ou execute:

```fish
source ~/.config/fish/config.fish
```

**Exemplos de TAB completion:**

```fish
set-net.sh <TAB>        # Lista comandos disponíveis
set-net.sh set <TAB>    # Lista perfis salvos
set-net.sh save <TAB>   # Sugere argumentos
set-net.sh delete <TAB> # Lista perfis para deletar
set-net.sh set -i <TAB> # Lista interfaces de rede disponíveis
```

---

*More scripts will be added in the future.*