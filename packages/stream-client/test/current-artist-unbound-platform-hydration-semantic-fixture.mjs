// Synthetic original-shape documentary facts. Private Identity/Payout admission,
// runtime provenance, signatures, governance and actual Registry execution are mocked.
import {AbiCoder,ParamType,ZeroAddress,ZeroHash,getAddress,id,keccak256} from "ethers";
import * as m from "../dist/current-artist-unbound-platform-hydration.js";
import {ARTIST_HYDRATION_SUITE_TUPLE} from "../dist/current-artist-authority-hydration.js";
import {fixture,unboundPlatformTuple,compiledLibraryValueInterface} from "./current-artist-unbound-platform-hydration-source-fixture.mjs";
export {m,fixture};
export const coder=AbiCoder.defaultAbiCoder(),Z=ZeroHash;
export const A=n=>getAddress("0x"+BigInt(n).toString(16).padStart(40,"0")),H=n=>"0x"+BigInt(n).toString(16).padStart(64,"0");
export const hash=(types,values)=>keccak256(coder.encode(types,values)),seven=fn=>Array.from({length:7},(_,i)=>fn(i)),child=(t,n)=>t.components.find(c=>c.name===n),findType=unboundPlatformTuple;
const clone=structuredClone;
export function zero(type){const t=typeof type==="string"?ParamType.from(type):type;if(t.baseType==="tuple")return Object.fromEntries(t.components.map(c=>[c.name,zero(c)]));if(t.baseType==="array")return Array.from({length:Math.max(0,t.arrayLength)},()=>zero(t.arrayChildren));if(t.type==="address")return ZeroAddress;if(t.type==="bool")return false;if(t.type==="string")return "";if(t.type==="bytes")return "0x";if(t.type.startsWith("bytes"))return "0x"+"00".repeat(Number(t.type.slice(5)));return 0n;}
export const T={
 state:findType("StreamArtistRecoveredMultipleTypes.State"),platform:findType("StreamArtistRecoveredPlatformTypes.Platform"),
 identity:findType("StreamArtistRecoveredIdentityHydrationTypes.Bundle"),payout:findType("StreamArtistRecoveredPayoutTypes.Bundle"),
 binding:findType("StreamArtistRecoveredSimpleHydrationTypes.Binding"),acceptance:findType("StreamArtistRecoveredSimpleHydrationTypes.Acceptance"),
 attribution:findType("StreamArtistRecoveredCollectionHydration.AttributionBundle"),policy:findType("StreamArtistRecoveredCollectionHydration.PolicyBundle"),
 envelope:findType("StreamArtistRecoveredSanctionHistoryTypes.Envelope"),claimPayload:findType("StreamArtistRecoveredPlatformPayload.Claim"),contestPayload:findType("StreamArtistRecoveredPlatformPayload.ContestPayload"),
};
T.prepared=compiledLibraryValueInterface("prepared").fragments.find(f=>f.type==="function"&&f.name==="prepare"&&f.inputs.length===2).outputs[0];
T.pState=child(T.platform,"state");T.pClaim=child(T.platform,"claims").arrayChildren;T.pContest=child(T.platform,"contests").arrayChildren;T.allegation=child(T.platform,"allegations").arrayChildren;
const flat=(type,v)=>coder.encode(type.components,type.components.map(c=>v[c.name]));
const emptyHash=domain=>hash(["bytes32","bytes32[]"],[id(domain),[]]);
const domain=i=>m.artistUnboundPlatformHydrationOwnerDomain(i);
const platformSurface=op=>op===10n?id("attribution_lifecycle.replay.claim_record_hash_uniqueness"):hash(["string","uint16"],["PLATFORM_WORKS",op]);
export function semanticFixture(args={}){
 const options=args.options??args,{mixed=false,claims=false,correction=false,repeated=false}=options;
 const source=args.source??{registry:A(1),archive:A(3),owners:seven(i=>A(10+i)),core:A(4),mintManager:A(5),roleRegistry:A(6),metadata:A(7),primaryResolver:A(8),royaltyResolver:A(9),primaryRevenueClass:H(8),validator:A(17)};
 const chainId=args.origin?.chainId??(1n<<200n)+11n;
 const origin=args.origin??{chainId,registry:source.registry,coordinator:A(2),archive:source.archive,owners:source.owners,ownerCodeHashes:seven(i=>H(100+i)),core:source.core,manager:source.mintManager,suiteConfigurationHash:hash([ARTIST_HYDRATION_SUITE_TUPLE],[source])};
 const origins=Array.from({length:repeated?3:1},(_,i)=>{if(i===(repeated?2:0))return clone(origin);const suite={...source,registry:A(4000+100*i),archive:A(4002+100*i),owners:seven(j=>A(4010+100*i+j))};return {...origin,registry:suite.registry,coordinator:A(4001+100*i),archive:suite.archive,owners:suite.owners,suiteConfigurationHash:hash([ARTIST_HYDRATION_SUITE_TUPLE],[suite])};});
 const ids=mixed?[H(1000),H(1001)]:[],artists=ids.map(artistId=>({artistId,collectionId:0n,bindingHash:Z,policies:[],records:[]}));
 const collections=[{artistId:Z,collectionId:(1n<<240n)+1n,bindingHash:Z,policies:[],records:[]},...(mixed?[0,1,2].map(i=>({artistId:ids[i===1?1:0],collectionId:(1n<<240n)+BigInt(i+2),bindingHash:Z,policies:[],records:[]})):[])];
 const journals=seven(()=>[]),aliases=seven(()=>[]),eras=[],archiveRows=[],envelopes=[],operations=[],platform=zero(T.platform);platform.collectionId=collections[0].collectionId;
 const bindings=collections.map(()=>null),acceptances=collections.map(()=>null),attributions=collections.map(()=>null),policies=collections.map(()=>null);
 const nonces=ids.toReversed().map(artistId=>({index:{kind:1n,key:artistId,prefixCount:1n},words:[{prefix:0n,words:Array.from({length:32},(_,i)=>i?0n:1n),exhausted:false}]}));
 const timingConfig=zero(m.ARTIST_UNBOUND_PLATFORM_HYDRATION_TIMING_CONFIGURATION_TUPLE),timing={schema:id("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1"),version:1n,count:0n,root:Z,configurationHash:hash([m.ARTIST_UNBOUND_PLATFORM_HYDRATION_TIMING_CONFIGURATION_TUPLE],[timingConfig])};
 const identities=artists.map((a,i)=>{const b=zero(T.identity);b.artistId=a.artistId;b.nextRegistrationNonce=BigInt(ids.length);Object.assign(b.identity,{authorityAddress:A(400+i),authorityClass:i?3n:1n,status:1n});b.timing.configuration=clone(timingConfig);b.timing.checkpoint=clone(timing);b.nonces=[{kind:1n,key:a.artistId,hint:0n,words:clone(nonces.find(n=>n.index.key===a.artistId).words)}];const r=zero(child(T.identity,"recoveries").arrayChildren);r.record.fields.vestedAuthorityClass=b.identity.authorityClass;b.recoveries=[r];return b;});
 const payouts=artists.map(a=>({...zero(T.payout),artistId:a.artistId}));
 const codes=args.codes,configs=origins.map((o,i)=>H(8000+i));
 if(codes)for(const o of origins){
  for(let i=0;i<7;i++)if(!codes.has(o.owners[i]))codes.set(o.owners[i],codes.get(origin.owners[i])??"0x60006000");
  for(const key of["registry","coordinator","archive"])if(!codes.has(o[key]))codes.set(o[key],codes.get(origin[key])??"0x60016000");
 }
 let current=zero(T.pState);
 for(let ei=0;ei<origins.length;ei++){
  const o=origins[ei],oh=m.artistUnboundPlatformHydrationOriginHash(o),start=journals.map(j=>j.length),lower=seven(i=>ei?(i===2?2n+BigInt(ids.length+collections.length):1n):0n);
  const clock=seven(i=>({domainId:domain(i),revision:lower[i],stateRoot:H(9000+ei*100+i),recordChainTip:H(9100+ei*100+i)}));
  const point=(owner,revision=clock[owner].revision)=>({environmentHash:oh,ownerIndex:BigInt(owner),ownerRevision:revision});
  const row=(owner,operation,artistId,collectionId,recordHash,revision=clock[owner].revision)=>{const j={position:{point:point(owner,revision),nativeIndex:BigInt(journals[owner].length-start[owner])},receipt:{operation,artistId,collectionId,recordHash}};journals[owner].push(j);return j;};
  const addAlias=(owner,point_,surface,scope,commitment)=>{const entry={surface,scope};aliases[owner].push({originHash:oh,ownerIndex:BigInt(owner),...entry,originalKey:m.artistUnboundPlatformHydrationReplayKey(o,owner,entry),cell:{kind:1n,status:2n,commitment,touchedRevision:point_.ownerRevision},admittedAt:clone(point_)});};
  // Each successor retains original aliases; empty-principal local lane/cutover cells are
  // era-local while root/action cells remain cumulatively spent.
  if(ei)for(let owner=0;owner<7;owner++)for(const a of aliases[owner].filter(a=>a.originHash===eras[ei-1].originHash)){
   if(owner===2&&![id("identity_authority.replay.import_binding_key"),id("identity_authority.replay.governance_action")].includes(a.surface))continue;
   addAlias(owner,a.admittedAt,a.surface,a.scope,a.cell.commitment);
  }
  if(!ei&&mixed){
   ids.forEach((a,i)=>{row(2,1n,a,0n,a,BigInt(3*i+1));row(2,35n,a,0n,H(1500+i),BigInt(3*i+2));row(2,35n,a,0n,H(1600+i),BigInt(3*i+2));});clock[2].revision=10n;
   collections.forEach((q,k)=>{if(q.artistId===Z)return;const b=zero(T.binding);Object.assign(b.item,{artistId:q.artistId,artistAddress:A(50+k),identityRecordHash:H(1200+k),generation:1n,consentMode:1n,proposer:A(70),accepted:true});b.terms.collaboratorSetHash=emptyHash("6529STREAM_ARTIST_COLLABORATOR_SET_V1");b.terms.capabilityPolicySetHash=emptyHash("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1");q.bindingHash=hash(["bytes32","uint256","address","address","uint256","uint64","bytes32","address","bytes32","uint8","uint8","uint8","bytes32","bytes32"],[id("6529STREAM_ARTIST_BINDING_V1"),chainId,o.registry,o.core,q.collectionId,1n,q.artistId,b.item.artistAddress,b.item.identityRecordHash,1n,0n,0n,b.terms.collaboratorSetHash,b.terms.capabilityPolicySetHash]);b.item.bindingHash=q.bindingHash;b.history=clone(b.item);b.scope={artistId:q.artistId,collectionId:q.collectionId,bindingHash:q.bindingHash};bindings[k]=b;
    clock[0].revision++;const j=row(0,1n,q.artistId,q.collectionId,q.bindingHash);addAlias(0,j.position.point,id("binding_lifecycle.replay.proposal_key"),hash(["uint256","uint64"],[q.collectionId,1n]),q.bindingHash);clock[0].revision++;
    clock[3].revision++;const a=row(3,2n,q.artistId,q.collectionId,H(1300+k));addAlias(3,a.position.point,id("acceptance_lifecycle.replay.record_uniqueness"),H(1400+k),a.receipt.recordHash);
    acceptances[k]={scope:clone(b.scope),provenanceCommitment:Z,record:a.receipt.recordHash,acceptedAt:1n};attributions[k]={state:{provenance:Z,artistId:q.artistId,collectionId:q.collectionId,bindingHash:q.bindingHash,item:{state:2n,generation:1n}},proposalOrigin:oh};policies[k]={provenance:Z,artistId:q.artistId,collectionId:q.collectionId,policies:[],records:[]};clock[4].revision+=2n;
   });
  }
  if(!mixed){
   if(ei){for(let k=0;k<collections.length;k++)for(const surface of ["verified_lane_key","import_binding"]){const scope=surface==="verified_lane_key"?hash(["uint8","bytes32"],[2n,H(collections[k].collectionId)]):hash(["uint256","uint8","bytes32"],[0n,2n,H(collections[k].collectionId)]);addAlias(2,point(2,2n+BigInt(k)),id("identity_authority.replay."+surface),scope,H(9200+ei*100+k));}
    for(const surface of ["import_binding_key","governance_action"])addAlias(2,point(2,1n),id("identity_authority.replay."+surface),H(9300+ei),H(9400+ei));
   }
   clock[2].revision=lower[2]+1n;addAlias(2,point(2),id("identity_authority.replay.one_way_cutover_latch"),Z,H(9500+ei));
  }
  let recordSequence=0n;
  function operation(op){
   const e=zero(T.envelope),payloadId=platform.collectionId,at=BigInt(100+ei*20+Number(clock[4].revision));Object.assign(e,{version:1n,configurationHash:configs[ei],operation:op,actor:A(op===8n?80:81)});e.before_[4]=clone(clock[4]);clock[4].revision++;e.after_[4]=clone(clock[4]);
   const pt=point(4);let scope,action,state,record;
   if(op===8n){const r={recordHash:Z,statementHash:H(6000),actor:e.actor,declaredAt:at};r.recordHash=hash(["bytes32","uint256","address","address","uint256","bytes32","uint64"],[id("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"),chainId,o.registry,o.core,payloadId,r.statementHash,r.declaredAt]);platform.declarationPoint=clone(pt);current.declaration=clone(r);platform.state.declaration=clone(r);e.value=r.recordHash;e.payload=coder.encode(["uint256","bytes32","bytes32","uint64"],[payloadId,r.statementHash,H(6010),1n]);scope=H(payloadId);for(const k of[0,6])e.before_[k]=e.after_[k]=clone(clock[k]);
   }else if(op===9n||op===10n){const c=zero(T.claimPayload),n=platform.claims.length+platform.allegations.length;Object.assign(c,{id:payloadId,uri:"urn:unbound-platform:"+n});for(const[name,offset]of[["evidenceDocument",6100],["reasonDocument",6200]])Object.assign(c[name],{schemaVersion:1n,collectionId:payloadId,proposedArtist:A(82),narrativeHash:H(offset+n)});c.evidence=hash([child(T.claimPayload,"evidenceDocument")],[c.evidenceDocument]);c.reason=hash([child(T.claimPayload,"reasonDocument")],[c.reasonDocument]);c.evidenceProof=H(6300+n);c.reasonProof=H(6400+n);
    const r={collectionId:payloadId,claimant:e.actor,proposedArtist:A(82),evidenceHash:c.evidence,reasonHash:c.reason,filedAt:at,recordHash:Z};r.recordHash=hash(["bytes32","uint256","address","address","uint256","address","bytes32","bytes32","uint64"],[id(op===9n?"6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1":"6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1"),chainId,o.registry,o.core,payloadId,e.actor,c.evidence,c.reason,at]);e.value=r.recordHash;e.payload=flat(T.claimPayload,c);scope=hash(["uint256","address","bytes32","bytes32"],[payloadId,e.actor,c.evidence,c.reason]);
    if(op===9n){platform.claims.push({point:clone(pt),record:r});current.claimCount++;current.latestClaim=r.recordHash;}else{Object.assign(r,{reasonURI:c.uri,previousRecordHash:platform.latestAllegation,index:BigInt(platform.allegations.length+1)});platform.allegations.push({point:clone(pt),record:r});platform.allegationCount++;platform.latestAllegation=r.recordHash;state=hash([child(T.allegation,"record")],[r]);action=hash(["uint256","address","bytes32","bytes32","string","address"],[payloadId,e.actor,c.evidence,c.reason,c.uri,c.evidenceDocument.proposedArtist]);}platform.latestDisplayClaim=r.recordHash;
   }else{const c=zero(T.contestPayload),stateCode=op===53n?3n:current.contestState===1n?(correction?3n:2n):1n;Object.assign(c,{id:payloadId,state:stateCode,claim:platform.claims[0].record.recordHash,correction:op===53n});for(const[name,offset]of[["evidenceDocument",6500],["reasonDocument",6600]])Object.assign(c[name],{schemaVersion:1n,collectionId:payloadId,proposedArtist:A(82),claimRecordHash:c.claim,narrativeHash:H(offset+Number(clock[4].revision))});c.evidence=hash([child(T.claimPayload,"evidenceDocument")],[c.evidenceDocument]);c.reason=hash([child(T.claimPayload,"reasonDocument")],[c.reasonDocument]);c.evidenceProof=H(6700);c.reasonProof=H(6800);
    c.context.scopeHash=hash(["bytes32","uint256","address","address","uint256","bool"],[id("6529STREAM_PLATFORM_WORKS_GOVERNANCE_SCOPE_V1"),chainId,o.registry,o.core,payloadId,c.correction]);c.context.oldValueHash=hash([child(T.pState,"declaration"),"uint8","bytes32","bytes32",child(T.pState,"correction")],[current.declaration,current.contestState,current.contestClaim,current.contestRecord,current.correction]);c.context.newValueHash=hash(["bytes32","bytes32","uint8","bytes32","bytes32","bytes32"],[c.context.scopeHash,c.context.oldValueHash,c.state,c.claim,c.evidence,c.reason]);Object.assign(c.governance,{...clone(c.context),actionId:H(6900+ei*100+Number(clock[4].revision)),proposer:A(83),roleMutationHash:H(6999),roleRevision:1n,actionClass:op===53n?2n:1n});
    if(op===11n){const r={collectionId:payloadId,adjudicatedArtist:A(82),state:c.state,claimRecordHash:c.claim,evidenceHash:c.evidence,reasonHash:c.reason,actionId:c.governance.actionId,previousRecordHash:current.contestRecord,changedAt:at,recordHash:Z};r.recordHash=hash(["bytes32","uint256","address",child(T.pContest,"record")],[id("6529STREAM_PLATFORM_WORKS_CONTEST_TRANSITION_V1"),chainId,o.owners[4],r]);platform.contests.push({point:clone(pt),record:r});Object.assign(current,{contestState:r.state,contestClaim:r.claimRecordHash,contestRecord:r.recordHash});e.value=r.recordHash;
    }else{const r={collectionId:payloadId,proposedArtist:A(82),claimRecordHash:c.claim,sustainedContestRecordHash:current.contestRecord,evidenceHash:c.evidence,reasonHash:c.reason,approvalActionId:c.governance.actionId,approvedAt:at,correctiveGeneration:0n,accepted:false,recordHash:Z};r.recordHash=hash(["bytes32","uint256","address","address","uint256","bytes32","bytes32","bytes32","bytes32","bytes32","uint64"],[id("6529STREAM_PLATFORM_WORKS_CORRECTION_RECORD_V1"),chainId,o.registry,o.core,payloadId,r.sustainedContestRecordHash,r.claimRecordHash,r.evidenceHash,r.reasonHash,r.approvalActionId,at]);current.correction=clone(r);platform.correctionPoint=clone(pt);platform.status.originalCorrectionRecord=r.recordHash;e.value=r.recordHash;}
    e.payload=flat(T.contestPayload,c);scope=hash(["uint256","bytes32"],[payloadId,c.governance.actionId]);
   }
   action??=e.value;state??=hash(["uint256",T.pState],[payloadId,current]);record=op===11n?Z:e.value;const replay=m.artistUnboundPlatformHydrationReplayKey(o,4,{surface:platformSurface(op),scope});
   clock[4].stateRoot=hash(["bytes32","uint256","address","address","address","address","bytes32","uint64","uint64","bytes32","bytes32","bytes32","bytes32","bytes32"],[id("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"),chainId,o.registry,o.coordinator,o.archive,o.owners[4],domain(4),e.before_[4].revision,clock[4].revision,e.before_[4].stateRoot,hash(["uint16","address","bytes32"],[op,e.actor,action]),state,replay,hash(["bytes32"],[record])]);
   if(record!==Z){clock[4].recordChainTip=hash(["bytes32","uint256","address","address","address","address","bytes32","uint64","uint64","bytes32","bytes32"],[id("6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2"),chainId,o.registry,o.coordinator,o.archive,o.owners[4],domain(4),recordSequence,recordSequence+1n,e.before_[4].recordChainTip,record]);recordSequence++;}e.after_[4]=clone(clock[4]);
   const j=row(4,op,Z,payloadId,e.value);addAlias(4,j.position.point,platformSurface(op),scope,e.value);
   const raw=flat(T.envelope,e),pointer=A(2000+archiveRows.length),payloadHash=keccak256(raw),evidenceId=hash(["bytes32","uint256","address","address","uint16","address","bytes32"],[id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),chainId,o.registry,o.coordinator,op,e.actor,e.value]),catalogueIndex=BigInt(archiveRows.filter(r=>r.originHash===oh).length);
   const evidence={catalogueIndex,pointer,payloadHash,evidenceId};envelopes.push(raw);operations.push({originHash:oh,operation:op,evidence});archiveRows.push({originHash:oh,catalogueIndex,pointer,kind:id("ARTIST_OPERATION_EVIDENCE"),hash:payloadHash,evidenceId,raw,atBlock:5n});if(codes)codes.set(pointer,"0x00"+raw.slice(2));
  }
  if(!ei){operation(8n);if(claims||correction){operation(9n);operation(10n);operation(11n);operation(11n);if(correction)operation(53n);}}else{operation(9n);operation(10n);}
  const cps=seven(i=>({schema:m.ARTIST_UNBOUND_PLATFORM_HYDRATION_CHECKPOINT_SCHEMA,ownerState:clone(clock[i]),replayRoot:aliases[i].some(a=>a.originHash===oh)?H(10000+ei*100+i):Z,replayCount:BigInt(aliases[i].filter(a=>a.originHash===oh).length),nonceRoot:i===2&&mixed?H(11000+ei):Z,nonceIndexCount:i===2?BigInt(nonces.length):0n}));
  eras.push({originHash:oh,priorImportCommitment:ei?H(12000+ei):Z,checkpoints:cps,nativeCounts:journals.map((rows,i)=>BigInt(rows.length-start[i])),lowerRevisions:lower});
 }
 platform.state=clone(current);
 const provenance={origins,eras,journals,aliases};const last=eras.at(-1),before=args.before??seven(i=>({domainId:domain(i),revision:i===2?1n+BigInt(ids.length+collections.length):0n,stateRoot:H(13000+i),recordChainTip:H(13100+i)}));
 const f={source,origin,provenance,artists,collections,identities,payouts,nonces,timing,before,bindings,acceptances,attributions,policies,platforms:[platform],archiveRows,envelopes,operations,configs,codes,payloads:[],states:[],options,coords:{chainId,registry:args.destination?.registry??A(500),coordinator:A(501)},features:4194304n|(mixed?3n:0n)|(repeated?16n:0n)};
 return refresh(f);
}
export function refresh(f){
 const p=f.provenance,last=p.eras.at(-1),cp=last.checkpoints;for(const rows of p.aliases)rows.sort((a,b)=>BigInt(a.originalKey)<BigInt(b.originalKey)?-1:1);
 for(const a of f.artists)a.records=p.journals.flat().filter(j=>j.receipt.artistId===a.artistId).map(j=>j.receipt.recordHash);for(const q of f.collections)q.records=p.journals.flat().filter(j=>j.receipt.collectionId===q.collectionId).map(j=>j.receipt.recordHash);
 const catalogues=p.origins.map((o,i)=>{const rows=f.archiveRows.filter(r=>r.originHash===p.eras[i].originHash),code=f.codes?.get(o.archive),c={originHash:p.eras[i].originHash,archiveCodeHash:code?keccak256(code):H(14000+i),configurationHash:f.configs[i],count:BigInt(rows.length),rowsHash:Z,lower:clone(p.eras[i].lowerRevisions),upper:p.eras[i].checkpoints.map(c=>c.ownerState.revision)};c.rowsHash=hash(["bytes32","bytes32","address","bytes32","bytes32","uint256"],[id("6529STREAM_ARTIST_RECOVERED_PLATFORM_CATALOGUE_V1"),c.originHash,o.archive,c.archiveCodeHash,c.configurationHash,c.count]);for(const r of rows)c.rowsHash=hash(["bytes32","uint256","address","bytes32","bytes32"],[c.rowsHash,r.catalogueIndex,r.pointer,r.kind,r.hash]);return c;});
 for(const b of f.platforms){b.catalogues=clone(catalogues);b.operations=clone(f.operations);}
 const logical=p.aliases.map(rows=>rows.filter(a=>a.originHash===last.originHash).map(({surface,scope})=>({surface,scope})));
 const data=seven(owner=>{const local=m.artistUnboundPlatformHydrationOwnerProvenance(p,owner),commitment=m.artistUnboundPlatformHydrationOwnerProvenanceHash(local,owner);let rows=[];
  if(owner===0)rows=f.bindings.map(b=>{if(!b)return "0x";b.provenanceCommitment=commitment;return coder.encode([T.binding],[b]);});
  if(owner===2){rows=f.identities.map(b=>{b.sourceSnapshot=clone(cp[2].ownerState);return coder.encode([T.identity],[b]);});if(!f.artists.length)rows=[m.encodeArtistUnboundPlatformHydrationEmptyIdentity(f.timing)];}
  if(owner===3)rows=f.acceptances.map(b=>{if(!b)return "0x";b.provenanceCommitment=commitment;return coder.encode([T.acceptance],[b]);});
  if(owner===4)rows=f.collections.map((q,k)=>{if(q.artistId===Z){const b=f.platforms.find(b=>b.collectionId===q.collectionId);b.provenance=commitment;return coder.encode([T.platform],[b]);}const b=f.attributions[k];b.state.provenance=commitment;return coder.encode([`tuple(${T.attribution.format("full")} state,bytes32 proposalOrigin)`],[b]);});
  if(owner===5)rows=f.payouts.map(b=>{b.sourceSnapshot=clone(cp[5].ownerState);return coder.encode(["bytes32",T.payout],[id("6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1"),b]);});
  if(owner===6)rows=f.policies.map(b=>{if(!b)return "0x";b.provenance=commitment;return coder.encode([T.policy],[b]);});
  const state={artists:clone(f.artists),collections:clone(f.collections),rows};f.states[owner]=state;
  const publications=f.codes&&[2,4,6].includes(owner)?[{pointer:A(90+owner),payloadType:H(800+owner),payloadHash:keccak256("0x1234")}]:[];if(publications.length)f.codes.set(publications[0].pointer,"0x001234");
  const payload={provenance:local,nonces:owner===2?clone(f.nonces):[],publications,semanticState:coder.encode(["bytes32","uint16","uint8",T.state],[id("6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1"),1n,BigInt(owner),state])};f.payloads[owner]=payload;
  const keys=logical[owner].map(v=>m.artistUnboundPlatformHydrationReplayKey(f.origin,owner,v));return {typedState:m.encodeArtistUnboundPlatformHydrationOwnerPayload(payload,owner,f.features),origins:logical[owner],sourceKeys:keys,cells:keys.map(k=>p.aliases[owner].find(a=>a.originalKey===k).cell),nonces:[]};
 });
 const first=f.collections[0],query={...clone(first),records:clone(first.artistId===Z?first.records:f.artists.find(a=>a.artistId===first.artistId).records)};
 f.prepared=f.certificate={admission:{prior:f.origin.registry,sourceCoordinator:f.origin.coordinator,source:f.source,provenance:p,artists:f.artists,collections:f.collections,before_:f.before},query,data,timing:f.timing,externalGuards:{schema:id(f.artists.length?"6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1":"6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1"),provenanceCommitment:m.artistUnboundPlatformHydrationProvenanceHash(p),artistId:f.artists[0]?.artistId??Z,actions:[],finality:[],entropy:[]}};
 f.request={records:{authority:{bindingIndex:0n,artistIds:f.artists.map(a=>a.artistId),collections:f.collections.map(q=>({artistId:q.artistId,collectionId:q.collectionId,policies:clone(q.policies)})),expectedSource:cp,replayOrigins:logical},witnesses:[]},expectedCapabilities:seven(i=>({profile:m.ARTIST_UNBOUND_PLATFORM_HYDRATION_PROFILE,version:1n,ownerIndex:BigInt(i),ownerDomain:domain(i),checkpointSchema:m.ARTIST_UNBOUND_PLATFORM_HYDRATION_CHECKPOINT_SCHEMA,stateSchema:m.artistUnboundPlatformHydrationOwnerTag(i),supportedFeatures:8388607n})),expectedSourceImportCommitment:last.priorImportCommitment,expectedSemanticInventory:Z};
 const q=f.prepared;f.request.expectedSemanticInventory=hash(["bytes32","uint16","bytes32",child(T.prepared,"query"),child(T.prepared,"data"),child(T.prepared,"timing"),child(T.prepared,"externalGuards")],[id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"),1n,m.artistUnboundPlatformHydrationProvenanceHash(p),q.query,q.data,q.timing,q.externalGuards]);f.input={request:f.request,royaltyFreezes:[]};return f;
}
