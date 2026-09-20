import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistHydrationOwnerIndex, ArtistHydrationSeven, ArtistHydrationSnapshot, ArtistHydrationSuite } from "../src/current-artist-authority-hydration.js";
import * as recovered from "../src/current-artist-recovered-hydration.js";

declare const registry: Address, actor: Address, raw: Hex;
declare const request: recovered.ArtistRecoveredHydrationRequest;
declare const prepared: recovered.ArtistRecoveredHydrationPrepared;
declare const coords: recovered.ArtistRecoveredHydrationCoordinates;
declare const origin: recovered.ArtistRecoveredHydrationOriginEnvironment;
declare const suite: ArtistHydrationSuite;
declare const index: ArtistHydrationOwnerIndex;
declare const historicalCells: readonly recovered.ArtistRecoveredHydrationHistoricalCell[];

const draft: recovered.ArtistRecoveredHydrationRequest = recovered.normalizeArtistRecoveredHydrationRequestDraft({
  ...request, expectedSemanticInventory: `0x${"00".repeat(32)}`,
});
const readData: Hex = recovered.artistRecoveredHydrationPreparationCalldata(suite, draft);
const certificate: recovered.ArtistRecoveredHydrationPrepared = recovered.decodeArtistRecoveredHydrationPrepared(raw);
const inventory: Hex = recovered.artistRecoveredHydrationSemanticInventory(certificate);
const finalRequest = recovered.normalizeArtistRecoveredHydrationRequest({ ...draft, expectedSemanticInventory: inventory });
const call: recovered.ArtistRecoveredHydrationCall = recovered.prepareArtistRecoveredHydrationCall(registry, actor, finalRequest);
const normalized = recovered.normalizeArtistRecoveredHydrationCall(call);
const verified: false = normalized.factsVerified;
const value: bigint = normalized.call.value;
const commitment: Hex = recovered.artistRecoveredHydrationCommitment(coords, finalRequest, prepared);
const nativeIndex: bigint = prepared.admission.provenance.journals[2][0]!.position.nativeIndex;
const cpRevision: bigint = prepared.admission.provenance.eras[0]!.checkpoints[2].ownerState.revision;
const scopes: readonly recovered.ArtistRecoveredHydrationCollectionWitness[] = finalRequest.records.witnesses;
const cells: ArtistHydrationSeven<readonly recovered.ArtistRecoveredHydrationReplayAlias[]> = prepared.admission.provenance.aliases;
const after: ArtistHydrationSnapshot = recovered.artistRecoveredHydrationOwnerAfter(
  origin, index, prepared.admission.before_[index], prepared.query, prepared.data[index], commitment, actor, historicalCells,
);
const ownerPayload = recovered.decodeArtistRecoveredHydrationOwnerPayload(prepared.data[index].typedState, index);
const publications: readonly recovered.ArtistRecoveredHydrationPublication[] = ownerPayload.payload.publications;
const semanticOpaqueBytes: Hex = ownerPayload.payload.semanticState;
const profile: Hex = recovered.encodeArtistRecoveredHydrationProfileEvidence(finalRequest, prepared);
const descriptor = recovered.artistRecoveredHydrationEvidenceDescriptor(profile);
const pageId: Hex = recovered.artistRecoveredHydrationPageId(coords, commitment, descriptor, 0n);
const reconstructed: Hex = recovered.assembleArtistRecoveredHydrationEvidence(descriptor, recovered.artistRecoveredHydrationEvidencePages(profile));
const state: recovered.ArtistRecoveredHydrationOperationEvidence = {
  schemaVersion: 1n, configurationHash: raw, operationId: 60n, actor, commitment,
  before: prepared.admission.before_, after: prepared.admission.before_, profileData: recovered.encodeArtistRecoveredHydrationEvidenceCarrier(descriptor),
};
recovered.decodeArtistRecoveredHydrationOperationEvidence(recovered.encodeArtistRecoveredHydrationOperationEvidence(state));

// @ts-expect-error Exact chain widths require bigint.
recovered.normalizeArtistRecoveredHydrationCoordinates({ ...coords, chainId: 1 });
// @ts-expect-error Native points use bigint revisions, not JS numbers.
const badPoint: recovered.ArtistRecoveredHydrationPoint = { environmentHash: raw, ownerIndex: 2n, ownerRevision: 1 };
// @ts-expect-error Complete fixed-owner capabilities cannot be an arbitrary dynamic array.
const badRequest: recovered.ArtistRecoveredHydrationRequest = { ...request, expectedCapabilities: [] };
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
recovered.artistRecoveredHydrationPageId(coords, commitment, descriptor, 0);
// @ts-expect-error Unknown owner index is not a source owner.
recovered.decodeArtistRecoveredHydrationOwnerPayload(raw, 7);
// @ts-expect-error Unpublished future composition is not an implicit extra request field.
recovered.normalizeArtistRecoveredHydrationRequest({ ...request, contentFreeze: true });
void [readData, inventory, verified, value, nativeIndex, cpRevision, cells, publications, semanticOpaqueBytes, pageId, reconstructed];
