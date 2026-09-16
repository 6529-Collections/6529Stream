import { getAddress } from "ethers";
import {
  inspectCompletedPrimaryOffer,
  inspectPrimaryOfferAcceptance,
  inspectPrimaryOfferBuyerRevocation,
  inspectPrimaryOfferRegistration,
  inspectPrimaryOfferSellerRevocation,
  inspectPrimaryOfferSignerConfiguration,
  inspectRegisteredPrimaryOffer,
  preparePrimaryOfferAcceptance,
  preparePrimaryOfferBuyerRevocation,
  preparePrimaryOfferDelegatedRefundClaim,
  preparePrimaryOfferRefundClaim,
  preparePrimaryOfferRegistration,
  preparePrimaryOfferSellerRevocation,
  preparePrimaryOfferSignerConfiguration,
  readPrimaryOfferCollectionSigner,
  readPrimaryOfferRefundCredit,
  simulatePrimaryOfferAcceptance,
  simulatePrimaryOfferBuyerRevocation,
  simulatePrimaryOfferRegistration,
  simulatePrimaryOfferSellerRevocation,
  simulatePrimaryOfferSignerConfiguration,
} from "../dist/current-primary-offer.js";
import { primaryOfferSigningSnapshot } from "../dist/current-primary-offer-signing.js";
import { createSafeCallPlan } from "../dist/safe-plan.js";
import { toSafeCall } from "../dist/safe.js";

/**
 * Turn one already-prepared action into a reviewable Safe operation-0 CALL.
 * Supply the exact target ABI selected from your own compiled ABI catalog.
 */
export function createPrimaryOfferSafeReview({
  chainId,
  title,
  intent,
  safe,
  prepared,
  targetAbi,
}) {
  if (getAddress(safe) !== getAddress(prepared.caller)) {
    throw new Error("The Safe must be the prepared action's actual caller");
  }
  const transaction = toSafeCall(prepared.call);
  const plan = createSafeCallPlan(chainId, title, [{
    safe,
    intent,
    call: prepared.call,
    abi: targetAbi,
  }]);
  return Object.freeze({ transaction, plan });
}

/** Prepare and simulate the owner's collection-signer configuration. */
export async function preparePrimaryOfferSignerExample({
  provider,
  deployment,
  owner,
  collectionId,
  signer,
  signerKind,
  evidenceHash,
  enabled,
  blockTag,
}) {
  const prepared = preparePrimaryOfferSignerConfiguration(
    deployment.adapter,
    owner,
    collectionId,
    signer,
    signerKind,
    evidenceHash,
    enabled,
  );
  const inspection = await inspectPrimaryOfferSignerConfiguration(
    provider,
    prepared,
    { blockTag },
  );
  await simulatePrimaryOfferSignerConfiguration(provider, prepared, { blockTag });
  return Object.freeze({ prepared, inspection });
}

/** Read the signer membership after its transaction is confirmed. */
export async function readPrimaryOfferSignerExample({
  provider,
  deployment,
  collectionId,
  signer,
  signerKind,
  blockTag,
}) {
  return readPrimaryOfferCollectionSigner(
    provider,
    deployment.adapter,
    collectionId,
    signer,
    signerKind,
    { blockTag },
  );
}

/** Prepare, inspect and simulate one owner registration at a concrete block. */
export async function preparePrimaryOfferRegistrationExample({
  provider,
  deployment,
  owner,
  expectedNonce,
  configuration,
  selectedProof,
  blockTag,
}) {
  const prepared = preparePrimaryOfferRegistration(
    deployment.chainId,
    deployment.adapter,
    owner,
    expectedNonce,
    configuration,
    selectedProof,
  );
  const inspection = await inspectPrimaryOfferRegistration(
    provider,
    prepared,
    { blockTag },
  );
  const simulatedSaleId = await simulatePrimaryOfferRegistration(
    provider,
    prepared,
    { blockTag },
  );
  return Object.freeze({ prepared, inspection, simulatedSaleId });
}

/** Verify the immutable stored sale after registration is confirmed. */
export async function readRegisteredPrimaryOfferExample({
  provider,
  preparedRegistration,
  blockTag,
}) {
  return inspectRegisteredPrimaryOffer(
    provider,
    preparedRegistration,
    { blockTag },
  );
}

/**
 * Build the original buyer 12-field and seller 24-field Sales payloads.
 * Sign `offerPayload` and `sellerPayload` outside this helper.
 */
export function preparePrimaryOfferSigningExample({
  deployment,
  configuration,
  saleId,
  offer,
  sellerAuthorization,
  selection,
}) {
  return primaryOfferSigningSnapshot(
    deployment.chainId,
    deployment.adapter,
    deployment.core,
    deployment.manager,
    configuration,
    saleId,
    offer,
    sellerAuthorization,
    selection.tokenData,
    selection.mintCommitment,
  );
}

/**
 * Reconstruct the signed packet, inspect live state and simulate the exact
 * executor-funded price-plus-fee CALL at one numeric block.
 */
export async function preparePrimaryOfferAcceptanceExample({
  provider,
  deployment,
  configuration,
  acceptance,
  blockTag,
}) {
  const prepared = preparePrimaryOfferAcceptance(
    deployment.chainId,
    deployment.adapter,
    deployment.core,
    deployment.manager,
    configuration,
    acceptance,
  );
  const inspection = await inspectPrimaryOfferAcceptance(
    provider,
    prepared,
    { blockTag },
  );
  const simulatedExecution = await simulatePrimaryOfferAcceptance(
    provider,
    prepared,
    { blockTag },
  );
  return Object.freeze({ prepared, inspection, simulatedExecution });
}

/**
 * Required post-transaction readback: sale completed, buyer TICKET consumed,
 * seller digest consumed, and seller digest not revoked.
 */
export async function inspectCompletedPrimaryOfferExample({
  provider,
  preparedAcceptance,
  blockTag,
}) {
  return inspectCompletedPrimaryOffer(
    provider,
    preparedAcceptance,
    { blockTag },
  );
}

/** Read the buyer-owned excess credit and prepare its direct claim CALL. */
export async function preparePrimaryOfferRefundExample({
  provider,
  deployment,
  buyer,
  saleId,
  recipient,
  blockTag,
}) {
  const adapter = deployment.adapter;
  const credit = await readPrimaryOfferRefundCredit(
    provider,
    adapter,
    saleId,
    buyer,
    { blockTag },
  );
  const prepared = preparePrimaryOfferRefundClaim(
    adapter,
    buyer,
    saleId,
    recipient,
  );
  return Object.freeze({ credit, prepared });
}

/** Prepare a delegate-triggered claim whose recipient remains the buyer. */
export function preparePrimaryOfferDelegatedRefundExample({
  deployment,
  delegate,
  saleId,
  buyer,
  witness,
}) {
  return preparePrimaryOfferDelegatedRefundClaim(
    deployment.adapter,
    delegate,
    saleId,
    buyer,
    witness,
  );
}

/** Inspect and simulate historical buyer TICKET revocation through Manager. */
export async function preparePrimaryOfferBuyerRevocationExample({
  provider,
  deployment,
  caller,
  offer,
  buyerKind,
  revocationSignature,
  blockTag,
}) {
  const prepared = preparePrimaryOfferBuyerRevocation(
    deployment.chainId,
    deployment.adapter,
    deployment.manager,
    deployment.ledger,
    caller,
    offer,
    buyerKind,
    revocationSignature,
  );
  const inspection = await inspectPrimaryOfferBuyerRevocation(
    provider,
    prepared,
    { blockTag },
  );
  const authorizationId = await simulatePrimaryOfferBuyerRevocation(
    provider,
    prepared,
    { blockTag },
  );
  return Object.freeze({ prepared, inspection, authorizationId });
}

/** Inspect and simulate historical seller-digest revocation on the carrier. */
export async function preparePrimaryOfferSellerRevocationExample({
  provider,
  deployment,
  caller,
  configuration,
  sellerAuthorization,
  proof,
  blockTag,
}) {
  const prepared = preparePrimaryOfferSellerRevocation(
    deployment.chainId,
    deployment.adapter,
    caller,
    configuration,
    sellerAuthorization,
    proof,
  );
  const inspection = await inspectPrimaryOfferSellerRevocation(
    provider,
    prepared,
    { blockTag },
  );
  await simulatePrimaryOfferSellerRevocation(provider, prepared, { blockTag });
  return Object.freeze({ prepared, inspection });
}
