import type { Address, Hex } from "../src/generated/contracts.js";
import {
  normalizePrimaryOfferConfiguration,
  normalizePrimaryOfferSaleOffer,
  normalizePrimaryOfferSellerAuthorization,
  normalizePrimaryOfferSignature,
  primaryOfferBatchHashes,
  primaryOfferBuyerAuthorizationId,
  primaryOfferBuyerRevocationPayload,
  primaryOfferConfigurationHash,
  primaryOfferPurchaseId,
  primaryOfferSaleId,
  primaryOfferSaleOfferPayload,
  primaryOfferSellerAuthorizationPayload,
  primaryOfferSellerReplayDigest,
  primaryOfferSellerRevocationPayload,
  primaryOfferSigningSnapshot,
  type PrimaryOfferConfiguration,
  type PrimaryOfferSaleOffer,
  type PrimaryOfferSellerAuthorization,
} from "../src/current-primary-offer-signing.js";

declare const address: Address;
declare const hash: Hex;
declare const configuration: PrimaryOfferConfiguration;
declare const offer: PrimaryOfferSaleOffer;
declare const authorization: PrimaryOfferSellerAuthorization;

normalizePrimaryOfferConfiguration(configuration);
normalizePrimaryOfferSaleOffer(offer);
normalizePrimaryOfferSellerAuthorization(authorization);
normalizePrimaryOfferSignature({ authorizer: address, kind: 1n, signature: "0x" });
primaryOfferSaleId(1n, address, 2n, hash, 3n);
primaryOfferPurchaseId(1n, address, hash, address, 1n);
primaryOfferConfigurationHash(1n, address, configuration);
primaryOfferBatchHashes(address, address, "0x1234", hash);
primaryOfferSaleOfferPayload(1n, address, offer);
primaryOfferSellerAuthorizationPayload(1n, address, authorization);
const authorizationId = primaryOfferBuyerAuthorizationId(1n, address, offer);
const sellerDigest = primaryOfferSellerReplayDigest(1n, address, authorization);
primaryOfferBuyerRevocationPayload(1n, address, address, address, authorizationId);
primaryOfferSellerRevocationPayload(1n, address, address, sellerDigest);
primaryOfferSigningSnapshot(1n, address, address, address, configuration, hash,
  offer, authorization, "0x", hash);

// @ts-expect-error numeric identities remain bigint at the public boundary
primaryOfferSaleId(1, address, 2n, hash, 3n);
// @ts-expect-error signatures use explicit bigint kind
normalizePrimaryOfferSignature({ authorizer: address, kind: 1, signature: "0x" });
