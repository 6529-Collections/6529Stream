// Frozen carrier ABI provenance, separate from Manager/Ledger revocation provenance.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const COMMIT = "5605d019bc9cb933398f626df77b84d1cd2a51ba";
const TREE = "0b12c46b997a6682cd48e2d8d7049d55ff6d755d";
const INPUT_SHA = "d1db6188f922acc490973cae67fbfecdd4fcfb31df18b909901acb57bb6a8101";
const OUTPUT_SHA = "a2783ea8778a84012c7c9b96d9983b434fdb75e6ceade1dbbe2bf8a26aa14ca7";
const sha = value => createHash("sha256").update(value).digest("hex");
const shared = ["owner", "nextSaleNonce", "saleIdFor", "saleRecord", "nextPurchaseNonce", "purchaseIdFor",
  "saleRevealQuote", "executionRecord", "refundableBalance", "claimRefund", "claimRefundFor", "cancelSale",
  "syncCollectionContest", "core", "mintManager", "revenueResolver", "artistRegistry", "moduleRegistry"];
const selections = {
  fixed: {
    source: "smart-contracts/domains/mint/StreamNativeCuratedFixedPriceSale.sol",
    contract: "StreamNativeCuratedFixedPriceSale",
    methods: [...shared, "fixedConfigurationHash", "registerCuratedFixedSale", "fixedSaleConfiguration",
      "purchaseSelectedContent", "commitSelection", "revealSelection", "selectionCommitment", "selectionDeposit",
      "selectionWindows", "unlockSelectionRefund", "unlockSelectionRefundForReason", "selectionRefundCredit",
      "claimSelectionRefund", "claimSelectionRefundDelegated", "selectionLiabilities"],
  },
  private: {
    source: "smart-contracts/domains/mint/StreamNativeCuratedPrivateSale.sol",
    contract: "StreamNativeCuratedPrivateSale",
    methods: [...shared, "configureCollectionSigner", "collectionSigner", "privateConfigurationHash",
      "registerCuratedPrivateSale", "privateSaleConfiguration", "purchasePrivateContent",
      "curatedSaleAuthorizationBinding", "eip712Domain", "expirePrivateSale"],
  },
  gate: {
    source: "smart-contracts/domains/mint/StreamNativeCuratedContentGate.sol",
    contract: "StreamNativeCuratedContentGate",
    methods: ["publication", "manifestBytes", "itemCount", "gateConfigHash", "managerCodeHash", "houseCodeHash", "contentPurchaseVersion"],
  },
};

export function currentCuratedFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact final curated carrier compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 128
    || output.errors?.some(error => error.severity === "error")) throw Error("Expected clean 128-source carrier capture");
  const sources = Object.fromEntries(Object.entries(input.sources).sort(([a], [b]) => a.localeCompare(b)).map(([path, value]) => {
    if (typeof value.content !== "string") throw Error(`Missing literal source ${path}`);
    return [path, sha(value.content)];
  }));
  const abis = {};
  for (const [key, selection] of Object.entries(selections)) {
    const full = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing selected product ${selection.contract}`);
    const selected = full.filter(item => item.type === "function" && selection.methods.includes(item.name));
    if (selected.length !== selection.methods.length || selection.methods.some(name => !selected.some(item => item.name === name))) throw Error(`Incomplete ABI ${key}`);
    abis[key] = selected;
  }
  return { schemaVersion: 1, sourceCommit: COMMIT, sourceTree: TREE,
    carrierCommit: "187a55af7dfe6bf65d51121c82452bf70d5da8ad", sourceCount: 128, compilerVersion: "0.8.19",
    sourceNormalization: "UTF-8 CRLF to LF", inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    qualification: "Source and selected compiled ABI evidence only; no deployment, complete current-stack, Safe or historical admission claim.",
    sources, selections, abis };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-curated-fixture.mjs INPUT OUTPUT [--check]");
  const result = JSON.stringify(currentCuratedFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-curated-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== result) throw Error("Stale curated carrier fixture");
  } else await writeFile(target, result, "utf8");
}
