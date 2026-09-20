// Project the frozen Phase Freeze and original governance ABI59 evidence; never compile.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "52e81ac5b4b415a046d96364f344355b308cb36a2d4dc3b34abc0a78e49262e9";
const OUTPUT_SHA = "e49d8e4542b21010193bafbb58dc309ac4e40238ffffe026275bb3f88a16e95b";
const SOURCE_COMMIT = "0ab602042dbbb1f141aea0d9cbb37bd9617345cf";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const mint = "smart-contracts/domains/mint/", governance = "smart-contracts/domains/governance/";
const selections = {
  manager: { source: mint + "StreamMintManager.sol", contract: "StreamMintManager", methods: [
    "core", "mintLedger", "moduleRegistry", "owner", "governanceAuthority", "supportsInterface", "isStreamMintManager",
    "phase", "phaseGate", "counterConfig", "phaseCounterIds", "phaseExecutor", "phaseExecutors", "phasePolicyHash", "phasePolicyGrace",
    "previewPhasePolicyHash", "phaseRoyaltyPolicy", "freezePhase", "phaseFrozen", "phaseFreezeTransitionHashes",
  ], events: ["MintPhaseFrozen"] },
  ledger: { source: mint + "StreamMintLedger.sol", contract: "StreamMintLedger", methods: [
    "owner", "supportsInterface", "isStreamMintLedger", "ledgerWriter", "ledgerWriterRetiredAt", "registeredPhasePolicyHash",
    "registeredCounterPolicy", "policyGrace", "counterDefinitionForManager", "mintImportCommitment", "mintImportDefinitionProgress",
    "mintImportAncestryProgress", "isMintSuccessorReady", "isCompletedMintDescendant", "freezePhase", "phaseFreeze", "frozenPhaseCount",
    "frozenPhaseAt", "frozenPhaseExecutors", "importPhaseFreezes", "mintImportFreezeProgress",
  ], events: ["MintLedgerPhaseFrozen", "MintLedgerPhaseFreezeImported", "MintLedgerImportCompleted"] },
  core: { source: "smart-contracts/core/StreamCore.sol", contract: "StreamCore", methods: ["collectionExists", "getSatellitePointer"] },
  registry: { source: "smart-contracts/domains/modules/StreamModuleRegistry.sol", contract: "StreamModuleRegistry", methods: ["governanceExecutor", "supportsInterface"] },
  executor: { source: governance + "StreamGovernanceExecutor.sol", contract: "StreamGovernanceExecutor", methods: [
    "owner", "currentAction", "minimumDelay", "isProposer", "governanceNonce", "governanceRootState", "roleRegistry",
    "scheduleGovernanceBatch", "executeGovernanceBatch", "governanceAction", "governanceActionFacts", "scheduledCallData",
    "scheduledCallDataPointer", "publishedCallData", "publishGovernanceCallData", "governanceActionPolicyState",
    "systemManifestBatchTailRule", "systemManifestBootstrapState", "supportsInterface", "freezeSelectorConfig", "registerFreezeSelector", "isFreezeSelector",
    "terminalFreezeVetoGuardianSet", "terminalFreezeGuardianConfigCommitment", "terminalFreezeVetoRole", "terminalFreezeLiveActionCaps", "terminalFreezeLiveActionUsage",
  ], events: ["GovernanceActionScheduled", "GovernanceActionExecuted", "GovernanceActionCancelled", "GovernanceActionVetoed",
    "GovernanceActionExpired", "GovernanceCallDataPublished", "GovernanceActionPolicyValidated", "FreezeSelectorUpdated",
    "TerminalFreezeGuardianConfigCommitted", "TerminalFreezeActionMembershipUpdated"] },
  freezeInterface: { source: "smart-contracts/interfaces/stream/mint/IStreamMintPhaseFreeze.sol", contract: "IStreamMintPhaseFreeze", full: true },
  ledgerFreezeInterface: { source: "smart-contracts/interfaces/stream/mint/IStreamMintLedgerPhaseFreeze.sol", contract: "IStreamMintLedgerPhaseFreeze", full: true },
  counterPolicyInterface: { source: "smart-contracts/interfaces/stream/mint/IStreamMintCounterPolicy.sol", contract: "IStreamMintCounterPolicy", full: true },
  royaltyInterface: { source: "smart-contracts/interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol", contract: "IStreamMintRoyaltyPolicy", full: true },
  roleRegistry: { source: "smart-contracts/interfaces/stream/governance/IStreamRoleRegistry.sol", contract: "IStreamRoleRegistry", full: true },
};
const oracleSources = [
  mint + "StreamMintPhaseFreezeControl.sol", mint + "StreamMintPhaseFreezeState.sol",
  mint + "StreamMintManager.sol", mint + "StreamMintLedger.sol", mint + "StreamMintImport.sol",
  mint + "StreamMintOperationIdentity.sol", mint + "StreamMintPhaseState.sol", mint + "StreamMintRoyaltyPolicy.sol",
  governance + "StreamGovernanceBootstrap.sol", governance + "StreamGovernanceScheduling.sol",
  governance + "StreamGovernanceActionPolicy.sol", governance + "StreamGovernanceExecutor.sol", governance + "StreamGovernancePolicy.sol",
  "script/current/StreamMintPhaseFreezePlan.sol",
];

export function mintPhaseFreezeFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen Phase Freeze ABI59 capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2269
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 2269-source capture");
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
  for (const [key, selected] of Object.entries(selections)) {
    visit(selected.source);
    const full = output.contracts?.[selected.source]?.[selected.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing compiled ABI ${key}`);
    const abi = selected.full ? full : full.filter(row => (row.type === "function" && selected.methods.includes(row.name))
      || (row.type === "event" && (selected.events ?? []).includes(row.name)));
    if (!selected.full) for (const [type, names] of [["function", selected.methods], ["event", selected.events ?? []]]) {
      if (names.some(name => abi.filter(row => row.type === type && row.name === name).length !== 1)) throw Error(`Incomplete or overloaded ABI ${key}`);
    }
    abis[key] = abi;
  }
  for (const path of oracleSources) { visit(path); sourceTexts[path] = input.sources[path].content; }
  return {
    schemaVersion: 1, capture: "parallel-feature-batch59-20260920", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 2269, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 2269 literal input sources independently verified byte-for-byte against this Git commit. Selected production closure hashes and original freeze, import and governance recipes follow.",
    qualification: "Frozen source and ABI evidence only; client tests do not establish native current-stack, actual Safe, gas, genesis or release acceptance.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-mint-phase-freeze-fixture.mjs INPUT OUTPUT [--check]");
  const rendered = JSON.stringify(mintPhaseFreezeFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-mint-phase-freeze-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale current Mint Phase Freeze fixture");
  } else await writeFile(target, rendered, "utf8");
}
