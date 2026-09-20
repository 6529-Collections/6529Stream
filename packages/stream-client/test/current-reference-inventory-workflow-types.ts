import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { ReferenceInventorySnapshot } from "../src/current-reference-inventory.js";
import {
  prepareReferenceInventoryPlan, inspectReferenceInventoryPreparation, simulateReferenceInventoryStep,
  quoteReferenceInventoryStepGas, inspectReferenceInventoryStepReceipt,
  type ReferenceInventoryDeployment, type ReferenceInventoryGasProvider, type ReferenceInventoryStepStatus,
} from "../src/current-reference-inventory-workflow.js";
import { toSafeCall } from "../src/safe.js";
declare const provider: Provider;
declare const gasProvider: ReferenceInventoryGasProvider;
declare const deployment: ReferenceInventoryDeployment;
declare const snapshot: ReferenceInventorySnapshot;
declare const preparer: Address;
declare const uploader: Address;
declare const hash: Hex;
const staged = prepareReferenceInventoryPlan(deployment, preparer, snapshot, { mode: "staged", uploader });
const monolithic = prepareReferenceInventoryPlan(deployment, preparer, snapshot, { mode: "monolithic" });
const operation: 0 = toSafeCall(staged.steps[0]!.call).operation;
const status: ReferenceInventoryStepStatus = { index: 0, status: "unnecessary", reason: "Full original already retained" };
void operation; void status; void monolithic;
void inspectReferenceInventoryPreparation(provider, staged, { blockTag: 1 });
void simulateReferenceInventoryStep(provider, staged, 0, { blockTag: 1 });
void quoteReferenceInventoryStepGas(gasProvider, staged, 0, { blockTag: 1, maximumGas: 100000n });
void inspectReferenceInventoryStepReceipt(provider, staged, 0, { transactionHash: hash, execution: "safe" });
// @ts-expect-error Mode is explicit; no automatic fallback to expensive monolithic preparation.
prepareReferenceInventoryPlan(deployment, preparer, snapshot, { mode: "auto" });
// @ts-expect-error Retained bytes and caller inputs are immutable.
staged.snapshot.rows[0]!.path = "changed";
// @ts-expect-error Part IDs cannot replace the original full rows in the plan.
prepareReferenceInventoryPlan(deployment, preparer, { partIds: [hash] }, { mode: "staged" });
// @ts-expect-error Reads and estimates require a concrete block number.
void inspectReferenceInventoryPreparation(provider, staged, { blockTag: "latest" });
// @ts-expect-error Generic ethers Provider does not offer pinned raw eth_estimateGas send.
void quoteReferenceInventoryStepGas(provider, staged, 0, { blockTag: 1 });
// @ts-expect-error Gas bounds are bigint.
void quoteReferenceInventoryStepGas(gasProvider, staged, 0, { blockTag: 1, maximumGas: 100000 });
// @ts-expect-error This workflow prepares inventories; it confers no publication authority.
const recorder = staged.authorization;
void recorder;
