# Initial adjudicated artist identity recovery

This developing profile restores control of the same artist identity after a
contest. It supports an initial living authority with no prior transition or
guardian history and an empty supersession list. Full historical, guardian,
posthumous and nonempty adjudication profiles remain in the delivery plan.

## Caller and authority

Use [IStreamArtistIdentityRecovery](../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol)
on the deployed artist facade. Its context read derives the exact request and
new-authority acceptance commitments. The mutation is executed by the original
sealed governance Executor under its terminal class, with the required live
attribution-arbiter proposer and exact per-call reason/context. Direct calls to
the Identity owner or a facade call outside that governance action are rejected.
The new principal's acceptance uses the original artist signature rules and
supports contract-wallet authorization.

The artist ID is preserved. The successful transition authenticates the new
principal, invalidates earlier delegation, records provisional standing and opens
a new contest window. Recovery state, nonce consumption, owner revision and the
two ordered Archive records commit atomically. If the last Archive call fails,
the earlier changes roll back and the same unconsumed acceptance can retry.

Secondary supersession receipts use an occurrence coordinate tied to the primary
recovery record. Distinct recoveries may therefore retain identical semantic
supersession lists without changing the permanent signed or record hash meanings.
The exact same primary recovery/action remains replay-protected.

## Reading and contests

Retained recovery records remain available through the facade and original
Identity state. Recovery markers participate in ordinary transition reads and
standing, including provisional-window equality boundaries. A successful
contest and dismissal preserve their original evidence and replay protection;
new later contests need their own unused subject/evidence/reason tuple.

## Evidence and remaining integration

Five actual Artist/Archive/Safe cases pass in IR as a retained three-case and
corrected two-case union. Seven recovery-state cases pass separately. The sealed
governance reader has six focused cases in both compiler modes and five actual
Core/Executor/Safe cases in IR, including retained foundation tests. Those are
separate cohorts; one fully composed governance-and-Artist deployment is still
required. The broad default build and full v1 release checks are not complete.

The owner adds a fixed third Identity child while preserving the original child
addresses at creation nonces one and two. Deployment tooling must include that
child and the exact compiler/library/constructor configuration. See
[ADR 0039](../adr/0039-canonical-finality-governance-and-evidence.md) and the
[active delivery ledger](../../ops/V1_DELIVERY.md) for the remaining profiles.
