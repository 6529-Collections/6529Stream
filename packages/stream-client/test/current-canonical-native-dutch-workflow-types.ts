import type { Provider } from "ethers";
import type { Hex } from "../src/generated/contracts.js";
import type { CanonicalNativeDutchCall } from "../src/current-canonical-native-dutch.js";
import { captureCanonicalNativeDutch, simulateCanonicalNativeDutch, reconcileCanonicalNativeDutchReceipt, inspectCanonicalNativeDutch,
  type CanonicalNativeDutchDeployment, type CanonicalNativeDutchCapture } from "../src/current-canonical-native-dutch-workflow.js";

declare const provider: Provider;
declare const deployment: CanonicalNativeDutchDeployment;
declare const prepared: CanonicalNativeDutchCall;
declare const capture: CanonicalNativeDutchCapture;
declare const hash: Hex;

void captureCanonicalNativeDutch(provider, deployment, prepared, { blockTag: 10 });
void simulateCanonicalNativeDutch(provider, capture, { blockTag: 11, gasLimit: 5_000_000n });
void inspectCanonicalNativeDutch(provider, deployment, { saleId: hash, executionId: hash }, { blockTag: 12 });
void reconcileCanonicalNativeDutchReceipt(provider, capture, hash, { execution: "direct" });
void reconcileCanonicalNativeDutchReceipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash, releaseKey: hash });
// @ts-expect-error Safe receipt requires independent transaction hash.
void reconcileCanonicalNativeDutchReceipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error Concrete block number is required.
void simulateCanonicalNativeDutch(provider, capture, { blockTag: "latest", gasLimit: 1n });
// @ts-expect-error Returned capture is immutable.
capture.refundCredit = 0n;
// @ts-expect-error Ordinary CALL receipt cannot select delegatecall.
void reconcileCanonicalNativeDutchReceipt(provider, capture, hash, { execution: "delegatecall" });
