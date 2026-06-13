# Release Readiness

This dashboard is the Gate G release-readiness entry point for 6529Stream.
It is a pre-audit local baseline, not production-ready, and not a security claim.
Local evidence does not replace fork/testnet/live evidence for public beta or
production release.

Use this file to answer one question before any release claim: what is already
proved by committed local evidence, and what still blocks a public beta or
production release?
Use [`docs/non-local-release-evidence.md`](non-local-release-evidence.md) as
the intake runbook for any fork, testnet, live, audit, gas, invariant,
verification, or signing evidence that updates the public-beta evidence status.
Use [`docs/incident-response.md`](incident-response.md) for no-secret triage,
containment, recovery, evidence retention, and reopening procedures when an
operational incident affects release readiness.
Use [`docs/drop-authorization-signing.md`](drop-authorization-signing.md) for
the local no-secret drop authorization signing fixtures, unsigned payload
generator templates, drop authorization signing evidence template, and the
EIP-712 / ERC-1271 evidence they cover.
Use [`docs/signer-custody-readiness.md`](signer-custody-readiness.md) for the
no-secret production signer custody readiness evidence model that must
accompany reviewed non-local signing evidence.
Use
[`release-artifacts/latest/public-beta-blockers.md`](../release-artifacts/latest/public-beta-blockers.md)
and
[`release-artifacts/latest/production-release-blockers.md`](../release-artifacts/latest/production-release-blockers.md)
as the generated blocker reports for the current evidence manifest, and use
[`release-artifacts/latest/release-evidence-packet-index.md`](../release-artifacts/latest/release-evidence-packet-index.md)
as the release evidence packet index that maps blocker rows to templates,
retained-artifact expectations, validation commands, and current readiness
posture. Use
[`release-artifacts/latest/release-evidence-issue-backlog.md`](../release-artifacts/latest/release-evidence-issue-backlog.md)
as the generated issue-preparation backlog for the same incomplete evidence
rows without creating issues automatically or changing readiness claims. Use
[`release-artifacts/latest/release-evidence-issue-links.json`](../release-artifacts/latest/release-evidence-issue-links.json)
as the committed tracker map from those generated backlog entries to GitHub
issues. Use
[`release-artifacts/latest/release-evidence-issue-body-sync.md`](../release-artifacts/latest/release-evidence-issue-body-sync.md)
as the generated no-secret review view for exact GitHub issue body payloads
derived from that backlog and tracker map. Run
`python scripts/check_release_evidence_issue_closure.py` before closing any
linked tracker issue; that release evidence issue closure readiness check loads
the tracker map, `release-evidence-issue-backlog.json` backlog artifact,
body-sync artifact, packet index, and evidence manifest, then keeps issues open
until committed evidence is `complete` or `accepted_risk`.

## Maturity And Scope

Current maturity:

- Repository status: pre-audit and not production-ready.
- Evidence status: local baseline only.
- Public beta status: blocked by missing fork/testnet/live evidence and
  external audit completion.
- Production release status: blocked by missing production signatures, signed
  Git tags, verified deployed addresses, explorer verification, non-local
  retained evidence, and post-audit remediation evidence.

This dashboard covers release-readiness evidence only. It does not perform a
real release, does not create production signatures, and does not assert that
local tests prove protocol correctness.

## Readiness Summary

| Area | Current state | Blocks public beta | Blocks production release |
| --- | --- | --- | --- |
| CI and local gates | Passing local/CI baseline exists for build, tests, size, local deployment rehearsals, incident response, release artifacts, architecture/threat model, audit package, release manifest, checksums, and changelog | No | No, but release commit CI must be green |
| Protocol maturity | Pre-audit, not production-ready, local baseline only | Yes | Yes |
| External audit | Audit package exists; completed external audit report and post-audit remediation do not exist | Yes | Yes |
| Deployment evidence | Local Anvil deployment, auction, metadata-browser, and emergency redeployment rehearsals exist | Fork/testnet/live evidence missing | Production broadcast retention, verified deployed addresses, and explorer verification missing |
| Release artifacts | Release manifest, checksum bundle, ABI baseline, gas snapshot, source verification inputs, address books, ceremony evidence, randomizer operations evidence, release-signature evidence, drop authorization signing fixtures, unsigned payload-generator examples, drop authorization signing evidence schema/template/checker, signer custody readiness schema/template/checker, public-beta evidence status, generated public-beta and production-release blocker reports, release evidence packet index, release evidence issue backlog, release evidence issue links, release evidence issue body sync, release evidence issue closure readiness, and non-local release evidence runbook, schema, generic template, per-requirement public-beta and production-release templates, and checker exist for the local baseline | Live release artifacts, production signing evidence, reviewed signer custody readiness, and reviewed non-local evidence missing | Production signatures and signed Git tags missing |
| Static analysis and tests | Slither baseline, test matrix, invariants, and local gas snapshot are tracked | Fork/testnet/live invariant and gas evidence missing | External audit and production evidence missing |

## Local Evidence Already Passing

The current local baseline includes:

- deterministic build, test, production size, gas snapshot, and deployment
  rehearsal gates through [`Makefile`](../Makefile), [`scripts/check.sh`](../scripts/check.sh),
  [`scripts/check.ps1`](../scripts/check.ps1), and GitHub CI;
- auditor-facing architecture, threat model, and audit package docs under
  [`docs/architecture.md`](architecture.md), [`docs/threat-model.md`](threat-model.md),
  and [`docs/audit-package.md`](audit-package.md);
- incident response procedures in
  [`docs/incident-response.md`](incident-response.md);
- drop authorization signing fixtures, unsigned payload-generator examples, and
  checked drop authorization signing evidence template in
  [`docs/drop-authorization-signing.md`](drop-authorization-signing.md) and
  [`test/fixtures/drop-authorization/`](../test/fixtures/drop-authorization/),
  [`release-artifacts/schema/drop-authorization-signing-evidence.schema.json`](../release-artifacts/schema/drop-authorization-signing-evidence.schema.json),
  [`release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json`](../release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json),
  and [`scripts/check_drop_authorization_signing_evidence.py`](../scripts/check_drop_authorization_signing_evidence.py);
- signer custody readiness guidance, schema, checked template, and checker in
  [`docs/signer-custody-readiness.md`](signer-custody-readiness.md),
  [`release-artifacts/schema/signer-custody-readiness.schema.json`](../release-artifacts/schema/signer-custody-readiness.schema.json),
  [`release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json),
  [`release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt),
  and [`scripts/check_signer_custody_readiness.py`](../scripts/check_signer_custody_readiness.py);
- release manifest and checksum bundle outputs under
  [`release-artifacts/latest/release-manifest.json`](../release-artifacts/latest/release-manifest.json),
  [`release-artifacts/latest/SHA256SUMS`](../release-artifacts/latest/SHA256SUMS),
  and [`release-artifacts/latest/release-checksums.json`](../release-artifacts/latest/release-checksums.json);
- source verification inputs under
  [`release-artifacts/latest/source-verification-inputs.json`](../release-artifacts/latest/source-verification-inputs.json);
- ABI compatibility and gas baselines under
  [`release-artifacts/baselines/v0.1.0/abi-surface.json`](../release-artifacts/baselines/v0.1.0/abi-surface.json)
  and [`release-artifacts/baselines/v0.1.0/gas-snapshot.snap`](../release-artifacts/baselines/v0.1.0/gas-snapshot.snap);
- no-secret local ceremony evidence, randomizer operations evidence, and
  release-signature evidence under
  [`deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json`](../deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json),
  [`deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json`](../deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json),
  and [`release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json`](../release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json);
- no-secret public-beta evidence status under
  [`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json)
  following [`docs/public-beta-evidence.md`](public-beta-evidence.md), plus the
  generated blocker reports at
  [`release-artifacts/latest/public-beta-blockers.md`](../release-artifacts/latest/public-beta-blockers.md)
  and
  [`release-artifacts/latest/production-release-blockers.md`](../release-artifacts/latest/production-release-blockers.md),
  plus the no-secret release evidence packet index at
  [`release-artifacts/latest/release-evidence-packet-index.json`](../release-artifacts/latest/release-evidence-packet-index.json)
  and
  [`release-artifacts/latest/release-evidence-packet-index.md`](../release-artifacts/latest/release-evidence-packet-index.md),
  plus the generated release evidence issue backlog at
  [`release-artifacts/latest/release-evidence-issue-backlog.json`](../release-artifacts/latest/release-evidence-issue-backlog.json)
  and
  [`release-artifacts/latest/release-evidence-issue-backlog.md`](../release-artifacts/latest/release-evidence-issue-backlog.md),
  plus the committed GitHub tracker map at
  [`release-artifacts/latest/release-evidence-issue-links.json`](../release-artifacts/latest/release-evidence-issue-links.json),
  plus deterministic live issue snapshot exporter tests with
  `python scripts/test_release_evidence_issue_snapshot.py` and
  `python scripts/test_release_evidence_issue_snapshot_audit.py`,
  plus deterministic tracker-label checks with
  `python scripts/test_release_evidence_issue_labels.py` and
  `python scripts/check_release_evidence_issue_labels.py`,
  plus the generated exact issue body payloads at
  [`release-artifacts/latest/release-evidence-issue-body-sync.json`](../release-artifacts/latest/release-evidence-issue-body-sync.json)
  and
  [`release-artifacts/latest/release-evidence-issue-body-sync.md`](../release-artifacts/latest/release-evidence-issue-body-sync.md),
  plus deterministic tracker-body checks with
  `python scripts/test_release_evidence_issue_bodies.py` and
  `python scripts/check_release_evidence_issue_bodies.py`, plus release
  evidence issue closure readiness checks with
  `python scripts/test_release_evidence_issue_closure.py` and
  `python scripts/check_release_evidence_issue_closure.py`;
- non-local release evidence intake requirements, schema, checked template, and
  checker under [`docs/non-local-release-evidence.md`](non-local-release-evidence.md),
  [`release-artifacts/schema/non-local-release-evidence.schema.json`](../release-artifacts/schema/non-local-release-evidence.schema.json),
  [`release-artifacts/evidence/non-local-release-evidence-template.json`](../release-artifacts/evidence/non-local-release-evidence-template.json),
  [`release-artifacts/evidence/public-beta-templates/`](../release-artifacts/evidence/public-beta-templates/),
  [`release-artifacts/evidence/production-release-templates/`](../release-artifacts/evidence/production-release-templates/),
  and [`scripts/check_non_local_release_evidence.py`](../scripts/check_non_local_release_evidence.py);
- Slither baseline evidence in [`ops/SLITHER_BASELINE.md`](../ops/SLITHER_BASELINE.md)
  and [`docs/slither.md`](slither.md);
- the test matrix in [`ops/ROADMAP.md`](../ops/ROADMAP.md#appendix-b-test-matrix);
- the ADR index in [`docs/adr/README.md`](adr/README.md).

These items are release evidence, not launch approval.

## Public Beta Blockers

Public beta remains blocked until maintainers add or explicitly accept evidence
for:

- completed external audit report and issue-linked remediation status;
- fork/testnet/live evidence for deployment rehearsal, metadata browser
  execution, ceremony evidence, randomizer operations evidence, emergency
  redeployment evidence, and invariant/gas checks following
  [`docs/non-local-release-evidence.md`](non-local-release-evidence.md);
- production address books generated from retained broadcast artifacts;
- verified deployed addresses and explorer verification status;
- production signer and admin ceremony evidence with secrets redacted;
- reviewed signer custody readiness evidence with custody owner, signer
  manager, signer epoch source, signer-service integration, ERC-1271 status,
  rotation/revocation drills, monitoring, and incident-response references;
- production drop authorization signing evidence and approved signer
  integration beyond the no-secret local fixtures and unsigned payload
  generator;
- a final review that known blockers in [`docs/known-blockers.md`](known-blockers.md)
  and [`ops/ROADMAP.md`](../ops/ROADMAP.md) have either been resolved or
  explicitly deferred outside public beta.

## Production Release Blockers

Production release remains blocked until maintainers add or explicitly accept:

- production signatures over the checksum bundle;
- signed Git tags for the release commit;
- production release-signature evidence following
  [`docs/release-signatures.md`](release-signatures.md);
- retained production broadcast outputs and generated live deployment manifests;
- verified deployed addresses and explorer verification output;
- post-audit remediation evidence for every accepted audit finding;
- dependency source retention and migration evidence following
  [`docs/dependency-operations.md`](dependency-operations.md);
- randomizer provider configuration, funding, lifecycle, and request-health
  evidence following [`docs/randomizer-operations.md`](randomizer-operations.md).
- no-secret non-local release evidence intake records following
  [`docs/non-local-release-evidence.md`](non-local-release-evidence.md).

## Required Evidence Links

Core project and governance:

- [README.md](../README.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)
- [SECURITY.md](../SECURITY.md)
- [CHANGELOG.md](../CHANGELOG.md)
- [ops/ROADMAP.md](../ops/ROADMAP.md)
- [ops/AUTONOMOUS_RUN.md](../ops/AUTONOMOUS_RUN.md)
- [docs/status.md](status.md)
- [docs/known-blockers.md](known-blockers.md)
- [docs/release-readiness.md](release-readiness.md)

Audit and protocol evidence:

- [docs/audit-package.md](audit-package.md)
- [docs/incident-response.md](incident-response.md)
- [docs/drop-authorization-signing.md](drop-authorization-signing.md)
- [docs/signer-custody-readiness.md](signer-custody-readiness.md)
- [docs/architecture.md](architecture.md)
- [docs/threat-model.md](threat-model.md)
- [docs/deployment.md](deployment.md)
- [docs/release-policy.md](release-policy.md)
- [docs/release-signatures.md](release-signatures.md)
- [docs/public-beta-evidence.md](public-beta-evidence.md)
- [docs/non-local-release-evidence.md](non-local-release-evidence.md)
- [docs/randomizer-operations.md](randomizer-operations.md)
- [docs/dependency-operations.md](dependency-operations.md)
- [docs/slither.md](slither.md)
- [docs/tooling.md](tooling.md)
- [docs/adr/README.md](adr/README.md)
- [ops/SLITHER_BASELINE.md](../ops/SLITHER_BASELINE.md)

Release artifacts:

- [release-artifacts/README.md](../release-artifacts/README.md)
- [release-artifacts/latest/release-manifest.json](../release-artifacts/latest/release-manifest.json)
- [release-artifacts/latest/SHA256SUMS](../release-artifacts/latest/SHA256SUMS)
- [release-artifacts/latest/release-checksums.json](../release-artifacts/latest/release-checksums.json)
- [release-artifacts/latest/public-beta-evidence.json](../release-artifacts/latest/public-beta-evidence.json)
- [release-artifacts/latest/public-beta-blockers.md](../release-artifacts/latest/public-beta-blockers.md)
- [release-artifacts/latest/production-release-blockers.md](../release-artifacts/latest/production-release-blockers.md)
- [release-artifacts/latest/release-evidence-packet-index.json](../release-artifacts/latest/release-evidence-packet-index.json)
- [release-artifacts/latest/release-evidence-packet-index.md](../release-artifacts/latest/release-evidence-packet-index.md)
- [release-artifacts/latest/release-evidence-issue-backlog.json](../release-artifacts/latest/release-evidence-issue-backlog.json)
- [release-artifacts/latest/release-evidence-issue-backlog.md](../release-artifacts/latest/release-evidence-issue-backlog.md)
- [release-artifacts/latest/release-evidence-issue-links.json](../release-artifacts/latest/release-evidence-issue-links.json)
- [release-artifacts/latest/release-evidence-issue-body-sync.json](../release-artifacts/latest/release-evidence-issue-body-sync.json)
- [release-artifacts/latest/release-evidence-issue-body-sync.md](../release-artifacts/latest/release-evidence-issue-body-sync.md)
- [release-artifacts/latest/source-verification-inputs.json](../release-artifacts/latest/source-verification-inputs.json)
- [release-artifacts/schema/public-beta-evidence.schema.json](../release-artifacts/schema/public-beta-evidence.schema.json)
- [release-artifacts/schema/drop-authorization-signing-evidence.schema.json](../release-artifacts/schema/drop-authorization-signing-evidence.schema.json)
- [release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json](../release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json)
- [release-artifacts/drop-authorization-signing/drop-authorization-signing-retained-artifact.txt](../release-artifacts/drop-authorization-signing/drop-authorization-signing-retained-artifact.txt)
- [release-artifacts/schema/signer-custody-readiness.schema.json](../release-artifacts/schema/signer-custody-readiness.schema.json)
- [release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json](../release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json)
- [release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt](../release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt)
- [release-artifacts/schema/non-local-release-evidence.schema.json](../release-artifacts/schema/non-local-release-evidence.schema.json)
- [release-artifacts/evidence/non-local-release-evidence-template.json](../release-artifacts/evidence/non-local-release-evidence-template.json)
- [release-artifacts/evidence/non-local-template-retained-artifact.txt](../release-artifacts/evidence/non-local-template-retained-artifact.txt)
- [release-artifacts/evidence/public-beta-templates/](../release-artifacts/evidence/public-beta-templates/)
- [release-artifacts/evidence/production-release-templates/](../release-artifacts/evidence/production-release-templates/)
- [release-artifacts/baselines/v0.1.0/abi-surface.json](../release-artifacts/baselines/v0.1.0/abi-surface.json)
- [release-artifacts/baselines/v0.1.0/gas-snapshot.snap](../release-artifacts/baselines/v0.1.0/gas-snapshot.snap)
- [deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json](../deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json)
- [deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json](../deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json)
- [release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json](../release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json)

## Release Commands

Run the dashboard checker directly:

```sh
python scripts/test_release_readiness.py
python scripts/check_release_readiness.py
python scripts/test_incident_response.py
python scripts/check_incident_response.py
python scripts/test_drop_authorization_payload_generator.py
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/fixed-price-input.json --output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json --check
python scripts/generate_drop_authorization_payload.py --input test/fixtures/drop-authorization/payload-generator/auction-input.json --output test/fixtures/drop-authorization/payload-generator/auction-output.json --check
python scripts/test_drop_authorization_fixtures.py
python scripts/check_drop_authorization_fixtures.py
python scripts/test_drop_authorization_signing_evidence.py
python scripts/check_drop_authorization_signing_evidence.py
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/test_public_beta_evidence.py
python scripts/check_public_beta_evidence.py
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
python scripts/test_release_evidence_issue_labels.py
python scripts/check_release_evidence_issue_labels.py
python scripts/test_release_evidence_issue_body_sync.py
python scripts/generate_release_evidence_issue_body_sync.py --check
python scripts/test_release_evidence_issue_bodies.py
python scripts/check_release_evidence_issue_bodies.py
python scripts/test_release_evidence_issue_closure.py
python scripts/check_release_evidence_issue_closure.py
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
```

Run the release evidence drift checks:

```sh
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

Run the full local release gate:

```sh
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Maintenance

Update this dashboard whenever a release gate, launch gate, evidence artifact,
production blocker, or accepted risk changes.

Required maintenance rules:

- New release evidence must be linked here before it can be treated as part of
  the public release baseline.
- New blockers must be added here, [`docs/known-blockers.md`](known-blockers.md),
  or [`ops/ROADMAP.md`](../ops/ROADMAP.md) before a PR claims readiness.
- Any public beta or production-ready claim must point to the CI run, release
  manifest, checksum bundle, signatures, signed tag, deployment evidence,
  explorer verification, audit report, and post-audit remediation evidence that
  justify it.
- Any fork/testnet/live evidence that changes public-beta or production status
  must follow the non-local release evidence intake runbook and include a
  reviewer before the related requirement is marked `complete`.
- Regenerate the release manifest and checksum bundle after changing this file,
  because it is a governance document in the release evidence package.
