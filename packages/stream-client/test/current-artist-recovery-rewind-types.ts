import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import * as p from "../src/current-artist-recovery-rewind.js";
import * as v2 from "../src/current-artist-recovery-adjudication.js";

declare const c: p.ArtistRecoveryRewindCoordinates, e: p.ArtistRecoveryRewindEnvironment, caller: Address, executor: Address, hash: Hex;
declare const request: v2.ArtistRecoveryRequest, acceptance: v2.ArtistRecoveryAuthorization, context: v2.ArtistRecoveryContext, association: v2.ArtistRecoveryActionAssociation;
declare const manifest: p.ArtistRecoveryRewindResolutionManifest, appeal: p.ArtistRecoveryRewindAppealDocument, original: p.ArtistRecoveryRewindPayoutOriginal;
declare const basis: p.ArtistRecoveryRewindSelectionBasis, result: p.ArtistRecoveryRewindSelectionResult, progress: p.ArtistRecoveryRewindSelectionProgress;
declare const state: p.ArtistRecoveryRewindEvidenceState, seal: p.ArtistRecoveryRewindPreparationSeal, facts: p.ArtistRecoveryRewindCrossOwnerFacts;
declare const evidence: p.ArtistRecoveryRewindEvidence, prep: p.ArtistRecoveryRewindPreparationPayload, execution: p.ArtistRecoveryRewindExecutionPayload;
declare const payoutApply: p.ArtistRecoveryRewindPayoutApply, action: p.ArtistRecoveryRewindActionContext, source: p.ArtistRecoveryRewindSourceFacts, contextFacts: p.ArtistRecoveryRewindContextFacts;
declare const revision: p.ArtistRecoveryRewindRevisionContinuation, standing: p.ArtistRecoveryRewindStandingContinuation, payout: p.ArtistRecoveryRewindPayoutContinuation, capabilities: p.ArtistRecoveryRewindCapabilityContinuation;
declare const window: v2.ArtistRecoveryGovernanceWindow, envelope: v2.ArtistRecoveryOperationEvidence;

const environment: p.ArtistRecoveryRewindEnvironment = p.artistRecoveryRewindEnvironment(c);
p.normalizeArtistRecoveryRewindEnvironment(e); p.normalizeArtistRecoveryRewindEnvironment(c); p.normalizeArtistRecoveryRewindCoordinates(c);
const manifestHash: Hex = p.artistRecoveryRewindManifestHash(e, manifest), publicationHash: Hex = p.artistRecoveryRewindPayoutOriginalHash(c, original);
p.artistRecoveryRewindAppealHash(c, appeal); p.artistRecoveryRewindPayoutRecordHash(c, original);
p.artistRecoveryRewindSelectionSourceHash(c, basis); p.artistRecoveryRewindSelectionKey(c, basis);
p.artistRecoveryRewindSelectionInventoryHash(e, basis.identity.inventory, basis.payoutInventory); p.artistRecoveryRewindSelectionResultHash(c, result);
p.artistRecoveryRewindGuardianResultHash(c, basis.identity.guardianHistory, result.guardians); p.artistRecoveryRewindPreparationSealHash(c, seal);
p.artistRecoveryRewindRevisionContinuationHash(e, revision); p.artistRecoveryRewindStandingContinuationHash(e, standing); p.artistRecoveryRewindPayoutContinuationHash(e, payout); p.artistRecoveryRewindCapabilityContinuationHash(e, capabilities);
p.artistRecoveryRewindPreparationHash(c, hash, manifestHash, hash, result, association); p.artistRecoveryRewindIdentitySourceHash(c, source); p.artistRecoveryRewindContextOldValueHash(hash, contextFacts);
p.artistRecoveryRewindIntentHash(context, request, acceptance); p.artistRecoveryRewindScopeHash(c, request.artistId);
const partitions: readonly (readonly Hex[])[] = p.artistRecoveryRewindPartition(request, manifest.supersededRecords);
const completion: Readonly<{ key: Hex; commitment: Hex; factsVerified: false }> = p.validateArtistRecoveryRewindSelection(c, manifest, basis, progress, result);
const sealed: Readonly<{ commitment: Hex; factsVerified: false }> = p.validateArtistRecoveryRewindPreparationSeal(c, basis, state, seal);
const prefixCount: bigint = manifest.payout.receiptCount, payoutRevision: bigint = manifest.payout.snapshot.revision;
const typedKind: p.ArtistRecoveryRewindRecordKind = 6n;
const calls: readonly p.ArtistRecoveryRewindInput[] = [
  { kind: "publishResolutionManifestV3", manifest }, { kind: "resolutionManifestV3", manifestHash },
  { kind: "publishAppealV3", document: appeal }, { kind: "appealEvidenceV3", documentHash: hash },
  { kind: "publishPayoutOriginalV3", original }, { kind: "payoutOriginalV3", recordHash: original.recordHash },
  { kind: "beginSelectionV3", manifestHash }, { kind: "continueSelectionV3", key: hash, maximumRecords: 100n },
  { kind: "requireSelectionV3", manifestHash }, { kind: "selectionV3", key: hash }, { kind: "selectionResultV3", key: hash },
  { kind: "selectionRecordV3", key: hash, recordHash: hash }, { kind: "retainedMemberV3", key: hash, actor: caller },
  { kind: "sealPreparationV3", manifestHash, actionId: hash, associationHash: hash }, { kind: "preparationSealV3", key: hash },
  { kind: "identityRecoveryContextV3", request, acceptance, manifestHash }, { kind: "recoverArtistIdentityV3", request, acceptance, manifestHash },
  { kind: "registerIdentityRecoveryActionV3", actionId: hash, calls: [], request, acceptance, manifestHash },
  { kind: "identityRecoveryEvidenceStateV3", artistId: request.artistId, actionId: hash },
  { kind: "guardianRecoveryAuthorityRoleV3", request, acceptance, manifestHash, facts },
  { kind: "recoveryRewindInventoryV3", artistId: request.artistId }, { kind: "recoveryRecordStatusV3", recordKind: typedKind, recordHash: hash },
  { kind: "recoveryStandingScopeV3", artistId: request.artistId, priorAddress: caller }, { kind: "recoveryRewindBasisV3", manifestHash },
  { kind: "latestRecoveryCapabilityContinuationV3", artistId: request.artistId }, { kind: "recoveryCapabilityContinuationV3", recoveryRecordHash: hash },
  { kind: "identityRevisionRecoveryContinuationV3", recordHash: hash }, { kind: "recoveryRevisionContinuationV3", continuationHash: hash },
  { kind: "standingRevocationRecoveryContinuationV3", recordHash: hash }, { kind: "recoveryStandingContinuationV3", continuationHash: hash },
  { kind: "payoutDesignationRecoveryContinuationV3", recordHash: hash }, { kind: "payoutRecoveryContinuationV3", continuationHash: hash },
  { kind: "payoutRewindInventoryV3", artistId: request.artistId }, { kind: "payoutRecoveryRecordStatusV3", recordHash: hash },
  { kind: "applyRecoveryRewindV3", context: action, plan: payoutApply },
];
for (const input of calls) {
  const prepared: p.ArtistRecoveryRewindCall = p.prepareArtistRecoveryRewindCall(c, caller, input);
  p.normalizeArtistRecoveryRewindCall(prepared); const call: UnsignedCall = prepared.call, expected: Hex | null = prepared.expectedReturnHash, unverified: false = prepared.factsVerified, protocolOnly: boolean = prepared.protocolOnly;
  if (prepared.input.kind === "publishPayoutOriginalV3") { const nonce: bigint = prepared.input.original.nonce; void nonce; }
  if (prepared.input.kind === "recoveryRecordStatusV3") { const kind: p.ArtistRecoveryRewindRecordKind = prepared.input.recordKind; void kind; }
  void call; void expected; void unverified; void protocolOnly;
}
const batch: p.ArtistRecoveryRewindGovernanceBatch = p.artistRecoveryRewindGovernanceBatch(c, request, acceptance, manifestHash, context, executor, 0n, window);
const classTwo: 2n = batch.actionClass, unsignedGovernance: UnsignedCall = batch.executionCall;
p.normalizeArtistRecoveryRewindGovernanceBatch(batch); p.normalizeArtistRecoveryRewindGovernanceWindow(window); p.assertArtistRecoveryRewindRegistrationWindow(acceptance, window, 1n, 259200n);
const originalMessage: v2.ArtistRecoveryAcceptanceMessage = p.artistRecoveryRewindAcceptancePayload(e.chainId, e.registry, request, context.incumbent, acceptance).message;
const decodedManifest: p.ArtistRecoveryRewindResolutionManifest = p.decodeArtistRecoveryRewindResolutionManifest(p.encodeArtistRecoveryRewindResolutionManifest(manifest));
const decodedState: p.ArtistRecoveryRewindEvidenceState = p.decodeArtistRecoveryRewindEvidenceState(p.encodeArtistRecoveryRewindEvidenceState(state));
const decodedEvidence: p.ArtistRecoveryRewindEvidence = p.decodeArtistRecoveryRewindEvidence(p.encodeArtistRecoveryRewindEvidence(evidence));
const decodedPrep: p.ArtistRecoveryRewindPreparationPayload = p.decodeArtistRecoveryRewindPreparationPayload(p.encodeArtistRecoveryRewindPreparationPayload(prep));
const decodedExec: p.ArtistRecoveryRewindExecutionPayload = p.decodeArtistRecoveryRewindExecutionPayload(p.encodeArtistRecoveryRewindExecutionPayload(execution));
const decodedEnvelope: v2.ArtistRecoveryOperationEvidence = p.decodeArtistRecoveryRewindOperationEvidence(p.encodeArtistRecoveryRewindOperationEvidence(envelope));
p.artistRecoveryRewindOperationEvidenceId(c, 65534n, caller, hash); p.artistRecoveryRewindOperationEvidenceId(c, 35n, caller, hash);
void environment; void publicationHash; void completion; void sealed; void prefixCount; void payoutRevision; void classTwo; void unsignedGovernance; void originalMessage; void decodedManifest; void decodedState; void decodedEvidence; void decodedPrep; void decodedExec; void decodedEnvelope;

// @ts-expect-error full uint256 chain remains bigint
p.normalizeArtistRecoveryRewindCoordinates({ ...c, chainId: 1 });
// @ts-expect-error V3 must retain both fixed owner bindings
p.normalizeArtistRecoveryRewindCoordinates({ chainId: c.chainId, registry: c.registry, owner: c.identityOwner });
// @ts-expect-error not an arbitrary target override
p.prepareArtistRecoveryRewindCall(c, caller, { kind: "selectionV3", key: hash, target: caller });
// @ts-expect-error historical V2 selector is separate
p.prepareArtistRecoveryRewindCall(c, caller, { kind: "recoverArtistIdentityV2", request, acceptance, manifestHash });
// @ts-expect-error original recover request does not gain typed exclusions
p.artistRecoveryRewindRequestCommitment({ ...request, supersededRecords: manifest.supersededRecords });
// @ts-expect-error only original seven family discriminants
p.normalizeArtistRecoveryRewindRecordReference({ kind: 7n, recordHash: hash });
// @ts-expect-error kind remains bigint
p.normalizeArtistRecoveryRewindRecordReference({ kind: 1, recordHash: hash });
// @ts-expect-error original request retains recordHash[]
p.artistRecoveryRewindPartition({ ...request, supersededRecordHashes: manifest.supersededRecords }, manifest.supersededRecords);
// @ts-expect-error receipt count remains uint256 bigint
p.normalizeArtistRecoveryRewindReceiptPrefix({ ...manifest.payout, receiptCount: 9007199254740993 });
// @ts-expect-error maximumRecords is original uint64 bigint
p.prepareArtistRecoveryRewindCall(c, caller, { kind: "continueSelectionV3", key: hash, maximumRecords: 32 });
// @ts-expect-error Original retains signer and inclusion timestamp
p.normalizeArtistRecoveryRewindPayoutOriginal({ recordHash: hash, terms: original.terms, authorityClass: 1n, nonce: 0n });
// @ts-expect-error signedAt is not a deadline alias
p.normalizeArtistRecoveryRewindPayoutOriginal({ ...original, deadline: 1n });
// @ts-expect-error complete two-owner prefix required
p.normalizeArtistRecoveryRewindResolutionManifest({ ...manifest, ownerRevision: 1n });
// @ts-expect-error only two original basis values
p.normalizeArtistRecoveryRewindResolutionManifest({ ...manifest, basis: 2n });
// @ts-expect-error source-owned hook requires ActionContext
p.prepareArtistRecoveryRewindCall(c, caller, { kind: "applyRecoveryRewindV3", caller, plan: payoutApply });
// @ts-expect-error nested snapshots are immutable
manifest.payout.snapshot.revision = 1n;
// @ts-expect-error result families are immutable
result.designation.operative.nonce = 1n;
// @ts-expect-error exclusions are immutable
manifest.supersededRecords.push({ kind: 0n, recordHash: hash });
// @ts-expect-error partitions are immutable
partitions[0]!.push(hash);
// @ts-expect-error governance call is immutable
batch.targetCall.value = 1n;
// @ts-expect-error helpers do not certify supplied facts
const verified: true = completion.factsVerified;
// @ts-expect-error V3 payload uses exact flat fields
p.encodeArtistRecoveryRewindPreparationPayload({ payload: prep, notice: null });
// @ts-expect-error no op60 recovery profile
p.artistRecoveryRewindOperationEvidenceId(c, 60n, caller, hash);
// @ts-expect-error governance nonce remains bigint
p.artistRecoveryRewindGovernanceBatch(c, request, acceptance, manifestHash, context, executor, 1, window);
void verified;
