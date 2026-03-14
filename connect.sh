#!/usr/bin/env bash
set -Eeuo pipefail

# SSH tunnel + open Jupyter in browser.
# Run this on your LOCAL machine (e.g. Mac).
#
# Usage:
#   bash connect.sh user@server_ip
#   bash connect.sh user@server_ip 8888
#   bash connect.sh user@server_ip 8888 ~/.ssh/id_rsa

HOST="${1:?Usage: bash connect.sh user@host [port] [ssh_key]}"
PORT="${2:-8888}"
SSH_KEY="${3:-}"

SSH_OPTS="-o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=3"

if [[ -n "$SSH_KEY" ]]; then
  SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

cleanup() {
  echo ""
  echo "Tunnel closed."
}
trap cleanup EXIT

# Kill any existing tunnel on this port
lsof -ti:"$PORT" 2>/dev/null | xargs kill -9 2>/dev/null || true

echo "Opening SSH tunnel: localhost:${PORT} -> ${HOST}:${PORT}"
echo "Jupyter will be available at: http://localhost:${PORT}"
echo ""
echo "Press Ctrl+C to close the tunnel."
echo ""

# Open browser after a short delay
(sleep 2 && open "http://localhost:${PORT}" 2>/dev/null || xdg-open "http://localhost:${PORT}" 2>/dev/null) &

# Forward port and keep connection alive
ssh $SSH_OPTS -N -L "${PORT}:localhost:${PORT}" "$HOST"
