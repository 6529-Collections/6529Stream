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
and processing. The new notice state begins after the existing steward mapping.

Focused tests use real OwnerRecords, SchemaRegistry, DocumentStore and threshold
Safe. A separate composition also uses the actual registered recovery companion,
while Core, Executor, artist/Consent and original finality are explicit boundary
fixtures. It proves immutable executed evidence, pending-tail rejection followed by
identical-request retry, and changed original lineage rejected by the companion
even while the deliberately lighter notice liveness remains true.

The named callback probe cools OwnerRecords, NoticeState, ActionReads, Core, Executor
and the actual recovery companion before each read. Its exact 192-byte result fits
500,000 gas in SCHEDULED and active EXECUTED contexts: measured enclosing call costs
are 105,181 / 122,489 in default and 104,585 / 121,975 with IR. This covers that
explicit graph, not the full current Core/Executor/artist deployment or every future
provider. The companion execution test separately exercises its preparation before
and after reading the actual owner evidence.

Maximum payload preservation is not a transaction gas acceptance. In the retained
default fixture, an 8192-byte steward record call costs 15,980,612 gas, opening with
2048-byte runbook/public-notice and five delivery-reference URIs costs 45,171,830,
and an 8192-byte response call costs 17,044,680. Those are individual traced contract
calls, exclude transaction intrinsic gas, and are not cold current-stack bounds.
Publication currently builds JSON while validating references although it retains
ABI bytes; eliminating that discarded serialization is a possible narrow follow-up.
No chain transaction ceiling or release gas gate is waived by these harness passes.

Actual full current Core/artist/Executor/companion composition, wider
collection/release/season/view affected-token inventory and runbook routing,
public delivery operations and institutional acceptance remain separate required
work. Unsupported wider scopes reject notice opening in this first profile; their
full protocol requirements are not removed.
