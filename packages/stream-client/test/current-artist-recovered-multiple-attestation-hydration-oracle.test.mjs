import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toBeHex } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledABI, compiledInterfaces, compiledLibraryEvents, libraryValueABI, compiledLibraryValueInterface } from "./current-artist-recovered-multiple-attestation-hydration-source-fixture.mjs";

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
const pureUrl = new URL("../src/current-artist-recovered-multiple-attestation-hydration.ts", import.meta.url);
const readPure = literalReader(pureUrl);
const source = name => {
  const found = Object.entries(fixture.sourceTexts).filter(([path]) => path.endsWith(`/${name}`));
  assert.equal(found.length, 1, name); return found[0][1];
};
const shape = p => p.baseType === "array" ? { length: p.arrayLength, child: shape(p.arrayChildren) }
  : p.baseType === "tuple" ? p.components.map(p => ({ name: p.name, type: shape(p) })) : p.type;

test("MULTIPLE_ATTESTATIONS is exactly bd4 ABI12 raw source and preserves the prior compiler witness", () => {
  assert.equal(fixture.sourceCommit, "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b");
  assert.equal(fixture.producerReportedCommit, fixture.sourceCommit);
  assert.equal(fixture.sourceTree, "466dac5d504c33a8a0bf4275997c33c851d65dd0");
  assert.equal(fixture.compilerVersion, "0.8.19"); assert.equal(fixture.sourceCount, 1430); assert.equal(fixture.literalBytes, 9829482);
  assert.equal(fixture.inputSha256, "18377a1e0ce422eec0c665c4f710789ec605ec97a5cc270e2147570ed5ad6ebe");
  assert.equal(fixture.outputSha256, "ce3e062cbf679958e07d0f8ca79ff393b17dd9ab23045c1b13a6659f512f9dc3");
  assert.equal(fixture.committedSourceBridge.commit, fixture.sourceCommit);
  assert.equal(Object.keys(fixture.committedSourceBridge.committedBlobSHA256).length, 1430);
  const producer = fixture.producerEvidence;
  assert.equal(sha(producer.handoffText), producer.handoffSha256);
  assert.deepEqual(JSON.parse(producer.handoffText), producer.handoff);
  assert.equal(producer.handoff.sourceInputSHA256, fixture.inputSha256); assert.equal(producer.handoff.sourceOutputSHA256, fixture.outputSha256);
  const oldRaw = readFileSync(new URL("./fixtures/current-artist-recovered-consent-hydration-abi.json", import.meta.url));
  assert.equal(sha(oldRaw), fixture.singletonAbiEvidence.fixtureSha256);
  const old = JSON.parse(oldRaw);
  for (const [name, methods] of Object.entries(fixture.singletonAbiEvidence.methods)) {
    const oldKey = Object.keys(old.selections).find(key => old.selections[key].contract === name);
    assert.ok(oldKey, name); assert.deepEqual(methods, old.abis[oldKey].filter(r => r.type === "function"));
    assert.deepEqual(methods, compiledABI(name).filter(r => r.type === "function"));
  }
});

test("complete selected source closure and nine normative documents retain exact byte hashes", () => {
  const selections = { ...fixture.selections, ...fixture.librarySelections }, seen = new Set();
  const visit = path => {
    if (seen.has(path)) return; seen.add(path);
    const text = fixture.sourceTexts[path]; assert.equal(typeof text, "string", path);
    assert.equal(sha(text), fixture.sourceHashes[path], path);
    assert.equal(sha(text), fixture.committedSourceBridge.committedBlobSHA256[path], path);
    for (const dependency of solidityImports(text)) visit(dependency.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), dependency)) : dependency);
  };
  fixture.roots.forEach(name => visit(selections[name].source));
  assert.deepEqual([...seen].sort(), Object.keys(fixture.sourceTexts).sort()); assert.equal(seen.size, 1033);
  assert.equal([...seen].reduce((n, path) => n + Buffer.byteLength(fixture.sourceTexts[path]), 0), 6622075);
  for (const [name, row] of Object.entries(selections)) {
    assert.equal(row.full, true, name); assert.ok(seen.has(row.source), name);
    const text = fixture.sourceTexts[row.source].replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
    const declaration = text.match(new RegExp(`\\b(contract|interface|library)\\s+${name}\\b`));
    assert.ok(declaration, name); assert.equal(declaration[1] === "library", Object.hasOwn(fixture.libraryAbis, name), name);
  }
  assert.equal(Object.keys(fixture.documents).length, 9);
  for (const [path, d] of Object.entries(fixture.documents)) { assert.equal(sha(d.text), d.sha256, path); assert.equal(Buffer.byteLength(d.text), d.byteLength, path); }
  assert.ok(fixture.documents["docs/integrations/artist-recovered-multiple-attestations.md"]);
});

test("all ordinary and nominal method IDs remain exact without nominal wallet selector substitution", () => {
  assert.equal(Object.keys(fixture.abis).length, 395); assert.equal(Object.keys(fixture.libraryAbis).length, 787);
  for (const [name, abi] of Object.entries(fixture.abis)) {
    assert.deepEqual(compiledABI(name), abi);
    const functions = compiledInterfaces[name].fragments.filter(f => f.type === "function");
    assert.equal(functions.length, Object.keys(fixture.methodIdentifiers[name]).length, name);
    for (const f of functions) assert.equal(f.selector.slice(2), fixture.methodIdentifiers[name][f.format("sighash")], name);
  }
  for (const [name, ids] of Object.entries(fixture.libraryMethodIdentifiers)) for (const [signature, selector] of Object.entries(ids)) assert.equal(id(signature).slice(2, 10), selector, name + signature);
  assert.throws(() => compiledABI("multipleAttestationCodec"), /ordinary/);
  const prepared = fixture.libraryMethodIdentifiers.StreamArtistRecoveredHydrationPrepared;
  assert.deepEqual(Object.values(prepared).sort(), ["35c07ee8", "86909776", "69f71db4", "72c84763", "4925300f", "0681a748"].sort());
  for (const [arity, selector] of [[2, "0x72c84763"], [3, "0x4925300f"]]) {
    const expanded = compiledLibraryValueInterface("prepared").fragments.find(f => f.type === "function" && f.name === "prepare" && f.inputs.length === arity);
    assert.notEqual(expanded.selector, selector);
  }
});

test("every exported named tuple matches an original complete compiler value witness", () => {
  const witnesses = new Set();
  const visit = p => {
    witnesses.add(JSON.stringify(shape(p)));
    if (p.baseType === "array") visit(p.arrayChildren);
    if (p.baseType === "tuple") p.components.forEach(visit);
  };
  for (const iface of Object.values(compiledInterfaces)) for (const f of iface.fragments) [...f.inputs ?? [], ...f.outputs ?? []].forEach(visit);
  for (const name of Object.keys(fixture.libraryAbis)) {
    const rows = libraryValueABI(name);
    for (const f of rows) for (const p of [...f.inputs ?? [], ...f.outputs ?? []]) {
      const recurse = field => { try { visit(ParamType.from(field)); } catch { /* Raw storage/nominal non-value types remain raw evidence. */ } for (const c of field.components ?? []) recurse(c); };
      recurse(p);
    }
  }
  const tree = ts.createSourceFile(pureUrl.pathname, readFileSync(pureUrl, "utf8"), ts.ScriptTarget.Latest, true), names = new Set();
  for (const s of tree.statements) {
    if (ts.isVariableStatement(s) && s.modifiers?.some(m => m.kind === ts.SyntaxKind.ExportKeyword)) for (const d of s.declarationList.declarations) if (ts.isIdentifier(d.name) && d.name.text.endsWith("_TUPLE")) names.add(d.name.text);
    if (ts.isExportDeclaration(s) && s.exportClause && ts.isNamedExports(s.exportClause)) for (const d of s.exportClause.elements) if (d.name.text.endsWith("_TUPLE")) names.add(d.name.text);
  }
  for (const name of names) {
    const p = ParamType.from(readPure(name));
    if (name === "ARTIST_RECOVERED_MULTIPLE_ATTESTATION_HYDRATION_ENVELOPE_TUPLE") { assert.match(source("StreamArtistRecoveredHydrationTypes.sol"), /struct Envelope\s*\{\s*ExportHeader header;\s*bytes payload;/); assert.deepEqual(p.components.map(x => x.name), ["header", "payload"]); }
    else if (name.endsWith("_ATTRIBUTION_TUPLE")) { assert.match(source("StreamArtistRecoveredMultipleConsentCollectionRows.sol"), /struct AttributionRow\s*\{\s*Original.AttributionBundle state;\s*bytes32 proposalOrigin;/); assert.ok(witnesses.has(JSON.stringify(shape(p.components[0])))); assert.equal(p.components[1].name, "proposalOrigin"); assert.equal(p.components[1].type, "bytes32"); }
    else assert.ok(witnesses.has(JSON.stringify(shape(p))), name);
  }
  assert.ok(names.size >= 50);
  assert.deepEqual(shape(ParamType.from(readPure("ARTIST_RECOVERED_MULTIPLE_ATTESTATION_HYDRATION_STATE_TUPLE"))), shape(compiledLibraryValueInterface("multipleAttestationCodec").getFunction("encode").inputs[1]));
});

test("closed feature masks and original whole-graph delegation invariants are source derived", () => {
  assert.equal(readPure("ARTIST_RECOVERED_MULTIPLE_ATTESTATION_HYDRATION_SOURCE"), fixture.sourceCommit);
  assert.equal(readPure("ARTIST_RECOVERED_MULTIPLE_ATTESTATION_HYDRATION_BASE"), 1048576n);
  assert.equal(readPure("ARTIST_RECOVERED_MULTIPLE_ATTESTATION_HYDRATION_ALLOWED_FEATURES"), 1049087n);
  assert.equal(readPure("ARTIST_RECOVERED_MULTIPLE_ATTESTATION_HYDRATION_KNOWN_FEATURES"), 2097151n);
  assert.match(source("StreamArtistRecoveredMultipleAttestationCodec.sol"), /6529STREAM_ARTIST_RECOVERED_MULTIPLE_ATTESTATIONS_V1/);
  assert.match(source("StreamArtistRecoveredMultipleAttestationPreparation.sol"), /features = RH.MULTIPLE_ATTESTATIONS/);
  const grants = source("StreamArtistRecoveredMultipleConsentFacts.sol");
  assert.match(grants, /total\[g\] \+= uses\[g\]/); assert.match(grants, /total\[g\] != identity.delegations\[g\].record.uses/);
  const lanes = source("StreamArtistRecoveredMultipleConsentNonces.sol");
  assert.match(lanes, /if \(kind == 2\)/); assert.match(lanes, /seen\[k\] \|\| \(j != 0 && k <= previous\)/); assert.match(lanes, /total != inventory.length/);
  assert.match(source("StreamArtistRecoveredMultipleConsentDelegations.sol"), /uses == 0 \|\| _consumed\(n\) != uses/);
  assert.match(source("StreamArtistRecoveredMultipleConsentContentRows.sol"), /signature.length > 4096/);
});

test("public Registry methods and all workflow read fragments match exact ordinary compiler endpoints", async () => {
  const r = await import("../dist/current-artist-recovered-multiple-attestation-hydration.js");
  const api = new Interface(r.CURRENT_ARTIST_RECOVERED_MULTIPLE_ATTESTATION_HYDRATION_ABI);
  for (const f of api.fragments) {
    const original = compiledInterfaces.registry.fragments.find(g => g.type === f.type && g.format("sighash") === f.format("sighash"));
    assert.ok(original, f.format("full")); compatibleFragment(f, original);
  }
  const get = literalReader(new URL("../src/current-artist-recovered-multiple-attestation-hydration-workflow.ts", import.meta.url));
  const all = Object.values(compiledInterfaces).flatMap(i => i.fragments);
  for (const name of ["abi", "identityAbi", "consentAbi", "attestationAbi", "clockAbi"]) for (const f of new Interface(get(name)).fragments) {
    assert.equal(f.type, "function"); assert.ok(["view", "pure"].includes(f.stateMutability));
    assert.ok(all.some(original => { if (original.type !== f.type || original.format("sighash") !== f.format("sighash")) return false; try { compatibleFragment(f, original); return true; } catch { return false; } }), name + f.format("full"));
  }
});

test("raw content and state bytes use exact compiler tuples without the singleton content tag", async () => {
  const { m: r, semanticFixture, coder, T, hash, child } = await import("./current-artist-recovered-multiple-attestation-hydration-semantic-fixture.mjs");
  const f = semanticFixture({ delegated: false });
  const expected = coder.encode([T.content], [f.contents[0]]);
  assert.equal(r.encodeArtistRecoveredMultipleAttestationHydrationContentBundle(f.contents[0]), expected);
  assert.deepEqual(r.decodeArtistRecoveredMultipleAttestationHydrationContentBundle(expected), f.contents[0]);
  const local = f.payloads[6].provenance;
  const state = coder.encode(["bytes32", "uint16", "uint8", T.state, "bytes"], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_ATTESTATIONS_V1"), 1n, 6n, f.states[6], "0x"]);
  assert.equal(r.encodeArtistRecoveredMultipleAttestationHydrationState(f.states[6], 6, local), state);
  assert.equal(r.artistRecoveredMultipleAttestationHydrationContentScope(f.contents[0].consents[0].terms), hash([child(child(T.content, "consents").arrayChildren, "terms"), "uint64"], [f.contents[0].consents[0].terms, 1n]));
  assert.equal(r.artistRecoveredMultipleAttestationHydrationRoyaltyScope(f.contents[0].royalties[0].terms, f.contents[0].original.artistId), hash([child(child(T.content, "royalties").arrayChildren, "terms"), "bytes32", "uint64"], [f.contents[0].royalties[0].terms, f.contents[0].original.artistId, 1n]));
});

test("compiler-original semantic inventory and operation60 commitment bind full plural consent facts", async () => {
  const { m: r, semanticFixture, T, hash, child } = await import("./current-artist-recovered-multiple-attestation-hydration-semantic-fixture.mjs");
  const f = semanticFixture(), p = f.prepared;
  const expected = hash(["bytes32", "uint16", "bytes32", child(T.prepared, "query"), child(T.prepared, "data"), child(T.prepared, "timing"), child(T.prepared, "externalGuards")],
    [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, r.artistRecoveredMultipleAttestationHydrationProvenanceHash(p.admission.provenance), p.query, p.data, p.timing, p.externalGuards]);
  assert.equal(r.artistRecoveredMultipleAttestationHydrationSemanticInventory(p), expected);
  const req = compiledInterfaces.registry.getFunction("hydrateRecoveredArtistAuthority").inputs[0];
  const admission = child(T.prepared, "admission");
  const commitment = hash(["bytes32", "uint16", "uint256", "address", "address", "address", "address", req, child(admission, "artists"), child(admission, "collections"),
    child(T.prepared, "query"), child(T.prepared, "data"), child(T.prepared, "timing"), child(T.prepared, "externalGuards"), child(admission, "before_")],
    [id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1"), 1n, f.coords.chainId, f.coords.registry, f.coords.coordinator, p.admission.prior, p.admission.sourceCoordinator,
      f.request, p.admission.artists, p.admission.collections, p.query, p.data, p.timing, p.externalGuards, p.admission.before_]);
  assert.equal(r.artistRecoveredMultipleAttestationHydrationCommitment(f.coords, f.request, p), commitment);
});

test("both original Prepared selectors and Registry calldata are reconstructed from compiler inputs", async () => {
  const { m: r, semanticFixture, coder, A } = await import("./current-artist-recovered-multiple-attestation-hydration-semantic-fixture.mjs");
  for (const royalties of [false, true]) {
    const f = semanticFixture({ royalties });
    const p = compiledLibraryValueInterface("prepared").fragments.find(p => p.type === "function" && p.name === "prepare" && p.inputs.length === (royalties ? 3 : 2));
    const expected = (royalties ? "0x4925300f" : "0x72c84763") + coder.encode(p.inputs, royalties ? [f.source, f.request, f.input.royaltyFreezes] : [f.source, f.request]).slice(2);
    assert.equal(r.artistRecoveredMultipleAttestationHydrationPreparationCalldata(f.source, f.input), expected);
    const plan = r.prepareArtistRecoveredMultipleAttestationHydrationCall(f.coords.registry, A(200), f.input);
    assert.equal(plan.call.data, compiledInterfaces.registry.encodeFunctionData(royalties ? "hydrateRecoveredArtistAuthorityWithConsents" : "hydrateRecoveredArtistAuthority", royalties ? [f.request, f.input.royaltyFreezes] : [f.request]));
    assert.equal(plan.call.value, 0n); assert.equal(plan.factsVerified, false);
  }
});

test("original attestation record and EIP712 preimages use compiler fields and full uint256 identifiers", async () => {
  const { m: r, semanticFixture, hash, coder, T } = await import("./current-artist-recovered-multiple-attestation-hydration-semantic-fixture.mjs");
  const f = semanticFixture(), o = f.origin, b = f.attestations[0], row = b.records[0].attestation, t = row.input.terms;
  const domains = source("StreamArtistHashes.sol");
  assert.match(domains, /6529STREAM_ARTIST_ATTESTATION_RECORD_V1/);
  assert.match(domains, /StreamArtistAttestation\(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt\)/);
  const record = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), o.chainId, o.registry, o.core, t.collectionId, t.subjectKind, t.subjectId, t.subjectStateHash,
      t.schemaId, t.statementHash, keccak256(Buffer.from(t.statementURI, "utf8")), b.artistId, row.record.signer, row.authorityClass, row.input.nonce, row.record.signedAt]));
  assert.equal(r.artistRecoveredMultipleAttestationHydrationAttestationRecordHash(o, b.artistId, row), record);
  const domain = hash(["bytes32", "bytes32", "bytes32", "uint256", "address"], [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), o.chainId, o.registry]);
  const body = hash(["bytes32", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64"],
    [id("StreamArtistAttestation(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt)"),
      o.core, t.collectionId, t.subjectKind, t.subjectId, t.subjectStateHash, t.schemaId, t.statementHash, keccak256(Buffer.from(t.statementURI, "utf8")), row.input.nonce, row.record.signedAt]);
  assert.equal(r.artistRecoveredMultipleAttestationHydrationAttestationDigest(o, row), keccak256(`0x1901${domain.slice(2)}${body.slice(2)}`));
  assert.ok(t.collectionId > 1n << 128n);
  assert.equal(r.encodeArtistRecoveredMultipleAttestationHydrationAttestationBundle(b), coder.encode([T.attestation], [b]));
});

test("owner4 alone carries original Archive clocks and owner4 transitions use the original flat envelope", async () => {
  const { m: r, semanticFixture, hash, coder, T } = await import("./current-artist-recovered-multiple-attestation-hydration-semantic-fixture.mjs");
  const f = semanticFixture(), o = f.origin, clocks = source("StreamArtistRecoveredMultipleAttestationClocks.sol");
  assert.match(clocks, /inventory\.operations\.length != 2 \* scope\.collections\.length/);
  assert.match(clocks, /native_\.position\.point\.ownerRevision != envelope\.after_\[owner\]\.revision/);
  assert.match(clocks, /Clock\.beforeOwner\(p, 4, c\.completions\[k\], j\.position\.point\)/);
  const e = f.envelopes[0], q = f.collections[0], binding = structuredClone(f.bindings[0].item); binding.accepted = false;
  const payload = coder.decode(T.proposal.components, e.payload);
  const proposal = payload[1];
  const action = hash(["uint256", T.acceptancePayload.components[1], "bytes32", "string"], [q.collectionId, binding, proposal.reasonHash, proposal.reasonURI]);
  const state = hash(["uint256", "uint8", "uint64"], [q.collectionId, 1n, 1n]);
  const expected = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"), o.chainId, o.registry, o.coordinator, o.archive, o.owners[4], e.before_[4].domainId,
      e.before_[4].revision, e.after_[4].revision, e.before_[4].stateRoot, hash(["uint16", "address", "bytes32"], [1n, e.actor, action]), state, ZeroHash, hash(["bytes32"], [ZeroHash])]);
  assert.equal(e.after_[4].stateRoot, expected);
  assert.equal(f.clockFacts.envelopes[0], coder.encode(T.envelope.components, T.envelope.components.map(p => e[p.name])));
  assert.equal(r.encodeArtistRecoveredMultipleAttestationHydrationAttributionState(f.states[4], f.payloads[4].provenance, coder.encode([T.clocks], [f.clocks])),
    coder.encode(["bytes32", "uint16", "uint8", T.state, "bytes"], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_ATTESTATIONS_V1"), 1n, 4n, f.states[4], coder.encode([T.clocks], [f.clocks])]));
  const composition = source("StreamArtistRecoveredMultipleAttestationConservation.sol");
  assert.match(composition, /before_\[a\]\[g\] \+ after_\[a\]\[g\] != b\.delegations\[g\]\.record\.uses/);
  assert.match(source("StreamArtistRecoveredMultipleAttestationQueries.sol"), /24/);
});
