import { CurrentRoyaltyContinuityClient, parseRoyaltyContinuityPlanJSON } from "../dist/current-royalty-continuity.js";

/**
 * Read and independently reproduce the complete frozen royalty continuity artifact.
 * `bindings` must come from a caller-selected successful compiler build.
 */
export async function captureRoyaltyContinuity(provider, chainId, deployment, bindings, uri, limits, blockTag = "latest") {
  const client = new CurrentRoyaltyContinuityClient(chainId, deployment, bindings);
  const plan = await client.capture(provider, uri, limits, blockTag);
  return { client, plan, governance: plan.transition, begin: client.begin(plan), canonicalManifest: plan.canonicalManifest };
}

/**
 * Reinspect every pinned dependency and prepare the next permissionless CALL.
 * This returns calldata only. It never signs, broadcasts, selects a Safe nonce, or changes Core.
 */
export async function prepareRoyaltyContinuityStep(provider, client, plan, caller, chunk, blockTag = "latest") {
  const prepared = await client.next(provider, plan, caller, chunk, blockTag);
  if (prepared.kind === "completed") return prepared;
  return { ...prepared, safeCall: client.safeCall(prepared.action) };
}

/** JSON-safe evidence representation. Decimal strings are labels for review, never parsed implicitly by the client. */
export function royaltyContinuityEvidenceJSON(plan) {
  return JSON.stringify(plan, (_key, value) => typeof value === "bigint" ? { $bigint: value.toString() } : value, 2) + "\n";
}

/** Reconstruct every saved commitment and bind it to historical capture provenance plus current state. */
export async function restoreRoyaltyContinuity(provider, chainId, deployment, bindings, savedJSON, blockTag = "latest") {
  const client = new CurrentRoyaltyContinuityClient(chainId, deployment, bindings);
  const restored = await client.restore(provider, parseRoyaltyContinuityPlanJSON(savedJSON), blockTag);
  return { client, ...restored };
}
