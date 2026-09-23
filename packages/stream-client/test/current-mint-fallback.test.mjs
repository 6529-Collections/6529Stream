import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, concat, id, keccak256, toUtf8Bytes } from "ethers";
import * as fallback from "../dist/current-mint-fallback.js";
import { buildMintContinuityArtifact, mintImportGovernanceTransition,
  prepareCounterDefinitionImport, prepareMintAncestryImport, prepareMintImportCommit,
  prepareMintImportCompletion, prepareMintStateImport } from "../dist/current-mint-continuity.js";

const f = JSON.parse(readFileSync(new URL("./fixtures/current-mint-fallback-abi.json", import.meta.url)));
const interfaces = Object.fromEntries(Object.entries(f.abis).map(([key, abi]) => [key, new Interface(abi)]));
const coder = AbiCoder.defaultAbiCoder(), A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const h = (types, values) => keccak256(coder.encode(types, values));
const moduleKeys = ["revenueResolver", "metadataRouter", "collectionMetadata", "entropyCoordinator", "mintManager", "mintLedger", "artistRegistry", "streamAdminsOrGovernance", "artworkFinalityRegistry", "moduleRegistry", "stateExportPublisher"];
const discoveryKeys = ["eventCatalogHash", "compatibilityMatrixHash", "numericIdCatalogHash", "schemaCatalogHash", "canonicalizationCatalogHash", "specBundleHash", "reconstructionClientHash"];
function configuration() {
  return { chainId: (1n << 200n) + 31337n, core: A(1), ledger: A(2), primary: A(3), fallbackManager: A(4), registry: A(5), governance: A(6),
    coreCodeHash: id("core runtime"), ledgerCodeHash: id("Ledger runtime"), primaryCodeHash: id("primary runtime"), fallbackCodeHash: id("fallback runtime"),
    registryCodeHash: id("registry runtime"), governanceCodeHash: id("actual Executor runtime"), moduleVersion: id("version1"),
    deploymentManifestHash: id("deployment"), moduleManifestHash: id("reserve module"), moduleManifestURI: "ipfs://reserve", moduleGasLimit: (1n << 32n) - 1n,
    recorder: ZeroAddress, recorderCodeHash: ZeroHash };
}
function classifier(c = configuration(), enabled = false, revision = (1n << 60n) + 9n) {
  const targetCodeHash = enabled ? c.ledgerCodeHash : ZeroHash;
  const stateHash = h(["bytes32", "uint256", "address", "bytes32", "address", "bytes4", "bool", "bytes32", "uint64"],
    [id("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"), c.chainId, c.governance, id("6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL"), c.ledger,
      interfaces.ledger.getFunction("retireLedgerWriter").selector, enabled, targetCodeHash, revision]);
  return { enabled, targetCodeHash, revision, stateHash };
}
function activation(c = configuration()) {
  const modules = Object.fromEntries(moduleKeys.map((key, i) => [key, A(100 + i)]));
  Object.assign(modules, { mintManager: c.primary, mintLedger: c.ledger, moduleRegistry: c.registry, streamAdminsOrGovernance: c.governance, stateExportPublisher: ZeroAddress });
  const discovery = Object.fromEntries(discoveryKeys.map(key => [key, id(`old ${key}`)]));
  return { manifest: A(20), payloadRoot: A(21), update: { manifestHash: id("new manifest"), manifestURI: "ipfs://manifest/é", ...Object.fromEntries(discoveryKeys.map(key => [key, id(`new ${key}`)])) },
    current: { manifestHash: id("old manifest"), manifestURI: "ipfs://previous", modules, discovery, revision: (1n << 62n) + 11n, payloadRoot: A(22) },
    previousPointer: { target: c.primary, codeHash: c.primaryCodeHash, frozen: false, moduleType: id("MINT_MANAGER"), interfaceId: "0xb4074ed7",
      registry: c.registry, registryStatus: 3n, moduleManifestHash: id("primary manifest"), deploymentManifestHash: id("primary deployment"), revision: (1n << 61n) + 7n } };
}
function incident() {
  return { tokenId: (1n << 180n) + 3n, operationId: id("original pending operation"), state: {
    collectionId: (1n << 200n) + 1n, serial: (1n << 190n) + 2n, lastTokenId: (1n << 230n) + 3n,
    nextSerial: (1n << 210n) + 4n, mintedEver: (1n << 180n) + 5n, supply: (1n << 170n) + 6n,
    tokenDataHash: keccak256("0x123400"), coordinator: A(30) } };
}
function artifact(c = configuration()) {
  const coordinates = { chainId: c.chainId, successorLedger: c.ledger, predecessorLedger: c.ledger, predecessorManager: c.primary, successorManager: c.fallbackManager, snapshotBlock: (1n << 60n) + 123n };
  const leaf = { collectionId: 8n, phaseId: id("phase"), counterId: id("actual definition"), keyMode: 1n, subjectBasis: ZeroHash, predecessorSubjectKey: ZeroHash, value: 17n };
  leaf.predecessorSubjectKey = h(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "bytes32"],
    [id("6529STREAM_MINT_COUNTER_SUBJECT_V1"), c.chainId, c.ledger, 1n, leaf.collectionId, leaf.phaseId, leaf.counterId]);
  return buildMintContinuityArtifact({ coordinates, counterLeaves: [leaf], nullifiers: [id("actual spent raw nullifier")], inventoryCompletenessReviewed: true });
}
function ordinary(call) {
  return { target: call.to, value: 0n, selector: call.data.slice(0, 10), callDataHash: keccak256(call.data),
    scopeHash: h(["address", "bytes"], [call.to, call.data]), oldValueHash: ZeroHash, newValueHash: keccak256(call.data) };
}
function assertCall(plan, index, name, abiKey, target, args) {
  const data = interfaces[abiKey].encodeFunctionData(name, args);
  assert.equal(plan.data[index], data); assert.deepEqual(plan.targetCalls[index], { to: target, value: 0n, data });
  assert.equal(plan.calls[index].target, target); assert.equal(plan.calls[index].value, 0n);
  assert.equal(plan.calls[index].selector, data.slice(0, 10)); assert.equal(plan.calls[index].callDataHash, keccak256(data));
}

test("fallback registration preserves the original Manager module/interface and exact pins", () => {
  const c = configuration(), r = fallback.mintFallbackRegistration(c);
  const functions = interfaces.managerInterface.fragments.filter(x => x.type === "function");
  const interfaceId = `0x${functions.reduce((n, x) => n ^ BigInt(interfaces.managerInterface.getFunction(x.format()).selector), 0n).toString(16).padStart(8, "0")}`;
  assert.equal(interfaceId, fallback.MINT_FALLBACK_MANAGER_INTERFACE_ID);
  assert.equal(r.module, c.fallbackManager); assert.equal(r.moduleType, id("MINT_MANAGER")); assert.equal(r.interfaceId, interfaceId);
  assert.equal(r.expectedRuntimeCodeHash, c.fallbackCodeHash); assert.equal(r.moduleGasLimit, c.moduleGasLimit);
  const registration = interfaces.registry.getFunction("registerModule").inputs[0];
  assert.equal(coder.decode([registration], coder.encode([registration], [r]))[0].moduleManifestURI, c.moduleManifestURI);
  for (const bad of [{ ...c, primary: c.fallbackManager }, { ...c, coreCodeHash: ZeroHash }, { ...c, recorder: A(9) },
    { ...c, recorderCodeHash: id("recorder") }, { ...c, moduleGasLimit: 1n << 32n }, { ...c, chainId: 1 }, { ...c, moduleManifestURI: "" }, { ...c, caller: A(9) }]) {
    assert.throws(() => fallback.normalizeMintFallbackConfiguration(bad));
  }
  assert.equal(fallback.normalizeMintFallbackConfiguration({ ...c, recorder: A(9), recorderCodeHash: id("recorder") }).recorder, A(9));
});

test("retirement classification is isolated class1 at the actual Executor with its original transition", () => {
  const c = configuration(), old = classifier(c), p = fallback.mintFallbackRetirementClassificationCall(c, old);
  const selector = interfaces.ledger.getFunction("retireLedgerWriter").selector;
  assertCall(p, 0, "setTighteningCall", "executor", c.governance, [c.ledger, selector, true]);
  assert.equal(p.actor, c.governance); assert.equal(p.actionClass, 1n); assert.equal(p.isolated, true); assert.equal(p.permissionless, false);
  assert.equal(p.calls[0].scopeHash, h(["bytes32", "uint256", "address", "bytes32", "address", "bytes4"],
    [id("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"), c.chainId, c.governance, id("6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL"), c.ledger, selector]));
  assert.equal(p.calls[0].oldValueHash, old.stateHash);
  assert.equal(p.calls[0].newValueHash, classifier(c, true, old.revision + 1n).stateHash);
  assert.equal(p.factsVerified, false);
  for (const bad of [classifier(c, true), { ...old, stateHash: ZeroHash }, classifier(c, false, (1n << 64n) - 1n)]) {
    assert.throws(() => fallback.mintFallbackRetirementClassificationCall(c, bad));
  }
});

test("permanent retirement is class0 with owner actor and original ordinary-call transition", () => {
  const c = configuration(), p = fallback.mintFallbackRetirementCall(c, classifier(c, true));
  assertCall(p, 0, "retireLedgerWriter", "ledger", c.ledger, [c.primary]);
  assert.deepEqual(p.calls[0], ordinary(p.targetCalls[0]));
  assert.equal(p.actionClass, 0n); assert.equal(p.actor, c.governance); assert.equal(p.permissionless, false);
  assert.throws(() => fallback.mintFallbackRetirementCall(c, classifier(c)));
  assert.throws(() => fallback.mintFallbackRetirementCall(c, { ...classifier(c, true), targetCodeHash: id("stale code") }));
});

test("genuine same-Ledger import reuses original commitment, copied definitions/ancestors and proofs", () => {
  const c = configuration(), a = artifact(c);
  const plans = [fallback.mintFallbackImportCommitCall(c, a), fallback.mintFallbackCopyDefinitionsCall(c, a, 32n),
    fallback.mintFallbackCopyAncestorsCall(c, a, 7n), fallback.mintFallbackImportStateCall(c, a, [0], [0]), fallback.mintFallbackCompleteImportCall(c, a)];
  const original = [prepareMintImportCommit(a).targetCall, prepareCounterDefinitionImport(a, 32n).call,
    prepareMintAncestryImport(a, 7n).call, prepareMintStateImport(a, c.governance, [0], [0]).call, prepareMintImportCompletion(a).call];
  const transition = mintImportGovernanceTransition({ ...a.coordinates, importRoot: a.importRoot, manifestHash: a.manifestHash });
  for (let i = 0; i < plans.length; i++) {
    assert.deepEqual(plans[i].targetCalls, [original[i]]); assert.equal(plans[i].actionClass, 1n); assert.equal(plans[i].factsVerified, false);
    if (i) assert.deepEqual(plans[i].calls[0], ordinary(original[i]));
    assert.equal(plans[i].permissionless, [1, 2, 4].includes(i)); assert.equal(plans[i].actor, [1, 2, 4].includes(i) ? null : c.governance);
    assert.deepEqual(fallback.normalizeMintFallbackPlan(structuredClone(plans[i])), plans[i]);
  }
  assert.equal(plans[0].calls[0].scopeHash, transition.scope); assert.equal(plans[0].calls[0].oldValueHash, ZeroHash); assert.equal(plans[0].calls[0].newValueHash, transition.newHash);
  assertCall(plans[0], 0, "commitCounterImportRoot", "ledger", c.ledger, [c.ledger, c.primary, c.fallbackManager, a.coordinates.snapshotBlock, a.importRoot, a.manifestHash]);
  const managerImport = interfaces.fallback.decodeFunctionData("importMintState", plans[3].data[0])[0];
  const batchType = "tuple(bytes32 importRoot,tuple(uint256 collectionId,bytes32 phaseId,bytes32 counterId,uint8 keyMode,bytes32 subjectBasis,bytes32 predecessorSubjectKey,uint64 value)[] counters,bytes32[][] counterProofs,bytes32[] nullifiers,bytes32[][] nullifierProofs)";
  assert.equal(coder.decode([batchType], managerImport)[0].nullifiers[0], a.nullifiers[0]);
  assert.throws(() => fallback.mintFallbackImportCommitCall({ ...c, ledger: A(40) }, a), /exact same-Ledger/);
  assert.throws(() => fallback.mintFallbackImportCommitCall(c, { ...a, importRoot: id("fabricated") }));
  assert.throws(() => fallback.mintFallbackImportStateCall(c, a, [0, 0], []));
});

test("raw original producer inputs retain supplied roots/proofs without claiming source completeness", () => {
  const c = configuration(), root = id("genuine external producer root"), snapshot = { snapshotBlock: 9n, importRoot: root, manifestHash: id("external manifest") };
  const commit = fallback.mintFallbackRawImportCommitCall(c, snapshot);
  assertCall(commit, 0, "commitCounterImportRoot", "ledger", c.ledger, [c.ledger, c.primary, c.fallbackManager, 9n, root, snapshot.manifestHash]);
  for (const [make, method] of [[fallback.mintFallbackRawCopyDefinitionsCall, "importCounterDefinitions"], [fallback.mintFallbackRawCopyAncestorsCall, "importMintAncestors"]]) {
    const p = make(c, root, 3n); assertCall(p, 0, method, "ledger", c.ledger, [root, 3n]); assert.equal(p.actor, null);
    for (const count of [0n, 33n, 1]) assert.throws(() => make(c, root, count));
  }
  const batch = { importRoot: root, counters: [], counterProofs: [], nullifiers: [id("spent")], nullifierProofs: [[id("proof")]] };
  const state = fallback.mintFallbackRawImportStateCall(c, batch);
  assert.equal(state.actor, c.governance); assert.equal(state.calls[0].selector, interfaces.fallback.getFunction("importMintState").selector);
  const descriptor = { importRoot: root, counterCount: 0n, nullifierCount: 0n, descriptorProof: [id("real descriptor proof")] };
  const completion = fallback.mintFallbackRawCompleteImportCall(c, descriptor);
  assertCall(completion, 0, "completeCounterImport", "ledger", c.ledger, [root, 0n, 0n, descriptor.descriptorProof]);
  assert.equal(completion.factsVerified, false); assert.equal(completion.permissionless, true);
  for (const p of [commit, state, completion]) assert.deepEqual(fallback.normalizeMintFallbackPlan(p), p);
  assert.throws(() => fallback.mintFallbackRawImportStateCall(c, { ...batch, nullifierProofs: [] }));
  assert.throws(() => fallback.mintFallbackRawImportStateCall(c, { ...batch, nullifiers: [], nullifierProofs: [] }));
  assert.throws(() => fallback.mintFallbackRawCompleteImportCall(c, { ...descriptor, counterCount: 1n << 64n }));
  assert.throws(() => fallback.mintFallbackRawImportCommitCall(c, { ...snapshot, snapshotBlock: 0n }));
});

test("normal activation replaces only the Manager pointer and preserves the full manifest tail", () => {
  const c = configuration(), a = activation(c), p = fallback.mintFallbackActivationCalls(c, a), next = fallback.mintFallbackNextPointer(c, a.previousPointer);
  assert.equal(p.actionClass, 3n); assert.equal(p.calls.length, 2); assert.equal(p.actor, c.governance);
  assertCall(p, 0, "updateSatellitePointer", "core", c.core, [id("MINT_MANAGER"), c.fallbackManager]);
  assertCall(p, 1, "publishStreamSystemManifest", "manifest", a.manifest, [a.payloadRoot, a.update]);
  const scope = h(["bytes32", "uint256", "address", "bytes32"], ["0xf4a381d3d4c51db07c19830799ea01c544326118ea1db1fb59d54af5f637bdbb", c.chainId, c.core, id("MINT_MANAGER")]);
  const pointerHash = q => h(["bytes32", "bytes32", "address", "bytes32", "bool", "bytes32", "bytes4", "address", "uint8", "bytes32", "bytes32", "uint64"],
    ["0x1fdde0a7122d0fc7c237e721e372e43082581dcc6bd2babca4e09bb1e6b3d043", scope, q.target, q.codeHash, q.frozen, q.moduleType, q.interfaceId, q.registry, q.registryStatus, q.moduleManifestHash, q.deploymentManifestHash, q.revision]);
  assert.equal(p.calls[0].oldValueHash, pointerHash(a.previousPointer)); assert.equal(p.calls[0].newValueHash, pointerHash(next));
  assert.equal(next.registryStatus, 1n); assert.equal(next.revision, a.previousPointer.revision + 1n);
  const ms = h(["bytes32", "uint256", "address"], ["0xf73b4d7b4d260fce0823707f836fdf29a1767a2a2a9cfbce14ec8c5e49e47841", c.chainId, a.manifest]);
  const manifestHash = (manifest, uri, payload, modules, discovery, revision) => h(["bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32", "uint64"],
    ["0x3764ccb415d0aac07f1bddb8d4841ad6d4c2f9b2fe7ce7d221c586bc056aaf60", ms, manifest, keccak256(toUtf8Bytes(uri)), payload,
      h(moduleKeys.map(() => "address"), moduleKeys.map(k => modules[k])), h(discoveryKeys.map(() => "bytes32"), discoveryKeys.map(k => discovery[k])), revision]);
  assert.equal(p.calls[1].oldValueHash, manifestHash(a.current.manifestHash, a.current.manifestURI, a.current.payloadRoot, a.current.modules, a.current.discovery, a.current.revision));
  assert.equal(p.calls[1].newValueHash, manifestHash(a.update.manifestHash, a.update.manifestURI, a.payloadRoot, { ...a.current.modules, mintManager: c.fallbackManager }, a.update, a.current.revision + 1n));
  assert.equal(p.request.activation.current.modules.mintManager, c.primary, "retained before-state stays original");
  assert.equal(p.request.activation.current.modules.stateExportPublisher, ZeroAddress);
});

test("incident activation preserves pointer/recovery/manifest order and six full-width retained values", () => {
  const c = configuration(), a = activation(c), i = incident(), p = fallback.mintFallbackIncidentActivationCalls(c, a, i);
  const normal = fallback.mintFallbackActivationCalls(c, a);
  assert.deepEqual(p.calls[0], normal.calls[0]); assert.deepEqual(p.calls[2], normal.calls[1]);
  assertCall(p, 1, "recoverPreparedMint", "fallback", c.fallbackManager, [i.tokenId, i.operationId]);
  const s = i.state, scope = h(["bytes32", "uint256", "address", "address", "uint256", "bytes32"],
    [id("6529STREAM_MINT_FALLBACK_RECOVERY_SCOPE_V1"), c.chainId, c.core, c.fallbackManager, i.tokenId, i.operationId]);
  const retained = h(Array(6).fill("uint256"), [s.collectionId, s.serial, s.lastTokenId, s.nextSerial, s.mintedEver, s.supply]);
  const state = (exists, data, coordinator) => h(["bytes32", "bytes32", "bool", "bytes32", "bytes32", "address"], [id("6529STREAM_MINT_FALLBACK_RECOVERY_STATE_V1"), scope, exists, retained, data, coordinator]);
  assert.equal(p.calls[1].scopeHash, scope); assert.equal(p.calls[1].oldValueHash, state(true, s.tokenDataHash, s.coordinator));
  assert.equal(p.calls[1].newValueHash, state(false, keccak256("0x"), ZeroAddress));
  assert.equal(p.actor, c.governance); assert.equal(p.calls[1].value, 0n);
  for (const key of ["collectionId", "serial", "lastTokenId", "nextSerial", "mintedEver", "supply"]) {
    assert.notEqual(fallback.mintFallbackRecoveryTransition(c, i.tokenId, i.operationId, { ...s, [key]: s[key] + 1n }).newHash, p.calls[1].newValueHash);
  }
  assert.notEqual(fallback.mintFallbackRecoveryTransition(c, i.tokenId + 1n, i.operationId, s).scope, scope);
  assert.notEqual(fallback.mintFallbackRecoveryTransition({ ...c, fallbackManager: A(99) }, i.tokenId, i.operationId, s).scope, scope);
  // Executor is the actor, but is not an invented extra field in the recovery scope.
  assert.deepEqual(fallback.mintFallbackRecoveryTransition({ ...c, governance: A(98) }, i.tokenId, i.operationId, s), fallback.mintFallbackRecoveryTransition(c, i.tokenId, i.operationId, s));
});

test("activation rejects frozen/wrong primary, stale manifest bindings, bad widths and invalid metadata", () => {
  const c = configuration(), a = activation(c);
  for (const change of [{ target: c.fallbackManager }, { frozen: true }, { codeHash: id("stale") }, { revision: (1n << 64n) - 1n }]) {
    assert.throws(() => fallback.mintFallbackActivationCalls(c, { ...a, previousPointer: { ...a.previousPointer, ...change } }));
  }
  for (const key of ["mintManager", "mintLedger", "moduleRegistry", "streamAdminsOrGovernance"]) {
    assert.throws(() => fallback.mintFallbackActivationCalls(c, { ...a, current: { ...a.current, modules: { ...a.current.modules, [key]: A(90) } } }));
  }
  assert.throws(() => fallback.mintFallbackActivationCalls(c, { ...a, current: { ...a.current, revision: (1n << 64n) - 1n } }));
  for (const change of [{ manifestHash: ZeroHash }, { eventCatalogHash: ZeroHash }, { manifestURI: "" }, { manifestURI: "é".repeat(1025) }, { manifestURI: "\uDC00" }]) {
    assert.throws(() => fallback.mintFallbackActivationCalls(c, { ...a, update: { ...a.update, ...change } }));
  }
  assert.throws(() => fallback.mintFallbackRecoveryTransition(c, 0n, id("op"), incident().state));
  assert.throws(() => fallback.mintFallbackRecoveryTransition(c, 1n, ZeroHash, incident().state));
  assert.throws(() => fallback.normalizeMintFallbackRecoveryState({ ...incident().state, supply: 1n << 256n }));
});

test("immutable request reconstruction rejects escaped actor, target, class, hash and ordering mutations", async () => {
  const c = configuration(), a = activation(c), i = incident(), p = fallback.mintFallbackIncidentActivationCalls(c, a, i);
  const expected = structuredClone(p);
  await Promise.resolve(); c.governance = A(90); a.current.modules.mintLedger = A(91); a.update.manifestURI = "changed"; i.state.serial++;
  assert.deepEqual(p, expected); assert.deepEqual(fallback.normalizeMintFallbackPlan(structuredClone(p)), p);
  assert.equal(Object.isFrozen(p.request.incident.state), true); assert.equal(Object.isFrozen(p.request.activation.current.modules), true);
  for (const mutate of [x => { x.actor = A(90); }, x => { x.actionClass = 0n; }, x => { x.permissionless = true; }, x => { x.factsVerified = true; },
    x => { x.calls[1].scopeHash = x.calls[0].scopeHash; }, x => { x.calls[1].value = 1n; }, x => { x.targetCalls[1].to = A(90); },
    x => { x.data.reverse(); }, x => { x.calls.reverse(); }, x => { x.request.incident.state.supply++; }]) {
    const escaped = structuredClone(p); mutate(escaped); assert.throws(() => fallback.normalizeMintFallbackPlan(escaped));
  }
  assert.throws(() => fallback.prepareMintFallbackPlan(configuration(), { kind: "incident-activation", activation: activation(), incident: incident(), caller: A(8) }));
  assert.throws(() => fallback.prepareMintFallbackPlan(configuration(), { kind: "synthetic-import" }));
});

test("original governance batch hashes, publication and Executor action ID match independent ABI preimages", () => {
  const c = configuration(), p = fallback.mintFallbackIncidentActivationCalls(c, activation(c), incident());
  const window = { notBefore: (1n << 60n) + 100n, expiresAfter: (1n << 60n) + 604900n, reasonHash: id("reason"), reasonURI: "ipfs://incident", manifestHash: id("reviewed manifest") };
  const nonce = (1n << 200n) + 4n, batch = fallback.mintFallbackGovernanceBatch(p, nonce, window);
  const callType = ParamType.from(f.abis.executor.find(x => x.name === "executeGovernanceBatch").inputs[1]);
  const callsHash = h(["bytes32", callType], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", p.calls]);
  assert.equal(batch.callsHash, callsHash);
  const aggregate = (domain, key) => h(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, p.calls.map(x => x[key])]);
  assert.equal(batch.scopeHash, aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash"));
  assert.equal(batch.oldValueHash, aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash"));
  assert.equal(batch.newValueHash, aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash"));
  const originalIdentity = coder.encode(["tuple(uint8 actionClass,bytes32 callsHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint256 nonce,uint64 notBefore,uint64 expiresAfter,bytes32 reasonHash,bytes32 manifestHash)"],
    [{ actionClass: p.actionClass, callsHash, scopeHash: batch.scopeHash, oldValueHash: batch.oldValueHash, newValueHash: batch.newValueHash, nonce, ...window }]);
  assert.equal(batch.actionId, keccak256(concat([coder.encode(["bytes32", "uint256", "address"], ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", c.chainId, c.governance]), originalIdentity])));
  assert.equal(batch.publicationKey, keccak256(concat(p.calls.map(call => call.callDataHash))));
  assert.equal(batch.publicationCall.data, interfaces.executor.encodeFunctionData("publishGovernanceCallData", [p.data]));
  assert.equal(batch.scheduleCall.data, interfaces.executor.encodeFunctionData("scheduleGovernanceBatch", [p.actionClass, p.calls, batch.scopeHash, batch.oldValueHash, batch.newValueHash, window.notBefore, window.expiresAfter, window.reasonHash, window.reasonURI, window.manifestHash]));
  assert.equal(batch.executionCall.data, interfaces.executor.encodeFunctionData("executeGovernanceBatch", [batch.actionId, p.calls, p.data]));
  for (const call of [batch.publicationCall, batch.scheduleCall, batch.executionCall]) { assert.equal(call.to, c.governance); assert.equal(call.value, 0n); }
  assert.equal(fallback.mintFallbackGovernanceBatch(p, nonce, { ...window, reasonURI: "other URI" }).actionId, batch.actionId, "URI is not invented into original ActionIdentity");
  assert.notEqual(fallback.mintFallbackGovernanceBatch(p, nonce + 1n, window).actionId, batch.actionId);
  assert.deepEqual(fallback.normalizeMintFallbackGovernanceBatch(structuredClone(batch)), batch);
  for (const field of ["actionId", "publicationKey", "scopeHash", "callsHash"]) {
    assert.throws(() => fallback.normalizeMintFallbackGovernanceBatch({ ...batch, [field]: id("forged") }));
  }
});

test("single-call classification also uses original aggregate batch scope without losing isolated policy", () => {
  const c = configuration(), p = fallback.mintFallbackRetirementClassificationCall(c, classifier(c));
  const window = { notBefore: 500n, expiresAfter: 900n, reasonHash: ZeroHash, reasonURI: "", manifestHash: ZeroHash };
  const batch = fallback.mintFallbackGovernanceBatch(p, 0n, window);
  assert.notEqual(batch.scopeHash, p.calls[0].scopeHash); assert.equal(batch.plan.isolated, true);
  assert.equal(batch.plan.calls.length, 1); assert.equal(batch.nonce, 0n);
  // Live timestamp, ordinary48h delay, open-window floor and catalog checks belong to simulation.
  assert.equal(batch.window.notBefore, 500n); assert.equal(batch.plan.factsVerified, false);
  for (const bad of [{ ...window, expiresAfter: 500n }, { ...window, notBefore: 1n << 64n }, { ...window, expiresAfter: 900 }, { ...window, reasonURI: "\uD800" }]) {
    assert.throws(() => fallback.mintFallbackGovernanceBatch(p, 0n, bad));
  }
  assert.throws(() => fallback.mintFallbackGovernanceBatch(p, 1n << 256n, window));
});
