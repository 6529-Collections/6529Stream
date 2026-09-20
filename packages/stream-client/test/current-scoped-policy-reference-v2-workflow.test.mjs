import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroAddress, ZeroHash, id, keccak256 } from 'ethers';
import * as workflow from '../dist/current-scoped-policy-reference-v2-workflow.js';
import { createSafeCallPlan, verifySafeCallPlan } from '../dist/safe-plan.js';
import { fixture } from './current-scoped-policy-reference-v2-fixture.mjs';
import { setup, fileRows, A, H, pin, safe, ref, c, coder, events } from './current-scoped-policy-reference-v2-workflow-fixture.mjs';

const capture=(f,request={kind:'publishReference',publication:f.publication},blockTag=10)=>
  workflow.captureScopedPolicyReferenceV2(f.provider,f.deployment,f.caller,request,{blockTag});
const reconcile=(f,saved,transport)=>workflow.reconcileScopedPolicyReferenceV2Receipt(f.provider,saved,transport.txHash,transport.options);
const simulate=(f,saved,blockTag=11)=>workflow.simulateScopedPolicyReferenceV2(f.provider,saved,{blockTag,gasLimit:20000000n});
const modes=['direct','legacy','indexed'];

test('all five original writes use exact CALL0 through direct and both Safe layouts',async()=>{
  for(const kind of ['prepareEnvironment','prepareFileInventory','prepareFileInventoryPart','prepareFileInventoryFromParts','publishReference'])for(const mode of modes){
    const f=setup(),request=kind==='publishReference'?{kind,publication:f.publication}:f.prepareRequest(kind);
    const saved=await capture(f,request),result=await simulate(f,saved);
    assert.equal(result.persisted,false);assert.equal(saved.prepared.call.value,0n);
    const receipt=await reconcile(f,saved,f.install(saved,mode));
    assert.equal(receipt.execution,mode==='direct'?'direct':'safe');assert.equal(receipt.finalityEstablished,false);
    assert.equal(receipt.result.kind,kind==='publishReference'?'publication':'preparation');
    assert.ok(f.state.calls.some(x=>x.method===kind&&x.tx.from===f.caller));
  }
});

test('TOKEN, RELEASE and SEASON use actual first/last rows, including burned completed tokens',async()=>{
  for(const scopeType of [1n,2n,3n]){
    const f=setup({count:scopeType===1n?1:2,burned:true,scope:{scopeType,collectionId:7n,tokenId:scopeType===1n?11n:0n,scopeId:scopeType===1n?ZeroHash:H(50)}});
    const saved=await capture(f);assert.equal(saved.stage.preview.source.samples.length,scopeType===1n?1:2);
    const result=await reconcile(f,saved,f.install(saved));assert.equal(result.result.receipt.observation.revision,1n);
    assert.equal(f.state.calls.filter(x=>x.method==='scopeTokenAt'&&x.tag===10).at(-1).args[1],scopeType===1n?0n:1n);
  }
});

test('fresh monolithic inventory is eventless, other fresh preparations require their original event',async()=>{
  for(const kind of ['prepareEnvironment','prepareFileInventory','prepareFileInventoryPart','prepareFileInventoryFromParts']){
    const f=setup(),saved=await capture(f,f.prepareRequest(kind,kind==='prepareFileInventoryPart'?fileRows(1):[]));
    const tx=f.install(saved);f.state.receipt.logs=[];
    if(kind==='prepareFileInventory')assert.equal((await reconcile(f,saved,tx)).result.receiptHadPreparationEvent,false);
    else await assert.rejects(reconcile(f,saved,tx),/exactly one/);
  }
});

test('retained preparation retries skip prerequisites but retain Store and linked runtime checks',async()=>{
  for(const kind of ['prepareEnvironment','prepareFileInventory','prepareFileInventoryPart','prepareFileInventoryFromParts']){
    const f=setup(),request=f.prepareRequest(kind),plan=ref.prepareScopedPolicyReferenceV2Call(f.coords,f.caller,request);
    f.state.prepared.clear();f.state.prepared.set(plan.preparation.id,plan.preparation.canonical);f.state.chunks.clear();
    f.state.hooks.code=(target)=>[A(1),A(2),A(3),A(5),A(203),A(9001)].includes(target)?'0x':undefined;
    const saved=await capture(f,request);assert.equal(saved.stage.retainedBefore,true);
    assert.deepEqual(saved.stage.prerequisites,[]);assert.equal((await reconcile(f,saved,f.install(saved,'indexed'))).result.priorRetained,true);
    f.state.hooks.code=target=>target===A(4)?'0x':undefined;
    await assert.rejects(capture(f,request),/runtime|code/i);
  }
});

test('original fixed64 assembly validates retained parts and environment prerequisites',async()=>{
  const f=setup(),request=f.prepareRequest('prepareFileInventoryFromParts',fileRows(65));
  const saved=await capture(f,request);assert.equal(saved.stage.prerequisites.length,2);
  assert.equal((await simulate(f,saved)).identity,saved.prepared.preparation.id);
  f.state.prepared.delete(saved.stage.prerequisites[1].identity);
  await assert.rejects(capture(f,request),/prerequisite/);
  const e=setup();e.state.prepared.clear();await assert.rejects(capture(e,e.prepareRequest('prepareEnvironment')),/prerequisite/);
});

test('preview permits zero expected source and does not claim Store availability; publication requires both payloads',async()=>{
  const f=setup();f.state.chunks.clear();
  const p={...f.publication,observation:{...f.publication.observation,expectedSourcesHash:ZeroHash}};
  const preview=await workflow.previewScopedPolicyReferenceV2(f.provider,f.deployment,f.caller,p,{blockTag:10});
  assert.equal(preview.storeAvailabilityChecked,false);assert.equal(preview.sourceHash,f.sourceHash);
  await assert.rejects(capture(f),/address|chunk/i);
  f.preupload(preview.canonical);await assert.rejects(capture(f),/address|chunk/i);
  f.preupload(ref.encodeScopedPolicyReferenceV2Publication(f.publication));assert.equal((await capture(f)).stage.kind,'publication');
});

test('CURATOR collection class3 precedes global8 independently of snapshot authority',async()=>{
  for(const cls of [3n,8n]){
    const f=setup({global:cls===8n});
    f.state.hooks.result=e=>e.method==='familyWriter'?[e.args[2]===8n||e.args[2]===cls,e.args[2]===cls?1n:9n]:undefined;
    const saved=await capture(f);assert.equal(saved.stage.preview.receipt.observation.authorizationClass,cls);
    const reads=f.state.calls.filter(e=>e.method==='familyWriter');
    assert.equal(reads[0].args[0],7n);assert.equal(reads[0].args[1],id('6529STREAM_RECORD_FAMILY_CURATOR_V1'));
    if(cls===8n)assert.equal(reads.at(-1).args[0],0n);
    await reconcile(f,saved,f.install(saved,'indexed'));
  }
  const f=setup();f.state.hooks.result=e=>e.method==='familyWriter'?[false,0n]:undefined;
  await assert.rejects(capture(f),/CURATOR/);
});

test('saved coverage uses the same two receipts after passing fixity refresh while fresh publication refuses',async()=>{
  const f=setup(),saved=await capture(f);await reconcile(f,saved,f.install(saved));
  const oldSourceHash=f.sourceHash;f.state.refreshed=true;f.state.calls.length=0;
  const current=await workflow.inspectScopedPolicyReferenceV2Current(f.provider,f.deployment,f.scope,{blockTag:13});
  assert.equal(current.currentnessChecked,true);assert.equal(current.receipt.observation.sourcesHash,oldSourceHash);
  assert.equal(current.coverage[0].saved.firstFixityHash,f.coverages[0].firstFixityHash);
  assert.equal(current.coverage[0].currentPair.firstFixityHash,H(9801));
  assert.equal(f.state.calls.some(x=>x.method==='requireCoverage'),false);
  // The prior scope is intentionally empty at block11; fresh admission fails on saved coverage fixity.
  await assert.rejects(workflow.previewScopedPolicyReferenceV2(f.provider,f.deployment,f.caller,f.publication,{blockTag:11}),/fixity/);
  f.state.hooks.result=e=>e.method==='currentReceiptPair'?[{...e.values[0],firstReceiptHash:H(9999)}]:undefined;
  await assert.rejects(workflow.inspectScopedPolicyReferenceV2Current(f.provider,f.deployment,f.scope,{blockTag:13}),/pair identity/);
});

test('immutable history survives lost source admission and grant revocation; current empty is explicit',async()=>{
  const f=setup();await assert.rejects(workflow.inspectScopedPolicyReferenceV2Current(f.provider,f.deployment,f.scope,{blockTag:10}),/No current reference/);
  const saved=await capture(f);f.install(saved);f.state.calls.length=0;
  f.state.hooks.code=target=>[A(1),A(2),A(3),A(5),A(203),A(9001),A(9101)].includes(target)?'0x':undefined;
  f.state.hooks.call=e=>['requireCoverage','currentReceiptPair','familyWriter','requireCurrent'].includes(e.method)?Promise.reject(Error('current source gone')):undefined;
  const history=await workflow.inspectScopedPolicyReferenceV2History(f.provider,f.historyDeployment,f.completed().observation.recordHash,{blockTag:13});
  assert.equal(history.currentnessChecked,false);assert.equal(history.finalityEstablished,false);
  assert.equal(history.publication.observation.manifestURI,'');
  assert.equal(f.state.calls.some(x=>['requireCoverage','currentReceiptPair','familyWriter','requireCurrent'].includes(x.method)),false);
  await assert.rejects(workflow.inspectScopedPolicyReferenceV2Current(f.provider,f.deployment,f.scope,{blockTag:13}),/runtime|code/i);
});

test('terminal DISABLED, ASYNC_NOT_REQUIRED and finalized zero seed retain original sample distinctions',async()=>{
  for(const options of [{},{asyncNotRequired:true},{finalized:true,zeroSeed:true}]){
    const f=setup(options),saved=await capture(f),sample=saved.stage.preview.source.samples[0];
    assert.equal(sample.observation.seed,ZeroHash);
    assert.equal(sample.entropy.status,options.finalized?5n:options.asyncNotRequired?2n:1n);
    assert.equal(sample.terminalAdmissionHash===ZeroHash,!!options.finalized);
    await reconcile(f,saved,f.install(saved));
    f.state.hooks.result=e=>e.method==='tokenEntropyReadiness'?[{...e.values[0],seed:H(8888)}]:undefined;
    await assert.rejects(capture(f),/entropy|differ|changed/i);
  }
});

test('actual membership, render bytes, original coordinator and PNG digest are independently joined',async()=>{
  const cases=[
    e=>e.method==='scopeTokenAt'?[12n]:undefined,
    e=>e.method==='tokenCollectionIdentity'?[true,8n,1n,false]:undefined,
    e=>e.method==='coordinatorAtMint'?[A(72)]:undefined,
    e=>e.method==='tokenHTML'?['<html>changed</html>']:undefined,
    e=>e.method==='tokenJSON'?['{}']:undefined,
    e=>e.method==='requireRetained'?[A(152),pin(A(152)).codeHash]:undefined,
    e=>e.method==='requireCoverage'&&e.args[2]!==H(6001)?[{...e.values[0],sha256Digest:H(123456)}]:undefined
  ];
  for(const fault of cases){const f=setup();f.state.hooks.result=fault;await assert.rejects(capture(f));}
  const f=setup({count:2});f.publication.observation.captures.reverse();await assert.rejects(capture(f),/membership/);
});

test('seven ACTIVE RAW definitions, exact snapshot first-five bindings and original output record key are required',async()=>{
  for(const fault of [
    e=>e.method==='document'?[{...e.values[0],status:1n}]:undefined,
    e=>e.method==='documentBytes'?['0x00']:undefined
  ]){const f=setup();f.state.hooks.result=fault;await assert.rejects(capture(f),/definition/i);}
  const f=setup();f.state.hooks.call=e=>{
    if(e.method==='dependencies'&&e.target===A(203)){const d=structuredClone(f.base.dependencies);d.targets[1]=A(999);return[d];}
    return undefined;
  };await assert.rejects(capture(f),/first five/);
  const good=setup();await capture(good);
  assert.ok(good.state.calls.some(e=>e.method==='manifestRecord'&&e.target===good.base.dependencies.targets[8]&&e.args[0]===good.base.publication.outputManifestRecord));
  assert.notEqual(good.base.publication.outputManifestRecord,good.base.source.outputs.manifestHash);
});

test('source, preparation and immutable-history linked pins are separate and reject delegation markers',async()=>{
  for(const route of ['source','preparation','history']){
    const f=setup(),pin_=f.deployment.linkedDependencies[route][0];
    if(route==='history')f.state.after=f.completed();
    f.state.hooks.code=target=>target===pin_.address?'0x':undefined;
    if(route==='source')await assert.rejects(capture(f),/runtime|code/i);
    if(route==='preparation')await assert.rejects(capture(f,f.prepareRequest('prepareFileInventory')),/runtime|code/i);
    if(route==='history')await assert.rejects(workflow.inspectScopedPolicyReferenceV2History(f.provider,f.historyDeployment,f.completed().observation.recordHash,{blockTag:13}),/runtime|code/i);
  }
  const f=setup(),marker='0xef0100'+A(999).slice(2);f.deployment.reference.codeHash=keccak256(marker);
  f.state.hooks.code=target=>target===A(9000)?marker:undefined;
  await assert.rejects(capture(f,f.prepareRequest('prepareFileInventory')),/delegation|runtime|code/i);
});

test('source refusal preserves the original error and local observation without claiming rollback',async()=>{
  const f=setup(),saved=await capture(f);
  // Matching captured HTML/JSON hashes do not reproduce the source byte-pattern/Image or capped-call admission.
  f.state.reject=true;
  await assert.rejects(simulate(f,saved),/original capped/);
  const refusal=await workflow.observeScopedPolicyReferenceV2Refusal(f.provider,saved,{blockTag:11,gasLimit:20000000n});
  assert.equal(refusal.outcome,'execution-reverted');assert.equal(refusal.retainedStateUnchanged,true);assert.equal(refusal.rollbackProven,false);
  assert.equal(refusal.error.data,'0x12345678');
  f.state.rpcFailure=true;
  assert.equal((await workflow.observeScopedPolicyReferenceV2Refusal(f.provider,saved,{blockTag:11,gasLimit:20000000n})).outcome,'rpc-failed');
  f.state.blockHashes.set(10,H(123));await assert.rejects(simulate(f,saved),/block/);
});

test('publication receipt rejects missing, duplicated, altered and early Safe events',async()=>{
  for(const mutation of [
    f=>f.state.receipt.logs.shift(),
    f=>f.state.receipt.logs.splice(1,0,structuredClone(f.state.receipt.logs[0])),
    f=>{const row=f.state.receipt.logs[0],p=events.parseLog(row);const encoded=events.encodeEventLog(events.getEvent(p.name),[1n,...p.args.slice(1)]);row.topics=[...encoded.topics];row.data=encoded.data;},
    f=>f.state.receipt.logs.reverse()
  ]){const f=setup(),saved=await capture(f),tx=f.install(saved,'indexed');mutation(f);f.renumber();await assert.rejects(reconcile(f,saved,tx));}
  const f=setup(),saved=await capture(f),tx=f.install(saved);f.state.hooks.result=e=>e.method==='currentReference'&&e.tag===12?[{...f.completed(),observation:{...f.completed().observation,revision:2n}}]:undefined;
  await assert.rejects(reconcile(f,saved,tx),/head/);
});

test('Safe exact CALL/value/data and independent execution hash are enforced with owned copied logs',async()=>{
  for(const fault of ['hash','failure','operation','value','data']){
    const f=setup(),saved=await capture(f),tx=f.install(saved,'legacy');
    if(fault==='hash')tx.options.expectedSafeTxHash=H(1234);
    else if(fault==='failure'){const row=safe.encodeEventLog(safe.getEvent('ExecutionFailure'),[H(901),0n]);Object.assign(f.state.receipt.logs.at(-1),{topics:[...row.topics],data:row.data});}
    else {const d=[...safe.decodeFunctionData('execTransaction',f.state.tx.data)];if(fault==='operation')d[3]=1;if(fault==='value')d[1]=1n;if(fault==='data')d[2]+='00';f.state.tx.data=safe.encodeFunctionData('execTransaction',d);}
    await assert.rejects(reconcile(f,saved,tx));
  }
  const f=setup(),saved=await capture(f),tx=f.install(saved,'indexed');
  f.state.hooks.transaction=()=>{f.state.receipt.logs[0].data='0x';f.state.receipt.logs.at(-1).topics[1]=H(1234);};
  assert.equal((await reconcile(f,saved,tx)).result.kind,'publication');
});

test('receipt metadata, exact prior/end attribution and finite transport bounds fail closed',async()=>{
  for(const change of [
    f=>{f.state.receipt.logs[0].removed=true;},f=>{f.state.receipt.logs[0].index=NaN;},
    f=>{delete f.state.receipt.logs[0].transactionHash;},f=>{f.state.receipt.from=A(99);},
    f=>{f.state.tx.value=1n;},f=>{f.state.tx.data='0x'+'00'.repeat(2097152+16385);},
    f=>{f.state.receipt.blockNumber=10;},f=>{f.state.receipt.logs[0].topics.push(ZeroHash,ZeroHash);}
  ]){const f=setup(),saved=await capture(f,f.prepareRequest('prepareFileInventoryPart')),tx=f.install(saved);change(f);await assert.rejects(reconcile(f,saved,tx));}
  const f=setup(),saved=await capture(f);f.state.hooks.result=e=>e.method==='familyWriter'&&e.tag===11?[true,2n]:undefined;
  await assert.rejects(simulate(f,saved),/differs|changed/);
  await assert.rejects(workflow.reconcileScopedPolicyReferenceV2Receipt(f.provider,saved,H(900),{execution:'delegatecall'}),/transport/);
});

test('input snapshots precede awaits and generic Safe planner round-trips original Registry-free calls',async()=>{
  const f=setup(),d=structuredClone(f.deployment),request={kind:'publishReference',publication:structuredClone(f.publication)};
  f.state.hooks.network=()=>{d.reference.address=A(99);request.publication.observation.manifestURI='altered';};
  const saved=await workflow.captureScopedPolicyReferenceV2(f.provider,d,f.caller,request,{blockTag:10});
  assert.equal(saved.deployment.reference.address,A(9000));assert.equal(saved.prepared.request.publication.observation.manifestURI,'');
  const plan=createSafeCallPlan(1n,'Original scoped reference',[{safe:f.caller,intent:'Publish already-covered reference',call:saved.prepared.call,abi:fixture.abis.reference}]);
  assert.deepEqual(verifySafeCallPlan(plan,[fixture.abis.reference]),plan);assert.equal(plan.steps[0].transaction.operation,0);
  const bad=structuredClone(plan);bad.steps[0].transaction.operation=1;assert.throws(()=>verifySafeCallPlan(bad,[fixture.abis.reference]));
});

test('fully rehashed historical TOKEN aliases still require the complete original source scope',async()=>{
  for(const field of ['publication','snapshotSource','contentRoot','subject']){
    const f=setup();const p=structuredClone(f.publication),r=structuredClone(f.completed()),source=structuredClone(f.source);
    if(field==='publication'){p.scope.collectionId=8n;p.observation.collectionId=8n;r.observation.collectionId=8n;}
    if(field==='snapshotSource')source.snapshotSource.scope.collectionId=8n;
    if(field==='contentRoot')source.contentRoot.publication.scope.collectionId=8n;
    if(field==='subject')source.scopeSubject=H(8989);
    const sourceHash=ref.scopedPolicyReferenceV2SourceHash(f.coords,f.dependencies,source);
    p.observation.expectedSourcesHash=sourceHash;r.observation.sourcesHash=sourceHash;
    const canonical=ref.scopedPolicyReferenceV2PayloadBytes(f.coords,p,r,source,f.envPrepared.canonical);
    r.observation.payloadHash=keccak256(canonical);r.observation.payloadBytes=BigInt((canonical.length-2)/2);
    r.observation.recordHash=ref.scopedPolicyReferenceV2RecordHash(f.coords,p,r);
    r.observation.recordChainHash=ref.scopedPolicyReferenceV2ChainHash(f.coords,p.scope,ZeroHash,1n,r.observation.recordHash);
    assert.notEqual(r.observation.recordHash,f.completed().observation.recordHash);
    f.state.hooks.call=e=>e.method==='referenceRecord'?[p,r]:e.method==='referencePayload'?[canonical]:e.method==='referenceSource'?[source]:undefined;
    await assert.rejects(workflow.inspectScopedPolicyReferenceV2History(f.provider,f.historyDeployment,r.observation.recordHash,{blockTag:13}),/scope/);
  }
});

test('authoritative first and last samples skip the middle of a five-token retained scope',async()=>{
  const f=setup({count:5}),saved=await capture(f);
  assert.equal(saved.stage.preview.source.snapshotSource.membership.tokenCount,5n);
  assert.deepEqual(saved.stage.preview.source.samples.map(x=>x.membershipIndex),[0n,4n]);
  assert.deepEqual(saved.stage.preview.publication.observation.captures.map(x=>x.tokenId),[11n,15n]);
  assert.deepEqual(f.state.calls.filter(x=>x.method==='scopeTokenAt'&&x.tag===10).map(x=>x.args[1]),[0n,4n]);
  await reconcile(f,saved,f.install(saved,'indexed'));
  f.state.hooks.result=e=>e.method==='scopeTokenAt'&&e.args[1]===4n?[12n]:undefined;
  await assert.rejects(capture(f),/membership/);
});

test('nonzero historical predecessor joins its own retained record and chain without live sources',async()=>{
  const f=setup(),prior=f.completed(),p=structuredClone(f.publication);
  p.observation.referenceId=H(7771);p.observation.expectedHead=prior.observation.recordHash;p.observation.expectedRevision=1n;
  const preview=ref.scopedPolicyReferenceV2PreviewReceipt(f.coords,p,f.caller,{authorizationClass:3n,grantRevision:1n},f.sourceHash);
  const canonical=ref.scopedPolicyReferenceV2PayloadBytes(f.coords,p,preview,f.source,f.envPrepared.canonical);
  const receipt={...preview,observation:{...preview.observation,recordedAt:1013n,payloadHash:keccak256(canonical),payloadBytes:BigInt((canonical.length-2)/2)}};
  receipt.observation.recordHash=ref.scopedPolicyReferenceV2RecordHash(f.coords,p,receipt);
  receipt.observation.recordChainHash=ref.scopedPolicyReferenceV2ChainHash(f.coords,p.scope,prior.observation.recordChainHash,2n,receipt.observation.recordHash);
  f.state.hooks.call=e=>e.method==='referenceRecord'?(e.args[0]===receipt.observation.recordHash?[p,receipt]:[f.publication,prior])
    :e.method==='referencePayload'?[canonical]:undefined;
  f.state.hooks.code=target=>[A(1),A(2),A(203),A(9001)].includes(target)?'0x':undefined;
  const result=await workflow.inspectScopedPolicyReferenceV2History(f.provider,f.historyDeployment,receipt.observation.recordHash,{blockTag:14});
  assert.equal(result.receipt.observation.revision,2n);assert.equal(result.currentnessChecked,false);
  const oldHook=f.state.hooks.call;
  f.state.hooks.call=e=>e.method==='referenceRecord'&&e.args[0]===prior.observation.recordHash
    ?[{...f.publication,scope:{...f.scope,collectionId:8n}},prior]:oldHook(e);
  await assert.rejects(workflow.inspectScopedPolicyReferenceV2History(f.provider,f.historyDeployment,receipt.observation.recordHash,{blockTag:14}),/predecessor full scope/);
});
