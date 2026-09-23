import type { Address, Hex } from "../src/generated/contracts.js";
import {
  canonicalNativeSalesAllowlistPrice,
  canonicalNativeSalesAuthorizationPayload,
  canonicalNativeSalesExpectedAuthorization,
  canonicalNativeSalesMintBatch,
  canonicalNativeSalesPrice,
  canonicalNativeSalesRevocationPayload,
  decodeCanonicalNativeSalesReceipt,
  encodeCanonicalNativeSalesAllowlistProofs,
  normalizeCanonicalNativeSalesCall,
  prepareCanonicalNativeSalesCall,
  prepareCanonicalNativeSalesPreview,
  prepareCanonicalNativeSalesRead,
} from "../src/current-canonical-native-sales.js";
import type {
  CanonicalNativeSalesAuthorization,
  CanonicalNativeSalesConfiguration,
  CanonicalNativeClaimConfiguration,
  CanonicalNativeSalesCoordinates,
  CanonicalNativeSalesCounterObservation,
  CanonicalNativeSalesPurchase,
  CanonicalNativeClaimPurchase,
  CanonicalNativeSalesRecord,
  CanonicalNativeSalesRequest,
  CanonicalNativeSalesSignature,
} from "../src/current-canonical-native-sales.js";

declare const coordinates: CanonicalNativeSalesCoordinates;
declare const actor: Address;
declare const hash: Hex;
declare const config: CanonicalNativeSalesConfiguration;
declare const claimConfig: CanonicalNativeClaimConfiguration;
declare const purchase: CanonicalNativeSalesPurchase;
declare const claimPurchase: CanonicalNativeClaimPurchase;
declare const authorization: CanonicalNativeSalesAuthorization;
declare const signature: CanonicalNativeSalesSignature;
declare const record: CanonicalNativeSalesRecord;
declare const counters: readonly CanonicalNativeSalesCounterObservation[];

const request: CanonicalNativeSalesRequest = {
  family: "immediate",
  kind: "purchaseSigned",
  purchase,
  authorization,
  signature,
  value: 100n,
};
const signed = prepareCanonicalNativeSalesCall(coordinates, actor, request);
const publicClaim = prepareCanonicalNativeSalesCall(coordinates, actor, {
  family: "claim", kind: "purchasePublic", purchase: claimPurchase, value: 0n,
});
const signedClaim = prepareCanonicalNativeSalesCall(coordinates, actor, {
  family: "claim", kind: "purchaseSigned", purchase: claimPurchase, authorization, signature, value: 0n,
});
const refund = prepareCanonicalNativeSalesCall(coordinates, actor, {
  family: "immediate", kind: "claimRefund", saleId: hash, recipient: actor,
});
const revoke = prepareCanonicalNativeSalesCall(coordinates, actor, {
  family: "claim", kind: "voidMintImmediateSaleAuthorization", authorization,
  authorizer: actor, authorizerKind: 2n, revocationSignature: "0x",
});
const prepared = normalizeCanonicalNativeSalesCall(signed);
const verified: false = prepared.factsVerified;
const batch = canonicalNativeSalesMintBatch(prepared, record);
const noAuthorizer: Address = batch.authorizer;
const payload = canonicalNativeSalesAuthorizationPayload(coordinates,
  canonicalNativeSalesExpectedAuthorization(coordinates, "immediate", config, purchase,
    { nonce: hash, deadline: 1n, unitPrice: 100n }));
const revokePayload = canonicalNativeSalesRevocationPayload(coordinates, authorization);
const feeAmount: bigint = canonicalNativeSalesPrice("claim", claimConfig, claimPurchase, 0n,
  canonicalNativeSalesAllowlistPrice(coordinates, claimConfig.sale, claimPurchase.mint, counters)).amount;
const proofs: Hex = encodeCanonicalNativeSalesAllowlistProofs([[{
  maxCount: 1n, hasPriceOverride: true, priceOverride: 0n, proof: [],
}]]);
const preview = prepareCanonicalNativeSalesPreview(prepared);
const historical = prepareCanonicalNativeSalesRead(actor, "claim", { kind: "executionReceipt", executionId: hash });
const receipt = decodeCanonicalNativeSalesReceipt(hash);
const exactAmount: bigint = receipt.chargedAmount;

// @ts-expect-error claim calldata uses the original wrapper, not the base mint tuple
prepareCanonicalNativeSalesCall(coordinates, actor, { family: "claim", kind: "purchasePublic", purchase, value: 0n });
// @ts-expect-error immediate calldata does not use the claim wrapper
prepareCanonicalNativeSalesCall(coordinates, actor, { family: "immediate", kind: "purchasePublic", purchase: claimPurchase, value: 0n });
// @ts-expect-error native value must preserve exact uint256 precision
prepareCanonicalNativeSalesCall(coordinates, actor, { family: "immediate", kind: "purchasePublic", purchase, value: 1 });
// @ts-expect-error operation scope excludes registration and owner/governance administration
prepareCanonicalNativeSalesCall(coordinates, actor, { family: "immediate", kind: "registerSale", config });
// @ts-expect-error refund carries no native transaction value
prepareCanonicalNativeSalesCall(coordinates, actor, { family: "claim", kind: "claimRefund", saleId: hash, recipient: actor, value: 0n });
// @ts-expect-error revocation uses its separate original proof rather than a purchase signature field
prepareCanonicalNativeSalesCall(coordinates, actor, { family: "immediate", kind: "voidMintImmediateSaleAuthorization", authorization, authorizer: actor, authorizerKind: 1n, signature });
// @ts-expect-error immutable reviewed actor
prepared.caller = actor;
// @ts-expect-error no mutable batch recipient array
batch.initialRecipients.push(actor);
// @ts-expect-error all receipt accounting values are exact bigint
const roundedAmount: number = receipt.chargedAmount;
// @ts-expect-error statement reads use an execution ID rather than a sale ID
prepareCanonicalNativeSalesRead(actor, "claim", { kind: "executionReceipt", saleId: hash });
// @ts-expect-error signatures retain immutable original nonce
payload.message.nonce = hash;

void [publicClaim, signedClaim, refund, revoke, verified, noAuthorizer, revokePayload,
  feeAmount, proofs, preview, historical, exactAmount, roundedAmount];
