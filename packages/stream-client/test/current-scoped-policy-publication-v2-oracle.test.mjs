import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledInterfaces, compiledLibraryEvents } from "./current-scoped-policy-publication-v2-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const fields = tuple => tuple.components.map(p => [p.name, p.type]);
const words = type => type.baseType === "tuple"
  ? type.components.reduce((n, p) => n + words(p), 0)
  : type.baseType === "array" ? type.arrayLength * words(type.arrayChildren) : 1;

test("scoped publication witness retains the exact ABI129 committed source and evidence boundary", () => {
  assert.equal(fixture.profile, "scoped-policy-publication-v2");
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
  assert.match(fixture.qualification, /Snapshot publication requires independently current SNAPSHOT and IDENTITY grants and is not idempotent/);
  assert.match(fixture.qualification, /Native\/Safe execution.*remain separately qualified/);
});

test("all ordinary contract and interface selectors retain complete compiler ABIs", () => {
  assert.equal(Object.keys(fixture.abis).length, 62);
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 2158);
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
  assert.equal(selectors, 1290);
});

test("nominal fixed deployment and reader libraries stay separate from wallet calls", () => {
  assert.equal(Object.keys(fixture.libraryAbis).length, 15);
  assert.equal(Object.values(fixture.libraryAbis).reduce((n, a) => n + a.length, 0), 42);
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
  assert.equal(count, 26);
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
  assert.equal(visited.size, 629);
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, text) => n + Buffer.byteLength(text), 0), 3791721);
});

test("original documents retain scope and acyclic preparation/publication boundaries", () => {
  assert.equal(Object.keys(fixture.documents).length, 19);
  let size = 0;
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
    size += document.byteLength;
  }
  assert.equal(size, 267693);
  const preservation = fixture.documents["docs/integrations/scoped-policy-preservation-v2.md"].text;
  assert.match(preservation, /TOKEN, RELEASE and SEASON/);
  assert.match(preservation, /does not require a snapshot, root,\nreference or inventory publication/);
  assert.match(fixture.documents["docs/integrations/scoped-policy-finality-v2.md"].text,
    /absent scoped head or completely empty V2 binding retains original scoped V1/);
});


test("five original writes and snapshot preview preserve actual method signatures and scopes", () => {
  const rows = [
    ["checkpoint", "begin", "c8b9e8ca", "begin(bytes32,bytes32)"],
    ["checkpoint", "append", "9f1dcd63", "append(bytes32,(uint256,bytes,bytes)[])"],
    ["output", "beginManifest", "1fe8e31c", "beginManifest(bytes32,bytes32,bytes32,bytes32)"],
    ["output", "verifyNextOutputs", "fe5dbcec", "verifyNextOutputs(bytes32,uint256)"],
    ["snapshot", "publishSnapshot", "178cc408", null]
  ];
  for (const [key, method, selector, signature] of rows) {
    const f = compiledInterfaces[key].getFunction(method);
    assert.equal(f.stateMutability, "nonpayable");
    assert.equal(f.selector.slice(2), selector);
    if (signature) assert.equal(f.format("sighash"), signature);
    assert.equal(f.selector, compiledInterfaces[key + "Interface"].getFunction(method).selector);
  }
  const preview = compiledInterfaces.snapshot.getFunction("previewSnapshot");
  const publish = compiledInterfaces.snapshot.getFunction("publishSnapshot");
  assert.equal(preview.stateMutability, "view");
  assert.equal(preview.selector, "0xffb836ac");
  assert.equal(preview.inputs[0].format("full"), publish.inputs[0].format("full"));
  assert.deepEqual(fields(publish.inputs[0]).map(row => row[0]),
    ["scope", "snapshotId", "expectedHead", "expectedRevision", "outputManifestRecord",
      "coordinatorInventoryPlan", "expectedSourceHash", "manifestURI", "effectiveAt", "reasonHash"]);
  assert.deepEqual(fields(publish.inputs[0].components[0]),
    [["scopeType", "uint8"], ["collectionId", "uint256"], ["tokenId", "uint256"], ["scopeId", "bytes32"]]);
  assert.equal(publish.inputs[0].components[3].type, "uint64");
  assert.equal(publish.inputs[0].components[8].type, "uint64");
});

test("original output and receipt layouts preserve full words, narrow widths and field names", () => {
  const output = compiledInterfaces.checkpoint.getFunction("outputAt").outputs[0];
  assert.equal(words(output), 20);
  assert.equal(words(compiledInterfaces.checkpoint.getFunction("checkpoint").outputs[0]), 13);
  assert.equal(words(compiledInterfaces.output.getFunction("manifestRecord").outputs[0]), 17);
  const [publication, receipt] = compiledInterfaces.snapshot.getFunction("snapshotRecord").outputs;
  assert.equal(words(receipt), 17);
  assert.deepEqual(fields(receipt), [
    ["recordHash", "bytes32"], ["scopeSubject", "bytes32"], ["predecessor", "bytes32"],
    ["revision", "uint64"], ["chainHash", "bytes32"], ["manifestHash", "bytes32"],
    ["manifestBytes", "uint32"], ["sourceHash", "bytes32"], ["publisher", "address"],
    ["authorizationClass", "uint8"], ["grantRevision", "uint64"],
    ["displayAuthorizationClass", "uint8"], ["displayGrantRevision", "uint64"],
    ["recordedAt", "uint64"], ["schemaHash", "bytes32"], ["profileHash", "bytes32"],
    ["canonicalizationHash", "bytes32"]
  ]);
  assert.equal(publication.format("sighash"),
    compiledInterfaces.snapshot.getFunction("publishSnapshot").inputs[0].format("sighash"));
  const event = compiledInterfaces.snapshot.getEvent("ScopedPolicySnapshotPublished");
  assert.deepEqual(event.inputs.map(p => [p.name, p.indexed]),
    [["schemaVersion", false], ["scopeSubject", true], ["snapshotId", true],
      ["recordHash", true], ["publication", false], ["receipt", false]]);
  assert.equal(event.inputs[4].format("sighash"), publication.format("sighash"));
  assert.equal(event.inputs[5].format("sighash"), receipt.format("sighash"));
});

test("snapshot source witness stays raw nominal library evidence with an independently proved enum width", () => {
  const raw = fixture.libraryAbis.snapshotSourceReads.find(f => f.name === "current");
  assert.equal(raw.inputs[1].components[0].components[0].type, "StreamFinalityScopeType");
  const enums = fixture.sourceTexts["smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol"];
  const declaration = /enum\s+StreamFinalityScopeType\s*\{([^}]*)\}/.exec(enums)?.[1];
  assert.ok(declaration);
  const names = declaration.replace(/\/\/[^\n]*/g, "").split(",").map(s => s.trim()).filter(Boolean);
  assert.deepEqual(names, ["COLLECTION", "TOKEN", "RELEASE", "SEASON", "VIEW"]);
  assert.ok(names.length <= 256);
  assert.deepEqual(raw.outputs[0].components.map(p => p.name),
    ["scope", "membership", "artist", "selection", "content", "outputs", "sourceFactory",
      "sourceFactoryCodeHash", "factoryDependenciesHash", "entropy"]);
  assert.equal(compiledInterfaces.snapshotSourceReads, undefined);
  assert.deepEqual(compiledLibraryEvents("snapshotSourceReads").fragments, []);
  assert.ok(!raw.outputs[0].components.some(p => /rootRecord|contentRootBinding/i.test(p.name)));
});

function originalStringConstant(source, name) {
  const match = new RegExp("string\\s+internal\\s+constant\\s+" + name + "\\s*=\\s*(\\\"(?:\\\\.|[^\\\"\\\\])*\\\")\\s*;").exec(source);
  assert.ok(match, name);
  return JSON.parse(match[1]);
}

test("registered snapshot definition bytes match original constants and documented canonical normalization", () => {
  const source = fixture.sourceTexts["smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol"];
  const rows = [
    ["SCHEMA", "schema", 3617],
    ["PROFILE", "profile", 1350],
    ["CANON", "abi", 970]
  ];
  for (const [key, suffix, size] of rows) {
    const literal = originalStringConstant(source, key + "_DOCUMENT");
    assert.equal(Buffer.byteLength(literal), size);
    const doc = fixture.documents["docs/schemas/preservation/scoped-policy-snapshot-v2." + suffix + ".json"];
    assert.equal(doc.text, literal);
    assert.equal(JSON.parse(literal).version, 2);
    assert.match(source, new RegExp(key + "_HASH = keccak256\\(bytes\\(" + key + "_DOCUMENT\\)\\)"));
  }
  const canon = JSON.parse(originalStringConstant(source, "CANON_DOCUMENT"));
  assert.equal(canon.domain, "keccak256(6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2)");
  assert.equal(canon.normalization, "publication.expectedSourceHash=0; receipt.recordHash,chainHash,manifestHash,manifestBytes,recordedAt=0; receipt.sourceHash is the actual complete source hash; other fields retained exactly");
  const profile = JSON.parse(originalStringConstant(source, "PROFILE_DOCUMENT"));
  assert.match(profile.bound, /policyCount positive and at most630/);
});

test("original output schema fixes offsets and complete ordered rows rather than generic JSON normalization", () => {
  const source = fixture.sourceTexts["smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol"];
  const documents = [...source.matchAll(/return bytes\(\s*'([^']*)'\s*\);/g)].map(m => JSON.parse(m[1]));
  assert.equal(documents.length, 3);
  const canon = documents.find(d => d.name === "STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2");
  assert.equal(canon.headBytes, 544);
  assert.equal(canon.arrayOffset, 544);
  assert.equal(canon.headerBytesIncludingArrayCount, 576);
  assert.equal(canon.rowBytes, 640);
  assert.equal(canon.trailingBytes, "Forbidden");
  assert.equal(canon.alternateOffsets, "Forbidden");
  assert.equal(Math.floor((64 * 8192 - 576) / 640), 818);
  assert.equal(canon.rowBytes, words(compiledInterfaces.checkpoint.getFunction("outputAt").outputs[0]) * 32);
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
  assert.equal(actual.length, expected.length, signature);
  for (let i = 0; i < expected.length; i++) {
    const a = actual[i], e = expected[i];
    assert.equal(a.format("sighash"), e.format("sighash"), signature);
    if (tuple) assert.equal(a.name, e.name, signature + "/" + e.name);
    if (e.baseType === "array") sameFields([a.arrayChildren], [e.arrayChildren], signature);
    if (e.baseType === "tuple") sameFields(a.components, e.components, signature, true);
  }
}



function ordinaryCodecWitness(param) {
  // The original five-member enum declaration above establishes uint8 ABI
  // representation. This creates only a codec comparison value; the retained
  // nominal library ABI and its selectors remain untouched.
  const copy = { ...param };
  if (copy.type === "StreamFinalityScopeType") {
    assert.equal(copy.internalType, "enum StreamFinalityScopeType");
    copy.type = "uint8";
  }
  if (copy.components) copy.components = copy.components.map(ordinaryCodecWitness);
  return copy;
}

test("client tuple literals retain every original nested field and width across publication stages", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-publication-v2.ts", import.meta.url));
  const c = compiledInterfaces;
  const token = c.selection.getFunction("selectionAt").outputs[0];
  const output = c.checkpoint.getFunction("outputAt").outputs[0];
  const entries = {
    SCOPE: c.snapshot.getFunction("publishSnapshot").inputs[0].components[0],
    DEPENDENCIES: c.snapshot.getFunction("dependencies").outputs[0],
    SELECTION_PLAN: c.selection.getFunction("checkpoint").outputs[0],
    RENDERER_SELECTION: token.components.find(p => p.name === "selection"),
    TOKEN_SELECTION: token,
    TOKEN_READINESS: output.components.find(p => p.name === "entropy"),
    TERMINAL_EVIDENCE: c.readiness.getFunction("requireTerminalRenderReady").outputs[0],
    LEAF: output.components.find(p => p.name === "leaf"),
    CONTENT_PLAN: c.checkpoint.getFunction("checkpoint").outputs[0],
    PAYLOAD: c.checkpoint.getFunction("append").inputs[1].arrayChildren,
    OUTPUT: output,
    MANIFEST: c.output.getFunction("manifestRecord").outputs[0],
    OUTPUT_PLAN: c.output.getFunction("manifestPlan").outputs[0],
    ARTIST_PRESENTATION: c.servingFacts.getFunction("artistPresentation").outputs[0],
    PUBLICATION: c.snapshot.getFunction("publishSnapshot").inputs[0],
    SOURCE: ParamType.from(ordinaryCodecWitness(fixture.libraryAbis.snapshotSourceReads.find(f => f.name === "current").outputs[0])),
    RECEIPT: c.snapshot.getFunction("snapshotRecord").outputs[1],
    LOCK: c.snapshot.getFunction("snapshotLock").outputs[0],
    COVERAGE: c.artifactCoverage.getFunction("requireArtifactCoverage").outputs[0]
  };
  assert.equal(Object.keys(entries).length, 19);
  for (const [name, expected] of Object.entries(entries)) {
    const actual = ParamType.from(read("SCOPED_POLICY_PUBLICATION_V2_" + name + "_TUPLE"));
    sameFields([actual], [expected], name);
  }
});

test("public client ABIs expose the exact five publication writes and original full event schemas", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-publication-v2.ts", import.meta.url));
  const methods = [];
  for (const [name, key] of [["CHECKPOINT", "checkpoint"], ["OUTPUT", "output"], ["SNAPSHOT", "snapshot"]]) {
    const iface = new Interface(read("SCOPED_POLICY_PUBLICATION_V2_" + name + "_ABI"));
    for (const fragment of iface.fragments) {
      const signature = fragment.format("sighash");
      const original = fragment.type === "event"
        ? compiledInterfaces[key].getEvent(signature) : compiledInterfaces[key].getFunction(signature);
      assert.ok(original, name + ":" + signature);
      assert.equal(fragment.format("full"), original.format("full"), name + ":" + signature);
      if (fragment.type === "function" && !["view", "pure"].includes(fragment.stateMutability)) {
        methods.push(fragment.name);
        assert.equal(fragment.stateMutability, "nonpayable");
      }
    }
  }
  assert.deepEqual(methods.sort(), ["append", "begin", "beginManifest", "publishSnapshot", "verifyNextOutputs"]);
});

test("workflow observation ABIs match complete original compiler fragments", () => {
  const url = new URL("../src/current-scoped-policy-publication-v2-workflow.ts", import.meta.url);
  const source = ts.createSourceFile(url.href, readFileSync(url, "utf8"), ts.ScriptTarget.Latest, true);
  const read = literalReader(url);
  const names = [];
  for (const statement of source.statements) {
    if (!ts.isVariableStatement(statement)) continue;
    for (const declaration of statement.declarationList.declarations) {
      if (!ts.isIdentifier(declaration.name) || !declaration.initializer
        || !ts.isNewExpression(declaration.initializer)
        || declaration.initializer.expression.getText(source) !== "Interface") continue;
      if (/^safe/i.test(declaration.name.text)) continue; // Independently checked transport, not a Stream ABI.
      names.push(declaration.name.text);
    }
  }
  assert.ok(names.length >= 12);
  for (const name of names) {
    const iface = new Interface(read(name));
    for (const fragment of iface.fragments) {
      const signature = fragment.format("sighash");
      const originals = Object.values(compiledInterfaces).flatMap(compiled => compiled.fragments.filter(original =>
        original.type === fragment.type && original.format("sighash") === signature));
      assert.ok(originals.length > 0, name + ":" + signature);
      assert.ok(originals.some(original => original.format("full") === fragment.format("full")), name + ":" + signature);
    }
  }
});

// These independent encoding vectors commit supplied facts. They do not assert
// that synthetic inputs passed deployed-source or writer-grant admission.
function originalExample(type, counter = { value: 10 }) {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(p => [p.name, originalExample(p, counter)]));
  if (type.baseType === "array") return Array.from({ length: type.arrayLength < 0 ? 2 : type.arrayLength },
    () => originalExample(type.arrayChildren, counter));
  const n = ++counter.value;
  if (type.type === "address") return getAddress("0x" + n.toString(16).padStart(40, "0"));
  if (type.type === "bool") return n % 2 === 0;
  if (type.type === "string") return "scope evidence " + n;
  if (type.type === "bytes") return "0xaabb";
  if (type.type.startsWith("bytes")) return "0x" + n.toString(16).padStart(Number(type.type.slice(5)) * 2, "0");
  if (type.type.startsWith("uint")) return Number(type.type.slice(4)) >= 128 ? (1n << 120n) + BigInt(n) : BigInt(n % 127 + 1);
  throw Error("Unsupported original example " + type.type);
}
const originalCoder = AbiCoder.defaultAbiCoder();
const hashOriginal = (types, values) => keccak256(originalCoder.encode(types, values));
const exampleAddress = n => getAddress("0x" + BigInt(n).toString(16).padStart(40, "0"));
const exampleHash = n => "0x" + BigInt(n).toString(16).padStart(64, "0");
const exampleCoordinates = () => ({
  chainId: (1n << 129n) + 6529n, core: exampleAddress(1), metadata: exampleAddress(2),
  checkpoint: exampleAddress(3), output: exampleAddress(4), snapshot: exampleAddress(5)
});
const exampleScope = () => ({ scopeType: 2n, collectionId: (1n << 130n) + 9n, tokenId: 0n, scopeId: exampleHash(7) });

test("checkpoint, selection and source-facts commitments use independently encoded original preimages", async () => {
  const p = await import("../dist/current-scoped-policy-publication-v2.js");
  const c = exampleCoordinates();
  const selectionType = compiledInterfaces.selection.getFunction("checkpoint").outputs[0];
  const selection = { ...originalExample(selectionType), scope: exampleScope(), tokenCount: 3n, nextIndex: 3n };
  const identity = { selectionCheckpoint: exampleAddress(6), selectionId: exampleHash(8), selection,
    entropySourceSet: exampleAddress(7), entropySourceSetCodeHash: exampleHash(9),
    terminalReadiness: exampleAddress(8), terminalReadinessCodeHash: exampleHash(10),
    inventoryHash: exampleHash(11), policyChainHash: exampleHash(12), salt: exampleHash(13) };
  const expected = hashOriginal(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "address",
    "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32"],
  [id("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2"), c.chainId, c.checkpoint, identity.selectionCheckpoint,
    identity.selectionId, hashOriginal([selectionType], [selection]), identity.entropySourceSet,
    identity.entropySourceSetCodeHash, identity.terminalReadiness, identity.terminalReadinessCodeHash,
    identity.inventoryHash, identity.policyChainHash, identity.salt]);
  assert.equal(p.scopedPolicyPublicationV2CheckpointId(c, identity), expected);
  assert.notEqual(p.scopedPolicyPublicationV2CheckpointId({ ...c, chainId: c.chainId + 1n }, identity), expected);
  assert.notEqual(p.scopedPolicyPublicationV2CheckpointId(c, { ...identity, salt: exampleHash(14) }), expected);
  assert.notEqual(p.scopedPolicyPublicationV2CheckpointId({ ...c, checkpoint: exampleAddress(99) }, identity), expected);
  const rowType = compiledInterfaces.selection.getFunction("selectionAt").outputs[0];
  const row = originalExample(rowType);
  const router = exampleAddress(9);
  assert.equal(p.scopedPolicyPublicationV2SelectionRowHash(c.chainId, c.core, router, row),
    hashOriginal(["bytes32", "uint256", "address", "address", rowType],
      [id("6529STREAM_STATIC_SELECTION_ROW_V1"), c.chainId, c.core, router, row]));
  const readinessType = compiledInterfaces.checkpoint.getFunction("outputAt").outputs[0].components.find(t => t.name === "entropy");
  const entropy = originalExample(readinessType);
  const facts = { configHash: exampleHash(15), rawSourceHash: exampleHash(16), coordinator: entropy.coordinator,
    entropy, entropySourceSet: identity.entropySourceSet, entropySourceSetCodeHash: identity.entropySourceSetCodeHash,
    inventoryHash: identity.inventoryHash, policyChainHash: identity.policyChainHash,
    terminalReadiness: identity.terminalReadiness, terminalReadinessCodeHash: identity.terminalReadinessCodeHash,
    terminalAdmissionHash: exampleHash(17) };
  const encodedFacts = originalCoder.encode([readinessType], [entropy]);
  assert.equal(p.scopedPolicyPublicationV2SourceFactsHash(facts),
    hashOriginal(["bytes32", "bytes32", "bytes32", "address", "bytes", "address", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32"],
      [id("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2"), facts.configHash, facts.rawSourceHash, facts.coordinator,
        encodedFacts, facts.entropySourceSet, facts.entropySourceSetCodeHash, facts.inventoryHash, facts.policyChainHash,
        facts.terminalReadiness, facts.terminalReadinessCodeHash, facts.terminalAdmissionHash]));
});

test("ordered content tree, rolling commitments and output archive bytes use original compiler tuples", async () => {
  const p = await import("../dist/current-scoped-policy-publication-v2.js");
  const c = exampleCoordinates();
  const outputType = compiledInterfaces.checkpoint.getFunction("outputAt").outputs[0];
  const contentType = compiledInterfaces.checkpoint.getFunction("checkpoint").outputs[0];
  const scopeType = contentType.components.find(t => t.name === "scope");
  const treeSource = fixture.sourceTexts["smart-contracts/domains/metadata/StreamTokenContentTree.sol"];
  const leafDomain = /LEAF_DOMAIN\s*=\s*(0x[0-9a-f]{64})/.exec(treeSource)[1];
  const nodeDomain = /NODE_DOMAIN\s*=\s*(0x[0-9a-f]{64})/.exec(treeSource)[1];
  const rows = [0, 1, 2].map(i => {
    const row = originalExample(outputType, { value: 10 + i * 40 });
    row.leaf.tokenId = (1n << 128n) + BigInt(i + 1);
    row.leaf.contentHash = ZeroHash;
    row.htmlHash = row.leaf.animationHash;
    row.entropy = { ...row.entropy, terminal: i === 0, finalized: i !== 0, status: i === 0 ? 1n : 5n,
      mode: i === 0 ? 0n : 2n, renderRequirement: i === 0 ? 1n : 0n, seed: i === 0 ? ZeroHash : exampleHash(80 + i) };
    row.terminalAdmissionHash = i === 0 ? exampleHash(90) : ZeroHash;
    return row;
  });
  const leafHashes = rows.map(row => hashOriginal(["bytes32", "uint256", "address", "uint256",
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
  [leafDomain, c.chainId, c.core, row.leaf.tokenId, row.leaf.metadataHash, row.leaf.imageHash,
    row.leaf.animationHash, row.leaf.contentHash, row.leaf.tokenDataHash]));
  const node = (a, b) => hashOriginal(["bytes32", "bytes32", "bytes32"], [nodeDomain, a, b]);
  const expectedRoot = node(node(leafHashes[0], leafHashes[1]), leafHashes[2]);
  assert.equal(p.scopedPolicyPublicationV2ContentRoot(c.chainId, c.core, rows.map(row => row.leaf)), expectedRoot);
  assert.notEqual(expectedRoot, node(node(leafHashes[0], leafHashes[1]), node(leafHashes[2], leafHashes[2])));
  let leafChain = ZeroHash, outputRoot = ZeroHash;
  rows.forEach((row, i) => {
    const nextLeaf = hashOriginal(["bytes32", "bytes32", "uint256", "bytes32"],
      [id("6529STREAM_SCOPED_POLICY_CONTENT_LEAVES_V2"), leafChain, i, leafHashes[i]]);
    const nextOutput = hashOriginal(["bytes32", "bytes32", "uint256", outputType],
      [id("6529STREAM_SCOPED_POLICY_FULL_OUTPUTS_V2"), outputRoot, i, row]);
    assert.equal(p.scopedPolicyPublicationV2LeafChain(leafChain, BigInt(i), leafHashes[i]), nextLeaf);
    assert.equal(p.scopedPolicyPublicationV2OutputChain(outputRoot, BigInt(i), row), nextOutput);
    leafChain = nextLeaf; outputRoot = nextOutput;
  });
  const content = { ...originalExample(contentType), scope: exampleScope(), tokenCount: 3n, nextIndex: 3n,
    leafChainHash: leafChain, contentRoot: expectedRoot, outputRoot };
  const checkpointHash = exampleHash(91), set = exampleAddress(92);
  const types = ["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "address",
    "bytes32", "bytes32", scopeType, "bytes32", "bytes32", "uint64", ParamType.from({ type: "tuple[]",
      components: fixture.abis.checkpoint.find(f => f.name === "outputAt").outputs[0].components })];
  const expectedBytes = originalCoder.encode(types, [id("STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2"), c.chainId,
    c.core, c.checkpoint, checkpointHash, hashOriginal([contentType], [content]), set, content.inventoryHash,
    content.policyChainHash, content.scope, expectedRoot, outputRoot, 3n, rows]);
  assert.equal(p.scopedPolicyPublicationV2OutputManifestBytes(c, checkpointHash, content, set, rows), expectedBytes);
  assert.equal((expectedBytes.length - 2) / 2, 576 + 640 * 3);
  assert.equal(BigInt("0x" + expectedBytes.slice(2 + 16 * 64, 2 + 17 * 64)), 544n);
  assert.equal(BigInt("0x" + expectedBytes.slice(2 + 17 * 64, 2 + 18 * 64)), 3n);
  assert.deepEqual(p.decodeScopedPolicyPublicationV2OutputManifestBytes(expectedBytes).rows, rows);
  assert.throws(() => p.decodeScopedPolicyPublicationV2OutputManifestBytes(expectedBytes + "00".repeat(32)));
  const altered = structuredClone(rows); altered[1].sourceFactsHash = exampleHash(93);
  assert.throws(() => p.scopedPolicyPublicationV2OutputManifestBytes(c, checkpointHash, content, set, altered));
  const manifestType = compiledInterfaces.output.getFunction("manifestRecord").outputs[0];
  const coverageType = compiledInterfaces.artifactCoverage.getFunction("requireArtifactCoverage").outputs[0];
  const coverage = { ...originalExample(coverageType), schemaId: id("STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2"),
    canonicalizationId: id("STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2"),
    contentHash: keccak256(expectedBytes), byteLength: BigInt((expectedBytes.length - 2) / 2), chunkCount: 1n };
  const manifest = { checkpointHash, checkpointStateHash: hashOriginal([contentType], [content]),
    entropySourceSet: set, inventoryHash: content.inventoryHash, policyChainHash: content.policyChainHash,
    artifactHash: coverage.artifactHash, coverageHash: coverage.completionHash, artistId: coverage.artistId,
    contentRoot: expectedRoot, outputRoot, manifestHash: coverage.contentHash, scope: content.scope,
    tokenCount: 3n, byteLength: coverage.byteLength };
  assert.deepEqual(p.scopedPolicyPublicationV2Manifest(c, checkpointHash, content, set, coverage), manifest);
  const coverageHost = exampleAddress(94);
  const plan = hashOriginal(["bytes32", "uint256", "address", "address", "address", "address", manifestType],
    [id("6529STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_PLAN_V2"), c.chainId, c.output, c.core, c.checkpoint, coverageHost, manifest]);
  assert.equal(p.scopedPolicyPublicationV2ManifestPlanHash(c, coverageHost, manifest), plan);
  assert.equal(p.scopedPolicyPublicationV2ManifestRecordHash(plan),
    hashOriginal(["bytes32", "bytes32"], [id("6529STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_VERIFIED_V2"), plan]));
});

test("root-free snapshot source, canonical payload, mined record and chain use separate original preimages", async () => {
  const p = await import("../dist/current-scoped-policy-publication-v2.js");
  const c = exampleCoordinates();
  const dependenciesType = compiledInterfaces.snapshot.getFunction("dependencies").outputs[0];
  const publicationType = compiledInterfaces.snapshot.getFunction("publishSnapshot").inputs[0];
  const receiptType = compiledInterfaces.snapshot.getFunction("snapshotRecord").outputs[1];
  const sourceType = ParamType.from(ordinaryCodecWitness(fixture.libraryAbis.snapshotSourceReads.find(f => f.name === "current").outputs[0]));
  const d = originalExample(dependenciesType);
  d.chainId = c.chainId; d.targets[0] = c.core; d.targets[1] = c.metadata;
  const f = originalExample(sourceType);
  f.scope = exampleScope();
  f.selection.scope = exampleScope();
  f.content.scope = exampleScope();
  f.outputs.scope = exampleScope();
  const publication = { ...originalExample(publicationType), scope: f.scope, manifestURI: "ipfs://example/作品",
    expectedRevision: (1n << 63n) + 9n, effectiveAt: 123n };
  const receipt = { ...originalExample(receiptType), revision: publication.expectedRevision + 1n,
    recordedAt: (1n << 63n) + 17n };
  const sourceHash = hashOriginal(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", sourceType],
    [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"), c.chainId, c.snapshot, d.targets, d.codeHashes, f]);
  assert.equal(p.scopedPolicyPublicationV2SourceHash(c, d, f), sourceHash);
  publication.expectedSourceHash = sourceHash;
  receipt.sourceHash = sourceHash;
  const canonical = originalCoder.encode(["bytes32", "uint256", "address", "address[11]", "bytes32[11]",
    publicationType, receiptType, sourceType],
  [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2"), c.chainId, c.snapshot, d.targets, d.codeHashes,
    { ...publication, expectedSourceHash: ZeroHash }, { ...receipt, recordHash: ZeroHash, chainHash: ZeroHash,
      manifestHash: ZeroHash, manifestBytes: 0n, recordedAt: 0n }, f]);
  assert.equal(p.scopedPolicyPublicationV2SnapshotBytes(c, d, publication, receipt, f), canonical);
  const decoded = p.decodeScopedPolicyPublicationV2SnapshotBytes(canonical);
  assert.deepEqual(decoded.source, f);
  assert.equal(decoded.receipt.sourceHash, sourceHash);
  assert.equal(decoded.publication.expectedSourceHash, ZeroHash);
  assert.throws(() => p.decodeScopedPolicyPublicationV2SnapshotBytes(canonical + "00".repeat(32)));
  const mined = { ...receipt, manifestHash: keccak256(canonical), manifestBytes: BigInt((canonical.length - 2) / 2) };
  const recordHash = hashOriginal(["bytes32", "uint256", "address", "address", "address", publicationType, receiptType],
    [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_RECORD_V2"), c.chainId, c.snapshot, c.core, c.metadata,
      publication, { ...mined, recordHash: ZeroHash, chainHash: ZeroHash }]);
  assert.equal(p.scopedPolicyPublicationV2SnapshotRecordHash(c, publication, mined), recordHash);
  assert.notEqual(p.scopedPolicyPublicationV2SnapshotRecordHash(c, publication, { ...mined, recordedAt: mined.recordedAt + 1n }), recordHash);
  assert.notEqual(p.scopedPolicyPublicationV2SnapshotRecordHash(c, { ...publication, expectedSourceHash: exampleHash(299) }, mined), recordHash);
  assert.equal(p.scopedPolicyPublicationV2SnapshotBytes(c, d, publication, { ...mined, recordedAt: mined.recordedAt + 1n }, f), canonical);
  const previousChain = exampleHash(301);
  const chainHash = hashOriginal(["bytes32", "uint256", "address", "address", publicationType.components[0], "bytes32", "uint64", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_CHAIN_V2"), c.chainId, c.snapshot, c.core, publication.scope,
      previousChain, mined.revision, recordHash]);
  assert.equal(p.scopedPolicyPublicationV2SnapshotChainHash(c, publication.scope, previousChain, mined.revision, recordHash), chainHash);
  assert.notEqual(p.scopedPolicyPublicationV2SnapshotChainHash(c, { ...publication.scope, collectionId: publication.scope.collectionId + 1n },
    previousChain, mined.revision, recordHash), chainHash);
  const codeHashes = [...d.codeHashes]; codeHashes[4] = exampleHash(302);
  assert.notEqual(p.scopedPolicyPublicationV2SourceHash(c, { ...d, codeHashes }, f), sourceHash);
});

test("snapshot chunk prerequisites use exact contiguous bytes and STOP-prefixed runtime commitments", async () => {
  const p = await import("../dist/current-scoped-policy-publication-v2.js");
  const canonical = "0x" + "ab".repeat(8192) + "cd".repeat(7);
  const chunks = p.scopedPolicyPublicationV2Chunks(canonical);
  assert.equal(chunks.length, 2);
  assert.deepEqual(chunks.map(c => c.byteLength), [8192n, 7n]);
  assert.equal("0x" + chunks.map(c => c.data.slice(2)).join(""), canonical);
  chunks.forEach((chunk, i) => {
    assert.equal(chunk.index, BigInt(i));
    assert.equal(chunk.hash, keccak256(chunk.data));
    assert.equal(chunk.runtime, "0x00" + chunk.data.slice(2));
    assert.equal(chunk.runtimeHash, keccak256("0x00" + chunk.data.slice(2)));
  });
});
