# Collection token inventory recovery

Use `current-collection-inventory` and `current-collection-inventory-workflow`
with the inventory interface frozen at
`e6a1704005f6a1197903eac372a166383a910681`. These helpers recover the completed-mint
inventory after incident-aborted allocations leave permanent ID and serial gaps.
They prepare permissionless, zero-value calls with an explicit caller.

## Keep the coordinates separate

| Coordinate | Meaning |
| --- | --- |
| Global token ID | Allocated across all collections; an abort consumes the ID. |
| Actual collection serial | Assigned at preparation; an abort consumes the serial. |
| Inventory ordinal | Zero-based position among indexed completed mints. |
| Scan cursor | Highest global ID verified through this inventory's append or scan path. |
| `collectionMintedEver` | Lifetime completed mints, including subsequently burned tokens. |

For completed serials `1, 4`, ordinals are `0, 1`.
`collectionTokenAt(collectionId, 1)` reads the second completed token.
`collectionTokenBySerial(collectionId, 4)` reads that token by its actual serial.
A zero serial lookup means absent from the current index; it does not prove an abort.
The original inventory and append hash domains are unchanged. Each appended
prefix binds the actual serial and token ID; skipped allocations create no members.

## Capture, prepare and simulate one bounded step

Supply reviewed inventory and Core addresses and runtime hashes. All RPC reads
use a concrete block number and check the block hash, chain and both code pins.
The inventory's stored Core, Core hash, deployment chain and batch bound must agree.

```js
import {
  captureCollectionInventory, prepareCollectionInventoryScan,
  simulateCollectionInventoryOperation,
} from "../dist/index.js";

const capture = await captureCollectionInventory(provider, deployment, collectionId,
  { blockTag: reviewedBlockNumber });
const plan = prepareCollectionInventoryScan(capture, caller, 256n);
const simulation = await simulateCollectionInventoryOperation(provider, plan,
  { blockTag: simulationBlockNumber });
// Review plan.call and simulation.replay. Submission belongs to your application.
```

`maxScan` is 1–256 **global allocated IDs**, including gaps and other collections.
The scan stops at the captured allocation frontier. Sparse collections may need
many successive calls. Capture and read back each step before preparing the next.
At the frontier a repeated scan can succeed without changing anything.

The replay validates the complete Core identity and lifecycle tuple for every ID,
including skipped IDs. An unknown ID must have the canonical all-zero identity.
A prepared target token makes the entire scan fail; a valid prepared token in
another collection can be skipped. Completed burned tokens remain members.
The scan's `indexedCount` return is the total count after scanning.

`prepareCollectionInventoryAppend(capture, caller, tokenIds)` prepares the fast
path for 1–256 known completed tokens. IDs must increase above the saved cursor,
and simulation requires consecutive actual target serials beginning at
`lastIndexedSerial + 1`. After a gap, that serial differs from `indexedCount + 1`.
Use the scan path to cross target serial gaps.

Simulation refreshes the saved capture, rejects changed count, prefix, cursor,
frontier or minted count, replays bounded identities, and compares the exact
`eth_call` result using the intended caller. Refresh a stale plan explicitly.
Pure replay helpers accept supplied facts for offline review; they do not establish
that those facts came from a chain.

## Read completeness and saved-prefix membership

The capture's `complete` flag means indexed count equals `collectionMintedEver`
at that block, corroborated by `requireCompleteCollection`. Reaching the global
frontier, having a large serial or matching current live supply cannot substitute
for that check. Completeness can coexist with a prepared mint and does not close
future minting, establish finality or authorize publication.

```js
const member = await inspectCollectionInventoryPrefixMember(provider, savedCapture,
  { collectionSerial: 4n, blockTag: observationBlockNumber });
// status: "member", "not-indexed", or "outside-prefix"; ordinal is explicit.
```

Membership revalidates the saved historical capture, reads the current exact
serial mapping and Core identity, and bounds membership to the saved completed
count. Its binary search stays inside that saved ordinal prefix, with at most
256 search reads. Later appends cannot expand the captured membership set.
These guarded helpers require the pinned Core at each observation. The contract's
raw historical getters can remain readable after Core or chain drift; that weaker
historical read is a separate capability.

## Direct and Safe receipt evidence

`inspectCollectionInventoryOperationReceipt(provider, plan,
{ transactionHash, execution: "direct" })` verifies the exact sender, destination,
zero value and calldata. Use `execution: "safe"` for an ordinary Safe CALL:
the helper validates the inner call and one canonical `ExecutionSuccess`, rejects
`ExecutionFailure`, and supports indexed and unindexed Safe success layouts.
The retained capture must precede the receipt block.

The helper compares exact inventory events with the saved replay and checks
ordinal and actual-serial readback. A stale event base fails explicitly. Later
calls in the receipt block may append tokens or advance the cursor.

**No scan-progress event exists.** The returned `replay` is an expectation derived
from the earlier capture. The separate `observed` field is end-of-block state.
`cursorAttribution: "not-proven"` makes this limit explicit, including eventless
scans: success proves that this call indexed zero tokens, but does not identify
its exact starting interval or ending cursor. Ordinary receipts do not contain
the scan's return tuple.

The [Safe review example](../examples/current-collection-inventory.mjs) prepares
the next bounded step with its actual Safe caller, compiled ABI, zero value and
operation `0`. It preserves serial, ordinal-count, cursor and block coordinates
as full-width decimal text. It does not sign, submit or invent dependent future
checkpoints. The generic Safe plan hash is a local review identity.

## Evidence and scope

The [ABI fixture](../test/fixtures/current-collection-inventory-abi.json) contains
44 selected compiler entries from a clean 62-source capture. All literal sources
were independently compared byte for byte with the frozen Git commit. Reproduce
the projection using the retained input and output:

```sh
node scripts/generate-current-collection-inventory-fixture.mjs INPUT.json OUTPUT.json --check
```

Tests cover original hashes, exact ABI shapes, bounded replay, malformed return
words, saved-prefix limits, stale captures and direct/Safe receipt evidence.
Their controlled RPC fixtures establish client behavior. Actual current-stack
execution, Safe deployment, gas capacity and release acceptance remain separate.
This client batch does not attest downstream RELEASE, SEASON or VIEW consumer
compatibility with serial gaps; those consumers require their own updated source
and runtime evidence. Historical RC1 exports remain separate.
