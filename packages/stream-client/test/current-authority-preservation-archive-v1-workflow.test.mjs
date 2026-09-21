import test from 'node:test';
import assert from 'node:assert/strict';
import { id } from 'ethers';
import { setup,archive,workflow as w,inv,prefix,ip,A,H,Z,ZA,safe,copy,empty,item } from './current-authority-preservation-archive-v1-workflow-fixture.mjs';
const capture=(f,q)=>f.capture(q),reconcile=(f,c,t)=>w.reconcileCurrentAuthorityPreservationArchiveV1Receipt(f.provider,c,t.hash,t.options);
const history=f=>w.inspectCurrentAuthorityPreservationArchiveV1History(f.provider,f.hd,f.id,{blockTag:90,segments:f.opts().segments});
const current=(f,extra={})=>w.inspectCurrentAuthorityPreservationArchiveV1Current(f.provider,f.d,f.id,{...f.opts(),...extra});
const completedRefresh=f=>({environmentHash:f.environment().hash,nextIndex:BigInt(f.rows.length),currentObservationChain:H(60000),complete:true});
function mutateLog(f,t,name,change){const receipt=f.state.receipts.get(t.hash),log=receipt.logs.find(v=>v.address===f.coords.archive&&f.host.parseLog(v)?.name===f.eventName(name));assert.ok(log);const parsed=f.host.parseLog(log),args=[...parsed.args];change(args);Object.assign(log,f.host.encodeEventLog(parsed.fragment,args));}

for(const method of ['beginCoverage','coverNext','coverEmptySegment','beginRefresh','refreshNext'])test(`${method}: both families and direct/legacy/indexed Safe compiler receipts`,async()=>{
  for(const scopeKind of ['collection','scoped'])for(const mode of ['direct','legacy','indexed']){
    const f=setup({scopeKind,empty:method==='coverEmptySegment'}),c=await capture(f,f.request(method)),t=f.mine(c,mode),result=await reconcile(f,c,t);
    assert.equal(result.planId,f.id);assert.equal(result.initialObservationChainAuthenticated,false);assert.equal(result.refreshStepChainAuthenticated,method==='refreshNext');assert.equal(result.currentAfterReceipt,false);
    assert.ok(f.state.calls.some(tx=>tx.to===f.coords.archive&&tx.from===f.caller&&tx.data===c.prepared.call.data));
  }
});

test('begin retry is eventless but requires current authority/environment; no inventory source-current gate',async()=>{
  const f=setup({existing:true});f.state.sourceStale=true;const q=f.request('beginCoverage'),c=await capture(f,q),t=f.mine(c);assert.equal(c.stage.existing,true);assert.equal(f.state.receipts.get(t.hash).logs.length,0);await reconcile(f,c,t);
  f.s.capture.selection.completion=H(60001);await assert.rejects(capture(f,q),/resolver capture differs/);
});

test('history authenticates retained chains after resolver/source/runtime retirement and detects local corruption',async()=>{
  const f=setup();f.request('beginRefresh');f.state.sourceStale=true;f.state.code.delete(f.base.ad.resolver);f.state.code.delete(f.d.archiveReader.address);f.state.code.delete(f.base.current.environment.archive);
  const h=await history(f);assert.equal(h.currentAuthorityChecked,false);assert.equal(h.currentEnvironmentChecked,false);assert.equal(h.inventory.selectionCommitmentRecomputed,false);assert.equal(h.admissions.length,f.rows.length);
  await assert.rejects(current(f),/runtime/i);f.s.admissions[0].originHash=H(60002);await assert.rejects(history(f),/occurrence hash/);
});

test('current coverage uses inventory hash, archiveGas and independently selected full diagnostic',async()=>{
  for(const scopeKind of ['collection','scoped']){const f=setup({scopeKind});f.request('beginRefresh');f.s.refresh=completedRefresh(f);assert.notEqual((f.s.evidence.coverage??f.s.evidence).bundleCoverageHash,(f.inventoryEvidence.inventory??f.inventoryEvidence).renderCriticalEvidenceHash);
    const result=await current(f,{fullCurrentCoverage:true});assert.equal(result.fullCurrentCoverageChecked,true);assert.equal(result.inventoryCurrentSourceChecked,false);assert.equal(result.initialObservationChainAuthenticated,false);assert.equal(f.s.requireFull,true);
  }
});

test('STATE_BUNDLE routes original op17/op24 to sealed prior Archive and binds every retained occurrence',async()=>{
  for(const scopeKind of ['collection','scoped'])for(const operation of [17n,24n]){const f=setup({scopeKind,stateBundle:true,oldOrigin:true,operation,first:true}),c=await capture(f,f.request('coverNext'));assert.notEqual(c.stage.admitted.originHash,Z);assert.equal(c.stage.admitted.original.producer.environment.archive,f.base.origin(10800).environment.archive);
    const observed=f.s.seen.find(v=>v.entry.method==='route');assert.ok(observed);const t=f.mine(c);await reconcile(f,c,t);assert.equal(f.s.afterAdmissions[0].originHash,c.stage.admitted.originHash);
  }
});

test('origin route rejects worker substitution, missing original occurrence and wrong retained route hash',async()=>{
  const f=setup({stateBundle:true,oldOrigin:true,first:true}),q=f.request('coverNext');f.s.workerResult=(entry,args,values)=>entry.method==='route'?[values[0],H(60003)]:values;await assert.rejects(capture(f,q),/archive route differs/);
  f.s.workerResult=null;const original=f.state.originRecords.values().next().value;original.occurrence.position.point.ownerIndex=4n;await assert.rejects(capture(f,q),/owner|origin|occurrence/i);
});

test('old origin Archive remains required on begin retry/current but unrelated old owner does not',async()=>{
  const f=setup({stateBundle:true,oldOrigin:true,existing:true}),q=f.request('beginCoverage'),old=f.base.origin(10800);f.state.code.delete(old.environment.owners[0]);await capture(f,q);f.state.code.delete(old.environment.archive);await assert.rejects(capture(f,q),/runtime/i);
});

test('mixed-environment completion retains coverage and suppresses automatic refresh',async()=>{
  const f=setup({mixed:true}),c=await capture(f,f.request('coverNext'));assert.equal(c.stage.after.complete,true);assert.equal(c.stage.after.environmentHash,Z);assert.deepEqual(c.stage.refreshAfter,empty('REFRESH'));const t=f.mine(c);const result=await reconcile(f,c,t);assert.equal(result.refresh.complete,false);assert.equal(result.evidence!==null,true);
});

test('automatic private observation chain is observed-only with strict shape, count and environment guards',async()=>{
  const f=setup(),c=await capture(f,f.request('coverNext')),t=f.mine(c);f.s.afterRefresh.currentObservationChain=H(60004);assert.equal((await reconcile(f,c,t)).initialObservationChainAuthenticated,false);
  const valid=copy(f.s.afterRefresh);for(const delta of [{currentObservationChain:Z},{nextIndex:valid.nextIndex-1n},{environmentHash:H(60005)},{complete:false}]){f.s.afterRefresh={...valid,...delta};await assert.rejects(reconcile(f,c,t),/refresh/i);}f.s.afterRefresh=valid;
});

test('external fixity refresh preserves original Admission and reconstructs explicit final refresh chain',async()=>{
  const f=setup({external:true,refreshIndex:10}),q=f.request('refreshNext'),saved=copy(f.s.admissions.at(-1).admission),old=saved.externalOriginal;
  const {coverageHash,...retainedPair}=old;void coverageHash;const pair={...retainedPair,firstFixityHash:H(60101),secondFixityHash:H(60102)};
  f.s.workerResult=(entry,args,values)=>entry.method==='current'?[archive[prefix+'CurrentObservation'](f.base.co.artistId,f.rows.at(-1),saved,pair)]:values;
  const c=await capture(f,q);assert.equal(c.stage.refreshAfter.complete,true);assert.notEqual(c.stage.currentObservation,Z);const t=f.mine(c);assert.equal((await reconcile(f,c,t)).refreshStepChainAuthenticated,true);assert.deepEqual(f.s.admissions.at(-1).admission,saved);
  pair.firstReceiptHash=H(60103);await assert.rejects(capture(f,q),/pair|receipt/i);
});

test('refresh begin retry is eventless; explicit cursor, completed refresh and backend re-admission remain source authority',async()=>{
  const f=setup({existingRefresh:true}),c=await capture(f,f.request('beginRefresh')),t=f.mine(c);assert.equal(f.state.receipts.get(t.hash).logs.length,0);await reconcile(f,c,t);
  const g=setup(),q=g.request('refreshNext');await assert.rejects(capture(g,{...q,expectedIndex:1n}),/cursor/);g.s.refresh=completedRefresh(g);await assert.rejects(capture(g,q),/cursor/);
  g.s.refresh={environmentHash:g.environment().hash,nextIndex:0n,currentObservationChain:Z,complete:false};g.s.workerResult=(entry,args,values)=>{if(entry.method==='current'){const changed=copy(g.s.admissions[0].admission);changed.originalBundleHash=H(60200);archive[prefix+'CurrentObservation'](g.base.co.artistId,g.rows[0],g.s.admissions[0].admission,changed);}return values;};await assert.rejects(capture(g,q),/changes original/);
});

test('all four e93 preservation V2 ABI correspondence pairs reach original admission; mismatched triples reject',async()=>{
  for(const [role,schema,canon] of [['POLICY_SNAPSHOT_MANIFEST_V2','STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V2','STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V2'],['REFERENCE_MANIFEST','STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V2','STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V2'],['SCOPED_POLICY_SNAPSHOT_MANIFEST_V2','STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V2','STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2'],['SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST','STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V2','STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V2']]){
    const row=item(200,{kind:2n,role:id(role),schemaId:id(schema),canonicalizationId:id(canon),algorithm:1n,digest:H(60201),byteSize:64n}),f=setup({item:row}),q=f.request('coverNext');const c=await capture(f,q);assert.equal(c.stage.admitted.admission.proof.backend,2n);assert.ok(f.s.seen.some(v=>v.entry.method==='admit'));
    const g=setup({item:{...row,schemaId:H(60202)}});await assert.rejects(capture(g,g.request('coverNext')),/correspondence/);
  }
});

test('duplicate Item occurrences preserve order, suffix and partial segment progress',async()=>{
  const f=setup({duplicates:true}),q=f.request('coverNext'),c=await capture(f,q);assert.equal(c.stage.after.complete,false);assert.equal(c.stage.after.segmentItemIndex,1n);await reconcile(f,c,f.mine(c));
  await assert.rejects(capture(f,{...q,nextLink:Z}),/link|suffix/i);await assert.rejects(capture(f,{...q,item:{...q.item,role:H(60203)}}),/occurrence/);
});

test('receipt event cardinality, original schema, admission order and end-block attribution are exact',async()=>{
  const f=setup(),c=await capture(f,f.request('coverNext')),t=f.mine(c),receipt=f.state.receipts.get(t.hash),valid=copy(receipt.logs);
  mutateLog(f,t,'ItemAdmitted',args=>{args[0]=2n;});await assert.rejects(reconcile(f,c,t),/ItemAdmitted differs/);receipt.logs=copy(valid);
  receipt.logs=[receipt.logs[1],receipt.logs[0]].map((v,index)=>({...v,index}));await assert.rejects(reconcile(f,c,t),/precedes/);receipt.logs=copy(valid);
  receipt.logs.push({...copy(valid[0]),index:2});await assert.rejects(reconcile(f,c,t),/event/i);receipt.logs=copy(valid);
  f.s.after.itemCount++;await assert.rejects(reconcile(f,c,t),/End-block/);
});

test('write receipt re-pins workers, transitive links and old-origin Archive at mined block',async()=>{
  const f=setup({stateBundle:true,oldOrigin:true}),c=await capture(f,f.request('coverNext')),t=f.mine(c);
  for(const target of [f.d.authorityReader.address,f.d.archiveReader.address,f.d.linkedDependencies[0].address,f.base.origin(10800).environment.archive]){f.state.hooks.code=(a,tag)=>a===target&&tag===100?'0x6001':undefined;await assert.rejects(reconcile(f,c,t),/runtime/i);}f.state.hooks.code=null;
});

test('Safe hash, exact CALL envelope, direct sender/value and receipt/header identity cannot substitute',async()=>{
  const f=setup(),c=await capture(f,f.request('coverNext')),t=f.mine(c,'indexed'),tx=f.state.transactions.get(t.hash),saved=copy(tx);
  await assert.rejects(reconcile(f,c,{...t,options:{execution:'safe',expectedSafeTxHash:H(60300)}}),/Safe|hash/i);tx.data=safe.encodeFunctionData('execTransaction',[f.coords.archive,0n,c.prepared.call.data,1,0,0,0,ZA,ZA,'0x12']);await assert.rejects(reconcile(f,c,t),/CALL|operation/i);Object.assign(tx,saved);
  const direct=f.mine(c),dtx=f.state.transactions.get(direct.hash);dtx.from=A(32);await assert.rejects(reconcile(f,c,direct),/from|caller|sender|receipt|transaction/i);
  dtx.from=f.caller;dtx.value=1n;await assert.rejects(reconcile(f,c,direct),/value|envelope/i);
});

test('fixed saved/prior blocks reject reorg, prior drift, earlier receipts and malformed canonical RPC',async()=>{
  const f=setup(),q=f.request('beginCoverage'),c=await capture(f,q),t=f.mine(c);f.state.blockHashes.set(90,H(60301));await assert.rejects(reconcile(f,c,t),/reorg|block/i);f.state.blockHashes.delete(90);
  f.s.hostResult=(name,args,values,tx)=>name==='progress'&&tx.blockTag===99?[{...values[0],environmentHash:H(60302)}]:values;await assert.rejects(reconcile(f,c,t),/cursor|progress|changed|link|suffix/i);f.s.hostResult=null;
  f.s.raw=(name,raw)=>name==='dependencyHash'?raw+'00'.repeat(32):raw;await assert.rejects(capture(f,q),/canonical/i);f.s.raw=null;
  const receipt=f.state.receipts.get(t.hash);receipt.blockNumber=90;receipt.blockHash=f.base.header(90).hash;receipt.logs=receipt.logs.map(v=>({...v,blockNumber:90,blockHash:receipt.blockHash}));Object.assign(f.state.transactions.get(t.hash),{blockNumber:90,blockHash:receipt.blockHash});await assert.rejects(reconcile(f,c,t),/follow captured block/);
});

test('refusal preserves original error and readback evidence without claiming rollback or transport reverts',async()=>{
  const f=setup(),c=await capture(f,f.request('beginCoverage'));for(const code of ['CALL_EXCEPTION','NETWORK_ERROR']){const error=Object.assign(Error('original archive proof refusal'),{code});f.s.reject={tag:91,error};const r=await w.observeCurrentAuthorityPreservationArchiveV1Refusal(f.provider,c,{blockTag:91,gasLimit:50000000n});assert.equal(r.error,error);assert.equal(r.retainedStateUnchanged,true);assert.equal(r.rollbackProven,false);assert.equal(r.outcome,code==='CALL_EXCEPTION'?'execution-reverted':'rpc-failed');}
});

test('inputs/options are owned before awaits; current diagnostics retain the original block and flag',async()=>{
  const f=setup(),d=copy(f.d),q=f.request('beginCoverage'),opts=copy(f.opts());f.state.hooks.network=()=>{d.linkedDependencies[0].codeHash=H(60303);q.id=H(60304);opts.blockTag=91;};const c=await w.captureCurrentAuthorityPreservationArchiveV1(f.provider,d,f.caller,q,opts);assert.equal(c.observed.blockNumber,90);assert.equal(c.prepared.request.id,f.id);assert.equal(c.deployment.linkedDependencies[0].codeHash,f.d.linkedDependencies[0].codeHash);
  f.state.hooks.network=null;f.request('beginRefresh');f.s.refresh=completedRefresh(f);const currentOpts={...f.opts(),fullCurrentCoverage:true};f.state.hooks.network=()=>{currentOpts.blockTag=92;currentOpts.fullCurrentCoverage=false;};const result=await w.inspectCurrentAuthorityPreservationArchiveV1Current(f.provider,f.d,f.id,currentOpts);assert.equal(result.capture.observed.blockNumber,90);assert.equal(result.fullCurrentCoverageChecked,true);
});

test('transport owns fetched logs/transactions; finite runtime/gas/locator/call limits reject early',async()=>{
  const f=setup(),q=f.request('beginCoverage'),c=await capture(f,q),t=f.mine(c,'legacy'),receipt=f.state.receipts.get(t.hash),tx=f.state.transactions.get(t.hash);
  let fetched=false;f.state.hooks.transaction=()=>{fetched=true;};f.state.hooks.block=tag=>{if(fetched&&tag===100){receipt.logs.length=0;tx.data='0x';}};await reconcile(f,c,t);
  f.state.hooks.block=null;await assert.rejects(w.captureCurrentAuthorityPreservationArchiveV1(f.provider,f.d,f.caller,q,{...f.opts(),gasLimit:100000001n}),/gas/i);await assert.rejects(w.captureCurrentAuthorityPreservationArchiveV1(f.provider,f.d,f.caller,q,{...f.opts(),segments:[...f.opts().segments,f.opts().segments[0]]}),/Duplicate/);
  const g=setup(),cg=await capture(g,g.request('beginCoverage')),tg=g.mine(cg);g.state.transactions.get(tg.hash).data='0x'+'00'.repeat(2*1024*1024+16385);await assert.rejects(reconcile(g,cg,tg),/limit|bytes/i);
  g.state.hooks.code=(a)=>a===g.coords.archive?'0x'+'00'.repeat(131073):undefined;await assert.rejects(capture(g,cg.prepared.request),/limit|bytes/i);
});

test('simulation revalidates immutable capture and uses actual caller with requested original call gas',async()=>{
  const f=setup(),c=await capture(f,f.request('beginCoverage')),r=await w.simulateCurrentAuthorityPreservationArchiveV1(f.provider,c,{blockTag:91,gasLimit:60000000n});assert.equal(r.originalCallSucceeded,true);assert.equal(r.stateChangesPersisted,false);assert.equal(r.capture.observed.blockNumber,91);
  assert.ok(f.state.calls.some(tx=>tx.to===f.coords.archive&&tx.from===f.caller&&tx.blockTag===91&&tx.gasLimit===60000000n&&tx.data===c.prepared.call.data));
  const forged=copy(c);forged.prepared.call.data='0x';await assert.rejects(w.simulateCurrentAuthorityPreservationArchiveV1(f.provider,forged,{blockTag:91,gasLimit:60000000n}),/fingerprint/);
  f.s.capture.selection.completion=H(60400);await assert.rejects(w.simulateCurrentAuthorityPreservationArchiveV1(f.provider,c,{blockTag:91,gasLimit:60000000n}),/capture differs/);
});
