#!/bin/bash
# SMTP-Tunnel - Iran DPI Bypass Installer
set -e

REPO="3x-code/SMTP-Tunnel"
VERSION=${1:-latest}
INSTALL_DIR="/usr/local/bin"

echo "════════════════════════════════════════════"
echo "  SMTP-Tunnel - Iran DPI Bypass Installer"
echo "════════════════════════════════════════════"

# Detect platform
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    case $ARCH in x86_64) ARCH="amd64" ;; aarch64) ARCH="arm64" ;; armv7l) ARCH="armv7" ;; esac
    case $OS in linux) echo "linux_${ARCH}" ;; darwin) echo "darwin_${ARCH}" ;; *) echo "linux_amd64" ;; esac
}

# Get latest version
get_latest_version() {
    curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Main installation
main() {
    echo "📱 Detecting platform..."
    PLATFORM=$(detect_platform)
    echo "✓ Platform: ${PLATFORM}"

    if [ "$VERSION" = "latest" ]; then
        echo "📦 Fetching latest version..."
        VERSION=$(get_latest_version)
    fi
    echo "✓ Version: ${VERSION}"

    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"

    URL="https://github.com/${REPO}/releases/download/${VERSION}/smtp-tunnel-${VERSION}-${PLATFORM}.tar.gz"
    echo "⬇️ Downloading: ${URL}"

    if curl -L -o smtp-tunnel.tar.gz "$URL"; then
        tar xzf smtp-tunnel.tar.gz
        if [ -f "smtp-tunnel" ]; then
            sudo cp smtp-tunnel "${INSTALL_DIR}/smtp-tunnel"
            sudo chmod +x "${INSTALL_DIR}/smtp-tunnel"
            echo "✅ Binary installed to ${INSTALL_DIR}/smtp-tunnel"
        else
            echo "❌ Binary not found in archive"
            exit 1
        fi
    else
        echo "❌ Download failed"
        exit 1
    fi

    cd / && rm -rf "$TMP_DIR"
    echo "✅ Installation complete!"
    echo ""
    echo "📋 Next step: Run ${GREEN}smtp-tunnel --interactive${NC}"
}

main "$@"
