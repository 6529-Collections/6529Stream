# Metadata

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](spec-policy.md), and where this
document conflicts with a specification home, the specification wins.


This document records the current metadata baseline and the public-beta target
from [ADR 0006](adr/0006-metadata-freeze.md). The repository is still
pre-public-beta, so the golden fixtures in `test/fixtures/metadata/` are
characterization fixtures, not a final marketplace schema promise.

## Current Output

Off-chain metadata is URI-based:

- Pending randomness: `collectionBaseURI + "pending"`.
- Stale randomness: `collectionBaseURI + "stale"` when a lifecycle-aware
  randomizer reports the token request as stale and the token hash is still
  unset.
- Failed randomness post-processing: `collectionBaseURI + "failed"` when a
  lifecycle-aware randomizer reports `FailedPostProcessing` and the token hash
  is still unset.
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
- `metadata_state` with value `pending`, `stale`, `failed`, or `final`
- `name`
- `description`
- `image`
- `attributes`
- `animation_url` for final on-chain metadata only

Pending on-chain metadata no longer runs the final generative HTML path with a
zero token hash. It returns schema-versioned JSON with
`metadata_state: "pending"` and omits `animation_url`. Lifecycle-aware stale
and failed post-processing requests return the same schema with
`metadata_state: "stale"` or `metadata_state: "failed"` while the token hash
remains unset. Final on-chain metadata returns schema-versioned JSON with
`metadata_state: "final"` and the existing base64-encoded HTML animation URL.

`StreamCore.metadataSchemaVersion()` exposes the active schema version and
`StreamCore.tokenMetadataState(tokenId)` exposes `pending`, `stale`, `failed`,
or `final` for minted tokens. Randomizer state lookup failures, unsupported
randomizer lifecycle views, EOAs, and malformed return data fall back to
`pending`; a nonzero token hash always overrides lifecycle state and reports
`final`. The current schema version escapes JSON string fields emitted by
on-chain metadata and rejects raw attribute fragments that do not encode empty
content or comma-separated objects with exactly `trait_type` and `value` string
fields. It also enforces the current URI policy for token images, collection
base URIs, and external collection library URLs before storage. Fixture-level
checks now reject invalid UTF-8 data URI payloads and non-semantic attribute
entries in committed metadata golden files. Production dependency registry
writes now reject invalid UTF-8 dependency script chunks and provenance before
storage, and `StreamCore` production metadata writes now reject invalid UTF-8
before storage for collection text fields, collection script chunks, token
data, token image URIs, and token raw attributes. Browser render-sandbox checks
now execute the committed final on-chain animation fixture in Chromium with a
deterministic dependency stub and parent-frame isolation assertion. A separate
local deployment-rehearsal browser check now deploys the stack, mints through
the drop authorization path, finalizes metadata inputs, extracts the generated
`tokenURI`, and executes that generated final animation in the same Chromium
sandbox policy. Production dependency migration and source-retention ceremonies
are documented in [`docs/dependency-operations.md`](dependency-operations.md).
Fork/testnet/live production-evidence browser coverage and live deployment
release manifests remain open.

## Artist Approval Provenance

Artist approval is stored as collection-level provenance state, not embedded
inside `tokenURI` metadata. The display string remains available through
`artistsSignatures(collectionId)`, while `artistApprovalHashes(collectionId)`
records the canonical typed approval digest the artist approved.
`hashArtistApproval(collectionId)` returns the digest for the collection's
current on-chain state, and `artistSigned(collectionId)` returns true only when
the retained approval hash still matches that current digest. Indexers and
frontends should treat `artistSigned(collectionId) == true` as the signal that
the display string is backed by the current on-chain collection state. If
mutable collection fields change after an approval, the contract keeps the
display string and stored hash as historical provenance, `artistSigned` returns
false, and the artist can approve the new current hash.

Artists can approve directly from the configured artist address or through a
relayed EIP-712 approval. EOA signers use the digest returned by
`hashArtistApproval(collectionId)`, and contract-wallet artists are validated
through ERC-1271 `isValidSignature(bytes32,bytes)`. The EIP-712 domain is
`6529StreamArtistApproval` version `1`, with `chainId` and `verifyingContract`
set to the deployed `StreamCore`. The signed approval type is:

```text
StreamArtistApproval(
  address artist,
  bytes32 freezeManifestHash,
  uint256 maxCollectionPurchases,
  uint256 collectionTotalSupply,
  uint256 finalSupplyDelay
)
```

Frozen collections can still receive a final artist approval, allowing the
stored approval hash to bind the final immutable collection state.

## Escaping And Attribute Fragments

On-chain JSON string fields are escaped before base64 encoding:

- `name`
- `description`
- `image`
- `animation_url`

The escape policy covers quotes, backslashes, JSON shorthand control characters
such as newline/tab/carriage return, and other ASCII control characters through
`\u00XX`.

`attributes` remains a caller-authored raw JSON fragment inserted inside the
metadata array. `updateImagesAndAttributes` accepts an empty fragment or a
comma-separated sequence of objects whose only keys are `trait_type` and
`value`, with both values encoded as JSON strings. The production guard rejects
missing keys, duplicate keys, unexpected keys, non-string values, invalid JSON
string escapes, control characters, malformed separators, and attempts to break
out of the enclosing `attributes` array, while still allowing brackets inside
quoted JSON strings.

Generated animation HTML remains executable. The wrapper now escapes
`collectionLibrary` for the `<script src>` attribute, escapes `tokenData` and
dependency script content before embedding them into JavaScript string
literals, parses `tokenData` through `JSON.parse("[" + tokenDataRaw + "]")`,
and neutralizes literal `</script` sequences inside the generated wrapper
script. This protects wrapper structure, but it does not sandbox artist
`collectionScript` code or certify dependency code as safe. Release tooling
now validates the committed golden fixtures for JSON/data-URI structure,
strict UTF-8 decoding, current URI scheme policy, semantic attribute shape, and
generated HTML wrapper/script boundaries. It also runs the committed final
animation fixture in Chromium through a sandboxed iframe, fulfills exactly the
expected external dependency request with a deterministic stub, rejects
unexpected outbound requests, asserts the token bootstrap values are present,
and proves the frame cannot read the parent document. Fork/testnet/live
production-evidence browser proofing remains required before public beta.

## URI Policy

`StreamMetadataRenderer` exposes the current URI policy used by metadata tests
and fixture checks:

- Content URIs allow `https://`, `ipfs://`, and `ar://` values.
- Required content URIs must be nonempty.
- Optional content URIs may be empty when the caller explicitly allows it.
- Script URIs allow only `https://` values. Empty script URIs are allowed only
  when the caller explicitly treats the field as optional.
- `https://` URIs must include a host byte after the scheme.
- URI values containing ASCII whitespace, other ASCII control characters, or
  DEL are rejected.

`StreamCore` now enforces this policy before storing token image inputs,
collection base URIs, and external collection library URLs, reverting with
`UnsafeMetadataURI()` on failure. Token images are required content URIs.
Collection base URIs and external library URLs are optional fields, so empty
values remain valid, but any nonempty collection base URI must be a safe content
URI and any nonempty library URL must be a safe script URI.

## Contract-Level Metadata

`StreamContractMetadata` provides the current ERC-7572-style contract-level
metadata surface without adding bytes to `StreamCore`. This is a
satellite/read-adapter: it records the deployed `StreamCore` address, the
`StreamAdmins` authority, a safe contract metadata URI, and
`contractURIHash()` so release artifacts can bind the current pointer.

The adapter exposes:

- `contractURI()`, from `IERC7572`, for collection/contract-level metadata;
- `ContractURIUpdated()`, from `IERC7572`, whenever the URI changes;
- `supportsInterface(type(IERC7572).interfaceId)` and
  `supportsInterface(type(IStreamContractMetadata).interfaceId)`;
- `streamCore()` and `adminsContract()` for indexer/source binding; and
- `isStreamContractMetadata()` as the release-tracked marker.

The current contract-level metadata policy intentionally stores a content URI
rather than on-chain JSON. Accepted URI schemes are the same current content
schemes used for token image and collection base URI storage: `https://`,
`ipfs://`, and `ar://`. Empty, unsafe, whitespace-bearing, control-character,
and invalid UTF-8 values revert before storage. Data URIs are not accepted by
this adapter in the current release track even though ERC-7572 allows on-chain
JSON shapes; changing that would require a separate storage, size, and
marketplace-evidence decision.

`updateContractURI` is authorized through the existing target-scoped
function-admin or global-admin model and is blocked when
`StreamPauseDomains.METADATA_MUTATION` is paused. `updateAdminContract` is also
target-scoped, blocked by the same metadata-mutation pause, and must point at a
contract that exposes the accepted `IStreamAdmins` marker. The marker is an
interface guard rather than a trust guarantee, so operators must still treat
admin rebinding as a ceremony-level governance action. The local deployment
rehearsal deploys the adapter, records it in deployment manifests/address
books, and includes its ABI, bytecode hash, interface IDs, and
`ContractURIUpdated` topic in the generated release artifacts.

`contractURIHash()` is `keccak256(bytes(contractURI()))` over the exact stored
URI bytes. The adapter does not normalize, lowercase, trim, decode, or fetch
the URI before hashing it.

The adapter is not `StreamCore` itself. Third-party marketplaces or wallets
that only probe the ERC-721 contract address for `contractURI()` will not
discover this surface until an integration explicitly follows the release
manifest/address book or until a later size-budget decision moves an equivalent
surface into a core or proxy address. Public-beta claims about OpenSea,
Reservoir, Blur, Manifold, wallets, or indexers reading contract-level metadata
still require retained fork/testnet/live evidence.

Contract-level metadata is not part of the per-collection freeze manifest in
the current implementation. Collection freeze remains the permanence boundary
for token rendering inputs in `StreamCore`; the adapter-level URI remains
governance-mutable before release and should be treated as release-artifact
state that changes only through an evented admin ceremony.

This slice also replaces several older `StreamCore` string reverts on
metadata-adjacent mint, randomizer, pause, and contract-wiring paths with
custom errors so the production URI checks fit under EIP-170 and integrations
can match selectors deterministically. New custom errors include
`CollectionSupplyReached()`, `CollectionSupplyTooLarge()`,
`InvalidAdminContract()`, `InvalidMinterContract()`,
`InvalidRandomizerContract()`, `MetadataMutationPaused()`,
`NotMinterContract()`, `TokenOutsideCollectionRange()`, and
`ZeroTokenHash()`.

## 1/1 Provenance Manifests

1/1 provenance is a collector-facing release artifact, not an additional
`StreamCore` token-rendering input in the current release track. The canonical
policy is [docs/provenance-manifests.md](provenance-manifests.md), the checked
schema is
[release-artifacts/schema/one-of-one-provenance-manifest.schema.json](../release-artifacts/schema/one-of-one-provenance-manifest.schema.json),
and the generated catalog is
[release-artifacts/latest/one-of-one-provenance-manifest.json](../release-artifacts/latest/one-of-one-provenance-manifest.json).
The current no-secret template is
[release-artifacts/provenance/one-of-one-provenance-template.provenance.json](../release-artifacts/provenance/one-of-one-provenance-template.provenance.json).

The manifest model can describe artist statements, authenticity status,
certificate hashes, curation notes, exhibition or publication history, retained
artifact hashes, and append-only story/provenance entries. These fields help
frontends, indexers, collectors, and auditors display and verify 1/1 context
without treating that context as ownership proof, marketplace readiness proof,
royalty enforcement, or a replacement for chain state.
Use [docs/royalty-policy.md](royalty-policy.md) for the current ERC-2981
royalty disclosure, governance, marketplace display, and non-enforcement
boundary.

This boundary is intentional while `StreamCore` remains close to the EIP-170
bytecode limit. The provenance manifest is not `tokenURI()` JSON, not
`contractURI()` JSON, not `collectionFreezeManifestHash(collectionId)`, and not
new `StreamCore` storage. A future on-chain provenance event/view or satellite
contract must be accepted in a separate size-budget and integration decision.
Until then, provenance is validated through the release artifact toolchain:

```text
python scripts/test_one_of_one_provenance_manifest.py
python scripts/check_one_of_one_provenance_manifest.py
python scripts/generate_one_of_one_provenance_manifest.py --check
```

## Collector-Verifiable Permanence Packages

Collector-verifiable permanence packages are release artifacts that sit beside
metadata and provenance. The canonical policy is
[docs/permanence-packages.md](permanence-packages.md), the checked schema is
[release-artifacts/schema/one-of-one-permanence-package.schema.json](../release-artifacts/schema/one-of-one-permanence-package.schema.json),
and the generated catalog is
[release-artifacts/latest/one-of-one-permanence-manifest.json](../release-artifacts/latest/one-of-one-permanence-manifest.json).
The current no-secret template is
[release-artifacts/permanence/one-of-one-permanence-template.permanence.json](../release-artifacts/permanence/one-of-one-permanence-template.permanence.json).

The package model can describe renderer source, dependency source and
provenance hashes, source archive hashes, exact replay commands, metadata JSON
hashes, animation HTML hashes, rendered output hashes, browser proof hashes,
and fully on-chain versus decentralized storage guarantees. These fields help
collectors, frontends, indexers, and auditors verify replayability without
treating the package as marketplace readiness proof, royalty enforcement,
ownership proof beyond chain state, or production release approval.

This boundary is intentional while `StreamCore` remains close to the EIP-170
bytecode limit. The permanence package is not `tokenURI()` JSON, not
`contractURI()` JSON, not `collectionFreezeManifestHash(collectionId)`, and not
new `StreamCore` storage. A future on-chain permanence event/view or satellite
contract must be accepted in a separate size-budget and integration decision.
Until then, permanence packages are validated through the release artifact
toolchain:

```text
python scripts/test_one_of_one_permanence_package.py
python scripts/check_one_of_one_permanence_package.py
python scripts/generate_one_of_one_permanence_manifest.py --check
```

## Size Limits

`StreamCore` and `DependencyRegistry` now reject oversized metadata inputs
before storing them, and `StreamCore.tokenURI` rejects generated responses that
exceed the configured response cap. Reverts use
`MetadataFieldTooLarge(field, actual, maximum)` or
`DependencyFieldTooLarge(field, actual, maximum)` so callers can identify the
failed surface without parsing strings.

| Surface | Limit |
| --- | ---: |
| Collection text fields: name, artist, description, website, license, base URI, library URL | 2,048 bytes each |
| Collection script chunk | 8,192 bytes |
| Collection script chunks per collection | 32 chunks |
| Token data | 4,096 bytes |
| Token image | 2,048 bytes |
| Token raw attributes fragment | 8,192 bytes |
| Generated `tokenURI` response | 65,536 bytes |
| Dependency script chunk | 8,192 bytes |
| Dependency script chunks per version | 32 chunks |
| Dependency provenance | 2,048 bytes |

## UTF-8 Policy

`StreamMetadataRenderer.isValidUtf8(raw)` exposes the shared strict UTF-8
scanner used by production metadata guards. The scanner accepts ASCII and valid
2-, 3-, and 4-byte UTF-8 sequences, and rejects lone continuation bytes,
invalid continuation bytes, overlong encodings, surrogate encodings, code
points above U+10FFFF, and truncated multibyte sequences.

`DependencyRegistry` applies this policy to dependency script chunks and
dependency provenance. Oversized values still fail with
`DependencyFieldTooLarge(field, actual, maximum)` before UTF-8 validity is
checked; invalid in-limit values fail with
`DependencyFieldInvalidUTF8(field)`.

`StreamCore` applies the same strict policy to collection display fields,
collection base URI and library URL inputs, collection script chunks, token
data, token image URI inputs, and token raw attributes. Oversized values fail
first with `MetadataFieldTooLarge(field, actual, maximum)`; invalid in-limit
values fail with `MetadataFieldInvalidUTF8(field)`.

## Golden Fixtures

`test/StreamMetadataGolden.t.sol` compares live contract output against:

- `test/fixtures/metadata/offchain-pending-token-uri.txt`
- `test/fixtures/metadata/offchain-stale-token-uri.txt`
- `test/fixtures/metadata/offchain-failed-token-uri.txt`
- `test/fixtures/metadata/offchain-final-token-uri.txt`
- `test/fixtures/metadata/onchain-pending-schema-v1-token-uri.txt`
- `test/fixtures/metadata/onchain-stale-schema-v1-token-uri.txt`
- `test/fixtures/metadata/onchain-failed-schema-v1-token-uri.txt`
- `test/fixtures/metadata/onchain-final-schema-v1-token-uri.txt`

The on-chain fixture names include the schema version so later schema migrations
are reviewable and deliberate.

`scripts/check_metadata_fixtures.py` validates these committed fixtures outside
Foundry. The check strictly decodes base64 data URIs as UTF-8, parses on-chain
metadata JSON, validates current content/script URI scheme policy, validates
fixture attributes as `trait_type` / `value` string pairs, decodes the final
`animation_url` HTML, and asserts the generated wrapper contains exactly one
external library script and one inline generative script with no raw script tag
breakout. `scripts/test_metadata_fixtures.py` covers the happy path, invalid
UTF-8 fixture payloads, semantic attribute-shape failures, and hostile wrapper
regressions; both scripts run in `make check`, the platform check wrappers, and
CI.

`scripts/check_metadata_browser_sandbox.py` adds the browser-backed half of the
fixture gate. It opens the committed final on-chain `animation_url` in Chromium
inside an `allow-scripts` sandboxed iframe, stubs the single expected external
dependency URL, fails unexpected outbound HTTP(S) requests, captures page and
console errors, asserts the current hash/token bootstrap values are available in
the frame, and verifies parent-document access fails with `SecurityError`.
`scripts/test_metadata_browser_sandbox.py` covers the harness and result
validation logic without launching a browser. Playwright is pinned in
`requirements-tools.txt`; bootstrap scripts install Chromium for contributors,
and CI installs the same toolchain before the metadata fixture safety job.

`script/RehearseMetadataBrowser.s.sol` and
`scripts/check_rehearsal_metadata_browser_sandbox.py` add the
deployment-rehearsal-generated half of the browser gate. The rehearsal deploys
the local non-production stack, registers a deterministic dependency,
configures an executable draw script, mints a zero-price fixed-price drop using
EIP-712 authorization, finalizes token image/attribute and randomness inputs,
then returns the generated on-chain `tokenURI`. The Python checker decodes that
`tokenURI`, validates the rehearsal evidence envelope, and runs the generated
final animation through the same Chromium sandbox policy as the committed
fixture check. This is local Anvil evidence and does not require RPC secrets; a
future fork, testnet, or production broadcast should still retain equivalent
browser evidence for release ceremonies.

## ERC-4906 Events

`StreamCore` supports ERC-4906 through `supportsInterface(0x49064906)`.
It does not advertise ERC-721 Enumerable support. The optional enumerable
extension was removed from `StreamCore` to keep production bytecode deployable;
the contract preserves a live `totalSupply()` view but does not expose
`tokenByIndex` or `tokenOfOwnerByIndex`.

The current event policy is:

Use [`docs/integrations/events-and-indexing.md`](integrations/events-and-indexing.md)
for the broader indexer reconstruction model, confirmation-depth posture,
read-after-event expectations, and known event/read gaps.

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
indexers should treat the ERC-721 transfer-to-zero event and the protocol
`TokenBurned(collectionId, tokenId, operator, owner)` event as the live-token
metadata removal signal.

`freezeCollection` does not change `tokenURI` bytes, so it emits the
protocol-specific `CollectionFrozen` event rather than an ERC-4906 update.
Dependency reference changes or explicit dependency-version repins through
`updateCollectionInfo` emit batch events. Creating, deprecating, or replacing a
dependency registry version does not emit ERC-4906 events for collections that
remain pinned to an earlier version, because their token output is unchanged.

## Burned Tokens

Burned tokens follow ERC-721 token-existence semantics:

- `ownerOf(tokenId)`, `tokenURI(tokenId)`, and `tokenMetadataState(tokenId)`
  are unavailable after burn.
- Burn emits the standard ERC-721 transfer-to-zero event and
  `TokenBurned(collectionId, tokenId, operator, owner)`.
- Burned tokens are excluded from live `totalSupply()` and
  `totalSupplyOfCollection(collectionId)`.
- `burnAmount(collectionId)` records the collection burn count.
- `viewColIDforTokenID(tokenId)` and `retrieveTokenHash(tokenId)` retain audit
  state, but that retention is not a public metadata availability guarantee.
- `isTokenBurned(tokenId)` and `burnedTokenAuditState(tokenId)` expose retained
  burn audit state for indexers and incident review.
- Burned token IDs are terminal and cannot be reminted in this release track.

If a valid VRF or arRNG fulfillment arrives after a pending token is burned, the
adapter records the derived seed/hash for audit only. The adapters emit:

```text
BurnedTokenRandomnessRecorded(requestId, collectionId, tokenId, provider, randomizerEpoch, derivedSeed, rawOutputHash)
```

That event is emitted only after `StreamCore.setTokenHash` accepts the
post-burn hash. The write does not resurrect ownership, does not make
`tokenURI` available, does not emit ERC-4906 metadata update events, and remains
allowed after collection freeze because the frozen manifest commits only to live
token metadata plus the burn count.

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

## Dependency Artifact Packaging

Release-packaged dependency source files live under
`release-artifacts/dependencies/`. Each package has a
`6529stream.dependency-artifact.v1` descriptor that records the protocol version,
deployment version, dependency registry key, version, registry contract label,
provenance string, source registration path, and repo-relative source files.

`scripts/generate_dependency_artifact_manifest.py` validates those descriptors,
rejects missing files, malformed dependency keys, duplicate dependency
identities, and paths outside `release-artifacts/dependencies/`, then emits
`release-artifacts/latest/dependency-artifact-manifest.json` with SHA-256
integrity records. The top-level release manifest includes that generated
manifest, and `SHA256SUMS` covers both the generated output and the source
descriptors/files. The first committed package covers the local Anvil rehearsal
dependency registered by `script/RehearseDeployment.s.sol`.

Production dependency changes must follow the
[`Dependency Operations Runbook`](dependency-operations.md). The runbook covers
proposal, review, source packaging, registry registration, unfrozen collection
repinning, deprecation, rollback by corrective version, frozen collection
immutability, and source-retention evidence.

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
or attributes, change the collection randomizer, set live/pre-mint token hashes,
finalize supply again, or swap the dependency registry while any collection is
frozen. A valid post-burn randomness fulfillment may still record audit-only
hash state for a burned token and does not change the frozen manifest.

The manifest now uses the collection's pinned dependency version, content hash,
and registry address, so later dependency registry versions or registry swaps
cannot change frozen collection output.

## Public-Beta Target

ADR 0006 requires future metadata work to add:

- broader fork/testnet/live production-evidence browser execution proofing for
  generated animation code beyond the committed golden fixture and local
  deployment-rehearsal sandbox checks
- richer structured attributes if the protocol moves away from caller-authored
  raw fragments; production raw-attribute schema validation now exists
