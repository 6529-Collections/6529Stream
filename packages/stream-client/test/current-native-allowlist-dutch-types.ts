import type { Address, Hex } from "../src/generated/contracts.js";
import {
  nativeAllowlistDutchCharge,
  nativeDutchAuthorizationPayload,
  prepareNativeAllowlistDutchPurchase,
  prepareNativeAllowlistDutchRegistration,
  prepareNativeDutchRefund,
} from "../src/current-native-allowlist-dutch.js";

declare const address: Address, hash: Hex;
const schedule = {
  startPrice: 2n,
  restingPrice: 1n,
  startTime: 1n,
  endTime: 2n,
  decayKind: 0n,
  stepSeconds: 0n,
  stepAmount: 0n,
} as const;
const config = {
  collectionId: 1n,
  phaseId: hash,
  schedule,
  maxSaleQuantity: 1n,
  closesAt: 2n,
  declaredFree: false,
  mintPolicyHash: hash,
} as const;
const facts = { expectedPrimaryPolicyHash: hash, primaryAssignmentHash: hash } as const;
const proof = {
  maxCount: 1n,
  hasPriceOverride: false,
  priceOverride: 0n,
  proof: [hash],
} as const;
const registration = prepareNativeAllowlistDutchRegistration(
  1n,
  address,
  address,
  1n,
  config,
  hash,
  facts,
);
const authorization = {
  saleId: registration.saleId,
  saleConfigHash: registration.configHash,
  payer: address,
  executor: address,
  recipient: address,
  artist: address,
  tokenDataHash: hash,
  mintCommitment: hash,
  executionNonce: 1n,
  nonce: hash,
  deadline: 2n,
  expectedPrimaryPolicyHash: hash,
  unitPrice: 2n,
} as const;
nativeDutchAuthorizationPayload(1n, address, authorization);
nativeAllowlistDutchCharge(2n, false, proof);
prepareNativeAllowlistDutchPurchase(1n, address, config, hash, facts, authorization, {
  tokenData: "0x",
  platformSignature: "0x",
  artistSignature: "0x",
  saleFundingMaximum: 2n,
  revealFeeAllowance: 0n,
  proofGroups: [{ counterId: hash, proof }],
});
prepareNativeDutchRefund(address, hash, address, address);
// @ts-expect-error declaredFree is a strict boolean
prepareNativeAllowlistDutchRegistration(1n, address, address, 1n, { ...config, declaredFree: "false" }, hash, facts);
// @ts-expect-error Dutch schedule prices are exact bigints
nativeAllowlistDutchCharge(2, false, proof);
