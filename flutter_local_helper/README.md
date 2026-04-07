# flutter_local_helper

CLI em shell script para localizar strings em arquivos `.dart` com alta chance de serem textos visiveis de UI.

## Requisitos

- `bash`
- `find`
- `sort`
- `perl`

O executavel usa `#!/usr/bin/env bash`, entao funciona no NixOS e em outros ambientes desde que `bash` esteja no `PATH`.

## Uso

```bash
./bin/flutter_local_helper
```

Por padrao a ferramenta:

- analisa `lib/`
- procura apenas arquivos `.dart`
- gera em `stdout` um JSON cuja raiz e uma lista de ocorrencias
- considera raw strings, triple quotes, interpolacao e literais adjacentes
- reduz falso positivo ignorando strings que sao apenas interpolacao, como `$variavel` ou `${obj.metodo()}`

Exemplos:

```bash
./bin/flutter_local_helper --root /caminho/do/projeto
./bin/flutter_local_helper --scan test
./bin/flutter_local_helper --output strings.json
```

Exemplo de saida:

```json
[
  {
    "file": "lib/home_page.dart",
    "line": 12,
    "column": 14,
    "text": "Welcome back"
  }
]
```

## Quando usar

Use a CLI quando voce quiser:

- levantar rapidamente strings candidatas a localizacao
- revisar um app Flutter antes de introduzir `intl` ou arquivos `.arb`
- automatizar uma auditoria local com saida JSON simples

## Testes

```bash
bash test/test.sh
```

## Documentacao

- Guia rapido: [docs/cli-quickstart.md](/home/lluz/dev/local_tools/flutter_local_helper/docs/cli-quickstart.md)
- Referencia da CLI: [docs/cli-reference.md](/home/lluz/dev/local_tools/flutter_local_helper/docs/cli-reference.md)
