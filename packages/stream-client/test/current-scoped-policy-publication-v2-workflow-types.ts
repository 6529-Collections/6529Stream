import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ScopedPolicyGraphV2Scope } from "../src/current-scoped-policy-graph-v2.js";
import type { ScopedPolicyPublicationV2Publication, ScopedPolicyPublicationV2Request } from "../src/current-scoped-policy-publication-v2.js";
import {
  captureScopedPolicyPublicationV2, previewScopedPolicyPublicationV2Snapshot, simulateScopedPolicyPublicationV2,
  reconcileScopedPolicyPublicationV2Receipt, inspectScopedPolicyPublicationV2History, inspectScopedPolicyPublicationV2Current,
  observeScopedPolicyPublicationV2Refusal, type ScopedPolicyPublicationV2Capture, type ScopedPolicyPublicationV2Deployment,
  type ScopedPolicyPublicationV2HistoryDeployment
} from "../src/current-scoped-policy-publication-v2-workflow.js";

declare const provider: Provider;
declare const deployment: ScopedPolicyPublicationV2Deployment;
declare const local: ScopedPolicyPublicationV2HistoryDeployment;
declare const capture: ScopedPolicyPublicationV2Capture;
declare const scope: ScopedPolicyGraphV2Scope;
declare const caller: Address;
declare const hash: Hex;
declare const publication: ScopedPolicyPublicationV2Publication;
const requests: readonly ScopedPolicyPublicationV2Request[] = [
  { kind: "begin", selectionId: hash, salt: hash },
  { kind: "append", id: hash, payloads: [{ tokenId: 1n, image: "0x", animation: "0x0102" }] },
  { kind: "beginManifest", checkpointHash: hash, artifactHash: hash, coverageHash: hash, artistId: hash },
  { kind: "verifyNextOutputs", planHash: hash, count: 1n },
  { kind: "publishSnapshot", publication }
];
for (const request of requests) void captureScopedPolicyPublicationV2(provider, deployment, scope, caller, request, { blockTag: 10 });
void previewScopedPolicyPublicationV2Snapshot(provider, deployment, publication, caller, { blockTag: 10 });
void simulateScopedPolicyPublicationV2(provider, capture, { blockTag: 11, gasLimit: 30000000n });
void reconcileScopedPolicyPublicationV2Receipt(provider, capture, hash, { execution: "direct" });
void reconcileScopedPolicyPublicationV2Receipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash });
void inspectScopedPolicyPublicationV2History(provider, local, { kind: "snapshotRecord", recordHash: hash }, { blockTag: 12 });
void inspectScopedPolicyPublicationV2Current(provider, deployment, scope, { kind: "manifest", recordHash: hash, artistId: hash }, { blockTag: 12 });
void observeScopedPolicyPublicationV2Refusal(provider, capture, { blockTag: 11, gasLimit: 30000000n });
// @ts-expect-error Governed locking is not an ordinary wallet operation in this batch.
void captureScopedPolicyPublicationV2(provider, deployment, scope, caller, { kind: "lockSnapshot", scope }, { blockTag: 10 });
// @ts-expect-error Covered output count is exact bigint.
void captureScopedPolicyPublicationV2(provider, deployment, scope, caller, { kind: "verifyNextOutputs", planHash: hash, count: 1 }, { blockTag: 10 });
// @ts-expect-error Safe receipt requires an independently supplied Safe transaction hash.
void reconcileScopedPolicyPublicationV2Receipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error Concrete fixed blocks only.
void simulateScopedPolicyPublicationV2(provider, capture, { blockTag: "latest", gasLimit: 30000000n });
// @ts-expect-error Captured authority is immutable.
capture.prepared.caller = caller;
// @ts-expect-error Reviewed dependency arrays are immutable.
capture.deployment.linkedDependencies.push({ address: caller, codeHash: hash });
if (capture.stage.kind === "checkpoint") {
  // @ts-expect-error Observed output rows are immutable.
  capture.stage.outputs.push(capture.stage.outputs[0]!);
}
async function resultTypes() {
  const history = await inspectScopedPolicyPublicationV2History(provider, local, { kind: "snapshotRecord", recordHash: hash }, { blockTag: 12 });
  const historicalOnly: false = history.currentnessChecked;
  if (history.result.kind === "snapshotRecord") {
    const timestamp: bigint = history.result.receipt.recordedAt;
    // @ts-expect-error Original publication is immutable.
    history.result.publication.expectedHead = hash;
    void timestamp;
  }
  const refusal = await observeScopedPolicyPublicationV2Refusal(provider, capture, { blockTag: 11, gasLimit: 30000000n });
  const notProof: false = refusal.rollbackProven;
  const preview = await previewScopedPolicyPublicationV2Snapshot(provider, deployment, publication, caller, { blockTag: 10 });
  const notStored: false = preview.storeAvailabilityChecked;
  void [historicalOnly, notProof, notStored];
}
void resultTypes;
