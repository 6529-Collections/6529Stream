import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, concat, getAddress, id, keccak256, toBeHex } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledABI, compiledInterfaces, compiledLibraryEvents, libraryValueABI, compiledLibraryValueInterface, multipleDisputeTuple, multipleDisputeSource, sourceProfile } from "./current-artist-recovered-multiple-dispute-hydration-source-fixture.mjs";

function literalReader(url, cache = new Map()) {
  if (cache.has(url.href)) return cache.get(url.href);
  const source = ts.createSourceFile(url.href, readFileSync(url, "utf8"), ts.ScriptTarget.Latest, true);
  const declarations = new Map(), imported = new Map(), namespaces = new Map();
  const read = name => {
    if (imported.has(name)) {
      const entry = imported.get(name);
      return literalReader(entry.url, cache)(entry.name);
    }
    return value(declarations.get(name));
  };
  cache.set(url.href, read);
  for (const statement of source.statements) {
    if (ts.isExportDeclaration(statement) && statement.moduleSpecifier && statement.exportClause && ts.isNamedExports(statement.exportClause)) {
      const target = new URL(statement.moduleSpecifier.text.replace(/\.js$/, ".ts"), url);
      for (const entry of statement.exportClause.elements) imported.set(entry.name.text, { url: target, name: entry.propertyName?.text ?? entry.name.text });
    }
    if (ts.isVariableStatement(statement)) for (const entry of statement.declarationList.declarations) {
      if (ts.isIdentifier(entry.name)) declarations.set(entry.name.text, entry.initializer);
    }
    if (ts.isImportDeclaration(statement) && statement.moduleSpecifier.text.startsWith(".")) {
      const target = new URL(statement.moduleSpecifier.text.replace(/\.js$/, ".ts"), url);
      const bindings = statement.importClause?.namedBindings;
      if (bindings && ts.isNamespaceImport(bindings)) namespaces.set(bindings.name.text, target);
      else if (bindings && ts.isNamedImports(bindings)) for (const entry of bindings.elements) {
        imported.set(entry.name.text, { url: target, name: entry.propertyName?.text ?? entry.name.text });
      }
    }
  }
  function value(node, locals = new Map()) {
    if (!node) throw Error(`Missing literal declaration in ${url.pathname}`);
    if (ts.isAsExpression(node) || ts.isSatisfiesExpression(node) || ts.isParenthesizedExpression(node)) return value(node.expression, locals);
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isBigIntLiteral(node)) return BigInt(node.text.replace(/n$/, "").replaceAll("_", ""));
    if (ts.isNumericLiteral(node)) return Number(node.text);
    if (ts.isPrefixUnaryExpression(node) && node.operator === ts.SyntaxKind.MinusToken) return -value(node.operand, locals);
    if (ts.isBinaryExpression(node) && node.operatorToken.kind === ts.SyntaxKind.PlusToken) {
      const left = value(node.left, locals), right = value(node.right, locals);
      assert.equal(typeof left, "string");
      assert.equal(typeof right, "string");
      return left + right;
    }
    if (ts.isObjectLiteralExpression(node)) return Object.fromEntries(node.properties.map(property => {
      assert.ok(ts.isPropertyAssignment(property), "literal object property");
      return [property.name.text, value(property.initializer, locals)];
    }));
    if (ts.isIdentifier(node)) return locals.has(node.text) ? locals.get(node.text) : read(node.text);
    if (ts.isPropertyAccessExpression(node) && ts.isIdentifier(node.expression) && namespaces.has(node.expression.text)) {
      return literalReader(namespaces.get(node.expression.text), cache)(node.name.text);
    }
    if (ts.isPropertyAccessExpression(node)) {
      const object = value(node.expression, locals);
      assert.ok(object !== null && typeof object === "object" && Object.hasOwn(object, node.name.text), "own literal property");
      return object[node.name.text];
    }
    if (ts.isTemplateExpression(node)) return node.head.text + node.templateSpans.map(span => value(span.expression, locals) + span.literal.text).join("");
    if (ts.isArrayLiteralExpression(node)) return node.elements.flatMap(element => ts.isSpreadElement(element) ? value(element.expression, locals) : [value(element, locals)]);

    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression)
      && node.expression.name.text === "map" && node.arguments.length === 1) {
      const fn = node.arguments[0];
      assert.ok(ts.isArrowFunction(fn) && fn.parameters.length === 1 && ts.isIdentifier(fn.parameters[0].name));
      const name = fn.parameters[0].name.text;
      return value(node.expression.expression, locals).map(item => value(fn.body, new Map([...locals, [name, item]])));
    }
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) && node.expression.name.text === "slice") {
      const input = value(node.expression.expression, locals), args = node.arguments.map(argument => value(argument, locals));
      assert.equal(typeof input, "string");
      assert.ok(args.length <= 2 && args.every(Number.isInteger));
      return input.slice(...args);
    }
    if (ts.isCallExpression(node) && node.expression.getText(source) === "Object.freeze") return value(node.arguments[0]);
    if (ts.isCallExpression(node) && node.expression.getText(source) === "childType" && node.arguments.length === 2) {
      const tuple = ParamType.from(value(node.arguments[0])), name = value(node.arguments[1]);
      const field = tuple.components.find(p => p.name === name);
      assert.ok(field, `Missing literal tuple member ${name}`);
      return field.format("full").replace(new RegExp(` ${name}$`), "");
    }
    if (ts.isNewExpression(node) && node.expression.getText(source) === "Interface") return value(node.arguments[0]);
    throw Error(`Nonliteral ABI expression in ${url.pathname}: ${node.getText(source)}`);
  }
  return read;
}

function sameFields(actual, expected, signature, tuple = false) {
  assert.ok(Array.isArray(actual) && Array.isArray(expected), signature + " parameter arrays");
  assert.equal(actual.length, expected.length, signature);
  for (let i = 0; i < expected.length; i++) {
    const a = actual[i], e = expected[i];
    assert.equal(a.format("sighash"), e.format("sighash"), signature);
    if (tuple) assert.equal(a.name, e.name, signature + "/" + e.name);
    if (e.baseType === "array") sameFields([a.arrayChildren], [e.arrayChildren], signature);
    if (e.baseType === "tuple") sameFields(a.components, e.components, signature, true);
  }
}

function compatibleFragment(actual, original) {
  assert.equal(actual.type, original.type);
  sameFields(actual.inputs, original.inputs, actual.format("sighash"));
  if (actual.type === "function") {
    sameFields(actual.outputs, original.outputs, actual.format("sighash"));
    assert.equal(actual.stateMutability, original.stateMutability);
  } else if (actual.type === "event") {
    assert.deepEqual(actual.inputs.map(p => Boolean(p.indexed)), original.inputs.map(p => Boolean(p.indexed)));
    assert.equal(actual.anonymous, original.anonymous);
  }
}

const sha = value => createHash("sha256").update(value).digest("hex");
const pureUrl = new URL("../src/current-artist-recovered-multiple-dispute-hydration.ts", import.meta.url);
const readPure = literalReader(pureUrl);
const PREFIX = "ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_";
const source = name => {
  const paths = Object.keys(sourceProfile.sources).filter(path => path.endsWith(`/${name}`));
  assert.equal(paths.length, 1, name); return multipleDisputeSource(paths[0]);
};
const shape = p => p.baseType === "array" ? { length: p.arrayLength, child: shape(p.arrayChildren) }
  : p.baseType === "tuple" ? p.components.map(p => ({ name: p.name, type: shape(p) })) : p.type;
const hash = (types, values) => keccak256(AbiCoder.defaultAbiCoder().encode(types, values));

const blob = bytes => createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");

test("compact dispute profile preserves distinct ABI189, producer, checkout and retained compiler identities", () => {
  const raw = readFileSync(new URL("./fixtures/current-artist-recovered-multiple-dispute-hydration-source-profile.json", import.meta.url));
  assert.equal(raw.length, 7389373); assert.equal(sha(raw), "a03aed691d0a326bad99846bdeb215f204fc982e586eb4faba517d392af1fa49");
  const old = readFileSync(new URL("./fixtures/current-artist-recovered-multiple-attestation-hydration-abi.json", import.meta.url));
  assert.equal(old.length, 39369402); assert.equal(sha(old), "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9");
  assert.equal(fixture.sourceCommit, "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b");
  assert.deepEqual(sourceProfile.currentSource, { commit: "b3ed602bcad94f09ee95f7abc1017d88df8178ba", tree: "c03d38362ab57966a6bb960ea8f3a31942408b94" });
  const e = sourceProfile.compilerEvidence;
  assert.equal(e.sourceCommit, sourceProfile.currentSource.commit); assert.equal(e.sourceTree, sourceProfile.currentSource.tree);
  assert.equal(e.inputSha256, "505d302f3457b8d9a3f6f757abd5bd55aae113b636b3e7a218f3fd119682a3f9");
  assert.equal(e.outputSha256, "420d25c7d872beffcc916fa12b4ea7a64c3afb79d787f834661389b05726eb72");
  assert.equal(e.bridgeSha256, "14591bd8112372d0b15361cd3a68f420676ff64682c78b2171e4c5c47be1c10e");
  assert.equal(e.sources, 4406); assert.equal(e.rawBytes, 51334744); assert.equal(e.literalBytes, 51334744);
  assert.equal(e.rawEqualCount, e.sources); assert.equal(e.normalizedOnlyCount, 0); assert.deepEqual(e.normalizedOnlyPaths, []);
  assert.equal(e.rawGitLiteralsEqual, true); assert.equal(e.lineEndingNormalizationApplied, false);
  assert.match(e.reportedTransport, /CRLF normalized/); // The reported procedure did not alter these observed literals.
  for (const key of ["compilerWasRerun", "checkoutSourceEqualsCompilerInput", "currentWholeSuiteSourceEqualityClaimed", "nativeExecutionVerified", "linkedRuntimeAdmissionVerified"]) assert.equal(sourceProfile.qualification[key], false);
  assert.deepEqual(sourceProfile.qualification.sourceDerivedWrappers, ["five-field MULTIPLE_DISPUTE semantic envelope", "StreamArtistRecoveredMultipleDisputeTypes.Attribution"]);
});

test("compiler closure, producer joins and original attribution reuse authenticate complete retained raw sources", () => {
  const visited = new Set();
  function visit(path) {
    if (visited.has(path)) return; visited.add(path);
    const text = multipleDisputeSource(path), bytes = Buffer.from(text), row = sourceProfile.sources[path];
    assert.equal(sha(bytes), row.sha256); assert.equal(bytes.length, row.byteLength); assert.equal(blob(bytes), row.blob);
    assert.equal(row.compilerLiteralSha256, row.sha256); assert.equal(row.compilerLiteralBytes, row.byteLength);
    assert.equal(row.compiler189RawSourceEqual, true); assert.equal(row.compiler189NormalizedSourceEqual, true);
    assert.equal(row.retainedCompiler12SourceEqual, text === fixture.sourceTexts[path]);
    for (const dep of solidityImports(text)) visit(dep.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), dep)) : dep);
  }
  sourceProfile.rootPaths.forEach(visit); assert.deepEqual([...visited].sort(), Object.keys(sourceProfile.sources).sort());
  assert.equal(visited.size, 1140); assert.equal([...visited].reduce((n, p) => n + sourceProfile.sources[p].byteLength, 0), 7269990);
  assert.equal(sourceProfile.changedSources.length, 28); assert.equal(sourceProfile.addedSources.length, 107); assert.equal(Object.keys(sourceProfile.sourceOverrides).length, 135);
  for (const row of sourceProfile.changedSources) { assert.equal(sha(fixture.sourceTexts[row.path]), row.retainedSha256); assert.equal(sha(multipleDisputeSource(row.path)), row.currentSha256); assert.notEqual(row.retainedSha256, row.currentSha256); }
  const p = sourceProfile.producerEvidence;
  assert.equal(p.commit, "b68ecb1eaf68b13df337f70255707d5de08033f7"); assert.equal(p.tree, "fb3521f8340d241277e330c62b2a7c883150ec17");
  assert.equal(p.followupCommit, "923c23268de3ca4470f1cf4e9a40f739e1083f9b");
  assert.equal(sha(p.handoffText), "24e724802e1d0606167515b44789381cbd71554d0e274e176181357687537e52");
  assert.equal(sha(p.reviewText), "986a02f105e4cc6b55d673c74636533872479b5f3f30feef25a312e9110366ad");
  assert.equal(Object.keys(p.joins).length, 54); assert.equal(Object.values(p.joins).filter(r => r.rawEqual).length, 44);
  for (const [path, row] of Object.entries(p.joins)) {
    const current = Buffer.from(multipleDisputeSource(path)), original = row.rawEqual ? current : Buffer.from(row.producerText);
    assert.equal(sha(current), row.compilerSha256); assert.equal(blob(current), row.compilerBlob); assert.equal(current.length, row.compilerBytes);
    assert.equal(sha(original), row.producerSha256); assert.equal(blob(original), row.producerBlob); assert.equal(original.length, row.producerBytes);
    assert.equal(original.equals(current), row.rawEqual);
    if (path.includes("/StreamArtistRecoveredMultipleDispute")) assert.equal(row.rawEqual, true);
  }
  const reuse = sourceProfile.attributionReuse;
  assert.equal(reuse.commit, "c715354ed57d2ab639f874cc595b272a7631de71"); assert.equal(reuse.compilerCommit, sourceProfile.currentSource.commit);
  assert.equal(Object.keys(reuse.joins).length, 27);
  for (const [path, row] of Object.entries(reuse.joins)) {
    const bytes = Buffer.from(multipleDisputeSource(path)); assert.equal(row.rawEqual, true);
    assert.equal(row.originalBlob, row.compilerBlob); assert.equal(blob(bytes), row.originalBlob); assert.equal(sha(bytes), row.sha256); assert.equal(bytes.length, row.byteLength);
  }
  assert.equal(Object.keys(sourceProfile.documents).length, 4);
  assert.equal(Object.values(sourceProfile.documents).reduce((n, row) => n + row.byteLength, 0), 42991);
  for (const row of Object.values(sourceProfile.documents)) { const bytes = Buffer.from(row.text); assert.equal(bytes.length, row.byteLength); assert.equal(sha(bytes), row.sha256); assert.equal(blob(bytes), row.blob); }
});

test("later checkout import relocation is an explicit source bridge without a fresh compiler or runtime claim", () => {
  const b = sourceProfile.checkoutBridge, visited = new Set();
  assert.equal(b.commit, "7d414ed34f3d71424f40bb9448c992e8fa1b110d"); assert.equal(b.tree, "2444b7fbe02f04cb8be1adc3871e9d617ae28ce0");
  assert.equal(b.compilerWasRerun, false); assert.equal(b.sourceEqualsCompilerPin, false);
  assert.equal(b.interfaceMoveCommit, "3f7bdf6bb3a5ea22731b877736fffa17df37cae9"); assert.equal(b.interfaceMoves.length, 39);
  for (const m of b.interfaceMoves) { assert.equal(m.declarationTokensEqual, true); assert.match(m.declarationTokensSha256, /^[a-f0-9]{64}$/); assert.notEqual(m.oldSourceSha256, m.newSourceSha256); }
  function visit(path) {
    if (visited.has(path)) return; visited.add(path);
    const text = b.sourceOverrides[path] ?? multipleDisputeSource(path), bytes = Buffer.from(text), row = b.sources[path];
    assert.equal(sha(bytes), row.sha256); assert.equal(bytes.length, row.byteLength); assert.equal(blob(bytes), row.blob);
    assert.equal(row.compilerSourceRawEqual, sourceProfile.sources[path]?.sha256 === row.sha256);
    for (const dep of solidityImports(text)) visit(dep.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), dep)) : dep);
  }
  sourceProfile.rootPaths.forEach(visit); assert.deepEqual([...visited].sort(), Object.keys(b.sources).sort());
  assert.equal(visited.size, 1152); assert.equal([...visited].reduce((n, p) => n + b.sources[p].byteLength, 0), 7273153);
  assert.equal(b.deltas.length, 24);
  const changedBodies = b.deltas.filter(row => !row.nonImportNonInterfaceTokensEqual && !row.path.startsWith("smart-contracts/interfaces/"));
  assert.deepEqual(changedBodies.map(row => row.path.split("/").at(-1)), ["StreamArtistUnboundPlatformCollectionRows.sol", "StreamArtistUnboundPlatformReplayRows.sol"]);
  for (const row of b.deltas) { assert.equal(sha(b.sourceOverrides[row.path]), row.checkoutSha256); assert.equal(sourceProfile.sources[row.path]?.sha256 ?? null, row.compilerSha256); }
});

test("all reused declarations retain full ABI equality and every changed nominal ABI has a current override", () => {
  const changed = [];
  assert.equal(Object.keys(sourceProfile.retainedDeclarations).length, 1182);
  for (const [name, row] of Object.entries(sourceProfile.retainedDeclarations)) {
    const oldABI = row.kind === "ordinary" ? fixture.abis[name] : fixture.libraryAbis[name];
    const oldMethods = row.kind === "ordinary" ? fixture.methodIdentifiers[name] : fixture.libraryMethodIdentifiers[name];
    const abi = row.kind === "ordinary" ? compiledABI(name) : sourceProfile.libraryAbis[name] ?? oldABI;
    const methods = (row.kind === "ordinary" ? sourceProfile.methodIdentifiers[name] : sourceProfile.libraryMethodIdentifiers[name]) ?? oldMethods;
    assert.equal(sha(JSON.stringify(oldABI)), row.retainedAbiSha256); assert.equal(sha(JSON.stringify(oldMethods)), row.retainedMethodsSha256);
    assert.equal(sha(JSON.stringify(abi)), row.currentAbiSha256); assert.equal(sha(JSON.stringify(methods)), row.currentMethodsSha256);
    if (!row.abiEqual || !row.methodsEqual) changed.push(name);
    else { assert.equal(row.retainedAbiSha256, row.currentAbiSha256); assert.equal(row.retainedMethodsSha256, row.currentMethodsSha256); }
  }
  assert.deepEqual(changed, ["StreamArtistConsentReadEncoding", "StreamArtistRecoveredDisputeIdentityFacts"]);
  for (const name of changed) assert.equal(sourceProfile.librarySelections[name].overridesRetainedABI, true);
  assert.equal(Object.keys(sourceProfile.abis).length, 1); assert.equal(Object.keys(sourceProfile.libraryAbis).length, 109);
  assert.equal(Object.keys(sourceProfile.libraryAbis).filter(name => name.startsWith("StreamArtistRecoveredMultipleDispute")).length, 37);
  let count = 0;
  for (const [name, map] of Object.entries(sourceProfile.libraryMethodIdentifiers)) for (const [signature, selector] of Object.entries(map)) { count++; assert.equal(id(signature).slice(2, 10), selector, name); }
  assert.equal(count, 192);
  for (const [name, map] of Object.entries(sourceProfile.methodIdentifiers)) for (const [signature, selector] of Object.entries(map)) assert.equal(new Interface(compiledABI(name)).getFunction(signature).selector, "0x" + selector);
  assert.throws(() => compiledABI("multipleDispute"), /ordinary|comparison/);
  const methods = sourceProfile.libraryMethodIdentifiers.StreamArtistRecoveredHydrationPrepared ?? fixture.libraryMethodIdentifiers.StreamArtistRecoveredHydrationPrepared;
  for (const [arity, selector] of [[2, "72c84763"], [3, "4925300f"]]) {
    const value = compiledLibraryValueInterface("prepared").fragments.find(f => f.type === "function" && f.name === "prepare" && f.inputs.length === arity);
    assert.ok(Object.values(methods).includes(selector)); assert.notEqual(value.selector, "0x" + selector);
  }
});

test("every public tuple is compiler witnessed or explicitly qualified as an original source carrier", () => {
  const witnesses = new Set(), visit = p => { witnesses.add(JSON.stringify(shape(p))); if (p.baseType === "array") visit(p.arrayChildren); if (p.baseType === "tuple") p.components.forEach(visit); };
  for (const iface of Object.values(compiledInterfaces)) for (const f of iface.fragments) [...f.inputs ?? [], ...f.outputs ?? []].forEach(visit);
  for (const name of [...new Set([...Object.keys(fixture.libraryAbis), ...Object.keys(sourceProfile.libraryAbis)])]) for (const f of libraryValueABI(name)) {
    const recurse = field => { try { visit(ParamType.from(field)); } catch { /* Storage/nominal parameters remain nominal. */ } for (const c of field.components ?? []) recurse(c); };
    [...f.inputs ?? [], ...f.outputs ?? []].forEach(recurse);
  }
  const tree = ts.createSourceFile(pureUrl.pathname, readFileSync(pureUrl, "utf8"), ts.ScriptTarget.Latest, true), names = new Set();
  for (const s of tree.statements) {
    if (ts.isVariableStatement(s) && s.modifiers?.some(m => m.kind === ts.SyntaxKind.ExportKeyword)) for (const d of s.declarationList.declarations) if (ts.isIdentifier(d.name) && d.name.text.endsWith("_TUPLE")) names.add(d.name.text);
    if (ts.isExportDeclaration(s) && s.exportClause && ts.isNamedExports(s.exportClause)) for (const d of s.exportClause.elements) if (d.name.text.endsWith("_TUPLE")) names.add(d.name.text);
  }
  for (const name of names) {
    const p = ParamType.from(readPure(name));
    if (name === PREFIX + "ENVELOPE_TUPLE") {
      assert.match(source("StreamArtistRecoveredHydrationTypes.sol"), /struct Envelope\s*\{\s*ExportHeader header;\s*bytes payload;/);
      assert.deepEqual(p.components.map(c => c.name), ["header", "payload"]); assert.ok(witnesses.has(JSON.stringify(shape(p.components[0])))); assert.equal(p.components[1].type, "bytes");
    } else if (name === PREFIX + "ATTRIBUTION_TUPLE") {
      assert.match(source("StreamArtistRecoveredMultipleDisputeTypes.sol"), /struct Attribution\s*\{\s*D\.Bundle history;\s*Records\.Bundle records;/);
      assert.deepEqual(p.components.map(c => c.name), ["history", "records"]);
      sameFields([p.components[0]], [multipleDisputeTuple("StreamArtistRecoveredDisputeHistoryTypes.Bundle")], name);
      assert.ok(witnesses.has(JSON.stringify(shape(p.components[1]))));
      assert.throws(() => multipleDisputeTuple("StreamArtistRecoveredMultipleDisputeTypes.Attribution"), /No ABI189/);
    } else assert.ok(witnesses.has(JSON.stringify(shape(p))), name);
  }
  assert.ok(names.size >= 65, "complete inherited and new tuple surface");
});

test("closed feature selection and all-owner current recheck preserve original global accounting", () => {
  assert.equal(readPure(PREFIX + "SOURCE"), sourceProfile.currentSource.commit);
  for (const [name, value] of [["BASE", 16777216n], ["DISPUTE_HISTORY", 8192n], ["ALLOWED_FEATURES", 16956415n], ["KNOWN_FEATURES", 33554431n]]) assert.equal(readPure(PREFIX + name), value);
  assert.equal(sourceProfile.requiredFeatures, 16785408); assert.equal(sourceProfile.advertisedFeatures, 25165823);
  const types = source("StreamArtistRecoveredMultipleDisputeTypes.sol"), codec = source("StreamArtistRecoveredMultipleDisputeCodec.sol"), current = source("StreamArtistRecoveredMultipleDisputeCurrent.sol");
  assert.match(types, /6529STREAM_ARTIST_MULTIPLE_DISPUTE_HISTORY_V1/); assert.match(types, /2276351\s*-\s*2097152\s*\+\s*FEATURE/);
  assert.match(codec, /abi\.encode\(SCHEMA, M\.VERSION, owner, s, auxiliary\)/);
  assert.match(codec, /owner == 0 \|\| owner == 3 \|\| owner == 4/); assert.match(codec, /G\.FEATURE \| RH\.DISPUTE_HISTORY/);
  assert.match(codec, /p\.journal\.length/); assert.match(codec, /s\.artists\[artist\(s, first\.artistId\)\]\.records/);
  assert.match(current, /Proof\.requireValid\(scope, p\.provenance, inventory\)/);
  assert.match(current, /Catalogue\.requireCurrent\(full, inventory\.catalogues, inventory\.operations\)/);
  const conservation = source("StreamArtistRecoveredMultipleDisputeConservation.sol");
  assert.match(conservation, /consent\[a\]\[g\] \+ attested\[a\]\[g\] \+ disputed\[a\]\[g\] != b\.delegations\[g\]\.record\.uses/);
  assert.match(conservation, /Disputes\.validate\(Disputes\.Context\(x\.identities, x\.scope, x\.histories, x\.provenance\)\)/);
});

test("both original Registry routes and every workflow ordinary read match the complete ABI189 witnesses", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-dispute-hydration.js");
  const api = new Interface(r.CURRENT_ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_ABI);
  assert.deepEqual(api.fragments.filter(f => f.type === "function").map(f => f.name), ["hydrateRecoveredArtistAuthority", "hydrateRecoveredArtistAuthorityWithConsents"]);
  for (const f of api.fragments) { const original = compiledInterfaces.registry.fragments.find(g => g.type === f.type && g.format("sighash") === f.format("sighash")); assert.ok(original); compatibleFragment(f, original); }
  assert.equal(api.getFunction("hydrateRecoveredArtistAuthority").selector, "0xb80889ba"); assert.equal(api.getFunction("hydrateRecoveredArtistAuthorityWithConsents").selector, "0x1e2d2f62");
  const get = literalReader(new URL("../src/current-artist-recovered-multiple-dispute-hydration-workflow.ts", import.meta.url));
  const all = Object.values(compiledInterfaces).flatMap(iface => iface.fragments);
  for (const name of ["abi", "consentAbi", "identityAbi", "attestationAbi", "clockAbi", "generationAbi"]) for (const f of new Interface(get(name)).fragments) {
    assert.equal(f.type, "function"); assert.ok(["view", "pure"].includes(f.stateMutability));
    assert.ok(all.some(original => { if (original.type !== f.type || original.format("sighash") !== f.format("sighash")) return false; try { compatibleFragment(f, original); return true; } catch { return false; } }), name + f.format("full"));
  }
  // Safe is a separately reviewed transport; this profile does not declare a new Safe host ABI.
  const safe = new Interface(get("safeABI"));
  assert.deepEqual(safe.fragments.filter(f => f.type === "function").map(f => f.name).sort(), ["execTransaction", "getTransactionHash", "nonce"]);
  const priorSafe = new Interface(literalReader(new URL("../src/current-artist-recovered-multiple-generation-hydration-workflow.ts", import.meta.url))("safeABI"));
  for (const f of safe.fragments) compatibleFragment(f, priorSafe.getFunction(f.format("sighash")));
});

// Compiler-shaped raw values only. They do not prove original state admission.
function specimen(p, depth = 0) {
  if (p.baseType === "array") return Array.from({ length: p.arrayLength < 0 ? (depth < 4 ? 1 : 0) : p.arrayLength }, () => specimen(p.arrayChildren, depth + 1));
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(c => [c.name, specimen(c, depth + 1)]));
  if (p.type === "address") return getAddress(toBeHex(7n, 20));
  if (p.type === "bool") return true; if (p.type === "string") return "urn:source:Unicode-😀"; if (p.type === "bytes") return "0x123456";
  if (/^bytes[0-9]+$/.test(p.type)) return toBeHex(9n, Number(p.type.slice(5)));
  if (/^uint/.test(p.type)) return p.type === "uint256" ? (1n << 220n) + 19n : p.type === "uint64" ? (1n << 50n) + 3n : 0n;
  throw Error(`Unsupported compiler specimen ${p.type}`);
}

test("raw dispute and generation codecs preserve original nested compiler tuples and full-width values", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-dispute-hydration.js"), coder = AbiCoder.defaultAbiCoder();
  for (const [suffix, type] of [["Inventory", "StreamArtistRecoveredMultipleGenerationTypes.Inventory"], ["Generation", "StreamArtistRecoveredAcceptedGenerationTypes.Generation"], ["BindingBundle", "StreamArtistRecoveredBindingCorrectionTypes.Bundle"], ["AcceptanceBundle", "StreamArtistRecoveredAcceptedGenerationTypes.AcceptanceBundle"], ["AttributionHistory", "StreamArtistRecoveredDisputeHistoryTypes.Bundle"], ["Consents", "StreamArtistRecoveredMultipleGenerationTypes.Consents"]]) {
    const p = multipleDisputeTuple(type), value = specimen(p), raw = coder.encode([p], [value]);
    assert.equal(r[`encodeArtistRecoveredMultipleDisputeHydration${suffix}`](value), raw, suffix);
    assert.deepEqual(r[`decodeArtistRecoveredMultipleDisputeHydration${suffix}`](raw), value, suffix);
    assert.throws(() => r[`decodeArtistRecoveredMultipleDisputeHydration${suffix}`](raw + "00".repeat(32)), /canonical|length|trailing/i, suffix);
  }
});

test("unchanged original dispute and repudiation preimages retain distinct domains and omitted metadata", async () => {
  const a = await import("../dist/current-artist-attribution.js");
  const c = { chainId: (1n << 128n) + 7n, registry: getAddress(toBeHex(11n, 20)), core: getAddress(toBeHex(12n, 20)) };
  const record = specimen(ParamType.from(a.ARTIST_ATTRIBUTION_RECORD_TUPLE)), rep = specimen(ParamType.from(a.ARTIST_ATTRIBUTION_REPUDIATION_RECORD_TUPLE));
  record.terms.disputeAction = 2n; rep.terms.disputeAction = 3n;
  const p = record.terms, q = rep.terms;
  const expected = hash(["bytes32", "uint256", "address", "uint256", "uint64", "uint8", "address", "uint8", "bytes32", "bytes32", "uint256", "uint64"], [id("6529STREAM_ARTIST_DISPUTE_RECORD_V1"), c.chainId, c.registry, p.collectionId, p.bindingGeneration, p.disputeAction, record.signer, record.authorityClass, p.evidenceHash, p.reasonHash, record.nonce, record.recordedAt]);
  const repudiated = hash(["bytes32", "uint256", "address", "uint256", "uint64", "bytes32", "address", "uint8", "bytes32", "bytes32", "uint256", "uint64", "uint64"], [id("6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1"), c.chainId, c.registry, q.collectionId, q.bindingGeneration, rep.artistId, rep.signer, rep.authorityClass, q.evidenceHash, q.reasonHash, rep.nonce, rep.stagedAt, rep.executableAt]);
  assert.equal(a.artistAttributionDisputeRecordHash(c, record), expected); assert.equal(a.artistAttributionRepudiationRecordHash(c, rep), repudiated); assert.notEqual(expected, repudiated);
  assert.equal(a.artistAttributionDisputeRecordHash({ ...c, core: getAddress(toBeHex(99n, 20)) }, record), expected, "native dispute hash excludes Core");
  assert.notEqual(a.artistAttributionDisputeRecordHash(c, { ...record, recordedAt: record.recordedAt + 1n }), expected);
  assert.notEqual(a.artistAttributionRepudiationRecordHash(c, { ...rep, executableAt: rep.executableAt + 1n }), repudiated);
  assert.match(source("StreamArtistDisputeHashes.sol"), /6529STREAM_ARTIST_DISPUTE_RECORD_V1/); assert.match(source("StreamArtistRepudiationHashes.sol"), /6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1/);
});

test("original filing digest binds Core and authorization deadline while Archive envelopes retain flat ABI", async () => {
  const a = await import("../dist/current-artist-attribution.js"), r = await import("../dist/current-artist-recovered-multiple-dispute-hydration.js");
  const c = { chainId: (1n << 128n) + 9n, registry: getAddress(toBeHex(13n, 20)), core: getAddress(toBeHex(14n, 20)) };
  const p = { collectionId: (1n << 220n) + 5n, bindingGeneration: 7n, disputeAction: 4n, evidenceHash: ZeroHash, reasonHash: id("reason") };
  const authorization = { nonce: (1n << 230n) + 17n, time: 123456n, signature: "0x" };
  const domain = hash(["bytes32", "bytes32", "bytes32", "uint256", "address"], [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), c.chainId, c.registry]);
  const inner = hash(["bytes32", "address", "uint256", "uint64", "uint8", "bytes32", "bytes32", "uint256", "uint64"], [id("StreamArtistAttributionDispute(address core,uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash,uint256 nonce,uint64 deadline)"), c.core, p.collectionId, p.bindingGeneration, p.disputeAction, p.evidenceHash, p.reasonHash, authorization.nonce, authorization.time]);
  const expected = keccak256(concat(["0x1901", domain, inner]));
  assert.equal(a.artistAttributionSigningPayload(c, p, authorization).digest, expected);
  assert.notEqual(a.artistAttributionSigningPayload(c, p, { ...authorization, time: authorization.time + 1n }).digest, expected);
  const type = multipleDisputeTuple("StreamArtistRecoveredSanctionHistoryTypes.Envelope"), value = specimen(type), coder = AbiCoder.defaultAbiCoder();
  const flat = coder.encode(type.components, type.components.map(field => value[field.name]));
  assert.equal(r.encodeArtistRecoveredMultipleDisputeHydrationArchiveEnvelope(value), flat);
  assert.equal(a.encodeArtistAttributionArchiveEnvelope(value), flat);
  assert.deepEqual(r.decodeArtistRecoveredMultipleDisputeHydrationArchiveEnvelope(flat), value);
  const wrapped = coder.encode([type], [value]); assert.notEqual(wrapped, flat);
  assert.throws(() => r.decodeArtistRecoveredMultipleDisputeHydrationArchiveEnvelope(wrapped), /canonical|offset|length|bounds|overflow|boolean|allocation|capacity/i);
});

test("compiler preimages preserve full dispute inventory, repeated origins and the original op60 commitment", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-dispute-hydration.js");
  const { semanticFixture } = await import("./current-artist-recovered-multiple-dispute-hydration-semantic-fixture.mjs");
  // Documentary supplied facts only. Private admission, signature validity,
  // runtime provenance and actual Registry/Safe execution remain unproved.
  const original = compiledLibraryValueInterface("StreamArtistRecoveredHydrationCommitEncoding").getFunction("prepare");
  const member = name => {
    const result = original.inputs[6].components.find(field => field.name === name);
    assert.ok(result, `original CommitEncoding.Inputs.${name}`);
    return result;
  };
  const provenanceType = multipleDisputeTuple("StreamArtistRecoveredHydrationTypes.Provenance");
  const originType = multipleDisputeTuple("StreamArtistRecoveredHydrationTypes.OriginEnvironment");
  const profile = id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1");
  const types = ["bytes32", "uint16", ...original.inputs.slice(0, 3), member("prior"), member("sourceCoordinator"), original.inputs[5],
    member("artists"), member("collections"), member("query"), member("data"), member("timing"), member("externalGuards"), member("before_")];
  for (const options of [
    { history: "withdrawal", royalties: false },
    { history: "veto", attestations: true },
    { history: "withdrawal", repeated: true, attestations: true },
  ]) {
    const f = semanticFixture({ options }), p = f.certificate, q = f.request, provenance = p.admission.provenance;
    assert.equal(p.admission.artists.length, 2);
    assert.equal(p.admission.collections.length, 3);
    assert.ok(p.admission.collections.every(row => row.collectionId > 1n << 200n));
    assert.ok(f.identities.some(identity => identity.delegations.some(d => d.record.uses > 0n)));
    assert.equal(f.input.royaltyFreezes.length > 0, options.royalties !== false);
    assert.equal(provenance.journals[4].some(row => row.receipt.operation === 24n), options.attestations === true);
    assert.equal(provenance.eras.length, options.repeated ? 2 : 1);
    assert.equal(q.expectedSourceImportCommitment, provenance.eras.at(-1).priorImportCommitment);

    const originHashes = provenance.origins.map(origin => hash(["bytes32", "uint16", originType],
      [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_ORIGIN_V1"), 1n, origin]));
    assert.deepEqual(provenance.eras.map(era => era.originHash), originHashes);
    assert.equal(p.admission.prior, provenance.origins.at(-1).registry);
    assert.equal(p.admission.sourceCoordinator, provenance.origins.at(-1).coordinator);
    for (const [at, era] of provenance.eras.entries()) {
      const catalogue = f.clocks.catalogues[at];
      assert.equal(catalogue.originHash, era.originHash);
      assert.deepEqual(catalogue.lower, era.lowerRevisions);
      assert.deepEqual(catalogue.upper, era.checkpoints.map(checkpoint => checkpoint.ownerState.revision));
      const rows = f.archiveRows.filter(row => row.originHash === era.originHash);
      assert.equal(catalogue.count, BigInt(rows.length));
      assert.deepEqual(rows.map(row => row.catalogueIndex), rows.map((_, i) => BigInt(i)));
      for (const [owner, journal] of provenance.journals.entries()) {
        const native = journal.filter(row => row.position.point.environmentHash === era.originHash);
        assert.equal(era.nativeCounts[owner], BigInt(native.length));
        assert.deepEqual(native.map(row => row.position.nativeIndex), native.map((_, i) => BigInt(i)));
      }
    }
    if (options.repeated) {
      assert.notEqual(provenance.eras[1].priorImportCommitment, ZeroHash);
      assert.notEqual(provenance.origins[0].registry, provenance.origins[1].registry);
      for (const bundle of f.attribution) {
        const rows = bundle.history.disputes;
        for (const action of [1n, 3n]) assert.ok(rows.some(row => row.record.terms.disputeAction === action && row.point.environmentHash === originHashes[0]));
        assert.ok(rows.some(row => row.record.terms.disputeAction === 2n && row.point.environmentHash === originHashes[1]));
      }
      let carried = 0;
      for (const aliases of provenance.aliases) for (const old of aliases.filter(alias => alias.originHash === originHashes[0])) {
        const next = aliases.find(alias => alias.originHash === originHashes[1] && alias.surface === old.surface && alias.scope === old.scope);
        assert.ok(next, "original logical replay alias must survive the next namespace");
        assert.notEqual(next.originalKey, old.originalKey);
        assert.deepEqual(next.cell, old.cell);
        assert.deepEqual(next.admittedAt, old.admittedAt);
        carried++;
      }
      assert.ok(carried > 0);
    }

    const provenanceHash = hash(["bytes32", "uint16", provenanceType],
      [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_PROVENANCE_V1"), 1n, provenance]);
    const inventory = hash(["bytes32", "uint16", "bytes32", member("query"), member("data"), member("timing"), member("externalGuards")],
      [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, provenanceHash, p.query, p.data, p.timing, p.externalGuards]);
    assert.equal(q.expectedSemanticInventory, inventory);
    assert.equal(r.artistRecoveredMultipleDisputeHydrationSemanticInventory(p), inventory);
    const values = [profile, 1n, f.coords.chainId, f.coords.registry, f.coords.coordinator, p.admission.prior, p.admission.sourceCoordinator, q,
      p.admission.artists, p.admission.collections, p.query, p.data, p.timing, p.externalGuards, p.admission.before_];
    const commitment = hash(types, values);
    assert.equal(r.artistRecoveredMultipleDisputeHydrationCommitment(f.coords, q, p), commitment);
    assert.notEqual(commitment, hash(types, [id("6529STREAM_ARTIST_MULTIPLE_DISPUTE_HISTORY_V1"), ...values.slice(1)]));
    const call = r.prepareArtistRecoveredMultipleDisputeHydrationCall(f.coords.registry, getAddress(toBeHex(501n, 20)), f.input);
    const method = f.input.royaltyFreezes.length ? "hydrateRecoveredArtistAuthorityWithConsents" : "hydrateRecoveredArtistAuthority";
    assert.equal(call.call.data, compiledInterfaces.registry.encodeFunctionData(method, f.input.royaltyFreezes.length ? [q, f.input.royaltyFreezes] : [q]));
    assert.equal(call.call.value, 0n);
    assert.equal(call.factsVerified, false);
  }
  assert.match(source("StreamArtistRecoveredPreparationInventory.sol"), /RH\.VERSION,\s*provenance,\s*p\.query,\s*p\.data,\s*p\.timing,\s*p\.externalGuards/);
  assert.match(source("StreamArtistRecoveredHydrationCommitEncoding.sol"), /RH\.PROFILE,\s*RH\.VERSION,\s*chainId,\s*registry,\s*coordinator,\s*prepared\.prior,\s*prepared\.sourceCoordinator,\s*request,\s*prepared\.artists,\s*prepared\.collections,\s*prepared\.query,\s*prepared\.data,\s*prepared\.timing,\s*prepared\.externalGuards,\s*prepared\.before_/);
});
