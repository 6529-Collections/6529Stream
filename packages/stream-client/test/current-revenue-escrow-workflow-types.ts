import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { RevenueEscrowCall } from "../src/current-revenue-escrow.js";
import type { MintFallbackGovernanceWindow } from "../src/current-mint-fallback.js";
import {
  captureRevenueEscrow,
  simulateRevenueEscrow,
  reconcileRevenueEscrowReceipt,
  prepareRevenueEscrowGovernanceStage,
  simulateRevenueEscrowGovernanceStage,
  reconcileRevenueEscrowGovernanceReceipt,
  inspectRevenueEscrowHistory,
  type RevenueEscrowCapture,
  type RevenueEscrowDeployment,
  type RevenueEscrowGovernanceStage,
} from "../src/current-revenue-escrow-workflow.js";

declare const provider: Provider;
declare const deployment: RevenueEscrowDeployment;
declare const prepared: RevenueEscrowCall;
declare const capture: RevenueEscrowCapture;
declare const stage: RevenueEscrowGovernanceStage;
declare const hash: Hex;
declare const caller: Address;
declare const window: MintFallbackGovernanceWindow;

async function examples() {
  const saved = await captureRevenueEscrow(provider, deployment, prepared, { blockTag: 10 });
  const simulation = await simulateRevenueEscrow(provider, saved, { blockTag: 11, gasLimit: 10_000_000n });
  await reconcileRevenueEscrowReceipt(provider, simulation.capture, hash, { execution: "safe", expectedSafeTxHash: hash });
  const operation = await prepareRevenueEscrowGovernanceStage(provider, capture, { stage: "schedule", caller, nonce: 0n, window, blockTag: 10 });
  const governance = await simulateRevenueEscrowGovernanceStage(provider, operation, { blockTag: 11, gasLimit: 10_000_000n });
  await reconcileRevenueEscrowGovernanceReceipt(provider, governance.operation, hash, { execution: "direct" });
  const history = await inspectRevenueEscrowHistory(provider, { chainId: 1n, escrow: deployment.escrow }, { recoveryId: hash }, { blockTag: 10 });
  if (history.record) { const amount: bigint = history.record.expectedAmount; void amount; }
  // @ts-expect-error immutable returned observation
  history.observed.timestamp = 0n;
  // @ts-expect-error immutable simulation envelope
  governance.gasLimit = 0n;
  // @ts-expect-error immutable captured factory metadata
  saved.deployment.origin.factory.codeHash = hash;
  // @ts-expect-error immutable original request
  saved.prepared.caller = caller;
}
void examples;
// @ts-expect-error concrete block number required
captureRevenueEscrow(provider, deployment, prepared, { blockTag: "latest" });
// @ts-expect-error gas limit must be explicit
simulateRevenueEscrow(provider, capture, { blockTag: 11 });
// @ts-expect-error no Safe success inferred from its own event
reconcileRevenueEscrowReceipt(provider, capture, hash, { execution: "safe" });
// @ts-expect-error only ordinary CALL transports
reconcileRevenueEscrowReceipt(provider, capture, hash, { execution: "delegatecall" });
// @ts-expect-error governance and target receipt families are distinct
reconcileRevenueEscrowReceipt(provider, stage, hash, { execution: "direct" });
// @ts-expect-error explicit governance caller required
prepareRevenueEscrowGovernanceStage(provider, capture, { stage: "publish", nonce: 0n, window, blockTag: 10 });
