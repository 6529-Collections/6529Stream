// Compiler-backed RPC consistency fixtures. Workers, whole-byte archive proofs, private
// accumulators and EVM/Safe execution are mocked. Compact sealed inventories are consumer
// fixtures, not demonstrations of a native-reachable nineteen-stage producer lifecycle.
// In particular, empty segments exercise the archive consumer only.
import assert from 'node:assert/strict';
import { Interface, id, keccak256 } from 'ethers';
import * as archive from '../dist/current-authority-preservation-archive-v1.js';
import * as workflow from '../dist/current-authority-preservation-archive-v1-workflow.js';
import { setup as inventorySetup, inv, A,H,Z,ZA,safe,coder,zero,plain,item,progress } from './current-authority-preservation-inventory-v1-workflow-fixture.mjs';
import { fixture,compiledInterfaces as c } from './current-authority-preservation-archive-v1-fixture.mjs';
export { archive,workflow,inv,A,H,Z,ZA,safe,coder,item,c,fixture };
export const prefix='currentAuthorityPreservationArchiveV1', ip='currentAuthorityPreservationInventoryV1', copy=structuredClone;
const P='CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_';
export const empty=name=>zero(archive[P+name+'_TUPLE']);
const common=value=>value.inventory??value.coverage??value;
function wire(p){const suffix=p.type.slice(p.type.indexOf('[')<0?p.type.length:p.type.indexOf('['));return p.components?`(${p.components.map(x=>`${wire(x)} ${x.name}`).join(',')})${suffix}`:/^(address|bool|string|bytes\d*|u?int\d*)(\[.*\])?$/.test(p.type)?p.type:`uint8${suffix}`;}
export function workerABI(contract,method){const row=fixture.libraryAbis[contract].find(x=>x.type==='function'&&x.name===method),entries=Object.entries(fixture.libraryMethodIdentifiers[contract]).filter(([s])=>s.startsWith(method+'('));assert.equal(entries.length,1);return{contract,method,selector:'0x'+entries[0][1].replace(/^0x/,''),inputs:row.inputs.map(wire),outputs:row.outputs.map(wire)};}
const workers=[...['capture','environment'].map(method=>({role:'authorityReader',...workerABI('StreamCurrentAuthorityBundleArchiveEnvironment',method)})),...['configuration','environment','originSet','originAt','route','admit','current'].map(method=>({role:'archiveReader',...workerABI('StreamMultiOriginBundleArchiveReads',method)}))];
const envABI=new Interface(['function currentArtifactEnvironment() view returns(bytes32,uint64)','function currentExternalArtifactEnvironment() view returns(bytes32,uint64)']);
export const methods=['beginCoverage','coverNext','coverEmptySegment','beginRefresh','refreshNext'];
export function setup(options={}){
  const base=inventorySetup({scopeKind:options.scopeKind??'scoped',distinctPresented:options.distinctPresented}),kind=base.kind,state=base.state;
  const code=state.code,pin=address=>{if(!code.has(address))code.set(address,`0x60${address.slice(-6)}`);return{address,codeHash:keccak256(code.get(address))};};
  const coords={chainId:1n,core:base.coords.core,archive:A(11000),scopeKind:kind};
  const d={chainId:1n,core:coords.core,scopeKind:kind,archive:pin(coords.archive),authorityReader:pin(A(11100)),archiveReader:pin(A(11101)),linkedDependencies:[pin(A(11102))]},hd={chainId:1n,core:coords.core,scopeKind:kind,archive:d.archive};
  const host=c[kind==='collection'?'StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1':'StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1'];
  const targets=[base.anchor.targets[0],base.anchor.targets[1],base.coords.inventory,base.anchor.targets[10],base.anchor.targets[11],base.anchor.artistTargets[4]],deps={targets,codeHashes:targets.map(a=>pin(a).codeHash),chainId:1n,readGas:300000n,archiveGas:900000n};
  const dependencyHash=archive[prefix+'DependencyHash'](kind,deps,base.od,base.ad),idValue=base.planId;
  const origins=[...state.origins];
  if(options.stateBundle){const producer=options.oldOrigin?base.origin(10800):base.current,[row,original]=base.originalRow(options.operation??17n,H(43000),base.caller,producer);Object.assign(row,{algorithm:1n,canonicalizationId:id('RAW_BYTES')});base.addSegment([row]);state.originRecords.set(inv[ip+'ItemHash'](row),original);if(!origins.some(o=>inv[ip+'OriginPinHash'](o)===inv[ip+'OriginPinHash'](producer)))origins.push(producer);}
  state.origins=origins;
  for(let i=0;i<origins.length;i++)base.addSegment(base.runtimeItems(origins[i],BigInt(i)),inv[ip+'OriginPinHash'](origins[i]));
  let tail=options.item??item(101);
  if(options.external)tail=item(102,{kind:0n,algorithm:1n,canonicalizationId:id('RAW_BYTES'),digest:H(43002),byteSize:3n});
  base.addSegment(options.empty?[]:options.duplicates?[tail,copy(tail)]:[tail]);
  state.before=base.plan(8n);progress(state.before).nextToken=base.co.tokenCount;state.originCursor=BigInt(origins.length);state.originRoot=inv[ip+'OriginSetHash'](origins);state.evidence=base.evidence(state.before);progress(state.before).renderCriticalEvidenceHash=common(state.evidence).renderCriticalEvidenceHash;
  const rows=state.segments.flatMap(s=>s.items),inventoryEvidence=state.evidence;
  const s={before:empty('PROGRESS'),after:null,refresh:empty('REFRESH'),afterRefresh:null,admissions:[],afterAdmissions:null,evidence:null,afterEvidence:null,onchainHash:H(41001),epoch:1n,externalHash:H(41002),revision:0n,observation:Z,capture:copy(base.capture),reject:null,workerResult:null,hostResult:null,raw:null,seen:[],requireFull:false};
  function environment(){const baseHash=archive[prefix+'BaseEnvironmentHash'](deps,s.onchainHash,s.epoch,s.externalHash,s.revision),multiHash=archive[prefix+'MultiOriginEnvironmentHash'](baseHash,base.od,kind,idValue,state.originRoot,BigInt(origins.length));return{baseHash,multiHash,hash:archive[prefix+'EnvironmentHash'](multiHash,base.ad,s.capture)};}
  const refreshId=()=>archive[prefix+'RefreshId'](coords,dependencyHash,idValue,environment().hash);
  function route(row){const original=row.kind===6n?state.originRecords.get(inv[ip+'ItemHash'](row)):null;return archive.validateCurrentAuthorityPreservationArchiveV1OriginRoute(deps,idValue,common(inventoryEvidence),row,original,origins);}
  function admission(row,index){
    if([6n,7n,8n,9n,11n].includes(row.kind))return copy(archive[prefix+'IntrinsicAdmission'](row,{backend:0n,coverageHash:Z,objectHash:Z},row.kind===6n?H(43003):Z));
    const result=empty('ADMISSION'),backend=options.external&&row===tail?1n:2n;result.proof={backend,coverageHash:H(44000+index),objectHash:H(45000+index)};result.originalBundleHash=H(46000+index);
    if(backend===1n)Object.assign(result.externalOriginal,{coverageHash:result.proof.coverageHash,objectHash:result.proof.objectHash,artistId:base.co.artistId,contentHash:row.digest,sha256Digest:H(47000+index),byteSize:row.byteSize||1n,firstReceiptHash:H(47100),secondReceiptHash:H(47101),firstFixityHash:H(47102),secondFixityHash:H(47103),checkpointHash:H(47104),profileHash:H(47105)});
    else Object.assign(result.onchainOriginal,{completionHash:result.proof.coverageHash,artifactHash:result.proof.objectHash,artistId:base.co.artistId,schemaId:row.schemaId,canonicalizationId:row.canonicalizationId,contentHash:row.digest,byteLength:row.byteSize||1n,chunkCount:1n,validationEpoch:1n,evidenceChainHash:H(47200)});
    return result;
  }
  const admitted=rows.map((row,i)=>({item:row,admission:admission(row,i),originHash:route(row).originHash}));
  function suffix(segment,items,index){let next=Z;for(let i=items.length-1;i>=index;i--)next=inv[ip+'Link'](segment.key,segment.itemCount,BigInt(i),items[i],next);return next;}
  function position(segmentIndex,itemIndex=0){const p=empty('PROGRESS');p.environmentHash=environment().hash;
    for(let i=0;i<segmentIndex;i++){p.segmentChainHash=inv[ip+'AppendSegment'](p.segmentChainHash,BigInt(i),state.segments[i].segment);p.itemCount+=state.segments[i].segment.itemCount;}
    p.segmentIndex=BigInt(segmentIndex);p.segmentItemIndex=BigInt(itemIndex);p.itemCount+=BigInt(itemIndex);p.complete=segmentIndex===state.segments.length;
    if(!p.complete)p.nextLink=suffix(state.segments[segmentIndex].segment,state.segments[segmentIndex].items,itemIndex);
    for(let i=0;i<Number(p.itemCount);i++){const v=admitted[i];p.evidenceChainHash=archive[prefix+'ItemChain'](kind,p.evidenceChainHash,idValue,BigInt(i),inv[ip+'ItemHash'](v.item),v.admission,v.originHash);}
    s.before=p;s.admissions=copy(admitted.slice(0,Number(p.itemCount)));s.evidence=p.complete?archive[prefix+'Evidence'](coords,dependencyHash,state.originRoot,BigInt(origins.length),inventoryEvidence,p.evidenceChainHash):null;return p;
  }
  function request(method){
    if(method==='beginCoverage'){if(options.existing)position(options.complete?state.segments.length:0);}
    else if(method==='coverNext'||method==='coverEmptySegment')position(options.first?0:state.segments.length-1,options.itemIndex??0);
    else {position(state.segments.length);if(method==='refreshNext')s.refresh={environmentHash:environment().hash,nextIndex:BigInt(options.refreshIndex??0),currentObservationChain:options.refreshIndex?H(48000):Z,complete:false};else if(options.existingRefresh)s.refresh={environmentHash:environment().hash,nextIndex:0n,currentObservationChain:Z,complete:false};}
    if(options.mixed)s.before.environmentHash=H(48999);
    if(method==='coverNext'){const index=Number(s.before.itemCount),v=admitted[index],segment=state.segments[Number(s.before.segmentIndex)];return{kind:method,id:idValue,item:v.item,proof:v.admission.proof,nextLink:suffix(segment.segment,segment.items,Number(s.before.segmentItemIndex)+1)};}
    return{kind:method,id:idValue,...(method==='refreshNext'?{expectedIndex:s.refresh.nextIndex}:{})};
  }
  const originalCall=base.provider.call.bind(base.provider),provider={...base.provider,async call(tx){
    const entry=workers.find(w=>d[w.role].address===tx.to&&w.selector===tx.data.slice(0,10));
    if(entry){state.calls.push({...tx});await state.hooks.call?.(tx);const args=coder.decode(entry.inputs,'0x'+tx.data.slice(10));let values;
      if(entry.role==='authorityReader')values=[entry.method==='capture'?s.capture:environment().hash];
      else if(entry.method==='configuration')values=[];else if(entry.method==='environment')values=[environment().multiHash];else if(entry.method==='originSet')values=[state.originRoot,BigInt(origins.length)];else if(entry.method==='originAt')values=[origins[Number(args[2])]];
      else {const row=plain(entry.inputs[3],args[3]),r=route(row);if(entry.method==='route')values=[r.dependencies,r.originHash];else if(entry.method==='admit'){const index=rows.findIndex(v=>inv[ip+'ItemHash'](v)===inv[ip+'ItemHash'](row));values=[admitted[index].admission,s.observation,r.originHash];}else if(entry.method==='current')values=[s.observation];else throw Error('Unexpected worker');}
      s.seen.push({entry,args,tx});values=await s.workerResult?.(entry,args,values,tx)??values;return coder.encode(entry.outputs,values);
    }
    if(tx.to===targets[3]||tx.to===targets[4]){state.calls.push({...tx});await state.hooks.call?.(tx);const parsed=envABI.parseTransaction({data:tx.data});assert.equal(tx.gasLimit,deps.archiveGas);assert.equal(parsed.name,tx.to===targets[3]?'currentArtifactEnvironment':'currentExternalArtifactEnvironment');return envABI.encodeFunctionResult(parsed.fragment,tx.to===targets[3]?[s.onchainHash,s.epoch]:[s.externalHash,s.revision]);}
    if(tx.to===base.coords.inventory){const parsed=base.host.parseTransaction({data:tx.data});if(parsed.name==='supportsInterface'){state.calls.push({...tx});return base.host.encodeFunctionResult(parsed.fragment,[['0x01ffc9a7',kind==='collection'?'0x1fee95a8':'0x6b2054bd','0x57219121','0xc0d7d0d7'].includes(parsed.args[0])]);}if(['requireCurrent','requireFullDefinitionBytes'].includes(parsed.name))throw Error('Invented inventory current gate');}
    if(tx.to!==coords.archive)return originalCall(tx);
    state.calls.push({...tx});await state.hooks.call?.(tx);const parsed=host.parseTransaction({data:tx.data}),name=parsed.name,args=parsed.args,after=tx.blockTag>=100;let values;
    const named={core:0,metadataHost:1,renderCriticalInventory:2,artifactCoverage:3,externalCoverage:4},hashes={coreCodeHash:0,metadataCodeHash:1,inventoryCodeHash:2};
    if(name in named)values=[targets[named[name]]];else if(name in hashes)values=[deps.codeHashes[hashes[name]]];else if(name==='dependencies')values=[deps];else if(name==='originDependencies')values=[base.od];else if(name==='authorityDependencies')values=[base.ad];else if(name==='dependencyHash')values=[dependencyHash];else if(name==='deploymentChainId')values=[1n];else if(['originProfile','preservationPolicyBundleArchiveProfile','scopedPreservationPolicyBundleArchiveProfile'].includes(name))values=[archive[prefix+'Profile'](kind)];
    else if(name==='progress')values=[after&&s.after?s.after:s.before];else if(name==='refresh')values=[args[0]!==refreshId()?empty('REFRESH'):after&&s.afterRefresh?s.afterRefresh:s.refresh];else if(name==='bundleEvidence')values=[after&&s.afterEvidence?s.afterEvidence:s.evidence];
    else if(name==='admittedItem'||name==='admittedOriginHash'){const v=(after&&s.afterAdmissions?s.afterAdmissions:s.admissions)[Number(args[1])];values=name==='admittedItem'?[v.item,v.admission]:[v.originHash];}
    else if(name==='requireCoverage'||name==='requireFullCurrentCoverage'){if(name==='requireCoverage')assert.equal(args.at(-1),common(inventoryEvidence).renderCriticalEvidenceHash);else s.requireFull=true;values=[s.evidence];}
    else {if(!methods.includes(name))throw Error('Unexpected archive method '+name);if(s.reject&&tx.blockTag>=s.reject.tag)throw s.reject.error;values=name==='beginRefresh'?[refreshId()]:[];}
    values=await s.hostResult?.(name,args,values,tx)??values;const raw=host.encodeFunctionResult(parsed.fragment,values);return s.raw?s.raw(name,raw,tx):raw;
  }};
  const eventName=suffix=>`${kind==='scoped'?'Scoped':''}Bundle${suffix}`,emit=(suffix,args)=>({address:coords.archive,...host.encodeEventLog(eventName(suffix),[...(kind==='scoped'?[1n]:[]),...args])});
  function mine(saved,mode='direct'){
    const st=saved.stage,q=saved.prepared.request;Object.assign(s,{after:copy(st.after),afterAdmissions:copy(st.admissions),afterEvidence:st.evidence,afterRefresh:st.refreshAfter??{environmentHash:st.environment.hash,nextIndex:common(inventoryEvidence).itemCount,currentObservationChain:H(49010),complete:true}});if(st.admitted)s.afterAdmissions.push(copy(st.admitted));const logs=[];
    if(q.kind==='beginCoverage'&&!st.existing)logs.push(emit('CoverageStarted',[idValue,common(inventoryEvidence).renderCriticalEvidenceHash]));
    if(st.admitted)logs.push(emit('ItemAdmitted',[idValue,st.before.itemCount,inv[ip+'ItemHash'](st.admitted.item),st.admitted.admission]));
    if(['coverNext','coverEmptySegment'].includes(q.kind)&&st.after.complete)logs.push(emit('CoverageCompleted',[idValue,common(st.evidence).bundleCoverageHash,st.evidence]));
    if(q.kind==='refreshNext')logs.push(emit('RefreshAdvanced',[idValue,st.refreshId,st.refreshAfter.nextIndex,st.refreshAfter.currentObservationChain,st.refreshAfter.complete]));
    const hash=H(49000),safeHash=H(49001),block=100;let from=base.caller,to=coords.archive,data=saved.prepared.call.data;
    if(mode!=='direct'){from=A(31);to=base.caller;data=safe.encodeFunctionData('execTransaction',[coords.archive,0n,data,0,0,0,0,ZA,ZA,'0x12']);const events=mode==='indexed'?new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']):safe;logs.push({address:base.caller,...events.encodeEventLog('ExecutionSuccess',[safeHash,0n])});}
    state.receipts.set(hash,{status:1,hash,from,to,blockNumber:block,blockHash:base.header(block).hash,logs:base.logsFor(hash,block,logs)});state.transactions.set(hash,{hash,from,to,chainId:1n,blockNumber:block,blockHash:base.header(block).hash,data,value:0n});return{hash,options:mode==='direct'?{execution:'direct'}:{execution:'safe',expectedSafeTxHash:safeHash}};
  }
  const opts=()=>({blockTag:90,gasLimit:base.gasLimit,segments:state.segments.map(v=>v.locator)}),capture=q=>workflow.captureCurrentAuthorityPreservationArchiveV1(provider,d,base.caller,q,opts());
  return{base,kind,coords,d,hd,host,deps,dependencyHash,rows,admitted,inventoryEvidence,state,s,provider,environment,refreshId,route,request,position,mine,emit,eventName,opts,capture,caller:base.caller,id:idValue};
}
