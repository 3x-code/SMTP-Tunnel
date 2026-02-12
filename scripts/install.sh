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

# Detect platform
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case $ARCH in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l)  ARCH="arm7" ;;
    esac

    case $OS in
        linux)  echo "linux_${ARCH}" ;;
        darwin) echo "darwin_${ARCH}" ;;
        mingw*|cygwin*|msys*) echo "windows_${ARCH}" ;;
        *)      echo "linux_amd64" ;;
    esac
}

# Get latest version from GitHub
get_latest_version() {
    curl -s "https://api.github.com/repos/${REPO}/releases/latest" | 
    grep '"tag_name":' | 
    sed -E 's/.*"([^"]+)".*/\1/'
}

main() {
    echo -e "${YELLOW}📱 Detecting platform...${NC}"
    PLATFORM=$(detect_platform)
    echo -e "${GREEN}✓ Platform: ${PLATFORM}${NC}"

    if [ "$VERSION" = "latest" ]; then
        echo -e "${YELLOW}📦 Fetching latest version...${NC}"
        VERSION=$(get_latest_version)
        if [ -z "$VERSION" ]; then
            echo -e "${RED}❌ Failed to fetch latest version${NC}"
            exit 1
        fi
    fi
    echo -e "${GREEN}✓ Version: ${VERSION}${NC}"

    # Create temp directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    echo -e "${YELLOW}📁 Working in: $TMP_DIR${NC}"

    # Download the release
    URL="https://github.com/${REPO}/releases/download/${VERSION}/smtp-tunnel-client-${VERSION}-${PLATFORM}.tar.gz"
    echo -e "${YELLOW}⬇️ Downloading: ${URL}${NC}"

    if curl -L --progress-bar -o smtp-tunnel.tar.gz "$URL"; then
        # Check if file is valid gzip
        if file smtp-tunnel.tar.gz | grep -q "gzip compressed"; then
            echo -e "${GREEN}✓ Download successful${NC}"
            
            # Extract
            echo -e "${YELLOW}📦 Extracting...${NC}"
            tar xzf smtp-tunnel.tar.gz
            
            # Find and copy the binary
            if [ -f "smtp-tunnel" ]; then
                echo -e "${GREEN}✓ Binary found${NC}"
                sudo cp smtp-tunnel "${INSTALL_DIR}/smtp-tunnel"
                sudo chmod +x "${INSTALL_DIR}/smtp-tunnel"
                echo -e "${GREEN}✅ Binary installed to ${INSTALL_DIR}/smtp-tunnel${NC}"
            else
                echo -e "${RED}❌ Binary 'smtp-tunnel' not found in archive${NC}"
                echo "Contents of archive:"
                tar tf smtp-tunnel.tar.gz
                exit 1
            fi
        else
            echo -e "${RED}❌ Downloaded file is not a valid gzip archive${NC}"
            echo "File type:"
            file smtp-tunnel.tar.gz
            exit 1
        fi
    else
        echo -e "${RED}❌ Download failed${NC}"
        exit 1
    fi

    # Create config directory
    sudo mkdir -p /etc/smtp-tunnel
    sudo mkdir -p /var/log/smtp-tunnel

    # Cleanup
    cd /
    rm -rf "$TMP_DIR"

    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "📋 Next steps:"
    echo -e "  1. Run: ${GREEN}smtp-tunnel --interactive${NC}"
    echo -e "  2. Follow the setup wizard"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
}

main "$@"
