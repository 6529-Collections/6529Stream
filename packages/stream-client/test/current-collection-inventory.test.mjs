import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import {
  COLLECTION_INVENTORY_MAX_BATCH, collectionInventoryAppendPrefix, collectionInventoryEmptyPrefix,
  decodeCollectionInventoryCoreIdentity, normalizeCollectionInventoryCheckpoint,
  normalizeCollectionInventoryCoordinates, normalizeCollectionInventoryCoreIdentity,
  replayCollectionInventoryAppend, replayCollectionInventoryScan,
} from "../dist/current-collection-inventory.js";

const coder = AbiCoder.defaultAbiCoder(), UMAX = (1n << 256n) - 1n;
const coordinates = () => ({ chainId: (1n << 180n) + 31337n, inventory: "0x0000000000000000000000000000000000000011",
  core: "0x0000000000000000000000000000000000000012", collectionId: (1n << 190n) + 7n });
const literalEmpty = c => keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256"],
  [id("6529STREAM_TOKEN_INVENTORY_V1"), c.chainId, c.inventory, c.core, c.collectionId]));
const literalAppend = (prefix, serial, token) => keccak256(coder.encode(["bytes32", "bytes32", "uint256", "uint256"],
  [id("6529STREAM_TOKEN_INVENTORY_APPEND_V1"), prefix, serial, token]));
const empty = (c = coordinates(), scanThrough = 0n) => ({ indexedCount: 0n, prefixHash: literalEmpty(c), lastIndexedSerial: 0n, scanThrough });
const known = (tokenId, collectionSerial, lifecycle = 2n, collectionId = coordinates().collectionId) => ({
  tokenId, mappingExists: true, collectionId, collectionSerial, burned: lifecycle === 3n, lifecycle,
});
const gap = tokenId => ({ tokenId, mappingExists: false, collectionId: 0n, collectionSerial: 0n, burned: false, lifecycle: 0n });
const identityBytes = f => coder.encode(["uint256", "uint256", "uint256", "uint256"],
  [f.mappingExists ? 1n : 0n, f.collectionId, f.collectionSerial, f.burned ? 1n : 0n]);
const lifecycleBytes = f => coder.encode(["uint256"], [f.lifecycle]);
const scanFacts = () => [gap(1n), known(2n, 1n, 1n, 99n), known(3n, 2n), gap(4n), known(5n, 2n, 3n, 99n), known(6n, 5n, 3n)];

test("unchanged empty and append preimages bind exact uint256 coordinates and actual serials", () => {
  const c = coordinates(), prefix = collectionInventoryEmptyPrefix(c);
  assert.equal(prefix, literalEmpty(c));
  for (const changed of [{ ...c, chainId: c.chainId + 1n }, { ...c, inventory: c.core },
    { ...c, core: c.inventory }, { ...c, collectionId: c.collectionId + 1n }]) {
    assert.notEqual(collectionInventoryEmptyPrefix(changed), prefix);
  }
  const serial = (1n << 200n) + 12n, token = (1n << 220n) + 33n;
  assert.equal(collectionInventoryAppendPrefix(prefix, serial, token), literalAppend(prefix, serial, token));
  assert.notEqual(collectionInventoryAppendPrefix(prefix, serial, token), literalAppend(prefix, 0n, token));
  assert.notEqual(collectionInventoryAppendPrefix(prefix, serial, token), literalAppend(prefix, serial, token + 1n));
  assert.equal(collectionInventoryAppendPrefix(ZeroHash, UMAX, UMAX), literalAppend(ZeroHash, UMAX, UMAX));
});

test("empty checkpoints validate the original prefix but preserve authenticated cursor progress", () => {
  const c = coordinates();
  assert.deepEqual(normalizeCollectionInventoryCheckpoint(c, empty(c, 44n)), empty(c, 44n));
  for (const bad of [{ ...empty(c), prefixHash: ZeroHash }, { ...empty(c), prefixHash: id("another prefix") },
    { ...empty(c), lastIndexedSerial: 1n }, { ...empty(c), indexedCount: 1n },
    { indexedCount: 2n, prefixHash: id("history"), lastIndexedSerial: 1n, scanThrough: 9n },
    { indexedCount: 2n, prefixHash: id("history"), lastIndexedSerial: 3n, scanThrough: 1n }]) {
    assert.throws(() => normalizeCollectionInventoryCheckpoint(c, bad));
  }
  const historical = { indexedCount: 2n, prefixHash: id("read at historical block"), lastIndexedSerial: 9n, scanThrough: 20n };
  assert.deepEqual(normalizeCollectionInventoryCheckpoint(c, historical), historical);
  assert.equal(Object.isFrozen(normalizeCollectionInventoryCheckpoint(c, historical)), true);
});

test("raw Core reads reject noncanonical booleans, lifecycle tuples and return sizes", () => {
  for (const f of [gap(1n), known(2n, 7n, 1n), known(3n, 8n), known(4n, 9n, 3n)]) {
    assert.deepEqual(decodeCollectionInventoryCoreIdentity(f.tokenId, identityBytes(f), lifecycleBytes(f)), f);
  }
  const f = known(7n, 7n);
  for (const bad of ["0x", identityBytes(f).slice(0, -2), `${identityBytes(f)}00`]) {
    assert.throws(() => decodeCollectionInventoryCoreIdentity(f.tokenId, bad, lifecycleBytes(f)), /exactly 128 and 32/);
  }
  for (const bad of ["0x", lifecycleBytes(f).slice(0, -2), `${lifecycleBytes(f)}00`]) {
    assert.throws(() => decodeCollectionInventoryCoreIdentity(f.tokenId, identityBytes(f), bad), /exactly 128 and 32/);
  }
  for (const [exists, burned] of [[2n, 0n], [1n, 2n], [UMAX, 0n]]) {
    const bad = coder.encode(["uint256", "uint256", "uint256", "uint256"], [exists, f.collectionId, f.collectionSerial, burned]);
    assert.throws(() => decodeCollectionInventoryCoreIdentity(f.tokenId, bad, lifecycleBytes(f)), /noncanonical boolean/);
  }
  for (const bad of [{ ...gap(1n), collectionId: 1n }, { ...gap(1n), burned: true }, { ...gap(1n), lifecycle: 1n },
    { ...known(1n, 1n), mappingExists: false }, { ...known(1n, 1n), collectionSerial: 0n },
    { ...known(1n, 1n), collectionId: 0n }, { ...known(1n, 1n), burned: true },
    { ...known(1n, 1n, 3n), burned: false }, { ...known(1n, 1n), lifecycle: 4n },
    { ...known(1n, 1n), lifecycle: 256n }, { ...known(1n, 1n), lifecycle: UMAX }]) {
    assert.throws(() => normalizeCollectionInventoryCoreIdentity(bad), /canonical complete tuple/);
    assert.throws(() => decodeCollectionInventoryCoreIdentity(bad.tokenId, identityBytes(bad), lifecycleBytes(bad)), /canonical complete tuple/);
  }
});

test("bounded scan authenticates abort gaps and foreign prepared tokens while retaining burned history", () => {
  const c = coordinates(), before = empty(c), facts = scanFacts();
  const result = replayCollectionInventoryScan(c, before, 6n, 256n, facts);
  const first = literalAppend(before.prefixHash, 2n, 3n), second = literalAppend(first, 5n, 6n);
  assert.deepEqual(result.indexed, [
    { ordinal: 0n, tokenId: 3n, collectionSerial: 2n, prefixHash: first },
    { ordinal: 1n, tokenId: 6n, collectionSerial: 5n, prefixHash: second },
  ]);
  assert.deepEqual(result.after, { indexedCount: 2n, prefixHash: second, lastIndexedSerial: 5n, scanThrough: 6n });
  assert.deepEqual(result.facts, facts);
  assert.equal(result.frontier, 6n); assert.equal(result.maxScan, 256n);
  assert.equal(before.indexedCount, 0n);
});

test("scan rejects a prepared target atomically, including after an otherwise valid append", () => {
  const c = coordinates(), before = empty(c), original = structuredClone(before);
  const input = [known(1n, 1n), gap(2n), known(3n, 3n, 1n), known(4n, 4n)];
  const savedFacts = structuredClone(input);
  assert.throws(() => replayCollectionInventoryScan(c, before, 4n, 4n, input), /blocked by prepared target token 3/);
  assert.deepEqual(before, original); assert.deepEqual(input, savedFacts);
  // Foreign identities are fully checked before they may be skipped.
  for (const invalid of [{ ...known(2n, 1n, 1n, 99n), burned: true }, { ...gap(2n), collectionSerial: 1n }]) {
    assert.throws(() => replayCollectionInventoryScan(c, before, 2n, 2n, [known(1n, 1n), invalid]), /canonical complete tuple/);
  }
});

test("scan requires every exact consecutive global ID and obeys both maxScan and frontier", () => {
  const c = coordinates(), before = empty(c), facts = scanFacts();
  for (const invalid of [facts.slice(1), facts.slice(0, -1), [...facts, gap(7n)],
    [facts[0], facts[0], ...facts.slice(2)], [facts[1], facts[0], ...facts.slice(2)]]) {
    assert.throws(() => replayCollectionInventoryScan(c, before, 6n, 6n, invalid), /exact consecutive global-ID interval/);
  }
  const partial = replayCollectionInventoryScan(c, before, 6n, 2n, facts.slice(0, 2));
  assert.deepEqual(partial.after, empty(c, 2n));
  assert.throws(() => replayCollectionInventoryScan(c, before, 6n, 2n, facts), /exact consecutive/);
  const noAllocation = replayCollectionInventoryScan(c, before, 0n, 256n, []);
  assert.deepEqual(noAllocation.after, before);
  for (const frontier of [1n, 2n]) {
    assert.deepEqual(replayCollectionInventoryScan(c, partial.after, frontier, 1n, []).after, partial.after);
  }
  for (const maxScan of [0n, 257n, -1n, 1, 1n << 256n]) {
    assert.throws(() => replayCollectionInventoryScan(c, before, 6n, maxScan, []));
  }
  assert.equal(COLLECTION_INVENTORY_MAX_BATCH, 256n);
});

test("target serial gaps are admitted only by scan and never by the consecutive fast path", () => {
  const c = coordinates(), start = replayCollectionInventoryScan(c, empty(c), 6n, 6n, scanFacts()).after;
  const next = known(7n, 9n);
  const scanned = replayCollectionInventoryScan(c, start, 7n, 1n, [next]);
  assert.equal(scanned.after.indexedCount, 3n); assert.equal(scanned.after.lastIndexedSerial, 9n);
  assert.equal(scanned.after.prefixHash, literalAppend(start.prefixHash, 9n, 7n));
  assert.throws(() => replayCollectionInventoryAppend(c, start, [next]), /consecutive actual serials/);
  for (const serial of [4n, 5n]) {
    assert.throws(() => replayCollectionInventoryScan(c, start, 7n, 1n, [known(7n, serial)]), /strictly increase/);
  }
});

test("fast append follows actual serial rather than count and starts above the complete scan cursor", () => {
  const c = coordinates(), start = replayCollectionInventoryScan(c, empty(c), 6n, 6n, scanFacts()).after;
  const cursor = replayCollectionInventoryScan(c, start, 10n, 4n, [gap(7n), gap(8n), gap(9n), known(10n, 3n, 1n, 99n)]).after;
  assert.equal(cursor.scanThrough, 10n); assert.equal(cursor.lastIndexedSerial, 5n);
  assert.throws(() => replayCollectionInventoryAppend(c, cursor, [known(9n, 6n)]), /above the scan cursor/);
  const result = replayCollectionInventoryAppend(c, cursor, [known(12n, 6n), known(19n, 7n, 3n)]);
  const expected = literalAppend(literalAppend(cursor.prefixHash, 6n, 12n), 7n, 19n);
  assert.deepEqual(result.after, { indexedCount: 4n, prefixHash: expected, lastIndexedSerial: 7n, scanThrough: 19n });
  assert.deepEqual(result.indexed.map(e => [e.ordinal, e.collectionSerial]), [[2n, 6n], [3n, 7n]]);
  for (const invalid of [[known(12n, 3n)], [known(12n, 7n)], [known(12n, 6n, 1n)],
    [gap(12n)], [known(12n, 6n, 2n, 99n)], [known(12n, 6n), known(12n, 7n)],
    [known(12n, 6n), known(19n, 8n)]]) {
    assert.throws(() => replayCollectionInventoryAppend(c, cursor, invalid), /consecutive actual serials/);
  }
  assert.throws(() => replayCollectionInventoryAppend(c, cursor, []));
  assert.throws(() => replayCollectionInventoryAppend(c, cursor, Array.from({ length: 257 }, (_, i) => known(BigInt(i + 11), BigInt(i + 6)))));
  assert.deepEqual(cursor, { ...start, scanThrough: 10n });
});

test("uint256 arithmetic matches checked Solidity serial addition even for skipped scan facts", () => {
  const c = coordinates(), maximumSerial = { indexedCount: 1n, prefixHash: id("prior"), lastIndexedSerial: UMAX, scanThrough: 4n };
  for (const fact of [gap(5n), known(5n, 1n, 1n, 99n)]) {
    assert.throws(() => replayCollectionInventoryScan(c, maximumSerial, 5n, 1n, [fact]), /Expected collection serial uint256 overflow/);
  }
  assert.deepEqual(replayCollectionInventoryScan(c, maximumSerial, 4n, 1n, []).after, maximumSerial);
  assert.throws(() => replayCollectionInventoryAppend(c, maximumSerial, [known(5n, 1n)]), /uint256 overflow/);
  const nearEnd = { indexedCount: 1n, prefixHash: id("near end"), lastIndexedSerial: 3n, scanThrough: UMAX - 1n };
  const result = replayCollectionInventoryScan(c, nearEnd, UMAX, 256n, [known(UMAX, 8n)]);
  assert.equal(result.after.scanThrough, UMAX);
  assert.deepEqual(replayCollectionInventoryScan(c, result.after, UMAX, 256n, []).after, result.after);
});

test("batch partitioning preserves one historical prefix across a 256-ID boundary", () => {
  const c = coordinates();
  const input = Array.from({ length: 260 }, (_, i) => {
    const token = BigInt(i + 1);
    return i % 3 === 0 ? known(token, token * 2n, i % 2 === 0 ? 2n : 3n)
      : i % 3 === 1 ? gap(token) : known(token, token, 1n, 99n);
  });
  let expectedPrefix = literalEmpty(c), expectedCount = 0n, expectedSerial = 0n;
  for (const f of input) if (f.collectionId === c.collectionId) {
    expectedPrefix = literalAppend(expectedPrefix, f.collectionSerial, f.tokenId); expectedCount++; expectedSerial = f.collectionSerial;
  }
  for (const size of [1, 7, 64, 256]) {
    let checkpoint = empty(c);
    for (let i = 0; i < input.length; i += size) {
      checkpoint = replayCollectionInventoryScan(c, checkpoint, 260n, BigInt(size), input.slice(i, i + size)).after;
    }
    assert.deepEqual(checkpoint, { indexedCount: expectedCount, prefixHash: expectedPrefix, lastIndexedSerial: expectedSerial, scanThrough: 260n });
  }
});

test("replay snapshots freeze coordinates, checkpoints and every retained skipped identity", async () => {
  const c = coordinates(), before = empty(c), input = scanFacts();
  const result = replayCollectionInventoryScan(c, before, 6n, 6n, input);
  const expected = structuredClone(result);
  await Promise.resolve();
  c.collectionId = 99n; before.prefixHash = ZeroHash; input[1].lifecycle = 3n; input[2].collectionSerial = 100n; input.push(gap(7n));
  assert.deepEqual(result, expected);
  for (const object of [result, result.coordinates, result.before, result.after, result.facts, ...result.facts, result.indexed, ...result.indexed]) {
    assert.equal(Object.isFrozen(object), true);
  }
  assert.throws(() => { result.after.scanThrough = 100n; }, TypeError);
  assert.throws(() => { result.facts[1].lifecycle = 3n; }, TypeError);
  assert.throws(() => result.indexed.push(result.indexed[0]), TypeError);
});

test("coordinates and evidence reject lossy numbers, extra properties and invented commitments", () => {
  const c = coordinates();
  for (const value of [0n, -1n, 1n << 256n, 1, "1"]) {
    assert.throws(() => normalizeCollectionInventoryCoordinates({ ...c, collectionId: value }));
    assert.throws(() => normalizeCollectionInventoryCoordinates({ ...c, chainId: value }));
    assert.throws(() => normalizeCollectionInventoryCoreIdentity({ ...known(1n, 1n), tokenId: value }));
  }
  for (const bad of [{ ...c, core: ZeroAddress }, { ...c, inventory: "invalid" }, { ...c, caller: c.core }]) {
    assert.throws(() => normalizeCollectionInventoryCoordinates(bad));
  }
  for (const bad of [{ ...empty(c), finalized: true }, { ...empty(c), prefixHash: "0x00" }, { ...empty(c), indexedCount: 0 },
    { ...empty(c), scanThrough: -1n }, { ...empty(c), lastIndexedSerial: 1n << 256n }]) {
    assert.throws(() => normalizeCollectionInventoryCheckpoint(c, bad));
  }
  for (const bad of [{ ...gap(1n), mappingExists: 0n }, { ...gap(1n), burned: 0 }, { ...known(1n, 1n), lifecycle: 2 },
    { ...known(1n, 1n), collectionSerial: Number.MAX_SAFE_INTEGER }, { ...known(1n, 1n), protocolHash: id("invented") }]) {
    assert.throws(() => normalizeCollectionInventoryCoreIdentity(bad));
  }
  assert.throws(() => replayCollectionInventoryScan(c, empty(c), 1, 1n, [gap(1n)]));
  assert.throws(() => replayCollectionInventoryScan(c, empty(c), 1n, 1n, {}));
  assert.throws(() => collectionInventoryAppendPrefix(id("prefix"), 0n, 1n));
});
