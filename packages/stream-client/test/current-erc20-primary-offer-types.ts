import type { Address, Hex } from "../src/generated/contracts.js";
import type { Provider } from "ethers";
import type { ERC20PrimaryOfferConfiguration, ERC20PrimaryOfferAcceptance } from "../src/current-erc20-primary-offer-signing.js";
import {
  prepareERC20PrimaryOfferAcceptance, inspectERC20PrimaryOfferAcceptance,
  prepareERC20PrimaryOfferFunding, simulateERC20PrimaryOfferFunding,
  inspectCompletedERC20PrimaryOffer, inspectERC20PrimaryOfferFundingReceipt,
  prepareERC20PrimaryOfferRegistration, simulateERC20PrimaryOfferRegistration,
  prepareERC20PrimaryOfferBuyerRevocation, prepareERC20PrimaryOfferSellerRevocation,
  prepareERC20PrimaryOfferPaymentRevocation, prepareERC20PrimaryOfferTokenApproval,
  type ERC20SettlementCandidate, type ERC20PrimaryOfferFundingRoute,
  type PreparedERC20PrimaryOfferFunding,
} from "../src/current-erc20-primary-offer.js";
import { toSafeCall } from "../src/safe.js";

declare const provider: Provider;
declare const address: Address;
declare const hash: Hex;
declare const config: ERC20PrimaryOfferConfiguration;
declare const acceptance: ERC20PrimaryOfferAcceptance;
declare const candidate: ERC20SettlementCandidate;

const prepared = prepareERC20PrimaryOfferAcceptance(1n, address, address, address, address, address, config, acceptance);
const plan: PreparedERC20PrimaryOfferFunding = prepareERC20PrimaryOfferFunding(prepared, candidate, { kind: "payer" });
const caller: Address = plan.caller;
const nativeValue: bigint = plan.call.value;
const operation: 0 = toSafeCall(plan.call).operation;
void caller; void nativeValue; void operation;

const routes: readonly ERC20PrimaryOfferFundingRoute[] = [
  { kind: "payer" },
  { kind: "intent", intent: { payer: address, asset: address, maxAmount: 1n, saleRef: hash,
    expectedPrimaryPolicyHash: hash, nonce: hash, deadline: 1n }, signature: hash },
  { kind: "eip2612", permit: { deadline: 1n, v: 27n, r: hash, s: hash } },
  { kind: "permit2", permit: { nonce: 1n, deadline: 1n, signature: hash } },
];
for (const route of routes) prepareERC20PrimaryOfferFunding(prepared, candidate, route);
void inspectERC20PrimaryOfferAcceptance(provider, prepared, { blockTag: 1 });
void simulateERC20PrimaryOfferFunding(provider, plan, { blockTag: 1 });
void inspectCompletedERC20PrimaryOffer(provider, plan, { blockTag: 1 });
void inspectERC20PrimaryOfferFundingReceipt(provider, plan, { transactionHash: hash, execution: "safe" });
const registration = prepareERC20PrimaryOfferRegistration(1n, address, address, 1n, config, []);
void simulateERC20PrimaryOfferRegistration(provider, registration, { blockTag: 1 });
prepareERC20PrimaryOfferBuyerRevocation(1n, address, address, address, address, acceptance.offer, 2n, hash);
prepareERC20PrimaryOfferSellerRevocation(1n, address, address, config, acceptance.authorization, acceptance.sellerProof);
prepareERC20PrimaryOfferPaymentRevocation(1n, address, address, { payer: address, nonce: hash, deadline: 1n });
prepareERC20PrimaryOfferPaymentRevocation(1n, address, address, { payer: address, nonce: hash, deadline: 1n }, hash);
prepareERC20PrimaryOfferTokenApproval(address, address, address, 1n);

// @ts-expect-error A nonpayable route does not accept a native reveal-fee allowance.
prepareERC20PrimaryOfferFunding(prepared, candidate, { kind: "payer", revealFeeAllowance: 1n });
// @ts-expect-error Intent funding requires a separate payer signature.
prepareERC20PrimaryOfferFunding(prepared, candidate, { kind: "intent", intent: routes[1] });
// @ts-expect-error Integer signing/funding fields are bigint, never rounded JSON numbers.
prepareERC20PrimaryOfferTokenApproval(address, address, address, 1);
// @ts-expect-error Pinned reads require a concrete numeric block.
void inspectERC20PrimaryOfferAcceptance(provider, prepared, { blockTag: "latest" });
// @ts-expect-error This atomic ERC20 execution has no alternate purchase identity.
const purchaseId = plan.purchaseId;
void purchaseId;
