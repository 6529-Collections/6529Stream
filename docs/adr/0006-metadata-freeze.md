# ADR 0006: Metadata And Freeze

## Status

Accepted.

## Metadata

| Field | Value |
| --- | --- |
| Date | 2026-06-10 |
| Issue | [P1-META-ADR](https://github.com/6529-Collections/6529Stream/issues/45) |
| Blocks | [P0-META-001](https://github.com/6529-Collections/6529Stream/issues/9), [P1-META-001](https://github.com/6529-Collections/6529Stream/issues/46), [P1-META-002](https://github.com/6529-Collections/6529Stream/issues/47), [P1-META-003](https://github.com/6529-Collections/6529Stream/issues/48), [P1-META-004](https://github.com/6529-Collections/6529Stream/issues/49), [P1-META-005](https://github.com/6529-Collections/6529Stream/issues/50), [P1-META-006](https://github.com/6529-Collections/6529Stream/issues/51) |
| Related issues | [P0-RAND-004](https://github.com/6529-Collections/6529Stream/issues/40), [P0-ADMIN-001](https://github.com/6529-Collections/6529Stream/issues/34), [P0-ADMIN-002](https://github.com/6529-Collections/6529Stream/issues/35), [P0-INIT-001](https://github.com/6529-Collections/6529Stream/issues/15) |
| Related ADRs | [ADR 0001](0001-drop-authorization.md), [ADR 0004](0004-admin-governance.md), [ADR 0005](0005-randomness.md), [ADR 0007](0007-upgrade-redeployment.md) |
| Affected contracts | `smart-contracts/StreamCore.sol`, `smart-contracts/DependencyRegistry.sol`, `smart-contracts/StreamMinter.sol`, randomizer adapters that finalize token metadata |
| Work type | `DESIGN` |

## Problem

6529Stream exposes mutable NFT metadata before collection freeze. That metadata
can include collection fields, off-chain URIs, on-chain JSON, generated HTML,
collection scripts, dependency scripts, token data, token image data,
attributes, token hashes, and burn state.

Before public beta, the protocol needs to decide:

- what pending and final metadata mean for both off-chain and on-chain tokens
- what data becomes immutable when a collection is frozen
- whether dependency registry updates can change already frozen collections
- how dependency chunks are encoded, hashed, versioned, and proven
- whether `ERC-4906` metadata update events are supported
- how burned tokens behave for metadata, supply, and late randomness callbacks
- how JSON, HTML, JavaScript, and URI inputs are escaped and bounded
- which events and views let indexers, artists, collectors, and auditors verify
  the final state

Without a complete metadata/freeze model, a collection can appear final while
important rendering inputs remain mutable or ambiguous.

## Current Behavior

Current source references:

- `smart-contracts/StreamCore.sol#createCollection` stores collection name,
  artist, description, website, license, base URI, library URL, dependency key,
  dependency script chunks, and collection script chunks.
- `smart-contracts/StreamCore.sol#tokenURI` has two off-chain states:
  `baseURI + "pending"` while `tokenToHash[tokenId]` is zero and
  `baseURI + tokenId` after a nonzero token hash is set.
- On-chain `tokenURI` does not have an explicit pending state. It builds JSON,
  HTML, and JavaScript even when `tokenToHash[tokenId]` is zero, so a zero hash
  can be rendered as if it were final metadata.
- `collectionFreeze[collectionId]` blocks `setCollectionData`,
  `updateCollectionInfo`, `changeMetadataView`, `changeTokenData`, and
  `updateImagesAndAttributes`.
- Freeze does not currently pin dependency registry contents, dependency
  registry address, randomizer configuration, token hash state, collection
  final supply, or script content hashes.
- `freezeCollection` requires the minter end time to have passed and
  `wereDataAdded[collectionId]` to be true, then sets `collectionFreeze` without
  a collection-freeze event or manifest.
- `DependencyRegistry.addDependency` replaces all chunks for a dependency key.
  `DependencyRegistry.addDependencyScriptIndex` mutates one chunk. Both are
  possible after collections reference that dependency key.
- `StreamCore.updateContracts(3, newContract)` can swap the dependency registry
  address for future reads.
- `retrieveDependencyScript` renders dependency chunks with initialized
  `string.concat`, and `retrieveDependencyScriptContentHash(tokenId)` exposes a
  typed dependency content hash for the referenced dependency key. The hash is
  segment-safe for the current registry content, but it is not a full freeze
  manifest by itself because it does not pin registry identity, provenance, or
  immutable version lifecycle.
- `burn(collectionId, tokenId)` burns the ERC-721 token and increments
  `burnAmount[collectionId]`. After burn, `tokenURI(tokenId)` reverts through
  `_requireMinted`, while internal token mappings remain in storage.
- `StreamCore.supportsInterface` reports ERC-721, ERC-721 Metadata, ERC-2981,
  and ERC-4906 support. It intentionally does not report ERC-721 Enumerable
  support; the optional enumerable extension was removed for production
  deployability while preserving a live `totalSupply()` view.
- JSON string fields, raw attribute fragments, generated animation wrapper
  fields, `tokenData`, dependency scripts embedded in JavaScript strings, and
  wrapper closing-script boundaries now have first-slice escaping or rejection
  coverage. Numeric byte limits now cover collection display fields, collection
  scripts, token data, token images, token attributes, generated `tokenURI`
  output, dependency scripts, and dependency provenance. Semantic attribute
  schema validation, URI policy, invalid UTF-8 policy, and browser
  render-sandbox automation remain open under P1-META-006.

The current behavior is useful as characterization, but it is not a production
metadata promise.

## Decision

6529Stream will use an explicit, schema-versioned metadata model with immutable
collection freeze manifests.

The public-beta target design is:

1. Every metadata response belongs to a named schema version.
2. Off-chain metadata keeps the current compatibility shape:
   `baseURI + "pending"` before final randomness and `baseURI + tokenId` after
   final randomness.
3. On-chain metadata must have explicit pending and final states. Pending
   on-chain metadata must not embed a zero token hash as final generative input.
4. Public-beta on-chain JSON will be base64-encoded in the data URI. JSON
   string values must still be escaped before encoding.
5. Generated HTML remains executable content and must be treated as untrusted
   code by docs, tests, and render harnesses.
6. A collection can be frozen only after all live minted tokens have terminal
   randomness state and after the final supply/final mint window state is known.
7. Freeze creates an immutable manifest hash that commits to every rendering
   input needed to reproduce metadata for the collection.
8. After freeze, no public or admin path may change metadata-significant
   collection fields, token fields, scripts, dependency references, dependency
   content, metadata mode, base URI, or frozen manifest data.
9. Dependency scripts are versioned immutable records. Updating a dependency
   creates a new version; it does not mutate an already pinned version.
10. Frozen collections pin dependency key, dependency version, dependency
    content hash, and the dependency registry identity or equivalent immutable
    source proof.
11. `ERC-4906` is accepted for public beta. If metadata remains mutable before
    freeze, `StreamCore` must support interface ID `0x49064906` and emit
    `MetadataUpdate` or `BatchMetadataUpdate` when JSON metadata changes.
12. Burned tokens follow ERC-721 semantics: `tokenURI` is unavailable after
    burn. Internal audit state may remain, but burning does not create a new
    public metadata schema unless a later issue explicitly adds one.
13. Valid randomness fulfillment after burn may be recorded for audit
    traceability only if ADR 0005 callback validation passes. It must not
    resurrect ownership or make `tokenURI` available.
14. Metadata mutation authority follows ADR 0004. Magic index switches are not
    acceptable as the final public API.
15. Every external metadata, dependency, freeze, burn, and metadata-significant
    randomness transition emits a stable event.

## Metadata Modes

### Off-Chain Metadata

Off-chain metadata remains URI-based for compatibility:

- pending randomness: `baseURI + "pending"`
- fulfilled randomness: `baseURI + tokenId`

The implementation must document the exact concatenation rule, including
whether `baseURI` must include a trailing slash and whether token IDs are
decimal strings.

The pending URI must be driven by explicit randomness state from ADR 0005, not
only by `tokenToHash[tokenId] == 0`. A zero hash is an implementation detail,
not the public metadata state machine.

Changing any input that affects a token's off-chain JSON URL must emit the
appropriate `ERC-4906` event unless the token has not been minted or the change
is explicitly outside token metadata.

### On-Chain Metadata

On-chain metadata must produce deterministic JSON for both pending and final
states.

Pending on-chain metadata must:

- identify the token as pending randomness or stale according to ADR 0005
- omit final generative hash inputs, or include explicit placeholder fields
  that cannot be confused with final randomness
- avoid running final collection scripts with a zero token hash
- remain valid JSON under the active schema version

Final on-chain metadata must:

- include the final derived seed/hash from ADR 0005
- include deterministic collection and token fields
- include `animation_url` only after the generated HTML inputs are valid for
  the final state
- be covered by golden-file tests

The public-beta data URI shape is:

```text
data:application/json;base64,<base64-json>
```

This does not remove the need to escape JSON string values. Base64 protects the
URI layer; JSON escaping protects the JSON layer.

## Metadata Schema

Public-beta metadata must expose a documented schema version. The exact field
names may evolve before implementation, but tests and docs must cover at least:

- `name`
- `description`
- `image`
- `attributes`
- `animation_url` when on-chain animation is present
- `metadata_schema_version`
- `metadata_state` or an equivalent pending/final/stale indicator
- collection ID
- token ID
- final seed/hash when fulfilled

Attributes must be either:

- stored through a structured API and serialized by the contract or metadata
  renderer, or
- accepted as a raw JSON fragment only after validation proves that the value is
  a JSON array compatible with the schema.

Unvalidated raw fragments are not acceptable for public beta.

## Escaping, Validation, And Size Limits

Every untrusted or artist-provided field must be escaped or validated for the
context where it is used:

- JSON strings: quotes, backslashes, control characters, and invalid UTF-8
  handling
- HTML attributes and text
- JavaScript strings and arrays
- URI components
- raw attribute fragments
- dependency and collection script chunks

The first `P1-META-006` implementation slice escapes on-chain JSON string
fields (`name`, `description`, `image`, and `animation_url`) and adds a
structural guard for raw attribute fragments. That guard rejects literal control
characters, unterminated strings, unbalanced object/array delimiters, and
unquoted `]`/`}` breakout attempts while preserving brackets inside quoted JSON
strings. The second slice hardens generated animation wrapper boundaries by
escaping the external library attribute, embedding `tokenData` and dependency
scripts through escaped JavaScript strings, and neutralizing closing-script
sequences. The third slice defines numeric byte limits for stored metadata
inputs and generated `tokenURI` output. The remaining public-beta work is still
to define semantic attribute schema validation or structured attributes,
browser render-sandbox proofing for generated animation code, URI policy checks,
and invalid UTF-8 policy.

The implementation must define maximum sizes for:

- collection name
- artist name
- description
- website
- license
- base URI
- library URL
- token data
- image data
- attributes
- collection script chunks
- dependency script chunks
- generated `tokenURI`
- dedicated generated HTML render budgets, if separate from the generated
  `tokenURI` response cap

Tests must include adversarial strings with quotes, backslashes, brackets,
newlines, null-like control characters, Unicode edge cases if supported, and
large but valid inputs near each accepted limit.

`P1-META-006` owns the exact numeric limits. The current size-limit slice sets
explicit upper bounds for stored metadata fields, dependency registry metadata,
and generated `tokenURI` output. Remaining render-sandbox work must prove
through gas, calldata, and browser/render tests that accepted limits leave
release-approved headroom for generated HTML and dependency/script reads.

## Freeze Model

Freeze is the public promise that a collection's metadata-significant state is
immutable.

A collection may freeze only when:

- collection creation is complete
- the mint or sale window has ended according to the accepted sale model
- final supply or final mint accounting is known
- all live minted tokens have terminal randomness state
- dependency references are pinned to immutable versions and hashes
- token data, image data, and attributes for minted tokens are final
- metadata mode and base URI are final
- no pending admin update can change metadata-significant state

For freeze eligibility, terminal randomness for a live minted token means
`Fulfilled` under ADR 0005. `Stale` and `FailedPostProcessing` are not
freeze-eligible for live tokens in public beta. A collection with a live token
in one of those states must resolve the token through the accepted randomness
recovery path or burn policy before freeze.

The frozen manifest must commit to:

- collection ID
- metadata schema version
- metadata mode
- collection display fields
- base URI
- library URL
- dependency key
- dependency version
- dependency content hash
- dependency registry identity or immutable source proof
- collection script chunk hashes and full script hash
- final supply and minted-ever counters
- burned-token policy
- token metadata input hash for each live minted token, or a Merkle root over
  token metadata input records
- randomness state root or equivalent proof that live minted tokens are
  terminal
- generated HTML input root, or an explicit statement that the manifest relies
  on deterministic replay from the committed dependency, script, token input,
  and seed hashes instead of storing every rendered HTML output hash
- freeze block number and timestamp

The manifest hash must be deterministic and collision-resistant. Public-beta
implementation will use `keccak256(abi.encode(...))` over a versioned
`METADATA_FREEZE_MANIFEST_TYPEHASH`, collection ID, schema version, chain ID,
core contract address, and the committed field hashes or Merkle roots listed
above. Variable-length records such as token metadata inputs, script chunks, and
dependency chunks must be represented by typed per-record hashes and Merkle
roots or an equivalent length-aware structure. `abi.encodePacked` with multiple
dynamic fields is not acceptable for manifest hashing.

After freeze, these operations or stricter equivalents must revert:

- collection display field updates
- base URI changes
- metadata mode changes
- token data changes
- token image or attribute changes
- collection script changes
- dependency reference changes
- dependency content mutation affecting the collection
- dependency registry swap that changes the collection's resolved output
- randomizer or randomness state changes that would change public metadata for a
  live token
- final supply changes that would change collection metadata promises

If implementation keeps separate admin paths for emergency correction, those
paths must be explicitly outside public-beta metadata promises, evented,
documented as break-glass governance actions, and reviewed under ADR 0004.

## Dependency Registry

The dependency registry is part of the metadata surface. It must become
versioned and immutable for production collections.

Required model:

- dependency key identifies a dependency family
- dependency version identifies an immutable record inside that family
- each record stores or exposes chunk count, chunk hashes, full content hash,
  provenance, creator/admin, creation block, and deprecation state
- updating a dependency creates a new version
- mutating an existing production version is not allowed
- deprecating a version does not change already frozen collections
- collection metadata pins dependency key, version, and content hash
- frozen collections resolve dependency output from the pinned immutable record
  or from a manifest snapshot

`P0-META-001` owns the packed/dynamic composition fix and now provides typed
per-chunk and full-content hashes. The accepted hash shape uses `abi.encode`,
the dependency key, chunk count, chunk index, chunk byte length, and per-chunk
content hash so two ambiguous chunk layouts that render the same JavaScript
still produce distinct proof hashes.

`P1-META-003` remains responsible for immutable dependency versions,
provenance, registry identity, deprecation semantics, and freeze-manifest
pinning. Release manifests must pair any dependency content hash with the
registry contract identity and accepted dependency version record.

## ERC-4906 Event Policy

`StreamCore` must implement `ERC-4906` if metadata can change after mint and
before freeze.

Required interface behavior:

- `supportsInterface(0x49064906)` returns true when `ERC-4906` events are part
  of the public contract behavior.
- `MetadataUpdate(tokenId)` is emitted when one token's JSON metadata changes.
- `BatchMetadataUpdate(fromTokenId, toTokenId)` is emitted when a contiguous
  range of tokens may have changed metadata.
- Collection-wide updates may use batch events only for token ID ranges that
  are meaningful to indexers.

Events should be emitted for:

- token data updates
- token image or attributes updates
- off-chain pending to final URI changes after randomness fulfillment
- on-chain pending to final metadata changes
- metadata mode changes
- base URI changes that affect minted tokens
- collection display field changes that affect minted-token JSON
- collection script or dependency reference changes before freeze
- collection freeze if freeze changes metadata state or finality flags

Events should not be emitted merely because mint happened unless the
implementation intentionally documents that the token's JSON metadata changed
as part of mint. Burn must not emit `MetadataUpdate` merely because
`tokenURI` becomes unavailable; indexers should detect burn through the
standard ERC-721 transfer-to-zero event and any protocol burn event.

## Burned Tokens

Burn follows ERC-721 token-existence semantics.

Required public-beta behavior:

- `tokenURI(tokenId)` reverts after burn because the token no longer exists.
- burned tokens are excluded from live `totalSupply()` and live collection
  supply views.
- minted-ever counters and collection token ID allocation remain monotonic.
- burned token IDs are terminal and cannot be reminted in this release track.
- internal token-to-collection and token input records may be retained for
  audits, but they are not a public metadata availability guarantee.
- burn emits the standard ERC-721 transfer-to-zero event and any protocol burn
  event required for indexers.
- metadata docs must state that burned-token metadata should be treated as an
  archival off-chain/indexer concern unless a later ADR changes this decision.

If a valid randomness callback arrives after burn, ADR 0005 callback validation
still applies. The accepted behavior for public beta is to record the valid
fulfillment for audit traceability and emit an explicit event, while preserving
burned ownership and unavailable `tokenURI`. Stale-only rejection for otherwise
valid post-burn callbacks is out of scope unless a later ADR supersedes this
decision.

## Metadata Authority

Metadata authority follows ADR 0004.

Required rules:

- metadata mutation roles are separate from generic admin, signer, payment, and
  randomizer roles
- collection-admin support, if implemented, can mutate only the assigned
  collection and only before freeze
- unsupported collection-admin paths must revert or be removed so integrations
  do not assume they work
- magic update indexes such as `999999` and `1000000` must be replaced by
  explicit functions, named constants, or a typed enum before public beta
- every metadata-significant admin action must emit an event that includes
  caller, collection ID, affected token range or token ID, and stable field
  identifiers

## Events And Views

Required events or stricter equivalents:

- `CollectionMetadataUpdated(collectionId, field, oldValueHash, newValueHash, admin)`
- `TokenMetadataInputsUpdated(collectionId, tokenId, field, oldValueHash, newValueHash, admin)`
- `MetadataViewChanged(collectionId, onchainMetadata, admin)`
- `CollectionFrozen(collectionId, manifestHash, schemaVersion, admin)`
- `DependencyVersionCreated(dependencyKey, version, contentHash, admin)`
- `DependencyVersionDeprecated(dependencyKey, version, admin)`
- `DependencyVersionPinned(collectionId, dependencyKey, version, contentHash)`
- `BurnedTokenRandomnessRecorded(requestId, collectionId, tokenId, provider, randomizerEpoch, derivedSeed, rawOutputHash)`
- `MetadataUpdate(tokenId)` from `ERC-4906`
- `BatchMetadataUpdate(fromTokenId, toTokenId)` from `ERC-4906`

Required views or stricter equivalents:

- metadata schema version
- metadata state by token ID
- collection freeze status
- collection freeze manifest hash
- collection dependency key, version, and content hash
- collection script hash
- dependency version record
- token metadata input hash
- live collection supply
- minted-ever collection count
- burn count
- burned-token audit state if retained

## Implementation Requirements

Public-beta implementation must:

- replace zero-hash-only pending metadata checks with explicit randomness state
- add pending/final on-chain metadata behavior
- base64-encode on-chain JSON data URIs
- escape JSON string contexts and generated JavaScript/HTML wrapper contexts or
  reject unsafe inputs
- validate raw attribute fragments or replace them with structured attributes
- add metadata schema docs and golden-file tests
- add freeze manifest storage and views
- make freeze block all metadata-significant mutation paths
- version and hash dependency records
- pin dependency key, version, and content hash for collections
- make frozen collections independent from mutable registry updates
- implement `ERC-4906` support and event emissions
- document and test burn metadata semantics
- replace magic metadata update indexes
- add custom errors for security-relevant metadata and freeze failures
- update Slither baseline status for dependency encoding after code resolution

## Tests Required

P1 metadata tests must include:

- characterization tests for current off-chain pending and final URI behavior
- on-chain pending metadata golden file
- on-chain final metadata golden file
- off-chain URI concatenation rules
- JSON escaping for quotes, backslashes, brackets, control characters, and
  large valid values. The current first slice covers quotes, backslashes, JSON
  shorthand control characters, other ASCII control characters, and raw
  attribute breakout rejection; large valid values remain with size-limit work.
- JavaScript and HTML escaping or rejection tests. The current wrapper-safety
  slice decodes final animation HTML and covers external library attribute
  escaping, escaped `tokenData` and dependency-script JavaScript strings, and
  closing-script neutralization inside the generated wrapper. It does not
  sandbox artist collection scripts.
- raw attributes validation or structured attributes serialization
- metadata mode changes emit expected events before freeze
- token data, image, and attribute updates emit expected events before freeze
- `supportsInterface(0x49064906)` succeeds when `ERC-4906` is implemented
- `MetadataUpdate` and `BatchMetadataUpdate` are emitted only when metadata
  changes
- freeze succeeds only after terminal randomness and final supply prerequisites
- every metadata-significant mutation reverts after freeze
- frozen manifest hash remains stable
- dependency version creation, deprecation, and pinning
- dependency mutation cannot alter frozen collection output
- dependency chunk hashing cannot collide across ambiguous segment boundaries
- burn removes `tokenURI` availability and updates live supply
- callback after burn follows the documented behavior
- metadata views expose schema, freeze, dependency, supply, and token input
  hashes
- render sandbox tests exercise generated HTML for representative collections
- gas and size snapshots for `tokenURI`, dependency reads, and freeze

## Migration And Rollout

1. Keep existing off-chain metadata characterization tests.
2. Add golden-file tests for current behavior before changing metadata output.
3. Introduce metadata schema versioning and escaping.
4. Add explicit pending/final metadata states from ADR 0005.
5. Enforce dependency version records and content hashes.
6. Store freeze manifests and post-freeze guards.
7. Add `ERC-4906` interface support and event emissions.
8. Document burn metadata and callback-after-burn behavior in code and tests.
9. Update protocol docs, event catalog, API matrix, and release checklist.
10. Re-run `make check`, the Windows wrapper, Slither, metadata golden tests,
    and render sandbox tests before public beta.

## Alternatives Considered

### Keep On-Chain Zero Hash As Pending Art Input

Rejected. Rendering zero hash as ordinary script input creates ambiguity for
collectors and indexers. Pending must be explicit.

### Keep Mutable Dependency Keys Without Versions

Rejected. A mutable dependency key can change frozen art after freeze. Frozen
collections must pin immutable dependency content.

### Keep Raw UTF-8 JSON Data URIs

Rejected for public beta. Raw UTF-8 JSON data URIs are workable only with
rigorous escaping. Base64 JSON gives indexers a cleaner URI boundary while tests
still prove JSON correctness.

### Serve Burned-Token Metadata On-Chain

Rejected for P1. ERC-721 burn semantics make token existence and ownership
unambiguous. Archival metadata can be handled by indexers and event history
unless a later ADR accepts a separate burned-token metadata API.

### Avoid ERC-4906

Rejected while metadata remains mutable after mint. Indexers need a standard
signal that metadata changed before freeze.

## Non-Goals

- Implementing code, tests, CI, render sandbox tooling, or deployment scripts
  in this ADR PR.
- Choosing final metadata field names beyond the minimum schema requirements.
- Choosing final CDN, IPFS, Arweave, or website hosting infrastructure.
- Defining upgrade or redeployment strategy. [ADR 0007](0007-upgrade-redeployment.md)
  owns that decision.
- Defining final randomness provider behavior beyond the metadata interactions
  inherited from ADR 0005.

## Accepted Risks

- Moving on-chain JSON to base64 data URIs changes current raw UTF-8 output
  shape. The repository is pre-public-beta, and golden-file tests will pin the
  accepted shape before release.
- Frozen manifest design adds storage and gas cost. That cost is acceptable for
  a public finality promise.
- `ERC-4906` events improve indexer behavior but do not force third-party
  marketplaces to refresh immediately.
- Burned-token archival metadata will depend on events, indexers, and retained
  audit state rather than `tokenURI`.

## Open Follow-Ups

- Keep the [P0-META-001](https://github.com/6529-Collections/6529Stream/issues/9)
  typed dependency hash regression suite in place while later freeze-manifest
  work builds on it.
- Implement [P1-META-001](https://github.com/6529-Collections/6529Stream/issues/46).
- Complete [P1-META-002](https://github.com/6529-Collections/6529Stream/issues/47).
- Build [P1-META-003](https://github.com/6529-Collections/6529Stream/issues/48).
- Add [P1-META-004](https://github.com/6529-Collections/6529Stream/issues/49).
- Keep [P1-META-005](https://github.com/6529-Collections/6529Stream/issues/50)
  burn semantics covered while later metadata work evolves. The current
  implementation keeps burned-token `tokenURI` unavailable, retains audit
  state, records valid post-burn randomness through an audit-only event, and
  leaves frozen live-token metadata unchanged.
- Cover [P1-META-006](https://github.com/6529-Collections/6529Stream/issues/51).
  This issue must set concrete field, `tokenURI`, generated HTML, calldata, and
  gas budget limits before metadata implementation merges.
- Keep metadata/freeze deployment implications aligned with
  [ADR 0007](0007-upgrade-redeployment.md) during implementation.
