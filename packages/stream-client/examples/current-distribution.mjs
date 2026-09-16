import { keccak256, toUtf8Bytes } from "ethers";
import {
  OPERATOR_DISTRIBUTION_DELIVERY_MODE,
  buildOperatorDistributionManifest,
  inspectAndPrepareOperatorDistribution,
  operatorDistributionManifestToJSON,
} from "../dist/current-distribution.js";

// Caller-supplied verified deployment facts only. This function reads a pinned block and prepares
// one unsigned CALL; it never signs, submits, invents a sale ID, or creates a payment credit.
export async function prepareReviewedDistribution(provider, deployment, orderedTokens, blockTag) {
  const artifact = buildOperatorDistributionManifest({
    context: deployment.context,
    collectionId: deployment.collectionId,
    phaseId: deployment.phaseId,
    operator: deployment.operator,
    supplyCounterId: deployment.supplyCounterId,
    recipientCounterId: deployment.recipientCounterId,
    perRecipientCap: deployment.perRecipientCap,
    deliveryMode: deployment.deliveryMode,
    prepared: deployment.prepared,
    sliceQuantity: deployment.sliceQuantity,
    tokens: orderedTokens,
    manifestCompletenessReviewed: true,
  });
  const prepared = await inspectAndPrepareOperatorDistribution(
    provider, artifact, deployment.sliceIndex,
    { resolverData: deployment.resolverData, gateData: deployment.gateData }, { blockTag },
  );
  return { canonicalManifestJSON: operatorDistributionManifestToJSON(artifact), prepared };
}

// Offline illustrative values. These are not deployed addresses and this block performs no RPC or send.
const h = value => keccak256(toUtf8Bytes(value));
const demo = buildOperatorDistributionManifest({
  context: {
    chainId: 1n,
    distributor: "0x1000000000000000000000000000000000000001",
    core: "0x2000000000000000000000000000000000000002",
    manager: "0x3000000000000000000000000000000000000003",
  },
  collectionId: 6529n,
  phaseId: h("reviewed-phase"),
  operator: "0x4000000000000000000000000000000000000004",
  supplyCounterId: h("distribution-supply"),
  recipientCounterId: h("distribution-recipient"),
  perRecipientCap: 2n,
  deliveryMode: OPERATOR_DISTRIBUTION_DELIVERY_MODE.FAILURE_ISOLATED,
  prepared: false,
  sliceQuantity: 2,
  tokens: [
    { beneficiary: "0x5000000000000000000000000000000000000005", tokenData: "0x0102", mintCommitment: h("artwork-1") },
    { beneficiary: "0x5000000000000000000000000000000000000005", tokenData: "0x0304", mintCommitment: h("artwork-2") },
  ],
  manifestCompletenessReviewed: true,
});
console.log({ manifestRoot: demo.program.slicesRoot, orderedBeneficiaries: demo.tokens.map(token => token.beneficiary),
  next: "Persist and review the canonical manifest, then prepare each slice against one concrete block." });
