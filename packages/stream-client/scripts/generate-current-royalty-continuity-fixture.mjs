// Extract a pending royalty-continuity caller fixture from an explicitly selected successful build.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const SOURCE_COMMIT = "49364823b9e537a33896346b67639e523b4f31d1";
const REVIEWED_INPUT_SHA256 = "dc2a6fb013e6ca5a98148032ec0ee60d87902a580d8e68d683e4e4af13400b6b";
const REVIEWED_OUTPUT_SHA256 = "b07f3db4656c8781935470f2dfa662c24c1254936f08a6aa2166f47825d495b3";
const sha = value => createHash("sha256").update(value).digest("hex");
const resolverMethods = new Set([
  "MAX_ROYALTY_BPS", "beginEconomicContinuity", "boundCore", "boundCoreCodeHash",
  "completeEconomicContinuity", "continuityHeader", "continuityManifestHash", "continuitySource",
  "economicContinuityReady", "economicContinuityState", "economicElectionAt", "governanceAuthority",
  "importEconomicContinuity", "owner", "previewEconomicContinuity", "protectedEconomicRouteAt",
  "splitFactory", "supportsEconomicContinuity", "supportsInterface",
]);

export function royaltyContinuityFixture(inputBytes, outputBytes) {
  const inputSha256 = sha(inputBytes), outputSha256 = sha(outputBytes);
  if (inputSha256 !== REVIEWED_INPUT_SHA256 || outputSha256 !== REVIEWED_OUTPUT_SHA256) {
    throw Error("Compiler capture differs from the reviewed canonical royalty continuity ABI capture");
  }
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || output.errors?.some(x => x.severity === "error")) throw Error("Expected successful Solidity standard JSON");
  const resolverPath = "smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
  const corePath = "smart-contracts/core/StreamCore.sol";
  const sources = {}, abis = {};
  for (const [name, path, contract, select] of [
    ["resolver", resolverPath, "StreamRoyaltyResolver", x => x.type === "function" && resolverMethods.has(x.name)],
    ["core", corePath, "StreamCore", x => x.type === "function" && x.name === "getSatellitePointer"],
  ]) {
    const source = input.sources?.[path]?.content, abi = output.contracts?.[path]?.[contract]?.abi;
    if (typeof source !== "string" || !Array.isArray(abi)) throw Error(`Missing compiler target ${name}`);
    sources[path] = sha(source); abis[name] = abi.filter(select);
  }
  if (abis.resolver.length !== resolverMethods.size || abis.core.length !== 1) throw Error("Selected ABI is incomplete or overloaded");
  for (const path of [
    "smart-contracts/interfaces/stream/revenue/IStreamRoyaltyEconomicContinuity.sol",
    "smart-contracts/domains/revenue/StreamRoyaltyContinuityState.sol",
    "smart-contracts/domains/revenue/StreamRoyaltyContinuityImport.sol",
    "smart-contracts/domains/revenue/StreamRoyaltyContinuityParameters.sol",
  ]) {
    const source = input.sources?.[path]?.content;
    if (typeof source !== "string") throw Error(`Missing continuity source ${path}`);
    sources[path] = sha(source);
  }
  return { schemaVersion: 1, sourceCommit: SOURCE_COMMIT,
    qualification: "Pending compiler-selected caller fixture only; no deployment, Core-cutover, native-runtime, audit or release claim.",
    inputSha256, outputSha256, sources, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: node scripts/generate-current-royalty-continuity-fixture.mjs INPUT OUTPUT [--check]");
  const file = new URL("../test/fixtures/current-royalty-continuity-abi.json", import.meta.url);
  const text = JSON.stringify(royaltyContinuityFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  if (mode === "--check") {
    if (await readFile(file, "utf8") !== text) throw Error("Stale royalty continuity fixture");
  } else await writeFile(file, text, "utf8");
  console.log("Verified compiler-selected royalty continuity fixture; retained catalogs untouched.");
}
