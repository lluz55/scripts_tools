# Android SDK/NDK Setup para NixOS

Script independente para instalação e configuração do Android SDK e NDK no NixOS, sem dependência de devshell ou flake.nix.

## Índice

- [Visão Geral](#visão-geral)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Estrutura de Diretórios](#estrutura-de-diretórios)
- [Uso](#uso)
- [Integração com Projetos](#integração-com-projetos)
- [Integração com Flake.nix](#integração-com-flakenix)
- [Solução de Problemas](#solução-de-problemas)
- [Atualização de Versões](#atualização-de-versões)

## Visão Geral

Este script foi projetado especificamente para o NixOS, lidando com:

- **Binários pré-compilados**: Usa `patchelf` para corrigir o interpretador dinâmico de binários ELF (adb, fastboot, aapt, etc.)
- **Dependências dinâmicas**: Cria wrappers que configuram `LD_LIBRARY_PATH` usando bibliotecas do nixpkgs
- **Java Runtime**: Configura automaticamente o OpenJDK 17 via nix-shell
- **Independência**: Funciona sem devshell, flake.nix ou arquivos de configuração adicionais

### Versões Instaladas

| Componente | Versão |
|------------|--------|
| SDK Command-line Tools | 11.0 (11076708) |
| NDK | r27 |
| Build Tools | 34.0.0 |
| Platform | android-34 |
| Platform Tools | mais recente |

## Requisitos

- **NixOS** ou sistema com Nix instalado
- **Conexão com a internet** (para downloads)
- **~3 GB de espaço em disco** (SDK + NDK)

### Verificação de Pré-requisitos

```bash
# Verificar se o Nix está instalado
nix-shell --version

# Verificar espaço disponível
df -h ~
```

## Instalação

### Execução Rápida

```bash
# Baixar e executar
curl -O https://seu-servidor/setup-android.sh
chmod +x setup-android.sh
./setup-android.sh
```

### Execução com Diretório Personalizado

```bash
# Instalar em local personalizado
ANDROID_HOME=/opt/android ./setup-android.sh
```

### Após a Instalação

Adicione ao seu shell RC (`~/.bashrc` ou `~/.zshrc`):

```bash
source ~/android/rc_snippet.sh
```

Ou execute manualmente quando necessário:

```bash
source ~/android/env.sh
```

## Estrutura de Diretórios

```
~/android/
├── sdk/                              # Android SDK
│   ├── cmdline-tools/
│   │   └── latest/                   # SDK Manager, avdmanager
│   │       └── bin/
│   │           ├── sdkmanager
│   │           └── avdmanager
│   ├── platform-tools/               # adb, fastboot, sqlite3
│   │   ├── adb
│   │   ├── fastboot
│   │   └── ...
│   ├── build-tools/
│   │   └── 34.0.0/                   # aapt, aapt2, d8, zipalign
│   │       ├── aapt
│   │       ├── aapt2
│   │       └── ...
│   └── platforms/
│       └── android-34/               # Android 34 platform
│
├── ndk/                              # Android NDK
│   ├── android-ndk-r27/              # NDK real
│   └── latest -> android-ndk-r27/    # Symlink para versão atual
│
├── cache/                            # Downloads (reutilizáveis)
│   ├── commandlinetools-linux-*.zip
│   └── android-ndk-r27-linux.zip
│
├── env.sh                            # Script de ambiente
├── rc_snippet.sh                     # Snippet para .bashrc/.zshrc
└── sdkmanager                        # Wrapper para sdkmanager
```

## Uso

### Variáveis de Ambiente

Após carregar o ambiente (`source ~/android/env.sh`):

| Variável | Valor |
|----------|-------|
| `ANDROID_HOME` | `~/android/sdk` |
| `ANDROID_SDK_ROOT` | `~/android/sdk` |
| `ANDROID_NDK_HOME` | `~/android/ndk/latest` |
| `ANDROID_NDK` | `~/android/ndk/latest` |

### SDK Manager

Use o wrapper fornecido para gerenciar pacotes do SDK:

```bash
# Listar pacotes disponíveis
~/android/sdkmanager --list

# Instalar pacotes adicionais
~/android/sdkmanager "platforms;android-33"
~/android/sdkmanager "build-tools;33.0.0"

# Atualizar todos os pacotes
~/android/sdkmanager --update

# Aceitar todas as licenças
~/android/sdkmanager --licenses
```

### ADB e Fastboot

```bash
# Verificar dispositivos conectados
adb devices

# Reiniciar dispositivo em modo fastboot
adb reboot bootloader

# Flash de imagem
fastboot flash boot boot.img
```

### NDK - Compilação Nativa

```bash
# Compilar com clang do NDK
$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/clang \
    -target aarch64-linux-android34 \
    -o myprogram myprogram.c
```

## Integração com Projetos

### React Native

**`android/local.properties`:**
```properties
sdk.dir=/home/seu-usuario/android/sdk
ndk.dir=/home/seu-usuario/android/ndk/latest
```

**Ou via variáveis de ambiente:**
```bash
export ANDROID_HOME=$HOME/android/sdk
export ANDROID_NDK_HOME=$HOME/android/ndk/latest
```

### Flutter

```bash
flutter config --android-sdk ~/android/sdk
flutter config --android-ndk ~/android/ndk/latest
```

### Gradle (Kotlin DSL)

**`build.gradle.kts`:**
```kotlin
android {
    ndkPath = file("${System.getProperty("user.home")}/android/ndk/latest").absolutePath
}
```

### CMake com NDK

**`CMakeLists.txt`:**
```cmake
set(ANDROID_NDK "$ENV{HOME}/android/ndk/latest")
set(CMAKE_TOOLCHAIN_FILE "${ANDROID_NDK}/build/cmake/android.toolchain.cmake")
set(ANDROID_ABI arm64-v8a)
set(ANDROID_PLATFORM android-34)
```

## Integração com Flake.nix

O script pode ser integrado a um flake.nix para desenvolvimento:

### Opção 1: Verificar e Executar

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      
      # Verifica se o Android SDK está instalado
      androidHome = builtins.getEnv "ANDROID_HOME" + "/sdk" 
        || "${builtins.getEnv "HOME"}/android/sdk";
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # Dependências do sistema (não do Android SDK)
          openjdk17
          gradle
        ];
        
        shellHook = ''
          # Configurar Android SDK se existir
          if [ -d "$HOME/android/sdk" ]; then
            export ANDROID_HOME="$HOME/android/sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export ANDROID_NDK_HOME="$HOME/android/ndk/latest"
            export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
            export PATH="$ANDROID_HOME/platform-tools:$PATH"
            echo "Android SDK configurado: $ANDROID_HOME"
          else
            echo "Execute ./setup-android.sh primeiro"
          fi
        '';
      };
    };
}
```

### Opção 2: Execução Automática

```nix
# flake.nix com instalação automática
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      setupAndroid = pkgs.writeShellScriptBin "setup-android" ''
        if [ ! -d "$HOME/android/sdk" ]; then
          echo "Instalando Android SDK/NDK..."
          ${./setup-android.sh}
        fi
      '';
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = [ setupAndroid ];
        
        shellHook = ''
          if [ ! -d "$HOME/android/sdk" ]; then
            echo "Android SDK não encontrado. Execute: setup-android"
          else
            export ANDROID_HOME="$HOME/android/sdk"
            export ANDROID_NDK_HOME="$HOME/android/ndk/latest"
            export PATH="$ANDROID_HOME/platform-tools:$PATH"
          fi
        '';
      };
    };
}
```

### Opção 3: Wrapper Derivation (avançado)

```nix
# Criar wrappers FHS para binários Android
{ pkgs ? import <nixpkgs> {} }:

pkgs.buildFHSEnv {
  name = "android-env";
  targetPkgs = pkgs: with pkgs; [
    openjdk17
    stdenv.cc.cc.lib
    ncurses5
    zlib
  ];
  
  runScript = pkgs.writeShellScript "android-shell" ''
    export ANDROID_HOME="$HOME/android/sdk"
    export ANDROID_NDK_HOME="$HOME/android/ndk/latest"
    exec "$SHELL"
  '';
}
```

## Solução de Problemas

### "command not found: adb"

```bash
# Verificar se o ambiente está carregado
source ~/android/env.sh

# Verificar PATH
echo $PATH | grep android
```

### "adb: cannot execute: required file not found"

O binário não foi patcheado corretamente:

```bash
# Verificar se é ELF
file ~/android/sdk/platform-tools/adb

# Re-executar patch
nix-shell -p patchelf stdenv.cc.cc.lib --run '
  patchelf --set-interpreter $(patchelf --print-interpreter $(which bash)) \
    ~/android/sdk/platform-tools/adb
'
```

### "sdkmanager: error: could not find java"

```bash
# O wrapper deve resolver isso automaticamente, mas se necessário:
nix-shell -p openjdk17 --run '~/android/sdkmanager --list'
```

### "Permission denied" ao conectar ADB

```bash
# Adicionar regra udev
sudo echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666"' \
  > /etc/udev/rules.d/51-android.rules
sudo udevadm control --reload-rules
```

### Licenças não aceitas

```bash
# Aceitar todas as licenças
yes | ~/android/sdkmanager --licenses
```

### NDK não encontrado pelo Gradle

```bash
# Verificar symlink
ls -la ~/android/ndk/latest

# Re-criar se necessário
ln -sf ~/android/ndk/android-ndk-r27 ~/android/ndk/latest
```

## Atualização de Versões

Para atualizar as versões dos componentes, edite o início do script:

```bash
# Linhas 20-26 do script
CMDLINE_TOOLS_VERSION="11076708"  # Command-line tools 11.0
NDK_VERSION="27"                  # NDK r27
BUILD_TOOLS_VERSION="34.0.0"
PLATFORM_VERSION="34"
```

### Descobrir Versões Disponíveis

```bash
# Listar todas as versões disponíveis
~/android/sdkmanager --list | grep -E "build-tools|platforms|ndk"
```

### Atualizar SDK

```bash
# Atualizar todos os componentes instalados
~/android/sdkmanager --update
```

## Limpeza

### Remover Cache

```bash
# Remover apenas arquivos de download (manter instalação)
rm -rf ~/android/cache
```

### Desinstalar Completamente

```bash
# Remover tudo
rm -rf ~/android

# Remover configurações do shell RC
# Edite ~/.bashrc ou ~/.zshrc e remova a linha:
# source ~/android/rc_snippet.sh
```

## Licença

Este script é fornecido "como está", sem garantias. O Android SDK e NDK estão sujeitos aos termos de licença do Google.

---

**Autor**: Gerado automaticamente  
**Compatibilidade**: NixOS  
**Última atualização**: 2024
