#!/bin/sh
set -e

# Docker entrypoint for SMTP-Tunnel Client

if [ -z "$SERVER_HOST" ] || [ -z "$USERNAME" ] || [ -z "$SECRET" ]; then
    echo "Error: SERVER_HOST, USERNAME, and SECRET must be set"
    exit 1
fi

SERVER_PORT=${SERVER_PORT:-587}
ISP=${ISP:-auto}
STRATEGY=${STRATEGY:-balanced}

exec /usr/local/bin/smtp-tunnel-client \
    --server "${SERVER_HOST}:${SERVER_PORT}" \
    --username "${USERNAME}" \
    --secret "${SECRET}" \
    --isp "${ISP}" \
    --strategy "${STRATEGY}"
