// Focused exact ABI167 witness for Artist recovered MULTIPLE_BASE clients.
// Never invokes Solidity, modifies captures, or refreshes historical fixtures.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { readFileSync } from "node:fs";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "99e9503020ea713b558835ac6fe1a034e36994a2";
const TREE = "21c4a573e18deea66f8030fcea5def18b792af66";
const INPUT_SHA = "6826e1482fdeace25c09fb7b2f5f329c61ec53b3eef5401d70f9553feed15d85";
const OUTPUT_SHA = "969365148c64364db453c12df6a52d188c7ab936fa6f33691247b83b523edd13";
const BRIDGE_SHA = "a905a9dcce552f96a37643ff3d2ac5823f4e89b108d62599c17544b483b4eb67";
const PRODUCER = "28ef1f012b414f8a215a96708066ce13549e4dd0";
const PRODUCER_TREE = "3cec4932b93f1882df230136b6ddcf96117d453d";
const HANDOFF_SHA = "8800d8bb3b27112e067c8d14cabbfb337301b53199a73e53f1a9441cec704e84";
const PRODUCER_BRIDGE_SHA = "cd82cfacf9f2b60e86a2d0627f1ac3bf94fdfd89e08e58a643e9549abc6da858";
const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const aliases = {
  "registry": "StreamArtistOnboardingRegistry",
  "coordinator": "StreamArtistOnboardingCoordinator",
  "reads": "StreamArtistOnboardingReads",
  "archive": "StreamArtistArchiveV2",
  "owner": "StreamArtistOwner",
  "binding": "StreamArtistBindingLifecycle",
  "collaborator": "StreamArtistCollaboratorLifecycle",
  "identity": "StreamArtistIdentityAuthority",
  "acceptance": "StreamArtistAcceptanceLifecycle",
  "attribution": "StreamArtistAttributionLifecycle",
  "payout": "StreamArtistPayoutLifecycle",
  "consent": "StreamArtistConsentFinalityLifecycle",
  "checkpoint": "IStreamArtistAuthorityCheckpoint",
  "recovered": "IStreamArtistRecoveredHydration",
  "recoveredCoordinator": "IStreamArtistRecoveredHydrationCoordinator",
  "recoveredOwner": "IStreamArtistRecoveredHydrationOwner",
  "chronology": "IStreamArtistRecoveredNativeChronology",
  "hydrationOwner": "IStreamArtistAuthorityHydrationOwner",
  "hydrationCoordinator": "IStreamArtistAuthorityHydrationCoordinator",
  "history": "IStreamArtistHistory",
  "nativeReceipts": "IStreamArtistNativeReceipts",
  "reconstruction": "IStreamArtistReconstruction",
  "suite": "IStreamArtistSuiteReads",
  "ingress": "IStreamArtistIngressBinding",
  "timing": "IStreamArtistRecoveredTimingInventory",
  "timingWorker": "StreamArtistRecoveredTimingInventory",
  "prepared": "StreamArtistRecoveredHydrationPrepared",
  "admission": "StreamArtistRecoveredHydrationAdmission",
  "source": "StreamArtistRecoveredHydrationSource",
  "provenance": "StreamArtistRecoveredHydrationProvenance",
  "guards": "StreamArtistRecoveredHydrationGuards",
  "codec": "StreamArtistRecoveredHydrationCodec",
  "payload": "StreamArtistRecoveredHydrationOwnerPayload",
  "commit": "StreamArtistRecoveredHydrationCommit",
  "evidence": "StreamArtistRecoveredHydrationEvidence",
  "external": "StreamArtistRecoveredExternalGuards",
  "publications": "StreamArtistRecoveredPayloadHydration",
  "witnesses": "StreamArtistRecoveredRecordWitnesses",
  "core": "IStreamCorePointers",
  "coreHost": "StreamCore",
  "governanceFacts": "IStreamGovernanceActionFacts",
  "finalityRecovery": "IStreamArtworkFinalityRecovery",
  "finalityBinding": "IStreamFinalityRecoveryGovernanceBinding",
  "entropyUnavailability": "IStreamEntropyArtistUnavailability",
  "entropyFreshRecovery": "IStreamEntropyFreshRecovery",
  "personhood": "IStreamArtistPersonhoodEvidence",
  "recoveredConsents": "IStreamArtistRecoveredConsentHydration",
  "recoveredConsentsCoordinator": "IStreamArtistRecoveredConsentHydrationCoordinator",
  "contentHydration": "StreamArtistRecoveredContentConsentHydration",
  "contentReads": "StreamArtistRecoveredContentConsentReads",
  "contentValidation": "StreamArtistRecoveredContentConsentValidation",
  "contentFacts": "StreamArtistRecoveredContentConsentFacts",
  "contentFactRows": "StreamArtistRecoveredContentConsentFactRows",
  "contentRecords": "IStreamArtistContentRecordsOwner",
  "consentOwner": "IStreamArtistConsentOwner",
  "delegatedConsentOwner": "IStreamArtistDelegatedConsentOwner",
  "delegatedPolicySale": "IStreamArtistDelegatedPolicySaleConsentOwner",
  "saleConsentOwner": "IStreamArtistSaleConsentOwner",
  "multiple": "StreamArtistRecoveredMultipleCodec",
  "multiplePreparation": "StreamArtistRecoveredMultiplePreparation",
  "multipleOwners": "StreamArtistRecoveredMultipleOwners",
  "multipleTypes": "StreamArtistRecoveredMultipleTypes",
  "multipleNonces": "StreamArtistRecoveredMultipleIdentityNonces",
  "multipleIdentity": "StreamArtistRecoveredMultipleIdentitySource",
  "multipleCollections": "StreamArtistRecoveredMultipleCollectionSource"
};
const roots = [...new Set(Object.values(aliases))];

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
    if (end < cursor || !/^[0-9a-f]+ blob [0-9]+$/.test(header) || !Number.isSafeInteger(size) || size < 0) {
      throw Error("Missing frozen source " + path);
    }
    const bytes = blobs.subarray(end + 1, end + 1 + size);
    if (blobs[end + 1 + size] !== 10) throw Error("Invalid Git batch framing");
    if (!bytes.equals(Buffer.from(source.content, "utf8"))) throw Error("Compiler/Git bytes differ: " + path);
    if (bridge.committedBlobSHA256[path] !== sha(bytes)) throw Error("Bridge/Git hash differs: " + path);
    cursor = end + size + 2;
    literalBytes += size;
  }
  if (cursor !== blobs.length || literalBytes !== 48_869_757) throw Error("Frozen literal inventory differs");
}

export function artistRecoveredMultipleHydrationFixture(inputBytes, outputBytes, bridgeBytes, handoffBytes, producerBridgeBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact ABI167 input/output");
  if (sha(bridgeBytes) !== BRIDGE_SHA) throw Error("Expected exact ABI167 committed source bridge");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), bridge = JSON.parse(bridgeBytes);
  if (bridge.commit !== SOURCE || bridge.sources !== 4138
    || Object.keys(bridge.committedBlobSHA256 ?? {}).length !== 4138
    || !Array.isArray(bridge.mismatches) || bridge.mismatches.length !== 0) throw Error("Invalid committed source bridge");
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 4138
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid current preservation ABI167 capture");
  if (execFileSync("git", ["rev-parse", SOURCE + "^{tree}"], { cwd: repositoryRoot, encoding: "utf8" }).trim() !== TREE) throw Error("Frozen tree differs");
  bindAllGitLiterals(input, bridge);
  if (sha(handoffBytes) !== HANDOFF_SHA || sha(producerBridgeBytes) !== PRODUCER_BRIDGE_SHA) throw Error("Producer evidence differs");
  const handoff = JSON.parse(handoffBytes), producerBridge = JSON.parse(producerBridgeBytes);
  if (handoff.commit !== PRODUCER || handoff.sourceBridgeSHA256 !== PRODUCER_BRIDGE_SHA) throw Error("Producer handoff identity differs");
  const git = args => execFileSync("git", args, { cwd: repositoryRoot, maxBuffer: 8 * 1024 * 1024 });
  if (git(["rev-parse", PRODUCER + "^{tree}"]).toString().trim() !== PRODUCER_TREE) throw Error("Producer tree differs");
  const artistDirectories = ["smart-contracts/domains/artist", "smart-contracts/interfaces/stream/artist"];
  if (git(["diff", "--name-only", PRODUCER, SOURCE, "--", ...artistDirectories]).length !== 0) throw Error("Integrated Artist producer source changed");
  for (const row of producerBridge.files) {
    const bytes = git(["show", PRODUCER + ":" + row.path]);
    if (bytes.length !== row.bytes || sha(bytes) !== row.rawSHA256) throw Error("Producer file pin differs: " + row.path);
  }
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
  // Select every compiler declaration already in the explicit roots' imported closure.
  // Nominal library selectors remain separate from ordinary wallet ABIs.
  for (const [path, entries] of candidates) {
    if (!Object.hasOwn(sourceTexts, path)) continue;
    for (const [name, contract] of Object.entries(entries)) select(path, name, contract, kind(path, name) === "library");
  }
  const documents = [
    "docs/adr/0023-modular-artist-authority-domain-ownership.md",
    "docs/adr/0025-artist-authority-windows-and-fixed-extensions.md",
    "docs/adr/0047-complete-artist-authority-hydration.md",
    "docs/guides/artist-recovered-authority-hydration.md",
    "docs/integrations/artist-recovered-multiple-base.md",
    "docs/architecture/artist-operation60-authority-hydration.json",
  ];
  const retainedDocuments = {};
  for (const path of documents) {
    const bytes = execFileSync("git", ["show", SOURCE + ":" + path], { cwd: repositoryRoot, maxBuffer: 4 * 1024 * 1024 });
    const text = bytes.toString("utf8");
    if (!Buffer.from(text, "utf8").equals(bytes)) throw Error("Invalid UTF-8 document " + path);
    retainedDocuments[path] = { sha256: sha(bytes), byteLength: bytes.length, text };
  }
  // Nominal enum labels are retained literally. A value-only helper may substitute
  // uint8 only where a complete ordinary compiler ABI independently witnesses it.
  const libraryValueTypeEvidence = {};
  function enumRows(fields, location, path = []) {
    fields.forEach((field, i) => {
      const parameterPath = [...path, i];
      if (field.internalType?.startsWith("enum ") && field.type === "uint8" && !libraryValueTypeEvidence[field.internalType]) {
        libraryValueTypeEvidence[field.internalType] = { nominalType: field.internalType.slice(5), abiType: "uint8", witness: { ...location, parameterPath } };
      }
      if (field.components) enumRows(field.components, location, [...parameterPath, "components"]);
    });
  }
  for (const [name, rows] of Object.entries(abis)) rows.forEach((row, abiIndex) => {
    for (const direction of ["inputs", "outputs"]) enumRows(row[direction] ?? [], { contract: name, abiIndex, direction });
  });
  // Compare only named original public hydration entry points and their full
  // Request/return shape. No claim that older singleton semantics were broadened.
  const oldPath = new URL("../test/fixtures/current-artist-recovered-consent-hydration-abi.json", import.meta.url);
  const oldBytes = readFileSync(oldPath);
  if (sha(oldBytes) !== "e266e18eb73d6d2022a4cef642190e01c3ef0f595a4aa22ed2afbea5011ddfea") throw Error("Frozen ABI106 singleton witness differs");
  const old = JSON.parse(oldBytes);
  const singletonMethods = {};
  for (const key of ["recovered", "recoveredCoordinator", "recoveredConsents", "recoveredConsentsCoordinator"]) {
    const name = old.selections[key].contract;
    const functions = old.abis[key].filter(row => row.type === "function");
    for (const row of functions) {
      const same = abis[name]?.find(value => value.type === "function" && value.name === row.name);
      if (JSON.stringify(same) !== JSON.stringify(row)) throw Error("Historical hydration function ABI changed: " + name + "." + row.name);
    }
    singletonMethods[name] = functions;
  }
  const sorted = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => order(a, b)));
  return {
    schemaVersion: 1,
    profile: "current-artist-recovered-multiple-hydration",
    capture: "parallel-feature-batch167-20260921",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 4138,
    compilerReportedCommit: SOURCE,
    committedSourceBridge: { sha256: sha(bridgeBytes), ...bridge },
    literalBytes: 48_869_757,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "All 4,138 compiler input literals match raw Git blobs byte-for-byte, without normalization. Complete ordinary and nominal compiler objects are retained separately for every declaration in the selected roots' full import closure. The producer's two Artist directories are byte-identical at the integrated source.",
    qualification: "Exact ABI167/source witness only. MULTIPLE_BASE is an explicit additive recovered profile, not a widening of frozen singleton clients. Nominal selectors are compiler evidence, not ordinary wallet endpoints. Fixture inclusion does not establish supported client behavior, native or Safe execution, runtime provenance, rollback, gas/capacity, release or deployment admission.",
    roots, aliases,
    producerEvidence: { sourceCommit: PRODUCER, sourceTree: PRODUCER_TREE, handoffSha256: HANDOFF_SHA, sourceBridgeSha256: PRODUCER_BRIDGE_SHA, artistDirectories, handoffText: handoffBytes.toString("utf8"), sourceBridgeText: producerBridgeBytes.toString("utf8"), handoff, sourceBridge: producerBridge },
    singletonAbiEvidence: { fixtureSha256: sha(oldBytes), sourceCommit: old.sourceCommit, methods: singletonMethods, qualification: "These original public function objects and their complete Request/return tuples are unchanged. This is ABI parity only, not singleton runtime or semantic validation." },
    libraryValueTypeEvidence: sorted(libraryValueTypeEvidence),
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
  const [input, output, bridge, handoff, producerBridge, mode, ...extra] = process.argv.slice(2);
  if (!input || !output || !bridge || !handoff || !producerBridge || mode !== undefined && mode !== "--check" || extra.length) {
    throw Error("Usage: generate-current-artist-recovered-multiple-hydration-fixture.mjs INPUT OUTPUT COMMITTED_SOURCE_BRIDGE HANDOFF PRODUCER_SOURCE_BRIDGE [--check]");
  }
  const rendered = JSON.stringify(artistRecoveredMultipleHydrationFixture(await readFile(input), await readFile(output), await readFile(bridge), await readFile(handoff), await readFile(producerBridge)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-artist-recovered-multiple-hydration-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale Artist recovered MULTIPLE_BASE V1 fixture");
    process.stdout.write("Artist recovered MULTIPLE_BASE fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Artist recovered MULTIPLE_BASE fixture written\n");
  }
}
