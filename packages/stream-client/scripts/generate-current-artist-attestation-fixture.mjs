// Project original delegated op24 and authenticated subject reads from retained ABI56; never compile.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "6aec6f59bb3037d83ee9a3bc2a3a1552bfac224c4b8cbf7bbe9ec79ce6c253c7";
const OUTPUT_SHA = "7423844d40d9ee2982473692bee53bb482f578a90e90e340f95d06469cbe3aaf";
const SOURCE_COMMIT = "ed4d557246a98698167d6986bc4266d9e375d558";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const artist = "smart-contracts/domains/artist/", interfaces = "smart-contracts/interfaces/stream/";
const selection = (source, contract, methods, events = []) => ({ source, contract, methods, events });
const selections = {
  registry: selection(artist + "StreamArtistOnboardingRegistry.sol", "StreamArtistOnboardingRegistry", [
    "recordDelegatedArtistAttestation", "recordDelegatedArtistScopedAttestation", "attestationDigest",
    "core", "mintManager", "operationCoordinator", "gasParameterInfo", "finalityRegistry", "finalityRegistryCodeHash",
  ]),
  writer: selection(interfaces + "artist/IStreamArtistAttestationWriter.sol", "IStreamArtistAttestationWriter", [
    "recordDelegatedArtistAttestation", "recordDelegatedArtistScopedAttestation", "attestationAssociation",
  ]),
  authenticatedOwner: selection(interfaces + "artist/IStreamArtistAttestationWriter.sol", "IStreamArtistAuthenticatedAttestationOwner", [
    "recordAuthenticatedAttestation", "attestationAssociation",
  ]),
  coordinator: selection(artist + "StreamArtistOnboardingCoordinator.sol", "StreamArtistOnboardingCoordinator", [
    "suiteConfiguration", "deploymentChainId", "configurationHash", "reads",
  ]),
  owner: selection(artist + "StreamArtistOwner.sol", "StreamArtistOwner", [
    "artistRegistry", "operationCoordinator", "archiveV2", "core", "mintManager", "deploymentChainId", "domainId", "ownerStateSnapshotV2",
  ]),
  identity: selection(artist + "StreamArtistIdentityAuthority.sol", "StreamArtistIdentityAuthority", [
    "authorityState", "artistAuthorizationState", "currentAuthorityCapabilities", "delegationEpochState", "signatureBundle", "replayCell",
    "operativeIdentityRecord", "delegationRecord", "operativeEstateDirective", "estateDirectiveRecord",
  ]),
  binding: selection(artist + "StreamArtistBindingLifecycle.sol", "StreamArtistBindingLifecycle", ["binding", "bindingTerms"]),
  attribution: selection(artist + "StreamArtistAttributionLifecycle.sol", "StreamArtistAttributionLifecycle", [
    "attributionState", "attestationRecord", "statementBytes", "attestationAssociation", "publicationAttestation", "attestationAuthorityClass",
  ], ["ArtistAttestationRecorded", "ArtistAttestationDelegation"]),
  collaborator: selection(artist + "StreamArtistCollaboratorLifecycle.sol", "StreamArtistCollaboratorLifecycle", ["acceptedCount"]),
  archive: selection(artist + "StreamArtistArchiveV2.sol", "StreamArtistArchiveV2", [
    "artistEvidenceBytesV2", "artistEvidenceMetadataV2", "artistRegistry", "operationCoordinator",
  ], ["ArtistArchiveEvidenceAppendedV2"]),
  core: selection(interfaces + "core/IStreamCorePointers.sol", "IStreamCorePointers", ["getSatellitePointer"]),
  collection: selection(interfaces + "core/IStreamCoreCollectionView.sol", "IStreamCoreCollectionView", ["collectionExists"]),
  finality: selection(interfaces + "finality/IStreamArtworkFinalityRegistry.sol", "IStreamArtworkFinalityRegistry", [
    "collectionFinalityRecord", "artworkScopeFinalityRecord",
  ]),
  finalityBindings: selection(interfaces + "finality/IStreamFinalityDeploymentBindings.sol", "IStreamFinalityDeploymentBindings", [
    "scopeEvidenceProvider", "scopeEvidenceProviderCodeHash",
  ]),
  discovery: selection(interfaces + "finality/IStreamFinalityDiscoverySources.sol", "IStreamFinalityDiscoverySources", ["snapshotHost"]),
  snapshotConfiguration: selection(artist + "StreamArtistAttestationSubjectReads.sol", "IStreamArtistSnapshotConfiguration", ["nativeConfiguration"]),
  snapshot: selection(interfaces + "metadata/IStreamCollectionSnapshots.sol", "IStreamCollectionSnapshots", [
    "core", "metadataRouter", "currentSnapshot", "latestSnapshotHash", "snapshotHash",
  ]),
  metadata: selection(interfaces + "metadata/IStreamCollectionManifestReads.sol", "IStreamCollectionManifestReads", [
    "core", "scriptManifestHash", "mediaManifestHash",
  ]),
  manager: selection(interfaces + "mint/IStreamMintReads.sol", "IStreamMintReads", ["core", "phase", "phasePolicyHash"]),
  primary: selection(interfaces + "revenue/IStreamRevenueResolver.sol", "IStreamRevenueResolver", ["core", "resolvePrimaryAssignment"]),
  primaryScope: selection(interfaces + "artist/IStreamArtistPrimaryScopeFacts.sol", "IStreamArtistPrimaryScopeFacts", ["primaryEconomicsFacts"]),
  royalty: selection(interfaces + "artist/IStreamArtistRoyaltyScopeFacts.sol", "IStreamArtistRoyaltyScopeFacts", [
    "royaltyEconomicsFacts", "resolveRoyaltyAssignment",
  ]),
  module: selection(interfaces + "modules/IStreamModule.sol", "IStreamModule", ["streamModuleType", "streamModuleInterfaceId"]),
  modules: selection(interfaces + "modules/IStreamModuleRegistry.sol", "IStreamModuleRegistry", ["isModuleEligible"]),
  publicationHost: selection(interfaces + "artist/IStreamArtistRecordPublicationHost.sol", "IStreamArtistRecordPublicationHost", ["requireArtistRecordCandidate"]),
  erc165: selection("smart-contracts/vendor/openzeppelin/IERC165.sol", "IERC165", ["supportsInterface"]),
};
const oracleSources = [
  "StreamArtistHashes.sol", "StreamArtistAttestationOperations.sol", "StreamArtistAttestationSubjectReads.sol",
  "StreamArtistAttributionAttestations.sol", "StreamArtistRecordPublicationReads.sol", "StreamArtistRecordPublicationRules.sol",
  "StreamArtistRecordPublicationState.sol", "StreamArtistDelegatedMutation.sol", "StreamArtistCurrentAuthorityFacts.sol",
  "StreamArtistC2PACredentials.sol", "StreamArtistDelegationState.sol", "StreamArtistAuthorizationState.sol",
].map(name => artist + name);

export function artistAttestationFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen Artist ABI56 compiler capture");
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
  for (const [key, selected] of Object.entries(selections)) {
    visit(selected.source);
    const full = output.contracts?.[selected.source]?.[selected.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing compiled ABI ${key}`);
    const abi = full.filter(row => (row.type === "function" && selected.methods.includes(row.name))
      || (row.type === "event" && selected.events.includes(row.name)));
    for (const [type, names] of [["function", selected.methods], ["event", selected.events]]) {
      if (names.some(name => abi.filter(row => row.type === type && row.name === name).length !== 1)) throw Error(`Incomplete or overloaded ABI ${key}`);
    }
    abis[key] = abi;
  }
  for (const path of oracleSources) { visit(path); sourceTexts[path] = input.sources[path].content; }
  return {
    schemaVersion: 1, capture: "parallel-feature-batch56-20260920", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 2241, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 2241 literal input sources independently verified byte-for-byte against this Git commit. Selected production closure hashes and original recipe texts follow.",
    qualification: "Frozen source and ABI evidence only; client tests do not establish deployed Artist, actual Safe, gas, genesis or release acceptance. Original op24 subject profiles only; C2PA caller support is deferred.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-artist-attestation-fixture.mjs INPUT OUTPUT [--check]");
  const rendered = JSON.stringify(artistAttestationFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-artist-attestation-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale current Artist attestation ABI fixture");
  } else await writeFile(target, rendered, "utf8");
}
