# Changelog

All notable release-impacting changes are recorded here. The project follows
the release policy in `docs/release-policy.md`.

## Unreleased

### Added

- Added release change approval policy and a local/CI changelog gate for
  release-impacting contract, deployment, artifact, and release-workflow
  changes.

### Release Impact

- Gate G now requires release-impacting PRs to update this `Unreleased` section
  before merge.
- Detached checksum signatures, signed release tags, production address books,
  and verified live deployment addresses remain future release-ceremony work.

## v0.1.0 - Initial Local Baseline

### Added

- Established the first local release-artifact baseline, including ABI
  checksums, bytecode checksums, interface IDs, event topic catalog, ABI
  compatibility baseline, local deployment manifest, local address book, and
  signable checksum bundle.
