// Compiler-shaped RPC/receipt consistency tests. Private composition, original
// signatures and actual Safe/native execution are mocked, never established here.
import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroHash } from 'ethers';
import { setup,capture,install,run,renumber,rh,workflow,abi,safeABI,A,H } from './current-artist-complete-history-hydration-workflow-fixture.mjs';
const later=(s,c,indices)=>s.state.hooks.push(({method,host,tag})=>tag===12&&method==='ownerStateSnapshotV2'&&indices.some(i=>host===s.destination.owners[i])?[{...c.after[s.destination.owners.indexOf(host)],revision:c.after[s.destination.owners.indexOf(host)].revision+1n,stateRoot:H(`later ${host}`)}]:undefined);

test('complete zero-Artist capture retains all seven identical common inventories',async()=>{
 const s=setup(),c=await capture(s);assert.equal(c.registrySimulated,false);assert.equal(c.prepared.call.value,0n);
 assert.equal(c.certificate.admission.artists.length,0);assert.equal(c.certificate.admission.collections[0].artistId,ZeroHash);
 assert.equal(abi.parseTransaction({data:c.prepared.call.data}).name,'hydrateRecoveredArtistAuthority');
 let aux;for(let i=0;i<7;i++){
  const {header,payload}=rh.decodeArtistCompleteHistoryHydrationOwnerPayload(c.certificate.data[i].typedState,i);
  assert.equal(header.requiredFeatures&33554432n,33554432n);
  const decoded=rh.decodeArtistCompleteHistoryHydrationAuxiliary(payload.semanticState,i,payload.provenance);
  assert.deepEqual(decoded.state.artists,[]);assert.deepEqual(decoded.state.collections,c.certificate.admission.collections);
  if(aux)assert.equal(decoded.auxiliary,aux);aux=decoded.auxiliary;
  if([1,2,5].includes(i))assert.equal(decoded.state.rows.length,0);
 }
 assert.equal(s.state.calls.some(v=>v.method==='identityDocumentBytes'||v.method==='signatureBundle'),false);
});

for(const royalties of [false,true])test(`complete historical Artist capture uses ${royalties?'WithConsents':'two-argument'} route under a different current Artist`,async()=>{
 const s=setup({historical:true,royalties}),c=await capture(s),q=c.certificate.admission.collections[0],e=s.contents[0].original.economics[0];
 assert.notEqual(e.item.association.artistId,q.artistId);assert.equal(s.bindings[0].bindings.current.accepted,false);
 assert.equal(abi.parseTransaction({data:c.prepared.call.data}).name,royalties?'hydrateRecoveredArtistAuthorityWithConsents':'hydrateRecoveredArtistAuthority');
 const read=s.state.calls.find(v=>v.method==='economicsRecordForBinding');assert.equal(read.args[1],e.item.association.artistId);
 assert.equal(c.certificate.admission.artists.length,2);assert.equal(c.certificate.admission.provenance.journals[6][0].receipt.artistId,e.item.association.artistId);
 if(royalties)assert.equal(s.state.calls.find(v=>v.method==='royaltyFreezeRecord').args[1],e.item.association.artistId);
});

test('complete historical economics readback cannot substitute the current Artist',async()=>{
 const s=setup({historical:true,royalties:false}),e=s.contents[0].original.economics[0];
 s.state.hooks.push(({method,host})=>method==='economicsRecordAssociation'&&host===s.source.owners[6]?[{...e.item.association,artistId:s.collections[0].artistId}]:undefined);
 await assert.rejects(capture(s),/economics record association/);
});

test('complete historical royalty readback binds its original Artist receipt',async()=>{
 const s=setup({historical:true}),r=s.contents[0].royalties[0];
 s.state.hooks.push(({method,host,args})=>{if(method==='royaltyFreezeRecord'&&host===s.source.owners[6]){assert.equal(args[1],r.item.artistId);return[{...r.item,artistId:s.collections[0].artistId}];}});
 await assert.rejects(capture(s),/royalty record/);
});

test('complete source checks every Archive catalogue and all seven cutoff clocks without op24',async()=>{
 const s=setup({historical:true,royalties:false}),c=await capture(s);assert.equal(c.owners[4].payload.provenance.journal.some(r=>r.receipt.operation===24n),false);
 assert.ok(s.clocks.operations.some(r=>r.operation===1n));assert.ok(s.clocks.operations.some(r=>r.operation===2n));
 for(const row of s.archiveRows)assert.ok(s.state.calls.some(v=>v.method==='artistEvidenceBytesV2'&&v.args[0]===row.evidenceId));
 assert.deepEqual(s.clocks.catalogues[0].upper,c.certificate.admission.provenance.eras[0].checkpoints.map(cp=>cp.ownerState.revision));
});

test('complete original Archive STOP runtime and metadata are independently checked',async()=>{
 const s=setup(),row=s.archiveRows[0];s.state.codes.set(row.pointer,'0x01'+row.raw.slice(2));
 await assert.rejects(capture(s),/STOP|SSTORE2|pointer|runtime/i);s.state.codes.set(row.pointer,'0x00'+row.raw.slice(2));
 s.state.hooks.push(({method,host})=>method==='artistEvidenceMetadataV2'&&host===s.source.archive?[row.hash,row.pointer,BigInt((row.raw.length-2)/2),11n]:undefined);
 await assert.rejects(capture(s),/future|metadata/i);
});

test('complete Platform allegations retain immutable bodies even with no Artist or binding',async()=>{
 const s=setup(),row=s.platforms[0].allegations[0];assert.equal(s.bindings[0].bindings.rows.length,0);
 s.state.hooks.push(({method,host})=>method==='attributionClaimRecord'&&host===s.source.owners[4]?[{...row.record,reasonHash:H('changed')}]:undefined);
 await assert.rejects(capture(s),/retained attribution allegation/i);
});

test('complete repeated capture reads both original source eras and carried Platform history',async()=>{
 const s=setup({repeated:true}),c=await capture(s),p=c.certificate.admission.provenance;
 assert.equal(p.eras.length,2);assert.equal(s.platforms[0].allegations.length,2);assert.notEqual(p.eras[1].priorImportCommitment,ZeroHash);
 for(const origin of p.origins)assert.ok(s.state.calls.some(v=>v.method==='storedPayloadCount'&&v.host===origin.archive));
 for(const row of s.archiveRows)assert.ok(s.state.calls.some(v=>v.method==='artistEvidenceBytesV2'&&v.args[0]===row.evidenceId));
 for(let i=0;i<7;i++)assert.equal(c.owners[i].payload.provenance.eras.length,2);
});

test('complete repeated capture refuses changed prior imported cutover revision',async()=>{
 const s=setup({repeated:true}),p=s.payloads[2].provenance,last=p.eras.at(-1),old=new Set(p.eras.slice(0,-1).map(e=>e.originHash));
 const prefix={origins:p.origins.slice(0,-1),eras:p.eras.slice(0,-1),journal:p.journal.filter(j=>old.has(j.position.point.environmentHash)),aliases:p.aliases.filter(a=>old.has(a.originHash))};
 s.state.hooks.push(({method,host})=>method==='recoveredHydrationImportedPrefix'&&host===s.source.owners[2]?[prefix,last.priorImportCommitment,last.lowerRevision+1n]:undefined);
 await assert.rejects(capture(s),/Source imported commitment or local revision differs/);
});

test('complete simulation invokes the original Registry at a fixed fresh block',async()=>{
 const s=setup(),c=await capture(s),r=await workflow.simulateArtistCompleteHistoryHydration(s.provider,c,{blockTag:10,gasLimit:10000000n});
 assert.equal(r.registrySimulated,true);assert.equal(r.futureExecutionGuaranteed,false);
 const call=s.state.calls.findLast(v=>v.method.startsWith('hydrateRecovered'));assert.equal(call.from,s.caller);assert.equal(call.value,0n);assert.equal(call.tag,10);
});

test('complete current inspection reruns original preparation and refuses changed source',async()=>{
 const s=setup();await capture(s);const before=s.state.calls.filter(v=>v.method==='prepare').length;
 assert.equal((await workflow.inspectArtistCompleteHistoryHydrationCurrent(s.provider,s.deployment,s.caller,s.input,{blockTag:10,gasLimit:10000000n})).registrySimulated,true);
 assert.ok(s.state.calls.filter(v=>v.method==='prepare').length>before);
 s.state.hooks.push(({method,host})=>method==='nextRegistrationNonce'&&host===s.source.owners[2]?[1n]:undefined);
 await assert.rejects(capture(s),/aggregate registration counter/);
});

for(const [variant,options,mode] of [['zero direct',{},'direct'],['zero Safe1.3',{},'legacy'],['zero Safe1.4',{},'indexed'],['historical direct',{historical:true},'direct'],['historical Safe1.3',{historical:true},'legacy'],['historical Safe1.4',{historical:true},'indexed']])test(`complete ${variant} receipt authenticates one import and retains proof limitations`,async()=>{
 const s=setup(options),c=await capture(s),m=install(s,c,mode),r=await workflow.inspectArtistCompleteHistoryHydrationHistory(s.provider,c,H('tx'),m.options);
 assert.equal(r.historicalImportProven,true);assert.equal(r.completeCommonInventoryReadBack,true);assert.equal(r.originalArchiveClockReadbackVerifiedAtReceipt,true);
 assert.equal(r.originalCompositionIndependentlyVerified,false);assert.equal(r.currentAuthorityClaimed,false);assert.equal(r.privateSemanticInstallationIndependentlyVerified,false);assert.equal(r.ownerSignaturesIndependentlyVerified,false);assert.equal(r.safeImplementationIndependentlyVerified,false);
 r.ownerSnapshots.forEach((row,i)=>assert.equal(row.revision,c.certificate.admission.before_[i].revision+1n));
 assert.equal(r.events.filter(v=>v.event==='RecoveredArtistAuthorityHydrated').length,1);assert.equal(r.events.filter(v=>v.event==='ArtistArchiveEvidenceAppendedV2').length,c.descriptor.pageHashes.length+1);
});

test('complete receipt permits later pending acceptance and overwritten acceptance heads',async()=>{
 const s=setup({historical:true,royalties:false}),c=await capture(s),m=install(s,c);later(s,c,[0,3,4]);
 const pending=s.bindings[0].bindings.rows.at(-1);
 s.state.hooks.push(({method,host,tag,args})=>{if(tag!==12)return;if(method==='bindingAt'&&host===s.destination.owners[0]&&args[1]===pending.item.generation)return[{...pending.item,accepted:true}];if(host===s.destination.owners[3]&&['acceptedAt','acceptanceRecord'].includes(method))throw Error('Mutable primary acceptance head is not historical evidence');});
 assert.equal((await run(s,c,m)).historicalImportProven,true);
});

test('complete later destination activity cannot alter original historical economics',async()=>{
 const s=setup({historical:true,royalties:false}),c=await capture(s),m=install(s,c),e=s.contents[0].original.economics[0];later(s,c,[6]);
 s.state.hooks.push(({method,host,tag})=>tag===12&&host===s.destination.owners[6]&&method==='economicsRecordAssociation'?[{...e.item.association,bindingHash:H('changed binding')}]:undefined);
 await assert.rejects(run(s,c,m),/economics record association/);
});

test('complete receipt conservatively refuses same-block original Archive append',async()=>{
 const s=setup(),c=await capture(s),m=install(s,c);
 s.state.hooks.push(({method,host,tag})=>tag===12&&method==='storedPayloadCount'&&host===s.source.archive?[BigInt(s.archiveRows.length+1)]:undefined);
 await assert.rejects(run(s,c,m),/catalogue count/);
});

test('complete Safe transport rejects changed value nonce and signed gas',async()=>{
 const s=setup(),c=await capture(s);let m=install(s,c);s.state.tx.value=1n;await assert.rejects(run(s,c,m),/value/);
 m=install(s,c,'legacy');s.state.safeEndingNonce=9n;await assert.rejects(run(s,c,m),/nonce/);s.state.safeEndingNonce=5n;
 m=install(s,c,'indexed');const v=Array.from(safeABI.decodeFunctionData('execTransaction',s.state.tx.data));v[4]+=1n;s.state.tx.data=safeABI.encodeFunctionData('execTransaction',v);await assert.rejects(run(s,c,m),/hash/);
});

test('complete Safe application ordering permits unrelated post-execution guard logs',async()=>{
 const s=setup(),c=await capture(s),m=install(s,c,'indexed');m.logs.push({address:A(999),topics:[H('guard')],data:'0x',index:m.logs.length,blockNumber:12,blockHash:H('block12'),transactionHash:H('tx'),removed:false});
 assert.equal((await run(s,c,m)).historicalImportProven,true);
 const success=m.logs.find(v=>v.address===s.caller);m.logs.splice(m.logs.indexOf(success),1);m.logs.unshift(success);renumber(m.logs);await assert.rejects(run(s,c,m),/precedes complete/);
});

test('complete receipt detaches supplied logs before later reads and pins workers',async()=>{
 const s=setup(),c=await capture(s),m=install(s,c,'indexed');s.state.transactionHook=()=>{s.state.receipt.logs[0].data='0x';};assert.equal((await run(s,c,m)).historicalImportProven,true);
 s.state.transactionHook=null;const next=install(s,c);s.state.hooks.push(({method,host,tag})=>method==='getCode'&&host===s.deployment.preparationLibrary.address&&tag===12?'0x':undefined);await assert.rejects(run(s,c,next),/runtime/i);
});

test('complete refusal distinguishes original success revert and sanitized transport failure',async()=>{
 const s=setup(),c=await capture(s),actual=H('changed actual commitment');s.state.hooks.push(({method})=>method.startsWith('hydrateRecovered')?[actual]:undefined);
 let r=await workflow.observeArtistCompleteHistoryHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});assert.equal(r.status,'succeeded');assert.equal(r.returnedCommitment,actual);assert.equal(r.capturePredictionChecked,false);
 s.state.hooks.length=0;s.state.hooks.push(({method})=>{if(method.startsWith('hydrateRecovered'))throw Object.assign(Error('mock refusal'),{code:'CALL_EXCEPTION',data:'0x12345678'});});
 r=await workflow.observeArtistCompleteHistoryHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});assert.equal(r.status,'reverted');
 s.state.hooks.length=0;s.state.hooks.push(({method})=>{if(method.startsWith('hydrateRecovered'))throw Object.assign(Error('https://secret.invalid'),{code:'NETWORK_ERROR',request:{authorization:'secret'}});});
 r=await workflow.observeArtistCompleteHistoryHydrationRefusal(s.provider,c,{blockTag:11,gasLimit:10000000n});assert.equal(r.status,'rpc-failed');assert.equal(JSON.stringify(r,(_,v)=>typeof v==='bigint'?String(v):v).includes('secret'),false);
});

test('complete refusal rejects cloned captures earlier blocks reorgs and replaced code',async()=>{
 const s=setup(),c=await capture(s),observe=(value=c,tag=11)=>workflow.observeArtistCompleteHistoryHydrationRefusal(s.provider,value,{blockTag:tag,gasLimit:10000000n});
 await assert.rejects(observe(structuredClone(c)),/workflow instance/);await assert.rejects(observe(c,9),/precedes/);
 s.state.blockOverride=tag=>({number:tag,timestamp:100+tag,hash:tag===10?H('reorg'):H(`block${tag}`)});await assert.rejects(observe(),/changed|Reorg|reorg/);s.state.blockOverride=null;
 s.state.hooks.push(({method,host,tag})=>method==='getCode'&&host===s.deployment.source.registry.address&&tag===11?'0x':undefined);await assert.rejects(observe(),/runtime/i);
});
