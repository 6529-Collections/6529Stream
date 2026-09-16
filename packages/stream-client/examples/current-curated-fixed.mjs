import {
  prepareCuratedFixedRegistration,
  prepareCuratedPublicPurchase,
  prepareCuratedSelectionCommit,
  prepareCuratedSelectionReveal,
} from "../dist/current-curated-fixed.js";

/**
 * Offline illustrative encoding only. Supply a verified current carrier, live
 * nonce, complete published manifest proof, current reveal-fee allowance and
 * actual buyer coordinates. This function does not use RPC or send calls.
 */
export function preparePublicExample({
  chainId,
  adapter,
  owner,
  buyer,
  expectedNonce,
  configuration,
  selection,
  revealFeeAllowance,
}) {
  const registration = prepareCuratedFixedRegistration(
    chainId,
    adapter,
    owner,
    expectedNonce,
    configuration,
  );
  const purchase = prepareCuratedPublicPurchase(
    chainId,
    adapter,
    buyer,
    registration.expectedSaleId,
    configuration,
    selection,
    revealFeeAllowance,
  );
  return { registration, purchase };
}

/**
 * Offline illustrative COMMIT_REVEAL encoding. The returned reveal must be
 * inspected and simulated only in a later block with a live fee quote.
 */
export function prepareCommitRevealExample({
  chainId,
  adapter,
  owner,
  buyer,
  expectedNonce,
  configuration,
  selection,
  salt,
  revealFeeAllowance,
}) {
  const registration = prepareCuratedFixedRegistration(
    chainId,
    adapter,
    owner,
    expectedNonce,
    configuration,
  );
  const commit = prepareCuratedSelectionCommit(
    chainId,
    adapter,
    buyer,
    registration.expectedSaleId,
    configuration,
    selection.content,
    salt,
    selection.purchaseNonce,
  );
  const reveal = prepareCuratedSelectionReveal(
    chainId,
    adapter,
    buyer,
    registration.expectedSaleId,
    configuration,
    selection,
    salt,
    revealFeeAllowance,
  );
  return { registration, commit, reveal };
}
