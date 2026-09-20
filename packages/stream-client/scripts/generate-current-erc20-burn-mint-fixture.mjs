// Frozen compiler evidence only; this generator never compiles or submits calls.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "4ffe7f7f1b1d672c63f291518fa8d5682cc1f08959f12053f9d78f38aa52457b";
const OUTPUT_SHA = "314c9d970d0c4ddc834184e8a50bbc52736213c4e921ba8ae00023c6fd71c58a";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const selections = {
  sale: { source: "smart-contracts/domains/mint/StreamERC20BurnMintSale.sol", contract: "StreamERC20BurnMintSale" },
  gate: { source: "smart-contracts/domains/mint/StreamERC20BurnMintGate.sol", contract: "StreamERC20BurnMintGate" },
  payment: { source: "smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol", contract: "StreamERC20PrimarySettlementAdapter" },
  core: { source: "smart-contracts/core/StreamCore.sol", contract: "StreamCore",
    functions: ["collectionExists", "collectionSupplyMode", "collectionStatus", "collectionHasMaxSupply", "collectionMaxSupply",
      "collectionMintedEver", "collectionFreezeStatus", "collectionBurnsBlocked", "collectionBurnsBlockedAtBlock", "getSatellitePointer",
      "ownerOf", "getApproved", "isApprovedForAll", "tokenCollectionIdentity", "tokenLifecycle", "approve", "setApprovalForAll"],
    events: ["StreamTokenBurned", "Transfer", "Approval", "ApprovalForAll"] },
  manager: { source: "smart-contracts/domains/mint/StreamMintManager.sol", contract: "StreamMintManager",
    functions: ["core", "moduleRegistry", "mintLedger", "mintTicketAuthorizationId", "isAuthorizationUsed", "isNullifierUsed", "isOperationRootUsed",
      "nextOperationNonce", "phase", "phaseGate", "phaseExecutor", "phasePolicyHash"],
    events: ["MintAuthorizationConsumed", "MintAuthorizationVoided", "MintBatchExecuted", "MintTokenExecuted", "MintGateValidated"] },
  ledger: { source: "smart-contracts/domains/mint/StreamMintLedger.sol", contract: "StreamMintLedger",
    functions: ["isManagerAuthorizationUsed", "isManagerNullifierUsed", "isManagerOperationRootUsed"],
    events: ["MintLedgerAuthorizationConsumed", "MintLedgerAuthorizationVoided", "MintLedgerNullifierConsumed", "MintLedgerOperationRootConsumed"] },
  recorder: { source: "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol", contract: "StreamPrimarySaleSettlement",
    functions: ["settlementKey", "settlementResult", "settlementConsumed", "officialSettled", "core"],
    events: ["PrimaryRevenueExecutionBound", "PrimaryRevenueSettled", "PrimaryRevenueSettlementContext", "PrimaryRevenueSettlementPolicy"] },
  token: { source: "smart-contracts/interfaces/standards/IERC20.sol", contract: "IERC20",
    functions: ["allowance", "approve", "balanceOf"], events: ["Approval", "Transfer"] },
};

export function currentERC20BurnMintFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen ERC20 burn-mint compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2108
    || output.errors?.some(error => error.severity === "error")) throw Error("Expected clean 2108-source ABI capture");
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
  return { schemaVersion: 1, sourceCommit: "c717a3e10dca06950353c66c6493de41cdfcb9e1",
    sourceTree: "604224dd42310e747eb329c88e4eb76f1cfed1d5", featureCommit: "83c67868303679ba34480bd120cbc08bfd87a5fc",
    sourceCount: 2108, compilerVersion: "0.8.19", inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    qualification: "Source and compiled ABI evidence only; no joined current-stack, gas, Safe runtime, deployment or release acceptance.",
    sources, selections, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-erc20-burn-mint-fixture.mjs INPUT OUTPUT [--check]");
  const result = JSON.stringify(currentERC20BurnMintFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-erc20-burn-mint-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== result) throw Error("Stale ERC20 burn-mint fixture");
  } else await writeFile(target, result, "utf8");
}
