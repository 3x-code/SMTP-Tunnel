#!/bin/bash
# SMTP-Tunnel Universal Installer - WORKING VERSION
# One script for both Server and Client - Auto-detects and installs

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VERSION="v0.2.0"

print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              SMTP-Tunnel - Universal Installer               ║
║                    Server & Client Auto-Detector            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_requirements() {
    echo -e "${YELLOW}🔍 Checking system requirements...${NC}"
    
    if [ ! -f /etc/os-release ]; then
        echo -e "${RED}❌ Unsupported OS${NC}"
        exit 1
    fi
    
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ]; then
        echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ System requirements met${NC}"
}

detect_environment() {
    echo -e "${YELLOW}🔍 Detecting installation environment...${NC}"
    
    # Method 1: Check command line argument
    if [ "$1" = "server" ]; then
        echo -e "${GREEN}✓ Manual selection: SERVER mode${NC}"
        return 1
    elif [ "$1" = "client" ]; then
        echo -e "${GREEN}✓ Manual selection: CLIENT mode${NC}"
        return 0
    fi
    
    # Method 2: Check public IP
    if command -v curl &> /dev/null; then
        PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || echo "")
        if [ -n "$PUBLIC_IP" ]; then
            COUNTRY=$(curl -s --connect-timeout 3 "http://ip-api.com/line/${PUBLIC_IP}?fields=countryCode" 2>/dev/null || echo "")
            
            if [ "$COUNTRY" = "IR" ]; then
                echo -e "${GREEN}✓ Detected: CLIENT mode (IP in Iran)${NC}"
                return 0
            else
                echo -e "${GREEN}✓ Detected: SERVER mode (IP outside Iran)${NC}"
                return 1
            fi
        fi
    fi
    
    # Method 3: Ask user
    echo -e "${YELLOW}⚠️  Could not auto-detect environment${NC}"
    echo ""
    echo "Where are you installing this?"
    echo "  1) Server (VPS outside Iran)"
    echo "  2) Client (Inside Iran)"
    read -p "Enter choice (1-2): " ENV_CHOICE
    
    case $ENV_CHOICE in
        1) return 1 ;;
        2) return 0 ;;
        *) return 1 ;;
    esac
}

install_server() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🖥️  Installing SMTP-Tunnel SERVER...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Server installation requires root privileges${NC}"
        echo -e "Please run: sudo $0"
        exit 1
    fi
    
    # Install dependencies
    echo -e "${YELLOW}📦 Installing system dependencies...${NC}"
    apt update -qq
    apt install -y -qq wget curl git openssl ufw certbot
    
    # Install Go
    echo -e "${YELLOW}📦 Installing Go 1.22.5...${NC}"
    cd /tmp
    wget -q https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    
    # Build server
    echo -e "${YELLOW}🔨 Building server binary...${NC}"
    cd /root
    rm -rf SMTP-Tunnel
    git clone https://github.com/3x-code/SMTP-Tunnel.git
    cd SMTP-Tunnel
    
    go mod init github.com/3x-code/SMTP-Tunnel 2>/dev/null || true
    go get github.com/fatih/color@v1.18.0
    go get gopkg.in/yaml.v3@v3.0.1
    go mod tidy
    go build -buildvcs=false -ldflags="-s -w -X main.version=${VERSION}" -o smtp-tunnel-server ./cmd/server
    
    cp smtp-tunnel-server /usr/local/bin/
    chmod +x /usr/local/bin/smtp-tunnel-server
    
    # Get configuration
    echo ""
    echo -e "${GREEN}📋 Server Configuration${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "Enter your server domain or IP: " SERVER_DOMAIN
    read -p "Enter your email (for SSL): " SSL_EMAIL
    read -p "Enter username for client: " CLIENT_USERNAME
    CLIENT_SECRET=$(openssl rand -hex 16)
    echo -e "Generated secret key: ${GREEN}${CLIENT_SECRET}${NC}"
    
    # Setup SSL
    echo -e "${YELLOW}🔐 Setting up SSL certificate...${NC}"
    mkdir -p /etc/smtp-tunnel/certs
    
    openssl req -x509 -newkey rsa:2048 \
        -keyout /etc/smtp-tunnel/certs/server.key \
        -out /etc/smtp-tunnel/certs/server.crt \
        -days 365 -nodes \
        -subj "/CN=${SERVER_DOMAIN}" 2>/dev/null
    
    chmod 600 /etc/smtp-tunnel/certs/server.key
    
    # Create config
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
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    # Start service
    systemctl daemon-reload
    systemctl enable smtp-tunnel-server
    systemctl start smtp-tunnel-server
    
    echo -e "${GREEN}✅ SERVER INSTALLATION COMPLETE!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🌍 Server: ${GREEN}${SERVER_DOMAIN}:587${NC}"
    echo -e "👤 Username: ${GREEN}${CLIENT_USERNAME}${NC}"
    echo -e "🔑 Secret: ${GREEN}${CLIENT_SECRET}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📋 CLIENT INSTALLATION COMMAND:${NC}"
    echo -e "${CYAN}curl -sSL https://raw.githubusercontent.com/3x-code/SMTP-Tunnel/main/scripts/install-universal.sh | bash -s client ${SERVER_DOMAIN} ${CLIENT_USERNAME} ${CLIENT_SECRET}${NC}"
}

install_client() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}💻  Installing SMTP-Tunnel CLIENT...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local SERVER=""
    local USERNAME=""
    local SECRET=""
    
    if [ "$1" = "client" ] && [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ]; then
        SERVER="$2"
        USERNAME="$3"
        SECRET="$4"
    else
        read -p "Enter your server IP/domain: " SERVER
        read -p "Enter username: " USERNAME
        read -s -p "Enter secret key: " SECRET
        echo ""
    fi
    
    # Download client
    echo -e "${YELLOW}📦 Downloading client binary...${NC}"
    cd /tmp
    curl -L -o smtp-tunnel-client.tar.gz \
        "https://github.com/3x-code/SMTP-Tunnel/releases/download/v0.2.0/smtp-tunnel-client-v0.2.0-linux_amd64.tar.gz"
    
    tar xzf smtp-tunnel-client.tar.gz
    cp smtp-tunnel /usr/local/bin/
    chmod +x /usr/local/bin/smtp-tunnel
    
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
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    # Start service
    systemctl daemon-reload
    systemctl enable smtp-tunnel-client
    systemctl start smtp-tunnel-client
    
    echo -e "${GREEN}✅ CLIENT INSTALLATION COMPLETE!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🌍 Server: ${GREEN}${SERVER}:587${NC}"
    echo -e "👤 Username: ${GREEN}${USERNAME}${NC}"
    echo -e "🔌 SOCKS5: ${GREEN}127.0.0.1:1080${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# MAIN FUNCTION - THIS WAS MISSING!
main() {
    print_banner
    check_requirements
    
    if [ "$1" = "server" ]; then
        install_server
    elif [ "$1" = "client" ]; then
        install_client "$@"
    else
        detect_environment "$1"
        ENV_TYPE=$?
        
        case $ENV_TYPE in
            0) 
                echo -e "${GREEN}🔧 Installing CLIENT...${NC}"
                install_client 
                ;;
            1) 
                echo -e "${GREEN}🔧 Installing SERVER...${NC}"
                install_server
                ;;
        esac
    fi
}

# RUN MAIN FUNCTION WITH ALL ARGUMENTS
main "$@"
