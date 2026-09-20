import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { TaggedPolicyViewV2Input } from "../src/current-tagged-policy-view-v2.js";
import {
  captureTaggedPolicyViewV2,
  preflightTaggedPolicyViewV2,
  simulateTaggedPolicyViewV2,
  inspectTaggedPolicyViewV2History,
  renderTaggedPolicyViewV2,
  observeTaggedPolicyViewV2Refusal,
  reconcileTaggedPolicyViewV2Receipt,
  type TaggedPolicyViewV2Deployment,
  type TaggedPolicyViewV2Capture,
  type TaggedPolicyViewV2HistoryDeployment,
  type TaggedPolicyViewV2ServingDeployment
} from "../src/current-tagged-policy-view-v2-workflow.js";

declare const provider: Provider;
declare const deployment: TaggedPolicyViewV2Deployment;
declare const history: TaggedPolicyViewV2HistoryDeployment;
declare const serving: TaggedPolicyViewV2ServingDeployment;
declare const caller: Address;
declare const input: TaggedPolicyViewV2Input;
declare const key: Hex;
declare const saved: TaggedPolicyViewV2Capture;

async function examples() {
  const preview = await preflightTaggedPolicyViewV2(provider, deployment, caller, input, { blockTag: 10 });
  const state: Hex = preview.consentTerms.newStateHash;
  const captured = await captureTaggedPolicyViewV2(provider, deployment, caller, input, { blockTag: 10 });
  const checked = await simulateTaggedPolicyViewV2(provider, captured, { blockTag: 11, gasLimit: 8_000_000n });
  const record = await inspectTaggedPolicyViewV2History(provider, history, checked.recordHash, { blockTag: 12 });
  const rendered = await renderTaggedPolicyViewV2(provider, serving, caller,
    { kind: "historicalTokenJSONForView", tokenId: 1n, recordHash: record.record.recordHash },
    { blockTag: 12, gasLimit: 8_000_000n });
  const output: string = rendered.output;
  const failure = await observeTaggedPolicyViewV2Refusal(provider, captured, { blockTag: 12, gasLimit: 8_000_000n });
  const outcome: "execution-reverted" | "rpc-failed" = failure.outcome;
  const receipt = await reconcileTaggedPolicyViewV2Receipt(provider, saved, key,
    { execution: "safe", expectedSafeTxHash: key });
  const revision: bigint = receipt.record.revision;
  void [state, output, outcome, revision];

  // @ts-expect-error The original target call has no payment value option.
  await captureTaggedPolicyViewV2(provider, deployment, caller, input, { blockTag: 10, value: 1n });
  // @ts-expect-error Safe evidence requires an independently known transaction hash.
  await reconcileTaggedPolicyViewV2Receipt(provider, saved, key, { execution: "safe" });
  // @ts-expect-error No delegatecall route exists.
  await reconcileTaggedPolicyViewV2Receipt(provider, saved, key, { execution: "delegatecall" });
  // @ts-expect-error Gas is a bounded bigint, not a floating point number.
  await simulateTaggedPolicyViewV2(provider, saved, { blockTag: 11, gasLimit: 100000 });
  // @ts-expect-error Immutable captures cannot mutate the scope.
  saved.preflight.input.scope.scopeId = key;
  // @ts-expect-error Current serving is addressed by scope, not a caller-supplied record hash.
  await renderTaggedPolicyViewV2(provider, serving, caller, { kind: "tokenJSONForView", tokenId: 1n, recordHash: key }, { blockTag: 12, gasLimit: 1n });
  // @ts-expect-error There is no VIEW finality workflow in this source profile.
  await renderTaggedPolicyViewV2(provider, serving, caller, { kind: "checkpointView", tokenId: 1n, scopeId: key }, { blockTag: 12, gasLimit: 1n });
}

void examples;
