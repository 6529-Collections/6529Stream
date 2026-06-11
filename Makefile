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

.PHONY: check build test size deploy-rehearsal release-artifacts release-artifacts-check deployment-manifests deployment-manifest-check fmt-check slither clean

check: build test size release-artifacts-check deployment-manifest-check deploy-rehearsal

build:
	forge build

test:
	forge test -vvv

size:
	forge build --sizes --via-ir --skip test --skip script --force

deploy-rehearsal:
	forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir

release-artifacts: size
	$(PYTHON) scripts/generate_release_artifacts.py

release-artifacts-check: size
	$(PYTHON) scripts/test_release_artifacts.py
	$(PYTHON) scripts/generate_release_artifacts.py --check

deployment-manifests: release-artifacts
	$(PYTHON) scripts/generate_deployment_manifest.py

deployment-manifest-check:
	$(PYTHON) scripts/test_deployment_manifest.py
	$(PYTHON) scripts/generate_deployment_manifest.py --check

fmt-check:
	forge fmt --check smart-contracts

slither:
	slither . --config-file slither.config.json --foundry-compile-all

clean:
	$(RM_RF)
