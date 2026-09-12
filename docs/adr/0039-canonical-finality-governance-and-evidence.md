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
