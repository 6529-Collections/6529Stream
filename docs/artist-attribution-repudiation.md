# Staged Artist repudiation (operations 47–50)

The additive `IStreamArtistAttributionRepudiation` facade supplies the original
unilateral exit in [AA-DISPUTE requirement 5](stream-artist-authority.md#disputed-and-revoked-attribution-aa-dispute).
It stages a full public window, allows a guardian veto or current staging-authority
cancellation, and only then permits a permanent prospective attribution exit.
Original operations 1–60, signature schemas and record domains remain intact.
This source batch has authored actual Artist/Safe/Archive tests and a cheap ABI
check. It has no new native execution, size or current Executor acceptance claim.

## Caller flow

```solidity
revokeAttribution(Filing filing, Authorization authorization) returns (bytes32)
pendingRepudiation(uint256 collectionId)
    returns (uint64 bindingGeneration, uint64 executableAt, bytes32 recordHash)
vetoAttributionRepudiation(uint256 collectionId, bytes32 expectedRecord, bytes32 reason)
cancelAttributionRepudiation(uint256 collectionId, bytes32 expectedRecord)
executeAttributionRepudiation(uint256 collectionId, bytes32 expectedRecord)
```

`Filing.disputeAction` is exactly4 (`REPUDIATE`). The original
`StreamArtistAttributionDispute` payload and `6529StreamArtistRegistry` / `1`
EIP-712 domain apply. Evidence may be zero; the reason hash must be nonzero.
This exit does not manufacture an evidence-document opening or adjudicate truth.
A direct authority call uses the exact current Identity nonce hint and an empty
signature. A relayed call uses the original EOA/ERC-1271 check and live deadline.
The original nonce, digest revocation and signature history remain authoritative.

The current accepted or sanctioned binding must use the supported PRIMARY_ONLY
policy. Living class 1 or the actual vested class 3/4 principal may stage; vested
principals must retain `CAP_DISPUTE = 16` in their actual current capability
origin. Repudiation is nondelegable, including for a delegate with that bit.
The capability bit does not replace the original designation/directive rules.
Identity contest and collection dispute block staging and completion. This batch
introduces no new authority class or authority-class transition.

`ARTIST_REPUDIATION_CONTEST_SECONDS` starts at 604800 seconds (seven days), with
a 259200-second floor (72 hours). The existing canonical governed window methods
configure it with the original exact old/new/revision context. Each record saves
the window revision and deadline. Later parameter changes never shorten or extend
an already staged record. No guardians still means the complete captured window.

While pending, either one guardian from the captured set or one from the current
operative set may directly veto. The actual stored set must identify this Artist.
The caller supplies a nonzero reason. The veto terminates that exit and creates
the existing canonical Identity contest plus kind 1 dismissal cause, with the
repudiation hash as evidence. Identity becomes contested and the existing pending
rotation, recovery, estate and dormancy rules apply. Original operation 58
adjudication may later restore authority, but never resurrects the vetoed exit.

Only the still-current staging principal may directly cancel. Cancellation uses
no new authorization signature or Identity nonce. It does perform the existing
authenticated activity hooks: living inactivity time advances, pending notices
are cancelled, and actual unavailability findings are invalidated by their
existing activity epoch. The fixed Identity owner verifies the exact Attribution
cancellation terminal before recording that activity.

At or after the captured deadline, any caller may execute. Completion rechecks
the current binding generation/hash, current authority head, current capability
and pending status. The generation becomes `REVOKED` with reason 3
`REPUDIATED_BY_ARTIST`. This explicit reason replaces any earlier reopenable
arbiter-revocation reason. Even an arbiter cannot reopen the chosen exit.
Executed finality, prior records, signatures and stored payloads remain intact;
future consumers see current revocation through their original state checks.

## History and invalidation

`attributionRepudiationRecord(hash)` is immutable. The separate
`attributionRepudiationTerminal(hash)` reports phase 1 pending,2 vetoed,3 cancelled,
4 executed, or5 explicitly invalidated. Staging saves the current principal/class,
latest transition, latest canonical Identity contest and latest dismissal. A
changed immutable history head makes the old pending record unavailable. These
history references cannot return to an earlier value through an address returning
to authority. Staging a rotation therefore voids an exit before rotation execution.

An old phase 1 row can remain historical after a head change; it is not an executable
pending record. `pendingRepudiation` and `activeRepudiationCount` report the live
head only. A fresh stage lazily records phase 5 on that old row. Opening an actual
attribution dispute explicitly records phase 5 immediately. Resolving the dispute
or dismissing the identity contest cannot revive the old row. Current pending
counts also enforce the original prohibition on revoking prior-address standing
while a repudiation is pending.

The original 13-word repudiation preimage is retained under
`ATTRIBUTION_REPUDIATION_RECORD_DOMAIN`. The original staged/vetoed/cancelled and
attribution-state events remain exact. A schema 1 context companion adds chain,
registry, current binding, captured authority head, guardian set and window
revision without changing the original record. The existing payload catalog and
operation Archive retain its bytes atomically. Guardian veto also appends the
actual canonical contest and cause receipts in Identity's lane as operation 48,
in their original domains; no receipt grants imported authority.

## Semantic recipe and validation boundaries

[ADR 0048](adr/0048-attribution-repudiation-identity-effects.md) records the required
Identity effects missing from the old proposed owner matrix: 48 and 49 write both
Identity and Attribution (`0x14`). Their original read/snapshot mask stays `0x14`;
the Attribution generation was installed atomically with its Binding generation.
Operation 47 retains read/snapshot `0x17` and writes `0x14`. Operation 50 retains
read/snapshot `0x15` and writes `0x10`, including its full current Binding recheck.
Archive remains the normal transaction tail outside those masks. Every semantic
owner checks the original snapshot and commits once; late failure rolls back
state, replay, native receipts, payload catalog and the enclosing Safe nonce.

The 16 authored cases use actual Artist owners/facade, Archive and threshold Safes,
including independent original hashes/events, optional empty evidence, earliest
execution, both guardian sets, original 58 dismissal, rotation/contest/dispute
invalidation, direct activity cancellation, real finding-epoch cancellation,
window contexts, permanently unreopenable exit after prior adjudication, delegation
refusal, nonce reuse, prior-standing refusal, class 3 capability and Archive retry.
Core/governance/role and metadata facts remain explicit unit boundaries. This is
not an actual-current Executor delay/veto or complete integration demonstration.

ALL/THRESHOLD/QUORUM and per-capability collaborator policies remain a separate
complete feature batch. Action 2 dispute withdrawal needs its own compatible
transport recipe and is not accepted by action 1 or 4. Existing operation 60 profiles
do not import dispute/repudiation state, guardian-veto 48 auxiliary history, or
changed repudiation window configuration. Their complete source inventories must
reject those profiles; the new window revision is explicitly checked by Identity's
baseline exporter. Complete import support remains required future work.
