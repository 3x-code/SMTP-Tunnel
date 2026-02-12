#!/bin/bash
# SMTP-Tunnel Client Auto-Deployment Script
# Run this inside Iran

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVER=$1
USERNAME=$2
SECRET=$3

if [ -z "$SERVER" ] || [ -z "$USERNAME" ] || [ -z "$SECRET" ]; then
    echo -e "${RED}Usage: $0 <server-ip> <username> <secret>${NC}"
    exit 1
fi

echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  SMTP-Tunnel Client Auto-Deployer${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

# Install binary
echo -e "${YELLOW}Installing SMTP-Tunnel client...${NC}"
curl -sSL https://raw.githubusercontent.com/3x-code/SMTP-Tunnel/main/scripts/install.sh | bash

# Create config directory
mkdir -p /etc/smtp-tunnel

# Detect ISP
ISP="auto"
if curl -s ifconfig.co | grep -q "5."; then
    if curl -s ifconfig.co | grep -q "5.22\|5.52\|5.53\|5.54\|5.55\|5.56\|5.57\|5.58\|5.59"; then
        ISP="mci"
    elif curl -s ifconfig.co | grep -q "5.200\|5.201\|5.202\|5.203\|5.204\|5.205\|5.206\|5.207"; then
        ISP="mtn"
    elif curl -s ifconfig.co | grep -q "5.248\|5.249\|5.250\|5.251"; then
        ISP="rightel"
    fi
fi

# Create client config
cat > /etc/smtp-tunnel/client.yaml << EOF
server:
  host: $SERVER
  port: 587
  fallback_ports:
    - 465
    - 2525

auth:
  username: $USERNAME
  secret: "$SECRET"

socks:
  host: 127.0.0.1
  port: 1080

bypass:
  isp: $ISP
  strategy: balanced
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

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl daemon-reload
systemctl enable smtp-tunnel-client
systemctl start smtp-tunnel-client

echo -e "${GREEN}✅ Client deployment complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "SOCKS5 Proxy: 127.0.0.1:1080"
echo -e "Status: ${YELLOW}systemctl status smtp-tunnel-client${NC}"
echo -e "Logs: ${YELLOW}journalctl -u smtp-tunnel-client -f${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
