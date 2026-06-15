# 1/1 Provenance Manifests

This document defines the current 6529Stream 1/1 provenance manifest model.
The repository remains a pre-audit local baseline, not production-ready, and
not a security claim. Local provenance templates do not replace fork, testnet,
marketplace, indexer, collector, or production release evidence.

Use this with the metadata baseline in [`docs/metadata.md`](metadata.md), the
metadata rendering guide in
[`docs/integrations/metadata-rendering.md`](integrations/metadata-rendering.md),
the event/indexer model in
[`docs/integrations/events-and-indexing.md`](integrations/events-and-indexing.md),
the integration entrypoint in [`docs/integrations/README.md`](integrations/README.md),
release readiness in [`docs/release-readiness.md`](release-readiness.md), and
non-local evidence intake in
[`docs/non-local-release-evidence.md`](non-local-release-evidence.md).

## Source Of Truth

The machine-readable provenance model lives in:

- [`release-artifacts/schema/one-of-one-provenance-manifest.schema.json`](../release-artifacts/schema/one-of-one-provenance-manifest.schema.json)
- [`release-artifacts/provenance/one-of-one-provenance-template.provenance.json`](../release-artifacts/provenance/one-of-one-provenance-template.provenance.json)
- [`release-artifacts/provenance/one-of-one-provenance-retained-artifact-template.md`](../release-artifacts/provenance/one-of-one-provenance-retained-artifact-template.md)
- [`release-artifacts/latest/one-of-one-provenance-manifest.json`](../release-artifacts/latest/one-of-one-provenance-manifest.json)
- [`scripts/check_one_of_one_provenance_manifest.py`](../scripts/check_one_of_one_provenance_manifest.py)
- [`scripts/generate_one_of_one_provenance_manifest.py`](../scripts/generate_one_of_one_provenance_manifest.py)
- [`scripts/test_one_of_one_provenance_manifest.py`](../scripts/test_one_of_one_provenance_manifest.py)

The template is intentionally not drop-completion evidence. The generated
`latest/one-of-one-provenance-manifest.json` file catalogs checked provenance
records and their descriptor hashes so release reviewers and frontend/indexer
teams can discover the model from the release artifact bundle.

## Model Boundary

Current provenance manifests are release artifacts, not new `StreamCore`
storage. This keeps the model away from the EIP-170 byte limit and avoids
changing token metadata semantics before there is reviewed integration evidence.

The current boundary is:

- Provenance is separate from `tokenURI` JSON unless a future metadata schema
  explicitly embeds it.
- Provenance is separate from `contractURI()` unless a future contract-level
  metadata document links to the generated provenance artifact.
- Provenance is separate from `collectionFreezeManifestHash(collectionId)`.
  Current freeze commits the on-chain rendering inputs, final supply state,
  burn count, live token aggregate, randomizer/core/chain context, and
  dependency pins, not the append-only provenance story.
- Provenance is not royalty enforcement, not ownership proof beyond chain
  state, and not marketplace or indexer readiness proof. Use
  [`docs/royalty-policy.md`](royalty-policy.md) for the current ERC-2981
  royalty disclosure and non-enforcement boundary.

## Required Fields

Each 1/1 provenance record must identify:

- repository source, commit, dirty state, and CI run;
- environment, protocol version, and deployment version;
- chain ID, `StreamCore` address, contract metadata adapter address,
  `collectionId`, `tokenId`, token standard, metadata schema version,
  `contractURIHash()`, and `collectionFreezeManifestHash(collectionId)`;
- artwork title, artist, artist statement, medium, creation date, image URI,
  and animation URI;
- authenticity status, authority, authority reference, artist statement hash,
  artwork content hash, and certificate hash;
- append-only provenance entries with evidence references;
- mutability policy for token metadata, contract metadata, freeze boundary,
  provenance updates, corrections, and authority rotation;
- release manifest, checksum, deployment manifest, and address book bindings;
- frontend, indexer, marketplace, and ownership-boundary guidance;
- reviewer state; and
- retained artifact, redaction, and operator notes.

Reviewed non-local evidence must replace local placeholders, use reviewed
authenticity state, retain non-placeholder hash evidence, and include reviewer
approval. Production evidence must be reviewed and approved before it can
support a production release claim.

## Frontend And Indexer Use

Frontends may display provenance fields as artist/story/authenticity context
when the selected release artifact bundle contains a checked provenance record.
They must not confuse the provenance story with token finality, ownership,
listing status, royalty payment, or marketplace acceptance.

Indexers should treat provenance records as release-artifact entities keyed by
`chainId:coreAddress:collectionId:tokenId:provenanceId`. If a future contract
or adapter emits provenance events, indexers should add event/read-after-event
rules at that time. In the current artifact-only model, provenance changes are
discovered by release manifest and checksum changes, not by protocol logs.

Mobile and Electron clients should render provenance links as untrusted
external content. Do not expose wallet providers, private keys, local files,
operator credentials, signer credentials, or privileged IPC to provenance
documents or linked media.

## Review And Release Gates

Before a manifest can support a reviewed release claim:

1. Run `python scripts/test_one_of_one_provenance_manifest.py`.
2. Run `python scripts/check_one_of_one_provenance_manifest.py`.
3. Run `python scripts/generate_one_of_one_provenance_manifest.py --check`.
4. Regenerate and check `release-artifacts/latest/release-manifest.json`.
5. Regenerate and check the bytecode release proof and checksum bundle.
6. Retain non-local indexer/marketplace evidence separately if the release claim
   depends on third-party display or discovery.

The model is intentionally append-only. Corrections should add superseding
entries instead of silently rewriting history.

## Maintenance

Update this guide when the provenance schema, template, checker, generated
artifact, metadata schema, contract-level metadata adapter, freeze manifest,
release readiness posture, or integration evidence requirements change.
