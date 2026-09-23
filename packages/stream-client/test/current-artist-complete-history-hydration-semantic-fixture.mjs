// Compiler-shaped supplied facts for client consistency tests. These fixtures do
// not execute Solidity, prove signature admission, or establish private history
// reconstruction. The mock original Prepared/Registry endpoints are explicit.
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as m from '../dist/current-artist-complete-history-hydration.js';
import { ARTIST_COMPLETE_HISTORY_TUPLES as tuples } from '../dist/generated/artist-complete-history.js';
import { ARTIST_HYDRATION_SUITE_TUPLE } from '../dist/current-artist-authority-hydration.js';
export { m };
export const coder=AbiCoder.defaultAbiCoder(), Z=ZeroHash, A=n=>getAddress(`0x${BigInt(n).toString(16).padStart(40,'0')}`), H=n=>id(String(n));
export const hash=(t,v)=>keccak256(coder.encode(t,v)), seven=f=>Array.from({length:7},(_,i)=>f(i));
export const findType=name=>ParamType.from(tuples[name]), child=(t,name)=>t.components.find(p=>p.name===name);
export function zero(type){const p=typeof type==='string'?ParamType.from(type):type;if(p.baseType==='tuple')return Object.fromEntries(p.components.map(c=>[c.name,zero(c)]));if(p.baseType==='array')return Array.from({length:Math.max(0,p.arrayLength)},()=>zero(p.arrayChildren));if(p.type==='address')return ZeroAddress;if(p.type==='bool')return false;if(p.type==='bytes')return'0x';if(p.type==='string')return'';if(p.type.startsWith('bytes'))return`0x${'00'.repeat(Number(p.type.slice(5)))}`;return 0n;}
export const T={state:findType('StreamArtistRecoveredMultipleTypes.State'),inventory:findType('StreamArtistCompleteHistoryTypes.Inventory'),prepared:findType('StreamArtistRecoveredHydrationCommit.Prepared'),
 binding:findType('StreamArtistRecoveredBindingCorrectionTypes.Bundle'),acceptance:findType('StreamArtistRecoveredAcceptedGenerationTypes.AcceptanceBundle'),platform:findType('StreamArtistRecoveredPlatformTypes.Platform'),
 identity:findType('StreamArtistRecoveredIdentityHydrationTypes.Bundle'),payout:findType('StreamArtistRecoveredPayoutTypes.Bundle'),attribution:ParamType.from(m.ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_TUPLE),
 consents:findType('StreamArtistRecoveredMultipleGenerationTypes.Consents'),supplement:findType('StreamArtistAggregateConsentSupplementTypes.Bundle'),envelope:findType('StreamArtistRecoveredSanctionHistoryTypes.Envelope')};
const clone=structuredClone, domain=i=>m.artistCompleteHistoryHydrationOwnerDomain(i), flat=(t,v)=>coder.encode(t.components,t.components.map(p=>v[p.name]));
export function semanticFixture(args={}) {
 const options=args.options??{}, historical=options.historical===true, repeated=options.repeated===true, platform=options.platform===true;
 if(platform&&(historical||repeated))throw Error('Platform timeline fixture is a separate single-era zero-Artist case');
 const source=args.source??{owners:seven(i=>A(10+i)),registry:A(1),archive:A(3),core:A(4),mintManager:A(5),roleRegistry:A(6),metadata:A(7),primaryResolver:A(8),royaltyResolver:A(9),validator:A(17),primaryRevenueClass:H('primary')};
 const origin=args.origin??{chainId:1n,registry:source.registry,coordinator:A(2),archive:source.archive,owners:source.owners,ownerCodeHashes:seven(i=>H(`runtime${i}`)),core:source.core,manager:source.mintManager,suiteConfigurationHash:hash([ARTIST_HYDRATION_SUITE_TUPLE],[source])};
 const origins=repeated?[{...origin,registry:A(4100),coordinator:A(4101),archive:A(4102),owners:seven(i=>A(4110+i))},clone(origin)]:[clone(origin)];
 origins.forEach(o=>{o.suiteConfigurationHash=hash([ARTIST_HYDRATION_SUITE_TUPLE],[{...source,registry:o.registry,archive:o.archive,owners:o.owners}]);if(args.codes)for(const key of['registry','coordinator','archive'])args.codes.set(o[key],args.codes.get(origin[key])??'0x60006000');if(args.codes)o.owners.forEach((a,i)=>args.codes.set(a,args.codes.get(origin.owners[i])));});
 const ids=historical?[H('Artist A'),H('Artist B')].sort((a,b)=>BigInt(a)<BigInt(b)?-1:1):[], old=ids[0], latest=ids[1];
 const artists=ids.map(artistId=>({artistId,collectionId:0n,bindingHash:Z,policies:[],records:[]})),cid=1001n;
 const collections=[{artistId:historical?latest:Z,collectionId:cid,bindingHash:Z,policies:[],records:[]}];
 const bindings=[zero(T.binding)],acceptances=[zero(T.acceptance)],platforms=[zero(T.platform)],attribution=[zero(T.attribution)],supplements=[zero(T.supplement)];
 const journals=seven(()=>[]),aliases=seven(()=>[]),eras=[],archiveRows=[],operations=[],configs=[],clock=seven(i=>({domainId:domain(i),revision:0n,stateRoot:H(`start${i}`),recordChainTip:H(`tip${i}`)}));
 const timingConfig=zero(m.ARTIST_COMPLETE_HISTORY_HYDRATION_TIMING_CONFIGURATION_TUPLE), timing={schema:id('6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1'),version:1n,count:0n,root:Z,configurationHash:hash([m.ARTIST_COMPLETE_HISTORY_HYDRATION_TIMING_CONFIGURATION_TUPLE],[timingConfig])};
 const nonces=[],identities=ids.map((artistId,i)=>{const b=zero(T.identity);b.artistId=artistId;b.nextRegistrationNonce=BigInt(ids.length);Object.assign(b.identity,{authorityAddress:A(400+i),authorityClass:i?3n:1n,status:1n});b.timing.configuration=clone(timingConfig);b.timing.checkpoint=clone(timing);return b;}),payouts=ids.map(artistId=>({...zero(T.payout),artistId}));
 const common=zero(T.inventory);common.bindings.bindings=bindings;common.bindings.generations=[[]];common.bindings.collaborators=[[]];common.platforms=platforms;common.accepted=acceptances;
 const f={source,origin,origins,artists,collections,identities,payouts,bindings,acceptances,platforms,attribution,attestations:attribution.map(a=>a.records),supplements,contents:[],nonces,timing,common,archiveRows,operations,configs,options,codes:args.codes,states:[],payloads:[],credentialHeads:new Map(),credentialRecords:new Map()};
 for(let era=0;era<origins.length;era++) {
  // A prior op60 commits every owner once, including owners with no native rows.
  if(era)for(let i=0;i<7;i++){clock[i].revision++;clock[i].stateRoot=H(`import root${era}/${i}`);clock[i].recordChainTip=H(`import tip${era}/${i}`);}
  const o=origins[era],oh=m.artistCompleteHistoryHydrationOriginHash(o),start=journals.map(j=>j.length),lower=clock.map(c=>c.revision),config=H(`configuration${era}`);configs.push(config);
  const point=i=>({environmentHash:oh,ownerIndex:BigInt(i),ownerRevision:clock[i].revision});
  function commit(owner,operation,artistId,collectionId,recordHash){clock[owner].revision++;clock[owner].stateRoot=H(`root/${era}/${owner}/${clock[owner].revision}`);clock[owner].recordChainTip=H(`tip/${era}/${owner}/${clock[owner].revision}`);const j={position:{point:point(owner),nativeIndex:BigInt(journals[owner].length-start[owner])},receipt:{operation,artistId,collectionId,recordHash}};journals[owner].push(j);return j;}
  function archive(operation,value,before,payload='0x'){const e={version:1n,configurationHash:config,operation,actor:A(80),value,before_:before,after_:clone(clock),payload};const raw=flat(T.envelope,e),pointer=A(2100+archiveRows.length),payloadHash=keccak256(raw),evidenceId=hash(['bytes32','uint256','address','address','uint16','address','bytes32'],[id('6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1'),o.chainId,o.registry,o.coordinator,operation,A(80),value]),catalogueIndex=BigInt(archiveRows.filter(r=>r.originHash===oh).length),evidence={catalogueIndex,pointer,payloadHash,evidenceId};archiveRows.push({originHash:oh,catalogueIndex,pointer,kind:id('ARTIST_OPERATION_EVIDENCE'),hash:payloadHash,raw,evidenceId,atBlock:5n});operations.push({originHash:oh,operation,evidence});args.codes?.set(pointer,'0x00'+raw.slice(2));return point(operation===2n?3:operation===5n?1:operation===6n?2:operation===1n||operation===3n?0:4);}
  if(!era&&historical) {
   ids.forEach(artistId=>commit(2,1n,artistId,0n,artistId));
   const b=bindings[0];Object.assign(b.bindings,{artistId:latest,collectionId:cid});
   for(let g=1;g<=2;g++) {
    const artistId=g===1?old:latest,row=zero(child(child(T.binding,'bindings'),'rows').arrayChildren);Object.assign(row.item,{artistId,artistAddress:identities[g-1].identity.authorityAddress,identityRecordHash:H(`identity${g}`),generation:BigInt(g),consentMode:2n,proposer:A(80),accepted:g===1});row.terms.collaboratorSetHash=hash(['bytes32','bytes32[]'],[id('6529STREAM_ARTIST_COLLABORATOR_SET_V1'),[]]);row.terms.capabilityPolicySetHash=hash(['bytes32','bytes32[]'],[id('6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1'),[]]);
    row.item.bindingHash=hash(['bytes32','uint256','address','address','uint256','uint64','bytes32','address','bytes32','uint8','uint8','uint8','bytes32','bytes32'],[id('6529STREAM_ARTIST_BINDING_V1'),o.chainId,o.registry,o.core,cid,BigInt(g),artistId,row.item.artistAddress,row.item.identityRecordHash,2n,0n,0n,row.terms.collaboratorSetHash,row.terms.capabilityPolicySetHash]);
    const before=clone(clock),j=commit(0,1n,artistId,cid,row.item.bindingHash);clock[4].revision++;archive(1n,row.item.bindingHash,before);b.bindings.rows.push(row);b.corrections.push(zero(child(T.binding,'corrections').arrayChildren));common.bindings.generations[0].push({bindingHash:row.item.bindingHash,generation:BigInt(g),accepted:row.item.accepted,proposal:clone(j.position.point)});common.bindings.collaborators[0].push([]);
    const a={bindingHash:row.item.bindingHash,generation:BigInt(g),recordHash:Z,acceptedAt:0n};
    if(g===1){const before=clone(clock);a.acceptedAt=100n;a.recordHash=H('original primary acceptance');commit(3,2n,artistId,cid,a.recordHash);clock[0].revision++;clock[4].revision++;archive(2n,a.recordHash,before);}
    acceptances[0].rows.push(a);
   }
   b.bindings.current=clone(b.bindings.rows[1].item);b.bindings.bindingHash=b.bindings.current.bindingHash;collections[0].bindingHash=b.bindings.bindingHash;
   // Deliberately mocked original composition: these immutable records exercise
   // historical Artist getter keys, not a native proof of the inter-generation
   // adjudication. Actual original endpoints remain the admission boundary.
   const consent=supplements[0].original;consent.bindings=b.bindings.rows.map(r=>clone(r.item));const original=consent.rows.original;Object.assign(original,{artistId:latest,collectionId:cid,bindingHash:collections[0].bindingHash});
   const economics=zero(child(child(child(T.supplement,'original'),'rows'),'original').components.find(c=>c.name==='economics').arrayChildren);Object.assign(economics.item.terms,{collectionId:cid,resolver:source.primaryResolver,revenueClass:source.primaryRevenueClass,scope:1n,scopeId:cid,assignmentHash:H('economics assignment')});Object.assign(economics.item.association,{artistId:old,bindingGeneration:1n,bindingHash:b.bindings.rows[0].item.bindingHash,payloadHash:hash([tuples['StreamArtistOnboardingTypes.EconomicsConsent']],[economics.item.terms]),originalRecord:H('first economics')});economics.item.recordHash=economics.item.association.originalRecord;original.economics.push(economics);commit(6,15n,old,cid,economics.item.recordHash);
   if(options.royalties!==false){const royalty=zero(child(child(child(T.supplement,'original'),'rows'),'royalties').arrayChildren);Object.assign(royalty.terms,{resolver:source.royaltyResolver,collectionId:cid,revenueClass:id('ROYALTY_ERC2981'),expectedAssignmentHash:H('royalty assignment')});Object.assign(royalty.item,{recordHash:H('historical royalty'),artistId:old,bindingGeneration:1n});consent.rows.royalties.push(royalty);commit(6,20n,old,cid,royalty.item.recordHash);}
  }
  if(!historical&&!platform) {
   const before=clone(clock),p=platforms[0],at=100n+BigInt(era),prior=p.latestAllegation;
   const record={recordHash:Z,collectionId:cid,claimant:A(80),evidenceHash:H(`evidence${era}`),reasonHash:H(`reason${era}`),reasonURI:'urn:complete:allegation',filedAt:at,proposedArtist:A(82),previousRecordHash:prior,index:BigInt(p.allegations.length+1)};
   record.recordHash=hash(['bytes32','uint256','address','address','uint256','address','bytes32','bytes32','uint64'],[id('6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1'),o.chainId,o.registry,o.core,cid,A(80),record.evidenceHash,record.reasonHash,at]);
   const j=commit(4,10n,Z,cid,record.recordHash);p.allegations.push({point:clone(j.position.point),record});p.allegationCount++;p.latestAllegation=p.latestDisplayClaim=record.recordHash;
   archive(10n,record.recordHash,before,coder.encode(['uint256','bytes32','bytes32','string'],[cid,record.evidenceHash,record.reasonHash,record.reasonURI]));
  }
  if(platform) {
   // Original 8 -> 9 -> 11(open) -> 11(sustain) -> 53. Governance/coverage
   // admission remains mocked; record, replay and owner/Archive preimages do not.
   const p=platforms[0],stateType=findType('StreamArtistPlatformTypes.State');
   const contestType=findType('StreamArtistPlatformTypes.Contest'),contextType=findType('StreamArtistPlatformTypes.Context');
   const governanceType=findType('StreamArtistIdentityContestTypes.GovernanceWitness');
   const evidenceType=ParamType.from('tuple(uint16 schemaVersion,uint256 collectionId,address proposedArtist,bytes32 claimRecordHash,bytes32 narrativeHash)');
   const cellType=ParamType.from('tuple(bytes32 commitment,uint64 touchedRevision,uint8 kind,uint8 status)');
   const proposer=A(82),governor=A(83);let sequence=0n,replayRoot=Z;
   f.platformStages=[];
   const documents=(label,claim)=>['evidence','reason'].map(kind=>({schemaVersion:1n,collectionId:cid,proposedArtist:proposer,claimRecordHash:claim,narrativeHash:H(`${label}/${kind}`)}));
   function platformCommit(operation,actor,record,scope,priorState,payload,body) {
    const before=clone(clock),surface=hash(['string','uint16'],['PLATFORM_WORKS',operation]);
    const originalKey=m.artistCompleteHistoryHydrationReplayKey(o,4,{surface,scope}),old=before[4],next=old.revision+1n,primary=operation===11n?Z:record;
    clock[4].revision=next;
    clock[4].stateRoot=hash(['bytes32','uint256','address','address','address','address','bytes32','uint64','uint64','bytes32','bytes32','bytes32','bytes32','bytes32'],[
     id('6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2'),o.chainId,o.registry,o.coordinator,o.archive,o.owners[4],domain(4),old.revision,next,old.stateRoot,
     hash(['uint16','address','bytes32'],[operation,actor,record]),hash(['uint256',stateType],[cid,p.state]),originalKey,hash(['bytes32'],[primary])]);
    if(primary!==Z){clock[4].recordChainTip=hash(['bytes32','uint256','address','address','address','address','bytes32','uint64','uint64','bytes32','bytes32'],[
     id('6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2'),o.chainId,o.registry,o.coordinator,o.archive,o.owners[4],domain(4),sequence,sequence+1n,old.recordChainTip,primary]);sequence++;}
    const at=point(4),cell={commitment:record,touchedRevision:next,kind:1n,status:2n};
    journals[4].push({position:{point:clone(at),nativeIndex:BigInt(journals[4].length-start[4])},receipt:{operation,artistId:Z,collectionId:cid,recordHash:record}});
    aliases[4].push({originHash:oh,ownerIndex:4n,surface,scope,originalKey,cell,admittedAt:clone(at)});
    replayRoot=hash(['bytes32','bytes32','bytes32',cellType],[m.ARTIST_COMPLETE_HISTORY_HYDRATION_CHECKPOINT_SCHEMA,replayRoot,originalKey,cell]);
    const mask=operation===8n?[0,4,6]:[4],snap=child(T.envelope,'before_').arrayChildren;
    const envelope={version:1n,configurationHash:config,operation,actor,value:record,before_:seven(i=>mask.includes(i)?before[i]:zero(snap)),after_:seven(i=>mask.includes(i)?clone(clock[i]):zero(snap)),payload};
    const raw=flat(T.envelope,envelope),pointer=A(2100+archiveRows.length),payloadHash=keccak256(raw);
    const evidenceId=hash(['bytes32','uint256','address','address','uint16','address','bytes32'],[id('6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1'),o.chainId,o.registry,o.coordinator,operation,actor,record]);
    const catalogueIndex=BigInt(archiveRows.length),evidence={catalogueIndex,pointer,payloadHash,evidenceId};
    archiveRows.push({originHash:oh,catalogueIndex,pointer,kind:id('ARTIST_OPERATION_EVIDENCE'),hash:payloadHash,raw,evidenceId,atBlock:5n});
    operations.push({originHash:oh,operation,evidence});args.codes?.set(pointer,'0x00'+raw.slice(2));
    f.platformStages.push({operation,actor,record,scope,point:clone(at),before:priorState,after:clone(p.state),envelope,body});return at;
   }
   {
    const before=clone(p.state),statement=H('Platform declaration'),declaredAt=90n;
    const record=hash(['bytes32','uint256','address','address','uint256','bytes32','uint64'],[id('6529STREAM_PLATFORM_WORKS_DECLARATION_V1'),o.chainId,o.registry,o.core,cid,statement,declaredAt]);
    p.state.declaration={recordHash:record,statementHash:statement,actor:A(80),declaredAt};
    const body={id:cid,statement,roleHash:H('original declaration admin role'),roleRevision:1n};
    p.declarationPoint=platformCommit(8n,A(80),record,'0x'+cid.toString(16).padStart(64,'0'),before,coder.encode(['uint256','bytes32','bytes32','uint64'],Object.values(body)),body);
   }
   {
    const before=clone(p.state),[e,r]=documents('claim',Z),evidence=hash([evidenceType],[e]),reason=hash([evidenceType],[r]),filedAt=91n;
    const record={collectionId:cid,claimant:A(80),proposedArtist:proposer,evidenceHash:evidence,reasonHash:reason,filedAt,recordHash:hash(['bytes32','uint256','address','address','uint256','address','bytes32','bytes32','uint64'],[id('6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1'),o.chainId,o.registry,o.core,cid,A(80),evidence,reason,filedAt])};
    p.state.claimCount=1n;p.state.latestClaim=p.latestDisplayClaim=record.recordHash;
    const body={id:cid,evidence,reason,uri:'urn:complete:platform-claim',e,r,ep:H('claim evidence admission'),rp:H('claim reason admission')};
    const scope=hash(['uint256','address','bytes32','bytes32'],[cid,A(80),evidence,reason]);
    const at=platformCommit(9n,A(80),record.recordHash,scope,before,coder.encode(['uint256','bytes32','bytes32','string',evidenceType,evidenceType,'bytes32','bytes32'],Object.values(body)),body);
    p.claims.push({point:at,record});
   }
   for(const [position,state,correction] of [[0,1n,false],[1,3n,false],[2,3n,true]]) {
    const before=clone(p.state),claim=p.state.latestClaim,[e,r]=documents(`resolution${position}`,claim),evidence=hash([evidenceType],[e]),reason=hash([evidenceType],[r]);
    const c={scopeHash:hash(['bytes32','uint256','address','address','uint256','bool'],[id('6529STREAM_PLATFORM_WORKS_GOVERNANCE_SCOPE_V1'),o.chainId,o.registry,o.core,cid,correction]),oldValueHash:hash([child(stateType,'declaration'),'uint8','bytes32','bytes32',child(stateType,'correction')],[before.declaration,before.contestState,before.contestClaim,before.contestRecord,before.correction]),newValueHash:Z};
    c.newValueHash=hash(['bytes32','bytes32','uint8','bytes32','bytes32','bytes32'],[c.scopeHash,c.oldValueHash,state,claim,evidence,reason]);
    const g={actionId:H(`Platform original action${position}`),proposer:A(84),actionClass:correction?2n:1n,roleMutationHash:H(`Platform original proposer role${position}`),roleRevision:BigInt(position+1),...c};
    let record;
    if(correction){
     record={collectionId:cid,proposedArtist:proposer,claimRecordHash:claim,sustainedContestRecordHash:before.contestRecord,evidenceHash:evidence,reasonHash:reason,approvalActionId:g.actionId,approvedAt:94n,correctiveGeneration:0n,accepted:false,recordHash:Z};
     record.recordHash=hash(['bytes32','uint256','address','address','uint256','bytes32','bytes32','bytes32','bytes32','bytes32','uint64'],[id('6529STREAM_PLATFORM_WORKS_CORRECTION_RECORD_V1'),o.chainId,o.registry,o.core,cid,before.contestRecord,claim,evidence,reason,g.actionId,record.approvedAt]);
     p.state.correction=record;p.status.originalCorrectionRecord=record.recordHash;
    }else{
     record={collectionId:cid,adjudicatedArtist:proposer,state,claimRecordHash:claim,evidenceHash:evidence,reasonHash:reason,actionId:g.actionId,previousRecordHash:before.contestRecord,changedAt:92n+BigInt(position),recordHash:Z};
     record.recordHash=hash(['bytes32','uint256','address',contestType],[id('6529STREAM_PLATFORM_WORKS_CONTEST_TRANSITION_V1'),o.chainId,o.owners[4],record]);
     p.state.contestState=state;p.state.contestClaim=claim;p.state.contestRecord=record.recordHash;
    }
    const body={id:cid,state,claim,evidence,reason,correction,c,g,e,r,ep:H(`resolution${position} evidence admission`),rp:H(`resolution${position} reason admission`)};
    const at=platformCommit(correction?53n:11n,governor,record.recordHash,hash(['uint256','bytes32'],[cid,g.actionId]),before,coder.encode(['uint256','uint8','bytes32','bytes32','bytes32','bool',contextType,governanceType,evidenceType,evidenceType,'bytes32','bytes32'],Object.values(body)),body);
    if(correction)p.correctionPoint=at;else p.contests.push({point:at,record});
   }
   f.platformReplayRoot=replayRoot;
  }
  // The original cutover is explicit documentary input; no fabricated native row.
  clock[2].revision++;
  const entry={surface:id('identity_authority.replay.one_way_cutover_latch'),scope:Z};aliases[2].push({originHash:oh,ownerIndex:2n,...entry,originalKey:m.artistCompleteHistoryHydrationReplayKey(o,2,entry),cell:{kind:1n,status:2n,commitment:H(`cutover${era}`),touchedRevision:clock[2].revision},admittedAt:point(2)});
  const checkpoints=seven(i=>({schema:m.ARTIST_COMPLETE_HISTORY_HYDRATION_CHECKPOINT_SCHEMA,ownerState:clone(clock[i]),replayRoot:aliases[i].some(a=>a.originHash===oh)?H(`replay${era}/${i}`):Z,replayCount:BigInt(aliases[i].filter(a=>a.originHash===oh).length),nonceRoot:Z,nonceIndexCount:0n}));
  if(platform)checkpoints[4].replayRoot=f.platformReplayRoot;
  eras.push({originHash:oh,priorImportCommitment:era?H(`import${era}`):Z,checkpoints,nativeCounts:journals.map((r,i)=>BigInt(r.length-start[i])),lowerRevisions:lower});
 }
 f.provenance={origins,eras,journals,aliases};f.before=args.before??seven(i=>({domainId:domain(i),revision:i===2?1n+BigInt(artists.length+collections.length):0n,stateRoot:H(`before${i}`),recordChainTip:H(`beforetip${i}`)}));
 f.features=33554432n|(historical?3n|32n|256n|512n|4096n:65536n)|(repeated?16n:0n);return refresh(f);
}
export function refresh(f) {
 const p=f.provenance,last=p.eras.at(-1),cp=last.checkpoints;
 for(const rows of p.aliases)rows.sort((a,b)=>BigInt(a.originalKey)<BigInt(b.originalKey)?-1:1);
 for(const a of f.artists)a.records=p.journals.flat().filter(j=>j.receipt.artistId===a.artistId).map(j=>j.receipt.recordHash);
 for(const q of f.collections)q.records=p.journals.flat().filter(j=>j.receipt.collectionId===q.collectionId).map(j=>j.receipt.recordHash);
 f.common.provenance=clone(p);f.common.archive.operations=clone(f.operations);
 f.common.archive.catalogues=p.origins.map((o,i)=>{const rows=f.archiveRows.filter(r=>r.originHash===p.eras[i].originHash),c={originHash:p.eras[i].originHash,archiveCodeHash:f.codes?.has(o.archive)?keccak256(f.codes.get(o.archive)):H(`archive${i}`),configurationHash:f.configs[i],count:BigInt(rows.length),rowsHash:Z,lower:clone(p.eras[i].lowerRevisions),upper:p.eras[i].checkpoints.map(c=>c.ownerState.revision)};c.rowsHash=hash(['bytes32','bytes32','address','bytes32','bytes32','uint256'],[id('6529STREAM_ARTIST_RECOVERED_PLATFORM_CATALOGUE_V1'),c.originHash,o.archive,c.archiveCodeHash,c.configurationHash,c.count]);for(const r of rows)c.rowsHash=hash(['bytes32','uint256','address','bytes32','bytes32'],[c.rowsHash,r.catalogueIndex,r.pointer,r.kind,r.hash]);return c;});
 const locals=seven(i=>m.artistCompleteHistoryHydrationOwnerProvenance(p,i)),commitments=locals.map((v,i)=>m.artistCompleteHistoryHydrationOwnerProvenanceHash(v,i));
 for(let k=0;k<f.collections.length;k++){
  const q=f.collections[k],b=f.bindings[k];Object.assign(b.bindings,{artistId:q.artistId,collectionId:q.collectionId,bindingHash:q.bindingHash,provenanceCommitment:commitments[0]});
  Object.assign(f.acceptances[k],{provenance:commitments[3],artistId:q.artistId,collectionId:q.collectionId,bindingHash:q.bindingHash});Object.assign(f.platforms[k],{provenance:commitments[4],collectionId:q.collectionId});
  const a=f.attribution[k];for(const row of[a.history,a.records])Object.assign(row,{provenance:commitments[4],artistId:q.artistId,collectionId:q.collectionId,bindingHash:q.bindingHash});
  a.history.current={state:q.artistId===Z?0n:1n,generation:b.bindings.current.generation};a.records.item=clone(a.history.current);a.history.generations=clone(f.common.bindings.generations[k]);a.history.heads=b.bindings.rows.map(()=>zero(child(findType('StreamArtistRecoveredDisputeHistoryTypes.Bundle'),'heads').arrayChildren));
  Object.assign(f.supplements[k].original.rows.original,{provenance:commitments[6],artistId:q.artistId,collectionId:q.collectionId,bindingHash:q.bindingHash});
 }
 for(const b of f.identities)b.sourceSnapshot=clone(cp[2].ownerState);for(const b of f.payouts)b.sourceSnapshot=clone(cp[5].ownerState);
 f.features=m.artistCompleteHistoryHydrationRequiredFeatures(f.identities,f.payouts,f.common,f.attribution,f.supplements);
 const auxiliary=coder.encode([T.inventory],[f.common]),logical=p.aliases.map(r=>r.filter(a=>a.originHash===last.originHash).map(({surface,scope})=>({surface,scope})));
 const data=seven(owner=>{let rows=[];if(owner===0)rows=f.bindings.map(v=>coder.encode([T.binding],[v]));if(owner===2)rows=f.identities.map(v=>coder.encode([T.identity],[v]));if(owner===3)rows=f.acceptances.map(v=>coder.encode([T.acceptance],[v]));if(owner===4)rows=f.attribution.map(v=>coder.encode([T.attribution],[v]));if(owner===5)rows=f.payouts.map(v=>coder.encode(['bytes32',T.payout],[id('6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1'),v]));if(owner===6)rows=f.supplements.map(v=>coder.encode([T.consents],[v.original]));
  const state={artists:clone(f.artists),collections:clone(f.collections),rows};f.states[owner]=state;
  const publications=f.codes&&[2,4,6].includes(owner)?[{pointer:A(90+owner),payloadType:H(`publication${owner}`),payloadHash:keccak256('0x1234')}]:[];if(publications.length)f.codes.set(publications[0].pointer,'0x001234');
  const payload={provenance:locals[owner],nonces:owner===2?clone(f.nonces):[],publications,semanticState:coder.encode(['bytes32','uint16','uint8',T.state,'bytes'],[m.ARTIST_COMPLETE_HISTORY_HYDRATION_SCHEMA,1n,BigInt(owner),state,auxiliary])};f.payloads[owner]=payload;
  const keys=logical[owner].map(v=>m.artistCompleteHistoryHydrationReplayKey(f.origin,owner,v));return{typedState:m.encodeArtistCompleteHistoryHydrationOwnerPayload(payload,owner,f.features),origins:logical[owner],sourceKeys:keys,cells:keys.map(key=>p.aliases[owner].find(a=>a.originalKey===key).cell),nonces:[]};
 });
 const first=f.collections[0],query={...clone(first),records:clone(first.artistId===Z?first.records:f.artists.find(a=>a.artistId===first.artistId).records)};
 f.prepared=f.certificate={admission:{prior:f.origin.registry,sourceCoordinator:f.origin.coordinator,source:f.source,provenance:p,artists:f.artists,collections:f.collections,before_:f.before},query,data,timing:f.timing,externalGuards:{schema:id(f.artists.length?'6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1':'6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1'),provenanceCommitment:m.artistCompleteHistoryHydrationProvenanceHash(p),artistId:f.artists[0]?.artistId??Z,actions:[],finality:[],entropy:[]}};
 const witnesses=f.supplements.flatMap(s=>s.original.rows.original.economics.length?[{collectionId:s.original.rows.original.collectionId,economics:s.original.rows.original.economics.map(r=>r.item.terms),attestations:[]}]:[]);
 f.request={records:{authority:{bindingIndex:0n,artistIds:f.artists.map(a=>a.artistId),collections:f.collections.map(q=>({artistId:q.artistId,collectionId:q.collectionId,policies:q.policies})),expectedSource:cp,replayOrigins:logical},witnesses},expectedCapabilities:seven(i=>({profile:m.ARTIST_COMPLETE_HISTORY_HYDRATION_PROFILE,version:1n,ownerIndex:BigInt(i),ownerDomain:domain(i),checkpointSchema:m.ARTIST_COMPLETE_HISTORY_HYDRATION_CHECKPOINT_SCHEMA,stateSchema:m.artistCompleteHistoryHydrationOwnerTag(i),supportedFeatures:67108863n})),expectedSourceImportCommitment:last.priorImportCommitment,expectedSemanticInventory:Z};
 f.request.expectedSemanticInventory=hash(['bytes32','uint16','bytes32',child(T.prepared,'query'),child(T.prepared,'data'),child(T.prepared,'timing'),child(T.prepared,'externalGuards')],[id('6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1'),1n,m.artistCompleteHistoryHydrationProvenanceHash(p),query,data,f.timing,f.prepared.externalGuards]);f.input={request:f.request,royaltyFreezes:f.supplements.flatMap(s=>s.original.rows.royalties.map(r=>r.terms))};f.contents=f.supplements.map(s=>s.original.rows);return f;
}
