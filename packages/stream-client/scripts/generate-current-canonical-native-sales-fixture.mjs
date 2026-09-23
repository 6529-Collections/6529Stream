// Retain the exact ABI113 canonical native sales source. Never invoke Solidity.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "4fa32ae1c9206b05be848c7553c6492f516a7bfe";
const TREE = "36bc632478b81ca929ab0eebec379f0e696f18c5";
const INPUT_SHA = "47ffa8bf3e2089ae875f0cb477b530a37696f598edc86daf8dff4af391468847";
const OUTPUT_SHA = "952debfc67638be049507a9d15a7b2eeae0b0ef7a0077174be12a72258642b7e";
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const contracts = {
  immediate: "StreamNativeImmediateSales",
  claim: "StreamNativeClaimSales",
  immediateInterface: "IStreamNativeImmediateSales",
  claimInterface: "IStreamNativeClaimSales",
  domain: "IERC5267",
  reveal: "IStreamImmediateSaleReveal",
  authorizationBinding: "IStreamImmediateSaleAuthorizationBinding",
  revocation: "IStreamMintImmediateSaleAuthorizationRevocation",
  manager: "StreamMintManager",
  managerInterface: "IStreamMintManager",
  mintReads: "IStreamMintReads",
  mintPreview: "IStreamMintPreview",
  counterPolicy: "IStreamMintCounterPolicy",
  ledger: "StreamMintLedger",
  ledgerInterface: "IStreamMintLedger",
  ledgerRevocation: "IStreamMintLedgerRevocation",
  core: "StreamCore",
  coreInterface: "IStreamCore",
  coreFloor: "IStreamCoreConservationFloor",
  coreTier: "IStreamCoreConservationTier",
  recorder: "StreamPrimarySaleSettlement",
  primarySettlement: "IStreamPrimarySaleSettlement",
  nativeSettlement: "IStreamNativePrimarySaleSettlement",
  publicSettlement: "IStreamNativePublicPrimarySaleSettlement",
  nativeBinding: "IStreamNativeSaleBinding",
  publicBinding: "IStreamNativePublicSaleBinding",
  resolver: "StreamRevenueResolver",
  resolverInterface: "IStreamRevenueResolver",
  factory: "StreamSplitFactory",
  escrow: "StreamRevenueEscrow",
  modules: "StreamModuleRegistry",
  moduleInterface: "IStreamModuleRegistry",
  assets: "StreamAssetPolicyRegistry",
  assetPolicy: "IStreamAssetPolicyRegistry",
  roles: "StreamRoleRegistry",
  roleInterface: "IStreamRoleRegistry",
  artistAttribution: "IStreamArtistAttribution",
  artistSale: "IStreamArtistSaleAuthority",
  artistFacts: "IStreamArtistSaleFacts",
  artistConsentOwner: "IStreamArtistSaleConsentOwner",
  artistIdentityOwner: "IStreamArtistSaleIdentityOwner",
  entropy: "StreamEntropyCoordinator",
  entropyPolicy: "IStreamEntropyCollectionPolicy",
  entropyView: "IStreamEntropyView",
  entropyInterface: "IStreamEntropyCoordinator",
  revealEscrow: "IStreamRevealFeeEscrow",
  floor: "StreamConservationFloor",
  floorInterface: "IStreamConservationFloor",
  floorProvider: "IStreamConservationFloorProvider",
  floorRelease: "IStreamConservationReleaseContext",
  gas: "IStreamGasParameterHost",
  erc1271: "IERC1271",
};
const documents = [
  "docs/adr/0019-payment-intent-orchestration.md",
  "docs/adr/0028-reveal-fee-custody-and-role-activation.md",
  "docs/adr/0037-full-payload-mint-authorization-revocation.md",
  "docs/integrations/native-immediate-sales.md",
  "docs/integrations/native-claim-sales.md",
  "docs/integrations/native-allowlist-price-programs.md",
  "docs/integrations/native-commerce-deployment.md",
  "docs/integrations/sale-parameter-consent.md",
  "docs/integrations/sale-signing-domains.md",
];

function bindAllGitLiterals(input) {
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
    cursor = end + size + 2;
    literalBytes += size;
  }
  if (cursor !== blobs.length || literalBytes !== 34_614_289) throw Error("Frozen literal inventory differs");
}

export function canonicalNativeSalesFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact ABI113 input/output");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2953
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid canonical native capture");
  if (execFileSync("git", ["rev-parse", `${SOURCE}^{tree}`], { encoding: "utf8" }).trim() !== TREE) throw Error("Frozen tree differs");
  bindAllGitLiterals(input);
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
    profile: "canonical-native-immediate-and-claim-sales-v1",
    capture: "parallel-feature-batch113-20260920",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 2953,
    literalBytes: 34_614_289,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "Every compiler input literal matches its frozen Git blob byte-for-byte; this verifier performs no line-ending normalization. All selected ABIs are complete compiler output, with the full imported source closure. Interpretation documents come from the same source commit.",
    qualification: "Source/ABI and mocked client evidence for canonical native Immediate kinds 0/1 and Claim kinds 12/13, SIGNED mode 1 and PUBLIC mode 2. The complete original 24-field Sales-v1 authorization is distinct from the earlier native fixed/price-program profiles; their fixtures and qualifications remain unchanged. The actual payer/executor, including a Safe, performs the payable CALL. Literal zero Claim execution creates no official settlement receipt; a later positive sale still needs its original paid floor. Operational scope covers purchases, native excess refunds and full-payload historical Manager revocation. Lifecycle administration, setup, gas writes, deployed-code acceptance, native contract/Safe execution and release readiness are outside this fixture's caller evidence.",
    sourceHashes: sorted(sourceHashes),
    sourceTexts: sorted(sourceTexts),
    documents: retainedDocuments,
    selections,
    methodIdentifiers,
    abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || mode !== undefined && mode !== "--check") {
    throw Error("Usage: generate-current-canonical-native-sales-fixture.mjs INPUT OUTPUT [--check]");
  }
  const rendered = JSON.stringify(canonicalNativeSalesFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-canonical-native-sales-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale canonical native fixture");
    process.stdout.write("Canonical native sales fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Canonical native sales fixture written\n");
  }
}
