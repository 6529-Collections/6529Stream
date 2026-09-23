import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledInterfaces, compiledLibraryEvents } from "./current-tagged-policy-view-v2-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const fields = tuple => tuple.components.map(p => [p.name, p.type]);
const words = type => type.baseType === "tuple"
  ? type.components.reduce((n, p) => n + words(p), 0)
  : type.baseType === "array" ? type.arrayLength * words(type.arrayChildren) : 1;

test("tagged VIEW witness retains the exact ABI125 committed source and evidence boundary", () => {
  assert.equal(fixture.profile, "tagged-policy-view-v2");
  assert.equal(fixture.sourceCommit, "00686b799ccf60713a0a30e1e81fca0c7281912d");
  assert.equal(fixture.sourceTree, "1778378447b903f7d5ebef38d77782881438e656");
  assert.equal(fixture.compilerReportedCommit, fixture.sourceCommit);
  assert.equal(fixture.compilerVersion, "0.8.19");
  assert.equal(fixture.sourceCount, 3146);
  assert.equal(fixture.literalBytes, 37016570);
  assert.equal(fixture.inputSha256, "5d22ce424636139d7768697a3d43aefad617e3b97f33e56eceaed34d05f38201");
  assert.equal(fixture.outputSha256, "a6a1663fc334ad82ddb6a0760d92106092d217d8dab9e45be638c8100128d047");
  const { sha256, ...bridge } = fixture.committedSourceBridge;
  assert.equal(sha256, "0bd6810dd83da8f150af8a38077b730192804e35c12c7a910ebd68bc9fcfc1d3");
  assert.equal(sha(JSON.stringify(bridge, null, 2) + "\n"), sha256);
  assert.equal(bridge.commit, fixture.sourceCommit);
  assert.equal(bridge.sources, 3146);
  assert.equal(Object.keys(bridge.committedBlobSHA256).length, 3146);
  assert.deepEqual(bridge.mismatches, []);
  assert.match(fixture.sourceBinding, /no line-ending normalization/);
  assert.match(fixture.qualification, /does not invent missing VIEW checkpoint/);
  assert.match(fixture.qualification, /Native\/Safe execution.*remain separately qualified/);
});

test("all ordinary contract and interface selectors retain complete compiler ABIs", () => {
  assert.equal(Object.keys(fixture.abis).length, 48);
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 2254);
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
  assert.equal(selectors, 1400);
});

test("nominal fixed-library selectors stay raw and event-only decoding grants no worker call", () => {
  assert.deepEqual(Object.keys(fixture.libraryAbis).sort(), ["adoptionWorker", "formatter", "legacyAdoptionWorker"]);
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
  assert.equal(count, 8);
  assert.equal(fixture.libraryMethodIdentifiers.formatter["html(IStreamRenderer.RenderRequest,bytes32,bytes32,uint256,bytes,StreamViewPolicyTypesV2.Entropy,bytes)"], "a063ea8f");
  assert.equal(fixture.libraryMethodIdentifiers.formatter["output(IStreamRenderer.RenderRequest,string,string,string,string,bytes,uint8)"], "f8f26c64");
  const nominal = fixture.libraryMethodIdentifiers.adoptionWorker["previewEncoded(StreamMetadataRouterContent.Layout,StreamMetadataRouterContent.Context,bytes)"];
  assert.equal(nominal, "aebfa3b4");
  assert.notEqual(new Interface(fixture.libraryAbis.adoptionWorker).getFunction("previewEncoded").selector.slice(2), nominal);
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
  assert.equal(visited.size, 1050);
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, text) => n + Buffer.byteLength(text), 0), 6640653);
});

test("interpretation documents retain original bytes and the missing VIEW finality boundary", () => {
  assert.equal(Object.keys(fixture.documents).length, 14);
  let size = 0;
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
    size += document.byteLength;
  }
  assert.equal(size, 256586);
  assert.match(fixture.documents["docs/integrations/tagged-policy-view-v2.md"].text, /still refuses\nVIEW finality/);
  assert.match(fixture.documents["docs/integrations/scoped-policy-preservation-v2.md"].text, /TOKEN, RELEASE and SEASON/);
});

test("V2 adoption preserves original Input, zero native funding and explicit actor preview", () => {
  const current = compiledInterfaces.policyRouter.getFunction("adoptPolicyView");
  const original = compiledInterfaces.viewRouter.getFunction("adoptView");
  assert.equal(current.stateMutability, "nonpayable");
  assert.equal(current.inputs[0].format("full"), original.inputs[0].format("full"));
  assert.deepEqual(fields(current.inputs[0]), [["scope", "tuple"], ["viewId", "bytes32"], ["viewRecordHash", "bytes32"],
    ["expectedPrevious", "bytes32"], ["rendererRegistry", "address"], ["rendererVersionKey", "bytes32"], ["expectedSourceHash", "bytes32"]]);
  assert.deepEqual(fields(current.inputs[0].components[0]), [["scopeType", "uint8"], ["collectionId", "uint256"], ["tokenId", "uint256"], ["scopeId", "bytes32"]]);
  const preview = compiledInterfaces.policyRouter.getFunction("previewPolicyViewAdoption");
  assert.equal(preview.stateMutability, "view");
  assert.equal(preview.inputs[1].name, "actor");
  assert.equal(preview.inputs[1].type, "address");
  assert.deepEqual(preview.outputs.map(p => [p.name, p.type]), [["familyState", "bytes32"], ["sourceHash", "bytes32"]]);
});

test("V2 policy binding retains 23 words and adopted records retain separate scope and aggregate revisions", () => {
  const binding = compiledInterfaces.rendererInterface.getFunction("policyViewBinding").outputs[0];
  assert.equal(words(binding), 23);
  assert.deepEqual(fields(binding), [["core", "address"], ["coreCodeHash", "bytes32"], ["factory", "address"], ["factoryCodeHash", "bytes32"],
    ["sourceSet", "address"], ["sourceSetCodeHash", "bytes32"], ["chainId", "uint256"], ["scope", "tuple"], ["membership", "tuple"],
    ["inventoryPlan", "bytes32"], ["inventoryHash", "bytes32"], ["policyChainHash", "bytes32"], ["policyCount", "uint256"]]);
  const event = compiledLibraryEvents("adoptionWorker").getEvent("ViewAdopted");
  const originalEvent = compiledLibraryEvents("legacyAdoptionWorker").getEvent("ViewAdopted");
  assert.deepEqual(event.inputs.map(p => [p.name, p.type, p.indexed]), [["schemaVersion", "uint16", false], ["profile", "bytes32", false],
    ["collectionId", "uint256", true], ["scopeSubject", "bytes32", true], ["recordHash", "bytes32", true], ["record", "tuple", false]]);
  assert.notEqual(event.topicHash, originalEvent.topicHash);
  const record = event.inputs.at(-1);
  assert.equal(record.format("full"), originalEvent.inputs.at(-1).format("full"));
  assert.deepEqual(fields(record), [["input", "tuple"], ["source", "tuple"], ["sourceHash", "bytes32"], ["recordHash", "bytes32"],
    ["revision", "uint64"], ["actor", "address"], ["authorizationClass", "uint8"], ["grantCollectionId", "uint256"], ["grantRevision", "uint64"],
    ["artistConsent", "bytes32"], ["adoptedAt", "uint64"], ["aggregate", "tuple"]]);
  assert.deepEqual(fields(record.components.at(-1)), [["revision", "uint64"], ["transitionChain", "bytes32"]]);
});

test("provider exposes its actual immutable source binding while Router owns the four serving calls", () => {
  assert.deepEqual(compiledInterfaces.providerBinding.fragments.filter(f => f.type === "function").map(f => f.name).sort(),
    ["viewPolicySourceFactoryV2", "viewPolicySourceFactoryV2CodeHash"]);
  const functions = ["tokenJSONForView", "tokenHTMLForView", "historicalTokenJSONForView", "historicalTokenHTMLForView"];
  for (const name of functions) {
    const router = compiledInterfaces.router.getFunction(name), api = compiledInterfaces.viewRouter.getFunction(name);
    assert.equal(router.selector, api.selector);
    assert.equal(router.stateMutability, "view");
    assert.deepEqual(router.inputs.map(p => p.type), ["uint256", "bytes32"]);
    assert.deepEqual(router.outputs.map(p => p.type), ["string"]);
  }
});

test("registered schema definitions preserve their exact frozen source strings", () => {
  const read = literalReader(new URL("../src/current-tagged-policy-view-v2.ts", import.meta.url));
  for (const [path, field, exported] of [
    ["smart-contracts/domains/metadata/StreamViewPayloadV2.sol", "DEFINITION", "PAYLOAD"],
    ["smart-contracts/domains/metadata/StreamCollectionViewFormat.sol", "DEFINITION", "MANIFEST"],
    ["smart-contracts/domains/metadata/StreamViewRendererFormatV2.sol", "SCHEMA", "OUTPUT"],
  ]) {
    const expression = new RegExp(`string internal constant ${field}\\s*=\\s*('(?:[^'\\\\]|\\\\.)*'|"(?:[^"\\\\]|\\\\.)*")\\s*;`);
    const literal = fixture.sourceTexts[path].match(expression)?.[1];
    assert.ok(literal, path);
    if (literal.startsWith("'")) assert.ok(!literal.includes("\\"), "Frozen single-quoted source needs no escape conversion");
    const definition = literal.startsWith("'") ? literal.slice(1, -1) : JSON.parse(literal);
    assert.equal(read(`TAGGED_POLICY_VIEW_V2_${exported}_SCHEMA`), definition, path);
    assert.deepEqual(JSON.parse(read(`TAGGED_POLICY_VIEW_V2_${exported}_SCHEMA`)), JSON.parse(definition));
  }
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
  function value(node) {
    if (!node) throw Error(`Missing literal declaration in ${url.pathname}`);
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isIdentifier(node)) return read(node.text);
    if (ts.isPropertyAccessExpression(node) && ts.isIdentifier(node.expression) && namespaces.has(node.expression.text)) {
      return literalReader(namespaces.get(node.expression.text), cache)(node.name.text);
    }
    if (ts.isTemplateExpression(node)) return node.head.text + node.templateSpans.map(span => value(span.expression) + span.literal.text).join("");
    if (ts.isArrayLiteralExpression(node)) return node.elements.map(value);
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

test("client tuple declarations preserve compiler-owned widths, nested names and library event records", () => {
  const read = literalReader(new URL("../src/current-tagged-policy-view-v2.ts", import.meta.url));
  const record = compiledLibraryEvents("adoptionWorker").getEvent("ViewAdopted").inputs.at(-1);
  const source = record.components[1];
  const route = source.components[0];
  const html = fixture.libraryAbis.formatter.find(f => f.type === "function" && f.name === "html");
  const carrier = compiledInterfaces.viewRouter.getFunction("viewAdoptionCarrier").outputs;
  const cases = [
    ["SCOPE", record.components[0].components[0]], ["INPUT", record.components[0]],
    ["BINDING", route.components.at(-1)], ["ROUTE", route], ["MEMBERSHIP", source.components[1]],
    ["SELECTION", source.components[2]], ["SOURCE", source], ["RECORD", record],
    ["AGGREGATE", record.components.at(-1)],
    ["POLICY_BINDING", compiledInterfaces.rendererInterface.getFunction("policyViewBinding").outputs[0]],
    ["POLICY", compiledInterfaces.policyFacts.getFunction("staticTerminalEntropyFacts").outputs[1]],
    ["COORDINATOR_POLICY", compiledInterfaces.sourceSet.getFunction("sourcePolicyAt").outputs[0]],
    ["ENTROPY", ParamType.from(html.inputs[5])],
    ["RENDER_REQUEST", compiledInterfaces.rendererInterface.getFunction("renderPolicyView").inputs[0]],
    ["CARRIER", ParamType.from(`tuple(${carrier.map(p => p.format("full")).join(",")})`)],
  ];
  for (const [label, compiled] of cases) {
    sameFields([ParamType.from(read(`TAGGED_POLICY_VIEW_V2_${label}_TUPLE`))], [compiled], label);
  }
});

test("public client ABI fragments target original Router or renderer methods and exact delegate events", () => {
  const read = literalReader(new URL("../src/current-tagged-policy-view-v2.ts", import.meta.url));
  for (const [name, target] of [["CURRENT_TAGGED_POLICY_VIEW_V2_ROUTER_ABI", "router"],
    ["CURRENT_TAGGED_POLICY_VIEW_V2_RENDERER_ABI", "rendererV2"]]) {
    for (const fragment of new Interface(read(name)).fragments) {
      const signature = fragment.format("sighash");
      const expected = fragment.type === "event"
        ? [compiledLibraryEvents("adoptionWorker"), compiledLibraryEvents("legacyAdoptionWorker")]
          .map(iface => iface.getEvent(signature)).find(Boolean)
        : compiledInterfaces[target].getFunction(signature);
      assert.ok(expected, `${target}:${signature}`);
      assert.equal(fragment.format("minimal"), expected.format("minimal"), signature);
      sameFields(fragment.inputs, expected.inputs, signature, fragment.type === "event");
      if (expected.outputs) sameFields(fragment.outputs, expected.outputs, signature);
    }
  }
});

test("workflow observation fragments retain original compiler methods and event schemas", () => {
  const read = literalReader(new URL("../src/current-tagged-policy-view-v2-workflow.ts", import.meta.url));
  const compiled = [...Object.values(compiledInterfaces), ...Object.keys(fixture.libraryAbis).map(compiledLibraryEvents)];
  for (const fragment of new Interface(read("abi")).fragments) {
    const signature = fragment.format("sighash");
    const candidates = compiled.map(iface => fragment.type === "event" ? iface.getEvent(signature)
      : fragment.type === "error" ? iface.getError(signature) : iface.getFunction(signature)).filter(Boolean);
    assert.ok(candidates.length, signature);
    const expected = candidates.find(candidate => candidate.format("minimal") === fragment.format("minimal"));
    assert.ok(expected, `${signature}: original mutability, outputs or indexed fields differ`);
    sameFields(fragment.inputs, expected.inputs, signature, fragment.type === "event");
    if (expected.outputs) sameFields(fragment.outputs, expected.outputs, signature);
  }
});

function originalTupleExample(type, counter = { value: 100 }) {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(p => [p.name, originalTupleExample(p, counter)]));
  if (type.baseType === "array") return Array.from({ length: type.arrayLength }, () => originalTupleExample(type.arrayChildren, counter));
  const n = ++counter.value;
  if (type.type === "address") return getAddress(`0x${n.toString(16).padStart(40, "0")}`);
  if (type.type === "bool") return true;
  if (type.type === "bytes32") return id(`independent-field-${n}`);
  if (type.type.startsWith("uint")) return BigInt(n) + (Number(type.type.slice(4)) >= 128 ? 1n << 120n : 0n);
  throw Error(`Unsupported oracle field ${type.type}`);
}

test("source, prepared, aggregate, family and V1/V2 record hashes retain independently encoded original preimages", async () => {
  const client = await import("../dist/current-tagged-policy-view-v2.js");
  const coder = AbiCoder.defaultAbiCoder();
  const digest = (types, values) => keccak256(coder.encode(types, values));
  const recordType = compiledLibraryEvents("adoptionWorker").getEvent("ViewAdopted").inputs.at(-1);
  const inputType = recordType.components[0], scopeType = inputType.components[0], sourceType = recordType.components[1];
  const bindingType = compiledInterfaces.rendererV2.getFunction("policyViewBinding").outputs[0];
  const aggregateType = recordType.components.at(-1);
  const profile = id("6529STREAM_STATIC_ADOPTED_POLICY_VIEW_V2");
  const r = originalTupleExample(recordType), b = originalTupleExample(bindingType);
  const c = { chainId: (1n << 160n) + 31337n, core: getAddress("0x0000000000000000000000000000000000000011"), router: getAddress("0x0000000000000000000000000000000000000012") };
  r.input.scope.scopeType = 4n;
  r.input.scope.tokenId = 0n;
  b.scope = { ...r.input.scope };
  r.source.renderer.contextVersion = id("STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2");
  const subject = digest(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
    [id("6529STREAM_SUBJECT_SCOPE_V1"), c.chainId, c.core, r.input.scope.collectionId, 4n, r.input.scope.scopeId]);
  assert.equal(client.taggedPolicyViewV2ScopeSubject(c, r.input.scope), subject);
  const source = digest(["bytes32", "bytes32", "uint256", "address", scopeType, "bytes32", "bytes32", sourceType, bindingType],
    [id("6529STREAM_POLICY_VIEW_ADOPTION_SOURCE_V2"), profile, c.chainId, c.router, r.input.scope, r.input.viewId, r.input.viewRecordHash, r.source, b]);
  assert.equal(client.taggedPolicyViewV2SourceHash(c, r.input, r.source, b), source);
  assert.equal(client.taggedPolicyViewV2SourceHash(c, { ...r.input, expectedPrevious: ZeroHash, expectedSourceHash: ZeroHash }, r.source, b), source);
  assert.notEqual(client.taggedPolicyViewV2SourceHash(c, r.input, r.source, { ...b, policyChainHash: id("different policy chain") }), source);
  const prepared = digest(["bytes32", "bytes32", inputType, "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_POLICY_VIEW_PREPARED_STATE_V2"), profile, r.input, r.sourceHash, r.actor, r.authorizationClass, r.grantCollectionId, r.grantRevision]);
  assert.equal(client.taggedPolicyViewV2PreparedHash(r), prepared);
  assert.notEqual(client.taggedPolicyViewV2PreparedHash({ ...r, input: { ...r.input, expectedPrevious: ZeroHash } }), prepared);
  const previous = { revision: (1n << 55n) + 5n, transitionChain: id("previous aggregate") };
  const next = { revision: previous.revision + 1n, transitionChain: digest(
    ["bytes32", "bytes32", "uint256", "address", "address", "uint256", "bytes32", "uint64", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_POLICY_VIEW_AGGREGATE_V2"), profile, c.chainId, c.router, c.core, r.input.scope.collectionId,
      previous.transitionChain, previous.revision + 1n, subject, r.input.expectedPrevious, prepared]) };
  assert.deepEqual(client.taggedPolicyViewV2NextAggregate(c, previous, r), next);
  const legacy = id("original legacy family");
  assert.equal(client.taggedPolicyViewV2FamilyState(c, r.input.scope.collectionId, legacy, { revision: 0n, transitionChain: ZeroHash }), legacy);
  assert.equal(client.taggedPolicyViewV2FamilyState(c, r.input.scope.collectionId, legacy, next), digest(
    ["bytes32", "uint256", "address", "address", "uint256", "bytes32", aggregateType],
    [id("6529STREAM_RENDERER_CONFIG_WITH_VIEWS_V1"), c.chainId, c.router, c.core, r.input.scope.collectionId, legacy, next]));
  const record = digest(["bytes32", "bytes32", "uint256", "address", "address", recordType],
    [id("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"), profile, c.chainId, c.router, c.core, { ...r, recordHash: ZeroHash }]);
  assert.equal(client.taggedPolicyViewV2RecordHash(c, r), record);
  assert.equal(client.taggedPolicyViewV2RecordHash(c, { ...r, recordHash: id("different self hash") }), record);
  const v1 = digest(["bytes32", "uint256", "address", "address", recordType],
    [id("6529STREAM_VIEW_ADOPTION_RECORD_V1"), c.chainId, c.router, c.core, { ...r, recordHash: ZeroHash }]);
  assert.equal(client.taggedPolicyViewV2RecordHash(c, r, ZeroHash), v1);
  assert.notEqual(v1, record);
  for (const changed of [{ ...c, chainId: c.chainId + 1n }, { ...c, core: c.router }, { ...c, router: c.core }]) {
    assert.notEqual(client.taggedPolicyViewV2RecordHash(changed, r), record);
  }
});

test("genuine explicit policy state uses the original entropy family domain", async () => {
  const client = await import("../dist/current-tagged-policy-view-v2.js");
  const rule = originalTupleExample(compiledInterfaces.sourceSet.getFunction("sourcePolicyAt").outputs[0]);
  const p = { ...rule.collectionPolicy, configured: true, explicitPolicy: true, frozen: true,
    mode: 2n, securityClass: 0n, renderRequirement: 1n, revision: 1n, providerEpoch: 0n, policyHash: rule.policyHash };
  p.contentStateHash = keccak256(AbiCoder.defaultAbiCoder().encode(["bytes32", "bytes32", "bool"],
    [id("6529STREAM_ENTROPY_CONFIGURATION_V1"), p.policyHash, true]));
  const valid = { ...rule, explicitPolicy: true, frozen: true, provider: ZeroAddress, epoch: 0n, salt: ZeroHash, collectionPolicy: p };
  assert.deepEqual(client.validateTaggedPolicyViewV2CoordinatorPolicy(valid), valid);
  const wrong = keccak256(AbiCoder.defaultAbiCoder().encode(["bytes32", "bytes32", "bool"], [id("ENTROPY_CONFIGURATION"), p.policyHash, true]));
  assert.throws(() => client.validateTaggedPolicyViewV2CoordinatorPolicy({ ...valid, collectionPolicy: { ...p, contentStateHash: wrong } }));
});
