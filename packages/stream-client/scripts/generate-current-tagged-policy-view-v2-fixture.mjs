// Retain the exact ABI125 tagged policy VIEW source. Never invoke Solidity.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "00686b799ccf60713a0a30e1e81fca0c7281912d";
const TREE = "1778378447b903f7d5ebef38d77782881438e656";
const INPUT_SHA = "5d22ce424636139d7768697a3d43aefad617e3b97f33e56eceaed34d05f38201";
const OUTPUT_SHA = "a6a1663fc334ad82ddb6a0760d92106092d217d8dab9e45be638c8100128d047";
const BRIDGE_SHA = "0bd6810dd83da8f150af8a38077b730192804e35c12c7a910ebd68bc9fcfc1d3";
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const contracts = {
  "router": "StreamMetadataRouter",
  "viewRouter": "IStreamViewAdoptionRouter",
  "policyRouter": "IStreamViewAdoptionPolicyRouterV2",
  "rendererV1": "StreamViewRendererV1",
  "rendererV2": "StreamViewRendererV2",
  "rendererInterface": "IStreamViewRendererV2",
  "originalRendererInterface": "IStreamViewRendererV1",
  "staticRouter": "IStreamStaticMetadataRouter",
  "provider": "StreamFinalityPolicyViewEvidenceProvider",
  "providerBinding": "IStreamViewPolicySourceBindingV2",
  "viewSourceBinding": "IStreamViewSourceBinding",
  "membership": "StreamFinalityScopeMembership",
  "membershipInterface": "IStreamFinalityScopeMembership",
  "scopedFactory": "StreamFinalityScopedEntropyPolicySourceFactoryV2",
  "scopedFactoryInterface": "IStreamFinalityScopedEntropyPolicySourceFactoryV2",
  "sourceSet": "StreamFinalityEntropyPolicySourceSet",
  "sourceSetInterface": "IStreamFinalityEntropyPolicySourceSet",
  "inventory": "StreamFinalityCoordinatorInventory",
  "core": "StreamCore",
  "coreIdentity": "IStreamCoreIdentity",
  "coreCollection": "IStreamCoreCollectionView",
  "corePointers": "IStreamCorePointers",
  "metadata": "StreamCollectionMetadataV1",
  "metadataInterface": "IStreamCollectionMetadataV1",
  "views": "StreamCollectionViews",
  "viewsInterface": "IStreamCollectionViews",
  "modules": "StreamModuleRegistry",
  "moduleInterface": "IStreamModuleRegistry",
  "registry": "StreamRendererRegistry",
  "registryInterface": "IStreamRendererRegistry",
  "schemas": "StreamSchemaRegistry",
  "store": "StreamSchemaDocumentStore",
  "finality": "StreamArtworkFinalityRegistry",
  "finalityInterface": "IStreamArtworkFinalityRegistry",
  "finalityBindings": "IStreamFinalityDeploymentBindings",
  "finalityEvidence": "IStreamFinalityEvidenceProvider",
  "gas": "IStreamGasParameterHost",
  "artistContentAuthority": "IStreamArtistContentAuthority",
  "artistFinalityBinding": "IStreamArtistFinalityBinding",
  "policyFacts": "IStreamEntropyPolicyStaticRead",
  "entropy": "StreamEntropyCoordinator",
  "staticEntropy": "IStreamStaticEntropySource",
  "erc165": "IERC165",
  "artistRegistry": "StreamArtistOnboardingRegistry",
  "artistConsentOwner": "StreamArtistConsentFinalityLifecycle",
  "artistContentOwner": "IStreamArtistContentRecordsOwner",
  "artistRatification": "IStreamArtistContentRatification",
  "artistSuite": "IStreamArtistSuiteReads"
};
// Solidity library selectors retain nominal enum types; never rewrite these
// compiler ABIs into public-contract tuples for ethers or wallet call plans.
const libraryContracts = {
  formatter: "StreamViewRendererEncodingV2",
  adoptionWorker: "StreamViewAdoptionV2",
  legacyAdoptionWorker: "StreamViewAdoption",
};
const documents = [
  "docs/adr/0006-metadata-freeze.md",
  "docs/adr/0039-canonical-finality-governance-and-evidence.md",
  "docs/adr/0040-current-metadata-record-host.md",
  "docs/adr/0041-typed-finality-evidence-provider.md",
  "docs/integrations/tagged-policy-view-v2.md",
  "docs/integrations/adopted-static-views.md",
  "docs/integrations/scoped-policy-source-factory-v2.md",
  "docs/integrations/scoped-policy-preservation-v2.md",
  "docs/integrations/static-renderer-versions.md",
  "docs/integrations/static-metadata-routing.md",
  "docs/integrations/current-static-token-rendering.md",
  "docs/integrations/artist-static-display.md",
  "docs/integrations/collection-views.md",
  "docs/integrations/view-current-source-reader.md"
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
  if (cursor !== blobs.length || literalBytes !== 37_016_570) throw Error("Frozen literal inventory differs");
}

export function taggedPolicyViewV2Fixture(inputBytes, outputBytes, bridgeBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact ABI125 input/output");
  if (sha(bridgeBytes) !== BRIDGE_SHA) throw Error("Expected exact ABI125 committed source bridge");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), bridge = JSON.parse(bridgeBytes);
  if (bridge.commit !== SOURCE || bridge.sources !== 3146
    || Object.keys(bridge.committedBlobSHA256 ?? {}).length !== 3146
    || !Array.isArray(bridge.mismatches) || bridge.mismatches.length !== 0) throw Error("Invalid committed source bridge");
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 3146
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid tagged policy VIEW V2 capture");
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
    profile: "tagged-policy-view-v2",
    capture: "parallel-feature-batch125-20260920",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 3146,
    compilerReportedCommit: "00686b799ccf60713a0a30e1e81fca0c7281912d",
    committedSourceBridge: { sha256: sha(bridgeBytes), ...bridge },
    literalBytes: 37_016_570,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "Every compiler input literal matches its frozen Git blob byte-for-byte; this verifier performs no line-ending normalization. All selected ABIs are complete compiler output, with the full imported source closure. Interpretation documents come from the same source commit.",
    qualification: "Source/ABI and mocked client evidence for the original tagged full-policy VIEW V2 adoption and serving routes. Original V1 records, domains and shared history retain their interpretation. Operational scope uses actual Router adoption, preview, profile, history and rendering methods with original Metadata writer authority and Artist operation-17 consent. Provider binding, scoped factory and source-set observations use existing integrated APIs. This profile does not invent missing VIEW checkpoint, snapshot, reference, archive or complete finality ceremonies. Native/Safe execution, deployed-runtime identity, whole-call rollback, gas/capacity and release acceptance remain separately qualified.",
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
    throw Error("Usage: generate-current-tagged-policy-view-v2-fixture.mjs INPUT OUTPUT COMMITTED_SOURCE_BRIDGE [--check]");
  }
  const rendered = JSON.stringify(taggedPolicyViewV2Fixture(await readFile(input), await readFile(output), await readFile(bridge)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-tagged-policy-view-v2-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale tagged policy VIEW V2 fixture");
    process.stdout.write("Tagged policy VIEW V2 fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Tagged policy VIEW V2 fixture written\n");
  }
}
