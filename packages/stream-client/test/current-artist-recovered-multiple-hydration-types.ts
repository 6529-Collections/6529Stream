import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistHydrationOwnerIndex, ArtistHydrationSeven, ArtistHydrationSnapshot, ArtistHydrationSuite } from "../src/current-artist-authority-hydration.js";
import * as recovered from "../src/current-artist-recovered-multiple-hydration.js";

declare const registry: Address, actor: Address, raw: Hex;
declare const request: recovered.ArtistRecoveredMultipleHydrationRequest;
declare const prepared: recovered.ArtistRecoveredMultipleHydrationPrepared;
declare const coords: recovered.ArtistRecoveredMultipleHydrationCoordinates;
declare const origin: recovered.ArtistRecoveredMultipleHydrationOriginEnvironment;
declare const suite: ArtistHydrationSuite;
declare const index: ArtistHydrationOwnerIndex;
declare const aggregate: recovered.ArtistRecoveredMultipleHydrationState;
declare const historicalCells: readonly recovered.ArtistRecoveredMultipleHydrationHistoricalCell[];

const draft: recovered.ArtistRecoveredMultipleHydrationRequest = recovered.normalizeArtistRecoveredMultipleHydrationRequestDraft({
  ...request, expectedSemanticInventory: `0x${"00".repeat(32)}`,
});
const readData: Hex = recovered.artistRecoveredMultipleHydrationPreparationCalldata(suite, draft);
const certificate: recovered.ArtistRecoveredMultipleHydrationPrepared = recovered.decodeArtistRecoveredMultipleHydrationPrepared(raw);
const inventory: Hex = recovered.artistRecoveredMultipleHydrationSemanticInventory(certificate);
const finalRequest = recovered.normalizeArtistRecoveredMultipleHydrationRequest({ ...draft, expectedSemanticInventory: inventory });
const call: recovered.ArtistRecoveredMultipleHydrationCall = recovered.prepareArtistRecoveredMultipleHydrationCall(registry, actor, finalRequest);
const normalized = recovered.normalizeArtistRecoveredMultipleHydrationCall(call);
const verified: false = normalized.factsVerified;
const value: bigint = normalized.call.value;
const commitment: Hex = recovered.artistRecoveredMultipleHydrationCommitment(coords, finalRequest, prepared);
const nativeIndex: bigint = prepared.admission.provenance.journals[2][0]!.position.nativeIndex;
const cpRevision: bigint = prepared.admission.provenance.eras[0]!.checkpoints[2].ownerState.revision;
const scopes: readonly recovered.ArtistRecoveredMultipleHydrationCollectionWitness[] = finalRequest.records.witnesses;
const cells: ArtistHydrationSeven<readonly recovered.ArtistRecoveredMultipleHydrationReplayAlias[]> = prepared.admission.provenance.aliases;
const after: ArtistHydrationSnapshot = recovered.artistRecoveredMultipleHydrationOwnerAfter(
  origin, index, prepared.admission.before_[index], prepared.query, prepared.data[index], commitment, actor, historicalCells,
);
const ownerPayload = recovered.decodeArtistRecoveredMultipleHydrationOwnerPayload(prepared.data[index].typedState, index);
const publications: readonly recovered.ArtistRecoveredMultipleHydrationPublication[] = ownerPayload.payload.publications;
const semanticOpaqueBytes: Hex = ownerPayload.payload.semanticState;
const profile: Hex = recovered.encodeArtistRecoveredMultipleHydrationProfileEvidence(finalRequest, prepared);
const descriptor = recovered.artistRecoveredMultipleHydrationEvidenceDescriptor(profile);
const pageId: Hex = recovered.artistRecoveredMultipleHydrationPageId(coords, commitment, descriptor, 0n);
const reconstructed: Hex = recovered.assembleArtistRecoveredMultipleHydrationEvidence(descriptor, recovered.artistRecoveredMultipleHydrationEvidencePages(profile));
const state: recovered.ArtistRecoveredMultipleHydrationOperationEvidence = {
  schemaVersion: 1n, configurationHash: raw, operationId: 60n, actor, commitment,
  before: prepared.admission.before_, after: prepared.admission.before_, profileData: recovered.encodeArtistRecoveredMultipleHydrationEvidenceCarrier(descriptor),
};
recovered.decodeArtistRecoveredMultipleHydrationOperationEvidence(recovered.encodeArtistRecoveredMultipleHydrationOperationEvidence(state));

// @ts-expect-error Exact chain widths require bigint.
recovered.normalizeArtistRecoveredMultipleHydrationCoordinates({ ...coords, chainId: 1 });
// @ts-expect-error Native points use bigint revisions, not JS numbers.
const badPoint: recovered.ArtistRecoveredMultipleHydrationPoint = { environmentHash: raw, ownerIndex: 2n, ownerRevision: 1 };
// @ts-expect-error Complete fixed-owner capabilities cannot be an arbitrary dynamic array.
const badRequest: recovered.ArtistRecoveredMultipleHydrationRequest = { ...request, expectedCapabilities: [] };
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
recovered.artistRecoveredMultipleHydrationPageId(coords, commitment, descriptor, 0);
// @ts-expect-error Unknown owner index is not a source owner.
recovered.decodeArtistRecoveredMultipleHydrationOwnerPayload(raw, 7);
// @ts-expect-error Unpublished future composition is not an implicit extra request field.
recovered.normalizeArtistRecoveredMultipleHydrationRequest({ ...request, contentFreeze: true });
void [readData, inventory, verified, value, nativeIndex, cpRevision, cells, publications, semanticOpaqueBytes, pageId, reconstructed];

const anchor = recovered.artistRecoveredMultipleHydrationAnchor(aggregate);
const partition = recovered.validateArtistRecoveredMultipleHydrationState(index, aggregate, ownerPayload.payload.provenance);
const aggregateBytes: Hex = recovered.encodeArtistRecoveredMultipleHydrationState(partition, index, ownerPayload.payload.provenance);
const decodedPartition = recovered.decodeArtistRecoveredMultipleHydrationState(aggregateBytes, index, ownerPayload.payload.provenance);
const identity = recovered.decodeArtistRecoveredMultipleHydrationIdentity(raw);
const principal: Address = identity.identity.authorityAddress;
const counter: bigint = identity.nextRegistrationNonce;
const payout = recovered.decodeArtistRecoveredMultipleHydrationPayout(raw);
recovered.encodeArtistRecoveredMultipleHydrationPayout(payout);
// @ts-expect-error Aggregate rows retain immutable byte strings.
decodedPartition.rows.push(raw);
// @ts-expect-error Aggregate scope quantities remain bigint.
decodedPartition.collections[0]!.collectionId = 2;
// @ts-expect-error Retained recovery histories cannot be edited in place.
identity.recoveries.push(identity.recoveries[0]!);
void [anchor, principal, counter];
