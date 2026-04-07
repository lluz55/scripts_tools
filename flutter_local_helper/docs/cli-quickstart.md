# Guia rapido da CLI

Este projeto fornece uma CLI em shell script para localizar strings em arquivos `.dart` com chance alta de serem textos visiveis ao usuario.

## Requisitos

- `bash`
- `find`
- `sort`
- `perl`
- Um projeto Flutter ou Dart com arquivos em `lib/`

O script usa `#!/usr/bin/env bash`, entao pode ser executado diretamente tambem no NixOS quando `bash` estiver no `PATH`.

## Execucao basica

Na raiz deste projeto:

```bash
./bin/flutter_local_helper
```

Para analisar outro projeto Flutter:

```bash
./bin/flutter_local_helper --root /caminho/do/app
```

## Resultado

O comando gera JSON em `stdout`, com uma lista de ocorrencias. Exemplo:

```json
[
  {
    "file": "lib/home_page.dart",
    "line": 12,
    "column": 14,
    "text": "Welcome back"
  },
  {
    "file": "lib/settings_page.dart",
    "line": 28,
    "column": 20,
    "text": "Save changes"
  }
]
```

Cada item da lista traz:

- `file`: caminho relativo do arquivo
- `line`: linha inicial do literal
- `column`: coluna inicial do literal
- `text`: conteudo textual detectado

## Salvar em arquivo

```bash
./bin/flutter_local_helper --root /caminho/do/app --output strings.json
```

## Trocar a pasta analisada

Por padrao a CLI analisa `lib/`. Para analisar outro caminho relativo a `--root`:

```bash
./bin/flutter_local_helper --root /caminho/do/app --scan test
```

## O que a ferramenta tenta encontrar

- textos em widgets e propriedades tipicas de UI
- frases com espacos, pontuacao ou formato de mensagem
- strings que parecem conteudo visivel ao usuario
- strings interpoladas e literais adjacentes quando formam uma mensagem unica

## O que a ferramenta tenta ignorar

- URLs
- caminhos de assets e arquivos
- nomes tecnicos, rotas e chaves internas
- imports e diretivas de Dart
- strings que sao apenas interpolacao, sem texto literal relevante ao redor

## Corner cases cobertos

- raw strings com prefixo `r`
- strings com aspas triplas
- interpolacao com `$nome` e `${expressao}`
- strings aninhadas dentro de interpolacoes
- concatenacao por literais adjacentes
