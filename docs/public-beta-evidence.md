# Public Beta Evidence

This document defines the no-secret evidence status manifest for public beta and
production release readiness.

The committed baseline is intentionally blocked. It records the categories that
must be supplied before public beta or production release, but it does not claim
that fork, testnet, live, external audit, production signing, signed Git tag, or
explorer verification evidence exists.

Validate the evidence status with:

```sh
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
```

## Evidence Artifact

The canonical status file is
[`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json).
Its schema is
[`release-artifacts/schema/public-beta-evidence.schema.json`](../release-artifacts/schema/public-beta-evidence.schema.json).
The filename is retained for compatibility with the original public-beta
evidence gate, but the manifest is now the shared release evidence status
manifest for both public-beta and production-release requirement rows.

The status file is included in release manifest and checksum coverage, so
changes to blocker status, retained evidence paths, hashes, or risk acceptance
records must refresh the generated release artifacts before release.

The generated blocker report is
[`release-artifacts/latest/public-beta-blockers.md`](../release-artifacts/latest/public-beta-blockers.md).
It is derived from the status file, lists incomplete public-beta and production
rows plus their evidence posture, and repeats the validation commands for the
underlying evidence families. It does not mark any row complete or claim public
beta or production readiness.

The production-focused blocker report is
[`release-artifacts/latest/production-release-blockers.md`](../release-artifacts/latest/production-release-blockers.md).
It is derived from the same status file but renders only production-release
requirements and links the matching checked template under
`release-artifacts/evidence/production-release-templates/` for each row.
It also preserves the blocked baseline and does not claim production readiness.

The release evidence packet index is generated as both
[`release-artifacts/latest/release-evidence-packet-index.json`](../release-artifacts/latest/release-evidence-packet-index.json)
and
[`release-artifacts/latest/release-evidence-packet-index.md`](../release-artifacts/latest/release-evidence-packet-index.md).
It maps every public-beta and production-release requirement to the blocker
report row, checked template path, retained-artifact expectation, validation
commands, and current blocked posture. Template rows remain template-only and
cannot complete evidence requirements by themselves.

The release evidence issue backlog is generated as both
[`release-artifacts/latest/release-evidence-issue-backlog.json`](../release-artifacts/latest/release-evidence-issue-backlog.json)
and
[`release-artifacts/latest/release-evidence-issue-backlog.md`](../release-artifacts/latest/release-evidence-issue-backlog.md).
It turns every incomplete packet row into an issue-ready title, label set,
body, validation command list, and completion gate. It does not create GitHub
issues automatically, does not mark evidence complete, and keeps
template-only evidence out of completion criteria.

The release evidence issue-link map is committed at
[`release-artifacts/latest/release-evidence-issue-links.json`](../release-artifacts/latest/release-evidence-issue-links.json).
It links every generated backlog entry to a durable GitHub tracker issue while
remaining no-secret and tracker-only. Closing those tracker issues still
requires reviewed retained evidence in the status manifest.
Every linked tracker issue should carry `release`, `roadmap`, and `evidence`.
Public-beta tracker issues should also carry `public-beta`; production-release
tracker issues should also carry `production-release`.

The release evidence issue body sync artifact is generated as both
[`release-artifacts/latest/release-evidence-issue-body-sync.json`](../release-artifacts/latest/release-evidence-issue-body-sync.json)
and
[`release-artifacts/latest/release-evidence-issue-body-sync.md`](../release-artifacts/latest/release-evidence-issue-body-sync.md).
It joins the generated backlog and committed issue-link map into exact GitHub
issue body payloads so tracker issues can be updated consistently. It remains
no-secret and tracker-only, does not update GitHub automatically, and does not
make issue closure completion evidence.

The release evidence issue closure checker,
`scripts/check_release_evidence_issue_closure.py`, validates that the committed
tracker map, `release-evidence-issue-backlog.json` backlog artifact, body-sync
artifact, packet index, and shared release evidence status manifest agree on
which tracker issues may close. A linked tracker issue should remain open while
its committed evidence status is `missing`, `pending`, `blocked`, or
`not_applicable`; it may close only after the committed status is `complete` or
`accepted_risk`.

The checker constants in `scripts/check_public_beta_evidence.py` are the
canonical requirement list. If the required public-beta or production rows
change, update the schema's `requirements.minItems` count and this document in
the same PR.

Use [`docs/non-local-release-evidence.md`](non-local-release-evidence.md) before
moving any fork, testnet, live, audit, explorer, gas, invariant,
checksum-backed production-signature, signed-tag, production-address-book, or
production-broadcast-retention requirement to `complete`. That runbook defines
required retained artifact fields, no-secret redaction boundaries, reviewer
expectations, and the requirement IDs that each evidence family updates.
Rows governed by that runbook should link reviewed JSON metadata that follows
[`release-artifacts/schema/non-local-release-evidence.schema.json`](../release-artifacts/schema/non-local-release-evidence.schema.json);
the committed
[`release-artifacts/evidence/non-local-release-evidence-template.json`](../release-artifacts/evidence/non-local-release-evidence-template.json)
is a checked template only. Requirement-specific public-beta templates live
under
[`release-artifacts/evidence/public-beta-templates/`](../release-artifacts/evidence/public-beta-templates/).
They map one checked template JSON to each public-beta requirement ID, but they
are still template-only artifacts and do not make any status row `complete`.
Requirement-specific production-release templates live under
[`release-artifacts/evidence/production-release-templates/`](../release-artifacts/evidence/production-release-templates/).
They map one checked template JSON to each production-release requirement ID
and are also template-only artifacts.

Drop authorization signing evidence should also follow
[`release-artifacts/schema/drop-authorization-signing-evidence.schema.json`](../release-artifacts/schema/drop-authorization-signing-evidence.schema.json)
and pass `python scripts/check_drop_authorization_signing_evidence.py` before
any public-beta or production status row relies on it. The committed
[`release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json`](../release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json)
is a local template only, not completion evidence.

Signer custody readiness evidence should follow
[`release-artifacts/schema/signer-custody-readiness.schema.json`](../release-artifacts/schema/signer-custody-readiness.schema.json)
and pass `python scripts/check_signer_custody_readiness.py` before any
public-beta or production status row relies on signer custody readiness
evidence for non-local signing. The committed
[`release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json)
is a checked local template only, not completion evidence.

## Status Values

Each requirement uses one of these statuses:

- `missing`: required evidence does not exist yet.
- `pending`: work has started, but evidence is not complete or reviewed.
- `blocked`: evidence is blocked by an external dependency or unresolved
  protocol/release decision.
- `accepted_risk`: maintainers intentionally accepted a missing or incomplete
  requirement with owner, dates, reference, and notes.
- `not_applicable`: the requirement does not apply to the selected release
  mode and the notes explain why.
- `complete`: retained evidence exists, is linked from the status file, and the
  recorded SHA256 digest matches the committed file.

`status.public_beta` and `status.production_release` may be `ready` only when
their requirement rows have no `missing`, `pending`, or `blocked` entries.

## Public Beta Requirements

Public beta evidence must account for:

- external audit report and remediation state;
- fork deployment rehearsal evidence;
- testnet deployment rehearsal evidence;
- fork/testnet metadata browser evidence;
- fork/testnet ceremony evidence;
- fork/testnet randomizer operations evidence;
- verified deployed addresses;
- explorer verification status.

## Production Release Requirements

Production release evidence must account for:

- production checksum signatures;
- signed Git tag verification;
- production address books;
- retained production broadcast outputs;
- reviewed signer custody readiness evidence;
- live deployment manifests;
- live ceremony evidence;
- live randomizer operations evidence;
- live explorer verification;
- post-audit remediation evidence.

## No-Secret Rule

Evidence files must not include private keys, mnemonics, seed phrases, API keys,
RPC URLs, passwords, or unreleased drop payloads. Retain public hashes, public
transaction identifiers, public explorer links, redacted command transcripts,
review references, and generated artifacts instead.

If a future evidence file needs private operator details, keep that file outside
the public repository and store only a public hash, redacted summary, or
maintainer-approved reference here.

## Updating Evidence

To move a requirement to `complete`:

1. Start from the matching template under
   `release-artifacts/evidence/public-beta-templates/` when the row maps to a
   public-beta requirement, or under
   `release-artifacts/evidence/production-release-templates/` when the row maps
   to a production-release requirement.
2. Add the retained public evidence file to the repository.
3. Add the evidence file path and `sha256:` digest to the relevant requirement.
4. Confirm the evidence follows the non-local release evidence intake runbook
   when the requirement depends on fork, testnet, live, audit, explorer, gas,
   invariant, checksum-backed production-signature, signed-tag,
   production-address-book, or production-broadcast-retention proof.
5. Keep `risk_acceptance` as `null`.
6. Run `python scripts/check_public_beta_evidence.py`.
7. Run `python scripts/check_non_local_release_evidence.py` for every reviewed
   non-local evidence metadata JSON that supports the row.
8. Run `python scripts/check_drop_authorization_signing_evidence.py` for any
   retained drop authorization signing evidence that supports the row.
9. Run `python scripts/check_signer_custody_readiness.py` for any signer
   custody readiness evidence that supports the row.
10. Regenerate and check the blocker reports with
   `python scripts/generate_public_beta_blocker_report.py` and
   `python scripts/generate_production_release_blocker_report.py`.
11. Regenerate and check the release evidence packet index with
   `python scripts/generate_release_evidence_packet_index.py`,
   `python scripts/test_release_evidence_packet_index.py`, and
   `python scripts/generate_release_evidence_packet_index.py --check`.
12. Regenerate and check the release evidence issue backlog with
   `python scripts/generate_release_evidence_issue_backlog.py`,
   `python scripts/test_release_evidence_issue_backlog.py`, and
   `python scripts/generate_release_evidence_issue_backlog.py --check`.
13. Check the issue-link map with
    `python scripts/test_release_evidence_issue_links.py` and
    `python scripts/check_release_evidence_issue_links.py`.
14. Check committed release evidence tracker labels with
    `python scripts/test_release_evidence_issue_labels.py` and
    `python scripts/check_release_evidence_issue_labels.py`. To audit live
    GitHub label, body, and closure drift together, run the operator-only
    no-secret orchestrator:

    ```bash
    python scripts/audit_release_evidence_issue_snapshots.py
    ```

    To audit only live GitHub label drift, export a local snapshot and pass it
    with `--live-json`:

    ```bash
    python scripts/export_release_evidence_issue_snapshot.py --profile labels
    python scripts/check_release_evidence_issue_labels.py --live-json tmp/release-evidence-issue-labels.json
    ```

15. Regenerate and check the release evidence issue body sync artifact with
    `python scripts/generate_release_evidence_issue_body_sync.py`,
    `python scripts/test_release_evidence_issue_body_sync.py`, and
    `python scripts/generate_release_evidence_issue_body_sync.py --check`.
16. Check committed release evidence tracker bodies with
    `python scripts/test_release_evidence_issue_bodies.py` and
    `python scripts/check_release_evidence_issue_bodies.py`. To audit live
    GitHub body drift, export a local snapshot and pass it with `--live-json`:

    ```bash
    python scripts/export_release_evidence_issue_snapshot.py --profile bodies
    python scripts/check_release_evidence_issue_bodies.py --live-json tmp/release-evidence-issue-bodies.json
    ```

    If drift is reported, generate deterministic body files with
    `python scripts/check_release_evidence_issue_bodies.py --write-body-files tmp/release-evidence-issue-bodies`
    and apply the issue-specific `gh issue edit ... --body-file ...` command
    printed by the checker.
17. Check release evidence tracker closure readiness with
    `python scripts/test_release_evidence_issue_closure.py` and
    `python scripts/check_release_evidence_issue_closure.py`. To audit live
    GitHub closure state, export all tracker issues and pass the snapshot with
    `--live-json`:

    ```bash
    python scripts/export_release_evidence_issue_snapshot.py --profile closure
    python scripts/check_release_evidence_issue_closure.py --live-json tmp/release-evidence-issue-closure.json
    ```

    If premature closure is reported, reopen the issue with the remediation
    command printed by the checker and keep it open until retained evidence is
    complete or explicitly risk-accepted in the committed manifest.
18. Regenerate and check the release manifest and checksum bundle.

To move a requirement to `accepted_risk`, include `accepted_by`, `accepted_at`,
`expires_at`, `reference`, and `notes`. The `accepted_at` and `expires_at`
fields must use real ISO `YYYY-MM-DD` calendar dates, such as `2026-06-12`;
`scripts/check_public_beta_evidence.py` enforces the format and tests reject
free-form values. Risk acceptance should be rare, explicit, and tied to a
public issue, governance decision, or release note.
