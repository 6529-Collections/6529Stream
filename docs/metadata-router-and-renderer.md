# Metadata Router And Renderer

This document is a pre-launch target specification for moving Stream metadata
rendering and script assembly out of `StreamCore` into dedicated metadata
contracts. `StreamCore` should remain the canonical ERC-721 contract, keep
`ERC721Enumerable`, and expose `tokenURI(uint256)` as required by ERC-721
metadata. The heavy metadata construction logic should live outside Core.
The cross-cutting 50+ year architecture principles live in
`docs/stream-long-term-architecture.md`.

## Design Summary

`StreamCore` should keep ownership, approvals, enumeration, token-to-collection
identity, mint finality, and minimal external hooks. The new metadata layer
should own token URI routing, metadata mode selection, JSON construction, HTML
construction, script assembly, dependency assembly, renderer versioning, and
metadata refresh events.

```text
StreamCore
  - ERC-721 ownership and enumeration
  - token existence checks
  - token to collection identity
  - collection supply facts needed by token naming
  - minimal tokenURI forwarding
  - optional minimal contractURI forwarding
  - admin-controlled metadata router pointer

StreamMetadataRouter
  - default, collection, and token renderer resolution
  - metadata mode resolution
  - pending, offchain, onchain, and hybrid routing
  - global contract metadata routing
  - metadata config storage
  - metadata freeze policy
  - ERC-4906-style refresh events

StreamRendererV1
  - safe JSON construction
  - safe HTML construction
  - script context assembly
  - dependency assembly
  - manifest-aware media output
  - Base64/data URI output
  - renderer version disclosure
```

`StreamCore.tokenURI(tokenId)` remains the public entrypoint that marketplaces,
wallets, indexers, and collectors call. Internally, Core delegates the metadata
answer to the configured metadata router.

## Adopted Research Decisions

The metadata architecture should adopt these eight design decisions from the
research pass in `docs/metadata-renderer-research.md`:

1. Keep `StreamCore.tokenURI()` native from the caller's perspective, but move
   heavy rendering, script assembly, and metadata JSON construction behind
   router and renderer contracts.
2. Treat the script, token hash, render context, dependencies, and media
   manifests as the durable artwork primitive, not merely as display metadata.
3. Keep top-level token JSON conservative and marketplace-compatible, while
   putting rich Stream-native facts under `properties.stream` and sibling
   namespaces.
4. Add ERC-7572-shaped contract metadata through router and
   `StreamCollectionMetadata` reads. Do not add Core `contractURI()` in launch
   v1 unless a later bytecode and marketplace evidence review explicitly
   accepts that Core surface.
5. Emit ERC-4906-compatible metadata refresh events from Core whenever token
   JSON materially changes.
6. Make renderer, script, dependency, media, and schema manifests first-class,
   with URI and hash commitments for every offchain or externally resolved
   payload.
7. Design storage as plural from day one: launch can use chunked strings, while
   the manifest interfaces can later point to SSTORE2, EthFS, Arweave, IPFS,
   dependency registries, or other durable stores without touching Core.
8. Keep frontier ideas as optional modules outside launch Core: post-mint
   parameters, dynamic onchain traits, alternate token views, token-bound
   accounts, and agent-readable metadata/tooling.

## Current Implementation Baseline

Current `origin/main` already made an important metadata-safety pass:

1. `StreamCore` implements ERC-4906 metadata refresh events.
2. `StreamCore` implements default ERC-2981 royalty disclosure.
3. `StreamCore.tokenURI()` delegates escaping, Base64 encoding, generated
   metadata assembly, dependency assembly, token metadata state, and size-limit
   checks to the `StreamMetadataRenderer` library.
4. Collection text, token data, token image, token attributes, collection script
   chunks, generated token URI size, dependency registry markers, and
   randomizer lifecycle checks now have explicit validation helpers.
5. Token metadata changes emit `MetadataUpdate`, and collection-level metadata
   changes can emit `BatchMetadataUpdate`.

That is a good current-state hardening step, but the ERC-721 Core still owns
too much long-term metadata responsibility:

1. Core still stores collection display metadata, base URI, library URI,
   dependency ID, and script chunks.
2. Core still stores token image and raw attributes.
3. Core still chooses offchain versus onchain metadata mode.
4. Core still builds the generated script path, even through a helper library.
5. Core still owns collection freeze and artist approval state tied to metadata.
6. Core still carries dynamic string/array storage and public metadata tuple
   reads that are not essential to ERC-721 ownership.

The target architecture keeps the current safety improvements but moves the
metadata policy, storage, and rendering boundary out of `StreamCore`. Core
should retain only minimal `tokenURI()` forwarding, optional minimal
token existence checks, token-to-collection facts,
and Core-originated metadata refresh events.

The earlier scratch compile showed that moving renderer/script assembly out of
Core saves about `3.8 KB` of runtime bytecode. The exact number should be
remeasured against current `origin/main`, but the architectural direction
remains the same: keep Core small and make the metadata layer the place where
long-lived renderer, schema, script, preservation, and view logic evolves.

## Standards Baseline

The renderer should deliberately support three metadata audiences:

1. ERC-721 consumers that only expect the formal metadata JSON schema fields:
   `name`, `description`, and `image`.
2. Marketplace and wallet consumers that understand widely adopted richer
   fields such as `external_url`, `animation_url`, `attributes`, and
   `background_color`.
3. Stream-native frontends, archival tools, and future indexers that can read
   namespaced fields under `properties.stream` and other extension objects.

The top-level JSON should stay conservative and marketplace-friendly. Rich
machine-readable facts should go under namespaces so future expansion does not
pollute trait filters or depend on every marketplace recognizing new fields.

## Goals

1. Keep `StreamCore` small enough to support Core-native ERC-2981 and
   long-term ERC-721 behavior without bytecode pressure.
2. Keep `ERC721Enumerable` in Core.
3. Keep `tokenURI(uint256)` Core-native from the caller's perspective.
4. Make metadata rendering a first-class module with explicit versioning.
5. Support default, collection-level, and token-level renderer configuration.
6. Support explicit pending, offchain, onchain, and hybrid metadata modes.
7. Provide safer JSON and JavaScript assembly than raw string concatenation.
8. Support richer future metadata schemas without redeploying the NFT core.
9. Make metadata update events clear for marketplaces and indexers.
10. Allow irreversible freezes at the collection or token scope.
11. Emit a rich default metadata schema while keeping extension fields open.

## Non-Goals

1. The metadata router does not own ERC-721 ownership state.
2. The metadata router does not mint, burn, transfer, or approve tokens.
3. The metadata router does not make royalty or primary-sale decisions.
4. The metadata router does not enforce marketplace royalty payment.
5. The metadata router does not become an upgradeable proxy by default.
6. The metadata router does not require labels, proceeds splits, or payment
   logic.

## Core Contract Changes

`StreamCore` should expose a minimal metadata router pointer:

```solidity
interface IStreamMetadataRouter {
    function tokenURI(address core, uint256 tokenId)
        external
        view
        returns (string memory);

    function contractURIForCore(address core)
        external
        view
        returns (string memory);

    function contractURIForCollection(address core, uint256 collectionId)
        external
        view
        returns (string memory);
}
```

`StreamCore` should store:

```solidity
IStreamMetadataRouter public metadataRouter;
```

`StreamCore.tokenURI()` should become a minimal bounded router call, not a
high-level unbounded string forward:

```solidity
enum TokenURIReadStatus {
    OK,
    NONEXISTENT,
    PREPARED_INCOMPLETE,
    BURNED,
    ROUTER_UNSET,
    ROUTER_NO_CODE,
    ROUTER_REVERTED,
    ROUTER_RETURNDATA_OVERSIZED,
    ROUTER_MALFORMED
}

function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
{
    _requireMinted(tokenId);

    (bool ok, string memory uri, TokenURIReadStatus status) =
        _boundedRouterTokenURI(tokenId);

    if (ok) {
        return uri;
    }

    return _fallbackTokenURI(tokenId, status);
}
```

The cross-contract numeric values are pinned in the Numeric ID Catalog:
`OK = 0`, `NONEXISTENT = 1`, `PREPARED_INCOMPLETE = 2`, `BURNED = 3`,
`ROUTER_UNSET = 4`, `ROUTER_NO_CODE = 5`, `ROUTER_REVERTED = 6`,
`ROUTER_RETURNDATA_OVERSIZED = 7`, and `ROUTER_MALFORMED = 8`.

Launch implementation requirements:

1. `metadataRouter == address(0)` returns the documented fallback JSON data URI
   for minted tokens with status `ROUTER_UNSET`.
2. A router address with no code returns the fallback with status
   `ROUTER_NO_CODE`.
3. Core calls the router through low-level `staticcall` with
   `METADATA_ROUTER_GAS_LIMIT`, after checking that parent gas can cover the
   call plus a named return buffer.
4. Core copies at most `MAX_TOKEN_URI_RETURNDATA` bytes from returndata before
   decoding. A router cannot force unbounded memory allocation.
5. Revert, malformed ABI, oversized returndata, or an empty required response
   returns the documented fallback for minted tokens. These failures must not
   make minted-token `tokenURI()` revert.
6. `_requireMinted(tokenId)` remains the only ordinary ERC-721 nonexistent-token
   revert in Core's default `tokenURI()` path.
7. The fallback payload is intentionally small and deterministic. It includes a
   name, description, optional empty image, and `properties.stream.error`.
8. The release manifest records the router gas limit, returndata limit, fallback
   schema hash, and gas measurements for success, revert, malformed return,
   oversized return, no-code router, and unset router cases.
`METADATA_ROUTER_GAS_LIMIT` must be a deploy-time immutable for a Core release,
not mutable governance state. A successor Core may choose a different immutable
gas limit after measuring a new router implementation, but launch Core must not
include a runtime setter that changes marketplace metadata read behavior.
The fallback JSON schema must be canonicalized and hash-committed in the
release manifest. The schema defines exact required fields, optional fields,
error-code vocabulary, omitted/null semantics, and canonicalization method so
independent tools can reproduce the fallback schema hash.

Core should also expose a diagnostic read with the same bounded call rules:

```solidity
function tokenURIStatus(uint256 tokenId)
    external
    view
    returns (
        TokenURIReadStatus status,
        address router,
        address renderer,
        bytes32 snapshotHash,
        bytes32 failureReason
    );
```

If the router itself is unreachable, Core computes the status locally instead
of depending on a router-side diagnostic. Router-side `tokenURIStatus` remains
useful for richer renderer and dependency failure reasons after Core has
successfully reached the router.
Unlike `tokenURI()`, `tokenURIStatus()` is a diagnostic read and should not
revert for nonexistent or burned tokens. It returns `NONEXISTENT` for a token
ID with no authoritative Core identity mapping, and `BURNED` for a token whose
retained mapping exists but ERC-721 ownership has been removed. The only
acceptable reverts are ordinary Solidity panics or catastrophic read failures
outside the launch test envelope.

Core should not expose `contractURI()` in launch v1. Stream is a
multi-collection ERC-721, and Core bytecode is reserved for ownership,
enumeration, Core-native ERC-2981, Core-native `tokenURI()` forwarding, and
Core-originated ERC-4906 refresh. ERC-7572-shaped contract metadata should be
served through router and metadata reads:

```solidity
function contractURIForCore(address core)
    external
    view
    returns (string memory);

function contractURIForCollection(address core, uint256 collectionId)
    external
    view
    returns (string memory);
```

Collection-specific contract metadata lives in
`StreamCollectionMetadata.contractURI(collectionId)`. The launch release
manifest must record that Core intentionally omits `contractURI()` to preserve
bytecode headroom and must point indexers to the Stream-native global and
collection-scoped metadata reads. A future Core `contractURI()` can be
reconsidered only after final bytecode measurements and marketplace evidence
show it is worth the Core surface.
Marketplace and indexer discovery guidance: read the Core-hosted
`streamSystemManifest()` to discover the current metadata router and collection
metadata contract, call `StreamMetadataRouter.contractURIForCore(core)` for
global Stream contract metadata, and call
`StreamCollectionMetadata.contractURI(collectionId)` for collection-specific
contract metadata. Core intentionally has no ERC-7572 `contractURI()` selector
in launch v1.

Core should emit an event when the router changes:

```solidity
event MetadataRouterUpdated(address indexed oldRouter, address indexed newRouter);
```

`CoreSatellitePointerUpdated(METADATA_ROUTER, ...)` is the canonical governance
event for router pointer history. `MetadataRouterUpdated` is an optional
convenience mirror for marketplace/indexer compatibility and must be emitted in
the same execution as the canonical pointer update if it is included. It must
not be used as a separate update path or carry different authority semantics.

Core should only allow router changes through ADR 0004 governance/action roles.
Legacy selector-map `StreamAdmins` authorization is nonconformant for launch.
The
router should be set before launch. Router changes must follow the shared Core
Satellite Pointer Policy in `docs/stream-long-term-architecture.md`: staged
operation ID, registry eligibility, expected code hash, expected manifest hash,
reason URI/hash, cancellation path, execution recheck, and optional one-way
pointer freeze. Incident updates must not silently alter frozen collection or
token artwork; frozen scopes keep their captured router/renderer identity or a
hash-bound recovery snapshot.

## Core Read Interface

The router and renderers need a stable, read-only interface to Core. They should
not depend on Solidity storage layout or private mappings.

Recommended interface:

```solidity
interface IStreamCoreMetadataView {
    function ownerOf(uint256 tokenId) external view returns (address);
    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (
            bool mappingExists,
            uint256 collectionId,
            uint256 collectionSerial,
            bool burned
        );
    function tokenLifecycle(uint256 tokenId) external view returns (uint8);
    function collectionSupplyMode(uint256 collectionId) external view returns (uint8);
    function collectionStatus(uint256 collectionId) external view returns (uint8);
    function collectionHasMaxSupply(uint256 collectionId) external view returns (bool);
    function collectionMaxSupply(uint256 collectionId) external view returns (uint256);
    function collectionMintedEver(uint256 collectionId) external view returns (uint256);
    function viewCirSupply(uint256 collectionId) external view returns (uint256);
    function totalSupplyOfCollection(uint256 collectionId) external view returns (uint256);
    function collectionFreezeStatus(uint256 collectionId) external view returns (bool);
    function coordinatorAtMint(uint256 tokenId) external view returns (address);
}
```

`tokenCollectionIdentity` is the canonical Core token-to-collection read shared
with royalties and finality. For burned tokens it must return
`mappingExists = true`, the last collection ID, the last collection-local
serial, and `burned = true`, even though `StreamCore.tokenURI()` may revert
before the router is called. The historical `viewColIDforTokenID` helper name
from `origin/main` is not the target satellite interface.

This interface should be expanded only when metadata genuinely needs new Core
facts. Long strings, script chunks, dependency IDs, image URIs, and attributes
should move to metadata storage rather than remain in Core.

Entropy seeds should not be stored in Core. Core only exposes
`coordinatorAtMint(tokenId)`, the coordinator pinned when the token was
allocated. The router and renderers should read seed/status from that dedicated
entropy coordinator, as described in `docs/stream-entropy-coordinator.md`:

```solidity
interface IStreamEntropyView {
    function tokenSeed(uint256 tokenId)
        external
        view
        returns (bytes32 seed, bool finalized);
}
```

The router must treat entropy reads as bounded and fail-safe for minted tokens.
If the pinned `coordinatorAtMint(tokenId)` has no code, is
incident-revoked, reverts, runs out of its read gas cap, or returns malformed
data, the router reports entropy as `PENDING_UNKNOWN` and renders the
collection's pending/unknown view. It must not revert `tokenURI()` for a minted
token solely because the pinned coordinator is unhealthy. Finality diagnostics
may still report that the current entropy route no longer matches the frozen
record.

## Metadata Router Responsibilities

`StreamMetadataRouter` is responsible for answering `tokenURI()` requests and
choosing which renderer should produce the response.

The router should support three configuration scopes:

```text
default scope      applies to all collections and tokens unless overridden
collection scope   applies to all tokens in one collection unless overridden
token scope        applies to one token
```

Resolution order:

```text
token override
collection override
default config
```

Each resolved config should include:

```solidity
struct MetadataConfig {
    MetadataMode mode;
    address renderer;
    string baseURI;
    string pendingURI;
    OffchainURIIdMode offchainURIIdMode;
    bool frozen;
}
```

`MetadataMode` should be explicit:

```solidity
enum MetadataMode {
    OFFCHAIN,
    ONCHAIN,
    HYBRID
}
```

Offchain URI ID mode should also be explicit:

```solidity
enum OffchainURIIdMode {
    TOKEN_ID,
    COLLECTION_SERIAL
}
```

`TOKEN_ID` preserves the current `baseURI + tokenId` behavior.
`COLLECTION_SERIAL` supports open-ended artist series that want offchain
metadata files numbered by the stable collection-local serial.

The router should also understand token render state:

```solidity
enum TokenRenderState {
    PENDING_RANDOMNESS,
    ACTIVE,
    FROZEN,
    BURNED
}
```

For Phase 1, burned-token behavior may be limited to normal ERC-721 behavior:
`StreamCore.tokenURI()` reverts because `_requireMinted(tokenId)` fails. The
enum is still useful for renderer APIs and future explicit burned-token views.

## Renderer Responsibilities

`StreamRendererV1` should produce the actual metadata payload.

Recommended interface:

```solidity
interface IStreamRenderer {
    function rendererVersion() external pure returns (bytes32);

    function renderContextVersion() external pure returns (bytes32);

    function rendererManifest()
        external
        view
        returns (RendererManifest memory);

    function tokenURI(RenderRequest calldata request)
        external
        view
        returns (string memory);
}
```

Renderer manifests should make renderer capabilities and limits explicit:

```solidity
struct RendererManifest {
    bytes32 rendererId;
    bytes32 rendererVersion;
    bytes32 contextVersion;
    bytes32 schemaHash;
    string schemaURI;
    string manifestURI;
    bytes32 manifestHash;
    uint32 maxJSONBytes;
    uint32 maxHTMLBytes;
    bool deprecated;
}
```

Rules:

1. `rendererId` identifies the renderer family, not just one deployed address.
2. `rendererVersion` identifies the implementation version.
3. `contextVersion` identifies the `window.__STREAM_TOKEN__` contract the
   renderer promises to honor.
4. `schemaURI` and `schemaHash` identify the JSON schema emitted by the
   renderer.
5. `manifestURI` and `manifestHash` can describe richer offchain renderer
   capabilities, examples, validation rules, and supported modes.
6. Size hints are not consensus limits, but tooling should warn before
   activation when a collection can exceed them.
7. A deprecated renderer must keep serving finalized or frozen historical
   collections that pinned it, but it should not be assigned to new mutable
   collections.
8. A renderer or dependency registry referenced by any finalized manifest cannot
   be disabled, self-destructed, repointed, or incident-revoked into a
   non-serving state without a public hash-bound recovery manifest. Registries
   must track finalized references and block ordinary removal while those
   references exist.

Recommended request struct:

```solidity
struct RenderRequest {
    address core;
    uint256 tokenId;
    uint256 collectionId;
    uint256 collectionSerial;
    bytes32 tokenHash;
    TokenRenderState state;
    MetadataMode mode;
    uint8 collectionSupplyMode;
    uint8 collectionStatus;
    bytes32 viewId;
    bytes32 viewManifestHash;
    bytes32 metadataSnapshotHash;
}
```

The renderer should read large metadata fields from `StreamCollectionMetadata`,
not from Core.

The router should also expose a diagnostic status view:

```solidity
function tokenURIStatus(uint256 tokenId)
    external
    view
    returns (
        uint8 status,
        address renderer,
        bytes32 snapshotHash,
        bytes32 failureReason
    );
```

This view is for operators, indexers, and tests. It lets tooling distinguish a
missing token, pending entropy, malformed metadata, oversized renderer output,
renderer revert, dependency failure, or snapshot fallback without relying on a
marketplace to debug a reverted `tokenURI()`.

## Metadata Storage Model

Metadata storage should be separated from ERC-721 ownership. Collection-level
metadata, script manifests, dependency manifests, custom fields, artist
attestations, generalized attestations, archive receipts, snapshots, view
manifests, and metadata locks should live in the dedicated
`StreamCollectionMetadata` contract specified in
`docs/collection-metadata-contract.md`.

The router should read collection metadata from `StreamCollectionMetadata`
instead of owning this storage directly. The router remains responsible for
metadata mode resolution, renderer resolution, and final `tokenURI()` routing.

Collection metadata should use the rich typed groups specified in
`docs/collection-metadata-contract.md`: identity, people, media, URIs, rights,
display, and open custom fields. Renderers should consume those group reads
instead of relying on Core-owned strings.

Illustrative renderer-facing summary:

```solidity
struct CollectionMetadataView {
    CollectionIdentity identity;
    CollectionPeople people;
    CollectionMedia media;
    CollectionURIs uris;
    CollectionRights rights;
    CollectionDisplay display;
}
```

Token metadata:

```solidity
struct TokenMetadata {
    string nameOverride;
    string descriptionOverride;
    string tokenData;
    string imageURI;
    string animationURI;
    string externalURI;
    string backgroundColor;
    string attributesJSON;
    string propertiesJSON;
    bool frozen;
}
```

Collection scripts should remain chunked:

```solidity
mapping(uint256 collectionId => string[] scriptChunks) collectionScripts;
```

The implementation may use append, replace-at-index, and clear-and-replace
operations, subject to freeze policy. Each operation should emit an event.

## Artwork Primitive

For onchain and hybrid Stream collections, the renderer should treat the
following values as the canonical artwork primitive:

```text
collection script manifest
token hash / finalized seed
render context version
dependency manifest
media manifest
renderer manifest
```

This is the durable reconstruction bundle. A future collector, museum,
marketplace, or agent should be able to identify the script bytes, dependency
bytes, renderer family, render context, token entropy, and media references
used to produce the work.

The token JSON should expose this bundle through `properties.stream`,
`properties.media`, and `properties.provenance`, but the source of truth should
be the manifest data in `StreamCollectionMetadata` and the token facts in Core
and the entropy coordinator.

Renderer behavior:

1. The renderer should never silently substitute a different script,
   dependency, media file, or render context than the resolved manifests
   declare.
2. Hash fields should commit to canonical payload bytes whenever practical.
3. If an offchain payload cannot be fetched or verified by a consumer, the
   metadata should still reveal the intended URI and hash.
4. Renderers may support multiple output modes, but every mode must disclose
   which renderer and context version produced it.
5. The default token view should remain marketplace-friendly even when richer
   archival or exhibition views exist elsewhere.

## Default Token Metadata Schema

`StreamRendererV1` should produce a richer default JSON payload than the current
Core implementation, while preserving compatibility with common ERC-721
consumers.

Default top-level fields:

```json
{
  "name": "Collection Name #23",
  "description": "...",
  "image": "ipfs://...",
  "animation_url": "data:text/html;base64,...",
  "external_url": "https://...",
  "background_color": "FFFFFF",
  "content": {
    "mime": "text/html",
    "uri": "data:text/html;base64,..."
  },
  "attributes": [],
  "properties": {}
}
```

Field rules:

1. `name` is always emitted. The default is collection name plus
   collection-local serial number. A token-specific name override may replace it.
2. `description` is always emitted. Token-specific description overrides may
   replace collection description when configured.
3. `image` is emitted when an image URI or onchain image exists.
4. `animation_url` is emitted when the token has an interactive, video, audio,
   HTML, GLB, or other animation/media payload.
5. `external_url` should point to the canonical 6529 token page when no
   stronger collection-specific external URL exists.
6. `background_color` is optional and must be a six-character hex string without
   `#` when emitted.
7. `content` is optional. When emitted, it should identify the canonical rich
   media payload with at least `mime` and `uri`, and should mirror
   `animation_url` or another primary media field rather than inventing a
   conflicting asset.
8. `attributes` is for user-facing traits and marketplace filtering, not for
   every machine fact.
9. `properties` is for structured machine-readable metadata and Stream-native
   extensions.

The default renderer should avoid emitting empty optional top-level fields
except `attributes` and `properties`, which may safely be empty arrays/objects
for shape stability.

## Stream Properties Namespace

The renderer should include a Stream-owned namespace under `properties.stream`.
This namespace is where the protocol can be world-class without fighting
marketplace trait conventions.

Recommended default:

```json
{
  "properties": {
    "stream": {
      "schema": "stream-token-metadata-v1",
      "schema_uri": "ipfs://...",
      "schema_hash": "0x...",
      "chain_id": "1",
      "core": "0x...",
      "token_id": "123",
      "collection_id": "1",
      "collection_serial": "23",
      "collection_supply_mode": "UNCAPPED_OPEN",
      "collection_status": "ACTIVE",
      "collection_minted_ever": "23",
      "collection_max_supply": null,
      "token_hash": "0x...",
      "seed": "0x...",
      "entropy_status": "FINALIZED",
      "entropy_provider": "0x...",
      "metadata_mode": "onchain",
      "render_state": "active",
      "renderer": "0x...",
      "renderer_id": "0x...",
      "renderer_version": "STREAM_RENDERER_V1",
      "render_context_version": "STREAM_CONTEXT_V1",
      "script_hash": "0x...",
      "script_source_type": "INLINE_CHUNKS",
      "dependency_id": "0x...",
      "dependency_hash": "0x...",
      "dependency_source_type": "DEPENDENCY_REGISTRY",
      "media_manifest_hash": "0x...",
      "metadata_snapshot_hash": "0x...",
      "view_id": "MARKETPLACE",
      "view_manifest_hash": "0x..."
    }
  }
}
```

Rules:

1. Numeric identifiers should be encoded as strings in `properties.stream` to
   avoid JavaScript precision issues for large token IDs.
2. `chain_id` should be included so the same metadata object is unambiguous
   across chains.
3. `core` should identify the canonical ERC-721 contract.
4. `renderer` and `renderer_version` should identify the renderer that produced
   the JSON. `renderer_id` should identify the renderer family when available.
5. `schema` should be a stable short ID. `schema_uri` may point to a human and
   machine-readable schema document. `schema_hash` should commit to the
   canonical schema payload when the schema URI is external.
6. `render_context_version` should identify the artist-facing JavaScript
   context supplied to the work.
7. Source type fields should disclose where scripts and dependencies came from
   without requiring consumers to infer storage from a URI shape.
8. Hash fields should be omitted until known rather than emitted as zero hashes.
9. `metadata_snapshot_hash` should identify the latest published collection
   snapshot when one exists.
10. `view_id` and `view_manifest_hash` describe the current default view that
    produced this `tokenURI()` response.

Additional Stream namespaces may be introduced later:

```json
{
  "properties": {
    "stream": {},
    "media": {},
    "rights": {},
    "provenance": {},
    "cultural": {},
    "views": {},
    "extensions": {}
  }
}
```

Known namespace meanings:

1. `properties.stream` is protocol/render context.
2. `properties.media` is MIME types, dimensions, integrity hashes, and alternate
   media.
3. `properties.rights` is license, artist, estate, museum, or rights metadata.
4. `properties.provenance` is creation, dependency, script, and attestation
   provenance.
5. `properties.cultural` is ERC-6596-style context, such as institutional,
   exhibition, historical, curatorial, conservation, and scholarship metadata.
6. `properties.views` is alternate canonical view discovery, such as gallery,
   archive, print, accessibility, AR/VR, raw JSON, raw HTML, or agent-readable
   views.
7. `properties.extensions` is open-ended project-specific metadata.

## Attribute Policy

The renderer should treat `attributes` as a display and marketplace filtering
surface. It should not dump every Stream machine fact into attributes.

Recommended default behavior:

1. Include token or collection-provided artistic traits from `attributesJSON`.
2. Allow collection config to opt into protocol attributes such as
   `Collection`, `Artist`, `Renderer`, `Metadata Mode`, or `Render State`.
3. Keep hashes, addresses, dependency IDs, script hashes, and schema IDs under
   `properties`, not `attributes`, unless a collection explicitly wants them as
   visible traits.
4. Preserve numeric trait values as numbers, not strings.
5. Support `display_type` values for numbers, percentages, boosts, and dates
   where marketplaces recognize them.

This keeps rarity and trait filtering clean while still making deep metadata
available to sophisticated clients.

## Expandable Metadata Model

The metadata model should have three expansion layers:

1. Stable top-level fields that broad wallets and marketplaces already expect.
2. Stream-owned structured namespaces under `properties`.
3. Arbitrary collection or token extensions stored as raw JSON fragments or
   typed custom fields in `StreamCollectionMetadata`.

The renderer should merge extension objects deterministically:

```text
base renderer properties
collection properties extension
token properties extension
```

If two objects define the same key, token scope wins over collection scope, and
collection scope wins over default scope. The renderer should reject malformed
JSON fragments before storage where practical. If full onchain validation is too
expensive, admin tooling must validate fragments before submission and the
contract should store a fragment hash for auditability.

## Canonical View Model

`tokenURI()` should remain the default marketplace-compatible metadata view.
The router should still be able to expose references to richer canonical views
recorded by `StreamCollectionMetadata`.

Recommended view behavior:

1. The default `StreamCore.tokenURI(tokenId)` path resolves the `MARKETPLACE`
   view.
2. Alternate view manifests are included as references under `properties.views`
   when configured.
3. Alternate views should not change ERC-721 ownership, token identity, or the
   default marketplace JSON shape.
4. Future view-specific reads such as `tokenURIForView(tokenId, viewId)` or
   `tokenHTMLForView(tokenId, viewId)` can be added outside Core if product
   needs justify them.
5. The router should pass `viewId` and `viewManifestHash` into the renderer
   context so generated JSON can identify the view that produced it.
6. View manifests should be hash-committed and schema-identified before they
   are surfaced as canonical.

Examples of views:

```text
MARKETPLACE      broad wallet and marketplace compatibility
GALLERY          richer 6529 or institutional display
ARCHIVE          preservation-grade metadata and manifests
PRINT            print production and editioning context
ACCESSIBILITY    alt text, captions, transcripts, language variants
MOBILE           lightweight display
AR               spatial or augmented-reality presentation
VR               immersive presentation
RAW_JSON         canonical raw metadata document
RAW_HTML         canonical rendered HTML surface
AGENT            agent-readable schema and tool context
```

## Metadata Modes

### Offchain Mode

In offchain mode, the router returns a URI, not full JSON.

If entropy is pending:

```text
pendingURI if set
else baseURI + "pending"
```

If entropy is finalized:

```text
baseURI + tokenId when offchainURIIdMode = TOKEN_ID
baseURI + collectionSerial when offchainURIIdMode = COLLECTION_SERIAL
```

The launch implementation should support both modes. The default can remain
`TOKEN_ID` for compatibility, but ongoing subcollections such as long-running
photography series should be able to opt into `COLLECTION_SERIAL`.

### Onchain Mode

In onchain mode, the renderer returns a full metadata JSON data URI. The JSON
should be Base64-encoded:

```text
data:application/json;base64,<base64-json>
```

The JSON should include at least:

```json
{
  "name": "...",
  "description": "...",
  "image": "...",
  "animation_url": "data:text/html;base64,...",
  "external_url": "...",
  "attributes": [],
  "properties": {
    "stream": {
      "schema": "stream-token-metadata-v1"
    }
  }
}
```

The renderer may include optional media, rights, provenance, and extension
namespaces when useful:

```json
{
  "properties": {
    "media": {
      "image_mime": "image/png",
      "animation_mime": "text/html",
      "image_hash": "0x...",
      "animation_hash": "0x...",
      "media_manifest_uri": "ipfs://...",
      "media_manifest_hash": "0x...",
      "iiif_manifest_uri": "ipfs://...",
      "iiif_manifest_hash": "0x...",
      "archive_manifest_uri": "ar://...",
      "archive_manifest_hash": "0x..."
    },
    "rights": {
      "license": "...",
      "license_uri": "...",
      "artist": "...",
      "artist_address": "0x...",
      "commercial_rights_uri": "...",
      "ai_training_permission": "...",
      "derivative_rights_uri": "...",
      "print_rights_uri": "...",
      "exhibition_rights_uri": "...",
      "attribution_requirements_uri": "...",
      "estate_contact_uri": "..."
    },
    "provenance": {
      "script_hash": "0x...",
      "dependency_hash": "0x...",
      "artist_attestation_hash": "0x...",
      "curator_attestation_hash": "0x...",
      "c2pa_manifest_uri": "ipfs://...",
      "c2pa_manifest_hash": "0x...",
      "c2pa_validation_status": "...",
      "preservation_event_log_uri": "ipfs://...",
      "fixity_check_uri": "ipfs://...",
      "source_media_relationships_uri": "ipfs://...",
      "derived_media_relationships_uri": "ipfs://..."
    },
    "cultural": {
      "historical_context_uri": "ipfs://...",
      "institution_uri": "ipfs://...",
      "exhibition_uri": "ipfs://...",
      "scholarship_uri": "ipfs://..."
    },
    "views": {
      "marketplace": "ipfs://...",
      "gallery": "ipfs://...",
      "archive": "ipfs://...",
      "accessibility": "ipfs://..."
    },
    "extensions": {}
  }
}
```

### Hybrid Mode

Hybrid mode allows the collection to combine offchain and onchain assets. The
initial use cases are:

1. Offchain image with onchain animation.
2. Onchain animation with offchain supplemental JSON.
3. Onchain metadata shell with offchain media URI.

Hybrid mode should still produce deterministic `tokenURI()` output from the
current onchain configuration.

## Script Assembly

The renderer should not inject loose top-level variables as the primary API.
Instead, it should build a stable JavaScript context:

```html
<script>
window.__STREAM_TOKEN__ = {
  contract: "0x...",
  tokenId: "123",
  collectionId: "1",
  collectionSerial: "23",
  collectionSupplyMode: "UNCAPPED_OPEN",
  collectionStatus: "ACTIVE",
  hash: "0x...",
  seed: "0x...",
  entropyStatus: "FINALIZED",
  entropyProvider: "0x...",
  viewId: "MARKETPLACE",
  viewManifestHash: "0x...",
  metadataSnapshotHash: "0x...",
  tokenData: [...],
  dependencyScript: "..."
};
</script>
```

Collection scripts can then consume `window.__STREAM_TOKEN__`. This creates a
stable artist-facing API and makes future renderer versions easier to support.

`STREAM_CONTEXT_V1` is normative. The renderer must encode the context object
with the following keys and JSON-compatible value types:

```text
schema                  string  "stream-render-context-v1"
chainId                 string  decimal chain ID
contract                string  lowercase 0x address
tokenId                 string  decimal token ID
collectionId            string  decimal collection ID
collectionSerial        string  decimal collection-local serial
collectionSupplyMode    string  enum name
collectionStatus        string  enum name
hash                    string  0x bytes32 token hash or omitted while pending
seed                    string  0x bytes32 finalized seed or omitted while pending
entropyStatus           string  enum name
entropyProvider         string  lowercase 0x address or omitted
viewId                  string  canonical view ID, default MARKETPLACE
viewManifestHash        string  0x bytes32 or omitted
metadataSnapshotHash    string  0x bytes32 or omitted
rendererId              string  0x bytes32 renderer family ID
rendererVersion         string  0x bytes32 renderer version
renderContextVersion    string  "STREAM_CONTEXT_V1"
scriptHash              string  0x bytes32 or omitted
dependencyHash          string  0x bytes32 or omitted
mediaManifestHash       string  0x bytes32 or omitted
tokenData               array   parsed token data values
dependencyScript        string  exact dependency JavaScript bytes as text
```

Rules:

1. Numeric identifiers are strings to avoid JavaScript precision loss.
2. Omitted optional fields are preferable to zero hashes or placeholder
   addresses.
3. Key spelling and meaning are frozen for `STREAM_CONTEXT_V1`.
4. Additional fields may be added only under `extensions` or a new context
   version.
5. The renderer must serialize this context with JSON string escaping and place
   it on `window.__STREAM_TOKEN__` before artist script execution.
6. A frozen collection pins its render context version forever unless a
   recovery snapshot explicitly opts into a successor context for a separate
   view.
7. Context serialization should be deterministic: emit keys in the documented
   order, omit optional fields rather than emitting zero placeholders, encode
   large numeric identifiers as decimal strings, and use the same escaping rules
   used by the token metadata JSON encoder. Snapshot and view manifest hashes
   should be recomputable by third-party tools from the documented canonical
   inputs.

For compatibility with simple sketches, `StreamRendererV1` may also provide
legacy-style local variables inside the generated shell:

```js
const stream = window.__STREAM_TOKEN__;
const hash = stream.hash;
const tokenId = Number(stream.tokenId);
const tokenData = stream.tokenData;
```

The exact compatibility variables should be documented before launch and then
treated as stable for `StreamRendererV1`.

When a collection freezes renderer metadata, it pins the render context version,
renderer family, dependency manifest, and script manifest used by that
collection. Future `STREAM_CONTEXT_V2` or renderer releases may exist, but they
must not silently change frozen `StreamRendererV1` collections. Mutable
collections can opt into a newer context through explicit metadata governance
and metadata refresh events.

## Dependency Assembly

The renderer should fetch dependency scripts from `DependencyRegistry` using the
collection's dependency ID. Dependency assembly should preserve deterministic
ordering:

```solidity
for i in 0 .. dependencyScriptCount - 1:
    append dependencyRegistry.getDependencyScript(dependencyId, i)
```

The renderer should avoid making Core responsible for dependency script
concatenation. If dependency script payloads become large, the metadata layer
can later introduce a dedicated dependency resolver without touching Core.

The dependency registry address must be a metadata-router or renderer
configuration pointer governed by ADR 0004, not a hardcoded permanent address.
Frozen collections pin the dependency registry or dependency source used by
their manifest. Mutable collections may move to a successor registry only
through explicit metadata governance and refresh events.

For `ONCHAIN` mode, the generated HTML must execute dependency content from a
hash-pinned source. A mutable `libraryURI` may be emitted as source/provenance
metadata, but it must not be the executed `<script src>` if that URI can change
without changing the onchain manifest hash. The renderer should inline the
DependencyRegistry payload, an inline-chunk payload, or another source whose
manifest commits to the exact bytes being executed.

### Dependency Registry Requirements

The launch dependency registry is a versioned satellite, not an ungoverned
library bucket.

Required surface:

```solidity
function dependencyRegistryVersion() external pure returns (bytes32);
function dependencyManifest(bytes32 dependencyId)
    external
    view
    returns (
        bytes32 manifestHash,
        bytes32 payloadHash,
        uint32 chunkCount,
        bool frozen,
        bytes32 recoveryManifestHash
    );
function dependencyChunk(bytes32 dependencyId, uint32 index)
    external
    view
    returns (bytes memory);
```

Rules:

1. Dependency payloads used by finalized collections are frozen by dependency
   ID and payload hash.
2. The registry implements `IStreamFinalityComponent` or is wrapped by a
   finality adapter.
3. Incident revocation blocks new mutable assignments but cannot remove bytes
   needed by finalized collections.
4. If a dependency is malicious or broken, recovery publishes a hash-bound
   replacement route and preserves the original payload hash for archives.
5. The registry emits version, payload, freeze, deprecation, and recovery
   events included in the event catalog.

## Storage Pluralism

The metadata layer should not assume one permanent storage substrate for scripts,
dependencies, schemas, or media. Launch can use simple chunked strings for
auditability, but the interfaces should support multiple source types:

```solidity
enum PayloadSourceType {
    NONE,
    INLINE_CHUNKS,
    SSTORE2,
    ETHFS,
    DEPENDENCY_REGISTRY,
    IPFS,
    ARWEAVE,
    HTTPS,
    WEB3_CALL
}
```

Guidance:

1. Core should never care which source type a script, dependency, schema, or
   media object uses.
2. `INLINE_CHUNKS` is the preferred launch source for collection scripts because
   it is simple and auditable.
3. SSTORE2-style blob contracts can be introduced later for larger write-once
   payloads.
4. EthFS or a dependency registry can be used for shared JavaScript libraries,
   fonts, or other reusable assets.
5. IPFS, Arweave, HTTPS, and future URI types are acceptable only when paired
   with hashes or other integrity commitments where the payload matters.
6. `WEB3_CALL` leaves room for ERC-4804-style raw onchain JSON or HTML views.
7. Every non-inline source should include enough manifest data for consumers to
   know where to fetch the payload and how to verify it.
8. Launch v1 should not include an `OTHER` source type because it has no
   resolution semantics. Future source types should be added through a new enum
   value or a versioned extension module with explicit resolver rules.

## Escaping And Encoding

The new renderer should improve correctness versus current raw string
concatenation.

Required safeguards:

1. JSON string fields must be escaped.
2. JavaScript string fields must be escaped or encoded safely.
3. `attributesJSON` must either be validated as JSON before storage or treated
   as a controlled raw JSON fragment with clear admin responsibility.
4. HTML should include a charset and viewport.
5. Metadata JSON should be Base64-encoded to avoid raw URI escaping issues.

Recommended HTML shell:

```html
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <script src="..."></script>
  </head>
  <body>
    <script>window.__STREAM_TOKEN__ = ...;</script>
    <script>...</script>
  </body>
</html>
```

The implementation should keep the shell deterministic and minimal.

## Canonicalization And Size Limits

Renderer-critical hashes must be reproducible by independent tools.

Every offchain or externally resolved manifest hash should either use a typed
`HashRef` or an equivalent pair of explicit fields:

```solidity
struct HashRef {
    uint16 algorithmId;
    bytes digest;
    bytes32 canonicalizationId;
    bytes32 schemaId;
}
```

Launch defaults:

```text
algorithmId = HASH_KECCAK256
canonicalizationId = CANON_RFC8785_JCS
schemaId = the schema that defines the payload
```

Algorithm, canonicalization, and schema identifiers are part of the public
release manifest. They should be allocated from an append-only registry with
reserved governance ranges. A future algorithm, canonicalization profile, or
schema family must get a new explicit ID; existing IDs must never be reused or
retargeted.

Bare `bytes32` hashes are acceptable only for version-fixed protocol identity
hashes whose algorithm and encoding are defined in the Solidity typehash or
struct documentation. Snapshot, schema, media, archive, preservation, C2PA,
view, and extension-manifest hashes must be algorithm-tagged and
canonicalization-tagged so independent tools can verify them decades later.

Rules:

1. Onchain struct commitments use `abi.encode` with explicit field order and
   type widths.
2. Offchain JSON manifests use RFC 8785 JSON Canonicalization Scheme in launch
   v1. A future non-JCS payload must use a distinct `canonicalizationId` and
   schema ID; consumers must not infer canonicalization from a URI or file
   extension.
3. Raw JSON fragments such as `attributesJSON` and `propertiesJSON` must either
   be validated before storage or marked as admin-trusted fragments with a
   stored hash and schema.
4. Omitted fields, null fields, empty strings, and empty arrays/objects must
   have schema-defined meaning before final artwork freeze.
5. Protocol identity hashes use version-fixed `keccak256`. Preservation and
   archive hashes may be algorithm-tagged for long-term agility.
6. Each `algorithmId` must define expected digest length and validation rules.
   Malformed, empty, or oversized digests revert on write. Variable-length
   encodings such as multihash must define their own maximum byte length and
   inner algorithm validation.
7. The release manifest records the fallback JSON schema hash, router gas
   limit, returndata limit, global metadata discovery reads, and
   `ContractURIUpdated()` emitter address.

Launch v1 should enforce explicit upper bounds. Recommended hard maxima:

```text
MAX_SHORT_STRING_BYTES       1,024
MAX_URI_BYTES                2,048
MAX_LONG_TEXT_BYTES         16,384
MAX_TOKEN_DATA_BYTES        16,384
MAX_ATTRIBUTES_JSON_BYTES   65,536
MAX_PROPERTIES_JSON_BYTES   65,536
MAX_CUSTOM_FIELDS              128
MAX_SCRIPT_CHUNK_BYTES       8,192
MAX_SCRIPT_CHUNKS               32
MAX_TOTAL_ONCHAIN_SCRIPT_BYTES  24,576
MAX_BATCH_MUTATIONS             50
MAX_DEFAULT_TOKEN_URI_BYTES  24,576
MAX_ARCHIVE_VIEW_BYTES      65,536
```

These values may be adjusted before implementation, but v1 must choose and test
finite limits. Writes that exceed storage limits should revert with specific
errors. Rendering that would exceed renderer limits should fail predictably and
be caught by pre-activation tooling.

Default marketplace `tokenURI()` output must remain small enough for ordinary
wallet, marketplace, and indexer calls. Payloads that exceed
`MAX_DEFAULT_TOKEN_URI_BYTES` must use offchain, hybrid, archive, raw HTML, or
raw JSON views rather than the default `tokenURI()` path. Frozen onchain
collections should publish an assembled snapshot manifest so preservation does
not depend on every future RPC endpoint tolerating maximum-size live rendering.

## Events

The router should emit explicit events for configuration and metadata changes:

```solidity
event DefaultMetadataConfigUpdated(address indexed renderer, MetadataMode mode);
event CollectionMetadataConfigUpdated(uint256 indexed collectionId, address indexed renderer, MetadataMode mode);
event TokenMetadataConfigUpdated(uint256 indexed tokenId, address indexed renderer, MetadataMode mode);

event CollectionMetadataUpdated(uint256 indexed collectionId);
event TokenMetadataUpdated(uint256 indexed tokenId);
event CollectionScriptUpdated(uint256 indexed collectionId);
event CollectionViewMetadataUpdated(uint256 indexed collectionId, bytes32 indexed viewId);
event CollectionSnapshotMetadataUpdated(uint256 indexed collectionId, bytes32 indexed snapshotId);
event MetadataFrozen(uint8 indexed scope, uint256 indexed id);
event ContractURIUpdated();
```

The metadata system should also support ERC-4906-style events:

```solidity
event MetadataUpdate(uint256 _tokenId);
event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

interface IStreamCoreMetadataRefresh {
    function emitMetadataUpdate(uint256 tokenId, bytes32 reasonHash) external;

    function emitBatchMetadataUpdate(
        uint256 fromTokenId,
        uint256 toTokenId,
        bytes32 reasonHash
    ) external;
}
```

Because marketplaces call `tokenURI()` on `StreamCore`, there are two viable
event strategies:

1. Emit ERC-4906-style events from `StreamCore` through metadata-admin helper
   functions.
2. Emit equivalent events from `StreamMetadataRouter` and document that indexers
   should observe the router as the metadata authority.

Preferred launch approach: Core should expose restricted helper functions that
allow the metadata router to cause Core to emit ERC-4906 events. This makes the
events originate from the NFT contract that marketplaces already index.

Those helper functions must be callable only by the current `metadataRouter`
pointer stored in Core. A stale router, replacement candidate, generic metadata
admin, or collection admin must not be able to call them directly. The helper
must verify that token IDs or collection ranges are valid for the requested
refresh, enforce a reasonable batch/range limit, and emit an internal reason or
manifest hash so indexers can distinguish normal metadata refresh from
governance or recovery. The helper is not an arbitrary log-spam bridge.
Launch `MAX_REFRESH_RANGE` should be no more than 5,000 token IDs per
`BatchMetadataUpdate` helper call unless a later marketplace/indexer review
accepts a different limit.
If an accepted recovery for a finalized scope legitimately affects more than
`MAX_REFRESH_RANGE` minted tokens, the router must request chunked refreshes.
Each chunk emits a standard `BatchMetadataUpdate(from, to)` plus the
Stream-native reason/manifest event or helper input that carries the same
`reasonHash` and recovery manifest hash for that chunk. A recovery must never
emit one oversized batch range or silently skip refresh for affected minted
tokens because the collection is larger than the batch cap.

After Core collection freeze, render-affecting metadata mutations are rejected,
so the metadata router must not ask Core to emit ERC-4906 refresh events for
those rejected changes. Append-only preservation records that do not affect
rendering may emit preservation-specific events, but they should not trigger
`MetadataUpdate` or `BatchMetadataUpdate` for frozen default-tokenURI output
unless a separate explicitly versioned archive view changes.

For ERC-7572-style contract metadata, Core does not emit
`ContractURIUpdated()` in launch v1 because Core does not expose
`contractURI()`. Router-level global contract metadata updates should emit
`ContractURIUpdated()` from the router or metadata contract that exposes the
global contract metadata read. Collection-scoped contract URI updates should
emit collection-specific events from `StreamCollectionMetadata`. Because
ERC-7572 exposes one `contractURI()` without a collection argument,
collection-specific contract metadata is discovered through
`StreamCollectionMetadata.contractURI(collectionId)`, collection metadata
events, and the default token metadata's `properties.stream.collection_uri`
field.

## Freeze Policy

The metadata layer should support one-way freezes:

```text
default config freeze      optional, freezes default metadata policy
collection freeze          freezes collection metadata, scripts, renderer, mode
token freeze               freezes token-specific metadata and renderer override
```

If `StreamCore.collectionFreezeStatus(collectionId)` is true, the metadata
router should reject collection metadata changes unless a narrower token-level
exception was explicitly allowed before the collection freeze. The simplest
launch rule is:

```text
Core collection freeze freezes metadata for that collection.
```

The router may also expose its own metadata-specific freeze before Core
collection freeze, but all freeze actions must be irreversible.

Launch freeze precedence:

```text
Core collection freeze
  freezes all render-affecting metadata for that collection:
    renderer assignment
    metadata mode
    default tokenURI view
    script manifest and chunks
    dependency manifest
    render context version
    media manifest used by default tokenURI
    schema used by default tokenURI
    active artwork snapshot hash

Metadata field/group locks
  can freeze narrower non-Core surfaces before Core freeze
  cannot unfreeze or override Core collection freeze

Append-only preservation records
  may continue after Core collection freeze only if:
    the collection did not lock PRESERVATION_RECORDS,
    the record type is append-only,
    the record cannot change tokenURI, renderer output, royalties, minting, or
      ownership,
    the event and schema clearly mark it as post-finalization evidence.
```

In other words, Core collection freeze means "the artwork and default display
are final." It does not have to mean "nobody can ever append an archive receipt
or future fixity check." Any post-freeze record is evidence about the frozen
object, not a mutation of the frozen object.

## Artwork Finality

For onchain and hybrid collections, final artwork freeze is stronger than
"metadata config frozen." A collection finality action must atomically bind the
metadata contract, metadata root or snapshot, router config, renderer address,
renderer code hash, render context version, script manifest, assembled script
hash, dependency sources, media manifests, entropy coordinator/config, and any
post-freeze exceptions.

The cross-module finality action is hosted by `StreamArtworkFinalityRegistry`
as described in `docs/stream-long-term-architecture.md`:

```solidity
function finalizeCollectionArtwork(
    uint256 collectionId,
    FinalityComponentExpectation[] calldata components,
    bytes32 expectedFinalityRecordHash,
    FinalityManifestRef calldata manifest
) external;
```

The metadata router must expose discovery reads that let the finality registry
find the resolved renderer, render context, dependency source, media/source
modules, and snapshot route for the collection. Each discovered component must
either implement `IStreamFinalityComponent` directly or be represented by a
finality adapter that returns frozen state, code hash, module version, manifest
hash, and data hash.

Renderer and router rules after finality:

1. The resolved renderer for a finalized collection must keep serving that
   collection, even if deprecated for new mutable collections.
2. If a renderer is incident-revoked, frozen collections may move only to a
   hash-bound snapshot or recovery renderer named by a public recovery
   manifest. They must not silently receive "equivalent" new artwork.
3. A renderer assignment for a finalized collection must verify the original
   finality manifest or the accepted recovery manifest.
4. Finalized onchain collections should expose or publish an assembled script
   and dependency snapshot hash so independent preservation tools can reproduce
   the bytes without relying on future chunk assembly code.
5. Metadata refresh events after finality must identify whether the change is
   display-only, preservation-only, or artwork-affecting. Artwork-affecting
   changes require a new recovery manifest.
6. Core-linked finality must call the metadata router, renderer or renderer
   registry, dependency registry, collection metadata contract, and entropy
   coordinator through the shared `finalityState(collectionId)` interface
   described in `docs/stream-long-term-architecture.md`.
7. Onchain and hybrid collections cannot finalize unless the assembled script
   and dependency snapshot manifest hash has already been recorded.

Burned token behavior remains asymmetric by design: `StreamCore.tokenURI()` may
revert for burned tokens because ERC-721 ownership no longer exists, while
royalty resolution can still retain token-to-collection mapping for ERC-2981
queries. Archival burned-token metadata, if desired, should be exposed through
router or metadata read functions outside Core's ERC-721 `tokenURI()`.

## Metadata Failure Behavior

Metadata failure should be explicit and scope-aware:

1. For mutable collections, a deprecated or unhealthy renderer can be replaced
   through staged metadata governance and normal metadata refresh events.
2. For frozen collections, renderer deprecation is not a display migration by
   itself. The frozen renderer must continue serving, or the system must serve a
   hash-bound snapshot route named by the finality or recovery manifest.
3. Incident revocation prevents new assignment and mutable updates, but it
   cannot rewrite frozen collection output.
4. `tokenURI()` should fail predictably when required metadata is malformed,
   oversized, or unsupported. Pre-activation tooling should block collections
   that would hit those failures.
5. Pending-entropy metadata must disclose pending status rather than fabricate a
   seed or return final artwork.
6. Offchain mutable URIs may remain mutable only when the collection policy says
   so. Render-critical offchain payloads require hash commitments before
   artwork finality.
7. Launch Core must return a minimal documented pending/error JSON data URI for
   minted tokens when `metadataRouter == address(0)`, has no code, reverts, or
   returns malformed data. The payload includes `name`, `description`, a
   fallback `image` or empty image, and `properties.stream.error`. Core exposes
   the precise reason through `tokenURIStatus`. Core should not revert
   `tokenURI()` for minted tokens solely because the router failed.

## Admin Model

Metadata admin should use ADR 0004 governance/action roles rather than a new
unrelated owner model. Legacy selector-map `StreamAdmins` authorization is
nonconformant for launch.

Recommended permissions:

```text
setMetadataRouter              Core/global admin
setDefaultMetadataConfig       global metadata admin
setCollectionMetadataConfig    collection/global metadata admin
setTokenMetadataConfig         token/global metadata admin
updateCollectionMetadata       collection/global metadata admin
updateTokenMetadata            collection/global metadata admin
updateCollectionScript         collection/global metadata admin
freezeCollectionMetadata       collection/global metadata admin
freezeTokenMetadata            token/global metadata admin
```

Artist signing and collection freeze rules should remain compatible with the
existing artist authority model, but mutable metadata updates after artist
signature should be deliberately constrained by policy.

## Expected Core Interaction

Metadata request flow:

```text
wallet/marketplace/indexer
  calls StreamCore.tokenURI(tokenId)
    StreamCore verifies token exists
    StreamCore performs a bounded staticcall to StreamMetadataRouter.tokenURI(address(this), tokenId)
      router resolves collection ID and config
      router detects pending/active entropy state
      router returns offchain URI, pending URI, or renderer output
    StreamCore returns the string if ABI, size, and gas rules pass
    otherwise StreamCore returns the documented fallback data URI for minted tokens
```

Onchain render flow:

```text
StreamMetadataRouter
  builds RenderRequest
  calls selected renderer
    renderer reads metadata store
    renderer reads dependency registry
    renderer builds safe JSON and HTML
    renderer returns data URI
```

Metadata update flow:

```text
metadata admin
  calls router update function
    router validates authority and freeze status
    router updates metadata storage
    router emits metadata-specific event
    router asks Core to emit MetadataUpdate or BatchMetadataUpdate when useful
```

## Bytecode Impact

The scratch measurement for moving renderer/script assembly out of Core showed:

```text
Current StreamCore runtime:       23,398 bytes
Renderer/script assembly removed: 19,568 bytes
Estimated Core savings:            3,830 bytes
```

This is the strongest first modularization target because it buys meaningful
Core bytecode while improving correctness and long-term extensibility.

The final implementation will add a small metadata-router call in Core, so the
net Core savings should be slightly lower than the scratch number. The expected
net savings are still large enough to materially improve Core headroom.

## Security Considerations

1. `tokenURI()` must remain `view` and must not mutate state.
2. Renderer contracts should not be able to call privileged Core mutation
   functions.
3. Renderer selection must be permissioned and freeze-aware.
4. Malicious or broken renderers can break metadata display, so renderer
   assignments require strong admin controls.
5. Metadata string input should be treated as untrusted until escaped or encoded.
6. Raw JSON fragments such as attributes require clear validation or explicit
   admin responsibility.
7. Large scripts can make `tokenURI()` expensive or fail under RPC limits; admin
   tools should warn on size.
8. The router should avoid unbounded writes in a single transaction where
   practical.
9. The renderer should avoid external calls other than known read-only metadata
   dependencies.
10. Freezes should be one-way and easy to verify from events.

## Future Optional Modules

The following ideas are worth preserving in the architecture, but they should
not be embedded in launch Core:

1. `StreamTokenParams`: artist-approved post-mint parameters inspired by Art
   Blocks PostParams. This should define parameter types, bounds, update
   authority, lock dates, and whether parameter changes trigger metadata
   refresh events.
2. `StreamDynamicTraits`: enforceable onchain traits inspired by ERC-7496. This
   should be used only when another contract needs to read or enforce a trait,
   not for ordinary display attributes.
3. `StreamMetadataViews`: richer view-specific reads and negotiation on top of
   the launch `CollectionViewManifest` baseline, inspired by ERC-7160 and
   ERC-5773. Examples: live views, token-specific archive views, raw JSON, raw
   HTML, and renderer-selected media variants. The default `tokenURI()` view
   should remain marketplace-friendly and deterministic.
4. `StreamTokenBoundAccounts`: optional ERC-6551 integration for
   collector-added archives, exhibition history, owned editions, or
   participatory works.
5. `StreamTokenRelationships`: ERC-7401-inspired parent/child and companion
   asset relationships expressed as metadata relationships unless a future
   product explicitly needs ownership nesting.
6. `StreamCulturalContext`: ERC-6596-inspired cultural and historical metadata
   views for provenance, institutions, exhibitions, historical context,
   scholarship, and cross-collection discovery.
7. `StreamAgentMetadata`: agent-readable schemas, manifests, and tool
   descriptors inspired by ERC-8257 and Art Blocks' agent-facing docs. This
   should include schema URI/hash commitments, extension namespaces, unknown
   field handling, and parser size limits.
8. `StreamVerifiedOffchainMetadata`: optional CCIP Read or proof-backed
   metadata resolution for very large payloads when offchain data can be
   verified by hash, signature, Merkle proof, or L2 state proof.

All of these modules should consume Core and metadata-layer read interfaces.
None should require changing ERC-721 ownership, enumerable behavior, or the
base token identity model.

## Implementation Phases

### Phase 1: Router Extraction

1. Add `IStreamMetadataRouter`.
2. Add `metadataRouter` to Core.
3. Replace Core rendering body with the bounded router call and documented
   minted-token fallback behavior.
4. Move existing behavior into `StreamMetadataRouter` plus `StreamRendererV1`.
5. Preserve current offchain, pending, and onchain observable behavior unless
   the team explicitly changes it before launch.

### Phase 2: Safer Rendering

1. Base64-encode metadata JSON.
2. Add JSON string escaping.
3. Add safer JavaScript context encoding.
4. Add deterministic HTML shell.
5. Add renderer manifest and version disclosure.
6. Add schema URI/hash disclosure.
7. Add MIME-aware `content` object support.

### Phase 3: Scoped Overrides

1. Add default renderer config.
2. Add collection renderer config.
3. Add token renderer config.
4. Add explicit metadata modes.
5. Add freeze-aware assignment updates.

### Phase 4: Metadata Refresh And Tooling

1. Add Core-originated metadata refresh events.
2. Add router- or metadata-contract-originated `ContractURIUpdated()` support
   for global contract metadata changes.
3. Add admin tooling for metadata config inspection.
4. Add script, HTML, JSON, and manifest size warnings.
5. Add view manifest and snapshot inspection tooling.
6. Add tests for pending, offchain, onchain, hybrid, collection override, token
   override, and freeze behavior.

### Phase 5: Optional Metadata Modules

1. Add raw `tokenJSON(uint256)` and `tokenHTML(uint256)` reads if ERC-4804
   support becomes a product requirement.
2. Add richer alternate token views only outside the default `tokenURI()` path.
3. Add post-mint params, dynamic traits, token-bound account references, or
   agent-readable manifests only after concrete launch use cases are approved.

## Required Tests

Core tests:

1. `tokenURI()` reverts for nonexistent tokens.
2. `tokenURI()` uses the bounded router path for minted tokens and returns the
   documented fallback data URI when the router is unset, has no code, reverts,
   returns malformed ABI, or exceeds the returndata cap.
3. Router updates require admin authority.
4. Router update emits canonical `CoreSatellitePointerUpdated` and, if
   implemented, the supplementary `MetadataRouterUpdated` mirror.
5. Core still reports ERC-721 enumerable behavior.
6. Core advertises ERC-4906 support if Core-originated metadata update events
   are implemented.
7. Core does not expose `contractURI()` in launch v1.
8. The release manifest records that global contract metadata discovery lives
   on the router/metadata contract, not Core.

Router tests:

1. Default config resolves when no override exists.
2. Collection config overrides default config.
3. Token config overrides collection config.
4. Pending offchain tokens return pending URI behavior.
5. Active offchain tokens return base URI behavior.
6. Onchain tokens return Base64 JSON data URI.
7. Hybrid mode returns the configured hybrid output.
8. Frozen collection metadata cannot be changed.
9. Frozen token metadata cannot be changed.
10. Metadata update events are emitted.
11. Default, collection, and token property extensions merge deterministically.
12. Global contract metadata resolves through `contractURIForCore(address)` or
    the router/metadata contract's equivalent ERC-7572-shaped read.
13. Collection-scoped contract metadata does not accidentally change global
    contract metadata.
14. Collection view metadata updates emit a view-specific refresh event.
15. Collection snapshot updates emit a snapshot-specific refresh event.

Renderer tests:

1. Token name uses collection name and collection-local serial.
2. Description, image, and external URL are JSON-escaped.
3. Attributes are included as valid JSON.
4. HTML shell is Base64-encoded.
5. Canonical seed and token hash alias are included in the render context.
6. Token data is included in the render context.
7. Dependency scripts are assembled in order.
8. Collection script chunks are assembled in order.
9. Renderer version is stable.
10. Renderer manifest reports renderer ID, renderer version, context version,
    schema URI/hash, manifest URI/hash, and size hints.
11. Large script payloads either render successfully or fail predictably.
12. Default JSON includes `name`, `description`, `image`, `animation_url`,
    `external_url`, `attributes`, and `properties` when source data exists.
13. Default JSON includes a MIME-aware `content` object when rich media exists.
14. `properties.stream` includes stable protocol fields.
15. `properties.media` includes media manifest URI/hash and MIME fields when
    configured.
16. `properties.views` includes alternate view references when configured.
17. `properties.provenance` includes attestation and preservation references
    when configured.
18. `properties.cultural` includes institutional, exhibition, historical,
    curatorial, conservation, or scholarship references when configured.
19. `properties.stream` includes view ID, view manifest hash, and metadata
    snapshot hash when known.
20. Large numeric IDs are encoded as strings in machine-readable properties.
21. Protocol facts do not pollute `attributes` unless explicitly configured.

## Open Decisions

1. Whether `attributesJSON` should be fully validated on write or accepted as a
   trusted admin-provided raw JSON fragment.
2. Whether hybrid mode is needed at launch or should be included as a dormant
   enum value with tests only for offchain and onchain.
3. Whether protocol attributes should be opt-in by collection or enabled by
   default for all collections.
4. Whether `propertiesJSON` should be fully validated onchain or validated by
   admin tooling with a stored hash.
5. The release manifest should name the exact global metadata discovery path
   because launch v1 intentionally excludes Core `contractURI()`.
6. Whether launch enforces raw JSON fragment validation onchain or accepts
   admin-trusted fragments with stored hashes and schema IDs. The hash and
   canonicalization baseline is no longer open: use version-fixed `keccak256`
   for protocol identities, RFC 8785/JCS for hash-committed JSON manifests,
   and explicit algorithm tags for preservation hashes.

## Recommended Launch Position

For launch, implement `StreamMetadataRouter` and `StreamRendererV1` before
adding the new revenue and royalty resolver work to Core. This buys Core
bytecode headroom early and gives the team a better place to implement
marketplace-facing metadata behavior.

The launch version should support:

1. Core-native `tokenURI()` forwarding.
2. Default and collection-level metadata config.
3. Token-level config if implementation complexity remains modest.
4. Offchain and onchain modes.
5. Pending URI behavior.
6. Safe Base64 JSON output.
7. Rich default metadata fields with a `properties.stream` namespace.
8. Schema URI/hash disclosure.
9. MIME-aware `content` object support.
10. Stable JavaScript render context.
11. Renderer manifest disclosure.
12. Dependency script assembly outside Core.
13. Collection script assembly outside Core.
14. Dedicated `StreamCollectionMetadata` storage.
15. Script, dependency, and media manifests with hash commitments.
16. Stable collection-local serials for open-ended collections.
17. Configurable offchain URI ID mode: token ID or collection serial.
18. One-way collection metadata freeze.
19. ERC-4906-style metadata refresh events from Core.
20. ERC-7572-shaped global metadata reads on the router or metadata contract,
    with Core `contractURI()` intentionally omitted from launch v1.
21. View manifest references in `properties.views`.
22. Snapshot hash and view identity disclosure in `properties.stream`.
23. Optional archive, IIIF, rights-policy, cultural, preservation, C2PA, fixity,
    and provenance references in namespaced `properties` objects.
