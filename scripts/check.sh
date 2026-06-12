#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

export PATH="$HOME/.foundry/bin:$PATH"

if ! command -v forge >/dev/null 2>&1; then
  echo "forge was not found. Run bash scripts/bootstrap-ec2.sh, then retry this command." >&2
  exit 1
fi

venv_python="$repo_root/.venv-tools/bin/python"

if [ -x "$venv_python" ]; then
  python_bin="$venv_python"
elif command -v python3 >/dev/null 2>&1; then
  python_bin="python3"
elif command -v python >/dev/null 2>&1; then
  python_bin="python"
else
  echo "python3 or python was not found. Install Python 3, then retry this command." >&2
  exit 1
fi

forge build
forge test -vvv
forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
forge build --sizes --via-ir --skip test --skip script --force
"$python_bin" scripts/test_metadata_fixtures.py
"$python_bin" scripts/check_metadata_fixtures.py
"$python_bin" scripts/test_metadata_browser_sandbox.py
"$python_bin" scripts/check_metadata_browser_sandbox.py
"$python_bin" scripts/test_rehearsal_metadata_browser_sandbox.py
"$python_bin" scripts/check_rehearsal_metadata_browser_sandbox.py
"$python_bin" scripts/test_release_artifacts.py
"$python_bin" scripts/generate_release_artifacts.py --check
"$python_bin" scripts/test_source_verification_inputs.py
"$python_bin" scripts/generate_source_verification_inputs.py --check
"$python_bin" scripts/test_dependency_artifact_manifest.py
"$python_bin" scripts/generate_dependency_artifact_manifest.py --check
"$python_bin" scripts/test_abi_compatibility.py
"$python_bin" scripts/check_abi_compatibility.py --check
"$python_bin" scripts/test_broadcast_manifest_input.py
"$python_bin" scripts/generate_broadcast_manifest_input.py --check
"$python_bin" scripts/test_deployment_manifest.py
"$python_bin" scripts/generate_deployment_manifest.py --check
"$python_bin" scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
"$python_bin" scripts/test_address_books.py
"$python_bin" scripts/generate_address_books.py --check
"$python_bin" scripts/test_ceremony_evidence.py
"$python_bin" scripts/check_ceremony_evidence.py
"$python_bin" scripts/test_randomizer_operations.py
"$python_bin" scripts/check_randomizer_operations.py
"$python_bin" scripts/test_release_signatures.py
"$python_bin" scripts/check_release_signatures.py
"$python_bin" scripts/test_architecture_threat_model.py
"$python_bin" scripts/check_architecture_threat_model.py
"$python_bin" scripts/test_audit_package.py
"$python_bin" scripts/check_audit_package.py
"$python_bin" scripts/test_release_readiness.py
"$python_bin" scripts/check_release_readiness.py
"$python_bin" scripts/test_release_manifest.py
"$python_bin" scripts/generate_release_manifest.py --check
"$python_bin" scripts/test_release_checksums.py
"$python_bin" scripts/generate_release_checksums.py --check
"$python_bin" scripts/test_changelog_check.py
"$python_bin" scripts/check_changelog.py
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
