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
  - tokenURI and contractURI public surfaces
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
2. Staging uses a two-step operation with an operation ID:

   ```solidity
   bytes32 operationId = keccak256(abi.encode(
       STREAM_POINTER_OPERATION_V1,
       block.chainid,
       address(core),
       bytes32(pointerType),
       address(oldTarget),
       address(newTarget),
       bytes32(newTargetCodeHash),
       bytes32(newTargetManifestHash),
       uint64(notBefore),
       bytes32(reasonHash)
   ));
   ```

3. Every staged operation emits old target, new target, code hash, manifest
   hash, earliest execution time, actor, and reason URI/hash.
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

Required events:

```solidity
event CoreSatellitePointerStaged(
    bytes32 indexed pointerType,
    address indexed oldTarget,
    address indexed newTarget,
    bytes32 operationId,
    bytes32 newTargetCodeHash,
    bytes32 newTargetManifestHash,
    uint64 notBefore,
    string reasonURI
);

event CoreSatellitePointerUpdated(
    bytes32 indexed pointerType,
    address indexed oldTarget,
    address indexed newTarget,
    bytes32 operationId
);

event CoreSatellitePointerFrozen(
    bytes32 indexed pointerType,
    address indexed target,
    bytes32 operationId,
    bytes32 targetCodeHash,
    bytes32 manifestHash
);
```

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
    bytes32 finalityManifestHash,
    string calldata finalityManifestURI
) external;
```

Every participating satellite must expose a finality read surface:

```solidity
struct FinalityComponentState {
    bool frozen;
    bytes32 componentType;
    address component;
    bytes32 interfaceId;
    bytes32 codeHash;
    bytes32 moduleVersion;
    bytes32 manifestHash;
    bytes32 dataHash;
}

struct FinalityComponentExpectation {
    bytes32 componentType;
    address component;
    bytes32 interfaceId;
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
```

The finality registry stores:

```solidity
struct CollectionFinalityRecord {
    bool finalized;
    bytes32 finalityManifestHash;
    string finalityManifestURI;
    bytes32 componentsHash;
    uint64 finalizedAt;
}

mapping(uint256 collectionId => CollectionFinalityRecord) finalityRecords;
mapping(uint256 collectionId => FinalityComponentExpectation[]) finalityComponentExpectations;
```

`componentsHash` is `keccak256(abi.encode(components))`. The registry computes
the finality hash onchain:

```solidity
bytes32 finalityManifestHash = keccak256(abi.encode(
    STREAM_FINALITY_V1,
    block.chainid,
    address(core),
    collectionId,
    coreCollectionFactsHash,
    componentsHash,
    keccak256(bytes(finalityManifestURI))
));
```

The offchain `finalityManifestURI` must include the same component list and any
richer human-readable reconstruction data, but onchain verification uses only
the typed `components` calldata and live component reads. The registry cannot
and must not try to parse `finalityManifestURI` onchain.

Component discovery path:

1. The registry is bound to one Core.
2. Core exposes current pointers for `COLLECTION_METADATA`,
   `METADATA_ROUTER`, `ENTROPY_COORDINATOR`, and other Core-owned satellites.
3. The metadata router exposes finality discovery reads for the resolved
   renderer, dependency source, media/source modules, and any snapshot route for
   `collectionId`.
4. Each discovered component implements `IStreamFinalityComponent` or is wrapped
   by a small finality adapter that reports the required state.
5. `finalizeCollectionArtwork` reverts unless the submitted component list
   exactly matches the discovered components and every live
   `FinalityComponentState` equals the corresponding expectation with
   `frozen = true`.
6. After finality, `finalityRecords(collectionId)` and
   `finalityComponents(collectionId, start, limit)` read from
   `finalityComponentExpectations` to provide the durable onchain record and
   allow future tools to check whether live components still match.
7. Finality either freezes the relevant collection-scoped Core pointers in the
   same action or records the collection as address-pinned. If a later global
   pointer move occurs, `verifyFinality(collectionId)` must still compare
   against the address/codehash captured in the finality record and return
   false for the current route unless a public recovery manifest supersedes it.

Required component types include at least:

```text
CORE_FACTS
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

Finality is not valid if any required component is merely promised frozen
offchain.
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
3. A read function returns the finality manifest hash and whether all component
   modules still match it.
4. Incident recovery cannot silently swap final artwork. It must publish a new
   recovery manifest and preserve the original finality manifest.
5. Frozen renderers may be deprecated for new collections, but they must keep
   serving historical frozen collections or a hash-bound snapshot route.
6. Onchain and hybrid collections cannot be finalized unless a snapshot
   manifest hash covering assembled script bytes, dependency payloads, renderer
   context, metadata root, media hashes, and entropy policy has already been
   recorded in the collection metadata contract.

Recommended event:

```solidity
event CollectionArtworkFinalized(
    uint256 indexed collectionId,
    bytes32 indexed finalityManifestHash,
    address indexed actor,
    bytes32 componentsHash,
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
        bytes32 finalityManifestHash,
        bytes32 componentsHash
    );
```

### Finality Recovery

Artwork-finality recovery is a governed state machine:

```solidity
event FinalityRecoveryScheduled(
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    bytes32 oldFinalityManifestHash,
    bytes32 newRecoveryManifestHash,
    uint64 executeAfter,
    bytes32 reasonHash
);

event FinalityRecoveryCancelled(
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    bytes32 reasonHash
);

event FinalityRecoveryExecuted(
    uint256 indexed collectionId,
    bytes32 indexed recoveryId,
    bytes32 newRecoveryManifestHash
);
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

Recommended aggregate read:

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
        bytes32 eventCatalogHash
    );
```

The manifest should include module addresses, versions, code hashes, registry
states, pointer freeze states, event catalog hash, and deployment chain IDs.

Core should also support a non-mutating successor declaration for long-term
identity continuity:

```solidity
event StreamCoreSuccessorDeclared(
    address indexed successorCore,
    bytes32 indexed successorManifestHash,
    string successorManifestURI
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
```

A successor declaration does not migrate tokens, transfer ownership, or change
the old Core. It is a public breadcrumb for future chain migrations, L2
successors, archival mirrors, or a post-EIP standards replacement.

Access control for `declareStreamCoreSuccessor` must use the ADR 0004
`SUCCESSOR_DECLARATION` governance class with the published delay, staged
operation ID, cancellation path, and reason URI/hash. It is not an emergency
bypass and cannot be executed by a narrow funds, metadata, entropy, or renderer
admin. The function may append to a successor history and expose the latest
declaration for convenience, but it must not mutate ERC-721 ownership, token
collection mappings, satellite pointers, royalty behavior, metadata behavior,
or freeze state.

The successor manifest must include old chain ID, old Core, new chain ID, new
Core, ownership snapshot hash, complete event-history snapshot hash,
collection-snapshot root, activation statement, and explicit old-Core status:
`ACTIVE`, `DEPRECATED_QUERYABLE`, or `DEPRECATED_ZERO_ROYALTIES`. Indexers must
not infer deprecation from the existence of a successor event alone.

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
Burned tokens are excluded from ownership roots after burn but included in
token-to-collection and collection-serial roots when Core retains their mapping.
Roots should be Merkle roots over sorted `(key, valueHash)` leaves with the leaf
schema named in the export manifest. The reference exporter can be maintained
offchain, but no export is canonical unless an independent indexer can reproduce
the same roots from archived chain data and the published event catalog.

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
publishes a compatibility report hash.

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

## Hash And Manifest Discipline

Every durable identity must be domain-separated and versioned.

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

Manifest canonicalization:

1. Onchain identity manifests should prefer typed `abi.encode` structs.
2. Offchain JSON manifests that are hash-committed should use a documented
   canonical JSON profile such as RFC 8785/JCS, or another explicitly named
   canonicalization scheme.
3. Raw JSON fragments used in metadata must be either validated before storage
   or marked as admin-trusted with a stored hash and schema.
4. Omitted field, null field, empty string, and empty array/object semantics
   must be specified for every manifest family before launch.

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
    uint256 indexed tokenId,
    address indexed receiver,
    uint256 royaltyAmount,
    bool resolverCallSucceeded,
    bytes32 assignmentHash,
    bytes32 failureReason
);
```

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
