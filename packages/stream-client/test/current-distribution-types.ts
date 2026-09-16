import type { Address, Hex } from "../src/generated/contracts.js";
import {
  OPERATOR_DISTRIBUTION_DELIVERY_MODE,
  buildOperatorDistributionManifest,
  operatorDistributionBatchForSlice,
  prepareDelegatedDistributionClaim,
  prepareOwnDistributionClaim,
} from "../src/current-distribution.js";

declare const address: Address, hash: Hex;
const artifact = buildOperatorDistributionManifest({
  context: { chainId: 1n, distributor: address, core: address, manager: address },
  collectionId: 1n, phaseId: hash, operator: address, supplyCounterId: hash, recipientCounterId: hash,
  perRecipientCap: 1n, deliveryMode: OPERATOR_DISTRIBUTION_DELIVERY_MODE.DIRECT, prepared: false,
  sliceQuantity: 1, tokens: [{ beneficiary: address, tokenData: "0x", mintCommitment: hash }], manifestCompletenessReviewed: true,
});
operatorDistributionBatchForSlice(artifact, 0, { expectedPolicyHash: hash, resolverData: "0x" });
prepareOwnDistributionClaim(1n, address, 1n, { collectionId: 1n, phaseId: hash, beneficiary: address }, address);
prepareDelegatedDistributionClaim(1n, address, address, 1n, { collectionId: 1n, phaseId: hash, beneficiary: address }, false, 0n);
// @ts-expect-error delivery mode is an exact bigint enum value
buildOperatorDistributionManifest({ context: artifact.context, collectionId: 1n, phaseId: hash, operator: address, supplyCounterId: hash, recipientCounterId: hash, perRecipientCap: 1n, deliveryMode: 0, prepared: false, sliceQuantity: 1, tokens: artifact.tokens, manifestCompletenessReviewed: true });
// @ts-expect-error delegated witness uses a strict boolean
prepareDelegatedDistributionClaim(1n, address, address, 1n, { collectionId: 1n, phaseId: hash, beneficiary: address }, "false", 0n);
