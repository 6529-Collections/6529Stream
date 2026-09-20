import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import * as client from "../dist/current-entropy-policy-succession.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-entropy-policy-succession-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, entries]) => [key, new Interface(entries)]));
const coder = AbiCoder.defaultAbiCoder(), hash = (types, values) => keccak256(coder.encode(types, values));
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const child = (type, name) => type.components.find(p => p.name === name);
const tuple = components => ParamType.from(`tuple(${components.map(p => p.format("full")).join(",")})`);
const policyType = abi.continuity.getFunction("exportEntropyPolicy").outputs[0];
const recoveryType = abi.continuity.getFunction("exportEntropyRecovery").outputs[0];
const receiptType = abi.continuity.getFunction("entropyPolicyImport").outputs[0];
function zero(p) {
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(c => [c.name, zero(c)]));
  if (p.baseType === "array") return p.arrayLength === -1 ? [] : Array.from({ length: p.arrayLength }, () => zero(p.arrayChildren));
  if (p.type === "address") return ZeroAddress;
  if (p.type === "bool") return false;
  if (p.type.startsWith("uint")) return 0n;
  if (p.type === "string") return "";
  return p.type === "bytes" ? "0x" : `0x${"00".repeat(Number(p.type.slice(5)))}`;
}
function configuration() {
  return { chainId: (1n << 240n) + 99n, core: address(1), moduleRegistry: address(2), executor: address(3), roleRegistry: address(4), predecessor: address(5), predecessorCodeHash: id("predecessor runtime"), candidate: address(6), candidateCodeHash: id("candidate runtime"), manifest: address(7) };
}

test("succession provenance retains exact joined capture and separately qualified runtime evidence", () => {
  assert.equal(fixture.profile, "entropy-policy-succession-v1");
  assert.equal(fixture.sourceCommit, "7901f3b108a7acc44780e6b686157d1016059e52");
  assert.equal(fixture.sourceTree, "c97f5289867bf1ce1a37ece386831c4201af2af6");
  assert.equal(fixture.sourceCount, 2501);
  assert.equal(fixture.inputSha256, "a7ee3da0c12de531be1a61e54dd56bdf3def42881668b548611b9acf12d9d061");
  assert.equal(fixture.outputSha256, "819ad416493a988d7c9ae80107750689cad48f5a19b7a1f3c478af40324907c7");
  assert.equal(Object.keys(fixture.abis).length, 20);
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 928);
  assert.equal(Object.keys(fixture.sourceHashes).length, 185);
  assert.equal(Object.keys(fixture.sourceTexts).length, 51);
  for (const [path, source] of Object.entries(fixture.sourceTexts)) {
    assert.equal(createHash("sha256").update(source).digest("hex"), fixture.sourceHashes[path], path);
  }
  for (const name of ["ReentrancyGuard.sol", "StreamModuleBase.sol", "IStreamEntropyTerminalFacts.sol", "ERC721.sol", "IStreamInstantEntropyProvider.sol"]) {
    assert.ok(Object.keys(fixture.sourceHashes).some(path => path.endsWith(`/${name}`)), name);
  }
  assert.equal(fixture.separateRuntimeEvidence.sourceCommit, "18c42131be84070641d071005b94abfbd73d23cc");
  assert.match(fixture.separateRuntimeEvidence.qualification, /predates.*Museum/);
});

test("dependency traversal keeps each plain, named and aliased import across comments and strings", () => {
  const source = `
    // import "ignored-line.sol";
    import "./Plain.sol";
    import { A, B as Renamed } from "./Named.sol";
    /* import "ignored-block.sol"; */
    import './Aliased.sol' as Alias;
    import * as Namespace from "./Wildcard.sol";
    string constant COMMENT = "import \\\"ignored-string.sol\\\"; // still a string";
    import /* same statement */ { C } from './Last.sol';
  `;
  assert.deepEqual(solidityImports(source), ["./Plain.sol", "./Named.sol", "./Aliased.sol", "./Wildcard.sol", "./Last.sol"]);
  assert.throws(() => solidityImports('import "unterminated.sol"'));
  assert.throws(() => solidityImports('import { A } from "one.sol" "two.sol";'));
});

test("succession public tuple names and widths match the compiler, including flat read results", () => {
  const relay = abi.originRelay.getFunction("relayEntropyRequest").inputs[0];
  const pairs = {
    INVENTORY_HEADER: tuple(abi.continuity.getFunction("entropyPolicyInventory").outputs),
    POLICY_INPUT: child(policyType, "policy"), POLICY_RECORD: child(policyType, "record"),
    COLLECTION_RECOVERY: child(policyType, "recovery"), POLICY_EXPORT: policyType,
    RECOVERY_STEP: child(child(recoveryType, "policy"), "steps").arrayChildren,
    RECOVERY_POLICY: child(recoveryType, "policy"), RECOVERY_EXPORT: recoveryType,
    IMPORT_RECEIPT: receiptType, IMPORTED_POLICY: tuple(abi.continuity.getFunction("importedEntropyPolicy").outputs),
    ADMISSION: tuple(abi.originRelay.getFunction("entropyRelayAdmission").outputs),
    REQUEST_POLICY_SNAPSHOT: child(relay, "policy"), RELAY_INPUT: relay,
    RELAY_RESULT: abi.originRelay.getFunction("entropyRelayResult").outputs[0],
    POINTER: tuple(abi.core.getFunction("getSatellitePointer").outputs),
    REGISTRATION: abi.modules.getFunction("registerModule").inputs[0],
    MANIFEST_UPDATE: abi.systemManifest.getFunction("publishStreamSystemManifest").inputs[1],
    GOVERNANCE_CALL: abi.executor.getFunction("scheduleGovernanceBatch").inputs[1].arrayChildren,
    CATALOG_ROW: abi.executor.getFunction("extendGovernanceActionPolicy").inputs[3].arrayChildren,
  };
  const named = p => p.baseType === "tuple" ? p.components.map(c => [c.name, named(c)]) : p.baseType === "array" ? [p.arrayLength, named(p.arrayChildren)] : p.type;
  for (const [key, compiled] of Object.entries(pairs)) {
    const supplied = ParamType.from(client[`ENTROPY_POLICY_SUCCESSION_${key}_TUPLE`]);
    assert.equal(supplied.format("sighash"), compiled.format("sighash"), key);
    assert.deepEqual(named(supplied), named(compiled), key);
  }
});

test("fixed exports and full recovery arrays preserve original canonical byte lengths", () => {
  const p = { ...zero(policyType), collectionId: (1n << 250n) + 13n, policyOrigin: address(11), policyOriginCodeHash: id("origin") };
  const r = { ...zero(receiptType), count: (1n << 220n) + 5n, serial: (1n << 63n) + 9n };
  for (const [name, type, value, length] of [["PolicyExport", policyType, p, 1184], ["ImportReceipt", receiptType, r, 544]]) {
    const expected = coder.encode([type], [value]);
    assert.equal((expected.length - 2) / 2, length);
    assert.equal(client[`encodeEntropyPolicySuccession${name}`](value), expected);
    assert.deepEqual(client[`decodeEntropyPolicySuccession${name}`](expected), value);
    assert.throws(() => client[`decodeEntropyPolicySuccession${name}`](`${expected}00`));
  }
  const recovery = zero(recoveryType), stepType = child(child(recoveryType, "policy"), "steps").arrayChildren;
  recovery.policy.steps = Array.from({ length: 32 }, (_, i) => ({ ...zero(stepType), provider: address(i + 20), providerEpoch: BigInt(i + 1), providerConfigHash: id(`provider ${i}`) }));
  const bytes = coder.encode([recoveryType], [recovery]);
  assert.equal((bytes.length - 2) / 2, 5696);
  assert.equal(client.encodeEntropyPolicySuccessionRecoveryExport(recovery), bytes);
  assert.deepEqual(client.decodeEntropyPolicySuccessionRecoveryExport(bytes), recovery);
  assert.equal(client.entropyPolicySuccessionExportHash(p), keccak256(coder.encode([policyType], [p])));
  assert.equal(client.entropyPolicySuccessionRecoveryExportHash(recovery), keccak256(bytes));
});

test("inventory append order and immutable import identity retain distinct source and progress commitments", () => {
  const c = configuration(), ids = [71n, 3n, (1n << 210n) + 1n];
  let digest = id("6529STREAM_ENTROPY_POLICY_INVENTORY_IDS_INITIAL_V1");
  assert.deepEqual(client.entropyPolicySuccessionInventory([], 0n), { count: 0n, serial: 0n, idDigest: digest });
  ids.forEach((collectionId, index) => { digest = hash(["bytes32", "bytes32", "uint256", "uint256"], [id("6529STREAM_ENTROPY_POLICY_INVENTORY_IDS_APPEND_V1"), digest, BigInt(index), collectionId]); });
  assert.deepEqual(client.entropyPolicySuccessionInventory(ids, 17n), { count: 3n, serial: 17n, idDigest: digest });
  assert.notEqual(client.entropyPolicySuccessionInventory([3n, 71n, ids[2]], 17n).idDigest, digest);
  const receipt = { ...zero(receiptType), state: 1n, nonce: 1n, predecessor: c.predecessor, predecessorCodeHash: c.predecessorCodeHash, pointerRevision: 9n, count: 3n, serial: 17n, idDigest: digest, manifestHash: id("operator import manifest") };
  const expected = hash(["bytes32", "uint256", "address", "bytes32", "address", "uint64", "address", "bytes32", "uint64", "uint256", "uint64", "bytes32", "bytes32"], [id("6529STREAM_ENTROPY_POLICY_IMPORT_V1"), c.chainId, c.candidate, c.candidateCodeHash, c.core, receipt.nonce, receipt.predecessor, receipt.predecessorCodeHash, receipt.pointerRevision, receipt.count, receipt.serial, receipt.idDigest, receipt.manifestHash]);
  assert.equal(client.entropyPolicySuccessionImportHash(c, receipt), expected);
  assert.equal(client.entropyPolicySuccessionImportHash(c, { ...receipt, state: 3n, nextIndex: 3n, beginActionId: id("begin"), sealActionId: id("seal"), activationActionId: id("activation"), exportDigest: id("completed exports") }), expected);
  assert.notEqual(client.entropyPolicySuccessionImportHash({ ...c, candidateCodeHash: id("different candidate") }, receipt), expected);
  const first = hash(["bytes32", "bytes32"], [id("6529STREAM_ENTROPY_POLICY_IMPORT_EXPORTS_V1"), expected]);
  assert.equal(client.entropyPolicySuccessionInitialExportDigest(expected), first);
  const appended = hash(["bytes32", "bytes32", "uint256", "uint256", "bytes32", "bytes32"], [id("6529STREAM_ENTROPY_POLICY_IMPORT_EXPORT_APPEND_V1"), first, 0n, ids[0], id("policy export"), id("recovery export")]);
  assert.equal(client.entropyPolicySuccessionAppendExportDigest(first, 0n, ids[0], id("policy export"), id("recovery export")), appended);
});

test("explicit policy identity retains ultimate origin and excludes operational fee and import receipts", () => {
  const c = configuration(), p = zero(policyType);
  Object.assign(p, { collectionId: 77n, profile: 1n, policyOrigin: address(11), policyOriginCodeHash: id("ultimate runtime"), providerCodeHash: id("provider runtime"), providerConfigHash: id("provider config") });
  Object.assign(p.record, { configured: true, mode: 2n, securityClass: 1n, renderRequirement: 1n, providerEpoch: 9n });
  Object.assign(p.policy, { mode: 2n, securityClass: 1n, renderRequirement: 1n, provider: address(12), collectionSalt: id("salt"), publicRequests: true, timeoutBlocks: 45n });
  Object.assign(p.policy.reveal, { declared: true, requestMode: 1n, revealOwnerRole: id("ROLE_ENTROPY_REVEAL_OWNER"), requestSLOBlocks: 90n, revealFeePerTokenWei: 31n });
  const types = ["bytes32", "uint256", "address", "address", "uint256", "uint8", "uint8", "uint8", "address", "bytes32", "bytes32", "uint32", "bytes32", "bool", "uint64", "bool", "uint8", "bytes32", "uint64", "bytes32", "bytes32", "uint16"];
  const values = [id("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"), c.chainId, p.policyOrigin, c.core, p.collectionId, p.record.mode, p.record.securityClass, p.record.renderRequirement, p.policy.provider, p.providerCodeHash, p.providerConfigHash, p.record.providerEpoch, p.policy.collectionSalt, p.policy.publicRequests, p.policy.timeoutBlocks, p.policy.reveal.declared, p.policy.reveal.requestMode, p.policy.reveal.revealOwnerRole, p.policy.reveal.requestSLOBlocks, p.recovery.policyId, p.recovery.policyHash, p.recovery.maxFreshRecoveryAttempts];
  const expected = hash(types, values);
  assert.equal(client.entropyPolicySuccessionPolicyHash(c.chainId, c.core, p), expected);
  const changed = structuredClone(p); changed.policy.reveal.revealFeePerTokenWei += 1n; changed.record.lastActionId = id("later action"); changed.record.revision = 99n;
  assert.equal(client.entropyPolicySuccessionPolicyHash(c.chainId, c.core, changed), expected);
  assert.notEqual(client.entropyPolicySuccessionPolicyHash(c.chainId, c.core, { ...p, policyOrigin: c.candidate }), expected);
  assert.notEqual(client.entropyPolicySuccessionPolicyHash(c.chainId, c.core, { ...p, providerConfigHash: id("other config") }), expected);
});

test("legacy undeclared zero and declared provider/reveal domains remain separate from explicit policies", () => {
  const c = configuration(), p = zero(policyType);
  Object.assign(p, { collectionId: 81n, policyOrigin: address(14), policyOriginCodeHash: id("origin"), providerCodeHash: id("provider runtime"), providerConfigHash: id("provider config") });
  Object.assign(p.policy, { provider: address(15), collectionSalt: id("legacy salt"), publicRequests: true, timeoutBlocks: 7n });
  p.record.providerEpoch = 1n;
  assert.equal(client.entropyPolicySuccessionLegacySaltHash(c.chainId, c.core, p), ZeroHash);
  assert.equal(client.entropyPolicySuccessionPolicyHash(c.chainId, c.core, p), ZeroHash);
  Object.assign(p.policy.reveal, { declared: true, requestMode: 1n, revealOwnerRole: id("ROLE_ENTROPY_REVEAL_OWNER"), requestSLOBlocks: 8n, revealFeePerTokenWei: 0n });
  const salt = hash(["bytes32", "uint256", "address", "address", "uint256", "bytes32"], [id("6529STREAM_ENTROPY_COLLECTION_SALT_V1"), c.chainId, p.policyOrigin, c.core, p.collectionId, p.policy.collectionSalt]);
  assert.equal(client.entropyPolicySuccessionLegacySaltHash(c.chainId, c.core, p), salt);
  for (const epoch of [1n, 2n]) {
    p.record.providerEpoch = epoch;
    const provider = hash(["bytes32", "address", "bytes32", "uint32", "bytes32", "bytes32", "bool", "uint64"], [id("6529STREAM_ENTROPY_SINGLE_PROVIDER_POLICY_V1"), p.policy.provider, p.providerCodeHash, epoch, p.providerConfigHash, salt, p.policy.publicRequests, p.policy.timeoutBlocks]);
    const reveal = hash(["bytes32", "uint8", "bytes32", "uint64"], [id("6529STREAM_ENTROPY_DECLARED_REVEAL_POLICY_V1"), p.policy.reveal.requestMode, p.policy.reveal.revealOwnerRole, p.policy.reveal.requestSLOBlocks]);
    const marker = epoch === 1n ? "6529STREAM_ENTROPY_EPOCH1_NO_FRESH_RECOVERY_V1" : "6529STREAM_ENTROPY_PREMINT_EPOCHS_NO_FRESH_RECOVERY_V1";
    const expected = hash(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32"], [id("6529STREAM_ENTROPY_FINALITY_POLICY_V1"), c.chainId, p.policyOrigin, c.core, p.collectionId, id(marker), provider, reveal]);
    assert.equal(client.entropyPolicySuccessionPolicyHash(c.chainId, c.core, p), expected);
  }
});

const source = suffix => Object.entries(fixture.sourceTexts).find(([path]) => path.endsWith(`/${suffix}`))[1];
function sourceConstant(file, name) {
  const match = source(file).match(new RegExp(`\\b${name}\\s*=\\s*(0x[0-9a-f]{64})\\s*;`));
  assert.ok(match, `${file}:${name}`);
  return match[1];
}
const pointerType = tuple(abi.core.getFunction("getSatellitePointer").outputs);
const rowType = abi.executor.getFunction("extendGovernanceActionPolicy").inputs[3].arrayChildren;
const manifestOutputs = abi.systemManifest.getFunction("streamSystemManifest").outputs;
const moduleFields = manifestOutputs.slice(2, 13), discoveryFields = manifestOutputs.slice(13, 20);
function originalPointer(c) {
  return { ...zero(pointerType), target: c.predecessor, codeHash: c.predecessorCodeHash, moduleType: id("ENTROPY_COORDINATOR"), interfaceId: "0x979b977f", registry: c.moduleRegistry, registryStatus: 1n, moduleManifestHash: id("old module"), deploymentManifestHash: id("deployment"), revision: 17n };
}
function originalManifest(c) {
  const modules = Object.fromEntries(moduleFields.map((p, i) => [p.name, address(100 + i)]));
  Object.assign(modules, { entropyCoordinator: c.predecessor, moduleRegistry: c.moduleRegistry, streamAdminsOrGovernance: c.executor });
  return { manifestHash: id("old manifest"), manifestURI: "ipfs://old", payloadRoot: address(90), modules, discovery: Object.fromEntries(discoveryFields.map(p => [p.name, id(p.name)])), revision: 7n };
}
function originalUpdate() {
  const type = abi.systemManifest.getFunction("publishStreamSystemManifest").inputs[1];
  return Object.fromEntries(type.components.map(p => [p.name, p.type === "string" ? "ipfs://new-π" : id(`new ${p.name}`)]));
}
function importState(scope, r) {
  return hash(["bytes32", "bytes32", "uint8", "uint64", "bytes32", "uint256", "bytes32", "uint256", "uint256"], [id("6529STREAM_ENTROPY_POLICY_IMPORT_STATE_V1"), scope, r.state, r.nonce, r.importHash, r.nextIndex, r.exportDigest, r.requiredRelayCount, r.confirmedRelayCount]);
}
function importScope(c, method) {
  return hash(["bytes32", "uint256", "address", "address", "bytes4"], [id("6529STREAM_ENTROPY_POLICY_IMPORT_SCOPE_V1"), c.chainId, c.candidate, c.core, abi.continuity.getFunction(method).selector]);
}
function manifestTransition(c, before, payload, update, cutover) {
  const scope = hash(["bytes32", "uint256", "address"], [sourceConstant("StreamSystemManifest.sol", "STREAM_SYSTEM_MANIFEST_SCOPE_V1"), c.chainId, c.manifest]);
  const state = (manifestHash, uri, pointer, modules, discovery, revision) => hash(["bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32", "uint64"], [sourceConstant("StreamSystemManifest.sol", "STREAM_SYSTEM_MANIFEST_STATE_V1"), scope, manifestHash, keccak256(toUtf8Bytes(uri)), pointer, hash(moduleFields, moduleFields.map(p => modules[p.name])), hash(discoveryFields, discoveryFields.map(p => discovery[p.name])), revision]);
  return { scope, oldHash: state(before.manifestHash, before.manifestURI, before.payloadRoot, before.modules, before.discovery, before.revision), newHash: state(update.manifestHash, update.manifestURI, payload, cutover ? { ...before.modules, entropyCoordinator: c.candidate } : before.modules, update, before.revision + 1n) };
}
function assertCall(actual, target, contract, method, args, transition) {
  const data = contract.encodeFunctionData(method, args);
  assert.deepEqual(actual, { target, value: 0n, selector: data.slice(0, 10), callDataHash: keccak256(data), scopeHash: transition.scope, oldValueHash: transition.oldHash, newValueHash: transition.newHash });
  return data;
}
test("begin and seal use original singleton class-1 transitions while progress is permissionless", () => {
  const c = configuration(), empty = client.entropyPolicySuccessionInventory([], 0n), pointer = originalPointer(c), receipt = zero(receiptType);
  const plan = client.prepareEntropyPolicySuccessionPlan(c, { kind: "begin", receipt, predecessorInventory: empty, candidateInventory: empty, pointer, manifestHash: id("empty import manifest") });
  const begun = client.entropyPolicySuccessionBeginReceipt(c, empty, pointer.revision, id("empty import manifest"));
  const scope = importScope(c, "beginEntropyPolicyImport");
  assert.equal(plan.actionClass, 1n); assert.equal(plan.calls.length, 1);
  assert.equal(plan.callDatas[0], assertCall(plan.calls[0], c.candidate, abi.continuity, "beginEntropyPolicyImport", [c.predecessor, begun.manifestHash], { scope, oldHash: importState(scope, receipt), newHash: importState(scope, begun) }));
  const seal = client.prepareEntropyPolicySuccessionPlan(c, { kind: "seal", receipt: { ...begun, beginActionId: id("begin action") }, predecessorInventory: empty, candidateInventory: empty });
  const sealScope = importScope(c, "sealEntropyPolicyImport");
  assert.equal(seal.actionClass, 1n);
  assertCall(seal.calls[0], c.candidate, abi.continuity, "sealEntropyPolicyImport", [], { scope: sealScope, oldHash: importState(sealScope, begun), newHash: importState(sealScope, { ...begun, state: 2n }) });
  for (const [request, method, value] of [[{ kind: "copy", expectedIndex: 3n }, "importNextEntropyPolicy", 3n], [{ kind: "confirm-route", collectionId: 77n }, "confirmEntropyRelayRoute", 77n]]) {
    const progress = client.prepareEntropyPolicySuccessionPlan(c, request);
    assert.equal(progress.actionClass, null); assert.deepEqual(progress.calls, []);
    assert.deepEqual(progress.targetCalls, [{ to: c.candidate, value: 0n, data: abi.continuity.encodeFunctionData(method, [value]) }]);
  }
});

test("atomic cutover reproduces exact pointer, activation and mandatory current-manifest commitments", () => {
  const c = configuration(), pointer = originalPointer(c), inventory = client.entropyPolicySuccessionInventory([], 0n);
  const receipt = { ...client.entropyPolicySuccessionBeginReceipt(c, inventory, pointer.revision, id("import")), state: 2n, beginActionId: id("begin"), sealActionId: id("seal") };
  const registration = { ...zero(abi.modules.getFunction("registerModule").inputs[0]), module: c.candidate, moduleType: id("ENTROPY_COORDINATOR"), moduleVersion: id("V1"), interfaceId: "0x979b977f", moduleGasLimit: 1000000n, expectedRuntimeCodeHash: c.candidateCodeHash, deploymentManifestHash: id("new deployment"), moduleManifestHash: id("new module"), moduleManifestURI: "ipfs://module" };
  const before = originalManifest(c), update = originalUpdate(), payload = address(91);
  const request = { kind: "cutover", receipt, predecessorInventory: inventory, candidateInventory: inventory, pointer, registration, registrationStatus: 1n, manifestState: before, payload, update };
  const plan = client.prepareEntropyPolicySuccessionPlan(c, request);
  assert.equal(plan.actionClass, 3n); assert.equal(plan.calls.length, 3);
  const scope = hash(["bytes32", "uint256", "address", "bytes32"], [sourceConstant("StreamCoreExternalReads.sol", "_STREAM_CORE_SATELLITE_POINTER_SCOPE_V1"), c.chainId, c.core, id("ENTROPY_COORDINATOR")]);
  const state = v => hash(["bytes32", "bytes32", pointerType], [sourceConstant("StreamCoreExternalReads.sol", "_STREAM_CORE_SATELLITE_POINTER_STATE_V1"), scope, v]);
  const next = { ...pointer, target: c.candidate, codeHash: c.candidateCodeHash, moduleManifestHash: registration.moduleManifestHash, deploymentManifestHash: registration.deploymentManifestHash, revision: pointer.revision + 1n };
  assertCall(plan.calls[0], c.core, abi.core, "updateSatellitePointer", [id("ENTROPY_COORDINATOR"), c.candidate], { scope, oldHash: state(pointer), newHash: state(next) });
  const activationScope = importScope(c, "activateEntropyPolicyImport");
  assertCall(plan.calls[1], c.candidate, abi.continuity, "activateEntropyPolicyImport", [], { scope: activationScope, oldHash: importState(activationScope, receipt), newHash: importState(activationScope, { ...receipt, state: 3n }) });
  assertCall(plan.calls[2], c.manifest, abi.systemManifest, "publishStreamSystemManifest", [payload, update], manifestTransition(c, before, payload, update, true));
  assert.deepEqual(plan.targetCalls.map(x => x.to), [c.core, c.candidate, c.manifest]);
  assert.throws(() => client.normalizeEntropyPolicySuccessionPlan({ ...plan, calls: plan.calls.slice(0, 2), callDatas: plan.callDatas.slice(0, 2), targetCalls: plan.targetCalls.slice(0, 2) }));
  assert.throws(() => client.normalizeEntropyPolicySuccessionPlan({ ...plan, calls: [...plan.calls].reverse() }));
  assert.equal(client.entropyPolicySuccessionImportReady(receipt, c.predecessor, c.predecessorCodeHash, pointer.revision, inventory), true);
  assert.equal(client.entropyPolicySuccessionImportReady({ ...receipt, state: 3n }, c.predecessor, c.predecessorCodeHash, pointer.revision, inventory), false);
});

const catalogKey = row => hash(["uint8", "address", "bytes4"], [row.actionClass, row.target, row.selector]);
function catalogRows(c, origins, deploymentHash) {
  return [[1n, c.candidate, c.candidateCodeHash, abi.continuity, "beginEntropyPolicyImport"], [1n, c.candidate, c.candidateCodeHash, abi.continuity, "sealEntropyPolicyImport"], [3n, c.candidate, c.candidateCodeHash, abi.continuity, "activateEntropyPolicyImport"], ...origins.map(o => [1n, o.target, o.codeHash, abi.originRelay, "admitEntropyRelay"])].map(([actionClass, target, targetCodeHash, contract, method]) => ({ actionClass, target, selector: contract.getFunction(method).selector, targetCodeHash, targetProfileHash: hash(["bytes32", "address"], [deploymentHash, target]), callType: 1n, valuePolicy: 0n, valueLimit: 0n, valueSemanticsHash: ZeroHash })).sort((a, b) => BigInt(catalogKey(a)) < BigInt(catalogKey(b)) ? -1 : 1);
}
function catalogExtension(c, previous, rows) {
  const state = { ...previous, revision: previous.revision + 1n, entryCount: previous.entryCount + BigInt(rows.length), catalogHash: hash(["bytes32", "uint256", "address", "bytes32", "uint64", "bytes32", "uint256", "bytes32"], [id("6529STREAM_GOVERNANCE_ACTION_POLICY_EXTENSION_V1"), c.chainId, c.executor, previous.candidateProfileHash, previous.revision + 1n, previous.catalogHash, previous.entryCount, hash([abi.executor.getFunction("extendGovernanceActionPolicy").inputs[3]], [rows])]) };
  const scope = hash(["bytes32", "uint256", "address"], [id("6529STREAM_GOVERNANCE_ACTION_POLICY_SCOPE_V1"), c.chainId, c.executor]);
  const commitment = s => hash(["bytes32", "bytes32", "bytes32", "uint64", "bytes32", "uint256"], [id("6529STREAM_GOVERNANCE_ACTION_POLICY_STATE_V1"), scope, s.candidateProfileHash, s.revision, s.catalogHash, s.entryCount]);
  return { state, transition: { scope, oldHash: commitment(previous), newHash: commitment(state) } };
}
test("canonical catalog inventory preserves complete history and exact 64-row extension plus manifest tail", () => {
  const c = configuration(), deploymentHash = id("succession deployment"), candidateProfileHash = id("foundation"), executorCodeHash = id("executor runtime");
  const origins = Array.from({ length: 65 }, (_, i) => ({ target: address(200 + i), codeHash: id(`origin runtime ${i}`) }));
  const rows = catalogRows(c, origins, deploymentHash);
  assert.deepEqual(client.entropyPolicySuccessionCatalogRows({ target: c.candidate, codeHash: c.candidateCodeHash }, origins, deploymentHash), rows);
  const initialRows = [{ ...rows[0], actionClass: 3n, target: c.core, selector: abi.core.getFunction("updateSatellitePointer").selector, targetCodeHash: id("core runtime"), targetProfileHash: id("core profile") }];
  const entryHash = hash(["bytes32", "uint64", rowType], [id("6529STREAM_GOVERNANCE_ACTION_POLICY_ENTRY_V1"), 0n, initialRows[0]]);
  const chainHash = hash(["bytes32", "bytes32", "bytes32", "uint64"], [id("6529STREAM_GOVERNANCE_ACTION_POLICY_CHAIN_V1"), ZeroHash, entryHash, 0n]);
  const baseCatalogHash = hash(["bytes32", "uint256", "address", "bytes32", "uint64", "bytes32"], [id("6529STREAM_GOVERNANCE_ACTION_POLICY_CATALOG_V1"), c.chainId, c.executor, candidateProfileHash, 1n, chainHash]);
  const baseHistory = { initialRows, extensions: [] }, base = { candidateProfileHash, catalogHash: baseCatalogHash, entryCount: 1n, revision: 0n };
  const inventory = client.entropyPolicySuccessionCatalogInventory(c, executorCodeHash, candidateProfileHash, baseHistory, origins, deploymentHash);
  assert.deepEqual(inventory, { chainId: c.chainId, executor: c.executor, executorCodeHash, candidateProfileHash, baseCatalogHash, baseEntryCount: 1n, baseRevision: 0n, additions: rows });
  const inventoryType = `tuple(uint256 chainId,address executor,bytes32 executorCodeHash,bytes32 candidateProfileHash,bytes32 baseCatalogHash,uint256 baseEntryCount,uint64 baseRevision,${rowType.format("full")}[] additions)`;
  assert.equal(client.entropyPolicySuccessionCatalogInventoryHash(inventory), hash([inventoryType], [inventory]));
  let current = base;
  for (const completedRows of [0n, 64n]) {
    const before = originalManifest(c), update = originalUpdate(), payload = address(92), stageRows = rows.slice(Number(completedRows), Number(completedRows) + 64);
    const expected = catalogExtension(c, current, stageRows);
    const plan = client.prepareEntropyPolicySuccessionPlan(c, { kind: "catalog", inventory, baseHistory, origins, deploymentHash, completedRows, catalogState: current, manifestState: before, payload, update });
    assert.equal(plan.actionClass, 3n); assert.equal(plan.calls.length, 2);
    assertCall(plan.calls[0], c.executor, abi.executor, "extendGovernanceActionPolicy", [current.revision, current.catalogHash, expected.state.catalogHash, stageRows], expected.transition);
    assertCall(plan.calls[1], c.manifest, abi.systemManifest, "publishStreamSystemManifest", [payload, update], manifestTransition(c, before, payload, update, false));
    assert.deepEqual(client.entropyPolicySuccessionCatalogExtension(c.chainId, c.executor, current, stageRows), expected);
    current = expected.state;
  }
  const history = client.entropyPolicySuccessionCatalogHistory(c.chainId, c.executor, candidateProfileHash, { initialRows, extensions: [rows.slice(0, 64), rows.slice(64)] });
  assert.deepEqual(history.state, current);
  const flattened = [...initialRows, ...rows].sort((a, b) => BigInt(catalogKey(a)) < BigInt(catalogKey(b)) ? -1 : 1);
  assert.notEqual(client.entropyPolicySuccessionCatalogHash(c.chainId, c.executor, candidateProfileHash, flattened), current.catalogHash);
});

test("governance identities and publication/schedule/execution use compiled ABI and original V2 domains", () => {
  const c = configuration(), empty = client.entropyPolicySuccessionInventory([], 0n);
  const plan = client.prepareEntropyPolicySuccessionPlan(c, { kind: "begin", receipt: zero(receiptType), predecessorInventory: empty, candidateInventory: empty, pointer: originalPointer(c), manifestHash: id("operator manifest") });
  const window = { notBefore: 400000n, expiresAfter: 1100000n, reasonHash: id("reason"), reasonURI: "ipfs://reason", manifestHash: id("governance manifest") }, nonce = (1n << 220n) + 1n;
  const batch = client.entropyPolicySuccessionGovernanceBatch(plan, nonce, window);
  const constant = name => sourceConstant("StreamGovernanceExecutor.sol", name);
  const callsHash = hash(["bytes32", abi.executor.getFunction("scheduleGovernanceBatch").inputs[1]], [constant("STREAM_GOVERNANCE_CALLS_V2"), plan.calls]);
  const aggregate = (name, field) => hash(["bytes32", "bytes32", "bytes32[]"], [constant(name), callsHash, plan.calls.map(c => c[field])]);
  const scopeHash = aggregate("STREAM_GOVERNANCE_BATCH_SCOPE_V2", "scopeHash"), oldHash = aggregate("STREAM_GOVERNANCE_BATCH_OLD_STATE_V2", "oldValueHash"), newHash = aggregate("STREAM_GOVERNANCE_BATCH_NEW_STATE_V2", "newValueHash");
  const actionId = hash(["bytes32", "uint256", "address", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64", "uint64", "bytes32", "bytes32"], [constant("STREAM_GOVERNANCE_ACTION_V2"), c.chainId, c.executor, 1n, callsHash, scopeHash, oldHash, newHash, nonce, window.notBefore, window.expiresAfter, window.reasonHash, window.manifestHash]);
  assert.equal(batch.callsHash, callsHash); assert.equal(batch.actionId, actionId);
  assert.equal(batch.publicationKey, keccak256(`0x${plan.callDatas.map(d => keccak256(d).slice(2)).join("")}`));
  for (const [key, method, args] of [["publicationCall", "publishGovernanceCallData", [plan.callDatas]], ["scheduleCall", "scheduleGovernanceBatch", [1n, plan.calls, scopeHash, oldHash, newHash, window.notBefore, window.expiresAfter, window.reasonHash, window.reasonURI, window.manifestHash]], ["executionCall", "executeGovernanceBatch", [actionId, plan.calls, plan.callDatas]]]) {
    assert.deepEqual(batch[key], { to: c.executor, value: 0n, data: abi.executor.encodeFunctionData(method, args) });
  }
  assert.throws(() => client.normalizeEntropyPolicySuccessionGovernanceBatch({ ...batch, executionCall: { ...batch.executionCall, value: 1n } }));
});

test("both pure and workflow ABI fragments retain exact compiled inputs, outputs and indexed topics", () => {
  const workflowSource = readFileSync(new URL("../src/current-entropy-policy-succession-workflow.ts", import.meta.url), "utf8");
  const literals = workflowSource.slice(workflowSource.indexOf("const abi = new Interface(["), workflowSource.indexOf("\n]);")).split(/\r?\n/).map(line => line.trim()).filter(line => line.startsWith('"')).map(line => JSON.parse(line.replace(/,$/, "")));
  assert.ok(literals.length > 50);
  for (const value of [client.CURRENT_ENTROPY_POLICY_SUCCESSION_ABI, literals]) {
    const supplied = new Interface(value);
    for (const fragment of supplied.fragments) {
      const original = Object.values(abi).flatMap(contract => contract.fragments).find(f => f.type === fragment.type && f.format("sighash") === fragment.format("sighash"));
      assert.ok(original, fragment.format("full"));
      assert.deepEqual(fragment.inputs.map(p => [p.format("sighash"), !!p.indexed]), original.inputs.map(p => [p.format("sighash"), !!p.indexed]), fragment.name);
      if (fragment.type === "function") assert.deepEqual(fragment.outputs.map(p => p.format("sighash")), original.outputs.map(p => p.format("sighash")), fragment.name);
    }
  }
});

test("multi-hop route admission stays at the ultimate origin and preserves original zero legacy policy identity", () => {
  const c = configuration(), p = zero(policyType), origin = { target: address(600), codeHash: id("ultimate origin") };
  Object.assign(p, { collectionId: 31n, policyOrigin: origin.target, policyOriginCodeHash: origin.codeHash, providerCodeHash: id("provider runtime"), providerConfigHash: id("provider config") });
  Object.assign(p.record, { configured: true, mode: 2n, renderRequirement: 1n, providerEpoch: 1n, contentStateHash: hash(["bytes32", "bytes32", "bool"], [id("6529STREAM_ENTROPY_CONFIGURATION_V1"), ZeroHash, false]) });
  Object.assign(p.policy, { mode: 2n, renderRequirement: 1n, provider: address(601), timeoutBlocks: 10n });
  const inventory = client.entropyPolicySuccessionInventory([p.collectionId], 1n);
  const receipt = { ...client.entropyPolicySuccessionBeginReceipt(c, inventory, 7n, id("import manifest")), beginActionId: id("begin action"), nextIndex: 1n, requiredRelayCount: 1n };
  const exportHash = keccak256(coder.encode([policyType], [p]));
  const importedPolicy = { importHash: receipt.importHash, exportHash, policyOrigin: origin.target, policyOriginCodeHash: origin.codeHash, policyHash: ZeroHash };
  const empty = { successorCodeHash: ZeroHash, importHash: ZeroHash, policyHash: ZeroHash };
  const request = { kind: "admit-route", origin, receipt, policy: p, recovery: null, importedPolicy, currentAdmission: empty, predecessorAdmission: { successorCodeHash: c.predecessorCodeHash, importHash: id("original import"), policyHash: ZeroHash } };
  const plan = client.prepareEntropyPolicySuccessionPlan(c, request);
  const scope = hash(["bytes32", "uint256", "address", "address", "uint256", "address", "bytes4"], [id("6529STREAM_ENTROPY_RELAY_ADMISSION_SCOPE_V1"), c.chainId, origin.target, c.core, p.collectionId, c.candidate, abi.originRelay.getFunction("admitEntropyRelay").selector]);
  const state = (pin, imported, policy, exported) => hash(Array(6).fill("bytes32"), [id("6529STREAM_ENTROPY_RELAY_ADMISSION_STATE_V1"), scope, pin, imported, policy, exported]);
  assert.equal(plan.actionClass, 1n); assert.equal(plan.calls.length, 1);
  assertCall(plan.calls[0], origin.target, abi.originRelay, "admitEntropyRelay", [p.collectionId, c.candidate, receipt.importHash], { scope, oldHash: state(ZeroHash, ZeroHash, ZeroHash, ZeroHash), newHash: state(c.candidateCodeHash, receipt.importHash, ZeroHash, exportHash) });
  assert.throws(() => client.prepareEntropyPolicySuccessionPlan(c, { ...request, predecessorAdmission: null }));
  assert.throws(() => client.prepareEntropyPolicySuccessionPlan(c, { ...request, currentAdmission: { successorCodeHash: c.candidateCodeHash, importHash: receipt.importHash, policyHash: ZeroHash } }));
});

test("recovery and relay hashes retain original domains, successor pins and full compiler tuples", () => {
  const c = configuration(), r = zero(recoveryType);
  Object.assign(r, { policyId: id("recovery"), policyOrigin: address(700), policyOriginCodeHash: id("recovery origin") });
  Object.assign(r.policy, { exists: true, frozen: true, maxFreshRecoveryAttempts: 1n, incidentDeclarerRole: id("ROLE_ENTROPY_INCIDENT_DECLARER"), reasonSchemaHash: id("reason schema"), policyManifestHash: id("recovery manifest"), steps: [{ provider: address(701), providerEpoch: 2n, providerConfigHash: id("config"), notBeforeBlocks: 9n, acceptLateOriginalFulfillment: false }] });
  const stepsHash = hash(["bytes32", child(child(recoveryType, "policy"), "steps")], [id("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), r.policy.steps]);
  const original = hash(["bytes32", "uint256", "address", "bytes32", "uint16", "bytes32", "bytes32", "bytes32", "bytes32"], [id("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"), c.chainId, r.policyOrigin, r.policyId, 1n, r.policy.incidentDeclarerRole, r.policy.reasonSchemaHash, r.policy.policyManifestHash, stepsHash]);
  assert.equal(client.entropyPolicySuccessionRecoveryHash(c.chainId, c.core, r), original);
  r.successor = c.predecessor; r.successorCodeHash = c.predecessorCodeHash;
  assert.equal(client.entropyPolicySuccessionRecoveryHash(c.chainId, c.core, r), hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "address", "bytes32"], [id("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V2"), c.chainId, r.policyOrigin, c.core, r.policyId, original, c.predecessor, c.predecessorCodeHash]));
  const relayType = abi.originRelay.getFunction("relayEntropyRequest").inputs[0], v = zero(relayType);
  Object.assign(v, { importHash: id("import"), collectionId: (1n << 220n) + 3n, tokenId: (1n << 230n) + 5n, successorRequestKey: id("request") });
  Object.assign(v.policy, { provider: address(702), providerEpoch: 8n, providerConfigHash: id("provider config"), requestAttempt: 2n, inputsHash: id("inputs") });
  const origin = { target: r.policyOrigin, codeHash: r.policyOriginCodeHash }, successor = { target: c.candidate, codeHash: c.candidateCodeHash };
  for (const scopeId of [ZeroHash, id("scope")]) {
    v.scopeId = scopeId;
    const context = coder.encode(["uint16", "address", "uint256", "uint256", "bytes32", "uint32", "bytes32", "uint16", "bytes32"], [scopeId === ZeroHash ? 1n : 2n, c.core, v.collectionId, v.tokenId, scopeId, v.policy.providerEpoch, v.policy.providerConfigHash, v.policy.requestAttempt, v.policy.inputsHash]);
    assert.equal(client.entropyPolicySuccessionRelayContext(c.core, v), context);
    const relayId = hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint256", "bytes32", "bytes32"], [id("6529STREAM_ENTROPY_RELAY_V1"), c.chainId, origin.target, successor.target, successor.codeHash, v.importHash, v.collectionId, v.successorRequestKey, keccak256(context)]);
    assert.equal(client.entropyPolicySuccessionRelayId(c.chainId, c.core, origin.target, successor, v), relayId);
    const witness = hash(["bytes32", "uint256", "address", "address", "bytes32", "address", "bytes32", relayType], [id("6529STREAM_ENTROPY_RELAY_WITNESS_V1"), c.chainId, c.core, successor.target, successor.codeHash, origin.target, origin.codeHash, v]);
    assert.equal(client.entropyPolicySuccessionRelayWitnessHash(c.chainId, c.core, origin, successor, v), witness);
  }
});

test("reviewable Safe CALL composition preserves compiled Executor and continuity transactions", () => {
  const c = configuration(), empty = client.entropyPolicySuccessionInventory([], 0n), safe = address(900);
  const begin = client.prepareEntropyPolicySuccessionPlan(c, { kind: "begin", receipt: zero(receiptType), predecessorInventory: empty, candidateInventory: empty, pointer: originalPointer(c), manifestHash: id("import") });
  const batch = client.entropyPolicySuccessionGovernanceBatch(begin, 3n, { notBefore: 400000n, expiresAfter: 1100000n, reasonHash: id("reason"), reasonURI: "ipfs://reason", manifestHash: id("manifest") });
  const copy = client.prepareEntropyPolicySuccessionPlan(c, { kind: "copy", expectedIndex: 19n });
  for (const [call, compiled] of [[batch.publicationCall, fixture.abis.executor], [batch.scheduleCall, fixture.abis.executor], [batch.executionCall, fixture.abis.executor], [copy.targetCalls[0], fixture.abis.continuity]]) {
    const plan = createSafeCallPlan(c.chainId, "Succession stage", [{ safe, intent: "Execute the reviewed original stage", call, abi: compiled }]);
    assert.deepEqual(verifySafeCallPlan(plan, [compiled]), plan);
    assert.deepEqual(plan.steps[0].transaction, { to: call.to, value: "0", data: call.data, operation: 0 });
    const changed = structuredClone(plan); changed.steps[0].transaction.data += "00";
    assert.throws(() => verifySafeCallPlan(changed, [compiled]));
  }
});
