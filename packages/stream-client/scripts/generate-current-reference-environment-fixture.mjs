// Project the exact retained environment-preparation ABI capture; never compile Solidity.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "d8c2ec0ad23d30802f2f5d36a63c20a608a370449e449b281daeccb8f27a149f";
const OUTPUT_SHA = "57a037664968f7d7f0ac96c7583732bff23d6f37edc550a5361327417c6c8f9b";
const SOURCE_COMMIT = "dfe75d52a2baa3fc394b0a94140565cd3ce850f4";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const methods = ["prepareEnvironment", "prepareFileInventory", "prepareFileInventoryPart", "prepareFileInventoryFromParts",
  "preparedFileInventory", "deploymentChainId", "dependencies", "supportsInterface"];
const events = ["ReferenceEnvironmentPrepared", "ReferenceInventoryPartPrepared", "ReferenceInventoryAssembled"];
const selections = {
  host: { source: "smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol", contract: "StreamReferenceRenderPublication", methods, events },
  modeHost: { source: "smart-contracts/domains/preservation/StreamReferenceModePublication.sol", contract: "StreamReferenceModePublication", methods, events },
  companion: { source: "smart-contracts/interfaces/stream/preservation/IStreamReferenceEnvironmentPreparation.sol", contract: "IStreamReferenceEnvironmentPreparation", full: true },
  environmentJson: { source: "smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol", contract: "StreamReferenceEnvironmentJson", full: true },
  store: { source: "smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol", contract: "StreamSchemaDocumentStore",
    methods: ["MAX_CHUNK_BYTES", "chunk", "publishChunk"], events: ["ChunkPublished"] },
};

export function referenceEnvironmentFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen environment-preparation compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 127
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 127-source capture");
  const sources = Object.fromEntries(Object.entries(input.sources).sort(([a], [b]) => a.localeCompare(b)).map(([path, source]) => {
    if (typeof source.content !== "string") throw Error(`Missing literal source ${path}`);
    return [path, sha(source.content)];
  }));
  const abis = {};
  for (const [key, selection] of Object.entries(selections)) {
    const full = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing ABI ${key}`);
    const abi = selection.full ? full : full.filter(row => (row.type === "function" && selection.methods.includes(row.name))
      || (row.type === "event" && selection.events.includes(row.name)));
    if (!selection.full) {
      for (const [type, names] of [["function", selection.methods], ["event", selection.events]]) {
        if (names.some(name => abi.filter(row => row.type === type && row.name === name).length !== 1)) throw Error(`Incomplete ABI ${key}`);
      }
      if (abi.length !== selection.methods.length + selection.events.length) throw Error(`Unexpected ABI ${key}`);
    }
    abis[key] = abi;
  }
  return { schemaVersion: 1, capture: "reference-modes-abi40", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 127, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 127 literal input sources independently verified byte-for-byte against this Git commit.",
    qualification: "Frozen source and ABI evidence only; no whole publisher, actual Safe, complete gas-envelope, genesis or release acceptance.",
    sources, selections, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-reference-environment-fixture.mjs INPUT OUTPUT [--check]");
  const canonical = JSON.stringify(referenceEnvironmentFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-reference-environment-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== canonical) throw Error("Stale environment-preparation ABI fixture");
  } else await writeFile(target, canonical, "utf8");
}
