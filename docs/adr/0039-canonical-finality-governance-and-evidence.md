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
product construction. The artist facade pins a predicted finality address and
the exact linked, immutable-completed runtime hash. Finality pins that artist
facade address but does not embed its runtime hash, avoiding a mutual runtime
hash fixed point. The prediction is deployment evidence, never an operational
readiness exception.

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
