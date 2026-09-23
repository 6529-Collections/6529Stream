import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import {
  captureTokenPreservationOutputV2, simulateTokenPreservationOutputV2,
  reconcileTokenPreservationOutputV2Receipt, inspectTokenPreservationOutputV2History,
  inspectTokenPreservationOutputV2Current, observeTokenPreservationOutputV2Refusal,
  type TokenPreservationOutputV2Deployment, type TokenPreservationOutputV2Capture,
  type TokenPreservationOutputV2HistoryRequest
} from "../src/current-token-preservation-output-v2-workflow.js";
import type { TokenPreservationOutputV2Request } from "../src/current-token-preservation-output-v2.js";
declare const provider: Provider;
declare const deployment: TokenPreservationOutputV2Deployment;
declare const caller: Address;
declare const hash: Hex;
declare const capture: TokenPreservationOutputV2Capture;
declare const request: TokenPreservationOutputV2Request;
void captureTokenPreservationOutputV2(provider, deployment, caller, request, { blockTag: 10, gasLimit: 50_000_000n });
void simulateTokenPreservationOutputV2(provider, capture, { blockTag: 11 });
void reconcileTokenPreservationOutputV2Receipt(provider, capture, hash, { execution: "direct" });
void reconcileTokenPreservationOutputV2Receipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash });
void inspectTokenPreservationOutputV2History(provider, deployment, { kind: "checkpoint", id: hash }, { blockTag: 10 });
void inspectTokenPreservationOutputV2Current(provider, deployment, { kind: "manifest", recordHash: hash }, { blockTag: 10 });
void observeTokenPreservationOutputV2Refusal(provider, capture, { blockTag: 11 });
// @ts-expect-error Historical/current reads have a closed request set.
const invalidHistory: TokenPreservationOutputV2HistoryRequest = { kind: "snapshot", recordHash: hash };
void invalidHistory;
// @ts-expect-error A Safe receipt needs an independently known transaction hash.
void reconcileTokenPreservationOutputV2Receipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error Fixed concrete blocks only.
void simulateTokenPreservationOutputV2(provider, capture, { blockTag: "latest" });
// @ts-expect-error This token profile does not admit VIEW.
const viewDeployment: TokenPreservationOutputV2Deployment = { ...deployment, scopeKind: "view" };
void viewDeployment;
// @ts-expect-error Captured deployment is immutable.
capture.deployment.chainId = 2n;
// @ts-expect-error No snapshot or authority writes in the four-write profile.
const snapshotWrite: TokenPreservationOutputV2Request = { kind: "publishSnapshot", publication: {} };
void snapshotWrite;
if (capture.stage.kind === "checkpoint") {
  const index: bigint = capture.stage.expected.nextIndex;
  void index;
  // @ts-expect-error Retained outputs are immutable.
  capture.stage.appended.push(capture.stage.appended[0]!);
}
