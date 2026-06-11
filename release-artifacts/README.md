# Release Artifacts

This directory contains the deterministic local release-artifact baseline for
6529Stream.

Run after the production build profile:

```sh
forge build --sizes --via-ir --skip test --skip script --force
python scripts/generate_release_artifacts.py
python scripts/check_abi_compatibility.py
python scripts/generate_release_checksums.py
```

Check the committed artifacts without rewriting them:

```sh
python scripts/test_release_artifacts.py
python scripts/generate_release_artifacts.py --check
python scripts/test_abi_compatibility.py
python scripts/check_abi_compatibility.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
```

The generated files under `latest/` are intentionally tracked. They give
deployment manifests stable ABI checksum, bytecode checksum, interface ID, and
event topic catalog inputs before any live network broadcast exists.

`latest/SHA256SUMS` and `latest/release-checksums.json` are also generated
outputs. They cover the committed release artifact config, generated release
artifacts, ABI compatibility baseline, deployment manifest config/examples,
address books, and artifact schemas. Treat `SHA256SUMS` as the signable
checksum file for a release; detached signatures and signed tags remain a
separate maintainer release-ceremony step.

The generated ABI compatibility baseline under `baselines/` is also tracked.
It captures the current production contract function, event, custom error,
constructor, fallback, and receive surface. The check fails on removed or
changed entries and reports additive entries as compatible for this first
release baseline.

The generator uses Foundry's `cast sig-event` for Ethereum event topics and
Foundry artifact `methodIdentifiers` for function selectors and interface IDs.
Known ERC interface IDs are pinned in `contracts.json` where the advertised
standard ID differs from a raw selector XOR over an artifact ABI that includes
inherited `supportsInterface` or event-only declarations.

After any covered artifact changes, refresh the checksum bundle with:

```sh
python scripts/generate_release_checksums.py
```
