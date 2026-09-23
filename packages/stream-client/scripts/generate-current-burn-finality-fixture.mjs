// Extract read-only operator evidence from the retained compiler capture. Never compiles.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "832fd66f1a77a6b5e031d01559b45dd6cafc2a2864e5de0c060e5e31844cea5c";
const OUTPUT_SHA = "f56bfe433b6361ff42ad5d2c054a9f89ce2f622b4152eab9f2cb36ac96e1947e";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const selections = {
  gate: { source: "smart-contracts/domains/mint/StreamBurnMintGate.sol", contract: "StreamBurnMintGate",
    functions: ["core", "moduleRegistry", "coreCodeHash", "registryCodeHash", "program", "allowedSourceCollections"],
    events: ["BurnMintProgramConfigured"] },
  redemption: { source: "smart-contracts/domains/mint/StreamBurnRedemption.sol", contract: "StreamBurnRedemption",
    functions: ["core", "moduleRegistry", "coreCodeHash", "registryCodeHash", "program"],
    events: ["SaleConfigured", "RedemptionTermsRecorded"] },
  core: { source: "smart-contracts/core/StreamCore.sol", contract: "StreamCore",
    functions: ["collectionExists", "collectionSupplyMode", "collectionStatus", "collectionHasMaxSupply",
      "collectionMaxSupply", "collectionMintedEver", "collectionFreezeStatus", "collectionBurnsBlocked",
      "collectionBurnsBlockedAtBlock", "getSatellitePointer"], events: [] },
  finality: { source: "smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol", contract: "StreamArtworkFinalityRegistry",
    functions: ["core", "collectionFinalityRecord", "artworkScopeFinalityRecord", "artworkFreezeMode"], events: [] },
};
const reviewedSources = [
  ...Object.values(selections).map(selection => selection.source),
  "smart-contracts/interfaces/stream/mint/IStreamBurnMintGate.sol",
  "smart-contracts/interfaces/stream/mint/IStreamBurnRedemption.sol",
  "smart-contracts/interfaces/stream/core/IStreamCoreBurn.sol",
  "smart-contracts/interfaces/stream/core/IStreamCoreCollectionView.sol",
  "smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol",
  "smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol",
];

export function currentBurnFinalityFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen burn finality compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2098
    || output.errors?.some(error => error.severity === "error")) throw Error("Expected clean 2098-source ABI capture");
  const sources = Object.fromEntries(reviewedSources.sort().map(path => {
    const content = input.sources[path]?.content;
    if (typeof content !== "string") throw Error(`Missing literal source ${path}`);
    return [path, sha(content)];
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
  return { schemaVersion: 1, sourceCommit: "2e0fca1aef41a023d76a9717651a699bbd7db155",
    sourceTree: "919ec79e1558a5c0b521474e7958ceee49fd26be", sourceCount: 2098, compilerVersion: "0.8.19",
    inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    reviewedSourceEquivalence: "The ten selected source files are byte-identical at integration 5ae32cdff9a3498316581467d2c585966473ed0a.",
    qualification: "Exact read/event ABI and selected source evidence only; no current-stack execution, gas, Safe runtime, deployment or release acceptance.",
    sources, selections, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-burn-finality-fixture.mjs INPUT OUTPUT [--check]");
  const result = JSON.stringify(currentBurnFinalityFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-burn-finality-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== result) throw Error("Stale burn finality fixture");
  } else await writeFile(target, result, "utf8");
}
