// Reproduce selected interfaces from the owner's frozen compiler capture; never compile.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "5e9a2397a95a837f6466057a065165693c0c9c192f42452246136e2c60b348dc";
const OUTPUT_SHA = "3b98544016dc3542d759d2da83f4d8cce8e73610a9a75af7fd1774689d3b6f2b";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const methods = ["prepareFileInventory", "prepareFileInventoryPart", "prepareFileInventoryFromParts",
  "preparedFileInventory", "deploymentChainId", "dependencies", "supportsInterface"];
const events = ["ReferenceInventoryPartPrepared", "ReferenceInventoryAssembled"];
const selections = {
  host: { source: "smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol", contract: "StreamReferenceRenderPublication", methods, events },
  modeHost: { source: "smart-contracts/domains/preservation/StreamReferenceModePublication.sol", contract: "StreamReferenceModePublication", methods, events },
  companion: { source: "smart-contracts/interfaces/stream/preservation/IStreamReferenceInventoryPreparation.sol", contract: "IStreamReferenceInventoryPreparation",
    methods: ["prepareFileInventoryPart", "prepareFileInventoryFromParts", "supportsInterface"], events },
  store: { source: "smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol", contract: "StreamSchemaDocumentStore",
    methods: ["MAX_CHUNK_BYTES", "chunk", "publishChunk"], events: ["ChunkPublished"] },
};

export function referenceInventoryFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact staged inventory compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 125
    || output.errors?.some(error => error.severity === "error")) throw Error("Expected clean 125-source capture");
  const sources = Object.fromEntries(Object.entries(input.sources).sort(([a], [b]) => a.localeCompare(b)).map(([path, source]) => {
    if (typeof source.content !== "string") throw Error(`Missing literal source ${path}`);
    return [path, sha(source.content)];
  }));
  const abis = {};
  for (const [key, selected] of Object.entries(selections)) {
    const full = output.contracts?.[selected.source]?.[selected.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing compiler product ${selected.contract}`);
    const abi = full.filter(item => (item.type === "function" && selected.methods.includes(item.name))
      || (item.type === "event" && selected.events.includes(item.name)));
    if (abi.length !== selected.methods.length + selected.events.length
      || selected.methods.some(name => !abi.some(item => item.type === "function" && item.name === name))
      || selected.events.some(name => !abi.some(item => item.type === "event" && item.name === name))) throw Error(`Incomplete ABI ${key}`);
    abis[key] = abi;
  }
  return { schemaVersion: 1, capture: "reference-modes-abi32", compilerVersion: "0.8.19", sourceCount: 125,
    inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    qualification: "Frozen literal compiler-input and ABI evidence; no joined runtime, real Safe execution, gas-cap or release acceptance.",
    sources, selections, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-reference-inventory-fixture.mjs INPUT OUTPUT [--check]");
  const canonical = JSON.stringify(referenceInventoryFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-reference-inventory-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== canonical) throw Error("Stale staged reference inventory ABI fixture");
  } else await writeFile(target, canonical, "utf8");
}
