# Stream Long-Term Architecture

This document is the umbrella pre-launch target specification for making
6529Stream durable over a 50+ year contract life. It ties together the proposed
revenue, royalty, metadata, renderer, entropy, and provider specs.

Companion specs:

- `docs/revenue-splits-and-royalties.md`
- `docs/mint-policy-and-accounting.md`
- `docs/adr/0004-admin-governance.md`
- `docs/adr/0008-revenue-splits-and-royalty-resolver.md`
- `docs/launch-conformance-matrix.md`
- `docs/metadata-router-and-renderer.md`
- `docs/collection-metadata-contract.md`
- `docs/stream-entropy-coordinator.md`
- `docs/stream-entropy-providers.md`

## Design Thesis

`StreamCore` should be a small permanent ERC-721 identity root. Everything that
is likely to change over decades should live in versioned satellite contracts
with explicit registries, immutable implementation identities, evented
configuration, and one-way freeze options.

The durable boundary is:

```text
StreamCore
  - ERC-721 ownership, approvals, enumerable supply, burn/mint facts
  - token ID to collection ID truth
  - Core-native ERC-2981 surface
  - tokenURI public surface
  - minimal pointers to approved satellites
  - one-way Core-level freeze hooks where product promises require them

Satellite contracts
  - revenue resolver and split wallets
  - metadata router, renderer, and collection metadata storage
  - entropy coordinator and provider adapters
  - future modules for views, token params, dynamic traits, cultural context,
    preservation records, alternate renderers, and new standards
```

The system should be easy to extend without forcing collectors, marketplaces,
or future engineers to understand a mutable black box. Every important choice
must be readable onchain, reconstructable from events, and bound to explicit
version or manifest hashes.

## Long-Term Principles

1. Keep Core permanent, small, and boring.
2. Keep `ERC721Enumerable` in Core.
3. Keep Core-native ERC-2981 in Core, but put mutable royalty policy in a
   resolver.
4. Keep marketplace-facing surfaces stable: `ownerOf`, `tokenURI`,
   `royaltyInfo`, `supportsInterface`, transfer, approval, and enumerable
   reads.
5. Keep mutable economic, rendering, and entropy policy out of Core.
6. Prefer immutable profiles, immutable implementation versions, and mutable
   assignments over mutable internals.
7. Prefer explicit versioned registries over proxies as the default upgrade
   pattern.
8. Prefer pull accounting over push payments.
9. Prefer typed status over sentinel values.
10. Prefer `bytes32` identifiers and hashes for protocol identity, with
    optional metadata for human-readable names.
11. Prefer `abi.encode` with domains and explicit versions for every durable
    hash.
12. Prefer predeclared fallback policies over ad hoc admin discretion after
    partial outcomes are visible.
13. Prefer one-way freeze controls where the product promise says a policy is
    permanent.
14. Keep all important policies inspectable without relying on private storage
    layout or offchain operator memory.
15. Treat standards, marketplaces, randomness providers, and storage systems as
    replaceable over decades.

## Core Minimalism

Core should own only facts that define the NFT:

- token existence;
- owner and approvals;
- enumerable global and per-owner state;
- collection ID for a token;
- collection-local serial when needed for names and open-ended collections;
- mint/burn audit facts;
- minimal pointers to current satellite contracts;
- minimal ERC-2981 fallback behavior.

Core should not own:

- split recipient lists;
- primary-sale revenue policy;
- mutable royalty assignment policy;
- metadata JSON or HTML assembly;
- collection script storage;
- dependency assembly;
- entropy provider callback handling;
- large event/recovery state machines;
- future optional display or agent metadata modules.

If Core bytecode becomes tight, the rule is not "drop Core-native ERC-2981" or
"drop enumerable." The rule is: move non-essential rendering, collection
metadata, entropy coordination, and other mutable policy out of Core until the
permanent surfaces fit with headroom.

## Satellite Versioning

Every satellite family should have a stable version and manifest surface:

```solidity
function moduleType() external pure returns (bytes32);
function moduleVersion() external pure returns (bytes32);
function moduleInterfaceId() external pure returns (bytes4);
function implementationCodeHash() external view returns (bytes32);
function deploymentManifestHash() external view returns (bytes32);
function moduleManifest() external view returns (string memory uri, bytes32 hash);
```

Recommended module type examples:

```text
STREAM_REVENUE_RESOLVER
STREAM_SPLIT_FACTORY
STREAM_SPLIT_WALLET
STREAM_METADATA_ROUTER
STREAM_RENDERER
STREAM_COLLECTION_METADATA
STREAM_ENTROPY_COORDINATOR
STREAM_ENTROPY_PROVIDER
```

Implementation contracts should expose enough immutable or read-only facts for
tools to prove which version is active. Factories and registries should bind
deterministic IDs to init code hash, runtime code hash, schema version,
interface ID, manifest hash, deployment manifest hash, chain ID, and factory
address.

## Registry Pattern

Use registries for replaceable modules, but keep registry authority narrow.

Registry responsibilities:

1. Approve or deprecate implementation families.
2. Track code hashes and version manifests.
3. Emit reasoned lifecycle events.
4. Prevent unknown modules from being assigned to mutable scopes.
5. Allow deprecated modules to keep serving already-frozen or already-assigned
   scopes when safe.
6. Provide incident revocation when an implementation is unsafe, with a
   documented recovery path.

Registry states:

```text
UNKNOWN             rejected
ACTIVE              allowed for new assignments
DEPRECATED          no new assignments, existing uses may continue
INCIDENT_REVOKED    no new use, and normal use may be blocked pending recovery
```

Incident revocation must not imply admin sweep rights, hidden migration, or
silent policy substitution. It should freeze the affected surface until an
accepted recovery or successor path is published.

Canonical launch registry surface:

```solidity
enum ModuleRegistryStatus {
    UNKNOWN,
    ACTIVE,
    DEPRECATED,
    INCIDENT_REVOKED
}

struct StreamModuleRecord {
    ModuleRegistryStatus status;
    bytes32 moduleType;
    bytes32 moduleVersion;
    bytes4 interfaceId;
    bytes32 runtimeCodeHash;
    bytes32 deploymentManifestHash;
    bytes32 moduleManifestHash;
    string moduleManifestURI;
    uint64 registeredAt;
    uint64 statusUpdatedAt;
}

interface IStreamModuleRegistry {
    function moduleRecord(address module)
        external
        view
        returns (StreamModuleRecord memory);

    function isModuleEligible(
        address module,
        bytes32 expectedModuleType,
        bytes4 expectedInterfaceId
    ) external view returns (bool);

    function moduleRegistryManifest()
        external
        view
        returns (bytes32 manifestHash, string memory manifestURI);
}

event StreamModuleRegistered(
    uint16 schemaVersion,
    address indexed module,
    bytes32 indexed moduleType,
    bytes4 indexed interfaceId,
    bytes32 moduleVersion,
    bytes32 runtimeCodeHash,
    bytes32 deploymentManifestHash,
    bytes32 moduleManifestHash,
    string moduleManifestURI
);

event StreamModuleStatusChanged(
    uint16 schemaVersion,
    address indexed module,
    bytes32 indexed moduleType,
    ModuleRegistryStatus status,
    bytes32 reasonHash,
    string reasonURI
);
```

Every launch pointer assignment, module registry check, and frozen-route
compatibility check must name the registry that supplied eligibility. A pointer
cannot be considered inspectable if tools can read only the target address and
must guess which registry, module type, interface, or manifest made that target
valid.
If a module registry itself becomes obsolete, unsupported, or unusable while
governance still functions, replacing it is a delayed pointer/governance action
with old/new registry manifests and a compatibility-matrix snapshot. Existing
Core pointer reads keep returning the cached registry status observed at their
last update until each pointer is revalidated against the successor registry.
If governance is lost before registry replacement, no hidden registry override
exists; mutable assignments halt and read-only/degraded mode continues from
cached pointer facts and frozen manifests.

## Core Satellite Pointer Policy

The Core pointers to satellites are protocol-critical. A mutable resolver,
metadata router, collection metadata contract, or entropy coordinator can
redirect royalties, alter metadata, reinterpret randomness state, or change the
meaning of a freeze. Pointer changes therefore need their own shared policy.

Core satellite pointer families:

```text
ROYALTY_RESOLVER
METADATA_ROUTER
COLLECTION_METADATA
ENTROPY_COORDINATOR
MINT_MANAGER
MINT_LEDGER
STREAM_ADMINS_OR_GOVERNANCE
ARTWORK_FINALITY_REGISTRY
SYSTEM_MANIFEST
```

Required pointer lifecycle:

1. New pointer targets must be approved by the relevant registry before they
   can be staged.
2. Staging uses the canonical ADR 0004 governance action ID. Pointer-specific
   fields are encoded into `callHash` and the pointer manifest hash; this
   document does not define a second pointer operation preimage.

3. Every staged operation emits old target, new target, code hash, manifest
   hash, earliest execution time, actor, indexed action ID, and reason URI/hash.
4. A staged operation can be cancelled before execution by the appropriate
   governance role.
5. Execution rechecks registry eligibility, code hash, manifest hash, and
   operation ID.
6. Emergency bypass is allowed only for incident response and must be limited to
   moving from an incident-revoked target to a pre-approved compatible target
   or to a safe read-only fallback. It must not redirect owed funds or final
   artwork arbitrarily.
   For `ENTROPY_COORDINATOR`, the pre-approved compatible target must be
   write-capable because mint registration is required; there is no read-only
   entropy fallback for live minting.
7. Pointer freezes are one-way. A frozen pointer cannot be changed except
   through a future Core successor declaration; do not add a hidden unfreeze.
8. Frozen collections and tokens keep using the module identity captured in
   their freeze/finality manifest unless the manifest explicitly points to an
   accepted recovery route.
9. Pointer changes must not alter already-finalized entropy seeds, already
   created split profiles, already credited escrow, or frozen artwork
   manifests.
10. Pointer replacement for metadata routers, renderers, collection metadata,
    dependency sources, or entropy coordinators is blocked while any frozen or
    finalized collection depends on the old target unless one of these is true:
    the collection is address-pinned and keeps reading the old target; the new
    target proves it supports the exact frozen route/snapshot; or an executed
    recovery manifest explicitly supersedes the frozen route.

Frozen-route compatibility is reported through a small read:

```solidity
interface IStreamFrozenRouteAwareModule {
    function supportsFrozenRoute(
        uint256 collectionId,
        bytes32 finalityRecordHash,
        bytes32 frozenRouteHash
    ) external view returns (bool);
}

interface IStreamFrozenRouteRegistry {
    function frozenRoute(bytes32 routeType, uint256 collectionId)
        external
        view
        returns (
            bool pinned,
            address module,
            bytes32 routeHash,
            bytes32 finalityRecordHash
        );
}

event FrozenRoutePinned(
    uint16 schemaVersion,
    bytes32 indexed routeType,
    uint256 indexed collectionId,
    address indexed module,
    bytes32 routeHash,
    bytes32 finalityRecordHash
);
```

Launch routing model: Core stays small and calls the current global
`METADATA_ROUTER`. The metadata router, not Core, owns collection-level frozen
route dispatch. A replacement global router is launch-conformant only if it can
serve or delegate every pinned frozen route reported by the frozen route
registry, or if an executed recovery manifest supersedes that route. Core does
not add arbitrary per-collection router pointers in v1.

Required events:

```solidity
event CoreSatellitePointerStaged(
    uint16 schemaVersion,
    bytes32 indexed pointerType,
    bytes32 indexed actionId,
    address indexed newTarget,
    address oldTarget,
    bytes32 newTargetCodeHash,
    bytes32 newTargetManifestHash,
    uint64 notBefore,
    bytes32 reasonHash,
    string reasonURI
);

event CoreSatellitePointerUpdated(
    uint16 schemaVersion,
    bytes32 indexed pointerType,
    bytes32 indexed actionId,
    address indexed newTarget,
    address oldTarget
);

event CoreSatellitePointerFrozen(
    uint16 schemaVersion,
    bytes32 indexed pointerType,
    bytes32 indexed actionId,
    address target,
    bytes32 manifestHash
);
```

Core must expose a required pointer read interface from launch:

```solidity
interface IStreamCorePointerView {
    function getSatellitePointer(bytes32 pointerType)
        external
        view
        returns (
            address target,
            bytes32 codeHash,
            bool frozen,
            bytes32 moduleType,
            bytes4 interfaceId,
            address registry,
            ModuleRegistryStatus registryStatus,
            bytes32 moduleManifestHash,
            bytes32 deploymentManifestHash
        );
}
```

Finality discovery, the system manifest, monitoring, and indexers depend on
this interface rather than individual public variable getter names. Core must
not call the registry from this read. `registryStatus` is the cached status
observed and stored during the latest successful pointer scheduling/execution
recheck. If tools need the live registry status, they should call the registry
directly with their own gas policy and compare it with Core's cached value.

## Token Identity Model

Protocol correctness must not depend on heuristic token ID range guesses.

Normative v1 rule:

1. Core stores an explicit `tokenId -> collectionId` mapping for every minted,
   same-transaction allocated, or burned token whose collection identity is
   authoritative.
2. Core stores or exposes an explicit collection-local serial for every minted
   token.
3. Namespaced token ID ranges may remain an allocation optimization, but they
   are not authority for royalty, metadata, revenue, entropy, or freeze
   resolution.
4. Launch v1 does not need a standalone premint reservation API. Premint or
   nonexistent token IDs without an authoritative same-transaction allocation
   mapping are unmapped. They may use default royalty behavior or zero, but
   must not be assigned to a collection from a range heuristic.
5. Burned tokens retain their last authoritative collection mapping for royalty
   disclosure and audit history. Burning removes ERC-721 ownership and
   enumerable membership, but it must not clear `tokenCollectionId`,
   `tokenCollectionSerial`, or `tokenCollectionMappingExists`. `royaltyInfo()`
   therefore continues to resolve token, collection, then default scope for a
   burned token, while `tokenURI()` may still revert because the token no
   longer exists for ERC-721 metadata purposes.
6. Token-level revenue, royalty, metadata, and entropy assignments require an
   authoritative minted or same-transaction allocated token-to-collection
   mapping. They cannot be created for unknown token IDs.
7. Inherited collection freezes apply to token-level assignments through this
   authoritative mapping. No token override can escape an inherited freeze by
   being created before the mapping exists.
8. Launch Core should preserve the current conservative burn posture: a frozen
   or artwork-finalized collection is non-burnable unless its pre-freeze policy
   and finality manifest explicitly preserve a burn path and prove that burning
   cannot change the promised artwork, supply semantics, entropy interpretation,
   or revenue/royalty history. If that explicit policy is absent, burn attempts
   for frozen collections revert.

This rule resolves the long-term model even if the implementation continues to
allocate token IDs from collection ranges.

Canonical Core read surface:

```solidity
enum StreamTokenLifecycle {
    UNKNOWN,
    PREPARED_INCOMPLETE,
    MINTED,
    BURNED
}

interface IStreamCoreTokenIdentityView {
    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (
            bool mappingExists,
            uint256 collectionId,
            uint256 collectionSerial,
            bool burned
        );

    function tokenLifecycle(uint256 tokenId)
        external
        view
        returns (uint8 lifecycle);

    function coordinatorAtMint(uint256 tokenId)
        external
        view
        returns (address);
}
```

`mappingExists` is the public read equivalent of
`tokenCollectionMappingExists[tokenId]`. For a currently minted token, the
function returns `(true, collectionId, collectionSerial, false)`. For a burned
token that was once minted, it returns
`(true, lastCollectionId, lastCollectionSerial, true)`. For a premint,
nonexistent, or otherwise unmapped token, it returns `(false, 0, 0, false)`.
Royalties, metadata routing, finality components, indexers, and archival tools
should use this read surface rather than private mapping names, historical
`origin/main` helper names, or token ID range inference.
Prepared-incomplete tokens have authoritative identity for the manager-owned
operation but are not ordinary minted ERC-721 tokens. Satellites that can be
called during `PREPARED_MINT` must check `tokenLifecycle(tokenId)` and reject
or render provisional state as their spec requires.
The cross-contract ABI returns `uint8`; the numeric values are pinned in the
Numeric ID Catalog as `UNKNOWN = 0`, `PREPARED_INCOMPLETE = 1`, `MINTED = 2`,
and `BURNED = 3`.

## Assignment Hierarchy

Default, collection, and token scope should be consistent across revenue,
royalties, metadata, and entropy:

```text
token override
collection override
contract default
zero / disabled / pending fallback
```

Rules:

1. Resolution order must be explicit and tested.
2. A scope can be mutable, exactly frozen, inherited-frozen, or globally frozen.
3. A lower-scope override should not silently escape an inherited freeze unless
   the higher-scope freeze explicitly preserves existing descendants.
4. Set, clear, freeze, and recovery events must include scope, scope ID,
   module/version identity, previous value, new value, and actor.
5. Token-level assignments must be possible only when token identity is known
   before the relevant external effects.
6. Open-ended collections must not require final supply knowledge for revenue,
   royalty, metadata, or entropy policy.

## Freeze Model

A 50-year contract needs both flexibility and finality. The system should use
explicit freeze semantics instead of relying on social promises.

Freeze modes:

```text
NONE        mutable subject to governance
EXACT       freezes only the exact default/collection/token key
INHERITED   freezes the exact key and blocks lower-scope changes
GLOBAL      freezes every key in the policy family
```

Freeze rules:

1. Freezes are one-way unless a future spec explicitly defines a timelocked
   unfreeze product.
2. The default launch posture should treat economic and final artwork freezes
   as irreversible.
3. Inherited freeze needs O(1) enforcement through counters, dirty bits, or
   explicit descendant materialization, not unbounded enumeration.
4. Freezing collection metadata should also freeze renderer choice, script
   manifest, dependency manifest, media manifests, and entropy policy if those
   facts define the final artwork.
5. Freezing revenue policy should be per revenue class, because primary-sale
   economics and royalties are separate promises.
6. Global freeze should clearly state whether it also blocks future revenue
   classes, renderer families, provider families, or only existing keys.

## Artwork Finality Freeze

Final artwork is cross-contract state. A collection cannot be honestly
described as final if the script is frozen but the renderer, dependency
manifest, media manifest, or entropy policy is still mutable.

Define a single collection finality action hosted by a dedicated
`StreamArtworkFinalityRegistry` satellite. Core stays small; the finality
registry is the contract that performs cross-module discovery, verifies the
component hashes, stores the finality record, and asks Core or the metadata
router to emit any Core-linked refresh/finality event required by indexers.

```solidity
function finalizeCollectionArtwork(
    uint256 collectionId,
    FinalityComponentExpectation[] calldata components,
    bytes32 expectedFinalityRecordHash,
    FinalityManifestRef calldata manifest
) external;
```

Access control:

1. `finalizeCollectionArtwork` requires `ROLE_COLLECTION_FINALITY_ADMIN`
   through ADR 0004 governance. Ordinary metadata, revenue, entropy, or
   collection admins cannot finalize artwork.
2. `scheduleFinalityRecovery` and `cancelFinalityRecovery` require
   `ROLE_COLLECTION_FINALITY_ADMIN`.
3. `executeFinalityRecovery` is permissionless after the scheduled delay if the
   recovery record is still `SCHEDULED` and all execution preconditions recheck.

```solidity
struct FinalityManifestRef {
    string uri;
    bytes32 uriHash;
    bytes32 contentHash;
    bytes32 schemaId;
    bytes32 canonicalizationHash;
}

struct RecoveryManifestRef {
    string uri;
    bytes32 uriHash;
    bytes32 contentHash;
    bytes32 schemaId;
    bytes32 canonicalizationHash;
}
```

`uriHash = keccak256(bytes(uri))`. `contentHash` is the hash of the canonical
manifest bytes, not the hash of a URL string. The manifest should be
canonicalized through the schema named by `schemaId` and
`canonicalizationHash`, for example RFC 8785/JCS JSON or deterministic CBOR.
PREMIS, C2PA, IIIF, preservation, recovery, and human-readable reconstruction
records are bound through `contentHash` when they are part of the finality
manifest.

Every participating satellite must expose a finality read surface:

```solidity
struct FinalityComponentState {
    bool frozen;
    bytes32 componentType;
    address component;
    bytes4 interfaceId;
    bytes32 codeHash;
    bytes32 moduleVersion;
    bytes32 manifestHash;
    bytes32 dataHash;
}

struct FinalityComponentExpectation {
    bytes32 componentType;
    address component;
    bytes4 interfaceId;
    bytes32 codeHash;
    bytes32 moduleVersion;
    bytes32 manifestHash;
    bytes32 dataHash;
}

interface IStreamFinalityComponent {
    function finalityState(uint256 collectionId)
        external
        view
        returns (FinalityComponentState memory);
}

interface IStreamFinalityDiscovery {
    function finalityComponentCount(uint256 collectionId)
        external
        view
        returns (uint256);

    function finalityComponentAt(uint256 collectionId, uint256 index)
        external
        view
        returns (FinalityComponentExpectation memory);

    function finalityDiscoveryHash(uint256 collectionId)
        external
        view
        returns (bytes32);
}
```

The finality registry stores:

```solidity
struct CollectionFinalityRecord {
    bool finalized;
    bytes32 finalityRecordHash;
    bytes32 manifestContentHash;
    bytes32 manifestURIHash;
    string finalityManifestURI;
    bytes32 componentsHash;
    uint64 finalizedAt;
}

mapping(uint256 collectionId => CollectionFinalityRecord) finalityRecords;
mapping(uint256 collectionId => FinalityComponentExpectation[]) finalityComponents;
```

`interfaceId` is the ERC-165-style four-byte interface identifier for the
component's finality read surface. If a component does not have an ERC-165
interface, the adapter must expose a Stream-defined `bytes4` interface ID.

`componentsHash` is:

```solidity
bytes32 componentsHash = keccak256(abi.encode(
    STREAM_FINALITY_COMPONENTS_V1,
    components
));
```

The submitted component list must be sorted ascending by `(componentType,
component, interfaceId, codeHash, moduleVersion, manifestHash, dataHash)` and
must not contain duplicates by that full identity tuple. Sorting is by
ABI-encoded field value, with addresses compared as 20-byte values and
`bytes4` compared as four-byte values. Any unsorted or duplicate list reverts
before finality is recorded.

`coreCollectionFactsHash` is computed onchain from Core through a small typed
read, not supplied as an opaque offchain assertion:

```solidity
struct CoreCollectionFinalityFacts {
    bool exists;
    bool hasMaxSupply;
    uint8 status;
    uint8 supplyMode;
    uint64 createdAt;
    uint64 maxSupply;
    uint64 mintedSupply;
    uint64 burnedSupply;
    uint64 nextCollectionSerial;
    bytes32 collectionConfigHash;
}

interface IStreamCoreFinalityFacts {
    function coreCollectionFinalityFacts(uint256 collectionId)
        external
        view
        returns (CoreCollectionFinalityFacts memory);
}

bytes32 coreCollectionFactsHash = keccak256(abi.encode(
    STREAM_CORE_COLLECTION_FACTS_V1,
    block.chainid,
    address(core),
    collectionId,
    facts.exists,
    facts.hasMaxSupply,
    facts.status,
    facts.supplyMode,
    facts.createdAt,
    facts.maxSupply,
    facts.mintedSupply,
    facts.burnedSupply,
    facts.nextCollectionSerial,
    facts.collectionConfigHash
));
```

`collectionConfigHash` is Core's hash of collection-level supply/status fields
that are not otherwise included above. It must not include mutable display
metadata, economic assignments, or event-only labels.
For launch v1, if no additional Core-owned collection config fields affect
finality beyond the fields explicitly listed in `CoreCollectionFinalityFacts`,
`collectionConfigHash` is:

```solidity
bytes32 collectionConfigHash = keccak256(abi.encode(
    STREAM_CORE_COLLECTION_CONFIG_EMPTY_V1,
    block.chainid,
    address(core),
    collectionId
));
```

If implementation adds another Core-owned collection config field that affects
minting, burning, supply, status, or finality, the launch spec must update this
preimage before deployment. A generic "whatever Core stores" hash is not
conformant.

Each component's `dataHash` preimage is component-owned but must be versioned,
typed, and named in that component's manifest. Launch components must publish
their `dataHash` schema in the release manifest. A generic "hash whatever the
module wants" value is not launch-conformant.

The registry computes the finality record hash onchain:

```solidity
bytes32 finalityRecordHash = keccak256(abi.encode(
    STREAM_FINALITY_V1,
    block.chainid,
    address(core),
    collectionId,
    coreCollectionFactsHash,
    componentsHash,
    manifest.uriHash,
    manifest.contentHash,
    manifest.schemaId,
    manifest.canonicalizationHash
));
```

`finalizeCollectionArtwork` reverts unless `finalityRecordHash ==
expectedFinalityRecordHash`. The offchain manifest at `manifest.uri` must
include the same component list, Core facts, preservation/provenance references,
and any richer human-readable reconstruction data. Onchain verification uses
the typed `components` calldata, live component reads, and manifest hashes. The
registry cannot and must not try to parse `manifest.uri` onchain.

Component discovery path:

1. The registry is bound to one Core.
2. Core exposes current pointers for `COLLECTION_METADATA`,
   `METADATA_ROUTER`, `ENTROPY_COORDINATOR`, and other Core-owned satellites.
3. The metadata router implements `IStreamFinalityDiscovery` for the resolved
   renderer, dependency source, media/source modules, and any snapshot route for
   `collectionId`.
4. Each discovered component implements `IStreamFinalityComponent` or is wrapped
   by a small finality adapter that reports the required state.
5. `finalizeCollectionArtwork` reverts unless the submitted component list
   exactly matches the discovered components, the submitted component hash
   equals `finalityDiscoveryHash(collectionId)`, and every live
   `FinalityComponentState` equals the corresponding expectation with
   `frozen = true`.
6. After finality, `finalityRecords(collectionId)` and
   `finalityComponents(collectionId, start, limit)` provide the durable
   onchain record and allow future tools to check whether live components still
   match.
7. Finality either freezes the relevant collection-scoped Core pointers in the
   same action or records the collection as address-pinned. If a later global
   pointer move occurs, `verifyFinality(collectionId)` must still compare
   against the address/codehash captured in the finality record and return
   false for the current route unless a public recovery manifest supersedes it.

Required component types include at least:

```text
COLLECTION_METADATA
METADATA_ROUTER
RENDERER
RENDER_CONTEXT
SCRIPT_SOURCE
DEPENDENCY_SOURCE
MEDIA_MANIFEST
ENTROPY_COORDINATOR
OPTIONAL_SNAPSHOT_ROUTE
```

Core facts are not a `FinalityComponentExpectation` entry; they are the
separately computed `coreCollectionFactsHash` or `scopedCoreFactsHash` input to
the finality record. Finality is not valid if any required satellite component
is merely promised frozen offchain.
Launch should cap finality component count and calldata size. Initial limits:
`MAX_FINALITY_COMPONENTS = 32` and `MAX_FINALITY_CALLDATA_BYTES = 32_768`,
subject to implementation measurement before deployment.

The finality manifest must bind:

1. Core address, chain ID, collection ID, and collection-local supply facts.
2. Collection metadata contract address, module version, and frozen metadata
   root.
3. Metadata router address, router config, and renderer assignment.
4. Renderer address, code hash, renderer version, render context version, and
   renderer manifest hash.
5. Script source type, script bytes hash, script chunk count, and script
   manifest hash.
6. Dependency registry/source identity and dependency payload hashes.
7. Media manifest hashes, image/animation/content URI hashes, and rights or
   preservation manifests where configured.
8. Entropy coordinator address, provider config, provider epoch, collection
   salt commitment, pending/finalized policy, and any allowed post-finality
   entropy state.
9. Post-freeze exceptions, if any, such as typo-only offchain label metadata or
   preservation mirrors that cannot change artwork bytes.

Finality requirements:

1. The action verifies that every participating module reports the required
   frozen state before finality is recorded.
2. The action emits one Core-originated or Core-linked finality event.
3. A read function returns the finality record hash, manifest content hash, and
   whether all component modules still match it.
4. Incident recovery cannot silently swap final artwork. It must publish a new
   recovery manifest and preserve the original finality manifest.
5. Frozen renderers may be deprecated for new collections, but they must keep
   serving historical frozen collections or a hash-bound snapshot route.
6. Onchain and hybrid collections cannot be finalized unless a snapshot
   manifest hash covering assembled script bytes, dependency payloads, renderer
   context, metadata root, media hashes, and entropy policy has already been
   recorded in the collection metadata contract.
7. Collection-level artwork finality that binds `mintedSupply`,
   `burnedSupply`, and `nextCollectionSerial` requires Core collection status
   `CLOSED`. For collection-level finality, `CLOSED` must guarantee that
   `mintedSupply`, `burnedSupply`, and `nextCollectionSerial` are immutable
   thereafter. `coreCollectionFinalityFacts(collectionId)` must therefore be
   invariant for a `CLOSED` finalized collection. If Core cannot guarantee
   this invariant, collection-level finality is forbidden and only scoped
   token, release, season, or view finality may be used. Collection-scope
   artwork finality forbids any surviving burn path, because a post-finality
   burn would mutate `burnedSupply`. Collections that require post-finality
   burns must use scoped finality only; scoped Core facts intentionally do not
   bind collection-wide burned supply.
8. Ongoing open series use token-level, release-level, season-level, or
   view-level snapshot/finality records rather than collection-level finality
   for the still-open parent collection.

### Scoped Finality For Open Series

Open-ended collections are a first-class launch target. They need finality for
individual works, releases, seasons, exhibitions, and archival views without
pretending the parent collection has a final supply.

Canonical scoped-finality model:

```solidity
enum FinalityScopeType {
    COLLECTION,
    TOKEN,
    RELEASE,
    SEASON,
    VIEW
}

struct FinalityScope {
    FinalityScopeType scopeType;
    uint256 collectionId;
    uint256 tokenId;
    bytes32 scopeId;
}

struct ScopedFinalityRecord {
    bool finalized;
    FinalityScope scope;
    bytes32 finalityRecordHash;
    bytes32 manifestContentHash;
    bytes32 manifestURIHash;
    bytes32 componentsHash;
    string finalityManifestURI;
    uint64 finalizedAt;
}

function finalizeArtworkScope(
    FinalityScope calldata scope,
    FinalityComponentExpectation[] calldata components,
    bytes32 expectedFinalityRecordHash,
    FinalityManifestRef calldata manifest
) external;

function artworkScopeFinalityRecord(FinalityScope calldata scope)
    external
    view
    returns (ScopedFinalityRecord memory);

function verifyArtworkScopeFinality(FinalityScope calldata scope)
    external
    view
    returns (
        bool currentRouteMatches,
        bytes32 finalityRecordHash,
        bytes32 componentsHash
    );

function finalityComponentCountForScope(FinalityScope calldata scope)
    external
    view
    returns (uint256);

function finalityComponentsForScope(
    FinalityScope calldata scope,
    uint256 start,
    uint256 limit
) external view returns (FinalityComponentExpectation[] memory);

function verifyArtworkScopeFinalityRange(
    FinalityScope calldata scope,
    uint256 start,
    uint256 limit
) external view returns (
    bool rangeMatches,
    bytes32 finalityRecordHash,
    bytes32 expectedRangeHash,
    bytes32 observedRangeHash,
    uint256 nextStart
);

interface IStreamScopedFinalityComponent {
    function finalityStateForScope(FinalityScope calldata scope)
        external
        view
        returns (FinalityComponentState memory);
}

interface IStreamScopedFinalityDiscovery {
    function finalityComponentCountForScope(FinalityScope calldata scope)
        external
        view
        returns (uint256);

    function finalityComponentAtForScope(
        FinalityScope calldata scope,
        uint256 index
    ) external view returns (FinalityComponentExpectation memory);

    function finalityDiscoveryHashForScope(FinalityScope calldata scope)
        external
        view
        returns (bytes32);
}

interface IStreamScopedFrozenRouteRegistry {
    function frozenRouteForScope(bytes32 routeType, FinalityScope calldata scope)
        external
        view
        returns (
            bool pinned,
            address module,
            bytes32 routeHash,
            bytes32 finalityRecordHash
        );
}
```

Scope rules:

1. `COLLECTION` scope uses `collectionId` and requires `tokenId == 0` and
   `scopeId == bytes32(0)`.
2. `TOKEN` scope requires a minted or burned token whose retained Core identity
   maps to `collectionId`; `scopeId` is zero unless a future token-view schema
   explicitly defines it.
3. `RELEASE`, `SEASON`, and `VIEW` scopes require a nonzero `scopeId` whose
   schema and canonical manifest are published by collection metadata.
4. A scoped finality record binds the same component identity fields as
   collection finality, but component `dataHash` may be scoped to the token,
   release, season, or view.
5. Frozen-route compatibility keys include
   `(scopeType, collectionId, tokenId, scopeId, finalityRecordHash)`, not only
   `collectionId`.
6. A global router, renderer, collection metadata, or entropy pointer
   replacement is launch-conformant only if it can serve every pinned scoped
   route or a delayed recovery manifest supersedes the affected scope.
7. Scoped finality recovery uses the same status machine as collection finality
   but its `recoveryId` preimage includes the full `FinalityScope`.
8. Collection-level finality may coexist with older token, release, season, or
   view records, but it cannot reinterpret them. Later broader finality records
   must reference prior scoped record hashes in their manifest when they depend
   on them.

Scoped finality hashes include the full scope:

```solidity
bytes32 scopedFinalityRecordHash = keccak256(abi.encode(
    STREAM_SCOPED_FINALITY_V1,
    block.chainid,
    address(core),
    uint8(scope.scopeType),
    scope.collectionId,
    scope.tokenId,
    scope.scopeId,
    scopedCoreFactsHash,
    componentsHash,
    manifest.uriHash,
    manifest.contentHash,
    manifest.schemaId,
    manifest.canonicalizationHash
));
```

Scoped Core facts:

```solidity
struct ScopedCoreFinalityFacts {
    bool scopeExists;
    uint8 scopeType;
    uint256 collectionId;
    uint256 tokenId;
    bytes32 scopeId;
    bool tokenMappingExists;
    uint256 collectionSerial;
    uint8 tokenLifecycle;
    bool burned;
    uint8 collectionStatus;
    uint8 collectionSupplyMode;
    bytes32 collectionConfigHash;
    bytes32 scopeManifestHash;
}

function scopedCoreFinalityFacts(FinalityScope calldata scope)
    external
    view
    returns (ScopedCoreFinalityFacts memory);

bytes32 scopedCoreFactsHash = keccak256(abi.encode(
    STREAM_SCOPED_CORE_FINALITY_FACTS_V1,
    block.chainid,
    address(core),
    uint8(scope.scopeType),
    scope.collectionId,
    scope.tokenId,
    scope.scopeId,
    facts.scopeExists,
    facts.tokenMappingExists,
    facts.collectionSerial,
    facts.tokenLifecycle,
    facts.burned,
    facts.collectionStatus,
    facts.collectionSupplyMode,
    facts.collectionConfigHash,
    facts.scopeManifestHash
));
```

For `TOKEN`, `scopeExists` requires `tokenCollectionIdentity(tokenId)` to map
to `collectionId`, and `scopeManifestHash` is zero unless token metadata names
a token-finality manifest. For `RELEASE`, `SEASON`, and `VIEW`, `scopeExists`
requires collection metadata to publish the `scopeId` and its manifest hash.
Scoped finality for an open parent collection does not bind `mintedSupply`,
`burnedSupply`, or `nextCollectionSerial`; it binds only the scoped facts above
and the component list for that scope.

Scoped recovery mirrors collection recovery:

```solidity
struct ScopedFinalityRecoveryRecord {
    FinalityRecoveryStatus status;
    FinalityScope scope;
    bytes32 oldFinalityRecordHash;
    RecoveryManifestRef recoveryManifest;
    bytes32 recoveryRouteHash;
    uint64 executeAfter;
    bool artworkBytesChanged;
    bytes32 reasonHash;
    string reasonURI;
}

function scheduleScopedFinalityRecovery(
    FinalityScope calldata scope,
    bytes32 recoveryId,
    bytes32 expectedOldFinalityRecordHash,
    RecoveryManifestRef calldata recoveryManifest,
    bytes32 recoveryRouteHash,
    uint64 executeAfter,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string calldata reasonURI
) external;

function cancelScopedFinalityRecovery(
    FinalityScope calldata scope,
    bytes32 recoveryId,
    bytes32 reasonHash,
    string calldata reasonURI
) external;

function executeScopedFinalityRecovery(
    FinalityScope calldata scope,
    bytes32 recoveryId
) external;

function scopedFinalityRecoveryRecord(
    FinalityScope calldata scope,
    bytes32 recoveryId
) external view returns (ScopedFinalityRecoveryRecord memory);
```

`recoveryId` is `keccak256(abi.encode(STREAM_SCOPED_FINALITY_RECOVERY_V1,
block.chainid, address(finalityRegistry), uint8(scope.scopeType),
scope.collectionId, scope.tokenId, scope.scopeId,
expectedOldFinalityRecordHash, recoveryManifest.contentHash, recoveryRouteHash,
executeAfter, artworkBytesChanged, reasonHash))`.

Recommended scoped event:

```solidity
event ArtworkScopeFinalized(
    uint16 schemaVersion,
    uint8 indexed scopeType,
    uint256 indexed collectionId,
    bytes32 indexed finalityRecordHash,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 componentsHash,
    bytes32 manifestContentHash,
    string finalityManifestURI
);

event ScopedFinalityRecoveryScheduled(
    uint16 schemaVersion,
    uint8 indexed scopeType,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 oldFinalityRecordHash,
    bytes32 recoveryManifestContentHash,
    bytes32 recoveryRouteHash,
    uint64 executeAfter,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string reasonURI
);

event ScopedFinalityRecoveryCancelled(
    uint16 schemaVersion,
    uint8 indexed scopeType,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 reasonHash,
    string reasonURI
);

event ScopedFinalityRecoveryExecuted(
    uint16 schemaVersion,
    uint8 indexed scopeType,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    uint256 tokenId,
    bytes32 scopeId,
    bytes32 recoveryManifestContentHash,
    bytes32 recoveryRouteHash,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string reasonURI
);
```

Recommended event:

```solidity
event CollectionArtworkFinalized(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed finalityRecordHash,
    address indexed actor,
    bytes32 componentsHash,
    bytes32 manifestContentHash,
    string finalityManifestURI
);
```

Required reads:

```solidity
function collectionFinalityRecord(uint256 collectionId)
    external
    view
    returns (CollectionFinalityRecord memory);

function finalityComponentCount(uint256 collectionId)
    external
    view
    returns (uint256);

function finalityComponents(uint256 collectionId, uint256 start, uint256 limit)
    external
    view
    returns (FinalityComponentExpectation[] memory);

function finalityStillMatches(uint256 collectionId)
    external
    view
    returns (bool);

function verifyFinality(uint256 collectionId)
    external
    view
    returns (
        bool currentRouteMatches,
        bytes32 finalityRecordHash,
        bytes32 componentsHash
    );

function verifyFinalityRange(
    uint256 collectionId,
    uint256 start,
    uint256 limit
)
    external
    view
    returns (
        bool rangeMatches,
        bytes32 finalityRecordHash,
        bytes32 expectedRangeHash,
        bytes32 observedRangeHash,
        uint256 nextStart
    );
```

`verifyFinality` and `finalityStillMatches` are non-reverting diagnostic reads
for already-recorded finality. They must use bounded `staticcall` to every
component, with a launch-measured `FINALITY_COMPONENT_READ_GAS` and a bounded
returndata copy for the fixed return struct. If any component read reverts,
runs out of its gas cap, returns malformed data, has no code, or no longer
matches the expected code hash, the read returns `currentRouteMatches = false`
or `false` and still returns the stored finality hash. It must not revert merely
because a historical component became unhealthy.
The release manifest must publish both per-component and total worst-case
diagnostic gas for `MAX_FINALITY_COMPONENTS`. If the full `verifyFinality`
read becomes impractical under future gas schedules, `verifyFinalityRange`
remains the archival verification primitive. Implementations should expose a
documented diagnostic status such as `VERIFY_RANGE_REQUIRED` before attempting
component reads when the published full-read budget is not satisfiable, instead
of allowing callers to hit an unexplained out-of-gas condition.
Initial planning target is `FINALITY_COMPONENT_READ_GAS = 30_000` and a full
diagnostic budget under 1,200,000 gas for 32 components, but launch uses
measured values plus margin. Operator tooling should prefer
`verifyFinalityRange` for routine archival checks once a collection has more
than eight components.

Finality recording is stricter: `finalizeCollectionArtwork` reverts if any
required component read fails, returns malformed data, reports `frozen = false`,
or differs from the submitted expectation. `previewFinality(collectionId,
components)` or equivalent tooling must expose the same comparisons before a
state-changing finality transaction is sent, and launch operator runbooks must
require a successful preview artifact hash before execution.

### Finality Recovery

Artwork-finality recovery is a governed state machine:

```solidity
enum FinalityRecoveryStatus {
    NONE,
    SCHEDULED,
    CANCELLED,
    EXECUTED
}

struct FinalityRecoveryRecord {
    FinalityRecoveryStatus status;
    bytes32 oldFinalityRecordHash;
    RecoveryManifestRef recoveryManifest;
    bytes32 recoveryRouteHash;
    uint64 executeAfter;
    bool artworkBytesChanged;
    bytes32 reasonHash;
    string reasonURI;
}

event FinalityRecoveryScheduled(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    bytes32 oldFinalityRecordHash,
    bytes32 recoveryManifestContentHash,
    bytes32 recoveryRouteHash,
    uint64 executeAfter,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string reasonURI
);

event FinalityRecoveryCancelled(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    bytes32 reasonHash,
    string reasonURI
);

event FinalityRecoveryExecuted(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    bytes32 recoveryManifestContentHash,
    bytes32 recoveryRouteHash,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string reasonURI
);

function scheduleFinalityRecovery(
    uint256 collectionId,
    bytes32 recoveryId,
    bytes32 expectedOldFinalityRecordHash,
    RecoveryManifestRef calldata recoveryManifest,
    bytes32 recoveryRouteHash,
    uint64 executeAfter,
    bool artworkBytesChanged,
    bytes32 reasonHash,
    string calldata reasonURI
) external;

function cancelFinalityRecovery(
    uint256 collectionId,
    bytes32 recoveryId,
    bytes32 reasonHash,
    string calldata reasonURI
) external;

function executeFinalityRecovery(
    uint256 collectionId,
    bytes32 recoveryId
) external;

function finalityRecoveryRecord(
    uint256 collectionId,
    bytes32 recoveryId
) external view returns (FinalityRecoveryRecord memory);

function activeFinalityRecoveryRoute(uint256 collectionId)
    external
    view
    returns (bytes32 recoveryRouteHash, bytes32 recoveryId);
```

Rules:

1. Recovery cannot erase the original finality record.
2. Recovery is delayed governance and uses the finality/preservation role, not
   ordinary metadata admin.
3. Recovery manifests name the failed component, old component address/codehash,
   new component address/codehash or snapshot route, old and new manifest
   hashes, reason URI/hash, and whether artwork bytes changed.
4. If artwork bytes change, the recovery is artwork-affecting and must be
   displayed as such forever.
5. `verifyFinality` returns both original finality and current-route status so
   archives can distinguish "historically final" from "currently served through
   a recovery route."
6. A global pointer move, including emergency entropy-coordinator replacement,
   makes finalized collections whose manifests pinned the old pointer report
   `currentRouteMatches = false` until a recovery manifest supersedes that
   route.
7. `recoveryId` is `keccak256(abi.encode(STREAM_FINALITY_RECOVERY_V1,
   block.chainid, address(finalityRegistry), collectionId,
   expectedOldFinalityRecordHash, recoveryManifest.contentHash, recoveryRouteHash,
   executeAfter, artworkBytesChanged, reasonHash))`.
8. `executeFinalityRecovery` rechecks status `SCHEDULED`, delay, old finality
   record hash, and recovery manifest hash before marking the recovery
   `EXECUTED`.

## Governance Staging

"Use timelock" is not enough. Staged governance actions should share an
implementable model.

Required staged-operation fields:

```text
operationType
target contract
selector or action family
scope and scope ID
old value hash
new value hash
nonce
notBefore timestamp
expiresAfter timestamp
actor
reason hash and reason URI
manifest hash
```

The canonical action ID/preimage is defined in `docs/adr/0004-admin-governance.md`.
Subsystem specs may name domain-specific fields, but they must fold into that
single staged-operation schema rather than inventing conflicting preimages.

Rules:

1. Default-scope economics, resolver replacement, metadata router replacement,
   renderer registry changes, entropy provider registry changes, global
   freezes, and artwork finality freezes require staged operations.
2. Staging and execution emit separate events.
3. Cancellation is evented and must be possible before execution.
4. Irreversible freezes should have a veto or guardian delay so one compromised
   key cannot instantly and permanently freeze artwork or economics.
5. Emergency operations must be narrower than normal governance. They can pause,
   deprecate, incident-revoke, or move to a pre-approved safe fallback, but they
   cannot sweep owed funds or change final artwork/economics without the normal
   recovery process.
6. The role-admin hierarchy and delay values are deployment parameters and must
   be recorded in deployment manifests.

## System Manifest And Successor Declaration

A future indexer, museum, or marketplace needs one deterministic way to discover
the active Stream system.

Required aggregate read:

```solidity
function streamSystemManifest()
    external
    view
    returns (
        bytes32 manifestHash,
        string memory manifestURI,
        address revenueResolver,
        address metadataRouter,
        address collectionMetadata,
        address entropyCoordinator,
        address mintManager,
        address mintLedger,
        address streamAdminsOrGovernance,
        address artworkFinalityRegistry,
        address moduleRegistry,
        address stateExportPublisher,
        bytes32 eventCatalogHash,
        bytes32 compatibilityMatrixHash,
        bytes32 numericIdCatalogHash,
        bytes32 schemaCatalogHash,
        bytes32 canonicalizationCatalogHash,
        bytes32 specBundleHash,
        bytes32 reconstructionClientHash
    );
```

The `streamSystemManifest()` read is hosted on Core and is a required launch
surface, not an optional convenience. The release manifest records its selector,
interface ID if one is assigned, return shape, and gas measurement. The
manifest should include module addresses, versions, code hashes, registry
states, pointer freeze states, event catalog hash, compatibility matrix hash,
numeric ID catalog hash, schema catalog hash, canonicalization catalog hash,
spec bundle hash, reconstruction client hash, and deployment chain IDs.
`streamSystemManifest()` is a storage-only read. Core stores the manifest hash,
manifest URI, current Core pointer addresses, the state/export publisher
address, cached catalog hashes, and cached discovery hashes needed for the
return tuple. It must not call satellites,
registries, or offchain resolvers. Pointer updates and catalog updates that
change any returned field must update the cached system manifest fields in the
same governed execution and emit the corresponding pointer/catalog event. If a
catalog publisher needs richer data, it lives in the content-addressed manifest
named by `manifestURI` and committed by `manifestHash`, not in an external call
from Core.

Core should also support a non-mutating successor declaration for long-term
identity continuity:

```solidity
event StreamCoreSuccessorDeclared(
    address indexed successorCore,
    bytes32 indexed successorManifestHash,
    string successorManifestURI
);

event StreamCoreSuccessorRepudiated(
    address indexed successorCore,
    bytes32 indexed successorManifestHash,
    bytes32 indexed reasonHash,
    string reasonURI
);

function declareStreamCoreSuccessor(
    address successorCore,
    bytes32 successorManifestHash,
    string calldata successorManifestURI
) external;

function streamCoreSuccessorCount() external view returns (uint256);

function streamCoreSuccessorAt(uint256 index)
    external
    view
    returns (
        address successorCore,
        bytes32 successorManifestHash,
        string memory successorManifestURI,
        uint64 declaredAt
    );

function coreLifecycleStatus()
    external
    view
    returns (
        uint8 status,
        bytes32 latestSuccessorManifestHash
    );
```

A successor declaration does not migrate tokens, transfer ownership, or change
the old Core. It is a public breadcrumb for future chain migrations, L2
successors, archival mirrors, or a post-EIP standards replacement.
Outstanding old-Core signed mint tickets, sale authorizations, nullifiers, and
future-dated permissions are not honored by a successor Core. A successor
deployment starts with its own authorization/nullifier ledger and must require
fresh signatures or an explicit successor authorization scheme.
A successor Core also deploys or points to its own revenue resolver line. The
old resolver is bound to the old Core and must not be reused as if assignments
automatically apply to the successor.

Access control for `declareStreamCoreSuccessor` must use the ADR 0004
`SUCCESSOR_DECLARATION` governance class with the published delay, staged
operation ID, cancellation path, and reason URI/hash. It is not an emergency
bypass and cannot be executed by a narrow funds, metadata, entropy, or renderer
admin. The function may append to a successor history and expose the latest
declaration for convenience, but it must not mutate ERC-721 ownership, token
collection mappings, satellite pointers, royalty behavior, metadata behavior,
or freeze state.
When `coreLifecycleStatus().status != ACTIVE`, `streamSystemManifest()` must
continue returning the old Core's module set and catalog hashes. It must not be
repurposed to advertise successor module addresses. Successor discovery is
through the successor declaration history and successor manifest, with
`coreLifecycleStatus()` as the old Core's lifecycle read.

Emergency incident communication, public state export, monitoring alerts, and
publication of candidate successor artifacts for a critical Core bug are not
gated by the 30-day `SUCCESSOR_DECLARATION` delay. The delay gates only the
onchain canonical successor pointer/declaration execution.

The successor manifest must include old chain ID, old Core, new chain ID, new
Core, ownership snapshot hash, complete event-history snapshot hash,
collection-snapshot root, activation statement, and explicit old-Core status:
`ACTIVE`, `DEPRECATED_QUERYABLE`, or `DEPRECATED_ZERO_ROYALTIES`. Indexers must
not infer deprecation from the existence of a successor event alone; they should
read `coreLifecycleStatus()` or the successor manifest status that the read
hashes.

## Resolver Safety Invariants

Core read paths that call satellites must be bounded and boring. In particular,
the royalty resolver's `royaltyInfoForToken` path must be storage reads and
arithmetic only. It must not make external calls, deploy wallets, read ERC-20
balances, call receiver hooks, or depend on mutable marketplace context.

Launch validation must include malicious resolvers that consume all gas,
return malformed data, return excess data, attempt external calls, or recurse
through another view. Core must return `(address(0), 0)` without reverting
under every resolver failure mode, and the production resolver implementation
must be audited against the no-external-call invariant.

`royaltyInfo()` and `tokenURI()` bounded reads are independent marketplace
entrypoints with independent top-level gas budgets. Launch code must not add a
combined marketplace read that invokes both the royalty resolver and metadata
router within one shared `staticcall` frame or derives one gas cap from the
other.

## State Export And Archival Operations

A 50-year system needs verifiable state export, not only live RPC reads.
Deployment and successor manifests should define a `StateExport` profile:

```text
STATE_EXPORT_V1
chainId
core address
block number/hash
token ownership root
token-to-collection root, including burned tokens with retained mappings
collection serial root
collection facts root
entropy seed/status root
revenue assignment root
split profile root
finality record root
event history snapshot hash
export manifest URI/hash
```

The export may be produced offchain by indexers, but the format must be
canonical and independently reproducible from chain data. Successor
declarations should reference the latest state export hash and, for chains
hosting onchain art, a content-addressed mirror of every finalized assembled
artwork snapshot.

Discoverable export publication surface:

```solidity
event StateExportPublished(
    uint16 schemaVersion,
    uint256 indexed blockNumber,
    bytes32 indexed exportHash,
    bytes32 indexed manifestHash,
    bytes32 blockHash,
    string manifestURI
);

function latestStateExport()
    external
    view
    returns (
        uint256 blockNumber,
        bytes32 blockHash,
        bytes32 exportHash,
        bytes32 manifestHash,
        string memory manifestURI
    );
```

The event may be emitted by governance, a dedicated archive publisher, or a
successor/export satellite named in `streamSystemManifest()`. It does not make
an offchain export magically correct; it makes the claimed export discoverable,
hash-bound, and challengeable.
Export roots are computed at a named confirmation depth. If an export's block
range includes a later-reorged entropy fulfillment, escrow event, governance
action, or other state-changing event, the old export must be superseded
through `StateExportSuperseded`; it must not be silently corrected in place.

Challenge and supersession surface:

```solidity
event StateExportChallenged(
    uint16 schemaVersion,
    bytes32 indexed exportHash,
    bytes32 indexed challengeHash,
    address indexed challenger,
    string challengeURI
);

event StateExportSuperseded(
    uint16 schemaVersion,
    bytes32 indexed oldExportHash,
    bytes32 indexed newExportHash,
    bytes32 indexed reasonHash,
    string reasonURI
);
```

The same pattern should be available for recovery manifests and archive/fixity
receipts when a previously published artifact is found incomplete, corrupted,
or non-canonical. Supersession does not erase the old artifact; it creates a
public lineage.
If the state/export publisher becomes obsolete or unavailable, the cached
`stateExportPublisher` in `streamSystemManifest()` remains historical discovery
data. While governance works, replacement uses delayed pointer/catalog
governance. If governance is lost, independent archives can still publish
unofficial exports and challenges offchain, but old Core cannot bless a new
publisher; consumers should mark those exports as independently reproduced, not
Core-published.
Successor manifests must name the proof posture for the state export: Merkle
inclusion proofs over the exported roots, a future ZK proof if one is adopted,
or explicit social/governance attestation when cryptographic continuity is not
available. The chosen proof posture is part of the successor manifest hash.
If a declared successor manifest is later found compromised, governance may
publish `StreamCoreSuccessorRepudiated` under the same
`SUCCESSOR_DECLARATION` delay class. Repudiation does not erase the old
declaration; it adds a visible warning and replacement lineage.
Burned tokens are excluded from ownership roots after burn but included in
token-to-collection and collection-serial roots when Core retains their mapping.
Roots should be Merkle roots over sorted `(key, valueHash)` leaves with the leaf
schema named in the export manifest. The reference exporter can be maintained
offchain, but no export is canonical unless an independent indexer can reproduce
the same roots from archived chain data and the published event catalog.

Minimum v1 leaf schemas:

```solidity
bytes32 tokenCollectionLeaf = keccak256(abi.encode(
    STREAM_EXPORT_TOKEN_COLLECTION_LEAF_V1,
    uint256(tokenId),
    bool(mappingExists),
    uint256(collectionId),
    uint256(collectionSerial),
    bool(burned)
));

bytes32 collectionSerialLeaf = keccak256(abi.encode(
    STREAM_EXPORT_COLLECTION_SERIAL_LEAF_V1,
    uint256(collectionId),
    uint256(collectionSerial),
    uint256(tokenId),
    bool(burned)
));

bytes32 entropyLeaf = keccak256(abi.encode(
    STREAM_EXPORT_ENTROPY_LEAF_V1,
    uint256(tokenId),
    uint8(status),
    bytes32(seed),
    address(coordinatorAtMint),
    address(provider),
    uint32(providerEpoch),
    bytes32 requestKey,
    uint16 requestAttempt
));

bytes32 finalityLeaf = keccak256(abi.encode(
    STREAM_EXPORT_FINALITY_LEAF_V1,
    uint8(scope.scopeType),
    uint256(scope.collectionId),
    uint256(scope.tokenId),
    bytes32(scope.scopeId),
    bytes32(finalityRecordHash),
    bytes32(componentsHash),
    bytes32(manifestContentHash),
    uint64(finalizedAt)
));

bytes32 splitProfileLeaf = keccak256(abi.encode(
    STREAM_EXPORT_SPLIT_PROFILE_LEAF_V1,
    bytes32(profileId),
    address(wallet),
    bytes32(entriesHash),
    uint16(walletVersion),
    bytes32(runtimeCodeHash)
));

bytes32 splitEntryLeaf = keccak256(abi.encode(
    STREAM_EXPORT_SPLIT_ENTRY_LEAF_V1,
    bytes32(profileId),
    uint16(index),
    address(account),
    bytes32(labelId),
    uint32(sharePpm)
));

bytes32 revenueAssignmentLeaf = keccak256(abi.encode(
    STREAM_EXPORT_REVENUE_ASSIGNMENT_LEAF_V1,
    bytes32(revenueClass),
    uint8(scope),
    uint256(scopeId),
    bytes32(profileOrTemplateId),
    address(wallet),
    uint16(royaltyBps),
    uint8(freezeMode),
    bool(permanentFreeze),
    bytes32(assignmentHash)
));

bytes32 escrowCreditLeaf = keccak256(abi.encode(
    STREAM_EXPORT_ESCROW_CREDIT_LEAF_V1,
    bytes32(revenueClass),
    bytes32(profileId),
    address(wallet),
    address(asset),
    uint256(owed),
    address(storedFactory),
    bytes32(escrowRuntimeCodeHash)
));

bytes32 mintCounterLeaf = keccak256(abi.encode(
    STREAM_EXPORT_MINT_COUNTER_LEAF_V1,
    bytes32(valueKey),
    uint64(counterValue),
    bytes32(policyHash)
));

bytes32 authorizationLeaf = keccak256(abi.encode(
    STREAM_EXPORT_AUTHORIZATION_LEAF_V1,
    bytes32(authorizationOrNullifierId),
    bool(used),
    bytes32(policyHash)
));

bytes32 registryRecordLeaf = keccak256(abi.encode(
    STREAM_EXPORT_REGISTRY_RECORD_LEAF_V1,
    address(registry),
    address(module),
    uint8(status),
    bytes32(moduleType),
    bytes4(interfaceId),
    bytes32(runtimeCodeHash),
    bytes32(moduleManifestHash)
));

bytes32 catalogLeaf = keccak256(abi.encode(
    STREAM_EXPORT_CATALOG_LEAF_V1,
    bytes32(catalogType),
    bytes32(catalogHash),
    bytes32(schemaId),
    bytes32(canonicalizationHash)
));

bytes32 recoveryLeaf = keccak256(abi.encode(
    STREAM_EXPORT_RECOVERY_LEAF_V1,
    bytes32(recoveryType),
    bytes32(recoveryId),
    uint8(status),
    bytes32(oldRecordHash),
    bytes32(recoveryManifestContentHash),
    uint64(executeAfter)
));
```

Leaves are sorted by `(tokenId)` for the token-to-collection root and by
`(collectionId, collectionSerial, tokenId)` for the collection-serial root.
Entropy leaves are sorted by `(tokenId)`. Finality leaves are sorted by
`(scopeType, collectionId, tokenId, scopeId, finalityRecordHash)`.
Each additional root defines a deterministic sort key in the export manifest;
the field lists above are minimum v1 leaves and may be extended only by a new
leaf version.

Render-critical and preservation-critical payloads should be mirrored across at
least two independent storage families where practical, for example IPFS plus
Arweave, Filecoin, institutional archives, or another content-addressed medium.
The manifest records storage locations, fixity hashes, last check time, and the
agent that performed the check. HTTPS-only render-critical payloads are allowed
only when the collection intentionally accepts service-backed mutability.

Every Ethereum hard fork, L2 migration, or material gas-schedule change should
trigger a protocol-parameter review. The review remeasures Core bytecode,
resolver gas, `SLOAD`/`STATICCALL` assumptions, split-wallet release gas,
metadata rendering limits, and any SSTORE2 or chunk-read assumptions, then
publishes a compatibility report hash. Periodic reviews should also sample
marketplace, wallet, indexer, archive-node, and metadata-cache behavior for
ERC-2981, ERC-4906, tokenURI fallback handling, contract metadata discovery,
and frozen/recovered collection display.
If average block time, timestamp behavior, finality assumptions, or block-count
semantics materially change, the review must re-evaluate entropy
`requestTimeoutBlocks`, governance delay UX, stale request windows, and any
block-number-based archival/export policy.

Stream should maintain a minimum archival reconstruction client outside the
production frontend. At launch it must be able to replay the event catalog,
reconstruct token-to-collection mappings, split profiles, escrow balances,
entropy status/seeds, collection metadata snapshots, and finality records from
archived chain data and content-addressed manifests. Its source archive,
reproducible build instructions, and test-vector outputs should be mirrored
with the deployment manifest. Operations should schedule periodic preservation
drills that independently rebuild these roots, render at least one finalized
onchain/hybrid collection from archived payloads, and publish the drill report
hash.
Those drills must also prove that the reconstruction client still builds from
archived source, pinned dependencies, and archived build instructions on
contemporary tooling or in a preserved build container. If it does not, the
replacement client and migration notes become preservation artifacts with their
own URI/hash.

Long-term operations also need a funding posture. The deployment runbook should
name the treasury or funding mechanism for keepers, entropy request payments,
monitoring, storage pinning/mirroring, domain/ENS renewal, and preservation
drills, and should document what degrades if funding disappears.
The specs, ADRs, event catalogs, release manifests, and reconstruction-client
source archives are themselves preservation objects. Each launch and material
upgrade should publish a content-addressed spec bundle hash in the deployment
manifest and mirror it across independent storage families. Governance runbooks
should also name legal-entity succession and dissolution risks; the contracts do
not solve legal continuity, but operators should document who can act if the
original operating entity ceases to exist.
Event-log and state availability are operational assumptions, not protocol
guarantees. If EIP-4444-style history expiry, log pruning, state expiry, or RPC
retention changes make ordinary `eth_getLogs`/archive reads incomplete, Stream
relies on content-addressed state exports, mirrored event-history snapshots,
archival reconstruction clients, and independent archive nodes named in the
operations runbook.

For literally unbounded open series, live per-token mappings are permanent
state growth. Launch keeps explicit `tokenCollectionIdentity` storage because
that is the most robust marketplace and royalty surface. A future state-expiry
or storage-rent era may add a successor deployment line in which cold token
identity proofs are served from a canonical state-export root, but that is a
new architecture decision. The launch Core must not silently replace live
token identity reads with offchain proofs. The same posture applies to durable
mint ledger counters, authorization/nullifier state, escrow owed balances,
split release state, finality records, recovery records, and registry/catalog
state: launch keeps them live where the protocol requires live reads, and any
future proof-backed cold-storage model is a successor-line decision with state
export roots and explicit user-facing tradeoffs.

Monitoring operations should define alert routing and escalation for:

1. resolver fallback-to-zero;
2. metadata router failure;
3. entropy pending/stale requests;
4. escrow owed aging;
5. unsupported asset receipt;
6. finality mismatch;
7. governance action scheduled/executed/cancelled;
8. storage fixity failure;
9. marketplace cache divergence.

If immutable Core is found to have a critical bug, the default incident posture
is communication, pause/tightening where available, state export, and successor
declaration. The old Core's ownership history is not rewritten. Any migration
or social-canonical successor must carry ownership and event-history snapshot
hashes plus a clear statement of old-Core status.

Zero-admin and lost-quorum drills must cover the complete satellite set, not
only Core. The runbook should periodically prove degraded-mode reads and
operations for metadata router failure, finality verification, pending entropy,
split-wallet release, escrow flush, state export publication, and event-catalog
reconstruction. If a degraded-mode item depends on immutable gas assumptions
that can fail under a future gas schedule, the drill report must say so rather
than treating the guarantee as absolute.

Read-only museum mode is the explicit posture when all governance is lost.
Ownership, transfer, approvals, enumerable reads, retained token identity,
frozen/finalized metadata reads, royalty disclosure as configured, split-wallet
release, already-deployed-wallet escrow flush, finality verification ranges,
state-export discovery, and archived reconstruction should continue where their
immutable dependencies still work. New mint programs, pointer moves, economic
changes, metadata mutations, provider recovery, registry replacement, and
economics/artwork-affecting recovery halt unless fully precommitted before
quorum loss.

## Hash And Manifest Discipline

Every durable identity must be domain-separated and versioned.

`block.chainid` provides replay protection only. It does not establish fork
canonicality, because a contentious fork can preserve the same chain ID.
Canonical deployment and successor resolution are governance- and
manifest-declared, then observed through contract events and state exports.

Use `abi.encode`, not packed encoding, for:

- split profile IDs;
- primary template IDs;
- materialized profile metadata hashes;
- sale context hashes;
- royalty resolver assignment hashes;
- renderer manifests;
- metadata snapshots;
- view manifests;
- entropy request keys;
- entropy raw randomness compression;
- final entropy seed derivation;
- collection freeze manifests;
- versioned event catalog manifests.

Every offchain or externally fetched artifact that matters to artwork or
economics should have:

1. URI;
2. hash;
3. hash algorithm or schema version;
4. content type where relevant;
5. event trail for assignment and freeze.

The release artifact set must include a machine-readable event catalog with its
own hash. The catalog should list every event, schema version, indexed fields,
unindexed fields, semantic owner, deprecation status, and replacement event
when applicable. Successor declarations and deployment manifests must reference
the event catalog hash so indexers can prove which log vocabulary a deployment
used.

Protocol identity hashes are intentionally `keccak256`-fixed for their version.
Do not "upgrade" an existing profile ID, request key, seed, or assignment hash
to a different hash algorithm. Content and preservation hashes may be
algorithm-tagged for long-term agility:

```text
hashAlgorithm = HASH_KECCAK256 | HASH_SHA256 | HASH_BLAKE3 | HASH_MULTIHASH
```

Launch should not include a generic `OTHER` hash bucket. New hash algorithms
must be assigned explicit IDs through the append-only hash/canonicalization
registry and documented in a release manifest or successor schema.

The hash, canonicalization, schema, and enum ID spaces must have a launch
governing surface. The minimum acceptable launch posture is a manifest-pinned
numeric allocation file whose hash is included in `streamSystemManifest()` and
the release manifest. A stronger posture is an append-only registry satellite
with explicit IDs, URI/hash, status, and supersession links. Either way, new
IDs are additions; old IDs are never reinterpreted.

Manifest canonicalization:

1. Onchain identity manifests should prefer typed `abi.encode` structs.
2. Offchain JSON manifests that are hash-committed should use a documented
   canonical JSON profile such as RFC 8785/JCS, or another explicitly named
   canonicalization scheme.
3. Raw JSON fragments used in metadata must be either validated before storage
   or marked as admin-trusted with a stored hash and schema.
4. Omitted field, null field, empty string, and empty array/object semantics
   must be specified for every manifest family before launch.

Privacy and redaction are part of manifest design. Provenance records may
include sensitive camera, location, institution, estate, model-release, or
rights information. Schemas should distinguish public payloads, redacted
payloads, sealed archive commitments, and finalized artwork bytes. A hidden
private record must not be required to render or verify a public final artwork
unless the collection's manifest explicitly accepts that dependency.
Sealed or redacted archival material needs an offchain custody and succession
policy: who may access it, rotate keys, attest to fixity, release it to an
institution or estate, or declare it lost. Onchain records should commit to the
sealed payload and custody policy hash without exposing secret material.

Signature suites are also time-bounded evidence. EIP-712, ERC-1271, W3C
Verifiable Credentials, DIDs, C2PA signatures, institutional attestations, and
archive receipts should record signature suite, public-key material reference,
verification method, timestamp, and signed payload hash. Old signatures remain
historical evidence under the suite used when recorded; future post-quantum or
successor signature suites should be added as new attestations or verification
bundles rather than rewriting old signatures. Preservation drills should
periodically re-attest finality-critical records under the current best
signature suite before an older suite is considered practically broken.

## Compatibility Matrix

Every assignment that connects two modules must verify compatibility at
assignment time.

Examples:

1. A metadata router can assign a renderer only if the renderer supports the
   configured render context version.
2. A collection metadata record can select a renderer only if its declared
   schema/compatibility range includes that renderer family.
3. An entropy coordinator can be assigned only if the metadata router supports
   the entropy view interface it exposes.
4. A revenue resolver can assign a split wallet only if the factory, wallet
   version, profile schema, and runtime code hash are approved.
5. A Core pointer update can execute only if the target module supports the
   expected interface ID and module type.

Optional interface:

```solidity
function supportsStreamModule(
    bytes32 moduleType,
    bytes32 moduleVersion,
    bytes32 contextVersion
) external view returns (bool);
```

Each deployment manifest must include a full compatibility-matrix snapshot:
one canonical hash over every approved module family, version, interface ID,
runtime code hash, registry status, and approved pair or exclusion. Pairwise
checks are necessary but not enough; future auditors need a single "these
versions were jointly blessed" artifact.

Cross-contract authority interfaces whose selectors are part of a release
manifest should use selector-stable parameter lists: value types, addresses,
fixed bytes, `bytes`, and `bytes32` commitments where practical. If a struct is
used in an external interface, the release manifest must pin the full canonical
signature, selector, ABI encoding, compiler version, and test vector so a
future compiler or language change cannot silently alter the contract between
modules.

Every deployed satellite should publish reproducible-build preservation data:
compiler version, optimizer settings, metadata hash mode, source bundle hash,
ABI hash, deployed bytecode, constructor arguments, linked libraries, runtime
code hash, creation code hash, compiler binary or container/Nix lock URI/hash,
Sourcify/Etherscan or successor verification status, verifier output hash, and
mirrored source archive URI/hash.

## Maximum On-Chain Options

The architecture should leave room for every reasonable long-term on-chain or
verifiable mode without putting all of them in launch Core.

Allowed storage and resolution families:

```text
INLINE_CHUNKS       simple launch path for scripts and small JSON fragments
SSTORE2             large write-once payloads
ETHFS               shared onchain web assets
DEPENDENCY_REGISTRY shared JavaScript/library dependencies
ERC-4804/6860       raw onchain web views if product requires them
IPFS                content-addressed offchain storage
ARWEAVE             durable offchain archive storage
HTTPS               mutable or service-backed URI, only with explicit trust
CCIP_READ           verified offchain or L2-backed reads
WEB3_CALL           future onchain composable views
```

Rules:

1. Core must not care which source family a payload uses.
2. Launch may use inline chunks for auditability.
3. Offchain sources that matter to final artwork should carry hash commitments.
4. Mutable HTTPS is acceptable only when the product intentionally wants a
   mutable or service-backed surface and the metadata says so.
5. Future storage families should be added as metadata/renderer modules, not
   as Core rewrites.

Open-ended collections create unbounded state by design. Core stores
token-to-collection mappings, collection serials, enumerable ownership state,
and entropy/request facts for every token. Token-level royalty snapshots,
token-level metadata overrides, and token-level preservation records should be
opt-in because they add per-token storage for potentially decades. Release
manifests should publish expected per-token storage writes and gas for the
default path, snapshot path, and token-override path, and future statelessness,
Verkle, or chain-migration strategies must preserve the explicit mapping model
rather than relying on token ID arithmetic.

Frozen onchain collections must publish a snapshot manifest hash over the
assembled script, dependency, and media payloads. This protects preservation
even if future RPC providers or gas limits make live `tokenURI()` rendering
difficult.

## Economics Boundary

Primary sales, royalties, curator rewards, refunds, and protocol surplus are
separate accounting domains.

Rules:

1. Primary revenue settlement is authoritative at sale settlement time.
2. Royalty disclosure is best-effort ERC-2981 at marketplace read time.
3. Royalty payment remains voluntary unless a separate enforcement design is
   accepted.
4. Recipient payments are pull-based.
5. Passive receipts and forced ETH must not become emergency surplus.
6. Split profiles are immutable; assignments choose which profile applies.
7. Future wallet versions can support larger recipient sets, Merkle claims, or
   asset adapters, but each version needs a new identity preimage and tests.
8. Unsupported ERC-20 assets must not block native ETH or other assets.

Escrow boundary:

1. Funds held by a protocol escrow are owed by the escrow, not yet received by
   the split wallet.
2. Split wallet `observedReceived(asset)` excludes escrow-pending funds until
   those funds are actually deposited into the wallet.
3. Wallet-level conservation excludes `escrowOwed`.
4. System-level conservation is:

   ```text
   walletReleased + walletReleasable + walletDust + escrowOwed
     <= officialDeposits + passiveReceipts + directTransfers + forcedETH
   ```

5. Escrow flush moves value from `escrowOwed` into wallet-resident balance and
   must be idempotent.
6. Escrow incident recovery can reroute only escrow-held funds, not funds
   already resident in a split wallet.

Incident-revoked escrow recovery:

1. An incident-revoked wallet runtime code hash blocks new credits and normal
   flushes for affected escrow.
2. A timelocked successor-wallet reroute may move escrow credit to a new
   verified wallet only through a published recovery manifest.
3. The recovery manifest must identify affected credit keys, old wallet,
   successor wallet, old profile, successor profile, runtime hashes, reason,
   and whether economics are identical or intentionally changed by governance.
4. If economics change, the reason must be explicit and the delay should be
   longer than ordinary config updates.
5. The reroute transfers only owed escrow accounting and escrow-held funds. It
   cannot seize or move balances already held by the old split wallet.

## Entropy Boundary

Entropy is a provenance-critical subsystem, not a renderer helper.

Rules:

1. Core mints tokens and registers entropy state.
2. The entropy coordinator owns canonical request lifecycle.
3. Provider adapters provide raw entropy and source provenance only.
4. Final seed derivation is coordinator-owned, domain-separated, and versioned.
5. Each token can receive at most one successful entropy output.
6. Delivery retry uses already-received randomness.
7. Fresh entropy recovery is an incident path, not a normal retry.
8. Provider rotation uses epochs and cannot reinterpret pending requests.
9. Metadata exposes pending, finalized, stale, failed, and recovery states.
10. Future entropy systems are added as adapters after review, not by changing
    Core.

For v1 high-value collections, fresh entropy recovery after an accepted provider
request should be disabled unless a complete recovery policy is configured and
frozen before mint. A complete policy includes fallback provider list, order,
deadlines, max attempts, proof that no valid raw randomness was received, and
adapter result-status reads. Without that policy, a stalled request remains
stuck but honest rather than becoming a reroll.

## Metadata And Artwork Boundary

The durable artwork primitive is not only the current marketplace JSON.

The reconstructable bundle is:

```text
Core token and collection facts
collection metadata manifest
renderer manifest
render context version
script manifest
dependency manifest
media manifest
entropy seed and provenance
view/snapshot manifest, if any
freeze manifest
```

Rules:

1. `tokenURI()` remains marketplace-friendly.
2. Rich protocol facts live under namespaced `properties`.
3. Renderer output should be deterministic for a fixed config and token state.
4. Alternate views should not destabilize the default `tokenURI()` surface.
5. Metadata refresh events should originate from Core when marketplaces are
   expected to observe them.
6. Renderer deprecation must not break frozen historical collections.

Metadata failure model:

1. Mutable collections may move from a deprecated renderer/router to a new
   compatible module through staged governance.
2. Frozen collections keep their frozen renderer and manifests unless an
   accepted recovery manifest says otherwise.
3. Incident revocation of a renderer freezes new use and mutable assignment,
   but cannot silently alter frozen historical artwork.
4. A frozen snapshot route may be used only if it is bound by the original
   finality manifest or a published recovery manifest.

## Standards Drift

Over 50 years, standards and marketplace behavior will change.

The architecture should support:

- ERC-165 interface discovery;
- ERC-721 and ERC-721 Enumerable;
- ERC-721 Metadata;
- ERC-2981 royalty disclosure;
- ERC-4906 metadata updates;
- ERC-7572-style contract metadata when bytecode allows;
- optional token-bound accounts;
- optional dynamic traits;
- optional multi-view metadata;
- optional CCIP Read or verified offchain reads;
- optional raw onchain web views.

Support for optional standards should live in satellites unless the standard is
part of the permanent NFT identity surface. New standards should be adopted by
adding module versions, renderer versions, or read adapters, not by weakening
Core invariants.

Core's `supportsInterface` set is part of the permanent Core surface. If a
future royalty, metadata, or identity standard requires new Core interface
advertisement that cannot be safely added to the existing Core, adoption should
use a successor Core declaration rather than pretending a satellite can change
old Core's ERC-165 truth.

## Governance And Operations

Governance should be boring, evented, and recoverable.

Required practices:

1. Use multisigs or equivalent durable governance for production roles.
2. Use two-step or timelocked changes for default-scope economics, renderer
   registries, entropy providers, and global freezes.
3. Emit reason URIs or content hashes for material changes.
4. Maintain runbooks for resolver failure, metadata incident, renderer
   deprecation, entropy provider incident, ERC-20 unsupported assets, and split
   wallet runtime-code revocation.
5. Keep all emergency actions scoped to the affected subsystem.
6. Never give emergency admins a path to sweep owed funds.
7. Treat fallback-to-zero royalty behavior, metadata router failure, and
   entropy request stalls as incidents requiring monitoring.

Royalty resolver readiness is a launch gate. Before public sale, governance
should stage, execute, and optionally freeze or timelock the resolver pointer;
operator tooling should run a non-view diagnostic probe that records resolver
health, configured defaults, gas behavior, and fallback-to-zero incidents.

Example diagnostic surface:

```solidity
function probeRoyaltyInfo(uint256 tokenId, uint256 salePrice)
    external
    returns (
        bool resolverCallSucceeded,
        address receiver,
        uint256 amount,
        bytes32 assignmentHash,
        bytes32 failureReason
    );
```

The probe is not used by marketplaces. It exists so operators can emit and
monitor incident evidence that `royaltyInfo()` itself cannot emit because it is
`view`.

```solidity
event RoyaltyInfoProbed(
    uint16 schemaVersion,
    uint256 indexed tokenId,
    address indexed receiver,
    uint256 royaltyAmount,
    bool resolverCallSucceeded,
    bytes32 assignmentHash,
    bytes32 failureReason
);
```

Diagnostics are operational tools, not permanent marketplace surfaces. If a
diagnostic such as `probeRoyaltyInfo`, full `verifyFinality`, or a catalog
consistency read becomes impractical under future gas schedules, the successor
manifest or release manifest must deprecate that diagnostic, point to a range
or offchain-verifiable replacement, and keep old selectors documented for
historical deployments. Production `royaltyInfo()` and `tokenURI()` behavior
must not depend on deprecated diagnostics.

## Observability

Every subsystem should expose both reads and events.

Minimum cross-cutting observability:

1. active module addresses and versions;
2. active, deprecated, and incident-revoked implementation/code-hash states;
3. default/collection/token assignment reads;
4. freeze state reads;
5. event reconstruction for every assignment mutation;
6. token-level final artwork provenance;
7. pending/stale/failed entropy dashboards;
8. payment owed, released, observed, escrowed, and unsupported asset states;
9. Core bytecode size and interface support checks in release artifacts.

Events are not enough by themselves. Critical current state also needs direct
view functions.

Event indexing policy:

1. Every event gets at most three indexed fields.
2. Each spec must name the canonical indexed fields for events used by
   indexers.
3. Non-indexed fields must still include the data needed for replay.
4. If an event has more than three natural query keys, the spec should name the
   primary query path and require secondary indexes off-chain.

## Failure And Recovery

The launch architecture should define failure modes before they occur.

Expected failure classes:

```text
resolver unavailable
resolver malformed return
split wallet wrong code at predicted address
split wallet runtime incident
unsupported ERC-20 asset
metadata router unavailable
renderer deprecated or unsafe
offchain payload unavailable
entropy provider stalled
entropy provider compromised
randomness callback stale
admin key or governance process compromised
marketplace cache divergence
```

Recovery principles:

1. Fail closed for mutation paths.
2. Fail safe for marketplace reads where reverting could break transfers or
   sales, such as `royaltyInfo()`.
3. Keep owed funds owed.
4. Make every incident path evented and reasoned.
5. Use predeclared fallbacks when outcomes could be manipulated.
6. Avoid hidden rerolls, hidden metadata swaps, or hidden payment reroutes.
7. Publish migration/reroute specs before moving stranded funds or changing
   frozen artwork/economics.

## Release Gates

No subsystem should be considered launch-ready until these gates pass.

Core gates:

1. `forge build`.
2. Core bytecode below EIP-170 with documented headroom after each extraction
   and again after Core-native ERC-2981 is added.
   CI should fail if Core runtime bytecode exceeds 22,000 bytes unless a
   launch-blocking governance review accepts a new ceiling with rationale.
3. interface IDs verified.
4. ERC-721 enumerable behavior unchanged.
5. Core-native ERC-2981 tested under resolver failure.

Revenue gates:

1. split profile identity fuzz tests;
2. release accounting fuzz tests;
3. forced ETH and passive receipt tests;
4. escrow credit/flush tests;
5. ERC-20 unsupported/deprecated state tests;
6. primary settlement CEI and no-recipient-blocking tests.

Metadata gates:

1. JSON escaping tests;
2. script assembly determinism tests;
3. renderer manifest tests;
4. metadata refresh event tests;
5. freeze and override tests;
6. large payload gas/RPC envelope tests.
7. artwork finality freeze proves renderer, manifests, and entropy policy are
   jointly locked.
8. onchain collection finality is blocked unless the snapshot manifest hash has
   been recorded.

Entropy gates:

1. request lifecycle tests;
2. provider adapter tests;
3. stale callback tests;
4. no-reroll recovery tests;
5. provider-epoch tests;
6. active and backup/safe-mode coordinator registration tests;
7. monitoring/runbook dry run.

Governance gates:

1. role matrix reviewed;
2. timelock/two-step changes tested where used;
3. emergency actions prove no owed-fund sweep;
4. event and view reconstruction tests.
5. genesis role assignment proves no single EOA can execute material actions;
6. deployment manifest includes event catalog hash, ABI checksums, module
   manifest hashes, bytecode sizes, and governance delay configuration.

## Accepted Tradeoffs

1. Satellite contracts add integration complexity, but protect Core from
   decades of changing policy.
2. Pull payments require recipients to claim, but protect settlement from
   recipient behavior.
3. Core-native ERC-2981 costs bytecode, but is necessary for marketplace
   compatibility and should be protected by moving other logic out.
4. Freeze controls reduce future flexibility, but create credible permanence
   when used.
5. Hash commitments make offchain artifacts verifiable, but do not guarantee
   every future client will fetch or display them.
6. Provider-adapter optionality adds operational work, but avoids betting the
   entire protocol life on one randomness vendor.

## Recommended Pre-Launch Order

1. Extract metadata router and renderer from Core.
2. Extract collection metadata storage from Core.
3. Extract entropy coordination from Core.
4. Implement revenue resolver and split wallets.
5. Add minimal resolver-backed Core ERC-2981.
6. Run bytecode and interface gates.
7. Freeze launch module manifests and deployment runbooks.
8. Gather marketplace, indexer, and rendering evidence before public claims.

This order maximizes Core headroom before adding mandatory ERC-2981 and keeps
the riskiest mutable policies in satellite contracts from day one.
