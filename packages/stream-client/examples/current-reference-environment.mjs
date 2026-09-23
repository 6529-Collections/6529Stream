import { prepareReferenceEnvironment } from "../dist/current-reference-environment.js";
import { prepareReferenceEnvironmentPlan } from "../dist/current-reference-environment-workflow.js";
import { createSafeCallPlan } from "../dist/safe-plan.js";

/** Exact unsigned uploads and complete typed preparation; never signs, submits or publishes a reference. */
export function createReferenceEnvironmentSafeReview({ deployment, environment, uploaderSafe, preparerSafe, storeAbi, publicationAbi }) {
  const snapshot = prepareReferenceEnvironment(deployment.chainId, deployment.publicationHost.address, environment);
  const preparation = prepareReferenceEnvironmentPlan(deployment, preparerSafe, snapshot, { uploader: uploaderSafe });
  const review = Object.freeze(preparation.steps.map(step => Object.freeze({ index: step.index, kind: step.kind,
    caller: step.caller, target: step.call.to, identity: step.identity, value: "0", operation: 0,
    intent: step.kind === "upload" ? `Upload environment chunk ${step.chunkIndex + 1}: ${step.identity}`
      : `Prepare complete original environment: ${snapshot.environmentId}` })));
  const abis = Object.freeze(preparation.steps.map(step => step.kind === "upload" ? storeAbi : publicationAbi));
  const safePlan = createSafeCallPlan(deployment.chainId, "Prepare reference environment",
    preparation.steps.map((step, index) => ({ safe: step.caller, intent: review[index].intent, call: step.call, abi: abis[index] })));
  return Object.freeze({ preparation, safePlan, abis, review,
    prerequisites: Object.freeze({ packageInventory: snapshot.packageInventory.inventoryId, platformInventory: snapshot.platformInventory.inventoryId }) });
}
