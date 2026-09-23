# Entropy incident declarations

The current coordinator implements evidence-bearing terminal incidents for an
original token or registered scope. This is the incident portion of
[the entropy specification](stream-entropy-coordinator.md).
It does not implement a fresh request, fallback selection or post-mint migration.
The collection's existing no-fresh-recovery policy commitment remains unchanged.

## Operator calls

Use `IStreamEntropyIncidents.markEntropyRequestUnrecoverable(tokenId, reasonURI,
evidenceHash)` for a token, or `markEntropyScopeRequestUnrecoverable(scopeId,
reasonURI, evidenceHash)` for a scope. Both are zero-value calls suitable for a
Safe. The caller must currently hold `ROLE_ENTROPY_INCIDENT_DECLARER` in the
original code-pinned role registry under the canonical executor/module registry.
Being the coordinator's authority alone does not satisfy the incident role.

Before submitting, collect independent upstream request/fulfillment evidence and
commit the bundle in `evidenceHash`; provide its nonempty reason/reference in
`reasonURI` (at most 2,048 bytes). A bundle for an independently observable
provider must corroborate that upstream fulfillment did not occur. If upstream
output already exists publicly, a negative adapter report cannot justify a fresh
draw. The contract commits this evidence; it cannot establish the truth of an
arbitrary offchain bundle.

The original subject must still be `REQUESTED`, with no stored seed/raw result,
and the request identity and saved provider policy must agree. The timeout must
have strictly elapsed; the existing provider-revocation flag waives only that
clock check. A code-pinned provider is probed for the exact saved provider request
ID. Only a canonical 160-byte negative report for that same request is accepted.
Unknown statuses, noncanonical words, any received/delivered output, a nonzero
raw-output hash, a wrong key, a revert, gas exhaustion or extra return bytes all
leave the request unchanged.

Success stores immutable `entropyIncident(requestKey)` evidence, marks the
original subject `FAILED`, closes its pending count once, and emits
`EntropyRequestFailed` or `EntropyScopeRequestFailed` with the original epoch and
attempt. Token metadata notification retains its existing retry behavior.
Later callbacks cannot write a seed for this closed subject. The old
`markRequestStale` and `markRequestFailed` administrative display transitions
remain separate and never authorize another draw.

## Host-owned probe budget

Each new coordinator independently registers
`GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT` (the hash of
`6529STREAM_GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT`). The current implementation's
initial value and immutable floor are 100,000 gas; failure class is
`FORWARDING_CAP` (1), initial revision is 1. These are implementation settings,
not measured release-capacity evidence. Adapter corpus sizing and the complete
primary/fallback deployment manifest remain required before candidate acceptance.

The gas-host interface, event schemas and V2 scope/state commitments match the
canonical governed parameter host. Only the pinned executor's exact delayed
class-1 context can raise a value, by at most twice its current value per action;
lowering and same-action reuse fail. Existing coordinator time parameters and
all prior ordinary storage slots remain unchanged. The new fixed linked workers
use distinct coordinator-owned storage namespaces.

## Validation scope

[The focused test source](../test/unit/entropy/StreamEntropyIncidents.t.sol)
covers token/scope events, evidence, strict timeout, revocation, dynamic roles,
actual Safe calls, terminal replay, received zero randomness, malformed and
wrong-key reports, real gas exhaustion/return bombs, governed-budget commitments
and fuzzed provider responses. The fixture uses actual coordinator and Safe
contracts with explicit Core, role-registry, provider and delayed-executor seams.
Full current-stack/fallback/Safe activation and measured gas remain separate.
