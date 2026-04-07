#!/usr/bin/env bash
# Android SDK/NDK Setup Script for NixOS
# Fully independent - no devshell or flake.nix required
# Downloads and configures Android development tools in $HOME/android

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ANDROID_HOME="${ANDROID_HOME:-$HOME/android}"
SDK_DIR="$ANDROID_HOME/sdk"
NDK_DIR="$ANDROID_HOME/ndk"
CMDLINE_TOOLS_DIR="$SDK_DIR/cmdline-tools"

# Latest versions (update these manually when needed)
CMDLINE_TOOLS_VERSION="11076708"  # Command-line tools 11.0
CMDLINE_TOOLS_VERSION_NAME="11.0"
NDK_VERSION="27"                # NDK r27
NDK_VERSION_FULL="27.0.12077973"
BUILD_TOOLS_VERSION="34.0.0"
PLATFORM_VERSION="34"

# Print colored message
print_msg() {
    echo -e "${2}${1}${NC}"
}

print_info() {
    print_msg "$1" "$BLUE"
}

print_success() {
    print_msg "$1" "$GREEN"
}

print_warning() {
    print_msg "$1" "$YELLOW"
}

print_error() {
    print_msg "$1" "$RED"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v nix-shell &> /dev/null; then
        print_error "nix-shell not found. This script requires Nix."
        exit 1
    fi
    
    print_success "Nix is available"
}

# Create directory structure
create_directories() {
    print_info "Creating directory structure in $ANDROID_HOME..."
    
    mkdir -p "$SDK_DIR"
    mkdir -p "$NDK_DIR"
    mkdir -p "$CMDLINE_TOOLS_DIR"
    mkdir -p "$ANDROID_HOME/cache"
    
    print_success "Directory structure created"
}

# Download file using nix-shell to get wget
download_file() {
    local url="$1"
    local output="$2"
    local description="$3"
    
    print_info "Downloading $description..."
    
    if [ -f "$output" ]; then
        print_warning "File already exists: $output"
        read -p "Re-download? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing file"
            return 0
        fi
    fi
    
    nix-shell -p wget --run "wget -q --show-progress -O '$output' '$url'" 2>/dev/null || \
    nix-shell -p curl --run "curl -L --progress-bar -o '$output' '$url'"
}

# Download and install Command-line Tools
install_cmdline_tools() {
    print_info "Installing Android SDK Command-line Tools..."
    
    local cmdline_tools_zip="$ANDROID_HOME/cache/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
    local url="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
    
    # Download if not exists
    if [ ! -f "$cmdline_tools_zip" ]; then
        download_file "$url" "$cmdline_tools_zip" "Command-line Tools"
    fi
    
    print_info "Extracting Command-line Tools..."
    local temp_dir="$ANDROID_HOME/cache/cmdline-tools-temp-$$"
    
    # Clean up existing installation to avoid conflicts
    rm -rf "$CMDLINE_TOOLS_DIR/latest"
    
    mkdir -p "$temp_dir"
    nix-shell -p unzip --run "unzip -q '$cmdline_tools_zip' -d '$temp_dir'"
    
    mkdir -p "$CMDLINE_TOOLS_DIR/latest"
    mv "$temp_dir/cmdline-tools/"* "$CMDLINE_TOOLS_DIR/latest/" 2>/dev/null || true
    rm -rf "$temp_dir"
    
    print_success "Command-line Tools installed to $CMDLINE_TOOLS_DIR/latest"
}

# Run sdkmanager with proper NixOS environment
run_sdkmanager() {
    local sdkmanager="$CMDLINE_TOOLS_DIR/latest/bin/sdkmanager"
    
    # Run inside nix-shell with all dependencies
    # Use a temp script to handle arguments properly
    local temp_script="/tmp/sdkmanager-run-$$.sh"
    
    # Escape arguments for shell
    local escaped_args=""
    for arg in "$@"; do
        escaped_args="$escaped_args '$arg'"
    done
    
    cat > "$temp_script" << EOF
#!/usr/bin/env bash
export ANDROID_HOME="$SDK_DIR"
export ANDROID_SDK_ROOT="$SDK_DIR"
exec "$sdkmanager" $escaped_args
EOF
    chmod +x "$temp_script"
    
    nix-shell -p openjdk17 stdenv.cc.cc.lib ncurses5 --run "$temp_script"
    local exit_code=$?
    rm -f "$temp_script"
    return $exit_code
}

# Install SDK components using sdkmanager
install_sdk_components() {
    print_info "Installing SDK components..."
    
    local sdkmanager="$CMDLINE_TOOLS_DIR/latest/bin/sdkmanager"
    
    if [ ! -f "$sdkmanager" ]; then
        print_error "sdkmanager not found at $sdkmanager"
        exit 1
    fi
    
    # Accept licenses
    print_info "Accepting licenses..."
    yes | run_sdkmanager --licenses 2>&1 | tail -5 || true
    
    # Install components
    print_info "Installing platform tools, build tools, and platforms..."
    print_info "This may take a while..."
    
    run_sdkmanager \
        "platform-tools" \
        "build-tools;$BUILD_TOOLS_VERSION" \
        "platforms;android-$PLATFORM_VERSION"
    
    print_success "SDK components installed"
}

# Patch native binaries for NixOS using patchelf
patch_native_binaries() {
    print_info "Patching native binaries for NixOS..."
    
    local platform_tools_dir="$SDK_DIR/platform-tools"
    local build_tools_dir="$SDK_DIR/build-tools/$BUILD_TOOLS_VERSION"
    
    # Get the dynamic linker path from NixOS
    local interpreter
    interpreter=$(nix-shell -p patchelf --run "patchelf --print-interpreter $(which bash 2>/dev/null || echo /run/current-system/sw/bin/bash)" 2>/dev/null)
    
    if [ -z "$interpreter" ]; then
        print_warning "Could not determine interpreter path, using fallback method"
        # Fallback: create wrapper scripts instead
        create_binary_wrappers
        return 0
    fi
    
    print_info "Using interpreter: $interpreter"
    
    # Find all ELF binaries and patch them
    for dir in "$platform_tools_dir" "$build_tools_dir"; do
        if [ ! -d "$dir" ]; then
            continue
        fi
        
        for binary in "$dir"/*; do
            if [ -f "$binary" ] && [ -x "$binary" ]; then
                # Check if it's an ELF file using nix-shell
                if nix-shell -p file --run "file '$binary'" 2>/dev/null | grep -q "ELF"; then
                    print_info "Patching $(basename "$binary")..."
                    
                    # Get required libraries from nixpkgs
                    local lib_path
                    lib_path=$(nix-shell -p stdenv.cc.cc.lib --run 'echo -n $LD_LIBRARY_PATH')
                    
                    nix-shell -p patchelf --run \
                        "patchelf --set-interpreter '$interpreter' '$binary'" 2>/dev/null || {
                        print_warning "Failed to patch $(basename "$binary"), creating wrapper"
                        create_single_wrapper "$binary" "$interpreter"
                    }
                fi
            fi
        done
    done
    
    print_success "Native binaries patched"
}

# Create wrapper for a single binary
create_single_wrapper() {
    local binary="$1"
    local interpreter="$2"
    
    if [ -f "${binary}.orig" ]; then
        return 0  # Already wrapped
    fi
    
    mv "$binary" "${binary}.orig"
    
    cat > "$binary" << EOF
#!/usr/bin/env bash
export LD_LIBRARY_PATH="\$(nix-shell -p stdenv.cc.cc.lib --run 'echo -n \$LD_LIBRARY_PATH'):\${LD_LIBRARY_PATH:-}"
exec "${binary}.orig" "\$@"
EOF
    chmod +x "$binary"
}

# Create wrappers for all binaries (fallback method)
create_binary_wrappers() {
    print_info "Creating wrapper scripts for binaries..."
    
    local platform_tools_dir="$SDK_DIR/platform-tools"
    
    for binary in adb fastboot dmtracedump hprof-conv sqlite3 etc1tool; do
        if [ -f "$platform_tools_dir/$binary" ] && [ ! -f "$platform_tools_dir/${binary}.orig" ]; then
            mv "$platform_tools_dir/$binary" "$platform_tools_dir/${binary}.orig"
            
            cat > "$platform_tools_dir/$binary" << 'EOF'
#!/usr/bin/env bash
SCRIPT="${BASH_SOURCE[0]}"
export LD_LIBRARY_PATH="$(nix-shell -p stdenv.cc.cc.lib --run 'echo -n $LD_LIBRARY_PATH'):${LD_LIBRARY_PATH:-}"
exec "${SCRIPT}.orig" "$@"
EOF
            chmod +x "$platform_tools_dir/$binary"
            print_info "Wrapped $binary"
        fi
    done
    
    print_success "Wrapper scripts created"
}

# Download and install NDK
install_ndk() {
    print_info "Installing Android NDK..."
    
    local ndk_zip="$ANDROID_HOME/cache/android-ndk-r${NDK_VERSION}-linux.zip"
    local url="https://dl.google.com/android/repository/android-ndk-r${NDK_VERSION}-linux.zip"
    
    if [ ! -f "$ndk_zip" ]; then
        download_file "$url" "$ndk_zip" "NDK r$NDK_VERSION"
    fi
    
    # Verify download
    if ! nix-shell -p unzip --run "unzip -t '$ndk_zip'" >/dev/null 2>&1; then
        print_error "Downloaded NDK file is corrupted. Removing and retrying..."
        rm -f "$ndk_zip"
        download_file "$url" "$ndk_zip" "NDK r$NDK_VERSION"
    fi
    
    print_info "Extracting NDK (this may take a while)..."
    nix-shell -p unzip --run "unzip -q '$ndk_zip' -d '$NDK_DIR'"
    
    # Find the extracted directory (may be android-ndk-r27 or similar)
    local ndk_extracted_dir=$(ls -d "$NDK_DIR"/android-ndk-* 2>/dev/null | head -1)
    
    if [ -z "$ndk_extracted_dir" ]; then
        print_error "Failed to find extracted NDK directory"
        exit 1
    fi
    
    # Create symlink for easy access
    ln -sf "$ndk_extracted_dir" "$NDK_DIR/latest" 2>/dev/null || true
    
    print_success "NDK installed to $ndk_extracted_dir"
}

# Generate helper script to run sdkmanager
generate_sdkmanager_wrapper() {
    local wrapper="$ANDROID_HOME/sdkmanager"
    
    cat > "$wrapper" << 'EOF'
#!/usr/bin/env bash
# Wrapper to run sdkmanager on NixOS
ANDROID_HOME="${ANDROID_HOME:-$HOME/android/sdk}"
SDK_CMDLINE_TOOLS="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

if [ ! -f "$SDK_CMDLINE_TOOLS" ]; then
    echo "Error: sdkmanager not found at $SDK_CMDLINE_TOOLS"
    exit 1
fi

# Escape arguments
escaped_args=""
for arg in "$@"; do
    escaped_args="$escaped_args '$arg'"
done

# Create temp script
temp_script=$(mktemp)
cat > "$temp_script" << SCRIPT
#!/usr/bin/env bash
export ANDROID_HOME="$ANDROID_HOME"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
exec "$SDK_CMDLINE_TOOLS" $escaped_args
SCRIPT
chmod +x "$temp_script"

nix-shell -p openjdk17 stdenv.cc.cc.lib ncurses5 --run "$temp_script"
exit_code=$?
rm -f "$temp_script"
exit $exit_code
EOF
    chmod +x "$wrapper"
    print_success "Created sdkmanager wrapper at $wrapper"
}

# Generate environment setup script
generate_env_script() {
    local env_script="$ANDROID_HOME/env.sh"
    
    print_info "Generating environment setup script..."
    
    cat > "$env_script" << 'EOF'
#!/usr/bin/env bash
# Android SDK/NDK Environment Setup for NixOS
# Source this file: source ~/android/env.sh

export ANDROID_HOME="${ANDROID_HOME:-$HOME/android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$HOME/android/ndk/latest}"
export ANDROID_NDK="$ANDROID_NDK_HOME"

# Add to PATH
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export PATH="$ANDROID_HOME/emulator:$PATH"
export PATH="$ANDROID_HOME/tools:$PATH"
export PATH="$ANDROID_HOME/tools/bin:$PATH"
export PATH="$ANDROID_NDK_HOME:$PATH"
export PATH="$HOME/android:$PATH"  # For sdkmanager wrapper

echo "Android SDK/NDK environment configured:"
echo "  ANDROID_HOME=$ANDROID_HOME"
echo "  ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
echo ""
echo "Use 'sdkmanager' wrapper for SDK operations"
EOF

    chmod +x "$env_script"
    print_success "Environment script created at $env_script"
}

# Generate shell RC snippet
generate_rc_snippet() {
    local rc_file="$ANDROID_HOME/rc_snippet.sh"
    
    cat > "$rc_file" << 'EOF'
# Add these lines to your ~/.bashrc or ~/.zshrc:
# source ~/android/rc_snippet.sh

export ANDROID_HOME="$HOME/android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="$HOME/android/ndk/latest"
export ANDROID_NDK="$ANDROID_NDK_HOME"

export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export PATH="$ANDROID_HOME/emulator:$PATH"
export PATH="$ANDROID_NDK_HOME:$PATH"
export PATH="$HOME/android:$PATH"  # For sdkmanager wrapper
EOF

    print_info "Add this to your shell RC file (~/.bashrc or ~/.zshrc):"
    echo ""
    echo "    source $rc_file"
    echo ""
}

# Verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    local errors=0
    
    [ -d "$SDK_DIR" ] && print_success "✓ SDK directory exists" || { print_error "✗ SDK directory missing"; ((errors++)); }
    [ -d "$NDK_DIR/latest" ] && print_success "✓ NDK directory exists" || { print_error "✗ NDK directory missing"; ((errors++)); }
    [ -f "$CMDLINE_TOOLS_DIR/latest/bin/sdkmanager" ] && print_success "✓ sdkmanager available" || { print_error "✗ sdkmanager missing"; ((errors++)); }
    [ -f "$SDK_DIR/platform-tools/adb" ] && print_success "✓ adb available" || { print_error "✗ adb missing"; ((errors++)); }
    [ -f "$ANDROID_HOME/sdkmanager" ] && print_success "✓ sdkmanager wrapper created" || { print_error "✗ sdkmanager wrapper missing"; ((errors++)); }
    
    if [ $errors -eq 0 ]; then
        print_success "Installation verified successfully!"
        return 0
    else
        print_error "Installation has $errors error(s)"
        return 1
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "========================================"
    print_success "Android SDK/NDK Setup Complete!"
    echo "========================================"
    echo ""
    echo "Installation locations:"
    echo "  SDK:      $SDK_DIR"
    echo "  NDK:      $NDK_DIR/latest (-> $(readlink "$NDK_DIR/latest" 2>/dev/null || echo "not found"))"
    echo ""
    echo "To use this setup:"
    echo ""
    echo "  1. Add to your shell RC (~/.bashrc or ~/.zshrc):"
    echo "     source $ANDROID_HOME/rc_snippet.sh"
    echo ""
    echo "  2. Or source manually when needed:"
    echo "     source $ANDROID_HOME/env.sh"
    echo ""
    echo "  3. Use the sdkmanager wrapper for SDK operations:"
    echo "     ~/android/sdkmanager --list"
    echo ""
    echo "For project builds (Gradle, React Native, Flutter):"
    echo "  ANDROID_HOME=$SDK_DIR"
    echo "  ANDROID_NDK_HOME=$NDK_DIR/latest"
    echo ""
}

# Main installation flow
main() {
    echo ""
    echo "========================================"
    echo "  Android SDK/NDK Installer for NixOS"
    echo "  (Standalone - No flake.nix required)"
    echo "========================================"
    echo ""
    
    print_info "Target directory: $ANDROID_HOME"
    print_info "SDK Command-line Tools: $CMDLINE_TOOLS_VERSION_NAME ($CMDLINE_TOOLS_VERSION)"
    print_info "NDK Version: $NDK_VERSION_FULL"
    print_info "Build Tools: $BUILD_TOOLS_VERSION"
    print_info "Platform: android-$PLATFORM_VERSION"
    echo ""
    
    check_prerequisites
    
    read -p "Proceed with installation? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Installation cancelled"
        exit 0
    fi
    
    create_directories
    install_cmdline_tools
    install_sdk_components
    patch_native_binaries
    install_ndk
    generate_sdkmanager_wrapper
    generate_env_script
    generate_rc_snippet
    verify_installation
    print_summary
}

main "$@"
