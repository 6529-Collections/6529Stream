# ADR 0039: Canonical Finality Governance and Evidence

## Status

Accepted design for autonomous implementation on 12 September 2026. Executable
source, behavioral tests, deployment proofs and current-stack integration remain
separate acceptance gates. The first milestone is a real ONCHAIN collection;
COLLECTION, TOKEN, RELEASE, SEASON and VIEW remain required finality scopes.

This decision explicitly amends the pre-genesis original-finality governance
profile in addition to the recovery direction in
[ADR 0020](0020-executor-only-finality-recovery.md). It does not mark that older
proposal or its unimplemented dependencies complete. The integrator owns current
metadata, discovery, entropy and owner-recovery evidence producers. The artist
builder owns finality, sanction, confirmation, the recovery companion and the
necessary archival coverage extension.

## One governance lifecycle

The actual canonical Governance Executor owns proposal, delay, guardian veto,
cancellation, expiry and retry. Finality execution accepts only the immutable
Executor during a nonzero executing TERMINAL_FREEZE action, class 2. Its exact
192-byte `currentAction()` must match the current call's scope and old/new state
commitments. A batched action's first target or aggregate scope is not a
substitute for the active call context.

The actual stored governance action supplies the proposer; `currentAction()`
does not. The target observes the action as EXECUTED during execution. A bounded
canonical read of the action, including its dynamic reason URI, must identify
the recorded proposer without an unbounded returndata allocation. The canonical
RoleRegistry must be owned by that Executor, and the recorded proposer must
currently hold `ROLE_COLLECTION_FINALITY_ADMIN`. Neither the Executor address
itself nor the permissionless transaction submitter substitutes for that role.

The original registry's local `scheduleArtworkTerminalFreeze`,
`vetoArtworkTerminalFreeze`, `cancelArtworkTerminalFreeze`,
`materializeExpiredArtworkTerminalFreeze` and `artworkTerminalFreezeAction`
selectors remain ABI-visible but revert with an explicit retired-lifecycle
error. They provide no second clock, pending map or success path. Existing local
storage declarations remain reserved so unrelated physical storage does not
move. Published historical event and type declarations remain available.

Permanent finality records, their hash preimages, component arrays, finalize
payloads, executed freeze reads and route reads retain their meaning. Additive
typed context reads supply canonical target-side commitments. Candidate
evidence, hash and context reads remain callable outside an executing action;
they build or validate canonical per-call commitments and report authority
readiness separately. Only mutation admission requires the active Executor
context. Preview tooling cannot infer a second pending action from the retired
getter. Recovery likewise stores only
executed append-only lineage, with the canonical action ID as execution identity.

## Constructor and selected-pointer identity

The staged canonical foundation in
[ADR 0032](0032-governance-foundation-before-product-activation.md) precedes
product construction. The facade and its fixed reader/writer children embed only
the predicted Coordinator address. Deploy those artist contracts first; the actual
MetadataV1 host can then pin the completed facade runtime, followed by the typed
provider, ArtifactCoverage and Finality. The Coordinator is constructed last at
its predicted address, with the actual Finality address and completed runtime hash
included in its fixed configuration. The facade exposes these pins through that
one constructor-fixed Coordinator. SuiteConfiguration's existing tuple stays intact.

This order avoids an indirect runtime-hash cycle: MetadataV1 embeds the facade
codehash and Finality embeds metadata/provider hashes. Neither Finality-derived
configurationHash nor Coordinator runtime hash may be embedded back into facade
or child runtime. The Coordinator constructor validates Finality's Core, metadata,
sanction and artifact bindings. Finality's constructor does not call back through
the absent Coordinator. Predeployment facade reads fail closed; no absent code or
malformed result supplies default pins or readiness. Operative preparation later
requires the complete reciprocal joins and current selected pointers.

The definitive Finality constructor also pins ArtifactCoverage and canonical
module deployment/manifest configuration. ArtifactCoverage may already pin the
predicted nonzero Finality address; every operative coverage read requires the
real deployed and selected counterpart. The registry advertises the canonical
IStreamModule identity and the Core-required permanent primary finality interface,
with additive preparation, canonical context and archive interfaces advertised
only when their implementation is supported. Original six finality storage roots
remain physical prefixes; new module and witness state is appended.

Every finality-sensitive artist or registry operation requires the counterpart
to have the expected nonempty code, exact interfaces and reciprocal Core,
metadata and sanction bindings. It also verifies the actual Core-selected
finality pointer and its recorded code hash. A correctly deployed but unselected
registry cannot authorize a ceremony. There is no mutable bind function,
activation flag, fallback provider or zero-code success path. Actual CREATE
addresses, argument-inclusive initcode, links and immutable substitutions must
be independently bound before accepting the composed deployment.

## Exact producer evidence

The original five `IStreamFinalityMetadataReads` methods remain unchanged.
`IStreamFinalityScopeEvidence` adds the validating
`requireFinalityScopeInputs(scope, manifestContentHash)` read and an exact Core
binding. Its result is ten immutable evidence references followed by the actual
validated manifest schema and canonicalization identifiers. The ten fields, in
order, are root, snapshot, reference render, intent, intent waiver, interview,
rights statement, work description, render-critical evidence and bundle
coverage. Mutually exclusive or inapplicable fields follow explicit validated
record rules; arbitrary zero values do not mean complete evidence.

The independent scope-input commitment is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_FINALITY_SCOPE_INPUTS_V1"),
  chainId, actualCore, metadataHost, scope, inputs
))
```

`renderCriticalEvidenceHash` commits a canonical ordered set derived from the
authoritative scope/source inventory: actual payload identities, immutable byte
hashes, serving routes and applicable evidence references.
`bundleCoverageHash` commits validated family-qualified coverage of that exact
set, including its count and applicability rules. Neither set nor count comes
from a caller's unsupported assertion. Unknown scope/component IDs fail closed;
retained burned tokens remain members where the canonical scope requires them.

`IStreamFinalityComponentFacts` supplies exactly the actual host's frozen flag,
module version, manifest hash and data hash for a component family and scope.
Each component adapter fixes its host, family, Core and metadata identities in
construction, supplies its own interface/runtime identity, and uses the current
selected host with reciprocal bindings. It cannot accept a replacement target,
selector, expected hash or readiness flag from a caller.

## Non-circular sanction and archival joins

The scope-input, render-critical and bundle-coverage commitments exclude the
final sanction record and its signature, and exclude the finality manifest's
own content hash. The independent finality manifest may include the ten evidence
references or their resulting commitment. It is validated separately against
its stored bytes and exact schema/canonicalization facts.

The sanction ceremony binds the reviewed non-sanction inputs and canonical
sanction subject. After the actual sanction and signature exist, finalization
separately validates archival coverage of those exact record and signature
bytes, signer, authority class and subject. Coverage of a generic ceremony
document or a detached reference cannot stand in for that join. This preserves
the permanent sanction and finality preimages without a circular content hash.

Artist-bound finalization explicitly selects a typed archive proof containing
sanctionRecordHash, artifactHash and completionHash. A new typed finalization
and preparation entry carries that tuple; the canonical action's new-state
commitment binds its exact evidence key as well as the finality record. The
execution witness retains the selected proof. Execution rechecks retained
sanction, signature and ceremony bytes against the artifact and its current
coverage. Permanent sanction subjects and finality record preimages do not
change. Old artist-bound finalize entries fail closed without the required
proof; platform declarations remain a separate profile.

No permissionless latest-proof pointer selects evidence for a scheduled action.
Permissionless archival ingestion establishes content-addressed evidence only;
it does not authorize or replace the action's selection. An unrelated submitter
cannot redirect an otherwise valid prepared action to another family pair.
A failed current-coverage check leaves both execution and its selected witness
uncommitted, permitting the same action to retry after healthy revalidation.

The estate provider's exact public estate schema, 8192-byte bound and receipt
preimages remain intact. Finality artifact support uses separately versioned
schemas and actual bytes. It reuses the canonical immutable chunk/document
store rather than creating another schema registry. A whole-artifact coverage
claim requires the complete ordered set of actual bytes, correct whole length
and content hash, and independent qualifying family receipts and current fixity
for every required part. A manifest or one chunk is not proof of its referents.
Incremental admission must bind one immutable artifact/family/provider context;
duplicates cannot fill missing positions. Larger multipart executable archives
require an explicit complete profile, not a relaxed manifest-only shortcut.

The first whole-object profile partitions actual bytes into at most 64 parts:
every non-final part is 8192 bytes, and the final part is 1–8192 bytes. The
artifact retains exact ordered part hashes and lengths. Equal bytes at different
positions are legitimate. Each pointer must be the actual canonical chunk-store
pointer for that content, with matching STOP-prefixed bytes, length and codehash.
Chunk-envelope commitments include the pointer and codehash; an alternate
identical-byte pointer cannot preempt the canonical record. Estate envelope and
receipt/signature preimages remain unchanged.

Original artifact completion is immutable and suitable for the signed/scheduled
candidate commitment. Its epoch and evidence-chain fields describe its original
coverage, not the latest validation. A separate current-validation record checks
every ordered part against fresh provider environment and epoch facts. Only the
current healthy fixity and corresponding coverage-record references may change;
the original artifact, envelope, receipts, family pair, checkpoint and proof
profile must remain exact. A new object, receipt or family needs a new completion.
All parts must validate under the same current epoch before the cache becomes
usable. Failed or interrupted revalidation never makes an old cache current.

The conservative global provider epoch advances on a family status transition or
replacement fixity, including an unrelated receipt. This may require bounded
revalidation, but never changes the original completion. Scope inputs, component
data hashes, manifests and sanction subjects must commit that original evidence,
not the mutable validation-record head. Routine healthy fixity refresh therefore
does not restart a scheduled terminal action. Current admission checks the fresh
cache and external pins separately; historical records remain readable.

## Typed sanction recording and archival interpretation

The first executable recording profile uses operation 12 with a real, nonempty
signature by the current principal: AUTH_ARTIST or a current AUTH_SUCCESSOR
with CAP_SANCTION. It supports an accepted binding without a collaborator
threshold. Delegate, steward and collaborator-threshold sanction paths remain
separate full-v1 obligations. A direct principal transaction does not replace
the required retained signature with an empty DIRECT proof.

Preparation derives the subject and review facts from the fixed validated
provider. The first ONCHAIN review profile has one actual content root, no media
hash entries and exactly one reference-render artifact content hash. The typed
serializer retains ordered identities, validates UTF-8 and emits the exact
bounded RFC8785 ceremony. The ceremony's custom JSON Schema profile annotations
are normative producer/consumer rules; an ordinary JSON Schema validator does
not automatically enforce them. Permanent EIP712 terms and the fourteen-word
sanction-record hash are unchanged. Deadline and observed signedAt remain
separate facts.

The full archive object has its own versioned binary schema and canonicalization:
a 24-word ABI head followed by canonical ceremony and signature byte tails.
The complete object, at most 13,120 bytes in this profile, is archived. Its whole
hash includes the retained signature and every offset, length and padding word.
It contains no self-dependent archive hash. The registered definition documents
are in [the finality schema directory](../schemas/finality/). Archive-proof
finalization checks all four exact interpretation definitions, their registered
kinds and names, and their actual retained bytes against fixed content hashes.
Retirement does not invalidate those existing interpretation references; there
is no incidental ACTIVE-only revocation of a historical sanction schema.

Consent remains the sole record owner. Its constructor-fixed writer executes
only explicit callbacks in the Consent host context and preserves the common
physical storage layout. The facade retains its original writer and reader
children at nonces 1 and 2 and adds the fixed sanction/finality reader at nonce 3.
Relocated digest reads retain the Coordinator's deployment chain, the facade as
verifying contract, and the exact bound Core and MintManager. Deployment evidence
must include child runtimes and argument-inclusive parent initcode, not runtime
size alone.

## Recorded sanction continuity and confirmation

A new sanction requires the actual current authority and its applicable sanction
capability. AA-GUARD4 rejects new sanctions and authorizations while the Identity
is contested. That rule does not retroactively invalidate an existing sanction
or independently prohibit its consumption by finality. AA-SANCTION1–3 instead
requires the exact current subject and a collection attribution that is neither
disputed nor revoked. The platform-works contest stop is a separate scope rule.

A recorded sanction remains usable across an authority-address rotation or
estate succession that preserves artistId, binding generation and binding hash.
The recorded signer and authority class remain immutable. Corrective rebinding,
collection dispute/revocation or subject drift rejects consumption. An Identity
contest alone does not rewrite historical sanction evidence or add a new
saved-sanction invalidation predicate. This differs from an unused publication
authorization, which must still identify the current signer when it is consumed.

Operation 13 is permissionless confirmation of an already executed COLLECTION
finality. Its ActionContext and Archive actor remain the actual transaction
caller. The Archive payload separately joins the saved sanction signer/class,
association, sanction record and executed finality evidence. Attribution uses
the saved authenticated class for the transition; the caller is not represented
as the historic signer. Confirmation consumes no Identity signature nonce,
records no living-authority action and fabricates no new primary sanction.
Scoped finality does not elevate collection attribution.

For canonical operation 13, confirmation uses the Coordinator's constructor-bound
original Finality registry and runtime, its immutable executed COLLECTION record,
canonical stored component array, and recorded governance and archive witnesses.
It does not follow a replacement Core finality pointer or revalidate current
discovery, provider readiness, coverage, observer roles or signer capabilities.
Repeat those historical reads and deployment identities under the operation lock,
require exact raw bytes and decoded facts, then recheck the live binding and
accepted Attribution state before either owner writes.

This pre-genesis decision explicitly supersedes the
`row_predicates.row_13` requirement `verify.currentRouteMatches equals true` and
the corresponding `reread_policy.row_13` requirement in the
[frozen finality dependency supplement](../../release-artifacts/issue-670-adapter-freeze/finality-dependency-supplement-v1.json)
for canonical operation 13. The frozen packet remains unchanged.
`verifyFinality` remains a current-route diagnostic, with no fallback role in
confirmation admission. Other applicable strict ABI, deployment, repeated-read,
association and event requirements remain. Canonical confirmation must not be
represented as literal conformance with those two retired packet predicates.

ConsentFinality owns the single-use finalization-transition replay key, followed
atomically by Attribution's accepted-to-sanctioned state change. Each owner
checks operation 13 and its exact snapshot and commits once. Neither callback
creates a new primary record. The newly explicit replay scope is
`keccak256(abi.encode(keccak256("6529STREAM_ARTIST_SANCTION_FINALIZATION_TRANSITION_V1"), collectionId, artistId, bindingGeneration, sanctionRecordHash, finalityRecordHash, priorAttributionState))`.
Those six fields retain their frozen order; the prior state is the actually
observed accepted state 2. The existing owner V2 replay wrapper binds the scope
to its chain, facade, Coordinator, Archive and Consent owner using surface
`consent_finality.replay.sanction_finalization_transition_key`. The historical
mechanics packet left that exact replay scope schema unresolved; this tag and
scope encoding are new implementation definitions. Already sanctioned state 3
cannot append a second confirmation. The Attribution event uses the sanction
record as `recordHash`, executed finality record as `reasonHash`, empty reasonURI,
actual caller as actor and the saved sanction authority class. Late owner or
Archive failure reverts both revisions, replay, state change and event.

The observation decoder admits at most 32 ordered components and a conservatively
bounded 32,768-byte stored URI. The latter is a read ceiling, not a claim that
such a URI fits the registry's finalization calldata limit. Both complete record
reads validate its exact ABI offsets, scalar widths, padding and URI hash. The
operation Archive carries the static record facts, its URI hash and
`keccak256(abi.encode(fullStoredRecord))`; the original complete URI remains in
the pinned immutable Finality record. Together with the ordered components,
saved sanction, execution and archive witnesses, and read transcript, this makes
the operation evidence exactly `3744 + 224 * componentCount` bytes (10,912 bytes
at 32 components), within ArchiveV2's 24,575-byte limit. The operation evidence
does not replace the separate whole-artifact archival requirement for finality.

`StreamArtistAttributionPolicy.acceptedOrSanctioned` applies only to Attribution
states 2 and 3. It composes the Onboarding accepted-binding and artist reads,
content/sale binding reads, commercial association read, and attestation,
publication and saved-sanction reads. Every existing Identity classification,
current signer, binding generation, capability and consent predicate remains
separate. Defensive state-4 paths retain their existing explicit exceptions;
confirmation itself still requires prior Attribution state 2. No Identity state
or authority class is interpreted using this Attribution predicate.

Required controls distinguish new sanction rejection during Identity contest
from preserved historical sanction/current consumption, and separately prove
that a real collection dispute stops consumption. Rotation/estate continuity
must preserve both the recorded sanction and its permanent subject preimage.

## Recovery approval and unavailability admission

The integrator authorized the canonical recovery companion and artist operations
22/23 implementation on 12 September 2026. This supersedes ADR 0020's historical
unassigned-owner/source-authorization block for this implementation lane; it
does not turn that proposal's unimplemented interfaces into release evidence.
The integrator owns actual OwnerRecords notice/evidence and Core/router wiring.
The artist/finality builder owns approval, finding and companion mechanics.

Operation 22 preserves the original seven-field `StreamArtistRecoveryApproval`
typed payload and twelve-word permanent approval record. Its original Finality
address, record hash and recovery-manifest hash are exact. Fresh admission must
validate the actual staged canonical recovery intent and current sanction-class
authority, including each applicable collaborator or delegation rule. Identity
association, deadline, digest and retained proof are separate immutable evidence;
they do not enter the permanent record preimage. Saved approval verification
does not repeat current signer/capability, deadline or digest-revocation checks.
Same-association rotation/estate preserves consumed approval. Adjudicated
association supersession remains distinct from ordinary authority succession.

The scoped-authority sentence in AA-RECOVERY is clarified in the context of
its explicit first requirement and ADR 0013 U4: living `AUTH_ARTIST` remains
eligible for supported scopes. The exclusion for TOKEN, RELEASE, SEASON and
VIEW applies to `AUTH_STEWARD`; successor/delegation still requires
`CAP_SANCTION` and the applicable collaborator policy. The parallel sanction
text describes scoped *posthumous* finality. This is an explicit pre-genesis
clarification of the recovery sentence's omitted lifetime-artist case, not a
claim that its literal abbreviated list already says the same thing. Approval
binds the original Finality record and manifest, without a new action-ID field;
the companion binds and records its selected evidence separately per action.

The proof backlink in AA-RECOVERY requirement 3 is represented by ADR 0020's
immutable executed recovery record: it stores the original staged manifest and
the exact eleven-field evidence snapshot, and the executed `recoveryRouteHash`
commits to both. The original signed/staged intent remains proof-free; it does
not contain a future approval or finding hash. An optional serialized execution
evidence document must use its own schema, content hash and URI while referencing
those exact stored facts and the original manifest. It must never reuse the
staged manifest's content hash or URI to imply that these are identical bytes.

Operation 22 resolves the previously unspecified
`consent_finality.replay.recovery_approval_key` scope as
`keccak256(abi.encode(keccak256("6529STREAM_ARTIST_RECOVERY_APPROVAL_KEY_V1"), artistId, bindingGeneration, bindingHash, ApprovalTerms))`
inside the existing OwnerReplayV2 envelope. This is a new implementation
definition, not a retroactive claim that the foundation packet already pinned
the key. An exact association and terms select one immutable record; a global
latest record across different artists or associations cannot shadow it.
Any corrective association or adjudicated supersession must be established
through its actual authorized record path. A differing generation or binding
hash alone is not proof of adjudication. Historical approval records and
already executed recovery evidence remain available after such transitions.

Operation 23 preserves the original ten-word permanent finding record. Its
`governanceActionId` is the actual class-2 arbiter action that records the
finding, never the separate recovery action. Supplemental immutable admission
binds one actual recovery companion/runtime, one canonical scope, one original
Finality record, one recovery manifest and one recovery action. It also retains
the actual binding association, notice duration/revision, authority-activity
epoch and governance witness. These fields are archived with the finding but
do not alter its original hash or event. The default artist notice is 90 days
with the existing 30-day immutable floor; observed inclusion time determines
the exact notice end. Later timing changes cannot rewrite it.

Two previously unspecified edges are explicitly decided for this pre-genesis
implementation. Successful authenticated CURRENT artist-authority activity
invalidates unexecuted fallback use both during the notice and after its end.
This extends AA-RECOVERY's literal during-notice rule to pending use; it is not
claimed as unchanged packet semantics. Same-block activity must invalidate the
finding, and any later owner/Archive failure must roll that invalidation back.
The activity predicate is separately authenticated current authority, including
an actually eligible successor or delegation path. It is not inferred from a
nonce change, an arbitrary owner commit, a permissionless confirmation, a
guardian/governance action, a passive read or a failed authorization. The estate
living-principal cancellation rule remains separate.

A finding is not a reusable blanket recovery permit. It can authorize only its
one immutable companion/action/scope/intent association. The companion's exact
canonical action replay supplies single consumption; a duplicate Artist
consume operation is unnecessary. Executed recovery history retains the saved
finding and notice end without repeating current activity or readiness reads.
An earlier live finding cannot be replaced merely by asserting its recovery is
terminal: admission must read authoritative action terminality or prove its
activity cancellation. Each new recovery action needs a new bound finding and
full notice, including after veto, cancellation or expiry of the earlier action.

The recovery action is scheduled with a future `notBefore` after the prospective
artist notice, then the finding is recorded for that exact action. Governance
already permits a future start, requires a seven-day open interval for delayed
classes, and bounds expiry to 365 days from scheduling. Finding admission checks
the actual scheduled action and enough remaining time for its observed notice;
an action scheduled too early does not borrow elapsed notice. A longer configured
notice must still fit the canonical action window. Recovery request/intent and
action commitments exclude future finding/approval/owner-evidence heads, so this
ordering creates no hash cycle. OwnerRecords retains its distinct action-bound
72-hour notice and expiry/new-action rule.

The narrow `IStreamArtistRecoveryIntent` read must derive the exact three
governance commitments and request hash from retained canonical intent bytes,
original Finality and route lineage on the selected companion. Its inputs are
the canonical scope, original record and manifest hash. It does not accept
caller-supplied ready flags or replace validation with a detached hash. The
artist ingress and the final companion execution independently repeat current
pins and exact fact joins. The six encoding and six state-harness tests are
bounded prerequisites; they do not establish this actual producer, artist
ingress, canonical governance, fallback execution or owner-notice composition.

The admitted finding additionally commits to the exact four-word recovery-intent
facts hash (scope, old state, new state and request), separately from the manifest.
Current-use reads recompute it. Scheduling evidence in the artist layer establishes
an actual class-2 scheduled action and its window; the action header's target and
selector identify only the first batch call and do not prove a later call's contents.
The companion must match the actual executing action and per-call context to all
four saved intent facts before consuming fallback evidence. No batch-membership
claim is made from the header alone.

Current candidate preparation checks all immutable artist suite code pins and
current Core-selected artist/recovery target code, primary module identity and
current ModuleRegistry eligibility. The recovery discovery identity remains
ADR 0020's `STREAM_ARTWORK_FINALITY_RECOVERY` / `0x83685f5c`, never the additive
intent caller subset. Incident suspension stops admission and current use;
immutable executed history remains separate. Operation 23 is included in the
Coordinator's supported-operation configuration commitment.

Size-driven extraction preserves explicit selectors and constructor topology.
Identity registration and delegation revocation execute in its existing first
writer; the two delegated economics/freeze callbacks execute directly in its
second writer, while the first writer retains compatibility forwarding through
the Identity's immutable second-child getter. Every callback validates its fixed
host and retains one owner check/commit. The facade's third reader and the
Coordinator's original Reads child use linked constructor helpers with CREATE
in the original creator context, preserving their nonces and arguments. The
facade policy digest remains in its fixed reader with the same environment and
preimage. No mutable binding, storage routing table or new constructor argument
is introduced.

Guardian-only approval 30 and role-only contest 33 do not establish activity,
even when the account also holds current artist authority. Rotation veto 31
has an independent current-principal admission branch; only that successful
branch invalidates a pending finding. This finding-only exception does not
change the separate estate living-principal cancellation rule.

## Recovery approval admission and saved association

Operation 22 preserves the seven signed fields and twelve-word permanent
approval preimage. Fresh admission validates the actual selected recovery
companion's retained intent, the exact original executed Finality record and
its unique stored `ARTIST_SANCTION` component and archival/execution witnesses.
The original saved sanction in the pinned Consent owner determines the artist
association. Its supplemental generation and binding hash are authenticated
by that immutable owner code; they are not falsely described as fields in the
permanent sanction hash.

The first implementation admits the current living principal or activated
successor with `CAP_SANCTION`, an empty collaborator set and canonical empty
capability-policy set. It supports the actual stored record path for each of
COLLECTION, TOKEN, RELEASE, SEASON and VIEW, with the requested scope exactly
equal to the authenticated original record's scope. New scoped recovery that
inherits collection finality under ADR 0020 is not admitted by this increment;
that requires the later companion lineage and admission path. The saved
verification tuple does not imply inherited-scope admission. Delegation,
steward authority and collaborator-threshold approval are separate remaining
branches. A direct
approval requires the actual caller to be the current principal, an empty
signature, the current shared nonce and an unexpired explicit deadline. A
relayed approval validates the permanent digest and deadline through the
existing signer verifier. Identity consumes its normal nonce/digest lane and
authenticated activity, then Consent records one immutable approval under the
new association replay scope. One Archive append binds the actual caller,
both owner transitions and exact preparation observations; late failure rolls
all of them back.

New admission requires the current accepted-or-sanctioned Binding association
to equal the original executed sanction association. The permanent
`verifyRecoveryApproval` read instead selects that original association and
exact original-record/manifest terms. It does not re-read current Binding,
Attribution status, authority address, capability, deadline, discovery,
coverage or Core pointer selection. Ordinary rotation, estate succession and
Identity contest cannot silently turn historical approval into an unused
authorization. Every entry retains the Coordinator's complete suite runtime
checks, including the Consent owner whose supplemental fields authenticate
the original association. The verifying read proves saved consent, not
current recovery-route readiness or that a recovery action can execute.

Corrective-association adoption and adjudicated identity supersession are not
implemented by this first profile. A mismatching current generation/hash is
rejected for fresh admission as unsupported; it is never treated as proof that
a saved approval was adjudicatively superseded. A later supported adoption
must consume the actual authoritative owner proof before selecting another
association. Raw records and exact-association lookups remain immutable and
available independently of that future selection policy.

The two existing facade delegation digest bodies move to its existing fixed
finality reader for size, preserving their exact preimages, constructor
topology, deployment chain ID and facade verifying-contract environment.
Operation 22 is added to the Coordinator configuration commitment; no new
constructor argument or mutable target binding is introduced.

## Recovery batch classification and companion cutover

The canonical Executor and its fixed scheduling library validate recovery
composition after the existing action catalog has authenticated every target,
selector, runtime and value. Both passes use the complete published call list
and its exact retained calldata. A recovery selector may appear at most once
across all targets and scopes, only under class 2 with value zero and a
canonically encoded complete request. Its target must identify the exact
recovery module/interface and reciprocally bind the same Core and Executor.
These classifier facts do not establish current module eligibility, artist or
owner evidence, original-finality lineage or replacement-route readiness;
the operative companion must validate those independently.

An update of the actual Core's `ARTWORK_FINALITY_RECOVERY` pointer has exact
68-byte calldata, canonical address encoding and value zero. When the current
pointer is nonzero, the immediately preceding call must be that current old
target's exact four-byte zero-incomplete assertion, also with value zero. An
initial zero-pointer installation needs no predecessor assertion. Only one
such pointer update is permitted in a batch. Execution repeats this check
against the then-current pointer, so an earlier scheduling observation cannot
authorize a stale predecessor. The stored pointer status is installation
history, not a substitute for the live ModuleRegistry eligibility read.

Focused classifier tests cover complete calldata and batch shape. Separate
composition uses actual Core, Executor, ModuleRegistry, SystemManifest and a
threshold Safe, with an explicitly limited companion target fixture: initial
installation, late assertion rollback and exact retry, a changed predecessor
between scheduling and execution, published-byte/runtime rejection and the
second call's distinct execution context. This does not complete the companion,
owner notice, inherited-scope admission or recovery serving implementation.

## Complete recovery request availability

The permanent staged recovery intent remains exactly 704 bytes. It commits
both URI hashes but cannot reconstruct the URI strings needed by the existing
three-key artist preparation read. An additive permissionless
`registerFinalityRecoveryIntent(Request)` therefore retains the complete
canonical `abi.encode(Request)` under the same manifest content key, only after
checking the already-staged exact intent, owning chain/companion environment,
manifest URI hash and all other committed fields. Exact duplicate registration
is idempotent; it cannot replace the original request or storage pointer.

This interface is separate from the original sixteen-selector recovery
interface. Registration creates no authority, pending action, head, generation,
approval/finding evidence or route readiness. Current preparation and execution
must independently revalidate stored bytes, fixed bindings and current lineage.
Every stored-object read checks its initial runtime and complete content hash.

The first availability profile uses one complete SSTORE2 object. The canonical
request may occupy at most 24,544 ABI-aligned bytes, including both complete URI
strings; the next padded word fails. Its STOP-prefixed runtime is at most
24,545 bytes. URI validation here proves UTF-8 and exact byte/hash binding, not
a separate absolute-URI grammar. Larger request profiles and actual companion
scope/route/authority admission are separate work. The bounded storage tests
do not imply those operative gates have been implemented.

## First operative recovery companion profile

The companion retains the original sixteen-selector recovery interface and
adds the separate complete-request availability interface. Construction takes
five fixed targets (Core, Executor, original Finality, artist facade and owner
evidence), three independent governed read budgets, and immutable module
document identity. The facade supplies its fixed Coordinator; that Coordinator
supplies its complete owner suite and original Finality pin. Construction
checks reciprocal Core, Executor, roles and owner bindings, including the
owner-evidence ERC165 triad and exact `core()`/`governanceAuthority()` reads.
All required targets must already have code. Construction does not require
their current Core selection, allowing staged deployment before activation.

New preparation and execution require the exact current Core-selected companion
and artist, their pinned runtime identities, and current ModuleRegistry
eligibility. A staged intent and its immutable full Request establish byte
availability only. Preparation independently derives the original record,
current exact-scope predecessor/generation, old route and healthy frozen
replacement, then produces the four intent facts. Executor-only mutation checks
the actual class-2 per-call context, reads artist and action-specific owner
evidence, repeats preparation and context checks, and appends once under the
host mutation guard. The evidence snapshot is outside the staged intent and
inside the immutable executed record and recovery-route commitment.

The initial original-record branch requires authenticated artist-sanctioned
finality. It supports exact original records for all five scopes and inherited
COLLECTION-to-TOKEN route resolution using completed token lifecycle and
retained membership. New inherited RELEASE/SEASON/VIEW scopes remain unsupported
until the fixed metadata provider implements authoritative family-qualified
membership. The additive `requireRecoveryScope` interface is a boundary only:
its subject must be recomputed locally; COLLECTION/TOKEN manifest hashes are
zero, while other scopes require the exact family-qualified stored manifest
and its provenance. An old collection/scope-ID-only manifest is insufficient.

Route resolution does not widen the earlier operation-22 admission profile:
new approvals still require the exact authenticated original scope. Inherited
approval admission, platform originals, collaborator/delegate/steward approval
paths and adjudicated supersession remain separate work. An approval returned
as already recorded is never reauthorized against current signer capability or
expiry. The alternative finding is bound to this companion, exact action,
scope and manifest and must have reached its snapshotted notice end.

Raw executed records remain usable after permitted pointer replacement and
later evidence changes. Historical route reads retain original runtime pins;
current route health is a separate observation. Permissionless refresh checks
its own chain, fixed Core and current selected companion, without reopening
artist or owner authorization. It advances the stored bounded plan against the
execution-time Core high-water snapshot and rolls back with a failed Core
callback. The first actual-governance composition's zero high-water control
does not establish nonempty actual Core refresh or actual owner-notice authority.

## Recovery-aware Router serving

The Router classifies permanent finality using the original Registry bound by
its constructor-fixed artist facade. The current Core original-Finality pointer
is not a historical lookup. During the existing authenticated, one-way
`lockArtistIdentity` operation, the Router also stores that original Registry's
address and runtime hash in a separately appended per-collection mapping. The
existing artist snapshot hash, tuple, lock rejection and two events are
unchanged. The new binding is derived from the facade and checked against the
actual Registry code and reciprocal Core before any snapshot store or event.
There is no caller-selected target, rebind operation or mutable activation flag.

A locked presentation requires both saved binding fields. Missing, half-cleared
or unreadable saved data rejects; it cannot fall back to a new facade or an empty
registry. An unlocked presentation requires an empty saved binding and a healthy
constructor-fixed facade. After facade code loss the saved presentation remains
usable for absence classification and local unfinalized rendering. Finalized
serving still requires the companion's artist, Coordinator and Consent runtime
pins and can fail closed after facade loss. Original Registry code loss is unreadability rather
than evidence that the collection is unfinalized. Immutable original component
counts only classify absence, including collection inheritance for TOKEN.

For a finalized scope, the current Core-selected recovery companion is required.
The Router checks its current pointer, runtime, primary interface, module type,
live registry eligibility and reciprocal deployment bindings. Every consumed
family joins both canonical resolved-route and current-status results, including
route hash, original record and recovery ID. A missing or unhealthy frozen route
rejects without a direct-original or local-render fallback. Current eligibility
for new discovery is separate from the immutable pins used by historical adapter
state reads.

A specialized provider-backed serving adapter keeps the adapter identity,
actual Router or entropy host, and immutable evidence provider distinct. Its
provider identifies the exact host for each family and reads raw source/lock
facts; it never calls routed serving or the adapter again. The original
`StreamFinalityHostAdapter` constructor and history are unchanged. The new
adapter cannot supply readiness from caller-provided facts.

New candidate admission must also join the selected Router collection's saved
`originalFinalityAnchor(uint256)` to the specific candidate Registry and its
runtime code hash. That getter returns the exact 64-byte `(address, bytes32)`
pair with selector `0xe0e6f53a`. The first serving profile requires locked artist
presentation and therefore admits only the complete saved pair. A current
original-Registry pointer or an unauthenticated current facade lookup cannot
replace this join. A future profile permitting unlocked presentation needs a
separate read that authenticates the Router's constructor facade code pin before
deriving its original Registry. Historical serving retains the recorded anchor.

METADATA_ROUTER supplies configured mode, display and saved artist presentation; MEDIA_MANIFEST
supplies image and base URI; SCRIPT_SOURCE supplies exact script bytes; ENTROPY
supplies the terminal seed. RENDERER selects the actual invoked renderer.
RENDER_CONTEXT and DEPENDENCY_SOURCE must match the explicit fixed presentation,
context and dependency profile. Their commitments are distinct from renderer
identity, so an independently recovered renderer does not require the old
renderer to remain alive. Only the selected renderer's code is needed to render;
unchanged source-family reads do not impose unrelated renderer liveness.

The new bytes-only renderer entry uses canonical `abi.encode(Token,
ServingSource, bytes artist)` and exact re-encoding checks. It avoids Solidity's
different library-versus-contract selectors for nested struct parameters while
preserving old renderer methods. The first profile has bounded raw fields,
16-KiB token data and 64-KiB returned ABI. Profile declarations do not prove that
arbitrary renderer bytecode has no external reads; runtime admission remains
an independent review responsibility.

The first serving implementation uses two-million-gas payload reads for complete
cold Router source/facts and 16-KiB Core token data, a two-million
gas resolver ceiling and an eight-million gas renderer ceiling. Their parent-gas
requirements are explicit. Older Core fixtures use a 500,000-gas metadata budget,
which is not claimed to support frozen rendering under this profile. The current
accepted deployment planner supplies 12,000,000 gas; this does not change any
already deployed Core's parameter. Actual cold Core calls and governed budget
admission require matching runtime evidence. The actual original Registry,
companion and Router composition separately covers stored routes and replacement
renderer execution with explicit Core, artist, OwnerRecords and provider authority
boundaries. The retained Router suite and specialized-adapter fixtures alone do
not establish the authoritative provider inventory or full-v1 scope completion.

## Acceptance and remaining work

Required tests include an actual threshold-Safe/Executor class-2 path, direct
caller rejection, wrong proposer role/context, stale prestate, veto/expiry/retry,
all five scopes, immutable original records, current component and coverage
failure, and a real executable reference artifact. Unit observer certificates
prove quorum mechanics; they do not prove native consensus or independent
real-world observer operation. The selected network anchoring trust model in
[ADR 0031](0031-quorum-anchored-estate-archival-profile.md) remains explicit.

Actual read budgets must be measured across nested cold dependencies. The old
diagnostic planning constant cannot stand in for an implemented governed budget,
and equal outer/inner caps cannot imply sufficient execution gas.

Artist sanction/confirmation and accepted-or-sanctioned consumer migration,
recovery owner notice/objection evidence, serving-route recovery, remaining
artist operations and the general multipart archival profile remain explicit
work until their source and executed integration evidence are accepted.
