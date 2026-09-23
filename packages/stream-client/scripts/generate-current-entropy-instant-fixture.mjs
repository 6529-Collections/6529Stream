// Project exact retained INSTANT/direct-static and unchanged governance captures; never compile.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SOURCE_COMMIT = "b4bbd262a77d122d35065a6b7b8b9606323361e5";
const INPUT_SHA = "816f8c9049f617a15d50a36a3c2cb72ef2e9578877edc6131c261642df522e22";
const OUTPUT_SHA = "29694f71f7fdfdc5338da4dd2bee485b14ffde62d70b3136d64d230ef080631e";
const GOVERNANCE_INPUT_SHA = "dc9032a36b5a9d54c9a6f75259ad15057131dede213bbb6a315f2129154c8f13";
const GOVERNANCE_OUTPUT_SHA = "557bfe82dd881dc2f3db2b624219ecdf8d67512f4ed3f4cd5b2215728d97205f";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const entropy = "smart-contracts/domains/entropy/", ei = "smart-contracts/interfaces/stream/entropy/";
const artist = "smart-contracts/domains/artist/", ai = "smart-contracts/interfaces/stream/artist/";
const governance = "smart-contracts/domains/governance/";
const full = (source, contract) => ({ source, contract, full: true, capture: "policy" });
const select = (source, contract, methods, events = [], capture = "policy") => ({ source, contract, methods, events, capture });
const selections = {
  entropy: full(entropy + "StreamEntropyCoordinator.sol", "StreamEntropyCoordinator"),
  instant: full(entropy + "StreamEntropyProviderInstant.sol", "StreamEntropyProviderInstant"),
  instantProvider: full(ei + "IStreamInstantEntropyProvider.sol", "IStreamInstantEntropyProvider"),
  instantIdentity: full(ei + "IStreamInstantEntropyProviderIdentity.sol", "IStreamInstantEntropyProviderIdentity"),
  terminalFacts: full(ei + "IStreamEntropyTerminalFacts.sol", "IStreamEntropyTerminalFacts"),
  view: full(ei + "IStreamEntropyView.sol", "IStreamEntropyView"),
  timing: full(ei + "IStreamEntropyTiming.sol", "IStreamEntropyTiming"),
  continuity: full(ei + "IStreamEntropyCoordinatorContinuity.sol", "IStreamEntropyCoordinatorContinuity"),
  policy: full(ei + "IStreamEntropyCollectionPolicy.sol", "IStreamEntropyCollectionPolicy"),
  recovery: full(ei + "IStreamEntropyCollectionRecovery.sol", "IStreamEntropyCollectionRecovery"),
  recoveryPolicies: full(ei + "IStreamEntropyRecoveryPolicies.sol", "IStreamEntropyRecoveryPolicies"),
  reveal: full(ei + "IStreamRevealFeeEscrow.sol", "IStreamRevealFeeEscrow"),
  epochs: full(ei + "IStreamEntropyEpochs.sol", "IStreamEntropyEpochs"),
  provider: full(ei + "IStreamEntropyProvider.sol", "IStreamEntropyProvider"),
  providerFee: full(ei + "IStreamEntropyProviderFeeQuote.sol", "IStreamEntropyProviderFeeQuote"),
  providerLifecycle: full(ei + "IStreamEntropyProviderLifecycle.sol", "IStreamEntropyProviderLifecycle"),
  core: select("smart-contracts/core/StreamCore.sol", "StreamCore", [
    "getSatellitePointer", "collectionExists", "collectionFreezeStatus", "collectionMintedEver",
    "coordinatorAtMint", "tokenLifecycle", "tokenCollectionIdentity", "tokenData",
  ]),
  modules: full("smart-contracts/interfaces/stream/mint/IStreamMintGovernanceRegistry.sol", "IStreamMintGovernanceRegistry"),
  artist: select(artist + "StreamArtistOnboardingRegistry.sol", "StreamArtistOnboardingRegistry", [
    "core", "operationCoordinator", "mintManager", "supportsInterface", "gasParameterInfo", "artistAuthorizationState",
    "collectionArtistState", "collectionArtistAuthority", "recordContentConsent", "contentConsentDigest",
    "contentConsentEvidenceForHost", "artistRegistryCutover", "storedPayloadCount", "storedPayloadAt", "recordPreimageBytes",
  ], ["ArtistStoredPayload"]),
  artistCoordinator: select(artist + "StreamArtistOnboardingCoordinator.sol", "StreamArtistOnboardingCoordinator", [
    "suiteConfiguration", "configurationHash", "deploymentChainId", "authorityHydrationSuite", "coordinateRecordContentConsent",
  ]),
  owner: full(ai + "IStreamArtistOwner.sol", "IStreamArtistOwner"),
  binding: full(ai + "IStreamArtistBindingOwner.sol", "IStreamArtistBindingOwner"),
  collaboratorBinding: full(ai + "IStreamArtistCollaboratorBindingOwner.sol", "IStreamArtistCollaboratorBindingOwner"),
  collaboratorRecords: full(ai + "IStreamArtistCollaboratorRecordsOwner.sol", "IStreamArtistCollaboratorRecordsOwner"),
  attribution: full(ai + "IStreamArtistAttributionOwner.sol", "IStreamArtistAttributionOwner"),
  identity: select(artist + "StreamArtistIdentityAuthority.sol", "StreamArtistIdentityAuthority", [
    "authorityState", "currentAuthorityCapabilities", "artistAuthorizationState", "nonceUsed", "signatureBundle",
    "ownerStateSnapshotV2", "core", "artistRegistry", "mintManager", "archiveV2", "operationCoordinator", "deploymentChainId", "domainId",
    "storedPayloadCount", "storedPayloadAt", "recordPreimageBytes", "replayCell",
  ]),
  contentIdentity: full(ai + "IStreamArtistContentOwner.sol", "IStreamArtistContentIdentityOwner"),
  contentRecords: full(ai + "IStreamArtistContentOwner.sol", "IStreamArtistContentRecordsOwner"),
  consent: select(artist + "StreamArtistConsentFinalityLifecycle.sol", "StreamArtistConsentFinalityLifecycle", [
    "contentConsentAt", "contentConsentRecord", "ownerStateSnapshotV2", "core", "artistRegistry", "mintManager", "archiveV2",
    "operationCoordinator", "deploymentChainId", "domainId", "storedPayloadCount", "storedPayloadAt", "recordPreimageBytes", "replayCell",
  ], ["ArtistContentConsentRecorded", "ArtistContentRecordContext"]),
  archive: full(artist + "StreamArtistArchiveV2.sol", "StreamArtistArchiveV2"),
  roleRegistry: full("smart-contracts/interfaces/stream/governance/IStreamRoleRegistry.sol", "IStreamRoleRegistry"),
  governanceIdentity: select(governance + "StreamGovernanceBootstrap.sol", "StreamGovernanceBootstrap", [
    "governanceActionId", "governanceCallsHash", "deriveBatchTransitionHashes", "minimumDelay", "validateActionWindow",
  ], [], "governance"),
  executor: select(governance + "StreamGovernanceExecutor.sol", "StreamGovernanceExecutor", [
    "owner", "currentAction", "minimumDelay", "isProposer", "governanceNonce", "governanceRootState", "roleRegistry",
    "scheduleGovernanceBatch", "executeGovernanceBatch", "governanceAction", "governanceActionFacts", "scheduledCallData",
    "scheduledCallDataPointer", "publishedCallData", "publishGovernanceCallData", "governanceActionPolicyState",
    "systemManifestBatchTailRule", "systemManifestBootstrapState", "supportsInterface", "freezeSelectorConfig", "isFreezeSelector",
    "terminalFreezeVetoGuardianSet", "terminalFreezeGuardianConfigCommitment", "terminalFreezeVetoRole", "terminalFreezeLiveActionCaps", "terminalFreezeLiveActionUsage",
  ], ["GovernanceActionScheduled", "GovernanceActionExecuted", "GovernanceActionCancelled", "GovernanceActionVetoed",
    "GovernanceActionExpired", "GovernanceCallDataPublished", "GovernanceActionPolicyValidated", "TerminalFreezeActionMembershipUpdated",
    "TerminalFreezeGuardianConfigCommitted"], "governance"),
};
const oracleSources = [
  entropy + "StreamEntropyCollectionPolicy.sol", entropy + "StreamEntropyCollectionPolicyAuthority.sol",
  entropy + "StreamEntropyCollectionPolicyState.sol", entropy + "StreamEntropyCollectionRecovery.sol",
  entropy + "StreamEntropyCoordinatorReads.sol", entropy + "StreamEntropyRecoveryPolicies.sol",
  entropy + "StreamEntropyCollectionConfiguration.sol", entropy + "StreamEntropyProviderLifecycle.sol",
  entropy + "StreamEntropyAuxiliaryReads.sol", entropy + "StreamEntropyScopeRegistration.sol",
  entropy + "StreamEntropyRequestPlan.sol", entropy + "StreamEntropyFulfillment.sol",
  entropy + "StreamEntropyRequestSubmission.sol", entropy + "StreamEntropySubjectReads.sol",
  entropy + "StreamEntropyInstantProviderReads.sol", entropy + "StreamEntropyIncidentParameters.sol",
  entropy + "StreamEntropyContinuity.sol", entropy + "StreamEntropyTerminalAdmission.sol",
  "smart-contracts/interfaces/stream/core/StreamCoreTypes.sol",
  artist + "StreamArtistContentOperations.sol", artist + "StreamArtistContentHashes.sol",
  artist + "StreamArtistIdentityWriterExtension.sol", artist + "StreamArtistIdentityConsentMutation.sol",
  artist + "StreamArtistIdentityConsentState.sol", artist + "StreamArtistConsentWriterExtension.sol",
  artist + "StreamArtistCurrentAuthorityFacts.sol", artist + "StreamArtistAuthorityPolicy.sol",
  artist + "StreamArtistHashes.sol", ai + "StreamArtistOnboardingTypes.sol", ai + "StreamArtistContentTypes.sol",
  governance + "StreamGovernanceScheduling.sol", governance + "StreamGovernanceActionPolicy.sol", governance + "StreamGovernancePolicy.sol",
];

export function entropyInstantFixture(inputBytes, outputBytes, governanceInputBytes, governanceOutputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen INSTANT/direct-static capture");
  if (sha(governanceInputBytes) !== GOVERNANCE_INPUT_SHA || sha(governanceOutputBytes) !== GOVERNANCE_OUTPUT_SHA) throw Error("Expected exact retained ABI65 governance witness");
  const inputs = { policy: JSON.parse(inputBytes), governance: JSON.parse(governanceInputBytes) };
  const outputs = { policy: JSON.parse(outputBytes), governance: JSON.parse(governanceOutputBytes) };
  for (const [key, count] of [["policy", 1044], ["governance", 2309]]) {
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
  // Record the complete independently source-matched supplemental closure first.
  for (const s of Object.values(selections).filter(s => s.capture === "governance")) visit(s.source, s.capture);
  if (Object.keys(governanceSourceHashes).length !== 35) throw Error("Unexpected supplemental governance closure");
  for (const [key, s] of Object.entries(selections)) {
    visit(s.source, s.capture);
    const all = outputs[s.capture].contracts?.[s.source]?.[s.contract]?.abi;
    if (!Array.isArray(all)) throw Error(`Missing compiled ABI ${key}`);
    const rows = s.full ? all : all.filter(row => row.type === "function" && s.methods.includes(row.name) || row.type === "event" && s.events.includes(row.name));
    if (!s.full) for (const [type, names] of [["function", s.methods], ["event", s.events]]) {
      if (names.some(n => rows.filter(row => row.type === type && row.name === n).length !== 1)) throw Error(`Missing/overloaded ${key} selection`);
    }
    abis[key] = rows;
  }
  for (const path of [...new Set([...Object.values(selections).map(s => s.source), ...oracleSources])].sort()) {
    const capture = inputs.policy.sources[path] ? "policy" : "governance";
    visit(path, capture); sourceTexts[path] = inputs[capture].sources[path].content;
  }
  return {
    schemaVersion: 1, capture: "entropy-instant-static-abi-final-1", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 1044, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    governanceWitness: { capture: "parallel-feature-batch65-20260920", sourceCommit: "ea92b7d41ae9e9eede2a00f2c12b70543f125307", sourceCount: 2309,
      inputSha256: GOVERNANCE_INPUT_SHA, outputSha256: GOVERNANCE_OUTPUT_SHA,
      qualification: "The policy capture omits concrete Executor/Bootstrap. Their complete selected 35-source ABI65 closure independently matches b4bbd262 byte-for-byte. Only these unchanged governance products are projected; no compilation or global fixture refresh.",
      sourceHashes: Object.fromEntries(Object.entries(governanceSourceHashes).sort(([a], [b]) => a.localeCompare(b))) },
    sourceBinding: "All 1044 policy compiler literals and the selected supplemental 35-source governance closure independently verified byte-for-byte against b4bbd262a77d122d35065a6b7b8b9606323361e5.",
    qualification: "Source/ABI and client evidence only. Original Artist17 and class1 configuration/class2 freeze retain their domains. This separate LOW_SECURITY delayed-blockhash INSTANT profile does not change earlier ASYNC evidence. The direct 16-word getter reports actual explicit registered states, not a finality guarantee. No native current-stack, actual Safe, operational gas, finality consumer or release acceptance is established.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))), sourceTexts, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, governanceInput, governanceOutput, mode] = process.argv.slice(2);
  if (!input || !output || !governanceInput || !governanceOutput || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-entropy-instant-fixture.mjs INPUT OUTPUT GOVERNANCE_INPUT GOVERNANCE_OUTPUT [--check]");
  const rendered = JSON.stringify(entropyInstantFixture(await readFile(input), await readFile(output), await readFile(governanceInput), await readFile(governanceOutput)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-entropy-instant-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale entropy INSTANT fixture");
  } else await writeFile(target, rendered, "utf8");
}
