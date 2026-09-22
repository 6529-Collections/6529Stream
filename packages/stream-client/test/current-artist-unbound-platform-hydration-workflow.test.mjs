// Compiler-encoded consistency mocks; no original owner execution or real signatures.
import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroHash } from 'ethers';
import { setup, capture, install, run, renumber, zeroValue, rh, workflow, abi, preparedAbi, safeABI, A, H } from './current-artist-unbound-platform-hydration-workflow-fixture.mjs';

test('zero-Artist capture uses original two-argument op60 without inventing principal rows',async()=>{
  const s=setup(),c=await capture(s);
  assert.equal(c.certificate.admission.artists.length,0);
  assert.equal(c.certificate.admission.collections.length,1);
  assert.equal(c.certificate.admission.before_[2].revision,2n);
  assert.equal(c.registrySimulated,false);assert.equal(c.prepared.call.value,0n);
  assert.equal(abi.parseTransaction({data:c.prepared.call.data}).name,'hydrateRecoveredArtistAuthority');
  assert.deepEqual(c.prepared.royaltyFreezes,[]);assert.deepEqual(c.prepared.request.records.witnesses,[]);
  const state=i=>rh.decodeArtistUnboundPlatformHydrationState(c.owners[i].payload.semanticState,i,c.owners[i].payload.provenance);
  assert.equal(state(2).rows.length,1);assert.equal(state(5).rows.length,0);assert.equal(state(1).rows.length,0);
  for(const i of [0,3,6])assert.deepEqual(state(i).rows,['0x']);
  assert.equal(c.owners[2].payload.provenance.journal.length,0);assert.deepEqual(c.owners[2].payload.nonces,[]);
  assert.deepEqual(state(4).collections,c.certificate.admission.collections);
  assert.equal(c.certificate.query.artistId,ZeroHash);
  assert.equal(s.state.calls.some(v=>v.method==='importedLaneVerified'&&v.args[0]===1n),false);
});

test('Platform current simulation keeps exact caller and original zero-value Registry route',async()=>{
  const s=setup(),c=await capture(s);
  const r=await workflow.simulateArtistUnboundPlatformHydration(s.provider,c,{blockTag:10,gasLimit:10000000n});
  assert.equal(r.registrySimulated,true);assert.equal(r.futureExecutionGuaranteed,false);
  const call=s.state.calls.findLast(v=>v.method==='hydrateRecoveredArtistAuthority');
  assert.equal(call.from,s.caller);assert.equal(call.value,0n);assert.equal(call.tag,10);
});

test('both original claim families and governed contest preserve complete display and Archive bodies',async()=>{
  const s=setup({claims:true}),c=await capture(s),p=s.platforms[0];
  assert.ok(p.claims.length>0&&p.allegations.length>0&&p.contests.length>0);
  for(const [method,rows]of[['platformWorksClaimRecord',p.claims],['attributionClaimRecord',p.allegations],['platformWorksContestRecord',p.contests]])for(const row of rows)assert.ok(s.state.calls.some(v=>v.method===method&&v.args[0]===row.record.recordHash));
  for(const method of ['attributionClaims','staticAttributionClaims'])assert.ok(s.state.calls.some(v=>v.method===method&&v.args[0]===p.collectionId));
  assert.ok(c.certificate.admission.provenance.journals[4].some(v=>v.receipt.operation===10n));
  for(const row of s.archiveRows)assert.ok(s.state.calls.some(v=>v.method==='artistEvidenceBytesV2'&&v.args[0]===row.evidenceId));
});

test('unused governed correction approval remains generation zero and unaccepted',async()=>{
  const s=setup({correction:true}),c=await capture(s),p=s.platforms[0];
  assert.notEqual(p.state.correction.recordHash,ZeroHash);
  assert.equal(p.state.correction.correctiveGeneration,0n);assert.equal(p.state.correction.accepted,false);
  assert.ok(c.certificate.admission.provenance.journals[4].some(v=>v.receipt.operation===53n));
});

test('mixed complete ordinary Artist graph retains gen1 acceptance alongside the zero-Artist Platform',async()=>{
  const s=setup({mixed:true}),c=await capture(s);
  assert.equal(c.certificate.admission.artists.length,2);assert.equal(c.certificate.admission.collections.length,4);
  assert.equal(c.certificate.admission.before_[2].revision,7n);
  assert.ok(c.certificate.admission.collections.some(q=>q.artistId===ZeroHash));
  const q=c.certificate.admission.collections.find(q=>q.artistId!==ZeroHash);
  assert.ok(s.state.calls.some(v=>v.method==='bindingAt'&&v.args[0]===q.collectionId&&v.args[1]===1n));
  assert.ok(s.state.calls.some(v=>v.method==='acceptanceRecord'&&v.args[0]===q.bindingHash));
  assert.ok(s.state.calls.some(v=>v.method==='importedLaneVerified'&&v.args[0]===1n&&v.args[1]===q.artistId));
});

test('repeated Platform import keeps every origin cutoff and historical cutover replay cell',async()=>{
  const s=setup({repeated:true,claims:true}),c=await capture(s),p=c.certificate.admission.provenance;
  assert.ok(p.eras.length>1);assert.ok(p.aliases[2].length>p.eras.length);
  for(const origin of p.origins)assert.ok(s.state.calls.some(v=>v.method==='storedPayloadCount'&&v.host===origin.archive));
  assert.equal(c.certificate.admission.artists.length,0);
  assert.ok(c.owners[2].historicalCells.length>1);
  assert.ok(c.owners[2].historicalCells.some(v=>v.cell.status===0n));
  assert.ok(c.owners[2].historicalCells.some(v=>v.cell.status===2n));
});

test('every selected collection lane is verified including the non-anchor ordinary subject',async()=>{
  const s=setup({mixed:true}),q=s.certificate.admission.collections.at(-1);
  s.state.hooks.push(({method,args})=>method==='importedLaneVerified'&&args[0]===2n&&BigInt(args[1])===q.collectionId?[false,H('missing lane'),BigInt(q.records.length)]:undefined);
  await assert.rejects(capture(s),/operation56 lane/);
});

test('zero-principal source refuses invented registration timing and nonce inventories',async()=>{
  const s=setup();
  s.state.hooks.push(({method,host})=>method==='nextRegistrationNonce'&&host===s.source.owners[2]?[1n]:undefined);
  await assert.rejects(capture(s),/registration counter/);s.state.hooks.length=0;
  s.state.hooks.push(({method,host})=>method==='recoveredTimingCheckpoint'&&host===s.source.owners[2]?[{...s.certificate.timing,configurationHash:H('invented timing')}]:undefined);
  await assert.rejects(capture(s),/timing checkpoint/);s.state.hooks.length=0;
  s.state.hooks.push(({method,host})=>method==='authorityCheckpoint'&&host===s.source.owners[2]?[{...s.certificate.admission.provenance.eras.at(-1).checkpoints[2],nonceIndexCount:1n}]:undefined);
  await assert.rejects(capture(s),/checkpoint/);
});

test('unbound current source refuses a fabricated binding without inferring an Artist',async()=>{
  const s=setup(),q=s.certificate.admission.collections[0];
  s.state.hooks.push(({method,host,fragment,args})=>method==='binding'&&host===s.source.owners[0]&&args[0]===q.collectionId?[{...zeroValue(fragment.outputs[0]),artistId:H('invented artist')}]:undefined);
  await assert.rejects(capture(s),/Binding must remain empty/);
});

test('whole claim fields and STATIC display cannot be substituted by their record hash',async()=>{
  const s=setup({claims:true}),p=s.platforms[0],row=p.claims[0];
  s.state.hooks.push(({method,host,args})=>method==='platformWorksClaimRecord'&&host===s.source.owners[4]&&args[0]===row.record.recordHash?[{...row.record,proposedArtist:A(998)}]:undefined);
  await assert.rejects(capture(s),/complete Platform claim/);s.state.hooks.length=0;
  s.state.hooks.push(({method,host})=>method==='staticAttributionClaims'&&host===s.source.owners[4]?[BigInt(p.claims.length)+p.allegationCount,H('different latest')]:undefined);
  await assert.rejects(capture(s),/STATIC Platform display/);
});

test('complete native receipt and live replay cell inventories cannot omit Platform history',async()=>{
  const s=setup({claims:true}),last=s.certificate.admission.provenance.eras.at(-1);
  s.state.hooks.push(({method,host})=>method==='artistNativeReceiptCount'&&host===s.source.owners[4]?[last.nativeCounts[4]-1n]:undefined);
  await assert.rejects(capture(s),/native count/);s.state.hooks.length=0;
  s.state.hooks.push(({method,host})=>method==='replayCell'&&host===s.source.owners[4]?[{commitment:ZeroHash,touchedRevision:0n,kind:0n,status:0n}]:undefined);
  await assert.rejects(capture(s),/replay cell/);
});

test('Platform Archive requires complete STOP bytes and original bounded metadata',async()=>{
  const s=setup(),row=s.archiveRows[0];s.state.codes.set(row.pointer,`0x01${row.raw.slice(2)}`);
  await assert.rejects(capture(s),/STOP/);s.state.codes.set(row.pointer,`0x00${row.raw.slice(2)}`);
  s.state.hooks.push(({method,host,args})=>method==='artistEvidenceMetadataV2'&&host===s.source.archive&&args[0]===row.evidenceId?[row.hash,row.pointer,BigInt((row.raw.length-2)/2),11n]:undefined);
  await assert.rejects(capture(s),/future block/);
});

test('original catalogue includes unrelated retained payload rows',async()=>{
  const s=setup();s.state.sourceCatalogs.get(s.source.archive).push({pointer:A(999),payloadType:H('other payload'),payloadHash:H('other bytes')});
  await assert.rejects(capture(s),/catalogue count/);
});

test('Platform Prepared result must be canonical before any Registry simulation',async()=>{
  const s=setup();s.state.hooks.push(({method,fragment})=>method==='prepare'?`${preparedAbi.encodeFunctionResult(fragment,[s.certificate])}${'00'.repeat(32)}`:undefined);
  await assert.rejects(capture(s),/Noncanonical/);assert.equal(s.state.calls.some(v=>v.method.startsWith('hydrateRecovered')),false);
});

test('original Platform request is owned before the first asynchronous read',async()=>{
  const s=setup(),network=s.provider.getNetwork;let once=true;
  s.provider.getNetwork=async()=>{if(once){once=false;s.input.request.expectedSourceImportCommitment=H('caller mutation');}return network();};
  const c=await capture(s);assert.notEqual(c.prepared.request.expectedSourceImportCommitment,s.input.request.expectedSourceImportCommitment);
});

for(const mode of ['direct','legacy','indexed'])test(`unbound Platform ${mode} receipt proves one aggregate import without native principal receipts`,async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,mode),r=await run(s,c,m);
  assert.equal(r.historicalImportProven,true);assert.equal(r.originalPlatformArchiveReadbackVerifiedAtReceipt,true);
  assert.equal(r.completePlatformInventoryReadBack,true);assert.equal(r.retainedPlatformRowsReadBack,true);
  assert.equal(r.currentAuthorityClaimed,false);assert.equal(r.privateSemanticInstallationIndependentlyVerified,false);
  assert.equal(r.laneActivationIndependentlyVerified,false);assert.equal(r.ownerSignaturesIndependentlyVerified,false);
  assert.equal(r.safeImplementationIndependentlyVerified,false);
  r.ownerSnapshots.forEach((row,i)=>assert.equal(row.revision,c.certificate.admission.before_[i].revision+1n));
  assert.equal(r.events.filter(v=>v.event==='RecoveredArtistAuthorityHydrated').length,1);
  assert.equal(r.events.filter(v=>v.event==='ArtistArchiveEvidenceAppendedV2').length,c.descriptor.pageHashes.length+1);
});

test('receipt rejects later same-block original Archive append conservatively',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c);
  s.state.hooks.push(({method,host,tag})=>method==='storedPayloadCount'&&host===s.source.archive&&tag===12?[BigInt(s.archiveRows.length+1)]:undefined);
  await assert.rejects(run(s,c,m),/catalogue count/);
});

test('later destination correction consumption preserves immutable approval history',async()=>{
  const s=setup({correction:true}),c=await capture(s),m=install(s,c),p=s.platforms[0];
  s.state.hooks.push(({method,host,tag})=>{
    if(tag!==12||host!==s.destination.owners[4])return;
    if(method==='ownerStateSnapshotV2')return[{...c.after[4],revision:c.after[4].revision+1n,stateRoot:H('later Platform')}];
    if(method==='platformWorksState')return[{...p.state,correction:{...p.state.correction,correctiveGeneration:1n,accepted:true}}];
    if(['attributionState','platformCorrectionStatus','attributionClaims','staticAttributionClaims'].includes(method))throw Error('Current head must not reauthorize imported history');
  });
  assert.equal((await run(s,c,m)).historicalImportProven,true);
});

test('later destination activity cannot replace immutable correction approval fields',async()=>{
  const s=setup({correction:true}),c=await capture(s),m=install(s,c),p=s.platforms[0];
  s.state.hooks.push(({method,host,tag})=>{
    if(tag!==12||host!==s.destination.owners[4])return;
    if(method==='ownerStateSnapshotV2')return[{...c.after[4],revision:c.after[4].revision+1n,stateRoot:H('later Platform')}];
    if(method==='platformWorksState')return[{...p.state,correction:{...p.state.correction,proposedArtist:A(998),correctiveGeneration:1n,accepted:true}}];
  });
  await assert.rejects(run(s,c,m),/retained correction approval/);
});

test('later first correction approval does not invalidate a prior declaration-only import',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c),p=s.platforms[0];
  assert.equal(p.state.correction.recordHash,ZeroHash);
  s.state.hooks.push(({method,host,tag})=>{
    if(tag!==12||host!==s.destination.owners[4])return;
    if(method==='ownerStateSnapshotV2')return[{...c.after[4],revision:c.after[4].revision+1n,stateRoot:H('later first approval')}];
    // This is observed later state, not a claim that the mock executed its production path.
    if(method==='platformWorksState')return[{...p.state,correction:{...p.state.correction,recordHash:H('later approval')}}];
  });
  assert.equal((await run(s,c,m)).historicalImportProven,true);
});
test('Safe complete envelope preserves zero value, nonce and signed gas fields',async()=>{
  const s=setup(),c=await capture(s);let m=install(s,c);s.state.tx.value=1n;
  await assert.rejects(run(s,c,m),/value/);
  m=install(s,c,'legacy');s.state.safeEndingNonce=9n;await assert.rejects(run(s,c,m),/nonce/);s.state.safeEndingNonce=5n;
  m=install(s,c,'indexed');const v=Array.from(safeABI.decodeFunctionData('execTransaction',s.state.tx.data));v[4]+=1n;s.state.tx.data=safeABI.encodeFunctionData('execTransaction',v);
  await assert.rejects(run(s,c,m),/hash/);
});

test('application evidence must precede Safe success while unrelated guard logs may follow',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,'indexed');
  m.logs.push({address:A(999),topics:[H('guard')],data:'0x',index:m.logs.length,blockNumber:12,blockHash:H('block12'),transactionHash:H('tx'),removed:false});
  assert.equal((await run(s,c,m)).historicalImportProven,true);
  const success=m.logs.find(v=>v.address===s.caller);m.logs.splice(m.logs.indexOf(success),1);m.logs.unshift(success);renumber(m.logs);
  await assert.rejects(run(s,c,m),/precedes complete/);
});

test('mined envelopes are detached before later reads and original worker pins remain mandatory',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,'indexed');
  s.state.transactionHook=()=>{s.state.receipt.logs[0].data='0x';};assert.equal((await run(s,c,m)).historicalImportProven,true);
  s.state.transactionHook=null;const next=install(s,c);
  s.state.hooks.push(({method,host,tag})=>method==='getCode'&&host===s.deployment.preparationLibrary.address&&tag===12?'0x':undefined);
  await assert.rejects(run(s,c,next),/runtime/i);
});

test('refusal observes the original call after source drift without treating its changed result as failure',async()=>{
  const s=setup(),c=await capture(s),other=H('actual later commitment');
  s.state.hooks.push(({method})=>method==='hydrateRecoveredArtistAuthority'?[other]:undefined);
  const r=await workflow.observeArtistUnboundPlatformHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});
  assert.equal(r.status,'succeeded');assert.equal(r.returnedCommitment,other);assert.equal(r.capturePredictionChecked,false);
  s.state.hooks.length=0;
  s.state.hooks.push(({method})=>{if(method==='hydrateRecoveredArtistAuthority')throw Object.assign(Error('mock original refusal'),{code:'CALL_EXCEPTION',data:'0x12345678'});});
  const reverted=await workflow.observeArtistUnboundPlatformHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});
  assert.equal(reverted.status,'reverted');assert.equal(reverted.data,'0x12345678');
  s.state.hooks.length=0;
  s.state.hooks.push(({method})=>{if(method==='hydrateRecoveredArtistAuthority')throw Object.assign(Error('fake https://credential.invalid/secret'),{code:'NETWORK_ERROR',request:{authorization:'secret'}});});
  const failed=await workflow.observeArtistUnboundPlatformHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});
  assert.equal(failed.status,'rpc-failed');assert.equal(failed.data,null);assert.equal(JSON.stringify(failed,(_,v)=>typeof v==='bigint'?String(v):v).includes('secret'),false);
});

test('refusal cannot use a cloned capture, earlier block, changed header or replaced original runtime',async()=>{
  const s=setup(),c=await capture(s),observe=(value=c,tag=11)=>workflow.observeArtistUnboundPlatformHydrationRefusal(s.provider,value,{blockTag:tag,gasLimit:10000000n});
  await assert.rejects(observe(structuredClone(c)),/workflow instance/);
  await assert.rejects(observe(c,9),/precedes/);
  s.state.blockOverride=tag=>({number:tag,timestamp:100+tag,hash:tag===10?H('reorg'):H(`block${tag}`)});
  await assert.rejects(observe(),/changed|Reorg|reorg/);s.state.blockOverride=null;
  s.state.hooks.push(({method,host,tag})=>method==='getCode'&&host===s.deployment.source.registry.address&&tag===11?'0x':undefined);
  await assert.rejects(observe(),/runtime/i);
});
