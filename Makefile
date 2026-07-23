ifeq ($(OS),Windows_NT)
PYTHON ?= python
POWERSHELL ?= powershell
POWERSHELL_FLAGS ?= -NoProfile -ExecutionPolicy Bypass
ifdef MSYSTEM
FOUNDRY_BIN := $(HOME)/.foundry/bin
REPO_ROOT := $(shell pwd)
PATH_SEPARATOR := :
RM_RF := rm -rf out out-release cache broadcast
else
FOUNDRY_BIN := $(USERPROFILE)/.foundry/bin
REPO_ROOT := $(CURDIR)
PATH_SEPARATOR := ;
RM_RF := powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -Recurse -Force out,out-release,cache,broadcast -ErrorAction SilentlyContinue"
endif
VENV_BIN := .venv-tools/Scripts
else
PYTHON ?= python3
POWERSHELL ?= pwsh
POWERSHELL_FLAGS ?= -NoProfile
FOUNDRY_BIN := $(HOME)/.foundry/bin
REPO_ROOT := $(CURDIR)
PATH_SEPARATOR := :
VENV_BIN := .venv-tools/bin
RM_RF := rm -rf out out-release cache broadcast
endif
PATH := $(FOUNDRY_BIN)$(PATH_SEPARATOR)$(REPO_ROOT)/$(VENV_BIN)$(PATH_SEPARATOR)$(PATH)

.PHONY: check build test gas-snapshot gas-snapshot-check gas-envelopes-check size release-build release-build-check contract-size-budget-check core-bytecode-spend-policy-check genesis-deployment-profile-check system-manifest-payload-vector system-manifest-payload-vector-check slither-baseline-metadata-check slither-baseline-check deployment-rehearsal-gate-check deploy-rehearsal deploy-rehearsal-standalone metadata-fixtures-check windows-check-wrapper-policy windows-check-wrapper-runtime drop-authorization-fixtures-check drop-authorization-signing-evidence-check signer-custody-readiness-check one-of-one-provenance-manifest one-of-one-provenance-manifest-check one-of-one-permanence-manifest one-of-one-permanence-manifest-check admin-ceremony-evidence-check solidity-formatting-check release-artifacts release-artifacts-check protocol-surface-report protocol-surface-report-check custom-error-catalog custom-error-catalog-check natspec-coverage-check source-verification-inputs source-verification-inputs-check abi-compatibility abi-compatibility-check broadcast-manifest-inputs broadcast-manifest-inputs-check deployment-manifests deployment-manifest-check address-books address-books-check dependency-artifacts dependency-artifacts-check dependency-provenance-attestation dependency-provenance-attestation-check ceremony-evidence-check randomizer-operations-check release-signatures-check signed-release-tag-check bytecode-release-proof bytecode-release-proof-check release-candidate-lockfile release-candidate-lockfile-check non-local-release-evidence-check external-audit-report-evidence-check post-audit-remediation-evidence-check live-ceremony-evidence-check live-randomizer-operations-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check sepolia-evidence-preflight-check public-beta-verified-addresses-check production-broadcast-retention-check live-deployment-manifest-evidence-check production-verified-addresses-check production-release-signing-evidence-check fork-metadata-browser-evidence-check live-metadata-browser-evidence-check marketplace-indexer-evidence-check incident-drill-evidence-check signer-compromise-drill-evidence-check stuck-auction-drill-evidence-check failed-randomness-drill-evidence-check bad-metadata-dependency-drill-evidence-check public-beta-evidence-check public-beta-blocker-report public-beta-blocker-report-check production-release-blocker-report production-release-blocker-report-check release-evidence-packet-index release-evidence-packet-index-check release-evidence-issue-backlog release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-labels-check release-evidence-issue-body-sync release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-issue-snapshot release-evidence-live-issue-sync-check release-evidence-live-audit-report-check release-evidence-live-audit-markdown-check release-evidence-live-audit-archive release-evidence-live-audit-archive-check architecture-threat-model-check audit-package-check audit-finding-workflow-check incident-response-check readme-check first-30-minutes-check issue-templates-check pr-template-check autonomous-state-check markdown-links-check integrations-readme-check contract-flows-check auction-flows-check curator-rewards-check withdrawals-credits-check wallet-signature-flows-check events-and-indexing-check metadata-rendering-check react-next-reference-check typescript-artifact-chain-config-check typescript-eip712-drop-authorization-check typescript-event-decoding-indexer-check integration-conformance-fixtures-check mobile-walletconnect-check electron-security-wallets-check operator-admin-ui-check operator-dashboard-query-model-check monitoring-spec-check royalty-policy-check warning-dispositions-check release-readiness-check release-mode-public-beta-check release-mode-production-release-check release-mode-check release-notes release-notes-check release-manifest release-manifest-check release-artifacts-verify release-checksums release-checksums-check changelog-check fmt-check slither clean
check: build test gas-snapshot-check gas-envelopes-check size release-build-check contract-size-budget-check core-bytecode-spend-policy-check genesis-deployment-profile-check system-manifest-payload-vector-check slither-baseline-metadata-check solidity-formatting-check windows-check-wrapper-policy metadata-fixtures-check drop-authorization-fixtures-check drop-authorization-signing-evidence-check signer-custody-readiness-check one-of-one-provenance-manifest-check one-of-one-permanence-manifest-check admin-ceremony-evidence-check release-artifacts-check protocol-surface-report-check custom-error-catalog-check natspec-coverage-check source-verification-inputs-check abi-compatibility-check dependency-provenance-attestation-check signed-release-tag-check non-local-release-evidence-check external-audit-report-evidence-check post-audit-remediation-evidence-check live-ceremony-evidence-check live-randomizer-operations-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check sepolia-evidence-preflight-check public-beta-verified-addresses-check production-broadcast-retention-check live-deployment-manifest-evidence-check production-verified-addresses-check production-release-signing-evidence-check fork-metadata-browser-evidence-check live-metadata-browser-evidence-check marketplace-indexer-evidence-check incident-drill-evidence-check signer-compromise-drill-evidence-check stuck-auction-drill-evidence-check failed-randomness-drill-evidence-check bad-metadata-dependency-drill-evidence-check public-beta-evidence-check public-beta-blocker-report-check production-release-blocker-report-check release-evidence-packet-index-check release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-labels-check release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-audit-archive-check architecture-threat-model-check audit-package-check audit-finding-workflow-check incident-response-check readme-check first-30-minutes-check issue-templates-check pr-template-check autonomous-state-check markdown-links-check integrations-readme-check contract-flows-check auction-flows-check curator-rewards-check withdrawals-credits-check wallet-signature-flows-check events-and-indexing-check metadata-rendering-check react-next-reference-check typescript-artifact-chain-config-check typescript-eip712-drop-authorization-check typescript-event-decoding-indexer-check integration-conformance-fixtures-check mobile-walletconnect-check electron-security-wallets-check operator-admin-ui-check operator-dashboard-query-model-check monitoring-spec-check royalty-policy-check warning-dispositions-check release-readiness-check release-notes-check release-artifacts-verify changelog-check deployment-rehearsal-gate-check deploy-rehearsal
check: fork-ceremony-evidence-check fork-randomizer-operations-evidence-check
check: python-toolchain-check
check: external-call-gas-inventory-check
release-manifest: fork-ceremony-evidence-check fork-randomizer-operations-evidence-check
release-manifest-check: fork-ceremony-evidence-check fork-randomizer-operations-evidence-check
.PHONY: fork-ceremony-evidence-check fork-randomizer-operations-evidence-check
.PHONY: python-toolchain-check
.PHONY: external-call-gas-inventory-check

build:
	forge build

test:
	forge test -vvv

gas-snapshot:
	forge snapshot --match-path test/StreamGasSnapshot.t.sol --snap release-artifacts/baselines/v0.1.0/gas-snapshot.snap

gas-snapshot-check:
	forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap

gas-envelopes-check:
	$(PYTHON) scripts/test_gas_envelopes.py
	$(PYTHON) scripts/check_gas_envelopes.py

external-call-gas-inventory-check:
	$(PYTHON) scripts/test_external_call_gas_inventory.py
	$(PYTHON) scripts/check_external_call_gas_inventory.py

# Aggregate diagnostic only; canonical release bytecode is built by release-build.
size:
	$(PYTHON) scripts/run_forge_size_log.py --log cache/forge-size.log

release-build:
	$(PYTHON) scripts/test_release_build_artifacts.py
	$(PYTHON) scripts/build_release_artifacts.py

release-build-check: release-build
	$(PYTHON) scripts/build_release_artifacts.py --check

contract-size-budget-check: size release-build-check
	$(PYTHON) scripts/test_contract_size_budget.py
	$(PYTHON) scripts/check_contract_size_budget.py

core-bytecode-spend-policy-check: size release-build-check
	$(PYTHON) scripts/test_core_bytecode_spend_policy.py
	$(PYTHON) scripts/check_core_bytecode_spend_policy.py

deployment-rehearsal-gate-check:
	$(PYTHON) scripts/test_deployment_rehearsal_gate.py
	$(PYTHON) scripts/check_deployment_rehearsal_gate.py

deploy-rehearsal:
	forge script script/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite --sig "run()" --via-ir

deploy-rehearsal-standalone:
	forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
	forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
	forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir

metadata-fixtures-check:
	$(PYTHON) scripts/test_metadata_fixtures.py
	$(PYTHON) scripts/check_metadata_fixtures.py
	$(PYTHON) scripts/test_metadata_browser_sandbox.py
	$(PYTHON) scripts/check_metadata_browser_sandbox.py
	$(PYTHON) scripts/test_rehearsal_metadata_browser_sandbox.py
	$(PYTHON) scripts/check_rehearsal_metadata_browser_sandbox.py

windows-check-wrapper-policy:
	$(PYTHON) scripts/test_windows_check_wrapper.py
	$(PYTHON) scripts/test_windows_ci_wrapper.py

windows-check-wrapper-runtime:
	$(POWERSHELL) $(POWERSHELL_FLAGS) -File scripts/test_windows_check_helpers.ps1

python-toolchain-check:
	$(PYTHON) scripts/test_python_toolchain.py
	$(PYTHON) scripts/check_python_toolchain.py

drop-authorization-fixtures-check:
	$(PYTHON) scripts/test_drop_authorization_payload_generator.py
	$(PYTHON) scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
	$(PYTHON) scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
	$(PYTHON) scripts/test_drop_authorization_fixtures.py
	$(PYTHON) scripts/check_drop_authorization_fixtures.py

drop-authorization-signing-evidence-check:
	$(PYTHON) scripts/test_drop_authorization_signing_evidence.py
	$(PYTHON) scripts/check_drop_authorization_signing_evidence.py

signer-custody-readiness-check:
	$(PYTHON) scripts/test_signer_custody_readiness.py
	$(PYTHON) scripts/check_signer_custody_readiness.py

one-of-one-provenance-manifest:
	$(PYTHON) scripts/generate_one_of_one_provenance_manifest.py

one-of-one-provenance-manifest-check:
	$(PYTHON) scripts/test_one_of_one_provenance_manifest.py
	$(PYTHON) scripts/check_one_of_one_provenance_manifest.py
	$(PYTHON) scripts/generate_one_of_one_provenance_manifest.py --check

one-of-one-permanence-manifest:
	$(PYTHON) scripts/generate_one_of_one_permanence_manifest.py

one-of-one-permanence-manifest-check:
	$(PYTHON) scripts/test_one_of_one_permanence_package.py
	$(PYTHON) scripts/check_one_of_one_permanence_package.py
	$(PYTHON) scripts/generate_one_of_one_permanence_manifest.py --check

admin-ceremony-evidence-check:
	$(PYTHON) scripts/test_admin_ceremony_evidence.py
	$(PYTHON) scripts/check_admin_ceremony_evidence.py

release-artifacts: release-build-check
	$(PYTHON) scripts/generate_release_artifacts.py

release-artifacts-check: release-build-check
	$(PYTHON) scripts/test_release_artifacts.py
	$(PYTHON) scripts/generate_release_artifacts.py --check

protocol-surface-report: release-artifacts
	$(PYTHON) scripts/generate_protocol_surface_report.py

protocol-surface-report-check: release-artifacts-check
	$(PYTHON) scripts/test_protocol_surface_report.py
	$(PYTHON) scripts/generate_protocol_surface_report.py --check

custom-error-catalog: protocol-surface-report
	$(PYTHON) scripts/generate_custom_error_catalog.py

custom-error-catalog-check: protocol-surface-report-check
	$(PYTHON) scripts/test_custom_error_catalog.py
	$(PYTHON) scripts/generate_custom_error_catalog.py --check

natspec-coverage-check: protocol-surface-report-check
	$(PYTHON) scripts/test_natspec_coverage.py
	$(PYTHON) scripts/check_natspec_coverage.py

source-verification-inputs: release-artifacts
	$(PYTHON) scripts/generate_source_verification_inputs.py

source-verification-inputs-check: release-artifacts-check
	$(PYTHON) scripts/test_source_verification_inputs.py
	$(PYTHON) scripts/generate_source_verification_inputs.py --check

abi-compatibility: release-build-check
	$(PYTHON) scripts/check_abi_compatibility.py

abi-compatibility-check: release-build-check
	$(PYTHON) scripts/test_abi_compatibility.py
	$(PYTHON) scripts/check_abi_compatibility.py --check

broadcast-manifest-inputs:
	$(PYTHON) scripts/generate_broadcast_manifest_input.py

broadcast-manifest-inputs-check:
	$(PYTHON) scripts/test_broadcast_manifest_input.py
	$(PYTHON) scripts/generate_broadcast_manifest_input.py --check

deployment-manifests: release-artifacts broadcast-manifest-inputs
	$(PYTHON) scripts/generate_deployment_manifest.py
	$(PYTHON) scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json
	$(PYTHON) scripts/generate_deployment_manifest.py --config deployments/config/fork-mainnet-6529stream-v0.1.0-001.json
	$(PYTHON) scripts/generate_deployment_manifest.py --config deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json

deployment-manifest-check: broadcast-manifest-inputs-check
	$(PYTHON) scripts/test_deployment_manifest.py
	$(PYTHON) scripts/generate_deployment_manifest.py --check
	$(PYTHON) scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
	$(PYTHON) scripts/generate_deployment_manifest.py --config deployments/config/fork-mainnet-6529stream-v0.1.0-001.json --check
	$(PYTHON) scripts/generate_deployment_manifest.py --config deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --check

address-books: deployment-manifests
	$(PYTHON) scripts/generate_address_books.py

address-books-check: deployment-manifest-check
	$(PYTHON) scripts/test_address_books.py
	$(PYTHON) scripts/generate_address_books.py --check

dependency-artifacts:
	$(PYTHON) scripts/generate_dependency_artifact_manifest.py

dependency-artifacts-check:
	$(PYTHON) scripts/test_dependency_artifact_manifest.py
	$(PYTHON) scripts/generate_dependency_artifact_manifest.py --check

dependency-provenance-attestation: dependency-artifacts
	$(PYTHON) scripts/generate_dependency_provenance_attestation.py

dependency-provenance-attestation-check: dependency-artifacts-check
	$(PYTHON) scripts/test_dependency_provenance_attestation.py
	$(PYTHON) scripts/generate_dependency_provenance_attestation.py --check

ceremony-evidence-check:
	$(PYTHON) scripts/test_ceremony_evidence.py
	$(PYTHON) scripts/check_ceremony_evidence.py

randomizer-operations-check:
	$(PYTHON) scripts/test_randomizer_operations.py
	$(PYTHON) scripts/check_randomizer_operations.py

release-signatures-check:
	$(PYTHON) scripts/test_release_signatures.py
	$(PYTHON) scripts/check_release_signatures.py

signed-release-tag-check:
	$(PYTHON) scripts/test_signed_release_tag.py
	$(PYTHON) scripts/check_signed_release_tag.py

bytecode-release-proof: release-manifest
	$(PYTHON) scripts/generate_bytecode_release_proof.py

bytecode-release-proof-check: release-manifest-check
	$(PYTHON) scripts/test_bytecode_release_proof.py
	$(PYTHON) scripts/generate_bytecode_release_proof.py --check

release-candidate-lockfile: bytecode-release-proof
	$(PYTHON) scripts/generate_release_candidate_lockfile.py

release-candidate-lockfile-check: bytecode-release-proof-check
	$(PYTHON) scripts/test_release_candidate_lockfile.py
	$(PYTHON) scripts/generate_release_candidate_lockfile.py --check

non-local-release-evidence-check:
	$(PYTHON) scripts/test_non_local_release_evidence.py
	$(PYTHON) scripts/check_non_local_release_evidence.py

external-audit-report-evidence-check:
	$(PYTHON) scripts/test_external_audit_report_evidence.py
	$(PYTHON) scripts/check_external_audit_report_evidence.py

post-audit-remediation-evidence-check:
	$(PYTHON) scripts/test_post_audit_remediation_evidence.py
	$(PYTHON) scripts/check_post_audit_remediation_evidence.py

live-ceremony-evidence-check:
	$(PYTHON) scripts/test_live_ceremony_evidence.py
	$(PYTHON) scripts/check_live_ceremony_evidence.py

live-randomizer-operations-evidence-check:
	$(PYTHON) scripts/test_live_randomizer_operations_evidence.py
	$(PYTHON) scripts/check_live_randomizer_operations_evidence.py

fork-deployment-rehearsal-evidence-check:
	$(PYTHON) scripts/test_fork_deployment_rehearsal_evidence.py
	$(PYTHON) scripts/check_fork_deployment_rehearsal_evidence.py

testnet-deployment-rehearsal-evidence-check:
	$(PYTHON) scripts/test_testnet_deployment_rehearsal_evidence.py
	$(PYTHON) scripts/check_testnet_deployment_rehearsal_evidence.py

sepolia-evidence-preflight-check:
	$(PYTHON) scripts/test_sepolia_evidence_preflight.py
	$(PYTHON) scripts/check_sepolia_evidence_preflight.py

public-beta-verified-addresses-check:
	$(PYTHON) scripts/test_public_beta_verified_addresses.py
	$(PYTHON) scripts/check_public_beta_verified_addresses.py

production-broadcast-retention-check:
	$(PYTHON) scripts/test_production_broadcast_retention.py
	$(PYTHON) scripts/check_production_broadcast_retention.py

live-deployment-manifest-evidence-check:
	$(PYTHON) scripts/test_live_deployment_manifest_evidence.py
	$(PYTHON) scripts/check_live_deployment_manifest_evidence.py

production-verified-addresses-check:
	$(PYTHON) scripts/test_production_verified_addresses.py
	$(PYTHON) scripts/check_production_verified_addresses.py

production-release-signing-evidence-check:
	$(PYTHON) scripts/test_production_release_signing_evidence.py
	$(PYTHON) scripts/check_production_release_signing_evidence.py

fork-metadata-browser-evidence-check:
	$(PYTHON) scripts/test_generate_fork_metadata_browser_evidence_draft.py
	$(PYTHON) scripts/test_fork_metadata_browser_evidence.py
	$(PYTHON) scripts/check_fork_metadata_browser_evidence.py

fork-ceremony-evidence-check:
	$(PYTHON) scripts/test_fork_ceremony_evidence.py
	$(PYTHON) scripts/check_fork_ceremony_evidence.py

fork-randomizer-operations-evidence-check:
	$(PYTHON) scripts/test_fork_randomizer_operations_evidence.py
	$(PYTHON) scripts/check_fork_randomizer_operations_evidence.py

live-metadata-browser-evidence-check:
	$(PYTHON) scripts/test_live_metadata_browser_evidence.py
	$(PYTHON) scripts/check_live_metadata_browser_evidence.py

marketplace-indexer-evidence-check:
	$(PYTHON) scripts/test_marketplace_indexer_evidence.py
	$(PYTHON) scripts/check_marketplace_indexer_evidence.py

incident-drill-evidence-check:
	$(PYTHON) scripts/test_incident_drill_evidence.py
	$(PYTHON) scripts/check_incident_drill_evidence.py

signer-compromise-drill-evidence-check:
	$(PYTHON) scripts/test_signer_compromise_drill_evidence.py
	$(PYTHON) scripts/check_signer_compromise_drill_evidence.py

stuck-auction-drill-evidence-check:
	$(PYTHON) scripts/test_stuck_auction_drill_evidence.py
	$(PYTHON) scripts/check_stuck_auction_drill_evidence.py

failed-randomness-drill-evidence-check:
	$(PYTHON) scripts/test_failed_randomness_drill_evidence.py
	$(PYTHON) scripts/check_failed_randomness_drill_evidence.py

bad-metadata-dependency-drill-evidence-check:
	$(PYTHON) scripts/test_bad_metadata_dependency_drill_evidence.py
	$(PYTHON) scripts/check_bad_metadata_dependency_drill_evidence.py

public-beta-evidence-check:
	$(PYTHON) scripts/test_public_beta_evidence.py
	$(PYTHON) scripts/check_public_beta_evidence.py

risk-register:
	$(PYTHON) scripts/generate_risk_register.py

risk-register-check:
	$(PYTHON) scripts/test_risk_register.py
	$(PYTHON) scripts/check_risk_register.py
	$(PYTHON) scripts/generate_risk_register.py --check

public-beta-blocker-report:
	$(PYTHON) scripts/generate_public_beta_blocker_report.py

public-beta-blocker-report-check:
	$(PYTHON) scripts/test_public_beta_blocker_report.py
	$(PYTHON) scripts/generate_public_beta_blocker_report.py --check

production-release-blocker-report:
	$(PYTHON) scripts/generate_production_release_blocker_report.py

production-release-blocker-report-check:
	$(PYTHON) scripts/test_production_release_blocker_report.py
	$(PYTHON) scripts/generate_production_release_blocker_report.py --check

release-evidence-packet-index:
	$(PYTHON) scripts/generate_release_evidence_packet_index.py

release-evidence-packet-index-check:
	$(PYTHON) scripts/test_release_evidence_packet_index.py
	$(PYTHON) scripts/generate_release_evidence_packet_index.py --check

release-evidence-issue-backlog: release-evidence-packet-index
	$(PYTHON) scripts/generate_release_evidence_issue_backlog.py

release-evidence-issue-backlog-check: release-evidence-packet-index-check
	$(PYTHON) scripts/test_release_evidence_issue_backlog.py
	$(PYTHON) scripts/generate_release_evidence_issue_backlog.py --check

release-evidence-issue-links-check: release-evidence-issue-backlog-check
	$(PYTHON) scripts/test_release_evidence_issue_links.py
	$(PYTHON) scripts/check_release_evidence_issue_links.py

release-evidence-issue-labels-check: release-evidence-issue-links-check
	$(PYTHON) scripts/test_release_evidence_issue_snapshot.py
	$(PYTHON) scripts/test_release_evidence_issue_snapshot_audit.py
	$(PYTHON) scripts/test_release_evidence_issue_labels.py
	$(PYTHON) scripts/check_release_evidence_issue_labels.py

release-evidence-issue-body-sync: release-evidence-issue-labels-check
	$(PYTHON) scripts/generate_release_evidence_issue_body_sync.py

release-evidence-issue-body-sync-check: release-evidence-issue-labels-check
	$(PYTHON) scripts/test_release_evidence_issue_body_sync.py
	$(PYTHON) scripts/generate_release_evidence_issue_body_sync.py --check

release-evidence-issue-bodies-check: release-evidence-issue-body-sync-check
	$(PYTHON) scripts/test_release_evidence_issue_bodies.py
	$(PYTHON) scripts/test_release_evidence_issue_live_snapshot.py
	$(PYTHON) scripts/check_release_evidence_issue_bodies.py

release-evidence-issue-closure-check: release-evidence-issue-bodies-check
	$(PYTHON) scripts/test_release_evidence_issue_closure.py
	$(PYTHON) scripts/check_release_evidence_issue_closure.py

release-evidence-live-issue-snapshot: release-evidence-issue-closure-check
	$(PYTHON) scripts/fetch_release_evidence_issue_snapshot.py --output tmp/release-evidence-live-issues.json

release-evidence-live-issue-sync-check: release-evidence-live-issue-snapshot
	$(PYTHON) scripts/check_release_evidence_issue_bodies.py --live-json tmp/release-evidence-live-issues.json
	$(PYTHON) scripts/check_release_evidence_issue_closure.py --live-json tmp/release-evidence-live-issues.json

release-evidence-live-audit-report-check: release-evidence-issue-closure-check
	$(PYTHON) scripts/test_release_evidence_live_audit_report.py
	$(PYTHON) scripts/check_release_evidence_live_audit_report.py

release-evidence-live-audit-markdown-check: release-evidence-live-audit-report-check
	$(PYTHON) scripts/test_release_evidence_live_audit_markdown.py
	$(PYTHON) scripts/check_release_evidence_live_audit_markdown.py

release-evidence-live-audit-archive: release-evidence-live-audit-markdown-check
	$(PYTHON) scripts/generate_release_evidence_live_audit_archive.py

release-evidence-live-audit-archive-check: release-evidence-live-audit-markdown-check
	$(PYTHON) scripts/test_release_evidence_live_audit_archive.py
	$(PYTHON) scripts/generate_release_evidence_live_audit_archive.py --check

architecture-threat-model-check:
	$(PYTHON) scripts/test_architecture_threat_model.py
	$(PYTHON) scripts/check_architecture_threat_model.py

audit-package-check:
	$(PYTHON) scripts/test_audit_package.py
	$(PYTHON) scripts/check_audit_package.py

audit-finding-workflow-check:
	$(PYTHON) scripts/test_audit_finding_workflow.py
	$(PYTHON) scripts/check_audit_finding_workflow.py

incident-response-check:
	$(PYTHON) scripts/test_incident_response.py
	$(PYTHON) scripts/check_incident_response.py

readme-check:
	$(PYTHON) scripts/test_readme.py
	$(PYTHON) scripts/check_readme.py

first-30-minutes-check:
	$(PYTHON) scripts/test_first_30_minutes.py
	$(PYTHON) scripts/check_first_30_minutes.py

issue-templates-check:
	$(PYTHON) scripts/test_issue_templates.py
	$(PYTHON) scripts/check_issue_templates.py

pr-template-check:
	$(PYTHON) scripts/test_pr_template.py
	$(PYTHON) scripts/check_pr_template.py

autonomous-state-check:
	$(PYTHON) scripts/test_autonomous_state.py
	$(PYTHON) scripts/check_autonomous_state.py

markdown-links-check:
	$(PYTHON) scripts/test_markdown_links.py
	$(PYTHON) scripts/check_markdown_links.py

integrations-readme-check:
	$(PYTHON) scripts/test_integrations_readme.py
	$(PYTHON) scripts/check_integrations_readme.py

contract-flows-check:
	$(PYTHON) scripts/test_contract_flows.py
	$(PYTHON) scripts/check_contract_flows.py

auction-flows-check:
	$(PYTHON) scripts/test_auction_flows.py
	$(PYTHON) scripts/check_auction_flows.py

curator-rewards-check:
	$(PYTHON) scripts/test_curator_rewards_flow.py
	$(PYTHON) scripts/check_curator_rewards_flow.py

withdrawals-credits-check:
	$(PYTHON) scripts/test_withdrawals_credits_flow.py
	$(PYTHON) scripts/check_withdrawals_credits_flow.py

wallet-signature-flows-check:
	$(PYTHON) scripts/test_wallet_signature_flows.py
	$(PYTHON) scripts/check_wallet_signature_flows.py

events-and-indexing-check:
	$(PYTHON) scripts/test_events_and_indexing.py
	$(PYTHON) scripts/check_events_and_indexing.py

metadata-rendering-check:
	$(PYTHON) scripts/test_metadata_rendering.py
	$(PYTHON) scripts/check_metadata_rendering.py

react-next-reference-check:
	$(PYTHON) scripts/test_react_next_reference.py
	$(PYTHON) scripts/check_react_next_reference.py

typescript-artifact-chain-config-check:
	$(PYTHON) scripts/test_typescript_artifact_chain_config.py
	$(PYTHON) scripts/check_typescript_artifact_chain_config.py

typescript-eip712-drop-authorization-check:
	$(PYTHON) scripts/test_typescript_eip712_drop_authorization.py
	$(PYTHON) scripts/check_typescript_eip712_drop_authorization.py

typescript-event-decoding-indexer-check:
	$(PYTHON) scripts/test_typescript_event_decoding_indexer.py
	$(PYTHON) scripts/check_typescript_event_decoding_indexer.py

integration-conformance-fixtures-check:
	$(PYTHON) scripts/test_integration_conformance_fixtures.py
	$(PYTHON) scripts/check_integration_conformance_fixtures.py

mobile-walletconnect-check:
	$(PYTHON) scripts/test_mobile_walletconnect.py
	$(PYTHON) scripts/check_mobile_walletconnect.py

electron-security-wallets-check:
	$(PYTHON) scripts/test_electron_security_wallets.py
	$(PYTHON) scripts/check_electron_security_wallets.py

operator-admin-ui-check:
	$(PYTHON) scripts/test_operator_admin_ui.py
	$(PYTHON) scripts/check_operator_admin_ui.py

operator-dashboard-query-model-check:
	$(PYTHON) scripts/test_operator_dashboard_query_model.py
	$(PYTHON) scripts/check_operator_dashboard_query_model.py

monitoring-spec-check:
	$(PYTHON) scripts/test_monitoring_spec.py
	$(PYTHON) scripts/check_monitoring_spec.py

royalty-policy-check:
	$(PYTHON) scripts/test_royalty_policy.py
	$(PYTHON) scripts/check_royalty_policy.py

warning-dispositions-check: size
	$(PYTHON) scripts/test_warning_dispositions.py
	$(PYTHON) scripts/check_warning_dispositions.py --solc-warnings-log cache/forge-size.log

genesis-deployment-profile-check:
	$(PYTHON) scripts/test_genesis_deployment_profile.py
	$(PYTHON) scripts/check_genesis_deployment_profile.py

system-manifest-payload-vector:
	$(PYTHON) scripts/generate_system_manifest_payload_vector.py

system-manifest-payload-vector-check:
	$(PYTHON) scripts/test_system_manifest_payload_vector.py
	$(PYTHON) scripts/check_system_manifest_payload_vector.py
	$(PYTHON) scripts/test_system_manifest_payload_vector_reference.py
	$(PYTHON) scripts/check_system_manifest_payload_vector_reference.py

slither-baseline-metadata-check:
	$(PYTHON) scripts/test_slither_baseline.py
	$(PYTHON) scripts/check_slither_baseline.py --baseline-only

slither-baseline-check: slither-baseline-metadata-check
	$(PYTHON) scripts/check_slither_baseline.py --run-slither

release-readiness-check:
	$(PYTHON) scripts/test_release_readiness.py
	$(PYTHON) scripts/check_release_readiness.py
	$(PYTHON) scripts/test_release_mode.py

release-mode-public-beta-check: check slither-baseline-check
	$(PYTHON) scripts/test_release_mode.py
	$(PYTHON) scripts/check_release_mode.py --phase public-beta

release-mode-production-release-check: check slither-baseline-check
	$(PYTHON) scripts/test_release_mode.py
	$(PYTHON) scripts/check_release_mode.py --phase production-release

release-mode-check: release-mode-production-release-check

release-notes:
	$(PYTHON) scripts/generate_release_notes.py

release-notes-check:
	$(PYTHON) scripts/test_release_notes.py
	$(PYTHON) scripts/generate_release_notes.py --check

release-manifest: address-books protocol-surface-report custom-error-catalog natspec-coverage-check source-verification-inputs dependency-provenance-attestation one-of-one-provenance-manifest one-of-one-permanence-manifest ceremony-evidence-check randomizer-operations-check release-signatures-check non-local-release-evidence-check external-audit-report-evidence-check post-audit-remediation-evidence-check live-ceremony-evidence-check live-randomizer-operations-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check sepolia-evidence-preflight-check public-beta-verified-addresses-check production-broadcast-retention-check live-deployment-manifest-evidence-check production-verified-addresses-check production-release-signing-evidence-check fork-metadata-browser-evidence-check live-metadata-browser-evidence-check marketplace-indexer-evidence-check incident-drill-evidence-check signer-compromise-drill-evidence-check stuck-auction-drill-evidence-check failed-randomness-drill-evidence-check bad-metadata-dependency-drill-evidence-check drop-authorization-signing-evidence-check signer-custody-readiness-check public-beta-evidence-check risk-register public-beta-blocker-report-check production-release-blocker-report-check release-evidence-packet-index-check release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-audit-markdown-check architecture-threat-model-check audit-package-check audit-finding-workflow-check incident-response-check readme-check first-30-minutes-check issue-templates-check pr-template-check markdown-links-check integrations-readme-check contract-flows-check auction-flows-check curator-rewards-check withdrawals-credits-check wallet-signature-flows-check events-and-indexing-check metadata-rendering-check react-next-reference-check typescript-artifact-chain-config-check typescript-eip712-drop-authorization-check typescript-event-decoding-indexer-check integration-conformance-fixtures-check mobile-walletconnect-check electron-security-wallets-check operator-admin-ui-check operator-dashboard-query-model-check monitoring-spec-check royalty-policy-check warning-dispositions-check core-bytecode-spend-policy-check drop-authorization-fixtures-check release-readiness-check release-notes
	$(PYTHON) scripts/generate_release_manifest.py

release-manifest-check: address-books-check protocol-surface-report-check custom-error-catalog-check natspec-coverage-check source-verification-inputs-check dependency-provenance-attestation-check one-of-one-provenance-manifest-check one-of-one-permanence-manifest-check ceremony-evidence-check randomizer-operations-check release-signatures-check non-local-release-evidence-check external-audit-report-evidence-check post-audit-remediation-evidence-check live-ceremony-evidence-check live-randomizer-operations-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check sepolia-evidence-preflight-check public-beta-verified-addresses-check production-broadcast-retention-check live-deployment-manifest-evidence-check production-verified-addresses-check production-release-signing-evidence-check fork-metadata-browser-evidence-check live-metadata-browser-evidence-check marketplace-indexer-evidence-check incident-drill-evidence-check signer-compromise-drill-evidence-check stuck-auction-drill-evidence-check failed-randomness-drill-evidence-check bad-metadata-dependency-drill-evidence-check drop-authorization-signing-evidence-check signer-custody-readiness-check public-beta-evidence-check risk-register-check public-beta-blocker-report-check production-release-blocker-report-check release-evidence-packet-index-check release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-audit-markdown-check architecture-threat-model-check audit-package-check audit-finding-workflow-check incident-response-check readme-check first-30-minutes-check issue-templates-check pr-template-check markdown-links-check integrations-readme-check contract-flows-check auction-flows-check curator-rewards-check withdrawals-credits-check wallet-signature-flows-check events-and-indexing-check metadata-rendering-check react-next-reference-check typescript-artifact-chain-config-check typescript-eip712-drop-authorization-check typescript-event-decoding-indexer-check integration-conformance-fixtures-check mobile-walletconnect-check electron-security-wallets-check operator-admin-ui-check operator-dashboard-query-model-check monitoring-spec-check royalty-policy-check warning-dispositions-check core-bytecode-spend-policy-check drop-authorization-fixtures-check release-readiness-check release-notes-check
	$(PYTHON) scripts/test_release_manifest.py
	$(PYTHON) scripts/generate_release_manifest.py --check

release-checksums: release-candidate-lockfile
	$(PYTHON) scripts/generate_release_checksums.py

release-checksums-check: release-candidate-lockfile-check
	$(PYTHON) scripts/test_release_checksums.py
	$(PYTHON) scripts/generate_release_checksums.py --check

release-artifacts-verify: release-checksums-check
	$(PYTHON) scripts/test_verify_release_artifacts.py
	$(PYTHON) scripts/verify_release_artifacts.py

changelog-check:
	$(PYTHON) scripts/test_changelog_check.py
	$(PYTHON) scripts/check_changelog.py

solidity-formatting-check:
	$(PYTHON) scripts/test_solidity_formatting.py
	$(PYTHON) scripts/check_solidity_formatting.py

fmt-check: solidity-formatting-check

slither:
	slither . --config-file slither.config.json --foundry-compile-all

clean:
	$(RM_RF)
