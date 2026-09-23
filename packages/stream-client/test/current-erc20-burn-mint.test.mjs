import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as api from '../dist/current-erc20-burn-mint.js';
import * as signing from '../dist/current-erc20-burn-mint-signing.js';
import { burnMintNullifier } from '../dist/current-burn-mint.js';
const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/current-erc20-burn-mint-abi.json', import.meta.url), 'utf8'));
const abis = Object.fromEntries(Object.entries(fixture.abis).map(([k, v]) => [k, new Interface(v)]));
const coder = AbiCoder.defaultAbiCoder();
const addr = n => getAddress(`0x${n.toString(16).padStart(40, '0')}`);
const code = '0x6000', codeHash = keccak256(code), blockHash = id('inspection'), minedHash = id('mined'), txHash = id('funding-tx');
const clone = v => structuredClone(v);
function setup({ nonpayer = false } = {}) {
  const deployment = { chainId: 1n, ...Object.fromEntries(['adapter', 'core', 'moduleRegistry', 'manager', 'ledger', 'gate', 'payment', 'recorder', 'asset'].map((k, i) => [k, { address: addr(i + 1), codeHash }])) };
  const d = deployment, executor = addr(30), payer = nonpayer ? addr(31) : executor, recipient = addr(32), artist = addr(33), owner = addr(34);
  const configuration = { paymentAdapter: d.payment.address, collectionId: 9n, phaseId: id('phase'), asset: d.asset.address, price: 100n, startsAt: 100n, endsAt: 1000n, mintPolicyHash: id('bound-policy'), expectedPrimaryPolicyHash: id('profile-policy') };
  const saleId = signing.erc20BurnMintSaleId(1n, d.adapter.address, 9n, configuration.phaseId, 1n);
  const authorization = { saleId, saleConfigHash: signing.erc20BurnMintConfigurationHash(saleId, configuration), payer, executor, recipient, artist, tokenDataHash: keccak256('0x1234'), mintCommitment: id('commitment'), executionNonce: 3n, nonce: ZeroHash, deadline: 900n };
  const execution = { sale: { authorization, tokenData: '0x1234', platformSignature: '0xab', artistSignature: '0xcd' }, sourceTokenIds: [11n, 12n] };
  const prepared = api.prepareERC20BurnMintExecution(d, configuration, execution);
  const programConfig = { manager: d.manager.address, targetCollectionId: 9n, phaseId: configuration.phaseId, sourceCollectionIds: [1n, 2n], sourcesPerMint: 2n, startsAt: 90n, endsAt: 0n, prepared: false, nativeSaleAdapter: ZeroAddress };
  const program = { config: programConfig, configHash: signing.erc20BurnMintProgramConfigHash(1n, d.gate.address, d.core.address, d.moduleRegistry.address, programConfig), managerCodeHash: codeHash, nativeSaleCodeHash: ZeroHash };
  const sale = { config: configuration, saleNonce: 1n, configHash: authorization.saleConfigHash, lifecycle: { paymentAdapter: d.payment.address, saleCreatedAt: 100n, saleAdapterRegistryRevision: 1n, paymentAdapterRegistryRevision: 1n }, cancelled: false };
  const candidate = {
    saleAdapter: d.adapter.address, executor, sale: { settlementId: saleId, revenueClass: id('PRIMARY_SALE'), policyMode: 0n, collectionId: 9n, tokenId: 0n, saleNonce: 1n, payer, poster: ZeroAddress, beneficiary: recipient, amount: 100n, expectedPrimaryPolicyHash: configuration.expectedPrimaryPolicyHash },
    lifecycleBinding: sale.lifecycle, executionBinding: { executionId: ZeroHash, executionNonce: 3n, authorityMode: 1n, saleAuthorizationDigest: prepared.signing.contextHash }, asset: d.asset.address, orchestrationOrder: 1n, mintManager: d.manager.address,
    operationIdentityCommitment: id('operation-root'), operationId: id('operation-id'), currentPolicyHash: id('different-current-policy-during-grace'), boundPolicyHash: configuration.mintPolicyHash,
    rights: { profileId: id('profile'), wallet: addr(35), templateId: ZeroHash, assignmentHash: id('assignment'), entriesHash: id('entries') }, saleExecutionHash: prepared.signing.saleExecutionHash,
  };
  candidate.executionBinding.executionId = signing.erc20BurnMintExecutionId(1n, candidate);
  const sources = execution.sourceTokenIds.map((tokenId, i) => ({ tokenId, collectionId: BigInt(i + 1), collectionSerial: BigInt(i + 5), owner, approved: d.gate.address, executorOperatorApproved: true, gateOperatorApproved: false, nullifier: burnMintNullifier(1n, d.core.address, tokenId) }));
  const capture = { prepared, blockNumber: 50, blockHash, sale, program, sources, candidate };
  const intent = { payer, asset: d.asset.address, maxAmount: 100n, saleRef: saleId, expectedPrimaryPolicyHash: configuration.expectedPrimaryPolicyHash, nonce: ZeroHash, deadline: 900n };
  const route = nonpayer ? { kind: 'intent', intent, signature: '0x1122' } : { kind: 'payer' };
  const plan = api.prepareERC20BurnMintFunding(capture, route);
  const settlement = { candidateCommitment: plan.candidateCommitment, settlementKey: plan.settlementKey, profileId: candidate.rights.profileId, wallet: candidate.rights.wallet, asset: candidate.asset, amount: 100n, executor, executionId: candidate.executionBinding.executionId, escrowed: true, operationIdentityCommitment: candidate.operationIdentityCommitment, currentPolicyHash: candidate.currentPolicyHash, boundPolicyHash: candidate.boundPolicyHash };
  const state = { completed: false, overrides: {}, requests: [], blockChanges: false, headerCalls: 0, networkHook: null, receipt: null, tx: null };
  const roles = Object.fromEntries(Object.entries(d).filter(([k]) => k !== 'chainId').map(([k, p]) => [p.address, k === 'adapter' ? 'sale' : k === 'asset' ? 'token' : k]));
  function values(role, name, args) {
    if (state.overrides[`${role}.${name}`]) return state.overrides[`${role}.${name}`](args);
    const read = {
      core: d.core.address, coreCodeHash: codeHash, moduleRegistry: d.moduleRegistry.address, moduleRegistryCodeHash: codeHash, registryCodeHash: codeHash,
      mintManager: d.manager.address, mintManagerCodeHash: codeHash, primarySaleSettlement: d.recorder.address, settlementCodeHash: codeHash,
      erc20SaleAdapter: d.adapter.address, erc20SaleCodeHash: codeHash, mintLedger: d.ledger.address,
    };
    if (name in read) return [read[name]];
    if (name === 'getSatellitePointer') return [args[0] === id('MODULE_REGISTRY') ? d.moduleRegistry.address : d.manager.address, codeHash, false, ZeroHash, '0x00000000', ZeroAddress, 0n, ZeroHash, ZeroHash, 1n];
    if (name === 'saleRecord') return [sale];
    if (name === 'program') return [program];
    if (name === 'allowedSourceCollections') return [programConfig.sourceCollectionIds];
    if (name === 'saleBurnGate') return [d.gate.address, codeHash, program.configHash];
    if (name === 'authorizationDigest') return [prepared.signing.contextHash];
    if (name === 'paused' || name === 'collectionBurnsBlocked' || name === 'collectionFreezeStatus') return [false];
    if (name === 'executionIdByNonce') return [state.completed ? candidate.executionBinding.executionId : ZeroHash];
    if (name === 'executionStatus') return [state.completed ? 2n : 0n];
    if (['authorizationUsed', 'isAuthorizationUsed', 'isManagerAuthorizationUsed', 'isNullifierUsed', 'isManagerNullifierUsed', 'isOperationRootUsed', 'isManagerOperationRootUsed', 'settlementConsumed', 'isPaymentIntentNonceUsed'].includes(name)) return [state.completed];
    if (name === 'tokenCollectionIdentity') {
      if (args[0] === 90n) return [true, 9n, 15n, false];
      const s = sources.find(s => s.tokenId === args[0]); return [true, s.collectionId, s.collectionSerial, state.completed];
    }
    if (name === 'ownerOf') return [owner];
    if (name === 'getApproved') return [d.gate.address];
    if (name === 'isApprovedForAll') return [args[1] === executor];
    if (name === 'burnNullifier') return [burnMintNullifier(1n, d.core.address, args[0])];
    if (name === 'previewExecution') return [candidate];
    if (name === 'paymentIntentDigest') return [signing.erc20BurnMintPaymentIntentPayload(1n, configuration, authorization, intent).digest];
    if (name.startsWith('settleERC20') || name === 'settlementResult') return [settlement];
    throw Error(`Unmocked ${role}.${name}`);
  }
  const provider = {
    async getNetwork() { state.networkHook?.(); return { chainId: 1n }; },
    async getCode() { return code; },
    async getBlock(n) { state.headerCalls++; return { number: n, hash: state.blockChanges && state.headerCalls > 1 ? id('reorg') : n === 50 ? blockHash : minedHash, timestamp: 500 }; },
    async call(req) {
      state.requests.push(req); assert.ok(req.blockTag === 50 || req.blockTag === 51); assert.equal(req.value, 0n);
      const role = roles[req.to], abi = abis[role], parsed = abi.parseTransaction({ data: req.data });
      if (parsed.name === 'previewExecution' || parsed.name.startsWith('settleERC20')) assert.equal(req.from, executor);
      const result = values(role, parsed.name, parsed.args);
      if (typeof result === 'string') return result;
      return abi.encodeFunctionResult(parsed.name, result);
    },
    async getTransaction() { return state.tx; }, async getTransactionReceipt() { return state.receipt; },
  };
  return { d, configuration, execution, prepared, program, sale, candidate, capture, sources, intent, plan, settlement, provider, state, executor, payer, recipient, artist, owner };
}
function receipt(f, mode = 'direct') {
  const { d, candidate: c, plan: p, prepared, sources, execution, recipient, owner } = f, a = execution.sale.authorization;
  const logs = [];
  const emit = (role, name, values) => { const encoded = abis[role].encodeEventLog(abis[role].getEvent(name), values); logs.push({ address: d[role === 'sale' ? 'adapter' : role].address, ...encoded, index: logs.length, blockNumber: 51, blockHash: minedHash, transactionHash: txHash, removed: false }); };
  const root = c.operationIdentityCommitment, eid = c.executionBinding.executionId, config = f.configuration, aid = prepared.signing.authorizationId;
  const batch = [9n, config.phaseId, a.payer, ZeroAddress, [recipient], [recipient], [execution.sale.tokenData], [a.mintCommitment], config.mintPolicyHash, aid, prepared.signing.contextHash, '0x'];
  const gateHash = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'address', 'bytes32', 'address', abis.gate.getFunction('previewERC20Burn').inputs[0], 'uint256[]', 'address[]', 'uint256[]', 'uint256[]', 'bytes32[]'], [id('6529STREAM_BURN_MINT_RESULT_V1'), 1n, d.gate.address, d.core.address, f.program.configHash, a.executor, batch, sources.map(s => s.tokenId), sources.map(s => s.owner), sources.map(s => s.collectionId), sources.map(s => s.collectionSerial), sources.map(s => s.nullifier)]));
  if (p.route.kind === 'intent') emit('payment', 'PaymentIntentConsumed', [a.payer, a.saleId, p.route.intent.nonce, 1n, c.asset, c.sale.amount]);
  emit('sale', 'UniversalSaleExecution', [a.saleId, eid, root, 1n, 1n, ZeroHash, 0n]);
  for (const s of sources) { emit('core', 'Transfer', [owner, ZeroAddress, s.tokenId]); emit('core', 'StreamTokenBurned', [s.tokenId, s.collectionId, s.collectionSerial, 1n]); }
  emit('recorder', 'PrimaryRevenueSettled', [p.settlementKey, c.sale.revenueClass, c.rights.profileId, 1n, c.rights.wallet, c.asset, a.payer, c.sale.amount, keccak256(coder.encode([abis.sale.getFunction('previewExecution').outputs[0].components.find(t => t.name === 'sale')], [c.sale])), false, 1n]);
  emit('recorder', 'PrimaryRevenueSettlementContext', [p.settlementKey, c.sale.revenueClass, c.rights.profileId, 1n, d.adapter.address, a.saleId, 0n, 9n, 0n, root, c.operationId, 1n, ZeroAddress, recipient, ZeroHash]);
  emit('recorder', 'PrimaryRevenueSettlementPolicy', [p.settlementKey, c.sale.revenueClass, c.rights.profileId, 1n, config.expectedPrimaryPolicyHash, config.expectedPrimaryPolicyHash, c.rights.assignmentHash, ZeroHash]);
  emit('recorder', 'PrimaryRevenueExecutionBound', [p.settlementKey, d.adapter.address, eid, 1n, a.executor, d.payment.address, p.candidateCommitment, c.currentPolicyHash, c.boundPolicyHash]);
  emit('manager', 'MintGateValidated', [9n, config.phaseId, d.gate.address, aid, ZeroAddress, 1n, prepared.signing.contextHash, gateHash, c.boundPolicyHash]);
  emit('ledger', 'MintLedgerAuthorizationConsumed', [1n, aid, root, d.manager.address, c.boundPolicyHash]);
  for (const s of sources) emit('ledger', 'MintLedgerNullifierConsumed', [1n, s.nullifier, root, d.manager.address, c.boundPolicyHash]);
  emit('ledger', 'MintLedgerOperationRootConsumed', [1n, root, d.manager.address, c.currentPolicyHash, c.boundPolicyHash, aid]);
  emit('core', 'Transfer', [ZeroAddress, recipient, 90n]);
  emit('core', 'Transfer', [recipient, addr(99), 90n]); // Receiver callback transfers output; original recipient still valid.
  emit('manager', 'MintTokenExecuted', [1n, c.operationId, 90n, root, 9n, config.phaseId, 0n, recipient, recipient, a.tokenDataHash, a.mintCommitment]);
  emit('manager', 'MintAuthorizationConsumed', [1n, 9n, config.phaseId, aid, c.boundPolicyHash, root]);
  emit('manager', 'MintBatchExecuted', [1n, root, 9n, config.phaseId, d.adapter.address, a.payer, ZeroAddress, 90n, 1n, prepared.signing.contextHash, gateHash, c.currentPolicyHash, c.boundPolicyHash]);
  for (const s of sources) emit('gate', 'BurnMintExecuted', [1n, s.tokenId, 90n, 9n, s.nullifier, a.executor]);
  emit('gate', 'BurnMintBatchExecuted', [1n, 9n, root, a.executor, sources.map(s => s.tokenId), sources.map(s => s.owner), [90n]]);
  emit('sale', 'UniversalSaleExecution', [a.saleId, eid, root, 1n, 2n, p.settlementKey, 90n]);
  const safe = new Interface(['function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)']);
  f.state.tx = { hash: txHash, blockNumber: 51, blockHash: minedHash, value: 0n, from: mode === 'safe' ? addr(80) : f.executor, to: mode === 'safe' ? f.executor : p.call.to, data: mode === 'safe' ? safe.encodeFunctionData('execTransaction', [p.call.to, 0n, p.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']) : p.call.data };
  f.state.receipt = { hash: txHash, status: 1, blockNumber: 51, blockHash: minedHash, logs };
  if (mode === 'safe') { const abi = new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']); const encoded = abi.encodeEventLog(abi.getEvent('ExecutionSuccess'), [id('safe-tx-hash'), 0n]); logs.push({ address: f.executor, ...encoded, index: logs.length, blockNumber: 51, blockHash: minedHash, transactionHash: txHash, removed: false }); }
  f.state.completed = true; return { transactionHash: txHash, execution: mode };
}

test('pinned canonical capture joins program, roles, original zero nonce and nonpayable actual-caller preview', async () => {
  const f = setup({ nonpayer: true }); const result = await api.inspectERC20BurnMintExecution(f.provider, f.prepared, { blockTag: 50 });
  assert.deepEqual(result, f.capture); assert.ok(Object.isFrozen(result.prepared.deployment.asset)); assert.ok(Object.isFrozen(result.sources));
  assert.notEqual(result.candidate.sale.payer, result.candidate.sale.beneficiary); assert.notEqual(result.candidate.currentPolicyHash, result.candidate.boundPolicyHash);
  const preview = f.state.requests.find(r => r.data.startsWith(abis.sale.getFunction('previewExecution').selector)); assert.equal(preview.from, f.executor); assert.equal(preview.value, 0n);
});
test('capture clones all mutable input before getNetwork yields', async () => {
  const f = setup(), input = clone(f.prepared); f.state.networkHook = () => { input.signing.execution.sourceTokenIds[0] = 99n; input.deployment.core.codeHash = id('changed'); input.signing.configuration.price = 200n; };
  const out = await api.inspectERC20BurnMintExecution(f.provider, input, { blockTag: 50 }); assert.deepEqual(out, f.capture);
});
test('source executor and gate authorities are independently required', async () => {
  const f = setup(); f.state.overrides['core.isApprovedForAll'] = () => [false];
  await assert.rejects(api.inspectERC20BurnMintExecution(f.provider, f.prepared, { blockTag: 50 }), /independent NFT authority/);
  delete f.state.overrides['core.isApprovedForAll']; f.state.overrides['core.getApproved'] = () => [ZeroAddress];
  await assert.rejects(api.inspectERC20BurnMintExecution(f.provider, f.prepared, { blockTag: 50 }), /independent NFT authority/);
});
test('capture fails closed on noncanonical data, code drift, identity, replay and reorg', async () => {
  for (const [name, value, pattern] of [['sale.saleRecord', () => abis.sale.encodeFunctionResult('saleRecord', [setup().sale]) + '00'.repeat(32), /Noncanonical/], ['core.tokenCollectionIdentity', () => [true, 999n, 5n, false], /Source identity/], ['sale.authorizationUsed', () => [true], /already consumed/], ['sale.authorizationDigest', () => [id('wrong')], /digest identity/]]) {
    const f = setup(); f.state.overrides[name] = value; await assert.rejects(api.inspectERC20BurnMintExecution(f.provider, f.prepared, { blockTag: 50 }), pattern);
  }
  const f = setup(); f.provider.getCode = async () => '0x6001'; await assert.rejects(api.inspectERC20BurnMintExecution(f.provider, f.prepared, { blockTag: 50 }), /Runtime code/);
  const g = setup(); g.state.blockChanges = true; await assert.rejects(api.inspectERC20BurnMintExecution(g.provider, g.prepared, { blockTag: 50 }), /block changed/);
});
test('all four funding routes encode exact original compiled contract20 calls and simulate from executor', async () => {
  const f = setup(); const routes = [{ kind: 'payer' }, { kind: 'intent', intent: f.intent, signature: '0x11' }, { kind: 'eip2612', permit: { deadline: 900n, v: 27n, r: id('r'), s: id('s') } }, { kind: 'permit2', permit: { nonce: 0n, deadline: 900n, signature: '0xab' } }];
  const names = ['settleERC20PrimarySaleByPayer', 'settleERC20PrimarySaleWithIntent', 'settleERC20PrimarySaleWithEIP2612Permit', 'settleERC20PrimarySaleWithPermit2'];
  for (const [i, route] of routes.entries()) {
    const p = api.prepareERC20BurnMintFunding(f.capture, route), parsed = abis.payment.parseTransaction({ data: p.call.data }); assert.equal(parsed.name, names[i]); assert.equal(parsed.args.at(-1), f.prepared.signing.saleExecutionData); assert.equal(p.caller, f.executor); assert.equal(p.call.value, 0n);
    assert.deepEqual(await api.simulateERC20BurnMintFunding(f.provider, p, { blockTag: 50 }), f.settlement);
  }
  const g = setup({ nonpayer: true }); assert.throws(() => api.prepareERC20BurnMintFunding(g.capture, { kind: 'payer' }), /requires.*payer/);
  assert.deepEqual(await api.simulateERC20BurnMintFunding(g.provider, g.plan, { blockTag: 50 }), g.settlement);
});
test('modified capture facts and stale candidates cannot survive funding reconstruction/simulation', async () => {
  for (const change of [p => p.sale.cancelled = true, p => p.sale.configHash = id('wrong'), p => p.program.managerCodeHash = id('wrong'), p => p.program.nativeSaleCodeHash = id('wrong'), p => p.sources[0].executorOperatorApproved = false]) {
    const f = setup(), p = clone(f.capture); change(p); assert.throws(() => api.prepareERC20BurnMintFunding(p, { kind: 'payer' }), /Capture/);
  }
  const f = setup(), changed = clone(f.plan); changed.call.value = 1n; await assert.rejects(api.simulateERC20BurnMintFunding(f.provider, changed, { blockTag: 50 }), /canonical reconstruction/);
  const g = setup(); g.state.overrides['core.ownerOf'] = () => [addr(89)]; await assert.rejects(api.simulateERC20BurnMintFunding(g.provider, g.plan, { blockTag: 50 }), /source approval\/identity/);
  const h = setup(); h.state.overrides['sale.previewExecution'] = () => [{ ...h.candidate, operationId: id('changed') }]; await assert.rejects(api.simulateERC20BurnMintFunding(h.provider, h.plan, { blockTag: 50 }), /preview differs/);
});
test('failed simulation has no client side effects and identical signatures/candidate can be retried', async () => {
  const f = setup(); f.state.overrides['sale.previewExecution'] = () => { throw Error('transient dependency unavailable'); };
  await assert.rejects(api.simulateERC20BurnMintFunding(f.provider, f.plan, { blockTag: 50 }), /transient/);
  delete f.state.overrides['sale.previewExecution']; assert.deepEqual(await api.simulateERC20BurnMintFunding(f.provider, f.plan, { blockTag: 50 }), f.settlement);
});
test('exact direct and Safe CALL receipts join original burns, mint, ledger and settlement, allowing recipient transfer', async () => {
  for (const mode of ['direct', 'safe']) {
    const f = setup({ nonpayer: true }), evidence = receipt(f, mode); const result = await api.inspectERC20BurnMintFundingReceipt(f.provider, f.plan, evidence);
    assert.equal(result.tokenId, 90n); assert.equal(result.operationId, f.candidate.operationId); assert.deepEqual(result.settlement, f.settlement); assert.equal(result.events.length, mode === 'safe' ? 24 : 23);
    assert.ok(Object.isFrozen(result.prepared.capture.sources[0])); assert.ok(result.events.every(e => e.transactionHash === txHash && e.blockHash === minedHash));
    assert.ok(!f.state.requests.some(r => r.data.startsWith(abis.sale.getFunction('previewExecution').selector)));
  }
});
test('receipts reject wrong envelope, duplicate/trailing logs, retained identities and replay mismatch', async () => {
  for (const corrupt of [f => f.state.tx.to = addr(88), f => f.state.receipt.logs[0].data += '00'.repeat(32), f => f.state.receipt.logs[0].blockHash = id('orphan'), f => f.state.overrides['ledger.isManagerNullifierUsed'] = () => [false], f => f.state.overrides['core.tokenCollectionIdentity'] = () => [true, 9n, 1n, false]]) {
    const f = setup(), evidence = receipt(f); corrupt(f); await assert.rejects(api.inspectERC20BurnMintFundingReceipt(f.provider, f.plan, evidence));
  }
  const f = setup(), evidence = receipt(f, 'safe'), safe = new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)']);
  f.state.tx.data = safe.encodeFunctionData('execTransaction', [f.plan.call.to, 0n, f.plan.call.data, 1n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']); await assert.rejects(api.inspectERC20BurnMintFundingReceipt(f.provider, f.plan, evidence), /ordinary zero CALL/);
});
test('immutable program and sale configuration receipts bind original identity/events and receipt-block readback', async () => {
  for (const kind of ['configureProgram', 'registerSale']) {
    const f = setup(), action = kind === 'configureProgram' ? { target: 'gate', kind, configuration: f.program.config } : { target: 'sale', kind, configuration: f.configuration, expectedNonce: 1n };
    const p = api.prepareERC20BurnMintAction(f.d, f.executor, action), role = kind === 'configureProgram' ? 'gate' : 'sale', event = kind === 'configureProgram' ? 'BurnMintProgramConfigured' : 'UniversalSaleConfigured';
    f.sale.lifecycle.saleCreatedAt = 500n;
    const values = kind === 'configureProgram' ? [1n, 9n, f.d.manager.address, f.configuration.phaseId, p.expectedIdentity, f.program.config] : [p.expectedIdentity, 9n, f.configuration.phaseId, 1n, 1n, f.sale.configHash, f.d.payment.address];
    const encoded = abis[role].encodeEventLog(abis[role].getEvent(event), values);
    f.state.tx = { hash: txHash, blockNumber: 51, blockHash: minedHash, value: 0n, from: f.executor, to: p.call.to, data: p.call.data };
    f.state.receipt = { hash: txHash, status: 1, blockNumber: 51, blockHash: minedHash, logs: [{ address: p.call.to, ...encoded, index: 0, transactionHash: txHash, blockNumber: 51, blockHash: minedHash, removed: false }] };
    const out = await api.inspectERC20BurnMintActionReceipt(f.provider, p, { transactionHash: txHash, execution: 'direct' }); assert.equal(out.events[0].event, event);
    f.state.receipt.logs[0].data += '00'.repeat(32); await assert.rejects(api.inspectERC20BurnMintActionReceipt(f.provider, p, { transactionHash: txHash, execution: 'direct' }), /Noncanonical/);
  }
});

test('Safe receipt requires canonical success without failure; intent requires exact consumed event', async () => {
  for (const corrupt of [
    f => f.state.receipt.logs.pop(),
    f => { f.state.receipt.logs.at(-1).topics[0] = id('ExecutionFailure(bytes32,uint256)'); },
    f => { f.state.receipt.logs.at(-1).data += '00'.repeat(32); },
  ]) {
    const f = setup({ nonpayer: true }), evidence = receipt(f, 'safe'); corrupt(f); await assert.rejects(api.inspectERC20BurnMintFundingReceipt(f.provider, f.plan, evidence), /Safe|Noncanonical|data|BUFFER|fragment|offset/i);
  }
  const f = setup({ nonpayer: true }), evidence = receipt(f); f.state.receipt.logs.shift();
  await assert.rejects(api.inspectERC20BurnMintFundingReceipt(f.provider, f.plan, evidence), /PaymentIntentConsumed/);
  const g = setup({ nonpayer: true }), e = receipt(g); const original = g.state.receipt.logs[0];
  const encoded = abis.payment.encodeEventLog(abis.payment.getEvent('PaymentIntentConsumed'), [g.payer, g.execution.sale.authorization.saleId, ZeroHash, 1n, g.d.asset.address, 99n]); Object.assign(original, encoded);
  await assert.rejects(api.inspectERC20BurnMintFundingReceipt(g.provider, g.plan, e), /amount differs/);
});
test('historical readback accepts later same-block cancellation/output burn and unrelated callback Core burn', async () => {
  const f = setup(), evidence = receipt(f); f.sale.cancelled = true;
  const originalIdentity = (args) => { if (args[0] === 90n) return [true, 9n, 15n, true]; const s = f.sources.find(s => s.tokenId === args[0]); return [true, s.collectionId, s.collectionSerial, true]; };
  f.state.overrides['core.tokenCollectionIdentity'] = originalIdentity;
  const encoded = abis.core.encodeEventLog(abis.core.getEvent('StreamTokenBurned'), [800n, 3n, 1n, 1n]);
  f.state.receipt.logs.splice(5, 0, { address: f.d.core.address, ...encoded, index: 5, blockNumber: 51, blockHash: minedHash, transactionHash: txHash, removed: false });
  f.state.receipt.logs.forEach((l, i) => l.index = i);
  const out = await api.inspectERC20BurnMintFundingReceipt(f.provider, f.plan, evidence); assert.equal(out.tokenId, 90n); assert.equal(out.events.filter(e => e.event === 'StreamTokenBurned').length, 2);
});
test('receipt inputs are cloned before awaits and changed mined block fails closed', async () => {
  const f = setup(), evidence = receipt(f), input = clone(f.plan); f.state.networkHook = () => { input.capture.sources[0].owner = addr(111); input.capture.prepared.signing.execution.sourceTokenIds[0] = 22n; };
  assert.equal((await api.inspectERC20BurnMintFundingReceipt(f.provider, input, evidence)).tokenId, 90n);
  const g = setup(), ev = receipt(g); g.state.blockChanges = true; await assert.rejects(api.inspectERC20BurnMintFundingReceipt(g.provider, g.plan, ev), /block changed/);
});
test('configuration receipt supports a Safe ordinary CALL and legacy unindexed success', async () => {
  const f = setup(), p = api.prepareERC20BurnMintAction(f.d, f.executor, { target: 'gate', kind: 'configureProgram', configuration: f.program.config });
  const safe = new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)', 'event ExecutionSuccess(bytes32 txHash,uint256 payment)']);
  f.state.tx = { hash: txHash, blockNumber: 51, blockHash: minedHash, value: 0n, from: addr(77), to: f.executor, data: safe.encodeFunctionData('execTransaction', [p.call.to, 0n, p.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']) };
  const configEvent = abis.gate.encodeEventLog(abis.gate.getEvent('BurnMintProgramConfigured'), [1n, 9n, f.d.manager.address, f.configuration.phaseId, p.expectedIdentity, f.program.config]), safeEvent = safe.encodeEventLog(safe.getEvent('ExecutionSuccess'), [id('safe-config'), 0n]);
  f.state.receipt = { hash: txHash, status: 1, blockNumber: 51, blockHash: minedHash, logs: [{ address: f.d.gate.address, ...configEvent }, { address: f.executor, ...safeEvent }].map((l, index) => ({ ...l, index, blockNumber: 51, blockHash: minedHash, transactionHash: txHash, removed: false })) };
  const result = await api.inspectERC20BurnMintActionReceipt(f.provider, p, { transactionHash: txHash, execution: 'safe' }); assert.equal(result.events.length, 2);
  f.state.receipt.logs.pop(); await assert.rejects(api.inspectERC20BurnMintActionReceipt(f.provider, p, { transactionHash: txHash, execution: 'safe' }), /Safe ExecutionSuccess/);
});
