import type { Address, Hex } from "../src/generated/contracts.js";
import type { CurrentViewPreservationBundleV1Request, CurrentViewPreservationBundleV1Item } from "../src/current-view-preservation-bundle-v1.js";
import {
  captureCurrentViewPreservationBundleV1, simulateCurrentViewPreservationBundleV1,
  reconcileCurrentViewPreservationBundleV1Receipt, inspectCurrentViewPreservationBundleV1History,
  inspectCurrentViewPreservationBundleV1Current, observeCurrentViewPreservationBundleV1Refusal,
  type CurrentViewPreservationBundleV1Deployment, type CurrentViewPreservationBundleV1HistoryDeployment,
  type CurrentViewPreservationBundleV1WorkflowCapture, type CurrentViewPreservationBundleV1SegmentLocator,
  type CurrentViewPreservationBundleV1ReceiptOptions,
} from "../src/current-view-preservation-bundle-v1-workflow.js";
declare const provider: Parameters<typeof captureCurrentViewPreservationBundleV1>[0];
declare const deployment: CurrentViewPreservationBundleV1Deployment;
declare const historical: CurrentViewPreservationBundleV1HistoryDeployment;
declare const caller: Address, hash: Hex, item: CurrentViewPreservationBundleV1Item;
declare const saved: CurrentViewPreservationBundleV1WorkflowCapture;
declare const segments: readonly CurrentViewPreservationBundleV1SegmentLocator[];
const request: CurrentViewPreservationBundleV1Request = { method: "coverRetrievalNext", id: hash, item, nextLink: hash, witnessHash: hash };
const options = { blockTag: 10, gasLimit: 12_000_000n, segments } as const;
void captureCurrentViewPreservationBundleV1(provider, deployment, caller, request, options).then(value => {
  const automatic: false = value.stage.initialObservationChainAuthenticated;
  const environment: Hex | null = value.stage.environment;
  void [automatic, environment];
  // @ts-expect-error captured Item occurrence is deeply readonly
  value.stage.admissions[0]!.admission.externalOriginal.artistId = hash;
  // @ts-expect-error saved reviewed dependency pins are readonly
  value.deployment.linkedDependencies[0]!.address = caller;
});
void simulateCurrentViewPreservationBundleV1(provider, saved, { blockTag: 11 });
void inspectCurrentViewPreservationBundleV1History(provider, historical, hash, { blockTag: 12, segments }).then(value => {
  const environment: false = value.currentEnvironmentChecked;
  const source: false = value.inventoryCurrentSourceChecked;
  const witness: false = value.retrievalWitnessRecordIndependentlyAuthenticated;
  void [environment, source, witness];
});
void inspectCurrentViewPreservationBundleV1Current(provider, deployment, hash, { ...options, fullCurrentCoverage: true }).then(value => {
  const cached: boolean = value.cachedCoverageChecked;
  const full: boolean = value.fullCurrentCoverageChecked;
  const refresh = value.refresh;
  if (refresh) { const index: bigint = refresh.nextIndex; void index; }
  void [cached, full];
});
void reconcileCurrentViewPreservationBundleV1Receipt(provider, saved, hash, { execution: "safe", expectedSafeTxHash: hash }).then(value => {
  const initial: false = value.initialObservationChainAuthenticated;
  const trace: false = value.intraBlockTraceProven;
  const step: boolean = value.refreshStepChainAuthenticated;
  void [initial, trace, step];
});
void observeCurrentViewPreservationBundleV1Refusal(provider, saved, { blockTag: 11 }).then(value => {
  const rollback: false = value.submittedTransactionRollbackProven;
  const source: false = value.currentEnvironmentRevalidated;
  void [rollback, source];
});
// @ts-expect-error stored witness retrieval has no generic caller-selected Proof
const mixed: CurrentViewPreservationBundleV1Request = { method: "coverRetrievalNext", id: hash, item, nextLink: hash, witnessHash: hash, proof: { backend: 1n, coverageHash: hash, objectHash: hash } };
// @ts-expect-error a dedicated witness cannot be silently supplied to generic coverNext
const generic: CurrentViewPreservationBundleV1Request = { method: "coverNext", id: hash, item, nextLink: hash, witnessHash: hash };
// @ts-expect-error no independently supplied Safe hash
const unsafe: CurrentViewPreservationBundleV1ReceiptOptions = { execution: "safe" };
// @ts-expect-error history cannot become current without the reviewed worker deployment
void inspectCurrentViewPreservationBundleV1Current(provider, historical, hash, options);
// @ts-expect-error fixed block and explicit event locators are mandatory
void captureCurrentViewPreservationBundleV1(provider, deployment, caller, request, { gasLimit: 12_000_000n });
void [mixed, generic, unsafe];
