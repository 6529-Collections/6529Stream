import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import * as m from "../src/current-museum-anchor-master.js";

declare const coordinates: m.MuseumAnchorMasterCoordinates, anchorCoordinates: m.MuseumAnchorCoordinates;
declare const master: m.MuseumMaster, waiver: m.MuseumMasterWaiver, selection: m.MuseumMasterSelection;
declare const caller: Address, recorder: Address, digest: Hex;
declare const context: m.MuseumMasterMediaContext, association: m.MuseumMasterAssociation;
declare const receipt: m.MuseumMasterRecordReceipt, evidence: m.MuseumMasterRecordEvidence, policy: m.MuseumMasterRecordPolicy;
declare const window: m.MuseumAnchorGovernanceWindow;

m.normalizeMuseumAnchorCoordinates(anchorCoordinates); m.normalizeMuseumAnchorMasterCoordinates(coordinates);
const payload: m.MuseumMasterCanonicalPayload = m.museumMasterCanonical(master), waivedPayload = m.museumMasterWaiverCanonical(waiver);
const raw: Hex = payload.canonical, fullLength: bigint = payload.byteLength;
const decodedMaster: m.MuseumMaster = m.decodeMuseumMasterCanonical(raw);
const decodedWaiver: m.MuseumMasterWaiver = m.decodeMuseumMasterWaiverCanonical(waivedPayload.canonical);
const record: m.MuseumMasterCollectionRecord = m.museumMasterRecord(master, "ipfs://master", 1n << 62n);
const waivedRecord = m.museumMasterWaiverRecord(waiver, "ar://waiver", 1n);
const publication = m.museumMasterPublication(coordinates, recorder, 1n << 250n, waivedRecord);
const completeStatement: Hex = publication.statement, originalRecorder: Address = publication.publication.recorder;
const calls: readonly m.MuseumAnchorMasterCall[] = [
  m.prepareMuseumAnchorMasterCall(coordinates, caller, { kind: "declareConservationTier", collectionId: 1n, tier: m.MUSEUM_GRADE }),
  m.prepareMuseumAnchorMasterCall(coordinates, caller, { kind: "recordCollectionRecordWithPayload", collectionId: 1n, record, witness: master }),
  m.prepareMuseumAnchorMasterCall(coordinates, caller, { kind: "recordArtistCollectionRecordWithPayload", recorder, collectionId: 1n, record: waivedRecord, authorization: digest, witness: waiver }),
  m.prepareMuseumAnchorMasterCall(coordinates, caller, { kind: "adoptMaster", collectionId: 1n, recordHash: digest, expectedRevision: 0n, original: record, witness: master }),
  m.prepareMuseumAnchorMasterCall(coordinates, caller, { kind: "adoptWaiver", collectionId: 1n, slot: 2n, manifestHash: digest, recordHash: digest, expectedRevision: 1n, original: waivedRecord, witness: waiver }),
];
for (const prepared of calls) {
  const ordinaryCall: UnsignedCall = prepared.call, unverified: false = prepared.factsVerified;
  const originalOrNull: Hex | null = prepared.recordHash;
  m.normalizeMuseumAnchorMasterCall(prepared);
  if (prepared.request.kind === "recordArtistCollectionRecordWithPayload") { const signer: Address = prepared.request.recorder; void signer; }
  if (prepared.request.kind === "adoptWaiver") { const roles: readonly (0n | 1n)[] = prepared.request.witness.mediaObjects[0]!.masterRoles; void roles; }
  void ordinaryCall; void unverified; void originalOrNull;
}
const tier = m.museumConservationTier(digest, 1n << 240n);
const subject: Hex = m.museumMasterCollectionSubject(coordinates.chainId, coordinates.core, 1n);
m.museumMasterObjectId(coordinates, 1n, subject, digest, 2n, digest);
m.museumMasterRecordHash(coordinates, recorder, 1n, record); m.museumMasterRecordChainHash(coordinates, 1n, digest, digest, digest, 0n);
m.museumMasterSelectionHash(coordinates, 1n, selection); m.museumMasterFactsHash(coordinates, 1n, context, [digest, digest, digest], association); m.museumMasterAppendFactsHash(digest, 2n, digest, digest);
m.decodeMuseumMasterCollectionRecord(m.encodeMuseumMasterCollectionRecord(record)); m.decodeMuseumMasterSelection(m.encodeMuseumMasterSelection(selection)); m.decodeMuseumMasterRecordReceipt(m.encodeMuseumMasterRecordReceipt(receipt)); m.decodeMuseumMasterRecordEvidence(m.encodeMuseumMasterRecordEvidence(evidence)); m.decodeMuseumMasterRecordPolicy(m.encodeMuseumMasterRecordPolicy(policy));
const reads: readonly UnsignedCall[] = [
  m.prepareMuseumAnchorRead(anchorCoordinates, { kind: "conditionSources" }), m.prepareMuseumAnchorRead(anchorCoordinates, { kind: "conservationFloor" }),
  m.prepareMuseumAnchorRead(anchorCoordinates, { kind: "conditionSourcesTransition", candidate: caller }), m.prepareMuseumAnchorRead(anchorCoordinates, { kind: "conservationFloorTransition", candidate: caller }),
  m.prepareMuseumMasterRead(coordinates, { kind: "declaredConservationTier", collectionId: 0n }), m.prepareMuseumMasterRead(coordinates, { kind: "conservationTier", collectionId: 1n }),
  m.prepareMuseumMasterRead(coordinates, { kind: "collectionMediaContext", collectionId: 1n }), m.prepareMuseumMasterRead(coordinates, { kind: "currentMaster", collectionId: 1n, subjectId: subject, slot: 2n }),
  m.prepareMuseumMasterRead(coordinates, { kind: "masterSelectionAt", collectionId: 1n, subjectId: subject, slot: 2n, revision: 10n }), m.prepareMuseumMasterRead(coordinates, { kind: "requireCollectionMasters", collectionId: 1n, subjectId: subject }),
  m.prepareMuseumMasterRead(coordinates, { kind: "mediaObjectId", collectionId: 1n, subjectId: subject, manifestHash: digest, slot: 2n, displayHash: digest }),
];
for (const kind of ["conditionSources", "conservationFloor"] as const) {
  const plan: m.MuseumAnchorBindingPlan = m.prepareMuseumAnchorBinding(anchorCoordinates, { kind, candidate: caller, runtimeCodeHash: digest, previous: { target: caller, runtimeCodeHash: digest } });
  m.normalizeMuseumAnchorBindingPlan(plan); const actionClass: 1n = plan.actionClass;
  const batch: m.MuseumAnchorGovernanceBatch = m.museumAnchorGovernanceBatch(plan, 1n << 250n, window); m.normalizeMuseumAnchorGovernanceBatch(batch); m.assertMuseumAnchorGovernanceWindow(window, 100n);
  const transports: readonly UnsignedCall[] = [batch.publicationCall, batch.scheduleCall, batch.executionCall]; void actionClass; void transports;
}
void tier; void reads; void completeStatement; void originalRecorder; void decodedMaster; void decodedWaiver; void fullLength;

// @ts-expect-error native uint256 remains exact bigint
m.prepareMuseumAnchorMasterCall(coordinates, caller, { kind: "declareConservationTier", collectionId: 1, tier: digest });
// @ts-expect-error Core tier write is selected-Metadata protocol-only, not a public operator lane
m.prepareMuseumAnchorMasterCall(coordinates, caller, { kind: "recordConservationTier", collectionId: 1n, tier: digest });
// @ts-expect-error pending paid-floor receipt writer is excluded
m.prepareMuseumAnchorMasterCall(coordinates, caller, { kind: "recordPrimarySale", candidate: {}, result: {} });
// @ts-expect-error detached waiver publishing requires the original recorder
m.prepareMuseumAnchorMasterCall(coordinates, caller, { kind: "recordArtistCollectionRecordWithPayload", collectionId: 1n, record: waivedRecord, authorization: digest, witness: waiver });
// @ts-expect-error a master witness cannot replace the original waiver structure
m.prepareMuseumAnchorMasterCall(coordinates, caller, { kind: "adoptWaiver", collectionId: 1n, slot: 1n, manifestHash: digest, recordHash: digest, expectedRevision: 1n, original: record, witness: master });
// @ts-expect-error original role enum is closed
m.normalizeMuseumMaster({ ...master, masterRole: 2n });
// @ts-expect-error original status enum is closed
m.normalizeMuseumMasterSelection({ ...selection, status: 3n });
// @ts-expect-error original generation is uint64 bigint
m.normalizeMuseumMasterWaiver({ ...waiver, artist: { ...waiver.artist, bindingGeneration: 1 } });
// @ts-expect-error original full slot vector contains exactly three entries
m.museumMasterFactsHash(coordinates, 1n, context, [digest, digest], association);
// @ts-expect-error nested snapshots are readonly
waiver.mediaObjects[0]!.masterRoles.push(1n);
// @ts-expect-error original record lineage is readonly
selection.predecessor = digest;
// @ts-expect-error canonical snapshot bytes are immutable
payload.canonical = digest;
// @ts-expect-error supplied facts cannot claim verified authority
const verified: true = calls[0]!.factsVerified;
// @ts-expect-error separate minimal anchor coordinates require exact chain/core/executor
m.prepareMuseumAnchorBinding({ chainId: 1n, core: caller }, { kind: "conditionSources", candidate: caller, runtimeCodeHash: digest, previous: { target: caller, runtimeCodeHash: digest } });
// @ts-expect-error finite permanent anchor family
m.prepareMuseumAnchorBinding(anchorCoordinates, { kind: "metadata", candidate: caller, runtimeCodeHash: digest, previous: { target: caller, runtimeCodeHash: digest } });
// @ts-expect-error no native transfer value in original binding request
m.prepareMuseumAnchorBinding(anchorCoordinates, { kind: "conditionSources", candidate: caller, runtimeCodeHash: digest, previous: { target: caller, runtimeCodeHash: digest }, value: 1n });
void verified;
