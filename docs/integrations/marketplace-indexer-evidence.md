# Marketplace And Indexer Evidence

This document is the `ONE-005` retained marketplace/indexer evidence guide for
6529Stream. It tells frontend, marketplace, analytics, collector-tool, and
indexer teams what must be proven before the project can make collector-facing
claims about marketplace display, indexer replay, royalty display, metadata
refresh, or cache invalidation.

The repository remains a pre-audit local baseline. It is not production-ready
and this document is not a security claim. Local evidence does not replace
fork/testnet/live evidence required for public beta or production release.

Use this with the integration entrypoint in
[`docs/integrations/README.md`](README.md), the event/indexer model in
[`docs/integrations/events-and-indexing.md`](events-and-indexing.md), the
metadata rendering guide in
[`docs/integrations/metadata-rendering.md`](metadata-rendering.md), the royalty
policy in [`docs/royalty-policy.md`](../royalty-policy.md), release readiness in
[`docs/release-readiness.md`](../release-readiness.md), public-beta evidence in
[`docs/public-beta-evidence.md`](../public-beta-evidence.md), and non-local
evidence intake in
[`docs/non-local-release-evidence.md`](../non-local-release-evidence.md).

## Maturity And Scope

`ONE-005` covers retained marketplace/indexer evidence only. It does not add a
maintained marketplace adapter, marketplace integration package, indexer
service, SDK, frontend, API dependency, or production deployment.

The checked artifacts are:

| Need | Source of truth |
| --- | --- |
| Public-beta retained artifact template | [`release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-retained-artifact-template.md`](../../release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-retained-artifact-template.md) |
| Production retained artifact template | [`release-artifacts/evidence/marketplace-indexer/live-marketplace-indexer-retained-artifact-template.md`](../../release-artifacts/evidence/marketplace-indexer/live-marketplace-indexer-retained-artifact-template.md) |
| Public-beta non-local envelope template | [`release-artifacts/evidence/public-beta-templates/fork-testnet-marketplace-indexer-evidence-template.json`](../../release-artifacts/evidence/public-beta-templates/fork-testnet-marketplace-indexer-evidence-template.json) |
| Production non-local envelope template | [`release-artifacts/evidence/production-release-templates/live-marketplace-indexer-evidence-template.json`](../../release-artifacts/evidence/production-release-templates/live-marketplace-indexer-evidence-template.json) |
| Evidence checker | [`scripts/check_marketplace_indexer_evidence.py`](../../scripts/check_marketplace_indexer_evidence.py) |
| Checker tests | [`scripts/test_marketplace_indexer_evidence.py`](../../scripts/test_marketplace_indexer_evidence.py) |
| Shared evidence status | [`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json) |

Template only. This file is not completion evidence.

## Evidence Rows

`ONE-005` adds two release evidence rows:

| Requirement ID | Phase | Tracker | Completion boundary |
| --- | --- | --- | --- |
| `fork_testnet_marketplace_indexer_evidence` | Public beta | [`#423`](https://github.com/6529-Collections/6529Stream/issues/423) | Reviewed fork or testnet marketplace/indexer evidence retained and linked from the shared evidence status |
| `live_marketplace_indexer_evidence` | Production release | [`#424`](https://github.com/6529-Collections/6529Stream/issues/424) | Reviewed live marketplace/indexer evidence retained and linked from the shared evidence status |

Both rows remain `missing` until real reviewed evidence is retained. Template
JSON, template Markdown, local metadata fixtures, local browser sandbox checks,
and local event/indexer docs are preparation material, not release readiness
proof.

When either row moves to `complete`, keep the reusable template files in place
and add a reviewed non-local evidence envelope from
[`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json).
`scripts/check_marketplace_indexer_evidence.py` follows complete marketplace /
indexer rows from the shared evidence manifest to the reviewed envelope, checks
that the envelope is not template-only, verifies the retained Markdown hash, and
then validates the retained Markdown with the same coverage and no-secret rules
as the standalone checker. This lets #423 and #424 be completed by supplemental
reviewed artifacts without weakening the template baseline.

## Required Coverage

Reviewed retained marketplace/indexer evidence must identify:

- network, chain ID, block or transaction reference, and deployment reference;
- release manifest and checksum digest;
- deployment manifest and address book used;
- contract addresses for `StreamCore`, `StreamContractMetadata`, and other
  relevant release-tracked contracts;
- token IDs and collection IDs exercised;
- command, platform, indexer, marketplace, or collector-tool source system;
- OpenSea, Reservoir, Blur, Manifold, or equivalent collector/indexer tooling
  results;
- contract metadata discovery through `contractURI()`,
  `contractURIHash()`, and `ContractURIUpdated`;
- token metadata refresh through ERC-4906 `MetadataUpdate` and
  `BatchMetadataUpdate` signals;
- animation rendering result;
- royalty display result and the explicit
  `royalty disclosure, not payment enforcement` boundary;
- transfer/listing/sale path or public-beta-safe simulated sale path;
- event replay result and indexer reconciliation posture;
- cache invalidation result;
- stale, failed, frozen, and burned metadata-state handling;
- screenshot, public URL, query result, transcript, or redacted retained
  reference; and
- operator, reviewer, review decision, and no-secret redaction status.

No production-readiness claim depends on marketplaces honoring royalties.
ERC-2981 exposes royalty information; it does not enforce secondary-sale
payment.

## Evidence Workflow

For public-beta evidence:

1. Start from
   [`release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-retained-artifact-template.md`](../../release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-retained-artifact-template.md).
2. Replace every `TBD` field with reviewed fork or testnet evidence.
3. Remove the template-only notice after the artifact is no longer a template.
4. Generate a non-local metadata envelope from
   [`release-artifacts/evidence/public-beta-templates/fork-testnet-marketplace-indexer-evidence-template.json`](../../release-artifacts/evidence/public-beta-templates/fork-testnet-marketplace-indexer-evidence-template.json).
5. Link the generated evidence from
   [`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json).
6. Run `python scripts/check_marketplace_indexer_evidence.py` so the shared
   manifest row, reviewed envelope, retained Markdown hash, and retained
   Markdown coverage are checked together.
7. Keep issue #423 open until the row is `complete` or explicitly
   risk-accepted.

For production evidence:

1. Start from
   [`release-artifacts/evidence/marketplace-indexer/live-marketplace-indexer-retained-artifact-template.md`](../../release-artifacts/evidence/marketplace-indexer/live-marketplace-indexer-retained-artifact-template.md).
2. Replace every `TBD` field with reviewed live evidence.
3. Remove the template-only notice after the artifact is no longer a template.
4. Generate a non-local metadata envelope from
   [`release-artifacts/evidence/production-release-templates/live-marketplace-indexer-evidence-template.json`](../../release-artifacts/evidence/production-release-templates/live-marketplace-indexer-evidence-template.json).
5. Link the generated evidence from
   [`release-artifacts/latest/public-beta-evidence.json`](../../release-artifacts/latest/public-beta-evidence.json).
6. Run `python scripts/check_marketplace_indexer_evidence.py` so the shared
   manifest row, reviewed envelope, retained Markdown hash, and retained
   Markdown coverage are checked together.
7. Keep issue #424 open until the row is `complete` or explicitly
   risk-accepted.

## Redaction

Retained marketplace/indexer evidence must not include private keys,
mnemonics, seed phrases, RPC URLs with credentials, API keys, bearer tokens,
cookies, marketplace account credentials, indexer credentials, private customer
data, unreleased drop payloads, private art files, private metadata, or private
operator notes.

Use public transaction hashes, public explorer links, public marketplace URLs,
redacted transcripts, file digests, and reviewer notes instead.

## Validation Commands

Run these when editing this guide or the retained marketplace/indexer evidence
templates:

```sh
python scripts/test_marketplace_indexer_evidence.py
python scripts/check_marketplace_indexer_evidence.py
python scripts/test_non_local_release_evidence.py
python scripts/check_non_local_release_evidence.py
python scripts/test_public_beta_evidence.py
python scripts/check_public_beta_evidence.py
python scripts/test_public_beta_blocker_report.py
python scripts/generate_public_beta_blocker_report.py --check
python scripts/test_production_release_blocker_report.py
python scripts/generate_production_release_blocker_report.py --check
python scripts/test_release_evidence_packet_index.py
python scripts/generate_release_evidence_packet_index.py --check
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
```

## Maintenance

Update this guide when any of these change:

- marketplace/indexer evidence requirement IDs;
- retained artifact template fields;
- OpenSea, Reservoir, Blur, Manifold, or equivalent collector/indexer tooling
  coverage expectations;
- contract metadata adapter behavior;
- ERC-4906 metadata refresh behavior;
- royalty display or royalty policy wording;
- event replay, cache invalidation, or metadata-state requirements; or
- public-beta or production release readiness claims.
