import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroHash, concat, getAddress, id, keccak256 } from "ethers";
import { mintPhasePolicyHash, normalizeMintPolicySnapshot, prepareMintPolicyGraceChange, mintPolicyGraceGovernanceBatch } from "../dist/current-mint-policy-grace.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-mint-policy-grace-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, value]) => [key, new Interface(value)]));
const coder = AbiCoder.defaultAbiCoder(), addr = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const u64 = (1n << 64n) - 1n;
function input() {
  return {
    chainId: (1n << 230n) + 31337n, manager: addr(11), ledger: addr(12), moduleRegistry: addr(13),
    collectionId: (1n << 201n) + 29n, phaseId: id("original phase"),
    config: { paused: true, startTime: 7n, endTime: 0n, maxBatchQuantity: 10n, configHash: id("phase config"), metadataHash: id("phase metadata") },
    gate: { gate: addr(40), gateConfigHash: id("gate config"), gateCodehash: id("gate runtime"), gateMetadataHash: id("gate metadata"), gateSemanticVersion: 9n, gateGasLimit: 250000n },
    counterIds: [id("ordered counter zero"), id("ordered counter one")],
    counterConfigs: [
      { enabled: true, keyMode: 1n, capMode: 1n, deltaMode: 0n, staticCap: u64, staticIncrement: 3n, counterConfigHash: id("counter zero config") },
      { enabled: true, keyMode: 6n, capMode: 0n, deltaMode: 0n, staticCap: 0n, staticIncrement: 2n, counterConfigHash: id("counter one config") },
    ],
    executors: [addr(100), addr(20)],
  };
}
function originalPolicy(p) {
  const phase = keccak256(coder.encode(["bytes32", "uint64", "uint64", "uint32", "bytes32", "bytes32"],
    [id("6529STREAM_MINT_MANAGER_PHASE_CONFIG_V1"), p.config.startTime, p.config.endTime, p.config.maxBatchQuantity, p.config.configHash, p.config.metadataHash]));
  const g = p.gate;
  const gate = keccak256(coder.encode(["bytes32", "address", "bytes32", "bytes32", "bytes32", "uint32", "uint32"],
    [id("6529STREAM_MINT_MANAGER_GATE_CONFIG_V1"), g.gate, g.gateConfigHash, g.gateCodehash, g.gateMetadataHash, g.gateSemanticVersion, g.gateGasLimit]));
  const counterHashes = p.counterIds.map((counterId, i) => {
    const c = p.counterConfigs[i];
    return keccak256(coder.encode(["bytes32", "bytes32", "bool", "uint8", "uint8", "uint8", "uint64", "uint64", "bytes32"],
      [id("6529STREAM_MINT_MANAGER_COUNTER_CONFIG_V1"), counterId, c.enabled, c.keyMode, c.capMode, c.deltaMode, c.staticCap, c.staticIncrement, c.counterConfigHash]));
  });
  const ordered = keccak256(coder.encode(["bytes32[]"], [counterHashes]));
  const executors = [...p.executors].sort((a, b) => BigInt(a) < BigInt(b) ? -1 : BigInt(a) > BigInt(b) ? 1 : 0);
  const executorHash = keccak256(coder.encode(["bytes32", "address[]"], [id("6529STREAM_MINT_MANAGER_EXECUTOR_SET_V1"), executors]));
  const preimage = [p.chainId, p.manager, p.ledger, p.moduleRegistry, 1n, p.collectionId, p.phaseId, phase, gate, ordered, executorHash];
  return keccak256(coder.encode(["bytes32", "(uint256,address,address,address,uint16,uint256,bytes32,bytes32,bytes32,bytes32,bytes32)"],
    [id("6529STREAM_MINT_MANAGER_POLICY_V1"), preimage]));
}
function plan() {
  const p = input();
  return prepareMintPolicyGraceChange({ ...p, currentPolicyHash: originalPolicy(p) }, { executor: addr(30), allowed: true, graceUntil: 100n });
}

test("Mint grace fixture retains exact joined ABI52 source provenance", () => {
  assert.equal(fixture.sourceCommit, "44af244ed576cc4b26632b800fe70a068d577940");
  assert.equal(fixture.sourceCount, 2212);
  assert.equal(fixture.inputSha256, "94d4a931f6f2f1849e9d91506e6ac9c39d10982cc61d06c7fc2f4b35c17f0fde");
  assert.equal(fixture.outputSha256, "d299875f9ae1f03e1361dfba0795b908b4d0b45a480fe4e47deab5f78c173905");
  assert.equal(Object.keys(fixture.sourceHashes).length, 530);
  assert.equal(Object.keys(fixture.sourceTexts).length, 10);
  for (const [path, source] of Object.entries(fixture.sourceTexts)) {
    assert.equal(createHash("sha256").update(source).digest("hex"), fixture.sourceHashes[path]);
  }
  assert.match(fixture.qualification, /do not establish native/);
});

test("policy identity reproduces original nested struct and array preimages", () => {
  const source = fixture.sourceTexts["smart-contracts/domains/mint/StreamMintOperationIdentity.sol"];
  for (const domain of ["POLICY", "PHASE_CONFIG", "COUNTER_CONFIG", "GATE_CONFIG", "EXECUTOR_SET"]) {
    assert.ok(source.includes(`"6529STREAM_MINT_MANAGER_${domain}_V1"`));
  }
  const p = input();
  assert.equal(mintPhasePolicyHash(p), originalPolicy(p));
  const wide = { ...p, config: { ...p.config, startTime: u64 - 1n, endTime: u64, maxBatchQuantity: (1n << 32n) - 1n },
    gate: { ...p.gate, gateSemanticVersion: (1n << 32n) - 1n, gateGasLimit: (1n << 32n) - 1n } };
  assert.equal(mintPhasePolicyHash(wide), originalPolicy(wide));
  assert.throws(() => normalizeMintPolicySnapshot({ ...wide, currentPolicyHash: originalPolicy(wide) }), /batch|quantity|limit/i);
  assert.equal(mintPhasePolicyHash({ ...p, config: { ...p.config, paused: false } }), originalPolicy(p));
  assert.equal(mintPhasePolicyHash({ ...p, executors: [...p.executors].reverse() }), originalPolicy(p));
  const reordered = { ...p, counterIds: [...p.counterIds].reverse(), counterConfigs: [...p.counterConfigs].reverse() };
  assert.notEqual(originalPolicy(reordered), originalPolicy(p));
  assert.equal(mintPhasePolicyHash(reordered), originalPolicy(reordered));
  for (const field of ["manager", "ledger", "moduleRegistry"]) assert.notEqual(mintPhasePolicyHash({ ...p, [field]: addr(500) }), originalPolicy(p));
});

test("additive grace setter and original preview use the exact compiled tuples", () => {
  const p = plan(), s = p.snapshot;
  assert.equal(abi.graceInterface.getFunction("setPhaseExecutorWithGrace").selector, "0xdef72e30");
  assert.equal(abi.managerInterface.getFunction("setPhaseExecutorWithGrace"), null);
  assert.equal(abi.managerInterface.getFunction("setPhaseExecutor").format("sighash"), "setPhaseExecutor(uint256,bytes32,address,bool)");
  assert.equal(p.targetCall.value, 0n); assert.equal(p.targetCall.to, s.manager);
  assert.equal(p.targetCall.data, abi.manager.encodeFunctionData("setPhaseExecutorWithGrace",
    [s.collectionId, s.phaseId, p.request.executor, p.request.allowed, p.request.graceUntil]));
  assert.equal(p.previewCall.data, abi.manager.encodeFunctionData("previewPhasePolicyHash",
    [s.collectionId, s.phaseId, s.config, s.gate, s.counterIds, s.counterConfigs, p.prospectiveExecutors]));
  assert.equal(p.prospectivePolicyHash, originalPolicy({ ...input(), executors: [...input().executors, addr(30)] }));
  const alternate = prepareMintPolicyGraceChange(s, { ...p.request, graceUntil: 0n });
  assert.equal(alternate.prospectivePolicyHash, p.prospectivePolicyHash);
  assert.notEqual(alternate.targetCall.data, p.targetCall.data);
  assert.equal(p.actionClass, 1n); assert.equal(p.factsVerified, false);
});

test("one-call governance preserves original domains, scalar widths, publication and exact calldata", () => {
  const p = plan(), executor = addr(60), nonce = (1n << 201n) + 71n;
  const w = { notBefore: 500000n, expiresAfter: 1500000n, reasonHash: id("grace rationale"), reasonURI: "ipfs://review/é", manifestHash: id("actual manifest") };
  const b = mintPolicyGraceGovernanceBatch(p, executor, nonce, w);
  const call = { target: p.targetCall.to, value: 0n, selector: "0xdef72e30", callDataHash: keccak256(p.targetCall.data),
    scopeHash: keccak256(coder.encode(["address", "bytes"], [p.targetCall.to, p.targetCall.data])), oldValueHash: ZeroHash, newValueHash: keccak256(p.targetCall.data) };
  assert.deepEqual(p.governanceCall, call);
  const tuple = "(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
  const callsHash = keccak256(coder.encode(["bytes32", `${tuple}[]`], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", [call]]));
  const aggregate = (domain, value) => keccak256(coder.encode(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, [value]]));
  const scope = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", call.scopeHash);
  const oldValue = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", ZeroHash);
  const newValue = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", call.newValueHash);
  const originalId = keccak256(concat([
    coder.encode(["bytes32", "uint256", "address"], ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", p.snapshot.chainId, executor]),
    coder.encode(["(uint8,bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64,bytes32,bytes32)"], [[1n, callsHash, scope, oldValue, newValue, nonce, w.notBefore, w.expiresAfter, w.reasonHash, w.manifestHash]]),
  ]));
  assert.equal(b.actionId, originalId); assert.equal(b.callsHash, callsHash);
  assert.equal(b.publicationKey, keccak256(call.callDataHash));
  assert.deepEqual(b.publicationCall, { to: executor, value: 0n, data: abi.executor.encodeFunctionData("publishGovernanceCallData", [[p.targetCall.data]]) });
  assert.deepEqual(b.scheduleCall, { to: executor, value: 0n, data: abi.executor.encodeFunctionData("scheduleGovernanceBatch",
    [1n, [call], scope, oldValue, newValue, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash]) });
  assert.deepEqual(b.executionCall, { to: executor, value: 0n, data: abi.executor.encodeFunctionData("executeGovernanceBatch", [originalId, [call], [p.targetCall.data]]) });
});

test("receipt and readiness projections retain exact source emitter and admission boundaries", () => {
  assert.equal(abi.ledger.getFunction("policyGrace").outputs.length, 3);
  assert.equal(abi.manager.getFunction("phasePolicyGrace").outputs.length, 2);
  assert.deepEqual(abi.ledger.getEvent("MintLedgerPolicyGraceSet").inputs.map(row => row.type), ["uint16", "uint256", "bytes32", "address", "bytes32", "bytes32", "uint64"]);
  assert.equal(abi.manager.getEvent("MintPhaseConsentRecorded").inputs.at(-2).type, "uint8");
  const artist = fixture.sourceTexts["smart-contracts/domains/mint/StreamMintArtistConsent.sol"];
  assert.match(artist, /if \(mode != 1 && mode != 3\) revert UnsupportedArtistConsentMode/);
  assert.match(artist, /isCompletedMintDescendant/);
  const root = fixture.sourceTexts["script/current/StreamCurrentStackDeployment.sol"];
  assert.match(root, /_operatingPolicy\(address\(manager\), manager\.setPhaseExecutorWithGrace\.selector\)/);
  assert.match(root, /keccak256\(abi\.encode\(DEPLOYMENT_HASH, target\)\)/);
  const executor = fixture.sourceTexts["smart-contracts/domains/governance/StreamGovernanceExecutor.sol"];
  const schedule = executor.slice(executor.indexOf("function _schedule("), executor.indexOf("function _publishCallData("));
  assert.ok(schedule.indexOf("StreamGovernanceBootstrap.emitActionScheduled(") >= 0);
  assert.ok(schedule.indexOf("emit GovernanceActionPolicyValidated(") > schedule.indexOf("StreamGovernanceBootstrap.emitActionScheduled("));
  const execute = executor.slice(executor.indexOf("function _execute("), executor.indexOf("function _firstSelector("));
  assert.ok(execute.indexOf("emit GovernanceActionExecuted(") >= 0);
  assert.ok(execute.indexOf("emit GovernanceActionPolicyValidated(") > execute.indexOf("emit GovernanceActionExecuted("));
});
