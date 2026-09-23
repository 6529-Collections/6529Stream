// Compact ABI178/source supplement. The original ABI12 fixture is never rewritten.
// This reads committed/compiler bytes only; it does not compile or execute Solidity.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const root = fileURLToPath(new URL("../../../", import.meta.url));
const baseURL = new URL("../test/fixtures/current-artist-recovered-multiple-attestation-hydration-abi.json", import.meta.url);
const outputURL = new URL("../test/fixtures/current-artist-recovered-multiple-generation-hydration-source-profile.json", import.meta.url);
const TARGET = "45828ad0db2a6d52c6b0c7aad8d25dd4ba866c65";
const TREE = "19426e71f466f9e5f4d7a3f8b2ee26c17d3d350c";
const CAPTURE = "d823d82c971fdf63906895852a7c6bd6543d5982";
const CAPTURE_TREE = "7b65371966647ec1f77a584082d46d1b956c1ad8";
const BASE_SHA = "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9";
const INPUT_SHA = "6b8a709dc4cb2e9851a23956d18b29f3a6f2ed0c8e15002269ab35f30337aff5";
const OUTPUT_SHA = "e33031906a3d48ba55f017d587fb2b16848cf679ff28f72ebbd3378c480fc9e5";
const BRIDGE_SHA = "1012e62388432b213c7dce3c5f5bf17c16954b3b3ec9ad5f14c7ac07bf2eb2e2";
const PREFIX = "StreamArtistRecoveredMultipleGeneration";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const sorted = value => Object.fromEntries(Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0));
const roots = ["StreamArtistOnboardingRegistry", "StreamArtistOnboardingCoordinator", "StreamArtistBindingLifecycle", "StreamArtistCollaboratorLifecycle", "StreamArtistIdentityAuthority", "StreamArtistAcceptanceLifecycle", "StreamArtistAttributionLifecycle", "StreamArtistPayoutLifecycle", "StreamArtistConsentFinalityLifecycle", "StreamArtistArchiveV2"];
const documents = ["docs/adr/0047-complete-artist-authority-hydration.md", "docs/integrations/artist-recovered-multiple-generations.md", "docs/architecture/artist-operation60-authority-hydration.json"];

function git(args, input) { return execFileSync("git", args, { cwd: root, input, maxBuffer: 160 * 1024 * 1024, windowsHide: true }); }
function blobs(commit, paths) {
  const raw = git(["cat-file", "--batch"], paths.map(path => `${commit}:${path}\n`).join(""));
  const result = {}; let cursor = 0;
  for (const path of paths) {
    const end = raw.indexOf(10, cursor), line = raw.subarray(cursor, end).toString("utf8"), match = /^([0-9a-f]{40}) blob ([0-9]+)$/.exec(line);
    if (!match) throw Error(`Missing committed blob ${commit}:${path}: ${line}`);
    const length = Number(match[2]); cursor = end + 1;
    const bytes = raw.subarray(cursor, cursor + length); cursor += length;
    if (bytes.length !== length || raw[cursor++] !== 10) throw Error("Invalid Git byte transport");
    const text = bytes.toString("utf8");
    if (!Buffer.from(text).equals(bytes)) throw Error(`Invalid UTF8 source ${path}`);
    result[path] = { blob: match[1], sha256: sha(bytes), byteLength: length, text };
  }
  if (cursor !== raw.length) throw Error("Unexpected Git batch tail");
  return result;
}
const imports = (path, text) => solidityImports(text).map(value => value.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), value)) : value);
function pinned(raw, expected, label) { if (sha(raw) !== expected) throw Error(`Wrong ${label} bytes`); return JSON.parse(raw); }
function methods(declaration) { return declaration.evm?.methodIdentifiers ?? {}; }

export function artistRecoveredMultipleGenerationHydrationSourceProfile(inputRaw, outputRaw, bridgeRaw) {
  const baseRaw = readFileSync(baseURL), base = pinned(baseRaw, BASE_SHA, "retained ABI12");
  const input = pinned(inputRaw, INPUT_SHA, "ABI178 input"), output = pinned(outputRaw, OUTPUT_SHA, "ABI178 output"), bridge = pinned(bridgeRaw, BRIDGE_SHA, "ABI178 bridge");
  if (base.sourceCommit !== "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b" || bridge.commit !== CAPTURE || bridge.sources !== 4321 || bridge.mismatches.length) throw Error("Compiler source coordinates differ");
  for (const [commit, tree] of [[TARGET, TREE], [CAPTURE, CAPTURE_TREE]]) if (git(["rev-parse", `${commit}^{tree}`]).toString().trim() !== tree) throw Error("Git tree differs");
  if ((output.errors ?? []).some(row => row.severity === "error")) throw Error("Compiler reported errors");
  const paths = Object.keys(input.sources).sort();
  if (paths.length !== 4321) throw Error("Unexpected compiler input count");
  const captured = blobs(CAPTURE, paths);
  let literalBytes = 0;
  for (const path of paths) {
    const text = input.sources[path].content, row = captured[path];
    if (typeof text !== "string" || row.text !== text || bridge.committedBlobSHA256[path] !== row.sha256) throw Error(`Compiler literal differs from raw committed source ${path}`);
    literalBytes += Buffer.byteLength(text);
  }
  const newNames = Object.entries(output.contracts).flatMap(([path, declarations]) => Object.keys(declarations).filter(name => name.startsWith(PREFIX) && path.startsWith("smart-contracts/")).map(name => [name, path])).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0);
  if (newNames.length !== 38) throw Error("Expected exact 38 generation library declarations");
  const rootPaths = [...new Set([...roots.map(name => base.selections[name].source), ...newNames.map(([, path]) => path)])].sort();
  const current = {}; let pending = rootPaths;
  while (pending.length) {
    Object.assign(current, blobs(TARGET, [...new Set(pending)].sort()));
    pending = [...new Set(Object.entries(current).flatMap(([path, row]) => imports(path, row.text)).filter(path => !Object.hasOwn(current, path)))];
  }
  const rows = {}, overrides = {}, changed = [], added = [];
  for (const path of Object.keys(current).sort()) {
    const row = current[path], original = base.sourceTexts[path];
    if (!captured[path] || captured[path].text !== row.text) throw Error(`Current selected source differs from ABI178 ${path}`);
    const same = original === row.text;
    if (original !== undefined && sha(original) !== base.sourceHashes[path]) throw Error(`Retained source hash differs ${path}`);
    rows[path] = { blob: row.blob, sha256: row.sha256, byteLength: row.byteLength, compiler178SourceEqual: true, retainedCompiler12SourceEqual: same };
    if (!same) {
      overrides[path] = row.text;
      if (original === undefined) added.push(path);
      else changed.push({ path, retainedSha256: sha(original), currentSha256: row.sha256 });
    }
  }
  // Authenticate old full declarations and nominal method maps before reuse.
  // A changed declaration is never silently presented as current compiler evidence.
  const retainedDeclarations = {};
  for (const [kind, selections, abis, ids] of [["ordinary", base.selections, base.abis, base.methodIdentifiers], ["library", base.librarySelections, base.libraryAbis, base.libraryMethodIdentifiers]]) {
    for (const [name, selection] of Object.entries(selections)) {
      if (!rows[selection.source]) continue;
      const currentDeclaration = output.contracts[selection.source]?.[selection.contract ?? name];
      if (!currentDeclaration) throw Error(`Missing retained declaration ${name}`);
      const abiEqual = JSON.stringify(abis[name]) === JSON.stringify(currentDeclaration.abi);
      const methodsEqual = JSON.stringify(ids[name]) === JSON.stringify(methods(currentDeclaration));
      retainedDeclarations[name] = { kind, source: selection.source, abiEqual, methodsEqual, retainedAbiSha256: sha(JSON.stringify(abis[name])), currentAbiSha256: sha(JSON.stringify(currentDeclaration.abi)), retainedMethodsSha256: sha(JSON.stringify(ids[name])), currentMethodsSha256: sha(JSON.stringify(methods(currentDeclaration))) };
    }
  }
  const libraryAbis = {}, libraryMethodIdentifiers = {}, librarySelections = {};
  for (const [name, path] of newNames) {
    const declaration = output.contracts[path][name];
    libraryAbis[name] = declaration.abi;
    libraryMethodIdentifiers[name] = methods(declaration);
    librarySelections[name] = { source: path, contract: name, sourceSha256: rows[path].sha256 };
  }
  const retainedDocuments = blobs(TARGET, documents);
  return {
    schemaVersion: 1, profile: "artist-recovered-multiple-generations-v1", feature: 2097152, allowedFeatures: 2276351, advertisedFeatures: 4194303,
    currentSource: { commit: TARGET, tree: TREE },
    retainedCompilerEvidence: { sourceCommit: base.sourceCommit, sourceTree: base.sourceTree, fixtureFile: "current-artist-recovered-multiple-attestation-hydration-abi.json", fixtureSha256: BASE_SHA, fixtureBytes: baseRaw.length },
    compilerEvidence: { capture: "parallel-feature-batch178-20260922", sourceCommit: CAPTURE, sourceTree: CAPTURE_TREE, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA, bridgeSha256: BRIDGE_SHA, sources: paths.length, literalBytes, rawGitLiteralsEqual: true, lineEndingNormalizationApplied: false, reportedTransport: "UTF-8 with CRLF normalized to LF" },
    qualification: { compilerWasRerun: false, selectedCurrentSourceEqualsCompilerInput: true, currentWholeSuiteSourceEqualityClaimed: false, nativeExecutionVerified: false, linkedRuntimeAdmissionVerified: false, sourceDerivedWrappers: ["five-field generation envelope", "StreamArtistRecoveredMultipleGenerationTypes.Attribution"], description: "ABI178 is preserved compiler type/method evidence at d823. Every selected production import is raw-byte equal at the separately pinned client source. Unchanged ABI12 declarations are reused only with explicit full ABI/method comparisons. Nominal library ABIs are value witnesses, never ordinary wallet endpoints." },
    roots, rootPaths, statistics: { currentClosureSources: Object.keys(rows).length, currentClosureBytes: Object.values(rows).reduce((n, row) => n + row.byteLength, 0), reusedSourceCount: Object.keys(rows).length - changed.length - added.length, changedSourceCount: changed.length, addedSourceCount: added.length, retainedDeclarationCount: Object.keys(retainedDeclarations).length, libraryCount: newNames.length, libraryEntries: Object.values(libraryAbis).reduce((n, abi) => n + abi.length, 0), librarySelectors: Object.values(libraryMethodIdentifiers).reduce((n, map) => n + Object.keys(map).length, 0), documentCount: documents.length, documentBytes: Object.values(retainedDocuments).reduce((n, row) => n + row.byteLength, 0) },
    changedSources: changed, addedSources: added, sources: sorted(rows), sourceOverrides: sorted(overrides), retainedDeclarations: sorted(retainedDeclarations), libraryAbis: sorted(libraryAbis), libraryMethodIdentifiers: sorted(libraryMethodIdentifiers), librarySelections: sorted(librarySelections), documents: sorted(retainedDocuments),
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2), check = args.at(-1) === "--check"; if (check) args.pop();
  if (args.length !== 3 || args.some(arg => arg.startsWith("--"))) throw Error("Usage: node generate-current-artist-recovered-multiple-generation-hydration-source-profile.mjs ABI178_INPUT ABI178_OUTPUT COMMITTED_BRIDGE [--check]");
  const result = artistRecoveredMultipleGenerationHydrationSourceProfile(...args.map(path => readFileSync(path)));
  const bytes = Buffer.from(JSON.stringify(result, null, 2) + "\n");
  if (check) { if (!readFileSync(outputURL).equals(bytes)) throw Error("Generation source profile is stale"); }
  else writeFileSync(outputURL, bytes);
  console.log(JSON.stringify({ ...result.statistics, bytes: bytes.length, sha256: sha(bytes), check }));
}
