# Release Artifacts

This directory contains the deterministic local release-artifact baseline for
6529Stream.

Run after the production build profile:

```sh
forge build --sizes --via-ir --skip test --skip script --force
forge snapshot --match-path test/StreamGasSnapshot.t.sol --snap release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python scripts/generate_release_artifacts.py
python scripts/generate_source_verification_inputs.py
python scripts/generate_dependency_artifact_manifest.py
python scripts/check_abi_compatibility.py
python scripts/generate_deployment_manifest.py
python scripts/generate_address_books.py
python scripts/check_ceremony_evidence.py
python scripts/check_randomizer_operations.py
python scripts/check_release_signatures.py
python scripts/check_architecture_threat_model.py
python scripts/check_audit_package.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py
python scripts/generate_release_checksums.py
```

Check the committed artifacts without rewriting them:

```sh
python scripts/test_release_artifacts.py
python scripts/generate_release_artifacts.py --check
forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap
python scripts/test_source_verification_inputs.py
python scripts/generate_source_verification_inputs.py --check
python scripts/test_dependency_artifact_manifest.py
python scripts/generate_dependency_artifact_manifest.py --check
python scripts/test_abi_compatibility.py
python scripts/check_abi_compatibility.py --check
python scripts/test_deployment_manifest.py
python scripts/generate_deployment_manifest.py --check
python scripts/test_address_books.py
python scripts/generate_address_books.py --check
python scripts/test_ceremony_evidence.py
python scripts/check_ceremony_evidence.py
python scripts/test_randomizer_operations.py
python scripts/check_randomizer_operations.py
python scripts/test_release_signatures.py
python scripts/check_release_signatures.py
python scripts/test_architecture_threat_model.py
python scripts/check_architecture_threat_model.py
python scripts/test_audit_package.py
python scripts/check_audit_package.py
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
```

The generated files under `latest/` are intentionally tracked. They give
deployment manifests stable ABI checksum, bytecode checksum, interface ID, and
event topic catalog inputs before any live network broadcast exists.

`latest/source-verification-inputs.json` is generated from the production
Foundry artifacts, source files, compiler settings, and contract config. It
retains source hashes, compiler settings, constructor ABI, bytecode/linking
status, and `forge verify-contract` command templates so live deployment
verification can be checked against committed release inputs once broadcast
addresses and encoded constructor args exist.

`latest/dependency-artifact-manifest.json` is generated from descriptors under
`dependencies/`. It records release-packaged dependency source files, dependency
registry key/version metadata, provenance, and SHA-256 file integrity so the
release bundle does not depend on registry provenance strings alone.
Dependency artifact source files are hashed byte-for-byte, so `.gitattributes`
pins JavaScript and other release text artifacts to LF line endings. Keep new
packaged dependency files under that policy so Windows and Linux checkouts
produce the same manifest hashes.
Production dependency version changes must follow
`docs/dependency-operations.md` before public release.

`latest/release-manifest.json` is a generated top-level release manifest. It
records release metadata, release artifact hashes, ABI compatibility baseline
hashes, deployment manifest/address-book hashes, ceremony evidence hashes,
schema hashes, governance doc hashes including `docs/architecture.md`,
`docs/threat-model.md`, `docs/audit-package.md`, and
`docs/release-readiness.md`, and the release-ceremony items that are not yet
available for this pre-audit local baseline.

`docs/architecture.md`, `docs/threat-model.md`, `docs/audit-package.md`, and
`docs/release-readiness.md` are the auditor-facing architecture,
trust-boundary, package, and Gate G readiness indexes for the current local
baseline. They are validated before release manifest generation, and the
release manifest records their hashes as governance documents.

`latest/SHA256SUMS` and `latest/release-checksums.json` are also generated
outputs. They cover the committed release artifact config, generated release
artifacts, dependency artifact descriptors/source files, ABI compatibility
baseline, deployment manifest config/examples, address books, ceremony evidence
bundles, randomizer operations evidence, release signature evidence, artifact
schemas, and release manifest. Treat `SHA256SUMS` as the signable checksum file
for a release; the committed local signature evidence records that production
detached signatures and signed tags remain a maintainer release-ceremony step.

Because the checksum bundle covers `latest/release-manifest.json`, the release
manifest cannot also embed the final checksum-bundle digests without creating a
self-referential hash cycle. It therefore lists the checksum bundle outputs and
marks their digests as `not_available_self_referential`.
Release signature evidence uses the same self-referential digest status for
`latest/release-manifest.json` and `latest/SHA256SUMS` because both generated
files cover the signature evidence file.

The generated ABI compatibility baseline under `baselines/` is also tracked.
It captures the current production contract function, event, custom error,
constructor, fallback, and receive surface. The check fails on removed or
changed entries and reports additive entries as compatible for this first
release baseline.

`baselines/v0.1.0/gas-snapshot.snap` is the local Foundry gas snapshot for the
Gate D operations. It is generated with `forge snapshot --match-path
test/StreamGasSnapshot.t.sol --snap
release-artifacts/baselines/v0.1.0/gas-snapshot.snap` and checked with the same
command's `--check` form. The snapshot intentionally covers deterministic local
tests only; fork/testnet/mainnet gas measurements remain a later release step.

The generator uses Foundry's `cast sig-event` for Ethereum event topics and
Foundry artifact `methodIdentifiers` for function selectors and interface IDs.
Known ERC interface IDs are pinned in `contracts.json` where the advertised
standard ID differs from a raw selector XOR over an artifact ABI that includes
inherited `supportsInterface` or event-only declarations.

After any covered artifact changes, refresh the checksum bundle with:

```sh
python scripts/generate_deployment_manifest.py
python scripts/generate_address_books.py
python scripts/generate_source_verification_inputs.py
python scripts/generate_dependency_artifact_manifest.py
python scripts/check_ceremony_evidence.py
python scripts/check_randomizer_operations.py
python scripts/check_release_signatures.py
python scripts/check_architecture_threat_model.py
python scripts/check_audit_package.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py
python scripts/generate_release_checksums.py
```

If only `release-artifacts/` changed, the manifest and address-book commands
should still be safe no-ops, and their `--check` modes will catch stale
deployment-derived inputs before the checksum bundle is refreshed.
