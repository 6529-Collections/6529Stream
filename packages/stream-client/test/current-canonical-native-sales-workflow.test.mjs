import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, getAddress, id, keccak256, ZeroAddress, ZeroHash } from "ethers";
import * as s from "../dist/current-canonical-native-sales.js";
import * as w from "../dist/current-canonical-native-sales-workflow.js";
import * as direct from "../dist/current-direct-conservation.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";
import { compiledABI, compiledInterfaces as c } from "./current-canonical-native-sales-fixture.mjs";

// Compiler-ABI RPC fixtures prove client joins and failure propagation, not native admission.
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = id;
const CODE = "0x600100";
const CODE_HASH = keccak256(CODE);
const P = n => ({ address: A(n), codeHash: CODE_HASH });
const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);
const indexedSafe = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)"]);
const allABI = new Interface(Object.values(c).flatMap(iface => iface.fragments.filter(f => f.type === "function" || f.type === "event")));
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

function setup(options = {}) {
  const family = options.family ?? "claim";
  const mode = options.mode ?? "direct";
  const signed = options.signed ?? false;
  const price = options.price ?? (family === "immediate" ? 100n : 0n);
  const fee = options.fee ?? 0n;
  const credit = options.credit ?? 0n;
  const declared = options.declared ?? (fee !== 0n || credit !== 0n);
  const caller = options.caller ?? A(30);
  const d = { chainId: 1n, family, adapter: P(10), manager: P(11), ledger: P(12), recorder: P(13), core: P(14), linkedDependencies: [] };
  const coords = { chainId: 1n, adapter: A(10), manager: A(11), ledger: A(12), recorder: A(13) };
  const iface = c[family];
  const config = {
    collectionId: 1n, phaseId: H("phase"), saleKind: family === "immediate" ? (options.open ? 1n : 0n) : price === 0n && !options.pwyw ? 12n : 13n,
    authorityMode: signed ? 1n : 2n, unitPrice: family === "immediate" ? price : 0n,
    startsAt: 1n, endsAt: 9000n, manualClose: false, saleSupplyLimit: options.open ? 0n : 1n,
    mintPolicyHash: H("bound"), expectedPrimaryPolicyHash: family === "claim" && price === 0n && !options.pwyw ? ZeroHash : H("primary"),
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
  const cfg = family === "immediate" ? config : { sale: config, maxUnitPrice: config.saleKind === 12n ? 0n : 1000n };
  const saleId = s.canonicalNativeSalesSaleId(coords, family, 1n, config.phaseId, 1n);
  const purchase = { saleId, payer: caller, executor: caller, initialRecipient: A(33), beneficiary: A(34), tokenData: "0x1234", mintCommitment: H("mint"), resolverData: options.allowlist ? s.encodeCanonicalNativeSalesAllowlistProofs(proofs.map(p => [p])) : "0x", executionNonce: 1n };
  const wrappedPurchase = family === "immediate" ? purchase : { mint: purchase, chosenUnitPrice: price };
  const authorization = signed ? s.canonicalNativeSalesExpectedAuthorization(coords, family, cfg, wrappedPurchase,
    { nonce: H("nonce"), deadline: options.deadline ?? 9000n, unitPrice: options.minimum ?? config.unitPrice }) : null;
  let request = signed
    ? { family, kind: "purchaseSigned", purchase: wrappedPurchase, authorization, signature: { authorizer: A(31), kind: 2n, signature: "0x" }, value: price + fee + credit }
    : { family, kind: "purchasePublic", purchase: wrappedPurchase, value: price + fee + credit };
  const base = { config, configHash: s.canonicalNativeSalesConfigurationHash(coords, family, cfg), saleNonce: 1n, soldQuantity: 0n, closed: false,
    lifecycle: { saleCreatedAt: 1n, saleAdapterRegistryRevision: 1n }, artistId: H("artist"), artistGeneration: 1n, artistBindingHash: H("binding") };
  const record = family === "immediate" ? base : { sale: base, maxUnitPrice: cfg.maxUnitPrice };
  let prepared = s.prepareCanonicalNativeSalesCall(coords, caller, request);
  const batch = s.canonicalNativeSalesMintBatch(prepared, record);
  const digest = signed ? s.canonicalNativeSalesAuthorizationPayload(coords, authorization).digest : ZeroHash;
  const candidate = {
    saleAdapter: A(10), executor: caller,
    sale: { settlementId: saleId, revenueClass: H("PRIMARY_SALE"), policyMode: 0n, collectionId: 1n, tokenId: 0n, saleNonce: 1n,
      payer: caller, poster: ZeroAddress, beneficiary: purchase.beneficiary, amount: price, expectedPrimaryPolicyHash: config.expectedPrimaryPolicyHash },
    lifecycleBinding: base.lifecycle, executionBinding: { executionId: ZeroHash, executionNonce: 1n, authorityMode: config.authorityMode, saleAuthorizationDigest: digest },
    orchestrationOrder: 1n, mintManager: A(11), operationIdentityCommitment: H("root"), operationId: H("operation"),
    currentPolicyHash: options.grace ? H("current") : config.mintPolicyHash, boundPolicyHash: config.mintPolicyHash,
    rights: price === 0n ? { profileId: ZeroHash, wallet: ZeroAddress, templateId: ZeroHash, assignmentHash: ZeroHash, entriesHash: ZeroHash }
      : { profileId: H("profile"), wallet: A(40), templateId: ZeroHash, assignmentHash: H("assignment"), entriesHash: H("entries") },
    saleExecutionHash: s.canonicalNativeSalesExecutionHash(family, batch.contextHash, digest, batch.authorizationId),
  };
  candidate.executionBinding.executionId = s.canonicalNativeSalesExecutionId(1n, candidate);
  const key = price === 0n ? ZeroHash : s.canonicalNativeSalesSettlementKey(1n, A(13), A(10), candidate.executionBinding.executionId);
  const receipt = { saleId, executionId: candidate.executionBinding.executionId, authorizationId: batch.authorizationId, saleAuthorizationDigest: digest,
    operationRoot: candidate.operationIdentityCommitment, operationId: candidate.operationId, tokenId: 123n, settlementKey: key,
    chargedAmount: price, revealFee: fee, revealCredit: credit };
  const quote = { coordinator: A(20), coordinatorCodeHash: CODE_HASH, policy: { declared, requestMode: options.ownerWindow ? 1n : 0n,
    revealOwnerRole: ZeroHash, requestSLOBlocks: declared ? 10n : 0n, revealFeePerTokenWei: fee } };
  const policy = { configured: true, explicitPolicy: true, frozen: true, mode: declared ? 2n : 1n, securityClass: declared ? 0n : 1n,
    renderRequirement: options.notRequired ? 1n : 0n, revision: 1n, providerEpoch: 1n, policyHash: H("entropy-policy"),
    contentStateHash: H("entropy-content"), lastActionId: H("entropy-action"), artistConsentRecord: H("entropy-consent") };
  const row = { status: options.deprecated ? 2n : 1n, moduleType: H("NATIVE_PRIMARY_SALE_ADAPTER"), moduleVersion: H("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
    interfaceId: `0x${c.nativeBinding.fragments.filter(f => f.type === "function").reduce((v, f) => v ^ BigInt(f.selector), 0n).toString(16).padStart(8, "0")}`,
    moduleGasLimit: 500000n, runtimeCodeHash: CODE_HASH, deploymentManifestHash: H("deployment"), moduleManifestHash: H("manifest"), moduleManifestURI: "ipfs://manifest",
    registeredAt: 1n, statusUpdatedAt: options.deprecated ? 50n : 1n, revision: options.deprecated ? 2n : 1n };
  const result = { candidateCommitment: s.canonicalNativeSalesCandidateCommitment(1n, A(13), candidate), settlementKey: key,
    profileId: candidate.rights.profileId, wallet: candidate.rights.wallet, asset: ZeroAddress, amount: price, executor: caller,
    executionId: receipt.executionId, escrowed: false, operationIdentityCommitment: receipt.operationRoot,
    currentPolicyHash: candidate.currentPolicyHash, boundPolicyHash: candidate.boundPolicyHash };
  const floorCoordinates = { chainId: 1n, core: A(14), floor: A(21) };
  const firstSale = { receiptHash: ZeroHash, collectionId: 1n, effectiveTier: H(options.tier ?? "CONSERVATION_WAIVED"), recorder: options.retainedFloor ? A(88) : A(13), settlementKey: options.retainedFloor ? H("old-key") : key,
    recordedAt: options.retainedFloor ? 20n : 110n, sourceId: 1n, sourceSetHash: H("sources"), facts: zero(c.floor.getFunction("firstSale").outputs[0].components.find(x => x.name === "facts")) };
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
    candidatePayloadHash: s.canonicalNativeSalesAccountingContextHash(candidate), candidateCommitment: result.candidateCommitment,
    resultHash: keccak256(s.encodeCanonicalNativeSalesResult(result)), collectionId: 1n, tokenId: 0n,
    effectiveTier: firstSale.effectiveTier, firstSaleReceiptHash: firstSale.receiptHash, releaseReceiptHash: release?.receiptHash ?? ZeroHash, recordedAt: 110n };
  floorReceipt.receiptHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address", floorTuple],
    [H("6529STREAM_CONSERVATION_SETTLEMENT_RECEIPT_V1"), 1n, A(14), A(21), floorReceipt]));
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
      return state.installed && tag >= 11 ? 1000n + (state.kind === "claimRefund" ? -state.historicalCredit : credit) : 1000n;
    },
    async call(call) {
      const responseABI = call.to === A(10) ? iface : all;
      const parsed = responseABI.parseTransaction({ data: call.data });
      const encode = (fn, output) => responseABI.encodeFunctionResult(fn, output);
      assert.ok(parsed, `Unknown ABI request ${call.data.slice(0, 10)}`);
      const name = parsed.name;
      const args = parsed.args;
      const tag = call.blockTag;
      const end = state.installed && tag >= 11;
      state.calls.push({ name, to: call.to, from: call.from, tag, value: call.value });
      if (state.onCall) await state.onCall(name, call, parsed);
      if (state.overrides.has(name)) return encode(parsed.fragment, await state.overrides.get(name)(call, args));
      if (name === state.kind) {
        if (state.callError) throw state.callError;
        assert.equal(call.from, prepared.caller);
        assert.equal(call.value, prepared.call.value);
        if (name === "claimRefund") return "0x";
        if (name === "voidMintImmediateSaleAuthorization") return encode(parsed.fragment, [batch.authorizationId]);
        return encode(parsed.fragment, [receipt]);
      }
      let out;
      const addresses = { core: 14, mintManager: 11, mintLedger: 12, primarySaleSettlement: 13, moduleRegistry: 15,
        revenueResolver: 16, splitFactory: 17, assetPolicyRegistry: 18, artistRegistry: 19, revenueEscrow: 22 };
      if (Object.hasOwn(addresses, name)) out = [A(addresses[name])];
      else if (/CodeHash$/.test(name)) out = [CODE_HASH];
      else switch (name) {
        case "getSatellitePointer": out = pointer(args[0] === H("ENTROPY_COORDINATOR") ? A(20) : args[0] === H("ARTIST_REGISTRY") ? A(19) : A(15)); break;
        case "moduleRecord": out = [state.row]; break;
        case "supportsInterface": out = [true]; break;
        case "saleRecord": out = [end && state.kind.startsWith("purchase")
          ? family === "immediate" ? { ...base, soldQuantity: 1n, closed: !options.open } : { ...record, sale: { ...base, soldQuantity: 1n, closed: !options.open } }
          : state.record]; break;
        case "saleConfigurationHash": out = [base.configHash]; break;
        case "eip712Domain": out = ["0x0f", "6529Stream Sales", "1", 1n, A(10), ZeroHash, []]; break;
        case "authorizationDigest": out = [digest]; break;
        case "nextExecutionNonce": out = [end && state.kind.startsWith("purchase") ? 2n : 1n]; break;
        case "previewSignedPurchase": out = [state.candidate]; break;
        case "previewPublicPurchase": out = [state.candidate, batch.authorizationId]; break;
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
        case "activePublicNativeCandidate": out = [ZeroHash]; break;
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
      const name = family === "immediate" ? "ImmediateSaleExecution" : "ClaimSaleExecution";
      event(A(10), iface, name, [saleId, receipt.executionId, receipt.operationRoot, 1n, { ...receipt, tokenId: 0n, settlementKey: ZeroHash }]);
      if (price !== 0n) {
        if (!options.retainedFloor) {
          event(A(21), c.floor, "ConservationFirstSaleRecorded", [1n, firstSale.receiptHash, firstSale, 1n]);
          if (release) event(A(21), c.floor, "ConservationReleaseFloorRecorded", [release.releaseKey, release.receiptHash, release, 1n]);
        }
        event(A(21), c.floor, "ConservationSettlementRecorded", [key, floorReceipt.receiptHash, floorReceipt, 1n]);
        event(A(13), c.recorder, "PrimaryRevenueSettled", [...common, result.wallet, ZeroAddress, caller, price,
          keccak256(coder.encode([s.CANONICAL_NATIVE_SALES_PRIMARY_SALE_TUPLE], [candidate.sale])), false, 1n]);
        event(A(13), c.recorder, "PrimaryRevenueSettlementContext", [...common, A(10), saleId, 0n, 1n, 0n, receipt.operationRoot, receipt.operationId, 1n, ZeroAddress, purchase.beneficiary, ZeroHash]);
        event(A(13), c.recorder, "PrimaryRevenueSettlementPolicy", [...common, config.expectedPrimaryPolicyHash, config.expectedPrimaryPolicyHash, candidate.rights.assignmentHash, ZeroHash]);
        event(A(13), c.recorder, "PrimaryRevenueExecutionBound", [key, A(10), receipt.executionId, 1n, caller, ZeroAddress, result.candidateCommitment, candidate.currentPolicyHash, candidate.boundPolicyHash]);
      }
      event(A(12), c.ledger, "MintLedgerAuthorizationConsumed", [1n, batch.authorizationId, receipt.operationRoot, A(11), config.mintPolicyHash]);
      event(A(12), c.ledger, "MintLedgerOperationRootConsumed", [1n, receipt.operationRoot, A(11), candidate.currentPolicyHash, config.mintPolicyHash, batch.authorizationId]);
      event(A(11), c.manager, "MintTokenExecuted", [1n, receipt.operationId, receipt.tokenId, receipt.operationRoot, 1n, config.phaseId, 0n, purchase.initialRecipient, purchase.beneficiary, keccak256(purchase.tokenData), purchase.mintCommitment]);
      event(A(11), c.manager, "MintAuthorizationConsumed", [1n, 1n, config.phaseId, batch.authorizationId, config.mintPolicyHash, receipt.operationRoot]);
      event(A(11), c.manager, "MintBatchExecuted", [1n, receipt.operationRoot, 1n, config.phaseId, A(10), caller, ZeroAddress, receipt.tokenId, 1n, batch.contextHash, ZeroHash, candidate.currentPolicyHash, config.mintPolicyHash]);
      if (declared && !options.notRequired && !options.ownerWindow) {
        event(A(10), iface, "ImmediateRevealAttempt", options.revealSuccess
          ? [1n, 1n, receipt.tokenId, true, H("request"), 0n, 64n, "0x"]
          : [1n, 1n, receipt.tokenId, false, ZeroHash, 0n, 2n, "0x1234"]);
      }
      if (credit) event(A(10), iface, "SalePaymentExcessCredited", [1n, saleId, caller, credit]);
      if (!options.open) event(A(10), iface, "ImmediateSaleClosed", [saleId, 1n]);
      if (price === 0n) event(A(10), iface, "FreeClaimExecuted", [saleId, receipt.executionId, receipt.tokenId, batch.authorizationId]);
      event(A(10), iface, name, [saleId, receipt.executionId, receipt.operationRoot, 2n, receipt]);
    }
    const safeHash = H("safe-transaction");
    if (mode !== "direct") event(caller, mode === "indexed" ? indexedSafe : safe, "ExecutionSuccess", [safeHash, 0n]);
    const txHash = H("tx");
    state.installed = true;
    state.tx = { to: mode === "direct" ? prepared.call.to : caller, from: mode === "direct" ? caller : A(90),
      value: mode === "direct" ? prepared.call.value : 0n,
      data: mode === "direct" ? prepared.call.data : safe.encodeFunctionData("execTransaction", [prepared.call.to, prepared.call.value, prepared.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x1234"]),
      hash: txHash, blockNumber: 11, blockHash: H("block-11"), chainId: 1n };
    state.receipt = { status: 1, hash: txHash, from: state.tx.from, to: state.tx.to, blockNumber: 11, blockHash: H("block-11"), logs: state.logs };
    renumber();
    return txHash;
  }
  function renumber() {
    state.logs.forEach((log, i) => Object.assign(log, { index: i, removed: false, transactionHash: H("tx"), blockHash: H("block-11"), blockNumber: 11 }));
  }
  function changeRequest(next) { request = next; prepared = s.prepareCanonicalNativeSalesCall(coords, caller, next); state.kind = next.kind; }
  const capture = () => w.captureCanonicalNativeSales(provider, d, prepared, { blockTag: 10 });
  const reconcile = (saved, extra = {}) => w.reconcileCanonicalNativeSalesReceipt(provider, saved, H("tx"), {
    ...(mode === "direct" ? { execution: "direct" } : { execution: "safe", expectedSafeTxHash: H("safe-transaction") }), ...extra,
  });
  return { d, coords, provider, state, family, mode, caller, iface, config, cfg, purchase, record, authorization,
    batch, candidate, receipt, firstSale, floorReceipt, release, result, quote, policy, saleId, counters, proofs, get prepared() { return prepared; },
    capture, reconcile, install, renumber, event, changeRequest };
}

test("both canonical families signed/public actual sender, positive native values and both Safe event layouts", async () => {
  for (const family of ["immediate", "claim"]) for (const signed of [false, true]) for (const mode of ["direct", "legacy", "indexed"]) {
    const f = setup({ family, signed, mode, price: 100n });
    const saved = await f.capture();
    const simulated = await w.simulateCanonicalNativeSales(f.provider, saved, { blockTag: 10, gasLimit: 5_000_000n });
    assert.equal(simulated.receipt.chargedAmount, 100n);
    assert.equal(saved.candidate.sale.beneficiary, A(34));
    assert.notEqual(saved.candidate.sale.beneficiary, f.purchase.initialRecipient);
    f.install();
    const result = await f.reconcile(saved);
    assert.equal(result.purchaseReceipt.tokenId, 123n);
    assert.equal(result.settlement.floor.receiptHash, f.floorReceipt.receiptHash);
    assert.equal(result.purchaseReceipt.revealCredit, 0n);
  }
});

test("zero claim and zero PWYW have literal zero settlement, while mint, authorization and close evidence remain", async () => {
  for (const pwyw of [false, true]) for (const signed of [false, true]) for (const mode of ["direct", "legacy", "indexed"]) {
    const f = setup({ pwyw, signed, mode });
    const saved = await f.capture();
    f.install();
    const result = await f.reconcile(saved);
    assert.equal(result.purchaseReceipt.settlementKey, ZeroHash);
    assert.equal(result.settlement, null);
    assert.equal(result.revealAttempt, null);
    assert.equal(f.state.calls.some(row => row.name === "settlementResult"), false);
  }
});

test("declared reveal fee and excess credit remain distinct; bounded request failure preserves completed purchase", async () => {
  const f = setup({ price: 0n, fee: 7n, credit: 5n });
  const saved = await f.capture();
  f.install();
  const result = await f.reconcile(saved);
  assert.equal(result.purchaseReceipt.revealFee, 7n);
  assert.equal(result.purchaseReceipt.revealCredit, 5n);
  assert.equal(result.revealAttempt.succeeded, false);
  assert.equal(result.settlement, null);
  for (const options of [{ ownerWindow: true }, { notRequired: true }]) {
    const other = setup({ ...options, fee: 7n, credit: 5n });
    const capture = await other.capture();
    other.install();
    assert.equal((await other.reconcile(capture)).revealAttempt, null);
  }
});

test("refunds are literal-caller local exits across direct and Safe without live upstream code", async () => {
  for (const family of ["immediate", "claim"]) for (const mode of ["direct", "legacy", "indexed"]) {
    const f = setup({ family, mode });
    f.state.historicalCredit = 10n;
    f.state.historicalLiability = 15n;
    f.changeRequest({ family, kind: "claimRefund", saleId: f.saleId, recipient: A(35) });
    f.state.codeGone = new Set([A(11), A(12), A(13), A(14), A(15), A(19), A(20)]);
    const saved = await f.capture();
    assert.equal((await w.simulateCanonicalNativeSales(f.provider, saved, { blockTag: 10, gasLimit: 100000n })).returnData, "0x");
    f.install();
    assert.equal((await f.reconcile(saved)).refundedAmount, 10n);
    assert.equal(f.state.calls.some(row => row.name === "saleRecord"), false);
  }
});

test("full-payload historical Manager revocation succeeds direct/relayed without sale readiness or current signer", async () => {
  for (const family of ["immediate", "claim"]) for (const mode of ["direct", "legacy", "indexed"]) {
    const f = setup({ family, signed: true, mode });
    f.changeRequest({ family, kind: "voidMintImmediateSaleAuthorization", authorization: f.authorization,
      authorizer: A(31), authorizerKind: 2n, revocationSignature: "0x" });
    f.state.codeGone = new Set([A(13), A(14), A(15), A(19), A(20)]);
    const saved = await f.capture();
    const simulated = await w.simulateCanonicalNativeSales(f.provider, saved, { blockTag: 10, gasLimit: 500000n });
    assert.equal(simulated.authorizationId, f.batch.authorizationId);
    f.install();
    assert.equal((await f.reconcile(saved)).revokedAuthorizationId, f.batch.authorizationId);
    assert.equal(f.state.calls.some(row => row.name === "saleRecord"), false);
  }
});

test("grace-current policy differs from bound and DEPRECATED requires both old timestamp and revision", async () => {
  const f = setup({ family: "immediate", signed: true, grace: true, deprecated: true });
  const saved = await f.capture();
  assert.notEqual(saved.candidate.currentPolicyHash, saved.candidate.boundPolicyHash);
  f.install();
  await f.reconcile(saved);
  for (const field of ["registeredAt", "statusUpdatedAt", "revision"]) {
    const bad = setup({ deprecated: true });
    if (field === "registeredAt") bad.state.row.registeredAt = 2n;
    if (field === "statusUpdatedAt") bad.state.row.statusUpdatedAt = 1n;
    if (field === "revision") bad.state.row.revision = 1n;
    await assert.rejects(bad.capture(), /admission/);
  }
});

test("capture fails closed on value, caller, replay, runtime delegation and contradictory preview", async () => {
  const f = setup();
  assert.throws(() => s.prepareCanonicalNativeSalesCall(f.coords, A(90), f.prepared.request), /payer|caller|actor/i);
  const value = setup();
  value.changeRequest({ ...value.prepared.request, value: 1n });
  await assert.rejects(value.capture(), /value/);
  const replay = setup();
  replay.state.overrides.set("isManagerAuthorizationUsed", () => [true]);
  await assert.rejects(replay.capture(), /replay/);
  const wrong = setup();
  wrong.state.candidate.sale.beneficiary = A(91);
  await assert.rejects(wrong.capture(), /joins/);
  const delegated = setup();
  const marker = `0xef0100${A(99).slice(2)}`;
  delegated.d.adapter.codeHash = keccak256(marker);
  delegated.provider.getCode = async () => marker;
  await assert.rejects(delegated.capture(), /Runtime pin/);
});

test("original preview and mutation reverts propagate and no moving/earlier simulation block is admitted", async () => {
  const f = setup();
  const saved = await f.capture();
  await assert.rejects(w.simulateCanonicalNativeSales(f.provider, saved, { blockTag: 9, gasLimit: 100000n }), /predates/);
  await assert.rejects(w.simulateCanonicalNativeSales(f.provider, saved, { blockTag: 10, gasLimit: 0n }), /gas/);
  f.state.callError = Object.assign(Error("original late receiver rollback"), { code: "CALL_EXCEPTION" });
  await assert.rejects(w.simulateCanonicalNativeSales(f.provider, saved, { blockTag: 10, gasLimit: 100000n }), /late receiver/);
  f.state.callError = null;
  await w.simulateCanonicalNativeSales(f.provider, saved, { blockTag: 10, gasLimit: 100000n });
  f.state.overrides.set("previewPublicPurchase", () => { throw Error("original paused/tolled-sale rejection"); });
  await assert.rejects(f.capture(), /tolled-sale/);
});


function eventIndex(f, contract, name) {
  const topic = contract.getEvent(name).topicHash;
  return f.state.logs.findIndex(log => log.topics[0] === topic);
}

function replaceEvent(f, contract, name, transform, occurrence = 0) {
  const topic = contract.getEvent(name).topicHash;
  const log = f.state.logs.filter(row => row.topics[0] === topic)[occurrence];
  const decoded = contract.decodeEventLog(name, log.data, log.topics);
  const args = transform(Array.from(decoded));
  Object.assign(log, contract.encodeEventLog(contract.getEvent(name), args));
}

function removeEvent(f, contract, name) {
  const topic = contract.getEvent(name).topicHash;
  for (let i = f.state.logs.length - 1; i >= 0; i--) {
    if (f.state.logs[i].topics[0] === topic) f.state.logs.splice(i, 1);
  }
  f.renumber();
}

test("OPEN immediate stays open and historical literal authorizer revokes expired payload directly", async () => {
  const open = setup({ family: "immediate", open: true });
  const saved = await open.capture();
  open.install();
  assert.equal((await open.reconcile(saved)).purchaseReceipt.chargedAmount, 100n);
  assert.equal(eventIndex(open, open.iface, "ImmediateSaleClosed"), -1);
  const f = setup({ family: "immediate", signed: true, caller: A(31), deadline: 1n });
  f.changeRequest({ family: "immediate", kind: "voidMintImmediateSaleAuthorization", authorization: f.authorization,
    authorizer: f.caller, authorizerKind: 2n, revocationSignature: "0x1234" });
  const capture = await f.capture();
  assert.equal((await w.simulateCanonicalNativeSales(f.provider, capture, { blockTag: 10, gasLimit: 200000n })).authorizationId, f.batch.authorizationId);
  f.install();
  assert.equal((await f.reconcile(capture)).revokedAuthorizationId, f.batch.authorizationId);
});

test("signed mined deadline is inclusive and original domain/digest reads must agree", async () => {
  for (const deadline of [110n, 109n]) {
    const f = setup({ signed: true, deadline });
    const saved = await f.capture();
    f.install();
    if (deadline === 110n) await f.reconcile(saved);
    else await assert.rejects(f.reconcile(saved), /expired at mined/);
  }
  for (const name of ["eip712Domain", "authorizationDigest"]) {
    const f = setup({ signed: true });
    f.state.overrides.set(name, () => name === "authorizationDigest" ? [H("other-domain-digest")]
      : ["0x0f", "6529Stream Sales", "2", 1n, A(10), ZeroHash, []]);
    await assert.rejects(f.capture(), /domain|digest/i);
  }
});

test("two Merkle counters preserve phase order and beneficiary proof; selected explicit zero replaces signed PWYW minimum", async () => {
  const f = setup({ pwyw: true, signed: true, minimum: 80n, allowlist: true });
  const saved = await f.capture();
  assert.equal(saved.counters.length, 2);
  assert.equal(saved.candidate.sale.amount, 0n);
  f.install();
  assert.equal((await f.reconcile(saved)).settlement, null);
  for (const mutation of ["order", "recipient", "missing"]) {
    const bad = setup({ pwyw: true, signed: true, minimum: 80n, allowlist: true });
    if (mutation === "order") bad.state.overrides.set("phaseCounterIds", () => [[...bad.counters].reverse().map(x => x.counterId)]);
    if (mutation === "recipient") bad.state.overrides.set("counterDefinitionForManager", (_call, args) => {
      const row = bad.counters.find(x => x.config.counterConfigHash === args[1]);
      return [true, { ...row.definition, capRoot: H("initial-recipient-is-not-beneficiary") }];
    });
    if (mutation === "missing") bad.state.overrides.set("phaseCounterIds", () => [[bad.counters[0].counterId]]);
    await assert.rejects(bad.capture(), /proof|definition|counter|Merkle|allowlist/i);
  }
});

test("declared zero-fee permits payer credit and successful AT_MINT accepts provider ID zero without asserting entropy finality", async () => {
  const f = setup({ declared: true, fee: 0n, credit: 3n, revealSuccess: true });
  const saved = await f.capture();
  f.install();
  // The pre-mint quote is retained even when the callback changes later operational pricing.
  f.state.overrides.set("saleRevealQuote", call => [{ ...f.quote, policy: { ...f.quote.policy, revealFeePerTokenWei: call.blockTag >= 11 ? 999n : 0n } }]);
  const result = await f.reconcile(saved);
  assert.equal(result.revealAttempt.succeeded, true);
  assert.equal(result.revealAttempt.providerRequestId, 0n);
  assert.equal(result.purchaseReceipt.revealCredit, 3n);
  assert.equal(f.state.calls.some(row => row.name === "tokenEntropyStatus"), false);
  for (const succeeded of [false, true]) {
    const bad = setup({ declared: true, revealSuccess: succeeded });
    const capture = await bad.capture();
    bad.install();
    replaceEvent(bad, bad.iface, "ImmediateRevealAttempt", args => { args[6] = 3n; return args; });
    await assert.rejects(bad.reconcile(capture), /reveal attempt/);
  }
  const legacy = setup();
  legacy.state.overrides.set("supportsInterface", call => [call.to !== A(20)]);
  await assert.rejects(legacy.capture(), /declared|reveal|interface/i);
});

test("paid FULL/LITE floor joins new releases and immutable earlier releases using an explicit locator", async () => {
  for (const tier of ["MUSEUM_GRADE", "MUSEUM_GRADE_LITE"]) for (const retainedFloor of [false, true]) {
    const f = setup({ price: 100n, tier, retainedFloor, mode: "indexed" });
    const saved = await f.capture();
    f.install();
    if (retainedFloor) await assert.rejects(f.reconcile(saved), /locator/);
    const result = await f.reconcile(saved, retainedFloor ? { releaseKey: f.release.releaseKey } : {});
    assert.equal(result.settlement.release.receiptHash, f.release.receiptHash);
    if (retainedFloor) assert.notEqual(result.settlement.release.recorder, f.d.recorder.address);
  }
  const f = setup({ price: 100n, tier: "MUSEUM_GRADE", retainedFloor: true });
  const saved = await f.capture();
  f.install();
  await assert.rejects(f.reconcile(saved, { releaseKey: H("wrong-locator") }), /linkage/);
  f.state.overrides.set("releaseFloorReceipt", () => [{ ...f.release, receiptHash: H("changed-release-hash") }]);
  await assert.rejects(f.reconcile(saved, { releaseKey: f.release.releaseKey }), /linkage/);
});

test("paid receipt requires complete first/release/settlement inventory and exact floor-before-mint order", async () => {
  for (const name of ["ConservationFirstSaleRecorded", "ConservationReleaseFloorRecorded", "ConservationSettlementRecorded", "PrimaryRevenueSettled", "MintLedgerAuthorizationConsumed"]) {
    const f = setup({ price: 100n, tier: "MUSEUM_GRADE" });
    const saved = await f.capture();
    f.install();
    const contract = name.startsWith("Conservation") ? c.floor : name.startsWith("Primary") ? c.recorder : c.ledger;
    removeEvent(f, contract, name);
    await assert.rejects(f.reconcile(saved, { releaseKey: f.release.releaseKey }), /event|Expected one|receipt mismatch/i);
  }
  for (const names of [["ConservationFirstSaleRecorded", "ConservationReleaseFloorRecorded"], ["ConservationSettlementRecorded", "PrimaryRevenueSettled"]]) {
    const f = setup({ price: 100n, tier: "MUSEUM_GRADE" });
    const saved = await f.capture();
    f.install();
    const i = eventIndex(f, c.floor, names[0]);
    const j = eventIndex(f, names[1].startsWith("Conservation") ? c.floor : c.recorder, names[1]);
    [f.state.logs[i], f.state.logs[j]] = [f.state.logs[j], f.state.logs[i]];
    f.renumber();
    await assert.rejects(f.reconcile(saved), /order/);
  }
});

test("free receipt rejects fabricated paid evidence, incomplete mint and inconsistent status/public candidate", async () => {
  for (const mutation of ["initial", "final", "mint", "free", "paid", "candidate", "nonce", "burn"]) {
    const f = setup();
    const saved = await f.capture();
    f.install();
    if (mutation === "initial") replaceEvent(f, f.iface, "ClaimSaleExecution", args => { args[4] = f.receipt; return args; });
    if (mutation === "final") replaceEvent(f, f.iface, "ClaimSaleExecution", args => { args[3] = 1n; return args; }, 1);
    if (mutation === "mint") removeEvent(f, c.manager, "MintBatchExecuted");
    if (mutation === "free") removeEvent(f, f.iface, "FreeClaimExecuted");
    if (mutation === "paid") {
      f.event(A(13), c.recorder, "PrimaryRevenueExecutionBound", [ZeroHash, A(10), f.receipt.executionId, 1n, f.caller, ZeroAddress, H("false"), H("bound"), H("bound")]);
      f.renumber();
    }
    if (mutation === "candidate") f.state.overrides.set("activePublicNativeCandidate", () => [H("uncleared")]);
    if (mutation === "nonce") f.state.overrides.set("nextExecutionNonce", () => [1n]);
    if (mutation === "burn") f.state.overrides.set("tokenLifecycle", () => [3n]);
    await assert.rejects(f.reconcile(saved), /receipt|status|Expected|paid|candidate|nonce|identity/i);
  }
  const burned = setup();
  const capture = await burned.capture();
  burned.install();
  burned.state.overrides.set("tokenLifecycle", () => [3n]);
  burned.state.overrides.set("tokenCollectionIdentity", () => [true, 1n, 1n, true]);
  await burned.reconcile(capture);
});

test("Safe exact CALL rejects hash, failure, early success, delegatecall and value/data substitution", async () => {
  for (const mutation of ["hash", "failure", "early", "operation", "innerValue", "outerValue", "data", "caller"]) {
    const f = setup({ price: 100n, mode: "indexed" });
    const saved = await f.capture();
    f.install();
    let options = {};
    if (mutation === "hash") options = { expectedSafeTxHash: H("unrelated-safe-hash") };
    if (mutation === "failure") {
      f.state.logs.pop();
      f.event(f.caller, safe, "ExecutionFailure", [H("safe-transaction"), 0n]);
    }
    if (mutation === "early") f.state.logs.unshift(f.state.logs.pop());
    if (["operation", "innerValue", "data"].includes(mutation)) {
      const args = Array.from(safe.decodeFunctionData("execTransaction", f.state.tx.data));
      if (mutation === "operation") args[3] = 1n;
      if (mutation === "innerValue") args[1] = 0n;
      if (mutation === "data") args[2] = "0x1234";
      f.state.tx.data = safe.encodeFunctionData("execTransaction", args);
    }
    if (mutation === "outerValue") f.state.tx.value = 1n;
    if (mutation === "caller") f.state.tx.to = A(99);
    f.renumber();
    await assert.rejects(f.reconcile(saved, options), /Safe|CALL|hash|order|endpoint/i);
  }
});

test("receipt log identity/canonicality and independent Safe verification use one immutable snapshot", async () => {
  for (const mutation of ["removed", "nan", "fraction", "missing", "endpoint", "data", "duplicate"]) {
    const f = setup({ mode: "legacy" });
    const saved = await f.capture();
    f.install();
    const log = f.state.logs[0];
    if (mutation === "removed") log.removed = true;
    if (mutation === "nan") log.index = NaN;
    if (mutation === "fraction") log.index = 0.5;
    if (mutation === "missing") delete log.transactionHash;
    if (mutation === "endpoint") f.state.receipt.from = A(99);
    if (mutation === "data") log.data += "00";
    if (mutation === "duplicate") f.state.logs[1].index = 0;
    await assert.rejects(f.reconcile(saved), /identity|index|bounded|endpoint|Canonical|data|bytes/i);
  }
  const f = setup({ mode: "indexed" });
  const saved = await f.capture();
  f.install();
  f.state.mutateAfterReceipt = () => {
    f.state.logs[0].data = "0x";
    f.state.logs.at(-1).topics[1] = H("mutated-provider-object");
  };
  await f.reconcile(saved);
});

test("local historical record/receipt survives dependency loss and rejects contradictory empty/key/status outputs", async () => {
  const f = setup();
  f.install();
  f.state.codeGone = new Set([A(11), A(12), A(13), A(14), A(15), A(20)]);
  const query = { saleId: f.saleId, executionId: f.receipt.executionId };
  const result = await w.inspectCanonicalNativeSales(f.provider, f.d, query, { blockTag: 11 });
  assert.equal(result.status, 2n);
  assert.equal(result.receipt.settlementKey, ZeroHash);
  f.state.unknownExecution = true;
  assert.equal((await w.inspectCanonicalNativeSales(f.provider, f.d, query, { blockTag: 11 })).status, 0n);
  f.state.overrides.set("executionReceipt", () => [f.receipt]);
  await assert.rejects(w.inspectCanonicalNativeSales(f.provider, f.d, query, { blockTag: 11 }), /Empty receipt/);
  f.state.unknownExecution = false;
  f.state.overrides.set("executionReceipt", () => [{ ...f.receipt, saleId: H("wrong-sale") }]);
  await assert.rejects(w.inspectCanonicalNativeSales(f.provider, f.d, query, { blockTag: 11 }), /key/);
  f.state.overrides.set("executionReceipt", () => [{ ...f.receipt, settlementKey: H("fabricated-paid") }]);
  await assert.rejects(w.inspectCanonicalNativeSales(f.provider, f.d, query, { blockTag: 11 }), /Free receipt/);
});

test("capture copies reviewed inputs before awaits and detects reorgs and canonical response drift", async () => {
  const f = setup();
  const deployment = clone(f.d);
  const call = clone(f.prepared);
  f.provider.getNetwork = async () => {
    deployment.adapter.address = A(99);
    call.call.value = 999n;
    return { chainId: 1n };
  };
  const saved = await w.captureCanonicalNativeSales(f.provider, deployment, call, { blockTag: 10 });
  assert.equal(saved.deployment.adapter.address, A(10));
  assert.equal(saved.prepared.call.value, 0n);
  assert.equal(Object.isFrozen(saved.counters), true);
  const fork = setup();
  let blockReads = 0;
  fork.provider.getBlock = async tag => ({ number: tag, hash: H(++blockReads === 1 ? "a" : "b"), timestamp: 100 });
  await assert.rejects(fork.capture(), /block|reorg/i);
  const malformed = setup();
  const originalCall = malformed.provider.call;
  malformed.provider.call = async call => `${await originalCall(call)}00`;
  await assert.rejects(malformed.capture(), /Canonical|return|bytes|data/i);
});

test("all original operational calls compose through the generic Safe planner with exact native value", async () => {
  for (const family of ["immediate", "claim"]) for (const kind of ["purchaseSigned", "purchasePublic", "claimRefund", "voidMintImmediateSaleAuthorization"]) {
    const f = setup({ family, signed: kind !== "purchasePublic", price: family === "claim" ? 0n : 100n });
    if (kind === "claimRefund") f.changeRequest({ family, kind, saleId: f.saleId, recipient: A(35) });
    if (kind === "voidMintImmediateSaleAuthorization") f.changeRequest({ family, kind, authorization: f.authorization, authorizer: A(31), authorizerKind: 2n, revocationSignature: "0x" });
    const catalog = compiledABI(kind === "voidMintImmediateSaleAuthorization" ? "revocation" : family);
    const plan = createSafeCallPlan(1n, "Canonical native caller", [{ safe: f.caller, intent: kind, call: f.prepared.call, abi: catalog }]);
    assert.equal(verifySafeCallPlan(plan, [catalog]).steps[0].transaction.value, f.prepared.call.value.toString());
    const wrong = clone(plan);
    wrong.steps[0].transaction.operation = 1;
    assert.throws(() => verifySafeCallPlan(wrong, [catalog]), /CALL/);
  }
});


test("local exits reject absent credit/replay, preserve failure propagation and require exact direct receipt context", async () => {
  const refund = setup();
  refund.changeRequest({ family: "claim", kind: "claimRefund", saleId: refund.saleId, recipient: A(35) });
  await assert.rejects(refund.capture(), /credit/);
  refund.state.historicalCredit = 10n;
  refund.state.historicalLiability = 10n;
  const capture = await refund.capture();
  refund.state.callError = Error("original refund recipient rejected");
  await assert.rejects(w.simulateCanonicalNativeSales(refund.provider, capture, { blockTag: 10, gasLimit: 100000n }), /recipient rejected/);
  refund.state.callError = null;
  refund.install();
  removeEvent(refund, refund.iface, "SaleRefundClaimed");
  await assert.rejects(refund.reconcile(capture), /SaleRefundClaimed/);
  const revoked = setup({ signed: true });
  revoked.changeRequest({ family: "claim", kind: "voidMintImmediateSaleAuthorization", authorization: revoked.authorization,
    authorizer: A(31), authorizerKind: 2n, revocationSignature: "0x" });
  revoked.state.overrides.set("isManagerAuthorizationUsed", () => [true]);
  await assert.rejects(revoked.capture(), /Unconsumed/);
  for (const mutation of ["sender", "value", "data", "transport", "sameBlock", "capture"]) {
    const f = setup();
    const saved = await f.capture();
    f.install();
    let supplied = saved;
    let options = {};
    if (mutation === "sender") f.state.receipt.from = f.state.tx.from = A(99);
    if (mutation === "value") f.state.tx.value = 1n;
    if (mutation === "data") f.state.tx.data = "0x1234";
    if (mutation === "transport") options = { execution: "delegatecall" };
    if (mutation === "sameBlock") {
      f.state.tx.blockNumber = f.state.receipt.blockNumber = 10;
      f.state.tx.blockHash = f.state.receipt.blockHash = H("block-10");
      f.state.logs.forEach(log => { log.blockNumber = 10; log.blockHash = H("block-10"); });
    }
    if (mutation === "capture") { supplied = clone(saved); supplied.refundCredit = 999n; }
    await assert.rejects(f.reconcile(supplied, options), /Direct|transport|strictly later|Captured/);
  }
});
