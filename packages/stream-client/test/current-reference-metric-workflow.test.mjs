import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  AbiCoder,
  Interface,
  ZeroAddress,
  ZeroHash,
  hexlify,
  id,
  keccak256,
} from "ethers";
import {
  REFERENCE_METRIC_CANONICALIZATION_HASH,
  REFERENCE_METRIC_PROFILE_HASH,
  REFERENCE_METRIC_SCHEMA_HASH,
  decodeReferenceMetricTranscript,
  decodeReferenceMetricSupplement,
  referenceMetricInputManifest,
  referenceMetricTranscriptBytes,
  referenceMetricSupplementHash,
} from "../dist/current-reference-metric.js";
import {
  inspectCurrentReferenceMetricSupplement,
  inspectHistoricalReferenceMetricSupplement,
  inspectReferenceMetricChunkAvailability,
  inspectReferenceMetricPublicationReceipt,
  inspectReferenceMetricSupplementPublication,
  prepareReferenceMetricSupplementPlan,
  simulateReferenceMetricChunkUpload,
  simulateReferenceMetricSupplementPublication,
} from "../dist/current-reference-metric-workflow.js";

const fixture = JSON.parse(await readFile(
  new URL("./fixtures/current-reference-metric-abi.json", import.meta.url),
  "utf8",
));
const replayBytes = await readFile(
  new URL("./fixtures/current-reference-metric-replay.abi", import.meta.url),
);
const publicationAbi = new Interface(fixture.abis.publication);
const storeAbi = new Interface(fixture.abis.store);
const metadataAbi = new Interface(fixture.abis.metadata);
const safeAbi = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns (bool)",
]);
const coder = AbiCoder.defaultAbiCoder();
const A = value => `0x${BigInt(value).toString(16).padStart(40, "0")}`;
const chainId = 31337n;
const producer = A(1);
const store = A(2);
const core = A(3);
const metadata = A(4);
const caller = A(5);
const collectionId = 77n;
const revision = 4n;
const referenceRecordHash = `0x${"34".repeat(32)}`;
const implementationHash = "0xdf70cb98b947f970bd117c6e7343c1471c9059efa9e36a8248e33c0e59b51aff";
const parametersHash = "0x1284b35afa316cb69d790a354cefdeb19d00a37116b1ec25e2ded88a1f59add3";
const reportHash = "0x32b889d85d6f36269730d5e3c2a9b4f9cde4ba3ee51723a75a37a90300f3cdc9";
const firstSha = "0x67f5c738d0805c210ffc7294b4eb21cec527dc14d3fb028f315a0a16a078182b";
const secondSha = "0xd410dd8d32b5dc55f03dde6cb0367ba31682a49a1af9a0c15308527a41c6838b";
const CURATOR = id("6529STREAM_RECORD_FAMILY_CURATOR_V1");

function dependencies() {
  return {
    targets: [core, metadata, A(30), store, A(31), A(32), A(33)],
    codeHashes: Array.from({ length: 7 }, (_, index) => id(`code ${index}`)),
  };
}

function source() {
  const retained = decodeReferenceMetricSupplement(hexlify(replayBytes));
  const originalBase = {
    referenceRecordHash,
    contextHash: ZeroHash,
    environmentObjectHash: retained.runtime.environmentObjectHash,
    environmentManifestHash: retained.runtime.environmentManifestHash,
    viewportWidth: 16n,
    viewportHeight: 16n,
    devicePixelRatio: 1n,
    packageFiles: retained.runtime.members,
    captures: [{ firstSha256: firstSha, secondSha256: secondSha }],
    metricImplementationHash: implementationHash,
    metricParametersHash: parametersHash,
    reportHash,
    threshold: 990000000n,
    evaluatedAt: 1n,
  };
  const draft = { original: originalBase };
  const publication = originalPublication(draft);
  const publicationParam = publicationAbi.getFunction("modeContextHash").inputs[0];
  const captureParam = publicationParam.components.find(component => component.name === "captures");
  const environmentParam = publicationParam.components.find(component => component.name === "environment");
  const fixed = dependencies();
  const computedContextHash = keccak256(coder.encode(
    [
      "bytes32",
      "uint256",
      "address",
      "address[7]",
      "bytes32[7]",
      "uint256",
      "bytes32",
      "bytes32",
      "uint64",
      captureParam,
      environmentParam,
    ],
    [
      id("6529STREAM_REFERENCE_MODE_CONTEXT_V1"),
      chainId,
      producer,
      fixed.targets,
      fixed.codeHashes,
      publication[0],
      publication[1],
      publication[4],
      publication[5],
      publication[7],
      publication[8],
    ],
  ));
  const original = { ...originalBase, contextHash: computedContextHash };
  const inputManifest = referenceMetricInputManifest(original);
  const metric = metricValue();
  const metricParam = publicationAbi
    .getFunction("referenceModeEvidence")
    .outputs[0]
    .components
    .find(component => component.name === "perceptual")
    .components
    .find(component => component.name === "metric");
  const computedReportHash = keccak256(coder.encode(
    ["bytes32", "bytes32", metricParam, "int64", "int64[]", "uint64"],
    [
      id("6529STREAM_PERCEPTUAL_REPORT_V1"),
      computedContextHash,
      metric,
      original.threshold,
      [1000000000n],
      original.evaluatedAt,
    ],
  ));
  const transcript = decodeReferenceMetricTranscript(retained.replay.transcript);
  const changedTranscript = referenceMetricTranscriptBytes({
    ...transcript,
    contextHash: computedContextHash,
    reportHash: computedReportHash,
    inputsHash: keccak256(inputManifest),
  });
  const supplement = {
    ...retained,
    replay: {
      ...retained.replay,
      contextHash: computedContextHash,
      reportHash: computedReportHash,
      inputsHash: keccak256(inputManifest),
      inputManifest,
      transcript: changedTranscript,
    },
  };
  const finalOriginal = { ...original, reportHash: computedReportHash };
  const evidenceValue = evidence({ original: finalOriginal })[0];
  const evidenceParam = publicationAbi.getFunction("referenceModeEvidence").outputs[0];
  const computedEvidenceHash = keccak256(coder.encode([evidenceParam], [evidenceValue]));
  const plan = prepareReferenceMetricSupplementPlan(
    chainId,
    producer,
    store,
    core,
    metadata,
    caller,
    { collectionId, revision },
    finalOriginal,
    supplement,
    supplement.replay.executedAt,
  );
  return {
    supplement,
    original: finalOriginal,
    plan,
    contextHash: computedContextHash,
    evidenceHash: computedEvidenceHash,
  };
}

function metricValue() {
  return [
    id("metric id"),
    id("algorithm"),
    "metric",
    "1",
    implementationHash,
    parametersHash,
    1000000000n,
  ];
}

const zeroReference = [0n, ZeroHash, "0x", ""];
const zeroInterviewRecord = [0n, ZeroAddress, ZeroAddress, ZeroHash, ZeroHash, ZeroHash, zeroReference];
const zeroInterview = [0n, zeroInterviewRecord, zeroReference];
const zeroArtist = [ZeroHash, 0n, ZeroHash, 0n];
const zeroDisplay = [
  zeroReference,
  zeroReference,
  zeroReference,
  zeroReference,
  zeroReference,
  zeroReference,
];
const zeroIntent = [
  ZeroHash,
  ZeroHash,
  ZeroHash,
  zeroArtist,
  zeroDisplay,
  zeroReference,
  zeroReference,
  zeroReference,
  zeroInterview,
];
const zeroCondition = [
  ZeroHash,
  ZeroHash,
  ZeroHash,
  ZeroHash,
  ZeroAddress,
  "",
  zeroReference,
  zeroReference,
  0n,
  [],
];

function originalPublication(value) {
  return [
    collectionId,
    id("reference id"),
    ZeroHash,
    3n,
    id("snapshot record"),
    2n,
    id("source hash"),
    [[
      1n,
      1n,
      id("metadata json"),
      id("html"),
      1n,
      "0x00",
      id("capture object"),
      id("capture coverage"),
      id("capture source"),
      [firstSha, secondSha],
      value.original.environmentManifestHash,
      2n,
    ]],
    [
      value.original.environmentObjectHash,
      id("environment coverage"),
      value.original.environmentManifestHash,
      1n,
      "engine",
      "1",
      id("engine executable"),
      "toolchain",
      "1",
      id("toolchain"),
      "engine.exe",
      "tool.exe",
      value.original.packageFiles.map(row => [row.path, row.byteSize, row.sha256Digest]),
      [],
      "windows",
      "server",
      "x86_64",
      value.original.viewportWidth,
      value.original.viewportHeight,
      value.original.devicePixelRatio,
      "srgb",
      true,
      id("capture profile"),
      "undetermined",
    ],
    "ipfs://reference",
    3n,
    id("reason"),
  ];
}

function originalReceipt() {
  return [
    referenceRecordHash,
    id("record chain"),
    collectionId,
    id("reference id"),
    ZeroHash,
    revision,
    id("payload"),
    1n,
    id("sources"),
    id("snapshot record"),
    2n,
    A(20),
    3n,
    2n,
    3n,
    4n,
    id("reason"),
    id("schema"),
    id("profile"),
    id("canonicalization"),
  ];
}

function evidence(value) {
  const metric = metricValue();
  const perceptual = [
    metric,
    value.original.threshold,
    [1000000000n],
    value.original.reportHash,
    "ipfs://report",
    1n,
  ];
  const curated = [ZeroHash, ZeroHash, 0n, zeroIntent, [], zeroCondition];
  const modeEvidence = [1n, [], perceptual, curated];
  const evidenceParam = publicationAbi.getFunction("referenceModeEvidence").outputs[0];
  const computedEvidenceHash = keccak256(coder.encode([evidenceParam], [modeEvidence]));
  const facts = [1n, computedEvidenceHash, id("interpretation"), ZeroHash, ZeroHash, ZeroHash, []];
  return [modeEvidence, facts];
}

function metricReceipt(value, authorizationClass = 3n, grantRevision = 9n) {
  const recordedAt = value.supplement.replay.executedAt + 10n;
  const coordinates = {
    chainId,
    producer,
    core,
    metadata,
    referenceRecordHash,
  };
  const base = {
    supplementHash: ZeroHash,
    referenceRecordHash,
    payloadHash: value.plan.artifact.payloadHash,
    payloadBytes: BigInt((value.plan.artifact.canonical.length - 2) / 2),
    runtimeHash: value.plan.artifact.runtimeHash,
    replayHash: value.plan.artifact.replayHash,
    schemaHash: REFERENCE_METRIC_SCHEMA_HASH,
    profileHash: REFERENCE_METRIC_PROFILE_HASH,
    canonicalizationHash: REFERENCE_METRIC_CANONICALIZATION_HASH,
    recorder: caller,
    authorizationClass,
    grantRevision,
    recordedAt,
  };
  return {
    ...base,
    supplementHash: referenceMetricSupplementHash(coordinates, base),
  };
}

function provider(value, controls = {}) {
  const pointerByHash = new Map();
  const chunkByPointer = new Map();
  for (const chunk of value.plan.chunks) {
    if (!pointerByHash.has(chunk.hash)) {
      const pointer = A(100 + pointerByHash.size);
      pointerByHash.set(chunk.hash, pointer);
      chunkByPointer.set(pointer.toLowerCase(), chunk.bytes);
    }
  }
  const seen = [];
  const service = {
    seen,
    getNetwork: async () => {
      if (controls.networkGate) await controls.networkGate;
      return { chainId };
    },
    getCode: async (pointer, blockTag) => {
      assert.equal(blockTag, 123);
      const bytes = chunkByPointer.get(pointer.toLowerCase());
      if (controls.badCode && pointer.toLowerCase() === [...chunkByPointer.keys()][0]) {
        return "0x0000";
      }
      return bytes ? `0x00${bytes.slice(2)}` : "0x";
    },
    getBlock: async blockTag => ({
      number: blockTag,
      timestamp: Number(metricReceipt(value).recordedAt),
    }),
    call: async transaction => {
      seen.push(transaction);
      assert.equal(transaction.blockTag, 123);
      const target = transaction.to.toLowerCase();
      if (target === store.toLowerCase()) {
        const parsed = storeAbi.parseTransaction({ data: transaction.data });
        switch (parsed.name) {
          case "MAX_CHUNK_BYTES": return storeAbi.encodeFunctionResult(parsed.fragment, [8192n]);
          case "chunk": {
            const chunkHash = parsed.args[0].toLowerCase();
            const pointer = pointerByHash.get(chunkHash) ?? ZeroAddress;
            const chunk = value.plan.chunks.find(row => row.hash === chunkHash);
            return storeAbi.encodeFunctionResult(parsed.fragment, [
              controls.missingChunk === chunkHash ? ZeroAddress : pointer,
              controls.missingChunk === chunkHash ? 0n : BigInt((chunk.bytes.length - 2) / 2),
            ]);
          }
          case "publishChunk": {
            const bytes = parsed.args[0];
            const chunk = value.plan.chunks.find(row => row.bytes === bytes);
            return storeAbi.encodeFunctionResult(parsed.fragment, [
              chunk.hash,
              pointerByHash.get(chunk.hash),
            ]);
          }
          default: throw new Error(`unexpected Store call ${parsed.name}`);
        }
      }
      if (target === metadata.toLowerCase()) {
        const parsed = metadataAbi.parseTransaction({ data: transaction.data });
        assert.equal(parsed.name, "familyWriter");
        assert.equal(parsed.args[1], CURATOR);
        const cls = BigInt(parsed.args[2]);
        const active = controls.noAuthority
          ? false
          : controls.class8 ? cls === 8n : cls === 3n;
        return metadataAbi.encodeFunctionResult(parsed.fragment, [active, active ? 9n : 0n]);
      }
      const parsed = publicationAbi.parseTransaction({ data: transaction.data });
      switch (parsed.name) {
        case "dependencies": return publicationAbi.encodeFunctionResult(parsed.fragment, [[
          dependencies().targets,
          dependencies().codeHashes,
          chainId,
          id("renderer catalog"),
          id("renderer hash"),
          1n,
          1n,
          1n,
          1n,
          1n,
        ]]);
        case "core": return publicationAbi.encodeFunctionResult(parsed.fragment, [core]);
        case "metadataHost": return publicationAbi.encodeFunctionResult(parsed.fragment, [metadata]);
        case "deploymentChainId": return publicationAbi.encodeFunctionResult(parsed.fragment, [chainId]);
        case "referenceRecord": return publicationAbi.encodeFunctionResult(parsed.fragment, [
          originalPublication(value),
          originalReceipt(),
        ]);
        case "currentReference":
        case "requireCurrent": return publicationAbi.encodeFunctionResult(parsed.fragment, [originalReceipt()]);
        case "referenceLock": return publicationAbi.encodeFunctionResult(parsed.fragment, [[ZeroHash, 0n, ZeroHash, 0n]]);
        case "referenceMode": return publicationAbi.encodeFunctionResult(parsed.fragment, [
          1n,
          controls.wrongEvidence ? id("wrong evidence") : value.evidenceHash,
        ]);
        case "referenceModeEvidence": {
          const rows = evidence(value);
          if (controls.wrongEvidence) rows[1][1] = id("wrong evidence facts");
          return publicationAbi.encodeFunctionResult(parsed.fragment, rows);
        }
        case "modeContextHash": return publicationAbi.encodeFunctionResult(parsed.fragment, [
          controls.wrongContext ? id("wrong context") : value.contextHash,
        ]);
        case "publishMetricSupplement": return publicationAbi.encodeFunctionResult(parsed.fragment, [
          controls.simulatedHash ?? metricReceipt(value).supplementHash,
        ]);
        case "metricSupplement": {
          const receipt = metricReceipt(value, controls.class8 ? 8n : 3n);
          return publicationAbi.encodeFunctionResult(parsed.fragment, [value.plan.artifact.canonical, receipt]);
        }
        case "requireMetricSupplement": {
          const receipt = metricReceipt(value, controls.class8 ? 8n : 3n);
          return publicationAbi.encodeFunctionResult(parsed.fragment, [receipt]);
        }
        default: throw new Error(`unexpected producer call ${parsed.name}`);
      }
    },
  };
  return service;
}

test("compiled fixture and prepared staged plan preserve every bounded chunk occurrence", () => {
  const value = source();
  assert.equal(fixture.sourceCommit, "7d5ba35cecad1f6d824332c07de1cb79612da59d");
  assert.equal(fixture.sourceCount, 2069);
  assert.equal(
    value.plan.chunks.length,
    Math.ceil(((value.plan.artifact.canonical.length - 2) / 2) / 8192),
  );
  assert.deepEqual(value.plan.chunks.map(row => row.index),
    Array.from({ length: value.plan.chunks.length }, (_, index) => index));
  assert(value.plan.chunks.every(row => row.call.to === store && row.call.value === 0n));
  assert.equal(value.plan.publication.to, producer);
  assert.equal(value.plan.publication.value, 0n);
  const final = publicationAbi.decodeFunctionData("publishMetricSupplement", value.plan.publication.data);
  assert.equal(final[0], referenceRecordHash);
  assert.equal(publicationAbi.getFunction("publishMetricSupplement").stateMutability, "nonpayable");
});

test("chunk inspection verifies Store rows and exact STOP-prefixed code, while upload stays permissionless", async () => {
  const value = source();
  const rpc = provider(value);
  const rows = await inspectReferenceMetricChunkAvailability(rpc, value.plan, { blockTag: 123 });
  assert.equal(rows.length, value.plan.chunks.length);
  const uploaded = await simulateReferenceMetricChunkUpload(rpc, value.plan, 0, { blockTag: 123 });
  assert.equal(uploaded.hash, value.plan.chunks[0].hash);
  assert.equal(rpc.seen.at(-1).from, caller);
  await assert.rejects(
    inspectReferenceMetricChunkAvailability(provider(value, { badCode: true }), value.plan, { blockTag: 123 }),
    /code differs/,
  );
  await assert.rejects(
    inspectReferenceMetricChunkAvailability(
      provider(value, { missingChunk: value.plan.chunks[0].hash }),
      value.plan,
      { blockTag: 123 },
    ),
    /chunk pointer/,
  );
});

test("publication inspection binds current original projection, class authority, chunks and exact caller simulation", async () => {
  const value = source();
  const rpc = provider(value);
  const inspected = await inspectReferenceMetricSupplementPublication(rpc, value.plan, { blockTag: 123 });
  assert.equal(inspected.authority.authorizationClass, 3n);
  assert.equal(inspected.original.contextHash, value.contextHash);
  assert.equal(inspected.original.evidenceHash, value.evidenceHash);
  const authorityReads = rpc.seen.filter(row => row.to.toLowerCase() === metadata.toLowerCase());
  assert.equal(authorityReads.length, 1);
  assert.equal(BigInt(metadataAbi.parseTransaction({ data: authorityReads[0].data }).args[2]), 3n);
  const result = await simulateReferenceMetricSupplementPublication(rpc, value.plan, { blockTag: 123 });
  assert.equal(result, metricReceipt(value).supplementHash);
  const finalCall = rpc.seen.find(row => row.data === value.plan.publication.data);
  assert.equal(finalCall.from, caller);
  assert.equal(finalCall.value, 0n);
  const global = await inspectReferenceMetricSupplementPublication(
    provider(value, { class8: true }),
    value.plan,
    { blockTag: 123 },
  );
  assert.equal(global.authority.authorizationClass, 8n);
  await assert.rejects(
    inspectReferenceMetricSupplementPublication(
      provider(value, { noAuthority: true }),
      value.plan,
      { blockTag: 123 },
    ),
    /lacks current Metadata CURATOR/,
  );
  await assert.rejects(
    inspectReferenceMetricSupplementPublication(
      provider(value, { wrongContext: true }),
      value.plan,
      { blockTag: 123 },
    ),
    /projection differs/,
  );
  await assert.rejects(
    inspectReferenceMetricSupplementPublication(
      provider(value, { wrongEvidence: true }),
      value.plan,
      { blockTag: 123 },
    ),
    /projection differs|mode differs/,
  );
  await assert.rejects(
    simulateReferenceMetricSupplementPublication(
      provider(value, { simulatedHash: id("wrong simulated supplement") }),
      value.plan,
      { blockTag: 123 },
    ),
    /pinned receipt preimage/,
  );
});

test("publication inspection snapshots the plan and block before awaiting network state", async () => {
  const value = source();
  let release;
  const networkGate = new Promise(resolve => { release = resolve; });
  const rpc = provider(value, { networkGate });
  const clone = structuredClone(value.plan);
  const options = { blockTag: 123 };
  const pending = inspectReferenceMetricSupplementPublication(rpc, clone, options);
  clone.publication.data = "0x1234";
  clone.locator.revision = 99n;
  options.blockTag = 999;
  release();
  const inspected = await pending;
  assert.equal(inspected.plan.locator.revision, revision);
  assert(rpc.seen.every(row => row.blockTag === 123));
  await assert.rejects(
    inspectReferenceMetricSupplementPublication(rpc, clone, { blockTag: 123 }),
    /canonical reconstruction/,
  );
});

test("historical retention and current requirement have distinct explicit read boundaries", async () => {
  const value = source();
  const authority = { recorder: caller, authorizationClass: 3n, grantRevision: 9n };
  const rpc = provider(value);
  const historical = await inspectHistoricalReferenceMetricSupplement(
    rpc,
    value.plan,
    authority,
    { blockTag: 123 },
  );
  assert.equal(historical.referenceRecordHash, referenceRecordHash);
  assert.equal(rpc.seen.some(row => publicationAbi.parseTransaction({ data: row.data })?.name === "requireMetricSupplement"), false);
  const current = await inspectCurrentReferenceMetricSupplement(
    provider(value),
    value.plan,
    authority,
    { blockTag: 123 },
  );
  assert.equal(current.supplementHash, historical.supplementHash);

  let release;
  const networkGate = new Promise(resolve => { release = resolve; });
  const mutableAuthority = { ...authority };
  const pending = inspectHistoricalReferenceMetricSupplement(
    provider(value, { networkGate }),
    value.plan,
    mutableAuthority,
    { blockTag: 123 },
  );
  mutableAuthority.authorizationClass = 8n;
  mutableAuthority.grantRevision = 99n;
  release();
  assert.equal((await pending).authorizationClass, 3n);
});

test("mined receipt validation binds exact CALL, event authority and block timestamp", async () => {
  const value = source();
  const receipt = metricReceipt(value);
  const transactionHash = id("metric publication transaction");
  const blockHash = id("metric publication block");
  const event = publicationAbi.encodeEventLog(
    publicationAbi.getEvent("ReferenceMetricSupplementPublished"),
    [1n, referenceRecordHash, receipt.supplementHash, receipt],
  );
  const safeData = safeAbi.encodeFunctionData("execTransaction", [
    producer,
    0n,
    value.plan.publication.data,
    0n,
    0n,
    0n,
    0n,
    ZeroAddress,
    ZeroAddress,
    "0x1234",
  ]);
  let transactionData = safeData;
  let transactionTo = caller;
  let receiptLogs = [{ address: producer, topics: event.topics, data: event.data }];
  const providerWithReceipt = {
    getNetwork: async () => ({ chainId }),
    getTransaction: async () => ({
      hash: transactionHash,
      blockNumber: 123,
      blockHash,
      from: A(99),
      to: transactionTo,
      value: 0n,
      data: transactionData,
    }),
    getTransactionReceipt: async () => ({
      hash: transactionHash,
      status: 1,
      blockNumber: 123,
      blockHash,
      logs: receiptLogs,
    }),
    getBlock: async () => ({ hash: blockHash, timestamp: Number(receipt.recordedAt) }),
  };
  const checked = await inspectReferenceMetricPublicationReceipt(
    providerWithReceipt,
    value.plan,
    { transactionHash, execution: "safe" },
  );
  assert.equal(checked.supplementHash, receipt.supplementHash);
  transactionTo = A(88);
  await assert.rejects(
    inspectReferenceMetricPublicationReceipt(
      providerWithReceipt,
      value.plan,
      { transactionHash, execution: "safe" },
    ),
    /does not target the reviewed Safe/,
  );
  transactionTo = caller;
  transactionData = `${safeData}${"00".repeat(600_000)}`;
  await assert.rejects(
    inspectReferenceMetricPublicationReceipt(
      providerWithReceipt,
      value.plan,
      { transactionHash, execution: "safe" },
    ),
    /malformed or oversized/,
  );
  transactionData = `${safeData}00`;
  await assert.rejects(
    inspectReferenceMetricPublicationReceipt(
      providerWithReceipt,
      value.plan,
      { transactionHash, execution: "safe" },
    ),
    /not an execTransaction envelope|differs from the reviewed CALL/,
  );
  transactionData = safeAbi.encodeFunctionData("execTransaction", [
    producer,
    0n,
    value.plan.publication.data,
    1n,
    0n,
    0n,
    0n,
    ZeroAddress,
    ZeroAddress,
    "0x1234",
  ]);
  await assert.rejects(
    inspectReferenceMetricPublicationReceipt(
      providerWithReceipt,
      value.plan,
      { transactionHash, execution: "safe" },
    ),
    /envelope differs/,
  );
  transactionData = safeData;
  receiptLogs = [{
    address: producer,
    topics: event.topics,
    data: `${event.data}00`,
  }];
  await assert.rejects(
    inspectReferenceMetricPublicationReceipt(
      providerWithReceipt,
      value.plan,
      { transactionHash, execution: "safe" },
    ),
    /exactly one supplement receipt/,
  );
  receiptLogs = [{ address: producer, topics: event.topics, data: event.data }];
  providerWithReceipt.getBlock = async () => ({
    hash: blockHash,
    timestamp: Number(receipt.recordedAt) + 1,
  });
  await assert.rejects(
    inspectReferenceMetricPublicationReceipt(
      providerWithReceipt,
      value.plan,
      { transactionHash, execution: "safe" },
    ),
    /timestamp differs/,
  );

  providerWithReceipt.getBlock = async () => ({
    hash: blockHash,
    timestamp: Number(receipt.recordedAt),
  });
  providerWithReceipt.getTransaction = async () => ({
    hash: transactionHash,
    blockNumber: 123,
    blockHash,
    from: caller,
    to: producer,
    value: 0n,
    data: value.plan.publication.data,
  });
  const direct = await inspectReferenceMetricPublicationReceipt(
    providerWithReceipt,
    value.plan,
    { transactionHash, execution: "direct" },
  );
  assert.equal(direct.supplementHash, receipt.supplementHash);
});
