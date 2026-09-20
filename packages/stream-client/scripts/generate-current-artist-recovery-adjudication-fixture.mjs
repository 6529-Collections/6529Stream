// Project immutable retained compiler evidence. This script never invokes a compiler.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SOURCE_COMMIT = "3ac39b556f17e938c5de2b7401429a2f8903ceb3";
const INPUT_SHA = "b2a677a4ce978bf20e3eb23ab846fda6f19a1d25626ac58a80384036f3b75844";
const OUTPUT_SHA = "bb9700c66af859c912d321acfc1310274134912b883dae0b50b29a43110ecdf9";
const GOVERNANCE_INPUT_SHA = "dc9032a36b5a9d54c9a6f75259ad15057131dede213bbb6a315f2129154c8f13";
const GOVERNANCE_OUTPUT_SHA = "557bfe82dd881dc2f3db2b624219ecdf8d67512f4ed3f4cd5b2215728d97205f";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const artist = "smart-contracts/domains/artist/", ai = "smart-contracts/interfaces/stream/artist/";
const governance = "smart-contracts/domains/governance/";
const full = (source, contract, capture = "adjudication") => ({ source, contract, capture });
const selections = {
  registry: full(artist + "StreamArtistOnboardingRegistry.sol", "StreamArtistOnboardingRegistry"),
  coordinator: full(artist + "StreamArtistOnboardingCoordinator.sol", "StreamArtistOnboardingCoordinator"),
  identity: full(artist + "StreamArtistIdentityAuthority.sol", "StreamArtistIdentityAuthority"),
  evidence: full(artist + "StreamArtistRecoveryEvidence.sol", "StreamArtistRecoveryEvidence"),
  selection: full(artist + "StreamArtistRecoverySelectionPreparation.sol", "StreamArtistRecoverySelectionPreparation"),
  archive: full(artist + "StreamArtistArchiveV2.sol", "StreamArtistArchiveV2"),
  owner: full(ai + "IStreamArtistOwner.sol", "IStreamArtistOwner"),
  recoveryV2: full(ai + "IStreamArtistIdentityRecoveryV2.sol", "IStreamArtistIdentityRecoveryV2"),
  recoveryOwnerV2: full(ai + "IStreamArtistIdentityRecoveryV2.sol", "IStreamArtistIdentityRecoveryOwnerV2"),
  recoveryCoordinatorV2: full(ai + "IStreamArtistIdentityRecoveryV2.sol", "IStreamArtistIdentityRecoveryCoordinatorV2"),
  evidenceInterface: full(ai + "IStreamArtistRecoveryEvidence.sol", "IStreamArtistRecoveryEvidence"),
  evidenceBinding: full(ai + "IStreamArtistRecoveryEvidence.sol", "IStreamArtistRecoveryEvidenceBinding"),
  selectionInterface: full(ai + "IStreamArtistRecoverySelectionPreparation.sol", "IStreamArtistRecoverySelectionPreparation"),
  selectionBinding: full(ai + "IStreamArtistRecoverySelectionPreparation.sol", "IStreamArtistRecoverySelectionBinding"),
  selectionOwner: full(ai + "IStreamArtistRecoverySelectionPreparation.sol", "IStreamArtistRecoverySelectionOwnerV2"),
  recovery: full(ai + "IStreamArtistIdentityRecovery.sol", "IStreamArtistIdentityRecovery"),
  recoveryOwner: full(ai + "IStreamArtistIdentityRecovery.sol", "IStreamArtistIdentityRecoveryOwner"),
  recoveryEvents: full(ai + "IStreamArtistIdentityRecovery.sol", "IStreamArtistIdentityRecoveryEvents"),
  action: full(ai + "IStreamArtistRecoveryAction.sol", "IStreamArtistRecoveryAction"),
  actionOwner: full(ai + "IStreamArtistRecoveryAction.sol", "IStreamArtistRecoveryActionOwner"),
  actionEvents: full(ai + "IStreamArtistRecoveryAction.sol", "IStreamArtistRecoveryActionEvents"),
  guardianHistory: full(ai + "IStreamArtistGuardianHistory.sol", "IStreamArtistGuardianHistory"),
  guardianSelection: full(ai + "IStreamArtistGuardianSelectionPreparation.sol", "IStreamArtistGuardianSelectionOwner"),
  guardianVesting: full(ai + "IStreamArtistGuardianVestingHistory.sol", "IStreamArtistGuardianVestingHistory"),
  guardianSupersession: full(ai + "IStreamArtistGuardianSupersession.sol", "IStreamArtistGuardianSupersession"),
  contest: full(ai + "IStreamArtistIdentityContest.sol", "IStreamArtistIdentityContestOwner"),
  dormancy: full(ai + "IStreamArtistDormancy.sol", "IStreamArtistDormancyOwner"),
  dormancyEvidence: full(ai + "IStreamArtistDormancy.sol", "IStreamArtistDormancyEvidence"),
  dormancyEvents: full(ai + "IStreamArtistDormancy.sol", "IStreamArtistDormancyEvents"),
  dormancyReconstruction: full(ai + "IStreamArtistDormancyReconstructionEvents.sol", "IStreamArtistDormancyReconstructionEvents"),
  rotation: full(ai + "IStreamArtistRotation.sol", "IStreamArtistRotationReads"),
  roleRegistry: full(governance + "StreamRoleRegistry.sol", "StreamRoleRegistry"),
  modules: full("smart-contracts/domains/modules/StreamModuleRegistry.sol", "StreamModuleRegistry"),
  core: full("smart-contracts/interfaces/stream/core/IStreamCore.sol", "IStreamCore"),
  governanceIdentity: full(governance + "StreamGovernanceBootstrap.sol", "StreamGovernanceBootstrap", "governance"),
  executor: full(governance + "StreamGovernanceExecutor.sol", "StreamGovernanceExecutor", "governance"),
};
const oracleSources = [
  "StreamArtistRecoveryAdjudicationOperations", "StreamArtistRecoveryAdjudicationContext", "StreamArtistRecoveryAdjudicationHistory",
  "StreamArtistRecoveryAdjudicationMutation", "StreamArtistRecoveryAdjudicationState", "StreamArtistRecoveryAdjudicationGuardians",
  "StreamArtistRecoveryAdjudicationReads", "StreamArtistRecoveryAdjudicationVeto", "StreamArtistCurrentNoticeRecoveryReads",
  "StreamArtistCurrentCompromiseReads", "StreamArtistDormancyNoticeHistory", "StreamArtistIdentityActivityMutation", "StreamArtistIdentityActivity",
  "StreamArtistRecoveryEvidenceReads", "StreamArtistRecoveryActionReads", "StreamArtistRecoveryActionOperations",
  "StreamArtistIdentityRecoveryGovernance", "StreamArtistGuardianAppealGovernance", "StreamArtistGuardianAppealAuthority",
  "StreamArtistIdentityRecoveryMutation", "StreamArtistIdentityRecoveryState", "StreamArtistRotationHashes",
  "StreamArtistIdentityAdjudicationExtension", "StreamArtistNativeReceipts", "StreamArtistRecoveryFamilyHistory",
  "StreamArtistHashes", "StreamArtistRecoveryFamilyAncestry",
].map(n => artist + n + ".sol").concat([
  "StreamArtistRecoveryEvidenceTypes", "StreamArtistRecoverySelectionTypesV2", "StreamArtistGuardianAppealTypes",
  "StreamArtistGuardianHistoryTypes", "StreamArtistGuardianSelectionTypes", "StreamArtistGuardianVestingTypes",
  "StreamArtistIdentityRecoveryOperationTypes", "StreamArtistIdentityRecoveryTypes", "StreamArtistRecoveryActionTypes",
  "StreamArtistIdentityContestTypes", "StreamArtistRotationTypes", "StreamArtistOnboardingTypes", "StreamArtistSuccessionTypes",
].map(n => ai + n + ".sol"), [governance + "StreamGovernanceActionPolicy.sol", governance + "StreamGovernancePolicy.sol"]);

export function artistRecoveryAdjudicationFixture(inputBytes, outputBytes, governanceInputBytes, governanceOutputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen current-notice capture");
  if (sha(governanceInputBytes) !== GOVERNANCE_INPUT_SHA || sha(governanceOutputBytes) !== GOVERNANCE_OUTPUT_SHA) throw Error("Expected exact retained ABI65 governance witness");
  const inputs = { adjudication: JSON.parse(inputBytes), governance: JSON.parse(governanceInputBytes) };
  const outputs = { adjudication: JSON.parse(outputBytes), governance: JSON.parse(governanceOutputBytes) };
  for (const [key, count] of [["adjudication", 931], ["governance", 2309]]) {
    if (inputs[key].language !== "Solidity" || Object.keys(inputs[key].sources ?? {}).length !== count || outputs[key].errors?.some(e => e.severity === "error")) throw Error(`Invalid ${key} capture`);
  }
  const sourceHashes = {}, sourceTexts = {}, abis = {}, governanceSourceHashes = {};
  function visit(path, capture) {
    const text = inputs[capture].sources[path]?.content;
    if (typeof text !== "string") throw Error(`Missing ${capture} source ${path}`);
    const hash = sha(text);
    if (sourceHashes[path] && sourceHashes[path] !== hash) throw Error(`Conflicting source provenance ${path}`);
    if (capture === "governance") governanceSourceHashes[path] = hash;
    if (sourceHashes[path]) return;
    sourceHashes[path] = hash;
    for (const match of text.matchAll(/import\s+(?:[\s\S]*?\s+from\s+)?["']([^"']+)["']\s*;/g)) {
      visit(match[1].startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), match[1])) : match[1], capture);
    }
  }
  for (const s of Object.values(selections).filter(s => s.capture === "governance")) visit(s.source, s.capture);
  if (Object.keys(governanceSourceHashes).length !== 35) throw Error("Unexpected supplemental governance closure");
  for (const [key, s] of Object.entries(selections)) {
    visit(s.source, s.capture);
    const all = outputs[s.capture].contracts?.[s.source]?.[s.contract]?.abi;
    if (!Array.isArray(all)) throw Error(`Missing compiled ABI ${key}`);
    abis[key] = all;
  }
  for (const path of [...new Set([...Object.values(selections).map(s => s.source), ...oracleSources])].sort()) {
    const capture = inputs.adjudication.sources[path] ? "adjudication" : "governance";
    visit(path, capture); sourceTexts[path] = inputs[capture].sources[path].content;
  }
  return {
    schemaVersion: 1, capture: "capture-current-notice-final", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    adjudicationBaseCommit: "674b96f93edafb60d652fc02e0e270f4434377da", sourceCount: 931,
    inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    governanceWitness: { capture: "parallel-feature-batch65-20260920", sourceCommit: "ea92b7d41ae9e9eede2a00f2c12b70543f125307", sourceCount: 2309,
      inputSha256: GOVERNANCE_INPUT_SHA, outputSha256: GOVERNANCE_OUTPUT_SHA,
      qualification: "The current-notice capture omits concrete Executor/Bootstrap. Their selected complete 35-source ABI65 closure independently matches the frozen 3ac39b55 producer byte-for-byte. Only those two unchanged governance products are projected.",
      sourceHashes: Object.fromEntries(Object.entries(governanceSourceHashes).sort(([a], [b]) => a.localeCompare(b))) },
    sourceBinding: "All 931 primary compiler literals and the supplemental 35-source governance closure independently verified byte-for-byte against 3ac39b556f17e938c5de2b7401429a2f8903ceb3.",
    qualification: "Compiler ABI/source and client evidence only. Original operation35 request, signature and semantic records remain distinct from V2 manifest/context and current-notice Archive wrappers. No V3 rewinds, full hydration, native current-stack, actual Safe composition, gas or release acceptance is established.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))), sourceTexts, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, governanceInput, governanceOutput, mode] = process.argv.slice(2);
  if (!input || !output || !governanceInput || !governanceOutput || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-artist-recovery-adjudication-fixture.mjs INPUT OUTPUT GOVERNANCE_INPUT GOVERNANCE_OUTPUT [--check]");
  const rendered = JSON.stringify(artistRecoveryAdjudicationFixture(await readFile(input), await readFile(output), await readFile(governanceInput), await readFile(governanceOutput)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-artist-recovery-adjudication-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale Artist recovery adjudication fixture");
  } else await writeFile(target, rendered, "utf8");
}
