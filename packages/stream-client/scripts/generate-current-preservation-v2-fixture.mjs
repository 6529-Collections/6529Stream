// Shared exact ABI146 evidence for current token preservation V2 and complete VIEW clients.
// Never invokes Solidity, modifies captures, or refreshes historical fixtures.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "9381dd999075693a4f63092d9924856a0dd72834";
const TREE = "d494a5f4703c5e35f7804ba8faabeecdceb69ef8";
const INPUT_SHA = "be6679a64a2dec7d5acacab44e72937871b4d07fbdbcacb67de0e29e00f243c4";
const OUTPUT_SHA = "955f08a7f6a1da5e1218654d841e6c0a62559b288bfc51a8fbb9fb4fb670cf1a";
const BRIDGE_SHA = "2078dab397cce55469f964b36f6d801329ec2f5d36c6ea175cf7426b1bd45d21";
const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const roots = [
  "IERC165",
  "IStreamArtistArchiveOriginInventory",
  "IStreamArtistArchiveOriginReads",
  "IStreamArtistArchiveV2",
  "IStreamArtistContentRecordsOwner",
  "IStreamArtistCurrentAuthorityResolver",
  "IStreamArtistImportedReceiptRead",
  "IStreamArtistNativeReceipts",
  "IStreamArtistRecordPublicationOwner",
  "IStreamArtistRecoveredHydrationOwner",
  "IStreamArtistRecoveredNativeChronology",
  "IStreamBundleArchiveCoverage",
  "IStreamCollectionMetadataV1",
  "IStreamContentRootPublication",
  "IStreamCoreCollectionView",
  "IStreamCoreIdentity",
  "IStreamCorePointers",
  "IStreamCurrentAuthorityBundleArchiveCoverage",
  "IStreamCurrentAuthorityInventory",
  "IStreamCurrentAuthorityPreservationPolicyPublicationFactoryV1",
  "IStreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1",
  "IStreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1",
  "IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1",
  "IStreamExternalArtifactCoverage",
  "IStreamExternalArtifactCurrentPair",
  "IStreamFinalityArtifactCoverage",
  "IStreamFinalityCurrentEntropyRoute",
  "IStreamFinalityEntropyPolicySourceSet",
  "IStreamFinalityPreservationFactoryProfileSourcesV1",
  "IStreamFinalityScopeMembership",
  "IStreamFinalityScopedEntropyPolicySourceFactoryV2",
  "IStreamFinalityViewPreservationBindingV1",
  "IStreamFinalityViewPreservationCompleteBindingV1",
  "IStreamGasParameterHost",
  "IStreamGovernanceActionFacts",
  "IStreamGovernanceCatalog",
  "IStreamGovernanceExecution",
  "IStreamGovernanceExecutor",
  "IStreamGovernanceReads",
  "IStreamMetadataRouter",
  "IStreamMetadataServingFacts",
  "IStreamModule",
  "IStreamModuleRegistry",
  "IStreamPreservationAttributionV1",
  "IStreamPreservationPolicyContentCheckpointV1",
  "IStreamPreservationPolicyContentRootPublicationV1",
  "IStreamPreservationPolicyOutputEvidenceBindingV1",
  "IStreamPreservationPolicyOutputManifestV1",
  "IStreamPreservationPolicyPublicationFactoryV1",
  "IStreamPreservationPolicyPublicationGraphBindingV1",
  "IStreamPreservationPolicyReferencePublicationV1",
  "IStreamPreservationPolicyRenderCriticalInventoryV1",
  "IStreamPreservationPolicySnapshotPublicationV1",
  "IStreamPreservationRegistryV1",
  "IStreamPreservationRendererV1",
  "IStreamRecordCurrentAuthority",
  "IStreamReferenceEnvironmentPreparation",
  "IStreamReferenceInventoryPreparation",
  "IStreamRenderCriticalInventory",
  "IStreamRendererRegistry",
  "IStreamRightsRecordCurrentAuthority",
  "IStreamRoleRegistry",
  "IStreamScopedBundleArchiveCoverage",
  "IStreamScopedContentRootPublication",
  "IStreamScopedPreservationPolicyBundleArchiveCoverageV1",
  "IStreamScopedPreservationPolicyContentRootEvidenceBindingV1",
  "IStreamScopedPreservationPolicyContentRootPublicationV1",
  "IStreamScopedPreservationPolicyPublicationEvidenceBindingV1",
  "IStreamScopedPreservationPolicyPublicationFactoryV1",
  "IStreamScopedPreservationPolicyReferencePublicationV1",
  "IStreamScopedPreservationPolicyRenderCriticalInventoryV1",
  "IStreamScopedPreservationPolicySnapshotPublicationV1",
  "IStreamStaticEntropySource",
  "IStreamStaticSelectionCheckpoint",
  "IStreamViewPolicySourceBindingV2",
  "IStreamViewPreservationBundleArchiveCoverageV1",
  "IStreamViewPreservationContentCheckpointV1",
  "IStreamViewPreservationContentRootV1",
  "IStreamViewPreservationEvidenceBindingV1",
  "IStreamViewPreservationFinalitySourcesV1",
  "IStreamViewPreservationOutputManifestV1",
  "IStreamViewPreservationReferencePublicationV1",
  "IStreamViewPreservationRenderCriticalInventoryV1",
  "IStreamViewPreservationRendererV1",
  "IStreamViewPreservationSnapshotPublicationV1",
  "IStreamViewRouteReadBudgetV1",
  "IStreamViewSourceBinding",
  "StreamArchivalCoverage",
  "StreamArtistAcceptanceLifecycle",
  "StreamArtistArchiveOriginReads",
  "StreamArtistArchiveV2",
  "StreamArtistAttributionLifecycle",
  "StreamArtistBindingLifecycle",
  "StreamArtistCollaboratorLifecycle",
  "StreamArtistConsentFinalityLifecycle",
  "StreamArtistCurrentAuthorityResolver",
  "StreamArtistIdentityAuthority",
  "StreamArtistOnboardingCoordinator",
  "StreamArtistOnboardingRegistry",
  "StreamArtistPayoutLifecycle",
  "StreamCollectionMetadataV1",
  "StreamCollectionViews",
  "StreamCore",
  "StreamCurrentArtistPreservationAttributionV1",
  "StreamCurrentArtistPreservationRendererV1",
  "StreamCurrentAuthorityConservationRecordSelection",
  "StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1",
  "StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1",
  "StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1",
  "StreamCurrentAuthorityPreservationPolicyPublicationFactoryV1",
  "StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1",
  "StreamCurrentAuthorityRightsRecordSelection",
  "StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1",
  "StreamCurrentAuthorityScopedPreservationPolicyPublicationFactoryV1",
  "StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1",
  "StreamCurrentAuthorityWorkRecordSelection",
  "StreamExternalArtifactCoverage",
  "StreamFinalityArtifactCoverage",
  "StreamFinalityEntropyPolicySourceSet",
  "StreamFinalityFullPreservationPolicyDiscoveryV1",
  "StreamFinalityFullPreservationPolicyEvidenceProviderV1",
  "StreamFinalityScopeMembership",
  "StreamFinalityScopedEntropyPolicySourceFactoryV2",
  "StreamGovernanceBootstrap",
  "StreamGovernanceExecutor",
  "StreamMetadataRouter",
  "StreamModuleRegistry",
  "StreamPreservationAttributionCompanion",
  "StreamPreservationPolicyContentCheckpointV2",
  "StreamPreservationPolicyOutputManifestV2",
  "StreamPreservationPolicyPublicationFactoryV1",
  "StreamPreservationPolicyReferencePublicationV2",
  "StreamPreservationPolicySnapshotPublicationV2",
  "StreamPreservationRendererV1",
  "StreamRenderCriticalInventory",
  "StreamRendererRegistry",
  "StreamRoleRegistry",
  "StreamSchemaDocumentStore",
  "StreamSchemaRegistry",
  "StreamScopedPreservationPolicyContentCheckpointV2",
  "StreamScopedPreservationPolicyPublicationFactoryV1",
  "StreamScopedPreservationPolicyReferencePublicationV2",
  "StreamScopedPreservationPolicySnapshotPublicationV2",
  "StreamStaticSelectionCheckpoint",
  "StreamTerminalEntropyReadiness",
  "StreamViewPreservationBundleArchiveCoverageV1",
  "StreamViewPreservationContentCheckpointV1",
  "StreamViewPreservationOutputManifestV1",
  "StreamViewPreservationReferencePublicationV1",
  "StreamViewPreservationRenderCriticalInventoryV1",
  "StreamViewPreservationRendererV1",
  "StreamViewPreservationSnapshotPublicationV1"
];

function bindAllGitLiterals(input, bridge) {
  const entries = Object.entries(input.sources).sort(([a], [b]) => order(a, b));
  if (entries.some(([path, source]) => /[\r\n]/.test(path) || typeof source.content !== "string")) {
    throw Error("Invalid compiler source literal");
  }
  const blobs = execFileSync("git", ["cat-file", "--batch"], {
    cwd: repositoryRoot,
    input: entries.map(([path]) => SOURCE + ":" + path + "\n").join(""),
    maxBuffer: 128 * 1024 * 1024,
  });
  let cursor = 0, literalBytes = 0;
  for (const [path, source] of entries) {
    const end = blobs.indexOf(10, cursor), header = blobs.subarray(cursor, end).toString("ascii");
    const size = Number(header.split(" ")[2]);
    if (end < cursor || !header.includes(" blob ") || !Number.isSafeInteger(size) || size < 0) {
      throw Error("Missing frozen source " + path);
    }
    const bytes = blobs.subarray(end + 1, end + 1 + size);
    if (!bytes.equals(Buffer.from(source.content, "utf8"))) throw Error("Compiler/Git bytes differ: " + path);
    if (bridge.committedBlobSHA256[path] !== sha(bytes)) throw Error("Bridge/Git hash differs: " + path);
    cursor = end + size + 2;
    literalBytes += size;
  }
  if (cursor !== blobs.length || literalBytes !== 46_592_135) throw Error("Frozen literal inventory differs");
}

export function currentPreservationV2Fixture(inputBytes, outputBytes, bridgeBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact ABI146 input/output");
  if (sha(bridgeBytes) !== BRIDGE_SHA) throw Error("Expected exact ABI146 committed source bridge");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), bridge = JSON.parse(bridgeBytes);
  if (bridge.commit !== SOURCE || bridge.sources !== 3914
    || Object.keys(bridge.committedBlobSHA256 ?? {}).length !== 3914
    || !Array.isArray(bridge.mismatches) || bridge.mismatches.length !== 0) throw Error("Invalid committed source bridge");
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 3914
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid current preservation ABI146 capture");
  if (execFileSync("git", ["rev-parse", SOURCE + "^{tree}"], { cwd: repositoryRoot, encoding: "utf8" }).trim() !== TREE) throw Error("Frozen tree differs");
  bindAllGitLiterals(input, bridge);
  const abis = {}, selections = {}, methodIdentifiers = {}, sourceHashes = {}, sourceTexts = {};
  const libraryAbis = {}, librarySelections = {}, libraryMethodIdentifiers = {};
  const candidates = Object.entries(output.contracts).filter(([path]) => path.startsWith("smart-contracts/"));
  function visit(path) {
    if (Object.hasOwn(sourceHashes, path)) return;
    const source = input.sources[path]?.content;
    if (typeof source !== "string") throw Error("Missing source " + path);
    sourceHashes[path] = sha(source);
    sourceTexts[path] = source;
    for (const imported of solidityImports(source)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  function kind(path, name) {
    // Names come exclusively from the exact compiler result. Declarations are
    // lexically checked to keep nominal library selectors out of wallet ABIs.
    const text = input.sources[path].content.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\r\n]*/g, "");
    const matches = [...text.matchAll(/\b(contract|interface|library)\s+([A-Za-z_][A-Za-z0-9_]*)\b/g)]
      .filter(match => match[2] === name);
    if (matches.length !== 1) throw Error("Ambiguous declaration kind: " + name);
    return matches[0][1];
  }
  function select(path, name, contract, nominal) {
    if (!Array.isArray(contract.abi)) throw Error("Missing full ABI " + name);
    if (Object.hasOwn(abis, name) || Object.hasOwn(libraryAbis, name)) return;
    const selected = { source: path, contract: name, full: true };
    if (nominal) {
      libraryAbis[name] = contract.abi;
      librarySelections[name] = { ...selected, nominal: true };
      libraryMethodIdentifiers[name] = contract.evm?.methodIdentifiers ?? {};
    } else {
      abis[name] = contract.abi;
      selections[name] = selected;
      methodIdentifiers[name] = contract.evm?.methodIdentifiers ?? {};
    }
    visit(path);
  }
  for (const name of roots) {
    const matches = candidates.filter(([, entries]) => Object.hasOwn(entries, name));
    if (matches.length !== 1) throw Error("Expected one compiled " + name);
    const [path, entries] = matches[0];
    select(path, name, entries[name], kind(path, name) === "library");
  }
  // Preserve the raw ABI of the relevant family, origin and VIEW workers.
  // Other imported libraries retain their exact source in the shared closure.
  // Nominal library selectors are source evidence, never wallet targets.
  const libraryWitness = /Preservation|ArtistArchiveOrigin|CurrentAuthorityInventory|CurrentAuthorityBundleArchive|MultiOrigin|FinalityView|ViewSourceTypes/;
  for (const [path, entries] of candidates) {
    if (!Object.hasOwn(sourceTexts, path)) continue;
    for (const [name, contract] of Object.entries(entries)) {
      if (libraryWitness.test(name) && kind(path, name) === "library") select(path, name, contract, true);
    }
  }
  const paths = execFileSync("git", ["ls-tree", "-r", "--name-only", SOURCE, "--", "docs", "schemas"], { cwd: repositoryRoot, encoding: "utf8" })
    .trim().split("\n");
  const extraDocuments = new Set([
    "docs/adr/0004-admin-governance.md",
    "docs/adr/0054-explicit-non-sanction-preservation-rendering.md",
    "docs/integrations/current-authority-rights-selection.md",
    "docs/guides/static-artist-current-authority.md",
    "docs/integrations/artist-content.md",
    "docs/guides/preservation-inventory.md",
    "docs/guides/native-reference-render.md",
    "docs/guides/external-object-archive.md",
  ]);
  const documents = paths.filter(path =>
    extraDocuments.has(path)
    || path.startsWith("docs/integrations/") && /(?:preservation|view-(?:source|policy|current|checkpoint|content))/.test(path)
    || path.startsWith("docs/schemas/preservation/") && /(?:preservation-policy|scoped-preservation-policy)/.test(path)
    || path.startsWith("schemas/metadata/view-preservation-")
    || path.startsWith("schemas/preservation/view-preservation-")
    || /^schemas\/records\/[^/]+\.json$/.test(path)
  ).sort(order);
  for (const path of extraDocuments) if (!documents.includes(path)) throw Error("Missing supporting document: " + path);
  const retainedDocuments = {};
  for (const path of documents) {
    const bytes = execFileSync("git", ["show", SOURCE + ":" + path], { cwd: repositoryRoot, maxBuffer: 4 * 1024 * 1024 });
    const text = bytes.toString("utf8");
    if (!Buffer.from(text, "utf8").equals(bytes)) throw Error("Invalid UTF-8 document " + path);
    retainedDocuments[path] = { sha256: sha(bytes), byteLength: bytes.length, text };
  }
  const sorted = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => order(a, b)));
  return {
    schemaVersion: 1,
    profile: "current-preservation-v2-and-complete-view",
    capture: "parallel-feature-batch146-20260921",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 3914,
    compilerReportedCommit: SOURCE,
    committedSourceBridge: { sha256: sha(bridgeBytes), ...bridge },
    literalBytes: 46_592_135,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "Every compiler input literal matches its frozen Git blob byte-for-byte; this verifier performs no line-ending normalization. All selected ABIs are complete compiler output, with one full imported source closure shared across related client batches. Interpretation documents come from the same source commit.",
    qualification: "Exact ABI146 source/ABI witness for current token preservation V2, current-authority preservation graphs and shared complete VIEW binding at 9381dd99. Fixture inclusion alone does not imply client workflow coverage. Token family V2, original and current-Artist row producer profiles, and VIEW remain distinct admission domains. Historical ABI129 clients retain their original fixtures. C/Burn/Prepared current VIEW finality dispatch remains pending and is not supplied by this witness. No actual native/Safe execution, runtime provenance, rollback, gas/capacity, release or deployment acceptance is established by this fixture.",
    sourceHashes: sorted(sourceHashes),
    sourceTexts: sorted(sourceTexts),
    documents: retainedDocuments,
    selections: sorted(selections),
    methodIdentifiers: sorted(methodIdentifiers),
    abis: sorted(abis),
    librarySelections: sorted(librarySelections),
    libraryMethodIdentifiers: sorted(libraryMethodIdentifiers),
    libraryAbis: sorted(libraryAbis),
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, bridge, mode] = process.argv.slice(2);
  if (!input || !output || !bridge || mode !== undefined && mode !== "--check") {
    throw Error("Usage: generate-current-preservation-v2-fixture.mjs INPUT OUTPUT COMMITTED_SOURCE_BRIDGE [--check]");
  }
  const rendered = JSON.stringify(currentPreservationV2Fixture(await readFile(input), await readFile(output), await readFile(bridge)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-preservation-v2-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale shared current preservation V2 fixture");
    process.stdout.write("Shared current preservation V2 fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Shared current preservation V2 fixture written\n");
  }
}
