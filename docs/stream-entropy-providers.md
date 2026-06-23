# Stream Entropy Provider Adapters

This document specifies the Stream-native entropy provider adapter contracts
that feed raw randomness into `StreamEntropyCoordinator`.

The coordinator spec is `docs/stream-entropy-coordinator.md`. That document
defines token registration, request lifecycle, seed finalization, delivery
retry, provider registry state, recovery policy, and metadata integration. This
document defines the provider contracts that connect external or deterministic
randomness sources to that coordinator.
The cross-cutting 50+ year architecture principles live in
`docs/stream-long-term-architecture.md`.

## Launch Scope

Launch adapter scope is intentionally small:

1. `StreamEntropyProviderVRF` as the default high-assurance production adapter.
2. `StreamEntropyProviderMock` for local development, tests, and deterministic
   simulations.
3. A v1 fallback decision: either ship one reviewed
   `StreamEntropyProviderARRNG` or `StreamEntropyProviderPyth` fallback, with
   ARRNG as the lower-complexity initial fallback candidate, or record an
   explicit reviewed VRF-only launch exception. The choice must be retained in a
   checksum-covered `StreamEntropyLaunchDecision` manifest, either as
   `release-artifacts/latest/entropy-launch-decision.json` or as an equivalent
   release-manifest record, that records the mode, selected provider code hashes,
   policy hashes, review evidence, and coordinator failure behavior.

All other provider families in this document are future research or future
adapter candidates. They should not be treated as launch implementation scope
unless a later ADR explicitly promotes one of them.

## Design Position

Provider adapters are entropy sources, not token-hash authorities.

```text
provider adapter
  - requests randomness from one source
  - maps provider request IDs to coordinator request keys
  - stores callback results safely
  - reports raw randomness to StreamEntropyCoordinator
  - emits source-specific provenance events

StreamEntropyCoordinator
  - verifies the active request
  - verifies provider authorization
  - finalizes the canonical seed exactly once
  - owns delivery retry, stale fulfillment, and recovery policy
```

Provider adapters must not write to `StreamCore`, must not expose
`setTokenHash`-style callbacks, and must not define the final artist-facing
token hash.

The current `NextGenRandomizerNXT`, `NextGenRandomizerRNG`, and
`NextGenRandomizerVRF` contracts are reference material only. The production
launch target is a new set of Stream-native adapters.

## NextGen Lifecycle Lessons For Adapters

NextGen's adapter split is still the right instinct: provider-specific code
belongs outside Core. The part Stream should not carry forward is direct
adapter authority over the final token hash.

Production adapters must preserve these lessons from the lifecycle hardening
work:

1. The coordinator is the canonical lifecycle authority. Adapter mappings are
   provider-specific lookup tables, not protocol truth.
2. Every accepted provider request maps to one coordinator `requestKey`, one
   provider request ID, one token, one collection, and one provider epoch.
3. Provider callbacks validate the provider request ID before doing anything
   else, then store the raw output or compressed raw output before coordinator
   delivery.
4. Adapter storage should mark results delivered or terminal, but should not
   delete request bindings in a way that makes the same token/request look
   requestable again.
5. Unknown, duplicate, wrong-epoch, or stale callbacks must fail closed or emit
   explicit stale/audit events. They must not silently disappear.
6. Deterministic post-processing retry is allowed only with the same stored raw
   randomness. Adapters must never ask the upstream provider for fresh
   randomness for an old `requestKey`.
7. Provider config changes affect future requests only. Request-time config
   must be visible in events.
8. If the upstream API returns a request ID only after an external call, the
   adapter needs a reentrancy guard or pre-reserved local request record so a
   malicious or unusual provider cannot fulfill before the request is bound.
9. Weak native/block-derived adapters can exist only as explicit low-assurance
   modes. They must not advertise themselves as production VRF equivalents.

## Research Findings

The provider landscape breaks into five useful categories:

1. Verifiable oracle VRF: Chainlink VRF, Supra dVRF, and similar networks.
2. Two-party commit-reveal oracle entropy: Pyth Entropy.
3. Public threshold beacons: drand, Gelato VRF over drand, DIA xRandom, and
   ARPA Randcast-style threshold BLS networks.
4. Physical or QRNG-backed oracle feeds: API3 QRNG and similar services.
5. Native or local schemes: PREVRANDAO, delayed blockhash, VDF/SNARK beacon
   research, and app-level commit-reveal.

Launch recommendation remains simple: use Chainlink VRF v2.5 as the first
default high-assurance adapter because it is production-proven, verifies proofs
onchain before consumer use, has clear security guidance, and supports modern
subscription/native-token funding paths.

The frontier opportunity is not to replace VRF immediately. It is to make the
Stream adapter boundary strong enough that better randomness systems can be
added over a 50-year contract life without touching `StreamCore`.

Provider research takeaways:

1. Do not expose normal token-level re-request or cancel semantics after a
   randomness request is accepted.
2. Store raw randomness before calling the coordinator.
3. Keep provider adapters narrow and replaceable.
4. Treat fallback providers as predeclared collection policy, not ad hoc admin
   decisions after outcomes are partially visible.
5. Treat PREVRANDAO, blockhash, and timestamp as low-assurance sources unless
   they are used only as supplemental salt beside a stronger source.
6. Watch BLS12-381 onchain verification after EIP-2537, because it makes
   drand-style and threshold-BLS beacons much more realistic on Ethereum.
7. Separate entropy generation from reveal secrecy. Timelock encryption can
   make metadata reveal ceremonies stronger, but it is not itself a replacement
   for token entropy.

## Common Provider Interface

All production provider adapters should implement:

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

enum ProviderResultStatus {
    UNKNOWN,
    REQUESTED,
    RAW_RANDOMNESS_RECEIVED,
    DELIVERED,
    TERMINAL_STALE,
    TERMINAL_FAILED
}
```

Only `StreamEntropyCoordinator` may call `requestEntropy`.

`context` is coordinator-defined and versioned. Recommended v1 encoding:

```solidity
abi.encode(
    uint16(1),          // context schema version
    address(streamCore),
    uint256(collectionId),
    uint256(tokenId),
    uint32(providerEpoch),
    providerConfigHash,
    uint16(requestAttempt)
)
```

Adapters may decode the context for events, request metadata, or source-specific
payloads. They must not use decoded context as authority in place of the
coordinator request key.

`providerResultStatus` is the shared audit and recovery probe. It must remain
queryable after delivery, stale marking, failed delivery, or incident handling.
Fresh entropy recovery for a token is forbidden when the old adapter reports
`rawRandomnessReceived = true`, even if coordinator delivery failed.

## Common Adapter Requirements

1. Bind to exactly one coordinator at construction.
2. `requestEntropy` must revert unless called by that coordinator.
3. Each accepted request must map a provider request ID to exactly one
   coordinator `requestKey`.
4. Each provider callback must store raw randomness or enough source data to
   reconstruct it before attempting coordinator fulfillment.
5. If coordinator fulfillment fails during a provider callback, the adapter must
   retain the raw randomness and expose a retry path for coordinator
   fulfillment.
6. Provider callbacks must not write to Core.
7. Provider callbacks must not derive the final Stream seed.
8. Provider callbacks must not silently discard unknown provider request IDs.
9. Admin configuration changes must emit events.
10. Withdrawals, refunds, or native-token recovery must be explicit and evented.
11. Adapter contracts should disclose a stable provider type and version.
12. Adapters should reject duplicate live `requestKey` submissions.
13. Adapters should never create fresh randomness for an old `requestKey`.
14. Adapters should retain request/result bindings after fulfillment, stale
    marking, or failed delivery so historical callbacks remain auditable and
    cannot reopen a token.
15. Adapters with external payable request calls that return the upstream
    request ID after the call must use a reentrancy guard or equivalent
    in-flight request reservation.
16. Adapters should include request-time provider configuration in request
    events, even if later config updates change adapter defaults.
17. Adapters should expose enough read methods for monitoring pending,
    received-not-delivered, delivered, and terminal stale results.
18. Adapters must expose `providerResultStatus` for every accepted provider
    request ID.
19. Adapters must never report `UNKNOWN` for a request ID they accepted, even
    after fulfillment, failure, stale marking, or config migration.
20. Adapters must set `rawRandomnessReceived = true` before attempting
    coordinator fulfillment.
21. Adapters must document operational key custody for provider subscriptions,
    payment wallets, callback authorities, and adapter admins.
22. Adapters must support a rotation plan for compromised or lost provider
    operational keys without changing already-recorded request commitments.

Provider key runbooks should name the responsible governance role, rotation
cadence or review cadence, loss procedure, compromise procedure, and expected
collection impact. For VRF, this includes subscription ownership, consumer
registration authority, LINK/native funding account, callback gas settings, and
the process for moving future requests to a new subscription without altering
old request provenance.

Recommended version interface:

```solidity
function providerType() external pure returns (bytes32);
function providerVersion() external pure returns (bytes32);
```

Example values:

```text
STREAM_ENTROPY_PROVIDER_VRF
STREAM_ENTROPY_PROVIDER_ARRNG
STREAM_ENTROPY_PROVIDER_INSTANT
STREAM_ENTROPY_PROVIDER_MOCK
```

## Common Events

Every provider should emit source-specific request and callback events. The
minimum shared shape is:

```solidity
event ProviderEntropyRequested(
    bytes32 indexed requestKey,
    uint256 indexed providerRequestId,
    address indexed coordinator,
    uint32 providerEpoch
);

event ProviderEntropyReceived(
    bytes32 indexed requestKey,
    uint256 indexed providerRequestId,
    bytes32 rawRandomness
);

event ProviderCoordinatorFulfillmentAttempted(
    bytes32 indexed requestKey,
    uint256 indexed providerRequestId,
    bool success,
    bytes returnData
);
```

Provider-specific events should include source configuration such as VRF key
hash, subscription ID, request confirmations, or ARRNG payment amount when
useful.

## Raw Randomness Compression

Adapters should report one `bytes32 rawRandomness` value to the coordinator.
When the upstream source returns multiple words or a complex payload, compress
it with a provider-specific domain:

```solidity
bytes32 rawRandomness = keccak256(abi.encode(
    STREAM_PROVIDER_RAW_V1,
    providerType,
    requestKey,
    providerRequestId,
    upstreamRandomWordsOrPayload
));
```

Do not use packed encoding for raw randomness compression.

The coordinator will include `rawRandomness`, `requestKey`,
`providerRequestId`, provider address, provider epoch, provider config hash,
collection ID, token ID, collection salt, and mint commitment in the final seed
derivation.

## Coordinator Fulfillment Retry

External randomness callbacks are valuable. If a callback receives valid
randomness but the coordinator call fails, the adapter should not lose it.

Recommended storage:

```solidity
struct ProviderResult {
    bytes32 requestKey;
    bytes32 rawRandomness;
    uint32 providerEpoch;
    bytes32 providerConfigHash;
    bool received;
    bool delivered;
}

mapping(uint256 providerRequestId => ProviderResult) results;
```

Recommended retry function:

```solidity
function retryCoordinatorFulfillment(uint256 providerRequestId) external;
```

Rules:

1. Provider result must exist and be received.
2. Result must not already be delivered.
3. Function may be called by anyone, unless the provider source requires a more
   constrained policy.
4. Adapter calls `coordinator.fulfillEntropy(requestKey, rawRandomness)`.
5. On success, marks result delivered.
6. On failure, emits failure and keeps result available for later retry.

If the coordinator rejects because the request is stale, already finalized, or
failed, the adapter may mark the result terminal after a successful explicit
coordinator stale-response path exists. Until then, retaining the result is
safer.

## StreamEntropyProviderVRF

`StreamEntropyProviderVRF` is the default high-assurance launch provider family.
It should be a new Stream-native adapter, not the current
`NextGenRandomizerVRF` wired into the new system.

### Responsibilities

1. Accept request keys only from `StreamEntropyCoordinator`.
2. Request randomness from the configured VRF coordinator.
3. Map VRF request ID to Stream request key.
4. Store callback raw randomness before coordinator fulfillment.
5. Report raw randomness to the coordinator.
6. Provide retry for coordinator fulfillment.
7. Emit complete request and callback provenance.

### Constructor

The exact VRF interface can be version-specific, but the adapter should bind:

```solidity
constructor(
    address streamEntropyCoordinator,
    address streamAdmins,
    address vrfCoordinator,
    uint64 subscriptionId,
    bytes32 keyHash,
    uint16 requestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
)
```

If the deployment uses a newer VRF coordinator interface, use a versioned
adapter name such as `StreamEntropyProviderVRFV2` or
`StreamEntropyProviderVRFv25`. The Stream adapter boundary should stay the
same.

### State

Recommended state:

```solidity
address public immutable coordinator;
address public vrfCoordinator;
uint64 public subscriptionId;
bytes32 public keyHash;
uint16 public requestConfirmations;
uint32 public callbackGasLimit;
uint32 public numWords;

mapping(uint256 vrfRequestId => bytes32 requestKey) vrfRequestToKey;
mapping(bytes32 requestKey => uint256 vrfRequestId) keyToVrfRequest;
mapping(uint256 vrfRequestId => ProviderResult) results;
```

Recommended result struct:

```solidity
struct ProviderResult {
    ProviderResultStatus status;
    bytes32 requestKey;
    bytes32 rawRandomness;
    bytes32 rawRandomnessHash;
    uint64 receivedAtBlock;
    uint64 deliveredAtBlock;
}
```

The adapter may store only the compressed `rawRandomness` plus
`rawRandomnessHash` if upstream words are large, but the status probe must make
the received-versus-delivered distinction unambiguous.

### Request Flow

```text
StreamEntropyCoordinator.requestEntropy(tokenId)
  -> StreamEntropyProviderVRF.requestEntropy(requestKey, context)
       require msg.sender == coordinator
       call VRF coordinator
       store vrfRequestId -> requestKey
       emit VRFEntropyRequested
       return vrfRequestId
```

Recommended event:

```solidity
event VRFEntropyRequested(
    bytes32 indexed requestKey,
    uint256 indexed vrfRequestId,
    uint64 indexed subscriptionId,
    uint32 providerEpoch,
    bytes32 keyHash,
    uint16 requestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
);
```

### Callback Flow

```text
VRF coordinator callback
  -> adapter verifies known vrfRequestId
  -> adapter compresses random words to rawRandomness
  -> adapter stores result and marks RAW_RANDOMNESS_RECEIVED
  -> adapter attempts coordinator.fulfillEntropy(requestKey, rawRandomness)
  -> adapter marks delivered only after success
```

Recommended raw compression:

```solidity
bytes32 rawRandomness = keccak256(abi.encode(
    STREAM_VRF_RAW_V1,
    requestKey,
    vrfRequestId,
    randomWords
));
```

Recommended event:

```solidity
event VRFEntropyReceived(
    bytes32 indexed requestKey,
    uint256 indexed vrfRequestId,
    bytes32 rawRandomness
);
```

### Admin Configuration

Admins may need to update VRF operational settings:

```solidity
function updateVRFConfig(
    uint64 subscriptionId,
    bytes32 keyHash,
    uint16 requestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
) external;
```

Rules:

1. Admin-only through ADR 0004 governance/action roles. Legacy selector-map
   `StreamAdmins` authorization is nonconformant for launch.
2. Emit `VRFConfigUpdated`.
3. Existing requests retain the provenance values emitted at request time.
4. Updates affect only future requests.

Recommended event:

```solidity
event VRFConfigUpdated(
    uint64 subscriptionId,
    bytes32 keyHash,
    uint16 requestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
);
```

### VRF Security Requirements

1. Callback must reject unknown VRF request IDs.
2. Callback must not trust token ID from external calldata.
3. Callback must not call Core.
4. Callback must not derive the final seed.
5. Callback should not permanently lose randomness if coordinator fulfillment
   fails.
6. Admin config updates must be visible in events.
7. Subscription and funding operations should be covered by deployment runbooks.

## StreamEntropyProviderARRNG

`StreamEntropyProviderARRNG` is the lower-complexity initial v1 fallback
candidate if launch chooses to ship a fallback provider instead of a reviewed
VRF-only exception. It should be a new Stream-native adapter if retained. The
current `NextGenRandomizerRNG` can inform the integration, but should not be
reused as-is.

### Responsibilities

1. Accept request keys only from `StreamEntropyCoordinator`.
2. Request randomness from the configured ARRNG controller.
3. Map ARRNG request ID to Stream request key.
4. Store callback raw randomness before coordinator fulfillment.
5. Report raw randomness to the coordinator.
6. Provide retry for coordinator fulfillment.
7. Make payment, refund, and withdrawal behavior explicit.

### Constructor

```solidity
constructor(
    address streamEntropyCoordinator,
    address streamAdmins,
    address arrngController
)
```

### State

Recommended state:

```solidity
address public immutable coordinator;
address public arrngController;
uint256 public requestPaymentWei;

mapping(uint256 arrngRequestId => bytes32 requestKey) arrngRequestToKey;
mapping(bytes32 requestKey => uint256 arrngRequestId) keyToArrngRequest;
mapping(uint256 arrngRequestId => ProviderResult) results;
```

### Request Flow

```text
StreamEntropyCoordinator.requestEntropy(tokenId)
  -> StreamEntropyProviderARRNG.requestEntropy(requestKey, context)
       require msg.sender == coordinator
       require msg.value >= requestPaymentWei, if payment is required
       request external randomness
       store arrngRequestId -> requestKey
       emit ARRNGEntropyRequested
       return arrngRequestId
```

Recommended event:

```solidity
event ARRNGEntropyRequested(
    bytes32 indexed requestKey,
    uint256 indexed arrngRequestId,
    uint32 providerEpoch,
    uint256 paymentWei
);
```

### Callback Flow

The adapter should compress ARRNG random numbers or payloads:

```solidity
bytes32 rawRandomness = keccak256(abi.encode(
    STREAM_ARRNG_RAW_V1,
    requestKey,
    arrngRequestId,
    numbers
));
```

Then it follows the same store-first, fulfill-second pattern as VRF.

Recommended event:

```solidity
event ARRNGEntropyReceived(
    bytes32 indexed requestKey,
    uint256 indexed arrngRequestId,
    bytes32 rawRandomness
);
```

### Payment And Recovery

ARRNG payment behavior must be explicit:

1. `requestPaymentWei` updates are admin-only and evented.
2. V1 should require exact native ETH payment and reject excess payment rather
   than refunding from the request path.
3. Adapter balances should not silently accumulate.
4. Withdrawals should send only to a configured protocol treasury or admin
   owner and emit an event.
5. Forced ETH should be recoverable through an explicit admin path.

Recommended events:

```solidity
event ARRNGPaymentUpdated(uint256 oldPaymentWei, uint256 newPaymentWei);
event ProviderFundsWithdrawn(address indexed to, uint256 amountWei);
```

### ARRNG Security Requirements

1. Callback must reject unknown ARRNG request IDs.
2. Callback must not trust token ID from external calldata.
3. Callback must not call Core.
4. Callback must not derive the final seed.
5. Callback should not permanently lose randomness if coordinator fulfillment
   fails.
6. Payment handling must be tested for exact payment, excess-payment rejection,
   failed external request, and withdrawal.
7. If the ARRNG controller returns the request ID only after an external
   payable call, the adapter must guard the submission window against
   reentrant callback attempts.
8. The adapter must record the ARRNG request ID to `requestKey` binding before
   any valid callback can be accepted.

## StreamEntropyProviderPyth

`StreamEntropyProviderPyth` is an accepted v1 fallback candidate if launch
chooses a Pyth fallback instead of ARRNG or a reviewed VRF-only exception. It is
more integration-complex than ARRNG and needs explicit fee, callback, liveness,
and audit coverage before activation.

Pyth Entropy uses a two-party commit-reveal construction. The provider commits
to values through a hash chain, the user contract supplies its own contribution,
and the final random number is derived from both contributions. The useful
security property is that the output remains secure if either party is honest
and the request flow prevents either side from adapting after seeing the other
side's reveal.

### Responsibilities

1. Accept request keys only from `StreamEntropyCoordinator`.
2. Generate or receive the user contribution before the provider reveal.
3. Request entropy from the configured Pyth Entropy contract.
4. Map Pyth sequence/request ID to Stream request key.
5. Store provider reveal, user contribution, and raw randomness before
   coordinator fulfillment.
6. Report raw randomness to the coordinator.
7. Provide retry for coordinator fulfillment.
8. Make native fee estimation, excess-payment rejection, and failures explicit.

### Security Requirements

1. User contribution must be bound to `requestKey`, collection ID, token ID,
   chain ID, coordinator address, and adapter address.
2. User contribution must be committed before provider reveal.
3. Callback must reject unknown Pyth request IDs.
4. Callback must not trust token ID from external calldata.
5. Callback must not call Core.
6. Callback must not derive final Stream seed.
7. The adapter must document whether Pyth callbacks can be delivered by
   anyone, by Pyth contracts, or by a provider-specific relayer.
8. Payment handling must be tested for exact fee, excess-fee rejection, stale
   fee quote, failed request, and withdrawal.

Recommended raw compression:

```solidity
bytes32 rawRandomness = keccak256(abi.encode(
    STREAM_PYTH_RAW_V1,
    requestKey,
    providerRequestId,
    userContribution,
    providerContribution,
    pythRandomness
));
```

## StreamEntropyProviderDrand

`StreamEntropyProviderDrand` is a future public-beacon adapter family.

drand is a distributed public randomness beacon backed by threshold BLS
signatures. It is especially interesting after EIP-2537 because Ethereum now
has native BLS12-381 precompiles, making onchain verification of drand
`quicknet` beacons more feasible than it was before Pectra.

This provider family has two possible designs:

1. Delivery-backed adapter: Gelato, DIA, or another network fetches a target
   drand round and calls the adapter.
2. Verification-backed adapter: the adapter verifies the drand BLS signature
   onchain using BLS12-381 precompiles.

The delivery-backed design is simpler. The verification-backed design is more
trust-minimized but needs careful gas, library, and chain-support review.

### Responsibilities

1. Accept request keys only from `StreamEntropyCoordinator`.
2. Bind each request to a future drand round.
3. Store target round and chain hash in request provenance.
4. Verify delivery authority or verify the drand signature onchain.
5. Store the beacon output before coordinator fulfillment.
6. Report raw randomness to the coordinator.
7. Provide retry for coordinator fulfillment.

### Security Requirements

1. Target round must be in the future at request time.
2. The adapter must not let callers choose a past or already-known round.
3. The selected drand network, chain hash, period, and genesis time must be
   evented.
4. If using third-party delivery, the trust and liveness assumptions must be
   disclosed in provider metadata.
5. If using onchain verification, gas limits and BLS library behavior must be
   audited on every supported chain.
6. Missing round delivery must not automatically fall back to a fresh random
   source unless that fallback was predeclared before mint.

Recommended raw compression:

```solidity
bytes32 rawRandomness = keccak256(abi.encode(
    STREAM_DRAND_RAW_V1,
    requestKey,
    providerRequestId,
    drandChainHash,
    drandRound,
    drandRandomness,
    drandSignature
));
```

## StreamEntropyProviderRandcast

`StreamEntropyProviderRandcast` is a future threshold-BLS oracle adapter
candidate.

ARPA Randcast uses a network of nodes performing BLS threshold signature tasks.
The adapter model looks similar to a VRF callback: request randomness, map the
provider request ID to the Stream request key, receive a verifiable random seed,
store first, and fulfill the coordinator.

This is not a launch-default recommendation. It is a good candidate to keep on
the provider roadmap because it gives Stream another independent randomness
network family.

Required review before implementation:

1. supported Ethereum mainnet contracts and request API;
2. onchain verification path and who performs it;
3. billing and failure behavior;
4. callback identity and replay protection;
5. operational maturity and audit history.

## StreamEntropyProviderSupra

`StreamEntropyProviderSupra` is a future dVRF adapter candidate.

Supra dVRF exposes randomness through router/deposit-style contracts and
supports callback-based request flows with configurable confirmations and
optional client seeds. It is worth tracking as a provider-diversification option
if its Ethereum mainnet availability, billing, whitelisting, and callback
security model fit Stream's operational requirements.

The adapter should follow the same store-first pattern as VRF:

1. request through the configured Supra router;
2. map Supra nonce/request ID to Stream request key;
3. validate callback sender as the Supra router;
4. compress returned random words and request metadata;
5. call the coordinator with retryable stored raw randomness.

## StreamEntropyProviderWitnet

`StreamEntropyProviderWitnet` is a future crowd-witnessing randomness candidate.

Witnet's model uses randomly selected witnesses with commit-reveal and
aggregation. It is conceptually attractive because it is not a single oracle
operator, but it should be reviewed for Ethereum mainnet integration quality,
latency, costs, callback semantics, and audit maturity before being considered
for production collections.

## StreamEntropyProviderAPI3QRNG

`StreamEntropyProviderAPI3QRNG` is a future physical-entropy candidate.

Quantum randomness can be excellent as entropy, but for Stream the key question
is not just the entropy source. It is whether the whole delivery path is
verifiable, live, and hard to bias. Treat QRNG as a possible supplemental or
special-purpose provider, not as a replacement for verifiable oracle randomness
without a full trust and liveness review.

## Multi-Source Mixer

A multi-source provider can combine several independent provider results:

```solidity
bytes32 mixedRawRandomness = keccak256(abi.encode(
    STREAM_MULTI_SOURCE_RAW_V1,
    requestKey,
    providerRequestId,
    sourceIds,
    sourceRequestIds,
    sourceRawRandomnessValues
));
```

The benefit is defense in depth: if at least one included source is honest,
unpredictable, and not revealed before the commitment point, the mixed value can
retain unpredictability.

The risk is liveness and selective-abort bias. If a source can see partial
results and then withhold its contribution, the mixer can become weaker than a
single strong source unless deadlines, required sources, and fallback rules are
precommitted.

Rules:

1. Source set must be frozen before mint.
2. Required source count and fallback policy must be frozen before mint.
3. Missing sources must not be dropped ad hoc after partial outcomes are known.
4. All source request IDs and raw values must be evented.
5. The final mixer result must still go through the coordinator as one
   `rawRandomness` value.

Launch posture: do not make this the default. Consider it for exceptional
high-value collections after the single-provider flow is audited and deployed.

## Timelock Reveal Layer

Timelock encryption is not an entropy provider. It is a reveal-secrecy tool.

For some collections, Stream may want the artist's metadata payload or render
script parameters to remain hidden until a future time or beacon round. A
drand/tlock-style layer can encrypt reveal material so it cannot be decrypted
until the target round is published.

Potential uses:

1. hide final metadata until all mints are committed;
2. publish encrypted provenance before reveal;
3. reduce trust in a centralized reveal server;
4. coordinate reveals around public randomness rounds.

This should live in metadata/reveal specs, not in the entropy coordinator. The
coordinator should still get its token entropy from provider adapters.

## VDF And SNARK Beacon Research

VDF and SNARK blockhash-oracle designs are frontier research for Ethereum
randomness. They aim to improve liveness, reduce lookback limitations, or make
beacon manipulation economically unattractive.

Stream should not build a custom VDF beacon for launch. The better 50-year
architecture is:

1. keep `StreamCore` independent of any provider;
2. keep provider adapters narrow;
3. track production-grade VDF/SNARK beacon systems;
4. add a new adapter only after public audits, gas analysis, and mainnet
   operational maturity.

## Native Block Sources

`block.timestamp`, `blockhash`, same-block `PREVRANDAO`, caller data, and admin
salts are not high-assurance randomness sources.

`PREVRANDAO` can be useful only with a future lookahead and clear low-assurance
disclosure. Even then, it should be treated as supplemental salt or an explicit
low-stakes collection mode, not as the default provider for high-value
generative art.

If native block sources are supported at all, they should live under
`StreamEntropyProviderInstant` with explicit mode flags and provenance warnings.

## StreamEntropyProviderInstant

`StreamEntropyProviderInstant` is not a default production provider. It exists
only for explicit low-assurance collections, internal testing, or deliberately
deterministic mechanics that have been reviewed.

For high-value generative art, use VRF by default.

### Responsibilities

1. Accept request keys only from `StreamEntropyCoordinator`.
2. Derive raw randomness from predeclared inputs.
3. Report raw randomness to the coordinator.
4. Disclose security assumptions through events and metadata/provenance notes.

### Production Warning

Instant randomness can be manipulable if it relies on block data, caller data,
admin-selected salts, or minter-selected inputs. It should not be marketed as
equivalent to VRF.

### Possible Modes

If implemented, use explicit modes:

```solidity
enum InstantMode {
    COMMIT_REVEAL,
    DELAYED_BLOCKHASH,
    DETERMINISTIC_TEST_ONLY
}
```

Recommended launch posture:

```text
COMMIT_REVEAL             defer unless fully specified
DELAYED_BLOCKHASH         explicit low-assurance only
DETERMINISTIC_TEST_ONLY   tests and local development only
```

### Request Flow

V1 instant providers should use a no-callback read/return interface:

```solidity
interface IStreamInstantEntropyProvider {
    function instantEntropy(bytes32 requestKey, bytes calldata context)
        external
        view
        returns (bytes32 rawRandomness, bytes32 provenanceHash);
}
```

If the instant provider fulfills in the same transaction as `requestEntropy`,
the coordinator must store active request state before calling the provider.
This request-time synchronous finality is allowed only after Core mint
registration has completed. Instant providers must not be called from
`onTokenMinted` or any Core mint path in v1. `instantEntropy` must be a
`view` read path. CI must fail if any production instant provider reachable
from `requestEntropy` contains `CALL`, `DELEGATECALL`, `STATICCALL`, `CREATE`,
or `CREATE2` opcodes, performs state writes, or depends on receiver behavior.
If request-time synchronous fulfillment cannot satisfy this no-external-call
posture, production instant fulfillment must be split into a second transaction
or deferred to a non-instant provider mode.
For synchronous instant fulfillment, `providerRequestId` is the
coordinator-allocated request identifier stored before the provider `view` call.
The provider does not choose it. It must be deterministic for
`(requestKey, requestAttempt, provider, providerEpoch, providerConfigHash)` and
must match the active request record used by the coordinator to finalize the
seed.

Recommended event:

```solidity
event InstantEntropyProduced(
    bytes32 indexed requestKey,
    uint256 indexed providerRequestId,
    bytes32 rawRandomness,
    bytes32 provenanceHash,
    InstantMode mode
);
```

### Security Requirements

1. Disabled by default in launch config.
2. Must be explicitly configured per collection.
3. Must emit mode and assumptions.
4. Must not call Core.
5. Must not derive final seed.
6. Must not allow buyer, minter, artist, or admin grinding after seeing partial
   outcomes.

## StreamEntropyProviderMock

Tests should use a dedicated mock provider rather than bending production
providers into test mode.

Responsibilities:

1. Implement `IStreamEntropyProvider`.
2. Accept request keys only from coordinator.
3. Let tests fulfill request keys with chosen raw randomness.
4. Expose no production deployment path.

Recommended name:

```text
StreamEntropyProviderMock
```

The mock provider should make tests precise:

1. request created;
2. fulfillment succeeds;
3. wrong fulfiller fails;
4. stale fulfillment is rejected;
5. zero raw randomness still finalizes through explicit status;
6. coordinator seed derivation is deterministic.

## Future Provider Adapters

Future adapters should be added by implementing `IStreamEntropyProvider` and
being activated in the coordinator provider registry.

New adapters require:

1. provider-specific spec section;
2. source security model;
3. request and callback mapping design;
4. payment model, if any;
5. callback failure and retry behavior;
6. event schema;
7. required tests;
8. deployment runbook;
9. provider lifecycle policy.

Existing `StreamCore` should not need changes for future providers.

## Required Tests

Common provider tests:

1. `isStreamEntropyProvider()` returns true.
2. `providerType()` and `providerVersion()` are stable.
3. Only coordinator can call `requestEntropy`.
4. Request maps provider request ID to request key.
5. Unknown callback request IDs are rejected or explicitly evented.
6. Callback stores raw randomness before coordinator fulfillment.
7. Coordinator fulfillment success marks result delivered.
8. Coordinator fulfillment failure leaves result retryable.
9. `retryCoordinatorFulfillment` succeeds after a transient coordinator failure.
10. Adapter never calls Core.
11. Duplicate live request keys are rejected.
12. Adapters never produce fresh randomness for an old request key.
13. Fulfilled or stale request bindings remain queryable for audit.
14. Provider epoch is emitted or reconstructable for every request.
15. Received-not-delivered results are monitorable.

VRF tests:

1. VRF request uses current config.
2. VRF request emits request key, request ID, subscription, key hash, request
   confirmations, callback gas limit, and number of words.
3. VRF callback compresses returned words deterministically.
4. VRF callback calls coordinator with request key and raw randomness.
5. VRF config updates are admin-only and evented.
6. Existing requests retain request-time provenance after config updates.
7. Wrong-epoch callback path is rejected by the coordinator and remains
   auditable in adapter events.

ARRNG tests:

1. ARRNG request uses current payment config.
2. ARRNG request emits request key, request ID, and payment.
3. ARRNG callback compresses returned payload deterministically.
4. ARRNG callback calls coordinator with request key and raw randomness.
5. Payment updates are admin-only and evented.
6. Excess payment is rejected in v1.
7. Withdrawal path is admin-only and evented.
8. Reentrant callback during request submission cannot fulfill or corrupt the
   request mapping.
9. Existing requests retain request-time payment and controller provenance
   after config updates.

Pyth tests:

1. Pyth request binds user contribution to Stream request key and token
   context.
2. User contribution is fixed before provider reveal.
3. Pyth callback rejects unknown request IDs.
4. Callback stores provider contribution and raw randomness before coordinator
   fulfillment.
5. Fee quote, exact payment, excess-payment rejection, and failed request
   behavior match the v1 policy.

Drand tests:

1. Request binds to a future drand round.
2. Past and already-known rounds are rejected.
3. Chain hash, period, genesis time, and target round are evented.
4. Delivery-backed mode validates authorized delivery.
5. Verification-backed mode verifies the beacon signature on supported chains.
6. Missing delivery does not silently fall back to a fresh source.

Instant provider tests:

1. Instant provider cannot be used unless configured.
2. Mode is explicit.
3. Raw randomness derivation is deterministic for a fixed input.
4. Request-time synchronous fulfillment is safe or disabled, and the instant
   provider is never called from `onTokenMinted`.
5. It never calls Core or derives final seed.

Multi-source mixer tests:

1. Source set is frozen before request.
2. Required source count and fallback policy are frozen before request.
3. Source raw randomness values are combined in deterministic order.
4. Missing sources cannot be dropped ad hoc after partial outcomes are known.
5. Final mixed value is delivered to the coordinator once.

Mock provider tests:

1. Test-selected raw randomness can finalize through coordinator.
2. Zero raw randomness is handled by status, not sentinel values.
3. Wrong request key cannot be fulfilled.

## Launch Recommendation

Build `StreamEntropyProviderVRF` first and make it the default provider for
collections whose art depends on entropy.

Build `StreamEntropyProviderMock` for tests.

Before launch, make and retain one fallback decision:

1. Build and review `StreamEntropyProviderARRNG` as the lower-complexity
   fallback provider.
2. Or build and review `StreamEntropyProviderPyth` if its fee, callback,
   liveness, and audit requirements are accepted.
3. Or record an explicit reviewed VRF-only launch exception with operational
   monitoring and no silent fallback.

The retained `StreamEntropyLaunchDecision` manifest is the release artifact for
that choice and must be covered by the release manifest, release-candidate
lockfile, and checksum bundle once a launch candidate chooses a mode. In
`VRF_ONLY`, unavailable VRF halts or rejects new entropy requests for
entropy-dependent collections rather than silently substituting another source.
In fallback modes, the coordinator may use only the reviewed fallback provider
and policy hash recorded in the manifest.

Track drand, Randcast, Supra, Witnet, and API3 QRNG as future adapters. The
best 50-year posture is not to guess the permanent winner now, but to keep
`StreamCore` stable and add provider adapters as the market matures.

Do not ship a multi-source mixer as the default. It is promising for exceptional
collections, but it creates liveness and selective-abort complexity.

Do not ship `StreamEntropyProviderInstant` as a default launch provider. If it
is implemented, it should be explicit-only and carry clear provenance warnings.

## Reference URLs

Primary references used for this provider roadmap:

1. Chainlink VRF: https://docs.chain.link/vrf
2. Chainlink VRF v2.5 security guidance:
   https://docs.chain.link/vrf/v2-5/security
3. Pyth Entropy protocol design:
   https://docs.pyth.network/entropy/protocol-design
4. drand documentation: https://docs.drand.love/
5. drand BLS12-381 verification on Ethereum:
   https://docs.drand.love/blog/2025/08/26/verifying-bls12-on-ethereum/
6. EIP-2537 BLS12-381 precompiles:
   https://eips.ethereum.org/EIPS/eip-2537
7. EIP-4399 PREVRANDAO:
   https://eips.ethereum.org/EIPS/eip-4399
8. EIP-2935 historical blockhash storage:
   https://eips.ethereum.org/EIPS/eip-2935
9. ARPA Randcast: https://docs.arpanetwork.io/randcast
10. Supra dVRF documentation: https://docs.supra.com/dvrf/overview
11. Witnet randomness documentation:
    https://docs.witnet.io/smart-contracts/witnet-randomness-oracle
12. API3 QRNG documentation: https://old-docs.api3.org/qrng/
13. Paradigm SNARK/VDF randomness research:
    https://www.paradigm.xyz/2023/01/eth-rng
14. VDF economic-security research:
    https://arxiv.org/html/2604.04744v1

Historical Stream/NextGen references:

1. ADR 0005 randomness issue:
   https://github.com/6529-Collections/6529Stream/issues/14
2. Randomizer lifecycle implementation:
   https://github.com/6529-Collections/6529Stream/pull/65
3. Request lifecycle tracking:
   https://github.com/6529-Collections/6529Stream/issues/37
4. Callback validation:
   https://github.com/6529-Collections/6529Stream/issues/39
5. Provider migration with pending requests:
   https://github.com/6529-Collections/6529Stream/issues/41
6. Deterministic post-processing retry:
   https://github.com/6529-Collections/6529Stream/issues/42
7. Raw random words versus derived hash storage:
   https://github.com/6529-Collections/6529Stream/issues/43
8. Removal or scoping of weak randomness helpers:
   https://github.com/6529-Collections/6529Stream/issues/73
9. Code4rena NextGen stale-callback finding:
   https://github.com/code-423n4/2023-10-nextgen-findings/issues/1778
10. Code4rena NextGen provider-change finding:
    https://github.com/code-423n4/2023-10-nextgen-findings/issues/1118
