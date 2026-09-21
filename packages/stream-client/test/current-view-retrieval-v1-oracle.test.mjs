import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { posix } from "node:path";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { readFileSync } from "node:fs";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, id, keccak256, toUtf8Bytes } from "ethers";
import { fixture, compiledInterfaces } from "./current-view-retrieval-v1-fixture.mjs";

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

function libraryValue(parameter) {
  assert.ok(!/\bstorage\b/.test(parameter.internalType ?? ""), "memory-only library values");
  let type = parameter.type;
  if (parameter.internalType?.startsWith("enum ")) type = "uint8" + (type.match(/(\[[0-9]*\])+$/)?.[0] ?? "");
  else if (parameter.internalType?.startsWith("contract ")) type = "address" + (type.match(/(\[[0-9]*\])+$/)?.[0] ?? "");
  return { ...parameter, type, ...(parameter.components ? { components: parameter.components.map(libraryValue) } : {}) };
}



const sha = value => createHash("sha256").update(value).digest("hex");

test("retrieval producer witness binds exact ABI157 and preserves historical fixture identities", () => {
  assert.equal(fixture.profile, "current-view-retrieval-v1");
  assert.equal(fixture.sourceCommit, "a2973d360f6ab18881c04d58193f855704ec56d3");
  assert.equal(fixture.sourceTree, "f66d6a195a9e59b31cfe9ad8bd819e29054298bd");
  assert.equal(fixture.compilerVersion, "0.8.19");
  assert.equal(fixture.sourceCount, 4059);
  assert.equal(fixture.literalBytes, 48186075);
  assert.equal(fixture.inputSha256, "bdeb13c7467525241cfdc4fffe97e11aefbbd310972606eefe1ebebe47358234");
  assert.equal(fixture.outputSha256, "b6b473ed08be283b2efba661132193670d8f2ff2d39e06cd1bb6f31729573da6");
  const { sha256, ...bridge } = fixture.committedSourceBridge;
  assert.equal(sha256, "32d8ad5e406ff13d7558e2d3a29fe44bb9f6108b0644cece83b45e1685d08a6a");
  assert.equal(sha(JSON.stringify(bridge, null, 2) + "\n"), sha256);
  assert.equal(bridge.commit, fixture.sourceCommit);
  assert.equal(bridge.sources, 4059);
  assert.equal(Object.keys(bridge.committedBlobSHA256).length, 4059);
  assert.deepEqual(bridge.mismatches, []);
  assert.match(fixture.sourceBinding, /no line-ending normalization/);
  assert.match(fixture.qualification, /does not establish client coverage of the companion VIEW inventory or Bundle consumer extension/);
  assert.match(fixture.qualification, /No actual native\/Safe execution/);
  for (const [name, hash] of [
    ["current-preservation-v2-abi.json", "6425f868f20cffa0da23dea20aa771a870fa4649ade04fe7229141bb15a4b7dc"],
    ["current-authority-preservation-archive-v1-abi.json", "c937f7d585f2192ecfa730125246cc56f5e8cfa64b638cdef698f1116883e62b"],
  ]) assert.equal(sha(readFileSync(new URL("./fixtures/" + name, import.meta.url))), hash, name);
});

test("retrieval compiler ABIs retain every ordinary and nominal selector with the correct declaration kind", () => {
  assert.equal(Object.keys(fixture.abis).length, 27);
  assert.equal(Object.keys(fixture.libraryAbis).length, 34);
  let ordinary = 0, nominal = 0;
  for (const [name, iface] of Object.entries(compiledInterfaces)) {
    const selection = fixture.selections[name];
    assert.deepEqual(selection, { source: selection.source, contract: name, full: true });
    const functions = iface.fragments.filter(f => f.type === "function");
    assert.equal(functions.length, Object.keys(fixture.methodIdentifiers[name]).length, name);
    const text = fixture.sourceTexts[selection.source];
    assert.match(text, new RegExp("\\b(?:contract|interface)\\s+" + name + "\\b"));
    for (const fn of functions) {
      assert.equal(fixture.methodIdentifiers[name][fn.format("sighash")], fn.selector.slice(2), name);
      ordinary++;
    }
  }
  for (const [name, identifiers] of Object.entries(fixture.libraryMethodIdentifiers)) {
    const selection = fixture.librarySelections[name];
    assert.equal(selection.nominal, true);
    assert.equal(selection.full, true);
    assert.equal(compiledInterfaces[name], undefined);
    assert.match(fixture.sourceTexts[selection.source], new RegExp("\\blibrary\\s+" + name + "\\b"));
    for (const [signature, selector] of Object.entries(identifiers)) {
      assert.equal(id(signature).slice(2, 10), selector, name + "." + signature);
      nominal++;
    }
  }
  assert.equal(ordinary, 244);
  assert.equal(nominal, 76);
});

test("the genuine witness has a complete exact-byte imported closure and same-commit interpretation documents", () => {
  const visited = new Set();
  function visit(path) {
    if (visited.has(path)) return;
    visited.add(path);
    const source = fixture.sourceTexts[path];
    assert.equal(typeof source, "string", path);
    assert.equal(sha(source), fixture.sourceHashes[path], path);
    assert.equal(sha(source), fixture.committedSourceBridge.committedBlobSHA256[path], path);
    for (const imported of solidityImports(source)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  visit(fixture.selections.StreamViewRetrievalWitnessV1.source);
  assert.equal(visited.size, 59);
  assert.deepEqual([...visited].sort(), Object.keys(fixture.sourceTexts).sort());
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, source) => n + Buffer.byteLength(source), 0), 275762);
  for (const selected of [...Object.values(fixture.selections), ...Object.values(fixture.librarySelections)]) {
    assert.ok(visited.has(selected.source), selected.contract);
  }
  assert.equal(Object.keys(fixture.documents).length, 2);
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
  }
});

const pureUrl = new URL("../src/current-view-retrieval-v1.ts", import.meta.url);
const readPure = () => literalReader(pureUrl);

const workflowUrl = new URL("../src/current-view-retrieval-v1-workflow.ts", import.meta.url);

test("workflow profile gates retain the original source domains", () => {
  const source = readFileSync(workflowUrl, "utf8");
  const checkpointTypes = fixture.sourceTexts["smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol"];
  const retrievalSource = fixture.sourceTexts["smart-contracts/domains/preservation/StreamViewRetrievalSourceV1.sol"];
  const checkpoint = /\bPROFILE\s*=\s*keccak256\("([^"]+)"\)/.exec(checkpointTypes)?.[1];
  const archive = /keccak256\("(STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1)"\)/.exec(retrievalSource)?.[1];
  assert.ok(checkpoint);
  assert.ok(archive);
  assert.equal(/id\("([^"]+)"\), "Checkpoint profile differs"/.exec(source)?.[1], checkpoint);
  assert.equal(/id\("([^"]+)"\), "Archive profile differs"/.exec(source)?.[1], archive);
});


test("workflow ordinary read selectors and recursive return layouts match their original compiler interfaces", () => {
  const literal = literalReader(workflowUrl);
  const selections = {
    checkpointAbi: ["IStreamViewPreservationContentCheckpointV1"],
    routerAbi: ["IStreamMetadataServingFacts"],
    capabilityAbi: ["IERC165"],
    archiveAbi: ["IStreamExternalArtifactCoverage", "IStreamExternalArtifactCurrentPair"],
    storeAbi: ["StreamSchemaDocumentStore"],
  };
  const source = fixture.sourceTexts["smart-contracts/domains/preservation/StreamViewRetrievalSourceV1.sol"];
  for (const [name, selected] of Object.entries(selections)) {
    const actual = new Interface(literal(name));
    for (const fragment of actual.fragments) {
      assert.equal(fragment.type, "function", name);
      assert.ok(fragment.constant, name + "." + fragment.name);
      if (name === "routerAbi" && fragment.name === "core") {
        // The original caller uses a literal selector and addressWord, outside Artist's declared interface.
        assert.match(source, /IO\.addressWord\(c\.router, abi\.encodeWithSignature\("core\(\)"\), c\.readGas\) != c\.core/);
        assert.equal(fragment.format("sighash"), "core()");
        assert.equal(fragment.selector, id("core()").slice(0, 10));
        assert.equal(fragment.outputs.length, 1);
        assert.equal(fragment.outputs[0].type, "address");
        assert.equal(fragment.stateMutability, "view");
        continue;
      }
      const witnesses = selected.flatMap(contract => compiledInterfaces[contract].fragments)
        .filter(original => original.type === fragment.type && original.format("sighash") === fragment.format("sighash"));
      assert.equal(witnesses.length, 1, name + "." + fragment.name);
      compatibleFragment(fragment, witnesses[0]);
    }
  }
});

test("workflow capability IDs use each complete declared interface rather than its read-only subset", () => {
  const literal = literalReader(workflowUrl);
  for (const [name, contract] of [
    ["CHECKPOINT_INTERFACE", "IStreamViewPreservationContentCheckpointV1"],
    ["ARCHIVE_INTERFACE", "IStreamExternalArtifactCoverage"],
  ]) {
    const text = fixture.sourceTexts[fixture.selections[contract].source];
    const ownNames = new Set([...text.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(match => match[1]));
    const ownFunctions = compiledInterfaces[contract].fragments.filter(f => f.type === "function" && ownNames.has(f.name));
    assert.equal(ownFunctions.length, ownNames.size);
    let expected = 0n;
    for (const fn of ownFunctions) expected ^= BigInt(fn.selector);
    assert.equal(literal(name), "0x" + expected.toString(16).padStart(8, "0"));
    if (contract === "IStreamExternalArtifactCoverage") {
      assert.match(text, /interface IStreamExternalArtifactCoverage\s*\{/);
      assert.equal(ownNames.has("supportsInterface"), true);
      assert.equal(ownNames.has("recordReceipt"), true);
    }
  }
});


test("retrieval client ABI preserves the exact two writes and every original read, event and error", () => {
  const actual = new Interface(readPure()("CURRENT_VIEW_RETRIEVAL_V1_ABI"));
  const original = compiledInterfaces.StreamViewRetrievalWitnessV1;
  const surface = iface => iface.fragments.filter(f => !["constructor", "fallback", "receive"].includes(f.type))
    .map(f => f.type + ":" + f.format("sighash")).sort();
  assert.deepEqual(surface(actual), surface(original));
  for (const fragment of actual.fragments) {
    const witness = original.fragments.find(f => f.type === fragment.type && f.format("sighash") === fragment.format("sighash"));
    assert.ok(witness, fragment.format("sighash"));
    compatibleFragment(fragment, witness);
  }
  assert.deepEqual(actual.fragments.filter(f => f.type === "function" && !f.constant).map(f => f.name).sort(),
    ["publish", "revoke"]);
});

test("all fifteen retrieval tuple codecs retain recursive compiler field names and widths", () => {
  const witnesses = [];
  function visit(value) {
    let p = ParamType.from(libraryValue(value), true);
    while (p.baseType === "array") p = p.arrayChildren;
    if (p.baseType === "tuple") witnesses.push(p);
    value.components?.forEach(visit);
  }
  for (const abi of [...Object.values(fixture.abis), ...Object.values(fixture.libraryAbis)]) for (const fragment of abi) {
    fragment.inputs?.forEach(visit);
    fragment.outputs?.forEach(visit);
  }
  const names = [...readFileSync(pureUrl, "utf8").matchAll(/export const (CURRENT_VIEW_RETRIEVAL_V1_\w+_TUPLE) =/g)];
  assert.equal(names.length, 15);
  const literal = readPure();
  for (const [, name] of names) {
    const actual = ParamType.from(literal(name));
    assert.ok(witnesses.some(original => {
      try { sameFields([actual], [original], name); return true; } catch { return false; }
    }), name + " lacks exact recursive compiler fields");
  }
});

test("original raw signing, source, record and nonce preimages remain distinct with full-width fields", async () => {
  const client = await import("../dist/current-view-retrieval-v1.js");
  const original = compiledInterfaces.StreamViewRetrievalWitnessV1;
  const configurationType = original.getFunction("configuration").outputs[0];
  const observationType = original.getFunction("prepare").outputs[0];
  const receiptType = original.getFunction("record").outputs[0];
  let seed = 1;
  function example(type) {
    if (type.baseType === "array") return Array.from({ length: type.arrayLength < 0 ? 0 : type.arrayLength }, () => example(type.arrayChildren));
    if (type.baseType === "tuple") return Object.fromEntries(type.components.map(p => [p.name, example(p)]));
    if (type.type === "address") return "0x" + (seed++).toString(16).padStart(40, "0");
    if (type.type === "bytes32") return id("independent-retrieval-vector-" + seed++);
    if (type.type === "bytes") return "0x123456";
    if (type.type === "string") return "https://example.test/literal/%2f?q=1#image";
    if (type.type === "bool") return false;
    const match = /^uint(\d+)$/.exec(type.type);
    assert.ok(match, type.type);
    return (1n << BigInt(Number(match[1]) - 1)) + BigInt(seed++);
  }
  const config = example(configurationType), observation = example(observationType), receipt = example(receiptType);
  observation.source.scope.scopeType = 4n;
  observation.source.scope.tokenId = 0n;
  const coordinates = { chainId: config.chainId, witness: "0x0000000000000000000000000000000000000abc" };
  const typesSource = fixture.sourceTexts["smart-contracts/interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol"];
  const domain = name => {
    const literal = new RegExp("\\b" + name + "\\s*=\\s*keccak256\\(\"([^\"]+)\"\\)").exec(typesSource)?.[1];
    assert.ok(literal, name); return id(literal);
  };
  const coder = AbiCoder.defaultAbiCoder();
  const hash = (types, values) => keccak256(coder.encode(types, values));
  const configHash = hash(["bytes32", configurationType], [domain("PROFILE"), config]);
  assert.equal(client.currentViewRetrievalV1ConfigurationHash(config), configHash);
  const sourceType = observationType.components.find(p => p.name === "source");
  const codec = fixture.sourceTexts["smart-contracts/domains/preservation/StreamViewRetrievalCodecV1.sol"];
  const sourceKeyBody = codec.slice(codec.indexOf("function sourceKey("), codec.indexOf("function digest("));
  const originalFields = /abi\.encode\(\s*T\.SOURCE,([\s\S]*?)\)\s*\)/.exec(sourceKeyBody)?.[1]
    .split(",").map(value => value.trim().replace(/^s\./, ""));
  assert.ok(originalFields);
  assert.deepEqual(originalFields, sourceType.components.map(p => p.name).filter(name => name !== "checkpointContextHash"));
  const selected = originalFields.map(name => sourceType.components.find(p => p.name === name));
  const sourceKey = hash(["bytes32", ...selected], [domain("SOURCE"), ...originalFields.map(name => observation.source[name])]);
  assert.equal(client.currentViewRetrievalV1SourceKey(observation.source), sourceKey);
  assert.equal(client.currentViewRetrievalV1SourceKey({ ...observation.source, checkpointContextHash: id("different context") }), sourceKey);
  const digest = value => hash(["bytes32", "uint256", "address", "bytes32", observationType],
    [domain("OBSERVATION"), config.chainId, coordinates.witness, configHash, value]);
  assert.equal(client.currentViewRetrievalV1Digest(coordinates, config, observation), digest(observation));
  const changed = { ...observation, source: { ...observation.source, checkpointContextHash: id("different context") } };
  assert.equal(client.currentViewRetrievalV1Digest(coordinates, config, changed), digest(changed));
  assert.notEqual(digest(changed), digest(observation));
  for (const nonce of [0n, (1n << 256n) - 1n]) {
    assert.equal(client.currentViewRetrievalV1NonceKey(observation.writer, nonce),
      hash(["bytes32", "address", "uint256"], [domain("NONCE"), observation.writer, nonce]));
  }
  const expectedRecord = hash(["bytes32", "uint256", "address", "bytes32", receiptType],
    [domain("RECORD"), config.chainId, coordinates.witness, configHash, { ...receipt, recordHash: "0x" + "00".repeat(32) }]);
  assert.equal(client.currentViewRetrievalV1RecordHash(coordinates, config, receipt), expectedRecord);
  assert.equal(client.currentViewRetrievalV1RecordHash(coordinates, config, { ...receipt, recordHash: id("another self hash") }), expectedRecord);
  assert.notEqual(client.currentViewRetrievalV1RecordHash(coordinates, config, { ...receipt, recordedAt: receipt.recordedAt + 1n }), expectedRecord);
});
