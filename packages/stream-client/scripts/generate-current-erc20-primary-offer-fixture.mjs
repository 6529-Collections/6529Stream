// Frozen compiler evidence only; this generator never compiles or submits calls.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const COMMIT = "2e0fca1aef41a023d76a9717651a699bbd7db155";
const TREE = "919ec79e1558a5c0b521474e7958ceee49fd26be";
const INPUT_SHA = "832fd66f1a77a6b5e031d01559b45dd6cafc2a2864e5de0c060e5e31844cea5c";
const OUTPUT_SHA = "f56bfe433b6361ff42ad5d2c054a9f89ce2f622b4152eab9f2cb36ac96e1947e";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const selections = {
  sale: { source: "smart-contracts/domains/mint/StreamERC20PrimaryOfferSale.sol", contract: "StreamERC20PrimaryOfferSale" },
  payment: { source: "smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol", contract: "StreamERC20PrimarySettlementAdapter" },
  gate: { source: "smart-contracts/domains/mint/StreamERC20OfferGate.sol", contract: "StreamERC20OfferGate" },
  manager: { source: "smart-contracts/domains/mint/StreamMintManager.sol", contract: "StreamMintManager",
    functions: ["core", "mintLedger", "mintOfferAuthorizationId", "voidMintOffer", "isAuthorizationUsed",
      "nextOperationNonce", "phase", "phaseGate", "phaseExecutor", "phasePolicyHash", "previewERC20OfferMintOperation"],
    events: ["MintAuthorizationConsumed", "MintAuthorizationVoided", "MintBatchExecuted", "MintTokenExecuted"] },
  ledger: { source: "smart-contracts/domains/mint/StreamMintLedger.sol", contract: "StreamMintLedger",
    functions: ["isManagerAuthorizationUsed"], events: ["MintLedgerAuthorizationConsumed", "MintLedgerAuthorizationVoided"] },
  recorder: { source: "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol", contract: "StreamPrimarySaleSettlement",
    functions: ["settlementKey", "settlementResult", "settlementConsumed", "officialSettled", "core"],
    events: ["PrimaryRevenueExecutionBound", "PrimaryRevenueSettled", "PrimaryRevenueSettlementContext", "PrimaryRevenueSettlementPolicy"] },
  token: { source: "smart-contracts/interfaces/standards/IERC20.sol", contract: "IERC20",
    functions: ["allowance", "approve", "balanceOf"], events: ["Approval", "Transfer"] },
};

export function currentERC20PrimaryOfferFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen ERC20 primary offer compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2098
    || output.errors?.some(error => error.severity === "error")) throw Error("Expected clean 2098-source ABI capture");
  const sources = Object.fromEntries(Object.entries(input.sources).sort(([a], [b]) => a.localeCompare(b)).map(([path, value]) => {
    if (typeof value.content !== "string") throw Error(`Missing literal source ${path}`);
    return [path, sha(value.content)];
  }));
  const abis = {};
  for (const [key, selection] of Object.entries(selections)) {
    const full = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing selected product ${selection.contract}`);
    const selected = full.filter(item => (item.type === "function" && (!selection.functions || selection.functions.includes(item.name)))
      || (item.type === "event" && (!selection.events || selection.events.includes(item.name))));
    if (selection.functions && (selected.length !== selection.functions.length + selection.events.length
      || selection.functions.some(name => !selected.some(item => item.type === "function" && item.name === name))
      || selection.events.some(name => !selected.some(item => item.type === "event" && item.name === name)))) throw Error(`Incomplete ABI ${key}`);
    abis[key] = selected;
  }
  return { schemaVersion: 1, sourceCommit: COMMIT, sourceTree: TREE,
    carrierCommit: "94eaedc3ddd17aa6866b00b668e5e511a2151c5d", sharedCommit: "1d4e7236d2f6712697d24f1dc60974d938a00c87",
    sourceCount: 2098, compilerVersion: "0.8.19", inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceNormalization: "Hashes preserve literal compiler inputs; Git comparison normalizes CRLF to LF only where recorded.",
    lineEndingOnlySourceDifferences: ["smart-contracts/interfaces/stream/entropy/IStreamEntropyFinalityPolicy.sol"],
    qualification: "Source and compiled ABI evidence only; no current-stack, gas, Safe runtime, deployment or release acceptance.",
    sources, selections, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-erc20-primary-offer-fixture.mjs INPUT OUTPUT [--check]");
  const result = JSON.stringify(currentERC20PrimaryOfferFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-erc20-primary-offer-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== result) throw Error("Stale ERC20 primary offer fixture");
  } else await writeFile(target, result, "utf8");
}
