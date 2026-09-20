import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import * as workflow from "../src/current-museum-anchor-master-workflow.js";
import * as pure from "../src/current-museum-anchor-master.js";
import { createSafeCallPlan } from "../src/safe-plan.js";

declare const provider: Provider;
declare const anchor: workflow.MuseumAnchorDeployment;
declare const deployment: workflow.MuseumMasterDeployment;
declare const candidate: workflow.MuseumCodePin;
declare const actor: Address;
declare const hash: Hex;
declare const window: pure.MuseumAnchorGovernanceWindow;
declare const preparedCall: pure.MuseumAnchorMasterCall;
declare const capture: workflow.MuseumMasterCapture;
declare const anchorCapture: workflow.MuseumAnchorCapture;

async function examples(): Promise<void> {
  const c = await workflow.captureMuseumAnchorBinding(provider, anchor, "conditionSources", candidate, { blockTag: 1 });
  const count: bigint = c.sourceHead.count;
  const klass: 1n = c.plan.actionClass;
  void count; void klass;
  await workflow.captureMuseumAnchorBinding(provider, anchor, "conservationFloor", candidate, { blockTag: 1 });
  const governance = workflow.prepareMuseumAnchorGovernance(c, actor, window);
  const op = workflow.prepareMuseumAnchorGovernanceOperation(governance, "schedule", actor);
  await workflow.simulateMuseumAnchorGovernance(provider, op, { blockTag: 2 });
  const receipt = await workflow.inspectMuseumAnchorGovernanceReceipt(provider, op,
    { transactionHash: hash, execution: "safe", expectedSafeTxHash: hash });
  const binding: pure.MuseumAnchorBindingState | null = receipt.binding;
  void binding;
  const tier = await workflow.readMuseumConservationTier(provider, anchor, 1n, { blockTag: 1 });
  const exists: boolean = tier.exists;
  const completed: bigint = tier.completedMints;
  void exists; void completed;
  const current = await workflow.captureMuseumAnchorMaster(provider, deployment, preparedCall, { blockTag: 1 });
  const observed = await workflow.simulateMuseumAnchorMaster(provider, current, { blockTag: 2 });
  const master = await workflow.inspectMuseumAnchorMasterReceipt(provider, current, { transactionHash: hash, execution: "direct" });
  const selection: pure.MuseumMasterSelection | null = master.selection;
  const original: workflow.MuseumMasterStoredRecord | null = master.original;
  void selection; void original;
  const retained = await workflow.readMuseumMasterSelection(provider, deployment, { collectionId: 1n, subjectId: hash, slot: 1n, revision: 1n }, { blockTag: 3 });
  const revision: bigint | null = retained.revision;
  void revision;
  const closure = await workflow.requireMuseumCollectionMasters(provider, deployment, 1n, { blockTag: 3 });
  const factsHash: Hex = closure.factsHash;
  void factsHash;
  createSafeCallPlan(1n, "Museum evidence", [{ safe: actor, intent: "Adopt retained evidence", call: current.prepared.call, abi: pure.CURRENT_MUSEUM_ANCHOR_MASTER_ABI }]);
  // @ts-expect-error immutable nested runtime pins
  current.deployment.artist.identity.codeHash = hash;
  // @ts-expect-error immutable typed capture
  current.expectedSelection = null;
  // @ts-expect-error immutable returned simulation
  observed.returnData = hash;
  // @ts-expect-error immutable original event references
  receipt.events.push({});
}
void examples;
// @ts-expect-error caller-independent view still requires a concrete block
workflow.readMuseumConservationTier(provider, anchor, 1n, { blockTag: "latest" });
// @ts-expect-error exact bigint collection coordinate
workflow.requireMuseumCollectionMasters(provider, deployment, 1, { blockTag: 1 });
// @ts-expect-error floor settlement receipts are outside this anchor profile
workflow.captureMuseumAnchorBinding(provider, anchor, "recordPrimarySale", candidate, { blockTag: 1 });
// @ts-expect-error no delegation or inferred onchain signer flow
workflow.captureMuseumAnchorMaster(provider, deployment, { kind: "delegatedWaiver" }, { blockTag: 1 });
// @ts-expect-error Safe needs independent transaction hash
workflow.inspectMuseumAnchorMasterReceipt(provider, capture, { transactionHash: hash, execution: "safe" });
// @ts-expect-error direct path does not accept irrelevant Safe identity
workflow.inspectMuseumAnchorMasterReceipt(provider, capture, { transactionHash: hash, execution: "direct", expectedSafeTxHash: hash });
// @ts-expect-error generic Delegatecall transport is unsupported
workflow.inspectMuseumAnchorMasterReceipt(provider, capture, { transactionHash: hash, execution: "delegatecall" });
// @ts-expect-error no omitted proposer/window
workflow.prepareMuseumAnchorGovernance(anchorCapture, actor);
// @ts-expect-error no implicit calldata preparation from operation60/other profiles
workflow.simulateMuseumAnchorMaster(provider, anchorCapture, { blockTag: 2 });
