// Project original Artist public calls and proof reads from retained ABI49; never compile Solidity.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Interface } from "ethers";

const INPUT_SHA = "d72aaf4b8dd4af5db39420038b0c0655a85161071d11a8dc8c9e00f9bc372b64";
const OUTPUT_SHA = "e21d5c31e1e10904cacc6577f27c3e036ac25d7c1999f8817d0b9cc6549fe15d";
const SOURCE_COMMIT = "18be311bc33e8007841f963f218ac8290e271015";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const base = "smart-contracts/domains/artist/";
const sharedOwner = ["artistRegistry", "operationCoordinator", "archiveV2", "core", "mintManager", "deploymentChainId", "domainId", "ownerStateSnapshotV2"];
const selections = {
  registry: { source: base + "StreamArtistOnboardingRegistry.sol", contract: "StreamArtistOnboardingRegistry", methods: [
    "refuseArtistBinding", "recordSaleConsent", "authorizeArtistRoyaltyFreeze", "authorizeArtistContentFreeze", "revokeArtistAuthorization",
    "bindingRefusalDigest", "saleConsentDigest", "royaltyFreezeDigest", "contentFreezeDigest", "authorizationRevocationDigest",
    "core", "mintManager", "operationCoordinator", "currentAuthorityCapabilities", "artistRegistryCutover", "gasParameterInfo",
    "artistAuthorizationState", "bindingTermination", "saleConsentRecord", "contentFreezeAuthorization", "isRoyaltyFreezeAuthorized",
  ] },
  coordinator: { source: base + "StreamArtistOnboardingCoordinator.sol", contract: "StreamArtistOnboardingCoordinator",
    methods: ["suiteConfiguration", "deploymentChainId", "configurationHash"] },
  owner: { source: base + "StreamArtistOwner.sol", contract: "StreamArtistOwner", methods: sharedOwner },
  identity: { source: base + "StreamArtistIdentityAuthority.sol", contract: "StreamArtistIdentityAuthority",
    methods: ["authorityState", "artistAuthorizationState", "currentAuthorityCapabilities"], events: ["ArtistAuthorizationRevoked"] },
  binding: { source: base + "StreamArtistBindingLifecycle.sol", contract: "StreamArtistBindingLifecycle", methods: ["binding", "bindingTerms", "bindingTermination"] },
  attribution: { source: base + "StreamArtistAttributionLifecycle.sol", contract: "StreamArtistAttributionLifecycle",
    methods: ["attributionState"], events: ["ArtistAttributionStateChanged", "ArtistBindingTerminationContext"] },
  collaborator: { source: base + "StreamArtistCollaboratorLifecycle.sol", contract: "StreamArtistCollaboratorLifecycle", methods: ["acceptedCount"] },
  consent: { source: base + "StreamArtistConsentFinalityLifecycle.sol", contract: "StreamArtistConsentFinalityLifecycle",
    methods: ["saleConsentRecord", "saleConsentAt", "royaltyFreezeRecord", "contentFreezeRecord", "contentFreezeAt"],
    events: ["ArtistSaleConsentRecorded", "ArtistRoyaltyFreezeAuthorized", "ArtistContentFreezeAuthorized", "ArtistContentRecordContext"] },
  archive: { source: base + "StreamArtistArchiveV2.sol", contract: "StreamArtistArchiveV2",
    methods: ["artistEvidenceBytesV2", "artistEvidenceMetadataV2", "artistRegistry", "operationCoordinator"], events: ["ArtistArchiveEvidenceAppendedV2"] },
  core: { source: "smart-contracts/interfaces/stream/core/IStreamCorePointers.sol", contract: "IStreamCorePointers", methods: ["getSatellitePointer"] },
  collection: { source: "smart-contracts/interfaces/stream/core/IStreamCoreCollectionView.sol", contract: "IStreamCoreCollectionView", methods: ["collectionExists"] },
};
const oracleSources = ["StreamArtistHashes.sol", "StreamArtistBindingOperations.sol", "StreamArtistSaleHashes.sol",
  "StreamArtistContentHashes.sol", "StreamArtistAuthorizationState.sol", "StreamArtistEconomicsHashes.sol"].map(name => base + name);

export function artistOperationFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen Artist ABI49 compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2172
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 2172-source capture");
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
    schemaVersion: 1, capture: "parallel-feature-batch49-20260920", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 2172, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 2172 literal input sources independently verified byte-for-byte against this Git commit. Selected production closure hashes and original hash-library texts follow.",
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
