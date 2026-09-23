// Project original Artist public calls and proof reads from retained ABI52; never compile Solidity.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Interface } from "ethers";

const INPUT_SHA = "94d4a931f6f2f1849e9d91506e6ac9c39d10982cc61d06c7fc2f4b35c17f0fde";
const OUTPUT_SHA = "d299875f9ae1f03e1361dfba0795b908b4d0b45a480fe4e47deab5f78c173905";
const SOURCE_COMMIT = "44af244ed576cc4b26632b800fe70a068d577940";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const base = "smart-contracts/domains/artist/";
const sharedOwner = ["artistRegistry", "operationCoordinator", "archiveV2", "core", "mintManager", "deploymentChainId", "domainId", "ownerStateSnapshotV2"];
const selections = {
  registry: { source: base + "StreamArtistOnboardingRegistry.sol", contract: "StreamArtistOnboardingRegistry", methods: [
    "refuseArtistBinding", "recordSaleConsent", "authorizeArtistRoyaltyFreeze", "authorizeArtistContentFreeze", "revokeArtistAuthorization",
    "bindingRefusalDigest", "saleConsentDigest", "royaltyFreezeDigest", "contentFreezeDigest", "authorizationRevocationDigest",
    "core", "mintManager", "operationCoordinator", "currentAuthorityCapabilities", "artistRegistryCutover", "gasParameterInfo",
    "artistAuthorizationState", "bindingTermination", "saleConsentRecord", "contentFreezeAuthorization", "isRoyaltyFreezeAuthorized",
    "recordIdentityRevision", "grantArtistDelegation", "revokeArtistDelegation", "identityRevisionDigest", "delegationGrantDigest", "delegationRevocationDigest",
    "operativeIdentityRecord", "identityRecordBytes", "identityDocumentBytes", "artistDisplayName", "identityRevisionRecord",
    "identityRevisionProvisionalAssociation", "delegationRecord", "delegationState", "delegatedNonceState", "recordDelegation",
    "operativeEstateDirective", "estateDirectiveRecord", "activeAuthorityWindow",
    "recordDelegatedPolicyConsent", "recordDelegatedSaleConsent", "policyConsentDigest",
    "isPolicyConsented", "requireMintConsent", "requireSaleConsent",
    "recordDelegatedEconomicsConsent", "recordDelegatedProspectiveEconomicsConsent", "authorizeDelegatedRoyaltyFreeze",
    "economicsConsentDigest", "artistPayoutAccount", "requireEconomicsConsent",
  ] },
  coordinator: { source: base + "StreamArtistOnboardingCoordinator.sol", contract: "StreamArtistOnboardingCoordinator",
    methods: ["suiteConfiguration", "deploymentChainId", "configurationHash", "reads"] },
  reads: { source: base + "StreamArtistOnboardingReads.sol", contract: "StreamArtistOnboardingReads", methods: [
    "acceptedBinding", "defensiveBinding", "artistPayoutAccount", "requireCurrentEconomics",
    "requireProspectiveEconomicsWithEvidence", "requireRoyaltyFreezeProposal",
  ] },
  owner: { source: base + "StreamArtistOwner.sol", contract: "StreamArtistOwner", methods: sharedOwner },
  identity: { source: base + "StreamArtistIdentityAuthority.sol", contract: "StreamArtistIdentityAuthority",
    methods: ["authorityState", "artistAuthorizationState", "currentAuthorityCapabilities", "delegationEpochState", "signatureBundle", "replayCell",
      "identity", "operativeIdentityRecord", "identityRecordBytes", "identityDocumentBytes", "artistDisplayName", "identityRevisionRecord",
      "identityRevisionProvisionalAssociation", "delegationRecord", "activeAuthorityWindow"],
    events: ["ArtistAuthorizationRevoked", "ArtistIdentityRevisionRecorded", "ArtistIdentityDisplayNameStored", "ArtistDelegationGranted", "ArtistDelegationRevoked"] },
  binding: { source: base + "StreamArtistBindingLifecycle.sol", contract: "StreamArtistBindingLifecycle", methods: ["binding", "bindingTerms", "bindingTermination"] },
  attribution: { source: base + "StreamArtistAttributionLifecycle.sol", contract: "StreamArtistAttributionLifecycle",
    methods: ["attributionState"], events: ["ArtistAttributionStateChanged", "ArtistBindingTerminationContext"] },
  collaborator: { source: base + "StreamArtistCollaboratorLifecycle.sol", contract: "StreamArtistCollaboratorLifecycle", methods: ["acceptedCount"] },
  payout: { source: base + "StreamArtistPayoutLifecycle.sol", contract: "StreamArtistPayoutLifecycle", methods: ["designationRecord"] },
  consent: { source: base + "StreamArtistConsentFinalityLifecycle.sol", contract: "StreamArtistConsentFinalityLifecycle",
    methods: ["saleConsentRecord", "saleConsentAt", "royaltyFreezeRecord", "contentFreezeRecord", "contentFreezeAt", "policyRecord", "recordDelegation",
      "economicsRecord", "economicsRecordForBinding", "economicsRecordAssociation"],
    events: ["ArtistSaleConsentRecorded", "ArtistRoyaltyFreezeAuthorized", "ArtistContentFreezeAuthorized", "ArtistContentRecordContext", "ArtistPolicyConsentRecorded",
      "ArtistEconomicsConsentRecorded", "ArtistEconomicsConsentAssociated", "ArtistRecordDelegation"] },
  consentTransport: { source: base + "StreamArtistConsentTransport.sol", contract: "StreamArtistConsentTransport",
    methods: [], events: ["ArtistConsentDelegationRecorded"] },
  delegatedConsent: { source: "smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsent.sol", contract: "IStreamArtistDelegatedConsent",
    methods: ["recordDelegatedPolicyConsent", "recordDelegatedSaleConsent"] },
  archive: { source: base + "StreamArtistArchiveV2.sol", contract: "StreamArtistArchiveV2",
    methods: ["artistEvidenceBytesV2", "artistEvidenceMetadataV2", "artistRegistry", "operationCoordinator"], events: ["ArtistArchiveEvidenceAppendedV2"] },
  core: { source: "smart-contracts/interfaces/stream/core/IStreamCorePointers.sol", contract: "IStreamCorePointers", methods: ["getSatellitePointer"] },
  collection: { source: "smart-contracts/interfaces/stream/core/IStreamCoreCollectionView.sol", contract: "IStreamCoreCollectionView", methods: ["collectionExists"] },
};
const oracleSources = ["StreamArtistHashes.sol", "StreamArtistBindingOperations.sol", "StreamArtistSaleHashes.sol",
  "StreamArtistContentHashes.sol", "StreamArtistAuthorizationState.sol", "StreamArtistEconomicsHashes.sol",
  "StreamArtistIdentityRevisionState.sol", "StreamArtistDelegationState.sol", "StreamArtistIdentityState.sol",
  "StreamArtistIdentityOperations.sol", "StreamArtistEconomicOperations.sol", "StreamArtistDelegatedConsentOperations.sol",
  "StreamArtistDelegatedMutation.sol", "StreamArtistConsentTransport.sol", "StreamArtistConsentState.sol",
  "StreamArtistSaleOperations.sol", "StreamArtistOnboardingReads.sol", "StreamArtistEconomicsAssociation.sol",
  "StreamArtistConsentReadEncoding.sol", "StreamArtistProfilePayoutReads.sol", "StreamArtistRoyaltyModeReads.sol",
  "StreamArtistTemplateEconomicsReads.sol", "StreamArtistDefaultTemplateReads.sol"].map(name => base + name);

export function artistOperationFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen Artist ABI52 compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2212
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 2212-source capture");
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
    const abi = full.filter(row => (row.type === "function" && selection.methods.includes(row.name))
      || (row.type === "event" && (selection.events ?? []).includes(row.name)));
    for (const [type, names] of [["function", selection.methods], ["event", selection.events ?? []]]) {
      if (names.some(name => abi.filter(row => row.type === type && row.name === name).length !== 1)) throw Error(`Incomplete or overloaded ABI ${key}`);
    }
    abis[key] = abi;
  }
  for (const path of oracleSources) { visit(path); sourceTexts[path] = input.sources[path].content; }
  const registryAbi = new Interface(output.contracts[selections.registry.source][selections.registry.contract].abi);
  const publicMethods = registryAbi.fragments.filter(row => row.type === "function").map(row => ({
    name: row.name, signature: row.format("sighash"), selector: row.selector, stateMutability: row.stateMutability,
  }));
  return {
    schemaVersion: 1, capture: "parallel-feature-batch52-20260920", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 2212, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 2212 literal input sources independently verified byte-for-byte against this Git commit. Selected production closure hashes and original hash-library texts follow.",
    qualification: "Frozen source and ABI evidence only; client tests do not establish deployed Artist, actual Safe, gas, genesis or release acceptance.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts, selections, publicMethods, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-artist-operation-fixture.mjs INPUT OUTPUT [--check]");
  const rendered = JSON.stringify(artistOperationFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-artist-operation-current-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale current Artist operation ABI fixture");
  } else await writeFile(target, rendered, "utf8");
}
