import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as graph from "../dist/current-scoped-policy-graph-v2.js";
import { compiledInterfaces } from "./current-scoped-policy-graph-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const h = n => "0x" + BigInt(n).toString(16).padStart(64, "0");
const a = n => getAddress("0x" + BigInt(n).toString(16).padStart(40, "0"));
const chainId = (1n << 160n) + 17n;
const coordinates = { chainId, sourceFactory: a(3), publicationFactory: a(4) };
const caller = a(5);
const scope = { scopeType: 1n, collectionId: (1n << 180n) + 4n, tokenId: (1n << 200n) + 7n, scopeId: ZeroHash };
const gas = (name, failureClass) => ({ name, failureClass, genesisValue: 500000n, floor: 50000n });
const recipe = () => ({
  inventory: {
    targets: Array.from({ length: 12 }, (_, i) => i === 5 || i === 6 ? ZeroAddress : a(100 + i)),
    codeHashes: Array.from({ length: 12 }, (_, i) => i === 5 || i === 6 ? ZeroHash : h(100 + i)),
    artistTargets: Array.from({ length: 5 }, (_, i) => a(200 + i)),
    artistCodeHashes: Array.from({ length: 5 }, (_, i) => h(200 + i)),
    artistContentOwner: a(250), artistContentOwnerCodeHash: h(250), chainId,
    readGas: 50000n, sourceGas: 600000n, selectionGas: 700000n, snapshotGas: 800000n, referenceGas: 900000n,
  },
  targets: [a(1), a(2), coordinates.sourceFactory, a(6)],
  codeHashes: [h(1), h(2), h(3), h(6)],
  readinessReadGas: 50000n, readinessSourceGas: 600000n,
  factorySourceGas: 2000000n, bundleReadGas: 50000n, bundleArchiveGas: 1000000n,
  checkpointGas: [gas("STATIC_CONTENT_READ_GAS", 2n), gas("STATIC_CONTENT_RENDER_GAS", 2n)],
  outputGas: gas("STATIC_OUTPUT_MANIFEST_READ_GAS", 2n),
  snapshotGas: ["READ", "SOURCE", "INVENTORY"].map(name => gas(`SCOPED_POLICY_SNAPSHOT_${name}_GAS`, 2n)),
  referenceGas: ["READ", "SOURCE", "SNAPSHOT", "ARCHIVE"].map(name => gas(`SCOPED_POLICY_REFERENCE_${name}_GAS`, 1n)),
});
const dependencies = r => ({
  targets: [r.inventory.targets[0], r.inventory.targets[1], r.targets[0], a(9)],
  codeHashes: [r.inventory.codeHashes[0], r.inventory.codeHashes[1], r.codeHashes[0], h(9)],
  chainId, readGas: 50000n, inventoryGas: 1000000n,
});
const suppliedGraph = (r, count = 7) => {
  const d = dependencies(r);
  const g = { scope, inventoryPlan: h(10), sourceSet: a(11), sourceSetCodeHash: h(11), graphId: ZeroHash,
    children: Array.from({ length: 7 }, (_, i) => i < count ? a(300 + i) : ZeroAddress),
    codeHashes: Array.from({ length: 7 }, (_, i) => i < count ? h(300 + i) : ZeroHash), preparedChildren: BigInt(count) };
  g.graphId = graph.scopedPolicyGraphV2GraphId(coordinates, graph.scopedPolicyGraphV2RecipeHash(chainId, r),
    graph.scopedPolicyGraphV2DependenciesHash(d), scope, g.inventoryPlan, g.sourceSet, g.sourceSetCodeHash);
  return g;
};
const zeroValue = type => {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(field => [field.name, zeroValue(field)]));
  if (type.baseType === "array") return Array.from({ length: type.arrayLength < 0 ? 0 : type.arrayLength }, () => zeroValue(type.arrayChildren));
  if (type.type === "address") return ZeroAddress;
  if (type.type === "bool") return false;
  if (type.type === "string") return "";
  if (type.type.startsWith("bytes")) return "0x" + "00".repeat(Number(type.type.slice(5)));
  return 0n;
};
const missing = () => zeroValue(compiledInterfaces.publicationFactory.getFunction("graphForPlan").outputs[0]);
const digest = (types, values) => keccak256(coder.encode(types, values));

test("complete compiler ABI fragments and own selector IDs preserve actual targets", () => {
  for (const [ours, theirs] of [
    [graph.scopedPolicyGraphV2SourceFactoryInterface(), compiledInterfaces.sourceFactory],
    [graph.scopedPolicyGraphV2PublicationFactoryInterface(), compiledInterfaces.publicationFactory],
    [new Interface(graph.SCOPED_POLICY_GRAPH_V2_PROVIDER_BINDING_ABI), compiledInterfaces.provider],
  ]) {
    for (const fragment of ours.fragments) {
      const compiled = fragment.type === "function" ? theirs.getFunction(fragment.format("sighash")) : theirs.getEvent(fragment.format("sighash"));
      assert.ok(compiled);
      assert.equal(fragment.format("sighash"), compiled.format("sighash"));
      if (fragment.type === "function") assert.equal(fragment.stateMutability, compiled.stateMutability);
    }
  }
  const own = names => "0x" + names.reduce((value, name) => value ^ BigInt(compiledInterfaces.publicationFactory.getFunction(name).selector), 0n).toString(16).padStart(8, "0");
  assert.equal(graph.SCOPED_POLICY_GRAPH_V2_PUBLICATION_FACTORY_INTERFACE_ID, own([
    "scopedPolicyPublicationFactoryProfile", "core", "metadataHost", "entropySourceFactory", "recipeHash",
    "sourceFactoryDependenciesHash", "recipe", "prepareGraph", "graphForPlan", "requireCurrentGraph",
  ]));
  assert.equal(graph.SCOPED_POLICY_GRAPH_V2_SOURCE_FACTORY_INTERFACE_ID, "0x" + (
    BigInt(compiledInterfaces.sourceFactory.getFunction("scopedPolicyFactoryProfile").selector)
    ^ BigInt(compiledInterfaces.sourceFactory.getFunction("dependencies").selector)).toString(16).padStart(8, "0"));
});

test("recipe full compiler encoding preserves bigint widths, immutable nested fields and canonical bytes", () => {
  const r = recipe();
  const type = compiledInterfaces.publicationFactory.getFunction("recipe").outputs[0];
  const encoded = graph.encodeScopedPolicyGraphV2Recipe(r);
  assert.equal(encoded, coder.encode([type], [r]));
  const decoded = graph.decodeScopedPolicyGraphV2Recipe(encoded);
  assert.equal(decoded.inventory.chainId, chainId);
  assert.ok(Object.isFrozen(decoded.inventory.targets));
  assert.ok(Object.isFrozen(decoded.snapshotGas[0]));
  assert.throws(() => graph.decodeScopedPolicyGraphV2Recipe(encoded + "00".repeat(32)), /canonical/);
  assert.throws(() => graph.normalizeScopedPolicyGraphV2Recipe({ ...r, untrusted: true }), /fields/);
  assert.throws(() => graph.normalizeScopedPolicyGraphV2Recipe({ ...r, readinessReadGas: 1n << 32n }), /uint32/);
  assert.throws(() => graph.normalizeScopedPolicyGraphV2Recipe({ ...r, bundleReadGas: 50000 }), /bigint/);
  const sparse = [...r.targets]; delete sparse[0]; sparse.extra = r.targets[0];
  assert.throws(() => graph.normalizeScopedPolicyGraphV2Recipe({ ...r, targets: sparse }), /dense/);
  assert.throws(() => graph.normalizeScopedPolicyGraphV2Recipe({ ...r, outputGas: { ...r.outputGas, name: "\udc00" } }), /text/);
});

test("recipe validates fixed holes, exact GGP names/classes/floors and asymmetric gas constraints", () => {
  assert.doesNotThrow(() => graph.validateScopedPolicyGraphV2Recipe(chainId, recipe()));
  for (const mutate of [
    r => { r.inventory.targets[5] = a(1); }, r => { r.inventory.codeHashes[6] = h(1); },
    r => { r.inventory.artistCodeHashes[4] = ZeroHash; }, r => { r.targets[3] = ZeroAddress; },
    r => { r.checkpointGas[0].name = "STATIC_CONTENT_RENDER_GAS"; },
    r => { r.referenceGas[0].failureClass = 2n; }, r => { r.outputGas.floor = 0n; },
    r => { r.outputGas.genesisValue = 1n << 32n; },
    r => { r.snapshotGas[1].genesisValue = 499999n; },
    r => { r.referenceGas[2].genesisValue = 499999n; },
    r => { r.factorySourceGas = 49999n; }, r => { r.inventory.chainId++; },
  ]) {
    const r = recipe(); mutate(r);
    assert.throws(() => graph.validateScopedPolicyGraphV2Recipe(chainId, r));
  }
  const wide = recipe(); wide.inventory.sourceGas = (1n << 256n) - 1n;
  assert.doesNotThrow(() => graph.validateScopedPolicyGraphV2Recipe(chainId, wide));
});

test("original three independent hashes use full recipe, canonical source dependencies and actual factory", () => {
  const r = recipe(), d = dependencies(r), g = suppliedGraph(r);
  const rt = compiledInterfaces.publicationFactory.getFunction("recipe").outputs[0];
  const dt = compiledInterfaces.sourceFactory.getFunction("dependencies").outputs[0];
  const st = compiledInterfaces.publicationFactory.getFunction("prepareGraph").inputs[0];
  const rh = digest(["bytes32", "uint256", rt], [id("6529STREAM_SCOPED_POLICY_PUBLICATION_FACTORY_V2"), chainId, r]);
  const dh = digest([dt], [d]);
  assert.equal(graph.scopedPolicyGraphV2RecipeHash(chainId, r), rh);
  assert.equal(graph.scopedPolicyGraphV2DependenciesHash(d), dh);
  assert.equal(g.graphId, digest(["bytes32", "uint256", "address", "bytes32", "bytes32", st, "bytes32", "address", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_PUBLICATION_GRAPH_V2"), chainId, coordinates.publicationFactory, rh, dh, scope, g.inventoryPlan, g.sourceSet, g.sourceSetCodeHash]));
  assert.notEqual(g.graphId, graph.scopedPolicyGraphV2GraphId({ ...coordinates, publicationFactory: a(7) }, rh, dh, scope, g.inventoryPlan, g.sourceSet, g.sourceSetCodeHash));
  assert.equal(suppliedGraph(r, 1).graphId, g.graphId);
});

test("stored graph missing/partial/complete authentication rejects holes, transient state and substitutions", () => {
  const r = recipe(), d = dependencies(r);
  assert.equal(graph.validateScopedPolicyGraphV2Graph(coordinates, r, d, missing()).status, "missing");
  for (let i = 1; i <= 7; i++) {
    const result = graph.validateScopedPolicyGraphV2Graph(coordinates, r, d, suppliedGraph(r, i), { expectedScope: scope, expectedPlan: h(10) });
    assert.equal(result.status, i === 7 ? "complete" : "partial"); assert.equal(result.factsVerified, false);
  }
  for (const mutate of [
    g => { g.children[0] = ZeroAddress; }, g => { g.children[6] = a(1); },
    g => { g.graphId = h(999); }, g => { g.sourceSetCodeHash = ZeroHash; },
    g => { g.preparedChildren = 8n; }, g => { g.inventoryPlan = h(555); },
  ]) {
    const g = suppliedGraph(r, 2); mutate(g);
    assert.throws(() => graph.validateScopedPolicyGraphV2Graph(coordinates, r, d, g));
  }
  assert.throws(() => graph.validateScopedPolicyGraphV2Graph(coordinates, r, d, { ...missing(), inventoryPlan: h(1) }), /missing/);
  const transient = suppliedGraph(r, 0);
  assert.doesNotThrow(() => graph.normalizeScopedPolicyGraphV2Graph(transient));
  assert.throws(() => graph.validateScopedPolicyGraphV2Graph(coordinates, r, d, transient), /persistent/);
  assert.throws(() => graph.validateScopedPolicyGraphV2Graph(coordinates, r, { ...d, targets: [a(99), ...d.targets.slice(1)] }, suppliedGraph(r)), /mismatch/);
});

test("four dependency projections retain fixed coordinates and seven worker order", () => {
  const r = recipe(), g = suppliedGraph(r);
  const snapshot = graph.scopedPolicyGraphV2SnapshotDependencies(r, g);
  assert.deepEqual(snapshot.targets, [...r.inventory.targets.slice(0, 5), r.targets[0], r.targets[1], g.children[1], g.children[2], r.inventory.targets[10], g.sourceSet]);
  const reference = graph.scopedPolicyGraphV2ReferenceDependencies(r, g);
  assert.deepEqual(reference.targets, [...r.inventory.targets.slice(0, 5), g.children[3], r.inventory.targets[11]]);
  const inventory = graph.scopedPolicyGraphV2InventoryDependencies(r, g);
  assert.equal(inventory.targets[5], g.children[3]); assert.equal(inventory.targets[6], g.children[4]);
  assert.equal(r.inventory.targets[5], ZeroAddress);
  const bundle = graph.scopedPolicyGraphV2BundleDependencies(r, g);
  assert.deepEqual(bundle.targets, [r.inventory.targets[0], r.inventory.targets[1], g.children[5], r.inventory.targets[10], r.inventory.targets[11], r.inventory.artistTargets[4]]);
  const kinds = ["readiness", "checkpoint", "output", "snapshot", "reference", "inventory", "bundle"];
  for (let i = 0; i < 7; i++) assert.equal(graph.scopedPolicyGraphV2ChildConstructor(r, g, BigInt(i)).kind, kinds[i]);
  assert.throws(() => graph.scopedPolicyGraphV2ChildConstructor(r, g, 7n), /worker/);
  assert.equal(graph.scopedPolicyGraphV2ChildConstructor(r, g, 1n).executor, r.targets[3]);
});

test("only documented gas fields may rise in child dependency comparison", () => {
  const r = recipe(), g = suppliedGraph(r);
  const s = graph.scopedPolicyGraphV2SnapshotDependencies(r, g);
  const increased = { ...s, readGas: s.readGas + 1n, sourceGas: s.sourceGas + 2n, inventoryGas: s.inventoryGas + 3n };
  assert.deepEqual(graph.validateScopedPolicyGraphV2SnapshotDependencies(r, g, increased), increased);
  assert.throws(() => graph.validateScopedPolicyGraphV2SnapshotDependencies(r, g, { ...s, sourceGas: s.sourceGas - 1n }), /decrease/);
  assert.throws(() => graph.validateScopedPolicyGraphV2SnapshotDependencies(r, g, { ...increased, chainId: chainId + 1n }), /mismatch/);
  const ref = graph.scopedPolicyGraphV2ReferenceDependencies(r, g);
  assert.doesNotThrow(() => graph.validateScopedPolicyGraphV2ReferenceDependencies(r, g, { ...ref, archiveGas: ref.archiveGas + 1n }));
  assert.throws(() => graph.validateScopedPolicyGraphV2ReferenceDependencies(r, g, { ...ref, targets: [a(9), ...ref.targets.slice(1)] }), /mismatch/);
});

const legacyPolicy = (r, index = 0n) => {
  const p = { coordinator: a(400 + Number(index)), indexedCodeHash: h(400 + Number(index)), firstTokenIndex: index,
    frozen: true, moduleVersion: h(1), moduleManifestHash: h(2), moduleSchemaHash: h(3), deploymentManifestHash: h(4),
    policyHash: h(5), provider: a(6), epoch: 7n, salt: h(8), componentDataHash: ZeroHash,
    explicitPolicy: false, collectionPolicy: graph.scopedPolicyGraphV2EmptyPolicy() };
  p.componentDataHash = digest(["bytes32", "uint256", "address", "address", graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, "bytes32", "address", "uint32", "bytes32"],
    [id("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1"), chainId, r.inventory.targets[0], p.coordinator, scope, p.policyHash, p.provider, p.epoch, p.salt]);
  return p;
};

test("supplied explicit and legacy policy semantics retain distinct fields/domains and no provenance claim", () => {
  const r = recipe(), legacy = legacyPolicy(r);
  assert.doesNotThrow(() => graph.validateScopedPolicyGraphV2CoordinatorPolicy(chainId, r.inventory.targets[0], scope, legacy));
  assert.doesNotThrow(() => graph.validateScopedPolicyGraphV2CoordinatorPolicy(chainId, r.inventory.targets[0], scope, { ...legacy, frozen: false }));
  const policy = { configured: true, explicitPolicy: true, frozen: true, mode: 1n, securityClass: 1n,
    renderRequirement: 0n, revision: (1n << 64n) - 1n, providerEpoch: 9n, policyHash: h(55),
    contentStateHash: digest(["bytes32", "bytes32", "bool"], [id("6529STREAM_ENTROPY_CONFIGURATION_V1"), h(55), true]),
    lastActionId: h(56), artistConsentRecord: h(57) };
  const explicit = { ...legacy, explicitPolicy: true, collectionPolicy: policy, policyHash: policy.policyHash,
    provider: ZeroAddress, epoch: 0n, salt: ZeroHash,
    componentDataHash: digest(["bytes32", "uint256", "address", "address", graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, graph.SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE],
      [id("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V2"), chainId, r.inventory.targets[0], legacy.coordinator, scope, policy]) };
  assert.doesNotThrow(() => graph.validateScopedPolicyGraphV2CoordinatorPolicy(chainId, r.inventory.targets[0], scope, explicit));
  assert.throws(() => graph.validateScopedPolicyGraphV2CoordinatorPolicy(chainId, r.inventory.targets[0], scope, { ...explicit, provider: a(6) }), /explicit/);
  assert.throws(() => graph.validateScopedPolicyGraphV2CoordinatorPolicy(chainId, r.inventory.targets[0], scope, { ...explicit,
    collectionPolicy: { ...policy, contentStateHash: digest(["bytes32", "bytes32", "bool"], [id("ENTROPY_CONFIGURATION"), h(55), true]) } }), /explicit/);
});

test("source inventory checks complete ordered rows, original chain append and allFrozen separately", () => {
  const r = recipe(), d = dependencies(r), rows = [legacyPolicy(r), legacyPolicy(r, 1n)];
  const membership = { scopeSubject: graph.scopedPolicyGraphV2ScopeSubject(chainId, d.targets[0], scope),
    scopeManifestHash: h(31), sourceRecordHash: h(32), tokenCount: 2n, tokenListHash: h(33),
    membershipHash: h(34), inventoryCount: 2n, inventoryPrefixHash: h(35) };
  const plan = graph.scopedPolicyGraphV2InventoryPlan(d, scope, membership);
  const original = rows.map(({ coordinator, indexedCodeHash, firstTokenIndex }) => ({ coordinator, indexedCodeHash, firstTokenIndex }));
  const progress = { exists: true, complete: true, processedTokens: 2n, tokenCount: 2n, coordinatorCount: 2n,
    tokenChain: h(36), coordinatorChain: graph.scopedPolicyGraphV2CoordinatorChain(plan, original), commitment: ZeroHash };
  progress.commitment = graph.scopedPolicyGraphV2InventoryCommitment(plan, progress);
  const evidence = graph.validateScopedPolicyGraphV2PolicyEvidence(d, scope, membership, progress, rows);
  assert.equal(evidence.allFrozen, true); assert.equal(evidence.policyCount, 2n);
  assert.equal(graph.validateScopedPolicyGraphV2PolicyEvidence(d, scope, membership, progress, [{ ...rows[0], frozen: false }, rows[1]]).allFrozen, false);
  assert.throws(() => graph.validateScopedPolicyGraphV2PolicyEvidence(d, scope, membership, progress, [...rows].reverse()), /order/);
  assert.throws(() => graph.validateScopedPolicyGraphV2PolicyEvidence(d, scope, membership, { ...progress, complete: false }, rows), /Incomplete/);
  assert.notEqual(graph.scopedPolicyGraphV2PolicyChain(d, scope, plan, progress.commitment, rows),
    graph.scopedPolicyGraphV2PolicyChain(d, scope, plan, progress.commitment, [...rows].reverse()));
  const encoded = graph.encodeScopedPolicyGraphV2PolicyEvidence(evidence);
  assert.deepEqual(graph.decodeScopedPolicyGraphV2PolicyEvidence(encoded), evidence);
  assert.throws(() => graph.encodeScopedPolicyGraphV2PolicyEvidence({ ...evidence, policies: Array(1024).fill(rows[0]) }), /byte bound/);
  assert.throws(() => graph.normalizeScopedPolicyGraphV2PolicyEvidence({ ...evidence, policies: Array(1025).fill(rows[0]) }), /bounded/);
});

test("source-set manifest/data bind original membership and token inventory without extra factory words", () => {
  const r = recipe(), d = dependencies(r);
  const f = { scopeSubject: h(1), scopeManifestHash: h(2), sourceRecordHash: h(3), tokenCount: 4n,
    tokenListHash: h(5), membershipHash: h(6), inventoryCount: 7n, inventoryPrefixHash: h(8) };
  const dt = compiledInterfaces.sourceFactory.getFunction("dependencies").outputs[0];
  const mt = compiledInterfaces.sourceSet.getFunction("scopeMembershipFacts").outputs[0];
  assert.equal(graph.scopedPolicyGraphV2SourceSetManifestHash(d, a(90), h(90)), digest(["bytes32", dt, "address", "bytes32"],
    [id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"), d, a(90), h(90)]));
  assert.equal(graph.scopedPolicyGraphV2SourceSetDataHash(scope, h(1), h(2), h(3), f, a(90), h(90)),
    digest(["bytes32", graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, "bytes32", "bytes32", "bytes32", mt, "address", "bytes32"],
      [id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"), scope, h(1), h(2), h(3), f, a(90), h(90)]));
});

test("provider binding preserves full original configuration and excludes only its computed word", () => {
  const r = recipe(), d = dependencies(r);
  const original = { targets: Array.from({ length: 22 }, (_, i) => a(600 + i)), codeHashes: Array.from({ length: 22 }, (_, i) => h(600 + i)),
    chainId, readGas: 50000n, sourceGas: 3000000n, componentSourceGas: 2000000n, inventoryDependencyHash: h(700) };
  [0, 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21].forEach((index, i) => {
    if (i !== 5 && i !== 6) { original.targets[index] = r.inventory.targets[i]; original.codeHashes[index] = r.inventory.codeHashes[i]; }
  });
  original.targets[3] = r.targets[0]; original.codeHashes[3] = r.codeHashes[0];
  original.targets[11] = r.inventory.artistTargets[0]; original.codeHashes[11] = r.inventory.artistCodeHashes[0];
  const b = { factory: coordinates.publicationFactory, factoryCodeHash: h(4), recipeHash: graph.scopedPolicyGraphV2RecipeHash(chainId, r),
    sourceFactoryDependenciesHash: graph.scopedPolicyGraphV2DependenciesHash(d), graphGas: 500000n, configurationHash: ZeroHash };
  b.configurationHash = graph.scopedPolicyGraphV2ProviderConfigurationHash(a(701), original, b);
  assert.equal(graph.encodeScopedPolicyGraphV2NativeConfiguration(original), coder.encode([compiledInterfaces.provider.getFunction("nativeConfiguration").outputs[0]], [original]));
  assert.doesNotThrow(() => graph.validateScopedPolicyGraphV2FactoryBinding(coordinates, a(701), original, r, d, b));
  assert.equal(graph.scopedPolicyGraphV2ProviderConfigurationHash(a(701), original, { ...b, configurationHash: h(1) }), b.configurationHash);
  assert.notEqual(graph.scopedPolicyGraphV2ProviderConfigurationHash(a(702), original, b), b.configurationHash);
  assert.throws(() => graph.validateScopedPolicyGraphV2FactoryBinding(coordinates, a(701), original, r, d, { ...b, configurationHash: ZeroHash }));
  for (let i = 0; i < 3; i++) {
    const targets = [...d.targets]; targets[i] = a(800 + i);
    const wrong = { ...d, targets };
    const rebound = { ...b, sourceFactoryDependenciesHash: graph.scopedPolicyGraphV2DependenciesHash(wrong) };
    rebound.configurationHash = graph.scopedPolicyGraphV2ProviderConfigurationHash(a(701), original, rebound);
    assert.throws(() => graph.validateScopedPolicyGraphV2FactoryBinding(coordinates, a(701), original, r, wrong, rebound), /mismatch/);
  }
});

test("closed unsigned writes preserve scope, caller, target, zero value and immutable reconstruction", () => {
  for (const request of [{ kind: "prepareSourceSet", scope }, { kind: "prepareGraph", scope, maximumChildren: 7n }]) {
    const prepared = graph.prepareScopedPolicyGraphV2Call(coordinates, caller, request);
    const iface = request.kind === "prepareGraph" ? compiledInterfaces.publicationFactory : compiledInterfaces.sourceFactory;
    assert.equal(prepared.call.data, iface.encodeFunctionData(request.kind, request.kind === "prepareGraph" ? [scope, 7n] : [scope]));
    assert.equal(prepared.call.value, 0n); assert.equal(prepared.factsVerified, false);
    assert.deepEqual(graph.normalizeScopedPolicyGraphV2Call(prepared), prepared);
    assert.throws(() => graph.normalizeScopedPolicyGraphV2Call({ ...prepared, call: { ...prepared.call, value: 1n } }), /mismatch/);
    assert.throws(() => graph.normalizeScopedPolicyGraphV2Call({ ...prepared, call: { ...prepared.call, data: prepared.call.data + "00" } }), /mismatch/);
    assert.ok(Object.isFrozen(prepared.request.scope));
  }
  for (const n of [0n, 8n, 256n, 1]) assert.throws(() => graph.prepareScopedPolicyGraphV2Call(coordinates, caller, { kind: "prepareGraph", scope, maximumChildren: n }));
  assert.throws(() => graph.prepareScopedPolicyGraphV2Call(coordinates, caller, { kind: "prepareGraph", scope, maximumChildren: 1n, children: [] }), /fields/);
  assert.throws(() => graph.prepareScopedPolicyGraphV2Call(coordinates, caller, { kind: "publish", scope }), /Unknown/);
  for (const scopeType of [0n, 4n]) assert.throws(() => graph.prepareScopedPolicyGraphV2Call(coordinates, caller, { kind: "prepareSourceSet", scope: { ...scope, scopeType } }), /profile/);
});

test("closed factory reads keep raw missing-plan reads separate from current scope validation", () => {
  for (const request of [
    { host: "sourceFactory", kind: "dependencies" }, { host: "sourceFactory", kind: "sourceSetForPlan", plan: ZeroHash },
    { host: "sourceFactory", kind: "requireCurrentRoute", scope },
    { host: "publicationFactory", kind: "recipe" }, { host: "publicationFactory", kind: "graphForPlan", plan: ZeroHash },
    { host: "publicationFactory", kind: "requireCurrentGraph", scope },
    { host: "sourceFactory", kind: "supportsInterface", interfaceId: "0xffffffff" },
  ]) {
    const prepared = graph.prepareScopedPolicyGraphV2Read(coordinates, ZeroAddress, request);
    assert.equal(prepared.caller, ZeroAddress); assert.deepEqual(graph.normalizeScopedPolicyGraphV2Read(prepared), prepared);
  }
  assert.throws(() => graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "sourceFactory", kind: "prepareSourceSet", scope }), /read/);
  assert.throws(() => graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "publicationFactory", kind: "currentInventoryPlan", scope }));
  assert.throws(() => graph.prepareScopedPolicyGraphV2Read(coordinates, caller, { host: "sourceFactory", kind: "dependencies", scope }), /scope/);
  assert.throws(() => graph.decodeScopedPolicyGraphV2Graph("0x" + "00".repeat(32 * 24) + h(8).slice(2)));
});
