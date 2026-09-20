// Additive mode2 source projection from retained ABI56; preserve the separate ABI52 generator/fixture.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "6aec6f59bb3037d83ee9a3bc2a3a1552bfac224c4b8cbf7bbe9ec79ce6c253c7";
const OUTPUT_SHA = "7423844d40d9ee2982473692bee53bb482f578a90e90e340f95d06469cbe3aaf";
const SOURCE_COMMIT = "ed4d557246a98698167d6986bc4266d9e375d558";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const mint = "smart-contracts/domains/mint/", governance = "smart-contracts/domains/governance/";
const selections = {
  manager: { source: mint + "StreamMintManager.sol", contract: "StreamMintManager", methods: [
    "core", "mintLedger", "moduleRegistry", "owner", "governanceAuthority", "supportsInterface", "gasParameterInfo", "isStreamMintManager",
    "phase", "phaseGate", "counterConfig", "phaseCounterIds", "phaseExecutor", "phasePolicyHash", "phasePolicyGrace",
    "previewPhasePolicyHash", "setPhaseExecutorWithGrace", "setPhaseExecutor", "hasRegisteredPhasePolicy",
  ], events: ["MintPhaseConsentRecorded", "MintPhaseExecutorUpdated"] },
  ledger: { source: mint + "StreamMintLedger.sol", contract: "StreamMintLedger", methods: [
    "registeredPhasePolicyHash", "policyGrace", "ledgerWriter", "ledgerWriterRetiredAt", "owner", "isStreamMintLedger",
    "registeredCounterPolicy", "isCompletedMintDescendant", "supportsInterface",
  ], events: ["MintLedgerPhasePolicyRegistered", "MintLedgerPolicyGraceSet", "MintLedgerCounterPolicyRegistered"] },
  core: { source: "smart-contracts/core/StreamCore.sol", contract: "StreamCore", methods: ["collectionExists", "getSatellitePointer"] },
  artist: { source: "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol", contract: "StreamArtistOnboardingRegistry", methods: [
    "core", "mintManager", "supportsInterface", "consentMode", "isPolicyConsented", "platformWorksDeclaration", "requireMintConsent",
  ] },
  registry: { source: "smart-contracts/domains/modules/StreamModuleRegistry.sol", contract: "StreamModuleRegistry", methods: ["governanceExecutor", "supportsInterface"] },
  executor: { source: governance + "StreamGovernanceExecutor.sol", contract: "StreamGovernanceExecutor", methods: [
    "owner", "currentAction", "minimumDelay", "isProposer", "governanceNonce", "governanceRootState", "roleRegistry",
    "scheduleGovernanceBatch", "executeGovernanceBatch", "governanceAction", "governanceActionFacts", "scheduledCallData",
    "scheduledCallDataPointer", "publishedCallData", "publishGovernanceCallData", "governanceActionPolicyState",
    "systemManifestBatchTailRule", "systemManifestBootstrapState", "supportsInterface",
  ], events: ["GovernanceActionScheduled", "GovernanceActionExecuted", "GovernanceActionCancelled", "GovernanceActionVetoed",
    "GovernanceActionExpired", "GovernanceCallDataPublished", "GovernanceActionPolicyValidated"] },
  graceInterface: { source: "smart-contracts/interfaces/stream/mint/IStreamMintPolicyGrace.sol", contract: "IStreamMintPolicyGrace", full: true },
  managerInterface: { source: "smart-contracts/interfaces/stream/mint/IStreamMintManager.sol", contract: "IStreamMintManager", full: true },
  ledgerInterface: { source: "smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol", contract: "IStreamMintLedger", full: true },
  artistInterface: { source: "smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol", contract: "IStreamArtistMintConsent", full: true },
  platformInterface: { source: "smart-contracts/interfaces/stream/artist/IStreamArtistPlatformWorks.sol", contract: "IStreamArtistPlatformWorks", full: true },
};
const oracleSources = [
  mint + "StreamMintManagerPolicy.sol", mint + "StreamMintManagerViews.sol", mint + "StreamMintManagerAccounting.sol",
  "smart-contracts/domains/artist/StreamArtistOnboardingReads.sol",
  "smart-contracts/domains/artist/StreamArtistConsentReadEncoding.sol",
  mint + "StreamMintOperationIdentity.sol", mint + "StreamMintManager.sol", mint + "StreamMintLedger.sol",
  mint + "StreamMintPhaseState.sol", mint + "StreamMintArtistConsent.sol",
  governance + "StreamGovernanceBootstrap.sol", governance + "StreamGovernanceScheduling.sol",
  governance + "StreamGovernanceActionPolicy.sol", governance + "StreamGovernanceExecutor.sol",
  "script/current/StreamCurrentStackDeployment.sol",
];

export function mintPolicyGraceMode2Fixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen Mint grace ABI56 capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2241
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 2241-source capture");
  const sourceHashes = {}, sourceTexts = {}, abis = {};
  function visit(path) {
    if (Object.hasOwn(sourceHashes, path)) return;
    const literal = input.sources[path]?.content;
    if (typeof literal !== "string") throw Error(`Missing literal source ${path}`);
    sourceHashes[path] = sha(literal);
    for (const match of literal.matchAll(/import\s+(?:[\s\S]*?\s+from\s+)?["']([^"']+)["']\s*;/g)) {
      visit(match[1].startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), match[1])) : match[1]);
    }
  }
  for (const [key, selection] of Object.entries(selections)) {
    visit(selection.source);
    const full = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing compiled ABI ${key}`);
    const abi = selection.full ? full : full.filter(row => (row.type === "function" && selection.methods.includes(row.name))
      || (row.type === "event" && (selection.events ?? []).includes(row.name)));
    if (!selection.full) {
      for (const [type, names] of [["function", selection.methods], ["event", selection.events ?? []]]) {
        if (names.some(name => abi.filter(row => row.type === type && row.name === name).length !== 1)) throw Error(`Incomplete or overloaded ABI ${key}`);
      }
    }
    abis[key] = abi;
  }
  for (const path of oracleSources) { visit(path); sourceTexts[path] = input.sources[path].content; }
  return {
    schemaVersion: 1, capture: "parallel-feature-batch56-20260920", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 2241, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 2241 literal input sources independently verified byte-for-byte against this Git commit. Closure hashes and original policy/governance source texts follow.",
    qualification: "Frozen source and ABI evidence only; client tests do not establish native current-stack, actual Safe, gas, genesis or release acceptance.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-mint-policy-grace-mode2-fixture.mjs INPUT OUTPUT [--check]");
  const rendered = JSON.stringify(mintPolicyGraceMode2Fixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-mint-policy-grace-mode2-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale current Mint policy grace fixture");
  } else await writeFile(target, rendered, "utf8");
}
