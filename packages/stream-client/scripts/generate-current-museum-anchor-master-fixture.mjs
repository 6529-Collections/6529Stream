// Project retained ABI94 and frozen interpretation bytes without invoking a compiler.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "e558addd5ce1aee15d7ac327482b3822289d3dc7";
const TREE = "22ce31e8d8bcc519989b580214860f85020e9e8a";
const INPUT_SHA = "f083e371f3a3e80182194794579338e1bf6d01e44713b78f41fe1af5ceed725d";
const OUTPUT_SHA = "4be8ef1f2eec2cebdef60f5dd78756948b4b64de9538edb2b49f672bf7a2bc90";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const contracts = {
  core: "StreamCore",
  coreCondition: "IStreamCoreConditionSources",
  coreFloor: "IStreamCoreConservationFloor",
  coreTier: "IStreamCoreConservationTier",
  metadata: "StreamCollectionMetadataV1",
  metadataInterface: "IStreamCollectionMetadataV1",
  tier: "IStreamConservationTier",
  conditionSources: "StreamConditionSources",
  conditionInterface: "IStreamConditionSources",
  floorInterface: "IStreamConservationFloor",
  master: "StreamMediaMasterSelection",
  masterInterface: "IStreamMediaMasterSelection",
  preservation: "IStreamPreservationRecords",
  recordReceipts: "IStreamCollectionRecordReceipts",
  schemas: "StreamSchemaRegistry",
  schemaFacts: "IStreamSchemaDocumentFacts",
  store: "StreamSchemaDocumentStore",
  manifestReads: "IStreamCollectionManifestReads",
  servingFacts: "IStreamMetadataServingFacts",
  coverage: "IStreamExternalArtifactCoverage",
  artistIngress: "IStreamArtistIngressBinding",
  artistPublication: "IStreamArtistRecordPublication",
  artistOwner: "IStreamArtistOwner",
  artistSuite: "IStreamArtistSuiteReads",
  identity: "IStreamArtistIdentityOwner",
  binding: "IStreamArtistBindingOwner",
  attribution: "IStreamArtistAttributionOwner",
  publication: "IStreamArtistRecordPublicationOwner",
  gasParameters: "IStreamGasParameterHost",
  executor: "StreamGovernanceExecutor",
  roleRegistry: "StreamRoleRegistry",
  modules: "StreamModuleRegistry",
};
const oracleNames = [
  "StreamCoreMuseumReads", "StreamCoreExternalReads", "StreamCoreTypes",
  "StreamConservationTiers", "StreamConservationTierExecution", "StreamMediaMasterTypes",
  "StreamMediaMasterDefinitions", "StreamMasterWaiverJson", "StreamMediaMasterReads",
  "StreamMediaMasterPublicationReads", "StreamConservationRecordContext",
  "StreamConservationRecordFields", "StreamConservationRecordTypes", "StreamRecordJson",
  "StreamRecordFamilies", "StreamRecordArtistIdentityReads", "StreamCollectionRecordHashes",
  "StreamWorkRecordDefinitions", "StreamMetadataSubjects", "StreamCollectionManifestTypes",
  "StreamArtistRecordPublicationTypes", "StreamArtistOnboardingTypes", "StreamExternalArtifactTypes",
  "StreamGovernanceBootstrap", "StreamGovernanceScheduling", "StreamGovernancePolicy",
  "StreamGovernanceActionPolicy", "StreamGovernanceTypes",
];
const testPaths = [
  "test/unit/core/StreamCoreMuseumAnchors.t.sol",
  "test/unit/core/StreamCoreConservationFloor.t.sol",
  "test/unit/metadata/StreamConservationTier.t.sol",
  "test/unit/metadata/StreamConditionSources.t.sol",
  "test/unit/metadata/StreamMasterWaiverJson.t.sol",
  "test/unit/metadata/StreamMediaMasterSelection.t.sol",
];
const documentPaths = [
  "schemas/records/STREAM_MEDIA_MASTER_ASSOCIATION_V1.json",
  "schemas/records/STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1.json",
  "schemas/records/STREAM_MASTER_WAIVER_V1.json",
  "schemas/museum/account-profile/RFC8785_JCS.json",
  "schemas/records/examples/genesis-preservation/master-waiver.json",
  "schemas/records/examples/genesis-preservation/media-master-association.json",
];

export function museumAnchorMasterFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact retained ABI94 input/output");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2557
      || output.errors?.some(e => e.severity === "error")) throw Error("Invalid frozen Museum capture");
  const abis = {}, selections = {}, sourceHashes = {}, sourceTexts = {}, documents = {};
  function visit(path) {
    if (sourceHashes[path]) return;
    const source = input.sources[path]?.content;
    if (typeof source !== "string") throw Error(`Missing source ${path}`);
    sourceHashes[path] = sha(source);
    for (const imported of solidityImports(source)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  for (const [key, contract] of Object.entries(contracts)) {
    const matches = Object.entries(output.contracts).filter(([path, values]) => path.startsWith("smart-contracts/") && values[contract]);
    if (matches.length !== 1) throw Error(`Expected one compiled ${contract}`);
    const [source, values] = matches[0];
    const abi = values[contract].abi;
    if (!Array.isArray(abi)) throw Error(`Missing ABI ${contract}`);
    selections[key] = { source, contract, full: true, capture: "museum" };
    abis[key] = abi;
  }
  const oracles = oracleNames.map(name => {
    const matches = Object.keys(input.sources).filter(path => path.endsWith(`/${name}.sol`));
    if (matches.length !== 1) throw Error(`Expected one source for ${name}`);
    return matches[0];
  });
  for (const path of [...new Set([...Object.values(selections).map(s => s.source), ...oracles, ...testPaths])].sort()) {
    visit(path); sourceTexts[path] = input.sources[path].content;
  }
  // Exact checked-in definitions/examples supplement Solidity literals. No working-tree
  // document can silently replace the version used by this immutable profile.
  for (const path of documentPaths) {
    const bytes = execFileSync("git", ["show", `${SOURCE}:${path}`], { maxBuffer: 1024 * 1024 });
    const text = bytes.toString("utf8");
    if (!Buffer.from(text, "utf8").equals(bytes)) throw Error(`Invalid UTF-8 document ${path}`);
    documents[path] = { sha256: sha(bytes), byteLength: bytes.length, text };
  }
  return {
    schemaVersion: 1, profile: "museum-anchor-master-v1", capture: "parallel-feature-batch94-20260920",
    compilerVersion: "0.8.19", sourceCommit: SOURCE, sourceTree: TREE, sourceCount: 2557,
    inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "Every one of the 2557 retained compiler input literals independently matches the frozen Git source byte-for-byte. Interpretation documents are read from that exact commit, never the working tree.",
    producerLineage: {
      originalAnchorProducer: "f7a05e0734b95f1e2ff1a038b73511c0d94b6f81",
      originalCoreAnchors: "758572df4e7f3969f549dd58aef0c369202e2b27",
      masterProducer: "7dca015920f2aaa0511b8ef4b4a56785e9321be8",
      masterIntegration: "c1c169d5171f870cc85477a769896936aecf12d4",
      laterCoreFloorBinding: "ff372f80b830b45a6afb30583780414f3abcc4cc",
      laterCoreFloorTests: "734775e8898dff191d8ceadb31326e7157aae468",
    },
    separateRuntimeEvidence: {
      testOnlyCorrection: "d35ea3b4091c8b7d4e2016bff0bb240839a2e327",
      tests: 51, suites: { coreAnchors: 18, conditionCatalog: 12, conservationTier: 21 },
      testResultsSha256: "ee6e767cdddce12df87451b0e9402150bc2ab0b9b8c32ce3d0d2f2bf675a04f4",
      qualification: "The separately retained museum-anchors-native2 summary reports 51 successes with unchanged 138 production inputs, 149 production products and no size overages. That original anchor/catalog/tier graph precedes the later Core floor binding and media-master implementation; it does not establish runtime acceptance of this joined client profile.",
    },
    separateMasterRuntimeEvidence: {
      testOnlyCorrection: "0aed46a1",
      tests: 47, suites: { coreFloorBinding: 14, masterSelection: 13, masterWaiverJson: 4, saleRights: 16 },
      mainTestResultsSha256: "0705a25890c23c775e9996887e829255daf3181b5993444073d965559e313caf",
      rightsTestResultsSha256: "f187b0b3bf4d07d2d8e3d33d7ab7609ddb983cd8647de10e564922258bc1f866",
      qualification: "The separately retained master-rights-native3 summary reports 47 successes over 198 sources with all 185 production inputs unchanged from native2 and all 88 nonempty production artifacts within size limits. This cohort covers the pinned later Core floor binding, masters, waiver JSON and separate sale rights; it excludes later provider, paid-floor ledger, actual Artist, DIRECT and joined Router acceptance, and does not establish whole-system readiness.",
    },
    qualification: "Source/ABI and mocked client evidence only. Permanent condition/floor anchor binding, durable tier declarations and original media-master/publication/waiver workflows are separate from the still-in-flight paid-floor ledger, direct receipt and settlement batch. Earlier native 51-case evidence predates the later Core floor binding and is not relabeled as acceptance of this complete joined graph. Existing client fixtures remain immutable.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts, documents, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || mode !== undefined && mode !== "--check") throw Error("Usage: generate-current-museum-anchor-master-fixture.mjs INPUT OUTPUT [--check]");
  const rendered = JSON.stringify(museumAnchorMasterFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-museum-anchor-master-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale Museum anchor/master fixture");
  } else await writeFile(target, rendered, "utf8");
}
