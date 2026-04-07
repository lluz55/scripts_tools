# Referencia da CLI

## Comando

```bash
./bin/flutter_local_helper [opcoes]
```

## Opcoes

`--root <path>`

- define a raiz do projeto a ser analisado
- padrao: `.`

`--scan <path>`

- define a pasta relativa a `--root` que sera varrida
- padrao: `lib`

`--output <path>`

- grava o JSON de saida em um arquivo
- quando omitido, a saida vai para `stdout`

`--help`, `-h`

- mostra a ajuda do comando

## Exemplos

Analisar a pasta `lib/` do projeto atual:

```bash
./bin/flutter_local_helper
```

Analisar outro projeto:

```bash
./bin/flutter_local_helper --root /home/usuario/dev/meu_app
```

Salvar a saida em arquivo:

```bash
./bin/flutter_local_helper --root /home/usuario/dev/meu_app --output strings.json
```

Analisar outra pasta:

```bash
./bin/flutter_local_helper --root /home/usuario/dev/meu_app --scan test
```

## Formato da saida JSON

A saida e uma lista JSON. Cada item representa uma ocorrencia encontrada com estes campos:

- `file`: caminho relativo do arquivo dentro do projeto
- `line`: linha da string no arquivo
- `column`: coluna inicial da string
- `text`: conteudo textual encontrado

## Observacoes

- a CLI analisa apenas arquivos `.dart`
- a deteccao usa heuristicas; o resultado serve para revisao humana
- algumas strings tecnicas sao ignoradas para reduzir ruido
- o projeto depende apenas de ferramentas comuns do sistema e `perl`
- o executavel usa `#!/usr/bin/env bash`
- o parser cobre raw strings, triple quotes, interpolacao e literais adjacentes
- interpolacoes puras como `$variavel` e `${obj.metodo()}` sao ignoradas para reduzir falso positivo
