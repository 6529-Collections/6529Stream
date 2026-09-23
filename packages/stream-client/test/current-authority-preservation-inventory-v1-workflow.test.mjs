import test from 'node:test';
import assert from 'node:assert/strict';
import { id, keccak256 } from 'ethers';
import { setup, methods, progress, item, definitionItem, inv,w,A,H,Z,ZA,safe,coder,empty,prefix } from './current-authority-preservation-inventory-v1-workflow-fixture.mjs';
import * as io from '../dist/current-scoped-policy-inventory-archive-workflow-internal.js';
const copy=structuredClone;
const reconcile=(f,cap,tx)=>w.reconcileCurrentAuthorityPreservationInventoryV1Receipt(f.provider,cap,tx.hash,tx.options);
const history=(f,tag=90)=>w.inspectCurrentAuthorityPreservationInventoryV1History(f.provider,f.hd,f.planId,{blockTag:tag,segments:f.options().segments});
const current=(f,full=false)=>w.inspectCurrentAuthorityPreservationInventoryV1Current(f.provider,f.d,f.scope,{...f.options(),fullDefinitionBytes:full});
const simulate=(f,cap)=>w.simulateCurrentAuthorityPreservationInventoryV1(f.provider,cap,{blockTag:91,gasLimit:f.gasLimit});
const optionsFor=(scopeKind,method)=>({scopeKind,waiver:method==='appendIntentWaiver',interviewWaiver:method==='appendInterviewWaiver'});
function replaceLog(f,hash,index,suffix,args){const old=f.state.receipts.get(hash).logs[index];Object.assign(old,f.emit(suffix,args));}

for(const scopeKind of ['collection','scoped'])test(`${scopeKind}: all nineteen original stage captures and direct receipts`,async()=>{
 for(const method of methods(scopeKind)){const f=setup(optionsFor(scopeKind,method)),q=f.prepare(method),cap=await f.captureCall(q);assert.equal(cap.prepared.caller,f.caller);assert.equal(cap.prepared.call.value,0n);assert.equal(cap.stage.selection.selection.selectionHash,f.selection.selectionHash);const tx=f.mine(cap),out=await reconcile(f,cap,tx);assert.equal(out.planId,f.planId);assert.equal(out.precedingAndEndBlockAttribution,true);assert.equal(out.currentAfterReceipt,false);assert.equal(out.privateCatalogFactsIndependentlyReconstructed,false);
  if(cap.stage.appended){assert.ok(out.appended.items.length>0);assert.equal(out.segmentLocator.transactionHash,tx.hash);assert.deepEqual(out.appended.items,cap.stage.appended.items);}
  if(method==='appendOriginRuntime'){assert.equal(out.appended.items.length,10);assert.ok(out.appended.items.every(row=>row.kind===1n&&row.byteSize>0n));}
  if(method==='sealInventory')assert.notEqual(out.origins.setHash,Z);
 }
});

for(const transport of ['legacy','indexed'])test(`${transport} Safe CALL: begin, original authorization, row append and seal in both families`,async()=>{
 for(const scopeKind of ['collection','scoped'])for(const method of ['beginInventory','appendRootAuthorization','appendTokenPreservation','sealInventory']){const f=setup({scopeKind}),q=f.prepare(method),cap=await f.captureCall(q),tx=f.mine(cap,transport);assert.equal((await reconcile(f,cap,tx)).planId,f.planId);}
});

test('actual caller original simulation is decisive; worker success does not establish private admission',async()=>{
 const f=setup(),q=f.prepare('appendWork'),cap=await f.captureCall(q),sim=await simulate(f,cap);assert.equal(sim.originalCallSucceeded,true);assert.equal(sim.stateChangesPersisted,false);const originalCalls=f.state.calls.filter(tx=>tx.to===f.coords.inventory&&tx.data===cap.prepared.call.data);assert.ok(originalCalls.length>=3);assert.ok(originalCalls.every(tx=>tx.from===f.caller));
 const error=Object.assign(Error('original Archive/JSON/catalog admission refused'),{code:'CALL_EXCEPTION'});f.state.hostResult=(name,args,values,tx)=>{if(name==='appendWork'&&tx.blockTag===91)throw error;};await assert.rejects(simulate(f,cap),e=>e===error);
});

test('legacy Work requires actor zero/native-zero witness; attested Work records the selected original occurrence',async()=>{
 for(const scopeKind of ['collection','scoped']){const f=setup({scopeKind}),q=f.prepare('appendWork'),cap=await f.captureCall(q);assert.equal(cap.stage.originsAfter.records.length,0);assert.ok(!f.state.calls.some(tx=>tx.to===f.od.worker));
  for(const wrong of [{...q,originalActor:f.caller},{...q,receipt:{lane:1n,index:0n}},{...q,receipt:{lane:0n,index:1n}}])await assert.rejects(f.captureCall(wrong),/Unattested|Legacy/);
  const g=setup({scopeKind,attested:true,imported:true,newOrigin:true}),request=g.prepare('appendWork'),saved=await g.captureCall(request);assert.equal(saved.stage.originsAfter.records.length,1);assert.equal(saved.stage.originsAfter.origins.length,2);const original=saved.stage.originsAfter.records[0].original;assert.equal(original.actor,g.caller);assert.equal(original.occurrence.receipt.operation,24n);assert.equal(original.occurrence.position.point.ownerIndex,4n);const tx=g.mine(saved,'indexed');assert.equal((await reconcile(g,saved,tx)).origins.records.length,1);await assert.rejects(g.captureCall({...request,originalActor:ZA}),/actor/i);
 }
});

test('current resolver commitments substitute Artist pins while immutable history needs no current resolver',async()=>{
 const f=setup({distinctPresented:true}),q=f.prepare('appendRights'),cap=await f.captureCall(q);assert.notDeepEqual(cap.stage.originalAnchor.artistTargets,cap.stage.selection.dependencies.artistTargets);assert.equal(cap.stage.originsBefore.origins.length,2);f.state.hooks.code=address=>address===f.ad.resolver||address===f.current.environment.registry?'0x':undefined;
 const retained=await history(f);assert.equal(retained.currentAuthorityChecked,false);assert.equal(retained.currentSourceChecked,false);assert.equal(retained.selectionCommitmentRecomputed,false);assert.equal(retained.privateCatalogFactsIndependentlyReconstructed,false);assert.equal(retained.selection.selection.selectionHash,cap.stage.selection.selection.selectionHash);await assert.rejects(f.captureCall(q),/runtime/i);
});

test('resolver anchors, actual selected capture and origin runtime mismatches refuse live capture',async()=>{
 for(const fault of ['anchor','selected','origin','profile']){const f=setup(),q=f.prepare();f.state.hostResult=(name,args,values)=>{if(fault==='anchor'&&name==='anchors')return[{...values[0],targets:[A(999),...values[0].targets.slice(1)]}];if(fault==='selected'&&name==='currentSelection')return[{...values[0],selectionHash:H(999)}];if(fault==='profile'&&name==='originProfile')return[inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_PROFILE];};if(fault==='origin')f.state.hooks.code=address=>address===f.current.environment.owners[0]?'0x6000':undefined;await assert.rejects(f.captureCall(q),/differ|commitment|runtime|profile/i);}
});

test('all fixed definitions retain source order; collection typed catalogs and scoped observations differ honestly',async()=>{
 for(const scopeKind of ['collection','scoped']){const f=setup({scopeKind,definitionIndex:30}),q=f.prepare('appendDefinition'),cap=await f.captureCall(q);assert.equal(progress(cap.stage.after).completedStages,8n);assert.equal(cap.stage.appended.items[0].catalogId,inv[prefix+'Definition'](scopeKind,30n).id);assert.equal(cap.stage.segments.slice(7).length,30);assert.deepEqual(cap.stage.segments.slice(7).map(v=>v.items[0].catalogId),Array.from({length:30},(_,i)=>inv[prefix+'Definition'](scopeKind,BigInt(i)).id));
  const g=setup({scopeKind,catalog:true}),request=g.prepare('appendRights'),saved=await g.captureCall(request);assert.equal(saved.stage.documents.length,scopeKind==='collection'?1:0);assert.ok(saved.stage.appended.items.some(v=>v.kind===3n));
 }
 const f=setup(),q=f.prepare('appendDefinition');f.state.workerResult=(worker,args,values)=>worker.key==='definition'?[H(999),values[1]]:values;await assert.rejects(f.captureCall(q),/definition ID/);
});

test('token cursor, preservation row count and explicit origin runtime progression are distinct',async()=>{
 for(const scopeKind of ['collection','scoped']){const f=setup({scopeKind}),q=f.prepare('appendTokenPreservation'),cap=await f.captureCall(q);assert.equal(progress(cap.stage.after).nextToken,1n);assert.deepEqual(cap.stage.tokenAfter,{phase:0n,row:0n,count:0n});assert.ok(f.state.calls.some(tx=>tx.to===f.d.workers.preservation.address));const g=setup({scopeKind}),request=g.prepare('appendOriginRuntime'),saved=await g.captureCall(request);assert.equal(saved.stage.originsAfter.runtimeCursor,1n);assert.equal(progress(saved.stage.after).renderCriticalEvidenceHash,Z);assert.equal(saved.stage.originsAfter.setHash,Z);}
 const f=setup(),q=f.prepare('appendTokenPreservation');f.state.workerResult=(worker,args,values)=>worker.key==='preservation'?[values[0],12n]:values;await assert.rejects(f.captureCall(q),/count|row/i);
});

test('original inventory HTML limit is 40960 and permits byte strings independently of original rendering predicates',async()=>{
 const f=setup(),q=f.prepare('appendTokenOutput');const cap=await f.captureCall({...q,payload:{...q.payload,image:'0x'+'ff'.repeat(2048),animation:'0x'+'fe'.repeat(40960)}});assert.equal((cap.prepared.request.payload.animation.length-2)/2,40960);
 for(const payload of [{...q.payload,animation:'0x'+'00'.repeat(40961)},{...q.payload,image:'0x'+'00'.repeat(2049)},{...q.payload,animation:'0x'}])await assert.rejects(f.captureCall({...q,payload}),/bounds|bytes/i);
});

test('begin retry and ordinary append accept unrelated retained origin retirement; seal/current reject it',async()=>{
 for(const retry of [false,true]){const f=setup({extraOrigin:true}),append=f.prepare('appendRights'),q=retry?{kind:'beginInventory',scope:f.scope}:append,cap=await f.captureCall(q),unrelated=f.state.origins.at(-1);const tx=f.mine(cap);f.state.hooks.code=(address,tag)=>tag===100&&address===unrelated.environment.registry?'0x':undefined;assert.equal((await reconcile(f,cap,tx)).planId,f.planId);if(retry)assert.equal(f.state.receipts.get(tx.hash).logs.length,0);}
 const f=setup({extraOrigin:true}),q=f.prepare('sealInventory'),unrelated=f.state.origins.at(-1);f.state.hooks.code=address=>address===unrelated.environment.registry?'0x':undefined;await assert.rejects(f.captureCall(q),/runtime/);
 const g=setup({extraOrigin:true,completed:true});g.prepare('sealInventory');g.state.hooks.code=address=>address===g.state.origins.at(-1).environment.registry?'0x':undefined;assert.equal((await history(g)).currentAuthorityChecked,false);await assert.rejects(current(g),/runtime/);
});

test('seal and completed current evidence bind all origin rows, while append/seal have no retained retry',async()=>{
 for(const scopeKind of ['collection','scoped']){const f=setup({scopeKind,distinctPresented:true,completed:true});f.prepare('sealInventory');const out=await current(f,true);assert.equal(out.currentAuthorityChecked,true);assert.equal(out.originRuntimesChecked,true);assert.equal(out.fullDefinitionBytesChecked,true);assert.equal((await history(f)).evidence.inventory?.renderCriticalEvidenceHash??(await history(f)).evidence.renderCriticalEvidenceHash,progress(f.state.before).renderCriticalEvidenceHash);await assert.rejects(f.captureCall({kind:'sealInventory',planId:f.planId}),/sealed/);f.state.originRoot=H(999);await assert.rejects(history(f),/origin root/);}
});

test('event-sourced segment rows retain duplicates and reject copied locator, Item and chronology contradictions',async()=>{
 const f=setup(),q=f.prepare('appendRights'),cap=await f.captureCall(q);assert.deepEqual(cap.stage.segments[0].items[0],cap.stage.segments[0].items[1]);const locator=f.options().segments[0],receipt=f.state.receipts.get(locator.transactionHash);receipt.logs[0].data='0x';await assert.rejects(history(f),/event|canonical|data/i);
 const g=setup();g.prepare('appendRights');await assert.rejects(w.inspectCurrentAuthorityPreservationInventoryV1History(g.provider,g.hd,g.planId,{blockTag:90,segments:g.options().segments.slice().reverse()}),/order/);
});

test('retained source scope, Artist association and origin evidence reject self-consistent contradictory getter data',async()=>{
 for(const fault of ['scope','association','originRecord','runtimeSize']){const f=setup({extraOrigin:true});f.prepare(fault==='runtimeSize'?'sealInventory':'appendRights');f.state.hostResult=(name,args,values)=>{if(name==='sourceContext'&&(fault==='scope'||fault==='association')){const v=copy(values[0]);if(fault==='scope')v.snapshotSource.scope.collectionId+=1n;else v.conservation.association.generation+=1n;return[v];}if(name==='artistArchiveOrigin'&&fault==='originRecord')return[{...values[0],sourceContextHash:H(999)}];};if(fault==='runtimeSize'){const row=f.state.segments.find(v=>v.items[0].role===id('ARTIST_ORIGIN_REGISTRY_RUNTIME'));row.items[0].byteSize=0n;row.segment=inv[prefix+'Segment'](row.segment.key,row.segment.sourceWitnessHash,row.items);const index=f.state.segments.indexOf(row),receipt=f.state.receipts.get(row.locator.transactionHash);Object.assign(receipt.logs[0],f.emit('SegmentRecorded',[f.planId,BigInt(index),row.segment,row.items]));const p=f.plan(8n);progress(p).nextToken=f.co.tokenCount;f.state.before=p;}
  await assert.rejects(history(f),/scope|association|origin|runtime/i);
 }
});

test('mined worker, linked helper, consumed origin and current producer code are pinned',async()=>{
 for(const select of [f=>f.d.workers.source.address,f=>f.d.linkedDependencies[0].address,f=>f.current.environment.owners[0],f=>A(10900)]){const f=setup({newOrigin:true}),q=f.prepare('appendIntent'),cap=await f.captureCall(q),tx=f.mine(cap);f.state.hooks.code=(address,tag)=>tag===100&&address===select(f)?'0x6000':undefined;await assert.rejects(reconcile(f,cap,tx),/runtime/);}
});

test('receipts enforce exact schema, event occurrence and prior/end-block attribution',async()=>{
 for(const fault of ['missing','duplicate','schema','end','prior','extra']){const f=setup(),q=f.prepare('appendNative'),cap=await f.captureCall(q),tx=f.mine(cap),receipt=f.state.receipts.get(tx.hash);if(fault==='missing')receipt.logs=[];if(fault==='duplicate')receipt.logs.push({...receipt.logs[0],index:1});if(fault==='schema'){const ev=f.host.getEvent('ScopedInventorySegmentRecorded');Object.assign(receipt.logs[0],f.host.encodeEventLog(ev,[2n,f.planId,0n,cap.stage.appended.segment,cap.stage.appended.items]));}if(fault==='extra')receipt.logs.push({...f.emit('Started',[f.planId,f.scope,f.sourceContextHash]),...receipt.logs[0],topics:f.emit('Started',[f.planId,f.scope,f.sourceContextHash]).topics,data:f.emit('Started',[f.planId,f.scope,f.sourceContextHash]).data,index:1});if(fault==='end')progress(f.state.after).itemCount+=1n;if(fault==='prior')f.state.hostResult=(name,args,values,call)=>name==='plan'&&call.blockTag===99?[{...values[0],progress:{...values[0].progress,nextToken:1n}}]:values;await assert.rejects(reconcile(f,cap,tx));}
});

test('direct and both Safe envelopes require actual caller, exact data/value/CALL and independent Safe hash',async()=>{
 for(const fault of ['caller','target','value','data','safehash','delegatecall','failure','order','removed','metadata']){const f=setup(),q=f.prepare(),cap=await f.captureCall(q),tx=f.mine(cap,['caller','target','data'].includes(fault)?'direct':'indexed'),transaction=f.state.transactions.get(tx.hash),receipt=f.state.receipts.get(tx.hash);if(fault==='caller')transaction.from=A(999);if(fault==='target')transaction.to=A(999);if(fault==='value')transaction.value=1n;if(fault==='data')transaction.data='0x12345678';if(fault==='safehash')tx.options.expectedSafeTxHash=H(999);if(fault==='delegatecall')transaction.data=safe.encodeFunctionData('execTransaction',[f.coords.inventory,0n,cap.prepared.call.data,1,0,0,0,ZA,ZA,'0x']);if(fault==='failure')Object.assign(receipt.logs[1],safe.encodeEventLog('ExecutionFailure',[H(49001),0n]));if(fault==='order')receipt.logs[0].index=2;if(fault==='removed')receipt.logs[0].removed=true;if(fault==='metadata')delete receipt.logs[0].transactionHash;await assert.rejects(reconcile(f,cap,tx));}
});

test('inputs, current options and receipt logs are copied before awaiting the provider',async()=>{
 const f=setup(),q=f.prepare(),d=copy(f.d),request=copy(q),opts=f.options();f.state.hooks.network=()=>{d.workers.source.codeHash=H(999);request.scope.collectionId=999n;opts.blockTag=999;};const cap=await w.captureCurrentAuthorityPreservationInventoryV1(f.provider,d,f.caller,request,opts);assert.equal(cap.observed.blockNumber,90);assert.equal(cap.prepared.request.scope.collectionId,f.scope.collectionId);f.state.hooks.network=null;const tx=f.mine(cap,'indexed');let changed=false;f.state.hooks.block=()=>{if(!changed){changed=true;f.state.receipts.get(tx.hash).logs[0].data='0x';}};assert.equal((await reconcile(f,cap,tx)).planId,f.planId);
 const g=setup({completed:true});g.prepare('sealInventory');const options={...g.options(),fullDefinitionBytes:true};g.state.hooks.network=()=>{options.blockTag=999;options.fullDefinitionBytes=false;};const out=await w.inspectCurrentAuthorityPreservationInventoryV1Current(g.provider,g.d,g.scope,options);assert.equal(out.capture.observed.blockNumber,90);assert.equal(out.fullDefinitionBytesChecked,true);assert.ok(g.state.calls.every(v=>v.blockTag===90));
});

test('canonical RPC, reorg, saved plan substitutions and finite transport bounds refuse',async()=>{
 const f=setup(),q=f.prepare(),cap=await f.captureCall(q);f.state.raw=(name,raw)=>name==='dependencies'?raw+'00'.repeat(32):raw;await assert.rejects(f.captureCall(q),/canonical/);f.state.raw=null;f.state.blockHashes.set(90,H(999));await assert.rejects(simulate(f,cap),/block/);f.state.blockHashes.clear();const tampered=copy(cap);tampered.prepared.call.data='0x12345678';const{captureHash,...body}=tampered;tampered.captureHash=io.fingerprint(body);await assert.rejects(simulate(f,tampered),/differ|call/i);
 const tx=f.mine(cap);f.state.transactions.get(tx.hash).data='0x'+'00'.repeat(io.MAX_CALL+16385);await assert.rejects(reconcile(f,cap,tx),/oversized/);await assert.rejects(w.captureCurrentAuthorityPreservationInventoryV1(f.provider,{...f.d,linkedDependencies:Array.from({length:257},()=>f.d.linkedDependencies[0])},f.caller,q,f.options()),/limit/);
});

test('refusal preserves RPC versus execution errors without claiming atomic rollback',async()=>{
 const f=setup(),q=f.prepare(),cap=await f.captureCall(q);for(const execution of [true,false]){const error=Object.assign(Error('Original refusal'),{code:execution?'CALL_EXCEPTION':'NETWORK_ERROR'});f.state.hostResult=(name,args,values,tx)=>{if(name==='beginInventory'&&tx.blockTag===91)throw error;return values;};const out=await w.observeCurrentAuthorityPreservationInventoryV1Refusal(f.provider,cap,{blockTag:91,gasLimit:f.gasLimit});assert.equal(out.error,error);assert.equal(out.outcome,execution?'execution-reverted':'rpc-failed');assert.equal(out.retainedStateUnchanged,true);assert.equal(out.rollbackProven,false);}f.state.hostResult=null;await assert.rejects(w.observeCurrentAuthorityPreservationInventoryV1Refusal(f.provider,cap,{blockTag:91,gasLimit:f.gasLimit}),/did not refuse/);
});
