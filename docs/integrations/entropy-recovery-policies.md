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

Policy registration is implemented independently of collection binding and fresh
requests. Current collection policies still expose the existing no-fresh-recovery
profile. Creating or freezing a policy cannot alter them, migrate a provider,
request randomness or change a finalized seed. Remaining implementation includes
pre-mint collection binding and its finality commitment, ordered recovery
execution with live timing/provider checks, token and scope incident linkage,
artist redraw consent/finding, and late-original callback arbitration. Policy
configuration alone does not establish acceptance of that remaining state machine.

The focused unit suite passes all nine policy cases plus 27 original provider,
epoch and subject cases, including three 256-input properties with seed
`0x6529`. The native run captures 59 exact source units; all nine production
products fit, with coordinator runtime 24,141 bytes and creation 28,501 bytes.
The unchanged collection-configuration path now uses a fixed worker to retain
deployment headroom. All original 162 ABI entries are retained.

The unit suite uses the actual coordinator and policy worker with
explicit Core/provider/governance-context fixtures, including actual threshold
Safe calls, independent hash/event assertions, irreversible freeze, changed
preimage/order, malformed authority replies and replay rejection. Current Executor composition, maximum-step gas and full-graph sizes remain
pending against their exact captured source.
