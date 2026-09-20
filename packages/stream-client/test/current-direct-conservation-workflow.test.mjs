import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { AbiCoder, Interface, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as p from '../dist/current-direct-conservation.js';
import * as w from '../dist/current-direct-conservation-workflow.js';
import { createSafeCallPlan, verifySafeCallPlan } from '../dist/safe-plan.js';
const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/current-direct-conservation-abi.json', import.meta.url)));
const all = new Interface(['nativeSale', 'erc20Sale', 'auction', 'manager', 'core', 'modules', 'floor'].flatMap(key => fixture.abis[key]).filter(fragment => fragment.type !== 'constructor'));
const contracts = {
  'native-fixed': new Interface(fixture.abis.nativeSale),
  'erc20-fixed': new Interface(fixture.abis.erc20Sale),
  'english-auction': new Interface(fixture.abis.auction)
};
const coder = AbiCoder.defaultAbiCoder();
const addr = n => getAddress(`0x${n.toString(16).padStart(40, '0')}`);
const code = '0x60006000';
const codeHash = keccak256(code);
const A = addr(1), B = addr(2), ARTIST = addr(3), WALLET = addr(4), CORE = addr(5), MANAGER = addr(6), REGISTRY = addr(7), FLOOR = addr(8), ASSET = addr(9);
const AUTH = id('authorization'), ROOT = id('operation-root'), OP = id('operation-id'), POLICY = id('mint-policy'), PRIMARY = id('primary-policy'), PROFILE = id('profile');
const TOKEN = 777n, CID = 123n, PHASE = id('phase');
const pin = address => ({ address, codeHash });
const block = n => ({ number: n, hash: id(`block-${n}`), timestamp: 900 + 10 * n });
const safeLegacy = new Interface(['event ExecutionSuccess(bytes32 txHash,uint256 payment)']);
const safeIndexed = new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']);
const safeCall = new Interface(['function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool)']);
const zeroTuple = param => {
  if (param.baseType === 'tuple')
    return Object.fromEntries(param.components.map(p => [p.name, zeroTuple(p)]));
  if (param.baseType === 'array')
    return [];
  if (param.type === 'address')
    return ZeroAddress;
  if (param.type === 'bool')
    return false;
  if (param.type.startsWith('bytes'))
    return param.type === 'bytes' ? '0x' : `0x${'00'.repeat(Number(param.type.slice(5)))}`;
  if (param.type === 'string')
    return '';
  return 0n;
};
const emptyPaid = () => zeroTuple(all.getFunction('directPrimarySaleReceipt').outputs[0]);
const emptyUniversal = () => zeroTuple(all.getFunction('settlementReceipt').outputs[0]);
const plain = (param, value) => param.baseType === 'tuple'
  ? Object.fromEntries(param.components.map((p, i) => [p.name, plain(p, value[i])]))
  : param.baseType === 'array' ? value.map(x => plain(param.arrayChildren, x)) : value;
function setup(kind = 'native-fixed', options = {}) {
  const product = addr(kind === 'native-fixed' ? 20 : kind === 'erc20-fixed' ? 21 : 22);
  const caller = options.caller ?? A;
  const coordinates = { chainId: 1n, core: CORE, product, productKind: kind };
  const deployment = { chainId: 1n, product: pin(product), core: pin(CORE), manager: pin(MANAGER), moduleRegistry: pin(REGISTRY) };
  const bindings = { core: CORE, coreCodeHash: codeHash, mintManager: MANAGER, mintManagerCodeHash: codeHash, deploymentChainId: 1n, productKind: p.DIRECT_CONSERVATION_PRODUCT_KINDS[kind] };
  const baseAuth = { collectionId: CID, phaseId: PHASE, payer: caller, recipient: B, artist: ARTIST, profileId: PROFILE, expectedPrimaryPolicyHash: PRIMARY, tokenDataHash: keccak256('0x1234'), mintCommitment: id('commitment'), mintPolicyHash: POLICY, price: options.price ?? 10n, nonce: AUTH, deadline: 100000n, signerEpoch: 1n };
  const config = { collectionId: CID, phaseId: PHASE, asset: ASSET, revenueClass: id('PRIMARY_SALE'), price: 10n, mintPolicyHash: POLICY, expectedPrimaryPolicyHash: PRIMARY, startsAt: 1n, endsAt: 100000n };
  const saleId = p.directConservationERC20SaleId({ ...coordinates, productKind: 'erc20-fixed' }, CID, PHASE, 1n);
  const sale = { config, saleNonce: 1n, configHash: p.directConservationERC20ConfigHash(saleId, config), cancelled: false };
  let authorization = baseAuth;
  if (kind === 'erc20-fixed')
    authorization = { saleId, saleConfigHash: sale.configHash, payer: options.payer ?? caller, recipient: B, artist: ARTIST, tokenDataHash: baseAuth.tokenDataHash, mintCommitment: baseAuth.mintCommitment, nonce: options.nonce ?? ZeroHash, deadline: 100000n, signerEpoch: 1n };
  if (kind === 'english-auction') {
    const { payer, recipient, price, ...rest } = baseAuth;
    authorization = { ...rest, reservePrice: 10n, startTime: 1000n, endTime: options.endTime ?? 1050n, extensionWindow: 10n, minBidIncrementBps: 500n };
  }
  const intent = { payer: authorization.payer ?? caller, asset: ASSET, maxAmount: 10n, saleRef: saleId, expectedPrimaryPolicyHash: PRIMARY, nonce: id('payer-nonce'), deadline: 100000n };
  const request = { productKind: kind, kind: kind === 'english-auction' ? 'createAuction' : 'buy', authorization, tokenData: '0x1234', platformSignature: '0x12', artistSignature: '0x34', ...(kind === 'erc20-fixed' ? { intent, payerSignature: options.payerSignature ?? '0x' } : {}) };
  const prepared = p.prepareDirectConservationCall(coordinates, caller, request);
  const rootState = {
    used: false, rootUsed: false, intentUsed: false, paused: false, epoch: 1n,
    sale: structuredClone(sale), auction: null, nextSaleNonce: 1n, refund: 0n,
    admission: { status: 1n, registeredAt: 1n, statusUpdatedAt: 1n, revision: 1n },
    paid: emptyPaid(), floorReceipt: null, firstSale: null, release: null,
    lifecycle: 2n, totalBidEscrow: 0n, totalRefundOwed: 0n
  };
  const states = new Map([[0, rootState]]);
  const state = tag => states.get([...states.keys()].filter(n => n <= tag).sort((a, b) => b - a)[0]);
  const traces = [], transactions = new Map(), receipts = new Map();
  const h = { kind, product, caller, coordinates, deployment, bindings, authorization, request, prepared, sale, intent, state, states, traces, transactions, receipts, mutate: null, codeAt: null, blockAt: null };
  h.provider = {
    async getNetwork() {
      return { chainId: 1n };
    },
    async getBlock(tag) {
      return h.blockAt?.(tag) ?? block(tag);
    },
    async getCode(target, tag) {
      return h.codeAt?.(target, tag) ?? code;
    },
    async getTransaction(hash) {
      return transactions.get(hash) ?? null;
    },
    async getTransactionReceipt(hash) {
      return receipts.get(hash) ?? null;
    },
    async call(tx) {
      traces.push(tx);
      const contract = tx.to === product ? contracts[kind] : all;
      const parsed = contract.parseTransaction({ data: tx.data });
      const fragment = parsed.fragment;
      const name = parsed.name;
      const args = fragment.inputs.map((param, i) => plain(param, parsed.args[i]));
      const s = state(tx.blockTag);
      let result;
      if (fragment.stateMutability === 'nonpayable' || fragment.stateMutability === 'payable') {
        assert.equal(tx.from, caller, 'original simulation caller');
        assert.equal(tx.gasLimit, 5000000n, 'explicit original simulation gas');
        result = name === 'buy' ? [TOKEN, ROOT] : name === 'createAuction' ? [TOKEN] : name === 'registerSale' ? [saleId] : [];
      }
      else
        switch (name) {
          case 'directPrimaryBindings':
            result = [bindings];
            break;
          case 'core':
            result = [CORE];
            break;
          case 'moduleRegistry':
            result = [REGISTRY];
            break;
          case 'getSatellitePointer':
            result = [REGISTRY, codeHash, false, id('MODULE_REGISTRY'), '0xefc33fae', REGISTRY, 1n, id('module-manifest'), id('deployment-manifest'), 1n];
            break;
          case 'moduleRecord':
            result = [{ ...s.admission, moduleType: p.DIRECT_CONSERVATION_MODULE_TYPE, moduleVersion: p.DIRECT_CONSERVATION_MODULE_VERSION, interfaceId: '0xf9f99b4b', moduleGasLimit: 0n, runtimeCodeHash: codeHash, deploymentManifestHash: id('deployment'), moduleManifestHash: id('manifest'), moduleManifestURI: 'ipfs://manifest' }];
            break;
          case 'supportsInterface':
            result = [args[0] !== '0xffffffff'];
            break;
          case 'deploymentChainId':
            result = [1n];
            break;
          case 'conservationFloor':
            result = [FLOOR, codeHash];
            break;
          case 'gasParameter':
            result = [500000n];
            break;
          case 'paused':
            result = [s.paused];
            break;
          case 'signerEpoch':
            result = [s.epoch];
            break;
          case 'platformSigner':
            result = [addr(31)];
            break;
          case 'owner':
            result = [caller];
            break;
          case 'authorizationUsed':
            result = [s.used];
            break;
          case 'authorizationId':
            result = [p.directConservationAuthorizationId(coordinates, args[0], args[1])];
            break;
          case 'authorizationDigest': {
            const typed = kind === 'native-fixed' ? p.directConservationNativeTypedData(coordinates, args[0]) : kind === 'erc20-fixed' ? p.directConservationERC20TypedData(coordinates, args[0]) : p.directConservationAuctionTypedData(coordinates, args[0]);
            result = [TypedDataEncoder.hash(typed.domain, typed.types, typed.message)];
            break;
          }
          case 'primaryPolicy':
            result = [PRIMARY, PROFILE, WALLET];
            break;
          case 'previewSingleStepMintOperation':
            assert.equal(tx.from, product, 'Manager preview executor is product');
            result = [ROOT, [OP]];
            break;
          case 'isOperationRootUsed':
          case 'isAuthorizationUsed':
            result = [s.rootUsed];
            break;
          case 'artistRegistry':
            result = [addr(32)];
            break;
          case 'artistRegistryCodeHash':
          case 'fundingFactoryCodeHash':
          case 'fundingEscrowCodeHash':
            result = [codeHash];
            break;
          case 'revenueResolver':
            result = [addr(33)];
            break;
          case 'splitFactory':
            result = [addr(34)];
            break;
          case 'revenueEscrow':
            result = [addr(35)];
            break;
          case 'assetPolicyRegistry':
            result = [addr(36)];
            break;
          case 'saleRecord':
            result = [s.sale];
            break;
          case 'nextSaleNonce':
            result = [s.nextSaleNonce];
            break;
          case 'isPaymentIntentNonceUsed':
            result = [s.intentUsed];
            break;
          case 'paymentIntentDigest': {
            const typed = p.directConservationPaymentIntentTypedData(coordinates, args[0]);
            result = [TypedDataEncoder.hash(typed.domain, typed.types, typed.message)];
            break;
          }
          case 'auction':
            result = [s.auction];
            break;
          case 'minimumBid':
            result = [p.directConservationMinimumBid(s.auction)];
            break;
          case 'auctionStatus':
            result = [p.directConservationAuctionStatus(s.auction, BigInt(block(tx.blockTag).timestamp))];
            break;
          case 'refundCredit':
            result = [s.refund];
            break;
          case 'totalBidEscrow':
            result = [s.totalBidEscrow];
            break;
          case 'totalRefundOwed':
            result = [s.totalRefundOwed];
            break;
          case 'directPrimarySaleReceipt':
            result = [s.paid];
            break;
          case 'directPrimarySaleReceiptHash':
            result = [p.directConservationReceiptLookupHash(bindings, product, args[0], s.paid)];
            break;
          case 'tokenCollectionIdentity':
            result = [true, CID, 1n, s.lifecycle === 3n];
            break;
          case 'tokenLifecycle':
            result = [s.lifecycle];
            break;
          case 'collectionExists':
            result = [true];
            break;
          case 'directPrimarySaleFloorReceipt':
            result = [s.floorReceipt];
            break;
          case 'firstSale':
            result = [s.firstSale];
            break;
          case 'releaseFloorReceipt':
            result = [s.release];
            break;
          case 'settlementReceipt':
            result = [emptyUniversal()];
            break;
          default: throw Error(`Unhandled ${name}`);
        }
      const mutated = await h.mutate?.({ tx, name, args, result, fragment, state: s });
      if (typeof mutated === 'string')
        return mutated;
      return contract.encodeFunctionResult(fragment, mutated ?? result);
    }
  };
  return h;
}
function event(target, name, args) {
  const fragment = all.getEvent(name);
  const encoded = all.encodeEventLog(fragment, fragment.inputs.map(input => args[input.name]));
  return { address: target, ...encoded, index: 0 };
}
function renumber(logs) {
  logs.forEach((log, i) => log.index = i);
  return logs;
}
function installTransaction(h, prepared, logs, tag = 11, safe = null) {
  const txHash = id(`tx-${tag}-${h.receipts.size}`);
  const tx = { hash: txHash, blockNumber: tag, blockHash: block(tag).hash, from: prepared.caller, to: h.product, data: prepared.call.data, value: prepared.call.value };
  const options = safe ? { execution: 'safe', expectedSafeTxHash: id(`safe-${tag}`) } : { execution: 'direct' };
  if (safe) {
    tx.from = addr(99);
    tx.to = prepared.caller;
    tx.value = 0n;
    tx.data = safeCall.encodeFunctionData('execTransaction', [h.product, prepared.call.value, prepared.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']);
    logs.push({ address: prepared.caller, ...(safe === 'indexed' ? safeIndexed : safeLegacy).encodeEventLog('ExecutionSuccess', [options.expectedSafeTxHash, 0n]), index: 0 });
  }
  h.transactions.set(txHash, tx);
  h.receipts.set(txHash, { hash: txHash, status: 1, blockNumber: tag, blockHash: block(tag).hash, logs: renumber(logs) });
  return { txHash, options, tx, receipt: h.receipts.get(txHash) };
}
function paidHistory(h, capture, tag, overrides = {}) {
  const origin = capture.mint;
  const sale = { authorizationDigest: origin.authorizationDigest, collectionId: CID, tokenId: TOKEN, operationRoot: ROOT, operationId: OP, boundMintPolicyHash: POLICY, expectedPrimaryPolicyHash: PRIMARY, profileId: PROFILE, wallet: WALLET, createdAt: BigInt(block(tag).timestamp), escrowed: false, payer: h.authorization.payer ?? A, registryRevision: 1n, beneficiary: B, asset: h.kind === 'erc20-fixed' ? ASSET : ZeroAddress, amount: 10n, ...overrides };
  const key = p.directConservationKey(h.bindings, h.product, origin.authorizationId);
  const fc = { chainId: 1n, core: CORE, floor: FLOOR };
  const firstSale = { receiptHash: ZeroHash, collectionId: CID, effectiveTier: id('CONSERVATION_WAIVED'), recorder: h.product, settlementKey: key, recordedAt: BigInt(block(tag).timestamp), sourceId: 0n, sourceSetHash: id('waived-current-head'), facts: { artistId: ZeroHash, identityRecordHash: ZeroHash, intentRecordHash: ZeroHash, intentWaiverRecordHash: ZeroHash, interviewEvidenceHash: ZeroHash, rightsRecordHash: ZeroHash, personhoodEvidenceHash: ZeroHash, platformWorks: false } };
  firstSale.receiptHash = p.directConservationFirstSaleReceiptHash(fc, firstSale);
  const floorReceipt = { receiptHash: ZeroHash, adapter: h.product, adapterCodeHash: codeHash, directKey: key, authorizationId: origin.authorizationId, originalReceiptHash: p.directConservationReceiptHash(h.bindings, h.product, origin.authorizationId, sale), bindings: h.bindings, sale, effectiveTier: firstSale.effectiveTier, firstSaleReceiptHash: firstSale.receiptHash, releaseReceiptHash: ZeroHash, recordedAt: BigInt(block(tag).timestamp) };
  floorReceipt.receiptHash = p.directConservationFloorReceiptHash(fc, floorReceipt);
  return { sale, key, firstSale, floorReceipt, fc };
}
function installBuy(h, capture, { tag = 11, safe = null, paid = true } = {}) {
  const next = structuredClone(h.state(tag - 1));
  next.used = true;
  next.rootUsed = true;
  next.intentUsed = capture.paymentIntent === 'signed-intent';
  const logs = [];
  const m = capture.mint;
  let history;
  if (next.intentUsed)
    logs.push(event(h.product, 'PaymentIntentConsumed', { payer: h.authorization.payer, saleRef: h.authorization.saleId, nonce: h.intent.nonce, schemaVersion: 1n, asset: ASSET, amount: 10n }));
  if (paid) {
    history = paidHistory(h, capture, tag);
    next.paid = history.sale;
    next.floorReceipt = history.floorReceipt;
    next.firstSale = history.firstSale;
    logs.push(event(FLOOR, 'ConservationFirstSaleRecorded', { collectionId: CID, receiptHash: history.firstSale.receiptHash, receipt: history.firstSale, schemaVersion: 1n }));
    logs.push(event(FLOOR, 'ConservationDirectPrimarySaleRecorded', { directKey: history.key, receiptHash: history.floorReceipt.receiptHash, receipt: history.floorReceipt, schemaVersion: 1n }));
    logs.push(event(h.product, 'DirectPrimarySaleRecorded', { authorizationId: m.authorizationId, receiptHash: history.floorReceipt.originalReceiptHash, tokenId: TOKEN, receipt: history.sale, schemaVersion: 1n }));
  }
  const amount = paid ? 10n : 0n;
  logs.push(event(h.product, h.kind === 'erc20-fixed' ? 'ERC20SaleSettled' : 'NativeSaleSettled', { saleId: h.authorization.saleId, authorizationId: m.authorizationId, operationRoot: ROOT, tokenId: TOKEN, authorizationDigest: m.authorizationDigest, profileId: PROFILE, wallet: WALLET, asset: ASSET, amount }));
  logs.push(event(h.product, h.kind === 'erc20-fixed' ? 'ERC20SaleParticipants' : 'SaleParticipants', { authorizationId: m.authorizationId, collectionId: CID, artist: ARTIST, payer: h.authorization.payer, recipient: B, primaryPolicyHash: PRIMARY }));
  logs.push(event(h.product, 'SaleRevenueFunded', { schemaVersion: 1n, authorizationId: m.authorizationId, operationRoot: ROOT, profileId: PROFILE, wallet: WALLET, asset: h.kind === 'erc20-fixed' ? ASSET : ZeroAddress, amount, escrowed: false }));
  h.states.set(tag, next);
  return { ...installTransaction(h, h.prepared, logs, tag, safe), history };
}
const capture = h => w.captureDirectConservation(h.provider, h.deployment, h.prepared, { blockTag: 10 });
const reconcile = (h, c, r) => w.reconcileDirectConservationReceipt(h.provider, c, r.txHash, r.options);
test('original caller/value and executor-scoped preview for native, ERC20 and auction simulations', async () => {
  for (const kind of ['native-fixed', 'erc20-fixed', 'english-auction']) {
    const h = setup(kind);
    const c = await capture(h);
    const s = await w.simulateDirectConservation(h.provider, c, { blockTag: 10, gasLimit: 5000000n });
    assert.equal(s.tokenId, TOKEN);
    assert.equal(s.operationRoot, ROOT);
    await assert.rejects(w.simulateDirectConservation(h.provider, c, { blockTag: 9, gasLimit: 5000000n }), /predates/);
    await assert.rejects(w.simulateDirectConservation(h.provider, c, { blockTag: 10, gasLimit: 100000001n }), /gas bound/);
    const preview = h.traces.find(x => x.data.startsWith(all.getFunction('previewSingleStepMintOperation').selector));
    assert.equal(preview.from, h.product);
  }
});
test('native free mint bypasses paid admission/floor and retains empty DIRECT history', async () => {
  const h = setup('native-fixed', { price: 0n });
  h.mutate = ({ name }) => {
    if (['getSatellitePointer', 'moduleRecord', 'conservationFloor'].includes(name))
      throw Error('unexpected paid admission');
  };
  const c = await capture(h);
  assert.equal(c.admission, null);
  assert.equal(c.floor, null);
  const r = installBuy(h, c, { paid: false });
  const result = await reconcile(h, c, r);
  assert.equal(result.outcome, 'free-mint');
  assert.equal(result.paidReceipt, null);
});
test('paid native and ERC20 receipts join complete original and floor tuples in source event order', async () => {
  for (const kind of ['native-fixed', 'erc20-fixed']) {
    const h = setup(kind);
    const c = await capture(h);
    const r = installBuy(h, c);
    const result = await reconcile(h, c, r);
    assert.equal(result.outcome, 'paid');
    assert.equal(result.paidReceipt.amount, 10n);
    assert.equal(result.floorHistory.receipt.originalReceiptHash, r.history.floorReceipt.originalReceiptHash);
    assert.equal(result.floorHistory.firstSale.sourceSetHash, id('waived-current-head'));
  }
});
test('literal payer exemption is distinct from empty relayed ERC1271 and nonempty direct intent', async () => {
  for (const [payer, payerSignature, lane] of [[A, '0x', 'exempt-literal-caller'], [B, '0x', 'signed-intent'], [A, '0x1234', 'signed-intent']]) {
    const h = setup('erc20-fixed', { payer, payerSignature });
    const c = await capture(h);
    assert.equal(c.paymentIntent, lane);
    assert.equal(h.authorization.nonce, ZeroHash);
    const result = await reconcile(h, c, installBuy(h, c));
    assert.equal(result.outcome, 'paid');
  }
});
function installCreation(h, c, { tag = 11, safe = null } = {}) {
  const a = h.authorization, m = c.mint;
  const next = structuredClone(h.state(tag - 1));
  next.used = true;
  next.rootUsed = true;
  next.auction = { artist: a.artist, wallet: WALLET, profileId: PROFILE, reservePrice: a.reservePrice, startTime: a.startTime, endTime: a.endTime, extensionWindow: a.extensionWindow, minBidIncrementBps: a.minBidIncrementBps, highestBidder: ZeroAddress, deliveryRecipient: ARTIST, highestBid: 0n, settled: false, cancelled: false, pendingNoBidNftClaimant: ZeroAddress, authorizationId: m.authorizationId, operationRoot: ROOT, primaryPolicyHash: PRIMARY };
  h.states.set(tag, next);
  return installTransaction(h, h.prepared, [
    event(h.product, 'AuctionCreated', { tokenId: TOKEN, artist: ARTIST, authorizationId: m.authorizationId, operationRoot: ROOT, authorizationDigest: m.authorizationDigest, profileId: PROFILE, wallet: WALLET }),
    event(h.product, 'AuctionTerms', { tokenId: TOKEN, reservePrice: a.reservePrice, startTime: a.startTime, endTime: a.endTime, extensionWindow: a.extensionWindow, minBidIncrementBps: a.minBidIncrementBps })
  ], tag, safe);
}
async function operational(kind, method, { safe = null, paidAuction = false, pending = false } = {}) {
  let caller = A;
  if (['cancel', 'claimNoBidNFT', 'setDeliveryRecipient'].includes(method))
    caller = ARTIST;
  const h = setup(kind, { caller });
  let c, r, origin = null;
  if (method === 'buy') {
    c = await capture(h);
    r = installBuy(h, c, { safe });
    return { h, c, r };
  }
  if (method === 'createAuction') {
    c = await capture(h);
    r = installCreation(h, c, { safe });
    return { h, c, r };
  }
  let tag = 11, req;
  if (kind === 'english-auction' && method !== 'cancelAuthorization' && method !== 'withdrawRefund') {
    const cc = await capture(h);
    const cr = installCreation(h, cc);
    origin = { capture: cc, transactionHash: cr.txHash, transport: cr.options };
    tag = ['settle', 'claimNoBidNFT'].includes(method) ? 17 : 13;
    const staged = structuredClone(h.state(tag - 1));
    if (paidAuction)
      staged.auction = { ...staged.auction, highestBidder: A, deliveryRecipient: B, highestBid: 20n };
    if (method === 'claimNoBidNFT')
      staged.auction.pendingNoBidNftClaimant = ARTIST;
    if (method === 'settle' && !pending && !paidAuction)
      h.codeAt = (target) => target === ARTIST ? '0x' : undefined;
    if (pending)
      staged.auction.pendingNoBidNftClaimant = ARTIST;
    h.states.set(tag - 1, staged);
    req = { productKind: kind, kind: method, tokenId: TOKEN, ...(['bid', 'setDeliveryRecipient', 'claimNoBidNFT'].includes(method) ? { recipient: B } : {}), ...(method === 'bid' ? { amount: 20n } : {}) };
  }
  else if (method === 'withdrawRefund') {
    h.state(0).refund = 7n;
    h.state(0).totalRefundOwed = 7n;
    req = { productKind: kind, kind: method, recipient: B };
  }
  else if (method === 'cancelAuthorization' || method === 'revokePaymentIntent')
    req = { productKind: kind, kind: method, nonce: AUTH };
  else if (method === 'revokePaymentIntentBySignature')
    req = { productKind: kind, kind: method, payer: B, nonce: AUTH, deadline: 99999n, signature: '0x' };
  else if (method === 'cancelSale')
    req = { productKind: kind, kind: method, saleId: h.authorization.saleId };
  else if (method === 'registerSale')
    req = { productKind: kind, kind: method, config: h.sale.config };
  h.prepared = p.prepareDirectConservationCall(h.coordinates, h.caller, req);
  c = await w.captureDirectConservation(h.provider, h.deployment, h.prepared, { blockTag: tag - 1 });
  const next = structuredClone(h.state(tag - 1)), logs = [];
  if (method === 'cancelAuthorization') {
    next.used = true;
    logs.push(event(h.product, kind === 'english-auction' ? 'AuctionAuthorizationCancelled' : 'SaleAuthorizationCancelled', { artist: h.caller, nonce: AUTH }));
  }
  else if (method === 'revokePaymentIntent' || method === 'revokePaymentIntentBySignature') {
    next.intentUsed = true;
    logs.push(event(h.product, 'PaymentIntentRevoked', { payer: method === 'revokePaymentIntent' ? h.caller : B, nonce: AUTH, schemaVersion: 1n }));
  }
  else if (method === 'registerSale') {
    next.nextSaleNonce = 2n;
    logs.push(event(h.product, 'SaleConfigured', { saleId: h.authorization.saleId, collectionId: CID, phaseId: PHASE, saleNonce: 1n, saleConfigHash: h.sale.configHash }));
  }
  else if (method === 'cancelSale') {
    next.sale.cancelled = true;
    logs.push(event(h.product, 'SaleCancelled', { saleId: h.authorization.saleId }));
  }
  else if (method === 'withdrawRefund') {
    next.refund = 0n;
    next.totalRefundOwed = 0n;
    logs.push(event(h.product, 'AuctionRefundWithdrawn', { bidder: h.caller, recipient: B, amount: 7n }));
  }
  else if (method === 'bid') {
    const prior = next.auction;
    if (prior.highestBid > 0n)
      logs.push(event(h.product, 'AuctionRefundCredited', { bidder: prior.highestBidder, tokenId: TOKEN, amount: prior.highestBid }));
    next.auction = { ...prior, highestBidder: h.caller, deliveryRecipient: B, highestBid: 20n };
    logs.push(event(h.product, 'AuctionBidPlaced', { tokenId: TOKEN, bidder: h.caller, recipient: B, amount: 20n, endTime: prior.endTime }));
  }
  else if (method === 'setDeliveryRecipient') {
    next.auction.deliveryRecipient = B;
    logs.push(event(h.product, 'AuctionRecipientChanged', { tokenId: TOKEN, recipient: B }));
  }
  else if (method === 'cancel') {
    next.auction.settled = true;
    next.auction.cancelled = true;
    logs.push(event(h.product, 'AuctionCancelled', { tokenId: TOKEN, recipient: ARTIST }));
  }
  else if (method === 'settle' && pending) {
    // Already pending in the exact previous block: original retry emits nothing.
  }
  else {
    next.auction.settled = true;
    next.auction.pendingNoBidNftClaimant = ZeroAddress;
    if (method === 'claimNoBidNFT')
      next.auction.deliveryRecipient = B;
    if (paidAuction) {
      const history = paidHistory(h, origin.capture, tag, { createdAt: BigInt(block(11).timestamp), amount: 20n, payer: A, beneficiary: B });
      next.paid = history.sale;
      next.floorReceipt = history.floorReceipt;
      next.firstSale = history.firstSale;
      logs.push(event(FLOOR, 'ConservationFirstSaleRecorded', { collectionId: CID, receiptHash: history.firstSale.receiptHash, receipt: history.firstSale, schemaVersion: 1n }));
      logs.push(event(FLOOR, 'ConservationDirectPrimarySaleRecorded', { directKey: history.key, receiptHash: history.floorReceipt.receiptHash, receipt: history.floorReceipt, schemaVersion: 1n }));
      logs.push(event(h.product, 'DirectPrimarySaleRecorded', { authorizationId: origin.capture.mint.authorizationId, receiptHash: history.floorReceipt.originalReceiptHash, tokenId: TOKEN, receipt: history.sale, schemaVersion: 1n }));
    }
    logs.push(event(h.product, 'AuctionSettled', { tokenId: TOKEN, bidder: next.auction.highestBidder, recipient: next.auction.deliveryRecipient, wallet: WALLET, amount: next.auction.highestBid }));
    if (paidAuction)
      logs.push(event(h.product, 'SaleRevenueFunded', { schemaVersion: 1n, authorizationId: origin.capture.mint.authorizationId, operationRoot: ROOT, profileId: PROFILE, wallet: WALLET, asset: ZeroAddress, amount: 20n, escrowed: false }));
  }
  h.states.set(tag, next);
  r = installTransaction(h, h.prepared, logs, tag, safe);
  if (paidAuction)
    r.options.auctionCreation = origin;
  return { h, c, r, origin };
}
const operations = [
  ['native-fixed', 'buy'], ['native-fixed', 'cancelAuthorization'],
  ...['buy', 'registerSale', 'cancelSale', 'cancelAuthorization', 'revokePaymentIntent', 'revokePaymentIntentBySignature'].map(x => ['erc20-fixed', x]),
  ...['createAuction', 'bid', 'settle', 'cancel', 'setDeliveryRecipient', 'claimNoBidNFT', 'withdrawRefund', 'cancelAuthorization'].map(x => ['english-auction', x])
];
test('all sixteen original operations reconcile direct and both exact Safe CALL layouts', async () => {
  for (const [kind, method] of operations)
    for (const safe of [null, 'legacy', 'indexed']) {
      const { h, c, r } = await operational(kind, method, { safe });
      const result = await reconcile(h, c, r);
      assert.ok(result.outcome, `${kind}.${method}/${safe}`);
      assert.equal(result.requiredLogIndices.length > 0, true);
      assert.equal(result.paidReceipt !== null, method === 'buy');
    }
});
test('paid auction settlement authenticates prior creation and accepts completed burned delivery', async () => {
  for (const safe of [null, 'legacy', 'indexed']) {
    const { h, c, r } = await operational('english-auction', 'settle', { safe, paidAuction: true });
    h.state(17).lifecycle = 3n;
    const result = await reconcile(h, c, r);
    assert.equal(result.outcome, 'paid');
    assert.equal(result.paidReceipt.beneficiary, B);
    assert.equal(result.paidReceipt.createdAt, 1010n);
    const missing = { ...r.options };
    delete missing.auctionCreation;
    await assert.rejects(w.reconcileDirectConservationReceipt(h.provider, c, r.txHash, missing), /creation receipt required/);
  }
});
test('auction retained deprecation requires both creation time and revision strictly earlier', async () => {
  const { h, c, r } = await operational('english-auction', 'settle', { paidAuction: true });
  for (const tag of [16, 17])
    h.state(tag).admission = { status: 2n, registeredAt: 1n, statusUpdatedAt: 1040n, revision: 2n };
  const fresh = await w.captureDirectConservation(h.provider, h.deployment, h.prepared, { blockTag: 16 });
  assert.equal((await reconcile(h, fresh, r)).outcome, 'paid');
  h.state(17).admission = { status: 2n, registeredAt: 1n, statusUpdatedAt: 1010n, revision: 2n };
  await assert.rejects(reconcile(h, fresh, r), /admission timing/);
  h.state(17).admission = { status: 2n, registeredAt: 1n, statusUpdatedAt: 1040n, revision: 1n };
  await assert.rejects(reconcile(h, fresh, r), /admission timing/);
});
test('no-bid contract retry is eventless pending state, while exits work paused without paid admission', async () => {
  for (const method of ['settle', 'cancel', 'claimNoBidNFT', 'withdrawRefund']) {
    const { h, c, r } = await operational('english-auction', method, { pending: method === 'settle' });
    for (const state of h.states.values())
      state.paused = true;
    h.mutate = ({ name, tx }) => {
      if (tx.blockTag >= c.observed.blockNumber && ['moduleRecord', 'getSatellitePointer'].includes(name))
        throw Error('exit must not require admission');
    };
    const fresh = await w.captureDirectConservation(h.provider, h.deployment, h.prepared, { blockTag: c.observed.blockNumber });
    const result = await reconcile(h, fresh, r);
    assert.equal(result.paidReceipt, null);
    if (method === 'settle') {
      assert.equal(result.outcome, 'pending-no-bid');
      assert.equal(result.auction.settled, false);
    }
  }
});
function addRelease(history, { older = false } = {}) {
  const { fc, floorReceipt, firstSale } = history;
  const tier = id('MUSEUM_GRADE_LITE');
  firstSale.effectiveTier = tier;
  if (older) {
    firstSale.recorder = addr(88);
    firstSale.settlementKey = id('earlier-universal');
    firstSale.recordedAt = 5n;
  }
  firstSale.receiptHash = p.directConservationFirstSaleReceiptHash(fc, firstSale);
  const context = { scopeSubject: id('release-scope'), membershipHash: id('members'), mediaInventoryHash: id('media'), scriptSourceHash: ZeroHash, sourceContextHash: id('old-source-context'), scriptWork: false };
  const releaseKey = p.directConservationReleaseKey(1n, CORE, CID, context);
  const release = { receiptHash: ZeroHash, releaseKey, collectionId: CID, effectiveTier: tier, recorder: older ? addr(89) : floorReceipt.adapter, settlementKey: older ? id('earlier-direct') : floorReceipt.directKey, recordedAt: older ? 6n : floorReceipt.recordedAt, sourceId: 3n, sourceSetHash: id('old-source-set'), context, facts: { sourceContextHash: context.sourceContextHash, mediaEvidenceHash: id('media-evidence'), referenceEvidenceHash: ZeroHash } };
  release.receiptHash = p.directConservationReleaseReceiptHash(fc, release);
  floorReceipt.effectiveTier = tier;
  floorReceipt.firstSaleReceiptHash = firstSale.receiptHash;
  floorReceipt.releaseReceiptHash = release.receiptHash;
  floorReceipt.receiptHash = p.directConservationFloorReceiptHash(fc, floorReceipt);
  return release;
}
function replaceLog(receipt, target, name, args) {
  const topic = all.getEvent(name).topicHash;
  const index = receipt.logs.findIndex(log => log.address === target && log.topics[0] === topic);
  receipt.logs[index] = { ...event(target, name, args), index };
}
function installReleaseEvents(h, r, release, { older = false } = {}) {
  const history = r.history;
  if (older)
    r.receipt.logs.splice(r.receipt.logs.findIndex(log => log.topics[0] === all.getEvent('ConservationFirstSaleRecorded').topicHash), 1);
  else {
    replaceLog(r.receipt, FLOOR, 'ConservationFirstSaleRecorded', { collectionId: CID, receiptHash: history.firstSale.receiptHash, receipt: history.firstSale, schemaVersion: 1n });
    r.receipt.logs.splice(1, 0, event(FLOOR, 'ConservationReleaseFloorRecorded', { releaseKey: release.releaseKey, receiptHash: release.receiptHash, receipt: release, schemaVersion: 1n }));
  }
  replaceLog(r.receipt, FLOOR, 'ConservationDirectPrimarySaleRecorded', { directKey: history.key, receiptHash: history.floorReceipt.receiptHash, receipt: history.floorReceipt, schemaVersion: 1n });
  renumber(r.receipt.logs);
  h.state(11).release = release;
}
test('local product and floor history survives unavailable former dependencies and reuses older foreign receipts', async () => {
  const h = setup();
  const c = await capture(h);
  const r = installBuy(h, c);
  const release = addRelease(r.history, { older: true });
  h.state(11).release = release;
  h.codeAt = target => [h.product, FLOOR].includes(target) ? code : '0x';
  h.mutate = ({ name }) => {
    if (['moduleRecord', 'getSatellitePointer', 'tokenLifecycle', 'previewSingleStepMintOperation'].includes(name))
      throw Error('historical read called live prerequisite');
  };
  const local = await w.inspectDirectConservationReceipt(h.provider, { chainId: 1n, product: h.deployment.product, authorizationId: c.mint.authorizationId }, { blockTag: 11 });
  assert.equal(local.receipt.amount, 10n);
  const originalMutation = h.mutate;
  h.mutate = context => context.name === 'directPrimarySaleReceiptHash' ? [id('changed-paid-hash')] : originalMutation(context);
  await assert.rejects(w.inspectDirectConservationReceipt(h.provider, { chainId: 1n, product: h.deployment.product, authorizationId: c.mint.authorizationId }, { blockTag: 11 }), /receipt hash/);
  h.mutate = originalMutation;
  const retained = await w.inspectDirectConservationFloorHistory(h.provider, { chainId: 1n, core: CORE, floor: pin(FLOOR), key: r.history.key }, { blockTag: 11, releaseKey: release.releaseKey });
  assert.equal(retained.firstSale.recorder, addr(88));
  assert.equal(retained.release.recorder, addr(89));
  await assert.rejects(w.inspectDirectConservationFloorHistory(h.provider, { chainId: 1n, core: CORE, floor: pin(FLOOR), key: r.history.key }, { blockTag: 11 }), /locator required/);
  const empty = setup();
  assert.equal((await w.inspectDirectConservationReceipt(empty.provider, { chainId: 1n, product: empty.deployment.product, authorizationId: ZeroHash }, { blockTag: 10 })).receipt, null);
  empty.mutate = ({ name, result }) => name === 'directPrimarySaleReceipt' ? [{ ...result[0], collectionId: 1n }] : undefined;
  await assert.rejects(w.inspectDirectConservationReceipt(empty.provider, { chainId: 1n, product: empty.deployment.product, authorizationId: ZeroHash }, { blockTag: 10 }), /Noncanonical empty/);
  empty.mutate = ({ name }) => name === 'directPrimarySaleReceiptHash' ? [id('nonzero-empty-hash')] : undefined;
  await assert.rejects(w.inspectDirectConservationReceipt(empty.provider, { chainId: 1n, product: empty.deployment.product, authorizationId: ZeroHash }, { blockTag: 10 }), /Empty product receipt hash/);
});
test('new release event supplies locator; reused release requires explicit retained key', async () => {
  for (const older of [false, true]) {
    const h = setup();
    const c = await capture(h);
    const r = installBuy(h, c);
    const release = addRelease(r.history, { older });
    installReleaseEvents(h, r, release, { older });
    if (older)
      r.options.releaseKey = release.releaseKey;
    assert.equal((await reconcile(h, c, r)).floorHistory.release.releaseKey, release.releaseKey);
    if (older) {
      delete r.options.releaseKey;
      await assert.rejects(reconcile(h, c, r), /locator required/);
    }
  }
});
test('history rejects rehashed wrong deployment, tiers, paid fields and universal namespace collision', async () => {
  for (const mutation of ['chain', 'tier', 'unknown-tier', 'release-missing', 'payer', 'universal']) {
    const h = setup();
    const c = await capture(h);
    const r = installBuy(h, c);
    const history = r.history;
    if (mutation === 'chain')
      history.floorReceipt.bindings = { ...h.bindings, deploymentChainId: 2n };
    if (mutation === 'tier')
      history.firstSale.effectiveTier = id('MUSEUM_GRADE_LITE');
    if (mutation === 'unknown-tier')
      history.firstSale.effectiveTier = history.floorReceipt.effectiveTier = id('unknown');
    if (mutation === 'release-missing')
      history.firstSale.effectiveTier = history.floorReceipt.effectiveTier = id('MUSEUM_GRADE_LITE');
    if (mutation === 'payer')
      history.sale.payer = ZeroAddress;
    history.firstSale.receiptHash = p.directConservationFirstSaleReceiptHash(history.fc, history.firstSale);
    history.floorReceipt.firstSaleReceiptHash = history.firstSale.receiptHash;
    history.floorReceipt.originalReceiptHash = p.directConservationReceiptHash(history.floorReceipt.bindings, h.product, c.mint.authorizationId, history.sale);
    history.floorReceipt.directKey = p.directConservationKey(history.floorReceipt.bindings, h.product, c.mint.authorizationId);
    history.floorReceipt.receiptHash = p.directConservationFloorReceiptHash(history.fc, history.floorReceipt);
    if (mutation === 'universal')
      h.mutate = ({ name, result }) => name === 'settlementReceipt' ? [{ ...result[0], receiptHash: id('unexpected') }] : undefined;
    await assert.rejects(w.inspectDirectConservationFloorHistory(h.provider, { chainId: 1n, core: CORE, floor: pin(FLOOR), key: history.floorReceipt.directKey }, { blockTag: 11 }));
  }
});
test('canonical copied capture, exact ABI bounds, reorgs and runtime drift fail closed', async () => {
  const h = setup();
  const c = await capture(h);
  const forged = structuredClone(c);
  forged.admission.revision = '1';
  await assert.rejects(w.simulateDirectConservation(h.provider, forged, { blockTag: 10, gasLimit: 5000000n }), /integrity/);
  h.mutate = ({ name, result, fragment }) => name === 'moduleRecord' ? all.encodeFunctionResult(fragment, result) + '00'.repeat(32) : undefined;
  await assert.rejects(capture(h), /Canonical/);
  h.mutate = null;
  h.codeAt = target => target === REGISTRY ? '0x6001' : undefined;
  await assert.rejects(capture(h), /Runtime pin/);
  h.codeAt = null;
  let reads = 0;
  h.blockAt = tag => ({ ...block(tag), hash: ++reads > 1 ? id('reorg') : block(tag).hash });
  await assert.rejects(capture(h), /Capture block/);
  const delayed = setup();
  const userCall = structuredClone(delayed.prepared);
  const original = delayed.provider.getNetwork;
  delayed.provider.getNetwork = async () => {
    userCall.call.value = 999n;
    return original();
  };
  const retained = await w.captureDirectConservation(delayed.provider, delayed.deployment, userCall, { blockTag: 10 });
  assert.equal(retained.prepared.call.value, 10n);
  assert.equal(Object.isFrozen(retained.prepared), true);
});
test('original product reverts propagate without fallback, and actual native caller cannot be substituted', async () => {
  const h = setup();
  const c = await capture(h);
  h.mutate = ({ name }) => {
    if (name === 'buy')
      throw Error('original callback or floor admission failed');
  };
  await assert.rejects(w.simulateDirectConservation(h.provider, c, { blockTag: 10, gasLimit: 5000000n }), /original callback/);
  assert.throws(() => p.prepareDirectConservationCall(h.coordinates, B, h.request), /payer|caller/i);
  const r = installBuy(h, c);
  h.mutate = null;
  r.tx.from = B;
  await assert.rejects(reconcile(h, c, r), /Actual direct caller/);
});
test('source event ordering rejects uniquely indexed permutations and omitted atomic floor receipt', async () => {
  const cases = [
    ['DirectPrimarySaleRecorded', 'NativeSaleSettled'],
    ['ConservationDirectPrimarySaleRecorded', 'DirectPrimarySaleRecorded'],
    ['SaleParticipants', 'NativeSaleSettled'],
    ['SaleRevenueFunded', 'SaleParticipants']
  ];
  for (const [first, second] of cases) {
    const h = setup();
    const c = await capture(h);
    const r = installBuy(h, c);
    const i = r.receipt.logs.findIndex(log => log.topics[0] === all.getEvent(first).topicHash);
    const j = r.receipt.logs.findIndex(log => log.topics[0] === all.getEvent(second).topicHash);
    [r.receipt.logs[i], r.receipt.logs[j]] = [r.receipt.logs[j], r.receipt.logs[i]];
    renumber(r.receipt.logs);
    await assert.rejects(reconcile(h, c, r), /order|precede/i);
  }
  const h = setup('erc20-fixed', { payer: B });
  const c = await capture(h);
  const r = installBuy(h, c);
  const intent = r.receipt.logs.shift();
  r.receipt.logs.splice(2, 0, intent);
  renumber(r.receipt.logs);
  await assert.rejects(reconcile(h, c, r), /misordered/);
  const q = setup();
  const qc = await capture(q);
  const qr = installBuy(q, qc);
  const release = addRelease(qr.history);
  installReleaseEvents(q, qr, release);
  [qr.receipt.logs[0], qr.receipt.logs[1]] = [qr.receipt.logs[1], qr.receipt.logs[0]];
  renumber(qr.receipt.logs);
  await assert.rejects(reconcile(q, qc, qr), /prerequisite events/);
  qr.receipt.logs = qr.receipt.logs.filter(log => log.topics[0] !== all.getEvent('ConservationDirectPrimarySaleRecorded').topicHash);
  renumber(qr.receipt.logs);
  await assert.rejects(reconcile(q, qc, qr), /Missing or duplicate/);
});
test('Safe independent hashes, failed calls, delegatecall, value and calldata substitution reject for all kinds', async () => {
  for (const [kind, method] of operations) {
    const { h, c, r } = await operational(kind, method, { safe: 'indexed' });
    await assert.rejects(w.reconcileDirectConservationReceipt(h.provider, c, r.txHash, { execution: 'delegatecall' }), /Unsupported receipt transport/);
    await assert.rejects(w.reconcileDirectConservationReceipt(h.provider, c, r.txHash, { ...r.options, expectedSafeTxHash: id('wrong-safe-hash') }), /matching Safe/);
    const parsed = Array.from(safeCall.decodeFunctionData('execTransaction', r.tx.data));
    parsed[3] = 1n;
    r.tx.data = safeCall.encodeFunctionData('execTransaction', parsed);
    await assert.rejects(reconcile(h, c, r), /exact CALL/);
  }
  for (const attack of ['value', 'data', 'early', 'failure', 'removed', 'wrong-block']) {
    const h = setup();
    const c = await capture(h);
    const r = installBuy(h, c, { safe: 'legacy' });
    if (attack === 'value' || attack === 'data') {
      const parsed = Array.from(safeCall.decodeFunctionData('execTransaction', r.tx.data));
      if (attack === 'value')
        parsed[1] = 11n;
      else
        parsed[2] = '0x1234';
      r.tx.data = safeCall.encodeFunctionData('execTransaction', parsed);
    }
    else if (attack === 'early') {
      r.receipt.logs.unshift(r.receipt.logs.pop());
      renumber(r.receipt.logs);
    }
    else if (attack === 'failure')
      r.receipt.logs.at(-1).topics[0] = id('ExecutionFailure(bytes32,uint256)');
    else if (attack === 'removed')
      r.receipt.logs[0].removed = true;
    else
      r.receipt.logs[0].blockHash = id('wrong-block');
    await assert.rejects(reconcile(h, c, r));
  }
});
test('shared Safe verification uses owned log snapshot despite provider mutation during readback', async () => {
  const h = setup();
  const c = await capture(h);
  const r = installBuy(h, c, { safe: 'indexed' });
  const success = r.receipt.logs.at(-1);
  success.topics[1] = id('wrong-in-original');
  h.mutate = ({ name }) => {
    if (name === 'directPrimaryBindings')
      success.topics[1] = r.options.expectedSafeTxHash;
  };
  await assert.rejects(reconcile(h, c, r), /matching Safe/);
});
test('free mint and every auction delivery path authenticate original Core runtime at the read block', async () => {
  for (const method of ['settle', 'cancel', 'claimNoBidNFT']) {
    const { h, c, r } = await operational('english-auction', method);
    h.codeAt = (target, tag) => target === CORE && tag === r.receipt.blockNumber ? '0x6001' : undefined;
    await assert.rejects(reconcile(h, c, r), /Runtime pin/);
    h.codeAt = target => target === CORE ? '0x6001' : undefined;
    await assert.rejects(w.captureDirectConservation(h.provider, h.deployment, h.prepared, { blockTag: c.observed.blockNumber }), /Runtime pin/);
  }
  const h = setup('native-fixed', { price: 0n });
  const c = await capture(h);
  const r = installBuy(h, c, { paid: false });
  h.codeAt = (target, tag) => target === MANAGER && tag === 11 ? '0x6001' : undefined;
  await assert.rejects(reconcile(h, c, r), /Runtime pin/);
});
test('generic Safe plans preserve every original call and its actual native value', async () => {
  for (const [kind, method] of operations) {
    const { h } = await operational(kind, method);
    const plan = createSafeCallPlan(1n, `${kind} ${method}`, [{ safe: h.caller, intent: method, call: h.prepared.call, abi: fixture.abis[kind === 'native-fixed' ? 'nativeSale' : kind === 'erc20-fixed' ? 'erc20Sale' : 'auction'] }]);
    assert.equal(verifySafeCallPlan(plan, [fixture.abis[kind === 'native-fixed' ? 'nativeSale' : kind === 'erc20-fixed' ? 'erc20Sale' : 'auction']]).hash, plan.hash);
    assert.equal(plan.steps[0].transaction.operation, 0);
    assert.equal(plan.steps[0].transaction.value, h.prepared.call.value.toString());
  }
});
