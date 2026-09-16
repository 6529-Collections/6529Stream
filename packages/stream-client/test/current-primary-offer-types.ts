import type { Address, Hex } from "../src/generated/contracts.js";
import type {
  PrimaryOfferConfiguration,
  PrimaryOfferSaleOffer,
  PrimaryOfferSellerAuthorization,
  PrimaryOfferSignature,
} from "../src/current-primary-offer-signing.js";
import type { CuratedSelection } from "../src/current-curated-content.js";
import {
  inspectPrimaryOfferAcceptance,
  preparePrimaryOfferAcceptance,
  preparePrimaryOfferBuyerRevocation,
  preparePrimaryOfferDelegatedRefundClaim,
  preparePrimaryOfferRegistration,
  preparePrimaryOfferSellerRevocation,
  preparePrimaryOfferSignerConfiguration,
} from "../src/current-primary-offer.js";

declare const address: Address;
declare const hash: Hex;
declare const configuration: PrimaryOfferConfiguration;
declare const offer: PrimaryOfferSaleOffer;
declare const authorization: PrimaryOfferSellerAuthorization;
declare const signature: PrimaryOfferSignature;
declare const selection: CuratedSelection;

preparePrimaryOfferSignerConfiguration(address, address, 1n, address, 1n, hash, true);
preparePrimaryOfferRegistration(1n, address, address, 1n, configuration, []);
const acceptance = preparePrimaryOfferAcceptance(
  1n,
  address,
  address,
  address,
  configuration,
  {
    offer,
    buyerProof: signature,
    sellerAuthorization: authorization,
    sellerProof: signature,
    selection,
    signerDelegation: { walletWide: false, index: 0n },
    executorDelegation: { walletWide: true, index: 1n },
    revealFeeAllowance: 0n,
  },
);
preparePrimaryOfferBuyerRevocation(1n, address, address, address, address, offer, 1n, "0x");
preparePrimaryOfferSellerRevocation(1n, address, address, configuration, authorization, signature);
preparePrimaryOfferDelegatedRefundClaim(
  address,
  address,
  hash,
  address,
  { walletWide: true, index: 1n },
);

declare const provider: Parameters<typeof inspectPrimaryOfferAcceptance>[0];
inspectPrimaryOfferAcceptance(provider, acceptance, { blockTag: 1 });

preparePrimaryOfferAcceptance(1n, address, address, address, configuration, {
  offer,
  buyerProof: signature,
  sellerAuthorization: authorization,
  sellerProof: signature,
  selection,
  signerDelegation: { walletWide: false, index: 0n },
  executorDelegation: { walletWide: false, index: 0n },
  // @ts-expect-error reveal fee allowance is an exact bigint
  revealFeeAllowance: 0,
});
// @ts-expect-error signer enabled state is a strict boolean
preparePrimaryOfferSignerConfiguration(address, address, 1n, address, 1n, hash, "true");
