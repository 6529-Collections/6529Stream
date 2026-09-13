# Owner recovery notices and responses

`StreamOwnerRecords` adds an action-bound TOKEN notice profile and the
`IStreamFinalityRecoveryOwnerEvidence` six-word read. It retains the original owner
record domain, unordered nonce lanes, permanent records and notice-only steward
designations. This guide describes the supported contract meaning. It does not
claim delivery to an offchain recipient or complete Finality/Museum conformance.

## Opening and original recipient evidence

Anyone may call `openRecoveryNotice` with the complete published governance batch,
the original recovery request, the current steward designation witness (an entirely
empty tuple when no designation exists), and publication claims. The linked
[action reader](owner-recovery-action-reads.md) authenticates the actual scheduled
class-2 action, every ordered call, exactly one zero-value recovery call, its
complete calldata commitment, the current Core-selected recovery target and code,
the reciprocal deployment graph, and the actual staged intent. TOKEN identity must
join the requested collection and have a current owner.

The opening retains the owner address, current per-author steward record hash,
complete designation payload commitment, original request/manifest/action binding,
publisher, original response-lane index and actual publication time. The deadline
is exactly publication time plus 72 hours and must not exceed the scheduled action
expiry. Equality at the deadline counts as elapsed; equality at action expiry is
still live. There is exactly one opening per action. Transfer, a replacement
steward, pause, failed processing and retry cannot restart its clock.

The snapshot stores authenticated binding hashes, not a second copy of the complete
`GovernanceCall[]` or request. Reconstruct that exact ordered witness from retained
scheduling/opening transaction calldata. Executor `scheduledCallData` and the
companion's registered request preserve constituent call/request bytes, but those
reads alone are not advertised as a complete ordered GovernanceCall metadata getter.
The separate claim getter below retains the complete notice-publication claims.

Publication includes a runbook reference, a public-notice reference and exactly one
delivery claim per required endpoint: first the opening owner's exact chain/address
tuple, then every original steward endpoint in its original order. Each reference
retains all six supported HashRef forms, exact digest bytes, canonicalization ID
and URI. No hash algorithm is silently computed or converted by this interpretation.

These are **publisher-attributed delivery claims**. An EIP155 endpoint names a
recipient; it does not prove transport or receipt. The contract establishes onchain
availability and exact endpoint coverage, never truth of the external delivery
assertion, public web availability, runbook authorization or institutional acceptance.
Those operational checks remain required. The notice and later recovery evidence
bind the exact scheduled manifest; this additive evidence does not rewrite the
immutable manifest bytes or claim a new manifest field was present originally.

`recoveryNoticeClaim(actionId, 0)` returns the retained pointer and exact
`abi.encode(runbook, publicNotice)` bytes. Indices `1..deliveryCount` return exact
`abi.encode(Delivery)` bytes in endpoint order. Each immutable chunk is at most
8192 bytes; the complete publication can span many chunks. A designation's complete
8192-byte canonical payload controls its endpoint set, without an arbitrary
eight-entry limit. Historical reads check each retained chunk hash and do not
depend on today's owner, steward, schema status, Executor or recovery readiness.

## Incremental immutable publication

Use `IStreamOwnerPreparedRecoveryNotices` for endpoint sets whose complete publication
would be too expensive in one call. It adds three guarded writes while retaining
`openRecoveryNotice` and the existing notice/evidence interfaces:

1. `prepareRecoveryNotice` authenticates the complete original designation once,
   snapshots its current owner and durable per-author head, publishes the runbook
   and public-notice references, and commits the required ordered endpoint tuples.
2. The original publisher calls `prepareRecoveryNoticeDelivery` once per endpoint,
   in order. Each call preserves the full `Delivery` ABI bytes in an immutable
   chunk. The final row must complete the exact expected endpoint commitment.
3. Anyone may call `openPreparedRecoveryNotice` with the complete governance batch
   and original request. It rechecks the current owner and exact designation head,
   authenticates the full action, and atomically creates the final notice snapshot.

The private reconstruction keeps every original field and canonical JSON byte,
including exact Unicode/escape values and inactive-union checks. It compares the
complete result to the payload hash at the actual per-author steward head. That
head can only have been admitted by the original registered-profile serializer,
which already rejected duplicate endpoints. Reconstruction therefore omits a
second quadratic uniqueness scan; duplicate or reordered witnesses fail the whole
payload hash comparison. The existing serializer and original admission are
unchanged. Repeated string concatenation remains, so this is not a claim that all
preparation work is asymptotically linear.

Preparation creates no notice, elapsed clock or recovery eligibility. The 72-hour
clock, expiry check, original response-lane barrier and complete candidate tail are
captured at final opening, including responses published during preparation. A
failed final opening rolls back consumption of the plan. A changed owner or
current designation prevents opening; the original A-to-B-to-A owner reactivation
continues to use its durable original head, without a custody-epoch condition.

The plan ID binds a versioned domain, chain, host, publisher, caller nonce, token,
action, opening owner, original designation head and base-publication hash. The
nonce separates preparations; it is not an owner signature or a globally consumed
authorization nonce. A completed plan permanently freezes its count, ordered root
and claim handles. It cannot accept another delivery. Earlier wrong rows cannot
be edited; that publisher can prepare a new plan. Incomplete plans remain attributed
publication history and can never become valid notices through missing endpoint
coverage.

Final opening has no endpoint loop or full designation serialization. It uses the
saved original publisher in the same publication/evidence hash as the original
opening path. `OwnerRecoveryNoticePreparedOpening` separately identifies the
finalizer; finalization never lets a relayer replace references or become their
author. Each endpoint commitment includes every canonical tuple field and its
index. Original reference algorithm, canonicalization ID, digest and URI bytes
remain intact, including opaque multihash/CID commitments.

`recoveryNoticePreparation` reads the stored plan summary;
`recoveryNoticePreparedClaim(id, 0)` reads the original base publication and higher
indices read original deliveries. `recoveryNoticePreparationFor(actionId)` links an
opened notice to its plan. The existing `recoveryNoticeClaim` also returns these
same original pointers and bytes for a prepared opening. Prepared carrier reads
verify the STOP prefix, bounded code length and full original bytes hash. Historical
reads do not revalidate current owner, interpretation status or action readiness.

For maximum 2048-byte URIs and 128-byte opaque digests, the base claim's complete
ABI encoding is at most 4800 bytes and a delivery's is at most 4672 bytes, below
the existing 8192-byte immutable chunk limit. Endpoint count remains controlled by
the complete original designation's 8192-byte canonical payload; no new item cap
or field omission is introduced. The final snapshot stores the aggregate publication
commitment and a link to the immutable plan instead of copying all delivery handles.

## Responses and complete processing

`recordRecoveryResponse` and `recordRecoveryResponseFor` validate the exact complete
`STREAM_RECOVERY_RESPONSE_V1` payload, its supported profile and JCS definition
against the actual registered immutable bytes. Retired definitions remain readable.
The existing direct current-owner check or original EIP712/ERC1271 authorization
determines the author. A relaying steward remains a relayer. An independent steward
or borrower speaking for itself must use the independent carrier.

Canonical responses remain appendable before a notice, after its minimum wait,
after expiry/cancellation/execution, and while the Executor or recovery dependency
is unavailable. Record time proves custody at that publication only. Former owners
cannot sign later after transfer, and no custody-epoch claim is inferred. Source
`effectiveAt` is retained without controlling the notice clock or response order.

Each original is atomically appended to the candidate queue for the exact
`(token, action ID, manifest hash)` pair. Opening adopts the full existing queue,
including pre-opening objections; a permissionless opener cannot hide them. The
saved original lane-index barrier distinguishes before/after opening even within
one timestamp. It is a publication-order diagnostic, not proof that governance had
already scheduled the action when the statement was written.

Anyone may process exactly one next response with `processRecoveryResponse` while
the action is SCHEDULED and its saved binding remains live. Processing follows
original order. The latest qualifying response per `(token, action, owner-author)`
replaces that author's prior counted class. Checked counters decrement/increment
atomically; originals remain permanent. A transfer does not erase a prior owner's
response. Responses at or after the minimum notice end carry a late label and
remain operative until execution or expiry, without restarting the wait.

Processing failure leaves the original record and pending candidate intact. The
callback requires **processed cursor equals the complete candidate tail**, including
after the 72-hour end. It cannot snapshot a stale count while any matching original
is pending. The evidence revision and rolling evidence hash advance only when the
operative response head changes; an empty processing call is idempotent. Once the
action closes, later documentation remains historical and cannot make it executable.
No acknowledgement or objection count automatically vetoes or shortens the window.

The original queue, temporal labels, raw receipts and replacement history remain
available even if current evidence is invalid. The recovery companion independently
stores the exact evidence hash, revision, end and counts consumed during execution.
Later owner documentation does not mutate that immutable execution snapshot.

## Current liveness, gas and composition boundary

The six-word callback checks the exact scope/manifest, elapsed clock and complete
processing, then the saved action's current graph, code, calls commitment, class and
window. SCHEDULED actions qualify; EXECUTED actions qualify only inside the exact
current Executor recovery-call context. Historical EXECUTED status alone is false.
This is owner-notice action liveness, not complete recovery readiness. The actual
companion performs its own full preparation before and after reading owner evidence.

The new `OWNER_RECOVERY_INTENT_READ_GAS` parameter starts at 8,000,000 with the same
floor and fail-closed precheck class 2. It applies only to admission's expensive
staged-intent read. Raises use the unchanged GasHost class-1 delayed authority and
at-most-twofold step rule. The existing metadata dependency and signature parameters
are unchanged. The verifier's separate actual-companion maximum-request measurement
is retained in its guide; it is not a whole-current-stack cold measurement.

OwnerRecords keeps its existing mapping roots at slots 4 through 10. Append/read
and signature preparation are linked helpers receiving explicit map references;
no aggregate storage overlay or caller-selected storage root is exposed by the host.
The shared guard surrounds original publication, typed queue linkage, notice opening
and processing. The notice state begins after the existing steward mapping; prepared-plan maps append
after the original notice roots. Original record and notice getters keep their typed
ABI and return the linked helper's exact canonical encoding without an extra full
tuple decode/re-encode. Signature preparation still precedes append inside the same
guarded transaction and retains its original nonce, domain and rollback behavior.

Focused tests use real OwnerRecords, SchemaRegistry, DocumentStore and threshold
Safe. A separate composition also uses the actual registered recovery companion,
while Core, Executor, artist/Consent and original finality are explicit boundary
fixtures. It proves immutable executed evidence, pending-tail rejection followed by
identical-request retry, and changed original lineage rejected by the companion
even while the deliberately lighter notice liveness remains true.

The named callback probe cools OwnerRecords, NoticeState, ActionReads, Core, Executor
and the actual recovery companion before each read. Its exact 192-byte result fits
500,000 gas in SCHEDULED and active EXECUTED contexts: measured enclosing call costs
are 105,205 / 122,513 in default and 104,573 / 121,963 with IR. This covers that
explicit graph, not the full current Core/Executor/artist deployment or every future
provider. The companion execution test separately exercises its preparation before
and after reading the actual owner evidence.

The original five-delivery opening remains a supported convenience path with cost
proportional to its full publication. A retained default predecessor measured
45,171,830 gas for its maximum-URI example. Validation without discarded JSON or
revalidating already authenticated steward endpoints reduced the same example to
21,863,647. Neither figure is an all-valid-shape transaction-capacity claim.

The designation writer now checks uniqueness by sorting a separate array of exact
canonical contact hashes. It retains the original contact/JSON order, validates
every row once, and joins the collected rows once. The uniqueness work is bounded
by O(n log n), with no recursion or item-count cap. All original tuple/inactive-field
and complete-payload limits remain; inputs with multiple distinct errors still
reject, without promising which competing error is reported first.

The exact 8192-byte, 214-short-endpoint original designation write costs
13,074,681 / 13,626,093 gas in the named-target cold enclosing-call probe, below
its 16-million test bound. A separate retained maximum-payload/2048-byte-record-URI
case costs 13,323,571 / 13,798,640 in the direct callee trace. These measurements
include the separately reviewed shared JSON escaping implementation; the Fields
change alone did not close the writer capacity gap. They cover the specified
shapes and cold targets, not every possible lexical shape or a network limit.

The final named-target cold capacity measurements are individual enclosing calls,
excluding transaction intrinsic gas. Each figure below gives default / IR gas:

| Exercised shape | Begin preparation | Largest single delivery | Final opening |
| --- | ---: | ---: | ---: |
| Exact 8192-byte designation, 214 short endpoints plus owner | 11,126,373 / 11,366,693 | 307,587 / 307,793 | 694,799 / 689,613 |
| Exact 8192-byte designation, maximum reference URIs, five deliveries | 9,002,832 / 9,311,757 | 1,815,594 / 1,902,103 | 695,614 / 690,432 |
| Absolute 4800-byte base and 4672-byte delivery encodings | 6,482,597 / 6,722,621 | 1,826,054 / 1,912,533 | 694,835 / 689,649 |

The exact 8192-byte escaped-name case begins at 4,760,274 / 4,855,301 gas. The
214-endpoint case also rejects a next entry in that same canonical family; it is
not a universal maximum over all lexical combinations. The final opening performs
no endpoint traversal. An actual companion's complete 24,544-byte registered request
is separately admitted at final opening for 6,782,262 / 7,641,804 gas, with the
existing dedicated intent cap. Those direct dependencies are named explicitly in
the test. This is not a whole current-stack cold transaction bound.

The original staged-input and full-witness requirements remain intact. All prior
119 behavioral names pass in the matching 131-case cohort in both profiles, along
with exact original-publication/evidence parity, maximum ABI chunks, malformed
witnesses, queue/clock timing, actual threshold Safe calls and actual companion
execution. No network transaction limit or release gas gate is waived. The measurements borrow the exact shared JSON escape implementation from
`e9b6a7bcb6a3e08ffe8ef8c117644c0eae5426ff`; that dependency remains owned and
committed separately from the contact writer change. The host ABI, storage,
signature preparation, nonce ordering and notice/response state are unchanged.

Actual full current Core/artist/Executor/companion composition, wider
collection/release/season/view affected-token inventory and runbook routing,
public delivery operations and institutional acceptance remain separate required
work. Unsupported wider scopes reject notice opening in this first profile; their
full protocol requirements are not removed.
