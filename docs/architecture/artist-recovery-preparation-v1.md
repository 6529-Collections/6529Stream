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


## Current guardian head recovery

`6529STREAM_ARTIST_GUARDIAN_HEAD_SELECTION_PROFILE_V1` extends the nonempty
profile above to current heads and higher-nonce records. The earlier
lower-nonce path remains supported. The same living, sole-original-rotation,
no-prior-recovery cutoff and exact contest evidence gates still apply.
Pre-transition and other record-family exclusions still reject.

The fixed third Identity child constructs one immutable
`StreamArtistGuardianSelectionPreparation` through a linked deployment library.
Read Identity's existing `identityRecoveryExtension()`, then that child's
`guardianSelectionPreparationBinding()` to find its address and runtime pin.
No caller selects the producer. Identity's original three child addresses and
constructor argument order remain unchanged; all linked creation helpers must
still satisfy deployment size limits.

Before asking for the recovery context, call `begin(artistId, transition,
excluded)` on this helper and advance `continueSelection(key, maximumRecords)`
until complete. Each transaction processes only its requested range. There is
no new total-history cardinality limit. The caller cannot skip, reorder or
shorten the committed history: the helper checks every indexed original entry,
strict owner-revision order, full guardian-record data hash and complete history
chain, and seals only at the exact admitted count, final root and revision.
Every excluded hash must occur in the scanned prefix. Empty and previously
unselected sets are scanned too. The elected result is the highest eligible
nonce outside the requested exclusions and permanent supersession statuses;
following an old head's predecessor pointer cannot establish that result.

Election starts only after the sole original rotation's post-window has
elapsed. Every provisional association must be empty or refer to that exact
original transition and deadline. Its phase, window and first contest timestamp
are fixed in the evaluation basis and rechecked at every chunk and consumption.
An early-contested cohort stays discarded; a late contest does not rewind
already-mature eligibility. Changed owner runtime, history or transition makes
the old preparation unusable. The no-prior-recovery restriction is also part of
this basis; a future profile allowing mutable prior supersession statuses must
add an appropriate invalidator. These checks prevent a scan from dropping an
immature higher nonce in one transaction and sealing after it matures.

Helper progress neither changes an Identity owner revision nor creates a pending
governance action. The existing owner-local registration still authenticates the
whole scheduled batch, complete terminal delay, exact current cause, request and
acceptance. It commits the sealed election and complete restored guardian record
in its state and Archive evidence. The original association retains the
pre-recovery operative guardian fact; `guardianRecoverySelection(actionId)` on
the fixed Identity owner exposes the separately retained result and restored
record. A complete zero eligible result is explicit. An eligible empty guardian
set has its original nonzero record hash and retains its own window floor.

Execution repeats the current context and applies the result atomically with the
original recovery record, two receipts and one owner revision. It checkpoints
the restored stable head, clears the fully classified former provisional
candidate, and records the exclusions permanently. The post-vesting window is
`max(global rotation window, restored guardian minimum)`. Saved recovery standing
uses the immutable restored record and action/selection commitments without
consulting the helper's later availability or today's selected head. Original
rotation, guardian and executed-history records remain unchanged.

Actual guardian admissions validate the local stable and provisional heads
against permanent statuses before and after their mutations; recovery validates
its atomic repaired result. The unchanged dismissal checkpoints only the actual
operative result from those same local heads and clears the candidate, so it
preserves this invariant without a new status read. It cannot install a
caller-selected or prior-history head. The outward guardian read validates the
same invariant. Existing selection logic can therefore continue reading these
authenticated heads without a new callback in every internal selection. Every
future writer that installs or rewinds a guardian head must preserve this
invariant and consult supersession status. No corrupted or legacy state repair
is inferred. A later authorized record below the excluded head's nonce can become
operative after its own captured window; the excluded head is never restored by
that comparison.

Preparation paging establishes completeness, not a universal gas envelope.
Maximum exclusion-count materialization, cold-read budgets, constructor/initcode
and complete deployment remain separately measured gates. General historical
or estate election needs all relevant eligibility invalidators, not just the
single elapsed transition used here. Appeal authority, hostile pre-transition
evidence, absolute directive restrictions, other superseded record families and
full chain rewinds remain required consumers.

## Restricted root appeal for pre-transition guardians

`6529STREAM_ARTIST_GUARDIAN_ROOT_APPEAL_PROFILE_V1` adds a pre-transition
guardian lane to the sole-original-rotation, living-authority profile. The
Identity owner derives the required tier from complete original history and
the saved successful vesting revision. A requested pre-cutoff record requires
APPEAL; post-cutoff-only lists retain ARBITER. Unknown artists, incomplete
chronology, missing records and prior permanent exclusions fail closed. This
does not change operations 34/35, permanent hashes, the 57 plus adopted 58
operation inventory, auxiliary 65534 or the 37 genesis roles.

The supported appeal proposer is the actual current GovernanceRoot. The fixed
Executor must own the actual RoleRegistry, point to that registry, and identify
the same root in `owner()` and `governanceRootState()`. That root must have the
current APPEAL role, with the exact saved root code hash/revision and role
mutation chain/revision. This establishes root-mediated administration of the
ROOT-class ARBITER role. It does not implement a general delegated role-admin
relation. The stored original proposer must equal that root. Both scheduled
association and active sealed TERMINAL_FREEZE execution authenticate these
facts; registration still leaves the full terminal minimum delay, and the
independent governance guardian veto remains intact.

The third fixed Identity child exposes `guardianAppealEvidenceBinding()` for a
permissionless immutable content publisher. The publisher observes the owner
runtime only after construction, when publishing. It creates no Identity
revision, pending action, signature authority or adjudication. A typed document
binds the exact current cause and original contest, saved original vesting
commitment, full request commitment, a hostile-findings reference and every
requested pre-cutoff guardian record with its exact original party array.
The owner reconstructs that complete subset from original records; omitted,
additional or substituted parties/records reject. Empty pre-cutoff guardian
sets are outside this explicit hostile-party profile.

The request commitment has its own domain/version and substitutes zero for
only `evidenceHash`. The resulting document hash fills that one request field;
the original expected cause/resolution, new principal, reason and complete
supersession list remain committed. The original Contest evidence and reason
are reconstructed from the retained original record and cause. The new request
must retain that original reason; its evidence field identifies the separate
hostile document. This avoids a circular commitment or a rewritten contest.
A nonzero hostile-findings hash identifies evidence assessed by the authorized
appeal adjudicator; it is not machine proof of hostility.

The actual operative artist directive is authenticated and included in the
scheduled context. A `CAP_GUARDIAN_SET` prohibition is absolute even at APPEAL.
Root/role/directive changes invalidate the original scheduled context; regranting
a role does not restore its earlier revision. Preparation and execution Archive
payloads retain the original payload plus the complete document, authority and
directive evidence. The document identifies the original cause and Contest
records already retained by operation 33 Archive evidence, and the immutable
vesting snapshot by transition and commitment. The owner validates those full
records in the scheduled context; these exact references preserve the
transitive Archive and owner-record join without duplicating their payloads.
Permanent original guardian/rotation records, one owner
revision, the two recovery receipts and late-Archive rollback are preserved.
Complete election and all retained guardian memberships still govern restored
selection and veto; a mixed pre/post list subtracts only its exact exclusions.

This profile remains limited to a fresh deployment with complete admission and
vesting indexes, one original ordinary rotation and no earlier recovery.
General historical/appeal/estate recovery, other superseded record families,
the exceptional still-provisional lane and full chain rewinds remain required.
Maximum 64-record/eight-party publication and preparation, repeated context
reads, constructor/factory sizes and aggregate transaction gas remain separate
capacity gates. The Artist/Safe tests and actual Executor/RoleRegistry witness
tests are complementary deployments; neither alone establishes the combined
full-system deployment.

## First estate-authority recovery

The first estate recovery profile uses the same public operation 35 request,
acceptance, scheduled action and operation 34 veto interfaces. Its request must
vest authority class 3 with an empty supersession list. The current original
compromise cause must save class 3/prior status 3 and identify the exact original
estate activation as its subject and executed transition. Request evidence and
reason must equal that original cause and Contest record. These are limits of
this profile, not a general prohibition on other estate resolution evidence.

The initial ordinary profile authenticates one operation-38/40 request/execution:
original record hash, phases, actual old-address retirement, authorityActivation,
latest execution/transition, exact notice and post-window arithmetic, original
coverage and timing supplements, and a completely empty closure. Execution must
follow the full original notice; the compromise must be at or after the saved
post-window end, with no strictly earlier contest. The immutable operation-40
vesting snapshot has no predecessor and commits the same current guardian count,
root and last-admission owner revision. Multiple and lower-nonce original sets
are supported. Missing history and post-activation admissions fail closed.

The full original designation and paired/forbidden directives are reconstructed
and authenticated under their original hashes. Current operative heads must
still equal those originals. The effective capability intersection is recomputed
and must equal the original execution facts; zero is a valid mask. The stored
original request, authorization and coverage evidence remain historical facts
from the trusted original admission, not fresh recovery authorizations. No old
signature, current original-key capability or current historical-coverage grant
is required to keep an already admitted activation true.

Recovery updates the current principal to the new accepted Safe with class 3 and
status 3 while preserving the original activation, designation successor address,
identity record and exact saved capability mask. It increments the delegation
epoch once. It creates a separate recovery transition/standing tail and vesting
snapshot chained to operation 40; original estate/living records and unrevoked
prior-address standing remain readable. The selected operative guardian floor
sets the new window through the usual maximum with the rotation window. Every
retained guardian in the complete original prefix keeps the staged recovery veto,
even if its lower-nonce record never became selected. This does not broaden the
separate singular post-recovery contest-standing interface.

The fixed Identity owner passes actual succession and Contest storage to named
estate-aware State entry points. Old State entry points remain living-only and
retain their ABI. Both derive the authenticated context before delegating to the
fixed mutation library. Its supplied context is internal linked-call evidence;
the library is not a new external owner authorization surface. The original
same-owner replay, primary/list hashes, one revision/two receipts, emitter and
late-Archive rollback boundary are unchanged. Context and mutation libraries add
linked calls and gas costs; deployment libraries and child templates remain
subject to their independent runtime and initcode limits.

The focused actual tests cover a first estate activation and exact-expiry
compromise, new Safe recovery with original mask 2304, zero-mask recovery and
blocked guardian removal, and a lower-nonce lifetime Safe veto after notBefore.
The Archive overflow case retries the identical registered action and original
acceptance after verifying rollback. Retained living-recovery and root-appeal
cases exercise the extraction. The positive guardian-removal case requires both
CAP_GUARDIAN_SET (256) and CAP_GUARDIAN_DISPLACE (2048), hence mask 2304. The
estate cases use original designation masks 2304/2048/0 and zero paired/forbidden
directives; they do not establish a nonzero
estate directive-intersection matrix. The unit Executor switches from the actual
archival coverage role graph to the constructor-pinned Artist role graph after
activation. Typed action facts/roles/Core and the separate real delayed governance
cohort remain complementary evidence, not one combined authority deployment.

Successor-authored guardian history and accelerated first-estate activation are
covered by the two extensions below. General or closed estate histories, nonempty
estate supersession and appeals, later recoveries, dormancy and steward branches
remain open. No maximum history/list, aggregate gas or complete
system deployment claim follows from these focused cases.

## Estate successor guardian admissions

The successor-guardian profile extends the preceding first-estate profile to
guardian records actually admitted by the original estate successor. The original
operation-40 activation, exact current class-3 compromise cause,
empty closure, unchanged designation/directives/capability mask, no earlier
vesting or recovery, and empty supersession list remain required. This extension
does not authorize a new guardian publication or reconstruct missing history.

The saved vesting guardian head is an authenticated prefix of the current complete
append-only history. A nonempty prefix must match its exact terminal index, full
guardian record/data hash, successful owner revision and history commitment; its
admission revision precedes the operation-40 revision. An empty saved prefix must
have zero count, commitment and last-admission revision, while the original
vesting itself remains a nonzero authenticated record. Missing or incomplete
legacy history fails closed. This is a fresh-deployment profile with no backfill.

The operative selection retains the normal maximum eligible nonce rule. A living
class-1 record must belong to the saved pre-vesting prefix and have the canonical
empty provisional association. A class-3 record must be beyond that prefix in
both admission index and successful owner revision, and its signer must be the
original operation-40 successor. Its immutable association must be empty or name
that exact estate activation and original post-window end. The normal eligibility
rule still applies: an original-window record can mature at exact expiry, while a
strictly earlier contest cannot become eligible merely through elapsed time.
Author-supplied timestamps and nonce order do not establish the vesting cutoff.

Original operation-28 admission supplies the historical capability and signature
authorization. Additive maintenance requires CAP_GUARDIAN_SET (256); removing a
captured original guardian additionally requires CAP_GUARDIAN_DISPLACE (2048).
Recovery adds no present-day capability gate to keep an already admitted record
valid. The unchanged zero-mask admission rule remains enforced.

Context and owner preparation use the same estate guardian reader. They commit
the complete current history and exact selected record before registration;
execution rejects changes to that basis. Every admitted member in the frozen
unsuperseded prefix, including an unselected lower-nonce successor record, retains
the action-local veto. Original operation-40 data, its smaller guardian snapshot,
and the designation's original successor remain unchanged. New operation-35
vesting captures the extended history and chains to the original estate
commitment. Saved recovery standing names the selected class-3 record without a
fresh current-head lookup; the singular post-recovery contest-standing interface
is not broadened into a complete historical-member union.

Focused cases cover SET-only successor records admitted inside and at the end of
the original window, exact-expiry maturation, complete-history preparation, a
lower-nonce successor-only Safe veto, zero-mask additive rejection, and an
identical-action late-Archive failure/retry. Retained first-estate and initial
living-recovery cases cover the prior branches. The original typed Core, action
facts and archival-to-Artist Executor role-phase fixture limitations remain;
these cases do not establish a combined actual governance deployment. General
estate histories, resolved windows, later recoveries, nonempty
estate supersession/appeals, other record families, and maximum-history or
whole-transaction capacity remain separate requirements.

## Accelerated first-estate continuation

The same first-estate recovery profile also consumes an original activation
executed before its saved notice deadline. The original operation 40 must have
admitted it through the canonical class-1 accelerator described in ADR 0031.
The consumer requires execution at or after the saved request time. Before the
original notice deadline both saved governance action ID and witness hash must
be nonzero; at or after that deadline both must be zero. The complete original
execution, including those commitments, remains in the same predecessor Facts
hash. Recovery neither accepts a replacement witness nor reauthorizes historical
governance roles or coverage. Original operation 40 owns those checks and the
one-use action replay key.

Acceleration does not shorten the saved post-activation contest window. The
current compromise must be at or after its exact end, with no earlier contest.
The first-vesting, empty-closure, unchanged authority-plan and capability checks
remain. The complete original guardian prefix and any eligible actual successor
admissions use the preceding rules; every unsuperseded member retains its
recovery veto, including members of unselected lower-nonce records. Recovery
preserves the original acceleration record, witness, identity and capability
mask, then appends its own vesting under the original atomic Archive boundary.

The focused cohort is `StreamArtistAcceleratedEstateRecoveryActualTest`: exact
expiry with successor history and identical signed retry after Archive failure;
lower-nonce successor Safe veto; permanent in-window compromise rejection; and
zero-capability recovery without living-authority or guardian-SET escalation.
It uses the actual Artist, Safe and Archive with explicitly typed unit Core and
governance action facts. It does not establish a complete delayed-Executor graph
or public-transaction capacity. Closed/dismissed cohorts, later estate or recovery
histories, nonempty supersession and appeals remain separate required work.

Run the focused cases through the repository wrapper in aggregate mode, which
preserves the inherited unit fixture's original CREATE sequence:

```powershell
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistAcceleratedEstateRecoveryActual.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```


## Closed first-estate compromise continuation

A first ordinary or accelerated estate activation may also continue through an
original dismissed identity-compromise cause (kind 1, operation 33). Recovery
reads the immutable closure, its original operation-41 dismissal and saved cause,
and the original contest record. It checks their complete canonical hashes,
artist, class-3 incumbent, restored status, activation, governance commitments
and chronology. Historical reason and evidence belong to that original episode;
they need not equal the new recovery request. Those records were authorized by
the original producers and are not reauthorized using current governance roles.

The closure's abandoned flag must equal the original transition predicate. An
early abandoned closure permits a new compromise and recovery preparation before
the old window ends. A non-abandoned closure requires the original window to have
ended before dismissal. Both retain the full new recovery scheduling delay. The
original closure never moves: an intervening actual dismissal is permitted, with
today's latest immutable dismissal and cause authenticated separately against the
current cause, same incumbent and activation. Original dismissal time must not
exceed latest dismissal time, which must not exceed the new compromise time.

The empty-closure path and original first-estate Facts hash remain unchanged.
Only the newly supported closed branch wraps that hash with a commitment to the
complete original closure and both original/latest dismissal, cause and contest
proofs. First vesting, no prior recovery, unchanged estate plan and capability
mask, current binding, Safe acceptance, governance, replay and complete-history
veto requirements remain. No producer operation, public ABI or storage changes.

Abandoned provisional documents, payout accounts and guardian sets remain
permanently ineligible, even after the old deadline and after recovery. Their
original records and associations stay intact. A fresh class-3 guardian record
admitted after dismissal is stable; an unsuperseded member found only in an
abandoned lower-nonce guardian record still retains the recovery veto. Dismissal
never disqualifies those historical guardians.

`StreamArtistClosedEstateRecoveryActualTest` covers early ordinary closure with
fresh guardian selection and identical signed retry after a real Archive failure;
accelerated closure with an intervening actual dismissal; non-abandoned post-end
closure with zero capabilities; an abandoned lower-nonce Safe veto; corrupted
original/latest immutable proof fields with exact restoration and retry; and
wrong latest-resolution or unclosed in-window refusal. Its retained ordinary and
accelerated cases continue to exercise the original branches. These use actual
Artist, Safe and Archive with typed unit Core, action facts and role phases.
The aggregate CREATE fixture is not a full delayed-Executor/current-Core graph or
individual transaction-capacity claim. Standing-contest (kind 2) closures, later
activations/rotations/recoveries, nonempty supersession and appeals remain separate
required work.

```powershell
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistClosedEstateRecoveryActual.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```


## Standing veto and living-history estate continuation

The next estate continuation keeps current recovery tied to the original
operation-33 class-3 compromise. Historical operation-31 standing vetoes are a
different producer: they veto a pending rotation, store a kind-2 Cause with zero
evidence (and possibly zero reason), and consume that rotation's veto key.
Operation 41 may then abandon the pending rotation and close the original
expired estate window without fabricating an estate contest timestamp. The
reader authenticates the original RotationRecord, its canonical hash and
phase-3 timestamp, the exact pending Closure, Dismissal and Cause. The original
estate closure never moves when a later episode is dismissed. Today's latest
admitted dismissal and latest closed pending rotation are checked separately.

An estate activation may also follow living-authority rotations. The actual
operation-40 vesting links the then-current operation-32 vesting and its original
commitment. The reader checks that immutable parent, its original executed
rotation, class-1 authority, addresses, chronology, owner revision and guardian
prefix, together with the parent's already-recorded predecessor commitment.
This is bounded consumption of admitted owner history, not an unbounded replay
of historical signatures or governance. A selected estate designation or
directive may retain its earlier living signer's address. A class-1 guardian
record that matured during a prior actual rotation may remain operative; its
original association, signer, canonical record, captured window and eligibility
must all match. Abandoned associations never become eligible.

The original zero-parent first-estate and kind-1 closure commitments remain
byte-for-byte unchanged. Only the additional paths use the separately tagged
ESTATE_CONTINUATION_FACTS_V1 wrapper around the original facts, with the exact
ancestry and latest standing proof. Complete guardian-history registration and
lifetime veto membership remain unchanged, including earlier lower-nonce sets.
Current binding, new-address acceptance, replay lanes, capability intersection,
governance delay and atomic Archive effects retain their existing checks.

The focused StreamArtistEstateStandingHistoryActualTest uses actual Artist,
threshold Safe and Archive contracts with explicitly typed unit Core and
governance boundaries. Its cases cover zero-reason standing closure, mixed
episodes, two prior living rotations with an earlier signer plan and mature
guardian, lower-nonce veto, corrupted immutable links, and identical Archive
retry. This guide does not infer native acceptance from those source cases.
Run the aggregate unit harness with its required limits:

```powershell
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistEstateStandingHistoryActual.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```

Those raised aggregate limits accommodate the test's fixture CREATE operations;
they do not establish individual deployment or recovery transaction capacity.
Executed successor rotations after estate activation, prior recoveries, nonempty
supersession and later estate plans remain distinct continuation work. The
existing request producer remains living class 1/status 1, so this increment
does not invent a second successor-to-successor estate activation.


## Recovery after one executed estate-successor rotation

An admitted estate successor may complete an original two-sided operation-32
rotation and later recover from an operation-33 compromise. This continuation
keeps the original operation-40 request, execution, plan, capability intersection
and guardian prefix as the authority origin. A distinct tagged proof binds the
immediate class-3 operation-32 RotationRecord and immutable vesting snapshot to
that origin, including its saved previous commitment, addresses, owner revisions,
retirement, canonical hashes, timing and early guardian-quorum condition. A
zero-capability successor may rotate under the original operation-29 policy;
this continuation introduces no rotation capability bit.

The current execution and vesting heads must both be that terminal rotation.
The original estate and terminal rotation must be unclosed, with no earlier
in-window contest. The current original kind-1 compromise names the terminal
rotation and occurs at or after its own post-window. Expiry of the earlier estate
window is insufficient. The immediate terminal parent is the original op40;
additional executed successor depth, closed terminal histories, prior recovery
and nonempty supersession remain separate required profiles.

Both original vesting prefixes remain authenticated. Earlier eligible guardian
records must precede the terminal snapshot; a later class-3 record must be signed
by its actual new incumbent, follow that snapshot, and retain either its exact
eligible terminal association or the canonical empty stable association. Context
and registration use the same reader. The full lifetime history still supplies
veto membership, including the original lower-nonce living guardian. A recovered
class-3 authority retains the original estate mask and activation while its new
op35 vesting links the terminal op32. Existing signatures, replay consumption,
registered action gates and both atomic Archive receipts are unchanged.

The focused StreamArtistEstateRotatedRecoveryActualTest uses actual Artist,
threshold Safe and Archive contracts with typed unit Core, governance action and
role-phase boundaries. Six source cases exercise timed and early-quorum rotation,
zero capabilities, a matured terminal guardian, original living ancestry and
lower-nonce veto, original/terminal proof corruption with exact restoration,
in-window refusal, additional-depth refusal and an identical late-Archive retry.
Native execution and complete product measurements are required independently;
this guide does not claim them from the test source.

```powershell
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistEstateRotatedRecoveryActual.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```

The raised limits accommodate aggregate fixture CREATE operations. This domain
harness does not establish a full current-Core/delayed-Executor lifecycle or
individual deployment and recovery transaction capacity.


## Estate history after successive rotations and dismissals

The next source batch extends the same original operation-40 authority origin
through successive admitted class-3 operation-32 rotations and terminal histories
closed by operation 41. An original compromise or a standing veto of a pending
rotation may precede the current compromise. The original estate activation,
selected plan and effective capability intersection remain unchanged.

The original terminal Closure stays attached to its first Dismissal record.
The reader authenticates that record, its original Cause and operation-33 record
(or the distinct operation-31 pending rotation and its abandoned closure), then
separately authenticates the current latest dismissal. Original evidence and
reason fields come from their historical records. The later compromise must
follow the latest admitted dismissal. An early abandoned closure releases its
former post-window; passage of time never restores abandoned provisional
records. An unclosed in-window compromise still cannot mature by waiting.

Executed ancestry uses the fixed owner's write-once vesting snapshots. Each
producer binds its actual preceding execution and canonical commitment, with
increasing owner revisions and complete guardian prefixes. Registration starts
in class 1; only the original estate operation establishes class 3, and ordinary
rotations preserve it. This reader still excludes prior identity recovery and
supersession. It therefore authenticates the unchanged original estate, current
terminal and immediate executed parent without a caller-supplied history or a
new depth ceiling. If the stage followed a dismissed pending rotation, that
staging parent is authenticated separately from the executed vesting parent.
Current terminal retirement is checked; old mutable retirement entries do not
serve as permanent ancestry anchors when an address has returned and left again.

An intermediate successor's guardian record may remain operative when its exact
canonical entry belongs to the complete terminal prefix and its original
association is eligible. Original class-1 records retain their earlier prefix
checks. Fresh terminal records retain the current signer and association checks.
All lifetime members remain in the veto history, including lower-nonce records
whose provisional cohort was abandoned. Context construction and registration
use the same guardian reader.

The source tests in StreamArtistEstateHistoryBatchActualTest compose early
closure and identical Archive retry, zero-mask authority, standing-veto closure
with an intervening dismissal, abandoned-record lifetime veto, original-closure
corruption/restoration, multiple rotations with an intermediate guardian,
returned original addresses and distinct staging/execution parents. The previous
single-rotation depth rejection becomes a canonical parent-drift/retry control.
The combined source exposes 40 test cases, including four inherited living
recovery/supersession cases beyond the scoped estate cohort. Its current
validation is ABI/type
checking and source review, with runtime acceptance deferred to the consolidated
validation phase. The separate frozen 28-case resume8 capture contains the prior
source and must not be relabelled as validation of this batch.

```powershell
python scripts/dev.py test --suite unit --match-path test/unit/artist/StreamArtistEstateHistoryBatchActual.t.sol --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```

This domain harness uses actual Artist, threshold Safe and Archive contracts,
with typed unit Core/governance/role-phase boundaries and aggregate CREATE
semantics. Prior-recovery composition, supersession, a changed estate plan,
full current-graph operation and transaction-capacity validation remain separate
requirements; the batch does not remove their existing refusal or authority gates.


## Historical and estate guardian supersession

The current operation33 cause supplies the exact executed transition whose
guardian vesting snapshot classifies the requested exclusions. A later ordinary
rotation or an executed estate can supply this cutoff; a caller cannot substitute
an older snapshot. The fixed Identity authenticates the current write-once
vesting head, canonical commitment, exact saved guardian prefix, immediate
admitted parent and original operation32 or operation40 record. Existing living
and estate predecessor validation remains a separate requirement. This consumes
trusted admitted history; it does not replay historical governance authorization.

Records admitted after the cutoff revision and prefix must belong to its exact
vested class and signer. They retain the ordinary ARBITER path. Any requested
record in the earlier prefix requires the existing APPEAL path, with the current
GovernanceRoot, exact hostile-party document and absolute operative-directive
constraints. A dismissed earlier episode supplies neither a different cutoff nor
appeal authority. This batch adjudicates only the current compromise cause; it
does not resolve a caller-selected chain of earlier contested transitions or
implement the separate still-provisional pre-vesting exception.

The permissionless election scans the complete admitted history and resolves
each original provisional association against its own actual transition. It can
therefore restore a mature living or intermediate class3 record after a later
rotation or estate. An abandoned cohort remains ineligible even after its former
deadline. Every chunk and consumption retains the whole current guardian
count/root/revision, current transition and owner-runtime basis, and the original
no-prior-recovery gate. Before expiry, preparation is possible only for an
already early-contested transition, whose associated records cannot mature;
the recovery context independently authenticates the admitted closure.

For estate APPEAL, predecessor validation reads the original operation33 evidence
from the actual saved contest. The unchanged signed recovery request separately
commits the new hostile-document evidence and is checked by the existing APPEAL
consumer. This is not a mutation of the original contest or acceptance. Empty
supersession keeps the original context hashes. Exact scheduled registration,
complete retained-membership veto, permanent exclusion status, nonce/replay,
capability preservation and atomic Archive rollback remain unchanged.

`StreamArtistHistoricalGuardianSupersessionActual.t.sol` adds six source-level
recipes for living history, estate and rotated-estate elections, exact Root and
document admission, incorrect cutoff retry and retained lifetime Safe veto. The
cases use actual Artist, Safe and Archive contracts with typed unit Core,
governance and role facts. The source batch is typechecked; integrated runtime,
complete linked-product sizes and transaction-capacity validation remain pending.
