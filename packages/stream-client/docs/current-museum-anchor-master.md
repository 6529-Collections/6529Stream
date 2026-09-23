# Native Museum anchors, tiers and media masters V1

This additive client profile targets source
`e558addd5ce1aee15d7ac327482b3822289d3dc7`, tree
`22ce31e8d8bcc519989b580214860f85020e9e8a`. Its retained ABI94 capture contains
2,557 Solidity inputs with no compiler errors. Every literal input was compared
byte for byte with the frozen Git commit. The fixture retains 32 complete ABI
segments, 1,087 entries, 189 dependency hashes, 66 source texts and six exact
definition/example documents. Existing client profiles keep their own pins.

The scope is permanent Core condition/floor binding, native conservation tiers,
and original media-master association or Artist waiver publication and adoption.
The later paid-floor ledger, direct receipt bridge, sale settlement and provider
batch remain outside this profile. A bound floor address does not establish
funding or a paid acquisition.

## Authority and permanence

| Operation | Original authority | Effect |
| --- | --- | --- |
| Bind condition catalog or floor | Singleton class 1 governance | Permanently records the address and runtime pin in Core |
| Declare a conservation tier | CONSERVATION class 7 for the collection or class 8 globally | Records the first explicit tier in Core before any completed mint |
| Publish a master association | Original MEDIA class 6 or 7 receipt | Appends a Metadata `MEDIA_RELATIONSHIP` record and retains its payload |
| Publish an Artist waiver | Already recorded original principal op24 authorization, class 1/capability 1 | Appends `ARTIST_STATEMENT` and consumes that publication authorization |
| Adopt either original record | Permissionless | Authenticates the original evidence and appends a selector revision |

The CONSERVATION, MEDIA and ARTIST families have distinct domain hashes and
permissions. Owning a collection, acting as curator, or having an unrelated
RIGHTS grant does not replace the required authority. The waiver relayer may
differ from the original recorder. Adoption preserves the original recorder,
class, binding generation, publication statement and receipt.

Core binding has no replacement or reset path. The candidate must report the
actual Core and Executor, both runtime hashes, chain, requested interface and
a nonzero source-set head. A source count of zero with a nonzero initial head is
valid. These identity checks do not enumerate the catalog's contents, establish
record authority, or admit a module into a different registry.

Anchor workflows support sealed ordinary class 1 governance: publish the exact
calldata, schedule its original singleton batch, wait for the delay, then execute.
The minimum delay is two days and the open execution window is at least seven
days, within the original one-year horizon. Direct RPC observations cannot prove
Core's bounded nested calls or private authority binding; simulate the original
Executor call from the actual sender at the reviewed block.

## Declared and effective tiers

`readMuseumConservationTier` checks collection existence and Core's durable
declaration and completed-mint count at one concrete block. A raw zero declaration
can also be returned for an unknown collection, so retain its `exists` field.

| Known collection state | Declared | Effective |
| --- | --- | --- |
| No declaration, no completed mint | Zero | Zero: undeclared |
| No declaration, at least one completed mint | Zero | `MUSEUM_GRADE_LITE` default |
| Explicit full tier | `MUSEUM_GRADE` | `MUSEUM_GRADE` |
| Explicit lite tier | `MUSEUM_GRADE_LITE` | `MUSEUM_GRADE_LITE` |
| Explicit waiver tier | `CONSERVATION_WAIVED` | `CONSERVATION_WAIVED` |

Allocation alone does not trigger the default. Burning a token does not erase
the completed-mint history or reopen declaration. A zero value is never an
explicit waiver. Writes go through the currently selected Metadata facade;
Core retains the durable declaration across facade replacement.

## Complete selected media

The native selector uses three shared collection slots: image (1), animation
(2), and content (3). Its media context commits the complete explicit manifest
and checks compatibility with the current Router serving source. The inventory
hash does not include Router name, description, script or pointer identity. Valid non-NONE
source kinds retain their literal URI and hash. MIME labels do not infer a master.

Opaque manifest and alternate documents, nonempty Router animation bases, and
inconsistent empty/occupied slots fail closed. A missing manifest is different
from an explicit selected manifest with no occupied slots. The latter has a
nonzero inventory commitment and a zero occupied mask.

`mediaObjectId` binds chain, Core, original Metadata, collection, subject,
manifest, slot and display hash. A PRESENT master authenticates a distinct
original object and its native external-artifact coverage; its content hash must
differ from the display hash. A URI or supplied digest alone proves neither that
coverage nor sold-display archival finality or institutional acquisition.

## Original records and waiver evidence

`museumMasterCanonical` and `museumMasterWaiverCanonical` produce the exact
fixed-key JSON accepted by the original producer. Their decoders require exact
canonical bytes. They preserve Unicode, URI spelling, object order and role order.
Binding generation is a decimal JSON string; media slot and reference algorithm
are JSON numbers. A zero predecessor serializes as `null`.

The record commits the original Metadata host, Core, chain, recorder, collection,
record type, subject, complete hash references, literal URI hash, schema and
effective time. Original record indices start at zero in separate collection and
record-type lanes. The recorded payload occupies one authenticated Store chunk,
with a maximum of 8,192 bytes. The exact active schema and canonicalization
documents must match their original hash and byte length.

For a waiver, `museumMasterPublication` returns the original publication tuple
and its 416-byte `abi.encode(uint16(1), Publication)` statement. It creates no
signature or authorization. Supply an already recorded original op24 authorization
for `recordArtistCollectionRecordWithPayload`; the workflow compares the stored
publication, original attestation and exact statement before consuming it.

Adoption requires consumed authorization and authenticates the full original
704-byte publication record, its Metadata runtime pin, original principal class
1/capability 1, signer, time and binding. The 224-byte attestation and original
416-byte statement must agree. The publication-evidence hash commits the entire
publication record. Current signer authority cannot replace that historical
evidence. The Artist association must also match the current collection binding.

Each waiver object has one or two distinct master roles; the selector retains
the first role for the adopted slot. Objects must be unique and scope must match
the collection subject. The native producer allows at most 512 objects, still
subject to the complete 8,192-byte payload ceiling. This profile does not provide
a platform-artist waiver shortcut.

## Selection history and current readiness

Adoption supplies the exact expected revision and predecessor original record
hash. It appends revision `expectedRevision + 1`. The predecessor is the previous
record hash, rather than its selection hash. Original receipt time cannot go
backward. Replacing a selection of the same status also requires a later original
record index; indices across master and waiver record types are separate lanes.

`currentMaster` and `masterSelectionAt` return stored selections without proving
current eligibility. An empty current selection is all zero; historical revisions
are one-based. `requireCollectionMasters` checks the complete current denominator,
association, exact active definitions and PRESENT coverage. Preserve its facts
hash separately from the historical selection hash.

The pure builders return `factsVerified: false`. Encoding, a stored selection or
a successful historical read is not current readiness. Use the bounded workflow
capture, exact sender simulation and post-receipt reads for operational evidence.

## Developer workflow

Supply the chain and runtime-pinned deployment explicitly. Anchor operations
need Core and Executor pins. Master operations additionally pin Metadata,
selector, schema registry, Store, external coverage and the Artist registry,
Coordinator, Identity, Binding and Attribution owners. Addresses from a different
release are not interchangeable merely because their ABIs match.

All workflow reads require a concrete numeric `blockTag`. Captures retain the
block hash and timestamp and check the header again after reads. Simulation
rechecks the original capture and observes a current concrete block before
calling the original contract as the actual sender. Re-capture and review when
relevant evidence changes. The workflow does not submit transactions.

For a permanent anchor, the first stage is:

```ts
const capture = await captureMuseumAnchorBinding(
  provider, anchorDeployment, "conditionSources", candidatePin,
  { blockTag: reviewedBlock },
);
const prepared = prepareMuseumAnchorGovernance(capture, proposerSafe, window);
const publish = prepareMuseumAnchorGovernanceOperation(
  prepared, "publish", proposerSafe,
);
await simulateMuseumAnchorGovernance(provider, publish, { blockTag: currentBlock });
const safePlan = createSafeCallPlan(anchorDeployment.chainId, "Publish Museum binding", [
  { safe: proposerSafe, intent: "Publish reviewed anchor calldata",
    call: publish.call, abi: verifiedExecutorAbi },
]);
```

After publication, prepare and simulate `"schedule"` from the proposer. After
the delay, prepare and simulate `"execute"` from the actual execution caller.
Each stage is an ordinary zero-value Safe CALL (`operation: 0`). Keep the same
reviewed batch and inspect each receipt before proceeding. Publication, scheduling
and execution are separate transactions; publication alone does not bind Core.

For a tier declaration, original record publication or adoption:

1. Use `prepareMuseumAnchorMasterCall(coordinates, caller, request)` with one of
   the five closed request kinds. For publication, build the exact record with
   `museumMasterRecord` or `museumMasterWaiverRecord` first.
2. Call `captureMuseumAnchorMaster(provider, deployment, call, { blockTag })`.
   It checks the operation's authority, source evidence and current dependencies.
3. Call `simulateMuseumAnchorMaster(provider, capture, { blockTag })` from the
   actual direct sender or Safe address, then compose `capture.prepared.call`
   using `createSafeCallPlan` and the corresponding original Metadata or selector
   ABI. Verify the plan with `verifySafeCallPlan`.
4. Submit through the application's transaction transport and inspect the
   original receipt before reporting success. A Safe outer transaction can
   succeed while its inner call fails.

Use `inspectMuseumAnchorGovernanceReceipt(provider, operation, options)` for
each governance stage, and `inspectMuseumAnchorMasterReceipt(provider, capture,
options)` for each ordinary operation. Direct options are `{ transactionHash,
execution: "direct" }`. Safe options also require an independently verified
`expectedSafeTxHash` from the reviewed Safe transaction:

```ts
const receipt = await inspectMuseumAnchorMasterReceipt(provider, capture, {
  transactionHash,
  execution: "safe",
  expectedSafeTxHash,
});
```

The shared `requireSafeExecution` verifier checks that hash, and the workflow
also verifies exact outer `execTransaction` calldata, zero-value CALL, required
operation events and their order before the sole Safe success. Receipts must be
strictly later than the original capture block. An eventless calldata publication
retry requires the same immutable pointer in the preceding block; a same-block
first publication cannot supply that proof.

Receipt checks use operation events and immutable original records or historical
selection revisions, rather than attributing mutable end-of-block current state
to one transaction. The profile still conservatively requires retained runtime
pins and, for governance, the reviewed catalog at the receipt block. Later
same-block changes can therefore make evidence unavailable to this profile;
do not relax its checks or report a fabricated receipt.

Keep original publication separate from adoption. Successful master publication
does not prove coverage or current selection. Waiver publication consumes its
already recorded op24 authorization; later permissionless adoption authenticates
that consumed evidence and the current association.

For reads, use `readMuseumConservationTier` for durable tier/default distinction,
`readMuseumMasterSelection` for current or specified historical storage, and
`requireMuseumCollectionMasters` for current native master eligibility and the
complete ordered facts hash. The last operation calls the original selector as
well as checking the source-derived facts.

Client allocation limits are explicit: runtime bytes 65,536, general RPC and
log data 32,768, native media reads 16,384, schema documents 64 chunks/524,288
bytes, prepared/outer Safe calldata 262,144, receipt logs 256 with at most four
topics each, and governance reason URI 2,048 bytes. Store chunk runtime is bounded
at 8,193 bytes and governance publication runtime at 24,576 bytes. The original
record payload ceiling remains 8,192 bytes.
Exceeding a client ceiling requires a separately reviewed bounded profile;
increasing an allocation limit cannot establish native nested-call gas safety.

## Source and runtime evidence

The original anchor producer is `f7a05e0734b95f1e2ff1a038b73511c0d94b6f81`;
Core anchors are `758572df4e7f3969f549dd58aef0c369202e2b27`. Master selection is
`7dca015920f2aaa0511b8ef4b4a56785e9321be8`, integrated at
`c1c169d5171f870cc85477a769896936aecf12d4`. The later Core floor binding is
`ff372f80b830b45a6afb30583780414f3abcc4cc` with tests integrated at
`734775e8898dff191d8ceadb31326e7157aae468`.

Separate `museum-anchors-native2` evidence reports 51 passing cases: 18 original
Core anchors, 12 catalog and 21 tier tests, with 138 unchanged production inputs
and 149 production products within size limits. That graph predates the later
Core floor binding and master implementation.

Separate `master-rights-native3` evidence reports 47 passing cases: 14 later Core
floor, 13 master selection, four waiver JSON and 16 sale-rights tests. Its 185
production inputs are unchanged from native2; all 88 nonempty production artifacts
fit. Its test-only correction is `0aed46a1`. This evidence excludes later provider,
paid-floor ledger, actual Artist, DIRECT and joined Router acceptance.

These retained native cohorts and client source/ABI/mocked tests remain separate
evidence. This lane does not compile Solidity, validate the complete joined native
graph, deploy contracts, or establish whole-system release readiness.

Regenerate the additive fixture from the exact retained ABI94 input and output:

```sh
node scripts/generate-current-museum-anchor-master-fixture.mjs ABI_INPUT ABI_OUTPUT --check
```

The input SHA-256 is
`f083e371f3a3e80182194794579338e1bf6d01e44713b78f41fe1af5ceed725d`;
the output SHA-256 is
`4be8ef1f2eec2cebdef60f5dd78756948b4b64de9538edb2b49f672bf7a2bc90`.
The generator reads interpretation documents from the exact frozen commit.
