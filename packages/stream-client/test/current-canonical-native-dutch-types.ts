import type { Address, Hex } from "../src/generated/contracts.js";
import * as dutch from "../src/current-canonical-native-dutch.js";
import type { CanonicalNativeSalesHistoricalBinding } from "../src/current-canonical-native-sales.js";

declare const coordinates: dutch.CanonicalNativeDutchCoordinates;
declare const config: dutch.CanonicalNativeDutchConfiguration;
declare const record: dutch.CanonicalNativeDutchRecord;
declare const purchase: dutch.CanonicalNativeDutchPurchase;
declare const signature: dutch.CanonicalNativeDutchSignature;
declare const caller: Address;
declare const hash: Hex;
declare const binding: CanonicalNativeSalesHistoricalBinding;

const authorization = dutch.canonicalNativeDutchExpectedAuthorization(coordinates, config, purchase, {
  nonce: hash, deadline: 100n, unitPrice: 0n,
});
const signed = dutch.prepareCanonicalNativeDutchCall(coordinates, caller, {
  kind: "purchaseSigned", purchase, authorization, signature, value: 1n << 100n,
});
const publicCall = dutch.prepareCanonicalNativeDutchCall(coordinates, caller, {
  kind: "purchasePublic", purchase, value: 0n,
});
const refund = dutch.prepareCanonicalNativeDutchCall(coordinates, caller, {
  kind: "claimRefund", saleId: hash, recipient: caller,
});
const revoke = dutch.prepareCanonicalNativeDutchCall(coordinates, caller, {
  kind: "voidMintImmediateSaleAuthorization", authorization, authorizer: caller,
  authorizerKind: 2n, revocationSignature: "0x",
});
const normalized = dutch.normalizeCanonicalNativeDutchCall(signed);
const structural: false = normalized.factsVerified;
const price: bigint = dutch.canonicalNativeDutchPrice(config, 1n << 65n, 0n, {
  hasOverride: true, overridePrice: 0n,
}).amount;
const credit: bigint = dutch.canonicalNativeDutchFunding(100n, 10n, 50n).revealCredit;
const batch = dutch.canonicalNativeDutchMintBatch(signed, record);
const recipients: readonly Address[] = batch.initialRecipients;
const digest: Hex = dutch.canonicalNativeDutchAuthorizationPayload(coordinates, authorization).digest;
dutch.validateCanonicalNativeDutchHistoricalBinding(revoke, binding);
dutch.prepareCanonicalNativeDutchPreview(publicCall);
dutch.prepareCanonicalNativeDutchRead(caller, { kind: "saleConfigurationHash", configuration: config });
dutch.prepareCanonicalNativeDutchRead(caller, { kind: "schedulePrice", saleId: hash });
dutch.prepareCanonicalNativeDutchRead(caller, { kind: "executionReceipt", executionId: hash });
const decoded: dutch.CanonicalNativeDutchRecord = dutch.decodeCanonicalNativeDutchRecord(dutch.encodeCanonicalNativeDutchRecord(record));

// @ts-expect-error exact uint256 native value requires bigint
dutch.prepareCanonicalNativeDutchCall(coordinates, caller, { kind: "purchasePublic", purchase, value: 1 });
// @ts-expect-error old family discriminant is not part of the separate Dutch API
dutch.prepareCanonicalNativeDutchCall(coordinates, caller, { family: "immediate", kind: "purchasePublic", purchase, value: 0n });
// @ts-expect-error public mode has no seller signature fields
dutch.prepareCanonicalNativeDutchCall(coordinates, caller, { kind: "purchasePublic", purchase, signature, value: 0n });
// @ts-expect-error governance/owner registration is outside this operational caller scope
dutch.prepareCanonicalNativeDutchCall(coordinates, caller, { kind: "registerSale", configuration: config });
// @ts-expect-error refund never accepts a caller-selected transaction value
dutch.prepareCanonicalNativeDutchCall(coordinates, caller, { kind: "claimRefund", saleId: hash, recipient: caller, value: 0n });
// @ts-expect-error the immutable schedule uses full exact integer widths
const roundedSchedule: dutch.CanonicalNativeDutchSchedule = { ...config.schedule, endTime: 100 };
// @ts-expect-error reviewed caller is immutable
normalized.caller = caller;
// @ts-expect-error nested retained configuration is immutable
decoded.sale.config.signer.revision = 2n;
// @ts-expect-error full ordered mint recipients cannot be changed
batch.beneficiaries.push(caller);
// @ts-expect-error no supplied-facts helper claims observed admission
const verified: true = normalized.factsVerified;
// @ts-expect-error schedule reads take saleId, not executionId
dutch.prepareCanonicalNativeDutchRead(caller, { kind: "schedulePrice", executionId: hash });

void [refund, structural, price, credit, recipients, digest];
