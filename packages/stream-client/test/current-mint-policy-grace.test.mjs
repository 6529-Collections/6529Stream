import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, concat, getAddress, id, keccak256 } from 'ethers';
import { CURRENT_MINT_POLICY_GRACE_ABI, MINT_POLICY_GRACE_INTERFACE_ID, MINT_POLICY_GRACE_MAX_SECONDS,
  normalizeMintPhasePolicyInput, mintPhasePolicyHash, normalizeMintPolicySnapshot, normalizeMintPolicyGraceRequest,
  prepareMintPolicyGraceChange, normalizeMintPolicyGracePlan, assertMintPolicyGraceDeadline,
  mintPolicyGraceGovernanceBatch, normalizeMintPolicyGraceGovernanceBatch, normalizeMintPolicyGraceGovernanceWindow,
} from '../dist/current-mint-policy-grace.js';
import { currentArtistTypedData } from '../dist/current-artist.js';
import { mintTicketForBatch, mintTicketTypedData, mintTicketAuthorizationId, mintTicketGateData } from '../dist/current-mint-gates.js';

const coder = AbiCoder.defaultAbiCoder(), a = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, '0')}`);
const h = n => `0x${BigInt(n).toString(16).padStart(64, '0')}`;
const fixture = JSON.parse(readFileSync(new URL('./fixtures/current-mint-policy-grace-abi.json', import.meta.url), 'utf8'));
const manager = new Interface(fixture.abis.manager), executorAbi = new Interface(fixture.abis.executor);
const u64 = (1n << 64n) - 1n, u256 = (1n << 256n) - 1n;
const input = {
  chainId: (1n << 100n) + 17n, manager: a(101), ledger: a(102), moduleRegistry: a(103),
  collectionId: (1n << 120n) + 31n, phaseId: h(104),
  config: { paused: false, startTime: 0n, endTime: u64, maxBatchQuantity: 10n, configHash: h(105), metadataHash: ZeroHash },
  gate: { gate: a(106), gateConfigHash: h(107), gateCodehash: h(108), gateMetadataHash: h(109), gateSemanticVersion: 0n, gateGasLimit: 500_000n },
  counterIds: [h(202), h(201)],
  counterConfigs: [
    { enabled: true, keyMode: 3n, capMode: 1n, deltaMode: 0n, staticCap: u64, staticIncrement: 2n, counterConfigHash: h(203) },
    { enabled: true, keyMode: 6n, capMode: 0n, deltaMode: 0n, staticCap: 0n, staticIncrement: 1n, counterConfigHash: h(204) },
  ],
  executors: [a(302), a(301)],
};
const hash = (types, values) => keccak256(coder.encode(types, values));
function independentPolicy(p) {
  const c = p.config, g = p.gate;
  const phase = hash(['bytes32','uint64','uint64','uint32','bytes32','bytes32'],
    [id('6529STREAM_MINT_MANAGER_PHASE_CONFIG_V1'),c.startTime,c.endTime,c.maxBatchQuantity,c.configHash,c.metadataHash]);
  const gate = hash(['bytes32','address','bytes32','bytes32','bytes32','uint32','uint32'],
    [id('6529STREAM_MINT_MANAGER_GATE_CONFIG_V1'),g.gate,g.gateConfigHash,g.gateCodehash,g.gateMetadataHash,g.gateSemanticVersion,g.gateGasLimit]);
  const counters = p.counterConfigs.map((q, i) => hash(['bytes32','bytes32','bool','uint8','uint8','uint8','uint64','uint64','bytes32'],
    [id('6529STREAM_MINT_MANAGER_COUNTER_CONFIG_V1'),p.counterIds[i],q.enabled,q.keyMode,q.capMode,q.deltaMode,q.staticCap,q.staticIncrement,q.counterConfigHash]));
  const executors = [...p.executors].sort((x, y) => BigInt(x) < BigInt(y) ? -1 : BigInt(x) > BigInt(y) ? 1 : 0);
  // Flattening the wholly static original PolicyPreimage produces these exact ABI words.
  return hash(['bytes32','uint256','address','address','address','uint16','uint256','bytes32','bytes32','bytes32','bytes32','bytes32'],
    [id('6529STREAM_MINT_MANAGER_POLICY_V1'),p.chainId,p.manager,p.ledger,p.moduleRegistry,1,p.collectionId,p.phaseId,
      phase,gate,hash(['bytes32[]'],[counters]),hash(['bytes32','address[]'],[id('6529STREAM_MINT_MANAGER_EXECUTOR_SET_V1'),executors])]);
}
function snapshot(changes = {}) { const p = { ...structuredClone(input), ...changes }; return { ...p, currentPolicyHash: independentPolicy(p) }; }
const request = { executor: a(303), allowed: true, graceUntil: 2_000_000_000n };
const window = { notBefore: 2_000_000_000n, expiresAfter: 2_000_604_800n, reasonHash: h(410), reasonURI: 'urn:grace:reviewed', manifestHash: h(411) };

test('original policy preimage retains all fields and full-width coordinates independently of ABI tuple shorthand', () => {
  assert.equal(mintPhasePolicyHash(input), independentPolicy(input));
  for (const field of ['chainId','collectionId']) {
    const p = { ...input, [field]: u256 }; assert.equal(mintPhasePolicyHash(p), independentPolicy(p));
    assert.notEqual(mintPhasePolicyHash(p), mintPhasePolicyHash(input));
  }
  for (const field of ['manager','ledger','moduleRegistry']) assert.notEqual(mintPhasePolicyHash({ ...input, [field]: a(999) }), mintPhasePolicyHash(input));
  const changedCounter = structuredClone(input); changedCounter.counterConfigs[0].staticIncrement++;
  assert.notEqual(mintPhasePolicyHash(changedCounter), mintPhasePolicyHash(input));
  const changedGate = { ...input, gate: { ...input.gate, gateMetadataHash: h(999) } };
  assert.notEqual(mintPhasePolicyHash(changedGate), mintPhasePolicyHash(input));
});

test('only executor order is canonicalized while pause and grace never enter policy identity', () => {
  const expected = mintPhasePolicyHash(input);
  assert.equal(mintPhasePolicyHash({ ...input, executors: [...input.executors].reverse() }), expected);
  assert.equal(mintPhasePolicyHash({ ...input, config: { ...input.config, paused: true } }), expected);
  assert.notEqual(mintPhasePolicyHash({ ...input, counterIds: [...input.counterIds].reverse(), counterConfigs: [...input.counterConfigs].reverse() }), expected);
  const first = prepareMintPolicyGraceChange(snapshot(), request), second = prepareMintPolicyGraceChange(snapshot(), { ...request, graceUntil: 0n });
  assert.equal(first.prospectivePolicyHash, second.prospectivePolicyHash);
  assert.notEqual(first.targetCall.data, second.targetCall.data);
  for (const key of ['core','graceUntil','schemaVersion']) assert.throws(() => mintPhasePolicyHash({ ...input, [key]: 1n }), /unknown/);
});

test('preview normalization retains structurally encodable values that are not configured phase admission', () => {
  const p = { ...input, collectionId: 0n, phaseId: ZeroHash, config: { ...input.config, startTime: u64, endTime: 1n, maxBatchQuantity: 0n },
    counterIds: [], counterConfigs: [], executors: [ZeroAddress,a(1),a(1)] };
  assert.equal(mintPhasePolicyHash(p), independentPolicy(p));
  assert.deepEqual(normalizeMintPhasePolicyInput(p).executors, p.executors);
  assert.throws(() => normalizeMintPolicySnapshot({ ...p, currentPolicyHash: independentPolicy(p) }), /identity/);
  const duplicateCounters = { ...input, counterIds: [ZeroHash,ZeroHash], counterConfigs: [input.counterConfigs[0],input.counterConfigs[0]] };
  assert.equal(mintPhasePolicyHash(duplicateCounters), independentPolicy(duplicateCounters));
  const originalEnums = { ...input, counterConfigs: [{ ...input.counterConfigs[0], enabled: false, keyMode: 0n, capMode: 2n, deltaMode: 1n }, input.counterConfigs[1]] };
  mintPhasePolicyHash(originalEnums);
});

test('preview rejects lossy widths, invalid enums, unknown fields and malformed bounded arrays', () => {
  for (const value of [1,-1n,1n << 256n]) assert.throws(() => mintPhasePolicyHash({ ...input, chainId: value }));
  for (const value of [1,-1n,1n << 64n]) assert.throws(() => mintPhasePolicyHash({ ...input, config: { ...input.config, startTime: value } }));
  for (const changes of [{ maxBatchQuantity: 1n << 32n }, { paused: 0 }, { extra: 1 }]) assert.throws(() => mintPhasePolicyHash({ ...input, config: { ...input.config, ...changes } }));
  for (const changes of [{ keyMode: 7n }, { capMode: 4n }, { deltaMode: 2n }, { staticCap: 1n << 64n }]) assert.throws(() => mintPhasePolicyHash({ ...input, counterConfigs: [{ ...input.counterConfigs[0], ...changes }, input.counterConfigs[1]] }));
  for (const executors of [Array(1), Array(65).fill(a(1)), Object.assign([a(1)], { extra: 1 }), Object.assign([a(1)], { [Symbol('hidden')]: true })]) assert.throws(() => mintPhasePolicyHash({ ...input, executors }));
  assert.throws(() => mintPhasePolicyHash({ ...input, counterIds: [] }), /length/);
  assert.throws(() => mintPhasePolicyHash({ ...input, counterIds: Array(17).fill(h(1)), counterConfigs: Array(17).fill(input.counterConfigs[0]) }), /bounded/);
  assert.throws(() => mintPhasePolicyHash({ ...input, [Symbol('hidden')]: 1 }), /unknown/);
});

test('configured snapshots prove the supplied executor inventory against the full original current hash', () => {
  const normalized = normalizeMintPolicySnapshot(snapshot());
  assert.deepEqual(normalized.executors, [a(301),a(302)]);
  assert.deepEqual(normalized.counterIds, input.counterIds);
  assert.throws(() => normalizeMintPolicySnapshot({ ...snapshot(), executors: [a(301)] }), /complete policy/);
  assert.throws(() => normalizeMintPolicySnapshot({ ...snapshot(), currentPolicyHash: ZeroHash }), /nonzero/);
  for (const executors of [[a(301),a(301)], [ZeroAddress]]) assert.throws(() => normalizeMintPolicySnapshot(snapshot({ executors })), /nonzero and distinct/);
  normalizeMintPolicySnapshot(snapshot({ executors: [] }));
  normalizeMintPolicySnapshot(snapshot({ config: { ...input.config, configHash: ZeroHash, metadataHash: ZeroHash } }));
});

test('configured invariants preserve original static counters, gate absence and phase limit boundaries', () => {
  for (const config of [{ ...input.config, maxBatchQuantity: 0n }, { ...input.config, maxBatchQuantity: 11n }, { ...input.config, startTime: 10n, endTime: 9n }]) assert.throws(() => normalizeMintPolicySnapshot(snapshot({ config })), /phase limits/);
  normalizeMintPolicySnapshot(snapshot({ config: { ...input.config, startTime: 10n, endTime: 10n } }));
  normalizeMintPolicySnapshot(snapshot({ gate: { gate: ZeroAddress, gateConfigHash: ZeroHash, gateCodehash: ZeroHash, gateMetadataHash: ZeroHash, gateSemanticVersion: 0n, gateGasLimit: 0n } }));
  assert.throws(() => normalizeMintPolicySnapshot(snapshot({ gate: { ...input.gate, gate: ZeroAddress } })), /all-zero/);
  assert.throws(() => normalizeMintPolicySnapshot(snapshot({ gate: { ...input.gate, gateCodehash: ZeroHash } })), /runtime hashes/);
  for (const changes of [{ enabled: false }, { keyMode: 0n }, { capMode: 2n }, { deltaMode: 1n }, { staticIncrement: 0n }, { counterConfigHash: ZeroHash }, { capMode: 0n, staticCap: 1n }, { capMode: 3n, staticCap: 0n }]) {
    assert.throws(() => normalizeMintPolicySnapshot(snapshot({ counterConfigs: [{ ...input.counterConfigs[0], ...changes }, input.counterConfigs[1]] })), /configured counter/);
  }
  normalizeMintPolicySnapshot(snapshot({ counterConfigs: [{ ...input.counterConfigs[0], capMode: 3n }, input.counterConfigs[1]] })); // Live Merkle definition admission remains external.
  assert.throws(() => normalizeMintPolicySnapshot(snapshot({ counterIds: [], counterConfigs: [] })), /nonempty/);
  assert.throws(() => normalizeMintPolicySnapshot(snapshot({ counterIds: [h(1),h(1)] })), /distinct/);
});

test('prospective add and remove calls preserve exact compiled tuple order and one original class1 commitment', () => {
  const local = new Interface(CURRENT_MINT_POLICY_GRACE_ABI);
  assert.equal(local.getFunction('setPhaseExecutorWithGrace').selector, MINT_POLICY_GRACE_INTERFACE_ID);
  assert.equal(manager.getFunction('setPhaseExecutorWithGrace').selector, MINT_POLICY_GRACE_INTERFACE_ID);
  const plan = prepareMintPolicyGraceChange(snapshot(), request);
  assert.equal(plan.changed, true); assert.equal(plan.actionClass, 1n); assert.equal(plan.factsVerified, false);
  assert.deepEqual(plan.prospectiveExecutors, [a(301),a(302),a(303)]);
  assert.equal(plan.prospectivePolicyHash, independentPolicy({ ...input, executors: plan.prospectiveExecutors }));
  assert.deepEqual(plan.targetCall, { to: input.manager, value: 0n, data: manager.encodeFunctionData('setPhaseExecutorWithGrace', [input.collectionId,input.phaseId,request.executor,true,request.graceUntil]) });
  assert.equal(plan.previewCall.data, manager.encodeFunctionData('previewPhasePolicyHash', [input.collectionId,input.phaseId,input.config,input.gate,input.counterIds,input.counterConfigs,plan.prospectiveExecutors]));
  assert.deepEqual(plan.governanceCall, { target: input.manager, value: 0n, selector: '0xdef72e30', callDataHash: keccak256(plan.targetCall.data),
    scopeHash: hash(['address','bytes'],[input.manager,plan.targetCall.data]), oldValueHash: ZeroHash, newValueHash: keccak256(plan.targetCall.data) });
  const removed = prepareMintPolicyGraceChange(snapshot(), { executor: a(301), allowed: false, graceUntil: 0n });
  assert.deepEqual(removed.prospectiveExecutors, [a(302)]); assert.equal(removed.actionClass, 1n);
});

test('unchanged zero-grace calls remain valid no-ops while nonzero grace cannot extend a window', () => {
  for (const [executor, allowed] of [[a(301),true],[a(999),false]]) {
    const plan = prepareMintPolicyGraceChange(snapshot(), { executor, allowed, graceUntil: 0n });
    assert.equal(plan.changed, false); assert.equal(plan.prospectivePolicyHash, snapshot().currentPolicyHash);
    assert.throws(() => prepareMintPolicyGraceChange(snapshot(), { executor, allowed, graceUntil: 1n }), /Unchanged executor/);
  }
  const full = snapshot({ executors: Array.from({ length: 64 }, (_, i) => a(i + 1)) });
  assert.throws(() => prepareMintPolicyGraceChange(full, request), /limit/);
  prepareMintPolicyGraceChange(full, { executor: a(1), allowed: true, graceUntil: 0n });
  for (const changes of [{ executor: ZeroAddress }, { allowed: 1 }, { graceUntil: 1 }, { graceUntil: 1n << 64n }, { expectedPolicyHash: h(1) }]) assert.throws(() => prepareMintPolicyGraceChange(snapshot(), { ...request, ...changes }));
});

test('deadline checks use explicit execution time with inclusive upper boundary and no invented lower bound', () => {
  const at = 3_000_000_000n;
  for (const until of [0n,1n,at - 1n,at,at + MINT_POLICY_GRACE_MAX_SECONDS]) assertMintPolicyGraceDeadline(until, at);
  assert.throws(() => assertMintPolicyGraceDeadline(at + MINT_POLICY_GRACE_MAX_SECONDS + 1n, at), /30 days/);
  assertMintPolicyGraceDeadline(u64, u64); assertMintPolicyGraceDeadline(0n, u256);
  assert.throws(() => assertMintPolicyGraceDeadline(1n, u256), /30 days/);
  for (const until of [1,-1n,1n << 64n]) assert.throws(() => assertMintPolicyGraceDeadline(until, at));
  assert.throws(() => assertMintPolicyGraceDeadline(1n, 1));
  // No preparation-time guess is made by the pure planner.
  prepareMintPolicyGraceChange(snapshot(), { ...request, graceUntil: u64 });
});

test('returning to an executor set restores policy identity without rewriting original tickets or Artist signatures', () => {
  const before = snapshot(), added = prepareMintPolicyGraceChange(before, request);
  const after = { ...before, executors: added.prospectiveExecutors, currentPolicyHash: added.prospectivePolicyHash };
  const restored = prepareMintPolicyGraceChange(after, { executor: request.executor, allowed: false, graceUntil: 0n });
  assert.equal(restored.prospectivePolicyHash, before.currentPolicyHash);
  const batch = { collectionId: input.collectionId, phaseId: input.phaseId, payer: a(501), authorizer: a(502),
    initialRecipients: [a(501)], beneficiaries: [a(501)], tokenData: ['0x12'], mintCommitments: [h(503)],
    expectedPolicyHash: before.currentPolicyHash, authorizationId: h(504), contextHash: ZeroHash, resolverData: '0x' };
  const ticket = mintTicketForBatch({ chainId: input.chainId, manager: input.manager, ledger: input.ledger, executor: a(301), authorizerKind: 2n, nonce: h(505), deadline: u64 }, batch);
  const signed = mintTicketTypedData(input.chainId, input.gate.gate, ticket), bytes = mintTicketGateData(ticket, '0x1234');
  assert.equal(ticket.policyHash, before.currentPolicyHash);
  prepareMintPolicyGraceChange(before, request);
  assert.equal(mintTicketGateData(ticket, '0x1234'), bytes);
  assert.equal(mintTicketAuthorizationId(mintTicketTypedData(input.chainId, input.gate.gate, ticket).digest), mintTicketAuthorizationId(signed.digest));
  const consent = currentArtistTypedData('artistPolicyConsent', input.chainId, a(506), { core: a(507), mintManager: input.manager,
    collectionId: input.collectionId, phaseId: input.phaseId, policyHash: added.prospectivePolicyHash, nonce: 0n, deadline: u64 });
  assert.equal(consent.message.policyHash, added.prospectivePolicyHash); // Original schema only; Manager admission is separate.
});

test('plans snapshot inputs and reject tampered derived facts without adding an onchain concurrency guard', () => {
  const supplied = snapshot(), change = { ...request }, plan = prepareMintPolicyGraceChange(supplied, change);
  supplied.config.paused = true; supplied.executors.push(a(999)); supplied.counterConfigs[0].staticCap = 1n; change.graceUntil = 1n;
  assert.equal(plan.snapshot.config.paused, false); assert.equal(plan.snapshot.counterConfigs[0].staticCap, u64);
  assert.equal(plan.request.graceUntil, request.graceUntil);
  assert.throws(() => { plan.snapshot.counterIds.reverse(); }, TypeError);
  assert.throws(() => { plan.request.allowed = false; }, TypeError);
  assert.deepEqual(normalizeMintPolicyGracePlan(plan), plan);
  for (const altered of [{ ...plan, changed: false }, { ...plan, factsVerified: true }, { ...plan, prospectivePolicyHash: h(999) },
    { ...plan, targetCall: { ...plan.targetCall, value: 1n } }, { ...plan, governanceCall: { ...plan.governanceCall, oldValueHash: plan.snapshot.currentPolicyHash } }]) assert.throws(() => normalizeMintPolicyGracePlan(altered), /reconstruction/);
  assert.equal(manager.decodeFunctionData('setPhaseExecutorWithGrace', plan.targetCall.data).length, 5);
  const detached = structuredClone(plan), fresh = normalizeMintPolicyGracePlan(detached); detached.snapshot.config.paused = true;
  assert.equal(fresh.snapshot.config.paused, false);
});

test('one-call governance publication, schedule and execution retain exact original identities and compiled ABIs', () => {
  const plan = prepareMintPolicyGraceChange(snapshot(), request), gov = a(601), nonce = (1n << 200n) + 9n;
  const batch = mintPolicyGraceGovernanceBatch(plan, gov, nonce, window), call = plan.governanceCall;
  const originalTuple = '(address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32)[]';
  const calls = [[call.target,call.value,call.selector,call.callDataHash,call.scopeHash,call.oldValueHash,call.newValueHash]];
  const callsHash = hash(['bytes32',originalTuple],['0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70',calls]);
  const aggregate = (domain, value) => hash(['bytes32','bytes32','bytes32[]'],[domain,callsHash,[value]]);
  const scope = aggregate('0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c', call.scopeHash);
  const old = aggregate('0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7', call.oldValueHash);
  const next = aggregate('0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b', call.newValueHash);
  const action = keccak256(concat([coder.encode(['bytes32','uint256','address'],['0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b',input.chainId,gov]),
    coder.encode(['(uint8,bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64,bytes32,bytes32)'],[[1,callsHash,scope,old,next,nonce,window.notBefore,window.expiresAfter,window.reasonHash,window.manifestHash]])]));
  assert.equal(batch.callsHash,callsHash); assert.equal(batch.actionId,action); assert.equal(batch.scopeHash,scope); assert.equal(batch.oldValueHash,old); assert.equal(batch.newValueHash,next);
  assert.equal(batch.publicationKey,keccak256(call.callDataHash));
  assert.deepEqual(batch.publicationCall,{to:gov,value:0n,data:executorAbi.encodeFunctionData('publishGovernanceCallData',[[plan.targetCall.data]])});
  assert.deepEqual(batch.scheduleCall,{to:gov,value:0n,data:executorAbi.encodeFunctionData('scheduleGovernanceBatch',[1,calls,scope,old,next,window.notBefore,window.expiresAfter,window.reasonHash,window.reasonURI,window.manifestHash])});
  assert.deepEqual(batch.executionCall,{to:gov,value:0n,data:executorAbi.encodeFunctionData('executeGovernanceBatch',[action,calls,[plan.targetCall.data]])});
  assert.notEqual(mintPolicyGraceGovernanceBatch(plan,a(602),nonce,window).actionId,action);
  assert.notEqual(mintPolicyGraceGovernanceBatch(plan,gov,nonce + 1n,window).actionId,action);
  const uri = mintPolicyGraceGovernanceBatch(plan,gov,nonce,{...window,reasonURI:'supplemental evidence'});
  assert.equal(uri.actionId,action); assert.notEqual(uri.scheduleCall.data,batch.scheduleCall.data);
});

test('governance windows and immutable packets reject lossy values, short windows and altered publication data', () => {
  const plan = prepareMintPolicyGraceChange(snapshot(), request), suppliedWindow = { ...window };
  const batch = mintPolicyGraceGovernanceBatch(plan,a(601),0n,suppliedWindow);
  suppliedWindow.reasonURI = 'changed'; assert.equal(batch.window.reasonURI,window.reasonURI);
  assert.deepEqual(normalizeMintPolicyGraceGovernanceBatch(batch),batch);
  for (const changes of [{ expiresAfter: window.notBefore }, { expiresAfter: window.notBefore + 604_799n }, { notBefore: 1 }, { expiresAfter: 1n << 64n }, { reasonURI: '\udc00' }, { actionClass: 0n }]) assert.throws(() => normalizeMintPolicyGraceGovernanceWindow({ ...window,...changes }));
  normalizeMintPolicyGraceGovernanceWindow({ ...window,reasonURI:'',reasonHash:ZeroHash,manifestHash:ZeroHash });
  assert.throws(() => mintPolicyGraceGovernanceBatch(plan,a(601),1,window));
  assert.throws(() => normalizeMintPolicyGraceGovernanceBatch({ ...batch, actionId:h(999) }), /reconstruction/);
  assert.throws(() => normalizeMintPolicyGraceGovernanceBatch({ ...batch, publicationCall:{...batch.publicationCall,data:'0x'} }), /reconstruction/);
  assert.throws(() => { batch.window.notBefore = 0n; },TypeError);
  const detached = structuredClone(batch), fresh = normalizeMintPolicyGraceGovernanceBatch(detached); detached.plan.request.allowed = false;
  assert.equal(fresh.plan.request.allowed,true);
});
