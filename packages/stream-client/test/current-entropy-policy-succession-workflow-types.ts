import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import {
  captureEntropyPolicySuccession, prepareEntropyPolicySuccession,
  prepareEntropyPolicySuccessionGovernance, entropyPolicySuccessionCall,
  entropyPolicySuccessionGovernanceCall, simulateEntropyPolicySuccession,
  reconcileEntropyPolicySuccessionReceipt,
  type EntropyPolicySuccessionDeployment, type EntropyPolicySuccessionCapture,
  type EntropyPolicySuccessionInspection, type EntropyPolicySuccessionOperation,
  type EntropyPolicySuccessionReceiptEvidence,
} from "../src/current-entropy-policy-succession-workflow.js";
import type { EntropyPolicySuccessionGovernanceWindow, EntropyPolicySuccessionCatalogInventory, EntropyPolicySuccessionCatalogHistory } from "../src/current-entropy-policy-succession.js";
import type { MintFallbackManifestUpdate } from "../src/current-mint-fallback.js";

declare const provider: Provider;
declare const deployment: EntropyPolicySuccessionDeployment;
declare const capture: EntropyPolicySuccessionCapture;
declare const inspection: EntropyPolicySuccessionInspection;
declare const actor: Address;
declare const hash: Hex;
declare const window: EntropyPolicySuccessionGovernanceWindow;
declare const inventory: EntropyPolicySuccessionCatalogInventory;
declare const baseHistory: EntropyPolicySuccessionCatalogHistory;
declare const update: MintFallbackManifestUpdate;

async function coverage(): Promise<void> {
  const c = await captureEntropyPolicySuccession(provider, deployment, { blockTag: 1 });
  const ready: boolean = c.ready;
  const state: 0n | 1n | 2n | 3n = c.receipt.state;
  void ready; void state;
  const steps = [
    await prepareEntropyPolicySuccession(provider, c, { kind: "begin", manifestHash: hash }),
    await prepareEntropyPolicySuccession(provider, c, { kind: "copy", expectedIndex: 0n }),
    await prepareEntropyPolicySuccession(provider, c, { kind: "confirm-route", collectionId: 1n }),
    await prepareEntropyPolicySuccession(provider, c, { kind: "admit-route", collectionId: 1n }),
    await prepareEntropyPolicySuccession(provider, c, { kind: "seal" }),
    await prepareEntropyPolicySuccession(provider, c, { kind: "cutover", payload: actor, update }),
    await prepareEntropyPolicySuccession(provider, c, { kind: "catalog", inventory, baseHistory, deploymentHash: hash, completedRows: 0n, payload: actor, update }),
  ];
  const permissionless: EntropyPolicySuccessionOperation = entropyPolicySuccessionCall(steps[1]!, actor);
  const governance = prepareEntropyPolicySuccessionGovernance(steps[0]!, actor, window);
  const op = entropyPolicySuccessionGovernanceCall(governance, "execute", actor);
  const simulation = await simulateEntropyPolicySuccession(provider, op, { blockTag: 2, gasLimit: 1_000_000n });
  const future: false = simulation.futureExecutionGuaranteed;
  void future; void permissionless;
  const direct: EntropyPolicySuccessionReceiptEvidence = { transport: "direct", transactionHash: hash };
  const safe: EntropyPolicySuccessionReceiptEvidence = { transport: "safe", transactionHash: hash, safe: actor, safeTransactionHash: hash };
  const result = await reconcileEntropyPolicySuccessionReceipt(provider, op, direct);
  await reconcileEntropyPolicySuccessionReceipt(provider, op, safe);
  const publication: "created" | "reused" | null = result.publication;
  const after: EntropyPolicySuccessionCapture | null = result.after;
  void publication; void after;
  // @ts-expect-error immutable observations
  c.receipt.state = 3n;
  // @ts-expect-error immutable runtime pin
  c.deployment.candidate.codeHash = hash;
  // @ts-expect-error immutable operation caller
  op.caller = actor;
  // @ts-expect-error immutable simulation evidence
  simulation.returnData = hash;
}
void coverage;
// @ts-expect-error current block is concrete, never moving latest
captureEntropyPolicySuccession(provider, deployment, { blockTag: "latest" });
// @ts-expect-error bigint collection identities
prepareEntropyPolicySuccession(provider, capture, { kind: "confirm-route", collectionId: 1 });
// @ts-expect-error no standalone activation lane
prepareEntropyPolicySuccession(provider, capture, { kind: "activate" });
// @ts-expect-error cutover requires mandatory manifest tail
prepareEntropyPolicySuccession(provider, capture, { kind: "cutover" });
// @ts-expect-error no arbitrary catalog additions without retained history
prepareEntropyPolicySuccession(provider, capture, { kind: "catalog", additions: [] });
// @ts-expect-error caller is mandatory
entropyPolicySuccessionCall(inspection);
// @ts-expect-error no delegatecall transport
const bad: EntropyPolicySuccessionReceiptEvidence = { transport: "delegatecall", transactionHash: hash };
void bad;
