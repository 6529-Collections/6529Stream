import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as pure from '../dist/current-mint-counter-reads.js';
import { inspectMintCounterRead } from '../dist/current-mint-counter-reads-workflow.js';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/current-mint-counter-reads-abi.json', import.meta.url), 'utf8'));
const managerAbi = new Interface(fixture.abis.manager), ledgerAbi = new Interface(fixture.abis.ledger);
const policyAbi = new Interface(fixture.abis.counterPolicyInterface), coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress('0x' + BigInt(n).toString(16).padStart(40, '0'));
const code = n => '0x60' + n.toString(16).padStart(2, '0');
const pin = n => ({ address: A(n), codeHash: keccak256(code(n)) });
const deployment = { chainId: 6529n, manager: pin(1), ledger: pin(2) };
const binding = { chainId: deployment.chainId, manager: A(1), ledger: A(2) };
const caller = A(99), phaseId = id('phase'), counterId = id('counter');
const MAX64 = (1n << 64n) - 1n, MAX256 = (1n << 256n) - 1n;
const hashBlock = n => id('block:' + n);
const scope = { collectionId: 77n, phaseId, counterId };
const context = { ...scope, payer: A(3), initialRecipient: A(4), beneficiary: A(5), executor: A(6), authorizer: A(7),
  tokenIndex: 1n, contextHash: id('context'), resolverData: '0x' };
const config = { enabled: true, keyMode: 2n, capMode: 1n, deltaMode: 0n, staticCap: 100n, staticIncrement: 3n, counterConfigHash: id('configuration') };
const definition = { scope: 2n, keyMode: 2n, capRoot: ZeroHash, metadataHash: id('definition') };
const basePolicy = { phaseExists: true, config, definitionExists: true, definition };
const phaseConfig = { paused: true, startTime: 1n, endTime: 2n, maxBatchQuantity: 10n, configHash: id('phase terms'), metadataHash: id('metadata') };
const fields = ['collectionId', 'phaseId', 'counterId', 'payer', 'initialRecipient', 'beneficiary', 'executor', 'authorizer', 'tokenIndex', 'contextHash', 'resolverData'];
const fromTuple = tuple => Object.fromEntries(fields.map((name, i) => [name, tuple[i]]));

function provider(options = {}) {
  const calls = [], blocks = new Map();
  const observedPolicy = options.policy ?? basePolicy;
  const originalPolicy = options.originalPolicy ?? observedPolicy;
  return {
    calls,
    async getNetwork() { options.mutate?.(); return { chainId: options.chainId ?? deployment.chainId }; },
    async getBlock(tag) {
      blocks.set(tag, (blocks.get(tag) ?? 0) + 1);
      return { number: options.blockNumber ?? tag, timestamp: 5000,
        hash: options.reorg && blocks.get(tag) > 1 ? id('reorg') : hashBlock(tag) };
    },
    async getCode(target, tag) {
      return options.code?.(target, tag) ?? code(Number(BigInt(target)));
    },
    async call(tx) {
      calls.push(tx);
      const ledger = tx.to === A(2), codec = ledger ? ledgerAbi : managerAbi;
      const parsed = codec.parseTransaction({ data: tx.data }), name = parsed.name, args = Array.from(parsed.args);
      const changed = options.read?.(name, args, tx, ledger);
      if (changed?.raw !== undefined) return changed.raw;
      if (changed !== undefined) return codec.encodeFunctionResult(parsed.fragment, changed);
      const current = options.current ?? 5n;
      let result;
      if (ledger) {
        switch (name) {
          case 'isStreamMintLedger': result = [true]; break;
          case 'supportsInterface': {
            if (options.probeError) throw options.probeError;
            if (options.probe !== undefined) return options.probe;
            result = [true]; break;
          }
          case 'counterDefinitionForManager':
            assert.equal(args[0], A(1));
            assert.equal(args[1], observedPolicy.config.counterConfigHash);
            result = [observedPolicy.definitionExists, observedPolicy.definition]; break;
          case 'counterValue': result = [current]; break;
          case 'deriveCounterValueKey':
            result = [keccak256(coder.encode(['bytes32', 'address', 'uint256', 'bytes32', 'bytes32', 'bytes32'],
              [id('6529STREAM_MINT_COUNTER_VALUE_KEY_V1'), ...args]))]; break;
          default: throw Error('Unexpected Ledger call ' + name);
        }
      } else {
        switch (name) {
          case 'mintLedger': result = [A(2)]; break;
          case 'isStreamMintManager': case 'supportsInterface': result = [true]; break;
          case 'phase': result = [observedPolicy.phaseExists, phaseConfig]; break;
          case 'counterConfig': result = [observedPolicy.config]; break;
          case 'previewCounterValueKey':
            result = [pure.mintCounterReadValueKey(binding, originalPolicy,
              { collectionId: args[0], phaseId: args[1], counterId: args[2], subjectKey: args[3] })]; break;
          case 'rawCounterValue': case 'counterValue': result = [options.originalCurrent ?? current]; break;
          case 'remainingForCounter': result = [pure.mintCounterProoflessRemaining(originalPolicy, current)]; break;
          case 'resolveCounter': case 'remainingForResolvedCounter': {
            const r = pure.resolveMintCounterRead(binding, originalPolicy, fromTuple(args[0]));
            result = name === 'resolveCounter' ? [r.resolution]
              : [r.resolution, current, pure.mintCounterReadRemaining(originalPolicy.config.capMode, r.resolution.effectiveCap, current)];
            break;
          }
          default: throw Error('Unexpected Manager call ' + name);
        }
      }
      return codec.encodeFunctionResult(parsed.fragment, result);
    }
  };
}
const requestCall = request => pure.prepareMintCounterReadCall(A(1), caller, request);
async function inspect(request, options = {}) {
  const rpc = provider(options), prepared = requestCall(request);
  return { rpc, result: await inspectMintCounterRead(rpc, deployment, prepared, { blockTag: 12 }) };
}
const scalar = (method, subjectKey = id('explicit subject')) => ({ method, ...scope, subjectKey });
const resolved = (method = 'remainingForResolvedCounter', x = context) => ({ method, context: x });

test('all five accounting views retain exact call/context/pins and do not require mint eligibility', async () => {
  for (const request of [{ method: 'rawCounterValue', valueKey: id('explicit value') }, scalar('counterValue'),
    scalar('remainingForCounter'), resolved('resolveCounter'), resolved()]) {
    const { rpc, result } = await inspect(request);
    assert.equal(result.accountingOnly, true);
    assert.equal(result.current, 5n);
    assert.equal(result.prepared.caller, caller);
    assert.equal(rpc.calls.at(-1).from, caller);
    assert.equal(rpc.calls.at(-1).blockTag, 12);
    assert.deepEqual(result.deployment, deployment);
    assert(Object.isFrozen(result.deployment.manager));
    if (request.method !== 'rawCounterValue') {
      assert.equal(result.phase.paused, true);
      assert(Object.isFrozen(result.policy.config));
      assert.equal(result.definition.scope, 'direct-ledger-observation');
      assert.equal(result.definition.noNestedGasEquivalence, true);
    }
    const names = rpc.calls.map(tx => (tx.to === A(2) ? ledgerAbi : managerAbi).parseTransaction({ data: tx.data }).name);
    assert(!names.some(n => /Artist|Writer|owner|governance|phaseExecutor|canMint|OperationNonce/.test(n)));
  }
});

test('raw explicit keys include zero and never infer a subject, phase or another Manager domain', async () => {
  for (const valueKey of [ZeroHash, id('any original ledger key')]) {
    const { rpc, result } = await inspect({ method: 'rawCounterValue', valueKey });
    assert.equal(result.valueKey, valueKey);
    assert.equal(result.value, 5n);
    assert.equal(result.policy, null);
    assert.equal(result.resolution, null);
    assert.equal(result.remaining, null);
    assert(!rpc.calls.some(tx => tx.data.startsWith(policyAbi.getFunction('counterDefinitionForManager').selector)));
  }
});

test('scoped PHASE/COLLECTION/GLOBAL values preserve actual Manager and original CONSTANT pre-scope resolution', async () => {
  const keys = [];
  for (const mode of [2n, 1n, 0n]) {
    const policy = { ...basePolicy, config: { ...config, keyMode: 1n }, definition: { ...definition, scope: mode, keyMode: 1n } };
    const { result } = await inspect(resolved(), { policy });
    assert.equal(result.scopedCollectionId, mode === 0n ? 0n : scope.collectionId);
    assert.equal(result.scopedPhaseId, mode === 2n ? phaseId : ZeroHash);
    if (mode !== 2n) assert.notEqual(result.preScopeSubjectKey, result.resolution.subjectKey);
    keys.push(result.valueKey);
  }
  assert.equal(new Set(keys).size, 3);
});

test('beneficiary/executor/authorizer are supplied hash context, independent of read caller and temporary recipient', async () => {
  for (const keyMode of [2n, 3n, 4n, 5n]) {
    const policy = { ...basePolicy, config: { ...config, keyMode }, definition: { ...definition, keyMode } };
    const { result } = await inspect(resolved(), { policy });
    const changedInitial = await inspect(resolved('resolveCounter', { ...context, initialRecipient: A(100) }), { policy });
    assert.deepEqual(changedInitial.result.resolution, result.resolution);
    assert.notEqual(context.executor, caller);
    assert.notEqual(context.beneficiary, context.initialRecipient);
    const expectedAddress = ({ 2: context.payer, 3: context.beneficiary, 4: context.executor, 5: context.authorizer })[Number(keyMode)];
    const subject = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'uint8', 'address'],
      [id('6529STREAM_MINT_COUNTER_SUBJECT_V1'), binding.chainId, A(2), keyMode, expectedAddress]));
    assert.equal(result.resolution.subjectKey, subject);
  }
});

test('CONTEXT uses batch sentinel and counts counter consumptions; token-index and subject errors reject', async () => {
  const policy = { ...basePolicy, config: { ...config, keyMode: 6n }, definition: { ...definition, keyMode: 6n } };
  const x = { ...context, tokenIndex: MAX256 };
  const { result } = await inspect(resolved('remainingForResolvedCounter', x), { policy });
  assert.equal(result.consumptionUnit, 'per-batch');
  assert.equal(result.remainingConsumptions, 31n);
  await assert.rejects(inspect(resolved(), { policy }), /index|sentinel/i);
  await assert.rejects(inspect(resolved('resolveCounter', { ...x, contextHash: ZeroHash }), { policy }), /subject|context/i);
  await assert.rejects(inspect(resolved('resolveCounter', { ...context, tokenIndex: 10n })), /index|bound/i);
  await assert.rejects(inspect(resolved('resolveCounter', { ...context, payer: ZeroAddress })), /subject|address|missing/i);
});

test('STATIC saturation and NONE storage headroom have distinct remaining meanings', async () => {
  for (const current of [99n, 100n, 101n, MAX64]) {
    const { result } = await inspect(scalar('remainingForCounter'), { current });
    assert.equal(result.remaining, current < 100n ? 100n - current : 0n);
    assert.equal(result.remainingMeaning, 'verified-counter-cap');
  }
  const policy = { ...basePolicy, config: { ...config, capMode: 0n, staticCap: 0n }, definitionExists: false };
  for (const current of [0n, MAX64 - 1n, MAX64]) {
    const { result } = await inspect(scalar('remainingForCounter'), { policy, current });
    assert.equal(result.remaining, MAX64 - current);
    assert.equal(result.remainingMeaning, 'uint64-storage-headroom');
  }
});

const PROOF = '(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)';
function leaf(x, proof) {
  const inner = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'uint256', 'bytes32', 'bytes32', 'address', 'uint64', 'bool', 'uint256'],
    [id('6529STREAM_MINT_ALLOWLIST_LEAF_V1'), binding.chainId, binding.manager, x.collectionId, x.phaseId, x.counterId,
      x.payer, proof.maxCount, proof.hasPriceOverride, proof.priceOverride]));
  return keccak256(inner);
}
function merkle() {
  const first = { maxCount: 7n, hasPriceOverride: false, priceOverride: 0n, proof: [] };
  const second = { maxCount: 11n, hasPriceOverride: true, priceOverride: 999n, proof: [] };
  const a = leaf(context, first), b = leaf(context, second);
  const root = keccak256(coder.encode(['bytes32', 'bytes32'], [a, b].sort()));
  first.proof = [b]; second.proof = [a];
  const policy = { ...basePolicy, config: { ...config, capMode: 3n }, definition: { ...definition, capRoot: root } };
  return { policy, proofs: [first, second] };
}
test('single canonical Merkle leaf caps select different allowances for the same subject without interpreting prices', async () => {
  const { policy, proofs } = merkle(), results = [];
  for (const proof of proofs) {
    const { result } = await inspect(resolved('remainingForResolvedCounter', { ...context, resolverData: coder.encode([PROOF], [proof]) }), { policy });
    results.push(result);
    assert.equal(result.resolution.effectiveCap, proof.maxCount);
    assert.equal(result.remaining, proof.maxCount - 5n);
  }
  assert.equal(results[0].valueKey, results[1].valueKey);
  assert.notEqual(results[0].resolution.resolutionHash, results[1].resolution.resolutionHash);
  await assert.rejects(inspect(scalar('remainingForCounter'), { policy }), /proof/i);
});

test('Merkle proof invalidity, undeclared price, overflow ceiling and noncanonical single-proof bytes never fall back', async () => {
  const { policy, proofs } = merkle();
  for (const proof of [
    { ...proofs[0], proof: [id('wrong sibling')] }, { ...proofs[0], maxCount: 0n },
    { ...proofs[0], maxCount: 101n }, { ...proofs[0], hasPriceOverride: false, priceOverride: 1n }
  ]) await assert.rejects(inspect(resolved('resolveCounter', { ...context, resolverData: coder.encode([PROOF], [proof]) }), { policy }));
  for (const resolverData of ['0x', coder.encode([PROOF], [proofs[0]]) + '00', '0xdeadbeef']) {
    await assert.rejects(inspect(resolved('resolveCounter', { ...context, resolverData }), { policy }));
  }
  for (const name of ['collectionId', 'phaseId', 'counterId', 'payer']) {
    const wrong = { ...context, resolverData: coder.encode([PROOF], [proofs[0]]), [name]: name === 'collectionId' ? 78n : name === 'payer' ? A(100) : id('other') };
    await assert.rejects(inspect(resolved('resolveCounter', wrong), { policy }), /proof/i);
  }
});

test('non-Merkle resolver bytes are retained but ignored and absent definition overrides only scope', async () => {
  const policy = { ...basePolicy, definitionExists: false,
    definition: { scope: 0n, keyMode: 5n, capRoot: id('raw retained'), metadataHash: id('raw metadata') } };
  const first = await inspect(resolved('resolveCounter', { ...context, resolverData: '0xdeadbeef' }), { policy });
  const second = await inspect(resolved('resolveCounter'), { policy });
  assert.deepEqual(first.result.resolution, second.result.resolution);
  assert.equal(first.result.scopedPhaseId, phaseId);
  assert.deepEqual(first.result.definition.returnedDefinition, policy.definition);
  assert.deepEqual(first.result.definition.candidateDefinition, { ...policy.definition, scope: 2n });
});

test('optional policy capability fallback preserves source behavior while network errors and dishonest results reject', async () => {
  const legacy = { ...basePolicy, definitionExists: false, definition: { scope: 2n, keyMode: 0n, capRoot: ZeroHash, metadataHash: ZeroHash } };
  for (const [opts, expected] of [
    [{ probe: coder.encode(['bool'], [false]) }, 'legacy-not-supported'],
    [{ probe: '0x1234' }, 'legacy-noncanonical'],
    [{ probe: coder.encode(['uint256'], [2n]) }, 'legacy-noncanonical'],
    [{ probeError: Object.assign(Error('execution reverted'), { code: 'CALL_EXCEPTION' }) }, 'legacy-call-reverted']
  ]) {
    const { result, rpc } = await inspect(resolved(), { ...opts, originalPolicy: legacy });
    assert.equal(result.definition.probe, expected);
    assert.equal(result.definition.noNestedGasEquivalence, true);
    assert(!rpc.calls.some(tx => tx.data.startsWith(policyAbi.getFunction('counterDefinitionForManager').selector)));
  }
  await assert.rejects(inspect(resolved(), { probeError: Object.assign(Error('network failed'), { code: 'NETWORK_ERROR' }) }), /network/);
  await assert.rejects(inspect(resolved(), { probe: '0x' + '00'.repeat(4097) }), /oversized/);
  const global = { ...basePolicy, definition: { ...definition, scope: 0n } };
  await assert.rejects(inspect(resolved(), { policy: global, originalPolicy: legacy }), /key differs/);
});

test('canonical four/six-word return joins and scalar64-bit words reject contradictions and trailing bytes', async () => {
  for (const [request, read] of [
    [scalar('counterValue'), (name, args, tx, ledger) => !ledger && name === 'counterValue' ? [6n] : undefined],
    [resolved('resolveCounter'), name => name === 'resolveCounter' ? [{ subjectKey: id('wrong'), effectiveCap: 100n, increment: 3n, resolutionHash: id('wrong') }] : undefined],
    [resolved(), name => name === 'remainingForResolvedCounter' ? [pure.resolveMintCounterRead(binding, basePolicy, context).resolution, 6n, 95n] : undefined],
    [scalar('counterValue'), (name, args, tx, ledger) => ledger && name === 'counterValue' ? { raw: coder.encode(['uint256'], [MAX64 + 1n]) } : undefined],
    [resolved(), name => name === 'remainingForResolvedCounter' ? { raw: '0x' + '00'.repeat(193) } : undefined]
  ]) await assert.rejects(inspect(request, { read }));
  await assert.rejects(inspect(resolved(), { read: name => name === 'phase' ? { raw: coder.encode(['uint256'], [2n]) + '00'.repeat(192) } : undefined }), /Noncanonical/);
});

test('phase/counter guards, exact pins, pre-await snapshots, caller separation and block rechecks remain strict', async () => {
  await assert.rejects(inspect(resolved(), { policy: { ...basePolicy, phaseExists: false } }), /phase does not exist/);
  await assert.rejects(inspect(resolved(), { policy: { ...basePolicy, config: { ...config, enabled: false } } }), /not enabled/);
  await assert.rejects(inspect(resolved(), { chainId: 1n }), /chain/);
  await assert.rejects(inspect(resolved(), { read: name => name === 'mintLedger' ? [A(100)] : undefined }), /dependency/);
  await assert.rejects(inspect(resolved(), { reorg: true }), /block changed/);
  await assert.rejects(inspect(resolved(), { blockNumber: 13 }), /mismatched block/);
  const dep = structuredClone(deployment), call = structuredClone(requestCall(resolved()));
  const rpc = provider({ mutate: () => { dep.manager.address = A(200); call.request.context.executor = A(201); } });
  const observed = await inspectMintCounterRead(rpc, dep, call, { blockTag: 12 });
  assert.equal(observed.deployment.manager.address, A(1));
  assert.equal(observed.prepared.request.context.executor, context.executor);
  assert(Object.isFrozen(observed.prepared.request.context));
  const delegatedCode = '0xef0100' + A(100).slice(2), delegated = structuredClone(deployment);
  delegated.manager.codeHash = keccak256(delegatedCode);
  await assert.rejects(inspectMintCounterRead(provider({ code: a => a === A(1) ? delegatedCode : undefined }), delegated, requestCall(resolved()), { blockTag: 12 }), /runtime/);
  const changed = structuredClone(requestCall(resolved()));
  changed.caller = A(100);
  // Caller can differ from every supplied role; changing retained request/call labels still requires exact reconstruction.
  const validOtherCaller = pure.prepareMintCounterReadCall(A(1), A(100), resolved());
  assert.equal((await inspectMintCounterRead(provider(), deployment, validOtherCaller, { blockTag: 12 })).prepared.caller, A(100));
  const zeroCaller = pure.prepareMintCounterReadCall(A(1), ZeroAddress, resolved());
  assert.equal((await inspectMintCounterRead(provider(), deployment, zeroCaller, { blockTag: 12 })).prepared.caller, ZeroAddress);
  changed.request.context.executor = A(200);
  await assert.rejects(inspectMintCounterRead(provider(), deployment, changed, { blockTag: 12 }));
});

test('coincident PHASE accounting does not turn a direct supported observation into nested-gas branch evidence', async () => {
  const legacy = { ...basePolicy, definitionExists: false,
    definition: { scope: 2n, keyMode: 0n, capRoot: ZeroHash, metadataHash: ZeroHash } };
  const { result } = await inspect(resolved(), { originalPolicy: legacy });
  assert.equal(result.definition.probe, 'supported');
  assert.equal(result.definition.exists, true);
  assert.equal(result.definition.scope, 'direct-ledger-observation');
  assert.equal(result.definition.noNestedGasEquivalence, true);
  assert.deepEqual(result.resolution, pure.resolveMintCounterRead(binding, legacy, context).resolution);
});

test('dynamic byte client bounds apply before awaits and original Manager errors never become a ceiling fallback', async () => {
  const { result } = await inspect(resolved('resolveCounter', { ...context, resolverData: '0x' + 'ff'.repeat(8192) }));
  assert.equal(result.resolution.effectiveCap, 100n);
  let invoked = false;
  const rpc = provider({ mutate: () => { invoked = true; } });
  const oversized = requestCall(resolved('resolveCounter', { ...context, resolverData: '0x' + 'ff'.repeat(8193) }));
  await assert.rejects(inspectMintCounterRead(rpc, deployment, oversized, { blockTag: 12 }), /oversized/);
  assert.equal(invoked, false);
  const forged = structuredClone(requestCall(resolved()));
  forged.call.data = '0x' + '00'.repeat(16385);
  await assert.rejects(inspectMintCounterRead(rpc, deployment, forged, { blockTag: 12 }), /oversized/);
  assert.equal(invoked, false);
  await assert.rejects(inspect(resolved(), { read: name => {
    if (name === 'remainingForResolvedCounter') throw Object.assign(Error('original Manager rejected proof'), { code: 'CALL_EXCEPTION' });
  } }), /original Manager rejected/);
});
