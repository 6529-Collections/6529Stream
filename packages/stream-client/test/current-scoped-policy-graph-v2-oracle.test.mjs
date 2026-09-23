import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { fixture, compiledInterfaces, compiledLibraryEvents } from "./current-scoped-policy-graph-v2-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const fields = tuple => tuple.components.map(p => [p.name, p.type]);
const words = type => type.baseType === "tuple"
  ? type.components.reduce((n, p) => n + words(p), 0)
  : type.baseType === "array" ? type.arrayLength * words(type.arrayChildren) : 1;

test("scoped graph witness retains the exact ABI129 committed source and evidence boundary", () => {
  assert.equal(fixture.profile, "scoped-policy-graph-v2");
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
  assert.match(fixture.qualification, /Graph creation does not publish output, snapshot, root/);
  assert.match(fixture.qualification, /Native\/Safe execution.*remain separately qualified/);
});

test("all ordinary contract and interface selectors retain complete compiler ABIs", () => {
  assert.equal(Object.keys(fixture.abis).length, 56);
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 2025);
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
  assert.equal(selectors, 1214);
});

test("nominal fixed deployment and reader libraries stay separate from wallet calls", () => {
  assert.equal(Object.keys(fixture.libraryAbis).length, 12);
  assert.equal(Object.values(fixture.libraryAbis).reduce((n, a) => n + a.length, 0), 35);
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
  assert.equal(count, 24);
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
  assert.equal(visited.size, 626);
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, text) => n + Buffer.byteLength(text), 0), 3765973);
});

test("original documents retain scope and acyclic preparation/publication boundaries", () => {
  assert.equal(Object.keys(fixture.documents).length, 14);
  let size = 0;
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
    size += document.byteLength;
  }
  assert.equal(size, 249210);
  const preservation = fixture.documents["docs/integrations/scoped-policy-preservation-v2.md"].text;
  assert.match(preservation, /TOKEN, RELEASE and SEASON/);
  assert.match(preservation, /does not require a snapshot, root,\nreference or inventory publication/);
  assert.match(fixture.documents["docs/integrations/scoped-policy-finality-v2.md"].text,
    /absent scoped head or completely empty V2 binding retains original scoped V1/);
});

test("two factory writes retain exact original scope arguments and nonpayable transport", () => {
  const source = compiledInterfaces.sourceFactory.getFunction("prepareSourceSet");
  const graph = compiledInterfaces.publicationFactory.getFunction("prepareGraph");
  assert.equal(source.stateMutability, "nonpayable");
  assert.equal(graph.stateMutability, "nonpayable");
  assert.equal(source.inputs.length, 1);
  assert.equal(graph.inputs.length, 2);
  assert.equal(source.inputs[0].format("full"), graph.inputs[0].format("full"));
  assert.deepEqual(fields(graph.inputs[0]), [["scopeType", "uint8"], ["collectionId", "uint256"],
    ["tokenId", "uint256"], ["scopeId", "bytes32"]]);
  assert.deepEqual([graph.inputs[1].name, graph.inputs[1].type], ["maximumChildren", "uint8"]);
  assert.deepEqual(source.outputs.map(p => [p.name, p.type]), [["sourceSet", "address"]]);
  assert.equal(source.selector, compiledInterfaces.genericFactoryInterface.getFunction("prepareSourceSet").selector);
  assert.equal(graph.selector, compiledInterfaces.publicationFactoryInterface.getFunction("prepareGraph").selector);
});

test("graph, source dependencies and provider binding retain full compiler tuple identities", () => {
  const graph = compiledInterfaces.publicationFactory.getFunction("graphForPlan").outputs[0];
  assert.deepEqual(fields(graph), [["scope", "tuple"], ["inventoryPlan", "bytes32"], ["sourceSet", "address"],
    ["sourceSetCodeHash", "bytes32"], ["graphId", "bytes32"], ["children", "address[7]"],
    ["codeHashes", "bytes32[7]"], ["preparedChildren", "uint8"]]);
  assert.equal(words(graph), 23);
  const source = compiledInterfaces.sourceFactory.getFunction("dependencies").outputs[0];
  assert.deepEqual(fields(source), [["targets", "address[4]"], ["codeHashes", "bytes32[4]"],
    ["chainId", "uint256"], ["readGas", "uint32"], ["inventoryGas", "uint32"]]);
  assert.equal(words(source), 11);
  const binding = compiledInterfaces.providerBinding.getFunction("scopedPolicyPublicationBinding").outputs[0];
  assert.deepEqual(fields(binding), [["factory", "address"], ["factoryCodeHash", "bytes32"], ["recipeHash", "bytes32"],
    ["sourceFactoryDependenciesHash", "bytes32"], ["graphGas", "uint256"], ["configurationHash", "bytes32"]]);
  assert.equal(words(binding), 6);
  const recipe = compiledInterfaces.publicationFactory.getFunction("recipe").outputs[0];
  assert.equal(recipe.components[0].name, "inventory");
  assert.equal(recipe.components.find(p => p.name === "checkpointGas").arrayLength, 2);
  assert.equal(recipe.components.find(p => p.name === "snapshotGas").arrayLength, 3);
  assert.equal(recipe.components.find(p => p.name === "referenceGas").arrayLength, 4);
  assert.deepEqual(fields(recipe.components.find(p => p.name === "outputGas")),
    [["name", "string"], ["genesisValue", "uint256"], ["floor", "uint256"], ["failureClass", "uint8"]]);
});

test("graph preparation emits only the original indexed child-progress event", () => {
  const events = compiledInterfaces.publicationFactory.fragments.filter(f => f.type === "event");
  assert.equal(events.length, 1);
  const event = events[0];
  assert.equal(event.name, "ScopedPolicyPublicationChildPrepared");
  assert.deepEqual(event.inputs.map(p => [p.name, p.type, p.indexed]), [
    ["schemaVersion", "uint16", false], ["graphId", "bytes32", true], ["inventoryPlan", "bytes32", true],
    ["childIndex", "uint8", true], ["child", "address", false], ["codeHash", "bytes32", false],
  ]);
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


test("client tuple literals retain original compiler widths and every nested field name", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-graph-v2.ts", import.meta.url));
  const c = compiledInterfaces;
  const recipe = c.publicationFactory.getFunction("recipe").outputs[0];
  const coordinator = c.sourceSet.getFunction("sourcePolicyAt").outputs[0];
  const evidence = ParamType.from(fixture.libraryAbis.policyReads.find(f => f.name === "requireCurrent").outputs[0]);
  const entries = {
    SCOPE: c.publicationFactory.getFunction("prepareGraph").inputs[0],
    SOURCE_DEPENDENCIES: c.sourceFactory.getFunction("dependencies").outputs[0],
    INVENTORY_DEPENDENCIES: c.inventory.getFunction("dependencies").outputs[0],
    GAS_PARAMETER_CONFIG: recipe.components.find(p => p.name === "outputGas"),
    RECIPE: recipe,
    GRAPH: c.publicationFactory.getFunction("graphForPlan").outputs[0],
    FACTORY_BINDING: c.providerBinding.getFunction("scopedPolicyPublicationBinding").outputs[0],
    SNAPSHOT_DEPENDENCIES: c.snapshot.getFunction("dependencies").outputs[0],
    REFERENCE_DEPENDENCIES: c.reference.getFunction("dependencies").outputs[0],
    BUNDLE_DEPENDENCIES: c.bundle.getFunction("dependencies").outputs[0],
    MEMBERSHIP: c.membership.getFunction("requireScopeMembership").outputs[0],
    POLICY: coordinator.components.find(p => p.name === "collectionPolicy"),
    COORDINATOR_POLICY: coordinator,
    COORDINATOR: c.coordinatorInventory.getFunction("requireCoordinator").outputs[0],
    INVENTORY_PROGRESS: c.coordinatorInventory.getFunction("requireCompleteInventory").outputs[0],
    POLICY_EVIDENCE: evidence,
    CURRENT_ROUTE: c.sourceFactory.getFunction("requireCurrentRoute").outputs[0],
    COMPONENT_EXPECTATION: c.sourceFactory.getFunction("requireCurrentComponent").outputs[0],
    NATIVE_CONFIGURATION: c.provider.getFunction("nativeConfiguration").outputs[0],
  };
  for (const [name, witness] of Object.entries(entries)) {
    const param = ParamType.from(read("SCOPED_POLICY_GRAPH_V2_" + name + "_TUPLE"));
    sameFields([param], [witness], name);
  }
  // The Evidence output is a codec witness, not an invented provider or library RPC endpoint.
  assert.equal(compiledInterfaces.policyReads, undefined);
});

test("public client factory and binding ABIs match actual contract methods and events", () => {
  const read = literalReader(new URL("../src/current-scoped-policy-graph-v2.ts", import.meta.url));
  for (const [name, key] of [["SOURCE_FACTORY", "sourceFactory"], ["PUBLICATION_FACTORY", "publicationFactory"],
    ["PROVIDER_BINDING", "providerBinding"]]) {
    const iface = new Interface(read("SCOPED_POLICY_GRAPH_V2_" + name + "_ABI"));
    for (const fragment of iface.fragments) {
      const signature = fragment.format("sighash");
      const original = fragment.type === "event"
        ? compiledInterfaces[key].getEvent(signature) : compiledInterfaces[key].getFunction(signature);
      assert.ok(original, name + ":" + signature);
      assert.equal(fragment.format("full"), original.format("full"), name + ":" + signature);
    }
  }
});

test("workflow observation ABIs retain complete original methods and exact tuple schemas", () => {
  const iface = new Interface(literalReader(new URL("../src/current-scoped-policy-graph-v2-workflow.ts", import.meta.url))("abi"));
  for (const fragment of iface.fragments) {
    const signature = fragment.format("sighash");
    const originals = Object.values(compiledInterfaces).flatMap(compiled => compiled.fragments.filter(original =>
      original.type === fragment.type && original.format("sighash") === signature));
    assert.ok(originals.length > 0, signature);
    assert.ok(originals.some(original => original.format("full") === fragment.format("full")), signature);
  }
});

// Encoding vectors exercise supplied facts; they do not claim live source admission.
function originalTupleExample(type, counter = { value: 10 }) {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(p => [p.name, originalTupleExample(p, counter)]));
  if (type.baseType === "array") return Array.from({ length: type.arrayLength < 0 ? 2 : type.arrayLength },
    () => originalTupleExample(type.arrayChildren, counter));
  const n = ++counter.value;
  if (type.type === "address") return getAddress("0x" + n.toString(16).padStart(40, "0"));
  if (type.type === "bool") return true;
  if (type.type === "string") return "independent recipe field " + n;
  if (type.type === "bytes32") return id("independent-field-" + n);
  if (type.type.startsWith("uint")) return BigInt(n) + (Number(type.type.slice(4)) >= 128 ? 1n << 120n : 0n);
  throw Error("Unsupported oracle field " + type.type);
}

test("recipe, dependencies, graph and provider hashes use independently encoded original preimages", async () => {
  const client = await import("../dist/current-scoped-policy-graph-v2.js");
  const c = compiledInterfaces, coder = AbiCoder.defaultAbiCoder();
  const recipeType = c.publicationFactory.getFunction("recipe").outputs[0];
  const dependenciesType = c.sourceFactory.getFunction("dependencies").outputs[0];
  const scopeType = c.publicationFactory.getFunction("prepareGraph").inputs[0];
  const nativeType = c.provider.getFunction("nativeConfiguration").outputs[0];
  const bindingType = c.providerBinding.getFunction("scopedPolicyPublicationBinding").outputs[0];
  const recipe = originalTupleExample(recipeType), dependencies = originalTupleExample(dependenciesType);
  const original = originalTupleExample(nativeType), binding = originalTupleExample(bindingType);
  const chainId = (1n << 180n) + 187n;
  const coordinates = { chainId, sourceFactory: getAddress("0x" + "11".repeat(20)), publicationFactory: getAddress("0x" + "22".repeat(20)) };
  const scope = { scopeType: 2n, collectionId: (1n << 140n) + 93n, tokenId: 0n, scopeId: id("release membership") };
  const recipeHash = keccak256(coder.encode(["bytes32", "uint256", recipeType],
    [id("6529STREAM_SCOPED_POLICY_PUBLICATION_FACTORY_V2"), chainId, recipe]));
  const dependencyHash = keccak256(coder.encode([dependenciesType], [dependencies]));
  assert.equal(client.scopedPolicyGraphV2RecipeHash(chainId, recipe), recipeHash);
  assert.equal(client.scopedPolicyGraphV2DependenciesHash(dependencies), dependencyHash);
  const plan = id("original plan"), sourceSet = getAddress("0x" + "33".repeat(20)), runtime = id("retained source runtime");
  const graphId = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "bytes32", scopeType,
    "bytes32", "address", "bytes32"], [id("6529STREAM_SCOPED_POLICY_PUBLICATION_GRAPH_V2"), chainId,
    coordinates.publicationFactory, recipeHash, dependencyHash, scope, plan, sourceSet, runtime]));
  assert.equal(client.scopedPolicyGraphV2GraphId(coordinates, recipeHash, dependencyHash, scope, plan, sourceSet, runtime), graphId);
  for (const changed of [
    { ...scope, scopeType: 3n }, { ...scope, collectionId: scope.collectionId + 1n }, { ...scope, scopeId: id("other scope") },
  ]) assert.notEqual(client.scopedPolicyGraphV2GraphId(coordinates, recipeHash, dependencyHash, changed, plan, sourceSet, runtime), graphId);
  assert.notEqual(client.scopedPolicyGraphV2GraphId({ ...coordinates, chainId: chainId + 1n },
    recipeHash, dependencyHash, scope, plan, sourceSet, runtime), graphId);
  assert.notEqual(client.scopedPolicyGraphV2GraphId({ ...coordinates, publicationFactory: sourceSet },
    recipeHash, dependencyHash, scope, plan, sourceSet, runtime), graphId);
  const provider = getAddress("0x" + "44".repeat(20));
  const configurationHash = keccak256(coder.encode(["bytes32", "uint256", "address", nativeType,
    "address", "bytes32", "bytes32", "bytes32", "uint256"],
  [id("6529STREAM_SCOPED_POLICY_PROVIDER_CONFIGURATION_V2"), original.chainId, provider, original, binding.factory,
    binding.factoryCodeHash, binding.recipeHash, binding.sourceFactoryDependenciesHash, binding.graphGas]));
  assert.equal(client.scopedPolicyGraphV2ProviderConfigurationHash(provider, original, binding), configurationHash);
  assert.equal(client.scopedPolicyGraphV2ProviderConfigurationHash(provider, original, { ...binding, configurationHash: ZeroHash }),
    configurationHash, "The returned configuration hash is excluded from its original preimage");
});

test("original inventory and full policy chains retain ordered, full-width compiler tuples", async () => {
  const client = await import("../dist/current-scoped-policy-graph-v2.js");
  const c = compiledInterfaces, coder = AbiCoder.defaultAbiCoder();
  const depsType = c.sourceFactory.getFunction("dependencies").outputs[0];
  const scopeType = c.publicationFactory.getFunction("prepareGraph").inputs[0];
  const memberType = c.membership.getFunction("requireScopeMembership").outputs[0];
  const coordinatorType = c.coordinatorInventory.getFunction("requireCoordinator").outputs[0];
  const policyType = c.sourceSet.getFunction("sourcePolicyAt").outputs[0];
  const progressType = c.coordinatorInventory.getFunction("requireCompleteInventory").outputs[0];
  const d = originalTupleExample(depsType), member = originalTupleExample(memberType), progress = originalTupleExample(progressType);
  const scope = { scopeType: 3n, collectionId: (1n << 180n) + 75n, tokenId: 0n, scopeId: id("season") };
  member.scopeSubject = keccak256(coder.encode(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
    [id("6529STREAM_SUBJECT_SCOPE_V1"), d.chainId, d.targets[0], scope.collectionId, scope.scopeType, scope.scopeId]));
  assert.equal(client.scopedPolicyGraphV2ScopeSubject(d.chainId, d.targets[0], scope), member.scopeSubject);
  const tokenScope = { scopeType: 1n, collectionId: scope.collectionId, tokenId: (1n << 170n) + 1n, scopeId: ZeroHash };
  assert.equal(client.scopedPolicyGraphV2ScopeSubject(d.chainId, d.targets[0], tokenScope),
    keccak256(coder.encode(["bytes32", "uint256", "address", "uint256"],
      [id("6529STREAM_SUBJECT_TOKEN_V1"), d.chainId, d.targets[0], tokenScope.tokenId])));
  const plan = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "address", "bytes32", scopeType, memberType],
    [id("6529STREAM_COORDINATOR_INVENTORY_PLAN_V1"), d.chainId, d.targets[3], d.targets[0], d.codeHashes[0], d.targets[2], d.codeHashes[2], scope, member]));
  assert.equal(client.scopedPolicyGraphV2InventoryPlan(d, scope, member), plan);
  const rows = [originalTupleExample(coordinatorType, { value: 201 }), originalTupleExample(coordinatorType, { value: 211 })];
  let chain = keccak256(coder.encode(["bytes32", "bytes32"], [id("6529STREAM_COORDINATOR_SOURCE_CHAIN_V1"), plan]));
  rows.forEach((row, i) => { chain = keccak256(coder.encode(["bytes32", "bytes32", "uint256", coordinatorType],
    [id("6529STREAM_COORDINATOR_SOURCE_APPEND_V1"), chain, BigInt(i), row])); });
  assert.equal(client.scopedPolicyGraphV2CoordinatorChain(plan, rows), chain);
  assert.notEqual(client.scopedPolicyGraphV2CoordinatorChain(plan, [...rows].reverse()), chain);
  const inventory = keccak256(coder.encode(["bytes32", "bytes32", "uint256", "uint256", "bytes32", "bytes32"],
    [id("6529STREAM_COORDINATOR_INVENTORY_COMPLETE_V1"), plan, progress.tokenCount, progress.coordinatorCount, progress.tokenChain, progress.coordinatorChain]));
  assert.equal(client.scopedPolicyGraphV2InventoryCommitment(plan, progress), inventory);
  const policies = [originalTupleExample(policyType, { value: 101 }), originalTupleExample(policyType, { value: 151 })];
  let policyChain = keccak256(coder.encode(["bytes32", "uint256", "address[4]", "bytes32[4]", scopeType, "bytes32", "bytes32", "uint256"],
    [id("6529STREAM_ORIGINAL_COORDINATOR_POLICIES_V2"), d.chainId, d.targets, d.codeHashes, scope, plan, inventory, 2n]));
  policies.forEach((row, i) => { policyChain = keccak256(coder.encode(["bytes32", "bytes32", "uint256", policyType],
    [id("6529STREAM_ORIGINAL_COORDINATOR_POLICY_APPEND_V2"), policyChain, BigInt(i), row])); });
  assert.equal(client.scopedPolicyGraphV2PolicyChain(d, scope, plan, inventory, policies), policyChain);
  assert.notEqual(client.scopedPolicyGraphV2PolicyChain(d, scope, plan, inventory, [...policies].reverse()), policyChain);
  const tokenInventory = getAddress("0x" + "55".repeat(20)), runtime = id("token inventory runtime");
  const profile = id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2");
  assert.equal(client.scopedPolicyGraphV2SourceSetManifestHash(d, tokenInventory, runtime),
    keccak256(coder.encode(["bytes32", depsType, "address", "bytes32"], [profile, d, tokenInventory, runtime])));
  assert.equal(client.scopedPolicyGraphV2SourceSetDataHash(scope, plan, inventory, policyChain, member, tokenInventory, runtime),
    keccak256(coder.encode(["bytes32", scopeType, "bytes32", "bytes32", "bytes32", memberType, "address", "bytes32"],
      [profile, scope, plan, inventory, policyChain, member, tokenInventory, runtime])));
});

test("factory ERC165 identities use only each original interface's own declared functions", async () => {
  const client = await import("../dist/current-scoped-policy-graph-v2.js");
  for (const [name, key] of [["SOURCE_FACTORY", "scopedFactoryInterface"],
    ["PUBLICATION_FACTORY", "publicationFactoryInterface"], ["PROVIDER_BINDING", "providerBinding"]]) {
    const source = fixture.sourceTexts[fixture.selections[key].source];
    const methods = [...source.matchAll(/\bfunction\s+([A-Za-z_]\w*)\s*\(/g)].map(m => m[1]);
    let expected = 0n;
    for (const method of methods) expected ^= BigInt(compiledInterfaces[key].getFunction(method).selector);
    assert.equal(client["SCOPED_POLICY_GRAPH_V2_" + name + "_INTERFACE_ID"], "0x" + expected.toString(16).padStart(8, "0"));
    assert.ok(!methods.includes("supportsInterface"));
  }
});

test("policy observations probe the original producer capability rather than its getter selector", async () => {
  const consumer = fixture.sourceTexts["smart-contracts/interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol"];
  const reader = fixture.sourceTexts["smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol"];
  const expected = /bytes4\s+internal\s+constant\s+CAPABILITY\s*=\s*(0x[0-9a-fA-F]{8})\s*;/.exec(consumer)?.[1].toLowerCase();
  assert.ok(expected, "Original producer capability must be retained");
  assert.match(reader, /abi\.encodeCall\(IERC165\.supportsInterface,\s*\(P\.CAPABILITY\)\)/);
  const getter = id("collectionEntropyPolicy(uint256)").slice(0, 10);
  assert.notEqual(expected, getter, "A one-method read mirror is not the producer capability");
  const { setup } = await import("./current-scoped-policy-graph-v2-workflow-fixture.mjs");
  const { captureScopedPolicyGraphV2 } = await import("../dist/current-scoped-policy-graph-v2-workflow.js");
  const h = setup();
  await captureScopedPolicyGraphV2(h.provider, h.deployment, h.caller,
    { kind: "prepareSourceSet", scope: h.scope }, { blockTag: 10 });
  for (const policy of h.policies) {
    const probes = h.state.calls.filter(call => call.target === policy.coordinator
      && call.method === "supportsInterface").map(call => call.args[0].toLowerCase());
    assert.ok(probes.includes(expected), "Original producer capability must select the policy branch");
    assert.ok(!probes.includes(getter), "Do not substitute the getter selector as a capability");
  }
});
