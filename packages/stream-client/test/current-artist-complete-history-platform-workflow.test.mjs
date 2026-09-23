// Source-shaped compiler-encoded consistency mocks, not native Platform,
// governance, signature, document-admission or Safe execution evidence.
// This file leaves the original 26 provider test names and bodies unchanged.
import test from 'node:test';
import assert from 'node:assert/strict';
import { AbiCoder, ZeroHash, id, keccak256 } from 'ethers';
import { setup,capture,install,run,replacePrepared,restorePrepared,rh,H } from './current-artist-complete-history-hydration-workflow-fixture.mjs';
import { T,child,zero } from './current-artist-complete-history-hydration-semantic-fixture.mjs';
import { compiledInterfaces } from './current-artist-complete-history-source-fixture.mjs';
const coder=AbiCoder.defaultAbiCoder(),clone=structuredClone,Z=ZeroHash;
const original=compiledInterfaces.StreamArtistAttributionLifecycle;
const stateType=original.getFunction('platformWorksState').outputs[0];
const contestType=original.getFunction('platformWorksContestRecord').outputs[0];
const hash=(types,values)=>keccak256(coder.encode(types,values));
const sourceRead=(s,method,key,tag=10,owner=s.source.owners[4])=>s.state.calls.some(r=>r.host===owner&&r.method===method&&r.args[0]===key&&r.tag===tag);
function later(s,c) {
 s.state.hooks.push(({method,host,tag})=>tag===12&&method==='ownerStateSnapshotV2'&&host===s.destination.owners[4]
  ?[{...c.after[4],revision:c.after[4].revision+1n,stateRoot:H('later Platform owner4 root')}]:undefined);
}
function outerRehashed(s,changed) {
 assert.notEqual(changed.request.expectedSemanticInventory,s.material.request.expectedSemanticInventory);
 for(let i=0;i<7;i++)assert.notEqual(changed.certificate.data[i].typedState,s.material.certificate.data[i].typedState);
 assert.deepEqual(s.material.platforms,s.platforms); // Provider source was not rewritten.
}
function swapOccurrence(f,from,to) {
 const native=f.provenance.journals[4].find(j=>j.receipt.operation===from),index=f.operations.findIndex(o=>o.evidence.evidenceId===f.archiveRows.find(r=>rh.decodeArtistCompleteHistoryHydrationArchiveEnvelope(r.raw).value===native.receipt.recordHash).evidenceId);
 native.receipt.operation=to;
 const row=f.archiveRows[index],e={...rh.decodeArtistCompleteHistoryHydrationArchiveEnvelope(row.raw),operation:to};
 const raw=coder.encode(T.envelope.components,T.envelope.components.map(t=>e[t.name]));
 const evidenceId=hash(['bytes32','uint256','address','address','uint16','address','bytes32'],[id('6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1'),f.origin.chainId,f.origin.registry,f.origin.coordinator,to,e.actor,e.value]);
 Object.assign(row,{raw,hash:keccak256(raw),evidenceId});
 f.operations[index].operation=to;Object.assign(f.operations[index].evidence,{payloadHash:keccak256(raw),evidenceId});
 f.codes.set(row.pointer,'0x00'+raw.slice(2)); // This clone's carriers only; original provider code is unchanged.
}

test('Platform source capture reads original contest11 and correction53 with distinct native and Archive preimages',async()=>{
 const s=setup({platform:true}),p=s.platforms[0],o=s.origin,c=await capture(s);
 assert.deepEqual(s.provenance.journals[4].map(j=>j.receipt.operation),[8n,9n,11n,11n,53n]);
 assert.deepEqual(s.operations.map(r=>r.operation),[8n,9n,11n,11n,53n]);
 assert.equal(new Set(s.platformStages.map(r=>r.record)).size,5);
 assert.deepEqual(s.platformStages.map(r=>r.point.ownerRevision),[1n,2n,3n,4n,5n]);
 assert.deepEqual(p.contests.map(r=>r.record.state),[1n,3n]);
 const d=p.state.declaration,claim=p.claims[0].record,correction=p.state.correction;
 assert.equal(d.recordHash,hash(['bytes32','uint256','address','address','uint256','bytes32','uint64'],[id('6529STREAM_PLATFORM_WORKS_DECLARATION_V1'),o.chainId,o.registry,o.core,p.collectionId,d.statementHash,d.declaredAt]));
 assert.equal(claim.recordHash,hash(['bytes32','uint256','address','address','uint256','address','bytes32','bytes32','uint64'],[id('6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1'),o.chainId,o.registry,o.core,p.collectionId,claim.claimant,claim.evidenceHash,claim.reasonHash,claim.filedAt]));
 for(const row of p.contests){
  assert.equal(row.record.recordHash,hash(['bytes32','uint256','address',contestType],[id('6529STREAM_PLATFORM_WORKS_CONTEST_TRANSITION_V1'),o.chainId,o.owners[4],{...row.record,recordHash:Z}]));
  assert.ok(sourceRead(s,'platformWorksContestRecord',row.record.recordHash));
 }
 assert.equal(correction.recordHash,hash(['bytes32','uint256','address','address','uint256','bytes32','bytes32','bytes32','bytes32','bytes32','uint64'],[id('6529STREAM_PLATFORM_WORKS_CORRECTION_RECORD_V1'),o.chainId,o.registry,o.core,p.collectionId,correction.sustainedContestRecordHash,correction.claimRecordHash,correction.evidenceHash,correction.reasonHash,correction.approvalActionId,correction.approvedAt]));
 assert.equal(correction.sustainedContestRecordHash,p.contests[1].record.recordHash);
 assert.ok(sourceRead(s,'platformWorksState',p.collectionId));assert.equal(p.correctionPoint.ownerRevision,5n);
 let sequence=0n;
 for(let i=0;i<s.platformStages.length;i++){
  const stage=s.platformStages[i],row=s.archiveRows[i],e=rh.decodeArtistCompleteHistoryHydrationArchiveEnvelope(row.raw),before=e.before_[4],after=e.after_[4];
  assert.equal(e.operation,stage.operation);assert.equal(e.value,stage.record);assert.equal(row.hash,keccak256(row.raw));
  assert.equal(row.evidenceId,hash(['bytes32','uint256','address','address','uint16','address','bytes32'],[id('6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1'),o.chainId,o.registry,o.coordinator,e.operation,e.actor,e.value]));
  assert.equal(s.state.codes.get(row.pointer),'0x00'+row.raw.slice(2));
  assert.ok(s.state.calls.some(r=>r.host===o.archive&&r.method==='artistEvidenceBytesV2'&&r.args[0]===row.evidenceId&&r.tag===10));
  for(let owner=0;owner<7;owner++)if(!(e.operation===8n?[0,4,6]:[4]).includes(owner)){
   assert.deepEqual(e.before_[owner],zero(child(T.envelope,'before_').arrayChildren));assert.deepEqual(e.after_[owner],zero(child(T.envelope,'after_').arrayChildren));
  }
  const alias=s.provenance.aliases[4].find(r=>r.cell.commitment===e.value),primary=e.operation===11n?Z:e.value;
  assert.equal(alias.originalKey,rh.artistCompleteHistoryHydrationReplayKey(o,4,{surface:hash(['string','uint16'],['PLATFORM_WORKS',e.operation]),scope:stage.scope}));
  assert.equal(after.stateRoot,hash(['bytes32','uint256','address','address','address','address','bytes32','uint64','uint64','bytes32','bytes32','bytes32','bytes32','bytes32'],[id('6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2'),o.chainId,o.registry,o.coordinator,o.archive,o.owners[4],before.domainId,before.revision,after.revision,before.stateRoot,hash(['uint16','address','bytes32'],[e.operation,e.actor,e.value]),hash(['uint256',stateType],[p.collectionId,stage.after]),alias.originalKey,hash(['bytes32'],[primary])]));
  if(primary===Z)assert.equal(after.recordChainTip,before.recordChainTip);
  else {assert.equal(after.recordChainTip,hash(['bytes32','uint256','address','address','address','address','bytes32','uint64','uint64','bytes32','bytes32'],[id('6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2'),o.chainId,o.registry,o.coordinator,o.archive,o.owners[4],before.domainId,sequence,sequence+1n,before.recordChainTip,primary]));sequence++;}
 }
 assert.equal(c.registrySimulated,false);assert.equal(c.certificate.admission.artists.length,0);
});

for(const [from,to] of [[11n,53n],[53n,11n]])test(`Platform fully rehashed native operation ${from} cannot substitute ${to}`,async()=>{
 const s=setup({platform:true}),changed=replacePrepared(s,f=>swapOccurrence(f,from,to));outerRehashed(s,changed);
 await assert.rejects(capture(s),/Original Platform native occurrence mismatch/);
 restorePrepared(s);const c=await capture(s);assert.equal(c.certificate.admission.provenance.journals[4].find(j=>j.receipt.operation===from).receipt.operation,from);
 for(const row of s.platforms[0].contests)assert.ok(sourceRead(s,'platformWorksContestRecord',row.record.recordHash));
});

test('Platform fully rehashed contest body is checked against the independently retained source getter',async()=>{
 const s=setup({platform:true}),saved=clone(s.platforms[0].contests[0].record);
 const changed=replacePrepared(s,f=>{f.platforms[0].contests[0].record.reasonHash=H('substituted retained contest reason');});outerRehashed(s,changed);
 assert.equal(changed.platforms[0].contests[0].record.recordHash,saved.recordHash);
 await assert.rejects(capture(s),/Retained Platform contest differs/);
 assert.ok(sourceRead(s,'platformWorksContestRecord',saved.recordHash));assert.deepEqual(s.platforms[0].contests[0].record,saved);
 restorePrepared(s);assert.equal((await capture(s)).registrySimulated,false);
});

test('Platform fully rehashed correction body is checked against the original current state carrier',async()=>{
 const s=setup({platform:true}),saved=clone(s.platforms[0].state.correction);
 const changed=replacePrepared(s,f=>{f.platforms[0].state.correction.approvedAt+=1n;});outerRehashed(s,changed);
 assert.equal(changed.platforms[0].state.correction.recordHash,saved.recordHash);
 await assert.rejects(capture(s),/Original Platform current state differs/);
 assert.ok(sourceRead(s,'platformWorksState',s.platforms[0].collectionId));assert.deepEqual(s.platforms[0].state.correction,saved);
 restorePrepared(s);assert.equal((await capture(s)).registrySimulated,false);
});

test('Platform receipt reads both original families after later correction consumption',async()=>{
 const s=setup({platform:true}),c=await capture(s),mined=install(s,c,'indexed');later(s,c);
 const p=s.platforms[0];s.state.hooks.push(({method,host,tag})=>tag===12&&host===s.destination.owners[4]&&method==='platformWorksState'
  ?[{...p.state,correction:{...p.state.correction,correctiveGeneration:1n,accepted:true}}]:undefined);
 const r=await run(s,c,mined);
 assert.ok(sourceRead(s,'platformWorksState',p.collectionId,12,s.destination.owners[4]));
 for(const row of p.contests)assert.ok(sourceRead(s,'platformWorksContestRecord',row.record.recordHash,12,s.destination.owners[4]));
 assert.equal(r.historicalImportProven,true);assert.equal(r.originalArchiveClockReadbackVerifiedAtReceipt,true);
 assert.equal(r.originalCompositionIndependentlyVerified,false);assert.equal(r.privateSemanticInstallationIndependentlyVerified,false);
 assert.equal(r.ownerSignaturesIndependentlyVerified,false);assert.equal(r.safeImplementationIndependentlyVerified,false);
});

test('Platform later receipt cannot replace an immutable contest body and succeeds after restoring source readback',async()=>{
 const s=setup({platform:true}),c=await capture(s),mined=install(s,c);later(s,c);const record=s.platforms[0].contests[1].record;
 s.state.hooks.push(({method,host,tag,args})=>tag===12&&host===s.destination.owners[4]&&method==='platformWorksContestRecord'&&args[0]===record.recordHash?[{...record,adjudicatedArtist:s.caller}]:undefined);
 await assert.rejects(run(s,c,mined),/Retained Platform contest differs/);
 assert.ok(sourceRead(s,'platformWorksContestRecord',record.recordHash,12,s.destination.owners[4]));
 s.state.hooks.pop();assert.equal((await run(s,c,mined)).historicalImportProven,true);
});

test('Platform later receipt cannot replace an immutable correction approval and succeeds after restoring carrier',async()=>{
 const s=setup({platform:true}),c=await capture(s),mined=install(s,c);later(s,c);const p=s.platforms[0];
 s.state.hooks.push(({method,host,tag})=>tag===12&&host===s.destination.owners[4]&&method==='platformWorksState'?[{...p.state,correction:{...p.state.correction,approvedAt:p.state.correction.approvedAt+1n,correctiveGeneration:1n,accepted:true}}]:undefined);
 await assert.rejects(run(s,c,mined),/Retained immutable Platform correction differs/);
 assert.ok(sourceRead(s,'platformWorksState',p.collectionId,12,s.destination.owners[4]));
 s.state.hooks.pop();assert.equal((await run(s,c,mined)).historicalImportProven,true);
});
