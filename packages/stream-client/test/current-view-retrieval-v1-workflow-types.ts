import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import {
  previewCurrentViewRetrievalV1, captureCurrentViewRetrievalV1, simulateCurrentViewRetrievalV1,
  reconcileCurrentViewRetrievalV1Receipt, inspectCurrentViewRetrievalV1History,
  inspectCurrentViewRetrievalV1Current, observeCurrentViewRetrievalV1Refusal,
  type CurrentViewRetrievalV1Deployment, type CurrentViewRetrievalV1HistoryDeployment,
  type CurrentViewRetrievalV1Capture, type CurrentViewRetrievalV1ReceiptOptions,
  type CurrentViewRetrievalV1RetainedPayload,
} from "../src/current-view-retrieval-v1-workflow.js";
import type { CurrentViewRetrievalV1Request } from "../src/current-view-retrieval-v1.js";

declare const provider: Provider;
declare const deployment: CurrentViewRetrievalV1Deployment;
declare const historyDeployment: CurrentViewRetrievalV1HistoryDeployment;
declare const request: CurrentViewRetrievalV1Request;
declare const caller: Address;
declare const recordHash: Hex;
declare const reasonHash: Hex;
declare const signature: Hex;
declare const transactionHash: Hex;
declare const retainedPayload: CurrentViewRetrievalV1RetainedPayload;
declare const capture: CurrentViewRetrievalV1Capture;

async function consume() {
  const preview = await previewCurrentViewRetrievalV1(provider, deployment, caller, request, { blockTag: 10, gasLimit: 10_000_000n });
  const unsigned: false = preview.signatureVerified;
  const noStore: false = preview.storeAvailabilityChecked;
  void unsigned; void noStore;
  const publish = await captureCurrentViewRetrievalV1(provider, deployment, caller, { kind: "publish", request, signature }, { blockTag: 10, gasLimit: 10_000_000n });
  const revoke = await captureCurrentViewRetrievalV1(provider, deployment, caller, { kind: "revoke", recordHash, reasonHash },
    { blockTag: 10, gasLimit: 10_000_000n, retainedPayload });
  await simulateCurrentViewRetrievalV1(provider, publish, { blockTag: 11 });
  await simulateCurrentViewRetrievalV1(provider, revoke, { blockTag: 11 });
  const options: CurrentViewRetrievalV1ReceiptOptions = { execution: "safe", expectedSafeTxHash: recordHash };
  const result = await reconcileCurrentViewRetrievalV1Receipt(provider, publish, transactionHash, options);
  const noTrace: false = result.intraBlockTraceProven;
  const noEndAdmission: false = result.currentSourceReauthorizedAtEndBlock;
  void noTrace; void noEndAdmission;
  await reconcileCurrentViewRetrievalV1Receipt(provider, revoke, transactionHash, { execution: "direct" });
  const history = await inspectCurrentViewRetrievalV1History(provider, historyDeployment, recordHash,
    { blockTag: 12, gasLimit: 10_000_000n, retainedPayload });
  const notCurrent: false = history.currentnessVerified;
  const notSigned: false = history.signatureVerified;
  void notCurrent; void notSigned;
  const current = await inspectCurrentViewRetrievalV1Current(provider, deployment, recordHash, { blockTag: 12, gasLimit: 10_000_000n });
  const noNewAuthority: false = current.freshSignatureRevalidated;
  const noNewDeadline: false = current.historicalDeadlineRevalidated;
  void noNewAuthority; void noNewDeadline;
  const refused = await observeCurrentViewRetrievalV1Refusal(provider, publish, { blockTag: 12 });
  const noRollback: false = refused.submittedTransactionRollbackProven;
  const noStalePrediction: false = refused.capturePredictionChecked;
  void noRollback; void noStalePrediction;
}
void consume;

// @ts-expect-error Full Safe transport must bind an independently reviewed hash.
const unsafe: CurrentViewRetrievalV1ReceiptOptions = { execution: "safe" };
void unsafe;
// @ts-expect-error No implicit/latest block capture.
void captureCurrentViewRetrievalV1(provider, deployment, caller, { kind: "publish", request, signature }, { blockTag: "latest", gasLimit: 10_000_000n });
// @ts-expect-error Public retained-byte reads use a distinct explicit outer gas budget.
void inspectCurrentViewRetrievalV1History(provider, historyDeployment, recordHash, { blockTag: 10 });
// @ts-expect-error Consumer admission extension is outside this producer seam.
void captureCurrentViewRetrievalV1(provider, deployment, caller, { kind: "coverRetrievalNext", recordHash }, { blockTag: 10, gasLimit: 10_000_000n });
// @ts-expect-error A caller cannot choose a writer or replace current Archive attribution.
void captureCurrentViewRetrievalV1(provider, deployment, caller, { kind: "publish", request, signature, writer: caller }, { blockTag: 10, gasLimit: 10_000_000n });
// @ts-expect-error Captures own their nested original calldata.
capture.prepared.call.data = signature;
if (capture.stage.kind === "publish") {
  // @ts-expect-error Retained original same-pair coverage is deeply immutable.
  capture.stage.preview.archive.coverage.firstReceiptHash = recordHash;
  // @ts-expect-error Caller cannot modify the prepared scope after capture.
  capture.stage.preview.observation.source.scope.collectionId = 99n;
  // @ts-expect-error Chunk bytes are owned and immutable.
  capture.stage.chunks[0]!.runtime = signature;
} else {
  // @ts-expect-error Revoke history is immutable and not a current-authority request.
  capture.stage.history.receipt.writer = caller;
}
