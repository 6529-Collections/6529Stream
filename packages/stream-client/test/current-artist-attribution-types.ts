import {
  prepareArtistAttributionCall, normalizeArtistAttributionCall, artistAttributionSigningPayload,
  prepareArtistAttributionRead, decodeArtistAttributionRead, decodeArtistAttributionArchiveDetail,
  encodeArtistAttributionArchiveDetail, encodeArtistAttributionArchiveEnvelope,
  decodeArtistAttributionArchiveEnvelope, artistAttributionOpeningContext, artistAttributionResolutionContext,
  artistAttributionClaimRecordHash, artistAttributionDisputeRecordHash, artistAttributionRepudiationRecordHash,
  validateArtistAttributionAuthorization, artistAttributionEvidenceId,
  type ArtistAttributionRequest, type ArtistAttributionArchiveDetail, type ArtistAttributionCoordinates,
  type ArtistAttributionAuthorization, type ArtistAttributionFiling, type ArtistAttributionStanding,
  type ArtistAttributionClaim, type ArtistAttributionRecord, type ArtistAttributionRepudiationRecord,
  type ArtistAttributionResolutionRequest, type ArtistAttributionBinding, type ArtistAttributionHead,
  type ArtistAttributionArchiveEnvelope,
} from '../src/current-artist-attribution.js';
import { toSafeCall } from '../src/safe.js';
import type { Address, Hex } from '../src/generated/contracts.js';

declare const coordinates: ArtistAttributionCoordinates;
declare const actor: Address;
declare const hash: Hex;
declare const filing: ArtistAttributionFiling;
declare const authorization: ArtistAttributionAuthorization;
declare const standing: ArtistAttributionStanding;
declare const resolution: ArtistAttributionResolutionRequest;
declare const claim: ArtistAttributionClaim;
declare const record: ArtistAttributionRecord;
declare const repudiation: ArtistAttributionRepudiationRecord;
declare const binding: ArtistAttributionBinding;
declare const head: ArtistAttributionHead;
declare const envelope: ArtistAttributionArchiveEnvelope;

const claims: Extract<ArtistAttributionRequest,{kind:'fileAttributionClaim'}> = {kind:'fileAttributionClaim',collectionId:1n,evidenceHash:hash,reasonHash:hash,reasonURI:''};
const opens: Extract<ArtistAttributionRequest,{kind:'openAttributionDispute'}> = {kind:'openAttributionDispute',mode:'signed',filing,standing,authorization};
const counters: Extract<ArtistAttributionRequest,{kind:'recordCounterStatement'}> = {kind:'recordCounterStatement',filing,standing,authorization};
const resolves: Extract<ArtistAttributionRequest,{kind:'resolveAttributionDispute'}> = {kind:'resolveAttributionDispute',resolution};
const stages: Extract<ArtistAttributionRequest,{kind:'revokeAttribution'}> = {kind:'revokeAttribution',filing,authorization};
const vetoes: Extract<ArtistAttributionRequest,{kind:'vetoAttributionRepudiation'}> = {kind:'vetoAttributionRepudiation',collectionId:1n,expectedRepudiation:hash,reasonHash:hash};
const cancels: Extract<ArtistAttributionRequest,{kind:'cancelAttributionRepudiation'}> = {kind:'cancelAttributionRepudiation',collectionId:1n,expectedRepudiation:hash};
const executes: Extract<ArtistAttributionRequest,{kind:'executeAttributionRepudiation'}> = {kind:'executeAttributionRepudiation',collectionId:1n,expectedRepudiation:hash};
const withdrawals: Extract<ArtistAttributionRequest,{kind:'withdrawAttributionDispute'}> = {kind:'withdrawAttributionDispute',filing,standing,authorization};
for(const request of [claims,opens,counters,resolves,stages,vetoes,cancels,executes,withdrawals]){
  const prepared=normalizeArtistAttributionCall(prepareArtistAttributionCall(coordinates,actor,request));
  const unverified: false=prepared.factsVerified;
  const safe=toSafeCall(prepared.call);
  void [unverified,safe];
  // @ts-expect-error Returned calls and requests are immutable.
  prepared.call.value=1n;
}
const payload=artistAttributionSigningPayload(coordinates,filing,authorization);
const nonce:bigint=payload.message.nonce;
// @ts-expect-error The signed message is readonly.
payload.message.disputeAction=2n;
const checked=validateArtistAttributionAuthorization(actor,actor,authorization,1n);
const signaturesUnverified:false=checked.signatureExecutionVerified;
void [nonce,signaturesUnverified];

const read=prepareArtistAttributionRead(actor,{host:'registry',kind:'attributionClaimRecord',recordHash:hash});
const decodedClaim:ArtistAttributionClaim=decodeArtistAttributionRead(read,hash);
const rawPending:Hex=decodeArtistAttributionRead(prepareArtistAttributionRead(actor,{host:'owner',kind:'rawPendingRepudiation',collectionId:1n}),hash);
const livePending=decodeArtistAttributionRead(prepareArtistAttributionRead(actor,{host:'registry',kind:'pendingRepudiation',collectionId:1n}),hash);
const generation:bigint=livePending.bindingGeneration;
const terminal=decodeArtistAttributionRead(prepareArtistAttributionRead(actor,{host:'owner',kind:'attributionRepudiationTerminal',recordHash:hash}),hash);
const phase:bigint=terminal.phase;
void [decodedClaim,rawPending,generation,phase];
// @ts-expect-error The Registry has only its live pending getter.
prepareArtistAttributionRead(actor,{host:'registry',kind:'rawPendingRepudiation',collectionId:1n});
// @ts-expect-error The owner has no Registry filtered pending getter.
prepareArtistAttributionRead(actor,{host:'owner',kind:'pendingRepudiation',collectionId:1n});
// @ts-expect-error Width-bearing inputs are bigint, never JS number.
prepareArtistAttributionCall(coordinates,actor,{...claims,collectionId:1});
// @ts-expect-error No generic Registry call route.
prepareArtistAttributionCall(coordinates,actor,{kind:'call',data:hash});
// @ts-expect-error Claim requires no signature field.
prepareArtistAttributionCall(coordinates,actor,{...claims,signature:hash});

// Every bigint discriminator can be selected independently with Extract.
declare const d10:Extract<ArtistAttributionArchiveDetail,{operationId:10n}>;
declare const d44:Extract<ArtistAttributionArchiveDetail,{operationId:44n}>;
declare const d45:Extract<ArtistAttributionArchiveDetail,{operationId:45n}>;
declare const d46:Extract<ArtistAttributionArchiveDetail,{operationId:46n}>;
declare const d47:Extract<ArtistAttributionArchiveDetail,{operationId:47n}>;
const d48:Extract<ArtistAttributionArchiveDetail,{operationId:48n}>={operationId:48n,r:repudiation,proof:{collectionId:1n,repudiationRecordHash:hash,capturedGuardianSet:hash,currentGuardianSet:hash,vetoer:actor,reasonHash:hash,vetoedAt:1n},contest:hash};
const d49:Extract<ArtistAttributionArchiveDetail,{operationId:49n}>={operationId:49n,r:repudiation};
const d50:Extract<ArtistAttributionArchiveDetail,{operationId:50n}>={operationId:50n,r:repudiation};
declare const d61:Extract<ArtistAttributionArchiveDetail,{operationId:61n}>;
const detailScopes:readonly bigint[]=[d10.id,d44.p.collectionId,d45.p.collectionId,d46.p.collectionId,d47.p.collectionId,d48.r.terms.collectionId,d49.r.terms.collectionId,d50.r.terms.collectionId,d61.p.collectionId];
void detailScopes;
for(const detail of [d10,d44,d45,d46,d47,d48,d49,d50,d61])encodeArtistAttributionArchiveDetail(detail);
const detail=decodeArtistAttributionArchiveDetail(61n,hash);
if(detail.operationId===61n){const delegated:Hex=detail.standing.delegation;void delegated;}
const decoded=decodeArtistAttributionArchiveEnvelope(encodeArtistAttributionArchiveEnvelope(envelope));
// @ts-expect-error Nested fixed original snapshots are readonly.
decoded.before_[0].revision=9n;
const hashes:readonly Hex[]=[artistAttributionClaimRecordHash(coordinates,claim),artistAttributionDisputeRecordHash(coordinates,record),artistAttributionRepudiationRecordHash(coordinates,repudiation),artistAttributionEvidenceId(coordinates,actor,61n,actor,hash)];
const contexts=[artistAttributionOpeningContext(coordinates,filing,binding,2n,head),artistAttributionResolutionContext(coordinates,resolution,binding,4n,head)];
void [hashes,contexts];
