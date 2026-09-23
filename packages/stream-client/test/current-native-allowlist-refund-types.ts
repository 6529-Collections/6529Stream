import type { Address, Hex } from "../src/generated/contracts.js";
import {
  nativeAllowlistRefundCharge,
  nativeRefundPurchaseAuthorizationPayload,
  prepareNativeAllowlistRefundPurchase,
  prepareNativeAllowlistRefundRegistration,
  prepareNativeRefundClaim,
} from "../src/current-native-allowlist-refund.js";

declare const address: Address, hash: Hex;
const config = {
  collectionId: 1n,
  phaseId: hash,
  price: 2n,
  maxSaleQuantity: 1n,
  startsAt: 1n,
  endsAt: 2n,
  refundWindowSeconds: 3_600n,
  finalizationWindowSeconds: 86_400n,
  primaryPolicyMode: 1n,
  mintPolicyHash: hash,
} as const;
const policy = { counterId: hash, allowFree: false } as const;
const proof = {
  maxCount: 1n,
  hasPriceOverride: false,
  priceOverride: 0n,
  proof: [hash],
} as const;
const registration = prepareNativeAllowlistRefundRegistration(
  1n,
  address,
  address,
  1n,
  config,
  policy,
  hash,
);
const authorization = {
  saleId: registration.saleId,
  saleConfigHash: registration.configHash,
  payer: address,
  recipient: address,
  artist: address,
  tokenDataHash: hash,
  mintCommitment: hash,
  purchaseNonce: 1n,
  nonce: hash,
  price: config.price,
  deadline: 2n,
  windowPolicyHash: registration.windowPolicyHash,
  maximumNominalFinalizeBy: 3n,
  absoluteEscapeDeadline: 4n,
  expectedPrimaryPolicyHash: hash,
} as const;
nativeRefundPurchaseAuthorizationPayload(1n, address, authorization);
nativeAllowlistRefundCharge(config.price, policy, proof);
prepareNativeAllowlistRefundPurchase(1n, address, config, policy, hash, authorization, {
  tokenData: "0x",
  platformSignature: "0x",
  artistSignature: "0x",
  priceFundingMaximum: 2n,
  revealFeeAllowance: 0n,
  proofGroups: [{ counterId: hash, proof }],
});
prepareNativeRefundClaim(address, registration.saleId, address, address);
// @ts-expect-error allowFree is a strict boolean
prepareNativeAllowlistRefundRegistration(1n, address, address, 1n, config, { ...policy, allowFree: "false" }, hash);
// @ts-expect-error prices are exact bigints
nativeAllowlistRefundCharge(2, policy, proof);
