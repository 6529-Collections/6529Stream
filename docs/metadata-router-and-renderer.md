# Metadata Router And Renderer

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md); its formerly open decisions are
resolved by [ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md)
and recorded in the `Resolved` section of
[`docs/spec-open-questions.md`](spec-open-questions.md). It is amended by
[ADR 0010](adr/0010-world-class-spec-pass.md): governed gas parameters,
renderer determinism, per-token content binding, onchain scale and the
full-view route, refresh-emitter authority, and attribution disclosure.
It is further amended by
[ADR 0011](adr/0011-world-class-pass-round-2.md): mint-time content
binding for offchain collections, renderer classes with per-version read
sets and re-render acceptance modes, the single-sourced attribution JSON
schema, mandatory event mirrors, and entropy-class disclosure. It is
further amended by
[ADR 0012](adr/0012-world-class-pass-round-3.md): the sold-token
preservation lane with a ceilinged coverage window, burned-token
full-view serving, the consolidated evolving-works extension recipe,
tokenData bytes-typing alignment, authority-class and
deployment-attestation display fields, the `ContractURIUpdated()`
caller-set pin at the hook-table home, and removal of
`ERC721Enumerable` storage from Core.

This document specifies how Stream metadata rendering and script assembly move
out of `StreamCore` into dedicated metadata contracts. 6529Stream is permanent
infrastructure for the 6529 network: the first production deployment is the
permanent system, and the requirements below are classified by permanence
class per `docs/spec-policy.md`, not by launch phase. `StreamCore` should
remain the canonical ERC-721 contract and expose `tokenURI(uint256)` as
required by ERC-721 metadata; Core carries no `ERC721Enumerable` storage —
`totalSupply()` stays, and enumeration derives from `Transfer` events
(ADR 0012 decision T10). The heavy metadata
construction logic should live outside Core. The cross-cutting 50+ year
architecture principles live in `docs/stream-long-term-architecture.md`.

## Design Summary

`StreamCore` should keep ownership, approvals, `totalSupply()`,
token-to-collection identity, mint finality, and minimal external hooks
(ADR 0012 decision T10). The new metadata layer
should own token URI routing, metadata mode selection, JSON construction, HTML
construction, script assembly, dependency assembly, renderer versioning, and
metadata refresh events.

```text
StreamCore
  - ERC-721 ownership and totalSupply()
  - token existence checks
  - token to collection identity
  - collection supply facts needed by token naming
  - minimal tokenURI forwarding
  - minimal contractURI forwarding
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
   `StreamCollectionMetadata` reads, and include Core `contractURI()` as a
   mandatory Core hook (ADR 0009 decision 4). Marketplaces resolve ERC-7572
   contract-level metadata from the ERC-721 address, so Core exposes a thin,
   bounded read that delegates to the contract-metadata satellite through
   the cached pointer policy, with the same fail-safe posture as
   `tokenURI()`. The hook is part of the Core hook budget and is covered by
   the measured Core size proof (ADR 0009 decision 2).
5. Emit ERC-4906-compatible metadata refresh events from Core whenever token
   JSON materially changes.
6. Make renderer, script, dependency, media, and schema manifests first-class,
   with URI and hash commitments for every offchain or externally resolved
   payload.
7. Design storage as plural from day one: genesis uses chunked strings for
   small scripts and SSTORE2 write-once blobs for large ones (ADR 0010
   decision 4), while the manifest interfaces can later point to EthFS,
   Arweave, IPFS, dependency registries, or other durable stores without
   touching Core.
8. Keep frontier ideas as optional modules outside protocol v1 Core: post-mint
   parameters, dynamic onchain traits, alternate token views, token-bound
   accounts, and agent-readable metadata/tooling. Owner-reactive,
   collector-configurable, and state-evolving works arrive, if ever,
   through the `DYNAMIC` renderer class and the per-version read-set
   extension mechanism of [MRR-DETERMINISM] (ADR 0011 decision R3), never
   by widening Core or the genesis renderer's read set.

## Current Implementation Baseline

This section is non-normative implementation evidence per
[`docs/spec-policy.md`](spec-policy.md); it records point-in-time as-built
state and does not weaken any requirement in this spec.

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
should retain only minimal `tokenURI()` forwarding, minimal `contractURI()`
forwarding (ADR 0009 decision 4), token existence checks,
token-to-collection facts, and Core-originated metadata refresh events.

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
2. Keep Core enumeration-free: `totalSupply()` stays, and
   `tokenOfOwnerByIndex`/`tokenByIndex` storage does not; indexers derive
   enumeration from `Transfer` events, and live enumeration reads are a
   periphery enumerator module (ADR 0012 decision T10).
3. Keep `tokenURI(uint256)` Core-native from the caller's perspective.
4. Make metadata rendering a first-class module with explicit versioning.
5. Support default, collection-level, and token-level renderer configuration.
6. Support explicit pending, offchain, and onchain metadata modes, with
   `HYBRID` reserved as a dormant enum value at genesis (ADR 0009
   decision 17).
7. Provide safer JSON and JavaScript assembly than raw string concatenation.
8. Support richer metadata schemas over time without redeploying the NFT core.
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

Production implementation requirements [MRR-CORE-TOKENURI]:

1. `metadataRouter == address(0)` returns the documented fallback JSON data URI
   for minted tokens with status `ROUTER_UNSET`.
2. A router address with no code returns the fallback with status
   `ROUTER_NO_CODE`.
3. Core calls the router through low-level `staticcall` with the current
   `METADATA_ROUTER_GAS_LIMIT` value, after a parent gas precheck that
   accounts for EIP-150's 63/64 gas forwarding rule plus a named return
   buffer, so a caller cannot pass the precheck while the router receives
   less than `METADATA_ROUTER_GAS_LIMIT`. CI must test calls just below, at,
   and above the precheck threshold, mirroring the royalty-path precheck
   tests in [`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md).
4. Core copies at most `MAX_TOKEN_URI_RETURNDATA` bytes from returndata before
   decoding. A router cannot force unbounded memory allocation.
5. Revert, malformed ABI, oversized returndata, or an empty required response
   returns the documented fallback for minted tokens. These failures must not
   make minted-token `tokenURI()` revert.
6. `_requireMinted(tokenId)` remains the only ordinary ERC-721 nonexistent-token
   revert in Core's default `tokenURI()` path.
7. The fallback payload is intentionally small and deterministic. It includes a
   name, description, optional empty image, and `properties.stream.error`.
8. The release manifest records the router gas-parameter genesis value and
   floor, returndata limit, fallback schema hash, and gas measurements for
   success, revert, malformed return, oversized return, no-code router, and
   unset router cases.

`METADATA_ROUTER_GAS_LIMIT` is a Governed Gas Parameter under the model
home,
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
[LTA-GGP] (ADR 0010 decision D1). Router gas-cap rules [MRR-ROUTER-GGP]:

1. The parameter is Core-hosted with immutable floor
   `METADATA_ROUTER_GAS_FLOOR`, set at deployment from the measured
   deepest cold read path plus margin; floor, raise/lower classes,
   Operational-layer exclusion, change events, EIP-150 live-value
   prechecks, repricing-checklist membership, and release-manifest
   recording follow [LTA-GGP] unchanged, and this document adds no
   pattern rules of its own.
2. The health probe for lowering is a recorded `tokenURI()` +
   `contractURI()` read sweep over the deepest known routes at the
   proposed value.
3. A deploy-time immutable cap is nonconformant for this Core line
   because a future opcode repricing would otherwise permanently degrade
   `tokenURI()` for every frozen collection; raising the cap is the cure
   and never touches artwork identity ([LTA-GGP] requirement 3).
4. The metadata-layer Governed Gas Parameter identifiers follow
   [LTA-GGP] definition item 5 and are recorded here as this subsystem's
   domain-table entries, mirrored in the protocol v1 GGP identifier
   table:

   | Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
   | --- | --- | --- | --- | --- | --- |
   | `GGP_METADATA_ROUTER_GAS_LIMIT` | `6529STREAM_GGP_METADATA_ROUTER_GAS_LIMIT` | 0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93 | `StreamCore` | `1` | Governed Gas Parameter identifier per [LTA-GGP]; [MRR-ROUTER-GGP] |
   | `GGP_ENTROPY_VIEW_GAS_LIMIT` | `6529STREAM_GGP_ENTROPY_VIEW_GAS_LIMIT` | 0x2bef811c095d83c93627f797c5c71bc97b747ab91fba78266f8f86513f50f5f6 | metadata router | `1` | Governed Gas Parameter identifier per [LTA-GGP]; [MRR-ENTROPY-READ] |

5. The parameter's release-manifest failure-direction class is
   `FORWARDING_CAP` ([LTA-GGP] requirement 10): it bounds the fail-safe
   `tokenURI()`/`contractURI()` routing read, raising restores metadata
   service, and it is a permissionless conditional-raise member per
   [LTA-GGP] requirement 11 (ADR 0012 decision T1). Its named probe is
   a Permanent-class probe contract ([LTA-GGP-PROBES]) executing the
   rule 2 read sweep — Core's bounded router-call frame replicated over
   the deepest known routes for pinned fixture tokens under exactly the
   probed cap, with no caller-supplied gas shaping — recording runs on
   itself and committing the measurement artifact through
   `evidenceHash`.

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
outside the v1 test envelope.

Core exposes `contractURI()` in protocol v1 as a mandatory Core hook
(ADR 0009 decision 4). Stream is a multi-collection ERC-721, and marketplaces
resolve ERC-7572 contract-level metadata from the ERC-721 address, so the
standards-correct permanent surface is a thin, bounded Core read that
delegates to the contract-metadata satellite through the cached pointer
policy. The delegated read uses the same fail-safe posture as `tokenURI()`:
a bounded staticcall with a returndata cap, returning the documented
fallback payload instead of reverting when the satellite read is unset,
code-less, reverting, oversized, or malformed. The delegated read uses the
same `METADATA_ROUTER_GAS_LIMIT` Governed Gas Parameter and the same
EIP-150 63/64 parent precheck as `tokenURI()` [MRR-CORE-TOKENURI], with CI
threshold tests just below, at, and above the precheck threshold. The hook
is part of the Core hook budget and is covered by the measured Core size
proof (ADR 0009 decision 2). The router serves the same ERC-7572-shaped
contract metadata through its own reads:

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
`StreamCollectionMetadata.contractURI(collectionId)`. The genesis release
manifest must record the Core `contractURI()` hook, its delegated read route
and fallback schema, and the Stream-native global and collection-scoped
metadata reads (ADR 0009 decision 4).

Collection discovery contract [MRR-COLLECTION-DISCOVERY]:

1. Token ID arithmetic carries no collection meaning (ADR 0009 decision 1),
   so the published machine path for per-collection identity is normative:
   `StreamCollectionCreated(collectionId, ...)` events enumerate
   collections, `tokenCollectionIdentity(tokenId)` maps any token to its
   collection and collection-local serial,
   `StreamCollectionMetadata.contractURI(collectionId)` serves
   ERC-7572-shaped per-collection metadata, and
   `properties.stream.collection_id` / `collection_serial` restate the
   mapping inside every default token JSON. Indexers must never be asked to
   infer collection membership from token ID ranges.
2. Marketplace and indexer discovery guidance: call Core `contractURI()` for
   ERC-7572 contract-level metadata, read the Core-hosted
   `streamSystemManifest()` to discover the current metadata router and
   collection metadata contract, call
   `StreamMetadataRouter.contractURIForCore(core)` for the router-served
   global Stream contract metadata, and call
   `StreamCollectionMetadata.contractURI(collectionId)` for
   collection-specific contract metadata.
3. Per-collection marketplace display is a launch condition, not an
   operational hope: the conformance matrix carries a gate requiring
   retained evidence that each artist series resolves as its own collection
   on the major marketplaces/indexers targeted at launch, using the machine
   path above as the published integration contract.
4. The remaining decision — a marketplace-native, standards-track
   collection-identity signal under sequential token IDs — is the single
   reserved open question of the spec set, tracked as OQ-X8 in
   [`docs/spec-open-questions.md`](spec-open-questions.md) (ADR 0010
   decision 11). It does not block Draft-stage work and must be resolved
   before this document reaches Final.

Core should emit an event when the router changes:

```solidity
event MetadataRouterUpdated(address indexed oldRouter, address indexed newRouter);
```

Router pointer event rules [MRR-ROUTER-EVENTS]:

1. `CoreSatellitePointerUpdated(METADATA_ROUTER, ...)` is the canonical
   governance event for router pointer history.
2. `MetadataRouterUpdated` is a required marketplace/indexer-compatibility
   mirror — optional event mirrors are banned at genesis (ADR 0011
   decision R12). It must be emitted in the same execution as the
   canonical pointer update, is tagged as a mirror of
   `CoreSatellitePointerUpdated` in the machine-readable event catalog,
   and must never be a separate update path or carry different authority
   semantics. A conformant deployment's event surface is deterministic: a
   missing mirror emission is a defect, never an implementation choice.

Core should only allow router changes through ADR 0004 governance/action roles.
Legacy selector-map `StreamAdmins` authorization is nonconformant for
production deployment. The router should be set at genesis. Router changes
must follow the shared Core Satellite Pointer Policy in
`docs/stream-long-term-architecture.md`: staged
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

The router must treat entropy reads as bounded and fail-safe for minted
tokens. Entropy read rules [MRR-ENTROPY-READ]:

1. The router calls the pinned coordinator through `staticcall` with
   `ENTROPY_VIEW_GAS_LIMIT`, a Governed Gas Parameter with immutable floor
   `ENTROPY_VIEW_GAS_FLOOR` under the model home
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-GGP] (ADR 0010 decision D1), after an EIP-150 63/64 parent
   precheck with the same threshold CI tests as the Core router call
   [MRR-CORE-TOKENURI].
2. The router copies at most `MAX_ENTROPY_VIEW_RETURNDATA = 64` bytes of
   returndata — the ABI encoding of `(bytes32 seed, bool finalized)` — and
   treats oversized or malformed returndata as a failed read.
3. If the pinned `coordinatorAtMint(tokenId)` has no code, is
   incident-revoked, reverts, runs out of `ENTROPY_VIEW_GAS_LIMIT`, or
   returns malformed data, the router reports entropy as `PENDING_UNKNOWN`
   and renders the collection's pending/unknown view. It must not revert
   `tokenURI()` for a minted token solely because the pinned coordinator is
   unhealthy. Finality diagnostics may still report that the current entropy
   route no longer matches the frozen record.
4. `PENDING_UNKNOWN` is router/renderer disposition vocabulary, not an
   `EntropyStatus` enum member. The coordinator's `EntropyStatus` vocabulary
   is owned by [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md):
   a prepared-incomplete token has no coordinator record (`NONE`, or the
   coordinator read reverts per that spec), and the router must render it as
   pending without inventing additional status values.
5. The genesis value and floor of `ENTROPY_VIEW_GAS_LIMIT`, and the
   returndata cap, are recorded in the release manifest.
6. The parameter's release-manifest failure-direction class is
   `FORWARDING_CAP` ([LTA-GGP] requirement 10): it bounds the fail-safe
   coordinator status read behind rendering (rule 3 renders
   `PENDING_UNKNOWN` instead of reverting), raising restores live
   entropy display, and it is a permissionless conditional-raise member
   per [LTA-GGP] requirement 11 (ADR 0012 decision T1). Its named probe
   is a Permanent-class probe contract ([LTA-GGP-PROBES]) executing the
   router's bounded coordinator read frame for a pinned fixture token
   corpus under exactly the probed cap, with no caller-supplied gas
   shaping, recording runs on itself and committing the measurement
   artifact through `evidenceHash`.

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

`StreamCore.tokenURI()` reverts for burned tokens because
`_requireMinted(tokenId)` fails — ordinary ERC-721 behavior — while the
genesis full-view reads keep serving the burned work's final artwork with
burned-state disclosure ([MRR-FULL-VIEW] rule 6; ADR 0012 decision T3).
The enum carries the burned disposition through renderer APIs.

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
    bytes32 rendererClass;
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
9. `rendererClass` declares the determinism class of [MRR-DETERMINISM]:
   `keccak256("STATIC")` or `keccak256("DYNAMIC")` (ADR 0011 decision R3).
   The class and the version's declared read set are pinned at renderer
   registration, immutable for that version, and disclosed through
   `properties.stream.renderer_class`.

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

Storage shape ownership [MRR-STORAGE-HOMES]:

1. The `CollectionMetadataView`, `TokenMetadata`, script manifest, script
   chunk, dependency manifest, and media manifest storage shapes are owned
   by [`docs/collection-metadata-contract.md`](collection-metadata-contract.md);
   this document cites them and must not restate the structs (ADR 0010
   decision 3).
2. Mint-time `tokenData` and its `tokenDataHash` commitment are owned by the
   Core mint ABI in
   [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   [MPA-CORE-ABI], where `tokenData` is opaque `bytes` end to end — V1
   Core stores the renderer-visible `tokenData` bytes and their hash — and the
   renderer reads the mint-time bytes from Core, not from the metadata
   contract (ADR 0010 decision 3; typing drift repaired by ADR 0012
   decision T7). `StreamCollectionMetadata` stores only token-level
   display metadata that Core deliberately does not store.
3. Script chunk mutation operations (append, replace-at-index,
   clear-and-replace, subject to freeze policy, each emitting an event) are
   specified in the collection metadata contract; the router only resolves
   and routes.

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

## Renderer Determinism

The renderer is the contract that produces the permanent artwork bytes, so
its determinism is enforced at the same rigor as the royalty resolver's
static-analysis gate, not left as guidance (ADR 0010 decision 4).

Determinism requirements [MRR-DETERMINISM]:

1. Renderer output must be a pure function of `(contract state,
   RenderRequest)`. Two calls with identical resolved inputs must return
   byte-identical output on any node, at any block, in any year.
2. A deployed renderer's `tokenURI` path, and every router `tokenURI` /
   `contractURI` code path, must not execute environment or context opcodes:
   `TIMESTAMP`, `NUMBER`, `PREVRANDAO`/`DIFFICULTY`, `BLOCKHASH`,
   `BLOBHASH`, `COINBASE`, `GASLIMIT`, `BASEFEE`, `BLOBBASEFEE`, `BALANCE`,
   `SELFBALANCE`, `ORIGIN`, and `GASPRICE`. `GAS` may be read only for the
   bounded-call prechecks specified in this document.
3. Renderer and router read paths must not perform external calls other
   than `staticcall` reads to the renderer version's registered read set.
   For `STATIC`-class renderers — the genesis default, and the only class
   deployed at genesis — the read set is exactly the pinned genesis
   allowlist: Core, `StreamCollectionMetadata` and its named companion
   satellites, the dependency registry, and the pinned entropy
   coordinator. No other external read, no `CALL` with value, no
   `DELEGATECALL`, and no `CREATE` family opcodes are permitted in these
   paths.
4. The read set is pinned per renderer version, not frozen for this Core
   line (ADR 0011 decision R3). A future renderer version accepted under
   its own renderer spec may extend its declared read set with additional
   metadata satellites and registers under the `DYNAMIC` renderer class.
   Qualification rules for a declared read target: it must be an
   append-only, hash-disciplined metadata satellite (a post-mint-parameter
   satellite, for example) whose writes are evented and record-chained,
   and it must be freeze-respecting — for a frozen or finalized scope the
   renderer must read only values pinned at or before the freeze, so
   finality still fixes output. The declared read set is frozen for that
   renderer version; extending it is a new version through the registry.
   `StreamOwnerRecords` remains excluded from every read set that serves
   the default `MARKETPLACE` view (the owner-record render firewall,
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-OWNER-RECORDS]). Collections rendered by a `DYNAMIC`-class
   renderer are excluded from the `BYTE_EXACT` re-render acceptance mode
   and must pin `PERCEPTUAL_TOLERANCE` or `CURATED_EQUIVALENCE` at
   finality ([CMC-FINALITY-INPUTS] rule 5 in the same document).
5. Rules 2 through 4 are verified by a static-analysis gate in the
   conformance matrix, mirroring the royalty-resolver and instant-entropy
   opcode gates, before any renderer version is registered; the gate runs
   against the registering version's declared read set, and a read outside
   the declared set fails registration for either class.
6. The release manifest must pin golden input/output vectors for each
   deployed renderer version: a documented set of `RenderRequest` inputs
   plus the keccak256 hash of each byte-exact output. Golden-vector
   recomputation is a deployment gate and is re-checked by every
   preservation drill, so drift in any dependency of the render path is
   detected while it is still diagnosable. `DYNAMIC`-class vectors pin the
   declared-read state alongside the `RenderRequest` so vectors stay
   reproducible.
7. Nondeterministic artist script behavior inside the browser (unseeded
   randomness, time, network) is out of consensus scope, but pre-activation
   tooling must warn when a collection script references network fetches,
   `Date`, or unseeded entropy sources, and the artist-intent record
   ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md))
   is the place to declare intended variability.

## Evolving Works Extension Recipe [MRR-EVOLVING-RECIPE]

Dynamic and evolving works — post-mint parameters, oracle-fed state,
ownership-history-reactive rendering, artist/collector co-creation — are
an enumerated extension category whose pieces exist across four
documents. This section is the one assembled recipe a future module spec
composes, in the [SSA-HOLDER]/[CMC-MEMENTO] pattern-recipe style, so a
2030 module author inherits the composition instead of reverse-engineering
it (ADR 0012 decision T6). A conformant evolving-work module supplies all
four pieces; nothing here adds a new rule — the recipe fixes the
composition of rules that already bind:

1. Renderer: a `DYNAMIC`-class renderer version registered through the
   renderer registry with its declared read set pinned at registration
   ([MRR-DETERMINISM] rules 3-5). Every declared read target must
   qualify: an append-only, hash-disciplined metadata satellite whose
   writes are evented and record-chained
   ([CMC-RECORD-CHAIN] in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)),
   and freeze-respecting — for a frozen or finalized scope the renderer
   reads only values pinned at or before the freeze, so finality still
   fixes output. The registration static-analysis gate verifies the read
   set, and golden vectors pin the declared-read state alongside each
   `RenderRequest` ([MRR-DETERMINISM] rule 6).
2. Mutable-state carrier: a post-mint-parameter satellite under its own
   accepted spec — the `StreamTokenParams` shape of Protocol v1
   Exclusions item 1 — defining parameter types, bounds, update
   authority, lock dates, and refresh-event behavior, byte-limited and
   evented. `StreamOwnerRecords` never qualifies for a default
   `MARKETPLACE` read set (the owner-record render firewall,
   [MRR-DETERMINISM] rule 4).
3. Finality acceptance mode: collections rendered by a `DYNAMIC`-class
   renderer are excluded from `BYTE_EXACT` and must pin
   `PERCEPTUAL_TOLERANCE` or `CURATED_EQUIVALENCE` at finality
   ([CMC-FINALITY-INPUTS] rule 5 in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md);
   mode vocabulary owned by [LTA-FINALITY] requirement 12 in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)).
   The finality manifest must state the allowed post-finality state —
   which declared-read values the renderer may still consume — and
   content-root leaves obey the finalized-entropy rule
   ([CMC-CONTENT-ROOT] rule 3).
4. Artist consent binding: ongoing-work co-creation mechanics are
   excluded from the genesis artist registry ([AA-EXCL] item 7 in
   [`docs/stream-artist-authority.md`](stream-artist-authority.md)), so
   the module spec must define the artist's consent surface for
   post-mint state changes — and between mint and executed finality the
   artist content veto binds every content-affecting surface regardless
   ([CMC-ARTIST-CONTENT-VETO]).

A module that omits any piece fails registration or finality under the
cited rules.

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
marketplace trait conventions. Pinned field requirements carry the anchor
[MRR-STREAM-PROPS].

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
      "citation": "eip155:1/erc721:0x.../123",
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
      "entropy_security_class": "HIGH_ASSURANCE",
      "metadata_mode": "onchain",
      "content_binding_class": "HASH_BOUND",
      "render_state": "active",
      "renderer": "0x...",
      "renderer_id": "0x...",
      "renderer_class": "STATIC",
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
11. `citation` must carry the canonical citation string for the work, in the
    format owned by the Canonical Citation Profile in
    [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
    (ADR 0010 decision 6), including the typed record-state qualifier
    prefixes when a record state is cited, so scholarly and registrar
    references converge on one blessed identifier instead of marketplace
    URLs.
12. `entropy_security_class` must be emitted for every collection with a
    recorded entropy configuration, carrying the collection's declared
    `EntropySecurityClass` name — `HIGH_ASSURANCE` or `LOW_SECURITY` — as
    owned by
    [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
    [EC-CONFIG] (ADR 0011 decision R12). The field must also appear
    in pending-state token JSON, so a collection whose instant entropy is
    manipulable is never displayed indistinguishably from a
    high-assurance work. Prose disclosure in provenance notes never
    substitutes for this pinned machine-readable field.
13. `content_binding_class` must be emitted for every collection with one
    of the pinned values `HASH_BOUND` or `SERVICE_BACKED_MUTABLE`, per the
    offchain binding rules [MRR-OFFCHAIN-BINDING] (ADR 0011 decision R2).
    `ONCHAIN` and hybrid collections are `HASH_BOUND` by construction.
14. `renderer_class` must mirror the resolved renderer version's declared
    determinism class (`STATIC` or `DYNAMIC`) from its renderer manifest
    [MRR-DETERMINISM].

Additional Stream namespaces may be introduced through separate accepted
schema versions:

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

### Attribution Disclosure

Marketplaces, wallets, and archives consume `tokenURI()`, not contract
internals, so the default JSON must distinguish artist-attested attribution
from platform-claimed attribution (ADR 0010 decision 2). The attribution
JSON schema has exactly one normative home:
[`docs/stream-artist-authority.md`](stream-artist-authority.md)
[AA-DISPLAY] (ADR 0011 decision R7). This section owns only the JSON
mechanics — path, serialization, and renderer derivation; the required
field set, state vocabulary, and semantics are cited from that home, and
the field mirror below is checker-verified against it, never a second
home.

Attribution disclosure requirements [MRR-ATTRIBUTION]:

1. Default token JSON for every collection must emit the nested
   `properties.provenance.attribution` object carrying exactly the field
   set required by [AA-DISPLAY] requirements 2, 3, and 5, together with
   the authority-class fields that home pins under ADR 0012 decision T4:
   `works_class`
   (`artist_bound` or `platform_works`) for every collection, and, for
   artist-bound collections, `state` (one of the pinned lowercase strings
   `claimed | artist_accepted | artist_sanctioned | disputed | revoked`,
   resolved for the token's scope with the [AA-DISPLAY] precedence rule),
   `artist_id`, `artist_address`, `binding_generation` (decimal string),
   `attestation_status`
   (`none | attested_current | attested_stale | disputed`, lowercase),
   `attestation_record`, `attested_state_hash`, and
   `attestation_authority_class` when an attestation exists,
   `sanction_record` and `sanction_authority_class` when a sanction
   covers the token, and the collaborator listing with role and
   verification state. The authority-class fields carry the [AA-DISPLAY]
   signing-authority vocabulary (`artist | delegate | successor |
   steward`, lowercase, in the home's order) so a steward-, successor-,
   or delegate-signed
   act is never displayed indistinguishably from the artist's own
   signature on the one surface marketplaces and archives consume
   (ADR 0012 decision T4). Flat
   `attribution_status`/`artist_attestation_status` fields and uppercase
   attestation vocabulary are nonconformant; a conformance checker row
   asserts this field mirror matches [AA-DISPLAY] and fails on drift.
2. Until the bound artist has accepted onchain, the renderer must present
   the attribution as unverified:
   `properties.provenance.attribution.state = "claimed"`, and any `Artist`
   attribute or `properties.rights.artist` value is platform assertion,
   not artist fact.
3. `attestation_status`, `attestation_record`, and `attested_state_hash`
   are derived from the staleness-aware attestation read in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   using the live subject state hash the renderer already reads. An
   attestation whose attested subject state hash no longer matches current
   collection state must be reported `attested_stale`, never silently
   presented as current.
4. Collections declared `PLATFORM_WORKS` at creation disclose
   `works_class = "platform_works"` and omit artist fields rather than
   fabricate them ([AA-DISPLAY] requirement 3); the declaration is
   immutable and must not be rendered as artist-attributed work. The
   pinned consent mode of an artist-bound collection may additionally be
   disclosed as `properties.provenance.attribution.consent_mode`, but
   `consent_mode` never substitutes for `works_class`.
5. Disputed or revoked attribution must remain visible: the renderer must
   not drop a `disputed`/`revoked` state from the default JSON while the
   dispute record stands.
6. A recorded C2PA attribution-divergence conflict for the collection or
   token ([CMC-C2PA] in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md),
   ADR 0011 decision R7) must be surfaced as
   `properties.provenance.c2pa_attribution_divergence = true` plus the
   divergence record reference; it is never silently omitted while the
   conflict record stands.
7. Address-level deployer provenance is served on the display surface by
   the artist-signed deployment attestation record family whose normative
   home is
   [`docs/stream-artist-authority.md`](stream-artist-authority.md)
   (ADR 0012 decision T9): when a deployment attestation exists for the
   collection, default token JSON must reference it as
   `properties.provenance.attribution.deployment_attestation` (the
   record hash), so a marketplace, explorer, or archive reading
   `tokenURI()` sees artist-attested deployment provenance despite the
   platform-deployed shared Core address. The field is display
   disclosure, never address identity; the per-collection facade
   question remains inside OQ-X8 ([MRR-COLLECTION-DISCOVERY]).

## Attribute Policy

The renderer should treat `attributes` as a display and marketplace filtering
surface. It should not dump every Stream machine fact into attributes.

Recommended default behavior:

1. Include token or collection-provided artistic traits from `attributesJSON`.
2. Include protocol-generated attributes such as `Collection`, `Artist`,
   `Renderer`, `Metadata Mode`, or `Render State` only when the collection
   config opts in: protocol attributes are opt-in per collection, never
   default-on (ADR 0009 decision 18).
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
collection scope wins over default scope. Protocol v1 does not validate raw
JSON fragments onchain: onchain JSON validation is rejected as
gas-prohibitive security theater (ADR 0009 decision 12). Raw fragments are
admin-trusted — operator tooling must validate them before submission, and
the contract must store a fragment hash and schema ID and emit an event for
every fragment write so the trusted payload stays auditable.

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
4. View-specific reads such as `tokenURIForView(tokenId, viewId)` or
   `tokenHTMLForView(tokenId, viewId)` can be added outside Core as
   Replaceable-layer view modules with separate accepted specs if product
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

## Full-View Serving And Reconstruction Reads

Large onchain generative works must be reconstructable from chain state by
live reads at genesis, not only by hash-committed offchain mirrors
(ADR 0010 decision 4). The default `tokenURI()` stays marketplace-sized;
this section is the documented over-cap serving story.

Full-view requirements [MRR-FULL-VIEW]:

1. The genesis router/renderer pair must expose full-view reads outside the
   default `tokenURI()` envelope:

   ```solidity
   function tokenHTML(uint256 tokenId) external view returns (string memory);
   function tokenJSON(uint256 tokenId) external view returns (string memory);
   ```

   `tokenHTML` assembles the complete executable HTML for an onchain work —
   render context, dependency payload, and collection script — from chain
   state, resolving every payload from its hash-pinned source. `tokenJSON`
   returns the canonical raw metadata document. These reads serve the
   `RAW_HTML` and `RAW_JSON` canonical views and are bounded only by node
   execution limits, not by `MAX_DEFAULT_TOKEN_URI_BYTES`.
2. The paged reconstruction path is mandatory alongside the assembled reads:
   `scriptChunk(collectionId, index)` and `dependencyChunk(dependencyId,
   index)` let any client rebuild payloads chunk by chunk when a single
   assembled read exceeds an RPC provider's response limits. The assembled
   reads and the paged path must produce byte-identical payloads, verified
   by a conformance test.
3. Payloads whose default `tokenURI()` output would exceed
   `MAX_DEFAULT_TOKEN_URI_BYTES` must serve a marketplace-sized default view
   (offchain URI or compact onchain JSON referencing the full views) and
   expose the full artwork through `tokenHTML`/`tokenJSON` plus the
   `properties.views` references. Exceeding the default cap is a serving
   decision, never a reason to leave artwork bytes off chain.
4. Frozen onchain collections must still publish the assembled snapshot
   manifest so preservation does not depend on any future RPC endpoint
   tolerating maximum-size live rendering; the full-view reads and the
   snapshot manifest are complementary, and both are conformance-gated.
5. Richer view negotiation (token-specific views, live views, programmable
   selection) remains a Replaceable extension module under a separate
   accepted spec; only the two raw full-view reads above are genesis
   requirements.
6. The full-view reads are burned-token capable, and that is a genesis
   requirement, not an option (ADR 0012 decision T3): `tokenJSON` and
   `tokenHTML` must keep serving a burned token whose retained Core
   identity mapping exists (`tokenCollectionIdentity` returns
   `mappingExists = true`, `burned = true`), assembling the final
   artwork from the retained `tokenData` bytes, manifests, and entropy
   record, with the burned state disclosed
   (`properties.stream.render_state = "burned"`). Router
   `tokenURIStatus` reports `BURNED` for such tokens rather than
   reverting. Core's ERC-721 `tokenURI()` may still revert for burned
   tokens; these reads are the required archival serving surface, and a
   conformance test renders a burned token through both reads.

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

The genesis implementation should support both modes. The default can remain
`TOKEN_ID` for compatibility, but ongoing subcollections such as long-running
photography series should be able to opt into `COLLECTION_SERIAL`.

Offchain content binding [MRR-OFFCHAIN-BINDING]:

1. An offchain URI is a locator, never a content commitment. Before any
   artwork finality at any scope — including token, release, season, and
   view scopes — an offchain-mode collection must have a recorded token
   content root covering every token in the finality scope, per the Token
   Content Root requirements in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   (ADR 0010 decision 4). Finality over `baseURI + tokenId` strings without
   per-token content hashes is nonconformant: in 2075 the chain would prove
   which URI was frozen but not which artwork it named.
2. Collection-scope finality is forbidden while any render-critical payload
   of the collection resolves through mutable transport (HTTPS, IPNS, or a
   mutable gateway path) without a recorded content hash.
3. Mutable offchain URIs remain acceptable locators for collections that
   have not reached finality, when the collection policy says so and
   tooling discloses the mutability — but the URI's mutability never
   suspends the sale-time byte commitments of rule 4 unless the collection
   declared the service-backed-mutable class of rule 5.
4. Content binding does not wait for the finality ceremony (ADR 0011
   decision R2): an `OFFCHAIN`-mode collection must record per-token
   metadata and media hash commitments — token-level `HashRef`s
   ([CMC-TOKEN-METADATA] in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md))
   or an incrementally committed token content root covering every minted
   token ([CMC-CONTENT-ROOT] in the same document) — before those tokens
   are sold. Selling unbound tokens without the rule 5 declaration is
   nonconformant, and the pre-sale conformance gate verifies coverage.
5. A collection that intends mutable, service-resolved content must
   declare the service-backed-mutable collection class at creation — the
   same HTTPS-trust class as the `src`-based shell posture [MRR-SHELL].
   The declaration is immutable, disclosed by tooling and operator UX, and
   disclosed in default token JSON as
   `properties.stream.content_binding_class = "SERVICE_BACKED_MUTABLE"`
   [MRR-STREAM-PROPS]. Declared collections are excluded from artwork
   finality at every scope while unbound; every other collection is
   `HASH_BOUND`.
6. Preservation coverage has a deadline, not a hope, and the deadline
   follows the sale, not the ceremony (ADR 0011 decision R2; ADR 0012
   decision T2). Both lanes below are monitored conformance gates: a
   missed deadline in either lane is a monitored incident with an alert,
   never a silent lapse.
   (a) Sold-token lane: for every `HASH_BOUND` `OFFCHAIN`-mode
   collection — open or closed — each sold token's render-critical
   payloads must have dual-family archive receipts, at least one from an
   `ENDOWED`-economics storage family ([LTA-ARCHIVE] requirements 2
   and 3 in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)),
   and must join the fixity program's sold-token population
   ([CMC-FIXITY-PROGRAM] rule 6 in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)),
   all within `OFFCHAIN_PRESERVATION_COVERAGE_SECONDS` of that token's
   first sale settlement — per token, or per release batch where a
   release sells together. Rule 4 binds the bytes at sale; this lane
   replicates and audits them, because a hash commitment without an
   enforced replica verifies loss instead of preventing it, and an
   uncapped open series that never reaches `CLOSED` accrues coverage
   token by token instead of never.
   (b) Close-out lane: a token content root covering the full collection
   plus dual-family archive receipts for its render-critical payloads
   must be recorded within `OFFCHAIN_PRESERVATION_COVERAGE_SECONDS` of
   the collection reaching Core status `CLOSED`.
7. `OFFCHAIN_PRESERVATION_COVERAGE_SECONDS` is a governed time parameter
   hardened in the direction that matters for a deadline (ADR 0012
   decision T2), under the same floor-and-probe discipline family as the
   [LTA-GGP] parameters: genesis value `7,776,000` seconds (90 days),
   recorded in the release manifest. It may be shortened through
   ordinary parameter governance, may be lengthened only through the
   ADR 0004 `DELAYED_LOOSENING` class, and may never exceed the
   deploy-time immutable ceiling
   `OFFCHAIN_PRESERVATION_COVERAGE_MAX_SECONDS = 15,552,000` (180 days).
   Every change emits a parameter-change event and is recorded in the
   release manifest; a release-manifest edit is never a change path, so
   the coverage window cannot be quietly hollowed out across a 50-year
   operator lineage.

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
      "attribution": {
        "state": "artist_sanctioned",
        "works_class": "artist_bound",
        "artist_id": "0x...",
        "artist_address": "0x...",
        "binding_generation": "1",
        "attestation_status": "attested_current",
        "attestation_record": "0x...",
        "attested_state_hash": "0x...",
        "attestation_authority_class": "artist",
        "sanction_record": "0x...",
        "sanction_authority_class": "artist",
        "deployment_attestation": "0x...",
        "consent_mode": "ARTIST_SIGNED_POLICY",
        "collaborators": [
          {"address": "0x...", "role": "co-artist", "state": "accepted"}
        ]
      },
      "script_hash": "0x...",
      "dependency_hash": "0x...",
      "artist_attestation_hash": "0x...",
      "curator_attestation_hash": "0x...",
      "c2pa_manifest_uri": "ipfs://...",
      "c2pa_manifest_hash": "0x...",
      "c2pa_validation_status": "VALID",
      "c2pa_validator_class": "CONFIGURED_PROVENANCE_VERIFIER",
      "c2pa_validation_report_uri": "ipfs://...",
      "c2pa_attribution_divergence": false,
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

At genesis, `HYBRID` is a dormant enum value (ADR 0009 decision 17): the
router rejects assigning `HYBRID` to any metadata config until a
hybrid-capable renderer version is registered through the renderer registry.
Genesis tests cover the offchain and onchain modes plus this dormancy
rejection. Renderers are Replaceable modules behind frozen interfaces, so
hybrid rendering arrives, if ever, as a new renderer version through the
registry without touching Core.

The dormancy carries a recorded rationale rather than an implied one:
a genesis hybrid renderer would enlarge the audited genesis render path
for a mode no launch collection requires, while mixed-media 1/1 works —
onchain scripts paired with offchain photographic or video masters — are
already expressible at genesis: `ONCHAIN` mode composes the hash-pinned
script with hash-committed offchain masters through the media manifest
(`MediaManifest` and token-level media in
[`docs/collection-metadata-contract.md`](collection-metadata-contract.md)),
and `OFFCHAIN` mode binds bytes at sale time [MRR-OFFCHAIN-BINDING].
What `HYBRID` adds is mode-level routing convenience, not a new art
capability, so it is dormant scope, not a precluded category. The
activation path is the ordinary renderer-version mechanism — the same
registry, determinism static gate, and golden-vector discipline the
Evolving Works Extension Recipe [MRR-EVOLVING-RECIPE] walks through —
and a hybrid renderer version proposal follows that recipe's
registration steps with `STATIC`-class reads.

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
  tokenData: "0x...",
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
tokenData               string  0x-prefixed lowercase hex of the exact
                                Core tokenData bytes; "0x" when empty
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
8. `tokenData` is read from Core's renderer-visible `tokenData` bytes,
   whose typing (opaque `bytes` end to end), locus, and hash binding are
   owned by the Core mint ABI in
   [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   [MRR-STORAGE-HOMES]. The renderer never parses the bytes: it emits
   them as the 0x-prefixed lowercase-hex string pinned above — `"0x"`
   for empty bytes, and the key is always emitted — and the collection
   script parses them client-side under the interpretation the
   collection's renderer/schema declares (ADR 0012 decision T7). A
   renderer that parses opaque token data into structured values is
   nonconformant: two implementations could parse the same bytes
   differently and fork the golden vectors and the frozen artwork.

For compatibility with simple sketches, `StreamRendererV1` also provides
legacy-style local variables inside the generated shell:

```js
const stream = window.__STREAM_TOKEN__;
const hash = stream.hash;
const tokenId = Number(stream.tokenId);
const tokenData = stream.tokenData;
```

`StreamRendererV1` exposes exactly these four legacy compatibility
variables — `stream`, `hash`, `tokenId`, and `tokenData` — pinned for the
renderer's life and covered by a golden test (ADR 0009 decision 13). No
variable may be silently added or removed; a different variable set is a new
renderer version.

When a collection freezes renderer metadata, it pins the render context version,
renderer family, dependency manifest, and script manifest used by that
collection. Successor `STREAM_CONTEXT_V2` or renderer releases may exist, but
they must not silently change frozen `StreamRendererV1` collections. Mutable
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
can introduce a dedicated dependency resolver, under a separate accepted spec,
without touching Core.

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

The genesis dependency registry is a versioned satellite, not an ungoverned
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
dependencies, schemas, or media. Genesis can use simple chunked strings for
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
2. `INLINE_CHUNKS` remains supported for small collection scripts because it
   is simple and auditable.
3. `SSTORE2` chunked write-once blob storage is a genesis capability, not a
   later addition (ADR 0010 decision 4): the genesis metadata contract must
   accept SSTORE2-backed script chunks so serious long-form generative works
   can be fully onchain from launch. Chunk sizes and the total script cap
   are specified in Canonicalization And Size Limits and in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md).
4. EthFS or a dependency registry can be used for shared JavaScript libraries,
   fonts, or other reusable assets.
5. IPFS, Arweave, HTTPS, and later-registered URI source types are acceptable
   only when paired with hashes or other integrity commitments where the
   payload matters.
6. `WEB3_CALL` leaves room for ERC-4804-style raw onchain JSON or HTML views.
7. Every non-inline source should include enough manifest data for consumers to
   know where to fetch the payload and how to verify it.
8. Protocol v1 should not include an `OTHER` source type because it has no
   resolution semantics. New source types should be added through a new enum
   value or a versioned extension module with explicit resolver rules, each
   under its own separate accepted spec.

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

Canonical HTML shell rules for `ONCHAIN` and hybrid modes [MRR-SHELL]:

Every executed script is inlined from a hash-pinned source; the shell
contains no external `<script src>` and no network fetch of executable
content:

```html
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
  </head>
  <body>
    <script>window.__STREAM_TOKEN__ = ...;</script>
    <script>/* inlined hash-pinned dependency payload */</script>
    <script>/* inlined hash-pinned collection script */</script>
  </body>
</html>
```

The implementation should keep the shell deterministic and minimal. A shell
that loads executable content through an external `<script src="...">` is
nonconformant for any collection that can reach artwork finality in
`ONCHAIN` or hybrid mode, because frozen artwork that loads remote code is
mutable artwork: the URI can change payloads without changing any onchain
hash. A `src`-based shell may exist only for explicitly service-backed,
non-finalizable HTTPS-trust collections, and tooling must block finality
for any collection whose shell executes non-inlined sources. This restates
the Dependency Assembly rule; the two must never diverge.

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

Protocol v1 defaults:

```text
algorithmId = HASH_KECCAK256
canonicalizationId = CANON_RFC8785_JCS
schemaId = the schema that defines the payload
```

Algorithm, canonicalization, and schema identifiers are part of the public
release manifest. They should be allocated from an append-only registry with
reserved governance ranges. A new algorithm, canonicalization profile, or
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
2. Offchain JSON manifests use RFC 8785 JSON Canonicalization Scheme in
   protocol v1. A non-JCS payload family added under a separate accepted spec
   must use a distinct `canonicalizationId` and schema ID; consumers must not
   infer canonicalization from a URI or file extension.
3. Raw JSON fragments such as `attributesJSON` and `propertiesJSON` are
   admin-trusted fragments, validated by operator tooling before submission
   and stored with a fragment hash and schema ID (ADR 0009 decision 12);
   protocol v1 performs no onchain JSON validation.
4. Omitted fields, null fields, empty strings, and empty arrays/objects must
   have schema-defined meaning before final artwork freeze.
5. Protocol identity hashes use version-fixed `keccak256`. Preservation and
   archive hashes may be algorithm-tagged for long-term agility.
6. Each `algorithmId` must define expected digest length and validation rules.
   Malformed, empty, or oversized digests revert on write. Variable-length
   encodings such as multihash must define their own maximum byte length and
   inner algorithm validation.
7. The release manifest records the fallback JSON schema hash, the genesis
   value and floor of every Governed Gas Parameter in this document
   (`METADATA_ROUTER_GAS_LIMIT`, `ENTROPY_VIEW_GAS_LIMIT`), returndata
   limits, global metadata discovery reads, and the `ContractURIUpdated()`
   emitter address.

Protocol v1 enforces explicit upper bounds. Normative v1 hard maxima
(ADR 0009 decision 14, script totals raised by ADR 0010 decision 4):

```text
MAX_SHORT_STRING_BYTES       1,024
MAX_URI_BYTES                2,048
MAX_LONG_TEXT_BYTES         16,384
MAX_TOKEN_DATA_BYTES        16,384
MAX_ATTRIBUTES_JSON_BYTES   65,536
MAX_PROPERTIES_JSON_BYTES   65,536
MAX_CUSTOM_FIELDS              128
MAX_SCRIPT_CHUNK_BYTES       8,192   (INLINE_CHUNKS storage)
MAX_SSTORE2_CHUNK_BYTES     24,576   (SSTORE2 chunk payload)
MAX_SCRIPT_CHUNKS               32
MAX_TOTAL_ONCHAIN_SCRIPT_BYTES 786,432
MAX_BATCH_MUTATIONS             50
MAX_DEFAULT_TOKEN_URI_BYTES  24,576
MAX_ARCHIVE_VIEW_BYTES      65,536
```

These values are the normative v1 limits (ADR 0009 decision 14, with
`MAX_TOTAL_ONCHAIN_SCRIPT_BYTES` raised to 786,432 — 32 SSTORE2 chunks of
24,576 bytes — by ADR 0010 decision 4), subject only to pre-deployment
measurement that pins the deployed constants in the release manifest.
Writes that exceed storage limits must revert with specific errors.
Rendering that would exceed renderer limits must fail predictably and be
caught by pre-activation tooling.

Script cap scope and over-cap posture [MRR-SCRIPT-CAP]:

1. `MAX_TOTAL_ONCHAIN_SCRIPT_BYTES` applies to the per-collection artist
   script; dependency payloads resolved through the dependency registry are
   excluded from it.
2. A work whose script exceeds the cap must launch in `OFFCHAIN` mode with
   script-manifest hash commitments and remains finalizable through the
   snapshot-manifest and token-content-root path in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md);
   it must not be silently truncated or split across pseudo-dependencies.
3. Default marketplace `tokenURI()` output must remain small enough for
   ordinary wallet, marketplace, and indexer calls. Payloads that exceed
   `MAX_DEFAULT_TOKEN_URI_BYTES` serve a marketplace-sized default view and
   expose the full artwork through the genesis full-view reads
   [MRR-FULL-VIEW] and archive/raw views; over-cap works are a serving
   decision, not an offchain fallback.
4. Frozen onchain collections must publish an assembled snapshot manifest so
   preservation does not depend on every future RPC endpoint tolerating
   maximum-size live rendering.

## Events [MRR-EVENTS]

Exactly one event exists per fact; optional mirror events are banned at
genesis under the matrix-owned event policy
([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
[LCM-EVENTS]), and every mirror relationship this document defines is
mandatory and catalog-tagged (ADR 0011 decision R12;
[MRR-ROUTER-EVENTS]).

The router should emit explicit events for configuration and metadata changes:

```solidity
event DefaultMetadataConfigUpdated(
    MetadataMode mode,
    address indexed renderer,
    string baseURI,
    string pendingURI,
    OffchainURIIdMode offchainURIIdMode,
    bool frozen,
    bytes32 configHash
);

event CollectionMetadataConfigUpdated(
    uint256 indexed collectionId,
    MetadataMode mode,
    address indexed renderer,
    string baseURI,
    string pendingURI,
    OffchainURIIdMode offchainURIIdMode,
    bool frozen,
    bytes32 configHash
);

event TokenMetadataConfigUpdated(
    uint256 indexed tokenId,
    MetadataMode mode,
    address indexed renderer,
    string baseURI,
    string pendingURI,
    OffchainURIIdMode offchainURIIdMode,
    bool frozen,
    bytes32 configHash
);

event CollectionMetadataUpdated(uint256 indexed collectionId);
event TokenMetadataUpdated(uint256 indexed tokenId);
event CollectionScriptUpdated(uint256 indexed collectionId);
event CollectionViewMetadataUpdated(uint256 indexed collectionId, bytes32 indexed viewId);
event CollectionSnapshotMetadataUpdated(uint256 indexed collectionId, bytes32 indexed snapshotId);
event MetadataFrozen(uint8 indexed scope, uint256 indexed id);
```

`ContractURIUpdated()` is declared and emitted by Core only, through the
restricted emitter path below; no router or satellite duplicate of that
fact exists (ADR 0011 decision R12).

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

Preferred v1 approach: Core should expose restricted helper functions that
allow authorized satellites to cause Core to emit ERC-4906 events. This makes
the events originate from the NFT contract that marketplaces already index.

Refresh emitter authorization [MRR-REFRESH-EMITTERS]:

1. The authorized caller set for Core's restricted
   `emitMetadataUpdate`/`emitBatchMetadataUpdate` helpers is owned by the
   Core Hook Budget table in
   [`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
   (ADR 0009 decision 5; ADR 0010 decision 10): the current metadata router,
   the artwork finality registry, and the entropy coordinator, each resolved
   from Core's own cached satellite pointers at call time. This document
   cites that home and must not narrow or extend the set. The restricted
   `ContractURIUpdated()` helper is pinned in the same hook-table home
   with its own caller set — the current metadata router, resolved from
   the cached pointer — and its own golden caller-set test; "same
   posture" prose never substitutes for the pinned set (ADR 0012
   decision T9).
2. The caller check derives from Core's satellite pointer storage, never
   from a separately mutable allowlist: a caller is authorized exactly when
   it equals the current `metadataRouter`, the current finality registry
   pointer, or the entropy coordinator authorized under the cached pointer
   policy for the affected tokens. A stale router, replacement candidate,
   generic metadata admin, or collection admin must not be able to call the
   helpers directly.
3. A golden conformance test must enumerate the exact authorized caller set
   and prove both acceptance for each authorized satellite and rejection for
   every other caller class.
4. The helper must verify that token IDs or collection ranges are valid for
   the requested refresh, enforce the batch/range limit, and emit an
   internal reason or manifest hash so indexers can distinguish normal
   metadata refresh from entropy finalization, governance, or recovery. The
   helper is not an arbitrary log-spam bridge.
Protocol v1 pins `MAX_REFRESH_RANGE = 5_000` token IDs per
`BatchMetadataUpdate` helper call (ADR 0009 decision 15), confirmed by
marketplace/indexer review evidence before deployment.
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

For ERC-7572-style contract metadata, Core exposes `contractURI()` in
protocol v1 (ADR 0009 decision 4), and the same Core-origination rationale
applies as for ERC-4906 refresh: marketplaces watch the ERC-721 contract.
Global contract metadata updates therefore cause Core to emit
`ContractURIUpdated()` through a restricted helper whose authorized
caller set is pinned — not analogized — at the Core Hook Budget table
home, [PV1-HOOKS] in
[`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
(ADR 0012 decision T9): the current metadata router only, resolved from
Core's cached satellite pointer at call time, never a separately mutable
allowlist, with a golden caller-set test proving acceptance for the
router and rejection for every other caller class alongside the ERC-4906
helper test [MRR-REFRESH-EMITTERS]. The release manifest records the
emitter address. Core is the
only `ContractURIUpdated()` emitter — a supplementary satellite mirror of
the same fact is banned at genesis (ADR 0011 decision R12).
Collection-scoped contract URI updates are a distinct fact and emit
collection-specific events from `StreamCollectionMetadata`. Because
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
router must reject every mutable collection-scoped metadata path in protocol
v1. No token-level exception may bypass Core collection freeze — absolutely
and permanently for this Core line (ADR 0009 decision 16). A later bypass
would retroactively weaken every already-frozen collection's promise, so no
successor spec for this Core line may introduce one. The v1 rule is:

```text
Core collection freeze freezes metadata for that collection.
```

The router may also expose its own metadata-specific freeze before Core
collection freeze, but all freeze actions must be irreversible.

Freeze precedence:

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
    the collection did not lock PRESERVATION_RECEIPTS
      (lock IDs are owned by the Lock Model in
      docs/collection-metadata-contract.md),
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

Final artwork freeze is stronger than "metadata config frozen" in every
metadata mode. A collection finality action must atomically bind the
metadata contract, metadata root or snapshot, token content root, router
config, renderer address, renderer code hash, render context version, script
manifest, assembled script hash, dependency sources, media manifests,
entropy coordinator/config, and any post-freeze exceptions.

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

Renderer and router rules after finality [MRR-FINALITY]:

1. The resolved renderer for a finalized collection must keep serving that
   collection, even if deprecated for new mutable collections.
2. If a renderer is incident-revoked, frozen collections may move only to a
   hash-bound snapshot or recovery renderer named by a public recovery
   manifest. They must not silently receive "equivalent" new artwork.
3. A renderer assignment for a finalized collection must verify the original
   finality manifest or the accepted recovery manifest.
4. Finalized onchain collections must expose or publish an assembled script
   and dependency snapshot hash so independent preservation tools can
   reproduce the bytes without relying on future chunk assembly code.
5. Metadata refresh events after finality must identify whether the change is
   display-only, preservation-only, or artwork-affecting. Artwork-affecting
   changes require a new recovery manifest.
6. Core-linked finality must call the metadata router, renderer or renderer
   registry, dependency registry, collection metadata contract, and entropy
   coordinator through the shared `finalityState(collectionId)` interface
   described in `docs/stream-long-term-architecture.md`.
7. Onchain and hybrid collections cannot finalize unless the assembled script
   and dependency snapshot manifest hash has already been recorded.
8. No finality at any scope, in any metadata mode — including `OFFCHAIN` —
   may execute unless a token content root covering every token in the
   finality scope has been recorded, per the Token Content Root
   requirements in
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   (ADR 0010 decision 4). Finality without per-token content binding is
   nonconformant.
9. Finality for script-based works (`ONCHAIN` and hybrid modes) requires a
   `REFERENCE_RENDER` component: hash-committed reference output captures
   for a pinned token sample or all tokens, plus an execution-environment
   manifest naming renderer version, render context version, browser/engine
   build, viewport, color space, and capture toolchain, recorded as a
   collection record before `finalizeCollectionArtwork` executes
   (ADR 0010 decision 4). The record schema — including the archived
   execution-environment artifact and the pinned per-work re-render
   acceptance mode — is owned by
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-FINALITY-INPUTS] (ADR 0011 decision R3); the acceptance-mode
   vocabulary (`BYTE_EXACT`, `PERCEPTUAL_TOLERANCE`,
   `CURATED_EQUIVALENCE`) is owned by [LTA-FINALITY] requirement 12 and
   the drill-outcome vocabulary
   (`MATCH`/`TOLERABLE_VARIANCE`/`DIVERGENT`) by [LTA-RECON]
   requirement 4, both in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md).
   Re-render verification follows the pinned acceptance mode, never an
   implied byte-equality default; `DYNAMIC`-class renderers are excluded
   from `BYTE_EXACT` [MRR-DETERMINISM]. For `OFFCHAIN` collections the
   component is optional but tooling-warned; non-script media works
   carry the media-conservation finality gate of [CMC-FINALITY-INPUTS]
   rule 12 in the same document instead, so byte fixity is never their
   only conservation surface (ADR 0012 decision T2).
10. Finality for a collection with a bound artist requires the artist
    sanction and artist-intent preconditions defined in
    [`docs/stream-artist-authority.md`](stream-artist-authority.md) and in the Artwork Finality Inputs of
    [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
    (ADR 0010 decisions 2 and 6): an `ARTIST_SANCTION` finality component
    and an `ARTIST_INTENT` record or its explicit recorded waiver. The
    router only surfaces these states; it does not own them.

Burned token behavior remains asymmetric by design: `StreamCore.tokenURI()` may
revert for burned tokens because ERC-721 ownership no longer exists, while
royalty resolution can still retain token-to-collection mapping for ERC-2981
queries. Archival burned-token metadata is served — not merely retained —
through the burned-token-capable full-view reads ([MRR-FULL-VIEW] rule 6)
outside Core's ERC-721 `tokenURI()` (ADR 0012 decision T3): a destroyed
work's appearance stays reproducible by a specified read, never by
reimplementing renderer assembly from raw storage.

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
6. Offchain mutable URIs may remain mutable only when the collection policy
   says so. Render-critical offchain payloads must have hash commitments and
   a recorded token content root before artwork finality at any scope
   [MRR-OFFCHAIN-BINDING].
7. Production Core must return a minimal documented pending/error JSON data
   URI for minted tokens when `metadataRouter == address(0)`, has no code,
   reverts, or returns malformed data. The payload includes `name`,
   `description`, a fallback `image` or empty image, and
   `properties.stream.error`. Core exposes the precise reason through
   `tokenURIStatus`. Core should not revert `tokenURI()` for minted tokens
   solely because the router failed.

## Admin Model [MRR-ADMIN]

Metadata admin should use ADR 0004 governance/action roles rather than a new
unrelated owner model. Legacy selector-map `StreamAdmins` authorization is
nonconformant for production deployment.

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

Artist identity, acceptance, attestation, consent-mode, and sanction
authority are owned by [`docs/stream-artist-authority.md`](stream-artist-authority.md) (ADR 0010
decision 2); metadata admin roles never substitute for artist authority.
Mutable metadata updates after an artist attestation must be deliberately
constrained by policy, and any render-affecting update invalidates
attestation currency per the staleness rules in
[`docs/collection-metadata-contract.md`](collection-metadata-contract.md).

Between first mint and executed finality, render-affecting router
configuration for an artist-bound collection — renderer assignment,
metadata mode, and render-context selection — is a content-affecting
surface under the artist content veto: it requires artist co-signature or
is artist-freezable per consent mode, as specified in
[`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
[CMC-ARTIST-CONTENT-VETO] (ADR 0011 decision R7). Metadata admin authority
alone cannot rewrite what a sold artist-attributed work renders.

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

This section is non-normative implementation evidence per
[`docs/spec-policy.md`](spec-policy.md); measurements are point-in-time and
superseded by the release-artifact size proofs.

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

## Protocol v1 Exclusions: Optional Extension Modules

The following ideas are worth preserving in the architecture, but they are
excluded from protocol v1 and should not be embedded in v1 Core. Each is a
candidate Replaceable-layer module, added through the frozen interfaces and
registries under its own separate accepted spec. Modules whose state must
reach rendered output (post-mint parameters, dynamic traits, token-bound
account references) qualify through the `DYNAMIC` renderer class and
declared read-set extension of [MRR-DETERMINISM] (ADR 0011 decision R3),
assembled end to end by the Evolving Works Extension Recipe
[MRR-EVOLVING-RECIPE] (ADR 0012 decision T6) — the extension path exists
at genesis, so this exclusion list precludes no art category on this
Core line:

1. `StreamTokenParams`: artist-approved post-mint parameters inspired by Art
   Blocks PostParams. This should define parameter types, bounds, update
   authority, lock dates, and whether parameter changes trigger metadata
   refresh events.
2. `StreamDynamicTraits`: enforceable onchain traits inspired by ERC-7496. This
   should be used only when another contract needs to read or enforce a trait,
   not for ordinary display attributes.
3. `StreamMetadataViews`: richer view-specific reads and negotiation on top
   of the v1 `CollectionViewManifest` baseline and the genesis full-view
   reads [MRR-FULL-VIEW], inspired by ERC-7160 and ERC-5773. Examples: live
   views, token-specific archive views, and renderer-selected media
   variants. Raw `tokenJSON`/`tokenHTML` reads are genesis surface, not part
   of this exclusion. The default `tokenURI()` view should remain
   marketplace-friendly and deterministic.
4. `StreamTokenBoundAccounts`: optional ERC-6551 integration for
   collector-added archives, exhibition history, owned editions, or
   participatory works.
5. `StreamTokenRelationships`: ERC-7401-inspired parent/child and companion
   asset relationships expressed as metadata relationships unless a separate
   accepted spec establishes a concrete product need for ownership nesting.
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
None should require changing ERC-721 ownership behavior or the base token
identity model.

## Implementation Phases

### Phase 1: Router Extraction

1. Add `IStreamMetadataRouter`.
2. Add `metadataRouter` to Core.
3. Replace Core rendering body with the bounded router call and documented
   minted-token fallback behavior.
4. Move existing behavior into `StreamMetadataRouter` plus `StreamRendererV1`.
5. Preserve current offchain, pending, and onchain observable behavior unless
   the team explicitly changes it before production deployment.

### Phase 2: Safer Rendering

1. Base64-encode metadata JSON.
2. Add JSON string escaping.
3. Add safer JavaScript context encoding.
4. Add deterministic HTML shell.
5. Add renderer manifest and version disclosure.
6. Add schema URI/hash disclosure.
7. Add MIME-aware `content` object support.
8. Add the genesis full-view reads `tokenHTML`/`tokenJSON` and verify the
   paged chunk reconstruction path against them [MRR-FULL-VIEW].
9. Pin golden render vectors and pass the renderer determinism
   static-analysis gate [MRR-DETERMINISM].

### Phase 3: Scoped Overrides

1. Add default renderer config.
2. Add collection renderer config.
3. Add token renderer config.
4. Add explicit metadata modes.
5. Add freeze-aware assignment updates.

### Phase 4: Metadata Refresh And Tooling

1. Add Core-originated metadata refresh events.
2. Add `ContractURIUpdated()` support for global contract metadata changes
   through the Core `contractURI()` hook and its restricted emitter path
   (ADR 0009 decision 4).
3. Add admin tooling for metadata config inspection.
4. Add script, HTML, JSON, and manifest size warnings.
5. Add view manifest and snapshot inspection tooling.
6. Add tests for pending, offchain, onchain, hybrid dormancy, collection
   override, token override, and freeze behavior.

### Phase 5: Optional Metadata Modules

1. Add richer alternate token views, beyond the genesis
   `tokenJSON`/`tokenHTML` full-view reads, only outside the default
   `tokenURI()` path.
2. Add post-mint params, dynamic traits, token-bound account references, or
   agent-readable manifests only after concrete use cases are approved in
   separate accepted specs.

## Required Tests

Core tests:

1. `tokenURI()` reverts for nonexistent tokens.
2. `tokenURI()` uses the bounded router path for minted tokens and returns the
   documented fallback data URI when the router is unset, has no code, reverts,
   returns malformed ABI, or exceeds the returndata cap.
3. Router updates require admin authority.
4. Router update emits canonical `CoreSatellitePointerUpdated` and the
   required `MetadataRouterUpdated` mirror in the same execution
   [MRR-ROUTER-EVENTS].
5. Core exposes `totalSupply()`, and `tokenOfOwnerByIndex`/`tokenByIndex`
   are absent from the Core interface (ADR 0012 decision T10).
6. Core advertises ERC-4906 support if Core-originated metadata update events
   are implemented.
7. Core `contractURI()` returns the delegated contract metadata through the
   bounded read path and returns the documented fallback payload when the
   delegated read is unset, code-less, reverting, oversized, or malformed.
8. The release manifest records the global contract metadata discovery path:
   the Core `contractURI()` hook plus the router/metadata contract reads.
9. EIP-150 63/64 precheck threshold tests: `tokenURI()` and `contractURI()`
   calls just below, at, and above the precheck threshold behave as
   specified [MRR-CORE-TOKENURI].
10. Governed Gas Parameter tests for `METADATA_ROUTER_GAS_LIMIT`: raise
    path, lower path with health probe, floor rejection, change event, and
    exclusion from finality identity [MRR-ROUTER-GGP].
11. The restricted ERC-4906 helper golden test enumerates the exact
    authorized caller set — metadata router, finality registry, entropy
    coordinator — and proves rejection for every other caller class
    [MRR-REFRESH-EMITTERS].
12. The restricted `ContractURIUpdated()` helper golden test enumerates
    its pinned caller set — the current metadata router, per [PV1-HOOKS]
    — proving acceptance for the router and rejection for every other
    caller class (ADR 0012 decision T9).

Router tests:

1. Default config resolves when no override exists.
2. Collection config overrides default config.
3. Token config overrides collection config.
4. Pending offchain tokens return pending URI behavior.
5. Active offchain tokens return base URI behavior.
6. Onchain tokens return Base64 JSON data URI.
7. Hybrid mode is dormant: `HYBRID` config assignment is rejected until a
   hybrid-capable renderer version is registered through the renderer
   registry.
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
16. Entropy view reads enforce `ENTROPY_VIEW_GAS_LIMIT` and the 64-byte
    returndata cap, and degrade to pending output on coordinator failure
    [MRR-ENTROPY-READ].
17. Finality gates: no finality at any scope without a recorded token
    content root; script-based finality without a `REFERENCE_RENDER`
    component is rejected [MRR-FINALITY].
18. Full-view reads `tokenHTML`/`tokenJSON` serve over-cap works, and the
    paged chunk path reproduces byte-identical payloads [MRR-FULL-VIEW].
19. Offchain binding gates: an `OFFCHAIN` collection without per-token
    content commitments and without the declared service-backed-mutable
    class fails the pre-sale conformance gate; a declared collection is
    rejected at every finality scope while unbound; the
    preservation-coverage deadline alert fires when a `HASH_BOUND`
    collection closes without full coverage, and the sold-token-lane
    alert fires when a sold token's receipts or fixity coverage miss the
    per-sale window [MRR-OFFCHAIN-BINDING].
20. Burned-token serving: `tokenJSON`/`tokenHTML` serve a burned token's
    final artwork with `properties.stream.render_state = "burned"`, and
    `tokenURIStatus` reports `BURNED` without reverting
    [MRR-FULL-VIEW].

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
22. Legacy compatibility variables are exactly `stream`, `hash`, `tokenId`,
    and `tokenData`, verified by a golden test.
23. Golden render vectors: pinned `RenderRequest` inputs reproduce the
    pinned output hashes for the deployed renderer version
    [MRR-DETERMINISM].
24. The renderer static-analysis gate rejects environment/context opcodes
    and non-allowlisted external reads in `tokenURI` paths
    [MRR-DETERMINISM].
25. The `ONCHAIN`-mode HTML shell contains no external `<script src>`;
    every executed payload is inlined from a hash-pinned source
    [MRR-SHELL].
26. The nested `properties.provenance.attribution` object renders each
    pinned state — `claimed`, `artist_accepted`, `artist_sanctioned`,
    `disputed`, `revoked` — and both works classes from the corresponding
    artist authority registry state; asserts presence of `artist_id`,
    `artist_address`, `binding_generation`, `sanction_record`,
    `sanction_authority_class`, `attestation_authority_class`, and
    `works_class` where required, with each authority class
    (`artist | delegate | successor | steward`, the [AA-DISPLAY]
    order) rendered from the
    corresponding registry authority (ADR 0012 decision T4); reports
    stale attestations as `attested_stale`; and matches the [AA-DISPLAY]
    field inventory via the checker row [MRR-ATTRIBUTION].
27. `properties.stream.citation` matches the Canonical Citation Profile
    format for the rendered token, including the typed record-state
    qualifier prefixes when a record state is cited.
28. `properties.stream.entropy_security_class` renders both
    `HIGH_ASSURANCE` and `LOW_SECURITY` declarations, in finalized and
    pending-state JSON alike [MRR-STREAM-PROPS].
29. `properties.stream.content_binding_class` and
    `properties.stream.renderer_class` render the declared collection
    binding class and the resolved renderer's determinism class
    [MRR-STREAM-PROPS].

## Resolved Decisions

Every formerly open decision in this document is resolved by
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md); the register
entries live in the `Resolved` section of
[`docs/spec-open-questions.md`](spec-open-questions.md).
[ADR 0010](adr/0010-world-class-spec-pass.md) then amends four postures in
this document: the router and entropy-view gas caps are Governed Gas
Parameters rather than deploy-time immutables (decision 1); the total
onchain script cap rises to 786,432 bytes with SSTORE2 genesis storage and
the full-view serving route (decision 4); every finality scope in every
mode requires a token content root and, for script-based works, a reference
render (decision 4); and the ERC-4906 emitter authority is the
authorized-satellite set owned by the protocol v1 hook table (decision 10).
[ADR 0011](adr/0011-world-class-pass-round-2.md) further amends five
postures: offchain collections bind content at sale time or declare the
service-backed-mutable class, with a preservation-coverage deadline
(decision R2) [MRR-OFFCHAIN-BINDING]; renderer read sets are per-version
with the `DYNAMIC` class and pinned re-render acceptance modes
(decision R3) [MRR-DETERMINISM]; the attribution JSON schema is
single-sourced from the artist authority home (decision R7)
[MRR-ATTRIBUTION]; optional event mirrors are banned (decision R12)
[MRR-ROUTER-EVENTS]; and entropy-security and content-binding classes are
pinned default token JSON fields (decisions R12 and R2)
[MRR-STREAM-PROPS].
[ADR 0012](adr/0012-world-class-pass-round-3.md) further amends seven
postures: preservation coverage follows each sold token's sale under a
ceilinged governed window (decision T2) [MRR-OFFCHAIN-BINDING]; the
full-view reads serve burned tokens (decision T3) [MRR-FULL-VIEW]; the
evolving-works extension recipe is consolidated here (decision T6)
[MRR-EVOLVING-RECIPE]; attribution JSON carries the authority-class
fields (decision T4) and the deployment-attestation reference
(decision T9) [MRR-ATTRIBUTION]; the `ContractURIUpdated()` caller set
is pinned at the hook-table home (decision T9); non-script media works
carry the media-conservation gate of the collection metadata contract
(decision T2) [MRR-FINALITY]; and Core drops `ERC721Enumerable` storage
(decision T10).
The only open decision touching this document is OQ-X8 (marketplace
collection-identity signal), reserved in the register and blocking Final,
not Draft [MRR-COLLECTION-DISCOVERY].

1. Core `contractURI()` is a mandatory Core hook: a thin, bounded delegated
   read to the contract-metadata satellite through the cached pointer
   policy, with the same fail-safe posture as `tokenURI()` and covered by
   the measured Core size proof. The release manifest names the full global
   metadata discovery path, including the Core surface (ADR 0009
   decision 4).
2. Raw JSON fragments (`attributesJSON`, `propertiesJSON`) are
   admin-trusted: validated by operator tooling before submission, stored
   with a fragment hash and schema ID, and evented; onchain JSON validation
   is rejected (ADR 0009 decision 12). The hash and canonicalization
   baseline is version-fixed `keccak256` for protocol identities, RFC
   8785/JCS for hash-committed JSON manifests, and explicit algorithm tags
   for preservation hashes.
3. `StreamRendererV1` exposes exactly four legacy compatibility variables —
   `stream`, `hash`, `tokenId`, `tokenData` — pinned for the renderer's
   life and golden-tested, with no silent additions (ADR 0009 decision 13).
4. The size and canonicalization maxima in this document are the normative
   v1 limits; pre-deployment measurement pins the deployed constants in the
   release manifest (ADR 0009 decision 14).
5. `MAX_REFRESH_RANGE = 5_000` token IDs per `BatchMetadataUpdate` helper
   call, confirmed by marketplace/indexer review evidence before deployment
   (ADR 0009 decision 15).
6. No token-level exception may bypass Core collection freeze, absolutely
   and permanently for this Core line (ADR 0009 decision 16).
7. Hybrid mode is a dormant enum value at genesis; tests cover the offchain
   and onchain modes, and hybrid arrives, if ever, as a new renderer
   version through the renderer registry (ADR 0009 decision 17).
8. Protocol-generated attributes are opt-in per collection (ADR 0009
   decision 18).
9. Token-scope metadata configuration ships in the genesis router (ADR 0009
   decision 19).

## Recommended Protocol v1 Position

For protocol v1, implement `StreamMetadataRouter` and `StreamRendererV1`
before adding the new revenue and royalty resolver work to Core. This buys
Core bytecode headroom early and gives the team a better place to implement
marketplace-facing metadata behavior.

The genesis deployment should support:

1. Core-native `tokenURI()` forwarding.
2. Default and collection-level metadata config.
3. Token-level metadata config, which ships in the genesis router
   (ADR 0009 decision 19): the resolution order,
   `TokenMetadataConfigUpdated` events, and router tests assume it.
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
    plus the mandatory Core `contractURI()` hook (ADR 0009 decision 4).
21. View manifest references in `properties.views`.
22. Snapshot hash and view identity disclosure in `properties.stream`.
23. Optional archive, IIIF, rights-policy, cultural, preservation, C2PA, fixity,
    and provenance references in namespaced `properties` objects.
24. SSTORE2-backed chunked script storage up to
    `MAX_TOTAL_ONCHAIN_SCRIPT_BYTES = 786,432` [MRR-SCRIPT-CAP].
25. Genesis full-view reads `tokenHTML`/`tokenJSON` plus paged chunk
    reconstruction [MRR-FULL-VIEW].
26. Renderer determinism gate and pinned golden render vectors
    [MRR-DETERMINISM].
27. Governed Gas Parameters with immutable floors for the router and
    entropy-view read caps [MRR-ROUTER-GGP] [MRR-ENTROPY-READ].
28. Attribution and citation disclosure in default token JSON
    [MRR-ATTRIBUTION].
29. Mint-time content binding or the declared service-backed-mutable
    class for `OFFCHAIN` collections, with the preservation-coverage
    deadline [MRR-OFFCHAIN-BINDING].
30. Entropy-security, content-binding, and renderer-class disclosure in
    default token JSON [MRR-STREAM-PROPS].
31. Burned-token serving through the full-view reads with burned-state
    disclosure [MRR-FULL-VIEW] (ADR 0012 decision T3).
