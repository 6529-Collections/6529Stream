# Signer Custody Readiness

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins.

This guide defines the no-secret evidence format for production, fork, or
testnet drop authorization signer custody readiness. It is pre-audit and not a
security claim. The committed template proves only that the repository can
validate the evidence shape; it does not prove production signer custody,
public-beta readiness, or live signer-service integration.

Use this guide with
[`docs/drop-authorization-signing.md`](drop-authorization-signing.md),
[`docs/integrations/wallets-and-signatures.md`](integrations/wallets-and-signatures.md),
[`docs/deployment.md#admin-ceremony-evidence`](deployment.md#admin-ceremony-evidence),
[`docs/incident-response.md`](incident-response.md),
[`docs/non-local-release-evidence.md`](non-local-release-evidence.md), and
[`docs/release-readiness.md`](release-readiness.md).

## Evidence Model

Signer custody readiness evidence must record:

- the environment, chain ID, source commit, and CI or review reference;
- signer type, expected signer address, signer epoch, signer epoch source,
  signer manager address, signer manager type, ERC-1271 support status, and
  signer-service class;
- custody owner, custody status, custody system, approval workflow reference,
  key-material location class, and separation-of-duties status;
- rotation readiness, revocation readiness, compromise response readiness,
  signer epoch rotation drill status, per-drop cancellation drill status, and
  last drill references;
- monitoring status, alerting reference, signer-service integration status,
  and runbook links;
- owner, reviewer, approval status, retained artifact paths, retained SHA-256
  hashes, and redaction policy.

The checker rejects secret-shaped keys or values. Public evidence may contain
addresses, hashes, redacted references, reviewer names, public issue or ticket
IDs, and sanitized command transcripts. It must not contain private keys,
mnemonics, seed phrases, HSM credentials, signer-service secrets, API keys,
RPC URLs, raw signatures, or unreleased drop payloads.

## Local Template

The schema is
[`release-artifacts/schema/signer-custody-readiness.schema.json`](../release-artifacts/schema/signer-custody-readiness.schema.json).
The checked local template is
[`release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json).
The template references
[`release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt`](../release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt)
to prove retained artifact hash validation.

The committed template intentionally uses `not_available_local` and `TBD`
placeholders. Fork, testnet, mainnet, and production evidence cannot use those
local placeholders for signer type, signer manager type, signer-service class,
custody status, key-material location, lifecycle readiness, monitoring, or
signer-service integration.

## Public Beta Requirements

Before public beta, signer custody readiness evidence must be reviewed and must
identify the approved custody owner, signer manager, signer-service class,
approval workflow, signer epoch source, monitoring runbook, incident-response
path, rotation procedure, revocation procedure, and signer compromise response.
The reviewed deployment admin ceremony evidence should independently prove the
matching signer manager, signer setup status, ownership handoff, temporary
deployer-admin revocation, and pause or emergency controls for the deployed
contracts.

The evidence must also show whether ERC-1271 contract signers are supported for
the selected signer. If an ERC-1271 signer is used for production, support must
be recorded as `supported`; otherwise the evidence must explicitly mark the
status as `not_applicable`, `pending`, `blocked`, or `unsupported` and include
machine-checked rationale in `signer_identity.erc1271_support_detail.rationale`
plus a retained or reviewed reference in
`signer_identity.erc1271_support_detail.evidence_reference`.

Production evidence must be reviewed and approved, with rotation, revocation,
compromise response, monitoring, signer-service integration, signer epoch
rotation drill, and per-drop cancellation drill all complete or validated.

## Local Verification Commands

```sh
python scripts/test_signer_custody_readiness.py
python scripts/check_signer_custody_readiness.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
make check
```

## Maintenance

Update this guide, schema, template, checker, and release evidence whenever the
drop signer model, signer manager model, signer epoch source, signer-service
class, ERC-1271 policy, rotation or revocation ceremony, signer compromise
response, monitoring policy, or redaction policy changes.
