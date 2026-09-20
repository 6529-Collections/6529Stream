import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ScopedPolicyBundleV2Request } from "../src/current-scoped-policy-bundle-v2.js";
import type { ScopedPolicyInventoryV2SegmentLocator } from "../src/current-scoped-policy-inventory-v2-workflow.js";
import * as w from "../src/current-scoped-policy-bundle-v2-workflow.js";
declare const provider: Provider;
declare const deployment: w.ScopedPolicyBundleV2Deployment;
declare const local: w.ScopedPolicyBundleV2HistoryDeployment;
declare const capture: w.ScopedPolicyBundleV2WorkflowCapture;
declare const request: ScopedPolicyBundleV2Request;
declare const caller: Address;
declare const hash: Hex;
declare const segments: readonly ScopedPolicyInventoryV2SegmentLocator[];
void w.captureScopedPolicyBundleV2(provider, deployment, caller, request, { blockTag: 10, gasLimit: 10000000n, segments });
void w.simulateScopedPolicyBundleV2(provider, capture, { blockTag: 11, gasLimit: 10000000n });
void w.reconcileScopedPolicyBundleV2Receipt(provider, capture, hash, { execution: "direct" });
void w.reconcileScopedPolicyBundleV2Receipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash });
void w.inspectScopedPolicyBundleV2History(provider, local, hash, { blockTag: 12, segments });
void w.inspectScopedPolicyBundleV2Current(provider, deployment, hash, { blockTag: 12, gasLimit: 10000000n, segments, fullCurrentCoverage: true });
void w.observeScopedPolicyBundleV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
// @ts-expect-error No arbitrary Safe transport or delegatecall.
void w.reconcileScopedPolicyBundleV2Receipt(provider, capture, hash, { execution: "delegatecall" });
// @ts-expect-error Original worker pin is a required deployment trust input.
const missingWorker: w.ScopedPolicyBundleV2Deployment = { chainId: 1n, core: caller, bundle: deployment.bundle, linkedDependencies: [] };
// @ts-expect-error Saved admission is readonly.
capture.stage.admissions[0]!.admission.originalBundleHash = hash;
// @ts-expect-error Private original chain must never be claimed independently authenticated.
const chainProven: true = capture.stage.initialObservationChainAuthenticated;
async function results() {
  const receipt = await w.reconcileScopedPolicyBundleV2Receipt(provider, capture, hash, { execution: "direct" });
  const noPrivateChain: false = receipt.initialObservationChainAuthenticated;
  const step: boolean = receipt.refreshStepChainAuthenticated;
  const current = await w.inspectScopedPolicyBundleV2Current(provider, deployment, hash, { blockTag: 12, gasLimit: 10000000n, segments });
  const noInventorySource: false = current.inventoryCurrentSourceChecked;
  const history = await w.inspectScopedPolicyBundleV2History(provider, local, hash, { blockTag: 12, segments });
  const noEnvironment: false = history.currentEnvironmentChecked;
  const refusal = await w.observeScopedPolicyBundleV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const noRollback: false = refusal.rollbackProven;
  void [noPrivateChain, step, noInventorySource, noEnvironment, noRollback];
}
void [results, missingWorker, chainProven];
