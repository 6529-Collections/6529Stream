// Project an exact retained compiler capture; this script never compiles Solidity.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "9a351a3b51b235a17d766ddaabc6d985fff8b34482d5f7ff92d6837220b6c631";
const OUTPUT_SHA = "5d3138f0dfc73f346c9263de451c853a4db3067625cd6d7ac5a226857c00a96d";
const SOURCE_COMMIT = "e6a1704005f6a1197903eac372a166383a910681";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const errors = ["InvalidInventoryConfiguration", "InventoryBatchSize", "InventoryCollectionUnknown",
  "InventoryCoreChanged", "InventoryCoreReadFailed", "InventoryIncomplete", "InventoryIndexOutOfBounds",
  "InventoryTokenMismatch"];
const legacyMethods = ["appendCollectionTokens", "collectionInventoryState", "collectionTokenAt", "core", "requireCompleteCollection"];
const selections = {
  inventory: { source: "smart-contracts/domains/finality/StreamCollectionTokenInventory.sol", contract: "StreamCollectionTokenInventory",
    methods: [...legacyMethods, "scanCollectionTokens", "collectionScanThrough", "collectionTokenBySerial",
      "coreCodeHash", "deploymentChainId", "MAX_INDEX_BATCH", "INVENTORY_DOMAIN", "APPEND_DOMAIN", "supportsInterface"],
    events: ["CollectionTokenIndexed"], errors: [...errors, "InventoryScanPrepared"] },
  core: { source: "smart-contracts/core/StreamCore.sol", contract: "StreamCore",
    methods: ["collectionExists", "collectionMintedEver", "lastAllocatedTokenId", "tokenCollectionIdentity", "tokenLifecycle"], events: [], errors: [] },
  legacy: { source: "smart-contracts/interfaces/stream/finality/IStreamCollectionTokenInventory.sol", contract: "IStreamCollectionTokenInventory",
    methods: legacyMethods, events: ["CollectionTokenIndexed"], errors },
  serialLookup: { source: "smart-contracts/interfaces/stream/finality/IStreamCollectionTokenInventorySerialLookup.sol", contract: "IStreamCollectionTokenInventorySerialLookup",
    methods: ["collectionTokenBySerial"], events: [], errors: [] },
};

export function collectionInventoryFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact collection inventory compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 62
    || output.errors?.some(error => error.severity === "error")) throw Error("Expected clean 62-source capture");
  const sources = Object.fromEntries(Object.entries(input.sources).sort(([a], [b]) => a.localeCompare(b)).map(([path, source]) => {
    if (typeof source.content !== "string") throw Error(`Missing literal source ${path}`);
    return [path, sha(source.content)];
  }));
  const abis = {};
  for (const [key, selected] of Object.entries(selections)) {
    const full = output.contracts?.[selected.source]?.[selected.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing compiler product ${selected.contract}`);
    const abi = full.filter(item => (item.type === "function" && selected.methods.includes(item.name))
      || (item.type === "event" && selected.events.includes(item.name))
      || (item.type === "error" && selected.errors.includes(item.name)));
    for (const [kind, names] of [["function", selected.methods], ["event", selected.events], ["error", selected.errors]]) {
      if (names.some(name => abi.filter(item => item.type === kind && item.name === name).length !== 1)) throw Error(`Incomplete ABI ${key}`);
    }
    if (abi.length !== selected.methods.length + selected.events.length + selected.errors.length) throw Error(`Unexpected ABI ${key}`);
    abis[key] = abi;
  }
  return { schemaVersion: 1, capture: "capture-erc20-burn-final-v2-StreamCollectionTokenInventory.t", compilerVersion: "0.8.19",
    sourceCommit: SOURCE_COMMIT, sourceCount: 62, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 62 literal input sources independently verified byte-for-byte against this Git commit.",
    qualification: "Frozen ABI and source evidence; client fixtures do not establish real RPC, Safe execution, downstream consumer compatibility, gas or release acceptance.",
    sources, selections, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-collection-inventory-fixture.mjs INPUT OUTPUT [--check]");
  const canonical = JSON.stringify(collectionInventoryFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-collection-inventory-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== canonical) throw Error("Stale collection inventory ABI fixture");
  } else await writeFile(target, canonical, "utf8");
}
