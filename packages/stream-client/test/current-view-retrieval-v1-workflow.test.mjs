// Mock RPC/source-consistency regressions, not native Archive/signature/Safe execution evidence.
import test from 'node:test';
import assert from 'node:assert/strict';
import { getAddress, keccak256 } from 'ethers';
import * as w from '../dist/current-view-retrieval-v1-workflow.js';
import * as p from '../dist/current-view-retrieval-v1.js';
import { setup, A, H, Z, ZA, host, safe } from './current-view-retrieval-v1-workflow-fixture.mjs';
const capture=f=>w.captureCurrentViewRetrievalV1(f.provider,f.d,f.caller,f.callRequest(),f.opts());
const history=(f,recordHash,more={})=>w.inspectCurrentViewRetrievalV1History(f.provider,f.hd,recordHash,{...f.opts(),...more});
const current=(f,recordHash,blockTag=10)=>w.inspectCurrentViewRetrievalV1Current(f.provider,f.d,recordHash,{...f.opts(),blockTag});
const rejected=()=>Object.assign(Error('mock original refusal'),{code:'CALL_EXCEPTION',data:host.encodeErrorResult('InvalidViewRetrieval')});

test('actual prepare returns unsigned full-source/writer evidence and skips nonce/signature/Store availability',async()=>{
  const f=setup();f.missingChunks=true;f.nonceBefore=true;
  const preview=await w.previewCurrentViewRetrievalV1(f.provider,f.d,A(99),f.request,f.opts());
  assert.equal(preview.nonceUsed,true);assert.equal(preview.signatureVerified,false);assert.equal(preview.storeAvailabilityChecked,false);
  assert.equal(preview.observation.writer,f.writer);assert.equal(preview.source.artist.locked,true);
  assert.equal(f.calls.some(c=>c.to===f.pins.store.address),false);
  await assert.rejects(capture(f),/nonce/);f.nonceBefore=false;await assert.rejects(capture(f),/Zero address/);
});

test('publish and revoke reconcile direct and both Safe layouts at the actual mined timestamp',async()=>{
  for(const mode of ['publish','revoke'])for(const transport of ['direct','legacy','indexed']){
    const f=setup({mode}),c=await capture(f),sim=await w.simulateCurrentViewRetrievalV1(f.provider,c,{blockTag:11});
    const t=f.mine(c,transport),r=await w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,t.hash,t.options);
    assert.equal(r.kind,mode);assert.equal(r.originalEventAuthenticated,true);assert.equal(r.intraBlockTraceProven,false);
    if(mode==='publish'){assert.equal(c.stage.predictedReceipt.recordedAt,1010n);assert.equal(r.history.receipt.recordedAt,1012n);
      assert.notEqual(sim.result,c.stage.predictedReceipt.recordHash);assert.notEqual(r.history.receipt.recordHash,sim.result);
      assert.equal(r.history.nonceUsed,true);assert.equal(r.timestampRecomputed,true);
    }else{assert.equal(sim.result,null);assert.equal(r.history.revoked,true);assert.equal(r.history.revocationEpoch,1n);}
  }
});

test('simulation compares stable observations and recomputes the return hash for each fixed block',async()=>{
  const f=setup(),c=await capture(f),s=await w.simulateCurrentViewRetrievalV1(f.provider,c,{blockTag:11});
  assert.equal(s.result,p.currentViewRetrievalV1PreviewReceipt(f.coordinates,f.configuration,c.stage.preview.observation,f.signature,1011n).recordHash);
  assert.notEqual(s.capture.captureHash,c.captureHash);assert.equal(s.capture.stage.payload,c.stage.payload);
  f.hook=call=>call.name==='publish'?[c.stage.predictedReceipt.recordHash]:undefined;
  await assert.rejects(w.simulateCurrentViewRetrievalV1(f.provider,c,{blockTag:11}),/simulated timestamp/);
});

test('direct writer, raw own-key, EIP7702 own-key/fallback and empty ERC1271 relay use original publish authority',async()=>{
  for(const signatureMode of [undefined,'own-key','7702-own','7702-fallback','contract']){
    const f=setup({signatureMode}),c=await capture(f);assert.equal(c.stage.signatureRoute.route,signatureMode===undefined?'direct-writer':signatureMode?.endsWith('own')||signatureMode==='own-key'?'own-key':'erc1271');
    const sim=await w.simulateCurrentViewRetrievalV1(f.provider,c,{blockTag:11});assert.equal(sim.originalCallSucceeded,true);
    if(['contract','7702-fallback'].includes(signatureMode)){assert.equal(f.signature,'0x');assert.equal(c.stage.signatureRoute.requiresContractValidation,true);f.signatureFailure=true;await assert.rejects(w.simulateCurrentViewRetrievalV1(f.provider,c,{blockTag:11}),/refused/);}
  }
  const bad=setup();await assert.rejects(w.captureCurrentViewRetrievalV1(bad.provider,bad.d,A(98),bad.callRequest(),bad.opts()),/own-key/);
});

test('prepared source joins full VIEW scope, locked Artist, exact adoption payload and original runtime pins',async()=>{
  for(const mutate of [f=>{f.artist.locked=false;},f=>{f.artist.registry=A(99);},f=>{f.artist.identityRecordHash=Z;},f=>{f.cp.adoption.input.scope={...f.scope,scopeType:4n,collectionId:9n,tokenId:0n,scopeId:H('wrong')};},
    f=>{f.cp.contextHash=H('other-context');},f=>{f.code.set(f.cp.adoption.source.payloadPointers[0],'0x0000');},f=>{f.cp.adoption.source.payloadPointers[4]=A(999);},f=>{f.code.set(f.pins.artist.address,'0x6000');}]){
    const f=setup();mutate(f);await assert.rejects(capture(f));
  }
});

test('complete retained payload chunks require ordered original sizes and full STOP bytes',async()=>{
  const f=setup(),c=await capture(f);assert.equal(c.stage.chunks[0].runtime,'0x00'+c.stage.chunks[0].data.slice(2));
  const row=f.chunkRecords.get(f.chunks[0].hash);row[1]++;await assert.rejects(capture(f),/length/);row[1]--;
  f.code.set(row[0],'0x01'+f.chunks[0].data.slice(2));await assert.rejects(capture(f),/STOP/);
});

test('institutional writer must match immutable second receipt, active family, and actual same receipt pair',async()=>{
  for(const mutate of [f=>{f.families.get(f.observation.coverage.secondFamilyRecordHash)[1]=2n;},f=>{f.families.get(f.observation.coverage.secondFamilyRecordHash)[0].economics=1n;},
    f=>{f.receipts.get(f.observation.coverage.secondReceiptHash)[0].writer=A(99);},f=>{f.receipts.get(f.observation.coverage.secondReceiptHash)[1]='0x01';},
    f=>{f.objects.get(f.request.coverageHash).pair.firstReceiptHash=H('different-original');},
    f=>{f.receipts.get(f.observation.coverage.secondReceiptHash)[2]='0x'+'11'.repeat(65200);}]){const f=setup();mutate(f);await assert.rejects(capture(f));}
  const f=setup(),c=await capture(f);f.pairRefresh=true;assert.equal((await w.simulateCurrentViewRetrievalV1(f.provider,c,{blockTag:11})).originalCallSucceeded,true);
  const retained=setup({mode:'revoke',deadline:1009n});retained.pairRefresh=true;const checked=await current(retained,retained.historical.recordHash);
  assert.equal(checked.archive.pair.firstReceiptHash,retained.observation.coverage.firstReceiptHash);assert.notEqual(checked.archive.pair.firstFixityHash,retained.observation.coverage.firstFixityHash);
  assert.equal(checked.freshSignatureRevalidated,false);assert.equal(checked.historicalDeadlineRevalidated,false);
});

test('Arweave path routes join whole manifest bytes and original transaction locators without network retrieval',async()=>{
  const tx='0x'+'11'.repeat(32),root='ar://'+Buffer.from(tx.slice(2),'hex').toString('base64url');
  const f=setup({arweave:true,requestedURI:root+'/index',resolvedURI:'ar://'+Buffer.from(H('final-tx').slice(2),'hex').toString('base64url')});
  const c=await capture(f);assert.equal(c.stage.preview.manifests.length,1);assert.equal(c.stage.preview.finalTransaction.locator,H('final-tx'));
  const manifest=c.stage.preview.manifests[0];assert.equal(keccak256(f.request.steps[0].manifestBytes),manifest.archive.object.contentHash);
  f.receipts.get(manifest.archive.coverage.firstReceiptHash)[1]=H('wrong-tx');await assert.rejects(capture(f),/locator/);
  const g=setup({arweave:true,requestedURI:root+'/index',resolvedURI:f.observation.resolvedURI});g.request.steps[0].manifestBytes='0x1234';
  g.hook=call=>call.name==='prepare'?[g.observation,p.currentViewRetrievalV1Digest(g.coordinates,g.configuration,g.observation)]:undefined;
  await assert.rejects(capture(g),/Manifest/);
});

test('nonce is writer-wide across scopes while original prepare remains callable after nonce use',async()=>{
  const a=setup(),b=setup({scope:'another'});assert.equal(p.currentViewRetrievalV1NonceKey(a.writer,a.request.nonce),p.currentViewRetrievalV1NonceKey(b.writer,b.request.nonce));
  b.nonceBefore=true;assert.equal((await w.previewCurrentViewRetrievalV1(b.provider,b.d,b.caller,b.request,b.opts())).nonceUsed,true);await assert.rejects(capture(b),/nonce/);
  assert.notEqual(p.currentViewRetrievalV1ScopeKey(a.request.scope),p.currentViewRetrievalV1ScopeKey(b.request.scope));
});

test('history and supplied-payload revoke survive dead sources, expired deadline, changed writer code and carrier loss',async()=>{
  const f=setup({mode:'revoke',deadline:1009n});f.currentFailure=true;f.code.set(f.writer,'0x6004');
  const retained={receipt:f.historical,payload:f.payload};
  f.codeHook=(address)=>address===f.pins.witness.address?undefined:'0x';
  const h=await history(f,f.historical.recordHash,{retainedPayload:retained});assert.equal(h.currentnessVerified,false);assert.equal(h.signatureVerified,false);
  await assert.rejects(history(f,f.historical.recordHash),/runtime/);
  const c=await w.captureCurrentViewRetrievalV1(f.provider,f.d,f.writer,f.callRequest(),{...f.opts(),retainedPayload:retained});
  const t=f.mine(c),r=await w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,t.hash,t.options);assert.equal(r.history.revoked,true);assert.equal(r.history.revocationEpoch,1n);
  assert.equal(f.calls.some(call=>call.name==='currentSource'||call.name==='coverage'||call.name==='encoded'),false);
});

test('history uses explicit outer byte-read gas and current preserves historical signature/deadline authority',async()=>{
  const f=setup({mode:'revoke',deadline:1009n});const h=await history(f,f.historical.recordHash);assert.equal(h.receipt.recordHash,f.historical.recordHash);
  assert(f.calls.filter(call=>call.name==='encoded').every(call=>call.gasLimit===10000000n));assert.equal(f.configuration.readGas,50000n);
  await current(f,f.historical.recordHash);f.currentFailure=true;await assert.rejects(current(f,f.historical.recordHash));assert.equal((await history(f,f.historical.recordHash)).receipt.recordHash,f.historical.recordHash);
  f.revokedBefore=true;await assert.rejects(history(f,f.historical.recordHash),/scope epoch/);f.revokedBefore=false;
  f.hook=call=>call.name==='encoded'?[f.payload+'00']:undefined;await assert.rejects(history(f,f.historical.recordHash),/canonical/i);
});

test('revoke joins actual writer, nonzero reason, retained scope, and exact epoch increment',async()=>{
  const f=setup({mode:'revoke'});await assert.rejects(w.captureCurrentViewRetrievalV1(f.provider,f.d,A(97),f.callRequest(),f.opts()),/revoke/);
  await assert.rejects(w.captureCurrentViewRetrievalV1(f.provider,f.d,f.writer,{...f.callRequest(),reasonHash:Z},f.opts()));
  f.revokedBefore=true;f.epochBefore=1n;await assert.rejects(capture(f),/revoke/);f.revokedBefore=false;f.epochBefore=0n;
  const c=await capture(f),t=f.mine(c);f.hook=call=>call.name==='revocationEpoch'&&call.blockTag===12?[2n]:undefined;
  await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,t.hash,t.options),/epoch increment/);
});

test('mined deadlines are inclusive and stored record hashes must use the actual mined timestamp',async()=>{
  const f=setup({deadline:1012n}),c=await capture(f),t=f.mine(c);assert.equal((await w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,t.hash,t.options)).history.receipt.recordedAt,1012n);
  const g=setup({deadline:1011n}),gc=await capture(g);g.receipt=structuredClone(f.receipt);g.transaction=structuredClone(f.transaction);
  g.transaction.data=gc.prepared.call.data;
  await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(g.provider,gc,t.hash,t.options),/time bounds/);
  const x=setup(),xc=await capture(x),xt=x.mine(xc);const old=xc.stage.predictedReceipt;Object.assign(x.receipt.logs[0],host.encodeEventLog('ViewRetrievalRecorded',[old.recordHash,old.sourceKey,old.writer,old]));
  await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(x.provider,xc,xt.hash,xt.options),/differs/);
});

test('receipt runtime pins include source/link/writer/chunks while revoke stays local',async()=>{
  for(const target of ['linked','artist','archive']){const f=setup(),c=await capture(f),t=f.mine(c);f.codeHook=(address,tag)=>tag===12&&address===f.pins[target].address?'0x6000':undefined;await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,t.hash,t.options),/runtime/);}
  const f=setup({signatureMode:'contract'}),c=await capture(f),t=f.mine(c);f.codeHook=(address,tag)=>tag===12&&address===f.writer?'0x6001':undefined;await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,t.hash,t.options),/writer code/);
});

test('copied receipt logs, exact caller/value/data/Safe hash and application-before-Safe ordering are enforced',async()=>{
  const f=setup(),c=await capture(f),t=f.mine(c,'indexed');await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,t.hash,{execution:'safe',expectedSafeTxHash:H('wrong')}));
  f.receipt.logs.reverse();f.receipt.logs.forEach((log,index)=>log.index=index);await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,t.hash,t.options),/precede Safe/);
  f.mine(c,'indexed');f.receipt.logs.push({...f.receipt.logs[0],index:2});await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,t.hash,t.options),/exactly one/);
  const direct=f.mine(c);f.transaction.from=A(99);f.receipt.from=A(99);await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,direct.hash,direct.options),/caller/);
  f.mine(c);f.transaction.value=1n;await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,direct.hash,direct.options),/value/);
  f.mine(c);f.transaction.data+='00';await assert.rejects(w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,direct.hash,direct.options),/data/);
});

test('unrelated post-execution Safe guard logs are allowed while receipt metadata is copied before awaits',async()=>{
  const f=setup(),c=await capture(f),t=f.mine(c,'legacy');f.receipt.logs.push({address:A(94),topics:[H('guard')],data:'0x',index:2,transactionHash:t.hash,blockNumber:12,blockHash:H('block-12'),removed:false});
  const getTx=f.provider.getTransaction;f.provider.getTransaction=async()=>{f.receipt.logs[0].data='0x';return getTx();};
  assert.equal((await w.reconcileCurrentViewRetrievalV1Receipt(f.provider,c,t.hash,t.options)).originalEventAuthenticated,true);
});

test('refusal distinguishes original revert, sanitized RPC failure and source-changed direct-writer success',async()=>{
  const f=setup(),c=await capture(f);f.callFailure=rejected();let r=await w.observeCurrentViewRetrievalV1Refusal(f.provider,c,{blockTag:11});assert.equal(r.outcome,'execution-reverted');assert.equal(r.submittedTransactionRollbackProven,false);
  f.callFailure=Object.assign(Error('private URL should not be returned'),{code:'NETWORK_ERROR',info:{url:'fake-secret'}});r=await w.observeCurrentViewRetrievalV1Refusal(f.provider,c,{blockTag:11});assert.equal(r.outcome,'rpc-failed');assert.equal(JSON.stringify(r,(_,v)=>typeof v==='bigint'?v.toString():v).includes('fake-secret'),false);
  f.callFailure=null;const changed=structuredClone(f.observation);changed.source.checkpointContextHash=H('fresh-context');const freshHash=p.currentViewRetrievalV1PreviewReceipt(f.coordinates,f.configuration,changed,f.signature,1011n).recordHash;
  f.hook=call=>call.blockTag===11&&call.name==='publish'?[freshHash]:undefined;r=await w.observeCurrentViewRetrievalV1Refusal(f.provider,c,{blockTag:11});assert.equal(r.outcome,'call-succeeded');assert.equal(r.result,freshHash);assert.equal(r.capturePredictionChecked,false);
});

test('pre-await inputs, capture tampering, fixed chain/block identity and finite bounds are enforced',async()=>{
  const f=setup(),d=structuredClone(f.d),q=structuredClone(f.callRequest()),options=f.opts();f.networkHook=()=>{q.request.scope.collectionId=99n;d.witness.codeHash=H('changed');options.blockTag=11;};
  const c=await w.captureCurrentViewRetrievalV1(f.provider,d,f.caller,q,options);assert.equal(c.observed.blockNumber,10);assert.equal(c.prepared.request.request.scope.collectionId,9n);
  const forged=structuredClone(c);forged.prepared.call.data='0x';await assert.rejects(w.simulateCurrentViewRetrievalV1(f.provider,forged,{blockTag:11}),/fingerprint/);
  const getBlock=f.provider.getBlock;f.provider.getBlock=async tag=>{const b=await getBlock(tag);return tag===10?{...b,hash:H('replacement')}:b;};await assert.rejects(w.simulateCurrentViewRetrievalV1(f.provider,c,{blockTag:11}),/block changed/);
  const x=setup();x.chainId=2n;await assert.rejects(capture(x),/Wrong chain/);
  const y=setup();await assert.rejects(w.captureCurrentViewRetrievalV1(y.provider,y.d,y.caller,y.callRequest(),{...y.opts(),gasLimit:100000001n}),/gas limit/);
  await assert.rejects(w.captureCurrentViewRetrievalV1(y.provider,{...y.d,linkedDependencies:Array(257).fill(y.pins.linked)},y.caller,y.callRequest(),y.opts()),/limit/);
});
