import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toBeHex } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledABI, compiledInterfaces, compiledLibraryEvents, libraryValueABI, compiledLibraryValueInterface, unboundPlatformTuple, unboundPlatformSource, sourceProfile } from "./current-artist-unbound-platform-hydration-source-fixture.mjs";

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
const pureUrl = new URL("../src/current-artist-unbound-platform-hydration.ts", import.meta.url);
const readPure = literalReader(pureUrl);
const PREFIX = "ARTIST_UNBOUND_PLATFORM_HYDRATION_";
const source = name => {
  const paths = Object.keys(sourceProfile.sources).filter(path => path.endsWith(`/${name}`));
  assert.equal(paths.length, 1, name); return unboundPlatformSource(paths[0]);
};
const shape = p => p.baseType === "array" ? { length: p.arrayLength, child: shape(p.arrayChildren) }
  : p.baseType === "tuple" ? p.components.map(p => ({ name: p.name, type: shape(p) })) : p.type;
const hash = (types, values) => keccak256(AbiCoder.defaultAbiCoder().encode(types, values));

test("compact UNBOUND profile authenticates distinct ABI188, producer ABI7 and retained bd4 identities", () => {
  const bytes = readFileSync(new URL("./fixtures/current-artist-unbound-platform-hydration-source-profile.json", import.meta.url));
  assert.equal(bytes.length, 4392456); assert.equal(sha(bytes), "2ae405a97ad928622370ff5b7d97850685dc7a563c3d17d724c41b3d6bbb3e82");
  const old = readFileSync(new URL("./fixtures/current-artist-recovered-multiple-attestation-hydration-abi.json", import.meta.url));
  assert.equal(old.length, 39369402); assert.equal(sha(old), "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9");
  assert.equal(fixture.sourceCommit, "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b");
  assert.deepEqual(sourceProfile.currentSource, { commit: "66dc4a308f6a1c1b93187d7295554062d900b5fa", tree: "aa49cd7bb32bdd299b320e5a81057deda33e950f" });
  const e = sourceProfile.compilerEvidence, p = sourceProfile.producerEvidence;
  assert.equal(e.sourceCommit, sourceProfile.currentSource.commit); assert.equal(e.sourceTree, sourceProfile.currentSource.tree);
  assert.equal(e.inputSha256, "b71464b4baec6eb7a452e18e82fde3c2526af094cba36c81ef1476854f20ec6a");
  assert.equal(e.outputSha256, "5c48a4813cefc70012acdd76d3be93e8417bec060a9b76afb8e9dbe23261edfd");
  assert.equal(e.bridgeSha256, "d6879efac7719977f4fd2c50584863b7ebe6023d7d1e6116cece67b3067b8453");
  assert.equal(e.sources, 4365); assert.equal(e.rawBytes, 51013298); assert.equal(e.literalBytes, 51013298);
  assert.equal(p.commit, "8aa8c6606e15fcee0ccfc18348efa73539f487c0"); assert.equal(p.tree, "92e67c95ede5d9207c0edaa0a534e2bcd1a2c15a");
  assert.equal(p.sources, 1467); assert.equal(p.rawBytes, 9656943); assert.equal(p.literalBytes, 9656943);
  assert.equal(p.inputSha256, "ac2637aeb8a9d3a9bca0b7a557f8e3baadbe07acc48ca4157bd8272bff46d89d");
  assert.equal(p.outputSha256, "1cd5c6da07f21e00b0ec132f027aac58a0f4152838b3c7668a8602925028cd81");
  for (const x of [e, p]) { assert.equal(x.rawEqualCount, x.sources); assert.equal(x.normalizedOnlyCount, 0); assert.deepEqual(x.normalizedOnlyPaths, []); assert.equal(x.rawGitLiteralsEqual, true); assert.equal(x.lineEndingNormalizationApplied, false); }
  assert.match(e.reportedTransport, /CRLF normalized/); // reported procedure differs from observed zero conversions
  for (const key of ["compilerWasRerun", "currentWholeSuiteSourceEqualityClaimed", "nativeExecutionVerified", "linkedRuntimeAdmissionVerified"]) assert.equal(sourceProfile.qualification[key], false);
  assert.deepEqual(sourceProfile.qualification.sourceDerivedWrappers, ["four-field UNBOUND_PLATFORM semantic envelope", "three-field zero-Artist timing row", "StreamArtistUnboundPlatformCollectionRows.AttributionRow"]);
});

test("selected production source closure and producer bridge retain raw bytes and only the exact Consent inverse", () => {
  const visited = new Set();
  function visit(path) {
    if (visited.has(path)) return; visited.add(path);
    const text = unboundPlatformSource(path), row = sourceProfile.sources[path], bytes = Buffer.from(text);
    assert.equal(sha(bytes), row.sha256); assert.equal(bytes.length, row.byteLength);
    assert.equal(createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex"), row.blob);
    assert.equal(row.compilerLiteralSha256, row.sha256); assert.equal(row.compilerLiteralBytes, row.byteLength);
    assert.equal(row.compiler188RawSourceEqual, true); assert.equal(row.compiler188NormalizedSourceEqual, true);
    assert.equal(row.retainedCompiler12SourceEqual, text === fixture.sourceTexts[path]);
    for (const dep of solidityImports(text)) visit(dep.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), dep)) : dep);
  }
  sourceProfile.rootPaths.forEach(visit); assert.deepEqual([...visited].sort(), Object.keys(sourceProfile.sources).sort());
  assert.equal(visited.size, 1102); assert.equal([...visited].reduce((n, p) => n + sourceProfile.sources[p].byteLength, 0), 7041047);
  assert.equal(sourceProfile.changedSources.length, 26); assert.equal(sourceProfile.addedSources.length, 69); assert.equal(Object.keys(sourceProfile.sourceOverrides).length, 95);
  for (const row of sourceProfile.changedSources) { assert.equal(sha(fixture.sourceTexts[row.path]), row.retainedSha256); assert.equal(sha(unboundPlatformSource(row.path)), row.currentSha256); assert.notEqual(row.retainedSha256, row.currentSha256); }
  const p = sourceProfile.producerEvidence;
  assert.equal(sha(p.handoffText), "c8b2b4b58770bcf9afae90ac98e367c2adb121198d487f288475df523403e655");
  assert.equal(sha(p.integrationBridgeText), "574d79a2b518eff29074ab207a01af68649a07d4e7335d0332a4ff819ffa9f49");
  const bridge = JSON.parse(p.integrationBridgeText), handoff = JSON.parse(p.handoffText);
  assert.equal(bridge.head, sourceProfile.currentSource.commit); assert.equal(bridge.producer, p.commit); assert.equal(handoff.commit, p.commit);
  assert.deepEqual(Object.keys(p.joins).sort(), Object.keys(bridge.files).sort()); assert.equal(Object.keys(p.joins).length, 34);
  for (const [path, row] of Object.entries(p.joins)) {
    assert.equal(row.integrated.sha256, bridge.files[path]);
    if (path !== p.consentInverse.path) { assert.equal(row.rawEqual, true); assert.deepEqual(row.producer, row.integrated); }
    else {
      assert.equal(row.rawEqual, false); assert.equal(row.exactConsentGetterInverse, true);
      const current = unboundPlatformSource(path); assert.equal(current.split(p.consentInverse.integratedBody).length, 2);
      const restored = current.replace(p.consentInverse.integratedBody, p.consentInverse.producerBody);
      assert.equal(sha(restored), row.producer.sha256); assert.equal(Buffer.byteLength(restored), row.producer.byteLength);
      assert.equal(createHash("sha1").update(`blob ${row.producer.byteLength}\0`).update(restored).digest("hex"), row.producer.blob);
    }
  }
  assert.deepEqual(Object.keys(sourceProfile.documents).sort(), ["docs/adr/0047-complete-artist-authority-hydration.md", "docs/architecture/artist-operation60-authority-hydration.json", "docs/integrations/artist-unbound-platform-hydration.md"].sort());
  for (const row of Object.values(sourceProfile.documents)) { assert.equal(sha(row.text), row.sha256); assert.equal(Buffer.byteLength(row.text), row.byteLength); }
});

test("current full ordinary and nominal declarations preserve original selectors with an explicit changed-library override", () => {
  assert.equal(Object.keys(sourceProfile.retainedDeclarations).length, 1182);
  const changed = [];
  for (const [name, row] of Object.entries(sourceProfile.retainedDeclarations)) {
    const oldABI = row.kind === "ordinary" ? fixture.abis[name] : fixture.libraryAbis[name];
    const oldMethods = row.kind === "ordinary" ? fixture.methodIdentifiers[name] : fixture.libraryMethodIdentifiers[name];
    assert.equal(sha(JSON.stringify(oldABI)), row.retainedAbiSha256); assert.equal(sha(JSON.stringify(oldMethods)), row.retainedMethodsSha256);
    const abi = row.kind === "ordinary" ? compiledABI(name) : libraryValueABI(name) && (sourceProfile.libraryAbis[name] ?? fixture.libraryAbis[name]);
    const methods = (row.kind === "ordinary" ? sourceProfile.methodIdentifiers[name] : sourceProfile.libraryMethodIdentifiers[name]) ?? oldMethods;
    assert.equal(sha(JSON.stringify(abi)), row.currentAbiSha256); assert.equal(sha(JSON.stringify(methods)), row.currentMethodsSha256);
    if (!row.abiEqual || !row.methodsEqual) changed.push(name);
    else { assert.equal(row.retainedAbiSha256, row.currentAbiSha256); assert.equal(row.retainedMethodsSha256, row.currentMethodsSha256); }
  }
  assert.deepEqual(changed, ["StreamArtistConsentReadEncoding"]);
  assert.equal(sourceProfile.librarySelections.StreamArtistConsentReadEncoding.overridesRetainedABI, true);
  assert.equal(Object.keys(sourceProfile.abis).length, 1); assert.ok(compiledInterfaces.IStreamUnboundPlatformClaimHead);
  assert.equal(Object.keys(sourceProfile.libraryAbis).length, 70);
  let count = 0;
  for (const [name, map] of Object.entries(sourceProfile.libraryMethodIdentifiers)) for (const [signature, selector] of Object.entries(map)) { count++; assert.equal(id(signature).slice(2, 10), selector, name); }
  assert.equal(count, 132);
  for (const [name, map] of Object.entries(sourceProfile.methodIdentifiers)) for (const [signature, selector] of Object.entries(map)) assert.equal(new Interface(compiledABI(name)).getFunction(signature).selector, "0x" + selector);
  assert.throws(() => compiledABI("unboundPlatformCodec"), /ordinary|comparison/);
  const methodMap = fixture.libraryMethodIdentifiers.StreamArtistRecoveredHydrationPrepared;
  for (const [arity, selector] of [[2, "72c84763"], [3, "4925300f"]]) {
    const value = compiledLibraryValueInterface("prepared").fragments.find(f => f.type === "function" && f.name === "prepare" && f.inputs.length === arity);
    assert.ok(Object.values(methodMap).includes(selector)); assert.notEqual(value.selector, "0x" + selector);
  }
});

test("every exported tuple has a complete original compiler witness or an explicit source-defined carrier", () => {
  const witnesses = new Set(), visit = p => { witnesses.add(JSON.stringify(shape(p))); if (p.baseType === "array") visit(p.arrayChildren); if (p.baseType === "tuple") p.components.forEach(visit); };
  for (const iface of Object.values(compiledInterfaces)) for (const f of iface.fragments) [...f.inputs ?? [], ...f.outputs ?? []].forEach(visit);
  for (const name of [...new Set([...Object.keys(fixture.libraryAbis), ...Object.keys(sourceProfile.libraryAbis)])]) for (const f of libraryValueABI(name)) {
    const recurse = field => { try { visit(ParamType.from(field)); } catch { /* Nominal/storage values stay raw. */ } for (const c of field.components ?? []) recurse(c); };
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
      assert.match(source("StreamArtistRecoveredHydrationTypes.sol"), /struct Envelope\s*\{\s*ExportHeader header;\s*bytes payload;/); assert.deepEqual(p.components.map(c => c.name), ["header", "payload"]);
      assert.ok(witnesses.has(JSON.stringify(shape(p.components[0])))); assert.equal(p.components[1].type, "bytes");
    } else if (name === PREFIX + "ATTRIBUTION_TUPLE") {
      assert.match(source("StreamArtistUnboundPlatformCollectionRows.sol"), /struct AttributionRow\s*\{\s*Original\.AttributionBundle state;\s*bytes32 proposalOrigin;/);
      sameFields([p.components[0]], [unboundPlatformTuple("StreamArtistRecoveredCollectionHydration.AttributionBundle")], name);
      assert.deepEqual(p.components.map(c => c.name), ["state", "proposalOrigin"]); assert.equal(p.components[1].type, "bytes32");
      assert.throws(() => unboundPlatformTuple("StreamArtistUnboundPlatformCollectionRows.AttributionRow"), /No ABI188/);
    } else assert.ok(witnesses.has(JSON.stringify(shape(p))), name);
  }
  assert.ok(names.size >= 45, "complete exported tuple surface");
});

test("feature masks, original scoped rows and mandatory current source reads match pinned UNBOUND producers", () => {
  assert.equal(readPure(PREFIX + "SOURCE"), sourceProfile.currentSource.commit);
  for (const [name, value] of [["BASE", 4194304n], ["ALLOWED_FEATURES", 4194335n], ["KNOWN_FEATURES", 33554431n], ["ADVERTISED_FEATURES", 8388607n]]) assert.equal(readPure(PREFIX + name), value);
  assert.match(source("StreamArtistUnboundPlatformTypes.sol"), /6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1/);
  assert.match(source("StreamArtistExtendedHydrationFeatures.sol"), /UNBOUND_PLATFORM = 4194304/);
  const codec = source("StreamArtistUnboundPlatformCodec.sol"), prepared = source("StreamArtistUnboundPlatformPreparation.sol"), current = source("StreamArtistUnboundPlatformCurrent.sol");
  assert.match(codec, /abi\.encode\(U\.TAG, U\.VERSION, owner, s\)/);
  assert.match(codec, /owner == 2 && s\.artists\.length == 0/);
  assert.match(prepared, /royalties\.length != 0/); assert.match(prepared, /witnesses\.length != 0/);
  assert.match(prepared, /externalGuards\.schema = U\.TAG/);
  assert.match(current, /Catalogue\.requireCurrent\(full, b\.catalogues, b\.operations\)/);
  assert.match(current, /nextRegistrationNonce\(\) != 0/);
  assert.match(current, /expected\.schema = U\.TAG/);
  assert.match(source("StreamArtistUnboundPlatformEmptyIdentity.sol"), /abi\.encode\(U\.TAG, U\.VERSION, checkpoint\)/);
  assert.match(source("StreamArtistUnboundPlatformNativeRows.sol"), /c\.display != b\.latestDisplayClaim/);
});

test("Registry call and all workflow ordinary reads match the actual host compiler fragments", async () => {
  const r = await import("../dist/current-artist-unbound-platform-hydration.js");
  const api = new Interface(r.CURRENT_ARTIST_UNBOUND_PLATFORM_HYDRATION_ABI);
  assert.deepEqual(api.fragments.filter(f => f.type === "function").map(f => f.name), ["hydrateRecoveredArtistAuthority"]);
  for (const f of api.fragments) {
    const original = compiledInterfaces.registry.fragments.find(g => g.type === f.type && g.format("sighash") === f.format("sighash"));
    assert.ok(original); compatibleFragment(f, original);
  }
  const get = literalReader(new URL("../src/current-artist-unbound-platform-hydration-workflow.ts", import.meta.url));
  const all = Object.values(compiledInterfaces).flatMap(iface => iface.fragments);
  for (const name of ["abi", "collectionAbi", "clockAbi"]) for (const f of new Interface(get(name)).fragments) {
    assert.equal(f.type, "function"); assert.ok(["view", "pure"].includes(f.stateMutability));
    assert.ok(all.some(original => { if (original.type !== f.type || original.format("sighash") !== f.format("sighash")) return false; try { compatibleFragment(f, original); return true; } catch { return false; } }), name + f.format("full"));
  }
});

// Compiler-shaped encoding vectors only; these do not assert source admission.
function specimen(p, depth = 0) {
  if (p.baseType === "array") return Array.from({ length: p.arrayLength < 0 ? (depth < 4 ? 1 : 0) : p.arrayLength }, () => specimen(p.arrayChildren, depth + 1));
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(c => [c.name, specimen(c, depth + 1)]));
  if (p.type === "address") return getAddress(toBeHex(7n, 20));
  if (p.type === "bool") return true; if (p.type === "string") return "urn:source:Unicode-😀"; if (p.type === "bytes") return "0x123456";
  if (/^bytes[0-9]+$/.test(p.type)) return toBeHex(9n, Number(p.type.slice(5)));
  if (/^uint/.test(p.type)) return p.type === "uint256" ? (1n << 220n) + 19n : p.type === "uint64" ? (1n << 50n) + 3n : 0n;
  throw Error(`Unsupported compiler specimen ${p.type}`);
}

test("raw Platform and Archive metadata codecs preserve complete compiler fields and uint256 widths", async () => {
  const r = await import("../dist/current-artist-unbound-platform-hydration.js"), coder = AbiCoder.defaultAbiCoder();
  for (const [suffix, type] of [["Platform", "StreamArtistRecoveredPlatformTypes.Platform"], ["PlatformState", "StreamArtistPlatformTypes.State"], ["PlatformClaim", "StreamArtistPlatformTypes.Claim"], ["PlatformContest", "StreamArtistPlatformTypes.Contest"], ["AttributionClaim", "StreamArtistAttributionClaimTypes.Claim"], ["PlatformStatus", "StreamArtistPlatformCorrectionLineageTypes.Status"], ["Catalogue", "StreamArtistRecoveredPlatformTypes.Catalogue"], ["PlatformOperationEvidence", "StreamArtistRecoveredSanctionHistoryTypes.OperationEvidence"]]) {
    const p = unboundPlatformTuple(type), value = specimen(p), raw = coder.encode([p], [value]);
    assert.equal(r[`encodeArtistUnboundPlatformHydration${suffix}`](value), raw, suffix);
    assert.deepEqual(r[`decodeArtistUnboundPlatformHydration${suffix}`](raw), value, suffix);
    assert.throws(() => r[`decodeArtistUnboundPlatformHydration${suffix}`](raw + "00".repeat(32)), /canonical|length|trailing/i, suffix);
  }
});

test("zero-Artist timing row keeps its separate original flat three-field tag and canonical boundary", async () => {
  const r = await import("../dist/current-artist-unbound-platform-hydration.js"), coder = AbiCoder.defaultAbiCoder();
  const p = unboundPlatformTuple("StreamArtistRecoveredTimingTypes.Checkpoint");
  const cp = { schema: id("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1"), version: 1n, count: 0n, root: ZeroHash, configurationHash: id("zero timing fixture") };
  const types = ["bytes32", "uint16", p], values = [id("6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1"), 1n, cp], raw = coder.encode(types, values);
  assert.equal(r.encodeArtistUnboundPlatformHydrationEmptyIdentity(cp), raw); assert.deepEqual(r.decodeArtistUnboundPlatformHydrationEmptyIdentity(raw), cp);
  for (const [tag, version] of [[id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_GENERATIONS_V1"), 1n], [values[0], 2n]]) assert.throws(() => r.decodeArtistUnboundPlatformHydrationEmptyIdentity(coder.encode(types, [tag, version, cp])), /timing|principal|Invalid/);
  assert.throws(() => r.decodeArtistUnboundPlatformHydrationEmptyIdentity(raw + "00".repeat(32)), /canonical|length|timing|principal/);
});

test("original Archive envelope and inner Platform payloads are flat ABI sequences rather than tuple wrappers", async () => {
  const r = await import("../dist/current-artist-unbound-platform-hydration.js"), coder = AbiCoder.defaultAbiCoder();
  for (const [suffix, type] of [["ArchiveEnvelope", "StreamArtistRecoveredSanctionHistoryTypes.Envelope"], ["ClaimPayload", "StreamArtistRecoveredPlatformPayload.Claim"], ["ContestPayload", "StreamArtistRecoveredPlatformPayload.ContestPayload"]]) {
    const p = unboundPlatformTuple(type), value = specimen(p), values = p.components.map(c => value[c.name]), raw = coder.encode(p.components, values);
    assert.equal(r[`encodeArtistUnboundPlatformHydration${suffix}`](value), raw); assert.deepEqual(r[`decodeArtistUnboundPlatformHydration${suffix}`](raw), value);
    if (suffix !== "ContestPayload") {
      assert.notEqual(coder.encode([p], [value]), raw); assert.throws(() => r[`decodeArtistUnboundPlatformHydration${suffix}`](coder.encode([p], [value])), /canonical|offset|length|bounds|overflow|boolean|allocation|capacity/i);
    } else assert.equal(coder.encode([p], [value]), raw, "The complete static tuple has no outer dynamic offset");
  }
});

test("original ordinary Binding commitment uses its captured origin and empty collaborator and capability sets", async () => {
  const r = await import("../dist/current-artist-unbound-platform-hydration.js");
  const o = specimen(unboundPlatformTuple("StreamArtistRecoveredHydrationTypes.OriginEnvironment"));
  const tuple = ParamType.from(readPure(PREFIX + "BINDING_TUPLE")), b = specimen(tuple.components.find(c => c.name === "item"));
  const collection = (1n << 220n) + 31n;
  const expected = hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"], [id("6529STREAM_ARTIST_BINDING_V1"), o.chainId, o.registry, o.core, collection, b.generation, b.artistId, b.artistAddress, b.identityRecordHash, b.consentMode, b.saleConsentScope, b.registryImmutabilityElection, hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []]), hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []])]);
  assert.equal(r.artistUnboundPlatformHydrationBindingHash(o, collection, b), expected);
  assert.notEqual(r.artistUnboundPlatformHydrationBindingHash({ ...o, registry: getAddress(toBeHex(8n, 20)) }, collection, b), expected);
  assert.match(source("StreamArtistUnboundPlatformCollectionRows.sol"), /b\.item\.generation != 1/);
});

test("compiler-derived original inventory and op60 preimages bind zero-Artist, mixed and repeated UNBOUND graphs", async () => {
  const r = await import("../dist/current-artist-unbound-platform-hydration.js");
  const { semanticFixture } = await import("./current-artist-unbound-platform-hydration-semantic-fixture.mjs");
  // Documentary synthetic inputs only. Private Identity/Payout semantics, runtime
  // provenance, signatures, governance and original Registry execution are mocked.
  const original = compiledLibraryValueInterface("StreamArtistRecoveredHydrationCommitEncoding").getFunction("prepare");
  const fields = original.inputs[6].components;
  const member = name => {
    const result = fields.find(field => field.name === name);
    assert.ok(result, `original CommitEncoding.Inputs.${name}`); return result;
  };
  const provenanceType = unboundPlatformTuple("StreamArtistRecoveredHydrationTypes.Provenance");
  const stateType = unboundPlatformTuple("StreamArtistRecoveredMultipleTypes.State");
  const coder = AbiCoder.defaultAbiCoder(), tag = id("6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1");
  const profile = id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1");
  for (const options of [{}, { claims: true }, { correction: true }, { mixed: true }, { repeated: true }]) {
    const f = semanticFixture(options), p = f.prepared, q = f.request;
    assert.equal(p.admission.artists.length, options.mixed ? 2 : 0);
    assert.equal(p.admission.collections.length, options.mixed ? 4 : 1);
    assert.equal(p.admission.provenance.eras.length, options.repeated ? 3 : 1);
    assert.equal(p.admission.collections[0].artistId, ZeroHash);
    assert.deepEqual(p.query.records, p.admission.collections[0].records, "zero-Artist anchor keeps the collection's complete original records");
    assert.ok(p.query.collectionId > 1n << 200n);
    if (options.claims || options.correction) assert.deepEqual(new Set(p.admission.provenance.journals[4].map(j => j.receipt.operation)), new Set(options.correction ? [8n, 9n, 10n, 11n, 53n] : [8n, 9n, 10n, 11n]));
    for (let owner = 0; owner < 7; owner++) {
      const canonical = coder.encode(["bytes32", "uint16", "uint8", stateType], [tag, 1n, BigInt(owner), f.states[owner]]);
      assert.equal(f.payloads[owner].semanticState, canonical, `owner ${owner} keeps the four-field semantic carrier`);
      assert.equal(r.encodeArtistUnboundPlatformHydrationState(f.states[owner], owner, f.payloads[owner].provenance), canonical);
    }
    const provenanceHash = hash(["bytes32", "uint16", provenanceType], [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_PROVENANCE_V1"), 1n, p.admission.provenance]);
    const inventory = hash(["bytes32", "uint16", "bytes32", member("query"), member("data"), member("timing"), member("externalGuards")], [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, provenanceHash, p.query, p.data, p.timing, p.externalGuards]);
    assert.equal(q.expectedSemanticInventory, inventory);
    assert.equal(r.artistUnboundPlatformHydrationSemanticInventory(p), inventory);
    assert.equal(p.externalGuards.schema, options.mixed ? id("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1") : tag);
    assert.equal(p.externalGuards.artistId, options.mixed ? p.admission.artists[0].artistId : ZeroHash);
    const types = ["bytes32", "uint16", ...original.inputs.slice(0, 3), member("prior"), member("sourceCoordinator"), original.inputs[5], member("artists"), member("collections"), member("query"), member("data"), member("timing"), member("externalGuards"), member("before_")];
    const values = [profile, 1n, f.coords.chainId, f.coords.registry, f.coords.coordinator, p.admission.prior, p.admission.sourceCoordinator, q, p.admission.artists, p.admission.collections, p.query, p.data, p.timing, p.externalGuards, p.admission.before_];
    const commitment = hash(types, values);
    assert.equal(r.artistUnboundPlatformHydrationCommitment(f.coords, q, p), commitment);
    assert.notEqual(hash(types, [tag, ...values.slice(1)]), commitment, "The unchanged outer op60 domain is not the new inner semantic tag");
    const profileBytes = coder.encode(["bytes32", "uint16", member("prior"), member("sourceCoordinator"), original.inputs[5], member("artists"), member("collections"), member("query"), member("data"), member("timing"), member("externalGuards")], [profile, 1n, p.admission.prior, p.admission.sourceCoordinator, q, p.admission.artists, p.admission.collections, p.query, p.data, p.timing, p.externalGuards]);
    assert.equal(r.encodeArtistUnboundPlatformHydrationProfileEvidence(q, p), profileBytes);
  }
  assert.match(source("StreamArtistRecoveredPreparationInventory.sol"), /RH\.VERSION,\s*provenance,\s*p\.query,\s*p\.data,\s*p\.timing,\s*p\.externalGuards/);
  assert.match(source("StreamArtistRecoveredHydrationCommitEncoding.sol"), /RH\.PROFILE,\s*RH\.VERSION,\s*chainId,\s*registry,\s*coordinator,\s*prepared\.prior,\s*prepared\.sourceCoordinator,\s*request,\s*prepared\.artists,\s*prepared\.collections,\s*prepared\.query,\s*prepared\.data,\s*prepared\.timing,\s*prepared\.externalGuards,\s*prepared\.before_/);
});
