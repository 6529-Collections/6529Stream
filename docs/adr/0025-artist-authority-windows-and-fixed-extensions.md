# ADR 0025: Artist authority windows and fixed typed extensions

Status: Accepted design for the undeployed full-v1 artist line, 2026-09-11.
Implementation and composition acceptance remain separate gates.

The owner delegated the full-v1 implementation decisions to the integrator.
This decision amends only the overlapping authority-transition model in
[AA-ROTATE and AA-GUARD](../stream-artist-authority.md) and the code placement
within the seven-owner architecture of [ADR 0023](0023-modular-artist-authority-domain-ownership.md).
It does not change an existing deployment or declare all 57 operations complete.

## One active window

An identity has at most one active authority-transition window, including the
post-execution period. A subsequent rotation waits until the previous executed
transition's captured post-window expires uncontested. A staged rotation remains
pending until execution or veto; the staging deadline does not discard it.
Captured guardian record, threshold, effective contest duration, standing tail
and timing revision are immutable for that transition. Guardian, payout and
document writes cannot move its deadline.

The post-window is the half-open interval `[executedAt, postWindowEndsAt)`.
Provisional records retain their exact transition association and prior operative
head. At equality, an uncontested candidate becomes operative through reads
alone. Guardian selection uses the highest eligible nonce. Document and payout
chains permit one provisional child of an operative predecessor; another child
would be a forbidden fork. An in-window contest makes that cohort ineligible.
A contest filed after uncontested expiry does not retroactively demote mature
records; doing that requires explicit adjudicated supersession.

Contested status never expires automatically. A contested provisional child
remains in history and cannot silently free its predecessor for a new branch.
The future adjudication/recovery implementation must explicitly supersede or
abandon it before normal progress resumes. Defensive authorization revocation,
royalty/content freezes and stored-grantor delegation revocation stay available.
Prior-address standing outlives the window until an eligible explicit revocation;
independent guardian membership is unaffected.

This trades rapid consecutive address rotations for bounded operative reads.
An artist can still veto a pending takeover and use the defensive operations.
Guardian quorum can execute a pending rotation early, but cannot shorten its
post-window. Future estate, dormancy, compromise and recovery operations must
honor this model or amend it explicitly; their absence is not hidden behind a
timeout or an invented readiness provider.

## Governed seconds

Identity owns the rotation and prior-standing-tail durations, outside GGP/GTP.
Their defaults/floors remain 7 days/72 hours and 90 days/30 days. The immutable
Executor is independently derived from the already-deployed Manager and its
Core-bound canonical ModuleRegistry; no selected artist pointer is needed
during construction and no EOA or mutable-owner fallback exists.

The explicit facade selector `setArtistWindow(bytes32,uint64,uint64)` forwards
the original actor through the guarded Coordinator. Identity requires that
actor to be the pinned Executor and verifies its nonzero executing action,
exact parameter scope, old/new values, floor and timing revision. Class 0 or 1
may raise; only class 1 may lower. Unknown parameters, no-ops, stale revisions,
values below the floor and timestamp overflow reject. Configuration has its
own revision and action replay commitment, without an artist record, owner
history commit or artist liveness update. Staging captures the actual revision.
The operator catalog must admit exact facade target/selector/class/code entries;
this ADR does not invent parameter catalog identifiers or authorize a wildcard.

## Fixed typed code placement

Measured runtime limits require splitting code without splitting semantic
ownership. Identity and its constructor-created writer extension share the
same physical Owner prefix and Identity field declarations. Existing explicit
writer selectors forward their unchanged calldata to that immutable target.
The extension verifies the exact host before the existing Coordinator/snapshot
guards and performs the same one-owner commit, replay updates and events under
the Identity address. Direct extension state reads and writes reject; inherited
immutable getters expose only the actual construction pins.

The facade similarly uses a fixed writer extension that preserves the original
caller. Selected caller-independent reads use a separate fixed helper through
`staticcall`, with the facade authenticated as caller. Authority-sensitive reads
remain on the facade. There is no generic public dispatcher, fallback, mutable
routing table, delegatecall view shortcut or caller-selected implementation.
Coordinator recipes may use fixed linked libraries behind its existing lock,
code checks and ingress authentication. The facade remains the EIP712 identity;
Archive remains evidence storage; no semantic state moves to an extension.

Acceptance requires recursive physical-storage and prior-ABI comparisons,
exact owner/caller/domain/event/replay tests, immutable host/pin checks, actual
child CREATE address and code hashes, and complete runtime plus constructor
size measurements including constructor arguments. Constructor child creation
does not consume the external deployer's nonce. Future deployment inventories
must nevertheless include the child contracts and all linked library bindings.

No live migration, upgrade route or release-readiness claim follows from this
decision. Existing immutable testnet evidence remains tied to its original line.
