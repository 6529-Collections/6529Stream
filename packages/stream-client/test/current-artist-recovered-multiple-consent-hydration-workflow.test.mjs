// Compiler-encoded RPC consistency only: no native execution, signer recovery or private-state proof.
import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroHash } from 'ethers';
import { setup, capture, install, run, renumber, rh, workflow, abi, preparedAbi, safeABI, A, H } from './current-artist-recovered-multiple-consent-hydration-workflow-fixture.mjs';

for (const royalties of [false,true]) test(`complete plural consents capture and original ${royalties?'WithConsents':'two-argument'} simulation`, async()=>{
  const s=setup({royalties}),c=await capture(s);
  assert.equal(c.certificate.admission.artists.length,2);assert.equal(c.certificate.admission.collections.length,3);
  assert.equal(c.certificate.admission.before_[2].revision,6n);assert.equal(c.registrySimulated,false);
  const method=royalties?'hydrateRecoveredArtistAuthorityWithConsents':'hydrateRecoveredArtistAuthority';
  assert.equal(abi.parseTransaction({data:c.prepared.call.data}).name,method);
  assert.equal(c.prepared.royaltyFreezes.length>0,royalties);
  for(const q of [...c.certificate.admission.artists,...c.certificate.admission.collections])assert.ok(s.state.calls.some(v=>v.method==='importedLaneVerified'&&(q.collectionId===0n?v.args[1]===q.artistId:BigInt(v.args[1])===q.collectionId)));
  const checked=await workflow.simulateArtistRecoveredMultipleConsentHydration(s.provider,c,{blockTag:11,gasLimit:10000000n});
  assert.equal(checked.registrySimulated,true);assert.equal(checked.futureExecutionGuaranteed,false);
  const tx=s.state.calls.findLast(v=>v.method===method);assert.equal(tx.host,s.destination.registry);assert.equal(tx.from,s.caller);assert.equal(tx.value,0n);
  for(const getter of ['policyRecord','economicsRecord','economicsRecordForBinding','saleConsentRecord','contentConsentRecord','contentFreezeRecord','delegationRecord'])assert.ok(s.state.calls.some(v=>v.method===getter),getter);
});

test('source rows preserve global 17/20/21 observation order within each selected collection',async()=>{
  const s=setup(),c=await capture(s),host=s.source.owners[6];
  const observations=s.state.calls.filter(v=>v.host===host&&['contentConsentRecord','royaltyFreezeRecord','contentFreezeRecord'].includes(v.method));
  const expected=c.certificate.admission.collections.flatMap(q=>c.certificate.admission.provenance.journals[6].filter(j=>j.receipt.collectionId===q.collectionId&&[17n,20n,21n].includes(j.receipt.operation)).map(j=>({method:{17:'contentConsentRecord',20:'royaltyFreezeRecord',21:'contentFreezeRecord'}[Number(j.receipt.operation)],hash:j.receipt.recordHash})));
  assert.deepEqual(observations.map(v=>v.method),expected.map(v=>v.method));
  observations.forEach((v,i)=>{if(v.method!=='royaltyFreezeRecord')assert.equal(v.args[0],expected[i].hash);});
});

test('non-anchor collection retained content and per-lock heads are checked',async()=>{
  const s=setup(),b=s.contents.at(-1),record=b.freezes.at(-1);
  s.state.hooks.push(({method,host,args})=>method==='contentFreezeAt'&&host===s.source.owners[6]&&args[0]===b.original.collectionId?[{...record,recordHash:H('wrong non-anchor head')}]:undefined);
  await assert.rejects(capture(s),/per-lock freeze head/);
});

test('every selected non-anchor Artist and collection requires its imported lane',async()=>{
  const s=setup(),q=s.certificate.admission.collections.at(-1);
  s.state.hooks.push(({method,args})=>method==='importedLaneVerified'&&args[0]===2n&&BigInt(args[1])===q.collectionId?[false,H('missing lane'),BigInt(q.records.length)]:undefined);
  await assert.rejects(capture(s),/operation56 lane/);
});

test('aggregate shared-grant uses and revocation state are read from the original Identity owner',async()=>{
  const s=setup(),grant=s.identities.flatMap(i=>i.delegations).find(r=>r.record.uses>0n);assert.ok(grant);
  s.state.hooks.push(({method,host,args})=>method==='delegationRecord'&&host===s.source.owners[2]&&args[0]===grant.recordHash?[{...grant.record,uses:grant.record.uses+1n}]:undefined);
  await assert.rejects(capture(s),/grant version, usage or revocation/);
});

test('op17 and op21 cannot inherit a delegated association from other consent families',async()=>{
  const s=setup(),record=s.contents[1].consents[0].recordHash;
  s.state.hooks.push(({method,host,args})=>method==='recordDelegation'&&host===s.source.owners[6]&&args[0]===record?[H('foreign grant')]:undefined);
  await assert.rejects(capture(s),/operation17 must remain undelegated/);
});

test('global royalty and per-collection economics witness ordering are part of the prepared input',async()=>{
  const s=setup();assert.ok(s.input.royaltyFreezes.length>1);s.input.royaltyFreezes.reverse();
  await assert.rejects(capture(s),/royalt|terms|witness|order/i);
  const e=setup();assert.ok(e.input.request.records.witnesses.length>1);e.input.request.records.witnesses.reverse();
  await assert.rejects(capture(e),/economics|witness|order/i);
});

test('canonical producer bytes and copied request inputs remain mandatory',async()=>{
  const s=setup(),network=s.provider.getNetwork;let first=true;
  s.provider.getNetwork=async()=>{if(first){first=false;s.input.royaltyFreezes[0].expectedAssignmentHash=H('mutated caller input');}return network();};
  const c=await capture(s);assert.notEqual(c.prepared.royaltyFreezes[0].expectedAssignmentHash,s.input.royaltyFreezes[0].expectedAssignmentHash);
  const bad=setup();bad.state.hooks.push(({method,fragment})=>method==='prepare'?`${preparedAbi.encodeFunctionResult(fragment,[bad.certificate])}${'00'.repeat(32)}`:undefined);
  await assert.rejects(capture(bad),/Noncanonical/);
});

test('original unsupported-history refusal has no fallback hydration call',async()=>{
  const s=setup();s.state.hooks.push(({method})=>{if(method==='prepare')throw Error('original MULTIPLE_CONSENTS unsupported profile');});
  await assert.rejects(capture(s),/original MULTIPLE_CONSENTS unsupported/);
  assert.equal(s.state.calls.some(v=>v.method.startsWith('hydrateRecovered')),false);
});

test('direct and both Safe receipts retain one aggregate apply per owner and complete operation60 evidence',async()=>{
  const s=setup(),c=await capture(s);
  for(const mode of ['direct','legacy','indexed']){
    const m=install(s,c,mode),r=await run(s,c,m);
    assert.equal(r.historicalImportProven,true);assert.equal(r.currentAuthorityClaimed,false);
    assert.equal(r.privateSemanticInstallationIndependentlyVerified,false);assert.equal(r.laneActivationIndependentlyVerified,false);
    assert.equal(r.ownerSignaturesIndependentlyVerified,false);assert.equal(r.safeImplementationIndependentlyVerified,false);
    assert.equal(r.events.filter(v=>v.event==='RecoveredArtistAuthorityHydrated').length,1);
    assert.equal(r.events.filter(v=>v.event==='ArtistArchiveEvidenceAppendedV2').length,c.descriptor.pageHashes.length+1);
    r.ownerSnapshots.forEach((v,i)=>assert.equal(v.revision,c.certificate.admission.before_[i].revision+1n));
  }
});

test('receipt input, value, Safe nonce and every signed gas field remain exact',async()=>{
  const s=setup(),c=await capture(s);
  let m=install(s,c);s.state.tx.value=1n;await assert.rejects(run(s,c,m),/value/);
  m=install(s,c,'legacy');s.state.safeEndingNonce=9n;await assert.rejects(run(s,c,m),/nonce/);s.state.safeEndingNonce=5n;
  m=install(s,c,'indexed');const fields=Array.from(safeABI.decodeFunctionData('execTransaction',s.state.tx.data));fields[4]+=1n;s.state.tx.data=safeABI.encodeFunctionData('execTransaction',fields);
  await assert.rejects(run(s,c,m),/hash/);
});

test('application evidence precedes Safe success while unrelated guard logs may follow it',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,'indexed');
  m.logs.push({address:A(999),topics:[H('guard')],data:'0x',index:m.logs.length,blockNumber:12,blockHash:H('block12'),transactionHash:H('tx'),removed:false});
  assert.equal((await run(s,c,m)).historicalImportProven,true);
  const success=m.logs.find(v=>v.address===s.caller);m.logs.splice(m.logs.indexOf(success),1);m.logs.unshift(success);renumber(m.logs);
  await assert.rejects(run(s,c,m),/precedes complete/);
});

test('retained consent records and aggregate nonce order must match the exact imported revision',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c),record=s.contents.at(-1).consents[0];
  s.state.hooks.push(({method,host,tag,args})=>method==='contentConsentRecord'&&host===s.destination.owners[6]&&tag===12&&args[0]===record.recordHash?[{...record,authorityClass:4n}]:undefined);
  await assert.rejects(run(s,c,m),/operation17 record/);s.state.hooks.pop();
  s.state.hooks.push(({method,host,tag,args})=>method==='authorityNonceIndexAt'&&host===s.destination.owners[2]&&tag===12?[c.owners[2].payload.nonces[Number(args[0])===0?1:0].index]:undefined);
  await assert.rejects(run(s,c,m),/nonce insertion/);
});

test('Archive pages, once-only coordinator commit and mined worker runtimes are required',async()=>{
  const s=setup(),c=await capture(s);let m=install(s,c);s.state.codes.set(A(200),'0x01');
  await assert.rejects(run(s,c,m),/Archive|carrier|STOP|runtime/i);
  m=install(s,c);const commit=m.logs.find(v=>v.topics[0]===abi.getEvent('RecoveredArtistAuthorityHydrated').topicHash);m.logs.push({...commit});renumber(m.logs);
  await assert.rejects(run(s,c,m),/hydration event/i);
  m=install(s,c);s.state.hooks.push(({method,host,tag})=>method==='getCode'&&host===s.deployment.preparationLibrary.address&&tag===12?'0x':undefined);
  await assert.rejects(run(s,c,m),/runtime/i);
});

test('later owner revisions preserve history without claiming fresh import or current grants',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c);
  s.state.hooks.push(({method,host,tag})=>{
    const i=s.destination.owners.indexOf(host);if(tag!==12||![2,6].includes(i))return;
    if(method==='ownerStateSnapshotV2')return[{...c.after[i],revision:c.after[i].revision+1n,stateRoot:H(`later${i}`)}];
    if(['delegationRecord','contentConsentAt','contentFreezeAt'].includes(method))throw Error('Mutable head must not reauthorize history');
  });
  assert.equal((await run(s,c,m)).historicalImportProven,true);
  await assert.rejects(workflow.inspectArtistRecoveredMultipleConsentHydrationCurrent(s.provider,s.deployment,s.caller,s.input,{blockTag:12,gasLimit:10000000n}),/fresh/);
});

test('copied mined envelopes resist provider mutation and reject reorg or same-block attribution',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,'indexed');
  s.state.transactionHook=()=>{s.state.receipt.logs[0].data='0x';};assert.equal((await run(s,c,m)).historicalImportProven,true);
  s.state.transactionHook=null;install(s,c);s.state.blockOverride=tag=>tag===12?{number:12,timestamp:112,hash:H('reorg')}:undefined;
  await assert.rejects(run(s,c,{options:{execution:'direct'}}),/block|canonical/i);
  s.state.blockOverride=null;s.state.tx.blockNumber=10;s.state.tx.blockHash=H('block10');s.state.receipt.blockNumber=10;s.state.receipt.blockHash=H('block10');
  for(const log of s.state.receipt.logs){log.blockNumber=10;log.blockHash=H('block10');}
  await assert.rejects(run(s,c,{options:{execution:'direct'}}),/follow|later/);
});
