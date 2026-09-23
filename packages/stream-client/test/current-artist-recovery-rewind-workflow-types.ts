import type { Provider } from 'ethers';
import type { Address, Hex } from '../src/generated/contracts.js';
import type { ArtistRecoveryRequest, ArtistRecoveryAuthorization, ArtistRecoveryGovernanceWindow } from '../src/current-artist-recovery-adjudication.js';
import { prepareArtistRecoveryRewindCall, type ArtistRecoveryRewindCoordinates } from '../src/current-artist-recovery-rewind.js';
import {
  captureArtistRecoveryRewind, simulateArtistRecoveryRewind, inspectArtistRecoveryRewindReceipt,
  prepareArtistRecoveryRewindGovernance, prepareArtistRecoveryRewindOperation,
  simulateArtistRecoveryRewindOperation, inspectArtistRecoveryRewindOperationReceipt,
  type ArtistRecoveryRewindDeployment, type ArtistRecoveryRewindCapture, type ArtistRecoveryRewindGovernanceReceipt,
} from '../src/current-artist-recovery-rewind-workflow.js';

declare const provider: Provider;
declare const deployment: ArtistRecoveryRewindDeployment;
declare const coords: ArtistRecoveryRewindCoordinates;
declare const request: ArtistRecoveryRequest;
declare const acceptance: ArtistRecoveryAuthorization;
declare const actor: Address;
declare const manifestHash: Hex;
declare const transactionHash: Hex;
declare const window: ArtistRecoveryGovernanceWindow;
declare const captured: ArtistRecoveryRewindCapture;
const call = prepareArtistRecoveryRewindCall(coords, actor, { kind: 'identityRecoveryContextV3', request, acceptance, manifestHash });
const pending: Promise<ArtistRecoveryRewindCapture> = captureArtistRecoveryRewind(provider, deployment, call, { blockTag: 123 });
void pending;
const observed: Promise<ArtistRecoveryRewindCapture> = simulateArtistRecoveryRewind(provider, captured, { blockTag: 124 });
void observed;
const prep = prepareArtistRecoveryRewindGovernance(captured, actor, 0n, window);
for (const stage of ['publish','schedule','register','execute'] as const) {
  const op = prepareArtistRecoveryRewindOperation(prep, stage, actor);
  void simulateArtistRecoveryRewindOperation(provider, op, { blockTag: 124 });
  const receipt: Promise<ArtistRecoveryRewindGovernanceReceipt> = inspectArtistRecoveryRewindOperationReceipt(provider, op, { transactionHash, execution: 'safe' });
  void receipt;
}
void inspectArtistRecoveryRewindReceipt(provider, captured, { transactionHash, execution: 'direct' });
const returned: readonly unknown[] = captured.result;
const separateNonce: bigint | undefined = captured.recovery?.acceptanceHint;
const canonicalSelection = captured.recovery?.selection.result;
void returned; void separateNonce; void canonicalSelection;
// @ts-expect-error Moving block tags cannot pin recovery evidence.
void captureArtistRecoveryRewind(provider, deployment, call, { blockTag: 'latest' });
// @ts-expect-error Concrete deployment pins are required, not only pure coordinates.
void captureArtistRecoveryRewind(provider, coords, call, { blockTag: 1 });
// @ts-expect-error Caller is required for each actual governance step.
void prepareArtistRecoveryRewindOperation(prep, 'execute');
// @ts-expect-error Protocol-only owner calls are not public workflow stages.
void prepareArtistRecoveryRewindOperation(prep, 'recoverIdentityV3', actor);
// @ts-expect-error Delegatecall transport is excluded.
void inspectArtistRecoveryRewindOperationReceipt(provider, prepareArtistRecoveryRewindOperation(prep, 'execute', actor), { transactionHash, execution: 'delegatecall' });
// @ts-expect-error Revision is original uint64 bigint.
captured.ownerSnapshot.revision = 1;
// @ts-expect-error Captured helper pins are immutable.
deployment.evidence.codeHash = manifestHash;
// @ts-expect-error Retained selection evidence is immutable.
captured.recovery!.selection.progress.complete = true;
// @ts-expect-error Array results are immutable.
captured.result.push(1n);

const payoutRevision: bigint = captured.payoutSnapshot.revision;
const payoutPrefix: bigint | undefined = captured.selection?.basis.payout.receiptCount;
const originalData: Hex | undefined = captured.selection?.records[0]?.originalData;
const currentStatus: bigint | undefined = captured.selection?.records[0]?.observedStatus.kind;
const sealedSnapshot = captured.selection?.seal.identityAfterPreparation;
void payoutRevision; void payoutPrefix; void originalData; void currentStatus; void sealedSnapshot;
// @ts-expect-error Both owner checkpoints are immutable.
captured.payoutSnapshot.revision = 3n;
// @ts-expect-error Full prefix observations are immutable.
captured.selection!.payoutJournal.push({operation:18n,artistId:manifestHash,collectionId:0n,recordHash:manifestHash});
// @ts-expect-error V2 context selector is outside this source-pinned V3 family.
void prepareArtistRecoveryRewindCall(coords, actor, {kind:'identityRecoveryContextV2',request,acceptance,manifestHash});
// @ts-expect-error The named bounded scan budget is bigint.
void prepareArtistRecoveryRewindCall(coords, actor, {kind:'continueSelectionV3',key:manifestHash,maximumRecords:32});
