#!/usr/bin/env bash
set -euo pipefail

FOUNDRY_VERSION="${FOUNDRY_VERSION:-v1.7.1}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

install_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y git curl build-essential make python3 python3-pip python3-venv ca-certificates
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y git curl gcc gcc-c++ make python3 python3-pip ca-certificates
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y git curl gcc gcc-c++ make python3 python3-pip ca-certificates
  else
    echo "Unsupported package manager. Install git, curl, make, gcc, python3, pip, venv, and ca-certificates manually."
    exit 1
  fi
}

install_foundry() {
  export PATH="$HOME/.foundry/bin:$PATH"
  if ! command -v foundryup >/dev/null 2>&1; then
    curl -L https://foundry.paradigm.xyz | bash
    export PATH="$HOME/.foundry/bin:$PATH"
  fi
  foundryup -v "$FOUNDRY_VERSION"
  forge --version
}

install_python_tools() {
  python3 -m venv .venv-tools
  # shellcheck source=/dev/null
  source .venv-tools/bin/activate
  python -m pip install --upgrade pip
  python -m pip install -r requirements-tools.txt
  solc-select install 0.8.19
  solc-select use 0.8.19
}

install_packages
install_foundry
install_python_tools

cat <<'EOF'

Bootstrap complete.

For this shell, run:
  source .venv-tools/bin/activate
  export PATH="$HOME/.foundry/bin:$PATH"

Then verify:
  make check

Non-gating diagnostics for later roadmap items:
  make fmt-check
  make slither

EOF
