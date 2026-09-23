import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import {
  captureScopedPolicyGraphV2,
  simulateScopedPolicyGraphV2,
  reconcileScopedPolicyGraphV2Receipt,
  inspectScopedPolicyGraphV2History,
  inspectScopedPolicyGraphV2Current,
  inspectScopedPolicyGraphV2Discovery,
  observeScopedPolicyGraphV2Refusal,
  type ScopedPolicyGraphV2Capture,
  type ScopedPolicyGraphV2Deployment,
  type ScopedPolicyGraphV2HistoryDeployment,
  type ScopedPolicyGraphV2DiscoveryDeployment
} from "../src/current-scoped-policy-graph-v2-workflow.js";
import type { ScopedPolicyGraphV2Scope } from "../src/current-scoped-policy-graph-v2.js";

declare const provider: Provider;
declare const deployment: ScopedPolicyGraphV2Deployment;
declare const local: ScopedPolicyGraphV2HistoryDeployment;
declare const discovery: ScopedPolicyGraphV2DiscoveryDeployment;
declare const capture: ScopedPolicyGraphV2Capture;
declare const caller: Address;
declare const hash: Hex;
declare const scope: ScopedPolicyGraphV2Scope;

void captureScopedPolicyGraphV2(provider, deployment, caller, { kind: "prepareSourceSet", scope }, { blockTag: 10 });
void captureScopedPolicyGraphV2(provider, deployment, caller, { kind: "prepareGraph", scope, maximumChildren: 7n }, { blockTag: 10 });
void simulateScopedPolicyGraphV2(provider, capture, { blockTag: 11, gasLimit: 10000000n });
void reconcileScopedPolicyGraphV2Receipt(provider, capture, hash, { execution: "direct" });
void reconcileScopedPolicyGraphV2Receipt(provider, capture, hash, { execution: "safe", expectedSafeTxHash: hash });
void inspectScopedPolicyGraphV2History(provider, local, hash, { blockTag: 11 });
void inspectScopedPolicyGraphV2Current(provider, deployment, scope, { blockTag: 11 });
void inspectScopedPolicyGraphV2Discovery(provider, discovery, scope, { blockTag: 11, includeRoutes: true, includeSanction: false });
void observeScopedPolicyGraphV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });

// @ts-expect-error The source factory takes no caller-supplied implementation.
void captureScopedPolicyGraphV2(provider, deployment, caller, { kind: "prepareSourceSet", scope, implementation: caller }, { blockTag: 10 });
// @ts-expect-error Fixed child limit is a bigint, preserving original uint8 semantics.
void captureScopedPolicyGraphV2(provider, deployment, caller, { kind: "prepareGraph", scope, maximumChildren: 7 }, { blockTag: 10 });
// @ts-expect-error Safe evidence requires an independently supplied transaction hash.
void reconcileScopedPolicyGraphV2Receipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error Concrete pinned blocks only.
void simulateScopedPolicyGraphV2(provider, capture, { blockTag: "latest", gasLimit: 10000000n });
// @ts-expect-error Captured operation is immutable.
capture.prepared.caller = caller;
// @ts-expect-error Captured source inventory is immutable.
capture.inventory.policies.push(capture.inventory.policies[0]!);

async function resultTypes() {
  const result = await inspectScopedPolicyGraphV2History(provider, local, hash, { blockTag: 11 });
  const currentness: false = result.currentnessChecked;
  const receipt = await reconcileScopedPolicyGraphV2Receipt(provider, capture, hash, { execution: "direct" });
  const afterCount: bigint = receipt.after.graph.preparedChildren;
  const refusal = await observeScopedPolicyGraphV2Refusal(provider, capture, { blockTag: 11, gasLimit: 10000000n });
  const unproven: false = refusal.rollbackProven;
  void [currentness, afterCount, unproven];
  // @ts-expect-error Retained graph arrays are immutable.
  result.graph.children[0] = caller;
}
void resultTypes;
