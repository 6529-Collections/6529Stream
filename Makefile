ifeq ($(OS),Windows_NT)
PYTHON ?= python
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
FOUNDRY_BIN := $(HOME)/.foundry/bin
REPO_ROOT := $(CURDIR)
PATH_SEPARATOR := :
VENV_BIN := .venv-tools/bin
RM_RF := rm -rf out cache broadcast
endif
PATH := $(FOUNDRY_BIN)$(PATH_SEPARATOR)$(REPO_ROOT)/$(VENV_BIN)$(PATH_SEPARATOR)$(PATH)

.PHONY: check build test gas-snapshot gas-snapshot-check size deploy-rehearsal metadata-fixtures-check drop-authorization-fixtures-check release-artifacts release-artifacts-check source-verification-inputs source-verification-inputs-check abi-compatibility abi-compatibility-check broadcast-manifest-inputs broadcast-manifest-inputs-check deployment-manifests deployment-manifest-check address-books address-books-check dependency-artifacts dependency-artifacts-check ceremony-evidence-check randomizer-operations-check release-signatures-check non-local-release-evidence-check public-beta-evidence-check architecture-threat-model-check audit-package-check incident-response-check release-readiness-check release-manifest release-manifest-check release-checksums release-checksums-check changelog-check fmt-check slither clean

check: build test gas-snapshot-check size metadata-fixtures-check drop-authorization-fixtures-check release-artifacts-check source-verification-inputs-check abi-compatibility-check non-local-release-evidence-check public-beta-evidence-check architecture-threat-model-check audit-package-check incident-response-check release-readiness-check release-checksums-check changelog-check deploy-rehearsal

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

drop-authorization-fixtures-check:
	$(PYTHON) scripts/test_drop_authorization_payload_generator.py
	$(PYTHON) scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
	$(PYTHON) scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
	$(PYTHON) scripts/test_drop_authorization_fixtures.py
	$(PYTHON) scripts/check_drop_authorization_fixtures.py

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

non-local-release-evidence-check:
	$(PYTHON) scripts/test_non_local_release_evidence.py
	$(PYTHON) scripts/check_non_local_release_evidence.py

public-beta-evidence-check:
	$(PYTHON) scripts/test_public_beta_evidence.py
	$(PYTHON) scripts/check_public_beta_evidence.py

architecture-threat-model-check:
	$(PYTHON) scripts/test_architecture_threat_model.py
	$(PYTHON) scripts/check_architecture_threat_model.py

audit-package-check:
	$(PYTHON) scripts/test_audit_package.py
	$(PYTHON) scripts/check_audit_package.py

incident-response-check:
	$(PYTHON) scripts/test_incident_response.py
	$(PYTHON) scripts/check_incident_response.py

release-readiness-check:
	$(PYTHON) scripts/test_release_readiness.py
	$(PYTHON) scripts/check_release_readiness.py

release-manifest: address-books source-verification-inputs dependency-artifacts ceremony-evidence-check randomizer-operations-check release-signatures-check non-local-release-evidence-check public-beta-evidence-check architecture-threat-model-check audit-package-check incident-response-check drop-authorization-fixtures-check release-readiness-check
	$(PYTHON) scripts/generate_release_manifest.py

release-manifest-check: address-books-check source-verification-inputs-check dependency-artifacts-check ceremony-evidence-check randomizer-operations-check release-signatures-check non-local-release-evidence-check public-beta-evidence-check architecture-threat-model-check audit-package-check incident-response-check drop-authorization-fixtures-check release-readiness-check
	$(PYTHON) scripts/test_release_manifest.py
	$(PYTHON) scripts/generate_release_manifest.py --check

release-checksums: release-manifest
	$(PYTHON) scripts/generate_release_checksums.py

release-checksums-check: release-manifest-check
	$(PYTHON) scripts/test_release_checksums.py
	$(PYTHON) scripts/generate_release_checksums.py --check

changelog-check:
	$(PYTHON) scripts/test_changelog_check.py
	$(PYTHON) scripts/check_changelog.py

fmt-check:
	forge fmt --check smart-contracts

slither:
	slither . --config-file slither.config.json --foundry-compile-all

clean:
	$(RM_RF)
