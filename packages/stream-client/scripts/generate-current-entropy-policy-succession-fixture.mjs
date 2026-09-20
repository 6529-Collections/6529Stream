// Project the exact retained joined ABI89 capture. This script never invokes a compiler.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SOURCE_COMMIT = "7901f3b108a7acc44780e6b686157d1016059e52";
const INPUT_SHA = "a7ee3da0c12de531be1a61e54dd56bdf3def42881668b548611b9acf12d9d061";
const OUTPUT_SHA = "819ad416493a988d7c9ae80107750689cad48f5a19b7a1f3c478af40324907c7";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const ei = "smart-contracts/interfaces/stream/entropy/", entropy = "smart-contracts/domains/entropy/";
const governance = "smart-contracts/domains/governance/";
const full = (source, contract) => ({ source, contract, full: true, capture: "succession" });
const selections = {
  entropy: full(entropy + "StreamEntropyCoordinator.sol", "StreamEntropyCoordinator"),
  continuity: full(ei + "IStreamEntropyPolicyContinuity.sol", "IStreamEntropyPolicyContinuity"),
  originRelay: full(ei + "IStreamEntropyOriginRelay.sol", "IStreamEntropyOriginRelay"),
  coordinatorContinuity: full(ei + "IStreamEntropyCoordinatorContinuity.sol", "IStreamEntropyCoordinatorContinuity"),
  policy: full(ei + "IStreamEntropyCollectionPolicy.sol", "IStreamEntropyCollectionPolicy"),
  recovery: full(ei + "IStreamEntropyCollectionRecovery.sol", "IStreamEntropyCollectionRecovery"),
  recoveryPolicies: full(ei + "IStreamEntropyRecoveryPolicies.sol", "IStreamEntropyRecoveryPolicies"),
  epochs: full(ei + "IStreamEntropyEpochs.sol", "IStreamEntropyEpochs"),
  reveal: full(ei + "IStreamRevealFeeEscrow.sol", "IStreamRevealFeeEscrow"),
  view: full(ei + "IStreamEntropyView.sol", "IStreamEntropyView"),
  provider: full(ei + "IStreamEntropyProvider.sol", "IStreamEntropyProvider"),
  providerLifecycle: full(ei + "IStreamEntropyProviderLifecycle.sol", "IStreamEntropyProviderLifecycle"),
  instantIdentity: full(ei + "IStreamInstantEntropyProviderIdentity.sol", "IStreamInstantEntropyProviderIdentity"),
  providerCoordinator: {
    source: entropy + "StreamEntropyProviderInstant.sol", contract: "StreamEntropyProviderInstant", capture: "succession",
    methods: ["coordinator"],
  },
  core: full("smart-contracts/core/StreamCore.sol", "StreamCore"),
  modules: full("smart-contracts/domains/modules/StreamModuleRegistry.sol", "StreamModuleRegistry"),
  systemManifest: full(governance + "StreamSystemManifest.sol", "StreamSystemManifest"),
  executor: full(governance + "StreamGovernanceExecutor.sol", "StreamGovernanceExecutor"),
  roleRegistry: full(governance + "StreamRoleRegistry.sol", "StreamRoleRegistry"),
  governanceIdentity: {
    source: governance + "StreamGovernanceBootstrap.sol", contract: "StreamGovernanceBootstrap", capture: "succession",
    methods: ["governanceActionId", "governanceCallsHash", "deriveBatchTransitionHashes", "minimumDelay", "validateActionWindow"],
  },
};
const oracleNames = [
  "StreamEntropyPolicySuccessionPlan", "StreamEntropyFallbackPlan", "StreamCurrentStackPlan",
  "StreamGenesisManifestPlan", "StreamGovernanceCatalogStagePlan", "StreamGovernanceStagePlan",
  "StreamEntropyPolicyInventory", "StreamEntropyPolicyImportState", "StreamEntropyPolicyImport",
  "StreamEntropyPolicyImportValidation", "StreamEntropyPolicyExport", "StreamEntropyPolicyReauthor",
  "StreamEntropyRelayState", "StreamEntropyRelayAdmission", "StreamEntropyOriginRelay",
  "StreamEntropyCollectionConfiguration", "StreamEntropyCollectionPolicy", "StreamEntropyCollectionPolicyState",
  "StreamEntropyCollectionRecovery", "StreamEntropyRecoveryPolicies", "StreamEntropyContinuity",
  "StreamEntropyProviderLifecycle", "StreamEntropyDirectReadEncoding", "StreamEntropyCoordinatorReads",
  "StreamCoreExternalReads", "StreamCoreTypes", "StreamGovernanceTypes", "StreamGovernanceBootstrap",
  "StreamGovernanceScheduling", "StreamGovernanceActionPolicy", "StreamGovernancePolicy",
  "StreamCurrentEntropyPolicySuccessionTest",
];

// Tokenize comments and strings before recognizing import statements. A plain
// quoted import must never be swallowed by a later named `from` import.
export function solidityImports(source) {
  const paths = [];
  let statement = null;
  const tokens = /\/\*[\s\S]*?\*\/|\/\/[^\r\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\bimport\b|;/g;
  for (const match of source.matchAll(tokens)) {
    const token = match[0];
    if (token.startsWith("//") || token.startsWith("/*")) continue;
    if (token === "import") {
      if (statement !== null) throw Error("Unterminated import statement");
      statement = [];
    } else if (token === ";" && statement !== null) {
      if (statement.length !== 1) throw Error("Import must contain exactly one source path");
      paths.push(statement[0]); statement = null;
    } else if (statement !== null && (token.startsWith('"') || token.startsWith("'"))) {
      const path = token.slice(1, -1);
      if (path.includes("\\")) throw Error("Escaped import paths need explicit handling");
      statement.push(path);
    }
  }
  if (statement !== null) throw Error("Unterminated import statement");
  return paths;
}

export function entropyPolicySuccessionFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact retained ABI89 input/output");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2501
      || output.errors?.some(error => error.severity === "error")) throw Error("Invalid frozen succession capture");
  const sourceHashes = {}, sourceTexts = {}, abis = {};
  function visit(path) {
    if (sourceHashes[path]) return;
    const text = input.sources[path]?.content;
    if (typeof text !== "string") throw Error(`Missing retained source ${path}`);
    sourceHashes[path] = sha(text);
    for (const imported of solidityImports(text)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  for (const [key, selection] of Object.entries(selections)) {
    visit(selection.source);
    const all = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(all)) throw Error(`Missing compiled ABI ${key}`);
    abis[key] = selection.full ? all : all.filter(fragment => fragment.type === "function" && selection.methods.includes(fragment.name));
    if (!selection.full && abis[key].length !== selection.methods.length) throw Error(`Missing selected functions ${key}`);
  }
  const oracleSources = oracleNames.map(name => {
    const matches = Object.keys(input.sources).filter(path => path.endsWith(`/${name}.sol`)
      || (name === "StreamCurrentEntropyPolicySuccessionTest" && path === "test/current/StreamCurrentEntropyPolicySuccession.t.sol"));
    if (matches.length !== 1) throw Error(`Expected one source for ${name}, found ${matches.length}`);
    return matches[0];
  });
  for (const path of [...new Set([...Object.values(selections).map(s => s.source), ...oracleSources])].sort()) {
    visit(path); sourceTexts[path] = input.sources[path].content;
  }
  return {
    schemaVersion: 1, profile: "entropy-policy-succession-v1", capture: "parallel-feature-batch89-20260920",
    compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT, sourceTree: "c97f5289867bf1ce1a37ece386831c4201af2af6",
    sourceCount: 2501, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    productionSourceCommit: "393faf78529b1b911db408b26829339371268e29",
    producerFollowupCommit: "5cf63b7b1bc674373404e40e1edeb8d0f9dd4c41",
    planSourceCommit: "3fab88e16549e9c06a339b7ef9a98562c6a9bfea",
    sourceBinding: "All 2501 compiler input literals independently matched the frozen source commit byte-for-byte. Entropy and canonical plan sources preserve the earlier producer/plan semantics; the joined Core includes later Museum anchors.",
    qualification: "ABI/source and mocked client evidence only. Exact canonical class-1 begin/seal/route and class-3 pointer, activation, mandatory manifest-tail plans remain distinct from arbitrary governance batches. Older client profiles stay immutable. No native execution, private candidate-freshness proof, equivalent nested gas admission, full current-stack or release acceptance is established.",
    separateRuntimeEvidence: {
      sourceCommit: "18c42131be84070641d071005b94abfbd73d23cc", tests: 16,
      qualification: "Separately reported actual foundation/Core/Executor/Registry/Manifest/Coordinator/upstream-Safe LEGACY succession run with a test-double provider. Its Core predates this joined source's later Museum anchors. The test-only registration correction, native graph, gas, and runtime evidence are not relabeled to the 7901f3b client profile.",
    },
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-entropy-policy-succession-fixture.mjs INPUT OUTPUT [--check]");
  const rendered = JSON.stringify(entropyPolicySuccessionFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-entropy-policy-succession-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale entropy policy succession fixture");
  } else await writeFile(target, rendered, "utf8");
}
