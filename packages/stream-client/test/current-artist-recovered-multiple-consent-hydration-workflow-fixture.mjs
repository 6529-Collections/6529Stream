// Compiler-encoded mock of the reviewed source/read boundaries, not an executed native graph.
import assert from 'node:assert/strict';
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as rh from '../dist/current-artist-recovered-multiple-consent-hydration.js';
import * as workflow from '../dist/current-artist-recovered-multiple-consent-hydration-workflow.js';
import { ARTIST_HYDRATION_SUITE_TUPLE } from '../dist/current-artist-authority-hydration.js';
import { fixture, compiledABI, compiledLibraryEvents, compiledLibraryValueInterface, libraryValueABI } from './current-artist-recovered-multiple-consent-hydration-source-fixture.mjs';
export { rh, workflow, fixture };
export const coder=AbiCoder.defaultAbiCoder(), A=n=>getAddress(`0x${BigInt(n).toString(16).padStart(40,'0')}`), H=v=>id(String(v));
export const hash=(types,values)=>keccak256(coder.encode(types,values));
const domains=Array.from({length:7},(_,i)=>rh.artistRecoveredMultipleConsentHydrationOwnerDomain(i));
const ordinary=['registry','coordinator','archive','owner','identity','checkpoint','recoveredOwner','chronology','history','nativeReceipts','reconstruction','timing','core','governanceFacts','finalityRecovery','finalityBinding','entropyUnavailability','entropyFreshRecovery','hydrationOwner','hydrationCoordinator','recoveredCoordinator'];
export const abi=new Interface(ordinary.flatMap(name=>compiledABI(name)).filter(row=>row.type!=='constructor').concat(compiledLibraryEvents('commit').fragments));
// Concrete compiler ABIs are immutable fixture inputs; parse each target alias once.
const targetInterfaces=new Map(['binding','collaborator','identity','acceptance','attribution','payout','consent','registry','archive','coordinator','core'].map(name=>[name,new Interface(compiledABI(name))]));
export const preparedAbi=compiledLibraryValueInterface('prepared');
const prepare2='0x'+fixture.libraryMethodIdentifiers.StreamArtistRecoveredHydrationPrepared['prepare(StreamArtistOnboardingTypes.SuiteConfiguration,StreamArtistRecoveredHydrationTypes.Request)'];
const prepare3='0x'+fixture.libraryMethodIdentifiers.StreamArtistRecoveredHydrationPrepared['prepare(StreamArtistOnboardingTypes.SuiteConfiguration,StreamArtistRecoveredHydrationTypes.Request,StreamArtistOnboardingTypes.RoyaltyFreeze[])'];
export const safeABI=new Interface(['function nonce() view returns(uint256)','function getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256) view returns(bytes32)','function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) payable returns(bool)','event ExecutionSuccess(bytes32 txHash,uint256 payment)','event ExecutionFailure(bytes32 txHash,uint256 payment)']);
const indexedSafe=new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)','event ExecutionFailure(bytes32 indexed txHash,uint256 payment)']);
const safeTypes={SafeTx:['to:address','value:uint256','data:bytes','operation:uint8','safeTxGas:uint256','baseGas:uint256','gasPrice:uint256','gasToken:address','refundReceiver:address','nonce:uint256'].map(s=>{const[name,type]=s.split(':');return{name,type};})};
export const safeHash=(chainId,address,values)=>TypedDataEncoder.hash({chainId,verifyingContract:address},safeTypes,Object.fromEntries(safeTypes.SafeTx.map((f,i)=>[f.name,values[i]])));
const zeroCell=()=>({commitment:ZeroHash,touchedRevision:0n,kind:0n,status:0n});
export function zeroValue(value){const p=typeof value==='string'?ParamType.from(value):value;if(p.baseType==='tuple')return Object.fromEntries(p.components.map(f=>[f.name,zeroValue(f)]));if(p.baseType==='array')return Array.from({length:Math.max(0,p.arrayLength)},()=>zeroValue(p.arrayChildren));if(p.type==='address')return ZeroAddress;if(p.type==='bool')return false;if(p.type==='string')return '';if(p.type==='bytes')return '0x';if(p.type.startsWith('bytes'))return `0x${'00'.repeat(Number(p.type.slice(5)))}`;return 0n;}

import { semanticFixture } from './current-artist-recovered-multiple-consent-hydration-semantic-fixture.mjs';

// Every response is selected from explicit retained constructor rows. No wildcard/default state.
function contentRead(bundles,method,args,fragment) {
  const equalTerms=(a,b)=>coder.encode([fragment.inputs[0]],[a])===coder.encode([fragment.inputs[0]],[b]);
  for(const b of bundles) {
    const q=b.original;
    if(method==='policyRecord'&&q.collectionId===args[0]) {
      const i=q.keys.findIndex(k=>k.phaseId===args[1]&&k.policyHash===args[2]);if(i>=0)return q.policies[i].recordHash;
    }
    for(const r of q.economics) {
      if(['economicsRecord','economicsRecordForBinding'].includes(method)&&equalTerms(r.item.terms,args[0])) {
        if(method==='economicsRecordForBinding'){assert.equal(args[1],q.artistId);assert.equal(args[2],1n);assert.equal(args[3],q.bindingHash);}
        return r.item.recordHash;
      }
      if(method==='economicsRecordAssociation'&&r.item.recordHash===args[0])return r.item.association;
    }
    for(const r of q.sales) {
      if(method==='saleConsentRecord'&&r.item.recordHash===args[0])return r.item;
      if(method==='saleConsentAt'&&q.collectionId===args[0]&&r.item.terms.saleId===args[1]&&r.item.terms.saleConfigHash===args[2])return r.current;
    }
    if(method==='contentConsentRecord'){const r=b.consents.find(r=>r.recordHash===args[0]);if(r)return r;}
    if(method==='contentConsentAt'){const r=b.consents.findLast(r=>equalTerms(r.terms,args[0]));if(r){assert.equal(args[1],1n);return r;}}
    if(method==='royaltyFreezeRecord') {const r=b.royalties.find(r=>equalTerms(r.terms,args[0]));if(r){assert.equal(args[1],q.artistId);assert.equal(args[2],1n);return r.item;}}
    if(method==='contentFreezeRecord'){const r=b.freezes.find(r=>r.recordHash===args[0]);if(r)return r;}
    if(method==='contentFreezeAt'&&q.collectionId===args[0]){const r=b.freezes.findLast(r=>r.metadataContract===args[2]&&r.lockClasses.includes(args[3]));if(r){assert.equal(args[1],1n);return r;}}
    if(method==='recordDelegation') {
      for(const r of q.policies)if(r.recordHash===args[0])return r.grant;
      for(const r of [...q.economics,...q.sales,...b.royalties])if(r.item.recordHash===args[0])return r.grant;
      if([...b.consents,...b.freezes].some(r=>r.recordHash===args[0]))return ZeroHash;
    }
  }
  throw Error(`Unknown retained consent row: ${method}`);
}

export function setup(options={}) {
  const codes=new Map(), pin=n=>{const address=A(n),code=`0x61${BigInt(n).toString(16).padStart(4,'0')}6000`;codes.set(address,code);return{address,codeHash:keccak256(code)};};
  const common=Array.from({length:7},(_,i)=>pin(50+i)),sourcePins=Array.from({length:9},(_,i)=>pin(10+i)).concat(common),destinationPins=Array.from({length:9},(_,i)=>pin(30+i)).concat(common);
  const deployment={chainId:1n,source:{registry:sourcePins[7],coordinator:pin(70),components:sourcePins},destination:{registry:destinationPins[7],coordinator:pin(71),components:destinationPins},preparationLibrary:pin(72),preparationDependencies:[pin(73)]};
  const caller=A(80);const safePin=pin(80);
  const suite=p=>({owners:p.slice(0,7).map(v=>v.address),registry:p[7].address,archive:p[8].address,core:p[9].address,mintManager:p[10].address,roleRegistry:p[11].address,metadata:p[12].address,primaryResolver:p[13].address,royaltyResolver:p[14].address,validator:p[15].address,primaryRevenueClass:H('PRIMARY_SALE')});
  const source=suite(sourcePins),destination=suite(destinationPins),origin={chainId:1n,registry:source.registry,coordinator:deployment.source.coordinator.address,archive:source.archive,owners:source.owners,ownerCodeHashes:sourcePins.slice(0,7).map(v=>v.codeHash),core:source.core,manager:source.mintManager,suiteConfigurationHash:hash([ARTIST_HYDRATION_SUITE_TUPLE],[source])};
  const before=domains.map((domainId,i)=>({domainId,revision:i===2?1n+BigInt((options.oneArtist?1:2)+(options.collectionCount??3)):0n,stateRoot:H(`destination root ${i}`),recordChainTip:H(`destination tip ${i}`)}));
  const material=semanticFixture({source,destination,origin,before,options,codes});
  const {certificate,request,input}=material,provenance=certificate.admission.provenance,checkpoints=provenance.eras.at(-1).checkpoints,journals=provenance.journals;
  // Independent retained source DTOs are constructor facts, not a decoder cache.
  // state.certificate is the mutable producer response used by negative tests.
  const ownerPayload = i => material.payloads[i];
  const sourceCatalogs=new Map([2,4,6].map(i=>[source.owners[i],ownerPayload(i).publications]));
  const state={codes,hooks:[],calls:[],mined:false,captured:null,catalogs:new Map(),metadata:new Map(),evidence:new Map(),
    beforeCatalogs:new Map([destination.owners[2],destination.owners[4],destination.owners[6],destination.archive].map(host=>[host,[]])),
    capabilities:request.expectedCapabilities,certificate,tx:null,receipt:null,safeNonce:4n,safeEndingNonce:5n,transactionHook:null,blockOverride:null};
  const sourceHosts=[...source.owners,source.registry,source.archive,deployment.source.coordinator.address];
  const provider={
    async getNetwork(){return{chainId:1n};},
    async getBlock(tag){return state.blockOverride?.(tag)??{number:tag,timestamp:100+tag,hash:H(`block${tag}`)};},
    async getCode(host,tag){for(const hook of state.hooks){const r=hook({method:'getCode',host:getAddress(host),tag});if(r!==undefined)return r;}return codes.get(getAddress(host))??'0x';},
    async call(tx){
      const host=getAddress(tx.to),tag=tx.blockTag;let fragment,args,selectedAbi=abi;
      if(host===caller){selectedAbi=safeABI;fragment=safeABI.getFunction(tx.data.slice(0,10));args=safeABI.decodeFunctionData(fragment,tx.data);}
      else if([prepare2,prepare3].includes(tx.data.slice(0,10))){
        assert.equal(host,deployment.preparationLibrary.address);selectedAbi=preparedAbi;fragment=preparedAbi.fragments.find(f=>f.type==='function'&&f.name==='prepare'&&f.inputs.length===(tx.data.slice(0,10)===prepare2?2:3));args=preparedAbi.decodeFunctionData(fragment,`${fragment.selector}${tx.data.slice(10)}`);
      }else{
        const ownerNames=['binding','collaborator','identity','acceptance','attribution','payout','consent'];
        const ownerIndex=source.owners.includes(host)?source.owners.indexOf(host):destination.owners.indexOf(host);
        const name=ownerIndex>=0?ownerNames[ownerIndex]:[source.registry,destination.registry].includes(host)?'registry':
          [source.archive,destination.archive].includes(host)?'archive':[deployment.source.coordinator.address,deployment.destination.coordinator.address].includes(host)?'coordinator':host===source.core?'core':null;
        if(!name)throw Error('Unknown fixture target');
        const targetABI=targetInterfaces.get(name);fragment=targetABI.getFunction(tx.data.slice(0,10));
        if(!fragment)throw Error('Unsupported target getter');selectedAbi=targetABI;args=targetABI.decodeFunctionData(fragment,tx.data);
      }
      const method=fragment.name,encode=values=>selectedAbi.encodeFunctionResult(fragment,values);state.calls.push({method,host,tag,args,from:tx.from,value:tx.value,gasLimit:tx.gasLimit});
      for(const hook of state.hooks){const result=hook({method,host,tag,args,fragment,tx});if(result!==undefined)return typeof result==='string'?result:encode(result);}
      if(host===caller){if(method==='nonce')return encode([tag>=12?state.safeEndingNonce:state.safeNonce]);if(method==='getTransactionHash')return encode([safeHash(1n,caller,Array.from(args))]);throw Error('Unexpected Safe fixture call');}
      const isSource=sourceHosts.includes(host),selected=isSource?source:destination,owner=selected.owners.indexOf(host),post=state.mined&&tag>=12&&!isSource;
      const payload=owner>=0?ownerPayload(owner):null;
      switch(method){
        case 'delegationRecord': {
          assert.equal(owner,2);const row=material.identities.flatMap(v=>v.delegations).find(v=>v.recordHash===args[0]);
          if(!row)throw Error('Unknown retained grant');return encode([row.record]);
        }
        case 'policyRecord':case 'economicsRecord':case 'economicsRecordForBinding':case 'economicsRecordAssociation':
        case 'saleConsentRecord':case 'saleConsentAt':case 'contentConsentRecord':case 'contentConsentAt':
        case 'royaltyFreezeRecord':case 'contentFreezeRecord':case 'contentFreezeAt':case 'recordDelegation': {
          assert.equal(owner,6);return encode([contentRead(material.contents,method,args,fragment)]);
        }
        case 'prepare':assert.equal(tx.value,0n);return encode([state.certificate]);
        case 'hydrateRecoveredArtistAuthority':case 'hydrateRecoveredArtistAuthorityWithConsents':assert.equal(host,destination.registry);assert.equal(tx.value,0n);return encode([state.captured.commitment]);
        case 'authorityHydrationSuite':return encode([selected]);
        case 'deploymentChainId':return encode([1n]);
        case 'core':return encode([selected.core]);
        case 'mintManager':return encode([selected.mintManager]);
        case 'artistRegistry':return encode([selected.registry]);
        case 'operationCoordinator':return encode([isSource?deployment.source.coordinator.address:deployment.destination.coordinator.address]);
        case 'archiveV2':return encode([selected.archive]);
        case 'domainId':return encode([domains[owner]]);
        case 'configurationHash':return encode([H('destination configuration')]);
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
        case 'ownerStateSnapshotV2':return encode([isSource?checkpoints[owner].ownerState:post?state.captured.after[owner]:before[owner]]);
        case 'authorityCheckpoint':return encode([isSource?checkpoints[owner]:{schema:rh.ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CHECKPOINT_SCHEMA,ownerState:post?state.captured.after[owner]:before[owner],replayCount:owner===2?2n+2n*BigInt(certificate.admission.artists.length+certificate.admission.collections.length):0n,replayRoot:H(`destination replay${owner}`),nonceIndexCount:post?BigInt(payload.nonces.length):0n,nonceRoot:H(`destination nonce${owner}`)}]);
        case 'nextRegistrationNonce':return encode([isSource||post?BigInt(certificate.admission.artists.length):0n]);
        case 'recoveredAuthorityHydrationCapability':return encode([state.capabilities[owner]]);
        case 'authorityHydrationCommitment':return encode([post?state.captured.commitment:ZeroHash]);
        case 'recoveredHydrationImportedPrefix':return encode(post?[payload.provenance,state.captured.commitment,state.captured.after[owner].revision]:[{origins:[],eras:[],journal:[],aliases:[]},ZeroHash,0n]);
        case 'artistNativeReceiptCount':return encode([isSource?BigInt(journals[owner].length):0n]);
        case 'artistNativeReceiptAt':return encode([journals[owner][Number(args[0])].receipt]);
        case 'artistNativeReceiptRevisionAt':return encode([journals[owner][Number(args[0])].position.point.ownerRevision]);
        case 'authorityReplayAt':return encode([certificate.data[owner].sourceKeys[Number(args[0])],certificate.data[owner].cells[Number(args[0])]]);
        case 'replayCell':{
          const data=certificate.data[owner];if(isSource)return encode([data.cells[data.sourceKeys.indexOf(args[0])]]);
          const target={...origin,registry:destination.registry,coordinator:deployment.destination.coordinator.address,archive:destination.archive,owners:destination.owners,ownerCodeHashes:destinationPins.slice(0,7).map(v=>v.codeHash),suiteConfigurationHash:hash([ARTIST_HYDRATION_SUITE_TUPLE],[destination])};
          const index=data.origins.findIndex(v=>rh.artistRecoveredMultipleConsentHydrationReplayKey(target,owner,v)===args[0]);
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
        case 'storedPayloadCount':return encode([BigInt((isSource?sourceCatalogs.get(host):post?state.catalogs.get(host):state.beforeCatalogs.get(host))?.length??0)]);
        case 'storedPayloadAt':{const row=(isSource?sourceCatalogs.get(host):post?state.catalogs.get(host):state.beforeCatalogs.get(host))[Number(args[0])];return encode([row.pointer,row.payloadType,row.payloadHash]);}
        case 'artistEvidenceMetadataV2':return encode(state.metadata.get(args[0]));
        case 'artistEvidenceBytesV2':return encode([state.evidence.get(args[0])]);
        default:throw Error(`Unexpected original mock method ${method}`);
      }
    },
    async getTransaction(hash){if(state.transactionHook)state.transactionHook(hash);return state.tx;},async getTransactionReceipt(){return state.receipt;}
  };
  return{provider,deployment,input,request,certificate,state,source,destination,origin,before,caller,safePin,...material};
}
export async function capture(s){const c=await workflow.captureArtistRecoveredMultipleConsentHydration(s.provider,s.deployment,s.caller,s.input,{blockTag:10,gasLimit:10000000n});s.state.captured=c;return c;}
export function install(s,c,mode='direct'){
  s.state.mined=true;s.state.catalogs=structuredClone(s.state.beforeCatalogs);const logs=[];
  const emit=(address,name,values,iface=abi)=>{const e=iface.encodeEventLog(iface.getEvent(name),values);logs.push({address,...e,index:logs.length,blockNumber:12,blockHash:H('block12'),transactionHash:H('tx'),removed:false});};
  const store=(host,row)=>{const list=s.state.catalogs.get(host)??[];if(list.some(v=>v.payloadType===row.payloadType&&v.payloadHash===row.payloadHash))return;emit(host,'ArtistStoredPayload',[1n,BigInt(list.length),row.payloadType,row.payloadHash,row.pointer]);list.push(row);s.state.catalogs.set(host,list);};
  for(const i of [2,4,6])for(const row of c.owners[i].payload.publications)store(s.destination.owners[i],row);
  const append=(evidenceId,payload,index)=>{const pointer=A(200+index),contentHash=keccak256(payload),size=BigInt((payload.length-2)/2);s.state.codes.set(pointer,`0x00${payload.slice(2)}`);s.state.evidence.set(evidenceId,payload);s.state.metadata.set(evidenceId,[contentHash,pointer,size,12n]);store(s.destination.archive,{pointer,payloadType:H('ARTIST_OPERATION_EVIDENCE'),payloadHash:contentHash});emit(s.destination.archive,'ArtistArchiveEvidenceAppendedV2',[evidenceId,1n,contentHash,pointer,size]);};
  const coordinates={chainId:1n,registry:s.destination.registry,coordinator:s.deployment.destination.coordinator.address};
  for(let i=0;i<c.descriptor.pageHashes.length;i++)append(rh.artistRecoveredMultipleConsentHydrationPageId(coordinates,c.commitment,c.descriptor,BigInt(i)),`0x${c.profileEvidence.slice(2+i*40960,2+(i+1)*40960)}`,i);
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
export const run=(s,c,mined)=>workflow.reconcileArtistRecoveredMultipleConsentHydrationReceipt(s.provider,c,H('tx'),mined.options);
export const renumber=logs=>logs.forEach((log,index)=>{log.index=index;});
