import { id, keccak256 } from "ethers";
import {
  CurrentNativeAllowlistClearingClient,
  nativeAllowlistClearingConfigHash,
  nativeClearingAuthorizationTypedData,
  nativeClearingOriginalConfigHash,
  nativeClearingSaleId,
  nativeClearingSchedulePrice,
} from "../dist/current-native-allowlist-clearing.js";

const A = value => `0x${BigInt(value).toString(16).padStart(40, "0")}`;
const chainId = 1n, adapter = A(1), expectedNonce = 7n;
const config = {
  collectionId: 6529n,
  phaseId: id("clearing phase"),
  schedule: { startPrice: 1_000n, restingPrice: 100n, startTime: 1_000n, endTime: 1_100n,
    decayKind: 0n, stepSeconds: 0n, stepAmount: 0n },
  maxSaleQuantity: 10n,
  closesAt: 1_200n,
  finalizationWindowSeconds: 100n,
  absoluteEscapeDeadline: 1_400n,
  primaryPolicyMode: 1n,
  mintPolicyHash: id("mint policy"),
};
const counterId = id("allowlist counter"), baseline = id("current primary policy");
const saleId = nativeClearingSaleId(chainId, adapter, config.collectionId, config.phaseId, expectedNonce);
const original = nativeClearingOriginalConfigHash(chainId, adapter, saleId, config, baseline);
const configHash = nativeAllowlistClearingConfigHash(original, counterId);
const authorization = {
  saleId, saleConfigHash: configHash, payer: A(2), executor: A(2), recipient: A(3), artist: A(4),
  tokenDataHash: keccak256("0x1234"), mintCommitment: id("mint commitment"), purchaseNonce: 1n,
  executionNonce: 1n, nonce: id("artist authorization"), deadline: 1_150n,
  expectedPrimaryPolicyHash: baseline, unitPrice: 700n, hasPriceOverride: true, priceOverride: 500n,
  windowPolicyHash: (await import("../dist/current-native-allowlist-clearing.js")).nativeClearingWindowPolicyHash(config),
  maximumNominalFinalizeBy: 1_300n, absoluteEscapeDeadline: 1_400n,
};
const client = new CurrentNativeAllowlistClearingClient(chainId, adapter);

export async function reviewPurchase(provider, signedAuthorization, purchaseInput, blockTag = "latest") {
  return client.preparePurchase(provider, signedAuthorization, purchaseInput, blockTag);
}

console.log(JSON.stringify({ saleId, originalConfigHash: original, configHash,
  priceAt1040: nativeClearingSchedulePrice(config.schedule, 1_040n),
  signingDigest: nativeClearingAuthorizationTypedData(chainId, adapter, authorization).digest,
  next: "Simulate registration from the current owner or inspect the stored sale, then run sender-aware purchase preparation." },
(_, value) => typeof value === "bigint" ? value.toString() : value, 2));
