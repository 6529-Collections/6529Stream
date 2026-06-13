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
python scripts/check_non_local_release_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/check_signer_custody_readiness.py
python scripts/check_public_beta_evidence.py
python scripts/generate_public_beta_blocker_report.py
python scripts/generate_production_release_blocker_report.py
python scripts/generate_release_evidence_packet_index.py
python scripts/generate_release_evidence_issue_backlog.py
python scripts/check_release_evidence_issue_links.py
python scripts/check_release_evidence_issue_labels.py
python scripts/check_release_evidence_live_audit_report.py
python scripts/generate_release_evidence_issue_body_sync.py
python scripts/check_release_evidence_issue_bodies.py
python scripts/check_release_evidence_issue_closure.py
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
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/test_public_beta_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/test_public_beta_blocker_report.py
python scripts/generate_public_beta_blocker_report.py --check
python scripts/test_production_release_blocker_report.py
python scripts/generate_production_release_blocker_report.py --check
python scripts/test_release_evidence_packet_index.py
python scripts/generate_release_evidence_packet_index.py --check
python scripts/test_release_evidence_issue_backlog.py
python scripts/generate_release_evidence_issue_backlog.py --check
python scripts/test_release_evidence_issue_links.py
python scripts/check_release_evidence_issue_links.py
python scripts/test_release_evidence_issue_snapshot.py
python scripts/test_release_evidence_issue_snapshot_audit.py
python scripts/test_release_evidence_live_audit_report.py
python scripts/check_release_evidence_live_audit_report.py
python scripts/test_release_evidence_issue_labels.py
python scripts/check_release_evidence_issue_labels.py
python scripts/test_release_evidence_issue_body_sync.py
python scripts/generate_release_evidence_issue_body_sync.py --check
python scripts/test_release_evidence_issue_bodies.py
python scripts/check_release_evidence_issue_bodies.py
python scripts/test_release_evidence_issue_closure.py
python scripts/check_release_evidence_issue_closure.py
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
public-beta evidence status, schema hashes, governance doc hashes including
`docs/architecture.md`, `docs/threat-model.md`, `docs/audit-package.md`,
`docs/incident-response.md`, `docs/public-beta-evidence.md`,
`docs/non-local-release-evidence.md`, and `docs/release-readiness.md`, and the
release-ceremony items that are not yet available for this pre-audit local
baseline.

`latest/public-beta-evidence.json` is the no-secret status manifest for
public-beta and production-release evidence. It stays blocked in the committed
local baseline until fork/testnet/live evidence, audit evidence, production
signatures, signed tags, explorer verification, and address evidence are
retained or explicitly risk-accepted.

`latest/public-beta-blockers.md` is generated from
`latest/public-beta-evidence.json`. It lists incomplete public-beta and
production rows, evidence posture, future external evidence categories, and
validation commands without changing the intentionally blocked readiness
status.

`latest/production-release-blockers.md` is generated from
`latest/public-beta-evidence.json` and the checked templates under
`evidence/production-release-templates/`. It lists only production-release
requirements, their evidence posture, matching template paths, future external
evidence categories, and validation commands without changing the intentionally
blocked production readiness status.

`latest/release-evidence-packet-index.json` and
`latest/release-evidence-packet-index.md` are generated from the evidence
manifest, blocker reports, and checked public-beta and production-release
templates. They map every evidence row to its blocker report, template,
retained-artifact expectation, validation commands, and current readiness
posture without treating templates as completion evidence.

`latest/release-evidence-issue-backlog.json` and
`latest/release-evidence-issue-backlog.md` are generated from
`latest/release-evidence-packet-index.json`. They turn every incomplete
public-beta and production-release packet row into an issue-ready title, label
set, body, retained-artifact completion gate, and validation command list.
They do not create issues automatically and do not change public-beta or
production-release readiness claims.

`latest/release-evidence-issue-links.json` is a committed no-secret tracker map
from each issue-backlog entry to its GitHub issue. It lets maintainers audit
that every incomplete evidence requirement has a durable issue without making
the issue itself completion evidence. The
`scripts/check_release_evidence_issue_labels.py` checker validates committed
`applied_labels` deterministically and can audit an exported live GitHub issue
JSON snapshot with `--live-json` before a release ceremony.
All retained-evidence tracker issues should carry `release`, `roadmap`, and
`evidence`; public-beta rows also carry `public-beta`, and production-release
rows also carry `production-release`.
Use `scripts/export_release_evidence_issue_snapshot.py` to write label, body,
or closure snapshots as UTF-8 JSON without relying on shell redirection.
Use `scripts/audit_release_evidence_issue_snapshots.py` as the operator-only
one-command live audit for label, body, and closure drift; CI runs only its
mocked unit tests and never requires GitHub network access.
When operators pass `--report-json` or `--report-md`, the live audit
orchestrator writes a retained no-secret report bundle with selected profiles,
repo target, snapshot paths, snapshot SHA-256 digests, command provenance,
checker outcomes, and the unchanged blocked-readiness warning. The report
schema lives at `schema/release-evidence-live-audit-report.schema.json`; the
default no-secret template report lives at
`evidence/release-evidence-live-audit-report-template.json`, with template
snapshots under `evidence/live-audit-report-template/`. Run
`scripts/check_release_evidence_live_audit_report.py` to validate retained
report bundles offline against snapshot digests, command provenance, profile
coverage, and the blocked-readiness posture. Report bundles are ceremony
evidence for review; they do not make any retained public-beta or production
evidence row complete.

`latest/release-evidence-issue-body-sync.json` and
`latest/release-evidence-issue-body-sync.md` join the generated backlog and
committed issue-link map into exact GitHub issue body payloads plus a Markdown
review view. They are no-secret, tracker-only artifacts; they do not update
GitHub automatically and do not make tracker closure retained evidence. The
`scripts/check_release_evidence_issue_bodies.py` checker validates committed
body payloads deterministically, can audit an exported live GitHub issue JSON
snapshot with `--live-json`, and can write deterministic per-issue body files
with `--write-body-files` for operator-run `gh issue edit --body-file`
remediation.

`scripts/check_release_evidence_issue_closure.py` validates the committed
tracker map, `release-evidence-issue-backlog.json` backlog artifact, body-sync
artifact, packet index, and shared release evidence status manifest agree on
tracker closure readiness. Its optional `--live-json` mode audits a
closure snapshot written by `scripts/export_release_evidence_issue_snapshot.py`
and fails if a linked tracker issue is closed while the committed evidence
status is still `missing`, `pending`, `blocked`, or `not_applicable`.

`evidence/non-local-release-evidence-template.json` is the checked no-secret
template for future reviewed non-local release evidence metadata. Its schema
lives at `schema/non-local-release-evidence.schema.json`, and the template
points at `evidence/non-local-template-retained-artifact.txt` to prove retained
artifact hash validation without claiming public-beta or production readiness.
`evidence/public-beta-templates/` contains one checked template JSON for each
public-beta requirement ID plus a shared retained-artifact placeholder. These
templates are release artifacts and checksum-covered operator starting points,
not completion evidence.

`evidence/production-release-templates/` contains one checked template JSON for
each production-release requirement ID plus a shared retained-artifact
placeholder. These templates are release artifacts and checksum-covered
operator starting points, not completion evidence.

`drop-authorization-signing/drop-authorization-signing-evidence-template.json`
is the checked no-secret template for future reviewed drop authorization
signing ceremonies. Its schema lives at
`schema/drop-authorization-signing-evidence.schema.json`, and the template
points at `drop-authorization-signing/drop-authorization-signing-retained-artifact.txt`
plus the generated unsigned payload output to prove payload/hash/reviewer
validation without claiming public-beta or production readiness.

`signer-custody-readiness/signer-custody-readiness-template.json` is the
checked no-secret template for future reviewed signer custody readiness
evidence. Its schema lives at `schema/signer-custody-readiness.schema.json`,
and the template points at
`signer-custody-readiness/signer-custody-readiness-retained-artifact.txt`,
`docs/signer-custody-readiness.md`, and `docs/incident-response.md` to prove
retained artifact and runbook hash validation without claiming public-beta or
production readiness.

`docs/architecture.md`, `docs/threat-model.md`, `docs/audit-package.md`,
`docs/incident-response.md`, `docs/public-beta-evidence.md`,
`docs/non-local-release-evidence.md`, `docs/signer-custody-readiness.md`, and
`docs/release-readiness.md` are the
auditor-facing architecture, trust-boundary, package, incident-response,
evidence-status, non-local evidence intake, signer custody readiness, and Gate G
readiness indexes for the current local baseline. They are validated before
release manifest generation, and the release manifest records their hashes as
governance documents.

`latest/SHA256SUMS` and `latest/release-checksums.json` are also generated
outputs. They cover the committed release artifact config, generated release
artifacts, dependency artifact descriptors/source files, ABI compatibility
baseline, deployment manifest config/examples, address books, ceremony evidence
bundles, randomizer operations evidence, release signature evidence, drop
authorization signing evidence, signer custody readiness evidence, artifact
schemas, non-local release evidence metadata and templates, public-beta
evidence status, release evidence packet index, release evidence issue backlog,
and release manifest. Treat
`SHA256SUMS` as the signable checksum file for a release; the committed local
signature evidence records that production detached signatures and signed tags
remain a maintainer release-ceremony step.

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
python scripts/check_non_local_release_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/check_signer_custody_readiness.py
python scripts/check_public_beta_evidence.py
python scripts/generate_public_beta_blocker_report.py
python scripts/generate_production_release_blocker_report.py
python scripts/generate_release_evidence_packet_index.py
python scripts/check_architecture_threat_model.py
python scripts/check_audit_package.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py
python scripts/generate_release_checksums.py
```

If only `release-artifacts/` changed, the manifest and address-book commands
should still be safe no-ops, and their `--check` modes will catch stale
deployment-derived inputs before the checksum bundle is refreshed.
