import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroAddress, ZeroHash, id, keccak256 } from 'ethers';
import * as w from '../dist/current-scoped-policy-publication-v2-workflow.js';
import { createSafeCallPlan, verifySafeCallPlan } from '../dist/safe-plan.js';
import { setup, A, H, pub, c, safe, coder } from './current-scoped-policy-publication-v2-workflow-fixture.mjs';
const at={blockTag:10}, sim={blockTag:11,gasLimit:30_000_000n};
const capture=(f,r)=>w.captureScopedPolicyPublicationV2(f.provider,f.deployment,f.scope,f.caller,r,at);
function forKind(kind, extra={}) {return setup({contentKnown:kind!=='begin',contentBefore:['beginManifest','verifyNextOutputs','publishSnapshot'].includes(kind)?1:0,
  outputKnown:kind!=='beginManifest',...extra});}
async function receipt(f,saved,mode='direct'){const x=f.install(saved,mode);return w.reconcileScopedPolicyPublicationV2Receipt(f.provider,saved,x.txHash,x.options);}

test('all five original zero-value writes capture, simulate, and reconcile direct and both Safe layouts',async()=>{
  for(const kind of ['begin','append','beginManifest','verifyNextOutputs','publishSnapshot']) {
    for(const mode of ['direct','legacy','indexed']) {
      const f=forKind(kind),saved=await capture(f,f.request(kind));
      assert.equal(saved.prepared.call.value,0n);
      if(mode==='direct'){
        const checked=await w.simulateScopedPolicyPublicationV2(f.provider,saved,sim);
        assert.equal(checked.persisted,false);
        const rpc=f.state.calls.findLast(x=>x.method===kind);
        assert.equal(rpc.tx.from,f.caller);assert.equal(rpc.tx.value,0n);assert.equal(rpc.tx.gasLimit,sim.gasLimit);
      }
      const result=await receipt(f,saved,mode);
      assert.equal(result.eventlessRetry,false);assert.equal(result.finalityEstablished,false);
    }
  }
});

test('true prior checkpoint/manifest begin retries are eventless, but completed append/verify reject',async()=>{
  for(const kind of ['begin','beginManifest']) {
    const f=forKind(kind,{contentKnown:true,contentBefore:1,outputKnown:true,outputBefore:1});
    const saved=await capture(f,f.request(kind));
    assert.equal((await receipt(f,saved,'indexed')).eventlessRetry,true);
  }
  const f=forKind('append',{contentBefore:1});
  await assert.rejects(()=>capture(f,{kind:'append',id:f.checkpointId,payloads:[f.payloads[0]]}),/remaining/);
  await assert.rejects(()=>capture(f,{kind:'verifyNextOutputs',planHash:f.planHash,count:2n}),/remaining/);
});

test('partial checkpoint then final append and partial output verification preserve exact ordered progress',async()=>{
  const f=forKind('append',{count:2,contentBefore:0});
  const saved=await capture(f,{kind:'append',id:f.checkpointId,payloads:[f.payloads[0]]});
  assert.equal(saved.stage.expected.nextIndex,1n);assert.equal(saved.stage.expected.contentRoot,ZeroHash);
  assert.equal((await receipt(f,saved)).result.nextIndex,1n);
  const last=forKind('append',{count:2,contentBefore:1});
  const completed=await capture(last,last.request('append'));
  assert.notEqual((await receipt(last,completed)).result.contentRoot,ZeroHash);
  const out=forKind('verifyNextOutputs',{count:2,contentBefore:2});
  const partial=await capture(out,{kind:'verifyNextOutputs',planHash:out.planHash,count:1n});
  assert.equal((await w.simulateScopedPolicyPublicationV2(out.provider,partial,sim)).returnValues[0],ZeroHash);
  assert.equal((await receipt(out,partial)).result.recordHash,ZeroHash);
  const final=forKind('verifyNextOutputs',{count:2,contentBefore:2,outputBefore:1});
  assert.notEqual((await receipt(final,await capture(final,final.request('verifyNextOutputs')))).result.recordHash,ZeroHash);
});

test('TOKEN RELEASE and SEASON keep complete full-scope identity; COLLECTION and VIEW refuse',async()=>{
  for(const scopeType of [1n,2n,3n]) {
    const scope={scopeType,collectionId:7n,tokenId:scopeType===1n?11n:0n,scopeId:scopeType===1n?ZeroHash:H(710)};
    const f=forKind('begin',{scope});
    assert.deepEqual((await capture(f,f.request('begin'))).scope,scope);
  }
  const f=forKind('begin');
  for(const scopeType of [0n,4n])await assert.rejects(()=>w.captureScopedPolicyPublicationV2(f.provider,f.deployment,
    {...f.scope,scopeType},f.caller,f.request('begin'),at),/TOKEN|scope/);
});

test('completed genuine Selection, full scope and immutable source identities are prerequisites',async()=>{
  for(const fault of ['incomplete','scope','membership','zero-root','unordered']) {
    const f=forKind('append',{count:2});
    f.state.hooks.result=({target,method,values})=>{
      if(target===A(7)&&method==='requireCurrentCheckpoint'){
        const p={...values[0]};
        if(fault==='incomplete')p.nextIndex=0n;if(fault==='scope')p.scope={...p.scope,collectionId:8n};
        if(fault==='membership')p.membershipHash=H(999);if(fault==='zero-root')p.selectionRoot=ZeroHash;
        return [p];
      }
      if(fault==='unordered'&&target===A(7)&&method==='selectionAt')return [{...values[0],tokenId:11n}];
    };
    await assert.rejects(()=>capture(f,f.request('append')),/Selection|selection/);
  }
});

test('current output observations refuse config, source, entropy, terminal admission and supplied animation drift',async()=>{
  const cases={resolvedMetadataConfig:v=>({...v,recordHash:H(9000)}),staticRenderSourceForConfig:v=>({...v,name:'changed'}),
    tokenEntropyReadiness:v=>({...v,finalized:true}),requireTerminalRenderReady:v=>({...v,policyChainHash:H(9001)}),
    tokenHTML:()=>'<html>changed</html>'};
  for(const [method,change]of Object.entries(cases)){
    const f=forKind('append');f.state.hooks.result=e=>e.method===method?[change(e.values[0]),...e.values.slice(1)]:undefined;
    await assert.rejects(()=>capture(f,f.request('append')),/differs|readiness/);
  }
  const f=forKind('append',{count:2,contentBefore:1});
  f.sources[0].json='changed prior output';
  await assert.rejects(()=>capture(f,f.request('append')),/stale/);
});

test('covered output requires current two-family archive, exact documents and STOP-backed complete manifest bytes',async()=>{
  for(const fault of ['family','hash','schema','carrier','definition','byte-definition','header']){
    const f=forKind('beginManifest');
    if(fault==='carrier')f.state.code.set(A(500),'0x01'+f.canonical.slice(2));
    if(fault==='header'){
      const forged=f.canonical.slice(0,-2)+'ff';f.state.code.set(A(500),'0x00'+forged.slice(2));
      f.coverage.contentHash=keccak256(forged);
      f.state.hooks.call=e=>e.method==='artifactChunk'?[A(500),keccak256(f.state.code.get(A(500)))]:undefined;
    }
    f.state.hooks.result=e=>{
      if(e.method==='requireArtifactCoverage')return [{...e.values[0],...(fault==='family'?{secondFamilyRecordHash:f.coverage.firstFamilyRecordHash}
        :fault==='hash'?{artifactHash:H(1)}:fault==='schema'?{schemaId:H(2)}:{})}];
      if(e.method==='document'&&fault==='definition')return [{...e.values[0],status:1n}];
      if(e.method==='documentBytes'&&fault==='byte-definition')return ['0x00'];
    };
    await assert.rejects(()=>capture(f,f.request('beginManifest')),/coverage|Coverage|differ|definition|document|carrier/);
  }
});

test('nonfinal verifier client intentionally requires current graph although source nonfinal byte step alone can proceed',async()=>{
  const f=forKind('verifyNextOutputs',{count:2,contentBefore:2});
  const request={kind:'verifyNextOutputs',planHash:f.planHash,count:1n};
  const plan=pub.prepareScopedPolicyPublicationV2Call(f.coords,f.caller,request);
  f.base.state.failCurrent=true;
  const raw=await f.provider.call({...plan.call,from:f.caller,blockTag:10});
  assert.equal(c.output.decodeFunctionResult('verifyNextOutputs',raw)[0],ZeroHash);
  await assert.rejects(()=>capture(f,request),/source drift|route drift|stale/);
});

test('snapshot preview resolves zero source hash and existing Store chunks are a separate publish prerequisite',async()=>{
  const f=forKind('publishSnapshot');f.state.missingChunks=true;
  const preview=await w.previewScopedPolicyPublicationV2Snapshot(f.provider,f.deployment,{...f.publication,expectedSourceHash:ZeroHash},f.caller,at);
  assert.equal(preview.storeAvailabilityChecked,false);assert.equal(preview.readyPublication.expectedSourceHash,f.publication.expectedSourceHash);
  await assert.rejects(()=>capture(f,{kind:'publishSnapshot',publication:preview.readyPublication}),/Zero address|preuploaded/);
  f.state.missingChunks=false;
  const saved=await capture(f,f.request('publishSnapshot'));
  assert.equal(saved.stage.canonical,f.snapshotBytes());assert.ok(saved.stage.chunks.length>0);
  const decoded=pub.decodeScopedPolicyPublicationV2SnapshotBytes(saved.stage.canonical);
  assert.equal(decoded.publication.expectedSourceHash,ZeroHash);
  assert.equal(saved.prepared.request.publication.expectedSourceHash,f.publication.expectedSourceHash);
});

test('snapshot dual independent grants use class7 collection before class8 global; Artist presentation must be locked',async()=>{
  const f=forKind('publishSnapshot',{displayGlobal:true});
  const saved=await capture(f,f.request('publishSnapshot'));
  assert.equal(saved.stage.receipt.authorizationClass,7n);assert.equal(saved.stage.receipt.displayAuthorizationClass,8n);
  const grants=f.state.calls.filter(x=>x.method==='familyWriter');
  assert.deepEqual(grants.map(x=>[x.args[0],x.args[2]]),[[7n,7n],[7n,7n],[0n,8n]]);
  for(const family of ['6529STREAM_RECORD_FAMILY_SNAPSHOT_V1','6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1']){
    const bad=forKind('publishSnapshot');bad.state.hooks.call=e=>e.method==='familyWriter'&&e.args[1]===id(family)?[false,0n]:undefined;
    await assert.rejects(()=>capture(bad,bad.request('publishSnapshot')),/independent family grant/);
  }
  const bad=forKind('publishSnapshot');bad.artist.locked=false;
  await assert.rejects(()=>capture(bad,bad.request('publishSnapshot')),/locked/);
});

test('snapshot full source hash, lineage, lock and actual publisher preview are independently joined',async()=>{
  for(const fault of ['hash','lineage','lock','preview','publisher']){
    const f=forKind('publishSnapshot');
    const request=f.request('publishSnapshot');
    if(fault==='hash')request.publication={...request.publication,expectedSourceHash:H(9)};
    if(fault==='lineage')request.publication={...request.publication,expectedRevision:1n};
    if(fault==='publisher')request.publication={...request.publication};
    f.state.hooks.result=e=>e.method==='snapshotLock'&&fault==='lock'?[{...e.values[0],actionId:H(3)}]
      :e.method==='previewSnapshot'&&fault==='preview'?[H(2),e.values[1]]:undefined;
    if(fault==='publisher')await assert.rejects(()=>w.captureScopedPolicyPublicationV2(f.provider,f.deployment,f.scope,A(40),request,at),/preview/);
    else await assert.rejects(()=>capture(f,request),/changed|lineage|locked|preview/);
  }
});

test('immutable checkpoint/output/snapshot history survives current graph and source loss',async()=>{
  const f=forKind('publishSnapshot');f.state.contentBefore=1;f.state.outputBefore=1;f.state.publicationPresent=true;
  f.base.state.failCurrent=true;
  for(const a of [A(1),A(2),A(5),A(101),A(103)])f.base.state.missingCode.add(a);
  for(const request of [{kind:'checkpoint',id:f.checkpointId},{kind:'manifestPlan',planHash:f.planHash},
    {kind:'manifestRecord',recordHash:f.recordHash},{kind:'snapshotRecord',recordHash:f.snapshotReceipt(1012n).recordHash}]){
    const result=await w.inspectScopedPolicyPublicationV2History(f.provider,f.historyDeployment,request,{blockTag:20});
    assert.equal(result.currentnessChecked,false);assert.equal(result.finalityEstablished,false);
  }
  await assert.rejects(()=>w.inspectScopedPolicyPublicationV2Current(f.provider,f.deployment,f.scope,{kind:'checkpoint',id:f.checkpointId},at));
});

test('snapshot receipt uses mined timestamp and immutable evidence even after later grant revocation',async()=>{
  const f=forKind('publishSnapshot');const saved=await capture(f,f.request('publishSnapshot'));const tx=f.install(saved,'legacy');
  f.state.hooks.call=e=>e.tag>=12&&e.method==='familyWriter'?[false,0n]:undefined;
  const result=await w.reconcileScopedPolicyPublicationV2Receipt(f.provider,saved,tx.txHash,tx.options);
  assert.equal(result.result.recordedAt,1012n);assert.equal(result.result.recordHash,f.snapshotReceipt(1012n).recordHash);
});

test('missing, reordered, extra or wrong-schema progress/completion events and concurrent end-state progress refuse',async()=>{
  for(const fault of ['missing','reverse','extra','schema','progress']){
    const f=forKind('append',{count:2});const saved=await capture(f,f.request('append'));const tx=f.install(saved);
    const logs=f.base.state.receipt.logs;
    if(fault==='missing')logs.splice(0,1);if(fault==='reverse')logs.reverse();if(fault==='extra')logs.push({...logs[0]});
    if(fault==='schema'){
      const v=c.checkpoint.decodeEventLog('StaticContentAppended',logs[0].data,logs[0].topics);
      const changed=c.checkpoint.encodeEventLog(c.checkpoint.getEvent('StaticContentAppended'),[1n,...v.slice(1)]);Object.assign(logs[0],changed);
    }
    if(fault==='progress')f.state.after.content={...f.state.after.content,nextIndex:1n};
    f.renumber();await assert.rejects(()=>w.reconcileScopedPolicyPublicationV2Receipt(f.provider,saved,tx.txHash,tx.options),/event|progress/);
  }
});

test('snapshot event, payload and carrier must exactly join the immutable record',async()=>{
  for(const fault of ['event','payload','record','carrier']){
    const f=forKind('publishSnapshot');const saved=await capture(f,f.request('publishSnapshot'));const tx=f.install(saved);
    if(fault==='event')f.base.state.receipt.logs=[];
    if(fault==='carrier')f.state.hooks.code=(target,tag)=>tag>=12&&target===A(550)?'0x00ff':undefined;
    f.state.hooks.result=e=>e.tag>=12&&e.method==='snapshotPayload'&&fault==='payload'?['0x00']
      :e.tag>=12&&e.method==='snapshotRecord'&&fault==='record'?[e.values[0],{...e.values[1],recordedAt:1000n}]:undefined;
    await assert.rejects(()=>w.reconcileScopedPolicyPublicationV2Receipt(f.provider,saved,tx.txHash,tx.options),/event|payload|record|carrier/);
  }
});

test('saved block hash, changed source/currentness and changed reviewed prestate require recapture',async()=>{
  for(const fault of ['reorg','source','progress']){
    const f=forKind('append');const saved=await capture(f,f.request('append'));
    if(fault==='reorg')f.base.state.blockHashes.set(10,H(1));
    if(fault==='source')f.base.state.failCurrent=true;
    if(fault==='progress')f.state.hooks.result=e=>e.tag===11&&e.method==='checkpoint'?[{...e.values[0],leafChainHash:H(9)}]:undefined;
    await assert.rejects(()=>w.simulateScopedPolicyPublicationV2(f.provider,saved,sim));
  }
});

test('Safe independent hash, failure, early success, operation1, caller, native value and receipt metadata reject',async()=>{
  for(const fault of ['hash','failure','early','operation','caller','value','removed','metadata','fraction']){
    const f=forKind('begin');const saved=await capture(f,f.request('begin'));const tx=f.install(saved,'indexed');
    const raw=f.base.state.receipt,t=f.base.state.transaction;
    if(fault==='hash')tx.options.expectedSafeTxHash=H(999);
    if(fault==='failure')raw.logs.at(-1).topics[0]=safe.getEvent('ExecutionFailure').topicHash;
    if(fault==='early'){raw.logs.unshift(raw.logs.pop());f.renumber();}
    if(fault==='operation'){const a=safe.decodeFunctionData('execTransaction',t.data);t.data=safe.encodeFunctionData('execTransaction',[a.to,a.value,a.data,1n,...a.slice(4)]);}
    if(fault==='caller'){t.to=A(99);raw.to=A(99);}if(fault==='value')t.value=1n;
    if(fault==='removed')raw.logs[0].removed=true;if(fault==='metadata')delete raw.logs[0].transactionHash;
    if(fault==='fraction')raw.logs[0].index=0.5;
    await assert.rejects(()=>w.reconcileScopedPolicyPublicationV2Receipt(f.provider,saved,tx.txHash,tx.options));
  }
});

test('copied receipt logs resist mutation; unrelated zero indexed topic is legal',async()=>{
  const f=forKind('begin');const saved=await capture(f,f.request('begin'));const tx=f.install(saved,'legacy');
  f.base.state.receipt.logs.unshift({address:A(999),topics:[H(88),ZeroHash],data:'0x'});f.renumber();
  f.base.state.hooks.transaction=()=>{f.base.state.receipt.logs.at(-1).data='0x';};
  assert.equal((await w.reconcileScopedPolicyPublicationV2Receipt(f.provider,saved,tx.txHash,tx.options)).execution,'safe');
});

test('refusal preserves execution error and only reports observed local state, not native rollback',async()=>{
  const f=forKind('append');const saved=await capture(f,f.request('append'));f.state.reject=true;
  const refused=await w.observeScopedPolicyPublicationV2Refusal(f.provider,saved,sim);
  assert.equal(refused.outcome,'execution-reverted');assert.equal(refused.retainedStateUnchanged,true);assert.equal(refused.rollbackProven,false);
  f.state.hooks.call=e=>{if(e.method==='append')throw Object.assign(Error('transport unavailable'),{code:'NETWORK_ERROR'});};
  assert.equal((await w.observeScopedPolicyPublicationV2Refusal(f.provider,saved,sim)).outcome,'rpc-failed');
});

test('snapshot input ownership, finite bounds, runtime pins and generic Safe planner compose original calls',async()=>{
  const f=forKind('begin'),request=f.request('begin'),d=structuredClone(f.deployment);
  f.base.state.hooks.network=()=>{request.salt=H(999);d.linkedDependencies[0].codeHash=H(999);};
  const saved=await capture({...f,deployment:d},request);
  assert.notEqual(saved.prepared.request.salt,H(999));assert.notEqual(saved.deployment.linkedDependencies[0].codeHash,H(999));
  const plan=createSafeCallPlan(1n,'Prepare checkpoint',[{safe:f.caller,intent:'Begin genuine current checkpoint',call:saved.prepared.call,abi:c.checkpoint.fragments}]);
  verifySafeCallPlan(plan,[c.checkpoint.fragments]);assert.equal(plan.steps[0].transaction.operation,0);
  await assert.rejects(()=>w.simulateScopedPolicyPublicationV2(f.provider,saved,{blockTag:9,gasLimit:1n}),/before/);
  await assert.rejects(()=>w.simulateScopedPolicyPublicationV2(f.provider,saved,{blockTag:11,gasLimit:100000001n}),/gas/);
  const bad=forKind('begin');bad.base.state.missingCode.add(A(120));await assert.rejects(()=>capture(bad,bad.request('begin')),/runtime/);
});


test('retained snapshot lineage and source joins reject fully rehashed contradictory evidence',async()=>{
  for(const fault of ['predecessor','revision','scopeSubject','overflow','output-record','collection']) {
    const f=forKind('publishSnapshot');
    const p=structuredClone(f.publication),r=structuredClone(f.snapshotReceipt(1012n));
    const payload=structuredClone(pub.decodeScopedPolicyPublicationV2SnapshotBytes(f.snapshotBytes()));
    if(fault==='predecessor')r.predecessor=H(990);
    if(fault==='revision')r.revision=2n;
    if(fault==='scopeSubject')r.scopeSubject=H(991);
    if(fault==='overflow')p.expectedRevision=(1n<<64n)-1n;
    if(fault==='output-record')p.outputManifestRecord=H(992);
    if(fault==='collection')p.scope={...p.scope,collectionId:8n};
    payload.publication={...p,expectedSourceHash:ZeroHash};
    payload.receipt={...r,recordHash:ZeroHash,chainHash:ZeroHash,manifestHash:ZeroHash,manifestBytes:0n,recordedAt:0n};
    const fields=['bytes32','uint256','address','address[11]','bytes32[11]',pub.SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE,
      pub.SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE,pub.SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE];
    const canonical=coder.encode(fields,[payload.domain,payload.chainId,payload.snapshotHost,payload.targets,payload.codeHashes,
      payload.publication,payload.receipt,payload.source]);
    r.manifestHash=keccak256(canonical);r.manifestBytes=BigInt((canonical.length-2)/2);
    r.recordHash=pub.scopedPolicyPublicationV2SnapshotRecordHash(f.coords,p,r);
    r.chainHash=pub.scopedPolicyPublicationV2SnapshotChainHash(f.coords,p.scope,ZeroHash,r.revision,r.recordHash);
    f.state.hooks.call=e=>e.method==='snapshotRecord'?[p,r]:e.method==='snapshotPayload'?[canonical]:undefined;
    await assert.rejects(()=>w.inspectScopedPolicyPublicationV2History(f.provider,f.historyDeployment,
      {kind:'snapshotRecord',recordHash:r.recordHash},at),fault==='output-record'?/selection\/content\/output join/:fault==='collection'?/source membership|join/:fault==='overflow'?/revision|publication|Publication/:/publication\/receipt lineage/);
  }
});

test('original capped append call remains decisive for inline image and terminal STATIC byte-pattern admission',async()=>{
  for(const fault of ['image','json']) {
    const f=forKind('append');
    const r=f.request('append');
    if(fault==='image')r.payloads=[{...r.payloads[0],image:'0xdeadbeef'}];
    if(fault==='json')f.sources[0].json='{"notTheOriginalTerminalFormat":true}';
    const saved=await capture(f,r);
    f.state.hooks.call=e=>{if(e.method==='append')throw Object.assign(Error(`original ${fault==='image'?'Image.matchesImage':'terminal JSON/data pattern'} refused`),{code:'CALL_EXCEPTION'});};
    await assert.rejects(()=>w.simulateScopedPolicyPublicationV2(f.provider,saved,sim),/original .* refused/);
    const refused=await w.observeScopedPolicyPublicationV2Refusal(f.provider,saved,sim);
    assert.equal(refused.outcome,'execution-reverted');assert.equal(refused.rollbackProven,false);
  }
});

test('partially populated begin retry preserves prior progress without fabricated completion',async()=>{
  const f=forKind('begin',{count:2,contentKnown:true,contentBefore:1});
  const saved=await capture(f,f.request('begin'));
  assert.equal(saved.stage.before.nextIndex,1n);assert.equal(saved.stage.expected.contentRoot,ZeroHash);
  const result=await receipt(f,saved,'indexed');assert.equal(result.eventlessRetry,true);assert.equal(result.result.nextIndex,1n);
});


test('ASYNC_NOT_REQUIRED terminal and finalized native status5 including zero seed retain distinct truthful outputs',async()=>{
  for(const options of [{asyncNotRequired:true},{finalized:true},{finalized:true,zeroSeed:true}]) {
    const f=forKind('append',options),saved=await capture(f,f.request('append'));
    const output=saved.stage.appended[0];
    if(options.asyncNotRequired) {
      assert.equal(output.entropy.status,2n);assert.equal(output.entropy.finalized,false);assert.equal(output.entropy.seed,ZeroHash);
      assert.notEqual(output.terminalAdmissionHash,ZeroHash);
      assert.equal(f.state.calls.some(e=>e.method==='staticTokenRenderFacts'),false);
    } else {
      assert.equal(output.entropy.status,5n);assert.equal(output.entropy.finalized,true);assert.equal(output.terminalAdmissionHash,ZeroHash);
      assert.ok(f.state.calls.some(e=>e.method==='staticTokenRenderFacts'));
      if(options.zeroSeed)assert.equal(output.entropy.seed,ZeroHash);
    }
    await w.simulateScopedPolicyPublicationV2(f.provider,saved,sim);await receipt(f,saved,'indexed');
  }
  for(const field of ['status','seed']) {
    const f=forKind('append',{finalized:true,zeroSeed:true});
    f.state.hooks.result=e=>e.method==='staticTokenRenderFacts'?[field==='status'?4n:5n,field==='seed'?H(999):ZeroHash,A(71)]:undefined;
    await assert.rejects(()=>capture(f,f.request('append')),/Native finalized entropy differs/);
  }
});
