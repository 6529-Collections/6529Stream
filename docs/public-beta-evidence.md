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
```

## Evidence Artifact

The canonical status file is
[`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json).
Its schema is
[`release-artifacts/schema/public-beta-evidence.schema.json`](../release-artifacts/schema/public-beta-evidence.schema.json).

The status file is included in release manifest and checksum coverage, so
changes to blocker status, retained evidence paths, hashes, or risk acceptance
records must refresh the generated release artifacts before release.

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
is a checked template only.

Drop authorization signing evidence should also follow
[`release-artifacts/schema/drop-authorization-signing-evidence.schema.json`](../release-artifacts/schema/drop-authorization-signing-evidence.schema.json)
and pass `python scripts/check_drop_authorization_signing_evidence.py` before
any public-beta or production status row relies on it. The committed
[`release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json`](../release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json)
is a local template only, not completion evidence.

Signer custody readiness evidence should follow
[`release-artifacts/schema/signer-custody-readiness.schema.json`](../release-artifacts/schema/signer-custody-readiness.schema.json)
and pass `python scripts/check_signer_custody_readiness.py` before any
public-beta or production status row relies on non-local drop authorization
signing. The committed
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

1. Add the retained public evidence file to the repository.
2. Add the evidence file path and `sha256:` digest to the relevant requirement.
3. Confirm the evidence follows the non-local release evidence intake runbook
   when the requirement depends on fork, testnet, live, audit, explorer, gas,
   invariant, checksum-backed production-signature, signed-tag,
   production-address-book, or production-broadcast-retention proof.
4. Keep `risk_acceptance` as `null`.
5. Run `python scripts/check_public_beta_evidence.py`.
6. Run `python scripts/check_non_local_release_evidence.py` for every reviewed
   non-local evidence metadata JSON that supports the row.
7. Run `python scripts/check_drop_authorization_signing_evidence.py` for any
   retained drop authorization signing evidence that supports the row.
8. Run `python scripts/check_signer_custody_readiness.py` for any signer
   custody readiness evidence that supports the row.
9. Regenerate and check the release manifest and checksum bundle.

To move a requirement to `accepted_risk`, include `accepted_by`, `accepted_at`,
`expires_at`, `reference`, and `notes`. The `accepted_at` and `expires_at`
fields must use real ISO `YYYY-MM-DD` calendar dates, such as `2026-06-12`;
`scripts/check_public_beta_evidence.py` enforces the format and tests reject
free-form values. Risk acceptance should be rare, explicit, and tied to a
public issue, governance decision, or release note.
