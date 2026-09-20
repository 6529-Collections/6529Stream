import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as api from '../dist/current-collection-inventory-workflow.js';
import * as pure from '../dist/current-collection-inventory.js';
const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/current-collection-inventory-abi.json', import.meta.url), 'utf8'));
const inventoryAbi = new Interface(fixture.abis.inventory), coreAbi = new Interface(fixture.abis.core), coder = AbiCoder.defaultAbiCoder();
const safe = new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)', 'event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)', 'event ExecutionFailure(bytes32 indexed txHash,uint256 payment)']);
const legacySafe = new Interface(['event ExecutionSuccess(bytes32 txHash,uint256 payment)']);
const addr = n => getAddress(`0x${n.toString(16).padStart(40, '0')}`), code = '0x6000', codeHash = keccak256(code), hash50 = id('before'), hash51 = id('after'), txHash = id('index-tx');
const unknown = tokenId => ({ tokenId, mappingExists: false, collectionId: 0n, collectionSerial: 0n, burned: false, lifecycle: 0n });
const token = (tokenId, collectionId, collectionSerial, lifecycle = 2n) => ({ tokenId, mappingExists: true, collectionId, collectionSerial, burned: lifecycle === 3n, lifecycle });
function setup() {
  const deployment = { chainId: 1n, inventory: { address: addr(1), codeHash }, core: { address: addr(2), codeHash } }, coordinates = { chainId: 1n, inventory: addr(1), core: addr(2), collectionId: 9n }, caller = addr(3);
  const facts = new Map([[1n, unknown(1n)], [2n, token(2n, 9n, 2n)], [3n, token(3n, 8n, 1n, 1n)], [4n, token(4n, 9n, 4n, 3n)], [5n, token(5n, 8n, 2n)], [6n, unknown(6n)]]);
  const empty = { indexedCount: 0n, prefixHash: pure.collectionInventoryEmptyPrefix(coordinates), lastIndexedSerial: 0n, scanThrough: 0n };
  const before = { checkpoint: empty, entries: [], frontier: 6n, mintedEver: 2n }, after = structuredClone(before);
  const state = { blocks: { 50: before, 51: after }, facts, overrides: {}, requests: [], headers: 0, reorg: false, onNetwork: null, tx: null, receipt: null };
  const provider = {
    async getNetwork() { state.onNetwork?.(); return { chainId: 1n }; },
    async getCode() { return code; },
    async getBlock(number) { state.headers++; return { number, hash: state.reorg && state.headers > 1 ? id('reorg') : number === 50 ? hash50 : hash51 }; },
    async call(req) {
      state.requests.push(req); assert.ok(req.blockTag === 50 || req.blockTag === 51); assert.equal(req.value, 0n);
      const abi = req.to === addr(1) ? inventoryAbi : coreAbi, p = abi.parseTransaction({ data: req.data }), b = state.blocks[req.blockTag];
      if (state.overrides[p.name]) { const v = state.overrides[p.name](p.args, req); return typeof v === 'string' ? v : abi.encodeFunctionResult(p.name, v); }
      let value;
      switch (p.name) {
        case 'core': value = [addr(2)]; break;
        case 'coreCodeHash': value = [codeHash]; break;
        case 'deploymentChainId': value = [1n]; break;
        case 'MAX_INDEX_BATCH': value = [256n]; break;
        case 'collectionExists': value = [true]; break;
        case 'collectionMintedEver': value = [b.mintedEver]; break;
        case 'lastAllocatedTokenId': value = [b.frontier]; break;
        case 'collectionInventoryState': value = [b.checkpoint.indexedCount, b.checkpoint.prefixHash]; break;
        case 'collectionScanThrough': value = [b.checkpoint.scanThrough]; break;
        case 'collectionTokenAt': { const e = b.entries[Number(p.args[1])]; if (!e) throw Error('ordinal out of range'); value = [e.tokenId]; break; }
        case 'collectionTokenBySerial': value = [b.entries.find(e => e.collectionSerial === p.args[1])?.tokenId ?? 0n]; break;
        case 'tokenCollectionIdentity': { const f = facts.get(p.args[0]) ?? unknown(p.args[0]); value = [f.mappingExists, f.collectionId, f.collectionSerial, f.burned]; break; }
        case 'tokenLifecycle': value = [(facts.get(p.args[0]) ?? unknown(p.args[0])).lifecycle]; break;
        case 'requireCompleteCollection': assert.equal(b.checkpoint.indexedCount, b.mintedEver); value = [b.checkpoint.indexedCount, b.checkpoint.prefixHash]; break;
        case 'appendCollectionTokens': assert.equal(req.from, caller); pure.replayCollectionInventoryAppend(coordinates, b.checkpoint, p.args[1].map(t => facts.get(t))); value = []; break;
        case 'scanCollectionTokens': {
          assert.equal(req.from, caller); const count = Number(b.frontier - b.checkpoint.scanThrough < p.args[1] ? b.frontier - b.checkpoint.scanThrough : p.args[1]);
          const f = Array.from({ length: count }, (_, i) => facts.get(b.checkpoint.scanThrough + BigInt(i) + 1n) ?? unknown(b.checkpoint.scanThrough + BigInt(i) + 1n));
          const r = pure.replayCollectionInventoryScan(coordinates, b.checkpoint, b.frontier, p.args[1], f); value = [r.after.scanThrough, r.after.indexedCount, r.after.prefixHash]; break;
        }
        default: throw Error(`Unexpected ${p.name}`);
      }
      return abi.encodeFunctionResult(p.name, value);
    },
    async getTransaction() { return state.tx; }, async getTransactionReceipt() { return state.receipt; },
  };
  function commit(plan, replay, mode = 'direct', indexed = true) {
    const b = state.blocks[51]; b.checkpoint = replay.after; b.entries = [...state.blocks[50].entries, ...replay.indexed];
    const logs = replay.indexed.map((e, index) => ({ address: addr(1), ...inventoryAbi.encodeEventLog(inventoryAbi.getEvent('CollectionTokenIndexed'), [9n, e.tokenId, e.collectionSerial, e.prefixHash]), index, transactionHash: txHash, blockNumber: 51, blockHash: hash51, removed: false }));
    if (mode === 'safe') { const abi = indexed ? safe : legacySafe; logs.push({ address: caller, ...abi.encodeEventLog(abi.getEvent('ExecutionSuccess'), [id('safe-index'), 0n]), index: logs.length, transactionHash: txHash, blockNumber: 51, blockHash: hash51, removed: false }); }
    state.tx = { hash: txHash, blockNumber: 51, blockHash: hash51, from: mode === 'safe' ? addr(99) : caller, to: mode === 'safe' ? caller : addr(1), value: 0n, data: mode === 'safe' ? safe.encodeFunctionData('execTransaction', [addr(1), 0n, plan.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']) : plan.call.data };
    state.receipt = { hash: txHash, status: 1, blockNumber: 51, blockHash: hash51, logs }; return { transactionHash: txHash, execution: mode };
  }
  return { deployment, coordinates, caller, facts, before, after, state, provider, commit };
}
async function capture(f) { return api.captureCollectionInventory(f.provider, f.deployment, 9n, { blockTag: 50 }); }
function prefix(f, entries, cursor) { let hash = pure.collectionInventoryEmptyPrefix(f.coordinates); const indexed = entries.map((e, i) => { hash = pure.collectionInventoryAppendPrefix(hash, e.collectionSerial, e.tokenId); return { ordinal: BigInt(i), tokenId: e.tokenId, collectionSerial: e.collectionSerial, prefixHash: hash }; }); return { checkpoint: { indexedCount: BigInt(entries.length), prefixHash: hash, lastIndexedSerial: entries.at(-1)?.collectionSerial ?? 0n, scanThrough: cursor }, entries: indexed }; }

test('capture distinguishes completed ordinal from actual serial and separately checks current completeness', async () => {
  const f = setup(); Object.assign(f.before, prefix(f, [f.facts.get(2n)], 3n)); const c = await capture(f);
  assert.equal(c.checkpoint.indexedCount, 1n); assert.equal(c.checkpoint.lastIndexedSerial, 2n); assert.equal(c.lastIndexedToken.tokenId, 2n); assert.equal(c.complete, false);
  assert.ok(Object.isFrozen(c.deployment.core)); assert.ok(!f.state.requests.some(r => r.data.startsWith(inventoryAbi.getFunction('requireCompleteCollection').selector)));
  Object.assign(f.before, prefix(f, [f.facts.get(2n), f.facts.get(4n)], 6n)); assert.equal((await capture(f)).complete, true);
});
test('bounded scan crosses abort gaps, skips prepared other-collection identities and retains burned history', async () => {
  const f = setup(), c = await capture(f), p = api.prepareCollectionInventoryScan(c, f.caller, 6n), result = await api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 50 });
  assert.deepEqual(result.replay.indexed.map(e => [e.ordinal, e.tokenId, e.collectionSerial]), [[0n, 2n, 2n], [1n, 4n, 4n]]);
  assert.equal(result.replay.after.scanThrough, 6n); assert.equal(result.identities.length, 6); assert.equal(result.identities[3].burned, true);
  const parsed = inventoryAbi.parseTransaction({ data: p.call.data }); assert.equal(parsed.name, 'scanCollectionTokens'); assert.equal(parsed.args[1], 6n); assert.equal(p.call.value, 0n);
});
test('fast append rejects actual serial gaps but accepts interleaved global token IDs with consecutive actual serials', async () => {
  const f = setup(), c = await capture(f), bad = api.prepareCollectionInventoryAppend(c, f.caller, [2n]); await assert.rejects(api.simulateCollectionInventoryOperation(f.provider, bad, { blockTag: 50 }));
  Object.assign(f.before, prefix(f, [f.facts.get(2n)], 2n)); f.facts.set(4n, token(4n, 9n, 3n, 3n)); const prior = await capture(f), plan = api.prepareCollectionInventoryAppend(prior, f.caller, [4n]);
  const simulated = await api.simulateCollectionInventoryOperation(f.provider, plan, { blockTag: 50 }); assert.equal(simulated.replay.after.indexedCount, 2n); assert.equal(simulated.replay.after.lastIndexedSerial, 3n);
  const evidence = f.commit(plan, simulated.replay); const receipt = await api.inspectCollectionInventoryOperationReceipt(f.provider, plan, evidence); assert.equal(receipt.events.length, 1);
});
test('a target prepared token blocks scan atomically even when empty inventory is currently complete', async () => {
  const f = setup(); f.before.frontier = 1n; f.before.mintedEver = 0n; f.facts.set(1n, token(1n, 9n, 1n, 1n)); const c = await capture(f); assert.equal(c.complete, true);
  const p = api.prepareCollectionInventoryScan(c, f.caller, 1n); await assert.rejects(api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 50 }), /prepared/i); assert.equal(f.before.checkpoint.indexedCount, 0n);
});
test('scan at frontier is a valid zero-fact no-op; all bounds stay 1..256', async () => {
  const f = setup(); Object.assign(f.before, prefix(f, [f.facts.get(2n), f.facts.get(4n)], 6n)); const c = await capture(f), p = api.prepareCollectionInventoryScan(c, f.caller, 256n);
  const r = await api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 50 }); assert.deepEqual(r.identities, []); assert.deepEqual(r.replay.after, c.checkpoint);
  for (const n of [0n, 257n]) assert.throws(() => api.prepareCollectionInventoryScan(c, f.caller, n)); assert.throws(() => api.prepareCollectionInventoryAppend(c, f.caller, []));
});
test('strict identity words, missing collection, changed code, trailing reads and stale captured frontier fail closed', async () => {
  for (const change of [
    f => f.state.overrides.collectionExists = () => [false],
    f => f.provider.getCode = async () => '0x6001',
    f => f.state.overrides.collectionInventoryState = () => inventoryAbi.encodeFunctionResult('collectionInventoryState', [0n, pure.collectionInventoryEmptyPrefix(f.coordinates)]) + '00'.repeat(32),
    f => f.state.reorg = true,
  ]) { const f = setup(); change(f); await assert.rejects(capture(f)); }
  const f = setup(), p = api.prepareCollectionInventoryScan(await capture(f), f.caller, 1n); f.state.overrides.tokenCollectionIdentity = () => coder.encode(['uint256', 'uint256', 'uint256', 'uint256'], [2n, 9n, 1n, 0n]); await assert.rejects(api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 50 }));
  const g = setup(), q = api.prepareCollectionInventoryScan(await capture(g), g.caller, 2n); g.after.frontier = 7n; await assert.rejects(api.simulateCollectionInventoryOperation(g.provider, q, { blockTag: 51 }), /frontier\/minted/);
});
test('saved-prefix membership verifies original block/prefix and dense ordinal, never current serial lookup alone', async () => {
  const f = setup(); Object.assign(f.before, prefix(f, [f.facts.get(2n)], 3n)); Object.assign(f.after, prefix(f, [f.facts.get(2n), f.facts.get(4n)], 6n)); const saved = await capture(f);
  const member = await api.inspectCollectionInventoryPrefixMember(f.provider, saved, { collectionSerial: 2n, blockTag: 51 }); assert.equal(member.status, 'member'); assert.equal(member.ordinal, 0n);
  const later = await api.inspectCollectionInventoryPrefixMember(f.provider, saved, { collectionSerial: 4n, blockTag: 51 }); assert.equal(later.status, 'outside-prefix'); assert.equal(later.lookupTokenId, 4n);
  const missing = await api.inspectCollectionInventoryPrefixMember(f.provider, saved, { collectionSerial: 1n, blockTag: 51 }); assert.equal(missing.status, 'not-indexed'); assert.equal(missing.ordinal, null); assert.ok(!('aborted' in missing));
  const bad = structuredClone(saved); bad.checkpoint.prefixHash = id('forged'); await assert.rejects(api.inspectCollectionInventoryPrefixMember(f.provider, bad, { collectionSerial: 2n, blockTag: 51 }), /historical block changed/);
});
test('direct and both Safe event layouts join exact scan replay while later same-block mints/indexing remain observations', async () => {
  for (const [mode, indexed] of [['direct', true], ['safe', true], ['safe', false]]) {
    const f = setup(), p = api.prepareCollectionInventoryScan(await capture(f), f.caller, 4n), sim = await api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 50 }), evidence = f.commit(p, sim.replay, mode, indexed);
    f.facts.set(7n, token(7n, 9n, 5n)); Object.assign(f.after, prefix(f, [f.facts.get(2n), f.facts.get(4n), f.facts.get(7n)], 7n)); f.after.frontier = 7n; f.after.mintedEver = 3n;
    const r = await api.inspectCollectionInventoryOperationReceipt(f.provider, p, evidence); assert.equal(r.replay.after.scanThrough, 4n); assert.equal(r.observed.checkpoint.scanThrough, 7n); assert.equal(r.observed.checkpoint.indexedCount, 3n); assert.equal(r.cursorAttribution, 'not-proven');
  }
});
test('zero-event cursor-only scan receipt does not attribute receipt-block progress to this transaction', async () => {
  const f = setup(), p = api.prepareCollectionInventoryScan(await capture(f), f.caller, 1n), sim = await api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 50 }), evidence = f.commit(p, sim.replay);
  Object.assign(f.after, prefix(f, [f.facts.get(2n), f.facts.get(4n)], 6n)); const result = await api.inspectCollectionInventoryOperationReceipt(f.provider, p, evidence);
  assert.deepEqual(result.events, []); assert.equal(result.replay.after.scanThrough, 1n); assert.equal(result.observed.checkpoint.scanThrough, 6n); assert.equal(result.cursorAttribution, 'not-proven');
});
test('receipt rejects stale event prefix, missing/malformed events, Safe failure, wrong CALL and orphaned block', async () => {
  for (const mutate of [
    f => f.state.receipt.logs.pop(),
    f => f.state.receipt.logs[0].data += '00'.repeat(32),
    f => f.state.tx.from = addr(50),
    f => f.state.receipt.blockHash = id('orphan'),
    f => { const ev = inventoryAbi.encodeEventLog(inventoryAbi.getEvent('CollectionTokenIndexed'), [9n, 2n, 2n, id('stale-prefix')]); Object.assign(f.state.receipt.logs[0], ev); },
  ]) { const f = setup(), p = api.prepareCollectionInventoryScan(await capture(f), f.caller, 4n), r = await api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 50 }), e = f.commit(p, r.replay); mutate(f); await assert.rejects(api.inspectCollectionInventoryOperationReceipt(f.provider, p, e)); }
  const f = setup(), p = api.prepareCollectionInventoryScan(await capture(f), f.caller, 1n), r = await api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 50 }), e = f.commit(p, r.replay, 'safe'); f.state.receipt.logs[0].topics[0] = safe.getEvent('ExecutionFailure').topicHash; await assert.rejects(api.inspectCollectionInventoryOperationReceipt(f.provider, p, e), /ExecutionSuccess/);
});
test('all mutable plans are reconstructed before the first await', async () => {
  const f = setup(), original = api.prepareCollectionInventoryScan(await capture(f), f.caller, 4n), input = structuredClone(original); f.state.onNetwork = () => { input.capture.checkpoint.scanThrough = 99n; input.maxScan = 256n; input.call.value = 1n; };
  const result = await api.simulateCollectionInventoryOperation(f.provider, input, { blockTag: 50 }); assert.equal(result.plan.maxScan, 4n); assert.equal(result.plan.call.value, 0n); assert.ok(Object.isFrozen(result.identities));
});
test('simulation cannot predate capture and receipt requires a strictly earlier checkpoint even for zero events', async () => {
  const f = setup(); Object.assign(f.before, prefix(f, [f.facts.get(2n), f.facts.get(4n)], 6n)); const p = api.prepareCollectionInventoryScan(await capture(f), f.caller, 1n);
  await assert.rejects(api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 49 }), /predates/);
  const r = await api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 50 }), e = f.commit(p, r.replay);
  f.state.tx.blockNumber = 50; f.state.tx.blockHash = hash50; f.state.receipt.blockNumber = 50; f.state.receipt.blockHash = hash50;
  await assert.rejects(api.inspectCollectionInventoryOperationReceipt(f.provider, p, e), /strictly earlier/);
});
test('eventless receipts still bind unchanged prefix and saved last ordinal when observation extends', async () => {
  const f = setup(); Object.assign(f.before, prefix(f, [f.facts.get(2n), f.facts.get(4n)], 6n)); const p = api.prepareCollectionInventoryScan(await capture(f), f.caller, 1n), r = await api.simulateCollectionInventoryOperation(f.provider, p, { blockTag: 50 }), e = f.commit(p, r.replay);
  f.after.checkpoint = { ...f.after.checkpoint, prefixHash: id('contradictory-prefix') };
  await assert.rejects(api.inspectCollectionInventoryOperationReceipt(f.provider, p, e), /retained prefix/);
  const g = setup(); Object.assign(g.before, prefix(g, [g.facts.get(2n)], 3n)); g.before.frontier = 3n; g.before.mintedEver = 1n;
  const q = api.prepareCollectionInventoryScan(await capture(g), g.caller, 1n), qr = await api.simulateCollectionInventoryOperation(g.provider, q, { blockTag: 50 }), qe = g.commit(q, qr.replay);
  Object.assign(g.after, prefix(g, [g.facts.get(2n), g.facts.get(4n)], 6n));
  g.after.entries[0] = { ...g.after.entries[0], tokenId: 1n };
  await assert.rejects(api.inspectCollectionInventoryOperationReceipt(g.provider, q, qe), /saved final ordinal/);
});
