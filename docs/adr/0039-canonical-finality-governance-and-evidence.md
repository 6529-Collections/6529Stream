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
every non-final part is 8192 bytes, and the final part is 1â€“8192 bytes. The
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
or independently prohibit its consumption by finality. AA-SANCTION1â€“3 instead
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

### Inherited TOKEN approval extension

The subsequent TOKEN increment extends fresh operation 22 admission from an
authenticated original COLLECTION record to a canonical TOKEN scope in that
same collection. The requested token ID must be nonzero and its scope ID zero.
The fixed Core must report a mapped identity, the exact collection, a nonzero
serial and either MINTED or BURNED lifecycle, with the burned flag agreeing
with that lifecycle. Prepared or unallocated identities are not sufficient.
The selected companion must independently authenticate the exact retained
request, manifest and original collection lineage. These observations are
repeated under the existing operation lock before either owner commits.

The immutable admission and Archive retain the requested TOKEN scope and the
companion's exact intent facts. The seven signed fields, twelve-word approval
hash and owner replay scope remain unchanged. Saved verification recognizes
only an exact original scope or the admission-proven COLLECTION-to-TOKEN
relation. It does not re-read current token state, companion staging or today's
pointers to keep recorded consent valid. A new companion execution separately
requires a currently valid route and membership. Authority is evaluated for
the requested scope; inheriting a collection's finality does not confer
collection-wide steward authority over a TOKEN request.

Operation 23 may bind a finding to that same authenticated TOKEN intent using
its existing action-specific notice and activity-cancellation rules. Its
notice clock remains an execution gate separate from the saved finding's
association and activity eligibility. Original executed records and the
recorded approval or finding remain permanent after a completed recovery.

This extension does not admit inherited RELEASE, SEASON or VIEW approvals,
delegated or collaborator-threshold approvals, or corrective association
adoption. Operation 35 and an explicit authorized approval-supersession proof
are not implemented by this increment. Neither a changed Binding generation
nor identity recovery by itself is such proof; the normative identity recovery
record list must not be silently enlarged to invalidate recovery approvals.

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

Router historical serving follows the companion's same evidence boundary:
OwnerRecords construction bindings and execution-time evidence remain mandatory,
but an already executed original or recovered route does not reopen the owner
host's current reciprocal reads or code liveness. Its immutable evidence snapshot
remains part of the executed record. New recovery preparation and execution still
require the constructor-pinned current evidence hosts, including OwnerRecords.
The original Registry and companion must still identify the exact same nonzero
Executor, but decoding those two immutable identities does not demand current
Executor code for historical serving. New recovery preparation retains its
Executor runtime pin. Core, artist, Coordinator, Consent, original Registry,
selected companion, current ModuleRegistry and serving-host dependencies retain
their respective canonical current-selection or historical runtime checks.

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

## Published scope membership profile

The approved pre-genesis membership profile introduces an explicitly registered
`SCOPE_MEMBERSHIP` record type, `STREAM_SCOPE_MEMBERSHIP_V1` schema and
`STREAM_SCOPE_MEMBERSHIP_ABI_V1` canonicalization. The actual collection Metadata
host publishes its full bytes under the canonical collection subject, using
only governed IDENTITY-family authorization classes 7/8. This is original
metadata provenance, not artist sanction or render-affecting VIEW adoption.

A fixed membership host authenticates the saved record, recorder/class, exact
generic record preimage, original definitions and full native bytes. It derives
the family-qualified scope ID from the versioned domain, chain, Core, collection,
scope type and original record hash. The payload omits that ID. Different
published records intentionally produce distinct scope identities even when
their token sets match; old arbitrary scope IDs are never silently aliased.

The full list commits strictly increasing token IDs in up to 64 native 8192-byte
parts, with an exact count and whole-byte hash. Continuation validates only the
next parts against actual completed/burned Core identities and the existing
collection token inventory. An unindexed part can retry; no incomplete prefix
is fixed at begin, and a partial list cannot seal. Sealed scopes are immutable.
Burns remain members and later parent mints cannot change a scoped commitment.

COLLECTION reads deliberately expose current complete inventory; historical
collection serving retains its original saved inventory/checkpoint commitment.
TOKEN reads retain the actual completed/burned identity. RELEASE/SEASON/VIEW
reads retain the sealed record/list without a mutable parent-inventory prefix.
The provider and Router must consume the same fixed membership host through the
original provider binding, without consulting today's replacement provider.
The complete byte grammar, authority separation, eight-word facts and measured
dependency budgets are specified in [the membership guide](../scope-membership.md).

This profile does not itself complete inherited-scope recovery approval,
adjudicated supersession, VIEW content adoption or whole-stack finality.

## Inherited published-family recovery admission

New recovery preparation supports inheritance from an authenticated canonical
COLLECTION finality record to RELEASE, SEASON and VIEW in the same collection.
The requested scope has zero token ID and a nonzero family-qualified scope ID.
The companion authenticates that ID through the original Registry's saved
provider and code hash, the provider's fixed Core, generic Metadata, Router and
membership host bindings, and the actual sealed membership facts. It recomputes
the subject, original-record-derived scope ID and full membership commitment.
Empty sealed scopes retain their valid grammar; membership alone does not imply
readiness, artist sanction or VIEW content adoption.

The Artist admission wrapper recognizes this canonical scope relation, then the
existing selected-companion proof loads the exact immutable full Request bound
to the original finality record and recovery manifest. The companion performs
the fresh membership check; Artist operation22 repeats this preparation under
its lock. Existing exact-scope and inherited TOKEN rules remain unchanged.
Authority restrictions use the requested scope, including the scoped steward
exclusion. Original signature fields, permanent approval hashes, nonce lanes and
stored Admission tuples remain unchanged.

An existing exact recovery head does not waive the fresh membership check for
another recovery inherited from COLLECTION. The companion revalidates that
relation during new preparation even though historical exact-head resolution
retains its saved original scope and record. Saved approval verification relies
on the immutable relation admitted with the exact manifest; it does not consult
today's membership source, token state, signer authority or deadline. A membership
source outage therefore blocks new inherited preparation while saved consent and
executed recovery evidence remain readable under their existing historical pins.

The membership read uses the companion's existing governed
GGP_RECOVERY_DEPENDENCY_READ_GAS. The Artist outer FINALITY_READ_GAS budget must
independently cover nested work and EIP-150 reserves. The retained lower-budget
controls and actual parameter-host raises are separate from proof of delayed
scheduling: the Artist composition profile raises the companion dependency read
to two million, Artist finality reads to eight million and the companion Artist
read to sixteen million through bounded successive host updates. The final
promised child cap requires strictly more than 16,353,968 gas at its inner caller
frame, in addition to preceding work and outer call reductions. Lower actual gas
consumption does not prove a twelve- or sixteen-million total transaction budget.
The fixture uses an exact typed Executor context, while real metadata publication, sealed membership, owner mutations, Safe
signatures and Archive callbacks execute normally. The helper cohort supplies
the actual provider/Router membership graph; original Registry and governance
boundaries in that cohort and the Artist cohort do not become a single complete
authority deployment by combining their results.

This admission extension does not implement operation35, explicit adjudicated
approval supersession, family VIEW presentation adoption or full finality
construction and launch acceptance. No Binding-generation or generic identity
change is an approval-supersession signal.

## Initial living-authority identity recovery

The first operation35 ingress is restricted to a contested initial living
artist authority. The saved cause must identify the same incumbent with prior
status1/class1, and the new address must be different and absent from the active-identity
index. The owner requires no prior pending or executed authority transition and no admitted
stable or provisional guardian record, including an empty guardian-set record.
It also rejects a nonempty supersession list in this first profile. Recovery
leaves a permanent execution marker, so the same artist cannot reenter this
initial-authority profile after dismissal or a later contest.

The facade captures the actual caller and the Coordinator retains its existing
lock and constructor runtime checks. Recovery requires the fixed Identity
Executor, an exact TERMINAL_FREEZE class2 per-call context, the stored executed
action and reason, its original proposer with the current Attribution Arbiter
role and mutation state, and a bound and sealed SystemManifest bootstrap state.
The sealed check excludes the current atomic genesis exception to ordinary
scheduling windows. The Executor's published action catalog must admit the
actual facade runtime, selector, class and zero-value call. Global terminal-veto
guardians and their scheduling commitments remain Executor responsibilities;
this first profile does not substitute them for artist-installed guardians.

The new side signs the original RotationAcceptance schema and consumes its
existing shared nonce allocator, digest revocation and observed-authorization
lanes. No permanent signed field or recovery semantic hash changes. The owner
recomputes the governance-bound request and new-side digest, consumes the current
cause and recovery action, advances the existing delegation epoch, preserves the
artist ID and prior-address standing, and assigns the new living authority.
It records a fresh executed transition with the snapshotted post-vesting window.
This governed action does not count as current artist activity: the new-side
signer was not the current principal at admission. Existing liveness and pending
fallback activity epochs therefore remain unchanged by operation35 itself.

The new owner commit uses the adopted operation35 receipt occurrence profile in
[the continuity packet](../architecture/artist-owner-record-continuity-v1.md).
The actual constructor-captured Identity domain is preserved. One successful
owner revision makes two ordered immutable receipt appends, binding the secondary
occurrence to the same-batch recomputed primary and unchanged list hash. The
Archive append follows atomically; any late failure restores authority, shared
nonce, delegation epoch, replay, both receipts and owner roots. Ordinary earlier
owner commits are not retroactively described as logical-receipt conformant.

The two relocated collaborator digest bodies preserve their inputs and hashing
under the authenticated fixed suite. The finality reader also reads the
Coordinator suite configuration, so this extraction does not claim identical
external-read behavior or gas cost.

The new recovery transition participates in the existing common window and
prior-standing reads. A successful later compromise filing marks its first
contested timestamp within the same operation33 commit. A contest before the
window ends prevents provisional records from becoming operative; a contest at
the exact end preserves their maturity. The existing typed dismissal closes that
transition and selects or discards the provisional cohort using the recorded
marker. A closed marker is not rewritten by a later valid contest. Recovery
records and stored receipt commitments remain immutable throughout. Recovery
does not populate the dismissal-specific record or latest-dismissal getter.

The current evidence separates actual Artist/Safe/owner/Archive execution under
typed Core/Executor/role boundaries from the actual sealed/delayed governance
reader cohort with Core, Executor, RoleRegistry, catalog, SystemManifest and Safe.
Those cohorts are complementary, not one combined authority deployment. The
first profile does not complete installed or historical guardian veto, prior
rotation/estate/recovery cohorts, posthumous recovery, nonempty adjudicated
supersession or full operation35. None of these identity changes alone invalidates
saved recovery approvals or rewrites consumed consent, sanction or executed
recovery history; exact approval-target adjudication remains separate work.

## Registered guardian recovery preparation

The next admitted initial-living profile permits one original, nonprovisional
class1 guardian record, including an authenticated empty first set. It still
requires the saved living pre-contest incumbent and no prior pending or executed
authority transition, and it still admits only an empty supersession list. Every
successful operation28 guardian admission increments an Identity-owned count,
including empty sets and lower-nonce records that never become operative. The
count is appended inside the final Recovery storage root and enters that same
operation28 state commitment and Archive rollback. The guarded profile requires
count1 and the exact original operative record; the never-guarded branch requires
count0 and both guardian heads absent. These rules apply to fresh deployments of
the counted implementation. A zero newly appended count cannot establish the
history of an earlier deployed implementation.

The supporting `registerIdentityRecoveryAction` operation has the exact auxiliary
`uint16` identifier65534 in its separate versioned configuration profile. It is
not a new canonical matrix operation or a validator operation-bitmask member.
The permissionless indexer submits the complete original GovernanceCall array,
recovery request and RotationAcceptance. The pinned canonical Executor must be
bound/sealed and store that exact full batch as a SCHEDULED TERMINAL_FREEZE
class2 action. Exactly one original recovery selector may occur anywhere in the
batch, with zero value and the fixed facade target. Its exact request/acceptance
calldata hash and per-call scope/old/new hashes must match the owner-derived
context. The original proposer, reason and current arbiter role facts are
corroborated against the same Executor and fixed suite.

Preparation must occur early enough to leave the entire actual terminal minimum
delay before `notBefore`; equality is accepted. A late indexer cannot shorten the
registered guardian's veto opportunity. Guardian `minContestSeconds` does not
extend Executor timing. It is instead included in the eventual post-vesting
window as `max(rotationSeconds, savedGuardianMinimum)`.

The Identity owner stores one immutable association containing action/batch/call
index, exact request and acceptance hashes, context hash, the complete original
guardian record, Executor runtime pin and original governance facts. The owner
rederives the context and guardian from its own state under the shared lock.
The actual indexer and preparation time are recorded. The scheduled context
excludes association/action identifiers, preparation time and owner revision;
registration therefore cannot invalidate its own previously scheduled action.
The separate association hash commits those fields and the prior pending action.
A current live action cannot be overwritten, including a locally vetoed action.
Replacement requires an authenticated terminal Executor status or a still
SCHEDULED action strictly past its authoritative expiry.

Auxiliary preparation and operation34 each use the existing owner zero-record
commit: one revision with the actual fourteen-word owner state preimage,
`recordDelta = keccak256(abi.encode(bytes32(0)))`, and unchanged record sequence
and chain tip. There is no invented semantic primary, new-side signature or nonce
consumption, or authority assignment. This is the explicit auxiliary profile in
[the preparation definition](../architecture/artist-recovery-preparation-v1.md),
not a claim of the continuity packet's separate twenty-word zero-record delta.
The actual Archive append follows atomically and binds the before/after owner
snapshots and retained association evidence.

`vetoIdentityRecovery(artistId, reasonHash)` preserves operation34's original ABI
and event. The actual direct actor must occur in the saved original guardian
array. Its permanent local action-keyed veto remains available throughout the
actual SCHEDULED status, including at and after `notBefore` until execution. It
does not call the Executor's global guardian-veto function. Execution retains the
existing strict active per-call governance witness, rechecks the exact stored
association and request against current owner facts, and refuses any local veto.
A historical EXECUTED action alone cannot reauthorize a call. The original
RotationAcceptance signature and nonce are consumed only by actual recovery.
The resulting recovery stores the admitted original guardian for common standing
and provisional-window consumers; later guardian changes do not rewrite it.

This is a bounded initial-authority increment. Historical eligible-set selection,
appeal-tier and prior-transition cases, posthumous recovery, nonempty adjudicated
supersession and exact approval-target adjudication remain required. Typed action
observations in Artist tests and separate real Executor reader tests do not by
themselves prove one combined authority deployment or maximum batch gas capacity.

## Complete initial guardian history for recovery veto

The next incremental profile widens the preceding count1 rule to every admitted
guardian-set record of an initial living authority with no prior transition and
an empty supersession list. The one-set evidence remains its own predecessor.
This widening implements the AA-GUARD7 veto union for that bounded initial
profile: a lower-nonce record that never became selected and a formerly selected
record replaced by an empty set both retain their guardians' recovery-veto
standing. It does not infer eligibility from a caller-supplied partial list.

Every successful operation28 now stores a one-based Identity-owned admission
index and a chained history commitment. The entry binds the actual successful
owner revision, original permanent record hash and full retained GuardianRecord
hash. Record indices follow admission, not signedAt or author nonce. Indexed
records include empty sets, and each member's first index is permanently kept
per artist. These writes enter the same operation28 next-state commitment,
original semantic append and final Archive rollback. They do not create a new
semantic record or alter the permanent guardian hash. The indexed count must
match the existing actual admission counter; a positive count with missing
history fails closed. Earlier deployments cannot import an asserted prefix.

The already-admitted complete history head enters the guarded context before
scheduling. Its historical admission revision is immutable; the future
preparation revision, action ID, association hash and preparation time never
enter that context. Preparation freezes the same count/root in a separate
owner-local action snapshot linked to the unchanged Association.contextHash and
association hash. Owner mutation and Archive payload both bind that snapshot.
Execution rechecks the exact committed prefix against the complete current head.
The new configuration additionally binds
`keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_PROFILE_V1")`.

Operation34 admits a direct actor only when its per-artist first membership index
is nonzero and no greater than the frozen count. A default-zero index grants no
standing. No history-wide scan or new arbitrary record-count cap is introduced.
The owner exposes indexed entries and the complete head through the additive
`guardianHistoryState` read bundle; the old Association and operation34/35 ABI
stay unchanged. The existing staged timing, local permanent veto, terminal
replacement, independent governance checks and original acceptance rules remain.

AA-GUARD10 still uses the operative set's minimum for the recovery post-vesting
window. The history union does not take the maximum of every old set's latency.
The existing common transition-standing tuple still captures that one operative
set; this increment does not claim the union supplies post-recovery identity
contest standing. Complete prior-transition/appeal eligibility, posthumous
recovery, nonempty supersession and exact approval-target adjudication remain
required, as does one combined actual Artist/governance deployment.

## First completed-rotation living recovery

The next bounded profile also admits a living authority whose first actual
rotation completed its original uncontested post-vesting window. It requires
the saved contested cause to identify that exact executed rotation and current
incumbent. Identity authenticates its local RotationRecord and permanent hash,
transition artist/hash and executed phase, the original old-address retirement,
and the stored window arithmetic. The original rotation must have no previous
transition; latest transition must still equal that execution, no pending
transition may exist, and no earlier identity recovery may exist. A later
abandoned cohort, estate transition or earlier recovery is not inferred to be an
eligible first rotation.

A contest entered before the stored post-window end remains outside this
profile after time elapses. A first contest at or after the end preserves the
rotation's matured status. The saved cause entry time and the transition's first
contestedAt must both satisfy that boundary; governance cannot substitute a
current timestamp for them. The context binds the full authenticated original
RotationRecord and retirement under a separate first-rotation facts/context
version. Initial-authority contexts acquire no such tail.

Selected guardians come from the owner's actual operative selection. A matured
provisional candidate can be selected without a checkpoint write and keeps its
original provisional association. A prior key's valid guardian record does not
need a signature from today's incumbent. Instead, the selected full record must
match its original indexed admission, record-data hash, permanent hash and
current provisional eligibility in the same complete owner history. Context,
preparation and execution use the same operative record. The full prefix retains
staged-recovery veto because this bounded profile has no earlier adjudicated
supersession and the current supersession list is empty. Provisional or lower-
nonce status alone never disqualifies a registered guardian from that veto.

The added configuration tag is
`keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_PROFILE_V1")`.
Operation34/35 and Association ABI, permanent record/signature preimages, owner
storage layout and one-revision/two-receipt recovery commit remain unchanged.
The selected set alone supplies its minimum for the new post-vesting window and
saved common standing. Original executed rotation records remain immutable.

This increment does not establish general prior-transition or appeal eligibility,
posthumous recovery, nonempty supersession, exact approval-target adjudication,
or the full history union for post-recovery contest standing. Actual Artist/Safe/
Archive tests and separate governance tests retain their respective dependency
boundaries; a typed scheduled-action fixture is not a combined real Executor
and Artist deployment. Complete default-profile and deployment-capacity evidence
remain separate from the focused IR implementation evidence.

## Later ordinary rotations and resolved original windows

The historical-rotation profile extends living, empty-supersession recovery to
later admitted ordinary rotations and to an original executed rotation whose
within-window contest was resolved by an actual earlier dismissal. It retains
the no-prior-identity-recovery gate. The current latest transition must still be
the actual latest ordinary execution; an unresolved later stage or vetoed head
is not treated as the vested incumbent.

The owner authenticates the current original RotationRecord, permanent hash,
executed transition, incumbent and old-address retirement. A nonzero previous
transition reference must identify an actual stored ordinary rotation of the
same artist. An executed predecessor must have vested the current rotation's
old address; a vetoed predecessor must retain that old address without having
executed. These are immediate owner-local joins over an admitted chain, not an
unbounded replay of every historical transition. The current original execution
may precede its contest deadline when its retained guardian approval threshold
was satisfied, exactly as ordinary rotation execution permits.

An early-contested executed window requires the exact permanent abandoned
Closure, its original Dismissal.Record and that record's original saved Cause.
The owner recomputes both hashes and joins artist, incumbent, original executed
transition, ACTIVE/class1 pre-contest authority, first contest time and stored
window. The original cause must precede that window's end; the original
dismissal must precede or coincide with the new cause. The closure continues to
name its first dismissal when later independent dismissals advance the current
resolution pointer. Current cause/latest-resolution equality remains a separate
existing admission check. A nonzero closure or today's timestamp alone supplies
no resolution evidence.

Resolution releases the operative window according to the existing dismissal
rules. It never clears the original contestedAt or makes the abandoned cohort
eligible. Every admitted guardian in the complete indexed prefix retains staged
recovery veto, including an abandoned provisional set. The selected operative
set alone controls the new post-vesting minimum and singular saved standing.
Neither an ordinary class1 nor class2 dismissal supplies appeal authority,
changes a guardian's lifetime veto, or adjudicates a recovery approval.

The added configuration tag is
`keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_PROFILE_V1")`.
Only the new historical branch wraps the scheduled old-value hash under
`6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_CONTEXT_V1`; initial and previously
supported first-rotation context preimages retain their existing domains and
contents. Public operation34/35 and Association tuples, permanent semantic and
signature hashes, owner storage, original acceptance replay, one owner revision
and two ordered recovery receipts remain unchanged. Archive failure rolls the
entire transition back.

This increment does not finish appeal, estate or prior-op35 histories, nonempty
supersession and operative-selection rewinds, a later phase3 latest head, exact
approval-target adjudication, or all-history post-recovery contest standing.
Those remain required. In particular, disqualifying a pre-transition guardian
requires the separately authenticated appeal authority, hostile-guardian
evidence and directive constraints in AA-GUARD7; ordinary dismissal is no proxy.
The focused actual Artist/Safe/Archive tests retain typed Core/governance
boundaries and do not establish the combined deployed system, a default-profile
build or an aggregate transaction gas limit.

## Guardian vesting snapshots for supersession chronology

The additive `6529STREAM_ARTIST_GUARDIAN_VESTING_PROFILE_V1` profile captures the
complete owner-maintained guardian prefix at actual rotation32, estate40 and
admitted recovery35 execution. The immutable snapshot records the original
transition, exact successful owner revision, actual execution time, old/new
principal and class, prior execution/snapshot chain and full guardian Head.
Count0 has a nonzero snapshot marker. Missing prior execution snapshots or an
incomplete counted history reject; no legacy backfill is authorized.

The new helper derives these facts from the fixed owner's just-executed original
record and current identity/retirement state. The existing mutation is extended
only in next-state commitment before its single original owner commit. The
expected original rotation/activation hash keys32/40, whose mutation record is
zero; the owner-recomputed recovery primary keys35. Permanent hashes, signature
preimages, action/replay behavior, semantic sequence and ordinary receipt rules
are unchanged. A late Archive failure rolls back vesting, snapshot, owner roots,
replay and any newly consumed acceptance together. The fixed owner's additive
fourteen-word `guardianVestingSnapshot` read rejects unknown/wrong-artist input.
The full encoding and producer rules are in the
[recovery preparation profile](../architecture/artist-recovery-preparation-v1.md#guardian-history-at-authority-vesting).

Successful guardian admission revision/index establishes before/after ordering
even when both actions share a timestamp. The Head's last guardian revision is
retained separately from the successful vesting revision. Author nonce,
signedAt, current selected head and a surviving provisional association do not
supply a supersession cutoff. Future consumers must authenticate the earliest
transition actually contested by resolution evidence, and independently prove
any still-provisional exception under AA-GUARD7/8. Ordinary dismissal does not
supply appeal authority. This is a prerequisite for required nonempty
supersession and does not itself remove any admitted guardian's veto standing.
The existing57 operations, adopted58, auxiliary65534 and37 genesis roles remain
unchanged; missing historical/appeal/posthumous consumers and any future
vesting producers still require implementation and actual integration evidence.

The fixed Estate deployment library embeds its child's creation code. Its own
EIP170 limit therefore applies in addition to the child runtime limit. Estate
execution preparation is extracted into a linked mutation helper, with the
original owner guard, coverage/witness order, actual execution, snapshot and
single-commit boundary preserved. Constructor/API/creation-nonce behavior stays
unchanged; the extra delegatecall and linked deployment artifact must remain in
runtime, gas and complete size evidence.

## First nonempty guardian supersession consumer

`6529STREAM_ARTIST_GUARDIAN_SUPERSESSION_PROFILE_V1` permits a sorted nonempty
guardian list only for the explicitly authenticated sole original rotation of
a living identity with no prior recovery. The actual current operation 33
subject, evidence, reason and cause must join that original transition and its
immutable vesting snapshot. Records must fall strictly after its saved prefix
and successful owner revision; no signed timestamp, nonce or latest-pointer
proxy establishes the chronological cutoff. The current stable/provisional
heads and records with nonce at or above the operative head are excluded from
this first supported profile. Pre-transition enumeration rejects at the ordinary
arbiter tier.

Complete per-member admission indices are maintained atomically with original
operation 28. Preparation freezes only the enumerated records' membership counts,
and every other saved-prefix membership preserves guardian veto standing.
Operation 35 permanently records the exact executed supersession coordinates in
the final Identity Recovery storage root, without rewriting the original records
or permanent list/primary hashes. Original one-revision/two-receipt continuity and
late-Archive rollback remain intact. Empty-list recovery retains its existing
context and application branches.

The [recovery preparation profile](../architecture/artist-recovery-preparation-v1.md#nonempty-post-vesting-guardian-adjudication)
defines the fixed-owner read, complete indexing, fresh-deployment restriction and
bounded membership mechanism. The list permits at most 64 entries; this grammar
alone does not establish maximum preparation capacity for 512 distinct members.
Future selection rewinds must consult the permanent supersession status. Full
head/chain rewinds, other record families, appeal-tier authority and hostile
guardian evidence, absolute directive constraints, posthumous/estate recovery
and complete historical standing remain required; this increment supplies no
proxy approval for them. Canonical 57 operations, adopted 58, auxiliary 65534 and
37 genesis roles remain unchanged.

## Complete election for guardian head supersession

`6529STREAM_ARTIST_GUARDIAN_HEAD_SELECTION_PROFILE_V1` extends the first
nonempty consumer to current-head exclusions using a complete bounded-chunk
history election. The immutable third-child preparation source scans every
original indexed admission and seals the exact count/root/revision, including
empty and unselected records. It elects the highest eligible nonce outside both
new and permanent exclusions; a prior-head link alone cannot prove completeness.

The evaluation basis is restricted to the same sole original ordinary rotation,
with its window already elapsed and each provisional association bound to that
exact transition/deadline. Every chunk and consumption rechecks original phase,
window, contest timestamp, current complete history and owner runtime. The
existing no-prior-recovery gate prevents cached status drift; broader historical
and estate profiles need their own complete invalidator set.

External progress has no owner authority. The existing scheduled-action
association separately commits the result and full restored record under one
owner revision, with complete Archive evidence. Execution preserves the original
recovery semantic hashes/two receipts, permanently excludes the listed records,
checkpoints the restored head and derives the fresh window from its minimum.
Saved standing retains that restored record independently of later helper
liveness. Fixed-owner guardian writers, dismissal checkpoints and outward reads
preserve the non-superseded-head invariant; future rewinds must do likewise.

The [preparation guide](../architecture/artist-recovery-preparation-v1.md#current-guardian-head-recovery)
defines discovery, paging, zero-versus-empty selection, immutable evidence and
capacity limits. Public operations 34/35, the canonical 57 plus adopted 58,
auxiliary 65534 and 37 genesis roles are unchanged. This extension does not
supply appeal/hostile-guardian authority, estate recovery, other record-family
adjudication or a maximum-capacity/full-deployment claim.

## Restricted guardian appeal profile

The pre-genesis `6529STREAM_ARTIST_GUARDIAN_ROOT_APPEAL_PROFILE_V1` supports
explicit pre-transition guardian adjudication in the first ordinary-rotation
profile. Identity derives the tier from its complete original history and saved
vesting revision; a publisher or caller cannot select APPEAL. The actual current
GovernanceRoot must hold APPEAL and control the actual Executor/RoleRegistry
ownership chain, establishing its root-mediated administration over ARBITER.
Root runtime/revision and APPEAL mutation state enter the scheduled context and
are authenticated again during sealed TERMINAL_FREEZE execution. The original
stored proposer, full batch, per-call context, full registration delay and
independent global guardian veto are preserved.

A fixed content publisher retains a versioned typed hostile-guardian document.
The owner independently joins its exact current original contest/cause, first
vesting snapshot, entire request and every requested pre-cutoff guardian record
and party. The request commitment zeroes only the self-derived document evidence
hash. Original contest evidence remains unchanged; the request retains the
original reason and points to the new document. The evidence reference expresses
the authorized adjudicator's findings, not an automated determination of
hostility. Empty pre-cutoff sets are outside this hostile-party profile.

The actual operative directive remains an absolute constraint:
`CAP_GUARDIAN_SET` forbiddance blocks these exclusions even at APPEAL. Complete
election, retained-prefix veto, permanent original records, one owner revision,
two receipts and atomic Archive rollback remain required. The exact document,
root/role and directive facts are retained in preparation and execution evidence.
The [preparation guide](../architecture/artist-recovery-preparation-v1.md#restricted-root-appeal-for-pre-transition-guardians)
defines this narrow authority graph and commitment profile.

Operations 34/35 and their permanent hashes remain unchanged, as do the 57 plus
adopted 58 operations, auxiliary 65534 and 37 genesis roles. Broader role-admin
delegation, historical and estate appeals, other record families, exceptional
provisional adjudication, maximum capacity and complete deployment remain open.

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
