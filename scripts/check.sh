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
"$python_bin" scripts/test_gas_envelopes.py
"$python_bin" scripts/check_gas_envelopes.py
"$python_bin" scripts/run_forge_size_log.py --log cache/forge-size.log
"$python_bin" scripts/test_contract_size_budget.py
"$python_bin" scripts/check_contract_size_budget.py
"$python_bin" scripts/test_core_bytecode_spend_policy.py
"$python_bin" scripts/check_core_bytecode_spend_policy.py
"$python_bin" scripts/test_solidity_formatting.py
"$python_bin" scripts/check_solidity_formatting.py
"$python_bin" scripts/test_windows_check_wrapper.py
"$python_bin" scripts/test_metadata_fixtures.py
"$python_bin" scripts/check_metadata_fixtures.py
"$python_bin" scripts/test_metadata_browser_sandbox.py
"$python_bin" scripts/check_metadata_browser_sandbox.py
"$python_bin" scripts/test_rehearsal_metadata_browser_sandbox.py
"$python_bin" scripts/check_rehearsal_metadata_browser_sandbox.py
"$python_bin" scripts/test_drop_authorization_payload_generator.py
"$python_bin" scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
"$python_bin" scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
"$python_bin" scripts/test_drop_authorization_fixtures.py
"$python_bin" scripts/check_drop_authorization_fixtures.py
"$python_bin" scripts/test_drop_authorization_signing_evidence.py
"$python_bin" scripts/check_drop_authorization_signing_evidence.py
"$python_bin" scripts/test_signer_custody_readiness.py
"$python_bin" scripts/check_signer_custody_readiness.py
"$python_bin" scripts/test_admin_ceremony_evidence.py
"$python_bin" scripts/check_admin_ceremony_evidence.py
"$python_bin" scripts/test_release_artifacts.py
"$python_bin" scripts/generate_release_artifacts.py --check
"$python_bin" scripts/test_protocol_surface_report.py
"$python_bin" scripts/generate_protocol_surface_report.py --check
"$python_bin" scripts/test_custom_error_catalog.py
"$python_bin" scripts/generate_custom_error_catalog.py --check
"$python_bin" scripts/test_natspec_coverage.py
"$python_bin" scripts/check_natspec_coverage.py
"$python_bin" scripts/test_source_verification_inputs.py
"$python_bin" scripts/generate_source_verification_inputs.py --check
"$python_bin" scripts/test_dependency_artifact_manifest.py
"$python_bin" scripts/generate_dependency_artifact_manifest.py --check
"$python_bin" scripts/test_dependency_provenance_attestation.py
"$python_bin" scripts/generate_dependency_provenance_attestation.py --check
"$python_bin" scripts/test_abi_compatibility.py
"$python_bin" scripts/check_abi_compatibility.py --check
"$python_bin" scripts/test_broadcast_manifest_input.py
"$python_bin" scripts/generate_broadcast_manifest_input.py --check
"$python_bin" scripts/generate_broadcast_manifest_input.py --template deployments/config/fork-mainnet-6529stream-v0.1.0-001.json --broadcast deployments/broadcasts/fork-mainnet-6529stream-v0.1.0-001-run-latest.json --output deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --manifest-output deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --check
"$python_bin" scripts/test_deployment_manifest.py
"$python_bin" scripts/generate_deployment_manifest.py --check
"$python_bin" scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
"$python_bin" scripts/generate_deployment_manifest.py --config deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --check
"$python_bin" scripts/test_address_books.py
"$python_bin" scripts/generate_address_books.py --check
"$python_bin" scripts/test_ceremony_evidence.py
"$python_bin" scripts/check_ceremony_evidence.py
"$python_bin" scripts/test_randomizer_operations.py
"$python_bin" scripts/check_randomizer_operations.py
"$python_bin" scripts/test_release_signatures.py
"$python_bin" scripts/check_release_signatures.py
"$python_bin" scripts/test_signed_release_tag.py
"$python_bin" scripts/check_signed_release_tag.py
"$python_bin" scripts/test_non_local_release_evidence_generator.py
"$python_bin" scripts/test_non_local_release_evidence.py
"$python_bin" scripts/check_non_local_release_evidence.py
"$python_bin" scripts/test_external_audit_report_evidence.py
"$python_bin" scripts/check_external_audit_report_evidence.py
"$python_bin" scripts/test_post_audit_remediation_evidence.py
"$python_bin" scripts/check_post_audit_remediation_evidence.py
"$python_bin" scripts/test_live_ceremony_evidence.py
"$python_bin" scripts/check_live_ceremony_evidence.py
"$python_bin" scripts/test_live_randomizer_operations_evidence.py
"$python_bin" scripts/check_live_randomizer_operations_evidence.py
"$python_bin" scripts/test_fork_deployment_rehearsal_evidence.py
"$python_bin" scripts/check_fork_deployment_rehearsal_evidence.py
"$python_bin" scripts/test_testnet_deployment_rehearsal_evidence.py
"$python_bin" scripts/check_testnet_deployment_rehearsal_evidence.py
"$python_bin" scripts/test_production_broadcast_retention.py
"$python_bin" scripts/check_production_broadcast_retention.py
"$python_bin" scripts/test_production_verified_addresses.py
"$python_bin" scripts/check_production_verified_addresses.py
"$python_bin" scripts/test_live_metadata_browser_evidence.py
"$python_bin" scripts/check_live_metadata_browser_evidence.py
"$python_bin" scripts/test_marketplace_indexer_evidence.py
"$python_bin" scripts/check_marketplace_indexer_evidence.py
"$python_bin" scripts/test_incident_drill_evidence.py
"$python_bin" scripts/check_incident_drill_evidence.py
"$python_bin" scripts/test_public_beta_evidence.py
"$python_bin" scripts/check_public_beta_evidence.py
"$python_bin" scripts/test_risk_register.py
"$python_bin" scripts/check_risk_register.py
"$python_bin" scripts/generate_risk_register.py --check
"$python_bin" scripts/test_public_beta_blocker_report.py
"$python_bin" scripts/generate_public_beta_blocker_report.py --check
"$python_bin" scripts/test_production_release_blocker_report.py
"$python_bin" scripts/generate_production_release_blocker_report.py --check
"$python_bin" scripts/test_release_evidence_packet_index.py
"$python_bin" scripts/generate_release_evidence_packet_index.py --check
"$python_bin" scripts/test_release_evidence_issue_backlog.py
"$python_bin" scripts/generate_release_evidence_issue_backlog.py --check
"$python_bin" scripts/test_release_evidence_issue_links.py
"$python_bin" scripts/check_release_evidence_issue_links.py
"$python_bin" scripts/test_release_evidence_issue_snapshot.py
"$python_bin" scripts/test_release_evidence_issue_snapshot_audit.py
"$python_bin" scripts/test_release_evidence_issue_labels.py
"$python_bin" scripts/check_release_evidence_issue_labels.py
"$python_bin" scripts/test_release_evidence_issue_body_sync.py
"$python_bin" scripts/generate_release_evidence_issue_body_sync.py --check
"$python_bin" scripts/test_release_evidence_issue_bodies.py
"$python_bin" scripts/check_release_evidence_issue_bodies.py
"$python_bin" scripts/test_release_evidence_issue_closure.py
"$python_bin" scripts/check_release_evidence_issue_closure.py
"$python_bin" scripts/test_release_evidence_live_audit_report.py
"$python_bin" scripts/check_release_evidence_live_audit_report.py
"$python_bin" scripts/test_release_evidence_live_audit_markdown.py
"$python_bin" scripts/check_release_evidence_live_audit_markdown.py
"$python_bin" scripts/test_release_evidence_live_audit_archive.py
"$python_bin" scripts/generate_release_evidence_live_audit_archive.py --check
"$python_bin" scripts/test_architecture_threat_model.py
"$python_bin" scripts/check_architecture_threat_model.py
"$python_bin" scripts/test_audit_package.py
"$python_bin" scripts/check_audit_package.py
"$python_bin" scripts/test_incident_response.py
"$python_bin" scripts/check_incident_response.py
"$python_bin" scripts/test_readme.py
"$python_bin" scripts/check_readme.py
"$python_bin" scripts/test_integrations_readme.py
"$python_bin" scripts/check_integrations_readme.py
"$python_bin" scripts/test_contract_flows.py
"$python_bin" scripts/check_contract_flows.py
"$python_bin" scripts/test_auction_flows.py
"$python_bin" scripts/check_auction_flows.py
"$python_bin" scripts/test_wallet_signature_flows.py
"$python_bin" scripts/check_wallet_signature_flows.py
"$python_bin" scripts/test_events_and_indexing.py
"$python_bin" scripts/check_events_and_indexing.py
"$python_bin" scripts/test_metadata_rendering.py
"$python_bin" scripts/check_metadata_rendering.py
"$python_bin" scripts/test_react_next_reference.py
"$python_bin" scripts/check_react_next_reference.py
"$python_bin" scripts/test_mobile_walletconnect.py
"$python_bin" scripts/check_mobile_walletconnect.py
"$python_bin" scripts/test_electron_security_wallets.py
"$python_bin" scripts/check_electron_security_wallets.py
"$python_bin" scripts/test_operator_admin_ui.py
"$python_bin" scripts/check_operator_admin_ui.py
"$python_bin" scripts/test_royalty_policy.py
"$python_bin" scripts/check_royalty_policy.py
"$python_bin" scripts/test_warning_dispositions.py
"$python_bin" scripts/check_warning_dispositions.py --solc-warnings-log cache/forge-size.log
"$python_bin" scripts/test_one_of_one_permanence_package.py
"$python_bin" scripts/check_one_of_one_permanence_package.py
"$python_bin" scripts/generate_one_of_one_permanence_manifest.py --check
"$python_bin" scripts/test_release_readiness.py
"$python_bin" scripts/check_release_readiness.py
"$python_bin" scripts/test_release_mode.py
"$python_bin" scripts/test_release_notes.py
"$python_bin" scripts/generate_release_notes.py --check
"$python_bin" scripts/test_release_manifest.py
"$python_bin" scripts/generate_release_manifest.py --check
"$python_bin" scripts/test_bytecode_release_proof.py
"$python_bin" scripts/generate_bytecode_release_proof.py --check
"$python_bin" scripts/test_release_checksums.py
"$python_bin" scripts/generate_release_checksums.py --check
"$python_bin" scripts/test_verify_release_artifacts.py
"$python_bin" scripts/verify_release_artifacts.py
"$python_bin" scripts/test_changelog_check.py
"$python_bin" scripts/check_changelog.py
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
