ifeq ($(OS),Windows_NT)
FOUNDRY_BIN := $(USERPROFILE)/.foundry/bin
PATH := $(FOUNDRY_BIN);$(PATH)
RM_RF := powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -Recurse -Force out,cache,broadcast -ErrorAction SilentlyContinue"
else
FOUNDRY_BIN := $(HOME)/.foundry/bin
PATH := $(FOUNDRY_BIN):$(PATH)
RM_RF := rm -rf out cache broadcast
endif

.PHONY: check build test fmt-check slither clean

check: build test

build:
	forge build

test:
	forge test -vvv

fmt-check:
	forge fmt --check smart-contracts

slither:
	slither . --foundry-compile-all

clean:
	$(RM_RF)
