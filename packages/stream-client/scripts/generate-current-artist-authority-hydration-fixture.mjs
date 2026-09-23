// Project approved operation60 profiles from frozen ABI67. This generator never compiles.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "dce7907bcef7668ae76048242727032374edd6a618d0e0070f6e84aeec27046f";
const OUTPUT_SHA = "d7dae97ec114efc0bdd76084f69f5601e04db5a108faa3be235dbb665f9eaf2e";
const SOURCE_COMMIT = "be359669d736843e7f0c8a85eed6f06ec9521464";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const domain = "smart-contracts/domains/artist/", interfaces = "smart-contracts/interfaces/stream/artist/";
const select = (source, contract, methods, events = []) => ({ source, contract, methods, events });
const full = (source, contract) => ({ source, contract, full: true });
const selections = {
  artist: select(domain + "StreamArtistOnboardingRegistry.sol", "StreamArtistOnboardingRegistry", [
    "hydrateArtistAuthority", "hydrateMultipleArtistAuthority", "hydrateArtistAuthorityWithDelegations",
    "core", "mintManager", "operationCoordinator", "supportsInterface", "gasParameter", "gasParameterInfo",
    "importedHistoryBinding", "importedHistoryBindingCount", "artistHistoryPredecessorBinding", "artistRegistryCutover",
    "artistHistoryLane", "importedLaneVerified", "storedPayloadAt", "storedPayloadCount",
  ], ["ArtistStoredPayload"]),
  coordinator: select(domain + "StreamArtistOnboardingCoordinator.sol", "StreamArtistOnboardingCoordinator", [
    "authorityHydrationSuite", "suiteConfiguration", "configurationHash", "deploymentChainId",
    "coordinateHydrateArtistAuthority", "coordinateHydrateMultipleArtistAuthority", "coordinateHydrateArtistAuthorityWithDelegations",
  ]),
  owner: full(domain + "StreamArtistOwner.sol", "StreamArtistOwner"),
  checkpoint: full(interfaces + "IStreamArtistAuthorityCheckpoint.sol", "IStreamArtistAuthorityCheckpoint"),
  hydrationInterface: full(interfaces + "IStreamArtistAuthorityHydration.sol", "IStreamArtistAuthorityHydration"),
  hydrationOwner: full(interfaces + "IStreamArtistAuthorityHydration.sol", "IStreamArtistAuthorityHydrationOwner"),
  multipleInterface: full(interfaces + "IStreamArtistMultipleAuthorityHydration.sol", "IStreamArtistMultipleAuthorityHydration"),
  multipleIdentity: full(interfaces + "IStreamArtistMultipleAuthorityHydration.sol", "IStreamArtistMultipleHydrationIdentity"),
  delegationInterface: full(interfaces + "IStreamArtistDelegationAuthorityHydration.sol", "IStreamArtistDelegationAuthorityHydration"),
  delegationOwner: full(interfaces + "IStreamArtistDelegationAuthorityHydration.sol", "IStreamArtistDelegationHydrationOwner"),
  history: full(interfaces + "IStreamArtistHistory.sol", "IStreamArtistHistory"),
  nativeReceipts: full(interfaces + "IStreamArtistHistory.sol", "IStreamArtistNativeReceipts"),
  archive: full(domain + "StreamArtistArchiveV2.sol", "StreamArtistArchiveV2"),
  binding: select(domain + "StreamArtistBindingLifecycle.sol", "StreamArtistBindingLifecycle", [
    "binding", "bindingAt", "bindingTerms", "authorityHydrationState", "authorityDelegationHydrationState",
  ]),
  identity: select(domain + "StreamArtistIdentityAuthority.sol", "StreamArtistIdentityAuthority", [
    "identity", "identityDocumentBytes", "identityRecordBytes", "nextRegistrationNonce", "signatureBundle", "nonceUsed",
    "delegatedNonceState", "delegationEpochState", "delegationRecord", "identityRevisionRecord", "operativeIdentityRecord",
    "authorityHydrationState", "authorityLivingIdentityHydrationState", "authorityDelegationHydrationState",
    "artistAuthorizationState", "recordPreimageBytes", "storedPayloadAt", "storedPayloadCount", "artistHistorySourceCursor",
  ]),
  acceptance: select(domain + "StreamArtistAcceptanceLifecycle.sol", "StreamArtistAcceptanceLifecycle", [
    "acceptanceRecord", "acceptedAt", "authorityHydrationState",
  ]),
  attribution: select(domain + "StreamArtistAttributionLifecycle.sol", "StreamArtistAttributionLifecycle", [
    "attributionState", "authorityHydrationState", "storedPayloadAt", "storedPayloadCount",
  ]),
  consent: select(domain + "StreamArtistConsentFinalityLifecycle.sol", "StreamArtistConsentFinalityLifecycle", [
    "policyRecord", "saleConsentRecord", "saleConsentAt", "recordPreimageBytes", "storedPayloadAt", "storedPayloadCount",
    "authorityHydrationState", "authorityDelegationHydrationState",
  ]),
  delegationCodec: full(domain + "StreamArtistDelegationHydrationCodec.sol", "StreamArtistDelegationHydrationCodec"),
  hydrationEvents: select(domain + "StreamArtistHydrationCommit.sol", "StreamArtistHydrationCommit", [], ["ArtistAuthorityHydrated"]),
  multipleEvents: select(domain + "StreamArtistMultipleHydrationOperations.sol", "StreamArtistMultipleHydrationOperations", [], ["MultipleArtistAuthorityHydrated"]),
  core: select("smart-contracts/core/StreamCore.sol", "StreamCore", ["getSatellitePointer"]),
  reconstruction: full(interfaces + "IStreamArtistReconstruction.sol", "IStreamArtistReconstruction"),
};

export function artistAuthorityHydrationFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen Artist authority hydration ABI67 capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2311
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 2311-source capture");
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
    const all = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(all)) throw Error(`Missing compiled ABI ${key}`);
    const abi = selection.full ? all : all.filter(row => row.type === "function" && selection.methods.includes(row.name)
      || row.type === "event" && selection.events.includes(row.name));
    if (!selection.full) for (const [type, names] of [["function", selection.methods], ["event", selection.events]]) {
      const invalid = names.filter(name => abi.filter(row => row.type === type && row.name === name).length !== 1);
      if (invalid.length) throw Error(`Missing/overloaded ABI ${key}: ${invalid.join(", ")}`);
    }
    abis[key] = abi;
  }
  const originalSources = Object.keys(input.sources).filter(path =>
    (path.startsWith(domain) && (/Hydration|AuthorityCheckpoint|HistoryProof|HistoryOperations|NativeHistory|OwnerCommit|PayloadStore|PayloadSync|Owner\.sol$/.test(path)))
    || (path.startsWith(interfaces) && /AuthorityHydration|AuthorityCheckpoint|ArtistOwner\.sol$|ArtistHistory\.sol$|OnboardingTypes|DelegationTypes|SaleTypes|IdentityRevision|CollaboratorTypes/.test(path)));
  for (const path of [...new Set([...Object.values(selections).map(row => row.source), ...originalSources])].sort()) {
    visit(path); sourceTexts[path] = input.sources[path].content;
  }
  return {
    schemaVersion: 1, capture: "parallel-feature-batch67-20260920", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 2311, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 2311 literal compiler inputs independently verified byte-for-byte against this frozen Git commit. Artist sources and approved profile guides are unchanged through integration 1f47d711433f7d68e3ee7c2375747d25aa22bef7.",
    qualification: "Frozen source and ABI evidence only. Selected client profiles are original living baseline, multiple and single delegation. Advanced or combined profiles are not inferred. Client tests do not establish native current-stack, actual Safe, gas, genesis or release acceptance.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-artist-authority-hydration-fixture.mjs INPUT OUTPUT [--check]");
  const rendered = JSON.stringify(artistAuthorityHydrationFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-artist-authority-hydration-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale Artist authority hydration fixture");
  } else await writeFile(target, rendered, "utf8");
}
