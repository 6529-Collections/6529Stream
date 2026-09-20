import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { AbiCoder, Interface, getAddress, hexlify, id, keccak256, toUtf8Bytes, toUtf8String } from "ethers";
import { prepareReferenceInventory, referenceInventoryParts } from "../dist/current-reference-inventory.js";
import { prepareReferenceInventoryPlan } from "../dist/current-reference-inventory-workflow.js";
import { verifySafeCallPlan } from "../dist/safe-plan.js";
import { createReferenceInventorySafeReview } from "../examples/current-reference-inventory.mjs";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-reference-inventory-abi.json", import.meta.url), "utf8"));
const corpus = JSON.parse(readFileSync(new URL("./fixtures/current-reference-inventory-corpus.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([name, records]) => [name, new Interface(records)]));
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const chainId = (1n << 240n) + 31337n, host = A(71), modeHost = A(72), store = A(73);
const uploader = A(80), preparer = A(81), codeHash = id("independently reviewed mock runtime");
const deployment = { chainId, publicationHost: { address: host, codeHash }, store: { address: store, codeHash } };
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const typedRows = rows => rows.map(row => ({ path: row.path, byteSize: BigInt(row.byteSize), sha256Digest: row.sha256Digest }));
function chunks(bytes) {
  const result = [];
  for (let offset = 0; offset < bytes.length; offset += 8192) result.push(hexlify(bytes.subarray(offset, offset + 8192)));
  return result;
}

test("frozen companion is additive and both concrete hosts expose exact original and staged tuples", () => {
  assert.equal(fixture.sourceCount, 125);
  assert.equal(Object.keys(fixture.sources).length, 125);
  assert.equal(Object.values(fixture.abis).reduce((sum, rows) => sum + rows.length, 0), 27);
  assert.equal(fixture.inputSha256, "5e9a2397a95a837f6466057a065165693c0c9c192f42452246136e2c60b348dc");
  assert.equal(fixture.outputSha256, "3b98544016dc3542d759d2da83f4d8cce8e73610a9a75af7fd1774689d3b6f2b");
  for (const target of [abi.host, abi.modeHost]) {
    for (const method of ["prepareFileInventory", "prepareFileInventoryPart", "prepareFileInventoryFromParts"]) {
      const fn = target.getFunction(method);
      assert.equal(fn.stateMutability, "nonpayable");
      assert.deepEqual(fn.inputs.map(p => p.format("sighash")), ["(string,uint64,bytes32)[]", "bool"]);
      assert.deepEqual(fn.outputs.map(p => p.type), ["bytes32"]);
    }
    assert.equal(target.getFunction("supportsInterface").stateMutability, "pure");
    assert.equal(target.getEvent("ReferenceInventoryPartPrepared").inputs[3].type, "uint16");
    assert.equal(target.getEvent("ReferenceInventoryAssembled").inputs[3].type, "uint256");
  }
  assert.equal(abi.companion.getFunction("prepareFileInventory"), null);
  const expectedId = BigInt(abi.companion.getFunction("prepareFileInventoryPart").selector)
    ^ BigInt(abi.companion.getFunction("prepareFileInventoryFromParts").selector);
  assert.notEqual(expectedId, 0n); // IERC165's inherited selector does not enter this companion ID.
  assert.equal(abi.host.getFunction("preparedFileInventory").outputs[0].type, "bytes");
});

test("the real 1048 and 102 row inventories reproduce independent canonical bytes and original IDs", () => {
  assert.equal(corpus.sourceFixtureCommit, "9cb5a32af45779f018f9b56f7ee0e57af4c6358a");
  assert.equal(corpus.sourceFixtureSha256, "dccfe2fc6ca80808b9ebcb9173df238598cccff3ffb9295ea8aa0497946d0564");
  assert.equal(corpus.sourceEnvironmentSha256, "4177e70740caaed5cdbe727891ad485cd7e075f87c3cb3cd735a89ce6db6f452");
  for (const [name, count, length] of [["packageFiles", 1048, 162109], ["platformPrerequisites", 102, 15583]]) {
    const source = corpus.inventories[name], rows = typedRows(source.rows);
    const original = Buffer.from(JSON.stringify(source.rows), "utf8");
    assert.equal(rows.length, count); assert.equal(original.length, length);
    assert.equal(sha(original), source.canonicalSha256);
    const snapshot = prepareReferenceInventory(chainId, host, source.relative, rows);
    assert.equal(snapshot.canonical, hexlify(original)); assert.equal(snapshot.byteLength, BigInt(length));
    assert.equal(snapshot.contentHash, keccak256(original));
    const param = abi.host.getFunction("prepareFileInventory").inputs[0];
    const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "bool", param],
      [id("6529STREAM_REFERENCE_FILE_INVENTORY_V1"), chainId, host, source.relative, rows]));
    assert.equal(snapshot.inventoryId, expected);
    assert.notEqual(prepareReferenceInventory(chainId, modeHost, source.relative, rows).inventoryId, expected);
  }
});

test("fixed64 parts reassemble genuine full inventories without changing full IDs or row bytes", () => {
  for (const [name, count, remainder] of [["packageFiles", 17, 24], ["platformPrerequisites", 2, 38]]) {
    const source = corpus.inventories[name], rows = typedRows(source.rows);
    const snapshot = prepareReferenceInventory(chainId, host, source.relative, rows);
    const parts = referenceInventoryParts(snapshot); assert.equal(parts.length, count);
    const param = abi.companion.getFunction("prepareFileInventoryPart").inputs[0];
    for (const [index, part] of parts.entries()) {
      const first = index * 64, originalRows = source.rows.slice(first, first + 64);
      assert.equal(part.index, index); assert.equal(part.rowOffset, first);
      assert.equal(part.rows.length, index + 1 === count ? remainder : 64);
      assert.equal(toUtf8String(part.canonical), JSON.stringify(originalRows));
      assert.equal(part.contentHash, keccak256(part.canonical));
      assert.equal(part.partId, keccak256(coder.encode(["bytes32", "uint256", "address", "bool", param],
        [id("6529STREAM_REFERENCE_FILE_INVENTORY_PART_V1"), chainId, host, source.relative, rows.slice(first, first + 64)])));
      assert.notEqual(part.partId, snapshot.inventoryId);
    }
    const assembled = `[${parts.map(p => toUtf8String(p.canonical).slice(1, -1)).join(",")}]`;
    assert.equal(hexlify(toUtf8Bytes(assembled)), snapshot.canonical);
    assert.equal(sha(assembled), source.canonicalSha256);
  }
});

test("staged plans upload part arrays and full-array chunks separately and use exact compiled calls", () => {
  const source = corpus.inventories.packageFiles;
  const snapshot = prepareReferenceInventory(chainId, host, true, typedRows(source.rows));
  const staged = prepareReferenceInventoryPlan(deployment, preparer, snapshot, { mode: "staged", uploader });
  const documents = [...staged.parts.map(p => Buffer.from(p.canonical.slice(2), "hex")), Buffer.from(snapshot.canonical.slice(2), "hex")];
  const expectedChunks = new Map(documents.flatMap(chunks).map(raw => [keccak256(raw), raw]));
  assert.deepEqual(staged.chunks.map(c => [c.hash, c.bytes]), [...expectedChunks]);
  assert.equal(staged.steps.length, staged.chunks.length + 17 + 1);
  for (const step of staged.steps) {
    assert.equal(step.call.value, 0n);
    if (step.kind === "upload") {
      assert.equal(step.caller, uploader); assert.equal(step.call.to, store);
      assert.equal(step.call.data, abi.store.encodeFunctionData("publishChunk", [staged.chunks[step.chunkIndex].bytes]));
    } else if (step.kind === "part") {
      const part = staged.parts[step.documentIndex];
      assert.equal(step.caller, preparer); assert.equal(step.identity, part.partId);
      assert.equal(step.call.data, abi.host.encodeFunctionData("prepareFileInventoryPart", [part.rows, true]));
    } else {
      assert.equal(step.kind, "assemble"); assert.equal(step.identity, snapshot.inventoryId);
      assert.equal(step.call.data, abi.modeHost.encodeFunctionData("prepareFileInventoryFromParts", [snapshot.rows, true]));
    }
  }
  const monolithic = prepareReferenceInventoryPlan(deployment, preparer, snapshot, { mode: "monolithic", uploader });
  assert.equal(monolithic.parts.length, 0); assert.equal(monolithic.snapshot.inventoryId, staged.snapshot.inventoryId);
  assert.equal(monolithic.steps.at(-1).call.data, abi.host.encodeFunctionData("prepareFileInventory", [snapshot.rows, true]));
  assert.notEqual(monolithic.steps.at(-1).call.data, staged.steps.at(-1).call.data);
  assert.ok(staged.chunks.length > monolithic.chunks.length);
});

test("Safe review retains exact caller, identities, full-width text and global call order", () => {
  const input = { deployment, uploaderSafe: uploader, preparerSafe: preparer,
    rows: typedRows(corpus.inventories.platformPrerequisites.rows), relative: false, mode: "staged",
    storeAbi: fixture.abis.store, publicationAbi: fixture.abis.modeHost };
  const result = createReferenceInventorySafeReview(input);
  assert.equal(result.pages.length, 1);
  assert.equal(result.review.length, result.preparation.steps.length);
  for (const page of result.pages) {
    verifySafeCallPlan(page.safePlan, page.abis);
    for (const [index, safeStep] of page.safePlan.steps.entries()) {
      const global = page.firstStep + index, original = result.preparation.steps[global], row = result.review[global];
      assert.equal(row.index, global); assert.equal(row.safe, original.caller);
      assert.equal(safeStep.safe, original.caller); assert.equal(safeStep.transaction.to, original.call.to);
      assert.equal(safeStep.transaction.data, original.call.data); assert.equal(safeStep.transaction.operation, 0);
      assert.equal(safeStep.transaction.value, "0"); assert.equal(row.identity, original.identity);
      assert.match(row.byteLength, /^(0|[1-9][0-9]*)$/);
    }
  }
  const reviewedParts = result.review.filter(row => row.kind === "part");
  assert.deepEqual(reviewedParts.map(row => [row.firstRow, row.rowCount]), [["1", "64"], ["65", "38"]]);
  const large = createReferenceInventorySafeReview({ ...input, relative: true,
    rows: [{ path: "file", byteSize: (1n << 64n) - 1n, sha256Digest: id("file") }] });
  assert.equal(large.pages[0].safePlan.steps.find(step => step.method.startsWith("prepareFileInventoryPart")).arguments[0][0][1], "18446744073709551615");
  assert.throws(() => createReferenceInventorySafeReview({ ...input, publicationAbi: fixture.abis.store }));
});

test("empty staged and monolithic plans retain the same original [] bytes and inventory ID", () => {
  const snapshot = prepareReferenceInventory(chainId, host, true, []);
  const staged = prepareReferenceInventoryPlan(deployment, preparer, snapshot, { mode: "staged" });
  const monolithic = prepareReferenceInventoryPlan(deployment, preparer, snapshot, { mode: "monolithic" });
  assert.equal(staged.parts.length, 0); assert.equal(staged.steps.length, 2);
  assert.equal(staged.chunks[0].bytes, "0x5b5d");
  assert.equal(staged.snapshot.inventoryId, monolithic.snapshot.inventoryId);
  const args = abi.host.decodeFunctionData("prepareFileInventoryFromParts", staged.steps[1].call.data);
  assert.equal(args[0].length, 0); assert.equal(args[1], true);
});
