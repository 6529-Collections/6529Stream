# Stream Entropy Coordinator

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md); the decisions formerly tracked
inline are resolved by
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md),
[ADR 0010](adr/0010-world-class-spec-pass.md),
[ADR 0011](adr/0011-world-class-pass-round-2.md),
[ADR 0012](adr/0012-world-class-pass-round-3.md), and
[ADR 0013](adr/0013-world-class-pass-round-4.md) and recorded
in [`docs/spec-open-questions.md`](spec-open-questions.md).

This document specifies the dedicated entropy subsystem that moves
randomness, token seed finalization, and randomizer coordination out of
`StreamCore`. 6529Stream is permanent infrastructure for the 6529 network:
the first production deployment is the permanent system, and the requirements
below are classified by permanence class per `docs/spec-policy.md`, not by
launch phase.

`StreamCore` should remain the canonical ERC-721 contract — with no
`ERC721Enumerable` storage; `totalSupply()` stays, and archival
enumeration is served by the three state-only lanes of the enumeration
posture home, [LTA-ENUMERATION] in
`docs/stream-long-term-architecture.md`: state exports, sequential-ID
iteration over live state, and event replay (ADR 0012 decision T10) —
and own token minting,
ownership, approvals, and token-to-collection identity. Entropy
generation, provider callbacks,
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
  - sale/collection scope entropy requests
  - request and fulfillment state machine
  - canonical seed derivation
  - reveal ownership, SLO fallback, and reveal-fee escrow
  - delivery retry and recovery policy
  - entropy provenance events

StreamEntropyProvider adapters
  - Stream-native Chainlink VRF adapter
  - one reviewed Stream-native fallback adapter (ARRNG preferred, Pyth alternate)
  - deterministic/pseudo provider only when explicitly configured
  - additional provider adapters via the provider registry

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

This section is non-normative implementation evidence per
[`docs/spec-policy.md`](spec-policy.md); it records point-in-time as-built
state and does not weaken any requirement in this spec.

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

The production implementation should build Stream-native provider adapters
rather than reuse the NextGen randomizers as-is.

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
  - right provider family for production
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
   calling the coordinator, and deliver to the coordinator through
   try/catch so a coordinator revert never unwinds the stored result
   (ADR 0010 decision D8.1). Raw provider outputs should be emitted for
   audit where practical; contract storage can keep compact hashes.
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
2. Keep Core enumeration-free: `totalSupply()` stays, and no
   `ERC721Enumerable` index storage exists (ADR 0012 decision T10).
3. Remove randomizer provider details from Core.
4. Remove token seed/hash storage from Core.
5. Avoid using `bytes32(0)` as a pending sentinel.
6. Make token entropy status explicit.
7. Finalize each token seed exactly once.
8. Make seed derivation domain-separated and versioned.
9. Support synchronous and asynchronous entropy providers through adapters.
10. Preserve strong event provenance for requests, fulfillments, delivery
    retries, recovery attempts, and provider decisions.
11. Allow new entropy providers to be added through the provider registry
    without redeploying the NFT Core.
12. Give metadata rendering a stable seed/status read interface.
13. Support long-lived collections where provider infrastructure may change
    over decades.
14. Give sale-, phase-, and collection-scoped mechanics — raffles, random
    assignment, reveal offsets — a first-party randomness surface that
    inherits the same anti-reroll lifecycle as token seeds (ADR 0011
    decision R8).
15. Make reveal completion an owned, funded, measured obligation rather
    than an unowned side effect of minting (ADR 0011 decision R8).

## Non-Goals

1. The entropy coordinator does not mint, burn, transfer, approve, or enumerate
   ERC-721 tokens.
2. The entropy coordinator does not build token metadata JSON or HTML.
3. The entropy coordinator does not own script storage or dependency storage.
4. The entropy coordinator does not make primary-sale or royalty decisions.
5. The entropy coordinator does not enforce marketplace behavior.
6. The entropy coordinator does not use upgradeable proxy mutability as its
   default safety mechanism.
7. The entropy coordinator does not select raffle winners, assign tokens,
   or compute reveal offsets. It finalizes scope seeds [EC-SCOPE];
   consuming adapters resolve outcomes from those seeds under their own
   accepted specs.

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
    uint16 schemaVersion,
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
    bytes memory tokenData_,
    uint256 collectionId,
    bytes32 mintCommitment
) internal {
    tokenData[tokenId] = tokenData_;
    tokenCollectionId[tokenId] = collectionId;
    // tokenCollectionIdentity derives mapping existence from live/burned/prepared state.
    entropyCoordinator.onTokenMinted(
        collectionId,
        tokenId,
        recipient,
        mintCommitment
    );
    _safeMint(recipient, tokenId);
}
```

Parameter typing and naming follow the Core mint ABI home
([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
[MPA-CORE-ABI]): `tokenData` is opaque `bytes` end to end, and
`bytes32 mintCommitment` replaces the legacy `_saltfun_o` parameter on
every production Core mint surface.

`onTokenMinted` must register token entropy state before any external receiver
callback can observe the freshly minted token. If `_safeMint` later reverts, the
whole transaction reverts and the entropy registration is unwound with it.

`onTokenMinted` must be a bounded internal-protocol registration call. It must
not call the configured provider, request randomness, finalize a seed, or depend
on external randomness provider uptime. Actual randomness requests happen only
through an idempotent request function on the coordinator after token state is
registered and `mintFromManager` has returned. Who requests, when, with
what funding, and what happens on lapse is not left unowned: the
collection's declared reveal policy governs it [EC-REVEAL] (ADR 0011
decision R8). A safe receiver callback may
therefore observe `REGISTERED` or pending entropy state; metadata must render
pending output honestly until a seed is finalized.
Core calls `onTokenMinted` with a bounded gas stipend and an EIP-150-aware
parent gas precheck. The stipend is a Governed Gas Parameter, not an
immutable constant (ADR 0010 decision D1.1).

Requirements [EC-REGGAS]:

1. `ENTROPY_REGISTRATION_GAS_LIMIT` is a Governed Gas Parameter: a Core
   storage value with a deploy-time immutable floor
   `ENTROPY_REGISTRATION_GAS_FLOOR` (ADR 0010 decision D1.1). Core must
   forward at most the current parameter value to `onTokenMinted` and must
   not forward all remaining gas to a mutable coordinator.
2. The floor must be at least four times the measured all-cold
   registration gas of the genesis coordinator under the deployment gas
   schedule, and the genesis value must be at least the floor. The
   historical planning target for measured all-cold registration is
   80,000 gas; the deployed floor and genesis value must come from
   measured gas, and both are recorded in the release manifest
   (ADR 0010 decision D1.4).
3. The EIP-150 63/64 parent gas precheck remains mandatory and reads the
   live parameter value per the model home,
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-GGP] requirement 5. If the precheck fails, the mint reverts
   before the coordinator call.
4. Raise and lower governance follows [LTA-GGP] requirements 1–2
   unchanged; parameter changes execute as canonical ADR 0004 governance
   actions.
5. The parameter is Operational-layer per [LTA-GGP] requirement 3; in
   this subsystem the exclusion additionally covers entropy policy
   manifests and seed derivation, so retuning gas never touches artwork
   identity.
6. If the coordinator call reverts, runs out of the forwarded stipend, or
   returns malformed success behavior, the mint reverts and all token
   identity writes unwind.
7. Monitoring follows the [LTA-GGP] requirement 6 threshold. The response
   is a staged raise; where a raise cannot restore margin, a
   leaner-storage safe-mode coordinator behind the same read ABI must be
   staged (see [Coordinator Replacement And State
   Continuity](#coordinator-replacement-and-state-continuity)).
8. The parameter is a member of the hard-fork/repricing review checklist
   ([LTA-GGP]), and every change emits the parameter-named alias event
   below — a member of the canonical GGP change-event family per
   [LTA-GGP] requirement 4, tagged as such in the event catalog:

```solidity
event EntropyRegistrationGasLimitUpdated(
    uint16 schemaVersion,
    uint256 oldValue,
    uint256 newValue,
    uint256 floor
);
```

The parameter's release-manifest failure-direction class is
`FAIL_CLOSED_PRECHECK` ([LTA-GGP] requirement 10): raises are
governance-only, and it is not a permissionless conditional-raise member
(ADR 0012 decision T1). Its named probe is a Permanent-class probe
contract ([LTA-GGP-PROBES]) that executes a faithful equivalent of the
guarded operation: the coordinator's all-cold registration write
sequence, replicated in probe-owned storage with the production struct
packing and slot shape, run under exactly the probed stipend against a
pinned input corpus with no caller-supplied gas shaping. The probe
records each run on itself, and `evidenceHash` commits to the run's
measurement artifact. A release golden test asserts probe equivalence:
probe-path gas must match measured production registration gas within
the tolerance recorded in the release manifest.

Registration failure can never permanently brick minting. The recovery
chain is explicit (ADR 0010 decision D1.5): the registration cap is
raisable without limit above the floor, and the Core coordinator pointer
is replaceable under the Core Satellite Pointer Policy with a pre-approved
safe-mode coordinator whose registration write fits a leaner storage
layout behind the same read ABI. Accepted terminal risk: the residual
failure mode is a gas repricing so severe that no mint transaction can
carry registration within the block gas limit while governance quorum is
simultaneously lost. This mirrors the accepted `FLUSH_GAS_FLOOR` terminal
risk in
[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md)
and is accepted with the same posture: no hidden admin path, recovery only
through governed succession.

If Core exposes `prepareMintFromManager`, the prepare step must not call
`onTokenMinted`, request entropy, or write provider/request state. Prepare only
allocates Core token identity and marks the token prepared-incomplete until
`completePreparedMintFromManager` clears that record. Completion invokes the
normal mint entropy boundary for the now-complete token while the Core
completion sentinel still blocks unrelated Core mutations. `requestEntropy(tokenId)`
must consult Core's token status or receive an equivalent Core-authenticated
flag and revert for prepared-incomplete tokens. A token cannot request entropy,
finalize entropy, or produce final metadata between prepare and complete.
For `PREPARED_MINT`, the first valid public or operator `requestEntropy` window
opens only after `completePreparedMintFromManager` has finished and the token is
no longer prepared-incomplete. A sale that needs both token-level economics and
async entropy must snapshot economics, record revenue, complete `_safeMint`,
and only then allow entropy request.
Any entropy registration event for a prepared mint must be deferred until
completion. If the top-level transaction reverts, registration and request
events disappear with the revert. `tokenEntropy` reads for a
prepared-incomplete token must disclose that status, or revert, so satellites
do not confuse it with an ordinary minted token.

This document is the owning home of `EntropyStatus` semantics; the
lifecycle reconciliation matrix in
[`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md) is a
checker-verified mirror of the mapping below and must match it (ADR 0010
decision D3.1).

Lifecycle mapping requirements [EC-LIFECYCLE]:

1. While a token is prepared-incomplete, the coordinator has no token
   entropy record: the only reachable `EntropyStatus` is `NONE`.
   `REGISTERED` and the terminal `DISABLED` / `NOT_REQUIRED` records are
   written only by `onTokenMinted`, which runs only at completion.
   `tokenEntropy` must disclose the prepared-incomplete condition (by
   consulting Core token status or an equivalent Core-authenticated flag)
   or revert; consumers must treat either behavior as pending.
2. Nonexistent tokens have `EntropyStatus` `NONE`. `EntropyStatus` has no
   `UNKNOWN` member; mirrors and indexers must not invent one.
3. Burned tokens retain their last written entropy status. Burning does
   not clear the token-to-request binding and does not create a new
   entropy state.

Coordinator availability is a hard mint prerequisite. Core should not catch and
ignore a failed `onTokenMinted` call because that would create minted tokens
without authoritative entropy state. Production operations must therefore
include a pre-approved, registry-approved, write-capable backup or safe-mode
coordinator that can be staged or emergency-switched under the Core Satellite
Pointer Policy if the active coordinator is incident-revoked. Safe-mode may
register tokens and leave them `REGISTERED` without requesting provider
randomness, but it must not silently mint unregistered tokens.

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

    function registerEntropyScope(
        uint256 collectionId,
        uint8 scopeKind,
        bytes32 scopeRef
    ) external returns (bytes32 scopeId);

    function requestScopeEntropy(bytes32 scopeId, bytes32 scopeInputsHash)
        external
        payable
        returns (bytes32 requestKey, uint256 providerRequestId);

    function fulfillEntropy(bytes32 requestKey, bytes32 rawRandomness)
        external
        returns (uint8 outcome);
}
```

`onTokenMinted` is callable only by Core.

`requestEntropy` is callable by the minter path, entropy admins, global
admins, and the collection's reveal owner role [EC-REVEAL]. Anyone may call
it only for collections that explicitly enable public requests — public
requests are opt-in per collection, never a default (ADR 0009 decision
22) — or, for collections with a declared reveal policy, for a token whose
reveal request window has lapsed: the permissionless reveal fallback
[EC-REVEAL] (ADR 0011 decision R8). `requestEntropy` is payable;
`msg.value` is the caller's maximum fee bound with pull-credit refund of
excess [EC-FEEBIND] (ADR 0010 decision D8.7).

`registerEntropyScope` and `requestScopeEntropy` are the
sale/collection-scoped request kind [EC-SCOPE] (ADR 0011 decision R8).
They are callable by the minter path and entropy admins, never by the
public, and `requestScopeEntropy` is payable under the same [EC-FEEBIND]
fee binding.

`fulfillEntropy` is callable only by the provider currently assigned to the
active request key.

`fulfillEntropy` returns a pinned outcome code instead of reverting on
benign rejection (ADR 0009 decision 25):

```solidity
enum EntropyFulfillmentOutcome {
    FINALIZED,
    REJECTED_STALE_EPOCH,
    REJECTED_INACTIVE_REQUEST,
    REJECTED_ALREADY_FINALIZED,
    REJECTED_UNKNOWN_REQUEST,
    REJECTED_PROVIDER_REVOKED
}
```

Benign rejections return an outcome and do not revert, because provider
callbacks — including VRF callbacks — must not revert. Hard violations
(unauthorized provider, reentrancy) still revert with typed errors.

This enum definition is the normative home of `EntropyFulfillmentOutcome`
(ADR 0010 decision D3.1). The pinned numeric values are `FINALIZED = 0`,
`REJECTED_STALE_EPOCH = 1`, `REJECTED_INACTIVE_REQUEST = 2`,
`REJECTED_ALREADY_FINALIZED = 3`, `REJECTED_UNKNOWN_REQUEST = 4`, and
`REJECTED_PROVIDER_REVOKED = 5`; the Numeric ID Catalog mirrors exactly
these six members. The first five members were pinned by ADR 0009
decision 25; `REJECTED_PROVIDER_REVOKED = 5` was appended by ADR 0010
decision D8.1. Decision-record or derived text that restates the
pre-extension five-member enum is drift and is corrected to cite this
home (ADR 0011 decision R12).

`REJECTED_PROVIDER_REVOKED` is returned when the caller is the request's
bound provider but that provider is `INCIDENT_REVOKED` at fulfillment time
(ADR 0010 decision D8.1): the call does not revert, does not finalize, and
the adapter must retain its stored result so an approved recovery policy
can resolve the request. Revocation between request and fulfillment is a
classifiable operational condition, never a randomness-loss path.

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

    function scopeEntropy(bytes32 scopeId)
        external
        view
        returns (ScopeEntropy memory);

    function scopeSeed(bytes32 scopeId)
        external
        view
        returns (bytes32 seed, bool finalized);

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

`quoteRequest` must return the exact fee that `requestEntropy` will require
for the same context in the same transaction; the normative quote rules are
provider-side and live in
[`docs/stream-entropy-providers.md`](stream-entropy-providers.md)
[EP-QUOTE]. The coordinator's use of the quote is defined in [EC-FEEBIND].

`providerResultStatus` is required for incident analysis and fresh-recovery
safety. The coordinator and operator tooling must be able to distinguish "the
provider never accepted or never produced randomness" from "the provider
received raw randomness but delivery failed." Fresh entropy recovery cannot
proceed if the adapter reports that raw randomness was received for the old
provider request; a negative report is necessary but never sufficient on
its own — the coordinator-state and independent-evidence requirements of
[EC-INCIDENT] rule 3 must also hold (ADR 0011 decision R12).

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

enum EntropySecurityClass {
    HIGH_ASSURANCE,
    LOW_SECURITY
}

enum EntropyScopeKind {
    SALE,
    PHASE,
    COLLECTION
}

enum RevealRequestMode {
    AT_MINT,
    OWNER_WINDOW
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

`EntropySecurityClass` is the collection's declared entropy assurance
posture (ADR 0010 decision D8.8). `HIGH_ASSURANCE` (value 0, the default)
means only reviewed async verifiable randomness may finalize seeds for the
collection. `LOW_SECURITY` means the collection explicitly accepts
manipulable-entropy exposure — block-derived instant modes and their
structural request-timing grinding — and must disclose that acceptance in
collection provenance and metadata notes and machine-readably in every
default token JSON: the renderer must emit the declared class as
`properties.stream.entropy_security_class` with exactly the pinned values
`HIGH_ASSURANCE` or `LOW_SECURITY`, in pending-state and finalized JSON
alike, so the class reaches marketplaces and collectors without relying on
prose disclosure (ADR 0011 decision R12). The token-JSON field pinning and
the renderer conformance test covering both classes are owned by
[`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md);
this document owns the class semantics being disclosed. `INSTANT` mode is
configurable only for `LOW_SECURITY` collections [EC-CONFIG]. The class
values are pinned in the Numeric ID Catalog.

`EntropyScopeKind` names the subject class of a scope entropy request
[EC-SCOPE] (ADR 0011 decision R8): `SALE = 0` (the subject is a sales-spec
sale), `PHASE = 1` (a mint phase), `COLLECTION = 2` (a collection-wide
purpose such as a reveal offset). The kind values are pinned in the
Numeric ID Catalog as an append-only vocabulary: later accepted specs may
append kinds; existing values are never reinterpreted.

`RevealRequestMode` is the collection's declared reveal-request posture
[EC-REVEAL] (ADR 0011 decision R8): `AT_MINT = 0` (the mint path attempts
the entropy request in the mint transaction) or `OWNER_WINDOW = 1` (the
reveal owner requests within the SLO window). The mode values are pinned
in the Numeric ID Catalog.

## Domain Constants [EC-DOMAINS]

This document is the normative home of the coordinator-owned hashing
domains (ADR 0010 decision D3.1; anchor per ADR 0013 decision U9).
Ordered `abi.encode` input lists are
defined once, in the owning sections referenced below; the checked
domain-constants table in
[`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
mirrors these rows, and release tooling computes and pins the hash values.

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_ENTROPY_REQUEST_V1` | `6529STREAM_ENTROPY_REQUEST_V1` | 0xf8ea7ebca4196e280c0b42e55e16736c8e836382a8859d151eb826edbecb7106 | `StreamEntropyCoordinator` | `1` | [Request Flow](#request-flow) |
| `STREAM_ENTROPY_SEED_V1` | `6529STREAM_ENTROPY_SEED_V1` | 0x88e816cf6b63abe50b33fdfd5033b9e0f12b8e8ba3925c57c3954ecf8caca69f | `StreamEntropyCoordinator` | `1` | [Fulfillment Flow](#fulfillment-flow) |
| `FRESH_RECOVERY_POLICY_DOMAIN` | `6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1` | 0x903ca537e686c7d615b886dbd8d81e240e58123e9918bc89ccabb64f2fe9a327 | `StreamEntropyCoordinator` | `1` | [Storage Model](#storage-model) |
| `FRESH_RECOVERY_STEPS_DOMAIN` | `6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1` | 0x8a9c948a061bd07713c5f797237b5d213f2f7cd133ea20f9e7a51af3fb204b9e | `StreamEntropyCoordinator` | `1` | interior composite; [Storage Model](#storage-model) |
| `STREAM_ENTROPY_SCOPE_SUBJECT_V1` | `6529STREAM_ENTROPY_SCOPE_SUBJECT_V1` | 0xef9a2afab4bd9a15841ca37c46b3cdb891a47121a1bfab0201f386d0a7b77490 | `StreamEntropyCoordinator` | `1` | [Scope Entropy Requests](#scope-entropy-requests) |
| `STREAM_ENTROPY_SCOPE_REQUEST_V1` | `6529STREAM_ENTROPY_SCOPE_REQUEST_V1` | 0xda5ba2e7e598a368f9e05c751fa0bbce4620c6fe030d47737c9eeb15099a3b81 | `StreamEntropyCoordinator` | `1` | [Scope Entropy Requests](#scope-entropy-requests) |
| `STREAM_ENTROPY_SCOPE_SEED_V1` | `6529STREAM_ENTROPY_SCOPE_SEED_V1` | 0x6111edc8a4ae25589e49af170892e9083107d07df6b48b7201458e32ba38365b | `StreamEntropyCoordinator` | `1` | [Scope Entropy Requests](#scope-entropy-requests) |
| `GGP_ENTROPY_REGISTRATION_GAS_LIMIT` | `6529STREAM_GGP_ENTROPY_REGISTRATION_GAS_LIMIT` | 0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17 | `StreamCore` | `1` | Governed Gas Parameter identifier per [LTA-GGP]; [EC-REGGAS] |
| `GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT` | `6529STREAM_GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT` | 0xaf00713aa70c259c23836c61245814e6e3b5fab1fe61b8879c0bd5450f23537c | `StreamEntropyCoordinator` | `1` | Governed Gas Parameter identifier per [LTA-GGP]; [EC-INCIDENT-ROLE] |
| `GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS` | `6529STREAM_GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS` | 0x63722ca7b016ab346b7839fe4e01fa7e0627bd5fb99531f7dbe5ec8c34e35c8d | `StreamEntropyCoordinator` | `1` | Governed Time Parameter identifier per [LTA-GTP]; [EC-TIME] |
| `GTP_ENTROPY_REVEAL_SLO_BLOCKS` | `6529STREAM_GTP_ENTROPY_REVEAL_SLO_BLOCKS` | 0x823057688d7c18dca4c528004d7912dfe0a32c36528a2cff1eb0e2a9164ab5e0 | `StreamEntropyCoordinator` | `1` | Governed Time Parameter identifier per [LTA-GTP]; [EC-TIME] |
| `GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS` | `6529STREAM_GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS` | 0x0be33ccf48a79079b125936b770c51cdd786fd29d574ce9071323b86838bccd8 | `StreamEntropyCoordinator` | `1` | Governed Time Parameter identifier per [LTA-GTP]; [EC-TIME] |
| `STREAM_ENTROPY_SCOPE_RANKING_V1` | `6529STREAM_ENTROPY_SCOPE_RANKING_V1` | 0x395f4d0c11d290e3bb32531f328ce6129c034100a89d45d65d1c55d248a6b0d3 | fair-allocation consumers ([EC-SCOPE-RAFFLE]) | `1` | [Scope Entropy Requests](#scope-entropy-requests) |

The three scope-request rows (ADR 0011 decision R8) carry values pinned
from exactly the string preimages shown; the rows join the checked mirror
table like every other
coordinator domain.

The `GTP_*` parameter-identifier rows and the scope-ranking row
(ADR 0012 decisions T1 and T6) carry values pinned from exactly the
string preimages shown, and the rows join the checked mirror table like
every other coordinator domain.

The `FRESH_RECOVERY_STEPS_DOMAIN` row (ADR 0013 decision U7) is an
interior-composite domain whose hash value release tooling computes and
pins from exactly the string preimage shown; the row joins the checked
mirror table like every other coordinator domain.

Provider-side raw randomness compression domains are owned by
[`docs/stream-entropy-providers.md`](stream-entropy-providers.md).

## Event Schemas [EC-EVENTS]

This document is the normative home of the entropy-subsystem event
vocabulary it defines, including the Core-emitted
`EntropyCoordinatorUpdated` and the parameter-named GGP/GTP alias
events. Every event block in this document is the production-exact
signature of its event, and the machine-readable event catalog must
reproduce these
signatures — `schemaVersion` position, field order, and indexed
allocation — exactly (ADR 0013 decision U7). The conformance-matrix
"snippet is shorthand" rule covers citations of these events in other
documents, never this home.

Requirements [EC-EVENTS]:

1. Every non-standard event carries `uint16 schemaVersion` as its
   leading declaration field — declared before every indexed parameter,
   so it is also the first data-section field — and declares at most
   three indexed parameters. Genesis emits every such event with
   `schemaVersion = 1`.
2. The only exempt signatures are the standard ERC-4906 refresh events
   (`MetadataUpdate` / `BatchMetadataUpdate`), emitted by Core with
   their standard signatures and named in the conformance-matrix
   standard-event exemption list.
3. The scope-keyed mirror events named by [EC-SCOPE] rule 6
   (`ScopeEntropyRequestFailed`, `StaleScopeEntropyFulfillment`) carry
   their token event's exact field shape — `schemaVersion` included —
   with `scopeId` in place of `tokenId`.

## Storage Model

Recommended collection config:

```solidity
struct CollectionEntropyConfig {
    EntropyMode mode;
    EntropySecurityClass securityClass;
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

Every lifecycle block-count window in this storage model —
`requestTimeoutBlocks`, `FreshRecoveryStep.notBeforeBlocks`, and the
reveal policy's `requestSLOBlocks` — is a collection timing policy: a
frozen declared floor applied through the effective-window rule of
[EC-TIME] (ADR 0012 decision T1). Collection timing policies are not
Governed Time Parameters and sit outside the GTP closed world: no
parameter identifier, cadence probe, or mirror-row obligation attaches
to a frozen per-collection declaration (ADR 0013 decision U9).

Fresh recovery policy is separate from the main config because most genesis
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
    bytes32 incidentDeclarerRole;
    bytes32 reasonSchemaHash;
    bytes32 policyManifestHash;
    FreshRecoveryStep[] steps;
}
```

The policy hash is deterministic:

```solidity
bytes32 stepsHash = keccak256(abi.encode(
    FRESH_RECOVERY_STEPS_DOMAIN,
    steps
));

bytes32 freshRecoveryPolicyHash = keccak256(abi.encode(
    FRESH_RECOVERY_POLICY_DOMAIN,
    uint256(block.chainid),
    address(coordinator),
    bytes32(policyId),
    uint16(maxFreshRecoveryAttempts),
    bytes32(incidentDeclarerRole),
    bytes32(reasonSchemaHash),
    bytes32(policyManifestHash),
    bytes32(stepsHash)
));
```

`steps` must be encoded as an ordered `FreshRecoveryStep[]` with `abi.encode`.
Packed encodings, JSON encodings, and display-order-dependent hashes are not
valid.

`stepsHash` is a named interior composite and carries its own versioned
domain, `FRESH_RECOVERY_STEPS_DOMAIN`, bound as the leading field of the
steps encoding, because every named composite hash is domain-separated
even when it is consumed only inside a domained outer preimage — the
same interior-composite discipline the mint and revenue layers apply
(ADR 0011 decision R12; ADR 0012 decision T6; ADR 0013 decision U7). It
remains an interior value: never a standalone key, event topic, or
signed field.

Incident declarer requirements [EC-INCIDENT-ROLE]:

1. `incidentDeclarerRole` is an ADR 0004 role identifier, never a raw
   address (ADR 0010 decision D7.4). Freezing a policy freezes the role
   binding; the holder behind the role rotates through ADR 0004 governance
   over decades without touching the frozen policy.
2. At declaration time the coordinator must resolve the role through the
   ADR 0004 admin/governance registry and accept the caller only if the
   registry confirms the caller currently holds the role. Embedding a raw
   declarer address in a fresh-recovery policy is nonconformant.
3. The genesis vocabulary entry for this authority is
   `ROLE_ENTROPY_INCIDENT_DECLARER`; the role-constant vocabulary is owned
   by [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
   [GOV-ROLES].
4. Role holders must satisfy the protocol custody bar: Safe/multisig or
   governance contracts, not long-lived EOAs (ADR 0010 decision D7.5).

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
   `REQUESTED` entropy — token-keyed or scope-keyed [EC-SCOPE] — against
   the current coordinator unless an already-frozen fresh-recovery policy
   explicitly covers coordinator replacement for that collection.
5. The old coordinator remains deployed, non-self-destructible, and queryable
   indefinitely. Incident revocation can block new requests or fulfillments but
   must not make finalized seeds or request history unreadable.
6. A successor coordinator must not rederive or refinalize seeds for tokens
   registered under a previous coordinator.
7. Safe-mode coordinators must expose the same read ABI —
   `IStreamEntropyView` semantics and the `EntropyStatus` vocabulary — and
   register tokens with status `REGISTERED` or a terminal non-random
   status. "Same shape" means read ABI, not storage layout: a safe-mode
   coordinator may use a cheaper storage packing so registration fits
   comfortably inside `ENTROPY_REGISTRATION_GAS_LIMIT` [EC-REGGAS].
   Transitioning from safe-mode to a full coordinator affects only newly
   minted tokens unless a frozen recovery policy explicitly moves pending
   requests.
8. Deployment manifests list every prior coordinator, its code hash, status,
   and collections, tokens, and scope subjects whose entropy reads remain
   pinned to it.
9. The raisable registration cap [EC-REGGAS] plus this replaceable pointer
   are the explicit never-brick recovery chain for the mint path (ADR 0010
   decision D1.5): no gas repricing short of block-gas-limit scale can
   permanently stop registration, because the cap can always be raised and
   a leaner coordinator can always be staged.

## Provider Registry

The coordinator should maintain provider lifecycle state:

```solidity
event EntropyProviderStateUpdated(
    uint16 schemaVersion,
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
recovery path before production tooling exposes it.

Collection provider epochs:

1. The coordinator should maintain a collection-level `providerEpoch`.
2. `providerEpoch` increments whenever the provider, provider config hash, or
   fallback policy changes.
3. Every request records the epoch in force when it was made.
4. Fulfillment checks the request's recorded epoch, not merely the collection's
   current provider address.
5. Replaced providers may fulfill requests from their original epoch only if
   the policy still allows old-epoch fulfillment.
6. Otherwise, old-epoch callbacks emit `StaleEntropyFulfillment`, do not
   mutate token seed, and return `REJECTED_STALE_EPOCH` (ADR 0009
   decision 25).

## Recommended Genesis Provider Policy

At genesis, the default high-assurance provider should be a new Stream-native
VRF adapter:

```text
default high-assurance provider   StreamEntropyProviderVRF
required reviewed fallback        ARRNG preferred, Pyth as the reviewed alternate
instant / pseudo providers        excluded at genesis (ADR 0009 decision 24)
additional providers              added as new adapters through registry
```

The coordinator produces the final canonical seed. Providers supply raw
randomness; they do not define the artist-facing token hash by themselves.

Recommended policy:

1. High-value fully generative collections should use
   `StreamEntropyProviderVRF` by default.
2. The genesis deployment ships dual providers (ADR 0009 decision 21):
   Chainlink VRF as the primary provider plus one reviewed fallback
   provider, with ARRNG as the preferred fallback candidate (existing
   operational experience) and Pyth as the reviewed alternate. A VRF-only
   deployment is not conformant; the former reviewed VRF-only exception
   path is removed. If neither fallback review completes, deployment
   blocks.
   The shipped fallback choice must be retained in a checksum-covered
   `StreamEntropyLaunchDecision` manifest, either as
   `release-artifacts/latest/entropy-launch-decision.json` or as an equivalent
   release-manifest record, with:
   - `mode = ARRNG_FALLBACK | PYTH_FALLBACK`;
   - selected provider addresses, code hashes, policy hashes, and review
     evidence hashes;
   - coordinator behavior when the selected provider is unavailable;
   - the operational monitor and incident-response path for pending requests.
   The manifest records which fallback shipped, its review evidence, and the
   coordinator failure posture. The coordinator may route only through the
   precommitted reviewed fallback path recorded in the manifest; no silent
   substitution of an unreviewed randomness source is allowed.
3. No instant or pseudo provider ships at genesis (ADR 0009 decision 24). A
   reviewed instant provider added later as a Replaceable module must be
   disabled by default and enabled only by explicit collection
   configuration.
4. Instant or pseudo providers, where later added, should include clear
   security assumptions in the collection provenance notes when used.
5. Provider and fallback choices should be configured and frozen before public
   minting begins for collections where entropy affects artwork.
6. Existing NextGen randomizer contracts may inform implementation, but should
   not be wired into production Core/Coordinator without being rewritten to the
   provider adapter interface and reviewed under this spec.
7. Protocol v1 should set fresh entropy recovery attempts to zero for VRF
   collections unless the recovery state machine has been separately audited.
   Delivery retry of already-received randomness may be enabled because it
   does not reroll.

## Collection Configuration

Admins configure collection entropy before minting:

```solidity
function configureFreshRecoveryPolicy(
    bytes32 policyId,
    uint16 maxFreshRecoveryAttempts,
    bytes32 incidentDeclarerRole,
    bytes32 reasonSchemaHash,
    bytes32 policyManifestHash,
    FreshRecoveryStep[] calldata steps
) external;

function freezeFreshRecoveryPolicy(bytes32 policyId) external;

event FreshRecoveryPolicyConfigured(
    uint16 schemaVersion,
    bytes32 indexed policyId,
    bytes32 indexed policyHash,
    uint16 maxFreshRecoveryAttempts,
    bytes32 incidentDeclarerRole,
    bytes32 policyManifestHash
);

event FreshRecoveryPolicyFrozen(
    uint16 schemaVersion,
    bytes32 indexed policyId,
    bytes32 indexed policyHash
);
```

Fresh recovery policies are configured before collection configs reference
them. A collection can use a policy only after it is frozen. Freezing a
policy means its step list, incident declarer role, reason schema, max
attempts, and manifest hash cannot change. Updating any of those fields
requires a new `policyId`. The frozen `incidentDeclarerRole` is a role
reference, not a holder address [EC-INCIDENT-ROLE].

```solidity
function configureCollectionEntropy(
    uint256 collectionId,
    EntropyMode mode,
    EntropySecurityClass securityClass,
    address provider,
    bytes32 collectionSalt,
    bytes32 providerConfigHash,
    bool publicRequestsEnabled,
    uint64 requestTimeoutBlocks,
    uint16 maxFreshRecoveryAttempts,
    bytes32 freshRecoveryPolicyId
) external;
```

Rules [EC-CONFIG]:

1. `provider` must be active unless `mode == DISABLED`.
2. `requestTimeoutBlocks` must be nonzero for async providers. It is the
   collection's declared incident-timeout floor; the operative window is
   the effective request timeout of [EC-TIME] (ADR 0012 decision T1).
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
11. `mode == INSTANT` must be rejected unless
    `securityClass == LOW_SECURITY` (ADR 0010 decision D8.8). The declared
    class freezes with the config, is disclosed by
    `collectionEntropyConfig`, and must be surfaced in collection
    provenance and metadata notes and in default token JSON as
    `properties.stream.entropy_security_class`, in pending-state and
    finalized JSON alike (ADR 0011 decision R12); the token-JSON field
    pinning and renderer conformance test are owned by
    [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md).
    `HIGH_ASSURANCE` is the default and forbids instant mode.
12. Gas-limit-class values are never part of collection entropy identity:
    provider config hashes exclude Operational-layer parameters per
    [`docs/stream-entropy-providers.md`](stream-entropy-providers.md)
    [EP-CONFIGHASH], so retuning gas, funding, or custody never increments
    `providerEpoch` and never disturbs a frozen collection (ADR 0010
    decision D1.3).
13. Collections with `mode == ASYNC` must declare a collection reveal
    policy [EC-REVEAL] before public mint, and `freezeCollectionEntropy`
    must reject an `ASYNC` collection whose reveal policy is undeclared
    (ADR 0011 decision R8). The reveal policy freezes with the entropy
    config.
14. Artist consent boundary (ADR 0013 decision U4). For an artist-bound
    collection
    ([`docs/stream-artist-authority.md`](stream-artist-authority.md)
    [AA-BINDING]), the entropy configuration is content, not operations:
    the values it fixes — provider, security class, `collectionSalt`,
    `providerConfigHash`, and the linked fresh-recovery policy — are
    seed inputs that determine what sold generative tokens render. The
    artist's recorded collection consent must bind the entropy
    configuration hash in force at consent; the binding mechanism and
    consent payloads are owned by the artist-authority home. From the
    first minted token until executed finality, the coordinator must
    apply an entropy config change — ordinary or incident-path — only
    with a verified artist content consent over the resulting config
    state, checked through the consent surface owned by [AA-CONTENT]
    (storage-side mirror [CMC-ARTIST-CONTENT-VETO] in
    [`docs/collection-metadata-contract.md`](collection-metadata-contract.md));
    where no artist authority is live, the [AA-RECOVERY] requirement 2
    unavailability-finding fallback applies. Entropy-admin authority
    alone never suffices for these collections. Operational overlays
    stay outside this boundary: GGP/GTP retunes (rule 12, [EC-TIME]
    rule 5), reveal-fee retuning ([EC-REVEAL] rule 9), and escrow
    funding change no seed input and need no consent.

Freeze:

```solidity
function freezeCollectionEntropy(uint256 collectionId) external;
```

Freezing prevents provider, salt, mode, recovery policy, reveal policy,
and declared lifecycle-window changes for the collection. Two named
Operational overlays remain governable after freeze without touching any
frozen declaration: the governed time parameters, which can never
shorten an effective window below the frozen declaration ([EC-TIME],
ADR 0012 decision T1), and the reveal-fee funding value ([EC-REVEAL]
rule 9, ADR 0012 decision T7).

## Governed Time Parameters [EC-TIME]

Entropy lifecycle windows are block-denominated liveness gates, and a
frozen block count silently rescales its wall-clock meaning with every
consensus-timing change. They are therefore Governed Time Parameters
(GTPs) under the pattern home
[`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
[LTA-GTP] (ADR 0012 decision T1); this section instantiates the
coordinator-hosted parameters and the per-collection freeze semantics
the pattern home delegates here.

| Parameter | Immutable floor | Window it governs |
| --- | --- | --- |
| `ENTROPY_REQUEST_TIMEOUT_BLOCKS` | `ENTROPY_REQUEST_TIMEOUT_FLOOR` | Unrecoverable-marking eligibility ([EC-INCIDENT] rule 2) |
| `ENTROPY_REVEAL_SLO_BLOCKS` | `ENTROPY_REVEAL_SLO_FLOOR` | Reveal SLO and permissionless-fallback lapse ([EC-REVEAL] rules 3–4) |
| `ENTROPY_RECOVERY_STEP_DELAY_BLOCKS` | `ENTROPY_RECOVERY_STEP_DELAY_FLOOR` | Fresh-recovery step eligibility (`FreshRecoveryStep.notBeforeBlocks`) |

Requirements [EC-TIME]:

1. `ENTROPY_REQUEST_TIMEOUT_BLOCKS`, `ENTROPY_REVEAL_SLO_BLOCKS`, and
   `ENTROPY_RECOVERY_STEP_DELAY_BLOCKS` are coordinator-hosted GTPs
   under the [LTA-GTP] pattern: storage-backed host values paired with
   deploy-time immutable floors, identified by the `GTP_`-prefixed
   parameter identifiers in the
   [Domain Constants](#domain-constants-ec-domains)
   table, recorded in the release manifest with genesis value, floor,
   host, and pinned wall-clock intent (seconds at the genesis cadence),
   and named members of the repricing/consensus-timing review checklist
   — all per the pattern home, which this section instantiates rather
   than restates.
2. Effective-window rule — the per-collection config-freeze semantics
   that [LTA-GTP] definition item 1 delegates to this document. At
   every evaluation the coordinator reads the live host value and
   applies the maximum of it and the collection's frozen declaration,
   token-keyed and scope-keyed alike:
   1. the effective request timeout is `max(requestTimeoutBlocks,
      ENTROPY_REQUEST_TIMEOUT_BLOCKS)`, consumed by [EC-INCIDENT]
      rule 2;
   2. the effective reveal SLO is `max(requestSLOBlocks,
      ENTROPY_REVEAL_SLO_BLOCKS)`, consumed by [EC-REVEAL] rules 3–4;
   3. the effective recovery-step delay is `max(notBeforeBlocks,
      ENTROPY_RECOVERY_STEP_DELAY_BLOCKS)` for each
      `FreshRecoveryStep`, counted from the block of the incident
      action (or exhausted prior step) that made the step eligible.
   The frozen declaration is never the parameter: it is a collection
   timing policy (ADR 0013 decision U9) — the collection's promised
   minimum, bounding every retune from below, with none of the GTP
   closed world's identifier, probe, or mirror-row obligations — so
   the pre-lapse public-request exclusivity (ADR 0009 decision 22) and
   the original provider's declared patience hold for the life of the
   collection.
3. Escalation gates open late, never early. Every window above gates an
   escalation — an unrecoverable declaration, a public request, a
   fallback-provider draw — whose premature firing is a reroll or
   exclusivity hazard and whose late firing is a bounded liveness cost.
   The immutable floors, the frozen declarations, and the max() rule
   enforce onchain that no retune opens a gate earlier than both allow;
   a governed lower restores a cadence-inflated window only down to
   those bounds.
4. Change discipline is the pattern home's, cited not restated: the
   canonical governance action on the normal delay class, per-action
   raise and lower bounds, cadence-probe-gated lowers, and no emergency
   or permissionless conditional path for any time parameter
   ([LTA-GTP]; ADR 0012 decision T1).
5. The values are Operational-layer ([LTA-GTP]): excluded from entropy
   identity, policy manifests, provider config hashes, seed derivation,
   and provider epochs, exactly as [EC-CONFIG] rule 12 excludes gas
   (ADR 0010 decision D1.3). Retuning a window never disturbs a frozen
   collection and never changes any seed.
6. Cadence probe: the three parameters share the coordinator's named
   cadence probe — a Permanent-class probe contract under
   [LTA-GGP-PROBES], recorded per parameter in the release manifest
   with its `probeMaxAgeBlocks` — whose recorded observed-cadence runs
   gate lowers and feed the review ([LTA-GTP]). Observed cadence drift
   beyond the manifest tolerance is a monitored review trigger under
   the same incident regime as [EC-REVEAL] rule 8.
7. Genesis posture: each genesis value equals its floor, so the overlay
   is inert — every effective window equals the collection's declared
   value wherever that declaration meets the floor — until a cadence
   change justifies a staged raise. Planning targets for the pinned
   wall-clock intents at the 12s deployment cadence: 24 hours for the
   request timeout and one hour each for the reveal SLO and the
   recovery-step delay. The deployed floors come from the recorded
   sizing rationale, not from this prose.
8. Accepted residual (ADR 0012 decision T1): block-cadence slowdown
   lengthens frozen declared windows in wall-clock terms, and no
   governance action may shorten a window below a collection's frozen
   declaration. Escalations arrive late, never early; delivery retry,
   reveal-owner and admin requests, and incident handling all remain
   available throughout the longer wait.
9. Every change emits the parameter-named alias event below — an alias
   member of the canonical `TimeParameterUpdated` change-event family
   per [LTA-GTP], tagged as such in the event catalog:

```solidity
event EntropyTimeParameterUpdated(
    uint16 schemaVersion,
    bytes32 indexed parameterId,
    uint256 oldValueBlocks,
    uint256 newValueBlocks,
    uint256 floorBlocks
);
```

## Token Registration Flow

This is the target flow for the entropy-coordinator PR. The current CON-012
Core hook slice still uses the legacy direct randomizer boundary after
`_safeMint`, so it must not be cited as evidence that entropy is observable
before receiver callbacks.

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
3. Collection config must exist. Per-collection entropy configuration is
   required and must be configured (and frozen where promised) before sale
   start; there is no coordinator-level global default provider, because a
   global default is an implicit dependency and changes the meaning of
   "unconfigured" (ADR 0009 decision 23).
4. If config mode is `DISABLED` or the render path is `NOT_REQUIRED`, the
   coordinator must record an explicit terminal token entropy status. Disabled
   collections must not revert minting because no provider is configured, and
   renderers must treat the token as intentionally not entropy-backed. A no-op
   success that leaves no token entropy record is not deployment-conformant.
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
    uint16 schemaVersion,
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
requestEntropy(tokenId) [nonReentrant, payable]
  verifies token is REGISTERED, or STALE/FAILED with approved incident recovery
  rejects prepared-incomplete tokens and terminal DISABLED/NOT_REQUIRED tokens
  rejects if token is already REQUESTED or FINALIZED
  resolves collection config and provider
  snapshots provider epoch and provider config hash
  builds requestKey
  stores active request and marks token REQUESTED before any provider call
  quotes fee = provider.quoteRequest(context) in the same transaction
  draws the fee from the reveal escrow first where declared [EC-REVEAL],
    requires msg.value to cover any shortfall, and credits msg.value
    excess to the payer [EC-FEEBIND]
  calls provider.requestEntropy{value: fee}(requestKey, context)
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
    uint16 schemaVersion,
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

Native ETH request payments bind the caller's `msg.value` as a maximum fee
against a same-transaction provider quote, with pull-credit refund of any
excess (ADR 0010 decision D8.7). This closes exact-payment griefing under
provider fee drift: a fee change between the caller's offchain quote and
execution cannot fail a request whose `msg.value` still covers the new fee,
and a fee decrease refunds rather than reverts.

Requirements [EC-FEEBIND]:

1. `requestEntropy` may be payable for providers that need native ETH.
   `msg.value` is the caller-supplied `maxFeeWei`: the binding upper bound
   on the caller-funded portion of what the request may pay.
2. The coordinator must obtain the required fee by calling
   `provider.quoteRequest(context)` in the same transaction, before the
   provider request call [EP-QUOTE]. Offchain or prior-block quotes are
   never binding.
3. If the available funding — `msg.value`, plus the reveal-escrow draw
   where rule 9 applies — is less than the quoted fee, `requestEntropy`
   must revert with a typed error carrying the quoted fee.
4. The coordinator must forward exactly the quoted fee to the provider.
   Adapters keep exact-payment discipline at their boundary; the
   coordinator, never the adapter, absorbs caller overpayment.
5. Any excess (`msg.value` minus fee) must be credited to the payer as a
   pull-based refund credit in the same transaction and evented. Push
   refunds inside `requestEntropy` are forbidden.
6. Refund credits are withdrawable through a dedicated non-reentrant claim
   function that zeroes the credit before transfer and reverts the claim
   on a failed transfer. Only the credited payer can claim, to a
   destination it names.
7. The coordinator must not become a general ETH custody contract: tracked
   refund credits and the tracked per-collection reveal-fee escrows
   [EC-REVEAL] are the only balances it may hold across transactions.
   Accidental or forced ETH recovery, if included, must be admin-only,
   evented, sent to the protocol treasury, and provably unable to reduce
   the aggregate of tracked refund credits and reveal-fee escrows.
8. Fee credits and reveal-fee escrows are Operational balances: excluded
   from entropy identity, policy manifests, and seed derivation.
9. For tokens of a collection with a declared reveal policy, the quoted
   fee is drawn from the collection's reveal-fee escrow first and from
   `msg.value` only for any shortfall [EC-REVEAL]; the pull-credit rules
   above apply to the `msg.value` portion, and the undrawn escrow
   remainder stays in escrow. Scope requests [EC-SCOPE] are always
   caller-funded and never draw from the reveal escrow.

Refund credit surface:

```solidity
mapping(address payer => uint256 creditWei) entropyFeeCredits;

function entropyFeeCredit(address payer) external view returns (uint256);

function claimEntropyFeeCredit(address to) external;

event EntropyFeeCredited(
    uint16 schemaVersion,
    address indexed payer,
    uint256 indexed tokenId,
    uint256 quotedFeeWei,
    uint256 creditedWei
);

event EntropyFeeCreditClaimed(
    uint16 schemaVersion,
    address indexed payer,
    address indexed to,
    uint256 amountWei
);
```

Request transition guards [EC-REQUEST-GUARDS]:

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
   status is not `REQUESTED`. Wrong providers are hard violations and revert
   with typed errors; the benign classes return their
   `EntropyFulfillmentOutcome` codes without reverting (ADR 0009
   decision 25).
8. For `INSTANT` mode, v1 uses the bounded
   `IStreamInstantEntropyProvider.instantEntropy(requestKey, context)`
   read/return path from inside `requestEntropy`; it must not use an external
   callback into `fulfillEntropy`. The path is reachable only for
   collections whose frozen config declares
   `EntropySecurityClass.LOW_SECURITY` (ADR 0010 decision D8.8) [EC-CONFIG].
   The coordinator finalizes once from the
   returned raw value before `requestEntropy` returns. If the instant read
   fails, the transaction reverts and the pre-call `REQUESTED` state unwinds.
   The instant provider function must be `view`, and release static analysis
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
5. Provider callbacks must store raw randomness before calling the
   coordinator and must deliver through try/catch [EP-CALLBACK]
   (ADR 0010 decision D8.1).
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

These commitment rules apply verbatim to scope entropy requests [EC-SCOPE]:
a scope subject is one commitment, exactly like a token.

## Scope Entropy Requests

Token-keyed requests cover per-token seeds. Some mechanics need one
verifiable random value for a subject that is not a token: raffle winner
selection for an oversubscribed drop, duplicate-free random assignment of
a curated set, and collection-wide reveal offsets. The coordinator
therefore supports a second, sale/collection-scoped request kind with its
own request-key domain (ADR 0011 decision R8). Scope requests reuse the
token request lifecycle wholesale — the frozen provider interface,
provider epochs, timeout, delivery retry, stale handling, incident
recovery, and the Request Commitment Finality rules — so a raffle or
assignment adapter inherits this spec's anti-reroll hardening instead of
integrating a randomness provider on its own.

A scope subject is identified by a domain-separated scope ID:

```solidity
bytes32 scopeId = keccak256(abi.encode(
    STREAM_ENTROPY_SCOPE_SUBJECT_V1,
    block.chainid,
    address(this),
    streamCore,
    collectionId,
    uint8(scopeKind),
    scopeRef
));
```

`scopeKind` is an `EntropyScopeKind` value; `scopeRef` names the subject
inside that kind: the sales-spec `saleId` for `SALE`
([`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) owns
`saleId` semantics), the phase policy hash for `PHASE`, and a documented
collection-scoped purpose constant for `COLLECTION`.

Recommended scope state:

```solidity
struct ScopeEntropy {
    EntropyStatus status;
    uint256 collectionId;
    uint8 scopeKind;
    bytes32 scopeRef;
    address provider;
    uint32 providerEpoch;
    bytes32 requestKey;
    uint256 providerRequestId;
    bytes32 scopeInputsHash;
    bytes32 rawRandomness;
    bytes32 seed;
    uint64 registeredAtBlock;
    uint64 requestedAtBlock;
    uint64 finalizedAtBlock;
    uint16 requestAttempt;
}

mapping(bytes32 scopeId => ScopeEntropy) scopeEntropies;
```

Scope request keys and scope seeds use the scope domains, never the token
domains:

```solidity
bytes32 requestKey = keccak256(abi.encode(
    STREAM_ENTROPY_SCOPE_REQUEST_V1,
    block.chainid,
    address(this),
    streamCore,
    collectionId,
    scopeId,
    provider,
    providerEpoch,
    providerConfigHash,
    scopeInputsHash,
    requestAttempt
));

bytes32 seed = keccak256(abi.encode(
    STREAM_ENTROPY_SCOPE_SEED_V1,
    block.chainid,
    address(this),
    streamCore,
    collectionId,
    scopeId,
    provider,
    providerEpoch,
    providerConfigHash,
    requestKey,
    providerRequestId,
    rawRandomness,
    collectionSalt,
    scopeInputsHash
));
```

The request context passed to providers uses context schema version 2,
carrying the scope ID where the token context carries a token ID:

```solidity
bytes memory context = abi.encode(
    uint16(2),          // context schema version: scope request
    streamCore,
    collectionId,
    scopeId,
    providerEpoch,
    providerConfigHash,
    requestAttempt
);
```

Requirements [EC-SCOPE]:

1. The scope request surface is a Permanent coordinator interface shipped
   at genesis. Consumers — raffle adapters, random-assignment gates,
   reveal tooling — are Replaceable modules with their own accepted specs.
   Onchain raffle and random-allocation sale mechanics are extension
   profiles that must consume this surface rather than integrate a
   randomness provider directly; the sale-side profile home is
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md).
   Instant entropy finalization inside sale settlement remains forbidden
   ([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
   [LCM-FORBIDDEN] item 11).
2. `registerEntropyScope` is callable by the minter path and entropy
   admins for a collection whose entropy config exists. A scope subject
   registers exactly once; a duplicate `scopeId` reverts. Registration
   writes status `REGISTERED` and emits `EntropyScopeRegistered`. For
   `SALE` scopes, the scope should be registered before the sale's entry
   window opens, so the drawing mechanism is committed before anyone
   enters.
3. Scope requests use the collection's frozen entropy config: provider,
   provider epoch, provider config hash, `collectionSalt`, the declared
   `requestTimeoutBlocks` (applied as the effective window, [EC-TIME]
   rule 2), and fresh-recovery policy. The collection's
   `mode` must be `ASYNC`: scope entropy is async-only, and no instant
   path may finalize a scope seed for any security class.
   `requestScopeEntropy` must satisfy the [EC-REQUEST-GUARDS] reentrancy
   guard and write-active-state-before-any-provider-call ordering.
4. `scopeInputsHash` commits to the complete subject set the seed will
   resolve over — the closed entry list root for a raffle, the assignment
   manifest hash for a curated set, the declared offset target for a
   reveal. It must be fixed and published before the request. The
   coordinator stores it on the first request, binds it into the request
   key and seed, and every recovery re-request must reuse the stored
   value: no path can bind a different subject set to an
   already-requested scope. Entry-set closing rules for `SALE` scopes are
   owned by the sales spec.
5. Scope status reuses the `EntropyStatus` vocabulary: `NONE`
   (unregistered), `REGISTERED`, `REQUESTED`, `FINALIZED`, `STALE`, and
   `FAILED`. `DISABLED` and `NOT_REQUIRED` are token-only and unreachable
   for scopes. Scope records are not rows in the token lifecycle
   reconciliation matrix [EC-LIFECYCLE], which maps token conditions only.
6. One seed per scope subject, forever. `FINALIZED` is terminal; a
   finalized, stale, or failed scope retains its request binding, cannot
   be re-registered, and cannot receive a quiet second output. Fresh
   recovery follows [EC-INCIDENT] — including its coordinator-state and
   evidence requirements — through scope-keyed equivalents:
   `markScopeEntropyRequestUnrecoverable(scopeId, reasonURI,
   evidenceHash)`, `ScopeEntropyRequestFailed`, and
   `StaleScopeEntropyFulfillment` mirror the token functions and events
   with `scopeId` in place of `tokenId`.
7. Fulfillment is shared: providers fulfill scope requests through the
   unchanged `fulfillEntropy(requestKey, rawRandomness)` under all
   [EC-FULFILL] rules and `EntropyFulfillmentOutcome` codes. Adapters
   cannot and need not distinguish token from scope requests; request
   keys and context are opaque at the adapter boundary
   ([`docs/stream-entropy-providers.md`](stream-entropy-providers.md)
   [EP-CONTEXT]).
8. Scope finalization emits `ScopeEntropyFinalized` and must not call the
   restricted Core ERC-4906 refresh emitter: there is no token subject to
   refresh. Consumers index the scope events.
9. Scope requests are caller-funded under [EC-FEEBIND]: `msg.value` is
   the caller's `maxFeeWei` and excess is a pull credit. They never draw
   from the reveal-fee escrow [EC-REVEAL].
10. Scope reads are bounded like token reads [EC-VIEWREAD]: `scopeSeed`
    returns exactly 64 bytes and `scopeEntropy` a fixed 480-byte struct
    tuple; both are O(1) storage reads with no external calls. Scope
    records stay pinned to, and readable from, the coordinator that
    registered them under the coordinator replacement rules.
11. Consumers must resolve outcomes from the finalized scope seed and the
    committed inputs deterministically — the canonical fair-allocation
    ranking is pinned in [EC-SCOPE-RAFFLE] — with the exact derivation
    pinned in the consuming spec so any party can recompute the result.
    Consumers must not mix a scope seed with inputs chosen after the
    request.

Events:

```solidity
event EntropyScopeRegistered(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed scopeId,
    uint8 scopeKind,
    bytes32 scopeRef
);

event ScopeEntropyRequested(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed scopeId,
    address indexed provider,
    bytes32 requestKey,
    uint256 providerRequestId,
    uint32 providerEpoch,
    bytes32 providerConfigHash,
    bytes32 scopeInputsHash,
    uint16 requestAttempt
);

event ScopeEntropyFinalized(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    bytes32 indexed scopeId,
    address indexed provider,
    bytes32 requestKey,
    uint256 providerRequestId,
    bytes32 seed,
    bytes32 rawRandomness
);
```

### Fair-Allocation Scope Recipe [EC-SCOPE-RAFFLE]

Oversubscribed-drop fair allocation — raffle winner selection and
duplicate-free random assignment of a pre-committed curated set — is a
frozen recipe over this surface (ADR 0012 decision T6), so a future
raffle or random-allocation adapter inherits committed safety semantics
instead of reconstructing intent decades later. The sale-side extension
profile — entry windows, escrowed entry deposits, refunds, winner
claims, and the entry-set closing rules — is owned by
[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md);
the coordinator-side sequence below is the part that profile consumes
and cites. The coordinator still resolves no outcome itself (Non-Goals
item 7): this recipe pins the derivation consumers must apply.

Requirements [EC-SCOPE-RAFFLE]:

1. Commitment before entries: the consuming sale registers its
   `SALE`-kind scope before the entry window opens — the [EC-SCOPE]
   rule 2 "should" is a "must" for this recipe — so the drawing
   mechanism (provider, epoch, config hash, salt) is committed onchain
   before the first entry exists.
2. Entry-root closure: `scopeInputsHash` must commit to the complete
   closed subject set — the root of the ordered entry list for a
   raffle, or the assignment manifest hash for a curated set — computed
   only after the entry window has closed. `requestScopeEntropy` must
   not be called while entries can still change, and the stored root is
   immutable across recovery re-requests ([EC-SCOPE] rule 4), so no
   path can add, remove, or reorder entrants after the request.
   Preimage publication and availability rules for the entry list are
   owned by the sale-side profile.
3. Canonical ranking: outcomes derive from exactly the finalized scope
   seed and the committed entry list. The canonical rank key of the
   0-based `entryIndex` into the committed ordered entry list is

   ```solidity
   bytes32 rankKey = keccak256(abi.encode(
       STREAM_ENTROPY_SCOPE_RANKING_V1,
       seed,
       uint256(entryIndex)
   ));
   ```

   with entries ordered by ascending `rankKey`: the first `W` ranked
   entries win a `W`-winner raffle, and curated-set assignment maps
   ranked entries to manifest slots in committed order. Distinct entry
   indexes make ties impossible. A consuming profile must pin this
   derivation, or a stricter refinement of it, verbatim; every outcome
   must be recomputable by any party from onchain data alone
   ([EC-SCOPE] rule 11), and no input chosen after the request may
   enter it.
4. One draw per sale: the raffle scope is one commitment ([EC-SCOPE]
   rule 6). A stalled, stale, or failed draw follows [EC-INCIDENT]
   through the scope-keyed path under the effective windows [EC-TIME];
   the sale-side profile must declare its abort remedy (refund every
   entry) rather than redraw outside the frozen fresh-recovery policy.
5. Separation from token seeds: allocation is a sale-layer outcome. The
   scope seed must not enter any token seed derivation; winning entries
   mint through the normal sale and mint path, and their tokens draw
   token-keyed entropy as usual.

## Reveal Ownership And Funding

Registration at mint is not a reveal. For async collections the visible
collector experience is the gap between mint and `FINALIZED`, and that
gap must not be unowned: a named party is responsible for requesting, a
funded path exists for the provider fee, and a lapse remedy engages
without permission. Reveal operations are owned (ADR 0011 decision R8):
collections declare a reveal owner with an SLO, sales escrow a per-mint
reveal fee that funds the requests, and a permissionless request fallback
engages after the SLO lapses.

Recommended policy state and surface:

```solidity
struct CollectionRevealPolicy {
    bool declared;
    RevealRequestMode requestMode;
    bytes32 revealOwnerRole;
    uint64 requestSLOBlocks;
    uint256 revealFeePerTokenWei;
}

mapping(uint256 collectionId => CollectionRevealPolicy) revealPolicies;
mapping(uint256 collectionId => uint256 escrowWei) revealFeeEscrows;

function configureCollectionRevealPolicy(
    uint256 collectionId,
    RevealRequestMode requestMode,
    bytes32 revealOwnerRole,
    uint64 requestSLOBlocks,
    uint256 revealFeePerTokenWei
) external;

function updateRevealFeePerToken(
    uint256 collectionId,
    uint256 newRevealFeePerTokenWei
) external;

function fundRevealFeeEscrow(uint256 collectionId) external payable;
```

Requirements [EC-REVEAL]:

1. Every collection configured with `mode == ASYNC` must declare a reveal
   policy before public mint; the policy freezes with the collection
   entropy config [EC-CONFIG] rule 13 — every field except the
   Operational `revealFeePerTokenWei` funding value (rule 9; ADR 0012
   decision T7). `revealOwnerRole` is an ADR 0004
   role identifier resolved through the registry at call time, never a
   raw address, under the same discipline as [EC-INCIDENT-ROLE]; the
   genesis vocabulary entry is `ROLE_ENTROPY_REVEAL_OWNER`, owned by
   [`docs/adr/0004-admin-governance.md`](adr/0004-admin-governance.md)
   [GOV-ROLES]. Role holders satisfy the protocol custody bar (ADR 0010
   decision D7.5).
2. `AT_MINT` mode: the minter path attempts `requestEntropy(tokenId)` in
   the mint transaction, after `mintFromManager` has returned and
   registration is complete. A failed attempt must not unwind the mint:
   the token remains `REGISTERED`, enters the SLO window, and the reveal
   owner or fallback completes the request. This preserves the
   never-brick posture — mint success never depends on provider uptime.
   The attempt is a named bounded call, never an adjective (ADR 0013
   decision U7): because its call chain — adapter to coordinator to
   provider adapter to upstream source — reaches third-party provider
   code inside the collector's purchase transaction, the sale adapter
   forwards at most the adapter-held `REVEAL_ATTEMPT_GAS_LIMIT`
   Governed Gas Parameter, with the EIP-150 63/64 parent precheck and
   try/catch isolation, per the adapter external-call rule
   [SSA-ADAPTER] rule 9. Sale-adapter conformance for the
   attempt-and-catch call shape and that parameter's normative home,
   floor, and manifest pinning are owned by
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   [SSA-REVEAL]; this document guarantees the coordinator side: the
   full `requestEntropy` gas envelope — including the configured
   provider's quote and request calls through upstream request
   submission — is measured per genesis provider and published in the
   release manifest, so the bound and its floor are sized with a
   stated margin and a pathological upstream cannot inflate purchase
   gas beyond the cap.
   `AT_MINT` is the default posture for priced sales of `ASYNC`
   collections; declaring `OWNER_WINDOW` instead requires a recorded
   rationale in the reveal operations manifest.
3. `OWNER_WINDOW` mode: the reveal owner must request entropy for each
   registered token within the effective reveal-SLO window ([EC-TIME]
   rule 2) of that token's `registeredAtBlock`. `requestSLOBlocks` is
   the declared floor of that window: it must be nonzero in every
   declared policy and must be at least the reveal owner's recorded
   worst-case holder latency plus margin, per the window-sizing rule of
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-GOV] rule 6; the reveal-operations-manifest gate checks the
   declared SLO against that recorded latency (ADR 0012 decision T5).
4. Permissionless fallback: once `block.number` exceeds
   `registeredAtBlock` plus the effective reveal-SLO window ([EC-TIME]
   rule 2) for a token that is still `REGISTERED`, anyone may call
   `requestEntropy(tokenId)` for it, regardless of
   `publicRequestsEnabled`. This time-gated lapse remedy is the decided
   exception to opt-in public requests (ADR 0011 decision R8); ADR 0009
   decision 22 continues to govern the pre-lapse window. The fallback
   pays the provider fee from the reveal-fee escrow [EC-FEEBIND] rule 9,
   so a lapsed reveal costs the fallback caller only gas while the
   escrow covers the live quote; if provider fee drift has outrun the
   escrow, the fallback stays available with the shortfall payable from
   `msg.value` — a monitored, remediable funding condition under
   rules 8–9 (ADR 0012 decision T7), never a spec-accepted steady
   state.
5. Funding: for priced sale kinds, the sale layer escrows
   `revealFeePerTokenWei` per minted token into the coordinator's
   per-collection reveal-fee escrow through `fundRevealFeeEscrow`; the
   priced line item, its buyer-side maxFee/pull-credit binding under
   fee drift (ADR 0013 decision U6), and settlement ordering — for
   escrow-holding and deferred sale kinds, escrowed at purchase and
   reconciled at finalization — are owned by
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md).
   Escrow funding flows from the settlement adapter directly to the
   coordinator, keeping the mint manager non-payable
   ([`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)).
   `fundRevealFeeEscrow` accepts permissionless top-ups; more funding is
   never a hazard because spends are rule-bound.
6. The genesis funding default is the operator-funded provider
   subscription (ADR 0011 decision R8): the VRF-class adapter quotes a
   zero request fee [EP-QUOTE], so `revealFeePerTokenWei` may be zero.
   Where the configured provider quotes a nonzero native fee, the
   declared `revealFeePerTokenWei` must cover the provider's quoted fee
   at configuration time and at every rule 9 update, so per-token
   accrual keeps pace with provider fee drift. In both postures the
   reveal operations manifest names the funding source.
7. Escrow discipline: escrow draws never exceed the same-transaction
   provider quote, every draw is evented, and escrow balances are
   Operational — excluded from entropy identity, policy manifests, and
   seed derivation [EC-FEEBIND] rules 7–9. Residual escrow is
   withdrawable only by admin action, evented, to the protocol treasury,
   and only when the collection has no non-terminal token entropy
   records.
8. The reveal operations manifest is a checked release artifact recording
   the reveal owner role and holder, the holder's recorded worst-case
   latency against the declared SLO (rule 3; ADR 0012 decision T5), the
   declared request mode and `requestSLOBlocks`, the target
   mint-to-`FINALIZED` latency, the keeper obligation and monitoring
   alerts (tokens `REGISTERED` past the effective SLO; requests
   `REQUESTED` beyond provider norms; escrow or subscription float below
   the exhaustion threshold; the live escrow-versus-quoted-fee margin of
   rule 9 below its recorded threshold), the funded float and the named
   top-up obligation, and a rehearsed end-to-end reveal run as release
   evidence. A missed SLO, exhausted float, or breached fee margin is a
   monitored incident (ADR 0011 decision R12; ADR 0012 decision T7).
9. `revealFeePerTokenWei` is an Operational funding parameter, never
   entropy identity (ADR 0012 decision T7). After the policy freezes,
   entropy admins may retune it through
   `updateRevealFeePerToken(collectionId, newRevealFeePerTokenWei)`:
   admin-only, evented via `RevealFeePerTokenUpdated`, applying to
   future mints only, and re-sized against the configured provider's
   live quoted fee (rule 6). The frozen promises — request mode, reveal
   owner role, declared SLO — never move with it, already-accrued
   escrow is never restated, and the sale layer charges the live
   declared value per mint under its buyer-side maxFee/pull-credit
   binding: the mutable fee never sits inside an exact-match
   `msg.value` equation, so a retune landing between a buyer's offchain
   quote and inclusion cannot fail a purchase whose payment still
   covers the live value (ADR 0013 decision U6). The priced line item
   and that binding are owned by
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   [SSA-REVEAL].
   Where drift outruns accrual, the remedy chain is the rule 8 margin
   alarm, a fee update for future mints, and the permissionless
   `fundRevealFeeEscrow` top-up for the shortfall — a monitored, funded
   condition, never a silent fallback failure.

Events:

```solidity
event RevealPolicyConfigured(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    uint8 requestMode,
    bytes32 revealOwnerRole,
    uint64 requestSLOBlocks,
    uint256 revealFeePerTokenWei
);

event RevealFeePerTokenUpdated(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    uint256 oldRevealFeePerTokenWei,
    uint256 newRevealFeePerTokenWei
);

event RevealFeeEscrowFunded(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    address indexed funder,
    uint256 amountWei,
    uint256 escrowWei
);

event RevealFeeEscrowSpent(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    uint256 indexed tokenId,
    uint256 amountWei,
    uint256 escrowWei
);

event RevealFeeEscrowWithdrawn(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    address indexed to,
    uint256 amountWei
);
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
function fulfillEntropy(bytes32 requestKey, bytes32 rawRandomness)
    external
    returns (uint8 outcome);
```

`fulfillEntropy` returns a pinned `EntropyFulfillmentOutcome` code (ADR 0009
decision 25). Benign rejections return their outcome and do not revert, so
provider callbacks — including VRF callbacks that must not revert — receive
a machine-readable verdict. Hard violations (unauthorized provider,
reentrancy) still revert with typed errors. Event behavior is unchanged.

Rules [EC-FULFILL]:

1. `fulfillEntropy` must use a reentrancy guard or equivalent state lock;
   reentrancy is a hard violation and reverts with a typed error.
2. `requestKey` must exist; an unknown request key returns
   `REJECTED_UNKNOWN_REQUEST`.
3. Request must be active; an inactive request key returns
   `REJECTED_INACTIVE_REQUEST`.
4. Caller must be the provider stored on the request; an unauthorized caller
   is a hard violation and reverts with a typed error.
5. Provider must not be `INCIDENT_REVOKED`. A revoked bound provider is a
   benign rejection, never a revert (ADR 0010 decision D8.1): the call
   emits `StaleEntropyFulfillment` with the revocation reason, does not
   finalize, and returns `REJECTED_PROVIDER_REVOKED`. The adapter must
   retain its stored result [EP-CALLBACK]; that retained
   `rawRandomnessReceived` proof keeps unsafe fresh recovery blocked while
   an approved recovery policy resolves the request.
6. Token status must be `REQUESTED`; a non-`REQUESTED`, non-finalized token
   returns `REJECTED_INACTIVE_REQUEST`.
7. Token must not already be finalized; an already finalized token returns
   `REJECTED_ALREADY_FINALIZED`.
8. Fulfillment must finalize exactly one canonical seed; successful
   finalization returns `FINALIZED`.
9. Before any external refresh or notification call, fulfillment must mark the
   request inactive and set token status `FINALIZED`.
10. Old request keys after incident recovery must be rejected or emitted as
   stale; the call returns `REJECTED_STALE_EPOCH`.
11. Wrong provider epoch must emit a stale/audit event, must not finalize,
    and returns `REJECTED_STALE_EPOCH`.
12. `fulfillEntropy` cannot call `requestEntropy`; delivery retry calls
    `fulfillEntropy` again with the same stored raw randomness.
13. The full `fulfillEntropy` gas envelope — including the restricted Core
    refresh emitter call after finalization — must be measured and
    published in the release manifest so async providers can size their
    callback gas limits with a stated margin [EP-CALLBACK]. A fulfillment
    frame that runs out of gas inside a provider callback is recoverable:
    the adapter's persisted result plus delivery retry re-deliver the
    identical randomness (ADR 0010 decision D8.1).

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

Scope requests fulfill through the same `fulfillEntropy` function under
the same [EC-FULFILL] rules and outcome codes; their request keys and
seeds derive from the scope domains [EC-SCOPE], and their finalization
emits `ScopeEntropyFinalized` with no ERC-4906 refresh, because no token
subject exists.

Event:

```solidity
event EntropyFinalized(
    uint16 schemaVersion,
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

After fulfillment, the coordinator should cause ERC-4906-style metadata
refresh events for the token:

```solidity
event MetadataUpdate(uint256 tokenId);
```

Metadata refresh events are Core-originated (ADR 0009 decision 5): Core
exposes restricted ERC-4906 refresh emitters callable by authorized
satellites, and the coordinator calls that restricted Core method after
finalization. The metadata router does not expose a refresh hook for this
path. Marketplaces watch the ERC-721 contract, so a refresh event emitted
from a satellite contract that marketplaces will not watch would never
reach them.

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

Provider callbacks must persist the result before delivery and must call
`fulfillEntropy` through try/catch or a checked low-level call so a
coordinator revert can never unwind the stored randomness or bubble into
the upstream randomness callback (ADR 0010 decision D8.1). The normative
callback rules live in
[`docs/stream-entropy-providers.md`](stream-entropy-providers.md)
[EP-CALLBACK].

Delivery retry keeps the same:

1. provider request ID;
2. request key;
3. raw randomness;
4. final seed derivation inputs.

This path is not a reroll and may be permissionless.

### Fresh Entropy Recovery

A fresh provider request for the same token is a recovery event, not a normal
retry. Protocol v1 should disable fresh token-level recovery for high-value
VRF collections by setting `maxFreshRecoveryAttempts = 0` unless the
collection has a complete pre-mint recovery policy that was configured,
evented, and frozen before public mint.

A complete fresh-recovery policy is represented by the frozen
`FreshRecoveryPolicy` linked from `CollectionEntropyConfig`. It must define:

1. the fallback provider list and provider order;
2. provider epochs and provider config hashes;
3. request timeout or incident conditions;
4. maximum fresh attempts;
5. the incident declarer role reference [EC-INCIDENT-ROLE];
6. the required reason URI/hash;
7. whether late fulfillment from the original provider is accepted or stale;
8. the complete no-reroll evidence rule [EC-INCIDENT] rule 3: the
   coordinator's own no-result state, the adapter result-status probe,
   and the independent provider-evidence commitment (ADR 0011 decision
   R12).

If any of those facts were not frozen onchain before mint, the safe v1 answer
is no fresh recovery and `maxFreshRecoveryAttempts` must be zero. Operational
protection should come from request funding monitors, provider health checks,
callback gas runbooks, and delivery retry of already received randomness.

Recommended function:

```solidity
function markEntropyRequestUnrecoverable(
    uint256 tokenId,
    string calldata reasonURI,
    bytes32 evidenceHash
) external;
```

Rules [EC-INCIDENT]:

1. Token must be `REQUESTED`.
2. `block.number` must be greater than `requestedAtBlock` plus the
   effective request-timeout window ([EC-TIME] rule 2; ADR 0012
   decision T1), unless a provider is `INCIDENT_REVOKED`.
3. No-reroll proof is coordinator-state evidence first, adapter testimony
   second (ADR 0011 decision R12). All three parts are required:
   1. Coordinator-state check: the coordinator must verify from its own
      storage that the request produced no result — the token is not
      `FINALIZED`, no seed was written, and the stored request being
      abandoned is the token's active request. The failed adapter can
      neither forge nor erase this state.
   2. Adapter probe: the provider adapter's `providerResultStatus` must
      report that no valid raw randomness was received for the old
      provider request. The coordinator must call this status probe as a
      bounded staticcall under `ENTROPY_RESULT_PROBE_GAS_LIMIT` — a
      coordinator Governed Gas Parameter with immutable floor
      `ENTROPY_RESULT_PROBE_GAS_FLOOR`, governed, monitored, and
      manifest-recorded exactly as [EC-REGGAS] items 2, 4, 5, 7, and 8
      prescribe (ADR 0010 decision D1.1) — and treat failure, malformed
      data, or out-of-gas as "not safe to recover." A
      `rawRandomnessReceived = true` report blocks recovery absolutely.
   3. Independent evidence commitment: the declaration's `evidenceHash`
      must be nonzero and must commit to the incident evidence bundle.
      Where the upstream source is independently observable — for
      VRF-class providers, the upstream coordinator's onchain
      request/fulfillment state and fulfillment logs for the provider
      request ID — the bundle must include that corroboration that no
      upstream fulfillment occurred. Where no independent upstream
      evidence exists for the provider family, the recovery manifest
      must record why the adapter's negative report was trusted.
   A negative adapter report alone never licenses a fresh draw: the
   adapter is the failed — and possibly compromised — component, and the
   decisive bit must not be adversary-controlled state.
4. The caller must hold the collection policy's frozen
   `incidentDeclarerRole`, resolved through the ADR 0004 registry at call
   time; for collections without a fresh-recovery policy the caller must
   hold `ROLE_ENTROPY_INCIDENT_DECLARER` [EC-INCIDENT-ROLE]. Raw-address
   authority is nonconformant (ADR 0010 decision D7.4).
5. The action must emit a human-readable or content-addressed incident
   reason and the `evidenceHash`.
6. Token status becomes `FAILED`.
7. The active request is closed only as an incident action.
8. A later fresh request, if allowed, must be emitted as recovery and counted
   separately from delivery retries.
9. Fallback providers for high-value collections should be predeclared and
   frozen before mint.
10. Admin-selected fallback after seeing partial outcomes is a manipulation
    risk.
11. Scope entropy incidents follow every rule above through the
    scope-keyed equivalents [EC-SCOPE], with the same coordinator-state,
    probe, and evidence requirements.
12. Artist consent for fresh redraws (ADR 0013 decision U4). A fresh
    recovery request re-randomizes what a sold generative token — or a
    committed scope outcome — renders or resolves to. For an
    artist-bound collection
    ([`docs/stream-artist-authority.md`](stream-artist-authority.md)
    [AA-BINDING]), creating the fresh request, token-keyed or
    scope-keyed, requires — in addition to every rule above and the
    frozen policy's declarer role — a verified artist content consent
    over the redraw through the consent surface owned by [AA-CONTENT],
    or the [AA-RECOVERY] requirement 2 unavailability-finding fallback
    when no artist authority is live. The consent or finding record
    hash must be part of the evidence bundle committed by the
    `EntropyRecoveryRequested` event's `evidenceHash`. The frozen
    fresh-recovery policy and the incident declarer role alone never
    authorize a redraw of an artist-bound work.

`ENTROPY_RESULT_PROBE_GAS_LIMIT` carries the release-manifest
failure-direction class `FORWARDING_CAP` ([LTA-GGP] requirement 10): it
bounds a fail-safe staticcall whose failure reads as "not safe to
recover," and raising it restores recovery capability. Its named health
probe — a Permanent-class probe contract ([LTA-GGP-PROBES]; ADR 0012
decision T1) — executes `providerResultStatus` staticcalls against each
registered production adapter for a pinned fixture corpus of request
IDs under exactly the probed cap, with no caller-supplied gas shaping;
it records each run on itself, treats out-of-gas, revert, or malformed
returndata as failure, and commits the measurement artifact through
`evidenceHash`.

One provider-side condition deserves explicit statement: a frame-level
callback loss after upstream fulfillment — the in-flight repricing mode
pinned in
[`docs/stream-entropy-providers.md`](stream-entropy-providers.md)
[EP-INFLIGHT] — leaves rule 3 permanently unsatisfiable by design. The
adapter truthfully reports no randomness received, but the upstream
output stands publicly revealed, so the rule 3.3 evidence bundle can
never corroborate that no upstream fulfillment occurred. Such a request
stays `REQUESTED` forever unless a separately accepted replay path
re-delivers the identical revealed output; a fresh draw after a public
reveal is a reroll and stays blocked for every collection, with or
without a fresh-recovery policy.

Event:

```solidity
event EntropyRequestFailed(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    uint256 indexed tokenId,
    address indexed provider,
    bytes32 requestKey,
    uint32 providerEpoch,
    uint16 requestAttempt,
    string reasonURI,
    bytes32 evidenceHash
);

event EntropyRecoveryRequested(
    uint16 schemaVersion,
    uint256 indexed collectionId,
    uint256 indexed tokenId,
    address indexed oldProvider,
    address newProvider,
    bytes32 oldRequestKey,
    bytes32 newRequestKey,
    uint32 oldProviderEpoch,
    uint32 newProviderEpoch,
    string reasonURI,
    bytes32 evidenceHash
);
```

Stale fulfillments after incident recovery should not mutate token seed:

```solidity
event StaleEntropyFulfillment(
    uint16 schemaVersion,
    uint256 indexed tokenId,
    address indexed provider,
    bytes32 requestKey,
    uint32 providerEpoch,
    string reason
);
```

A stale fulfillment emits `StaleEntropyFulfillment`, does not finalize, and
the `fulfillEntropy` call returns `REJECTED_STALE_EPOCH` (ADR 0009
decision 25).

For Chainlink-style VRF, the v1 default should be no fresh token-level
request after the VRF request is accepted. Operational protection should come
from funding monitors, provider health checks, callback gas runbooks, and
delivery retry of already received randomness. Fresh recovery should be a rare
public incident process. In-flight callback-gas semantics across raises
and gas-schedule repricings — including the frame-level loss mode that
[EC-INCIDENT] rule 3 blocks from fresh draws — are provider-side and
pinned in
[`docs/stream-entropy-providers.md`](stream-entropy-providers.md)
[EP-INFLIGHT] (ADR 0012 decision T1).

## Instant Providers

Some collections may use an instant deterministic provider. This mode is lower
assurance than external verifiable randomness unless carefully designed.

Instant provider rules [EC-INSTANT]:

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
8. Instant mode is restricted to collections whose frozen config declares
   `EntropySecurityClass.LOW_SECURITY`; the coordinator must reject
   `INSTANT` configuration for `HIGH_ASSURANCE` collections [EC-CONFIG]
   (ADR 0010 decision D8.8).
9. The synchronous view call shape structurally permits request-timing
   grinding for any mode whose output varies across candidate inclusion
   blocks. The normative disclosure and provider-side restrictions live in
   [`docs/stream-entropy-providers.md`](stream-entropy-providers.md)
   [EP-INSTANT-TIMING].

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
4. On VRF callback, compress returned words to `bytes32 rawRandomness` and
   persist the result before delivery.
5. Call `StreamEntropyCoordinator.fulfillEntropy(requestKey, rawRandomness)`
   through try/catch [EP-CALLBACK] (ADR 0010 decision D8.1).
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

### Additional Adapters

Additional providers should be added as new Replaceable-layer adapters
behind the frozen provider interface and activated through provider epochs
and registry approval, each with its own separately accepted spec. The
request lifecycle — the token-keyed and scope-keyed request kinds alike
(ADR 0011 decision R8) — seed derivation, epoch semantics, and stale,
failed, and recovery semantics defined here are final in v1; only the
provider catalog grows, and scope-consuming mechanics such as raffle
adapters grow as Replaceable consumers of the frozen [EC-SCOPE] surface.
Existing Core contracts should not need changes.

## Metadata Integration

Metadata Router should read:

```solidity
(bytes32 seed, bool finalized) = entropyCoordinator.tokenSeed(tokenId);
```

Read-boundary requirements [EC-VIEWREAD]:

1. Router and renderer reads of the pinned `coordinatorAtMint(tokenId)`
   are bounded, fail-safe staticcalls governed by the router-held
   `ENTROPY_VIEW_GAS_LIMIT` Governed Gas Parameter with an EIP-150 63/64
   parent precheck (ADR 0010 decision D1.1). That parameter's normative
   home, floor, and manifest pinning are defined in
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md);
   this document guarantees the coordinator side stated below.
2. Returndata bounds are fixed by the read interface: `tokenSeed` and
   `scopeSeed` return exactly 64 bytes, `tokenEntropyStatus` exactly 32
   bytes, `tokenEntropy` a fixed 256-byte tuple, and `scopeEntropy` a
   fixed 480-byte struct tuple. Consumers must cap the returndata copy at
   the expected size and treat oversized or malformed returndata as a
   failed read.
3. Coordinator view functions must be O(1) storage reads with no external
   calls and no loops over token or request counts, so a manifest-pinned
   read cap stays sufficient across the system's life. They must not
   revert for minted tokens; the documented prepared-incomplete
   disclosure [EC-LIFECYCLE] is the only exception, and consumers treat
   it as pending.
4. A failed, reverting, out-of-gas, or malformed read renders
   pending/unknown metadata and must never revert `tokenURI()` for a
   minted token; the router-side failure semantics are owned by
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md).

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
entropy config admin     configure collection entropy before freeze;
                         retune the Operational reveal fee after freeze
                         [EC-REVEAL] rule 9
provider admin           approve, deprecate, or revoke providers
request operator         request entropy or trigger delivery retry where allowed
metadata refresh admin   coordinate refresh events if required
gas/time parameter admin stage GGP and GTP raises/lowers through ADR 0004
                         action classes [EC-REGGAS] [EC-TIME]
incident declarer        declare entropy incidents through the frozen role
                         reference [EC-INCIDENT-ROLE]
reveal owner             request entropy for reveal-declared collections
                         through the frozen role reference [EC-REVEAL]
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
17. Fresh entropy recovery cannot proceed unless the coordinator's own
    request state shows no finalized result, the bounded adapter probe
    reports no raw randomness received, and the declaration commits to
    independent provider evidence where such evidence exists; adapter
    testimony alone never licenses a fresh draw [EC-INCIDENT] (ADR 0011
    decision R12).
18. Mint registration happens before any `_safeMint` receiver callback can
    observe the token.
19. Every entropy-path gas cap is a Governed Gas Parameter at or above its
    immutable floor; gas retuning never changes entropy identity, policy
    manifests, seeds, or provider epochs (ADR 0010 decisions D1.1, D1.3).
20. `requestEntropy` never retains more than the provider-quoted fee;
    excess is credited to the payer and leaves only by pull [EC-FEEBIND].
21. Instant-mode finalization is reachable only for collections whose
    frozen config declares `LOW_SECURITY` (ADR 0010 decision D8.8).
22. Incident declaration authority resolves through a frozen role
    reference, never through a frozen raw address (ADR 0010 decision
    D7.4).
23. A revoked bound provider's fulfillment attempt cannot finalize, cannot
    revert the callback frame, and cannot erase the adapter's stored
    result (ADR 0010 decision D8.1).
24. A scope subject registers once and can receive at most one finalized
    seed; scope request keys and seeds derive from the scope domains,
    never the token domains [EC-SCOPE] (ADR 0011 decision R8).
25. Recovery re-requests for a scope reuse the stored `scopeInputsHash`;
    no path can bind a different subject set to an already-requested
    scope [EC-SCOPE].
26. Reveal-fee escrow draws never exceed the same-transaction provider
    quote, and forced ETH recovery can reduce neither tracked refund
    credits nor tracked reveal-fee escrows [EC-REVEAL].
27. The permissionless reveal fallback is reachable for a token only
    after that token's effective reveal-SLO window has lapsed
    [EC-REVEAL] (ADR 0011 decision R8).
28. Effective lifecycle windows are never shorter than the collection's
    frozen declarations or the immutable parameter floors, and governed
    time retuning never changes entropy identity, policy manifests,
    seeds, or provider epochs [EC-TIME] (ADR 0012 decision T1).
29. Reveal-fee retuning changes only the Operational funding value:
    frozen reveal promises and accrued escrow are untouched, and a
    fee-drift shortfall is a monitored, permissionlessly fundable
    condition [EC-REVEAL] (ADR 0012 decision T7).
30. For an artist-bound collection, no entropy config change after the
    first minted token and no fresh recovery request executes without
    a verified artist content consent or the recorded
    unavailability-finding fallback [EC-CONFIG] rule 14, [EC-INCIDENT]
    rule 12 (ADR 0013 decision U4).

## Security Considerations

### Mint Reentrancy And Provider Calls

Core should not call external randomness providers directly. If mint calls the
coordinator, the coordinator registers state without provider callbacks.
External provider calls belong in `requestEntropy`, and `requestEntropy` is not
called from `onTokenMinted` in v1. Seed finality before safe receiver
callbacks is excluded from protocol v1; any design that wants it must be
specified in a separately accepted ADR with an exact Core/manager call order,
reentrancy analysis, and metadata-observation model.

### Manipulation Resistance

For collections whose art depends on entropy, provider and salt configuration
should be frozen before public mint starts. Changing provider after partial
minting can create selection or perception risk.

Grinding vectors include input choice and request timing. Request-timing
selection against synchronous instant providers is structural and cannot
be prevented behind the frozen instant interface; it is disclosed and
restricted to `LOW_SECURITY` collections instead of papered over
(ADR 0010 decision D8.8) [EP-INSTANT-TIMING].

Scope entropy adds a subject-set grinding surface: choosing or reordering
the entry set after partial information leaks. The committed
`scopeInputsHash`, its immutability across recovery re-requests, and the
async-only rule close it — a scope request cannot start until the subject
set is fixed, and no instant path can finalize a scope seed [EC-SCOPE].

### Zero Values

`bytes32(0)` is a valid theoretical hash output. It must not be used to infer
pending state.

### Provider Compromise

Provider incident revocation can strand pending tokens. Tooling should require a
documented recovery path before revocation is used. Precommitted fallback
providers are preferred for long-running high-value collections.
If the coordinator or provider quorum needed for safe recovery is lost, behavior
must follow the retained `StreamEntropyLaunchDecision`. In both
`ARRNG_FALLBACK` and `PYTH_FALLBACK` (the only conformant modes, ADR 0009
decision 21), the coordinator may use only the precommitted fallback path
and policy hash recorded in the `StreamEntropyLaunchDecision` manifest. If
both the frozen VRF route and the reviewed fallback are unavailable, new
entropy requests revert or remain unavailable as an accepted terminal
degradation until governance restores a reviewed route or accepts a
separately reviewed recovery, while already registered tokens keep truthful
pending metadata. In every mode, the system should preserve existing
ownership, finalized seeds, pending-state truthfulness, and metadata
fallback behavior rather than inventing an unauthorized randomness source.
Collection `CLOSED` status does not block fulfillment for already-`REQUESTED`
tokens or permissionless `requestEntropy` for already-`REGISTERED` tokens whose
frozen policy allows public requests or whose reveal SLO has lapsed
[EC-REVEAL]. Closing stops new minting, not honest completion of
already-minted entropy lifecycle.

### Event Provenance

Collectors and auditors should be able to reconstruct:

1. collection entropy config at mint time;
2. provider used;
3. request key;
4. provider request ID;
5. raw randomness;
6. final seed;
7. delivery retry and recovery history;
8. final metadata refresh trigger;
9. scope registration, request, inputs commitment, and finalization
   history [EC-SCOPE];
10. reveal policy, escrow funding, escrow draws, fee retuning, and
    fallback engagement [EC-REVEAL];
11. governed gas and time parameter value history [EC-REGGAS]
    [EC-TIME];
12. for artist-bound collections, the artist consent or
    unavailability-finding evidence behind every entropy config change
    and fresh redraw [EC-CONFIG] rule 14, [EC-INCIDENT] rule 12.

## Bytecode Impact

This section is non-normative implementation evidence per
[`docs/spec-policy.md`](spec-policy.md); measurements are point-in-time and
superseded by the release-artifact size proofs.

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
6. Add scope registration and request logic [EC-SCOPE] plus reveal
   policy, reveal-fee escrow, and lapse-fallback logic [EC-REVEAL].

### Phase 2: Provider Adapters

1. Implement a new `StreamEntropyProviderVRF` adapter using the `requestKey`
   pattern.
2. Implement the reviewed fallback adapter using the `requestKey` pattern:
   `StreamEntropyProviderARRNG` as the preferred fallback or
   `StreamEntropyProviderPyth` as the reviewed alternate (ADR 0009
   decision 21).
3. Do not implement an instant provider: no instant provider ships at
   genesis (ADR 0009 decision 24). The `IStreamInstantEntropyProvider`
   interface is Permanent and frozen, so a reviewed instant provider can be
   added later as a Replaceable module if a collection needs one.
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
2. Add dashboards for pending, requested, failed, and finalized tokens and
   scopes, including tokens `REGISTERED` past their reveal SLO.
3. Add keeper or operator scripts for reveal-owned and public-request
   collections [EC-REVEAL], with the rehearsal run retained as release
   evidence.
4. Add runbooks for provider deprecation and incident revocation.

## Required Tests

Core integration tests:

1. Mint registers token entropy.
2. Only Core can call `onTokenMinted`.
3. Core emits `EntropyCoordinatorUpdated`.
4. Updating coordinator requires admin authority.
5. Core no longer stores token hash or randomizer address.
6. Core carries no `ERC721Enumerable` surface:
   `supportsInterface(0x780e9d63)` is false and the index selectors are
   absent (ADR 0012 decision T10; [LTA-ENUMERATION]).
7. If `onTokenMinted` reverts, the whole mint reverts and no token is minted.
8. Emergency switch to a pre-approved safe-mode coordinator preserves
   registration semantics.
9. `ENTROPY_REGISTRATION_GAS_LIMIT` behaves per [EC-REGGAS] and
   [LTA-GGP] requirements 1–2 (ADR 0011 decision R5): staged raises on
   the normal delay class bounded to 2x per action, the raise-only
   probe-gated emergency path, lower only with a recorded passing probe
   run at the proposed value, floor rejection below
   `ENTROPY_REGISTRATION_GAS_FLOOR`, and change events with old and new
   values.
10. The EIP-150 parent precheck is exercised at, below, and above the
    threshold and reads the live parameter value after a raise.
11. Gas parameter values appear in no finality manifest, frozen-route
    identity, entropy policy manifest, or seed derivation input.
12. The registration-gas probe satisfies its golden equivalence test,
    records failing and passing runs on itself, and the parameter's
    `FAIL_CLOSED_PRECHECK` class excludes it from permissionless
    conditional-raise registration (ADR 0012 decision T1).

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
8. Fresh recovery policy steps, incident declarer role, provider epochs, and
   reason schema are included in the policy hash; `stepsHash` binds
   `FRESH_RECOVERY_STEPS_DOMAIN` as the leading field of the steps
   encoding, and an undomained steps encoding fails the golden preimage
   test (ADR 0013 decision U7).
9. `INSTANT` configuration is rejected unless the collection declares
   `EntropySecurityClass.LOW_SECURITY`; the declared class freezes with
   the config and is readable through `collectionEntropyConfig`.
10. Rotating the holder behind a frozen `incidentDeclarerRole` through
    ADR 0004 governance requires no policy or config change, and incident
    declaration honors the post-rotation holder.
11. Governed time parameters [EC-TIME]: values below their immutable
    floors are rejected; raises and lowers respect the per-action bounds
    and the normal delay class; every change emits
    `EntropyTimeParameterUpdated`; no emergency or permissionless
    conditional path exists for a time parameter.
12. Effective windows apply the max() rule: a governed raise lengthens
    the effective timeout, SLO, and recovery-step delay for a frozen
    collection without touching its config, policy hashes, provider
    epoch, or seeds, and no action shortens any window below the frozen
    declaration or the floor.
13. Artist consent boundary: on an artist-bound collection, an entropy
    config change after the first minted token without a verified
    artist content consent reverts; the same change with consent (or a
    recorded unavailability finding) proceeds; Operational retunes —
    GGP/GTP values and the reveal fee — need no consent [EC-CONFIG]
    rule 14 (ADR 0013 decision U4).

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
12. Fee binding [EC-FEEBIND]: `msg.value` below the same-transaction quote
    reverts with the quoted fee; `msg.value` equal to the quote forwards
    exactly; excess is credited to the payer, evented, and claimable only
    by pull; claims zero the credit before transfer and reject reentrancy.
13. A provider fee change between quote observation and execution cannot
    fail a request whose `msg.value` still covers the new fee; forced ETH
    recovery cannot reduce the aggregate of tracked fee credits.

Fulfillment tests:

1. Active provider can fulfill.
2. Wrong provider cannot fulfill.
3. Unknown request key cannot fulfill.
4. Fulfillment finalizes seed exactly once.
5. Fulfillment emits `EntropyFinalized`.
6. Seed derivation is deterministic and domain-separated.
7. Seed zero does not control status.
8. Metadata refresh is triggered through the restricted Core refresh
   emitter (ADR 0009 decision 5).
9. Wrong provider epoch cannot fulfill.
10. Stale fulfillment emits `StaleEntropyFulfillment`, does not mutate seed,
    and returns `REJECTED_STALE_EPOCH`.
11. `fulfillEntropy` rejects inactive requests, non-`REQUESTED` token status,
    and already finalized tokens, returning their `EntropyFulfillmentOutcome`
    codes without reverting; unauthorized providers revert.
12. Synchronous `INSTANT` finality uses `instantEntropy` return data, not a
    callback into `fulfillEntropy`, and is rejected for collections that do
    not declare `LOW_SECURITY`.
13. Fulfillment by the bound provider while `INCIDENT_REVOKED` emits
    `StaleEntropyFulfillment`, returns `REJECTED_PROVIDER_REVOKED`, does
    not finalize, and does not revert.
14. The measured `fulfillEntropy` gas envelope, including the Core refresh
    emitter, is published and matches the provider callback sizing tests
    [EP-CALLBACK].

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
9. Fresh recovery is rejected for high-value v1 configs with
   `maxFreshRecoveryAttempts = 0`.
10. Fresh recovery follows the frozen ordered policy step and cannot choose an
    ad hoc provider after the incident.
11. `markEntropyRequestUnrecoverable` accepts only a caller holding the
    frozen incident declarer role via live ADR 0004 resolution and rejects
    every other caller, including former role holders after rotation.
12. The adapter result probe runs under `ENTROPY_RESULT_PROBE_GAS_LIMIT`
    and treats out-of-gas, revert, and malformed returndata as unsafe to
    recover.
13. Recovery is rejected when the coordinator's own state shows a
    finalized seed or an inactive stored request, even when the adapter
    reports no randomness received [EC-INCIDENT] rule 3 (ADR 0011
    decision R12).
14. Incident declaration with a zero `evidenceHash` reverts, and the
    emitted failure and recovery events carry the evidence hash.
15. With a false-negative adapter — one that reports
    `rawRandomnessReceived = false` after receiving randomness — the late
    original callback remains a stale, audit-visible event that cannot
    finalize, and the declared evidence commitment is retained for
    incident review.
16. Unrecoverable marking honors the effective request-timeout window:
    eligibility opens only after the maximum of the frozen declaration
    and the live governed value [EC-TIME], and a governed raise defers
    an otherwise-eligible declaration.
17. The result-probe parameter's named health probe records runs on
    itself and treats out-of-gas, revert, and malformed returndata as
    failing runs (ADR 0012 decision T1).
18. For an artist-bound collection, a fresh recovery request without a
    verified artist content consent or a recorded unavailability
    finding reverts; with one, the consent or finding record hash is
    part of the bundle committed by the emitted `evidenceHash`
    [EC-INCIDENT] rule 12 (ADR 0013 decision U4).

Scope entropy tests:

1. Scope registration derives `scopeId` with the subject domain, writes
   `REGISTERED`, and rejects duplicate registration.
2. Scope requests require the collection's frozen `ASYNC` config;
   `INSTANT`-mode and `DISABLED` collections cannot request scope
   entropy.
3. Scope request keys and seeds use the scope domains; token and scope
   requests over the same collection can never collide.
4. `scopeInputsHash` is stored on first request, bound into request key
   and seed, and recovery re-requests with a different inputs hash
   revert.
5. Providers fulfill scope requests through the unchanged
   `fulfillEntropy` path; context schema version 2 flows opaquely
   through request, callback, and retry [EP-CONTEXT].
6. A finalized scope cannot be re-registered, re-requested, or
   refinalized; stale and wrong-epoch scope callbacks emit
   `StaleScopeEntropyFulfillment` and return their outcome codes.
7. Scope incident recovery enforces the full [EC-INCIDENT] rule 3
   evidence set through the scope-keyed functions.
8. Scope finalization emits `ScopeEntropyFinalized` and never calls the
   restricted Core refresh emitter.
9. Scope requests are caller-funded under [EC-FEEBIND] and never draw
   from the reveal-fee escrow.
10. Fair-allocation golden vectors: a fixed seed and committed entry
    list reproduce the pinned `STREAM_ENTROPY_SCOPE_RANKING_V1` winner
    order and curated-set assignment [EC-SCOPE-RAFFLE], and the
    derivation consumes only the finalized seed and the committed
    inputs.

Reveal operation tests:

1. `freezeCollectionEntropy` rejects an `ASYNC` collection without a
   declared reveal policy; declared policies freeze with the config.
2. In `AT_MINT` mode, a failed at-mint request attempt does not unwind
   the mint: the token stays `REGISTERED` and enters the SLO window.
3. Before SLO lapse, public callers are rejected unless
   `publicRequestsEnabled`; after lapse, anyone can request and the
   escrow pays the quoted fee.
4. Fee draw order: escrow first, `msg.value` shortfall second; excess
   `msg.value` is credited per [EC-FEEBIND]; every escrow draw is
   evented.
5. Residual escrow withdrawal succeeds only when the collection has no
   non-terminal token entropy records, pays only the protocol treasury,
   and is evented; forced ETH cannot reduce the escrow or credit
   aggregates.
6. The reveal owner role resolves through ADR 0004 at call time, and
   holder rotation requires no policy change.
7. The reveal operations manifest — SLO target, holder-latency check,
   keeper obligation, monitoring thresholds including the
   escrow-versus-quote margin, funded float and top-up obligation,
   rehearsal evidence — is present and checksum-covered in the release
   artifacts.
8. `updateRevealFeePerToken` is admin-only, evented via
   `RevealFeePerTokenUpdated`, applies to future mints only, and leaves
   request mode, reveal owner role, declared SLO, and accrued escrow
   untouched; frozen-policy field changes still revert.
9. With the live provider quote above the accrued per-token fee, the
   lapse fallback draws the escrow first and requires only the
   shortfall from `msg.value`; a permissionless `fundRevealFeeEscrow`
   top-up restores gas-only fallback calls.
10. A declared `requestSLOBlocks` below the reveal owner's recorded
    worst-case holder latency plus margin fails the
    reveal-operations-manifest gate (ADR 0012 decision T5).
11. The measured `requestEntropy` gas envelope — through the configured
    provider's quote and request calls to upstream submission — is
    published per genesis provider in the release manifest, and the
    sale-side `REVEAL_ATTEMPT_GAS_LIMIT` bound sized from it caps the
    at-mint attempt: an attempt under the cap with a pathological
    upstream still fails caught, leaving the token `REGISTERED`
    [EC-REVEAL] rule 2 (ADR 0013 decision U7).

Provider adapter tests:

1. VRF adapter maps provider request ID to request key.
2. VRF callback fulfills through coordinator.
3. ARRNG adapter maps provider request ID to request key.
4. Provider adapters reject unauthorized callers where applicable.
5. Payable providers enforce exact payment at the adapter boundary; caller
   overpayment never reaches the adapter because the coordinator binds
   `msg.value` as `maxFeeWei`, forwards exactly the same-transaction
   quote, and credits excess as a pull refund [EC-FEEBIND] (ADR 0010
   decision D8.7).
6. Provider adapters expose result status for requested, received, delivered,
   stale, and failed cases.
7. Provider callbacks persist results and deliver through try/catch; a
   coordinator revert during callback never reverts the upstream frame and
   never erases the stored result [EP-CALLBACK].

Renderer integration tests:

1. Pending token renders pending metadata.
2. Finalized token renders active metadata.
3. Render context includes canonical seed.
4. Render context includes entropy status and provider.
5. Metadata output does not depend on Core `tokenToHash`.
6. Default token JSON discloses
   `properties.stream.entropy_security_class` for both declared classes,
   in pending-state and finalized JSON alike (ADR 0011 decision R12); the
   field pinning and full conformance test are owned by
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md).

## Resolved Design Decisions

1. Per-collection entropy configuration is required and must be configured
   (and frozen where promised) before sale start; there is no
   coordinator-level global default provider (ADR 0009 decision 23).
2. Public `requestEntropy` is not enabled by default: `requestEntropy` is
   callable by the minter path, entropy admins, and global admins, and
   public requests are opt-in per collection (ADR 0009 decision 22). The
   reveal-lapse fallback [EC-REVEAL] is the single decided exception:
   after a reveal-declared collection's request SLO lapses for a token,
   anyone may request for that token (ADR 0011 decision R8).
3. No instant provider ships at genesis; the `IStreamInstantEntropyProvider`
   interface is Permanent and frozen, so a reviewed instant provider can be
   added later as a Replaceable module if a collection needs one
   (ADR 0009 decision 24), subject to the low-security class restriction
   and timing-grinding disclosure (ADR 0010 decision D8.8).
4. Genesis ships dual providers: Chainlink VRF primary plus one reviewed
   fallback, with ARRNG as the preferred candidate and Pyth as the reviewed
   alternate; a VRF-only deployment is not conformant, and the former
   VRF-only exception path is removed (ADR 0009 decision 21).
5. Metadata refresh events are Core-originated: Core exposes restricted
   ERC-4906 refresh emitters callable by authorized satellites, and the
   coordinator calls the restricted Core method after entropy finalization
   (ADR 0009 decision 5).
6. `fulfillEntropy` returns a pinned `EntropyFulfillmentOutcome` code
   instead of reverting on benign rejection; hard violations still revert
   with typed errors (ADR 0009 decision 25).
7. `ENTROPY_REGISTRATION_GAS_LIMIT` and every coordinator-side external
   call cap are Governed Gas Parameters with immutable floors, staged
   raise/lower, health probes, and exclusion from finality identity; the
   never-brick recovery chain — raisable cap plus replaceable coordinator
   pointer — is explicit (ADR 0010 decisions D1.1 through D1.5).
8. Request payment binds `msg.value` as `maxFeeWei` against a
   same-transaction provider quote with pull-credit refund of excess
   [EC-FEEBIND] (ADR 0010 decision D8.7).
9. Instant mode is restricted to collections declaring
   `EntropySecurityClass.LOW_SECURITY`, and the instant interface's
   structural request-timing exposure is disclosed rather than papered
   over; the genesis exclusion stands (ADR 0010 decision D8.8).
10. Incident declaration authority is a role reference resolved through
    the ADR 0004 registry, never a frozen raw address (ADR 0010 decision
    D7.4).
11. A revoked bound provider's fulfillment is a non-reverting benign
    rejection with the pinned `REJECTED_PROVIDER_REVOKED` outcome, and
    provider callbacks persist randomness and deliver through try/catch
    so a coordinator revert can never lose provider randomness (ADR 0010
    decision D8.1).
12. The coordinator carries a sale/collection-scoped request kind with
    its own request-key and seed domains, reusing the token lifecycle —
    epochs, timeout, delivery retry, stale handling, incident recovery,
    and commitment finality — so raffles, random assignment, and reveal
    offsets consume this surface instead of integrating providers
    directly [EC-SCOPE] (ADR 0011 decision R8).
13. Reveal operations are owned: `ASYNC` collections declare a reveal
    owner role and request SLO before public mint, sales escrow a
    per-mint reveal fee into the coordinator's per-collection escrow, and
    a permissionless, escrow-funded request fallback engages after the
    SLO lapses [EC-REVEAL] (ADR 0011 decision R8).
14. Fresh-recovery no-reroll proof is coordinator-state evidence first:
    the coordinator's own no-result state, the bounded adapter probe, and
    a nonzero independent-evidence commitment are all required, and
    adapter testimony alone never licenses a fresh draw [EC-INCIDENT]
    (ADR 0011 decision R12).
15. The declared entropy security class is disclosed machine-readably in
    default token JSON as `properties.stream.entropy_security_class`,
    pending and finalized alike, with the field pinning and renderer
    conformance test owned by
    [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
    (ADR 0011 decision R12).
16. `EntropyFulfillmentOutcome` numeric values 0–5 are pinned in this
    home, including `REJECTED_PROVIDER_REVOKED = 5` (ADR 0010 decision
    D8.1); decision-record text restating the five-member pre-extension
    enum is corrected to cite this home (ADR 0011 decision R12).
17. Entropy lifecycle block-count windows are Governed Time Parameters:
    coordinator-hosted values with immutable floors, applied through
    the effective-window max() rule over frozen per-collection
    declarations, retunable on the normal delay class, members of the
    cadence review, and excluded from entropy identity [EC-TIME]
    (ADR 0012 decision T1).
18. `revealFeePerTokenWei` is Operational funding, updatable after
    policy freeze with evented, future-mints-only effect and a
    monitored escrow-margin top-up obligation; the frozen reveal
    promises never move with it [EC-REVEAL] (ADR 0012 decision T7).
19. Oversubscribed-drop fair allocation is a frozen recipe over the
    scope surface — pre-entry scope registration, post-closure
    committed entry roots, and the canonical domain-separated ranking
    derivation [EC-SCOPE-RAFFLE] — with the sale-side profile home in
    [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
    (ADR 0012 decision T6).
20. Event schemas in this home are production-exact with a leading
    `uint16 schemaVersion` on every non-standard event [EC-EVENTS];
    `stepsHash` carries its own interior-composite domain
    `FRESH_RECOVERY_STEPS_DOMAIN`; per-collection frozen lifecycle
    declarations are collection timing policies outside the GTP closed
    world; and the at-mint reveal attempt is bounded by the sale-side
    `REVEAL_ATTEMPT_GAS_LIMIT` Governed Gas Parameter with the
    coordinator's measured `requestEntropy` envelope published for its
    sizing [EC-REVEAL] rule 2 (ADR 0013 decisions U7 and U9).
21. Entropy configuration and fresh redraws for artist-bound
    collections join the artist consent/veto surface: config changes
    after first mint and fresh recovery requests require verified
    artist content consent or the recorded unavailability-finding
    fallback, and the reveal-fee line item binds buyer-side as
    maxFee/pull-credit in the sales home [EC-CONFIG] rule 14,
    [EC-INCIDENT] rule 12, [EC-REVEAL] rules 5 and 9 (ADR 0013
    decisions U4 and U6).

These resolutions are normative; the requirements in the body of this
document already state each decided behavior.
