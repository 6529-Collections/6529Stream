# Metadata

This document records the current metadata baseline and the public-beta target
from [ADR 0006](adr/0006-metadata-freeze.md). The repository is still
pre-public-beta, so the golden fixtures in `test/fixtures/metadata/` are
characterization fixtures, not a final marketplace schema promise.

## Current Output

Off-chain metadata is URI-based:

- Pending randomness: `collectionBaseURI + "pending"`.
- Final randomness: `collectionBaseURI + tokenId` with the token ID as a
  decimal string.

The current contract does raw string concatenation and does not insert a path
separator. Operators must include the desired separator in `collectionBaseURI`.
For example, `collectionBaseURI = "https://example.com/collections/abc/"`
returns `https://example.com/collections/abc/pending` before randomness and
`https://example.com/collections/abc/123` after token `123` is finalized. Without
the trailing slash, `collectionBaseURI = "https://example.com/collections/abc"`
would produce `https://example.com/collections/abcpending` and
`https://example.com/collections/abc123`.

Current on-chain metadata is returned as:

```text
data:application/json;base64,<base64-json>
```

The current JSON includes:

- `metadata_schema_version` with value `6529stream-v1`
- `metadata_state` with value `pending` or `final`
- `name`
- `description`
- `image`
- `attributes`
- `animation_url` for final on-chain metadata only

Pending on-chain metadata no longer runs the final generative HTML path with a
zero token hash. It returns schema-versioned JSON with
`metadata_state: "pending"` and omits `animation_url`. Final on-chain metadata
returns schema-versioned JSON with `metadata_state: "final"` and the existing
base64-encoded HTML animation URL.

`StreamCore.metadataSchemaVersion()` exposes the active schema version and
`StreamCore.tokenMetadataState(tokenId)` exposes the current `pending` or
`final` state for minted tokens. The current schema version does not yet solve
JSON escaping, raw attribute validation, metadata size limits, dependency
artifact packaging beyond registry provenance strings, stale randomness display,
or burn metadata semantics.

## Golden Fixtures

`test/StreamMetadataGolden.t.sol` compares live contract output against:

- `test/fixtures/metadata/offchain-pending-token-uri.txt`
- `test/fixtures/metadata/offchain-final-token-uri.txt`
- `test/fixtures/metadata/onchain-pending-schema-v1-token-uri.txt`
- `test/fixtures/metadata/onchain-final-schema-v1-token-uri.txt`

The on-chain fixture names include the schema version so later schema migrations
are reviewable and deliberate.

## ERC-4906 Events

`StreamCore` supports ERC-4906 through `supportsInterface(0x49064906)`.

The current event policy is:

- `MetadataUpdate(tokenId)` is emitted when a live token's randomness is
  fulfilled through `setTokenHash`.
- `MetadataUpdate(tokenId)` is emitted when `changeTokenData` writes a live
  token's generative input.
- `MetadataUpdate(tokenId)` is emitted for each token written by
  `updateImagesAndAttributes`.
- `BatchMetadataUpdate(fromTokenId, toTokenId)` is emitted when
  `changeMetadataView` writes the metadata mode for a collection with minted
  tokens.
- `BatchMetadataUpdate(fromTokenId, toTokenId)` is emitted when
  `updateCollectionInfo` writes collection-level metadata inputs for a
  collection with minted tokens, including base URI, display fields, library,
  dependency reference, or collection script chunks.
- Batch events use the collection's minted-ever contiguous token range. They are
  skipped while a collection has no minted tokens.

The current contract intentionally does not emit ERC-4906 events merely because
a token is minted. If the configured randomizer fulfills during mint, the
fulfillment itself emits `MetadataUpdate`. Burn also does not emit ERC-4906;
indexers should treat the ERC-721 transfer-to-zero event as the live-token
metadata removal signal.

`freezeCollection` does not change `tokenURI` bytes, so it emits the
protocol-specific `CollectionFrozen` event rather than an ERC-4906 update.
Dependency reference changes or explicit dependency-version repins through
`updateCollectionInfo` emit batch events. Creating, deprecating, or replacing a
dependency registry version does not emit ERC-4906 events for collections that
remain pinned to an earlier version, because their token output is unchanged.

## Dependency Versions

`DependencyRegistry` treats dependency scripts as immutable version records:

- `addDependency(key, chunks)` creates the next version for `key`.
- `addDependencyWithProvenance(key, chunks, provenance)` creates the next
  version with an operator-supplied provenance string.
- `addDependencyScriptIndex(key, index, chunk)` derives the next version from
  the latest version with one chunk replaced.
- `deprecateDependencyVersion(key, version)` marks a version as deprecated but
  does not delete it or change collections already pinned to it.

Each version records chunk count, typed content hash, provenance string, creator,
creation block, creation timestamp, and deprecation state. Latest-version helper
views remain for compatibility, while versioned views expose
`getDependencyScriptCountAtVersion`, `getDependencyScriptAtVersion`,
`getDependencyScriptChunkHashAtVersion`, and
`getDependencyScriptContentHashAtVersion`.

`StreamCore` pins each collection to a dependency key, version, content hash, and
registry address at collection creation and whenever `updateCollectionInfo` runs
the full collection update path. Later registry versions do not change existing
collection output until the collection is explicitly repinned through
`updateCollectionInfo`. Script retrieval and freeze manifests use that pinned
registry address, so a later global registry swap cannot change an existing
collection's dependency bytes until the collection is explicitly repinned.
`collectionDependencyVersionState(collectionId)` exposes the current pin, and
`DependencyVersionPinned(collectionId, key, version, contentHash, registry)`
records each pin.

`bytes32(0)` is the explicit no-dependency sentinel and pins version `0` plus
the typed empty-script content hash. `DependencyRegistry` reserves that key for
the sentinel and rejects dependency writes under it, and `StreamCore` treats it
as no-dependency without consulting the registry latest-version pointer.
Nonzero dependency keys must already have a registered version before collection
creation or explicit repinning; otherwise `StreamCore` reverts with
`UnknownDependency(key)`.

## Freeze Manifest And Boundaries

`StreamCore.freezeCollection(collectionId)` records the public freeze boundary
for the current `StreamCore` metadata surface. A collection can freeze only when:

- collection data has been added
- the configured mint window has ended
- the final-supply delay has elapsed
- every live minted token has nonzero final metadata randomness

Freeze finalizes the collection supply to the minted-ever count, tightens the
reserved max token ID, stores `collectionFreezeManifestHash(collectionId)`, and
emits:

```text
CollectionFrozen(collectionId, manifestHash, schemaVersion, admin)
```

The manifest hash commits to the schema version, collection display fields,
metadata mode, dependency key, pinned dependency version, pinned dependency
content hash, pinned dependency registry address, collection script chunk
hashes, final supply counters, burn count, the tracked live-token metadata
aggregate, randomizer epoch/contract, core contract address, and chain ID. The
live-token aggregate is maintained as tokens are minted, burned, finalized by
randomness, or changed through token data, image, and attribute writes, so
freeze eligibility and manifest preview do not scan every minted token.

After freeze, current `StreamCore` paths cannot mint into the collection, change
collection metadata, change metadata mode, change token data, update token image
or attributes, change the collection randomizer, set token hashes, finalize
supply again, or swap the dependency registry while any collection is frozen.

The manifest now uses the collection's pinned dependency version, content hash,
and registry address, so later dependency registry versions or registry swaps
cannot change frozen collection output. Burn metadata and callback-after-burn
semantics remain P1-META-005.

## Public-Beta Target

ADR 0006 requires future metadata work to add:

- stale and burned-state policy
- JSON escaping and raw-attribute validation
- dependency artifact packaging and release manifests beyond registry
  provenance strings
- burn semantics and callback-after-burn tests
