import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroHash, ZeroAddress } from 'ethers';
import { setup, methods, inv, w, A, H, pin, host, safe, coder, item } from './current-scoped-policy-inventory-v2-workflow-fixture.mjs';
import { createSafeCallPlan, verifySafeCallPlan } from '../dist/safe-plan.js';

async function capture(kind='beginInventory',options={}) {
  const f=setup({waiver:kind==='appendIntentWaiver',interviewWaiver:kind==='appendInterviewWaiver',...options});
  f.request=f.prepare(kind);
  f.capture=await w.captureScopedPolicyInventoryV2(f.provider,f.deployment,f.caller,f.request,f.options());
  return f;
}
const receipt=async(f,mode='direct')=>{const tx=f.install(f.capture,mode);return w.reconcileScopedPolicyInventoryV2Receipt(f.provider,f.capture,tx.txHash,tx.options);};

test('all17 original inventory stages capture, simulate and reconcile direct plus both Safe layouts (mocked source producers)',async()=>{
  for(const kind of methods)for(const mode of ['direct','legacy','indexed']){
    const f=await capture(kind);
    const simulated=await w.simulateScopedPolicyInventoryV2(f.provider,f.capture,{blockTag:91,gasLimit:f.gasLimit});
    assert.equal(simulated.originalCallSucceeded,true);assert.equal(simulated.stateChangesPersisted,false);
    const result=await receipt(f,mode);assert.equal(result.planId,f.planId);assert.equal(result.precedingAndEndBlockAttribution,true);
    assert.equal(result.currentAfterReceipt,false);
    if(f.capture.stage.appended){assert.ok(result.segmentLocator);assert.deepEqual(result.appended.items,f.capture.stage.appended.items);}
  }
});
test('TOKEN RELEASE SEASON source identities and actual permissionless caller, value and original begin',async()=>{
  for(const scopeType of [1n,2n,3n]){const scope={scopeType,collectionId:1n,tokenId:scopeType===1n?11n:0n,scopeId:scopeType===1n?ZeroHash:H(55)};
    const f=await capture('beginInventory',{scope});assert.equal(f.capture.prepared.call.value,0n);
    assert.ok(f.state.calls.some(x=>x.to===f.coords.inventory&&x.from===f.caller&&x.data.startsWith(host.getFunction('beginInventory').selector)));
    await receipt(f);}
});
test('begin retry is eventless with exact prior retained state; new begin requires its event',async()=>{
  const old=await capture('beginInventory',{existing:true});assert.equal(old.capture.stage.existing,true);await receipt(old);
  const f=await capture();const tx=f.install(f.capture);f.state.receipts.get(tx.txHash).logs=[];
  await assert.rejects(w.reconcileScopedPolicyInventoryV2Receipt(f.provider,f.capture,tx.txHash,tx.options),/begin events/);
});
test('complete ordered event locators preserve duplicate Item occurrences and reject missing/order/hash substitutions',async()=>{
  const f=await capture('appendReference');assert.deepEqual(f.capture.stage.segments[0].items[0],f.capture.stage.segments[0].items[1]);
  await assert.rejects(w.captureScopedPolicyInventoryV2(f.provider,f.deployment,f.caller,f.request,{...f.options(),segments:[]}),/locators/);
  const locator=f.locators()[0],log=f.state.receipts.get(locator.transactionHash).logs[0];log.data=log.data.slice(0,-2)+'01';
  await assert.rejects(w.inspectScopedPolicyInventoryV2Segment(f.provider,f.historyDeployment,locator,{blockTag:90}));
});
test('segment schema, retained segment, topic and transaction identity must all agree',async()=>{
  for(const variant of ['schema','retained','removed','index','metadata']){
    const f=await capture('appendReference');const locator=f.locators()[0],r=f.state.receipts.get(locator.transactionHash);
    if(variant==='schema'){const x=f.state.segments[0];r.logs[0]={...r.logs[0],...f.emit('ScopedInventorySegmentRecorded',[1n,f.planId,0n,x.segment,x.items])};}
    if(variant==='retained')f.state.segments[0].segment={...f.state.segments[0].segment,sourceWitnessHash:H(9)};
    if(variant==='removed')r.logs[0].removed=true;if(variant==='index')r.logs[0].index=NaN;if(variant==='metadata')delete r.logs[0].blockHash;
    await assert.rejects(w.inspectScopedPolicyInventoryV2Segment(f.provider,f.historyDeployment,locator,{blockTag:90}));
  }
});
test('saved-source drift and changed original capture block reject recapture without inventing current-plan getter',async()=>{
  const f=await capture();f.state.blockHashes.set(90,H(1));
  await assert.rejects(w.simulateScopedPolicyInventoryV2(f.provider,f.capture,{blockTag:91,gasLimit:f.gasLimit}),/changed/);
  const g=await capture('appendNative');g.context.rootRecordHash=H(2);
  await assert.rejects(w.simulateScopedPolicyInventoryV2(g.provider,g.capture,{blockTag:91,gasLimit:g.gasLimit}),/stale|differs/);
});
test('wrong stage, page length, row count and selected conservation branch refuse before original mutation',async()=>{
  const f=setup();const q=f.prepare('appendRights');f.state.before.progress.completedStages=2n;
  await assert.rejects(w.captureScopedPolicyInventoryV2(f.provider,f.deployment,f.caller,q,f.options()),/stage/);
  for(const values of [[[],2n],[[item()],3n]]){const g=setup();const request=g.prepare('appendNative');g.state.workerResult=(worker,args,old)=>worker.role==='native'?values:old;
    await assert.rejects(w.captureScopedPolicyInventoryV2(g.provider,g.deployment,g.caller,request,g.options()),/page/);}
});
test('all31 fixed definitions are source-bound; altered selected definition and retained facts refuse',async()=>{
  const f=setup();const q=f.prepare('appendDefinition');f.state.workerResult=(worker,args,values)=>worker.role==='documents'&&worker.method==='item'?[{...values[0],catalogHash:H(4)}]:values;
  await assert.rejects(w.captureScopedPolicyInventoryV2(f.provider,f.deployment,f.caller,q,f.options()),/definition/);
  const g=setup();g.completed();g.state.workerResult=(worker,args,values)=>worker.method==='currentFactsHash'?[H(1)]:values;
  await assert.rejects(w.inspectScopedPolicyInventoryV2Current(g.provider,g.deployment,g.context.scope,{...g.options(),fullDefinitionBytes:true}),/document/);
});
test('bounded currentness and full definition diagnostic differ, detached options never change selected block',async()=>{
  const f=setup();f.completed();const opts={...f.options(),fullDefinitionBytes:false};
  f.state.hooks.network=()=>{opts.blockTag=999;opts.fullDefinitionBytes=true;};
  const result=await w.inspectScopedPolicyInventoryV2Current(f.provider,f.deployment,f.context.scope,opts);
  assert.equal(result.fullDefinitionBytesChecked,false);assert.equal(result.capture.observed.blockNumber,90);
  assert.ok(f.state.calls.every(x=>x.blockTag===90));assert.ok(!f.state.calls.some(x=>x.data.startsWith(host.getFunction('requireFullDefinitionBytes').selector)));
});
test('local complete history survives former source/worker loss; current source inspection refuses',async()=>{
  const f=setup();f.completed();f.state.code.set(f.deployment.workers.source.address,'0x');f.state.sourceStale=true;
  const result=await w.inspectScopedPolicyInventoryV2History(f.provider,f.historyDeployment,f.planId,{blockTag:90,segments:f.locators()});
  assert.equal(result.currentSourceChecked,false);assert.ok(result.evidence);
  await assert.rejects(w.inspectScopedPolicyInventoryV2Current(f.provider,f.deployment,f.context.scope,f.options()));
});
test('receipt progress, event absence/duplication, wrong schema and later same-block progress refuse attribution',async()=>{
  for(const variant of ['missing','duplicate','schema','progress','token']){const f=await capture('appendNative');const tx=f.install(f.capture);const r=f.state.receipts.get(tx.txHash);
    if(variant==='missing')r.logs=[];if(variant==='duplicate'){r.logs.push({...r.logs[0]});f.renumber();}
    if(variant==='schema'){const a=f.capture.stage.appended;r.logs[0]={...r.logs[0],...f.emit('ScopedInventorySegmentRecorded',[1n,f.planId,0n,a.segment,a.items])};}
    if(variant==='progress')f.state.after.progress.itemCount++;if(variant==='token')f.state.tokenAfter.phase=1n;
    await assert.rejects(w.reconcileScopedPolicyInventoryV2Receipt(f.provider,f.capture,tx.txHash,tx.options));}
});
test('Safe exact inner CALL, independent hash and final success order; original planner round-trip',async()=>{
  const f=await capture();const plan=createSafeCallPlan(1n,'Inventory',[{safe:f.caller,intent:'Begin inventory',call:f.capture.prepared.call,abi:inv.SCOPED_POLICY_INVENTORY_V2_ABI}]);
  assert.equal(verifySafeCallPlan(plan,[inv.SCOPED_POLICY_INVENTORY_V2_ABI]).steps.length,1);
  for(const variant of ['hash','operation','value','early','failure']){const g=await capture('appendNative');const tx=g.install(g.capture,'indexed');const r=g.state.receipts.get(tx.txHash),t=g.state.transactions.get(tx.txHash);
    if(variant==='hash')tx.options.expectedSafeTxHash=H(3);
    if(variant==='operation'||variant==='value'){const a=Array.from(safe.decodeFunctionData('execTransaction',t.data));a[variant==='operation'?3:1]=1n;t.data=safe.encodeFunctionData('execTransaction',a);}
    if(variant==='early'){r.logs.reverse();g.renumber();}if(variant==='failure')r.logs.at(-1).topics[0]=safe.getEvent('ExecutionFailure').topicHash;
    await assert.rejects(w.reconcileScopedPolicyInventoryV2Receipt(g.provider,g.capture,tx.txHash,tx.options));}
});
test('receipt copied logs resist mutation; host-linked runtime and exact mined identities are mandatory',async()=>{
  const f=await capture();const tx=f.install(f.capture,'indexed');const raw=f.state.receipts.get(tx.txHash);
  f.state.hooks.transaction=()=>{raw.logs.at(-1).topics[1]=H(3);};await w.reconcileScopedPolicyInventoryV2Receipt(f.provider,f.capture,tx.txHash,tx.options);
  for(const variant of ['worker','link','from','removed','outer']){const g=await capture();const t=g.install(g.capture);const r=g.state.receipts.get(t.txHash);
    if(variant==='worker'||variant==='link')g.state.hooks.code=(address,tag)=>{if(tag===100&&address===(variant==='worker'?g.deployment.workers.source.address:g.deployment.linkedDependencies[0].address))g.state.code.set(address,'0x6001');};
    if(variant==='from')r.from=A(9);if(variant==='removed')r.logs[0].removed=true;if(variant==='outer')g.state.transactions.get(t.txHash).data='0x'+'00'.repeat(2097152+16385);
    await assert.rejects(w.reconcileScopedPolicyInventoryV2Receipt(g.provider,g.capture,t.txHash,t.options));}
});
test('refusal distinguishes original revert from RPC failure and reports observation equality without rollback proof',async()=>{
  const f=await capture('appendNative');f.state.hooks.call=tx=>{if(tx.blockTag===91&&tx.data===f.capture.prepared.call.data)throw Object.assign(Error('late failure'),{code:'CALL_EXCEPTION'});};
  const result=await w.observeScopedPolicyInventoryV2Refusal(f.provider,f.capture,{blockTag:91,gasLimit:f.gasLimit});
  assert.equal(result.outcome,'execution-reverted');assert.equal(result.retainedStateUnchanged,true);assert.equal(result.rollbackProven,false);
  f.state.hooks.call=tx=>{if(tx.blockTag===91&&tx.data===f.capture.prepared.call.data)throw Error('transport');};
  assert.equal((await w.observeScopedPolicyInventoryV2Refusal(f.provider,f.capture,{blockTag:91,gasLimit:f.gasLimit})).outcome,'rpc-failed');
});
test('input snapshots and finite block/gas/runtime/canonical-response bounds refuse contradictory evidence',async()=>{
  const f=setup(),q=structuredClone(f.prepare()),d=structuredClone(f.deployment),opts=f.options();
  f.state.hooks.network=()=>{d.core=A(6);q.scope.collectionId=999n;opts.blockTag=91;};
  const captured=await w.captureScopedPolicyInventoryV2(f.provider,d,f.caller,q,opts);
  assert.equal(captured.deployment.core,A(1));assert.equal(captured.observed.blockNumber,90);
  const g=setup();const request=g.prepare();await assert.rejects(w.captureScopedPolicyInventoryV2(g.provider,g.deployment,g.caller,request,{...g.options(),gasLimit:100000001n}));
  g.state.raw=(name,raw)=>name==='dependencyHash'?raw+'00':raw;await assert.rejects(w.captureScopedPolicyInventoryV2(g.provider,g.deployment,g.caller,request,g.options()),/canonical|invalid length/);
});

test('original PRESENT0 and WAIVED1 remain distinct from malformed enum values and wrong selected branch',async()=>{
  for(const kind of ['appendInterview','appendInterviewWaiver']){const f=await capture(kind);assert.equal(f.context.conservation.interviewStatus,kind==='appendInterview'?0n:1n);}
  const f=setup({interviewWaiver:true});const q=f.prepare('appendInterview');
  await assert.rejects(w.captureScopedPolicyInventoryV2(f.provider,f.deployment,f.caller,q,f.options()),/branch/);
  const g=setup();const request=g.prepare();g.context.conservation.interviewStatus=2n;
  await assert.rejects(w.captureScopedPolicyInventoryV2(g.provider,g.deployment,g.caller,request,g.options()),/enum/);
});
