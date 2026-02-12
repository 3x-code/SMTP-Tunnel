#!/bin/bash
# SMTP-Tunnel Server Installer

REPO="3x-code/SMTP-Tunnel"
VERSION=${1:-latest}
INSTALL_DIR="/usr/local/bin"

echo "Installing SMTP-Tunnel Server..."

# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
[ "$ARCH" = "x86_64" ] && ARCH="amd64"

# Get latest version
if [ "$VERSION" = "latest" ]; then
    VERSION=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | cut -d'"' -f4)
fi

# Download and install
cd /tmp
URL="https://github.com/${REPO}/releases/download/${VERSION}/smtp-tunnel-server-${VERSION}-${OS}_${ARCH}.tar.gz"
curl -L -o server.tar.gz "$URL"
tar xzf server.tar.gz
sudo cp smtp-tunnel-server ${INSTALL_DIR}/
sudo chmod +x ${INSTALL_DIR}/smtp-tunnel-server
rm -rf server.tar.gz smtp-tunnel-server

echo "✅ Server installed to ${INSTALL_DIR}/smtp-tunnel-server"
