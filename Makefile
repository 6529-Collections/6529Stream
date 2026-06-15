ifeq ($(OS),Windows_NT)
PYTHON ?= python
POWERSHELL ?= powershell
POWERSHELL_FLAGS ?= -NoProfile -ExecutionPolicy Bypass
ifdef MSYSTEM
FOUNDRY_BIN := $(HOME)/.foundry/bin
REPO_ROOT := $(shell pwd)
PATH_SEPARATOR := :
RM_RF := rm -rf out cache broadcast
else
FOUNDRY_BIN := $(USERPROFILE)/.foundry/bin
REPO_ROOT := $(CURDIR)
PATH_SEPARATOR := ;
RM_RF := powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -Recurse -Force out,cache,broadcast -ErrorAction SilentlyContinue"
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
RM_RF := rm -rf out cache broadcast
endif
PATH := $(FOUNDRY_BIN)$(PATH_SEPARATOR)$(REPO_ROOT)/$(VENV_BIN)$(PATH_SEPARATOR)$(PATH)

.PHONY: check build test gas-snapshot gas-snapshot-check size deploy-rehearsal metadata-fixtures-check windows-check-wrapper-policy windows-check-wrapper-runtime drop-authorization-fixtures-check drop-authorization-signing-evidence-check signer-custody-readiness-check admin-ceremony-evidence-check solidity-formatting-check release-artifacts release-artifacts-check source-verification-inputs source-verification-inputs-check abi-compatibility abi-compatibility-check broadcast-manifest-inputs broadcast-manifest-inputs-check deployment-manifests deployment-manifest-check address-books address-books-check dependency-artifacts dependency-artifacts-check ceremony-evidence-check randomizer-operations-check release-signatures-check signed-release-tag-check bytecode-release-proof bytecode-release-proof-check non-local-release-evidence-check external-audit-report-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check public-beta-evidence-check public-beta-blocker-report public-beta-blocker-report-check production-release-blocker-report production-release-blocker-report-check release-evidence-packet-index release-evidence-packet-index-check release-evidence-issue-backlog release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-labels-check release-evidence-issue-body-sync release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-audit-report-check release-evidence-live-audit-markdown-check release-evidence-live-audit-archive release-evidence-live-audit-archive-check architecture-threat-model-check audit-package-check incident-response-check integrations-readme-check contract-flows-check release-readiness-check release-manifest release-manifest-check release-checksums release-checksums-check changelog-check fmt-check slither clean

check: build test gas-snapshot-check size solidity-formatting-check windows-check-wrapper-policy metadata-fixtures-check drop-authorization-fixtures-check drop-authorization-signing-evidence-check signer-custody-readiness-check admin-ceremony-evidence-check release-artifacts-check source-verification-inputs-check abi-compatibility-check signed-release-tag-check non-local-release-evidence-check external-audit-report-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check public-beta-evidence-check public-beta-blocker-report-check production-release-blocker-report-check release-evidence-packet-index-check release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-labels-check release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-audit-archive-check architecture-threat-model-check audit-package-check incident-response-check integrations-readme-check contract-flows-check release-readiness-check release-checksums-check changelog-check deploy-rehearsal

build:
	forge build

test:
	forge test -vvv

gas-snapshot:
	forge snapshot --match-path test/StreamGasSnapshot.t.sol --snap release-artifacts/baselines/v0.1.0/gas-snapshot.snap

gas-snapshot-check:
	forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap

size:
	forge build --sizes --via-ir --skip test --skip script --force

deploy-rehearsal:
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

admin-ceremony-evidence-check:
	$(PYTHON) scripts/test_admin_ceremony_evidence.py
	$(PYTHON) scripts/check_admin_ceremony_evidence.py

release-artifacts: size
	$(PYTHON) scripts/generate_release_artifacts.py

release-artifacts-check: size
	$(PYTHON) scripts/test_release_artifacts.py
	$(PYTHON) scripts/generate_release_artifacts.py --check

source-verification-inputs: release-artifacts
	$(PYTHON) scripts/generate_source_verification_inputs.py

source-verification-inputs-check: release-artifacts-check
	$(PYTHON) scripts/test_source_verification_inputs.py
	$(PYTHON) scripts/generate_source_verification_inputs.py --check

abi-compatibility: size
	$(PYTHON) scripts/check_abi_compatibility.py

abi-compatibility-check: size
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

deployment-manifest-check: broadcast-manifest-inputs-check
	$(PYTHON) scripts/test_deployment_manifest.py
	$(PYTHON) scripts/generate_deployment_manifest.py --check
	$(PYTHON) scripts/generate_deployment_manifest.py --config deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json --check

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

non-local-release-evidence-check:
	$(PYTHON) scripts/test_non_local_release_evidence.py
	$(PYTHON) scripts/check_non_local_release_evidence.py

external-audit-report-evidence-check:
	$(PYTHON) scripts/test_external_audit_report_evidence.py
	$(PYTHON) scripts/check_external_audit_report_evidence.py

fork-deployment-rehearsal-evidence-check:
	$(PYTHON) scripts/test_fork_deployment_rehearsal_evidence.py
	$(PYTHON) scripts/check_fork_deployment_rehearsal_evidence.py

testnet-deployment-rehearsal-evidence-check:
	$(PYTHON) scripts/test_testnet_deployment_rehearsal_evidence.py
	$(PYTHON) scripts/check_testnet_deployment_rehearsal_evidence.py

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
	$(PYTHON) scripts/check_release_evidence_issue_bodies.py

release-evidence-issue-closure-check: release-evidence-issue-bodies-check
	$(PYTHON) scripts/test_release_evidence_issue_closure.py
	$(PYTHON) scripts/check_release_evidence_issue_closure.py

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

incident-response-check:
	$(PYTHON) scripts/test_incident_response.py
	$(PYTHON) scripts/check_incident_response.py

integrations-readme-check:
	$(PYTHON) scripts/test_integrations_readme.py
	$(PYTHON) scripts/check_integrations_readme.py

contract-flows-check:
	$(PYTHON) scripts/test_contract_flows.py
	$(PYTHON) scripts/check_contract_flows.py

release-readiness-check:
	$(PYTHON) scripts/test_release_readiness.py
	$(PYTHON) scripts/check_release_readiness.py

release-manifest: address-books source-verification-inputs dependency-artifacts ceremony-evidence-check randomizer-operations-check release-signatures-check non-local-release-evidence-check external-audit-report-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check drop-authorization-signing-evidence-check signer-custody-readiness-check public-beta-evidence-check risk-register public-beta-blocker-report-check production-release-blocker-report-check release-evidence-packet-index-check release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-audit-markdown-check architecture-threat-model-check audit-package-check incident-response-check integrations-readme-check contract-flows-check drop-authorization-fixtures-check release-readiness-check
	$(PYTHON) scripts/generate_release_manifest.py

release-manifest-check: address-books-check source-verification-inputs-check dependency-artifacts-check ceremony-evidence-check randomizer-operations-check release-signatures-check non-local-release-evidence-check external-audit-report-evidence-check fork-deployment-rehearsal-evidence-check testnet-deployment-rehearsal-evidence-check drop-authorization-signing-evidence-check signer-custody-readiness-check public-beta-evidence-check risk-register-check public-beta-blocker-report-check production-release-blocker-report-check release-evidence-packet-index-check release-evidence-issue-backlog-check release-evidence-issue-links-check release-evidence-issue-body-sync-check release-evidence-issue-bodies-check release-evidence-issue-closure-check release-evidence-live-audit-markdown-check architecture-threat-model-check audit-package-check incident-response-check integrations-readme-check contract-flows-check drop-authorization-fixtures-check release-readiness-check
	$(PYTHON) scripts/test_release_manifest.py
	$(PYTHON) scripts/generate_release_manifest.py --check

release-checksums: bytecode-release-proof
	$(PYTHON) scripts/generate_release_checksums.py

release-checksums-check: bytecode-release-proof-check
	$(PYTHON) scripts/test_release_checksums.py
	$(PYTHON) scripts/generate_release_checksums.py --check

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
