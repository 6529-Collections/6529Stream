// Source/encoding provenance for the accepted Dutch and clearing allowlist callers.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const COMMIT = "2dc3ea7ee35d4e5d698a2245bed54fcb03665819";
const TREE = "f5cb1a0abd375bbaa087df409775150a884d3767";
const INPUT_SHA = "996210da666b0f63930cf10f20ac61c4397bc2451b8931e1690c6432d4811ae6";
const OUTPUT_SHA = "ad0f34dc0c3ee118d6d5fc117263902d5294f9933b90aef46508ab40ba65cf06";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");

const sourcePaths = [
  "smart-contracts/domains/mint/StreamNativeDutchSale.sol",
  "smart-contracts/domains/mint/StreamNativeDutchSaleWorker.sol",
  "smart-contracts/domains/mint/StreamDutchSaleSupport.sol",
  "smart-contracts/domains/mint/StreamDutchPricing.sol",
  "smart-contracts/domains/mint/StreamNativeClearingSale.sol",
  "smart-contracts/domains/mint/StreamClearingSaleRegistration.sol",
  "smart-contracts/domains/mint/StreamClearingSaleExecution.sol",
  "smart-contracts/domains/mint/StreamClearingSaleSupport.sol",
  "smart-contracts/domains/mint/StreamClearingSaleBook.sol",
  "smart-contracts/domains/mint/StreamMintSaleAllowlist.sol",
  "smart-contracts/domains/mint/StreamMintCounterPolicy.sol",
  "smart-contracts/interfaces/stream/mint/IStreamNativeDutchSale.sol",
  "smart-contracts/interfaces/stream/mint/IStreamNativeAllowlistDutchSale.sol",
  "smart-contracts/interfaces/stream/mint/IStreamNativeClearingSale.sol",
  "smart-contracts/interfaces/stream/mint/IStreamNativeAllowlistClearingSale.sol",
  "smart-contracts/interfaces/stream/mint/IStreamDutchPriceSchedule.sol",
  "smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol",
];
const selections = {
  dutch: {
    source: "smart-contracts/domains/mint/StreamNativeDutchSale.sol",
    contract: "StreamNativeDutchSale",
    methods: [
      "registerAllowlistDutchSale", "allowlistPriceCounter", "purchaseWithAllowlist",
      "saleIdFor", "saleRecord", "currentPrice", "authorizationDigest", "nextSaleNonce",
      "owner", "core", "mintManager", "entropyCoordinator", "paused", "refundableBalance", "claimRefund",
    ],
  },
  clearing: {
    source: "smart-contracts/domains/mint/StreamNativeClearingSale.sol",
    contract: "StreamNativeClearingSale",
    methods: [
      "registerAllowlistClearingSale", "allowlistPriceCounter", "owner", "nextSaleNonce",
      "saleIdFor", "saleRecord", "currentPrice", "nextPurchaseNonce", "authorizationDigest",
      "eip712Domain", "purchaseWithAllowlist", "refundableBalance", "claimRefund", "financialSale",
      "saleDeadlines", "fixClearingPrice", "settlePurchaseSupplement", "synchronizeRebate", "entropyCoordinator",
    ],
  },
  entropy: {
    source: "smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol",
    contract: "IStreamRevealFeeEscrow",
    methods: ["collectionRevealPolicy"],
  },
};

export function currentNativeMovingPriceFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) {
    throw Error("Compiler capture differs from the reviewed moving-price capture");
  }
  const input = JSON.parse(inputBytes);
  const output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 290
    || output.errors?.some(error => error.severity === "error")) {
    throw Error("Expected the clean 290-source Dutch and clearing ABI capture");
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
    sourceCount: 290,
    compilerVersion: "0.8.19",
    sourceNormalization: "UTF-8 CRLF to LF",
    qualification: "Selected ABI and source encoding evidence only; no moving-price runtime, live eligibility, signature, payment, Safe or release acceptance claim.",
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
    throw Error("Usage: generate-current-native-moving-price-fixture.mjs INPUT OUTPUT [--check]");
  }
  const fixture = currentNativeMovingPriceFixture(await readFile(input), await readFile(output));
  const rendered = JSON.stringify(fixture, null, 2) + "\n";
  const target = new URL("../test/fixtures/current-native-moving-price-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale native moving-price ABI fixture");
  } else {
    await writeFile(target, rendered, "utf8");
  }
}
