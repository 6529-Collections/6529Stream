import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, sha256, toUtf8Bytes } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledInterfaces, compiledLibraryEvents } from "./current-scoped-policy-inventory-archive-v2-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const fields = tuple => tuple.components.map(p => [p.name, p.type]);
const words = type => type.baseType === "tuple"
  ? type.components.reduce((n, p) => n + words(p), 0)
  : type.baseType === "array" ? type.arrayLength * words(type.arrayChildren) : 1;

test("scoped inventory/archive witness retains the exact ABI129 committed source and evidence boundary", () => {
  assert.equal(fixture.profile, "scoped-policy-inventory-archive-v2");
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
  assert.match(fixture.qualification, /original scoped render-critical inventory and bundle archive coverage/);
  assert.match(fixture.qualification, /native\/Safe execution.*remain separate/);
});

test("all ordinary contract and interface selectors retain complete compiler ABIs", () => {
  assert.equal(Object.keys(fixture.abis).length, 141);
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 4403);
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
  assert.equal(selectors, 2944);
});

test("nominal fixed deployment and reader libraries stay separate from wallet calls", () => {
  assert.equal(Object.keys(fixture.libraryAbis).length, 66);
  assert.equal(Object.values(fixture.libraryAbis).reduce((n, a) => n + a.length, 0), 276);
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
  assert.equal(count, 171);
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
  assert.equal(visited.size, 1305);
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, text) => n + Buffer.byteLength(text), 0), 8796175);
});

test("original documents retain scope and acyclic preparation/publication boundaries", () => {
  assert.equal(Object.keys(fixture.documents).length, 61);
  let size = 0;
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
    size += document.byteLength;
  }
  assert.equal(size, 855933);
  const preservation = fixture.documents["docs/integrations/scoped-policy-preservation-v2.md"].text;
  assert.match(preservation, /TOKEN, RELEASE and SEASON/);
  assert.match(preservation, /does not require a snapshot, root,\nreference or inventory publication/);
  assert.match(fixture.documents["docs/integrations/scoped-policy-finality-v2.md"].text,
    /absent scoped head or completely empty V2 binding retains original scoped V1/);
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
    if (ts.isAsExpression(node) || ts.isSatisfiesExpression(node) || ts.isParenthesizedExpression(node)) return value(node.expression, locals);
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isNumericLiteral(node)) return Number(node.text);
    if (ts.isObjectLiteralExpression(node)) return Object.fromEntries(node.properties.map(property => {
      assert.ok(ts.isPropertyAssignment(property), "literal object property");
      return [property.name.text, value(property.initializer, locals)];
    }));
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

test("inventory/archive fixture preserves every earlier original reference witness byte", () => {
  const earlier = JSON.parse(readFileSync(new URL("./fixtures/current-scoped-policy-reference-v2-abi.json", import.meta.url), "utf8"));
  for (const field of ["selections", "abis", "methodIdentifiers", "librarySelections", "libraryAbis",
    "libraryMethodIdentifiers", "sourceTexts", "sourceHashes", "documents"]) {
    for (const [key, value] of Object.entries(earlier[field])) assert.deepEqual(fixture[field][key], value, field + "/" + key);
  }
  assert.equal(fixture.selections.rendererRegistry.contract, "IStreamRendererRegistry");
  assert.equal(fixture.selections.rendererRegistryHost.contract, "StreamRendererRegistry");
  assert.equal(fixture.selections.referenceInventoryPreparation.contract, "IStreamReferenceInventoryPreparation");
  assert.equal(fixture.librarySelections.referenceInventoryPreparationLibrary.contract, "StreamReferenceInventoryPreparation");
});

const inventorySelectors = {
  appendDefinition: "f557eeda", appendIntent: "b04dc617", appendIntentWaiver: "1d8e209d",
  appendInterview: "4a983e5d", appendInterviewWaiver: "f8f51cc6", appendNative: "90742055",
  appendReference: "d4dabeb0", appendRights: "b43cf842", appendRootAuthorization: "a5837274",
  appendTokenCitation: "74f15779", appendTokenLibrary: "0fd43083", appendTokenOutput: "9af3be6b",
  appendTokenRenderer: "ccad8c6f", appendTokenScript: "b3c9ff7c", appendWork: "7f2fc51b",
  beginInventory: "4f9f5425", sealInventory: "c8ede19d",
};
const bundleSelectors = {
  beginCoverage: "006b6787", coverEmptySegment: "519ab176", coverNext: "0acda76b",
  beginRefresh: "6f16bed8", refreshNext: "bd6c7ccb",
};

test("the original two hosts expose exactly seventeen inventory and five archive writes", () => {
  for (const [key, expected] of [["inventory", inventorySelectors], ["bundle", bundleSelectors]]) {
    const original = compiledInterfaces[key];
    const writes = original.fragments.filter(f => f.type === "function" && !["pure", "view"].includes(f.stateMutability));
    assert.deepEqual(writes.map(f => f.name).sort(), Object.keys(expected).sort());
    for (const [name, selector] of Object.entries(expected)) {
      const f = original.getFunction(name);
      assert.equal(f.stateMutability, "nonpayable");
      assert.equal(f.selector, "0x" + selector);
      assert.equal(fixture.methodIdentifiers[key][f.format("sighash")], selector);
    }
  }
  assert.equal(compiledInterfaces.inventory.getFunction("inventoryItem"), null);
  assert.equal(compiledInterfaces.inventory.getFunction("currentPlan"), null);
  const event = compiledInterfaces.inventory.getEvent("ScopedInventorySegmentRecorded");
  assert.deepEqual(event.inputs.map(p => [p.name, p.type, Boolean(p.indexed)]), [
    ["schemaVersion", "uint16", false], ["id", "bytes32", true], ["index", "uint64", true],
    ["segment", "tuple", false], ["items", "tuple[]", false],
  ]);
  sameFields([event.inputs[3]], [compiledInterfaces.inventory.getFunction("inventorySegment").outputs[0]], "stored segment");
  sameFields([event.inputs[4].arrayChildren], [compiledInterfaces.bundle.getFunction("coverNext").inputs[1]], "item crossing hosts");
});

test("original dependency rosters, complete scopes and narrow progress fields remain distinct", () => {
  const inventory = compiledInterfaces.inventory, bundle = compiledInterfaces.bundle;
  assert.deepEqual(fields(inventory.getFunction("dependencies").outputs[0]), [
    ["targets", "address[12]"], ["codeHashes", "bytes32[12]"], ["artistTargets", "address[5]"],
    ["artistCodeHashes", "bytes32[5]"], ["artistContentOwner", "address"], ["artistContentOwnerCodeHash", "bytes32"],
    ["chainId", "uint256"], ["readGas", "uint256"], ["sourceGas", "uint256"], ["selectionGas", "uint256"],
    ["snapshotGas", "uint256"], ["referenceGas", "uint256"],
  ]);
  assert.deepEqual(fields(bundle.getFunction("dependencies").outputs[0]), [
    ["targets", "address[6]"], ["codeHashes", "bytes32[6]"], ["chainId", "uint256"],
    ["readGas", "uint256"], ["archiveGas", "uint256"],
  ]);
  assert.deepEqual(fields(inventory.getFunction("tokenProgress").outputs[0]), [
    ["phase", "uint8"], ["row", "uint64"], ["count", "uint64"],
  ]);
  const evidence = inventory.getFunction("inventoryEvidence").outputs[0];
  assert.equal(words(evidence) * 32, 736);
  assert.deepEqual(fields(evidence), [["scope", "tuple"], ["inventory", "tuple"]]);
  const coverage = bundle.getFunction("bundleEvidence").outputs[0];
  assert.deepEqual(fields(coverage), [["scope", "tuple"], ["coverage", "tuple"]]);
  sameFields([evidence.components[0]], [coverage.components[0]], "full inventory/bundle scope");
  assert.equal(inventory.getFunction("sourceContext").outputs[0].components.length, 17);
  assert.equal(inventory.getFunction("plan").outputs[0].components.length, 6);
});

function sourceNamed(name) {
  const matches = Object.entries(fixture.sourceTexts).filter(([path]) => path.endsWith("/" + name + ".sol"));
  assert.equal(matches.length, 1, name);
  return matches[0][1];
}

// Read the original Solidity constants and document literals independently of
// the client table. Exact registered bytes have no synthesized final newline.
function originalDefinitions() {
  const records = [];
  function fixed(name, prefix, path) {
    const source = sourceNamed(name);
    const identity = new RegExp(prefix + '_ID\\s*=\\s*keccak256\\("([^\"]+)"\\)').exec(source)?.[1];
    let hash = new RegExp(prefix + "_HASH\\s*=\\s*(0x[0-9a-f]{64})").exec(source)?.[1];
    let sourceDocument;
    if (!hash) {
      const literal = new RegExp(prefix + '_DOCUMENT\\s*=\\s*("(?:\\\\.|[^"\\\\])*")\\s*;').exec(source)?.[1];
      assert.ok(literal, name + "/" + prefix + " exact document literal");
      sourceDocument = JSON.parse(literal);
      assert.match(source, new RegExp(prefix + "_HASH\\s*=\\s*keccak256\\(bytes\\(" + prefix + "_DOCUMENT\\)\\)"));
      hash = keccak256(toUtf8Bytes(sourceDocument));
    }
    const length = Number(new RegExp(prefix + "_BYTES\\s*=\\s*(\\d+)").exec(source)?.[1]);
    assert.ok(identity && hash && length, name + "/" + prefix);
    const doc = fixture.documents[path ?? "schemas/records/" + identity + ".json"];
    assert.ok(doc, identity);
    if (sourceDocument !== undefined) assert.equal(doc.text, sourceDocument);
    assert.equal(doc.byteLength, length);
    assert.equal(keccak256(toUtf8Bytes(doc.text)), hash);
    records.push({ name: identity, id: id(identity), hash, length, bytes: doc.text });
  }
  for (const prefix of ["SCHEMA", "PROFILE", "CATALOG_SCHEMA", "CATALOG_PROFILE"]) fixed("StreamWorkRecordDefinitions", prefix);
  for (const prefix of ["SCHEMA", "PROFILE"]) fixed("StreamRightsRecordDefinitions", prefix);
  for (const prefix of ["INTENT_SCHEMA", "INTENT_PROFILE", "WAIVER_SCHEMA", "WAIVER_PROFILE",
    "INTERVIEW_SCHEMA", "INTERVIEW_PROFILE", "CATALOG_SCHEMA", "CATALOG_PROFILE"]) fixed("StreamConservationDefinitions", prefix);
  for (const prefix of ["ENVIRONMENT_SCHEMA", "PNG_SCHEMA", "ZIP_SCHEMA", "FORMAT_CATALOG"]) fixed("StreamReferenceRenderDefinitions", prefix);
  fixed("StreamSnapshotDefinitions", "CANON", "schemas/museum/account-profile/RFC8785_JCS.json");
  const raw = fixture.documents["schemas/museum/genesis/RAW_BYTES.json"];
  const literal = /bytes\(\s*'([^']+)'\s*\)/.exec(sourceNamed("StreamPreservationDocumentReads"))[1];
  assert.equal(raw.text, literal);
  records.push({ name: "RAW_BYTES", id: id("RAW_BYTES"), hash: keccak256(toUtf8Bytes(raw.text)), length: raw.byteLength, bytes: raw.text });
  for (const kind of ["Snapshot", "Reference"]) {
    for (const [prefix, suffix] of [["SCHEMA", "schema"], ["PROFILE", "profile"], ["CANON", "abi"]]) {
      fixed("StreamScopedPolicy" + kind + "DefinitionsV2", prefix,
        "docs/schemas/preservation/scoped-policy-" + kind.toLowerCase() + "-v2." + suffix + ".json");
    }
  }
  for (const [name, prefixes] of [["StreamScopedPolicyOutputSchemasV2", ["SCHEMA", "CANON", "LEAF_SCHEMA"]],
    ["StreamScopedPolicyContentRootSchemasV2", ["ROOT_SCHEMA", "ROOT_CANON"]]]) {
    const source = sourceNamed(name);
    for (const prefix of prefixes) {
      const identity = new RegExp(prefix + '\\s*=\\s*keccak256\\("([^\"]+)"\\)').exec(source)[1];
      const text = new RegExp('if \\(id == ' + prefix + '\\) \\{\\s*return bytes\\(\\s*\'([^\']+)\'\\s*\\);').exec(source)[1];
      assert.equal(JSON.parse(text).name, identity);
      records.push({ name: identity, id: id(identity), hash: keccak256(toUtf8Bytes(text)), length: Buffer.byteLength(text), bytes: text });
    }
  }
  return records;
}

test("all thirty-one ordered fixed definitions retain their exact original bytes and source hashes", () => {
  const rows = originalDefinitions();
  assert.equal(rows.length, 31);
  assert.equal(new Set(rows.map(row => row.id)).size, 31);
  for (const row of [...rows.slice(0, 14), ...rows.slice(18, 23), ...rows.slice(26)]) {
    assert.ok(!row.bytes.endsWith("\n"), row.name);
  }
  assert.equal(rows[20].name, "STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2");
  assert.equal(rows[23].name, "STREAM_SCOPED_POLICY_REFERENCE_ABI_V2");
  assert.deepEqual(rows.slice(26).map(row => row.length), [1608, 1062, 816, 1856, 1373]);
  assert.equal(rows[23].length, 26018);
  assert.match(sourceNamed("StreamScopedPolicyRenderCriticalDefinitionsV2"), /COUNT = 31/);
  assert.match(sourceNamed("StreamScopedPolicyRenderCriticalDefinitionsV2"), /i < 14/);
  assert.match(sourceNamed("StreamScopedPolicyRenderCriticalDefinitionsV2"), /Documents.fixedId\(i \+ 6\)/);
});

function ordinaryValueType(raw) {
  let type = raw.type;
  if (raw.internalType?.startsWith("enum ")) {
    const matches = [];
    function collect(param) {
      if (param.internalType === raw.internalType) matches.push(param.type);
      for (const nested of param.components ?? []) collect(nested);
    }
    for (const abi of Object.values(fixture.abis)) for (const fragment of abi) {
      for (const param of [...(fragment.inputs ?? []), ...(fragment.outputs ?? [])]) collect(param);
    }
    assert.ok(matches.length > 0, raw.internalType + " ordinary compiler width witness");
    assert.deepEqual([...new Set(matches)], ["uint8"]);
    type = "uint8";
  }
  return ParamType.from({ ...raw, type, components: raw.components?.map(ordinaryValueType) });
}

const inventoryReadWorkers = {
  sourceCurrent: ["scopedPolicyRenderCriticalSourceReadsV2", "current"],
  sourceReference: ["scopedPolicyRenderCriticalSourceReadsV2", "referenceBindings"],
  sourceSnapshot: ["scopedPolicyRenderCriticalSourceReadsV2", "snapshotBindings"],
  nativeItems: ["scopedPolicyRenderCriticalNativeReadsV2", "items"],
  referenceItems: ["scopedPolicyReferenceInventoryReadsV2", "items"],
  work: ["preservationTypedReferences", "work"], rights: ["preservationTypedReferences", "rights"],
  intent: ["preservationTypedReferences", "intent"], waiver: ["preservationTypedReferences", "waiver"],
  interview: ["preservationTypedReferences", "interview"], originals: ["preservationOriginalReads", "items"],
  artist: ["preservationArtistBundleReads", "item"], document: ["preservationDocumentReads", "item"],
  catalogs: ["preservationDocumentReads", "authenticateCatalogs"], documentFacts: ["preservationDocumentReads", "currentFactsHash"],
  root: ["scopedPolicyRenderCriticalRootAuthorizationV2", "contentItem"],
  token: ["scopedPolicyRenderCriticalTokenReadsV2", "tokenItems"], script: ["scopedPolicyRenderCriticalScriptReadsV2", "items"],
  renderer: ["scopedPolicyRenderCriticalRendererReadsV2", "item"], citation: ["scopedPolicyRenderCriticalCitationReadsV2", "item"],
};

function workerParity(descriptors, expected) {
  assert.deepEqual(Object.keys(descriptors).sort(), Object.keys(expected).sort());
  for (const [name, [key, method]] of Object.entries(expected)) {
    const methods = fixture.libraryAbis[key].filter(f => f.type === "function" && f.name === method);
    assert.equal(methods.length, 1, name);
    const original = methods[0];
    assert.ok(["view", "pure"].includes(original.stateMutability), name + " read-only");
    assert.ok(original.inputs.every(p => !p.internalType.includes(" storage")), name + " no storage reference");
    const ids = Object.entries(fixture.libraryMethodIdentifiers[key]).filter(([s]) => s.startsWith(method + "("));
    assert.equal(ids.length, 1, name + " exact nominal selector");
    const descriptor = descriptors[name];
    assert.equal(descriptor.selector, "0x" + ids[0][1]);
    sameFields(descriptor.inputs.map(ParamType.from), original.inputs.map(ordinaryValueType), name + " inputs");
    sameFields(descriptor.outputs.map(ParamType.from), original.outputs.map(ordinaryValueType), name + " outputs");
  }
}

test("inventory read workers keep original nominal selectors and complete compiler value encodings", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-inventory-v2-workflow.ts", import.meta.url));
  workerParity(read("workers"), inventoryReadWorkers);
});

test("inventory pure tuples retain the original complete nested compiler shapes", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-inventory-v2.ts", import.meta.url));
  const abi = compiledInterfaces.inventory, bundle = compiledInterfaces.bundle;
  const context = abi.getFunction("sourceContext").outputs[0];
  const evidence = abi.getFunction("inventoryEvidence").outputs[0];
  const tuples = {
    DEPENDENCIES: abi.getFunction("dependencies").outputs[0], ITEM: bundle.getFunction("coverNext").inputs[1],
    SEGMENT: abi.getFunction("inventorySegment").outputs[0], PLAN: abi.getFunction("plan").outputs[0],
    PROGRESS: abi.getFunction("plan").outputs[0].components[1], TOKEN_PROGRESS: abi.getFunction("tokenProgress").outputs[0],
    EVIDENCE: evidence, ORIGINAL_EVIDENCE: evidence.components[1],
    ORIGINAL_INPUTS: evidence.components[1].components.find(p => p.name === "originals"), CONTEXT: context,
    WORK: abi.getFunction("appendWork").inputs[1], RIGHTS: abi.getFunction("appendRights").inputs[1],
    INTENT: abi.getFunction("appendIntent").inputs[1], INTENT_WAIVER: abi.getFunction("appendIntentWaiver").inputs[1],
    INTERVIEW: abi.getFunction("appendInterview").inputs[1], PAYLOAD: abi.getFunction("appendTokenOutput").inputs[1],
    DOCUMENT_FACTS: compiledInterfaces.schemaDocumentFacts.getFunction("documentFacts").outputs[0],
    SCOPE: evidence.components[0], AGGREGATE: abi.getFunction("appendRootAuthorization").inputs[3],
  };
  for (const [suffix, original] of Object.entries(tuples)) {
    const constant = "SCOPED_POLICY_INVENTORY_V2_" + suffix + "_TUPLE";
    sameFields([ParamType.from(read(constant))], [original], constant);
  }
});

test("the inventory public ABI and own ERC165 identity match the original declared interface", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-inventory-v2.ts", import.meta.url));
  const actual = new Interface(read("SCOPED_POLICY_INVENTORY_V2_ABI"));
  for (const fragment of actual.fragments) {
    const original = fragment.type === "event" ? compiledInterfaces.inventory.getEvent(fragment.format("sighash"))
      : fragment.type === "error" ? Object.values(compiledInterfaces).map(i => i.getError(fragment.format("sighash"))).find(Boolean)
      : compiledInterfaces.inventory.getFunction(fragment.format("sighash"));
    assert.ok(original, fragment.format("sighash"));
    compatibleFragment(fragment, original);
  }
  assert.deepEqual(actual.fragments.filter(f => f.type === "function" && f.stateMutability === "nonpayable")
    .map(f => f.name).sort(), Object.keys(inventorySelectors).sort());
  const original = fixture.sourceTexts[fixture.selections.inventoryInterface.source];
  const names = [...original.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(match => match[1]);
  assert.ok(!names.includes("supportsInterface"));
  const interfaceId = names.reduce((v, name) => v ^ BigInt(compiledInterfaces.inventoryInterface.getFunction(name).selector), 0n);
  assert.equal(read("SCOPED_POLICY_INVENTORY_V2_INTERFACE_ID"), "0x" + interfaceId.toString(16).padStart(8, "0"));
});

const coder = AbiCoder.defaultAbiCoder();
const abiHash = (types, values) => keccak256(coder.encode(types, values));
const address = n => getAddress("0x" + BigInt(n).toString(16).padStart(40, "0"));
const hash = n => "0x" + BigInt(n).toString(16).padStart(64, "0");
function sample(type, counter = { n: 10 }) {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(p => [p.name, sample(p, counter)]));
  if (type.baseType === "array") return Array.from({ length: type.arrayLength < 0 ? 2 : type.arrayLength }, () => sample(type.arrayChildren, counter));
  const n = ++counter.n;
  if (type.type === "address") return address(n);
  if (type.type === "bool") return n % 2 === 0;
  if (type.type === "string") return "original inventory 作品 " + n;
  if (type.type === "bytes") return hash(n);
  if (type.type.startsWith("bytes")) return "0x" + n.toString(16).padStart(Number(type.type.slice(5)) * 2, "0");
  if (type.type.startsWith("uint")) {
    const width = Number(type.type.slice(4));
    return width === 8 ? 1n : width >= 128 ? (1n << 130n) + BigInt(n) : BigInt(n);
  }
  throw Error("Unhandled compiler value " + type.type);
}
const coordinates = () => ({ chainId: (1n << 131n) + 6529n, core: address(1), inventory: address(2) });

test("inventory context and plan hashes use complete original ABI preimages and actual host coordinates", async () => {
  const p = await import("../dist/current-scoped-policy-inventory-v2.js");
  const type = compiledInterfaces.inventory.getFunction("sourceContext").outputs[0], context = sample(type);
  const dType = compiledInterfaces.inventory.getFunction("dependencies").outputs[0], dependencies = sample(dType);
  const c = coordinates();
  const dHash = abiHash([dType], [dependencies]);
  assert.equal(p.scopedPolicyInventoryV2DependencyHash(dependencies), dHash);
  assert.equal(p.scopedPolicyInventoryV2ContextHash(context), abiHash([type], [context]));
  const plan = abiHash(["bytes32", "uint256", "address", "bytes32", type],
    [id("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_PLAN_V2"), c.chainId, c.inventory, dHash, context]);
  assert.equal(p.scopedPolicyInventoryV2PlanId(c, dHash, context), plan);
  for (const field of ["rootRecordHash", "tokenInventoryHash", "checkpointHash", "outputManifestRecord", "selectionHash"]) {
    assert.notEqual(p.scopedPolicyInventoryV2PlanId(c, dHash, { ...context, [field]: hash(999) }), plan);
  }
  const changed = structuredClone(context);
  changed.scope.collectionId += 1n;
  assert.notEqual(p.scopedPolicyInventoryV2PlanId(c, dHash, changed), plan);
  assert.notEqual(p.scopedPolicyInventoryV2PlanId({ ...c, inventory: address(3) }, dHash, context), plan);
  assert.notEqual(p.scopedPolicyInventoryV2PlanId({ ...c, chainId: c.chainId + 1n }, dHash, context), plan);
});

test("inventory links retain every role-qualified occurrence and the original backward terminator", async () => {
  const p = await import("../dist/current-scoped-policy-inventory-v2.js");
  const itemType = compiledInterfaces.bundle.getFunction("coverNext").inputs[1];
  const segmentType = compiledInterfaces.inventory.getFunction("inventorySegment").outputs[0];
  const row = sample(itemType), second = { ...row, role: hash(500) }, planId = hash(501), at = (1n << 63n) + 3n;
  const key = abiHash(["bytes32", "bytes32", "uint64"], [id("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_SEGMENT_V2"), planId, at]);
  assert.equal(p.scopedPolicyInventoryV2SegmentKey(planId, at), key);
  const itemHash = value => abiHash(["bytes32", itemType], [id("6529STREAM_PRESERVATION_ITEM_V1"), value]);
  assert.equal(p.scopedPolicyInventoryV2ItemHash(row), itemHash(row));
  assert.notEqual(itemHash(row), itemHash(second));
  const link = (index, value, next) => abiHash(["bytes32", "bytes32", "uint64", "uint64", "bytes32", "bytes32"],
    [id("6529STREAM_PRESERVATION_ITEM_LINK_V1"), key, 3n, index, itemHash(value), next]);
  const last = link(2n, row, ZeroHash), middle = link(1n, second, last), first = link(0n, row, middle);
  const expected = { key, itemCount: 3n, firstLink: first, sourceWitnessHash: hash(502) };
  assert.deepEqual(p.scopedPolicyInventoryV2Segment(key, hash(502), [row, second, row]), expected);
  assert.equal(p.scopedPolicyInventoryV2Link(key, 3n, 2n, row, ZeroHash), last);
  assert.equal(p.scopedPolicyInventoryV2AppendSegment(hash(503), at, expected), abiHash(
    ["bytes32", "bytes32", "uint64", segmentType], [id("6529STREAM_PRESERVATION_SEGMENT_V1"), hash(503), at, expected]));
  assert.deepEqual(p.scopedPolicyInventoryV2Segment(key, hash(502), []),
    { key, itemCount: 0n, firstLink: ZeroHash, sourceWitnessHash: hash(502) });
  assert.throws(() => p.scopedPolicyInventoryV2Link(key, 3n, 0n, row, ZeroHash));
  assert.throws(() => p.scopedPolicyInventoryV2Link(key, 3n, 2n, row, hash(504)));
  assert.throws(() => p.scopedPolicyInventoryV2SegmentKey(planId, 1n << 64n));
});

test("inventory evidence clears only its own hash and commits the entire 736-byte scoped tuple", async () => {
  const p = await import("../dist/current-scoped-policy-inventory-v2.js");
  const type = compiledInterfaces.inventory.getFunction("inventoryEvidence").outputs[0], evidence = sample(type);
  const c = coordinates(), dependency = hash(601);
  const cleared = { ...evidence, inventory: { ...evidence.inventory, renderCriticalEvidenceHash: ZeroHash } };
  const expected = abiHash(["bytes32", "uint256", "address", "bytes32", type],
    [id("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_EVIDENCE_V2"), c.chainId, c.inventory, dependency, cleared]);
  assert.equal(p.scopedPolicyInventoryV2EvidenceHash(c, dependency, evidence), expected);
  assert.equal(p.scopedPolicyInventoryV2EvidenceHash(c, dependency,
    { ...evidence, inventory: { ...evidence.inventory, renderCriticalEvidenceHash: hash(602) } }), expected);
  for (const field of ["planId", "scopeSubject", "sourceContextHash", "tokenInventoryHash", "segmentChainHash"]) {
    assert.notEqual(p.scopedPolicyInventoryV2EvidenceHash(c, dependency,
      { ...evidence, inventory: { ...evidence.inventory, [field]: hash(603) } }), expected);
  }
  assert.notEqual(p.scopedPolicyInventoryV2EvidenceHash(c, dependency,
    { ...evidence, scope: { ...evidence.scope, collectionId: evidence.scope.collectionId + 1n } }), expected);
  const encoded = coder.encode([type], [evidence]);
  assert.equal((encoded.length - 2) / 2, 736);
  assert.equal(p.encodeScopedPolicyInventoryV2Evidence(evidence), encoded);
  assert.deepEqual(p.decodeScopedPolicyInventoryV2Evidence(encoded), evidence);
  assert.throws(() => p.decodeScopedPolicyInventoryV2Evidence(encoded + "00".repeat(32)));
});

test("token and page source witnesses preserve uint64 ordinals and the uint8 phase", async () => {
  const p = await import("../dist/current-scoped-policy-inventory-v2.js");
  const n = (1n << 63n) + 5n;
  assert.equal(p.scopedPolicyInventoryV2TokenWitness(hash(701), hash(702), n, 4n, n + 1n, n + 2n), abiHash(
    ["bytes32", "bytes32", "bytes32", "uint64", "uint8", "uint64", "uint64"],
    [id("6529STREAM_SCOPED_POLICY_TOKEN_INVENTORY_SOURCE_V2"), hash(701), hash(702), n, 4n, n + 1n, n + 2n]));
  assert.equal(p.scopedPolicyInventoryV2CursorWitness(hash(703), n, n + 1n),
    abiHash(["bytes32", "uint64", "uint64"], [hash(703), n, n + 1n]));
  assert.throws(() => p.scopedPolicyInventoryV2TokenWitness(hash(701), hash(702), n, 256n, 0n, 0n));
});

test("the client definition table matches all thirty-one original definitions without byte normalization", async () => {
  const p = await import("../dist/current-scoped-policy-inventory-v2.js");
  const expected = originalDefinitions(), actual = p.SCOPED_POLICY_INVENTORY_V2_DEFINITIONS;
  assert.equal(actual.length, 31);
  for (let i = 0; i < expected.length; i++) {
    const e = expected[i], a = actual[i];
    assert.equal(a.index, BigInt(i));
    assert.equal(a.name, e.name);
    assert.equal(a.id, e.id);
    assert.equal(a.contentHash, e.hash);
    assert.equal(a.byteLength, BigInt(e.length));
    assert.ok(Object.hasOwn(fixture.sourceTexts, a.sourcePath));
    if (i < 26) assert.equal(fixture.documents[a.documentPath]?.text, e.bytes);
    else assert.equal(a.literal, "0x" + Buffer.from(e.bytes).toString("hex"));
  }
});

test("bundle pure tuples retain full original admissions, proof branches and scoped evidence", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-bundle-v2.ts", import.meta.url));
  const abi = compiledInterfaces.bundle;
  const admission = abi.getFunction("admittedItem").outputs[1];
  const evidence = abi.getFunction("bundleEvidence").outputs[0];
  const tuples = {
    DEPENDENCIES: abi.getFunction("dependencies").outputs[0], PROOF: abi.getFunction("coverNext").inputs[3],
    ADMISSION: admission, PROGRESS: abi.getFunction("progress").outputs[0], REFRESH: abi.getFunction("refresh").outputs[0],
    EVIDENCE: evidence, ORIGINAL_EVIDENCE: evidence.components[1],
    EXTERNAL_COVERAGE: admission.components.find(p => p.name === "externalOriginal"),
    ONCHAIN_COVERAGE: admission.components.find(p => p.name === "onchainOriginal"),
    ITEM: abi.getFunction("coverNext").inputs[1], SEGMENT: compiledInterfaces.inventory.getFunction("inventorySegment").outputs[0],
    SCOPE: evidence.components[0], ARTIFACT: compiledInterfaces.artifactCoverage.getFunction("artifact").outputs[0],
    OBJECT_IDENTITY: compiledInterfaces.externalCoverage.getFunction("objectIdentity").outputs[0],
    CURRENT_PAIR: compiledInterfaces.externalCurrentPair.getFunction("currentReceiptPair").outputs[0],
  };
  for (const [suffix, original] of Object.entries(tuples)) {
    const constant = "SCOPED_POLICY_BUNDLE_V2_" + suffix + "_TUPLE";
    sameFields([ParamType.from(read(constant))], [original], constant);
  }
});

test("the bundle public ABI and own ERC165 identity match the original declared interface", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-bundle-v2.ts", import.meta.url));
  const actual = new Interface(read("SCOPED_POLICY_BUNDLE_V2_ABI"));
  for (const fragment of actual.fragments) {
    const original = fragment.type === "event" ? compiledInterfaces.bundle.getEvent(fragment.format("sighash"))
      : fragment.type === "error" ? Object.values(compiledInterfaces).map(i => i.getError(fragment.format("sighash"))).find(Boolean)
      : compiledInterfaces.bundle.getFunction(fragment.format("sighash"));
    assert.ok(original, fragment.format("sighash"));
    compatibleFragment(fragment, original);
  }
  assert.deepEqual(actual.fragments.filter(f => f.type === "function" && f.stateMutability === "nonpayable")
    .map(f => f.name).sort(), Object.keys(bundleSelectors).sort());
  const original = fixture.sourceTexts[fixture.selections.bundleInterface.source];
  const names = [...original.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(match => match[1]);
  assert.ok(!names.includes("supportsInterface"));
  const interfaceId = names.reduce((v, name) => v ^ BigInt(compiledInterfaces.bundleInterface.getFunction(name).selector), 0n);
  assert.equal(read("SCOPED_POLICY_BUNDLE_V2_INTERFACE_ID"), "0x" + interfaceId.toString(16).padStart(8, "0"));
});

test("bundle read workers preserve original nominal selectors and full source value tuples", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-bundle-v2-workflow.ts", import.meta.url));
  workerParity(read("workers"), {
    environment: ["bundleArchiveReads", "environment"], admit: ["bundleArchiveReads", "admit"], current: ["bundleArchiveReads", "current"],
  });
});

test("the original archive environment commits all dependency fields and separate epoch/revision widths", async () => {
  const p = await import("../dist/current-scoped-policy-bundle-v2.js");
  const type = compiledInterfaces.bundle.getFunction("dependencies").outputs[0], d = sample(type);
  const epoch = (1n << 63n) + 11n;
  const expected = abiHash(["bytes32", type, "bytes32", "uint64", "bytes32", "uint64"],
    [id("6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1"), d, hash(801), epoch, hash(802), 0n]);
  assert.equal(p.scopedPolicyBundleV2DependencyHash(d), abiHash([type], [d]));
  assert.equal(p.scopedPolicyBundleV2EnvironmentHash(d, hash(801), epoch, hash(802), 0n), expected);
  for (const field of ["readGas", "archiveGas", "chainId"]) {
    assert.notEqual(p.scopedPolicyBundleV2EnvironmentHash({ ...d, [field]: d[field] + 1n }, hash(801), epoch, hash(802), 0n), expected);
  }
  for (let i = 0; i < 6; i++) {
    const changed = structuredClone(d);
    changed.codeHashes[i] = hash(810 + i);
    assert.notEqual(p.scopedPolicyBundleV2EnvironmentHash(changed, hash(801), epoch, hash(802), 0n), expected);
  }
  assert.throws(() => p.scopedPolicyBundleV2EnvironmentHash(d, hash(801), 0n, hash(802), 0n));
  assert.throws(() => p.scopedPolicyBundleV2EnvironmentHash(d, hash(801), epoch, hash(802), 1n << 64n));
});

test("bundle evidence binds the original complete inventory and clears only its own coverage hash", async () => {
  const p = await import("../dist/current-scoped-policy-bundle-v2.js");
  const type = compiledInterfaces.bundle.getFunction("bundleEvidence").outputs[0], evidence = sample(type);
  const inventoryType = compiledInterfaces.inventory.getFunction("inventoryEvidence").outputs[0], original = sample(inventoryType);
  const c = { chainId: coordinates().chainId, core: address(1), bundle: address(3) }, dependency = hash(901);
  const cleared = { ...evidence, coverage: { ...evidence.coverage, bundleCoverageHash: ZeroHash } };
  const expected = abiHash(["bytes32", "uint256", "address", "bytes32", "bytes32", inventoryType, type],
    [id("6529STREAM_SCOPED_POLICY_BUNDLE_ARCHIVE_COVERAGE_V2"), c.chainId, c.bundle, dependency,
      id("6529STREAM_SCOPED_POLICY_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V2"), original, cleared]);
  assert.equal(p.scopedPolicyBundleV2CoverageHash(c, dependency, original, evidence), expected);
  assert.equal(p.scopedPolicyBundleV2CoverageHash(c, dependency, original,
    { ...evidence, coverage: { ...evidence.coverage, bundleCoverageHash: hash(902) } }), expected);
  assert.notEqual(p.scopedPolicyBundleV2CoverageHash(c, dependency,
    { ...original, inventory: { ...original.inventory, renderCriticalEvidenceHash: hash(903) } }, evidence), expected);
  for (const field of ["renderCriticalEvidenceHash", "inventoryPlan", "evidenceChainHash"]) {
    assert.notEqual(p.scopedPolicyBundleV2CoverageHash(c, dependency, original,
      { ...evidence, coverage: { ...evidence.coverage, [field]: hash(904) } }), expected);
  }
  assert.notEqual(p.scopedPolicyBundleV2CoverageHash(c, dependency, original,
    { ...evidence, scope: { ...evidence.scope, collectionId: evidence.scope.collectionId + 1n } }), expected);
  assert.notEqual(p.scopedPolicyBundleV2CoverageHash({ ...c, bundle: address(4) }, dependency, original, evidence), expected);
});

test("bundle item and observation chains retain full original admission and global uint64 order", async () => {
  const p = await import("../dist/current-scoped-policy-bundle-v2.js");
  const type = compiledInterfaces.bundle.getFunction("admittedItem").outputs[1], admission = sample(type);
  const index = (1n << 63n) + 12n;
  const expected = abiHash(["bytes32", "bytes32", "bytes32", "uint64", "bytes32", type],
    [id("6529STREAM_SCOPED_POLICY_BUNDLE_COVERED_ITEM_V2"), hash(1001), hash(1002), index, hash(1003), admission]);
  assert.equal(p.scopedPolicyBundleV2ItemChain(hash(1001), hash(1002), index, hash(1003), admission), expected);
  for (const branch of ["externalOriginal", "onchainOriginal"]) {
    const changed = structuredClone(admission), name = branch === "externalOriginal" ? "firstReceiptHash" : "evidenceChainHash";
    changed[branch][name] = hash(1004);
    assert.notEqual(p.scopedPolicyBundleV2ItemChain(hash(1001), hash(1002), index, hash(1003), changed), expected);
  }
  assert.equal(p.scopedPolicyBundleV2ObservationChain(hash(1005), index, hash(1006), hash(1007)), abiHash(
    ["bytes32", "bytes32", "uint64", "bytes32", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_BUNDLE_CURRENT_OBSERVATION_V2"), hash(1005), index, hash(1006), hash(1007)]));
  assert.throws(() => p.scopedPolicyBundleV2ObservationChain(hash(1005), 1n << 64n, hash(1006), hash(1007)));
});

test("bundle refresh identity binds actual host, chain, dependency hash, inventory plan and environment", async () => {
  const p = await import("../dist/current-scoped-policy-bundle-v2.js");
  const c = { chainId: coordinates().chainId, core: address(1), bundle: address(3) };
  const expected = abiHash(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_BUNDLE_REFRESH_V2"), c.chainId, c.bundle, hash(1101), hash(1102), hash(1103)]);
  assert.equal(p.scopedPolicyBundleV2RefreshId(c, hash(1101), hash(1102), hash(1103)), expected);
  assert.notEqual(p.scopedPolicyBundleV2RefreshId({ ...c, chainId: c.chainId + 1n }, hash(1101), hash(1102), hash(1103)), expected);
  assert.notEqual(p.scopedPolicyBundleV2RefreshId({ ...c, bundle: address(4) }, hash(1101), hash(1102), hash(1103)), expected);
  for (let i = 0; i < 3; i++) {
    const fields = [hash(1101), hash(1102), hash(1103)]; fields[i] = hash(1104);
    assert.notEqual(p.scopedPolicyBundleV2RefreshId(c, ...fields), expected);
  }
});

test("archive original-bundle and immutable-part preimages preserve complete compiler evidence", async () => {
  const p = await import("../dist/current-scoped-policy-bundle-v2.js");
  const dType = compiledInterfaces.bundle.getFunction("dependencies").outputs[0], d = sample(dType);
  const admission = compiledInterfaces.bundle.getFunction("admittedItem").outputs[1];
  const externalType = admission.components.find(c => c.name === "externalOriginal"), external = sample(externalType);
  const onchainType = admission.components.find(c => c.name === "onchainOriginal"), onchain = sample(onchainType);
  const artifactType = compiledInterfaces.artifactCoverage.getFunction("artifact").outputs[0], artifact = sample(artifactType);
  const originals = [hash(1201), hash(1202), hash(1203), hash(1204), hash(1205)];
  assert.equal(p.scopedPolicyBundleV2ExternalOriginalHash(d, external, originals), abiHash(
    ["address", "bytes32", externalType, "bytes32[5]"], [d.targets[4], d.codeHashes[4], external, originals]));
  assert.equal(p.scopedPolicyBundleV2OnchainOriginalHash(d, onchain, artifact, hash(1206), hash(1207)), abiHash(
    ["address", "bytes32", onchainType, artifactType, "bytes32", "bytes32"],
    [d.targets[3], d.codeHashes[3], onchain, artifact, hash(1206), hash(1207)]));
  const index = (1n << 31n) + 5n;
  assert.equal(p.scopedPolicyBundleV2PartChain(hash(1208), index, address(1210), hash(1211), hash(1212), 8192n), abiHash(
    ["bytes32", "uint32", "address", "bytes32", "bytes32", "uint32"],
    [hash(1208), index, address(1210), hash(1211), hash(1212), 8192n]));
  assert.equal(p.scopedPolicyBundleV2OriginalPartChain(hash(1213), index, hash(1214)), abiHash(
    ["bytes32", "uint32", "bytes32"], [hash(1213), index, hash(1214)]));
  assert.throws(() => p.scopedPolicyBundleV2PartChain(hash(1208), 1n << 32n, address(1210), hash(1211), hash(1212), 8192n));
});

test("current external pairs may refresh fixity while preserving both original receipt identities", async () => {
  const p = await import("../dist/current-scoped-policy-bundle-v2.js");
  const coverageType = compiledInterfaces.bundle.getFunction("admittedItem").outputs[1].components.find(c => c.name === "externalOriginal");
  const type = compiledInterfaces.externalCurrentPair.getFunction("currentReceiptPair").outputs[0], original = sample(coverageType);
  const pair = Object.fromEntries(type.components.map(c => [c.name, original[c.name]]));
  pair.firstFixityHash = hash(1301); pair.secondFixityHash = hash(1302);
  assert.equal(p.scopedPolicyBundleV2CurrentPairHash(original, pair), abiHash([type], [pair]));
  for (const field of ["objectHash", "firstReceiptHash", "secondReceiptHash", "checkpointHash", "profileHash"]) {
    assert.throws(() => p.scopedPolicyBundleV2CurrentPairHash(original, { ...pair, [field]: hash(1303) }));
  }
  assert.throws(() => p.scopedPolicyBundleV2CurrentPairHash(original, { ...pair, firstFixityHash: ZeroHash }));
  assert.notEqual(p.scopedPolicyBundleV2CurrentPairHash(original, pair),
    p.scopedPolicyBundleV2CurrentPairHash(original, { ...pair, firstFixityHash: hash(1304) }));
});

test("ordinary Work-selection and archive-environment reads preserve their own original producer ABIs", () => {
  const inventory = literalReader(new URL("../src/current-scoped-policy-inventory-v2-workflow.ts", import.meta.url));
  for (const fragment of new Interface(inventory("workAbi")).fragments) {
    compatibleFragment(fragment, compiledInterfaces.workSelection.getFunction(fragment.format("sighash")));
  }
  const bundle = literalReader(new URL("../src/current-scoped-policy-bundle-v2-workflow.ts", import.meta.url));
  for (const fragment of new Interface(bundle("environmentAbi")).fragments) {
    const source = fragment.name === "currentArtifactEnvironment" ? "artifactEnvironment" : "externalEnvironment";
    compatibleFragment(fragment, compiledInterfaces[source].getFunction(fragment.format("sighash")));
  }
});
