// These tests exercise mocked RPC consistency and original compiler encodings, not native execution or signature acceptance.
import test from 'node:test';
import assert from 'node:assert/strict';
import { keccak256 } from 'ethers';
import * as w from '../dist/current-artist-attribution-workflow.js';
import * as a from '../dist/current-artist-attribution.js';
import { setup, methods, A, H, Z, ZA, copy } from './current-artist-attribution-workflow-fixture.mjs';
import { compiledInterfaces } from './current-artist-attribution-source-fixture.mjs';

async function capture(f) {
  if(f.governed){const g=await f.governanceCapture();f.config.governanceCapture=g;return w.captureArtistAttribution(f.provider,f.deployment,f.caller,f.request,{...f.options,governance:g});}
  return w.captureArtistAttribution(f.provider,f.deployment,f.caller,f.request,f.options);
}
async function reconcile(f,c,mode='direct'){const m=f.mine(c,mode);return {mined:m,result:await w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options)};}
function updateArchive(f) {
  const x=f.state.after;x.envelope.payload=a.encodeArtistAttributionArchiveDetail(x.detail);x.raw=a.encodeArtistAttributionArchiveEnvelope(x.envelope);x.contentHash=keccak256(x.raw);f.state.codes.set(x.pointer,`0x00${x.raw.slice(2)}`);
  const iface=compiledInterfaces.archive,encoded=iface.encodeEventLog(iface.getEvent('ArtistArchiveEvidenceAppendedV2'),[x.evidenceId,1n,x.contentHash,x.pointer,BigInt((x.raw.length-2)/2)]);
  for(const receipt of f.state.receipts.values())for(const row of receipt.logs)if(row.address===f.deployment.archive.address)Object.assign(row,encoded);
}
const history=(f,m)=>w.inspectArtistAttributionHistory(f.provider,f.historyDeployment,{operationId:f.prepared.operationId,actor:f.caller,value:m.facts.value},{blockTag:22,gasLimit:9_000_000n});

for(const kind of methods)test(`original ${kind} capture, actual call and direct receipt`,async()=>{
  const f=setup(kind),c=await capture(f);
  assert.equal(c.originalCallAdmissionChecked,false);
  const simulation=await w.simulateArtistAttribution(f.provider,c,f.options);assert.equal(simulation.originalCallAdmissionChecked,true);
  const {mined,result}=await reconcile(f,c);assert.equal(result.originalArchiveAndPublicStateVerified,true);assert.equal(result.privateAuxiliaryEffectsIndependentlyReconstructed,false);
  assert.equal(result.history.envelope.value,mined.facts.value);assert.equal(result.history.currentAuthorizationChecked,false);
  const retained=await history(f,mined);assert.deepEqual(retained.record,result.history.record);
});

test('governed opening composes actual Executor execution and class-zero proposer record',async()=>{
  const f=setup('openAttributionDispute',{governed:true}),c=await capture(f);
  const simulation=await w.simulateArtistAttribution(f.provider,c,f.options);
  assert.equal(simulation.originalCallAdmissionChecked,true);
  assert.ok(!f.state.reads.some(v=>v.to===f.deployment.registry.address&&v.data===c.prepared.call.data),'No Registry caller impersonation');
  const {result}=await reconcile(f,c);assert.equal(result.history.record.authorityClass,0n);assert.equal(result.history.record.signer,f.governance.caller);
  assert.equal(result.history.envelope.after_[2].revision,result.history.envelope.before_[2].revision);
});

test('direct and both official Safe event encodings retain zero CALL and independent hash joins',async()=>{
  for(const mode of ['direct','legacy','indexed'])for(const kind of ['fileAttributionClaim','recordCounterStatement','executeAttributionRepudiation']){
    const f=setup(kind),c=await capture(f),{result}=await reconcile(f,c,mode);
    assert.equal(result.execution,mode==='direct'?'direct':'safe');assert.equal(result.ownerSignaturesIndependentlyVerified,false);
  }
});

test('governed target composes both Safe transport encodings without a synthetic governance capture',async()=>{
  for(const mode of ['legacy','indexed']){const f=setup('resolveAttributionDispute'),c=await capture(f);await reconcile(f,c,mode);}
  const f=setup('resolveAttributionDispute');await assert.rejects(w.captureArtistAttribution(f.provider,f.deployment,f.caller,f.request,f.options),/actual Executor/);
});

test('signed digest and consumed nonce are actual original read joins',async()=>{
  const f=setup();f.state.override=({host,name})=>name==='attributionDisputeDigest'?host.encodeFunctionResult(name,[H(9900)]):undefined;
  await assert.rejects(capture(f),/signing digest/);
  const g=setup(),c=await capture(g);g.state.nonceUsed=true;await assert.rejects(w.simulateArtistAttribution(g.provider,c,g.options),/nonce already used/);
});

test('relayed signed caller remains separate from recorded signer and original call admission',async()=>{
  const f=setup('recordCounterStatement',{relayed:true}),c=await capture(f);assert.notEqual(f.caller,f.state.identity.authorityAddress);
  const {result}=await reconcile(f,c);assert.equal(result.history.detail.proof.direct,false);
  const g=setup('recordCounterStatement',{relayed:true}),gc=await capture(g);g.state.simulationError=Object.assign(Error('mock original signature refusal'),{code:'CALL_EXCEPTION',data:'0x12345678'});
  await assert.rejects(w.simulateArtistAttribution(g.provider,gc,g.options),/signature refusal/);
  const refusal=await w.observeArtistAttributionRefusal(g.provider,gc,g.options);assert.equal(refusal.status,'reverted');
});

test('preawait ownership freezes requests and options and rejects forged captures',async()=>{
  const f=setup(),q=copy(f.request),options=copy(f.options);f.state.mutate=()=>{q.filing.reasonHash=H(9910);options.blockTag=500;};
  const c=await w.captureArtistAttribution(f.provider,f.deployment,f.caller,q,options);assert.equal(c.prepared.request.filing.reasonHash,f.request.filing.reasonHash);assert.equal(c.observed.blockNumber,20);
  await assert.rejects(w.simulateArtistAttribution(f.provider,copy(c),f.options),/workflow instance/);
});

test('current-state drift, earlier blocks and capture reorg fail before simulation',async()=>{
  const f=setup(),c=await capture(f);f.state.snapshots[4].stateRoot=H(9911);await assert.rejects(w.simulateArtistAttribution(f.provider,c,f.options),/facts changed/);
  const g=setup(),gc=await capture(g);await assert.rejects(w.simulateArtistAttribution(g.provider,gc,{...g.options,blockTag:19}),/predates/);
  g.governance.state.blocks.set(20,H(9912));await assert.rejects(w.observeArtistAttributionRefusal(g.provider,gc,g.options),/Pinned block changed/);
});

test('refusal observation reports successful changed original result without stale prediction',async()=>{
  const f=setup('fileAttributionClaim'),c=await capture(f);f.state.claims=[4n,H(4000)];const out=await w.observeArtistAttributionRefusal(f.provider,c,{...f.options,blockTag:21});assert.equal(out.status,'succeeded');assert.equal(out.capturePredictionChecked,false);
  f.state.codeOverride=(address)=>address===f.deployment.registry.address?'0x6002':undefined;
  await assert.rejects(w.observeArtistAttributionRefusal(f.provider,c,f.options),/runtime differs/);
});

test('receipt requires exact actual caller, bytes, value and later block',async()=>{
  for(const mutation of [m=>m.transaction.from=A(4567),m=>m.transaction.data='0x12345678',m=>m.transaction.value=1n]){
    const f=setup('fileAttributionClaim'),c=await capture(f),m=f.mine(c);mutation(m);await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/envelope|caller|value/i);
  }
});

test('receipt pins mined runtime and refuses a concurrent owner commit',async()=>{
  const f=setup(),c=await capture(f),m=f.mine(c);f.state.codeOverride=(address,tag)=>address===f.deployment.linkedDependencies[0].address&&tag===22?'0x6002':undefined;
  await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/runtime differs/);
  const g=setup(),gc=await capture(g),gm=g.mine(gc);g.state.after.after[4].revision+=1n;
  await assert.rejects(w.reconcileArtistAttributionReceipt(g.provider,gc,gm.hash,gm.options),/end state|owner commit/);
});

test('receipt domain event order and Archive content/carrier joins reject corruption',async()=>{
  const f=setup(),c=await capture(f),m=f.mine(c);const first=m.receipt.logs[0],second=m.receipt.logs[1];[first.topics,second.topics]=[second.topics,first.topics];[first.data,second.data]=[second.data,first.data];
  await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/event order/);
  const g=setup(),gc=await capture(g),gm=g.mine(gc);g.state.codes.set(gm.facts.pointer,'0x0060');await assert.rejects(w.reconcileArtistAttributionReceipt(g.provider,gc,gm.hash,gm.options),/carrier/);
});

test('Safe signatures, independent hash, nonce and post-execution guard log boundary',async()=>{
  const f=setup(),c=await capture(f),m=f.mine(c,'indexed');const last=m.receipt.logs.at(-1);m.receipt.logs.push({...last,address:A(8001),topics:[H(8002)],data:'0x',index:last.index+1});
  await w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options);
  await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,{...m.options,nonce:m.options.nonce+1n}),/hash differs/);
  m.receipt.logs.at(-1).address=f.deployment.owners[4].address;await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/precede Safe/);
});

test('history stays readable after current source and authority retirement; retained bytes bypass dead carrier only',async()=>{
  const f=setup(),c=await capture(f),m=f.mine(c);f.state.current=false;f.state.codeOverride=address=>[f.deployment.core.address,f.deployment.registry.address,f.deployment.owners[2].address].includes(address)?'0x':undefined;
  const result=await history(f,m);assert.equal(result.currentAuthorizationChecked,false);
  f.state.codes.set(m.facts.pointer,'0x');await assert.rejects(history(f,m),/carrier/);
  const retained=await w.inspectArtistAttributionHistory(f.provider,f.historyDeployment,{operationId:f.prepared.operationId,actor:f.caller,value:m.facts.value},{blockTag:22,gasLimit:9_000_000n,retainedPayload:m.facts.raw});assert.equal(retained.contentHash,m.facts.contentHash);
});

test('fully reencoded history rejects operation/action, generation and forged signed digest joins',async()=>{
  for(const change of [x=>x.detail.p.disputeAction=3n,x=>x.detail.admission.binding_.generation=3n,x=>{x.detail.admission.digest=H(8890);x.detail.proof.digest=H(8890);}]){
    const f=setup(),c=await capture(f),m=f.mine(c);change(f.state.after);updateArchive(f);await assert.rejects(history(f,m),/action mismatch|generation differs|digest differs/);
  }
});

test('withdrawal preserves original opener and never reopens repudiation',async()=>{
  const f=setup('withdrawAttributionDispute'),c=await capture(f),m=f.mine(c);f.state.after.record.standing.delegation=H(4500);f.state.after.detail.standing.delegation=H(4500);f.state.after.detail.admission.standing.delegation=H(4500);updateArchive(f);
  await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/Standing changed/);
});

test('veto and cancellation remain available after executableAt; execute honors original deadline',async()=>{
  for(const method of ['vetoAttributionRepudiation','cancelAttributionRepudiation']){const f=setup(method),c=await capture(f);assert.ok(BigInt(f.header(22).timestamp)>f.priorRepudiation.executableAt);await reconcile(f,c);}
  const f=setup('executeAttributionRepudiation');f.governance.state.time.set(22,f.priorRepudiation.executableAt-1n);const c=await capture(f),m=f.mine(c);await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/precedes deadline/);
});

test('veto authenticates original Contest, Cause, Identity prior facts and ordered native receipts',async()=>{
  const f=setup('vetoAttributionRepudiation'),c=await capture(f),m=f.mine(c);f.state.after.identityNative.reverse();await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/Contest native/);
  const g=setup('vetoAttributionRepudiation'),gc=await capture(g),gm=g.mine(gc);g.state.after.detail.proof.vetoedAt+=1n;updateArchive(g);await assert.rejects(w.reconcileArtistAttributionReceipt(g.provider,gc,gm.hash,gm.options),/Veto proof mined time/);
});

test('noncanonical RPC returns and caller mutation cannot pass a canonical capture',async()=>{
  const f=setup();f.state.override=({host,name})=>name==='binding'?`${host.encodeFunctionResult(name,[f.binding])}${'00'.repeat(32)}`:undefined;
  await assert.rejects(capture(f),/Noncanonical/);
});

test('raw pending phase-one invalidation is ordered and bound for opening and replacement stage',async()=>{
  for(const [kind,pending]of [['openAttributionDispute','active'],['revokeAttribution','stale']]){
    const f=setup(kind,{pending}),c=await capture(f),{result}=await reconcile(f,c);assert.equal(result.originalArchiveAndPublicStateVerified,true);
    const g=setup(kind,{pending}),gc=await capture(g),gm=g.mine(gc);g.state.after.oldTerminal.reasonHash=H(9901);
    await assert.rejects(w.reconcileArtistAttributionReceipt(g.provider,gc,gm.hash,gm.options),/invalidation terminal|replacement terminal/);
  }
  const f=setup('revokeAttribution',{pending:'active'}),c=await capture(f),m=f.mine(c);await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/active repudiation/);
});

test('transport exceptions remain rpc-failed rather than original source refusal',async()=>{
  const f=setup(),c=await capture(f);f.state.simulationError=Object.assign(Error('credential URL must not escape'),{code:'NETWORK_ERROR',url:'https://secret.example/token'});
  const result=await w.observeArtistAttributionRefusal(f.provider,c,f.options);assert.equal(result.status,'rpc-failed');assert.equal(result.data,null);assert.ok(!JSON.stringify(result,(_,v)=>typeof v==='bigint'?v.toString():v).includes('secret'));
});

test('active notices require exact op42 cancellation rows and original signer event order',async()=>{
  for(const kind of ['openAttributionDispute','recordCounterStatement','revokeAttribution','cancelAttributionRepudiation','withdrawAttributionDispute']){
    const f=setup(kind,{activeNotice:true,relayed:kind==='recordCounterStatement'}),c=await capture(f),m=f.mine(c);
    await w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options);
    assert.equal(m.facts.cancellation.actor,kind==='cancelAttributionRepudiation'?f.caller:m.facts.detail.proof.signer);
    m.facts.identityNative.length=0;
    await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/Activity cancellation native count differs/);
  }
  const f=setup('recordCounterStatement',{activeNotice:true,relayed:true}),c=await capture(f),m=f.mine(c);
  m.facts.identityNative[0].operation=43n;
  await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/Unexpected auxiliary Identity receipt/);
  m.facts.identityNative[0].operation=42n;
  const activity=m.receipt.logs.splice(0,2);m.receipt.logs.splice(m.receipt.logs.length-1,0,...activity);m.receipt.logs.forEach((v,i)=>v.index=i);
  await assert.rejects(w.reconcileArtistAttributionReceipt(f.provider,c,m.hash,m.options),/Original activity event order differs/);
});

test('governed captured target calldata, context and Registry actor cannot be substituted',async()=>{
  const f=setup('resolveAttributionDispute'),g=await f.governanceCapture();
  for(const mutate of [v=>v.prepared.request.calls[0].newValueHash=H(777),v=>v.prepared.request.callDatas[0]='0x12345678']){
    const forged=copy(g);mutate(forged);await assert.rejects(w.captureArtistAttribution(f.provider,f.deployment,f.caller,f.request,{...f.options,governance:forged}),/target context|call bytes/);
  }
  await assert.rejects(w.captureArtistAttribution(f.provider,f.deployment,A(998),f.request,{...f.options,governance:g}),/actual Executor/);
});
