// Retain the exact ABI121 canonical Dutch source. Never invoke Solidity.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "6536c25895ae12eb9d702da9361f067152060d9b";
const TREE = "d4b524e8125570855880f96fe42da5b3fa9c55ba";
const INPUT_SHA = "3c29417776dfd5a5a14c91cd759cb0c84ff336886081dd6e576c3825271fc531";
const OUTPUT_SHA = "bc0ad0abc35eeae5e9e645da7fa3ddc6c5faf6474a841952941992c6fa4804ff";
const BRIDGE_SHA = "78ba92fd9390ce976a0b5b5ff88476c2a916346acabe64af64f81cf6295c1f7b";
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const contracts = {
  "immediate": "StreamNativeImmediateSales",
  "claim": "StreamNativeClaimSales",
  "immediateInterface": "IStreamNativeImmediateSales",
  "claimInterface": "IStreamNativeClaimSales",
  "domain": "IERC5267",
  "reveal": "IStreamImmediateSaleReveal",
  "authorizationBinding": "IStreamImmediateSaleAuthorizationBinding",
  "revocation": "IStreamMintImmediateSaleAuthorizationRevocation",
  "manager": "StreamMintManager",
  "managerInterface": "IStreamMintManager",
  "mintReads": "IStreamMintReads",
  "mintPreview": "IStreamMintPreview",
  "counterPolicy": "IStreamMintCounterPolicy",
  "ledger": "StreamMintLedger",
  "ledgerInterface": "IStreamMintLedger",
  "ledgerRevocation": "IStreamMintLedgerRevocation",
  "core": "StreamCore",
  "coreInterface": "IStreamCore",
  "coreFloor": "IStreamCoreConservationFloor",
  "coreTier": "IStreamCoreConservationTier",
  "recorder": "StreamPrimarySaleSettlement",
  "primarySettlement": "IStreamPrimarySaleSettlement",
  "nativeSettlement": "IStreamNativePrimarySaleSettlement",
  "publicSettlement": "IStreamNativePublicPrimarySaleSettlement",
  "nativeBinding": "IStreamNativeSaleBinding",
  "publicBinding": "IStreamNativePublicSaleBinding",
  "resolver": "StreamRevenueResolver",
  "resolverInterface": "IStreamRevenueResolver",
  "factory": "StreamSplitFactory",
  "escrow": "StreamRevenueEscrow",
  "modules": "StreamModuleRegistry",
  "moduleInterface": "IStreamModuleRegistry",
  "assets": "StreamAssetPolicyRegistry",
  "assetPolicy": "IStreamAssetPolicyRegistry",
  "roles": "StreamRoleRegistry",
  "roleInterface": "IStreamRoleRegistry",
  "artistAttribution": "IStreamArtistAttribution",
  "artistSale": "IStreamArtistSaleAuthority",
  "artistFacts": "IStreamArtistSaleFacts",
  "artistConsentOwner": "IStreamArtistSaleConsentOwner",
  "artistIdentityOwner": "IStreamArtistSaleIdentityOwner",
  "entropy": "StreamEntropyCoordinator",
  "entropyPolicy": "IStreamEntropyCollectionPolicy",
  "entropyView": "IStreamEntropyView",
  "entropyInterface": "IStreamEntropyCoordinator",
  "revealEscrow": "IStreamRevealFeeEscrow",
  "floor": "StreamConservationFloor",
  "floorInterface": "IStreamConservationFloor",
  "floorProvider": "IStreamConservationFloorProvider",
  "floorRelease": "IStreamConservationReleaseContext",
  "gas": "IStreamGasParameterHost",
  "erc1271": "IERC1271",
  "nativeDutch": "StreamNativeDutchSales",
  "nativeDutchInterface": "IStreamNativeDutchSales",
  "dutchSchedule": "IStreamDutchPriceSchedule",
  "erc20Dutch": "StreamERC20DutchSale",
  "erc20DutchInterface": "IStreamERC20DutchSale",
  "payment": "StreamERC20PrimarySettlementAdapter",
  "paymentInterface": "IStreamERC20PrimarySettlementAdapter",
  "dutchPayments": "IStreamERC20DutchPayments",
  "dutchResolution": "IStreamERC20DutchSaleResolution",
  "dutchFreeExecution": "IStreamERC20DutchFreeExecution",
  "erc20Execution": "IStreamERC20SaleExecution",
  "erc20PublicBinding": "IStreamERC20PublicSaleBinding",
  "erc20DutchSettlement": "IStreamERC20DutchPrimarySaleSettlement",
  "erc20PublicDutchSettlement": "IStreamERC20PublicDutchPrimarySaleSettlement",
  "assetPermitPolicy": "IStreamAssetPermitPolicy",
  "paymentIntent": "IStreamPaymentIntentVerifier",
  "permit2": "IStreamPinnedPermit2",
  "token": "IERC20",
  "mintExecution": "IStreamMintExecution",
  "counterReads": "IStreamMintCounterReads",
  "ledgerContinuity": "IStreamMintLedgerContinuity",
  "corePointers": "IStreamCorePointers"
};
const documents = [
  "docs/adr/0003-payment-accounting.md",
  "docs/adr/0019-payment-intent-orchestration.md",
  "docs/adr/0028-reveal-fee-custody-and-role-activation.md",
  "docs/adr/0037-full-payload-mint-authorization-revocation.md",
  "docs/adr/0045-native-reveal-fees-for-token-sales.md",
  "docs/integrations/canonical-native-dutch-sales.md",
  "docs/integrations/erc20-standard-dutch.md",
  "docs/integrations/erc20-dutch-recorder.md",
  "docs/integrations/native-allowlist-price-programs.md",
  "docs/integrations/native-commerce-deployment.md",
  "docs/integrations/sale-parameter-consent.md",
  "docs/integrations/sale-signing-domains.md",
  "docs/erc20-immediate-reveal.md",
  "docs/mint-policy-and-accounting.md",
  "docs/stream-sales-and-auctions.md"
];

function bindAllGitLiterals(input, bridge) {
  const entries = Object.entries(input.sources).sort(([a], [b]) => order(a, b));
  if (entries.some(([path, source]) => /[\r\n]/.test(path) || typeof source.content !== "string")) {
    throw Error("Invalid compiler source literal");
  }
  const blobs = execFileSync("git", ["cat-file", "--batch"], {
    input: entries.map(([path]) => `${SOURCE}:${path}\n`).join(""), maxBuffer: 128 * 1024 * 1024,
  });
  let cursor = 0, literalBytes = 0;
  for (const [path, source] of entries) {
    const end = blobs.indexOf(10, cursor), header = blobs.subarray(cursor, end).toString("ascii");
    const size = Number(header.split(" ")[2]);
    if (end < cursor || !header.includes(" blob ") || !Number.isSafeInteger(size) || size < 0) {
      throw Error(`Missing frozen source ${path}`);
    }
    const bytes = blobs.subarray(end + 1, end + 1 + size);
    if (!bytes.equals(Buffer.from(source.content, "utf8"))) throw Error(`Compiler/Git bytes differ: ${path}`);
    if (bridge.committedBlobSHA256[path] !== sha(bytes)) throw Error("Bridge/Git hash differs: " + path);
    cursor = end + size + 2;
    literalBytes += size;
  }
  if (cursor !== blobs.length || literalBytes !== 35_616_310) throw Error("Frozen literal inventory differs");
}

export function canonicalDutchFixture(inputBytes, outputBytes, bridgeBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact ABI121 input/output");
  if (sha(bridgeBytes) !== BRIDGE_SHA) throw Error("Expected exact ABI121 committed source bridge");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), bridge = JSON.parse(bridgeBytes);
  if (bridge.commit !== SOURCE || bridge.sources !== 3033
    || Object.keys(bridge.committedBlobSHA256 ?? {}).length !== 3033
    || !Array.isArray(bridge.mismatches) || bridge.mismatches.length !== 0) throw Error("Invalid committed source bridge");
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 3033
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid canonical Dutch capture");
  if (execFileSync("git", ["rev-parse", `${SOURCE}^{tree}`], { encoding: "utf8" }).trim() !== TREE) throw Error("Frozen tree differs");
  bindAllGitLiterals(input, bridge);
  const abis = {}, selections = {}, methodIdentifiers = {}, sourceHashes = {}, sourceTexts = {};
  function visit(path) {
    if (Object.hasOwn(sourceHashes, path)) return;
    const source = input.sources[path]?.content;
    if (typeof source !== "string") throw Error(`Missing source ${path}`);
    sourceHashes[path] = sha(source);
    sourceTexts[path] = source;
    for (const imported of solidityImports(source)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  for (const [key, name] of Object.entries(contracts)) {
    const matches = Object.entries(output.contracts).filter(([path, entries]) => path.startsWith("smart-contracts/") && entries[name]);
    if (matches.length !== 1) throw Error(`Expected one compiled ${name}`);
    const [source, entries] = matches[0], contract = entries[name];
    if (!Array.isArray(contract.abi)) throw Error(`Missing full ABI ${name}`);
    abis[key] = contract.abi;
    selections[key] = { source, contract: name, full: true };
    methodIdentifiers[key] = contract.evm?.methodIdentifiers ?? {};
    visit(source);
  }
  const retainedDocuments = {};
  for (const path of documents) {
    const bytes = execFileSync("git", ["show", `${SOURCE}:${path}`], { maxBuffer: 4 * 1024 * 1024 });
    const text = bytes.toString("utf8");
    if (!Buffer.from(text, "utf8").equals(bytes)) throw Error(`Invalid UTF-8 document ${path}`);
    retainedDocuments[path] = { sha256: sha(bytes), byteLength: bytes.length, text };
  }
  const sorted = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => order(a, b)));
  return {
    schemaVersion: 1,
    profile: "canonical-native-and-erc20-dutch-v1",
    capture: "parallel-feature-batch121-20260920",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 3033,
    compilerReportedCommit: "0f30e1d56d145712a1b3cae69a73b233e036e1d9",
    committedSourceBridge: { sha256: sha(bridgeBytes), ...bridge },
    literalBytes: 35_616_310,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "Every compiler input literal matches its frozen Git blob byte-for-byte; this verifier performs no line-ending normalization. All selected ABIs are complete compiler output, with the full imported source closure. Interpretation documents come from the same source commit.",
    qualification: "Source/ABI and mocked client evidence for original canonical Sales-v1 standard Dutch purchases. Native and ERC20 profiles retain all 24 authorization fields, distinct original family commitments, live inclusion-price rules, same-leaf overrides and declared free outcomes. Native reveal funding remains separate from token price and maximum permit authorization. Operational scope covers original purchase/payment routes, local pull refunds and historical Manager kind-3 revocation through direct and Safe CALLs; carrier-only callbacks, sale setup and administrative writes are not wallet plans. Earlier fixtures and client profiles retain their own evidence. Native execution, deployed-runtime identity, complete rollback proofs, gas/capacity and release acceptance remain separately qualified.",
    sourceHashes: sorted(sourceHashes),
    sourceTexts: sorted(sourceTexts),
    documents: retainedDocuments,
    selections,
    methodIdentifiers,
    abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, bridge, mode] = process.argv.slice(2);
  if (!input || !output || !bridge || mode !== undefined && mode !== "--check") {
    throw Error("Usage: generate-current-canonical-dutch-fixture.mjs INPUT OUTPUT COMMITTED_SOURCE_BRIDGE [--check]");
  }
  const rendered = JSON.stringify(canonicalDutchFixture(await readFile(input), await readFile(output), await readFile(bridge)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-canonical-dutch-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale canonical Dutch fixture");
    process.stdout.write("Canonical Dutch fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Canonical Dutch fixture written\n");
  }
}
