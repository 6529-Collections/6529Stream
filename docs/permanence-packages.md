# Collector-Verifiable Permanence Packages

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins.

This document defines the current 6529Stream collector-verifiable permanence
package model for 1/1 drops. The repository remains a pre-audit local baseline,
not production-ready, and not a security claim. Local permanence templates do
not replace fork, testnet, live, marketplace, indexer, browser, collector, or
production release evidence.

Use this with the metadata baseline in [`docs/metadata.md`](metadata.md), the
dependency operations guide in
[`docs/dependency-operations.md`](dependency-operations.md), the metadata
rendering guide in
[`docs/integrations/metadata-rendering.md`](integrations/metadata-rendering.md),
the 1/1 provenance model in
[`docs/provenance-manifests.md`](provenance-manifests.md), release readiness in
[`docs/release-readiness.md`](release-readiness.md), and non-local evidence
intake in [`docs/non-local-release-evidence.md`](non-local-release-evidence.md).

## Source Of Truth

The machine-readable permanence package model lives in:

- [`release-artifacts/schema/one-of-one-permanence-package.schema.json`](../release-artifacts/schema/one-of-one-permanence-package.schema.json)
- [`release-artifacts/permanence/one-of-one-permanence-template.permanence.json`](../release-artifacts/permanence/one-of-one-permanence-template.permanence.json)
- [`release-artifacts/permanence/one-of-one-permanence-retained-artifact-template.md`](../release-artifacts/permanence/one-of-one-permanence-retained-artifact-template.md)
- [`release-artifacts/latest/one-of-one-permanence-manifest.json`](../release-artifacts/latest/one-of-one-permanence-manifest.json)
- [`scripts/check_one_of_one_permanence_package.py`](../scripts/check_one_of_one_permanence_package.py)
- [`scripts/generate_one_of_one_permanence_manifest.py`](../scripts/generate_one_of_one_permanence_manifest.py)
- [`scripts/test_one_of_one_permanence_package.py`](../scripts/test_one_of_one_permanence_package.py)

The template is intentionally not completion evidence. The generated
`latest/one-of-one-permanence-manifest.json` file catalogs checked permanence
package descriptors and their descriptor hashes so collectors, frontend teams,
indexers, auditors, and release reviewers can discover the current model from
the release artifact bundle.

## Model Boundary

Current permanence packages are release artifacts, not new `StreamCore`
storage. This keeps the model away from the EIP-170 byte limit and avoids
changing token metadata semantics before there is reviewed integration and
collector evidence.

The current boundary is:

- The permanence package is separate from `tokenURI()` JSON unless a future
  metadata schema explicitly embeds a package pointer.
- The permanence package is separate from `contractURI()` unless a future
  contract-level metadata document links to the generated permanence artifact.
- The permanence package is separate from
  `collectionFreezeManifestHash(collectionId)`. The freeze hash remains the
  on-chain rendering-input and final-supply boundary; the permanence package
  binds to that hash and adds retained replay instructions, output hashes,
  browser proof, and storage guarantees.
- The permanence package is separate from the 1/1 provenance manifest. Use
  [`docs/provenance-manifests.md`](provenance-manifests.md) for
  artist/story/authenticity context. Use this document for replayability,
  renderer, dependency, output-hash, browser-proof, and storage-guarantee
  evidence.
- The permanence package is not marketplace readiness proof, ownership proof
  beyond chain state, royalty enforcement, royalty payment evidence, or
  production release approval. Use [`docs/royalty-policy.md`](royalty-policy.md)
  for the ERC-2981 royalty disclosure and non-enforcement boundary.

## Required Fields

Each permanence package record must identify:

- repository source, commit, dirty state, and CI run;
- environment, protocol version, and deployment version;
- chain ID, `StreamCore` address, contract metadata adapter address,
  `collectionId`, `tokenId`, token standard, metadata schema version,
  `contractURIHash()`, and `collectionFreezeManifestHash(collectionId)`;
- renderer name, renderer version, renderer contract, renderer source hash,
  rendering mode, and runtime assumptions;
- dependency artifact manifest, dependency registry, dependency keys, versions,
  content hashes, provenance hashes, and review status;
- source archive URI, archive hash, included source files, and archive review
  status;
- exact no-secret replay commands, working directory, command purpose, network
  assumption, and expected replay outputs;
- metadata JSON hash, animation HTML hash, image hash, rendered output hash,
  browser proof hash, browser proof status, and output hash status;
- fully on-chain components, decentralized-storage components, external
  service dependencies, gateway assumptions, permanence summary, and known
  failure modes;
- release manifest, checksum bundle, dependency manifest, and 1/1 provenance
  manifest bindings;
- collector, frontend, indexer, and marketplace-boundary guidance;
- reviewer state; and
- retained artifacts, redaction policy, and operator notes.

Reviewed non-local or final-drop evidence must replace local placeholders, use
nonzero contract and freeze hashes, retain non-placeholder output and browser
proof hashes, bind to reviewed dependency/provenance/release artifacts, and
include reviewer approval. Production evidence must be reviewed and approved
before it can support a production release claim.

## Collector Verification

A collector or independent reviewer should be able to:

1. Open the generated release manifest and checksum bundle.
2. Find `release-artifacts/latest/one-of-one-permanence-manifest.json`.
3. Locate the package for the target `chainId:core:collectionId:tokenId`.
4. Verify the descriptor hash from the generated permanence manifest.
5. Verify every retained artifact hash in the descriptor.
6. Verify the dependency artifact manifest and 1/1 provenance manifest binding.
7. Read the fully on-chain versus decentralized storage guarantees.
8. Run the no-secret replay commands in the documented working directory.
9. Compare the replayed metadata, animation, rendered output, and browser proof
   hashes with the descriptor.

If any reviewed hash, browser proof, dependency binding, source archive, replay
command, or storage guarantee is missing, the package must remain
`pending_review`, `template`, or explicitly blocked. It must not be described
as final collector proof.

## Frontend And Indexer Use

Frontends may display permanence package status as replayability context when
the selected release artifact bundle contains a checked package descriptor.
They must not confuse permanence package evidence with token finality,
ownership, listing status, royalty payment, marketplace acceptance, or live
production deployment approval.

Indexers should treat permanence packages as release-artifact entities keyed by
`chainId:coreAddress:collectionId:tokenId:packageId`. In the current
artifact-only model, permanence package changes are discovered by release
manifest and checksum changes, not by protocol logs.

Mobile and Electron clients should treat replay commands, browser proof links,
and retained media as untrusted external content. Do not expose wallet
providers, private keys, local files, operator credentials, signer credentials,
or privileged IPC to replay documents, linked media, or package-specified
content.

## Review And Release Gates

Before a package can support a reviewed release claim:

1. Run `python scripts/test_one_of_one_permanence_package.py`.
2. Run `python scripts/check_one_of_one_permanence_package.py`.
3. Run `python scripts/generate_one_of_one_permanence_manifest.py --check`.
4. Regenerate and check `release-artifacts/latest/release-manifest.json`.
5. Regenerate and check the bytecode release proof and checksum bundle.
6. Retain non-local browser, marketplace, and indexer evidence separately if
   the release claim depends on third-party display, discovery, rendering, or
   refresh behavior.

## Maintenance

Update this guide when the permanence schema, template, checker, generated
artifact, metadata schema, dependency artifact manifest, provenance manifest,
release readiness posture, or integration evidence requirements change.
