import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroHash } from 'ethers';
import { setup, bundle, w, inv, A, H, host, safe, methods, coder } from './current-scoped-policy-bundle-v2-workflow-fixture.mjs';

async function capture(kind='beginCoverage',options={}){const f=setup({empty:kind==='coverEmptySegment',...options});f.request=f.prepare(kind);
  f.capture=await w.captureScopedPolicyBundleV2(f.provider,f.deployment,f.caller,f.request,f.options());return f;}
async function reconcile(f,mode='direct'){const tx=f.install(f.capture,mode);return w.reconcileScopedPolicyBundleV2Receipt(f.provider,f.capture,tx.txHash,tx.options);}

test('all five original archive calls direct/legacy/indexed Safe; empty segment is consumer-only mock evidence',async()=>{
  for(const kind of methods)for(const mode of ['direct','legacy','indexed']){
    const f=await capture(kind);const simulation=await w.simulateScopedPolicyBundleV2(f.provider,f.capture,{blockTag:91,gasLimit:f.gasLimit});
    assert.equal(simulation.originalCallSucceeded,true);assert.equal(simulation.stateChangesPersisted,false);
    const result=await reconcile(f,mode);assert.equal(result.initialObservationChainAuthenticated,false);
    assert.equal(result.refreshStepChainAuthenticated,kind==='refreshNext');assert.equal(result.currentAfterReceipt,false);
  }
});
test('beginCoverage requires retained complete inventory but deliberately does not require its current source',async()=>{
  const f=setup();f.f.state.sourceStale=true;f.f.state.code.set(f.f.deployment.workers.source.address,'0x');
  const q=f.prepare();const result=await w.captureScopedPolicyBundleV2(f.provider,f.deployment,f.caller,q,f.options());
  assert.equal(result.stage.inventory.inventory.renderCriticalEvidenceHash,f.f.state.evidence.inventory.renderCriticalEvidenceHash);
  assert.ok(!f.f.state.calls.some(x=>x.to===f.f.deployment.workers.source.address));
});
test('environment uses original archiveGas, all runtime pins and exact epoch/hash observations',async()=>{
  const f=await capture();assert.ok(f.state.calls.some(x=>x.to===f.dependencies.targets[3]&&x.gasLimit===f.dependencies.archiveGas));
  for(const variant of ['epoch','worker','hash']){const g=setup();const q=g.prepare();
    if(variant==='epoch')g.environment.epoch=0n;if(variant==='worker')g.f.state.code.set(g.deployment.archiveReader.address,'0x');
    if(variant==='hash')g.state.workerResult=(worker,args,values)=>worker.method==='environment'?[H(1)]:values;
    await assert.rejects(w.captureScopedPolicyBundleV2(g.provider,g.deployment,g.caller,q,g.options()));}
});
test('current coverage passes original renderCriticalEvidenceHash and keeps full diagnostic separate',async()=>{
  const f=setup();f.prepare('beginRefresh');f.state.refreshBefore={environmentHash:f.environmentHash(),nextIndex:BigInt(f.rows.length),currentObservationChain:H(7),complete:true};
  const opts={...f.options(),fullCurrentCoverage:false};f.f.state.hooks.network=()=>{opts.blockTag=999;opts.fullCurrentCoverage=true;};
  const result=await w.inspectScopedPolicyBundleV2Current(f.provider,f.deployment,f.f.planId,opts);
  assert.equal(result.initialObservationChainAuthenticated,false);assert.equal(result.fullCurrentCoverageChecked,false);
  assert.equal(result.inventoryCurrentSourceChecked,false);assert.equal(result.capture.observed.blockNumber,90);
  assert.ok(f.state.calls.every(x=>x.blockTag===90));
  const call=f.state.calls.find(x=>x.data.startsWith(host.getFunction('requireCoverage').selector));
  assert.equal(host.decodeFunctionData('requireCoverage',call.data)[2],f.f.state.evidence.inventory.renderCriticalEvidenceHash);
});
test('automatic completed refresh requires exact environment/count/completion and nonzero observed chain',async()=>{
  for(const variant of ['environment','count','complete','zero']){const f=await capture('coverNext');const tx=f.install(f.capture);
    if(variant==='environment')f.state.refreshAfter.environmentHash=H(2);if(variant==='count')f.state.refreshAfter.nextIndex--;
    if(variant==='complete')f.state.refreshAfter.complete=false;if(variant==='zero')f.state.refreshAfter.currentObservationChain=ZeroHash;
    await assert.rejects(w.reconcileScopedPolicyBundleV2Receipt(f.provider,f.capture,tx.txHash,tx.options),/refresh/);}
  const f=await capture('coverNext');const tx=f.install(f.capture);f.state.refreshAfter.currentObservationChain=H(123456);
  const result=await w.reconcileScopedPolicyBundleV2Receipt(f.provider,f.capture,tx.txHash,tx.options);
  assert.equal(result.refresh.currentObservationChain,H(123456));assert.equal(result.initialObservationChainAuthenticated,false);
});
test('public refreshNext reconstructs the exact chain and index; beginRefresh is eventless and cannot reset',async()=>{
  const f=await capture('refreshNext');const tx=f.install(f.capture);f.state.refreshAfter.currentObservationChain=H(5);
  await assert.rejects(w.reconcileScopedPolicyBundleV2Receipt(f.provider,f.capture,tx.txHash,tx.options),/refresh differs/);
  const g=setup();g.prepare('beginRefresh');g.state.refreshBefore={environmentHash:g.environmentHash(),nextIndex:1n,currentObservationChain:H(6),complete:false};
  const saved=await w.captureScopedPolicyBundleV2(g.provider,g.deployment,g.caller,{kind:'beginRefresh',id:g.f.planId},g.options());
  assert.deepEqual(saved.stage.refreshAfter,saved.stage.refreshBefore);
});
test('retained admitted Item, proof and full admission evidence chain bind original duplicate occurrences',async()=>{
  for(const variant of ['item','proof','chain']){const f=setup();const q=f.prepare('coverNext');
    if(variant==='item')f.state.admitted[0]={...f.state.admitted[0],item:{...f.state.admitted[0].item,role:H(3)}};
    if(variant==='proof')f.state.admitted[0]={...f.state.admitted[0],admission:{...f.state.admitted[0].admission,originalBundleHash:H(3)}};
    if(variant==='chain')f.state.before.evidenceChainHash=H(3);
    await assert.rejects(w.captureScopedPolicyBundleV2(f.provider,f.deployment,f.caller,q,f.options()));}
});
test('next occurrence/suffix/proof cannot be replaced and empty segment cannot consume a nonempty segment',async()=>{
  const f=setup();const q=f.prepare('coverNext');q.nextLink=H(1);
  await assert.rejects(w.captureScopedPolicyBundleV2(f.provider,f.deployment,f.caller,q,f.options()));
  const g=setup();g.prepare('coverNext');await assert.rejects(w.captureScopedPolicyBundleV2(g.provider,g.deployment,g.caller,
    {kind:'coverEmptySegment',id:g.f.planId},g.options()),/empty/);
});
test('ItemAdmitted precedes Completed; missing duplicate and schema-corrupted events reject',async()=>{
  for(const variant of ['missing','reorder','duplicate','schema']){const f=await capture('coverNext');const tx=f.install(f.capture);const r=f.f.state.receipts.get(tx.txHash);
    if(variant==='missing')r.logs.shift();if(variant==='reorder')r.logs.reverse();if(variant==='duplicate')r.logs.push({...r.logs[0]});
    if(variant==='schema'){const s=f.capture.stage;r.logs[0]={...r.logs[0],...f.emit('ScopedBundleItemAdmitted',[1n,f.f.planId,s.before.itemCount,inv.scopedPolicyInventoryV2ItemHash(s.admitted.item),s.admitted.admission])};}
    f.f.renumber();await assert.rejects(w.reconcileScopedPolicyBundleV2Receipt(f.provider,f.capture,tx.txHash,tx.options));}
});
test('archive receipt refuses same-block progress, late linked-helper replacement and malformed mined envelope',async()=>{
  for(const variant of ['progress','worker','link','metadata','outer','earlyBlock']){const f=await capture();const tx=f.install(f.capture);const r=f.f.state.receipts.get(tx.txHash);
    if(variant==='progress')f.state.after.itemCount++;
    if(variant==='worker'||variant==='link')f.f.state.hooks.code=(address,tag)=>{if(tag===100&&address===(variant==='worker'?f.deployment.archiveReader.address:f.deployment.linkedDependencies[0].address))f.f.state.code.set(address,'0x6001');};
    if(variant==='metadata')delete r.logs[0].transactionHash;if(variant==='outer')f.f.state.transactions.get(tx.txHash).value=1n;
    if(variant==='earlyBlock'){r.blockNumber=90;r.blockHash=f.f.header(90).hash;}
    await assert.rejects(w.reconcileScopedPolicyBundleV2Receipt(f.provider,f.capture,tx.txHash,tx.options));}
});
test('Safe independent hash, CALL-only transport, copied logs and exact event order',async()=>{
  for(const variant of ['hash','operation','failure','early']){const f=await capture('coverNext');const tx=f.install(f.capture,'indexed');const r=f.f.state.receipts.get(tx.txHash),t=f.f.state.transactions.get(tx.txHash);
    if(variant==='hash')tx.options.expectedSafeTxHash=H(1);if(variant==='operation'){const args=Array.from(safe.decodeFunctionData('execTransaction',t.data));args[3]=1n;t.data=safe.encodeFunctionData('execTransaction',args);}
    if(variant==='failure')r.logs.at(-1).topics[0]=safe.getEvent('ExecutionFailure').topicHash;if(variant==='early'){r.logs.unshift(r.logs.pop());f.f.renumber();}
    await assert.rejects(w.reconcileScopedPolicyBundleV2Receipt(f.provider,f.capture,tx.txHash,tx.options));}
  const f=await capture();const tx=f.install(f.capture,'indexed');f.f.state.hooks.transaction=()=>{f.f.state.receipts.get(tx.txHash).logs.at(-1).topics[1]=H(1);};
  await w.reconcileScopedPolicyBundleV2Receipt(f.provider,f.capture,tx.txHash,tx.options);
});
test('immutable local evidence survives lost archive/source workers; bounded current explicitly does not',async()=>{
  const f=setup();f.prepare('beginRefresh');f.f.state.code.set(f.deployment.archiveReader.address,'0x');f.f.state.sourceStale=true;
  const result=await w.inspectScopedPolicyBundleV2History(f.provider,f.historyDeployment,f.f.planId,{blockTag:90,segments:f.f.locators()});
  assert.ok(result.evidence);assert.equal(result.currentEnvironmentChecked,false);assert.equal(result.inventoryCurrentSourceChecked,false);
  await assert.rejects(w.inspectScopedPolicyBundleV2Current(f.provider,f.deployment,f.f.planId,f.options()));
});
test('changed environment permits a separate refresh; current observations remain distinct from original admissions',async()=>{
  const f=setup();f.prepare('beginRefresh');const old=f.environmentHash();f.environment.revision=1n;
  const result=await w.captureScopedPolicyBundleV2(f.provider,f.deployment,f.caller,{kind:'beginRefresh',id:f.f.planId},f.options());
  assert.notEqual(result.stage.environment.hash,old);assert.equal(result.stage.before.environmentHash,old);
  assert.equal(result.stage.refreshAfter.environmentHash,result.stage.environment.hash);
});
test('refusal records exact selected state equality, preserves original error, and does not claim atomic rollback',async()=>{
  const f=await capture();const error=Object.assign(Error('late original dependency failure'),{code:'CALL_EXCEPTION'});
  f.state.hooks.call=tx=>{if(tx.blockTag===91&&tx.data===f.capture.prepared.call.data)throw error;};
  const result=await w.observeScopedPolicyBundleV2Refusal(f.provider,f.capture,{blockTag:91,gasLimit:f.gasLimit});
  assert.equal(result.error,error);assert.equal(result.retainedStateUnchanged,true);assert.equal(result.rollbackProven,false);
});

test('external refresh passes saved original receipt pair to current worker while fresh fixity observation changes',async()=>{
  const f=setup({external:true});f.prepare('refreshNext');const last=BigInt(f.rows.length-1);
  f.state.refreshBefore={environmentHash:f.environmentHash(),nextIndex:last,currentObservationChain:H(77),complete:false};
  const original=structuredClone(f.admissions.at(-1).admission);let seen=false;
  f.state.workerResult=(worker,args,values)=>{if(worker.method==='current'){
    assert.equal(args[3].externalOriginal.firstReceiptHash,original.externalOriginal.firstReceiptHash);
    assert.equal(args[3].externalOriginal.secondReceiptHash,original.externalOriginal.secondReceiptHash);
    assert.equal(args[3].externalOriginal.firstFixityHash,original.externalOriginal.firstFixityHash);seen=true;return [H(88000)];}return values;};
  const capture=await w.captureScopedPolicyBundleV2(f.provider,f.deployment,f.caller,{kind:'refreshNext',id:f.f.planId,expectedIndex:last},f.options());
  assert.equal(seen,true);assert.equal(capture.stage.currentObservation,H(88000));assert.deepEqual(capture.stage.admissions.at(-1).admission,original);
  assert.equal(capture.stage.refreshAfter.complete,true);
  const tx=f.install(capture);const result=await w.reconcileScopedPolicyBundleV2Receipt(f.provider,capture,tx.txHash,tx.options);
  assert.equal(result.refreshStepChainAuthenticated,true);
});

test('native whole-byte archival admission rejects wrong content, size and artist',async()=>{
  for(const field of ['contentHash','byteLength','artistId']){const f=setup();const q=f.prepare('coverNext');
    f.state.workerResult=(worker,args,values)=>{if(worker.method!=='admit')return values;const a=structuredClone(values[0]);
      a.onchainOriginal[field]=field==='byteLength'?a.onchainOriginal.byteLength+1n:H(1);return [a,values[1]];};
    await assert.rejects(w.captureScopedPolicyBundleV2(f.provider,f.deployment,f.caller,q,f.options()));}
});
