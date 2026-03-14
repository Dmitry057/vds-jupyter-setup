# VDS Jupyter Setup

One command — install environment on a bare server, forward ports, get a Jupyter URL.

## One-liner (run on your Mac)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/deploy.sh) <SERVER_IP> <ENV>
```

**Environments:**

| # | Name | Packages |
|---|------|----------|
| 1 | `robotics` | ROS2, gymnasium, mujoco, torch, OpenCV, visualization |
| 2 | `nlp` | transformers, spacy, nltk, torch, pandas |
| 3 | `ml` | scikit-learn, xgboost, lightgbm, torch, pandas |

**Examples:**
```bash
# Robotics
bash <(curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/deploy.sh) 158.160.42.69 1

# NLP
bash <(curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/deploy.sh) 158.160.42.69 nlp

# ML
bash <(curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/deploy.sh) 158.160.42.69 ml

# Re-use saved IP (interactive env menu)
bash <(curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/deploy.sh)
```

The script will:
1. SSH to the server (using `~/.ssh/Ключевая_пара_finetuning.pem`)
2. Install the chosen environment (skips if already installed)
3. Start Jupyter Lab
4. Open SSH tunnel for port forwarding
5. Print the `http://127.0.0.1:8888/lab?token=...` URL
6. Open the URL in your browser

## Server-only setup (run on the server itself)

If you just want to set up the environment without port forwarding:

```bash
# Robotics
curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/setup.sh | bash -s robotics

# NLP
curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/setup.sh | bash -s nlp

# ML
curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/setup.sh | bash -s ml

# Interactive menu
curl -fsSL https://raw.githubusercontent.com/Dmitry057/vds-jupyter-setup/main/setup.sh | bash
```

## Detailed Setup

### Prerequisites

- Ubuntu/Debian-based Linux VDS (or Fedora/CentOS)
- Root access or sudo privileges
- Python 3.8+

### Automatic Setup

Each environment script handles:
1. ✅ System package installation (build tools, Python dev headers)
2. ✅ CUDA detection (auto-selects correct PyTorch wheels if GPU available)
3. ✅ Virtual environment creation
4. ✅ Python dependencies installation
5. ✅ Jupyter Lab setup
6. ✅ Kernel registration
7. ✅ Verification of installed packages
8. ✅ Launcher script creation

### Environment Details

#### Robotics (`setup_jupyter_robotics.sh`)
```
Core:
  - Jupyter Lab
  - PyTorch
  - Python 3 venv

Robotics:
  - gymnasium
  - mujoco
  - OpenAI Gym
  - transforms3d
  - trimesh
  - open3d (optional)

Visualization:
  - OpenCV
  - Pillow
  - matplotlib
  - plotly
  - dash

Data:
  - numpy
  - pandas
  - scipy
  - scikit-learn
```

#### NLP (`setup_jupyter_nlp.sh`)
```
Core:
  - Jupyter Lab
  - PyTorch
  - Python 3 venv

NLP:
  - Hugging Face transformers
  - datasets
  - tokenizers
  - spacy (with en_core_web_sm model)
  - NLTK
  - sentencepiece
  - regex

Data & Viz:
  - pandas
  - numpy
  - scipy
  - matplotlib
  - seaborn
  - plotly

ML:
  - scikit-learn
  - tqdm
  - ipywidgets
```

#### Classic ML (`setup_jupyter_ml.sh`)
```
Core:
  - Jupyter Lab
  - PyTorch
  - Python 3 venv

ML Libraries:
  - scikit-learn
  - XGBoost
  - LightGBM
  - CatBoost
  - statsmodels
  - SHAP
  - Optuna (hyperparameter tuning)

Data & Viz:
  - pandas
  - numpy
  - scipy
  - matplotlib
  - seaborn
  - plotly
  - dash
  - jupyter-dash

Utils:
  - tqdm
  - ipywidgets
```

## Configuration

All scripts support optional environment variables:

```bash
# Set custom paths and ports
export VENV_DIR="/opt/jupyter-venv"
export WORKDIR="/opt/notebooks"
export JUPYTER_PORT="8888"
export JUPYTER_IP="0.0.0.0"

# Control what gets installed
export INSTALL_TORCH=1                # Install PyTorch (1 or 0)
export INSTALL_NOTEBOOK_DEPS=1        # Install environment-specific packages (1 or 0)

# Run script
bash setup_jupyter_nlp.sh
```

**Defaults:**
- `VENV_DIR=$HOME/jupyter-venv`
- `WORKDIR=$HOME/notebooks`
- `JUPYTER_PORT=8888`
- `JUPYTER_IP=0.0.0.0`
- `INSTALL_TORCH=1`
- `INSTALL_NOTEBOOK_DEPS=1`

## Usage

### Start Jupyter

After setup, a launcher script is created at `~/notebooks/start_jupyter.sh`:

```bash
~/notebooks/start_jupyter.sh
```

Or manually:
```bash
source ~/jupyter-venv/bin/activate
cd ~/notebooks
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser
```

### Connect from your local machine (auto port-forward)

Use `connect.sh` on your **local machine** — it opens an SSH tunnel and launches the browser:

```bash
# Basic usage
bash connect.sh user@server_ip

# Custom port
bash connect.sh user@server_ip 8888

# With SSH key
bash connect.sh user@server_ip 8888 ~/.ssh/id_rsa
```

Or manually:
```bash
ssh -L 8888:localhost:8888 user@server_ip
```

Then open: `http://localhost:8888`

### Authentication

Jupyter will display a token in the server logs:
```
[C 2026-03-14 12:34:56.789 ServerApp] To access the server, open this file in a browser:
    file:///home/user/.local/share/jupyter/runtime/jpserver_...
    or copy and paste one of these URLs:
        http://localhost:8888/lab?token=abc123def456...
```

Copy the token and paste it when Jupyter asks for authentication.

## CUDA/GPU Support

Scripts automatically detect CUDA and install compatible PyTorch wheels:
- CUDA 12.4-12.9 → `torch cu124`
- CUDA 12.0-12.3 → `torch cu121`
- CUDA 11.8 → `torch cu118`
- No CUDA detected → CPU-only torch

Verify GPU in Jupyter:
```python
import torch
print(torch.cuda.is_available())
print(torch.cuda.get_device_name(0))
```

## Troubleshooting

### Script fails with "No supported package manager found"

Your system uses a package manager we don't detect. Edit the script and add support for your package manager in the `detect_pkg_manager()` function.

### PyTorch still installs CPU-only on GPU server

Check CUDA installation:
```bash
nvidia-smi        # Should show GPU info
nvcc --version    # Should show CUDA version
```

If CUDA is not installed, install CUDA toolkit first:
```bash
# Ubuntu
sudo apt-get install nvidia-cuda-toolkit

# Or download from https://developer.nvidia.com/cuda-downloads
```

### Port 8888 already in use

Use a different port:
```bash
export JUPYTER_PORT=9999
bash setup_jupyter_nlp.sh
```

### Out of disk space during installation

Check available space:
```bash
df -h
```

Some options:
- Use a custom venv directory on a larger disk: `export VENV_DIR=/large_disk/jupyter-venv`
- Install on a separate partition
- Clean package manager cache: `sudo apt-get clean`

### Permission denied on system packages

Make sure you have sudo access:
```bash
sudo -v  # Test sudo
```

If you don't have sudo, ask your hosting provider for root access or to pre-install Python dev headers.

## Manual Installation

If you prefer manual setup, see individual script files:
- `setup_jupyter_robotics.sh`
- `setup_jupyter_nlp.sh`
- `setup_jupyter_ml.sh`

Each is fully self-contained and can be customized.

## Multi-Environment Setup

To install multiple environments:

```bash
# Install NLP environment in default location
bash setup_jupyter_nlp.sh

# Install ML environment in different location
export VENV_DIR="/opt/jupyter-ml"
export JUPYTER_PORT=8889
bash setup_jupyter_ml.sh
```

Each will register a separate Jupyter kernel, selectable in the notebook.

## Notes

- Scripts use `set -Eeuo pipefail` for safety (fail on errors)
- Virtual environments are isolated and won't affect system Python
- All Jupyter kernels are registered to your user's Jupyter config
- Launcher scripts are created for convenience but you can always activate venv manually

## License

MIT

## Contributing

Found a bug? Have a suggestion? Open an issue on GitHub!

https://github.com/Dmitry057/vds-jupyter-setup

## Author

Dmitry057
