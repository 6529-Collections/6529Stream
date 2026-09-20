import type { Address, Hex } from "../src/generated/contracts.js";
import * as p from "../src/current-artist-recovery-adjudication.js";

declare const coordinates: p.ArtistRecoveryAdjudicationCoordinates, caller: Address, actor: Address, executor: Address, hash: Hex;
declare const request: p.ArtistRecoveryRequest, acceptance: p.ArtistRecoveryAuthorization;
declare const manifest: p.ArtistRecoveryResolutionManifest, appeal: p.ArtistRecoveryAppealDocument;
declare const basis: p.ArtistRecoverySelectionBasis, progress: p.ArtistRecoverySelectionProgress, context: p.ArtistRecoveryContext;
declare const evidenceState: p.ArtistRecoveryEvidenceState, guardian: p.ArtistRecoveryGuardianRecord, association: p.ArtistRecoveryActionAssociation;
declare const record: p.ArtistRecoveryRecord, vesting: p.ArtistRecoveryVesting, notice: p.ArtistRecoveryCurrentNoticeFacts, terminal: p.ArtistRecoveryTerminal;
declare const preparation: p.ArtistRecoveryPreparationPayload, execution: p.ArtistRecoveryExecutionPayload, noticeEvidence: p.ArtistRecoveryNoticeEvidence;
declare const operationEvidence: p.ArtistRecoveryOperationEvidence, window: p.ArtistRecoveryGovernanceWindow;

p.normalizeArtistRecoveryAdjudicationCoordinates(coordinates); p.normalizeArtistRecoveryRequest(request); p.normalizeArtistRecoveryAuthorization(acceptance);
p.normalizeArtistRecoveryResolutionManifest(manifest); p.normalizeArtistRecoveryAppealDocument(appeal);
p.normalizeArtistRecoveryContext(context); p.normalizeArtistRecoveryEvidenceState(evidenceState); p.normalizeArtistRecoveryGuardianRecord(guardian);
p.normalizeArtistRecoveryActionAssociation(association); p.normalizeArtistRecoveryRecord(record); p.normalizeArtistRecoveryVesting(vesting);
p.normalizeArtistRecoveryCurrentNoticeFacts(notice); p.normalizeArtistRecoveryTerminal(terminal);
const manifestHash: Hex = p.artistRecoveryResolutionManifestHash(coordinates, manifest), appealHash: Hex = p.artistRecoveryAppealHash(coordinates, appeal);
const requestCommitment: Hex = p.artistRecoveryRequestCommitment(request), selection: p.ArtistRecoverySelectionResult = p.artistRecoverySelectionResult(coordinates, basis, progress);
p.artistRecoverySelectionKey(coordinates, basis); p.artistRecoverySupersededRecordsHash(request.supersededRecordHashes);
p.artistRecoveryRecordHash(coordinates.chainId, coordinates.registry, record.fields); p.artistRecoveryVestingCommitment(coordinates, vesting);
p.artistRecoveryScopeHash(coordinates, request.artistId); p.artistRecoveryIntentHash(context, request, acceptance);
p.artistRecoveryCurrentNoticeContextHash(hash, notice); p.artistRecoveryCurrentNoticeSourceHash(hash, notice);
p.artistRecoveryPreparationHash(coordinates, hash, manifestHash, hash, selection, association); p.artistRecoveryCancellationHash(coordinates, terminal, 0n);
const payload = p.artistRecoveryAcceptancePayload(coordinates.chainId, coordinates.registry, request, context.incumbent, acceptance);
const signedMessage: p.ArtistRecoveryAcceptanceMessage = payload.message;
const batch: p.ArtistRecoveryGovernanceBatch = p.artistRecoveryGovernanceBatch(coordinates, request, acceptance, manifestHash, context, executor, 0n, window);
p.normalizeArtistRecoveryGovernanceBatch(batch); p.normalizeArtistRecoveryGovernanceWindow(window); p.assertArtistRecoveryRegistrationWindow(acceptance, window, 1n, 259200n);
const classTwo: 2n = batch.actionClass, unverified: false = batch.factsVerified;
const calls: readonly p.ArtistRecoveryAdjudicationInput[] = [
  { kind: "publishResolutionManifest", manifest }, { kind: "resolutionManifest", manifestHash },
  { kind: "publishAppealV2", document: appeal }, { kind: "appealEvidenceV2", documentHash: appealHash },
  { kind: "beginSelectionV2", manifestHash }, { kind: "continueSelectionV2", key: hash, maximumRecords: 100n },
  { kind: "requireSelectionV2", manifestHash }, { kind: "selectionV2", key: hash }, { kind: "retainedMemberV2", key: hash, actor },
  { kind: "identityRecoveryContextV2", request, acceptance, manifestHash }, { kind: "recoverArtistIdentityV2", request, acceptance, manifestHash },
  { kind: "registerIdentityRecoveryActionV2", actionId: batch.actionId, calls: [batch.governanceCall], request, acceptance, manifestHash },
  { kind: "identityRecoveryEvidenceState", artistId: request.artistId, actionId: hash },
];
for (const input of calls) {
  const call: p.ArtistRecoveryAdjudicationCall = p.prepareArtistRecoveryAdjudicationCall(coordinates, caller, input);
  p.normalizeArtistRecoveryAdjudicationCall(call); const expected: Hex | null = call.expectedReturnHash, copiedCaller: Address = call.caller; void expected; void copiedCaller;
  if (call.input.kind === "publishResolutionManifest") { const revisions: bigint = call.input.manifest.ownerRevision; void revisions; }
  if (call.input.kind === "registerIdentityRecoveryActionV2") { const exactCallList: readonly p.ArtistRecoveryGovernanceCall[] = call.input.calls; void exactCallList; }
}
const decodedManifest: p.ArtistRecoveryResolutionManifest = p.decodeArtistRecoveryResolutionManifest(p.encodeArtistRecoveryResolutionManifest(manifest));
const decodedRequest: p.ArtistRecoveryRequest = p.decodeArtistRecoveryRequest(p.encodeArtistRecoveryRequest(request));
const decodedContext: p.ArtistRecoveryContext = p.decodeArtistRecoveryContext(p.encodeArtistRecoveryContext(context));
const decodedState: p.ArtistRecoveryEvidenceState = p.decodeArtistRecoveryEvidenceState(p.encodeArtistRecoveryEvidenceState(evidenceState));
const decodedRecord: p.ArtistRecoveryRecord = p.decodeArtistRecoveryRecord(p.encodeArtistRecoveryRecord(record));
const decodedPreparation: p.ArtistRecoveryPreparationEvidence = p.decodeArtistRecoveryPreparationEvidence(p.encodeArtistRecoveryPreparationEvidence({ payload: preparation, notice: noticeEvidence }));
const decodedExecution: p.ArtistRecoveryExecutionEvidence = p.decodeArtistRecoveryExecutionEvidence(p.encodeArtistRecoveryExecutionEvidence({ payload: execution, noticeBefore: noticeEvidence, noticeAfter: noticeEvidence }));
const decodedEnvelope: p.ArtistRecoveryOperationEvidence = p.decodeArtistRecoveryOperationEvidence(p.encodeArtistRecoveryOperationEvidence(operationEvidence));
p.artistRecoveryOperationEvidenceId(coordinates, 35n, caller, hash); p.artistRecoveryOperationEvidenceId(coordinates, 65534n, caller, hash);
void requestCommitment; void classTwo; void unverified; void signedMessage; void decodedRequest; void decodedContext; void decodedState; void decodedRecord; void decodedPreparation; void decodedExecution; void decodedEnvelope;

// @ts-expect-error all chain/nonce/owner-revision widths remain bigint
p.normalizeArtistRecoveryAdjudicationCoordinates({ ...coordinates, chainId: 1 });
// @ts-expect-error original publisher binding is explicit, not a generic target override
p.normalizeArtistRecoveryAdjudicationCoordinates({ ...coordinates, target: caller });
// @ts-expect-error original Request does not append the V2 manifest sidecar
p.normalizeArtistRecoveryRequest({ ...request, manifestHash });
// @ts-expect-error original Authorization uses time, whose meaning here is deadline
p.normalizeArtistRecoveryAuthorization({ nonce: 1n, deadline: 100n, signature: hash });
// @ts-expect-error no signedAt sentinel is substituted into an acceptance deadline
p.normalizeArtistRecoveryAuthorization({ ...acceptance, time: "now" });
// @ts-expect-error only the two original vesting bases exist
p.normalizeArtistRecoveryResolutionManifest({ ...manifest, basis: 2n });
// @ts-expect-error declared references need both original transition and vesting commitments
p.normalizeArtistRecoveryResolutionManifest({ ...manifest, contestedVestings: [{ transitionRecordHash: hash }] });
// @ts-expect-error owner revision cannot become a JS number
p.normalizeArtistRecoveryResolutionManifest({ ...manifest, ownerRevision: 1 });
// @ts-expect-error hostile findings must preserve their original party list
p.normalizeArtistRecoveryAppealDocument({ ...appeal, findings: [{ guardianRecordHash: hash }] });
// @ts-expect-error a complete empty selection is a structured result, not null
p.artistRecoverySelectionResult(coordinates, basis, null);
// @ts-expect-error selected nonce retains full uint256
p.normalizeArtistRecoverySelectionProgress({ ...progress, selectedNonce: 1 });
// @ts-expect-error no current source fact is an admission boolean
p.normalizeArtistRecoveryContext({ ...context, authorized: true });
// @ts-expect-error old selector is not implicitly opted into V2
p.prepareArtistRecoveryAdjudicationCall(coordinates, caller, { kind: "recoverArtistIdentity", request, acceptance });
// @ts-expect-error V2 calls always retain the manifest sidecar
p.prepareArtistRecoveryAdjudicationCall(coordinates, caller, { kind: "recoverArtistIdentityV2", request, acceptance });
// @ts-expect-error publication names manifest explicitly
p.prepareArtistRecoveryAdjudicationCall(coordinates, caller, { kind: "publishResolutionManifest", document: manifest });
// @ts-expect-error current selection takes only source-owned history, not caller-supplied rows
p.prepareArtistRecoveryAdjudicationCall(coordinates, caller, { kind: "beginSelectionV2", manifestHash, rows: [] });
// @ts-expect-error uint64 chunk size remains bigint
p.prepareArtistRecoveryAdjudicationCall(coordinates, caller, { kind: "continueSelectionV2", key: hash, maximumRecords: 1 });
// @ts-expect-error publication remains a zero-value original call without arbitrary payment
p.prepareArtistRecoveryAdjudicationCall(coordinates, caller, { kind: "publishAppealV2", document: appeal, value: 1n });
// @ts-expect-error original op35 class2 is fixed
p.normalizeArtistRecoveryGovernanceBatch({ ...batch, actionClass: 1n });
// @ts-expect-error complete calls, request and acceptance are required for original registration
p.prepareArtistRecoveryAdjudicationCall(coordinates, caller, { kind: "registerIdentityRecoveryActionV2", actionId: hash, manifestHash });
// @ts-expect-error scheduled minimum delay requires an observed bigint
p.assertArtistRecoveryRegistrationWindow(acceptance, window, 1n, 259200);
// @ts-expect-error source facts are not verified by pure reconstruction
p.normalizeArtistRecoveryGovernanceBatch({ ...batch, factsVerified: true });
// @ts-expect-error permanent acceptance schema contains no reason hash
payload.message.reasonHash;
// @ts-expect-error reason/manifest cannot silently become new signed fields
const incorrectMessage: p.ArtistRecoveryAcceptanceMessage = { ...signedMessage, manifestHash };
// @ts-expect-error nested guardian inventory is immutable
guardian.terms.guardians.push(caller);
// @ts-expect-error manifest declaration order cannot mutate after normalization
decodedManifest.contestedVestings.reverse();
// @ts-expect-error policy source notices and Archive raw notice evidence are separate shapes
p.encodeArtistRecoveryNoticeEvidence(notice);
// @ts-expect-error tagged execution explicitly carries both observations or null fields
p.encodeArtistRecoveryExecutionEvidence({ payload: execution, noticeBefore: noticeEvidence });
// @ts-expect-error internal preparation remains operation65534, not operation35
p.encodeArtistRecoveryOperationEvidence({ ...operationEvidence, operation: 42n });
// @ts-expect-error no invented operation/domain for cancellation is added to this envelope
p.artistRecoveryOperationEvidenceId(coordinates, 42n, caller, hash);
// @ts-expect-error original recovery fields contain execution time, not acceptance deadline
p.artistRecoveryRecordHash(coordinates.chainId, coordinates.registry, { ...record.fields, deadline: 100n });
// @ts-expect-error readback context is immutable
decodedContext.newValueHash = hash;
// @ts-expect-error original nested notice terms cannot mutate
noticeEvidence.notice.terms.reasonURI = "changed";
void incorrectMessage;
