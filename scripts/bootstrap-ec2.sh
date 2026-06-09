#!/usr/bin/env bash
set -euo pipefail

FOUNDRY_VERSION="${FOUNDRY_VERSION:-v1.7.1}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

install_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y git curl tar build-essential make python3 python3-pip python3-venv ca-certificates
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y git curl tar gcc gcc-c++ make python3 python3-pip ca-certificates
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y git curl tar gcc gcc-c++ make python3 python3-pip ca-certificates
  else
    echo "Unsupported package manager. Install git, curl, tar, make, gcc, python3, pip, venv, and ca-certificates manually."
    exit 1
  fi
}

foundry_arch() {
  case "$(uname -m)" in
    x86_64|amd64)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    *)
      echo "Unsupported architecture for Foundry release assets: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

install_foundry() {
  local arch
  local asset_name
  local checksum_name
  local release_base
  local temp_dir
  local archive_path
  local checksum_path
  local expected_hash
  local actual_hash

  export PATH="$HOME/.foundry/bin:$PATH"
  arch="$(foundry_arch)"
  asset_name="foundry_${FOUNDRY_VERSION}_linux_${arch}.tar.gz"
  checksum_name="foundry_${FOUNDRY_VERSION}_linux_${arch}.sha256"
  release_base="https://github.com/foundry-rs/foundry/releases/download/${FOUNDRY_VERSION}"
  temp_dir="$(mktemp -d)"
  archive_path="${temp_dir}/${asset_name}"
  checksum_path="${temp_dir}/${checksum_name}"

  mkdir -p "$HOME/.foundry/bin"
  curl -fsSL "${release_base}/${asset_name}" -o "$archive_path"
  curl -fsSL "${release_base}/${checksum_name}" -o "$checksum_path"

  expected_hash="$(awk '{print $1}' "$checksum_path")"
  actual_hash="$(sha256sum "$archive_path" | awk '{print $1}')"
  if [ "$expected_hash" != "$actual_hash" ]; then
    echo "SHA256 mismatch for ${asset_name}. Expected ${expected_hash}, got ${actual_hash}." >&2
    exit 1
  fi

  tar -xzf "$archive_path" -C "$HOME/.foundry/bin"
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
