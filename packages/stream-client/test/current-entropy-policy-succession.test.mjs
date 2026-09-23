import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as s from "../dist/current-entropy-policy-succession.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-entropy-policy-succession-abi.json", import.meta.url), "utf8"));
const abis = Object.fromEntries(Object.entries(fixture.abis).map(([k, v]) => [k, new Interface(v)]));
const coder = AbiCoder.defaultAbiCoder(), a = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`), h = id;
const c = { chainId: (1n << 200n) + 10n, core: a(1), moduleRegistry: a(2), executor: a(3), roleRegistry: a(4), predecessor: a(5), predecessorCodeHash: h("predecessor"), candidate: a(6), candidateCodeHash: h("candidate"), manifest: a(7) };
const empty = s.entropyPolicySuccessionInventory([], 0n), source = s.entropyPolicySuccessionInventory([90n, 1n], 17n), copied = { ...source, serial: 2n };
function zero(p) { if (p.baseType === "tuple") return Object.fromEntries(p.components.map(x => [x.name, zero(x)])); if (p.baseType === "array") return []; if (p.type === "address") return ZeroAddress; if (p.type === "bool") return false; if (p.type.startsWith("uint")) return 0n; if (p.type === "string") return ""; return `0x${"00".repeat(Number(p.type.slice(5)))}`; }
const noImport = () => zero(abis.continuity.getFunction("entropyPolicyImport").outputs[0]);
const pointer = () => ({ target: c.predecessor, codeHash: c.predecessorCodeHash, frozen: false, moduleType: s.ENTROPY_POLICY_SUCCESSION_KIND, interfaceId: s.ENTROPY_POLICY_SUCCESSION_COORDINATOR_INTERFACE_ID, registry: c.moduleRegistry, registryStatus: 1n, moduleManifestHash: h("old module"), deploymentManifestHash: h("deployment"), revision: 9n });
const receipt = () => ({ ...s.entropyPolicySuccessionBeginReceipt(c, source, 9n, h("import manifest")), nextIndex: 2n, exportDigest: h("copied exports"), beginActionId: h("begin"), requiredRelayCount: 2n, confirmedRelayCount: 2n });
const discovery = () => Object.fromEntries(["eventCatalogHash", "compatibilityMatrixHash", "numericIdCatalogHash", "schemaCatalogHash", "canonicalizationCatalogHash", "specBundleHash", "reconstructionClientHash"].map(k => [k, h(k)]));
const manifest = () => ({ manifestHash: h("old manifest"), manifestURI: "ipfs://old/μ", payloadRoot: a(8), revision: 8n, modules: { revenueResolver: a(10), metadataRouter: a(11), collectionMetadata: a(12), entropyCoordinator: c.predecessor, mintManager: a(13), mintLedger: a(14), artistRegistry: a(15), streamAdminsOrGovernance: c.executor, artworkFinalityRegistry: a(16), moduleRegistry: c.moduleRegistry, stateExportPublisher: a(17) }, discovery: discovery() });
const update = () => ({ manifestHash: h("next manifest"), manifestURI: "ipfs://next", ...discovery() });
const registration = () => ({ module: c.candidate, moduleType: s.ENTROPY_POLICY_SUCCESSION_KIND, moduleVersion: h("version"), interfaceId: s.ENTROPY_POLICY_SUCCESSION_COORDINATOR_INTERFACE_ID, moduleGasLimit: 600000n, expectedRuntimeCodeHash: c.candidateCodeHash, deploymentManifestHash: h("deployment"), moduleManifestHash: h("module"), moduleManifestURI: "ipfs://module" });
const cutoverInput = () => ({ kind: "cutover", receipt: { ...receipt(), state: 2n, sealActionId: h("seal") }, predecessorInventory: source, candidateInventory: copied, pointer: pointer(), registration: registration(), registrationStatus: 1n, manifestState: manifest(), payload: a(19), update: update() });
function bindPolicy(p) { p.record.policyHash = s.entropyPolicySuccessionPolicyHash(c.chainId, c.core, p); p.record.contentStateHash = s.entropyPolicySuccessionContentStateHash(p.record.policyHash, p.record.frozen); return p; }
function policy(mode = 2n, profile = 1n) {
  const p = zero(abis.continuity.getFunction("exportEntropyPolicy").outputs[0]);
  Object.assign(p, { collectionId: 90n, profile, policyOrigin: c.predecessor, policyOriginCodeHash: c.predecessorCodeHash, providerCodeHash: h("provider"), providerConfigHash: h("provider config") });
  Object.assign(p.record, { configured: true, explicitPolicy: profile === 1n, mode, securityClass: mode === 1n ? 1n : 0n, renderRequirement: 1n, revision: profile === 1n ? 8n : 0n, providerEpoch: 4n, lastActionId: profile === 1n ? h("policy action") : ZeroHash, artistConsentRecord: profile === 1n ? h("consent") : ZeroHash });
  Object.assign(p.policy, { mode, securityClass: p.record.securityClass, renderRequirement: 1n, provider: a(20), collectionSalt: h("salt"), publicRequests: true, timeoutBlocks: mode === 2n ? 5n : 0n });
  if (mode === 2n) Object.assign(p.policy.reveal, { declared: true, requestMode: 1n, revealOwnerRole: h("ROLE_ENTROPY_REVEAL_OWNER"), requestSLOBlocks: 10n, revealFeePerTokenWei: (1n << 190n) + 4n });
  if (mode === 0n) { Object.assign(p.policy, { renderRequirement: 0n, provider: ZeroAddress, collectionSalt: ZeroHash, publicRequests: false }); p.record.renderRequirement = 0n; p.providerCodeHash = ZeroHash; p.providerConfigHash = ZeroHash; }
  return bindPolicy(p);
}
const sort = rows => rows.sort((x, y) => BigInt(s.entropyPolicySuccessionCatalogKey(x)) < BigInt(s.entropyPolicySuccessionCatalogKey(y)) ? -1 : 1);
const baseRow = () => ({ actionClass: 1n, target: a(100), selector: "0x12345678", targetCodeHash: h("old runtime"), targetProfileHash: h("old profile"), callType: 1n, valuePolicy: 0n, valueLimit: 0n, valueSemanticsHash: ZeroHash });
function catalogInput(n = 65) {
  const baseHistory = { initialRows: [baseRow()], extensions: [] }, origins = Array.from({ length: n }, (_, i) => ({ target: a(1000 + i), codeHash: h(`origin ${i}`) })), deploymentHash = h("deployment"), profile = h("candidate profile");
  const inventory = s.entropyPolicySuccessionCatalogInventory(c, h("executor runtime"), profile, baseHistory, origins, deploymentHash), state = s.entropyPolicySuccessionCatalogHistory(c.chainId, c.executor, profile, baseHistory).state;
  return { kind: "catalog", inventory, baseHistory, origins, deploymentHash, completedRows: 0n, catalogState: state, manifestState: manifest(), payload: a(19), update: update() };
}

test("original inventory is ordered, unique and full width; snapshots reject sparse and unknown input", () => {
  const ids = [90n, (1n << 255n) + 1n, 0n], inventory = s.entropyPolicySuccessionInventory(ids, 50n); ids.reverse();
  assert.notEqual(s.entropyPolicySuccessionInventory(ids, 50n).idDigest, inventory.idDigest);
  assert.throws(() => s.entropyPolicySuccessionInventory([1n, 1n], 2n)); assert.throws(() => s.entropyPolicySuccessionInventory([, 2n], 2n));
  assert.throws(() => s.entropyPolicySuccessionInventory([1n], 0n)); assert.throws(() => s.entropyPolicySuccessionInventory([], 1n << 64n));
  assert.throws(() => s.normalizeEntropyPolicySuccessionConfiguration({ ...c, authority: a(20) })); assert.throws(() => s.normalizeEntropyPolicySuccessionConfiguration({ ...c, chainId: 1 }));
  assert.equal(empty.idDigest, h("6529STREAM_ENTROPY_POLICY_INVENTORY_IDS_INITIAL_V1")); assert.ok(Object.isFrozen(inventory));
});

test("canonical ABI transport rejects suffixes, enum overflow and mutated nested observations", () => {
  const p = policy(), saved = s.normalizeEntropyPolicySuccessionPolicyExport(p), bytes = s.encodeEntropyPolicySuccessionPolicyExport(p); p.policy.reveal.revealFeePerTokenWei++;
  assert.notDeepEqual(p, saved); assert.ok(Object.isFrozen(saved.policy.reveal)); assert.deepEqual(s.decodeEntropyPolicySuccessionPolicyExport(bytes), saved);
  assert.throws(() => s.decodeEntropyPolicySuccessionPolicyExport(`${bytes}00`)); assert.throws(() => s.decodeEntropyPolicySuccessionPolicyExport(bytes.slice(0, -2)));
  assert.throws(() => s.normalizeEntropyPolicySuccessionPolicyExport({ ...saved, profile: 2n })); assert.throws(() => s.normalizeEntropyPolicySuccessionPolicyInput({ ...saved.policy, securityClass: 2n }));
  assert.throws(() => s.normalizeEntropyPolicySuccessionPolicyInput({ ...saved.policy, timeoutBlocks: 1n << 64n }));
});

test("explicit disabled and instant imports retain historical epochs and removed-recovery receipts", () => {
  for (const securityClass of [0n, 1n]) { const p = policy(0n); p.record.securityClass = securityClass; p.policy.securityClass = securityClass; p.record.providerEpoch = 91n; p.recovery.revision = 17n; p.recovery.lastActionId = h("removed"); bindPolicy(p); assert.deepEqual(s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, p), p); assert.equal(s.entropyPolicySuccessionRouteRequired(p), false); }
  const p = policy(1n); assert.deepEqual(s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, p), p); assert.equal(s.entropyPolicySuccessionRouteRequired(p), true);
  p.policy.renderRequirement = 0n; p.record.renderRequirement = 0n; bindPolicy(p); assert.equal(s.entropyPolicySuccessionRouteRequired(p), false); s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, p);
  p.policy.reveal.revealFeePerTokenWei = 1n; assert.throws(() => s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, p));
});

test("ASYNC NOT_REQUIRED still needs original reveal policy; fee and freeze never change semantic H", () => {
  const p = policy(); p.policy.renderRequirement = 0n; p.record.renderRequirement = 0n; bindPolicy(p); s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, p);
  assert.equal(s.entropyPolicySuccessionRouteRequired(p), true); const original = p.record.policyHash, changed = structuredClone(p);
  changed.policy.reveal.revealFeePerTokenWei++; changed.record.frozen = true; changed.record.revision++; changed.record.lastActionId = h("later"); changed.record.artistConsentRecord = h("new consent");
  assert.equal(s.entropyPolicySuccessionPolicyHash(c.chainId, c.core, changed), original); assert.notEqual(s.entropyPolicySuccessionExportHash(changed), s.entropyPolicySuccessionExportHash(p));
  assert.throws(() => s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, changed)); bindPolicy(changed); s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, changed);
  changed.policy.reveal.declared = false; assert.throws(() => s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, changed));
});

test("legacy undeclared H zero remains a valid committed profile, never an explicit replacement", () => {
  const p = policy(2n, 0n); p.policy.reveal = zero(abis.continuity.getFunction("exportEntropyPolicy").outputs[0].components.find(x => x.name === "policy").components.find(x => x.name === "reveal")); bindPolicy(p);
  assert.equal(p.record.policyHash, ZeroHash); assert.notEqual(p.record.contentStateHash, ZeroHash); s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, p);
  assert.throws(() => s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, { ...p, profile: 1n }));
  assert.throws(() => s.validateEntropyPolicySuccessionPolicy(c.chainId, c.core, { ...p, record: { ...p.record, contentStateHash: ZeroHash } }));
});

test("recovery validates all retained steps but orders only the consumed prefix", () => {
  const p = policy(), r = zero(abis.continuity.getFunction("exportEntropyRecovery").outputs[0]);
  Object.assign(r, { policyId: h("recovery"), revision: 1n, lastActionId: h("recovery action"), policyOrigin: p.policyOrigin, policyOriginCodeHash: p.policyOriginCodeHash });
  Object.assign(r.policy, { exists: true, frozen: true, maxFreshRecoveryAttempts: 2n, incidentDeclarerRole: h("ROLE_ENTROPY_INCIDENT_DECLARER"), reasonSchemaHash: h("reason"), policyManifestHash: h("manifest"), steps: [5n, 6n, 1n].map(epoch => ({ provider: a(20), providerEpoch: epoch, providerConfigHash: h("config"), notBeforeBlocks: 1n, acceptLateOriginalFulfillment: true })) });
  r.policyHash = s.entropyPolicySuccessionRecoveryHash(c.chainId, c.core, r); s.validateEntropyPolicySuccessionRecovery(c.chainId, c.core, r);
  p.policy.recoveryPolicyId = r.policyId; p.policy.maxFreshRecoveryAttempts = 2n; p.recovery = { policyId: r.policyId, policyHash: r.policyHash, maxFreshRecoveryAttempts: 2n, revision: 1n, lastActionId: h("binding") }; bindPolicy(p); s.verifyEntropyPolicySuccessionRecoveryBinding(p, r);
  const reversed = structuredClone(r); reversed.policy.steps[1].providerEpoch = 4n; reversed.policyHash = s.entropyPolicySuccessionRecoveryHash(c.chainId, c.core, reversed); s.validateEntropyPolicySuccessionRecovery(c.chainId, c.core, reversed); p.recovery.policyHash = reversed.policyHash; assert.throws(() => s.verifyEntropyPolicySuccessionRecoveryBinding(p, reversed));
  const invalid = structuredClone(r); invalid.policy.steps[2].notBeforeBlocks = 0n; assert.throws(() => s.validateEntropyPolicySuccessionRecovery(c.chainId, c.core, invalid));
  invalid.policy.steps = Array.from({ length: 33 }, () => r.policy.steps[0]); assert.throws(() => s.normalizeEntropyPolicySuccessionRecoveryExport(invalid));
});

test("import identity ignores progress and action receipts while transitions bind current progress", () => {
  const r = receipt(), changed = { ...r, nextIndex: 1n, exportDigest: h("other exports"), confirmedRelayCount: 1n, state: 3n, beginActionId: h("other begin") }, scope = h("scope");
  assert.equal(s.entropyPolicySuccessionImportHash(c, r), s.entropyPolicySuccessionImportHash(c, changed)); assert.notEqual(s.entropyPolicySuccessionImportStateHash(scope, r), s.entropyPolicySuccessionImportStateHash(scope, changed));
  assert.equal(s.entropyPolicySuccessionImportStateHash(scope, r), s.entropyPolicySuccessionImportStateHash(scope, { ...r, beginActionId: h("other"), activationActionId: h("another") }));
  assert.notEqual(s.entropyPolicySuccessionImportHash({ ...c, candidateCodeHash: h("changed code") }, r), r.importHash);
  assert.equal(s.entropyPolicySuccessionImportReady({ ...r, state: 2n }, c.predecessor, c.predecessorCodeHash, 9n, source), true);
  assert.equal(s.entropyPolicySuccessionImportReady({ ...r, state: 3n }, c.predecessor, c.predecessorCodeHash, 9n, source), false);
});

test("finite begin/seal and permissionless progress calls retain original methods and reconstructed plans", () => {
  const begin = s.prepareEntropyPolicySuccessionPlan(c, { kind: "begin", receipt: noImport(), predecessorInventory: source, candidateInventory: empty, pointer: pointer(), manifestHash: h("import") });
  assert.equal(begin.actionClass, 1n); assert.equal(begin.targetCalls[0].data, abis.continuity.encodeFunctionData("beginEntropyPolicyImport", [c.predecessor, h("import")]));
  const seal = s.prepareEntropyPolicySuccessionPlan(c, { kind: "seal", receipt: receipt(), predecessorInventory: source, candidateInventory: copied }); assert.equal(seal.targetCalls[0].data, abis.continuity.encodeFunctionData("sealEntropyPolicyImport"));
  assert.throws(() => s.prepareEntropyPolicySuccessionPlan(c, { ...seal.request, candidateInventory: { ...copied, idDigest: h("not same IDs") } }));
  for (const request of [{ kind: "copy", expectedIndex: 1n << 230n }, { kind: "confirm-route", collectionId: 1n << 220n }]) { const p = s.prepareEntropyPolicySuccessionPlan(c, request); assert.equal(p.actionClass, null); assert.equal(p.calls.length, 0); assert.equal(p.targetCalls[0].value, 0n); assert.deepEqual(s.normalizeEntropyPolicySuccessionPlan(p), p); assert.throws(() => s.entropyPolicySuccessionGovernanceBatch(p, 0n, { notBefore: 200000n, expiresAfter: 900000n, reasonHash: h("why"), reasonURI: "", manifestHash: h("manifest") })); }
  assert.throws(() => s.normalizeEntropyPolicySuccessionPlan({ ...seal, targetCalls: [begin.targetCalls[0]] }));
  assert.throws(() => s.prepareEntropyPolicySuccessionPlan(c, { kind: "relay-request", collectionId: 1n }));
});

test("route admission binds actual ultimate origin, exact copied export and predecessor route", () => {
  const p = policy(), r = receipt(), importedPolicy = { importHash: r.importHash, exportHash: s.entropyPolicySuccessionExportHash(p), policyOrigin: p.policyOrigin, policyOriginCodeHash: p.policyOriginCodeHash, policyHash: p.record.policyHash }, currentAdmission = { successorCodeHash: ZeroHash, importHash: ZeroHash, policyHash: ZeroHash };
  const request = { kind: "admit-route", origin: { target: p.policyOrigin, codeHash: p.policyOriginCodeHash }, receipt: r, policy: p, recovery: null, importedPolicy, currentAdmission, predecessorAdmission: null };
  const plan = s.prepareEntropyPolicySuccessionPlan(c, request); assert.equal(plan.targetCalls[0].to, c.predecessor); assert.equal(plan.targetCalls[0].data, abis.originRelay.encodeFunctionData("admitEntropyRelay", [p.collectionId, c.candidate, r.importHash]));
  assert.throws(() => s.prepareEntropyPolicySuccessionPlan(c, { ...request, importedPolicy: { ...importedPolicy, exportHash: h("wrong") } }));
  const descendant = structuredClone(request); descendant.policy.policyOrigin = a(300); descendant.policy.policyOriginCodeHash = h("ultimate"); bindPolicy(descendant.policy); descendant.origin = { target: a(300), codeHash: h("ultimate") }; Object.assign(descendant.importedPolicy, { policyOrigin: a(300), policyOriginCodeHash: h("ultimate"), policyHash: descendant.policy.record.policyHash, exportHash: s.entropyPolicySuccessionExportHash(descendant.policy) });
  assert.throws(() => s.prepareEntropyPolicySuccessionPlan(c, descendant)); descendant.predecessorAdmission = { successorCodeHash: c.predecessorCodeHash, importHash: h("prior import"), policyHash: descendant.policy.record.policyHash }; assert.equal(s.prepareEntropyPolicySuccessionPlan(c, descendant).targetCalls[0].to, a(300));
});

test("cutover is exactly pointer then activation then complete fresh manifest", () => {
  const input = cutoverInput(), plan = s.prepareEntropyPolicySuccessionPlan(c, input);
  assert.equal(plan.actionClass, 3n); assert.deepEqual(plan.targetCalls.map(x => x.to), [c.core, c.candidate, c.manifest]); assert.equal(plan.targetCalls[0].data, abis.core.encodeFunctionData("updateSatellitePointer", [s.ENTROPY_POLICY_SUCCESSION_KIND, c.candidate])); assert.equal(plan.targetCalls[2].data, abis.systemManifest.encodeFunctionData("publishStreamSystemManifest", [input.payload, input.update]));
  input.manifestState.modules.revenueResolver = a(999); input.update.manifestURI = "changed"; assert.notEqual(plan.request.manifestState.modules.revenueResolver, a(999)); assert.ok(Object.isFrozen(plan.request.manifestState.modules));
  for (const mutation of [{ registrationStatus: 3n }, { pointer: { ...pointer(), frozen: true } }, { predecessorInventory: { ...source, serial: source.serial + 1n } }, { receipt: { ...receipt(), state: 3n } }]) assert.throws(() => s.prepareEntropyPolicySuccessionPlan(c, { ...cutoverInput(), ...mutation }));
  assert.throws(() => s.normalizeEntropyPolicySuccessionPlan({ ...plan, calls: [...plan.calls].reverse() }));
});

test("original catalog history keeps extension groups and validates exact old rows", () => {
  const profile = h("profile"), initialRows = [baseRow()], extensions = [[{ ...baseRow(), target: a(101) }]], history = { initialRows, extensions }, result = s.entropyPolicySuccessionCatalogHistory(c.chainId, c.executor, profile, history);
  assert.equal(result.state.revision, 1n); assert.equal(result.state.entryCount, 2n); assert.notEqual(result.state.catalogHash, s.entropyPolicySuccessionCatalogHash(c.chainId, c.executor, profile, sort([...initialRows, ...extensions[0]])));
  initialRows[0].target = a(900); assert.equal(result.rows[0].target, a(100)); assert.ok(Object.isFrozen(result.history.extensions[0]));
  assert.throws(() => s.normalizeEntropyPolicySuccessionCatalogHistory({ initialRows: [baseRow()], extensions: [[baseRow()]] }));
  assert.throws(() => s.normalizeEntropyPolicySuccessionCatalogHistory({ initialRows: [baseRow(), { ...baseRow(), target: a(101) }].sort((x, y) => BigInt(s.entropyPolicySuccessionCatalogKey(x)) > BigInt(s.entropyPolicySuccessionCatalogKey(y)) ? -1 : 1), extensions: [] }));
  assert.throws(() => s.entropyPolicySuccessionCatalogHash(c.chainId, c.executor, profile, [{ ...baseRow(), valuePolicy: 1n, valueLimit: 1n }]));
});

test("canonical catalog stage uses 64 then remainder, unchanged modules and exact saved prefix", () => {
  const input = catalogInput(), first = s.prepareEntropyPolicySuccessionPlan(c, input), decoded = abis.executor.decodeFunctionData("extendGovernanceActionPolicy", first.targetCalls[0].data);
  assert.equal(decoded[3].length, 64); assert.equal(first.actionClass, 3n); assert.deepEqual(first.targetCalls.map(x => x.to), [c.executor, c.manifest]);
  const advanced = s.entropyPolicySuccessionCatalogExtension(c.chainId, c.executor, input.catalogState, input.inventory.additions.slice(0, 64)).state;
  const second = s.prepareEntropyPolicySuccessionPlan(c, { ...input, completedRows: 64n, catalogState: advanced }); assert.equal(abis.executor.decodeFunctionData("extendGovernanceActionPolicy", second.targetCalls[0].data)[3].length, 4);
  assert.throws(() => s.prepareEntropyPolicySuccessionPlan(c, { ...input, completedRows: 1n })); assert.throws(() => s.prepareEntropyPolicySuccessionPlan(c, { ...input, completedRows: 64n })); assert.throws(() => s.prepareEntropyPolicySuccessionPlan(c, { ...input, inventory: { ...input.inventory, additions: input.inventory.additions.slice(1) } }));
  assert.equal(first.request.manifestState.modules.entropyCoordinator, c.predecessor);
  assert.notEqual(first.calls[1].newValueHash, s.entropyPolicySuccessionManifestTransition(c, input.manifestState, input.payload, input.update).newHash);
});

test("catalog derivation removes only exact retained rows and rejects duplicate origins or capacity excess", () => {
  const input = catalogInput(1), exactRow = input.inventory.additions[0], baseHistory = { initialRows: sort([baseRow(), exactRow]), extensions: [] };
  const saved = s.entropyPolicySuccessionCatalogInventory(c, input.inventory.executorCodeHash, input.inventory.candidateProfileHash, baseHistory, input.origins, input.deploymentHash); assert.equal(saved.additions.length, 3);
  assert.throws(() => s.entropyPolicySuccessionCatalogInventory(c, input.inventory.executorCodeHash, input.inventory.candidateProfileHash, { initialRows: [{ ...exactRow, targetCodeHash: h("stale") }], extensions: [] }, input.origins, input.deploymentHash));
  assert.throws(() => s.entropyPolicySuccessionCatalogRows({ target: c.candidate, codeHash: c.candidateCodeHash }, [input.origins[0], input.origins[0]], input.deploymentHash));
  assert.throws(() => s.normalizeEntropyPolicySuccessionCatalogInventory({ ...saved, baseEntryCount: 1024n }));
  assert.equal(s.entropyPolicySuccessionCatalogInventoryHash(saved), keccak256(coder.encode([s.ENTROPY_POLICY_SUCCESSION_CATALOG_INVENTORY_TUPLE], [saved])));
});

test("governance reconstructs immutable class1/class3 calls, exact calldata publication and original timing", () => {
  const plan = s.prepareEntropyPolicySuccessionPlan(c, cutoverInput()), window = { notBefore: 172900n, expiresAfter: 172900n + 604800n, reasonHash: h("why"), reasonURI: "ipfs://reason", manifestHash: h("action manifest") }, batch = s.entropyPolicySuccessionGovernanceBatch(plan, 1n << 240n, window);
  assert.equal(batch.publicationKey, keccak256(`0x${plan.callDatas.map(d => keccak256(d).slice(2)).join("")}`)); assert.equal(batch.publicationCall.data, abis.executor.encodeFunctionData("publishGovernanceCallData", [plan.callDatas])); assert.equal(batch.executionCall.data, abis.executor.encodeFunctionData("executeGovernanceBatch", [batch.actionId, plan.calls, plan.callDatas]));
  assert.equal(batch.factsVerified, false); s.assertEntropyPolicySuccessionGovernanceWindow(window, 100n); assert.throws(() => s.assertEntropyPolicySuccessionGovernanceWindow(window, 101n));
  assert.throws(() => s.assertEntropyPolicySuccessionGovernanceWindow({ ...window, expiresAfter: window.notBefore + 604799n }, 100n)); assert.throws(() => s.assertEntropyPolicySuccessionGovernanceWindow({ ...window, expiresAfter: 31536101n }, 100n)); assert.throws(() => s.assertEntropyPolicySuccessionGovernanceWindow(window, (1n << 64n) - 31536000n));
  window.reasonURI = "changed"; assert.equal(batch.window.reasonURI, "ipfs://reason"); assert.deepEqual(s.normalizeEntropyPolicySuccessionGovernanceBatch(batch), batch); assert.throws(() => s.normalizeEntropyPolicySuccessionGovernanceBatch({ ...batch, actionId: h("fake") }));
});

test("relay identities preserve token versus scope input binding and raw-zero receipt truth", () => {
  const p = { provider: a(20), providerCodeHash: h("provider"), providerEpoch: 8n, providerConfigHash: h("config"), requestAttempt: 2n, inputsHash: h("inputs"), /* full original seventh word */ };
  const shape = zero(abis.originRelay.getFunction("relayEntropyRequest").inputs[0]); Object.assign(shape.policy, p); Object.assign(shape, { importHash: h("import"), collectionId: 90n, tokenId: 1n << 230n });
  const key = s.entropyPolicySuccessionRequestKey(c.chainId, c.core, c.candidate, shape), changed = structuredClone(shape); changed.policy.inputsHash = h("different"); assert.equal(s.entropyPolicySuccessionRequestKey(c.chainId, c.core, c.candidate, changed), key); assert.notEqual(s.entropyPolicySuccessionRelayContext(c.core, shape), s.entropyPolicySuccessionRelayContext(c.core, changed));
  shape.scopeId = h("scope"); changed.scopeId = shape.scopeId; assert.notEqual(s.entropyPolicySuccessionRequestKey(c.chainId, c.core, c.candidate, shape), s.entropyPolicySuccessionRequestKey(c.chainId, c.core, c.candidate, changed));
  const r = zero(abis.originRelay.getFunction("entropyRelayResult").outputs[0]); r.rawReceived = true; r.raw = ZeroHash; r.providerRequestId = 1n << 255n; assert.deepEqual(s.decodeEntropyPolicySuccessionRelayResult(s.encodeEntropyPolicySuccessionRelayResult(r)), r);
});
