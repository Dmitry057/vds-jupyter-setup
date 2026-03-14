#!/usr/bin/env bash
set -Eeuo pipefail

# Universal Jupyter setup script for VDS
# Allows user to choose which environment to install
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/setup.sh | bash
#   OR
#   bash setup.sh [robotics|nlp|ml]

REPO_URL="https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '\n[%s] %s\n' "$(date +'%F %T')" "$*"
}

show_menu() {
  cat <<EOF

╔════════════════════════════════════════════════════════════════╗
║         Jupyter Environment Setup for VDS                      ║
╚════════════════════════════════════════════════════════════════╝

Choose an environment:

  1) robotics    - ROS2, gymnasium, mujoco, torch, visualization
  2) nlp         - Transformers, spacy, nltk, torch, pandas
  3) ml          - scikit-learn, xgboost, lightgbm, torch, pandas

EOF
}

main() {
  local choice

  if [[ $# -gt 0 ]]; then
    choice="$1"
  else
    show_menu
    read -p "Enter your choice (1-3): " choice
  fi

  local script_name
  case "$choice" in
    1|robotics)
      script_name="setup_jupyter_robotics.sh"
      log "Installing Robotics environment..."
      ;;
    2|nlp)
      script_name="setup_jupyter_nlp.sh"
      log "Installing NLP environment..."
      ;;
    3|ml)
      script_name="setup_jupyter_ml.sh"
      log "Installing Classic ML environment..."
      ;;
    *)
      echo "[ERROR] Invalid choice: $choice"
      exit 1
      ;;
  esac

  # If script exists locally, use it; otherwise download it
  if [[ -f "$SCRIPT_DIR/$script_name" ]]; then
    log "Using local script: $SCRIPT_DIR/$script_name"
    bash "$SCRIPT_DIR/$script_name"
  else
    log "Downloading $script_name from $REPO_URL..."
    bash <(curl -fsSL "$REPO_URL/$script_name")
  fi
}

main "$@"
