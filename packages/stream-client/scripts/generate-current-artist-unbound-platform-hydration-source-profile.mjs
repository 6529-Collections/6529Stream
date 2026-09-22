// Compact ABI188 supplement; the retained bd4 ABI12 fixture is never rewritten.
// Reads authenticated compiler/Git bytes only. No Solidity execution or compilation.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const root = fileURLToPath(new URL("../../../", import.meta.url));
const baseURL = new URL("../test/fixtures/current-artist-recovered-multiple-attestation-hydration-abi.json", import.meta.url);
const outputURL = new URL("../test/fixtures/current-artist-unbound-platform-hydration-source-profile.json", import.meta.url);
const TARGET = "66dc4a308f6a1c1b93187d7295554062d900b5fa";
const TREE = "aa49cd7bb32bdd299b320e5a81057deda33e950f";
const PRODUCER = "8aa8c6606e15fcee0ccfc18348efa73539f487c0";
const PRODUCER_TREE = "92e67c95ede5d9207c0edaa0a534e2bcd1a2c15a";
const BASE_SHA = "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9";
const INPUT_SHA = "b71464b4baec6eb7a452e18e82fde3c2526af094cba36c81ef1476854f20ec6a";
const OUTPUT_SHA = "5c48a4813cefc70012acdd76d3be93e8417bec060a9b76afb8e9dbe23261edfd";
const BRIDGE_SHA = "d6879efac7719977f4fd2c50584863b7ebe6023d7d1e6116cece67b3067b8453";
const HANDOFF_SHA = "c8b2b4b58770bcf9afae90ac98e367c2adb121198d487f288475df523403e655";
const JOIN_SHA = "574d79a2b518eff29074ab207a01af68649a07d4e7335d0332a4ff819ffa9f49";
const PRODUCER_INPUT_SHA = "ac2637aeb8a9d3a9bca0b7a557f8e3baadbe07acc48ca4157bd8272bff46d89d";
const PRODUCER_OUTPUT_SHA = "1cd5c6da07f21e00b0ec132f027aac58a0f4152838b3c7668a8602925028cd81";
const PREFIX = "StreamArtistUnboundPlatform";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const sorted = value => Object.fromEntries(Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0));
const roots = ["StreamArtistOnboardingRegistry", "StreamArtistOnboardingCoordinator", "StreamArtistBindingLifecycle", "StreamArtistCollaboratorLifecycle", "StreamArtistIdentityAuthority", "StreamArtistAcceptanceLifecycle", "StreamArtistAttributionLifecycle", "StreamArtistPayoutLifecycle", "StreamArtistConsentFinalityLifecycle", "StreamArtistArchiveV2"];
const documents = ["docs/adr/0047-complete-artist-authority-hydration.md", "docs/integrations/artist-unbound-platform-hydration.md", "docs/architecture/artist-operation60-authority-hydration.json"];

function git(args, input) { return execFileSync("git", args, { cwd: root, input, maxBuffer: 180 * 1024 * 1024, windowsHide: true }); }
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
const methods = declaration => declaration.evm?.methodIdentifiers ?? {};
function capture(input, commit, count, bridge) {
  const paths = Object.keys(input.sources).sort();
  if (paths.length !== count) throw Error("Unexpected compiler source count");
  const rows = blobs(commit, paths); let literalBytes = 0, rawBytes = 0;
  const normalizedOnly = [];
  for (const path of paths) {
    const literal = input.sources[path].content, row = rows[path];
    if (typeof literal !== "string" || (literal !== row.text && literal !== row.text.replace(/\r\n/g, "\n"))) throw Error(`Compiler literal differs from committed source ${path}`);
    if (bridge && bridge.committedBlobSHA256[path] !== row.sha256) throw Error(`Bridge raw hash differs ${path}`);
    if (literal !== row.text) normalizedOnly.push(path);
    literalBytes += Buffer.byteLength(literal); rawBytes += row.byteLength;
  }
  return { rows, statistics: { sources: count, rawBytes, literalBytes, rawEqualCount: count - normalizedOnly.length, normalizedOnlyCount: normalizedOnly.length, normalizedOnlyPaths: normalizedOnly, rawGitLiteralsEqual: normalizedOnly.length === 0, lineEndingNormalizationApplied: normalizedOnly.length !== 0 } };
}
function kind(text, name) {
  const stripped = text.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\r\n]*/g, "");
  const matches = [...stripped.matchAll(/\b(contract|interface|library)\s+([A-Za-z_][A-Za-z0-9_]*)\b/g)].filter(match => match[2] === name);
  if (matches.length !== 1) throw Error(`Ambiguous declaration kind ${name}`);
  return matches[0][1] === "library" ? "library" : "ordinary";
}

export function artistUnboundPlatformHydrationSourceProfile(inputRaw, outputRaw, bridgeRaw, handoffRaw, joinRaw, producerInputRaw, producerOutputRaw) {
  const baseRaw = readFileSync(baseURL), base = pinned(baseRaw, BASE_SHA, "retained ABI12");
  const input = pinned(inputRaw, INPUT_SHA, "ABI188 input"), output = pinned(outputRaw, OUTPUT_SHA, "ABI188 output"), bridge = pinned(bridgeRaw, BRIDGE_SHA, "ABI188 bridge");
  const handoff = pinned(handoffRaw, HANDOFF_SHA, "producer handoff"), join = pinned(joinRaw, JOIN_SHA, "integration source bridge");
  const producerInput = pinned(producerInputRaw, PRODUCER_INPUT_SHA, "ABI7 input"), producerOutput = pinned(producerOutputRaw, PRODUCER_OUTPUT_SHA, "ABI7 output");
  if (base.sourceCommit !== "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b" || bridge.commit !== TARGET || bridge.mismatches.length || handoff.commit !== PRODUCER || handoff.tree !== PRODUCER_TREE || join.head !== TARGET || join.producer !== PRODUCER) throw Error("Source coordinates differ");
  for (const [commit, tree] of [[TARGET, TREE], [PRODUCER, PRODUCER_TREE]]) if (git(["rev-parse", `${commit}^{tree}`]).toString().trim() !== tree) throw Error("Git tree differs");
  for (const value of [output, producerOutput]) if ((value.errors ?? []).some(row => row.severity === "error")) throw Error("Compiler reported errors");
  const captured = capture(input, TARGET, 4365, bridge), producer = capture(producerInput, PRODUCER, 1467);
  const selectedNames = Object.entries(output.contracts).flatMap(([path, ds]) => Object.keys(ds).filter(name => name.startsWith(PREFIX) && path.startsWith("smart-contracts/")).map(name => [name, path])).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0);
  if (selectedNames.length !== 18) throw Error("Expected eighteen UNBOUND libraries");
  const rootPaths = [...new Set([...roots.map(name => base.selections[name].source), ...selectedNames.map(([, path]) => path)])].sort();
  const current = {}; let pending = rootPaths;
  while (pending.length) {
    Object.assign(current, blobs(TARGET, [...new Set(pending)].sort()));
    pending = [...new Set(Object.entries(current).flatMap(([path, row]) => imports(path, row.text)).filter(path => !Object.hasOwn(current, path)))];
  }
  const rows = {}, overrides = {}, changed = [], added = [];
  for (const path of Object.keys(current).sort()) {
    const row = current[path], original = base.sourceTexts[path], literal = input.sources[path]?.content;
    if (!captured.rows[path] || captured.rows[path].text !== row.text || (literal !== row.text && literal !== row.text.replace(/\r\n/g, "\n"))) throw Error(`Selected source differs from ABI188 ${path}`);
    const same = original === row.text;
    if (original !== undefined && sha(original) !== base.sourceHashes[path]) throw Error(`Retained source hash differs ${path}`);
    rows[path] = { blob: row.blob, sha256: row.sha256, byteLength: row.byteLength, compilerLiteralSha256: sha(literal), compilerLiteralBytes: Buffer.byteLength(literal), compiler188RawSourceEqual: literal === row.text, compiler188NormalizedSourceEqual: literal === row.text.replace(/\r\n/g, "\n"), retainedCompiler12SourceEqual: same };
    if (!same) { overrides[path] = row.text; if (original === undefined) added.push(path); else changed.push({ path, retainedSha256: sha(original), currentSha256: row.sha256 }); }
  }
  const retainedDeclarations = {}, abis = {}, selections = {}, methodIdentifiers = {}, libraryAbis = {}, librarySelections = {}, libraryMethodIdentifiers = {};
  for (const path of Object.keys(current).sort()) for (const [name, declaration] of Object.entries(output.contracts[path] ?? {}).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)) {
    const declarationKind = kind(current[path].text, name), nominal = declarationKind === "library";
    const oldABI = nominal ? base.libraryAbis[name] : base.abis[name], oldSelection = nominal ? base.librarySelections[name] : base.selections[name], oldMethods = nominal ? base.libraryMethodIdentifiers[name] : base.methodIdentifiers[name];
    let unchanged = false;
    if (oldABI) {
      if (oldSelection.source !== path) throw Error(`Retained declaration source changed ${name}`);
      const abiEqual = JSON.stringify(oldABI) === JSON.stringify(declaration.abi), methodsEqual = JSON.stringify(oldMethods) === JSON.stringify(methods(declaration));
      retainedDeclarations[name] = { kind: declarationKind, source: path, abiEqual, methodsEqual, retainedAbiSha256: sha(JSON.stringify(oldABI)), currentAbiSha256: sha(JSON.stringify(declaration.abi)), retainedMethodsSha256: sha(JSON.stringify(oldMethods)), currentMethodsSha256: sha(JSON.stringify(methods(declaration))) };
      unchanged = abiEqual && methodsEqual;
    }
    if (!unchanged) {
      const as = nominal ? libraryAbis : abis, ss = nominal ? librarySelections : selections, ms = nominal ? libraryMethodIdentifiers : methodIdentifiers;
      if (Object.hasOwn(as, name)) throw Error(`Duplicate declaration ${name}`);
      as[name] = declaration.abi; ms[name] = methods(declaration); ss[name] = { source: path, contract: name, full: true, nominal, sourceSha256: rows[path].sha256, overridesRetainedABI: Boolean(oldABI) };
    }
  }
  const joinPaths = Object.keys(join.files).sort(), joinedTarget = blobs(TARGET, joinPaths), joinedProducer = blobs(PRODUCER, joinPaths), producerJoins = {};
  if (joinPaths.length !== 34) throw Error("Integration bridge path count differs");
  const consent = "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol";
  const oldBody = "        bytes32 hash = _sanctions.latest[associationKey];\n        return (hash, _sanctions.records[hash]);";
  const newBody = "        _returnSanction(\n            StreamArtistConsentReadEncoding.staticSanction(\n                _sanctions.latest, _sanctions.records, associationKey\n            )\n        );";
  for (const path of joinPaths) {
    const a = joinedProducer[path], b = joinedTarget[path];
    if (join.files[path] !== b.sha256) throw Error(`Integration bridge hash differs ${path}`);
    if (a.text !== b.text && (path !== consent || b.text.split(newBody).length !== 2 || b.text.replace(newBody, oldBody) !== a.text)) throw Error(`Unexpected producer source delta ${path}`);
    producerJoins[path] = { producer: { blob: a.blob, sha256: a.sha256, byteLength: a.byteLength }, integrated: { blob: b.blob, sha256: b.sha256, byteLength: b.byteLength }, rawEqual: a.text === b.text, exactConsentGetterInverse: path === consent };
  }
  const retainedDocuments = blobs(TARGET, documents);
  return {
    schemaVersion: 1, profile: "artist-unbound-platform-hydration-v1", feature: 4194304, allowedFeatures: 4194335, knownFeatures: 33554431, advertisedFeatures: 8388607,
    currentSource: { commit: TARGET, tree: TREE },
    retainedCompilerEvidence: { sourceCommit: base.sourceCommit, sourceTree: base.sourceTree, fixtureFile: "current-artist-recovered-multiple-attestation-hydration-abi.json", fixtureSha256: BASE_SHA, fixtureBytes: baseRaw.length },
    compilerEvidence: { capture: "parallel-feature-batch188-20260922", sourceCommit: TARGET, sourceTree: TREE, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA, bridgeSha256: BRIDGE_SHA, ...captured.statistics, reportedTransport: "direct committed Git blob input, CRLF normalized" },
    producerEvidence: { commit: PRODUCER, tree: PRODUCER_TREE, inputSha256: PRODUCER_INPUT_SHA, outputSha256: PRODUCER_OUTPUT_SHA, handoffSha256: HANDOFF_SHA, integrationBridgeSha256: JOIN_SHA, ...producer.statistics, handoffText: handoffRaw.toString("utf8"), integrationBridgeText: joinRaw.toString("utf8"), joins: producerJoins, consentInverse: { path: consent, producerBody: oldBody, integratedBody: newBody } },
    qualification: { compilerWasRerun: false, selectedCurrentSourceEqualsCompilerInput: true, currentWholeSuiteSourceEqualityClaimed: false, nativeExecutionVerified: false, linkedRuntimeAdmissionVerified: false, sourceDerivedWrappers: ["four-field UNBOUND_PLATFORM semantic envelope", "three-field zero-Artist timing row", "StreamArtistUnboundPlatformCollectionRows.AttributionRow"], description: "ABI188 type/method evidence is separately pinned to the integrated source. The complete selected import closure retains raw Git text and compiler literal identities. Unchanged bd4 declarations are reused only after full ABI and method comparisons; changed declarations have current full overrides. Nominal library ABIs are value witnesses, never ordinary wallet endpoints. Producer ABI7 and the thirty-four-path integration bridge remain separate evidence; the Consent getter extraction is explicitly retained." },
    roots, rootPaths, statistics: { currentClosureSources: Object.keys(rows).length, currentClosureBytes: Object.values(rows).reduce((n, row) => n + row.byteLength, 0), reusedSourceCount: Object.keys(rows).length - changed.length - added.length, changedSourceCount: changed.length, addedSourceCount: added.length, retainedDeclarationCount: Object.keys(retainedDeclarations).length, ordinarySupplementCount: Object.keys(abis).length, ordinarySupplementEntries: Object.values(abis).reduce((n, abi) => n + abi.length, 0), ordinarySupplementSelectors: Object.values(methodIdentifiers).reduce((n, map) => n + Object.keys(map).length, 0), librarySupplementCount: Object.keys(libraryAbis).length, librarySupplementEntries: Object.values(libraryAbis).reduce((n, abi) => n + abi.length, 0), librarySupplementSelectors: Object.values(libraryMethodIdentifiers).reduce((n, map) => n + Object.keys(map).length, 0), unboundLibraryCount: selectedNames.length, documentCount: documents.length, documentBytes: Object.values(retainedDocuments).reduce((n, row) => n + row.byteLength, 0) },
    changedSources: changed, addedSources: added, sources: sorted(rows), sourceOverrides: sorted(overrides), retainedDeclarations: sorted(retainedDeclarations), abis: sorted(abis), selections: sorted(selections), methodIdentifiers: sorted(methodIdentifiers), libraryAbis: sorted(libraryAbis), libraryMethodIdentifiers: sorted(libraryMethodIdentifiers), librarySelections: sorted(librarySelections), documents: sorted(retainedDocuments),
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2), check = args.at(-1) === "--check"; if (check) args.pop();
  if (args.length !== 7 || args.some(arg => arg.startsWith("--"))) throw Error("Usage: node generate-current-artist-unbound-platform-hydration-source-profile.mjs ABI188_INPUT ABI188_OUTPUT COMMITTED_BRIDGE PRODUCER_HANDOFF INTEGRATION_BRIDGE ABI7_INPUT ABI7_OUTPUT [--check]");
  const result = artistUnboundPlatformHydrationSourceProfile(...args.map(path => readFileSync(path)));
  const bytes = Buffer.from(JSON.stringify(result, null, 2) + "\n");
  if (check) { if (!readFileSync(outputURL).equals(bytes)) throw Error("UNBOUND_PLATFORM source profile is stale"); }
  else writeFileSync(outputURL, bytes);
  console.log(JSON.stringify({ ...result.statistics, bytes: bytes.length, sha256: sha(bytes), check }));
}
