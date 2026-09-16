import {
  NATIVE_ALLOWLIST_PRICE_KIND,
  prepareNativeAllowlistPricePurchase,
  prepareNativeAllowlistPriceRegistration,
} from "../dist/current-native-allowlist-price.js";

/**
 * Offline illustrative encoding only. Callers must supply a verified current
 * deployment, live nonce, real proofs and real signatures. This function does
 * not connect to RPC or send a transaction.
 */
export function prepareExample({ chainId, adapter, owner, payer, recipient, artist, phaseId, mintPolicyHash,
  assignmentHash, counterId, tokenDataHash, mintCommitment, expectedPrimaryPolicyHash, proofSibling }) {
  const config = { collectionId: 1n, phaseId, kind: NATIVE_ALLOWLIST_PRICE_KIND.FIXED, minUnitPrice: 100n,
    maxUnitPrice: 100n, maxSaleQuantity: 10n, startsAt: 0n, endsAt: 0n, closeRule: 2n,
    mintPolicyHash, primaryAssignmentHash: assignmentHash };
  const policy = { counterId, allowFree: false };
  const registration = prepareNativeAllowlistPriceRegistration(chainId, adapter, owner, 1n, config, policy);
  const authorization = { saleId: registration.saleId, saleConfigHash: registration.configHash, payer, executor: payer,
    recipient, artist, tokenDataHash, mintCommitment, executionNonce: 1n, nonce: phaseId, deadline: 2n ** 64n - 1n,
    expectedPrimaryPolicyHash, unitPrice: 100n };
  const purchase = prepareNativeAllowlistPricePurchase(chainId, adapter, config, policy, authorization, {
    chosenUnitPrice: 100n, tokenData: "0x", platformSignature: "0x", artistSignature: "0x", revealFeeAllowance: 0n,
    proofGroups: [{ counterId, proof: { maxCount: 1n, hasPriceOverride: false, priceOverride: 0n, proof: [proofSibling] } }],
  });
  return { registration, purchase };
}
