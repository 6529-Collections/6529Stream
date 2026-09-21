import test from 'node:test';
import assert from 'node:assert/strict';
import { id } from 'ethers';
import { setup,bundle,workflow as w,inv,retrieval,bp,host,methods,row,obligation,copy,A,H,Z,emptyRefresh,callError,rawCid } from './current-view-preservation-bundle-v1-workflow-fixture.mjs';
const capture=(f,q)=>w.captureCurrentViewPreservationBundleV1(f.provider,f.d,f.caller,q,f.opts());
const reconcile=(f,c,tx)=>w.reconcileCurrentViewPreservationBundleV1Receipt(f.provider,c,tx.hash,tx.options);
const history=f=>w.inspectCurrentViewPreservationBundleV1History(f.provider,f.hd,f.planId,{blockTag:10,segments:f.opts().segments});
const current=(f,fullCurrentCoverage=false)=>w.inspectCurrentViewPreservationBundleV1Current(f.provider,f.d,f.planId,{...f.opts(),fullCurrentCoverage});
// These are compiler-encoded mocked RPC and Safe-envelope checks, not native source execution.
test('all six original bundle writes reconcile direct and both Safe event layouts',async()=>{
 for(const method of methods)for(const transport of ['direct','legacy','indexed']){const f=setup(),q=f.request(method),c=await capture(f,q),tx=f.mine(c,transport),r=await reconcile(f,c,tx);assert.equal(r.planId,f.planId);assert.equal(r.initialObservationChainAuthenticated,false);assert.equal(r.intraBlockTraceProven,false);assert.equal(r.refreshStepChainAuthenticated,method==='refreshNext');}
});
test('begin retry checks original environment but skips companion epoch and inventory current source',async()=>{
 const f=setup();f.position(1);f.companionDead=true;f.base.currentFailure=true;f.base.code.set(f.base.witness.address,'0x');const c=await capture(f,{method:'beginCoverage',id:f.planId});assert.equal(c.stage.environment,null);assert.equal(c.stage.companion,null);const tx=f.mine(c);assert.equal(tx.receipt.logs.length,0);await reconcile(f,c,tx);assert(!f.calls.some(c=>c.name==='revocationEpoch'||c.worker==='StreamViewRetrievalConsumerV1'));assert(!f.base.calls.some(c=>c.name==='requireCurrent'));
 const g=setup();g.position(1);g.hook=c=>c.name==='currentArtifactEnvironment'?[Z,1n]:undefined;await assert.rejects(capture(g,{method:'beginCoverage',id:g.planId}));
});
test('retrieval obligation and legacy locator both use dedicated admission and stored witness dispatch',async()=>{
 for(const role of [retrieval.CURRENT_VIEW_RETRIEVAL_V1_ROLE,id('VIEW_ARCHIVE_LOCATOR_IMAGE')]){
  const f=setup({parts:[[obligation(1,role)]]});f.position(0);const q={method:'coverRetrievalNext',id:f.planId,item:f.rows[0],nextLink:Z,witnessHash:H('record')},c=await capture(f,q),r=await reconcile(f,c,f.mine(c));assert.equal(r.admitted.witnessHash,q.witnessHash);assert(f.calls.some(c=>c.worker==='StreamViewRetrievalConsumerV1'&&c.name==='admit'));
 }
 const f=setup({parts:[[obligation()]]});f.position(0);await assert.rejects(capture(f,{method:'coverNext',id:f.planId,item:f.rows[0],nextLink:Z,proof:{backend:1n,objectHash:H('o'),coverageHash:H('c')}}),/requires witness/);
});
test('generic empty segment is explicitly consumer-only and advances no item count',async()=>{
 const f=setup(),q=f.request('coverEmptySegment'),c=await capture(f,q),r=await reconcile(f,c,f.mine(c));assert.equal(r.progress.itemCount,0n);assert.equal(r.progress.segmentIndex,1n);assert.equal(r.admitted,null);
 const g=setup();g.position(0);await assert.rejects(capture(g,{method:'coverEmptySegment',id:g.planId}),/empty segment/);
});
test('mixed environment completion suppresses automatic refresh while retaining immutable evidence',async()=>{
 const f=setup({parts:[[row(1)]]});f.position(0);f.before.environmentHash=H('earlier-environment');const q={method:'coverNext',id:f.planId,item:f.rows[0],nextLink:Z,proof:f.admission(f.rows[0]).proof},c=await capture(f,q),r=await reconcile(f,c,f.mine(c));assert.equal(r.progress.complete,true);assert.equal(r.progress.environmentHash,Z);assert.equal(r.refresh.complete,false);assert.equal(r.evidence.coverage.itemCount,1n);assert.equal(r.initialObservationChainAuthenticated,false);
});
test('automatic observation chain is observed-only but complete count/environment/nonzero invariants are enforced',async()=>{
 const prepare=async()=>{const f=setup({parts:[[row(1)]]});f.position(0);const q={method:'coverNext',id:f.planId,item:f.rows[0],nextLink:Z,proof:f.admission(f.rows[0]).proof};const c=await capture(f,q);return{f,c,tx:f.mine(c)};};
 const {f,c,tx}=await prepare();f.afterRefreshes.get(c.stage.refreshId).currentObservationChain=H('opaque-different-but-unreconstructed');const r=await reconcile(f,c,tx);assert.equal(r.initialObservationChainAuthenticated,false);
 for(const mutate of [r=>r.currentObservationChain=Z,r=>r.nextIndex=0n,r=>r.complete=false,r=>r.environmentHash=H('wrong')]){const {f,c,tx}=await prepare();mutate(f.afterRefreshes.get(c.stage.refreshId));await assert.rejects(reconcile(f,c,tx),/refresh/i);}
});
test('explicit refresh recomputes each observation step and uses saved witness rather than role',async()=>{
 for(const routed of [false,true]){const r=obligation(1,id('VIEW_ARCHIVE_LOCATOR_IMAGE')),f=setup({parts:[[r]]});f.position(1,{complete:true,witnessHashes:[routed?H('record'):Z]});f.refreshes.set(f.refreshKey(),{...emptyRefresh(),environmentHash:f.environment()});const q={method:'refreshNext',id:f.planId,expectedIndex:0n},c=await capture(f,q),tx=f.mine(c),result=await reconcile(f,c,tx);assert.equal(result.refreshStepChainAuthenticated,true);assert.equal(result.refresh.complete,true);assert(f.calls.some(c=>c.name==='current'&&c.worker===(routed?'StreamViewRetrievalConsumerV1':'StreamViewPreservationArchiveReadsV1')));}
 const f=setup(),q=f.request('refreshNext'),c=await capture(f,q),tx=f.mine(c);f.afterRefreshes.get(c.stage.refreshId).currentObservationChain=H('wrong');await assert.rejects(reconcile(f,c,tx),/refresh differs/);
});
test('unrelated witness revocation can invalidate cached coverage while full diagnosis still succeeds',async()=>{
 const f=setup();f.position(2,{complete:true});f.cache();const cached=await current(f);assert.equal(cached.cachedCoverageChecked,true);f.epoch++;f.calls=[];await assert.rejects(current(f),/refresh incomplete/);f.calls=[];const full=await current(f,true);assert.equal(full.cachedCoverageChecked,false);assert.equal(full.fullCurrentCoverageChecked,true);assert.equal(full.refresh,null);assert(!f.calls.some(c=>c.name==='refresh'||c.name==='requireCoverage'));assert(!f.base.calls.some(c=>c.name==='requireCurrent'));
});
test('cached coverage uses inventory evidence hash and does not replay per-item current readers',async()=>{
 const f=setup();f.position(2,{complete:true});f.cache();await current(f);assert(f.calls.some(c=>c.name==='requireCoverage'));assert(!f.calls.some(c=>c.name==='current'));assert(f.calls.filter(c=>c.name.startsWith('currentArtifact')||c.name.startsWith('currentExternal')).every(c=>c.gasLimit===f.deps.archiveGas));
});
test('history remains local after resolver/witness/archive liveness loss and rejects fully rehashed immutable admission contradictions',async()=>{
 const f=setup({parts:[[obligation()]]});f.position(1,{complete:true});f.currentFailure=true;f.companionDead=true;f.base.currentFailure=true;f.base.code.set(f.base.witness.address,'0x');const h=await history(f);assert.equal(h.currentEnvironmentChecked,false);assert.equal(h.retrievalWitnessRecordIndependentlyAuthenticated,false);assert(!f.calls.some(c=>c.worker||c.name==='revocationEpoch'));
 for(const mutate of [a=>a.externalOriginal.artistId=H('wrong'),a=>a.proof.objectHash=H('wrong'),a=>a.externalOriginal.coverageHash=H('wrong'),a=>a.immutablePartsHash=H('wrong'),a=>a.onchainOriginal.artifactHash=H('wrong'),a=>a.externalOriginal.firstFixityHash=Z]){const g=setup({parts:[[obligation()]]});g.position(1,{complete:true});mutate(g.admissions[0].admission);g.rehash();await assert.rejects(history(g));}
 const g=setup();g.position(2,{complete:true});g.admissions[0].admission=copy(g.admissions[0].admission);g.admissions[0].admission.originalBundleHash=H('forged-intrinsic');g.rehash();await assert.rejects(history(g),/Intrinsic/);
});
test('refresh admits a new current pair observation while keeping immutable saved admission unchanged',async()=>{
 const f=setup({parts:[[obligation()]]});f.position(1,{complete:true});const original=copy(f.admissions[0].admission);f.epoch=4n;f.refreshes.set(f.refreshKey(),{...emptyRefresh(),environmentHash:f.environment()});const c=await capture(f,{method:'refreshNext',id:f.planId,expectedIndex:0n});assert.deepEqual(c.stage.admissions[0].admission,original);assert.equal(c.stage.observation,f.observation());await reconcile(f,c,f.mine(c));
});
test('exact occurrence, suffix, witness mapping and original event order are required',async()=>{
 const f=setup(),q=f.request('coverRetrievalNext');await assert.rejects(capture(f,{...q,nextLink:H('wrong')}),/suffix/);await assert.rejects(capture(f,{...q,item:{...q.item,sourceIndex:1n}}),/Item differs/);
 for(const mutate of ['mapping','missing','extra','order','schema','state']){const g=setup(),c=await capture(g,g.request('coverRetrievalNext')),tx=g.mine(c);
  if(mutate==='mapping')g.afterAdmissions[0].witnessHash=H('wrong');if(mutate==='missing')tx.receipt.logs.shift();if(mutate==='extra')tx.receipt.logs.push({...copy(tx.receipt.logs[0]),index:2});if(mutate==='order'){tx.receipt.logs.reverse();tx.receipt.logs.forEach((l,i)=>l.index=i);}if(mutate==='state')g.after.itemCount++;
  if(mutate==='schema')Object.assign(tx.receipt.logs[0],host.encodeEventLog('ViewPreservationBundleItemAdmitted',[2n,g.planId,0n,inv.currentViewPreservationInventoryV1ItemHash(c.stage.admitted.item),c.stage.admitted.admission]));await assert.rejects(reconcile(g,c,tx));}
});
test('strict receipt block attribution and mined worker/dependency runtime pins reject drift',async()=>{
 for(const mutation of ['prior','worker','link','companion','sameblock']){const f=setup(),c=await capture(f,f.request('coverNext')),tx=f.mine(c);
  if(mutation==='prior')f.hook=call=>call.name==='progress'&&call.blockTag===11?[{...f.before,environmentHash:H('changed')}]:undefined;
  if(['worker','link','companion'].includes(mutation))f.base.codeHook=(a,t)=>t===12&&a===(mutation==='worker'?f.d.archiveReader.address:mutation==='link'?f.d.linkedDependencies[0].address:f.base.witness.address)?'0x6002':undefined;
  if(mutation==='sameblock'){for(const obj of [tx.receipt,tx.transaction,...tx.receipt.logs]){obj.blockNumber=10;obj.blockHash=f.block(10).hash;}}await assert.rejects(reconcile(f,c,tx));}
});
test('direct and Safe envelope joins reject mutation and permit later unrelated guard logs',async()=>{
 for(const transport of ['direct','legacy','indexed']){const f=setup(),c=await capture(f,f.request('coverNext')),tx=f.mine(c,transport);if(transport!=='direct')tx.receipt.logs.push({...copy(tx.receipt.logs[0]),address:A(9999),index:tx.receipt.logs.length});await reconcile(f,c,tx);tx.transaction.value=1n;await assert.rejects(reconcile(f,c,tx));}
 const f=setup(),c=await capture(f,f.request('coverNext')),tx=f.mine(c,'indexed');tx.options.expectedSafeTxHash=H('wrong');await assert.rejects(reconcile(f,c,tx),/Safe/);
});
test('owned input/current options and transaction logs detach before awaits',async()=>{
 const f=setup(),q=f.request('coverNext'),d=copy(f.d);f.base.networkHook=()=>{q.item.source=A(9000);d.bundle.address=A(9001);};const c=await w.captureCurrentViewPreservationBundleV1(f.provider,d,f.caller,q,f.opts());assert.equal(c.prepared.request.item.source,f.rows[0].source);assert.equal(c.deployment.bundle.address,f.d.bundle.address);f.base.networkHook=null;
 const tx=f.mine(c),old=f.provider.getTransaction;f.provider.getTransaction=async h=>{tx.receipt.logs[0].data='0x';return old(h);};await reconcile(f,c,tx);
 const g=setup();g.position(2,{complete:true});const opts={...g.opts(),fullCurrentCoverage:true};g.base.networkHook=()=>{opts.blockTag=11;opts.fullCurrentCoverage=false;};const result=await w.inspectCurrentViewPreservationBundleV1Current(g.provider,g.d,g.planId,opts);assert.equal(result.cachedCoverageChecked,false);assert(g.calls.every(c=>c.blockTag===10));
});
test('simulation/refusal classify original failure without claiming rollback or exposing raw errors',async()=>{
 const f=setup(),c=await capture(f,f.request('coverNext'));assert.equal((await w.simulateCurrentViewPreservationBundleV1(f.provider,c,{blockTag:11})).stateChangesPersisted,false);
 for(const code of ['CALL_EXCEPTION','NETWORK_ERROR']){f.hook=call=>{if(call.blockTag===11&&call.name==='coverNext')throw{code,data:'0x1234',url:'https://secret@example.invalid'};};const r=await w.observeCurrentViewPreservationBundleV1Refusal(f.provider,c,{blockTag:11});assert.equal(r.outcome,code==='CALL_EXCEPTION'?'execution-reverted':'rpc-failed');assert.equal(r.submittedTransactionRollbackProven,false);assert(!JSON.stringify(r,(_,v)=>typeof v==='bigint'?v.toString():v).includes('secret'));}
});
test('capture reorg, bounded RPC canonicality and progress impossibilities refuse',async()=>{
 const f=setup(),c=await capture(f,f.request('coverNext')),tampered=copy(c);tampered.stage.before.itemCount=9n;await assert.rejects(w.simulateCurrentViewPreservationBundleV1(f.provider,tampered,{blockTag:11}),/fingerprint/);
 f.base.blockHook=n=>({...f.block(n),hash:H('replacement')});await assert.rejects(w.simulateCurrentViewPreservationBundleV1(f.provider,c,{blockTag:11}),/changed/);
 const g=setup();g.position(0);g.before.segmentItemIndex=2n;g.before.itemCount=2n;g.before.nextLink=Z;await assert.rejects(history(g),/cursor/);
 const j=setup();j.hook=call=>call.name==='progress'?{raw:host.encodeFunctionResult('progress',[j.before])+'00'.repeat(32)}:undefined;await assert.rejects(capture(j,{method:'beginCoverage',id:j.planId}),/canonical/);
});
test('empty and raw-CID obligations retain their original non-retrieval branches',async()=>{
 const absent=obligation(1,undefined,''),cid=obligation(2,undefined,rawCid());assert.equal(absent.kind,7n);assert.equal(cid.role,id('VIEW_CONTENT_ADDRESSED_IMAGE'));assert.notEqual(cid.role,retrieval.CURRENT_VIEW_RETRIEVAL_V1_ROLE);
 const f=setup({parts:[[absent]]});f.position(0);const c=await capture(f,{method:'coverNext',id:f.planId,item:absent,nextLink:Z,proof:f.admission(absent).proof});await reconcile(f,c,f.mine(c));
 const g=setup({parts:[[cid]]});const start=await capture(g,{method:'beginCoverage',id:g.planId});assert.equal(start.stage.inventory.segments[0].items[0].digest,cid.digest);
});
