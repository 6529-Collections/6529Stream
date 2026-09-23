// Retain the exact ABI129 scoped policy publication source. Never invoke Solidity.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "896899f7ca4130f86e066587f780a3b1f755a25d";
const TREE = "743efae1136e5742cb57c9e477080bd1c6aca5aa";
const INPUT_SHA = "2f53a404ef440f637623a5dcfa143d7c617f403bd01438e36f507dc0da329295";
const OUTPUT_SHA = "d646cec16ef86f03a7689e856473f2967a8b30e4d64dfafeba395f445ca3ffbb";
const BRIDGE_SHA = "f59fa4f8b70da4f1ac70d1224e8b4740d398cdd41df29bb48c6d6ddc8cbad696";
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const contracts = {
  "publicationFactory": "StreamScopedPolicyPublicationFactoryV2",
  "publicationFactoryInterface": "IStreamScopedPolicyPublicationFactoryV2",
  "sourceFactory": "StreamFinalityScopedEntropyPolicySourceFactoryV2",
  "scopedFactoryInterface": "IStreamFinalityScopedEntropyPolicySourceFactoryV2",
  "genericFactoryInterface": "IStreamFinalityEntropySourceFactory",
  "currentRoute": "IStreamFinalityCurrentEntropyRoute",
  "sourceSet": "StreamFinalityEntropyPolicySourceSet",
  "sourceSetInterface": "IStreamFinalityEntropyPolicySourceSet",
  "coordinatorInventory": "StreamFinalityCoordinatorInventory",
  "coordinatorInventoryInterface": "IStreamFinalityCoordinatorInventory",
  "membership": "StreamFinalityScopeMembership",
  "membershipInterface": "IStreamFinalityScopeMembership",
  "readiness": "StreamTerminalEntropyReadiness",
  "readinessInterface": "IStreamTerminalEntropyReadiness",
  "checkpoint": "StreamScopedPolicyContentCheckpointV2",
  "checkpointInterface": "IStreamScopedPolicyContentCheckpointV2",
  "output": "StreamScopedPolicyOutputManifestV2",
  "outputInterface": "IStreamScopedPolicyOutputManifestV2",
  "snapshot": "StreamScopedPolicySnapshotPublicationV2",
  "snapshotInterface": "IStreamScopedPolicySnapshotPublicationV2",
  "reference": "StreamScopedPolicyReferencePublicationV2",
  "referenceInterface": "IStreamScopedPolicyReferencePublicationV2",
  "inventory": "StreamScopedPolicyRenderCriticalInventoryV2",
  "inventoryInterface": "IStreamScopedPolicyRenderCriticalInventoryV2",
  "bundle": "StreamScopedPolicyBundleArchiveCoverageV2",
  "bundleInterface": "IStreamScopedPolicyBundleArchiveCoverageV2",
  "provider": "StreamFinalityScopedPolicyEvidenceProviderV2",
  "providerBinding": "IStreamScopedPolicyPublicationEvidenceBindingV2",
  "profileSources": "IStreamFinalityProfileSources",
  "discovery": "StreamFinalityScopedPolicyProfileDiscoveryV2",
  "contentRootBinding": "IStreamScopedPolicyContentRootEvidenceBindingV2",
  "core": "StreamCore",
  "corePointers": "IStreamCorePointers",
  "coreCollection": "IStreamCoreCollectionView",
  "coreIdentity": "IStreamCoreIdentity",
  "metadata": "StreamCollectionMetadataV1",
  "metadataInterface": "IStreamCollectionMetadataV1",
  "selection": "StreamStaticSelectionCheckpoint",
  "selectionInterface": "IStreamStaticSelectionCheckpoint",
  "schemas": "StreamSchemaRegistry",
  "store": "StreamSchemaDocumentStore",
  "moduleRegistry": "StreamModuleRegistry",
  "finality": "StreamArtworkFinalityRegistry",
  "erc165": "IERC165",
  "gas": "IStreamGasParameterHost",
  "router": "StreamMetadataRouter",
  "entropy": "StreamEntropyCoordinator",
  "policyFacts": "IStreamEntropyPolicyStaticRead",
  "staticEntropy": "IStreamStaticEntropySource",
  "discoveryBinding": "IStreamFinalityEvidenceDiscoveryBinding",
  "routerBinding": "IStreamFinalityRouterEvidenceBinding",
  "entropyCoordinatorInterface": "IStreamEntropyCoordinator",
  "entropyFinalityPolicyInterface": "IStreamEntropyFinalityPolicy",
  "moduleInterface": "IStreamModule",
  "routerInterface": "IStreamMetadataRouter",
  "scopedFinalityComponentInterface": "IStreamArtworkScopedFinalityComponent",
  "artifactCoverage": "StreamFinalityArtifactCoverage",
  "artifactCoverageInterface": "IStreamFinalityArtifactCoverage",
  "servingFacts": "IStreamMetadataServingFacts",
  "staticRouter": "IStreamStaticMetadataRouter",
  "fullViews": "IStreamMetadataFullViews",
  "renderer": "IStreamRenderer",
  "artist": "StreamArtistOnboardingRegistry",
  "artistCoordinator": "StreamArtistOnboardingCoordinator",
  "bindingHost": "StreamArtistBindingLifecycle",
  "collaboratorHost": "StreamArtistCollaboratorLifecycle",
  "identity": "StreamArtistIdentityAuthority",
  "acceptanceHost": "StreamArtistAcceptanceLifecycle",
  "attributionHost": "StreamArtistAttributionLifecycle",
  "payoutHost": "StreamArtistPayoutLifecycle",
  "consent": "StreamArtistConsentFinalityLifecycle",
  "archive": "StreamArtistArchiveV2",
  "validator": "StreamArtistRegistryValidatorBase",
  "ownerBase": "StreamArtistOwner",
  "owner": "IStreamArtistOwner",
  "binding": "IStreamArtistBindingOwner",
  "collaboratorBinding": "IStreamArtistCollaboratorBindingOwner",
  "collaboratorRecords": "IStreamArtistCollaboratorRecordsOwner",
  "identityInterface": "IStreamArtistIdentityOwner",
  "attribution": "IStreamArtistAttributionOwner",
  "attributionState": "IStreamArtistAttributionState",
  "artistAttribution": "IStreamArtistAttribution",
  "commercialAuthority": "IStreamArtistCommercialAuthority",
  "contentAuthority": "IStreamArtistContentAuthority",
  "contentFacts": "IStreamArtistContentFacts",
  "contentMutationFacts": "IStreamArtistContentMutationFacts",
  "contentRatification": "IStreamArtistContentRatification",
  "contentCoordinator": "IStreamArtistContentCoordinator",
  "contentIdentity": "IStreamArtistContentIdentityOwner",
  "contentRecords": "IStreamArtistContentRecordsOwner",
  "currentConsentOwner": "IStreamArtistCurrentConsentOwner",
  "authorization": "IStreamArtistAuthorizationRevocation",
  "authorizationOwner": "IStreamArtistAuthorizationOwner",
  "estateOwner": "IStreamArtistEstateOwner",
  "artistFinalityBinding": "IStreamArtistFinalityBinding",
  "artistCheckpoint": "IStreamArtistAuthorityCheckpoint",
  "nativeReceipts": "IStreamArtistNativeReceipts",
  "artistHistory": "IStreamArtistHistory",
  "reconstruction": "IStreamArtistReconstruction",
  "payloadArchive": "IStreamArtistPayloadArchive",
  "archiveInterface": "IStreamArtistArchiveV2",
  "erc1271": "IERC1271",
  "scopedRoot": "IStreamScopedContentRootPublication",
  "policyRoot": "IStreamScopedPolicyContentRootPublicationV2",
  "finalityInterface": "IStreamArtworkFinalityRegistry",
  "finalityBindings": "IStreamFinalityDeploymentBindings",
  "finalityProviderInterface": "IStreamFinalityEvidenceProvider",
  "originalRootEvidence": "IStreamContentRootEvidenceBinding",
  "artistSuiteReads": "IStreamArtistSuiteReads",
  "artistDormancy": "IStreamArtistDormancy",
  "artistDormancyEvents": "IStreamArtistDormancyReconstructionEvents",
  "scopedMetadataReads": "IStreamFinalityScopedMetadataReads"
};
// Solidity library selectors retain nominal enum types; never rewrite these
// compiler ABIs into public-contract tuples for ethers or wallet call plans.
const libraryContracts = {
  "recipe": "StreamScopedPolicyPublicationRecipeV2",
  "graphReads": "StreamScopedPolicyPublicationGraphReadsV2",
  "readinessDeployment": "StreamScopedPolicyPublicationReadinessDeploymentV2",
  "checkpointDeployment": "StreamScopedPolicyPublicationCheckpointDeploymentV2",
  "outputDeployment": "StreamScopedPolicyPublicationOutputDeploymentV2",
  "snapshotDeployment": "StreamScopedPolicyPublicationSnapshotDeploymentV2",
  "referenceDeployment": "StreamScopedPolicyPublicationReferenceDeploymentV2",
  "inventoryDeployment": "StreamScopedPolicyPublicationInventoryDeploymentV2",
  "bundleDeployment": "StreamScopedPolicyPublicationBundleDeploymentV2",
  "sourceDeployment": "StreamFinalityEntropyPolicySourceDeploymentV2",
  "graphSelection": "StreamFinalityScopedPolicyGraphSelectionV2",
  "policyReads": "StreamFinalityCoordinatorPolicyReadsV2",
  "snapshotSourceReads": "StreamScopedPolicySnapshotSourceReadsV2",
  "snapshotDefinitions": "StreamScopedPolicySnapshotDefinitionsV2",
  "outputSchemas": "StreamScopedPolicyOutputSchemasV2",
  "metadataScopedPolicyContentSourceV2": "StreamMetadataScopedPolicyContentSourceV2",
  "metadataScopedPolicyContentV2": "StreamMetadataScopedPolicyContentV2",
  "metadataScopedContentState": "StreamMetadataScopedContentState",
  "metadataContentAuthorization": "StreamMetadataContentAuthorization",
  "metadataRouterRootCodec": "StreamMetadataRouterRootCodec",
  "metadataContentRoot": "StreamMetadataContentRoot",
  "metadataScopedContent": "StreamMetadataScopedContent",
  "metadataScopedPolicyContentStateV2": "StreamMetadataScopedPolicyContentStateV2",
  "scopedPolicyContentRootSchemasV2": "StreamScopedPolicyContentRootSchemasV2",
  "finalityScopedPolicySnapshotReadsV2": "StreamFinalityScopedPolicySnapshotReadsV2",
  "artistContentHashes": "StreamArtistContentHashes",
  "artistHashes": "StreamArtistHashes",
  "artistContentOperations": "StreamArtistContentOperations",
  "artistIdentityConsentState": "StreamArtistIdentityConsentState",
  "artistIdentityState": "StreamArtistIdentityState",
  "artistConsentTransport": "StreamArtistConsentTransport",
  "artistCurrentAuthorityFacts": "StreamArtistCurrentAuthorityFacts",
  "artistAuthorityPolicy": "StreamArtistAuthorityPolicy",
  "artistOwnerCommit": "StreamArtistOwnerCommit",
  "artistNativeReceipts": "StreamArtistNativeReceipts",
  "artistPayloadStore": "StreamArtistPayloadStore"
};
const documents = [
  "docs/adr/0006-metadata-freeze.md",
  "docs/adr/0039-canonical-finality-governance-and-evidence.md",
  "docs/adr/0040-current-metadata-record-host.md",
  "docs/adr/0041-typed-finality-evidence-provider.md",
  "docs/integrations/scoped-policy-source-factory-v2.md",
  "docs/integrations/scoped-policy-output-v2.md",
  "docs/integrations/scoped-policy-publication-v2.md",
  "docs/integrations/scoped-policy-preservation-v2.md",
  "docs/integrations/scoped-policy-finality-v2.md",
  "docs/scope-membership.md",
  "docs/integrations/original-coordinator-inventory.md",
  "docs/integrations/static-selection-checkpoint.md",
  "docs/integrations/current-terminal-entropy.md",
  "docs/integrations/terminal-entropy-consumers.md",
  "docs/integrations/metadata-records.md",
  "docs/schema-registry.md",
  "docs/schemas/preservation/scoped-policy-snapshot-v2.abi.json",
  "docs/schemas/preservation/scoped-policy-snapshot-v2.profile.json",
  "docs/schemas/preservation/scoped-policy-snapshot-v2.schema.json",
  "docs/integrations/artist-content.md",
  "docs/stream-artist-authority.md",
  "docs/adr/0022-immutable-artist-registry-validation-adapter.md",
  "docs/adr/0023-modular-artist-authority-domain-ownership.md",
  "docs/adr/0025-artist-authority-windows-and-fixed-extensions.md",
  "docs/guides/artist-authority-checkpoints.md",
  "docs/guides/artist-state-reconstruction.md"
];

function bindAllGitLiterals(input, bridge) {
  const entries = Object.entries(input.sources).sort(([a], [b]) => order(a, b));
  if (entries.some(([path, source]) => /[\r\n]/.test(path) || typeof source.content !== "string")) {
    throw Error("Invalid compiler source literal");
  }
  const blobs = execFileSync("git", ["cat-file", "--batch"], {
    input: entries.map(([path]) => `${SOURCE}:${path}\n`).join(""), maxBuffer: 128 * 1024 * 1024,
  });
  let cursor = 0, literalBytes = 0;
  for (const [path, source] of entries) {
    const end = blobs.indexOf(10, cursor), header = blobs.subarray(cursor, end).toString("ascii");
    const size = Number(header.split(" ")[2]);
    if (end < cursor || !header.includes(" blob ") || !Number.isSafeInteger(size) || size < 0) {
      throw Error(`Missing frozen source ${path}`);
    }
    const bytes = blobs.subarray(end + 1, end + 1 + size);
    if (!bytes.equals(Buffer.from(source.content, "utf8"))) throw Error(`Compiler/Git bytes differ: ${path}`);
    if (bridge.committedBlobSHA256[path] !== sha(bytes)) throw Error("Bridge/Git hash differs: " + path);
    cursor = end + size + 2;
    literalBytes += size;
  }
  if (cursor !== blobs.length || literalBytes !== 38_308_658) throw Error("Frozen literal inventory differs");
}

export function scopedPolicyRootV2Fixture(inputBytes, outputBytes, bridgeBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact ABI129 input/output");
  if (sha(bridgeBytes) !== BRIDGE_SHA) throw Error("Expected exact ABI129 committed source bridge");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), bridge = JSON.parse(bridgeBytes);
  if (bridge.commit !== SOURCE || bridge.sources !== 3262
    || Object.keys(bridge.committedBlobSHA256 ?? {}).length !== 3262
    || !Array.isArray(bridge.mismatches) || bridge.mismatches.length !== 0) throw Error("Invalid committed source bridge");
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 3262
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid scoped policy root V2 capture");
  if (execFileSync("git", ["rev-parse", `${SOURCE}^{tree}`], { encoding: "utf8" }).trim() !== TREE) throw Error("Frozen tree differs");
  bindAllGitLiterals(input, bridge);
  const abis = {}, selections = {}, methodIdentifiers = {}, sourceHashes = {}, sourceTexts = {};
  const libraryAbis = {}, librarySelections = {}, libraryMethodIdentifiers = {};
  function visit(path) {
    if (Object.hasOwn(sourceHashes, path)) return;
    const source = input.sources[path]?.content;
    if (typeof source !== "string") throw Error(`Missing source ${path}`);
    sourceHashes[path] = sha(source);
    sourceTexts[path] = source;
    for (const imported of solidityImports(source)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  for (const [key, name] of Object.entries(contracts)) {
    const matches = Object.entries(output.contracts).filter(([path, entries]) => path.startsWith("smart-contracts/") && entries[name]);
    if (matches.length !== 1) throw Error(`Expected one compiled ${name}`);
    const [source, entries] = matches[0], contract = entries[name];
    if (!Array.isArray(contract.abi)) throw Error(`Missing full ABI ${name}`);
    abis[key] = contract.abi;
    selections[key] = { source, contract: name, full: true };
    methodIdentifiers[key] = contract.evm?.methodIdentifiers ?? {};
    visit(source);
  }
  for (const [key, name] of Object.entries(libraryContracts)) {
    const matches = Object.entries(output.contracts).filter(([path, entries]) => path.startsWith("smart-contracts/") && entries[name]);
    if (matches.length !== 1) throw Error(`Expected one compiled library ${name}`);
    const [source, entries] = matches[0], contract = entries[name];
    if (!Array.isArray(contract.abi)) throw Error(`Missing full library ABI ${name}`);
    libraryAbis[key] = contract.abi;
    librarySelections[key] = { source, contract: name, full: true, nominal: true };
    libraryMethodIdentifiers[key] = contract.evm?.methodIdentifiers ?? {};
    visit(source);
  }
  const retainedDocuments = {};
  for (const path of documents) {
    const bytes = execFileSync("git", ["show", `${SOURCE}:${path}`], { maxBuffer: 4 * 1024 * 1024 });
    const text = bytes.toString("utf8");
    if (!Buffer.from(text, "utf8").equals(bytes)) throw Error(`Invalid UTF-8 document ${path}`);
    retainedDocuments[path] = { sha256: sha(bytes), byteLength: bytes.length, text };
  }
  const sorted = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => order(a, b)));
  return {
    schemaVersion: 1,
    profile: "scoped-policy-root-v2",
    capture: "parallel-feature-batch129-20260920",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 3262,
    compilerReportedCommit: "896899f7ca4130f86e066587f780a3b1f755a25d",
    committedSourceBridge: { sha256: sha(bridgeBytes), ...bridge },
    literalBytes: 38_308_658,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "Every compiler input literal matches its frozen Git blob byte-for-byte; this verifier performs no line-ending normalization. All selected ABIs are complete compiler output, with the full imported source closure. Interpretation documents come from the same source commit.",
    qualification: "Source/ABI and mocked client evidence for actual scoped full-policy root adoption and original Artist operation-17 content consent. This explicit profile admits TOKEN, RELEASE and SEASON using the selected genuine Finality/provider snapshot route. Completed current root-free snapshot, actual covered output, exact source/dependency pins and original interpretation documents are prerequisites. Root publisher and Artist signer/caller remain separate. Original op17 signs the Router preview's next collection-wide CONTENT_ROOT family, not the individual root state hash; direct/Safe transport never grants authority. Historical record hashes commit the publication event's original collection Aggregate. Original V1 and V2 history retain separate closed interpretations. Reference/inventory/archive/governance/finality ceremonies and COLLECTION/VIEW profiles remain separate. Native/Safe execution, deployed-runtime provenance, whole-call rollback, gas/capacity and release acceptance remain separately qualified.",
    sourceHashes: sorted(sourceHashes),
    sourceTexts: sorted(sourceTexts),
    documents: retainedDocuments,
    selections,
    methodIdentifiers,
    abis,
    librarySelections,
    libraryMethodIdentifiers,
    libraryAbis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, bridge, mode] = process.argv.slice(2);
  if (!input || !output || !bridge || mode !== undefined && mode !== "--check") {
    throw Error("Usage: generate-current-scoped-policy-root-v2-fixture.mjs INPUT OUTPUT COMMITTED_SOURCE_BRIDGE [--check]");
  }
  const rendered = JSON.stringify(scopedPolicyRootV2Fixture(await readFile(input), await readFile(output), await readFile(bridge)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-scoped-policy-root-v2-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale scoped policy root V2 fixture");
    process.stdout.write("Scoped policy root V2 fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Scoped policy root V2 fixture written\n");
  }
}
