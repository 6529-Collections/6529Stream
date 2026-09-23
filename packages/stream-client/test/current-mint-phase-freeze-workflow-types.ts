import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { MintPolicySnapshot } from "../src/current-mint-policy-grace.js";
import { CURRENT_MINT_PHASE_FREEZE_ABI, CURRENT_MINT_LEDGER_PHASE_FREEZE_ABI,
  type MintPhaseFreezeConfigurationInput, type MintPhaseFreezeGovernanceWindow, type MintPhaseFreezePlan } from "../src/current-mint-phase-freeze.js";
import { createSafeCallPlan, type SafeCallPlan } from "../src/safe-plan.js";
import { captureMintPhaseFreeze, prepareMintPhaseFreezeGovernance, prepareMintPhaseFreezeGovernanceOperation,
  simulateMintPhaseFreezeOperation, captureMintPhaseFreezeImport, prepareMintPhaseFreezeImportOperation,
  simulateMintPhaseFreezeImport, inspectMintPhaseFreezeReceipt, inspectMintPhaseFreezeImportReceipt,
  type MintPhaseFreezeCodePin, type MintPhaseFreezeDeployment, type MintPhaseFreezeScope,
  type MintPhaseFreezeCapture, type PreparedMintPhaseFreezeGovernance, type MintPhaseFreezeOperation,
  type MintPhaseFreezeSimulation, type MintPhaseFreezeImportScope, type MintPhaseFreezeImportCapture,
  type MintPhaseFreezeImportOperation, type MintPhaseFreezeReceipt, type MintPhaseFreezeImportReceipt } from "../src/current-mint-phase-freeze-workflow.js";

declare const provider: Provider;
declare const deployment: MintPhaseFreezeDeployment, scope: MintPhaseFreezeScope;
declare const capture: MintPhaseFreezeCapture, window: MintPhaseFreezeGovernanceWindow;
declare const actor: Address, publisher: Address, proposer: Address, executor: Address, hash: Hex;
declare const purePlan: MintPhaseFreezePlan;

const pendingCapture: Promise<MintPhaseFreezeCapture> = captureMintPhaseFreeze(provider, deployment, scope, { blockTag: 100 });
const classifier: PreparedMintPhaseFreezeGovernance = prepareMintPhaseFreezeGovernance(capture, "classifier", proposer, window);
const terminal: PreparedMintPhaseFreezeGovernance = prepareMintPhaseFreezeGovernance(capture, "freeze", proposer, window);
const publish: MintPhaseFreezeOperation = prepareMintPhaseFreezeGovernanceOperation(classifier, "publish", publisher);
const schedule: MintPhaseFreezeOperation = prepareMintPhaseFreezeGovernanceOperation(terminal, "schedule", proposer);
const execute: MintPhaseFreezeOperation = prepareMintPhaseFreezeGovernanceOperation(terminal, "execute", executor);
const simulation: Promise<MintPhaseFreezeSimulation> = simulateMintPhaseFreezeOperation(provider, execute, { blockTag: 200 });
const managerPin: MintPhaseFreezeCodePin = capture.deployment.manager;
const currentPolicy: MintPolicySnapshot | null = capture.phase.policy;
const constraints: MintPhaseFreezeConfigurationInput | null = capture.phase.constraints;
const originalPolicyProvenance: Hex = capture.phase.snapshot.record.policyHash;
const currentManagerPolicy: Hex = capture.phase.snapshot.currentPolicyHash;
const inheritedCeiling: readonly Address[] = capture.phase.executorCeiling;
const nonce: bigint = capture.governanceNonce, timestamp: bigint = capture.timestamp;
const selectorRevision: bigint = capture.selector.revision, value: bigint = execute.call.value;
const rowAdmission: "original-call-simulation-required" = capture.catalog.rowAdmission;
void pendingCapture; void publish; void schedule; void simulation; void managerPin; void currentPolicy; void constraints;
void originalPolicyProvenance; void currentManagerPolicy; void inheritedCeiling; void nonce; void timestamp; void selectorRevision; void value; void rowAdmission;

function checkedSimulation(result: MintPhaseFreezeSimulation): void {
  const blockNumber: number = result.blockNumber, at: bigint = result.timestamp;
  const observed: MintPhaseFreezeCapture | null = result.observed, commitment: Hex | null = result.guardianCommitment;
  if (result.guardians) {
    const count: bigint = result.guardians.globalHolderCount;
    const earliest: bigint = result.guardians.earliestVetoDeadline;
    const admission: "original-call-simulation-required" = result.guardians.admission;
    void count; void earliest; void admission;
  }
  void blockNumber; void at; void observed; void commitment;
}
void checkedSimulation;

// @ts-expect-error chain identity is exact uint256 bigint
captureMintPhaseFreeze(provider, { ...deployment, chainId: 1 }, scope, { blockTag: 100 });
// @ts-expect-error every runtime dependency requires its reviewed address and code hash
captureMintPhaseFreeze(provider, { ...deployment, manager: actor }, scope, { blockTag: 100 });
// @ts-expect-error an address without its exact runtime hash is insufficient
captureMintPhaseFreeze(provider, { ...deployment, ledger: { address: actor } }, scope, { blockTag: 100 });
// @ts-expect-error collection IDs are exact uint256 bigint
captureMintPhaseFreeze(provider, deployment, { ...scope, collectionId: 1 }, { blockTag: 100 });
// @ts-expect-error phase identity is bytes32, not a numeric ordinal
captureMintPhaseFreeze(provider, deployment, { ...scope, phaseId: 1n }, { blockTag: 100 });
// @ts-expect-error captures require a concrete block, not a moving tag
captureMintPhaseFreeze(provider, deployment, scope, { blockTag: "latest" });
// @ts-expect-error the concrete ethers block-number transport is an exact safe number
captureMintPhaseFreeze(provider, deployment, scope, { blockTag: 100n });
// @ts-expect-error a concrete capture block is mandatory
captureMintPhaseFreeze(provider, deployment, scope);
// @ts-expect-error read-only capture takes no signer or wallet authorization
captureMintPhaseFreeze(provider, deployment, scope, { blockTag: 100, signer: actor });
// @ts-expect-error original phase freeze has no re-enable or unfreeze kind
prepareMintPhaseFreezeGovernance(capture, "unfreeze", proposer, window);
// @ts-expect-error governance construction requires a captured runtime context, not a pure supplied-facts plan
prepareMintPhaseFreezeGovernance(purePlan, "freeze", proposer, window);
// @ts-expect-error proposer remains explicit and distinct from the Manager owner
prepareMintPhaseFreezeGovernance(capture, "freeze", window);
// @ts-expect-error exactly publish, schedule and execute are supported governance stages
prepareMintPhaseFreezeGovernanceOperation(terminal, "direct-owner-write", actor);
// @ts-expect-error the actual caller is mandatory for every stage
prepareMintPhaseFreezeGovernanceOperation(terminal, "publish");
// @ts-expect-error a review stage requires a prepared capture-bound governance batch
prepareMintPhaseFreezeGovernanceOperation(purePlan, "execute", actor);
// @ts-expect-error simulation is read-only and does not accept an injected signer
simulateMintPhaseFreezeOperation(provider, execute, { blockTag: 200, signer: actor });
// @ts-expect-error simulation block cannot be moving
simulateMintPhaseFreezeOperation(provider, execute, { blockTag: "pending" });
// @ts-expect-error supplied code pins are immutable after review
capture.deployment.manager.codeHash = hash;
// @ts-expect-error frozen inventory preserves its immutable observed order
capture.frozenInventory.push(scope);
// @ts-expect-error an inherited executor ceiling cannot be expanded through the capture
capture.phase.executorCeiling.push(actor);
// @ts-expect-error currentPolicyHash cannot overwrite retained first-freeze provenance
capture.phase.snapshot.record.policyHash = hash;
// @ts-expect-error configured terms must be checked for null for an unconfigured successor
const assumedConfigured: MintPolicySnapshot = capture.phase.policy;
// @ts-expect-error a supplied constraints observation cannot be treated as always configured
const assumedConstraints: MintPhaseFreezeConfigurationInput = capture.phase.constraints;
// @ts-expect-error no complete catalog row admission is claimed by a read-only capture
const provenAdmission: "catalog-row-verified" = capture.catalog.rowAdmission;
// @ts-expect-error original uint64 timestamps are immutable bigints
capture.phase.grace.graceUntil = 1;
// @ts-expect-error an operation retains its exact reviewed calldata
execute.call.data = hash;
// @ts-expect-error original class0/class2 discriminant cannot be replaced with a guessed class
terminal.batch.plan.actionClass = 1n;
void assumedConfigured; void assumedConstraints; void provenAdmission;

declare const importScope: MintPhaseFreezeImportScope, importCapture: MintPhaseFreezeImportCapture;
const pendingImport: Promise<MintPhaseFreezeImportCapture> = captureMintPhaseFreezeImport(provider, deployment, importScope, { blockTag: 300 });
const copy: MintPhaseFreezeImportOperation = prepareMintPhaseFreezeImportOperation(importCapture, actor, 32n);
const importSimulation = simulateMintPhaseFreezeImport(provider, copy, { blockTag: 301 });
const snapshotBlock: bigint = importCapture.commitment.snapshotBlock, importedCount: bigint = importCapture.progress.freezes.imported;
const requiredDefinitions: bigint = importCapture.progress.definitions.required, requiredAncestry: bigint = importCapture.progress.ancestry.required;
const predecessorPin: MintPhaseFreezeCodePin = importCapture.scope.predecessorManager;
const sameLedger: Address = importCapture.commitment.predecessorLedger;
const ordinal: bigint | undefined = importCapture.next[0]?.ordinal;
const successorPolicy: MintPolicySnapshot | null | undefined = importCapture.next[0]?.successor.policy;
const firstFrozenPolicy: Hex | undefined = importCapture.next[0]?.predecessor.snapshot.record.policyHash;
const completionBoundary: "original import completion additionally requires all definitions, ancestry and leaf proofs" = importCapture.completionBarrier;
const safeGovernance: SafeCallPlan = createSafeCallPlan(deployment.chainId, "Review terminal phase freeze", [
  { safe: execute.caller, intent: "Execute the reviewed terminal freeze", call: execute.call, abi: CURRENT_MINT_PHASE_FREEZE_ABI },
]);
const safeCopy: SafeCallPlan = createSafeCallPlan(deployment.chainId, "Review freeze continuity copy", [
  { safe: copy.caller, intent: "Copy bounded frozen-phase constraints", call: copy.call, abi: CURRENT_MINT_LEDGER_PHASE_FREEZE_ABI },
]);
void pendingImport; void importSimulation; void snapshotBlock; void importedCount; void requiredDefinitions; void requiredAncestry;
void predecessorPin; void sameLedger; void ordinal; void successorPolicy; void firstFrozenPolicy; void completionBoundary; void safeGovernance; void safeCopy;

// @ts-expect-error original import root is bytes32, not a numeric revision
captureMintPhaseFreezeImport(provider, deployment, { ...importScope, importRoot: 1n }, { blockTag: 300 });
// @ts-expect-error predecessor requires an exact runtime pin, not an unpinned address
captureMintPhaseFreezeImport(provider, deployment, { ...importScope, predecessorManager: actor }, { blockTag: 300 });
// @ts-expect-error this API does not accept an alternative caller-authored predecessor Ledger
captureMintPhaseFreezeImport(provider, deployment, { ...importScope, predecessorLedger: actor }, { blockTag: 300 });
// @ts-expect-error import inspection also requires one concrete block
captureMintPhaseFreezeImport(provider, deployment, importScope, { blockTag: "latest" });
// @ts-expect-error bounded import copies preserve exact uint256 bigint maxCount
prepareMintPhaseFreezeImportOperation(importCapture, actor, 32);
// @ts-expect-error a phase capture cannot substitute for the original committed import capture
prepareMintPhaseFreezeImportOperation(capture, actor, 32n);
// @ts-expect-error import copying retains explicit actual caller
prepareMintPhaseFreezeImportOperation(importCapture, 32n);
// @ts-expect-error governance operations cannot be submitted to the Ledger-copy simulation
simulateMintPhaseFreezeImport(provider, execute, { blockTag: 301 });
// @ts-expect-error a Ledger-copy operation is not an Executor governance stage
simulateMintPhaseFreezeOperation(provider, copy, { blockTag: 301 });
// @ts-expect-error no signature is supplied to permissionless import simulation
simulateMintPhaseFreezeImport(provider, copy, { blockTag: 301, signature: hash });
// @ts-expect-error captured import progress is immutable
importCapture.progress.freezes.imported = 1n;
// @ts-expect-error provenance stays immutable across later successors
importCapture.next[0]!.predecessor.snapshot.record.policyHash = hash;
// @ts-expect-error inherited executor rights cannot be expanded through the copied witness
importCapture.next[0]!.successor.executorCeiling.push(actor);
// @ts-expect-error Ledger commitment cannot be rewritten into a cross-Ledger import
importCapture.commitment.predecessorLedger = actor;
// @ts-expect-error source runtime pin cannot be overwritten after capture
importCapture.scope.predecessorManager.codeHash = hash;
// @ts-expect-error copy progress does not itself assert completion of the original import
const prematureCompletion: "complete" = importCapture.completionBarrier;
// @ts-expect-error the eventual successor may still be unconfigured
const configuredSuccessor: MintPolicySnapshot = importCapture.next[0]!.successor.policy;
// @ts-expect-error all inventory identities remain readonly
importCapture.predecessorInventory[0]!.collectionId = 1n;
// @ts-expect-error Safe call construction accepts exact calldata, not a replacement top-level signature
createSafeCallPlan(deployment.chainId, "Copy", [{ safe: copy.caller, intent: "Copy", call: copy.call, abi: CURRENT_MINT_LEDGER_PHASE_FREEZE_ABI, signature: hash }]);
void prematureCompletion; void configuredSuccessor;

const directReceipt: Promise<MintPhaseFreezeReceipt> = inspectMintPhaseFreezeReceipt(provider, schedule, { transactionHash: hash, execution: "direct" });
const safeReceipt: Promise<MintPhaseFreezeReceipt> = inspectMintPhaseFreezeReceipt(provider, execute, { transactionHash: hash, execution: "safe" });
const directCopyReceipt: Promise<MintPhaseFreezeImportReceipt> = inspectMintPhaseFreezeImportReceipt(provider, copy, { transactionHash: hash, execution: "direct" });
const safeCopyReceipt: Promise<MintPhaseFreezeImportReceipt> = inspectMintPhaseFreezeImportReceipt(provider, copy, { transactionHash: hash, execution: "safe" });
void directReceipt; void safeReceipt; void directCopyReceipt; void safeCopyReceipt;

function checkedReceipts(result: MintPhaseFreezeReceipt, imported: MintPhaseFreezeImportReceipt,
  simulated: Awaited<ReturnType<typeof simulateMintPhaseFreezeImport>>): void {
  const governanceObservation: MintPhaseFreezeCapture | null = result.observed;
  const eventIndex: number | undefined = result.events[0]?.logIndex;
  const copied: readonly bigint[] = imported.copiedOrdinals;
  const importObservation: MintPhaseFreezeImportCapture = imported.observed;
  const governanceAttribution: "events identify this operation; exact end-of-block phase state required" = result.stateAttribution;
  const importAttribution: "copy events identify this operation; progress is an end-of-block observation" = imported.stateAttribution;
  const simulatedOperation: MintPhaseFreezeImportOperation = simulated.operation;
  const simulatedObservation: MintPhaseFreezeImportCapture = simulated.observed;
  const returned: Hex = simulated.returnData;
  void governanceObservation; void eventIndex; void copied; void importObservation; void governanceAttribution; void importAttribution;
  void simulatedOperation; void simulatedObservation; void returned;
  // @ts-expect-error receipts do not permit overwriting exact copied ordinal evidence
  imported.copiedOrdinals.push(1n);
  // @ts-expect-error historical log coordinates are immutable
  result.events[0]!.logIndex = 1;
  // @ts-expect-error observed import progress cannot be rewritten after receipt inspection
  imported.observed.progress.freezes.imported = 2n;
  // @ts-expect-error publication receipt does not guarantee a phase-state observation
  const alwaysObserved: MintPhaseFreezeCapture = result.observed;
  // @ts-expect-error end-of-block observations do not claim that every state change belongs to this transaction
  const overclaim: "all state changes caused by this transaction" = imported.stateAttribution;
  // @ts-expect-error runtime-frozen simulation results are readonly in the public type too
  simulated.returnData = hash;
  void alwaysObserved; void overclaim;
}
void checkedReceipts;

// @ts-expect-error receipt provenance must name direct or ordinary Safe execution explicitly
inspectMintPhaseFreezeReceipt(provider, execute, { transactionHash: hash });
// @ts-expect-error Safe delegatecall is not a supported receipt transport
inspectMintPhaseFreezeReceipt(provider, execute, { transactionHash: hash, execution: "delegatecall" });
// @ts-expect-error transaction hash is bytes, not an integer
inspectMintPhaseFreezeReceipt(provider, execute, { transactionHash: 1n, execution: "safe" });
// @ts-expect-error supplied signatures are not receipt evidence
inspectMintPhaseFreezeReceipt(provider, execute, { transactionHash: hash, execution: "safe", signature: hash });
// @ts-expect-error phase governance receipts cannot authenticate a Ledger-copy operation
inspectMintPhaseFreezeReceipt(provider, copy, { transactionHash: hash, execution: "direct" });
// @ts-expect-error Ledger-copy receipts require the original import operation
inspectMintPhaseFreezeImportReceipt(provider, execute, { transactionHash: hash, execution: "direct" });
// @ts-expect-error copy receipts also reject delegated Safe execution
inspectMintPhaseFreezeImportReceipt(provider, copy, { transactionHash: hash, execution: "delegatecall" });
// @ts-expect-error copy receipt inspection does not receive an externally asserted completion flag
inspectMintPhaseFreezeImportReceipt(provider, copy, { transactionHash: hash, execution: "direct", complete: true });
