#!/bin/bash
# SMTP-Tunnel Universal Installer - SERVER OPTIMIZED VERSION
# One script for both Server and Client - Forces proper detection

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Version
VERSION="v0.2.0"

# Print banner
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                    SMTP Tunnel - Iran DPI Bypass            ║
║                      Universal Installer                    ║
║                    SERVER-OPTIMIZED VERSION                 ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${GREEN}  Version: $VERSION${NC}"
    echo -e "${BLUE}  One script for Server (VPS) and Client (Iran)${NC}"
    echo ""
}

# Force server installation - THIS IS THE KEY FIX!
force_server_mode() {
    echo -e "${GREEN}🔧 FORCING SERVER MODE - VPS OUTSIDE IRAN${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    install_server
    exit 0
}

# Force client installation
force_client_mode() {
    echo -e "${GREEN}🔧 FORCING CLIENT MODE - INSIDE IRAN${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    install_client "$@"
    exit 0
}

# Check system requirements
check_requirements() {
    echo -e "${YELLOW}🔍 Checking system requirements...${NC}"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ This script requires root privileges${NC}"
        echo -e "Please run: sudo $0"
        exit 1
    fi
    
    # Check OS
    if [ ! -f /etc/os-release ]; then
        echo -e "${RED}❌ Unsupported OS${NC}"
        exit 1
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ]; then
        echo -e "${RED}❌ Unsupported architecture: $ARCH (only x86_64 supported)${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ System requirements met${NC}"
}

# Install Go properly
install_go() {
    echo -e "${YELLOW}📦 Installing Go 1.22.5...${NC}"
    
    cd /tmp
    wget -q https://go.dev/dl/go1.22.5.linux-amd64.tar.gz || {
        echo -e "${RED}❌ Failed to download Go${NC}"
        exit 1
    }
    
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
    
    # Set up Go environment
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
    
    if ! command -v go &> /dev/null; then
        echo -e "${RED}❌ Go installation failed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Go $(go version | awk '{print $3}') installed${NC}"
}

# Build server binary
build_server() {
    echo -e "${YELLOW}🔨 Building server binary...${NC}"
    
    cd /root
    rm -rf SMTP-Tunnel
    
    git clone https://github.com/3x-code/SMTP-Tunnel.git || {
        echo -e "${RED}❌ Failed to clone repository${NC}"
        exit 1
    }
    
    cd SMTP-Tunnel
    
    # Initialize module
    go mod init github.com/3x-code/SMTP-Tunnel 2>/dev/null || true
    
    # Get dependencies
    go get github.com/fatih/color@v1.18.0
    go get gopkg.in/yaml.v3@v3.0.1
    
    # Tidy and build
    go mod tidy
    go build -buildvcs=false -ldflags="-s -w -X main.version=${VERSION}" -o smtp-tunnel-server ./cmd/server
    
    if [ ! -f "smtp-tunnel-server" ]; then
        echo -e "${RED}❌ Server build failed${NC}"
        exit 1
    fi
    
    cp smtp-tunnel-server /usr/local/bin/
    chmod +x /usr/local/bin/smtp-tunnel-server
    
    echo -e "${GREEN}✓ Server binary built successfully${NC}"
}

# Setup SSL certificates
setup_ssl() {
    local DOMAIN=$1
    local EMAIL=$2
    
    echo -e "${YELLOW}🔐 Setting up SSL certificate...${NC}"
    
    mkdir -p /etc/smtp-tunnel/certs
    
    # Always use self-signed for reliability
    echo -e "${YELLOW}Creating self-signed SSL certificate...${NC}"
    openssl req -x509 -newkey rsa:2048 \
        -keyout /etc/smtp-tunnel/certs/server.key \
        -out /etc/smtp-tunnel/certs/server.crt \
        -days 365 -nodes \
        -subj "/CN=${DOMAIN}" 2>/dev/null
    
    chmod 600 /etc/smtp-tunnel/certs/server.key
    echo -e "${GREEN}✓ SSL certificate setup complete${NC}"
}

# Install server - THIS IS THE FIXED VERSION
install_server() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🖥️  INSTALLING SMTP-Tunnel SERVER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Install system dependencies
    echo -e "${YELLOW}📦 Installing system dependencies...${NC}"
    apt update -qq
    apt install -y -qq wget curl git openssl ufw
    
    # Install Go
    install_go
    
    # Build server
    build_server
    
    # Get server configuration
    echo ""
    echo -e "${GREEN}📋 SERVER CONFIGURATION${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Please enter your server details:${NC}"
    echo ""
    
    read -p "Enter your server domain or IP: " SERVER_DOMAIN
    read -p "Enter your email (for SSL notifications): " SSL_EMAIL
    read -p "Enter username for client: " CLIENT_USERNAME
    
    # Generate random secret
    CLIENT_SECRET=$(openssl rand -hex 16)
    echo -e "${YELLOW}Generated client secret: ${GREEN}${CLIENT_SECRET}${NC}"
    echo -e "${RED}⚠️  SAVE THIS SECRET - IT WILL NOT BE SHOWN AGAIN!${NC}"
    echo ""
    
    # Setup SSL
    setup_ssl "$SERVER_DOMAIN" "$SSL_EMAIL"
    
    # Create server config
    echo -e "${YELLOW}📝 Creating server configuration...${NC}"
    mkdir -p /etc/smtp-tunnel
    mkdir -p /var/log/smtp-tunnel
    
    cat > /etc/smtp-tunnel/server.yaml << EOF
server:
  host: 0.0.0.0
  port: 587
  hostname: ${SERVER_DOMAIN}

tls:
  cert_file: /etc/smtp-tunnel/certs/server.crt
  key_file: /etc/smtp-tunnel/certs/server.key

users:
  ${CLIENT_USERNAME}:
    secret: "${CLIENT_SECRET}"
    whitelist: []
    logging: true

logging:
  level: info
  file: /var/log/smtp-tunnel/server.log
EOF
    
    echo -e "${GREEN}✓ Server configuration created${NC}"
    
    # Create systemd service
    echo -e "${YELLOW}⚙️  Creating systemd service...${NC}"
    cat > /etc/systemd/system/smtp-tunnel-server.service << EOF
[Unit]
Description=SMTP-Tunnel Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/smtp-tunnel-server -config /etc/smtp-tunnel/server.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    # Configure firewall
    echo -e "${YELLOW}🛡️  Configuring firewall...${NC}"
    ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
    ufw allow 587/tcp comment 'SMTP-Tunnel' 2>/dev/null || true
    ufw --force enable 2>/dev/null || true
    echo -e "${GREEN}✓ Firewall configured (port 587 open)${NC}"
    
    # Start service
    systemctl daemon-reload
    systemctl enable smtp-tunnel-server
    systemctl start smtp-tunnel-server
    
    sleep 3
    
    if systemctl is-active --quiet smtp-tunnel-server; then
        echo -e "${GREEN}✅ Server service started successfully${NC}"
    else
        echo -e "${RED}❌ Server service failed to start${NC}"
        echo -e "${YELLOW}Check logs: journalctl -u smtp-tunnel-server -f${NC}"
    fi
    
    # Generate client command
    CLIENT_CMD="curl -sSL https://raw.githubusercontent.com/3x-code/SMTP-Tunnel/main/scripts/install-universal.sh | bash -s client ${SERVER_DOMAIN} ${CLIENT_USERNAME} ${CLIENT_SECRET}"
    
    echo -e "${GREEN}✅✅✅ SERVER INSTALLATION COMPLETE! ✅✅✅${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}YOUR SERVER IS READY!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🌍 Server Address:    ${CYAN}${SERVER_DOMAIN}:587${NC}"
    echo -e "👤 Client Username:   ${CYAN}${CLIENT_USERNAME}${NC}"
    echo -e "🔑 Client Secret:     ${CYAN}${CLIENT_SECRET}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📋 CLIENT INSTALLATION COMMAND (Run on computer inside Iran):${NC}"
    echo -e "${CYAN}${CLIENT_CMD}${NC}"
    echo ""
    echo -e "${YELLOW}📋 Save this command to a file:${NC}"
    echo -e "${CLIENT_CMD}" > /root/client-install-command.txt
    echo -e "${GREEN}✓ Client command saved to: /root/client-install-command.txt${NC}"
    echo ""
    echo -e "${YELLOW}📋 Server Management:${NC}"
    echo -e "  Status:  systemctl status smtp-tunnel-server"
    echo -e "  Logs:    journalctl -u smtp-tunnel-server -f"
    echo -e "  Restart: systemctl restart smtp-tunnel-server"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Install client - SIMPLIFIED VERSION
install_client() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}💻  INSTALLING SMTP-Tunnel CLIENT${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local SERVER=""
    local USERNAME=""
    local SECRET=""
    
    # Get parameters from command line
    if [ "$1" = "client" ] && [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ]; then
        SERVER="$2"
        USERNAME="$3"
        SECRET="$4"
        echo -e "${GREEN}✓ Using server: ${SERVER}${NC}"
        echo -e "${GREEN}✓ Using username: ${USERNAME}${NC}"
    else
        echo -e "${RED}❌ Error: Missing parameters${NC}"
        echo -e "Usage: $0 client <server> <username> <secret>"
        echo -e "Example: $0 client 123.45.67.89 alice mysecret123"
        exit 1
    fi
    
    # Download client binary
    echo -e "${YELLOW}📦 Downloading client binary...${NC}"
    cd /tmp
    rm -f smtp-tunnel-client*.tar.gz smtp-tunnel
    
    curl -L --connect-timeout 10 \
        -o smtp-tunnel-client.tar.gz \
        "https://github.com/3x-code/SMTP-Tunnel/releases/download/${VERSION}/smtp-tunnel-client-${VERSION}-linux_amd64.tar.gz" || {
        echo -e "${YELLOW}Download failed, trying fallback...${NC}"
        curl -L --connect-timeout 10 \
            -o smtp-tunnel-client.tar.gz \
            "https://github.com/3x-code/SMTP-Tunnel/releases/download/v0.2.0/smtp-tunnel-client-v0.2.0-linux_amd64.tar.gz"
    }
    
    if [ ! -f "smtp-tunnel-client.tar.gz" ]; then
        echo -e "${RED}❌ Failed to download client binary${NC}"
        exit 1
    fi
    
    tar xzf smtp-tunnel-client.tar.gz
    cp smtp-tunnel /usr/local/bin/
    chmod +x /usr/local/bin/smtp-tunnel
    echo -e "${GREEN}✓ Client binary installed${NC}"
    
    # Create client config
    echo -e "${YELLOW}📝 Creating client configuration...${NC}"
    mkdir -p /etc/smtp-tunnel
    mkdir -p /var/log/smtp-tunnel
    
    cat > /etc/smtp-tunnel/client.yaml << EOF
server:
  host: ${SERVER}
  port: 587
  fallback_ports:
    - 465
    - 2525

auth:
  username: ${USERNAME}
  secret: "${SECRET}"

socks:
  host: 127.0.0.1
  port: 1080

bypass:
  isp: auto
  strategy: balanced
  port_hopping: true
  sni_fronting: true

logging:
  level: info
  file: /var/log/smtp-tunnel/client.log
EOF
    
    # Create systemd service
    echo -e "${YELLOW}⚙️  Creating systemd service...${NC}"
    cat > /etc/systemd/system/smtp-tunnel-client.service << EOF
[Unit]
Description=SMTP-Tunnel Client
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/smtp-tunnel --config /etc/smtp-tunnel/client.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Start service
    systemctl daemon-reload
    systemctl enable smtp-tunnel-client
    systemctl start smtp-tunnel-client
    
    echo -e "${GREEN}✅✅✅ CLIENT INSTALLATION COMPLETE! ✅✅✅${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🌍 Server:  ${CYAN}${SERVER}:587${NC}"
    echo -e "👤 Username: ${CYAN}${USERNAME}${NC}"
    echo -e "🔌 SOCKS5:   ${CYAN}127.0.0.1:1080${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📋 Test the proxy:${NC}"
    echo -e "  curl --socks5 127.0.0.1:1080 https://www.google.com"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# SHOW USAGE
show_help() {
    echo -e "${CYAN}SMTP-Tunnel Universal Installer${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Usage:"
    echo -e "  ${GREEN}For SERVER (VPS outside Iran):${NC}"
    echo -e "    curl -sSL https://raw.githubusercontent.com/3x-code/SMTP-Tunnel/main/scripts/install-universal.sh | bash -s server"
    echo -e ""
    echo -e "  ${GREEN}For CLIENT (Inside Iran):${NC}"
    echo -e "    curl -sSL https://raw.githubusercontent.com/3x-code/SMTP-Tunnel/main/scripts/install-universal.sh | bash -s client <server> <username> <secret>"
    echo -e ""
    echo -e "  ${GREEN}Examples:${NC}"
    echo -e "    # Server"
    echo -e "    curl -sSL https://... | bash -s server"
    echo -e ""
    echo -e "    # Client"  
    echo -e "    curl -sSL https://... | bash -s client 123.45.67.89 alice abc123def456"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# MAIN - SIMPLIFIED AND FOOLPROOF
main() {
    print_banner
    check_requirements
    
    case "$1" in
        server)
            force_server_mode
            ;;
        client)
            force_client_mode "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}❌ ERROR: You must specify server or client mode!${NC}"
            echo -e ""
            show_help
            exit 1
            ;;
    esac
}

# Run main with all arguments
main "$@"
