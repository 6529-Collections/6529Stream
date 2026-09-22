// Compact ABI189 supplement; the retained bd4 ABI12 fixture is never rewritten.
// Reads authenticated compiler/Git bytes only. No Solidity execution or compilation.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const root = fileURLToPath(new URL("../../../", import.meta.url));
const baseURL = new URL("../test/fixtures/current-artist-recovered-multiple-attestation-hydration-abi.json", import.meta.url);
const outputURL = new URL("../test/fixtures/current-artist-recovered-multiple-dispute-hydration-source-profile.json", import.meta.url);
const TARGET = "b3ed602bcad94f09ee95f7abc1017d88df8178ba";
const TREE = "c03d38362ab57966a6bb960ea8f3a31942408b94";
const PRODUCER = "b68ecb1eaf68b13df337f70255707d5de08033f7";
const PRODUCER_TREE = "fb3521f8340d241277e330c62b2a7c883150ec17";
const BASE_SHA = "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9";
const INPUT_SHA = "505d302f3457b8d9a3f6f757abd5bd55aae113b636b3e7a218f3fd119682a3f9";
const OUTPUT_SHA = "420d25c7d872beffcc916fa12b4ea7a64c3afb79d787f834661389b05726eb72";
const BRIDGE_SHA = "14591bd8112372d0b15361cd3a68f420676ff64682c78b2171e4c5c47be1c10e";
const HANDOFF_SHA = "24e724802e1d0606167515b44789381cbd71554d0e274e176181357687537e52";
const PREFIX = "StreamArtistRecoveredMultipleDispute";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const sorted = value => Object.fromEntries(Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0));
const roots = ["StreamArtistOnboardingRegistry", "StreamArtistOnboardingCoordinator", "StreamArtistBindingLifecycle", "StreamArtistCollaboratorLifecycle", "StreamArtistIdentityAuthority", "StreamArtistAcceptanceLifecycle", "StreamArtistAttributionLifecycle", "StreamArtistPayoutLifecycle", "StreamArtistConsentFinalityLifecycle", "StreamArtistArchiveV2"];

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


const CHECKOUT = "7d414ed34f3d71424f40bb9448c992e8fa1b110d";
const CHECKOUT_TREE = "2444b7fbe02f04cb8be1adc3871e9d617ae28ce0";
const MOVE = "3f7bdf6bb3a5ea22731b877736fffa17df37cae9";
const REVIEW_SHA = "986a02f105e4cc6b55d673c74636533872479b5f3f30feef25a312e9110366ad";
const documents = ["docs/adr/0047-complete-artist-authority-hydration.md", "docs/adr/0048-attribution-repudiation-identity-effects.md", "docs/integrations/artist-recovered-multiple-disputes.md", "docs/architecture/artist-operation60-authority-hydration.json"];
const attributionPaths = ["AttributionClaimOperations", "AttributionClaimState", "AttributionDisputeTransport", "CoordinatorDisputeTransport", "DisputeAdmission", "DisputeHashes", "DisputeIdentityMutation", "DisputeOperations", "DisputeReadEncoding", "DisputeState", "DisputeWithdrawalAdmission", "DisputeWithdrawalOperations", "DisputeWithdrawalState", "RepudiationAdmission", "RepudiationAttributionTransport", "RepudiationFacts", "RepudiationHashes", "RepudiationIdentityMutation", "RepudiationOperations", "RepudiationReadEncoding", "RepudiationState", "RepudiationTiming", "Hashes", "RegistryDigestEncoding"].map(name => `smart-contracts/domains/artist/StreamArtist${name}.sol`).concat(["IStreamArtistAttributionDisputes", "IStreamArtistAttributionRepudiation", "IStreamArtistDisputeWithdrawal"].map(name => `smart-contracts/interfaces/stream/artist/${name}.sol`));
function closure(commit, roots) {
  const rows = {}; let pending = roots;
  while (pending.length) {
    Object.assign(rows, blobs(commit, [...new Set(pending)].sort()));
    pending = [...new Set(Object.entries(rows).flatMap(([path, row]) => imports(path, row.text)).filter(path => !Object.hasOwn(rows, path)))];
  }
  return sorted(rows);
}
// Source-only relocation proof. Preserve quoted strings while ignoring comments
// and layout; this is not a new compiler or a general runtime-equivalence claim.
function tokens(text) {
  return text.match(/\/\*[\s\S]*?\*\/|\/\/[^\r\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[A-Za-z_$][A-Za-z0-9_$]*|[0-9]+|[^\s]/g).filter(s => !s.startsWith("//") && !s.startsWith("/*"));
}
function interfaces(text) {
  const t = tokens(text), result = [];
  for (let i = 0; i < t.length; i++) if (t[i] === "interface") {
    const start = i, name = t[++i]; while (t[i] !== "{" && i < t.length) i++;
    let depth = 1; while (depth && ++i < t.length) { if (t[i] === "{") depth++; if (t[i] === "}") depth--; }
    if (depth) throw Error("Unbalanced interface declaration");
    result.push({ name, tokens: t.slice(start, i + 1) });
  }
  return result;
}
function nonInterfaceTokens(text) {
  const t = tokens(text), out = [];
  for (let i = 0; i < t.length; i++) {
    if (t[i] === "import") { while (t[i] !== ";" && i < t.length) i++; }
    else if (t[i] === "interface") { while (t[i] !== "{" && i < t.length) i++; let depth = 1; while (depth && ++i < t.length) { if (t[i] === "{") depth++; if (t[i] === "}") depth--; } }
    else out.push(t[i]);
  }
  return out;
}
function checkoutBridge(current, rootPaths) {
  const selected = closure(CHECKOUT, rootPaths), rows = {}, overrides = {}, deltas = [];
  for (const [path, row] of Object.entries(selected)) {
    const old = current[path]; rows[path] = { blob: row.blob, sha256: row.sha256, byteLength: row.byteLength, compilerSourceRawEqual: old?.text === row.text };
    if (old?.text !== row.text) { overrides[path] = row.text; deltas.push({ path, compilerSha256: old?.sha256 ?? null, checkoutSha256: row.sha256, nonImportNonInterfaceTokensEqual: old ? JSON.stringify(nonInterfaceTokens(old.text)) === JSON.stringify(nonInterfaceTokens(row.text)) : false }); }
  }
  const changed = git(["diff", "--name-status", `${MOVE}^`, MOVE, "--", "smart-contracts"]).toString().trim().split("\n").map(line => line.split("\t"));
  const added = changed.filter(([s]) => s === "A").map(([, p]) => p), modified = changed.filter(([s]) => s === "M").map(([, p]) => p);
  const oldRows = blobs(`${MOVE}^`, modified), newRows = blobs(MOVE, [...modified, ...added]), moves = [];
  for (const path of added) {
    const defs = interfaces(newRows[path].text); if (defs.length !== 1) throw Error(`Expected one relocated interface ${path}`);
    const d = defs[0], candidates = modified.filter(old => imports(old, newRows[old].text).includes(path)).flatMap(old => interfaces(oldRows[old].text).filter(x => x.name === d.name).map(x => ({ old, definition: x })));
    if (candidates.length !== 1 || JSON.stringify(candidates[0].definition.tokens) !== JSON.stringify(d.tokens)) throw Error(`Interface relocation differs ${path}`);
    moves.push({ name: d.name, from: candidates[0].old, to: path, declarationTokensSha256: sha(JSON.stringify(d.tokens)), declarationTokensEqual: true, oldSourceSha256: oldRows[candidates[0].old].sha256, newSourceSha256: newRows[path].sha256 });
  }
  if (moves.length !== 39 || modified.some(path => JSON.stringify(nonInterfaceTokens(oldRows[path].text)) !== JSON.stringify(nonInterfaceTokens(newRows[path].text)))) throw Error("Interface move changed another declaration");
  return { commit: CHECKOUT, tree: CHECKOUT_TREE, compilerWasRerun: false, sourceEqualsCompilerPin: false, interfaceMoveCommit: MOVE, interfaceMoves: moves, selectedClosureSources: Object.keys(rows).length, selectedClosureBytes: Object.values(rows).reduce((n, x) => n + x.byteLength, 0), sources: sorted(rows), sourceOverrides: sorted(overrides), deltas, description: "Checkout imports are separately retained. Thirty-nine interface declarations have exact token identity across the committed move. The selected closure also contains an unrelated UNBOUND collection-row extraction; its changed raw text is retained without a general runtime-equivalence assertion. ABI/method evidence remains ABI189 at b3ed, not this later checkout." };
}

export function artistRecoveredMultipleDisputeHydrationSourceProfile(inputRaw, outputRaw, bridgeRaw, handoffRaw, reviewRaw) {
  const baseRaw = readFileSync(baseURL), base = pinned(baseRaw, BASE_SHA, "retained ABI12");
  const input = pinned(inputRaw, INPUT_SHA, "ABI189 input"), output = pinned(outputRaw, OUTPUT_SHA, "ABI189 output"), bridge = pinned(bridgeRaw, BRIDGE_SHA, "ABI189 bridge");
  const handoff = pinned(handoffRaw, HANDOFF_SHA, "producer handoff"), review = pinned(reviewRaw, REVIEW_SHA, "producer review");
  if (bridge.commit !== TARGET || bridge.mismatches.length || handoff.commit !== PRODUCER || handoff.tree !== PRODUCER_TREE || review.featureCommit !== PRODUCER || review.followupProductionDelta !== false) throw Error("Source coordinates differ");
  for (const [commit, tree] of [[TARGET, TREE], [PRODUCER, PRODUCER_TREE], [CHECKOUT, CHECKOUT_TREE]]) if (git(["rev-parse", `${commit}^{tree}`]).toString().trim() !== tree) throw Error("Git tree differs");
  if ((output.errors ?? []).some(row => row.severity === "error")) throw Error("Compiler reported errors");
  const captured = capture(input, TARGET, 4406, bridge);
  const selectedNames = Object.entries(output.contracts).flatMap(([path, ds]) => Object.keys(ds).filter(name => name.startsWith(PREFIX) && path.startsWith("smart-contracts/")).map(name => [name, path])).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0);
  if (selectedNames.length !== 37) throw Error("Expected thirty-seven MULTIPLE_DISPUTE libraries");
  const rootPaths = [...new Set([...roots.map(name => base.selections[name].source), ...selectedNames.map(([, path]) => path)])].sort(), current = closure(TARGET, rootPaths);
  const rows = {}, overrides = {}, changed = [], added = [];
  for (const [path, row] of Object.entries(current)) {
    const original = base.sourceTexts[path], literal = input.sources[path]?.content;
    if (!captured.rows[path] || captured.rows[path].text !== row.text || (literal !== row.text && literal !== row.text.replace(/\r\n/g, "\n"))) throw Error(`Selected source differs from ABI189 ${path}`);
    const same = original === row.text;
    if (original !== undefined && sha(original) !== base.sourceHashes[path]) throw Error(`Retained source hash differs ${path}`);
    rows[path] = { blob: row.blob, sha256: row.sha256, byteLength: row.byteLength, compilerLiteralSha256: sha(literal), compilerLiteralBytes: Buffer.byteLength(literal), compiler189RawSourceEqual: literal === row.text, compiler189NormalizedSourceEqual: literal === row.text.replace(/\r\n/g, "\n"), retainedCompiler12SourceEqual: same };
    if (!same) { overrides[path] = row.text; if (original === undefined) added.push(path); else changed.push({ path, retainedSha256: sha(original), currentSha256: row.sha256 }); }
  }
  const retainedDeclarations = {}, abis = {}, selections = {}, methodIdentifiers = {}, libraryAbis = {}, librarySelections = {}, libraryMethodIdentifiers = {}, seen = new Map();
  for (const [path, row] of Object.entries(current)) for (const [name, declaration] of Object.entries(output.contracts[path] ?? {}).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)) {
    const declarationKind = kind(row.text, name), nominal = declarationKind === "library", m = methods(declaration);
    const fingerprint = JSON.stringify([declarationKind, declaration.abi, m]);
    if (seen.has(name)) { if (seen.get(name) !== fingerprint) throw Error(`Conflicting declaration ${name}`); const selection = nominal ? librarySelections[name] : selections[name]; if (selection) selection.additionalSources.push(path); if (retainedDeclarations[name]) retainedDeclarations[name].additionalSources.push(path); continue; }
    seen.set(name, fingerprint);
    const oldABI = nominal ? base.libraryAbis[name] : base.abis[name], oldSelection = nominal ? base.librarySelections[name] : base.selections[name], oldMethods = nominal ? base.libraryMethodIdentifiers[name] : base.methodIdentifiers[name];
    let unchanged = false;
    if (oldABI) {
      const abiEqual = JSON.stringify(oldABI) === JSON.stringify(declaration.abi), methodsEqual = JSON.stringify(oldMethods) === JSON.stringify(m);
      retainedDeclarations[name] = { kind: declarationKind, source: path, retainedSource: oldSelection.source, additionalSources: [], abiEqual, methodsEqual, retainedAbiSha256: sha(JSON.stringify(oldABI)), currentAbiSha256: sha(JSON.stringify(declaration.abi)), retainedMethodsSha256: sha(JSON.stringify(oldMethods)), currentMethodsSha256: sha(JSON.stringify(m)) };
      unchanged = abiEqual && methodsEqual;
    }
    if (!unchanged) {
      const as = nominal ? libraryAbis : abis, ss = nominal ? librarySelections : selections, ms = nominal ? libraryMethodIdentifiers : methodIdentifiers;
      as[name] = declaration.abi; ms[name] = m; ss[name] = { source: path, additionalSources: [], contract: name, full: true, nominal, sourceSha256: row.sha256, overridesRetainedABI: Boolean(oldABI) };
    }
  }
  const producerPaths = handoff.changedFiles.filter(path => path.startsWith("smart-contracts/")).sort(), producerRows = blobs(PRODUCER, producerPaths), integratedRows = blobs(TARGET, producerPaths), producerJoins = {};
  for (const path of producerPaths) { const a = producerRows[path], b = integratedRows[path]; if (path.includes("/StreamArtistRecoveredMultipleDispute") && a.text !== b.text) throw Error(`New family producer differs ${path}`); producerJoins[path] = { producerBlob: a.blob, compilerBlob: b.blob, producerSha256: a.sha256, compilerSha256: b.sha256, producerBytes: a.byteLength, compilerBytes: b.byteLength, rawEqual: a.text === b.text, ...(a.text === b.text ? {} : { producerText: a.text }) }; }
  const attributionCommit = "c715354ed57d2ab639f874cc595b272a7631de71", attributionOld = blobs(attributionCommit, attributionPaths), attributionNew = blobs(TARGET, attributionPaths), attributionReuse = {};
  for (const path of attributionPaths) { const a = attributionOld[path], b = attributionNew[path]; if (a.text !== b.text) throw Error(`Original attribution producer differs ${path}`); attributionReuse[path] = { originalBlob: a.blob, compilerBlob: b.blob, sha256: b.sha256, byteLength: b.byteLength, rawEqual: true }; }
  const retainedDocuments = blobs(TARGET, documents);
  return {
    schemaVersion: 1, profile: "artist-recovered-multiple-dispute-hydration-v1", feature: 16777216, requiredFeatures: 16785408, allowedFeatures: 16956415, knownFeatures: 33554431, advertisedFeatures: 25165823,
    currentSource: { commit: TARGET, tree: TREE },
    retainedCompilerEvidence: { sourceCommit: base.sourceCommit, sourceTree: base.sourceTree, fixtureFile: "current-artist-recovered-multiple-attestation-hydration-abi.json", fixtureSha256: BASE_SHA, fixtureBytes: baseRaw.length },
    compilerEvidence: { capture: "parallel-feature-batch189-20260922", sourceCommit: TARGET, sourceTree: TREE, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA, bridgeSha256: BRIDGE_SHA, ...captured.statistics, reportedTransport: "direct committed Git blob input, CRLF normalized" },
    producerEvidence: { commit: PRODUCER, tree: PRODUCER_TREE, handoffSha256: HANDOFF_SHA, reviewSha256: REVIEW_SHA, followupCommit: review.followupCommit, handoffText: handoffRaw.toString("utf8"), reviewText: reviewRaw.toString("utf8"), joins: producerJoins },
    attributionReuse: { commit: attributionCommit, compilerCommit: TARGET, joins: attributionReuse },
    checkoutBridge: checkoutBridge(current, rootPaths),
    qualification: { compilerWasRerun: false, selectedCompilerSourceEqualsCompilerInput: true, checkoutSourceEqualsCompilerInput: false, currentWholeSuiteSourceEqualityClaimed: false, nativeExecutionVerified: false, linkedRuntimeAdmissionVerified: false, sourceDerivedWrappers: ["five-field MULTIPLE_DISPUTE semantic envelope", "StreamArtistRecoveredMultipleDisputeTypes.Attribution"], description: "ABI189 remains pinned to b3ed. Complete selected source/declaration comparisons reuse unchanged bd4 witnesses and override every changed ABI. The later checkout import relocation has an explicit separate source bridge. Nominal library ABIs are value witnesses, never ordinary wallet endpoints. All thirty-seven new family libraries equal the producer; ten integrated owner/transport sources include separately retained UNBOUND changes. Producer handoff/review are retained reports, not independent execution evidence." },
    roots, rootPaths, statistics: { currentClosureSources: Object.keys(rows).length, currentClosureBytes: Object.values(rows).reduce((n, row) => n + row.byteLength, 0), reusedSourceCount: Object.keys(rows).length - changed.length - added.length, changedSourceCount: changed.length, addedSourceCount: added.length, retainedDeclarationCount: Object.keys(retainedDeclarations).length, ordinarySupplementCount: Object.keys(abis).length, ordinarySupplementEntries: Object.values(abis).reduce((n, abi) => n + abi.length, 0), ordinarySupplementSelectors: Object.values(methodIdentifiers).reduce((n, map) => n + Object.keys(map).length, 0), librarySupplementCount: Object.keys(libraryAbis).length, librarySupplementEntries: Object.values(libraryAbis).reduce((n, abi) => n + abi.length, 0), librarySupplementSelectors: Object.values(libraryMethodIdentifiers).reduce((n, map) => n + Object.keys(map).length, 0), multipleDisputeLibraryCount: selectedNames.length, documentCount: documents.length, documentBytes: Object.values(retainedDocuments).reduce((n, row) => n + row.byteLength, 0) },
    changedSources: changed, addedSources: added, sources: sorted(rows), sourceOverrides: sorted(overrides), retainedDeclarations: sorted(retainedDeclarations), abis: sorted(abis), selections: sorted(selections), methodIdentifiers: sorted(methodIdentifiers), libraryAbis: sorted(libraryAbis), libraryMethodIdentifiers: sorted(libraryMethodIdentifiers), librarySelections: sorted(librarySelections), documents: sorted(retainedDocuments),
  };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2), check = args.at(-1) === "--check"; if (check) args.pop();
  if (args.length !== 5 || args.some(arg => arg.startsWith("--"))) throw Error("Usage: node generate-current-artist-recovered-multiple-dispute-hydration-source-profile.mjs ABI189_INPUT ABI189_OUTPUT COMMITTED_BRIDGE PRODUCER_HANDOFF PRODUCER_REVIEW [--check]");
  const result = artistRecoveredMultipleDisputeHydrationSourceProfile(...args.map(path => readFileSync(path))), bytes = Buffer.from(JSON.stringify(result, null, 2) + "\n");
  if (check) { if (!readFileSync(outputURL).equals(bytes)) throw Error("MULTIPLE_DISPUTE source profile is stale"); }
  else writeFileSync(outputURL, bytes);
  console.log(JSON.stringify({ ...result.statistics, checkoutSources: result.checkoutBridge.selectedClosureSources, interfaceMoves: result.checkoutBridge.interfaceMoves.length, bytes: bytes.length, sha256: sha(bytes), check }));
}
