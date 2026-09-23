import type { Provider } from "ethers";
import type { Hex } from "../src/generated/contracts.js";
import type { ScopedPolicyFinalityV2Call, ScopedPolicyFinalityV2Finalization, ScopedPolicyFinalityV2Scope } from "../src/current-scoped-policy-finality-v2.js";
import {
  captureScopedPolicyFinalityV2, simulateScopedPolicyFinalityV2, inspectScopedPolicyFinalityV2Route,
  inspectScopedPolicyFinalityV2History, inspectScopedPolicyFinalityV2Current,
  reconcileScopedPolicyFinalityV2Receipt, observeScopedPolicyFinalityV2Refusal,
  type ScopedPolicyFinalityV2Deployment, type ScopedPolicyFinalityV2HistoryDeployment,
  type ScopedPolicyFinalityV2DiagnosticDeployment, type ScopedPolicyFinalityV2WorkflowCapture
} from "../src/current-scoped-policy-finality-v2-workflow.js";

declare const provider: Provider;
declare const deployment: ScopedPolicyFinalityV2Deployment;
declare const local: ScopedPolicyFinalityV2HistoryDeployment;
declare const diagnostic: ScopedPolicyFinalityV2DiagnosticDeployment;
declare const prepared: ScopedPolicyFinalityV2Call;
declare const plan: ScopedPolicyFinalityV2Finalization;
declare const saved: ScopedPolicyFinalityV2WorkflowCapture;
declare const hash: Hex;
declare const scope: ScopedPolicyFinalityV2Scope;
const options = { blockTag: 10, gasLimit: 90000000n };
void captureScopedPolicyFinalityV2(provider, deployment, prepared, options);
void simulateScopedPolicyFinalityV2(provider, saved, options);
void inspectScopedPolicyFinalityV2Route(provider, deployment, plan, options);
void inspectScopedPolicyFinalityV2History(provider, local, scope, { blockTag: 12 });
void inspectScopedPolicyFinalityV2Current(provider, diagnostic, scope, options);
void inspectScopedPolicyFinalityV2Current(provider, diagnostic, scope, { ...options, range: { start: 0n, limit: 2n } });
void reconcileScopedPolicyFinalityV2Receipt(provider, saved, hash, { execution: "direct" });
void reconcileScopedPolicyFinalityV2Receipt(provider, saved, hash, { execution: "safe", expectedSafeTxHash: hash });
void observeScopedPolicyFinalityV2Refusal(provider, saved, options);
// @ts-expect-error Exact concrete block is required.
void captureScopedPolicyFinalityV2(provider, deployment, prepared, { ...options, blockTag: "latest" });
// @ts-expect-error Actual simulation gas must be supplied.
void simulateScopedPolicyFinalityV2(provider, saved, { blockTag: 11 });
// @ts-expect-error Independent Safe hash is mandatory.
void reconcileScopedPolicyFinalityV2Receipt(provider, saved, hash, { execution: "safe" });
// @ts-expect-error Local history pins alone do not authorize linked current diagnostics.
void inspectScopedPolicyFinalityV2Current(provider, local, scope, options);
// @ts-expect-error Captured exact original caller is readonly.
saved.prepared.caller = deployment.executor.address;
// @ts-expect-error Reviewed runtime metadata is immutable.
saved.deployment.linkedDependencies.push(deployment.core);
// @ts-expect-error Range cursors are original bigint values.
void inspectScopedPolicyFinalityV2Current(provider, diagnostic, scope, { ...options, range: { start: 0, limit: 2n } });
if (saved.route) {
  // @ts-expect-error Retained statement facts are deeply readonly.
  saved.route.plan.statement.inputs.rootRecordHash = hash;
}
async function outputs() {
  const history = await inspectScopedPolicyFinalityV2History(provider, local, scope, { blockTag: 20 });
  const noCurrent: false = history.currentnessChecked;
  const noTransaction: false = history.transactionAuthenticated;
  if (history.status === "finalized") {
    const original: Hex = history.record.finalityRecordHash;
    const archive: Hex = history.archiveWitness.proof.artifactHash;
    void [original, archive];
  }
  const current = await inspectScopedPolicyFinalityV2Current(provider, diagnostic, scope, options);
  const noAdmission: false = current.freshFinalizationAdmissionChecked;
  const refusal = await observeScopedPolicyFinalityV2Refusal(provider, saved, options);
  const noRollback: false = refusal.nativeRollbackProven;
  const simulation = await simulateScopedPolicyFinalityV2(provider, saved, options);
  const notSubmitted: false = simulation.submitted;
  const receipt = await reconcileScopedPolicyFinalityV2Receipt(provider, saved, hash, { execution: "direct" });
  const attribution: "unchanged-preceding-block-and-exact-end-block" = receipt.receiptAttribution;
  void [noCurrent, noTransaction, noAdmission, noRollback, notSubmitted, attribution];
}
void outputs;
