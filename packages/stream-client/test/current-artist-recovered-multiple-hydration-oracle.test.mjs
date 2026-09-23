import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toBeHex } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledABI, compiledInterfaces, compiledLibraryEvents, libraryValueABI, compiledLibraryValueInterface } from "./current-artist-recovered-multiple-hydration-source-fixture.mjs";

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
const pureUrl = new URL("../src/current-artist-recovered-multiple-hydration.ts", import.meta.url);
const readPure = literalReader(pureUrl);
const source = basename => {
  const matches = Object.entries(fixture.sourceTexts).filter(([path]) => path.endsWith(`/${basename}`));
  assert.equal(matches.length, 1, basename);
  return matches[0][1];
};
const shape = type => type.baseType === "array"
  ? { length: type.arrayLength, child: shape(type.arrayChildren) }
  : type.baseType === "tuple" ? type.components.map(p => ({ name: p.name, type: shape(p) })) : type.type;

test("MULTIPLE_BASE capture is exact ABI167 with a separately identified producer and unchanged singleton ABI", () => {
  assert.equal(fixture.sourceCommit, "99e9503020ea713b558835ac6fe1a034e36994a2");
  assert.equal(readPure("ARTIST_RECOVERED_MULTIPLE_HYDRATION_SOURCE"), fixture.sourceCommit);
  assert.equal(fixture.sourceTree, "21c4a573e18deea66f8030fcea5def18b792af66");
  assert.equal(fixture.compilerVersion, "0.8.19");
  assert.equal(fixture.sourceCount, 4138);
  assert.equal(fixture.literalBytes, 48869757);
  assert.equal(fixture.inputSha256, "6826e1482fdeace25c09fb7b2f5f329c61ec53b3eef5401d70f9553feed15d85");
  assert.equal(fixture.outputSha256, "969365148c64364db453c12df6a52d188c7ab936fa6f33691247b83b523edd13");
  const { sha256, ...bridge } = fixture.committedSourceBridge;
  assert.equal(sha256, "a905a9dcce552f96a37643ff3d2ac5823f4e89b108d62599c17544b483b4eb67");
  assert.equal(sha(JSON.stringify(bridge, null, 2) + "\n"), sha256);
  assert.equal(bridge.commit, fixture.sourceCommit);
  assert.equal(Object.keys(bridge.committedBlobSHA256).length, 4138);
  assert.deepEqual(bridge.mismatches, []);
  const p = fixture.producerEvidence;
  assert.equal(p.sourceCommit, "28ef1f012b414f8a215a96708066ce13549e4dd0");
  assert.equal(p.sourceTree, "3cec4932b93f1882df230136b6ddcf96117d453d");
  assert.equal(p.handoffSha256, "8800d8bb3b27112e067c8d14cabbfb337301b53199a73e53f1a9441cec704e84");
  assert.equal(p.sourceBridgeSha256, "cd82cfacf9f2b60e86a2d0627f1ac3bf94fdfd89e08e58a643e9549abc6da858");
  assert.equal(sha(p.handoffText), p.handoffSha256);
  assert.equal(sha(p.sourceBridgeText), p.sourceBridgeSha256);
  assert.deepEqual(JSON.parse(p.handoffText), p.handoff);
  assert.deepEqual(JSON.parse(p.sourceBridgeText), p.sourceBridge);
  assert.equal(p.sourceBridge.files.length, 34);
  for (const row of p.sourceBridge.files) {
    const retained = fixture.sourceTexts[row.path] ?? fixture.documents[row.path]?.text;
    if (retained !== undefined) assert.equal(sha(retained), row.rawSHA256, row.path);
    else assert.match(row.path, /^(test\/|docs\/|CHANGELOG\.md$)/, "Only producer test/docs outside selected closure");
  }
  const oldBytes = readFileSync(new URL("./fixtures/current-artist-recovered-consent-hydration-abi.json", import.meta.url));
  assert.equal(sha(oldBytes), fixture.singletonAbiEvidence.fixtureSha256);
  const old = JSON.parse(oldBytes);
  for (const [name, methods] of Object.entries(fixture.singletonAbiEvidence.methods)) {
    const oldKey = Object.keys(old.selections).find(key => old.selections[key].contract === name);
    assert.ok(oldKey, name);
    assert.deepEqual(methods, old.abis[oldKey].filter(row => row.type === "function"));
    assert.deepEqual(methods, compiledABI(name).filter(row => row.type === "function"));
  }
});

test("MULTIPLE_BASE witness retains its entire import closure and exact normative document bytes", () => {
  const all = { ...fixture.selections, ...fixture.librarySelections }, seen = new Set();
  function visit(path) {
    if (seen.has(path)) return;
    seen.add(path);
    const text = fixture.sourceTexts[path]; assert.equal(typeof text, "string", path);
    assert.equal(sha(text), fixture.sourceHashes[path], path);
    assert.equal(sha(text), fixture.committedSourceBridge.committedBlobSHA256[path], path);
    for (const imported of solidityImports(text)) visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
  }
  fixture.roots.forEach(name => visit(all[name].source));
  assert.deepEqual([...seen].sort(), Object.keys(fixture.sourceTexts).sort());
  assert.equal(seen.size, 1012);
  assert.equal([...seen].reduce((n, path) => n + Buffer.byteLength(fixture.sourceTexts[path]), 0), 6464346);
  for (const [name, row] of Object.entries(all)) {
    assert.equal(row.full, true, name); assert.ok(seen.has(row.source), name);
    const text = fixture.sourceTexts[row.source].replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
    const declaration = text.match(new RegExp(`\\b(contract|interface|library)\\s+${name}\\b`));
    assert.ok(declaration, name);
    assert.equal(declaration[1] === "library", Object.hasOwn(fixture.libraryAbis, name), name);
  }
  for (const [path, doc] of Object.entries(fixture.documents)) {
    assert.equal(sha(doc.text), doc.sha256, path); assert.equal(Buffer.byteLength(doc.text), doc.byteLength, path);
  }
  assert.ok(fixture.documents["docs/adr/0047-complete-artist-authority-hydration.md"]);
  assert.ok(fixture.documents["docs/integrations/artist-recovered-multiple-base.md"]);
});

test("ordinary compiler selectors and nominal library selectors remain distinct and complete", () => {
  assert.equal(Object.keys(fixture.abis).length, 417);
  assert.equal(Object.keys(fixture.libraryAbis).length, 745);
  for (const [name, rows] of Object.entries(fixture.abis)) {
    const iface = compiledInterfaces[name];
    const functions = iface.fragments.filter(f => f.type === "function");
    assert.equal(functions.length, Object.keys(fixture.methodIdentifiers[name]).length, name);
    for (const f of functions) assert.equal(f.selector.slice(2), fixture.methodIdentifiers[name][f.format("sighash")], name);
    assert.deepEqual(compiledABI(name), rows);
  }
  for (const [name, identifiers] of Object.entries(fixture.libraryMethodIdentifiers)) {
    for (const [signature, selector] of Object.entries(identifiers)) assert.equal(id(signature).slice(2, 10), selector, name + signature);
  }
  assert.throws(() => compiledABI("prepared"), /ordinary/);
  const ids = fixture.libraryMethodIdentifiers.StreamArtistRecoveredHydrationPrepared;
  assert.deepEqual(Object.values(ids).sort(), ["35c07ee8", "86909776", "69f71db4", "72c84763", "4925300f", "0681a748"].sort());
  const expanded = compiledLibraryValueInterface("prepared").fragments.find(f => f.type === "function" && f.name === "prepare" && f.inputs.length === 2);
  assert.notEqual(expanded.selector, "0x72c84763");
  assert.equal(fixture.libraryMethodIdentifiers.StreamArtistRecoveredMultipleCodec["anchorQuery(StreamArtistRecoveredMultipleTypes.State)"], "63c3fb14");
});

test("all exported MULTIPLE_BASE tuple fields and widths match complete original compiler witnesses", () => {
  const witnesses = new Set();
  function valueField(field) {
    if (field.internalType?.startsWith("enum ") && field.type !== "uint8") {
      const evidence = fixture.libraryValueTypeEvidence[field.internalType];
      assert.ok(evidence && evidence.nominalType === field.type && evidence.abiType === "uint8", "Only independently witnessed enum values");
      let original = fixture.abis[evidence.witness.contract][evidence.witness.abiIndex][evidence.witness.direction];
      for (const key of evidence.witness.parameterPath) original = original[key];
      assert.equal(original.internalType, field.internalType); assert.equal(original.type, "uint8");
      field = { ...field, type: "uint8" };
    }
    return { ...field, ...(field.components ? { components: field.components.map(valueField) } : {}) };
  }
  function visit(field) {
    if (field.type === undefined) return;
    try {
      let p = ParamType.from(valueField(field)); witnesses.add(JSON.stringify(shape(p)));
      while (p.baseType === "array") { p = p.arrayChildren; witnesses.add(JSON.stringify(shape(p))); }
    } catch { /* Unwitnessed nominal or storage fields are not value witnesses. Their nested proved fields are considered separately. */ }
    for (const child of field.components ?? []) visit(child);
  }
  for (const rows of [...Object.values(fixture.abis), ...Object.values(fixture.libraryAbis)]) {
    for (const row of rows) for (const field of [...row.inputs ?? [], ...row.outputs ?? []]) visit(field);
  }
  const tree = ts.createSourceFile(pureUrl.pathname, readFileSync(pureUrl, "utf8"), ts.ScriptTarget.Latest, true);
  const names = new Set();
  for (const statement of tree.statements) {
    if (ts.isVariableStatement(statement) && statement.modifiers?.some(m => m.kind === ts.SyntaxKind.ExportKeyword)) {
      for (const d of statement.declarationList.declarations) if (ts.isIdentifier(d.name) && d.name.text.endsWith("_TUPLE")) names.add(d.name.text);
    }
    if (ts.isExportDeclaration(statement) && statement.exportClause && ts.isNamedExports(statement.exportClause)) {
      for (const d of statement.exportClause.elements) if (d.name.text.endsWith("_TUPLE")) names.add(d.name.text);
    }
  }
  for (const name of names) {
    const p = ParamType.from(readPure(name));
    if (name.endsWith("_ENVELOPE_TUPLE")) {
      assert.match(source("StreamArtistRecoveredHydrationTypes.sol"), /struct Envelope\s*\{\s*ExportHeader header;\s*bytes payload;/);
      assert.deepEqual(p.components.map(x => x.name), ["header", "payload"]);
    } else if (name === "ARTIST_RECOVERED_MULTIPLE_HYDRATION_ATTRIBUTION_TUPLE") {
      assert.match(source("StreamArtistRecoveredMultipleCollectionRows.sol"), /struct AttributionRow\s*\{\s*Original.AttributionBundle state;\s*bytes32 proposalOrigin;/);
      assert.deepEqual(shape(p), [
        { name: "state", type: shape(ParamType.from(readPure("ARTIST_RECOVERED_MULTIPLE_HYDRATION_ATTRIBUTION_STATE_TUPLE"))) },
        { name: "proposalOrigin", type: "bytes32" },
      ]);
    } else assert.ok(witnesses.has(JSON.stringify(shape(p))), name);
  }
  assert.ok(names.size >= 40);
  assert.deepEqual(shape(ParamType.from(readPure("ARTIST_RECOVERED_MULTIPLE_HYDRATION_STATE_TUPLE"))),
    shape(compiledLibraryValueInterface("multiple").getFunction("encode").inputs[1]));
});

test("original aggregate schema, actual feature ceiling and seven-owner transport stay source pinned", () => {
  assert.match(source("StreamArtistRecoveredMultipleTypes.sol"), /SCHEMA\s*=\s*keccak256\("6529STREAM_ARTIST_RECOVERED_MULTIPLE_BASE_V1"\)/);
  assert.match(source("StreamArtistRecoveredMultipleTypes.sol"), /uint16 internal constant VERSION = 1/);
  assert.equal(readPure("ARTIST_RECOVERED_MULTIPLE_HYDRATION_BASE"), 262144n);
  assert.equal(readPure("ARTIST_RECOVERED_MULTIPLE_HYDRATION_ALLOWED_FEATURES"), 262175n);
  assert.equal(readPure("ARTIST_RECOVERED_MULTIPLE_HYDRATION_KNOWN_FEATURES"), 524287n);
  assert.match(source("StreamArtistRecoveredMultipleCodec.sol"), /h.requiredFeatures & ~\(RH.FIRST_GRAPH_FEATURES \| RH.MULTIPLE_BASE\)/);
  assert.match(source("StreamArtistRecoveredMultipleCodec.sol"), /for \(uint256 i; i < p.journal.length; \+\+i\)/);
  assert.match(source("StreamArtistRecoveredMultipleOwners.sol"), /for \(uint8 i; i < 7; \+\+i\)/);
  assert.match(source("StreamArtistRecoveredMultiplePreparation.sol"), /uint256 features = RH.MULTIPLE_BASE/);
  assert.equal(compiledInterfaces.registry.getFunction("hydrateRecoveredArtistAuthority").selector, compiledInterfaces.recovered.getFunction("hydrateRecoveredArtistAuthority").selector);
  assert.equal(compiledInterfaces.registry.getFunction("hydrateRecoveredArtistAuthorityWithConsents").selector, "0x1e2d2f62");
  const old = literalReader(new URL("../src/current-artist-recovered-hydration.ts", import.meta.url));
  const consent = readFileSync(new URL("../src/current-artist-recovered-consent-hydration.ts", import.meta.url), "utf8");
  assert.equal(old("ARTIST_RECOVERED_HYDRATION_SOURCE"), "d56e13ffc8664b322a3a208f21d308918ed47072");
  assert.match(consent, /createArtistRecoveredHydrationCodec\(511n\)/);
  assert.match(readFileSync(new URL("../src/current-artist-recovered-hydration.ts", import.meta.url), "utf8"), /createArtistRecoveredHydrationCodec\(255n\)/);
});

test("shared and aggregate workflow observation ABIs match ordinary reads and original Commit event witnesses", () => {
  const witnesses = Object.values(compiledInterfaces).flatMap(iface => iface.fragments)
    .concat(compiledLibraryEvents("commit").fragments);
  for (const path of ["../src/internal/artist-recovered-hydration-workflow.ts", "../src/current-artist-recovered-multiple-hydration-workflow.ts"]) {
    const abi = new Interface(literalReader(new URL(path, import.meta.url))("abi"));
    for (const fragment of abi.fragments) {
      const matches = witnesses.filter(f => f.type === fragment.type && f.format("sighash") === fragment.format("sighash"));
      assert.ok(matches.length, fragment.format("full"));
      assert.ok(matches.some(original => {
        try { compatibleFragment(fragment, original); return true; } catch { return false; }
      }), fragment.format("full"));
    }
  }
  const admission = source("StreamArtistRecoveredHydrationAdmission.sol");
  assert.match(admission, /uint256 laneCount = selectors.artistIds.length \+ selectors.collections.length/);
  assert.match(admission, /i == 2 \? 1 \+ laneCount : 0/);
  assert.match(admission, /i == 2 \? 2 \+ 2 \* laneCount : 0/);
});

const coder = AbiCoder.defaultAbiCoder(), H = n => toBeHex(n, 32), A = n => getAddress(toBeHex(n, 20));
const hash = (types, values) => keccak256(coder.encode(types, values));
function compilerTuple(internalType) {
  function find(value) {
    if (!value || typeof value !== "object") return;
    if (value.internalType === internalType) return value;
    for (const child of Object.values(value)) {
      const result = Array.isArray(child) ? child.map(find).find(Boolean) : find(child);
      if (result) return result;
    }
  }
  for (const name of Object.keys(fixture.libraryAbis)) {
    if (!JSON.stringify(fixture.libraryAbis[name]).includes(`"${internalType}"`)) continue;
    const found = find(libraryValueABI(name));
    if (found) return ParamType.from(found);
  }
  throw Error(`Missing original compiler type ${internalType}`);
}
function zero(p) {
  if (p.baseType === "array") return Array.from({ length: Math.max(0, p.arrayLength) }, () => zero(p.arrayChildren));
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(c => [c.name, zero(c)]));
  if (p.type === "address") return ZeroAddress;
  if (p.type === "bool") return false;
  if (p.type === "string") return "";
  if (p.type === "bytes") return "0x";
  if (p.type.startsWith("bytes")) return toBeHex(0, Number(p.type.slice(5)));
  return 0n;
}
function suppliedOrigin() {
  return { chainId: (1n << 200n) + 7n, registry: A(1), coordinator: A(2), archive: A(3),
    owners: Array.from({ length: 7 }, (_, i) => A(10 + i)), ownerCodeHashes: Array.from({ length: 7 }, (_, i) => H(10 + i)),
    core: A(4), manager: A(5), suiteConfigurationHash: H(200) };
}

test("runtime original State envelope, copied anchor and minimal/mixed feature headers use independent compiler preimages", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-hydration.js");
  const sType = compiledLibraryValueInterface("multiple").getFunction("encode").inputs[1];
  const ownerType = compiledLibraryValueInterface("multiple").getFunction("encode").inputs[2];
  const originType = ownerType.components.find(p => p.name === "origins").arrayChildren;
  const origin = suppliedOrigin(), originHash = hash(["bytes32", "uint16", originType], [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_ORIGIN_V1"), 1n, origin]);
  assert.equal(r.artistRecoveredMultipleHydrationOriginHash(origin), originHash);
  const provenance = { origins: [origin], eras: [{ originHash, checkpoint: { schema: id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"),
    ownerState: { domainId: id("domain:collaborator_lifecycle"), revision: 0n, stateRoot: H(31), recordChainTip: H(32) },
    replayRoot: ZeroHash, replayCount: 0n, nonceRoot: ZeroHash, nonceIndexCount: 0n }, nativeCount: 0n, lowerRevision: 0n, priorImportCommitment: ZeroHash }], journal: [], aliases: [] };
  const s = { artists: [{ artistId: H(1000), collectionId: 0n, bindingHash: ZeroHash, policies: [], records: [H(1), H(2), H(1)] }],
    collections: [1n, 2n].map(n => ({ artistId: H(1000), collectionId: (1n << 240n) + n, bindingHash: H(100n + n), policies: [], records: [H(100n + n)] })), rows: [] };
  const original = structuredClone(s), anchor = r.artistRecoveredMultipleHydrationAnchor(s);
  assert.deepEqual(anchor, { ...s.collections[0], records: s.artists[0].records });
  assert.deepEqual(s, original); assert.notEqual(anchor, s.collections[0]);
  const raw = coder.encode(["bytes32", "uint16", "uint8", sType], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_BASE_V1"), 1n, 1n, s]);
  assert.equal(r.encodeArtistRecoveredMultipleHydrationState(s, 1, provenance), raw);
  assert.deepEqual(r.decodeArtistRecoveredMultipleHydrationState(raw, 1, provenance), s);
  assert.throws(() => r.decodeArtistRecoveredMultipleHydrationState(raw + "00".repeat(32), 1, provenance));
  assert.throws(() => r.decodeArtistRecoveredMultipleHydrationState(raw, 0, provenance));
  assert.equal(r.artistRecoveredMultipleHydrationOwnerProvenanceHash(provenance, 1), hash(["bytes32", "uint16", "bytes32", ownerType],
    [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_V1"), 1n, id("domain:collaborator_lifecycle"), provenance]));
  for (const features of [262144n, 262145n, 262147n, 262175n]) {
    const payload = { provenance, nonces: [], semanticState: raw, publications: [] };
    const bytes = r.encodeArtistRecoveredMultipleHydrationOwnerPayload(payload, 1, features);
    assert.equal(r.decodeArtistRecoveredMultipleHydrationOwnerPayload(bytes, 1).header.requiredFeatures, features);
  }
});

test("runtime full Identity/Payout compiler codecs and data-derived feature union preserve original widths", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-hydration.js");
  const it = compilerTuple("struct StreamArtistRecoveredIdentityHydrationTypes.Bundle");
  const pt = compilerTuple("struct StreamArtistRecoveredPayoutTypes.Bundle");
  const identity = zero(it), payout = zero(pt);
  identity.artistId = payout.artistId = H(500); identity.identity.authorityClass = 1n;
  identity.nextRegistrationNonce = (1n << 250n) + 3n;
  identity.identity.nonceHint = (1n << 200n) + 19n;
  identity.identity.displayName = "Original λ"; identity.identityDocument = "0x010203";
  assert.equal(r.encodeArtistRecoveredMultipleHydrationIdentity(identity), coder.encode([it], [identity]));
  assert.deepEqual(r.decodeArtistRecoveredMultipleHydrationIdentity(coder.encode([it], [identity])), identity);
  const payoutBytes = coder.encode(["bytes32", pt], [id("6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1"), payout]);
  assert.equal(r.encodeArtistRecoveredMultipleHydrationPayout(payout), payoutBytes);
  assert.deepEqual(r.decodeArtistRecoveredMultipleHydrationPayout(payoutBytes), payout);
  assert.equal(r.artistRecoveredMultipleHydrationRequiredFeatures([identity], [payout], 1n), 262145n);
  const other = structuredClone(identity), pay2 = structuredClone(payout);
  other.artistId = pay2.artistId = H(501); other.identity.authorityClass = 3n;
  assert.equal(r.artistRecoveredMultipleHydrationRequiredFeatures([identity, other], [payout, pay2], 2n), 262163n);
  other.identity.authorityClass = 4n;
  assert.throws(() => r.artistRecoveredMultipleHydrationRequiredFeatures([other], [pay2], 1n));
});

test("runtime original binding hash and unchanged nominal preparation/Registry calldata bind high-width aggregate requests", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-hydration.js");
  const bindingType = compilerTuple("struct StreamArtistRecoveredSimpleHydrationTypes.Binding");
  const itemType = bindingType.components.find(p => p.name === "item"), item = zero(itemType), origin = suppliedOrigin();
  Object.assign(item, { artistId: H(701), artistAddress: A(702), identityRecordHash: H(703), generation: (1n << 63n) + 1n, consentMode: 1n });
  const collectionId = (1n << 230n) + 9n;
  assert.equal(r.artistRecoveredMultipleHydrationBindingHash(origin, collectionId, item), hash(
    ["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_BINDING_V1"), origin.chainId, origin.registry, origin.core, collectionId, item.generation, item.artistId, item.artistAddress, item.identityRecordHash,
      item.consentMode, item.saleConsentScope, item.registryImmutabilityElection,
      hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []]), hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []])]));
  const prepare = compiledLibraryValueInterface("prepared").fragments.find(f => f.type === "function" && f.name === "prepare" && f.inputs.length === 2);
  const suite = { registry: A(1), archive: A(2), owners: Array.from({ length: 7 }, (_, i) => A(10 + i)), core: A(3), mintManager: A(4), roleRegistry: A(5), metadata: A(6), primaryResolver: A(7), royaltyResolver: A(8), primaryRevenueClass: H(9), validator: A(9) };
  const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"];
  const tags = ["BINDING", "COLLABORATOR", "IDENTITY", "ACCEPTANCE", "ATTRIBUTION", "PAYOUT", "CONSENT"];
  const request = zero(prepare.inputs[1]);
  request.records.authority.artistIds = [H(1000)];
  request.records.authority.collections = [1n, 2n].map(n => ({ artistId: H(1000), collectionId: collectionId + n, policies: [] }));
  request.records.authority.expectedSource = domains.map((d, i) => ({ schema: id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"), ownerState: { domainId: id(`domain:${d}`), revision: 1n, stateRoot: H(90 + i), recordChainTip: H(100 + i) }, replayRoot: ZeroHash, replayCount: 0n, nonceRoot: ZeroHash, nonceIndexCount: 0n }));
  request.expectedCapabilities = domains.map((d, i) => ({ profile: id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1"), version: 1n, ownerIndex: BigInt(i), ownerDomain: id(`domain:${d}`), checkpointSchema: id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"), stateSchema: id(`6529STREAM_ARTIST_RECOVERED_${tags[i]}_STATE_V1`), supportedFeatures: 524287n }));
  assert.equal(r.artistRecoveredMultipleHydrationPreparationCalldata(suite, request), "0x72c84763" + coder.encode(prepare.inputs, [suite, request]).slice(2));
  request.expectedSemanticInventory = H(990);
  const plan = r.prepareArtistRecoveredMultipleHydrationCall(A(1), A(100), request);
  assert.equal(plan.call.data, compiledInterfaces.registry.encodeFunctionData("hydrateRecoveredArtistAuthority", [request]));
  assert.equal(plan.call.value, 0n); assert.equal(plan.factsVerified, false);
  assert.throws(() => r.normalizeArtistRecoveredMultipleHydrationCall({ ...plan, call: { ...plan.call, data: plan.call.data + "00" } }));
  const old = await import("../dist/current-artist-recovered-hydration.js");
  const consent = await import("../dist/current-artist-recovered-consent-hydration.js");
  assert.throws(() => old.normalizeArtistRecoveredHydrationRequest(request));
  assert.throws(() => consent.normalizeArtistRecoveredConsentHydrationInput({ request, royaltyFreezes: [] }));
});
