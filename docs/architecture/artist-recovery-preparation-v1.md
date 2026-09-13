# Identity recovery preparation profile v1

This pre-genesis auxiliary profile supports the first counted, guarded
initial-living identity recovery. It supplements canonical operations34 and35;
it does not renumber or extend their permanent semantic and signature preimages.

| Coordinate | Exact rule |
| --- | --- |
| Operation | `uint16(65534)` |
| Configuration profile tag | `keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_PROFILE_V1")` |
| State owner | The fixed actual Identity owner, constructor domain `keccak256("domain:identity_authority")` |
| Admission | Complete exact stored SCHEDULED class2 batch, bound/sealed Executor, full remaining terminal minimum delay, one exact zero-value recovery call to the fixed facade |
| Actor | The actual permissionless indexer captured by the facade |
| Semantic primary | None: `bytes32(0)` |
| Owner revision | One successful increment |
| Record delta | `keccak256(abi.encode(bytes32(0)))` |
| Sequence and chain tip | Unchanged |
| Signature and nonce | Stored acceptance commitment only; no consumption |
| Atomicity | Owner association, replay, revision and final Archive append all succeed or all revert |

The association contains, in order, `associationHash`, artist ID, request hash,
complete acceptance hash, scheduled context hash, the full action witness, the
full original guardian record, actual indexer, preparation timestamp and successful
owner revision. The action witness contains action ID, full calls hash, call
index, exact calldata hash, immutable Executor address and runtime hash, original
proposer, registration-time role mutation hash and revision, `notBefore`, expiry,
actual minimum delay and action manifest hash. Integer widths and tuple order are
defined in `StreamArtistRecoveryActionTypes`.

Compute the association hash with its `associationHash` field zero, using
`abi.encode` of the preparation domain, deployment chain, registry, actual owner,
Coordinator, Archive, prior pending action ID and that complete association.
The preparation domain is
`keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_V1")`. Store the resulting hash
once, with the immutable association, and select its action as that artist's
pending action. The replay scope is that actual action ID under
`identity_authority.replay.recovery_preparation` in existing owner replay V2.

The state commitment uses the existing owner fourteen-word transition preimage.
Its action component wraps operation65534, actual actor, and the hash of the
operation, completed association and prior action. Its next-state component binds
the completed association and selected pending action. The replay component is
the consumed owner replay key. This explicit zero-record profile is different
from the packet's twenty-word record-delta encoding; neither earlier owner
history nor this auxiliary commit is relabeled as that other encoding.

Operation34 similarly stores no semantic primary. It binds artist, exact pending
action, direct saved guardian and nonzero reason to a permanent local veto,
consumes the action-keyed `identity_authority.replay.recovery_veto_key`, advances
one owner revision and leaves sequence/tip unchanged. Its original
`ArtistIdentityRecoveryVetoed(uint16,bytes32,address,bytes32,bytes32)` event is
emitted by the Identity host before the atomic Archive append. The event uses
schema2, indexed artist and vetoer, reason, then governance action ID.

The preparation event uses schema1 and reports indexed artist/action, association
hash, original guardian record, actual indexer and actual preparation time. These
auxiliary receipts do not create or replace the permanent operation35 primary
and secondary receipts. Successful guarded recovery still uses the original
RotationAcceptance and unchanged recovery/supersession semantic hashes.

The exact selected guardian record, admission count and pre-transition cause
determine the scheduled context before preparation. No owner revision or pending
association enters that context. This avoids a scheduling cycle while the
separate association commits the owner revision and frozen guardian identity.
Count1 can include an empty first set; such a set supplies no eligible local
guardian. Fresh counted deployments are required: this profile does not infer
historical admission counts for an older deployment.

## Indexed-history extension

The additional configuration tag
`keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_PROFILE_V1")` admits
multiple original guardian-set records in the same initial-living/no-transition
profile. `StreamArtistGuardianHistoryTypes` defines the exact Head, Entry and
Snapshot widths/order. The original Association tuple is unchanged.

Each operation28 history commitment hashes ten ABI words in this order:
`keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1")`, chain ID,
registry, actual Identity owner, artist ID, one-based admission index, successful
operation28 owner revision, unchanged permanent guardian record hash,
`keccak256(abi.encode(fullGuardianRecord))`, and previous history commitment.
The owner retains both index-to-record and record-to-entry mappings. The first
membership index is per artist and address and is written only once.

The guarded context wraps its preceding guarded old-value hash and complete
Head under `keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_CONTEXT_V1")`.
Only prior immutable admission revisions enter that head. Registration cannot
change the history/context by creating its own owner revision.

The action-local Snapshot contains artist ID, complete count, history commitment
and association hash. Preparation's next-state hash and Archive payload include
this snapshot; veto's next-state hash includes the same snapshot and the actor's
first membership index. The historical count/root remain immutable per action.
A new member cannot join an older prefix. Runtime source admission supplies the
policy under which every record in this initial prefix has veto standing; the
standalone history library is not an authority or adjudication verifier.

`guardianHistoryState(artistId,index,actor,actionId)` returns Head, the indexed
Entry, the action Snapshot and actor's first index. Index0/action0 request absent
entry/snapshot, and a known snapshot from another artist rejects. Positive
admission count without complete indexed history rejects. The read bundle does
not replace the existing singular transition-standing tuple or grant union
standing to post-recovery contests.

## First completed-rotation extension

The additive `6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_PROFILE_V1` tag permits
one actual first rotation whose original uncontested window has completed, with
no later transition cohort, pending transition or earlier identity recovery.
The current contested cause must bind that execution and incumbent. Original
rotation hash, record, executed transition and old-address retirement are read
from Identity-owned storage; the exact stored window is never recomputed from
today's configuration. Both the cause and any first contest marker must be at
or after that original end. Earlier contests do not expire into eligibility.

The predecessor commitment is `keccak256(abi.encode(
keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_FACTS_V1"),
fullOriginalRotationRecord, originalRetirementHash))`. After the existing
initial/guarded/history context calculation, only this new branch wraps the
old-value hash and predecessor commitment under
`keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_CONTEXT_V1")`.
This wrapper contains no pending association or future preparation revision.
The original initial-authority branch remains unchanged.

Use the actual operative guardian record, including an eligible provisional
candidate that has matured through reads alone. The exact full record must match
its indexed History entry and permanent GuardianRecord hash. Original authorship
is preserved; a changed incumbent does not invalidate a prior key's admitted
set. The full non-superseded history prefix remains the staged-veto source,
while the selected record controls the new post-vesting minimum and common
standing tuple. Existing Association fields, action membership, local veto,
cancellation/replacement, original acceptance and receipt rules are unchanged.

This is an empty-supersession first-rotation profile. It does not implement later
rotation/appeal/estate histories, earlier adjudicated exclusions, nonempty
supersession or all-history post-recovery contest standing. Counted/indexed fresh
deployments remain required; an unindexed legacy history cannot be asserted.

## Historical ordinary-rotation extension

The additional `6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_PROFILE_V1`
configuration tag admits later ordinary rotations and actual prior-dismissal
resolution of an executed in-window contest. The initial branch and the
previously supported first completed-rotation branch retain their old context
preimages. No public tuple or storage root changes.

The new predecessor hashes `abi.encode(
keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_FACTS_V1"),
fullCurrentOriginalRotationRecord, currentOldAddressRetirement,
previousRecordHash, resolutionHash)`. Here `previousRecordHash` is zero for no
previous transition, otherwise `keccak256(abi.encode(fullPreviousRotationRecord))`.
The previous record must be an actual same-artist ordinary record that either
vested the current old address or was vetoed without changing that address.
The helper trusts the fixed owner's original admission invariants; it does not
walk every predecessor or equate a vetoed new address with an incumbent.

For an originally uncontested completed window, `resolutionHash` is zero. For
an early-contested window it is `keccak256(abi.encode(originalClosure,
originalDismissalRecord, originalCause))`, after validating the full original
record/cause hashes, exact transition/artist/incumbent and chronology. The first
closure's dismissal need not be today's latest dismissal. The current cause
still binds today's actual latest resolution through the unchanged owner
admission. The original contestedAt and abandoned guardian records remain
permanent; they never mature through this read.

Only the new historical branch then wraps its preceding old-value hash and
this predecessor under `6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_CONTEXT_V1`.
All inputs exist before scheduling. The future preparation revision, action ID
and association remain outside that context, avoiding a scheduling cycle.
The saved history prefix supplies all registered guardian veto membership;
operative selection supplies only the new window and singular standing tuple.
Guardian-threshold execution before an ordinary rotation's contest deadline is
valid original history and retains its actual stored approvals/timing.

This remains living class1, empty supersession, no earlier identity recovery
and no later unresolved phase3 latest head. Dismissal is an ordinary typed
resolution, not appeal authority or supersession. Estate, prior recovery,
nonempty supersession/selection rewinds, appeal-tier disqualification and
complete post-recovery historical contest standing remain implementation work.

## Guardian history at authority vesting

The `6529STREAM_ARTIST_GUARDIAN_VESTING_PROFILE_V1` profile records an immutable
snapshot at each implemented authority vesting: ordinary rotation (32), estate
activation (40), and an admitted identity recovery (35). This is chronology
for later supersession admission, not a decision to exclude any guardian. The
canonical 57 operations, adopted dismissal58, auxiliary preparation65534 and
37 genesis roles are unchanged.

The fixed Identity owner captures its actual previous executed transition before
the original mutation. Immediately after that mutation, a linked admission
helper joins the original stored record, executed phase2 transition, current
principal/address/class, active-identity mapping and old-address retirement.
Operations32/40 use the expected original rotation/activation record because
their existing mutation contains no semantic record. Operation35 uses its
owner-recomputed new recovery record. Approval, staging and cancellation do not
create vesting snapshots.

The snapshot retains artist, original transition hash, operation, successful
owner revision, actual execution timestamp, old/new address, vested class, the
complete GuardianHistory Head, previous actual execution and its snapshot
commitment. Its successful owner revision is distinct from the Head revision,
which records the last successful guardian admission. Every guardian entry in
that prefix precedes the vesting even at the same block timestamp. An entry
admitted afterward has a later owner revision/index; author-supplied signedAt
and nonce do not establish that ordering.

The commitment has exactly seventeen static ABI words:
`keccak256(abi.encode(keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
chainId, artistRegistry, identityOwner, artistId, transitionRecordHash,
operationId, successfulOwnerRevision, executedAt, oldAddress, newAddress,
authorityClass, completeGuardianHead, previousTransitionRecordHash,
previousSnapshotCommitment))`. The Head contributes three words. The implementation
concatenates the static four-word environment and thirteen-word facts encodings;
there is no dynamic offset or change to the preimage. Empty history still has
a nonzero snapshot commitment. `guardianVestingSnapshot(artistId,recordHash)`
on the fixed Identity owner returns the fourteen-word Snapshot, including its
commitment. Unknown or wrong-artist records reject. Historical reads use the
immutable saved record and do not depend on current guardian selection.

The two snapshot mappings append inside the existing final Recovery storage
root. Only the original mutation's next-state hash additionally commits the
snapshot commitment. The original action/replay, permanent semantic hashes,
signatures and record append rules stay intact: one owner revision for each
operation; no semantic append for32/40; two ordered receipts for35. Snapshot
storage and its exact `ArtistGuardianVestingRecorded` event participate in the
same lock and transaction as the original owner commit and Archive write.
Any late failure rolls the complete transition back.

This profile requires fresh, completely counted guardian history and a snapshot
for each prior actual execution. A nonzero previous execution with no matching
snapshot rejects; there is no retrospective backfill or migration claim. The
current zero guardian count also rejects unexplained stable/provisional heads.
A future vesting producer, including any not-yet-implemented dormancy path,
must add the same owner-authenticated hook before claiming complete chronology.

The later consumer must authenticate the earliest vesting actually contested
by its resolution evidence. It cannot select a later snapshot to exclude more
guardians. AA-GUARD7's separate still-provisional lane requires the exact
original association/transition/window/closure and scope of evidence; a
persisting provisional field is not proof of current ineligibility. This
prerequisite does not implement that consumer, appeal-tier authorization,
hostile-guardian findings, directive constraints, nonempty supersession,
operative-selection rewinds, or expanded historical contest standing.

Estate execution preparation runs in the linked `StreamArtistEstateExecutionMutation`
helper to keep the fixed second-child deployment library within EIP170. The child
retains its original only-host and owner-context guards, then delegates the exact
coverage, execution-facts, optional governance witness, original mutation and
snapshot sequence before its original single commit. The environment and revision
are derived by the fixed owner. The extra delegatecall preserves owner storage,
address and event emitter while adding a code/gas dependency. The original
factory and six-argument child constructor are unchanged. Deployment acceptance
must measure every linked deployment library as well as deployed children; the
passing-test code-size allowance is not that acceptance gate.

## Nonempty post-vesting guardian adjudication

`6529STREAM_ARTIST_GUARDIAN_SUPERSESSION_PROFILE_V1` admits a first nonempty
recovery list for a living identity after its sole original ordinary rotation.
The current operation 33 record must name that exact executed rotation, and its
evidence and reason must equal the recovery request and current cause. The
immutable vesting snapshot must prove that there was no earlier vesting. This
profile therefore authenticates its earliest contested transition; a current
execution pointer or caller-supplied timestamp cannot supply the cutoff.

The sorted, unique list contains one through sixty-four original guardian-set
hashes, retaining the [validation profile's existing bound](../adr/0021-0022-validation-adapter-interface-freeze.md).
Every record must belong to the same artist, have been admitted by the
vested incumbent after the saved guardian prefix and successful vesting owner
revision, and remain within the complete current history. Both admission index
and owner revision are checked, so a later admission at the same timestamp is
classified correctly. A pre-vesting record rejects at this arbiter-only tier.
The separate still-provisional exception is not inferred from a persistent
provisional field.

This increment rejects both current stable/provisional heads and every record
whose nonce is equal to or above the operative guardian's nonce. An excluded
record need not have been unselected throughout its entire history. These
records cannot win the preserved monotone selector; execution permanently
records their actual recovery/action coordinate without changing original
guardian records, signatures, executed transitions or semantic hashes. A later
head-supersession/rewind implementation must consult this permanent status
before selecting historical records. Selected-head supersession and rewind
remain required work.

Every actual operation 28 also appends the record's admission index to each
member's per-artist index, inside the same original owner mutation and Archive
transaction. Empty sets advance the complete indexed head too. The new indexing
maps append after vesting history inside the final Recovery root. Missing
preexisting indexing rejects both a subsequent indexed operation 28 and nonempty
recovery; this is a fresh-deployment profile with no backfill claim.

Preparation commits the exact exclusions in its immutable owner-local action
association and freezes each actor's excluded membership count. Veto reads use
binary search over that actor's admission indices up to the saved prefix and
subtract only the frozen excluded memberships. Any membership in another
retained record preserves the actor's veto, including a later retained set when
the actor's first membership was excluded. No list-wide or history-wide scan is
needed when the guardian calls veto. The full remaining terminal delay, actual
SCHEDULED lifetime and authoritative cancellation/replacement rules remain
unchanged.

Preparation creates no executed supersession. Successful operation 35 saves each
original record's `(artistId,recoveryRecordHash,actionId)` status under
`guardianRecordSupersession(recordHash)` on the fixed Identity owner, folds the
adjudication into the same owner next-state commitment, and retains the original
one-revision/two-receipt append. A late Archive failure rolls back statuses,
acceptance nonce and the entire recovery together. The saved request and recovery
event retain the full nonempty list and unchanged supersession-domain hash.

The cardinality grammar is not a maximum-capacity acceptance claim. Sixty-four
sets can contain 512 distinct members; materializing all frozen exclusion counts
requires a separately measured preparation envelope. Small-list current-Artist
tests do not prove that maximum, full governed deployment, or aggregate gas.
Appeal-tier hostile pre-transition exclusions, absolute directive forbiddance,
estate/posthumous recovery, other superseded record families, selected-head and
chain rewinds, and expanded historical contest standing remain required
consumers. This increment neither fabricates their authority nor weakens their
conditions.
