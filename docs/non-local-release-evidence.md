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
- fork/testnet/live marketplace/indexer display, replay, and cache evidence;
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
| Marketplace/indexer evidence | `release-artifacts/evidence/marketplace-indexer/` |

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

## Machine-Readable Metadata

Use
[`release-artifacts/evidence/non-local-release-evidence-template.json`](../release-artifacts/evidence/non-local-release-evidence-template.json)
as the starting point for reviewed non-local evidence metadata. The schema is
[`release-artifacts/schema/non-local-release-evidence.schema.json`](../release-artifacts/schema/non-local-release-evidence.schema.json),
and the retained template artifact is
[`release-artifacts/evidence/non-local-template-retained-artifact.txt`](../release-artifacts/evidence/non-local-template-retained-artifact.txt).

The committed template is not completion evidence and does not unblock public
beta or production release. Real non-local evidence should copy the template
shape, replace every template value with reviewed no-secret metadata, point
`retained_path` at the retained public artifact, and update `sha256` to match
that file.

For public-beta blockers, start from the matching checked template under
[`release-artifacts/evidence/public-beta-templates/`](../release-artifacts/evidence/public-beta-templates/).
The checker requires one template for each public-beta requirement ID. These
files are still `record_type: "template"` and `review_status: "template"`;
they are operator starting points, not reviewed evidence.
For production-release blockers, start from the matching checked template under
[`release-artifacts/evidence/production-release-templates/`](../release-artifacts/evidence/production-release-templates/).
The checker requires one template for each production-release requirement ID
and rejects public-beta-only IDs in that directory.

Validate metadata with:

```sh
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
```

The checker validates the public-beta requirement ID, environment, chain ID
policy, retained artifact path, SHA-256 digest, review status, source metadata,
public-beta and production-release template-set coverage, and no-secret
boundary before release manifest and checksum generation.

### Evidence Metadata Generator

Use `scripts/generate_non_local_release_evidence.py` when a retained artifact
already exists and the operator needs a metadata envelope that matches the
canonical checker. The generator copies the requirement ID and redaction policy
from a committed public-beta or production-release template, computes the
retained artifact digest, sets `record_type: "evidence"`, and validates the
result against the same checker rules before writing. Run
`scripts/check_non_local_release_evidence.py` separately when you want an
explicit verification pass.

Example fork rehearsal draft:

```sh
python scripts/generate_non_local_release_evidence.py \
  --template release-artifacts/evidence/public-beta-templates/fork-deployment-rehearsal-template.json \
  --retained-artifact release-artifacts/evidence/fork-deployment-rehearsal/fork-rehearsal.md \
  --output release-artifacts/evidence/fork-deployment-rehearsal/fork-rehearsal-evidence.json \
  --environment fork \
  --chain-id 1 \
  --block-or-reference "fork block 19000000" \
  --command-or-source-system "forge script script/RehearseDeployment.s.sol:RehearseDeployment --rpc-url <redacted>" \
  --owner release-operator \
  --reviewer TBD \
  --source-git-commit <release commit sha> \
  --source-ci-run <ci run or TBD>
```

Use `--review-status reviewed --reviewer <reviewer>` only after independent
review is complete. Use `--check` in follow-up PRs to prove the retained
artifact hash and metadata fields have not drifted:

```sh
python scripts/generate_non_local_release_evidence.py ... --check
```

This helper does not create completion evidence by itself. A public-beta or
production-release row remains blocked until the generated evidence is reviewed,
linked from `release-artifacts/latest/public-beta-evidence.json`, and all
release evidence gates pass.

### Fork Deployment Retained Artifact

Tracker issue #216 requires a reviewed retained fork deployment rehearsal
artifact before `fork_deployment_rehearsal` can move to `complete`. Use
[`release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md`](../release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-retained-artifact-template.md)
as the canonical retained transcript path. It records the fork block reference,
sanitized deployment transcript, sanitized broadcast, generated manifest,
address book, verification status, gas or invariant summary, redaction
confirmation, and reviewer decision.

The committed file currently contains reviewed mainnet-fork rehearsal evidence
captured at block `25316366` with fork hash
`0xb7c7a456e0f1246fa4ee52de6fca99cc16628ce1eafd85b65b0f3d22f3933ee7`.
It is linked to
[`release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-evidence.json`](../release-artifacts/evidence/fork-deployment-rehearsal/fork-deployment-rehearsal-evidence.json),
which records the retained artifact digest for the public-beta evidence row.
The row is `complete`; public beta remains blocked by the remaining missing
evidence rows, including external audit, testnet rehearsal, verified deployed
addresses, explorer verification, and fork/testnet ceremony, metadata browser,
and randomizer operations evidence.

The retained artifact is checked separately from the JSON metadata envelope:

```sh
python scripts/test_fork_deployment_rehearsal_evidence.py
python scripts/check_fork_deployment_rehearsal_evidence.py
```

The retained artifact can remain in `pending_review` only while a PR review is
in progress. Issue #216 can close only after the review decision is accepted,
the generated non-local evidence envelope remains in sync, and
`release-artifacts/latest/public-beta-evidence.json` is updated consistently
with the accepted retained artifact.

### Testnet Deployment Retained Artifact

Tracker issue #217 requires reviewed retained testnet deployment rehearsal
evidence before `testnet_deployment_rehearsal` can move to `complete`. Use
[`release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md`](../release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md)
as the canonical retained transcript path. It records the Sepolia chain ID,
testnet block or transaction references, sanitized deployment transcript,
sanitized broadcast, generated manifest, address book, explorer verification
status, gas or invariant summary, redaction confirmation, and reviewer
decision.

The committed file is template-only. It is not evidence that a testnet
deployment rehearsal occurred, and issue #217 remains open until reviewed
retained evidence is linked from the shared public-beta evidence manifest.
Use
[`deployments/config/sepolia-6529stream-v0.1.0-001.template.json`](../deployments/config/sepolia-6529stream-v0.1.0-001.template.json)
and
[`docs/deployment.md#sepolia-deployment-rehearsal-runbook`](deployment.md#sepolia-deployment-rehearsal-runbook)
for the operator command sequence, required Sepolia environment variable names,
broadcast sanitization, manifest/address-book generation, and no-secret
redaction requirements before replacing this retained artifact template.

The retained artifact is checked separately from the JSON metadata envelope:

```sh
python scripts/test_testnet_deployment_rehearsal_evidence.py
python scripts/check_testnet_deployment_rehearsal_evidence.py
```

For pending or reviewed testnet deployment evidence, retained transcript,
broadcast, manifest, address-book, and gas/invariant references must be
repo-relative files. Each reference may include one optional
`sha256:<64 lowercase hex>` digest, which the checker verifies against the
committed file bytes. Absolute paths, parent-directory escapes, Windows
backslashes, whitespace-ambiguous paths, stale hashes, duplicate hashes,
bare 64-hex strings, private RPC URLs, private keys, API keys, bearer tokens,
credentialed URLs, and provider-token URLs fail closed.

## Public-Beta Requirement Mapping

When evidence is retained, update the matching requirement row in
[`release-artifacts/latest/public-beta-evidence.json`](../release-artifacts/latest/public-beta-evidence.json).

| Requirement ID | Evidence to retain before `complete` |
| --- | --- |
| `external_audit_report` | Final external audit report, scope, commit, issue-linked findings, and remediation state |
| `fork_deployment_rehearsal` | Fork transcript, sanitized broadcast, manifest, address book, verification status, gas/invariant summary |
| `testnet_deployment_rehearsal` | Testnet transcript, transaction references, sanitized broadcast, manifest, address book, explorer verification status |
| `fork_testnet_metadata_browser_evidence` | Browser execution output for token metadata generated from deployed fork/testnet contracts |
| `fork_testnet_marketplace_indexer_evidence` | Fork/testnet marketplace and indexer proof for contract metadata, token metadata refresh, animation rendering, royalty display, transfer/listing/sale or simulated sale path, event replay, cache invalidation, platform coverage, redaction, and reviewer approval |
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
| `live_marketplace_indexer_evidence` | Live marketplace and indexer proof for contract metadata, token metadata refresh, animation rendering, royalty display, transfer/listing/sale path, event replay, cache invalidation, platform coverage, redaction, and reviewer approval |
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
6. Add the retained artifact to the appropriate repository directory.
7. Generate a metadata envelope with
   `scripts/generate_non_local_release_evidence.py`, or manually hash the
   retained file and copy the same fields into a checked metadata document.
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
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
python scripts/test_fork_deployment_rehearsal_evidence.py
python scripts/check_fork_deployment_rehearsal_evidence.py
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
evidence to `live_metadata_browser_evidence`.

The fork/testnet metadata-browser row has a dedicated retained-artifact template
at
`release-artifacts/evidence/fork-metadata-browser/fork-metadata-browser-retained-artifact-template.md`.
Before generating the non-local metadata envelope, run:

```sh
python scripts/test_fork_metadata_browser_evidence.py
python scripts/check_fork_metadata_browser_evidence.py
```

The live metadata-browser row has a dedicated retained-artifact template at
`release-artifacts/evidence/live-metadata-browser/live-metadata-browser-retained-artifact-template.md`.
Before generating the non-local metadata envelope, run:

```sh
python scripts/test_live_metadata_browser_evidence.py
python scripts/check_live_metadata_browser_evidence.py
```

The checker validates retained no-secret browser proof only. It does not fetch
live metadata, call a private RPC endpoint, or execute production browser work
from CI. Pending-review or reviewed retained artifact fields must reference
repo-relative files and may include one optional `sha256:<64 lowercase hex>`
digest; absolute paths, parent escapes, Windows backslashes, whitespace in
paths, missing files, stale hashes, duplicate hashes, credentialed URLs,
provider/API-token-shaped URLs, bearer credentials, and bare 64-hex values fail
closed.

### Ceremony Evidence

Retain:

- fork/testnet chain ID and block or testnet deployment reference;
- deployer, admin Safe or multisig, pause guardian, emergency recipient, drop
  signer, and signer-manager addresses;
- ownership-transfer, role-grant/revoke, signer-setup, metadata/freeze,
  auction, and emergency-control ceremony references;
- dry-run mint and auction evidence;
- monitoring handoff and post-state views;
- deployment manifest, address book, Safe or multisig export, transaction
  bundle, release manifest/checksum digests, and reviewer notes.

Map fork/testnet evidence to `fork_testnet_ceremony_evidence` and live evidence
to `live_ceremony_evidence`.

The fork/testnet ceremony row has a dedicated retained-artifact template at
`release-artifacts/evidence/fork-ceremony/fork-ceremony-retained-artifact-template.md`.
Before generating the non-local ceremony envelope, run:

```sh
python scripts/test_fork_ceremony_evidence.py
python scripts/check_fork_ceremony_evidence.py
```

### Live Ceremony Evidence

Retain:

- release commit, deployment version, chain ID, and live block or transcript
  reference;
- deployer, Safe or multisig, pause guardian, emergency recipient, drop signer,
  and signer-manager identities as public addresses or role classes, never
  private keys;
- ownership transfer, role grant/revoke, signer setup, metadata/freeze, auction,
  and emergency-control transaction references;
- dry-run mint and auction outcomes;
- monitoring handoff owner, reviewer, and decision;
- generated live deployment manifest, live address book, Safe/multisig export,
  explorer transaction bundle, post-state views, release manifest digest, and
  checksum digest references; and
- explicit redaction confirmations for private keys, private RPC URLs,
  signer-service secrets, and unreleased drop payloads.

Map production ceremony proof to `live_ceremony_evidence`.

The live ceremony row has a dedicated retained-artifact template at
`release-artifacts/evidence/live-ceremony/live-ceremony-retained-artifact-template.md`.
Before generating the non-local metadata envelope, run:

```sh
python scripts/test_live_ceremony_evidence.py
python scripts/check_live_ceremony_evidence.py
```

The checker validates retained no-secret ceremony proof only. It does not
execute live transactions, contact a Safe, call private RPC endpoints, or
approve a production release by itself. Future pending-review or reviewed
retained ceremony references must be repo-relative files and may include one
optional `sha256:<64 lowercase hex>` digest. The checker rejects missing files,
absolute paths, path escapes, Windows backslashes, ambiguous whitespace,
duplicate or malformed digests, stale declared hashes, credentialed/provider
URLs, bearer tokens, bare 64-hex values, and secret-shaped content in referenced
retained files.

### Marketplace And Indexer Evidence

Retain:

- network, chain ID, block, deployment manifest, address book, and contract
  addresses;
- token IDs and collection IDs exercised;
- OpenSea, Reservoir, Blur, Manifold, or equivalent collector/indexer tooling
  source references;
- contract metadata discovery through `contractURI()`, `contractURIHash()`,
  and `ContractURIUpdated`;
- token metadata refresh through ERC-4906 `MetadataUpdate` and
  `BatchMetadataUpdate`;
- animation rendering result;
- royalty display result with the explicit
  `royalty disclosure, not payment enforcement` boundary;
- transfer/listing/sale path or public-beta-safe simulated sale path;
- event replay, cache invalidation, and stale/failed/frozen/burned state
  handling;
- screenshot, public reference, query result, or redacted transcript; and
- reviewer confirmation without secrets or unreleased payloads.

Map fork/testnet evidence to `fork_testnet_marketplace_indexer_evidence` and
live evidence to `live_marketplace_indexer_evidence`.

The marketplace/indexer rows have dedicated retained-artifact templates at
`release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-retained-artifact-template.md`
and
`release-artifacts/evidence/marketplace-indexer/live-marketplace-indexer-retained-artifact-template.md`.
Before generating the non-local metadata envelope, run:

```sh
python scripts/test_marketplace_indexer_evidence.py
python scripts/check_marketplace_indexer_evidence.py
```

The committed templates are not completion evidence. Issues #423 and #424
remain open and the shared release evidence rows remain `missing` until
reviewed retained marketplace/indexer evidence is linked from the shared
public-beta evidence manifest.

Do not replace the reusable template files when retaining reviewed evidence.
Instead, add a reviewed evidence envelope and link that envelope from the
complete row in `release-artifacts/latest/public-beta-evidence.json`.
`python scripts/check_marketplace_indexer_evidence.py` validates the template
baseline and, for any completed marketplace/indexer row, follows the manifest
reference to the reviewed envelope, verifies the retained Markdown hash, and
then checks the retained Markdown coverage fields. A template envelope,
wrong-environment envelope, stale retained-artifact hash, or retained Markdown
artifact that still fails the marketplace/indexer coverage rules cannot
complete #423 or #424.

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

The fork/testnet randomizer operations row has a dedicated retained-artifact
template at
`release-artifacts/evidence/fork-randomizer-operations/fork-randomizer-operations-retained-artifact-template.md`.
Before generating the non-local metadata envelope, run:

```sh
python scripts/test_fork_randomizer_operations_evidence.py
python scripts/check_fork_randomizer_operations_evidence.py
python scripts/check_randomizer_operations.py
```

The fork/testnet checker validates fork or testnet environments, positive
chain IDs, provider configuration, funding, reserve, request-health,
lifecycle-control, monitoring, retained file references, optional declared
`sha256:` hashes, reviewer state, and no-secret redaction before any
pending-review or reviewed artifact can pass. The committed file is
template-only and keeps public beta blocked until future reviewed evidence is
accepted and linked from the shared evidence manifest.

The live randomizer operations row has a dedicated retained-artifact template at
`release-artifacts/evidence/live-randomizer-operations/live-randomizer-operations-retained-artifact-template.md`.
Before generating the non-local metadata envelope, run:

```sh
python scripts/test_live_randomizer_operations_evidence.py
python scripts/check_live_randomizer_operations_evidence.py
python scripts/check_randomizer_operations.py
```

The checker validates retained no-secret operations proof only. It does not
fetch provider dashboards, call private RPC endpoints, query billing systems,
or execute randomizer migrations from CI.

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

The external audit report row has a dedicated retained-artifact template at
`release-artifacts/evidence/external-audit-report/external-audit-report-retained-artifact-template.md`.
Before generating the non-local metadata envelope for `external_audit_report`,
run:

```sh
python scripts/test_external_audit_report_evidence.py
python scripts/check_external_audit_report_evidence.py
```

The committed template is not completion evidence. Issue #215 remains open and
the public-beta row remains `missing` until a final reviewed audit report,
audited commit/scope, finding remediation map, retest or accepted-risk status,
and reviewer confirmation are retained and linked from the shared
public-beta evidence manifest.

The post-audit remediation row has a dedicated retained-artifact template at
`release-artifacts/evidence/post-audit-remediation/post-audit-remediation-retained-artifact-template.md`.
Before generating the non-local metadata envelope for
`post_audit_remediation`, run:

```sh
python scripts/test_post_audit_remediation_evidence.py
python scripts/check_post_audit_remediation_evidence.py
```

The committed template is not completion evidence. Issue #231 remains open and
the production-release row remains `missing` until finding-by-finding
remediation status, fix PRs or commits, regression tests, retest evidence,
accepted-risk records, release-note mapping, and reviewer confirmation are
retained and linked from the shared production-release evidence manifest.

The testnet deployment rehearsal row has a dedicated retained-artifact template
at
`release-artifacts/evidence/testnet-deployment-rehearsal/testnet-deployment-rehearsal-retained-artifact-template.md`.
Before generating the non-local metadata envelope for
`testnet_deployment_rehearsal`, run:

```sh
python scripts/test_testnet_deployment_rehearsal_evidence.py
python scripts/check_testnet_deployment_rehearsal_evidence.py
```

The committed template is not completion evidence. Issue #217 remains open and
the public-beta row remains `missing` until reviewed testnet transcript,
transaction references, sanitized broadcast, generated manifest/address book,
explorer status, and reviewer confirmation are retained and linked from the
shared public-beta evidence manifest.

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
