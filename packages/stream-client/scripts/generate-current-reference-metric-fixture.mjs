// Frozen ABI and retained replay bytes, without executing or downloading metric artifacts.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const COMMIT = "7d5ba35cecad1f6d824332c07de1cb79612da59d";
const TREE = "6efe493b7447e6eb9ca63158685be57231cbeb97";
const INPUT_SHA = "b10b0bc4ada4e14dc133f9c6ba2dfe5bd23bffe64216aeab8ecc202815cbcd0c";
const OUTPUT_SHA = "d1549c61f90cd692e0809c6bfe75792742f7c68c430c00291153d27bbb6374ec";
const REPLAY_SHA = "919d2fd5eb99d921fc71442d46d2bc6d5bccc0ec77ab503d69bcb70a5f95b1fb";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const selections = {
  publication: {
    source: "smart-contracts/domains/preservation/StreamReferenceModePublication.sol", contract: "StreamReferenceModePublication",
    functions: ["dependencies", "core", "metadataHost", "deploymentChainId", "publishMetricSupplement",
      "metricSupplement", "requireMetricSupplement", "referenceRecord", "currentReference", "referenceLock",
      "referenceMode", "referenceModeEvidence", "modeContextHash", "requireCurrent", "referencePayload"],
    events: ["ReferenceMetricSupplementPublished"],
  },
  store: {
    source: "smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol", contract: "StreamSchemaDocumentStore",
    functions: ["publishChunk", "chunk", "readChunk", "MAX_CHUNK_BYTES"], events: ["ChunkPublished"],
  },
  metadata: {
    source: "smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol", contract: "StreamCollectionMetadataV1",
    functions: ["familyWriter"], events: [],
  },
};

export function currentReferenceMetricFixture(inputBytes, outputBytes, replayBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen reference metric compiler capture");
  if (replayBytes.length !== 219264 || sha(replayBytes) !== REPLAY_SHA) throw Error("Expected exact retained synthetic-context metric replay fixture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2069
    || output.errors?.some(error => error.severity === "error")) throw Error("Expected clean 2069-source ABI capture");
  const sources = Object.fromEntries(Object.entries(input.sources).sort(([a], [b]) => a.localeCompare(b)).map(([path, value]) => {
    if (typeof value.content !== "string") throw Error(`Missing literal source ${path}`);
    return [path, sha(value.content)];
  }));
  const abis = {};
  for (const [key, selection] of Object.entries(selections)) {
    const full = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing selected product ${selection.contract}`);
    const selected = full.filter(item => (item.type === "function" && selection.functions.includes(item.name))
      || (item.type === "event" && selection.events.includes(item.name)));
    if (selected.length !== selection.functions.length + selection.events.length
      || selection.functions.some(name => !selected.some(item => item.type === "function" && item.name === name))
      || selection.events.some(name => !selected.some(item => item.type === "event" && item.name === name))) throw Error(`Incomplete ABI ${key}`);
    abis[key] = selected;
  }
  return { schemaVersion: 1, sourceCommit: COMMIT, sourceTree: TREE,
    supplementCommit: "7ca6a2df111e607f8dca055253f0c2fad182720e", sourceCount: 2069, compilerVersion: "0.8.19",
    sourceNormalization: "Hashes preserve literal compiler inputs; Git comparison normalizes CRLF to LF only where recorded.",
    lineEndingOnlySourceDifferences: ["smart-contracts/interfaces/stream/entropy/IStreamEntropyFinalityPolicy.sol"],
    inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    qualification: "Source and compiled ABI evidence only. Retained replay has a synthetic original image/context boundary; no joined publication, current graph, gas, Safe runtime, deployment or release acceptance.",
    replay: { file: "current-reference-metric-replay.abi", sourceFile: "test/fixtures/preservation/reference-metric-replay-v1.abi",
      sourceCommit: "7ca6a2df111e607f8dca055253f0c2fad182720e", bytes: 219264, sha256: REPLAY_SHA,
      keccak256: "0x704890c8d588fcf16f927fa6b292ed3f3198594c7a54460a535b59d45b48ef13" },
    sources, selections, abis };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, replay, mode] = process.argv.slice(2);
  if (!input || !output || !replay || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-reference-metric-fixture.mjs INPUT OUTPUT REPLAY [--check]");
  const replayBytes = await readFile(replay);
  const result = JSON.stringify(currentReferenceMetricFixture(await readFile(input), await readFile(output), replayBytes), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-reference-metric-abi.json", import.meta.url);
  const replayTarget = new URL("../test/fixtures/current-reference-metric-replay.abi", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== result || !(await readFile(replayTarget)).equals(replayBytes)) throw Error("Stale metric fixture");
  } else {
    await writeFile(target, result, "utf8");
    await writeFile(replayTarget, replayBytes);
  }
}
