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
3. Keep `risk_acceptance` as `null`.
4. Run `python scripts/check_public_beta_evidence.py`.
5. Regenerate and check the release manifest and checksum bundle.

To move a requirement to `accepted_risk`, include `accepted_by`, `accepted_at`,
`expires_at`, `reference`, and `notes`. The `accepted_at` and `expires_at`
fields must use real ISO `YYYY-MM-DD` calendar dates, such as `2026-06-12`;
`scripts/check_public_beta_evidence.py` enforces the format and tests reject
free-form values. Risk acceptance should be rare, explicit, and tied to a
public issue, governance decision, or release note.
