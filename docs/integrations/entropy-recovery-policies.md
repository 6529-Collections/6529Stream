# Frozen entropy recovery policies

`IStreamEntropyRecoveryPolicies` is an additive capability of the current
coordinator. It implements the original ordered `FreshRecoveryStep` and
`FreshRecoveryPolicy` configuration and irreversible freeze. The policy hash
uses the exact original `FRESH_RECOVERY_STEPS_DOMAIN` and
`FRESH_RECOVERY_POLICY_DOMAIN` recipes in the [entropy specification](../stream-entropy-coordinator.md#storage-model).
Every step, including provider epoch/config, delay floor and late-original
fulfillment choice, is retained onchain and emitted in its original order.

Configuration and freeze each require an exact class-1 executing governance
call. `freshRecoveryPolicyTransition` gives the call-level scope/old/new hashes;
use the existing governance batch planner to aggregate these before scheduling.
Execution rehashes the actual configuration, binds the current revision and
pinned authority runtime, and rejects a previously consumed policy/action pair.
A frozen ID cannot be edited or frozen again. Use a new ID for changed policy.
The original configured/frozen events remain intact; definition and action
companions make the full preimage and authorizing action reconstructible.

This implementation admits one to 32 ordered steps, with a positive maximum
attempt count no greater than the number of steps. Every step names an admitted
active provider, a nonzero provider epoch/config hash and a positive declared
block delay. Provider configurations may describe a future fallback epoch;
execution must independently validate their actual availability and identity.
The incident authority is the original `ROLE_ENTROPY_INCIDENT_DECLARER` role
identifier. A holder address is never frozen into a policy. Actual holder
resolution belongs to incident/recovery execution.

## Bind a collection before minting

`IStreamEntropyCollectionRecovery` adds the collection binding without changing
original collection storage or the existing `configureCollection` signature.
First configure a collection and freeze a recovery policy, then obtain
`collectionFreshRecoveryTransition(collectionId, attempts, policyId)` and
schedule its exact class-1 governance call to
`configureCollectionFreshRecovery`. Use the ordinary batch planner for a batch
rather than treating the call-level hashes as aggregate governance hashes.

A positive attempt count cannot exceed the frozen policy's maximum or step
count. Selected fallback epochs must be strictly increasing and greater than
the collection epoch after the binding update. Each selected provider must be
active with its pinned runtime at binding time. Execution must check live
provider eligibility again. Changing the binding increments the collection
provider epoch, stores the frozen hash and authorizing action, and emits both
binding and original epoch events. `collectionFreshRecovery` returns the full
binding, revision and last action ID.

Before minting, an exact governed `(attempts = 0, policyId = 0)` call can detach
a binding. No-op changes and reused collection/action pairs fail. The first
token or entropy-scope registration locks the configuration; a Core collection
freeze also blocks binding changes. Ordinary pre-mint provider changes cannot
overtake a selected fallback epoch.

Unbound collections retain their original finality-policy commitment exactly.
A positive binding uses the `6529STREAM_ENTROPY_FINALITY_FRESH_POLICY_V1` domain
and commits to the original provider/reveal policies plus the frozen policy ID,
hash and maximum attempts. It therefore discloses the configured fallback to
finality consumers. Registration, freeze and binding do not request randomness,
migrate an existing request or change a finalized seed.

## Execution and validation boundary

The additive [fresh-request implementation](entropy-fresh-recovery.md) now
covers ordered token/scope requests, live timing/provider checks, incident
linkage, original Artist consent and late-original callback arbitration.
Its focused runtime acceptance is tracked separately. The entropy-specific
unavailability finding and complete current-stack composition remain required.
Configuration alone does not establish acceptance of that state machine.

The focused unit suite passes eight collection-binding cases, nine policy
cases and 27 original provider/epoch/subject cases: 44 total. Three properties
each pass 256 inputs with seed `0x6529`. The native run captures 62 exact source
units; all ten production products fit, with coordinator runtime 24,553 bytes
and creation 28,934 bytes. Moving the new transition's encoding into the fixed
read worker resolves the first run's 24,739-byte runtime while retaining all
prior coordinator ABI entries and original collection storage.

The unit suite uses the actual coordinator and policy worker with
explicit Core/provider/governance-context fixtures, including actual threshold
Safe calls, independent hash/event assertions, irreversible freeze, changed
preimage/order, malformed authority replies and replay rejection. Current Executor composition, maximum-step gas and full-graph sizes remain
pending against their exact captured source.
