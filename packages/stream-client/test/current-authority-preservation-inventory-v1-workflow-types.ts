import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { CurrentAuthorityPreservationInventoryV1Request, CurrentAuthorityPreservationInventoryV1Scope } from "../src/current-authority-preservation-inventory-v1.js";
import * as w from "../src/current-authority-preservation-inventory-v1-workflow.js";
declare const provider: Provider;
declare const deployment: w.CurrentAuthorityPreservationInventoryV1Deployment;
declare const local: w.CurrentAuthorityPreservationInventoryV1HistoryDeployment;
declare const capture: w.CurrentAuthorityPreservationInventoryV1WorkflowCapture;
declare const request: CurrentAuthorityPreservationInventoryV1Request;
declare const scope: CurrentAuthorityPreservationInventoryV1Scope;
declare const caller: Address;
declare const hash: Hex;
declare const segments: readonly w.CurrentAuthorityPreservationInventoryV1SegmentLocator[];
void w.captureCurrentAuthorityPreservationInventoryV1(provider, deployment, caller, request, { blockTag: 10, gasLimit: 10000000n, segments });
void w.simulateCurrentAuthorityPreservationInventoryV1(provider, capture, { blockTag: 11, gasLimit: 10000000n });
void w.reconcileCurrentAuthorityPreservationInventoryV1Receipt(provider, capture, hash, { execution: "direct" });
void w.reconcileCurrentAuthorityPreservationInventoryV1Receipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash });
void w.inspectCurrentAuthorityPreservationInventoryV1History(provider, local, hash, { blockTag: 12, segments });
void w.inspectCurrentAuthorityPreservationInventoryV1Segment(provider, local, { transactionHash: hash, logIndex: 0 }, { blockTag: 12 });
void w.inspectCurrentAuthorityPreservationInventoryV1Current(provider, deployment, scope, { blockTag: 12, gasLimit: 10000000n, segments, fullDefinitionBytes: true });
void w.observeCurrentAuthorityPreservationInventoryV1Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
// @ts-expect-error Safe receipt requires the independently supplied hash.
void w.reconcileCurrentAuthorityPreservationInventoryV1Receipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error Block observations are explicit numbers.
void w.simulateCurrentAuthorityPreservationInventoryV1(provider, capture, { blockTag: "latest", gasLimit: 10000000n });
// @ts-expect-error Event locators are required, not an invented Item getter.
void w.captureCurrentAuthorityPreservationInventoryV1(provider, deployment, caller, request, { blockTag: 10, gasLimit: 10000000n });
// @ts-expect-error Reviewed runtime metadata is immutable.
capture.deployment.workers.source.codeHash = hash;
// @ts-expect-error Retained authority is deeply readonly.
capture.stage.selection.selection.origin.environment.ownerCodeHashes[0] = hash;
// @ts-expect-error Item rows retain order and multiplicity.
capture.stage.segments[0]!.items.push(capture.stage.segments[0]!.items[0]!);
async function results() {
  const simulated = await w.simulateCurrentAuthorityPreservationInventoryV1(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const noPersistence: false = simulated.stateChangesPersisted;
  const history = await w.inspectCurrentAuthorityPreservationInventoryV1History(provider, local, hash, { blockTag: 12, segments });
  const noCurrent: false = history.currentAuthorityChecked;
  const noSelectionRecompute: false = history.selectionCommitmentRecomputed;
  const privateFacts: false = history.privateCatalogFactsIndependentlyReconstructed;
  const receipt = await w.reconcileCurrentAuthorityPreservationInventoryV1Receipt(provider, capture, hash, { execution: "direct" });
  const noCurrentAfter: false = receipt.currentAfterReceipt;
  const refusal = await w.observeCurrentAuthorityPreservationInventoryV1Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const noRollback: false = refusal.rollbackProven;
  const outcome: "execution-reverted" | "rpc-failed" = refusal.outcome;
  void [noPersistence, noCurrent, noSelectionRecompute, privateFacts, noCurrentAfter, noRollback, outcome];
}
void results;
