import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from 'ethers';
import * as pure from '../dist/current-metadata-citation.js';
import * as workflow from '../dist/current-metadata-citation-workflow.js';
import { createSafeCallPlan } from '../dist/safe-plan.js';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/current-metadata-citation-abi.json', import.meta.url)));
const abi = new Interface(['registry', 'currentRegistry', 'currentRenderer', 'schemaRegistry', 'documentFacts', 'store', 'executor'].flatMap(key => fixture.abis[key]).filter(f => ['function', 'event'].includes(f.type)));
const registryAbi = new Interface(fixture.abis.registry), rendererAbi = new Interface(fixture.abis.currentRenderer);
const coder = AbiCoder.defaultAbiCoder();
const a = n => getAddress(`0x${n.toString(16).padStart(40, '0')}`);
const code = '0x600060005260206000f3';
const pin = n => ({ address: a(n), codeHash: keccak256(code) });
const clone = value => structuredClone(value);
const safeAbi = new Interface([
  'function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)',
  'event ExecutionSuccess(bytes32 txHash,uint256 payment)', 'event ExecutionFailure(bytes32 txHash,uint256 payment)',
]);

// Compiled-ABI RPC fixture. Original governance eth_call is stubbed; these tests prove client
// joins and boundaries, not native execution, nested STATICCALL gas or release acceptance.
function setup(options = {}) {
  const deployment = { chainId: 1n, registry: pin(1), schemaRegistry: pin(2), store: pin(3), governance: pin(4), renderer: pin(5), encoding: pin(6) };
  const versionKey = id('renderer-version');
  const targets = [{ target: a(6), codeHash: keccak256(code), role: id('METADATA_COMPANION') }, { target: a(7), codeHash: keccak256(code), role: id('CORE') }];
  const originalReads = [{ targetIndex: 1n, selector: '0x12345678', maxReturnBytes: 32n, exact: true }];
  const reads = [{ targetIndex: 0n, selector: '0x55bbfc11', maxReturnBytes: 16777216n, exact: false }, ...originalReads];
  if (options.maxReads) reads.unshift(...Array.from({ length: 126 }, (_, i) => ({ targetIndex: 0n,
    selector: `0x${(i + 1).toString(16).padStart(8, '0')}`, maxReturnBytes: 32n, exact: true })));
  const originalVersion = { exists: true, deprecated: false, renderer: a(5), runtimeHash: keccak256(code), registrationHash: id('original-registration'),
    readSetHash: pure.metadataCitationReadSetHash(targets, originalReads), analysisHash: id('original-analysis'), goldenHash: id('original-goldens'), actionId: id('original-action') };
  const registration = { versionKey, profile: pure.METADATA_CITATION_PROFILE, selector: pure.METADATA_CITATION_RENDER_SELECTOR,
    encoding: a(6), encodingRuntimeHash: keccak256(code), analysisDocument: id('citation-analysis'), goldenDocument: id('citation-goldens') };
  const emptyRecord = { registration: { versionKey: ZeroHash, profile: ZeroHash, selector: '0x00000000', encoding: ZeroAddress,
    encodingRuntimeHash: ZeroHash, analysisDocument: ZeroHash, goldenDocument: ZeroHash }, registrationHash: ZeroHash, readSetHash: ZeroHash, analysisHash: ZeroHash, goldenHash: ZeroHash, actionId: ZeroHash };
  const snapshot = { chainId: 1n, registry: a(1), schemaRegistry: a(2), schemaRegistryCodeHash: keccak256(code), governanceExecutor: a(4),
    targets, originalVersion, originalReads, currentRecord: emptyRecord };
  const plan = pure.prepareMetadataCitationRegistration(snapshot, registration, reads);
  const request = { core: a(7), tokenId: 7n, collectionId: 2n, collectionSerial: 3n, tokenHash: id('token'), state: 1n, mode: 1n,
    collectionSupplyMode: 1n, collectionStatus: 0n, viewId: ZeroHash, viewManifestHash: ZeroHash, metadataSnapshotHash: ZeroHash };
  // Expectations are independent fixed fixture bytes, never produced by the mocked renderer.
  const outputs = ['{"mode":0,"citation":"eip155:1/erc721:0x0000000000000000000000000000000000000007/7"}', '{"mode":1}', '{"mode":2}'];
  const goldens = outputs.map((output, mode) => ({ request, mode: BigInt(mode), outputHash: keccak256(toUtf8Bytes(output)) }));
  const analysis = { analysisProfile: pure.METADATA_CITATION_ANALYSIS_PROFILE, outputProfile: registration.profile, selector: registration.selector,
    renderer: a(5), runtimeHash: keccak256(code), encoding: a(6), encodingRuntimeHash: keccak256(code), readSetHash: plan.readSetHash,
    originalRegistrationHash: originalVersion.registrationHash, toolHash: id('independent-tool'), findingsHash: id('retained-findings'), passed: true };
  const evidence = pure.validateMetadataCitationEvidence(plan, analysis, goldens);
  const documents = new Map([[registration.analysisDocument, { bytes: evidence.analysisBytes, pointer: a(51) }],
    [registration.goldenDocument, { bytes: evidence.goldenBytes, pointer: a(52) }]]);
  const window = { notBefore: 173820n, expiresAfter: 778620n, reasonHash: id('reason'), reasonURI: 'ipfs://citation-review', manifestHash: id('manifest') };
  const batch = pure.metadataCitationGovernanceBatch(plan, 1n, window), proposer = a(80), actor = a(81), pointer = a(50);
  const record = { registration, registrationHash: plan.registrationHash, readSetHash: plan.readSetHash,
    analysisHash: evidence.analysisHash, goldenHash: evidence.goldenHash, actionId: batch.actionId };
  const catalog = { candidateProfileHash: id('candidate'), catalogHash: id('catalog'), entryCount: 12n, revision: 0n };
  const state = { publishedAt: Infinity, scheduledAt: Infinity, executedAt: Infinity, deprecatedAt: Infinity, retiredAt: Infinity };
  const calls = [], blockHash = n => id(`citation-block-${n}`), txHash = id('citation-transaction');
  let transaction, receipt;
  const provider = {
    getNetwork: async () => { options.network?.(); return { chainId: options.chainId ?? 1n }; },
    getBlock: async n => ({ number: n, hash: options.blockHash?.(n) ?? blockHash(n), timestamp: options.timestamp?.(n) ?? (n >= 20 ? Number(window.notBefore) + n - 20 : 1000 + n) }),
    getCode: async (address, tag) => options.code?.(address, tag) ?? (address === pointer ? `0x00${coder.encode(['bytes[]'], [[plan.targetCall.data]]).slice(2)}`
      : [...documents.values()].find(d => d.pointer === address) ? `0x00${[...documents.values()].find(d => d.pointer === address).bytes.slice(2)}` : code),
    call: async tx => {
      calls.push(tx);
      const parsed = abi.parseTransaction({ data: tx.data }), fn = parsed.name, args = parsed.args, tag = tx.blockTag;
      const injected = await options.read?.({ fn, args, tx, parsed });
      if (injected !== undefined) return typeof injected === 'string' ? injected : abi.encodeFunctionResult(parsed.fragment, injected);
      let result;
      if (fn === 'governanceAuthority') result = [a(4)];
      else if (fn === 'governanceAuthorityCodeHash' || fn === 'schemaRegistryCodeHash') result = [keccak256(code)];
      else if (fn === 'schemaRegistry') result = [a(2)];
      else if (fn === 'chunkStore') result = [a(3)];
      else if (fn === 'deploymentChainId') result = [1n];
      else if (fn === 'supportsInterface') result = [true];
      else if (fn === 'currentCitationProfile') result = [registration.profile];
      else if (fn === 'encodingBinding') result = [a(6), keccak256(code)];
      else if (fn === 'targetCount') result = [BigInt(targets.length)];
      else if (fn === 'targetAt') result = [targets[Number(args[0])]];
      else if (fn === 'targetSetHash') result = [pure.metadataCitationTargetSetHash(targets)];
      else if (fn === 'version') result = [{ ...originalVersion, deprecated: tag >= state.deprecatedAt }];
      else if (fn === 'requireRetained') result = [a(5), keccak256(code)];
      else if (fn === 'reads') result = [originalReads];
      else if (fn === 'currentCitationRecord') result = [tag >= state.executedAt ? record : emptyRecord];
      else if (fn === 'currentCitationReads') result = [tag >= state.executedAt ? reads : []];
      else if (fn === 'requireCurrentCitation') {
        if (tag < state.executedAt) throw Error('CurrentCitationUnavailable');
        result = [a(5), keccak256(code), registration.profile, registration.selector];
      } else if (fn === 'gasParameterInfo') result = [1000000n, 100000n, 2n, 1n];
      else if (fn === 'systemManifestBootstrapState') {
        result = Array.from(abi.getFunction(fn).outputs, output => output.type === 'bool' ? false : output.type === 'address' ? ZeroAddress : output.type === 'bytes32' ? ZeroHash : 0n);
        result[0] = true; result[1] = true;
      } else if (fn === 'minimumDelay') result = [172800n];
      else if (fn === 'governanceNonce') result = [tag >= state.scheduledAt ? 2n : 1n];
      else if (fn === 'governanceActionPolicyState') result = Object.values(catalog);
      else if (fn === 'owner') result = [proposer];
      else if (fn === 'isProposer') result = [args[0] === proposer];
      else if (fn === 'currentCitationTransition') result = Object.values(plan.transition);
      else if (fn === 'documentFacts') {
        const row = documents.get(args[0]);
        result = [{ exists: true, kind: 2n, status: tag >= state.retiredAt ? 2n : 0n, contentHash: keccak256(row.bytes), canonicalizationId: id('RAW_BYTES'),
          supersedesId: ZeroHash, totalBytes: BigInt((row.bytes.length - 2) / 2), chunkCount: 1n, declarationHash: id(`document:${args[0]}`) }];
      } else if (fn === 'documentBytes') result = [documents.get(args[0]).bytes];
      else if (fn === 'documentChunkHashAt') result = [keccak256(documents.get(args[0]).bytes)];
      else if (fn === 'chunk' || fn === 'readChunk') {
        const row = [...documents.values()].find(d => keccak256(d.bytes) === args[0]);
        result = fn === 'chunk' ? [row.pointer, BigInt((row.bytes.length - 2) / 2)] : [row.bytes];
      } else if (fn === 'renderCurrent') result = [outputs[Number(args[1])]];
      else if (fn === 'publishedCallData' || fn === 'scheduledCallDataPointer') result = [tag >= state.publishedAt ? pointer : ZeroAddress];
      else if (fn === 'scheduledCallData') result = [[plan.targetCall.data]];
      else if (fn === 'governanceAction') result = [{ status: options.status ?? (tag >= state.executedAt ? 3n : tag >= state.scheduledAt ? 1n : 0n), actionClass: 1n,
        target: a(1), value: 0n, selector: plan.governanceCall.selector, callHash: batch.callsHash, scopeHash: batch.scopeHash,
        oldValueHash: batch.oldValueHash, newValueHash: batch.newValueHash, notBefore: window.notBefore, expiresAfter: window.expiresAfter,
        proposer, executor: tag >= state.executedAt ? actor : ZeroAddress, canceller: ZeroAddress, vetoer: ZeroAddress,
        reasonHash: window.reasonHash, reasonURI: window.reasonURI, manifestHash: window.manifestHash }];
      else if (fn === 'publishGovernanceCallData') result = [pointer];
      else if (fn === 'scheduleGovernanceBatch') { assert.equal(tx.from, proposer); result = [batch.actionId]; }
      else if (fn === 'executeGovernanceBatch') { assert.equal(tx.from, actor); result = []; }
      else throw Error(`Unhandled ${fn}`);
      return abi.encodeFunctionResult(parsed.fragment, result);
    },
    getTransaction: async () => transaction,
    getTransactionReceipt: async () => receipt,
  };
  async function prepare() {
    const c = await workflow.captureMetadataCitation(provider, deployment, versionKey, { blockTag: 10 });
    const i = await workflow.inspectMetadataCitationRegistration(provider, c, registration, reads);
    return workflow.prepareMetadataCitationGovernance(i, proposer, window);
  }
  function operation(prepared, stage) { return workflow.prepareMetadataCitationOperation(prepared, stage, stage === 'schedule' ? proposer : actor); }
  function mine(o, execution = 'direct', indexed = false, eventless = false) {
    const stage = o.stage, tag = options.receiptBlock ?? (stage === 'execute' ? 20 : stage === 'schedule' ? 12 : 11);
    if (stage === 'publish') state.publishedAt = eventless ? 10 : tag;
    if (stage === 'schedule') { state.publishedAt = 11; state.scheduledAt = tag; }
    if (stage === 'execute') { state.publishedAt = 11; state.scheduledAt = 12; state.executedAt = tag; }
    const logs = [];
    const log = (address, event, values, selected = abi) => {
      const encoded = selected.encodeEventLog(selected.getEvent(event), values);
      logs.push({ address, ...encoded, index: logs.length, removed: false, transactionHash: txHash, blockNumber: tag, blockHash: blockHash(tag) });
    };
    const common = [1n, batch.actionId, 1n, a(1), 0n, plan.governanceCall.selector, batch.callsHash, batch.scopeHash, batch.oldValueHash, batch.newValueHash];
    if (stage === 'publish' && !eventless) log(a(4), 'GovernanceCallDataPublished', [1n, batch.publicationKey, pointer, o.caller]);
    if (stage === 'schedule') log(a(4), 'GovernanceActionScheduled', [...common, window.notBefore, window.expiresAfter, 1n, proposer, window.reasonHash, window.reasonURI, window.manifestHash]);
    if (stage === 'execute') {
      log(a(1), 'CurrentCitationRegistered', [1n, versionKey, a(5), batch.actionId, plan.registrationHash, registration, reads]);
      log(a(4), 'GovernanceActionExecuted', [...common, actor, window.manifestHash]);
    }
    if (stage !== 'publish') log(a(4), 'GovernanceActionPolicyValidated', [1n, batch.actionId, stage === 'schedule' ? 1n : 2n, catalog.candidateProfileHash, catalog.catalogHash]);
    if (execution === 'safe') {
      log(o.caller, 'ExecutionSuccess', [id('safe-tx'), 0n], safeAbi);
      if (indexed) { logs.at(-1).topics.push(id('safe-tx')); logs.at(-1).data = coder.encode(['uint256'], [0n]); }
    }
    const to = execution === 'safe' ? o.caller : o.call.to, from = execution === 'safe' ? a(90) : o.caller;
    const data = execution === 'safe' ? safeAbi.encodeFunctionData('execTransaction', [o.call.to, 0n, o.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']) : o.call.data;
    transaction = { hash: txHash, chainId: 1n, to, from, value: 0n, data, blockNumber: tag, blockHash: blockHash(tag) };
    receipt = { hash: txHash, status: 1, to, from, blockNumber: tag, blockHash: blockHash(tag), logs };
    return { receipt, transaction };
  }
  return { provider, options, deployment, versionKey, targets, originalReads, reads, snapshot, registration, plan, request, evidence,
    outputs, documents, state, record, calls, window, batch, catalog, proposer, actor, pointer, blockHash, txHash, prepare, operation, mine };
}

test('pinned capture and evidence join original reads, immutable chunks and independent mode0/1/2 expectations', async () => {
  const s = setup(), prepared = await s.prepare(), i = prepared.inspection;
  assert.equal(i.plan.registrationHash, s.plan.registrationHash);
  assert.equal(i.evidence.goldenHash, s.evidence.goldenHash);
  assert.equal(i.goldenObservation, 'direct renderer calls; no nested gas equivalence');
  assert.ok(Object.isFrozen(i.capture.snapshot.targets));
  assert.equal(s.calls.filter(tx => abi.parseTransaction({ data: tx.data }).name === 'renderCurrent').length, 3);
  assert.ok(s.calls.every(tx => tx.blockTag === 10));
});

test('all governance stages use original exact caller and ordinary Safe CALL composition', async () => {
  const s = setup(), prepared = await s.prepare();
  for (const stage of ['publish', 'schedule', 'execute']) {
    const op = s.operation(prepared, stage);
    if (stage !== 'publish') s.state.publishedAt = 11;
    if (stage === 'execute') s.state.scheduledAt = 12;
    const simulation = await workflow.simulateMetadataCitationOperation(s.provider, op, { blockTag: stage === 'execute' ? 20 : 11 });
    assert.equal(simulation.operation.caller, op.caller);
    assert.ok(s.calls.some(tx => tx.from === op.caller && tx.data === op.call.data));
    const safe = createSafeCallPlan(1n, 'Review citation governance', [{ safe: op.caller, intent: stage, call: op.call, abi: fixture.abis.executor }]);
    assert.equal(safe.steps[0].transaction.operation, 0);
  }
});

test('direct and both Safe event layouts join registration, exact original governance and immutable current record', async () => {
  for (const stage of ['publish', 'schedule', 'execute']) for (const execution of ['direct', 'safe', 'indexed-safe']) {
    const s = setup(), prepared = await s.prepare(), op = s.operation(prepared, stage);
    s.mine(op, execution === 'direct' ? 'direct' : 'safe', execution === 'indexed-safe');
    const r = await workflow.inspectMetadataCitationOperationReceipt(s.provider, op, { transactionHash: s.txHash, execution: execution === 'direct' ? 'direct' : 'safe' });
    if (stage === 'execute') assert.deepEqual(r.record, s.record);
    if (execution !== 'direct') assert.equal(r.events.at(-1).event, 'ExecutionSuccess');
  }
});

test('retained serving survives catalog retirement and original version deprecation without old-selector fallback', async () => {
  const s = setup(); s.state.executedAt = 20; s.state.retiredAt = 20; s.state.deprecatedAt = 20;
  for (const mode of [0n, 1n, 2n]) {
    const r = await workflow.readMetadataCurrentCitation(s.provider, s.deployment, s.versionKey, s.request, mode, { blockTag: 20 });
    assert.equal(r.output, s.outputs[Number(mode)]);
    assert.equal(r.record.registrationHash, s.plan.registrationHash);
  }
  const names = s.calls.map(tx => abi.parseTransaction({ data: tx.data }).name);
  assert.ok(names.includes('requireCurrentCitation'));
  assert.ok(!names.some(name => ['tokenURI', 'renderView', 'documentFacts', 'documentBytes', 'governanceActionPolicyState'].includes(name)));
  await assert.rejects(workflow.readMetadataCurrentCitation(s.provider, s.deployment, s.versionKey, s.request, 3n, { blockTag: 20 }), /modes0/);
  s.state.executedAt = Infinity;
  await assert.rejects(workflow.readMetadataCurrentCitation(s.provider, s.deployment, s.versionKey, s.request, 0n, { blockTag: 20 }), /not admitted/);
});


async function captured(s) { return workflow.captureMetadataCitation(s.provider, s.deployment, s.versionKey, { blockTag: 10 }); }
const inspect = async s => workflow.inspectMetadataCitationRegistration(s.provider, await captured(s), s.registration, s.reads);

test('admission rejects retired documents, altered golden results and noncanonical retained evidence', async () => {
  for (const attack of ['retired', 'golden', 'analysis', 'noncanonical', 'chunk', 'oversized', 'mode-coverage']) {
    const s = setup();
    if (attack === 'retired') s.state.retiredAt = 10;
    if (attack === 'golden') s.outputs[1] = '{"unexpected":true}';
    if (attack === 'analysis') s.documents.get(s.registration.analysisDocument).bytes = pure.encodeMetadataCitationAnalysis({ ...s.evidence.analysis, findingsHash: ZeroHash });
    if (attack === 'noncanonical') s.documents.get(s.registration.analysisDocument).bytes += '00';
    if (attack === 'mode-coverage') {
      const vectors = clone(s.evidence.goldens); vectors[2].mode = 1n;
      s.documents.get(s.registration.goldenDocument).bytes = coder.encode([`${pure.METADATA_CITATION_GOLDEN_VECTOR_TUPLE}[]`], [vectors]);
    }
    if (attack === 'chunk') s.options.code = address => address === a(51) ? '0x00abcd' : undefined;
    if (attack === 'oversized') s.options.read = ({ fn }) => fn === 'documentFacts' ? [{ exists: true, kind: 2n, status: 0n, contentHash: id('large'),
      canonicalizationId: id('RAW_BYTES'), supersedesId: ZeroHash, totalBytes: 8193n, chunkCount: 1n, declarationHash: id('declaration') }] : undefined;
    await assert.rejects(inspect(s), /document|golden|analysis|canonical|chunk|mode|evidence/i);
  }
});

test('original declaration preservation, target pins, renderer binding and current-record contradictions fail closed', async () => {
  for (const attack of ['old-read', 'target-runtime', 'binding', 'profile', 'empty-record', 'retained-hash']) {
    const s = setup();
    if (attack === 'old-read') s.reads[1] = { ...s.reads[1], exact: false };
    if (attack === 'target-runtime') s.options.code = address => address === a(7) ? '0x6001' : undefined;
    if (attack === 'binding') s.options.read = ({ fn }) => fn === 'encodingBinding' ? [a(9), keccak256(code)] : undefined;
    if (attack === 'profile') s.options.read = ({ fn }) => fn === 'currentCitationProfile' ? [id('old-profile')] : undefined;
    if (attack === 'empty-record') s.options.read = ({ fn }) => fn === 'currentCitationRecord' ? [{ ...s.record, registrationHash: ZeroHash }] : undefined;
    if (attack === 'retained-hash') {
      s.state.executedAt = 10;
      s.options.read = ({ fn }) => fn === 'currentCitationRecord' ? [{ ...s.record, analysisHash: ZeroHash }] : undefined;
    }
    await assert.rejects(inspect(s), /read|runtime|binding|profile|record|bytes32|unavailable|admitted/i);
  }
});

test('copied captures preserve scalar types, inputs before awaits and exact block/runtime identities', async () => {
  const s = setup(), d = clone(s.deployment), registration = clone(s.registration), reads = clone(s.reads);
  s.options.network = () => { d.renderer.codeHash = id('mutated'); };
  const c = await workflow.captureMetadataCitation(s.provider, d, s.versionKey, { blockTag: 10 });
  assert.equal(c.deployment.renderer.codeHash, s.deployment.renderer.codeHash);
  s.options.network = () => { registration.analysisDocument = id('mutated'); reads.reverse(); };
  const inspection = await workflow.inspectMetadataCitationRegistration(s.provider, c, registration, reads);
  assert.equal(inspection.plan.registration.analysisDocument, s.registration.analysisDocument);
  delete s.options.network;
  const changed = clone(c); changed.governanceNonce = '1n';
  await assert.rejects(workflow.inspectMetadataCitationRegistration(s.provider, changed, s.registration, s.reads), /changed/);
  for (const attack of ['chain', 'code', 'delegated-code', 'reorg', 'rpc']) {
    const bad = setup();
    if (attack === 'chain') bad.options.chainId = 2n;
    if (attack === 'code') bad.options.code = address => address === a(1) ? '0x6002' : undefined;
    if (attack === 'delegated-code') {
      const designation = `0xef0100${a(99).slice(2)}`;
      bad.deployment.registry.codeHash = keccak256(designation);
      bad.options.code = address => address === a(1) ? designation : undefined;
    }
    if (attack === 'reorg') { let reads = 0; bad.options.blockHash = () => ++reads > 1 ? id('reorg') : bad.blockHash(10); }
    if (attack === 'rpc') bad.options.read = ({ fn }) => fn === 'targetCount' ? `${coder.encode(['uint256'], [2n])}00` : undefined;
    await assert.rejects(captured(bad), /chain|runtime|block|canonical|length/i);
  }
});

test('governance timing, catalog and nonce freshness use original exact-call admission', async () => {
  const s = setup(), prepared = await s.prepare();
  assert.throws(() => workflow.prepareMetadataCitationGovernance(prepared.inspection, s.proposer,
    { ...s.window, notBefore: 173809n }), /window/);
  assert.throws(() => workflow.prepareMetadataCitationOperation(prepared, 'schedule', s.actor), /proposer/);
  for (const attack of ['catalog', 'nonce', 'unpublished', 'simulation', 'early', 'reverted']) {
    const bad = setup(), ready = await bad.prepare(), stage = attack === 'early' ? 'execute' : 'schedule';
    bad.state.publishedAt = attack === 'unpublished' ? Infinity : 11;
    bad.state.scheduledAt = stage === 'execute' ? 11 : Infinity;
    bad.options.read = ({ fn, tx }) => {
      if (tx.blockTag === 10) return;
      if (attack === 'catalog' && fn === 'governanceActionPolicyState') return [bad.catalog.candidateProfileHash, id('new-catalog'), 13n, 1n];
      if (attack === 'nonce' && fn === 'governanceNonce') return [9n];
      if (attack === 'simulation' && fn === 'scheduleGovernanceBatch') return [id('wrong-action')];
      if (attack === 'reverted' && fn === 'scheduleGovernanceBatch') throw Error('original catalog rejected selector');
    };
    await assert.rejects(workflow.simulateMetadataCitationOperation(bad.provider, bad.operation(ready, stage), { blockTag: 11 }), /catalog|nonce|Publish|action|window|selector/i);
  }
});

test('idempotent publication requires immutable prior pointer/runtime and needs no fresh admission', async () => {
  const s = setup(), prepared = await s.prepare(), op = s.operation(prepared, 'publish');
  s.state.executedAt = 20; s.state.deprecatedAt = 20; s.state.retiredAt = 20; s.state.publishedAt = 11;
  await workflow.simulateMetadataCitationOperation(s.provider, op, { blockTag: 20 });
  const retry = setup(), ready = await retry.prepare(), publish = retry.operation(ready, 'publish');
  retry.mine(publish, 'safe', true, true);
  const result = await workflow.inspectMetadataCitationOperationReceipt(retry.provider, publish, { transactionHash: retry.txHash, execution: 'safe' });
  assert.equal(result.events.length, 1);
  for (const attack of ['missing-prior', 'prior-code', 'prior-pointer', 'simulated-pointer']) {
    const bad = setup(), ready = await bad.prepare(), o = bad.operation(ready, 'publish');
    if (attack === 'prior-code') bad.options.receiptBlock = 12;
    bad.mine(o, 'direct', false, true);
    if (attack === 'missing-prior') bad.state.publishedAt = 11;
    if (attack === 'prior-code') bad.options.code = (address, tag) => address === a(4) && tag === 11 ? '0x6002' : undefined;
    if (attack === 'prior-pointer') bad.options.read = ({ fn, tx }) => fn === 'publishedCallData' && tx.blockTag === 10 ? [a(53)] : undefined;
    if (attack === 'simulated-pointer') {
      bad.options.read = ({ fn }) => fn === 'publishGovernanceCallData' ? [a(53)] : undefined;
      await assert.rejects(workflow.simulateMetadataCitationOperation(bad.provider, o, { blockTag: 11 }), /pointer/);
    } else await assert.rejects(workflow.inspectMetadataCitationOperationReceipt(bad.provider, o, { transactionHash: bad.txHash, execution: 'direct' }), /prior|previous|runtime|Published/i);
  }
});

test('execution receipts retain admitted evidence through same-block retirement and deprecation', async () => {
  const s = setup(), ready = await s.prepare(), op = s.operation(ready, 'execute');
  s.mine(op); s.state.deprecatedAt = 20; s.state.retiredAt = 20;
  const result = await workflow.inspectMetadataCitationOperationReceipt(s.provider, op, { transactionHash: s.txHash, execution: 'direct' });
  assert.equal(result.record.registrationHash, s.plan.registrationHash);
  const laterReads = s.calls.filter(tx => tx.blockTag === 20).map(tx => abi.parseTransaction({ data: tx.data }).name);
  assert.ok(!laterReads.includes('documentFacts'));
  s.options.code = address => address === a(7) ? '0x6002' : undefined;
  await assert.rejects(workflow.readMetadataCurrentCitation(s.provider, s.deployment, s.versionKey, s.request, 0n, { blockTag: 21 }), /runtime/);
});

test('receipt events, canonical fields and Safe outcomes require exact original ordering', async () => {
  for (const attack of ['missing-registration', 'missing-safe', 'failed-safe', 'early-safe', 'policy-order', 'record', 'delegatecall', 'trailing', 'same-block', 'topic']) {
    const s = setup(), ready = await s.prepare(), op = s.operation(ready, 'execute'), { receipt, transaction } = s.mine(op, 'safe');
    if (attack === 'missing-registration') receipt.logs.shift();
    if (attack === 'missing-safe') receipt.logs.pop();
    if (attack === 'failed-safe') receipt.logs.at(-1).topics[0] = safeAbi.getEvent('ExecutionFailure').topicHash;
    if (attack === 'early-safe') receipt.logs.unshift(receipt.logs.pop());
    if (attack === 'policy-order') [receipt.logs[1], receipt.logs[2]] = [receipt.logs[2], receipt.logs[1]];
    if (attack === 'record') s.options.read = ({ fn, tx }) => fn === 'currentCitationRecord' && tx.blockTag === 20 ? [{ ...s.record, goldenHash: id('wrong') }] : undefined;
    if (attack === 'delegatecall') transaction.data = safeAbi.encodeFunctionData('execTransaction', [op.call.to, 0n, op.call.data, 1n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']);
    if (attack === 'trailing') receipt.logs[0].data += '00';
    if (attack === 'same-block') receipt.blockNumber = transaction.blockNumber = 10;
    if (attack === 'topic') receipt.logs[0].topics[0] = '0x12';
    receipt.logs.forEach((log, i) => { log.index = i; });
    await assert.rejects(workflow.inspectMetadataCitationOperationReceipt(s.provider, op, { transactionHash: s.txHash, execution: 'safe' }), /CurrentCitationRegistered|Safe|order|record|CALL|canonical|chronology|bytes32/i);
  }
});


test('class1 schedule permits later same-block cancellation but rejects execution, expiry and veto contradictions', async () => {
  for (const status of [2n, 3n, 4n, 5n]) {
    const s = setup(), ready = await s.prepare(), op = s.operation(ready, 'schedule'); s.mine(op);
    s.options.status = status;
    const result = workflow.inspectMetadataCitationOperationReceipt(s.provider, op, { transactionHash: s.txHash, execution: 'direct' });
    if (status === 2n) await result;
    else await assert.rejects(result, /Scheduled action/);
  }
  const s = setup(), ready = await s.prepare(), op = s.operation(ready, 'schedule'), { receipt } = s.mine(op);
  receipt.logs.reverse(); receipt.logs.forEach((log, i) => { log.index = i; });
  await assert.rejects(workflow.inspectMetadataCitationOperationReceipt(s.provider, op, { transactionHash: s.txHash, execution: 'direct' }), /follow scheduling/);
});

test('serving enforces canonical string and mode byte limits independently from registration evidence', async () => {
  const s = setup(); s.state.executedAt = 20;
  s.outputs[0] = 'x'.repeat(18000);
  assert.equal((await workflow.readMetadataCurrentCitation(s.provider, s.deployment, s.versionKey, s.request, 0n, { blockTag: 20 })).output.length, 18000);
  s.outputs[0] += 'x';
  await assert.rejects(workflow.readMetadataCurrentCitation(s.provider, s.deployment, s.versionKey, s.request, 0n, { blockTag: 20 }), /bound/);
  s.options.read = ({ fn }) => fn === 'renderCurrent' ? `${coder.encode(['string'], ['valid'])}${'00'.repeat(32)}` : undefined;
  await assert.rejects(workflow.readMetadataCurrentCitation(s.provider, s.deployment, s.versionKey, s.request, 0n, { blockTag: 20 }), /canonical/);
});

test('maximum128-read registration reconciles its complete compiled event beyond16384 bytes', async () => {
  const s = setup({ maxReads: true }), ready = await s.prepare(), op = s.operation(ready, 'execute');
  const { receipt } = s.mine(op, 'safe', true);
  const event = receipt.logs.find(log => abi.parseLog(log)?.name === 'CurrentCitationRegistered');
  assert.equal((event.data.length - 2) / 2, 16736);
  const result = await workflow.inspectMetadataCitationOperationReceipt(s.provider, op, { transactionHash: s.txHash, execution: 'safe' });
  assert.equal(result.operation.prepared.inspection.plan.reads.length, 128);
  assert.equal(result.record.registrationHash, ready.inspection.plan.registrationHash);
});
