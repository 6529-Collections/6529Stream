import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroHash, keccak256 } from 'ethers';
import * as p from '../dist/current-role-registry-operational.js';
import * as w from '../dist/current-role-registry-operational-workflow.js';
import { A, H, copy, setup, registry, safe } from './current-role-registry-operational-workflow-fixture.mjs';
const simulateOptions={blockTag:11,gasLimit:1000000n};
const reconcile=(f,c,m)=>w.reconcileRoleRegistryOperationalReceipt(f.provider,c,m.hash,m.receiptOptions);
const reencode=(row,name,args)=>{const encoded=registry.encodeEventLog(name,args);row.topics=encoded.topics;row.data=encoded.data;};

for(const kind of ['grantRole','revokeRole'])test(`${kind} direct and both Safe layouts capture, simulate, reconcile and read current`,async()=>{
  for(const transport of ['direct','legacy','indexed']){
    const f=setup({kind,transport}),c=await f.capture();
    assert.equal(c.originalCallSimulated,false);assert.equal(c.independentRedundancyVerified,false);
    assert.equal(f.state.calls.filter(x=>x.name===kind).length,0);
    const simulated=await w.simulateRoleRegistryOperational(f.provider,c,simulateOptions);
    assert.equal(simulated.originalCallSimulated,true);
    const invoked=f.state.calls.find(x=>x.name===kind);assert.equal(invoked.from,f.caller);assert.equal(invoked.value,0n);assert.equal(invoked.gasLimit,1000000n);
    const m=f.mine(),h=await reconcile(f,c,m);
    assert.deepEqual(h.after,f.state.after);assert.equal(h.mutationLogIndex,0);assert.equal(h.membershipLogIndex,1);
    assert.equal(h.receiptVerified,true);assert.equal(h.ownerSignaturesIndependentlyVerified,false);assert.equal(h.intraBlockTraceProven,false);
    assert.equal(h.safeTxHash,m.expectedSafeTxHash);
    const current=await w.inspectRoleRegistryOperationalCurrent(f.provider,h,{blockTag:13});
    assert.equal(current.holderCurrentlyGranted,kind==='grantRole');assert.equal(current.managerCurrentlyEnabled,true);assert.equal(current.roleStateUnchanged,true);
  }
});

test('direct manager has no holder-code or redundancy gate, including EIP7702 and same-manager holders',async()=>{
  const f=setup();f.code.set(f.request.holder,'0xef0100'+A(70).slice(2));
  const c=await f.capture();assert.equal(c.independentRedundancyVerified,false);
  assert.ok(!f.state.calls.some(x=>['isRoleRedundant','roleRedundancy','hasAnyTerminalFreezeVetoRole'].includes(x.name)));
  const h=await reconcile(f,c,f.mine());assert.equal(h.independentRedundancyVerified,false);
});

test('registry and owning Executor require original reciprocal sealed code pins',async()=>{
  for(const change of [f=>f.state.sealed=false,f=>f.state.bound=false,f=>f.state.registryOwner=A(99),f=>f.state.executorRegistry=A(99),f=>f.state.registryHash=H('wrong'),f=>f.code.set(f.d.registry.address,'0x6009'),f=>f.code.set(f.d.executor.address,'0xef0100'+A(90).slice(2))]){
    const f=setup();change(f);await assert.rejects(f.capture,/binding|runtime/);
  }
  const f=setup();f.state.chainId=2n;await assert.rejects(f.capture,/chain/);
  const g=setup();g.state.callHook=tx=>tx.name==='roleGrantClass'?[1n]:undefined;await assert.rejects(g.capture,/operational/);
});

test('no-op, revoked manager, u64 exhaustion and bounded holder reads fail before claimed simulation',async()=>{
  for(const change of [f=>f.state.before.managerEnabled=false,f=>f.state.before.holders.push(f.request.holder),
    f=>f.state.before.globalState.revision=(1n<<64n)-1n]){
    const f=setup();change(f);await assert.rejects(f.capture);assert.equal(f.state.calls.filter(x=>x.name==='grantRole').length,0);
  }
  const f=setup();f.state.callHook=tx=>tx.name==='roleHolderCount'?[1025n]:undefined;
  await assert.rejects(f.capture,/holder list limit/);assert.ok(!f.state.calls.some(x=>x.name==='roleHolderAt'));
});

test('role ABA, global interference and manager disable/re-enable stale a saved capture',async()=>{
  for(const change of [row=>row.roleState={chainHash:H('ABA-role'),revision:row.roleState.revision+2n},
    row=>row.globalState={chainHash:H('another-role'),revision:row.globalState.revision+1n},
    row=>row.managerState={chainHash:H('manager-ABA'),revision:row.managerState.revision+2n}]){
    const f=setup(),c=await f.capture();change(f.state.before);
    await assert.rejects(()=>w.simulateRoleRegistryOperational(f.provider,c,simulateOptions),/changed/);
  }
});

test('same-instance capture and detached input guards cannot be bypassed by rebuilding a fingerprint',async()=>{
  const f=setup(),input=copy(f.d),prepared=copy(f.prepared),options={blockTag:10,gasLimit:1000000n};
  const pending=w.captureRoleRegistryOperational(f.provider,input,prepared,options);
  input.registry.address=A(98);prepared.request.holder=A(99);options.blockTag=0;
  const c=await pending;assert.equal(c.deployment.registry.address,f.d.registry.address);assert.equal(c.prepared.request.holder,f.request.holder);
  await assert.rejects(()=>w.simulateRoleRegistryOperational(f.provider,{...c,captureHash:H('forged')},simulateOptions),/same-instance/);
  assert.throws(()=>{c.before.holders.push(A(99));},TypeError);
});

test('actual refusal probes do not assert the old optimistic prestate or leak provider errors',async()=>{
  const f=setup(),c=await f.capture();f.state.before.globalState={chainHash:H('changed'),revision:10n};
  const success=await w.probeRoleRegistryOperationalRefusal(f.provider,c,simulateOptions);
  assert.equal(success.outcome,'success');assert.equal(success.capturePredictionChecked,false);
  const data=registry.encodeErrorResult('RoleAlreadyGranted',[f.request.role,f.request.holder]);
  f.state.originalError=Object.assign(Error('private-provider-message'),{code:'CALL_EXCEPTION',data});
  const refusal=await w.probeRoleRegistryOperationalRefusal(f.provider,c,simulateOptions);
  assert.equal(refusal.outcome,'revert');assert.equal(refusal.revertData,data);
  f.state.originalError=Object.assign(Error('credential=https://private'),{code:'NETWORK_ERROR'});
  await assert.rejects(()=>w.probeRoleRegistryOperationalRefusal(f.provider,c,simulateOptions),e=>/Provider failure/.test(e.message)&&!e.message.includes('credential'));
});

test('history remains valid after current manager revocation and role loss; current reports both losses',async()=>{
  const f=setup(),c=await f.capture(),m=f.mine();
  f.state.current=copy(f.state.after);f.state.current.managerEnabled=false;
  f.state.current.managerState={chainHash:H('revoked-manager'),revision:2n};
  f.state.current.holders=f.state.current.holders.filter(x=>x!==f.request.holder);
  f.state.current.roleState={chainHash:H('revoked-role'),revision:6n};f.state.current.globalState={chainHash:H('later-global'),revision:12n};
  const h=await w.inspectRoleRegistryOperationalHistory(f.provider,f.d,f.prepared,m.hash,m.receiptOptions);
  assert.equal(h.currentAuthorityVerified,false);assert.equal(h.after.managerEnabled,true);
  const current=await w.inspectRoleRegistryOperationalCurrent(f.provider,h,{blockTag:13});
  assert.equal(current.managerCurrentlyEnabled,false);assert.equal(current.holderCurrentlyGranted,false);
  assert.equal(current.roleStateUnchanged,false);assert.equal(current.managerStateUnchanged,false);assert.equal(current.globalStateUnchanged,false);
  await assert.rejects(()=>w.inspectRoleRegistryOperationalCurrent(f.provider,{...h},{blockTag:13}),/same-instance/);
  assert.equal((await reconcile(f,c,m)).receiptVerified,true);
});

test('receipt attribution refuses unrelated same-block global changes, holder order and manager interference',async()=>{
  for(const change of [f=>f.state.after.globalState={chainHash:H('later-global'),revision:11n},
    f=>f.state.after.holders.reverse(),f=>f.state.after.managerEnabled=false,
    f=>f.state.after.roleState={chainHash:H('ABA-role'),revision:7n}]){
    const f=setup(),c=await f.capture();change(f);const m=f.mine();await assert.rejects(()=>reconcile(f,c,m),/interference/);
  }
  const f=setup(),c=await f.capture();f.state.before.globalState={chainHash:H('prior-other'),revision:10n};
  await assert.rejects(()=>reconcile(f,c,f.mine()),/interference|prestate/);
});

test('exact schema/class/actor/actionId and mutation-before-membership events are required',async()=>{
  for(const mode of ['schema','class','actor','action','reverse','extra']){
    const f=setup(),c=await f.capture(),m=f.mine(),rows=m.receipt.logs;
    if(mode==='reverse'){[rows[0],rows[1]]=[rows[1],rows[0]];rows.forEach((x,i)=>x.index=i);}
    else if(mode==='extra')rows.push({...copy(rows[0]),index:2});
    else{
      const args=[mode==='schema'?2n:1n,f.request.role,f.request.holder,mode==='class'?1n:2n,mode==='actor'?A(90):f.caller,mode==='action'?H('borrowed-executor-context'):ZeroHash];
      reencode(rows[1],'StreamRoleGranted',args);
    }
    await assert.rejects(()=>reconcile(f,c,m),/differs|ordering|exactly one/);
  }
});

test('direct envelope, failed receipt, canonical logs and log identity are separately authenticated',async()=>{
  for(const change of [m=>{m.transaction.from=A(99);m.receipt.from=A(99);},m=>m.transaction.data='0x12345678',m=>m.transaction.value=1n,
    m=>m.receipt.status=0,m=>m.receipt.logs[0].removed=true,m=>m.receipt.logs[0].data+='00'.repeat(32),m=>m.receipt.logs[0].transactionHash=H('other')]){
    const f=setup(),c=await f.capture(),m=f.mine();change(m);await assert.rejects(()=>reconcile(f,c,m));
  }
});

test('Safe independent ten-field hash, original getter, nonce and immutable configuration all bind receipt',async()=>{
  for(const mode of ['expected','getter','nonce','inner','owners','failure']){
    const f=setup({transport:'indexed'}),c=await f.capture();
    const m=f.mine(mode==='inner'?{fields:{value:1n}}:mode==='failure'?{outcome:'failure'}:{});
    if(mode==='expected')m.receiptOptions.expectedSafeTxHash=H('wrong-safe-hash');
    if(mode==='getter')f.state.safeHashOverride=H('wrong-original-hash');
    if(mode==='nonce')f.state.endNonce=9n;
    if(mode==='owners')f.state.callHook=tx=>tx.name==='getOwners'&&tx.blockTag===12?[[A(30),A(32)]]:undefined;
    await assert.rejects(()=>reconcile(f,c,m));
  }
});

test('both Safe layouts allow unrelated post-success guard logs but refuse later registry application logs',async()=>{
  for(const transport of ['legacy','indexed']){
    const f=setup({transport}),c=await f.capture(),m=f.mine({signatures:'0x'});
    const h=await reconcile(f,c,m);assert.equal(h.ownerSignaturesIndependentlyVerified,false);
    const mutation=copy(m.receipt.logs.shift());m.receipt.logs.push(mutation);m.receipt.logs.forEach((row,index)=>row.index=index);
    await assert.rejects(()=>reconcile(f,c,m),/ordering|precede/);
  }
});

test('provider-owned receipt logs are copied before subsequent awaits and all observed blocks are rechecked',async()=>{
  const f=setup(),c=await f.capture(),m=f.mine();
  f.state.transactionHook=()=>{m.receipt.logs[0].data='0x';};
  assert.equal((await reconcile(f,c,m)).receiptVerified,true);
  const g=setup(),saved=await g.capture(),mined=g.mine();let n=0;
  g.state.blockHook=tag=>tag===12&&++n>1?{...g.block(12),hash:H('reorg')}:undefined;
  await assert.rejects(()=>reconcile(g,saved,mined),/block changed/);
});

test('noncanonical RPC and resource/snapshot bounds reject without a target-execution claim',async()=>{
  const f=setup();f.state.callHook=tx=>tx.name==='isRoleManager'?{raw:registry.encodeFunctionResult('isRoleManager',[true])+'00'.repeat(32)}:undefined;
  await assert.rejects(f.capture,/Noncanonical/);
  const g=setup(),c=await g.capture();
  await assert.rejects(()=>w.simulateRoleRegistryOperational(g.provider,c,{blockTag:9,gasLimit:1000000n}),/predates/);
  await assert.rejects(()=>w.simulateRoleRegistryOperational(g.provider,c,{blockTag:11,gasLimit:100000001n}),/gas limit/);
  g.state.originalRaw='0x00';await assert.rejects(()=>w.simulateRoleRegistryOperational(g.provider,c,simulateOptions),/bytes/);
  const m=g.mine();m.receipt.logs=Array(65537).fill(m.receipt.logs[0]);await assert.rejects(()=>reconcile(g,c,m),/log limit/);
});

test('captured transport cannot change from direct to Safe and Safe source pins reject designators',async()=>{
  const f=setup(),c=await f.capture(),m=f.mine();
  await assert.rejects(()=>reconcile(f,c,{...m,receiptOptions:{execution:'safe',safe:f.safeDeployment,expectedSafeTxHash:H('hash')}}),/transport/);
  const g=setup({transport:'legacy'});g.code.set(g.safeDeployment.safe.address,'0xef0100'+A(99).slice(2));await assert.rejects(g.capture,/runtime/);
});
