// Compiler-encoded consistency mocks. These do not execute native admission or signatures.
import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroHash } from 'ethers';
import { setup, capture, install, run, renumber, rh, workflow, abi, preparedAbi, safeABI, A, H } from './current-artist-recovered-multiple-generation-hydration-workflow-fixture.mjs';

for(const royalties of [false,true])test(`complete generation capture uses original ${royalties?'WithConsents':'two-argument'} route and unfiltered admission`,async()=>{
  const s=setup({royalties}),c=await capture(s);
  assert.equal(c.certificate.admission.artists.length,2);
  assert.equal(c.certificate.admission.collections.length,3);
  assert.equal(c.certificate.admission.before_[2].revision,6n);
  assert.equal(c.registrySimulated,false);
  assert.equal(c.prepared.call.value,0n);
  assert.equal(c.prepared.call.to,c.prepared.registry);
  assert.equal(abi.parseTransaction({data:c.prepared.call.data}).name,royalties?'hydrateRecoveredArtistAuthorityWithConsents':'hydrateRecoveredArtistAuthority');
  const decoded=i=>rh.decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(c.owners[i].payload.semanticState,i,c.owners[i].payload.provenance);
  assert.equal(decoded(0).auxiliary,decoded(4).auxiliary);
  assert.ok(s.bindings.some(b=>b.bindings.current.generation>1n));
  for(let k=0;k<decoded(4).state.collections.length;k++) {
    const q=decoded(4).state.collections[k];
    const expected=c.certificate.admission.provenance.journals[4].filter(j=>j.receipt.collectionId===q.collectionId&&j.receipt.operation===24n).map(j=>j.receipt.recordHash);
    assert.deepEqual(q.records,expected);
    assert.equal(q.bindingHash,c.certificate.admission.collections[k].bindingHash);
  }
  assert.ok(s.state.calls.some(v=>v.method==='bindingAt'&&v.args[1]>1n));
});

test('complete generation simulation uses the exact caller and original zero-value Registry call',async()=>{
  const s=setup({royalties:false}),c=await capture(s);
  const r=await workflow.simulateArtistRecoveredMultipleGenerationHydration(s.provider,c,{blockTag:10,gasLimit:10000000n});
  assert.equal(r.registrySimulated,true);assert.equal(r.futureExecutionGuaranteed,false);
  const actual=s.state.calls.findLast(v=>v.method==='hydrateRecoveredArtistAuthority');
  assert.equal(actual.from,s.caller);assert.equal(actual.value,0n);assert.equal(actual.tag,10);
});

test('all retained binding generations and original acceptance records are observed',async()=>{
  const s=setup({royalties:false});await capture(s);
  for(let k=0;k<s.bindings.length;k++) {
    const b=s.bindings[k].bindings;
    for(const row of b.rows)for(const method of ['bindingAt','bindingTerms','bindingTermination'])assert.ok(s.state.calls.some(v=>v.host===s.source.owners[0]&&v.method===method&&v.args[0]===b.collectionId&&v.args[1]===row.item.generation));
    for(const row of s.acceptances[k].rows)assert.ok(s.state.calls.some(v=>v.host===s.source.owners[3]&&v.method==='acceptanceRecord'&&v.args[0]===row.bindingHash));
  }
  assert.equal(s.clocks.operations.length,2*s.bindings.reduce((n,b)=>n+b.bindings.rows.length,0));
  const observed=s.state.calls.filter(v=>v.host===s.source.owners[2]&&v.method==='authorityNonceIndexAt');
  assert.deepEqual(observed.map(v=>v.args[0]),s.payloads[2].nonces.map((_,i)=>BigInt(i)));
});

test('accepted earlier generation retains governed opening and class-two revoke independently of current binding',async()=>{
  const s=setup({acceptedHistory:true,royalties:false}),c=await capture(s);
  const history=s.attribution.find(b=>b.history.revocations.length)?.history;assert.ok(history);
  for(const row of history.revocations) {
    assert.equal(row.resolution.actionClass,2n);
    assert.ok(s.state.calls.some(v=>v.method==='attributionDisputeRecord'&&v.args[0]===row.opening.recordHash));
    assert.ok(s.state.calls.some(v=>v.method==='attributionDisputeResolution'&&v.args[0]===row.resolution.actionId));
  }
  assert.ok(c.certificate.admission.provenance.journals[4].some(row=>row.receipt.operation===44n));
});

test('zero-op24 current preparation still reads the complete original Archive inventory',async()=>{
  const s=setup({attestations:false,royalties:false}),c=await capture(s);
  assert.equal(c.certificate.admission.provenance.journals[4].filter(j=>j.receipt.operation===24n).length,0);
  assert.ok(s.archiveRows.length>0);
  for(const row of s.archiveRows)assert.ok(s.state.calls.some(v=>v.method==='storedPayloadAt'&&v.host===s.source.archive&&v.args[0]===row.catalogueIndex));
  assert.ok(s.state.calls.some(v=>v.method==='storedPayloadCount'&&v.host===s.source.archive));
});

test('op24 records keep saved generations and global Artist credential order through a corrective binding',async()=>{
  const s=setup({acceptedHistory:true,attestations:true,royalties:false}),c=await capture(s);
  const journal=c.certificate.admission.provenance.journals[4].filter(row=>row.receipt.operation===24n);
  assert.ok(journal.length>0);
  assert.ok(s.attestations.some(b=>b.records.some(row=>row.attestation.record.generation<b.item.generation)));
  assert.ok(s.attestations.some(b=>b.records.some(row=>row.attestation.record.generation===b.item.generation)));
  assert.ok([...s.credentialHeads.values()].some(head=>head.revision>1n&&head.previousRecordHash!==ZeroHash));
  assert.deepEqual(s.state.calls.filter(v=>v.host===s.source.owners[4]&&v.method==='attestationRecord').map(v=>v.args[0]),journal.map(v=>v.receipt.recordHash));
  for(const head of s.credentialRecords.values()) {
    if(head.recordHash===ZeroHash)continue;
    const b=s.bindings.find(b=>b.bindings.collectionId===head.collectionId).bindings;
    assert.equal(head.bindingHash,b.rows[Number(head.generation-1n)].item.bindingHash);
    assert.ok(s.state.calls.some(v=>v.method==='c2paCredentialRecord'&&v.args[0]===head.recordHash));
  }
  const rows=s.state.calls.filter(v=>v.host===s.source.owners[4]);
  assert.ok(rows.findIndex(v=>v.method==='c2paCredentialRecord')>rows.findLastIndex(v=>v.method==='personhoodProofSummaryHash'));
});

test('economics first-record association is distinct from a later accepted-generation occurrence',async()=>{
  const s=setup({acceptedHistory:true,royalties:false});
  const row=s.contents.flatMap(b=>b.original.economics).find(r=>r.item.recordHash!==r.item.association.originalRecord);assert.ok(row);
  s.state.hooks.push(({method,host,args})=>method==='economicsRecordAssociation'&&host===s.source.owners[6]&&args[0]===row.item.recordHash?[{...row.item.association,originalRecord:row.item.recordHash}]:undefined);
  await assert.rejects(capture(s),/economics record association/);
});

test('non-anchor retained generation is never coerced to generation one',async()=>{
  const s=setup(),b=s.bindings.findLast(b=>b.bindings.rows.length>1).bindings,row=b.rows.at(-1);
  s.state.hooks.push(({method,host,args})=>host===s.source.owners[0]&&method==='bindingAt'&&args[0]===b.collectionId&&args[1]===row.item.generation?[{...row.item,generation:1n}]:undefined);
  await assert.rejects(capture(s),/Retained generation binding/);
});

test('original generation terminal and correction records must match retained immutable facts',async()=>{
  const s=setup(),b=s.bindings.find(b=>b.bindings.rows.length>1),row=b.bindings.rows[1],correction=b.corrections[1];
  s.state.hooks.push(({method,host,args})=>host===s.source.owners[0]&&method==='bindingCorrection'&&args[0]===row.item.bindingHash?[correction.approval,H('wrong correction')]:undefined);
  await assert.rejects(capture(s),/Retained generation correction/);
});

test('full Archive STOP carriers and same-owner completion clocks remain mandatory',async()=>{
  const s=setup(),row=s.archiveRows[0];s.state.codes.set(row.pointer,`0x01${row.raw.slice(2)}`);
  await assert.rejects(capture(s),/STOP/);
});

test('complete original catalogue cannot hide an unrelated appended row with no op24',async()=>{
  const s=setup({attestations:false,royalties:false});
  s.state.sourceCatalogs.get(s.source.archive).push({pointer:A(999),payloadType:H('other payload'),payloadHash:H('other bytes')});
  await assert.rejects(capture(s),/catalogue count/);
});

test('original clock metadata cannot come from a future observation block',async()=>{
  const s=setup(),row=s.archiveRows[0];
  s.state.hooks.push(({method,host,args})=>method==='artistEvidenceMetadataV2'&&host===s.source.archive&&args[0]===row.evidenceId?[row.hash,row.pointer,BigInt((row.raw.length-2)/2),11n]:undefined);
  await assert.rejects(capture(s),/future block/);
});

test('every non-anchor lane remains part of complete capture',async()=>{
  const s=setup(),q=s.certificate.admission.collections.at(-1);
  s.state.hooks.push(({method,args})=>method==='importedLaneVerified'&&args[0]===2n&&BigInt(args[1])===q.collectionId?[false,H('missing'),BigInt(q.records.length)]:undefined);
  await assert.rejects(capture(s),/operation56 lane/);
});

test('full cross-generation grant usage is read from the original Identity owner',async()=>{
  const s=setup(),g=s.identities.flatMap(i=>i.delegations).find(g=>g.record.uses>0n);assert.ok(g);
  s.state.hooks.push(({method,host,args})=>method==='delegationRecord'&&host===s.source.owners[2]&&args[0]===g.recordHash?[{...g.record,uses:g.record.uses-1n}]:undefined);
  await assert.rejects(capture(s),/grant version, usage or revocation/);
});

test('new generation Prepared bytes must remain canonical before Registry simulation',async()=>{
  const s=setup();
  s.state.hooks.push(({method,fragment})=>method==='prepare'?`${preparedAbi.encodeFunctionResult(fragment,[s.certificate])}${'00'.repeat(32)}`:undefined);
  await assert.rejects(capture(s),/Noncanonical/);
  assert.equal(s.state.calls.some(v=>v.method.startsWith('hydrateRecovered')),false);
});

test('original generation request and royalty order are owned before the first await',async()=>{
  const s=setup({royalties:true}),network=s.provider.getNetwork;let once=true;
  s.provider.getNetwork=async()=>{if(once){once=false;s.input.royaltyFreezes[0].expectedAssignmentHash=H('caller mutation');}return network();};
  const c=await capture(s);assert.notEqual(c.prepared.royaltyFreezes[0].expectedAssignmentHash,s.input.royaltyFreezes[0].expectedAssignmentHash);
});

for(const mode of ['direct','legacy','indexed'])test(`complete generation ${mode} receipt proves one aggregate import with exact original clocks`,async()=>{
  const s=setup({royalties:false}),c=await capture(s),m=install(s,c,mode),r=await run(s,c,m);
  assert.equal(r.historicalImportProven,true);assert.equal(r.originalArchiveClockReadbackVerifiedAtReceipt,true);
  assert.equal(r.completeGenerationInventoryReadBack,true);assert.equal(r.retainedAttestationRowsReadBack,true);
  assert.equal(r.currentAuthorityClaimed,false);assert.equal(r.privateSemanticInstallationIndependentlyVerified,false);
  assert.equal(r.laneActivationIndependentlyVerified,false);assert.equal(r.ownerSignaturesIndependentlyVerified,false);
  assert.equal(r.safeImplementationIndependentlyVerified,false);
  r.ownerSnapshots.forEach((row,i)=>assert.equal(row.revision,c.certificate.admission.before_[i].revision+1n));
  assert.equal(r.events.filter(v=>v.event==='RecoveredArtistAuthorityHydrated').length,1);
  assert.equal(r.events.filter(v=>v.event==='ArtistArchiveEvidenceAppendedV2').length,c.descriptor.pageHashes.length+1);
});

test('receipt full catalogue rejects same-block original append even with empty op24',async()=>{
  const s=setup({attestations:false,royalties:false}),c=await capture(s),m=install(s,c);
  s.state.hooks.push(({method,host,tag})=>method==='storedPayloadCount'&&host===s.source.archive&&tag===12?[BigInt(s.archiveRows.length+1)]:undefined);
  await assert.rejects(run(s,c,m),/catalogue count/);
});

test('later mutable destination generation heads do not reauthorize historical import',async()=>{
  const s=setup({royalties:false}),c=await capture(s),m=install(s,c);
  s.state.hooks.push(({method,host,tag})=>{
    if(tag!==12||![s.destination.owners[0],s.destination.owners[4]].includes(host))return;
    const i=host===s.destination.owners[0]?0:4;
    if(method==='ownerStateSnapshotV2')return[{...c.after[i],revision:c.after[i].revision+1n,stateRoot:H(`later owner${i}`)}];
    if(['binding','attributionState','attributionDispute','platformWorksState','attestation','c2paCredentialHead','personhoodAttestation'].includes(method))throw Error('Current head must not reauthorize retained import');
  });
  assert.equal((await run(s,c,m)).historicalImportProven,true);
});

test('immutable earlier binding remains checked after later destination activity',async()=>{
  const s=setup({royalties:false}),c=await capture(s),m=install(s,c),b=s.bindings.find(b=>b.bindings.rows.length>1).bindings;
  s.state.hooks.push(({method,host,tag,args})=>{
    if(host!==s.destination.owners[0]||tag!==12)return;
    if(method==='ownerStateSnapshotV2')return[{...c.after[0],revision:c.after[0].revision+1n,stateRoot:H('later binding')}];
    if(method==='bindingAt'&&args[0]===b.collectionId&&args[1]===1n)return[{...b.rows[0].item,bindingHash:H('wrong earlier binding')}];
  });
  await assert.rejects(run(s,c,m),/Retained generation binding/);
});

test('Safe complete envelope preserves zero value, nonce and signed gas fields',async()=>{
  const s=setup({royalties:false}),c=await capture(s);let m=install(s,c);s.state.tx.value=1n;
  await assert.rejects(run(s,c,m),/value/);
  m=install(s,c,'legacy');s.state.safeEndingNonce=9n;await assert.rejects(run(s,c,m),/nonce/);s.state.safeEndingNonce=5n;
  m=install(s,c,'indexed');const v=Array.from(safeABI.decodeFunctionData('execTransaction',s.state.tx.data));v[4]+=1n;s.state.tx.data=safeABI.encodeFunctionData('execTransaction',v);
  await assert.rejects(run(s,c,m),/hash/);
});

test('application evidence must precede Safe success while unrelated guard logs may follow',async()=>{
  const s=setup({royalties:false}),c=await capture(s),m=install(s,c,'indexed');
  m.logs.push({address:A(999),topics:[H('guard')],data:'0x',index:m.logs.length,blockNumber:12,blockHash:H('block12'),transactionHash:H('tx'),removed:false});
  assert.equal((await run(s,c,m)).historicalImportProven,true);
  const success=m.logs.find(v=>v.address===s.caller);m.logs.splice(m.logs.indexOf(success),1);m.logs.unshift(success);renumber(m.logs);
  await assert.rejects(run(s,c,m),/precedes complete/);
});

test('mined envelopes are detached before later reads and original worker pins remain mandatory',async()=>{
  const s=setup({royalties:false}),c=await capture(s),m=install(s,c,'indexed');
  s.state.transactionHook=()=>{s.state.receipt.logs[0].data='0x';};assert.equal((await run(s,c,m)).historicalImportProven,true);
  s.state.transactionHook=null;const next=install(s,c);
  s.state.hooks.push(({method,host,tag})=>method==='getCode'&&host===s.deployment.preparationLibrary.address&&tag===12?'0x':undefined);
  await assert.rejects(run(s,c,next),/runtime/i);
});

test('refusal observes the original call after source drift without treating its changed result as failure',async()=>{
  const s=setup({royalties:false}),c=await capture(s),other=H('actual later commitment');
  s.state.hooks.push(({method})=>method==='hydrateRecoveredArtistAuthority'?[other]:undefined);
  const r=await workflow.observeArtistRecoveredMultipleGenerationHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});
  assert.equal(r.status,'succeeded');assert.equal(r.returnedCommitment,other);assert.equal(r.capturePredictionChecked,false);
  s.state.hooks.length=0;
  s.state.hooks.push(({method})=>{if(method==='hydrateRecoveredArtistAuthority')throw Object.assign(Error('mock original refusal'),{code:'CALL_EXCEPTION',data:'0x12345678'});});
  const reverted=await workflow.observeArtistRecoveredMultipleGenerationHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});
  assert.equal(reverted.status,'reverted');assert.equal(reverted.data,'0x12345678');
  s.state.hooks.length=0;
  s.state.hooks.push(({method})=>{if(method==='hydrateRecoveredArtistAuthority')throw Object.assign(Error('fake https://credential.invalid/secret'),{code:'NETWORK_ERROR',request:{authorization:'secret'}});});
  const failed=await workflow.observeArtistRecoveredMultipleGenerationHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});
  assert.equal(failed.status,'rpc-failed');assert.equal(failed.data,null);assert.equal(JSON.stringify(failed,(_,v)=>typeof v==='bigint'?String(v):v).includes('secret'),false);
});

test('refusal cannot use a cloned capture, earlier block, changed header or replaced original runtime',async()=>{
  const s=setup({royalties:false}),c=await capture(s),observe=(value=c,tag=11)=>workflow.observeArtistRecoveredMultipleGenerationHydrationRefusal(s.provider,value,{blockTag:tag,gasLimit:10000000n});
  await assert.rejects(observe(structuredClone(c)),/workflow instance/);
  await assert.rejects(observe(c,9),/precedes/);
  s.state.blockOverride=tag=>({number:tag,timestamp:100+tag,hash:tag===10?H('reorg'):H(`block${tag}`)});
  await assert.rejects(observe(),/changed|Reorg|reorg/);s.state.blockOverride=null;
  s.state.hooks.push(({method,host,tag})=>method==='getCode'&&host===s.deployment.source.registry.address&&tag===11?'0x':undefined);
  await assert.rejects(observe(),/runtime/i);
});
