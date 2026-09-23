import {
  prepareNativeAllowlistRefundPurchase,
  prepareNativeAllowlistRefundRegistration,
} from "../dist/current-native-allowlist-refund.js";

/**
 * Offline illustrative encoding only. Callers must supply a verified current
 * deployment, live nonce and policy readback, ordered proofs and real
 * signatures. This function does not connect to RPC or send a transaction.
 */
export function prepareExample({
  chainId,
  adapter,
  owner,
  payer,
  recipient,
  artist,
  phaseId,
  mintPolicyHash,
  registrationPolicyHash,
  currentPrimaryPolicyHash,
  counterId,
  tokenDataHash,
  mintCommitment,
  proofSibling,
}) {
  const config = {
    collectionId: 1n,
    phaseId,
    price: 100n,
    maxSaleQuantity: 10n,
    startsAt: 1n,
    endsAt: 101n,
    refundWindowSeconds: 3_600n,
    finalizationWindowSeconds: 86_400n,
    primaryPolicyMode: 1n,
    mintPolicyHash,
  };
  const policy = {
    counterId,
    allowFree: false,
  };
  const registration = prepareNativeAllowlistRefundRegistration(
    chainId,
    adapter,
    owner,
    1n,
    config,
    policy,
    registrationPolicyHash,
  );
  const authorization = {
    saleId: registration.saleId,
    saleConfigHash: registration.configHash,
    payer,
    recipient,
    artist,
    tokenDataHash,
    mintCommitment,
    purchaseNonce: 1n,
    nonce: phaseId,
    price: config.price,
    deadline: 2n ** 64n - 1n,
    windowPolicyHash: registration.windowPolicyHash,
    maximumNominalFinalizeBy: 2n ** 64n - 1n,
    absoluteEscapeDeadline: 2n ** 64n - 1n,
    expectedPrimaryPolicyHash: currentPrimaryPolicyHash,
  };
  const purchase = prepareNativeAllowlistRefundPurchase(
    chainId,
    adapter,
    config,
    policy,
    registrationPolicyHash,
    authorization,
    {
      tokenData: "0x",
      platformSignature: "0x",
      artistSignature: "0x",
      priceFundingMaximum: 100n,
      revealFeeAllowance: 0n,
      proofGroups: [{
        counterId,
        proof: {
          maxCount: 1n,
          hasPriceOverride: false,
          priceOverride: 0n,
          proof: [proofSibling],
        },
      }],
    },
  );
  return { registration, purchase };
}
