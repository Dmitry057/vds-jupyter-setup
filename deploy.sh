#!/usr/bin/env bash
set -Eeuo pipefail

# One-command Jupyter deployment: install env + port-forward + get URL.
# Run on your LOCAL machine.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/deploy.sh) <IP> <ENV>
#
#   ENV options:
#     1 | robotics  — ROS2, gymnasium, mujoco, torch
#     2 | nlp       — transformers, spacy, nltk, torch
#     3 | ml        — scikit-learn, xgboost, lightgbm, torch
#
# Examples:
#   bash deploy.sh 158.160.42.69 1
#   bash deploy.sh 158.160.42.69 nlp

REPO_URL="https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main"
KEY_PATH="$HOME/.ssh/Ключевая_пара_finetuning.pem"
SSH_USER="ubuntu"
PORT=8888
STATE_FILE="$HOME/.ssh/.immers_ip"

# ─── helpers ────────────────────────────────────────────────────────
log()  { printf '\n\033[1;34m[%s] %s\033[0m\n' "$(date +'%T')" "$*"; }
ok()   { printf '\033[1;32m[OK] %s\033[0m\n' "$*"; }
err()  { printf '\033[1;31m[ERROR] %s\033[0m\n' "$*" >&2; exit 1; }

# ─── args ───────────────────────────────────────────────────────────
IP="${1:-}"
ENV_CHOICE="${2:-}"

if [[ -z "$IP" ]]; then
  # Try saved IP
  if [[ -f "$STATE_FILE" ]]; then
    SAVED_IP=$(cat "$STATE_FILE")
    read -p "Server IP [${SAVED_IP}]: " IP
    IP="${IP:-$SAVED_IP}"
  else
    read -p "Server IP: " IP
  fi
fi

if [[ -z "$IP" ]]; then
  err "Server IP is required"
fi

if [[ -z "$ENV_CHOICE" ]]; then
  cat <<'MENU'

Choose environment:
  1) robotics  — ROS2, gymnasium, mujoco, torch
  2) nlp       — transformers, spacy, nltk, torch
  3) ml        — scikit-learn, xgboost, lightgbm, torch

MENU
  read -p "Enter choice (1-3): " ENV_CHOICE
fi

case "$ENV_CHOICE" in
  1|robotics)  SCRIPT="setup_jupyter_robotics.sh"; ENV_NAME="robotics" ;;
  2|nlp)       SCRIPT="setup_jupyter_nlp.sh";      ENV_NAME="nlp" ;;
  3|ml)        SCRIPT="setup_jupyter_ml.sh";        ENV_NAME="ml" ;;
  *)           err "Unknown environment: $ENV_CHOICE" ;;
esac

# Save IP for future use
mkdir -p "$(dirname "$STATE_FILE")"
echo "$IP" > "$STATE_FILE"

# ─── SSH options ────────────────────────────────────────────────────
SSH_OPTS=(-i "$KEY_PATH" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=3)
SSH_TARGET="${SSH_USER}@${IP}"

ssh_cmd() {
  ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "$@"
}

# ─── cleanup ────────────────────────────────────────────────────────
TUNNEL_PID=""
cleanup() {
  if [[ -n "$TUNNEL_PID" ]]; then
    kill "$TUNNEL_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ─── step 1: install environment on server ──────────────────────────
log "Installing '$ENV_NAME' environment on $IP ..."

ssh_cmd "bash -s" <<REMOTE
  set -e
  if [ -f "\$HOME/jupyter-venv/bin/activate" ]; then
    echo "[INFO] Virtual environment already exists, checking kernel..."
    source "\$HOME/jupyter-venv/bin/activate"
    if python -c "import jupyterlab" 2>/dev/null; then
      echo "[INFO] Environment already set up. Skipping installation."
      exit 0
    fi
  fi
  echo "[INFO] Downloading and running $SCRIPT ..."
  curl -fsSL "$REPO_URL/$SCRIPT" | bash
REMOTE

ok "Environment '$ENV_NAME' installed"

# ─── step 2: kill old jupyter, start new one ────────────────────────
log "Starting Jupyter on server ..."

ssh_cmd "bash -s" <<REMOTE
  # Kill any existing Jupyter
  pkill -f "jupyter-lab" 2>/dev/null || true
  sleep 1

  source "\$HOME/jupyter-venv/bin/activate"
  mkdir -p "\$HOME/notebooks"
  cd "\$HOME/notebooks"

  # Start Jupyter in background, log to file
  nohup jupyter lab --ip=0.0.0.0 --port=${PORT} --port-retries=0 --no-browser \
    > "\$HOME/.jupyter_output.log" 2>&1 &

  # Wait for Jupyter to start and print token
  for i in \$(seq 1 30); do
    if grep -q "token=" "\$HOME/.jupyter_output.log" 2>/dev/null; then
      break
    fi
    sleep 1
  done
REMOTE

ok "Jupyter started on server"

# ─── step 3: get the token URL ──────────────────────────────────────
log "Fetching Jupyter token ..."

REMOTE_URL=$(ssh_cmd "grep -oP 'http://127\.0\.0\.1:\d+/lab\?token=\S+' \$HOME/.jupyter_output.log 2>/dev/null | head -1")

if [[ -z "$REMOTE_URL" ]]; then
  # Fallback: try broader grep
  REMOTE_URL=$(ssh_cmd "grep -o 'http://[^ ]*token=[^ ]*' \$HOME/.jupyter_output.log 2>/dev/null | tail -1")
fi

if [[ -z "$REMOTE_URL" ]]; then
  err "Could not find Jupyter token. Check server: ssh ${SSH_TARGET} cat ~/.jupyter_output.log"
fi

# Replace server hostname/ip with localhost in the URL
LOCAL_URL=$(echo "$REMOTE_URL" | sed -E "s|http://[^:]+:|http://127.0.0.1:|")

# ─── step 4: kill existing local tunnel, open new one ───────────────
log "Opening SSH tunnel (port $PORT) ..."

lsof -ti:"$PORT" 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 0.5

ssh "${SSH_OPTS[@]}" -N -L "${PORT}:localhost:${PORT}" "$SSH_TARGET" &
TUNNEL_PID=$!
sleep 1

# Verify tunnel is alive
if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
  err "SSH tunnel failed to start"
fi

ok "SSH tunnel active"

# ─── done ───────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  Jupyter is ready!                                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "  $LOCAL_URL"
echo ""
echo "  Environment: $ENV_NAME"
echo "  Server:      $IP"
echo "  Port:        $PORT"
echo ""
echo "  Press Ctrl+C to close the tunnel."
echo ""

# Try to open browser
open "$LOCAL_URL" 2>/dev/null || xdg-open "$LOCAL_URL" 2>/dev/null || true

# Keep tunnel alive
wait "$TUNNEL_PID"
