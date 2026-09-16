// Exact frozen ABI capture; this does not compile contracts or establish runtime acceptance.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const COMMIT = "cf268d24bd0098c90ece4cd2b9d306802d9c1b62";
const TREE = "ca5b8a92015e661cb028202ddcc86028b90adfca";
const INPUT_SHA = "58ae3150ca16a6ec0f012846a7d98343b1ddd8b1ebcd57c7573945fed03b7893";
const OUTPUT_SHA = "f0a922c7f8fad812b021876a4667fb8b84e05fcd4d697ff499adb7901d364c7d";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const selections = {
  sale: {
    source: "smart-contracts/domains/mint/StreamNativePrimaryOfferSale.sol", contract: "StreamNativePrimaryOfferSale",
    methods: ["configureCollectionSigner", "collectionSigner", "owner", "nextSaleNonce", "saleIdFor",
      "primaryOfferConfigurationHash", "registerPrimaryOffer", "primaryOfferConfiguration", "saleRecord",
      "nextPurchaseNonce", "purchaseIdFor", "authorizationDigest", "offerDigest", "digestConsumed", "digestRevoked",
      "saleRevealQuote", "primaryOfferAuthorizationBinding", "acceptPrimaryOffer", "executionRecord",
      "refundableBalance", "refundLiability", "claimRefund", "claimRefundFor", "revokeAuthorization", "cancelSale",
      "expirePrimaryOffer", "syncCollectionContest", "core", "mintManager", "revenueResolver", "artistRegistry",
      "moduleRegistry", "eip712Domain"],
  },
  gate: {
    source: "smart-contracts/domains/mint/StreamNativePrimaryOfferGate.sol", contract: "StreamNativePrimaryOfferGate",
    methods: ["publication", "manifestBytes", "itemCount", "gateConfigHash", "managerCodeHash", "houseCodeHash", "offerPurchaseVersion"],
  },
  manager: {
    source: "smart-contracts/domains/mint/StreamMintManager.sol", contract: "StreamMintManager",
    methods: ["core", "mintLedger", "mintOfferAuthorizationId", "voidMintOffer", "isAuthorizationUsed"],
  },
  ledger: {
    source: "smart-contracts/domains/mint/StreamMintLedger.sol", contract: "StreamMintLedger",
    methods: ["isManagerAuthorizationUsed"],
  },
};

export function currentPrimaryOfferFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen primary offer compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 396
    || output.errors?.some(error => error.severity === "error")) throw Error("Expected clean 396-source offer capture");
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
    carrierCommit: "6d69483cc7eeee748271f531821ed2bf7643a787", sourceCount: 396, compilerVersion: "0.8.19",
    sourceNormalization: "UTF-8 CRLF to LF", inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    qualification: "Source and selected compiled ABI evidence only; no current-stack, Safe runtime, gas, deployment or release acceptance.",
    sources, selections, abis };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-primary-offer-fixture.mjs INPUT OUTPUT [--check]");
  const result = JSON.stringify(currentPrimaryOfferFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-primary-offer-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== result) throw Error("Stale primary offer fixture");
  } else await writeFile(target, result, "utf8");
}
