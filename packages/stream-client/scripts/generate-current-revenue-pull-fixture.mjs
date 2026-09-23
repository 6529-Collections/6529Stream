// Retain the exact ABI107 revenue pull/recovery source. Never invoke Solidity.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "d88ee108080ba1e66f1b8a9b49e3fd9a59d35c4a";
const TREE = "8572b46becb1b0207b2313e6371b034e4a5381ee";
const INPUT_SHA = "8f7a2f3597177dbd5bbc84eebae2cf2f80c5205aefbfa0e913e62590720dc740";
const OUTPUT_SHA = "1de19aca0c19df097c8c51123d1975574ff6b997901e77bc6c51806776d92edc";
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const contracts = {
  wallet: "StreamSplitWallet",
  walletInterface: "IStreamSplitWallet",
  factory: "StreamSplitFactory",
  factoryInterface: "IStreamSplitFactory",
  implementationInterface: "IStreamSplitWalletImplementation",
  router: "StreamClaimRouter",
  routerInterface: "IStreamClaimRouter",
  escrow: "StreamRevenueEscrow",
  escrowInterface: "IStreamRevenueEscrow",
  escrowRecovery: "IStreamRevenueEscrowRecovery",
  escrowManifest: "IStreamRevenueEscrowRecoveryManifest",
  assets: "StreamAssetPolicyRegistry",
  assetPolicy: "IStreamAssetPolicyRegistry",
  runtime: "StreamRevenueRuntimeRegistry",
  runtimeInterface: "IStreamRevenueRuntimeRegistry",
  runtimeBinding: "IStreamRevenueRuntimeBinding",
  executor: "StreamGovernanceExecutor",
  governanceExecutor: "IStreamGovernanceExecutor",
  governanceReads: "IStreamGovernanceReads",
  governanceExecution: "IStreamGovernanceExecution",
  governanceFacts: "IStreamGovernanceActionFacts",
  roles: "StreamRoleRegistry",
  roleInterface: "IStreamRoleRegistry",
  gasParameters: "IStreamGasParameterHost",
  erc20: "IERC20",
  erc1271: "IERC1271",
};
const documents = [
  "docs/adr/0003-payment-accounting.md",
  "docs/adr/0004-admin-governance.md",
  "docs/adr/0008-revenue-splits-and-royalty-resolver.md",
  "docs/guides/revenue-runtime-escrow-recovery.md",
  "docs/integrations/split-profiles.md",
  "docs/integrations/split-wallet-releases.md",
  "docs/revenue-splits-and-royalties.md",
];
const reuseSource = "7382327933c90638e8552fc8dd0340e9de53c449";
const reusePaths = [
  "smart-contracts/domains/revenue/StreamSplitFactory.sol",
  "smart-contracts/domains/revenue/StreamSplitWallet.sol",
  "smart-contracts/domains/revenue/StreamSplitWalletDeployment.sol",
  "smart-contracts/domains/revenue/StreamReleaseAuthorization.sol",
  "smart-contracts/domains/revenue/StreamClaimRouter.sol",
  "smart-contracts/interfaces/stream/revenue/IStreamSplitFactory.sol",
  "smart-contracts/interfaces/stream/revenue/IStreamSplitWallet.sol",
  "smart-contracts/interfaces/stream/revenue/IStreamSplitWalletImplementation.sol",
  "smart-contracts/interfaces/stream/revenue/IStreamClaimRouter.sol",
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
    const end = blobs.indexOf(10, cursor);
    const header = blobs.subarray(cursor, end).toString("ascii");
    const size = Number(header.split(" ")[2]);
    if (end < cursor || !header.includes(" blob ") || !Number.isSafeInteger(size) || size < 0) {
      throw Error(`Missing frozen source ${path}`);
    }
    const bytes = blobs.subarray(end + 1, end + 1 + size);
    if (!bytes.equals(Buffer.from(source.content, "utf8"))) throw Error(`Compiler/Git bytes differ: ${path}`);
    cursor = end + size + 2;
    literalBytes += size;
  }
  if (cursor !== blobs.length || literalBytes !== 33_830_434) throw Error("Unexpected literal input inventory");
}

export function revenuePullFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact retained ABI107 input/output");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2865
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid frozen revenue capture");
  const tree = execFileSync("git", ["rev-parse", `${SOURCE}^{tree}`], { encoding: "utf8" }).trim();
  if (tree !== TREE) throw Error("Frozen source tree differs");
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
  const matchingFiles = {};
  for (const path of reusePaths) {
    const prior = execFileSync("git", ["show", `${reuseSource}:${path}`], { maxBuffer: 4 * 1024 * 1024 });
    if (!prior.equals(Buffer.from(input.sources[path]?.content ?? "", "utf8"))) throw Error(`Prior helper source changed: ${path}`);
    matchingFiles[path] = sha(prior);
    visit(path);
  }
  const sorted = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => order(a, b)));
  return {
    schemaVersion: 1,
    profile: "revenue-pull-and-escrow-recovery-v1",
    capture: "parallel-feature-batch107-20260920",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 2865,
    literalBytes: 33_830_434,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "Every retained compiler input literal matches its frozen Git blob byte-for-byte; no line-ending normalization is used in this verification. Selected full ABIs and the complete imported source closure come from that input/output. Interpretation documents come from the same commit.",
    priorHelperReuse: {
      sourceCommit: reuseSource,
      matchingFiles,
      qualification: "Only these exact source files are compared for existing split-profile, clone and authorization helper reuse. This is not whole-closure, deployed-runtime or native-execution compatibility evidence. All earlier fixtures retain their original qualifications.",
    },
    qualification: "Source/ABI and mocked client evidence for initialized clone wallet pulls, ClaimRouter batches and Escrow flush/recovery. The role-6 singleton implementation is not a claim wallet. Governed recovery targets retain the actual Executor action context and class; ordinary Safe CALLs confer no governance authority. Setup, producer credits and their admission, surplus sweeps, current deployment acceptance, native contract/Safe execution and gas sizing are outside this caller fixture. Recovery preserves the original escrow-held credit boundary and never redirects resident old-wallet balances.",
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
    throw Error("Usage: generate-current-revenue-pull-fixture.mjs INPUT OUTPUT [--check]");
  }
  const rendered = JSON.stringify(revenuePullFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-revenue-pull-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale revenue pull fixture");
    process.stdout.write("Revenue pull fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Revenue pull fixture written\n");
  }
}
