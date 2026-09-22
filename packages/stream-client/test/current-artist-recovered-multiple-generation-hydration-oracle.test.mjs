import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toBeHex } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledABI, compiledInterfaces, compiledLibraryEvents, libraryValueABI, compiledLibraryValueInterface, generationTuple, generationSource, sourceProfile } from "./current-artist-recovered-multiple-generation-hydration-source-fixture.mjs";

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
const pureUrl = new URL("../src/current-artist-recovered-multiple-generation-hydration.ts", import.meta.url);
const readPure = literalReader(pureUrl);
const PREFIX = "ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_";
const source = name => {
  const paths = Object.keys(sourceProfile.sources).filter(path => path.endsWith(`/${name}`));
  assert.equal(paths.length, 1, name); return generationSource(paths[0]);
};
const shape = p => p.baseType === "array" ? { length: p.arrayLength, child: shape(p.arrayChildren) }
  : p.baseType === "tuple" ? p.components.map(p => ({ name: p.name, type: shape(p) })) : p.type;
const hash = (types, values) => keccak256(AbiCoder.defaultAbiCoder().encode(types, values));

test("compact generation bridge preserves ABI12 and separately pins actual ABI178 and current source", () => {
  const compact = readFileSync(new URL("./fixtures/current-artist-recovered-multiple-generation-hydration-source-profile.json", import.meta.url));
  assert.equal(compact.length, 3125821);
  assert.equal(sha(compact), "fabd0a15ac8d2ea5d8013d8b2ede7594d768627284182b7c63ba1e57edae5d53");
  const raw = readFileSync(new URL("./fixtures/current-artist-recovered-multiple-attestation-hydration-abi.json", import.meta.url));
  assert.equal(sha(raw), "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9");
  assert.equal(raw.length, 39369402);
  assert.equal(fixture.sourceCommit, "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b");
  assert.equal(sourceProfile.retainedCompilerEvidence.fixtureSha256, sha(raw));
  assert.deepEqual(sourceProfile.currentSource, { commit: "45828ad0db2a6d52c6b0c7aad8d25dd4ba866c65", tree: "19426e71f466f9e5f4d7a3f8b2ee26c17d3d350c" });
  const e = sourceProfile.compilerEvidence;
  assert.equal(e.sourceCommit, "d823d82c971fdf63906895852a7c6bd6543d5982");
  assert.equal(e.sourceTree, "7b65371966647ec1f77a584082d46d1b956c1ad8");
  assert.equal(e.inputSha256, "6b8a709dc4cb2e9851a23956d18b29f3a6f2ed0c8e15002269ab35f30337aff5");
  assert.equal(e.outputSha256, "e33031906a3d48ba55f017d587fb2b16848cf679ff28f72ebbd3378c480fc9e5");
  assert.equal(e.bridgeSha256, "1012e62388432b213c7dce3c5f5bf17c16954b3b3ec9ad5f14c7ac07bf2eb2e2");
  assert.equal(e.sources, 4321); assert.equal(e.literalBytes, 50597455);
  assert.equal(e.rawGitLiteralsEqual, true); assert.equal(e.lineEndingNormalizationApplied, false);
  assert.equal(sourceProfile.qualification.selectedCurrentSourceEqualsCompilerInput, true);
  for (const key of ["compilerWasRerun", "currentWholeSuiteSourceEqualityClaimed", "nativeExecutionVerified", "linkedRuntimeAdmissionVerified"]) assert.equal(sourceProfile.qualification[key], false, key);
  assert.deepEqual(sourceProfile.qualification.sourceDerivedWrappers, ["five-field generation envelope", "StreamArtistRecoveredMultipleGenerationTypes.Attribution"]);
});

test("current concrete production roots retain a complete raw import closure and exact documents", () => {
  const seen = new Set(), visit = path => {
    if (seen.has(path)) return; seen.add(path);
    const text = generationSource(path), row = sourceProfile.sources[path], bytes = Buffer.from(text);
    assert.equal(sha(bytes), row.sha256, path); assert.equal(bytes.length, row.byteLength, path);
    assert.equal(createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex"), row.blob, path);
    assert.equal(row.compiler178SourceEqual, true);
    assert.equal(row.retainedCompiler12SourceEqual, fixture.sourceTexts[path] === text);
    for (const dependency of solidityImports(text)) visit(dependency.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), dependency)) : dependency);
  };
  assert.deepEqual(sourceProfile.roots, ["StreamArtistOnboardingRegistry", "StreamArtistOnboardingCoordinator", "StreamArtistBindingLifecycle", "StreamArtistCollaboratorLifecycle", "StreamArtistIdentityAuthority", "StreamArtistAcceptanceLifecycle", "StreamArtistAttributionLifecycle", "StreamArtistPayoutLifecycle", "StreamArtistConsentFinalityLifecycle", "StreamArtistArchiveV2"]);
  sourceProfile.rootPaths.forEach(visit);
  assert.deepEqual([...seen].sort(), Object.keys(sourceProfile.sources).sort());
  assert.equal(seen.size, 1078); assert.equal([...seen].reduce((n, path) => n + sourceProfile.sources[path].byteLength, 0), 6910755);
  assert.equal(sourceProfile.changedSources.length, 21); assert.equal(sourceProfile.addedSources.length, 45);
  assert.equal(Object.keys(sourceProfile.sourceOverrides).length, 66);
  for (const row of sourceProfile.changedSources) {
    assert.equal(sha(fixture.sourceTexts[row.path]), row.retainedSha256);
    assert.equal(sha(generationSource(row.path)), row.currentSha256);
    assert.notEqual(row.retainedSha256, row.currentSha256);
  }
  assert.deepEqual(Object.keys(sourceProfile.documents).sort(), ["docs/adr/0047-complete-artist-authority-hydration.md", "docs/architecture/artist-operation60-authority-hydration.json", "docs/integrations/artist-recovered-multiple-generations.md"].sort());
  for (const [path, row] of Object.entries(sourceProfile.documents)) {
    assert.equal(sha(row.text), row.sha256, path); assert.equal(Buffer.byteLength(row.text), row.byteLength, path);
  }
});

test("retained complete declarations and all new nominal selectors remain original compiler evidence", () => {
  assert.equal(Object.keys(sourceProfile.retainedDeclarations).length, 1182);
  for (const [name, row] of Object.entries(sourceProfile.retainedDeclarations)) {
    const abi = row.kind === "ordinary" ? fixture.abis[name] : fixture.libraryAbis[name];
    const methods = row.kind === "ordinary" ? fixture.methodIdentifiers[name] : fixture.libraryMethodIdentifiers[name];
    assert.ok(abi && methods, name); assert.equal(row.abiEqual, true, name); assert.equal(row.methodsEqual, true, name);
    assert.equal(sha(JSON.stringify(abi)), row.retainedAbiSha256, name); assert.equal(row.retainedAbiSha256, row.currentAbiSha256, name);
    assert.equal(sha(JSON.stringify(methods)), row.retainedMethodsSha256, name); assert.equal(row.retainedMethodsSha256, row.currentMethodsSha256, name);
    if (row.kind === "ordinary") {
      assert.deepEqual(compiledABI(name), abi);
      const functions = compiledInterfaces[name].fragments.filter(f => f.type === "function");
      assert.equal(functions.length, Object.keys(methods).length, name);
      for (const f of functions) assert.equal(f.selector.slice(2), methods[f.format("sighash")], name);
    } else for (const [signature, selector] of Object.entries(methods)) assert.equal(id(signature).slice(2, 10), selector, name);
  }
  assert.equal(Object.keys(sourceProfile.libraryAbis).length, 38);
  assert.equal(Object.values(sourceProfile.libraryAbis).reduce((n, abi) => n + abi.length, 0), 83);
  let count = 0;
  for (const [name, methods] of Object.entries(sourceProfile.libraryMethodIdentifiers)) {
    const selection = sourceProfile.librarySelections[name];
    assert.equal(sha(generationSource(selection.source)), selection.sourceSha256, name);
    for (const [signature, selector] of Object.entries(methods)) { count++; assert.equal(id(signature).slice(2, 10), selector, name); }
  }
  assert.equal(count, 53); assert.throws(() => compiledABI("multipleGenerationCodec"), /ordinary|comparison/);
  for (const [arity, selector] of [[2, "0x72c84763"], [3, "0x4925300f"]]) {
    const f = compiledLibraryValueInterface("prepared").fragments.find(f => f.type === "function" && f.name === "prepare" && f.inputs.length === arity);
    assert.ok(f); assert.notEqual(f.selector, selector);
    assert.ok(Object.values(fixture.libraryMethodIdentifiers.StreamArtistRecoveredHydrationPrepared).includes(selector.slice(2)));
  }
});

test("every public tuple has a complete compiler witness or an explicit source-defined wrapper", () => {
  const witnesses = new Set(), visit = p => {
    witnesses.add(JSON.stringify(shape(p)));
    if (p.baseType === "array") visit(p.arrayChildren);
    if (p.baseType === "tuple") p.components.forEach(visit);
  };
  for (const iface of Object.values(compiledInterfaces)) for (const f of iface.fragments) [...f.inputs ?? [], ...f.outputs ?? []].forEach(visit);
  for (const name of [...Object.keys(fixture.libraryAbis), ...Object.keys(sourceProfile.libraryAbis)]) for (const f of libraryValueABI(name)) for (const p of [...f.inputs ?? [], ...f.outputs ?? []]) {
    const recurse = field => { try { visit(ParamType.from(field)); } catch { /* Storage/nominal non-value parameters stay raw. */ } for (const c of field.components ?? []) recurse(c); };
    recurse(p);
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
      assert.deepEqual(p.components.map(c => c.name), ["header", "payload"]);
    } else if (name === PREFIX + "ATTRIBUTION_TUPLE") {
      assert.match(source("StreamArtistRecoveredMultipleGenerationTypes.sol"), /struct Attribution\s*\{\s*A\.AttributionBundle history;\s*Records\.Bundle records;/);
      sameFields([p.components[0]], [generationTuple("StreamArtistRecoveredAcceptedGenerationTypes.AttributionBundle")], name);
      assert.ok(witnesses.has(JSON.stringify(shape(p.components[1]))), name);
      assert.deepEqual(p.components.map(c => c.name), ["history", "records"]);
    } else assert.ok(witnesses.has(JSON.stringify(shape(p))), name);
  }
  assert.ok(names.size >= 65, "complete exported type surface");
  for (const [suffix, type] of [["INVENTORY", "StreamArtistRecoveredMultipleGenerationTypes.Inventory"], ["GENERATION", "StreamArtistRecoveredAcceptedGenerationTypes.Generation"], ["BINDING_BUNDLE", "StreamArtistRecoveredBindingCorrectionTypes.Bundle"], ["ACCEPTANCE_BUNDLE", "StreamArtistRecoveredAcceptedGenerationTypes.AcceptanceBundle"], ["ATTRIBUTION_HISTORY", "StreamArtistRecoveredAcceptedGenerationTypes.AttributionBundle"], ["CONSENTS", "StreamArtistRecoveredMultipleGenerationTypes.Consents"]]) {
    sameFields([ParamType.from(readPure(PREFIX + suffix + "_TUPLE"))], [generationTuple(type)], suffix);
  }
});

test("generation feature selection and unconditional post-write currentness follow the pinned producers", () => {
  assert.equal(readPure(PREFIX + "SOURCE"), sourceProfile.currentSource.commit);
  assert.equal(readPure(PREFIX + "BASE"), 2097152n); assert.equal(readPure(PREFIX + "ALLOWED_FEATURES"), 2276351n); assert.equal(readPure(PREFIX + "KNOWN_FEATURES"), 4194303n);
  const types = source("StreamArtistRecoveredMultipleGenerationTypes.sol");
  assert.match(types, /6529STREAM_ARTIST_RECOVERED_MULTIPLE_GENERATIONS_V1/);
  assert.match(types, /VERSION = 1/); assert.match(types, /FEATURE = 2097152/); assert.match(types, /ALLOWED = 2276351/);
  assert.match(source("StreamArtistRecoveredMultipleGenerationPreparation.sol"), /context\.features = G\.FEATURE \| RH\.BINDING_GENERATIONS/);
  const current = source("StreamArtistRecoveredMultipleGenerationCurrent.sol");
  for (const text of ["Clocks.validateLocal(scope, p.provenance, inventory)", "Revocations.validate(history, scope, p.provenance, inventory, clocks)", "Attestations.validate(scope, p.provenance, inventory, clocks)", "Catalogue.requireCurrent(full, inventory.catalogues, inventory.operations)"]) assert.ok(current.includes(text), text);
  assert.match(current, /RH\.ownerProvenance\(full, 4\)/);
  assert.doesNotMatch(current, /if\s*\([^)]*records\.length/);
  assert.match(source("StreamArtistRecoveredMultipleConsentNonces.sol"), /total != inventory\.length/);
  assert.match(source("StreamArtistRecoveredMultipleConsentFacts.sol"), /total\[g\] != identity\.delegations\[g\]\.record\.uses/);
});

test("the closed Registry surface and every workflow read match original complete ordinary fragments", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-generation-hydration.js");
  const api = new Interface(r["CURRENT_" + PREFIX + "ABI"]);
  assert.deepEqual(api.fragments.filter(f => f.type === "function").map(f => f.name).sort(), ["hydrateRecoveredArtistAuthority", "hydrateRecoveredArtistAuthorityWithConsents"]);
  for (const f of api.fragments) {
    const original = compiledInterfaces.registry.fragments.find(g => g.type === f.type && g.format("sighash") === f.format("sighash"));
    assert.ok(original, f.format("full")); compatibleFragment(f, original);
  }
  const get = literalReader(new URL("../src/current-artist-recovered-multiple-generation-hydration-workflow.ts", import.meta.url));
  const all = Object.values(compiledInterfaces).flatMap(iface => iface.fragments);
  for (const name of ["abi", "identityAbi", "consentAbi", "attestationAbi", "clockAbi", "generationAbi"]) for (const f of new Interface(get(name)).fragments) {
    assert.equal(f.type, "function"); assert.ok(["view", "pure"].includes(f.stateMutability));
    assert.ok(all.some(original => { if (original.type !== f.type || original.format("sighash") !== f.format("sighash")) return false; try { compatibleFragment(f, original); return true; } catch { return false; } }), name + f.format("full"));
  }
});

// These values are compiler-shaped codec inputs, not an admitted source graph.
function specimen(p, depth = 0) {
  if (p.baseType === "array") return Array.from({ length: p.arrayLength < 0 ? (depth < 4 ? 1 : 0) : p.arrayLength }, () => specimen(p.arrayChildren, depth + 1));
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(c => [c.name, specimen(c, depth + 1)]));
  if (p.type === "address") return getAddress(toBeHex(7n, 20));
  if (p.type === "bool") return true;
  if (p.type === "string") return "urn:source:Unicode-😀";
  if (p.type === "bytes") return "0x123456";
  if (/^bytes[0-9]+$/.test(p.type)) return toBeHex(9n, Number(p.type.slice(5)));
  if (/^uint/.test(p.type)) return p.type === "uint256" ? (1n << 220n) + 19n : p.type === "uint64" ? (1n << 50n) + 3n : 0n;
  throw Error(`Unsupported compiler specimen ${p.type}`);
}

test("raw generation codecs encode complete original compiler tuples without narrowing uint256 facts", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-generation-hydration.js"), coder = AbiCoder.defaultAbiCoder();
  for (const [suffix, type] of [["Inventory", "StreamArtistRecoveredMultipleGenerationTypes.Inventory"], ["Generation", "StreamArtistRecoveredAcceptedGenerationTypes.Generation"], ["BindingBundle", "StreamArtistRecoveredBindingCorrectionTypes.Bundle"], ["AcceptanceBundle", "StreamArtistRecoveredAcceptedGenerationTypes.AcceptanceBundle"], ["AttributionHistory", "StreamArtistRecoveredAcceptedGenerationTypes.AttributionBundle"], ["Consents", "StreamArtistRecoveredMultipleGenerationTypes.Consents"]]) {
    const tuple = generationTuple(type), value = specimen(tuple), raw = coder.encode([tuple], [value]);
    assert.equal(r[`encodeArtistRecoveredMultipleGenerationHydration${suffix}`](value), raw, suffix);
    assert.deepEqual(r[`decodeArtistRecoveredMultipleGenerationHydration${suffix}`](raw), value, suffix);
    assert.throws(() => r[`decodeArtistRecoveredMultipleGenerationHydration${suffix}`](raw + "00".repeat(32)), /canonical|length|trailing/i, suffix);
  }
});

test("original Binding and Correction commitments retain their distinct complete preimages", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-generation-hydration.js");
  const origin = specimen(generationTuple("StreamArtistRecoveredHydrationTypes.OriginEnvironment"));
  const bundle = generationTuple("StreamArtistRecoveredBindingCorrectionTypes.Bundle");
  const bindingType = bundle.components[0].components.find(p => p.name === "current");
  const approvalType = bundle.components[1].arrayChildren.components.find(p => p.name === "approval");
  const b = specimen(bindingType), a = specimen(approvalType), collectionId = (1n << 233n) + 19n, bindingHash = id("target-binding");
  const collaborators = hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []]);
  const policies = hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []]);
  const expectedBinding = hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_BINDING_V1"), origin.chainId, origin.registry, origin.core, collectionId, b.generation, b.artistId, b.artistAddress, b.identityRecordHash, b.consentMode, b.saleConsentScope, b.registryImmutabilityElection, collaborators, policies]);
  assert.equal(r.artistRecoveredMultipleGenerationHydrationBindingHash(origin, collectionId, b), expectedBinding);
  const omitted = { ...b, bindingHash: id("not-in-preimage"), accepted: !b.accepted, proposer: getAddress(toBeHex(99n, 20)) };
  assert.equal(r.artistRecoveredMultipleGenerationHydrationBindingHash(origin, collectionId, omitted), expectedBinding);
  const expectedCorrection = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", approvalType],
    [id("6529STREAM_ARTIST_BINDING_CORRECTION_RECORD_V1"), origin.chainId, origin.registry, origin.core, origin.manager, collectionId, bindingHash, a]);
  assert.equal(r.artistRecoveredMultipleGenerationHydrationCorrectionHash(origin, collectionId, bindingHash, a), expectedCorrection);
  assert.notEqual(r.artistRecoveredMultipleGenerationHydrationCorrectionHash(origin, collectionId, bindingHash, { ...a, governance: { ...a.governance, newValueHash: id("changed-transition") } }), expectedCorrection);
  assert.match(source("StreamArtistBindingCorrectionHashes.sol"), /e\.registry,\s*e\.core,\s*e\.manager,\s*id,\s*bindingHash,\s*a/);
});

test("original attestation native and EIP712 hashes bind the exact source Registry and URI bytes", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-generation-hydration.js");
  const o = specimen(generationTuple("StreamArtistRecoveredHydrationTypes.OriginEnvironment"));
  const bundle = generationTuple("StreamArtistRecoveredAttestationHydration.Bundle");
  const rowType = bundle.components.find(p => p.name === "records").arrayChildren.components.find(p => p.name === "attestation");
  const row = specimen(rowType), t = row.input.terms, artistId = id("full-artist");
  const record = hash(["bytes32", "uint256", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), o.chainId, o.registry, o.core, t.collectionId, t.subjectKind, t.subjectId, t.subjectStateHash, t.schemaId, t.statementHash, keccak256(Buffer.from(t.statementURI)), artistId, row.record.signer, row.authorityClass, row.input.nonce, row.record.signedAt]);
  assert.equal(r.artistRecoveredMultipleGenerationHydrationAttestationRecordHash(o, artistId, row), record);
  const domain = hash(["bytes32", "bytes32", "bytes32", "uint256", "address"], [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), o.chainId, o.registry]);
  const body = hash(["bytes32", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64"],
    [id("StreamArtistAttestation(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt)"), o.core, t.collectionId, t.subjectKind, t.subjectId, t.subjectStateHash, t.schemaId, t.statementHash, keccak256(Buffer.from(t.statementURI)), row.input.nonce, row.record.signedAt]);
  assert.equal(r.artistRecoveredMultipleGenerationHydrationAttestationDigest(o, row), keccak256(`0x1901${domain.slice(2)}${body.slice(2)}`));
  const sourceHash = source("StreamArtistHashes.sol");
  assert.match(sourceHash, /6529STREAM_ARTIST_ATTESTATION_RECORD_V1/);
  assert.ok(sourceHash.includes("StreamArtistAttestation(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt)"));
  assert.ok(t.collectionId > 1n << 200n);
});

test("Archive envelope and correction/refusal payloads are original flat fields rather than outer tuples", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-generation-hydration.js"), coder = AbiCoder.defaultAbiCoder();
  for (const [suffix, type] of [["ArchiveEnvelope", "StreamArtistRecoveredSanctionHistoryTypes.Envelope"], ["CorrectionPayload", "StreamArtistRecoveredPlatformPayload.Correction"], ["RefusalPayload", "StreamArtistRecoveredPlatformPayload.Refusal"]]) {
    const tuple = generationTuple(type), value = specimen(tuple);
    const expected = coder.encode(tuple.components, tuple.components.map(p => value[p.name]));
    assert.equal(r[`encodeArtistRecoveredMultipleGenerationHydration${suffix}`](value), expected, suffix);
    assert.deepEqual(r[`decodeArtistRecoveredMultipleGenerationHydration${suffix}`](expected), value, suffix);
    assert.notEqual(expected, coder.encode([tuple], [value]), suffix);
    assert.throws(() => r[`decodeArtistRecoveredMultipleGenerationHydration${suffix}`](coder.encode([tuple], [value])), undefined, suffix);
  }
  const history = generationTuple("StreamArtistRecoveredAcceptedGenerationTypes.AttributionBundle"), records = generationTuple("StreamArtistRecoveredAttestationHydration.Bundle");
  const wrapper = ParamType.from({ type: "tuple", components: [{ ...JSON.parse(history.format("json")), name: "history" }, { ...JSON.parse(records.format("json")), name: "records" }] });
  const value = { history: specimen(history), records: specimen(records) }, raw = coder.encode([wrapper], [value]);
  assert.equal(r.encodeArtistRecoveredMultipleGenerationHydrationAttribution(value), raw);
  assert.deepEqual(r.decodeArtistRecoveredMultipleGenerationHydrationAttribution(raw), value);
  assert.match(source("StreamArtistRecoveredMultipleGenerationTypes.sol"), /A\.AttributionBundle history;\s*Records\.Bundle records;/);
});

test("public input and call wrappers reject caller accessors without invoking them", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-generation-hydration.js");
  // Deliberately malformed scaffolds isolate wrapper ownership before protocol admission.
  // The prior implementation reached these getters immediately after checking field names.
  let requestReads = 0;
  const input = { royaltyFreezes: [] };
  Object.defineProperty(input, "request", { enumerable: true, get() {
    requestReads++;
    throw Error("Caller request accessor executed");
  } });
  assert.throws(() => r.normalizeArtistRecoveredMultipleGenerationHydrationInputDraft(input));
  assert.equal(requestReads, 0, "InputDraft must inspect the request descriptor without executing its getter");

  let callReads = 0;
  const call = {
    registry: getAddress(toBeHex(7n, 20)), caller: getAddress(toBeHex(8n, 20)),
    request: {}, royaltyFreezes: [], profile: ZeroHash, capabilityId: "0x00000000", factsVerified: false,
  };
  Object.defineProperty(call, "call", { enumerable: true, get() {
    callReads++;
    throw Error("Caller call accessor executed");
  } });
  assert.throws(() => r.normalizeArtistRecoveredMultipleGenerationHydrationCall(call));
  assert.equal(callReads, 0, "Call normalization must inspect the call descriptor without executing its getter");
});

test("compiler-encoded supplied multi-generation inventory and op60 commitment retain every original field", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-generation-hydration.js");
  const { semanticFixture } = await import("./current-artist-recovered-multiple-generation-hydration-semantic-fixture.mjs");
  // Source-shaped documentary input, with private Identity/Payout admission,
  // runtime provenance, signatures and Registry execution still mocked.
  const f = semanticFixture({ acceptedHistory: true, attestations: true });
  const p = f.prepared, q = f.request;
  assert.equal(p.admission.collections.length, 3);
  assert.ok(f.bindings.every(b => b.bindings.rows.length === 2));
  assert.deepEqual(new Set(p.admission.provenance.journals[6].map(j => j.receipt.operation)), new Set([14n, 15n, 16n, 17n, 20n, 21n]));
  assert.ok(p.admission.provenance.journals[4].some(j => j.receipt.operation === 24n));
  assert.ok(p.admission.provenance.journals[4].some(j => j.receipt.operation === 44n));
  assert.ok(f.identities.some(identity => identity.delegations.some(d => d.record.uses > 0n)));

  const original = compiledLibraryValueInterface("StreamArtistRecoveredHydrationCommitEncoding").getFunction("prepare");
  const fields = original.inputs[6].components;
  const member = name => {
    const result = fields.find(field => field.name === name);
    assert.ok(result, `original CommitEncoding.Inputs.${name}`);
    return result;
  };
  const provenanceHash = hash(["bytes32", "uint16", generationTuple("StreamArtistRecoveredHydrationTypes.Provenance")],
    [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_PROVENANCE_V1"), 1n, p.admission.provenance]);
  const inventory = hash(["bytes32", "uint16", "bytes32", member("query"), member("data"), member("timing"), member("externalGuards")],
    [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, provenanceHash, p.query, p.data, p.timing, p.externalGuards]);
  assert.equal(q.expectedSemanticInventory, inventory, "constructor's retained expectation must match the independent original preimage");
  assert.equal(r.artistRecoveredMultipleGenerationHydrationSemanticInventory(p), inventory);

  // RH.PROFILE remains the original recovered-authority profile. The new
  // generation tag lives inside the complete owner payloads, not in this word.
  const profile = id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1");
  const types = ["bytes32", "uint16", ...original.inputs.slice(0, 3), member("prior"), member("sourceCoordinator"), original.inputs[5],
    member("artists"), member("collections"), member("query"), member("data"), member("timing"), member("externalGuards"), member("before_")];
  const values = [profile, 1n, f.coords.chainId, f.coords.registry, f.coords.coordinator, p.admission.prior, p.admission.sourceCoordinator, q,
    p.admission.artists, p.admission.collections, p.query, p.data, p.timing, p.externalGuards, p.admission.before_];
  const commitment = hash(types, values);
  assert.equal(r.artistRecoveredMultipleGenerationHydrationCommitment(f.coords, q, p), commitment);
  assert.notEqual(commitment, hash(types, [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_GENERATIONS_V1"), ...values.slice(1)]));
  assert.match(source("StreamArtistRecoveredPreparationInventory.sol"), /RH\.VERSION,\s*provenance,\s*p\.query,\s*p\.data,\s*p\.timing,\s*p\.externalGuards/);
  assert.match(source("StreamArtistRecoveredHydrationCommitEncoding.sol"), /RH\.PROFILE,\s*RH\.VERSION,\s*chainId,\s*registry,\s*coordinator,\s*prepared\.prior,\s*prepared\.sourceCoordinator,\s*request,\s*prepared\.artists,\s*prepared\.collections,\s*prepared\.query,\s*prepared\.data,\s*prepared\.timing,\s*prepared\.externalGuards,\s*prepared\.before_/);
});
