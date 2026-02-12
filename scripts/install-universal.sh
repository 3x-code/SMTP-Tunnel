#!/bin/bash
# SMTP-Tunnel Universal Installer - FIXED VERSION
# One script for both Server and Client - Production Ready

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
║                                                              ║
║              SMTP-Tunnel - Universal Installer               ║
║                    Fixed Version - Production                ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check system requirements
check_requirements() {
    echo -e "${YELLOW}🔍 Checking system requirements...${NC}"
    
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
    
    # Check disk space
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 1048576 ]; then
        echo -e "${RED}❌ Insufficient disk space (need at least 1GB)${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ System requirements met${NC}"
}

# Detect environment with multiple methods
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
    
    # Method 2: Check if running in Iran
    LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
    
    # Iran IP ranges
    if [[ $LOCAL_IP =~ ^10\. ]] || \
       [[ $LOCAL_IP =~ ^172\.(1[6-9]|2[0-9]|3[0-1]) ]] || \
       [[ $LOCAL_IP =~ ^192\.168\. ]] || \
       [[ $LOCAL_IP =~ ^5\.(2[2-9]|5[2-9]|1[0-9]|200|20[1-7]|24[8-9]|25[0-1]) ]]; then
        echo -e "${GREEN}✓ Detected: CLIENT mode (Iran IP range)${NC}"
        return 0
    fi
    
    # Method 3: Check if public IP is from Iran
    if command -v curl &> /dev/null; then
        PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || echo "")
        if [ -n "$PUBLIC_IP" ]; then
            IP_INFO=$(curl -s --connect-timeout 3 "http://ip-api.com/line/${PUBLIC_IP}?fields=countryCode" 2>/dev/null || echo "")
            if [ "$IP_INFO" = "IR" ]; then
                echo -e "${GREEN}✓ Detected: CLIENT mode (Public IP in Iran)${NC}"
                return 0
            fi
        fi
    fi
    
    # Method 4: Check if it's a VPS (has public IP and not in Iran)
    if [ -n "$PUBLIC_IP" ] && [ "$IP_INFO" != "IR" ]; then
        echo -e "${GREEN}✓ Detected: SERVER mode (VPS outside Iran)${NC}"
        return 1
    fi
    
    # Method 5: Ask user if detection fails
    echo -e "${YELLOW}⚠️  Could not auto-detect environment${NC}"
    echo ""
    echo -e "Where are you installing this?"
    echo -e "  ${CYAN}1)${NC} Server (VPS outside Iran) - I want to host the tunnel"
    echo -e "  ${CYAN}2)${NC} Client (Inside Iran) - I want to bypass DPI"
    echo -e "  ${CYAN}3)${NC} Both (Local testing only)"
    echo ""
    read -p "Enter choice (1-3): " ENV_CHOICE
    
    case $ENV_CHOICE in
        1) return 1 ;;
        2) return 0 ;;
        3) return 2 ;;
        *) return 0 ;;
    esac
}

# Install Go properly
install_go() {
    echo -e "${YELLOW}📦 Installing Go 1.22.5...${NC}"
    
    # Remove old Go
    rm -rf /usr/local/go
    
    # Download and install Go
    cd /tmp
    wget -q https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to download Go${NC}"
        exit 1
    fi
    
    tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
    
    # Set up Go environment
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
    export PATH=$PATH:/usr/local/go/bin
    
    # Verify installation
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
    
    # Clone repository
    git clone https://github.com/3x-code/SMTP-Tunnel.git
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to clone repository${NC}"
        exit 1
    fi
    
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
    
    # Check if domain is IP address
    if [[ $DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${YELLOW}Using self-signed certificate for IP...${NC}"
        openssl req -x509 -newkey rsa:2048 \
            -keyout /etc/smtp-tunnel/certs/server.key \
            -out /etc/smtp-tunnel/certs/server.crt \
            -days 365 -nodes \
            -subj "/CN=${DOMAIN}" 2>/dev/null
    else
        # Try Let's Encrypt if certbot is available
        if command -v certbot &> /dev/null; then
            echo -e "${YELLOW}Attempting Let's Encrypt SSL...${NC}"
            systemctl stop apache2 nginx 2>/dev/null || true
            certbot certonly --standalone \
                --non-interactive \
                --agree-tos \
                --email "${EMAIL}" \
                -d "${DOMAIN}" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" /etc/smtp-tunnel/certs/server.crt
                cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" /etc/smtp-tunnel/certs/server.key
                echo -e "${GREEN}✓ Let's Encrypt SSL certificate obtained${NC}"
            else
                echo -e "${YELLOW}Let's Encrypt failed, using self-signed...${NC}"
                openssl req -x509 -newkey rsa:2048 \
                    -keyout /etc/smtp-tunnel/certs/server.key \
                    -out /etc/smtp-tunnel/certs/server.crt \
                    -days 365 -nodes \
                    -subj "/CN=${DOMAIN}" 2>/dev/null
            fi
        else
            echo -e "${YELLOW}Certbot not found, using self-signed certificate...${NC}"
            openssl req -x509 -newkey rsa:2048 \
                -keyout /etc/smtp-tunnel/certs/server.key \
                -out /etc/smtp-tunnel/certs/server.crt \
                -days 365 -nodes \
                -subj "/CN=${DOMAIN}" 2>/dev/null
        fi
    fi
    
    chmod 600 /etc/smtp-tunnel/certs/server.key
    echo -e "${GREEN}✓ SSL certificate setup complete${NC}"
}

# Install server
install_server() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🖥️  Installing SMTP-Tunnel SERVER...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Server installation requires root privileges${NC}"
        exit 1
    fi
    
    # Install dependencies
    echo -e "${YELLOW}📦 Installing system dependencies...${NC}"
    apt update -qq
    apt install -y -qq wget curl git openssl ufw
    
    # Install Go
    install_go
    
    # Build server
    build_server
    
    # Get server configuration
    echo ""
    echo -e "${GREEN}📋 Server Configuration${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "Enter your server domain or IP: " SERVER_DOMAIN
    read -p "Enter your email (for SSL): " SSL_EMAIL
    read -p "Enter username for client: " CLIENT_USERNAME
    
    # Generate random secret if not provided
    CLIENT_SECRET=$(openssl rand -hex 16)
    echo -e "${YELLOW}Generated secret key: ${GREEN}${CLIENT_SECRET}${NC}"
    echo -e "${YELLOW}Please save this secret!${NC}"
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
    
    # Create systemd service
    echo -e "${YELLOW}⚙️  Creating systemd service...${NC}"
    cat > /etc/systemd/system/smtp-tunnel-server.service << EOF
[Unit]
Description=SMTP-Tunnel Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/SMTP-Tunnel
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
    ufw allow 22/tcp comment 'SSH' 2>/dev/null
    ufw allow 587/tcp comment 'SMTP-Tunnel' 2>/dev/null
    ufw --force enable 2>/dev/null || true
    
    # Start service
    systemctl daemon-reload
    systemctl enable smtp-tunnel-server
    systemctl start smtp-tunnel-server
    
    # Wait for service to start
    sleep 3
    
    if systemctl is-active --quiet smtp-tunnel-server; then
        echo -e "${GREEN}✅ Server service started successfully${NC}"
    else
        echo -e "${RED}❌ Server service failed to start${NC}"
        journalctl -u smtp-tunnel-server -n 20 --no-pager
        exit 1
    fi
    
    # Generate client command
    CLIENT_CMD="curl -sSL https://raw.githubusercontent.com/3x-code/SMTP-Tunnel/main/scripts/install-universal-fixed.sh | bash -s client ${SERVER_DOMAIN} ${CLIENT_USERNAME} ${CLIENT_SECRET}"
    
    echo -e "${GREEN}✅ SERVER INSTALLATION COMPLETE!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🌍 Server: ${GREEN}${SERVER_DOMAIN}:587${NC}"
    echo -e "👤 Username: ${GREEN}${CLIENT_USERNAME}${NC}"
    echo -e "🔑 Secret: ${GREEN}${CLIENT_SECRET}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📋 CLIENT INSTALLATION COMMAND:${NC}"
    echo -e "${CYAN}${CLIENT_CMD}${NC}"
    echo ""
    echo -e "${CLIENT_CMD}" > /root/client-install-command.txt
    echo -e "${YELLOW}Client command saved to: /root/client-install-command.txt${NC}"
}

# Install client
install_client() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}💻  Installing SMTP-Tunnel CLIENT...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get parameters
    local SERVER=""
    local USERNAME=""
    local SECRET=""
    
    if [ "$1" = "client" ] && [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ]; then
        SERVER="$2"
        USERNAME="$3"
        SECRET="$4"
    else
        echo -e "${GREEN}📋 Client Configuration${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -p "Enter your server IP/domain: " SERVER
        read -p "Enter username: " USERNAME
        read -s -p "Enter secret key: " SECRET
        echo ""
    fi
    
    # Detect ISP
    echo -e "${YELLOW}📱 Detecting Iranian ISP...${NC}"
    
    # Try multiple methods to get public IP
    PUBLIC_IP=""
    if command -v curl &> /dev/null; then
        PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null || curl -s --connect-timeout 3 icanhazip.com 2>/dev/null || echo "")
    fi
    
    ISP="auto"
    ISP_NAME="Unknown"
    STRATEGY="balanced"
    BEST_SERVER="$SERVER"
    
    if [[ $PUBLIC_IP =~ ^5\.(2[2-9]|5[2-9]|1[0-9]|200|20[1-7]|24[8-9]|25[0-1]) ]]; then
        ISP="mci"
        ISP_NAME="MCI (Hamrah Aval)"
        STRATEGY="paranoid"
        BEST_SERVER="${SERVER:-istanbul.smtp-tunnel.3x-code.ir}"
        echo -e "${GREEN}✓ Detected: MCI (Hamrah Aval)${NC}"
    elif [[ $PUBLIC_IP =~ ^5\.(200|201|202|203|204|205|206|207) ]]; then
        ISP="mtn"
        ISP_NAME="MTN (Irancell)"
        STRATEGY="balanced"
        BEST_SERVER="${SERVER:-yerevan.smtp-tunnel.3x-code.ir}"
        echo -e "${GREEN}✓ Detected: MTN (Irancell)${NC}"
    elif [[ $PUBLIC_IP =~ ^5\.(248|249|250|251) ]]; then
        ISP="rightel"
        ISP_NAME="Rightel"
        STRATEGY="paranoid"
        BEST_SERVER="${SERVER:-baku.smtp-tunnel.3x-code.ir}"
        echo -e "${GREEN}✓ Detected: Rightel${NC}"
    else
        echo -e "${YELLOW}✓ Using default configuration${NC}"
    fi
    
    # Download client binary
    echo -e "${YELLOW}📦 Downloading client binary...${NC}"
    cd /tmp
    
    # Get latest release
    LATEST_VERSION="v0.2.0"
    if command -v curl &> /dev/null; then
        LATEST_VERSION=$(curl -s --connect-timeout 5 "https://api.github.com/repos/3x-code/SMTP-Tunnel/releases/latest" | grep '"tag_name":' | head -1 | cut -d'"' -f4 || echo "v0.2.0")
    fi
    
    # Download with fallback
    curl -L --connect-timeout 10 \
        -o smtp-tunnel-client.tar.gz \
        "https://github.com/3x-code/SMTP-Tunnel/releases/download/${LATEST_VERSION}/smtp-tunnel-client-${LATEST_VERSION}-linux_amd64.tar.gz" || {
        echo -e "${YELLOW}Download failed, using v0.2.0...${NC}"
        curl -L --connect-timeout 10 \
            -o smtp-tunnel-client.tar.gz \
            "https://github.com/3x-code/SMTP-Tunnel/releases/download/v0.2.0/smtp-tunnel-client-v0.2.0-linux_amd64.tar.gz"
    }
    
    if [ ! -f "smtp-tunnel-client.tar.gz" ]; then
        echo -e "${RED}❌ Failed to download client binary${NC}"
        exit 1
    fi
    
    # Extract and install
    tar xzf smtp-tunnel-client.tar.gz
    if [ ! -f "smtp-tunnel" ]; then
        echo -e "${RED}❌ Invalid client package${NC}"
        exit 1
    fi
    
    cp smtp-tunnel /usr/local/bin/
    chmod +x /usr/local/bin/smtp-tunnel
    
    echo -e "${GREEN}✓ Client binary installed${NC}"
    
    # Create client config
    echo -e "${YELLOW}📝 Creating client configuration...${NC}"
    mkdir -p /etc/smtp-tunnel
    mkdir -p /var/log/smtp-tunnel
    
    cat > /etc/smtp-tunnel/client.yaml << EOF
server:
  host: ${BEST_SERVER}
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
  isp: ${ISP}
  strategy: ${STRATEGY}
  port_hopping: true
  sni_fronting: true
  multipath: false
  min_delay: 50
  max_delay: 500

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
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    # Start service
    systemctl daemon-reload
    systemctl enable smtp-tunnel-client
    systemctl start smtp-tunnel-client
    
    # Wait for service to start
    sleep 3
    
    if systemctl is-active --quiet smtp-tunnel-client; then
        echo -e "${GREEN}✅ Client service started successfully${NC}"
    else
        echo -e "${RED}❌ Client service failed to start${NC}"
        journalctl -u smtp-tunnel-client -n 20 --no-pager
    fi
    
    echo -e "${GREEN}✅ CLIENT INSTALLATION COMPLETE!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🌍 Server: ${GREEN}${BEST_SERVER}:587${NC}"
    echo -e "👤 Username: ${GREEN}${USERNAME}${NC}"
    echo -e "🔌 SOCKS5 Proxy: ${GREEN}127.0.0.1:1080${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📋 Test the proxy:${NC}"
    echo -e "  curl --socks5 127.0.0.1:1080 https://www.google.com"
    echo ""
    echo -e "${YELLOW}📋 View logs:${NC}"
    echo -e "  journalctl -u smtp-tunnel-client -f"
}

# Main execution
main() {
    print_banner
    check_requirements
    
    # Check command line arguments
    if [ "$1" = "server" ]; then
        install_server
    elif [ "$1" = "client" ]; then
        install_client "$@"
    else
        # Auto-detect
        detect_environment "$1"
        ENV_TYPE=$?
        
        case $ENV_TYPE in
            0) install_client ;;
            1) install_server ;;
            2) 
                echo -e "${YELLOW}Installing both server and client for local testing...${NC}"
                install_server
                install_client "client" "127.0.0.1" "$CLIENT_USERNAME" "$CLIENT_SECRET"
                ;;
        esac
    fi
}

# Run main function with all arguments
main "$@"
