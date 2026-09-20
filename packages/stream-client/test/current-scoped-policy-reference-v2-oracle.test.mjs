import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, sha256, toUtf8Bytes } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledInterfaces, compiledLibraryEvents } from "./current-scoped-policy-reference-v2-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const fields = tuple => tuple.components.map(p => [p.name, p.type]);
const words = type => type.baseType === "tuple"
  ? type.components.reduce((n, p) => n + words(p), 0)
  : type.baseType === "array" ? type.arrayLength * words(type.arrayChildren) : 1;

test("scoped reference witness retains the exact ABI129 committed source and evidence boundary", () => {
  assert.equal(fixture.profile, "scoped-policy-reference-v2");
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
  assert.match(fixture.qualification, /original scoped full-policy reference preparation and publication/);
  assert.match(fixture.qualification, /Native\/Safe execution.*remain separately qualified/);
});

test("all ordinary contract and interface selectors retain complete compiler ABIs", () => {
  assert.equal(Object.keys(fixture.abis).length, 118);
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 3860);
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
  assert.equal(selectors, 2623);
});

test("nominal fixed deployment and reader libraries stay separate from wallet calls", () => {
  assert.equal(Object.keys(fixture.libraryAbis).length, 42);
  assert.equal(Object.values(fixture.libraryAbis).reduce((n, a) => n + a.length, 0), 178);
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
  assert.equal(count, 123);
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
  assert.equal(visited.size, 1287);
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, text) => n + Buffer.byteLength(text), 0), 8544426);
});

test("original documents retain scope and acyclic preparation/publication boundaries", () => {
  assert.equal(Object.keys(fixture.documents).length, 36);
  let size = 0;
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
    size += document.byteLength;
  }
  assert.equal(size, 715300);
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
  if (type.type.startsWith("uint")) return type.name === "scopeType" ? 2n
    : Number(type.type.slice(4)) >= 128 ? (1n << 120n) + BigInt(n) : BigInt(n % 127 + 1);
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
  chainId: (1n << 129n) + 6529n, core: exampleAddress(1), metadata: exampleAddress(2), reference: exampleAddress(3)
});
const exampleScope = () => ({ scopeType: 2n, collectionId: (1n << 130n) + 9n, tokenId: 0n, scopeId: exampleHash(7) });

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

test("original scoped reference retains the exact five preparation/publication selectors and distinct governance", () => {
  const selectors = {
    prepareEnvironment: "e5dc1cfc", prepareFileInventory: "c7ca6887", prepareFileInventoryPart: "33fda048",
    prepareFileInventoryFromParts: "3b1c5322", publishReference: "3d620828", previewReference: "c3b2c07f",
    preparedFileInventory: "280885af", referenceRecord: "f84137a7", referencePayload: "c1385b3b",
    referenceSource: "6ccc1644", currentReference: "03760025", requireCurrent: "d09430c8",
    referenceCount: "aa44c136", referenceAt: "2bc35419", referenceLock: "ffbbb3f6",
  };
  for (const [name, selector] of Object.entries(selectors)) {
    const method = compiledInterfaces.reference.getFunction(name);
    assert.equal(method.selector, "0x" + selector, name);
    assert.equal(fixture.methodIdentifiers.reference[method.format("sighash")], selector);
    assert.equal(method.stateMutability, Object.keys(selectors).indexOf(name) < 5 ? "nonpayable" : "view");
  }
  assert.deepEqual(compiledInterfaces.reference.getFunction("previewReference").outputs.map(p => [p.name, p.type]),
    [["sourceHash", "bytes32"], ["canonical", "bytes"]]);
  const writes = compiledInterfaces.reference.fragments.filter(f => f.type === "function"
    && !["pure", "view"].includes(f.stateMutability)).map(f => f.name).sort();
  assert.deepEqual(writes, ["lockReference", "prepareEnvironment", "prepareFileInventory", "prepareFileInventoryFromParts",
    "prepareFileInventoryPart", "publishReference", "raiseGasParameter"]);
  const ownSource = fixture.sourceTexts[fixture.selections.referenceInterface.source];
  const ownNames = [...ownSource.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(match => match[1]);
  assert.equal(ownNames.length, 21);
  const ownId = ownNames.reduce((value, name) => value ^ BigInt(compiledInterfaces.referenceInterface.getFunction(name).selector), 0n);
  assert.equal("0x" + ownId.toString(16).padStart(8, "0"), "0xc6e43ef2");
  assert.ok(!ownNames.includes("supportsInterface"));
});

test("complete original dependency, source, scoped publication and receipt fields remain separate", () => {
  const abi = compiledInterfaces.reference;
  assert.deepEqual(fields(abi.getFunction("dependencies").outputs[0]), [
    ["targets", "address[7]"], ["codeHashes", "bytes32[7]"], ["chainId", "uint256"], ["readGas", "uint256"],
    ["sourceGas", "uint256"], ["snapshotGas", "uint256"], ["archiveGas", "uint256"],
  ]);
  const publication = abi.getFunction("publishReference").inputs[0];
  assert.deepEqual(fields(publication), [["scope", "tuple"], ["observation", "tuple"]]);
  assert.equal(publication.components[1].components.length, 12);
  const source = abi.getFunction("referenceSource").outputs[0];
  assert.deepEqual(source.components.map(p => p.name), ["scopeSubject", "snapshot", "snapshotSource", "contentRootRecordHash",
    "contentRoot", "contentRootBinding", "environmentCoverage", "samples"]);
  assert.equal(source.components[1].components.length, 17);
  assert.equal(source.components[5].components.length, 23);
  assert.equal(source.components[6].components.length, 15);
  assert.deepEqual(source.components[7].arrayChildren.components.map(p => p.name),
    ["membershipIndex", "observation", "selection", "entropy", "terminalAdmissionHash"]);
  assert.equal(source.components[7].arrayChildren.components[0].type, "uint64");
  sameFields([source.components[4]], [compiledInterfaces.router.getFunction("scopedContentRootRecord").outputs[0]], "root record");
  sameFields([source.components[5]], [compiledInterfaces.router.getFunction("scopedPolicyContentRootBinding").outputs[0]], "V2 binding");
  assert.notEqual(fixture.selections.externalCoverage.contract, fixture.selections.artifactCoverage.contract);
  assert.equal(fixture.selections.externalCoverage.contract, "StreamExternalArtifactCoverage");
});

test("the three original scoped reference document bytes match Solidity IDs, lengths and hashes", () => {
  const source = fixture.sourceTexts["smart-contracts/domains/records/StreamScopedPolicyReferenceDefinitionsV2.sol"];
  for (const [suffix, prefix, length] of [["schema", "SCHEMA", 26018], ["profile", "PROFILE", 2114], ["abi", "CANON", 1412]]) {
    const document = fixture.documents["docs/schemas/preservation/scoped-policy-reference-v2." + suffix + ".json"];
    const hash = new RegExp(prefix + "_HASH\\s*=\\s*(0x[0-9a-f]{64})").exec(source)[1];
    const name = new RegExp(prefix + '_ID = keccak256\\("([^\"]+)"\\)').exec(source)[1];
    assert.equal(keccak256(Buffer.from(document.text, "utf8")), hash);
    assert.equal(document.byteLength, length);
    assert.match(source, new RegExp(prefix + "_BYTES = " + length));
    assert.equal(JSON.parse(document.text).name, name);
  }
  const canonical = JSON.parse(fixture.documents["docs/schemas/preservation/scoped-policy-reference-v2.abi.json"].text);
  assert.match(canonical.normalization, /sourcesHash remains populated/);
  assert.match(canonical.recordHash, /publication,receiptWithObservationRecordHashAndChainHashZero/);
  assert.match(canonical.canonical, /outer payload is not JCS/);
  const profile = JSON.parse(fixture.documents["docs/schemas/preservation/scoped-policy-reference-v2.profile.json"].text);
  assert.match(profile.authority, /CURATOR class3 collection or class8 global/);
  assert.match(profile.environment, /original current-pair semantics/);
  assert.match(profile.unproven, /do not prove all-token rendering conformance/);
});

test("every pure reference tuple preserves original field names, widths and full nested shapes", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-reference-v2.ts", import.meta.url));
  const original = compiledInterfaces.reference;
  const publication = original.getFunction("publishReference").inputs[0];
  const observation = publication.components[1];
  const receipt = original.getFunction("referenceRecord").outputs[1];
  const source = original.getFunction("referenceSource").outputs[0];
  const sample = source.components[7].arrayChildren;
  const tuples = {
    SCOPE: publication.components[0],
    ENVIRONMENT: original.getFunction("prepareEnvironment").inputs[0],
    PACKAGE_FILE: original.getFunction("prepareFileInventory").inputs[0].arrayChildren,
    DEPENDENCIES: original.getFunction("dependencies").outputs[0],
    CAPTURE: observation.components[7].arrayChildren,
    OBSERVATION_PUBLICATION: observation,
    PUBLICATION: publication,
    OBSERVATION_RECEIPT: receipt.components[1],
    RECEIPT: receipt,
    COVERAGE: source.components[6],
    SAMPLE_FACTS: sample.components[1],
    SAMPLE: sample,
    SOURCE_FACTS: source,
    LOCK: original.getFunction("referenceLock").outputs[0],
  };
  assert.equal(Object.keys(tuples).length, 14);
  for (const [suffix, expected] of Object.entries(tuples)) {
    const constant = "SCOPED_POLICY_REFERENCE_V2_" + suffix + "_TUPLE";
    sameFields([ParamType.from(read(constant))], [expected], constant);
  }
  sameFields(read("SCOPED_POLICY_REFERENCE_V2_PAYLOAD_TYPES").map(ParamType.from),
    ["bytes32", "uint256", "address", publication, receipt, source, "bytes"].map(ParamType.from), "payload");
});

function originalReferenceVector() {
  const abi = compiledInterfaces.reference;
  const types = {
    dependencies: abi.getFunction("dependencies").outputs[0],
    publication: abi.getFunction("publishReference").inputs[0],
    receipt: abi.getFunction("referenceRecord").outputs[1],
    source: abi.getFunction("referenceSource").outputs[0],
  };
  const c = exampleCoordinates();
  const d = { ...originalExample(types.dependencies), chainId: c.chainId };
  const publication = originalExample(types.publication);
  publication.scope = exampleScope();
  publication.observation.collectionId = publication.scope.collectionId;
  publication.observation.manifestURI = "ipfs://reference/作品";
  const receipt = originalExample(types.receipt), source = originalExample(types.source);
  return { c, d, publication, receipt, source, types };
}

test("reference source hash binds all seven targets and pins plus every full supplied source fact", async () => {
  const p = await import("../dist/current-scoped-policy-reference-v2.js");
  const { c, d, source, types } = originalReferenceVector();
  const expected = hashOriginal(["bytes32", "uint256", "address", "address[7]", "bytes32[7]", types.source],
    [id("6529STREAM_SCOPED_POLICY_REFERENCE_SOURCES_V2"), c.chainId, c.reference, d.targets, d.codeHashes, source]);
  assert.equal(p.scopedPolicyReferenceV2SourceHash(c, d, source), expected);
  assert.equal(p.scopedPolicyReferenceV2SourceHash(c, { ...d, readGas: d.readGas + 1n, archiveGas: d.archiveGas + 1n }, source), expected);
  for (let i = 0; i < 7; i++) {
    const changed = structuredClone(d);
    changed.targets[i] = exampleAddress(900 + i);
    assert.notEqual(p.scopedPolicyReferenceV2SourceHash(c, changed, source), expected);
    changed.targets[i] = d.targets[i]; changed.codeHashes[i] = exampleHash(910 + i);
    assert.notEqual(p.scopedPolicyReferenceV2SourceHash(c, changed, source), expected);
  }
  for (const change of [
    f => { f.contentRootRecordHash = exampleHash(920); },
    f => { f.contentRootBinding.checkpointStateHash = exampleHash(921); },
    f => { f.environmentCoverage.firstFixityHash = exampleHash(922); },
    f => { f.samples[0].entropy.seed = exampleHash(923); },
    f => { f.samples[1].membershipIndex += 1n; },
  ]) {
    const changed = structuredClone(source); change(changed);
    assert.notEqual(p.scopedPolicyReferenceV2SourceHash(c, d, changed), expected);
  }
  assert.notEqual(p.scopedPolicyReferenceV2SourceHash({ ...c, reference: exampleAddress(999) }, d, source), expected);
  assert.throws(() => p.scopedPolicyReferenceV2SourceHash(c, { ...d, chainId: c.chainId + 1n }, source));
});

test("canonical reference payload clears exactly one publication and five receipt fields", async () => {
  const p = await import("../dist/current-scoped-policy-reference-v2.js");
  const { c, publication, receipt, source, types } = originalReferenceVector();
  const environmentBytes = "0x7b226e616d65223a22e4bd9ce59381227d";
  const normalizedPublication = { ...publication, observation: { ...publication.observation, expectedSourcesHash: ZeroHash } };
  const normalizedReceipt = { ...receipt, observation: { ...receipt.observation, recordHash: ZeroHash,
    recordChainHash: ZeroHash, payloadHash: ZeroHash, payloadBytes: 0n, recordedAt: 0n } };
  const payloadTypes = ["bytes32", "uint256", "address", types.publication, types.receipt, types.source, "bytes"];
  const expected = originalCoder.encode(payloadTypes, [id("6529STREAM_SCOPED_POLICY_REFERENCE_PAYLOAD_V2"),
    c.chainId, c.reference, normalizedPublication, normalizedReceipt, source, environmentBytes]);
  assert.equal(p.scopedPolicyReferenceV2PayloadBytes(c, publication, receipt, source, environmentBytes), expected);
  const changed = structuredClone(receipt);
  for (const name of ["recordHash", "recordChainHash", "payloadHash"]) changed.observation[name] = exampleHash(999);
  changed.observation.payloadBytes = 999n; changed.observation.recordedAt = 999n;
  assert.equal(p.scopedPolicyReferenceV2PayloadBytes(c, { ...publication, observation: {
    ...publication.observation, expectedSourcesHash: exampleHash(998) } }, changed, source, environmentBytes), expected);
  for (const patch of [{ sourcesHash: exampleHash(1000) }, { recorder: exampleAddress(1001) }, { grantRevision: 1002n }]) {
    assert.notEqual(p.scopedPolicyReferenceV2PayloadBytes(c, publication,
      { ...receipt, observation: { ...receipt.observation, ...patch } }, source, environmentBytes), expected);
  }
  const decoded = p.decodeScopedPolicyReferenceV2Payload(expected);
  assert.deepEqual(decoded, { chainId: c.chainId, reference: c.reference, publication: normalizedPublication,
    receipt: normalizedReceipt, source, environmentBytes });
  assert.throws(() => p.decodeScopedPolicyReferenceV2Payload(expected + "00".repeat(32)));
  const wrongTag = originalCoder.encode(payloadTypes, [id("OTHER_REFERENCE_PROFILE"),
    c.chainId, c.reference, normalizedPublication, normalizedReceipt, source, environmentBytes]);
  assert.throws(() => p.decodeScopedPolicyReferenceV2Payload(wrongTag));
});

test("mined reference record and scoped chain retain submitted source commitment and mined time", async () => {
  const p = await import("../dist/current-scoped-policy-reference-v2.js");
  const { c, publication, receipt, types } = originalReferenceVector();
  receipt.observation.revision = (1n << 63n) + 13n;
  receipt.observation.recordedAt = (1n << 63n) + 19n;
  const expected = hashOriginal(["bytes32", "uint256", "address", "address", "address", types.publication, types.receipt],
    [id("6529STREAM_SCOPED_POLICY_REFERENCE_RECORD_V2"), c.chainId, c.reference, c.core, c.metadata, publication,
      { ...receipt, observation: { ...receipt.observation, recordHash: ZeroHash, recordChainHash: ZeroHash } }]);
  assert.equal(p.scopedPolicyReferenceV2RecordHash(c, publication, receipt), expected);
  assert.equal(p.scopedPolicyReferenceV2RecordHash(c, publication, { ...receipt, observation: {
    ...receipt.observation, recordHash: exampleHash(1001), recordChainHash: exampleHash(1002) } }), expected);
  assert.notEqual(p.scopedPolicyReferenceV2RecordHash(c, publication, { ...receipt, observation: {
    ...receipt.observation, recordedAt: receipt.observation.recordedAt + 1n } }), expected);
  assert.notEqual(p.scopedPolicyReferenceV2RecordHash(c, { ...publication, observation: {
    ...publication.observation, expectedSourcesHash: ZeroHash } }, receipt), expected);
  const scope = publication.scope, previous = exampleHash(1003);
  const subject = hashOriginal(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
    [id("6529STREAM_SUBJECT_SCOPE_V1"), c.chainId, c.core, scope.collectionId, scope.scopeType, scope.scopeId]);
  const chain = hashOriginal(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint64", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_REFERENCE_CHAIN_V2"), c.chainId, c.reference, c.core, subject, previous,
      receipt.observation.revision, expected]);
  assert.equal(p.scopedPolicyReferenceV2ChainHash(c, scope, previous, receipt.observation.revision, expected), chain);
  assert.notEqual(p.scopedPolicyReferenceV2ChainHash(c, { ...scope, scopeId: exampleHash(1004) }, previous,
    receipt.observation.revision, expected), chain);
  assert.throws(() => p.scopedPolicyReferenceV2ChainHash(c, scope, previous, 1n << 64n, expected));
});

test("reference structural codecs and both retained byte streams use original canonical encodings", async () => {
  const p = await import("../dist/current-scoped-policy-reference-v2.js");
  const { c, d, publication, receipt, source, types } = originalReferenceVector();
  for (const [name, value, type] of [["Dependencies", d, types.dependencies], ["Publication", publication, types.publication],
    ["Receipt", receipt, types.receipt], ["SourceFacts", source, types.source]]) {
    const encoded = originalCoder.encode([type], [value]);
    assert.equal(p["encodeScopedPolicyReferenceV2" + name](value), encoded);
    assert.deepEqual(p["decodeScopedPolicyReferenceV2" + name](encoded), value);
    assert.throws(() => p["decodeScopedPolicyReferenceV2" + name](encoded + "00".repeat(32)));
  }
  const submitted = originalCoder.encode([types.publication], [publication]);
  const payload = p.scopedPolicyReferenceV2PayloadBytes(c, publication, receipt, source, "0x7b7d");
  assert.notEqual(keccak256(submitted), keccak256(payload));
  for (const raw of [submitted, payload, "0x" + "ab".repeat(8193)]) {
    const expected = [];
    for (let offset = 2; offset < raw.length; offset += 8192 * 2) expected.push("0x" + raw.slice(offset, offset + 8192 * 2));
    assert.deepEqual(p.scopedPolicyReferenceV2Chunks(raw), expected.map((data, index) => ({
      index: BigInt(index), data, hash: keccak256(data), byteLength: BigInt((data.length - 2) / 2),
      runtime: "0x00" + data.slice(2), runtimeHash: keccak256("0x00" + data.slice(2)),
    })));
    assert.equal("0x" + expected.map(chunk => chunk.slice(2)).join(""), raw);
  }
});

test("reference public ABI fragments retain original hosts and expose exactly five writes", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-reference-v2.ts", import.meta.url));
  const iface = new Interface(read("SCOPED_POLICY_REFERENCE_V2_ABI"));
  const originals = [compiledInterfaces.reference, compiledLibraryEvents("referenceRenderPreparation"),
    compiledLibraryEvents("referenceInventoryPreparationLibrary"), compiledLibraryEvents("scopedPolicyReferenceRecordsV2")];
  const writes = [];
  for (const fragment of iface.fragments) {
    const signature = fragment.format("sighash");
    const matches = originals.flatMap(original => original.fragments).filter(candidate =>
      candidate.type === fragment.type && candidate.format("sighash") === signature);
    assert.ok(matches.some(original => {
      try { compatibleFragment(fragment, original); return true; } catch { return false; }
    }), signature);
    if (fragment.type === "function" && !["view", "pure"].includes(fragment.stateMutability)) writes.push(fragment.name);
  }
  assert.deepEqual(writes.sort(), ["prepareEnvironment", "prepareFileInventory", "prepareFileInventoryFromParts",
    "prepareFileInventoryPart", "publishReference"]);
});

test("reference workflow reads and events match original compiler layouts and full return shapes", () => {
  const url = new URL("../src/current-scoped-policy-reference-v2-workflow.ts", import.meta.url);
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
  assert.ok(names.includes("hostAbi") && names.includes("coverageAbi") && names.includes("rendererAbi") && names.includes("eventAbi"));
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

test("three inventory planners retain exact original JSON, domain identities and compiled calldata", async () => {
  const p = await import("../dist/current-scoped-policy-reference-v2.js");
  const c = exampleCoordinates(), caller = exampleAddress(4);
  const rows = [{ path: "a.bin", byteSize: 0n, sha256Digest: exampleHash(20) },
    { path: "z.bin", byteSize: (1n << 64n) - 1n, sha256Digest: exampleHash(21) }];
  const rowType = compiledInterfaces.reference.getFunction("prepareFileInventory").inputs[0];
  const canonical = "0x" + Buffer.from(JSON.stringify(rows.map(row => ({
    byteSize: row.byteSize.toString(), path: row.path, sha256Digest: row.sha256Digest,
  }))), "utf8").toString("hex");
  for (const kind of ["prepareFileInventory", "prepareFileInventoryPart", "prepareFileInventoryFromParts"]) {
    const request = { kind, rows, relative: true };
    const plan = p.prepareScopedPolicyReferenceV2Call(c, caller, request);
    const domain = kind === "prepareFileInventoryPart" ? "6529STREAM_REFERENCE_FILE_INVENTORY_PART_V1"
      : "6529STREAM_REFERENCE_FILE_INVENTORY_V1";
    const identity = hashOriginal(["bytes32", "uint256", "address", "bool", rowType], [id(domain), c.chainId, c.reference, true, rows]);
    assert.deepEqual(plan.call, { to: c.reference, value: 0n, data: compiledInterfaces.reference.encodeFunctionData(kind, [rows, true]) });
    assert.deepEqual(plan.preparation, { id: identity, canonical, contentHash: keccak256(canonical), byteLength: BigInt((canonical.length - 2) / 2) });
    assert.equal(plan.factsVerified, false);
    assert.deepEqual(p.normalizeScopedPolicyReferenceV2Call(structuredClone(plan)), plan);
  }
  for (const kind of ["prepareFileInventory", "prepareFileInventoryFromParts"]) {
    assert.equal(p.prepareScopedPolicyReferenceV2Call(c, caller, { kind, rows: [], relative: true }).preparation.canonical, "0x5b5d");
  }
  assert.throws(() => p.prepareScopedPolicyReferenceV2Call(c, caller, { kind: "prepareFileInventoryPart", rows: [], relative: true }));
  assert.throws(() => p.prepareScopedPolicyReferenceV2Call(c, caller, { kind: "lockReference", rows, relative: true }));
});

async function admittedReferenceDraft() {
  const { referenceEnvironmentCanonicalBytes } = await import("../dist/current-reference-environment.js");
  const environment = {
    objectHash: exampleHash(50), coverageHash: exampleHash(51), manifestHash: ZeroHash, manifestBytes: 0n,
    engineName: "Browser", engineVersion: "1", engineExecutableSha256: exampleHash(52),
    toolchainName: "Capture", toolchainVersion: "1", toolchainSha256: exampleHash(53),
    engineExecutablePath: "engine.exe", toolchainPath: "tool.exe",
    packageFiles: [{ path: "engine.exe", byteSize: 1n, sha256Digest: exampleHash(52) },
      { path: "tool.exe", byteSize: 1n, sha256Digest: exampleHash(53) }],
    platformPrerequisites: [{ path: "Windows runtime", byteSize: 0n, sha256Digest: exampleHash(54) }],
    operatingSystem: "Windows", operatingSystemVersion: "Server", architecture: "AMD64",
    viewportWidth: 1920n, viewportHeight: 1080n, devicePixelRatio: 1n, colorSpace: "srgb", softwareRasterization: true,
    captureProfile: id("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"), licenseNote: "Recorded license evidence",
  };
  const environmentBytes = referenceEnvironmentCanonicalBytes(environment);
  environment.manifestHash = keccak256(environmentBytes);
  environment.manifestBytes = BigInt((environmentBytes.length - 2) / 2);
  const html = "0x" + Buffer.from("<canvas>作品</canvas>", "utf8").toString("hex");
  const scope = exampleScope();
  const publication = { scope, observation: {
    collectionId: scope.collectionId, referenceId: exampleHash(55), expectedHead: ZeroHash, expectedRevision: 0n,
    snapshotRecordHash: exampleHash(56), snapshotRevision: 1n, expectedSourcesHash: ZeroHash,
    captures: [{ tokenId: 1n, collectionSerial: 1n, metadataJSONHash: keccak256(toUtf8Bytes("{}")),
      htmlHash: keccak256(html), htmlBytes: BigInt((html.length - 2) / 2), animationHTML: html,
      objectHash: exampleHash(57), coverageHash: exampleHash(58), sourceSha256: sha256(html),
      repeatCaptureSha256: [exampleHash(59), exampleHash(59)], environmentManifestHash: environment.manifestHash, capturedAt: 100n }],
    environment, manifestURI: "", effectiveAt: 100n, reasonHash: exampleHash(60),
  } };
  return { environment, environmentBytes, publication };
}

test("environment, preview and publication plans match original complete calldata and authority fields", async () => {
  const p = await import("../dist/current-scoped-policy-reference-v2.js");
  const c = exampleCoordinates(), caller = exampleAddress(4);
  const { environment, environmentBytes, publication } = await admittedReferenceDraft();
  const environmentType = compiledInterfaces.reference.getFunction("prepareEnvironment").inputs[0];
  const identity = hashOriginal(["bytes32", "uint256", "address", environmentType],
    [id("6529STREAM_REFERENCE_ENVIRONMENT_PREPARATION_V1"), c.chainId, c.reference, environment]);
  const preparation = p.prepareScopedPolicyReferenceV2Call(c, caller, { kind: "prepareEnvironment", environment });
  assert.deepEqual(preparation.preparation, { id: identity, canonical: environmentBytes,
    contentHash: environment.manifestHash, byteLength: environment.manifestBytes });
  assert.equal(preparation.call.data, compiledInterfaces.reference.encodeFunctionData("prepareEnvironment", [environment]));
  const preview = p.prepareScopedPolicyReferenceV2Read(c, caller, { kind: "previewReference", publication, recorder: caller });
  assert.equal(preview.call.data, compiledInterfaces.reference.encodeFunctionData("previewReference", [publication, caller]));
  assert.deepEqual(p.normalizeScopedPolicyReferenceV2Read(structuredClone(preview)), preview);
  assert.throws(() => p.prepareScopedPolicyReferenceV2Call(c, caller, { kind: "publishReference", publication }));
  publication.observation.expectedSourcesHash = exampleHash(61);
  const submitted = p.prepareScopedPolicyReferenceV2Call(c, caller, { kind: "publishReference", publication });
  assert.equal(submitted.call.data, compiledInterfaces.reference.encodeFunctionData("publishReference", [publication]));
  assert.equal(submitted.preparation, null);
  for (const authorizationClass of [3n, 8n]) {
    const receipt = p.scopedPolicyReferenceV2PreviewReceipt(c, publication, caller,
      { authorizationClass, grantRevision: (1n << 63n) + 1n }, exampleHash(61));
    assert.equal(receipt.observation.authorizationClass, authorizationClass);
    assert.equal(receipt.observation.sourcesHash, exampleHash(61));
    assert.equal(receipt.observation.recordedAt, 0n);
    assert.equal(receipt.observation.schemaHash, keccak256(Buffer.from(fixture.documents[
      "docs/schemas/preservation/scoped-policy-reference-v2.schema.json"].text, "utf8")));
  }
  assert.throws(() => p.scopedPolicyReferenceV2PreviewReceipt(c, publication, caller,
    { authorizationClass: 7n, grantRevision: 1n }, exampleHash(61)));
});

test("all seven ACTIVE RAW document pins bind exact original committed definition bytes", async () => {
  const p = await import("../dist/current-scoped-policy-reference-v2.js");
  assert.equal(p.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS.length, 7);
  const definitions = fixture.sourceTexts["smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol"];
  for (const [prefix, name, length] of [
    ["ENVIRONMENT_SCHEMA", "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1", 2236],
    ["PNG_SCHEMA", "STREAM_REFERENCE_PNG_OBJECT_V1", 286],
    ["ZIP_SCHEMA", "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1", 351],
    ["FORMAT_CATALOG", "STREAM_REFERENCE_NATIVE_FORMATS_V1", 422],
  ]) {
    const doc = fixture.documents["schemas/records/" + name + ".json"];
    const expectedHash = new RegExp(prefix + "_HASH\\s*=\\s*(0x[0-9a-f]{64})").exec(definitions)[1];
    assert.equal(doc.byteLength, length);
    assert.equal(keccak256(Buffer.from(doc.text, "utf8")), expectedHash);
    assert.match(definitions, new RegExp(prefix + "_BYTES = " + length));
    assert.match(definitions, new RegExp(prefix + '_ID\\s*=\\s*keccak256\\("' + name + '"\\)'));
    assert.equal(JSON.parse(doc.text).name ?? JSON.parse(doc.text).$id, name);
  }
  for (const pin of p.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS) {
    const docs = Object.values(fixture.documents).filter(doc => {
      try { const parsed = JSON.parse(doc.text); return id(parsed.name ?? parsed.$id) === pin.id; }
      catch { return false; }
    });
    assert.equal(docs.length, 1, pin.id);
    assert.equal(keccak256(Buffer.from(docs[0].text, "utf8")), pin.contentHash);
    assert.equal(BigInt(docs[0].byteLength), pin.byteLength);
  }
});
