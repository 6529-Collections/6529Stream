// Exact source/encoding provenance for additive native refund-window prices.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const COMMIT = "90e68ebfc62e63eb46c6f23b23c32f3ccf2957a8";
const TREE = "1011eb3e1470dab54cf770904f0fb3ac749777fe";
const INPUT_SHA = "43a641fea018f20fe0119d4c4003a0c4b5dacc335b49eb13263c3e338a711a09";
const OUTPUT_SHA = "2c5d098727bcba813eb8215a78be8efc2faedd333628946691be3548d729210f";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const sourcePaths = [
  "smart-contracts/domains/mint/StreamNativeRefundWindowSale.sol",
  "smart-contracts/domains/mint/StreamNativeRefundWindowWorker.sol",
  "smart-contracts/domains/mint/StreamRefundWindowSupport.sol",
  "smart-contracts/domains/mint/StreamRefundWindowBookStore.sol",
  "smart-contracts/domains/mint/StreamRefundWindowBook.sol",
  "smart-contracts/domains/mint/StreamRefundWindowPriceStore.sol",
  "smart-contracts/domains/mint/StreamRefundClock.sol",
  "smart-contracts/domains/mint/StreamRefundUnlock.sol",
  "smart-contracts/domains/mint/StreamMintSaleAllowlist.sol",
  "smart-contracts/domains/mint/StreamMintCounterPolicy.sol",
  "smart-contracts/interfaces/stream/mint/IStreamNativeRefundWindowSale.sol",
  "smart-contracts/interfaces/stream/mint/IStreamNativeAllowlistRefundWindowSale.sol",
  "smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol",
  "smart-contracts/interfaces/stream/revenue/StreamNativeSettlementTypes.sol",
];
const selections = {
  refund: {
    source: sourcePaths[0],
    contract: "StreamNativeRefundWindowSale",
    methods: [
      "registerAllowlistRefundSale", "purchaseAllowlistRefundWindow", "allowlistRefundSalePolicy",
      "refundSaleRecord", "refundPurchaseAuthorizationDigest", "nextSaleNonce", "nextPurchaseNonce",
      "refundableBalance", "finalizeRefundWindow", "refundPurchase", "unlockRefund", "synchronizePurchaseWindow",
      "claimRefund", "purchaseDeadlines", "owner", "core", "mintManager", "entropyCoordinator",
      "refundPurchaseRecord", "refundPurchasePriceFacts", "refundPurchaseResolverData",
    ],
  },
  entropy: {
    source: "smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol",
    contract: "IStreamRevealFeeEscrow",
    methods: ["collectionRevealPolicy"],
  },
};

export function currentNativeRefundPriceFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) {
    throw Error("Compiler capture differs from the reviewed native refund price capture");
  }
  const input = JSON.parse(inputBytes);
  const output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 291
    || output.errors?.some(error => error.severity === "error")) {
    throw Error("Expected the clean 291-source native refund ABI capture");
  }
  const sources = {};
  for (const path of sourcePaths) {
    const source = input.sources?.[path]?.content;
    if (typeof source !== "string") throw Error(`Missing source ${path}`);
    sources[path] = sha(source);
  }
  const abis = {};
  for (const [key, selection] of Object.entries(selections)) {
    const full = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing compiler target ${selection.contract}`);
    const selected = full.filter(item => item.type === "function" && selection.methods.includes(item.name));
    if (selected.length !== selection.methods.length
      || selection.methods.some(name => !selected.some(item => item.name === name))) {
      throw Error(`Incomplete selected ABI for ${selection.contract}`);
    }
    abis[key] = selected;
  }
  return {
    schemaVersion: 1,
    sourceCommit: COMMIT,
    sourceTree: TREE,
    sourceCount: 291,
    compilerVersion: "0.8.19",
    sourceNormalization: "UTF-8 CRLF to LF",
    qualification: "Selected ABI and source encoding evidence only; no native-runtime, live eligibility, historical provenance, Safe or release acceptance claim.",
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sources,
    selections,
    abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) {
    throw Error("Usage: generate-current-native-refund-price-fixture.mjs INPUT OUTPUT [--check]");
  }
  const fixture = currentNativeRefundPriceFixture(await readFile(input), await readFile(output));
  const rendered = JSON.stringify(fixture, null, 2) + "\n";
  const target = new URL("../test/fixtures/current-native-refund-price-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale native refund price ABI fixture");
  } else {
    await writeFile(target, rendered, "utf8");
  }
}
