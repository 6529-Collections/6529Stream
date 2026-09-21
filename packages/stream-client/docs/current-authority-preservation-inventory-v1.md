# Current-authority preservation inventories

This client targets source
`9381dd999075693a4f63092d9924856a0dd72834` and the
[shared ABI146 fixture](../test/fixtures/current-preservation-v2-abi.json).
The actual hosts are
`StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1` and
`StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1`.
Their nominal V1 names use the fixed token preservation V2 family.

Each host exposes nineteen operational writes. They materialize the original
records, definitions, token rendering inputs and Artist archive origins needed
for a render-critical inventory. They are permissionless zero-value CALLs;
materialization does not grant publication or signing authority.

The inventory follows the current
[snapshot](current-token-preservation-snapshot-v2.md) and
[reference publication](current-token-preservation-reference-v2.md) flows.
Bundle archive coverage and finality are subsequent, separate operations.

## Deployment and read workers

`CurrentAuthorityPreservationInventoryV1Deployment` supplies the chain, Core,
collection or scoped variant, inventory runtime pin, read-worker pins and the
reviewed linked-dependency pins. Each pin contains an address and the expected
runtime code hash. Obtain these from the deployment's reviewed runtime and link
inventory; an address list alone does not establish the deployed closure.

The client reads the host's original anchor, origin reader and authority
resolver, checks the saved dependency commitment, then resolves and verifies
the current selected Artist dependencies. It also authenticates the resolver's
anchors and selection commitment. Captures bind those observations to one
block and the proposed inventory operation.

The source-qualified read workers use public pure/view library methods with
memory values. Their calls use compiler nominal selectors and separate ABI
value codecs, with reviewed deployed runtime and link pins. A selector can be
shared by different library contracts, so dispatch must retain the exact
contract and method. These reads support Item prediction; the original host's
stage, currentness and admission calls remain the operative simulation.

## Original anchor and captured authority

`dependencies()` and `originalAnchor()` expose the constructor's original
anchor. The pinned current-authority resolver selects the Artist dependencies
used by a new plan. `authoritySelection(planId)` exposes that captured
selection. Treat those two dependency sets separately.

Beginning an inventory resolves current authority, validates current sources
and derives the plan identity from the actual inventory host, dependency
commitment, captured selection, source context and lineage. Even an existing
plan retry performs those current source and selection checks before returning
its ID. An existing plan does not permit caller-supplied replacement routes.

Later writes follow the original stage and currentness checks against the
captured plan. Authority succession or changed source context can make a plan
ineligible for further work or current admission while its recorded history
remains available.

## Materialization stages

| Stage | Collection host | Scoped host |
| --- | --- | --- |
| Begin | `beginInventory(collectionId)` | `beginInventory(scope)` |
| Native and reference originals | `appendNative`, `appendReference` | Same methods with a bounded `maximum` of 1 through 64 |
| Description and conservation | Work, Rights, Intent or its waiver, Interview or its waiver | Same original record families |
| Root authorization | Original actor, observed time, aggregate and receipt witness | Also the original legacy-family hash |
| Definitions | `appendDefinition` | `appendDefinition` |
| Token bytes | `appendToken` | `appendTokenOutput` |
| Token dependencies | `appendScript`, `appendLibrary`, `appendRenderer`, `appendCurrentProfile`, `appendTokenPreservation` | `appendTokenScript`, `appendTokenLibrary`, `appendTokenRenderer`, `appendTokenCitation`, `appendTokenPreservation` |
| Origin runtimes | `appendOriginRuntime` | `appendOriginRuntime` |
| Seal | `sealInventory` | `sealInventory` |

The current plan and token progress determine the next valid operation.
Appending an original record requires its exact supplied structure; a digest
or newer replacement record cannot substitute for that structure. The
thirty-one definition slots retain the original order, with V2 snapshot,
reference, output and root interpretations in the preservation slots.

Each token completes all six original token phases before the next token.
After every token is complete, materialize the runtime rows for every recorded
origin, then seal. Sealing is not an idempotent retry.

## Original actors and receipt witnesses

A receipt witness `{ lane, index }` locates the original receipt occurrence.
It does not establish authority by itself. The original actor, producer,
archive, operation and domain remain part of the authenticated record.

Work has a specific legacy branch. If the selected Work record's
`artistPublication.attestationRecordHash` is zero, the call requires a zero
actor and witness `{ lane: 0, index: 0 }` (NATIVE). This branch does not add an
Artist publication item or archive origin. When the attestation is nonzero,
the original publication path requires the nonzero actor and records its
authenticated origin.

Root authorization uses its recorded authority class and historical aggregate.
The scoped form also supplies the original legacy-family hash. Preserve the
exact original authorization form; inventory readers do not accept every
signature form that a publication-creation route may have accepted.

## Ordered archive origins

Origin initialization records the current origin first and the presented
origin next when their archive environments differ. Later record encounters
extend that order. Deduplication uses the original environment identity;
sorting origins would change the commitment.

There are at most seventeen origins. Each `appendOriginRuntime` materializes
ten rows for the next origin: Registry, Coordinator, Archive and seven owners.
The cursor must cover every origin before sealing. The resulting evidence
binds both the captured authority selection and the sealed origin set.

An item's original archive route remains tied to its own authenticated
origin. A current resolver result is not a substitute for that historical
route when later producing archive proofs.

## Token byte bounds

These inventory token readers admit at most 40,960 bytes of HTML/animation,
2,048 bytes of supplied image data, 65,536 bytes of producer JSON and 16,384
bytes of Core token data. The supplied animation must match the exact admitted
producer output hash and the saved checkpoint output.

The earlier checkpoint's larger rendering allowance does not expand this
inventory profile. Keep preservation-family admission, the actual selected
Registry, original producer binding and per-token entropy evidence intact.

## History and current admission

Plan, source-context, segment, evidence, captured-selection and origin getters
are local recorded facts. Operative `requireCurrent` resolves and checks the
current authority and sources. `requireFullDefinitionBytes` additionally reads
the complete original definition bytes under its currentness checks.

There is no getter for the complete ordered Item list. Authenticate those
items from the original segment events and their item/segment commitments.
Collection events have no schema-version word. The current-authority scoped
events use schema version 1. An older profile's matching event name or tuple
does not establish the same event layout.

Historical evidence and live eligibility remain separate. A sealed inventory
does not itself establish bundle archive coverage, actual Safe execution or
finality.

Historical inspection uses `CurrentAuthorityPreservationInventoryV1HistoryDeployment`
and exact transaction/log locators for the ordered segments. It checks the
retained context, plan, Item chains, origin rows and evidence without requiring
today's resolver to accept the original authority. The inventory retains its
captured selection commitment but does not retain the resolver's original
anchors. History therefore reports `currentAuthorityChecked: false` and
`selectionCommitmentRecomputed: false`; current capture separately verifies
the live anchors and selection.

## Client entrypoints

Use `prepareCurrentAuthorityPreservationInventoryV1Call` for a typed unsigned
call. The workflow's `captureCurrentAuthorityPreservationInventoryV1` also
checks the pinned deployment, current selection, retained progress and exact
next segment. Supply the authenticated locators for all preceding segments.
For a new collection plan, the list is empty:

```ts
const capture = await captureCurrentAuthorityPreservationInventoryV1(
  provider, deployment, caller,
  { kind: "beginInventory", collectionId },
  { blockTag, gasLimit, segments: [] },
);
const simulation = await simulateCurrentAuthorityPreservationInventoryV1(
  provider, capture, { blockTag, gasLimit },
);
const call = simulation.capture.prepared.call;
```

Simulation runs the original call with the supplied caller and reports
`stateChangesPersisted: false`. Submit the prepared call through the intended
wallet. Use the Safe address as `caller` when the Safe will execute it.

`reconcileCurrentAuthorityPreservationInventoryV1Receipt` checks direct or
Safe transport, original events and the predicted plan, token and origin
state. It compares the preceding and ending block state and returns the new
segment locator for an append. Retain that locator for the next capture.
The receipt block must be later than the saved capture. Reconciliation rejects
intervening source or progress changes and additional ending-block progress
that prevents exact attribution to the captured operation.
Safe options require the independently verified Safe transaction hash and
ordinary CALL. A reconciled receipt reports `currentAfterReceipt: false`;
current-source eligibility requires a separate check.

`inspectCurrentAuthorityPreservationInventoryV1History` authenticates retained
plan history. `inspectCurrentAuthorityPreservationInventoryV1Current` checks
the actual current admission and optionally `requireFullDefinitionBytes`.
`inspectCurrentAuthorityPreservationInventoryV1Segment` authenticates one
original segment event and its ordered Items.

Some saved catalog facts are private host state. Capture simulates the complete
original call, including those checks when sealing. History, current inspection
and receipt results report `privateCatalogFactsIndependentlyReconstructed: false`;
current admission and full-definition checks still use the original host predicates.

`observeCurrentAuthorityPreservationInventoryV1Refusal` distinguishes an
execution revert from an RPC failure. Its before/after observations do not
prove rollback of a mined transaction.

## Client resource guards

The client limits inner calldata to 2 MiB and allows another 16 KiB for the
outer transaction envelope. RPC results and aggregate receipt log data are
limited to 16 MiB, with at most 65,536 logs and four topics per log. Runtime
reads allow 131,072 bytes; a linked-dependency roster allows 256 pins.

Structural array codecs allow at most 8,192 rows. Historical reconstruction
allows at most 16,384 segments and 16,384 total Items. Workflow gas inputs must
be between 21,000 and 100,000,000. These client allocation limits do not expand
the original token byte bounds or establish transaction capacity.

## Evidence boundary

The client prepares and inspects source-qualified calls. Runtime identity,
complete reviewed dependency lists and original contract execution remain
necessary. Client tests and RPC observations do not establish native rollback,
transaction capacity, complete archival custody or release acceptance.
