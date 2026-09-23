import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as dutch from "../dist/current-erc20-dutch.js";
import * as native from "../dist/current-canonical-native-dutch.js";
import * as sales from "../dist/current-canonical-native-sales.js";
import { compiledInterfaces } from "./current-canonical-dutch-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const addr = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const coordinates = { chainId: (1n << 160n) + 1n, adapter: addr(1), manager: addr(2), ledger: addr(3), recorder: addr(4), paymentAdapter: addr(5) };
const actor = addr(6), payer = addr(7), asset = addr(8);
const terms = { nonce: id("nonce"), deadline: 1000n, unitPrice: 500n };
function setup(mode = 1n, samePayer = true, amount = 450n) {
  const signer = mode === 1n ? { authorizer: addr(9), kind: 2n, evidenceHash: id("evidence"), revision: 1n, installingAuthority: addr(10) }
    : { authorizer: ZeroAddress, kind: 0n, evidenceHash: ZeroHash, revision: 0n, installingAuthority: ZeroAddress };
  const config = {
    sale: { collectionId: (1n << 140n) + 1n, phaseId: id("phase"), saleKind: 3n, authorityMode: mode,
      unitPrice: 0n, startsAt: 100n, endsAt: 201n, manualClose: false, saleSupplyLimit: 9n,
      mintPolicyHash: id("bound"), expectedPrimaryPolicyHash: id("primary"), primaryPolicyMode: 0n,
      priceCounterId: ZeroHash, signer }, asset, paymentAdapter: coordinates.paymentAdapter,
    schedule: { startPrice: 1000n, restingPrice: 0n, startTime: 100n, endTime: 200n, decayKind: 0n, stepSeconds: 0n, stepAmount: 0n },
    declaredFree: true,
  };
  const saleId = dutch.erc20DutchSaleId(coordinates, config.sale.collectionId, config.sale.phaseId, 1n);
  const purchase = { saleId, payer: samePayer ? actor : payer, executor: actor, initialRecipient: addr(11), beneficiary: addr(12),
    tokenData: "0x1122", mintCommitment: id("mint"), resolverData: "0x", executionNonce: 1n };
  const authorization = mode === 1n ? dutch.erc20DutchExpectedAuthorization(coordinates, config, purchase, terms) : null;
  const execution = mode === 1n ? { purchase, authorization, signature: { authorizer: signer.authorizer, kind: 2n, signature: "0x" } }
    : dutch.erc20DutchPublicExecution(purchase);
  const configHash = dutch.erc20DutchConfigurationHash(coordinates, config);
  const request = dutch.prepareERC20DutchPaymentRequest(coordinates, id("carrier code"), configHash, 750n, execution);
  const lifecycle = { paymentAdapter: coordinates.paymentAdapter, saleCreatedAt: 90n, saleAdapterRegistryRevision: 4n, paymentAdapterRegistryRevision: 5n };
  const record = { config, configHash, priceScheduleHash: native.canonicalNativeDutchScheduleHash(dutch.erc20DutchSalesCoordinates(coordinates), saleId, config.schedule),
    saleNonce: 1n, soldQuantity: 0n, closed: false, lifecycle, artistId: id("artist"), artistGeneration: 1n, artistBindingHash: id("binding") };
  const intent = { payer: purchase.payer, asset, maxAmount: 600n, saleRef: saleId, expectedPrimaryPolicyHash: config.sale.expectedPrimaryPolicyHash,
    nonce: ZeroHash, deadline: 1000n };
  const candidate = { saleAdapter: coordinates.adapter, executor: actor,
    sale: { settlementId: saleId, revenueClass: id("PRIMARY_SALE"), policyMode: 0n, collectionId: config.sale.collectionId,
      tokenId: 0n, saleNonce: 1n, payer: purchase.payer, poster: ZeroAddress, beneficiary: purchase.beneficiary,
      amount, expectedPrimaryPolicyHash: config.sale.expectedPrimaryPolicyHash }, lifecycleBinding: lifecycle,
    executionBinding: { executionId: ZeroHash, executionNonce: 1n, authorityMode: mode,
      saleAuthorizationDigest: mode === 1n ? dutch.erc20DutchAuthorizationPayload(coordinates, authorization).digest : ZeroHash },
    asset, orchestrationOrder: 1n, mintManager: coordinates.manager, operationIdentityCommitment: id("root"), operationId: id("op"),
    currentPolicyHash: id("current differs under grace"), boundPolicyHash: config.sale.mintPolicyHash,
    rights: { profileId: id("profile"), wallet: addr(13), templateId: ZeroHash, assignmentHash: id("assignment"), entriesHash: id("entries") },
    saleExecutionHash: dutch.erc20DutchSaleExecutionHash(execution) };
  candidate.executionBinding.executionId = dutch.erc20DutchExecutionId(coordinates.chainId, candidate);
  return { config, purchase, authorization, execution, request, record, intent, candidate };
}
function routes(e, maximum = 700n, deadline = 1000n) {
  return [
    { kind: "settleERC20DutchSaleByPayer", request: e.request, value: 20n },
    { kind: "settleERC20DutchSaleWithIntent", request: e.request, intent: e.intent, signature: "0x", value: 20n },
    { kind: "settleERC20DutchSaleWithEIP2612Permit", request: e.request,
      permit: { permittedAmount: maximum, authorization: { deadline, v: 27n, r: id("r"), s: id("s") } }, value: 20n },
    { kind: "settleERC20DutchSaleWithPermit2", request: e.request,
      permit: { permittedAmount: maximum, authorization: { deadline, nonce: 0n, signature: "0x1234" } }, value: 20n },
  ];
}

test("ERC20 Dutch exact original Sales24 and independent PaymentIntent domains", () => {
  const e = setup(1n, false);
  const seller = dutch.erc20DutchAuthorizationPayload(coordinates, e.authorization);
  const payment = dutch.erc20DutchPaymentIntentPayload(coordinates, e.intent);
  assert.equal(seller.domain.name, "6529Stream Sales");
  assert.equal(seller.domain.verifyingContract, coordinates.adapter);
  assert.equal(payment.domain.name, "6529StreamPaymentIntentVerifier");
  assert.equal(payment.domain.verifyingContract, coordinates.paymentAdapter);
  assert.equal(payment.message.nonce, ZeroHash);
  assert.equal(seller.message.asset, asset);
  assert.notEqual(seller.message.payer, seller.message.executor);
  assert.equal(seller.types.SaleAuthorization.length, 24);
  assert.notEqual(seller.message.initialRecipientsHash, seller.message.beneficiariesHash);
});

test("configuration price remains zero and timed end must be strictly after schedule end", () => {
  const e = setup();
  assert.deepEqual(dutch.validateERC20DutchConfiguration(e.config), e.config);
  for (const patch of [{ unitPrice: 1000n }, { endsAt: 200n }, { saleKind: 0n }]) {
    assert.throws(() => dutch.validateERC20DutchConfiguration({ ...e.config, sale: { ...e.config.sale, ...patch } }));
  }
  const manual = { ...e.config, sale: { ...e.config.sale, manualClose: true, endsAt: 0n } };
  assert.deepEqual(dutch.validateERC20DutchConfiguration(manual), manual);
  assert.equal(dutch.erc20DutchPrice(e.config, 100n, 1n, { hasOverride: true, overridePrice: 600n }).amount, 600n);
  assert.throws(() => dutch.erc20DutchPrice(e.config, 100n, 1n, { hasOverride: false, overridePrice: 0n }), /maximum/);
  assert.equal(dutch.erc20DutchPrice(e.config, 200n, 0n, { hasOverride: false, overridePrice: 0n }).amount, 0n);
});

test("all four actual Payment routes preserve exact compiled calldata and native value", () => {
  const e = setup();
  for (const request of routes(e)) {
    const plan = dutch.prepareERC20DutchCall(coordinates, actor, request);
    const args = [request.request];
    if (request.kind.endsWith("WithIntent")) args.push(request.intent, request.signature);
    if (request.permit) args.push(request.permit);
    assert.equal(plan.call.data, compiledInterfaces.payment.encodeFunctionData(request.kind, args));
    assert.equal(plan.call.to, coordinates.paymentAdapter);
    assert.equal(plan.call.value, 20n);
    assert.deepEqual(dutch.normalizeERC20DutchCall(plan), plan);
    assert.equal(dutch.validateERC20DutchFunding(plan, e.candidate, 1000n).amount, 450n);
    const batch = dutch.erc20DutchMintBatch(plan, e.record);
    assert.equal(batch.authorizer, ZeroAddress);
    assert.deepEqual(batch.initialRecipients, [e.purchase.initialRecipient]);
    assert.equal(batch.expectedPolicyHash, e.record.config.sale.mintPolicyHash);
  }
});

test("public has literal empty authority and always binds payer caller, signed relay needs Intent", () => {
  const e = setup(2n);
  for (const request of routes(e)) {
    const plan = dutch.prepareERC20DutchCall(coordinates, actor, request);
    assert.equal(plan.execution.authorization.nonce, ZeroHash);
    assert.equal(dutch.validateERC20DutchFunding(plan, e.candidate, 1000n).amount, 450n);
    assert.throws(() => dutch.prepareERC20DutchCall(coordinates, payer, request), /caller/);
  }
  assert.throws(() => dutch.prepareERC20DutchPaymentRequest(coordinates, id("code"), e.record.configHash, 1n,
    { ...e.execution, signature: { ...e.execution.signature, signature: "0x00" } }), /literal empty/);
  const relay = setup(1n, false);
  for (const request of routes(relay)) {
    if (request.kind === "settleERC20DutchSaleWithIntent") {
      const p = dutch.prepareERC20DutchCall(coordinates, actor, request);
      assert.equal(dutch.validateERC20DutchFunding(p, relay.candidate, 1000n).consumesPaymentIntent, true);
    } else assert.throws(() => dutch.prepareERC20DutchCall(coordinates, actor, request), /caller/);
  }
});

test("free permits skip maxima/deadlines while free Intent remains validated without nonce consumption", () => {
  const e = setup(2n, true, 0n);
  for (const request of routes(e, 0n, 0n)) {
    const p = dutch.prepareERC20DutchCall(coordinates, actor, request);
    assert.deepEqual(dutch.validateERC20DutchFunding(p, e.candidate, 1000n), {
      amount: 0n, requestMaximum: 750n, consumesPaymentIntent: false, usesPermit: false,
    });
  }
  const intent = routes(e)[1];
  assert.throws(() => dutch.validateERC20DutchFunding(dutch.prepareERC20DutchCall(coordinates, actor,
    { ...intent, intent: { ...intent.intent, deadline: 999n } }), e.candidate, 1000n), /deadline/);
  const p = dutch.prepareERC20DutchCall(coordinates, actor, intent);
  assert.equal(p.request.signature, "0x"); // Arbitrary ERC1271 proof bytes remain original-simulation authority.
});

test("token request maximum, Intent maximum, permit ceiling and inclusive deadline remain independent", () => {
  const e = setup();
  const ordinary = routes(e)[0];
  assert.throws(() => dutch.validateERC20DutchFunding(dutch.prepareERC20DutchCall(coordinates, actor,
    { ...ordinary, request: { ...ordinary.request, maxAmount: 449n } }), e.candidate, 1000n), /request/);
  const intent = routes(e)[1];
  assert.throws(() => dutch.validateERC20DutchFunding(dutch.prepareERC20DutchCall(coordinates, actor,
    { ...intent, intent: { ...e.intent, maxAmount: 449n } }), e.candidate, 1000n), /intent/);
  for (const request of routes(e, 449n).slice(2)) {
    assert.throws(() => dutch.validateERC20DutchFunding(dutch.prepareERC20DutchCall(coordinates, actor, request), e.candidate, 1000n), /Permit/);
  }
  for (const request of routes(e, 450n, 999n).slice(2)) {
    assert.throws(() => dutch.validateERC20DutchFunding(dutch.prepareERC20DutchCall(coordinates, actor, request), e.candidate, 1000n), /deadline/);
  }
});

test("maximum Permit2 uses maximum permission but actual requested charge and literal upstream nonce", () => {
  const e = setup();
  const permit = routes(e, 1000n)[3].permit;
  const transfer = dutch.erc20DutchPermit2Transfer(e.candidate, permit);
  assert.deepEqual(transfer.permit.permitted, { token: asset, amount: 1000n });
  assert.deepEqual(transfer.transferDetails, { to: coordinates.paymentAdapter, requestedAmount: 450n });
  assert.equal(transfer.permit.nonce, 0n);
  assert.equal(transfer.owner, actor);
  dutch.erc20DutchEIP2612Remaining(1000n, 450n, 550n);
  assert.throws(() => dutch.erc20DutchEIP2612Remaining(1000n, 450n, 1000n), /remaining/);
  const maximum = (1n << 256n) - 1n;
  dutch.erc20DutchEIP2612Remaining(maximum, 450n, maximum);
  dutch.erc20DutchEIP2612Remaining(maximum, 450n, maximum - 450n);
});

test("canonical complete Execution hash and full lifecycle accounting stay separate from native identity", () => {
  const e = setup();
  const raw = dutch.encodeERC20DutchExecution(e.execution);
  assert.equal(raw, coder.encode([dutch.ERC20_DUTCH_EXECUTION_TUPLE], [e.execution]));
  assert.equal(dutch.erc20DutchSaleExecutionHash(e.execution), keccak256(raw));
  assert.equal(dutch.erc20DutchAccountingContextHash(e.candidate), keccak256(dutch.encodeERC20DutchCandidate(e.candidate)));
  assert.equal(dutch.erc20DutchAccountingContext(e.candidate).lifecycleBinding.saleCreatedAt, 90n);
  assert.notEqual(dutch.erc20DutchCandidateCommitment(coordinates.chainId, coordinates.paymentAdapter, coordinates.recorder, e.candidate),
    dutch.erc20DutchCandidateCommitment(coordinates.chainId, coordinates.paymentAdapter, coordinates.recorder,
      { ...e.candidate, lifecycleBinding: { ...e.candidate.lifecycleBinding, paymentAdapterRegistryRevision: 6n } }));
  assert.throws(() => dutch.decodeERC20DutchExecution(`${raw}${"00".repeat(32)}`), /Noncanonical/);
});

test("free result is literal zero and structural empty candidate/record codecs make no admission claim", () => {
  const e = setup(2n, true, 0n);
  const settlement = sales.decodeCanonicalNativeSalesResult(`0x${"00".repeat(384)}`);
  const result = { revenueOutcome: 1n, executionId: e.candidate.executionBinding.executionId, settlement };
  assert.deepEqual(dutch.validateERC20DutchResult(result, e.candidate), result);
  assert.throws(() => dutch.validateERC20DutchResult({ ...result, settlement: { ...settlement, asset } }, e.candidate), /literal zero/);
  assert.throws(() => dutch.validateERC20DutchResult({ ...result, revenueOutcome: 2n }, e.candidate), /literal zero/);
  const candidate = dutch.decodeERC20DutchCandidate(`0x${"00".repeat(1088)}`);
  assert.equal(candidate.sale.amount, 0n);
  assert.equal(dutch.encodeERC20DutchCandidate(candidate), `0x${"00".repeat(1088)}`);
  assert.deepEqual(dutch.decodeERC20DutchRecord(dutch.encodeERC20DutchRecord(e.record)), e.record);
});

test("paid result retains every candidate-derived join while commitment/key remain coordinate-dependent", () => {
  const e = setup();
  const result = { revenueOutcome: 2n, executionId: e.candidate.executionBinding.executionId,
    settlement: { candidateCommitment: dutch.erc20DutchCandidateCommitment(coordinates.chainId, coordinates.paymentAdapter, coordinates.recorder, e.candidate),
      settlementKey: dutch.erc20DutchSettlementKey(coordinates.chainId, coordinates.recorder, coordinates.adapter, e.candidate.executionBinding.executionId),
      profileId: e.candidate.rights.profileId, wallet: e.candidate.rights.wallet, asset, amount: e.candidate.sale.amount,
      executor: actor, executionId: e.candidate.executionBinding.executionId, escrowed: false,
      operationIdentityCommitment: e.candidate.operationIdentityCommitment,
      currentPolicyHash: e.candidate.currentPolicyHash, boundPolicyHash: e.candidate.boundPolicyHash } };
  assert.deepEqual(dutch.validateERC20DutchResult(result, e.candidate), result);
  for (const key of ["profileId", "operationIdentityCommitment", "currentPolicyHash", "boundPolicyHash"]) {
    assert.throws(() => dutch.validateERC20DutchResult({ ...result, settlement: { ...result.settlement, [key]: id(`other ${key}`) } }, e.candidate), /differs/);
  }
  assert.throws(() => dutch.validateERC20DutchResult({ ...result, settlement: { ...result.settlement, wallet: addr(99) } }, e.candidate), /differs/);
});

test("local refund and historical Manager revoke do not invoke Payment or paid admission", () => {
  const e = setup();
  const refund = dutch.prepareERC20DutchCall(coordinates, actor, { kind: "claimRefund", saleId: e.purchase.saleId, recipient: addr(20) });
  assert.equal(refund.call.to, coordinates.adapter);
  assert.equal(refund.execution, null);
  assert.equal(refund.call.value, 0n);
  const authorization = { ...e.authorization, nonce: ZeroHash, deadline: 0n, asset: ZeroAddress, unitPrice: 0n, finalizeBy: 55n };
  const request = { kind: "voidMintImmediateSaleAuthorization", authorization, authorizer: e.config.sale.signer.authorizer,
    authorizerKind: 2n, revocationSignature: "0x" };
  const p = dutch.prepareERC20DutchCall(coordinates, actor, request);
  assert.equal(p.call.to, coordinates.manager);
  assert.equal(p.call.data, compiledInterfaces.manager.encodeFunctionData(request.kind, [authorization, request.authorizer, 2n, "0x"]));
  assert.equal(dutch.erc20DutchRevocationPayload(coordinates, authorization).domain.verifyingContract, coordinates.adapter);
  for (const kind of ["saleRecord", "nativeSaleLifecycleBinding", "publicNativeSaleBinding"]) {
    assert.throws(() => dutch.prepareERC20DutchRead(coordinates.adapter, { kind, saleId: ZeroHash }), /Unsupported/);
  }
  assert.throws(() => dutch.prepareERC20DutchRead(coordinates.adapter, { kind: "activePublicNativeCandidate", executionId: ZeroHash }), /Unsupported/);
  for (const kind of ["saleConsentFacts", "saleRevealQuote", "immediateSaleAuthorizationBinding"]) {
    const call = dutch.prepareERC20DutchRead(coordinates.adapter, { kind, saleId: ZeroHash });
    assert.equal(call.data, compiledInterfaces.erc20Dutch.encodeFunctionData(kind, [ZeroHash]));
  }
});

test("immutable full reconstruction excludes callback/admin escapes and bounds complete transport", () => {
  const e = setup();
  const request = structuredClone(routes(e)[3]);
  const p = dutch.prepareERC20DutchCall({ ...coordinates }, actor, request);
  request.permit.authorization.signature = "0xffff";
  request.request.maxAmount = 1n;
  assert.equal(p.request.permit.authorization.signature, "0x1234");
  assert.equal(p.request.request.maxAmount, 750n);
  assert(Object.isFrozen(p.execution.purchase));
  assert.throws(() => dutch.normalizeERC20DutchCall({ ...p, call: { ...p.call, to: coordinates.adapter } }), /differs/);
  assert.throws(() => dutch.normalizeERC20DutchCall({ ...p, execution: null }), /differs/);
  assert.throws(() => dutch.prepareERC20DutchCall(coordinates, actor, { kind: "executeERC20DutchFreeMint", candidate: e.candidate }), /Unsupported/);
  assert.throws(() => dutch.prepareERC20DutchCall(coordinates, actor, { ...routes(e)[0], request: { ...e.request, extra: true } }), /unknown/);
  assert.throws(() => dutch.prepareERC20DutchPaymentRequest(coordinates, id("code"), e.record.configHash, 1n, {
    ...e.execution, purchase: { ...e.purchase, resolverData: `0x${"01".repeat(dutch.ERC20_DUTCH_MAX_BYTES)}` },
  }), /byte limit/);
});
