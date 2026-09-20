# Entropy coordinator continuity and ordinary backup

This profile implements the pending-request exception in
[Coordinator Replacement And State Continuity](../stream-entropy-coordinator.md#coordinator-replacement-and-state-continuity).
It retains original request records, entropy domains, fulfillment and refund
ownership. It does not migrate existing subjects to the new coordinator.

## Replacement policy

The original `FreshRecoveryPolicy` and `FreshRecoveryStep` tuples, V1 hash and
selectors are unchanged. A V1 policy never grants permission to replace a
coordinator while requests remain pending.

The additive `IStreamEntropyCoordinatorContinuity` interface provides:

| Method | Purpose |
| --- | --- |
| `configureFreshRecoveryPolicyV2(id, attempts, role, reason, manifest, steps, successor, successorCodeHash)` | Class-1 governed definition of all original recovery terms and one exact successor/runtime. |
| `freshRecoveryPolicyV2Transition(id, proposedHash)` | Original governance transition fields for that new configure selector. |
| `coordinatorReplacementTerms(id)` | Retained target, runtime and complete policy hash. Zero target denotes no replacement permission. |
| `uncoveredPendingRequestCount(successor, successorCodeHash)` | Constant-time count of pending requests without frozen permission for this exact replacement. |

Let `originalHash` be the unchanged original V1 policy hash, including every
ordered recovery step. The V2 policy hash is exactly:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V2"),
    block.chainid, address(coordinator), address(core), policyId,
    originalHash, successor, successorCodeHash
))
```

The target must be a distinct deployed contract with that runtime and the same
Core and governance authority. The original freeze operation then freezes the
complete V2 policy. The original collection binding operation requires the
policy to be frozen, validates the ordered provider epochs and commits its
complete hash before collection locking. A frozen V1 policy cannot acquire a
replacement extension. Replacing an unfrozen definition with V1 explicitly
removes any unfrozen V2 target.

`FreshRecoveryCoordinatorReplacement` emits the exact additional terms.
Original policy definition, action, freeze and collection-binding events remain.
The new namespace is internal to the coordinator; no external registry can
manufacture pending coverage.

## Pending accounting and Core admission

Every successful request captures its collection's already-frozen replacement
target key. Token and scope requests, including authorized fresh requests,
participate in the same accounting. Uncovered requests remain counted globally.
Provider rejection or reentry rolls back both original and coverage counters.
Finalization and every terminal transition retire coverage once. A permitted
late-original result retires the active successor request's captured coverage,
even though original finalization changes the subject's current request key.

A live Core entropy-pointer replacement requires all of the following at
execution, including after a saved governance plan was scheduled:

1. Both original and candidate code match their runtime pins.
2. Exact 32-byte `core()` responses identify this Core on both contracts.
3. The original coordinator returns an exact 32-byte zero uncovered count for
   the selected candidate address and runtime.

Malformed, missing, reverting and nonzero responses fail closed. A historical
coordinator without the new read is not implicitly admitted by a missing-read
fallback. This is a new-deployment protocol profile, not a storage upgrade of an
already deployed coordinator.

Core uses its existing governed `ENTROPY_REGISTRATION_GAS_LIMIT` for each of
these entropy lifecycle reads as well as original registration. The original
full-forwarding/EIP-150 sufficiency check and completion buffer apply before
each call. The value remains raisable through the existing GGP authority/delay
mechanism; the constructor retains exactly its original four gas rows. No
caller-supplied cap or new fixed recovery gas ceiling is introduced.

Only new token registrations select the new current coordinator. Core's
`coordinatorAtMint`, old request/provider identity, token and scope seeds,
recovery journals and balances stay on their original hosts. Existing scopes
may finish or request entropy on their original host after cutover. A new
scope requires the host to be Core's current pinned entropy coordinator.
Original token hooks retain only-Core and actual `coordinatorAtMint` checks.

## Configured ordinary fallback

`DeployCurrentEntropyFallback.s.sol` deploys a distinct ordinary
`StreamEntropyCoordinator` with the same Core, authority and canonical role
registry. It does not select or register it. This is the supported ordinary
backup profile for the genesis `ENTROPY_COORDINATOR_FALLBACK` instance; it is not
a cheaper registration-only safe-mode implementation.

`StreamEntropyFallbackPlan` supplies the domain-specific assembly:

1. `deploymentConfig` and `requirePair` bind the distinct instances to the same
   foundation.
2. `registration` creates the original class-1 ACTIVE catalog intent.
3. The existing provider lifecycle plan admits the exact backup provider.
   `configureCollection` supplies each original governed collection tuple;
   `revealConfiguration` supplies the direct call by the actual current
   `ROLE_ENTROPY_ADMIN`. It does not impersonate that role through the Executor.
4. `selection` builds the original class-3 Core pointer intent. Both
   registration and selection must be completed with `withManifestTail`, the
   caller's retained payload and exact `StreamSystemManifestUpdate`. This uses
   the original mandatory publication call and no new manifest authority.
5. `StreamGovernanceStagePlan` publishes, schedules and executes the complete
   saved batch under the actual canonical governor, including a threshold Safe.

The `checkpoint` reader checks sorted supplied collection rows, exact configured
provider/salt/public/timeout terms, declared reveal policy, and ACTIVE pinned
backup providers. Its manifest binds both coordinators and runtime hashes,
foundation, backup deployment manifest, supplied collection inventory and an
external historical-subjects manifest hash. It does not prove the caller's
inventory complete. Genesis composition must independently enumerate all
required collections and original token/scope subjects, retain the bytes and
include the checkpoint in its deployment evidence.

## Verification boundary

`StreamEntropyContinuity.t.sol` uses actual coordinator workers and official
threshold Safe execution with explicit typed Core, Artist, role and provider
boundaries. It covers mixed token/scope coverage, original V1 hashing,
immutable frozen terms, wrong runtime/Core, provider rollback, late-original
fulfillment, old-scope continuity and identical Safe retry.

The focused native capture passed all eight continuity cases plus three Core
read controls (including 256 exact-zero fuzz runs). The ten existing subject
identity cases also passed from the same compiled capture. The first capture's
Safe fixture failure is retained: an expected-revert marker intercepted the
helper's nonce read, corrected by an external test wrapper around execution.
The Core read controls independently reject missing, overlong, reverting and
foreign-Core replies, and prove an insufficient parent budget cannot turn a
reduced-gas read into permission to replace.

`StreamCurrentEntropyContinuity.t.sol` authors actual
Core/Manager/Ledger/Artist/Registry/Executor/threshold-Safe flows with mock
upstream randomness: paid mints on both sides, mixed covered requests, saved
plan delay, new pending work after schedule, runtime drift, unchanged original
seed/URI and exact plan retry. These current-graph recipes require coordinated
native execution; ABI acceptance alone does not demonstrate them.

The existing V1 host ABI and ordinary storage prefix must remain unchanged.
New mapping state is appended to the original policy namespace or lives in
the separate compiler-declared continuity namespace. Fixed registration and
configuration workers retain original caller checks, typed storage references,
events and write order. Selected product sizing must include every changed
host and worker; aggregate test limits are not production deployment limits.
The selected Solidity 0.8.19 via-IR/200-runs/Paris capture measures Coordinator
at 24,079 runtime bytes and 28,439 creation bytes, Core at 19,638/23,076, and all
six affected fixed workers below both limits. This is source-specific selected
capacity evidence, not a refreshed genesis artifact set. Core and Coordinator
retain all 304 original ABI entries and their original ordinary storage layout.
