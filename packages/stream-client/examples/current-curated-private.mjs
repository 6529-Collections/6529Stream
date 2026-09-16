import { ZeroAddress, id } from "ethers";
import {
  CurrentCuratedPrivateClient,
  curatedPrivateBatchHashes,
  curatedPrivateSaleAuthorizationPayload,
} from "../dist/current-curated-private.js";
import { curatedContentLeaf } from "../dist/current-curated-content.js";
import { toSafeCall } from "../dist/safe.js";

/**
 * Prepare an owner registration CALL and the complete 24-field Sales payload.
 * The caller supplies every deployment and sale coordinate; this function has
 * no default network and never signs or sends either artifact.
 */
export async function prepareCuratedPrivateRegistrationExample({
  provider,
  chainId,
  adapter,
  manager,
  owner,
  configuration,
  selectedProof,
  selection,
  executor,
  authorizationNonce,
  authorizationDeadline,
  blockTag = "latest",
}) {
  const client = new CurrentCuratedPrivateClient(provider, chainId, adapter);
  const registration = await client.prepareRegistration(
    owner,
    configuration,
    selectedProof,
    blockTag,
  );
  const batch = curatedPrivateBatchHashes(adapter, configuration.buyer, selection);
  const contentSelectionHash = curatedContentLeaf(
    chainId,
    adapter,
    registration.saleId,
    selection.content.contentId,
    selection.content.tokenDataHash,
  );
  const authorization = {
    chainId,
    saleAdapter: adapter,
    mintManager: manager,
    collectionId: configuration.sale.collectionId,
    phaseId: configuration.sale.phaseId,
    saleId: registration.saleId,
    saleKind: 5n,
    revenueClass: id("PRIMARY_SALE"),
    expectedPrimaryPolicyHash: configuration.sale.expectedPrimaryPolicyHash,
    primaryPolicyMode: 0n,
    ...batch,
    payer: configuration.buyer,
    executor,
    asset: ZeroAddress,
    unitPrice: configuration.sale.price,
    quantity: 1n,
    contentSelectionHash,
    policyHash: configuration.sale.mintPolicyHash,
    nonce: authorizationNonce,
    deadline: authorizationDeadline,
    finalizeBy: 0n,
  };
  const signingPayload = curatedPrivateSaleAuthorizationPayload(
    chainId,
    adapter,
    authorization,
  );
  return Object.freeze({
    registration,
    ownerSafeCall: toSafeCall(registration.call),
    authorization,
    signingPayload,
  });
}

/**
 * After registration and signature collection, prepare the actual executor's
 * payable purchase. Convert to a Safe CALL only when `executor` is that Safe.
 */
export async function prepareCuratedPrivatePurchaseExample({
  provider,
  chainId,
  adapter,
  executor,
  authorization,
  signature,
  selection,
  witness,
  revealFeeAllowance,
  blockTag = "latest",
}) {
  const client = new CurrentCuratedPrivateClient(provider, chainId, adapter);
  const prepared = await client.preparePurchase(executor, {
    authorization,
    signature,
    selection,
    witness,
    revealFeeAllowance,
  }, blockTag);
  return Object.freeze({
    prepared,
    executorSafeCall: toSafeCall(prepared.call),
  });
}
