import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as pure from '../dist/current-mint-policy-grace.js';
import * as flow from '../dist/current-mint-policy-grace-workflow.js';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/current-mint-policy-grace-abi.json', import.meta.url), 'utf8'));
const abi = new Interface(Object.values(fixture.abis).flat());
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress('0x' + BigInt(n).toString(16).padStart(40, '0'));
const code = n => '0x60' + n.toString(16).padStart(2, '0');
const pin = n => ({ address: A(n), codeHash: keccak256(code(n)) });
const d = { chainId: 31337n, core: pin(1), manager: pin(2), ledger: pin(3), moduleRegistry: pin(4), governance: pin(5), artistRegistry: pin(6) };
const governor = A(50), caller = A(51), pointer = A(90);
const bh = n => id('block:' + n);
const phaseId = id('phase'), cid = 7n;
const baseInput = {
  chainId: d.chainId, manager: A(2), ledger: A(3), moduleRegistry: A(4), collectionId: cid, phaseId,
  config: { paused: false, startTime: 1n, endTime: 0n, maxBatchQuantity: 10n, configHash: id('config'), metadataHash: id('metadata') },
  gate: { gate: ZeroAddress, gateConfigHash: ZeroHash, gateCodehash: ZeroHash, gateMetadataHash: ZeroHash, gateSemanticVersion: 0n, gateGasLimit: 0n },
  counterIds: [id('counter1'), id('counter2')],
  counterConfigs: [1, 2].map(n => ({ enabled: true, keyMode: 1n, capMode: 1n, deltaMode: 0n,
    staticCap: 100n, staticIncrement: 1n, counterConfigHash: id('counter-config' + n) })),
  executors: [A(10), A(11)]
};
const base = { ...baseInput, currentPolicyHash: pure.mintPhasePolicyHash(baseInput) };
const scope = { collectionId: cid, phaseId, executors: base.executors };
const request = { executor: A(12), allowed: true, graceUntil: 300000n };
const grace = { previousPolicyHash: id('older-policy'), previousPolicyRevision: 1n, graceUntil: 999n };
const window = { notBefore: 200000n, expiresAfter: 900000n, reasonHash: id('reason'), reasonURI: 'ipfs://reviewed', manifestHash: id('manifest') };
const tupleObject = (tuple, fields) => Object.fromEntries(fields.map((name, index) => [name, tuple[index]]));
const phaseFields = ['paused', 'startTime', 'endTime', 'maxBatchQuantity', 'configHash', 'metadataHash'];
const gateFields = ['gate', 'gateConfigHash', 'gateCodehash', 'gateMetadataHash', 'gateSemanticVersion', 'gateGasLimit'];
const counterFields = ['enabled', 'keyMode', 'capMode', 'deltaMode', 'staticCap', 'staticIncrement', 'counterConfigHash'];

function provider(options = {}) {
  const calls = [], blocks = new Map();
  return {
    calls,
    async getNetwork() { options.mutate?.(); return { chainId: options.chainId ?? d.chainId }; },
    async getBlock(tag) {
      blocks.set(tag, (blocks.get(tag) ?? 0) + 1);
      return { number: tag, timestamp: options.timestamp?.(tag) ?? 1000 + tag,
        hash: options.reorg && blocks.get(tag) > 1 ? id('reorg') : bh(tag) };
    },
    async getCode(target, tag) {
      const replacement = options.code?.(target, tag);
      if (replacement !== undefined) return replacement;
      if (target === pointer) return '0x00' + coder.encode(['bytes[]'], [[options.batch.plan.targetCall.data]]).slice(2);
      return code(Number(BigInt(target)));
    },
    async call(tx) {
      calls.push(tx);
      const parsed = abi.parseTransaction({ data: tx.data });
      const name = parsed.name, args = parsed.args, tag = tx.blockTag;
      const replacement = options.read?.(name, args, tx);
      if (replacement?.raw !== undefined) return replacement.raw;
      if (replacement !== undefined) return abi.encodeFunctionResult(name, replacement);
      const state = options.state?.(tag) ?? base;
      const currentGrace = options.grace?.(tag) ?? grace;
      let result;
      switch (name) {
        case 'core': result = [A(1)]; break;
        case 'mintLedger': result = [tx.to === A(7) ? A(8) : A(3)]; break;
        case 'moduleRegistry': result = [A(4)]; break;
        case 'governanceExecutor': case 'governanceAuthority': result = [A(5)]; break;
        case 'owner': result = [tx.to === A(5) ? governor : A(5)]; break;
        case 'mintManager': result = [options.origin ? A(7) : A(2)]; break;
        case 'isCompletedMintDescendant': result = [true]; break;
        case 'supportsInterface': case 'isStreamMintManager': case 'isStreamMintLedger':
        case 'collectionExists': case 'ledgerWriter': case 'isProposer': result = [true]; break;
        case 'ledgerWriterRetiredAt': result = [0n]; break;
        case 'getSatellitePointer': {
          const mapping = { [id('MINT_MANAGER')]: pin(2), [id('MINT_LEDGER')]: pin(3),
            [id('MODULE_REGISTRY')]: pin(4), [id('ARTIST_REGISTRY')]: pin(6) };
          const chosen = mapping[args[0]];
          result = [chosen.address, chosen.codeHash, false, args[0], '0x12345678', A(4), 1n, id('module'), id('deployment'), 1n];
          break;
        }
        case 'minimumDelay': result = [172800n]; break;
        case 'governanceActionPolicyState': result = [id('profile'), id('catalog'), 40n, 2n]; break;
        case 'governanceNonce': result = [options.nonce?.(tag) ?? 4n]; break;
        case 'phase': result = [true, state.config]; break;
        case 'phaseGate': result = [state.gate]; break;
        case 'phaseCounterIds': result = [state.counterIds]; break;
        case 'counterConfig': result = [state.counterConfigs[state.counterIds.indexOf(args[2])]]; break;
        case 'registeredCounterPolicy': {
          const { keyMode, ...rest } = state.counterConfigs[state.counterIds.indexOf(args[3])];
          result = [rest]; break;
        }
        case 'phaseExecutor': result = [state.executors.includes(args[2])]; break;
        case 'phasePolicyHash': case 'registeredPhasePolicyHash': result = [state.currentPolicyHash]; break;
        case 'phasePolicyGrace': result = [currentGrace.previousPolicyHash, currentGrace.graceUntil]; break;
        case 'policyGrace': result = [currentGrace.previousPolicyHash, currentGrace.previousPolicyRevision, currentGrace.graceUntil]; break;
        case 'previewPhasePolicyHash': result = [pure.mintPhasePolicyHash({ ...baseInput, collectionId: args[0], phaseId: args[1],
          config: tupleObject(args[2], phaseFields), gate: tupleObject(args[3], gateFields), counterIds: [...args[4]],
          counterConfigs: args[5].map(c => tupleObject(c, counterFields)), executors: [...args[6]] })]; break;
        case 'gasParameterInfo': result = [150000n, 150000n, 2n, 1n]; break;
        case 'consentMode': result = [1n]; break;
        case 'isPolicyConsented': result = [true, id('consent')]; break;
        case 'platformWorksDeclaration': result = [true, id('consent'), 1n]; break;
        case 'requireMintConsent': assert.equal(tx.from, A(2)); result = []; break;
        case 'publishedCallData': result = [options.published?.(tag) === false ? ZeroAddress : pointer]; break;
        case 'publishGovernanceCallData': result = [pointer]; break;
        case 'scheduleGovernanceBatch': result = [options.batch.actionId]; break;
        case 'executeGovernanceBatch': result = []; break;
        case 'scheduledCallData': result = [[options.batch.plan.targetCall.data]]; break;
        case 'scheduledCallDataPointer': result = [pointer]; break;
        case 'governanceAction': {
          const b = options.batch;
          result = [[options.status?.(tag) ?? 1n, 1n, A(2), 0n, '0xdef72e30', b.callsHash, b.scopeHash,
            b.oldValueHash, b.newValueHash, b.window.notBefore, b.window.expiresAfter, governor,
            options.executedCaller ?? caller, ZeroAddress, ZeroAddress, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]];
          break;
        }
        default: throw Error('Unhandled ' + name);
      }
      return abi.encodeFunctionResult(name, result);
    }
  };
}
async function bundle(change = request, options = {}, deployment = d) {
  const rpc = provider(options);
  const capture = await flow.captureMintPolicyGrace(rpc, deployment, scope, { blockTag: 10 });
  const inspection = await flow.inspectMintPolicyGraceChange(rpc, capture, change, { blockTag: 10 });
  const prepared = flow.prepareMintPolicyGraceGovernance(inspection, governor, window);
  options.batch = prepared.batch;
  return { rpc, options, capture, inspection, prepared };
}
function op(b, stage, actor = stage === 'schedule' ? governor : caller) {
  return flow.prepareMintPolicyGraceGovernanceOperation(b.prepared, stage, actor);
}
const safe = new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)']);
const safePlain = new Interface(['event ExecutionSuccess(bytes32 txHash,uint256 payment)', 'event ExecutionFailure(bytes32 txHash,uint256 payment)']);
const safeIndexed = new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']);
function mined(b, stage, options = {}) {
  const operation = op(b, stage), batch = b.prepared.batch, plan = b.inspection.plan;
  const tag = options.receiptBlock ?? (stage === 'execute' ? 200001 : 11);
  const transactionHash = id(stage + JSON.stringify(options));
  const logs = [];
  const emit = (address, name, values, iface = abi) => {
    const encoded = iface.encodeEventLog(iface.getEvent(name), values);
    logs.push({ address, ...encoded, index: logs.length, transactionHash, blockNumber: tag, blockHash: bh(tag), removed: false });
  };
  const common = [1n, batch.actionId, 1n, A(2), 0n, '0xdef72e30', batch.callsHash, batch.scopeHash, batch.oldValueHash, batch.newValueHash];
  if (stage === 'publish') {
    if (!options.repeat) emit(A(5), 'GovernanceCallDataPublished', [1n, batch.publicationKey, pointer, operation.caller]);
  } else {
    if (stage === 'schedule') {
      emit(A(5), 'GovernanceActionScheduled', [...common, window.notBefore, window.expiresAfter, batch.nonce, governor, window.reasonHash, window.reasonURI, window.manifestHash]);
    } else {
      if (plan.changed) {
        emit(A(2), 'MintPhaseConsentRecorded', [1n, cid, phaseId, plan.prospectivePolicyHash, 1n, id('consent')]);
        emit(A(3), 'MintLedgerPolicyGraceSet', [1n, cid, phaseId, A(2), base.currentPolicyHash, plan.prospectivePolicyHash, plan.request.graceUntil]);
        emit(A(3), 'MintLedgerPhasePolicyRegistered', [A(2), cid, phaseId, plan.prospectivePolicyHash]);
        base.counterConfigs.forEach((c, n) => emit(A(3), 'MintLedgerCounterPolicyRegistered', [A(2), cid, phaseId,
          base.counterIds[n], c.capMode, c.deltaMode, c.staticCap, c.staticIncrement, c.counterConfigHash, plan.prospectivePolicyHash]));
        emit(A(2), 'MintPhaseExecutorUpdated', [cid, phaseId, plan.request.executor, plan.request.allowed, plan.prospectivePolicyHash, A(5)]);
      }
      emit(A(5), 'GovernanceActionExecuted', [...common, caller, window.manifestHash]);
    }
    // Validation runs first, but the original Executor emits its validation event last.
    emit(A(5), 'GovernanceActionPolicyValidated', [1n, batch.actionId, stage === 'schedule' ? 1n : 2n, id('profile'), id('catalog')]);
  }
  if (options.safe) emit(operation.caller, 'ExecutionSuccess', [id('safe-hash'), 0n], options.indexed ? safeIndexed : safePlain);
  const tx = { hash: transactionHash, chainId: d.chainId, blockNumber: tag, blockHash: bh(tag),
    from: options.safe ? A(99) : operation.caller, to: options.safe ? operation.caller : A(5), value: 0n,
    data: options.safe ? safe.encodeFunctionData('execTransaction', [A(5), 0n, operation.call.data, 0, 0, 0, 0, ZeroAddress, ZeroAddress, '0x']) : operation.call.data };
  const receipt = { ...tx, status: 1, logs };
  const after = { ...base, executors: plan.prospectiveExecutors, currentPolicyHash: plan.prospectivePolicyHash };
  const afterGrace = !plan.changed ? grace : plan.request.graceUntil === 0n
    ? { previousPolicyHash: ZeroHash, previousPolicyRevision: 0n, graceUntil: 0n }
    : { previousPolicyHash: base.currentPolicyHash, previousPolicyRevision: 2n, graceUntil: plan.request.graceUntil };
  const rpc = provider({ batch, state: n => stage === 'execute' && n >= tag ? after : base,
    grace: n => stage === 'execute' && n >= tag ? afterGrace : grace,
    nonce: n => n >= tag && stage !== 'publish' ? 5n : 4n,
    status: n => options.status?.(n) ?? (n >= tag && stage === 'execute' ? 3n : 1n),
    published: n => stage === 'publish' ? options.repeat || n >= tag : true,
    read: options.read, code: options.code, timestamp: options.timestamp, reorg: options.reorg });
  rpc.getTransaction = async () => tx;
  rpc.getTransactionReceipt = async () => receipt;
  return { rpc, operation, tx, receipt, tag, transactionHash };
}
async function inspect(r, execution = 'direct') {
  return flow.inspectMintPolicyGraceOperationReceipt(r.rpc, r.operation, { transactionHash: r.transactionHash, execution });
}

test('captures complete executor identity with ordered counters and both original current/preview hashes', async () => {
  const b = await bundle();
  assert.equal(b.capture.snapshot.currentPolicyHash, base.currentPolicyHash);
  assert.deepEqual(b.capture.grace, grace);
  assert.equal(b.capture.catalog.rowAdmission, 'original-call-simulation-required');
  assert.equal(b.inspection.artistConsent.registrationReady, true);
  assert.equal(b.inspection.artistConsent.signingManager, A(2));
  assert(Object.isFrozen(b.capture.snapshot.counterConfigs[0]));
  assert(Object.isFrozen(b.inspection.plan.request));
  await assert.rejects(flow.captureMintPolicyGrace(provider(), d, { ...scope, executors: [A(10)] }, { blockTag: 10 }), /complete policy/);
  await assert.rejects(flow.captureMintPolicyGrace(provider({ read: name => name === 'previewPhasePolicyHash' ? [id('wrong')] : undefined }), d, scope, { blockTag: 10 }), /policy hash/);
});

test('capture rejects mismatched runtime, ownership, chain, existence, membership and canonical RPC', async () => {
  for (const [name, result, pattern] of [
    ['owner', [A(400)], /governance|owner/i], ['collectionExists', [false], /Unknown collection/],
    ['phase', [false, base.config], /Unknown phase/], ['phaseExecutor', [false], /membership/],
    ['registeredPhasePolicyHash', [id('wrong')], /policy hash/],
    ['phasePolicyGrace', [ZeroHash, 0n], /grace differs/],
    ['minimumDelay', [0n], /governance/], ['phasePolicyHash', { raw: base.currentPolicyHash + '00' }, /decode|length|Noncanonical/]
  ]) {
    await assert.rejects(flow.captureMintPolicyGrace(provider({ read: n => n === name ? result : undefined }), d, scope, { blockTag: 10 }), pattern);
  }
  await assert.rejects(flow.captureMintPolicyGrace(provider({ chainId: 1n }), d, scope, { blockTag: 10 }), /chain/);
  await assert.rejects(flow.captureMintPolicyGrace(provider({ code: () => '0x' }), d, scope, { blockTag: 10 }), /runtime/);
  await assert.rejects(flow.captureMintPolicyGrace(provider({ reorg: true }), d, scope, { blockTag: 10 }), /block changed/);
  const delegated = '0xef0100' + A(99).slice(2), changed = structuredClone(d);
  changed.manager.codeHash = keccak256(delegated);
  await assert.rejects(flow.captureMintPolicyGrace(provider({ code: target => target === A(2) ? delegated : undefined }), changed, scope, { blockTag: 10 }), /runtime/);
});

test('prospective Artist checks preserve exact modes1/3, declaration and original successor ancestry', async () => {
  for (const mode of [0n, 2n, 3n]) {
    const b = await bundle(request, { read: name => name === 'consentMode' ? [mode] : undefined });
    assert.equal(b.inspection.artistConsent.registrationReady, mode === 3n);
  }
  const missing = await bundle(request, { read: name => name === 'isPolicyConsented' ? [false, ZeroHash] : undefined });
  assert.equal(missing.inspection.artistConsent.registrationReady, false);
  const badDeclaration = await bundle(request, { read: name => name === 'consentMode' ? [3n]
    : name === 'platformWorksDeclaration' ? [true, id('other'), 1n] : undefined });
  assert.equal(badDeclaration.inspection.artistConsent.registrationReady, false);
  const origin = { ...d, artistOrigin: { manager: pin(7), ledger: pin(8) } };
  const b = await bundle(request, { origin: true }, origin);
  assert.equal(b.inspection.artistConsent.signingManager, A(7));
  await assert.rejects(bundle(request, { origin: true }), /pin required/);
  await assert.rejects(bundle(request, { origin: true, read: n => n === 'isCompletedMintDescendant' ? [false] : undefined }, origin), /ancestry/);
  await assert.rejects(bundle(request, { read: n => n === 'ledgerWriterRetiredAt' ? [1n] : undefined }), /Ledger writer/);
});

test('unchanged zero-grace no-op skips all Artist registration and writer checks and retains prior grace', async () => {
  const noOp = { executor: A(10), allowed: true, graceUntil: 0n };
  const b = await bundle(noOp, { read(name) {
    if (['consentMode', 'isPolicyConsented', 'requireMintConsent', 'mintManager', 'ledgerWriter'].includes(name)) throw Error('No-op must skip Artist/ledger admission');
  } });
  assert.equal(b.inspection.plan.changed, false);
  assert.equal(b.inspection.artistConsent, null);
  assert.deepEqual(b.capture.grace, grace);
  await flow.simulateMintPolicyGraceOperation(b.rpc, op(b, 'execute'), { blockTag: 200000 });
  await assert.rejects(flow.inspectMintPolicyGraceChange(b.rpc, b.capture, { ...noOp, graceUntil: 1n }, { blockTag: 10 }), /Unchanged/);
});

test('publication, scheduling and permissionless execution simulate original calls from the actual caller', async () => {
  const b = await bundle();
  for (const stage of ['publish', 'schedule', 'execute']) {
    const operation = op(b, stage), tag = stage === 'execute' ? 200000 : 10;
    const result = await flow.simulateMintPolicyGraceOperation(b.rpc, operation, { blockTag: tag });
    assert.equal(result.operation.call.value, 0n);
    const last = b.rpc.calls.at(-1);
    assert.equal(last.from, operation.caller);
    assert.equal(last.to, A(5));
    assert.equal(last.data, operation.call.data);
    assert.equal(result.observed === null, stage === 'publish');
  }
  const absent = await bundle(request, { read: name => name === 'isPolicyConsented' ? [false, ZeroHash] : undefined });
  await flow.simulateMintPolicyGraceOperation(absent.rpc, op(absent, 'schedule'), { blockTag: 10 });
  await assert.rejects(flow.simulateMintPolicyGraceOperation(absent.rpc, op(absent, 'execute'), { blockTag: 200000 }), /Artist consent unavailable/);
});

test('48h scheduling, inclusive execution endpoints and execution-relative30day grace remain distinct', async () => {
  const b = await bundle();
  assert.throws(() => flow.prepareMintPolicyGraceGovernance(b.inspection, governor, { ...window, notBefore: 1010n + 172799n }), /48h/);
  assert.throws(() => flow.prepareMintPolicyGraceGovernance(b.inspection, governor, { ...window, expiresAfter: window.notBefore + 604799n }), /7|window/);
  for (const timestamp of [Number(window.notBefore), Number(window.expiresAfter)]) {
    const rpc = provider({ batch: b.prepared.batch, timestamp: tag => tag === 10 ? 1010 : timestamp });
    await flow.simulateMintPolicyGraceOperation(rpc, op(b, 'execute'), { blockTag: 20 });
  }
  for (const timestamp of [Number(window.notBefore - 1n), Number(window.expiresAfter + 1n)]) {
    const rpc = provider({ batch: b.prepared.batch, timestamp: tag => tag === 10 ? 1010 : timestamp });
    await assert.rejects(flow.simulateMintPolicyGraceOperation(rpc, op(b, 'execute'), { blockTag: 20 }), /execution window/);
  }
  for (const graceUntil of [1n, 201000n, 201000n + 2592000n]) {
    const b = await bundle({ ...request, graceUntil });
    await flow.simulateMintPolicyGraceOperation(b.rpc, op(b, 'execute'), { blockTag: 200000 });
  }
  const tooFar = await bundle({ ...request, graceUntil: 201000n + 2592001n });
  await assert.rejects(flow.simulateMintPolicyGraceOperation(tooFar.rpc, op(tooFar, 'execute'), { blockTag: 200000 }), /30 days/);
});

test('stale policy/catalog/nonce, missing publication and changed exact-call results reject before claimed readiness', async () => {
  const b = await bundle();
  for (const [name, value, stage, pattern] of [
    ['governanceNonce', [5n], 'schedule', /nonce/],
    ['governanceActionPolicyState', [id('profile'), id('new-catalog'), 41n, 3n], 'schedule', /catalog/],
    ['publishedCallData', [ZeroAddress], 'schedule', /Publish/],
    ['scheduleGovernanceBatch', [id('wrong-action')], 'schedule', /action ID/],
    ['executeGovernanceBatch', { raw: '0x00' }, 'execute', /void/],
    ['publishGovernanceCallData', [A(91)], 'publish', /pointer changed/]
  ]) {
    const rpc = provider({ batch: b.prepared.batch, read: (n, args, tx) => tx.blockTag !== 10 && n === name ? value : undefined });
    await assert.rejects(flow.simulateMintPolicyGraceOperation(rpc, op(b, stage), { blockTag: stage === 'execute' ? 200000 : 11 }), pattern);
  }
  const changed = { ...baseInput, executors: [...base.executors, A(13)] };
  const state = { ...changed, currentPolicyHash: pure.mintPhasePolicyHash(changed) };
  const rpc = provider({ batch: b.prepared.batch, state: tag => tag > 10 ? state : base });
  await assert.rejects(flow.simulateMintPolicyGraceOperation(rpc, op(b, 'execute'), { blockTag: 200000 }), /complete policy/);
  await flow.simulateMintPolicyGraceOperation(rpc, op(b, 'publish'), { blockTag: 200000 });
});

test('captures and operations clone inputs before awaits and reject typed-fact and call forgery', async () => {
  const mutableD = structuredClone(d), mutableScope = structuredClone(scope), options = { blockTag: 10 };
  const capture = await flow.captureMintPolicyGrace(provider({ mutate() {
    mutableD.manager.address = A(444); mutableScope.executors[0] = A(555); options.blockTag = 90;
  } }), mutableD, mutableScope, options);
  assert.equal(capture.deployment.manager.address, A(2));
  assert.equal(capture.blockNumber, 10);
  const b = await bundle();
  const forged = structuredClone(b.capture);
  forged.grace.previousPolicyRevision = '1n';
  await assert.rejects(flow.inspectMintPolicyGraceChange(b.rpc, forged, request, { blockTag: 10 }), /facts changed/);
  const action = structuredClone(op(b, 'execute'));
  action.call.to = A(444);
  await assert.rejects(flow.simulateMintPolicyGraceOperation(b.rpc, action, { blockTag: 200000 }), /differs|facts differ/);
  await assert.rejects(flow.captureMintPolicyGrace(provider(), { ...d, extra: true }, scope, { blockTag: 10 }), /properties/);
});

test('direct and both Safe layouts join exact publication, scheduling and full Manager/Ledger execution events', async () => {
  const b = await bundle();
  for (const stage of ['publish', 'schedule', 'execute']) {
    for (const options of [{}, { safe: true }, { safe: true, indexed: true }]) {
      const r = mined(b, stage, options);
      const result = await inspect(r, options.safe ? 'safe' : 'direct');
      assert.equal(result.operation.stage, stage);
      assert.equal(result.stateAttribution, 'exact end-of-block policy required; events identify this operation');
      if (stage === 'execute') {
        assert.equal(result.observedPolicy.grace.previousPolicyHash, base.currentPolicyHash);
        assert.equal(result.events.filter(x => x.event === 'MintLedgerCounterPolicyRegistered').length, 2);
      }
      assert(Object.isFrozen(result.events));
    }
  }
});

test('real zero-grace rotation clears tuple, while an event-free no-op preserves grace with prior-block proof', async () => {
  const clearing = await bundle({ ...request, graceUntil: 0n });
  const cleared = await inspect(mined(clearing, 'execute'));
  assert.equal(cleared.observedPolicy.grace.previousPolicyHash, ZeroHash);
  const noOp = await bundle({ executor: A(10), allowed: true, graceUntil: 0n });
  const result = await inspect(mined(noOp, 'execute'));
  assert.deepEqual(result.observedPolicy.grace, grace);
  assert.equal(result.events.some(e => e.event.startsWith('Mint')), false);
  const contradictory = mined(noOp, 'execute', { read(name, args, tx) {
    if (tx.blockTag === 200000 && name === 'policyGrace') return [id('other'), 2n, 900n];
    if (tx.blockTag === 200000 && name === 'phasePolicyGrace') return [id('other'), 900n];
  } });
  await assert.rejects(inspect(contradictory), /previous-block grace proof/);
});

test('publication retries require immutable previous-block pointer proof; first missing event cannot borrow later state', async () => {
  const b = await bundle();
  await inspect(mined(b, 'publish', { repeat: true }));
  const missing = mined(b, 'publish'); missing.receipt.logs = [];
  await assert.rejects(inspect(missing), /previous-block proof/);
  const moved = mined(b, 'publish', { repeat: true, read(name, args, tx) {
    if (name === 'publishedCallData' && tx.blockTag === 10) return [A(91)];
  }, code(target) {
    if (target === A(91)) return '0x00' + coder.encode(['bytes[]'], [[b.prepared.batch.plan.targetCall.data]]).slice(2);
  } });
  await assert.rejects(inspect(moved), /pointer changed/);
  const unpinned = mined(b, 'publish', { repeat: true, receiptBlock: 12, code(target, tag) {
    if (target === A(5) && tag === 11) return '0x1234';
  } });
  await assert.rejects(inspect(unpinned), /runtime/);
});

test('receipt identity, exact Safe CALL, success ordering and original policy event preimages fail closed', async () => {
  const b = await bundle();
  let r = mined(b, 'execute', { safe: true });
  r.receipt.logs.pop();
  await assert.rejects(inspect(r, 'safe'), /Safe requires/);
  r = mined(b, 'execute', { safe: true });
  const success = r.receipt.logs.pop();
  r.receipt.logs.unshift(success); r.receipt.logs.forEach((l, n) => l.index = n);
  await assert.rejects(inspect(r, 'safe'), /Safe success/);
  r = mined(b, 'execute', { safe: true });
  const args = [...safe.decodeFunctionData('execTransaction', r.tx.data)]; args[3] = 1n;
  r.tx.data = safe.encodeFunctionData('execTransaction', args);
  await assert.rejects(inspect(r, 'safe'), /ordinary/);
  r = mined(b, 'execute');
  const target = r.receipt.logs.find(l => l.topics[0] === abi.getEvent('MintLedgerPolicyGraceSet').topicHash);
  const values = [...abi.decodeEventLog('MintLedgerPolicyGraceSet', target.data, target.topics)]; values[4] = id('wrong-old');
  Object.assign(target, abi.encodeEventLog('MintLedgerPolicyGraceSet', values));
  await assert.rejects(inspect(r), /fields differ/);
  r = mined(b, 'execute'); r.receipt.logs[2].data += '00';
  await assert.rejects(inspect(r), /Noncanonical|decode|length/);
  r = mined(b, 'execute'); r.tx.chainId = 1n;
  await assert.rejects(inspect(r), /identity/);
});

test('receipt readback rejects later same-block policy drift and contradictory grace without inventing active revision', async () => {
  const b = await bundle();
  const r = mined(b, 'execute', { read(name, args, tx) {
    if (tx.blockTag === 200001 && name === 'registeredPhasePolicyHash') return [id('later-policy')];
  } });
  await assert.rejects(inspect(r), /policy hash/);
  const revision = mined(b, 'execute', { read(name, args, tx) {
    if (tx.blockTag === 200001 && name === 'policyGrace') return [base.currentPolicyHash, 17n, request.graceUntil];
  } });
  const result = await inspect(revision);
  assert.equal(result.observedPolicy.grace.previousPolicyRevision, 17n);
  const bad = mined(b, 'execute', { read(name, args, tx) {
    if (tx.blockTag === 200001 && name === 'policyGrace') return [base.currentPolicyHash, 0n, request.graceUntil];
  } });
  await assert.rejects(inspect(bad), /Malformed predecessor/);
  const regressed = mined(b, 'execute', { read(name, args, tx) {
    if (tx.blockTag === 200001 && name === 'policyGrace') return [base.currentPolicyHash, 1n, request.graceUntil];
  } });
  await assert.rejects(inspect(regressed), /Predecessor grace/);
});

test('governance validation events follow scheduling/execution and class1 schedule readback permits only scheduled or cancelled', async () => {
  const b = await bundle();
  for (const stage of ['schedule', 'execute']) {
    const r = mined(b, stage);
    const last = r.receipt.logs.pop();
    assert.equal(last.topics[0], abi.getEvent('GovernanceActionPolicyValidated').topicHash);
    r.receipt.logs.unshift(last); r.receipt.logs.forEach((l, n) => l.index = n);
    await assert.rejects(inspect(r), /must follow/);
  }
  await inspect(mined(b, 'schedule', { status: n => n === 11 ? 2n : 1n }));
  for (const status of [0n, 3n, 4n, 5n]) {
    await assert.rejects(inspect(mined(b, 'schedule', { status: n => n === 11 ? status : 1n })), /action\/nonce/);
  }
});
