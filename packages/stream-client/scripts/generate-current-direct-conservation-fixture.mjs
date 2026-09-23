// Project retained ABI98 and frozen source interpretation without invoking Solidity.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "8bb6dfe2957542f641b0d558e1cfd48e1b39ae98";
const TREE = "d521268a11aaeb867c6c43f9a8140042a187c1cc";
const INPUT_SHA = "5828313cd35628ec3935cc0447faefb592b12b1ef79b2ac0ae225b2106c7152c";
const OUTPUT_SHA = "573e271eb99807b2847e47502d3a7f3fc751ce07e07918d5ad5791062732e55a";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const contracts = {
  core: "StreamCore",
  coreCollection: "IStreamCoreCollectionView",
  coreTier: "IStreamCoreConservationTier",
  coreFloor: "IStreamCoreConservationFloor",
  manager: "StreamMintManager",
  managerInterface: "IStreamMintManager",
  mintReads: "IStreamMintReads",
  mintExecution: "IStreamMintExecution",
  nativeSale: "StreamFixedPriceSaleAdapter",
  nativeInterface: "IStreamFixedPriceSaleAdapter",
  erc20Sale: "StreamERC20FixedPriceSaleAdapter",
  erc20Interface: "IStreamERC20FixedPriceSaleAdapter",
  auction: "StreamEnglishAuctionHouse",
  auctionInterface: "IStreamEnglishAuctionHouse",
  directReceipt: "IStreamDirectPrimarySaleReceipt",
  floor: "StreamConservationFloor",
  floorInterface: "IStreamConservationFloor",
  directFloor: "IStreamDirectPrimaryConservationFloor",
  providerInterface: "IStreamConservationFloorProvider",
  nativeProvider: "StreamNativeConservationFloorProvider",
  metadata: "StreamCollectionMetadataV1",
  modules: "StreamModuleRegistry",
  moduleInterface: "IStreamModuleRegistry",
  gasParameters: "IStreamGasParameterHost",
  executor: "StreamGovernanceExecutor",
  resolver: "StreamRevenueResolver",
  resolverInterface: "IStreamRevenueResolver",
  factory: "StreamSplitFactory",
  factoryInterface: "IStreamSplitFactory",
  assets: "IStreamAssetPolicyRegistry",
  escrow: "IStreamRevenueEscrow",
  artistAttribution: "IStreamArtistAttribution",
  paymentIntent: "IStreamPaymentIntentVerifier",
  erc20: "IERC20",
  erc1271: "IERC1271"
};
const oracleNames = [
  "StreamDirectPrimarySaleTypes", "StreamDirectPrimaryConservationTypes",
  "StreamConservationFloorTypes", "StreamDirectPrimarySaleHash",
  "StreamDirectPrimaryReceipts", "StreamDirectPrimaryAdmission",
  "StreamDirectPrimarySaleFloorCall", "StreamConservationDirectReads",
  "StreamConservationDirectHistory", "StreamConservationFloorReads",
  "StreamConservationFloorSupplemental", "StreamConservationTiers",
  "StreamSettlementAdmission", "StreamSaleArtist", "StreamLegacySaleConsent",
  "StreamSaleFunding", "StreamSaleTemplate", "StreamSaleSignatures",
  "StreamPaymentIntentVerifier",
  "StreamCoreTypes", "StreamMintOperationIdentity", "StreamMintPreview",
  "StreamMintTranscriptTypes", "StreamMintManagerViews",
  "StreamPrimarySettlementTypes", "StreamMetadataSubjects"
];
const testPaths = [
  "test/current/StreamCurrentDirectConservation.t.sol",
  "test/unit/auctions/StreamEnglishAuctionDirectConservation.t.sol",
  "test/unit/auctions/StreamEnglishAuctionHouse.t.sol",
  "test/unit/core/StreamCoreConservationFloor.t.sol",
  "test/unit/metadata/StreamConservationFloor.t.sol",
  "test/unit/metadata/StreamDirectPrimaryConservationFloor.t.sol",
  "test/unit/mint/StreamERC20FixedPriceSaleAdapter.t.sol",
  "test/unit/mint/StreamFixedPriceSaleAdapter.t.sol"
];
const documentPaths = [
  "docs/integrations/direct-primary-conservation.md",
  "docs/conservation-sale-floor.md",
  "docs/museum-conservation-floor-source.md"
];

export function directConservationFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) {
    throw Error("Expected exact retained ABI98 input/output");
  }
  const input = JSON.parse(inputBytes);
  const output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2591
      || output.errors?.some(e => e.severity === "error")) {
    throw Error("Invalid frozen DIRECT conservation capture");
  }
  const abis = {}, selections = {}, sourceHashes = {}, sourceTexts = {}, documents = {};
  function visit(path) {
    if (sourceHashes[path]) return;
    const source = input.sources[path]?.content;
    if (typeof source !== "string") throw Error(`Missing source ${path}`);
    sourceHashes[path] = sha(source);
    for (const imported of solidityImports(source)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  for (const [key, contract] of Object.entries(contracts)) {
    const matches = Object.entries(output.contracts).filter(([path, values]) =>
      path.startsWith("smart-contracts/") && values[contract]);
    if (matches.length !== 1) throw Error(`Expected one compiled ${contract}`);
    const [source, values] = matches[0];
    const abi = values[contract].abi;
    if (!Array.isArray(abi)) throw Error(`Missing ABI ${contract}`);
    selections[key] = { source, contract, full: true, capture: "direct" };
    abis[key] = abi;
  }
  const oracles = oracleNames.map(name => {
    const matches = Object.keys(input.sources).filter(path => path.endsWith(`/${name}.sol`));
    if (matches.length !== 1) throw Error(`Expected one source for ${name}`);
    return matches[0];
  });
  const retained = new Set([...Object.values(selections).map(s => s.source), ...oracles, ...testPaths]);
  for (const path of [...retained].sort()) {
    visit(path);
    sourceTexts[path] = input.sources[path].content;
  }
  for (const path of documentPaths) {
    const bytes = execFileSync("git", ["show", `${SOURCE}:${path}`], { maxBuffer: 1024 * 1024 });
    const text = bytes.toString("utf8");
    if (!Buffer.from(text, "utf8").equals(bytes)) throw Error(`Invalid UTF-8 document ${path}`);
    documents[path] = { sha256: sha(bytes), byteLength: bytes.length, text };
  }
  return {
    schemaVersion: 1,
    profile: "direct-conservation-v1",
    capture: "parallel-feature-batch98-20260920",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 2591,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "All 2591 retained compiler input literals (30084406 bytes) independently match the frozen Git source byte-for-byte. Interpretation documents come from that exact commit.",
    producerLineage: {
      originalProductsIntegration: "e3ff6308c6aa4171ffb5399c02a41045c39d6918",
      typedFloorIntegration: "3979cc3e701a027e5098813fbdee827bd77ccc2e",
      canonicalProductAdmission: "447ba56ece04cc6fc8385e1bfbb3c02f989a1ca6",
      immutableHistoryWorker: "c379bffacc6c9e45adb3ee4f2f35bc58dafdecc5"
    },
    separateRuntimeEvidence: {
      sourceCommit: "844d5f323acb459adec33db7b218901545ec84c2",
      tests: 73,
      suites: { floorLedger: 34, typedDirectFloor: 25, nativeProvider: 14 },
      sourceCount: 188,
      nonemptyProductionArtifacts: 82,
      testResultsSha256: "e3baf24b2f91b933ac7fdbc4a902a15a2417d2bf6f9dd6565f124e7fd4a75035",
      sourceManifestSha256: "ce9fb30854ad2cc3e74d6a88e01f3ca3136fb44fe883498cdb8b5bd54ccda418",
      qualification: "The retained direct-conservation-native1 summary reports 73 passing floor/provider cases against declared typed boundaries and all 82 nonempty production artifacts within size limits. It excludes original adapter signatures/payment/current7, actual Artist3, the full joined graph, deployment and cold whole-transaction gas acceptance. It is not relabeled as acceptance of this client source profile."
    },
    qualification: "Source/ABI and mocked client evidence for the original native fixed-price, ERC20 fixed-price and English-auction calls, typed DIRECT receipts and immutable floor history. Original authorization, payment and callback semantics remain authoritative. No universal settlement candidate, direct preparation or arbitrary-wallet floor writer is synthesized. Separately reported producer native cohorts do not establish acceptance of this joined source, complete Artist personhood evidence, the whole-paid-transaction gas target, deployment or release readiness. Earlier fixtures retain their original source and runtime qualifications.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts,
    documents,
    selections,
    abis
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || mode !== undefined && mode !== "--check") {
    throw Error("Usage: generate-current-direct-conservation-fixture.mjs INPUT OUTPUT [--check]");
  }
  const rendered = JSON.stringify(directConservationFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-direct-conservation-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale DIRECT conservation fixture");
  } else {
    await writeFile(target, rendered, "utf8");
  }
}
