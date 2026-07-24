# Stream Entropy Provider Adapters

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md); the decisions formerly tracked
inline are resolved by
[ADR 0009](adr/0009-protocol-v1-open-question-resolutions.md),
[ADR 0010](adr/0010-world-class-spec-pass.md),
[ADR 0011](adr/0011-world-class-pass-round-2.md),
[ADR 0012](adr/0012-world-class-pass-round-3.md),
[ADR 0013](adr/0013-world-class-pass-round-4.md), and
[ADR 0014](adr/0014-world-class-pass-round-5.md), as amended by
[ADR 0017](adr/0017-raise-only-parameter-governance.md), and recorded
in [`docs/spec-open-questions.md`](spec-open-questions.md).

This document specifies the Stream-native entropy provider adapter contracts
that feed raw randomness into `StreamEntropyCoordinator`. 6529Stream is
permanent infrastructure for the 6529 network: the first production
deployment is the permanent system. Requirements here are classified by
permanence class per `docs/spec-policy.md`. The provider interface and its
result-status semantics are Permanent; individual provider adapters are
Replaceable modules behind that frozen interface.

The coordinator spec is `docs/stream-entropy-coordinator.md`. That document
defines token registration, request lifecycle, seed finalization, delivery
retry, provider registry state, recovery policy, and metadata integration. This
document defines the provider contracts that connect external or deterministic
randomness sources to that coordinator.
The cross-cutting 50+ year architecture principles live in
`docs/stream-long-term-architecture.md`.

## Genesis Adapter Scope

The genesis adapter set is intentionally small:

1. `StreamEntropyProviderVRF` as the default high-assurance production adapter.
2. `StreamEntropyProviderMock` for local development, tests, and deterministic
   simulations.
3. One reviewed fallback adapter shipped alongside VRF: genesis ships dual
   providers — VRF primary plus one reviewed
   `StreamEntropyProviderARRNG` or `StreamEntropyProviderPyth` fallback, with
   ARRNG as the preferred candidate and Pyth as the reviewed alternate
   (ADR 0009 decision 21). A VRF-only deployment is not conformant; the
   former reviewed VRF-only exception path is removed. The shipped choice
   must be retained in a checksum-covered `StreamEntropyLaunchDecision`
   manifest, either as
   `release-artifacts/latest/entropy-launch-decision.json` or as an equivalent
   release-manifest record, that records the mode, selected provider code hashes,
   policy hashes, review evidence, and coordinator failure behavior.

All other provider families in this document are extension candidates:
Replaceable-layer adapters that may be added behind the frozen provider
interface, provider epochs, and coordinator registry approval. Each requires
its own separate accepted spec and review before production use, and none is
part of the genesis implementation scope unless an accepted ADR explicitly
promotes it.

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

The coordinator's token-keyed and scope-keyed request kinds (ADR 0011
decision R8) share this one adapter boundary: adapters serve both
identically and never distinguish them [EP-CONTEXT].

The current `NextGenRandomizerNXT`, `NextGenRandomizerRNG`, and
`NextGenRandomizerVRF` contracts are reference material only. The production
target is a new set of Stream-native adapters.

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

The genesis recommendation remains simple: use Chainlink VRF v2.5 as the first
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

Fee quoting requirements [EP-QUOTE]:

1. `quoteRequest(context)` must return the exact fee that `requestEntropy`
   will require for the same context in the same transaction. The
   coordinator quotes, checks the caller's `msg.value` bound, and forwards
   exactly the quoted amount within one transaction (ADR 0010 decision
   D8.7); adapters must not derive the required fee from state that can
   change between the quote and the request call inside one transaction.
2. Fee changes — admin updates or upstream fee moves — apply to future
   transactions only. They can never make a same-transaction
   quote-then-request pair disagree, so provider fee drift can only
   affect callers whose `msg.value` no longer covers the new fee.
3. Adapters must require exact payment at their boundary
   (`msg.value == quoteRequest(context)`) and reject excess. Caller
   overpayment tolerance and pull-credit refunds are coordinator-side:
   [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
   [EC-FEEBIND].
4. Fee-free adapters must return zero from `quoteRequest` and reject
   nonzero `msg.value`.

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

Context handling requirements [EP-CONTEXT]:

1. The version prefix is the leading `uint16`. Schema version 1 is the
   token-request context above; schema version 2 is the scope-request
   context, carrying the coordinator `scopeId` in place of a token ID.
   Both encodings are owned by the coordinator spec
   ([`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
   Request Flow and [EC-SCOPE]; ADR 0011 decision R8).
2. Adapters must treat `requestKey` and `context` as opaque: token-keyed
   and scope-keyed requests are indistinguishable at the adapter boundary
   and flow through identical request, callback, storage, retry, and
   status-probe paths.
3. Adapters may decode context versions they recognize for events,
   request metadata, or source-specific payloads. They must not use
   decoded context as authority in place of the coordinator request key,
   and they must not reject or special-case a request because its
   context schema version is unrecognized.

`providerResultStatus` is the shared audit and recovery probe. It must remain
queryable after delivery, stale marking, failed delivery, or incident handling.
Fresh entropy recovery for a token is forbidden when the old adapter reports
`rawRandomnessReceived = true`, even if coordinator delivery failed. The
probe is one-directional evidence: a `true` report blocks fresh recovery
absolutely, while a `false` report alone never licenses it — the
coordinator corroborates a negative report against its own request state
and requires an independent-evidence commitment before any fresh draw
([`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
[EC-INCIDENT] rule 3; ADR 0011 decision R12).

## Common Adapter Requirements

1. Bind to exactly one coordinator at construction.
2. `requestEntropy` must revert unless called by that coordinator.
3. Each accepted request must map a provider request ID to exactly one
   coordinator `requestKey`.
4. Each provider callback must store raw randomness or enough source data to
   reconstruct it before attempting coordinator fulfillment.
5. Provider callbacks must deliver to the coordinator through try/catch or
   a checked low-level call; if coordinator fulfillment fails during a
   provider callback, the adapter must retain the raw randomness and
   expose a retry path for coordinator fulfillment [EP-CALLBACK]
   (ADR 0010 decision D8.1).
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
21. Adapter operational authorities must be contract-held governed
    configuration, not documented key custody [EP-CUSTODY] (ADR 0010
    decision D7.5).
22. Adapters must support rotation of operational authorities by contract
    execution without changing already-recorded request commitments
    [EP-CUSTODY].

## Operational Authority Custody

Entropy is provenance-critical, and the external dependency's control
plane must meet the same custody bar as protocol roles: no single EOA may
be able to execute a material action, and no single lost key may stall the
subsystem (ADR 0010 decision D7.5).

Requirements [EP-CUSTODY]:

1. Every adapter operational authority must be contract-holdable and
   contract-held: provider subscription owners (for VRF, the Chainlink
   subscription owner), consumer registration authorities, LINK/native
   funding wallets, payment configuration admins, and withdrawal
   destinations must be Safe/multisig or governance contracts, never
   long-lived EOAs.
2. These authorities are governed configuration, not documentation: each
   is recorded in the deployment manifest alongside protocol role
   assignments and verified by the governance conformance gate before
   production deployment.
3. Rotation of a compromised or lost operational authority must be
   executable by contract (for example, a Safe-executed VRF subscription
   ownership transfer) without changing already-recorded request
   commitments, and a rehearsed contract-executed rotation is required
   release evidence.
4. Custody and funding parameters are Operational-layer values excluded
   from `streamEntropyProviderConfigHash()` [EP-CONFIGHASH]: rotating an
   authority or moving future requests to a new subscription never alters
   old request provenance, entropy identity, or provider epochs.
5. Provider key runbooks name the responsible governance role, review
   cadence, loss procedure, compromise procedure, and expected collection
   impact for each authority. For VRF this covers subscription ownership,
   consumer registration, funding, callback gas settings, and the
   new-subscription migration procedure. Runbooks describe how the
   contract-held authorities are exercised; they never substitute for
   contract custody.

## Provider Config Hash Contents

`streamEntropyProviderConfigHash()` is entropy identity: it is snapshotted
into requests, bound into `requestKey` and seed derivation, and pinned by
provider epochs and finality manifests.

Requirements [EP-CONFIGHASH]:

1. The config hash must bind every randomness-identity parameter: for
   VRF-class adapters at least the VRF coordinator address, key hash,
   `requestConfirmations`, and `numWords`; for other families the
   equivalent source-identity and security parameters.
2. The config hash must exclude Operational-layer parameters: callback
   gas limits, subscription IDs, funding and custody addresses, payment
   amounts, and withdrawal destinations (ADR 0010 decisions D1.3 and
   D7.5). Retuning gas, fees, funding, or custody never changes entropy
   identity, never increments a collection provider epoch, and never
   disturbs a frozen collection.
3. Changing any bound identity parameter changes the config hash and is a
   provider config change under the coordinator's epoch rules; changing
   an excluded Operational parameter is not.

The provider-family identity surface is the one already declared on
`IStreamEntropyProvider`:

```solidity
function streamEntropyProviderFamily() external pure returns (bytes32);
function streamEntropyProviderVersion() external pure returns (bytes32);
```

Providers additionally expose the canonical module identity surface
(`streamModuleType()` and companions, ADR 0009 decision 3) like every other
satellite.

Example values:

```text
STREAM_ENTROPY_PROVIDER_VRF
STREAM_ENTROPY_PROVIDER_ARRNG
STREAM_ENTROPY_PROVIDER_INSTANT
STREAM_ENTROPY_PROVIDER_MOCK
```

## Common Events [EP-EVENTS]

This document is the normative home of the provider-adapter event
vocabulary it defines. Every non-standard event schema in this document
carries `uint16 schemaVersion` as its leading declaration field —
declared before every indexed parameter, so it is also the first
data-section field — and declares at most three indexed parameters;
genesis emits every such event with `schemaVersion = 1` (ADR 0013
decision U7), except the raise-only parameter-family
`GasParameterRegistered` and `GasParameterUpdated` events, whose
`schemaVersion` is `2` under ADR 0017. For the genesis
adapters these blocks are the
production-exact signatures the machine-readable event catalog must
reproduce; extension-family blocks bind their separately accepted
adapter specs the same way. The conformance-matrix "snippet is
shorthand" rule covers citations of these events in other documents,
never this home. Host events of adapter mutations that execute as
canonical ADR 0004 governance actions bind the authorizing
`bytes32 actionId` (ADR 0014 decision V6); in the genesis adapter set
that is `VRFConfigUpdated` [EP-VRF-CONFIG].

Every provider must emit source-specific request and callback events. The
minimum shared shape is:

```solidity
event ProviderEntropyRequested(
    uint16 schemaVersion,
    bytes32 indexed requestKey,
    uint256 indexed providerRequestId,
    address indexed coordinator,
    uint32 providerEpoch
);

event ProviderEntropyReceived(
    uint16 schemaVersion,
    bytes32 indexed requestKey,
    uint256 indexed providerRequestId,
    bytes32 rawRandomness
);

event ProviderCoordinatorFulfillmentAttempted(
    uint16 schemaVersion,
    bytes32 indexed requestKey,
    uint256 indexed providerRequestId,
    bool success,
    bytes returnData
);
```

Provider-specific events should include source configuration such as VRF key
hash, subscription ID, request confirmations, or ARRNG payment amount when
useful.

## Raw Randomness Compression [EP-RAW]

Adapters should report one `bytes32 rawRandomness` value to the coordinator
(anchor per ADR 0013 decision U9).
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

This document is the normative home of the provider-side raw compression
domains (ADR 0010 decision D3.1); the input lists are the `abi.encode`
blocks in each owning adapter section, and the checked domain-constants
table in
[`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
mirrors these rows. Release tooling computes and pins the hash values.

| Constant name | String preimage | Hash value | Owner | Schema version | Scope |
| --- | --- | --- | --- | --- | --- |
| `STREAM_PROVIDER_RAW_V1` | `6529STREAM_PROVIDER_RAW_V1` | 0x9d25920cde651730cff9eacf736aaa7aa2f6d1f22e948f5d5e362fb181a5bee1 | provider adapters (generic) | `1` | genesis |
| `STREAM_VRF_RAW_V1` | `6529STREAM_VRF_RAW_V1` | 0x9aec1af5d92901527f48ea05f0779a6d6cd5153a45cb99ffa4383b1b4beea311 | `StreamEntropyProviderVRF` | `1` | genesis |
| `STREAM_ARRNG_RAW_V1` | `6529STREAM_ARRNG_RAW_V1` | 0xa7c608806995e034e71d26ec44e96245b593a47fe673f8f1d8e33cde02c3bf86 | `StreamEntropyProviderARRNG` | `1` | genesis if selected fallback |
| `STREAM_PYTH_RAW_V1` | `6529STREAM_PYTH_RAW_V1` | 0x904dfcae5221db62594fb78af05341a66a4e8d649ec151a90cee174eecf6e246 | `StreamEntropyProviderPyth` | `1` | genesis if selected fallback |
| `STREAM_DRAND_RAW_V1` | `6529STREAM_DRAND_RAW_V1` | 0x81d2ca2a7da654d7cfe760fac3c357e03fc212d4790b5277459b5717b3f46201 | `StreamEntropyProviderDrand` | `1` | extension |
| `STREAM_MULTI_SOURCE_RAW_V1` | `6529STREAM_MULTI_SOURCE_RAW_V1` | 0x94257c55589ad53441c332497f043fbe4820fe5089152303939a0aaba1f8f4f0 | multi-source mixer adapters | `1` | extension |
| `GGP_VRF_CALLBACK_GAS_LIMIT` | `6529STREAM_GGP_VRF_CALLBACK_GAS_LIMIT` | 0xb54bc37de6ab63d94434a3fb47e0b24ad67118105c91c59db7b1c58d482f5491 | provider adapters | `1` | genesis (Governed Gas Parameter identifier per [LTA-GGP]; [EP-VRF-CONFIG]) |

## Callback Delivery Discipline

Upstream randomness callbacks are one-shot: Chainlink-class coordinators
mark a request fulfilled when the consumer callback runs, whether or not
the consumer's downstream logic succeeded, and never redeliver. A
coordinator revert that unwinds the adapter's stored randomness therefore
loses the randomness forever and strands the token `REQUESTED` under the
default no-fresh-recovery policy. Callback delivery is store-first,
try/catch-second (ADR 0010 decision D8.1).

Requirements [EP-CALLBACK]:

1. A provider callback must validate the provider request ID, then persist
   the `ProviderResult` — including the raw randomness and
   `rawRandomnessReceived = true` — before any call to
   `coordinator.fulfillEntropy`.
2. The callback must invoke `coordinator.fulfillEntropy` through Solidity
   `try/catch` or a checked low-level call. A coordinator revert, a
   subcall out-of-gas, or malformed return data must be caught inside the
   adapter frame; it must never bubble a revert into the upstream
   randomness callback.
3. On a caught failure the adapter emits
   `ProviderCoordinatorFulfillmentAttempted` with `success = false` and
   retains the result unchanged; `retryCoordinatorFulfillment` then
   re-delivers the identical stored randomness. On a `FINALIZED` outcome
   the adapter marks the result delivered.
4. A benign rejection outcome follows the terminal-stale rule in the
   Coordinator Fulfillment Retry section. `REJECTED_PROVIDER_REVOKED`
   must not mark the result terminal: the retained result is the
   `rawRandomnessReceived` evidence that keeps unsafe fresh recovery
   blocked while incident policy resolves the request.
5. Callback gas limits must be sized from the measured coordinator
   fulfillment envelope — `fulfillEntropy` including the restricted Core
   refresh emitter call — plus the adapter's own persistence writes and
   outcome handling, with a margin published in the release manifest.
   The margin must include the governance-published worst-case
   repricing headroom recorded in the release manifest and remeasured
   by every hard-fork/repricing review, and must reserve the
   adapter-local persistence-and-outcome budget separately from the
   coordinator envelope, so envelope growth exhausts the retryable
   coordinator subcall before it can reach the store-first writes
   [EP-INFLIGHT] (ADR 0012 decision T1). Monitoring must alert when the
   measured envelope exceeds two-thirds of the configured callback gas
   limit.
6. These rules apply to every callback-receiving adapter family — VRF,
   ARRNG, Pyth, drand, Randcast, Supra, Witnet, and all future adapters —
   and to permissionless retry paths.

## In-Flight Requests Under Raises And Repricings [EP-INFLIGHT]

Chainlink-class upstreams bind the callback gas limit per request at
submission time. Raising `VRF_CALLBACK_GAS_LIMIT` — or any adapter
callback-gas configuration — therefore protects future requests only
([EP-VRF-CONFIG] rule 4): every in-flight request executes under the
limit it was submitted with, and the upstream coordinator additionally
enforces its own maximum callback gas above which no raise can go. This
section pins what happens to requests in flight when the fulfillment
envelope grows — through a gas-schedule repricing or a measured-envelope
increase — faster than their submitted limits (ADR 0012 decision T1).

Requirements [EP-INFLIGHT]:

1. Two failure classes are distinguished, and only the first is
   recoverable:
   1. Coordinator-frame failure: the callback frame completes the
      adapter's own persist writes, and the `fulfillEntropy` subcall
      reverts or runs out of gas inside the [EP-CALLBACK] try/catch.
      The stored result survives, and `retryCoordinatorFulfillment`
      re-delivers the identical randomness in a later transaction with
      fresh gas, regardless of the original request's submitted limit.
      The [EP-CALLBACK] rule 5 adapter-local reserve exists precisely
      so envelope growth lands in this class.
   2. Frame-level loss: a repricing inflates the adapter's own persist
      writes beyond an in-flight request's submitted limit, the
      one-shot callback reverts before storing, the upstream marks the
      request fulfilled and never redelivers, and the raw output stands
      publicly revealed in the upstream fulfillment transaction while
      the adapter holds nothing.
2. The frame-level-loss outcome is pinned, not improvised: the adapter
   probe truthfully reports no randomness received, but the
   [EC-INCIDENT] rule 3 evidence bundle can never corroborate that no
   upstream fulfillment occurred (ADR 0011 decision R12), so fresh
   recovery is blocked by construction for every collection — with or
   without a frozen fresh-recovery policy — because a fresh draw after
   a publicly revealed output is a reroll. The request stays
   `REQUESTED`, and its token or scope renders honest pending state
   indefinitely: a disclosed permanence limit of one-shot upstream
   callbacks. A separately accepted Replaceable replay adapter behind
   the frozen provider interface may later make the already-revealed
   upstream output deliverable again under a frozen recovery policy —
   delivering the identical value is delivery, not a reroll — but no
   such module ships at genesis and nothing in this spec depends on
   one. Collection finality over a permanently pending token follows
   the never-finalized-entropy content-root semantics owned by
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   (ADR 0012 decision T3).
3. There is no pre-emptive re-request: creating a second live draw for
   a subject whose first request can still fulfill is exactly the
   reroll surface the coordinator's Request Commitment Finality rules
   exclude. The protections are preventive:
   1. headroom — the [EP-CALLBACK] rule 5 margin includes the published
      worst-case repricing headroom, remeasured by every
      hard-fork/repricing review before activation;
   2. activation-boundary drain — where a scheduled gas-schedule change
      would push the measured envelope past the submitted limit of any
      in-flight request class, operations must raise the parameter
      ahead of activation for new requests, alert on every request
      still pending across the activation boundary whose submitted
      limit the post-fork envelope would exceed, and complete or
      retry-deliver those requests before activation where possible.
      Healthy VRF in-flight windows are minutes long, so the straddle
      set is small by construction; the drain obligation and its alert
      join the release-manifest monitoring plan beside the
      [EP-CALLBACK] rule 5 alert.
4. Upstream ceiling and migration ladder: when the measured envelope
   plus margin approaches the upstream coordinator's own maximum
   callback gas, raising the adapter parameter is no longer a remedy.
   The remediation is migrating future requests to an upstream
   coordinator version (or provider family) with a sufficient ceiling —
   a randomness-identity change under [EP-CONFIGHASH] and the
   coordinator's provider-epoch rules, never a silent config drift.
   Subscription-level settings (`subscriptionId`, funding) stay
   Operational and never gate this ladder.
5. These rules apply to every callback-receiving adapter family whose
   upstream binds per-request callback gas and does not redeliver —
   VRF, ARRNG, Pyth, drand, Randcast, Supra, Witnet, and future
   adapters. Each adapter spec must state its upstream's callback-gas
   ceiling, its redelivery posture, and which of the failure classes
   above its upstream can produce.

## Coordinator Fulfillment Retry

External randomness callbacks are valuable. If a callback receives valid
randomness but the coordinator call fails, the adapter must not lose it
(ADR 0010 decision D8.1). Persistent result storage and a retry surface
are mandatory for every callback-receiving adapter; the storage layout
below is the reference shape, and any equivalent must preserve every
distinction the status probe reports.

Required result storage (reference shape):

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

The retry surface is part of the frozen provider interface:

```solidity
function retryCoordinatorFulfillment(uint256 providerRequestId) external;
```

Rules [EP-RETRY]:

1. Provider result must exist and be received.
2. Result must not already be delivered.
3. Function may be called by anyone, unless the provider source requires a more
   constrained policy.
4. Adapter calls
   `uint8 outcome = coordinator.fulfillEntropy(requestKey, rawRandomness);`
   and inspects the returned outcome.
5. On a `FINALIZED` outcome, marks result delivered.
6. On a caught revert, emits `ProviderCoordinatorFulfillmentAttempted` with
   `success = false` and keeps the result available for later retry. The
   stored `requestKey`, raw randomness, epoch, and config hash are
   immutable across attempts.
7. On a benign rejection outcome, applies the terminal-stale rule below.

`fulfillEntropy` returns a pinned `EntropyFulfillmentOutcome` code instead of
reverting on benign rejection (ADR 0009 decision 25); the outcome enum is
defined in `docs/stream-entropy-coordinator.md`. If the coordinator rejects
because the request is stale, already finalized, or failed, the adapter
should retain the result. An adapter may mark a delivered result
`TERMINAL_STALE` only when `fulfillEntropy` returned `REJECTED_STALE_EPOCH`
or `REJECTED_INACTIVE_REQUEST`, or when the coordinator's request-status
read shows that the adapter's stored (epoch, attempt) pair is no longer
active. `REJECTED_PROVIDER_REVOKED` never authorizes terminal marking: the
request is still active, and the retained result is recovery evidence
[EP-CALLBACK].

## StreamEntropyProviderVRF

`StreamEntropyProviderVRF` is the default high-assurance genesis provider
family. It should be a new Stream-native adapter, not the current
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
    uint256 subscriptionId,
    bytes32 keyHash,
    uint16 requestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
)
```

This reference shape targets the recommended upstream version, Chainlink
VRF v2.5, whose subscription IDs are `uint256` (Research Findings;
ADR 0013 decision U7). A deployment against a different upstream
coordinator version uses a versioned adapter name — for example
`StreamEntropyProviderVRFV2` for the v2-era `uint64`-subscription shape —
and retypes the subscription field to that version's width:
subscription-ID width is upstream-version-specific Operational
configuration, excluded from the config hash like the subscription value
itself [EP-CONFIGHASH]. The Stream adapter boundary stays the same.

### State

Recommended state:

```solidity
address public immutable coordinator;
address public vrfCoordinator;
uint256 public subscriptionId;
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

Event ([EP-EVENTS]):

```solidity
event VRFEntropyRequested(
    uint16 schemaVersion,
    bytes32 indexed requestKey,
    uint256 indexed vrfRequestId,
    uint256 indexed subscriptionId,
    uint32 providerEpoch,
    bytes32 keyHash,
    uint16 requestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
);
```

### Callback Flow

```text
VRF coordinator callback [must never revert; EP-CALLBACK]
  -> adapter verifies known vrfRequestId
  -> adapter compresses random words to rawRandomness
  -> adapter stores result and marks RAW_RANDOMNESS_RECEIVED
  -> try coordinator.fulfillEntropy(requestKey, rawRandomness)
       returns outcome: adapter marks delivered only on FINALIZED;
       benign rejections follow the terminal-stale rule [EP-RETRY]
     catch (coordinator revert or subcall out-of-gas):
       adapter emits ProviderCoordinatorFulfillmentAttempted(success=false)
       stored result survives for retryCoordinatorFulfillment
```

The callback frame must satisfy [EP-CALLBACK]: the stored raw randomness
survives every coordinator failure, and the upstream VRF coordinator never
observes a revert (ADR 0010 decision D8.1).

Recommended raw compression:

```solidity
bytes32 rawRandomness = keccak256(abi.encode(
    STREAM_VRF_RAW_V1,
    requestKey,
    vrfRequestId,
    randomWords
));
```

Event ([EP-EVENTS]):

```solidity
event VRFEntropyReceived(
    uint16 schemaVersion,
    bytes32 indexed requestKey,
    uint256 indexed vrfRequestId,
    bytes32 rawRandomness
);
```

### Admin Configuration

Admins may need to update VRF operational settings:

```solidity
function updateVRFConfig(
    uint256 subscriptionId,
    bytes32 keyHash,
    uint16 requestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
) external;
```

Rules [EP-VRF-CONFIG]:

1. Admin-only through ADR 0004 governance/action roles. Legacy selector-map
   `StreamAdmins` authorization is nonconformant for production deployment.
   `updateVRFConfig` is one protected selector in the governance action
   policy catalog; because its parameter set spans randomness identity
   (rule 5) and a Governed Gas Parameter (rule 6), the selector is
   catalog-classed as a canonical ADR 0004 governance action, with its
   class-`1` delay recorded there. It has no emergency eligibility
   (ADR 0017).
2. Emit `VRFConfigUpdated` binding the authorizing canonical action ID
   (ADR 0014 decision V6). `VRFConfigUpdated` is not a GGP family
   alias — it carries no old value and no floor — so a change touching
   `callbackGasLimit` additionally emits the canonical
   schema-v2 `GasParameterUpdated` family event ([LTA-GGP] requirement 4 in
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)),
   bound to the same action ID.
3. Existing requests retain the provenance values emitted at request time.
4. Updates affect only future requests.
5. `keyHash`, `requestConfirmations`, and `numWords` are randomness-identity
   parameters bound by `streamEntropyProviderConfigHash()`; updating any of
   them is a provider config change under the coordinator's epoch rules.
   `subscriptionId` and `callbackGasLimit` are Operational parameters
   excluded from the config hash [EP-CONFIGHASH].
6. `callbackGasLimit` is the adapter-hosted `VRF_CALLBACK_GAS_LIMIT`
   Governed Gas Parameter
   ([`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-GGP]): its genesis value must not be below its immutable floor
   `VRF_CALLBACK_GAS_FLOOR`, sized from the measured fulfillment envelope
   with margin [EP-CALLBACK item 5]; raising it is a service-restoring
   authority-only class-`1` action delayed at least 48 hours and bounded to
   2x, and the floor, genesis value, and measured envelope are
   recorded in the release manifest. A raise binds future requests only
   — in-flight requests keep their submitted limit — and the upstream
   coordinator's own maximum callback gas bounds every raise; the
   in-flight, drain, and ceiling semantics are pinned in [EP-INFLIGHT]
   (ADR 0012 decision T1).
7. Subscription ownership, consumer registration, and funding follow the
   contract-held custody requirements [EP-CUSTODY] (ADR 0010 decision
   D7.5).
8. The parameter's release-manifest failure-direction class is
   `FORWARDING_CAP` ([LTA-GGP] requirement 10): it caps the gas the
   upstream forwards to the adapter callback, and raising it restores
   delivery for future requests. Reproducible sizing evidence executes a
   faithful equivalent of the
   callback frame: the persist writes plus a fulfillment-shaped subcall
   replicating the published coordinator envelope ([EC-FULFILL]
   rule 13), under the candidate value against a pinned fixture corpus. A
   release golden asserts measurement parity with the production envelope.
   The evidence has no onchain authorization role, and no lower, emergency,
   probe, rebind, conditional, or permissionless writer exists (ADR 0017).

Event ([EP-EVENTS]):

```solidity
event VRFConfigUpdated(
    uint16 schemaVersion,
    bytes32 indexed actionId,
    uint256 subscriptionId,
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
5. Callback must not permanently lose randomness if coordinator fulfillment
   fails: store-first persistence, try/catch delivery, and permissionless
   retry are mandatory [EP-CALLBACK] (ADR 0010 decision D8.1).
6. Admin config updates must be visible in events.
7. Subscription ownership, consumer registration, and funding authorities
   are contract-held governed configuration [EP-CUSTODY]; deployment
   runbooks describe how those contract-held authorities are exercised.

## StreamEntropyProviderARRNG

`StreamEntropyProviderARRNG` is the preferred candidate for the reviewed
fallback provider that genesis ships alongside the VRF primary: genesis
ships VRF primary plus one reviewed fallback, ARRNG preferred for its
existing operational experience, Pyth as the reviewed alternate, and a
VRF-only deployment is not conformant (ADR 0009 decision 21). It should be
a new Stream-native adapter if selected. The current `NextGenRandomizerRNG`
can inform the integration, but should not be reused as-is.

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
       require msg.value == requestPaymentWei, if payment is required
       request external randomness
       store arrngRequestId -> requestKey
       emit ARRNGEntropyRequested
       return arrngRequestId
```

Event ([EP-EVENTS]):

```solidity
event ARRNGEntropyRequested(
    uint16 schemaVersion,
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

Then it follows the same store-first, try/catch-delivery pattern as VRF
[EP-CALLBACK].

Event ([EP-EVENTS]):

```solidity
event ARRNGEntropyReceived(
    uint16 schemaVersion,
    bytes32 indexed requestKey,
    uint256 indexed arrngRequestId,
    bytes32 rawRandomness
);
```

### Payment And Recovery

ARRNG payment behavior must be explicit [EP-ARRNG-PAY]:

1. `requestPaymentWei` updates are admin-only, evented, and apply to future
   transactions only. The payment amount is an Operational parameter
   excluded from `streamEntropyProviderConfigHash()` [EP-CONFIGHASH], and
   `quoteRequest` must return the live `requestPaymentWei` so the
   same-transaction quote rule holds [EP-QUOTE].
2. The adapter must require exact native ETH payment at its boundary and
   reject excess. A conformant coordinator never sends excess: it binds
   the caller's `msg.value` as `maxFeeWei`, forwards exactly the
   same-transaction quote, and refunds caller excess as a pull credit
   ([EC-FEEBIND] in
   [`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md),
   ADR 0010 decision D8.7). Fee updates therefore cannot grief in-flight
   requests whose `msg.value` still covers the new fee.
3. Adapter balances must not silently accumulate.
4. Withdrawals must send only to the configured withdrawal destination — a
   Safe/multisig or governance treasury contract recorded as governed
   configuration [EP-CUSTODY] — and emit an event.
5. Forced ETH must be recoverable through an explicit admin path to the
   same governed destination.

Events ([EP-EVENTS]):

```solidity
event ARRNGPaymentUpdated(
    uint16 schemaVersion,
    uint256 oldPaymentWei,
    uint256 newPaymentWei
);

event ProviderFundsWithdrawn(
    uint16 schemaVersion,
    address indexed to,
    uint256 amountWei
);
```

### ARRNG Security Requirements

1. Callback must reject unknown ARRNG request IDs.
2. Callback must not trust token ID from external calldata.
3. Callback must not call Core.
4. Callback must not derive the final seed.
5. Callback must not permanently lose randomness if coordinator fulfillment
   fails: store-first persistence, try/catch delivery, and retry are
   mandatory [EP-CALLBACK] (ADR 0010 decision D8.1).
6. Payment handling must be tested for exact payment, excess-payment rejection,
   failed external request, and withdrawal.
7. If the ARRNG controller returns the request ID only after an external
   payable call, the adapter must guard the submission window against
   reentrant callback attempts.
8. The adapter must record the ARRNG request ID to `requestKey` binding before
   any valid callback can be accepted.
9. The fallback review must record the ARRNG controller's callback-gas
   provisioning, ceiling, and redelivery posture, and which
   [EP-INFLIGHT] failure classes the upstream can produce, in the
   `StreamEntropyLaunchDecision` manifest.

## StreamEntropyProviderPyth

`StreamEntropyProviderPyth` is the reviewed alternate for the fallback
provider that genesis ships alongside the VRF primary: it ships only if it,
rather than the preferred ARRNG candidate, is selected as the reviewed
fallback (ADR 0009 decision 21). It is more integration-complex than
ARRNG and needs explicit fee, callback, liveness, and audit coverage before
activation.

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
8. Make native fee estimation, excess-payment rejection, and failures
   explicit. Pyth fees are quote-dependent: `quoteRequest` must read the
   live upstream fee so the same-transaction quote rule holds [EP-QUOTE],
   and upstream fee drift is absorbed by the coordinator's `maxFeeWei`
   binding ([EC-FEEBIND], ADR 0010 decision D8.7), never by failing
   in-flight requests whose `msg.value` still covers the new fee.

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
8. Payment handling must be tested for exact fee, excess-fee rejection at
   the adapter boundary, upstream fee drift between quote observation and
   execution (absorbed by the coordinator fee binding, never a stranded
   request), failed request, and withdrawal to the governed destination
   [EP-CUSTODY].
9. The fallback review must record the Pyth Entropy callback-gas
   provisioning, ceiling, and redelivery posture, and which
   [EP-INFLIGHT] failure classes the upstream can produce, in the
   `StreamEntropyLaunchDecision` manifest.

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

`StreamEntropyProviderDrand` is an extension public-beacon adapter family:
a Replaceable-layer candidate behind the frozen provider interface, requiring
a separate accepted spec and review before production use.

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

`StreamEntropyProviderRandcast` is an extension threshold-BLS oracle adapter
candidate.

ARPA Randcast uses a network of nodes performing BLS threshold signature tasks.
The adapter model looks similar to a VRF callback: request randomness, map the
provider request ID to the Stream request key, receive a verifiable random seed,
store first, and fulfill the coordinator.

This is not a genesis-default recommendation. It is a good candidate to keep on
the provider roadmap because it gives Stream another independent randomness
network family.

Required review before implementation:

1. supported Ethereum mainnet contracts and request API;
2. onchain verification path and who performs it;
3. billing and failure behavior;
4. callback identity and replay protection;
5. operational maturity and audit history.

## StreamEntropyProviderSupra

`StreamEntropyProviderSupra` is an extension dVRF adapter candidate.

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

`StreamEntropyProviderWitnet` is an extension crowd-witnessing randomness
candidate.

Witnet's model uses randomly selected witnesses with commit-reveal and
aggregation. It is conceptually attractive because it is not a single oracle
operator, but it should be reviewed for Ethereum mainnet integration quality,
latency, costs, callback semantics, and audit maturity before being considered
for production collections.

## StreamEntropyProviderAPI3QRNG

`StreamEntropyProviderAPI3QRNG` is an extension physical-entropy candidate.

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

Genesis posture: do not make this the default. Consider it for exceptional
high-value collections, through a separate accepted spec, after the
single-provider flow is audited and deployed.

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

Stream should not build a custom VDF beacon for the genesis deployment. The
better 50-year architecture is:

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

### Timing-Grinding Exposure

`instantEntropy` is a synchronous view finalized inside `requestEntropy`.
That call shape is Permanent and frozen, and it structurally permits
request-timing grinding for any mode whose output varies across the blocks
in which the request transaction could land (ADR 0010 decision D8.8): a
requester can simulate the view offchain each block and submit only when
the derived seed is favorable. The selection is free, leaves no onchain
trace, and is available to any caller on public-request collections. No
rule behind this interface can prevent it, because the interface has no
commit-then-finalize split; the exposure is disclosed and restricted
rather than papered over.

Requirements [EP-INSTANT-TIMING]:

1. The exposure must be disclosed in the adapter's provider metadata, in
   its emitted mode assumptions, and in the provenance notes of every
   collection configured to use an instant provider.
2. Instant providers may be configured only for collections whose frozen
   entropy config declares `EntropySecurityClass.LOW_SECURITY`; the
   coordinator enforces the restriction
   ([`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md)
   [EC-CONFIG], ADR 0010 decision D8.8).
3. A mode is timing-invariant only if its raw randomness derives solely
   from request-key-committed inputs that are identical across every block
   in which the request could land. `DELAYED_BLOCKHASH` is not
   timing-invariant and is therefore low-assurance by construction;
   `DETERMINISTIC_TEST_ONLY` is timing-invariant but remains excluded from
   production.
4. Anti-grinding review of any instant provider must name request-timing
   selection explicitly alongside input-choice grinding; a review that
   covers only input choice is incomplete.
5. The genesis exclusion stands: no instant provider ships at genesis
   (ADR 0009 decision 24).

### Possible Modes

If implemented, use explicit modes:

```solidity
enum InstantMode {
    COMMIT_REVEAL,
    DELAYED_BLOCKHASH,
    DETERMINISTIC_TEST_ONLY
}
```

Recommended genesis posture:

```text
COMMIT_REVEAL             excluded from v1 unless fully specified
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

Recommended event ([EP-EVENTS] binds the future accepted spec):

```solidity
event InstantEntropyProduced(
    uint16 schemaVersion,
    bytes32 indexed requestKey,
    uint256 indexed providerRequestId,
    bytes32 rawRandomness,
    bytes32 provenanceHash,
    InstantMode mode
);
```

### Security Requirements

1. Disabled by default in genesis config.
2. Must be explicitly configured per collection.
3. Must emit mode and assumptions.
4. Must not call Core.
5. Must not derive final seed.
6. Must not allow buyer, minter, artist, or admin grinding after seeing partial
   outcomes, and must treat request-timing selection as a named grinding
   vector [EP-INSTANT-TIMING].
7. May be configured only for collections that declare
   `EntropySecurityClass.LOW_SECURITY` (ADR 0010 decision D8.8).

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

## Extension Provider Adapters

New provider adapters are Replaceable-layer extensions: they implement the
frozen `IStreamEntropyProvider` interface and are activated in the coordinator
provider registry through provider epochs and registry approval. The adapter
interface and result-status semantics are final in v1; only the provider
catalog grows.

New adapters require:

1. a separate accepted provider-specific spec;
2. source security model;
3. request and callback mapping design;
4. payment model, if any;
5. callback failure and retry behavior;
6. event schema;
7. required tests;
8. deployment runbook;
9. provider lifecycle policy.

Existing `StreamCore` should not need changes for new provider adapters.

## Required Tests

Common provider tests:

1. `isStreamEntropyProvider()` returns true.
2. `streamEntropyProviderFamily()` and `streamEntropyProviderVersion()` are
   stable.
3. Only coordinator can call `requestEntropy`.
4. Request maps provider request ID to request key.
5. Unknown callback request IDs are rejected or explicitly evented.
6. Callback stores raw randomness before coordinator fulfillment.
7. A `FINALIZED` coordinator fulfillment outcome marks result delivered.
8. A reverted coordinator fulfillment leaves result retryable; a
   `REJECTED_STALE_EPOCH` or `REJECTED_INACTIVE_REQUEST` outcome authorizes
   `TERMINAL_STALE` marking.
9. `retryCoordinatorFulfillment` succeeds after a transient coordinator failure.
10. Adapter never calls Core.
11. Duplicate live request keys are rejected.
12. Adapters never produce fresh randomness for an old request key.
13. Fulfilled or stale request bindings remain queryable for audit.
14. Provider epoch is emitted or reconstructable for every request.
15. Received-not-delivered results are monitorable.
16. A coordinator revert during a callback is caught inside the adapter
    frame: the upstream callback does not revert, the stored result
    survives unchanged, and
    `ProviderCoordinatorFulfillmentAttempted(success = false)` is emitted
    [EP-CALLBACK].
17. `quoteRequest` equals the fee `requestEntropy` requires in the same
    transaction for identical context; a fee update in a prior transaction
    changes both together [EP-QUOTE].
18. Operational parameter updates (callback gas limit, subscription,
    payment amount, custody destinations) leave
    `streamEntropyProviderConfigHash()` unchanged; identity parameter
    updates change it [EP-CONFIGHASH].
19. Deployment manifest records contract-held operational authorities, and
    a contract-executed rotation (for example, Safe-executed subscription
    ownership transfer) is rehearsed and retained as release evidence
    [EP-CUSTODY].
20. `REJECTED_PROVIDER_REVOKED` outcomes never mark a stored result
    terminal; the result remains queryable as recovery evidence.
21. Token-keyed (context schema version 1) and scope-keyed (schema
    version 2) requests flow through identical adapter paths, and an
    unrecognized context schema version is accepted and treated opaquely
    [EP-CONTEXT].
22. The published callback-gas margin separates the adapter-local
    persistence reserve from the coordinator envelope and includes the
    recorded worst-case repricing headroom [EP-INFLIGHT].
23. Every non-standard adapter event carries `uint16 schemaVersion` as
    its leading declaration field and at most three indexed parameters,
    and the golden event tests match the catalog rows to these homes
    exactly [EP-EVENTS] (ADR 0013 decision U7).

VRF tests:

1. VRF request uses current config.
2. VRF request emits request key, request ID, subscription, key hash, request
   confirmations, callback gas limit, and number of words.
3. VRF callback compresses returned words deterministically.
4. VRF callback calls coordinator with request key and raw randomness.
5. VRF config updates are admin-only, execute as canonical ADR 0004
   governance actions, and are evented with the authorizing `actionId`;
   a `callbackGasLimit` change additionally emits the canonical GGP
   family event bound to the same action ID ([LTA-GGP] requirement 4;
   ADR 0014 decision V6).
6. Existing requests retain request-time provenance after config updates.
7. Wrong-epoch callback path is rejected by the coordinator and remains
   auditable in adapter events.
8. A VRF callback whose coordinator delivery reverts persists the result,
   does not revert the VRF coordinator frame, and a later
   `retryCoordinatorFulfillment` delivers the identical randomness
   [EP-CALLBACK].
9. `callbackGasLimit` covers the measured fulfillment envelope with the
   published margin; an artificially undersized limit proves store-first
   persistence still holds and delivery is retryable [EP-VRF-CONFIG].
10. In-flight discipline [EP-INFLIGHT]: a request submitted before a
    `callbackGasLimit` raise executes under its submitted limit; an
    induced coordinator-frame failure persists the result and remains
    retryable; a simulated frame-level loss leaves the adapter with no
    result, the result-status read reporting `rawRandomnessReceived = false`, and
    coordinator fresh recovery blocked by the [EC-INCIDENT] rule 3
    evidence requirements.
11. The callback-gas sizing fixture reproduces the published fulfillment
    envelope within the recorded tolerance. ABI/source goldens prove it does
    not authorize a mutation and no lower/probe surface exists
    ([LTA-GGP], [EP-VRF-CONFIG], ADR 0017).
12. The adapter's subscription-ID typing matches the bound upstream
    coordinator version — `uint256` for the recommended v2.5 reference
    shape — and integration tests request and receive against that
    upstream interface (ADR 0013 decision U7).

ARRNG tests:

1. ARRNG request uses current payment config.
2. ARRNG request emits request key, request ID, and payment.
3. ARRNG callback compresses returned payload deterministically.
4. ARRNG callback calls coordinator with request key and raw randomness.
5. Payment updates are admin-only, evented, and leave the provider config
   hash unchanged [EP-CONFIGHASH].
6. Excess payment is rejected at the adapter boundary; caller overpayment
   is absorbed by the coordinator fee binding and never reaches the
   adapter [EP-QUOTE].
7. Withdrawal path is admin-only, evented, and pays only the governed
   destination [EP-CUSTODY].
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
5. Fee quote, exact payment at the adapter boundary, excess rejection,
   upstream fee drift absorption through the coordinator fee binding, and
   failed request behavior match [EP-QUOTE] and [EC-FEEBIND].

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
6. Configuration is rejected for collections that do not declare
   `EntropySecurityClass.LOW_SECURITY`, and the timing-grinding disclosure
   is present in provider metadata and provenance notes
   [EP-INSTANT-TIMING].

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

## Genesis Recommendation

Build `StreamEntropyProviderVRF` first and make it the default provider for
collections whose art depends on entropy.

Build `StreamEntropyProviderMock` for tests.

The fallback requirement is decided (ADR 0009 decision 21): genesis ships
dual providers — VRF primary plus one reviewed fallback — and a VRF-only
deployment is not conformant. Before production deployment, build and
review exactly one fallback provider:

1. `StreamEntropyProviderARRNG` as the preferred lower-complexity fallback
   provider.
2. Or `StreamEntropyProviderPyth` as the reviewed alternate, if its fee,
   callback, liveness, and audit requirements are accepted.

If neither fallback review completes, deployment blocks. Retain the
`StreamEntropyLaunchDecision` manifest recording which fallback shipped, its
review evidence, and the coordinator failure posture; it is the release
artifact for that choice and must be covered by the release manifest,
release-candidate lockfile, and checksum bundle once a release candidate
chooses a mode. The coordinator may use only the reviewed fallback provider
and policy hash recorded in the manifest; an unavailable provider must never
be silently substituted with another source.

Track drand, Randcast, Supra, Witnet, and API3 QRNG as extension adapter
candidates, each requiring a separate accepted spec before production use. The
best 50-year posture is not to guess the permanent winner now, but to keep
`StreamCore` stable and add provider adapters as the market matures.

Do not ship a multi-source mixer as the default. It is promising for exceptional
collections, but it creates liveness and selective-abort complexity.

Do not ship `StreamEntropyProviderInstant` as a default genesis provider. If it
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
