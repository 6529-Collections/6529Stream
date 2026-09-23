import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistHydrationOwnerIndex, ArtistHydrationSeven, ArtistHydrationSnapshot, ArtistHydrationSuite } from "../src/current-artist-authority-hydration.js";
import * as recovered from "../src/current-artist-recovered-multiple-generation-hydration.js";

declare const registry: Address, actor: Address, raw: Hex;
declare const request: recovered.ArtistRecoveredMultipleGenerationHydrationRequest;
declare const prepared: recovered.ArtistRecoveredMultipleGenerationHydrationPrepared;
declare const coords: recovered.ArtistRecoveredMultipleGenerationHydrationCoordinates;
declare const origin: recovered.ArtistRecoveredMultipleGenerationHydrationOriginEnvironment;
declare const suite: ArtistHydrationSuite;
declare const index: ArtistHydrationOwnerIndex;
declare const aggregate: recovered.ArtistRecoveredMultipleGenerationHydrationState;
declare const historicalCells: readonly recovered.ArtistRecoveredMultipleGenerationHydrationHistoricalCell[];

const draft: recovered.ArtistRecoveredMultipleGenerationHydrationRequest = recovered.normalizeArtistRecoveredMultipleGenerationHydrationRequestDraft({
  ...request, expectedSemanticInventory: `0x${"00".repeat(32)}`,
});
const readData: Hex = recovered.artistRecoveredMultipleGenerationHydrationPreparationCalldata(suite, {request:draft,royaltyFreezes:[]});
const certificate: recovered.ArtistRecoveredMultipleGenerationHydrationPrepared = recovered.decodeArtistRecoveredMultipleGenerationHydrationPrepared(raw);
const inventory: Hex = recovered.artistRecoveredMultipleGenerationHydrationSemanticInventory(certificate);
const finalRequest = recovered.normalizeArtistRecoveredMultipleGenerationHydrationRequest({ ...draft, expectedSemanticInventory: inventory });
const call: recovered.ArtistRecoveredMultipleGenerationHydrationCall = recovered.prepareArtistRecoveredMultipleGenerationHydrationCall(registry, actor, {request:finalRequest,royaltyFreezes:[]});
const normalized = recovered.normalizeArtistRecoveredMultipleGenerationHydrationCall(call);
const verified: false = normalized.factsVerified;
const value: bigint = normalized.call.value;
const commitment: Hex = recovered.artistRecoveredMultipleGenerationHydrationCommitment(coords, finalRequest, prepared);
const nativeIndex: bigint = prepared.admission.provenance.journals[2][0]!.position.nativeIndex;
const cpRevision: bigint = prepared.admission.provenance.eras[0]!.checkpoints[2].ownerState.revision;
const scopes: readonly recovered.ArtistRecoveredMultipleGenerationHydrationCollectionWitness[] = finalRequest.records.witnesses;
const cells: ArtistHydrationSeven<readonly recovered.ArtistRecoveredMultipleGenerationHydrationReplayAlias[]> = prepared.admission.provenance.aliases;
const after: ArtistHydrationSnapshot = recovered.artistRecoveredMultipleGenerationHydrationOwnerAfter(
  origin, index, prepared.admission.before_[index], prepared.query, prepared.data[index], commitment, actor, historicalCells,
);
const ownerPayload = recovered.decodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(prepared.data[index].typedState, index);
const publications: readonly recovered.ArtistRecoveredMultipleGenerationHydrationPublication[] = ownerPayload.payload.publications;
const semanticOpaqueBytes: Hex = ownerPayload.payload.semanticState;
const profile: Hex = recovered.encodeArtistRecoveredMultipleGenerationHydrationProfileEvidence(finalRequest, prepared);
const descriptor = recovered.artistRecoveredMultipleGenerationHydrationEvidenceDescriptor(profile);
const pageId: Hex = recovered.artistRecoveredMultipleGenerationHydrationPageId(coords, commitment, descriptor, 0n);
const reconstructed: Hex = recovered.assembleArtistRecoveredMultipleGenerationHydrationEvidence(descriptor, recovered.artistRecoveredMultipleGenerationHydrationEvidencePages(profile));
const state: recovered.ArtistRecoveredMultipleGenerationHydrationOperationEvidence = {
  schemaVersion: 1n, configurationHash: raw, operationId: 60n, actor, commitment,
  before: prepared.admission.before_, after: prepared.admission.before_, profileData: recovered.encodeArtistRecoveredMultipleGenerationHydrationEvidenceCarrier(descriptor),
};
recovered.decodeArtistRecoveredMultipleGenerationHydrationOperationEvidence(recovered.encodeArtistRecoveredMultipleGenerationHydrationOperationEvidence(state));

// @ts-expect-error Exact chain widths require bigint.
recovered.normalizeArtistRecoveredMultipleGenerationHydrationCoordinates({ ...coords, chainId: 1 });
// @ts-expect-error Native points use bigint revisions, not JS numbers.
const badPoint: recovered.ArtistRecoveredMultipleGenerationHydrationPoint = { environmentHash: raw, ownerIndex: 2n, ownerRevision: 1 };
// @ts-expect-error Complete fixed-owner capabilities cannot be an arbitrary dynamic array.
const badRequest: recovered.ArtistRecoveredMultipleGenerationHydrationRequest = { ...request, expectedCapabilities: [] };
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
recovered.artistRecoveredMultipleGenerationHydrationPageId(coords, commitment, descriptor, 0);
// @ts-expect-error Unknown owner index is not a source owner.
recovered.decodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(raw, 7);
// @ts-expect-error Unpublished future composition is not an implicit extra request field.
recovered.normalizeArtistRecoveredMultipleGenerationHydrationRequest({ ...request, contentFreeze: true });
void [readData, inventory, verified, value, nativeIndex, cpRevision, cells, publications, semanticOpaqueBytes, pageId, reconstructed];

const anchor = recovered.artistRecoveredMultipleGenerationHydrationAnchor(aggregate);
const partition = recovered.validateArtistRecoveredMultipleGenerationHydrationState(index, aggregate, ownerPayload.payload.provenance);
const aggregateBytes: Hex = recovered.encodeArtistRecoveredMultipleGenerationHydrationState(partition, index, ownerPayload.payload.provenance);
const decodedPartition = recovered.decodeArtistRecoveredMultipleGenerationHydrationState(aggregateBytes, index, ownerPayload.payload.provenance);
const identity = recovered.decodeArtistRecoveredMultipleGenerationHydrationIdentity(raw);
const principal: Address = identity.identity.authorityAddress;
const counter: bigint = identity.nextRegistrationNonce;
const payout = recovered.decodeArtistRecoveredMultipleGenerationHydrationPayout(raw);
recovered.encodeArtistRecoveredMultipleGenerationHydrationPayout(payout);
// @ts-expect-error Aggregate rows retain immutable byte strings.
decodedPartition.rows.push(raw);
// @ts-expect-error Aggregate scope quantities remain bigint.
decodedPartition.collections[0]!.collectionId = 2;
// @ts-expect-error Retained recovery histories cannot be edited in place.
identity.recoveries.push(identity.recoveries[0]!);
void [anchor, principal, counter];

declare const complete: recovered.ArtistRecoveredMultipleGenerationHydrationInventory;
declare const facts: recovered.ArtistRecoveredMultipleGenerationHydrationClockFacts;
const clocks: recovered.ArtistRecoveredMultipleGenerationHydrationClockResult = recovered.validateArtistRecoveredMultipleGenerationHydrationClocks(aggregate,prepared.admission.provenance,complete,facts);
const suppliedOnly: false = clocks.factsVerified;
const timelines: readonly recovered.ArtistRecoveredMultipleGenerationHydrationTimeline[] = clocks.collections;
const binding = recovered.decodeArtistRecoveredMultipleGenerationHydrationBindingBundle(raw);
const acceptance = recovered.decodeArtistRecoveredMultipleGenerationHydrationAcceptanceBundle(raw);
const attribution = recovered.decodeArtistRecoveredMultipleGenerationHydrationAttribution(raw);
const consents = recovered.decodeArtistRecoveredMultipleGenerationHydrationConsents(raw);
const aux = recovered.decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(raw,index,ownerPayload.payload.provenance);
recovered.validateArtistRecoveredMultipleGenerationHydrationRevocations(aggregate,prepared.admission.provenance,complete,[attribution.history],clocks);
const uses = recovered.validateArtistRecoveredMultipleGenerationHydrationAttestations([identity],aggregate.collections,[attribution.records],prepared.admission.provenance,complete,clocks);
const sourceFactsVerified: false = uses.factsVerified;
const input: recovered.ArtistRecoveredMultipleGenerationHydrationInput = {request:finalRequest,royaltyFreezes:[]};
recovered.normalizeArtistRecoveredMultipleGenerationHydrationInput(input);
recovered.validateArtistRecoveredMultipleGenerationHydrationInput(input,prepared);
recovered.encodeArtistRecoveredMultipleGenerationHydrationAuxiliaryState(aggregate,0,ownerPayload.payload.provenance,recovered.encodeArtistRecoveredMultipleGenerationHydrationInventory(complete));
const completion = recovered.decodeArtistRecoveredMultipleGenerationHydrationArchiveEnvelope(raw);
const archiveVersion: bigint = completion.version;
// @ts-expect-error Original Archive bytes do not independently prove their read provenance.
const provenanceVerified: true = clocks.factsVerified;
// @ts-expect-error Generation rows are immutable.
binding.bindings.rows[0]!.item.generation=2n;
// @ts-expect-error Complete catalogue cutoffs retain all seven owner slots.
const incompleteCatalogue: recovered.ArtistRecoveredMultipleGenerationHydrationInventory = {...complete,catalogues:[{...complete.catalogues[0]!,upper:[0n]}]};
// @ts-expect-error No caller-provided signature packet is part of operation60 input.
recovered.normalizeArtistRecoveredMultipleGenerationHydrationInput({...input,signature:raw});
// @ts-expect-error Current-generation fields require bigint, not number.
const wrongGeneration: recovered.ArtistRecoveredMultipleGenerationHydrationGeneration={...complete.generations[0]![0]!,generation:2};
// @ts-expect-error Original owner4 collection histories are readonly.
attribution.history.revocations.push(attribution.history.revocations[0]!);
// @ts-expect-error Every clock vector stays immutable.
timelines[0]!.completions.push(timelines[0]!.completions[0]!);
void [suppliedOnly,sourceFactsVerified,archiveVersion,binding,acceptance,consents,aux];
