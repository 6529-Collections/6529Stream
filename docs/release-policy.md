# Release Policy

This policy defines how 6529Stream source releases, ABI changes, deployment
artifacts, release notes, and public release claims are approved before the
first public beta.

The project is still pre-audit. A release tag or artifact bundle must not imply
production readiness until the launch gates in `ops/ROADMAP.md` are satisfied.

## Version Surfaces

6529Stream tracks several related but separate versions:

- Protocol release version: a source release such as `v0.1.0` that bundles
  code, docs, release artifacts, deployment inputs, and release notes.
- Contract version: the source and deployed bytecode for one Solidity contract.
- ABI version: the externally consumed function, event, error, struct, and
  interface surface.
- Metadata schema version: the token JSON and animation output schema exposed
  by metadata APIs.
- Deployment manifest version: a network-specific manifest instance such as
  `anvil-6529stream-v0.1.0-001`.
- Release artifact schema version: the schema for generated files under
  `release-artifacts/` and `deployments/`.

Before an audited public release, protocol versions may remain `0.x`. After a
public audited release, semantic versioning is expected:

- MAJOR: breaking contract, ABI, event, error, authorization, metadata,
  deployment manifest, release artifact, or role/permission change.
- MINOR: additive external behavior or additive release artifact fields that
  are backwards compatible.
- PATCH: bug fixes, docs, tooling, tests, or non-breaking artifact corrections.

## Release-Impacting Changes

A PR is release-impacting when it changes any of these surfaces:

- Solidity source under `smart-contracts/`.
- Release artifacts, generated baselines, artifact schemas, or artifact
  generation/check scripts.
- Deployment broadcasts, configs, schemas, examples, address books, or
  deployment manifest generation/check scripts.
- CI, `Makefile`, or local check wrappers that define the release gate.
- Release process docs such as this file, `docs/deployment.md`,
  `docs/release-signatures.md`, `docs/public-beta-evidence.md`, `docs/architecture.md`,
  `docs/threat-model.md`, `docs/non-local-release-evidence.md`,
  `docs/release-readiness.md`, `docs/tooling.md`, `SECURITY.md`, `CONTRIBUTING.md`,
  or the PR template.

Release-impacting PRs must update `CHANGELOG.md` under `## Unreleased` with a
non-placeholder bullet. The `scripts/check_changelog.py` gate enforces this for
changed paths that affect the release surface.

## Breaking Changes

The following changes are breaking unless maintainers explicitly document a
compatible migration path:

- Function removal, signature change, visibility change, selector change, or
  changed payable behavior.
- Event signature change, indexed-field change, or event removal.
- Custom error or revert-behavior change that integrations may depend on.
- Struct, enum, or interface ID change.
- Authorization schema, signer semantics, nonce/replay semantics, or role
  permission change.
- Metadata schema, token URI state, animation HTML, dependency pinning, or
  freeze semantics change.
- Royalty behavior, ERC-2981 disclosure, receiver, fee numerator, denominator,
  governance, marketplace display, or enforcement boundary change. Current
  policy is recorded in `docs/royalty-policy.md`.
- Payment, withdrawal, custody, settlement, emergency withdrawal, or accounting
  behavior change.
- Randomness provider, request lifecycle, retry, or stale callback behavior
  change.
- Deployment manifest, address book, release manifest, release checksum, ABI
  compatibility, or artifact schema change.

Breaking changes require:

- a linked GitHub issue or ADR describing the intent;
- updated `CHANGELOG.md` under `## Unreleased` with a `Breaking Changes` or
  `Release Impact` entry;
- updated docs for affected users or integrators;
- regenerated release artifacts when ABI, event, deployment, or artifact output
  changes;
- explicit maintainer approval before a public release tag.

## ABI And Artifact Approval

The ABI compatibility gate compares the current production ABI surface against
`release-artifacts/baselines/v0.1.0/abi-surface.json`.

- Removed or changed entries are blocking until the change is approved and the
  baseline is intentionally refreshed.
- Additive entries are reported as compatible, but they still require a
  changelog entry when they are part of a release-impacting PR.
- Baseline refreshes must happen in the same PR as the contract or artifact
  change, or in a follow-up PR linked from the original approval issue.
- Event topic, interface ID, source verification input, broadcast-derived
  manifest input, deployment manifest, address book, release manifest, and
  checksum outputs must be regenerated before merge when their covered inputs
  change.
- Update [`docs/integrations/events-and-indexing.md`](integrations/events-and-indexing.md)
  when event signatures, indexed fields, emitting contracts, replay posture, or
  read-after-event requirements change.

## Changelog Gate

Run the changelog gate locally with:

```sh
python scripts/test_changelog_check.py
python scripts/check_changelog.py
```

In CI, the gate compares the pull request branch against the PR base SHA. On a
local branch, the gate compares against `origin/main` and also includes staged
or unstaged files.

The gate intentionally does not choose the semantic version for maintainers. It
only proves that release-impacting changes are visible in release notes before
merge.

## Release Checklist

Before a public release tag:

- CI is green on the release commit.
- `make check` or the documented platform equivalent passes locally.
- Slither baseline is reviewed and accepted.
- Gas and size snapshots are accepted. The current local gas baseline is
  `release-artifacts/baselines/v0.1.0/gas-snapshot.snap` and must pass
  `forge snapshot --match-path test/StreamGasSnapshot.t.sol --check
  release-artifacts/baselines/v0.1.0/gas-snapshot.snap`.
- Deployment rehearsal passes.
- ABI, bytecode, interface ID, event topic, broadcast-derived manifest input,
  deployment manifest, address book, source verification input, release
  manifest, bytecode-to-release proof, and checksum artifacts are generated and
  checked.
- Dependency source packages, migration plans, source-retention evidence,
  deprecation decisions, and unfrozen collection repins follow
  `docs/dependency-operations.md` when the release uses dependency registry
  versions.
- Randomizer provider configuration, funding/billing status, lifecycle controls,
  reserve policy, retained artifacts, and redaction policy follow
  `docs/randomizer-operations.md` and pass
  `python scripts/check_randomizer_operations.py`.
- Release signature evidence follows `docs/release-signatures.md` and passes
  `python scripts/check_release_signatures.py`.
- Signed release tag verification passes
  `python scripts/check_signed_release_tag.py` in non-release mode for ordinary
  PRs, and in `--mode release --tag <tag> --evidence <post-bundle-evidence>`
  mode before any public release tag claim.
- Bytecode-to-release proof passes
  `python scripts/generate_bytecode_release_proof.py --check`; the committed
  local/fork proof is not live-chain verification, and production completion
  requires reviewed retained live bytecode or explorer evidence.
- Drop authorization signing evidence follows
  `docs/drop-authorization-signing.md` and passes
  `python scripts/check_drop_authorization_signing_evidence.py`.
- Signer custody readiness evidence follows
  `docs/signer-custody-readiness.md` and passes
  `python scripts/check_signer_custody_readiness.py`.
- Public-beta evidence status follows `docs/public-beta-evidence.md`, keeps
  unresolved public-beta and production blockers visible, and passes
  `python scripts/check_public_beta_evidence.py`.
- Non-local release evidence follows `docs/non-local-release-evidence.md`
  before any fork, testnet, live, audit, explorer, gas, invariant, signature,
  or signed-tag row is marked complete in the public-beta evidence status.
- Architecture and threat-model evidence follows `docs/architecture.md` and
  `docs/threat-model.md` and passes
  `python scripts/check_architecture_threat_model.py`.
- The external audit package follows `docs/audit-package.md` and passes
  `python scripts/check_audit_package.py`.
- The release-readiness dashboard follows `docs/release-readiness.md` and
  passes `python scripts/check_release_readiness.py`.
- Royalty policy follows `docs/royalty-policy.md` and passes
  `python scripts/check_royalty_policy.py`.
- `CHANGELOG.md` describes user-visible and release-impacting changes.
- `SECURITY.md`, deployment docs, and known-risk docs are current.
- Contract verification status is recorded or explicitly blocked.
- Detached checksum signatures and signed Git tags are produced for public
  releases once maintainer signing-key policy is accepted. Detached checksum
  signature artifacts and the matching reviewed evidence must be retained as
  post-bundle proof outside the `SHA256SUMS` file they verify.
