# ADR 0029: Identity-contest dismissal and cohort closure

Status: Accepted design for the undeployed full-v1 implementation. The
[effective extension design](../architecture/artist-operation-extension-v1.md)
is recorded and checked. Source and the 202-case domain runtime are integrated;
actual current-stack and effective source/configuration acceptance remain pending.

Date: 12 September 2026. Delivery issue: [#743](https://github.com/6529-Collections/6529Stream/issues/743).

## Problem and decision

`AA-GUARD` requirement 6 in [artist authority](../stream-artist-authority.md)
requires an arbiter to dismiss a contested identity and restore its prior
status under the incumbent authority. The historical 57-operation matrix has
no distinct dismissal operation. Filing operation 33 cannot double as its
resolution, and recovery operation 35 changes authority and requires new-side
acceptance. Fabricating either transition would misstate authorization and
history.

Add a distinct, typed `dismissArtistIdentityContest` operation with ID 58.
Preserve operations 1 through 57 and their historical evidence exactly. This
decision clarifies the already-required dismissal and amends the unresolved
contested-window behavior in [ADR 0025](0025-artist-authority-windows-and-fixed-extensions.md).
It does not change an existing deployed contract or the completed RC1.

Dismissal explicitly closes the exact contested provisional cohort, including
when governance executes before its original post-window deadline. Its invalid
candidates remain permanently ineligible. Fresh authorized writes may then
proceed as stable records, and a new rotation may begin with fresh timing and
acceptance. This early closure is an adjudicated effect, not an implicit
consequence of clearing the contested status.

## Authority and atomic result

The immutable canonical Executor must be executing a staged class-1 or class-2
action with exact per-call scope, prior-state and intended-state commitments.
Its stored proposer must currently hold `ROLE_ATTRIBUTION_ARBITER`, and the
recorded reason must match the dismissal. Use the bounded governance witness
rules established for operation 33, including batches. A Safe holding the role
uses this delayed route; a direct Safe call does not replace it.

Bind the exact current contest cause, artist, incumbent address and authority
class, pre-contest status, evidence, reason, expected cause/resolution heads
and relevant transition facts. Reject stale, foreign, superseded or already
resolved causes. Consume cause-resolution and action replay independently.
Append one immutable dismissal record and event, retaining the original cause
and all its evidence.

Both a rotation veto (operation 31) and an identity filing (operation 33) can
set the identity to CONTESTED. Append Identity-owned typed cause evidence on
both entry paths: cause kind/reference, actual actor and reason, incumbent
address/class and prior status captured at entry, relevant pending/executed
cohort and prior cause head. Operation 33 references its actual contest record;
operation 31 references the actual vetoed rotation. Preserve operation 31's
`NONE` normative primary-record semantics and the existing `Contest.Record`
tuple. Supplemental cause evidence must not fabricate an operation-33 filing
or change either historical signature/record preimage.

An operation-31 cause is sufficient for dismissal when it is the exact current
cause; requiring an operation-33 record would strand a veto-contested identity.
Capture the actor explicitly: a rotation's old address is not necessarily its
vetoer. An untyped reference, foreign rotation, mismatched kind or reconstructed
incumbent cannot substitute for this owner-held evidence.

Restore the captured pre-contest status under the same incumbent. The first
implementation may support the currently implemented ACTIVE artist profile
only if it rejects unsupported prior statuses explicitly. Full-v1 completion
also requires SUCCEEDED and DORMANCY_NOTICE restoration, with their captured
authority class and original notice deadline. Dismissal must not reconstruct
these facts from the execution timestamp.

The Identity owner remains the sole writer for operation 58, with owner mask
`0x04`. Archive failure rolls back status, resolution, continuation, standing
and replay together. Payout maintenance is deferred to its next authorized
write through typed composition, as described below.

## Terminal cohort closure

Snapshot the exact pending and executed transitions captured by the contest,
their Identity-owned candidates and operative stable heads. Operation 58 does
not read or write Payout state; its candidate and stable-head checks belong to
the later typed operation-18 callback. A filing naming an
older subject must also resolve its captured current invalid cohort. An
Identity-owned terminal resolution links each abandoned transition to the
dismissal without rewriting its original deadline, `contestedAt`, retirement
or transition record.

Both `activeWindow` and record `association` must recognize terminal closure.
Clearing only the active-window pointer is insufficient: an association read
before the original deadline would attach new records to an invalid cohort.
Closed-cohort records remain ineligible after that deadline and after later
rotations, even if a record is no longer held in a single candidate pointer.
Guardian, directive and successor selection must obey the same rule.

A contest filed at or after the original post-window end cannot demote records
that already matured. Preserve the selected mature heads before replacing
candidate pointers; operative reads immediately before and after dismissal
must agree. Conversely, waiting until the deadline after an in-window contest
cannot make that invalid cohort eligible.

A cancelled pending transition stays cancelled. Dismissal does not revive its
acceptance, approval, pending pointer or banked notice time. Fresh rotation or
estate activation requires a new request and the applicable new acceptance.

## Continue record chains without erasing replay

An abandoned identity-revision child has already consumed its predecessor's
one-child replay scope. Never mark that scope unused or overwrite its historic
result. Append an owner-derived continuation authorization binding the
original predecessor, exact abandoned child, dismissal and prior continuation
head. A new versioned replay scope permits one replacement child from the
retained stable head. Caller-selected salts cannot choose another replay lane.
A later abandonment needs its own exact dismissal and continuation.

Preserve the existing operation-25 signature and document-record preimages;
bind the continuation separately in operation, state and replay evidence.
Detach a candidate only when its exact association has an actual terminal
abandonment. Mere expiry, contention or ineligibility is insufficient. Keep
old records, document bytes, associations, nonces and consumed digest cells
readable. Unused signatures retain their existing rules; dismissal does not
implicitly revoke them or revive consumed or explicitly revoked signatures.

For Payout, use an additive typed callback during the next authorized payout
write. The Coordinator snapshots the Identity resolution; Payout checks the
exact artist, cohort, candidate and stable predecessor before detaching that
candidate. Preserve the old callback's fail-closed behavior. Payout must not
call Identity itself or accept an unverified boolean. The composed facade read
can return the stable payout immediately after dismissal; an owner-local read
may continue to require its explicit context until maintenance occurs.

## Preserved state and standing

Do not change bindings, attribution generations, commercial/content consent,
financial entitlements, finality, defensive freezes, delegation grants,
principal nonces or digest revocations. Restored ordinary actions remain
subject to those retained restrictions.

Optional bad-faith standing removal must name the cause's filing/vetoing prior address and
its exact retirement and append adjudication evidence. It removes that
prior-address contest/veto standing only. Independent guardian or successor
standing is unaffected. Preserve the specified appeal obligation; dismissal
does not invent an appeal implementation or imitate an artist-signed
operation-51 revocation.

## Effective inventory and release

Preserve the original operation matrix and its five mechanics, continuity and
reconstruction packets, schemas and historical checker expectations byte for
byte. Add a versioned operation-extension manifest that pins those exact inputs
and appends row 58 with all original 18 column names, its typed recipe,
authority, concurrency facts, owner mask, replay, record and event joins.
Dismissal has no fabricated artist-signature family.

A dedicated checker must verify every baseline row and derive the effective
inventory as the original ordered prefix plus the extension. Reject changed
historical fields or hashes, omission, reordering, duplicate IDs, selector
collisions, invalid widths/masks, inconsistent writers and incomplete
event/replay reconstruction. The current source gate must consume that
effective inventory and bind supported selectors and configuration hashes.
A historical 57-only check does not prove operation 58.

Freeze the exact new ABI, hashes, events and typed continuation contracts with
the implementation and extension manifest. Regenerate current deployment
links, constructor bindings, ABI exports and release artifacts once that source
stabilizes. Existing RC1 and historical packets remain unchanged.

## Bounded implementation helpers

The integrated implementation keeps Identity as the sole owner of dismissal
storage, replay, records and events. Resolution state follows the existing
succession roots. Fixed compiler-linked helpers compose cause records and
encode eleven typed Identity reads. Each read has an explicit function and
fixed storage arguments; callers cannot supply a target or selector. Direct
library calls do not return authoritative Identity state.

The Identity constructor uses a fixed deployment helper to create its writer
child. Delegatecall retains Identity as the CREATE sender and preserves child
nonce 1, the actual Identity host and the existing facade, Coordinator, Archive,
Core and Manager pins. The Registry's separate reader deployment helper retains
its earlier CREATE sequence. Neither helper introduces mutable routing or a
caller-selected deployment host.

The accepted 213-source, 202-test domain snapshot includes nine actual CREATE
traces and 95 production runtimes within the EVM size limits. Identity's runtime
is 24,490 bytes and its argument-inclusive initcode is 26,263 bytes; the fixed
deployment helper's runtime is 24,304 bytes. These measurements apply to that
snapshot. The supported artist profile remains via-IR; non-IR compilation is
unsupported. Current deployment and Executor/Safe acceptance remain separate.

## Required verification

- Real delayed Executor/Safe success and exact unauthorized, wrong-role,
  class, context, stale-state, wrong-incumbent and replay rejection.
- A real operation-31 veto followed by dismissal and fresh rotation, with
  no fabricated operation-33 record; reject mismatched cause kind/reference,
  actor, incumbent or cause head. Preserve the operation-31 record semantics.
- In-window contest and pre-deadline dismissal with document, payout,
  guardian, directive and designation candidates: old candidates never mature;
  fresh writes and rotation succeed from the preserved stable state.
- One replacement revision child per authorized continuation; reject a fork,
  retain the original consumed cell, and handle a second later abandonment
  through a distinct continuation. Exercise typed payout continuation too.
- Equality and late contests preserve matured heads. Earlier-subject filings
  cannot leave the captured current invalid cohort unresolved. Cancelled
  transitions remain unexecutable.
- Late Archive failure restores all state atomically. Successful dismissal
  preserves defensive restrictions and balances; bad-faith prior-standing
  removal preserves independent standing.
- Negative extension-manifest fixtures independently alter a historical
  field/hash, row order, event field, owner mask, ID, selector and stop overlay.

The design received separate adversarial review before acceptance. Existing
operation-33 or succession tests are not evidence that dismissal is implemented.
