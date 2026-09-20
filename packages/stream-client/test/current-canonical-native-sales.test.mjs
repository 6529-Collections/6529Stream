import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as sales from "../dist/current-canonical-native-sales.js";
import { compiledInterfaces } from "./current-canonical-native-sales-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const addr = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const coords = { chainId: (1n << 200n) + 97n, adapter: addr(101), manager: addr(102), ledger: addr(103), recorder: addr(104) };
const caller = addr(105);
const beneficiary = addr(106);
const recipient = addr(107);
const signer = addr(108);
const emptySigner = { authorizer: ZeroAddress, kind: 0n, evidenceHash: ZeroHash, revision: 0n, installingAuthority: ZeroAddress };

function example(family = "immediate", kind = 0n, mode = 1n) {
  const config = {
    collectionId: (1n << 100n) + 5n,
    phaseId: id("phase"),
    saleKind: kind,
    authorityMode: mode,
    unitPrice: family === "immediate" ? 71n : 0n,
    startsAt: 2n,
    endsAt: 50n,
    manualClose: false,
    saleSupplyLimit: kind === 1n ? 0n : 9n,
    mintPolicyHash: id("bound policy"),
    expectedPrimaryPolicyHash: kind === 12n ? ZeroHash : id("primary policy"),
    primaryPolicyMode: 0n,
    priceCounterId: ZeroHash,
    signer: mode === 1n
      ? { authorizer: signer, kind: 2n, evidenceHash: id("signer evidence"), revision: 3n, installingAuthority: addr(109) }
      : { ...emptySigner },
  };
  const configuration = family === "immediate" ? config : { sale: config, maxUnitPrice: kind === 12n ? 0n : 500n };
  const saleNonce = (1n << 128n) + 2n;
  const saleId = sales.canonicalNativeSalesSaleId(coords, family, config.collectionId, config.phaseId, saleNonce);
  const mint = { saleId, payer: caller, executor: caller, initialRecipient: recipient, beneficiary,
    tokenData: "0x1234", mintCommitment: id("mint"), resolverData: "0x", executionNonce: (1n << 100n) + 1n };
  const purchase = family === "immediate" ? mint : { mint, chosenUnitPrice: kind === 12n ? 0n : 91n };
  const authorization = mode === 1n ? sales.canonicalNativeSalesExpectedAuthorization(coords, family, configuration, purchase,
    { nonce: id("nonce"), deadline: 100n, unitPrice: config.unitPrice }) : null;
  const signature = { authorizer: signer, kind: 2n, signature: "0x" };
  const recordBase = { config, configHash: sales.canonicalNativeSalesConfigurationHash(coords, family, configuration), saleNonce,
    soldQuantity: 1n, closed: false, lifecycle: { saleCreatedAt: 2n, saleAdapterRegistryRevision: 3n },
    artistId: id("artist"), artistGeneration: 1n, artistBindingHash: id("artist binding") };
  const record = family === "immediate" ? recordBase : { sale: recordBase, maxUnitPrice: configuration.maxUnitPrice };
  const request = mode === 1n
    ? { family, kind: "purchaseSigned", purchase, authorization, signature, value: 123n }
    : { family, kind: "purchasePublic", purchase, value: 123n };
  return { family, config, configuration, mint, purchase, authorization, signature, record, request };
}

function zero(param) {
  if (param.baseType === "tuple") return Object.fromEntries(param.components.map(p => [p.name, zero(p)]));
  if (param.baseType === "array") return [];
  if (param.type === "address") return ZeroAddress;
  if (param.type === "bytes32") return ZeroHash;
  if (param.type === "bytes") return "0x";
  if (param.type === "bool") return false;
  return 0n;
}

test("structural getter codecs preserve canonical empty records, receipts and full uint widths", () => {
  for (const [name, tuple] of [
    ["Record", sales.CANONICAL_NATIVE_SALES_RECORD_TUPLE],
    ["ClaimRecord", sales.CANONICAL_NATIVE_CLAIM_RECORD_TUPLE],
    ["Receipt", sales.CANONICAL_NATIVE_SALES_RECEIPT_TUPLE],
    ["Candidate", sales.CANONICAL_NATIVE_SALES_CANDIDATE_TUPLE],
    ["Result", sales.CANONICAL_NATIVE_SALES_RESULT_TUPLE],
    ["RevealQuote", sales.CANONICAL_NATIVE_SALES_REVEAL_QUOTE_TUPLE],
  ]) {
    const value = zero(ParamType.from(tuple));
    const encoded = sales[`encodeCanonicalNativeSales${name}`](value);
    assert.equal(encoded, coder.encode([tuple], [value]));
    assert.deepEqual(sales[`decodeCanonicalNativeSales${name}`](encoded), value);
    assert.throws(() => sales[`decodeCanonicalNativeSales${name}`](`${encoded}${"00".repeat(32)}`), /Noncanonical/);
    assert(Object.isFrozen(sales[`normalizeCanonicalNativeSales${name}`](value)));
  }
  const e = example();
  assert.deepEqual(sales.decodeCanonicalNativeSalesRecord(sales.encodeCanonicalNativeSalesRecord(e.record)), e.record);
  assert.throws(() => sales.normalizeCanonicalNativeSalesRecord({ ...e.record, saleNonce: Number.MAX_SAFE_INTEGER }), /bigint/);
  assert.throws(() => sales.normalizeCanonicalNativeSalesRecord({ ...e.record, extra: true }), /unknown/);
  assert.throws(() => sales.normalizeCanonicalNativeSalesRecord({ ...e.record, soldQuantity: 1n << 64n }), /uint64/);
});

test("both authority modes and all four kinds keep exact compiler-owned purchase shapes and value", () => {
  for (const [family, kind] of [["immediate", 0n], ["immediate", 1n], ["claim", 12n], ["claim", 13n]]) {
    for (const mode of [1n, 2n]) {
      const e = example(family, kind, mode);
      const plan = sales.prepareCanonicalNativeSalesCall(coords, caller, e.request);
      const abi = compiledInterfaces[family];
      const args = mode === 1n ? [e.purchase, e.authorization, e.signature] : [e.purchase];
      assert.equal(plan.call.data, abi.encodeFunctionData(e.request.kind, args));
      assert.equal(plan.call.to, coords.adapter);
      assert.equal(plan.call.value, 123n);
      assert.equal(plan.caller, caller);
      assert.equal(plan.factsVerified, false);
      assert.deepEqual(sales.normalizeCanonicalNativeSalesCall(plan), plan);
      const batch = sales.canonicalNativeSalesMintBatch(plan, e.record);
      assert.deepEqual(batch.initialRecipients, [recipient]);
      assert.deepEqual(batch.beneficiaries, [beneficiary]);
      assert.equal(batch.authorizer, ZeroAddress);
      assert.notEqual(batch.contextHash, ZeroHash);
      assert.equal(batch.resolverData, e.mint.resolverData);
      assert.equal(sales.prepareCanonicalNativeSalesPreview(plan).value, 0n);
    }
  }
});

test("purchase constraints distinguish actual payer executor and original signer from recipient", () => {
  const e = example();
  assert.throws(() => sales.prepareCanonicalNativeSalesCall(coords, addr(999), e.request), /actor/);
  for (const patch of [{ payer: coords.adapter, executor: coords.adapter }, { executor: recipient },
    { initialRecipient: coords.adapter }, { beneficiary: ZeroAddress }, { executionNonce: 0n }, { mintCommitment: ZeroHash }]) {
    assert.throws(() => sales.prepareCanonicalNativeSalesCall(coords, caller, { ...e.request, purchase: { ...e.purchase, ...patch } }));
  }
  for (const patch of [{ nonce: ZeroHash }, { finalizeBy: 1n }, { quantity: 2n }, { asset: addr(500) },
    { contentSelectionHash: id("content") }, { saleKind: 6n }, { initialRecipientsHash: e.authorization.beneficiariesHash }]) {
    assert.throws(() => sales.prepareCanonicalNativeSalesCall(coords, caller, { ...e.request, authorization: { ...e.authorization, ...patch } }));
  }
  assert.throws(() => sales.prepareCanonicalNativeSalesCall(coords, caller, { ...e.request,
    signature: { ...e.signature, kind: 0n } }), /explicit/);
  assert.throws(() => sales.prepareCanonicalNativeSalesCall(coords, caller, { ...e.request,
    purchase: { ...e.purchase, tokenData: `0x${"ab".repeat(8193)}` } }), /byte limit/);
  sales.validateCanonicalNativeSalesAuthorizationDeadline(e.authorization, 100n);
  assert.throws(() => sales.validateCanonicalNativeSalesAuthorizationDeadline(e.authorization, 101n), /Expired/);
});

test("retained configuration binds signer revision, family and request without equating current policy", () => {
  const e = example();
  const plan = sales.prepareCanonicalNativeSalesCall(coords, caller, e.request);
  const batch = sales.canonicalNativeSalesMintBatch(plan, e.record);
  assert.equal(batch.expectedPolicyHash, e.config.mintPolicyHash);
  assert.throws(() => sales.canonicalNativeSalesMintBatch(plan, { ...e.record, configHash: id("wrong") }), /identity/);
  assert.throws(() => sales.canonicalNativeSalesMintBatch(plan, { ...e.record, saleNonce: e.record.saleNonce + 1n }), /identity/);
  const mismatched = sales.prepareCanonicalNativeSalesCall(coords, caller, { ...e.request, signature: { ...e.signature, authorizer: addr(600) } });
  assert.throws(() => sales.canonicalNativeSalesMintBatch(mismatched, e.record), /retained configuration/);
  assert.notEqual(sales.canonicalNativeSalesPublicAuthorizationId(coords, "immediate", e.record.configHash, batch.contextHash),
    sales.canonicalNativeSalesPublicAuthorizationId(coords, "claim", e.record.configHash, batch.contextHash));
});

test("configured admission distinguishes finite/open supply, signed/public bindings and free/PWYW policy", () => {
  const e = example();
  for (const patch of [
    { collectionId: 0n }, { phaseId: ZeroHash }, { unitPrice: 0n }, { saleSupplyLimit: 0n },
    { expectedPrimaryPolicyHash: ZeroHash }, { primaryPolicyMode: 1n },
    { manualClose: true }, { endsAt: 2n }, { signer: { ...e.config.signer, revision: 0n } },
  ]) assert.throws(() => sales.validateCanonicalNativeSalesConfiguration("immediate", { ...e.config, ...patch }));
  const manual = { ...e.config, manualClose: true, endsAt: 0n };
  assert.deepEqual(sales.validateCanonicalNativeSalesConfiguration("immediate", manual), manual);
  const open = example("immediate", 1n, 2n);
  assert.throws(() => sales.validateCanonicalNativeSalesConfiguration("immediate", { ...open.config, saleSupplyLimit: 1n }));
  assert.throws(() => sales.validateCanonicalNativeSalesConfiguration("immediate", { ...open.config, signer: e.config.signer }), /empty/);
  const free = example("claim", 12n);
  for (const c of [
    { ...free.configuration, maxUnitPrice: 1n },
    { ...free.configuration, sale: { ...free.config, expectedPrimaryPolicyHash: id("policy") } },
    { ...free.configuration, sale: { ...free.config, saleSupplyLimit: 0n } },
  ]) assert.throws(() => sales.validateCanonicalNativeSalesConfiguration("claim", c));
  const claim = example("claim", 13n);
  assert.throws(() => sales.validateCanonicalNativeSalesConfiguration("claim", { ...claim.configuration, maxUnitPrice: 0n }));
  assert.throws(() => sales.validateCanonicalNativeSalesConfiguration("claim", {
    ...claim.configuration, sale: { ...claim.config, unitPrice: 501n },
  }));
  // Raw config hashing/getter transport remain structural, including unknown/empty records.
  const zeroConfig = zero(ParamType.from(sales.CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE));
  const read = sales.prepareCanonicalNativeSalesRead(coords.adapter, "immediate", {
    kind: "saleConfigurationHash", configuration: zeroConfig,
  });
  assert.equal(read.data, compiledInterfaces.immediate.encodeFunctionData("saleConfigurationHash", [zeroConfig]));
  assert.notEqual(sales.canonicalNativeSalesConfigurationHash(coords, "immediate", zeroConfig), ZeroHash);
});

test("source price rules preserve authenticated zero override and keep chosen price outside signature", () => {
  const e = example("claim", 13n);
  const a = sales.canonicalNativeSalesExpectedAuthorization(coords, "claim", e.configuration, e.purchase,
    { nonce: id("nonce"), deadline: 100n, unitPrice: 1000n });
  const changed = { ...e.purchase, chosenUnitPrice: 7n };
  const b = sales.canonicalNativeSalesExpectedAuthorization(coords, "claim", e.configuration, changed,
    { nonce: id("nonce"), deadline: 100n, unitPrice: 1000n });
  assert.equal(sales.canonicalNativeSalesAuthorizationPayload(coords, a).digest, sales.canonicalNativeSalesAuthorizationPayload(coords, b).digest);
  assert.notEqual(sales.canonicalNativeSalesRequestHash(coords, "claim", e.record.sale.configHash, e.purchase),
    sales.canonicalNativeSalesRequestHash(coords, "claim", e.record.sale.configHash, changed));
  assert.deepEqual(sales.canonicalNativeSalesPrice("claim", e.configuration, changed, 1000n,
    { hasOverride: true, overridePrice: 0n }), { amount: 7n, minimum: 0n, maximum: 500n });
  assert.throws(() => sales.canonicalNativeSalesPrice("claim", e.configuration, changed, 1000n,
    { hasOverride: false, overridePrice: 0n }), /bounds/);
  assert.throws(() => sales.canonicalNativeSalesPrice("claim", { sale: { ...e.config, unitPrice: 8n }, maxUnitPrice: 500n }, changed, 1000n,
    { hasOverride: true, overridePrice: 0n }), /bounds/);
  const free = example("claim", 12n);
  assert.equal(sales.canonicalNativeSalesPrice("claim", free.configuration, free.purchase, 0n,
    { hasOverride: true, overridePrice: 0n }).amount, 0n);
  assert.throws(() => sales.canonicalNativeSalesPrice("claim", free.configuration, free.purchase, 1n,
    { hasOverride: true, overridePrice: 0n }), /Zero-price/);
  const immediate = example();
  assert.throws(() => sales.canonicalNativeSalesPrice("immediate", immediate.config, immediate.purchase, 71n,
    { hasOverride: true, overridePrice: 0n }), /positive/);
});

function allowlistExample() {
  const e = example("claim", 13n);
  const ids = [id("payer counter"), id("recipient price counter")];
  const proofs = [
    { maxCount: 2n, hasPriceOverride: false, priceOverride: 0n, proof: [] },
    { maxCount: 3n, hasPriceOverride: true, priceOverride: 0n, proof: [] },
  ];
  const rows = ids.map((counterId, i) => {
    const account = i === 0 ? caller : beneficiary;
    const p = proofs[i];
    const leaf = keccak256(keccak256(coder.encode(
      ["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256"],
      [id("6529STREAM_MINT_ALLOWLIST_LEAF_V1"), coords.chainId, coords.manager, e.config.collectionId,
        e.config.phaseId, counterId, account, p.maxCount, p.hasPriceOverride, p.priceOverride])));
    const definition = { scope: 1n, keyMode: i === 0 ? 2n : 3n, capRoot: leaf, metadataHash: id(`definition${i}`) };
    const definitionHash = keccak256(coder.encode(["bytes32", "tuple(uint8 scope,uint8 keyMode,bytes32 capRoot,bytes32 metadataHash)"],
      [id("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition]));
    return { counterId, definitionExists: true, definition, config: { enabled: true, keyMode: definition.keyMode,
      capMode: 3n, deltaMode: 0n, staticCap: 5n, staticIncrement: 1n, counterConfigHash: definitionHash } };
  });
  return { ...e, rows, proofs, config: { ...e.config, priceCounterId: ids[1] },
    mint: { ...e.mint, resolverData: sales.encodeCanonicalNativeSalesAllowlistProofs(proofs.map(p => [p])) } };
}

test("same-leaf price proof verifies every Merkle counter in original order and RECIPIENT means beneficiary", () => {
  const e = allowlistExample();
  assert.deepEqual(sales.canonicalNativeSalesAllowlistPrice(coords, e.config, e.mint, e.rows),
    { hasOverride: true, overridePrice: 0n });
  assert.throws(() => sales.canonicalNativeSalesAllowlistPrice(coords, e.config,
    { ...e.mint, beneficiary: recipient }, e.rows), /proof/);
  assert.throws(() => sales.canonicalNativeSalesAllowlistPrice(coords, e.config,
    { ...e.mint, resolverData: sales.encodeCanonicalNativeSalesAllowlistProofs([...e.proofs].reverse().map(p => [p])) }, e.rows), /proof/);
  assert.throws(() => sales.canonicalNativeSalesAllowlistPrice(coords, e.config, e.mint, [...e.rows].reverse()), /proof/);
  assert.throws(() => sales.canonicalNativeSalesAllowlistPrice(coords, e.config, e.mint,
    [e.rows[0], { ...e.rows[1], definitionExists: false }]), /policy/);
  assert.throws(() => sales.canonicalNativeSalesAllowlistPrice(coords, e.config, e.mint,
    [e.rows[0], { ...e.rows[1], config: { ...e.rows[1].config, staticCap: 2n } }]), /proof/);
  assert.throws(() => sales.canonicalNativeSalesAllowlistPrice(coords, { ...e.config, priceCounterId: e.rows[0].counterId }, e.mint, e.rows), /selected/);
  assert.throws(() => sales.canonicalNativeSalesAllowlistPrice(coords, { ...e.config, priceCounterId: ZeroHash }, e.mint, e.rows), /Unselected/);
});

test("proof codec is canonical nested singleton rows with explicit client allocation bounds", () => {
  const e = allowlistExample();
  const encoded = e.mint.resolverData;
  assert.deepEqual(sales.decodeCanonicalNativeSalesAllowlistProofs(encoded), e.proofs.map(p => [p]));
  assert.throws(() => sales.decodeCanonicalNativeSalesAllowlistProofs(`${encoded}${"00".repeat(32)}`), /Noncanonical/);
  assert.throws(() => sales.encodeCanonicalNativeSalesAllowlistProofs([[]]), /one proof/);
  assert.throws(() => sales.encodeCanonicalNativeSalesAllowlistProofs([[e.proofs[0], e.proofs[1]]]), /bounded/);
  assert.throws(() => sales.encodeCanonicalNativeSalesAllowlistProofs(Array(1)), /dense/);
  assert.throws(() => sales.encodeCanonicalNativeSalesAllowlistProofs(Array(17).fill([e.proofs[0]])), /bounded/);
  assert.throws(() => sales.encodeCanonicalNativeSalesAllowlistProofs([[{ ...e.proofs[0], proof: Array(65).fill(id("sibling")) }]]), /bounded/);
  const one = coder.encode([sales.CANONICAL_NATIVE_SALES_ALLOWLIST_PROOF_TUPLE], [e.proofs[0]]);
  assert.throws(() => sales.decodeCanonicalNativeSalesAllowlistProofs(one));
});

test("historical revocation preserves expired and non-purchase payloads and original actual signer bypass", () => {
  const e = example();
  const authorization = { ...e.authorization, deadline: 0n, nonce: ZeroHash, unitPrice: 0n,
    quantity: 0n, contentSelectionHash: id("historical otherwise invalid"), asset: addr(600), finalizeBy: 99n };
  const request = { family: "immediate", kind: "voidMintImmediateSaleAuthorization", authorization,
    authorizer: signer, authorizerKind: 2n, revocationSignature: "0xabcd" };
  const plan = sales.prepareCanonicalNativeSalesCall(coords, signer, request);
  assert.equal(plan.call.to, coords.manager);
  assert.equal(plan.call.value, 0n);
  assert.equal(plan.call.data, compiledInterfaces.revocation.encodeFunctionData(request.kind,
    [authorization, signer, 2n, "0xabcd"]));
  assert.equal(plan.request.authorization.nonce, ZeroHash);
  const binding = { collectionId: authorization.collectionId, phaseId: authorization.phaseId, saleKind: authorization.saleKind,
    authorityMode: 1n, configHash: id("historical immutable config"), authorizer: signer, authorizerKind: 2n };
  assert.deepEqual(sales.validateCanonicalNativeSalesHistoricalBinding(plan, binding), binding);
  assert.throws(() => sales.validateCanonicalNativeSalesHistoricalBinding(plan, { ...binding, authorityMode: 2n }), /mismatch/);
  assert.throws(() => sales.validateCanonicalNativeSalesHistoricalBinding(plan, { ...binding, authorizer: caller }), /mismatch/);
  assert.throws(() => sales.prepareCanonicalNativeSalesCall(coords, signer, { ...request, authorization: { ...authorization, saleKind: 3n } }), /family/);
  const relay = sales.prepareCanonicalNativeSalesCall(coords, caller, { ...request, revocationSignature: "0x" });
  assert.equal(relay.caller, caller); // ERC1271 acceptance remains the original Manager simulation's decision.
  const payload = sales.canonicalNativeSalesRevocationPayload(coords, authorization);
  assert.equal(payload.domain.verifyingContract, coords.adapter);
  assert.equal(payload.domain.name, "6529Stream Sales");
  assert.equal(payload.primaryType, "MintTicketRevocation");
  assert.equal(payload.message.manager, coords.manager);
  assert.equal(payload.message.ledger, coords.ledger);
});

test("declared reveal excess is a payer pull credit; undeclared policy requires exact value even when free", () => {
  const quote = { coordinator: addr(500), coordinatorCodeHash: id("entropy"), policy: {
    declared: true, requestMode: 1n, revealOwnerRole: ZeroHash, requestSLOBlocks: 0n, revealFeePerTokenWei: 7n } };
  assert.deepEqual(sales.canonicalNativeSalesRevealFunding(0n, 20n, quote), { chargedAmount: 0n, revealFee: 7n, revealCredit: 13n });
  assert.throws(() => sales.canonicalNativeSalesRevealFunding(10n, 16n, quote), /below/);
  const undeclared = { ...quote, policy: { ...quote.policy, declared: false, revealFeePerTokenWei: 0n } };
  assert.deepEqual(sales.canonicalNativeSalesRevealFunding(0n, 0n, undeclared), { chargedAmount: 0n, revealFee: 0n, revealCredit: 0n });
  assert.throws(() => sales.canonicalNativeSalesRevealFunding(0n, 1n, undeclared), /exact/);
  assert.throws(() => sales.canonicalNativeSalesRevealFunding((1n << 256n) - 1n, 0n, quote), /uint256/);
  const refund = sales.prepareCanonicalNativeSalesCall(coords, caller,
    { family: "claim", kind: "claimRefund", saleId: id("historical"), recipient });
  assert.equal(refund.call.value, 0n);
  assert.equal(refund.call.data, compiledInterfaces.claim.encodeFunctionData("claimRefund", [id("historical"), recipient]));
  assert.throws(() => sales.prepareCanonicalNativeSalesCall(coords, caller,
    { family: "claim", kind: "claimRefund", saleId: ZeroHash, recipient: coords.adapter }), /recipient/);
});

test("snapshots copy all nested mutable inputs and refuse forged call reconstruction", () => {
  const e = example("claim", 13n);
  const request = structuredClone(e.request);
  const mutableCoords = { ...coords };
  const plan = sales.prepareCanonicalNativeSalesCall(mutableCoords, caller, request);
  const before = plan.call.data;
  request.purchase.mint.tokenData = "0xffff";
  request.authorization.deadline = 500n;
  request.signature.signature = "0xdead";
  mutableCoords.adapter = addr(999);
  assert.equal(plan.call.data, before);
  assert.equal(plan.request.purchase.mint.tokenData, "0x1234");
  assert(Object.isFrozen(plan.request.purchase.mint));
  assert(Object.isFrozen(plan.request.authorization));
  assert.throws(() => sales.normalizeCanonicalNativeSalesCall({ ...plan, call: { ...plan.call, value: plan.call.value + 1n } }), /differs/);
  assert.throws(() => sales.normalizeCanonicalNativeSalesCall({ ...plan, factsVerified: true }), /differs/);
  assert.throws(() => sales.prepareCanonicalNativeSalesCall(coords, caller, { ...e.request, method: "purchaseSigned" }), /unknown/);
  assert.throws(() => sales.prepareCanonicalNativeSalesCall(coords, caller, { family: "claim", kind: "registerSale" }), /Unsupported/);
});

test("full encoded calldata cap reconstructs at the accepted boundary and rejects the next ABI word", () => {
  const e = example("immediate", 0n, 2n);
  const base = sales.prepareCanonicalNativeSalesCall(coords, caller, e.request);
  const overhead = (base.call.data.length - 2) / 2;
  const size = Math.floor((sales.CANONICAL_NATIVE_SALES_MAX_BYTES - overhead) / 32) * 32;
  const request = { ...e.request, purchase: { ...e.purchase, resolverData: `0x${"aa".repeat(size)}` } };
  const plan = sales.prepareCanonicalNativeSalesCall(coords, caller, request);
  assert.deepEqual(sales.normalizeCanonicalNativeSalesCall(plan), plan);
  assert.throws(() => sales.prepareCanonicalNativeSalesCall(coords, caller,
    { ...request, purchase: { ...request.purchase, resolverData: `${request.purchase.resolverData}${"aa".repeat(32)}` } }), /byte limit/);
});

test("typed read calls keep raw history keys and expected function destinations", () => {
  const reads = [
    { kind: "nextSaleNonce" }, { kind: "refundLiability" }, { kind: "refundAccountCount" }, { kind: "eip712Domain" },
    ...["saleRecord", "saleConsentFacts", "nativeSaleLifecycleBinding", "publicNativeSaleBinding", "immediateSaleAuthorizationBinding", "saleRevealQuote"].map(kind => ({ kind, saleId: ZeroHash })),
    ...["executionReceipt", "executionStatus", "activePublicNativeCandidate"].map(kind => ({ kind, executionId: ZeroHash })),
    { kind: "nextExecutionNonce", saleId: ZeroHash, payer: ZeroAddress },
    { kind: "refundableBalance", saleId: ZeroHash, payer: ZeroAddress },
    { kind: "refundAccountAt", index: 1n << 130n },
    { kind: "saleIdFor", collectionId: 0n, phaseId: ZeroHash, saleNonce: 0n },
    { kind: "collectionSigner", collectionId: 0n, signer: ZeroAddress, signerKind: 0n },
    { kind: "authorizationDigest", authorization: example().authorization },
  ];
  for (const family of ["immediate", "claim"]) {
    for (const read of reads) {
      const call = sales.prepareCanonicalNativeSalesRead(coords.adapter, family, read);
      assert.equal(call.to, coords.adapter);
      assert.equal(call.value, 0n);
      assert.equal(compiledInterfaces[family].parseTransaction({ data: call.data }).name, read.kind);
    }
  }
});
