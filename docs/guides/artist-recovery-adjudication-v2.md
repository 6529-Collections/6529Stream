# Artist recovery adjudication V2

The explicit V2 recovery API binds governance to a published resolution
manifest. The manifest declares which genuine executed vestings the resolution
evidence contests, or explicitly declares no contested vesting. This supports
current living/class1 and estate/class3 compromise causes and standing-veto
causes, including zero execution, aborted staging records, historical compromise
subjects and an early current compromise.

The normative rules remain [AA-GUARD and AA-RECOVERY](../stream-artist-authority.md)
and [ADR 0025](../adr/0025-artist-authority-windows-and-fixed-extensions.md).
This guide describes the new implementation surface, not release acceptance.

## Fixed interfaces

Read `recoveryEvidenceBinding()` and
`recoverySelectionPreparationBinding()` on the fixed Identity owner. Each
returns the constructor-bound helper address and code hash. These are separate
from the original V1 recovery child and its guardian preparation helper.

| Surface | Methods |
| --- | --- |
| [Evidence publisher](../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryEvidence.sol) | `publishResolutionManifest`, `resolutionManifest`, `publishAppealV2`, `appealEvidenceV2` |
| [Selection preparation](../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoverySelectionPreparation.sol) | `beginSelectionV2`, `continueSelectionV2`, `requireSelectionV2`, `selectionV2`, `retainedMemberV2` |
| [Registry V2 recovery](../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV2.sol) | `identityRecoveryContextV2`, `registerIdentityRecoveryActionV2`, `recoverArtistIdentityV2`, `identityRecoveryEvidenceState` |

The original recovery `Request` and new-side `Authorization` remain the request
types. Each V2 context, registration and execution call also supplies the exact
`manifestHash`. The scheduled batch must contain exactly one matching V2 call,
with the registry target, zero value, exact calldata hash and context hashes.
Changing the manifest sidecar or using the original recovery selector rejects.

## Manifest and guardian basis

The [new evidence types](../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol)
bind the artist, pre-preparation owner revision, current native cause,
resolution head, actual executed head, request commitment, opaque resolution
evidence and exact sorted guardian exclusions. The request commitment omits
only `Request.evidenceHash`; the scheduled calldata and V2 context still bind
that actual field. Publication checks content shape and stores immutable
content. Its 64-reference/exclusion limits bound each published request; they
do not truncate authenticated original ancestry. It grants no recovery authority and changes no owner revision.

`DECLARED_VESTINGS` requires one or more original vesting references, ordered
from oldest to newest. Each reference contains its original transition hash
and vesting commitment. The reader authenticates the complete original
execution ancestry, including records, receipts, epochs, guardian prefixes,
staging boundaries and dismissal closures. Every declared reference must occur
in that ancestry, without duplicates and in its real execution order. The
first declared member supplies the ordinary guardian cutoff, even when a later
execution is the current authority head. An aborted rotation or cancelled
estate request is not a vesting.

Governance attests that the declaration describes the complete set contested
by the opaque evidence. The contract verifies the declaration's original
membership and order; it cannot interpret an offchain document's meaning.

`NO_CONTESTED_VESTING` requires an empty declared set. The real ancestry may be
empty or nonempty, and is still authenticated in full. This basis supplies no
ordinary post-cutoff exclusion lane. When real ancestry exists, a guardian
admission may independently qualify as still provisional through its original
vesting association, captured window, marker and closure state. A stale stored
provisional pointer alone does not qualify. With genuinely zero execution,
that provisional exception cannot exist.

All remaining guardian exclusions require APPEAL evidence. The V2 appeal
document names the exact manifest and the complete expected hostile guardian
records and parties. Ordinary requests use the manifest's
`resolutionEvidenceHash` as `Request.evidenceHash`; APPEAL requests use the
published V2 appeal document hash. Both registration and execution derive the
required ARBITER/APPEAL role from the same authenticated facts. The original
root-admin authority, role revision and absolute directive protection remain
binding, including the independent provisional path under NONE.

## Preparation and execution

1. Read the original current cause, resolution head, execution ancestry and
   owner revision. Construct and publish the exact resolution manifest. For
   APPEAL, publish its matching hostile-guardian document.
2. Call `beginSelectionV2(manifestHash)` and process the complete original
   guardian history with `continueSelectionV2(key, maximumRecords)`.
   `requireSelectionV2(manifestHash)` must return a completed result before
   obtaining the executable context. Selection itself does not change owner
   state or revision.
3. Obtain `identityRecoveryContextV2(request, acceptance, manifestHash)`.
   Schedule the exact V2 recovery call using the independently required role
   and governance delay, then register that scheduled batch through
   `registerIdentityRecoveryActionV2`.
4. Registration advances the owner revision once and stores the original
   pre-preparation anchor, manifest, guardian basis, selection and association
   in `identityRecoveryEvidenceState(artistId, actionId)`. Execution uses this
   retained anchor and rechecks current facts. It does not compare the
   manifest's old revision directly with the post-preparation live revision.
   Any further owner revision invalidates execution under that manifest; the
   single authenticated preparation increment is the only allowed drift.
5. After the governance delay, execute the registered V2 call. Original
   new-address acceptance, independent guardian veto and cause replay checks
   still apply. Successful operation35 installs the selected guardian head,
   preserves the original authority history and capability origin, and advances
   the delegation epoch exactly once.

A completed election may select zero when no eligible guardian remains.
This is an explicit empty result with a nonzero result commitment, distinct
from absent or incomplete preparation. Even a genuinely empty history requires
the begin/continue completion step. No fabricated guardian record replaces an
empty result, and the independent governance veto remains required.

V2 veto standing comes from retained membership in the completed selection's
original admission prefix, independently of operative guardian eligibility.
Admissions permanently superseded by an earlier recovery remain excluded from
that standing even when the new request's exclusion list is empty. A person
who also belongs to a retained admission keeps that independent membership.

A later separately registered action requires a newly anchored manifest.
The previous action must have reached its original terminal condition; its
association, manifest and permanent veto remain retained. A prior action's
manifest cannot authorize a second preparation.

An early current operation33 may be resolved directly after the governance
requirements mature. Its original early marker and empty dismissal closure
remain unchanged. This does not relax an ancestor's maturity or the eligibility
required before a later rotation was actually staged.

## Current living notice recovery

The same V2 selectors also admit an original class1 compromise captured while
a dormancy notice was open (`priorStatus == 2`). The cause must name its exact
original operation41 notice, have no pending transition and belong to the
authenticated living authority history. The notice may still be open, or may
already have its original operation42 cancellation while the artist remains
contested. A completed operation43 is a different authority origin.

The reader checks the original notice terms, deadline, inactivity and notice
durations, timing revision, incumbent, liveness and activity counter. It joins
the cause, replay admission and native receipt, and checks the execution and
staging boundaries at the original notice initiation time. Earlier challenges
dismissed back to status2 retain their exact notice association and first
closures. Passing the notice deadline does not complete the notice or resolve
the compromise.

After governance and the new Safe's acceptance succeed, operation35 installs
the recovered living principal and invokes the original dormancy activity
writer. An open notice receives one genuine cancellation by that accepted new
principal, with its captured activity counter incremented once. The original
notice and deadline remain immutable. The native operation42 receipt precedes
the original adjacent operation35 primary/secondary pair, and cancellation and
recovery replay share the same new owner revision. If a cancellation already
exists, its terminal is retained and no second cancellation is created.

Future V2 recovery authenticates a historical new-side cancellation through
that exact admitted operation35, its consumed cause, notice association,
vesting and receipt order. Ordinary incumbent cancellations keep their original
rules. The current-notice context and selection source add tagged commitments
to these facts; contexts with no new notice source retain their original bytes.
The Archive preparation payload adds the original cause and notice state.
Execution adds the exact before/after notice evidence inside the original
operation envelope. An Archive failure rolls back acceptance, cancellation,
recovery, replay, receipts and owner state together.

Notice cancellation after preparation advances the owner revision and requires
a newly anchored manifest and action. The existing retained-guardian veto and
ARBITER/APPEAL rules apply unchanged.

## Compatibility and remaining domains

V2 uses explicit selectors and separate evidence, context, preparation and
selection commitments. The original `Request`, `Context`, operation35 record,
receipt pair and sorted supersession domains remain unchanged. Existing V1
selectors keep their supported admission and context bytes; publishing V2
content or completing an external selection does not opt a V1 request into V2.
The [original staging-family guide](artist-recovery-staging-family.md) describes
those earlier selector paths.

Class4/steward-to-living recovery, non-guardian record rewinds and broader
hydration remain separate required domains. Their absence here does not amend
the authority specification.

## Authored validation

The batch contains 25 new actual-producer cases in
[StreamArtistRecoveryAdjudicationActual.t.sol](../../test/unit/artist/StreamArtistRecoveryAdjudicationActual.t.sol),
11 publisher cases in
[StreamArtistRecoveryEvidence.t.sol](../../test/unit/artist/StreamArtistRecoveryEvidence.t.sol),
and 8 selection-worker cases in
[StreamArtistRecoverySelectionPreparation.t.sol](../../test/unit/artist/StreamArtistRecoverySelectionPreparation.t.sol).
The actual host uses original Artist owners, threshold Safes and Archive;
Core and action scheduling retain explicitly typed unit boundaries.

The actual cases cover current C1/C2, class1/class3, zero and nonzero ancestry,
NONE/one/multiple declared vestings, early and historical subjects, genuine
provisional exclusions, complete empty selection, role/directive changes,
retained vetoes and associations, exclusion of previously superseded-only veto
membership, exact calldata, acceptance, original receipt
preimages, closure preservation, Archive failure with identical retry and
replay rejection. The publisher and worker hosts separately exercise grammar,
immutable bindings and bounded preparation controls.

The separate
[current-notice host](../../test/unit/artist/StreamArtistCurrentNoticeRecoveryActual.t.sol)
uses original notice, compromise, dismissal, cancellation and recovery producers.
It covers zero/32/prior35 ancestry, repeated notice challenges, retained phase2
terminals, future recovery, exact cancellation and Archive evidence, stale
preparation, guardian veto and atomic rollback with identical retry.

Implementation validation uses source review and ABI/type checks. These checks
do not establish runtime acceptance. Native execution, combined current-stack
tests, linked product sizes, gas/capacity, full CI and release artifacts remain
pending. No deployment or readiness claim follows from the authored cases.
