import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, ZeroHash, concat, hexlify, id, keccak256, sha256, toUtf8Bytes } from "ethers";
import * as metric from "../dist/current-reference-metric.js";
import { verifySafeCallPlan, simulateSafePlanStep } from "../dist/safe-plan.js";
import { simulateReferenceMetricChunkUpload } from "../dist/current-reference-metric-workflow.js";
import { prepareMetricSafeExample } from "../examples/current-reference-metric.mjs";

const fixture = JSON.parse(await readFile(new URL("./fixtures/current-reference-metric-abi.json", import.meta.url), "utf8"));
const rawBytes = await readFile(new URL("./fixtures/current-reference-metric-replay.abi", import.meta.url));
const canonical = hexlify(rawBytes), coder = AbiCoder.defaultAbiCoder();
const publicationAbi = new Interface(fixture.abis.publication), storeAbi = new Interface(fixture.abis.store);
const supplementType = publicationAbi.getFunction("publishMetricSupplement").inputs[1];
const runtimeType = supplementType.components.find(field => field.name === "runtime");
const replayType = supplementType.components.find(field => field.name === "replay");
const receiptType = publicationAbi.getFunction("requireMetricSupplement").outputs[0];
function plain(type, value) {
  if (type.baseType === "array") return Array.from(value, item => plain(type.arrayChildren, item));
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map((part, i) => [part.name, plain(part, value[i])]));
  return value;
}
const supplement = plain(supplementType, coder.decode([supplementType], canonical)[0]);
const referenceRecordHash = id("synthetic original reference identity");
const original = {
  referenceRecordHash, contextHash: `0x${"12".repeat(32)}`,
  environmentObjectHash: supplement.runtime.environmentObjectHash, environmentManifestHash: supplement.runtime.environmentManifestHash,
  viewportWidth: 16n, viewportHeight: 16n, devicePixelRatio: 1n, packageFiles: supplement.runtime.members,
  captures: [{ firstSha256: "0x67f5c738d0805c210ffc7294b4eb21cec527dc14d3fb028f315a0a16a078182b",
    secondSha256: "0xd410dd8d32b5dc55f03dde6cb0367ba31682a49a1af9a0c15308527a41c6838b" }],
  metricImplementationHash: "0xdf70cb98b947f970bd117c6e7343c1471c9059efa9e36a8248e33c0e59b51aff",
  metricParametersHash: "0x1284b35afa316cb69d790a354cefdeb19d00a37116b1ec25e2ded88a1f59add3",
  reportHash: "0x32b889d85d6f36269730d5e3c2a9b4f9cde4ba3ee51723a75a37a90300f3cdc9", threshold: 990000000n, evaluatedAt: 1n,
};
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const coordinates = { chainId: 31337n, producer: A(1), core: A(2), metadata: A(3), referenceRecordHash };
const authority = { recorder: A(4), authorizationClass: 3n, grantRevision: (1n << 63n) + 1n };
function hashes() {
  return { payloadHash: keccak256(canonical),
    runtimeHash: keccak256(coder.encode(["bytes32", runtimeType], [id("6529STREAM_METRIC_RUNTIME_V1"), supplement.runtime])),
    replayHash: keccak256(coder.encode(["bytes32", replayType], [id("6529STREAM_METRIC_REPLAY_V1"), supplement.replay])) };
}
function receipt() {
  const value = { supplementHash: ZeroHash, referenceRecordHash, payloadBytes: BigInt(rawBytes.length), ...hashes(),
    schemaHash: "0xe1d65752e9ccd6217a35d52ac5c3358bd1b22211472b10cd38461bac1795677a",
    profileHash: "0x9044071059abb70a02df3ebd40ce30ad024203d2058235540ff7c449ea8ef036",
    canonicalizationHash: "0x88c5f5a1b04f40ebae17a2c6f85ba5cd88c32d9139a809f0a1b209afbe15e883",
    ...authority, recordedAt: supplement.replay.executedAt + 1n };
  value.supplementHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", receiptType],
    [id("6529STREAM_METRIC_SUPPLEMENT_V1"), coordinates.chainId, coordinates.producer, coordinates.core, coordinates.metadata, value]));
  return value;
}

test("frozen metric fixture retains exact full replay bytes and separately pinned compiler provenance", () => {
  assert.equal(fixture.sourceCount, 2069); assert.equal(Object.keys(fixture.sources).length, 2069);
  assert.equal(fixture.sourceCommit, "7d5ba35cecad1f6d824332c07de1cb79612da59d");
  assert.deepEqual(fixture.lineEndingOnlySourceDifferences, ["smart-contracts/interfaces/stream/entropy/IStreamEntropyFinalityPolicy.sol"]);
  assert.equal(rawBytes.length, 219264); assert.equal(createHash("sha256").update(rawBytes).digest("hex"), fixture.replay.sha256);
  assert.equal(keccak256(canonical), fixture.replay.keccak256);
  assert.equal(supplement.runtime.members.length, 684); assert.equal((supplement.replay.transcript.length - 2) / 2, 28096);
  assert.equal(coder.encode([supplementType], [supplement]), canonical);
  assert.equal(supplementType.components.length, 5); assert.equal(receiptType.components.length, 13);
  assert.equal(publicationAbi.getFunction("publishMetricSupplement").stateMutability, "nonpayable");
  assert.equal(storeAbi.getFunction("publishChunk").stateMutability, "nonpayable");
});

test("literal original source index, capture-major inputs and three content hashes match retained evidence", () => {
  const sourcePaths = ["tools/museum/canonical.py", "tools/museum/chain_abi.py", "tools/preservation/reference_manifest.py", "tools/preservation/reference_metric.py"];
  assert.deepEqual(supplement.sources.map(file => file.path), sourcePaths);
  const index = hexlify(toUtf8Bytes(`{${supplement.sources.map(file => `"${file.path}":"${sha256(file.content).slice(2)}"`).join(",")}}`));
  assert.equal(metric.referenceMetricImplementationIndex(supplement.sources), index);
  assert.equal(index, supplement.implementationIndex); assert.equal(keccak256(index), original.metricImplementationHash);
  const input = hexlify(toUtf8Bytes(`{"captures":[{"firstSha256":"${original.captures[0].firstSha256}","height":16,"secondSha256":"${original.captures[0].secondSha256}","width":16}],"contextHash":"${original.contextHash}","environmentHash":"${original.environmentManifestHash}","evaluatedAt":1,"threshold":990000000}`));
  assert.equal(metric.referenceMetricInputManifest(original), input); assert.equal(input, supplement.replay.inputManifest);
  const expected = hashes(), artifact = metric.validateReferenceMetricSupplement(original, supplement, supplement.replay.executedAt);
  for (const [key, value] of Object.entries(expected)) assert.equal(artifact[key], value);
  assert.equal(artifact.canonical, canonical); assert.equal(artifact.original.referenceRecordHash, referenceRecordHash);
  assert.equal(metric.referenceMetricRuntimeHash(supplement.runtime), expected.runtimeHash);
  assert.equal(metric.referenceMetricReplayHash(supplement.replay), expected.replayHash);
  assert.equal(new Set(Object.values(expected)).size, 3);
});

test("transcript preserves all copied replay fields and original diagnostic bytes under its own domain", () => {
  const fields = ["bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "uint32", "bytes"];
  const envelope = coder.decode(fields, supplement.replay.transcript);
  assert.equal(envelope[0], id("6529STREAM_METRIC_TRANSCRIPT_V1"));
  for (const [index, field] of [[1, "runtimeHash"], [2, "contextHash"], [3, "reportHash"], [4, "inputsHash"], [5, "executedAt"], [6, "exitCode"]]) {
    assert.equal(envelope[index], supplement.replay[field]);
  }
  const parsed = metric.decodeReferenceMetricTranscript(supplement.replay.transcript);
  assert.equal(parsed.diagnostic, envelope[7]); assert.equal(metric.referenceMetricTranscriptBytes(parsed), supplement.replay.transcript);
  assert.throws(() => metric.decodeReferenceMetricTranscript(envelope[7]));
  const changed = [...envelope]; changed[1] = id("different runtime");
  assert.throws(() => metric.validateReferenceMetricSupplement(original, { ...supplement,
    replay: { ...supplement.replay, transcript: coder.encode(fields, changed) } }, supplement.replay.executedAt));
});

test("receipt identity zeroes its own hash and binds original reference, producer, authority and time", () => {
  const expected = receipt(), artifact = metric.validateReferenceMetricSupplement(original, supplement, expected.recordedAt);
  assert.equal(metric.referenceMetricSupplementHash(coordinates, expected), expected.supplementHash);
  assert.deepEqual(metric.validateReferenceMetricReceipt(coordinates, artifact, expected, authority), expected);
  assert.equal(new Set([expected.supplementHash, expected.payloadHash, expected.runtimeHash, expected.replayHash, referenceRecordHash]).size, 5);
  for (const key of ["producer", "core", "metadata"]) assert.notEqual(metric.referenceMetricSupplementHash({ ...coordinates, [key]: A(10) }, expected), expected.supplementHash);
  assert.throws(() => metric.validateReferenceMetricReceipt(coordinates, artifact, expected, { ...authority, recorder: A(8) }));
  assert.throws(() => metric.validateReferenceMetricReceipt(coordinates, artifact, expected, { ...authority, authorizationClass: 1n }));
  assert.throws(() => metric.validateReferenceMetricReceipt(coordinates, artifact, { ...expected, recordedAt: expected.recordedAt + 1n }, authority));
});

test("retention uses original ordered 8192-byte segments and exact final remainder", () => {
  const chunks = metric.referenceMetricSupplementChunks(canonical);
  assert.equal(chunks.length, 27); assert.equal(concat(chunks.map(chunk => chunk.bytes)), canonical);
  chunks.forEach((chunk, i) => {
    assert.equal(chunk.index, i); assert.equal(chunk.offset, i * 8192);
    assert.equal((chunk.bytes.length - 2) / 2, i === 26 ? 6272 : 8192);
    assert.equal(chunk.hash, keccak256(chunk.bytes));
  });
  const repeated = metric.referenceMetricSupplementChunks(`0x${"01".repeat(16384)}`);
  assert.equal(repeated.length, 2); assert.equal(repeated[0].hash, repeated[1].hash);
  assert.notEqual(repeated[0].offset, repeated[1].offset);
});

function safeReview() {
  return prepareMetricSafeExample({
    deployment: { ...coordinates, store: A(6) }, uploaderSafe: A(7), writerSafe: authority.recorder,
    locator: { collectionId: 77n, revision: 4n }, original, supplement,
    maximumExecutedAt: supplement.replay.executedAt,
    storeAbi: fixture.abis.store, publicationAbi: fixture.abis.publication,
  });
}

test("compiled-ABI Safe plan preserves every ordered chunk and a separately authorized final writer", () => {
  const review = safeReview(), { safePlan, uploads, publication } = review;
  assert.equal(safePlan.steps.length, 28);
  assert.deepEqual(verifySafeCallPlan(safePlan, review.abis), safePlan);
  assert.equal(uploads.artifact.canonical, publication.artifact.canonical);
  for (const [i, step] of safePlan.steps.entries()) {
    assert.equal(step.index, i); assert.equal(step.transaction.operation, 0); assert.equal(step.transaction.value, "0");
    if (i < 27) {
      assert.equal(step.safe, A(7)); assert.equal(step.transaction.to, A(6));
      const decoded = storeAbi.decodeFunctionData("publishChunk", step.transaction.data);
      assert.equal(decoded[0], `0x${canonical.slice(2 + i * 8192 * 2, 2 + (i + 1) * 8192 * 2)}`);
    } else {
      assert.equal(step.safe, authority.recorder); assert.equal(step.transaction.to, coordinates.producer);
      const decoded = publicationAbi.decodeFunctionData("publishMetricSupplement", step.transaction.data);
      assert.equal(decoded[0], referenceRecordHash); assert.equal(coder.encode([supplementType], [decoded[1]]), canonical);
    }
  }
  const changed = structuredClone(safePlan); changed.steps[27].safe = A(7);
  assert.throws(() => verifySafeCallPlan(changed, review.abis));
  const reordered = structuredClone(safePlan); [reordered.steps[0], reordered.steps[1]] = [reordered.steps[1], reordered.steps[0]];
  assert.throws(() => verifySafeCallPlan(reordered, review.abis));
});

test("failed staged simulation makes no earlier uploads and explicit upload retries preserve exact CALL bytes", async () => {
  const review = safeReview(), calls = [];
  const provider = { getNetwork: async () => ({ chainId: coordinates.chainId }), call: async tx => {
    calls.push(tx);
    if (tx.to === coordinates.producer) throw Error("missing retained chunks");
    const [bytes] = storeAbi.decodeFunctionData("publishChunk", tx.data);
    return storeAbi.encodeFunctionResult("publishChunk", [keccak256(bytes), A(8)]);
  } };
  await assert.rejects(simulateSafePlanStep(provider, review.safePlan, review.abis, 27), /missing retained/);
  assert.equal(calls.length, 1); assert.equal(calls[0].from, authority.recorder);
  const first = await simulateReferenceMetricChunkUpload(provider, review.uploads, 0, { blockTag: 42 });
  const retry = await simulateReferenceMetricChunkUpload(provider, review.uploads, 0, { blockTag: 42 });
  assert.deepEqual(first, retry); assert.deepEqual(calls[1], calls[2]);
  assert.equal(calls[1].from, A(7)); assert.equal(calls[1].value, 0n); assert.equal(calls[1].blockTag, 42);
  assert.equal(first.hash, review.uploads.chunks[0].hash);
  const bad = { call: async () => storeAbi.encodeFunctionResult("publishChunk", [id("wrong chunk"), A(8)]) };
  await assert.rejects(simulateReferenceMetricChunkUpload(bad, review.uploads, 0, { blockTag: 42 }), /differs/);
});
