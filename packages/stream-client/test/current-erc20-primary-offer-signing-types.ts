import type { Address, Hex } from "../src/generated/contracts.js";
import type { PaymentIntent } from "../src/signing.js";
import type { PrimaryOfferSaleOffer, PrimaryOfferSellerAuthorization } from "../src/current-primary-offer-signing.js";
import {
  encodeERC20PrimaryOfferAcceptance, erc20PrimaryOfferPaymentIntentPayload,
  erc20PrimaryOfferSigningSnapshot, normalizeERC20PrimaryOfferAcceptance,
  normalizeERC20PrimaryOfferConfiguration, normalizeERC20PrimaryOfferSelection,
  type ERC20PrimaryOfferAcceptance, type ERC20PrimaryOfferConfiguration, type ERC20PrimaryOfferSelection,
} from "../src/current-erc20-primary-offer-signing.js";

declare const account: Address;
declare const hash: Hex;
declare const config: ERC20PrimaryOfferConfiguration;
declare const offer: PrimaryOfferSaleOffer;
declare const authorization: PrimaryOfferSellerAuthorization;
declare const acceptance: ERC20PrimaryOfferAcceptance;
declare const selection: ERC20PrimaryOfferSelection;
declare const payment: PaymentIntent;

normalizeERC20PrimaryOfferConfiguration(config);
erc20PrimaryOfferSigningSnapshot(1n, account, account, account, config, hash, offer, authorization, "0x", hash);
erc20PrimaryOfferPaymentIntentPayload(1n, config, hash, payment);
const saved = normalizeERC20PrimaryOfferAcceptance(acceptance);
encodeERC20PrimaryOfferAcceptance(saved);
normalizeERC20PrimaryOfferSelection(selection);
// @ts-expect-error sequence numbers retain uint256 precision as bigint
normalizeERC20PrimaryOfferSelection({ ...selection, executionNonce: 1 });
// @ts-expect-error there is no independent recipient in the direct-to-buyer profile
normalizeERC20PrimaryOfferSelection({ ...selection, recipient: account });
// @ts-expect-error configuration is flat and does not contain a native sale tuple
normalizeERC20PrimaryOfferConfiguration({ ...config, sale: {} });
// @ts-expect-error no native reveal fee is accepted
encodeERC20PrimaryOfferAcceptance({ ...acceptance, revealFeeAllowance: 1n });
// @ts-expect-error the frozen snapshot is read-only
saved.selection.content.proof.push(hash);
