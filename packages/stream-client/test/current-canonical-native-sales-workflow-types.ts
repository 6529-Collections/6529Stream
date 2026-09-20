import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type {
  CanonicalNativeSalesAuthorization,
  CanonicalNativeSalesCall,
  CanonicalNativeSalesCoordinates,
  CanonicalNativeSalesPurchase,
  CanonicalNativeClaimPurchase,
  CanonicalNativeSalesSignature,
} from "../src/current-canonical-native-sales.js";
import { prepareCanonicalNativeSalesCall } from "../src/current-canonical-native-sales.js";
import {
  captureCanonicalNativeSales,
  inspectCanonicalNativeSales,
  reconcileCanonicalNativeSalesReceipt,
  simulateCanonicalNativeSales,
} from "../src/current-canonical-native-sales-workflow.js";
import type {
  CanonicalNativeSalesCapture,
  CanonicalNativeSalesDeployment,
  CanonicalNativeSalesReceiptOptions,
  CanonicalNativeSalesReconciliation,
} from "../src/current-canonical-native-sales-workflow.js";

declare const provider: Provider;
declare const deployment: CanonicalNativeSalesDeployment;
declare const coordinates: CanonicalNativeSalesCoordinates;
declare const caller: Address;
declare const hash: Hex;
declare const purchase: CanonicalNativeSalesPurchase;
declare const claimPurchase: CanonicalNativeClaimPurchase;
declare const authorization: CanonicalNativeSalesAuthorization;
declare const signature: CanonicalNativeSalesSignature;
declare const captured: CanonicalNativeSalesCapture;

const calls: readonly CanonicalNativeSalesCall[] = [
  prepareCanonicalNativeSalesCall(coordinates, caller, {
    family: "immediate", kind: "purchaseSigned", purchase, authorization, signature, value: 100n,
  }),
  prepareCanonicalNativeSalesCall(coordinates, caller, {
    family: "claim", kind: "purchasePublic", purchase: claimPurchase, value: 0n,
  }),
  prepareCanonicalNativeSalesCall(coordinates, caller, {
    family: "claim", kind: "claimRefund", saleId: hash, recipient: caller,
  }),
  prepareCanonicalNativeSalesCall(coordinates, caller, {
    family: "immediate", kind: "voidMintImmediateSaleAuthorization", authorization,
    authorizer: caller, authorizerKind: 2n, revocationSignature: "0x",
  }),
];

async function examples(): Promise<void> {
  for (const call of calls) {
    const capture = await captureCanonicalNativeSales(provider, deployment, call, { blockTag: 10 });
    const simulated = await simulateCanonicalNativeSales(provider, capture, { blockTag: 10, gasLimit: 5_000_000n });
    const result: CanonicalNativeSalesReconciliation = await reconcileCanonicalNativeSalesReceipt(
      provider, simulated.capture, hash, { execution: "safe", expectedSafeTxHash: hash, releaseKey: hash },
    );
    const amount: bigint | undefined = result.purchaseReceipt?.chargedAmount;
    const first: Hex | undefined = result.settlement?.firstSale.receiptHash;
    const raw: Hex = simulated.returnData;
    const revoked: Hex | null = result.revokedAuthorizationId;
    const refunded: bigint | null = result.refundedAmount;
    const authority: "original-adapter-or-manager-call-simulation" = capture.admissionAuthority;
    const count: number = capture.counters.length;
    // @ts-expect-error observations and plans are immutable
    capture.deployment.adapter.codeHash = hash;
    // @ts-expect-error no mutation of the ordered phase inventory
    capture.counters.push(capture.counters[0]!);
    // @ts-expect-error original literal caller remains immutable
    capture.prepared.caller = caller;
    // @ts-expect-error receipt integer precision is bigint
    const rounded: number | undefined = result.purchaseReceipt?.chargedAmount;
    void [amount, first, raw, revoked, refunded, authority, count, rounded];
  }
  const history = await inspectCanonicalNativeSales(provider, deployment, { saleId: hash, executionId: hash }, { blockTag: 11 });
  const status: bigint | null = history.status;
  const localReceipt = history.receipt;
  const direct: CanonicalNativeSalesReceiptOptions = { execution: "direct" };
  await reconcileCanonicalNativeSalesReceipt(provider, captured, hash, direct);
  // @ts-expect-error concrete block number is required
  await captureCanonicalNativeSales(provider, deployment, calls[0]!, { blockTag: "latest" });
  // @ts-expect-error original simulation requires explicitly reviewed gas
  await simulateCanonicalNativeSales(provider, captured, { blockTag: 10 });
  // @ts-expect-error simulation gas must preserve bigint precision
  await simulateCanonicalNativeSales(provider, captured, { blockTag: 10, gasLimit: 5000000 });
  // @ts-expect-error Safe verification requires an independently supplied hash
  await reconcileCanonicalNativeSalesReceipt(provider, captured, hash, { execution: "safe" });
  // @ts-expect-error delegatecall is outside the original transport
  await reconcileCanonicalNativeSalesReceipt(provider, captured, hash, { execution: "delegatecall" });
  // @ts-expect-error capture requires prepared original call, not arbitrary calldata
  await captureCanonicalNativeSales(provider, deployment, calls[0]!.call, { blockTag: 10 });
  // @ts-expect-error no entropy finality inferred from adapter completion
  const finality: boolean = localReceipt?.finalized;
  void [status, finality];
}
void examples;
