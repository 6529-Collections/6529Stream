// Retain the exact ABI117 recipient Merkle distribution source. Never invoke Solidity.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "5d1756eb53a28ebc5ecd24513493ce6bfe7ef62f";
const TREE = "b0d30c650c1e55d3b213a3e0159dcb54d0a17c42";
const INPUT_SHA = "d922340003209b74572b9f047c68143400d96a7b8bf2f0dc6466cc071ba3f970";
const OUTPUT_SHA = "b6d298b26e2f0c004f7f7193f679f115093d71705ff777108b7f5cc7a9dafcc7";
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const contracts = {
  distributor: "StreamOperatorDistribution",
  distributionInterface: "IStreamOperatorDistribution",
  merkleInterface: "IStreamOperatorDistributionMerkle",
  manager: "StreamMintManager",
  managerInterface: "IStreamMintManager",
  mintReads: "IStreamMintReads",
  mintPreview: "IStreamMintPreview",
  mintExecution: "IStreamMintExecution",
  counterReads: "IStreamMintCounterReads",
  counterPolicy: "IStreamMintCounterPolicy",
  ledger: "StreamMintLedger",
  ledgerInterface: "IStreamMintLedger",
  ledgerRevocation: "IStreamMintLedgerRevocation",
  ledgerContinuity: "IStreamMintLedgerContinuity",
  royaltyPolicy: "IStreamMintRoyaltyPolicy",
  core: "StreamCore",
  coreInterface: "IStreamCore",
  corePointers: "IStreamCorePointers",
  modules: "StreamModuleRegistry",
  moduleInterface: "IStreamModuleRegistry",
  delegation: "DelegationManagementContract",
  delegationInterface: "IDelegationManagementContract",
  entropy: "StreamEntropyCoordinator",
  entropyInterface: "IStreamEntropyCoordinator",
  entropyView: "IStreamEntropyView",
  entropyPolicy: "IStreamEntropyCollectionPolicy",
  revealEscrow: "IStreamRevealFeeEscrow",
  reveal: "IStreamImmediateSaleReveal",
  royaltySnapshot: "IStreamRoyaltySnapshot",
  resolver: "StreamRevenueResolver",
  resolverInterface: "IStreamRevenueResolver",
  royaltyResolver: "IStreamRoyaltyResolver",
  erc721: "IERC721",
  gas: "IStreamGasParameterHost",
};
const documents = [
  "docs/adr/0003-payment-accounting.md",
  "docs/adr/0028-reveal-fee-custody-and-role-activation.md",
  "docs/adr/0044-prepared-royalty-snapshot-consent.md",
  "docs/guides/operator-distribution.md",
  "docs/mint-policy-and-accounting.md",
  "docs/stream-sales-and-auctions.md",
  "artifacts/distribution-merkle-caps.md",
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
  if (cursor !== blobs.length || literalBytes !== 35_100_884) throw Error("Frozen literal inventory differs");
}

export function distributionMerkleFixture(inputBytes, outputBytes, bridgeBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact ABI117 input/output");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), bridge = JSON.parse(bridgeBytes);
  if (bridge.sourceCommit !== SOURCE || bridge.sources !== 3000 || bridge.inputSHA256 !== INPUT_SHA
    || !Array.isArray(bridge.mismatches) || bridge.mismatches.length !== 0) throw Error("Invalid committed source bridge");
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 3000
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid distribution Merkle capture");
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
    profile: "recipient-merkle-operator-distribution-v1",
    capture: "parallel-feature-batch117-20260920",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 3000,
    compilerReportedCommit: "c686a29f4ba6031cccfe8fd60a0b0aef296aa85a",
    committedSourceBridge: { sha256: sha(bridgeBytes), ...bridge },
    literalBytes: 35_100_884,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "Every compiler input literal matches its frozen Git blob byte-for-byte; this verifier performs no line-ending normalization. All selected ABIs are complete compiler output, with the full imported source closure. Interpretation documents come from the same source commit.",
    qualification: "Source/ABI and mocked client evidence for recipient MERKLE_STATIC operator distributions. The additive MPA-MERKLE.7 commitment binds the original STATIC program hash, the actual Manager-selected recipient definition hash and its full-list publication hash. Original Program, slice and authorization encodings and the earlier STATIC fixture remain unchanged. Proof rows retain actual configured Merkle-counter order and complete beneficiary order, including duplicates. Operational scope covers exact operator distributions and original own/delegated owed-NFT claims through direct and Safe CALLs. No sale or revenue settlement exists. Phase setup, governance/gas writes, native execution, deployed-runtime identity, full rollback proofs and release acceptance remain separately qualified.",
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
    throw Error("Usage: generate-current-distribution-merkle-fixture.mjs INPUT OUTPUT COMMITTED_SOURCE_BRIDGE [--check]");
  }
  const rendered = JSON.stringify(distributionMerkleFixture(await readFile(input), await readFile(output), await readFile(bridge)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-distribution-merkle-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale distribution Merkle fixture");
    process.stdout.write("Distribution Merkle fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Distribution Merkle fixture written\n");
  }
}
