#!/bin/bash
# SMTP-Tunnel - Iran DPI Bypass Installer
# https://github.com/3x-code/SMTP-Tunnel

set -e

REPO="3x-code/SMTP-Tunnel"
VERSION=${1:-latest}
INSTALL_DIR="/usr/local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  SMTP-Tunnel - Iran DPI Bypass Installer${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

# Detect OS and Architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l)  ARCH="armv7" ;;
        armv6l)  ARCH="armv6" ;;
        i386)    ARCH="386" ;;
        i686)    ARCH="386" ;;
    esac
    
    case $OS in
        darwin) OS="darwin" ;;
        linux)  OS="linux" ;;
        mingw*|cygwin*|msys*) OS="windows" ;;
    esac
    
    echo "${OS}_${ARCH}"
}

# Get latest version from GitHub
get_latest_version() {
    curl -s "https://api.github.com/repos/${REPO}/releases/latest" | 
    grep '"tag_name":' | 
    sed -E 's/.*"([^"]+)".*/\1/'
}

# Main installation
main() {
    echo -e "${YELLOW}📱 Detecting platform...${NC}"
    PLATFORM=$(detect_platform)
    echo -e "${GREEN}✓ Platform: ${PLATFORM}${NC}"
    
    if [ "$VERSION" = "latest" ]; then
        echo -e "${YELLOW}📦 Fetching latest version...${NC}"
        VERSION=$(get_latest_version)
        if [ -z "$VERSION" ]; then
            echo -e "${RED}❌ Failed to fetch latest version${NC}"
            echo -e "${YELLOW}⚠️  Falling back to development build${NC}"
            VERSION="dev"
        fi
    fi
    echo -e "${GREEN}✓ Version: ${VERSION}${NC}"
    
    # Create temp directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    if [ "$VERSION" = "dev" ]; then
        # Development build - clone and build
        echo -e "${YELLOW}🔨 Building from source...${NC}"
        git clone "https://github.com/${REPO}.git"
        cd SMTP-Tunnel
        make build
        sudo cp bin/* "${INSTALL_DIR}/"
    else
        # Release build - download binary
        URL="https://github.com/${REPO}/releases/download/${VERSION}/smtp-tunnel-${VERSION}-${PLATFORM}.tar.gz"
        echo -e "${YELLOW}⬇️ Downloading: ${URL}${NC}"
        
        if curl -L -o smtp-tunnel.tar.gz "$URL"; then
            tar xzf smtp-tunnel.tar.gz
            sudo cp smtp-tunnel-*/smtp-tunnel-* "${INSTALL_DIR}/"
        else
            echo -e "${RED}❌ Download failed${NC}"
            exit 1
        fi
    fi
    
    # Set permissions
    sudo chmod +x "${INSTALL_DIR}"/smtp-tunnel-*
    
    # Create config directory
    sudo mkdir -p /etc/smtp-tunnel/profiles
    sudo mkdir -p /var/log/smtp-tunnel
    
    # Cleanup
    cd /
    rm -rf "$TMP_DIR"
    
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "📋 Next steps:"
    echo -e "  1. Run: ${GREEN}smtp-tunnel-client --interactive${NC}"
    echo -e "  2. Follow the setup wizard"
    echo -e "  3. Configure your browser to use SOCKS5 proxy on ${YELLOW}127.0.0.1:1080${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

main "$@"
