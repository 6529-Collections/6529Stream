// Compiler-encoded RPC consistency mocks, not native lifecycle/signature execution.
import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroHash } from 'ethers';
import { setup, capture, install, run, renumber, rh, workflow, abi, preparedAbi, safeABI, A, H } from './current-artist-recovered-multiple-attestation-hydration-workflow-fixture.mjs';

for(const royalties of [false,true]) test(`plural attestation capture uses original ${royalties?'WithConsents':'two-argument'} route and full projected scope`,async()=>{
  const s=setup({royalties}),c=await capture(s);
  assert.equal(c.certificate.admission.artists.length,2);assert.equal(c.certificate.admission.collections.length,3);
  assert.equal(c.certificate.admission.before_[2].revision,6n);assert.equal(c.registrySimulated,false);
  const method=royalties?'hydrateRecoveredArtistAuthorityWithConsents':'hydrateRecoveredArtistAuthority';
  assert.equal(abi.parseTransaction({data:c.prepared.call.data}).name,method);
  const owner4=c.owners[4].payload,decoded=rh.decodeArtistRecoveredMultipleAttestationHydrationAuxiliary(owner4.semanticState,4,owner4.provenance);
  assert.notEqual(decoded.auxiliary,'0x');
  for(const q of decoded.state.collections)assert.deepEqual(q.records,c.certificate.admission.provenance.journals[4].filter(j=>j.receipt.collectionId===q.collectionId).map(j=>j.receipt.recordHash));
  assert.ok(c.certificate.admission.collections.some((q,i)=>q.records.length>decoded.state.collections[i].records.length));
  const simulation=await workflow.simulateArtistRecoveredMultipleAttestationHydration(s.provider,c,{blockTag:11,gasLimit:10000000n});
  assert.equal(simulation.registrySimulated,true);assert.equal(simulation.futureExecutionGuaranteed,false);
  const called=s.state.calls.findLast(r=>r.method===method);assert.equal(called.from,s.caller);assert.equal(called.value,0n);
});

test('original op24 record observations precede global credential and collection heads',async()=>{
  const s=setup(),c=await capture(s),rows=s.state.calls.filter(v=>v.host===s.source.owners[4]);
  const journal=c.certificate.admission.provenance.journals[4];
  assert.deepEqual(rows.filter(v=>v.method==='attestationRecord').map(v=>v.args[0]),journal.map(v=>v.receipt.recordHash));
  const firstHead=rows.findIndex(v=>v.method==='c2paCredentialRecord'),lastRow=rows.findLastIndex(v=>v.method==='personhoodProofSummaryHash');
  assert.ok(firstHead>lastRow);
  assert.deepEqual(rows.filter(v=>v.method==='c2paCredentialRecord').map(v=>v.args[0]),journal.map(v=>v.receipt.recordHash));
  assert.equal(rows.filter(v=>v.method==='c2paCredentialHead').length,2);
  assert.equal(rows.filter(v=>v.method==='personhoodAttestation').length,3);
});

test('full Archive catalogue authenticates original owner4 clocks and preserves native owner clocks',async()=>{
  const s=setup(),c=await capture(s);
  assert.equal(s.clocks.operations.length,6);
  assert.ok(s.envelopes.some(e=>e.operation===2n&&e.after_[3].revision!==e.after_[4].revision));
  for(const r of s.archiveRows){
    assert.ok(s.state.calls.some(v=>v.method==='storedPayloadAt'&&v.host===s.source.archive&&v.args[0]===r.catalogueIndex));
    assert.ok(s.state.calls.some(v=>v.method==='artistEvidenceMetadataV2'&&v.host===s.source.archive&&v.args[0]===r.evidenceId));
  }
  assert.equal(c.certificate.admission.provenance.journals[4].length,s.attestationPlan.length);
});

test('non-anchor attestation association is checked',async()=>{
  const s=setup(),r=s.attestations.at(-1).records[0].attestation;
  s.state.hooks.push(({method,host,args})=>host===s.source.owners[4]&&method==='attestationAssociation'&&args[0]===r.record.recordHash?[{...r.association,artistId:H('wrong artist')}]:undefined);
  await assert.rejects(capture(s),/attestation association/);
});

test('original statement carrier bytes cannot change under a retained statement hash',async()=>{
  const s=setup(),r=s.attestations[0].records[0].attestation;
  s.state.hooks.push(({method,host,args})=>host===s.source.owners[4]&&method==='statementBytes'&&args[0]===r.record.statementHash?['0x1234']:undefined);
  await assert.rejects(capture(s),/statement carrier/);
});

test('complete op24 input witness order remains tied to each selected collection',async()=>{
  const s=setup(),w=s.input.request.records.witnesses.find(w=>w.attestations.length>1);assert.ok(w);w.attestations.reverse();
  await assert.rejects(capture(s),/attestation|witness|order/i);
});

test('global cross-collection credential chain cannot be replaced with a local collection head',async()=>{
  const s=setup(),head=[...s.credentialHeads.values()].find(v=>v.revision>1n);assert.ok(head);
  s.state.hooks.push(({method,host,args})=>host===s.source.owners[4]&&method==='c2paCredentialRecord'&&args[0]===head.recordHash?[{...head,revision:1n,previousRecordHash:ZeroHash}]:undefined);
  await assert.rejects(capture(s),/credential record/);
});

test('collection personhood remains distinct from its Artist credential head',async()=>{
  const s=setup(),b=s.attestations.find(b=>b.personhood.length);assert.ok(b);
  const wrong=s.attestations.flatMap(v=>v.records).find(v=>v.attestation.input.terms.schemaId===H('6529STREAM_ARTIST_C2PA_CREDENTIALS_V1')).attestation.record;
  s.state.hooks.push(({method,host,args})=>host===s.source.owners[4]&&method==='personhoodAttestation'&&args[0]===b.collectionId?[wrong]:undefined);
  await assert.rejects(capture(s),/personhood head/);
});

test('original clock STOP carrier mutation is rejected before supplied envelope authority',async()=>{
  const s=setup(),row=s.archiveRows[1];s.state.codes.set(row.pointer,`0x01${row.raw.slice(2)}`);
  await assert.rejects(capture(s),/STOP/);
});

test('original clock metadata rejects a future block and preserves exact evidence version',async()=>{
  const s=setup(),r=s.archiveRows[0];
  s.state.hooks.push(({method,host,args})=>method==='artistEvidenceMetadataV2'&&host===s.source.archive&&args[0]===r.evidenceId?[r.hash,r.pointer,BigInt((r.raw.length-2)/2),11n]:undefined);
  await assert.rejects(capture(s),/future block/);
});

test('complete catalogue commits non-selected rows and cannot omit an appended carrier',async()=>{
  const s=setup();s.state.sourceCatalogs.get(s.source.archive).push({pointer:A(999),payloadType:H('unrelated retained payload'),payloadHash:H('unrelated bytes')});
  await assert.rejects(capture(s),/catalogue count/);
});

test('original acceptance readback cannot substitute raw cross-owner revisions or another record',async()=>{
  const s=setup(),a=s.acceptances.at(-1);
  s.state.hooks.push(({method,host,args})=>method==='acceptanceRecord'&&host===s.source.owners[3]&&args[0]===a.scope.bindingHash?[H('other acceptance')]:undefined);
  await assert.rejects(capture(s),/clock acceptance record/);
});

test('every selected non-anchor lane and complete grant use remains required',async()=>{
  const s=setup(),q=s.certificate.admission.collections.at(-1);
  s.state.hooks.push(({method,args})=>method==='importedLaneVerified'&&args[0]===2n&&BigInt(args[1])===q.collectionId?[false,H('missing lane'),BigInt(q.records.length)]:undefined);
  await assert.rejects(capture(s),/operation56 lane/);
});

test('op24 and consent families share the original complete grant usage record',async()=>{
  const s=setup(),g=s.identities.flatMap(v=>v.delegations).find(v=>v.record.uses>0n);assert.ok(g);
  s.state.hooks.push(({method,host,args})=>method==='delegationRecord'&&host===s.source.owners[2]&&args[0]===g.recordHash?[{...g.record,uses:g.record.uses-1n}]:undefined);
  await assert.rejects(capture(s),/grant version, usage or revocation/);
});

test('canonical producer output and pre-await input ownership remain mandatory',async()=>{
  const s=setup(),network=s.provider.getNetwork;let first=true;
  s.provider.getNetwork=async()=>{if(first){first=false;s.input.royaltyFreezes[0].expectedAssignmentHash=H('caller mutation');}return network();};
  const c=await capture(s);assert.notEqual(c.prepared.royaltyFreezes[0].expectedAssignmentHash,s.input.royaltyFreezes[0].expectedAssignmentHash);
});

test('noncanonical original Prepared output has no fallback or simulated installation',async()=>{
  const s=setup();s.state.hooks.push(({method,fragment})=>method==='prepare'?`${preparedAbi.encodeFunctionResult(fragment,[s.certificate])}${'00'.repeat(32)}`:undefined);
  await assert.rejects(capture(s),/Noncanonical/);assert.equal(s.state.calls.some(v=>v.method.startsWith('hydrateRecovered')),false);
});

for(const mode of ['direct','legacy','indexed'])test(`plural attestation ${mode} receipt proves aggregate import with exact original clock readback`,async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,mode),r=await run(s,c,m);
  assert.equal(r.historicalImportProven,true);assert.equal(r.originalArchiveClockReadbackVerifiedAtReceipt,true);
  assert.equal(r.retainedAttestationRowsReadBack,true);assert.equal(r.currentAuthorityClaimed,false);
  assert.equal(r.privateSemanticInstallationIndependentlyVerified,false);assert.equal(r.laneActivationIndependentlyVerified,false);
  assert.equal(r.ownerSignaturesIndependentlyVerified,false);assert.equal(r.safeImplementationIndependentlyVerified,false);
  r.ownerSnapshots.forEach((v,i)=>assert.equal(v.revision,c.certificate.admission.before_[i].revision+1n));
  assert.equal(r.events.filter(v=>v.event==='RecoveredArtistAuthorityHydrated').length,1);
  assert.equal(r.events.filter(v=>v.event==='ArtistArchiveEvidenceAppendedV2').length,c.descriptor.pageHashes.length+1);
});

test('mined source catalogue append is an explicit conservative attribution refusal',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c);
  s.state.hooks.push(({method,host,tag})=>method==='storedPayloadCount'&&host===s.source.archive&&tag===12?[BigInt(s.archiveRows.length+1)]:undefined);
  await assert.rejects(run(s,c,m),/catalogue count/);
});

test('receipt checks immutable attestation records even after later owner4 activity',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c),r=s.attestations.at(-1).records[0].attestation;
  s.state.hooks.push(({method,host,tag,args})=>{
    if(host!==s.destination.owners[4]||tag!==12)return;
    if(method==='ownerStateSnapshotV2')return[{...c.after[4],revision:c.after[4].revision+1n,stateRoot:H('later owner4')}];
    if(['c2paCredentialHead','personhoodAttestation','attestation','attributionState'].includes(method))throw Error('Later mutable head must not reauthorize retained import');
    if(method==='attestationRecord'&&args[0]===r.record.recordHash)return[{...r.record,signer:A(999)}];
  });
  await assert.rejects(run(s,c,m),/attestation record/);
});

test('later mutable heads preserve historical readback without fresh import authority',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c);
  s.state.hooks.push(({method,host,tag})=>{
    if(host!==s.destination.owners[4]||tag!==12)return;
    if(method==='ownerStateSnapshotV2')return[{...c.after[4],revision:c.after[4].revision+1n,stateRoot:H('later owner4')}];
    if(['c2paCredentialHead','personhoodAttestation','attestation','attributionState'].includes(method))throw Error('Later mutable head must not reauthorize history');
  });
  assert.equal((await run(s,c,m)).historicalImportProven,true);
});

test('Safe value nonce and all signed gas fields remain exact',async()=>{
  const s=setup(),c=await capture(s);let m=install(s,c);s.state.tx.value=1n;await assert.rejects(run(s,c,m),/value/);
  m=install(s,c,'legacy');s.state.safeEndingNonce=9n;await assert.rejects(run(s,c,m),/nonce/);s.state.safeEndingNonce=5n;
  m=install(s,c,'indexed');const values=Array.from(safeABI.decodeFunctionData('execTransaction',s.state.tx.data));values[4]+=1n;s.state.tx.data=safeABI.encodeFunctionData('execTransaction',values);
  await assert.rejects(run(s,c,m),/hash/);
});

test('application evidence precedes Safe success while unrelated guard logs may follow',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,'indexed');
  m.logs.push({address:A(999),topics:[H('guard')],data:'0x',index:m.logs.length,blockNumber:12,blockHash:H('block12'),transactionHash:H('tx'),removed:false});
  assert.equal((await run(s,c,m)).historicalImportProven,true);
  const success=m.logs.find(v=>v.address===s.caller);m.logs.splice(m.logs.indexOf(success),1);m.logs.unshift(success);renumber(m.logs);
  await assert.rejects(run(s,c,m),/precedes complete/);
});

test('detached mined envelopes and original worker runtime pins survive provider mutation',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,'indexed');
  s.state.transactionHook=()=>{s.state.receipt.logs[0].data='0x';};assert.equal((await run(s,c,m)).historicalImportProven,true);
  s.state.transactionHook=null;const next=install(s,c);s.state.hooks.push(({method,host,tag})=>method==='getCode'&&host===s.deployment.preparationLibrary.address&&tag===12?'0x':undefined);
  await assert.rejects(run(s,c,next),/runtime/i);
});
