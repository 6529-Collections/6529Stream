import { prepareCollectionInventoryAppend, prepareCollectionInventoryScan } from "../dist/current-collection-inventory-workflow.js";
import { createSafeCallPlan } from "../dist/safe-plan.js";

/** Review the next bounded unsigned operation. Capture/read back before preparing its successor. */
export function createCollectionInventorySafeReview({ capture, safe, operation, inventoryAbi }) {
  if (!operation || !["append", "scan"].includes(operation.kind)) throw Error("Expected append or scan operation");
  const expected = operation.kind === "append" ? ["kind", "tokenIds"] : ["kind", "maxScan"];
  if (Object.keys(operation).sort().join() !== expected.sort().join()) throw Error("Unexpected operation fields");
  const preparation = operation.kind === "append"
    ? prepareCollectionInventoryAppend(capture, safe, operation.tokenIds)
    : prepareCollectionInventoryScan(capture, safe, operation.maxScan);
  const saved = preparation.capture, checkpoint = saved.checkpoint;
  const intent = operation.kind === "append"
    ? `Append ${preparation.tokenIds.length} completed tokens after actual collection serial ${checkpoint.lastIndexedSerial}`
    : `Scan at most ${preparation.maxScan} global allocated IDs after cursor ${checkpoint.scanThrough}`;
  const safePlan = createSafeCallPlan(saved.deployment.chainId, "Recover collection token inventory", [
    { safe: preparation.caller, intent, call: preparation.call, abi: inventoryAbi },
  ]);
  const review = Object.freeze({ collectionId: saved.coordinates.collectionId.toString(),
    blockNumber: saved.blockNumber, blockHash: saved.blockHash, caller: preparation.caller,
    inventory: saved.deployment.inventory.address, core: saved.deployment.core.address,
    indexedCount: checkpoint.indexedCount.toString(), prefixHash: checkpoint.prefixHash,
    lastIndexedSerial: checkpoint.lastIndexedSerial.toString(), scanThrough: checkpoint.scanThrough.toString(),
    frontier: saved.frontier.toString(), mintedEver: saved.mintedEver.toString(), completeAtCapture: saved.complete,
    value: "0", operation: 0, intent });
  return Object.freeze({ preparation, review, safePlan });
}
