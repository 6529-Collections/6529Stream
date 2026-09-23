
import assert from "node:assert/strict";
import { AbiCoder, Interface, getAddress, id, keccak256, ZeroAddress, ZeroHash } from "ethers";
import * as s from "../dist/current-canonical-native-sales.js";
import * as n from "../dist/current-canonical-native-dutch.js";
import * as e from "../dist/current-erc20-dutch.js";
import * as nw from "../dist/current-canonical-native-dutch-workflow.js";
import * as ew from "../dist/current-erc20-dutch-workflow.js";
import * as direct from "../dist/current-direct-conservation.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";
import { compiledABI, compiledInterfaces as c } from "./current-canonical-dutch-fixture.mjs";

// Compiler-ABI RPC fixtures prove client joins and failure propagation, not native admission.
const coder = AbiCoder.defaultAbiCoder();
export const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
export const H = id;
export const CODE = "0x600100";
export const CODE_HASH = keccak256(CODE);
const P = n => ({ address: A(n), codeHash: CODE_HASH });
export const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);
export const indexedSafe = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)"]);
const allABI = new Interface([...Object.values(c).flatMap(iface => iface.fragments.filter(f => f.type === "function" || f.type === "event")), "function nonces(address owner) view returns(uint256)"]);
const clone = structuredClone;
const floorTuple = "tuple(bytes32 receiptHash,address recorder,bytes32 recorderCodeHash,bytes32 settlementKey,bytes32 candidatePayloadHash,bytes32 candidateCommitment,bytes32 resultHash,uint256 collectionId,uint256 tokenId,bytes32 effectiveTier,bytes32 firstSaleReceiptHash,bytes32 releaseReceiptHash,uint64 recordedAt)";

function zero(type) {
  if (type.baseType === "array") return [];
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(x => [x.name, zero(x)]));
  if (type.type === "bool") return false;
  if (type.type === "address") return ZeroAddress;
  if (type.type === "bytes") return "0x";
  if (type.type.startsWith("bytes")) return `0x${"00".repeat(Number(type.type.slice(5)))}`;
  if (type.type === "string") return "";
  return 0n;
}

export function setup(options = {}) {
  const family = options.family ?? "native";
  const erc = family === "erc20";
  const w = erc ? ew : nw;
  const mode = options.mode ?? "direct";
  const signed = options.signed ?? false;
  const price = options.price ?? 100n;
  const startPrice = options.startPrice ?? (price===0n?100n:price);
  const minedBlock=options.minedBlock??11;
  const minedTime=BigInt(minedBlock*10);
  const value = options.value ?? (erc ? 0n : startPrice) + (options.fee ?? 0n) + (options.credit ?? 0n);
  const fee = options.fee ?? 0n;
  let credit = options.credit ?? 0n;
  const declared = options.declared ?? (fee !== 0n);
  const caller = options.caller ?? A(30);
  const d = { chainId: 1n, adapter: P(10), manager: P(11), ledger: P(12), recorder: P(13), core: P(14), linkedDependencies: [], refundLinkedDependencies: [], historyLinkedDependencies: [], revocationLinkedDependencies: [], ...(erc ? { paymentAdapter: P(23), asset: P(24), permit2: P(25) } : {}) };
  const coords = { chainId: 1n, adapter: A(10), manager: A(11), ledger: A(12), recorder: A(13), ...(erc ? { paymentAdapter: A(23) } : {}) };
  const iface = erc ? c.erc20Dutch : c.nativeDutch;
  const config = {
    collectionId: 1n, phaseId: H("phase"), saleKind: 3n,
    authorityMode: signed ? 1n : 2n, unitPrice: erc ? 0n : startPrice,
    startsAt: 2n, endsAt: 9000n, manualClose: false, saleSupplyLimit: options.open ? 10n : 1n,
    mintPolicyHash: H("bound"), expectedPrimaryPolicyHash: H("primary"),
    primaryPolicyMode: 0n, priceCounterId: ZeroHash,
    signer: signed ? { authorizer: A(31), kind: 2n, evidenceHash: H("signer"), revision: 1n, installingAuthority: A(32) }
      : { authorizer: ZeroAddress, kind: 0n, evidenceHash: ZeroHash, revision: 0n, installingAuthority: ZeroAddress },
  };
  const counters = [];
  const proofs = [];
  if (options.allowlist) {
    for (let i = 0; i < 2; i++) {
      const counterId = H(`counter-${i}`);
      const proof = { maxCount: 5n, hasPriceOverride: i === 1, priceOverride: 0n, proof: [] };
      const account = i === 0 ? caller : A(34);
      const capRoot = keccak256(keccak256(coder.encode(
        ["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256"],
        [H("6529STREAM_MINT_ALLOWLIST_LEAF_V1"), 1n, A(11), 1n, config.phaseId, counterId, account, 5n, proof.hasPriceOverride, 0n])));
      const definition = { scope: 1n, keyMode: i === 0 ? 2n : 3n, capRoot, metadataHash: H(`definition-${i}`) };
      const counterConfigHash = keccak256(coder.encode(["bytes32", "tuple(uint8 scope,uint8 keyMode,bytes32 capRoot,bytes32 metadataHash)"],
        [H("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition]));
      counters.push({ counterId, definitionExists: true, definition, config: { enabled: true, keyMode: definition.keyMode,
        capMode: 3n, deltaMode: 0n, staticCap: 9n, staticIncrement: 1n, counterConfigHash } });
      proofs.push(proof);
    }
    config.priceCounterId = counters[1].counterId;
  }
  const schedule = { startPrice, restingPrice: price, startTime: 2n, endTime: options.scheduleEnd??(price===0n&&options.startPrice===undefined?90n:110n), decayKind: 0n, stepSeconds: 0n, stepAmount: 0n };
  const cfg = { sale: config, schedule, declaredFree: price === 0n, ...(erc ? { asset: A(24), paymentAdapter: A(23) } : {}) };
  const saleId = erc ? e.erc20DutchSaleId(coords, 1n, config.phaseId, 1n) : n.canonicalNativeDutchSaleId(coords, 1n, config.phaseId, 1n);
  const purchase = { saleId, payer: options.payer ?? caller, executor: caller, initialRecipient: A(33), beneficiary: A(34), tokenData: "0x1234", mintCommitment: H("mint"), resolverData: options.allowlist ? s.encodeCanonicalNativeSalesAllowlistProofs(proofs.map(p => [p])) : "0x", executionNonce: 1n };
  const authOptions = { nonce: H("nonce"), deadline: options.deadline ?? 9000n, unitPrice: options.maximum ?? startPrice };
  const authorization = signed ? (erc ? e.erc20DutchExpectedAuthorization(coords, cfg, purchase, authOptions) : n.canonicalNativeDutchExpectedAuthorization(coords, cfg, purchase, authOptions)) : null;
  const signature = { authorizer: A(31), kind: 2n, signature: "0x" };
  const configHash = erc ? e.erc20DutchConfigurationHash(coords, cfg) : n.canonicalNativeDutchConfigurationHash(coords, cfg);
  const base = { config, configHash, saleNonce: 1n, soldQuantity: 0n, closed: false,
    lifecycle: { saleCreatedAt: 1n, saleAdapterRegistryRevision: 1n, ...(erc ? { paymentAdapter: A(23), paymentAdapterRegistryRevision: 1n } : {}) },
    artistId: H("artist"), artistGeneration: 1n, artistBindingHash: H("binding") };
  const scheduleHash = n.canonicalNativeDutchScheduleHash({chainId:1n,adapter:A(10),manager:A(11),ledger:A(12),recorder:A(13)}, saleId, schedule);
  const record = erc ? { ...base, config: cfg, priceScheduleHash: scheduleHash } : { sale: base, schedule, priceScheduleHash: scheduleHash, declaredFree: cfg.declaredFree };
  const execution = erc ? signed ? { purchase, authorization, signature } : e.erc20DutchPublicExecution(purchase) : null;
  const paymentRequest = erc ? e.prepareERC20DutchPaymentRequest(coords, CODE_HASH, configHash, options.requestMaximum ?? startPrice, execution) : null;
  const lane = options.lane ?? "ByPayer";
  const intent = { payer: purchase.payer, asset: A(24), maxAmount: options.intentMaximum ?? startPrice, saleRef: saleId,
    expectedPrimaryPolicyHash: config.expectedPrimaryPolicyHash, nonce: options.intentNonce ?? ZeroHash, deadline: options.intentDeadline ?? 9000n };
  const permit = lane === "WithEIP2612Permit" ? { permittedAmount: options.permitMaximum ?? startPrice + 100n,
    authorization: { deadline: options.permitDeadline ?? 9000n, v: 27n, r: H("r"), s: H("s") } }
    : { permittedAmount: options.permitMaximum ?? startPrice + 100n, authorization: { nonce: 257n, deadline: options.permitDeadline ?? 9000n, signature: "0x" } };
  let request = erc ? { kind: `settleERC20DutchSale${lane}`, request: paymentRequest, value,
    ...(lane === "WithIntent" ? { intent, signature: "0x" } : lane === "ByPayer" ? {} : { permit }) }
    : signed ? { kind: "purchaseSigned", purchase, authorization, signature, value } : { kind: "purchasePublic", purchase, value };
  const prepare = r => erc ? e.prepareERC20DutchCall(coords, caller, r) : n.prepareCanonicalNativeDutchCall(coords, caller, r);
  let prepared = prepare(request);
  const batch = erc ? e.erc20DutchMintBatch(prepared, record) : n.canonicalNativeDutchMintBatch(prepared, record);
  const digest = signed ? (erc ? e.erc20DutchAuthorizationPayload(coords, authorization) : n.canonicalNativeDutchAuthorizationPayload(coords, authorization)).digest : ZeroHash;
  const amountAt = time => (erc ? e.erc20DutchPrice : n.canonicalNativeDutchPrice)(cfg, BigInt(time), signed ? authorization.unitPrice : null,
    options.allowlist ? { hasOverride: true, overridePrice: 0n } : { hasOverride: false, overridePrice: 0n }).amount;
  const amount = amountAt(minedTime);
  credit = value - (erc ? 0n : amount) - fee;
  const candidate = {
    saleAdapter: A(10), executor: caller,
    sale: { settlementId: saleId, revenueClass: H("PRIMARY_SALE"), policyMode: 0n, collectionId: 1n, tokenId: 0n, saleNonce: 1n,
      payer: purchase.payer, poster: ZeroAddress, beneficiary: purchase.beneficiary, amount, expectedPrimaryPolicyHash: config.expectedPrimaryPolicyHash },
    lifecycleBinding: base.lifecycle, executionBinding: { executionId: ZeroHash, executionNonce: 1n, authorityMode: config.authorityMode, saleAuthorizationDigest: digest },
    ...(erc ? { asset: A(24) } : {}), orchestrationOrder: 1n, mintManager: A(11), operationIdentityCommitment: H("root"), operationId: H("operation"),
    currentPolicyHash: options.grace ? H("current") : config.mintPolicyHash, boundPolicyHash: config.mintPolicyHash,
    rights: !erc && amount === 0n ? { profileId: ZeroHash, wallet: ZeroAddress, templateId: ZeroHash, assignmentHash: ZeroHash, entriesHash: ZeroHash }
      : { profileId: H("profile"), wallet: A(40), templateId: ZeroHash, assignmentHash: H("assignment"), entriesHash: H("entries") },
    saleExecutionHash: erc ? e.erc20DutchSaleExecutionHash(execution) : n.canonicalNativeDutchSaleExecutionHash(batch.contextHash, digest, batch.authorizationId),
  };
  candidate.executionBinding.executionId = erc ? e.erc20DutchExecutionId(1n, candidate) : s.canonicalNativeSalesExecutionId(1n, candidate);
  const key = amount === 0n ? ZeroHash : s.canonicalNativeSalesSettlementKey(1n, A(13), A(10), candidate.executionBinding.executionId);
  const receipt = { saleId, executionId: candidate.executionBinding.executionId, authorizationId: batch.authorizationId, saleAuthorizationDigest: digest,
    operationRoot: candidate.operationIdentityCommitment, operationId: candidate.operationId, tokenId: 123n, settlementKey: key,
    chargedAmount: amount, revealFee: fee, revealCredit: credit };
  const quote = { coordinator: A(20), coordinatorCodeHash: CODE_HASH, policy: { declared, requestMode: options.ownerWindow ? 1n : 0n,
    revealOwnerRole: ZeroHash, requestSLOBlocks: declared ? 10n : 0n, revealFeePerTokenWei: fee } };
  const policy = { configured: true, explicitPolicy: true, frozen: true, mode: declared ? 2n : 1n, securityClass: declared ? 0n : 1n,
    renderRequirement: options.notRequired ? 1n : 0n, revision: 1n, providerEpoch: 1n, policyHash: H("entropy-policy"),
    contentStateHash: H("entropy-content"), lastActionId: H("entropy-action"), artistConsentRecord: H("entropy-consent") };
  const row = { status: options.deprecated ? 2n : 1n, moduleType: H(erc ? "DUTCH_AUCTION_ADAPTER" : "NATIVE_PRIMARY_SALE_ADAPTER"), moduleVersion: H("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
    interfaceId: erc ? "0x2d8995b3" : `0x${c.nativeBinding.fragments.filter(f => f.type === "function").reduce((v, f) => v ^ BigInt(f.selector), 0n).toString(16).padStart(8, "0")}`,
    moduleGasLimit: 500000n, runtimeCodeHash: CODE_HASH, deploymentManifestHash: H("deployment"), moduleManifestHash: H("manifest"), moduleManifestURI: "ipfs://manifest",
    registeredAt: 1n, statusUpdatedAt: options.deprecated ? 50n : 1n, revision: options.deprecated ? 2n : 1n };
  const result = { candidateCommitment: erc ? e.erc20DutchCandidateCommitment(1n,A(23),A(13),candidate) : s.canonicalNativeSalesCandidateCommitment(1n, A(13), candidate), settlementKey: key,
    profileId: candidate.rights.profileId, wallet: candidate.rights.wallet, asset: erc ? A(24) : ZeroAddress, amount, executor: caller,
    executionId: receipt.executionId, escrowed: false, operationIdentityCommitment: receipt.operationRoot,
    currentPolicyHash: candidate.currentPolicyHash, boundPolicyHash: candidate.boundPolicyHash };
  const floorCoordinates = { chainId: 1n, core: A(14), floor: A(21) };
  const firstSale = { receiptHash: ZeroHash, collectionId: 1n, effectiveTier: H(options.tier ?? "CONSERVATION_WAIVED"), recorder: options.retainedFloor ? A(88) : A(13), settlementKey: options.retainedFloor ? H("old-key") : key,
    recordedAt: options.retainedFloor ? 20n : minedTime, sourceId: 1n, sourceSetHash: H("sources"), facts: zero(c.floor.getFunction("firstSale").outputs[0].components.find(x => x.name === "facts")) };
  firstSale.receiptHash = direct.directConservationFirstSaleReceiptHash(floorCoordinates, firstSale);
  const release = options.tier ? {
    receiptHash: ZeroHash, releaseKey: ZeroHash, collectionId: 1n, effectiveTier: firstSale.effectiveTier,
    recorder: firstSale.recorder, settlementKey: firstSale.settlementKey, recordedAt: firstSale.recordedAt,
    sourceId: 1n, sourceSetHash: H("source-set"), context: { scopeSubject: H("scope"), membershipHash: H("members"),
      mediaInventoryHash: H("media"), scriptSourceHash: ZeroHash, sourceContextHash: H("source-context"), scriptWork: false },
    facts: { sourceContextHash: H("source-context"), mediaEvidenceHash: H("media-proof"), referenceEvidenceHash: H("reference") },
  } : null;
  if (release) {
    release.releaseKey = direct.directConservationReleaseKey(1n, A(14), 1n, release.context);
    release.receiptHash = direct.directConservationReleaseReceiptHash(floorCoordinates, release);
  }
  const floorReceipt = { receiptHash: ZeroHash, recorder: A(13), recorderCodeHash: CODE_HASH, settlementKey: key,
    candidatePayloadHash: erc ? e.erc20DutchAccountingContextHash(candidate) : s.canonicalNativeSalesAccountingContextHash(candidate), candidateCommitment: result.candidateCommitment,
    resultHash: keccak256(s.encodeCanonicalNativeSalesResult(result)), collectionId: 1n, tokenId: 0n,
    effectiveTier: firstSale.effectiveTier, firstSaleReceiptHash: firstSale.receiptHash, releaseReceiptHash: release?.receiptHash ?? ZeroHash, recordedAt: minedTime };
  floorReceipt.receiptHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address", floorTuple],
    [H("6529STREAM_CONSERVATION_SETTLEMENT_RECEIPT_V1"), 1n, A(14), A(21), floorReceipt]));
  const candidateAt = time => {
    const v = clone(candidate); v.sale.amount = amountAt(time);
    if (!erc) v.rights = v.sale.amount === 0n ? { profileId: ZeroHash, wallet: ZeroAddress, templateId: ZeroHash, assignmentHash: ZeroHash, entriesHash: ZeroHash }
      : { profileId: H("profile"), wallet: A(40), templateId: ZeroHash, assignmentHash: H("assignment"), entriesHash: H("entries") };
    return v;
  };
  const paymentResult = time => { const v=candidateAt(time); return { revenueOutcome: v.sale.amount===0n?1n:2n, executionId:v.executionBinding.executionId,
    settlement:v.sale.amount===0n?zero(c.payment.getFunction("settleERC20DutchSaleByPayer").outputs[0].components[2]):{...result,amount:v.sale.amount,candidateCommitment:e.erc20DutchCandidateCommitment(1n,A(23),A(13),v)} }; };
  const state = { installed: false, kind: request.kind, mode, overrides: new Map(), logs: [], tx: null, receipt: null,
    historicalCredit: 0n, historicalLiability: 0n, codeGone: new Set(), calls: [], quote, policy, row, record, candidate,
    mutateAfterReceipt: null, callError: null, onCall: null, unknownExecution: false };
  const all = allABI;
  const pointer = target => [target, CODE_HASH, false, H("MODULE_REGISTRY"), "0x12345678", A(15), 1n, H("manifest"), H("deployment"), 1n];
  const provider = {
    async getNetwork() { return { chainId: 1n }; },
    async getBlock(tag) { return { number: tag, hash: H(`block-${tag}`), timestamp: tag * 10 }; },
    async getCode(target) { return state.codeGone.has(target) ? "0x" : CODE; },
    async getBalance(target, tag) {
      if (target !== A(10)) return 0n;
      return state.installed && tag >= minedBlock ? 1000n + (state.kind === "claimRefund" ? -state.historicalCredit : credit) : 1000n;
    },
    async call(call) {
      const responseABI = call.to === A(10) ? iface : call.to === A(23) ? c.payment : all;
      const parsed = responseABI.parseTransaction({ data: call.data });
      const encode = (fn, output) => responseABI.encodeFunctionResult(fn, output);
      assert.ok(parsed, `Unknown ABI request ${call.data.slice(0, 10)}`);
      const name = parsed.name;
      const args = parsed.args;
      const tag = call.blockTag;
      const end = state.installed && tag >= minedBlock;
      state.calls.push({ name, to: call.to, from: call.from, tag, value: call.value });
      if (state.onCall) await state.onCall(name, call, parsed);
      if (state.overrides.has(name)) return encode(parsed.fragment, await state.overrides.get(name)(call, args));
      if (name === state.kind) {
        if (state.callError) throw state.callError;
        assert.equal(call.from, prepared.caller);
        assert.equal(call.value, prepared.call.value);
        if (name === "claimRefund") return "0x";
        if (name === "voidMintImmediateSaleAuthorization") return encode(parsed.fragment, [batch.authorizationId]);
        return encode(parsed.fragment, [erc ? paymentResult(tag*10) : { ...receipt, chargedAmount:amountAt(tag*10), settlementKey:amountAt(tag*10)===0n?ZeroHash:key, revealCredit:value-amountAt(tag*10)-fee }]);
      }
      let out;
      const addresses = { core: 14, mintManager: 11, mintLedger: 12, primarySaleSettlement: 13, moduleRegistry: 15,
        revenueResolver: 16, splitFactory: 17, assetPolicyRegistry: 18, artistRegistry: 19, revenueEscrow: 22 };
      if (Object.hasOwn(addresses, name)) out = [A(addresses[name])];
      else if (/CodeHash$/.test(name)) out = [CODE_HASH];
      else switch (name) {
        case "getSatellitePointer": out = pointer(args[0] === H("ENTROPY_COORDINATOR") ? A(20) : args[0] === H("ARTIST_REGISTRY") ? A(19) : A(15)); break;
        case "moduleRecord": out = [args[0]===A(23)?{...state.row,moduleType:H("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),interfaceId:"0x1dfe133f"}:state.row]; break;
        case "supportsInterface": out = [true]; break;
        case "saleRecord": case "dutchSaleRecord": out = [end && (state.kind.startsWith("purchase") || state.kind.startsWith("settle"))
          ? erc ? {...record,soldQuantity:1n,closed:!options.open} : {...record,sale:{...base,soldQuantity:1n,closed:!options.open}}
          : state.record]; break;
        case "saleConfigurationHash": out = [base.configHash]; break;
        case "eip712Domain": out = ["0x0f", call.to===A(23)?"6529StreamPaymentIntentVerifier":"6529Stream Sales", "1", 1n, call.to, ZeroHash, []]; break;
        case "authorizationDigest": out = [digest]; break;
        case "nextExecutionNonce": out = [end && (state.kind.startsWith("purchase") || state.kind.startsWith("settle")) ? 2n : 1n]; break;
        case "previewSignedPurchase": out = [candidateAt(tag*10)]; break;
        case "previewPublicPurchase": out = [candidateAt(tag*10), batch.authorizationId]; break;
        case "resolveERC20DutchExecution": assert.equal(call.from,A(23));out=[candidateAt(tag*10)];break;
        case "previewSingleStepMintOperation": assert.equal(call.from, A(10), "Manager executor is adapter"); out = [receipt.operationRoot, [receipt.operationId]]; break;
        case "phasePolicyHash": out = [candidate.currentPolicyHash]; break;
        case "phaseCounterIds": out = [counters.map(row => row.counterId)]; break;
        case "counterConfig": out = [counters.find(row => row.counterId === args[2]).config]; break;
        case "counterDefinitionForManager": out = [true, counters.find(row => row.config.counterConfigHash === args[1]).definition]; break;
        case "executionStatus": out = [state.unknownExecution ? 0n : end ? 2n : 0n]; break;
        case "executionReceipt": out = [state.unknownExecution || !end ? zero(parsed.fragment.outputs[0]) : receipt]; break;
        case "isManagerAuthorizationUsed": case "isManagerOperationRootUsed": out = [end]; break;
        case "saleRevealQuote": out = [state.quote]; break;
        case "collectionEntropyPolicy": out = [state.policy]; break;
        case "refundableBalance": out = [end ? state.kind === "claimRefund" ? 0n : state.historicalCredit + credit : state.historicalCredit]; break;
        case "refundLiability": out = [end ? state.kind === "claimRefund" ? state.historicalLiability - state.historicalCredit : state.historicalLiability + credit : state.historicalLiability]; break;
        case "conservationFloor": out = [A(21), CODE_HASH]; break;
        case "activePublicNativeCandidate": case "activePublicERC20Candidate": out = [ZeroHash]; break;
        case "tokenCollectionIdentity": out = [true, 1n, 1n, false]; break;
        case "tokenLifecycle": out = [2n]; break;
        case "coordinatorAtMint": out = [A(20)]; break;
        case "settlementConsumed": out = [end]; break;
        case "settlementResult": out = [result]; break;
        case "settlementReceipt": out = [floorReceipt]; break;
        case "firstSale": out = [end || options.retainedFloor ? firstSale : zero(parsed.fragment.outputs[0])]; break;
        case "releaseFloorReceipt": out = [end || options.retainedFloor ? release : zero(parsed.fragment.outputs[0])]; break;
        case "immediateSaleAuthorizationBinding": out = [1n, config.phaseId, config.saleKind, 1n, base.configHash, A(31), 2n]; break;
        case "mintSaleAuthorizationId": out = [batch.authorizationId]; break;
        case "dutchResolutionProfile":out=[H("6529STREAM_ERC20_STANDARD_DUTCH_V1")];break;
        case "phase":out=call.to===A(23)?[0n]:[true,{paused:false,startTime:1n,endTime:options.phaseEnd??9000n,maxBatchQuantity:1n,configHash:H("phase"),metadataHash:H("metadata")}];break;
        case "policyGrace":out=[config.mintPolicyHash,1n,options.graceUntil??9000n];break;
        case "assetPolicy":out=[1n,H("asset-policy"),1n,0n];break;
        case "assetPolicyHash":out=[H("asset-policy")];break;
        case "assetPolicyRevision":out=[1n];break;
        case "assetPermitPolicy":out=[{capabilities:3n,permit2AllowanceMode:options.allowanceMode??1n,permit2:A(25),permit2CodeHash:CODE_HASH,assetCodeHash:CODE_HASH,assetPolicyHash:H("asset-policy"),assetPolicyRevision:1n,revision:1n}];break;
        case "permit2":out=[A(25)];break;
        case "permit2ChainId":out=[1n];break;
        case "balanceOf":out=[args[0]===purchase.payer?10000n-(end?amount:0n):1000n];break;
        case "allowance": { const approval=options.approval??10000n;out=[end?(lane==="WithEIP2612Permit"?(options.retainMaximum?permit.permittedAmount:permit.permittedAmount-amount):(approval===(1n<<256n)-1n&&options.allowanceMode===2n?approval:approval-amount)):approval];break; }
        case "nonces":out=[end?6n:5n];break;
        case "nonceBitmap":out=[end?2n:0n];break;
        case "isPaymentIntentNonceUsed":out=[end&&amount!==0n];break;
        case "paymentIntentDigest":out=[e.erc20DutchPaymentIntentPayload(coords,intent).digest];break;
        default: throw Error(`Unexpected RPC ${name}`);
      }
      return encode(parsed.fragment, out);
    },
    async getTransactionReceipt() { return state.receipt; },
    async getTransaction() {
      if (state.mutateAfterReceipt) state.mutateAfterReceipt();
      return state.tx;
    },
  };
  function event(target, contract, name, args) {
    const log = contract.encodeEventLog(contract.getEvent(name), args);
    state.logs.push({ address: target, ...log });
  }
  function install(kind = state.kind) {
    state.kind = kind;
    state.logs = [];
    const common = [key, H("PRIMARY_SALE"), result.profileId, 1n];
    if (kind === "claimRefund") {
      event(A(10), iface, "SaleRefundClaimed", [1n, saleId, caller, A(35), state.historicalCredit]);
    } else if (kind === "voidMintImmediateSaleAuthorization") {
      event(A(12), c.ledger, "MintLedgerAuthorizationVoided", [1n, batch.authorizationId, A(11)]);
      event(A(11), c.manager, "MintAuthorizationVoided", [1n, 1n, config.phaseId, batch.authorizationId, A(31), A(10), 2n]);
    } else {
      const name = erc ? "ERC20DutchExecution" : "DutchSaleExecution";
      if(erc&&lane==="WithIntent"&&amount!==0n)event(A(23),c.payment,"PaymentIntentConsumed",[purchase.payer,saleId,intent.nonce,1n,A(24),amount]);
      event(A(10), iface, name, erc?[saleId,receipt.executionId,1n,amount===0n?1n:2n,{...receipt,tokenId:0n,settlementKey:ZeroHash}]:[saleId, receipt.executionId, receipt.operationRoot, 1n, { ...receipt, tokenId: 0n, settlementKey: ZeroHash }]);
      if (amount !== 0n) {
        if (!options.retainedFloor) {
          event(A(21), c.floor, "ConservationFirstSaleRecorded", [1n, firstSale.receiptHash, firstSale, 1n]);
          if (release) event(A(21), c.floor, "ConservationReleaseFloorRecorded", [release.releaseKey, release.receiptHash, release, 1n]);
        }
        event(A(21), c.floor, "ConservationSettlementRecorded", [key, floorReceipt.receiptHash, floorReceipt, 1n]);
        event(A(13), c.recorder, "PrimaryRevenueSettled", [...common, result.wallet, erc?A(24):ZeroAddress, purchase.payer, amount,
          keccak256(coder.encode([s.CANONICAL_NATIVE_SALES_PRIMARY_SALE_TUPLE], [candidate.sale])), false, 1n]);
        event(A(13), c.recorder, "PrimaryRevenueSettlementContext", [...common, A(10), saleId, 0n, 1n, 0n, receipt.operationRoot, receipt.operationId, 1n, ZeroAddress, purchase.beneficiary, ZeroHash]);
        event(A(13), c.recorder, "PrimaryRevenueSettlementPolicy", [...common, config.expectedPrimaryPolicyHash, config.expectedPrimaryPolicyHash, candidate.rights.assignmentHash, ZeroHash]);
        event(A(13), c.recorder, "PrimaryRevenueExecutionBound", [key, A(10), receipt.executionId, 1n, caller, erc?A(23):ZeroAddress, result.candidateCommitment, candidate.currentPolicyHash, candidate.boundPolicyHash]);
      }
      event(A(12), c.ledger, "MintLedgerAuthorizationConsumed", [1n, batch.authorizationId, receipt.operationRoot, A(11), config.mintPolicyHash]);
      event(A(12), c.ledger, "MintLedgerOperationRootConsumed", [1n, receipt.operationRoot, A(11), candidate.currentPolicyHash, config.mintPolicyHash, batch.authorizationId]);
      event(A(11), c.manager, "MintTokenExecuted", [1n, receipt.operationId, receipt.tokenId, receipt.operationRoot, 1n, config.phaseId, 0n, purchase.initialRecipient, purchase.beneficiary, keccak256(purchase.tokenData), purchase.mintCommitment]);
      event(A(11), c.manager, "MintAuthorizationConsumed", [1n, 1n, config.phaseId, batch.authorizationId, config.mintPolicyHash, receipt.operationRoot]);
      event(A(11), c.manager, "MintBatchExecuted", [1n, receipt.operationRoot, 1n, config.phaseId, A(10), purchase.payer, ZeroAddress, receipt.tokenId, 1n, batch.contextHash, ZeroHash, candidate.currentPolicyHash, config.mintPolicyHash]);
      if (declared && !options.notRequired && !options.ownerWindow) {
        event(A(10), iface, "ImmediateRevealAttempt", options.revealSuccess
          ? [1n, 1n, receipt.tokenId, true, H("request"), 0n, 64n, "0x"]
          : [1n, 1n, receipt.tokenId, false, ZeroHash, 0n, 2n, "0x1234"]);
      }
      if (credit) event(A(10), iface, "SalePaymentExcessCredited", [1n, saleId, caller, credit]);
      if (!options.open) event(A(10), iface, "ImmediateSaleClosed", [saleId, 1n]);
      if (amount === 0n && !erc) event(A(10), iface, "FreeDutchExecuted", [saleId, receipt.executionId, receipt.tokenId, batch.authorizationId]);
      event(A(10), iface, name, erc?[saleId,receipt.executionId,2n,amount===0n?1n:2n,receipt]:[saleId, receipt.executionId, receipt.operationRoot, 2n, receipt]);
    }
    const safeHash = H("safe-transaction");
    if (mode !== "direct") event(caller, mode === "indexed" ? indexedSafe : safe, "ExecutionSuccess", [safeHash, 0n]);
    const txHash = H("tx");
    state.installed = true;
    state.tx = { to: mode === "direct" ? prepared.call.to : caller, from: mode === "direct" ? caller : A(90),
      value: mode === "direct" ? prepared.call.value : 0n,
      data: mode === "direct" ? prepared.call.data : safe.encodeFunctionData("execTransaction", [prepared.call.to, prepared.call.value, prepared.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x1234"]),
      hash: txHash, blockNumber: minedBlock, blockHash: H(`block-${minedBlock}`), chainId: 1n };
    state.receipt = { status: 1, hash: txHash, from: state.tx.from, to: state.tx.to, blockNumber: minedBlock, blockHash: H(`block-${minedBlock}`), logs: state.logs };
    renumber();
    return txHash;
  }
  function renumber() {
    state.logs.forEach((log, i) => Object.assign(log, { index: i, removed: false, transactionHash: H("tx"), blockHash: H(`block-${minedBlock}`), blockNumber: minedBlock }));
  }
  function changeRequest(next) { request = next; prepared = prepare(next); state.kind = next.kind; }
  const capture = () => (erc?w.captureERC20Dutch:w.captureCanonicalNativeDutch)(provider, d, prepared, { blockTag: 10 });
  const reconcile = (saved, extra = {}) => (erc?w.reconcileERC20DutchReceipt:w.reconcileCanonicalNativeDutchReceipt)(provider, saved, H("tx"), {
    ...(mode === "direct" ? { execution: "direct" } : { execution: "safe", expectedSafeTxHash: H("safe-transaction") }), ...extra,
  });
  return { d, coords, provider, state, family, mode, caller, iface, config, cfg, purchase, record, authorization,
    batch, candidate, receipt, firstSale, floorReceipt, release, result, quote, policy, saleId, counters, proofs, get prepared() { return prepared; },
    capture, reconcile, install, renumber, event, changeRequest, candidateAt, amountAt, lane, permit, intent, paymentResult,
    simulate: saved => (erc?ew.simulateERC20Dutch:nw.simulateCanonicalNativeDutch)(provider,saved,{blockTag:10,gasLimit:5_000_000n}),
    inspect: () => (erc?ew.inspectERC20Dutch:nw.inspectCanonicalNativeDutch)(provider,d,{saleId,executionId:receipt.executionId},{blockTag:minedBlock}) };
}
