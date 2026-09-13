.DEFAULT_GOAL := help
check: export FOUNDRY_PROFILE := default

ifeq ($(OS),Windows_NT)
PYTHON ?= python
POWERSHELL ?= powershell
POWERSHELL_FLAGS ?= -NoProfile -ExecutionPolicy Bypass
ifdef MSYSTEM
FOUNDRY_BIN := $(HOME)/.foundry/bin
REPO_ROOT := $(shell pwd)
PATH_SEPARATOR := :
else
FOUNDRY_BIN := $(USERPROFILE)/.foundry/bin
REPO_ROOT := $(CURDIR)
PATH_SEPARATOR := ;
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
endif
PATH := $(FOUNDRY_BIN)$(PATH_SEPARATOR)$(REPO_ROOT)/$(VENV_BIN)$(PATH_SEPARATOR)$(PATH)

.PHONY: check build test gas-snapshot gas-snapshot-check gas-envelopes-check royalty-return-gas-buffer-check size release-build release-build-check contract-size-budget-check core-bytecode-spend-policy-check genesis-deployment-profile-check system-manifest-payload-vector system-manifest-payload-vector-check slither-baseline-metadata-check slither-baseline-check deployment-rehearsal-gate-check deploy-rehearsal deploy-rehearsal-standalone metadata-fixtures-check windows-check-wrapper-policy windows-check-wrapper-runtime drop-authorization-fixtures-check drop-authorization-signing-evidence-check signer-custody-readiness-check one-of-one-provenance-manifest one-of-one-provenance-manifest-check one-of-one-permanence-manifest one-of-one-permanence-manifest-check admin-ceremony-evidence-check solidity-formatting-check solidity-source-layout-check release-artifacts release-artifacts-check protocol-surface-report protocol-surface-report-check custom-error-catalog custom-error-catalog-check natspec-coverage-check source-verification-inputs source-verification-inputs-check abi-compatibility abi-compatibility-check broadcast-manifest-inputs broadcast-manifest-inputs-check deployment-manifests deployment-manifest-check address-books address-books-check dependency-artifacts dependency-artifacts-check dependency-provenance-attestation dependency-provenance-attestation-check ceremony-evidence-check randomizer-operations-check release-signatures-check signed-release-tag-check bytecode-release-proof bytecode-release-proof-check release-candidate-lockfile release-candidate-lockfile-check non-local-release-evidence-check external-audit-report-evidence-check post-audit-remediation-evidence-check live-ceremony-evidence-check live-randomizer-operations-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check sepolia-evidence-preflight-check public-beta-verified-addresses-check production-broadcast-retention-check live-deployment-manifest-evidence-check production-verified-addresses-check production-release-signing-evidence-check fork-metadata-browser-evidence-check live-metadata-browser-evidence-check marketplace-indexer-evidence-check incident-drill-evidence-check signer-compromise-drill-evidence-check stuck-auction-drill-evidence-check failed-randomness-drill-evidence-check bad-metadata-dependency-drill-evidence-check public-beta-evidence-check public-beta-blocker-report public-beta-blocker-report-check production-release-blocker-report production-release-blocker-report-check release-evidence-packet-index release-evidence-packet-index-check release-evidence-issue-backlog release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-labels-check release-evidence-issue-body-sync release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-issue-snapshot release-evidence-live-issue-sync-check release-evidence-live-audit-report-check release-evidence-live-audit-markdown-check release-evidence-live-audit-archive release-evidence-live-audit-archive-check architecture-threat-model-check audit-package-check audit-finding-workflow-check incident-response-check readme-check first-30-minutes-check issue-templates-check pr-template-check autonomous-state-check markdown-links-check integrations-readme-check contract-flows-check auction-flows-check curator-rewards-check withdrawals-credits-check wallet-signature-flows-check events-and-indexing-check metadata-rendering-check react-next-reference-check typescript-artifact-chain-config-check typescript-eip712-drop-authorization-check typescript-event-decoding-indexer-check integration-conformance-fixtures-check mobile-walletconnect-check electron-security-wallets-check operator-admin-ui-check operator-dashboard-query-model-check monitoring-spec-check royalty-policy-check warning-dispositions-check release-readiness-check release-mode-public-beta-check release-mode-production-release-check release-mode-check release-notes release-notes-check release-manifest release-manifest-check release-artifacts-verify release-checksums release-checksums-check changelog-check fmt-check slither clean
check: all-build all-test gas-snapshot-check gas-envelopes-check royalty-return-gas-buffer-check size release-build-check contract-size-budget-check core-bytecode-spend-policy-check genesis-deployment-profile-check system-manifest-payload-vector-check slither-baseline-metadata-check solidity-formatting-check solidity-source-layout-check windows-check-wrapper-policy metadata-fixtures-check drop-authorization-fixtures-check drop-authorization-signing-evidence-check signer-custody-readiness-check one-of-one-provenance-manifest-check one-of-one-permanence-manifest-check admin-ceremony-evidence-check release-artifacts-check protocol-surface-report-check custom-error-catalog-check natspec-coverage-check source-verification-inputs-check abi-compatibility-check dependency-provenance-attestation-check signed-release-tag-check non-local-release-evidence-check external-audit-report-evidence-check post-audit-remediation-evidence-check live-ceremony-evidence-check live-randomizer-operations-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check sepolia-evidence-preflight-check public-beta-verified-addresses-check production-broadcast-retention-check live-deployment-manifest-evidence-check production-verified-addresses-check production-release-signing-evidence-check fork-metadata-browser-evidence-check live-metadata-browser-evidence-check marketplace-indexer-evidence-check incident-drill-evidence-check signer-compromise-drill-evidence-check stuck-auction-drill-evidence-check failed-randomness-drill-evidence-check bad-metadata-dependency-drill-evidence-check public-beta-evidence-check public-beta-blocker-report-check production-release-blocker-report-check release-evidence-packet-index-check release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-labels-check release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-audit-archive-check architecture-threat-model-check audit-package-check audit-finding-workflow-check incident-response-check readme-check first-30-minutes-check issue-templates-check pr-template-check autonomous-state-check markdown-links-check integrations-readme-check contract-flows-check auction-flows-check curator-rewards-check withdrawals-credits-check wallet-signature-flows-check events-and-indexing-check metadata-rendering-check react-next-reference-check typescript-artifact-chain-config-check typescript-eip712-drop-authorization-check typescript-event-decoding-indexer-check integration-conformance-fixtures-check mobile-walletconnect-check electron-security-wallets-check operator-admin-ui-check operator-dashboard-query-model-check monitoring-spec-check royalty-policy-check warning-dispositions-check release-readiness-check release-notes-check release-artifacts-verify changelog-check deployment-rehearsal-gate-check deploy-rehearsal canonical-deployment-plan-check
check: fork-ceremony-evidence-check fork-randomizer-operations-evidence-check
check: python-toolchain-check
check: external-call-gas-inventory-check
check: post-entropy-completion-gas-check
release-manifest: fork-ceremony-evidence-check fork-randomizer-operations-evidence-check
release-manifest-check: fork-ceremony-evidence-check fork-randomizer-operations-evidence-check
.PHONY: fork-ceremony-evidence-check fork-randomizer-operations-evidence-check
.PHONY: python-toolchain-check
.PHONY: external-call-gas-inventory-check
.PHONY: post-entropy-completion-gas-check
.PHONY: canonical-deployment-plan-check
.PHONY: governed-parameter-identifiers-check
.PHONY: governed-parameter-inventory-check
.PHONY: governance-action-policy-check
.PHONY: record-family-authorization-check artist-semantic-owner-matrix-check artist-record-event-reconstruction-correction-check artist-owner-record-continuity-check
.PHONY: artist-operation-extension-check frozen-artist-runner-check
check: artist-operation-extension-check frozen-artist-runner-check
check: governed-parameter-identifiers-check
check: governed-parameter-inventory-check
check: governance-action-policy-check
check: record-family-authorization-check artist-semantic-owner-matrix-check artist-record-event-reconstruction-correction-check artist-owner-record-continuity-check

.PHONY: current-stack-check
current-stack-check: export FOUNDRY_PROFILE := current
current-stack-check:
	forge build
	forge test -vvv
	$(PYTHON) -m tools.protocol.test_artist_operation_extension
	$(PYTHON) -m tools.protocol.check_artist_operation_extension
	$(PYTHON) -m tools.build.test_release_artifacts
	$(PYTHON) -m tools.deployment.test_current_stack_artifacts
	$(PYTHON) -m tools.deployment.test_prepare_current_stack_compilation
	$(PYTHON) -m tools.deployment.test_current_stack_deployment_verification
	$(PYTHON) -m tools.deployment.test_current_stack_observations
	$(PYTHON) -m tools.build.check_solidity_formatting
	$(PYTHON) -m tools.build.check_solidity_source_layout
	$(PYTHON) -m tools.build.check_abi_compatibility --target-only

build:
	$(PYTHON) scripts/dev.py build

test:
	$(PYTHON) scripts/dev.py test

.PHONY: all-build all-test
all-build: export FOUNDRY_PROFILE := default
all-build:
	forge build

all-test: export FOUNDRY_PROFILE := default
all-test:
	forge test -vvv

gas-snapshot:
	forge snapshot --match-path test/gas/StreamGasSnapshot.t.sol --snap release-artifacts/baselines/v0.1.0/gas-snapshot.snap

gas-snapshot-check:
	forge snapshot --match-path test/gas/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap

gas-envelopes-check:
	$(PYTHON) -m tools.protocol.test_gas_envelopes
	$(PYTHON) -m tools.protocol.check_gas_envelopes

external-call-gas-inventory-check:
	$(PYTHON) -m tools.protocol.test_external_call_gas_inventory
	$(PYTHON) -m tools.protocol.check_external_call_gas_inventory

post-entropy-completion-gas-check:
	$(PYTHON) -m tools.protocol.test_post_entropy_completion_gas
	$(PYTHON) -m tools.protocol.generate_post_entropy_completion_gas --check
	$(PYTHON) -m tools.protocol.check_post_entropy_completion_gas
	forge test --via-ir --match-path test/gas/StreamPostEntropyCompletionGas.t.sol -vvv
	forge snapshot --via-ir --match-path test/gas/StreamPostEntropyCompletionGas.t.sol --match-test testMeasureWorstCaseEoaPostCoordinatorTail --check release-artifacts/baselines/v0.1.0/post-entropy-completion-gas.snap

royalty-return-gas-buffer-check:
	$(PYTHON) -m tools.protocol.test_royalty_return_gas_buffer
	$(PYTHON) -m tools.protocol.generate_royalty_return_gas_buffer --check
	$(PYTHON) -m tools.protocol.check_royalty_return_gas_buffer
	forge test --via-ir --match-path test/gas/StreamRoyaltyReturnGasBuffer.t.sol -vvv
	forge snapshot --via-ir --match-path test/gas/StreamRoyaltyReturnGasBuffer.t.sol --match-test testMeasure --check release-artifacts/baselines/v0.1.0/royalty-return-gas-buffer.snap

# Aggregate diagnostic only; canonical release bytecode is built by release-build.
size:
	$(PYTHON) -m tools.build.run_forge_size_log --log cache/forge-size.log

release-build:
	$(PYTHON) -m tools.build.test_release_build_artifacts
	$(PYTHON) -m tools.build.build_release_artifacts

release-build-check: release-build
	$(PYTHON) -m tools.build.build_release_artifacts --check

canonical-deployment-plan-check: release-build-check
	$(PYTHON) -m tools.deployment.test_canonical_deployment_candidate
	$(PYTHON) -m tools.deployment.check_canonical_deployment_candidate
	@if $(PYTHON) -m tools.deployment.check_canonical_deployment_candidate --require-complete; then echo "expected incomplete canonical deployment candidate v2" >&2; exit 1; else status=$$?; if [ $$status -ne 1 ]; then exit $$status; fi; fi
	$(PYTHON) -m tools.deployment.test_materialize_canonical_deployment_plan
	$(PYTHON) -m tools.deployment.materialize_canonical_deployment_plan --candidate deployments/config/canonical-deployment-candidate-non-production.json --output tmp/canonical-deployment-plan.json
	$(PYTHON) -m tools.deployment.materialize_canonical_deployment_plan --candidate deployments/config/canonical-deployment-candidate-non-production.json --output tmp/canonical-deployment-plan.json --check

contract-size-budget-check: size release-build-check
	$(PYTHON) -m tools.build.test_contract_size_budget
	$(PYTHON) -m tools.build.check_contract_size_budget

core-bytecode-spend-policy-check: size release-build-check
	$(PYTHON) -m tools.build.test_core_bytecode_spend_policy
	$(PYTHON) -m tools.build.check_core_bytecode_spend_policy

deployment-rehearsal-gate-check:
	$(PYTHON) -m tools.deployment.test_deployment_rehearsal_gate
	$(PYTHON) -m tools.deployment.check_deployment_rehearsal_gate

deploy-rehearsal:
	forge script script/legacy/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite --sig "run()" --via-ir

deploy-rehearsal-standalone:
	forge script script/legacy/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
	forge script script/legacy/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
	forge script script/legacy/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir

metadata-fixtures-check:
	$(PYTHON) -m tools.protocol.test_metadata_fixtures
	$(PYTHON) -m tools.protocol.check_metadata_fixtures
	$(PYTHON) -m tools.deployment.test_metadata_browser_sandbox
	$(PYTHON) -m tools.deployment.check_metadata_browser_sandbox
	$(PYTHON) -m tools.deployment.test_rehearsal_metadata_browser_sandbox
	$(PYTHON) -m tools.deployment.check_rehearsal_metadata_browser_sandbox

windows-check-wrapper-policy:
	$(PYTHON) -m tools.development.test_windows_check_wrapper
	$(PYTHON) -m tools.development.test_windows_ci_wrapper

windows-check-wrapper-runtime:
	$(POWERSHELL) $(POWERSHELL_FLAGS) -File scripts/test_windows_check_helpers.ps1

python-toolchain-check:
	$(PYTHON) -m tools.development.test_python_toolchain
	$(PYTHON) -m tools.development.check_python_toolchain

solidity-source-layout-check:
	$(PYTHON) -m tools.build.test_solidity_source_layout
	$(PYTHON) -m tools.build.check_solidity_source_layout
	$(PYTHON) -m tools.build.test_solidity_layout_equivalence
	$(PYTHON) -m tools.build.check_solidity_layout_equivalence --check-receipt
	$(PYTHON) -m tools.development.check_legacy_snapshot

drop-authorization-fixtures-check:
	$(PYTHON) -m tools.protocol.test_drop_authorization_payload_generator
	$(PYTHON) -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
	$(PYTHON) -m tools.protocol.generate_drop_authorization_payload --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
	$(PYTHON) -m tools.protocol.test_drop_authorization_fixtures
	$(PYTHON) -m tools.protocol.check_drop_authorization_fixtures

drop-authorization-signing-evidence-check:
	$(PYTHON) -m tools.release.test_drop_authorization_signing_evidence
	$(PYTHON) -m tools.release.check_drop_authorization_signing_evidence

signer-custody-readiness-check:
	$(PYTHON) -m tools.release.test_signer_custody_readiness
	$(PYTHON) -m tools.release.check_signer_custody_readiness

one-of-one-provenance-manifest:
	$(PYTHON) -m tools.protocol.generate_one_of_one_provenance_manifest

one-of-one-provenance-manifest-check:
	$(PYTHON) -m tools.protocol.test_one_of_one_provenance_manifest
	$(PYTHON) -m tools.protocol.check_one_of_one_provenance_manifest
	$(PYTHON) -m tools.protocol.generate_one_of_one_provenance_manifest --check

one-of-one-permanence-manifest:
	$(PYTHON) -m tools.protocol.generate_one_of_one_permanence_manifest

one-of-one-permanence-manifest-check:
	$(PYTHON) -m tools.protocol.test_one_of_one_permanence_package
	$(PYTHON) -m tools.protocol.check_one_of_one_permanence_package
	$(PYTHON) -m tools.protocol.generate_one_of_one_permanence_manifest --check

admin-ceremony-evidence-check:
	$(PYTHON) -m tools.deployment.test_admin_ceremony_evidence
	$(PYTHON) -m tools.deployment.check_admin_ceremony_evidence

release-artifacts: release-build-check
	$(PYTHON) -m tools.build.generate_release_artifacts

release-artifacts-check: release-build-check
	$(PYTHON) -m tools.build.test_release_artifacts
	$(PYTHON) -m tools.build.generate_release_artifacts --check

protocol-surface-report: release-artifacts
	$(PYTHON) -m tools.build.generate_protocol_surface_report

protocol-surface-report-check: release-artifacts-check
	$(PYTHON) -m tools.build.test_protocol_surface_report
	$(PYTHON) -m tools.build.generate_protocol_surface_report --check

custom-error-catalog: protocol-surface-report
	$(PYTHON) -m tools.build.generate_custom_error_catalog

custom-error-catalog-check: protocol-surface-report-check
	$(PYTHON) -m tools.build.test_custom_error_catalog
	$(PYTHON) -m tools.build.generate_custom_error_catalog --check

natspec-coverage-check: protocol-surface-report-check
	$(PYTHON) -m tools.build.test_natspec_coverage
	$(PYTHON) -m tools.build.check_natspec_coverage

source-verification-inputs: release-artifacts
	$(PYTHON) -m tools.build.generate_source_verification_inputs

source-verification-inputs-check: release-artifacts-check
	$(PYTHON) -m tools.build.test_source_verification_inputs
	$(PYTHON) -m tools.build.generate_source_verification_inputs --check

abi-compatibility: release-build-check
	$(PYTHON) -m tools.build.check_abi_compatibility

abi-compatibility-check: release-build-check
	$(PYTHON) -m tools.build.test_abi_compatibility
	$(PYTHON) -m tools.build.check_abi_compatibility --check

broadcast-manifest-inputs:
	$(PYTHON) -m tools.deployment.generate_broadcast_manifest_input

broadcast-manifest-inputs-check:
	$(PYTHON) -m tools.deployment.test_broadcast_manifest_input
	$(PYTHON) -m tools.deployment.generate_broadcast_manifest_input --check

deployment-manifests: release-artifacts broadcast-manifest-inputs
	$(PYTHON) -m tools.deployment.generate_deployment_manifest
	$(PYTHON) -m tools.deployment.generate_deployment_manifest --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json
	$(PYTHON) -m tools.deployment.generate_deployment_manifest --config deployments/config/fork-mainnet-6529stream-v0.1.0-001.json
	$(PYTHON) -m tools.deployment.generate_deployment_manifest --config deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json

deployment-manifest-check: broadcast-manifest-inputs-check
	$(PYTHON) -m tools.deployment.test_deployment_manifest
	$(PYTHON) -m tools.deployment.generate_deployment_manifest --check
	$(PYTHON) -m tools.deployment.generate_deployment_manifest --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check
	$(PYTHON) -m tools.deployment.generate_deployment_manifest --config deployments/config/fork-mainnet-6529stream-v0.1.0-001.json --check
	$(PYTHON) -m tools.deployment.generate_deployment_manifest --config deployments/config/fork-mainnet-6529stream-v0.1.0-001-broadcast.json --check

address-books: deployment-manifests
	$(PYTHON) -m tools.deployment.generate_address_books

address-books-check: deployment-manifest-check
	$(PYTHON) -m tools.deployment.test_address_books
	$(PYTHON) -m tools.deployment.generate_address_books --check

dependency-artifacts:
	$(PYTHON) -m tools.protocol.generate_dependency_artifact_manifest

dependency-artifacts-check:
	$(PYTHON) -m tools.protocol.test_dependency_artifact_manifest
	$(PYTHON) -m tools.protocol.generate_dependency_artifact_manifest --check

dependency-provenance-attestation: dependency-artifacts
	$(PYTHON) -m tools.protocol.generate_dependency_provenance_attestation

dependency-provenance-attestation-check: dependency-artifacts-check
	$(PYTHON) -m tools.protocol.test_dependency_provenance_attestation
	$(PYTHON) -m tools.protocol.generate_dependency_provenance_attestation --check

ceremony-evidence-check:
	$(PYTHON) -m tools.deployment.test_ceremony_evidence
	$(PYTHON) -m tools.deployment.check_ceremony_evidence

randomizer-operations-check:
	$(PYTHON) -m tools.deployment.test_randomizer_operations
	$(PYTHON) -m tools.deployment.check_randomizer_operations

release-signatures-check:
	$(PYTHON) -m tools.release.test_release_signatures
	$(PYTHON) -m tools.release.check_release_signatures

signed-release-tag-check:
	$(PYTHON) -m tools.release.test_signed_release_tag
	$(PYTHON) -m tools.release.check_signed_release_tag

bytecode-release-proof: release-manifest
	$(PYTHON) -m tools.build.generate_bytecode_release_proof

bytecode-release-proof-check: release-manifest-check
	$(PYTHON) -m tools.build.test_bytecode_release_proof
	$(PYTHON) -m tools.build.generate_bytecode_release_proof --check

release-candidate-lockfile: bytecode-release-proof
	$(PYTHON) -m tools.release.generate_release_candidate_lockfile

release-candidate-lockfile-check: bytecode-release-proof-check
	$(PYTHON) -m tools.release.test_release_candidate_lockfile
	$(PYTHON) -m tools.release.generate_release_candidate_lockfile --check

non-local-release-evidence-check:
	$(PYTHON) -m tools.release.test_non_local_release_evidence
	$(PYTHON) -m tools.release.check_non_local_release_evidence

external-audit-report-evidence-check:
	$(PYTHON) -m tools.release.test_external_audit_report_evidence
	$(PYTHON) -m tools.release.check_external_audit_report_evidence

post-audit-remediation-evidence-check:
	$(PYTHON) -m tools.release.test_post_audit_remediation_evidence
	$(PYTHON) -m tools.release.check_post_audit_remediation_evidence

live-ceremony-evidence-check:
	$(PYTHON) -m tools.deployment.test_live_ceremony_evidence
	$(PYTHON) -m tools.deployment.check_live_ceremony_evidence

live-randomizer-operations-evidence-check:
	$(PYTHON) -m tools.deployment.test_live_randomizer_operations_evidence
	$(PYTHON) -m tools.deployment.check_live_randomizer_operations_evidence

fork-deployment-rehearsal-evidence-check:
	$(PYTHON) -m tools.deployment.test_fork_deployment_rehearsal_evidence
	$(PYTHON) -m tools.deployment.check_fork_deployment_rehearsal_evidence

testnet-deployment-rehearsal-evidence-check:
	$(PYTHON) -m tools.deployment.test_testnet_deployment_rehearsal_evidence
	$(PYTHON) -m tools.deployment.check_testnet_deployment_rehearsal_evidence

sepolia-evidence-preflight-check:
	$(PYTHON) -m tools.deployment.test_sepolia_evidence_preflight
	$(PYTHON) -m tools.deployment.check_sepolia_evidence_preflight

public-beta-verified-addresses-check:
	$(PYTHON) -m tools.release.test_public_beta_verified_addresses
	$(PYTHON) -m tools.release.check_public_beta_verified_addresses

production-broadcast-retention-check:
	$(PYTHON) -m tools.release.test_production_broadcast_retention
	$(PYTHON) -m tools.release.check_production_broadcast_retention

live-deployment-manifest-evidence-check:
	$(PYTHON) -m tools.release.test_live_deployment_manifest_evidence
	$(PYTHON) -m tools.release.check_live_deployment_manifest_evidence

production-verified-addresses-check:
	$(PYTHON) -m tools.release.test_production_verified_addresses
	$(PYTHON) -m tools.release.check_production_verified_addresses

production-release-signing-evidence-check:
	$(PYTHON) -m tools.release.test_production_release_signing_evidence
	$(PYTHON) -m tools.release.check_production_release_signing_evidence

fork-metadata-browser-evidence-check:
	$(PYTHON) -m tools.release.test_generate_fork_metadata_browser_evidence_draft
	$(PYTHON) -m tools.release.test_fork_metadata_browser_evidence
	$(PYTHON) -m tools.release.check_fork_metadata_browser_evidence

fork-ceremony-evidence-check:
	$(PYTHON) -m tools.deployment.test_fork_ceremony_evidence
	$(PYTHON) -m tools.deployment.check_fork_ceremony_evidence

fork-randomizer-operations-evidence-check:
	$(PYTHON) -m tools.deployment.test_fork_randomizer_operations_evidence
	$(PYTHON) -m tools.deployment.check_fork_randomizer_operations_evidence

live-metadata-browser-evidence-check:
	$(PYTHON) -m tools.release.test_live_metadata_browser_evidence
	$(PYTHON) -m tools.release.check_live_metadata_browser_evidence

marketplace-indexer-evidence-check:
	$(PYTHON) -m tools.release.test_marketplace_indexer_evidence
	$(PYTHON) -m tools.release.check_marketplace_indexer_evidence

incident-drill-evidence-check:
	$(PYTHON) -m tools.release.test_incident_drill_evidence
	$(PYTHON) -m tools.release.check_incident_drill_evidence

signer-compromise-drill-evidence-check:
	$(PYTHON) -m tools.release.test_signer_compromise_drill_evidence
	$(PYTHON) -m tools.release.check_signer_compromise_drill_evidence

stuck-auction-drill-evidence-check:
	$(PYTHON) -m tools.release.test_stuck_auction_drill_evidence
	$(PYTHON) -m tools.release.check_stuck_auction_drill_evidence

failed-randomness-drill-evidence-check:
	$(PYTHON) -m tools.release.test_failed_randomness_drill_evidence
	$(PYTHON) -m tools.release.check_failed_randomness_drill_evidence

bad-metadata-dependency-drill-evidence-check:
	$(PYTHON) -m tools.protocol.test_bad_metadata_dependency_drill_evidence
	$(PYTHON) -m tools.protocol.check_bad_metadata_dependency_drill_evidence

public-beta-evidence-check:
	$(PYTHON) -m tools.release.test_public_beta_evidence
	$(PYTHON) -m tools.release.check_public_beta_evidence

risk-register:
	$(PYTHON) -m tools.security.generate_risk_register

risk-register-check:
	$(PYTHON) -m tools.security.test_risk_register
	$(PYTHON) -m tools.security.check_risk_register
	$(PYTHON) -m tools.security.generate_risk_register --check

public-beta-blocker-report:
	$(PYTHON) -m tools.release.generate_public_beta_blocker_report

public-beta-blocker-report-check:
	$(PYTHON) -m tools.release.test_public_beta_blocker_report
	$(PYTHON) -m tools.release.generate_public_beta_blocker_report --check

production-release-blocker-report:
	$(PYTHON) -m tools.release.generate_production_release_blocker_report

production-release-blocker-report-check:
	$(PYTHON) -m tools.release.test_production_release_blocker_report
	$(PYTHON) -m tools.release.generate_production_release_blocker_report --check

release-evidence-packet-index:
	$(PYTHON) -m tools.release.generate_release_evidence_packet_index

release-evidence-packet-index-check:
	$(PYTHON) -m tools.release.test_release_evidence_packet_index
	$(PYTHON) -m tools.release.generate_release_evidence_packet_index --check

release-evidence-issue-backlog: release-evidence-packet-index
	$(PYTHON) -m tools.release.generate_release_evidence_issue_backlog

release-evidence-issue-backlog-check: release-evidence-packet-index-check
	$(PYTHON) -m tools.release.test_release_evidence_issue_backlog
	$(PYTHON) -m tools.release.generate_release_evidence_issue_backlog --check

release-evidence-issue-links-check: release-evidence-issue-backlog-check
	$(PYTHON) -m tools.release.test_release_evidence_issue_links
	$(PYTHON) -m tools.release.check_release_evidence_issue_links

release-evidence-issue-labels-check: release-evidence-issue-links-check
	$(PYTHON) -m tools.release.test_release_evidence_issue_snapshot
	$(PYTHON) -m tools.release.test_release_evidence_issue_snapshot_audit
	$(PYTHON) -m tools.release.test_release_evidence_issue_labels
	$(PYTHON) -m tools.release.check_release_evidence_issue_labels

release-evidence-issue-body-sync: release-evidence-issue-labels-check
	$(PYTHON) -m tools.release.generate_release_evidence_issue_body_sync

release-evidence-issue-body-sync-check: release-evidence-issue-labels-check
	$(PYTHON) -m tools.release.test_release_evidence_issue_body_sync
	$(PYTHON) -m tools.release.generate_release_evidence_issue_body_sync --check

release-evidence-issue-bodies-check: release-evidence-issue-body-sync-check
	$(PYTHON) -m tools.release.test_release_evidence_issue_bodies
	$(PYTHON) -m tools.release.test_release_evidence_issue_live_snapshot
	$(PYTHON) -m tools.release.check_release_evidence_issue_bodies

release-evidence-issue-closure-check: release-evidence-issue-bodies-check
	$(PYTHON) -m tools.release.test_release_evidence_issue_closure
	$(PYTHON) -m tools.release.check_release_evidence_issue_closure

release-evidence-live-issue-snapshot: release-evidence-issue-closure-check
	$(PYTHON) -m tools.release.fetch_release_evidence_issue_snapshot --output tmp/release-evidence-live-issues.json

release-evidence-live-issue-sync-check: release-evidence-live-issue-snapshot
	$(PYTHON) -m tools.release.check_release_evidence_issue_bodies --live-json tmp/release-evidence-live-issues.json
	$(PYTHON) -m tools.release.check_release_evidence_issue_closure --live-json tmp/release-evidence-live-issues.json

release-evidence-live-audit-report-check: release-evidence-issue-closure-check
	$(PYTHON) -m tools.release.test_release_evidence_live_audit_report
	$(PYTHON) -m tools.release.check_release_evidence_live_audit_report

release-evidence-live-audit-markdown-check: release-evidence-live-audit-report-check
	$(PYTHON) -m tools.release.test_release_evidence_live_audit_markdown
	$(PYTHON) -m tools.release.check_release_evidence_live_audit_markdown

release-evidence-live-audit-archive: release-evidence-live-audit-markdown-check
	$(PYTHON) -m tools.release.generate_release_evidence_live_audit_archive

release-evidence-live-audit-archive-check: release-evidence-live-audit-markdown-check
	$(PYTHON) -m tools.release.test_release_evidence_live_audit_archive
	$(PYTHON) -m tools.release.generate_release_evidence_live_audit_archive --check

architecture-threat-model-check:
	$(PYTHON) -m tools.docs.test_architecture_threat_model
	$(PYTHON) -m tools.docs.check_architecture_threat_model

artist-semantic-owner-matrix-check:
	$(PYTHON) -m tools.protocol.run_frozen_artist_checks matrix

artist-record-event-reconstruction-correction-check:
	$(PYTHON) -m tools.protocol.run_frozen_artist_checks reconstruction

artist-owner-record-continuity-check:
	$(PYTHON) -m tools.protocol.run_frozen_artist_checks continuity

# The three artist-57 targets above validate the immutable historical baseline.
# Effective design and executable contract tests use the active checkout.
artist-operation-extension-check:
	$(PYTHON) -m tools.protocol.test_artist_operation_extension
	$(PYTHON) -m tools.protocol.check_artist_operation_extension

frozen-artist-runner-check:
	$(PYTHON) -m tools.protocol.test_frozen_artist_checks

audit-package-check:
	$(PYTHON) -m tools.docs.test_audit_package
	$(PYTHON) -m tools.docs.check_audit_package

audit-finding-workflow-check:
	$(PYTHON) -m tools.docs.test_audit_finding_workflow
	$(PYTHON) -m tools.docs.check_audit_finding_workflow

incident-response-check:
	$(PYTHON) -m tools.docs.test_incident_response
	$(PYTHON) -m tools.docs.check_incident_response

readme-check:
	$(PYTHON) -m tools.docs.test_readme
	$(PYTHON) -m tools.docs.check_readme

first-30-minutes-check:
	$(PYTHON) -m tools.docs.test_first_30_minutes
	$(PYTHON) -m tools.docs.check_first_30_minutes

issue-templates-check:
	$(PYTHON) -m tools.docs.test_issue_templates
	$(PYTHON) -m tools.docs.check_issue_templates

pr-template-check:
	$(PYTHON) -m tools.docs.test_pr_template
	$(PYTHON) -m tools.docs.check_pr_template

autonomous-state-check:
	$(PYTHON) -m tools.development.test_autonomous_state
	$(PYTHON) -m tools.development.check_autonomous_state

markdown-links-check:
	$(PYTHON) -m tools.docs.test_markdown_links
	$(PYTHON) -m tools.docs.check_markdown_links

integrations-readme-check:
	$(PYTHON) -m tools.docs.test_integrations_readme
	$(PYTHON) -m tools.docs.check_integrations_readme

contract-flows-check:
	$(PYTHON) -m tools.docs.test_contract_flows
	$(PYTHON) -m tools.docs.check_contract_flows

auction-flows-check:
	$(PYTHON) -m tools.docs.test_auction_flows
	$(PYTHON) -m tools.docs.check_auction_flows

curator-rewards-check:
	$(PYTHON) -m tools.docs.test_curator_rewards_flow
	$(PYTHON) -m tools.docs.check_curator_rewards_flow

withdrawals-credits-check:
	$(PYTHON) -m tools.docs.test_withdrawals_credits_flow
	$(PYTHON) -m tools.docs.check_withdrawals_credits_flow

wallet-signature-flows-check:
	$(PYTHON) -m tools.docs.test_wallet_signature_flows
	$(PYTHON) -m tools.docs.check_wallet_signature_flows

events-and-indexing-check:
	$(PYTHON) -m tools.docs.test_events_and_indexing
	$(PYTHON) -m tools.docs.check_events_and_indexing

metadata-rendering-check:
	$(PYTHON) -m tools.docs.test_metadata_rendering
	$(PYTHON) -m tools.docs.check_metadata_rendering

react-next-reference-check:
	$(PYTHON) -m tools.docs.test_react_next_reference
	$(PYTHON) -m tools.docs.check_react_next_reference

typescript-artifact-chain-config-check:
	$(PYTHON) -m tools.protocol.test_typescript_artifact_chain_config
	$(PYTHON) -m tools.protocol.check_typescript_artifact_chain_config

typescript-eip712-drop-authorization-check:
	$(PYTHON) -m tools.protocol.test_typescript_eip712_drop_authorization
	$(PYTHON) -m tools.protocol.check_typescript_eip712_drop_authorization

typescript-event-decoding-indexer-check:
	$(PYTHON) -m tools.protocol.test_typescript_event_decoding_indexer
	$(PYTHON) -m tools.protocol.check_typescript_event_decoding_indexer

integration-conformance-fixtures-check:
	$(PYTHON) -m tools.protocol.test_integration_conformance_fixtures
	$(PYTHON) -m tools.protocol.check_integration_conformance_fixtures

mobile-walletconnect-check:
	$(PYTHON) -m tools.docs.test_mobile_walletconnect
	$(PYTHON) -m tools.docs.check_mobile_walletconnect

electron-security-wallets-check:
	$(PYTHON) -m tools.docs.test_electron_security_wallets
	$(PYTHON) -m tools.docs.check_electron_security_wallets

operator-admin-ui-check:
	$(PYTHON) -m tools.docs.test_operator_admin_ui
	$(PYTHON) -m tools.docs.check_operator_admin_ui

operator-dashboard-query-model-check:
	$(PYTHON) -m tools.docs.test_operator_dashboard_query_model
	$(PYTHON) -m tools.docs.check_operator_dashboard_query_model

monitoring-spec-check:
	$(PYTHON) -m tools.docs.test_monitoring_spec
	$(PYTHON) -m tools.docs.check_monitoring_spec

royalty-policy-check:
	$(PYTHON) -m tools.docs.test_royalty_policy
	$(PYTHON) -m tools.docs.check_royalty_policy

warning-dispositions-check: size
	$(PYTHON) -m tools.security.test_warning_dispositions
	$(PYTHON) -m tools.security.check_warning_dispositions --solc-warnings-log cache/forge-size.log

genesis-deployment-profile-check:
	$(PYTHON) -m tools.protocol.test_genesis_deployment_profile
	$(PYTHON) -m tools.protocol.check_genesis_deployment_profile

governed-parameter-identifiers-check:
	$(PYTHON) -m tools.protocol.test_governed_parameter_identifiers
	$(PYTHON) -m tools.protocol.check_governed_parameter_identifiers

governed-parameter-inventory-check:
	$(PYTHON) -m tools.protocol.test_governed_parameter_inventory
	$(PYTHON) -m tools.protocol.check_governed_parameter_inventory

governance-action-policy-check:
	$(PYTHON) -m tools.protocol.test_governance_action_policy
	$(PYTHON) -m tools.protocol.check_governance_action_policy

record-family-authorization-check:
	$(PYTHON) -m tools.protocol.test_record_family_authorization
	$(PYTHON) -m tools.protocol.check_record_family_authorization

system-manifest-payload-vector: genesis-deployment-profile-check governed-parameter-identifiers-check
	$(PYTHON) -m tools.protocol.generate_system_manifest_payload_vector
	$(PYTHON) -m tools.protocol.test_system_manifest_payload_vector
	$(PYTHON) -m tools.protocol.check_system_manifest_payload_vector
	$(PYTHON) -m tools.protocol.test_system_manifest_payload_vector_reference
	$(PYTHON) -m tools.protocol.check_system_manifest_payload_vector_reference

system-manifest-payload-vector-check: genesis-deployment-profile-check governed-parameter-identifiers-check
	$(PYTHON) -m tools.protocol.test_system_manifest_payload_vector
	$(PYTHON) -m tools.protocol.check_system_manifest_payload_vector
	$(PYTHON) -m tools.protocol.test_system_manifest_payload_vector_reference
	$(PYTHON) -m tools.protocol.check_system_manifest_payload_vector_reference

slither-baseline-metadata-check:
	$(PYTHON) -m tools.security.test_slither_baseline
	$(PYTHON) -m tools.security.check_slither_baseline --baseline-only

slither-baseline-check: slither-baseline-metadata-check
	$(PYTHON) -m tools.security.check_slither_baseline --run-slither

release-readiness-check:
	$(PYTHON) -m tools.release.test_release_readiness
	$(PYTHON) -m tools.release.check_release_readiness
	$(PYTHON) -m tools.release.test_release_mode

release-mode-public-beta-check: check slither-baseline-check
	$(PYTHON) -m tools.release.test_release_mode
	$(PYTHON) -m tools.release.check_release_mode --phase public-beta

release-mode-production-release-check: check slither-baseline-check
	$(PYTHON) -m tools.release.test_release_mode
	$(PYTHON) -m tools.release.check_release_mode --phase production-release

release-mode-check: release-mode-production-release-check

release-notes:
	$(PYTHON) -m tools.release.generate_release_notes

release-notes-check:
	$(PYTHON) -m tools.release.test_release_notes
	$(PYTHON) -m tools.release.generate_release_notes --check

release-manifest: external-call-gas-inventory-check abi-compatibility-check genesis-deployment-profile-check governed-parameter-identifiers-check governed-parameter-inventory-check system-manifest-payload-vector address-books protocol-surface-report custom-error-catalog natspec-coverage-check source-verification-inputs dependency-provenance-attestation one-of-one-provenance-manifest one-of-one-permanence-manifest ceremony-evidence-check randomizer-operations-check release-signatures-check non-local-release-evidence-check external-audit-report-evidence-check post-audit-remediation-evidence-check live-ceremony-evidence-check live-randomizer-operations-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check sepolia-evidence-preflight-check public-beta-verified-addresses-check production-broadcast-retention-check live-deployment-manifest-evidence-check production-verified-addresses-check production-release-signing-evidence-check fork-metadata-browser-evidence-check live-metadata-browser-evidence-check marketplace-indexer-evidence-check incident-drill-evidence-check signer-compromise-drill-evidence-check stuck-auction-drill-evidence-check failed-randomness-drill-evidence-check bad-metadata-dependency-drill-evidence-check drop-authorization-signing-evidence-check signer-custody-readiness-check public-beta-evidence-check risk-register public-beta-blocker-report-check production-release-blocker-report-check release-evidence-packet-index-check release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-audit-markdown-check architecture-threat-model-check artist-semantic-owner-matrix-check audit-package-check audit-finding-workflow-check incident-response-check readme-check first-30-minutes-check issue-templates-check pr-template-check markdown-links-check integrations-readme-check contract-flows-check auction-flows-check curator-rewards-check withdrawals-credits-check wallet-signature-flows-check events-and-indexing-check metadata-rendering-check react-next-reference-check typescript-artifact-chain-config-check typescript-eip712-drop-authorization-check typescript-event-decoding-indexer-check integration-conformance-fixtures-check mobile-walletconnect-check electron-security-wallets-check operator-admin-ui-check operator-dashboard-query-model-check monitoring-spec-check royalty-policy-check warning-dispositions-check core-bytecode-spend-policy-check drop-authorization-fixtures-check release-readiness-check release-notes
	$(PYTHON) -m tools.release.generate_release_manifest

release-manifest-check: external-call-gas-inventory-check abi-compatibility-check genesis-deployment-profile-check governed-parameter-identifiers-check governed-parameter-inventory-check system-manifest-payload-vector-check address-books-check protocol-surface-report-check custom-error-catalog-check natspec-coverage-check source-verification-inputs-check dependency-provenance-attestation-check one-of-one-provenance-manifest-check one-of-one-permanence-manifest-check ceremony-evidence-check randomizer-operations-check release-signatures-check non-local-release-evidence-check external-audit-report-evidence-check post-audit-remediation-evidence-check live-ceremony-evidence-check live-randomizer-operations-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check sepolia-evidence-preflight-check public-beta-verified-addresses-check production-broadcast-retention-check live-deployment-manifest-evidence-check production-verified-addresses-check production-release-signing-evidence-check fork-metadata-browser-evidence-check live-metadata-browser-evidence-check marketplace-indexer-evidence-check incident-drill-evidence-check signer-compromise-drill-evidence-check stuck-auction-drill-evidence-check failed-randomness-drill-evidence-check bad-metadata-dependency-drill-evidence-check drop-authorization-signing-evidence-check signer-custody-readiness-check public-beta-evidence-check risk-register-check public-beta-blocker-report-check production-release-blocker-report-check release-evidence-packet-index-check release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-audit-markdown-check architecture-threat-model-check artist-semantic-owner-matrix-check audit-package-check audit-finding-workflow-check incident-response-check readme-check first-30-minutes-check issue-templates-check pr-template-check markdown-links-check integrations-readme-check contract-flows-check auction-flows-check curator-rewards-check withdrawals-credits-check wallet-signature-flows-check events-and-indexing-check metadata-rendering-check react-next-reference-check typescript-artifact-chain-config-check typescript-eip712-drop-authorization-check typescript-event-decoding-indexer-check integration-conformance-fixtures-check mobile-walletconnect-check electron-security-wallets-check operator-admin-ui-check operator-dashboard-query-model-check monitoring-spec-check royalty-policy-check warning-dispositions-check core-bytecode-spend-policy-check drop-authorization-fixtures-check release-readiness-check release-notes-check
	$(PYTHON) -m tools.release.test_release_manifest
	$(PYTHON) -m tools.release.generate_release_manifest --check

release-checksums: release-candidate-lockfile
	$(PYTHON) -m tools.release.generate_release_checksums

release-checksums-check: release-candidate-lockfile-check
	$(PYTHON) -m tools.release.test_release_checksums
	$(PYTHON) -m tools.release.generate_release_checksums --check

release-artifacts-verify: release-checksums-check
	$(PYTHON) -m tools.build.test_verify_release_artifacts
	$(PYTHON) -m tools.build.verify_release_artifacts

changelog-check:
	$(PYTHON) -m tools.docs.test_changelog_check
	$(PYTHON) -m tools.docs.check_changelog

solidity-formatting-check:
	$(PYTHON) -m tools.build.test_solidity_formatting
	$(PYTHON) -m tools.build.check_solidity_formatting

fmt-check: solidity-formatting-check

slither:
	slither . --config-file slither.config.json --foundry-compile-all

clean:
	$(PYTHON) scripts/dev.py clean

# Common contributor commands. The release target preserves the full evidence gate.
.PHONY: help dev doctor docs-check release-check
help:
	@echo "6529Stream developer commands"
	@echo "  make doctor               Check the local toolchain"
	@echo "  make build / make test    Compile or test the supported current stack"
	@echo "  make dev                  Check the supported current stack"
	@echo "  make current-stack-check  Current integration and artifact checks"
	@echo "  make docs-check           Check documentation entry points and links"
	@echo "  make release-check        Full release gate, including legacy regressions"
	@echo "  make clean                Clear compiler output; keep deployment evidence"
	@echo "Portable equivalent: python scripts/dev.py --help"

doctor:
	$(PYTHON) scripts/dev.py doctor

dev:
	$(PYTHON) scripts/dev.py check

docs-check:
	$(PYTHON) scripts/dev.py docs

release-check: check
