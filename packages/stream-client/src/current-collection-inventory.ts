import { AbiCoder, ZeroAddress, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";

export interface CollectionInventoryCoordinates {
  readonly chainId: bigint;
  readonly inventory: Address;
  readonly core: Address;
  readonly collectionId: bigint;
}
/** Retained historical prefix coordinates, not current completeness or finality. */
export interface CollectionInventoryCheckpoint {
  readonly indexedCount: bigint;
  readonly prefixHash: Hex;
  readonly lastIndexedSerial: bigint;
  readonly scanThrough: bigint;
}
export interface CollectionInventoryCoreIdentity {
  readonly tokenId: bigint;
  readonly mappingExists: boolean;
  readonly collectionId: bigint;
  readonly collectionSerial: bigint;
  readonly burned: boolean;
  readonly lifecycle: 0n | 1n | 2n | 3n;
}
/** A dense completed-mint ordinal and its actual Core serial are separate coordinates. */
export interface CollectionInventoryIndexedToken {
  readonly ordinal: bigint;
  readonly tokenId: bigint;
  readonly collectionSerial: bigint;
  readonly prefixHash: Hex;
}
export interface CollectionInventoryReplay {
  readonly coordinates: CollectionInventoryCoordinates;
  readonly before: CollectionInventoryCheckpoint;
  readonly after: CollectionInventoryCheckpoint;
  readonly facts: readonly CollectionInventoryCoreIdentity[];
  readonly indexed: readonly CollectionInventoryIndexedToken[];
}
export interface CollectionInventoryScanReplay extends CollectionInventoryReplay {
  readonly frontier: bigint;
  readonly maxScan: bigint;
}

export const COLLECTION_INVENTORY_MAX_BATCH = 256n;
const coder = AbiCoder.defaultAbiCoder();
const inventoryDomain = id("6529STREAM_TOKEN_INVENTORY_V1");
const appendDomain = id("6529STREAM_TOKEN_INVENTORY_APPEND_V1");
const UINT256_MAX = (1n << 256n) - 1n;

function exact(value: unknown, keys: readonly string[], label: string): void {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...keys].sort().join(",")) throw Error(`${label} contains missing or unknown properties`);
}
function uint(value: unknown, label: string, positive = false): bigint {
  if (typeof value !== "bigint" || value < (positive ? 1n : 0n) || value > UINT256_MAX) throw Error(`${label} must be ${positive ? "positive " : ""}uint256 bigint`);
  return value;
}
function address(value: unknown, label: string): Address {
  if (typeof value !== "string") throw Error(`${label} must be an address`);
  const normalized = getAddress(value) as Address;
  if (normalized === ZeroAddress) throw Error(`${label} must be nonzero`);
  return normalized;
}
function hash(value: unknown): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)) throw Error("Inventory prefix must be bytes32");
  return value.toLowerCase() as Hex;
}
function increment(value: bigint, label: string): bigint {
  if (value === UINT256_MAX) throw Error(`${label} uint256 overflow`);
  return value + 1n;
}
function batch(value: unknown): bigint {
  const count = uint(value, "Inventory batch", true);
  if (count > COLLECTION_INVENTORY_MAX_BATCH) throw Error("Inventory batch must contain 1..256 IDs");
  return count;
}

export function normalizeCollectionInventoryCoordinates(input: CollectionInventoryCoordinates): CollectionInventoryCoordinates {
  exact(input, ["chainId", "inventory", "core", "collectionId"], "Inventory coordinates");
  return Object.freeze({ chainId: uint(input.chainId, "Chain ID", true), inventory: address(input.inventory, "Inventory"),
    core: address(input.core, "Core"), collectionId: uint(input.collectionId, "Collection ID", true) });
}
function emptyPrefix(coordinates: CollectionInventoryCoordinates): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256"],
    [inventoryDomain, coordinates.chainId, coordinates.inventory, coordinates.core, coordinates.collectionId])) as Hex;
}
/** The unchanged deployment-chain/inventory/Core/collection empty prefix preimage. */
export function collectionInventoryEmptyPrefix(coordinates: CollectionInventoryCoordinates): Hex {
  return emptyPrefix(normalizeCollectionInventoryCoordinates(coordinates));
}
/** The unchanged append preimage binds actual collection serial, never dense ordinal. */
export function collectionInventoryAppendPrefix(previousPrefix: Hex, collectionSerial: bigint, tokenId: bigint): Hex {
  return keccak256(coder.encode(["bytes32", "bytes32", "uint256", "uint256"],
    [appendDomain, hash(previousPrefix), uint(collectionSerial, "Collection serial", true), uint(tokenId, "Token ID", true)])) as Hex;
}
export function normalizeCollectionInventoryCheckpoint(
  coordinates: CollectionInventoryCoordinates, input: CollectionInventoryCheckpoint,
): CollectionInventoryCheckpoint {
  const saved = normalizeCollectionInventoryCoordinates(coordinates);
  exact(input, ["indexedCount", "prefixHash", "lastIndexedSerial", "scanThrough"], "Inventory checkpoint");
  const indexedCount = uint(input.indexedCount, "Indexed count"), prefixHash = hash(input.prefixHash),
    lastIndexedSerial = uint(input.lastIndexedSerial, "Last indexed serial"), scanThrough = uint(input.scanThrough, "Scan cursor");
  if (indexedCount === 0n) {
    if (lastIndexedSerial !== 0n || prefixHash !== emptyPrefix(saved)) throw Error("Empty inventory checkpoint must retain its original empty prefix and zero last serial");
  } else if (lastIndexedSerial < indexedCount || scanThrough < indexedCount) {
    throw Error("Inventory checkpoint count exceeds its serial or scan cursor");
  }
  return Object.freeze({ indexedCount, prefixHash, lastIndexedSerial, scanThrough });
}
/** Validate the entire tuple even when a scan will skip this global token ID. */
export function normalizeCollectionInventoryCoreIdentity(input: CollectionInventoryCoreIdentity): CollectionInventoryCoreIdentity {
  exact(input, ["tokenId", "mappingExists", "collectionId", "collectionSerial", "burned", "lifecycle"], "Core identity");
  const tokenId = uint(input.tokenId, "Token ID", true), collectionId = uint(input.collectionId, "Identity collection ID"),
    collectionSerial = uint(input.collectionSerial, "Identity collection serial"), lifecycle = uint(input.lifecycle, "Lifecycle");
  if (typeof input.mappingExists !== "boolean" || typeof input.burned !== "boolean") throw Error("Core identity flags must be boolean");
  const mappingExists = input.mappingExists, burned = input.burned;
  const unknown = !mappingExists && collectionId === 0n && collectionSerial === 0n && !burned && lifecycle === 0n;
  const known = mappingExists && collectionId > 0n && collectionSerial > 0n
    && (((lifecycle === 1n || lifecycle === 2n) && !burned) || (lifecycle === 3n && burned));
  if (!unknown && !known) throw Error("Core identity and lifecycle are not a canonical complete tuple");
  return Object.freeze({ tokenId, mappingExists, collectionId, collectionSerial, burned, lifecycle: lifecycle as CollectionInventoryCoreIdentity["lifecycle"] });
}
/** Exact Core return words, including canonical bool words and complete output lengths. */
export function decodeCollectionInventoryCoreIdentity(tokenId: bigint, identityReturn: Hex, lifecycleReturn: Hex): CollectionInventoryCoreIdentity {
  if (!isHexString(identityReturn, 128) || !isHexString(lifecycleReturn, 32)) throw Error("Core identity reads require exactly 128 and 32 return bytes");
  const [exists, collectionId, collectionSerial, burned] = coder.decode(["uint256", "uint256", "uint256", "uint256"], identityReturn) as unknown as readonly bigint[];
  const lifecycle = coder.decode(["uint256"], lifecycleReturn)[0] as bigint;
  if ((exists !== 0n && exists !== 1n) || (burned !== 0n && burned !== 1n)) throw Error("Core identity has noncanonical boolean return words");
  return normalizeCollectionInventoryCoreIdentity({ tokenId, mappingExists: exists === 1n, collectionId: collectionId!,
    collectionSerial: collectionSerial!, burned: burned === 1n, lifecycle: lifecycle as CollectionInventoryCoreIdentity["lifecycle"] });
}
function facts(input: readonly CollectionInventoryCoreIdentity[], expectedSize?: bigint): readonly CollectionInventoryCoreIdentity[] {
  if (!Array.isArray(input)) throw Error("Core identity facts must be an array");
  if (expectedSize === undefined) batch(BigInt(input.length));
  else if (BigInt(input.length) !== expectedSize) throw Error("Scan facts must cover the exact consecutive global-ID interval");
  return Object.freeze(input.map(normalizeCollectionInventoryCoreIdentity));
}
function appendEntry(entries: CollectionInventoryIndexedToken[], current: CollectionInventoryCheckpoint, fact: CollectionInventoryCoreIdentity): CollectionInventoryCheckpoint {
  const prefixHash = collectionInventoryAppendPrefix(current.prefixHash, fact.collectionSerial, fact.tokenId);
  entries.push(Object.freeze({ ordinal: current.indexedCount, tokenId: fact.tokenId, collectionSerial: fact.collectionSerial, prefixHash }));
  return { indexedCount: increment(current.indexedCount, "Indexed count"), prefixHash,
    lastIndexedSerial: fact.collectionSerial, scanThrough: fact.tokenId };
}
/** Replay explicit facts without RPC, membership claims, or a completeness/finality decision. */
export function replayCollectionInventoryScan(
  coordinates: CollectionInventoryCoordinates, checkpoint: CollectionInventoryCheckpoint,
  frontier: bigint, maxScan: bigint, input: readonly CollectionInventoryCoreIdentity[],
): CollectionInventoryScanReplay {
  const saved = normalizeCollectionInventoryCoordinates(coordinates), before = normalizeCollectionInventoryCheckpoint(saved, checkpoint);
  const bound = uint(frontier, "Allocation frontier"), limit = batch(maxScan);
  const remaining = bound > before.scanThrough ? bound - before.scanThrough : 0n;
  const count = remaining < limit ? remaining : limit, retained = facts(input, count), indexed: CollectionInventoryIndexedToken[] = [];
  let current = before;
  for (const fact of retained) {
    const next = increment(current.scanThrough, "Scan cursor");
    if (fact.tokenId !== next) throw Error("Scan facts must cover the exact consecutive global-ID interval");
    // Solidity computes serial + 1 before every identity read, including skipped identities.
    increment(current.lastIndexedSerial, "Expected collection serial");
    if (fact.collectionId === saved.collectionId) {
      if (fact.lifecycle === 1n) throw Error(`Inventory scan is blocked by prepared target token ${fact.tokenId}`);
      if (fact.collectionSerial <= current.lastIndexedSerial) throw Error("Target collection serial must strictly increase during scan");
      current = appendEntry(indexed, current, fact);
    } else current = { ...current, scanThrough: next };
  }
  return Object.freeze({ coordinates: saved, before, after: Object.freeze({ ...current }), facts: retained,
    indexed: Object.freeze(indexed), frontier: bound, maxScan: limit });
}
/** Fast append accepts only the next consecutive actual serials and IDs above the scan cursor. */
export function replayCollectionInventoryAppend(
  coordinates: CollectionInventoryCoordinates, checkpoint: CollectionInventoryCheckpoint,
  input: readonly CollectionInventoryCoreIdentity[],
): CollectionInventoryReplay {
  const saved = normalizeCollectionInventoryCoordinates(coordinates), before = normalizeCollectionInventoryCheckpoint(saved, checkpoint);
  const retained = facts(input), indexed: CollectionInventoryIndexedToken[] = [];
  let current = before;
  for (const fact of retained) {
    const serial = increment(current.lastIndexedSerial, "Expected collection serial");
    if (fact.tokenId <= current.scanThrough || fact.collectionId !== saved.collectionId
      || fact.collectionSerial !== serial || fact.lifecycle < 2n) throw Error("Fast append requires completed target identities at consecutive actual serials above the scan cursor");
    current = appendEntry(indexed, current, fact);
  }
  return Object.freeze({ coordinates: saved, before, after: Object.freeze({ ...current }), facts: retained, indexed: Object.freeze(indexed) });
}
