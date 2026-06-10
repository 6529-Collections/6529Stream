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
data:application/json;utf8,<json>
```

The current JSON includes:

- `name`
- `description`
- `image`
- `attributes`
- `animation_url`

The current on-chain pending output still embeds the zero token hash in the
generated HTML. ADR 0006 rejects that as the final public-beta behavior; future
metadata work must replace it with an explicit pending state and update the
golden fixtures intentionally.

## Golden Fixtures

`test/StreamMetadataGolden.t.sol` compares live contract output against:

- `test/fixtures/metadata/offchain-pending-token-uri.txt`
- `test/fixtures/metadata/offchain-final-token-uri.txt`
- `test/fixtures/metadata/current-onchain-pending-token-uri.txt`
- `test/fixtures/metadata/current-onchain-final-token-uri.txt`

The fixture names use `current-onchain-*` because the current on-chain JSON is
not yet the accepted public-beta schema. These fixtures are meant to make
metadata changes reviewable and deliberate.

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

Current freeze does not change `tokenURI` bytes, so `freezeCollection` does not
emit ERC-4906 yet. Future schema-versioned freeze manifests may add finality
fields and should update this policy intentionally. Dependency reference changes
through `updateCollectionInfo` emit batch events; dependency registry content
versioning and reverse collection-to-dependency signaling remain part of
P1-META-003.

## Public-Beta Target

ADR 0006 requires future metadata work to add:

- schema version fields
- explicit pending, final, stale, and burned-state policy
- base64 JSON data URIs for on-chain metadata
- JSON escaping and raw-attribute validation
- freeze manifests and immutable dependency version pins
- burn semantics and callback-after-burn tests
