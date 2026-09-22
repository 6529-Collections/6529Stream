import {
  CURRENT_ARTIST_COLLABORATOR_ABI, prepareCollaboratorCall, normalizeCollaboratorCall,
  prepareCollaboratorRead, decodeCollaboratorRead, normalizeCollaboratorTerms,
  collaboratorIdentityId, primaryOnlyCollaboratorBindingHash,
  type CollaboratorRequest, type CollaboratorIdentityProposal, type CollaboratorAuthorization,
  type CollaboratorBindingAcceptance, type CollaboratorBinding, type CollaboratorTerm,
  type CollaboratorIdentityProposalState, type CollaboratorRow,
} from "../src/current-artist-collaborator.js";
import { createSafeCallPlan } from "../src/safe-plan.js";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { Provider } from "ethers";
import type { CurrentArtistDeployment } from "../src/current-artist-workflow.js";
import {
  captureCollaborator, simulateCollaborator, createCollaboratorSafePlan, inspectCollaboratorReceipt,
  type CollaboratorCapture, type CollaboratorReceipt,
} from "../src/current-artist-collaborator-workflow.js";

declare const account: Address, registry: Address, core: Address, hash: Hex, bytes: Hex;
declare const proposal: CollaboratorIdentityProposal, authorization: CollaboratorAuthorization;
declare const terms: CollaboratorBindingAcceptance, binding: CollaboratorBinding;
declare const rows: readonly CollaboratorTerm[];
const context = { chainId: 1n, registry, caller: account };
const proposalRequest: CollaboratorRequest = { ...context, kind: "proposeIdentity", proposal };
const identityRequest: CollaboratorRequest = { ...context, kind: "acceptIdentity", account, identityRecordHash: hash, authorization, document: bytes, displayName: "Artist" };
const rowRequest: CollaboratorRequest = { ...context, kind: "acceptRow", core, terms, authorization };
for (const request of [proposalRequest, identityRequest, rowRequest]) {
  const prepared = prepareCollaboratorCall(request);
  const operation: 5 | 6 | 7 = prepared.operation;
  const unverified: false = prepared.factsVerified;
  normalizeCollaboratorCall(prepared);
  createSafeCallPlan(context.chainId, "Collaborator", [{ safe: account, intent: `Operation ${operation}`, call: prepared.call, abi: CURRENT_ARTIST_COLLABORATOR_ABI }]);
  void unverified;
  // @ts-expect-error Prepared calls are immutable.
  prepared.call.data = bytes;
}
normalizeCollaboratorTerms(rows);
collaboratorIdentityId(1n, registry, account, hash, 0n);
primaryOnlyCollaboratorBindingHash(1n, registry, core, 1n, binding, rows);
prepareCollaboratorRead(registry, "collaboratorIdentityProposal", [account, hash]);
prepareCollaboratorRead(registry, "collaboratorRegistrationNonceState", [account, 0n]);
prepareCollaboratorRead(registry, "collaboratorCount", [1n, 1n]);
prepareCollaboratorRead(registry, "collaboratorAt", [1n, 1n, 0n]);
prepareCollaboratorRead(registry, "collaboratorPayoutAccount", [hash, account]);
const proposalState: CollaboratorIdentityProposalState = decodeCollaboratorRead("collaboratorIdentityProposal", bytes);
const nonce: { readonly used: boolean; readonly firstUnused: bigint } = decodeCollaboratorRead("collaboratorRegistrationNonceState", bytes);
const count: bigint = decodeCollaboratorRead("collaboratorCount", bytes);
const row: CollaboratorRow = decodeCollaboratorRead("collaboratorAt", bytes);
const payout: { readonly payoutAccount: Address; readonly designationRecordHash: Hex } = decodeCollaboratorRead("collaboratorPayoutAccount", bytes);
void [proposalState, nonce, count, row, payout];

// @ts-expect-error Protocol integers cannot be JS numbers.
prepareCollaboratorCall({ ...rowRequest, chainId: 1 });
// @ts-expect-error Operation 7 requires its signed Core context.
prepareCollaboratorCall({ ...context, kind: "acceptRow", terms, authorization });
// @ts-expect-error Identity acceptance requires exact document bytes.
prepareCollaboratorCall({ ...context, kind: "acceptIdentity", account, identityRecordHash: hash, authorization, displayName: "Artist" });
// @ts-expect-error Proposal cannot carry acceptance authorization.
prepareCollaboratorCall({ ...proposalRequest, authorization });
// @ts-expect-error No new payout mutation is introduced.
prepareCollaboratorCall({ ...context, kind: "collaboratorPayout", account });
// @ts-expect-error Authorization nonce is bigint.
prepareCollaboratorCall({ ...identityRequest, authorization: { ...authorization, nonce: 0 } });
// @ts-expect-error Generation is bigint.
prepareCollaboratorCall({ ...rowRequest, terms: { ...terms, generation: 1 } });
// @ts-expect-error The read method set is closed.
prepareCollaboratorRead(registry, "acceptCollaborator", [terms, authorization]);
// @ts-expect-error At requires the explicit index argument.
prepareCollaboratorRead(registry, "collaboratorAt", [1n, 1n]);
// @ts-expect-error Count accepts bigint generation.
prepareCollaboratorRead(registry, "collaboratorCount", [1n, 1]);
// @ts-expect-error Payout order is identity hash then account, not an integer.
prepareCollaboratorRead(registry, "collaboratorPayoutAccount", [1n, account]);
// @ts-expect-error Count result is a bigint, not a collaborator row.
const invalidRow: CollaboratorRow = decodeCollaboratorRead("collaboratorCount", bytes);
// @ts-expect-error Returned proposal state is deeply readonly.
proposalState.proposal.account = account;
// @ts-expect-error Original PRIMARY_ONLY API has no multiparty threshold input.
primaryOnlyCollaboratorBindingHash(1n, registry, core, 1n, { ...binding, threshold: 2n }, rows);
void invalidRow;

declare const provider: Provider, deployment: CurrentArtistDeployment;
async function workflowTypes(): Promise<void> {
  const captured: CollaboratorCapture = await captureCollaborator(provider, deployment, prepareCollaboratorCall(rowRequest), { blockTag: 10 });
  const unverified: false | undefined = captured.signing?.signatureVerified;
  const requiresSimulation: true = captured.simulationRequired;
  const simulation = await simulateCollaborator(provider, captured, { gasLimit: 5_000_000n, blockTag: 11 });
  const targetOnly: true = simulation.targetCallOnly;
  const simulatedHash: Hex = simulation.recordHash;
  createCollaboratorSafePlan(simulation.observation, { safe: account, title: "Accept collaborator row" });
  const receipt: CollaboratorReceipt = await inspectCollaboratorReceipt(provider, captured, { transactionHash: hash, execution: "safe" });
  const historicalOnly: true = receipt.historicalEvidenceOnly;
  const actualCount: bigint | undefined = receipt.completion?.count;
  const allocatedId: Hex | null = receipt.artistId;
  void [unverified, requiresSimulation, targetOnly, simulatedHash, historicalOnly, actualCount, allocatedId];

  // @ts-expect-error Observations cannot be relabeled as verified signatures.
  captured.signing!.signatureVerified = true;
  // @ts-expect-error Captured collaborator rows are deeply readonly.
  captured.row!.rows[0]!.accepted = true;
  // @ts-expect-error Capture requires a concrete numbered observation block.
  await captureCollaborator(provider, deployment, prepareCollaboratorCall(rowRequest), { blockTag: "latest" });
  // @ts-expect-error Simulation requires an explicit bigint gas bound.
  await simulateCollaborator(provider, captured, { gasLimit: 5_000_000 });
  // @ts-expect-error Simulation cannot omit its gas bound.
  await simulateCollaborator(provider, captured, {});
  // @ts-expect-error Safe plan binds the actual Safe address explicitly.
  createCollaboratorSafePlan(captured, { title: "Missing Safe" });
  // @ts-expect-error No batch delegatecall receipt mode is supplied by this family.
  await inspectCollaboratorReceipt(provider, captured, { transactionHash: hash, execution: "delegatecall" });
  // @ts-expect-error Historical evidence cannot be changed into an execution assertion.
  receipt.historicalEvidenceOnly = false;
}
void workflowTypes;
