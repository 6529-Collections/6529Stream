#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v forge >/dev/null 2>&1; then
  echo "forge was not found. Run bash scripts/bootstrap-ec2.sh, then retry this command." >&2
  exit 1
fi

forge build
forge test -vvv
forge build --sizes --via-ir --skip test --skip script --force
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
