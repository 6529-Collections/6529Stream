import test from 'node:test';
import assert from 'node:assert/strict';
import { Interface, ZeroAddress, ZeroHash, id, keccak256 } from 'ethers';
import * as w from '../dist/current-scoped-policy-root-v2-workflow.js';
import * as graph from '../dist/current-scoped-policy-graph-v2.js';
import { createSafeCallPlan, verifySafeCallPlan } from '../dist/safe-plan.js';
import { setup, A, H, pin, safe, root, c, all, coder, zero, SNAPSHOT } from './current-scoped-policy-root-v2-workflow-fixture.mjs';
const gas={blockTag:11,gasLimit:10000000n};
async function preview(f,tag=10){return w.previewScopedPolicyRootV2(f.provider,f.deployment,f.publisher,f.publication,{blockTag:tag});}
async function capture(f,stage='root',tag=10){return stage==='root'?w.captureScopedPolicyRootV2(f.provider,f.deployment,f.publisher,f.publication,{blockTag:tag})
  :w.captureScopedPolicyRootV2Consent(f.provider,await preview(f,tag),f.caller,f.authorization);}
async function reconcile(f,saved,mode='direct'){const tx=f.install(saved,mode);return w.reconcileScopedPolicyRootV2Receipt(f.provider,saved,tx.txHash,tx.options);}
function event(f,name){return f.state.logs.find(x=>x.topics[0]===all.getEvent(name).topicHash);}
function changeEvent(f,name,mutate){const row=event(f,name),fragment=all.getEvent(name),args=Array.from(all.decodeEventLog(fragment,row.data,row.topics));mutate(args);Object.assign(row,all.encodeEventLog(fragment,args));}
async function rejectsCapture(options,hook,pattern,stage='root') {const f=setup(options);hook(f);await assert.rejects(capture(f,stage),pattern);}

test('TOKEN RELEASE SEASON original root preview, simulation and direct/both Safe receipts',async()=>{
  for(const scope of [{scopeType:1n,collectionId:7n,tokenId:11n,scopeId:ZeroHash},{scopeType:2n,collectionId:7n,tokenId:0n,scopeId:H(77)},{scopeType:3n,collectionId:7n,tokenId:0n,scopeId:H(78)}])
    for(const mode of ['direct','legacy','indexed']){
      const f=setup({scope}),saved=await capture(f);
      assert.equal(saved.preview.record.publisher,f.publisher);
      assert.notEqual(saved.preview.nextFamily,saved.preview.record.stateHash);
      await w.simulateScopedPolicyRootV2(f.provider,saved,gas);
      const result=await reconcile(f,saved,mode);
      assert.equal(result.result.kind,'root');assert.equal(result.finalityEstablished,false);
      assert.equal(result.result.record.publishedAt,1012n);
      assert.notEqual(result.result.contentStateHash,saved.preview.nextFamily);
      assert.equal(f.state.calls.find(x=>x.method==='contentConsentEvidence').tx.from,A(5));
    }
});
test('original op17 class1 direct nonce zero and class3 relayed empty proof across all transports',async()=>{
  for(const options of [{},{authorityClass:3n,relay:true,nonce:9n,nonceHint:0n}])for(const mode of ['direct','legacy','indexed']){
    const f=setup(options),saved=await capture(f,'consent');
    assert.equal(saved.prepared.consent.direct,!options.relay);
    await w.simulateScopedPolicyRootV2(f.provider,saved,gas);
    const result=await reconcile(f,saved,mode);
    assert.equal(result.result.kind,'consent');assert.equal(result.result.after[2].recordChainTip,result.result.before[2].recordChainTip);
    assert.equal(result.result.after[2].revision,result.result.before[2].revision+1n);
    assert.equal(result.privateIdentityActivityIndependentlyReconstructed,false);
  }
});
test('fresh root capture after mined consent retains distinct publisher and consent signer',async()=>{
  const f=setup({consentPresent:false}),consent=await capture(f,'consent');
  const mined=await reconcile(f,consent,'indexed');
  const saved=await capture(f,'root',12);
  assert.equal(saved.consent.recordHash,mined.result.recordHash);
  assert.notEqual(saved.prepared.caller,consent.prepared.caller);
  await w.simulateScopedPolicyRootV2(f.provider,saved,{blockTag:13,gasLimit:10000000n});
  const tx=f.install(saved,'legacy',14);
  assert.equal((await w.reconcileScopedPolicyRootV2Receipt(f.provider,saved,tx.txHash,tx.options)).result.kind,'root');
});
test('snapshot selected through original route, five ACTIVE definitions and eleven dependency pins',async()=>{
  for(const method of ['scopedPolicySnapshotHost','scopedPolicySnapshotCodeHash','scopedPolicySnapshotProfile','metadataReads','finalityRegistryCodeHash'])
    await rejectsCapture({},f=>{f.state.hooks.result=e=>e.method===method?[method.endsWith('Host')||method==='metadataReads'?A(777):H(777)]:undefined;},/differs|mismatch|profile|changed/i);
  await rejectsCapture({},f=>{f.state.hooks.result=e=>e.method==='document'?[{...e.values[0],status:1n}]:undefined;},/ACTIVE/);
  await rejectsCapture({},f=>{f.state.hooks.code=target=>target===f.base.dependencies.targets[6]?'0x':undefined;},/runtime/);
  await rejectsCapture({},f=>{f.state.hooks.result=e=>e.method==='supportsInterface'&&e.target===A(203)?[false]:undefined;},/changed/);
  const f=setup();await capture(f);assert.ok(f.state.calls.some(e=>e.method==='scopedPolicySnapshotHost'&&e.tx.gasLimit===2000000n));
});
test('root publisher SNAPSHOT class7 preference then global8; no inferred Artist authority',async()=>{
  const f=setup({global:true}),saved=await capture(f);
  assert.equal(saved.preview.record.authorizationClass,8n);
  assert.ok(f.state.calls.some(e=>e.method==='familyWriter'&&e.args[0]===0n&&e.args[2]===8n));
  await rejectsCapture({},f=>{f.state.hooks.result=e=>e.method==='familyWriter'?[false,0n]:undefined;},/SNAPSHOT/);
  await rejectsCapture({},f=>{f.state.hooks.result=e=>e.method==='collectionFreezeStatus'?[true]:undefined;},/frozen/);
  await rejectsCapture({},f=>{f.state.hooks.result=e=>e.method==='artworkFreezeMode'?[1n]:undefined;},/frozen/);
});
test('original principal identity, capability128, nonceHint, replay, gas and digest gates',async()=>{
  await rejectsCapture({authorityClass:4n},()=>{},/class1 or3/,'consent');
  await rejectsCapture({authorityClass:3n},f=>{f.state.hooks.result=e=>e.method==='currentAuthorityCapabilities'?[{...e.values[0],effectiveCapabilities:1n}]:undefined;},/capability/,'consent');
  await rejectsCapture({nonce:1n,nonceHint:0n},()=>{},/nonce/,'consent');
  await rejectsCapture({},f=>{f.state.hooks.result=e=>e.method==='artistAuthorizationState'?[{...e.values[0],nonceRevoked:true}]:undefined;},/nonce/,'consent');
  await rejectsCapture({relay:true},f=>{f.state.hooks.result=e=>e.method==='gasParameterInfo'?[0n,0n,2n,1n]:undefined;},/gas/,'consent');
  await rejectsCapture({},f=>{f.state.hooks.result=e=>e.method==='contentConsentDigest'?[H(99)]:undefined;},/digest/,'consent');
  const f=setup(),p=await preview(f);
  await assert.rejects(w.captureScopedPolicyRootV2Consent(f.provider,p,f.caller,{...f.authorization,signer:A(90)}),/actual current/);
  await assert.rejects(w.captureScopedPolicyRootV2Consent(f.provider,p,f.caller,{...f.authorization,signature:'0x'+'11'.repeat(4097)}),/oversized/);
});
test('inclusive consent deadline and exact mined clock, without substituting deadline in record',async()=>{
  const f=setup({deadline:1012n}),saved=await capture(f,'consent'),r=await reconcile(f,saved);
  assert.equal(r.result.recordHash,root.scopedPolicyRootV2ConsentRecordHash(f.coordinates,{terms:r.result.record.terms,artistId:f.binding.artistId,signer:f.signer,authorityClass:1n,nonce:0n,observedAt:1012n}));
  const expired=setup({deadline:1011n}),e=await capture(expired,'consent');await assert.rejects(reconcile(expired,e),/Mined Artist deadline/);
});
test('estate, private activity, optional42 and signature dedup preserve exact event/native ordering',async()=>{
  for(const dedup of [false,true]){
    const f=setup({estate:true,activity:true,dormancy:true,dedup}),saved=await capture(f,'consent');
    const result=await reconcile(f,saved,'indexed');assert.notEqual(result.result.cancellationHash,ZeroHash);
    assert.equal(result.result.after[2].revision,result.result.before[2].revision+1n);
    assert.ok(f.state.calls.some(e=>e.method==='replayCell'&&e.args[0]===f.replayKey(2,'identity_authority.replay.dormancy_cancellation_key',f.state.notice.recordHash)));
  }
});
test('optional42 context and cursor, estate replay and activity epoch contradictions reject',async()=>{
  for(const fault of ['context','cursor','estate','activity','order']){
    const f=setup({estate:true,activity:true,dormancy:true}),saved=await capture(f,'consent'),tx=f.install(saved);
    if(fault==='context')changeEvent(f,'ArtistDormancyCancellationContext',a=>{a[3]={chainId:2n,registry:A(20),identityOwner:A(802),recorder:f.signer,recorderAuthorityClass:1n};});
    if(fault==='cursor')f.state.hooks.result=e=>e.tag===12&&e.method==='dormancyNotice'?[f.state.notice.recordHash,1n,ZeroHash]:undefined;
    if(fault==='estate')f.state.after.cells.delete(f.replayKey(2,'identity_authority.replay.activation_cancellation_key',f.state.pendingEstate));
    if(fault==='activity')changeEvent(f,'ArtistUnavailabilityActivityRecorded',a=>{a[6]=8n;});
    if(fault==='order'){const a=event(f,'ArtistEstateActivationCancelled'),b=event(f,'ArtistUnavailabilityActivityRecorded');const i=f.state.logs.indexOf(a),j=f.state.logs.indexOf(b);[f.state.logs[i],f.state.logs[j]]=[b,a];f.renumber();}
    await assert.rejects(w.reconcileScopedPolicyRootV2Receipt(f.provider,saved,tx.txHash,tx.options),/context|cursor|replay|Activity|ordering/i);
  }
});
function rewriteArchive(f,mutate){
  const types=['uint16','bytes32','uint16','address','bytes32',SNAPSHOT+'[7]',SNAPSHOT+'[7]','bytes'];
  const decoded=coder.decode(types,f.state.after.archiveBytes);
  const rows=Array.from(decoded);rows[5]=decoded[5].map(x=>({domainId:x.domainId,revision:x.revision,stateRoot:x.stateRoot,recordChainTip:x.recordChainTip}));rows[6]=decoded[6].map(x=>({domainId:x.domainId,revision:x.revision,stateRoot:x.stateRoot,recordChainTip:x.recordChainTip}));
  mutate(rows);const raw=coder.encode(types,rows),hash=keccak256(raw);f.state.after.archiveBytes=raw;f.state.code.set(A(961),'0x00'+raw.slice(2));
  f.state.after.archivePayloads.find(x=>x.payloadType===id('ARTIST_OPERATION_EVIDENCE')).payloadHash=hash;
  const log=f.state.logs.find(x=>x.address===A(808)&&x.topics[0]===all.getEvent('ArtistStoredPayload').topicHash);
  const args=Array.from(all.decodeEventLog(all.getEvent('ArtistStoredPayload'),log.data,log.topics));args[3]=hash;Object.assign(log,all.encodeEventLog(all.getEvent('ArtistStoredPayload'),args));
  changeEvent(f,'ArtistArchiveEvidenceAppendedV2',a=>{a[2]=hash;a[4]=BigInt((raw.length-2)/2);});
}
test('self-consistent Archive carriers cannot substitute op17 mask, flat payload, actor or owner revision',async()=>{
  for(const fault of ['readOnly','identityTip','actor','wrapped']){
    const f=setup(),saved=await capture(f,'consent'),tx=f.install(saved);
    rewriteArchive(f,rows=>{if(fault==='readOnly')rows[6][4]={...rows[6][4],revision:rows[6][4].revision+1n};if(fault==='identityTip')rows[6][2].recordChainTip=H(998);if(fault==='actor')rows[3]=A(998);if(fault==='wrapped')rows[7]=coder.encode(['bytes'],[rows[7]]);});
    await assert.rejects(w.reconcileScopedPolicyRootV2Receipt(f.provider,saved,tx.txHash,tx.options),/Read-only|semantic tip|changed|flat payload/);
  }
});
test('Archive and signature catalogs require exact original rows, carriers and order',async()=>{
  for(const fault of ['ownerMissing','archiveMissing','carrier','afterAppend','native']){
    const f=setup(),saved=await capture(f,'consent'),tx=f.install(saved);
    if(fault==='ownerMissing')f.state.logs.splice(f.state.logs.indexOf(event(f,'ArtistStoredPayload')),1);
    if(fault==='archiveMissing')f.state.logs.splice(f.state.logs.findIndex(x=>x.address===A(808)&&x.topics[0]===all.getEvent('ArtistStoredPayload').topicHash),1);
    if(fault==='carrier')f.state.code.set(A(960),'0x0001');
    if(fault==='afterAppend'){const i=f.state.logs.findIndex(x=>x.address===A(808)&&x.topics[0]===all.getEvent('ArtistStoredPayload').topicHash);[f.state.logs[i],f.state.logs[i+1]]=[f.state.logs[i+1],f.state.logs[i]];}
    if(fault==='native')f.state.after.natives[6].operation=24n;
    f.renumber();await assert.rejects(w.reconcileScopedPolicyRootV2Receipt(f.provider,saved,tx.txHash,tx.options),/catalog|carrier|changed|Native receipt/);
  }
});
test('collection aggregate and legacy family concurrency invalidate saved preview for both stages',async()=>{
  for(const stage of ['root','consent'])for(const method of ['scopedContentRootAggregate','collectionContentRootHead']){
    const f=setup(),saved=await capture(f,stage);
    f.state.hooks.result=e=>e.tag===11&&e.method===method?[method==='collectionContentRootHead'?H(99):{revision:1n,transitionChain:H(99)}]:undefined;
    await assert.rejects(w.simulateScopedPolicyRootV2(f.provider,saved,gas),/differs|changed/);
  }
});
test('root consumed map and first-release ratification/evolution continuity are independent',async()=>{
  const f=setup({ratified:true}),saved=await capture(f);await reconcile(f,saved);
  await rejectsCapture({},f=>{f.state.hooks.result=e=>e.method==='consumedArtistContentConsent'?[true]:undefined;},/consumed/);
  await rejectsCapture({ratified:true},f=>{f.state.ratification[1]=H(123);},/evolution/);
  await rejectsCapture({},f=>{f.state.hooks.result=e=>e.method==='contentConsentRecord'||e.method==='contentConsentAt'?[{...e.values[0],authorityClass:4n}]:undefined;},/class/);
});
test('root event schemas, order, full post-content hash and exact end-block attribution',async()=>{
  for(const fault of ['schema','binding','order','applied','extra','end']){
    const f=setup(),saved=await capture(f),tx=f.install(saved,'indexed');
    if(fault==='schema')changeEvent(f,'ScopedContentRootPublished',a=>{a[0]=1n;});
    if(fault==='binding')f.state.logs.splice(1,1);
    if(fault==='order')[f.state.logs[0],f.state.logs[1]]=[f.state.logs[1],f.state.logs[0]];
    if(fault==='applied')changeEvent(f,'ArtistContentConsentApplied',a=>{a[3]=saved.preview.nextFamily;});
    if(fault==='extra')f.state.logs.splice(1,0,{...f.state.logs[0]});
    if(fault==='end')f.state.hooks.result=e=>e.tag===12&&e.method==='scopedContentRootAggregate'?[{revision:2n,transitionChain:H(99)}]:undefined;
    f.renumber();await assert.rejects(w.reconcileScopedPolicyRootV2Receipt(f.provider,saved,tx.txHash,tx.options),/differs|ordering|exactly|changed/);
  }
});
test('immutable history uses event historical aggregate despite later routes, grants and aggregate drift',async()=>{
  const f=setup(),saved=await capture(f),tx=f.install(saved);const key=f.state.rootAfter.recordHash;
  f.state.hooks.call=e=>{if(e.tag===20&&['scopedContentRootAggregate','familyWriter','requireCurrent','getSatellitePointer'].includes(e.method))throw Error('No current reauthorization in history');};
  f.state.hooks.code=(target,tag)=>tag===20&&target!==A(5)&&target!==A(820)?'0x':undefined;
  const history=await w.inspectScopedPolicyRootV2History(f.provider,f.historyDeployment,key,{transactionHash:tx.txHash,logIndex:0},{blockTag:20});
  assert.equal(history.profile,'v2');assert.equal(history.currentnessChecked,false);assert.equal(history.aggregate.revision,1n);
  changeEvent(f,'ScopedContentRootPublished',a=>{a[5]={revision:2n,transitionChain:H(99)};});
  await assert.rejects(w.inspectScopedPolicyRootV2History(f.provider,f.historyDeployment,key,{transactionHash:tx.txHash,logIndex:0},{blockTag:20}),/historical record mismatch/);
});
test('known V1 zero binding stays separate; unknown profile and contradictory zero binding refuse',async()=>{
  const f=setup(),saved=await capture(f),tx=f.install(saved),r=f.state.rootAfter;
  r.binding=zero(c.policyRoot.getFunction('scopedPolicyContentRootBinding').outputs[0]);
  r.record.stateHash=root.scopedPolicyRootV2LegacyStateHash(f.coordinates,r.record);
  r.recordHash=root.scopedPolicyRootV2LegacyRecordHash(f.coordinates,r.record,r.aggregate);
  changeEvent(f,'ScopedContentRootPublished',a=>{a[0]=1n;a[3]=r.recordHash;a[4]=r.record;});f.state.logs.splice(1,1);f.renumber();
  assert.equal((await w.inspectScopedPolicyRootV2History(f.provider,f.historyDeployment,r.recordHash,{transactionHash:tx.txHash,logIndex:0},{blockTag:20})).profile,'v1');
  r.binding.checkpoint=A(999);await assert.rejects(w.inspectScopedPolicyRootV2History(f.provider,f.historyDeployment,r.recordHash,{transactionHash:tx.txHash,logIndex:0},{blockTag:20}),/zero|binding|profile/i);
  r.binding.profileId=H(999);await assert.rejects(w.inspectScopedPolicyRootV2History(f.provider,f.historyDeployment,r.recordHash,{transactionHash:tx.txHash,logIndex:0},{blockTag:20}),/profile/);
});
test('current provider path uses exact full scope and snapshot, without fresh publisher grants',async()=>{
  const f=setup(),saved=await capture(f);f.install(saved);
  f.state.hooks.call=e=>{if(e.method==='familyWriter')throw Error('No new writer admission');};
  const result=await w.inspectScopedPolicyRootV2Current(f.provider,f.deployment,f.scope,{blockTag:12});
  assert.equal(result.currentnessChecked,true);assert.equal(result.historicalAggregateAuthenticated,false);
  await assert.rejects(w.inspectScopedPolicyRootV2Current(f.provider,f.deployment,{...f.scope,collectionId:8n},{blockTag:12}),/full scope/);
  f.state.hooks.result=e=>e.method==='scopedContentRoot'?[H(7),1n,H(8)]:undefined;
  await assert.rejects(w.inspectScopedPolicyRootV2Current(f.provider,f.deployment,f.scope,{blockTag:12}),/provider current root/);
});
test('refusal separates execution revert from transport failure and never claims native rollback',async()=>{
  const f=setup(),saved=await capture(f);f.state.rejected=true;
  const refusal=await w.observeScopedPolicyRootV2Refusal(f.provider,saved,gas);
  assert.equal(refusal.outcome,'execution-reverted');assert.equal(refusal.retainedStateUnchanged,true);assert.equal(refusal.rollbackProven,false);
  f.state.hooks.call=e=>{if(e.method==='publishScopedPolicyContentRootPublication')throw Error('connection lost');};
  assert.equal((await w.observeScopedPolicyRootV2Refusal(f.provider,saved,gas)).outcome,'rpc-failed');
  f.state.network=2n;await assert.rejects(w.observeScopedPolicyRootV2Refusal(f.provider,saved,gas),/chain/);
});
test('exact Safe independent hash, CALL/value/target/calldata and success order',async()=>{
  for(const fault of ['hash','delegate','innerValue','target','data','outerValue','failure','early']){
    const f=setup(),saved=await capture(f),tx=f.install(saved,'legacy');
    if(fault==='hash')tx.options.expectedSafeTxHash=H(88);
    if(['delegate','innerValue','target','data'].includes(fault)){
      const d=Array.from(safe.decodeFunctionData('execTransaction',f.state.tx.data));
      if(fault==='delegate')d[3]=1n;if(fault==='innerValue')d[1]=1n;if(fault==='target')d[0]=A(88);if(fault==='data')d[2]='0x';
      f.state.tx.data=safe.encodeFunctionData('execTransaction',d);
    }
    if(fault==='outerValue')f.state.tx.value=1n;
    if(fault==='failure')Object.assign(f.state.logs.at(-1),safe.encodeEventLog(safe.getEvent('ExecutionFailure'),[H(995),0n]));
    if(fault==='early'){f.state.logs.unshift(f.state.logs.pop());f.renumber();}
    await assert.rejects(w.reconcileScopedPolicyRootV2Receipt(f.provider,saved,tx.txHash,tx.options),/Safe|value|hash|failed|CALL/i);
  }
});
test('copied logs, mandatory metadata, saved block hash and malformed canonical returns',async()=>{
  for(const fault of ['removed','index','metadata','endpoint','reorg']){
    const f=setup(),saved=await capture(f),tx=f.install(saved);
    if(fault==='removed')f.state.logs[0].removed=true;if(fault==='index')f.state.logs[0].index=NaN;
    if(fault==='metadata')delete f.state.logs[0].blockHash;if(fault==='endpoint')f.state.receipt.from=A(98);
    if(fault==='reorg')f.state.blockHashes.set(10,H(88));
    await assert.rejects(w.reconcileScopedPolicyRootV2Receipt(f.provider,saved,tx.txHash,tx.options),/identity|concrete|envelope|block changed/i);
  }
  const f=setup(),saved=await capture(f),tx=f.install(saved,'indexed');
  f.state.hooks.transaction=()=>{f.state.logs[0].data='0x';};
  assert.equal((await w.reconcileScopedPolicyRootV2Receipt(f.provider,saved,tx.txHash,tx.options)).result.kind,'root');
  const malformed=setup();malformed.state.raw=(e,raw)=>e.method==='configurationHash'?raw+'00':raw;
  await assert.rejects(capture(malformed,'consent'),/Noncanonical|invalid length/);
});
test('caller-owned inputs are snapshotted before first await and generic Safe planner composes original methods',async()=>{
  const f=setup(),d=structuredClone(f.deployment),p=structuredClone(f.publication);let done=false;
  f.state.hooks.network=()=>{if(!done){done=true;d.provider.address=A(99);p.manifestURI='mutated';}};
  const saved=await w.captureScopedPolicyRootV2(f.provider,d,f.publisher,p,{blockTag:10});
  assert.equal(saved.preview.deployment.provider.address,A(851));assert.equal(saved.preview.publication.manifestURI,'ipfs://original-root');
  for(const stage of ['root','consent']){
    const ff=setup(),s=await capture(ff,stage),abi=stage==='root'?c.router.fragments:c.artist.fragments;
    const plan=createSafeCallPlan(1n,'Original scoped root stage',[{safe:s.prepared.caller,intent:'Perform original reviewed stage',call:s.prepared.call,abi}]);
    assert.equal(verifySafeCallPlan(plan,[abi]).hash,plan.hash);assert.equal(plan.steps[0].transaction.operation,0);
  }
});

test('finite profile bounds, direct envelope and historical owner pins fail closed',async()=>{
  const f=setup(),saved=await capture(f);
  await assert.rejects(w.simulateScopedPolicyRootV2(f.provider,saved,{blockTag:11,gasLimit:0n}),/Gas/);
  await assert.rejects(w.simulateScopedPolicyRootV2(f.provider,saved,{blockTag:9,gasLimit:100n}),/predates/);
  await assert.rejects(w.previewScopedPolicyRootV2(f.provider,f.deployment,f.publisher,{...f.publication,scope:{...f.scope,scopeType:4n}},{blockTag:10}),/TOKEN, RELEASE or SEASON/);
  for(const fault of ['caller','value','data','execution','outerBound']){
    const tx=f.install(saved);
    if(fault==='caller'){f.state.tx.from=A(99);f.state.receipt.from=A(99);}
    if(fault==='value')f.state.tx.value=1n;
    if(fault==='data')f.state.tx.data='0x';
    if(fault==='execution')tx.options.execution='delegatecall';
    if(fault==='outerBound')f.state.tx.data='0x'+'00'.repeat(81921);
    await assert.rejects(w.reconcileScopedPolicyRootV2Receipt(f.provider,saved,tx.txHash,tx.options),/caller|value|transport|oversized/);
  }
  const owner=setup(),s=await capture(owner),tx=owner.install(s);
  owner.state.hooks.code=(target,tag)=>tag===12&&target===A(806)?'0x':undefined;
  await assert.rejects(w.reconcileScopedPolicyRootV2Receipt(owner.provider,s,tx.txHash,tx.options),/runtime/);
  const delegated=setup(),marker='0xef0100'+A(99).slice(2);
  delegated.deployment.provider.codeHash=keccak256(marker);
  delegated.state.hooks.code=target=>target===A(851)?marker:undefined;
  await assert.rejects(preview(delegated),/runtime/);
});
