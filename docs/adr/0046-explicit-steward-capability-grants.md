# ADR 0046: Explicit steward capability grants

- Status: Accepted technical decision for the developing full-v1 implementation.
- Date: 2026-09-15.
- Validation: source and ABI checks; native behavior, integrated governance and
  product-size evidence remain pending consolidated validation.

## Context

[AA-DORMANCY requirement 6](../stream-artist-authority.md#governed-dormancy-procedure-aa-dormancy)
requires later, explicit, reasoned `TERMINAL_FREEZE` grants of sanction or
economics authority to an appointed steward. Neither the original living-only
operation 19 grant nor appointment operation 43 admits that later action.
The historical catalog contains operations 1–57; accepted dismissal is 58.
Reusing one of those operations would conflate authority and replay recipes.

## Decision

Adopt additive operation **59**, `grantStewardCapabilities`, through the existing
immutable registry, fixed writer, guarded Coordinator, Identity owner and
atomic Archive. The original 1–57 catalog prefix and dismissal 58 remain intact.
The typed interface is `IStreamArtistStewardCapabilities`; the companion
[recipe extension](../architecture/artist-operation59-steward-grants.json)
describes its owner/read/write/replay boundaries.

The exact payload contains artist ID, expected immutable operation-43 appointment,
current steward address, expected original directive, expected grant head,
expected effective mask, added mask, reason hash and reason URI. The added mask
must be nonzero, contain only `CAP_ECONOMICS_CONSENT` (4) and `CAP_SANCTION` (8),
and contain no already-held or artist-forbidden bit. Policy consent and guardian
displacement cannot be granted here. A prior explicit artist directive can still
supply guardian displacement at appointment; this action never creates it.

Identity authenticates its current class-4/status-3 principal, active address,
actual completed appointment, original directive and its currently operative
selection. The scope commits chain, registry, fixed Identity, artist and operation
59. The old state commits the full principal/appointment/directive, exact current
grant head/mask and latest execution. The new state commits the exact payload.
An intervening authority rotation, grant or directive selection therefore
invalidates a staged context. A current successor is not a steward.

The calling actor must be Identity's immutable governance Executor. Its live
per-call context must be executing class 2 with the exact scope/old/new hashes.
The canonical stored action must be executed, class 2, have actual proposer and
execution caller, be inside its saved window, have no canceller/vetoer, and retain
the payload's exact nonempty reason hash/URI. The exact registry selector must
have active terminal-freeze classification with its current runtime pin and
nonzero configuration revision/hash. The action must retain a nonzero captured
terminal-freeze guardian-set commitment.

The real Executor already enforces its minimum delay, independent veto authorities,
captured guardian-set equality and veto outcome before entering this callback.
This recipe consumes that admitted state. It introduces no second signatures,
alternate scheduling preimage or reconstruction from a batch's first-call index
fields; authorization uses the current per-call context.

Each grant is an immutable record with its terms, admitted witness, prior head,
resulting mask and recording time. Additional bits and a head pointer are stored
separately under the original appointment. The appointment record and its original
mask remain immutable. Current class-4 capability reads include the later admitted
bits; legitimate same-class address rotation preserves that appointment's grants.
The next grant must still bind the then-current address and head.

The semantic owner mask is `0x04` (Identity only). Two explicit new replay surfaces
consume the record and exact action/context pair. The original operation-evidence
Archive format carries operation 59 and the full terms/context/witness/record.
A late Archive failure rolls back the grant head, mask, record, replay cells and
Identity commitment in the same transaction.

## Permanent limits and validation

Granted sanction and recovery approval still require collection scope and the
original permanent collection burn block at or before the immutable appointment
height. The grant cannot authorize new policy, displace lifetime guardians, bypass
an artist's forbidden mask, change the appointment, or create a new authority class.

The focused source tests compose actual Artist owners, Safe signatures and Archive
with explicitly typed Executor/Core boundaries. They cover same-signed economics
retry, immutable appointment and original record hash, sanction boundary,
stale appointment/head, repeated/forbidden bits, actual directive-pointer drift,
wrong principal class, wrong class/context/selector runtime, missing admission,
veto/reason failures and late Archive rollback. These authored tests do not
establish actual delayed Executor integration or native runtime acceptance.
