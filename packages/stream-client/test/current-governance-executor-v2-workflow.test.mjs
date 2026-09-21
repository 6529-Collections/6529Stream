import test from 'node:test';
import assert from 'node:assert/strict';
import * as workflow from '../dist/current-governance-executor-v2-workflow.js';
import * as pure from '../dist/current-governance-executor-v2.js';
import { A, H, Z, ZA, copy, setup, methods, executorABI, safeABI, coder } from './current-governance-executor-v2-workflow-fixture.mjs';
// These are compiler-encoded mocked observations, never native execution or signer evidence.
const capture = f => workflow.captureGovernanceExecutorV2(f.provider,f.deployment,f.caller,f.request,f.options);
const simulate = (f,c,blockTag=20) => workflow.simulateGovernanceExecutorV2(f.provider,c,{blockTag,gasLimit:9_000_000n});
const reconcile = (f,c,m) => workflow.reconcileGovernanceExecutorV2Receipt(f.provider,c,m.hash,m.options);
const history = (f,blockTag=20) => workflow.inspectGovernanceExecutorV2History(f.provider,f.historyDeployment,f.actionId,{blockTag,gasLimit:9_000_000n,schedule:f.historical});
function reindex(receipt) { receipt.logs.forEach((v,index)=>v.index=index); }
for(const method of methods) test(`sealed original ${method}: direct and both Safe layouts preserve exact value and lifecycle`,async()=>{
  for(const mode of ['direct','legacy','indexed']) {
    const f=setup(method),c=await capture(f),s=await simulate(f,c);assert.equal(s.originalCallAdmissionChecked,true);assert.equal(s.targetEffectsIndependentlyVerified,false);
    assert.equal(f.state.calls.at(-1).from,f.caller);assert.equal(f.state.calls.at(-1).value,c.prepared.call.value);
    const m=f.mine(c,mode,{outerValue:3n,guardLog:true}),r=await reconcile(f,c,m);
    assert.equal(r.execution,mode==='direct'?'direct':'safe');assert.equal(r.originalCallReceiptAuthenticated,true);assert.equal(r.targetEffectsIndependentlyVerified,false);
    assert.equal(r.sameBlockIntermediateEffectsIndependentlyVerified,false);
  }
});

test('stored expiry is distinct from virtual expiry and materialization; both execution endpoints are inclusive',async()=>{
  const f=setup('materializeExpiredAction'),h=await history(f);assert.equal(h.action.status,4n);assert.equal(h.facts.status,1n);
  const c=await capture(f),m=f.mine(c);const r=await reconcile(f,c,m);assert.equal(r.action.status,4n);
  for(const endpoint of ['notBefore','expiresAfter']) {const g=setup('executeGovernanceAction');g.state.time.set(20,g.action[endpoint]);await capture(g);}
  const g=setup('materializeExpiredAction');g.state.time.set(20,g.action.expiresAfter);await assert.rejects(capture(g),/strictly expired/);
  const e=setup('executeGovernanceAction');e.state.time.set(20,e.action.expiresAfter+1n);await assert.rejects(capture(e),/execution window/);
});

test('cancel accepts revoked original proposer while veto requires current role and strictly earlier deadline',async()=>{
  const f=setup('cancelGovernanceAction');f.state.root=A(150);f.state.codes.set(A(150),f.runtime);f.state.proposer=false;f.state.canceller=false;
  const c=await capture(f);await reconcile(f,c,f.mine(c));
  const v=setup('vetoTerminalFreeze');v.state.time.set(20,v.action.notBefore);await assert.rejects(capture(v),/Veto deadline/);
  const no=setup('vetoTerminalFreeze');no.state.granted=false;await assert.rejects(capture(no),/veto guardian/);
  const drift=setup('vetoTerminalFreeze');drift.state.roleDrift=true;await capture(drift); // no old guardian-commitment reauthorization on veto
});

test('class2 scheduling authenticates raw elapsed swap-pop, historical capacity and distinct per-call scopes',async()=>{
  const f=setup('scheduleGovernanceBatch',{actionClass:2n,batchSize:2});
  const dead=f.addMember({deadline:f.now-1n,nonce:8n}),live=f.addMember({deadline:f.now+1000n,nonce:9n}),dead2=f.addMember({deadline:f.now,nonce:10n});
  const c=await capture(f);assert.equal(c.observation.memberships.length,2);assert.equal(c.observation.memberships[0].rows[0].usesRootCapacity,false);
  const m=f.mine(c),r=await reconcile(f,c,m);assert.deepEqual(r.memberships[0].rows.map(v=>v.actionId),[live.actionId,c.observation.actionId]);
  assert.ok(!r.memberships[0].rows.some(v=>[dead.actionId,dead2.actionId].includes(v.actionId)));
  const bad=copy(m.receipt.logs.find(l=>l.topics[0]===executorABI.getEvent('TerminalFreezeActionMembershipUpdated').topicHash));
  const decoded=executorABI.decodeEventLog('TerminalFreezeActionMembershipUpdated',bad.data,bad.topics);const values=Array.from(decoded);values[5]=3n;
  const encoded=executorABI.encodeEventLog('TerminalFreezeActionMembershipUpdated',values);Object.assign(m.receipt.logs[0],encoded);
  await assert.rejects(reconcile(f,c,m),/Membership mutation/);
});

test('prune can be eventless, removes at exact veto deadline, and leaves raw action status and pending count intact',async()=>{
  const f=setup('pruneElapsedTerminalFreezeActions');f.state.beforePages.clear();const c=await capture(f),m=f.mine(c);assert.equal(m.receipt.logs.length,0);await reconcile(f,c,m);
  const g=setup('pruneElapsedTerminalFreezeActions');g.state.time.set(20,g.action.notBefore);g.state.time.set(21,g.action.notBefore);g.state.time.set(22,g.action.notBefore);
  const gc=await capture(g),gm=g.mine(gc),r=await reconcile(g,gc,gm);assert.equal(r.memberships[0].rows.length,0);assert.equal((await history(g,22)).facts.status,1n);
});

test('execution after prior prune permits no cleanup event; wrong membership index/order is refused',async()=>{
  const f=setup('executeGovernanceBatch',{actionClass:2n});f.state.beforePages.clear();const c=await capture(f),m=f.mine(c);await reconcile(f,c,m);
  const g=setup('executeGovernanceBatch',{actionClass:2n,batchSize:2}),gc=await capture(g),gm=g.mine(gc);
  const rows=gm.receipt.logs.filter(l=>l.topics[0]===executorABI.getEvent('TerminalFreezeActionMembershipUpdated').topicHash);assert.equal(rows.length,2);
  const x=copy(rows[0]);Object.assign(rows[0],{topics:rows[1].topics,data:rows[1].data});Object.assign(rows[1],{topics:x.topics,data:x.data});
  await assert.rejects(reconcile(g,gc,gm),/Membership mutation/);
});

test('publication retry is eventless and deliberately does not reread the old carrier',async()=>{
  const f=setup('publishGovernanceCallData');f.state.publishedBefore=true;f.state.codes.set(f.pointer,'0x');const c=await capture(f);
  const m=f.mine(c);assert.equal(m.receipt.logs.length,0);await simulate(f,c);await reconcile(f,c,m);
  const g=setup('publishGovernanceCallData'),gc=await capture(g),gm=g.mine(gc);g.state.codes.set(g.pointer,'0x');await assert.rejects(reconcile(g,gc,gm),/STOP calldata/);
});

test('scheduleBatch needs prior exact ordered publication; history preserves duplicate calldata',async()=>{
  const f=setup('scheduleGovernanceBatch',{batchSize:2});const c=await capture(f);assert.deepEqual(c.observation.callDatas,['0x12345678','0x12345678']);await reconcile(f,c,f.mine(c));
  const g=setup('scheduleGovernanceBatch');g.state.publishedBefore=false;await assert.rejects(capture(g),/must be published/);
  const bad=setup('scheduleGovernanceBatch');bad.state.codes.set(bad.pointer,`0x00${coder.encode(['bytes[]'],[['0x87654321']]).slice(2)}`);await assert.rejects(capture(bad),/ordered calldata/);
});

test('current capture validates root/proposer/catalog and saved class2 guardian state; original simulation decides private revisions',async()=>{
  const f=setup('scheduleGovernanceAction');f.state.root=A(151);f.state.codes.set(A(151),f.runtime);f.state.proposer=false;await assert.rejects(capture(f),/root\/proposer/);
  const g=setup('executeGovernanceBatch');g.state.sourceDrift=true;await assert.rejects(capture(g),/catalog changed/);
  const h=setup('executeGovernanceBatch',{actionClass:2n});h.state.roleDrift=true;await assert.rejects(capture(h),/guardian commitment changed/);
  const k=setup('executeGovernanceBatch'),c=await capture(k);k.state.simulateError={code:'CALL_EXCEPTION',data:'0x12345678'};await assert.rejects(simulate(k,c),e=>e.code==='CALL_EXCEPTION');
});

test('sealed profile, target pin and native value receiver are distinct; mined native drift is refused',async()=>{
  const f=setup('scheduleGovernanceAction');f.state.sealed=false;await assert.rejects(capture(f),/sealed/);
  const g=setup('executeGovernanceBatch');g.deployment.targets=[];await assert.rejects(capture(g),/target runtime pin/);
  const n=setup('scheduleGovernanceAction',{native:true,actionClass:1n});n.deployment.targets=[];const c=await capture(n);assert.equal(c.observation.targetRuntimes[0].empty,true);
  const m=n.mine(c);await reconcile(n,c,m);n.state.codeOverride=(a,t)=>a===n.calls[0].target&&t===22?n.runtime:undefined;
  await assert.rejects(reconcile(n,c,m),/Native receiver runtime changed/);
});

test('receipt direct amount/caller/data and signed Safe inner amount/op/hash/outer value are independently bound',async()=>{
  const f=setup('executeGovernanceBatch'),c=await capture(f),m=f.mine(c);m.tx.value++;await assert.rejects(reconcile(f,c,m),/Direct caller\/target\/data\/value/);m.tx.value--;
  m.tx.data+='00';await assert.rejects(reconcile(f,c,m),/Direct caller/);
  const g=setup('executeGovernanceBatch'),gc=await capture(g),gm=g.mine(gc,'indexed',{outerValue:3n});
  await assert.rejects(workflow.reconcileGovernanceExecutorV2Receipt(g.provider,gc,gm.hash,{...gm.options,outerValue:4n}),/outer value/);
  await assert.rejects(workflow.reconcileGovernanceExecutorV2Receipt(g.provider,gc,gm.hash,{...gm.options,expectedSafeTxHash:H(1234)}),/Safe hash/);
  const decoded=Array.from(safeABI.decodeFunctionData('execTransaction',gm.tx.data));decoded[1]++;gm.tx.data=safeABI.encodeFunctionData('execTransaction',decoded);await assert.rejects(reconcile(g,gc,gm),/inner payable CALL/);
});

test('Safe failures/duplicate/malformed evidence and nonce drift refuse while unrelated post-success guard logs remain valid',async()=>{
  const f=setup('executeGovernanceAction'),c=await capture(f),m=f.mine(c,'legacy',{guardLog:true});await reconcile(f,c,m);
  f.state.afterSafeNonce++;await assert.rejects(reconcile(f,c,m),/ending nonce/);f.state.afterSafeNonce--;
  const success=m.receipt.logs.find(l=>l.topics[0]===safeABI.getEvent('ExecutionSuccess').topicHash);success.data+='00'.repeat(32);await assert.rejects(reconcile(f,c,m),/Noncanonical ExecutionSuccess/);
  const g=setup('executeGovernanceAction'),gc=await capture(g),gm=g.mine(gc,'legacy');const last=gm.receipt.logs.at(-1);gm.receipt.logs.push(copy(last));reindex(gm.receipt);await assert.rejects(reconcile(g,gc,gm),/Exactly one/);
});

test('one lifecycle attribution refuses earlier/same-block receipts and changed preceding block state',async()=>{
  const f=setup('executeGovernanceAction'),c=await capture(f),m=f.mine(c);f.state.readOverride=({name,tag,host})=>name==='governanceNonce'&&tag===21?host.encodeFunctionResult(name,[7n]):undefined;
  await assert.rejects(reconcile(f,c,m),/observations changed/);
  const g=setup('executeGovernanceAction'),gc=await capture(g),gm=g.mine(gc);gm.receipt.blockNumber=20;gm.receipt.blockHash=g.header(20).hash;gm.tx.blockNumber=20;gm.tx.blockHash=gm.receipt.blockHash;gm.receipt.logs.forEach(l=>{l.blockNumber=20;l.blockHash=gm.receipt.blockHash;});
  await assert.rejects(reconcile(g,gc,gm),/Receipt must follow/);
});

test('receipt checks exact lifecycle fields/order, cleared executing context, nonce and pending deltas',async()=>{
  const f=setup('scheduleGovernanceAction'),c=await capture(f),m=f.mine(c);const policy=m.receipt.logs.pop();m.receipt.logs.unshift(policy);reindex(m.receipt);await assert.rejects(reconcile(f,c,m),/event order/);
  const g=setup('executeGovernanceAction'),gc=await capture(g),gm=g.mine(gc);g.state.after.pending=5n;await assert.rejects(reconcile(g,gc,gm),/pending count/);g.state.after.pending=0n;
  g.state.readOverride=({name,tag,host})=>name==='currentAction'&&tag===22?host.encodeFunctionResult(name,[true,g.actionId,0n,Z,Z,Z]):undefined;await assert.rejects(reconcile(g,gc,gm),/executing context/);
});

test('history authenticates schedule nonce and carrier without today root/roles/targets; altered locator and retained identity reject',async()=>{
  const f=setup('executeGovernanceBatch');for(const a of [f.caller,f.deployment.roleRegistry.address,f.calls[0].target])f.state.codes.delete(a);
  const h=await history(f);assert.equal(h.currentAuthorityChecked,false);assert.equal(h.schedule.nonce,5n);assert.equal(h.targetEffectsIndependentlyVerified,false);
  await assert.rejects(workflow.inspectGovernanceExecutorV2History(f.provider,f.historyDeployment,f.actionId,{blockTag:20,gasLimit:9_000_000n,schedule:{...f.historical,logIndex:f.historical.logIndex+1}}),/Scheduled locator/);
  f.state.actions.get(f.actionId).reasonHash=H(999);await assert.rejects(history(f),/Retained action/);
});

test('owned inputs/captures, copied receipt logs, canonical reads and fixed headers resist mutation',async()=>{
  const f=setup('executeGovernanceAction');const expected=copy(f.request);f.state.mutate=()=>{f.request.callData='0xdeadbeef';f.options.blockTag=99;};const c=await capture(f);assert.deepEqual(c.prepared.request,expected);assert.equal(c.observed.blockNumber,20);
  await assert.rejects(simulate(f,copy(c)),/workflow instance/);
  const m=f.mine(c);f.state.transactionHook=hash=>{if(hash===m.hash)m.receipt.logs[0].data='0x';};await reconcile(f,c,m);
  const g=setup('executeGovernanceAction');g.state.readOverride=({name,host})=>name==='governanceNonce'?`${host.encodeFunctionResult(name,[6n])}${'00'.repeat(32)}`:undefined;await assert.rejects(capture(g),/Noncanonical RPC/);
});

test('refusal pins original runtime/sealed state, rejects older blocks, and distinguishes actual success from genuine CALL_EXCEPTION',async()=>{
  const f=setup('executeGovernanceAction'),c=await capture(f);
  await assert.rejects(workflow.observeGovernanceExecutorV2Refusal(f.provider,c,{blockTag:19,gasLimit:9_000_000n}),/predates/);
  await assert.rejects(simulate(f,c,19),/predates/);
  f.state.codes.set(f.deployment.linkedDependencies[0].address,'0x6002');await assert.rejects(workflow.observeGovernanceExecutorV2Refusal(f.provider,c,{blockTag:20,gasLimit:9_000_000n}),/runtime/i);
  f.state.codes.set(f.deployment.linkedDependencies[0].address,f.runtime);f.state.simulateError={code:'CALL_EXCEPTION',data:'0x12345678',secret:'credential'};
  const r=await workflow.observeGovernanceExecutorV2Refusal(f.provider,c,{blockTag:20,gasLimit:9_000_000n});assert.equal(r.status,'reverted');assert.equal(JSON.stringify(r,(_,v)=>typeof v==='bigint'?String(v):v).includes('credential'),false);
  f.state.simulateError=null;f.state.sourceDrift=true;const success=await workflow.observeGovernanceExecutorV2Refusal(f.provider,c,{blockTag:20,gasLimit:9_000_000n});assert.equal(success.status,'succeeded');assert.equal(success.capturePredictionChecked,false);
});

test('mined library/target pins and captured block reorgs reject without claiming target effect proofs',async()=>{
  const f=setup('executeGovernanceAction'),c=await capture(f),m=f.mine(c);f.state.codeOverride=(a,t)=>a===f.deployment.linkedDependencies[0].address&&t===22?'0x6002':undefined;await assert.rejects(reconcile(f,c,m),/runtime/i);
  f.state.codeOverride=null;f.state.blocks.set(20,H(123456));await assert.rejects(reconcile(f,c,m),/changed|reorg/i);
});

test('client allocation limits reject excess locators/calls and block tags before any RPC; zero cancellation reason remains valid',async()=>{
  const f=setup('cancelGovernanceAction');assert.equal((await capture(f)).prepared.request.reasonHash,Z);
  const g=setup('publishGovernanceCallData');await assert.rejects(workflow.captureGovernanceExecutorV2(g.provider,g.deployment,g.caller,g.request,{...g.options,blockTag:'latest'}),/concrete block/);assert.equal(g.state.reads.length,0);
  await assert.rejects(workflow.captureGovernanceExecutorV2(g.provider,g.deployment,g.caller,g.request,{...g.options,membershipSchedules:Array.from({length:4097},()=>g.options.membershipSchedules[0])}),/locator client bound/);
});
