import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as api from '../dist/current-reference-inventory-workflow.js';
import { prepareReferenceInventory } from '../dist/current-reference-inventory.js';
const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/current-reference-inventory-abi.json', import.meta.url), 'utf8'));
const hostAbi = new Interface(fixture.abis.host), storeAbi = new Interface(fixture.abis.store);
const safeAbi = new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)', 'event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)', 'event ExecutionFailure(bytes32 indexed txHash,uint256 payment)']);
const addr = n => getAddress(`0x${n.toString(16).padStart(40, '0')}`), blockHash = id('block'), txHash = id('step-tx'), code = '0x6000', codeHash = keccak256(code);
const rows = count => Array.from({ length: count }, (_, i) => ({ path: `folder/${i.toString().padStart(5, '0')}/file.txt`, byteSize: BigInt(i), sha256Digest: id(`sha-${i}`) }));
function setup(count = 70, mode = 'staged') {
  const deployment = { chainId: 1n, publicationHost: { address: addr(1), codeHash }, store: { address: addr(2), codeHash } }, preparer = addr(3), uploader = addr(4);
  const snapshot = prepareReferenceInventory(1n, addr(1), true, rows(count)), plan = api.prepareReferenceInventoryPlan(deployment, preparer, snapshot, { mode, uploader });
  const state = { chunks: new Map(), inventories: new Map(), requests: [], estimates: [], override: {}, onNetwork: null, reorg: false, headers: 0, tx: null, receipt: null };
  function upload(chunk) { state.chunks.set(chunk.hash, { pointer: addr(100 + chunk.index), bytes: chunk.bytes }); }
  const deps = { targets: [addr(10), addr(11), addr(12), addr(2), addr(14), addr(15), addr(16)], codeHashes: Array(7).fill(codeHash), chainId: 1n, rendererCatalogId: id('catalog'), rendererCatalogHash: id('catalog-hash'), rendererCatalogBytes: 1n, readGas: 50000n, sourceGas: 50000n, snapshotGas: 50000n, archiveGas: 50000n };
  const provider = {
    async getNetwork() { state.onNetwork?.(); return { chainId: 1n }; },
    async getBlock(number) { state.headers++; return { number, hash: state.reorg && state.headers > 1 ? id('reorg') : blockHash }; },
    async getCode(target) { if (target === addr(1) || target === addr(2)) return code; const found = [...state.chunks.values()].find(c => c.pointer === target); return found ? `0x00${found.bytes.slice(2)}` : '0x'; },
    async call(request) {
      state.requests.push(request); assert.equal(request.blockTag, 50); assert.equal(request.value, 0n);
      const abi = request.to === addr(1) ? hostAbi : storeAbi, parsed = abi.parseTransaction({ data: request.data });
      if (state.override[parsed.name]) { const value = state.override[parsed.name](parsed.args, request); return typeof value === 'string' ? value : abi.encodeFunctionResult(parsed.name, value); }
      let value;
      switch (parsed.name) {
        case 'deploymentChainId': value = [1n]; break;
        case 'dependencies': value = [deps]; break;
        case 'supportsInterface': value = [true]; break;
        case 'MAX_CHUNK_BYTES': value = [8192n]; break;
        case 'preparedFileInventory': {
          const raw = state.inventories.get(parsed.args[0]); if (raw === undefined) throw Object.assign(Error('unknown inventory'), { code: 'CALL_EXCEPTION', data: id('InvalidSnapshotManifest()').slice(0, 10) }); value = [raw]; break;
        }
        case 'chunk': { const stored = state.chunks.get(parsed.args[0]); value = stored ? [stored.pointer, BigInt((stored.bytes.length - 2) / 2)] : [ZeroAddress, 0n]; break; }
        case 'publishChunk': assert.equal(request.from, uploader); value = [keccak256(parsed.args[0]), addr(900)]; break;
        default: {
          assert.equal(request.from, preparer); const step = plan.steps.find(s => s.call.data === request.data); assert.ok(step); value = [step.identity]; break;
        }
      }
      return abi.encodeFunctionResult(parsed.name, value);
    },
    async send(method, params) { state.estimates.push({ method, params }); return '0x5208'; },
    async getTransaction() { return state.tx; }, async getTransactionReceipt() { return state.receipt; },
  };
  function commit(index, execution = 'direct', emit = true) {
    const step = plan.steps[index], logs = [];
    const event = (target, abi, name, values) => logs.push({ address: target, ...abi.encodeEventLog(abi.getEvent(name), values), index: logs.length, blockNumber: 50, blockHash, transactionHash: txHash, removed: false });
    if (step.kind === 'upload') {
      const chunk = plan.chunks[step.chunkIndex]; upload(chunk); if (emit) event(addr(2), storeAbi, 'ChunkPublished', [chunk.hash, state.chunks.get(chunk.hash).pointer, BigInt((chunk.bytes.length - 2) / 2)]);
    } else {
      const doc = step.kind === 'part' ? plan.parts[step.documentIndex] : snapshot; state.inventories.set(step.identity, doc.canonical);
      if (emit && step.kind !== 'monolithic') event(addr(1), hostAbi, step.kind === 'part' ? 'ReferenceInventoryPartPrepared' : 'ReferenceInventoryAssembled', [1n, step.identity, snapshot.relative, BigInt(doc.rows.length), doc.contentHash, doc.byteLength]);
    }
    if (execution === 'safe') event(step.caller, safeAbi, 'ExecutionSuccess', [id('safe-step'), 0n]);
    state.tx = { hash: txHash, blockNumber: 50, blockHash, from: execution === 'safe' ? addr(90) : step.caller, to: execution === 'safe' ? step.caller : step.call.to, value: 0n, data: execution === 'safe' ? safeAbi.encodeFunctionData('execTransaction', [step.call.to, 0n, step.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']) : step.call.data };
    state.receipt = { hash: txHash, status: 1, blockNumber: 50, blockHash, logs };
    return { transactionHash: txHash, execution };
  }
  return { deployment, snapshot, plan, preparer, uploader, state, provider, deps, upload, commit };
}

test('fixed parts, original full identity, exact separate document chunks and different upload/preparation actors', () => {
  const f = setup(); assert.deepEqual(f.plan.parts.map(p => p.rows.length), [64, 6]);
  assert.equal(f.plan.steps.at(-1).kind, 'assemble'); assert.equal(f.plan.steps.at(-1).identity, f.snapshot.inventoryId);
  for (const s of f.plan.steps) { assert.equal(s.call.value, 0n); assert.equal(s.caller, s.kind === 'upload' ? f.uploader : f.preparer); }
  assert.equal(new Set(f.plan.chunks.map(c => c.hash)).size, f.plan.chunks.length); assert.ok(Object.isFrozen(f.plan.parts[0].rows));
  const parsed = hostAbi.parseTransaction({ data: f.plan.steps.at(-1).call.data }); assert.equal(parsed.args[0].length, 70); assert.equal(parsed.args[1], true);
});
test('inspection resumes only exact onchain chunks/parts and marks prerequisites per step', async () => {
  const f = setup(); let inspected = await api.inspectReferenceInventoryPreparation(f.provider, f.plan, { blockTag: 50 });
  assert.ok(inspected.steps.filter(s => f.plan.steps[s.index].kind === 'upload').every(s => s.status === 'ready'));
  assert.equal(inspected.steps.at(-1).status, 'blocked'); assert.ok(inspected.parts.every(p => !p.prepared));
  f.plan.chunks.forEach(f.upload); inspected = await api.inspectReferenceInventoryPreparation(f.provider, f.plan, { blockTag: 50 });
  assert.ok(inspected.steps.filter(s => f.plan.steps[s.index].kind === 'part').every(s => s.status === 'ready')); assert.equal(inspected.steps.at(-1).status, 'blocked');
  f.plan.parts.forEach(p => f.state.inventories.set(p.partId, p.canonical)); inspected = await api.inspectReferenceInventoryPreparation(f.provider, f.plan, { blockTag: 50 }); assert.equal(inspected.steps.at(-1).status, 'ready');
});
test('existing monolithic full inventory completes staged resume without asserting part/upload history', async () => {
  const f = setup(); f.state.inventories.set(f.snapshot.inventoryId, f.snapshot.canonical);
  const result = await api.inspectReferenceInventoryPreparation(f.provider, f.plan, { blockTag: 50 }); assert.equal(result.completed, true); assert.deepEqual(result.parts, []); assert.deepEqual(result.chunkAvailability, []);
  assert.ok(result.steps.slice(0, -1).every(s => s.status === 'unnecessary'));
  assert.equal((await api.simulateReferenceInventoryStep(f.provider, f.plan, f.plan.steps.length - 1, { blockTag: 50 })).identity, f.snapshot.inventoryId);
  await assert.rejects(api.simulateReferenceInventoryStep(f.provider, f.plan, 0, { blockTag: 50 }), /no part\/upload/);
});
test('empty inventory uses [] upload plus zero-part assembly and monolithic compatibility stays explicit', async () => {
  const f = setup(0); assert.equal(f.plan.parts.length, 0); assert.equal(f.plan.chunks.length, 1); assert.equal(f.plan.chunks[0].bytes, '0x5b5d'); f.upload(f.plan.chunks[0]);
  assert.equal((await api.inspectReferenceInventoryPreparation(f.provider, f.plan, { blockTag: 50 })).steps.at(-1).status, 'ready');
  const g = setup(1, 'monolithic'); assert.equal(g.plan.parts.length, 0); assert.equal(hostAbi.parseTransaction({ data: g.plan.steps.at(-1).call.data }).name, 'prepareFileInventory');
});
test('actual-caller simulation and pinned raw gas estimation quote only executable current steps', async () => {
  const f = setup(), final = f.plan.steps.length - 1;
  await assert.rejects(api.quoteReferenceInventoryStepGas(f.provider, f.plan, final, { blockTag: 50 }), /prerequisites/); assert.equal(f.state.estimates.length, 0);
  const quote = await api.quoteReferenceInventoryStepGas(f.provider, f.plan, 0, { blockTag: 50, maximumGas: 20000n });
  assert.equal(quote.scope, 'inner-call'); assert.equal(quote.estimatedGas, 21000n); assert.equal(quote.withinMaximum, false);
  assert.deepEqual(f.state.estimates[0], { method: 'eth_estimateGas', params: [{ from: f.uploader, to: f.deployment.store.address, data: f.plan.steps[0].call.data, value: '0x0' }, '0x32'] });
  f.provider.send = async () => '0x05208'; await assert.rejects(api.quoteReferenceInventoryStepGas(f.provider, f.plan, 0, { blockTag: 50 }), /Noncanonical gas/);
});
test('inputs are rebuilt before awaits; bad code/dependency/hash/trailingRPC and unknown failures fail closed', async () => {
  const f = setup(), input = structuredClone(f.plan); f.state.onNetwork = () => { input.snapshot.rows[0].path = 'changed'; input.steps[0].caller = addr(98); };
  const result = await api.inspectReferenceInventoryPreparation(f.provider, input, { blockTag: 50 }); assert.equal(result.plan.snapshot.rows[0].path, f.snapshot.rows[0].path);
  for (const configure of [
    g => g.provider.getCode = async () => '0x6001',
    g => g.deps.targets[3] = addr(89),
    g => g.state.override.preparedFileInventory = () => ['0x00'],
    g => g.state.override.preparedFileInventory = () => { throw Error('RPC network failure'); },
    g => g.state.override.MAX_CHUNK_BYTES = () => storeAbi.encodeFunctionResult('MAX_CHUNK_BYTES', [8192n]) + '00'.repeat(32),
    g => g.state.reorg = true,
  ]) { const g = setup(); configure(g); await assert.rejects(api.inspectReferenceInventoryPreparation(g.provider, g.plan, { blockTag: 50 })); }
});
test('chunk mapping lengths and exact STOP-prefixed runtime are verified', async () => {
  const f = setup(); f.upload(f.plan.chunks[0]); const original = f.provider.getCode; f.provider.getCode = async target => target === addr(100) ? '0x0000' : original(target);
  await assert.rejects(api.inspectReferenceInventoryPreparation(f.provider, f.plan, { blockTag: 50 }), /pointer runtime/);
  const g = setup(); g.state.override.chunk = () => [ZeroAddress, 1n]; await assert.rejects(api.inspectReferenceInventoryPreparation(g.provider, g.plan, { blockTag: 50 }), /nonzero length/);
});
test('direct/Safe first-save and eventless repeated upload/part/assembly receipts bind exact readback', async () => {
  for (const mode of ['direct', 'safe']) for (const kind of ['upload', 'part', 'assemble']) for (const emit of [true, false]) {
    const f = setup(), s = f.plan.steps.find(s => s.kind === kind), evidence = f.commit(s.index, mode, emit);
    const result = await api.inspectReferenceInventoryStepReceipt(f.provider, f.plan, s.index, evidence); assert.equal(result.identity, s.identity); assert.equal(result.events.length, Number(emit) + Number(mode === 'safe')); assert.ok(Object.isFrozen(result.plan.snapshot.rows));
  }
  const f = setup(1, 'monolithic'), index = f.plan.steps.length - 1, ev = f.commit(index); assert.deepEqual((await api.inspectReferenceInventoryStepReceipt(f.provider, f.plan, index, ev)).events, []);
});
test('receipts reject wrong hashes, trailing events, false Safe success, wrong call frame and reorg', async () => {
  for (const change of [
    f => f.state.receipt.logs[0].data += '00'.repeat(32),
    f => f.state.receipt.logs[0].topics[1] = id('wrong'),
    f => f.state.receipt.logs[0].topics[0] = hostAbi.getEvent('ReferenceInventoryAssembled').topicHash,
    f => { f.state.receipt.logs[0].address = addr(99); f.state.receipt.logs[0].topics[0] = '0x00'; },
    f => f.state.tx.from = addr(92),
    f => f.state.inventories.clear(),
    f => f.state.reorg = true,
  ]) { const f = setup(), s = f.plan.steps.find(s => s.kind === 'part'), ev = f.commit(s.index); change(f); await assert.rejects(api.inspectReferenceInventoryStepReceipt(f.provider, f.plan, s.index, ev)); }
  const f = setup(), ev = f.commit(0, 'safe'); f.state.receipt.logs.at(-1).topics[0] = safeAbi.getEvent('ExecutionFailure').topicHash; await assert.rejects(api.inspectReferenceInventoryStepReceipt(f.provider, f.plan, 0, ev), /ExecutionSuccess/);
  const g = setup(), e = g.commit(0, 'safe'); g.state.receipt.logs.pop(); await assert.rejects(api.inspectReferenceInventoryStepReceipt(g.provider, g.plan, 0, e), /ExecutionSuccess/);
});
