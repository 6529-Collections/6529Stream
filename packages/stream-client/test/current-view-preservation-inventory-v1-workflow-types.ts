import type { Address, Hex } from "../src/generated/contracts.js";
import type { CurrentViewPreservationInventoryV1Request, CurrentViewPreservationInventoryV1Scope } from "../src/current-view-preservation-inventory-v1.js";
import {
  captureCurrentViewPreservationInventoryV1, simulateCurrentViewPreservationInventoryV1,
  reconcileCurrentViewPreservationInventoryV1Receipt, inspectCurrentViewPreservationInventoryV1Segment,
  inspectCurrentViewPreservationInventoryV1History, inspectCurrentViewPreservationInventoryV1Current,
  observeCurrentViewPreservationInventoryV1Refusal,
  type CurrentViewPreservationInventoryV1Deployment, type CurrentViewPreservationInventoryV1HistoryDeployment,
  type CurrentViewPreservationInventoryV1WorkflowCapture, type CurrentViewPreservationInventoryV1SegmentLocator,
  type CurrentViewPreservationInventoryV1ReceiptOptions,
} from "../src/current-view-preservation-inventory-v1-workflow.js";
declare const provider: Parameters<typeof captureCurrentViewPreservationInventoryV1>[0];
declare const deployment: CurrentViewPreservationInventoryV1Deployment;
declare const historical: CurrentViewPreservationInventoryV1HistoryDeployment;
declare const caller: Address, hash: Hex, scope: CurrentViewPreservationInventoryV1Scope;
declare const saved: CurrentViewPreservationInventoryV1WorkflowCapture;
declare const segments: readonly CurrentViewPreservationInventoryV1SegmentLocator[];
const request: CurrentViewPreservationInventoryV1Request = { method: "beginInventory", scope };
const options = { blockTag: 10, gasLimit: 12_000_000n, segments } as const;
const capture = captureCurrentViewPreservationInventoryV1(provider, deployment, caller, request, options);
void capture.then(value => {
  const independent: false = value.itemProductionIndependentlyReconstructed;
  const simulated: true = value.originalCallSimulated;
  void [independent, simulated];
  // @ts-expect-error observed source context is deeply readonly
  value.stage.context.scope.collectionId = 3n;
  // @ts-expect-error reviewed runtime pins are readonly
  value.deployment.linkedDependencies.push(value.deployment.inventory);
});
void simulateCurrentViewPreservationInventoryV1(provider, saved, { blockTag: 11 });
void inspectCurrentViewPreservationInventoryV1Segment(provider, historical, { transactionHash: hash, logIndex: 0 }, { blockTag: 12 });
void inspectCurrentViewPreservationInventoryV1History(provider, historical, hash, { blockTag: 12, segments }).then(value => {
  const current: false = value.currentSourceChecked;
  const production: false = value.itemProductionIndependentlyReconstructed;
  void [current, production];
  // @ts-expect-error authenticated emitted Items are readonly
  value.segments[0]!.items[0]!.sourceIndex = 3n;
});
void inspectCurrentViewPreservationInventoryV1Current(provider, deployment, hash, { ...options, fullDefinitionBytes: true });
void reconcileCurrentViewPreservationInventoryV1Receipt(provider, saved, hash, { execution: "direct" });
void reconcileCurrentViewPreservationInventoryV1Receipt(provider, saved, hash, { execution: "safe", expectedSafeTxHash: hash }).then(value => {
  const trace: false = value.intraBlockTraceProven;
  const source: false = value.currentSourceReauthorizedAtEndBlock;
  void [trace, source];
});
void observeCurrentViewPreservationInventoryV1Refusal(provider, saved, { blockTag: 11 }).then(value => {
  const rollback: false = value.submittedTransactionRollbackProven;
  const outcome: "call-succeeded" | "execution-reverted" | "rpc-failed" = value.outcome;
  void [rollback, outcome];
});
// @ts-expect-error Safe reconciliation requires an independently supplied transaction hash
const badSafe: CurrentViewPreservationInventoryV1ReceiptOptions = { execution: "safe" };
// @ts-expect-error fixed block is required
void captureCurrentViewPreservationInventoryV1(provider, deployment, caller, request, { gasLimit: 12_000_000n, segments });
// @ts-expect-error explicit locators are required; there is no Item getter or implicit indexer
void inspectCurrentViewPreservationInventoryV1History(provider, historical, hash, { blockTag: 12 });
// @ts-expect-error only sixteen original permissionless writes are exposed
const invalidWrite: CurrentViewPreservationInventoryV1Request = { method: "bindCompleteViewPreservation", scope };
// @ts-expect-error supplied history deployment does not acquire source-reader authority
void inspectCurrentViewPreservationInventoryV1Current(provider, historical, hash, options);
void [badSafe, invalidWrite];
