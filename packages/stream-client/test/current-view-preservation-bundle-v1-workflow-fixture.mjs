// Compiler-encoded mock RPC only: worker admission/source/nested gas and Safe execution are mocked.
// Compact sealed inventory prefixes authenticate client history joins, not the full native producer lifecycle.
// An empty segment is a generic consumer branch, not emitted by the concrete sixteen-stage producer.
import assert from 'node:assert/strict';
import { getAddress,id,keccak256,ParamType } from 'ethers';
import * as bundle from '../dist/current-view-preservation-bundle-v1.js';
import * as workflow from '../dist/current-view-preservation-bundle-v1-workflow.js';
import * as retrieval from '../dist/current-view-retrieval-v1.js';
import { setup as inventorySetup,inv,ip,c,coder,copy,Z,ZA,A,H,zero,plain,workerABI,item,callError,makeTransaction,safe,indexedSafe } from './current-view-preservation-inventory-v1-workflow-fixture.mjs';
export { bundle,workflow,inv,retrieval,c,coder,copy,Z,ZA,A,H,zero,plain,item,callError,safe,indexedSafe };
export const bp='currentViewPreservationBundleV1',host=c.StreamViewPreservationBundleArchiveCoverageV1;
export const methods=['beginCoverage','coverNext','coverRetrievalNext','coverEmptySegment','beginRefresh','refreshNext'];
export const emptyProgress=()=>zero(bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROGRESS_TUPLE),emptyRefresh=()=>zero(bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_REFRESH_TUPLE);
export const row=n=>item(n,{kind:9n,digest:keccak256('0x'),byteSize:0n});
export const obligation=(n=1,role=retrieval.CURRENT_VIEW_RETRIEVAL_V1_ROLE,uri=undefined)=>inv[ip+'Obligation']({scope:{scopeType:4n,collectionId:7n,tokenId:0n,scopeId:H('view-scope')},core:A(100),router:A(104),adoptionRecord:H('adoptionRecord'),adoptionSourceHash:H('adoption-source'),declaration:A(901),declarationRecord:H('declaration-'+n),payloadHash:H('payloadHash'),checkpointContextHash:H('sourceContextHash'),requestedURI:uri??(role===id('VIEW_ARCHIVE_LOCATOR_IMAGE')?'https://museum.example/image.png':'https://museum.example/image%20one.png'),artistId:H('artist'),artistPresentationHash:H('artist-presentation')});
export function rawCid(){const bytes=[1,85,18,32,...Array(32).fill(17)],alphabet='abcdefghijklmnopqrstuvwxyz234567';let accumulator=0,bits=0,result='';for(const byte of bytes){accumulator=(accumulator<<8)|byte;bits+=8;while(bits>=5){bits-=5;result+=alphabet[(accumulator>>>bits)&31];}accumulator&=(1<<bits)-1;}if(bits)result+=alphabet[(accumulator<<(5-bits))&31];return 'ipfs://b'+result;}
export function setup(options={}){
 const base=inventorySetup(),coords={chainId:1n,core:base.coords.core,bundle:A(800)},d={chainId:1n,core:coords.core,bundle:base.pin(coords.bundle),environmentReader:base.pin(A(801)),archiveReader:base.pin(A(802)),retrievalReader:base.pin(A(803)),linkedDependencies:[base.pin(A(804))]},hd={chainId:1n,core:coords.core,bundle:d.bundle};
 const targets=[base.deps.targets[0],base.deps.targets[1],base.coords.inventory,base.deps.targets[10],base.deps.targets[11],base.deps.artistTargets[4]],deps={targets,codeHashes:targets.map(a=>base.pin(a).codeHash),chainId:1n,readGas:500000n,archiveGas:1500000n};
 const dependencyHash=bundle[bp+'DependencyHash'](deps),f={base,d,hd,coords,deps,dependencyHash,caller:base.caller,code:base.code,block:base.block,receipts:base.receipts,transactions:base.transactions,calls:[],before:emptyProgress(),after:null,admissions:[],afterAdmissions:null,refreshes:new Map(),afterRefreshes:null,evidence:null,afterEvidence:null,epoch:0n,onchainHash:H('native-env'),validationEpoch:1n,externalHash:H('external-env'),healthRevision:1n,hook:null,callFailure:null,currentFailure:false,companionDead:false};
 Object.defineProperty(f,'planId',{get:()=>base.planId});f.baseEnvironment=()=>bundle[bp+'BaseEnvironmentHash'](deps,f.onchainHash,f.validationEpoch,f.externalHash,f.healthRevision);
 f.environment=()=>bundle[bp+'EnvironmentHash'](f.baseEnvironment(),base.witness.address,base.witness.codeHash,base.scope,f.epoch);
 f.refreshKey=()=>bundle[bp+'RefreshId'](coords,dependencyHash,f.planId,f.environment());f.observation=(index=0)=>H('observation-'+index+'-'+f.epoch);
 f.resetInventory=(parts)=>{base.segments=[];base.receipts.clear();base.transactions.clear();for(const rows of parts)base.addSegment(rows);base.before=base.plan(11n);base.before.progress.nextToken=base.context.tokenCount;base.evidence=base.evidenceFor(base.before);base.before.progress.renderCriticalEvidenceHash=base.evidence.inventory.renderCriticalEvidenceHash;f.rows=parts.flat().map(value=>copy(value));};
 f.resetInventory(options.parts??[[row(1),row(2)]]);
 f.admission=(r,witnessHash=Z)=>{if(witnessHash===Z&&r.role!==id('VIEW_ARCHIVE_LOCATOR_IMAGE'))return bundle[bp+'IntrinsicAdmission'](r,{backend:0n,objectHash:Z,coverageHash:Z});
  const a=zero(bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ADMISSION_TUPLE);a.proof={backend:1n,objectHash:H('object'),coverageHash:H('coverage')};a.originalBundleHash=H('wrapped-original');Object.assign(a.externalOriginal,{coverageHash:a.proof.coverageHash,objectHash:a.proof.objectHash,artistId:base.context.artistId,contentHash:H('external-content'),sha256Digest:H('external-sha'),byteSize:55n,firstReceiptHash:H('receipt-1'),secondReceiptHash:H('receipt-2'),firstFixityHash:H('fixity-1'),secondFixityHash:H('fixity-2'),firstFamilyRecordHash:H('family-1'),secondFamilyRecordHash:H('family-2'),checkpointHash:H('checkpoint'),profileHash:H('profile')});return a;};
 f.evidenceFor=p=>bundle[bp+'Evidence'](coords,dependencyHash,base.evidence,p.evidenceChainHash);
 f.suffix=(s,index)=>{let next=Z;for(let j=s.items.length-1;j>=Number(index);j--)next=inv[ip+'Link'](s.segment.key,s.segment.itemCount,BigInt(j),s.items[j],next);return next;};
 f.position=(count,{complete=false,witnessHashes=[]}={})=>{const p=emptyProgress();p.environmentHash=f.environment();f.admissions=[];let remaining=count;
  for(const s of base.segments){if(remaining>=s.items.length&&(s.items.length>0||complete)){p.segmentChainHash=inv[ip+'AppendSegment'](p.segmentChainHash,p.segmentIndex,s.segment);p.segmentIndex++;remaining-=s.items.length;}else{p.segmentItemIndex=BigInt(remaining);p.nextLink=f.suffix(s,BigInt(remaining));break;}}
  p.itemCount=BigInt(count);p.complete=p.segmentIndex===BigInt(base.segments.length);if(p.complete)p.nextLink=Z;
  for(let i=0;i<count;i++){const r=f.rows[i],w=witnessHashes[i]??(r.role===retrieval.CURRENT_VIEW_RETRIEVAL_V1_ROLE?H('witness-'+i):Z),a=f.admission(r,w);f.admissions.push({item:r,admission:a,witnessHash:w});p.evidenceChainHash=bundle[bp+'CoveredItemChain'](p.evidenceChainHash,f.planId,BigInt(i),inv[ip+'ItemHash'](r),a);}
  f.before=p;f.evidence=p.complete?f.evidenceFor(p):null;return p;};
 f.rehash=()=>{let chain=Z;for(let i=0;i<f.admissions.length;i++){const r=f.admissions[i];chain=bundle[bp+'CoveredItemChain'](chain,f.planId,BigInt(i),inv[ip+'ItemHash'](r.item),r.admission);}f.before.evidenceChainHash=chain;if(f.before.complete)f.evidence=f.evidenceFor(f.before);};
 f.cache=()=>{f.refreshes.set(f.refreshKey(),{environmentHash:f.environment(),nextIndex:BigInt(f.rows.length),currentObservationChain:H('private-initial-observation-chain'),complete:true});};
 f.opts=()=>({blockTag:10,gasLimit:12000000n,segments:base.opts().segments});
 f.request=method=>{if(method==='beginCoverage')return{method,id:f.planId};
  if(method==='coverRetrievalNext'){f.resetInventory([[obligation()]]);f.position(0);return{method,id:f.planId,item:copy(f.rows[0]),nextLink:Z,witnessHash:H('witness-0')};}
  if(method==='coverEmptySegment'){f.resetInventory([[],[row(2)]]);f.position(0);return{method,id:f.planId};}
  if(method==='coverNext'){f.position(0);return{method,id:f.planId,item:copy(f.rows[0]),nextLink:f.suffix(base.segments[0],1n),proof:copy(f.admission(f.rows[0]).proof)};}
  f.position(f.rows.length,{complete:true});if(method==='refreshNext')f.refreshes.set(f.refreshKey(),{...emptyRefresh(),environmentHash:f.environment()});return method==='refreshNext'?{method,id:f.planId,expectedIndex:0n}:{method,id:f.planId};};
 const workers=[['StreamBundleArchiveReads','environment',d.environmentReader],['StreamViewPreservationArchiveReadsV1','admit',d.archiveReader],['StreamViewPreservationArchiveReadsV1','current',d.archiveReader],['StreamViewRetrievalConsumerV1','environment',d.retrievalReader],['StreamViewRetrievalConsumerV1','context',d.retrievalReader],['StreamViewRetrievalConsumerV1','admit',d.retrievalReader],['StreamViewRetrievalConsumerV1','current',d.retrievalReader]].map(([a,b,p])=>({...workerABI(a,b),address:p.address}));
 const witnessHost=c.IStreamViewRetrievalWitnessV1;
 const envNative=c.IStreamArtifactEnvironment,envExternal=c.IStreamExternalArtifactEnvironment;
 const baseProvider=base.provider;
 f.provider={...baseProvider,async call(tx){const to=getAddress(tx.to),tag=tx.blockTag,after=tag>=12&&f.after!==null;const work=workers.find(w=>w.address===to&&w.selector===tx.data.slice(0,10));
  if(work){const raw=coder.decode(work.inputs,'0x'+tx.data.slice(10)),args=work.inputs.map((t,i)=>plain(ParamType.from(t),raw[i]));const call={...tx,name:work.method,worker:work.contract,args};f.calls.push(call);const override=await f.hook?.(call);if(override?.raw)return override.raw;if(override)return coder.encode(work.outputs,override);if(f.currentFailure)throw callError();if(work.contract==='StreamViewRetrievalConsumerV1'&&f.companionDead)throw callError();let result;
   if(work.method==='environment')result=[work.contract==='StreamBundleArchiveReads'?f.baseEnvironment():f.environment()];else if(work.method==='context')result=[base.context];else if(work.method==='admit'){const retrievalCall=work.contract==='StreamViewRetrievalConsumerV1',r=args[2],w=retrievalCall?args[3]:Z;result=[f.admission(r,w),f.observation(Number(f.before.itemCount))];}else result=[f.observation(Number(f.refreshes.get(f.refreshKey())?.nextIndex??0n))];return coder.encode(work.outputs,result);}
  if(workers.some(w=>w.address===to))throw Error('Wrong exact nominal worker target/selector');
  let iface;if(to===coords.bundle)iface=host;else if(to===base.witness.address){if(f.companionDead)throw callError();iface=witnessHost;}else if(to===deps.targets[3])iface=envNative;else if(to===deps.targets[4])iface=envExternal;else return baseProvider.call(tx);
  const q=iface.parseTransaction({data:tx.data});if(!q)throw Error('Unknown exact host method');const call={...tx,name:q.name,args:q.args};f.calls.push(call);const override=await f.hook?.(call);if(override?.raw)return override.raw;if(override)return iface.encodeFunctionResult(q.fragment,override);let result;
  if(to===base.witness.address){if(q.name!=='revocationEpoch')throw Error('Unexpected companion read');result=[f.epoch];}
  else if(to===deps.targets[3]){assert.equal(q.name,'currentArtifactEnvironment');assert.equal(tx.gasLimit,deps.archiveGas);result=[f.onchainHash,f.validationEpoch];}
  else if(to===deps.targets[4]){assert.equal(q.name,'currentExternalArtifactEnvironment');assert.equal(tx.gasLimit,deps.archiveGas);result=[f.externalHash,f.healthRevision];}
  else {const getters={dependencies:deps,dependencyHash,bundleProfile:bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROFILE,core:deps.targets[0],metadataHost:deps.targets[1],renderCriticalInventory:deps.targets[2],artifactCoverage:deps.targets[3],externalCoverage:deps.targets[4],coreCodeHash:deps.codeHashes[0],metadataCodeHash:deps.codeHashes[1],inventoryCodeHash:deps.codeHashes[2],deploymentChainId:1n};
   if(Object.hasOwn(getters,q.name))result=[getters[q.name]];else if(q.name==='progress')result=[after?f.after:f.before];else if(q.name==='bundleEvidence')result=[after?f.afterEvidence??f.evidence:f.evidence];else if(q.name==='refresh')result=[(after?f.afterRefreshes??f.refreshes:f.refreshes).get(q.args[0])??emptyRefresh()];
   else if(q.name==='admittedItem'){const r=(after?f.afterAdmissions??f.admissions:f.admissions)[Number(q.args[1])];result=[r.item,r.admission];}else if(q.name==='retrievalWitnessForItem')result=[(after?f.afterAdmissions??f.admissions:f.admissions)[Number(q.args[1])]?.witnessHash??Z];
   else if(q.name==='requireCoverage'){assert.equal(q.args[2],base.evidence.inventory.renderCriticalEvidenceHash);assert.notEqual(q.args[2],f.evidence.coverage.bundleCoverageHash);if(!f.refreshes.get(f.refreshKey())?.complete)throw callError();result=[f.evidence];}
   else if(q.name==='requireFullCurrentCoverage'){if(f.currentFailure)throw callError();result=[f.evidence];}
   else if(methods.includes(q.name)){if(f.callFailure)throw f.callFailure;if(f.currentFailure)throw callError();result=q.name==='beginRefresh'?[f.refreshKey()]:[];}else throw Error('Unexpected bundle method '+q.name);}
  return iface.encodeFunctionResult(q.fragment,result);}};
 f.mine=(capture,transport='direct')=>{const q=capture.prepared.request,s=capture.stage,logs=[],emit=(suffix,args)=>logs.push({address:coords.bundle,...host.encodeEventLog('ViewPreservationBundle'+suffix,args)});f.after=copy(s.after);f.afterAdmissions=copy(s.admissions);if(s.admitted)f.afterAdmissions.push(copy(s.admitted));f.afterEvidence=s.evidence;f.afterRefreshes=new Map(f.refreshes);
  if(q.method==='beginCoverage'&&!s.existing)emit('CoverageStarted',[1n,f.planId,base.evidence.inventory.renderCriticalEvidenceHash]);
  if(s.admitted)emit('ItemAdmitted',[1n,f.planId,s.before.itemCount,inv[ip+'ItemHash'](s.admitted.item),s.admitted.admission]);
  if(!s.before.complete&&s.after.complete)emit('CoverageCompleted',[1n,f.planId,s.evidence.coverage.bundleCoverageHash,s.evidence]);
  if(s.refreshId){if(s.refreshAfter)f.afterRefreshes.set(s.refreshId,copy(s.refreshAfter));else f.afterRefreshes.set(s.refreshId,{environmentHash:s.environment,nextIndex:s.after.itemCount,currentObservationChain:H('opaque-original-private-chain'),complete:true});}
  if(q.method==='refreshNext')emit('RefreshAdvanced',[1n,f.planId,s.refreshId,s.refreshAfter.nextIndex,s.refreshAfter.currentObservationChain,s.refreshAfter.complete]);
  return makeTransaction(f,capture,logs,transport);};
 return f;
}
