import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { getBytes, hexlify, id } from "ethers";
import {
  REFERENCE_METRIC_CANONICALIZATION_HASH,
  REFERENCE_METRIC_PROFILE_HASH,
  REFERENCE_METRIC_SCHEMA_HASH,
  decodeReferenceMetricSupplement,
  decodeReferenceMetricTranscript,
  encodeReferenceMetricSupplement,
  referenceMetricImplementationIndex,
  referenceMetricPayloadHash,
  referenceMetricReplayHash,
  referenceMetricRuntimeHash,
  referenceMetricSupplementChunks,
  referenceMetricSupplementHash,
  referenceMetricTranscriptBytes,
  validateReferenceMetricReceipt,
  validateReferenceMetricSupplement,
} from "../dist/current-reference-metric.js";

const fixtureBytes = readFileSync(new URL(
  "./fixtures/current-reference-metric-replay.abi",
  import.meta.url,
));
const fixtureHex = hexlify(fixtureBytes);
const recordHash = `0x${"34".repeat(32)}`;
const contextHash = `0x${"12".repeat(32)}`;
const implementationHash = "0xdf70cb98b947f970bd117c6e7343c1471c9059efa9e36a8248e33c0e59b51aff";
const parametersHash = "0x1284b35afa316cb69d790a354cefdeb19d00a37116b1ec25e2ded88a1f59add3";
const reportHash = "0x32b889d85d6f36269730d5e3c2a9b4f9cde4ba3ee51723a75a37a90300f3cdc9";
const runtimeHash = "0xb48e4d17f67da4dab5dc2e52df363484ea73e5de74eaa581497490da6b42d198";
const replayHash = "0x7f88f64377870c028884417891c58090d2e0e77c7310b7dfa06e53431be4fe67";
const payloadHash = "0x704890c8d588fcf16f927fa6b292ed3f3198594c7a54460a535b59d45b48ef13";
const indexText = "{\"tools/museum/canonical.py\":\"208c31075112ee942818639774bae416855228e8e1cce8fbf033cd1181404069\",\"tools/museum/chain_abi.py\":\"4dc74a1d21ec5cd443e1ef97fa0a2c3ddd86b99bfaefd3ca76f6ead00109d94d\",\"tools/preservation/reference_manifest.py\":\"c6070bfe8552d0ab5bf31775c2976c77150482eb85076a2267f29f4179a41550\",\"tools/preservation/reference_metric.py\":\"88428ca6ca5babaea0bff0448b73b7edc45305db54edf07ef53f66a647d42a07\"}";

function original(supplement) {
  return {
    referenceRecordHash: recordHash,
    contextHash,
    environmentObjectHash: supplement.runtime.environmentObjectHash,
    environmentManifestHash: supplement.runtime.environmentManifestHash,
    viewportWidth: 16n,
    viewportHeight: 16n,
    devicePixelRatio: 1n,
    packageFiles: supplement.runtime.members,
    captures: [{
      firstSha256: "0x67f5c738d0805c210ffc7294b4eb21cec527dc14d3fb028f315a0a16a078182b",
      secondSha256: "0xd410dd8d32b5dc55f03dde6cb0367ba31682a49a1af9a0c15308527a41c6838b",
    }],
    metricImplementationHash: implementationHash,
    metricParametersHash: parametersHash,
    reportHash,
    threshold: 990000000n,
    evaluatedAt: 1n,
  };
}

function artifact() {
  const supplement = decodeReferenceMetricSupplement(fixtureHex);
  return validateReferenceMetricSupplement(
    original(supplement),
    supplement,
    supplement.replay.executedAt,
  );
}

test("retained replay decodes canonically and reproduces literal source-domain hashes", () => {
  assert.equal(fixtureBytes.length, 219264);
  assert.equal(
    createHash("sha256").update(fixtureBytes).digest("hex"),
    "919d2fd5eb99d921fc71442d46d2bc6d5bccc0ec77ab503d69bcb70a5f95b1fb",
  );
  const saved = decodeReferenceMetricSupplement(fixtureHex);
  assert.equal(encodeReferenceMetricSupplement(saved), fixtureHex);
  assert.equal(new TextDecoder().decode(getBytes(referenceMetricImplementationIndex(saved.sources))), indexText);
  assert.equal(referenceMetricRuntimeHash(saved.runtime), runtimeHash);
  assert.equal(referenceMetricReplayHash(saved.replay), replayHash);
  assert.equal(referenceMetricPayloadHash(saved), payloadHash);
  const checked = validateReferenceMetricSupplement(
    original(saved),
    saved,
    saved.replay.executedAt,
  );
  assert.equal(checked.payloadHash, payloadHash);
  assert.equal(checked.runtimeHash, runtimeHash);
  assert.equal(checked.replayHash, replayHash);
  assert.equal(checked.supplement.runtime.members.length, 684);
  assert.equal((checked.supplement.replay.transcript.length - 2) / 2, 28096);
  assert.equal(new TextDecoder().decode(getBytes(checked.inputManifest)),
    "{\"captures\":[{\"firstSha256\":\"0x67f5c738d0805c210ffc7294b4eb21cec527dc14d3fb028f315a0a16a078182b\",\"height\":16,\"secondSha256\":\"0xd410dd8d32b5dc55f03dde6cb0367ba31682a49a1af9a0c15308527a41c6838b\",\"width\":16}],\"contextHash\":\"0x1212121212121212121212121212121212121212121212121212121212121212\",\"environmentHash\":\"0x5a0224754f60b1df38229251a7f493c7012caa721202b105fb08fc93742b6a3f\",\"evaluatedAt\":1,\"threshold\":990000000}");
});

test("source, member, transcript, time and canonical-byte substitutions are rejected", () => {
  const saved = decodeReferenceMetricSupplement(fixtureHex);
  const substitutedBytes = getBytes(saved.sources[0].content);
  substitutedBytes[0] ^= 1;
  const changedSource = {
    ...saved,
    sources: saved.sources.map((source, index) => index === 0
      ? { ...source, content: hexlify(substitutedBytes) }
      : source),
  };
  assert.throws(() => encodeReferenceMetricSupplement(changedSource), /index differs/);
  const changedOrder = {
    ...saved,
    runtime: {
      ...saved.runtime,
      members: [saved.runtime.members[1], saved.runtime.members[0], ...saved.runtime.members.slice(2)],
    },
  };
  assert.throws(() => encodeReferenceMetricSupplement(changedOrder), /strict UTF-8 byte order/);
  const transcript = decodeReferenceMetricTranscript(saved.replay.transcript);
  const changedTranscript = referenceMetricTranscriptBytes({ ...transcript, reportHash: id("other report") });
  assert.throws(() => encodeReferenceMetricSupplement({
    ...saved,
    replay: { ...saved.replay, transcript: changedTranscript },
  }), /envelope differs/);
  assert.throws(() => validateReferenceMetricSupplement(
    original(saved),
    saved,
    saved.replay.executedAt - 1n,
  ), /original reference or replay profile/);
  assert.throws(() => decodeReferenceMetricSupplement(`${fixtureHex}00`), /canonical/);
});

test("Store chunk projection uses fixed 8192-byte order and retains duplicates", () => {
  const repeated = `0x${"ab".repeat(16_384)}`;
  const chunks = referenceMetricSupplementChunks(repeated);
  assert.equal(chunks.length, 2);
  assert.deepEqual(chunks.map(chunk => chunk.index), [0, 1]);
  assert.deepEqual(chunks.map(chunk => chunk.offset), [0, 8192]);
  assert.equal(chunks[0].bytes, chunks[1].bytes);
  assert.equal(chunks[0].hash, chunks[1].hash);
});

test("receipt binds canonical bytes, four coordinates and actual class-3 grant", () => {
  const canonical = artifact();
  const coordinates = {
    chainId: 1n,
    producer: "0x1111111111111111111111111111111111111111",
    core: "0x2222222222222222222222222222222222222222",
    metadata: "0x3333333333333333333333333333333333333333",
    referenceRecordHash: recordHash,
  };
  const authority = {
    recorder: "0x4444444444444444444444444444444444444444",
    authorizationClass: 3n,
    grantRevision: 9n,
  };
  let receipt = {
    supplementHash: `0x${"00".repeat(32)}`,
    referenceRecordHash: recordHash,
    payloadHash: canonical.payloadHash,
    payloadBytes: BigInt(fixtureBytes.length),
    runtimeHash: canonical.runtimeHash,
    replayHash: canonical.replayHash,
    schemaHash: REFERENCE_METRIC_SCHEMA_HASH,
    profileHash: REFERENCE_METRIC_PROFILE_HASH,
    canonicalizationHash: REFERENCE_METRIC_CANONICALIZATION_HASH,
    recorder: authority.recorder,
    authorizationClass: authority.authorizationClass,
    grantRevision: authority.grantRevision,
    recordedAt: canonical.supplement.replay.executedAt + 10n,
  };
  receipt = { ...receipt, supplementHash: referenceMetricSupplementHash(coordinates, receipt) };
  assert.equal(receipt.supplementHash, "0x75c9887e4ac2a75a77abb768c61aeb93e84741fb9ca858b263067c15b7d57aba");
  assert.equal(
    validateReferenceMetricReceipt(coordinates, canonical, receipt, authority).supplementHash,
    receipt.supplementHash,
  );

  const forgedRuntime = id("forged artifact runtime");
  const forgedArtifact = { ...canonical, runtimeHash: forgedRuntime };
  const forgedReceiptBase = { ...receipt, supplementHash: `0x${"00".repeat(32)}`, runtimeHash: forgedRuntime };
  const forgedReceipt = {
    ...forgedReceiptBase,
    supplementHash: referenceMetricSupplementHash(coordinates, forgedReceiptBase),
  };
  assert.throws(
    () => validateReferenceMetricReceipt(coordinates, forgedArtifact, forgedReceipt, authority),
    /canonical bytes or actual authority/,
  );
  assert.throws(
    () => validateReferenceMetricReceipt(coordinates, canonical, { ...receipt, recordedAt: 1n }, authority),
    /original reference or replay profile/,
  );
});
