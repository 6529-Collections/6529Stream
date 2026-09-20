import { getAddress } from "ethers";
import { prepareReferenceInventory } from "../dist/current-reference-inventory.js";
import { prepareReferenceInventoryPlan } from "../dist/current-reference-inventory-workflow.js";
import { createSafeCallPlan } from "../dist/safe-plan.js";

/** Offline review of exact unsigned CALLs; no signing, submission or file execution. */
export function createReferenceInventorySafeReview({ deployment, uploaderSafe, preparerSafe,
  rows, relative, mode, storeAbi, publicationAbi, title = "Prepare reference file inventory" }) {
  const snapshot = prepareReferenceInventory(deployment.chainId, deployment.publicationHost.address, relative, rows);
  const preparation = prepareReferenceInventoryPlan(deployment, getAddress(preparerSafe), snapshot,
    { mode, uploader: getAddress(uploaderSafe) });
  const review = Object.freeze(preparation.steps.map(step => {
    const part = step.kind === "part" ? preparation.parts[step.documentIndex] : null;
    const chunk = step.kind === "upload" ? preparation.chunks[step.chunkIndex] : null;
    const firstRow = part ? part.rowOffset : 0;
    const count = chunk ? null : (part ? part.rows.length : snapshot.rows.length);
    const contentHash = chunk ? chunk.hash : (part ? part.contentHash : snapshot.contentHash);
    const byteLength = chunk ? BigInt((chunk.bytes.length - 2) / 2) : (part ? part.byteLength : snapshot.byteLength);
    const intent = chunk ? `Upload exact inventory chunk ${chunk.index + 1}: ${chunk.hash}`
      : part ? `Prepare part ${part.index + 1}, rows ${firstRow + 1} through ${firstRow + count}: ${part.partId}`
      : `${mode === "staged" ? "Assemble" : "Prepare monolithic"} complete ${snapshot.rows.length}-row inventory: ${snapshot.inventoryId}`;
    return Object.freeze({ index: step.index, kind: step.kind, safe: step.caller, target: step.call.to,
      identity: step.identity, contentHash, byteLength: byteLength.toString(), value: "0", operation: 0,
      firstRow: count === null || count === 0 ? null : String(firstRow + 1),
      rowCount: count === null ? null : String(count), intent });
  }));
  // Each page stays within the generic Safe review bound; firstStep preserves global order.
  const pages = [];
  for (let firstStep = 0; firstStep < preparation.steps.length; firstStep += 256) {
    const steps = preparation.steps.slice(firstStep, firstStep + 256);
    const abis = Object.freeze(steps.map(step => step.kind === "upload" ? storeAbi : publicationAbi));
    const safePlan = createSafeCallPlan(deployment.chainId, `${title} — calls ${firstStep + 1}–${firstStep + steps.length}`,
      steps.map((step, index) => ({ safe: step.caller, intent: review[step.index].intent, call: step.call, abi: abis[index] })));
    pages.push(Object.freeze({ firstStep, safePlan, abis }));
  }
  return Object.freeze({ preparation, review, pages: Object.freeze(pages) });
}
