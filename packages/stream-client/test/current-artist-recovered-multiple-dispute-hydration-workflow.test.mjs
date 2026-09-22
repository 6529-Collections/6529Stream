// Compiler-encoded provider consistency mocks; no native/signature/Safe acceptance claim.
import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroHash } from 'ethers';
import { setup,capture,install,run,renumber,rh,workflow,abi,preparedAbi,safeABI,A,H } from './current-artist-recovered-multiple-dispute-hydration-workflow-fixture.mjs';
const histories=s=>s.attribution.map(row=>row.history);
const signed=s=>histories(s).flatMap(b=>b.disputes).find(row=>row.record.governanceActionId===ZeroHash);
const later=(s,c,indices=[2,4])=>s.state.hooks.push(({method,host,tag})=>tag===12&&method==='ownerStateSnapshotV2'&&indices.some(i=>host===s.destination.owners[i])?[{...c.after[s.destination.owners.indexOf(host)],revision:c.after[s.destination.owners.indexOf(host)].revision+1n,stateRoot:H(`later ${host}`)}]:undefined);

for(const royalties of [false,true])test(`complete dispute capture uses original ${royalties?'WithConsents':'two-argument'} route and full owner scope`,async()=>{
  const s=setup({royalties}),c=await capture(s);
  assert.equal(c.registrySimulated,false);assert.equal(c.prepared.call.value,0n);
  assert.equal(abi.parseTransaction({data:c.prepared.call.data}).name,royalties?'hydrateRecoveredArtistAuthorityWithConsents':'hydrateRecoveredArtistAuthority');
  assert.ok(c.certificate.admission.artists.length>1||c.certificate.admission.collections.length>1);
  assert.equal(c.certificate.admission.before_[2].revision,1n+BigInt(c.certificate.admission.artists.length+c.certificate.admission.collections.length));
  for(let i=0;i<7;i++){
    const {header,payload}=rh.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(c.certificate.data[i].typedState,i);
    assert.equal(header.requiredFeatures&16785408n,16785408n);
    const state=rh.decodeArtistRecoveredMultipleDisputeHydrationState(payload.semanticState,i,payload.provenance);
    assert.deepEqual(state.artists,c.certificate.admission.artists);assert.deepEqual(state.collections,c.certificate.admission.collections);
  }
});

test('dispute simulation calls the original Registry from the exact zero-value caller',async()=>{
  const s=setup(),c=await capture(s),r=await workflow.simulateArtistRecoveredMultipleDisputeHydration(s.provider,c,{blockTag:10,gasLimit:10000000n});
  assert.equal(r.registrySimulated,true);assert.equal(r.futureExecutionGuaranteed,false);
  const observed=s.state.calls.findLast(v=>v.method.startsWith('hydrateRecovered'));
  assert.equal(observed.from,s.caller);assert.equal(observed.value,0n);assert.equal(observed.tag,10);
});

test('current dispute inspection recaptures original eligibility before Registry simulation',async()=>{
  const s=setup();await capture(s);
  const before=s.state.calls.filter(v=>v.method==='prepare').length;
  const inspect=()=>workflow.inspectArtistRecoveredMultipleDisputeHydrationCurrent(s.provider,s.deployment,s.caller,s.input,{blockTag:10,gasLimit:10000000n});
  assert.equal((await inspect()).registrySimulated,true);
  assert.ok(s.state.calls.filter(v=>v.method==='prepare').length>before);
});

test('zero-op24 source still authenticates every original Archive catalogue and independent cutoff',async()=>{
  const s=setup({attestations:false}),c=await capture(s);
  assert.equal(c.certificate.admission.provenance.journals[4].some(j=>j.receipt.operation===24n),false);
  for(const origin of c.certificate.admission.provenance.origins)assert.ok(s.state.calls.some(v=>v.method==='storedPayloadCount'&&v.host===origin.archive));
  for(const row of s.archiveRows)assert.ok(s.state.calls.some(v=>v.method==='artistEvidenceBytesV2'&&v.args[0]===row.evidenceId));
  const operations=s.clocks.operations.map(r=>r.operation);assert.ok(operations.includes(44n));
});

test('repeated dispute capture retains both original eras and successor withdrawal proofs',async()=>{
  const s=setup({repeated:true}),c=await capture(s),p=c.certificate.admission.provenance;
  assert.equal(p.eras.length,2);assert.equal(p.origins.length,2);
  assert.notEqual(p.eras[1].priorImportCommitment,ZeroHash);
  assert.equal(c.prepared.request.expectedSourceImportCommitment,p.eras[1].priorImportCommitment);
  for(const b of histories(s)){
    const opening=b.disputes.find(r=>r.record.terms.disputeAction===1n),counter=b.disputes.find(r=>r.record.terms.disputeAction===3n),withdrawal=b.disputes.find(r=>r.record.terms.disputeAction===2n);
    assert.ok(opening&&counter&&withdrawal);
    assert.equal(opening.point.environmentHash,p.eras[0].originHash);assert.equal(counter.point.environmentHash,p.eras[0].originHash);
    assert.equal(withdrawal.point.environmentHash,p.eras[1].originHash);assert.equal(withdrawal.record.disputeRecordHash,opening.record.recordHash);
    assert.equal(opening.withdrawal.recordHash,withdrawal.record.recordHash);
  }
  for(let i=0;i<7;i++){
    const payload=c.owners[i].payload;assert.equal(payload.provenance.eras.length,2);
    const {header}=rh.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(c.certificate.data[i].typedState,i);assert.equal(header.requiredFeatures&16n,16n);
    assert.ok(s.state.calls.some(v=>v.method==='recoveredHydrationImportedPrefix'&&v.host===s.source.owners[i]));
  }
  for(let era=0;era<2;era++){
    assert.deepEqual(s.clocks.catalogues[era].upper,p.eras[era].checkpoints.map(cp=>cp.ownerState.revision));
    assert.deepEqual(s.clocks.catalogues[era].lower,p.eras[era].lowerRevisions);
    for(const row of s.archiveRows.filter(r=>r.originHash===p.eras[era].originHash))assert.ok(s.state.calls.some(v=>v.method==='artistEvidenceBytesV2'&&v.host===p.origins[era].archive&&v.args[0]===row.evidenceId));
  }
  assert.equal(c.registrySimulated,false);
});

test('repeated dispute capture refuses an inconsistent prior import cutover revision',async()=>{
  const s=setup({repeated:true}),p=s.payloads[2].provenance,last=p.eras.at(-1),old=new Set(p.eras.slice(0,-1).map(e=>e.originHash));
  const prefix={origins:p.origins.slice(0,-1),eras:p.eras.slice(0,-1),journal:p.journal.filter(j=>old.has(j.position.point.environmentHash)),aliases:p.aliases.filter(a=>old.has(a.originHash))};
  s.state.hooks.push(({method,host})=>method==='recoveredHydrationImportedPrefix'&&host===s.source.owners[2]?[prefix,last.priorImportCommitment,last.lowerRevision+1n]:undefined);
  await assert.rejects(capture(s),/Source imported commitment or local revision differs/);
  assert.equal(s.state.calls.some(v=>v.method.startsWith('hydrateRecovered')),false);
});

test('signed history retains complete original record bodies and Identity signature bytes',async()=>{
  const s=setup(),c=await capture(s),records=histories(s).flatMap(b=>b.disputes);
  assert.ok(records.some(r=>r.record.terms.disputeAction===1n));
  assert.ok(records.some(r=>r.record.terms.disputeAction===2n));
  assert.ok(records.some(r=>r.record.terms.disputeAction===3n));
  for(const row of records)assert.ok(s.state.calls.some(v=>v.method==='attributionDisputeRecord'&&v.args[0]===row.record.recordHash));
  for(const identity of s.identities)for(const row of identity.signatures)assert.ok(s.state.calls.some(v=>v.method==='signatureBundle'&&v.args[0]===row.recordHash));
  assert.equal(c.owners[2].payload.nonces.length,s.nonces.length);
});

test('non-anchor dispute records cannot be substituted by the same record hash',async()=>{
  const s=setup(),b=histories(s).at(-1),row=b.disputes[0];assert.ok(row);
  s.state.hooks.push(({method,host,args})=>host===s.source.owners[4]&&method==='attributionDisputeRecord'&&args[0]===row.record.recordHash?[{...row.record,signer:A(999)}]:undefined);
  await assert.rejects(capture(s),/complete signed or governed dispute record/);
});

test('source signature and document readback uses retained bytes without current signer approval',async()=>{
  const s=setup(),signature=s.identities.flatMap(b=>b.signatures)[0],document=s.identities.flatMap(b=>b.documents)[0];assert.ok(signature&&document);
  s.state.hooks.push(({method,host,args})=>host===s.source.owners[2]&&method==='signatureBundle'&&args[0]===signature.recordHash?['0x123456']:undefined);
  await assert.rejects(capture(s),/retained signature bytes/);s.state.hooks.length=0;
  s.state.hooks.push(({method,host,args})=>host===s.source.owners[2]&&method==='identityDocumentBytes'&&args[0]===document.documentHash?['0x123456']:undefined);
  await assert.rejects(capture(s),/retained Identity document/);
});

test('complete indexed nonce words and original cross-family grant usage remain source facts',async()=>{
  const s=setup({delegated:true}),grant=s.identities.flatMap(b=>b.delegations)[0];assert.ok(grant);
  s.state.hooks.push(({method,host,args})=>method==='delegationRecord'&&host===s.source.owners[2]&&args[0]===grant.recordHash?[{...grant.record,uses:grant.record.uses+1n}]:undefined);
  await assert.rejects(capture(s),/grant version, usage or revocation/);s.state.hooks.length=0;
  const n=s.payloads[2].nonces[0];assert.ok(n);
  s.state.hooks.push(({method,host})=>method==='authorityNonceWordAt'&&host===s.source.owners[2]?[n.words[0].prefix,n.words[0].words.map(()=>0n),n.words[0].exhausted]:undefined);
  await assert.rejects(capture(s),/nonce prefix or exhaustion/);
});

test('pending repudiation counts aggregate shared Artist cohorts across collections',async()=>{
  const s=setup({history:'pending'}),all=histories(s),pending=all.flatMap(b=>b.repudiations).filter(r=>r.terminal.phase===1n);assert.ok(pending.length>1);
  await capture(s);const counts=s.state.calls.filter(v=>v.method==='repudiationCount');assert.ok(counts.length>0);
  s.state.hooks.push(({method,host})=>method==='repudiationCount'&&host===s.source.owners[4]?[0n]:undefined);
  await assert.rejects(capture(s),/aggregate pending authority-head count/);
});

test('veto history reads the original terminal and both immutable Identity effects',async()=>{
  const s=setup({history:'veto'});await capture(s);
  const vetoes=histories(s).flatMap(b=>b.repudiations).filter(r=>r.terminal.phase===2n);assert.ok(vetoes.length>0);
  const native=s.certificate.admission.provenance.journals[2].filter(j=>j.receipt.operation===48n);assert.equal(native.length,2*vetoes.length);
  for(const identity of s.identities){for(const row of identity.contests)assert.ok(s.state.calls.some(v=>v.method==='identityContestRecord'&&v.args[0]===row.record.recordHash));for(const row of identity.causes)assert.ok(s.state.calls.some(v=>v.method==='identityContestCause'&&v.args[0]===row.cause.causeHash));}
});

test('cancellation retains its terminal body without inventing a signed nonce or native row',async()=>{
  const s=setup({history:'cancel'}),c=await capture(s),rows=histories(s).flatMap(b=>b.repudiations).filter(r=>r.terminal.phase===3n);assert.ok(rows.length>0);
  for(const row of rows){assert.equal(row.terminal.actor,row.record.signer);assert.equal(row.terminal.reasonHash,ZeroHash);assert.ok(s.state.calls.some(v=>v.method==='attributionRepudiationTerminal'&&v.args[0]===row.record.recordHash));}
  assert.equal(c.certificate.admission.provenance.journals[2].some(j=>j.receipt.operation===49n),false);
  assert.ok(s.clocks.operations.some(row=>row.operation===49n));
});

test('reopened dispute episodes retain previous records and immutable closed outcomes',async()=>{
  const s=setup({history:'reopen'});await capture(s);
  const history=histories(s).find(b=>b.disputes.filter(r=>r.record.terms.disputeAction===1n).length>1);assert.ok(history);
  const openings=history.disputes.filter(r=>r.record.terms.disputeAction===1n);
  assert.equal(openings.at(-1).record.previousRecordHash,openings.at(-2).record.recordHash);
  assert.ok(openings.slice(0,-1).some(row=>row.withdrawal.recordHash!==ZeroHash)||history.resolutions.length>0);
  for(const row of openings)assert.ok(s.state.calls.some(v=>v.method==='attributionDisputeRecord'&&v.args[0]===row.record.recordHash));
});

test('automatic phase5 invalidation retains its original cause without a fabricated terminal operation',async()=>{
  const s=setup({history:'reopen'}),row=histories(s).flatMap(b=>b.repudiations).find(r=>r.terminal.phase===5n);assert.ok(row);
  assert.equal(row.terminal.actor,A(0));assert.equal(row.terminalPoint.environmentHash,ZeroHash);assert.equal(row.terminalPoint.ownerRevision,0n);
  assert.ok(histories(s).flatMap(b=>b.disputes).some(d=>d.record.recordHash===row.terminal.reasonHash&&d.record.recordedAt===row.terminal.recordedAt));
  assert.equal(s.clocks.operations.some(r=>[48n,49n,50n].includes(r.operation)),false);
  const c=await capture(s),m=install(s,c);later(s,c,[4]);
  s.state.hooks.push(({method,host,tag,args})=>tag===12&&host===s.destination.owners[4]&&method==='attributionRepudiationTerminal'&&args[0]===row.record.recordHash?[{...row.terminal,reasonHash:H('changed invalidation cause')}]:undefined);
  await assert.rejects(run(s,c,m),/final repudiation terminal/);
});

test('op24 and dispute occurrences share complete provenance without filtered indices',async()=>{
  const s=setup({attestations:true}),c=await capture(s),journal=c.owners[4].payload.provenance.journal;
  assert.ok(journal.some(j=>j.receipt.operation===24n));assert.ok(journal.some(j=>[44n,45n,47n,61n].includes(j.receipt.operation)));
  for(const entry of journal.filter(j=>j.receipt.operation===24n))assert.ok(s.state.calls.some(v=>v.method==='attestationRecord'&&v.args[0]===entry.receipt.recordHash));
  for(const row of s.credentialRecords.values())assert.ok(s.state.calls.some(v=>v.method==='c2paCredentialRecord'&&v.args[0]===row.recordHash));
});

test('executed repudiation correction keeps every original generation and cause body',async()=>{
  const s=setup({history:'executed'});await capture(s);
  assert.ok(histories(s).flatMap(b=>b.repudiations).some(r=>r.terminal.phase===4n));
  assert.ok(s.bindings.some(b=>b.corrections.some(c=>c.approval.cause===3n)));
  for(const b of s.bindings)for(const row of b.bindings.rows)assert.ok(s.state.calls.some(v=>v.method==='bindingAt'&&v.args[0]===b.bindings.collectionId&&v.args[1]===row.item.generation));
});

test('arbiter-revoked pending generation does not invent an acceptance receipt',async()=>{
  const s=setup({history:'pending-revoked'});await capture(s);
  const index=s.bindings.findIndex(b=>b.bindings.rows.some(r=>!r.item.accepted&&r.terminal.kind===0n));assert.ok(index>=0);
  const row=s.bindings[index].bindings.rows.find(r=>!r.item.accepted&&r.terminal.kind===0n);
  assert.equal(s.acceptances[index].rows.some(r=>r.bindingHash===row.item.bindingHash),false);
  assert.equal(s.state.calls.some(v=>v.method==='acceptanceRecord'&&v.args[0]===row.item.bindingHash),false);
});

test('complete dispute source rejects lost STOP carriers and future original metadata',async()=>{
  const s=setup(),row=s.archiveRows[0];s.state.codes.set(row.pointer,`0x01${row.raw.slice(2)}`);
  await assert.rejects(capture(s),/STOP/);s.state.codes.set(row.pointer,`0x00${row.raw.slice(2)}`);
  s.state.hooks.push(({method,args})=>method==='artistEvidenceMetadataV2'&&args[0]===row.evidenceId?[row.hash,row.pointer,BigInt((row.raw.length-2)/2),11n]:undefined);
  await assert.rejects(capture(s),/future block/);
});

test('complete catalogue includes unrelated rows and every non-anchor history lane',async()=>{
  const s=setup(),q=s.certificate.admission.collections.at(-1);
  s.state.hooks.push(({method,args})=>method==='importedLaneVerified'&&args[0]===2n&&BigInt(args[1])===q.collectionId?[false,H('missing'),BigInt(q.records.length)]:undefined);
  await assert.rejects(capture(s),/operation56 lane/);s.state.hooks.length=0;
  s.state.sourceCatalogs.get(s.source.archive).push({pointer:A(999),payloadType:H('unrelated'),payloadHash:H('bytes')});
  await assert.rejects(capture(s),/catalogue count/);
});

test('dispute Prepared bytes must be canonical before any original Registry simulation',async()=>{
  const s=setup();s.state.hooks.push(({method,fragment})=>method==='prepare'?`${preparedAbi.encodeFunctionResult(fragment,[s.certificate])}${'00'.repeat(32)}`:undefined);
  await assert.rejects(capture(s),/Noncanonical/);assert.equal(s.state.calls.some(v=>v.method.startsWith('hydrateRecovered')),false);
});

test('dispute request inputs are owned before the first asynchronous read',async()=>{
  const s=setup(),network=s.provider.getNetwork;let once=true;
  s.provider.getNetwork=async()=>{if(once){once=false;s.input.request.expectedSourceImportCommitment=H('mutated');}return network();};
  const c=await capture(s);assert.notEqual(c.prepared.request.expectedSourceImportCommitment,s.input.request.expectedSourceImportCommitment);
});

for(const mode of ['direct','legacy','indexed'])test(`complete dispute ${mode} receipt proves one aggregate import with immutable original evidence`,async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,mode),r=mode==='direct'?await workflow.inspectArtistRecoveredMultipleDisputeHydrationHistory(s.provider,c,H('tx'),m.options):await run(s,c,m);
  assert.equal(r.historicalImportProven,true);assert.equal(r.originalArchiveClockReadbackVerifiedAtReceipt,true);
  assert.equal(r.retainedDisputeHistoryReadBack,true);assert.equal(r.retainedIdentityEvidenceReadBack,true);
  assert.equal(r.currentAuthorityClaimed,false);assert.equal(r.privateSemanticInstallationIndependentlyVerified,false);assert.equal(r.ownerSignaturesIndependentlyVerified,false);
  r.ownerSnapshots.forEach((row,i)=>assert.equal(row.revision,c.certificate.admission.before_[i].revision+1n));
  assert.equal(r.events.filter(v=>v.event==='RecoveredArtistAuthorityHydrated').length,1);
  assert.equal(r.events.filter(v=>v.event==='ArtistArchiveEvidenceAppendedV2').length,c.descriptor.pageHashes.length+1);
});

test('receipt refuses a later same-block original catalogue append even without op24',async()=>{
  const s=setup({attestations:false}),c=await capture(s),m=install(s,c);
  s.state.hooks.push(({method,host,tag})=>tag===12&&method==='storedPayloadCount'&&host===s.source.archive?[BigInt(s.archiveRows.length+1)]:undefined);
  await assert.rejects(run(s,c,m),/catalogue count/);
});

test('later mutable heads and pending terminals do not reauthorize imported history',async()=>{
  const s=setup({history:'pending'}),c=await capture(s),m=install(s,c);later(s,c);
  const pending=new Set(histories(s).flatMap(b=>b.repudiations).filter(r=>r.terminal.phase===1n).map(r=>r.record.recordHash));
  const absent=new Set(histories(s).flatMap(b=>b.disputes).filter(r=>r.withdrawal.recordHash===ZeroHash).map(r=>r.record.recordHash));
  s.state.hooks.push(({method,host,tag,args})=>{if(tag!==12||host!==s.destination.owners[4])return;if(['attributionState','attributionDispute','rawPendingRepudiation','repudiationCount'].includes(method)||(method==='attributionRepudiationTerminal'&&pending.has(args[0]))||(method==='attributionDisputeWithdrawal'&&absent.has(args[0])))throw Error('Mutable current head must not reauthorize saved history');});
  assert.equal((await run(s,c,m)).historicalImportProven,true);
});

test('nonzero withdrawal outcomes remain immutable after later destination activity',async()=>{
  const s=setup(),row=histories(s).flatMap(b=>b.disputes).find(r=>r.withdrawal.recordHash!==ZeroHash);assert.ok(row);
  const c=await capture(s),m=install(s,c);later(s,c);
  s.state.hooks.push(({method,host,tag,args})=>tag===12&&host===s.destination.owners[4]&&method==='attributionDisputeWithdrawal'&&args[0]===row.record.recordHash?[{...row.withdrawal,counterStatementRecordHash:H('changed')}]:undefined);
  await assert.rejects(run(s,c,m),/withdrawal outcome/);
});

test('final terminal and immutable Identity Cause remain checked after later activity',async()=>{
  const s=setup({history:'veto'}),row=histories(s).flatMap(b=>b.repudiations).find(r=>r.terminal.phase===2n),cause=s.identities.flatMap(b=>b.causes)[0];assert.ok(row&&cause);
  const c=await capture(s),m=install(s,c);later(s,c);
  s.state.hooks.push(({method,host,tag,args})=>tag===12&&host===s.destination.owners[4]&&method==='attributionRepudiationTerminal'&&args[0]===row.record.recordHash?[{...row.terminal,reasonHash:H('changed')}]:undefined);
  await assert.rejects(run(s,c,m),/final repudiation terminal/);
  s.state.hooks.length=0;later(s,c);
  s.state.hooks.push(({method,host,tag,args})=>tag===12&&host===s.destination.owners[2]&&method==='identityContestCause'&&args[0]===cause.cause.causeHash?[{...cause.cause,facts:{...cause.cause.facts,priorStatus:99n}}]:undefined);
  await assert.rejects(run(s,c,m),/retained Identity Cause/);
});

test('original signed record and signature bytes stay immutable after Identity advances',async()=>{
  const s=setup(),row=signed(s);assert.ok(row);const c=await capture(s),m=install(s,c);later(s,c);
  s.state.hooks.push(({method,host,tag,args})=>tag===12&&host===s.destination.owners[2]&&method==='signatureBundle'&&args[0]===row.record.recordHash?['0xdead']:undefined);
  await assert.rejects(run(s,c,m),/retained signature bytes/);
});

test('later Identity activity may increase retained active grant usage',async()=>{
  const s=setup({delegated:true}),grant=s.identities.flatMap(b=>b.delegations).find(row=>!row.record.revoked);assert.ok(grant);
  const c=await capture(s),m=install(s,c);later(s,c,[2]);
  assert.ok(grant.record.grant.maxUses===0n||grant.record.uses<grant.record.grant.maxUses);
  s.state.hooks.push(({method,host,tag,args})=>tag===12&&host===s.destination.owners[2]&&method==='delegationRecord'&&args[0]===grant.recordHash?[{...grant.record,uses:grant.record.uses+1n}]:undefined);
  assert.equal((await run(s,c,m)).historicalImportProven,true);
});

test('later Identity activity cannot change retained grant terms grantor or nonce',async()=>{
  const s=setup({delegated:true}),grant=s.identities.flatMap(b=>b.delegations).find(row=>!row.record.revoked);assert.ok(grant);
  const c=await capture(s),m=install(s,c);later(s,c,[2]);
  s.state.hooks.push(({method,host,tag,args})=>tag===12&&host===s.destination.owners[2]&&method==='delegationRecord'&&args[0]===grant.recordHash?[{...grant.record,grant:{...grant.record.grant,constraintsHash:H('changed immutable grant')}}]:undefined);
  await assert.rejects(run(s,c,m),/immutable grant terms, grantor or nonce/);
});

test('Safe complete dispute envelope preserves zero value nonce and signed gas fields',async()=>{
  const s=setup(),c=await capture(s);let m=install(s,c);s.state.tx.value=1n;await assert.rejects(run(s,c,m),/value/);
  m=install(s,c,'legacy');s.state.safeEndingNonce=9n;await assert.rejects(run(s,c,m),/nonce/);s.state.safeEndingNonce=5n;
  m=install(s,c,'indexed');const v=Array.from(safeABI.decodeFunctionData('execTransaction',s.state.tx.data));v[4]+=1n;s.state.tx.data=safeABI.encodeFunctionData('execTransaction',v);await assert.rejects(run(s,c,m),/hash/);
});

test('dispute application evidence precedes Safe success while later guard logs are allowed',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,'indexed');
  m.logs.push({address:A(999),topics:[H('guard')],data:'0x',index:m.logs.length,blockNumber:12,blockHash:H('block12'),transactionHash:H('tx'),removed:false});
  assert.equal((await run(s,c,m)).historicalImportProven,true);
  const success=m.logs.find(v=>v.address===s.caller);m.logs.splice(m.logs.indexOf(success),1);m.logs.unshift(success);renumber(m.logs);await assert.rejects(run(s,c,m),/precedes complete/);
});

test('dispute mined evidence is detached before later reads and source workers remain pinned',async()=>{
  const s=setup(),c=await capture(s),m=install(s,c,'indexed');s.state.transactionHook=()=>{s.state.receipt.logs[0].data='0x';};assert.equal((await run(s,c,m)).historicalImportProven,true);
  s.state.transactionHook=null;const next=install(s,c);s.state.hooks.push(({method,host,tag})=>method==='getCode'&&host===s.deployment.preparationLibrary.address&&tag===12?'0x':undefined);await assert.rejects(run(s,c,next),/runtime/i);
});

test('dispute refusal distinguishes changed original success revert and transport failure',async()=>{
  const s=setup(),c=await capture(s),actual=H('later actual commitment');s.state.hooks.push(({method})=>method.startsWith('hydrateRecovered')?[actual]:undefined);
  let r=await workflow.observeArtistRecoveredMultipleDisputeHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});assert.equal(r.status,'succeeded');assert.equal(r.returnedCommitment,actual);assert.equal(r.capturePredictionChecked,false);
  s.state.hooks.length=0;s.state.hooks.push(({method})=>{if(method.startsWith('hydrateRecovered'))throw Object.assign(Error('mock refusal'),{code:'CALL_EXCEPTION',data:'0x12345678'});});
  r=await workflow.observeArtistRecoveredMultipleDisputeHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});assert.equal(r.status,'reverted');
  s.state.hooks.length=0;s.state.hooks.push(({method})=>{if(method.startsWith('hydrateRecovered'))throw Object.assign(Error('https://secret.invalid'),{code:'NETWORK_ERROR',request:{authorization:'secret'}});});
  r=await workflow.observeArtistRecoveredMultipleDisputeHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});assert.equal(r.status,'rpc-failed');assert.equal(JSON.stringify(r,(_,v)=>typeof v==='bigint'?String(v):v).includes('secret'),false);
});

test('dispute refusal rejects cloned capture earlier block changed header and replaced runtime',async()=>{
  const s=setup(),c=await capture(s),observe=(value=c,tag=11)=>workflow.observeArtistRecoveredMultipleDisputeHydrationRefusal(s.provider,value,{blockTag:tag,gasLimit:10000000n});
  await assert.rejects(observe(structuredClone(c)),/workflow instance/);await assert.rejects(observe(c,9),/precedes/);
  s.state.blockOverride=tag=>({number:tag,timestamp:100+tag,hash:tag===10?H('reorg'):H(`block${tag}`)});await assert.rejects(observe(),/changed|Reorg|reorg/);s.state.blockOverride=null;
  s.state.hooks.push(({method,host,tag})=>method==='getCode'&&host===s.deployment.source.registry.address&&tag===11?'0x':undefined);await assert.rejects(observe(),/runtime/i);
});
