# Non-Local Release Evidence

This runbook defines how maintainers collect and review fork, testnet, live,
audit, and signed-release evidence before a public beta or production release.

The repository's committed local baseline is intentionally blocked. Non-local
release evidence is the retained, no-secret proof that an operator ran the
release process against a non-local environment and that a reviewer can tie the
result back to a specific release commit, chain, deployment, artifact, and
public-beta evidence requirement.

## Scope

Use this runbook for evidence that cannot be produced by the local Anvil gate:

- fork deployment rehearsals;
- testnet deployments and explorer verification;
- live deployments, sanitized broadcasts, address books, and explorer links;
- fork/testnet/live metadata browser execution;
- fork/testnet/live deployment and admin ceremonies;
- fork/testnet/live randomizer provider operations;
- fork/testnet/live gas and invariant evidence;
- external audit reports and remediation status;
- checksum signatures, signed tags, and release-signing verification.

This runbook does not require secrets, private RPC URLs, private keys, mnemonics,
API tokens, unreleased drop payloads, or private audit drafts to be committed to
the public repository.

## Evidence Destinations

Use the most specific existing evidence directory when one exists:

| Evidence family | Preferred retained path |
| --- | --- |
| Deployment manifests | `deployments/examples/` |
| Sanitized broadcasts | `deployments/broadcasts/` |
| Address books | `deployments/address-books/` |
| Ceremony evidence | `deployments/ceremony-evidence/` |
| Randomizer operations evidence | `deployments/randomizer-operations/` |
| Release signatures | `release-artifacts/signatures/` |
| Release manifests and checksums | `release-artifacts/latest/` |
| Audit or remediation summaries | `docs/audits/` or `docs/audit-package.md` |
| Browser, gas, invariant, or explorer transcripts | A release-specific subdirectory under `release-artifacts/evidence/` |

If a new evidence family needs a schema, add the schema and checker before
marking the related public-beta row complete.

## Required Artifact Fields

Every retained non-local evidence file or redacted transcript must include, or
be accompanied by a small manifest that includes, these fields:

| Field | Requirement |
| --- | --- |
| `environment` | `fork`, `testnet`, `live`, `audit`, or `release_signing` |
| `chain_id` | Numeric chain ID, or `not_applicable` for audit-only/signing-only evidence |
| `block_or_reference` | Block number/hash, fork block, transaction hash, explorer URL, audit report ID, CI run, or signed-tag ref |
| `command_or_source_system` | Exact command, CI job, explorer, Safe transaction, audit portal, or signing tool that produced the artifact |
| `retained_path` | Repository path to the retained public artifact |
| `sha256` | `sha256:` digest of the retained artifact |
| `redaction_statement` | Explicit statement that secrets and unreleased drop payloads were removed or were never present |
| `owner` | Maintainer/operator responsible for the evidence |
| `reviewer` | Independent reviewer or `TBD` until review is complete |
| `public_beta_requirement_id` | Matching row in `release-artifacts/latest/public-beta-evidence.json` |

Prefer JSON for machine-readable evidence and Markdown for human reports. If a
Markdown report references generated JSON artifacts, include the JSON path and
digest in the report.

## Public-Beta Requirement Mapping

When evidence is retained, update the matching requirement row in
[`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json).

| Requirement ID | Evidence to retain before `complete` |
| --- | --- |
| `external_audit_report` | Final external audit report, scope, commit, issue-linked findings, and remediation state |
| `fork_deployment_rehearsal` | Fork transcript, sanitized broadcast, manifest, address book, verification status, gas/invariant summary |
| `testnet_deployment_rehearsal` | Testnet transcript, sanitized broadcast, manifest, address book, explorer verification status |
| `fork_testnet_metadata_browser_evidence` | Browser execution output for token metadata generated from deployed fork/testnet contracts |
| `fork_testnet_ceremony_evidence` | Fork/testnet deployment/admin/signer/auction/emergency ceremony evidence |
| `fork_testnet_randomizer_operations_evidence` | Fork/testnet provider, funding, epoch, callback, reserve, migration, stale/failed/retry, pause, and emergency evidence |
| `verified_deployed_addresses` | Reviewed non-local address book plus independent address verification source |
| `explorer_verification_status` | Explorer submission output or verified-source links for non-local contracts |
| `production_signatures` | Detached checksum signatures, public key fingerprint, verification command, and reviewer result |
| `signed_git_tag` | Signed release tag, tag verification output, commit hash, and reviewer result |
| `production_address_books` | Production address books generated from live deployment manifests |
| `production_broadcast_retention` | Sanitized live Foundry broadcasts and any derived broadcast manifest inputs |
| `live_deployment_manifest` | Live deployment manifests generated from production inputs and broadcasts |
| `live_ceremony_evidence` | Live admin, signer, metadata, auction, emergency, ownership, role, and verification ceremony evidence |
| `live_randomizer_operations_evidence` | Live provider configuration, funding, billing, epoch, callback health, reserve, migration, stale/failed/retry, pause, and emergency evidence |
| `live_explorer_verification` | Live explorer verification outputs and verified contract-address links |
| `post_audit_remediation` | Finding-by-finding remediation evidence, accepted-risk records, retest status, and release notes |

Do not set a row to `complete` until the row has at least one retained evidence
file with a matching digest and an independent review note.

## Intake Workflow

1. Start from a clean release commit with CI green.
2. Run the non-local command or ceremony from an operator machine or CI runner.
3. Save raw logs outside the public repository.
4. Redact secrets, private URLs, unreleased payloads, private comments, and
   private audit-draft text.
5. Convert the retained artifact to JSON or Markdown with the required artifact
   fields.
6. Hash the retained file with SHA-256.
7. Add the retained artifact to the appropriate repository directory.
8. Update the matching `public-beta-evidence.json` requirement row with the
   retained path and digest.
9. Set the requirement status to `pending` until review is complete.
10. Ask a reviewer to confirm the command, environment, chain, digest, and
    redaction boundary.
11. Move the requirement to `complete` only after review, or to
    `accepted_risk` only with owner, dates, public reference, and notes.
12. Regenerate release manifest and checksum outputs.

The required validation sequence is:

```sh
python scripts/check_public_beta_evidence.py
python scripts/check_release_readiness.py
python scripts/generate_release_manifest.py
python scripts/generate_release_checksums.py
python scripts/generate_release_manifest.py --check
python scripts/generate_release_checksums.py --check
```

Run `make check` or the documented platform equivalent before a release PR
claims readiness.

## Evidence Family Checklists

### Deployment Rehearsal Evidence

Retain:

- command transcript or CI job URL;
- fork/testnet/live chain ID and block reference;
- sanitized broadcast output;
- generated deployment manifest;
- generated address book;
- contract verification status;
- release manifest and checksum bundle digests used during the ceremony;
- operator and reviewer notes.

Map fork evidence to `fork_deployment_rehearsal`, testnet evidence to
`testnet_deployment_rehearsal`, and live evidence to
`production_broadcast_retention`, `live_deployment_manifest`, and
`production_address_books`.

### Metadata Browser Evidence

Retain:

- deployed contract addresses and chain ID;
- token/collection IDs exercised;
- exact browser-sandbox command or CI job;
- generated token URI or a digest of the generated token URI when the payload is
  too large;
- console/error summary;
- screenshot or text transcript when useful;
- reviewer note confirming the artifact was produced from deployed contracts.

Map fork/testnet evidence to `fork_testnet_metadata_browser_evidence` and live
evidence to `live_ceremony_evidence` unless a later schema creates a dedicated
live metadata requirement.

### Ceremony Evidence

Retain:

- deployer identity class, not private keys;
- Safe or multisig address;
- ownership transfers;
- role grants and revocations;
- signer setup and epoch;
- dry-run mint and auction results;
- emergency redeployment or rollback outcome when applicable;
- verification and address-book references.

Map fork/testnet evidence to `fork_testnet_ceremony_evidence` and live evidence
to `live_ceremony_evidence`.

### Randomizer Operations Evidence

Retain:

- provider addresses and adapter addresses;
- provider epoch;
- subscription or funding status without private billing credentials;
- request-cost policy and reserve summary;
- callback validation result;
- pending-request migration check;
- stale request, failed request, retry, pause, and emergency-control evidence;
- observed request health for the selected environment.

Map fork/testnet evidence to `fork_testnet_randomizer_operations_evidence` and
live evidence to `live_randomizer_operations_evidence`.

### Gas And Invariant Evidence

Retain:

- exact command or CI job;
- chain, fork block, and Foundry profile;
- focused gas report or invariant summary;
- reason for any accepted delta;
- reviewer note tying the evidence to the release commit.

Gas and invariant evidence normally supports deployment, ceremony, and
post-audit rows rather than standing alone. Link it from the relevant
requirement row.

### Audit And Remediation Evidence

Retain:

- final audit report or public report URL;
- scope and commit hash;
- finding IDs and severities;
- issue or PR links for remediations;
- accepted-risk records with owner, dates, public reference, and notes;
- retest result or explicit reason retest is unavailable.

Map the final report to `external_audit_report` and the remediation evidence to
`post_audit_remediation`.

### Release Signing Evidence

Retain:

- checksum bundle path and digest;
- detached signature path and verification command;
- public key fingerprint and custody summary;
- signed Git tag and `git verify-tag` output;
- release commit hash;
- reviewer note confirming the signature verification result.

Map detached signatures to `production_signatures` and signed tag evidence to
`signed_git_tag`.

## No-Secret Checklist

Before committing any non-local evidence, confirm that the retained files do
not contain:

- private keys, mnemonics, seed phrases, or wallet export material;
- RPC URLs with credentials;
- API keys, bearer tokens, passwords, cookies, or session IDs;
- unreleased drop payloads, allowlists, private art files, or private metadata;
- private audit draft text, private auditor comments, or private procurement
  data;
- internal incident channels or personal contact details that are not intended
  for publication.

Forbidden examples include:

```text
private_key=...
mnemonic: ...
https://user:password@example-rpc
Authorization: Bearer ...
api_key: ...
unreleased_drop_payload: ...
```

Use public transaction hashes, public explorer links, redacted command
transcripts, file digests, and issue/PR references instead.

## Updating Public-Beta Evidence

Use `missing`, `pending`, `blocked`, `accepted_risk`, `not_applicable`, or
`complete` according to [`docs/public-beta-evidence.md`](public-beta-evidence.md).

For each retained artifact:

1. Add the file under the appropriate retained evidence path.
2. Compute its digest in the `sha256:<64 lowercase hex>` format.
3. Add `{ "path": "...", "sha256": "..." }` to the matching requirement's
   `evidence` array.
4. Keep `risk_acceptance` as `null` unless the status is `accepted_risk`.
5. Keep `status.public_beta` or `status.production_release` as `blocked` while
   any blocking requirement remains.
6. Run the public-beta evidence checker before regenerating release outputs.

If a requirement cannot be completed before a release, record `accepted_risk`
with real ISO dates, a public reference, and explicit owner. Accepted risk is a
release decision, not an evidence shortcut.

## Review Standard

A reviewer should be able to answer yes to every question below:

- Does the artifact identify the environment, chain, block/reference, command,
  retained path, digest, owner, reviewer, and requirement ID?
- Does the digest match the committed retained file?
- Does the evidence map to the correct public-beta requirement row?
- Does the redaction statement match the no-secret checklist?
- Does the evidence refer to the same release commit and artifact set as the
  release manifest?
- Is any missing evidence represented as `missing`, `pending`, `blocked`, or
  `accepted_risk` rather than silently omitted?

Only after that review should a release PR claim a public-beta or production
requirement is complete.
