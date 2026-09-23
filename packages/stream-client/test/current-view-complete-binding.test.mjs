import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as p from "../dist/current-view-complete-binding.js";
import { fixture, compiledInterfaces as ci } from "./current-preservation-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = n => id(String(n));
const copy = structuredClone;
const C = { chainId: 1n, provider: A(900) };
const host = ci.StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1;
const other = ci.StreamFinalityFullPreservationPolicyEvidenceProviderV1;
const binding = ci.IStreamFinalityViewPreservationCompleteBindingV1;
const sources = ci.IStreamViewPreservationFinalitySourcesV1;
const basicABI = ci.IStreamFinalityViewPreservationBindingV1;
const T = {
  Configuration: binding.getFunction("bindCompleteViewPreservation").inputs[0],
  Declaration: binding.getFunction("bindCompleteViewPreservation").inputs[1],
  Selection: sources.getFunction("viewFinalitySources").outputs[0],
  Receipt: sources.getFunction("viewFinalitySourcesReceipt").outputs[0],
  BasicReceipt: basicABI.getFunction("viewPreservationBindingReceipt").outputs[0],
  Capability: basicABI.getFunction("viewPreservationBindingCapability").outputs[0],
  Transition: binding.getFunction("completeViewPreservationBindingTransition").outputs[0],
  NativeConfiguration: host.getFunction("nativeConfiguration").outputs[0],
  FactoryBinding: host.getFunction("scopedPreservationPolicyPublicationBinding").outputs[0],
  SnapshotDependencies: ci.StreamViewPreservationSnapshotPublicationV1.getFunction("dependencies").outputs[0],
  ReferenceDependencies: ci.StreamViewPreservationReferencePublicationV1.getFunction("dependencies").outputs[0],
  InventoryDependencies: ci.StreamViewPreservationRenderCriticalInventoryV1.getFunction("dependencies").outputs[0],
  BundleDependencies: ci.StreamViewPreservationBundleArchiveCoverageV1.getFunction("dependencies").outputs[0],
  Expected: ParamType.from(fixture.libraryAbis.StreamFinalityViewPreservationSourceSelectionV1.find(f => f.name === "requireBindings").inputs[1])
};
const hash = (types, values) => keccak256(coder.encode(types, values));
function zero(type) {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(field => [field.name, zero(field)]));
  if (type.baseType === "array") return Array.from({ length: type.arrayLength }, () => zero(type.arrayChildren));
  if (type.type === "address") return ZeroAddress;
  if (type.type.startsWith("uint")) return 0n;
  return `0x${"00".repeat(Number(type.type.slice(5)))}`;
}
function specimen() {
  const original = { targets: Array.from({ length: 22 }, (_, i) => A(i + 1)), codeHashes: Array.from({ length: 22 }, (_, i) => H(i + 1)),
    chainId: 1n, readGas: 1000000n, sourceGas: 4000000n, componentSourceGas: 1000000n, inventoryDependencyHash: ZeroHash };
  const indexes = [0, 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
  const originalInventory = { targets: indexes.map(i => original.targets[i]), codeHashes: indexes.map(i => original.codeHashes[i]),
    artistTargets: [original.targets[11], A(70), A(71), A(72), A(73)], artistCodeHashes: [original.codeHashes[11], H(70), H(71), H(72), H(73)],
    artistContentOwner: A(74), artistContentOwnerCodeHash: H(74), chainId: 1n,
    readGas: 1000000n, sourceGas: 18000000n, selectionGas: 8000000n, snapshotGas: 18000000n, referenceGas: 24000000n };
  original.inventoryDependencyHash = hash([T.InventoryDependencies], [originalInventory]);
  const capability = { authority: A(23), authorityCodeHash: H(23), originalHash: hash([T.NativeConfiguration], [original]), capabilityHash: ZeroHash };
  capability.capabilityHash = hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32"],
    [id("6529STREAM_FINALITY_VIEW_PRESERVATION_BINDING_V1"), C.chainId, C.provider, capability.authority, capability.authorityCodeHash, capability.originalHash]);
  const configuration = { snapshotHost: A(31), snapshotCodeHash: H(31), validationGas: 16000000n,
    checkpointHost: A(32), checkpointCodeHash: H(32), manifestHost: A(33), manifestCodeHash: H(33) };
  const declaration = { views: A(34), viewsCodeHash: H(34), membership: original.targets[3], membershipCodeHash: original.codeHashes[3],
    readGas: 2000000n, sourceGas: 4000000n };
  const dependencies = { targets: [original.targets[0], original.targets[1], original.targets[4], original.targets[5], original.targets[2],
    original.targets[3], A(32), A(33), original.targets[20], A(23)], codeHashes: [original.codeHashes[0], original.codeHashes[1],
    original.codeHashes[4], original.codeHashes[5], original.codeHashes[2], original.codeHashes[3], H(32), H(33), original.codeHashes[20], H(23)],
  chainId: 1n, readGas: 1000000n, sourceGas: 14000000n, inventoryGas: 4000000n };
  const workers = Array.from({ length: 5 }, (_, i) => A(50 + i)), workerHashes = Array.from({ length: 5 }, (_, i) => H(50 + i));
  const basic = { capabilityHash: capability.capabilityHash, configuration, declaration, dependencies,
    dependenciesHash: hash([T.SnapshotDependencies], [dependencies]), workersHash: hash(["address[5]", "bytes32[5]"], [workers, workerHashes]),
    actionId: ZeroHash, boundAt: 0n, recordHash: ZeroHash };
  const selection = { referencePublication: A(40), referencePublicationCodeHash: H(40), renderCriticalInventory: A(41),
    renderCriticalInventoryCodeHash: H(41), bundleArchiveCoverage: A(42), bundleArchiveCoverageCodeHash: H(42) };
  const expected = p.deriveViewCompleteBindingExpected(original, basic, selection, originalInventory);
  const reference = { targets: [0, 1, 2, 3, 4, 5, 11].map(i => expected.targets[i]), codeHashes: [0, 1, 2, 3, 4, 5, 11].map(i => expected.codeHashes[i]),
    chainId: 1n, readGas: 1000000n, sourceGas: 16000000n, snapshotGas: 16000000n, archiveGas: 1000000n };
  const inventory = { ...originalInventory, ...copy(expected) };
  const bundle = { targets: [expected.targets[0], expected.targets[1], selection.renderCriticalInventory, expected.targets[10], expected.targets[11], expected.artistTargets[4]],
    codeHashes: [expected.codeHashes[0], expected.codeHashes[1], selection.renderCriticalInventoryCodeHash, expected.codeHashes[10], expected.codeHashes[11], expected.artistCodeHashes[4]],
    chainId: 1n, readGas: 2000000n, archiveGas: 8000000n };
  const complete = { selection, referenceDependenciesHash: hash([T.ReferenceDependencies], [reference]), inventoryDependenciesHash: hash([T.InventoryDependencies], [inventory]),
    bundleDependenciesHash: hash([T.BundleDependencies], [bundle]), basicBindingRecordHash: ZeroHash, actionId: ZeroHash, boundAt: 0n, recordHash: ZeroHash };
  const candidate = { configuration, declaration, selection };
  return { original, originalInventory, capability, basic, complete, candidate, reference, inventory, bundle, expected, workers, workerHashes };
}
function originalBasicProposal(b) {
  return hash(["bytes32", "bytes32", T.Configuration, T.Declaration, T.SnapshotDependencies, "bytes32", "bytes32"],
    [id("6529STREAM_FINALITY_VIEW_PRESERVATION_PROPOSAL_V1"), b.capabilityHash, b.configuration, b.declaration, b.dependencies, b.dependenciesHash, b.workersHash]);
}
function mined(f) {
  f.basic.actionId = H("original action"); f.basic.boundAt = 1234n;
  f.basic.recordHash = hash(["bytes32", "bytes32", "bytes32", "uint64"],
    [id("6529STREAM_FINALITY_VIEW_PRESERVATION_RECEIPT_V1"), originalBasicProposal(f.basic), f.basic.actionId, f.basic.boundAt]);
  f.complete.actionId = f.basic.actionId; f.complete.boundAt = f.basic.boundAt; f.complete.basicBindingRecordHash = f.basic.recordHash;
  f.complete.recordHash = hash(["bytes32", "uint256", "address", T.Selection, "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"],
    [id("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"), C.chainId, C.provider, f.complete.selection,
      f.complete.referenceDependenciesHash, f.complete.inventoryDependenciesHash, f.complete.bundleDependenciesHash,
      f.basic.recordHash, f.basic.actionId, f.basic.boundAt]);
  return f;
}

test("fourteen structural codecs match complete compiler tuples including names and original zero records", () => {
  const shape = t => ({ type: t.format("sighash"), fields: t.components?.map(c => ({ name: c.name, ...shape(c) })), child: t.arrayChildren ? shape(t.arrayChildren) : undefined });
  for (const [name, original] of Object.entries(T)) {
    const key = `VIEW_COMPLETE_BINDING_${name.replace(/([a-z])([A-Z])/g, "$1_$2").toUpperCase()}_TUPLE`;
    assert.deepEqual(shape(ParamType.from(p[key])), shape(original), name);
    const value = zero(original), raw = coder.encode([original], [value]);
    assert.equal(p[`encodeViewCompleteBinding${name}`](value), raw, name);
    assert.deepEqual(p[`decodeViewCompleteBinding${name}`](raw), value, name);
    assert.throws(() => p[`decodeViewCompleteBinding${name}`](`${raw}${"00".repeat(32)}`), /canonical/);
  }
  assert.equal(p.encodeViewCompleteBindingReceipt(zero(T.Receipt)).length, 2 + 416 * 2);
  assert.throws(() => p.authenticateViewCompleteBindingHistory(C, zero(T.BasicReceipt), zero(T.Receipt)), /Zero/);
});

test("five shared methods and complete event match both genuine hosts; basic writes are absent", () => {
  const own = p.viewCompleteBindingInterface();
  assert.equal(own.fragments.filter(f => f.type === "function").length, 5);
  for (const f of own.fragments) for (const original of [host, other]) {
    const actual = f.type === "function" ? original.getFunction(f.format("sighash")) : original.getEvent(f.format("sighash"));
    assert.ok(actual);
    if (f.type === "function") { assert.equal(f.selector, actual.selector); assert.equal(f.stateMutability, actual.stateMutability); }
    else { assert.equal(f.topicHash, actual.topicHash); assert.deepEqual(f.inputs.map(x => Boolean(x.indexed)), actual.inputs.map(x => Boolean(x.indexed))); }
    assert.deepEqual(f.outputs?.map(x => x.format("sighash")), actual.outputs?.map(x => x.format("sighash")));
  }
  assert.equal(own.getFunction("bindViewPreservation"), null);
  assert.equal(own.getEvent("ViewPreservationBound"), null);
  for (const f of p.viewCompleteBindingObservationInterface().fragments) {
    assert.equal(f.selector, host.getFunction(f.name).selector);
    assert.equal(f.stateMutability, host.getFunction(f.name).stateMutability);
  }
});

test("capability and basic/full proposals use independent compiler preimages and exclude future receipt fields", () => {
  const f = specimen(), { basic: b, complete: r } = f;
  assert.equal(p.viewCompleteBindingCapabilityHash(C, f.capability), f.capability.capabilityHash);
  assert.equal(p.viewCompleteBindingBasicProposalHash(b), originalBasicProposal(b));
  const proposal = hash(["bytes32", "bytes32", T.Selection, "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_PROPOSAL_V1"), originalBasicProposal(b), r.selection,
      r.referenceDependenciesHash, r.inventoryDependenciesHash, r.bundleDependenciesHash]);
  assert.equal(p.viewCompleteBindingProposalHash(b, r), proposal);
  assert.notEqual(proposal, originalBasicProposal(b));
  const before = p.viewCompleteBindingTransition(C, b, r); mined(f);
  assert.equal(p.viewCompleteBindingProposalHash(b, r), proposal);
  assert.deepEqual(p.viewCompleteBindingTransition(C, b, r), before);
  assert.equal(p.viewCompleteBindingBasicReceiptHash(b), b.recordHash);
  assert.equal(p.viewCompleteBindingReceiptHash(C, r), r.recordHash);
  assert.equal(before.scopeHash, hash(["bytes32", "uint256", "address", "bytes32"], [id("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_BINDING_V1"), C.chainId, C.provider, b.capabilityHash]));
  assert.equal(before.oldValueHash, hash(["bytes32", "bytes32", "bool"], [id("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_BINDING_V1"), b.capabilityHash, false]));
});

test("every full proposal family and receipt domain coordinate is committed", () => {
  const f = specimen(), initial = p.viewCompleteBindingProposalHash(f.basic, f.complete);
  for (const mutate of [b => b.capabilityHash = H(991), b => b.configuration.validationGas++, b => b.declaration.sourceGas++,
    b => b.dependencies.codeHashes[1] = H(991), b => b.dependenciesHash = H(991), b => b.workersHash = H(991)]) {
    const b = copy(f.basic); mutate(b); assert.notEqual(p.viewCompleteBindingProposalHash(b, f.complete), initial);
  }
  for (const key of ["referenceDependenciesHash", "inventoryDependenciesHash", "bundleDependenciesHash"]) {
    assert.notEqual(p.viewCompleteBindingProposalHash(f.basic, { ...f.complete, [key]: H(991) }), initial);
  }
  for (const key of Object.keys(f.complete.selection)) {
    const r = copy(f.complete); r.selection[key] = key.endsWith("CodeHash") ? H(991) : A(991);
    assert.notEqual(p.viewCompleteBindingProposalHash(f.basic, r), initial);
  }
  mined(f);
  for (const c of [{ ...C, chainId: 2n }, { ...C, provider: A(991) }]) assert.notEqual(p.viewCompleteBindingReceiptHash(c, f.complete), f.complete.recordHash);
  assert.notEqual(p.viewCompleteBindingReceiptHash(C, { ...f.complete, boundAt: 1235n }), f.complete.recordHash);
  assert.notEqual(p.viewCompleteBindingReceiptHash(C, { ...f.complete, actionId: H(991) }), f.complete.recordHash);
});

test("local paired history rejects self-consistently rehashed linkage substitutions without live reads", () => {
  const f = mined(specimen());
  const history = p.authenticateViewCompleteBindingHistory(C, f.basic, f.complete);
  assert.equal(history.currentnessChecked, false); assert.equal(history.factsVerified, false);
  for (const key of ["basicBindingRecordHash", "actionId", "boundAt"]) {
    const r = copy(f.complete); r[key] = key === "boundAt" ? 1235n : H(991);
    r.recordHash = p.viewCompleteBindingReceiptHash(C, r);
    assert.throws(() => p.authenticateViewCompleteBindingHistory(C, f.basic, r), /link/);
  }
  const r = copy(f.complete); r.actionId = ZeroHash; r.recordHash = p.viewCompleteBindingReceiptHash(C, r);
  assert.throws(() => p.authenticateViewCompleteBindingHistory(C, f.basic, r), /Zero/);
  const b = copy(f.basic); b.workersHash = H(991);
  assert.throws(() => p.authenticateViewCompleteBindingHistory(C, b, f.complete), /commitment/);
  assert.equal(p.authenticateViewCompleteBindingHistory(C, f.basic, f.complete).complete.referenceDependenciesHash, f.complete.referenceDependenciesHash);
});

test("two genuine provider constructor domains remain distinct with exact four constructor tuples", () => {
  const f = specimen(), constructor = host.deploy.inputs;
  const value = { original: f.original, scoped: { ...f.original, readGas: 2000000n },
    collectionFactory: { factory: A(80), factoryCodeHash: H(80), recipeHash: H(81), sourceFactoryDependenciesHash: H(82), graphGas: 10000000n, configurationHash: H(83) },
    publicationFactory: { factory: A(90), factoryCodeHash: H(90), recipeHash: H(91), sourceFactoryDependenciesHash: H(92), graphGas: 12000000n, configurationHash: H(93) } };
  for (const [kind, domain] of [["preservation", "6529STREAM_FINALITY_PRESERVATION_FACTORY_SOURCE_CONFIGURATION_V1"],
    ["current-authority-preservation", "6529STREAM_CURRENT_AUTHORITY_PRESERVATION_FACTORY_SOURCE_CONFIGURATION_V1"]]) {
    assert.equal(p.viewCompleteBindingSourceConfigurationHash(kind, C, value), hash(["bytes32", "uint256", "address", ...constructor],
      [id(domain), C.chainId, C.provider, value.original, value.scoped, value.collectionFactory, value.publicationFactory]));
  }
  assert.notEqual(p.viewCompleteBindingSourceConfigurationHash("preservation", C, value), p.viewCompleteBindingSourceConfigurationHash("current-authority-preservation", C, value));
  assert.throws(() => p.viewCompleteBindingSourceConfigurationHash("unknown", C, value), /profile/);
});

test("supplied basic admission joins original authority/roster and rejects future receipt fields", () => {
  const f = specimen();
  assert.deepEqual(p.validateViewCompleteBindingBasicCandidate(C, f.original, f.capability, f.basic), f.basic);
  assert.equal(p.validateViewCompleteBindingCapability(C, f.original, f.capability).factsVerified, false);
  for (const mutate of [b => b.actionId = H(991), b => b.boundAt = 1n, b => b.recordHash = H(991), b => b.capabilityHash = H(991),
    b => b.declaration.membership = A(991), b => b.dependencies.targets[9] = A(991), b => b.dependencies.targets[4] = A(991),
    b => b.dependencies.chainId = 2n, b => b.dependenciesHash = H(991), b => b.workersHash = ZeroHash]) {
    const b = copy(f.basic); mutate(b);
    assert.throws(() => p.validateViewCompleteBindingBasicCandidate(C, f.original, f.capability, b));
  }
  assert.throws(() => p.validateViewCompleteBindingCapability({ ...C, provider: A(991) }, f.original, f.capability), /hash/);
  assert.throws(() => p.validateViewCompleteBindingCapability(C, f.original, { ...f.capability, authority: ZeroAddress }), /Zero/);
});

test("strict original forwarding reserve and finite declaration widths preserve exact endpoints", () => {
  const inner = 1000000n, boundary = inner + inner / 63n + 10000n;
  assert.equal(p.viewCompleteBindingFits(boundary, inner), false);
  assert.equal(p.viewCompleteBindingFits(boundary + 1n, inner), true);
  assert.equal(p.viewCompleteBindingFits((1n << 256n) - 1n, (1n << 256n) - 1n), false);
  const f = specimen();
  for (const value of [0n, 16777217n, f.basic.dependencies.sourceGas]) {
    assert.throws(() => p.validateViewCompleteBindingBasicCandidate(C, f.original, f.capability,
      { ...f.basic, configuration: { ...f.basic.configuration, validationGas: value } }));
  }
  assert.throws(() => p.normalizeViewCompleteBindingDeclaration({ ...f.basic.declaration, readGas: 1n << 32n }), /uint32/);
  assert.doesNotThrow(() => p.normalizeViewCompleteBindingConfiguration({ ...f.basic.configuration, validationGas: 1n << 200n }));
});

test("expected complete roster is derived only from exact original inventory with three substitutions", () => {
  const f = specimen();
  assert.equal(f.expected.targets[5], f.basic.configuration.snapshotHost);
  assert.equal(f.expected.targets[6], f.complete.selection.referencePublication);
  assert.equal(f.expected.targets[10], f.basic.dependencies.targets[8]);
  assert.deepEqual(f.expected.artistTargets, f.originalInventory.artistTargets);
  for (const mutate of [d => d.targets[0] = A(991), d => d.artistTargets[0] = A(991), d => d.chainId = 2n]) {
    const d = copy(f.originalInventory); mutate(d);
    const original = { ...f.original, inventoryDependencyHash: hash([T.InventoryDependencies], [d]) };
    assert.throws(() => p.deriveViewCompleteBindingExpected(original, f.basic, f.complete.selection, d), /roster|anchor|chain/);
  }
  assert.throws(() => p.deriveViewCompleteBindingExpected({ ...f.original, inventoryDependencyHash: H(991) }, f.basic, f.complete.selection, f.originalInventory), /hash/);
});

test("producer dependency projections preserve reference-gas drift without rewriting historical admission", () => {
  const f = mined(specimen());
  const initial = p.validateViewCompleteBindingProducerDependencies(f.expected, f.complete.selection, f.reference, f.inventory, f.bundle);
  assert.equal(initial.referenceDependenciesHash, f.complete.referenceDependenciesHash);
  const reference = { ...f.reference, sourceGas: 17000000n, snapshotGas: 18000000n };
  const changed = p.validateViewCompleteBindingProducerDependencies(f.expected, f.complete.selection, reference, f.inventory, f.bundle);
  assert.notEqual(changed.referenceDependenciesHash, initial.referenceDependenciesHash);
  assert.equal(changed.factsVerified, false);
  assert.equal(p.authenticateViewCompleteBindingHistory(C, f.basic, f.complete).complete.recordHash, f.complete.recordHash);
  for (const [which, mutate] of [["reference", d => d.targets[5] = A(991)], ["inventory", d => d.artistContentOwner = A(991)],
    ["inventory", d => d.artistTargets[3] = A(991)], ["bundle", d => d.targets[5] = A(991)], ["reference", d => d.snapshotGas = 50000n]]) {
    const rows = { reference: copy(f.reference), inventory: copy(f.inventory), bundle: copy(f.bundle) }; mutate(rows[which]);
    assert.throws(() => p.validateViewCompleteBindingProducerDependencies(f.expected, f.complete.selection, rows.reference, rows.inventory, rows.bundle));
  }
});

test("worker commitment preserves the ordered five original addresses and runtimes", () => {
  const f = specimen();
  assert.equal(p.viewCompleteBindingWorkersHash(f.workers, f.workerHashes), f.basic.workersHash);
  assert.notEqual(p.viewCompleteBindingWorkersHash([...f.workers].reverse(), f.workerHashes), f.basic.workersHash);
  assert.notEqual(p.viewCompleteBindingWorkersHash(f.workers, [...f.workerHashes].reverse()), f.basic.workersHash);
  assert.throws(() => p.viewCompleteBindingWorkersHash(f.workers.slice(1), f.workerHashes));
});

test("closed five-method plans reproduce compiler calldata and explicitly require nested governance", () => {
  const f = specimen(), call = p.prepareViewCompleteBindingCall(C, f.candidate);
  assert.equal(call.call.data, host.encodeFunctionData("bindCompleteViewPreservation", [f.candidate.configuration, f.candidate.declaration, f.candidate.selection]));
  assert.equal((call.call.data.length - 2) / 2, 612);
  assert.equal(call.governanceTargetOnly, true); assert.equal(call.requiredActionClass, 2n); assert.equal(call.call.value, 0n);
  assert.deepEqual(p.normalizeViewCompleteBindingCall(call), call);
  for (const kind of ["completeViewPreservationBindingProfile", "completeViewPreservationBindingTransition", "viewFinalitySources", "viewFinalitySourcesReceipt"]) {
    const request = kind.endsWith("Transition") ? { kind, candidate: f.candidate } : { kind };
    const read = p.prepareViewCompleteBindingRead(C, request);
    const args = kind.endsWith("Transition") ? [f.candidate.configuration, f.candidate.declaration, f.candidate.selection] : [];
    assert.equal(read.call.data, host.encodeFunctionData(kind, args)); assert.deepEqual(p.normalizeViewCompleteBindingRead(read), read);
  }
  assert.throws(() => p.prepareViewCompleteBindingRead(C, { kind: "bindViewPreservation" }));
  assert.throws(() => p.prepareViewCompleteBindingRead(C, { kind: "viewFinalitySources", candidate: f.candidate }));
  for (const mutate of [v => v.call.to = A(991), v => v.call.value = 1n, v => v.call.data += "00", v => v.governanceTargetOnly = false,
    v => v.requiredActionClass = 1n, v => v.candidate.selection.referencePublication = A(991)]) {
    const value = copy(call); mutate(value); assert.throws(() => p.normalizeViewCompleteBindingCall(value));
  }
});

test("codecs reject sparse/surplus/dirty/out-of-width/oversized input and own immutable nested copies", () => {
  const f = specimen();
  for (const mutate of [v => delete v.targets[2], v => v.targets.extra = 1, v => v.targets[Symbol()] = 1,
    v => Object.defineProperty(v.targets, "hidden", { value: 1 }), v => v.chainId = 1, v => v.codeHashes[0] = "0x12",
    v => v.extra = true, v => Object.defineProperty(v, "hidden", { value: 1 })]) {
    const value = copy(f.original); mutate(value); assert.throws(() => p.normalizeViewCompleteBindingNativeConfiguration(value));
  }
  const raw = p.encodeViewCompleteBindingDeclaration(f.basic.declaration).slice(2);
  assert.throws(() => p.decodeViewCompleteBindingDeclaration(`0x${raw.slice(0, 4 * 64)}${"f".repeat(64)}${raw.slice(5 * 64)}`));
  assert.throws(() => p.decodeViewCompleteBindingSelection(`0x${"00".repeat(262145)}`), /bound/);
  const c = p.prepareViewCompleteBindingCall(C, f.candidate); f.candidate.configuration.snapshotHost = A(991);
  assert.equal(c.candidate.configuration.snapshotHost, A(31));
  assert.ok(Object.isFrozen(c.candidate.configuration)); assert.ok(Object.isFrozen(p.normalizeViewCompleteBindingNativeConfiguration(f.original).targets));
});
