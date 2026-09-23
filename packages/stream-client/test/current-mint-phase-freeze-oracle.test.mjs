import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as client from "../dist/current-mint-phase-freeze.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-mint-phase-freeze-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, value]) => [key, new Interface(value)]));
const coder = AbiCoder.defaultAbiCoder(), address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const hash = (types, values) => keccak256(coder.encode(types, values));
const phaseType = abi.manager.getFunction("phase").outputs[1];
const gateType = abi.manager.getFunction("phaseGate").outputs[0];
const counterType = abi.manager.getFunction("counterConfig").outputs[0];
const definitionType = abi.ledger.getFunction("counterDefinitionForManager").outputs[1];
const royaltyType = abi.manager.getFunction("phaseRoyaltyPolicy").outputs[0];
const governanceCallType = abi.executor.getFunction("scheduleGovernanceBatch").inputs[1];

function configuration(configured = false) {
  const p = {
    chainId: (1n << 230n) + 31337n, core: address(10), manager: address(11), ledger: address(12), moduleRegistry: address(13),
    collectionId: (1n << 201n) + 29n, phaseId: id("phase freeze oracle"),
    config: { paused: true, startTime: 7n, endTime: 0n, maxBatchQuantity: 10n, configHash: id("raw application"), metadataHash: id("phase metadata") },
    gate: { gate: address(40), gateConfigHash: id("gate config"), gateCodehash: id("gate runtime"), gateMetadataHash: id("gate metadata"), gateSemanticVersion: 9n, gateGasLimit: 250000n },
    counterIds: [id("ordered counter zero"), id("ordered counter one")],
    counterConfigs: [
      { enabled: true, keyMode: 1n, capMode: 1n, deltaMode: 0n, staticCap: (1n << 64n) - 1n, staticIncrement: 3n, counterConfigHash: id("counter zero") },
      { enabled: false, keyMode: 6n, capMode: 0n, deltaMode: 1n, staticCap: 0n, staticIncrement: 2n, counterConfigHash: id("counter one") },
    ],
    defined: [true, false],
    definitions: [
      { scope: 1n, keyMode: 1n, capRoot: id("definition cap"), metadataHash: id("definition metadata") },
      { scope: 2n, keyMode: 0n, capRoot: ZeroHash, metadataHash: ZeroHash },
    ],
    // Even inactive nonzero fields remain part of the original unconfigured branch.
    royalty: { configured, applicationConfigHash: id("royalty application"), resolver: address(70), resolverRuntimeHash: id("resolver runtime"),
      electionHash: id("election"), expectedModeAssignmentHash: id("assignment"), expectedSourceRoyaltyPolicyHash: id("source policy") },
  };
  if (configured) p.config.configHash = originalRoyaltyWrapper(p);
  return p;
}
function originalRoyaltyWrapper(p) {
  const r = p.royalty;
  return hash(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "bytes32", "uint8", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_MINT_PHASE_ROYALTY_CONFIG_V1"), p.chainId, p.manager, p.collectionId, p.phaseId, r.applicationConfigHash,
      r.resolver, r.resolverRuntimeHash, 2n, r.electionHash, r.expectedModeAssignmentHash, r.expectedSourceRoyaltyPolicyHash]);
}
function originalConfiguration(p) {
  const phase = { ...p.config, paused: false };
  if (p.royalty.configured) {
    assert.equal(phase.configHash, originalRoyaltyWrapper(p));
    phase.configHash = p.royalty.applicationConfigHash;
  }
  const branch = id(p.royalty.configured ? "6529STREAM_MINT_PHASE_FREEZE_ROYALTY_CONFIGURED_V1" : "6529STREAM_MINT_PHASE_FREEZE_ROYALTY_UNCONFIGURED_V1");
  return hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", phaseType, gateType,
    "bytes32[]", ParamType.from({ type: "tuple[]", components: counterType.components }), "bool[]",
    ParamType.from({ type: "tuple[]", components: definitionType.components }), "bytes32", "bytes32", royaltyType],
  [id("6529STREAM_MINT_PHASE_FREEZE_CONFIGURATION_V1"), p.chainId, p.core, p.moduleRegistry, p.ledger, p.collectionId, p.phaseId,
    phase, p.gate, p.counterIds, p.counterConfigs, p.defined, p.definitions, branch, p.royalty.applicationConfigHash, p.royalty]);
}
function snapshot() {
  const p = configuration();
  return { chainId: p.chainId, core: p.core, manager: p.manager, ledger: p.ledger, governanceExecutor: address(80),
    collectionId: p.collectionId, phaseId: p.phaseId, currentPolicyHash: id("exact current policy"), record: { policyHash: ZeroHash, configurationHash: ZeroHash } };
}
function selectorHash(s, config) {
  return hash(["bytes32", "uint256", "address", "bytes32", "address", "bytes4", "bool", "bytes32", "uint64"],
    [id("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"), s.chainId, s.governanceExecutor, id("6529STREAM_GOVERNANCE_CONFIG_FREEZE_SELECTOR"),
      s.manager, abi.manager.getFunction("freezePhase").selector, config.enabled, config.targetCodeHash, config.revision]);
}
function classifier() {
  const { chainId, manager, governanceExecutor } = snapshot();
  const s = { chainId, manager, governanceExecutor, managerCodeHash: id("actual manager runtime"), config: { enabled: false, targetCodeHash: ZeroHash, revision: 0n } };
  s.config.stateHash = selectorHash(s, s.config);
  return s;
}

test("Phase Freeze fixture retains exact ABI59 provenance and original source recipes", () => {
  assert.equal(fixture.sourceCommit, "0ab602042dbbb1f141aea0d9cbb37bd9617345cf");
  assert.equal(fixture.sourceCount, 2269);
  assert.equal(fixture.inputSha256, "52e81ac5b4b415a046d96364f344355b308cb36a2d4dc3b34abc0a78e49262e9");
  assert.equal(fixture.outputSha256, "e49d8e4542b21010193bafbb58dc309ac4e40238ffffe026275bb3f88a16e95b");
  assert.equal(Object.values(fixture.abis).flat().length, 179);
  assert.equal(Object.keys(fixture.sourceHashes).length, 147);
  assert.equal(Object.keys(fixture.sourceTexts).length, 14);
  for (const [path, source] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(source).digest("hex"), fixture.sourceHashes[path]);
  assert.match(fixture.qualification, /do not establish native/);
});

test("original separate Manager and Ledger companions retain selectors, events and interface identities", () => {
  const ownId = iface => `0x${iface.fragments.filter(row => row.type === "function" && row.name !== "supportsInterface")
    .reduce((sum, row) => sum ^ BigInt(row.selector), 0n).toString(16).padStart(8, "0")}`;
  assert.equal(ownId(abi.freezeInterface), client.MINT_PHASE_FREEZE_INTERFACE_ID);
  assert.equal(ownId(abi.ledgerFreezeInterface), client.MINT_LEDGER_PHASE_FREEZE_INTERFACE_ID);
  assert.equal(abi.manager.getFunction("freezePhase").selector, "0xaf55aad7");
  assert.equal(abi.ledger.getFunction("freezePhase").selector, "0x4cd37f0c");
  assert.equal(abi.ledger.getFunction("importPhaseFreezes").selector, "0x2ef5fe27");
  for (const [fragments, compiled] of [[client.CURRENT_MINT_PHASE_FREEZE_ABI, [abi.manager, abi.executor]], [client.CURRENT_MINT_LEDGER_PHASE_FREEZE_ABI, [abi.ledger]]]) {
    for (const fragment of new Interface(fragments).fragments) {
      const original = compiled.flatMap(i => i.fragments).find(row => row.type === fragment.type && row.format("sighash") === fragment.format("sighash"));
      assert.ok(original, fragment.format());
      assert.deepEqual(fragment.inputs.map(i => i.format("sighash")), original.inputs.map(i => i.format("sighash")));
      if (fragment.type === "event") assert.deepEqual(fragment.inputs.map(i => i.indexed === true), original.inputs.map(i => i.indexed === true));
      if (fragment.type === "function") {
        assert.equal(fragment.stateMutability, original.stateMutability);
        assert.deepEqual(fragment.outputs.map(i => i.format("sighash")), original.outputs.map(i => i.format("sighash")));
      }
    }
  }
});

test("Ledger configuration uses compiler-owned full tuples and original royalty branches", () => {
  for (const configured of [false, true]) {
    const p = configuration(configured);
    assert.equal(client.mintPhaseFreezeRoyaltyConfigHash(p), originalRoyaltyWrapper(p));
    assert.equal(client.mintPhaseFreezeConfigurationHash(p), originalConfiguration(p));
    const normalized = client.normalizeMintPhaseFreezeConfigurationInput(p);
    assert.equal(normalized.config.paused, true);
    assert.equal(normalized.config.configHash, p.config.configHash);
    assert.equal(client.mintPhaseFreezeConfigurationHash({ ...p, config: { ...p.config, paused: false } }), originalConfiguration(p));
    const successor = structuredClone(p); successor.manager = address(111);
    if (configured) successor.config.configHash = originalRoyaltyWrapper(successor);
    assert.equal(client.mintPhaseFreezeConfigurationHash(successor), originalConfiguration(p));
  }
  const p = configuration(true), wrong = structuredClone(p); wrong.manager = address(111);
  assert.throws(() => client.mintPhaseFreezeConfigurationHash(wrong), /wrapper/);
  const branch = structuredClone(p); branch.royalty.configured = false;
  assert.notEqual(client.mintPhaseFreezeConfigurationHash(branch), originalConfiguration(p));
});

test("every full configuration leaf remains committed except pause and the verified Manager wrapper", () => {
  const paths = [];
  function leaves(value, path = []) {
    if (value && typeof value === "object") for (const key of Object.keys(value)) leaves(value[key], [...path, key]);
    else paths.push(path);
  }
  leaves(configuration());
  for (const configured of [false, true]) {
    const p = configuration(configured), expected = originalConfiguration(p);
    for (const path of paths) {
      const key = path.join(".");
      if (["manager", "config.paused", "royalty.configured"].includes(key) || (configured && key === "config.configHash")) continue;
      const changed = structuredClone(p);
      const target = path.slice(0, -1).reduce((value, part) => value[part], changed), leaf = path.at(-1), value = target[leaf];
      target[leaf] = typeof value === "boolean" ? !value : typeof value === "bigint" ? value === 0n ? 1n : value - 1n
        : value.length === 42 ? address(BigInt(value) + 1n) : id(`mutated ${key}`);
      if (configured) changed.config.configHash = originalRoyaltyWrapper(changed);
      const actual = client.mintPhaseFreezeConfigurationHash(changed);
      assert.equal(actual, originalConfiguration(changed), key);
      assert.notEqual(actual, expected, key);
    }
  }
  const p = configuration(), reverse = structuredClone(p);
  for (const field of ["counterIds", "counterConfigs", "defined", "definitions"]) reverse[field].reverse();
  assert.notEqual(client.mintPhaseFreezeConfigurationHash(reverse), originalConfiguration(p));
});

test("freeze and classifier calls retain separate original per-call transition preimages", () => {
  const s = snapshot(), p = client.prepareMintPhaseFreeze(s);
  const scope = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32"],
    [id("6529STREAM_MINT_PHASE_FREEZE_SCOPE_V1"), s.chainId, s.core, s.manager, s.ledger, s.collectionId, s.phaseId]);
  const state = frozen => hash(["bytes32", "bytes32", "bool", "bytes32"], [id("6529STREAM_MINT_PHASE_FREEZE_STATE_V1"), scope, frozen, s.currentPolicyHash]);
  assert.deepEqual(p.transition, { scopeHash: scope, oldValueHash: state(false), newValueHash: state(true) });
  assert.deepEqual(p.targetCall, { to: s.manager, value: 0n, data: abi.manager.encodeFunctionData("freezePhase", [s.collectionId, s.phaseId]) });
  assert.equal(p.actionClass, 2n); assert.equal(p.factsVerified, false);
  const c = classifier(), registration = client.prepareMintPhaseFreezeClassifier(c);
  assert.notEqual(c.config.stateHash, ZeroHash);
  assert.equal(registration.actionClass, 0n);
  assert.deepEqual(registration.targetCall, { to: c.governanceExecutor, value: 0n,
    data: abi.executor.encodeFunctionData("registerFreezeSelector", [c.manager, "0xaf55aad7", true]) });
  assert.equal(registration.transition.scopeHash, hash(["bytes32", "uint256", "address", "bytes32", "address", "bytes4"],
    [id("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"), c.chainId, c.governanceExecutor, id("6529STREAM_GOVERNANCE_CONFIG_FREEZE_SELECTOR"), c.manager, "0xaf55aad7"]));
  assert.equal(registration.transition.oldValueHash, selectorHash(c, c.config));
  assert.equal(registration.transition.newValueHash, selectorHash(c, { enabled: true, targetCodeHash: c.managerCodeHash, revision: 1n }));
  assert.throws(() => client.prepareMintPhaseFreezeClassifier({ ...c, config: { ...c.config, stateHash: ZeroHash } }));
});

test("both one-call governance classes match original compiled calldata, aggregate commitments and IDs", () => {
  const plans = [client.prepareMintPhaseFreeze(snapshot()), client.prepareMintPhaseFreezeClassifier(classifier())];
  const nonce = (1n << 201n) + 81n, window = { notBefore: 500000n, expiresAfter: 1500000n,
    reasonHash: id("freeze reason"), reasonURI: "ipfs://review/é", manifestHash: id("manifest") };
  for (const p of plans) {
    const b = client.mintPhaseFreezeGovernanceBatch(p, nonce, window), call = p.governanceCall;
    const callsHash = hash(["bytes32", governanceCallType], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", [call]]);
    const aggregate = (domain, value) => hash(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, [value]]);
    const scope = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", call.scopeHash);
    const oldValue = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", call.oldValueHash);
    const newValue = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", call.newValueHash);
    const originalId = hash(["bytes32", "uint256", "address", "(uint8,bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64,bytes32,bytes32)"],
      ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", p.chainId, p.governanceExecutor,
        [p.actionClass, callsHash, scope, oldValue, newValue, nonce, window.notBefore, window.expiresAfter, window.reasonHash, window.manifestHash]]);
    assert.equal(b.actionId, originalId); assert.equal(b.callsHash, callsHash);
    assert.equal(b.publicationKey, keccak256(keccak256(p.targetCall.data)));
    assert.equal(b.publicationCall.data, abi.executor.encodeFunctionData("publishGovernanceCallData", [[p.targetCall.data]]));
    assert.equal(b.scheduleCall.data, abi.executor.encodeFunctionData("scheduleGovernanceBatch", [p.actionClass, [call], scope, oldValue, newValue,
      window.notBefore, window.expiresAfter, window.reasonHash, window.reasonURI, window.manifestHash]));
    assert.equal(b.executionCall.data, abi.executor.encodeFunctionData("executeGovernanceBatch", [originalId, [call], [p.targetCall.data]]));
  }
});

test("original window bounds and permissionless copy calls preserve exact widths and limits", () => {
  const now = 100n, minDelay = 72n * 3600n, open = 7n * 86400n, lifetime = 365n * 86400n;
  const window = { notBefore: now + minDelay, expiresAfter: now + minDelay + open, reasonHash: ZeroHash, reasonURI: "", manifestHash: ZeroHash };
  client.assertMintPhaseFreezeGovernanceWindow(2n, window, now);
  assert.throws(() => client.assertMintPhaseFreezeGovernanceWindow(2n, { ...window, notBefore: window.notBefore - 1n }, now), /delay/);
  assert.throws(() => client.assertMintPhaseFreezeGovernanceWindow(2n, { ...window, expiresAfter: window.expiresAfter - 1n }, now), /seven days/);
  client.assertMintPhaseFreezeGovernanceWindow(2n, { ...window, expiresAfter: now + lifetime }, now);
  assert.throws(() => client.assertMintPhaseFreezeGovernanceWindow(2n, { ...window, expiresAfter: now + lifetime + 1n }, now), /lifetime/);
  client.assertMintPhaseFreezeGovernanceWindow(0n, { ...window, notBefore: now, expiresAfter: now + 1n }, now);
  const timestamp = (1n << 64n) - 1n - lifetime + 1n;
  assert.throws(() => client.assertMintPhaseFreezeGovernanceWindow(0n, { ...window, notBefore: timestamp, expiresAfter: timestamp + 1n }, timestamp), /headroom/);
  for (const count of [1n, 32n]) {
    const plan = client.prepareMintPhaseFreezeImport(address(12), address(200), id("original root"), count);
    assert.deepEqual(plan.call, { to: address(12), value: 0n, data: abi.ledger.encodeFunctionData("importPhaseFreezes", [plan.importRoot, count]) });
    assert.equal(plan.caller, address(200)); assert.equal(plan.factsVerified, false);
  }
  for (const count of [0n, 33n, 1]) assert.throws(() => client.prepareMintPhaseFreezeImport(address(12), address(200), id("original root"), count));
});

test("source retains first-freeze provenance, legacy definitions and unconfigured same-Ledger inheritance", () => {
  const state = fixture.sourceTexts["smart-contracts/domains/mint/StreamMintPhaseFreezeState.sol"];
  assert.match(state, /count != 0 && predecessorLedger != address\(this\)/);
  assert.match(state, /counterDefinitionForManager\(manager, counters\[i\]\.counterConfigHash\)/);
  assert.match(state, /current\.policyHash = previous\.fact\.policyHash/);
  assert.match(state, /current\.configurationHash = previous\.fact\.configurationHash;\s+current\.executors = previous\.executors/);
  const create = state.indexOf("if (next.fact.configurationHash == 0)"), preserved = state.indexOf("current.policyHash = previous.fact.policyHash", create);
  assert.ok(preserved > create && preserved < state.indexOf("} else {", create));
  assert.match(state, /_requireSubset\(next, current\.executors/);
  const ledger = fixture.sourceTexts["smart-contracts/domains/mint/StreamMintLedger.sol"];
  assert.match(ledger, /\|\| _phaseFreezes\.imports\[root\]\.imported != _phaseFreezes\.imports\[root\]\.required/);
  assert.match(ledger, /c\.successorManager == address\(0\) \|\| c\.complete/);
  const control = fixture.sourceTexts["smart-contracts/domains/mint/StreamMintPhaseFreezeControl.sol"];
  assert.ok(control.indexOf("IStreamMintLedgerPhaseFreeze(ledger).freezePhase") < control.indexOf("emit MintPhaseFrozen(1"));
  assert.match(control, /!executing \|\| id == 0 \|\| cls != 2/);
  assert.match(control, /return record\.configurationHash != 0/);
});
