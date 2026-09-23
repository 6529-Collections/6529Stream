# VIEW inventory and Bundle consumers

These clients target the genuine retrieval-enabled
`StreamViewPreservationRenderCriticalInventoryV1` and
`StreamViewPreservationBundleArchiveCoverageV1` at source
`a2973d360f6ab18881c04d58193f855704ec56d3`. Their separate
[ABI157 fixture](../test/fixtures/current-view-preservation-consumers-v1-abi.json)
retains both complete concrete ABIs and their 263-source import closure.

Inventory preparation is permissionless. It grants no Artist, publication,
Archive or finality authority. All 22 writes are ordinary zero-value CALLs.
The [retrieval witness producer](current-view-retrieval-v1.md) has its own
publication and revocation workflow.

## Exact operations

| Host | Operations |
| --- | --- |
| Inventory | `beginInventory`, `appendNative`, `appendReference`, `appendWork`, `appendRights`, `appendIntent`, `appendIntentWaiver`, `appendInterview`, `appendInterviewWaiver`, `appendRootAuthorization`, `appendDefinition`, `appendArtwork`, `appendRenderer`, `appendPreservationAdmission`, `appendTokenOutput`, `sealInventory` |
| Bundle | `beginCoverage`, `coverNext`, `coverRetrievalNext`, `coverEmptySegment`, `beginRefresh`, `refreshNext` |

The inventory binds the actual adopted VIEW context, full canonical scope,
original Artist, chain, selected host and dependency hash. Its ordered stages
retain native and reference evidence, original records and applicable waivers,
historical Artist operation-17 root authorization, all 36 definitions, adopted
artwork, renderer and preservation admission, and every member's complete output.
Native and reference batches accept `maximum` from 1 through 64. Sealing requires
complete token membership, positive exhausted native/reference page counts,
and exhausted output cursors.

Root authorization uses the original aggregate and legacy-family preimages.
It does not request a fresh signature or substitute today's Artist aggregate.
A legacy WORK without an Artist attestation uses a zero original actor.
Preparation still relies on the original host to admit these witnesses and
produce each stage's rows.

## Authenticate the companion separately

The inventory's original Dependencies tuple is 1,344 ABI bytes. Its hash does
not include the immutable retrieval-witness address and runtime hash. Read and
authenticate `retrievalWitnessBinding` separately, together with the exact
retrieval-enabled inventory profile, companion capability, original witness
configuration, and reciprocal Core, Router, checkpoint and Archive pins.

Bundle dependencies are 480 bytes. Their selected inventory, Core, Metadata,
artifact coverage, external coverage and original Artist Archive must match
the authenticated inventory graph. A supplied runtime hash establishes equality
to the supplied deployment record; source and deployment provenance still need
independent review.

## Preserve the original image obligation

| Adopted image | Inventory row |
| --- | --- |
| Empty | Original explicit absent row, using declaration coordinates. |
| Supported raw CID | Original declaration row containing the CID's SHA-256 digest; size and availability require Archive evidence. |
| Canonical `ar://` transaction or exact institutional HTTPS locator | Original declaration-based locator row with no invented digest or size. |
| Other admitted HTTPS or Arweave path | Retrieval obligation using Router, adoption and the original source key. |

URI bytes remain literal. The retrieval producer's admitted-URI validator is
not a validator for empty or raw-CID inventory rows. A locator never becomes a
content digest.

`coverRetrievalNext` joins the exact inventory row to the original witness's
complete source, retained receipt and current Archive admission. This includes
scope, Artist, adoption, payload and checkpoint-context hash. The source key
alone is insufficient because it deliberately omits the checkpoint-context
hash. The admission commitment additionally binds the actual witness address,
runtime, configuration, record and payload hash.

This dedicated path can also admit an original locator-shaped row. Read the
stored `retrievalWitnessForItem(plan,index)` association to choose subsequent
refresh/current dispatch; the row's role alone cannot choose it. The contract
emits the ordinary item-admission event and saves the witness coordinate in
storage. There is no additional witness event.

## Keep history and currentness distinct

| Surface | Evidence established by the original contract |
| --- | --- |
| `inventoryEvidence` and `bundleEvidence` | Saved completed evidence, without a fresh full source or per-item liveness check. |
| Inventory `requireCurrent` | Current original VIEW source selection and the exact completed inventory, including its definition checks. |
| Bundle `requireCoverage` | Exact saved completed coverage and completed refresh under the current Archive/revocation environment. |
| Bundle `requireFullCurrentCoverage` | Complete per-item current diagnosis through each item's saved ordinary or retrieval admission path. |
| `refreshNext` | The next ordered item's current check and its committed observation-chain transition. |

Operative combined evidence requires the separate inventory current read and
an exact plan/evidence-hash match. Cached `requireCoverage` does not replay every
witness, source and item. The same-scope retrieval revocation epoch invalidates
that scope's cached refresh; another scope's epoch does not. This epoch is not
a counter for every possible VIEW source mutation.

Saved history remains readable after revocation or lost source liveness.
Fresh fixity may restore currentness for the same original receipt pair;
today's coverage head need not replace the retained pair.

## Retries and ordered evidence

`beginInventory` repeats current source selection before returning an existing
plan without another start event. `beginCoverage` first checks the original
Archive environment, then returns for an existing plan before checking the
retrieval companion or scope epoch. It does not require inventory source
currentness. Do not add those checks to an eventless retry and report them as
original contract requirements.

Every consumed segment and item must retain its exact link, order and count.
`coverEmptySegment` supports a source-authenticated empty segment; its presence
in the consumer ABI does not establish that the actual inventory producer emits
one. The initial automatic refresh observation chain is private state observed
through the refresh result, not independently reconstructible from admission
events alone.

## RPC and Safe evidence boundary

Use the closed call helpers to prepare exact unsigned calldata:

```js
import { prepareCurrentViewPreservationInventoryV1Call } from "@6529/stream-client";

const prepared = prepareCurrentViewPreservationInventoryV1Call(
  { chainId, core, inventory },
  caller,
  { method: "appendNative", id: planId, maximum: 64n },
);
```

The Bundle helper is `prepareCurrentViewPreservationBundleV1Call`, with
`{ chainId, core, bundle }` coordinates. A prepared call supplies no verified
runtime facts and sends nothing. ABI integers use `bigint`.

The inventory workflow exposes:

| API | Purpose |
| --- | --- |
| `captureCurrentViewPreservationInventoryV1` | Fixed-block source, companion, saved-plan and ordered-segment checks, followed by the original host's dry-run call. |
| `simulateCurrentViewPreservationInventoryV1` | Revalidate the saved capture and repeat its original call at the selected block. |
| `reconcileCurrentViewPreservationInventoryV1Receipt` | Authenticate the exact direct/Safe transaction, events and stored transition. |
| `inspectCurrentViewPreservationInventoryV1Segment` | Authenticate one original segment event and its saved row commitment. |
| `inspectCurrentViewPreservationInventoryV1History` | Read authenticated saved context, segments and any completed evidence. |
| `inspectCurrentViewPreservationInventoryV1Current` | History plus current source/evidence, with optional full definition-byte inspection. |
| `observeCurrentViewPreservationInventoryV1Refusal` | Observe the original saved call's success or refusal without submitting it. |

Supply segment locators as `{ transactionHash, logIndex }`, preserving every
saved segment in order. Inventory capture requires `blockTag`, `gasLimit` and
`segments`; use an empty list for a new plan. Current inspection accepts the
same options and optional `fullDefinitionBytes`. Historical inspection needs
the explicit block and segment locators, without current-source runtime pins.

The Bundle workflow uses the corresponding
`captureCurrentViewPreservationBundleV1`,
`simulateCurrentViewPreservationBundleV1`,
`reconcileCurrentViewPreservationBundleV1Receipt`,
`inspectCurrentViewPreservationBundleV1History`,
`inspectCurrentViewPreservationBundleV1Current` and
`observeCurrentViewPreservationBundleV1Refusal` APIs. Capture requires the
explicit block, gas budget and inventory segment locators. Current inspection
checks cached current coverage by default. Select `fullCurrentCoverage: true`
for the independent per-item diagnostic, which does not require a completed
cached refresh and returns `cachedCoverageChecked: false` with `refresh: null`.
It reports `inventoryCurrentSourceChecked: false`;
compose it with the separate inventory current inspection and compare the exact
plan and evidence hash.

Historical Bundle inspection retains the stored witness coordinate and saved
admission commitment. It reports
`retrievalWitnessRecordIndependentlyAuthenticated: false`; it does not replay
the producer's historical payload authentication. The original current worker
checks correspondence when operative admission or per-item currentness is needed.

Workflows use an explicit numeric block, outer call gas, actual host/runtime
pins, and reviewed transitive library links. The original public memory-only
read workers retain their compiler-declared nominal selectors and structural
argument layouts. They are read helpers, not wallet transaction targets.

Host simulation performs the original append admission. Receipt inspection
authenticates emitted full item rows against stored segment hashes, links and
progress. The workflow reports `itemProductionIndependentlyReconstructed: false`
where it has not separately reproduced every stage-specific item worker.

Direct and Safe receipt checks bind the exact transaction and original host
events to preceding/end-block state. Safe success must follow the application's
events; unrelated later guard events may remain. A block snapshot cannot prove
an intra-block execution trace. A refusal observation alone cannot prove a
submitted transaction's rollback.

## Client resource limits

Pure codecs and call helpers cap each encoded value, complete call or segment
at 2 MiB, each array at 8,192 entries, and one normalization traversal at
65,536 nested values. Supplied-history authentication caps each retained segment
history and Bundle admission history at 16 MiB and 8,192 rows. These are client
allocation limits, not protocol capacity claims.

RPC workflows separately limit segment locators to 16,384 and total retained
items to 65,536, with an incremental 16 MiB limit for each segment history and
Bundle admission history. Shared RPC guards cap a response or aggregate receipt-log
payload at 16 MiB, a runtime at 128 KiB and a receipt at 65,536 logs. The
explicit outer-call gas budget must be between 21,000 and 100,000,000. A caller
must still provide a gas budget and history that fit the actual deployment.

Source, codec and mocked RPC tests do not establish actual native/Safe execution,
linked runtime provenance, complete Artist/Router/finality acceptance,
transaction capacity or deployment readiness. The actual campaign requires
matching deployment inputs and runtime evidence.
