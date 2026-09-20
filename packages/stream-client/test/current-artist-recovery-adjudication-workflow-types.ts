import type { Provider } from 'ethers';
import type { Address, Hex } from '../src/generated/contracts.js';
import { prepareArtistRecoveryAdjudicationCall, type ArtistRecoveryAdjudicationCoordinates, type ArtistRecoveryRequest, type ArtistRecoveryAuthorization, type ArtistRecoveryGovernanceWindow } from '../src/current-artist-recovery-adjudication.js';
import {
  captureArtistRecoveryAdjudication, simulateArtistRecoveryAdjudication, inspectArtistRecoveryAdjudicationReceipt,
  prepareArtistRecoveryAdjudicationGovernance, prepareArtistRecoveryAdjudicationOperation,
  simulateArtistRecoveryAdjudicationOperation, inspectArtistRecoveryAdjudicationOperationReceipt,
  type ArtistRecoveryAdjudicationDeployment, type ArtistRecoveryAdjudicationCapture, type ArtistRecoveryAdjudicationGovernanceReceipt,
} from '../src/current-artist-recovery-adjudication-workflow.js';

declare const provider: Provider;
declare const deployment: ArtistRecoveryAdjudicationDeployment;
declare const coords: ArtistRecoveryAdjudicationCoordinates;
declare const request: ArtistRecoveryRequest;
declare const acceptance: ArtistRecoveryAuthorization;
declare const actor: Address;
declare const manifestHash: Hex;
declare const transactionHash: Hex;
declare const window: ArtistRecoveryGovernanceWindow;
declare const captured: ArtistRecoveryAdjudicationCapture;
const call = prepareArtistRecoveryAdjudicationCall(coords, actor, { kind: 'identityRecoveryContextV2', request, acceptance, manifestHash });
const pending: Promise<ArtistRecoveryAdjudicationCapture> = captureArtistRecoveryAdjudication(provider, deployment, call, { blockTag: 123 });
void pending;
const observed: Promise<ArtistRecoveryAdjudicationCapture> = simulateArtistRecoveryAdjudication(provider, captured, { blockTag: 124 });
void observed;
const prep = prepareArtistRecoveryAdjudicationGovernance(captured, actor, 0n, window);
for (const stage of ['publish','schedule','register','execute'] as const) {
  const op = prepareArtistRecoveryAdjudicationOperation(prep, stage, actor);
  void simulateArtistRecoveryAdjudicationOperation(provider, op, { blockTag: 124 });
  const receipt: Promise<ArtistRecoveryAdjudicationGovernanceReceipt> = inspectArtistRecoveryAdjudicationOperationReceipt(provider, op, { transactionHash, execution: 'safe' });
  void receipt;
}
void inspectArtistRecoveryAdjudicationReceipt(provider, captured, { transactionHash, execution: 'direct' });
const returned: readonly unknown[] = captured.result;
const separateNonce: bigint | undefined = captured.recovery?.acceptanceHint;
const canonicalSelection = captured.recovery?.selection.result;
void returned; void separateNonce; void canonicalSelection;
// @ts-expect-error Moving block tags cannot pin recovery evidence.
void captureArtistRecoveryAdjudication(provider, deployment, call, { blockTag: 'latest' });
// @ts-expect-error Concrete deployment pins are required, not only pure coordinates.
void captureArtistRecoveryAdjudication(provider, coords, call, { blockTag: 1 });
// @ts-expect-error Caller is required for each actual governance step.
void prepareArtistRecoveryAdjudicationOperation(prep, 'execute');
// @ts-expect-error Protocol-only owner calls are not public workflow stages.
void prepareArtistRecoveryAdjudicationOperation(prep, 'recoverIdentityV2', actor);
// @ts-expect-error Delegatecall transport is excluded.
void inspectArtistRecoveryAdjudicationOperationReceipt(provider, prepareArtistRecoveryAdjudicationOperation(prep, 'execute', actor), { transactionHash, execution: 'delegatecall' });
// @ts-expect-error Revision is original uint64 bigint.
captured.ownerSnapshot.revision = 1;
// @ts-expect-error Captured helper pins are immutable.
deployment.evidence.codeHash = manifestHash;
// @ts-expect-error Retained selection evidence is immutable.
captured.recovery!.selection.progress.complete = true;
// @ts-expect-error Array results are immutable.
captured.result.push(1n);
