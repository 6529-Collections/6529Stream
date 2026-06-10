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

## Public-Beta Target

ADR 0006 requires future metadata work to add:

- schema version fields
- explicit pending, final, stale, and burned-state policy
- base64 JSON data URIs for on-chain metadata
- JSON escaping and raw-attribute validation
- ERC-4906 support and metadata update events
- freeze manifests and immutable dependency version pins
- burn semantics and callback-after-burn tests
