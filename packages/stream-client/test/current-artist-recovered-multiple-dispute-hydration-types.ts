import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistHydrationOwnerIndex, ArtistHydrationSeven, ArtistHydrationSnapshot, ArtistHydrationSuite } from "../src/current-artist-authority-hydration.js";
import * as recovered from "../src/current-artist-recovered-multiple-dispute-hydration.js";

declare const registry: Address, actor: Address, raw: Hex;
declare const request: recovered.ArtistRecoveredMultipleDisputeHydrationRequest;
declare const prepared: recovered.ArtistRecoveredMultipleDisputeHydrationPrepared;
declare const coords: recovered.ArtistRecoveredMultipleDisputeHydrationCoordinates;
declare const origin: recovered.ArtistRecoveredMultipleDisputeHydrationOriginEnvironment;
declare const suite: ArtistHydrationSuite;
declare const index: ArtistHydrationOwnerIndex;
declare const aggregate: recovered.ArtistRecoveredMultipleDisputeHydrationState;
declare const historicalCells: readonly recovered.ArtistRecoveredMultipleDisputeHydrationHistoricalCell[];

const draft: recovered.ArtistRecoveredMultipleDisputeHydrationRequest = recovered.normalizeArtistRecoveredMultipleDisputeHydrationRequestDraft({
  ...request, expectedSemanticInventory: `0x${"00".repeat(32)}`,
});
const readData: Hex = recovered.artistRecoveredMultipleDisputeHydrationPreparationCalldata(suite, {request:draft,royaltyFreezes:[]});
const certificate: recovered.ArtistRecoveredMultipleDisputeHydrationPrepared = recovered.decodeArtistRecoveredMultipleDisputeHydrationPrepared(raw);
const inventory: Hex = recovered.artistRecoveredMultipleDisputeHydrationSemanticInventory(certificate);
const finalRequest = recovered.normalizeArtistRecoveredMultipleDisputeHydrationRequest({ ...draft, expectedSemanticInventory: inventory });
const call: recovered.ArtistRecoveredMultipleDisputeHydrationCall = recovered.prepareArtistRecoveredMultipleDisputeHydrationCall(registry, actor, {request:finalRequest,royaltyFreezes:[]});
const normalized = recovered.normalizeArtistRecoveredMultipleDisputeHydrationCall(call);
const verified: false = normalized.factsVerified;
const value: bigint = normalized.call.value;
const commitment: Hex = recovered.artistRecoveredMultipleDisputeHydrationCommitment(coords, finalRequest, prepared);
const nativeIndex: bigint = prepared.admission.provenance.journals[2][0]!.position.nativeIndex;
const cpRevision: bigint = prepared.admission.provenance.eras[0]!.checkpoints[2].ownerState.revision;
const scopes: readonly recovered.ArtistRecoveredMultipleDisputeHydrationCollectionWitness[] = finalRequest.records.witnesses;
const cells: ArtistHydrationSeven<readonly recovered.ArtistRecoveredMultipleDisputeHydrationReplayAlias[]> = prepared.admission.provenance.aliases;
const after: ArtistHydrationSnapshot = recovered.artistRecoveredMultipleDisputeHydrationOwnerAfter(
  origin, index, prepared.admission.before_[index], prepared.query, prepared.data[index], commitment, actor, historicalCells,
);
const ownerPayload = recovered.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(prepared.data[index].typedState, index);
const publications: readonly recovered.ArtistRecoveredMultipleDisputeHydrationPublication[] = ownerPayload.payload.publications;
const semanticOpaqueBytes: Hex = ownerPayload.payload.semanticState;
const profile: Hex = recovered.encodeArtistRecoveredMultipleDisputeHydrationProfileEvidence(finalRequest, prepared);
const descriptor = recovered.artistRecoveredMultipleDisputeHydrationEvidenceDescriptor(profile);
const pageId: Hex = recovered.artistRecoveredMultipleDisputeHydrationPageId(coords, commitment, descriptor, 0n);
const reconstructed: Hex = recovered.assembleArtistRecoveredMultipleDisputeHydrationEvidence(descriptor, recovered.artistRecoveredMultipleDisputeHydrationEvidencePages(profile));
const state: recovered.ArtistRecoveredMultipleDisputeHydrationOperationEvidence = {
  schemaVersion: 1n, configurationHash: raw, operationId: 60n, actor, commitment,
  before: prepared.admission.before_, after: prepared.admission.before_, profileData: recovered.encodeArtistRecoveredMultipleDisputeHydrationEvidenceCarrier(descriptor),
};
recovered.decodeArtistRecoveredMultipleDisputeHydrationOperationEvidence(recovered.encodeArtistRecoveredMultipleDisputeHydrationOperationEvidence(state));

// @ts-expect-error Exact chain widths require bigint.
recovered.normalizeArtistRecoveredMultipleDisputeHydrationCoordinates({ ...coords, chainId: 1 });
// @ts-expect-error Native points use bigint revisions, not JS numbers.
const badPoint: recovered.ArtistRecoveredMultipleDisputeHydrationPoint = { environmentHash: raw, ownerIndex: 2n, ownerRevision: 1 };
// @ts-expect-error Complete fixed-owner capabilities cannot be an arbitrary dynamic array.
const badRequest: recovered.ArtistRecoveredMultipleDisputeHydrationRequest = { ...request, expectedCapabilities: [] };
// @ts-expect-error No operation60 signing payload is invented.
call.signingPayload;
// @ts-expect-error Pure call cannot assert checked source readiness.
const authorityVerified: true = call.factsVerified;
// @ts-expect-error Every copied nested record is immutable.
call.request.records.authority.collections[0]!.collectionId = 3n;
// @ts-expect-error Actual caller is immutable.
call.caller = registry;
// @ts-expect-error Witness inventory cannot be mutated after preparation.
scopes.push(scopes[0]!);
// @ts-expect-error Public snapshot preserves all seven fixed owners.
const incompleteBefore: ArtistHydrationSeven<ArtistHydrationSnapshot> = [after];
// @ts-expect-error Page indices are full uint256 bigints.
recovered.artistRecoveredMultipleDisputeHydrationPageId(coords, commitment, descriptor, 0);
// @ts-expect-error Unknown owner index is not a source owner.
recovered.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(raw, 7);
// @ts-expect-error Unpublished future composition is not an implicit extra request field.
recovered.normalizeArtistRecoveredMultipleDisputeHydrationRequest({ ...request, contentFreeze: true });
void [readData, inventory, verified, value, nativeIndex, cpRevision, cells, publications, semanticOpaqueBytes, pageId, reconstructed];

const anchor = recovered.artistRecoveredMultipleDisputeHydrationAnchor(aggregate);
const partition = recovered.validateArtistRecoveredMultipleDisputeHydrationState(index, aggregate, ownerPayload.payload.provenance);
const aggregateBytes: Hex = recovered.encodeArtistRecoveredMultipleDisputeHydrationState(partition, index, ownerPayload.payload.provenance);
const decodedPartition = recovered.decodeArtistRecoveredMultipleDisputeHydrationState(aggregateBytes, index, ownerPayload.payload.provenance);
const identity = recovered.decodeArtistRecoveredMultipleDisputeHydrationIdentity(raw);
const principal: Address = identity.identity.authorityAddress;
const counter: bigint = identity.nextRegistrationNonce;
const payout = recovered.decodeArtistRecoveredMultipleDisputeHydrationPayout(raw);
recovered.encodeArtistRecoveredMultipleDisputeHydrationPayout(payout);
// @ts-expect-error Aggregate rows retain immutable byte strings.
decodedPartition.rows.push(raw);
// @ts-expect-error Aggregate scope quantities remain bigint.
decodedPartition.collections[0]!.collectionId = 2;
// @ts-expect-error Retained recovery histories cannot be edited in place.
identity.recoveries.push(identity.recoveries[0]!);
void [anchor, principal, counter];

declare const complete: recovered.ArtistRecoveredMultipleDisputeHydrationInventory;
declare const facts: recovered.ArtistRecoveredMultipleDisputeHydrationClockFacts;
const clocks: recovered.ArtistRecoveredMultipleDisputeHydrationClockResult = recovered.validateArtistRecoveredMultipleDisputeHydrationClocks(aggregate,prepared.admission.provenance,complete,facts);
const suppliedOnly: false = clocks.factsVerified;
const timelines: readonly recovered.ArtistRecoveredMultipleDisputeHydrationTimeline[] = clocks.collections;
const binding = recovered.decodeArtistRecoveredMultipleDisputeHydrationBindingBundle(raw);
const acceptance = recovered.decodeArtistRecoveredMultipleDisputeHydrationAcceptanceBundle(raw);
const attribution = recovered.decodeArtistRecoveredMultipleDisputeHydrationAttribution(raw);
const consents = recovered.decodeArtistRecoveredMultipleDisputeHydrationConsents(raw);
const aux = recovered.decodeArtistRecoveredMultipleDisputeHydrationAuxiliary(raw,index,ownerPayload.payload.provenance);
const disputeFacts = recovered.validateArtistRecoveredMultipleDisputeHydrationDisputes(aggregate,prepared.admission.provenance,complete,[attribution.history],clocks,{envelopes:facts.envelopes});
const identityFacts = recovered.validateArtistRecoveredMultipleDisputeHydrationIdentityFacts([identity],aggregate,complete,[acceptance],prepared.admission.provenance,[attribution.history]);
const originalSignatureVerified: false = identityFacts.factsVerified;
const disputesVerified: false = disputeFacts.factsVerified;
const uses = recovered.validateArtistRecoveredMultipleDisputeHydrationAttestations([identity],aggregate.collections,[attribution.records],prepared.admission.provenance,complete,clocks);
const sourceFactsVerified: false = uses.factsVerified;
const input: recovered.ArtistRecoveredMultipleDisputeHydrationInput = {request:finalRequest,royaltyFreezes:[]};
recovered.normalizeArtistRecoveredMultipleDisputeHydrationInput(input);
recovered.validateArtistRecoveredMultipleDisputeHydrationInput(input,prepared);
recovered.encodeArtistRecoveredMultipleDisputeHydrationAuxiliaryState(aggregate,0,ownerPayload.payload.provenance,recovered.encodeArtistRecoveredMultipleDisputeHydrationInventory(complete));
const completion = recovered.decodeArtistRecoveredMultipleDisputeHydrationArchiveEnvelope(raw);
const archiveVersion: bigint = completion.version;
// @ts-expect-error Original Archive bytes do not independently prove their read provenance.
const provenanceVerified: true = clocks.factsVerified;
// @ts-expect-error Generation rows are immutable.
binding.bindings.rows[0]!.item.generation=2n;
// @ts-expect-error Complete catalogue cutoffs retain all seven owner slots.
const incompleteCatalogue: recovered.ArtistRecoveredMultipleDisputeHydrationInventory = {...complete,catalogues:[{...complete.catalogues[0]!,upper:[0n]}]};
// @ts-expect-error No caller-provided signature packet is part of operation60 input.
recovered.normalizeArtistRecoveredMultipleDisputeHydrationInput({...input,signature:raw});
// @ts-expect-error Current-generation fields require bigint, not number.
const wrongGeneration: recovered.ArtistRecoveredMultipleDisputeHydrationGeneration={...complete.generations[0]![0]!,generation:2};
// @ts-expect-error Original owner4 collection histories are readonly.
attribution.history.disputes.push(attribution.history.disputes[0]!);
// @ts-expect-error Every clock vector stays immutable.
timelines[0]!.completions.push(timelines[0]!.completions[0]!);
void [suppliedOnly,sourceFactsVerified,archiveVersion,binding,acceptance,consents,aux];

const originalRecord = attribution.history.disputes[0]!.record;
const recordHash: Hex = recovered.artistRecoveredMultipleDisputeHydrationDisputeRecordHash(origin, originalRecord);
const pending: readonly Readonly<{artistId:Hex;authorityHeadHash:Hex;count:bigint}>[] = identityFacts.pending;
// @ts-expect-error Historical records contain no original signed deadline.
originalRecord.deadline;
// @ts-expect-error Immutable withdrawals are not caller-mutable.
attribution.history.disputes[0]!.withdrawal.recordHash = raw;
// @ts-expect-error A historical terminal cannot be edited into a new live phase.
attribution.history.repudiations[0]!.terminal.phase = 1n;
// @ts-expect-error No arbitrary call is admitted by the closed original op60 planner.
recovered.prepareArtistRecoveredMultipleDisputeHydrationCall(registry, actor, {...input,operation:44n});
void [originalSignatureVerified,disputesVerified,recordHash,pending];
