import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { CurrentAuthorityPreservationArchiveV1Request } from "../src/current-authority-preservation-archive-v1.js";
import * as w from "../src/current-authority-preservation-archive-v1-workflow.js";
declare const provider: Provider;
declare const deployment: w.CurrentAuthorityPreservationArchiveV1Deployment;
declare const local: w.CurrentAuthorityPreservationArchiveV1HistoryDeployment;
declare const capture: w.CurrentAuthorityPreservationArchiveV1WorkflowCapture;
declare const request: CurrentAuthorityPreservationArchiveV1Request;
declare const caller: Address;
declare const hash: Hex;
declare const segments: readonly w.CurrentAuthorityPreservationArchiveV1SegmentLocator[];
void w.captureCurrentAuthorityPreservationArchiveV1(provider, deployment, caller, request, { blockTag: 10, gasLimit: 10000000n, segments });
void w.simulateCurrentAuthorityPreservationArchiveV1(provider, capture, { blockTag: 11, gasLimit: 10000000n });
void w.reconcileCurrentAuthorityPreservationArchiveV1Receipt(provider, capture, hash, { execution: "direct" });
void w.reconcileCurrentAuthorityPreservationArchiveV1Receipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash });
void w.inspectCurrentAuthorityPreservationArchiveV1History(provider, local, hash, { blockTag: 12, segments });
void w.inspectCurrentAuthorityPreservationArchiveV1Current(provider, deployment, hash, { blockTag: 12, gasLimit: 10000000n, segments, fullCurrentCoverage: true });
void w.observeCurrentAuthorityPreservationArchiveV1Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
// @ts-expect-error Safe success must match an independently supplied transaction hash.
void w.reconcileCurrentAuthorityPreservationArchiveV1Receipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error Fixed block observations are explicit numbers.
void w.simulateCurrentAuthorityPreservationArchiveV1(provider, capture, { blockTag: "latest", gasLimit: 10000000n });
// @ts-expect-error Event locators are required; no original Item getter is invented.
void w.captureCurrentAuthorityPreservationArchiveV1(provider, deployment, caller, request, { blockTag: 10, gasLimit: 10000000n });
// @ts-expect-error Caller may not substitute a supplied original archive route.
void w.captureCurrentAuthorityPreservationArchiveV1(provider, deployment, caller, { kind: "coverNext", id: hash, archive: caller }, { blockTag: 10, gasLimit: 10000000n, segments });
// @ts-expect-error Runtime metadata is immutable.
capture.deployment.archiveReader.codeHash = hash;
// @ts-expect-error Captured authority retains fixed deeply readonly original tuples.
capture.stage.environment.capture.selection.origin.environment.ownerCodeHashes[0] = hash;
// @ts-expect-error Ordered admissions must not be mutated.
capture.stage.admissions.push(capture.stage.admissions[0]!);
// @ts-expect-error The private initial accumulator is not independently authenticated.
const independentlyAuthenticated: true = capture.stage.initialObservationChainAuthenticated;
async function results() {
  const simulated = await w.simulateCurrentAuthorityPreservationArchiveV1(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const noPersistence: false = simulated.stateChangesPersisted;
  const history = await w.inspectCurrentAuthorityPreservationArchiveV1History(provider, local, hash, { blockTag: 12, segments });
  const noAuthority: false = history.currentAuthorityChecked;
  const noEnvironment: false = history.currentEnvironmentChecked;
  const noInventorySource: false = history.inventoryCurrentSourceChecked;
  const noInitialProof: false = history.initialObservationChainAuthenticated;
  const current = await w.inspectCurrentAuthorityPreservationArchiveV1Current(provider, deployment, hash, { blockTag: 12, gasLimit: 10000000n, segments });
  const environmentChecked: true = current.currentEnvironmentChecked;
  const diagnostic: boolean = current.fullCurrentCoverageChecked;
  const receipt = await w.reconcileCurrentAuthorityPreservationArchiveV1Receipt(provider, capture, hash, { execution: "direct" });
  const noCurrentAfter: false = receipt.currentAfterReceipt;
  const refreshStep: boolean = receipt.refreshStepChainAuthenticated;
  const refusal = await w.observeCurrentAuthorityPreservationArchiveV1Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const noRollback: false = refusal.rollbackProven;
  const outcome: "execution-reverted" | "rpc-failed" = refusal.outcome;
  void [noPersistence, noAuthority, noEnvironment, noInventorySource, noInitialProof, environmentChecked, diagnostic, noCurrentAfter, refreshStep, noRollback, outcome];
}
void results;
void independentlyAuthenticated;
