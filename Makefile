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

.PHONY: check build test size deploy-rehearsal metadata-fixtures-check release-artifacts release-artifacts-check source-verification-inputs source-verification-inputs-check abi-compatibility abi-compatibility-check broadcast-manifest-inputs broadcast-manifest-inputs-check deployment-manifests deployment-manifest-check address-books address-books-check release-manifest release-manifest-check release-checksums release-checksums-check changelog-check fmt-check slither clean

check: build test size metadata-fixtures-check release-artifacts-check source-verification-inputs-check abi-compatibility-check release-checksums-check changelog-check deploy-rehearsal

build:
	forge build

test:
	forge test -vvv

size:
	forge build --sizes --via-ir --skip test --skip script --force

deploy-rehearsal:
	forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir

metadata-fixtures-check:
	$(PYTHON) scripts/test_metadata_fixtures.py
	$(PYTHON) scripts/check_metadata_fixtures.py

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

release-manifest: address-books source-verification-inputs
	$(PYTHON) scripts/generate_release_manifest.py

release-manifest-check: address-books-check source-verification-inputs-check
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
