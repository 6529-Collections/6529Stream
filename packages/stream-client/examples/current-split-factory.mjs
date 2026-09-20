import { prepareSplitFactoryOperation } from "../dist/current-split-factory-workflow.js";
import { createSafeCallPlan } from "../dist/safe-plan.js";

/** One original factory CALL from the actual Safe; this never signs or broadcasts. */
export function createSplitFactorySafeReview({ capture, profile, kind, safe, factoryAbi }) {
  const operation = prepareSplitFactoryOperation(capture, profile, kind, safe);
  const reviewed = operation.prepared.request.profile, context = reviewed.context;
  const safePlan = createSafeCallPlan(context.chainId, "Split profile and wallet", [
    { safe: operation.caller, intent: `${kind}: profile ${reviewed.profileId}`, call: operation.call, abi: factoryAbi },
  ]);
  const review = Object.freeze({ kind, caller: operation.caller, factory: context.factory,
    profileId: reviewed.profileId, predictedWallet: reviewed.wallet, predictionOnly: true,
    schemaVersion: context.schemaVersion.toString(), walletVersion: context.walletVersion.toString(),
    entriesHash: reviewed.entriesHash, metadataURIHash: reviewed.metadataURIHash,
    entries: Object.freeze(reviewed.entries.map(row => Object.freeze({ ...row, sharePpm: row.sharePpm.toString() }))),
    implementation: operation.capture.snapshot.implementation, initCodeHash: context.initCodeHash,
    runtimeCodeHash: context.runtimeCodeHash, blockNumber: operation.capture.blockNumber,
    blockHash: operation.capture.blockHash, value: "0", operation: 0 });
  return Object.freeze({ operation, safePlan, review });
}
