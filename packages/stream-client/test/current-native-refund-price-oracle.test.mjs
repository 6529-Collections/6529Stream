import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, TypedDataEncoder, ZeroAddress, id, keccak256 } from "ethers";
import * as records from "../dist/current-refund-purchase-record.js";
import * as refund from "../dist/current-native-allowlist-refund.js";

// Literal source preimages from 90e68ebf. These check caller encoding and stored
// commitment consistency; they do not prove historical admission or execution.
const coder = AbiCoder.defaultAbiCoder();
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chainId = 31337n, adapter = A(1), payer = A(2), owner = A(3);
const configType = "tuple(uint256 collectionId,bytes32 phaseId,uint256 price,uint64 maxSaleQuantity,uint64 startsAt,uint64 endsAt,uint64 refundWindowSeconds,uint64 finalizationWindowSeconds,uint8 primaryPolicyMode,bytes32 mintPolicyHash)";
const policyType = "tuple(bytes32 counterId,bool allowFree)";
const authType = "tuple(bytes32 saleId,bytes32 saleConfigHash,address payer,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 purchaseNonce,bytes32 nonce,uint256 price,uint64 deadline,bytes32 windowPolicyHash,uint64 maximumNominalFinalizeBy,uint64 absoluteEscapeDeadline,bytes32 expectedPrimaryPolicyHash)";
const captureType = "tuple(uint256 savedRevealFee,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address referencedGate)";
const proofType = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)";
const config = { collectionId: 9007199254740997n, phaseId: id("refund phase"), price: (1n << 200n) + 100n,
  maxSaleQuantity: (1n << 64n) - 1n, startsAt: 100n, endsAt: 200n, refundWindowSeconds: 3600n,
  finalizationWindowSeconds: 86400n, primaryPolicyMode: 1n, mintPolicyHash: id("mint policy") };
const policy = { counterId: id("selected counter"), allowFree: true };
const baseline = id("registration baseline"), nonce = (1n << 255n) + 3n;
const plain = { maxCount: 1n, hasPriceOverride: false, priceOverride: 0n, proof: [] };
const priced = { maxCount: (1n << 64n) - 1n, hasPriceOverride: true, priceOverride: 40n, proof: [id("sibling")] };

function saleId(c = config) {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), chainId, adapter, 7n, c.collectionId, c.phaseId, nonce]));
}
function windowHash(c = config) {
  return keccak256(coder.encode(["bytes32", "uint64", "uint64", "bytes32", "bytes32"],
    [id("6529STREAM_REFUND_WINDOW_POLICY_V1"), c.refundWindowSeconds, c.finalizationWindowSeconds,
      id("OBSERVED_GLOBAL_OR_LOCAL_PAUSE_UNION"), id("ABSOLUTE_ESCAPE_PAUSED_EQUALITY_UNPAUSED_FINALIZE_EQUALITY")]));
}
function originalConfigHash(c = config) {
  return keccak256(coder.encode(["bytes32", "bytes32", configType, "bytes32"],
    [id("6529STREAM_NATIVE_REFUND_SALE_CONFIG_V1"), saleId(c), c, baseline]));
}
function wrappedConfigHash(c = config, p = policy) {
  return keccak256(coder.encode(["bytes32", "bytes32", policyType],
    [id("6529STREAM_NATIVE_ALLOWLIST_REFUND_CONFIG_V1"), originalConfigHash(c), p]));
}
function authorization() {
  return { saleId: saleId(), saleConfigHash: wrappedConfigHash(), payer, recipient: A(4), artist: A(5),
    tokenDataHash: keccak256("0x00123400"), mintCommitment: id("commitment"), purchaseNonce: nonce,
    nonce: id("authorization nonce"), price: config.price, deadline: 200n, windowPolicyHash: windowHash(),
    maximumNominalFinalizeBy: 100000n, absoluteEscapeDeadline: 120000n, expectedPrimaryPolicyHash: id("current primary policy") };
}
const fields = [
  ["saleId", "bytes32"], ["saleConfigHash", "bytes32"], ["payer", "address"], ["recipient", "address"],
  ["artist", "address"], ["tokenDataHash", "bytes32"], ["mintCommitment", "bytes32"], ["purchaseNonce", "uint256"],
  ["nonce", "bytes32"], ["price", "uint256"], ["deadline", "uint64"], ["windowPolicyHash", "bytes32"],
  ["maximumNominalFinalizeBy", "uint64"], ["absoluteEscapeDeadline", "uint64"], ["expectedPrimaryPolicyHash", "bytes32"],
].map(([name, type]) => ({ name, type }));
function digest(a = authorization()) {
  return TypedDataEncoder.hash({ name: "6529StreamNativeRefundWindowSale", version: "1", chainId, verifyingContract: adapter },
    { RefundPurchaseAuthorization: fields }, a);
}
function purchaseId(a = authorization()) {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "uint256"],
    [id("6529STREAM_SALE_PURCHASE_V1"), chainId, adapter, a.saleId, a.payer, a.purchaseNonce]));
}
const capture = { savedRevealFee: 7n, artistId: id("original artist identity"), bindingGeneration: (1n << 63n) + 1n,
  bindingHash: id("original binding"), referencedGate: ZeroAddress };
const purchasedAt = 150n, pauseBaseline = 12n, refundDeadline = 3750n, finalizeBy = 90150n;
function originalRecordHash(a = authorization(), facts = capture) {
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", "bytes32", authType, "bytes32", captureType, "uint64", "uint64", "uint64", "uint64"],
    [id("6529STREAM_REFUND_PURCHASE_RECORD_V1"), chainId, adapter, purchaseId(a), a, digest(a), facts,
      purchasedAt, pauseBaseline, refundDeadline, finalizeBy],
  ));
}
function wrappedRecordHash(original, chargedPrice, proofHash) {
  return keccak256(coder.encode(["bytes32", "bytes32", "uint256", "bytes32"],
    [id("6529STREAM_REFUND_ALLOWLIST_PURCHASE_RECORD_V1"), original, chargedPrice, proofHash]));
}

test("refund ABI fixture keeps its exact source capture and additive saved-price reads", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-refund-price-abi.json", import.meta.url)));
  assert.equal(fixture.sourceCommit, "90e68ebfc62e63eb46c6f23b23c32f3ccf2957a8");
  assert.equal(fixture.sourceTree, "1011eb3e1470dab54cf770904f0fb3ac749777fe");
  assert.equal(fixture.sourceCount, 291);
  assert.equal(fixture.inputSha256, "43a641fea018f20fe0119d4c4003a0c4b5dacc335b49eb13263c3e338a711a09");
  assert.equal(fixture.outputSha256, "2c5d098727bcba813eb8215a78be8efc2faedd333628946691be3548d729210f");
  assert.equal(Object.keys(fixture.sources).length, 14);
  const abi = new Interface(fixture.abis.refund);
  assert.equal(abi.getFunction("purchaseAllowlistRefundWindow").stateMutability, "payable");
  assert.deepEqual(abi.getFunction("refundPurchasePriceFacts").outputs.map(x => x.type), ["bool", "uint256", "bytes32"]);
});

test("refund record preimage binds original full authorization and capture facts before its price wrapper", () => {
  const auth = authorization(), expected = originalRecordHash(auth);
  const actual = records.nativeRefundOriginalPurchaseRecordHash(chainId, adapter, purchaseId(auth), auth, digest(auth), capture,
    purchasedAt, pauseBaseline, refundDeadline, finalizeBy);
  assert.equal(actual, expected);
  const resolver = coder.encode([`${proofType}[][]`], [[[plain], [priced]]]);
  for (const charge of [0n, 40n, (1n << 255n) + 1n]) {
    assert.equal(records.nativeRefundAllowlistPurchaseRecordHash(actual, charge, keccak256(resolver)),
      wrappedRecordHash(expected, charge, keccak256(resolver)));
  }
  for (const changed of [{ ...capture, savedRevealFee: 8n }, { ...capture, referencedGate: A(9) }, { ...capture, bindingGeneration: 1n }]) {
    const changedHash = records.nativeRefundOriginalPurchaseRecordHash(chainId, adapter, purchaseId(auth), auth, digest(auth), changed,
      purchasedAt, pauseBaseline, refundDeadline, finalizeBy);
    assert.equal(changedHash, originalRecordHash(auth, changed));
    assert.notEqual(changedHash, expected);
  }
});

test("saved proof decoding rejects noncanonical trailing data and malformed single-token groups", () => {
  const encoded = groups => coder.encode([`${proofType}[][]`], [groups]);
  assert.doesNotThrow(() => records.decodeCanonicalRefundAllowlistResolverData(encoded([[plain], [priced]])));
  assert.throws(() => records.decodeCanonicalRefundAllowlistResolverData(encoded([[plain]]) + "00".repeat(32)));
  assert.throws(() => records.decodeCanonicalRefundAllowlistResolverData(encoded([])));
  assert.throws(() => records.decodeCanonicalRefundAllowlistResolverData(encoded([[]])));
  assert.throws(() => records.decodeCanonicalRefundAllowlistResolverData(encoded([[plain, priced]])));
  assert.throws(() => records.decodeCanonicalRefundAllowlistResolverData(encoded([[{ ...plain, priceOverride: 1n }]])));
  assert.throws(() => records.decodeCanonicalRefundAllowlistResolverData(encoded([[{ ...priced, proof: Array(257).fill(id("node")) }]])));
});

async function recordProvider(controls = {}) {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-refund-price-abi.json", import.meta.url)));
  const abi = new Interface(fixture.abis.refund), auth = authorization();
  const resolver = coder.encode([`${proofType}[][]`], [[[{ ...priced, priceOverride: 0n }]]]);
  const hash = wrappedRecordHash(originalRecordHash(auth), 0n, keccak256(resolver));
  const record = { authorization: auth, authorizationDigest: digest(auth), purchaseRecordHash: controls.badRecord ? id("bad record") : hash,
    artistId: capture.artistId, bindingGeneration: capture.bindingGeneration, bindingHash: capture.bindingHash,
    referencedGate: capture.referencedGate, tokenData: "0x00123400", savedRevealFee: capture.savedRevealFee,
    purchasedAt, pauseBaseline, nominalRefundDeadline: refundDeadline, nominalFinalizeBy: finalizeBy,
    terminalToll: controls.terminalToll ?? 999n, status: controls.status ?? 3n };
  const calls = [];
  let blocks = 0;
  const provider = {
    getNetwork: async () => {
      controls.mutate?.();
      return { chainId };
    },
    getBlock: async () => ({ number: 77, hash: controls.reorg && ++blocks > 1 ? id("new block") : id("pinned block"), timestamp: 200 }),
    getCode: async (to, blockTag) => { assert.equal(to.toLowerCase(), adapter); assert.equal(blockTag, 77); return "0x6001600055"; },
    call: async tx => {
      assert.equal(tx.to.toLowerCase(), adapter);
      assert.equal(tx.blockTag, 77);
      const parsed = abi.parseTransaction({ data: tx.data });
      calls.push(parsed.name);
      const values = {
        refundPurchaseRecord: [record],
        refundPurchasePriceFacts: [true, 0n, keccak256(resolver)],
        refundPurchaseResolverData: [controls.badProof ? "0x1234" : resolver],
        refundPurchaseAuthorizationDigest: [digest(auth)],
      };
      assert.ok(Object.hasOwn(values, parsed.name), "stored-record read must not require current admission");
      return abi.encodeFunctionResult(parsed.name, values[parsed.name]);
    },
  };
  return { provider, calls, resolver, hash };
}
function coordinates() {
  return { chainId, adapter, purchaseId: purchaseId(), saleId: saleId(), payer };
}

test("captured zero price and original proof commitment survive every terminal status without repricing", async () => {
  for (const status of [1n, 2n, 3n, 4n]) {
    const { provider } = await recordProvider({ status, terminalToll: status === 1n ? 0n : status * 7n });
    const verified = await records.verifyCurrentRefundPurchaseRecord(provider, coordinates());
    assert.equal(verified.chargedPrice, 0n);
    assert.equal(verified.publicPrice, config.price);
    assert.equal(verified.record.status, status);
    assert.equal(verified.mutableLifecycleExcludedFromHash, true);
  }
});

test("record verification rejects proof, commitment and canonical-block drift while copying expected coordinates", async () => {
  for (const controls of [{ badRecord: true }, { badProof: true }, { reorg: true }]) {
    const { provider } = await recordProvider(controls);
    await assert.rejects(records.verifyCurrentRefundPurchaseRecord(provider, coordinates()));
  }
  const expected = coordinates();
  const { provider } = await recordProvider({ mutate: () => { expected.adapter = A(99); expected.purchaseId = id("changed"); } });
  const verified = await records.verifyCurrentRefundPurchaseRecord(provider, expected);
  assert.equal(verified.chargedPrice, 0n);
  assert.equal(verified.publicPrice, config.price);
});

test("refund sale and window commitments retain their original preimages under the additive policy wrapper", async () => {
  assert.equal(refund.nativeAllowlistRefundSaleId(chainId, adapter, config.collectionId, config.phaseId, nonce), saleId());
  assert.equal(refund.nativeRefundWindowPolicyHash(config), windowHash());
  assert.equal(refund.nativeRefundOriginalConfigHash(saleId(), config, baseline), originalConfigHash());
  assert.equal(refund.nativeAllowlistRefundConfigHash(originalConfigHash(), policy), wrappedConfigHash());
  const registered = refund.prepareNativeAllowlistRefundRegistration(chainId, adapter, owner, nonce, config, policy, baseline);
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-refund-price-abi.json", import.meta.url)));
  assert.equal(registered.call.data, new Interface(fixture.abis.refund).encodeFunctionData("registerAllowlistRefundSale", [config, policy]));
  assert.equal(registered.configHash, wrappedConfigHash());
  assert.equal(registered.expectedPolicyRequiresPostRegistrationReadback, true);
  assert.notEqual(refund.nativeAllowlistRefundConfigHash(originalConfigHash(), { ...policy, allowFree: false }), wrappedConfigHash());
  assert.notEqual(refund.nativeRefundWindowPolicyHash({ ...config, refundWindowSeconds: 3601n }), windowHash());
});

test("refund signing binds the original public price and window envelope instead of the saved charge", () => {
  const auth = authorization();
  const payload = refund.nativeRefundPurchaseAuthorizationPayload(chainId, adapter, auth);
  assert.equal(payload.digest, digest(auth));
  assert.equal(refund.nativeRefundPurchaseId(chainId, adapter, auth.saleId, auth.payer, auth.purchaseNonce), purchaseId(auth));
  assert.equal(payload.message.price, config.price);
  for (const changed of [{ ...auth, price: 40n }, { ...auth, maximumNominalFinalizeBy: 100001n },
    { ...auth, absoluteEscapeDeadline: 120001n }, { ...auth, purchaseNonce: nonce + 1n }]) {
    assert.notEqual(refund.nativeRefundPurchaseAuthorizationPayload(chainId, adapter, changed).digest, payload.digest);
  }
});

test("refund override is an exact saved price including above-public values, with separately declared zero", () => {
  for (const amount of [0n, 40n, (1n << 255n) + 1n]) {
    assert.deepEqual(refund.nativeAllowlistRefundCharge(config.price, policy, { ...priced, priceOverride: amount }),
      { overridden: true, publicPrice: config.price, chargedPrice: amount });
  }
  assert.deepEqual(refund.nativeAllowlistRefundCharge(config.price, policy, plain),
    { overridden: false, publicPrice: config.price, chargedPrice: config.price });
  assert.throws(() => refund.nativeAllowlistRefundCharge(config.price, { ...policy, allowFree: false }, { ...priced, priceOverride: 0n }));
  assert.throws(() => refund.nativeAllowlistRefundCharge(config.price, policy, { ...plain, priceOverride: 1n }));
});

test("refund purchase CALL preserves original authorization, exact proofs and total attached funding", async () => {
  const auth = authorization();
  const proof = { ...priced, priceOverride: 100n };
  const groups = [{ counterId: id("other counter"), proof: plain }, { counterId: policy.counterId, proof }];
  const input = { tokenData: "0x00123400", platformSignature: "0xaaaa", artistSignature: "0xbb",
    priceFundingMaximum: 90n, revealFeeAllowance: 20n, proofGroups: groups };
  const prepared = refund.prepareNativeAllowlistRefundPurchase(chainId, adapter, config, policy, baseline, auth, input);
  const resolver = coder.encode([`${proofType}[][]`], [[[plain], [proof]]]);
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-refund-price-abi.json", import.meta.url)));
  const data = { authorization: auth, tokenData: input.tokenData, platformSignature: input.platformSignature, artistSignature: input.artistSignature };
  assert.equal(prepared.call.data, new Interface(fixture.abis.refund).encodeFunctionData("purchaseAllowlistRefundWindow", [data, resolver]));
  assert.equal(prepared.resolverData, resolver);
  assert.equal(prepared.call.value, 110n);
  assert.equal(prepared.expectedCharge.chargedPrice, 100n);
  assert.equal(prepared.payload.message.price, config.price);
  assert.equal(prepared.expectedPurchaseId, purchaseId(auth));
  assert.equal(prepared.caller, payer);
  groups[0].counterId = id("different unchecked label");
  assert.equal(refund.prepareNativeAllowlistRefundPurchase(chainId, adapter, config, policy, baseline, auth, input).call.data, prepared.call.data);
});

test("refund lifecycle calls preserve original selectors, payer-owned claims and zero native value", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-refund-price-abi.json", import.meta.url)));
  const abi = new Interface(fixture.abis.refund), pid = purchaseId();
  const calls = [
    [refund.prepareNativeRefundFinalize(adapter, pid, owner), "finalizeRefundWindow", [pid]],
    [refund.prepareNativeRefundRefund(adapter, pid, payer), "refundPurchase", [pid]],
    [refund.prepareNativeRefundUnlock(adapter, pid, 0n, owner), "unlockRefund", [pid, 0n]],
    [refund.prepareNativeRefundSynchronize(adapter, pid, owner), "synchronizePurchaseWindow", [pid]],
    [refund.prepareNativeRefundClaim(adapter, saleId(), payer, A(8)), "claimRefund", [saleId(), A(8)]],
  ];
  for (const [prepared, method, args] of calls) {
    assert.equal(prepared.call.data, abi.encodeFunctionData(method, args));
    assert.equal(prepared.call.to, adapter);
    assert.equal(prepared.call.value, 0n);
  }
  assert.equal(calls[1][0].caller, payer);
  assert.equal(calls[4][0].caller, payer);
});
