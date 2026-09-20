import type { Address, Hex } from "../src/generated/contracts.js";
import {
  collectionInventoryAppendPrefix, collectionInventoryEmptyPrefix, decodeCollectionInventoryCoreIdentity,
  normalizeCollectionInventoryCheckpoint, normalizeCollectionInventoryCoordinates,
  normalizeCollectionInventoryCoreIdentity, replayCollectionInventoryAppend, replayCollectionInventoryScan,
  type CollectionInventoryCoordinates, type CollectionInventoryCheckpoint,
  type CollectionInventoryCoreIdentity, type CollectionInventoryReplay, type CollectionInventoryScanReplay,
} from "../src/current-collection-inventory.js";

declare const address: Address;
declare const hash: Hex;
const coordinates: CollectionInventoryCoordinates = { chainId: 1n, inventory: address, core: address, collectionId: 1n };
const before: CollectionInventoryCheckpoint = { indexedCount: 0n, prefixHash: collectionInventoryEmptyPrefix(coordinates), lastIndexedSerial: 0n, scanThrough: 0n };
const identity: CollectionInventoryCoreIdentity = { tokenId: 1n, mappingExists: true, collectionId: 1n, collectionSerial: 2n, burned: false, lifecycle: 2n };
const scan: CollectionInventoryScanReplay = replayCollectionInventoryScan(coordinates, before, 1n, 256n, [identity]);
const append: CollectionInventoryReplay = replayCollectionInventoryAppend(coordinates, before, [identity]);
const ordinal: bigint = scan.indexed[0]!.ordinal;
const prefix: Hex = collectionInventoryAppendPrefix(hash, 2n, 1n);
normalizeCollectionInventoryCoordinates(coordinates);
normalizeCollectionInventoryCheckpoint(coordinates, before);
normalizeCollectionInventoryCoreIdentity(identity);
decodeCollectionInventoryCoreIdentity(1n, hash, hash);
void append; void ordinal; void prefix;
// @ts-expect-error exact token IDs are bigint
normalizeCollectionInventoryCoreIdentity({ ...identity, tokenId: 1 });
// @ts-expect-error raw boolean flags are explicit booleans
normalizeCollectionInventoryCoreIdentity({ ...identity, mappingExists: 1n });
// @ts-expect-error no additional lifecycle state exists
normalizeCollectionInventoryCoreIdentity({ ...identity, lifecycle: 4n });
// @ts-expect-error prefix coordinates never include a caller
normalizeCollectionInventoryCoordinates({ ...coordinates, caller: address });
// @ts-expect-error historical inventory checkpoints do not claim finality
normalizeCollectionInventoryCheckpoint(coordinates, { ...before, finalized: true });
// @ts-expect-error scan limits remain uint256 bigint
replayCollectionInventoryScan(coordinates, before, 1n, 256, [identity]);
// @ts-expect-error checkpoint snapshots are immutable
scan.after.indexedCount = 100n;
// @ts-expect-error skipped facts are immutable too
scan.facts[0]!.collectionSerial = 7n;
// @ts-expect-error result arrays are immutable
scan.indexed.push(scan.indexed[0]!);
