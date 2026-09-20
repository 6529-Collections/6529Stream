import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledInterfaces, compiledLibraryEvents } from "./current-scoped-policy-root-v2-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const fields = tuple => tuple.components.map(p => [p.name, p.type]);
const words = type => type.baseType === "tuple"
  ? type.components.reduce((n, p) => n + words(p), 0)
  : type.baseType === "array" ? type.arrayLength * words(type.arrayChildren) : 1;

test("scoped root and original op17 witness retains the exact ABI129 committed source and evidence boundary", () => {
  assert.equal(fixture.profile, "scoped-policy-root-v2");
  assert.equal(fixture.sourceCommit, "896899f7ca4130f86e066587f780a3b1f755a25d");
  assert.equal(fixture.sourceTree, "743efae1136e5742cb57c9e477080bd1c6aca5aa");
  assert.equal(fixture.compilerReportedCommit, fixture.sourceCommit);
  assert.equal(fixture.compilerVersion, "0.8.19");
  assert.equal(fixture.sourceCount, 3262);
  assert.equal(fixture.literalBytes, 38308658);
  assert.equal(fixture.inputSha256, "2f53a404ef440f637623a5dcfa143d7c617f403bd01438e36f507dc0da329295");
  assert.equal(fixture.outputSha256, "d646cec16ef86f03a7689e856473f2967a8b30e4d64dfafeba395f445ca3ffbb");
  const { sha256, ...bridge } = fixture.committedSourceBridge;
  assert.equal(sha256, "f59fa4f8b70da4f1ac70d1224e8b4740d398cdd41df29bb48c6d6ddc8cbad696");
  assert.equal(sha((JSON.stringify(bridge, null, 2) + "\n").replaceAll("\n", "\r\n")), sha256);
  assert.equal(bridge.commit, fixture.sourceCommit);
  assert.equal(bridge.sources, 3262);
  assert.equal(Object.keys(bridge.committedBlobSHA256).length, 3262);
  assert.deepEqual(bridge.mismatches, []);
  assert.match(fixture.sourceBinding, /no line-ending normalization/);
  assert.match(fixture.qualification, /original Artist operation-17 content consent/);
  assert.match(fixture.qualification, /Native\/Safe execution.*remain separately qualified/);
});

test("all ordinary contract and interface selectors retain complete compiler ABIs", () => {
  assert.equal(Object.keys(fixture.abis).length, 112);
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 3725);
  let selectors = 0;
  for (const [key, iface] of Object.entries(compiledInterfaces)) {
    assert.equal(fixture.selections[key].full, true);
    const functions = iface.fragments.filter(f => f.type === "function");
    assert.equal(functions.length, Object.keys(fixture.methodIdentifiers[key]).length, key);
    for (const f of functions) {
      assert.equal(fixture.methodIdentifiers[key][f.format("sighash")], f.selector.slice(2), `${key}:${f.name}`);
      selectors++;
    }
  }
  assert.equal(selectors, 2542);
});

test("nominal fixed deployment and reader libraries stay separate from wallet calls", () => {
  assert.equal(Object.keys(fixture.libraryAbis).length, 36);
  assert.equal(Object.values(fixture.libraryAbis).reduce((n, a) => n + a.length, 0), 150);
  let count = 0;
  for (const [key, abi] of Object.entries(fixture.libraryAbis)) {
    assert.equal(fixture.librarySelections[key].full, true);
    assert.equal(fixture.librarySelections[key].nominal, true);
    assert.equal(compiledInterfaces[key], undefined);
    const events = compiledLibraryEvents(key);
    assert.equal(events.fragments.length, abi.filter(f => f.type === "event").length);
    assert.ok(events.fragments.every(f => f.type === "event"));
    for (const [signature, selector] of Object.entries(fixture.libraryMethodIdentifiers[key])) {
      assert.equal(id(signature).slice(2, 10), selector);
      count++;
    }
  }
  assert.equal(count, 106);
  const nominal = fixture.libraryMethodIdentifiers.graphReads[
    "current(StreamScopedPolicyPublicationGraphTypesV2.Recipe,bytes32,StreamFinalityScope)"
  ];
  assert.equal(nominal, "0b5c2ea0");
  const raw = fixture.libraryAbis.graphReads.find(f => f.name === "current");
  assert.equal(raw.inputs[2].components[0].type, "StreamFinalityScopeType");
  const recipe = compiledInterfaces.publicationFactory.getFunction("recipe").outputs[0].format("sighash");
  const scope = compiledInterfaces.publicationFactory.getFunction("prepareGraph").inputs[0].format("sighash");
  assert.notEqual(id(`current(${recipe},bytes32,${scope})`).slice(2, 10), nominal);
});

test("all selected sources retain a complete lexical closure and exact source bridge hashes", () => {
  const visited = new Set();
  function visit(path) {
    if (visited.has(path)) return;
    visited.add(path);
    const text = fixture.sourceTexts[path];
    assert.equal(typeof text, "string", path);
    assert.equal(sha(text), fixture.sourceHashes[path], path);
    assert.equal(sha(text), fixture.committedSourceBridge.committedBlobSHA256[path], path);
    for (const imported of solidityImports(text)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  for (const selection of [...Object.values(fixture.selections), ...Object.values(fixture.librarySelections)]) visit(selection.source);
  assert.deepEqual([...visited].sort(), Object.keys(fixture.sourceHashes).sort());
  assert.deepEqual(Object.keys(fixture.sourceTexts).sort(), Object.keys(fixture.sourceHashes).sort());
  assert.equal(visited.size, 1284);
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, text) => n + Buffer.byteLength(text), 0), 8508825);
});

test("original documents retain scope and acyclic preparation/publication boundaries", () => {
  assert.equal(Object.keys(fixture.documents).length, 26);
  let size = 0;
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
    size += document.byteLength;
  }
  assert.equal(size, 647742);
  const preservation = fixture.documents["docs/integrations/scoped-policy-preservation-v2.md"].text;
  assert.match(preservation, /TOKEN, RELEASE and SEASON/);
  assert.match(preservation, /does not require a snapshot, root,\nreference or inventory publication/);
  assert.match(fixture.documents["docs/integrations/scoped-policy-finality-v2.md"].text,
    /absent scoped head or completely empty V2 binding retains original scoped V1/);
});

test("root writes, publisher preview and original Artist consent retain exact compiler selectors", () => {
  const cases = [
    ["router", "previewScopedPolicyContentRootPublication", "745e3d75", "view"],
    ["router", "publishScopedPolicyContentRootPublication", "fc307407", "nonpayable"],
    ["router", "scopedContentRootRecord", "1917cae6", "view"],
    ["router", "scopedContentRootAggregate", "59d460c4", "view"],
    ["router", "scopedPolicyContentRootBinding", "0c2dc183", "view"],
    ["artist", "recordContentConsent", "97194184", "nonpayable"],
    ["artist", "contentConsentDigest", "381509e1", "view"],
    ["artist", "contentConsentEvidenceForHost", "51a042ce", "view"],
  ];
  for (const [key, name, selector, mutability] of cases) {
    const f = compiledInterfaces[key].getFunction(name);
    assert.equal(f.selector, "0x" + selector);
    assert.equal(fixture.methodIdentifiers[key][f.format("sighash")], selector);
    assert.equal(f.stateMutability, mutability);
  }
  const root = compiledInterfaces.router.getFunction("publishScopedPolicyContentRootPublication");
  assert.deepEqual(fields(root.inputs[0]), [
    ["scope", "tuple"], ["expectedPredecessor", "bytes32"], ["snapshotRecordHash", "bytes32"],
    ["snapshotRevision", "uint64"], ["manifestURI", "string"],
  ]);
  assert.equal(compiledInterfaces.artist.getFunction("contentConsentEvidenceForHost").inputs.length, 4);
  assert.equal(compiledInterfaces.artist.getFunction("contentConsentEvidence").inputs.length, 3);
  assert.notEqual(compiledInterfaces.artist.getFunction("contentConsentEvidence").selector, "0x51a042ce");
});

test("original root record, V2 binding and historical Aggregate retain complete named fields and events", () => {
  const r = compiledInterfaces.router.getFunction("scopedContentRootRecord").outputs[0];
  assert.deepEqual(fields(r), [
    ["publication", "tuple"], ["snapshotHost", "address"], ["snapshotCodeHash", "bytes32"],
    ["snapshotManifestHash", "bytes32"], ["snapshotSourceHash", "bytes32"], ["contentRoot", "bytes32"],
    ["leafCount", "uint64"], ["outputManifestHash", "bytes32"], ["artistId", "bytes32"],
    ["bindingGeneration", "uint64"], ["bindingHash", "bytes32"], ["publisher", "address"],
    ["authorizationClass", "uint8"], ["grantRevision", "uint64"], ["routeHash", "bytes32"],
    ["stateHash", "bytes32"], ["artistConsent", "bytes32"], ["publishedAt", "uint64"],
  ]);
  const b = compiledInterfaces.router.getFunction("scopedPolicyContentRootBinding").outputs[0];
  assert.equal(b.components.length, 23);
  assert.equal(words(b), 23);
  const a = compiledInterfaces.router.getFunction("scopedContentRootAggregate").outputs[0];
  assert.deepEqual(fields(a), [["revision", "uint64"], ["transitionChain", "bytes32"]]);
  const events = compiledLibraryEvents("metadataScopedPolicyContentV2");
  const published = events.getEvent("ScopedContentRootPublished");
  assert.deepEqual(published.inputs.map(p => [p.name, p.indexed]), [
    ["schemaVersion", false], ["collectionId", true], ["scopeSubject", true], ["recordHash", true],
    ["record", false], ["collectionAggregate", false],
  ]);
  assert.equal(published.inputs[4].format("sighash"), r.format("sighash"));
  assert.equal(published.inputs[5].format("sighash"), a.format("sighash"));
  const companion = events.getEvent("ScopedPolicyContentRootBindingPublished");
  assert.equal(companion.inputs[4].format("sighash"), b.format("sighash"));
  assert.equal(companion.inputs[4].indexed, false);
  const applied = compiledLibraryEvents("metadataContentAuthorization").getEvent("ArtistContentConsentApplied");
  assert.deepEqual(applied.inputs.map(p => [p.name, p.type, p.indexed]), [
    ["collectionId", "uint256", true], ["familyId", "bytes32", true], ["consentRecordHash", "bytes32", true],
    ["resultingContentStateHash", "bytes32", false], ["schemaVersion", "uint16", false],
  ]);
});

test("same-named Artist methods preserve facade, Coordinator and owner ABI boundaries", () => {
  const facade = compiledInterfaces.artist.getFunction("recordContentConsent");
  assert.deepEqual(fields(facade.inputs[0]), [
    ["collectionId", "uint256"], ["metadataContract", "address"], ["familyId", "bytes32"], ["newStateHash", "bytes32"],
  ]);
  assert.deepEqual(fields(facade.inputs[1]), [["nonce", "uint256"], ["time", "uint64"], ["signature", "bytes"]]);
  const coordinate = compiledInterfaces.artistCoordinator.getFunction("coordinateRecordContentConsent");
  assert.equal(coordinate.inputs.length, 3);
  assert.equal(coordinate.inputs[0].name, "actor");
  assert.equal(coordinate.inputs[1].format("sighash"), facade.inputs[0].format("sighash"));
  assert.equal(coordinate.inputs[2].format("sighash"), facade.inputs[1].format("sighash"));
  assert.notEqual(compiledInterfaces.contentRecords.getFunction("recordContentConsent").selector, facade.selector);
  const facadeRatification = compiledInterfaces.artist.getFunction("firstReleaseRatification");
  const ownerRatification = compiledInterfaces.consent.getFunction("firstReleaseRatification");
  assert.equal(facadeRatification.selector, ownerRatification.selector);
  assert.deepEqual(facadeRatification.outputs.map(x => x.type), ["bool", "bytes32", "bytes32"]);
  assert.deepEqual(fields(ownerRatification.outputs[0]), [
    ["recordHash", "bytes32"], ["contentStateHash", "bytes32"], ["metadataContract", "address"],
  ]);
  const hashes = fixture.sourceTexts["smart-contracts/domains/artist/StreamArtistContentHashes.sol"];
  assert.ok(hashes.includes("StreamArtistContentConsent(address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline)"));
  assert.ok(hashes.includes('keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1")'));
  assert.ok(hashes.includes("uint64 observedAt"));
});

test("original root definition bytes require historical Aggregate and distinct state, family and record commitments", () => {
  const text = fixture.sourceTexts["smart-contracts/domains/finality/StreamScopedPolicyContentRootSchemasV2.sol"];
  const documents = [...text.matchAll(/return bytes\(\s*'([^']+)'/g)].map(m => ({ raw: m[1], value: JSON.parse(m[1]) }));
  assert.equal(documents.length, 2);
  const [schema, canon] = documents;
  assert.equal(schema.value.name, "STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2");
  assert.equal(canon.value.name, "STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2");
  assert.deepEqual(schema.value.bindingFields, compiledInterfaces.router.getFunction("scopedPolicyContentRootBinding")
    .outputs[0].components.map(p => p.type + " " + p.name));
  assert.match(canon.value.stateHash, /recordWithStateHashConsentAndPublishedAtZero,binding/);
  assert.match(canon.value.recordHash, /completedRecord,binding,historicalAggregate/);
  assert.match(canon.value.signedFamily, /individual stateHash is not signed family/);
  assert.match(canon.value.history, /V2 never enters V1 snapshot decoders/);
  assert.match(schema.value.authority, /SNAPSHOT class7 collection or class8 global/);
  assert.match(schema.value.authority, /operation17 CONTENT_ROOT consent/);
  assert.match(schema.value.entropy, /finalized=false/);
  assert.ok(documents.every(d => !d.raw.endsWith("\n")));
  const worker = fixture.sourceTexts["smart-contracts/domains/metadata/StreamMetadataScopedPolicyContentV2.sol"];
  const rootEvent = worker.indexOf("emit ScopedContentRootPublished(");
  const bindingEvent = worker.indexOf("emit ScopedPolicyContentRootBindingPublished(");
  assert.ok(rootEvent > 0 && bindingEvent > rootEvent);
  assert.ok(worker.indexOf("Content.recordApplication(") > worker.indexOf("hash = _commit("));
  assert.match(worker, /consent == 0/);
  assert.match(worker, /_nextFamily\(state, l, c, current\) != nextFamily/);
  const source = fixture.sourceTexts["smart-contracts/domains/metadata/StreamMetadataScopedPolicyContentSourceV2.sol"];
  assert.match(source, /type\(Provider\)\.interfaceId/);
  assert.match(source, /r\.validationGas < r\.readGas/);
  assert.match(source, /Provider\.scopedPolicySnapshotHost/);
});

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
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isIdentifier(node)) return locals.has(node.text) ? locals.get(node.text) : read(node.text);
    if (ts.isPropertyAccessExpression(node) && ts.isIdentifier(node.expression) && namespaces.has(node.expression.text)) {
      return literalReader(namespaces.get(node.expression.text), cache)(node.name.text);
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




test("root and original op17 tuple literals match every original compiler field and width", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-root-v2.ts", import.meta.url));
  const r = compiledInterfaces.router;
  const publication = r.getFunction("publishScopedPolicyContentRootPublication").inputs[0];
  const samples = {
    SCOPE: publication.components[0], PUBLICATION: publication,
    RECORD: r.getFunction("scopedContentRootRecord").outputs[0],
    BINDING: r.getFunction("scopedPolicyContentRootBinding").outputs[0],
    AGGREGATE: r.getFunction("scopedContentRootAggregate").outputs[0],
    CONSENT_TERMS: compiledInterfaces.artist.getFunction("recordContentConsent").inputs[0],
    AUTHORIZATION: compiledInterfaces.artist.getFunction("recordContentConsent").inputs[1],
    SIGNER_APPROVAL: compiledInterfaces.contentIdentity.getFunction("consumeContentConsent").inputs[4],
    ARTIST_BINDING: compiledInterfaces.binding.getFunction("binding").outputs[0],
  };
  for (const [name, original] of Object.entries(samples)) {
    sameFields([ParamType.from(read("SCOPED_POLICY_ROOT_V2_" + name + "_TUPLE"))], [original], name);
  }
});


// These vectors bind synthetic supplied facts to original compiler tuple encodings;
// they do not establish deployed source, authority or currentness admission.
function originalExample(type, counter = { value: 10 }) {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(p => [p.name, originalExample(p, counter)]));
  if (type.baseType === "array") return Array.from({ length: type.arrayLength < 0 ? 2 : type.arrayLength },
    () => originalExample(type.arrayChildren, counter));
  const n = ++counter.value;
  if (type.type === "address") return getAddress("0x" + n.toString(16).padStart(40, "0"));
  if (type.type === "bool") return n % 2 === 0;
  if (type.type === "string") return "root evidence " + n;
  if (type.type === "bytes") return "0xaabb";
  if (type.type.startsWith("bytes")) return "0x" + n.toString(16).padStart(Number(type.type.slice(5)) * 2, "0");
  if (type.type.startsWith("uint")) return Number(type.type.slice(4)) >= 128 ? (1n << 120n) + BigInt(n) : BigInt(n % 127 + 1);
  throw Error("Unsupported original example " + type.type);
}
function originalZero(type) {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(p => [p.name, originalZero(p)]));
  if (type.type === "address") return ZeroAddress;
  if (type.type.startsWith("bytes")) return "0x" + "00".repeat(Number(type.type.slice(5)) || 0);
  if (type.type.startsWith("uint")) return 0n;
  if (type.type === "string") return "";
  if (type.type === "bool") return false;
  throw Error("Unsupported original zero " + type.type);
}
const originalCoder = AbiCoder.defaultAbiCoder();
const hashOriginal = (types, values) => keccak256(originalCoder.encode(types, values));
const exampleAddress = n => getAddress("0x" + BigInt(n).toString(16).padStart(40, "0"));
const exampleHash = n => "0x" + BigInt(n).toString(16).padStart(64, "0");
const exampleCoordinates = () => ({
  chainId: (1n << 129n) + 6529n, core: exampleAddress(1), router: exampleAddress(2), artistRegistry: exampleAddress(3)
});
const exampleScope = () => ({ scopeType: 2n, collectionId: (1n << 130n) + 9n, tokenId: 0n, scopeId: exampleHash(7) });

test("V2 root route and state hashes use original order, full scope and three normalized fields", async () => {
  const p = await import("../dist/current-scoped-policy-root-v2.js");
  const c = exampleCoordinates(), scope = exampleScope();
  const recordType = compiledInterfaces.router.getFunction("scopedContentRootRecord").outputs[0];
  const bindingType = compiledInterfaces.router.getFunction("scopedPolicyContentRootBinding").outputs[0];
  const route = { finality: exampleAddress(4), provider: exampleAddress(5), snapshot: exampleAddress(6),
    codeHashes: Array.from({ length: 6 }, (_, n) => exampleHash(20 + n)), metadata: exampleAddress(7),
    metadataCodeHash: exampleHash(27), scope };
  const routeHash = hashOriginal(["bytes32", "uint256", "address[6]", "bytes32[6]", "address", "bytes32", recordType.components[0].components[0]],
    [id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_ROUTE_V2"), c.chainId,
      [c.core, c.artistRegistry, c.router, route.finality, route.provider, route.snapshot], route.codeHashes,
      route.metadata, route.metadataCodeHash, scope]);
  assert.equal(p.scopedPolicyRootV2RouteHash(c, route), routeHash);
  assert.notEqual(p.scopedPolicyRootV2RouteHash(c, { ...route, provider: route.snapshot, snapshot: route.provider }), routeHash);
  assert.notEqual(p.scopedPolicyRootV2RouteHash(c, { ...route, metadataCodeHash: exampleHash(99) }), routeHash);
  const record = originalExample(recordType);
  record.publication.scope = scope;
  record.publication.manifestURI = "ipfs://root/作品";
  record.routeHash = routeHash;
  const binding = { ...originalExample(bindingType), profileId: id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2") };
  const expected = hashOriginal(["bytes32", "uint256", "address", "address", recordType, bindingType],
    [id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_STATE_V2"), c.chainId, c.router, c.core,
      { ...record, stateHash: ZeroHash, artistConsent: ZeroHash, publishedAt: 0n }, binding]);
  assert.equal(p.scopedPolicyRootV2StateHash(c, record, binding), expected);
  assert.equal(p.scopedPolicyRootV2StateHash(c, { ...record, stateHash: exampleHash(100), artistConsent: exampleHash(101), publishedAt: 102n }, binding), expected);
  assert.notEqual(p.scopedPolicyRootV2StateHash({ ...c, chainId: c.chainId + 1n }, record, binding), expected);
  assert.notEqual(p.scopedPolicyRootV2StateHash(c, { ...record, publisher: exampleAddress(99) }, binding), expected);
  assert.notEqual(p.scopedPolicyRootV2StateHash(c, { ...record, publication: { ...record.publication, manifestURI: "ipfs://different" } }, binding), expected);
  const encoded = originalCoder.encode([recordType], [record]);
  assert.equal(p.encodeScopedPolicyRootV2Record(record), encoded);
  assert.deepEqual(p.decodeScopedPolicyRootV2Record(encoded), record);
  assert.throws(() => p.decodeScopedPolicyRootV2Record(encoded + "00".repeat(32)));
});

test("original collection aggregate and family differ from both V1 and V2 historical record commitments", async () => {
  const p = await import("../dist/current-scoped-policy-root-v2.js");
  const c = exampleCoordinates(), scope = exampleScope();
  const rType = compiledInterfaces.router.getFunction("scopedContentRootRecord").outputs[0];
  const bType = compiledInterfaces.router.getFunction("scopedPolicyContentRootBinding").outputs[0];
  const aType = compiledInterfaces.router.getFunction("scopedContentRootAggregate").outputs[0];
  const record = originalExample(rType);
  record.publication.scope = scope; record.publication.manifestURI = "https://example.test/root";
  const binding = { ...originalExample(bType), profileId: id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2") };
  record.stateHash = hashOriginal(["bytes32", "uint256", "address", "address", rType, bType],
    [id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_STATE_V2"), c.chainId, c.router, c.core,
      { ...record, stateHash: ZeroHash, artistConsent: ZeroHash, publishedAt: 0n }, binding]);
  const prior = { revision: (1n << 63n) + 17n, transitionChain: exampleHash(200) };
  const subject = hashOriginal(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
    [id("6529STREAM_SUBJECT_SCOPE_V1"), c.chainId, c.core, scope.collectionId, scope.scopeType, scope.scopeId]);
  const aggregate = { revision: prior.revision + 1n, transitionChain: hashOriginal(
    ["bytes32", "uint256", "address", "address", "uint256", "bytes32", "uint64", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1"), c.chainId, c.router, c.core, scope.collectionId,
      prior.transitionChain, prior.revision + 1n, subject, record.publication.expectedPredecessor, record.stateHash]) };
  assert.deepEqual(p.scopedPolicyRootV2NextAggregate(c, prior, record.publication.expectedPredecessor, record), aggregate);
  assert.throws(() => p.scopedPolicyRootV2NextAggregate(c, prior, exampleHash(999), record));
  assert.throws(() => p.scopedPolicyRootV2NextAggregate(c, { ...prior, revision: (1n << 64n) - 1n }, record.publication.expectedPredecessor, record));
  const legacy = hashOriginal(["bytes32", "uint256", "address", "address", "uint256"],
    [id("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"), c.chainId, c.router, c.core, scope.collectionId]);
  assert.equal(p.scopedPolicyRootV2EmptyLegacyFamily(c, scope.collectionId), legacy);
  const family = hashOriginal(["bytes32", "uint256", "address", "address", "uint256", "bytes32", aType],
    [id("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"), c.chainId, c.router, c.core, scope.collectionId, legacy, aggregate]);
  assert.equal(p.scopedPolicyRootV2FamilyHash(c, scope.collectionId, legacy, aggregate), family);
  assert.equal(p.scopedPolicyRootV2FamilyHash(c, scope.collectionId, legacy, { revision: 0n, transitionChain: ZeroHash }), legacy);
  assert.notEqual(family, record.stateHash);
  record.publishedAt = (1n << 63n) + 27n;
  const v2 = hashOriginal(["bytes32", "uint256", "address", "address", rType, bType, aType],
    [id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"), c.chainId, c.router, c.core, record, binding, aggregate]);
  const legacyRecord = { ...record, stateHash: hashOriginal(["bytes32", "uint256", "address", "address", rType],
    [id("6529STREAM_SCOPED_CONTENT_ROOT_STATE_V1"), c.chainId, c.router, c.core,
      { ...record, stateHash: ZeroHash, artistConsent: ZeroHash, publishedAt: 0n }]) };
  const v1 = hashOriginal(["bytes32", "uint256", "address", "address", rType, aType],
    [id("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"), c.chainId, c.router, c.core, legacyRecord, aggregate]);
  assert.equal(p.scopedPolicyRootV2RecordHash(c, record, binding, aggregate), v2);
  assert.equal(p.scopedPolicyRootV2LegacyRecordHash(c, legacyRecord, aggregate), v1);
  assert.notEqual(v1, v2); assert.notEqual(v2, family);
  assert.equal(p.authenticateScopedPolicyRootV2History(c, v2, record, binding, aggregate), "v2");
  assert.equal(p.authenticateScopedPolicyRootV2History(c, v1, legacyRecord, originalZero(bType), aggregate), "v1");
  const wrongLegacyState = hashOriginal(["bytes32", "uint256", "address", "address", rType, aType],
    [id("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"), c.chainId, c.router, c.core, record, aggregate]);
  assert.throws(() => p.authenticateScopedPolicyRootV2History(c, wrongLegacyState, record, originalZero(bType), aggregate));
  assert.throws(() => p.authenticateScopedPolicyRootV2History(c, v2, record, binding, { ...aggregate, revision: aggregate.revision + 1n }));
  assert.throws(() => p.authenticateScopedPolicyRootV2History(c, v1, legacyRecord, { ...originalZero(bType), outputRoot: exampleHash(1) }, aggregate));
  assert.throws(() => p.authenticateScopedPolicyRootV2History(c, v2, record, { ...binding, profileId: exampleHash(999) }, aggregate));
  assert.notEqual(p.scopedPolicyRootV2RecordHash(c, { ...record, publishedAt: record.publishedAt + 1n }, binding, aggregate), v2);
  assert.notEqual(p.scopedPolicyRootV2FamilyHash(c, scope.collectionId, exampleHash(998), aggregate), family);
});

test("unchanged original operation17 signer matches the frozen Registry domain, field order and calldata", async () => {
  const { prepareArtistContentConsent } = await import("../dist/current-manifests.js");
  const c = exampleCoordinates(), scope = exampleScope();
  const terms = { collectionId: scope.collectionId, metadataContract: c.router, familyId: id("CONTENT_ROOT"), newStateHash: exampleHash(300) };
  const auth = { nonce: 0n, deadline: (1n << 63n) + 33n, signature: "0x" };
  const prepared = prepareArtistContentConsent(c.chainId, c.artistRegistry, c.core,
    { collectionId: terms.collectionId, contract: terms.metadataContract, familyId: terms.familyId }, terms.newStateHash, auth);
  const domain = hashOriginal(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
      id("6529StreamArtistRegistry"), id("1"), c.chainId, c.artistRegistry]);
  const struct = hashOriginal(["bytes32", "address", "address", "uint256", "bytes32", "bytes32", "uint256", "uint64"],
    [id("StreamArtistContentConsent(address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline)"),
      c.core, c.router, terms.collectionId, terms.familyId, terms.newStateHash, auth.nonce, auth.deadline]);
  assert.equal(prepared.payload.digest, keccak256("0x1901" + domain.slice(2) + struct.slice(2)));
  assert.equal(prepared.call.to, c.artistRegistry); assert.equal(prepared.call.value, 0n);
  assert.equal(prepared.call.data, compiledInterfaces.artist.encodeFunctionData("recordContentConsent",
    [terms, { nonce: auth.nonce, time: auth.deadline, signature: auth.signature }]));
  assert.equal(prepared.digestCall.data, compiledInterfaces.artist.encodeFunctionData("contentConsentDigest",
    [terms, { nonce: auth.nonce, time: auth.deadline, signature: "0x" }]));
});

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

test("root public ABI fragments match their original host and expose exactly two writes", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-root-v2.ts", import.meta.url));
  const writes = [];
  for (const [name, host] of [["ROUTER", "router"], ["ARTIST", "artist"], ["PROVIDER", "contentRootBinding"]]) {
    const iface = new Interface(read("SCOPED_POLICY_ROOT_V2_" + name + "_ABI"));
    for (const fragment of iface.fragments) {
      const signature = fragment.format("sighash");
      const original = fragment.type === "event"
        ? compiledLibraryEvents("metadataScopedPolicyContentV2").getEvent(signature) : compiledInterfaces[host].getFunction(signature);
      assert.ok(original, name + ":" + signature);
      compatibleFragment(fragment, original);
      if (fragment.type === "function" && !["view", "pure"].includes(fragment.stateMutability)) writes.push(fragment.name);
    }
  }
  assert.deepEqual(writes.sort(), ["publishScopedPolicyContentRootPublication", "recordContentConsent"]);
});

test("workflow reads and events retain original compiler layouts including same-selector outputs", () => {
  const url = new URL("../src/current-scoped-policy-root-v2-workflow.ts", import.meta.url);
  const source = ts.createSourceFile(url.href, readFileSync(url, "utf8"), ts.ScriptTarget.Latest, true);
  const read = literalReader(url), names = [];
  for (const statement of source.statements) {
    if (!ts.isVariableStatement(statement)) continue;
    for (const declaration of statement.declarationList.declarations) {
      if (!ts.isIdentifier(declaration.name) || !declaration.initializer
        || !ts.isNewExpression(declaration.initializer)
        || declaration.initializer.expression.getText(source) !== "Interface") continue;
      if (/^safe/i.test(declaration.name.text)) continue;
      names.push(declaration.name.text);
    }
  }
  assert.ok(names.includes("routeAbi") && names.includes("artistAbi") && names.includes("eventAbi"));
  const originals = Object.values(compiledInterfaces).flatMap(iface => iface.fragments)
    .concat(Object.values(fixture.libraryAbis).flatMap(abi => new Interface(abi.filter(f => f.type === "event")).fragments));
  for (const name of names) for (const fragment of new Interface(read(name)).fragments) {
    const matching = originals.filter(original => original.type === fragment.type
      && original.format("sighash") === fragment.format("sighash"));
    assert.ok(matching.length > 0, name + ":" + fragment.format("sighash"));
    assert.ok(matching.some(original => {
      try { compatibleFragment(fragment, original); return true; } catch { return false; }
    }), name + ":" + fragment.format("full"));
  }
});

test("root definition constants hash the original newline-free Solidity document bytes", async () => {
  const p = await import("../dist/current-scoped-policy-root-v2.js");
  const text = fixture.sourceTexts["smart-contracts/domains/finality/StreamScopedPolicyContentRootSchemasV2.sol"];
  const documents = [...text.matchAll(/return bytes\(\s*'([^']+)'/g)].map(m => Buffer.from(m[1], "utf8"));
  assert.equal(p.SCOPED_POLICY_ROOT_V2_SCHEMA_HASH, keccak256(documents[0]));
  assert.equal(p.SCOPED_POLICY_ROOT_V2_CANONICALIZATION_HASH, keccak256(documents[1]));
  assert.equal(p.SCOPED_POLICY_ROOT_V2_SCHEMA_BYTES, BigInt(documents[0].length));
  assert.equal(p.SCOPED_POLICY_ROOT_V2_CANONICALIZATION_BYTES, BigInt(documents[1].length));
  assert.notEqual(keccak256(Buffer.concat([documents[0], Buffer.from("\n")])), p.SCOPED_POLICY_ROOT_V2_SCHEMA_HASH);
});

test("original op17 record, evidence ID and flat payload bind mined time and submitted authorization", async () => {
  const p = await import("../dist/current-scoped-policy-root-v2.js");
  const c = exampleCoordinates(), scope = exampleScope();
  const terms = { collectionId: scope.collectionId, metadataContract: c.router, familyId: id("CONTENT_ROOT"), newStateHash: exampleHash(301) };
  const facts = { terms, artistId: exampleHash(302), signer: exampleAddress(77), authorityClass: 3n,
    nonce: (1n << 240n) + 3n, observedAt: (1n << 63n) + 40n };
  const record = hashOriginal(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"), c.chainId, c.artistRegistry, c.router, c.core,
      terms.collectionId, terms.familyId, terms.newStateHash, facts.artistId, facts.signer, facts.authorityClass, facts.nonce, facts.observedAt]);
  assert.equal(p.scopedPolicyRootV2ConsentRecordHash(c, facts), record);
  assert.notEqual(p.scopedPolicyRootV2ConsentRecordHash(c, { ...facts, observedAt: facts.observedAt + 1n }), record);
  assert.throws(() => p.scopedPolicyRootV2ConsentRecordHash(c, { ...facts, authorityClass: 4n }));
  const coordinator = exampleAddress(78), actor = exampleAddress(79);
  assert.equal(p.scopedPolicyRootV2ConsentEvidenceId(c, coordinator, actor, record),
    hashOriginal(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
      [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), c.chainId, c.artistRegistry, coordinator, 17n, actor, record]));
  const bindingType = compiledInterfaces.binding.getFunction("binding").outputs[0];
  const binding = originalExample(bindingType);
  const authorization = { nonce: facts.nonce, deadline: facts.observedAt + 60n, signature: "0x1234" };
  const proof = { signer: facts.signer, digest: exampleHash(303), direct: false };
  const payload = { binding, terms, authorization, proof, currentFamilyState: exampleHash(304) };
  const method = compiledInterfaces.artist.getFunction("recordContentConsent");
  const proofType = compiledInterfaces.contentIdentity.getFunction("consumeContentConsent").inputs[4];
  const expected = originalCoder.encode([bindingType, ...method.inputs, proofType, "bytes32"],
    [binding, terms, { nonce: authorization.nonce, time: authorization.deadline, signature: authorization.signature }, proof, payload.currentFamilyState]);
  assert.equal(p.encodeScopedPolicyRootV2ConsentPayload(payload), expected);
  assert.deepEqual(p.decodeScopedPolicyRootV2ConsentPayload(expected), payload);
  assert.throws(() => p.decodeScopedPolicyRootV2ConsentPayload(expected + "00".repeat(32)));
});

test("V2 binding projection retains original dependency positions and all five definition hashes", async () => {
  const p = await import("../dist/current-scoped-policy-root-v2.js");
  const enums = fixture.sourceTexts["smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol"];
  const names = /enum\s+StreamFinalityScopeType\s*\{([^}]*)\}/.exec(enums)[1]
    .replace(/\/\/[^\n]*/g, "").split(",").map(s => s.trim()).filter(Boolean);
  assert.deepEqual(names, ["COLLECTION", "TOKEN", "RELEASE", "SEASON", "VIEW"]);
  function codecWitness(param) {
    // Copy for an encoding witness only; never rewrite a nominal library ABI or selector.
    const copy = { ...param };
    if (copy.type === "StreamFinalityScopeType") {
      assert.equal(copy.internalType, "enum StreamFinalityScopeType");
      copy.type = "uint8";
    }
    if (copy.components) copy.components = copy.components.map(codecWitness);
    return copy;
  }
  const sourceType = ParamType.from(codecWitness(fixture.libraryAbis.snapshotSourceReads.find(f => f.name === "current").outputs[0]));
  const source = originalExample(sourceType);
  source.scope = exampleScope();
  source.selection.scope = exampleScope();
  source.content.scope = exampleScope();
  source.outputs.scope = exampleScope();
  const dependencies = originalExample(compiledInterfaces.snapshot.getFunction("dependencies").outputs[0]);
  const receipt = originalExample(compiledInterfaces.snapshot.getFunction("snapshotRecord").outputs[1]);
  const documents = name => [...fixture.sourceTexts["smart-contracts/domains/finality/" + name + ".sol"]
    .matchAll(/return bytes\(\s*'([^']+)'/g)].map(m => keccak256(Buffer.from(m[1], "utf8")));
  const [outputSchema, outputCanon, leafSchema] = documents("StreamScopedPolicyOutputSchemasV2");
  const [rootSchema, rootCanon] = documents("StreamScopedPolicyContentRootSchemasV2");
  const expected = {
    profileId: id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2"),
    outputManifest: dependencies.targets[8], outputManifestCodeHash: dependencies.codeHashes[8],
    checkpoint: dependencies.targets[7], checkpointCodeHash: dependencies.codeHashes[7],
    checkpointHash: source.outputs.checkpointHash, checkpointStateHash: source.outputs.checkpointStateHash,
    entropySourceSet: dependencies.targets[10], entropySourceSetCodeHash: dependencies.codeHashes[10],
    inventoryHash: source.outputs.inventoryHash, policyChainHash: source.outputs.policyChainHash, outputRoot: source.outputs.outputRoot,
    outputSchemaHash: outputSchema, outputCanonicalizationHash: outputCanon, leafSchemaHash: leafSchema,
    rootSchemaHash: rootSchema, rootCanonicalizationHash: rootCanon,
    sourceFactory: source.sourceFactory, sourceFactoryCodeHash: source.sourceFactoryCodeHash,
    factoryDependenciesHash: source.factoryDependenciesHash, snapshotSchemaHash: receipt.schemaHash,
    snapshotProfileHash: receipt.profileHash, snapshotCanonicalizationHash: receipt.canonicalizationHash,
  };
  assert.deepEqual(p.scopedPolicyRootV2BindingFromSnapshot(dependencies, source, receipt), expected);
  const type = compiledInterfaces.router.getFunction("scopedPolicyContentRootBinding").outputs[0];
  assert.equal(p.encodeScopedPolicyRootV2Binding(expected), originalCoder.encode([type], [expected]));
});

test("closed call planners encode only actual original Router publication and Artist consent", async () => {
  const p = await import("../dist/current-scoped-policy-root-v2.js");
  const c = exampleCoordinates(), publisher = exampleAddress(50), signer = exampleAddress(51);
  const publication = { scope: exampleScope(), expectedPredecessor: exampleHash(400), snapshotRecordHash: exampleHash(401),
    snapshotRevision: (1n << 63n) + 1n, manifestURI: "ipfs://root/作品" };
  const root = p.prepareScopedPolicyRootV2Call(c, publisher, { kind: "publishScopedPolicyContentRootPublication", publication });
  assert.deepEqual(root.call, { to: c.router, value: 0n,
    data: compiledInterfaces.router.encodeFunctionData("publishScopedPolicyContentRootPublication", [publication]) });
  assert.equal(root.factsVerified, false);
  const terms = { collectionId: publication.scope.collectionId, metadataContract: c.router, familyId: id("CONTENT_ROOT"), newStateHash: exampleHash(402) };
  const authorization = { nonce: 0n, deadline: (1n << 63n) + 70n, signature: "0x" };
  const request = { kind: "recordContentConsent", collectionId: terms.collectionId, newFamilyStateHash: terms.newStateHash,
    signer, authorityClass: 1n, authorization };
  const consent = p.prepareScopedPolicyRootV2Call(c, publisher, request);
  assert.deepEqual(consent.call, { to: c.artistRegistry, value: 0n,
    data: compiledInterfaces.artist.encodeFunctionData("recordContentConsent", [terms,
      { nonce: authorization.nonce, time: authorization.deadline, signature: authorization.signature }]) });
  assert.equal(consent.consent.direct, false); // Empty ERC-1271 signatures may be relayed.
  assert.equal(p.prepareScopedPolicyRootV2Call(c, signer, request).consent.direct, true);
  assert.equal(consent.factsVerified, false);
  assert.throws(() => p.normalizeScopedPolicyRootV2Call({ ...consent, call: { ...consent.call, value: 1n } }));
  assert.throws(() => p.prepareScopedPolicyRootV2Call(c, publisher, { ...request, authorityClass: 4n }));
  assert.throws(() => p.prepareScopedPolicyRootV2Call(c, publisher, { kind: "lockSnapshot", scope: publication.scope }));
});
