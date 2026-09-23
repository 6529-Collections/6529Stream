import type { Address, Hex } from "../src/generated/contracts.js";
import type { NativeRefundPurchaseAuthorization } from "../src/current-native-allowlist-refund.js";
import {
  decodeCanonicalRefundAllowlistResolverData,
  nativeRefundAllowlistPurchaseRecordHash,
  nativeRefundOriginalPurchaseRecordHash,
  normalizeRefundPurchaseCapture,
  verifyCurrentRefundPurchaseRecord,
  type RefundPurchaseCapture,
} from "../src/current-refund-purchase-record.js";

declare const address: Address, hash: Hex, authorization: NativeRefundPurchaseAuthorization;
declare const capture: RefundPurchaseCapture;
normalizeRefundPurchaseCapture(capture);
nativeRefundOriginalPurchaseRecordHash(
  1n, address, hash, authorization, hash, capture, 1n, 0n, 2n, 3n,
);
nativeRefundAllowlistPurchaseRecordHash(hash, 0n, hash);
decodeCanonicalRefundAllowlistResolverData("0x1234");
verifyCurrentRefundPurchaseRecord({} as never, {
  chainId: 1n,
  adapter: address,
  purchaseId: hash,
  saleId: hash,
  payer: address,
});
// @ts-expect-error chain IDs preserve full uint256 width as bigint
verifyCurrentRefundPurchaseRecord({} as never, { chainId: 1, adapter: address, purchaseId: hash, saleId: hash, payer: address });
