import { prepareMintFallbackGovernanceOperation, prepareMintFallbackPermissionless } from "../dist/current-mint-fallback-workflow.js";
import { createSafeCallPlan } from "../dist/safe-plan.js";

function targetReview(plan) {
  return Object.freeze(plan.calls.map((call, index) => Object.freeze({ index,
    target: call.target, value: call.value.toString(), selector: call.selector,
    data: plan.data[index], callDataHash: call.callDataHash, scopeHash: call.scopeHash,
    oldValueHash: call.oldValueHash, newValueHash: call.newValueHash })));
}

/** Review one actual Safe CALL to the Executor; target calls execute inside its action context. */
export function createMintFallbackSafeReview({ prepared, stage, safe, executorAbi }) {
  const operation = prepareMintFallbackGovernanceOperation(prepared, stage, safe);
  const batch = operation.prepared.batch, inspection = operation.prepared.inspection;
  const intent = `${stage} ${batch.plan.kind}: governance action ${batch.actionId}`;
  const safePlan = createSafeCallPlan(batch.plan.configuration.chainId, "Mint Manager fallback ceremony", [
    { safe: operation.caller, intent, call: operation.call, abi: executorAbi },
  ]);
  const review = Object.freeze({ stage, actionId: batch.actionId, actionClass: batch.plan.actionClass.toString(),
    proposer: operation.prepared.proposer, caller: operation.caller, executor: batch.plan.configuration.governance,
    blockNumber: inspection.blockNumber, blockHash: inspection.blockHash, nonce: batch.nonce.toString(),
    notBefore: batch.window.notBefore.toString(), expiresAfter: batch.window.expiresAfter.toString(),
    reasonHash: batch.window.reasonHash, reasonURI: batch.window.reasonURI, manifestHash: batch.window.manifestHash,
    callsHash: batch.callsHash, scopeHash: batch.scopeHash, oldValueHash: batch.oldValueHash, newValueHash: batch.newValueHash,
    targetCalls: targetReview(batch.plan), value: "0", operation: 0 });
  return Object.freeze({ operation, safePlan, review });
}

/** The original permissionless copying/completion paths also support an ordinary Safe CALL. */
export function createMintFallbackPermissionlessSafeReview({ inspection, plan, safe, targetAbi }) {
  const operation = prepareMintFallbackPermissionless(inspection, plan, safe);
  const safePlan = createSafeCallPlan(plan.configuration.chainId, "Copy or complete fallback accounting", [
    { safe: operation.caller, intent: plan.kind, call: operation.call, abi: targetAbi },
  ]);
  return Object.freeze({ operation, safePlan, review: targetReview(plan) });
}
