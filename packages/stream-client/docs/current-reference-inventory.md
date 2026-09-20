# Reference file-inventory preparation

Reference inventories retain the complete ordered file descriptions used by
the original reference publication and mode publication hosts. Staged
preparation splits the JSON construction into smaller calls while preserving
the original inventory ID, canonical bytes and publication witness.

Preparation is permissionless. Uploading chunks, preparing parts and assembling
an inventory grants no curator or writer authority, changes no reference head,
and reserves no right to publish. Publication has its own current source and
authority checks.

## Exact rows and identities

Each row is `{ path, byteSize, sha256Digest }`. Keep `byteSize` as a `bigint`
within the original `uint64` range. Its canonical JSON value is a quoted decimal
string; the digest is a nonzero, lowercase, fixed-width hexadecimal string.
Canonical row keys are `byteSize`, `path`, `sha256Digest`, with no whitespace
or trailing newline.

Rows must already be strictly ordered by their raw UTF-8 path bytes. The client
rejects reordered or duplicate paths; it does not sort, case-fold, normalize
Unicode or discard files. Relative package paths use the contract's ASCII path
rules and a 1,024-byte limit. Nonrelative platform paths use valid, nonempty
UTF-8 up to 2,048 bytes and the contract's exact JSON escaping. `relative: false`
does not itself require an absolute filesystem path.

The original preparation accepts an empty array and zero-byte files. The
environment and offline package validator impose further checks. Preparation
does not prove that the declared files match a ZIP archive, run an executable,
or satisfy those later checks.

The full inventory ID is the original hash of the `FILE_INVENTORY_V1` domain,
chain, actual publication host, relative flag and complete typed row array.
Part IDs use the separate `FILE_INVENTORY_PART_V1` domain with the same
coordinates and each exact part's rows. The preparer is absent from both
identities. The original and mode publication hosts have different addresses
and therefore different inventory IDs for the same bytes.

## Fixed parts and Store uploads

Staged preparation always groups consecutive rows in batches of 64. The final
part contains 1–64 rows. An empty inventory has zero parts and finalizes to
`[]`. Global ordering still applies across every part boundary.

Each part's canonical bytes form a complete JSON array, including its own
brackets. The final array contains all original rows with one pair of brackets.
Upload both the part arrays and the full array before their respective
preparation calls. These have different chunk boundaries; concatenating part
chunk hashes cannot substitute for the full array's chunks.

The client splits each array into exact 8,192-byte chunks and one final
remainder. Retain every chunk occurrence in order, even when identical content
can share one upload. The complete retained array must be at most 524,288
bytes. Chunk uploads and repeated preparation are idempotent; an existing
intact item can succeed without a new event.

The staged companion adds two calls:

| Call | Input and result |
| --- | --- |
| `prepareFileInventoryPart` | One exact 1–64-row array and relative flag; returns its part ID. |
| `prepareFileInventoryFromParts` | The full original row array and relative flag; derives every required part and returns the original full inventory ID. |

The caller supplies no alternate part IDs, counts or grouping to the finalizer.
Read either a part or the full array through the original
`preparedFileInventory(id)` method. The original `prepareFileInventory` remains
available as the explicitly selected monolithic route.

## Inspect, simulate and quote

```js
const snapshot = prepareReferenceInventory(chainId, publicationHost, relative, rows);
const plan = prepareReferenceInventoryPlan(deployment, preparer, snapshot, {
  mode: "staged",
  uploader,
});
const progress = await inspectReferenceInventoryPreparation(provider, plan, {
  blockTag: blockNumber,
});
const next = progress.steps.find(step => step.status === "ready");
if (next) {
  const quote = await quoteReferenceInventoryStepGas(provider, plan, next.index, {
    blockTag: blockNumber,
    maximumGas: reviewedInnerCallLimit,
  });
  // Review quote.estimatedGas and quote.withinMaximum before submitting separately.
}
```

Keep the chain, publication host, Store addresses and their reviewed runtime
hashes with the plan. Inspect one concrete block, verify the host's configured
Store, then check each available chunk's mapping and exact STOP-prefixed runtime
bytes. A returned pointer alone is insufficient.

Use stored bytes to reconstruct progress before each action. Do not advance a
local counter after a simulation or assume an earlier upload has been mined.
A full inventory already prepared through the monolithic route is complete
even if no staged parts were prepared. That observation does not attribute the
preparation to a particular caller or claim a staged history.

Simulate each pending call from its actual uploader or preparer with zero
native value. Gas quotes use that same call and a concrete RPC block. Missing
prerequisites block the quote until they are mined; simulating a later call
does not execute earlier steps. A quote can change with state and is not a
protocol gas-cap acceptance result.

The inner-call estimate is separate from the gas needed for a Safe's outer
transaction, signatures and execution policy. Keep this distinction in the
review and use the actual Safe envelope for Safe execution estimates.

## Safe calls and mined evidence

Each upload and preparation call uses ordinary Safe `CALL`, operation 0, with
zero native value. The uploader Safe and preparer Safe may differ. Review the
exact target, caller, row interval, part or inventory ID, content hash and byte
length before submission. A plan never selects signatures or broadcasts calls.

The [offline example](../examples/current-reference-inventory.mjs) builds these
review rows and ordered Safe plans from the caller's exact Store and host ABIs.
Large reviews are divided into pages of at most 256 calls, preserving each
page's global `firstStep`. Pages are review containers; they are not transaction
batches and do not apply earlier calls automatically.

For a mined call, bind the exact direct transaction or single Safe
`execTransaction` envelope to the prepared bytes. A Safe receipt must contain
its successful execution event and no failure event; an outer successful
transaction alone is insufficient. Check protocol events when emitted and
read the exact retained bytes at the receipt block. A repeated successful
preparation may have no new preparation event.

`ReferenceInventoryPartPrepared` identifies a newly retained part.
`ReferenceInventoryAssembled` identifies a newly assembled full inventory.
Both bind the schema, relative flag, row count, content hash and byte length.
The monolithic route emits neither event. These events establish preparation,
not publication or curator authorization.

Receipt inspection bounds outer calldata to 2,000,000 bytes, receipts to 256
logs and each event body to 16,384 bytes. These are client inspection limits,
not protocol validity rules.

## Evidence boundary

The [compiled fixture](../test/fixtures/current-reference-inventory-abi.json)
pins the exact 125-source `reference-modes-abi32` input and output hashes, with
27 complete selected ABI records for both hosts, the companion and the Store.
Its [generator](../scripts/generate-current-reference-inventory-fixture.mjs)
reproduces the fixture without compiling contracts.

The [native corpus](../test/fixtures/current-reference-inventory-corpus.json)
joins the original typed ABI rows to independently retained canonical
environment bytes: 1,048 package rows produce 162,109 bytes and 17 fixed parts;
102 platform rows produce 15,583 bytes and two parts. The
[corpus generator](../scripts/generate-current-reference-inventory-corpus.mjs)
verifies both source-file hashes and exact array equality. These are genuine
runtime declarations at typed test boundaries, not an RPC anchor or a complete
preservation dossier.

Client encoding, type, synthetic RPC and Safe-plan checks are separate from
joined contract execution, transaction gas limits, real Safe execution and
release acceptance. Transaction gas must be validated for the exact deployed
implementation and the actual Safe envelope separately from client quotes.
