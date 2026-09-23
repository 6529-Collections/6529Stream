// Project frozen Mode byte-preparation calls and original payload types from ABI57; never compile.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "84adf2af8226b1f052b12546a4afdd2e58d05ac276a7f6705e5a55ff686f34df";
const OUTPUT_SHA = "8ce143a79e67363cf84b0b8b6c7435006771c1acc1037dfdf14562d6b3c7b341";
const SOURCE_COMMIT = "9beafd1ab5e5a5c8403f24958e49801f34625e66";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const preservation = "smart-contracts/domains/preservation/";
const selections = {
  host: { source: preservation + "StreamReferenceModePublication.sol", contract: "StreamReferenceModePublication", methods: [
    "prepareModePublication", "prepareModePayload", "preparedModePublication", "preparedModePayload",
    "previewModeReference", "publishModeReference", "preparedFileInventory", "dependencies", "modeDependencies", "deploymentChainId",
    "core", "metadataHost", "metadataRouter", "snapshots", "archiveCoverage", "supportsInterface",
  ], events: ["ReferenceModePublicationPrepared", "ReferenceModePayloadPrepared"] },
  companion: { source: "smart-contracts/interfaces/stream/preservation/IStreamReferenceModePayloadPreparation.sol", contract: "IStreamReferenceModePayloadPreparation", full: true },
  environment: { source: "smart-contracts/interfaces/stream/preservation/IStreamReferenceEnvironmentPreparation.sol", contract: "IStreamReferenceEnvironmentPreparation", full: true },
  store: { source: "smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol", contract: "StreamSchemaDocumentStore",
    methods: ["MAX_CHUNK_BYTES", "chunk", "publishChunk"], events: ["ChunkPublished"] },
  metadata: { source: "smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol", contract: "IStreamCollectionMetadataV1",
    methods: ["familyWriter"], events: [] },
};
const oracleSources = [
  preservation + "StreamReferenceModePayloadPreparation.sol",
  preservation + "StreamReferenceModePayloadEncoding.sol",
  preservation + "StreamReferenceModePreparation.sol",
  preservation + "StreamReferenceModePublication.sol",
  preservation + "StreamReferenceModeProof.sol",
  preservation + "StreamReferenceRenderPreparation.sol",
  "smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol",
  "smart-contracts/domains/records/StreamSnapshotManifestBytes.sol",
  "smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol",
  "smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol",
];

export function referenceModePayloadFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen Mode payload ABI57 capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2248
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 2248-source capture");
  const sourceHashes = {}, sourceTexts = {}, abis = {};
  function visit(path) {
    if (Object.hasOwn(sourceHashes, path)) return;
    const literal = input.sources[path]?.content;
    if (typeof literal !== "string") throw Error(`Missing literal source ${path}`);
    sourceHashes[path] = sha(literal);
    for (const match of literal.matchAll(/import\s+(?:[\s\S]*?\s+from\s+)?["']([^"']+)["']\s*;/g)) {
      visit(match[1].startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), match[1])) : match[1]);
    }
  }
  for (const [key, selected] of Object.entries(selections)) {
    visit(selected.source);
    const full = output.contracts?.[selected.source]?.[selected.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing compiled ABI ${key}`);
    const abi = selected.full ? full : full.filter(row => (row.type === "function" && selected.methods.includes(row.name))
      || (row.type === "event" && selected.events.includes(row.name)));
    if (!selected.full) for (const [type, names] of [["function", selected.methods], ["event", selected.events]]) {
      if (names.some(name => abi.filter(row => row.type === type && row.name === name).length !== 1)) throw Error(`Incomplete or overloaded ABI ${key}`);
    }
    abis[key] = abi;
  }
  for (const path of oracleSources) { visit(path); sourceTexts[path] = input.sources[path].content; }
  return {
    schemaVersion: 1, capture: "parallel-feature-batch57-20260920", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 2248, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 2248 literal input sources independently verified byte-for-byte against this Git commit. Selected production closure hashes and original recipe texts follow.",
    qualification: "Frozen source and ABI evidence only; client tests do not establish actual publisher completion, actual Safe, gas, genesis or release acceptance. Preparation preserves the original payload and confers no source or writer authority.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-reference-mode-payload-fixture.mjs INPUT OUTPUT [--check]");
  const rendered = JSON.stringify(referenceModePayloadFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-reference-mode-payload-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale current Mode payload ABI fixture");
  } else await writeFile(target, rendered, "utf8");
}
