import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as pure from '../dist/current-mint-phase-freeze.js';
import { mintPhasePolicyHash } from '../dist/current-mint-policy-grace.js';
import * as flow from '../dist/current-mint-phase-freeze-workflow.js';
import { createSafeCallPlan } from '../dist/safe-plan.js';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/current-mint-phase-freeze-abi.json', import.meta.url), 'utf8'));
const abi = new Interface(Object.values(fixture.abis).flat());
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress('0x' + BigInt(n).toString(16).padStart(40, '0'));
const code = n => '0x60' + n.toString(16).padStart(2, '0');
const pin = n => ({ address: A(n), codeHash: keccak256(code(n)) });
const d = { chainId: 31337n, core: pin(1), manager: pin(2), ledger: pin(3), moduleRegistry: pin(4), governance: pin(5) };
const governor = A(50), caller = A(51), pointer = A(90), predecessor = A(7);
const bh = n => id('block:' + n), scope = { collectionId: 8n, phaseId: id('phase') };
const grace = { previousPolicyHash: id('earlier-policy'), previousPolicyRevision: 6n, graceUntil: 777n };
const window = { notBefore: 300000n, expiresAfter: 1000000n, reasonHash: id('reason'), reasonURI: 'ipfs://review', manifestHash: id('manifest') };
const fields = {
  phase: ['paused', 'startTime', 'endTime', 'maxBatchQuantity', 'configHash', 'metadataHash'],
  gate: ['gate', 'gateConfigHash', 'gateCodehash', 'gateMetadataHash', 'gateSemanticVersion', 'gateGasLimit'],
  counter: ['enabled', 'keyMode', 'capMode', 'deltaMode', 'staticCap', 'staticIncrement', 'counterConfigHash']
};
const object = (tuple, names) => Object.fromEntries(names.map((n, i) => [n, tuple[i]]));
function phase(manager = A(2), identity = scope, options = {}) {
  const constraints = {
    chainId: d.chainId, core: A(1), manager, ledger: A(3), moduleRegistry: A(4), ...identity,
    config: { paused: options.paused ?? false, startTime: 1n, endTime: 0n, maxBatchQuantity: 10n,
      configHash: options.configHash ?? id('config'), metadataHash: id('metadata') },
    gate: { gate: ZeroAddress, gateConfigHash: ZeroHash, gateCodehash: ZeroHash, gateMetadataHash: ZeroHash, gateSemanticVersion: 0n, gateGasLimit: 0n },
    counterIds: [id('counter B'), id('counter A')],
    counterConfigs: [1, 2].map(n => ({ enabled: true, keyMode: 1n, capMode: 1n, deltaMode: 0n,
      staticCap: 100n, staticIncrement: 1n, counterConfigHash: id('counter-config' + n) })),
    defined: [false, true],
    definitions: [{ scope: 0n, keyMode: 0n, capRoot: ZeroHash, metadataHash: id('legacy definition') },
      { scope: 2n, keyMode: 1n, capRoot: ZeroHash, metadataHash: id('effective definition') }],
    royalty: { configured: options.royalty ?? false, applicationConfigHash: id('application'), resolver: A(20),
      resolverRuntimeHash: id('resolver runtime'), electionHash: id('election'), expectedModeAssignmentHash: id('mode'), expectedSourceRoyaltyPolicyHash: id('royalty') }
  };
  if (constraints.royalty.configured) constraints.config.configHash = pure.mintPhaseFreezeRoyaltyConfigHash(constraints);
  const { core, defined, definitions, royalty, ...policyInput } = constraints;
  const executors = options.executors ?? [A(10), A(11)];
  const policy = { ...policyInput, executors, currentPolicyHash: mintPhasePolicyHash({ ...policyInput, executors }) };
  const configurationHash = pure.mintPhaseFreezeConfigurationHash(constraints);
  const record = options.record ?? (options.frozen
    ? { policyHash: options.provenance ?? policy.currentPolicyHash, configurationHash }
    : { policyHash: ZeroHash, configurationHash: ZeroHash });
  return { identity, exists: options.exists ?? true, policy, constraints, configurationHash, record,
    ceiling: options.ceiling ?? (record.configurationHash === ZeroHash ? [] : executors), grace: options.grace ?? grace };
}
const base = phase();
function snapshot(state, manager) {
  return { chainId: d.chainId, core: A(1), manager, ledger: A(3), governanceExecutor: A(5), ...state.identity,
    currentPolicyHash: state.exists ? state.policy.currentPolicyHash : ZeroHash, record: state.record };
}
function selector(enabled = true, revision = enabled ? 1n : 0n) {
  const input = { enabled, targetCodeHash: enabled ? d.manager.codeHash : ZeroHash, revision };
  return { ...input, stateHash: pure.mintPhaseFreezeSelectorStateHash(d.chainId, A(5), A(2), input) };
}
const importScope = { importRoot: id('original import root'), predecessorManager: pin(7) };
const emptyGrace = { previousPolicyHash: ZeroHash, previousPolicyRevision: 0n, graceUntil: 0n };

function provider(options = {}) {
  const calls = [], blocks = new Map();
  const stateAt = (tag, manager, identity) => options.state?.(tag, manager, identity) ?? phase(manager, identity);
  const inventoryAt = (tag, manager) => options.inventory?.(tag, manager)
    ?? (stateAt(tag, manager, scope).record.configurationHash === ZeroHash ? [] : [scope]);
  const commitmentAt = tag => ({ predecessorLedger: A(3), predecessorManager: predecessor, successorManager: A(2), snapshotBlock: 8n,
    manifestHash: id('original manifest'), importedCounters: 0n, importedNullifiers: 0n, complete: false, ...options.commitment?.(tag) });
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
      const parsed = abi.parseTransaction({ data: tx.data }), name = parsed.name, args = Array.from(parsed.args), tag = tx.blockTag;
      const replacement = options.read?.(name, args, tx);
      if (replacement?.raw !== undefined) return replacement.raw;
      if (replacement !== undefined) return abi.encodeFunctionResult(name, replacement);
      const ledgerScoped = ['phaseFreeze', 'frozenPhaseExecutors', 'registeredPhasePolicyHash', 'registeredCounterPolicy', 'policyGrace'].includes(name);
      const manager = ledgerScoped ? args[0] : tx.to;
      const identity = { collectionId: args[ledgerScoped ? 1 : 0] ?? scope.collectionId, phaseId: args[ledgerScoped ? 2 : 1] ?? scope.phaseId };
      const s = ['phaseFreeze', 'frozenPhaseExecutors', 'registeredPhasePolicyHash', 'registeredCounterPolicy', 'policyGrace', 'phase', 'phaseGate',
        'phaseCounterIds', 'counterConfig', 'phaseExecutors', 'phaseExecutor', 'phasePolicyHash', 'phasePolicyGrace', 'phaseFrozen', 'phaseRoyaltyPolicy',
        'phaseFreezeTransitionHashes'].includes(name) ? stateAt(tag, manager, identity) : base;
      const c = commitmentAt(tag), b = options.batch;
      let result;
      switch (name) {
        case 'core': result = [A(1)]; break;
        case 'mintLedger': result = [A(3)]; break;
        case 'moduleRegistry': result = [A(4)]; break;
        case 'governanceExecutor': case 'governanceAuthority': result = [A(5)]; break;
        case 'owner': result = [tx.to === A(5) ? governor : A(5)]; break;
        case 'supportsInterface': case 'isStreamMintManager': case 'isStreamMintLedger': case 'collectionExists': case 'isProposer': result = [true]; break;
        case 'ledgerWriter': result = [args[0] !== predecessor && (options.writer?.(tag) ?? true)]; break;
        case 'ledgerWriterRetiredAt': result = [args[0] === predecessor ? 5n : options.retired?.(tag) ?? 0n]; break;
        case 'minimumDelay': result = [args[0] === 2n ? 259200n : 0n]; break;
        case 'systemManifestBootstrapState': {
          result = Array.from(coder.getDefaultValue(abi.getFunction(name).outputs));
          result[0] = true; result[1] = true; result[2] = A(6); result[3] = pin(6).codeHash;
          break;
        }
        case 'roleRegistry': result = [A(6)]; break;
        case 'governanceActionPolicyState': result = [id('profile'), id('catalog'), 40n, 0n]; break;
        case 'governanceNonce': result = [options.nonce?.(tag) ?? 4n]; break;
        case 'freezeSelectorConfig': {
          const f = options.selector?.(tag) ?? selector(); result = [f.enabled, f.targetCodeHash, f.revision, f.stateHash]; break;
        }
        case 'isFreezeSelector': result = [(options.selector?.(tag) ?? selector()).enabled]; break;
        case 'phase': result = [s.exists, s.exists ? s.policy.config : [false, 0n, 0n, 0n, ZeroHash, ZeroHash]]; break;
        case 'phaseGate': result = [s.policy.gate]; break;
        case 'phaseCounterIds': result = [s.policy.counterIds]; break;
        case 'counterConfig': result = [s.policy.counterConfigs[s.policy.counterIds.indexOf(args[2])]]; break;
        case 'registeredCounterPolicy': {
          const { keyMode, ...rest } = s.policy.counterConfigs[s.policy.counterIds.indexOf(args[3])]; result = [rest]; break;
        }
        case 'counterDefinitionForManager': {
          const index = base.policy.counterConfigs.findIndex(c => c.counterConfigHash === args[1]);
          result = [base.constraints.defined[index], base.constraints.definitions[index]]; break;
        }
        case 'phaseExecutors': result = [s.exists ? s.policy.executors : []]; break;
        case 'phaseExecutor': result = [s.policy.executors.includes(args[2])]; break;
        case 'phasePolicyHash': case 'registeredPhasePolicyHash': result = [s.exists ? s.policy.currentPolicyHash : ZeroHash]; break;
        case 'phasePolicyGrace': result = [s.exists ? s.grace.previousPolicyHash : ZeroHash, s.exists ? s.grace.graceUntil : 0n]; break;
        case 'policyGrace': result = s.exists ? Object.values(s.grace) : [ZeroHash, 0n, 0n]; break;
        case 'phaseRoyaltyPolicy': result = [s.constraints.royalty]; break;
        case 'phaseFrozen': result = [s.record.configurationHash !== ZeroHash]; break;
        case 'phaseFreeze': result = [s.record]; break;
        case 'phaseFreezeTransitionHashes': result = Object.values(pure.mintPhaseFreezeTransition(snapshot(s, manager))); break;
        case 'frozenPhaseExecutors': result = [s.ceiling]; break;
        case 'frozenPhaseCount': result = [BigInt(inventoryAt(tag, args[0]).length)]; break;
        case 'frozenPhaseAt': result = Object.values(inventoryAt(tag, args[0])[Number(args[1])]); break;
        case 'previewPhasePolicyHash': result = [mintPhasePolicyHash({ chainId: d.chainId, manager: tx.to, ledger: A(3), moduleRegistry: A(4),
          collectionId: args[0], phaseId: args[1], config: object(args[2], fields.phase), gate: object(args[3], fields.gate),
          counterIds: [...args[4]], counterConfigs: args[5].map(v => object(v, fields.counter)), executors: [...args[6]] })]; break;
        case 'terminalFreezeVetoGuardianSet': {
          const global = id('ROLE_TERMINAL_FREEZE_VETO');
          result = [A(6), keccak256(coder.encode(['bytes32', 'bytes32'], [global, args[0]])), 1n, global, 2n, 0n]; break;
        }
        case 'roleHolderCount': result = [args[0] === id('ROLE_TERMINAL_FREEZE_VETO') ? 2n : 1n]; break;
        case 'isRoleRedundant': result = [true]; break;
        case 'terminalFreezeGuardianConfigCommitment': result = [id('guardian commitment')]; break;
        case 'publishedCallData': result = [options.published?.(tag) === false ? ZeroAddress : pointer]; break;
        case 'publishGovernanceCallData': result = [pointer]; break;
        case 'scheduleGovernanceBatch': result = [b.actionId]; break;
        case 'executeGovernanceBatch': case 'importPhaseFreezes': result = []; break;
        case 'scheduledCallData': result = [[b.plan.targetCall.data]]; break;
        case 'scheduledCallDataPointer': result = [pointer]; break;
        case 'governanceAction': result = [[options.status?.(tag) ?? 1n, b.plan.actionClass, b.plan.targetCall.to, 0n,
          b.plan.governanceCall.selector, b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash, b.window.notBefore, b.window.expiresAfter,
          governor, caller, ZeroAddress, ZeroAddress, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]]; break;
        case 'governanceActionFacts': result = [[options.status?.(tag) ?? 1n, b.plan.actionClass, b.callsHash, b.window.notBefore, b.window.expiresAfter]]; break;
        case 'mintImportCommitment': result = [c]; break;
        case 'mintImportFreezeProgress': result = [options.progress?.(tag) ?? 0n, BigInt(inventoryAt(tag, predecessor).length)]; break;
        case 'mintImportDefinitionProgress': case 'mintImportAncestryProgress': result = [1n, 1n]; break;
        case 'isMintSuccessorReady': result = [c.complete && (options.writer?.(tag) ?? true) && (options.retired?.(tag) ?? 0n) === 0n]; break;
        default: throw Error('Unhandled ' + name);
      }
      return abi.encodeFunctionResult(name, result);
    }
  };
}
async function bundle(kind = 'freeze', options = {}) {
  options.selector ??= () => selector(kind === 'freeze');
  const rpc = provider(options), capture = await flow.captureMintPhaseFreeze(rpc, d, scope, { blockTag: 10 });
  const prepared = flow.prepareMintPhaseFreezeGovernance(capture, kind, governor, window);
  options.batch = prepared.batch;
  return { rpc, capture, prepared, options };
}
const operation = (b, stage) => flow.prepareMintPhaseFreezeGovernanceOperation(b.prepared, stage, stage === 'schedule' ? governor : caller);
const safe = new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)']);
const safePlain = new Interface(['event ExecutionSuccess(bytes32 txHash,uint256 payment)', 'event ExecutionFailure(bytes32 txHash,uint256 payment)']);
const safeIndexed = new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']);
function envelope(op, tag, events, options = {}) {
  const transactionHash = id('receipt:' + tag + ':' + events.length), logs = [];
  const emit = (target, name, values, codec = abi) => {
    const encoded = codec.encodeEventLog(codec.getEvent(name), values);
    logs.push({ address: target, ...encoded, index: logs.length, transactionHash, blockNumber: tag, blockHash: bh(tag), removed: false });
  };
  events.forEach(e => emit(...e));
  if (options.safe) emit(op.caller, 'ExecutionSuccess', [id('Safe transaction'), 0n], options.indexed ? safeIndexed : safePlain);
  const tx = { hash: transactionHash, chainId: d.chainId, blockNumber: tag, blockHash: bh(tag), from: options.safe ? A(99) : op.caller,
    to: options.safe ? op.caller : op.call.to, value: 0n, data: options.safe
      ? safe.encodeFunctionData('execTransaction', [op.call.to, 0n, op.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']) : op.call.data };
  return { transactionHash, tx, receipt: { ...tx, status: 1, logs } };
}
function governanceReceipt(b, stage, opts = {}) {
  const op = operation(b, stage), batch = b.prepared.batch, plan = batch.plan;
  const tag = stage === 'execute' ? 300001 : 11, events = [];
  const common = [1n, batch.actionId, plan.actionClass, plan.targetCall.to, 0n, plan.governanceCall.selector,
    batch.callsHash, batch.scopeHash, batch.oldValueHash, batch.newValueHash];
  if (stage === 'publish') {
    if (!opts.repeat) events.push([A(5), 'GovernanceCallDataPublished', [1n, batch.publicationKey, pointer, op.caller]]);
  } else if (stage === 'schedule') {
    if (plan.kind === 'freeze') {
      events.push([A(5), 'TerminalFreezeActionMembershipUpdated', [1n, plan.transition.scopeHash, batch.actionId, governor, true, 1n, true, window.notBefore, 0n, 1n]]);
      events.push([A(5), 'TerminalFreezeGuardianConfigCommitted', [1n, batch.actionId, id('guardian commitment')]]);
    }
    events.push([A(5), 'GovernanceActionScheduled', [...common, window.notBefore, window.expiresAfter, batch.nonce,
      governor, window.reasonHash, window.reasonURI, window.manifestHash]]);
  } else {
    if (plan.kind === 'classifier') {
      events.push([A(5), 'FreezeSelectorUpdated', [1n, A(2), '0xaf55aad7', true, d.manager.codeHash, 1n, batch.actionId]]);
    } else {
      events.push([A(3), 'MintLedgerPhaseFrozen', [1n, A(2), scope.collectionId, scope.phaseId, base.policy.currentPolicyHash, base.configurationHash]]);
      events.push([A(2), 'MintPhaseFrozen', [1n, scope.collectionId, scope.phaseId, true, base.policy.currentPolicyHash]]);
    }
    events.push([A(5), 'GovernanceActionExecuted', [...common, caller, window.manifestHash]]);
  }
  if (stage !== 'publish') events.push([A(5), 'GovernanceActionPolicyValidated', [1n, batch.actionId, stage === 'schedule' ? 1n : 2n, id('profile'), id('catalog')]]);
  const env = envelope(op, tag, events, opts);
  const rpc = provider({ batch, state: (n, manager, identity) => phase(manager, identity, { frozen: stage === 'execute' && plan.kind === 'freeze' && n >= tag }),
    selector: n => selector(plan.kind === 'freeze' || (stage === 'execute' && n >= tag)),
    nonce: n => n >= tag && stage !== 'publish' ? 5n : 4n,
    status: n => opts.status?.(n) ?? (stage === 'execute' && n >= tag ? 3n : 1n),
    published: n => stage === 'publish' ? opts.repeat || n >= tag : true, read: opts.read, code: opts.code,
    timestamp: opts.timestamp, reorg: opts.reorg });
  rpc.getTransaction = async () => env.tx;
  rpc.getTransactionReceipt = async () => env.receipt;
  return { ...env, rpc, op, tag };
}
const inspect = (r, execution = 'direct') => flow.inspectMintPhaseFreezeReceipt(r.rpc, r.op, { transactionHash: r.transactionHash, execution });

test('captures configured policy, effective definitions, actual executor inventory and valid revision-zero catalog', async () => {
  const { capture } = await bundle();
  assert.equal(capture.catalog.revision, 0n);
  assert.equal(capture.phase.configurationHash, base.configurationHash);
  assert.deepEqual(capture.phase.policy.executors, base.policy.executors);
  assert.deepEqual(capture.phase.constraints.defined, [false, true]);
  assert.deepEqual(capture.phase.grace, grace);
  assert.equal(capture.catalog.rowAdmission, 'original-call-simulation-required');
  assert(Object.isFrozen(capture.phase.constraints.definitions[0]));
  assert(Object.isFrozen(capture.deployment.manager));
});

test('canonical freeze provenance stays distinct from current policy after removal and on unconfigured inheritance', async () => {
  const prior = id('original predecessor policy');
  for (const exists of [true, false]) {
    const p = provider({ state: (tag, manager, s) => phase(manager, s, { frozen: true, provenance: prior, executors: [A(10)], exists }) });
    const c = await flow.captureMintPhaseFreeze(p, d, scope, { blockTag: 10 });
    assert.equal(c.phase.snapshot.record.policyHash, prior);
    assert.equal(c.phase.policy === null, !exists);
    assert.deepEqual(c.phase.executorCeiling, [A(10)]);
    assert.throws(() => flow.prepareMintPhaseFreezeGovernance(c, 'freeze', governor, window), /already|frozen/i);
  }
});

test('configuration hash normalizes paused and only the original configured royalty wrapper', async () => {
  const regular = phase(A(2), scope, { royalty: true });
  const paused = phase(A(2), scope, { royalty: true, paused: true });
  assert.equal(regular.configurationHash, paused.configurationHash);
  const c = await flow.captureMintPhaseFreeze(provider({ state: () => paused }), d, scope, { blockTag: 10 });
  assert.equal(c.phase.configurationHash, regular.configurationHash);
  const bad = structuredClone(paused);
  bad.constraints.royalty.applicationConfigHash = id('wrong');
  await assert.rejects(flow.captureMintPhaseFreeze(provider({ state: () => bad }), d, scope, { blockTag: 10 }), /wrapper|royalty/i);
});

test('captures fail closed on wrong bindings, malformed RPC, bounds, missing phase and delegated dependency runtime', async () => {
  for (const [name, result, pattern] of [
    ['owner', [A(400)], /owner|governance/i], ['phaseExecutor', [false], /membership/],
    ['registeredPhasePolicyHash', [id('wrong')], /policy differs/], ['phasePolicyGrace', [ZeroHash, 0n], /grace/],
    ['frozenPhaseCount', [257n], /256/], ['phaseExecutors', [[A(10), A(10)]], /Duplicate/],
    ['phaseFreeze', [[id('partial'), ZeroHash]], /Partial/], ['phasePolicyHash', { raw: base.policy.currentPolicyHash + '00' }, /decode|length|Noncanonical/],
    ['minimumDelay', [172800n], /governance/]
  ]) await assert.rejects(flow.captureMintPhaseFreeze(provider({ read: n => n === name ? result : undefined }), d, scope, { blockTag: 10 }), pattern);
  const fresh = await flow.captureMintPhaseFreeze(provider({ state: () => phase(A(2), scope, { exists: false }), selector: () => selector(false) }), d, scope, { blockTag: 10 });
  assert.equal(flow.prepareMintPhaseFreezeGovernance(fresh, 'classifier', governor, window).batch.plan.actionClass, 0n);
  assert.equal(fresh.phase.policy, null);
  const classified = await flow.captureMintPhaseFreeze(provider({ state: () => phase(A(2), scope, { exists: false }) }), d, scope, { blockTag: 10 });
  assert.throws(() => flow.prepareMintPhaseFreezeGovernance(classified, 'freeze', governor, window), /nonzero|policy|hash/i);
  await assert.rejects(flow.captureMintPhaseFreeze(provider({ chainId: 1n }), d, scope, { blockTag: 10 }), /chain/);
  await assert.rejects(flow.captureMintPhaseFreeze(provider({ reorg: true }), d, scope, { blockTag: 10 }), /block changed/);
  const delegated = '0xef0100' + A(99).slice(2), changed = structuredClone(d);
  changed.manager.codeHash = keccak256(delegated);
  await assert.rejects(flow.captureMintPhaseFreeze(provider({ code: a => a === A(2) ? delegated : undefined }), changed, scope, { blockTag: 10 }), /runtime/);
  const boot = Array.from(coder.getDefaultValue(abi.getFunction('systemManifestBootstrapState').outputs));
  boot[0] = true;
  await assert.rejects(flow.captureMintPhaseFreeze(provider({ read: n => n === 'systemManifestBootstrapState' ? boot : undefined }), d, scope, { blockTag: 10 }), /sealed/);
});

test('mutable inputs snapshot before getNetwork and saved typed facts cannot collide', async () => {
  const dep = structuredClone(d), identity = { ...scope };
  const c = await flow.captureMintPhaseFreeze(provider({ mutate: () => { dep.manager.address = A(200); identity.phaseId = id('changed'); } }), dep, identity, { blockTag: 10 });
  assert.equal(c.deployment.manager.address, d.manager.address);
  assert.equal(c.scope.phaseId, scope.phaseId);
  const altered = structuredClone(c);
  altered.selector.revision = '1';
  assert.throws(() => flow.prepareMintPhaseFreezeGovernance(altered, 'freeze', governor, window), /capture facts changed/);
});

test('classifier is isolated class0, freeze is class2 and ordinary Safe calls target Executor', async () => {
  const c = await bundle('classifier'), f = await bundle();
  assert.equal(c.prepared.batch.plan.actionClass, 0n);
  assert.equal(c.prepared.batch.plan.targetCall.to, A(5));
  assert.equal(f.prepared.batch.plan.actionClass, 2n);
  assert.equal(f.prepared.batch.plan.targetCall.to, A(2));
  for (const b of [c, f]) for (const stage of ['publish', 'schedule', 'execute']) {
    const op = operation(b, stage);
    assert.equal(op.call.to, A(5));
    assert.equal(op.call.value, 0n);
  }
  assert.throws(() => flow.prepareMintPhaseFreezeGovernance(c.capture, 'freeze', governor, window), /Classify/);
  assert.throws(() => flow.prepareMintPhaseFreezeGovernance(f.capture, 'classifier', governor, window), /enabled|already/i);
  assert.throws(() => flow.prepareMintPhaseFreezeGovernance(f.capture, 'freeze', governor, { ...window, notBefore: 259200n }), /window|delay/i);
  const op = operation(f, 'execute');
  const safePlan = createSafeCallPlan(d.chainId, 'Execute reviewed phase freeze', [{ safe: op.caller, intent: 'Execute class2 terminal freeze', call: op.call, abi: fixture.abis.executor }]);
  assert.equal(safePlan.steps[0].transaction.operation, 0);
});

test('actual-caller simulations enforce publication, original72h schedule, guardian redundancy and stale action boundaries', async () => {
  const b = await bundle();
  for (const stage of ['publish', 'schedule']) {
    const op = operation(b, stage), result = await flow.simulateMintPhaseFreezeOperation(b.rpc, op, { blockTag: 10 });
    assert.equal(b.rpc.calls.at(-1).from, op.caller);
    assert.equal(result.returnData, stage === 'publish' ? abi.encodeFunctionResult('publishGovernanceCallData', [pointer]) : b.prepared.batch.actionId);
  }
  const exec = operation(b, 'execute');
  const valid = await flow.simulateMintPhaseFreezeOperation(provider({ batch: b.prepared.batch }), exec, { blockTag: 300001 });
  assert.equal(valid.guardianCommitment, id('guardian commitment'));
  for (const opts of [
    { read: n => n === 'isRoleRedundant' ? [false] : undefined },
    { read: n => n === 'governanceActionPolicyState' ? [id('profile'), id('changed'), 40n, 1n] : undefined },
    { status: () => 5n }, { timestamp: n => n === 300001 ? 1000001 : 1000 + n }
  ]) await assert.rejects(flow.simulateMintPhaseFreezeOperation(provider({ batch: b.prepared.batch, ...opts }), exec, { blockTag: 300001 }));
  await assert.rejects(flow.simulateMintPhaseFreezeOperation(provider({ batch: b.prepared.batch, published: () => false }), operation(b, 'schedule'), { blockTag: 10 }), /Publish/);
  await assert.rejects(flow.simulateMintPhaseFreezeOperation(provider({ batch: b.prepared.batch, nonce: () => 5n }), operation(b, 'schedule'), { blockTag: 11 }), /historical|nonce/);
  await assert.rejects(flow.simulateMintPhaseFreezeOperation(b.rpc, exec, { blockTag: 9 }), /predates/);
});

test('original direct and both Safe event layouts verify classifier, schedule and terminal freeze receipts', async () => {
  for (const kind of ['classifier', 'freeze']) {
    const b = await bundle(kind);
    for (const stage of ['publish', 'schedule', 'execute']) for (const layout of ['direct', 'plain', 'indexed']) {
      const r = governanceReceipt(b, stage, { safe: layout !== 'direct', indexed: layout === 'indexed' });
      const result = await inspect(r, layout === 'direct' ? 'direct' : 'safe');
      assert.equal(result.transactionHash, r.transactionHash);
      if (stage === 'execute' && kind === 'freeze') assert.deepEqual(result.events.slice(0, 2).map(v => v.event), ['MintLedgerPhaseFrozen', 'MintPhaseFrozen']);
    }
  }
});

test('publication retries need prior-block runtime and retained bytes; repeat freeze cannot hide missing events', async () => {
  const b = await bundle();
  await inspect(governanceReceipt(b, 'publish', { repeat: true }));
  const absent = governanceReceipt(b, 'publish');
  absent.receipt.logs = [];
  await assert.rejects(inspect(absent), /previous-block/);
  await assert.rejects(inspect(governanceReceipt(b, 'publish', { repeat: true, code: (a, n) => a === A(5) && n === 10 ? '0x' : undefined })), /runtime/);
  const freeze = governanceReceipt(b, 'execute');
  freeze.receipt.logs = freeze.receipt.logs.filter(v => v.address !== A(3));
  await assert.rejects(inspect(freeze), /MintLedgerPhaseFrozen/);
});

test('receipt exact event order, Safe envelope/success and class2 veto status are enforced', async () => {
  const b = await bundle();
  for (const status of [1n, 2n, 5n]) await inspect(governanceReceipt(b, 'schedule', { status: () => status }));
  for (const status of [3n, 4n]) await assert.rejects(inspect(governanceReceipt(b, 'schedule', { status: () => status })), /Scheduled action/);
  const reordered = governanceReceipt(b, 'execute');
  [reordered.receipt.logs[0], reordered.receipt.logs[1]] = [reordered.receipt.logs[1], reordered.receipt.logs[0]];
  reordered.receipt.logs.forEach((v, n) => { v.index = n; });
  await assert.rejects(inspect(reordered), /order/);
  const badSafe = governanceReceipt(b, 'execute', { safe: true });
  badSafe.receipt.logs.pop();
  await assert.rejects(inspect(badSafe, 'safe'), /Safe requires/);
  const delegate = governanceReceipt(b, 'execute', { safe: true });
  const decoded = [...safe.decodeFunctionData('execTransaction', delegate.tx.data)];
  decoded[3] = 1n;
  delegate.tx.data = safe.encodeFunctionData('execTransaction', decoded);
  await assert.rejects(inspect(delegate, 'safe'), /ordinary/);
  const noncanonical = governanceReceipt(b, 'execute');
  noncanonical.receipt.logs[0].data += '00';
  await assert.rejects(inspect(noncanonical), /Noncanonical|data/);
});

async function importBundle(options = {}) {
  const count = options.count ?? 2;
  const identities = Array.from({ length: count }, (_, i) => ({ collectionId: scope.collectionId, phaseId: id('import phase:' + i) }));
  const source = identities.map(s => phase(predecessor, s, { frozen: true, provenance: id('source first:' + s.phaseId) }));
  const successor = identities.map((s, n) => phase(A(2), s, {
    exists: options.configured ?? false, frozen: options.preexisting ?? false,
    provenance: id('successor own first:' + n), executors: [A(10)],
    configHash: options.incompatibleSecond && n === 1 ? id('incompatible') : undefined
  }));
  const initial = options.progress ?? 0n;
  // Already-copied records may be unconfigured; their inherited ceiling is nevertheless complete.
  for (let n = 0; n < Number(initial); n++) {
    successor[n] = phase(A(2), identities[n], { exists: options.configured ?? false,
      record: source[n].record, ceiling: options.configured ? [A(10)] : source[n].ceiling, executors: [A(10)] });
  }
  const state = (tag, manager, identity) => {
    const index = identities.findIndex(s => s.phaseId === identity.phaseId);
    return manager === predecessor ? source[index] : successor[index];
  };
  const inventory = (tag, manager) => manager === predecessor ? identities : identities.filter((_, n) => successor[n].record.configurationHash !== ZeroHash);
  const rpcOptions = { state, inventory, progress: () => initial, ...options.rpc };
  const rpc = provider(rpcOptions);
  const capture = await flow.captureMintPhaseFreezeImport(rpc, d, importScope, { blockTag: 10 });
  return { options, rpcOptions, rpc, capture, identities, source, successor };
}
function importReceipt(b, count = 1n, opts = {}) {
  const op = flow.prepareMintPhaseFreezeImportOperation(b.capture, caller, count), tag = 12;
  const expected = b.capture.next.slice(0, Number(count));
  const progressAfter = b.capture.progress.freezes.imported + BigInt(opts.laterCopied ?? expected.length);
  const after = b.successor.map((s, n) => {
    if (BigInt(n) >= progressAfter) return s;
    const input = b.source[n];
    return phase(A(2), b.identities[n], { exists: opts.laterConfigure || s.exists,
      record: s.record.configurationHash === ZeroHash ? input.record : s.record,
      executors: s.exists || opts.laterConfigure ? [A(10)] : s.policy.executors,
      ceiling: s.exists || opts.laterConfigure ? [A(10)] : input.ceiling });
  });
  const events = expected.map(row => [A(3), 'MintLedgerPhaseFreezeImported', [importScope.importRoot, predecessor, A(2),
    row.predecessor.scope.collectionId, row.predecessor.scope.phaseId, row.predecessor.snapshot.record.policyHash,
    row.successor.snapshot.currentPolicyHash, row.predecessor.snapshot.record.configurationHash]]);
  const env = envelope(op, tag, events, opts);
  const rpc = provider({ ...b.rpcOptions,
    state: (n, manager, identity) => {
      const index = b.identities.findIndex(s => s.phaseId === identity.phaseId);
      return manager === predecessor ? b.source[index] : n >= tag ? after[index] : b.successor[index];
    },
    inventory: (n, manager) => manager === predecessor ? b.identities : b.identities.filter((_, i) => (n >= tag ? after : b.successor)[i].record.configurationHash !== ZeroHash),
    progress: n => n >= tag ? progressAfter : b.capture.progress.freezes.imported,
    read: opts.read, code: opts.code, commitment: opts.commitment
  });
  rpc.getTransaction = async () => env.tx;
  rpc.getTransactionReceipt = async () => env.receipt;
  return { ...env, rpc, op, tag, after };
}
const inspectImport = (r, execution = 'direct') => flow.inspectMintPhaseFreezeImportReceipt(r.rpc, r.op, { transactionHash: r.transactionHash, execution });

test('original same-Ledger import captures immutable root, retirement, progress and at most32 candidate rows', async () => {
  const b = await importBundle({ count: 33 });
  assert.equal(b.capture.progress.freezes.required, 33n);
  assert.equal(b.capture.next.length, 32);
  assert.equal(b.capture.next[0].successor.policy, null);
  assert.equal(b.capture.next[0].predecessor.snapshot.record.policyHash, b.source[0].record.policyHash);
  assert.equal(b.capture.successorReady, false);
  for (const maxCount of [0n, 33n]) assert.throws(() => flow.prepareMintPhaseFreezeImportOperation(b.capture, caller, maxCount), /1|32|bound/);
  const op = flow.prepareMintPhaseFreezeImportOperation(b.capture, caller, 1n);
  assert.equal(op.call.to, d.ledger.address);
  assert.equal(op.call.data, abi.encodeFunctionData('importPhaseFreezes', [importScope.importRoot, 1n]));
  const simulated = await flow.simulateMintPhaseFreezeImport(b.rpc, op, { blockTag: 10 });
  assert.equal(simulated.returnData, '0x');
  assert.equal(b.rpc.calls.at(-1).from, caller);
  const plan = createSafeCallPlan(d.chainId, 'Copy original freeze continuity', [{ safe: caller, intent: 'Copy one retained freeze', call: op.call, abi: fixture.abis.ledger }]);
  assert.equal(plan.steps[0].transaction.operation, 0);
});

test('incompatible second successor does not prevent original maxCount1; selected maxCount2 fails before await', async () => {
  const b = await importBundle({ configured: true, incompatibleSecond: true });
  const one = flow.prepareMintPhaseFreezeImportOperation(b.capture, caller, 1n);
  await flow.simulateMintPhaseFreezeImport(b.rpc, one, { blockTag: 10 });
  assert.throws(() => flow.prepareMintPhaseFreezeImportOperation(b.capture, caller, 2n), /configuration incompatible/);
});

test('completion is distinct from current writer readiness and cannot permit a further copy', async () => {
  for (const [writer, retired] of [[false, 0n], [true, 9n], [true, 0n]]) {
    const b = await importBundle({ count: 1, progress: 1n, rpc: {
      commitment: () => ({ complete: true }), writer: () => writer, retired: () => retired
    } });
    assert.equal(b.capture.commitment.complete, true);
    assert.equal(b.capture.successorReady, writer && retired === 0n);
    assert.throws(() => flow.prepareMintPhaseFreezeImportOperation(b.capture, caller, 1n), /complete|retired/);
  }
  await assert.rejects(importBundle({ rpc: { read: name => name === 'isMintSuccessorReady' ? [true] : undefined } }), /readiness/);
});

test('copy receipt joins unconfigured and configured successor policies, preserves own first record, and supports both Safe layouts', async () => {
  for (const profile of [{}, { configured: true }, { configured: true, preexisting: true }]) {
    const b = await importBundle(profile);
    for (const layout of ['direct', 'plain', 'indexed']) {
      const r = importReceipt(b, 1n, { safe: layout !== 'direct', indexed: layout === 'indexed' });
      const result = await inspectImport(r, layout === 'direct' ? 'direct' : 'safe');
      assert.deepEqual(result.copiedOrdinals, [0n]);
      assert.equal(result.observed.progress.freezes.imported, 1n);
      assert.equal(result.events[0].event, 'MintLedgerPhaseFreezeImported');
      if (profile.preexisting) assert.equal(r.after[0].record.policyHash, b.successor[0].record.policyHash);
      else assert.equal(r.after[0].record.policyHash, b.source[0].record.policyHash);
    }
  }
});

test('copy events attribute only selected rows while later block copying/configuration remains an observation', async () => {
  const b = await importBundle({ count: 2 });
  const r = importReceipt(b, 1n, { laterCopied: 2, laterConfigure: true });
  const result = await inspectImport(r);
  assert.deepEqual(result.copiedOrdinals, [0n]);
  assert.equal(result.observed.progress.freezes.imported, 2n);
  assert.equal(result.observed.successorInventory.length, 2);
  assert.match(result.stateAttribution, /end-of-block/);
});

test('eventless copy retries require previous-block fully copied incomplete root and exact canonical history', async () => {
  const b = await importBundle({ count: 1, progress: 1n });
  const result = await inspectImport(importReceipt(b));
  assert.deepEqual(result.copiedOrdinals, []);
  assert.equal(result.events.length, 0);
  const missingPrior = importReceipt(b, 1n, { read: (name, args, tx) => name === 'mintImportFreezeProgress' && tx.blockTag === 11 ? [0n, 1n] : undefined });
  await assert.rejects(inspectImport(missingPrior), /prior-block/);
  const wrongRuntime = importReceipt(b, 1n, { code: (a, n) => a === A(3) && n === 11 ? '0x' : undefined });
  await assert.rejects(inspectImport(wrongRuntime), /runtime/);
  const laterComplete = importReceipt(b, 1n, { commitment: n => ({ complete: n >= 12 }) });
  await assert.rejects(inspectImport(laterComplete), /incomplete/);
});

test('import bounds, root/bindings, retirement, stale progress and malformed or wrong events fail closed', async () => {
  for (const rpc of [
    { commitment: () => ({ predecessorLedger: A(30) }) },
    { commitment: () => ({ snapshotBlock: 4n }) },
    { read: name => name === 'mintImportFreezeProgress' ? [2n, 1n] : undefined },
    { read: name => name === 'frozenPhaseCount' ? [257n] : undefined }
  ]) await assert.rejects(importBundle({ rpc }));
  const b = await importBundle();
  const op = flow.prepareMintPhaseFreezeImportOperation(b.capture, caller, 1n);
  await assert.rejects(flow.simulateMintPhaseFreezeImport(provider({ ...b.rpcOptions, progress: n => n > 10 ? 1n : 0n }), op, { blockTag: 11 }), /facts changed/);
  const forged = structuredClone(op);
  forged.capture.next[0].predecessor.snapshot.record.policyHash = id('forged');
  await assert.rejects(flow.simulateMintPhaseFreezeImport(b.rpc, forged, { blockTag: 10 }), /capture facts changed/);
  const missing = importReceipt(b);
  missing.receipt.logs = [];
  await assert.rejects(inspectImport(missing), /Copy event count/);
  const wrong = importReceipt(b);
  const log = wrong.receipt.logs[0], decoded = [...abi.decodeEventLog('MintLedgerPhaseFreezeImported', log.data, log.topics)];
  decoded[6] = id('wrong successor policy');
  Object.assign(log, abi.encodeEventLog(abi.getEvent('MintLedgerPhaseFreezeImported'), decoded));
  await assert.rejects(inspectImport(wrong), /copy event fields/);
  const early = importReceipt(b, 1n, { safe: true });
  early.receipt.logs.reverse().forEach((v, n) => { v.index = n; });
  await assert.rejects(inspectImport(early, 'safe'), /Safe success/);
});
