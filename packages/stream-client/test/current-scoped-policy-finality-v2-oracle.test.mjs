import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroHash, concat, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledInterfaces, compiledLibraryEvents } from "./current-scoped-policy-finality-v2-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const fields = tuple => tuple.components.map(p => [p.name, p.type]);

test("historical scoped finality witness retains the exact ABI129 committed source and evidence boundary", () => {
  assert.equal(fixture.profile, "scoped-policy-finality-v2");
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
  assert.match(fixture.qualification, /historical original ABI129 scoped-policy finality/);
  assert.match(fixture.qualification, /No actual native\/Safe execution/);
});

test("all ordinary contract and interface selectors retain complete compiler ABIs", () => {
  assert.equal(Object.keys(fixture.abis).length, 171);
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 5069);
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
  assert.equal(selectors, 3251);
});

test("nominal fixed deployment and reader libraries stay separate from wallet calls", () => {
  assert.equal(Object.keys(fixture.libraryAbis).length, 80);
  assert.equal(Object.values(fixture.libraryAbis).reduce((n, a) => n + a.length, 0), 458);
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
  assert.equal(count, 237);
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
  assert.equal(visited.size, 1326);
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, text) => n + Buffer.byteLength(text), 0), 9142073);
});

test("original documents retain scope and acyclic preparation/publication boundaries", () => {
  assert.equal(Object.keys(fixture.documents).length, 78);
  let size = 0;
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
    size += document.byteLength;
  }
  assert.equal(size, 1132105);
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
  if (type.type === "string") return "historical finality 作品 " + n;
  if (type.type === "bytes") return hash(n);
  if (type.type.startsWith("bytes")) return "0x" + n.toString(16).padStart(Number(type.type.slice(5)) * 2, "0");
  if (type.type.startsWith("uint")) {
    const width = Number(type.type.slice(4));
    return width === 8 ? 1n : width >= 128 ? (1n << 130n) + BigInt(n) : BigInt(n);
  }
  throw Error("Unhandled compiler value " + type.type);
}

test("finality fixture preserves every earlier inventory/archive witness byte", () => {
  const earlier = JSON.parse(readFileSync(new URL("./fixtures/current-scoped-policy-inventory-archive-v2-abi.json", import.meta.url), "utf8"));
  for (const field of ["selections", "abis", "methodIdentifiers", "librarySelections", "libraryAbis",
    "libraryMethodIdentifiers", "sourceTexts", "sourceHashes", "documents"]) {
    for (const [key, value] of Object.entries(earlier[field])) assert.deepEqual(fixture[field][key], value, field + "/" + key);
  }
  assert.equal(fixture.selections.currentRoute.contract, "IStreamFinalityCurrentEntropyRoute");
  assert.equal(fixture.selections.currentComponentRoutes.contract, "IStreamFinalityCurrentComponentRoutes");
});

function sourceNamed(name) {
  const paths = Object.keys(fixture.sourceTexts).filter(path => path.endsWith("/" + name + ".sol"));
  assert.equal(paths.length, 1, name);
  return fixture.sourceTexts[paths[0]];
}

function sourceFunction(source, name) {
  const at = source.search(new RegExp("\\bfunction\\s+" + name + "\\s*\\("));
  assert.notEqual(at, -1, name);
  const start = source.indexOf("{", at);
  assert.notEqual(start, -1, name + " body");
  let depth = 1, end = start + 1;
  while (end < source.length && depth) {
    if (source[end] === "{") depth++;
    if (source[end] === "}") depth--;
    end++;
  }
  assert.equal(depth, 0, name + " body closure");
  return source.slice(start + 1, end - 1);
}

const ownCapabilityIds = {
  finalityInterface: "0x47291ea1", canonicalFinality: "0xe06bf3bb", sanctionArchive: "0x53d07afe",
  scopeEvidence: "0xf57e9876", finalityProviderInterface: "0x83933c7a",
  preparedScopeEvidence: "0x343d8ac3", preparedSanctionReview: "0x9850674d", sanctionReview: "0x01859042",
  profileSources: "0xc4925e99", providerBinding: "0x266d0af8", contentRootBinding: "0x9ee19586",
  finalityDiscoveryInterface: "0xcdf740c0", scopedFinalityDiscoveryInterface: "0x3c79ba09",
  nonSanctionDiscovery: "0x3c43dd84", currentComponentRoutes: "0xb415e609", discoveryBinding: "0x19a8102d",
  finalityComponent: "0x1300f2d7", scopedFinalityComponentInterface: "0x8004d4f5",
};

test("original ERC165 capabilities include only selectors declared by each independent interface", () => {
  for (const [key, expected] of Object.entries(ownCapabilityIds)) {
    const selection = fixture.selections[key];
    const source = fixture.sourceTexts[selection.source].replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
    const match = source.match(new RegExp("\\binterface\\s+" + selection.contract + "\\b[^\\{]*\\{([\\s\\S]*?)\\n\\}"));
    assert.ok(match, selection.contract);
    const names = [...match[1].matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(m => m[1]);
    assert.ok(names.length, selection.contract);
    const methods = compiledInterfaces[key].fragments.filter(f => f.type === "function" && names.includes(f.name));
    assert.equal(methods.length, names.length, selection.contract);
    const xor = methods.reduce((value, method) => value ^ BigInt(method.selector), 0n);
    assert.equal("0x" + xor.toString(16).padStart(8, "0"), expected, selection.contract);
  }
});

test("provider and discovery are read-only and the retained Registry mutators keep exact original selectors", () => {
  for (const key of ["provider", "discovery"]) {
    assert.deepEqual(compiledInterfaces[key].fragments.filter(f => f.type === "function"
      && !["view", "pure"].includes(f.stateMutability)), []);
  }
  const actual = compiledInterfaces.finality.fragments.filter(f => f.type === "function"
    && !["view", "pure"].includes(f.stateMutability));
  const expected = {
    cancelArtworkTerminalFreeze: "0x4d7bbf4a", finalizeArtworkScope: "0xcd2a94a8",
    finalizeArtworkScopeWithArchive: "0xa09b64ca", finalizeCollectionArtwork: "0x53742883",
    finalizeCollectionArtworkWithArchive: "0x06812c19", materializeExpiredArtworkTerminalFreeze: "0xf1205ba2",
    raiseGasParameter: "0x5c0df7da", scheduleArtworkTerminalFreeze: "0xc6f1fbda",
    stageFinalityManifest: "0x58490e22", vetoArtworkTerminalFreeze: "0x2c6abb68",
  };
  assert.equal(actual.length, 10);
  for (const fn of actual) {
    assert.equal(fn.selector, expected[fn.name], fn.name);
    assert.equal(fn.stateMutability, "nonpayable", fn.name);
  }
  const registry = sourceNamed("StreamArtworkFinalityRegistry");
  for (const name of ["cancelArtworkTerminalFreeze", "materializeExpiredArtworkTerminalFreeze",
    "scheduleArtworkTerminalFreeze", "vetoArtworkTerminalFreeze"]) {
    assert.match(sourceFunction(registry, name), /revert FinalityLocalLifecycleRetired\(\)/, name);
  }
  assert.match(sourceFunction(registry, "_finalize"), /msg\.sender != governanceAuthority/);
  assert.match(sourceFunction(registry, "_finalize"), /StreamFinalityGovernanceWitness\.requireExecution/);
});

test("canonical manifest source preserves all ten inputs, nine independent components and exact two-store bytes", () => {
  const original = fixture.libraryAbis.scopedFinalityInputManifestReads.find(f => f.type === "function" && f.name === "encode");
  const statement = ordinaryValueType(original.inputs[1]);
  assert.deepEqual(fields(statement), [
    ["scope", "tuple"], ["coreFactsHash", "bytes32"], ["contentRoot", "bytes32"], ["leafCount", "uint64"],
    ["contentRootSchemaId", "bytes32"], ["snapshotManifestHash", "bytes32"], ["referenceRenderManifestHash", "bytes32"],
    ["inputs", "tuple"], ["nonSanctionComponents", "tuple[]"], ["entropyPolicy", "uint8"],
    ["postFreezePolicy", "uint8"], ["sanctionPolicy", "uint8"],
  ]);
  const inputs = statement.components[7];
  assert.deepEqual(inputs.components.map(p => p.name), [
    "rootRecordHash", "snapshotRecordHash", "referenceRenderRecordHash", "intentRecordHash",
    "intentWaiverRecordHash", "interviewEvidenceHash", "rightsStatementRecordHash", "workDescriptionRecordHash",
    "renderCriticalEvidenceHash", "bundleCoverageHash",
  ]);
  assert.ok(inputs.components.every(p => p.type === "bytes32"));
  sameFields([statement.components[0]], [compiledInterfaces.finality.getFunction("finalizeArtworkScopeWithArchive").inputs[0]], "scope");
  sameFields([statement.components[8]], [compiledInterfaces.finality.getFunction("finalizeArtworkScopeWithArchive").inputs[1]], "components");
  const reads = sourceNamed("StreamScopedFinalityInputManifestReads");
  assert.match(sourceFunction(reads, "encode"), /payload\.length > 8192/);
  const current = sourceFunction(reads, "requireCurrent");
  assert.match(current, /StreamSchemaDocumentStore\.readChunk/);
  assert.match(current, /IStreamArtworkFinalityRegistry\.finalityManifestBytes/);
  assert.match(sourceFunction(reads, "_shape"), /nonSanctionComponents\.length != 9/);
  const stage = sourceFunction(sourceNamed("StreamArtworkFinalityRegistry"), "stageFinalityManifest");
  assert.match(stage, /_manifestBytes\[contentHash\]\.length == 0/);
  assert.match(stage, /emit FinalityManifestStaged/);
});

test("the two manifest interpretation documents retain exact original Solidity bytes", () => {
  const schemaSource = sourceNamed("StreamScopedFinalityInputManifestSchemas");
  const literalBodies = [...schemaSource.matchAll(/return bytes\(\s*'([^']*)'\s*\)/g)].map(match => match[1]);
  assert.equal(literalBodies.length, 2);
  const paths = ["docs/schemas/finality/scoped-input-manifest-v1.definition.json",
    "docs/schemas/finality/scoped-input-manifest-abi-v1.definition.json"];
  for (let i = 0; i < paths.length; i++) {
    assert.equal(literalBodies[i].includes("\\"), false, "unescaped source literal");
    assert.equal(fixture.documents[paths[i]].text, literalBodies[i]);
    assert.equal(fixture.documents[paths[i]].byteLength, Buffer.byteLength(literalBodies[i]));
    assert.equal(fixture.documents[paths[i]].text.endsWith("\n"), false);
  }
  const canon = JSON.parse(literalBodies[1]);
  assert.equal(canon.maximumBytes, 8192);
  assert.equal(canon.componentCount, 9);
  assert.equal(canon.componentWords, 7);
  assert.match(canon.retention, /schema Store and original Registry/);
  const definition = sourceFunction(sourceNamed("StreamScopedFinalityInputManifestReads"), "_definition");
  assert.match(definition, /DocumentStatus\.ACTIVE/);
  assert.match(definition, /keccak256\("RAW_BYTES"\)/);
  assert.match(definition, /f\.chunkCount != 1/);
});

test("complete original Provider, Discovery and graph binding tuples retain their distinct widths", () => {
  const configFields = [["targets","address[22]"],["codeHashes","bytes32[22]"],["chainId","uint256"],
    ["readGas","uint256"],["sourceGas","uint256"],["componentSourceGas","uint256"],["inventoryDependencyHash","bytes32"]];
  for (const method of ["nativeConfiguration","scopedConfiguration","policyConfiguration"]) {
    assert.deepEqual(fields(compiledInterfaces.provider.getFunction(method).outputs[0]), configFields);
  }
  assert.deepEqual(fields(compiledInterfaces.discovery.getFunction("configuration").outputs[0]), [
    ["core","address"],["metadata","address"],["router","address"],["provider","address"],["membership","address"],
    ["entropyFactory","address"],["metadataAdapter","address"],["referenceRender","address"],["artist","address"],
    ["finalityRegistry","address"],["finalityRegistryCodeHash","bytes32"],["routerAdapters","address[6]"],
    ["readGas","uint32"],["componentGas","uint32"],["entropyGas","uint32"],
  ]);
  assert.deepEqual(fields(compiledInterfaces.provider.getFunction("scopedPolicyPublicationBinding").outputs[0]),
    [["factory","address"],["factoryCodeHash","bytes32"],["recipeHash","bytes32"],
      ["sourceFactoryDependenciesHash","bytes32"],["graphGas","uint256"],["configurationHash","bytes32"]]);
  const graphSelection = sourceNamed("StreamFinalityScopedPolicyGraphSelectionV2");
  assert.match(sourceFunction(graphSelection, "isPolicy"), /if \(head == 0\) return false/);
  assert.match(sourceFunction(graphSelection, "isPolicy"), /b\.profileId != RootSchemas\.PROFILE/);
  assert.match(sourceFunction(graphSelection, "current"), /g\.preparedChildren != 7/);
  assert.match(sourceFunction(graphSelection, "sources"), /b\.outputManifest != g\.children\[2\]/);
});

test("original class-two execution preserves complete governance and historical witness tuples", () => {
  const call = compiledInterfaces.executor.getFunction("scheduleGovernanceBatch").inputs[1].arrayChildren;
  assert.deepEqual(fields(call), [["target","address"],["value","uint256"],["selector","bytes4"],["callDataHash","bytes32"],
    ["scopeHash","bytes32"],["oldValueHash","bytes32"],["newValueHash","bytes32"]]);
  const context = compiledInterfaces.finality.getFunction("finalityExecutionContextWithArchive").outputs[0];
  assert.deepEqual(fields(context), [["scopeHash","bytes32"],["oldValueHash","bytes32"],["newValueHash","bytes32"],
    ["finalityRecordHash","bytes32"],["coreFactsHash","bytes32"],["componentsHash","bytes32"],["inputsHash","bytes32"]]);
  assert.deepEqual(fields(compiledInterfaces.finality.getFunction("finalityExecutionWitness").outputs[0]),
    [["actionId","bytes32"],["proposer","address"],["reasonHash","bytes32"],["roleMutationHash","bytes32"],["roleRevision","uint64"]]);
  const witness = sourceFunction(sourceNamed("StreamFinalityGovernanceWitness"), "requireExecution");
  assert.match(witness, /msg\.sender != pins\.executor/);
  assert.match(witness, /StreamGovernanceActionClasses\.TERMINAL_FREEZE/);
  assert.match(witness, /ROLE_COLLECTION_FINALITY_ADMIN/);
  assert.match(witness, /GovernanceActionStatus\.EXECUTED/);
  assert.match(witness, /expected\.scopeHash/);
  const record = compiledInterfaces.finality.getFunction("artworkScopeFinalityRecord").outputs[0];
  assert.equal(record.components.some(p => p.name === "coreFactsHash"), false);
  assert.equal(ordinaryValueType(fixture.libraryAbis.scopedFinalityInputManifestReads.find(f => f.name === "encode").inputs[1])
    .components.some(p => p.name === "coreFactsHash"), true, "immutable canonical manifest retains the historical preimage");
});

const finalizer = compiledInterfaces.finality.getFunction("finalizeArtworkScopeWithArchive");
const rawInput = (library, method, index) => ordinaryValueType(fixture.libraryAbis[library]
  .find(f => f.type === "function" && f.name === method).inputs[index]);
const compilerTuples = {
  SCOPE: finalizer.inputs[0],
  COMPONENT: finalizer.inputs[1].arrayChildren,
  COMPONENT_STATE: compiledInterfaces.scopedFinalityComponentInterface.getFunction("finalityStateForScope").outputs[0],
  INPUTS: compiledInterfaces.provider.getFunction("requireFinalityScopeInputs").outputs[0],
  STATEMENT: rawInput("scopedFinalityInputManifestReads", "encode", 1),
  MANIFEST_REF: finalizer.inputs[3],
  PROFILE: compiledInterfaces.profileSources.getFunction("finalitySourceProfile").outputs[0],
  SOURCES: compiledInterfaces.profileSources.getFunction("finalitySourcesForScope").outputs[0],
  NATIVE_CONFIGURATION: compiledInterfaces.provider.getFunction("nativeConfiguration").outputs[0],
  DISCOVERY_CONFIGURATION: compiledInterfaces.discovery.getFunction("configuration").outputs[0],
  FACTORY_BINDING: compiledInterfaces.provider.getFunction("scopedPolicyPublicationBinding").outputs[0],
  SOURCE_CONFIGURATION: rawInput("finalityProfileSourceReads", "current", 0),
  EXECUTION_CONTEXT: compiledInterfaces.finality.getFunction("finalityExecutionContextWithArchive").outputs[0],
  EXECUTION_WITNESS: compiledInterfaces.finality.getFunction("finalityExecutionWitness").outputs[0],
  ARCHIVE_PROOF: finalizer.inputs[4],
  ARCHIVE_WITNESS: compiledInterfaces.finality.getFunction("finalitySanctionArchiveWitness").outputs[0],
  SCOPED_RECORD: compiledInterfaces.finality.getFunction("artworkScopeFinalityRecord").outputs[0],
  SANCTION_PREPARATION: compiledInterfaces.finality.getFunction("prepareSanction").outputs[0],
  REVIEW: compiledInterfaces.provider.getFunction("requireSanctionReviewFacts").outputs[0],
  SCOPED_CORE_FACTS: compiledInterfaces.coreFinalityAdapter.getFunction("scopedCoreFinalityFacts").outputs[0],
  GOVERNANCE_CALL: compiledInterfaces.executor.getFunction("scheduleGovernanceBatch").inputs[1].arrayChildren,
  GOVERNANCE_ACTION: compiledInterfaces.executor.getFunction("governanceAction").outputs[0],
  ACTION_IDENTITY: rawInput("governanceBootstrap", "governanceActionId", 0),
};
const sourceLiteral = literalReader(new URL("../src/current-scoped-policy-finality-v2.ts", import.meta.url));

test("all twenty-three public finality tuples preserve complete original compiler fields and widths", () => {
  for (const [name, original] of Object.entries(compilerTuples)) {
    const actual = ParamType.from(sourceLiteral(`SCOPED_POLICY_FINALITY_V2_${name}_TUPLE`));
    sameFields([actual], [original], name);
    const value = sample(original);
    assert.equal(coder.encode([actual], [value]), coder.encode([original], [value]), name);
  }
});

test("four selected public host ABIs retain compiler fields, all events and errors, and closed mutators", () => {
  const mutators = {
    REGISTRY: ["finalizeArtworkScopeWithArchive", "stageFinalityManifest"],
    PROVIDER: [], DISCOVERY: [],
    EXECUTOR: ["executeGovernanceBatch", "publishGovernanceCallData", "scheduleGovernanceBatch"],
  };
  for (const [name, key] of [["REGISTRY", "finality"], ["PROVIDER", "provider"],
    ["DISCOVERY", "discovery"], ["EXECUTOR", "executor"]]) {
    const actual = new Interface(sourceLiteral(`SCOPED_POLICY_FINALITY_V2_${name}_ABI`));
    const original = compiledInterfaces[key];
    const supported = iface => iface.fragments.filter(f => ["function", "event", "error"].includes(f.type));
    const fragmentKey = f => f.type + "/" + f.format("sighash");
    const evidence = iface => supported(iface).filter(f => f.type !== "function").map(fragmentKey).sort();
    assert.deepEqual(evidence(actual), evidence(original), name + " complete events/errors");
    assert.deepEqual(actual.fragments.filter(f => f.type === "function"
      && !["pure", "view"].includes(f.stateMutability)).map(f => f.name).sort(), mutators[name], name);
    for (const fragment of supported(actual)) {
      const expected = supported(original).find(f => fragmentKey(f) === fragmentKey(fragment));
      assert.ok(expected, name + "/" + fragmentKey(fragment));
      compatibleFragment(fragment, expected);
    }
  }
});

// Runtime expectations below use frozen compiler tuples and independently assembled
// original Solidity preimages. No client hash or codec constructs an expected value.
const client = await import("../dist/current-scoped-policy-finality-v2.js");
const compilerType = name => compilerTuples[name].format("full");
const domain = name => {
  assert.ok(Object.values(fixture.sourceTexts).some(source => source.includes(`keccak256("${name}")`)), name);
  return id(name);
};
const domains = Object.fromEntries([
  "FINALITY_COMPONENTS_V1", "FINALITY_SCOPE_INPUTS_V1", "SCOPED_CORE_FINALITY_FACTS_V1",
  "SCOPED_FINALITY_V1", "ARTIST_SANCTION_SUBJECT_V1", "FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1",
  "FINALITY_EXECUTION_SCOPE_V1", "FINALITY_EXECUTION_OLD_V1", "FINALITY_EXECUTION_ARCHIVED_NEW_V1",
  "SCOPED_FINALITY_INPUT_MANIFEST_V1", "SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1",
  "SCOPED_POLICY_PROVIDER_CONFIGURATION_V2", "FINALITY_SOURCE_CONFIGURATION_V1",
  "FINALITY_SOURCE_CONFIGURATION_SCOPED_POLICY_V2",
].map(name => [name, domain("6529STREAM_" + name)]));
const manifestTypes = ["bytes32", "bytes32", "uint256", "address", "address", "address", compilerType("STATEMENT")];
const families = ["METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT", "MEDIA_MANIFEST", "SCRIPT_SOURCE",
  "DEPENDENCY_SOURCE", "COLLECTION_METADATA", "ENTROPY_COORDINATOR", "REFERENCE_RENDER"].map(id).sort();

function oracleModel(scopeType = 1n) {
  const coordinates = { chainId: (1n << 100n) + 111n, core: address(101), metadata: address(102),
    registry: address(103), executor: address(104), artist: address(105), artifactCoverage: address(106) };
  const scope = { scopeType, collectionId: (1n << 150n) + 17n,
    tokenId: scopeType === 1n ? (1n << 200n) + 31n : 0n, scopeId: scopeType === 1n ? ZeroHash : hash(27) };
  const nonSanctionComponents = families.map((componentType, i) => ({ ...sample(compilerTuples.COMPONENT, { n: 30 + i * 10 }),
    componentType, interfaceId: "0x8004d4f5" }));
  const proof = sample(compilerTuples.ARCHIVE_PROOF);
  const artist = { ...sample(compilerTuples.COMPONENT, { n: 300 }), componentType: id("ARTIST_SANCTION"),
    component: coordinates.artist, interfaceId: "0x8004d4f5", dataHash: proof.sanctionRecordHash };
  const components = [...nonSanctionComponents, artist].sort((a, b) => a.componentType.localeCompare(b.componentType));
  const facts = { ...sample(compilerTuples.SCOPED_CORE_FACTS), ...scope, scopeExists: true };
  const first = coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "uint256", "bytes32", "bool"],
    [domains.SCOPED_CORE_FINALITY_FACTS_V1, coordinates.chainId, coordinates.core, scope.scopeType,
      scope.collectionId, scope.tokenId, scope.scopeId, facts.scopeExists]);
  const second = coder.encode(["bool", "uint256", "uint8", "bool", "uint8", "uint8", "bytes32", "bytes32"],
    [facts.tokenMappingExists, facts.collectionSerial, facts.tokenLifecycle, facts.burned,
      facts.collectionStatus, facts.collectionSupplyMode, facts.collectionConfigHash, facts.scopeManifestHash]);
  const coreFactsHash = keccak256(concat([first, second]));
  const statement = { ...sample(compilerTuples.STATEMENT), scope, coreFactsHash, leafCount: scopeType === 1n ? 1n : 37n,
    nonSanctionComponents, inputs: { ...sample(compilerTuples.INPUTS), intentWaiverRecordHash: ZeroHash } };
  const manifestBytes = coder.encode(manifestTypes, [domains.SCOPED_FINALITY_INPUT_MANIFEST_V1,
    domains.SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1, coordinates.chainId, coordinates.core,
    coordinates.metadata, coordinates.registry, statement]);
  const manifestURI = "ipfs://historical-finality/作品";
  const manifest = { uri: manifestURI, uriHash: keccak256(toUtf8Bytes(manifestURI)), contentHash: keccak256(manifestBytes),
    schemaId: domains.SCOPED_FINALITY_INPUT_MANIFEST_V1, canonicalizationHash: domains.SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1 };
  return { coordinates, scope, facts, statement, proof, components, manifestBytes, manifestURI, manifest, coreFactsHash };
}

function oracleHashes(model) {
  const { coordinates: c, scope: s, statement, manifest: m, coreFactsHash, components, proof } = model;
  const componentsHash = abiHash(["bytes32", compilerType("COMPONENT") + "[]"], [domains.FINALITY_COMPONENTS_V1, components]);
  const nonSanctionComponentsHash = abiHash(["bytes32", compilerType("COMPONENT") + "[]"],
    [domains.FINALITY_COMPONENTS_V1, statement.nonSanctionComponents]);
  const inputsHash = abiHash(["bytes32", "uint256", "address", "address", compilerType("SCOPE"), compilerType("INPUTS")],
    [domains.FINALITY_SCOPE_INPUTS_V1, c.chainId, c.core, c.metadata, s, statement.inputs]);
  const recordPrefix = coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "uint256", "bytes32"],
    [domains.SCOPED_FINALITY_V1, c.chainId, c.core, s.scopeType, s.collectionId, s.tokenId, s.scopeId]);
  const recordSuffix = coder.encode(["bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [coreFactsHash, componentsHash, m.uriHash, m.contentHash, m.schemaId, m.canonicalizationHash]);
  const record = keccak256(concat([recordPrefix, recordSuffix]));
  const sanctionPrefix = coder.encode(["bytes32", "uint256", "address", "address", "uint8", "uint256", "uint256"],
    [domains.ARTIST_SANCTION_SUBJECT_V1, c.chainId, c.core, c.registry, s.scopeType, s.collectionId, s.tokenId]);
  const sanctionSuffix = coder.encode(Array(7).fill("bytes32"), [s.scopeId, coreFactsHash, nonSanctionComponentsHash,
    m.uriHash, m.contentHash, m.schemaId, m.canonicalizationHash]);
  const sanctionSubject = keccak256(concat([sanctionPrefix, sanctionSuffix]));
  const archiveEvidence = abiHash(["bytes32", "uint256", "address", "address", "address", compilerType("ARCHIVE_PROOF")],
    [domains.FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1, c.chainId, c.core, c.registry, c.artifactCoverage, proof]);
  const scopeHash = abiHash(["bytes32", "uint256", "address", compilerType("SCOPE")],
    [domains.FINALITY_EXECUTION_SCOPE_V1, c.chainId, c.registry, s]);
  const execution = { scopeHash, coreFactsHash, componentsHash, inputsHash, finalityRecordHash: record,
    oldValueHash: abiHash(["bytes32", "bytes32", "bool", "bytes32", "bytes32", "bytes32"],
      [domains.FINALITY_EXECUTION_OLD_V1, scopeHash, false, coreFactsHash, componentsHash, inputsHash]),
    newValueHash: abiHash(["bytes32", "bytes32", "bool", "bytes32", "bytes32"],
      [domains.FINALITY_EXECUTION_ARCHIVED_NEW_V1, scopeHash, true, record, archiveEvidence]) };
  return { componentsHash, nonSanctionComponentsHash, inputsHash, record, sanctionSubject, archiveEvidence, execution };
}

test("runtime codecs round-trip twenty-two complete compiler tuple values including high identities", () => {
  for (const [name, tuple] of Object.entries(compilerTuples)) {
    if (name === "ACTION_IDENTITY") continue;
    const suffix = name.toLowerCase().split("_").map(word => word[0].toUpperCase() + word.slice(1)).join("");
    const value = sample(tuple), encoded = coder.encode([tuple], [value]);
    assert.equal(client[`encodeScopedPolicyFinalityV2${suffix}`](value), encoded, name);
    const decoded = client[`decodeScopedPolicyFinalityV2${suffix}`](encoded);
    assert.deepEqual(decoded, value, name);
    assert.ok(Object.isFrozen(decoded), name);
  }
});

test("canonical manifests retain the exact flat compiler envelope for TOKEN, RELEASE and SEASON", () => {
  for (const scopeType of [1n, 2n, 3n]) {
    const m = oracleModel(scopeType);
    assert.equal(client.scopedPolicyFinalityV2ManifestBytes(m.coordinates, m.statement), m.manifestBytes);
    const decoded = client.decodeScopedPolicyFinalityV2Manifest(m.manifestBytes);
    assert.deepEqual(decoded.statement, m.statement);
    assert.equal(decoded.metadata, m.coordinates.metadata);
    assert.equal(decoded.registry, m.coordinates.registry);
    const tupleWrapped = coder.encode(["(" + manifestTypes.join(",") + ")"], [[
      domains.SCOPED_FINALITY_INPUT_MANIFEST_V1, domains.SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1,
      m.coordinates.chainId, m.coordinates.core, m.coordinates.metadata, m.coordinates.registry, m.statement]]);
    assert.notEqual(tupleWrapped, m.manifestBytes);
    assert.throws(() => client.decodeScopedPolicyFinalityV2Manifest(tupleWrapped));
    assert.throws(() => client.decodeScopedPolicyFinalityV2Manifest(m.manifestBytes + "00"));
  }
});

test("runtime interpretation constants match complete original definition bytes and keccak identities", () => {
  assert.equal(client.SCOPED_POLICY_FINALITY_V2_PROFILE,
    keccak256(toUtf8Bytes(fixture.documents["docs/schemas/preservation/scoped-policy-snapshot-v2.profile.json"].text)));
  for (const [key, path] of [["SCHEMA", "scoped-input-manifest-v1.definition.json"],
    ["CANONICALIZATION", "scoped-input-manifest-abi-v1.definition.json"]]) {
    const original = fixture.documents["docs/schemas/finality/" + path];
    assert.equal(client[`SCOPED_POLICY_FINALITY_V2_${key}_DOCUMENT`], original.text);
    assert.equal(client[`SCOPED_POLICY_FINALITY_V2_${key}_HASH`], keccak256(toUtf8Bytes(original.text)));
    assert.equal(client[`SCOPED_POLICY_FINALITY_V2_${key}_BYTES`], BigInt(original.byteLength));
  }
});

test("scope, components, ten-input and split Core preimages match original source for all three scopes", () => {
  const coreSource = sourceFunction(sourceNamed("StreamFinalityHashes"), "scopedCoreFactsHash");
  assert.match(coreSource, /bytes\.concat/);
  assert.match(coreSource, /uint8\(scope\.scopeType\)/);
  assert.doesNotMatch(coreSource, /facts\.scopeType|facts\.collectionId|facts\.tokenId|facts\.scopeId/);
  for (const scopeType of [1n, 2n, 3n]) {
    const m = oracleModel(scopeType), h = oracleHashes(m);
    assert.equal(client.scopedPolicyFinalityV2ScopeKey(m.scope), abiHash(["uint8", "uint256", "uint256", "bytes32"],
      [m.scope.scopeType, m.scope.collectionId, m.scope.tokenId, m.scope.scopeId]));
    assert.equal(client.scopedPolicyFinalityV2ComponentsHash(m.components), h.componentsHash);
    assert.equal(client.scopedPolicyFinalityV2ComponentsHash(m.statement.nonSanctionComponents), h.nonSanctionComponentsHash);
    assert.equal(client.scopedPolicyFinalityV2ScopeInputsHash(m.coordinates, m.scope, m.statement.inputs), h.inputsHash);
    assert.equal(client.scopedPolicyFinalityV2ScopedCoreFactsHash(m.coordinates, m.scope, m.facts), m.coreFactsHash);
    assert.equal(client.scopedPolicyFinalityV2ScopedCoreFactsHash(m.coordinates, m.scope, { ...m.facts,
      collectionId: 3n, tokenId: 4n, scopeType: 0n, scopeId: hash(5) }), m.coreFactsHash,
    "source commits the explicit scope; admission must separately join duplicated fact identity fields");
  }
});

test("permanent record, Artist subject, archive evidence and archived transition use distinct original domains", () => {
  for (const scopeType of [1n, 2n, 3n]) {
    const m = oracleModel(scopeType), h = oracleHashes(m);
    assert.equal(client.scopedPolicyFinalityV2RecordHash(m.coordinates, m.scope, m.coreFactsHash, h.componentsHash, m.manifest), h.record);
    assert.equal(client.scopedPolicyFinalityV2SanctionSubjectHash(m.coordinates, m.scope, m.coreFactsHash,
      h.nonSanctionComponentsHash, m.manifest), h.sanctionSubject);
    assert.equal(client.scopedPolicyFinalityV2ArchiveEvidenceHash(m.coordinates, m.proof), h.archiveEvidence);
    assert.deepEqual(client.scopedPolicyFinalityV2ExecutionContext(m.coordinates, m.scope, m.coreFactsHash,
      h.componentsHash, h.inputsHash, h.record, h.archiveEvidence), h.execution);
    assert.notEqual(h.execution.newValueHash, abiHash(["bytes32", "bytes32", "bool", "bytes32"],
      [domain("6529STREAM_FINALITY_EXECUTION_NEW_V1"), h.execution.scopeHash, true, h.record]));
    const changedArchive = oracleHashes({ ...m, proof: { ...m.proof, completionHash: hash(987) } });
    assert.equal(changedArchive.record, h.record);
    assert.notEqual(changedArchive.execution.newValueHash, h.execution.newValueHash);
    const changedMetadata = oracleHashes({ ...m, coordinates: { ...m.coordinates, metadata: address(199) } });
    assert.notEqual(changedMetadata.inputsHash, h.inputsHash);
    assert.equal(changedMetadata.record, h.record);
  }
});

test("provider and source configurations retain complete original context and different binding preimages", () => {
  const provider = address(401), original = sample(compilerTuples.NATIVE_CONFIGURATION);
  const binding = sample(compilerTuples.FACTORY_BINDING), configuration = sample(compilerTuples.SOURCE_CONFIGURATION);
  const providerHash = abiHash(["bytes32", "uint256", "address", compilerType("NATIVE_CONFIGURATION"),
    "address", "bytes32", "bytes32", "bytes32", "uint256"],
  [domains.SCOPED_POLICY_PROVIDER_CONFIGURATION_V2, original.chainId, provider, original, binding.factory,
    binding.factoryCodeHash, binding.recipeHash, binding.sourceFactoryDependenciesHash, binding.graphGas]);
  const sourceHash = b => abiHash(["bytes32", "bytes32", compilerType("FACTORY_BINDING")],
    [domains.FINALITY_SOURCE_CONFIGURATION_SCOPED_POLICY_V2,
      abiHash(["bytes32", "uint256", "address", compilerType("SOURCE_CONFIGURATION")],
        [domains.FINALITY_SOURCE_CONFIGURATION_V1, configuration.chainId, provider, configuration]), b]);
  assert.equal(client.scopedPolicyFinalityV2ProviderConfigurationHash(provider, original, binding), providerHash);
  assert.equal(client.scopedPolicyFinalityV2SourceConfigurationHash(provider, configuration, binding), sourceHash(binding));
  const mutated = { ...binding, configurationHash: hash(999) };
  assert.equal(client.scopedPolicyFinalityV2ProviderConfigurationHash(provider, original, mutated), providerHash);
  assert.equal(client.scopedPolicyFinalityV2SourceConfigurationHash(provider, configuration, mutated), sourceHash(mutated));
  assert.notEqual(sourceHash(mutated), sourceHash(binding));
  assert.match(sourceFunction(sourceNamed("StreamFinalityProfileSourceReads"), "configurationHash"),
    /abi\.encode\(DOMAIN, c\.chainId, address\(this\), c\)/);
});

test("archived plan encodes the genuine Registry target and view with independently reconstructed commitments", () => {
  for (const scopeType of [1n, 2n, 3n]) {
    const m = oracleModel(scopeType), h = oracleHashes(m);
    const plan = client.prepareScopedPolicyFinalityV2Finalization(m.coordinates,
      { manifestBytes: m.manifestBytes, manifestURI: m.manifestURI, components: m.components, proof: m.proof });
    const args = [m.scope, m.components, h.record, m.manifest, m.proof];
    const data = compiledInterfaces.finality.encodeFunctionData("finalizeArtworkScopeWithArchive", args);
    assert.deepEqual(plan.targetCall, { to: m.coordinates.registry, value: 0n, data });
    assert.equal(plan.contextCall.data, compiledInterfaces.finality.encodeFunctionData("finalityExecutionContextWithArchive", args));
    assert.deepEqual(plan.execution, h.execution);
    assert.deepEqual(plan.governanceCall, { target: m.coordinates.registry, value: 0n, selector: finalizer.selector,
      callDataHash: keccak256(data), scopeHash: h.execution.scopeHash, oldValueHash: h.execution.oldValueHash,
      newValueHash: h.execution.newValueHash });
    assert.equal(plan.factsVerified, false);
  }
});

test("singleton class-two batches match source-literal aggregate domains, split action identity and packed publication key", () => {
  const m = oracleModel(2n), h = oracleHashes(m);
  const plan = client.prepareScopedPolicyFinalityV2Finalization(m.coordinates,
    { manifestBytes: m.manifestBytes, manifestURI: m.manifestURI, components: m.components, proof: m.proof });
  const window = { notBefore: (1n << 55n) + 17n, expiresAfter: (1n << 55n) + 17n + 604800n,
    reasonHash: hash(805), reasonURI: "reviewed/作品", manifestHash: hash(806) };
  const nonce = (1n << 240n) + 3n, batch = client.scopedPolicyFinalityV2GovernanceBatch(plan, nonce, window);
  const targetData = compiledInterfaces.finality.encodeFunctionData("finalizeArtworkScopeWithArchive",
    [m.scope, m.components, h.record, m.manifest, m.proof]);
  const calls = [{ target: m.coordinates.registry, value: 0n, selector: finalizer.selector,
    callDataHash: keccak256(targetData), scopeHash: h.execution.scopeHash,
    oldValueHash: h.execution.oldValueHash, newValueHash: h.execution.newValueHash }];
  const bootstrap = sourceNamed("StreamGovernanceBootstrap");
  const literals = method => [...sourceFunction(bootstrap, method).matchAll(/bytes32\((0x[0-9a-f]{64})\)/g)].map(m => m[1]);
  const callsDomain = literals("governanceCallsHash"), aggregates = literals("deriveBatchTransitionHashes"), identityDomain = literals("governanceActionId");
  assert.equal(callsDomain.length, 1); assert.equal(aggregates.length, 3); assert.equal(identityDomain.length, 1);
  const callsHash = abiHash(["bytes32", compilerType("GOVERNANCE_CALL") + "[]"], [callsDomain[0], calls]);
  const [scopeHash, oldValueHash, newValueHash] = ["scopeHash", "oldValueHash", "newValueHash"].map((field, i) =>
    abiHash(["bytes32", "bytes32", "bytes32[]"], [aggregates[i], callsHash, calls.map(row => row[field])]));
  const identity = { actionClass: 2n, callsHash, scopeHash, oldValueHash, newValueHash, nonce,
    notBefore: window.notBefore, expiresAfter: window.expiresAfter, reasonHash: window.reasonHash, manifestHash: window.manifestHash };
  const actionId = keccak256(concat([coder.encode(["bytes32", "uint256", "address"],
    [identityDomain[0], m.coordinates.chainId, m.coordinates.executor]), coder.encode([compilerTuples.ACTION_IDENTITY], [identity])]));
  assert.equal(batch.callsHash, callsHash); assert.equal(batch.scopeHash, scopeHash);
  assert.equal(batch.oldValueHash, oldValueHash); assert.equal(batch.newValueHash, newValueHash);
  assert.equal(batch.actionId, actionId);
  assert.equal(batch.publicationKey, keccak256(concat(calls.map(row => row.callDataHash))));
  assert.notEqual(batch.scopeHash, h.execution.scopeHash);
  assert.equal(batch.publicationCall.data, compiledInterfaces.executor.encodeFunctionData("publishGovernanceCallData", [[targetData]]));
  assert.equal(batch.scheduleCall.data, compiledInterfaces.executor.encodeFunctionData("scheduleGovernanceBatch", [2n, calls,
    scopeHash, oldValueHash, newValueHash, window.notBefore, window.expiresAfter, window.reasonHash, window.reasonURI, window.manifestHash]));
  assert.equal(batch.executionCall.data, compiledInterfaces.executor.encodeFunctionData("executeGovernanceBatch", [actionId, calls, [targetData]]));
  for (const kind of ["publishGovernanceCallData", "scheduleGovernanceBatch", "executeGovernanceBatch"]) {
    assert.equal(client.prepareScopedPolicyFinalityV2Call(m.coordinates, address(999), { kind, batch }).call.to, m.coordinates.executor);
  }
});

test("immutable history rederives original Core and component commitments solely from retained manifest bytes", () => {
  const m = oracleModel(3n), h = oracleHashes(m);
  const record = { finalized: true, scope: m.scope, finalityRecordHash: h.record,
    manifestContentHash: m.manifest.contentHash, manifestURIHash: m.manifest.uriHash, componentsHash: h.componentsHash,
    finalityManifestURI: m.manifestURI, manifestPointer: m.coordinates.registry, finalizedAt: (1n << 55n) + 19n };
  const input = { manifestBytes: m.manifestBytes, record, components: m.components };
  const result = client.authenticateScopedPolicyFinalityV2History(m.coordinates, input);
  assert.equal(result.statement.coreFactsHash, m.coreFactsHash);
  assert.equal(result.record.finalityRecordHash, h.record);
  const changed = { ...m.statement, coreFactsHash: hash(999) };
  const replacedBytes = coder.encode(manifestTypes, [m.manifest.schemaId, m.manifest.canonicalizationHash,
    m.coordinates.chainId, m.coordinates.core, m.coordinates.metadata, m.coordinates.registry, changed]);
  assert.throws(() => client.authenticateScopedPolicyFinalityV2History(m.coordinates, {
    ...input, manifestBytes: replacedBytes, record: { ...record, manifestContentHash: keccak256(replacedBytes) } }));
  assert.throws(() => client.authenticateScopedPolicyFinalityV2History(m.coordinates, {
    ...input, components: m.components.map((component, i) => i === 0 ? { ...component, moduleVersion: hash(888) } : component) }));
});

test("every workflow-local read ABI is an original ordinary compiler endpoint with complete result fields", () => {
  const path = new URL("../src/current-scoped-policy-finality-v2-workflow.ts", import.meta.url);
  const source = ts.createSourceFile(path.href, readFileSync(path, "utf8"), ts.ScriptTarget.Latest, true);
  const reads = [];
  function visit(node) {
    if (ts.isStringLiteral(node) && /^function /.test(node.text)) reads.push(node.text);
    ts.forEachChild(node, visit);
  }
  visit(source);
  assert.ok(reads.length > 50, "complete workflow-local read inventory");
  const originals = Object.values(compiledInterfaces).flatMap(iface => iface.fragments.filter(f => f.type === "function"));
  for (const read of reads) {
    const [actual] = new Interface([read]).fragments;
    assert.ok(["pure", "view"].includes(actual.stateMutability), read);
    const matches = originals.filter(f => f.format("sighash") === actual.format("sighash"));
    assert.ok(matches.length, "ordinary compiler endpoint: " + read);
    assert.ok(matches.some(original => {
      try { compatibleFragment(actual, original); return true; } catch { return false; }
    }), "complete compiler result/mutability: " + read);
  }
});
