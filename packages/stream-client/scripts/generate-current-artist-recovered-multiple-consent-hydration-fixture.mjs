// Exact c636 ABI11 witness for additive Artist recovered MULTIPLE_CONSENTS clients.
// Never invokes Solidity, modifies captures, or refreshes historical fixtures.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { readFileSync } from "node:fs";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "c636a5f176c5765d80d15ee20f41355a8911ea9c";
const TREE = "7f52167006283928e96919fcea03b7434e61b257";
const INPUT_SHA = "90c25baadbc04ccbea996853dba16ac9cae1759fe7e8fb5dbaf8bdf228a887d8";
const OUTPUT_SHA = "270041a81ecdfacb7b495062973463aa84995d1e1aad768d907d15273e0417f0";
const HANDOFF_SHA = "d3c43a2cf1452c1b1a9fea47ed004e1dd10a89d9fa57e63e596edbdd900311bc";
const BRIDGE_SHA = "2f6bb2e01e647d8ace99955136b34e54a8351cca0bd88986928fee7cc764ae39";
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
  "multipleCollections": "StreamArtistRecoveredMultipleCollectionSource",
  "multipleConsentBaseImport": "StreamArtistRecoveredMultipleConsentBaseImport",
  "multipleConsentCodec": "StreamArtistRecoveredMultipleConsentCodec",
  "multipleConsentCollectionImport": "StreamArtistRecoveredMultipleConsentCollectionImport",
  "multipleConsentCollectionRows": "StreamArtistRecoveredMultipleConsentCollectionRows",
  "multipleConsentCollectionSource": "StreamArtistRecoveredMultipleConsentCollectionSource",
  "multipleConsentComposition": "StreamArtistRecoveredMultipleConsentComposition",
  "multipleConsentContentRows": "StreamArtistRecoveredMultipleConsentContentRows",
  "multipleConsentDelegations": "StreamArtistRecoveredMultipleConsentDelegations",
  "multipleConsentFacts": "StreamArtistRecoveredMultipleConsentFacts",
  "multipleConsentGrantRows": "StreamArtistRecoveredMultipleConsentGrantRows",
  "multipleConsentIdentityCodec": "StreamArtistRecoveredMultipleConsentIdentityCodec",
  "multipleConsentIdentityImport": "StreamArtistRecoveredMultipleConsentIdentityImport",
  "multipleConsentIdentitySource": "StreamArtistRecoveredMultipleConsentIdentitySource",
  "multipleConsentIdentityValidation": "StreamArtistRecoveredMultipleConsentIdentityValidation",
  "multipleConsentImport": "StreamArtistRecoveredMultipleConsentImport",
  "multipleConsentNonces": "StreamArtistRecoveredMultipleConsentNonces",
  "multipleConsentOwners": "StreamArtistRecoveredMultipleConsentOwners",
  "multipleConsentPayoutImport": "StreamArtistRecoveredMultipleConsentPayoutImport",
  "multipleConsentPreparation": "StreamArtistRecoveredMultipleConsentPreparation",
  "multipleConsentReads": "StreamArtistRecoveredMultipleConsentReads",
  "multipleConsentSelection": "StreamArtistRecoveredMultipleConsentSelection",
  "multipleConsentValidation": "StreamArtistRecoveredMultipleConsentValidation",
  "multipleConsentWitnesses": "StreamArtistRecoveredMultipleConsentWitnesses"
};
const roots = [...new Set(Object.values(aliases))];

function bindAllGitLiterals(input) {
  const entries = Object.entries(input.sources).sort(([a], [b]) => order(a, b));
  if (entries.some(([path, source]) => /[\r\n]/.test(path) || typeof source.content !== "string")) throw Error("Invalid compiler source literal");
  const blobs = execFileSync("git", ["cat-file", "--batch"], {
    cwd: repositoryRoot, input: entries.map(([path]) => SOURCE + ":" + path + "\n").join(""), maxBuffer: 32 * 1024 * 1024,
  });
  let cursor = 0, literalBytes = 0;
  const committedBlobSHA256 = {};
  for (const [path, source] of entries) {
    const end = blobs.indexOf(10, cursor), header = blobs.subarray(cursor, end).toString("ascii");
    const size = Number(header.split(" ")[2]);
    if (end < cursor || !/^[0-9a-f]+ blob [0-9]+$/.test(header) || !Number.isSafeInteger(size) || size < 0) throw Error("Missing frozen source " + path);
    const bytes = blobs.subarray(end + 1, end + 1 + size);
    if (blobs[end + 1 + size] !== 10) throw Error("Invalid Git batch framing");
    if (!bytes.equals(Buffer.from(source.content, "utf8"))) throw Error("Compiler/Git raw bytes differ: " + path);
    committedBlobSHA256[path] = sha(bytes);
    cursor = end + size + 2;
    literalBytes += size;
  }
  if (cursor !== blobs.length || literalBytes !== 9_603_516) throw Error("Frozen literal inventory differs");
  return { commit: SOURCE, tree: TREE, sources: entries.length, literalBytes, committedBlobSHA256 };
}

export function artistRecoveredMultipleConsentHydrationFixture(inputBytes, outputBytes, handoffBytes, bridgeBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact recovered MULTIPLE_CONSENTS ABI11 input/output");
  if (sha(handoffBytes) !== HANDOFF_SHA || sha(bridgeBytes) !== BRIDGE_SHA) throw Error("Expected exact c636 producer evidence");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), handoff = JSON.parse(handoffBytes), bridge = JSON.parse(bridgeBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 1408
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid frozen ABI11 capture");
  const git = args => execFileSync("git", args, { cwd: repositoryRoot, maxBuffer: 8 * 1024 * 1024 });
  if (git(["rev-parse", SOURCE + "^{tree}"]).toString().trim() !== TREE
    || handoff.commit !== SOURCE || handoff.tree !== TREE || bridge.commit !== SOURCE || bridge.tree !== TREE
    || bridge.ABI11Sources !== 1408 || handoff.ABI.sources !== 1408 || handoff.ABI.errors !== 0
    || handoff.ABI.inputSHA256 !== INPUT_SHA || handoff.ABI.outputSHA256 !== OUTPUT_SHA) throw Error("Producer/source identity differs");
  if (handoff.profile.bit !== 524288 || handoff.profile.allowedFeatures !== 524671
    || handoff.profile.advertisedFeatures !== 1048575 || handoff.profile.version !== 1
    || handoff.profile.tag !== "6529STREAM_ARTIST_RECOVERED_MULTIPLE_CONSENTS_V1") throw Error("Producer profile differs");
  const committedSourceBridge = bindAllGitLiterals(input);
  for (const row of bridge.changedPaths) {
    const bytes = git(["show", SOURCE + ":" + row.path]);
    const blob = createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
    if (row.gitBlob !== blob) throw Error("Producer committed blob differs: " + row.path);
    if (sha(bytes.toString("utf8").replace(/\r\n/g, "\n")) !== row.LFSHA256) throw Error("Producer committed text differs: " + row.path);
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
    "docs/integrations/artist-recovered-multiple-consents.md",
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
    schemaVersion: 1, profile: "current-artist-recovered-multiple-consent-hydration",
    capture: "recovered-multiple-consents-abi11", compilerVersion: "0.8.19",
    sourceCommit: SOURCE, sourceTree: TREE, sourceCount: 1408, compilerReportedCommit: SOURCE,
    committedSourceBridge, literalBytes: 9_603_516, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 1,408 compiler input literals match raw c636 Git blobs byte-for-byte without normalization. Complete ordinary and nominal compiler objects are retained separately for every declaration in the selected roots' full import closure.",
    qualification: "Exact c636 ABI11/source witness only. MULTIPLE_CONSENTS is an additive recovered profile; frozen BASE/255/511 clients remain strict. Nominal selectors are compiler evidence, not ordinary wallet endpoints. Fixture inclusion does not establish supported client behavior, native/Safe execution, runtime provenance, rollback, gas/capacity or release/deployment admission.",
    roots, aliases,
    producerEvidence: { sourceCommit: SOURCE, sourceTree: TREE, handoffSha256: HANDOFF_SHA, sourceBridgeSha256: BRIDGE_SHA, handoffText: handoffBytes.toString("utf8"), sourceBridgeText: bridgeBytes.toString("utf8"), handoff, sourceBridge: bridge },
    absentHistoricalAliases: { coreHost: "StreamCore is not a selected product in ABI11; IStreamCorePointers remains available", contentFacts: "StreamArtistRecoveredContentConsentFacts is not selected in ABI11; current MultipleConsentFacts is retained" },
    singletonAbiEvidence: { fixtureSha256: sha(oldBytes), sourceCommit: old.sourceCommit, methods: singletonMethods, qualification: "Original public function objects and complete Request/return tuples are unchanged. ABI parity does not widen frozen profiles or prove semantic/runtime acceptance." },
    libraryValueTypeEvidence: sorted(libraryValueTypeEvidence),
    sourceHashes: sorted(sourceHashes), sourceTexts: sorted(sourceTexts), documents: retainedDocuments,
    selections: sorted(selections), methodIdentifiers: sorted(methodIdentifiers), abis: sorted(abis),
    librarySelections: sorted(librarySelections), libraryMethodIdentifiers: sorted(libraryMethodIdentifiers), libraryAbis: sorted(libraryAbis),
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, handoff, bridge, mode, ...extra] = process.argv.slice(2);
  if (!input || !output || !handoff || !bridge || mode !== undefined && mode !== "--check" || extra.length) throw Error("Usage: generate-current-artist-recovered-multiple-consent-hydration-fixture.mjs INPUT OUTPUT HANDOFF COMMIT_BRIDGE [--check]");
  const rendered = JSON.stringify(artistRecoveredMultipleConsentHydrationFixture(await readFile(input), await readFile(output), await readFile(handoff), await readFile(bridge)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-artist-recovered-multiple-consent-hydration-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale Artist recovered MULTIPLE_CONSENTS V1 fixture");
    process.stdout.write("Artist recovered MULTIPLE_CONSENTS fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Artist recovered MULTIPLE_CONSENTS fixture written\n");
  }
}
