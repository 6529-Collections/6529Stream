import type { Address, Hex } from "../src/generated/contracts.js";
import {
  NATIVE_ALLOWLIST_PRICE_KIND,
  nativeAllowlistPriceMatrix,
  prepareNativeAllowlistPricePurchase,
  prepareNativeAllowlistPriceRegistration,
} from "../src/current-native-allowlist-price.js";
declare const address: Address, hash: Hex;
const config = { collectionId: 1n, phaseId: hash, kind: NATIVE_ALLOWLIST_PRICE_KIND.FIXED, minUnitPrice: 1n, maxUnitPrice: 1n,
  maxSaleQuantity: 1n, startsAt: 0n, endsAt: 0n, closeRule: 2n, mintPolicyHash: hash, primaryAssignmentHash: hash } as const;
const policy = { counterId: hash, allowFree: false } as const;
const proof = { maxCount: 1n, hasPriceOverride: false, priceOverride: 0n, proof: [hash] } as const;
const registration = prepareNativeAllowlistPriceRegistration(1n, address, address, 1n, config, policy);
const authorization = { saleId: registration.saleId, saleConfigHash: registration.configHash, payer: address, executor: address, recipient: address,
  artist: address, tokenDataHash: hash, mintCommitment: hash, executionNonce: 1n, nonce: hash, deadline: 1n,
  expectedPrimaryPolicyHash: hash, unitPrice: 1n } as const;
nativeAllowlistPriceMatrix(config, policy, 1n, proof);
prepareNativeAllowlistPricePurchase(1n, address, config, policy, authorization, { chosenUnitPrice: 1n, tokenData: "0x", platformSignature: "0x",
  artistSignature: "0x", revealFeeAllowance: 0n, proofGroups: [{ counterId: hash, proof }] });
// @ts-expect-error strict booleans prevent truthy allowFree coercion
prepareNativeAllowlistPriceRegistration(1n, address, address, 1n, config, { counterId: hash, allowFree: "false" });
// @ts-expect-error prices are exact bigints
nativeAllowlistPriceMatrix(config, policy, 1, proof);
