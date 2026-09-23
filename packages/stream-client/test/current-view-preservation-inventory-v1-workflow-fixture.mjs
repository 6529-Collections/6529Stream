// Compiler-encoded RPC consistency fixtures. Original Source/Binding workers, stage admission,
// byte correspondence and EVM/Safe execution are mocked. Compact prefixes are retained-history
// witnesses for client joins, not demonstrations of a native sixteen-stage producer lifecycle.
import assert from 'node:assert/strict';
import { AbiCoder,Interface,ParamType,getAddress,id,keccak256 } from 'ethers';
import * as inv from '../dist/current-view-preservation-inventory-v1.js';
import * as workflow from '../dist/current-view-preservation-inventory-v1-workflow.js';
import { fixture,compiledInterfaces as c } from './current-view-preservation-consumers-v1-fixture.mjs';
export { inv,workflow,fixture,c };
export const coder=AbiCoder.defaultAbiCoder(),copy=structuredClone,Z='0x'+'00'.repeat(32),ZA='0x'+'00'.repeat(20);
export const A=n=>getAddress('0x'+BigInt(n).toString(16).padStart(40,'0')),H=n=>id(String(n));
export const safe=new Interface(['function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)','event ExecutionSuccess(bytes32 txHash,uint256 payment)','event ExecutionFailure(bytes32 txHash,uint256 payment)']);
export const indexedSafe=new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']);
export function zero(t){t=typeof t==='string'?ParamType.from(t):t;if(t.baseType==='tuple')return Object.fromEntries(t.components.map(p=>[p.name,zero(p)]));if(t.baseType==='array')return Array.from({length:Math.max(0,t.arrayLength)},()=>zero(t.arrayChildren));if(t.type==='address')return ZA;if(t.type==='bool')return false;if(t.type==='string')return '';if(t.type.startsWith('bytes'))return '0x'+'00'.repeat(Number(t.type.slice(5))||0);return 0n;}
export function plain(t,v){if(t.baseType==='tuple')return Object.fromEntries(t.components.map((p,i)=>[p.name,plain(p,v[i])]));if(t.baseType==='array')return Array.from(v,x=>plain(t.arrayChildren,x));return v;}
function wire(p){const suffix=p.type.slice(p.type.indexOf('[')<0?p.type.length:p.type.indexOf('['));return p.components?`(${p.components.map(x=>`${wire(x)} ${x.name}`).join(',')})${suffix}`:/^(address|bool|string|bytes\d*|u?int\d*)(\[.*\])?$/.test(p.type)?p.type:`uint8${suffix}`;}
export function workerABI(contract,method){const row=fixture.libraryAbis[contract].find(x=>x.type==='function'&&x.name===method),entries=Object.entries(fixture.libraryMethodIdentifiers[contract]).filter(([s])=>s.startsWith(method+'('));assert.equal(entries.length,1);return{contract,method,selector:'0x'+entries[0][1],inputs:row.inputs.map(wire),outputs:row.outputs.map(wire)};}
export const host=c.StreamViewPreservationRenderCriticalInventoryV1,ip='currentViewPreservationInventoryV1';
export const methods=['beginInventory','appendNative','appendReference','appendWork','appendRights','appendIntent','appendIntentWaiver','appendInterview','appendInterviewWaiver','appendRootAuthorization','appendDefinition','appendArtwork','appendRenderer','appendPreservationAdmission','appendTokenOutput','sealInventory'];
export const item=(n,changes={})=>({...zero(inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE),kind:2n,role:H('role-'+n),source:A(100),sourceRecord:H('record-'+n),algorithm:1n,canonicalizationId:id('RAW_BYTES'),digest:H('bytes-'+n),byteSize:3n,...changes});
export const callError=()=>Object.assign(new Error('Mock original execution reverted'),{code:'CALL_EXCEPTION',data:'0x12345678'});
export function setup(options={}){
 const code=new Map(),pin=address=>{if(!code.has(address))code.set(address,'0x60016000');return{address,codeHash:keccak256(code.get(address))};};
 const coords={chainId:1n,core:A(100),inventory:A(500)};
 const d={chainId:1n,core:coords.core,inventory:pin(coords.inventory),sourceReader:pin(A(501)),retrievalBindingReader:pin(A(502)),linkedDependencies:[pin(A(503))]},hd={chainId:1n,core:coords.core,inventory:d.inventory};
 const targets=Array.from({length:12},(_,i)=>A(100+i)),artistTargets=Array.from({length:5},(_,i)=>A(200+i));
 const deps={targets,codeHashes:targets.map(a=>pin(a).codeHash),artistTargets,artistCodeHashes:artistTargets.map(a=>pin(a).codeHash),artistContentOwner:A(210),artistContentOwnerCodeHash:pin(A(210)).codeHash,chainId:1n,readGas:500000n,sourceGas:2000000n,selectionGas:1000000n,snapshotGas:2000000n,referenceGas:2000000n};
 const dependencyHash=inv[ip+'DependencyHash'](deps),scope={scopeType:4n,collectionId:7n,tokenId:0n,scopeId:H('view-scope')};
 const context=zero(inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONTEXT_TUPLE),subject=inv[ip+'ScopeSubject'](coords,scope);
 Object.assign(context,{scope,subject,artistId:H('artist'),tokenCount:options.tokenCount??1n});
 for(const name of ['nativeHash','rootRecordHash','tokenInventoryHash','checkpointHash','outputManifestRecord','adoptionRecord','viewId','payloadHash','sourceContextHash','policyChainHash','outputRoot','manifestIndexHash','interviewEvidenceHash'])context[name]=H(name);
 Object.assign(context.snapshot,{recordHash:H('snapshot'),scopeSubject:subject,revision:1n});Object.assign(context.referenceRender,{scopeSubject:subject});Object.assign(context.referenceRender.observation,{recordHash:H('reference'),payloadHash:H('reference-payload'),collectionId:scope.collectionId,snapshotRecordHash:context.snapshot.recordHash,snapshotRevision:1n});
 Object.assign(context.descriptions,{scopeSubject:subject,workDescriptionRecordHash:H('work'),workPayloadHash:H('work-payload'),workSelectionHash:H('work-selected'),rightsStatementRecordHash:H('rights'),rightsPayloadHash:H('rights-payload'),rightsSelectionHash:H('rights-selected')});
 Object.assign(context.conservation.association,{artistId:context.artistId});Object.assign(context.conservation.record,{kind:options.waiver?1n:0n,recordHash:H('intent'),payloadHash:H('intent-bytes')});Object.assign(context.conservation,{interviewStatus:options.interviewWaiver?1n:0n,selectionHash:H('conservation')});if(!options.interviewWaiver)context.conservation.interview.recordHash=H('interview');
 const witness=pin(A(600)),configuration={core:deps.targets[0],coreCodeHash:deps.codeHashes[0],router:deps.targets[4],routerCodeHash:deps.codeHashes[4],checkpoint:A(601),checkpointCodeHash:pin(A(601)).codeHash,archive:deps.targets[11],archiveCodeHash:deps.codeHashes[11],chainId:1n,readGas:500000n,sourceGas:1000000n,archiveGas:1000000n,signatureGas:500000n};
 const f={d,hd,coords,deps,dependencyHash,scope,context,witness,configuration,code,caller:A(0xabcd),before:zero(inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PLAN_TUPLE),tokenBefore:zero(inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_TOKEN_PROGRESS_TUPLE),after:null,tokenAfter:null,evidence:null,afterEvidence:null,segments:[],transactions:new Map(),receipts:new Map(),calls:[],hook:null,codeHook:null,networkHook:null,blockHook:null,chainId:1n,currentFailure:false,callFailure:null};
 Object.defineProperty(f,'planId',{get:()=>inv[ip+'PlanId'](coords,dependencyHash,context)});
 const block=n=>({number:n,hash:H('block-'+n),timestamp:1000+n});
 f.pin=pin;f.block=block;f.evidenceFor=plan=>inv[ip+'Evidence'](coords,dependencyHash,context,plan.progress);
 f.plan=(stage=0n)=>{const p=zero(inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PLAN_TUPLE);p.scope=copy(scope);Object.assign(p.progress,{collectionId:scope.collectionId,subject:context.subject,artistId:context.artistId,sourceContextHash:inv[ip+'ContextHash'](context),tokenCount:context.tokenCount,completedStages:stage});if(stage>0n){p.nativeCount=1n;p.nativeCursor=1n;}if(stage>1n){p.referenceCount=1n;p.referenceCursor=1n;}for(const s of f.segments){p.progress.segmentChainHash=inv[ip+'AppendSegment'](p.progress.segmentChainHash,s.index,s.segment);p.progress.segmentCount++;p.progress.itemCount+=s.segment.itemCount;}return p;};
 f.addSegment=(items,witnessHash=H('prefix'),logIndex=100+f.segments.length)=>{const index=BigInt(f.segments.length),segment=inv[ip+'Segment'](inv[ip+'SegmentKey'](f.planId,index),witnessHash,items),hash=H('segment-'+index),b=block(5),data=host.encodeFunctionData('appendArtwork',[f.planId]);
   const log={address:coords.inventory,...host.encodeEventLog('ViewPreservationInventorySegmentRecorded',[1n,f.planId,index,segment,items]),index:logIndex,transactionHash:hash,blockNumber:5,blockHash:b.hash,removed:false};
   f.receipts.set(hash,{status:1,hash,from:f.caller,to:coords.inventory,blockNumber:5,blockHash:b.hash,logs:[log]});f.transactions.set(hash,{hash,from:f.caller,to:coords.inventory,blockNumber:5,blockHash:b.hash,chainId:1n,value:0n,data});
   const row={index,segment,items:copy(items),locator:{transactionHash:hash,logIndex},recorded:{blockNumber:5,blockHash:b.hash,timestamp:1005n}};f.segments.push(row);return row;};
 f.opts=()=>({blockTag:10,gasLimit:12000000n,segments:f.segments.map(s=>s.locator)});
 f.request=(method)=>{let q={method,id:f.planId};if(method==='beginInventory')return{method,scope:copy(scope)};
   const stages={appendNative:0n,appendReference:1n,appendWork:2n,appendRights:3n,appendIntent:4n,appendIntentWaiver:4n,appendInterview:5n,appendInterviewWaiver:5n,appendRootAuthorization:6n,appendDefinition:7n,appendArtwork:8n,appendRenderer:9n,appendPreservationAdmission:10n,appendTokenOutput:11n,sealInventory:11n};
   if(method==='appendIntentWaiver')context.conservation.record.kind=1n;if(method==='appendInterviewWaiver'){context.conservation.interviewStatus=1n;context.conservation.interview.recordHash=Z;}
   if(method!=='appendNative'&&!f.segments.length)f.addSegment([item(0)],method==='appendDefinition'?context.rootRecordHash:H('prefix'));
   f.before=f.plan(stages[method]);if(method==='sealInventory')f.before.progress.nextToken=context.tokenCount;
   if(method==='appendNative'||method==='appendReference')q.maximum=2n;
   const witnesses={appendWork:'DESCRIPTION',appendRights:'STATEMENT',appendIntent:'INTENT',appendIntentWaiver:'INTENT_WAIVER',appendInterview:'INTERVIEW'};
   if(witnesses[method]){q.witness=zero(inv['CURRENT_VIEW_PRESERVATION_INVENTORY_V1_'+witnesses[method]+'_TUPLE']);if(method!=='appendRights')q.originalActor=method==='appendWork'?ZA:A(700);}
   if(method==='appendRootAuthorization')Object.assign(q,{actor:A(700),observedAt:1n,originalAggregate:{revision:1n,transitionChain:H('historical-aggregate')},originalLegacyFamilyHash:H('legacy-family')});q.id=f.planId;return q;};
 const source=workerABI('StreamViewPreservationRenderCriticalSourceReadsV1','current'),binding=workerABI('StreamViewRetrievalBindingV1','requireInventory');
 function result(method,args,tag){const after=tag>=12&&f.after!==null,plan=after?f.after:f.before,token=after?f.tokenAfter:f.tokenBefore;
  const getters={dependencies:deps,dependencyHash,inventoryProfile:inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PROFILE,core:deps.targets[0],metadataHost:deps.targets[1],metadataRouter:deps.targets[4],snapshots:deps.targets[5],referencePublisher:deps.targets[6],artifactCoverage:deps.targets[10],externalCoverage:deps.targets[11]};if(Object.hasOwn(getters,method))return[getters[method]];
  if(method==='supportsInterface')return[['0x01ffc9a7','0xb8957a7d','0xb3df912c'].includes(args[0])];if(method==='retrievalWitnessBinding')return[witness.address,witness.codeHash];
  if(method==='plan')return[plan];if(method==='tokenProgress')return[token];if(method==='sourceContext')return[context];
  if(method==='inventorySegment'){const rows=after&&f.appended?[...f.segments,f.appended]:f.segments;return[rows[Number(args[1])].segment];}
  if(method==='inventoryEvidence')return[after?f.afterEvidence??f.evidence:f.evidence];
  if(method==='requireCurrent'){if(f.currentFailure)throw callError();return[f.evidence];}if(method==='requireFullDefinitionBytes'){if(f.currentFailure)throw callError();return[];}
  if(methods.includes(method)){if(f.callFailure)throw f.callFailure;if(f.currentFailure)throw callError();if(method==='beginInventory')return[f.planId];if(method==='sealInventory')return[f.evidenceFor(f.before)];return[];}
  throw Error('Unexpected inventory method '+method);
 }
 f.provider={async getNetwork(){f.networkHook?.();return{chainId:f.chainId};},async getBlock(n){return f.blockHook?.(n)??block(n);},async getCode(a,tag){return f.codeHook?.(getAddress(a),tag)??code.get(getAddress(a))??'0x';},async getTransaction(h){return f.transactions.get(h)??null;},async getTransactionReceipt(h){return f.receipts.get(h)??null;},async call(tx){const target=getAddress(tx.to),tag=tx.blockTag;
  const worker=target===d.sourceReader.address?source:target===d.retrievalBindingReader.address?binding:null;
  if(worker){if(tx.data.slice(0,10)!==worker.selector)throw Error('Wrong nominal worker selector/target');const args=coder.decode(worker.inputs,'0x'+tx.data.slice(10));f.calls.push({...tx,name:worker.method,worker:worker.contract,args});const override=await f.hook?.(f.calls.at(-1));if(override?.raw)return override.raw;if(f.currentFailure)throw callError();return coder.encode(worker.outputs,override??(worker===source?[context]:[witness.address,witness.codeHash,configuration]));}
  if(target!==coords.inventory)throw Error('Unexpected mock target');const q=host.parseTransaction({data:tx.data});if(!q)throw Error('Unknown original selector');f.calls.push({...tx,name:q.name,args:q.args});const override=await f.hook?.(f.calls.at(-1));if(override?.raw)return override.raw;return host.encodeFunctionResult(q.fragment,override??result(q.name,q.args,tag));}};
 f.mine=(capture,transport='direct')=>{const q=capture.prepared.request,s=capture.stage,p=copy(s.before),token=copy(s.tokenBefore);let appended=null,evidence=s.evidence,rows=[],witnessHash=H('witness'),logs=[];
  const emit=(name,args)=>logs.push({address:coords.inventory,...host.encodeEventLog(name,args)});
  if(q.method==='beginInventory'){if(!s.existing){Object.assign(p,f.plan());emit('ViewPreservationInventoryStarted',[1n,f.planId,context.scope,inv[ip+'ContextHash'](context)]);}}
  else if(q.method==='sealInventory'){evidence=f.evidenceFor(p);p.progress.renderCriticalEvidenceHash=evidence.inventory.renderCriticalEvidenceHash;emit('ViewPreservationInventoryCompleted',[1n,f.planId,evidence.inventory.renderCriticalEvidenceHash,evidence]);}
  else {rows=[item(1)];const stage=p.progress.completedStages;
   if(q.method==='appendNative'||q.method==='appendReference'){const native=q.method==='appendNative',cursor=native?p.nativeCursor:p.referenceCursor,total=options.pageTotal??2n;rows=Array.from({length:Number(total-cursor<q.maximum?total-cursor:q.maximum)},(_,i)=>item(i+1));witnessHash=keccak256(coder.encode(['bytes32','uint64','uint64'],[native?p.progress.sourceContextHash:context.referenceRender.observation.payloadHash,cursor,total]));if(native){p.nativeCount=total;p.nativeCursor+=BigInt(rows.length);}else{p.referenceCount=total;p.referenceCursor+=BigInt(rows.length);}if(cursor+BigInt(rows.length)===total)p.progress.completedStages++;}
   else if(q.method==='appendDefinition'){const def=inv[ip+'Definition'](0n);rows=[item(1,{kind:3n,catalogId:def.id,catalogHash:def.hash,provenanceHash:H('document-facts')})];witnessHash=keccak256(coder.encode(['bytes32',inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE],[def.id,rows[0]]));}
   else if(stage>=8n){let index=0n,count=BigInt(rows.length);if(q.method==='appendRenderer'||q.method==='appendPreservationAdmission'){index=token.row;count=options.rowCount??2n;token.count=count;token.row++;if(token.row===count){token.row=0n;token.count=0n;p.progress.completedStages++;}}
    else if(q.method==='appendTokenOutput'){index=p.progress.nextToken;p.progress.nextToken++;}else p.progress.completedStages=9n;witnessHash=inv[ip+'TokenWitness'](context,stage,index,count);}
   else {witnessHash=q.method==='appendWork'?context.descriptions.workSelectionHash:q.method==='appendRights'?context.descriptions.rightsSelectionHash:q.method==='appendIntent'||q.method==='appendIntentWaiver'?context.conservation.selectionHash:q.method==='appendRootAuthorization'?context.rootRecordHash:context.interviewEvidenceHash;p.progress.completedStages++;}
   const index=p.progress.segmentCount,segment=inv[ip+'Segment'](inv[ip+'SegmentKey'](f.planId,index),witnessHash,rows);p.progress.segmentChainHash=inv[ip+'AppendSegment'](p.progress.segmentChainHash,index,segment);p.progress.segmentCount++;p.progress.itemCount+=BigInt(rows.length);appended={index,segment,items:rows};emit('ViewPreservationInventorySegmentRecorded',[1n,f.planId,index,segment,rows]);
  }
  f.after=p;f.tokenAfter=token;f.afterEvidence=evidence;f.appended=appended;const tx=makeTransaction(f,capture,logs,transport);return{...tx,plan:p,token,appended,evidence};
 };
 return f;
}
export function makeTransaction(f,capture,logs,transport='direct',target=capture.prepared.call.to){const hash=H('submitted'),b=f.block(12);let from=capture.prepared.caller,to=target,data=capture.prepared.call.data,expectedSafeTxHash=null;
 if(transport!=='direct'){expectedSafeTxHash=H('safe-hash');to=capture.prepared.caller;from=A(999);data=safe.encodeFunctionData('execTransaction',[target,0n,data,0n,0n,0n,0n,ZA,ZA,'0x1234']);logs.push({address:to,...(transport==='indexed'?indexedSafe:safe).encodeEventLog('ExecutionSuccess',[expectedSafeTxHash,0n])});}
 const receipt={status:1,hash,from,to,blockNumber:12,blockHash:b.hash,logs:logs.map((l,index)=>({...l,index,transactionHash:hash,blockNumber:12,blockHash:b.hash,removed:false}))};
 f.receipts.set(hash,receipt);f.transactions.set(hash,{hash,from,to,data,value:0n,chainId:1n,blockNumber:12,blockHash:b.hash});return{hash,receipt,transaction:f.transactions.get(hash),options:transport==='direct'?{execution:'direct'}:{execution:'safe',expectedSafeTxHash}};}
