// Exact ABI projection from the retained fallback compiler capture; never compile.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "d92d75ef82e9b645b0df856a110bb49f6d52134a2bf42d4c811391a6341586f7";
const OUTPUT_SHA = "110472bc5e57b6cea4351ce27daf1d081a9bbb802d763cf0daa2b4f05a61b356";
const SOURCE_COMMIT = "d1a58e4403cfbb80d921e117e0a7ac9b90ff61c7";
const sha = value => createHash("sha256").update(value).digest("hex");
const managerMethods = ["isStreamMintManager", "supportsInterface", "core", "mintLedger", "moduleRegistry", "owner",
  "governanceAuthority", "gasParameterInfo", "preparedNativeRecorder", "bindPreparedNativeRecorder", "importMintState"];
const selections = {
  core: { source: "smart-contracts/core/StreamCore.sol", contract: "StreamCore", methods: ["getSatellitePointer", "updateSatellitePointer",
    "pendingPreparedMintTokenId", "preparedMint", "tokenCollectionIdentity", "tokenLifecycle", "tokenData", "coordinatorAtMint",
    "lastAllocatedTokenId", "collectionNextSerial", "collectionMintedEver", "totalSupply"], events: ["CoreSatellitePointerUpdated", "TokenCollectionRegistrationReverted"] },
  ledger: { source: "smart-contracts/domains/mint/StreamMintLedger.sol", contract: "StreamMintLedger", methods: ["isStreamMintLedger", "owner",
    "ledgerWriter", "ledgerWriterRetiredAt", "retireLedgerWriter", "commitCounterImportRoot", "importCounterDefinitions", "importMintAncestors",
    "completeCounterImport", "mintImportCommitment", "mintImportDefinitionProgress", "mintImportAncestryProgress", "isMintSuccessorReady",
    "isCompletedMintDescendant", "managerDefinitionCount", "managerDefinitionAt", "mintAncestorCount", "mintAncestorAt",
    "counterDefinitionForManager", "deriveCounterValueKey", "counterValue", "isManagerNullifierUsed"],
    events: ["MintLedgerWriterRetired", "MintLedgerImportRootCommitted", "MintLedgerImportCompleted", "MintLedgerImportProfileCopied",
      "MintLedgerCounterImported", "MintLedgerNullifierImported", "MintLedgerAncestorImported"] },
  manager: { source: "smart-contracts/domains/mint/StreamMintManager.sol", contract: "StreamMintManager", methods: managerMethods, events: ["PreparedNativeRecorderBound"] },
  fallback: { source: "smart-contracts/domains/mint/StreamMintManagerFallback.sol", contract: "StreamMintManagerFallback",
    methods: [...managerMethods, "recoverPreparedMint"], events: ["PreparedNativeRecorderBound", "MintFallbackPreparedRecovered"] },
  registry: { source: "smart-contracts/domains/modules/StreamModuleRegistry.sol", contract: "StreamModuleRegistry",
    methods: ["governanceExecutor", "moduleRecord", "isModuleEligible", "registerModule", "setModuleStatus", "registrationChainHash", "moduleCount"],
    events: ["StreamModuleRegistered", "StreamModuleStatusChanged"] },
  executor: { source: "smart-contracts/domains/governance/StreamGovernanceExecutor.sol", contract: "StreamGovernanceExecutor",
    methods: ["owner", "tighteningCallConfig", "setTighteningCall", "currentAction", "minimumDelay", "isProposer", "governanceNonce",
      "scheduleGovernanceBatch", "executeGovernanceBatch", "scheduleGovernanceAction", "executeGovernanceAction", "governanceAction",
      "governanceActionFacts", "scheduledCallData", "scheduledCallDataPointer", "publishedCallData", "publishGovernanceCallData",
      "governanceActionPolicyState", "systemManifestBatchTailRule", "systemManifestBootstrapState"],
    events: ["TighteningCallUpdated", "GovernanceActionScheduled", "GovernanceActionExecuted", "GovernanceActionCancelled",
      "GovernanceActionVetoed", "GovernanceActionExpired", "GovernanceCallDataPublished", "GovernanceActionPolicyValidated"] },
  manifest: { source: "smart-contracts/domains/governance/StreamSystemManifest.sol", contract: "StreamSystemManifest",
    methods: ["core", "governanceExecutor", "streamSystemManifest", "streamSystemManifestPointer", "publishStreamSystemManifest"], events: ["StreamSystemManifestPublished"] },
  recovery: { source: "smart-contracts/domains/mint/StreamMintFallbackRecovery.sol", contract: "StreamMintFallbackRecovery",
    methods: ["transition"], events: ["MintFallbackPreparedRecovered"] },
  recorder: { source: "smart-contracts/interfaces/stream/revenue/IStreamPrimarySettlementBindings.sol", contract: "IStreamPrimarySettlementBindings",
    methods: ["core", "moduleRegistry"], events: [] },
  erc165: { source: "smart-contracts/vendor/openzeppelin/IERC165.sol", contract: "IERC165", full: true },
  managerInterface: { source: "smart-contracts/interfaces/stream/mint/IStreamMintManager.sol", contract: "IStreamMintManager", full: true },
  ledgerInterface: { source: "smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol", contract: "IStreamMintLedger", full: true },
  recorderInterface: { source: "smart-contracts/interfaces/stream/revenue/IStreamPreparedNativePrimarySaleSettlement.sol", contract: "IStreamPreparedNativePrimarySaleSettlement", full: true },
  recoveryInterface: { source: "smart-contracts/interfaces/stream/mint/IStreamMintFallbackRecovery.sol", contract: "IStreamMintFallbackRecovery", full: true },
};

export function mintFallbackFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen fallback compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 988
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 988-source capture");
  const sources = Object.fromEntries(Object.entries(input.sources).sort(([a], [b]) => a.localeCompare(b)).map(([path, source]) => {
    if (typeof source.content !== "string") throw Error(`Missing literal source ${path}`);
    return [path, sha(source.content)];
  }));
  const abis = {};
  for (const [key, selection] of Object.entries(selections)) {
    const full = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing ABI ${key}`);
    const abi = selection.full ? full : full.filter(item => (item.type === "function" && selection.methods.includes(item.name))
      || (item.type === "event" && selection.events.includes(item.name)));
    if (!selection.full) {
      for (const [type, names] of [["function", selection.methods], ["event", selection.events]]) {
        if (names.some(name => abi.filter(item => item.type === type && item.name === name).length !== 1)) throw Error(`Missing/ambiguous ABI ${key}`);
      }
      if (abi.length !== selection.methods.length + selection.events.length) throw Error(`Incomplete ABI ${key}`);
    }
    abis[key] = abi;
  }
  return { schemaVersion: 1, capture: "fallback-final-joint-abi", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 988, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 988 literal input sources independently verified byte-for-byte against this Git commit.",
    qualification: "Frozen source and ABI evidence only; client tests do not establish actual current-stack, Safe, gas, genesis or release acceptance.",
    sources, selections, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-mint-fallback-fixture.mjs INPUT OUTPUT [--check]");
  const canonical = JSON.stringify(mintFallbackFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-mint-fallback-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== canonical) throw Error("Stale fallback ABI fixture");
  } else await writeFile(target, canonical, "utf8");
}
