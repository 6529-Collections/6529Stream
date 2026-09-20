import type { Address, Hex } from "../src/generated/contracts.js";
import {
  prepareRevenueEscrowCall,
  prepareRevenueEscrowGovernanceBatch,
  normalizeRevenueEscrowDocument,
  revenueEscrowConsentTypedData,
  type RevenueEscrowCoordinates,
  type RevenueEscrowDocument,
  type RevenueEscrowRecoveryTerms,
  type RevenueEscrowTransition,
} from "../src/current-revenue-escrow.js";
import type { MintFallbackGovernanceWindow } from "../src/current-mint-fallback.js";

declare const address: Address;
declare const hash: Hex;
declare const coordinates: RevenueEscrowCoordinates;
declare const document: RevenueEscrowDocument;
declare const terms: RevenueEscrowRecoveryTerms;
declare const transition: RevenueEscrowTransition;
declare const window: MintFallbackGovernanceWindow;

const call = prepareRevenueEscrowCall(coordinates, address, {
  kind: "recordEscrowRecoveryConsent", recoveryId: hash, nonce: hash,
});
const governed = prepareRevenueEscrowCall(coordinates, address, { kind: "scheduleEscrowRecovery", terms });
const batch = prepareRevenueEscrowGovernanceBatch(governed, address, transition, 0n, window);
normalizeRevenueEscrowDocument(document);
revenueEscrowConsentTypedData(coordinates, { account: address, recoveryId: hash, nonce: hash, deadline: 0n });
// @ts-expect-error bigint nonce required
prepareRevenueEscrowGovernanceBatch(governed, address, transition, 0, window);
// @ts-expect-error setup/credit transport excluded
prepareRevenueEscrowCall(coordinates, address, { kind: "creditNative" });
// @ts-expect-error missing original terms
prepareRevenueEscrowCall(coordinates, address, { kind: "scheduleEscrowRecovery", recoveryId: hash });
// @ts-expect-error submitted consent requires explicit signature, including empty if chosen
prepareRevenueEscrowCall(coordinates, address, { kind: "submitEscrowRecoveryConsent", consent: { account: address, recoveryId: hash, nonce: hash, deadline: 0n } });
// @ts-expect-error immutable prepared transport
call.call.value = 1n;
// @ts-expect-error original committed statement is immutable
batch.window.manifestHash = hash;
// @ts-expect-error readonly original entry inventory
document.oldEntries.push({ account: address, sharePpm: 1n, labelId: hash });
