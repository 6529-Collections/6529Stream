# Changelog

All notable release-impacting changes are recorded here. The project follows
the release policy in `docs/release-policy.md`.

## Unreleased

### Added

- Added release change approval policy and a local/CI changelog gate for
  release-impacting contract, deployment, artifact, and release-workflow
  changes.
- Added a deterministic machine-readable release manifest that ties release
  artifacts, ABI compatibility, deployment manifests, address books, governance
  docs, and release-ceremony status together under `release-artifacts/latest/`.

### Release Impact

- Gate G now requires release-impacting PRs to update this `Unreleased` section
  before merge.
- Gate G now checks `release-artifacts/latest/release-manifest.json` before the
  signable checksum bundle. The checksum bundle covers the release manifest, so
  the manifest records checksum-bundle digests as self-referentially unavailable
  rather than embedding a hash cycle.
- Detached checksum signatures, signed release tags, production address books,
  and verified live deployment addresses remain future release-ceremony work.

## v0.1.0 - Initial Local Baseline

### Added

- Established the first local release-artifact baseline, including ABI
  checksums, bytecode checksums, interface IDs, event topic catalog, ABI
  compatibility baseline, local deployment manifest, local address book, and
  signable checksum bundle.
