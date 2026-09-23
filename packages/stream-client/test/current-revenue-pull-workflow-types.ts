import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import {
  captureRevenuePull, simulateRevenuePull, inspectRevenuePullReceipt,
} from "../src/current-revenue-pull-workflow.js";
import type { RevenuePullDeployment, RevenuePullCapture } from "../src/current-revenue-pull-workflow.js";
import type { PreparedRevenuePullCall } from "../src/current-revenue-pull.js";

declare const provider: Provider;
declare const deployment: RevenuePullDeployment;
declare const prepared: PreparedRevenuePullCall;
declare const capture: RevenuePullCapture;
declare const hash: Hex;
declare const address: Address;
const observed = await captureRevenuePull(provider, deployment, prepared, { blockTag: 1 });
const simulation = await simulateRevenuePull(provider, observed, { blockTag: 2, gasLimit: 1000000n });
const returned: readonly bigint[] = simulation.amounts;
const direct = await inspectRevenuePullReceipt(provider, capture, { transactionHash: hash, execution: "direct" });
const safe = await inspectRevenuePullReceipt(provider, capture, { transactionHash: hash, execution: "safe", expectedSafeTxHash: hash });
const amount: bigint | null = safe.items[0]!.amount;
const operation: "syncAsset" | "release" | undefined = direct.items[0]?.failure?.operation;
// @ts-expect-error concrete numeric block required
await captureRevenuePull(provider, deployment, prepared, { blockTag: "latest" });
// @ts-expect-error independent Safe hash required
await inspectRevenuePullReceipt(provider, capture, { transactionHash: hash, execution: "safe" });
// @ts-expect-error gas is full-width bigint
await simulateRevenuePull(provider, capture, { blockTag: 2, gasLimit: 1000000 });
// @ts-expect-error capture is immutable
observed.prepared.caller = address;
// @ts-expect-error deployment pins are readonly
deployment.assets.push({ address, codeHash: hash });
// @ts-expect-error simulated amounts never claim mined receipt semantics
simulation.transactionHash;
void [returned, amount, operation];
