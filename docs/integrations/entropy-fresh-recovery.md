# Fresh entropy recovery

`IStreamEntropyFreshRecovery` adds an exceptional fresh request for an existing
token or registered scope. It uses the same provider request/seed domains and
submission/custody path as the original request. First requests remain attempt
1; each successful recovery consumes the next frozen policy step and advances
the subject's request attempt. The collection's original policy remains fixed.

## Prepare and execute

1. Before registration, configure and freeze an ordered policy and attach it
   through [collection recovery binding](entropy-recovery-policies.md).
2. The current `ROLE_ENTROPY_INCIDENT_DECLARER` holder declares the active
   request unrecoverable, supplying the independent incident-evidence commitment.
3. Wait until the incident block plus the greater of the step's declared delay
   and the current governed recovery delay has passed.
4. Construct `RecoveryInput(oldRequestKey, reasonURI, providerEvidenceHash)` and
   call `freshRecoveryTransition`. The result is the exact next request key,
   proposed content-state hash and current provider quote. Preserve the supplied
   reason and evidence preimages for the evidence bundle.
5. For an Artist-bound collection, obtain original operation-17 content consent
   for the current entropy host, family
   `keccak256("6529STREAM_ENTROPY_RECOVERY_V1")`, and that proposed content-state
   hash. [Artist host evidence](../guides/artist-entropy-content-consent.md)
   retains the original signed tuple and current binding checks.
6. The live incident-role holder calls `requestFreshEntropy(input)`, optionally
   attaching ETH. The contract recomputes every admission fact and the provider
   quote. Token requests draw available collection reveal escrow first; scope
   requests use caller funding. Excess becomes the actual caller's pull credit.
   Safe callers use an ordinary CALL with the intended value.

The proof checks the coordinator's actual active FAILED request and absence of
a seed/result, the immutable incident, exact frozen policy/hash/order/attempt,
live provider runtime/configuration and delay, and a fresh bounded negative
provider-result probe. Any older request still eligible to win under the frozen
late-callback policy is probed again as well. Unavailable, malformed or positive
provider evidence rejects the new draw. A burned token cannot start recovery.

The selected Artist registry and its runtime/Core binding are checked directly.
A missing or failed attribution read is not an unbound collection. Only an
explicit all-zero unbound attribution bypasses Artist consent. Other states
require exact original host/content evidence, consumed once in the entropy
host. The unavailability-finding alternative still needs its entropy-specific
intent integration and remains unavailable in this implementation.

## State and evidence

`artistContentFamilyState` commits to the actual collection binding and stored
recovery journal head. Its initial supported state is nonzero. The proposed
state commits to the prior journal, exact old/new requests, immutable provider
snapshot, original inputs, independent evidence and reason. Successful recovery
stores that head, so the resulting family state equals the consented hash.
Another recovery in the collection changes the head and requires a fresh quote
and matching consent.

The original `EntropyRecoveryRequested` schema is preserved. Its evidence hash
uses `6529STREAM_ENTROPY_RECOVERY_EVIDENCE_V1` and `abi.encode` over the supplied
provider evidence hash, retained incident evidence hash, exact Artist record
(or zero for explicitly unbound attribution), old/new request keys, resulting
content state and reason hash. `EntropyRecoveryEvidence` emits those component
commitments and the scope ID. `freshRecoveryReceipt(newRequestKey)` retains the
original request, evidence, content state, journal head, block and late policy.
An opaque evidence commitment records the declared corroboration; it does not
independently prove upstream facts or the absence of a publicly exposed result.

A refused fee, provider submission, request-ID collision or reentrant submission
reverts the receipt, Artist-record consumption, journal, escrow/credits,
request association and counters together. The same authorized input can then
be retried after the failure is repaired.

## Late replies

An old request can win only while the current subject is REQUESTED and every
intervening frozen step accepts late original fulfillment. Traversal is bounded
by the maximum 32 policy steps. Any rejecting step makes that ancestor stale.
A permitted old reply finalizes with its own immutable request/seed inputs,
marks its key as the winning subject request and emits the displaced key.
Pending and token counters decrease once. Every later reply observes the
existing finalization and cannot change the seed.

A stale reply emits the original `StaleEntropyFulfillment` schema and returns
outcome 1. Current provider lifecycle eligibility still applies. Ordinary
terminal actions also require the actual active key, so an old failed request
cannot close a newer pending request.

## Validation boundary

The focused cases cover token/scope recovery, immutable inputs and exact keys,
Artist evidence and resulting state, live roles/provider status/delay,
provider output discovered after an incident, fee ownership, rollback and retry,
ordered attempts, maximum attempts, ancestor arbitration, actual threshold Safe
execution and finalized-seed fuzzing. The cohort uses explicit typed Core,
Artist, role and provider fixtures with the actual coordinator and fixed workers.
Actual joined Artist/Executor composition, the unavailability finding branch,
maximum-depth gas, complete current-stack validation and new testnet evidence
remain required. Runtime and size results are recorded with their source batch.

The final focused run passes all 100 cases across ten suites, including the
12 new recovery cases and the existing incident, policy, provider, epoch,
subject, reveal-fee, quote and SLO regressions. All 79 captured sources match
the integration checkout and every one of the 181 prior coordinator ABI
entries remains. All 15 production products fit deployment limits. The first
run passed 70 cases but exceeded the coordinator runtime limit; the fixed
callback worker and quote encoder resolve that size failure. Complete current
Artist/Executor integration and the pending finding branch remain separate.
