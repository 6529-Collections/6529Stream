// Extract the bounded burn-to-mint caller ABI from the exact 9310d6e9 capture.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const SOURCE_COMMIT = "9310d6e9865db8ffe83fb53c78801ff4151158e3";
const SOURCE_TREE = "ac8bde02e1ee6e88d0dac7887610a6c3eb9c1ea2";
const REVIEWED_INPUT_SHA256 = "53a0fb51bba21ce5a96a6fe19431a9b910dcf45fd689e93b091b383412002d6d";
const REVIEWED_OUTPUT_SHA256 = "b129483dc970d397415586ddfe3a41efcb2958a08a47944a2e169e0e6e77b3fe";
const REVIEWED_BINDING_SHA256 = "3a2f4ce2cd99233f89f367d950963fc7bfd4c9a906a9885b0fa82a6b84eab1d7";
const sha = value => createHash("sha256").update(value).digest("hex");

const selections = [
  ["gate", "smart-contracts/domains/mint/StreamBurnMintGate.sol", "StreamBurnMintGate",
    ["allowedSourceCollections", "burnAndMint", "burnNullifier", "claimRefund", "configureProgram", "core", "coreCodeHash",
      "moduleRegistry", "nativeSaleCreditPage", "nativeSaleCreditState", "owner", "program", "programConfigHash",
      "refundableBalance", "registryCodeHash", "saleRevealQuote"]],
  ["core", "smart-contracts/core/StreamCore.sol", "StreamCore",
    ["collectionExists", "getApproved", "getSatellitePointer", "isApprovedForAll", "ownerOf", "tokenCollectionIdentity"]],
  ["manager", "smart-contracts/domains/mint/StreamMintManager.sol", "StreamMintManager",
    ["core", "isNullifierUsed", "moduleRegistry", "phaseGate"]],
  ["nativeSale", "smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol", "StreamNativeFixedPriceSaleAdapter",
    ["authorizationDigest", "core", "mintManager", "moduleRegistry", "purchaseWithBurn", "saleRecord"]],
];
const sourcePaths = [
  "smart-contracts/domains/mint/StreamBurnMintGate.sol",
  "smart-contracts/domains/mint/StreamBurnMintCredits.sol",
  "smart-contracts/interfaces/stream/mint/IStreamBurnMintGate.sol",
  "smart-contracts/interfaces/stream/mint/IStreamBurnMintNativeSale.sol",
  "smart-contracts/interfaces/stream/mint/IStreamImmediateSaleReveal.sol",
  "smart-contracts/interfaces/stream/mint/IStreamNativeSaleCredits.sol",
  "smart-contracts/domains/mint/StreamNativeBurnCallback.sol",
  "smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol",
  "smart-contracts/domains/mint/StreamMintManager.sol",
  "smart-contracts/core/StreamCore.sol",
];

export function currentBurnMintFixture(inputBytes, outputBytes, bindingBytes) {
  const inputSha256 = sha(inputBytes), outputSha256 = sha(outputBytes), bindingSha256 = sha(bindingBytes);
  if (inputSha256 !== REVIEWED_INPUT_SHA256 || outputSha256 !== REVIEWED_OUTPUT_SHA256 || bindingSha256 !== REVIEWED_BINDING_SHA256) {
    throw Error("Compiler capture differs from the reviewed canonical burn-to-mint capture");
  }
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), binding = JSON.parse(bindingBytes);
  if (binding.builderCommit !== SOURCE_COMMIT || binding.inputSha256 !== inputSha256 || binding.outputSha256 !== outputSha256
    || binding.sourceCount !== 999 || binding.compilerErrorCount !== 0 || !Array.isArray(binding.mismatches) || binding.mismatches.length !== 0
    || input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 999
    || output.errors?.some(item => item.severity === "error")) throw Error("Invalid bound burn-to-mint compiler evidence");
  const sources = {};
  for (const path of sourcePaths) {
    const source = input.sources?.[path]?.content;
    if (typeof source !== "string") throw Error(`Missing burn-to-mint source ${path}`);
    const bindingRow = binding.sources.find(row => row.path === path);
    if (!bindingRow?.matchesCommit || bindingRow.compilerSourceSha256 !== sha(source)) throw Error(`Source binding differs for ${path}`);
    sources[path] = sha(source);
  }
  const abis = {};
  for (const [name, path, contract, methods] of selections) {
    const full = output.contracts?.[path]?.[contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing compiler target ${path}::${contract}`);
    const selected = full.filter(item => item.type === "function" && methods.includes(item.name));
    if (selected.length !== methods.length || methods.some(method => !selected.some(item => item.name === method))) {
      throw Error(`Incomplete selected burn-to-mint ABI ${contract}`);
    }
    abis[name] = selected;
  }
  return { schemaVersion: 1, sourceCommit: SOURCE_COMMIT, sourceTree: SOURCE_TREE,
    qualification: "Exact compiler-selected burn-to-mint ABI/source binding; no scoped native runtime, live approval, signature acceptance, send, deployment, audit or release claim.",
    compilerVersion: "0.8.19", sourceCount: 999, inputSha256, outputSha256, bindingSha256, sources, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, binding, mode] = process.argv.slice(2);
  if (!input || !output || !binding || (mode !== undefined && mode !== "--check")) {
    throw Error("Usage: node scripts/generate-current-burn-mint-fixture.mjs INPUT OUTPUT SOURCE_BINDING [--check]");
  }
  const file = new URL("../test/fixtures/current-burn-mint-abi.json", import.meta.url);
  const rendered = JSON.stringify(currentBurnMintFixture(await readFile(input), await readFile(output), await readFile(binding)), null, 2) + "\n";
  if (mode === "--check") {
    if (await readFile(file, "utf8") !== rendered) throw Error("Stale current burn-to-mint fixture");
  } else await writeFile(file, rendered, "utf8");
  console.log("Verified exact compiler-selected current burn-to-mint fixture; scoped native runtime remains separate.");
}
