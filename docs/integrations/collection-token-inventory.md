# Collection token inventory

`StreamCollectionTokenInventory` builds an append-only list of the actual Core's
completed collection mints. It includes burned tokens. It supplies membership
to content-root producers without adding a hook or more storage to Core.

Use the small
[caller interface](../../smart-contracts/interfaces/stream/finality/IStreamCollectionTokenInventory.sol)
for indexing and reads. The constructor binds Core, its runtime hash and the
deployment chain. Its existing governed gas-parameter host accepts an Executor,
or zero for an immutable allowance. Register `TOKEN_INVENTORY_CORE_READ_GAS` as
a forwarding-cap parameter; the focused fixture uses 100,000 gas with a 50,000
floor. This is a dependency-call allowance, not a measured transaction ceiling.

## Indexing and completeness

1. Discover candidate token IDs from Core events or a local index.
2. Read `collectionInventoryState(collectionId)` to obtain the indexed count.
3. Submit the next 1 to 256 token IDs through `appendCollectionTokens` when their
   actual serials immediately follow the last indexed serial. To cross an aborted
   allocation gap, call `scanCollectionTokens(collectionId, maxScan)` instead.
4. Call `requireCompleteCollection` at the state being committed.

The contract checks each token against Core's permanent collection mapping and
requires actual collection serials exactly one above the last indexed serial
for the fast append path. Global token IDs must increase, but may have gaps
because other collections mint between them. Both minted and burned lifecycles
are accepted; prepared or unknown identities cannot be appended. A failed
element reverts the complete batch, including serial lookups and scan progress.

An incident abort consumes its token ID and serial permanently without increasing
`mintedEver`. For example, aborting serial 1 then completing serial 2 produces one
inventory entry at ordinal 0. Arbitrary increasing serials are insufficient:
they would let a submitter omit an earlier completed mint and poison the prefix.

The bounded scan authenticates each global ID after `collectionScanThrough` up
to Core's `lastAllocatedTokenId`, examining at most `maxScan` IDs (1 to 256).
It skips canonical unknown abort gaps and identities belonging to other
collections, and automatically indexes every completed target mint, including
burned history. It reverts the whole scan at a prepared target identity, because
that identity may still complete. Repeat bounded calls for sparse collections.
The returned cursor never crosses the current allocation frontier, so future
mints remain discoverable. Fast appends and scans share one monotonic cursor.

Anyone can append, including a Safe. An earlier transaction can only append an
authentic next prefix. If another submitter has already indexed overlapping
tokens, refresh the count and retry the remaining suffix. Submitted data never
grants authority or changes Core ownership, metadata or finality.

`requireCompleteCollection` checks that the collection exists and that the
indexed count equals Core's current `collectionMintedEver`. Later mints make a
previously complete inventory incomplete until they are indexed. Burns do not
reduce this count. A collection with no completed mints has an empty inventory,
even while a mint is prepared. This result alone does not prove that future
mints are disabled or that a collection is ready for finality.

## Reproducing the retained commitment

The empty prefix is:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_TOKEN_INVENTORY_V1"),
  deploymentChainId, inventoryAddress, coreAddress, collectionId
))
```

Each indexed token replaces the prefix with:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_TOKEN_INVENTORY_APPEND_V1"),
  previousPrefix, collectionSerial, tokenId
))
```

All numeric fields are `uint256`. `CollectionTokenIndexed` records the exact
serial, token and resulting prefix. `collectionTokenAt` uses a zero-based index.
The index is a completed-mint ordinal, not `collectionSerial - 1`. The additive
[serial lookup interface](../../smart-contracts/interfaces/stream/finality/IStreamCollectionTokenInventorySerialLookup.sol)
provides `collectionTokenBySerial(collectionId, actualSerial)`: zero means that
serial has not been indexed, including consumed abort gaps. The original
inventory ERC165 interface ID, hash domains and valid no-gap preimages are
unchanged. Consumers of a retained historical prefix must also bound membership
to that prefix's last ordinal; current serial membership alone includes later
appends.
History reads retain their values if Core code or the current chain changes;
new indexing and current completeness checks reject that changed binding.
An empty history read for an unknown collection asserts no existence.

## Verification and remaining composition

The focused suite executes actual Core minting, preparation, replacement-Manager
abort, burning and callbacks. It checks interleaved collections, atomic rejection,
consumed gaps before the first mint and between mints, bounded scan progress,
late-failure rollback, exact event/hash preimages and randomized batch partitions.
An actual threshold Safe 1.4.1 executes indexing operations and public reads.
Gas-parameter writes remain Executor-only;
the fixture checks rejection of a Safe acting directly as that authority.

The fixture uses explicit governance, module-registry, Manager and entropy
boundaries around Core. This is not full current-stack acceptance. Content
leaves, media hashes, entropy finalization, render locks, archival evidence and
the other RELEASE/SEASON/VIEW scope inventories still need their own actual
producer validation. The inventory prefix is not the artwork content root.
