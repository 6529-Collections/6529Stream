// Compiler-encoded RPC consistency mock for the unbound Platform graph.
// Original signatures, private admission and native hydration are not executed here.
import assert from 'node:assert/strict';
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as rh from '../dist/current-artist-unbound-platform-hydration.js';
import * as workflow from '../dist/current-artist-unbound-platform-hydration-workflow.js';
import { ARTIST_HYDRATION_SUITE_TUPLE } from '../dist/current-artist-authority-hydration.js';
import { fixture, compiledABI, compiledLibraryEvents, compiledLibraryValueInterface, libraryValueABI } from './current-artist-unbound-platform-hydration-source-fixture.mjs';
export { rh, workflow, fixture };
export const coder=AbiCoder.defaultAbiCoder(), A=n=>getAddress(`0x${BigInt(n).toString(16).padStart(40,'0')}`), H=v=>id(String(v));
export const hash=(types,values)=>keccak256(coder.encode(types,values));
const domains=Array.from({length:7},(_,i)=>rh.artistUnboundPlatformHydrationOwnerDomain(i));
const ordinary=['registry','coordinator','archive','owner','identity','checkpoint','recoveredOwner','chronology','history','nativeReceipts','reconstruction','timing','core','governanceFacts','finalityRecovery','finalityBinding','entropyUnavailability','entropyFreshRecovery','hydrationOwner','hydrationCoordinator','recoveredCoordinator'];
export const abi=new Interface(ordinary.flatMap(name=>compiledABI(name)).filter(row=>row.type!=='constructor').concat(compiledLibraryEvents('commit').fragments));
// Concrete compiler ABIs are immutable fixture inputs; parse each target alias once.
const targetInterfaces=new Map(['binding','collaborator','identity','acceptance','attribution','payout','consent','registry','archive','coordinator','core'].map(name=>[name,new Interface(compiledABI(name))]));
export const preparedAbi=compiledLibraryValueInterface('prepared');
const prepare2='0x'+fixture.libraryMethodIdentifiers.StreamArtistRecoveredHydrationPrepared['prepare(StreamArtistOnboardingTypes.SuiteConfiguration,StreamArtistRecoveredHydrationTypes.Request)'];
export const safeABI=new Interface(['function nonce() view returns(uint256)','function getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256) view returns(bytes32)','function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) payable returns(bool)','event ExecutionSuccess(bytes32 txHash,uint256 payment)','event ExecutionFailure(bytes32 txHash,uint256 payment)']);
const indexedSafe=new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)','event ExecutionFailure(bytes32 indexed txHash,uint256 payment)']);
const safeTypes={SafeTx:['to:address','value:uint256','data:bytes','operation:uint8','safeTxGas:uint256','baseGas:uint256','gasPrice:uint256','gasToken:address','refundReceiver:address','nonce:uint256'].map(s=>{const[name,type]=s.split(':');return{name,type};})};
export const safeHash=(chainId,address,values)=>TypedDataEncoder.hash({chainId,verifyingContract:address},safeTypes,Object.fromEntries(safeTypes.SafeTx.map((f,i)=>[f.name,values[i]])));
const zeroCell=()=>({commitment:ZeroHash,touchedRevision:0n,kind:0n,status:0n});
export function zeroValue(value){const p=typeof value==='string'?ParamType.from(value):value;if(p.baseType==='tuple')return Object.fromEntries(p.components.map(f=>[f.name,zeroValue(f)]));if(p.baseType==='array')return Array.from({length:Math.max(0,p.arrayLength)},()=>zeroValue(p.arrayChildren));if(p.type==='address')return ZeroAddress;if(p.type==='bool')return false;if(p.type==='string')return '';if(p.type==='bytes')return '0x';if(p.type.startsWith('bytes'))return `0x${'00'.repeat(Number(p.type.slice(5)))}`;return 0n;}

import { semanticFixture } from './current-artist-unbound-platform-hydration-semantic-fixture.mjs';

// Known selected subjects only. No invented zero Artist or wildcard getter response.
function collectionRead(material,method,args,fragment) {
  const queries=material.certificate.admission.collections;
  if(['acceptedAt','acceptanceRecord'].includes(method)&&args[0]===ZeroHash&&queries.some(q=>q.artistId===ZeroHash))return[method==='acceptedAt'?0n:ZeroHash];
  for(let i=0;i<queries.length;i++) {
    const q=queries[i],cid=q.collectionId;
    if(q.artistId===ZeroHash) {
      const p=material.platforms.find(p=>p.collectionId===cid);
      if(method==='binding'&&cid===args[0])return[zeroValue(fragment.outputs[0])];
      if(method==='attributionState'&&cid===args[0])return[0n,0n];
      if(method==='platformWorksState'&&cid===args[0])return[p.state];
      if(method==='platformCorrectionStatus'&&cid===args[0])return[p.status];
      if(['attributionClaims','staticAttributionClaims'].includes(method)&&cid===args[0])return[BigInt(p.claims.length)+p.allegationCount,p.latestDisplayClaim];
      const rows=method==='platformWorksClaimRecord'?p.claims:method==='platformWorksContestRecord'?p.contests:method==='attributionClaimRecord'?p.allegations:[];
      const row=rows.find(r=>r.record.recordHash===args[0]);if(row)return[row.record];
      continue;
    }
    const b=material.bindingRows[i],a=material.acceptanceRows[i],s=material.attributionRows[i],policy=material.policyRows[i];
    if(method==='binding'&&cid===args[0])return[b.item];
    if(['bindingAt','bindingTerms','bindingTermination'].includes(method)&&cid===args[0]&&args[1]===1n)return[method==='bindingAt'?b.history:method==='bindingTerms'?b.terms:b.terminal];
    if(args[0]===q.bindingHash&&method==='acceptedAt')return[a.acceptedAt];
    if(args[0]===q.bindingHash&&method==='acceptanceRecord')return[a.record];
    if(method==='attributionState'&&cid===args[0])return[s.state.item.state,s.state.item.generation];
    if(method==='platformWorksState'&&cid===args[0])return[zeroValue(fragment.outputs[0])];
    if(method==='policyRecord'&&cid===args[0]){const k=policy.policies.findIndex(v=>v.phaseId===args[1]&&v.policyHash===args[2]);if(k>=0)return[policy.records[k]];}
    if(method==='recordDelegation'&&policy.records.includes(args[0]))return[ZeroHash];
  }
  throw Error(`Unknown retained unbound/mixed collection row: ${method}`);
}

export function setup(options={}) {
  const codes=new Map(), pin=n=>{const address=A(n),code=`0x61${BigInt(n).toString(16).padStart(4,'0')}6000`;codes.set(address,code);return{address,codeHash:keccak256(code)};};
  const common=Array.from({length:7},(_,i)=>pin(50+i)),sourcePins=Array.from({length:9},(_,i)=>pin(10+i)).concat(common),destinationPins=Array.from({length:9},(_,i)=>pin(30+i)).concat(common);
  const deployment={chainId:1n,source:{registry:sourcePins[7],coordinator:pin(70),components:sourcePins},destination:{registry:destinationPins[7],coordinator:pin(71),components:destinationPins},preparationLibrary:pin(72),preparationDependencies:[pin(73)]};
  const caller=A(80);const safePin=pin(80);
  const suite=p=>({owners:p.slice(0,7).map(v=>v.address),registry:p[7].address,archive:p[8].address,core:p[9].address,mintManager:p[10].address,roleRegistry:p[11].address,metadata:p[12].address,primaryResolver:p[13].address,royaltyResolver:p[14].address,validator:p[15].address,primaryRevenueClass:H('PRIMARY_SALE')});
  const source=suite(sourcePins),destination=suite(destinationPins),origin={chainId:1n,registry:source.registry,coordinator:deployment.source.coordinator.address,archive:source.archive,owners:source.owners,ownerCodeHashes:sourcePins.slice(0,7).map(v=>v.codeHash),core:source.core,manager:source.mintManager,suiteConfigurationHash:hash([ARTIST_HYDRATION_SUITE_TUPLE],[source])};
  const material=semanticFixture({source,destination,origin,options,codes});
  const before=structuredClone(material.certificate.admission.before_);
  // The mutable caller request and producer-response negative controls do not
  // mutate the separate original getter DTOs created by the semantic fixture.
  const certificate=structuredClone(material.certificate),request=structuredClone(material.request),input=structuredClone(material.input);
  const provenance=certificate.admission.provenance,checkpoints=provenance.eras.at(-1).checkpoints,journals=provenance.journals;
  const semanticRows=i=>rh.decodeArtistUnboundPlatformHydrationState(material.payloads[i].semanticState,i,material.payloads[i].provenance).rows;
  const queries=certificate.admission.collections;
  const mixed=(owner,decode)=>semanticRows(owner).map((raw,i)=>queries[i].artistId===ZeroHash?null:decode(raw));
  material.bindingRows=mixed(0,rh.decodeArtistUnboundPlatformHydrationBinding);
  material.acceptanceRows=mixed(3,rh.decodeArtistUnboundPlatformHydrationAcceptance);
  material.attributionRows=mixed(4,rh.decodeArtistUnboundPlatformHydrationAttributionRow);
  material.policyRows=mixed(6,rh.decodeArtistUnboundPlatformHydrationPolicyBundle);
  material.platforms=semanticRows(4).flatMap((raw,i)=>queries[i].artistId===ZeroHash?[rh.decodeArtistUnboundPlatformHydrationPlatform(raw)]:[]);
  material.clocks=material.platforms[0];

  // Independent retained source DTOs are constructor facts, not a decoder cache.
  // state.certificate is the mutable producer response used by negative tests.
  const ownerPayload = i => material.payloads[i];
  const sourceCatalogs=new Map([2,4,6].map(i=>[source.owners[i],ownerPayload(i).publications]));
  const originSuites=provenance.origins.map(o=>({...source,registry:o.registry,archive:o.archive,owners:o.owners,core:o.core,mintManager:o.manager}));
  const eraForHost=host=>provenance.origins.findIndex(o=>[...o.owners,o.registry,o.archive,o.coordinator].includes(host));
  const rowOrigin=row=>row.originHash??(provenance.origins.length===1?provenance.eras[0].originHash:null);
  if(material.archiveRows.some(row=>rowOrigin(row)===null))throw Error('Repeated fixture requires explicit original Archive row origin');
  for(let i=0;i<provenance.origins.length;i++)sourceCatalogs.set(provenance.origins[i].archive,material.archiveRows.filter(row=>rowOrigin(row)===provenance.eras[i].originHash).map(row=>({pointer:row.pointer,payloadType:row.kind,payloadHash:row.hash})));
  const state={codes,hooks:[],calls:[],mined:false,captured:null,catalogs:new Map(),metadata:new Map(),evidence:new Map(),
    beforeCatalogs:new Map([destination.owners[2],destination.owners[4],destination.owners[6],destination.archive].map(host=>[host,[]])),
    capabilities:request.expectedCapabilities,certificate,tx:null,receipt:null,safeNonce:4n,safeEndingNonce:5n,transactionHook:null,blockOverride:null,sourceCatalogs};
  const sourceHosts=provenance.origins.flatMap(o=>[...o.owners,o.registry,o.archive,o.coordinator]);
  const provider={
    async getNetwork(){return{chainId:1n};},
    async getBlock(tag){return state.blockOverride?.(tag)??{number:tag,timestamp:100+tag,hash:H(`block${tag}`)};},
    async getCode(host,tag){for(const hook of state.hooks){const r=hook({method:'getCode',host:getAddress(host),tag});if(r!==undefined)return r;}return codes.get(getAddress(host))??'0x';},
    async call(tx){
      const host=getAddress(tx.to),tag=tx.blockTag;let fragment,args,selectedAbi=abi;
      if(host===caller){selectedAbi=safeABI;fragment=safeABI.getFunction(tx.data.slice(0,10));args=safeABI.decodeFunctionData(fragment,tx.data);}
      else if(tx.data.slice(0,10)===prepare2){
        assert.equal(host,deployment.preparationLibrary.address);selectedAbi=preparedAbi;fragment=preparedAbi.fragments.find(f=>f.type==='function'&&f.name==='prepare'&&f.inputs.length===2);args=preparedAbi.decodeFunctionData(fragment,`${fragment.selector}${tx.data.slice(10)}`);
      }else{
        const ownerNames=['binding','collaborator','identity','acceptance','attribution','payout','consent'];
        const originalEra=eraForHost(host),original=originalEra<0?null:provenance.origins[originalEra];
        const ownerIndex=original?original.owners.indexOf(host):destination.owners.indexOf(host);
        const name=ownerIndex>=0?ownerNames[ownerIndex]:[original?.registry,destination.registry].includes(host)?'registry':
          [original?.archive,destination.archive].includes(host)?'archive':[original?.coordinator,deployment.destination.coordinator.address].includes(host)?'coordinator':host===source.core?'core':null;
        if(!name)throw Error('Unknown fixture target');
        const targetABI=targetInterfaces.get(name);fragment=targetABI.getFunction(tx.data.slice(0,10));
        if(!fragment)throw Error('Unsupported target getter');selectedAbi=targetABI;args=targetABI.decodeFunctionData(fragment,tx.data);
      }
      const method=fragment.name,encode=values=>selectedAbi.encodeFunctionResult(fragment,values);state.calls.push({method,host,tag,args,from:tx.from,value:tx.value,gasLimit:tx.gasLimit});
      for(const hook of state.hooks){const result=hook({method,host,tag,args,fragment,tx});if(result!==undefined)return typeof result==='string'?result:encode(result);}
      if(host===caller){if(method==='nonce')return encode([tag>=12?state.safeEndingNonce:state.safeNonce]);if(method==='getTransactionHash')return encode([safeHash(1n,caller,Array.from(args))]);throw Error('Unexpected Safe fixture call');}
      const isSource=sourceHosts.includes(host),era=isSource?eraForHost(host):-1,original=isSource?provenance.origins[era]:null;
      const selected=isSource?originSuites[era]:destination,owner=selected.owners.indexOf(host),post=state.mined&&tag>=12&&!isSource;
      const payload=owner>=0?ownerPayload(owner):null;
      switch(method){
        case 'binding':case 'bindingAt':case 'bindingTerms':case 'bindingTermination':
          assert.equal(owner,0);return encode(collectionRead(material,method,args,fragment));
        case 'acceptedAt':case 'acceptanceRecord':
          assert.equal(owner,3);return encode(collectionRead(material,method,args,fragment));
        case 'attributionState':case 'platformWorksState':case 'platformWorksClaimRecord':case 'platformWorksContestRecord':
        case 'attributionClaimRecord':case 'platformCorrectionStatus':case 'attributionClaims':case 'staticAttributionClaims':
          assert.equal(owner,4);return encode(collectionRead(material,method,args,fragment));
        case 'policyRecord':case 'recordDelegation':
          assert.equal(owner,6);return encode(collectionRead(material,method,args,fragment));
        case 'prepare':assert.equal(tx.value,0n);return encode([state.certificate]);
        case 'hydrateRecoveredArtistAuthority':assert.equal(host,destination.registry);assert.equal(tx.value,0n);return encode([state.captured.commitment]);
        case 'authorityHydrationSuite':return encode([selected]);
        case 'deploymentChainId':return encode([1n]);
        case 'core':return encode([selected.core]);
        case 'mintManager':return encode([selected.mintManager]);
        case 'artistRegistry':return encode([selected.registry]);
        case 'operationCoordinator':return encode([isSource?original.coordinator:deployment.destination.coordinator.address]);
        case 'archiveV2':return encode([selected.archive]);
        case 'domainId':return encode([domains[owner]]);
        case 'configurationHash':return encode([isSource?material.clocks.catalogues[era].configurationHash:H('destination configuration')]);
        case 'gasParameterInfo':return encode([1000000n,1n,2n,1n]);
        case 'getSatellitePointer':return encode([destination.registry,deployment.destination.registry.codeHash,true,H('ARTIST_REGISTRY'),'0x00000000',A(3),1n,H('deploy'),H('module'),1n]);
        case 'artistRegistryCutover':return encode(isSource?[true,destination.registry,90n]:[false,ZeroAddress,0n]);
        case 'importedHistoryBindingCount':return encode([1n]);
        case 'importedHistoryBinding':return encode([source.registry,1n,H('history'),H('binding')]);
        case 'artistHistoryPredecessorBinding':return encode([true,deployment.source.registry.codeHash,90n]);
        case 'importedLaneVerified':case 'artistHistoryLane':{
          const q=args[0]===1n?certificate.admission.artists.find(v=>v.artistId===args[1]):certificate.admission.collections.find(v=>v.collectionId===BigInt(args[1]));if(!q)throw Error('Unknown fixture lane');
          const value=[H(`lane${args[0]}:${args[1]}`),BigInt(q.records.length)];return encode(method==='importedLaneVerified'?[true,...value]:value);
        }
        case 'ownerStateSnapshotV2':return encode([isSource?provenance.eras[era].checkpoints[owner].ownerState:post?state.captured.after[owner]:before[owner]]);
        case 'authorityCheckpoint':return encode([isSource?provenance.eras[era].checkpoints[owner]:{schema:rh.ARTIST_UNBOUND_PLATFORM_HYDRATION_CHECKPOINT_SCHEMA,ownerState:post?state.captured.after[owner]:before[owner],replayCount:owner===2?2n+2n*BigInt(certificate.admission.artists.length+certificate.admission.collections.length):0n,replayRoot:H(`destination replay${owner}`),nonceIndexCount:post?BigInt(payload.nonces.length):0n,nonceRoot:H(`destination nonce${owner}`)}]);
        case 'nextRegistrationNonce':return encode([isSource||post?BigInt(certificate.admission.artists.length):0n]);
        case 'recoveredAuthorityHydrationCapability':return encode([state.capabilities[owner]]);
        case 'authorityHydrationCommitment':return encode([isSource?provenance.eras[era].priorImportCommitment:post?state.captured.commitment:ZeroHash]);
        case 'recoveredHydrationImportedPrefix': {
          if(post)return encode([payload.provenance,state.captured.commitment,state.captured.after[owner].revision]);
          if(!isSource)return encode([{origins:[],eras:[],journal:[],aliases:[]},ZeroHash,0n]);
          const prefix={origins:payload.provenance.origins.slice(0,era),eras:payload.provenance.eras.slice(0,era),journal:payload.provenance.journal.filter(row=>payload.provenance.eras.findIndex(e=>e.originHash===row.position.point.environmentHash)<era),aliases:payload.provenance.aliases.filter(row=>payload.provenance.eras.findIndex(e=>e.originHash===row.originHash)<era)};
          return encode([prefix,provenance.eras[era].priorImportCommitment,provenance.eras[era].lowerRevisions[owner]]);
        }
        case 'artistNativeReceiptCount':return encode([isSource?provenance.eras[era].nativeCounts[owner]:0n]);
        case 'artistNativeReceiptAt':case 'artistNativeReceiptRevisionAt':{
          assert(isSource);const row=journals[owner].find(r=>r.position.point.environmentHash===provenance.eras[era].originHash&&r.position.nativeIndex===args[0]);
          if(!row)throw Error('Unknown original native receipt');return encode([method==='artistNativeReceiptAt'?row.receipt:row.position.point.ownerRevision]);
        }
        case 'authorityReplayAt':return encode([certificate.data[owner].sourceKeys[Number(args[0])],certificate.data[owner].cells[Number(args[0])]]);
        case 'replayCell':{
          const data=certificate.data[owner];if(isSource)return encode([data.cells[data.sourceKeys.indexOf(args[0])]]);
          const target={...origin,registry:destination.registry,coordinator:deployment.destination.coordinator.address,archive:destination.archive,owners:destination.owners,ownerCodeHashes:destinationPins.slice(0,7).map(v=>v.codeHash),suiteConfigurationHash:hash([ARTIST_HYDRATION_SUITE_TUPLE],[destination])};
          const index=data.origins.findIndex(v=>rh.artistUnboundPlatformHydrationReplayKey(target,owner,v)===args[0]);
          if(index<0)return encode([zeroCell()]);const name=data.origins[index].surface;
          if(name===H('identity_authority.replay.one_way_cutover_latch'))return encode([zeroCell()]);
          if(owner===2&&['verified_lane_key','import_binding'].some(n=>name===H(`identity_authority.replay.${n}`)))return encode([{commitment:H(`destination guard${index}`),touchedRevision:before[2].revision,kind:1n,status:2n}]);
          return encode([post?data.cells[index]:zeroCell()]);
        }
        case 'recoveredHydrationReplayPoint':return encode([payload.provenance.aliases.find(v=>v.originalKey===args[0]).admittedAt]);
        case 'authorityNonceIndexAt':return encode([payload.nonces[Number(args[0])].index]);
        case 'authorityNonceWordAt':{const row=payload.nonces.find(v=>v.index.kind===args[0]&&v.index.key===args[1]).words[Number(args[2])];return encode([row.prefix,row.words,row.exhausted]);}
        case 'recoveredTimingCheckpoint':return encode([certificate.timing]);
        case 'recoveredTimingEntryAt':throw Error('No timing mutations in compact fixture');
        case 'artistArchiveMaxEvidenceBytesV2':return encode([24575n]);
        case 'artistArchiveMarkerV2':return encode([H('6529STREAM_ARTIST_ARCHIVE_V2')]);
        case 'artistArchiveSchemaV2':return encode([2n]);
        case 'artistArchiveBindingHashV2': {
          const own=compiledABI('IStreamArtistArchiveV2').filter(f=>f.type==='function'&&f.name!=='supportsInterface'),iface=new Interface(own);
          const interfaceId=`0x${own.reduce((x,f)=>x^BigInt(iface.getFunction(f.name).selector),0n).toString(16).padStart(8,'0')}`;
          return encode([hash(['bytes32','uint256','address','address','bytes4','bytes32','uint16','uint256'],[H('6529STREAM_ARTIST_ARCHIVE_BINDING_V2'),1n,selected.registry,isSource?original.coordinator:deployment.destination.coordinator.address,interfaceId,H('6529STREAM_ARTIST_ARCHIVE_V2'),2n,24575n])]);
        }
        case 'storedPayloadCount':return encode([BigInt((isSource?sourceCatalogs.get(host):post?state.catalogs.get(host):state.beforeCatalogs.get(host))?.length??0)]);
        case 'storedPayloadAt':{const row=(isSource?sourceCatalogs.get(host):post?state.catalogs.get(host):state.beforeCatalogs.get(host))[Number(args[0])];return encode([row.pointer,row.payloadType,row.payloadHash]);}
        case 'artistEvidenceMetadataV2': {assert.equal(args[1],1n);if(isSource){const row=material.archiveRows.find(r=>r.evidenceId===args[0]&&rowOrigin(r)===provenance.eras[era].originHash);if(!row)throw Error('Unknown original Archive evidence');return encode([row.hash,row.pointer,BigInt((row.raw.length-2)/2),row.atBlock]);}return encode(state.metadata.get(args[0]));}
        case 'artistEvidenceBytesV2': {assert.equal(args[1],1n);if(isSource){const row=material.archiveRows.find(r=>r.evidenceId===args[0]&&rowOrigin(r)===provenance.eras[era].originHash);if(!row)throw Error('Unknown original Archive evidence');return encode([row.raw]);}return encode([state.evidence.get(args[0])]);}
        default:throw Error(`Unexpected original mock method ${method}`);
      }
    },
    async getTransaction(hash){if(state.transactionHook)state.transactionHook(hash);return state.tx;},async getTransactionReceipt(){return state.receipt;}
  };
  return{...material,provider,deployment,input,request,certificate,state,source,destination,origin,before,caller,safePin};
}
export async function capture(s){const c=await workflow.captureArtistUnboundPlatformHydration(s.provider,s.deployment,s.caller,s.input,{blockTag:10,gasLimit:10000000n});s.state.captured=c;return c;}
export function install(s,c,mode='direct'){
  s.state.mined=true;s.state.catalogs=structuredClone(s.state.beforeCatalogs);const logs=[];
  const emit=(address,name,values,iface=abi)=>{const e=iface.encodeEventLog(iface.getEvent(name),values);logs.push({address,...e,index:logs.length,blockNumber:12,blockHash:H('block12'),transactionHash:H('tx'),removed:false});};
  const store=(host,row)=>{const list=s.state.catalogs.get(host)??[];if(list.some(v=>v.payloadType===row.payloadType&&v.payloadHash===row.payloadHash))return;emit(host,'ArtistStoredPayload',[1n,BigInt(list.length),row.payloadType,row.payloadHash,row.pointer]);list.push(row);s.state.catalogs.set(host,list);};
  for(const i of [2,4,6])for(const row of c.owners[i].payload.publications)store(s.destination.owners[i],row);
  const append=(evidenceId,payload,index)=>{const pointer=A(200+index),contentHash=keccak256(payload),size=BigInt((payload.length-2)/2);s.state.codes.set(pointer,`0x00${payload.slice(2)}`);s.state.evidence.set(evidenceId,payload);s.state.metadata.set(evidenceId,[contentHash,pointer,size,12n]);store(s.destination.archive,{pointer,payloadType:H('ARTIST_OPERATION_EVIDENCE'),payloadHash:contentHash});emit(s.destination.archive,'ArtistArchiveEvidenceAppendedV2',[evidenceId,1n,contentHash,pointer,size]);};
  const coordinates={chainId:1n,registry:s.destination.registry,coordinator:s.deployment.destination.coordinator.address};
  for(let i=0;i<c.descriptor.pageHashes.length;i++)append(rh.artistUnboundPlatformHydrationPageId(coordinates,c.commitment,c.descriptor,BigInt(i)),`0x${c.profileEvidence.slice(2+i*40960,2+(i+1)*40960)}`,i);
  append(c.evidenceId,c.operationEvidence,c.descriptor.pageHashes.length);emit(s.deployment.destination.coordinator.address,'RecoveredArtistAuthorityHydrated',[1n,s.source.registry,c.commitment,c.prepared.request.expectedSemanticInventory,c.descriptor.payloadHash]);
  for(const i of [2,4,6])for(const row of c.owners[i].payload.publications)store(s.destination.archive,row);
  s.state.tx={hash:H('tx'),from:c.prepared.caller,to:c.prepared.registry,data:c.prepared.call.data,value:0n,chainId:1n,blockNumber:12,blockHash:H('block12')};let receiptOptions={execution:'direct'};
  if(mode!=='direct'){
    const values=[c.prepared.registry,0n,c.prepared.call.data,0n,1000000n,0n,0n,ZeroAddress,ZeroAddress,s.state.safeNonce],expectedSafeTxHash=safeHash(1n,c.prepared.caller,values);
    s.state.tx.from=A(81);s.state.tx.to=c.prepared.caller;s.state.tx.data=safeABI.encodeFunctionData('execTransaction',[...values.slice(0,9),'0x1234']);emit(c.prepared.caller,'ExecutionSuccess',[expectedSafeTxHash,0n],mode==='indexed'?indexedSafe:safeABI);
    receiptOptions={execution:'safe',expectedSafeTxHash,nonce:s.state.safeNonce,safeCodeHash:s.safePin.codeHash};
  }
  s.state.receipt={...s.state.tx,status:1,logs};return{logs,emit,options:receiptOptions};
}
export const run=(s,c,mined)=>workflow.reconcileArtistUnboundPlatformHydrationReceipt(s.provider,c,H('tx'),mined.options);
export const renumber=logs=>logs.forEach((log,index)=>{log.index=index;});
