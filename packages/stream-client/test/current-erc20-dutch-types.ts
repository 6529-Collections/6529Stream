import type { Address, Hex } from "../src/generated/contracts.js";
import type { PaymentIntent } from "../src/signing.js";
import type { CanonicalNativeSalesPurchase, CanonicalNativeSalesSignature } from "../src/current-canonical-native-sales.js";
import * as dutch from "../src/current-erc20-dutch.js";

declare const coordinates: dutch.ERC20DutchCoordinates;
declare const config: dutch.ERC20DutchConfiguration;
declare const record: dutch.ERC20DutchRecord;
declare const candidate: dutch.ERC20DutchCandidate;
declare const purchase: CanonicalNativeSalesPurchase;
declare const signature: CanonicalNativeSalesSignature;
declare const caller: Address;
declare const hash: Hex;
declare const intent: PaymentIntent;
declare const eip2612: dutch.ERC20DutchEIP2612Maximum;
declare const permit2: dutch.ERC20DutchPermit2Maximum;

const authorization = dutch.erc20DutchExpectedAuthorization(coordinates, config, purchase, {
  nonce: hash, deadline: 100n, unitPrice: 0n,
});
const execution: dutch.ERC20DutchExecution = { purchase, authorization, signature };
const request = dutch.prepareERC20DutchPaymentRequest(coordinates, hash, hash, 1n << 200n, execution);
const requests: readonly dutch.ERC20DutchRequest[] = [
  { kind: "settleERC20DutchSaleByPayer", request, value: 0n },
  { kind: "settleERC20DutchSaleWithIntent", request, intent, signature: "0x", value: 1n },
  { kind: "settleERC20DutchSaleWithEIP2612Permit", request, permit: eip2612, value: 1n },
  { kind: "settleERC20DutchSaleWithPermit2", request, permit: permit2, value: 1n },
  { kind: "claimRefund", saleId: hash, recipient: caller },
  { kind: "voidMintImmediateSaleAuthorization", authorization, authorizer: caller, authorizerKind: 2n, revocationSignature: "0x" },
];
for (const input of requests) {
  const prepared = dutch.prepareERC20DutchCall(coordinates, caller, input);
  const copied = dutch.normalizeERC20DutchCall(prepared);
  const suppliedFactsOnly: false = copied.factsVerified;
  const value: bigint = copied.call.value;
  if (copied.execution !== null) {
    const mint = dutch.erc20DutchMintBatch(copied, record);
    const amount: bigint = dutch.validateERC20DutchFunding(copied, candidate, 100n).amount;
    void [mint, amount];
  }
  void [suppliedFactsOnly, value];
}
const publicExecution = dutch.erc20DutchPublicExecution(purchase);
const preview = dutch.prepareERC20DutchPreview(coordinates, publicExecution);
const data: Hex = dutch.encodeERC20DutchExecution(execution);
const decoded = dutch.decodeERC20DutchExecution(data);
const transfer = dutch.erc20DutchPermit2Transfer(candidate, permit2);
const signedPermission: bigint = transfer.permit.permitted.amount;
const actualTransfer: bigint = transfer.transferDetails.requestedAmount;
const typed = dutch.erc20DutchPaymentIntentPayload(coordinates, intent);
dutch.prepareERC20DutchRead(caller, { kind: "dutchSaleRecord", saleId: hash });
dutch.prepareERC20DutchRead(caller, { kind: "saleConsentFacts", saleId: hash });
dutch.prepareERC20DutchRead(caller, { kind: "executionStatus", executionId: hash });
dutch.prepareERC20DutchRead(caller, { kind: "immediateSaleAuthorizationBinding", saleId: hash });

// @ts-expect-error Payment request max is an exact uint256 bigint
const rounded: dutch.ERC20DutchPaymentRequest = { ...request, maxAmount: 1 };
// @ts-expect-error fixed-payment permit does not include the required maximum wrapper
dutch.prepareERC20DutchCall(coordinates, caller, { kind: "settleERC20DutchSaleWithPermit2", request, permit: permit2.authorization, value: 0n });
// @ts-expect-error a paid callback is not a wallet entrypoint
dutch.prepareERC20DutchCall(coordinates, caller, { kind: "executeERC20PreRevenueSingleStep", candidate, executionData: data });
// @ts-expect-error caller cannot choose an arbitrary execution target
dutch.prepareERC20DutchCall(coordinates, caller, { kind: "settleERC20DutchSaleByPayer", request, value: 0n, to: caller });
// @ts-expect-error structural execution cannot carry a replacement signed authorization schema
const wrongExecution: dutch.ERC20DutchExecution = { purchase, authorization: intent, signature };
// @ts-expect-error old native-only getter is absent on ERC20 Dutch host
dutch.prepareERC20DutchRead(caller, { kind: "saleRecord", saleId: hash });
// @ts-expect-error native-only lifecycle selector is not an ERC20 read
dutch.prepareERC20DutchRead(caller, { kind: "nativeSaleLifecycleBinding", saleId: hash });
// @ts-expect-error native-only public binding selector is not an ERC20 read
dutch.prepareERC20DutchRead(caller, { kind: "publicNativeSaleBinding", saleId: hash });
// @ts-expect-error native-only active candidate selector is not an ERC20 read
dutch.prepareERC20DutchRead(caller, { kind: "activePublicNativeCandidate", executionId: hash });
// @ts-expect-error exact immutable decoded authorization
decoded.authorization.unitPrice = 1n;
// @ts-expect-error immutable maximum permission
transfer.permit.permitted.amount = 1n;

void [preview, signedPermission, actualTransfer, typed];
