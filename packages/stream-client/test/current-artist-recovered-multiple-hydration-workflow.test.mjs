// Compiler-encoded RPC consistency tests only; no Solidity execution or private-state proof.
import test from 'node:test';
import assert from 'node:assert/strict';
import { ZeroAddress, ZeroHash } from 'ethers';
import { setup, capture, install, run, renumber, rh, workflow, abi, preparedAbi, safeABI, A, H } from './current-artist-recovered-multiple-hydration-workflow-fixture.mjs';

test('plural preparation captures every lane and one aggregate nonce inventory before original caller simulation', async () => {
  const s=setup(),c=await capture(s);
  assert.equal(c.certificate.admission.artists.length,2); assert.equal(c.certificate.admission.collections.length,2);
  assert.equal(c.certificate.admission.before_[2].revision,5n);
  assert.equal(c.registrySimulated,false); assert.notEqual(c.prepared.request.expectedSemanticInventory,ZeroHash);
  for(const q of [...c.certificate.admission.artists,...c.certificate.admission.collections]) {
    assert.ok(s.state.calls.some(v=>v.method==='importedLaneVerified' && (q.collectionId===0n?v.args[1]===q.artistId:BigInt(v.args[1])===q.collectionId)));
  }
  const checked=await workflow.simulateArtistRecoveredMultipleHydration(s.provider,c,{blockTag:11,gasLimit:10000000n});
  assert.equal(checked.registrySimulated,true); assert.equal(checked.futureExecutionGuaranteed,false);
  const call=s.state.calls.findLast(v=>v.method==='hydrateRecoveredArtistAuthority');
  assert.equal(call.host,s.destination.registry); assert.equal(call.from,s.caller); assert.equal(call.value,0n);
});

test('one Artist with two complete collections derives the original four-revision fresh Identity profile', async () => {
  const s=setup({oneArtist:true}),c=await capture(s);
  assert.equal(c.certificate.admission.artists.length,1); assert.equal(c.certificate.admission.collections.length,2);
  assert.equal(c.certificate.admission.before_[2].revision,4n);
  assert.equal(c.after[2].revision,5n);
});

test('direct and both Safe event layouts retain one seven-owner apply and the complete paged operation60 archive', async () => {
  for(const mode of ['direct','legacy','indexed']) {
    const s=setup(),c=await capture(s),m=install(s,c,mode),r=await run(s,c,m);
    assert.equal(r.commitment,c.commitment); assert.equal(r.historicalImportProven,true); assert.equal(r.currentAuthorityClaimed,false);
    assert.equal(r.laneActivationIndependentlyVerified,false); assert.equal(r.privateSemanticInstallationIndependentlyVerified,false);
    assert.equal(r.ownerSignaturesIndependentlyVerified,false); assert.equal(r.safeImplementationIndependentlyVerified,false);
    assert.equal(r.events.filter(e=>e.event==='RecoveredArtistAuthorityHydrated').length,1);
    assert.equal(r.events.filter(e=>e.event==='ArtistArchiveEvidenceAppendedV2').length,c.descriptor.pageHashes.length+1);
    r.ownerSnapshots.forEach((v,i)=>assert.equal(v.revision,c.certificate.admission.before_[i].revision+1n));
  }
});

test('non-anchor Artist and collection lane rejection cannot be hidden by an intact first lane', async () => {
  for(const kind of [1n,2n]) {
    const s=setup(),q=kind===1n?s.certificate.admission.artists[1]:s.certificate.admission.collections[1];
    s.state.hooks.push(({method,args})=>method==='importedLaneVerified'&&args[0]===kind&&(kind===1n?args[1]===q.artistId:BigInt(args[1])===q.collectionId)?[false,H('missing non-anchor lane'),BigInt(q.records.length)]:undefined);
    await assert.rejects(capture(s),/operation56 lane/);
  }
});

test('source aggregate registration counter and complete non-anchor nonce words are independently read', async () => {
  for(const which of ['counter','index','words']) {
    const s=setup(); const payload=rh.decodeArtistRecoveredMultipleHydrationOwnerPayload(s.certificate.data[2].typedState,2).payload;
    const last=payload.nonces.at(-1);
    s.state.hooks.push(({method,host,args})=>{
      if(host!==s.source.owners[2])return;
      if(which==='counter'&&method==='nextRegistrationNonce')return[1n];
      if(which==='index'&&method==='authorityNonceIndexAt'&&args[0]===BigInt(payload.nonces.length-1))return[{...last.index,key:H('foreign lane')}];
      if(which==='words'&&method==='authorityNonceWordAt'&&args[1]===last.index.key){const w=structuredClone(last.words[Number(args[2])]);w.words[31]^=1n;return[w.prefix,w.words,w.exhausted];}
    });
    await assert.rejects(capture(s),/aggregate registration|nonce index|nonce prefix/);
  }
});

test('plural pristine revision and replay count refuse legacy singleton preparation clocks', async () => {
  for(const which of ['revision','replay']) {
    const s=setup();s.state.hooks.push(({method,host})=>{
      if(host!==s.destination.owners[2])return;
      if(which==='revision'&&method==='ownerStateSnapshotV2')return[{...s.before[2],revision:3n}];
      if(which==='replay'&&method==='authorityCheckpoint')return[{schema:rh.ARTIST_RECOVERED_MULTIPLE_HYDRATION_CHECKPOINT_SCHEMA,ownerState:s.before[2],replayCount:6n,replayRoot:H('r'),nonceIndexCount:0n,nonceRoot:H('n')}];
    });await assert.rejects(capture(s),/fresh seven-owner/);
  }
});

test('exact expected capability and destination whole-profile support remain distinct checks', async () => {
  const s=setup();s.state.hooks.push(({method,host})=>method==='recoveredAuthorityHydrationCapability'&&host===s.source.owners[3]?[{...s.request.expectedCapabilities[3],supportedFeatures:262175n}]:undefined);
  await assert.rejects(capture(s),/Expected source capability/);
  const d=setup();d.state.hooks.push(({method,host})=>method==='recoveredAuthorityHydrationCapability'&&host===d.destination.owners[4]?[{...d.request.expectedCapabilities[4],supportedFeatures:511n}]:undefined);
  await assert.rejects(capture(d),/complete features/);
});

test('original unsupported-history refusal is decisive and no fallback transaction is prepared', async () => {
  const s=setup();s.state.hooks.push(({method})=>{if(method==='prepare')throw Error('original MULTIPLE_BASE unsupported delegated content history');});
  await assert.rejects(capture(s),/original MULTIPLE_BASE unsupported/);
  assert.equal(s.state.calls.some(v=>v.method==='hydrateRecoveredArtistAuthority'),false);
});

test('complete nonce union is bound inside the original canonical owner State', async () => {
  const s=setup(),bad=structuredClone(s.certificate);
  const {header,payload}=rh.decodeArtistRecoveredMultipleHydrationOwnerPayload(bad.data[2].typedState,2);
  const changed=structuredClone(payload);changed.nonces.at(-1).words[0].words[0]^=1n;
  bad.data[2].typedState=rh.encodeArtistRecoveredMultipleHydrationOwnerPayload(changed,2,header.requiredFeatures);
  s.state.certificate=bad;
  await assert.rejects(capture(s),/nonce|union/i);
});

test('capture inputs are copied before awaits and canonical preparation bytes cannot carry a trailing word', async () => {
  const s=setup(),network=s.provider.getNetwork;let first=true;
  s.provider.getNetwork=async()=>{if(first){first=false;s.request.expectedSemanticInventory=H('mutated input');}return network();};
  const c=await capture(s);assert.notEqual(c.prepared.request.expectedSemanticInventory,s.request.expectedSemanticInventory);
  const bad=setup();bad.state.hooks.push(({method,fragment})=>method==='prepare'?`${preparedAbi.encodeFunctionResult(fragment,[bad.certificate])}${'00'.repeat(32)}`:undefined);
  await assert.rejects(capture(bad),/Noncanonical/);
});

test('saved capture revalidation refuses changed sources, fabricated captures and backward simulation', async () => {
  const s=setup(),c=await capture(s);
  const altered=structuredClone(c);altered.commitment=H('fabricated');
  await assert.rejects(workflow.simulateArtistRecoveredMultipleHydration(s.provider,altered,{blockTag:11,gasLimit:10000000n}),/capture/i);
  await assert.rejects(workflow.simulateArtistRecoveredMultipleHydration(s.provider,c,{blockTag:9,gasLimit:10000000n}),/precedes/);
  s.state.hooks.push(({method,host,tag})=>method==='nextRegistrationNonce'&&host===s.source.owners[2]&&tag===11?[99n]:undefined);
  await assert.rejects(workflow.simulateArtistRecoveredMultipleHydration(s.provider,c,{blockTag:11,gasLimit:10000000n}),/aggregate registration/);
});

test('receipt transport refuses wrong caller, changed calldata, nonzero value and failed outer transactions', async () => {
  const s=setup(),c=await capture(s);
  for(const change of [m=>{s.state.tx.from=A(999);},m=>{s.state.tx.data='0x1234';},m=>{s.state.tx.value=1n;},m=>{s.state.receipt.status=0;}]) {
    const m=install(s,c);change(m);await assert.rejects(run(s,c,m),/transaction|value|failed|successful|succeeded|status/i);
  }
});

test('Safe receipt checks all signed fields with independent nonce/hash and reviewed caller runtime', async () => {
  const s=setup(),c=await capture(s);
  for(const field of ['nonce','hash','runtime','innerValue','operation','gas']) {
    const m=install(s,c,'legacy');
    if(field==='nonce')s.state.safeEndingNonce=9n;
    else if(field==='hash')m.options.expectedSafeTxHash=H('wrong signed hash');
    else if(field==='runtime')m.options.safeCodeHash=H('wrong runtime');
    else{const values=Array.from(safeABI.decodeFunctionData('execTransaction',s.state.tx.data));values[field==='innerValue'?1:field==='operation'?3:4]+=1n;s.state.tx.data=safeABI.encodeFunctionData('execTransaction',values);}
    await assert.rejects(run(s,c,m),/Safe|runtime|CALL|hash/i);s.state.safeEndingNonce=5n;
  }
});

test('Safe success must follow original application evidence but unrelated later guard logs remain valid', async () => {
  const s=setup(),c=await capture(s),m=install(s,c,'indexed');
  m.logs.push({address:A(999),topics:[H('unrelated guard')],data:'0x',index:m.logs.length,blockNumber:12,blockHash:H('block12'),transactionHash:H('tx'),removed:false});
  assert.equal((await run(s,c,m)).historicalImportProven,true);
  const success=m.logs.find(v=>v.address===s.caller);m.logs.splice(m.logs.indexOf(success),1);m.logs.unshift(success);renumber(m.logs);
  await assert.rejects(run(s,c,m),/precedes complete/);
  const failure=install(s,c,'legacy');failure.emit(s.caller,'ExecutionFailure',[failure.options.expectedSafeTxHash,0n],safeABI);
  await assert.rejects(run(s,c,failure),/failure|failed/i);
});

test('every owner commitment and exact immutable imported prefix is required once', async () => {
  const s=setup(),c=await capture(s),m=install(s,c);
  for(const which of ['commitment','prefix','revision']) {
    const hook=({method,host,tag})=>{
      if(host!==s.destination.owners[6]||tag!==12)return;
      if(method==='authorityHydrationCommitment'&&which==='commitment')return[H('wrong marker')];
      if(method==='recoveredHydrationImportedPrefix')return[which==='prefix'?{origins:[],eras:[],journal:[],aliases:[]}:c.owners[6].payload.provenance,c.commitment,which==='revision'?c.after[6].revision+1n:c.after[6].revision];
    };s.state.hooks.push(hook);await assert.rejects(run(s,c,m),/commitments|prefix|revisions/);s.state.hooks.pop();
  }
});

test('mined registration count and global nonce insertion order are checked without per-Artist reset', async () => {
  const s=setup(),c=await capture(s),m=install(s,c);
  for(const which of ['counter','index','count']) {
    s.state.hooks.push(({method,host,tag,args})=>{
      if(host!==s.destination.owners[2]||tag!==12)return;
      if(which==='counter'&&method==='nextRegistrationNonce')return[1n];
      if(which==='index'&&method==='authorityNonceIndexAt')return[c.owners[2].payload.nonces[Number(args[0])===0?1:0].index];
      if(which==='count'&&method==='authorityCheckpoint')return[{schema:rh.ARTIST_RECOVERED_MULTIPLE_HYDRATION_CHECKPOINT_SCHEMA,ownerState:c.after[2],replayCount:10n,replayRoot:H('r'),nonceIndexCount:0n,nonceRoot:H('n')}];
    });await assert.rejects(run(s,c,m),/aggregate registration|nonce insertion|nonce index count/);s.state.hooks.pop();
  }
});

test('complete Archive pages require STOP carriers, ordered append events and exactly one coordinator commit', async () => {
  const s=setup(),c=await capture(s);
  for(const which of ['missing','duplicate','carrier','order']) {
    const m=install(s,c);const commits=m.logs.filter(v=>v.topics[0]===abi.getEvent('RecoveredArtistAuthorityHydrated').topicHash);
    if(which==='duplicate'){m.logs.push({...commits[0]});renumber(m.logs);}
    if(which==='missing'){m.logs.splice(m.logs.findIndex(v=>v.topics[0]===abi.getEvent('ArtistArchiveEvidenceAppendedV2').topicHash),1);renumber(m.logs);}
    if(which==='carrier')s.state.codes.set(A(200),'0x01');
    if(which==='order'){const index=m.logs.indexOf(commits[0]);m.logs.splice(index,1);m.logs.unshift(commits[0]);renumber(m.logs);}
    await assert.rejects(run(s,c,m),/Archive|carrier|STOP|hydration event|ordering|runtime/i);
  }
});

test('mined source and preparation worker runtime pins remain mandatory without fresh source authorization', async () => {
  const s=setup(),c=await capture(s),m=install(s,c);
  for(const pin of [s.deployment.source.components[2],s.deployment.preparationLibrary,s.deployment.preparationDependencies[0]]) {
    s.state.hooks.push(({method,host,tag})=>method==='getCode'&&tag===12&&host===pin.address?'0x':undefined);
    await assert.rejects(run(s,c,m),/runtime|code/i);s.state.hooks.pop();
  }
});

test('immutable historical import survives later owner progress while fresh import inspection refuses replay', async () => {
  const s=setup(),c=await capture(s),m=install(s,c);
  s.state.hooks.push(({method,host,tag})=>{
    if(tag!==12)return;
    if(method==='ownerStateSnapshotV2'&&host===s.destination.owners[2])return[{...c.after[2],revision:c.after[2].revision+1n,stateRoot:H('later root')}];
    if(method==='nextRegistrationNonce'&&host===s.destination.owners[2])throw Error('later counter must not be read as original import');
  });
  const r=await workflow.inspectArtistRecoveredMultipleHydrationHistory(s.provider,c,H('tx'),m.options);
  assert.equal(r.historicalImportProven,true);assert.equal(r.currentAuthorityClaimed,false);
  await assert.rejects(workflow.inspectArtistRecoveredMultipleHydrationCurrent(s.provider,s.deployment,s.caller,s.request,{blockTag:12,gasLimit:10000000n}),/fresh/);
});

test('receipt and input copies precede awaited transport reads and reorg or same-block attribution refuses', async () => {
  const s=setup(),c=await capture(s),m=install(s,c,'indexed');
  s.state.transactionHook=()=>{s.state.receipt.logs[0].data='0x';};
  assert.equal((await run(s,c,m)).historicalImportProven,true);
  s.state.transactionHook=null;install(s,c);
  s.state.blockOverride=tag=>tag===12?{number:12,timestamp:112,hash:H('reorg')}:undefined;
  await assert.rejects(run(s,c,{options:{execution:'direct'}}),/block|canonical/i);
  s.state.blockOverride=null;s.state.tx.blockNumber=10;s.state.tx.blockHash=H('block10');s.state.receipt.blockNumber=10;s.state.receipt.blockHash=H('block10');
  for(const log of s.state.receipt.logs){log.blockNumber=10;log.blockHash=H('block10');}
  await assert.rejects(run(s,c,{options:{execution:'direct'}}),/follow|later/);
});
