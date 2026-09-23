import { CurrentInventoryWorkflow, type InventoryWorkflowStart, type SavedInventoryWorkflow } from "../src/index.js";
declare const workflow: CurrentInventoryWorkflow;
declare const provider: Parameters<CurrentInventoryWorkflow["resume"]>[0];
declare const input: InventoryWorkflowStart;
declare const saved: SavedInventoryWorkflow;
workflow.start(provider, input);
workflow.resume(provider, saved);
// @ts-expect-error restore requires the original independent commitment
workflow.restore(saved.json);
// @ts-expect-error grant coordinates retain full-width bigint
workflow.start(provider, { ...input, deposits: [{ ...input.deposits[0]!, grant: { ...input.deposits[0]!.grant, tokenId: 9 } }] });
// @ts-expect-error transaction values are not a new inventory-opening allowance
workflow.start(provider, { ...input, value: 1n });
// @ts-expect-error only original EOA/Safe caller coordinates are accepted, no delegate-spend field
workflow.start(provider, { ...input, executorAllowance: 1n });
