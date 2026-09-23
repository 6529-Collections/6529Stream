import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, getAddress, id, keccak256 } from "ethers";
import { collectionInventoryEmptyPrefix, collectionInventoryAppendPrefix, replayCollectionInventoryScan,
  decodeCollectionInventoryCoreIdentity } from "../dist/current-collection-inventory.js";
import { createCollectionInventorySafeReview } from "../examples/current-collection-inventory.mjs";
import { verifySafeCallPlan } from "../dist/safe-plan.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-collection-inventory-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([name, entries]) => [name, new Interface(entries)]));
const coder = AbiCoder.defaultAbiCoder(), A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const coordinates = { chainId: (1n << 244n) + 31337n, inventory: A(41), core: A(42), collectionId: (1n << 220n) + 17n };
const empty = () => ({ indexedCount: 0n, prefixHash: collectionInventoryEmptyPrefix(coordinates), lastIndexedSerial: 0n, scanThrough: 0n });
const fact = (tokenId, serial, burned = false) => ({ tokenId, mappingExists: true, collectionId: coordinates.collectionId,
  collectionSerial: serial, burned, lifecycle: burned ? 3n : 2n });
const missing = tokenId => ({ tokenId, mappingExists: false, collectionId: 0n, collectionSerial: 0n, burned: false, lifecycle: 0n });

test("retained inventory ABI has additive serial lookup, unchanged ordinal interface and exact event indexing", () => {
  assert.equal(fixture.sourceCommit, "e6a1704005f6a1197903eac372a166383a910681");
  assert.equal(fixture.sourceCount, 62); assert.equal(Object.keys(fixture.sources).length, 62);
  assert.equal(fixture.inputSha256, "9a351a3b51b235a17d766ddaabc6d985fff8b34482d5f7ff92d6837220b6c631");
  assert.equal(fixture.outputSha256, "5d3138f0dfc73f346c9263de451c853a4db3067625cd6d7ac5a226857c00a96d");
  assert.equal(Object.values(fixture.abis).reduce((n, entries) => n + entries.length, 0), 44);
  assert.equal(abi.legacy.getFunction("collectionTokenBySerial"), null);
  assert.equal(abi.serialLookup.getFunction("collectionTokenAt"), null);
  for (const method of ["appendCollectionTokens", "collectionInventoryState", "collectionTokenAt", "core", "requireCompleteCollection"]) {
    assert.equal(abi.legacy.getFunction(method).format("full"), abi.inventory.getFunction(method).format("full"));
  }
  assert.deepEqual(abi.inventory.getEvent("CollectionTokenIndexed").inputs.map(p => [p.type, p.indexed]),
    [["uint256", true], ["uint256", true], ["uint256", false], ["bytes32", false]]);
  assert.deepEqual(abi.inventory.getFunction("scanCollectionTokens").outputs.map(p => [p.name, p.type]),
    [["scannedThrough", "uint256"], ["indexedCount", "uint256"], ["prefixHash", "bytes32"]]);
  assert.equal(abi.inventory.getFunction("scanCollectionTokens").stateMutability, "nonpayable");
  assert.equal(abi.inventory.getFunction("appendCollectionTokens").outputs.length, 0);
  assert.equal(abi.inventory.getError("InventoryScanPrepared").inputs[0].type, "uint256");
});

test("full-width original hash preimages bind serial gaps without inserting synthetic members", () => {
  const initial = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256"],
    [id("6529STREAM_TOKEN_INVENTORY_V1"), coordinates.chainId, coordinates.inventory, coordinates.core, coordinates.collectionId]));
  assert.equal(collectionInventoryEmptyPrefix(coordinates), initial);
  const serial = (1n << 230n) + 4n, tokenId = (1n << 240n) + 9n;
  const next = keccak256(coder.encode(["bytes32", "bytes32", "uint256", "uint256"],
    [id("6529STREAM_TOKEN_INVENTORY_APPEND_V1"), initial, serial, tokenId]));
  assert.equal(collectionInventoryAppendPrefix(initial, serial, tokenId), next);
  assert.notEqual(collectionInventoryAppendPrefix(initial, 1n, tokenId), next);
  const replay = replayCollectionInventoryScan(coordinates, empty(), 4n, 4n, [fact(1n, 1n), missing(2n), missing(3n), fact(4n, 4n, true)]);
  let expected = initial;
  for (const [serial, token] of [[1n, 1n], [4n, 4n]]) expected = keccak256(coder.encode(
    ["bytes32", "bytes32", "uint256", "uint256"], [id("6529STREAM_TOKEN_INVENTORY_APPEND_V1"), expected, serial, token]));
  assert.equal(replay.after.prefixHash, expected); assert.equal(replay.after.indexedCount, 2n);
  assert.deepEqual(replay.indexed.map(row => [row.ordinal, row.collectionSerial, row.tokenId]), [[0n, 1n, 1n], [1n, 4n, 4n]]);
});

test("Core compiler return tuples decode exactly and reject noncanonical bool aliases", () => {
  const token = (1n << 243n) + 3n, serial = (1n << 221n) + 7n;
  const raw = abi.core.encodeFunctionResult("tokenCollectionIdentity", [true, coordinates.collectionId, serial, true]);
  const life = abi.core.encodeFunctionResult("tokenLifecycle", [3]);
  assert.deepEqual(decodeCollectionInventoryCoreIdentity(token, raw, life), fact(token, serial, true));
  const malformed = coder.encode(["uint256", "uint256", "uint256", "uint256"], [2n, coordinates.collectionId, serial, 1n]);
  assert.throws(() => decodeCollectionInventoryCoreIdentity(token, malformed, life), /boolean/);
  assert.throws(() => decodeCollectionInventoryCoreIdentity(token, raw + "00", life), /exactly/);
});

test("Safe review preserves original serial/cursor coordinates and exact bounded compiler calldata", () => {
  const replay = replayCollectionInventoryScan(coordinates, empty(), 4n, 4n, [fact(1n, 1n), missing(2n), missing(3n), fact(4n, 4n)]);
  const capture = { deployment: { chainId: coordinates.chainId, inventory: { address: coordinates.inventory, codeHash: id("inventory runtime") },
    core: { address: coordinates.core, codeHash: id("core runtime") } }, coordinates, blockNumber: 71, blockHash: id("capture block"),
    checkpoint: replay.after, lastIndexedToken: fact(4n, 4n), frontier: 8n, mintedEver: 3n, complete: false };
  for (const operation of [{ kind: "append", tokenIds: [8n] }, { kind: "scan", maxScan: 256n }]) {
    const review = createCollectionInventorySafeReview({ capture, safe: A(49), operation, inventoryAbi: fixture.abis.inventory });
    verifySafeCallPlan(review.safePlan, [fixture.abis.inventory]);
    const method = operation.kind === "append" ? "appendCollectionTokens" : "scanCollectionTokens";
    const expected = abi.inventory.encodeFunctionData(method, [coordinates.collectionId, operation.tokenIds ?? operation.maxScan]);
    assert.equal(review.preparation.call.data, expected); assert.equal(review.safePlan.steps[0].transaction.data, expected);
    assert.equal(review.safePlan.steps[0].transaction.operation, 0); assert.equal(review.safePlan.steps[0].transaction.value, "0");
    assert.equal(review.safePlan.steps[0].safe, A(49)); assert.equal(review.review.lastIndexedSerial, "4");
    assert.equal(review.review.indexedCount, "2"); assert.equal(review.review.scanThrough, "4");
    assert.equal(review.review.collectionId, coordinates.collectionId.toString()); assert.equal(review.review.completeAtCapture, false);
    assert.ok(Object.isFrozen(review.review));
  }
  assert.throws(() => createCollectionInventorySafeReview({ capture, safe: A(49), operation: { kind: "scan", maxScan: 257n }, inventoryAbi: fixture.abis.inventory }), /1..256/);
  assert.throws(() => createCollectionInventorySafeReview({ capture, safe: A(49), operation: { kind: "scan", maxScan: 4n, tokenIds: [] }, inventoryAbi: fixture.abis.inventory }), /fields/);
});
