# Scoped full-policy inventory and bundle archive

This additive client profile targets original ABI129 source
`896899f7ca4130f86e066587f780a3b1f755a25d`, tree
`743efae1136e5742cb57c9e477080bd1c6aca5aa`. It follows the
[scoped reference publication](current-scoped-policy-reference-v2.md) for
TOKEN, RELEASE and SEASON. The inventory enumerates every required source
object. Bundle coverage then records the applicable archival proof for each
ordered occurrence. Finality independently requires current inventory sources
and matching current bundle coverage.

## Inventory calls and order

All seventeen inventory writes are permissionless, zero-value CALLs. They
consume original source evidence; they grant no Artist or governance authority.

| Stage | Calls |
| --- | --- |
| Start | `beginInventory(scope)` |
| 0 | `appendNative(id, maximum)` |
| 1 | `appendReference(id, maximum)` |
| 2 | `appendWork` |
| 3 | `appendRights` |
| 4 | `appendIntent` or `appendIntentWaiver` |
| 5 | `appendInterview` or `appendInterviewWaiver` |
| 6 | `appendRootAuthorization` |
| 7 | Thirty-one ordered `appendDefinition` calls |
| 8 | For each token: `appendTokenOutput`, `appendTokenScript`, `appendTokenLibrary`, all `appendTokenRenderer` rows, all `appendTokenCitation` rows |
| Complete | `sealInventory` |

Native and reference batches admit 1 through 64 rows. Their cursors and counts
remain uint64. Token phases are output, script, library, renderer and citation;
only the final citation row advances the token ordinal. Sealing requires every
token to be complete and the phase, row and count cursors to be zero. A sealed
plan cannot be appended or sealed again.

`beginInventory` computes the original current source context before returning
an existing plan. A retry may therefore be eventless and still refuse changed
sources. For an incomplete plan, a pinned `beginInventory` simulation can check
its identity; the contract has no independent current-plan getter.

## Source and dependency commitments

Inventory binds twelve ordered targets and runtime hashes: Core, Metadata,
Schema Registry, Store, Router, scoped Snapshot, scoped Reference, Work
selection, Rights selection, Conservation selection, Finality Artifact Coverage
and External Artifact Coverage. It separately binds five Artist targets, the
Artist content owner, chain ID and the original five read budgets. The whole
dependency tuple enters its dependency hash.

The complete source context includes the current reference, snapshot, scoped
V2 root, membership, selection, output manifest record, Work, Rights,
conservation selection and original Artist association. A content hash cannot
replace the output manifest record key. TOKEN's subject hash omits collection
ID, so every cross-record join must also compare the full scope.

Token enumeration uses original membership ordinals, including retained burned
tokens. Script and library bytes need each original chunk and their complete
ordered concatenation. A retained deprecated STATIC renderer can remain valid;
new-assignment eligibility is a different check. Current-citation and terminal
entropy admission have separate records and interpretation documents.

Native inventory contains `44 + 2 * policyCount` rows. Reference inventory
contains `3 + packageFiles + platformPrerequisites + 2 * captures` rows.
Repeated objects with different roles or positions remain separate occurrences.
Never deduplicate inventory rows. Here a zero-byte package member requires the
SHA-256 digest of empty bytes; the earlier reference preparation alone permits
a looser declaration.

## Original Artist evidence

Root authorization consumes the original actor, observed timestamp, historical
Aggregate from the root publication event and original legacy CONTENT_ROOT
family hash. It authenticates the operation-17 Archive envelope, complete STOP
carrier, original class-1 or class-3 consent record, binding and record preimage.
Today's aggregate or family cannot replace that historical evidence. Historical
signatures are not rechecked against today's owner.

The original operation-17 root reader and shared operation-24 preservation
reader require a nonempty signature for a non-direct original approval. Some
relayed empty-ERC1271 approvals accepted at creation consequently cannot pass
these frozen inventory readers. This client preserves that original reader
boundary; earlier consent preparation does not promise inventory admission.

## Exact interpretation documents

The fixed definition sequence contains 31 entries:

1. Four Work definitions and two Rights definitions.
2. Eight Intent, waiver, interview and conservation catalog definitions.
3. Four reference environment, PNG, ZIP and native format definitions.
4. `RFC8785_JCS` and `RAW_BYTES`.
5. Three scoped Snapshot and three scoped Reference definitions.
6. Output schema, canonicalization and token leaf schema.
7. Root schema and canonicalization.

The fixture retains 26 exact JSON files and the five original output/root
Solidity document literals. Preserve each source's exact newline convention:
the four reference environment/format documents include a final newline, while
the newly retained common-record, JCS and RAW_BYTES files do not.

Fixed-definition and selected renderer/citation document admission authenticates
the full original DocumentFacts tuple,
ACTIVE status and complete ordered Store chunks. A document has 1 through 64
chunks, each 1 through 8192 bytes. Repeated chunks remain repeated. The resulting
item binds both the complete content and the full facts hash; changed facts can
invalidate a document even when its bytes are unchanged.

Selected renderer, citation and terminal-admission definitions add their own
source-derived pins. Renderer context's expected content hash can be zero; its
actual registered bytes and facts still need authentication. Typed Work or
conservation catalogs additionally authenticate their exact selected catalog
bytes at the record append stage. Those typed-reference rows retain their own
digest and size; they do not copy the document facts into row provenance or add
saved selected-document facts pins. These configured documents are additional
to the fixed 31. Fact-pin deduplication does not permit removing repeated
inventory occurrences.

Seal and current checks revalidate the saved fixed and renderer/citation facts.
The separate full-definition
diagnostic additionally reads all original chunks again.

## Authenticate segment rows

The contract stores Segment commitments and exposes `inventorySegment`; it has
no Item getter. `ScopedInventorySegmentRecorded` schema 2 carries the complete
ordered Item array. Retain its transaction hash and log index, authenticate its
receipt and stored Segment, and reconstruct the original backward item links.
An unauthenticated caller-supplied Item list cannot establish inventory evidence.

Each segment has a deterministic scoped plan/index key and a nonzero source
witness. The shared chain format supports explicit empty applicability segments,
with item count and first link both zero. Every stage of this concrete original
V2 inventory produces at least one item; an empty-segment consumer test does not
establish reachability through its seventeen writes. The final item link ends
at zero. The ordered chain commits every segment.

The inventory evidence hash binds the complete scope and original evidence
tuple with its own inner evidence hash cleared. Its encoded evidence is 736
bytes. Neither a subject hash nor a partial struct is a substitute.

## Bundle calls and proof branches

The archive host binds six ordered targets and runtime hashes: Core, Metadata,
Inventory, Finality Artifact Coverage, External Artifact Coverage and Artist
Archive, plus chain ID, read gas and archive gas. Its five writes are also
permissionless, zero-value CALLs.

| Call | Effect |
| --- | --- |
| `beginCoverage` | Authenticate completed inventory evidence and the current archive environment |
| `coverNext` | Consume the exact next authenticated Item and its applicable proof |
| `coverEmptySegment` | Advance an explicit empty segment in the supported consumer branch |
| `beginRefresh` | Select the deterministic refresh for this inventory and current environment |
| `refreshNext` | Recheck one saved item at the exact expected uint64 index |

`beginCoverage` checks the archive environment even on an existing-plan retry.
It authenticates immutable completed inventory evidence, without asserting that
inventory sources remain current. `beginRefresh` is eventless even when fresh
and cannot reset existing progress. Empty-segment progress has no item event;
the last segment may emit completion.

The twelve original Item kinds have distinct applicability. Proof backend 0
is reserved for the supported original state-bundle and intrinsic applicability
branches. Backend 1 excludes an onchain object; backend 2 excludes an external
object. Hash equality alone cannot select a proof branch.

| Evidence | Required original material |
| --- | --- |
| Native artifact | Full Artifact and Coverage, every STOP chunk, original per-chunk coverage, both receipt bundles and fixities, checkpoint certificate and exact envelope |
| External object | Full identity and saved Coverage, both original receipts, locators and signatures, both fixities and checkpoint certificate |
| Artist state bundle | Original Archive envelope, complete metadata and exact STOP carrier bytes |
| Explicit applicability | The canonical absent, empty-byte, empty-package-member or OS-prerequisite row |

The original correspondence rules use algorithm 1 for Keccak-256 or 2 for
SHA-256, with exact canonicalization and byte size. Arbitrary reference hash
algorithms do not expand this archive profile.

## Immutable coverage, refresh and currentness

Each admission checks the archive environment before and after its proof. If
the environment changes across initial admissions, the saved environment marker
becomes zero. Completed immutable coverage can still exist, but bounded current
coverage then needs a complete refresh under one current environment.

Current external observations preserve the original two receipt hashes and may
use later passing fixities. Replacing the original receipt pair changes the
evidence identity. Refresh retains the original proof and checks the whole saved
item; it does not substitute a newer coverage head.

The initial admission observation chain is private. The item event exposes
the Item hash and Admission, and the final automatic refresh exposes the
completed chain, but earlier per-admission observations have no getter. The
workflow independently reconstructs Item and Admission evidence commitments,
checks the final refresh environment, count and completion, and labels the
initial observation chain as observed rather than independently reconstructed.
Later `refreshNext` transitions have a public refresh prestate and permit exact
observation-chain reconstruction. These two levels of verification are distinct.
Bundle results expose `initialObservationChainAuthenticated=false`. Receipt
reconciliation sets `refreshStepChainAuthenticated=true` only for `refreshNext`.

`requireCoverage(scope, plan, renderCriticalEvidenceHash)` checks matching scope,
the original inventory evidence hash and
complete current-environment coverage for the immutable STOP aggregate profile.
`requireFullCurrentCoverage(plan)` is the separate expensive per-item byte and
runtime diagnostic. Historical inventory and archive evidence remain readable
without today's source liveness or archival reauthorization.

## Client evidence and receipts

Import the following entrypoints from `@6529/stream-client`:

| Inventory | Bundle archive |
| --- | --- |
| `prepareScopedPolicyInventoryV2Call` | `prepareScopedPolicyBundleV2Call` |
| `captureScopedPolicyInventoryV2` | `captureScopedPolicyBundleV2` |
| `simulateScopedPolicyInventoryV2` | `simulateScopedPolicyBundleV2` |
| `inspectScopedPolicyInventoryV2History` | `inspectScopedPolicyBundleV2History` |
| `inspectScopedPolicyInventoryV2Current` | `inspectScopedPolicyBundleV2Current` |
| `reconcileScopedPolicyInventoryV2Receipt` | `reconcileScopedPolicyBundleV2Receipt` |
| `observeScopedPolicyInventoryV2Refusal` | `observeScopedPolicyBundleV2Refusal` |

`inspectScopedPolicyInventoryV2Segment` authenticates a retained Item event by
its transaction hash and log index. History inspection also returns incomplete
plan and token progress; completed evidence is present only after sealing.
Supply every existing segment locator in original order when resuming.

The inventory deployment supplies `chainId`, Core address, an `inventory`
code pin, twelve named worker pins and the reviewed `linkedDependencies` list.
The archive deployment supplies the chain, Core, `bundle` code pin,
`archiveReader` pin and its linked dependencies. A code pin contains
`{address, codeHash}`. Historical deployment input needs the chain, Core and
original inventory or bundle host pin. Bundle history derives the immutable
Inventory pin from its stored dependencies and authenticates the inventory's
segment receipts. It needs those historical hosts, without current rendering
source or archive reauthorization.
Current inspection offers `fullDefinitionBytes` or `fullCurrentCoverage` for
the corresponding expensive diagnostic.

For a fresh inventory, the caller has reviewed the original deployment pins,
scope, concrete block and gas limit:

```ts
import {
  captureScopedPolicyInventoryV2,
  simulateScopedPolicyInventoryV2,
} from "@6529/stream-client";

const capture = await captureScopedPolicyInventoryV2(
  provider, reviewedInventoryDeployment, caller,
  { kind: "beginInventory", scope },
  { blockTag: reviewedBlock, gasLimit: reviewedGasLimit, segments: [] },
);
const simulation = await simulateScopedPolicyInventoryV2(provider, capture, {
  blockTag: reviewedBlock,
  gasLimit: reviewedGasLimit,
});
```

Use the actual Safe address as `caller` when preparing a Safe CALL. Capture and
simulation do not submit the transaction. Retain subsequent segment-event
locators for stage resumption and bundle proof preparation.

The pure modules expose separate `ScopedPolicyInventoryV2` and
`ScopedPolicyBundleV2` types and prepare the original unsigned CALLs. Workflow
capture checks the caller-reviewed deployment, actual dependency bindings,
source evidence, stage and exact request at a concrete block. Simulation
reconstructs capture and performs the inner CALL; it persists no changes.

Read-only worker calls use a closed set of original public pure/view functions,
their exact compiler nominal selectors and independently checked structural
argument/result encodings. Their reviewed addresses, runtime hashes and
transitive linked dependencies are explicit deployment inputs. These reads do
not turn storage-mutating library functions into wallet endpoints. Caller-supplied
code hashes alone cannot establish deployment provenance.

Downstream contracts observe the worker library as the caller during these
standalone reads. Their equivalence relies on the reviewed original pinned
implementations and linked closure, including renderers and verifiers. Gas
checks also run in a different call frame. A successful worker read therefore
does not prove that the complete host transaction will pass or fit its gas
budget; simulate the original host CALL separately.

Receipt reconciliation checks the exact direct transaction or supported Safe
CALL envelope, transaction/log identities, protocol events, Safe success and
the state immediately before and at the end of the mined block. The receipt
block must follow the capture block. Conflicting same-block progress requires
separate review. Refusal observation distinguishes execution reverts from RPC
failures and cannot prove mined rollback.

## Client allocation limits

This workflow accepts at most 16384 retained segments and 16384 total inventory
items. Larger inventories are outside this bounded client profile. Structural
pure codecs separately limit arrays to 8192 rows and encoded values to 2097152
bytes. These are client limits, not new restrictions on the original contracts.

The transport caps an RPC result or aggregate receipt log data at 16777216
bytes, runtime code at 131072 bytes, linked dependencies at 256 pins, and a
receipt at 65536 logs with at most four topics per log. Inner CALL data is
limited to 2097152 bytes, with 16384 additional bytes for the Safe envelope.
Workflow gas inputs range from 21000 through 100000000. These bounds do not
establish transaction capacity or gas acceptance.

This package consumes supplied archive evidence. Uploads, actual native
rendering, actual Safe execution, whole-call rollback, gas/capacity, deployment
and finality require their own evidence. COLLECTION, VIEW and the integrator's
newer preservation architecture remain separately qualified.
