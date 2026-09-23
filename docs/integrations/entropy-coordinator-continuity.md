# Entropy coordinator continuity and ordinary backup

This profile implements the pending-request exception in
[Coordinator Replacement And State Continuity](../stream-entropy-coordinator.md#coordinator-replacement-and-state-continuity).
It retains original request records, entropy domains, fulfillment and refund
ownership. It does not migrate existing subjects to the new coordinator.

The current Core also requires complete collection-policy import evidence
([ADR0052](../adr/0052-entropy-policy-succession.md)). The pending-request layer
below is necessary but no longer sufficient for replacement. Exact legacy and
explicit imports, original-provider relay and their atomic activation plan are
being completed; manual backup configuration alone does not satisfy that gate.

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
4. Its direct `entropyPolicyInventory()` returns exactly 96 bytes: full-width
   count, canonical uint64 mutation serial and ordered collection-ID digest.
5. The candidate's `entropyPolicyImportReady` returns exactly the canonical
   32-byte true word for that source/runtime, current pointer revision and all
   three header fields. Even an empty inventory requires authenticated readiness.

Readiness binds a complete SEALED import. The same class-3 governed batch must
replace the Core pointer and activate that import at the incremented revision;
a later activation failure rolls the batch back. Missing export/readiness
interfaces refuse replacement; old finalized reads remain on their original host.

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

`StreamEntropyFallbackPlan` retains the earlier domain-specific assembly below.
Its manually configured candidate/checkpoint does not prove complete policy
import and is not sufficient for the current Core replacement gate. The new
import/relay activation plan must replace that manual cutover path; do not treat
the retained historical recipe as executable current-source acceptance.

The earlier assembly is:

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

The current complete-policy Core gate (`4b6e05ea`) passes eight focused read
controls, including two256-input fuzz properties, on a60-source capture.
All16 nonempty production products fit; Core is19,630/23,068 runtime/init bytes.
The controls use typed source/candidate fault boundaries and do not execute the
real import/relay or an actual governed pointer/activation batch. The earlier
captures below retain their original source and simpler admission boundary.

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

### Current registration value and floor evidence

`StreamEntropyRegistrationCap.t.sol` runs the actual Core mutation and actual
Coordinator registration with the four rows from `StreamCurrentStackPlan`.
The entropy row is value **500,000**, floor **120,000**, failure class **2**;
the constructor initializes revision **1**. The final `2` in that deployment
tuple is not a revision. The Core test subclass adds only original worker
views. Registry, Manager, governance, role registry and provider remain explicit
typed boundaries, so this is not the complete current graph.

All three focused cases pass: cold first registration at the current value,
late receiver rejection with complete Core/Coordinator rollback and identical
mint retry, and fail-closed registration at a separately deployed 120,000
value. Cooling names Core, Coordinator, Manager, Registry, the registration
worker and the Core read worker and their storage. Core's mint naturally warms
the token identity and original coordinator cells before calling the hook.

The cached trace measures **131,789 gas** in `onTokenMinted` in each successful
hook frame, including the hook preceding receiver rejection. The first Core
mint frame uses **393,262 gas**, and its typed Manager frame uses **395,021**.
These are execution-frame measurements, not full transaction gas including
intrinsic costs, and the cooling declaration is not a claim of a complete
transitive genesis benchmark.

Earlier probes incorrectly required success at the minimum permitted value.
Both the original pre-extraction Coordinator and the continuity Coordinator
failed that 120,000-value probe before reaching the receiver. Those failing
captures remain evidence; they do not establish a continuity regression.
The final positive run restores the exact reviewed entropy production and
includes Core's separate monotone prepared-abort correction.

This positive integration result does **not** validate the release floor.
EC-REGGAS rule 2 requires at least four times measured all-cold genesis hook
cost and a genesis value at least that floor. Four times this observed frame
cost is **527,156**, already above both the current floor and current value.
Final genesis configuration requires its own complete cold benchmark and a
new compliant floor/value profile. This test changes no deployment settings,
governed policy or transaction cap.
