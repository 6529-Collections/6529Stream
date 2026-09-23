import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import { previewTokenPreservationSnapshotV2, captureTokenPreservationSnapshotV2, simulateTokenPreservationSnapshotV2,
  reconcileTokenPreservationSnapshotV2Receipt, inspectTokenPreservationSnapshotV2History,
  inspectTokenPreservationSnapshotV2Current, observeTokenPreservationSnapshotV2Refusal,
  type TokenPreservationSnapshotV2Deployment, type TokenPreservationSnapshotV2Capture } from "../src/current-token-preservation-snapshot-v2-workflow.js";
import type { TokenPreservationSnapshotV2Publication, TokenPreservationSnapshotV2Scope } from "../src/current-token-preservation-snapshot-v2.js";
declare const provider: Provider, deployment: TokenPreservationSnapshotV2Deployment, publication: TokenPreservationSnapshotV2Publication;
declare const caller: Address, recordHash: Hex, scope: TokenPreservationSnapshotV2Scope, capture: TokenPreservationSnapshotV2Capture;
async function consumer() {
  const preview = await previewTokenPreservationSnapshotV2(provider, deployment, publication, caller, { blockTag: 1 });
  const checked = await captureTokenPreservationSnapshotV2(provider, deployment, caller,
    { kind: "publishSnapshot", publication: preview.readyPublication }, { blockTag: 1, gasLimit: 50000000n });
  const simulation = await simulateTokenPreservationSnapshotV2(provider, checked, { blockTag: 1 });
  const persisted: false = simulation.persisted;
  const receipt = await reconcileTokenPreservationSnapshotV2Receipt(provider, checked, recordHash,
    { execution: "safe", expectedSafeTxHash: recordHash });
  const attribution: "unchanged-preceding-block-and-exact-end-block" = receipt.receiptAttribution;
  const history = await inspectTokenPreservationSnapshotV2History(provider, deployment, recordHash, { blockTag: 2 });
  const historical: false = history.currentEligibilityChecked;
  const now = await inspectTokenPreservationSnapshotV2Current(provider, deployment, scope, { blockTag: 2 });
  if (now.exists) { const freshAuthority: false = now.publisherReauthorized; void freshAuthority; }
  const refusal = await observeTokenPreservationSnapshotV2Refusal(provider, checked, { blockTag: 2 });
  const native: false = refusal.nativeRollbackProven;
  void [persisted, attribution, historical, native];
}
// @ts-expect-error governance lock is not a publication wallet stage
captureTokenPreservationSnapshotV2(provider, deployment, caller, { kind: "lockSnapshot", scope }, { blockTag: 1, gasLimit: 50000000n });
// @ts-expect-error explicit Safe hash is mandatory
reconcileTokenPreservationSnapshotV2Receipt(provider, capture, recordHash, { execution: "safe" });
// @ts-expect-error capture facts are deeply readonly
capture.stage.source.entropy.policies[0]!.frozen = false;
// @ts-expect-error concrete numeric block tag is required
simulateTokenPreservationSnapshotV2(provider, capture, { blockTag: "latest" });
// @ts-expect-error history needs a record hash, not a current scope
inspectTokenPreservationSnapshotV2History(provider, deployment, scope, { blockTag: 1 });
void consumer;
