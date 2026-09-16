import {
  prepareNativeAllowlistDutchPurchase,
  prepareNativeAllowlistDutchRegistration,
} from "../dist/current-native-allowlist-dutch.js";

/**
 * Offline illustrative encoding only. Callers must supply a verified current
 * deployment, live nonce, registration facts, real proofs and real signatures.
 * This function does not connect to RPC or send a transaction.
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
  assignmentHash,
  currentPrimaryPolicyHash,
  counterId,
  tokenDataHash,
  mintCommitment,
  proofSibling,
}) {
  const config = {
    collectionId: 1n,
    phaseId,
    schedule: {
      startPrice: 100n,
      restingPrice: 20n,
      startTime: 1n,
      endTime: 101n,
      decayKind: 0n,
      stepSeconds: 0n,
      stepAmount: 0n,
    },
    maxSaleQuantity: 10n,
    closesAt: 101n,
    declaredFree: false,
    mintPolicyHash,
  };
  const hashFacts = {
    expectedPrimaryPolicyHash: registrationPolicyHash,
    primaryAssignmentHash: assignmentHash,
  };
  const registration = prepareNativeAllowlistDutchRegistration(
    chainId,
    adapter,
    owner,
    1n,
    config,
    counterId,
    hashFacts,
  );
  const authorization = {
    saleId: registration.saleId,
    saleConfigHash: registration.configHash,
    payer,
    executor: payer,
    recipient,
    artist,
    tokenDataHash,
    mintCommitment,
    executionNonce: 1n,
    nonce: phaseId,
    deadline: 2n ** 64n - 1n,
    expectedPrimaryPolicyHash: currentPrimaryPolicyHash,
    unitPrice: 100n,
  };
  const purchase = prepareNativeAllowlistDutchPurchase(
    chainId,
    adapter,
    config,
    counterId,
    hashFacts,
    authorization,
    {
      tokenData: "0x",
      platformSignature: "0x",
      artistSignature: "0x",
      saleFundingMaximum: 100n,
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
