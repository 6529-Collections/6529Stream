#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v forge >/dev/null 2>&1; then
  echo "forge was not found. Run bash scripts/bootstrap-ec2.sh, then retry this command." >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  python_bin="python3"
elif command -v python >/dev/null 2>&1; then
  python_bin="python"
else
  echo "python3 or python was not found. Install Python 3, then retry this command." >&2
  exit 1
fi

forge build
forge test -vvv
forge build --sizes --via-ir --skip test --skip script --force
"$python_bin" scripts/test_release_artifacts.py
"$python_bin" scripts/generate_release_artifacts.py --check
"$python_bin" scripts/test_deployment_manifest.py
"$python_bin" scripts/generate_deployment_manifest.py --check
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
