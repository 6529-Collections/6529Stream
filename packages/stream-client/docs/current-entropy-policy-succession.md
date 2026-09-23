# Canonical entropy policy succession V1

This additive client profile is pinned to joined source
`7901f3b108a7acc44780e6b686157d1016059e52`, tree
`c97f5289867bf1ce1a37ece386831c4201af2af6`. Its retained ABI89 capture contains
2,501 sources with no compiler errors. Every literal source was compared with
the frozen Git commit. Earlier entropy client profiles keep their original
source and runtime qualifications.

The canonical planner is `StreamEntropyPolicySuccessionPlan.sol`, introduced at
`3fab88e16549e9c06a339b7ef9a98562c6a9bfea`. Its entropy implementation follows
`393faf78529b1b911db408b26829339371268e29` and the test/document follow-up
`5cf63b7b1bc674373404e40e1edeb8d0f9dd4c41`. The plan and entropy semantics are
unchanged in this joined source. The full joined Core also contains later Museum
changes, so evidence for an earlier Core graph remains separately identified.

## What succession preserves

A fresh Coordinator imports every configured LEGACY and EXPLICIT collection
from the selected predecessor. Each row preserves its ultimate policy origin,
runtime pin, provider/runtime/configuration, policy and reveal inputs, operational
fee, frozen state, recovery binding and original revision, action and Artist
receipt. The explicit policy hash still names its ultimate origin.

LEGACY retains its original hash branch and zero explicit revision, action and
Artist receipt. An undeclared legacy reveal retains a zero policy hash; importing
it cannot create a new declared policy. A removed collection recovery binding can
still have historical revision and action evidence. Referenced frozen recovery
definitions are copied exactly; formerly bound, unreferenced definitions remain
historical data at their original host. Those original fields remain
distinct from the import's begin, seal and activation actions.

Historical token and scope subjects, original request keys, seeds, escrow and
requester credits stay at their existing hosts. New tokens use the newly selected
Coordinator. Importing a policy's fee amount does not fund that amount. The
candidate needs its own explicit provider lifecycle admission.

The public operations in this batch cover succession, catalog preparation and
governance. Provider requests, asynchronous relay delivery and retries remain
separate operational workflows.

## Complete inventory and one-use session

`entropyPolicyInventory()` returns the configured collection count, a mutation
serial and an ordered-ID digest. Enumerate exactly that count with
`entropyPolicyCollectionAt(index)`. The order is authoritative append order;
sorting IDs or enumerating every allocated Core collection changes the evidence.
An allocated but unconfigured collection is outside this inventory.

The initial digest is nonzero even for an empty inventory. Each append commits
the previous digest, index and collection ID. Policy contents are separately
committed by export hashes and the running export digest. A fee-only change can
advance the source serial while preserving the original policy hash.

Begin binds the predecessor/runtime, current Core pointer revision, complete
inventory header and operator manifest hash. The candidate must be irreversibly
unused. Publicly empty views cannot prove that private condition; the original
transition and call enforce it. An obsolete session requires another unused
candidate. There is no reset or partial activation.

| Stage | Exact authority and effect |
| --- | --- |
| Begin | Class 1, one original `beginEntropyPolicyImport` call |
| Copy | Permissionless `importNextEntropyPolicy(expectedIndex)`, one authoritative source row |
| Admit origin route | Class 1, one `admitEntropyRelay` call on that collection's ultimate origin |
| Confirm route | Permissionless `confirmEntropyRelayRoute(collectionId)` on the candidate |
| Seal | Class 1, one `sealEntropyPolicyImport` call after complete copy and required confirmations |
| Cutover | Class 3, exactly Core pointer replacement, candidate activation, then current manifest publication |

Copy and confirmation consume their exact progress. A repeated index or route
confirmation is not an eventless success. The candidate's ordinary configuration,
registration and funding paths are unavailable while STAGING or SEALED.

Every copy, seal and activation checks the pinned source evidence. Source runtime,
count, serial, digest or pointer drift can invalidate a pending plan. Empty
inventory still requires a genuine begin and seal.

## Ultimate-origin routes

A replacement of an imported Coordinator still routes directly to the policy's
ultimate origin. Succession does not grow an intermediate relay chain or rewrite
the original provider's authorized caller.

Each permanent route binds collection, candidate address/runtime, import hash and
original policy hash. The origin and candidate share the actual Core, authority
and RoleRegistry. A route cannot be retargeted to another import or replacement.
Existing one-successor recovery coverage also retains its original target.

DISABLED policies and INSTANT policies with NOT_REQUIRED rendering need no route.
ASYNC with NOT_REQUIRED rendering still needs one because scope requests remain
supported. The candidate's receipt counts required and confirmed routes. There
is no public per-collection confirmation flag; an observed origin admission alone
does not prove that the candidate has consumed its confirmation.

Imported policy receipts are immutable local evidence. Later reauthoring of an
unlocked ACTIVE policy may create a new local policy while its original import
receipt remains readable. Live provider and origin checks belong to the relevant
execution path; historical receipt inspection must preserve that distinction.

## Catalog admission

`entropyPolicySuccessionCatalogRows` derives the precise additional admissions:
class-1 begin and seal,
class-3 activation, and class-1 route admission for every supplied ultimate
origin. Rows bind actual target runtime and deployment identity and are sorted
by their original action-class/target/selector key. Duplicate origin admissions
are rejected.

Extending the catalog is itself a class-3 operation. The canonical catalog stage
contains exactly the extension followed by a fresh current-manifest publication.
The saved complete addition inventory binds chain, Executor/runtime, candidate
profile, base catalog/count/revision and all rows before the first stage.

Each stage applies at most 64 rows. Prepare the next stage only after observing
the exact prior catalog and manifest results. Existing actions scheduled under
an earlier catalog must execute before the extension or be prepared and scheduled
again under the new state. The original total catalog capacity is 1,024 entries.

The Executor exposes an aggregate catalog commitment, not an enumerable list of
historical entries. Retain the base admission inventory and compare additions
against it. A matching aggregate count alone does not prove that proposed rows
are absent. The original execution and its catalog checks remain authoritative.

The client retains the initial catalog rows and every ordered extension group.
It reconstructs the original bind and each extension commitment before using the
observed catalog state. Flattening all rows into a new initial catalog produces a
different commitment. An exact existing canonical row is retained; a conflicting
row with the same key is rejected. The workflow derives the complete origin set
from route-required source policies, rather than accepting an operator-selected
subset. A catalog whose necessary rows are all present needs no extension stage.

## Atomic pointer, activation and manifest

The cutover plan requires the actual selected predecessor/runtime, a mutable Core
pointer with an available next revision, an ACTIVE candidate ModuleRegistry
record and the original eligibility checks. The current manifest must name the
actual Core, ModuleRegistry and predecessor.

The candidate's readiness reply must be canonical true for the exact live source
header and pointer revision. Readiness means a complete SEALED session with all
required routes confirmed. It is a view and does not activate storage. Core also
checks uncovered pending requests under its original bounded call rules.

The batch has exactly three calls in this order:

1. Core selects the candidate and advances the original entropy pointer revision.
2. The candidate activates the sealed import at that exact next revision.
3. The original SystemManifest publishes the retained payload and updated module
   set, with the entropy Coordinator changed to the candidate.

The activation transition can be prepared while SEALED. Executing activation
before pointer replacement fails. Omitting the manifest tail or substituting
another target, module set, payload, transition or call order is outside this
profile. Any late activation or publication failure reverts the entire batch.

Once ACTIVE, the import receipt stays latched. A subsequent predecessor fee
change does not erase its historical activation. `entropyPolicyImportReady`
returns false for ACTIVE because it answers whether a SEALED session is ready
for the pending cutover; false does not erase completed activation evidence.

## Client API

The package exports the pure module and the provider-backed workflow separately.
All integers in contract structures are `bigint`; concrete RPC block numbers are
safe JavaScript integers. Supply the chain and runtime pins for the actual Core,
ModuleRegistry, Executor, RoleRegistry, predecessor, candidate and manifest.
Registration and provider lifecycle setup must already satisfy the original
contracts' requirements.

| API | Result |
| --- | --- |
| `captureEntropyPolicySuccession` | One block-bound observation with complete configured inventories, exports, copied receipts, registration, catalog, manifest and live readiness |
| `prepareEntropyPolicySuccession` | An inspected canonical begin, copy, route admission, route confirmation, seal, catalog or cutover plan |
| `prepareEntropyPolicySuccessionGovernance` | Original governance identity using the captured nonce, explicit proposer and time window |
| `entropyPolicySuccessionCall` | One unsigned permissionless copy or confirmation call |
| `entropyPolicySuccessionGovernanceCall` | Exact unsigned publication, scheduling or execution call |
| `simulateEntropyPolicySuccession` | Fresh validation followed by the original call with explicit sender, block and gas limit |
| `reconcileEntropyPolicySuccessionReceipt` | Exact direct or Safe CALL transaction, event and storage evidence |

For example, given the application's typed deployment pins and operator inputs:

```ts
const capture = await captureEntropyPolicySuccession(provider, deployment, {
  blockTag: blockNumber,
});
const inspection = await prepareEntropyPolicySuccession(provider, capture, {
  kind: "begin",
  manifestHash: importManifestHash,
});
const governance = prepareEntropyPolicySuccessionGovernance(
  inspection, proposer, window,
);
const publication = entropyPolicySuccessionGovernanceCall(
  governance, "publish", proposer,
);
const simulation = await simulateEntropyPolicySuccession(provider, publication, {
  blockTag: blockNumber,
  gasLimit: 5_000_000n,
});
```

Retain the capture, inspection and governance object before signing. Publish the
exact calldata first, then prepare the scheduling and execution calls from the
same governance object. Reinspect at each new stage. Class 1 and class 3 retain
the original two-day delay, seven-day open-window floor and one-year scheduling
horizon. The client constructs and verifies unsigned operations; it does not
broadcast or hold signer material.

Pure `prepareEntropyPolicySuccessionPlan` and
`entropyPolicySuccessionGovernanceBatch` reconstruct exact encodings from supplied
facts. They return `factsVerified: false`. A provider inspection still records
`admissionRequiresOriginalSimulation: true` and `nestedGasEquivalence: false`.
A successful simulation records that call's observed success and explicitly
does not guarantee future execution.

For a Safe caller, set the operation's proposer/caller to the actual Safe. Wrap
its exact unsigned call with the existing [Safe plan API](safe-call-plans.md):

```ts
const safePlan = createSafeCallPlan(deployment.chainId, "Publish succession calls", [
  { safe: proposerSafe, intent: "Publish the retained succession calldata",
    call: publication.call, abi: compiledExecutorABI },
]);
verifySafeCallPlan(safePlan, [compiledExecutorABI]);
```

Use the exact target ABI from the retained compiler profile: Executor for
governance stages and the continuity ABI for permissionless progress. The Safe
plan preserves ordinary CALL with `operation: 0`; its application review hash is
separate from the independently verified Safe transaction hash used in receipts.

## Receipt evidence and observation limits

Direct evidence must match the original sender, target, zero value and complete
calldata. Safe evidence requires the exact `execTransaction` inner target, value,
calldata and ordinary CALL operation, plus one matching Safe success after the
required protocol events. Both supported Safe success-event indexing layouts
are decoded canonically. Failure, duplicate success, incorrect transaction hash,
removed or foreign logs, wrong event order and substituted calls are rejected.

Governance receipts join retained calldata, the scheduled action and catalog
validation evidence. Lifecycle receipts also reconstruct the prior-block plan
and check the receipt block's complete inventories, import progress and required
state changes. Cutover verifies the exact pointer revision, latched activation
action and mandatory manifest publication together. Catalog stages verify the
new catalog commitment and fresh manifest together.

This profile needs historical block reads, and the receipt must be in a strictly
later block than the saved capture. Publication retry proofs and lifecycle proofs
need the preceding block's pinned runtime and state. It conservatively requires
the relevant prior-block state to match the prepared plan and the end-of-receipt-block
state to match the expected result. Multiple copy/confirm operations or unrelated
mutations in the same block may therefore make a valid transaction unverifiable
through this API. Later reauthoring does not rewrite the original import receipt;
inspect its historical block when reconciling that import.

## Explicit client bounds

These are allocation and observation bounds, not additional protocol capacities:

- Provider capture: at most 256 configured collections per Coordinator and 256
  distinct referenced recovery definitions, each retaining up to 32 steps.
- Pure inventory hashing: at most 4,096 IDs. The original catalog still allows
  1,024 total rows with at most 64 new rows per stage.
- Canonical policy exports: 1,184 bytes; import receipts: 544 bytes; full recovery
  exports: at most 5,696 bytes.
- Manifest payload: at most 32 canonical chunks and 786,400 bytes. Governance
  calldata publication retains its original 24,575-byte payload limit.
- Runtime reads: 65,536 bytes; ordinary RPC results and individual log data:
  32,768 bytes; receipt logs: 4,096 with at most four topics each; outer transaction
  calldata: 262,144 bytes.
- Simulation requires an explicit nonzero gas limit no greater than 100,000,000.

An incomplete inventory is rejected instead of producing a partial cutover.

## Validation and acceptance boundary

The fixture is regenerated from the retained joined ABI input/output without
invoking a compiler:

```sh
node scripts/generate-current-entropy-policy-succession-fixture.mjs \
  /path/to/abi89-input.json /path/to/abi89-output.json --check
```

Compiler-derived tuples and independently checked hash/calldata oracles establish
the source-bound encoding profile. Mock RPC and receipt cases establish client
consistency checks. Original simulations still enforce private candidate
freshness, authority, source and nested-call admission. Direct successful RPC
reads do not prove that Core's nested calls fit the governed gas limits.

The separate native packet at
`18c42131be84070641d071005b94abfbd73d23cc` reports 16 passing foundation and LEGACY
succession cases, including the actual Core, Executor, registries, manifest,
Coordinators and upstream Safe. It uses a test-double provider and an earlier
Core graph, with a test-only registration-batch correction. It does not establish
native acceptance of the full `7901f3b` graph, actual Artist/paid-mint/rendering
composition, release gas floors, full CI or deployment readiness.
