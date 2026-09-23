import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ScopedPolicyInventoryV2Request, ScopedPolicyInventoryV2Scope } from "../src/current-scoped-policy-inventory-v2.js";
import * as w from "../src/current-scoped-policy-inventory-v2-workflow.js";
declare const provider: Provider;
declare const deployment: w.ScopedPolicyInventoryV2Deployment;
declare const local: w.ScopedPolicyInventoryV2HistoryDeployment;
declare const capture: w.ScopedPolicyInventoryV2WorkflowCapture;
declare const request: ScopedPolicyInventoryV2Request;
declare const scope: ScopedPolicyInventoryV2Scope;
declare const caller: Address;
declare const hash: Hex;
declare const segments: readonly w.ScopedPolicyInventoryV2SegmentLocator[];
void w.captureScopedPolicyInventoryV2(provider, deployment, caller, request, { blockTag: 10, gasLimit: 10000000n, segments });
void w.simulateScopedPolicyInventoryV2(provider, capture, { blockTag: 11, gasLimit: 10000000n });
void w.reconcileScopedPolicyInventoryV2Receipt(provider, capture, hash, { execution: "direct" });
void w.reconcileScopedPolicyInventoryV2Receipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash });
void w.inspectScopedPolicyInventoryV2History(provider, local, hash, { blockTag: 12, segments });
void w.inspectScopedPolicyInventoryV2Segment(provider, local, { transactionHash: hash, logIndex: 0 }, { blockTag: 12 });
void w.inspectScopedPolicyInventoryV2Current(provider, deployment, scope, { blockTag: 12, gasLimit: 10000000n, segments, fullDefinitionBytes: true });
void w.observeScopedPolicyInventoryV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
// @ts-expect-error Safe hash is independently supplied.
void w.reconcileScopedPolicyInventoryV2Receipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error No latest-block implicit observation.
void w.simulateScopedPolicyInventoryV2(provider, capture, { blockTag: "latest", gasLimit: 10000000n });
// @ts-expect-error Complete prior segment locators are required.
void w.captureScopedPolicyInventoryV2(provider, deployment, caller, request, { blockTag: 10, gasLimit: 10000000n });
// @ts-expect-error Reviewed pins are readonly.
capture.deployment.workers.source.codeHash = hash;
// @ts-expect-error Captured nested context is readonly.
capture.stage.context.snapshotSource.artist.artistId = hash;
// @ts-expect-error Repeated Item rows cannot be mutated in saved evidence.
capture.stage.segments[0]!.items.push(capture.stage.segments[0]!.items[0]!);
async function results() {
  const simulated = await w.simulateScopedPolicyInventoryV2(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const noPersistence: false = simulated.stateChangesPersisted;
  const history = await w.inspectScopedPolicyInventoryV2History(provider, local, hash, { blockTag: 12, segments });
  const noCurrent: false = history.currentSourceChecked;
  const receipt = await w.reconcileScopedPolicyInventoryV2Receipt(provider, capture, hash, { execution: "direct" });
  const noCurrentAfter: false = receipt.currentAfterReceipt;
  const refusal = await w.observeScopedPolicyInventoryV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const noRollback: false = refusal.rollbackProven;
  const outcome: "execution-reverted" | "rpc-failed" = refusal.outcome;
  void [noPersistence, noCurrent, noCurrentAfter, noRollback, outcome];
}
void results;
