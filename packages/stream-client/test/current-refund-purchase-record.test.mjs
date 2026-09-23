import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, id, keccak256 } from "ethers";
import {
  nativeRefundPurchaseAuthorizationPayload,
  nativeRefundPurchaseId,
} from "../dist/current-native-allowlist-refund.js";
import {
  REFUND_RECORD_MAX_RAW_RETURN_BYTES,
  decodeCanonicalRefundAllowlistResolverData,
  nativeRefundAllowlistPurchaseRecordHash,
  nativeRefundOriginalPurchaseRecordHash,
  verifyCurrentRefundPurchaseRecord,
} from "../dist/current-refund-purchase-record.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-native-refund-price-abi.json", import.meta.url), "utf8"));
const refundAbi = new Interface(fixture.abis.refund);
const coder = AbiCoder.defaultAbiCoder();
const proofTuple = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)";
const A = value => `0x${BigInt(value).toString(16).padStart(40, "0")}`;
const chainId = 31337n, adapter = A(1), payer = A(2), recipient = A(3), artist = A(4);
const saleId = id("refund sale"), tokenData = "0x123456", code = "0x60016000";
const blockHash = id("refund record block");

function authorization(price = 100n) {
  return { saleId, saleConfigHash: id("sale config"), payer, recipient, artist,
    tokenDataHash: keccak256(tokenData), mintCommitment: id("mint commitment"), purchaseNonce: 9n,
    nonce: `0x${"00".repeat(32)}`, price, deadline: 1_000n, windowPolicyHash: id("windows"),
    maximumNominalFinalizeBy: 9_000n, absoluteEscapeDeadline: 10_000n,
    expectedPrimaryPolicyHash: id("primary policy") };
}
function resolver(enabled = true, price = 5n) {
  return coder.encode([`${proofTuple}[][]`], [[[{ maxCount: 2n, hasPriceOverride: enabled,
    priceOverride: enabled ? price : 0n, proof: [id("sibling")] }]]]);
}
function captured(price = 5n, enabled = true) {
  const auth = authorization(), purchaseId = nativeRefundPurchaseId(chainId, adapter, saleId, payer, auth.purchaseNonce);
  const payload = nativeRefundPurchaseAuthorizationPayload(chainId, adapter, auth);
  const capture = { savedRevealFee: 7n, artistId: id("artist id"), bindingGeneration: 3n,
    bindingHash: id("binding"), referencedGate: ZeroAddress };
  const original = nativeRefundOriginalPurchaseRecordHash(chainId, adapter, purchaseId, auth, payload.digest,
    capture, 500n, 12n, 4_100n, 8_100n);
  const resolverData = resolver(enabled, price), chargedPrice = enabled ? price : auth.price;
  const wrapped = nativeRefundAllowlistPurchaseRecordHash(original, chargedPrice, keccak256(resolverData));
  const record = { authorization: auth, authorizationDigest: payload.digest, purchaseRecordHash: wrapped,
    artistId: capture.artistId, bindingGeneration: capture.bindingGeneration, bindingHash: capture.bindingHash,
    referencedGate: capture.referencedGate, tokenData, savedRevealFee: capture.savedRevealFee, purchasedAt: 500n,
    pauseBaseline: 12n, nominalRefundDeadline: 4_100n, nominalFinalizeBy: 8_100n,
    terminalToll: 999n, status: 3n };
  return { auth, purchaseId, payload, capture, original, resolverData, chargedPrice, wrapped, record };
}
function rpc(state) {
  return {
    async getNetwork() { return { chainId }; },
    async getBlock() { return { number: 77, hash: blockHash, timestamp: 2_000 }; },
    async getCode(target) { assert.equal(target, adapter); return code; },
    async call(tx) {
      const parsed = refundAbi.parseTransaction(tx); let output;
      if (parsed.name === "refundPurchaseRecord") output = [state.record];
      else if (parsed.name === "refundPurchasePriceFacts") output = [true, state.chargedPrice, keccak256(state.resolverData)];
      else if (parsed.name === "refundPurchaseResolverData") {
        if (state.oversizedRaw) return `0x${"00".repeat(REFUND_RECORD_MAX_RAW_RETURN_BYTES + 1)}`;
        output = [state.resolverData];
      }
      else if (parsed.name === "refundPurchaseAuthorizationDigest") output = [state.payload.digest];
      else throw new Error(`unexpected refund read ${parsed.name}`);
      return refundAbi.encodeFunctionResult(parsed.name, output);
    },
  };
}

test("terminal allowlist record reproduces original and wrapped immutable commitments", async () => {
  const state = captured(), verified = await verifyCurrentRefundPurchaseRecord(rpc(state), {
    chainId, adapter, purchaseId: state.purchaseId, saleId, payer,
  });
  assert.equal(verified.record.status, 3n);
  assert.equal(verified.record.terminalToll, 999n);
  assert.equal(verified.mutableLifecycleExcludedFromHash, true);
  assert.equal(verified.originalPurchaseRecordHash, state.original);
  assert.equal(verified.allowlistPurchaseRecordHash, state.wrapped);
  assert.equal(verified.chargedPrice, 5n);
  assert.equal(verified.publicPrice, 100n);
  assert.equal(verified.priceSource, "saved-allowlist-override");
  assert.equal(verified.record.authorization.nonce, `0x${"00".repeat(32)}`);
  assert.equal(verified.capture.referencedGate, ZeroAddress);
});

test("cap-only saved proof retains the original signed public price", async () => {
  const state = captured(0n, false), verified = await verifyCurrentRefundPurchaseRecord(rpc(state), {
    chainId, adapter, purchaseId: state.purchaseId, saleId, payer,
  });
  assert.equal(verified.priceSource, "original-public-price");
  assert.equal(verified.chargedPrice, state.auth.price);
});

test("resolver decoder rejects noncanonical bytes and readback rejects changed saved token data", async () => {
  const state = captured();
  assert.throws(() => decodeCanonicalRefundAllowlistResolverData(`${state.resolverData}00`), /canonical/);
  state.record = { ...state.record, tokenData: "0xabcd" };
  await assert.rejects(verifyCurrentRefundPurchaseRecord(rpc(state), {
    chainId, adapter, purchaseId: state.purchaseId, saleId, payer,
  }), /tokenData/);
});

test("readback rejects oversized dynamic RPC return data before ABI decoding", async () => {
  const state = captured();
  state.oversizedRaw = true;
  await assert.rejects(verifyCurrentRefundPurchaseRecord(rpc(state), {
    chainId, adapter, purchaseId: state.purchaseId, saleId, payer,
  }), /raw return/);
});
