#!/bin/bash
# SMTP-Tunnel Server Auto-Deployment Script
# Run this on your VPS (Ubuntu 22.04/24.04)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  SMTP-Tunnel Server Auto-Deployer${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Get user input
read -p "Enter your domain (or VPS IP): " DOMAIN
read -p "Enter server hostname [mail.$DOMAIN]: " HOSTNAME
HOSTNAME=${HOSTNAME:-mail.$DOMAIN}
read -p "Enter admin email for SSL: " EMAIL
read -p "Enter username for client: " USERNAME
read -s -p "Enter secret key for client: " SECRET
echo ""

echo -e "${YELLOW}Step 1: Installing dependencies...${NC}"
apt update
apt install -y golang-go git ufw fail2ban certbot

echo -e "${YELLOW}Step 2: Setting up Go...${NC}"
wget -q https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
export PATH=$PATH:/usr/local/go/bin

echo -e "${YELLOW}Step 3: Building server...${NC}"
cd /root
git clone https://github.com/3x-code/SMTP-Tunnel.git
cd SMTP-Tunnel
go mod init github.com/3x-code/SMTP-Tunnel 2>/dev/null || true
go get github.com/fatih/color@v1.18.0
go mod tidy
go build -buildvcs=false -ldflags="-s -w" -o smtp-tunnel-server ./cmd/server

echo -e "${YELLOW}Step 4: Setting up SSL certificate...${NC}"
mkdir -p /etc/smtp-tunnel/certs
if [ "$DOMAIN" != "$(hostname -I | awk '{print $1}')" ]; then
    certbot certonly --standalone --non-interactive --agree-tos -d $DOMAIN -m $EMAIL
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/smtp-tunnel/certs/server.crt
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/smtp-tunnel/certs/server.key
    SSL_MODE="cert"
else
    openssl req -x509 -newkey rsa:4096 -keyout /etc/smtp-tunnel/certs/server.key \
        -out /etc/smtp-tunnel/certs/server.crt -days 365 -nodes \
        -subj "/CN=$DOMAIN"
    SSL_MODE="cert"
fi

echo -e "${YELLOW}Step 5: Creating server configuration...${NC}"
mkdir -p /etc/smtp-tunnel
cat > /etc/smtp-tunnel/server.yaml << EOF
server:
  host: 0.0.0.0
  port: 587
  hostname: $HOSTNAME

tls:
  mode: $SSL_MODE
  cert_file: /etc/smtp-tunnel/certs/server.crt
  key_file: /etc/smtp-tunnel/certs/server.key
  domain: $DOMAIN
  email: $EMAIL

users:
  $USERNAME:
    secret: "$SECRET"
    whitelist: []
    logging: true

logging:
  level: info
  file: /var/log/smtp-tunnel/server.log
EOF

echo -e "${YELLOW}Step 6: Setting up systemd service...${NC}"
cat > /etc/systemd/system/smtp-tunnel-server.service << EOF
[Unit]
Description=SMTP-Tunnel Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/SMTP-Tunnel
ExecStart=/root/SMTP-Tunnel/smtp-tunnel-server -config /etc/smtp-tunnel/server.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo -e "${YELLOW}Step 7: Configuring firewall...${NC}"
ufw allow 22/tcp comment 'SSH'
ufw allow 587/tcp comment 'SMTP-Tunnel'
ufw --force enable

echo -e "${YELLOW}Step 8: Starting server...${NC}"
systemctl daemon-reload
systemctl enable smtp-tunnel-server
systemctl start smtp-tunnel-server

echo -e "${GREEN}✅ Server deployment complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "Server: $DOMAIN:587"
echo -e "Username: $USERNAME"
echo -e "Secret: $SECRET"
echo -e ""
echo -e "Run this on client:"
echo -e "${YELLOW}curl -sSL https://raw.githubusercontent.com/3x-code/SMTP-Tunnel/main/scripts/deploy-client.sh | bash -s $DOMAIN $USERNAME $SECRET${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
