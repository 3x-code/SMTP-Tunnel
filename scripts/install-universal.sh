#!/bin/bash
# SMTP-Tunnel Universal Installer
# One script for both Server and Client - Auto-detects environment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ASCII Art Banner
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║     ███████  ████   █████ ██████  ████████ ██   ██ ████       ║
║     ██      ██  ██ ██     ██   ██    ██    ██   ██ ██  ██     ║
║     █████   ██████ ██     ██████     ██    ██   ██ ██  ██     ║
║     ██      ██  ██ ██     ██   ██    ██    ██   ██ ██  ██     ║
║     ██      ██  ██  █████ ██   ██    ██    ███████ ████       ║
║                                                              ║
║              SMTP-Tunnel - Universal Installer              ║
║                    One Script for Everything                ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Auto-detect environment
detect_environment() {
    echo -e "${YELLOW}🔍 Detecting environment...${NC}"
    
    # Check if running on VPS (outside Iran)
    PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me || echo "")
    COUNTRY=$(curl -s --max-time 5 http://ip-api.com/line/${PUBLIC_IP}?fields=countryCode 2>/dev/null || echo "")
    
    # Check if it's a VPS (no ISP detection means it's likely a VPS)
    if [[ "$COUNTRY" != "IR" ]] && [[ -n "$COUNTRY" ]]; then
        echo -e "${GREEN}✓ Environment: SERVER (Outside Iran - $COUNTRY)${NC}"
        return 1  # Server mode
    elif [[ "$PUBLIC_IP" =~ ^5\. ]] || [[ "$PUBLIC_IP" =~ ^10\. ]] || [[ "$PUBLIC_IP" =~ ^172\. ]] || [[ "$PUBLIC_IP" =~ ^192\.168\. ]]; then
        echo -e "${GREEN}✓ Environment: CLIENT (Inside Iran)${NC}"
        return 0  # Client mode
    else
        # Ask user if detection fails
        echo -e "${YELLOW}⚠️  Could not auto-detect environment${NC}"
        echo ""
        echo -e "Where are you installing this?"
        echo -e "  ${CYAN}1)${NC} VPS/Server (Outside Iran) - I have a public IP"
        echo -e "  ${CYAN}2)${NC} Client (Inside Iran) - I want to bypass DPI"
        echo -e "  ${CYAN}3)${NC} Both - Install complete system locally (testing)"
        echo ""
        read -p "Enter choice (1-3): " ENV_CHOICE
        
        case $ENV_CHOICE in
            1) return 1 ;;  # Server
            2) return 0 ;;  # Client
            3) return 2 ;;  # Both
            *) return 0 ;;  # Default to client
        esac
    fi
}

# Install Server (VPS outside Iran)
install_server() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🖥️  Installing SMTP-Tunnel SERVER...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check root
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}❌ Server installation requires root privileges${NC}"
        echo -e "Please run: sudo $0"
        exit 1
    fi
    
    # Get server configuration
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📋 Server Configuration${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "Enter your server domain or IP: " SERVER_DOMAIN
    read -p "Enter your email for SSL (Let's Encrypt): " SSL_EMAIL
    read -p "Enter username for client: " CLIENT_USERNAME
    read -s -p "Enter secret key for client: " CLIENT_SECRET
    echo ""
    read -s -p "Confirm secret key: " CLIENT_SECRET_CONFIRM
    echo ""
    
    if [ "$CLIENT_SECRET" != "$CLIENT_SECRET_CONFIRM" ]; then
        echo -e "${RED}❌ Secrets don't match!${NC}"
        exit 1
    fi
    
    # Install dependencies
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    apt update -y
    apt install -y wget curl git ufw fail2ban certbot
    
    # Install Go
    echo -e "${YELLOW}🔧 Installing Go 1.22.5...${NC}"
    wget -q https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    
    # Build server
    echo -e "${YELLOW}🔨 Building server binary...${NC}"
    cd /root
    rm -rf SMTP-Tunnel
    git clone https://github.com/3x-code/SMTP-Tunnel.git
    cd SMTP-Tunnel
    go mod init github.com/3x-code/SMTP-Tunnel 2>/dev/null || true
    go mod tidy
    go build -buildvcs=false -ldflags="-s -w -X main.version=v0.2.0" -o smtp-tunnel-server ./cmd/server
    
    if [ ! -f "smtp-tunnel-server" ]; then
        echo -e "${RED}❌ Build failed!${NC}"
        exit 1
    fi
    
    cp smtp-tunnel-server /usr/local/bin/
    chmod +x /usr/local/bin/smtp-tunnel-server
    
    # Setup SSL
    echo -e "${YELLOW}🔐 Setting up SSL certificate...${NC}"
    mkdir -p /etc/smtp-tunnel/certs
    
    if [[ $SERVER_DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${YELLOW}Using self-signed certificate for IP...${NC}"
        openssl req -x509 -newkey rsa:4096 \
            -keyout /etc/smtp-tunnel/certs/server.key \
            -out /etc/smtp-tunnel/certs/server.crt \
            -days 365 -nodes \
            -subj "/CN=$SERVER_DOMAIN"
    else
        echo -e "${YELLOW}Attempting Let's Encrypt SSL...${NC}"
        systemctl stop apache2 nginx 2>/dev/null || true
        if certbot certonly --standalone \
            --non-interactive \
            --agree-tos \
            --email "$SSL_EMAIL" \
            -d "$SERVER_DOMAIN"; then
            cp "/etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem" /etc/smtp-tunnel/certs/server.crt
            cp "/etc/letsencrypt/live/$SERVER_DOMAIN/privkey.pem" /etc/smtp-tunnel/certs/server.key
            echo "0 0 * * * root certbot renew --quiet && systemctl restart smtp-tunnel-server" > /etc/cron.d/certbot-renew
        else
            echo -e "${YELLOW}Let's Encrypt failed, using self-signed...${NC}"
            openssl req -x509 -newkey rsa:4096 \
                -keyout /etc/smtp-tunnel/certs/server.key \
                -out /etc/smtp-tunnel/certs/server.crt \
                -days 365 -nodes \
                -subj "/CN=$SERVER_DOMAIN"
        fi
    fi
    
    chmod 600 /etc/smtp-tunnel/certs/server.key
    
    # Create server config
    echo -e "${YELLOW}📝 Creating server configuration...${NC}"
    mkdir -p /etc/smtp-tunnel
    mkdir -p /var/log/smtp-tunnel
    
    cat > /etc/smtp-tunnel/server.yaml << EOF
server:
  host: 0.0.0.0
  port: 587
  hostname: $SERVER_DOMAIN

tls:
  cert_file: /etc/smtp-tunnel/certs/server.crt
  key_file: /etc/smtp-tunnel/certs/server.key

users:
  $CLIENT_USERNAME:
    secret: "$CLIENT_SECRET"
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
    ufw allow 22/tcp comment 'SSH'
    ufw allow 587/tcp comment 'SMTP-Tunnel'
    ufw --force enable
    
    # Start service
    systemctl daemon-reload
    systemctl enable smtp-tunnel-server
    systemctl start smtp-tunnel-server
    
    # Generate client command
    CLIENT_CMD="curl -sSL https://raw.githubusercontent.com/3x-code/SMTP-Tunnel/main/scripts/install-universal.sh | bash -s client $SERVER_DOMAIN $CLIENT_USERNAME $CLIENT_SECRET"
    
    echo -e "${GREEN}✅ SERVER INSTALLATION COMPLETE!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🌍 Server: ${GREEN}$SERVER_DOMAIN:587${NC}"
    echo -e "👤 Username: ${GREEN}$CLIENT_USERNAME${NC}"
    echo -e "🔑 Secret: ${GREEN}$CLIENT_SECRET${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📋 CLIENT INSTALLATION COMMAND (run inside Iran):${NC}"
    echo -e "${CYAN}$CLIENT_CMD${NC}"
    echo ""
    
    # Save client command to file
    echo "$CLIENT_CMD" > /root/client-install-command.txt
    echo -e "${YELLOW}Client command saved to: /root/client-install-command.txt${NC}"
}

# Install Client (Inside Iran)
install_client() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}💻  Installing SMTP-Tunnel CLIENT...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Get parameters from command line or prompt
    if [ "$1" == "client" ] && [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ]; then
        SERVER="$2"
        USERNAME="$3"
        SECRET="$4"
    else
        read -p "Enter your server IP/domain: " SERVER
        read -p "Enter username: " USERNAME
        read -s -p "Enter secret key: " SECRET
        echo ""
    fi
    
    # Detect ISP
    echo -e "${YELLOW}📱 Detecting Iranian ISP...${NC}"
    PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me || echo "")
    
    if [[ $PUBLIC_IP =~ ^5\.(22|52|53|54|55|56|57|58|59)\. ]]; then
        ISP="mci"
        ISP_NAME="MCI (Hamrah Aval)"
        STRATEGY="paranoid"
        BEST_SERVER="istanbul.smtp-tunnel.3x-code.ir"
    elif [[ $PUBLIC_IP =~ ^5\.(200|201|202|203|204|205|206|207)\. ]]; then
        ISP="mtn"
        ISP_NAME="MTN (Irancell)"
        STRATEGY="balanced"
        BEST_SERVER="yerevan.smtp-tunnel.3x-code.ir"
    elif [[ $PUBLIC_IP =~ ^5\.(248|249|250|251)\. ]]; then
        ISP="rightel"
        ISP_NAME="Rightel"
        STRATEGY="paranoid"
        BEST_SERVER="baku.smtp-tunnel.3x-code.ir"
    else
        ISP="auto"
        ISP_NAME="Unknown/Other"
        STRATEGY="balanced"
        BEST_SERVER="$SERVER"
    fi
    
    echo -e "${GREEN}✓ ISP: $ISP_NAME${NC}"
    echo -e "${GREEN}✓ Strategy: $STRATEGY${NC}"
    
    # Download client
    echo -e "${YELLOW}📦 Downloading client binary...${NC}"
    cd /tmp
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/3x-code/SMTP-Tunnel/releases/latest" | grep '"tag_name":' | cut -d'"' -f4)
    LATEST_VERSION=${LATEST_VERSION:-v0.2.0}
    
    curl -L -o smtp-tunnel-client.tar.gz \
        "https://github.com/3x-code/SMTP-Tunnel/releases/download/${LATEST_VERSION}/smtp-tunnel-client-${LATEST_VERSION}-linux_amd64.tar.gz"
    
    tar xzf smtp-tunnel-client.tar.gz
    cp smtp-tunnel /usr/local/bin/
    chmod +x /usr/local/bin/smtp-tunnel
    
    # Create client config
    echo -e "${YELLOW}📝 Creating client configuration...${NC}"
    mkdir -p /etc/smtp-tunnel
    mkdir -p /var/log/smtp-tunnel
    
    cat > /etc/smtp-tunnel/client.yaml << EOF
server:
  host: $BEST_SERVER
  port: 587
  fallback_ports:
    - 465
    - 2525
    - 25

auth:
  username: $USERNAME
  secret: "$SECRET"

socks:
  host: 127.0.0.1
  port: 1080

bypass:
  isp: $ISP
  strategy: $STRATEGY
  port_hopping: true
  sni_fronting: true
  multipath: false
  fragmentation: false
  dummy_traffic: true
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
    
    echo -e "${GREEN}✅ CLIENT INSTALLATION COMPLETE!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🌍 Server: ${GREEN}$BEST_SERVER:587${NC}"
    echo -e "👤 Username: ${GREEN}$USERNAME${NC}"
    echo -e "🔌 SOCKS5: ${GREEN}127.0.0.1:1080${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Install Both (Testing/Local)
install_both() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🖥️  Installing SMTP-Tunnel BOTH (Server + Client)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Install server first
    install_server
    
    # Then install client connecting to localhost
    install_client "client" "127.0.0.1" "$CLIENT_USERNAME" "$CLIENT_SECRET"
}

# Main execution
main() {
    # Check for command line arguments
    if [ "$1" == "server" ]; then
        install_server
    elif [ "$1" == "client" ]; then
        install_client "$@"
    elif [ "$1" == "both" ]; then
        install_both
    else
        # Auto-detect
        detect_environment
        ENV_TYPE=$?
        
        case $ENV_TYPE in
            0) install_client ;;
            1) install_server ;;
            2) install_both ;;
        esac
    fi
}

main "$@"
