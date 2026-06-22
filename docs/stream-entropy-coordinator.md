# Stream Entropy Coordinator

This document is a pre-launch target specification for moving randomness,
token seed finalization, and randomizer coordination out of `StreamCore` into a
dedicated entropy subsystem.

`StreamCore` should remain the canonical ERC-721 contract, keep
`ERC721Enumerable`, and own token minting, ownership, approvals, enumeration,
and token-to-collection identity. Entropy generation, provider callbacks,
request lifecycle, delivery retries, recovery policy, and final token seed
provenance should live outside Core.
The cross-cutting 50+ year architecture principles live in
`docs/stream-long-term-architecture.md`.

## Design Summary

```text
StreamCore
  - ERC-721 ownership and enumeration
  - token to collection identity
  - mint finality
  - minimal entropy coordinator hook
  - admin-controlled entropy coordinator pointer

StreamEntropyCoordinator
  - collection entropy configuration
  - provider approval and lifecycle
  - token entropy registration
  - request and fulfillment state machine
  - canonical seed derivation
  - delivery retry and recovery policy
  - entropy provenance events

StreamEntropyProvider adapters
  - Stream-native Chainlink VRF adapter
  - Stream-native ARRNG adapter, if deliberately retained
  - deterministic/pseudo provider only when explicitly configured
  - future provider adapters

StreamMetadataRouter / StreamRenderer
  - read token entropy status and seed
  - render pending metadata until seed finalizes
  - use finalized seed as the artist-facing token hash
```

The target architecture separates three concerns:

1. Core mints tokens.
2. Entropy Coordinator finalizes immutable token seeds.
3. Metadata Router and Renderer consume finalized seeds.

## Current Implementation Baseline

Today `StreamCore` stores the randomizer address and interface in
`collectionAdditionalData`:

```solidity
address randomizerContract;
IRandomizer randomizer;
```

An admin assigns a randomizer with `addRandomizer(collectionId, randomizer)`.
During mint, Core calls:

```solidity
collectionAdditionalData[collectionId].randomizer.calculateTokenHash(
    collectionId,
    tokenId,
    salt
);
```

The randomizer later calls back to Core:

```solidity
setTokenHash(collectionId, tokenId, hash);
```

Core then stores `tokenToHash[tokenId]`, uses zero as the pending sentinel, and
the renderer injects that value into the token script as `hash`.

This works, but it braids minting, randomizer trust, provider-specific callback
logic, token seed storage, pending state, and rendering together inside Core.
The scratch compile showed that moving randomizer/hash coordination out of Core
after the larger metadata refactors saves about `1 KB` of runtime bytecode.
The bigger win is architectural: entropy becomes explicit, auditable,
provider-agnostic, retryable, and durable.

## Provider Design Decision

The current `NextGenRandomizerNXT`, `NextGenRandomizerRNG`, and
`NextGenRandomizerVRF` contracts are useful historical reference material, but
they should not be treated as the production Stream entropy provider layer.

Their current shape is:

```text
randomizer receives or derives randomness
  -> randomizer hashes it into a token hash
  -> randomizer calls StreamCore.setTokenHash(...)
  -> StreamCore stores tokenToHash
```

The target Stream shape is:

```text
provider adapter receives raw randomness
  -> provider adapter reports raw randomness to StreamEntropyCoordinator
  -> StreamEntropyCoordinator derives the canonical token seed
  -> metadata reads seed/status from StreamEntropyCoordinator
```

The launch implementation should build Stream-native provider adapters rather
than reuse the NextGen randomizers as-is.

Assessment of current contracts:

```text
NextGenRandomizerNXT
  - reference only, or explicit low-assurance instant/pseudo mode after review
  - not equivalent to verifiable randomness

NextGenRandomizerRNG
  - possible reference for an ARRNG adapter
  - not production-ready as-is because it calls Core directly and lacks the
    coordinator lifecycle, delivery retry, provenance, and seed derivation model

NextGenRandomizerVRF
  - right provider family for launch
  - should be rewritten as StreamEntropyProviderVRF rather than reused as-is
```

Provider adapters should supply entropy. The coordinator should define the
final canonical seed.

## NextGen And ADR 0005 Lessons

The earlier NextGen randomizer design made one strong architectural move that
Stream should keep: Core did not try to understand every randomness provider.
It delegated per-collection randomness to pluggable adapters and stored one
final token hash. That kept Core smaller and made VRF/arRNG/NXT experimentation
possible.

The serious follow-up discussion around ADR 0005 and the lifecycle hardening
work showed where that shape was incomplete for long-lived production
collections. Async randomness is not just "a randomizer eventually calls
Core." It is a request lifecycle with identities, epochs, stale callbacks,
terminal fulfillment, retry policy, and provider operations.

This spec keeps the good part of NextGen, provider pluggability, but moves the
canonical lifecycle into a first-party coordinator instead of relying on
adapter-private mappings plus `StreamCore.setTokenHash`.

Required lessons to preserve:

1. A token can receive at most one successful entropy output. The token's
   request binding must not be cleared after fulfillment, stale marking, burn,
   or failure in a way that enables a quiet redraw.
2. Every request must bind collection ID, token ID, provider, provider request
   ID, provider epoch, request attempt, request-time config, and immutable
   mint inputs.
3. The coordinator owns canonical request state. Provider adapters may mirror
   provider-specific IDs, but protocol correctness must not depend only on
   adapter-private storage.
4. Provider or config replacement creates a new provider epoch. Pending
   requests from an old provider or epoch must be fulfilled under their
   original policy, marked stale, or handled by an explicit incident recovery.
   They must not silently become requests for the new provider.
5. Ordinary provider migration should be blocked while requests are pending
   unless the collection precommitted a fallback or governance declares an
   incident.
6. Fulfillment validates request key, provider request ID, token, collection,
   provider, provider epoch, token existence or documented burned-token path,
   and "not already finalized" before any seed is finalized.
7. The first valid fulfillment is terminal. Late, duplicate, wrong-provider,
   or wrong-epoch callbacks are stale/audit events, not mutation paths.
8. Retry means deterministic delivery or post-processing retry with the same
   already-received randomness. It must not mean asking for a different random
   output.
9. Provider callbacks store the raw result or compressed raw result before
   calling the coordinator. Raw provider outputs should be emitted for audit
   where practical; contract storage can keep compact hashes.
10. Providers with request IDs returned after an external call, such as the
    historical arRNG integration shape, need an explicit reentrancy guard or
    pre-reserved local request record so a callback cannot arrive before the
    request is bound.
11. NXT-style block-derived randomness is historical or low-assurance only. It
    is not production-equivalent to VRF or another reviewed async provider.
12. Metadata must expose enough state for pending, finalized, stale, failed,
    and incident-recovery paths so collectors and operators can tell the
    difference between "waiting", "final", and "requires attention".

## Goals

1. Keep `StreamCore` small and stable.
2. Keep `ERC721Enumerable` in Core.
3. Remove randomizer provider details from Core.
4. Remove token seed/hash storage from Core.
5. Avoid using `bytes32(0)` as a pending sentinel.
6. Make token entropy status explicit.
7. Finalize each token seed exactly once.
8. Make seed derivation domain-separated and versioned.
9. Support synchronous and asynchronous entropy providers through adapters.
10. Preserve strong event provenance for requests, fulfillments, delivery
    retries, recovery attempts, and provider decisions.
11. Allow future entropy providers without redeploying the NFT Core.
12. Give metadata rendering a stable seed/status read interface.
13. Support long-lived collections where provider infrastructure may change
    over decades.

## Non-Goals

1. The entropy coordinator does not mint, burn, transfer, approve, or enumerate
   ERC-721 tokens.
2. The entropy coordinator does not build token metadata JSON or HTML.
3. The entropy coordinator does not own script storage or dependency storage.
4. The entropy coordinator does not make primary-sale or royalty decisions.
5. The entropy coordinator does not enforce marketplace behavior.
6. The entropy coordinator does not use upgradeable proxy mutability as its
   default safety mechanism.

## Core Contract Changes

Core should remove:

```solidity
address randomizerContract;
IRandomizer randomizer;
mapping(uint256 => bytes32) tokenToHash;
addRandomizer(...)
setTokenHash(...)
retrieveTokenHash(...)
```

Core should store one entropy coordinator pointer:

```solidity
IStreamEntropyCoordinator public entropyCoordinator;
```

Core should emit:

```solidity
event EntropyCoordinatorUpdated(
    address indexed oldCoordinator,
    address indexed newCoordinator
);
```

Core's mint flow should register the token with the coordinator after the token
identity is known:

```solidity
function _mintProcessing(
    uint256 tokenId,
    address recipient,
    string memory tokenData_,
    uint256 collectionId,
    bytes32 mintCommitment
) internal {
    tokenData[tokenId] = tokenData_;
    tokenCollectionId[tokenId] = collectionId;
    tokenCollectionMappingExists[tokenId] = true;
    entropyCoordinator.onTokenMinted(
        collectionId,
        tokenId,
        recipient,
        mintCommitment
    );
    _safeMint(recipient, tokenId);
}
```

The final implementation may keep the current `_saltfun_o` parameter name for a
short transition during development, but the production interface should treat
this value as a typed `bytes32 mintCommitment` or remove it if not used. Since
Stream is pre-launch, the preferred path is a clean production signature.

`onTokenMinted` must register token entropy state before any external receiver
callback can observe the freshly minted token. If `_safeMint` later reverts, the
whole transaction reverts and the entropy registration is unwound with it.

`onTokenMinted` must be a bounded internal-protocol registration call. It must
not call the configured provider, request randomness, finalize a seed, or depend
on external randomness provider uptime. Actual randomness requests happen only
through an idempotent request function on the coordinator after token state is
registered and `mintFromManager` has returned. A safe receiver callback may
therefore observe `REGISTERED` or pending entropy state; metadata must render
pending output honestly until a seed is finalized.
Core calls `onTokenMinted` with a deploy-time immutable
`ENTROPY_REGISTRATION_GAS_LIMIT` and an EIP-150-aware parent gas precheck.
Initial planning target is 80,000 gas for all-cold registration, but launch
must use measured gas plus margin and publish the value in the release
manifest. If the coordinator call reverts, runs out of its cap, or returns
malformed success behavior, the mint reverts and all token identity writes
unwind. Core must not forward all remaining gas to a mutable coordinator.

If Core exposes `prepareMintFromManager`, the prepare step calls
`onTokenMinted` and writes the same entropy registration state, but Core also
marks the token prepared-incomplete until `completePreparedMintFromManager`
clears that record. `requestEntropy(tokenId)` must consult Core's token status
or receive an equivalent Core-authenticated flag and revert for
prepared-incomplete tokens. A token cannot request entropy, finalize entropy,
or produce final metadata between prepare and complete.
For `PREPARED_MINT`, the first valid public or operator `requestEntropy` window
opens only after `completePreparedMintFromManager` has finished and the token is
no longer prepared-incomplete. A sale that needs both token-level economics and
async entropy must snapshot economics, record revenue, complete `_safeMint`,
and only then allow entropy request.
Any entropy registration event emitted during prepare must be explicitly marked
`preparedIncomplete = true`, or the event must be deferred until completion.
If the top-level transaction reverts, provisional registration events disappear
with the revert. `tokenEntropy` reads for a prepared-incomplete token must
disclose that status so satellites do not confuse it with an ordinary minted
token.

Coordinator availability is a hard mint prerequisite. Core should not catch and
ignore a failed `onTokenMinted` call because that would create minted tokens
without authoritative entropy state. Launch operations must therefore include a
pre-approved, registry-approved, write-capable backup or safe-mode coordinator
that can be staged or emergency-switched under the Core Satellite Pointer Policy
if the active coordinator is incident-revoked. Safe-mode may register tokens and
leave them `REGISTERED` without requesting provider randomness, but it must not
silently mint unregistered tokens.

## Coordinator Constructor

`StreamEntropyCoordinator` should be bound to one Core and one admin contract:

```solidity
constructor(address streamCore, address streamAdmins)
```

The coordinator should reject arbitrary Core addresses in write paths. A
single-purpose coordinator is easier to reason about, audit, and index than a
multi-Core coordinator.

## Interfaces

### Coordinator Write Interface

```solidity
interface IStreamEntropyCoordinator {
    function onTokenMinted(
        uint256 collectionId,
        uint256 tokenId,
        address recipient,
        bytes32 mintCommitment
    ) external;

    function requestEntropy(uint256 tokenId)
        external
        payable
        returns (bytes32 requestKey, uint256 providerRequestId);

    function fulfillEntropy(bytes32 requestKey, bytes32 rawRandomness) external;
}
```

`onTokenMinted` is callable only by Core.

`requestEntropy` should be callable according to collection policy. The
recommended launch policy is: minter, entropy admin, global admin, or anyone if
the collection explicitly enables public requests.

`fulfillEntropy` is callable only by the provider currently assigned to the
active request key.

### Coordinator Read Interface

```solidity
interface IStreamEntropyView {
    function tokenEntropy(uint256 tokenId)
        external
        view
        returns (
            EntropyStatus status,
            bytes32 seed,
            address provider,
            uint32 providerEpoch,
            bytes32 providerConfigHash,
            bytes32 requestKey,
            uint256 providerRequestId,
            uint16 requestAttempt
        );

    function tokenSeed(uint256 tokenId)
        external
        view
        returns (bytes32 seed, bool finalized);

    function tokenEntropyStatus(uint256 tokenId)
        external
        view
        returns (EntropyStatus status);

    function collectionEntropyConfig(uint256 collectionId)
        external
        view
        returns (CollectionEntropyConfig memory);

    function entropyPolicyFrozen(uint256 collectionId)
        external
        view
        returns (
            bool frozen,
            bytes32 policyManifestHash,
            address provider,
            uint32 providerEpoch,
            bytes32 collectionSaltCommitment
        );
}
```

Metadata contracts should consume `tokenSeed` or `tokenEntropy`. They should
not read entropy from Core storage.

`entropyPolicyFrozen(collectionId)` is the finality-facing read. It tells Core,
metadata tooling, and archives whether the collection's provider family,
provider epoch, configuration hash, collection salt commitment, and permitted
post-finality entropy behavior have been frozen. Artwork finality must capture
this policy manifest hash; a finalized collection cannot silently move to a new
provider epoch or salt commitment.

### Provider Interface

Provider adapters should implement:

```solidity
interface IStreamEntropyProvider {
    function isStreamEntropyProvider() external view returns (bool);
    function streamEntropyProviderFamily() external pure returns (bytes32);
    function streamEntropyProviderVersion() external pure returns (bytes32);
    function streamEntropyProviderConfigHash() external view returns (bytes32);

    function quoteRequest(bytes calldata context)
        external
        view
        returns (uint256 fee);

    function requestEntropy(bytes32 requestKey, bytes calldata context)
        external
        payable
        returns (uint256 providerRequestId);

    function retryCoordinatorFulfillment(uint256 providerRequestId) external;

    function providerResultStatus(uint256 providerRequestId)
        external
        view
        returns (
            ProviderResultStatus status,
            bytes32 requestKey,
            bytes32 rawRandomnessHash,
            bool rawRandomnessReceived,
            bool delivered
        );
}
```

Provider adapters that receive external randomness callbacks, such as VRF, map
their provider-specific request ID back to the coordinator's `requestKey` and
call:

```solidity
coordinator.fulfillEntropy(requestKey, rawRandomness);
```

The coordinator should use `requestKey` as the canonical request identifier.
Provider request IDs are retained for provenance only.

`providerResultStatus` is required for incident analysis and fresh-recovery
safety. The coordinator and operator tooling must be able to distinguish "the
provider never accepted or never produced randomness" from "the provider
received raw randomness but delivery failed." Fresh entropy recovery cannot
proceed if the adapter reports that raw randomness was received for the old
provider request.

## Enums

```solidity
enum EntropyStatus {
    NONE,
    DISABLED,
    NOT_REQUIRED,
    REGISTERED,
    REQUESTED,
    FINALIZED,
    STALE,
    FAILED
}

enum EntropyMode {
    DISABLED,
    INSTANT,
    ASYNC
}

enum ProviderState {
    UNKNOWN,
    ACTIVE,
    DEPRECATED,
    INCIDENT_REVOKED
}

enum ProviderResultStatus {
    UNKNOWN,
    REQUESTED,
    RAW_RANDOMNESS_RECEIVED,
    DELIVERED,
    TERMINAL_STALE,
    TERMINAL_FAILED
}
```

`NONE` means the coordinator has no token entropy state. Renderers should treat
this as pending or unsupported depending on collection metadata policy.

`DISABLED` means the collection policy disables entropy for this token.

`NOT_REQUIRED` means the token's render path does not require entropy even
though the collection or system may support entropy for other tokens.

`DISABLED` and `NOT_REQUIRED` are terminal non-random states. They are never
represented by a `bytes32(0)` seed sentinel, and `requestEntropy` must revert
for both.

`REGISTERED` means Core minted the token and the coordinator knows it, but no
active randomness request exists.

`REQUESTED` means an active request exists.

`FINALIZED` means the canonical seed is immutable and should be used for
rendering.

`STALE` means the request no longer belongs to an eligible provider epoch or
collection policy. Stale requests are audit-visible and cannot finalize the
token unless an explicit recovery policy says otherwise.

`FAILED` means the active request was declared unrecoverable under the incident
policy. It does not imply a normal reroll is available.

## Storage Model

Recommended collection config:

```solidity
struct CollectionEntropyConfig {
    EntropyMode mode;
    address provider;
    uint32 providerEpoch;
    bytes32 collectionSalt;
    bytes32 providerConfigHash;
    bool frozen;
    bool publicRequestsEnabled;
    uint64 requestTimeoutBlocks;
    uint16 maxFreshRecoveryAttempts;
    bytes32 freshRecoveryPolicyId;
    bytes32 freshRecoveryPolicyHash;
}
```

Fresh recovery policy is separate from the main config because most launch
collections should not use it. If `maxFreshRecoveryAttempts > 0`, the linked
policy must exist and be frozen before public mint.

```solidity
struct FreshRecoveryStep {
    address provider;
    uint32 providerEpoch;
    bytes32 providerConfigHash;
    uint64 notBeforeBlocks;
    bool acceptLateOriginalFulfillment;
}

struct FreshRecoveryPolicy {
    bool exists;
    bool frozen;
    uint16 maxFreshRecoveryAttempts;
    address incidentDeclarer;
    bytes32 reasonSchemaHash;
    bytes32 policyManifestHash;
    FreshRecoveryStep[] steps;
}
```

The policy hash is deterministic:

```solidity
bytes32 stepsHash = keccak256(abi.encode(steps));

bytes32 freshRecoveryPolicyHash = keccak256(abi.encode(
    FRESH_RECOVERY_POLICY_DOMAIN,
    uint256(block.chainid),
    address(coordinator),
    bytes32(policyId),
    uint16(maxFreshRecoveryAttempts),
    address(incidentDeclarer),
    bytes32(reasonSchemaHash),
    bytes32(policyManifestHash),
    bytes32(stepsHash)
));
```

`steps` must be encoded as an ordered `FreshRecoveryStep[]` with `abi.encode`.
Packed encodings, JSON encodings, and display-order-dependent hashes are not
valid.

Recommended token state:

```solidity
struct TokenEntropy {
    EntropyStatus status;
    uint256 collectionId;
    address mintedTo;
    address provider;
    uint32 providerEpoch;
    bytes32 requestKey;
    uint256 providerRequestId;
    bytes32 rawRandomness;
    bytes32 seed;
    bytes32 mintCommitment;
    uint64 registeredAtBlock;
    uint64 requestedAtBlock;
    uint64 finalizedAtBlock;
    uint16 requestAttempt;
}
```

Recommended request state:

```solidity
struct EntropyRequest {
    uint256 tokenId;
    uint256 collectionId;
    address provider;
    uint32 providerEpoch;
    bytes32 providerConfigHash;
    uint16 requestAttempt;
    bool active;
}
```

Recommended mappings:

```solidity
mapping(uint256 collectionId => CollectionEntropyConfig) collectionConfigs;
mapping(uint256 tokenId => TokenEntropy) tokenEntropies;
mapping(bytes32 requestKey => EntropyRequest) requests;
mapping(address provider => ProviderState) providerStates;
mapping(bytes32 policyId => FreshRecoveryPolicy) freshRecoveryPolicies;
```

The coordinator must not use `seed == bytes32(0)` as a status check. Status is
the source of truth.

## Coordinator Replacement And State Continuity

Coordinator pointer replacement is an ADR 0004 `POINTER_REPLACEMENT` action.
Entropy state must survive pointer changes:

1. Core stores `coordinatorAtMint[tokenId]` when token identity is allocated.
   This is the authoritative coordinator for that token's entropy reads.
2. The metadata router reads `tokenSeed(tokenId)` and
   `tokenEntropy(tokenId)` from `coordinatorAtMint[tokenId]`, not blindly from
   the current live Core pointer.
3. The live Core `entropyCoordinator` pointer is used for new token
   registration and for request/fulfillment routing only for tokens whose
   `coordinatorAtMint` equals that live pointer.
4. Coordinator replacement is blocked while any collection has active
   `REQUESTED` entropy against the current coordinator unless an already-frozen
   fresh-recovery policy explicitly covers coordinator replacement for that
   collection.
5. The old coordinator remains deployed, non-self-destructible, and queryable
   indefinitely. Incident revocation can block new requests or fulfillments but
   must not make finalized seeds or request history unreadable.
6. A successor coordinator must not rederive or refinalize seeds for tokens
   registered under a previous coordinator.
7. Safe-mode coordinators write the same `TokenEntropy` shape, with status
   `REGISTERED` or a terminal non-random status, and expose the same read
   interface. Transitioning from safe-mode to a full coordinator affects only
   newly minted tokens unless a frozen recovery policy explicitly moves pending
   requests.
8. Deployment manifests list every prior coordinator, its code hash, status,
   and collections/tokens whose entropy reads remain pinned to it.

## Provider Registry

The coordinator should maintain provider lifecycle state:

```solidity
event EntropyProviderStateUpdated(
    address indexed provider,
    ProviderState oldState,
    ProviderState newState,
    string reasonURI
);
```

Provider behavior:

```text
ACTIVE             can be used for new collection configs and new requests
DEPRECATED         cannot be used for new configs, but existing requests may fulfill
INCIDENT_REVOKED   cannot be used for new configs or fulfillments unless a
                   specific recovery policy is approved
UNKNOWN            rejected
```

Deprecation is forward-looking. It should not strand already requested tokens.
Incident revocation is exceptional and should be accompanied by a documented
recovery path before launch tooling exposes it.

Collection provider epochs:

1. The coordinator should maintain a collection-level `providerEpoch`.
2. `providerEpoch` increments whenever the provider, provider config hash, or
   fallback policy changes.
3. Every request records the epoch in force when it was made.
4. Fulfillment checks the request's recorded epoch, not merely the collection's
   current provider address.
5. Replaced providers may fulfill requests from their original epoch only if
   the policy still allows old-epoch fulfillment.
6. Otherwise, old-epoch callbacks emit `StaleEntropyFulfillment` and do not
   mutate token seed.

## Recommended Launch Provider Policy

For launch, the default high-assurance provider should be a new Stream-native
VRF adapter:

```text
default high-assurance provider   StreamEntropyProviderVRF
launch fallback                   disabled unless a later launch ADR accepts one
future reviewed fallback          StreamEntropyProviderARRNG or other adapter
non-default / explicit only       instant or pseudo provider
future providers                  added as new adapters through registry
```

The coordinator produces the final canonical seed. Providers supply raw
randomness; they do not define the artist-facing token hash by themselves.

Recommended policy:

1. High-value fully generative collections should use
   `StreamEntropyProviderVRF` by default.
2. Launch should use VRF-only for production collections unless a separate ADR
   accepts a fallback before launch. ARRNG should be used only if the team
   deliberately chooses it for a collection or precommits it as a reviewed
   fallback.
3. Instant or pseudo providers should be disabled by default and enabled only by
   explicit collection configuration.
4. Instant or pseudo providers should include clear security assumptions in the
   collection provenance notes when used.
5. Provider and fallback choices should be configured and frozen before public
   minting begins for collections where entropy affects artwork.
6. Existing NextGen randomizer contracts may inform implementation, but should
   not be wired into production Core/Coordinator without being rewritten to the
   provider adapter interface and reviewed under this spec.
7. Launch should set fresh entropy recovery attempts to zero for VRF collections
   unless the recovery state machine has been separately audited. Delivery retry
   of already-received randomness may be enabled because it does not reroll.

## Collection Configuration

Admins configure collection entropy before minting:

```solidity
function configureFreshRecoveryPolicy(
    bytes32 policyId,
    uint16 maxFreshRecoveryAttempts,
    address incidentDeclarer,
    bytes32 reasonSchemaHash,
    bytes32 policyManifestHash,
    FreshRecoveryStep[] calldata steps
) external;

function freezeFreshRecoveryPolicy(bytes32 policyId) external;

event FreshRecoveryPolicyConfigured(
    bytes32 indexed policyId,
    bytes32 indexed policyHash,
    uint16 maxFreshRecoveryAttempts,
    address incidentDeclarer,
    bytes32 policyManifestHash
);

event FreshRecoveryPolicyFrozen(
    bytes32 indexed policyId,
    bytes32 indexed policyHash
);
```

Fresh recovery policies are configured before collection configs reference
them. A collection can use a policy only after it is frozen. Freezing a policy
means its step list, incident declarer, reason schema, max attempts, and
manifest hash cannot change. Updating any of those fields requires a new
`policyId`.

```solidity
function configureCollectionEntropy(
    uint256 collectionId,
    EntropyMode mode,
    address provider,
    bytes32 collectionSalt,
    bytes32 providerConfigHash,
    bool publicRequestsEnabled,
    uint64 requestTimeoutBlocks,
    uint16 maxFreshRecoveryAttempts,
    bytes32 freshRecoveryPolicyId
) external;
```

Rules:

1. `provider` must be active unless `mode == DISABLED`.
2. `requestTimeoutBlocks` must be nonzero for async providers.
3. `maxFreshRecoveryAttempts` must be bounded and should default to zero for
   high-value VRF collections.
4. If `maxFreshRecoveryAttempts > 0`, `freshRecoveryPolicyId` must point to an
   existing frozen `FreshRecoveryPolicy`, `freshRecoveryPolicyHash` must match
   that policy's current hash, and the policy must contain at least that many
   ordered recovery steps.
5. Config changes are forbidden after collection entropy is frozen.
6. For art collections that rely on entropy, collection entropy should be
   frozen before public mint starts.
7. After the first token is minted for a collection, changing entropy provider
   should be forbidden unless the collection explicitly configured a
   precommitted fallback mechanism.
8. Provider, provider config hash, or fallback policy changes increment
   `providerEpoch`.
9. Ordinary config changes are blocked while the collection has pending
   requests unless the change is an explicit incident action.
10. Config events must include the new provider epoch and provider config hash.

Freeze:

```solidity
function freezeCollectionEntropy(uint256 collectionId) external;
```

Freezing prevents provider, salt, mode, timeout, and recovery policy changes for
the collection.

## Token Registration Flow

```text
StreamMintManager / authorized settlement adapter
  calls StreamCore.mintFromManager(...)
    StreamCore assigns token to collection and serial
    StreamCore calls EntropyCoordinator.onTokenMinted(...)
      coordinator records REGISTERED state
      coordinator emits EntropyRegistered
    StreamCore mints ERC-721 token with _safeMint
```

`onTokenMinted` happens before `_safeMint`; a receiver callback must never
observe a token that lacks identity mapping and entropy registration.

`onTokenMinted` rules:

1. Caller must be Core.
2. Token must not already be registered.
3. Collection config must exist, or a default config must exist.
4. If config mode is `DISABLED` or the render path is `NOT_REQUIRED`, the
   coordinator must record an explicit terminal token entropy status. Disabled
   collections must not revert minting because no provider is configured, and
   renderers must treat the token as intentionally not entropy-backed. A no-op
   success that leaves no token entropy record is not launch-conformant.
5. If config mode is `INSTANT`, `onTokenMinted` still records only registered
   state. It does not request entropy or finalize a seed. `INSTANT` means a
   later `requestEntropy` call may finalize synchronously in that request
   transaction after Core mint registration has completed.
6. If config mode is `ASYNC`, status remains `REGISTERED` until
   `requestEntropy`.
7. In default `ASYNC` mode, `onTokenMinted` must not make any external call. It
   writes registration state and emits events only. External provider requests
   happen through `requestEntropy`.
8. In `INSTANT` mode, same-transaction fulfillment is allowed only if the
   provider path is pure, bounded, and makes no external calls; otherwise
   instant-like fulfillment must be a separate transaction after registration.

Event:

```solidity
event EntropyRegistered(
    uint256 indexed collectionId,
    uint256 indexed tokenId,
    address indexed mintedTo,
    bytes32 mintCommitment
);
```

## Mint Commitment Discipline

For collections where entropy affects artwork, `mintCommitment` must not be an
attacker-chosen value after randomness-relevant state is observable. The active
mint policy must define who supplies it and when it is fixed.

Rules:

1. For async VRF-style collections, `mintCommitment` may bind sale, token data,
   buyer, beneficiary, phase, and nonce, but it must be included in the signed
   mint or sale authorization before mint execution. For batch mints, the exact
   per-token commitment passed to Core must equal the corresponding element
   committed by `MintTicket.mintCommitmentsHash` or by an equivalent sale
   authorization hash.
2. For instant-mode collections, `mintCommitment` must either be fixed before
   any outcome-affecting state is known to the executor or be excluded from the
   final seed derivation.
3. Executors, posters, or buyers must not be able to grind `mintCommitment` in
   the same transaction after seeing provider output or token serial.
4. Tests must prove an executor cannot bias instant-mode outcomes by varying
   `mintCommitment`.

## Request Flow

```text
requestEntropy(tokenId) [nonReentrant]
  verifies token is REGISTERED, or STALE/FAILED with approved incident recovery
  rejects prepared-incomplete tokens and terminal DISABLED/NOT_REQUIRED tokens
  rejects if token is already REQUESTED or FINALIZED
  resolves collection config and provider
  snapshots provider epoch and provider config hash
  builds requestKey
  stores active request and marks token REQUESTED before any provider call
  calls provider.requestEntropy{value: msg.value}(requestKey, context)
  stores providerRequestId
  emits EntropyRequested
```

`requestKey` should be derived with `abi.encode`, not packed encoding:

```solidity
bytes32 requestKey = keccak256(abi.encode(
    STREAM_ENTROPY_REQUEST_V1,
    block.chainid,
    address(this),
    streamCore,
    collectionId,
    tokenId,
    provider,
    providerEpoch,
    providerConfigHash,
    requestAttempt
));
```

Request context passed to providers should be compact and versioned:

```solidity
bytes memory context = abi.encode(
    uint16(1),          // context schema version
    streamCore,
    collectionId,
    tokenId,
    providerEpoch,
    providerConfigHash,
    requestAttempt
);
```

Event:

```solidity
event EntropyRequested(
    uint256 indexed collectionId,
    uint256 indexed tokenId,
    address indexed provider,
    bytes32 requestKey,
    uint256 providerRequestId,
    uint32 providerEpoch,
    bytes32 providerConfigHash,
    uint16 requestAttempt
);
```

Native ETH request payments:

1. `requestEntropy` may be payable for providers that need native ETH.
2. The coordinator should quote or compute the required provider payment before
   the provider call.
3. Launch v1 should reject `msg.value` greater than the required payment rather
   than hold or refund excess ETH. If a later provider requires refund behavior,
   the refund path must be explicit, bounded, non-reentrant, and evented.
4. The coordinator should not become a general ETH custody contract.
5. Accidental or forced ETH recovery, if included, should be admin-only,
   evented, and sent to a protocol treasury address.

Request transition guards:

1. `requestEntropy` must use a reentrancy guard or equivalent state lock.
2. The only normal starting status is `REGISTERED`.
3. `STALE` or `FAILED` can start a new request only through an approved fresh
   recovery path, with `requestAttempt` incremented and a new request key.
4. `DISABLED`, `NOT_REQUIRED`, `REQUESTED`, and `FINALIZED` always revert for
   ordinary `requestEntropy`.
5. Before any provider call, the coordinator writes the active `requestKey`,
   request metadata, request attempt, provider epoch, provider config hash, and
   token status `REQUESTED`.
6. If a provider or callback tries to reenter `requestEntropy` for the same
   token, the status and reentrancy guard both reject it.
7. `fulfillEntropy` must reject unknown request keys, inactive request keys,
   wrong providers, wrong epochs, already finalized tokens, and tokens whose
   status is not `REQUESTED`.
8. For `INSTANT` mode, v1 uses the bounded
   `IStreamInstantEntropyProvider.instantEntropy(requestKey, context)`
   read/return path from inside `requestEntropy`; it must not use an external
   callback into `fulfillEntropy`. The coordinator finalizes once from the
   returned raw value before `requestEntropy` returns. If the instant read
   fails, the transaction reverts and the pre-call `REQUESTED` state unwinds.
   The instant provider function must be `view`, and launch static analysis
   must fail if any reachable instant-provider path contains external calls,
   contract creation, delegatecall, or state writes.

## Request Commitment Finality

Randomness requests are commitments, not optional draws.

Once a token has an active provider request, Stream must not allow normal
cancel, re-request, or provider switching for that token. A fresh request after
an active request lets someone discard an unfavorable or suspicious outcome and
is therefore a reroll surface.

Rules:

1. Use `requestKey` and `providerRequestId` as the durable request identity.
2. Stop accepting artist, admin, minter, or buyer inputs that can affect final
   traits before the entropy request is made.
3. Do not let a token create a second fresh provider request while its first
   request can still fulfill.
4. Do not expose user-facing "reroll", "cancel randomness", or "try again"
   semantics.
5. Provider callbacks should store raw randomness before calling the
   coordinator.
6. Coordinator fulfillment should be intentionally small and should not depend
   on complex downstream rendering or payment logic.
7. Retrying delivery of already received randomness is safe. Requesting new
   randomness is an exceptional incident path.

This distinction is critical:

```text
safe retry:
  provider already received randomness
  adapter stores the raw randomness
  adapter calls coordinator.fulfillEntropy again with the same value

dangerous reroll:
  token abandons an unresolved request
  token asks a provider or fallback provider for a fresh random value
```

## Reorg Safety

Entropy finalization is final only in canonical chain history. If a fulfillment
transaction is reorged out, canonical state returns to the pre-fulfillment
status and the original request commitment remains the only valid request for
that attempt. A later callback for the same provider request may finalize again
if it matches the original request key and provider result; it must not create a
fresh request or reroll.

Provider adapters should configure confirmation depth according to the
provider's security model and target chain. VRF-style `requestConfirmations` is
part of the provider config hash and finality manifest. Tests must simulate a
reorged fulfillment by rolling back local chain state and proving the token
returns to `REQUESTED` without enabling a fresh entropy request.

## Fulfillment Flow

Provider adapters fulfill through the coordinator:

```solidity
function fulfillEntropy(bytes32 requestKey, bytes32 rawRandomness) external;
```

Rules:

1. `fulfillEntropy` must use a reentrancy guard or equivalent state lock.
2. `requestKey` must exist.
3. Request must be active.
4. Caller must be the provider stored on the request.
5. Provider must not be `INCIDENT_REVOKED`.
6. Token status must be `REQUESTED`.
7. Token must not already be finalized.
8. Fulfillment must finalize exactly one canonical seed.
9. Before any external refresh or notification call, fulfillment must mark the
   request inactive and set token status `FINALIZED`.
10. Old request keys after incident recovery must be rejected or emitted as
   stale.
11. Wrong provider epoch must emit a stale/audit event and must not finalize.
12. `fulfillEntropy` cannot call `requestEntropy`; delivery retry calls
    `fulfillEntropy` again with the same stored raw randomness.

Seed derivation:

```solidity
bytes32 seed = keccak256(abi.encode(
    STREAM_ENTROPY_SEED_V1,
    block.chainid,
    address(this),
    streamCore,
    collectionId,
    tokenId,
    provider,
    providerEpoch,
    providerConfigHash,
    requestKey,
    providerRequestId,
    rawRandomness,
    collectionSalt,
    mintCommitment
));
```

The seed, not provider-specific raw randomness, is the canonical artist-facing
token hash. Metadata renderers should expose this as `hash` or `seed`.

Event:

```solidity
event EntropyFinalized(
    uint256 indexed collectionId,
    uint256 indexed tokenId,
    address indexed provider,
    bytes32 requestKey,
    uint256 providerRequestId,
    uint32 providerEpoch,
    bytes32 providerConfigHash,
    bytes32 seed,
    bytes32 rawRandomness
);
```

After fulfillment, the coordinator or metadata router should cause
ERC-4906-style metadata refresh events for the token:

```solidity
event MetadataUpdate(uint256 tokenId);
```

If Core owns those events, the coordinator should call a restricted Core method
or the metadata router should expose a refresh hook. The spec should avoid fake
metadata update events emitted from contracts that marketplaces will not watch.

## Retry And Failure Policy

Async providers can fail, stall, or be replaced by infrastructure changes over
time. The coordinator needs explicit failure policy, but "retry" must be split
into two categories:

1. Delivery retry of already received randomness.
2. Fresh entropy recovery after an unrecoverable provider incident.

Delivery retry is the normal path. Fresh entropy recovery is exceptional.

### Delivery Retry

If a provider adapter receives valid randomness but the coordinator call fails,
the adapter must retain the raw randomness and expose
`retryCoordinatorFulfillment(providerRequestId)`.

Delivery retry keeps the same:

1. provider request ID;
2. request key;
3. raw randomness;
4. final seed derivation inputs.

This path is not a reroll and may be permissionless.

### Fresh Entropy Recovery

A fresh provider request for the same token is a recovery event, not a normal
retry. Launch v1 should disable fresh token-level recovery for high-value VRF
collections by setting `maxFreshRecoveryAttempts = 0` unless the collection has
a complete pre-mint recovery policy that was configured, evented, and frozen
before public mint.

A complete fresh-recovery policy is represented by the frozen
`FreshRecoveryPolicy` linked from `CollectionEntropyConfig`. It must define:

1. the fallback provider list and provider order;
2. provider epochs and provider config hashes;
3. request timeout or incident conditions;
4. maximum fresh attempts;
5. who can declare the incident;
6. the required reason URI/hash;
7. whether late fulfillment from the original provider is accepted or stale;
8. adapter result-status proof that no raw randomness was received for the
   abandoned request.

If any of those facts were not frozen onchain before mint, the safe v1 answer
is no fresh recovery and `maxFreshRecoveryAttempts` must be zero. Operational
protection should come from request funding monitors, provider health checks,
callback gas runbooks, and delivery retry of already received randomness.

Recommended function:

```solidity
function markEntropyRequestUnrecoverable(
    uint256 tokenId,
    string calldata reasonURI
) external;
```

Rules:

1. Token must be `REQUESTED`.
2. `block.number` must be greater than
   `requestedAtBlock + requestTimeoutBlocks`, unless a provider is
   `INCIDENT_REVOKED`.
3. The provider adapter's `providerResultStatus` must prove that no valid raw
   randomness was received for the old provider request. The coordinator should
   call this status probe with an explicit gas cap and treat failure, malformed
   data, or out-of-gas as "not safe to recover."
4. Caller should be admin/governance only.
5. The action must emit a human-readable or content-addressed incident reason.
6. Token status becomes `FAILED`.
7. The active request is closed only as an incident action.
8. A later fresh request, if allowed, must be emitted as recovery and counted
   separately from delivery retries.
9. Fallback providers for high-value collections should be predeclared and
   frozen before mint.
10. Admin-selected fallback after seeing partial outcomes is a manipulation
    risk.

Event:

```solidity
event EntropyRequestFailed(
    uint256 indexed collectionId,
    uint256 indexed tokenId,
    address indexed provider,
    bytes32 requestKey,
    uint32 providerEpoch,
    uint16 requestAttempt,
    string reasonURI
);

event EntropyRecoveryRequested(
    uint256 indexed collectionId,
    uint256 indexed tokenId,
    address indexed oldProvider,
    address newProvider,
    bytes32 oldRequestKey,
    bytes32 newRequestKey,
    uint32 oldProviderEpoch,
    uint32 newProviderEpoch,
    string reasonURI
);
```

Stale fulfillments after incident recovery should not mutate token seed:

```solidity
event StaleEntropyFulfillment(
    uint256 indexed tokenId,
    address indexed provider,
    bytes32 requestKey,
    uint32 providerEpoch,
    string reason
);
```

For Chainlink-style VRF, the launch default should be no fresh token-level
request after the VRF request is accepted. Operational protection should come
from funding monitors, provider health checks, callback gas runbooks, and
delivery retry of already received randomness. Fresh recovery should be a rare
public incident process.

## Instant Providers

Some collections may use an instant deterministic provider. This mode is lower
assurance than external verifiable randomness unless carefully designed.

Instant provider rules:

1. It must be explicitly configured as `INSTANT`.
2. It should derive raw randomness from data that cannot be freely chosen after
   mint outcome is known.
3. It should not allow the minter, buyer, artist, or admin to grind favorable
   outcomes.
4. If block data is used, the security assumptions should be documented in the
   collection metadata or provenance notes.
5. High-value fully generative collections should prefer async verifiable
   randomness.
6. Same-mint-path instant fulfillment is not allowed in v1. `INSTANT` means a
   later `requestEntropy` call can finalize synchronously in that request
   transaction after Core mint registration has completed.
7. The instant provider must be pure, bounded, and have no external call, no
   Core call, and no callback path. If it can fail, block, reenter, or consult
   mutable external state, it is not eligible for production use.

The current NXT-style randomizer should not be treated as equivalent to VRF
without an explicit security review.

## Adapter Expectations

Detailed provider adapter specifications live in
`docs/stream-entropy-providers.md`. This section records the coordinator-level
expectations only.

### VRF Adapter

The VRF adapter should:

1. Receive `requestKey` from the coordinator.
2. Request randomness from the VRF coordinator.
3. Store `providerRequestId -> requestKey`.
4. On VRF callback, compress returned words to `bytes32 rawRandomness`.
5. Call `StreamEntropyCoordinator.fulfillEntropy(requestKey, rawRandomness)`.
6. Emit provider-level request and callback events.
7. Avoid writing to Core, deriving the final token seed, or exposing
   `setTokenHash`-style callbacks.

### ARRNG Adapter

The ARRNG adapter should follow the same `requestKey` pattern:

1. Receive `requestKey`.
2. Request external randomness.
3. Store provider request ID to request key.
4. Fulfill through the coordinator.
5. Keep payment and withdrawal behavior explicit and evented.
6. Avoid writing to Core, deriving the final token seed, or exposing
   `setTokenHash`-style callbacks.

### Future Adapters

Future providers should be added as new adapters and activated through the
provider registry. Existing Core contracts should not need changes.

## Metadata Integration

Metadata Router should read:

```solidity
(bytes32 seed, bool finalized) = entropyCoordinator.tokenSeed(tokenId);
```

Rendering behavior:

```text
if finalized:
    render active metadata using seed
else:
    render pending metadata
```

The renderer should expose the canonical seed in the JavaScript render context:

```js
window.__STREAM_TOKEN__ = {
  tokenId: "123",
  collectionId: "1",
  hash: "0x...",
  seed: "0x...",
  entropyStatus: "FINALIZED",
  entropyProvider: "0x..."
};
```

`hash` may be kept as the artist-friendly alias for the seed. `seed` should be
included as the precise protocol term.

## Access Control

Recommended admin roles:

```text
global admin             emergency authority through ADR 0004 governance/action roles
entropy config admin     configure collection entropy before freeze
provider admin           approve, deprecate, or revoke providers
request operator         request entropy or trigger delivery retry where allowed
metadata refresh admin   coordinate refresh events if required
```

All admin actions should emit events and should include a reason URI where
practical.

## Invariants

1. Only Core can register token entropy.
2. A token can be registered only once.
3. A token seed can be finalized only once.
4. Token status, not seed value, determines pending/finalized state.
5. A fulfillment can only come from the active request's provider.
6. Request keys are globally unique for this coordinator.
7. Seed derivation uses `abi.encode`, not packed encoding.
8. Collection entropy config cannot change after freeze.
9. New requests cannot use unknown, deprecated, or incident-revoked providers.
10. Deprecated providers may fulfill already-open requests unless explicitly
    incident-revoked.
11. Stale fulfillments cannot overwrite or finalize token seed.
12. Metadata pending/active state must be reconstructable from events and reads.
13. Provider epoch changes cannot silently reinterpret pending requests.
14. Token-to-request binding remains after fulfillment, stale marking, and
    failure so a token cannot receive a quiet second output.
15. Delivery retry cannot change raw randomness, provider request ID, request
    key, provider epoch, or request attempt.
16. Fresh entropy recovery is an incident path and must be visible in events.
17. Fresh entropy recovery cannot proceed unless adapter status proves no raw
    randomness was received for the old request.
18. Mint registration happens before any `_safeMint` receiver callback can
    observe the token.

## Security Considerations

### Mint Reentrancy And Provider Calls

Core should not call external randomness providers directly. If mint calls the
coordinator, the coordinator registers state without provider callbacks.
External provider calls belong in `requestEntropy`, and `requestEntropy` is not
called from `onTokenMinted` in v1. Any future design that wants seed finality
before safe receiver callbacks must be specified in a separate ADR with an exact
Core/manager call order, reentrancy analysis, and metadata-observation model.

### Manipulation Resistance

For collections whose art depends on entropy, provider and salt configuration
should be frozen before public mint starts. Changing provider after partial
minting can create selection or perception risk.

### Zero Values

`bytes32(0)` is a valid theoretical hash output. It must not be used to infer
pending state.

### Provider Compromise

Provider incident revocation can strand pending tokens. Tooling should require a
documented recovery path before revocation is used. Precommitted fallback
providers are preferred for long-running high-value collections.
If the coordinator or provider quorum needed for safe recovery is lost, minting
for entropy-dependent collections halts as an accepted terminal degradation
until governance is restored or a precommitted fallback route is executed. The
system should preserve existing ownership, finalized seeds, pending-state
truthfulness, and metadata fallback behavior rather than inventing an
unauthorized randomness source.
Collection `CLOSED` status does not block fulfillment for already-`REQUESTED`
tokens or permissionless `requestEntropy` for already-`REGISTERED` tokens whose
frozen policy allows public requests. Closing stops new minting, not honest
completion of already-minted entropy lifecycle.

### Event Provenance

Collectors and auditors should be able to reconstruct:

1. collection entropy config at mint time;
2. provider used;
3. request key;
4. provider request ID;
5. raw randomness;
6. final seed;
7. delivery retry and recovery history;
8. final metadata refresh trigger.

## Bytecode Impact

The layered scratch compile that removed randomizer/hash coordination from Core
after renderer, collection metadata, and counter extraction saved roughly
`970` additional runtime bytes. The exact final saving depends on the final
Core hook and interfaces, but this refactor should still buy about `0.8 KB` to
`1.1 KB` while making randomness substantially safer and easier to audit.

## Implementation Plan

### Phase 1: Coordinator And Interfaces

1. Add `IStreamEntropyCoordinator`, `IStreamEntropyView`, and
   `IStreamEntropyProvider`.
2. Implement `StreamEntropyCoordinator`.
3. Add provider registry state.
4. Add collection config and freeze functions.
5. Add token registration, request, fulfillment, failure, delivery retry, and
   recovery logic.

### Phase 2: Provider Adapters

1. Implement a new `StreamEntropyProviderVRF` adapter using the `requestKey`
   pattern.
2. Implement a new `StreamEntropyProviderARRNG` adapter using the `requestKey`
   pattern if ARRNG is still required.
3. Implement or explicitly defer an instant provider.
4. Add provider-level events and tests.
5. Do not reuse `NextGenRandomizerNXT`, `NextGenRandomizerRNG`, or
   `NextGenRandomizerVRF` as production providers without rewriting them to the
   adapter interface.

### Phase 3: Core Integration

1. Remove Core randomizer storage and token hash storage.
2. Add `entropyCoordinator`.
3. Add `EntropyCoordinatorUpdated`.
4. Register token entropy during mint.
5. Remove `addRandomizer`, `setTokenHash`, and `retrieveTokenHash`.

### Phase 4: Metadata Integration

1. Update `StreamMetadataRouter` to read seed/status from the coordinator.
2. Render pending metadata until seed finalizes.
3. Include `hash`, `seed`, `entropyStatus`, and `entropyProvider` in the render
   context.
4. Trigger ERC-4906-style metadata refresh when entropy finalizes.

### Phase 5: Tooling And Monitoring

1. Add admin tools for collection entropy config inspection.
2. Add dashboards for pending, requested, failed, and finalized tokens.
3. Add keeper or operator scripts for public-request collections.
4. Add runbooks for provider deprecation and incident revocation.

## Required Tests

Core integration tests:

1. Mint registers token entropy.
2. Only Core can call `onTokenMinted`.
3. Core emits `EntropyCoordinatorUpdated`.
4. Updating coordinator requires admin authority.
5. Core no longer stores token hash or randomizer address.
6. `ERC721Enumerable` behavior remains unchanged.
7. If `onTokenMinted` reverts, the whole mint reverts and no token is minted.
8. Emergency switch to a pre-approved safe-mode coordinator preserves
   registration semantics.

Coordinator config tests:

1. Unknown providers cannot be configured.
2. Active providers can be configured.
3. Deprecated providers cannot be used for new configs.
4. Collection config emits events.
5. Frozen collection config cannot be changed.
6. Provider changes after first mint are blocked unless policy explicitly allows
   precommitted fallback.
7. `maxFreshRecoveryAttempts > 0` is rejected unless a frozen
   `FreshRecoveryPolicy` exists and its hash matches collection config.
8. Fresh recovery policy steps, incident declarer, provider epochs, and reason
   schema are included in the policy hash.

Request tests:

1. Registered token can request entropy.
2. Unknown token cannot request entropy.
3. Finalized token cannot request entropy again.
4. Request stores active `requestKey`.
5. Request emits `EntropyRequested`.
6. Provider request ID is recorded.
7. Public requests obey collection policy.
8. Request snapshots provider epoch and provider config hash.
9. Request key changes when provider epoch changes.
10. `requestEntropy` rejects reentrant calls, already `REQUESTED` tokens, and
    already `FINALIZED` tokens.
11. `requestEntropy` writes `REQUESTED` state before any provider or instant
    provider call.

Fulfillment tests:

1. Active provider can fulfill.
2. Wrong provider cannot fulfill.
3. Unknown request key cannot fulfill.
4. Fulfillment finalizes seed exactly once.
5. Fulfillment emits `EntropyFinalized`.
6. Seed derivation is deterministic and domain-separated.
7. Seed zero does not control status.
8. Metadata refresh hook/event is triggered.
9. Wrong provider epoch cannot fulfill.
10. Stale fulfillment emits `StaleEntropyFulfillment` and does not mutate seed.
11. `fulfillEntropy` rejects inactive requests, non-`REQUESTED` token status,
    and already finalized tokens.
12. Synchronous `INSTANT` finality uses `instantEntropy` return data, not a
    callback into `fulfillEntropy`.

Delivery retry tests:

1. Provider adapter can retry coordinator fulfillment with the same raw
   randomness.
2. Delivery retry does not change request key.
3. Delivery retry does not change provider request ID.
4. Delivery retry does not increment request attempt.
5. Delivery retry cannot finalize an already finalized token twice.
6. Delivery retry does not change provider epoch or provider config hash.

Incident recovery tests:

1. Request cannot be marked unrecoverable before timeout.
2. Request can be marked unrecoverable after timeout or provider incident.
3. Fresh recovery increments request attempt.
4. Fresh recovery creates a new request key.
5. Stale fulfillment cannot finalize token unless policy explicitly accepts
   late fulfillment from the original provider.
6. Max recovery attempts are enforced if fresh recovery is enabled.
7. Incident-revoked provider behavior follows policy.
8. Fresh recovery is rejected when the adapter reports raw randomness received.
9. Fresh recovery is rejected for high-value launch configs with
   `maxFreshRecoveryAttempts = 0`.
10. Fresh recovery follows the frozen ordered policy step and cannot choose an
    ad hoc provider after the incident.

Provider adapter tests:

1. VRF adapter maps provider request ID to request key.
2. VRF callback fulfills through coordinator.
3. ARRNG adapter maps provider request ID to request key.
4. Provider adapters reject unauthorized callers where applicable.
5. Payable providers enforce exact payment and reject excess payment unless a
   later adapter-specific ADR explicitly accepts a bounded refund path.
6. Provider adapters expose result status for requested, received, delivered,
   stale, and failed cases.

Renderer integration tests:

1. Pending token renders pending metadata.
2. Finalized token renders active metadata.
3. Render context includes canonical seed.
4. Render context includes entropy status and provider.
5. Metadata output does not depend on Core `tokenToHash`.

## Open Design Decisions

1. Whether launch collections should require entropy config before sale start or
   allow a global default provider.
2. Whether public `requestEntropy` should be enabled by default.
3. Whether an instant provider should be included in v1 or deferred.
4. Whether fallback providers are needed in v1 or only after the first external
   provider integration review.
5. Whether Core or Metadata Router should emit the ERC-4906-compatible refresh
   event after entropy finalization.

The preferred answers for a high-value launch are: configure and freeze entropy
before sale start, allow operator/admin requests by default, defer instant
providers unless strongly needed, use precommitted fallback only if provider
risk justifies it, and ensure refresh events are emitted from the contract or
surface marketplaces actually monitor.
