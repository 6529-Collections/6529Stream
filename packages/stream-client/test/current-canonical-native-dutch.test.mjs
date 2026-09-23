import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as dutch from "../dist/current-canonical-native-dutch.js";
import * as sales from "../dist/current-canonical-native-sales.js";
import { compiledInterfaces } from "./current-canonical-dutch-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const addr = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const coordinates = { chainId: (1n << 160n) + 1n, adapter: addr(1), manager: addr(2), ledger: addr(3), recorder: addr(4) };
const actor = addr(5);
const terms = { nonce: id("seller nonce"), deadline: 1000n, unitPrice: 1000n };
function setup(mode = 1n, declaredFree = false) {
  const signer = mode === 1n ? { authorizer: addr(6), kind: 2n, evidenceHash: id("signer evidence"), revision: 1n, installingAuthority: addr(7) }
    : { authorizer: ZeroAddress, kind: 0n, evidenceHash: ZeroHash, revision: 0n, installingAuthority: ZeroAddress };
  const config = {
    sale: { collectionId: (1n << 150n) + 5n, phaseId: id("phase"), saleKind: 3n, authorityMode: mode,
      unitPrice: 1000n, startsAt: 100n, endsAt: 200n, manualClose: false, saleSupplyLimit: 10n,
      mintPolicyHash: id("bound policy"), expectedPrimaryPolicyHash: id("primary policy"), primaryPolicyMode: 0n,
      priceCounterId: ZeroHash, signer },
    schedule: { startPrice: 1000n, restingPrice: declaredFree ? 0n : 100n, startTime: 100n, endTime: 200n,
      decayKind: 0n, stepSeconds: 0n, stepAmount: 0n }, declaredFree,
  };
  const saleId = dutch.canonicalNativeDutchSaleId(coordinates, config.sale.collectionId, config.sale.phaseId, 1n);
  const purchase = { saleId, payer: actor, executor: actor, initialRecipient: addr(8), beneficiary: addr(9),
    tokenData: "0x1234", mintCommitment: id("mint"), resolverData: "0x", executionNonce: 1n };
  const authorization = mode === 1n ? dutch.canonicalNativeDutchExpectedAuthorization(coordinates, config, purchase, terms) : null;
  const request = mode === 1n ? { kind: "purchaseSigned", purchase, authorization,
    signature: { authorizer: signer.authorizer, kind: signer.kind, signature: "0x" }, value: 1100n }
    : { kind: "purchasePublic", purchase, value: 1100n };
  const record = { sale: { config: config.sale, configHash: dutch.canonicalNativeDutchConfigurationHash(coordinates, config),
    saleNonce: 1n, soldQuantity: 0n, closed: false, lifecycle: { saleCreatedAt: 99n, saleAdapterRegistryRevision: 3n },
    artistId: id("artist"), artistGeneration: 1n, artistBindingHash: id("binding") }, schedule: config.schedule,
    priceScheduleHash: dutch.canonicalNativeDutchScheduleHash(coordinates, saleId, config.schedule), declaredFree };
  return { config, purchase, authorization, request, record };
}

test("canonical native Dutch preserves original24 domain, fullwidth identity and distinct recipients", () => {
  const e = setup();
  const payload = dutch.canonicalNativeDutchAuthorizationPayload(coordinates, e.authorization);
  assert.equal(payload.domain.name, "6529Stream Sales");
  assert.equal(payload.domain.version, "1");
  assert.equal(payload.domain.verifyingContract, coordinates.adapter);
  assert.equal(payload.types.SaleAuthorization.length, 24);
  assert.equal(payload.digest, sales.canonicalNativeSalesAuthorizationPayload(coordinates, e.authorization).digest);
  assert.notEqual(e.authorization.initialRecipientsHash, e.authorization.beneficiariesHash);
  assert.equal(e.authorization.saleKind, 3n);
  assert.equal(e.authorization.chainId, coordinates.chainId);
  assert.equal(e.authorization.asset, ZeroAddress);
  const plan = dutch.prepareCanonicalNativeDutchCall(coordinates, actor, e.request);
  const batch = dutch.canonicalNativeDutchMintBatch(plan, e.record);
  assert.deepEqual(batch.initialRecipients, [e.purchase.initialRecipient]);
  assert.deepEqual(batch.beneficiaries, [e.purchase.beneficiary]);
  assert.equal(batch.authorizer, ZeroAddress);
  assert.equal(batch.authorizationId, dutch.canonicalNativeDutchAuthorizationId(coordinates, e.authorization));
});

test("native Dutch registration shape keeps inclusive schedule end and requires its start price", () => {
  const e = setup();
  assert.deepEqual(dutch.validateCanonicalNativeDutchConfiguration(e.config), e.config);
  for (const patch of [{ unitPrice: 0n }, { saleKind: 0n }, { endsAt: 199n }, { saleSupplyLimit: 0n }, { primaryPolicyMode: 1n }]) {
    assert.throws(() => dutch.validateCanonicalNativeDutchConfiguration({ ...e.config, sale: { ...e.config.sale, ...patch } }));
  }
  assert.throws(() => dutch.validateCanonicalNativeDutchConfiguration({ ...e.config, schedule: { ...e.config.schedule, restingPrice: 0n } }), /schedule/);
  const manual = { ...e.config, sale: { ...e.config.sale, manualClose: true, endsAt: 0n } };
  assert.deepEqual(dutch.validateCanonicalNativeDutchConfiguration(manual), manual);
  assert.throws(() => dutch.validateCanonicalNativeDutchConfiguration({ ...setup(2n).config, sale: { ...setup(2n).config.sale, signer: e.config.sale.signer } }), /empty/);
});

test("raw-time linear rounding and partial stepped end are independent from sale pauses", () => {
  const e = setup();
  const noOverride = { hasOverride: false, overridePrice: 0n };
  assert.equal(dutch.canonicalNativeDutchPrice(e.config, 99n, 1000n, noOverride).amount, 1000n);
  assert.equal(dutch.canonicalNativeDutchPrice(e.config, 101n, 1000n, noOverride).amount, 991n);
  assert.equal(dutch.canonicalNativeDutchPrice(e.config, 201n, 1000n, noOverride).amount, 100n);
  const fractional = { ...e.config, schedule: { ...e.config.schedule, restingPrice: 999n } };
  assert.equal(dutch.canonicalNativeDutchPrice(fractional, 199n, 1000n, noOverride).amount, 1000n);
  const stepped = { ...e.config, schedule: { ...e.config.schedule, decayKind: 1n, stepSeconds: 30n, stepAmount: 100n } };
  assert.equal(dutch.canonicalNativeDutchPrice(stepped, 199n, 1000n, noOverride).amount, 700n);
  assert.equal(dutch.canonicalNativeDutchPrice(stepped, 200n, 1000n, noOverride).amount, 100n);
  for (const patch of [{ startPrice: 1n << 96n }, { stepSeconds: 1n << 32n }, { startTime: 1n << 64n }, { decayKind: 2n }]) {
    assert.throws(() => dutch.validateCanonicalNativeDutchSchedule({ ...e.config.schedule, ...patch }, false));
  }
});

test("authenticated ceiling replaces signed maximum, including true zero and unchanged digest", () => {
  const e = setup(1n, true);
  const authorization = dutch.canonicalNativeDutchExpectedAuthorization(coordinates, e.config, e.purchase, { ...terms, unitPrice: 599n });
  const before = dutch.canonicalNativeDutchAuthorizationPayload(coordinates, authorization).digest;
  assert.equal(dutch.canonicalNativeDutchPrice(e.config, 100n, authorization.unitPrice, { hasOverride: true, overridePrice: 600n }).amount, 600n);
  assert.throws(() => dutch.canonicalNativeDutchPrice(e.config, 100n, 599n, { hasOverride: false, overridePrice: 0n }), /maximum/);
  assert.equal(dutch.canonicalNativeDutchPrice(e.config, 100n, 0n, { hasOverride: true, overridePrice: 0n }).amount, 0n);
  assert.throws(() => dutch.canonicalNativeDutchPrice(setup().config, 100n, 1000n, { hasOverride: true, overridePrice: 0n }), /free/);
  assert.equal(dutch.canonicalNativeDutchAuthorizationPayload(coordinates, authorization).digest, before);
  assert.equal(dutch.canonicalNativeDutchPrice(setup(2n).config, 150n, null, { hasOverride: false, overridePrice: 0n }).amount, 550n);
});

test("native maximum is value minus captured fee and every excess is payer pull credit", () => {
  assert.deepEqual(dutch.canonicalNativeDutchFunding(1200n, 50n, 600n), { maximum: 1150n, revealCredit: 550n });
  assert.deepEqual(dutch.canonicalNativeDutchFunding(100n, 0n, 0n), { maximum: 100n, revealCredit: 100n });
  assert.deepEqual(dutch.canonicalNativeDutchFunding(600n, 0n, 600n), { maximum: 600n, revealCredit: 0n });
  assert.throws(() => dutch.canonicalNativeDutchFunding(1n, 2n, 0n), /fee/);
  assert.throws(() => dutch.canonicalNativeDutchFunding(600n, 1n, 600n), /maximum/);
  assert.throws(() => dutch.canonicalNativeDutchFunding(1, 0n, 0n), /bigint/);
});

test("signed and public CALLs match the compiler, with literal actual native actor and value", () => {
  for (const mode of [1n, 2n]) {
    const e = setup(mode);
    const p = dutch.prepareCanonicalNativeDutchCall(coordinates, actor, e.request);
    const args = mode === 1n ? [e.purchase, e.authorization, e.request.signature] : [e.purchase];
    assert.equal(p.call.data, compiledInterfaces.nativeDutch.encodeFunctionData(e.request.kind, args));
    assert.equal(p.call.value, 1100n);
    assert.equal(p.call.to, coordinates.adapter);
    assert.equal(p.factsVerified, false);
    assert.deepEqual(dutch.normalizeCanonicalNativeDutchCall(p), p);
    const preview = dutch.prepareCanonicalNativeDutchPreview(p);
    assert.equal(preview.value, 0n);
    assert.equal(compiledInterfaces.nativeDutch.parseTransaction({ data: preview.data }).name, mode === 1n ? "previewSignedPurchase" : "previewPublicPurchase");
    assert.throws(() => dutch.prepareCanonicalNativeDutchCall(coordinates, addr(88), e.request), /actor/);
  }
});

test("public replay and configuration bind the full original request without signature substitution", () => {
  const e = setup(2n);
  const p = dutch.prepareCanonicalNativeDutchCall(coordinates, actor, e.request);
  const b = dutch.canonicalNativeDutchMintBatch(p, e.record);
  const requestHash = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", sales.CANONICAL_NATIVE_SALES_PURCHASE_TUPLE],
    [id("6529STREAM_NATIVE_DUTCH_SALES_REQUEST_V1"), coordinates.chainId, coordinates.adapter, e.record.sale.configHash, e.purchase]));
  assert.equal(b.contextHash, requestHash);
  assert.equal(b.authorizationId, dutch.canonicalNativeDutchPublicAuthorizationId(coordinates, e.record.sale.configHash, requestHash));
  const changed = { ...e.request, purchase: { ...e.purchase, executionNonce: 2n } };
  assert.notEqual(dutch.canonicalNativeDutchMintBatch(dutch.prepareCanonicalNativeDutchCall(coordinates, actor, changed), e.record).authorizationId, b.authorizationId);
  assert.throws(() => dutch.canonicalNativeDutchMintBatch(p, { ...e.record, priceScheduleHash: ZeroHash }), /identity/);
});

test("historical kind3 revocation accepts expired and nonpurchase words but keeps seven-field membership", () => {
  const e = setup();
  const historical = { ...e.authorization, nonce: ZeroHash, deadline: 0n, finalizeBy: 99n, unitPrice: 0n, quantity: 0n,
    asset: addr(90), contentSelectionHash: id("historical content"), policyHash: ZeroHash };
  const request = { kind: "voidMintImmediateSaleAuthorization", authorization: historical,
    authorizer: e.config.sale.signer.authorizer, authorizerKind: 2n, revocationSignature: "0x" };
  const p = dutch.prepareCanonicalNativeDutchCall(coordinates, addr(40), request);
  assert.equal(p.call.to, coordinates.manager);
  assert.equal(p.call.value, 0n);
  assert.equal(p.call.data, compiledInterfaces.manager.encodeFunctionData(request.kind, [historical, request.authorizer, 2n, "0x"]));
  const binding = { collectionId: historical.collectionId, phaseId: historical.phaseId, saleKind: 3n, authorityMode: 1n,
    configHash: e.record.sale.configHash, authorizer: request.authorizer, authorizerKind: 2n };
  assert.deepEqual(dutch.validateCanonicalNativeDutchHistoricalBinding(p, binding), binding);
  assert.throws(() => dutch.validateCanonicalNativeDutchHistoricalBinding(p, { ...binding, authorityMode: 2n }), /membership/);
  assert.equal(dutch.canonicalNativeDutchRevocationPayload(coordinates, historical).domain.verifyingContract, coordinates.adapter);
  assert.throws(() => dutch.prepareCanonicalNativeDutchCall(coordinates, actor, { ...e.request, authorization: historical }), /purchase/);
});

test("deadline equality, signer kind and source token bound are preserved independently from quote", () => {
  const e = setup();
  dutch.validateCanonicalNativeDutchAuthorizationDeadline(e.authorization, 1000n);
  assert.throws(() => dutch.validateCanonicalNativeDutchAuthorizationDeadline(e.authorization, 1001n), /Expired/);
  assert.throws(() => dutch.prepareCanonicalNativeDutchCall(coordinates, actor,
    { ...e.request, authorization: { ...e.authorization, nonce: ZeroHash } }), /purchase/);
  assert.throws(() => dutch.prepareCanonicalNativeDutchCall(coordinates, actor,
    { ...e.request, signature: { ...e.request.signature, kind: 0n } }), /kind/);
  const free = setup(2n);
  assert.throws(() => dutch.prepareCanonicalNativeDutchCall(coordinates, actor,
    { ...free.request, purchase: { ...free.purchase, tokenData: `0x${"ab".repeat(8193)}` } }), /byte limit/);
});

test("empty structural record roundtrips and refund/read calls do not require purchase readiness", () => {
  const raw = `0x${"00".repeat(32 * 36)}`;
  const empty = compiledInterfaces.nativeDutch.decodeFunctionResult("saleRecord", raw)[0];
  const canonical = compiledInterfaces.nativeDutch.encodeFunctionResult("saleRecord", [empty]);
  const decoded = dutch.decodeCanonicalNativeDutchRecord(canonical);
  assert.equal(decoded.sale.saleNonce, 0n);
  assert.equal(dutch.encodeCanonicalNativeDutchRecord(decoded), canonical);
  const p = dutch.prepareCanonicalNativeDutchCall(coordinates, actor, { kind: "claimRefund", saleId: ZeroHash, recipient: addr(90) });
  assert.equal(p.call.data, compiledInterfaces.nativeDutch.encodeFunctionData("claimRefund", [ZeroHash, addr(90)]));
  for (const request of [{ kind: "schedulePrice", saleId: ZeroHash }, { kind: "saleRecord", saleId: ZeroHash }, { kind: "refundLiability" }]) {
    assert.equal(dutch.prepareCanonicalNativeDutchRead(coordinates.adapter, request).value, 0n);
  }
});

test("prepared immutable copies reject unknown fields, caller/value edits and complete-call overflow", () => {
  const e = setup();
  const mutable = structuredClone(e.request);
  const p = dutch.prepareCanonicalNativeDutchCall({ ...coordinates }, actor, mutable);
  mutable.purchase.tokenData = "0xffff";
  mutable.signature.signature = "0xaa";
  assert.equal(p.request.purchase.tokenData, "0x1234");
  assert(Object.isFrozen(p.request.signature));
  assert.throws(() => dutch.normalizeCanonicalNativeDutchCall({ ...p, call: { ...p.call, value: 1n } }), /differs/);
  assert.throws(() => dutch.prepareCanonicalNativeDutchCall(coordinates, actor, { ...e.request, family: "immediate" }), /unknown/);
  const e2 = setup(2n);
  assert.throws(() => dutch.prepareCanonicalNativeDutchCall(coordinates, actor, {
    ...e2.request, purchase: { ...e2.purchase, resolverData: `0x${"01".repeat(dutch.CANONICAL_NATIVE_DUTCH_MAX_BYTES)}` },
  }), /byte limit/);
  const emptyCall = dutch.prepareCanonicalNativeDutchCall(coordinates, actor, e2.request);
  const overhead = (emptyCall.call.data.length - 2) / 2;
  const largest = Math.floor((dutch.CANONICAL_NATIVE_DUTCH_MAX_BYTES - overhead) / 32) * 32;
  const bounded = dutch.prepareCanonicalNativeDutchCall(coordinates, actor, {
    ...e2.request, purchase: { ...e2.purchase, resolverData: `0x${"01".repeat(largest)}` },
  });
  assert.deepEqual(dutch.normalizeCanonicalNativeDutchCall(bounded), bounded);
  assert.throws(() => dutch.prepareCanonicalNativeDutchCall(coordinates, actor, {
    ...e2.request, purchase: { ...e2.purchase, resolverData: `0x${"01".repeat(largest + 1)}` },
  }), /byte limit/);
});
