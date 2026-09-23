import type { Address, Hex } from "../src/generated/contracts.js";
import type { ArtistHydrationOwnerIndex, ArtistHydrationSeven, ArtistHydrationSnapshot, ArtistHydrationSuite } from "../src/current-artist-authority-hydration.js";
import * as recovered from "../src/current-artist-unbound-platform-hydration.js";

declare const registry: Address, actor: Address, raw: Hex;
declare const request: recovered.ArtistUnboundPlatformHydrationRequest;
declare const prepared: recovered.ArtistUnboundPlatformHydrationPrepared;
declare const coords: recovered.ArtistUnboundPlatformHydrationCoordinates;
declare const origin: recovered.ArtistUnboundPlatformHydrationOriginEnvironment;
declare const suite: ArtistHydrationSuite;
declare const index: ArtistHydrationOwnerIndex;
declare const aggregate: recovered.ArtistUnboundPlatformHydrationState;
declare const historicalCells: readonly recovered.ArtistUnboundPlatformHydrationHistoricalCell[];

const draft: recovered.ArtistUnboundPlatformHydrationRequest = recovered.normalizeArtistUnboundPlatformHydrationRequestDraft({
  ...request, expectedSemanticInventory: `0x${"00".repeat(32)}`,
});
const readData: Hex = recovered.artistUnboundPlatformHydrationPreparationCalldata(suite, {request:draft,royaltyFreezes:[]});
const certificate: recovered.ArtistUnboundPlatformHydrationPrepared = recovered.decodeArtistUnboundPlatformHydrationPrepared(raw);
const inventory: Hex = recovered.artistUnboundPlatformHydrationSemanticInventory(certificate);
const finalRequest = recovered.normalizeArtistUnboundPlatformHydrationRequest({ ...draft, expectedSemanticInventory: inventory });
const call: recovered.ArtistUnboundPlatformHydrationCall = recovered.prepareArtistUnboundPlatformHydrationCall(registry, actor, {request:finalRequest,royaltyFreezes:[]});
const normalized = recovered.normalizeArtistUnboundPlatformHydrationCall(call);
const verified: false = normalized.factsVerified;
const value: bigint = normalized.call.value;
const commitment: Hex = recovered.artistUnboundPlatformHydrationCommitment(coords, finalRequest, prepared);
const nativeIndex: bigint = prepared.admission.provenance.journals[2][0]!.position.nativeIndex;
const cpRevision: bigint = prepared.admission.provenance.eras[0]!.checkpoints[2].ownerState.revision;
const scopes: readonly recovered.ArtistUnboundPlatformHydrationCollectionWitness[] = finalRequest.records.witnesses;
const cells: ArtistHydrationSeven<readonly recovered.ArtistUnboundPlatformHydrationReplayAlias[]> = prepared.admission.provenance.aliases;
const after: ArtistHydrationSnapshot = recovered.artistUnboundPlatformHydrationOwnerAfter(
  origin, index, prepared.admission.before_[index], prepared.query, prepared.data[index], commitment, actor, historicalCells,
);
const ownerPayload = recovered.decodeArtistUnboundPlatformHydrationOwnerPayload(prepared.data[index].typedState, index);
const publications: readonly recovered.ArtistUnboundPlatformHydrationPublication[] = ownerPayload.payload.publications;
const semanticOpaqueBytes: Hex = ownerPayload.payload.semanticState;
const profile: Hex = recovered.encodeArtistUnboundPlatformHydrationProfileEvidence(finalRequest, prepared);
const descriptor = recovered.artistUnboundPlatformHydrationEvidenceDescriptor(profile);
const pageId: Hex = recovered.artistUnboundPlatformHydrationPageId(coords, commitment, descriptor, 0n);
const reconstructed: Hex = recovered.assembleArtistUnboundPlatformHydrationEvidence(descriptor, recovered.artistUnboundPlatformHydrationEvidencePages(profile));
const state: recovered.ArtistUnboundPlatformHydrationOperationEvidence = {
  schemaVersion: 1n, configurationHash: raw, operationId: 60n, actor, commitment,
  before: prepared.admission.before_, after: prepared.admission.before_, profileData: recovered.encodeArtistUnboundPlatformHydrationEvidenceCarrier(descriptor),
};
recovered.decodeArtistUnboundPlatformHydrationOperationEvidence(recovered.encodeArtistUnboundPlatformHydrationOperationEvidence(state));

// @ts-expect-error Exact chain widths require bigint.
recovered.normalizeArtistUnboundPlatformHydrationCoordinates({ ...coords, chainId: 1 });
// @ts-expect-error Native points use bigint revisions, not JS numbers.
const badPoint: recovered.ArtistUnboundPlatformHydrationPoint = { environmentHash: raw, ownerIndex: 2n, ownerRevision: 1 };
// @ts-expect-error Complete fixed-owner capabilities cannot be an arbitrary dynamic array.
const badRequest: recovered.ArtistUnboundPlatformHydrationRequest = { ...request, expectedCapabilities: [] };
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
recovered.artistUnboundPlatformHydrationPageId(coords, commitment, descriptor, 0);
// @ts-expect-error Unknown owner index is not a source owner.
recovered.decodeArtistUnboundPlatformHydrationOwnerPayload(raw, 7);
// @ts-expect-error Unpublished future composition is not an implicit extra request field.
recovered.normalizeArtistUnboundPlatformHydrationRequest({ ...request, contentFreeze: true });
void [readData, inventory, verified, value, nativeIndex, cpRevision, cells, publications, semanticOpaqueBytes, pageId, reconstructed];

const anchor = recovered.artistUnboundPlatformHydrationAnchor(aggregate);
const partition = recovered.validateArtistUnboundPlatformHydrationState(index, aggregate, ownerPayload.payload.provenance);
const aggregateBytes: Hex = recovered.encodeArtistUnboundPlatformHydrationState(partition, index, ownerPayload.payload.provenance);
const decodedPartition = recovered.decodeArtistUnboundPlatformHydrationState(aggregateBytes, index, ownerPayload.payload.provenance);
const identity = recovered.decodeArtistUnboundPlatformHydrationIdentity(raw);
const principal: Address = identity.identity.authorityAddress;
const counter: bigint = identity.nextRegistrationNonce;
const payout = recovered.decodeArtistUnboundPlatformHydrationPayout(raw);
recovered.encodeArtistUnboundPlatformHydrationPayout(payout);
// @ts-expect-error Aggregate rows retain immutable byte strings.
decodedPartition.rows.push(raw);
// @ts-expect-error Aggregate scope quantities remain bigint.
decodedPartition.collections[0]!.collectionId = 2;
// @ts-expect-error Retained recovery histories cannot be edited in place.
identity.recoveries.push(identity.recoveries[0]!);
void [anchor, principal, counter];

declare const platform: recovered.ArtistUnboundPlatformHydrationPlatform;
declare const ownerProvenance: recovered.ArtistUnboundPlatformHydrationOwnerProvenance;
declare const archiveBytes: readonly Hex[];
const platformRaw: Hex = recovered.encodeArtistUnboundPlatformHydrationPlatform(platform);
const retained = recovered.decodeArtistUnboundPlatformHydrationPlatform(platformRaw);
const validated = recovered.validateArtistUnboundPlatformHydrationPlatform(retained, ownerProvenance);
const timeline = recovered.validateArtistUnboundPlatformHydrationPlatformTimeline(retained, ownerProvenance, {envelopes:archiveBytes});
const noNativeClaim: false = timeline.factsVerified;
const noCatalogueClaim: false = timeline.catalogueRowsIndependentlyVerified;
const stateCopy: recovered.ArtistUnboundPlatformHydrationPlatformState = timeline.state;
const lower: ArtistHydrationSeven<bigint> = retained.catalogues[0]!.lower;
const archive = recovered.decodeArtistUnboundPlatformHydrationArchiveEnvelope(raw);
const snapshots: ArtistHydrationSeven<ArtistHydrationSnapshot> = archive.before_;
const selected: recovered.ArtistUnboundPlatformHydrationPlatformOperationEvidence = retained.operations[0]!;
const op60: recovered.ArtistUnboundPlatformHydrationOperationEvidence = state;
const e = recovered.decodeArtistUnboundPlatformHydrationClaimPayload(raw);
const c = recovered.decodeArtistUnboundPlatformHydrationContestPayload(raw);
const empty = recovered.decodeArtistUnboundPlatformHydrationEmptyIdentity(raw);
const untouched = recovered.validateArtistUnboundPlatformHydrationEmptyIdentity(ownerProvenance, [], aggregate.collections, raw);
const mixed = recovered.decodeArtistUnboundPlatformHydrationAttributionRow(raw);
const binding = recovered.decodeArtistUnboundPlatformHydrationBinding(raw);
const acceptance = recovered.decodeArtistUnboundPlatformHydrationAcceptance(raw);
const policy = recovered.decodeArtistUnboundPlatformHydrationPolicyBundle(raw);
const emptyRoyalties: readonly never[] = call.royaltyFreezes;
// @ts-expect-error This profile only accepts an empty royalty array.
recovered.normalizeArtistUnboundPlatformHydrationInput({request, royaltyFreezes:[{}]});
// @ts-expect-error Original Platform collection quantities require bigint.
retained.collectionId = 2;
// @ts-expect-error Every retained Archive cut is fixed to seven owners.
const incomplete: recovered.ArtistUnboundPlatformHydrationCatalogue = {...retained.catalogues[0]!,upper:[1n]};
// @ts-expect-error Original state transitions preserve fixed seven snapshots.
const shortEnvelope: recovered.ArtistUnboundPlatformHydrationArchiveEnvelope = {...archive,after_:[snapshots[0]]};
// @ts-expect-error Archive selected rows are not operation60 evidence.
const wrongOperation: recovered.ArtistUnboundPlatformHydrationOperationEvidence = selected;
// @ts-expect-error Supplied Archive data does not establish native authority.
const claimed: true = timeline.factsVerified;
// @ts-expect-error Retained native claims cannot be mutated.
retained.claims.push(retained.claims[0]!);
// @ts-expect-error The source-only record wrapper remains immutable.
mixed.proposalOrigin = raw;
// @ts-expect-error There is no caller-chosen platform clock override.
recovered.validateArtistUnboundPlatformHydrationPlatformTimeline(retained,ownerProvenance,{envelopes:archiveBytes,revision:2n});
void [validated,noNativeClaim,noCatalogueClaim,stateCopy,lower,snapshots,op60,e,c,empty,untouched,binding,acceptance,policy,emptyRoyalties];
