# Release Artifacts

This directory contains the deterministic local release-artifact baseline for
6529Stream.

Run after the production build profile:

```sh
forge build --sizes --via-ir --skip test --skip script --force
python scripts/generate_release_artifacts.py
```

Check the committed artifacts without rewriting them:

```sh
python scripts/test_release_artifacts.py
python scripts/generate_release_artifacts.py --check
```

The generated files under `latest/` are intentionally tracked. They give
deployment manifests stable ABI checksum, bytecode checksum, interface ID, and
event topic catalog inputs before any live network broadcast exists.

The generator uses Foundry's `cast sig-event` for Ethereum event topics and
Foundry artifact `methodIdentifiers` for function selectors and interface IDs.
Known ERC interface IDs are pinned in `contracts.json` where the advertised
standard ID differs from a raw selector XOR over an artifact ABI that includes
inherited `supportsInterface` or event-only declarations.
