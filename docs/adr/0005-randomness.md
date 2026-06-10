# ADR 0005: Randomness

## Status

Accepted.

## Metadata

| Field | Value |
| --- | --- |
| Date | 2026-06-10 |
| Issue | [P0-RAND-ADR](https://github.com/6529-Collections/6529Stream/issues/14) |
| Blocks | [P0-RAND-001](https://github.com/6529-Collections/6529Stream/issues/37), [P0-RAND-002](https://github.com/6529-Collections/6529Stream/issues/38), [P0-RAND-003](https://github.com/6529-Collections/6529Stream/issues/39), [P0-RAND-004](https://github.com/6529-Collections/6529Stream/issues/40), [P0-RAND-005](https://github.com/6529-Collections/6529Stream/issues/41), [P0-RAND-006](https://github.com/6529-Collections/6529Stream/issues/42), [P0-RAND-007](https://github.com/6529-Collections/6529Stream/issues/43) |
| Related issues | [P0-PAY-007](https://github.com/6529-Collections/6529Stream/issues/31), [P0-PAY-008](https://github.com/6529-Collections/6529Stream/issues/8), [P0-META-001](https://github.com/6529-Collections/6529Stream/issues/9) |
| Related ADRs | [ADR 0001](0001-drop-authorization.md), [ADR 0002](0002-auction-custody.md), [ADR 0003](0003-payment-accounting.md), [ADR 0004](0004-admin-governance.md), ADR 0006 |
| Affected contracts | `smart-contracts/StreamCore.sol`, `smart-contracts/RandomizerVRF.sol`, `smart-contracts/RandomizerRNG.sol`, `smart-contracts/RandomizerNXT.sol`, `smart-contracts/XRandoms.sol`, `smart-contracts/IRandomizer.sol`, `smart-contracts/IArrngController.sol`, `smart-contracts/ArrngConsumer.sol` |
| Work type | `DESIGN` |

## Problem

6529Stream mints generative tokens whose final token hash affects metadata and
art output. That hash must not be miner/manipulator-controlled, silently
rewriteable, or ambiguous during provider outages.

Before public beta, the protocol needs to decide:

- which randomness providers are production-eligible
- how requests are recorded and exposed
- how callbacks prove request, token, collection, provider, and provider epoch
- how stale callbacks behave after provider replacement
- how pending, fulfilled, stale, and failed randomness states appear in metadata
- how retries work without changing the random output
- whether raw random words, derived seeds, or both are stored
- how provider costs, refunds, reserves, and emergency withdrawals interact
- how weak block-derived helper contracts are removed or scoped out of
  production

## Current Behavior

Current source references:

- `smart-contracts/StreamCore.sol#_mintProcessing` stores `tokenData`, maps the
  token to a collection, mints the token, and calls the configured collection
  randomizer.
- `_safeMint` runs before `calculateTokenHash`, so receiver callbacks and
  indexers can observe a minted token while the token hash is still zero.
- `smart-contracts/StreamCore.sol#setTokenHash` allows only the collection's
  current `randomizerContract` to set a token hash, and only when the token hash
  is still zero.
- `smart-contracts/StreamCore.sol#tokenURI` returns the off-chain `pending`
  URI while `tokenToHash[tokenId]` is zero and the token uses off-chain
  metadata.
- On-chain metadata does not have an explicit pending state; it embeds the zero
  hash directly in the generated script while randomness is pending.
- `smart-contracts/RandomizerVRF.sol` stores
  `tokenToRequest`, `requestToToken`, and `tokenIdToCollection`, then writes a
  token hash from `fulfillRandomWords`.
- `smart-contracts/RandomizerRNG.sol` has a similar request-to-token mapping
  and sends ETH to the arRNG controller from the randomizer adapter.
- `smart-contracts/RandomizerRNG.sol#emergencyWithdraw` sweeps the adapter
  balance to `adminsContract.owner()`, which conflicts with ADR 0003 unless
  randomness reserves and refunds are excluded from surplus.
- `smart-contracts/RandomizerNXT.sol` synchronously derives a hash from
  `blockhash(block.number - 1)` and `XRandoms`.
- `smart-contracts/XRandoms.sol` derives helper values from `block.prevrandao`,
  recent block hash, and timestamp. Slither reports these as high-impact
  `weak-prng` findings.
- There is no collection-level randomizer epoch, terminal request state, stale
  callback policy, callback-after-burn policy, explicit post-processing failure
  state, or provider migration model.

The current one-time `tokenToHash` guard is useful, but it is not enough for
production. It prevents direct overwrites through the current randomizer path,
but it does not prove that a callback belongs to the correct live request and
provider epoch.

Current implementation status:

- `StreamCore` exposes the current collection randomizer and a monotonic
  randomizer epoch that increments on `addRandomizer`.
- `RandomizerVRF` and `RandomizerRNG` record provider request lifecycle data
  and validate request ID, the core token-to-collection binding, provider, and
  randomizer epoch before writing a derived seed.
- Lifecycle-aware randomizer adapters expose per-collection and total pending
  request counts. `StreamCore.addRandomizer` blocks ordinary provider migration
  while the current lifecycle-aware provider reports pending requests.
- VRF and arRNG adapters catch deterministic `setTokenHash` post-processing
  failures after provider output is validated, mark the request
  `FailedPostProcessing`, store the derived seed and failure-data hash, and
  clear pending counts without requesting new randomness.
- VRF and arRNG adapters expose an admin-gated
  `retryRandomnessPostProcessing` path that retries only deterministic core
  writes for `FailedPostProcessing` requests, reuses the stored derived seed,
  emits retry-specific success/failure events, refreshes fulfillment timing on
  success, and caps attempts at `MAX_RANDOMNESS_POST_PROCESSING_RETRIES`.
- `RandomizerRNG` guards the arRNG request-submission window where the provider
  request ID is returned from an external payable call, and tests prove a
  reentrant controller cannot fulfill during that window.
- VRF and arRNG adapters store `rawOutputHash =
  keccak256(abi.encode(randomWords))` for each accepted fulfillment. They do not
  store full provider word arrays in contract storage.
- The derived seed includes `RANDOMNESS_SEED_TYPEHASH`, provider adapter,
  provider request ID, collection, token, randomizer epoch, and the stored
  raw-output hash via `abi.encode`.
- VRF and arRNG adapters both emit provider-specific `RequestFulfilled` events
  with the raw provider words for off-chain auditability; contract state remains
  hash-only.
- `RandomizerNXT` no longer advertises itself as a production randomizer.
- Remaining implementation work includes callback-after-burn policy, richer
  metadata state exposure, provider configuration events/runbooks, canonical
  core/coordinator-owned lifecycle state, and final handling of `XRandoms` weak
  helper randomness.

## Decision

6529Stream will use asynchronous, provider-backed randomness with an explicit
request lifecycle for production drops.

The public-beta target design is:

1. Production collections must use a provider-backed async randomizer adapter.
2. A Chainlink VRF-compatible adapter is the preferred production default.
3. The arRNG adapter may be production-eligible only if it satisfies the same
   request lifecycle, callback validation, accounting, event, and monitoring
   requirements.
4. `RandomizerNXT` and `XRandoms` block-derived helper randomness are not
   production-eligible. They must be removed from production deployment paths or
   isolated as test, demo, or legacy-only code before Gate C.
5. `StreamCore` or a dedicated first-party randomness coordinator must own the
   canonical request state. Provider adapters may keep provider-specific
   mappings, but protocol correctness cannot depend only on adapter-private
   state.
6. Every randomness request is bound to the collection, token, provider,
   provider request ID, randomizer epoch, and immutable request-time inputs.
7. Fulfillment validates request ID, token, collection, provider, and
   randomizer epoch before any final token hash or seed is written.
8. Fulfillment is terminal. A token cannot receive a second random output after
   the first valid fulfillment.
9. Provider migration increments a collection-level randomizer epoch.
10. Pending requests from an old provider or epoch cannot be silently fulfilled
    as if they came from the new provider.
11. Retrying is allowed only for deterministic post-processing after random
    output already exists. Retrying must not request a different random output.
12. Randomness fulfillment should not be broadly paused in normal incident
    response. ADR 0004's pause model blocks new randomness requests; fulfillment
    safety comes from request validation.

## Request Lifecycle

The implementation may choose exact enum names, but public-beta behavior must
preserve these states or stricter equivalents.

| State | Meaning | Terminal |
| --- | --- | --- |
| `None` | No randomness request exists for the token | No |
| `Pending` | A provider request was submitted and no valid output has been accepted | No |
| `Fulfilled` | A valid provider callback produced the final seed/hash | Yes |
| `Stale` | The request belongs to a provider or epoch no longer eligible to fulfill | Yes, unless an explicit governance recovery issue defines otherwise |
| `FailedPostProcessing` | Provider output exists, but deterministic local processing failed | No |

The request record must store or expose enough data for tests, indexers,
runbooks, and audits:

- collection ID
- token ID
- provider adapter address
- provider request ID
- randomizer epoch
- request state
- requested block and timestamp
- fulfilled block and timestamp when fulfilled
- random output hash or derived seed
- post-processing failure-data hash when applicable

The request record must not be keyed only by token ID if a provider can return
request IDs. The protocol must be able to answer "which exact request fulfilled
this token" and "which token did this request belong to."

## Callback Validation

Every fulfillment path must validate:

- the caller is the expected provider adapter or provider coordinator path
- the request ID exists
- the request is `Pending` or `FailedPostProcessing` according to the retry path
- the request's token ID matches the callback token
- the request's collection ID matches the callback collection
- the request's provider adapter matches the stored provider
- the request's randomizer epoch matches the stored epoch
- the token is not already fulfilled
- the token exists or follows the explicitly documented burned-token callback
  path
- the token still belongs to the recorded collection when it is not burned
- the provider output is non-empty according to the provider contract
- the derived seed/hash is nonzero

The implementation must reject:

- unknown request IDs
- duplicate fulfillments
- callbacks from replaced providers
- callbacks from stale epochs
- callbacks for the wrong token or collection
- callbacks that attempt to overwrite a final seed/hash
- malformed provider output
- zero derived seed/hash values

Security-relevant failures should use custom errors so tests can assert the
specific reason.

## Provider Model

### Chainlink VRF-Compatible Adapter

The VRF-compatible adapter is the preferred public-beta provider because the
existing code already has a VRF path and because it is the clearest model for
request IDs, callback origin, confirmations, and provider-specific operational
runbooks.

The production adapter must:

- request randomness only when called by the core/coordinator
- bind the provider request ID to the protocol request record
- keep provider config changes behind ADR 0004 roles
- emit config-change events for key hash, subscription, confirmations, callback
  gas limit, and word count changes
- expose views for the active provider configuration
- fail closed on unknown, stale, duplicate, or mismatched callbacks

### arRNG Adapter

The arRNG adapter may remain as a supported provider only if it meets the same
security and accounting bar as the VRF-compatible adapter.

The production adapter must:

- record the arRNG request ID in the canonical lifecycle
- bind request fees and refunds to ADR 0003 randomness reserve accounting
- expose `ethRequired` or equivalent provider cost data
- treat refunds received by the adapter as reserve or surplus according to ADR
  0003, not as sweepable untracked balance
- avoid `tx.origin` refund assumptions when using provider APIs
- use bounded emergency withdrawal semantics from ADR 0003 and ADR 0004

### Block-Derived Helper Randomness

`RandomizerNXT` and `XRandoms` are out of production scope.

Before Gate C, the implementation must choose one of these resolutions:

- remove the weak helper path from production builds and deployment manifests
- move it to test/demo-only scope where Slither baseline and docs make that
  boundary explicit
- keep it as legacy read-only/example code that cannot pass
  `isRandomizerContract()` in production deployments

No production deployment manifest may configure a collection to use
`RandomizerNXT` or `XRandoms` as a live randomizer.

## Randomizer Epoch And Migration

Each collection must have a monotonic `randomizerEpoch` or equivalent versioned
provider configuration. The epoch increments whenever:

- the collection randomizer adapter changes
- provider-critical config changes in a way that affects callbacks
- governance explicitly marks pending requests stale during an incident

Migration rules:

1. New requests use the current provider and epoch.
2. Existing pending requests remain bound to the provider and epoch recorded at
   request time.
3. A callback from an old provider or epoch must not fulfill a request after the
   request was marked `Stale`.
4. Provider migration with pending requests should be blocked by default.
5. If emergency migration with pending requests is allowed, it must require an
   explicit governance action, mark affected requests `Stale`, emit events, and
   leave indexers able to explain why affected tokens remain pending or stale.
6. Re-requesting randomness for the same token is out of scope for P0 after a
   provider accepted a request, unless a later issue proves an unbiased recovery
   mechanism before implementation.

This deliberately favors stuck-but-honest states over the ability to redraw a
random output after users can observe a mint.

Current implementation status for `P0-RAND-005`: ordinary provider migration is
blocked while the current lifecycle-aware adapter reports pending requests for
the collection. Pending counts decrement only when a request reaches a terminal
`Fulfilled` or `Stale` state. Explicit admin stale marking is the current
emergency path that makes the pending state observable before provider
migration; automatic bulk stale marking and redraw/re-request behavior remain
out of scope.

## Seed And Storage Policy

P0 implementation stores a canonical derived seed/hash and a canonical hash of
the raw provider output. It does not store full provider word arrays as
unstructured implementation detail.

The derived value should be domain-separated from provider internals and include
at least:

- provider adapter
- provider request ID
- collection ID
- token ID
- randomizer epoch
- hash of raw provider output

Recommended shape:

```solidity
keccak256(
    abi.encode(
        RANDOMNESS_SEED_TYPEHASH,
        provider,
        requestId,
        collectionId,
        tokenId,
        randomizerEpoch,
        keccak256(abi.encode(rawWords))
    )
)
```

The implementation may also emit raw provider words in a provider-specific
event if gas and privacy considerations are accepted. The canonical contract
state exposes the derived seed/hash and the raw-output hash.

## Metadata And Request-Time Inputs

Randomness must not depend on mutable user-significant inputs changed after the
request is submitted.

P0 implementation must either:

- keep seed derivation independent from mutable metadata and token data, or
- store a request-time hash of every user-significant input included in final
  rendering.

Because `StreamCore` currently allows mutable token data until collection
freeze, ADR 0006 must decide the final metadata/freeze model. Until then,
randomness implementation must not include mutable `tokenData`, image,
attribute, dependency, or collection metadata values in seed derivation unless
their request-time hashes are recorded and verified.

Off-chain metadata may continue to expose a pending URI while randomness is
pending. On-chain metadata must also have an explicit pending/final policy so it
does not silently present a zero hash as final art data. Pending/final behavior
must be based on explicit request state, not only on whether
`tokenToHash[tokenId] == 0`.

## Burned Tokens

A callback after burn must not resurrect a token, change ownership, or corrupt
collection supply.

P0 implementation may either:

- accept and record a valid fulfillment for an already burned token for audit
  traceability, while leaving ERC-721 ownership and tokenURI behavior burned; or
- reject or mark the callback stale with an explicit event.

The chosen implementation must be documented and tested. Silent success that
changes hidden state without an event is not acceptable.

## Payment And Reserve Accounting

Provider fees, refunds, and adapter balances are payment-accounting concerns.
They must follow ADR 0003 and ADR 0004.

Required rules:

- randomness provider prepayments are reserved balances, not surplus
- provider refunds received by adapters are credited to the appropriate
  randomness reserve or protocol surplus category according to ADR 0003
- emergency withdrawal cannot sweep randomness reserves or pending provider
  refunds owed to the protocol
- provider-cost updates are protected by ADR 0004 roles
- provider-cost changes emit events with enough indexed fields for monitoring

## Events And Views

The randomness system must be observable.

Required events or stricter equivalents:

- `RandomizerProviderUpdated(collectionId, oldProvider, newProvider, oldEpoch, newEpoch, admin)`
- `RandomizerEpochIncremented(collectionId, oldEpoch, newEpoch, reason, admin)`
- `RandomnessRequested(collectionId, tokenId, provider, requestId, epoch)`
- `RandomnessFulfilled(collectionId, tokenId, provider, requestId, epoch, seed, rawOutputHash)`
- `RandomnessStale(collectionId, tokenId, provider, requestId, epoch, reason)`
- `RandomnessPostProcessingFailed(requestId, collectionId, tokenId, provider, epoch, seed, rawOutputHash, failureDataHash)`
- `RandomnessPostProcessingRetried(requestId, collectionId, tokenId, provider, epoch, retryCount, seed, rawOutputHash)`
- `RandomnessPostProcessingRetryFailed(requestId, collectionId, tokenId, provider, epoch, retryCount, seed, rawOutputHash, failureDataHash)`
- `RandomizerProviderConfigUpdated(provider, field, oldValueHash, newValueHash, admin)`

Successful deterministic post-processing retries emit
`RandomnessPostProcessingRetried` followed by `RandomnessFulfilled` for the same
request ID. Indexers should treat that fulfillment event as retry success
confirmation, not as a second provider callback.

Required views or stricter equivalents:

- current collection randomizer provider
- current collection randomizer epoch
- request record by provider request ID
- request record by token ID
- request state by token ID
- derived seed/hash by token ID
- raw provider output hash by token ID, if fulfilled
- pending request count by collection, if practical
- provider configuration and cost views
- randomness reserve and surplus views where the adapter can hold ETH

## Implementation Requirements

P0 implementation must:

- add canonical request lifecycle storage
- add collection-level randomizer epoch/versioning
- route fulfillment through validation that binds request, token, collection,
  provider, and epoch
- reject unknown, stale, mismatched, duplicate, and overwrite callbacks
- replace zero-hash-only pending logic with explicit lifecycle state
- define the callback-after-burn behavior and test it
- add deterministic post-processing retry without requesting a new random
  output
- remove, isolate, or disable weak block-derived randomness for production
- align provider fee/refund balances with ADR 0003
- align provider config and migration controls with ADR 0004
- emit events for every external randomness state transition
- expose views needed by tests, docs, deployment checks, and indexers
- add custom errors for security-relevant failure paths

## Tests Required

P0 tests must include:

- characterization tests for current pending URI and one-time token-hash
  behavior before rewrites
- request lifecycle creation and views
- valid fulfillment from the configured provider
- wrong provider rejection
- wrong request ID rejection
- wrong token rejection
- wrong collection rejection
- stale epoch rejection
- duplicate fulfillment rejection
- unknown request rejection
- zero derived seed/hash rejection
- replaced provider callback rejection
- pending, fulfilled, stale, and failed post-processing metadata states for both
  off-chain and on-chain metadata
- provider migration with pending requests follows this ADR
- manual retry cannot change the random output
- callback after burn follows the documented behavior
- provider config updates require the right role and emit events
- randomness reserves are not emergency-withdrawable surplus
- weak helper contracts cannot be configured for production collections or are
  fully removed from production scope
- event assertions for request, fulfillment, stale, failure, retry, provider
  update, and epoch update events
- Slither `weak-prng` rows are fixed, scoped, or explicitly accepted with proof

## Migration And Rollout

1. Keep current characterization tests for pending metadata and one-time token
   hash writes.
2. Add issue-scoped tests for request lifecycle and callback validation.
3. Introduce canonical request state and views.
4. Add randomizer epoch handling and provider migration policy.
5. Update VRF-compatible and arRNG adapters to write through the canonical
   lifecycle.
6. Remove or isolate `RandomizerNXT` and `XRandoms` from production paths.
7. Update provider configuration docs, deployment manifests, and runbooks.
8. Update Slither baseline rows for `weak-prng` after code resolution.
9. Re-run `make check`, the Windows check wrapper, Slither, and deployment
   rehearsal before public beta.

## Alternatives Considered

### Keep Current Adapter-Local Mappings

Rejected. Adapter-local mappings help providers, but protocol correctness needs
canonical state that survives provider replacement, exposes request status, and
lets tests prove stale callbacks fail.

### Use Only Synchronous Block-Derived Randomness

Rejected for production. Recent block data and timestamps can be influenced and
are already flagged by Slither as `weak-prng`.

### Allow Re-Requesting Randomness For Stuck Tokens

Rejected for P0. Re-requesting after a provider accepted a request can create
selection and timing risk. P0 will prefer explicit pending/stale status and a
documented incident path unless a later design proves an unbiased recovery
mechanism.

### Pause All Fulfillment During Incidents

Rejected as the default. Broad fulfillment pauses can leave valid randomness
stuck and do not solve stale-callback ambiguity. New requests can be paused;
fulfillment safety should come from strict validation.

## Non-Goals

- Choosing final mainnet provider subscription IDs, funding amounts, or Safe
  addresses.
- Implementing code, tests, CI, deployment scripts, or runbooks in this ADR PR.
- Finalizing metadata freeze semantics. ADR 0006 owns the complete metadata
  freeze model.
- Defining a DAO or timelock governance process. ADR 0004 owns authority and
  pause controls.
- Proving provider liveness or provider SLA guarantees.

## Accepted Risks

- Tokens may remain pending or stale if a provider fails after accepting a
  request. This is safer than redrawing randomness without a proven unbiased
  process.
- P0 stores derived seed/hash state and a raw-output hash rather than full raw
  words. Provider-specific events and provider logs must preserve enough
  auditability for the chosen provider.
- arRNG support may be deferred if it cannot meet the same lifecycle,
  accounting, and monitoring requirements as the VRF-compatible path.
- Weak helper contracts may remain in the repository during transition if they
  are clearly outside production scope and cannot be configured for public-beta
  collections.

## Open Follow-Ups

- Define and test callback-after-burn behavior.
- Reconcile final metadata pending/freeze behavior with ADR 0006.
- Add provider configuration events and production runbooks.
- Update Slither baseline status after weak randomness code is removed, scoped,
  or otherwise resolved.
