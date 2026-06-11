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
- Deployment configs, schemas, examples, address books, or deployment manifest
  generation/check scripts.
- CI, `Makefile`, or local check wrappers that define the release gate.
- Release process docs such as this file, `docs/deployment.md`,
  `docs/tooling.md`, `SECURITY.md`, `CONTRIBUTING.md`, or the PR template.

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
- Payment, withdrawal, custody, settlement, emergency withdrawal, or accounting
  behavior change.
- Randomness provider, request lifecycle, retry, or stale callback behavior
  change.
- Deployment manifest, address book, release checksum, ABI compatibility, or
  artifact schema change.

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
- Event topic, interface ID, deployment manifest, address book, and checksum
  outputs must be regenerated before merge when their covered inputs change.

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
- Gas and size snapshots are accepted.
- Deployment rehearsal passes.
- ABI, bytecode, interface ID, event topic, deployment manifest, address book,
  and checksum artifacts are generated and checked.
- `CHANGELOG.md` describes user-visible and release-impacting changes.
- `SECURITY.md`, deployment docs, and known-risk docs are current.
- Contract verification status is recorded or explicitly blocked.
- Detached checksum signatures and signed git tags are produced once maintainer
  signing-key policy is accepted.
