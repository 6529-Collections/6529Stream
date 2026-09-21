import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { TokenPreservationReferenceV2Publication, TokenPreservationReferenceV2Request } from "../src/current-token-preservation-reference-v2.js";
import {
  captureTokenPreservationReferenceV2, previewTokenPreservationReferenceV2, simulateTokenPreservationReferenceV2,
  reconcileTokenPreservationReferenceV2Receipt, inspectTokenPreservationReferenceV2History,
  inspectTokenPreservationReferenceV2Current, observeTokenPreservationReferenceV2Refusal,
  type TokenPreservationReferenceV2Deployment, type TokenPreservationReferenceV2HistoryDeployment,
  type TokenPreservationReferenceV2WorkflowCapture, type TokenPreservationReferenceV2ReceiptOptions
} from "../src/current-token-preservation-reference-v2-workflow.js";
declare const provider: Provider;
declare const deployment: TokenPreservationReferenceV2Deployment;
declare const historical: TokenPreservationReferenceV2HistoryDeployment;
declare const caller: Address;
declare const publication: TokenPreservationReferenceV2Publication;
declare const capture: TokenPreservationReferenceV2WorkflowCapture;
declare const transactionHash: Hex;
declare const safeHash: Hex;
const request: TokenPreservationReferenceV2Request = { kind: "publishReference", publication };
void captureTokenPreservationReferenceV2(provider, deployment, caller, request, { blockTag: 10 });
void previewTokenPreservationReferenceV2(provider, deployment, caller, publication, { blockTag: 10 });
void simulateTokenPreservationReferenceV2(provider, capture, { blockTag: 11, gasLimit: 10_000_000n });
const safe: TokenPreservationReferenceV2ReceiptOptions = { execution: "safe", expectedSafeTxHash: safeHash };
void reconcileTokenPreservationReferenceV2Receipt(provider, capture, transactionHash, safe);
void reconcileTokenPreservationReferenceV2Receipt(provider, capture, transactionHash, { execution: "direct" });
void inspectTokenPreservationReferenceV2History(provider, historical, transactionHash, { blockTag: 12 });
void inspectTokenPreservationReferenceV2Current(provider, deployment, publication.scope, { blockTag: 12 });
void observeTokenPreservationReferenceV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10_000_000n });
if (capture.stage.kind === "publication") {
  const ready: TokenPreservationReferenceV2Publication = capture.stage.preview.publication;
  const checked: false = capture.stage.preview.storeAvailabilityChecked;
  void ready; void checked;
  // @ts-expect-error sampled source state is deeply immutable
  capture.stage.preview.source.samples[0]!.preservationAdmission.goldenHash = transactionHash;
} else {
  const retained: boolean = capture.stage.retainedBefore;
  void retained;
  // @ts-expect-error retained chunk observations are immutable
  capture.stage.chunks.push({ hash: transactionHash, pointer: caller, byteLength: 1n });
}
// @ts-expect-error scope family is closed
const unsupported: TokenPreservationReferenceV2Deployment = { ...deployment, scopeKind: "view" };
// @ts-expect-error Safe must supply its independently reviewed transaction hash
const missingSafeHash: TokenPreservationReferenceV2ReceiptOptions = { execution: "safe" };
// @ts-expect-error capture options require a concrete block
void captureTokenPreservationReferenceV2(provider, deployment, caller, request, { blockTag: "latest" });
// @ts-expect-error no direct governance lock operation in this workflow request union
const lock: TokenPreservationReferenceV2Request = { kind: "lockReference", scope: publication.scope };
// @ts-expect-error the smaller immutable-history deployment does not provide fresh source admission pins
void inspectTokenPreservationReferenceV2Current(provider, historical, publication.scope, { blockTag: 12 });
void unsupported; void missingSafeHash; void lock;
