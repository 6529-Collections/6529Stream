import test from 'node:test';
import assert from 'node:assert/strict';
import { id,keccak256 } from 'ethers';
import { setup,inv,workflow as w,methods,copy,A,H,Z,ZA,host,item,coder,zero,makeTransaction } from './current-view-preservation-inventory-v1-workflow-fixture.mjs';
const capture=(f,q)=>w.captureCurrentViewPreservationInventoryV1(f.provider,f.d,f.caller,q,f.opts());
const reconcile=(f,c,tx)=>w.reconcileCurrentViewPreservationInventoryV1Receipt(f.provider,c,tx.hash,tx.options);
const history=f=>w.inspectCurrentViewPreservationInventoryV1History(f.provider,f.hd,f.planId,{blockTag:10,segments:f.opts().segments});
// Each iteration is a compiler-encoded mock RPC consistency case, not actual Solidity/Safe execution.
test('all sixteen original inventory writes reconcile direct and both Safe event layouts',async()=>{
 for(const method of methods)for(const transport of ['direct','legacy','indexed']){const f=setup(),q=f.request(method),c=await capture(f,q),tx=f.mine(c,transport),r=await reconcile(f,c,tx);
  assert.equal(r.planId,f.planId);assert.equal(r.itemProductionIndependentlyReconstructed,false);assert.equal(r.intraBlockTraceProven,false);assert.equal(c.originalCallSimulated,true);}
});
test('genuine intent0 and waiver1 produce the original separate evidence coordinates',async()=>{
 for(const waiver of [false,true]){const f=setup({waiver}),q=f.request('sealInventory'),c=await capture(f,q),r=await reconcile(f,c,f.mine(c));assert.equal(r.evidence.inventory.originals.intentRecordHash,waiver?Z:f.context.conservation.record.recordHash);assert.equal(r.evidence.inventory.originals.intentWaiverRecordHash,waiver?f.context.conservation.record.recordHash:Z);}
 const f=setup(),q=f.request('appendIntent');f.context.conservation.record.kind=1n;await assert.rejects(capture(f,q));
});
test('native/reference pages and renderer/admission row cursors distinguish partial from final',async()=>{
 for(const method of ['appendNative','appendReference','appendRenderer','appendPreservationAdmission'])for(const final of [false,true]){const f=setup({pageTotal:final?2n:4n,rowCount:final?1n:2n}),q=f.request(method),c=await capture(f,q),tx=f.mine(c),r=await reconcile(f,c,tx);assert.equal(r.plan.progress.completedStages,c.stage.before.progress.completedStages+(final?1n:0n));}
});
test('begin retry is eventless but still invokes original current source; completed writes are not no-ops',async()=>{
 const f=setup();f.addSegment([item(1)]);f.before=f.plan(3n);const c=await capture(f,{method:'beginInventory',scope:f.scope}),tx=f.mine(c);assert.equal(tx.receipt.logs.length,0);await reconcile(f,c,tx);
 f.currentFailure=true;await assert.rejects(capture(f,{method:'beginInventory',scope:f.scope}));
 const g=setup(),q=g.request('sealInventory');g.evidence=g.evidenceFor(g.before);g.before.progress.renderCriticalEvidenceHash=g.evidence.inventory.renderCriticalEvidenceHash;await assert.rejects(capture(g,q),/stage/);
});
test('companion configuration is separate from dependency hash and binding getter joins exactly',async()=>{
 const f=setup(),q=f.request('appendNative');const hash=f.dependencyHash;f.hook=call=>call.name==='retrievalWitnessBinding'?[A(701),H('changed')]:undefined;await assert.rejects(capture(f,q),/Companion/);assert.equal(f.dependencyHash,hash);
 const g=setup();g.hook=call=>call.name==='supportsInterface'&&call.args[0]==='0xb8957a7d'?[false]:undefined;await assert.rejects(capture(g,g.request('appendNative')),/capability/);
});
test('history authenticates emitted occurrence/segment chains without current source or companion',async()=>{
 const f=setup();f.request('appendArtwork');f.currentFailure=true;f.code.set(f.d.sourceReader.address,'0x');f.code.set(f.witness.address,'0x');const r=await history(f);assert.equal(r.currentSourceChecked,false);assert.equal(r.itemProductionIndependentlyReconstructed,false);assert.equal(r.segments.length,1);
 assert(!f.calls.some(c=>c.name==='current'||c.name==='requireInventory'||c.name==='retrievalWitnessBinding'));
});
test('fully rehashed context mutations cannot replace immutable VIEW subjects and snapshot lineage',async()=>{
 for(const mutate of [f=>f.context.subject=H('wrong'),f=>f.context.referenceRender.observation.snapshotRecordHash=H('wrong'),f=>f.context.referenceRender.observation.collectionId++]){
  const f=setup();mutate(f);f.before=f.plan(0n);await assert.rejects(history(f),/subject|Snapshot|collection/i);
 }
});
test('local history requires every ordered unique canonical segment and bounded rows',async()=>{
 const f=setup();f.request('appendArtwork');const opts={blockTag:10,segments:[]};await assert.rejects(w.inspectCurrentViewPreservationInventoryV1History(f.provider,f.hd,f.planId,opts),/locators/);
 const loc=f.opts().segments[0];await assert.rejects(w.inspectCurrentViewPreservationInventoryV1History(f.provider,f.hd,f.planId,{blockTag:10,segments:[loc,loc]}),/Duplicate/);
 const receipt=f.receipts.get(loc.transactionHash);receipt.logs[0].data+='00';await assert.rejects(history(f),/canonical|bounds|data|buffer/i);
});
test('receipt rejects missing/extra/reordered segment events and contradictory end state',async()=>{
 for(const mutation of ['missing','extra','schema','state','witness']){const f=setup(),q=f.request('appendNative'),c=await capture(f,q),tx=f.mine(c);
  if(mutation==='missing')tx.receipt.logs=[];if(mutation==='extra')tx.receipt.logs.push({...copy(tx.receipt.logs[0]),index:1});
  if(mutation==='schema'||mutation==='witness'){const row=copy(f.appended);if(mutation==='witness')row.segment.sourceWitnessHash=H('forged');const log=host.encodeEventLog('ViewPreservationInventorySegmentRecorded',[mutation==='schema'?2n:1n,f.planId,0n,row.segment,row.items]);Object.assign(tx.receipt.logs[0],log);}
  if(mutation==='state')f.after.progress.nextToken++;await assert.rejects(reconcile(f,c,tx));
 }
});
test('Safe exact hash/caller/value/data and target-specific order remain independent',async()=>{
 for(const mutate of [tx=>tx.options.expectedSafeTxHash=H('wrong'),tx=>tx.transaction.data+='00',tx=>tx.transaction.value=1n,tx=>{tx.receipt.logs.reverse();tx.receipt.logs.forEach((l,i)=>l.index=i);}]){const f=setup(),c=await capture(f,f.request('appendNative')),tx=f.mine(c,'indexed');mutate(tx);await assert.rejects(reconcile(f,c,tx));}
 const f=setup(),c=await capture(f,f.request('appendNative')),tx=f.mine(c,'legacy');tx.receipt.logs.push({...copy(tx.receipt.logs[0]),address:A(880),index:2});await reconcile(f,c,tx);
});
test('receipts require unchanged saved/preblock facts and runtime pins at inclusion',async()=>{
 for(const changed of ['prior','link','source','sameblock']){const f=setup(),c=await capture(f,f.request('appendNative')),tx=f.mine(c);
  if(changed==='prior')f.hook=call=>call.name==='plan'&&call.blockTag===11?[{...f.before,progress:{...f.before.progress,nextToken:1n}}]:undefined;
  if(changed==='link'||changed==='source')f.codeHook=(a,t)=>t===12&&a===(changed==='link'?f.d.linkedDependencies[0].address:f.d.sourceReader.address)?'0x6002':undefined;
  if(changed==='sameblock'){tx.receipt.blockNumber=10;tx.transaction.blockNumber=10;tx.receipt.blockHash=f.block(10).hash;tx.transaction.blockHash=f.block(10).hash;for(const l of tx.receipt.logs){l.blockNumber=10;l.blockHash=f.block(10).hash;}}
  await assert.rejects(reconcile(f,c,tx));
 }
});
test('current inspector invokes original full current and optional byte diagnostic with copied options',async()=>{
 const f=setup(),q=f.request('sealInventory');f.evidence=f.evidenceFor(f.before);f.before.progress.renderCriticalEvidenceHash=f.evidence.inventory.renderCriticalEvidenceHash;
 const opts={blockTag:10,gasLimit:12000000n,segments:f.opts().segments,fullDefinitionBytes:true};f.networkHook=()=>{opts.blockTag=11;opts.fullDefinitionBytes=false;};
 const r=await w.inspectCurrentViewPreservationInventoryV1Current(f.provider,f.d,f.planId,opts);assert.equal(r.fullDefinitionBytesChecked,true);assert(f.calls.some(c=>c.name==='requireFullDefinitionBytes'));assert(f.calls.every(c=>c.blockTag===10));
});
test('captured request/deployment and receipt snapshots detach before provider awaits',async()=>{
 const f=setup(),q=f.request('appendNative'),d=copy(f.d);f.networkHook=()=>{q.maximum=9n;d.inventory.address=A(991);};const c=await w.captureCurrentViewPreservationInventoryV1(f.provider,d,f.caller,q,f.opts());assert.equal(c.prepared.request.maximum,2n);assert.equal(c.deployment.inventory.address,f.d.inventory.address);
 f.networkHook=null;const tx=f.mine(c);const old=f.provider.getTransaction;f.provider.getTransaction=async h=>{tx.receipt.logs[0].data='0x';return old(h);};await reconcile(f,c,tx);
});
test('simulation, refusal and RPC-error classification do not claim persisted rollback',async()=>{
 const f=setup(),c=await capture(f,f.request('appendNative'));const result=await w.simulateCurrentViewPreservationInventoryV1(f.provider,c,{blockTag:11});assert.equal(result.stateChangesPersisted,false);
 f.hook=call=>{if(call.blockTag===11&&call.name==='appendNative')throw Object.assign(new Error('secret-url'),{code:'CALL_EXCEPTION',data:'0x1234',info:{password:'private'}});};
 const refused=await w.observeCurrentViewPreservationInventoryV1Refusal(f.provider,c,{blockTag:11});assert.equal(refused.outcome,'execution-reverted');assert.equal(refused.submittedTransactionRollbackProven,false);assert(!JSON.stringify(refused,(_,v)=>typeof v==='bigint'?v.toString():v).includes('secret'));
 f.hook=call=>{if(call.blockTag===11&&call.name==='appendNative')throw{code:'NETWORK_ERROR',message:'secret'};};assert.equal((await w.observeCurrentViewPreservationInventoryV1Refusal(f.provider,c,{blockTag:11})).outcome,'rpc-failed');
});
test('capture tampering, reorg, chain and finite operational bounds reject before dependent work',async()=>{
 const f=setup(),c=await capture(f,f.request('appendNative')),bad=copy(c);bad.prepared.caller=A(999);await assert.rejects(w.simulateCurrentViewPreservationInventoryV1(f.provider,bad,{blockTag:11}),/fingerprint/);
 f.blockHook=n=>({...f.block(n),hash:H('reorg')});await assert.rejects(w.simulateCurrentViewPreservationInventoryV1(f.provider,c,{blockTag:11}),/changed/);
 const g=setup();g.chainId=2n;await assert.rejects(capture(g,g.request('appendNative')),/chain/i);
 await assert.rejects(w.captureCurrentViewPreservationInventoryV1(g.provider,g.d,g.caller,g.request('appendNative'),{...g.opts(),gasLimit:100000001n}),/gas/);
 await assert.rejects(w.captureCurrentViewPreservationInventoryV1(g.provider,g.d,g.caller,{method:'appendNative',id:g.planId,maximum:65n},g.opts()),/Maximum/);
});
test('sealed history rejects independently altered native/reference completion cursors',async()=>{
 for(const field of ['nativeCursor','nativeCount','referenceCursor','referenceCount']){const f=setup();f.request('sealInventory');f.evidence=f.evidenceFor(f.before);f.before.progress.renderCriticalEvidenceHash=f.evidence.inventory.renderCriticalEvidenceHash;f.before[field]=0n;if(field==='nativeCount')f.before.nativeCursor=0n;if(field==='referenceCount')f.before.referenceCursor=0n;await assert.rejects(history(f),/sealed plan/);}
});
test('history applies an incremental aggregate byte ceiling to individually bounded segment receipts',async()=>{
 const f=setup(),large='0x'+'11'.repeat(1048576);for(let i=0;i<17;i++)f.addSegment([item(i,{digest:large})]);f.before=f.plan(3n);
 // These deliberately oversized synthetic rows test client allocation refusal, not source production.
 await assert.rejects(history(f),/History byte allocation bound/);
});
