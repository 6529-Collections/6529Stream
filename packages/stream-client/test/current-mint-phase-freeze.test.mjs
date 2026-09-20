import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as freeze from "../dist/current-mint-phase-freeze.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-mint-phase-freeze-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, rows]) => [key, new Interface(rows)]));
const coder = AbiCoder.defaultAbiCoder(), A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`), chainId = (1n << 240n) + 6529n;
const coords = { chainId, core: A(1), manager: A(2), ledger: A(3), governanceExecutor: A(4), collectionId: (1n << 253n) + 1n, phaseId: id("phase") };
const digest = (types, values) => keccak256(coder.encode(types, values));
function snapshot() { return { ...coords, currentPolicyHash: id("current policy"), record: { policyHash: ZeroHash, configurationHash: ZeroHash } }; }
function selectorState(c, config) {
  return digest(["bytes32", "uint256", "address", "bytes32", "address", "bytes4", "bool", "bytes32", "uint64"],
    [id("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"), c.chainId, c.governanceExecutor, id("6529STREAM_GOVERNANCE_CONFIG_FREEZE_SELECTOR"), c.manager,
      "0xaf55aad7", config.enabled, config.targetCodeHash, config.revision]);
}
function classifier(config = { enabled: false, targetCodeHash: ZeroHash, revision: (1n << 63n) + 1n }) {
  const c = { chainId, manager: coords.manager, governanceExecutor: coords.governanceExecutor, managerCodeHash: id("actual Manager runtime") };
  return { ...c, config: { ...config, stateHash: selectorState(c, config) } };
}
function configuration(configured = false) {
  const c = { chainId, core: coords.core, manager: coords.manager, ledger: coords.ledger, moduleRegistry: A(5), collectionId: coords.collectionId, phaseId: coords.phaseId,
    config: { paused: true, startTime: 1n, endTime: (1n << 64n) - 1n, maxBatchQuantity: 10n, configHash: id("raw phase terms"), metadataHash: id("metadata") },
    gate: { gate: A(6), gateConfigHash: id("gate config"), gateCodehash: id("gate code"), gateMetadataHash: id("gate metadata"), gateSemanticVersion: 7n, gateGasLimit: 99999n },
    counterIds: [id("counter B"), id("counter A")],
    counterConfigs: [
      { enabled: true, keyMode: 1n, capMode: 1n, deltaMode: 0n, staticCap: (1n << 64n) - 1n, staticIncrement: 1n, counterConfigHash: id("definition B") },
      { enabled: true, keyMode: 6n, capMode: 3n, deltaMode: 0n, staticCap: 33n, staticIncrement: 2n, counterConfigHash: id("definition A") }],
    defined: [false, true], definitions: [{ scope: 2n, keyMode: 0n, capRoot: ZeroHash, metadataHash: id("absent selection retained") },
      { scope: 0n, keyMode: 6n, capRoot: id("allowlist root"), metadataHash: id("definition metadata") }],
    royalty: { configured, applicationConfigHash: id("application"), resolver: A(7), resolverRuntimeHash: id("resolver runtime"),
      electionHash: id("election"), expectedModeAssignmentHash: id("mode assignment"), expectedSourceRoyaltyPolicyHash: id("source royalty") } };
  if (configured) c.config.configHash = royaltyWrapper(c);
  return c;
}
function royaltyWrapper(c) {
  const r = c.royalty;
  return digest(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "bytes32", "uint8", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_MINT_PHASE_ROYALTY_CONFIG_V1"), c.chainId, c.manager, c.collectionId, c.phaseId, r.applicationConfigHash,
      r.resolver, r.resolverRuntimeHash, 2n, r.electionHash, r.expectedModeAssignmentHash, r.expectedSourceRoyaltyPolicyHash]);
}
function originalConfigurationHash(c) {
  const config = { ...c.config, paused: false, configHash: c.royalty.configured ? c.royalty.applicationConfigHash : c.config.configHash };
  const phaseType = abi.manager.getFunction("phase").outputs[1], gateType = abi.manager.getFunction("phaseGate").outputs[0];
  const counterType = abi.manager.getFunction("counterConfig").outputs[0], definitionType = abi.counterPolicyInterface.getFunction("counterDefinitionForManager").outputs[1];
  const royaltyType = abi.royaltyInterface.getFunction("phaseRoyaltyPolicy").outputs[0];
  const arrayType = type => { const full = type.format("full"); return `${full.slice(0, full.lastIndexOf(")") + 1)}[]`; };
  return digest(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", phaseType, gateType,
    "bytes32[]", arrayType(counterType), "bool[]", arrayType(definitionType), "bytes32", "bytes32", royaltyType],
  [id("6529STREAM_MINT_PHASE_FREEZE_CONFIGURATION_V1"), c.chainId, c.core, c.moduleRegistry, c.ledger, c.collectionId, c.phaseId, config,
    c.gate, c.counterIds, c.counterConfigs, c.defined, c.definitions,
    id(c.royalty.configured ? "6529STREAM_MINT_PHASE_FREEZE_ROYALTY_CONFIGURED_V1" : "6529STREAM_MINT_PHASE_FREEZE_ROYALTY_UNCONFIGURED_V1"), c.royalty.applicationConfigHash, c.royalty]);
}
const window = { notBefore: 1000000n, expiresAfter: 1000000n + 604800n, reasonHash: id("reason"), reasonURI: "ipfs://review", manifestHash: id("manifest") };

test("exact own capability IDs and frozen ABI methods are separate Manager and Ledger surfaces", () => {
  const manager = new Interface(freeze.CURRENT_MINT_PHASE_FREEZE_ABI), ledger = new Interface(freeze.CURRENT_MINT_LEDGER_PHASE_FREEZE_ABI);
  for (const [client, source] of [[manager, abi.freezeInterface], [ledger, abi.ledgerFreezeInterface]]) {
    let own = 0n;
    for (const f of source.fragments.filter(f => f.type === "function" && f.name !== "supportsInterface")) {
      assert.equal(client.getFunction(f.format("sighash")).selector, f.selector); own ^= BigInt(f.selector);
    }
    assert.equal(`0x${own.toString(16).padStart(8, "0")}`, source === abi.freezeInterface ? freeze.MINT_PHASE_FREEZE_INTERFACE_ID : freeze.MINT_LEDGER_PHASE_FREEZE_INTERFACE_ID);
  }
  assert.equal(manager.getFunction("freezePhase").selector, "0xaf55aad7");
  assert.notEqual(manager.getFunction("freezePhase").selector, ledger.getFunction("freezePhase").selector);
});

test("original class2 transition binds full coordinates and current policy, not inherited provenance", () => {
  const s = snapshot(), t = freeze.mintPhaseFreezeTransition(s), p = freeze.prepareMintPhaseFreeze(s);
  const scope = digest(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32"],
    [id("6529STREAM_MINT_PHASE_FREEZE_SCOPE_V1"), s.chainId, s.core, s.manager, s.ledger, s.collectionId, s.phaseId]);
  assert.deepEqual(t, { scopeHash: scope,
    oldValueHash: digest(["bytes32", "bytes32", "bool", "bytes32"], [id("6529STREAM_MINT_PHASE_FREEZE_STATE_V1"), scope, false, s.currentPolicyHash]),
    newValueHash: digest(["bytes32", "bytes32", "bool", "bytes32"], [id("6529STREAM_MINT_PHASE_FREEZE_STATE_V1"), scope, true, s.currentPolicyHash]) });
  assert.equal(p.actionClass, 2n); assert.equal(p.targetCall.to, coords.manager); assert.equal(p.targetCall.value, 0n);
  assert.equal(p.targetCall.data, abi.manager.encodeFunctionData("freezePhase", [coords.collectionId, coords.phaseId]));
  assert.equal(p.governanceCall.callDataHash, keccak256(p.targetCall.data)); assert.equal(p.governanceCall.scopeHash, t.scopeHash);
  assert.equal(p.governanceCall.oldValueHash, t.oldValueHash); assert.equal(p.factsVerified, false);
  for (const patch of [{ chainId: s.chainId + 1n }, { core: A(101) }, { manager: A(102) }, { ledger: A(103) }, { collectionId: s.collectionId + 1n }, { phaseId: id("other phase") }]) {
    assert.notEqual(freeze.mintPhaseFreezeTransition({ ...s, ...patch }).scopeHash, scope);
  }
  const changed = freeze.mintPhaseFreezeTransition({ ...s, currentPolicyHash: id("new live policy") });
  assert.equal(changed.scopeHash, scope); assert.notEqual(changed.oldValueHash, t.oldValueHash);
  assert.deepEqual(freeze.mintPhaseFreezeTransition({ ...s, record: { policyHash: id("first frozen policy"), configurationHash: id("constraints") } }), t);
});

test("unconfigured inherited phases remain representable but cannot be frozen again", () => {
  const s = { ...snapshot(), currentPolicyHash: ZeroHash, record: { policyHash: id("ancestor frozen policy"), configurationHash: id("inherited terms") } };
  assert.deepEqual(freeze.normalizeMintPhaseFreezeSnapshot(s), s);
  assert.throws(() => freeze.prepareMintPhaseFreeze(s), /already frozen/);
  assert.throws(() => freeze.mintPhaseFreezeTransition(s), /nonzero/);
  assert.throws(() => freeze.prepareMintPhaseFreeze({ ...s, record: { policyHash: ZeroHash, configurationHash: ZeroHash } }), /nonzero/);
  const configured = { ...s, currentPolicyHash: id("successor current") };
  assert.throws(() => freeze.prepareMintPhaseFreeze(configured), /already frozen/);
  assert.equal(freeze.normalizeMintPhaseFreezeSnapshot(configured).record.policyHash, s.record.policyHash);
});

test("classifier is an exact isolated class0 Executor self-call with actual runtime and revision+1", () => {
  const s = classifier(), p = freeze.prepareMintPhaseFreezeClassifier(s), next = { enabled: true, targetCodeHash: s.managerCodeHash, revision: s.config.revision + 1n };
  const scope = digest(["bytes32", "uint256", "address", "bytes32", "address", "bytes4"],
    [id("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"), chainId, coords.governanceExecutor, id("6529STREAM_GOVERNANCE_CONFIG_FREEZE_SELECTOR"), coords.manager, "0xaf55aad7"]);
  assert.equal(p.actionClass, 0n); assert.equal(p.targetCall.to, coords.governanceExecutor); assert.equal(p.targetCall.value, 0n);
  assert.equal(p.targetCall.data, abi.executor.encodeFunctionData("registerFreezeSelector", [coords.manager, "0xaf55aad7", true]));
  assert.deepEqual(p.transition, { scopeHash: scope, oldValueHash: s.config.stateHash, newValueHash: selectorState(s, next) });
  assert.equal(p.governanceCall.selector, abi.executor.getFunction("registerFreezeSelector").selector);
  assert.notEqual(freeze.prepareMintPhaseFreezeClassifier({ ...s, managerCodeHash: id("other runtime") }).transition.newValueHash, p.transition.newValueHash);
  assert.throws(() => freeze.prepareMintPhaseFreezeClassifier(classifier({ enabled: true, targetCodeHash: s.managerCodeHash, revision: 1n })), /enabled/);
  assert.throws(() => freeze.prepareMintPhaseFreezeClassifier(classifier({ enabled: false, targetCodeHash: ZeroHash, revision: (1n << 64n) - 1n })), /exhausted/);
  assert.throws(() => freeze.prepareMintPhaseFreezeClassifier({ ...s, config: { ...s.config, stateHash: id("unverified state") } }), /state hash/);
  assert.throws(() => freeze.prepareMintPhaseFreezeClassifier({ ...s, managerCodeHash: ZeroHash }), /nonzero/);
});

test("configuration hash matches full compiler tuples in both original royalty branches", () => {
  for (const configured of [false, true]) {
    const c = configuration(configured), before = structuredClone(c), hash = freeze.mintPhaseFreezeConfigurationHash(c);
    assert.equal(hash, originalConfigurationHash(c)); assert.deepEqual(c, before);
    assert.equal(freeze.normalizeMintPhaseFreezeConfigurationInput(c).config.paused, true);
    assert.equal(freeze.mintPhaseFreezeConfigurationHash({ ...c, config: { ...c.config, paused: false } }), hash);
  }
  const c = configuration(true);
  assert.equal(freeze.mintPhaseFreezeRoyaltyConfigHash(c), royaltyWrapper(c));
  assert.throws(() => freeze.mintPhaseFreezeConfigurationHash({ ...c, config: { ...c.config, configHash: c.royalty.applicationConfigHash } }), /Manager-bound wrapper/);
});

test("only verified Manager-domain wrapper is normalized across same-Ledger successors", () => {
  const first = configuration(true), successor = structuredClone(first); successor.manager = A(222);
  assert.throws(() => freeze.mintPhaseFreezeConfigurationHash(successor), /wrapper/);
  successor.config.configHash = royaltyWrapper(successor);
  assert.notEqual(successor.config.configHash, first.config.configHash);
  assert.equal(freeze.mintPhaseFreezeConfigurationHash(successor), freeze.mintPhaseFreezeConfigurationHash(first));
  const raw = configuration(false), otherManager = { ...raw, manager: A(223) };
  assert.equal(freeze.mintPhaseFreezeConfigurationHash(raw), freeze.mintPhaseFreezeConfigurationHash(otherManager));
  assert.notEqual(freeze.mintPhaseFreezeConfigurationHash({ ...raw, config: { ...raw.config, configHash: id("changed raw terms") } }), freeze.mintPhaseFreezeConfigurationHash(raw));
  const sameTermsDifferentBranch = { ...first, royalty: { ...first.royalty, configured: false }, config: { ...first.config, configHash: first.royalty.applicationConfigHash } };
  assert.notEqual(freeze.mintPhaseFreezeConfigurationHash(sameTermsDifferentBranch), freeze.mintPhaseFreezeConfigurationHash(first));
});

test("configuration preserves full ordered definitions, gate and unconfigured royalty values", () => {
  const c = configuration(false), baseline = freeze.mintPhaseFreezeConfigurationHash(c);
  for (const mutate of [x => { x.core = A(101); }, x => { x.moduleRegistry = A(102); }, x => { x.ledger = A(103); },
    x => { x.counterIds.reverse(); }, x => { x.counterConfigs.reverse(); }, x => { x.defined.reverse(); }, x => { x.definitions.reverse(); },
    x => { x.definitions[0].metadataHash = ZeroHash; }, x => { x.gate.gateCodehash = id("new code"); },
    x => { x.royalty.applicationConfigHash = ZeroHash; }, x => { x.royalty.resolver = ZeroAddress; }, x => { x.royalty.expectedSourceRoyaltyPolicyHash = ZeroHash; }]) {
    const changed = structuredClone(c); mutate(changed); assert.notEqual(freeze.mintPhaseFreezeConfigurationHash(changed), baseline);
  }
  const scalarOnly = { ...c, counterIds: [], counterConfigs: [], defined: [], definitions: [] };
  assert.doesNotThrow(() => freeze.mintPhaseFreezeConfigurationHash(scalarOnly));
  assert.equal("executors" in freeze.normalizeMintPhaseFreezeConfigurationInput(c), false);
});

test("definition and policy normalizers enforce exact widths, dense arrays and aligned full selections", () => {
  const c = configuration();
  for (const mutate of [x => { x.defined.pop(); }, x => { x.definitions.pop(); }, x => { x.defined[0] = 0; },
    x => { x.definitions[0].scope = 3n; }, x => { x.definitions[0].keyMode = 7n; }, x => { x.config.startTime = 1n << 64n; },
    x => { x.config.maxBatchQuantity = 1; }, x => { x.counterConfigs[0].staticCap = 1n << 64n; },
    x => { x.definitions = new Array(2); }, x => { x.counterIds.extra = true; }, x => { x.royalty.extra = undefined; },
    x => { x.definitions[0][Symbol("extra")] = true; }, x => { x.executors = []; }]) {
    const changed = structuredClone(c); mutate(changed); assert.throws(() => freeze.normalizeMintPhaseFreezeConfigurationInput(changed));
  }
  const seventeen = structuredClone(c); seventeen.counterIds = Array(17).fill(id("counter"));
  assert.throws(() => freeze.normalizeMintPhaseFreezeConfigurationInput(seventeen), /bounded/);
});

test("original batch uses per-call commitments and exact publication, schedule and execution calldata", () => {
  for (const plan of [freeze.prepareMintPhaseFreeze(snapshot()), freeze.prepareMintPhaseFreezeClassifier(classifier())]) {
    const b = freeze.mintPhaseFreezeGovernanceBatch(plan, (1n << 255n) + 9n, window), calls = [plan.governanceCall];
    const tuple = abi.executor.getFunction("scheduleGovernanceBatch").inputs[1];
    const callsHash = digest(["bytes32", tuple], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
    const aggregate = (domain, key) => digest(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, [plan.governanceCall[key]]]);
    assert.equal(b.callsHash, callsHash);
    assert.equal(b.scopeHash, aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash"));
    assert.equal(b.oldValueHash, aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash"));
    assert.equal(b.newValueHash, aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash"));
    assert.notEqual(b.scopeHash, plan.transition.scopeHash);
    assert.equal(b.publicationKey, keccak256(plan.governanceCall.callDataHash));
    assert.equal(b.actionId, digest(["bytes32", "uint256", "address", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64", "uint64", "bytes32", "bytes32"],
      ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", chainId, coords.governanceExecutor, plan.actionClass,
        b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash, b.nonce, window.notBefore, window.expiresAfter, window.reasonHash, window.manifestHash]));
    assert.equal(b.publicationCall.data, abi.executor.encodeFunctionData("publishGovernanceCallData", [[plan.targetCall.data]]));
    assert.equal(b.scheduleCall.data, abi.executor.encodeFunctionData("scheduleGovernanceBatch", [plan.actionClass, calls, b.scopeHash, b.oldValueHash, b.newValueHash,
      window.notBefore, window.expiresAfter, window.reasonHash, window.reasonURI, window.manifestHash]));
    assert.equal(b.executionCall.data, abi.executor.encodeFunctionData("executeGovernanceBatch", [b.actionId, calls, [plan.targetCall.data]]));
    assert.equal(b.executionCall.to, coords.governanceExecutor); assert.equal(b.executionCall.value, 0n);
  }
});

test("terminal scheduling keeps exact inclusive 72h/7d/365d boundaries and uint64 headroom", () => {
  const at = 100n, start = at + 259200n, w = { ...window, notBefore: start, expiresAfter: start + 604800n };
  assert.doesNotThrow(() => freeze.assertMintPhaseFreezeGovernanceWindow(2n, w, at));
  assert.throws(() => freeze.assertMintPhaseFreezeGovernanceWindow(2n, { ...w, notBefore: start - 1n }, at), /minimum/);
  assert.throws(() => freeze.assertMintPhaseFreezeGovernanceWindow(2n, { ...w, expiresAfter: w.expiresAfter - 1n }, at), /seven days/);
  assert.doesNotThrow(() => freeze.assertMintPhaseFreezeGovernanceWindow(2n, { ...w, expiresAfter: at + 31536000n }, at));
  assert.throws(() => freeze.assertMintPhaseFreezeGovernanceWindow(2n, { ...w, expiresAfter: at + 31536001n }, at), /365 days/);
  assert.throws(() => freeze.assertMintPhaseFreezeGovernanceWindow(2n, w, at + 1n), /minimum/);
  const lastAt = (1n << 64n) - 1n - 31536000n, lastWindow = { ...w, notBefore: lastAt + 259200n, expiresAfter: (1n << 64n) - 1n };
  assert.doesNotThrow(() => freeze.assertMintPhaseFreezeGovernanceWindow(2n, lastWindow, lastAt));
  assert.throws(() => freeze.assertMintPhaseFreezeGovernanceWindow(2n, lastWindow, lastAt + 1n), /headroom/);
});

test("class0 retains zero delay and no seven-day open floor; unsupported classes and lossy times reject", () => {
  const w = { ...window, notBefore: 100n, expiresAfter: 101n, reasonHash: ZeroHash, reasonURI: "", manifestHash: ZeroHash };
  assert.doesNotThrow(() => freeze.assertMintPhaseFreezeGovernanceWindow(0n, w, 100n));
  assert.throws(() => freeze.assertMintPhaseFreezeGovernanceWindow(0n, w, 101n), /minimum/);
  assert.throws(() => freeze.normalizeMintPhaseFreezeGovernanceWindow({ ...w, expiresAfter: 100n }, 0n), /follow/);
  for (const actionClass of [1n, 3n, 2]) assert.throws(() => freeze.normalizeMintPhaseFreezeGovernanceWindow(w, actionClass), /classes/);
  for (const patch of [{ notBefore: 1 }, { expiresAfter: 1n << 64n }, { reasonURI: "\udc00" }, { reasonURI: "\ud800" }, { signature: "0x" }]) {
    assert.throws(() => freeze.normalizeMintPhaseFreezeGovernanceWindow({ ...w, ...patch }, 0n));
  }
  const p = freeze.prepareMintPhaseFreezeClassifier(classifier()), first = freeze.mintPhaseFreezeGovernanceBatch(p, 0n, w);
  const second = freeze.mintPhaseFreezeGovernanceBatch(p, 0n, { ...w, reasonURI: "supplemental review URI" });
  assert.equal(first.actionId, second.actionId); assert.notEqual(first.scheduleCall.data, second.scheduleCall.data);
});

test("bounded import is permissionless Ledger calldata and carries no fabricated transition or completion", () => {
  const root = id("committed root");
  for (const count of [1n, 32n]) {
    const p = freeze.prepareMintPhaseFreezeImport(coords.ledger, A(50), root, count);
    assert.equal(p.call.data, abi.ledger.encodeFunctionData("importPhaseFreezes", [root, count]));
    assert.equal(p.call.to, coords.ledger); assert.equal(p.call.value, 0n); assert.equal(p.caller, A(50));
    assert.equal("actionId" in p, false); assert.equal("complete" in p, false); assert.equal(p.factsVerified, false);
    assert.deepEqual(freeze.normalizeMintPhaseFreezeImport(structuredClone(p)), p);
  }
  for (const count of [0n, 33n, -1n, 1]) assert.throws(() => freeze.prepareMintPhaseFreezeImport(coords.ledger, A(50), root, count));
  assert.throws(() => freeze.prepareMintPhaseFreezeImport(coords.ledger, A(50), ZeroHash, 1n));
  assert.throws(() => freeze.prepareMintPhaseFreezeImport(coords.ledger, ZeroAddress, root, 1n));
});

test("all snapshots and call plans are copied, frozen and reconstructed before asynchronous use", async () => {
  const s = snapshot(), c = configuration(true), normalized = freeze.normalizeMintPhaseFreezeConfigurationInput(c);
  const p = freeze.prepareMintPhaseFreeze(s), b = freeze.mintPhaseFreezeGovernanceBatch(p, 0n, window), expected = structuredClone(b);
  s.record.configurationHash = id("later freeze"); s.currentPolicyHash = id("later policy"); c.definitions[0].metadataHash = ZeroHash;
  c.counterIds.reverse(); c.royalty.applicationConfigHash = ZeroHash;
  await Promise.resolve(); assert.deepEqual(b, expected); assert.notEqual(normalized.definitions[0].metadataHash, ZeroHash);
  const frozen = value => { if (value && typeof value === "object") { assert.equal(Object.isFrozen(value), true); Object.values(value).forEach(frozen); } };
  frozen(b); frozen(normalized);
  assert.deepEqual(freeze.normalizeMintPhaseFreezeGovernanceBatch(structuredClone(b)), b);
  for (const patch of [{ actionClass: 0n }, { targetCall: { ...p.targetCall, value: 1n } }, { governanceCall: { ...p.governanceCall, scopeHash: ZeroHash } },
    { transition: { ...p.transition, extra: undefined } }, { factsVerified: true }, { kind: "unfreeze" }]) assert.throws(() => freeze.normalizeMintPhaseFreezePlan({ ...p, ...patch }));
  for (const patch of [{ actionId: ZeroHash }, { window: { ...b.window, notBefore: b.window.notBefore + 1n, expiresAfter: b.window.expiresAfter + 1n } },
    { executionCall: { ...b.executionCall, to: coords.manager } }, { extra: undefined }]) assert.throws(() => freeze.normalizeMintPhaseFreezeGovernanceBatch({ ...b, ...patch }));
  const imported = freeze.prepareMintPhaseFreezeImport(coords.ledger, A(50), id("root"), 2n);
  assert.throws(() => freeze.normalizeMintPhaseFreezeImport({ ...imported, call: { ...imported.call, value: 1n } }));
});
