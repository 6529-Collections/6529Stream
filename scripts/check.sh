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
forge snapshot --match-path test/gas/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
"$python_bin" -m tools.protocol.test_gas_envelopes
"$python_bin" -m tools.protocol.check_gas_envelopes
"$python_bin" -m tools.protocol.test_external_call_gas_inventory
"$python_bin" -m tools.protocol.check_external_call_gas_inventory
"$python_bin" -m tools.protocol.test_post_entropy_completion_gas
"$python_bin" -m tools.protocol.generate_post_entropy_completion_gas --check
"$python_bin" -m tools.protocol.check_post_entropy_completion_gas
forge test --via-ir --match-path test/gas/StreamPostEntropyCompletionGas.t.sol -vvv
forge snapshot --via-ir --match-path test/gas/StreamPostEntropyCompletionGas.t.sol --match-test testMeasureWorstCaseEoaPostCoordinatorTail --check release-artifacts/baselines/v0.1.0/post-entropy-completion-gas.snap
"$python_bin" -m tools.build.run_forge_size_log --log cache/forge-size.log
"$python_bin" -m tools.build.test_release_build_artifacts
"$python_bin" -m tools.build.build_release_artifacts
"$python_bin" -m tools.build.build_release_artifacts --check
"$python_bin" -m tools.deployment.test_canonical_deployment_candidate
"$python_bin" -m tools.deployment.check_canonical_deployment_candidate
if "$python_bin" -m tools.deployment.check_canonical_deployment_candidate --require-complete; then
  echo "expected incomplete canonical deployment candidate v2" >&2
  exit 1
else
  candidate_strict_exit=$?
  if [ "$candidate_strict_exit" -ne 1 ]; then
    exit "$candidate_strict_exit"
  fi
fi
"$python_bin" -m tools.deployment.test_materialize_canonical_deployment_plan
"$python_bin" -m tools.deployment.materialize_canonical_deployment_plan --candidate deployments/config/canonical-deployment-candidate-non-production.json --output tmp/canonical-deployment-plan.json
"$python_bin" -m tools.deployment.materialize_canonical_deployment_plan --candidate deployments/config/canonical-deployment-candidate-non-production.json --output tmp/canonical-deployment-plan.json --check
"$python_bin" -m tools.build.test_contract_size_budget
"$python_bin" -m tools.build.check_contract_size_budget
"$python_bin" -m tools.build.test_core_bytecode_spend_policy
"$python_bin" -m tools.build.check_core_bytecode_spend_policy
"$python_bin" -m tools.protocol.test_genesis_deployment_profile
"$python_bin" -m tools.protocol.check_genesis_deployment_profile
"$python_bin" -m tools.protocol.test_governed_parameter_identifiers
"$python_bin" -m tools.protocol.check_governed_parameter_identifiers
"$python_bin" -m tools.protocol.test_governed_parameter_inventory
"$python_bin" -m tools.protocol.check_governed_parameter_inventory
"$python_bin" -m tools.protocol.test_governance_action_policy
"$python_bin" -m tools.protocol.check_governance_action_policy
"$python_bin" -m tools.protocol.test_record_family_authorization
"$python_bin" -m tools.protocol.check_record_family_authorization
"$python_bin" -m tools.protocol.test_artist_semantic_owner_matrix
"$python_bin" -m tools.protocol.check_artist_semantic_owner_matrix
"$python_bin" -m tools.protocol.test_artist_record_event_reconstruction_correction
"$python_bin" -m tools.protocol.check_artist_record_event_reconstruction_correction
"$python_bin" -m tools.protocol.test_artist_owner_record_continuity
"$python_bin" -m tools.protocol.check_artist_owner_record_continuity
"$python_bin" -m tools.protocol.test_system_manifest_payload_vector
"$python_bin" -m tools.protocol.check_system_manifest_payload_vector
"$python_bin" -m tools.protocol.test_system_manifest_payload_vector_reference
"$python_bin" -m tools.protocol.check_system_manifest_payload_vector_reference
"$python_bin" -m tools.security.test_slither_baseline
"$python_bin" -m tools.security.check_slither_baseline --baseline-only
"$python_bin" -m tools.build.test_solidity_formatting
"$python_bin" -m tools.build.check_solidity_formatting
"$python_bin" -m tools.build.test_solidity_source_layout
"$python_bin" -m tools.build.check_solidity_source_layout
"$python_bin" -m tools.build.test_solidity_layout_equivalence
"$python_bin" -m tools.build.check_solidity_layout_equivalence --check-receipt
"$python_bin" -m tools.development.test_windows_check_wrapper
"$python_bin" -m tools.development.test_python_toolchain
"$python_bin" -m tools.development.check_python_toolchain
"$python_bin" -m tools.protocol.test_metadata_fixtures
"$python_bin" -m tools.protocol.check_metadata_fixtures
"$python_bin" -m tools.deployment.test_metadata_browser_sandbox
"$python_bin" -m tools.deployment.check_metadata_browser_sandbox
"$python_bin" -m tools.deployment.test_rehearsal_metadata_browser_sandbox
"$python_bin" -m tools.deployment.check_rehearsal_metadata_browser_sandbox
"$python_bin" -m tools.protocol.test_drop_authorization_payload_generator
"$python_bin" -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
"$python_bin" -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
"$python_bin" -m tools.protocol.test_drop_authorization_fixtures
"$python_bin" -m tools.protocol.check_drop_authorization_fixtures
"$python_bin" -m tools.release.test_drop_authorization_signing_evidence
"$python_bin" -m tools.release.check_drop_authorization_signing_evidence
"$python_bin" -m tools.release.test_signer_custody_readiness
"$python_bin" -m tools.release.check_signer_custody_readiness
"$python_bin" -m tools.protocol.test_one_of_one_provenance_manifest
"$python_bin" -m tools.protocol.check_one_of_one_provenance_manifest
"$python_bin" -m tools.protocol.generate_one_of_one_provenance_manifest --check
"$python_bin" -m tools.deployment.test_admin_ceremony_evidence
"$python_bin" -m tools.deployment.check_admin_ceremony_evidence
"$python_bin" -m tools.build.test_release_artifacts
"$python_bin" -m tools.build.generate_release_artifacts --check
"$python_bin" -m tools.build.test_protocol_surface_report
"$python_bin" -m tools.build.generate_protocol_surface_report --check
"$python_bin" -m tools.build.test_custom_error_catalog
"$python_bin" -m tools.build.generate_custom_error_catalog --check
"$python_bin" -m tools.build.test_natspec_coverage
"$python_bin" -m tools.build.check_natspec_coverage
"$python_bin" -m tools.build.test_source_verification_inputs
"$python_bin" -m tools.build.generate_source_verification_inputs --check
"$python_bin" -m tools.protocol.test_dependency_artifact_manifest
"$python_bin" -m tools.protocol.generate_dependency_artifact_manifest --check
"$python_bin" -m tools.protocol.test_dependency_provenance_attestation
"$python_bin" -m tools.protocol.generate_dependency_provenance_attestation --check
"$python_bin" -m tools.build.test_abi_compatibility
"$python_bin" -m tools.build.check_abi_compatibility --check
"$python_bin" -m tools.deployment.test_broadcast_manifest_input
"$python_bin" -m tools.deployment.generate_broadcast_manifest_input --check
"$python_bin" -m tools.deployment.generate_broadcast_manifest_input --template deployments/config/fork-mainnet-6529stream-v0.1.0-001.json --broadcast deployments/broadcasts/fork-mainnet-6529stream-v0.1.0-001-run-latest.json --output deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --manifest-output deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --check
"$python_bin" -m tools.deployment.test_deployment_manifest
"$python_bin" -m tools.deployment.generate_deployment_manifest --check
"$python_bin" -m tools.deployment.generate_deployment_manifest --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
"$python_bin" -m tools.deployment.generate_deployment_manifest --config deployments/config/fork-mainnet-6529stream-v0.1.0-001.json --check
"$python_bin" -m tools.deployment.generate_deployment_manifest --config deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --check
"$python_bin" -m tools.deployment.test_address_books
"$python_bin" -m tools.deployment.generate_address_books --check
"$python_bin" -m tools.deployment.test_ceremony_evidence
"$python_bin" -m tools.deployment.check_ceremony_evidence
"$python_bin" -m tools.deployment.test_randomizer_operations
"$python_bin" -m tools.deployment.check_randomizer_operations
"$python_bin" -m tools.release.test_release_signatures
"$python_bin" -m tools.release.check_release_signatures
"$python_bin" -m tools.release.test_signed_release_tag
"$python_bin" -m tools.release.check_signed_release_tag
"$python_bin" -m tools.release.test_non_local_release_evidence_generator
"$python_bin" -m tools.release.test_non_local_release_evidence
"$python_bin" -m tools.release.check_non_local_release_evidence
"$python_bin" -m tools.release.test_external_audit_report_evidence
"$python_bin" -m tools.release.check_external_audit_report_evidence
"$python_bin" -m tools.release.test_post_audit_remediation_evidence
"$python_bin" -m tools.release.check_post_audit_remediation_evidence
"$python_bin" -m tools.deployment.test_live_ceremony_evidence
"$python_bin" -m tools.deployment.check_live_ceremony_evidence
"$python_bin" -m tools.deployment.test_live_randomizer_operations_evidence
"$python_bin" -m tools.deployment.check_live_randomizer_operations_evidence
"$python_bin" -m tools.deployment.test_fork_deployment_rehearsal_evidence
"$python_bin" -m tools.deployment.check_fork_deployment_rehearsal_evidence
"$python_bin" -m tools.deployment.test_testnet_deployment_rehearsal_evidence
"$python_bin" -m tools.deployment.check_testnet_deployment_rehearsal_evidence
"$python_bin" -m tools.deployment.test_sepolia_evidence_preflight
"$python_bin" -m tools.deployment.check_sepolia_evidence_preflight
"$python_bin" -m tools.release.test_public_beta_verified_addresses
"$python_bin" -m tools.release.check_public_beta_verified_addresses
"$python_bin" -m tools.release.test_production_broadcast_retention
"$python_bin" -m tools.release.check_production_broadcast_retention
"$python_bin" -m tools.release.test_live_deployment_manifest_evidence
"$python_bin" -m tools.release.check_live_deployment_manifest_evidence
"$python_bin" -m tools.release.test_production_verified_addresses
"$python_bin" -m tools.release.check_production_verified_addresses
"$python_bin" -m tools.release.test_production_release_signing_evidence
"$python_bin" -m tools.release.check_production_release_signing_evidence
"$python_bin" -m tools.release.test_generate_fork_metadata_browser_evidence_draft
"$python_bin" -m tools.release.test_fork_metadata_browser_evidence
"$python_bin" -m tools.release.check_fork_metadata_browser_evidence
"$python_bin" -m tools.deployment.test_fork_ceremony_evidence
"$python_bin" -m tools.deployment.check_fork_ceremony_evidence
"$python_bin" -m tools.deployment.test_fork_randomizer_operations_evidence
"$python_bin" -m tools.deployment.check_fork_randomizer_operations_evidence
"$python_bin" -m tools.release.test_live_metadata_browser_evidence
"$python_bin" -m tools.release.check_live_metadata_browser_evidence
"$python_bin" -m tools.release.test_marketplace_indexer_evidence
"$python_bin" -m tools.release.check_marketplace_indexer_evidence
"$python_bin" -m tools.release.test_incident_drill_evidence
"$python_bin" -m tools.release.check_incident_drill_evidence
"$python_bin" -m tools.release.test_signer_compromise_drill_evidence
"$python_bin" -m tools.release.check_signer_compromise_drill_evidence
"$python_bin" -m tools.release.test_stuck_auction_drill_evidence
"$python_bin" -m tools.release.check_stuck_auction_drill_evidence
"$python_bin" -m tools.release.test_failed_randomness_drill_evidence
"$python_bin" -m tools.release.check_failed_randomness_drill_evidence
"$python_bin" -m tools.protocol.test_bad_metadata_dependency_drill_evidence
"$python_bin" -m tools.protocol.check_bad_metadata_dependency_drill_evidence
"$python_bin" -m tools.release.test_public_beta_evidence
"$python_bin" -m tools.release.check_public_beta_evidence
"$python_bin" -m tools.security.test_risk_register
"$python_bin" -m tools.security.check_risk_register
"$python_bin" -m tools.security.generate_risk_register --check
"$python_bin" -m tools.release.test_public_beta_blocker_report
"$python_bin" -m tools.release.generate_public_beta_blocker_report --check
"$python_bin" -m tools.release.test_production_release_blocker_report
"$python_bin" -m tools.release.generate_production_release_blocker_report --check
"$python_bin" -m tools.release.test_release_evidence_packet_index
"$python_bin" -m tools.release.generate_release_evidence_packet_index --check
"$python_bin" -m tools.release.test_release_evidence_issue_backlog
"$python_bin" -m tools.release.generate_release_evidence_issue_backlog --check
"$python_bin" -m tools.release.test_release_evidence_issue_links
"$python_bin" -m tools.release.check_release_evidence_issue_links
"$python_bin" -m tools.release.test_release_evidence_issue_snapshot
"$python_bin" -m tools.release.test_release_evidence_issue_snapshot_audit
"$python_bin" -m tools.release.test_release_evidence_issue_labels
"$python_bin" -m tools.release.check_release_evidence_issue_labels
"$python_bin" -m tools.release.test_release_evidence_issue_body_sync
"$python_bin" -m tools.release.generate_release_evidence_issue_body_sync --check
"$python_bin" -m tools.release.test_release_evidence_issue_bodies
"$python_bin" -m tools.release.check_release_evidence_issue_bodies
"$python_bin" -m tools.release.test_release_evidence_issue_closure
"$python_bin" -m tools.release.check_release_evidence_issue_closure
"$python_bin" -m tools.release.test_release_evidence_live_audit_report
"$python_bin" -m tools.release.check_release_evidence_live_audit_report
"$python_bin" -m tools.release.test_release_evidence_live_audit_markdown
"$python_bin" -m tools.release.check_release_evidence_live_audit_markdown
"$python_bin" -m tools.release.test_release_evidence_live_audit_archive
"$python_bin" -m tools.release.generate_release_evidence_live_audit_archive --check
"$python_bin" -m tools.docs.test_architecture_threat_model
"$python_bin" -m tools.docs.check_architecture_threat_model
"$python_bin" -m tools.protocol.test_mint_manager_domain_constants
"$python_bin" -m tools.protocol.check_mint_manager_domain_constants
"$python_bin" -m tools.docs.test_audit_package
"$python_bin" -m tools.docs.check_audit_package
"$python_bin" -m tools.docs.test_audit_finding_workflow
"$python_bin" -m tools.docs.check_audit_finding_workflow
"$python_bin" -m tools.docs.test_incident_response
"$python_bin" -m tools.docs.check_incident_response
"$python_bin" -m tools.docs.test_readme
"$python_bin" -m tools.docs.check_readme
"$python_bin" -m tools.docs.test_first_30_minutes
"$python_bin" -m tools.docs.check_first_30_minutes
"$python_bin" -m tools.docs.test_issue_templates
"$python_bin" -m tools.docs.check_issue_templates
"$python_bin" -m tools.docs.test_pr_template
"$python_bin" -m tools.docs.check_pr_template
"$python_bin" -m tools.development.test_autonomous_state
"$python_bin" -m tools.development.check_autonomous_state
"$python_bin" -m tools.docs.test_markdown_links
"$python_bin" -m tools.docs.check_markdown_links
"$python_bin" -m tools.docs.test_integrations_readme
"$python_bin" -m tools.docs.check_integrations_readme
"$python_bin" -m tools.docs.test_contract_flows
"$python_bin" -m tools.docs.check_contract_flows
"$python_bin" -m tools.docs.test_auction_flows
"$python_bin" -m tools.docs.check_auction_flows
"$python_bin" -m tools.docs.test_curator_rewards_flow
"$python_bin" -m tools.docs.check_curator_rewards_flow
"$python_bin" -m tools.docs.test_withdrawals_credits_flow
"$python_bin" -m tools.docs.check_withdrawals_credits_flow
"$python_bin" -m tools.docs.test_wallet_signature_flows
"$python_bin" -m tools.docs.check_wallet_signature_flows
"$python_bin" -m tools.docs.test_events_and_indexing
"$python_bin" -m tools.docs.check_events_and_indexing
"$python_bin" -m tools.docs.test_metadata_rendering
"$python_bin" -m tools.docs.check_metadata_rendering
"$python_bin" -m tools.docs.test_react_next_reference
"$python_bin" -m tools.docs.check_react_next_reference
"$python_bin" -m tools.protocol.test_typescript_artifact_chain_config
"$python_bin" -m tools.protocol.check_typescript_artifact_chain_config
"$python_bin" -m tools.protocol.test_typescript_eip712_drop_authorization
"$python_bin" -m tools.protocol.check_typescript_eip712_drop_authorization
"$python_bin" -m tools.protocol.test_typescript_event_decoding_indexer
"$python_bin" -m tools.protocol.check_typescript_event_decoding_indexer
"$python_bin" -m tools.protocol.test_integration_conformance_fixtures
"$python_bin" -m tools.protocol.check_integration_conformance_fixtures
"$python_bin" -m tools.docs.test_mobile_walletconnect
"$python_bin" -m tools.docs.check_mobile_walletconnect
"$python_bin" -m tools.docs.test_electron_security_wallets
"$python_bin" -m tools.docs.check_electron_security_wallets
"$python_bin" -m tools.docs.test_operator_admin_ui
"$python_bin" -m tools.docs.check_operator_admin_ui
"$python_bin" -m tools.docs.test_operator_dashboard_query_model
"$python_bin" -m tools.docs.check_operator_dashboard_query_model
"$python_bin" -m tools.docs.test_monitoring_spec
"$python_bin" -m tools.docs.check_monitoring_spec
"$python_bin" -m tools.docs.test_royalty_policy
"$python_bin" -m tools.docs.check_royalty_policy
"$python_bin" -m tools.security.test_warning_dispositions
"$python_bin" -m tools.security.check_warning_dispositions --solc-warnings-log cache/forge-size.log
"$python_bin" -m tools.protocol.test_one_of_one_permanence_package
"$python_bin" -m tools.protocol.check_one_of_one_permanence_package
"$python_bin" -m tools.protocol.generate_one_of_one_permanence_manifest --check
"$python_bin" -m tools.release.test_release_readiness
"$python_bin" -m tools.release.check_release_readiness
"$python_bin" -m tools.release.test_release_mode
"$python_bin" -m tools.release.test_release_notes
"$python_bin" -m tools.release.generate_release_notes --check
"$python_bin" -m tools.release.test_release_manifest
"$python_bin" -m tools.release.generate_release_manifest --check
"$python_bin" -m tools.build.test_bytecode_release_proof
"$python_bin" -m tools.build.generate_bytecode_release_proof --check
"$python_bin" -m tools.release.test_release_candidate_lockfile
"$python_bin" -m tools.release.generate_release_candidate_lockfile --check
"$python_bin" -m tools.release.test_release_checksums
"$python_bin" -m tools.release.generate_release_checksums --check
"$python_bin" -m tools.build.test_verify_release_artifacts
"$python_bin" -m tools.build.verify_release_artifacts
"$python_bin" -m tools.docs.test_changelog_check
"$python_bin" -m tools.docs.check_changelog
"$python_bin" -m tools.deployment.test_deployment_rehearsal_gate
"$python_bin" -m tools.deployment.check_deployment_rehearsal_gate
forge script script/legacy/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite --sig "run()" --via-ir
forge script script/legacy/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/legacy/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/legacy/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
