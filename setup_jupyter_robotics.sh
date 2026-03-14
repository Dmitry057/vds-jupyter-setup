#!/usr/bin/env bash
set -Eeuo pipefail

# Installs Jupyter + Robotics/Self-Driving environment on a minimal Linux VDS.
# Includes: ROS2, gymnasium, mujoco, torch, visualization tools.
# Usage:
#   bash setup_jupyter_robotics.sh
#
# Optional env vars:
#   VENV_DIR=/opt/jupyter-venv
#   WORKDIR=/opt/notebooks
#   JUPYTER_PORT=8888
#   JUPYTER_IP=0.0.0.0
#   INSTALL_TORCH=1
#   INSTALL_NOTEBOOK_DEPS=1

VENV_DIR="${VENV_DIR:-$HOME/jupyter-venv}"
WORKDIR="${WORKDIR:-$HOME/notebooks}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"
JUPYTER_IP="${JUPYTER_IP:-0.0.0.0}"
INSTALL_TORCH="${INSTALL_TORCH:-1}"
INSTALL_NOTEBOOK_DEPS="${INSTALL_NOTEBOOK_DEPS:-1}"

log() {
  printf '\n[%s] %s\n' "$(date +'%F %T')" "$*"
}

die() {
  printf '\n[ERROR] %s\n' "$*" >&2
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  if has_cmd sudo; then
    SUDO="sudo"
  else
    die "Run as root or install sudo first."
  fi
fi

detect_pkg_manager() {
  if has_cmd apt-get; then
    echo "apt"
    return
  fi
  if has_cmd dnf; then
    echo "dnf"
    return
  fi
  if has_cmd yum; then
    echo "yum"
    return
  fi
  die "No supported package manager found (apt-get/dnf/yum)."
}

install_system_packages() {
  local pm="$1"
  case "$pm" in
    apt)
      log "Installing system packages with apt..."
      $SUDO apt-get update -y
      $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 python3-venv python3-pip python3-dev \
        build-essential git curl ca-certificates \
        libopenmpi-dev openmpi-bin \
        libgl1-mesa-glx libglfw3 libxrender1 \
        ros-humble-desktop-full 2>/dev/null || true
      ;;
    dnf)
      log "Installing system packages with dnf..."
      $SUDO dnf install -y \
        python3 python3-pip python3-devel \
        gcc gcc-c++ make git curl ca-certificates \
        openmpi-devel mesa-libGL glfw-devel
      ;;
    yum)
      log "Installing system packages with yum..."
      $SUDO yum install -y \
        python3 python3-pip python3-devel \
        gcc gcc-c++ make git curl ca-certificates \
        openmpi-devel mesa-libGL glfw-devel
      ;;
    *)
      die "Unsupported package manager: $pm"
      ;;
  esac
}

detect_cuda_version() {
  local version=""
  if has_cmd nvcc; then
    version="$(nvcc --version | sed -n 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/p' | head -n1)"
  fi
  if [[ -z "$version" ]] && has_cmd nvidia-smi; then
    version="$(nvidia-smi | sed -n 's/.*CUDA Version: \([0-9]\+\.[0-9]\+\).*/\1/p' | head -n1)"
  fi
  echo "$version"
}

torch_channel_for_cuda() {
  local cuda="$1"
  case "$cuda" in
    12.4|12.5|12.6|12.7|12.8|12.9)
      echo "cu124"
      ;;
    12.0|12.1|12.2|12.3)
      echo "cu121"
      ;;
    11.8)
      echo "cu118"
      ;;
    *)
      echo ""
      ;;
  esac
}

setup_python_env() {
  log "Creating virtual environment at: $VENV_DIR"
  mkdir -p "$(dirname "$VENV_DIR")"
  if [[ ! -d "$VENV_DIR" ]]; then
    python3 -m venv "$VENV_DIR"
  fi
  # shellcheck disable=SC1090
  source "$VENV_DIR/bin/activate"
  python -m pip install --upgrade pip setuptools wheel
}

install_python_packages() {
  log "Installing Jupyter..."
  python -m pip install --upgrade jupyterlab notebook ipykernel

  if [[ "$INSTALL_TORCH" == "1" ]]; then
    local cuda_version
    local torch_channel
    cuda_version="$(detect_cuda_version)"
    torch_channel="$(torch_channel_for_cuda "$cuda_version")"

    if [[ -n "$torch_channel" ]]; then
      log "Installing PyTorch for CUDA ${cuda_version} (${torch_channel})..."
      python -m pip install --upgrade torch torchvision torchaudio \
        --index-url "https://download.pytorch.org/whl/${torch_channel}"
    else
      log "CUDA version not mapped (detected: ${cuda_version:-unknown}), installing default PyTorch wheels..."
      python -m pip install --upgrade torch torchvision torchaudio
    fi
  fi

  if [[ "$INSTALL_NOTEBOOK_DEPS" == "1" ]]; then
    log "Installing robotics/self-driving dependencies..."
    python -m pip install --upgrade \
      gymnasium mujoco gym \
      numpy pandas matplotlib seaborn \
      opencv-python pillow \
      pyyaml tqdm ipywidgets \
      scikit-learn scipy \
      plotly dash

    log "Installing ROS2/robotics tools..."
    python -m pip install --upgrade \
      transforms3d trimesh open3d \
      2>/dev/null || log "Some optional robotics packages failed, continuing..."
  fi

  log "Registering kernel..."
  python -m ipykernel install --user --name robotics --display-name "Python (Robotics)"
}

create_launcher() {
  mkdir -p "$WORKDIR"
  local launcher="$WORKDIR/start_jupyter.sh"

  cat >"$launcher" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

# Kill any existing Jupyter on the same port
lsof -ti:${JUPYTER_PORT} 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 1

source "${VENV_DIR}/bin/activate"
cd "${WORKDIR}"
jupyter lab --ip="${JUPYTER_IP}" --port="${JUPYTER_PORT}" --port-retries=0 --no-browser
EOF

  chmod +x "$launcher"
  log "Launcher created: $launcher"
}

verify_install() {
  # shellcheck disable=SC1090
  source "$VENV_DIR/bin/activate"
  log "Verifying Jupyter/Torch/Robotics packages..."
  python - <<'PY'
import importlib

mods = ["jupyterlab", "notebook", "ipykernel", "torch", "gymnasium", "gym", "mujoco", "cv2", "sklearn", "numpy", "pandas", "matplotlib"]
for m in mods:
    try:
        importlib.import_module(m)
        print(f"[OK] {m}")
    except Exception as e:
        print(f"[WARN] {m}: {e}")

try:
    import torch
    print("Torch version:", torch.__version__)
    print("CUDA available:", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("GPU:", torch.cuda.get_device_name(0))
except Exception as e:
    print("Torch check skipped:", e)
PY
}

main() {
  local pm
  pm="$(detect_pkg_manager)"
  install_system_packages "$pm"
  setup_python_env
  install_python_packages
  create_launcher
  verify_install

  log "Done."
  cat <<EOF

Next:
1) Start Jupyter:
   ${WORKDIR}/start_jupyter.sh

2) SSH tunnel from your local machine:
   ssh -L ${JUPYTER_PORT}:localhost:${JUPYTER_PORT} <user>@<server_ip>

3) Open in browser:
   http://localhost:${JUPYTER_PORT}

If token is requested, copy it from server logs.
EOF
}

main "$@"
