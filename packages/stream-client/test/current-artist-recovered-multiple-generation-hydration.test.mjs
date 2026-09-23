// Supplied-data tests, not native admission or signature execution.
import test from 'node:test';
import assert from 'node:assert/strict';
import { id, keccak256, ZeroHash } from 'ethers';
import { m, semanticFixture, refresh, coder, T, zero, hash, child, A, H } from './current-artist-recovered-multiple-generation-hydration-semantic-fixture.mjs';
import { createArtistRecoveredHydrationCodec } from '../dist/internal/artist-recovered-hydration-codec.js';
import { compiledInterfaces } from './current-artist-recovered-multiple-generation-hydration-source-fixture.mjs';
const clone = structuredClone;
let pending, accepted;
const sample = (history = false) => history ? (accepted ??= semanticFixture({ acceptedHistory: true, attestations: true })) : (pending ??= semanticFixture());
const clockOf = f => m.validateArtistRecoveredMultipleGenerationHydrationClocks(f.states[4], f.provenance, f.clocks, f.clockFacts);
const validate = f => m.normalizeArtistRecoveredMultipleGenerationHydrationPrepared(f.certificate);
const op = (f, owner) => m.artistRecoveredMultipleGenerationHydrationOwnerProvenance(f.provenance, owner);
const arrayCopy = value => value.map(v => clone(v));

// The material cache is test-owned only; production retains immutable schemas only.
test('generation profile has its own exact bit and preserves all previous codec masks', () => {
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BASE, 2097152n);
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ALLOWED_FEATURES, 2276351n);
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_SCHEMA, id('6529STREAM_ARTIST_RECOVERED_MULTIPLE_GENERATIONS_V1'));
  const f = sample();
  for (const mask of [255n,511n,262175n,524671n,1049087n]) {
    const old = createArtistRecoveredHydrationCodec(mask);
    assert.equal(old.artistRecoveredHydrationOriginHash(f.origin), m.artistRecoveredMultipleGenerationHydrationOriginHash(f.origin));
    for (let i = 0; i < 7; i++) assert.equal(old.artistRecoveredHydrationOwnerDomain(i),m.artistRecoveredMultipleGenerationHydrationOwnerDomain(i));
    assert.throws(() => old.decodeArtistRecoveredHydrationOwnerPayload(f.certificate.data[0].typedState,0),/feature|profile|supported|header/i);
  }
  assert.throws(() => createArtistRecoveredHydrationCodec(2276350n), /profile|codec|unsupported/i);
});

test('genuine compiler generation values round trip without nominal callable selector claims', () => {
  const f = sample(true);
  const rows = [
    ['Inventory',T.clocks,f.clocks], ['BindingBundle',T.bindingBundle,f.bindings[0]],
    ['AcceptanceBundle',T.acceptanceBundle,f.acceptances[0]], ['AttributionHistory',T.history,f.attribution[0].history],
    ['Consents',T.consents,f.contents[0]], ['Attribution',T.gAttribution,f.attribution[0]],
  ];
  for (const [name,type,value] of rows) {
    const raw=coder.encode([type],[value]);
    assert.equal(m[`encodeArtistRecoveredMultipleGenerationHydration${name}`](value),raw);
    assert.deepEqual(m[`decodeArtistRecoveredMultipleGenerationHydration${name}`](raw),value);
    assert.throws(()=>m[`decodeArtistRecoveredMultipleGenerationHydration${name}`](`${raw}${'00'.repeat(32)}`),/canonical/i);
  }
  assert.equal(m.decodeArtistRecoveredMultipleGenerationHydrationInventory(coder.encode([T.clocks],[zero(T.clocks)])).operations.length,0);
});

test('pending refusal and withdrawal generations admit zero op24 with complete current inventory', () => {
  const f=sample(), p=validate(f), clocks=clockOf(f);
  assert.equal(f.provenance.journals[4].length,0);
  assert.ok(f.envelopes.some(e=>e.operation===3n)); assert.ok(f.envelopes.some(e=>e.operation===4n));
  assert.ok(f.provenance.journals[0].every(j=>j.receipt.operation!==4n));
  assert.equal(clocks.factsVerified,false); assert.equal(clocks.counts[0],12n);
  assert.equal(p.query.collectionId,p.admission.collections[0].collectionId);
  assert.deepEqual(p.query.records,p.admission.artists.find(a=>a.artistId===p.query.artistId).records);
  for(const t of clocks.collections) assert.ok(t.completions[0].ownerRevision>t.proposals[0].ownerRevision+1n);
  m.validateArtistRecoveredMultipleGenerationHydrationInput(f.input,p);
});

test('accepted history authenticates separated governed openings and owner4 completion windows', () => {
  const f=sample(true), p=validate(f), clocks=clockOf(f);
  m.validateArtistRecoveredMultipleGenerationHydrationRevocations(f.states[4],f.provenance,f.clocks,f.attribution.map(a=>a.history),clocks);
  const result=m.validateArtistRecoveredMultipleGenerationHydrationAttestations(f.identities,f.collections,f.attestations,f.provenance,f.clocks,clocks);
  assert.equal(result.factsVerified,false); assert.ok(result.credentialHeads.some(h=>h.revision>2n));
  assert.equal(result.credentialRecords.length,f.provenance.journals[4].filter(j=>j.receipt.operation===24n).length);
  const history=f.attribution[0].history.revocations[0];
  const opened=f.provenance.journals[4].find(j=>j.receipt.recordHash===history.opening.recordHash).position.point;
  const resolved=f.provenance.aliases[4].find(a=>a.surface===id('attribution_lifecycle.replay.dispute_resolution_key')&&a.scope===history.opening.recordHash).admittedAt;
  assert.ok(resolved.ownerRevision>opened.ownerRevision+1n);
  assert.equal(p.admission.collections[0].records.length>f.states[4].collections[0].records.length,true);
});

test('all owners retain full Artist queries while only owner4 collection records project op24', () => {
  const f=sample(true);
  for(let i=0;i<7;i++){
    const d=m.decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(f.payloads[i].semanticState,i,op(f,i));
    assert.deepEqual(d.state.artists,f.artists);
    if(i!==4)assert.deepEqual(d.state.collections,f.collections);
    if(i===0||i===4)assert.equal(d.auxiliary,coder.encode([T.clocks],[f.clocks]));
    else if(i===3)assert.equal(d.auxiliary,coder.encode([`${T.generation.format('full')}[][]`],[f.clocks.generations]));
    else assert.equal(d.auxiliary,'0x');
  }
});

test('complete generation rows reject current-only and changed primary supplied facts',()=>{
  const f=clone(sample(true)); f.bindings[1].bindings.rows[0].item.artistId=H(998); refresh(f);
  assert.throws(()=>validate(f),/generation binding preimage/);
  const short=clone(sample());short.clocks.generations[1].pop();
  assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationInventory(short.states[4],op(short,4),short.clocks),/Incomplete generation binding/);
});

test('fully rehashed content continuation must retain first economics record',()=>{
  const f=sample(true), values=clone(f.contents), row=values[0].rows.original.economics[1];
  assert.notEqual(row.item.recordHash,row.item.association.originalRecord);
  row.item.association.originalRecord=row.item.recordHash;
  assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationContentBundles(values,f.collections,op(f,6)),/retain first record/);
  const rows=m.validateArtistRecoveredMultipleGenerationHydrationContentBundles(f.contents,f.collections,op(f,6));
  assert.equal(rows[0].original.sales[0].current,rows[0].original.sales[1].item.recordHash);
  assert.deepEqual(rows[0].royalties[0].terms,rows[0].royalties[1].terms);
});

test('global royalty terms preserve occurrence order and can repeat across generations',()=>{
  const f=sample(true); assert.equal(f.input.royaltyFreezes.length,6);
  assert.deepEqual(m.validateArtistRecoveredMultipleGenerationHydrationInput(f.input,f.certificate),f.input);
  const bad=clone(f.input); [bad.royaltyFreezes[0],bad.royaltyFreezes[1]]=[bad.royaltyFreezes[1],bad.royaltyFreezes[0]];
  assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationInput(bad,f.certificate),/global operation20 order/);
});

test('complete grant uses and global nonce bijection include every generation and collection',()=>{
  const f=sample(true);m.validateArtistRecoveredMultipleGenerationHydrationGrantUses(f.identities,f.collections,f.contents,f.clocks,f.provenance,f.attestations);
  const ids=clone(f.identities);ids[0].delegations[0].record.uses--;
  assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationGrantUses(ids,f.collections,f.contents,f.clocks,f.provenance,f.attestations),/nonce bits|grant uses/i);
  const s=clone(f.states[2]), n=clone(f.nonces); n.pop();
  assert.throws(()=>m.artistRecoveredMultipleGenerationHydrationNonceUnion(s,n,{...f.provenance.eras[0].checkpoints[2],nonceIndexCount:BigInt(n.length)}),/inventory|nonce|Incomplete/i);
});

test('standalone attestation helper joins the saved generation and Artist before supplied clocks',()=>{
  const f=sample(true);
  for(const field of ['generation','artistId']){
    const inventory=clone(f.clocks);inventory.bindings[0].bindings.rows[0].item[field]=field==='generation'?9n:H(991);
    assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationAttestations(f.identities,f.collections,f.attestations,f.provenance,inventory),/original accepted generation/);
  }
});

test('independently rehashed Archive bytes must preserve original owner4 transition and untouched tip',()=>{
  const f=sample(),inventory=clone(f.clocks),facts=clone(f.clockFacts),e=clone(f.envelopes[0]);
  e.after_[4].stateRoot=H(912345);
  facts.envelopes[0]=coder.encode(T.envelope.components,T.envelope.components.map(c=>e[c.name]));
  inventory.operations[0].evidence.payloadHash=keccak256(facts.envelopes[0]);
  assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationClocks(f.states[4],f.provenance,inventory,facts),/owner4 transition preimage/);
  e.after_[4].stateRoot=f.envelopes[0].after_[4].stateRoot;e.after_[4].recordChainTip=H(555);
  facts.envelopes[0]=coder.encode(T.envelope.components,T.envelope.components.map(c=>e[c.name]));inventory.operations[0].evidence.payloadHash=keccak256(facts.envelopes[0]);
  assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationClocks(f.states[4],f.provenance,inventory,facts),/owner4 transition preimage/);
});

test('clock cutoffs authenticate every owner and never infer acceptance from cross-owner revision',()=>{
  const f=sample(),inventory=clone(f.clocks);inventory.catalogues[0].upper[2]++;
  assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationClocks(f.states[4],f.provenance,inventory,f.clockFacts),/seven original cutoffs/);
  const a=clone(sample(true)),clocks=clone(clockOf(a));clocks.collections[0].attributionCompletions[0]=clone(clocks.collections[0].completions[0]);
  assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationRevocations(a.states[4],a.provenance,a.clocks,a.attribution.map(x=>x.history),clocks),/owner|chronology/i);
});

test('governed revocation aliases exhaust original partitions and forbid invented adjacent resolutions',()=>{
  const f=clone(sample(true)),r=f.attribution[0].history.revocations[0],opened=f.provenance.journals[4].find(j=>j.receipt.recordHash===r.opening.recordHash).position.point;
  const prior=f.provenance.aliases[4].find(v=>v.surface===id('attribution_lifecycle.replay.dispute_resolution_key')&&v.scope===r.opening.recordHash).admittedAt.ownerRevision;
  for(const a of f.provenance.aliases[4])if(a.admittedAt.ownerRevision===prior){a.admittedAt.ownerRevision=opened.ownerRevision+1n;a.cell.touchedRevision=a.admittedAt.ownerRevision;}
  assert.throws(()=>{refresh(f);validate(f);},/resolution coordinate|alias|native/i);
});

test('owner payload and canonical dynamic decoders reject wrong tags dirty bool and trailing words',()=>{
  const f=sample(),raw=m.encodeArtistRecoveredMultipleGenerationHydrationInventory(f.clocks);
  assert.throws(()=>m.decodeArtistRecoveredMultipleGenerationHydrationInventory(`${raw}${'00'.repeat(32)}`),/canonical/);
  const dirty=coder.encode([T.bindingBundle],[f.bindings[0]]);
  const wordAt=offset=>BigInt('0x'+dirty.slice(2+offset*2,66+offset*2));
  const bundle=Number(wordAt(0)),binding=bundle+Number(wordAt(bundle)),boolOffset=binding+13*32;
  const changed=dirty.slice(0,2+boolOffset*2)+'2'.padStart(64,'0')+dirty.slice(2+(boolOffset+32)*2);
  assert.throws(()=>m.decodeArtistRecoveredMultipleGenerationHydrationBindingBundle(changed),/canonical|bool/i);
  const wrong=coder.encode(['bytes32','uint16','uint8',T.state,'bytes'],[id('6529STREAM_ARTIST_RECOVERED_MULTIPLE_ATTESTATIONS_V1'),1n,4n,f.states[4],coder.encode([T.clocks],[f.clocks])]);
  assert.throws(()=>m.decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(wrong,4,op(f,4)),/schema|profile|owner|tag/i);
  assert.throws(()=>m.normalizeArtistRecoveredMultipleGenerationHydrationInventory({...f.clocks,unexpected:true}),/field|shape|key/i);
});

test('new-only wrappers and arrays never invoke accessors and bound cumulative input first',()=>{
  const f=sample();let reads=0;
  for(const [value,key,invoke] of [
    [clone(f.clockFacts),'envelopes',v=>m.validateArtistRecoveredMultipleGenerationHydrationClocks(f.states[4],f.provenance,f.clocks,v)],
    [clone(f.input),'request',v=>m.normalizeArtistRecoveredMultipleGenerationHydrationInputDraft(v)],
    [clone(clockOf(f)),'factsVerified',v=>m.validateArtistRecoveredMultipleGenerationHydrationRevocations(f.states[4],f.provenance,f.clocks,f.attribution.map(x=>x.history),v)]
  ]){Object.defineProperty(value,key,{enumerable:true,get(){reads++;throw Error('getter invoked');}});assert.throws(()=>invoke(value));}
  const facts=clone(f.clockFacts);Object.defineProperty(facts.envelopes,'0',{enumerable:true,get(){reads++;return '0x';}});assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationClocks(f.states[4],f.provenance,f.clocks,facts));
  const rows=clone(f.contents);Object.defineProperty(rows,'0',{enumerable:true,get(){reads++;return f.contents[0];}});assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationContentBundles(rows,f.collections,op(f,6)));
  assert.equal(reads,0);
  const giant='0x'+'00'.repeat(140000),tooLarge={...f.clockFacts,envelopes:Array(128).fill(giant)};
  assert.throws(()=>m.validateArtistRecoveredMultipleGenerationHydrationClocks(f.states[4],f.provenance,f.clocks,tooLarge),/capacity|bytes|limit/i);
});

test('exact original two wallet routes reconstruct readonly calls and preserve royalty input',()=>{
  for(const f of [sample(),semanticFixture({royalties:false})]){
    const c=m.prepareArtistRecoveredMultipleGenerationHydrationCall(A(101),A(102),f.input),method=f.input.royaltyFreezes.length?'hydrateRecoveredArtistAuthorityWithConsents':'hydrateRecoveredArtistAuthority';
    assert.equal(c.call.data,compiledInterfaces.registry.encodeFunctionData(method,f.input.royaltyFreezes.length?[f.request,f.input.royaltyFreezes]:[f.request]));
    assert.equal(c.factsVerified,false);assert.equal(c.call.value,0n);assert.ok(Object.isFrozen(c)&&Object.isFrozen(c.request.records.authority.collections));
    assert.deepEqual(m.normalizeArtistRecoveredMultipleGenerationHydrationCall(c),c);
    assert.throws(()=>m.normalizeArtistRecoveredMultipleGenerationHydrationCall({...c,call:{...c.call,data:`${c.call.data}00`}}),/immutable input/);
  }
});

test('standalone profile evidence retains request guards and full original provenance',()=>{
  const f=sample(),raw=m.encodeArtistRecoveredMultipleGenerationHydrationProfileEvidence(f.request,f.certificate),decoded=m.decodeArtistRecoveredMultipleGenerationHydrationProfileEvidence(raw);
  assert.deepEqual(decoded.collections,f.collections);assert.equal(decoded.query.bindingHash,f.collections[0].bindingHash);
  assert.throws(()=>m.decodeArtistRecoveredMultipleGenerationHydrationProfileEvidence(`${raw}${'00'.repeat(32)}`),/canonical/);
  const altered=clone(f.request);altered.expectedSourceImportCommitment=H(999);
  assert.throws(()=>m.encodeArtistRecoveredMultipleGenerationHydrationProfileEvidence(altered,f.certificate),/source|import|commit|certificate/i);
});

test('same term royalty and content keys include generation while raw hashes remain deterministic',()=>{
  const f=sample(true),a=f.contents[0].rows.royalties;
  assert.notEqual(m.artistRecoveredMultipleGenerationHydrationRoyaltyScope(a[0].terms,a[0].item.artistId,1n),m.artistRecoveredMultipleGenerationHydrationRoyaltyScope(a[1].terms,a[1].item.artistId,2n));
  const c=f.contents[0].rows.consents;
  assert.notEqual(m.artistRecoveredMultipleGenerationHydrationContentScope(c[0].terms,1n),m.artistRecoveredMultipleGenerationHydrationContentScope(c[1].terms,2n));
  const correction=f.bindings[0].corrections[1],expected=hash(['bytes32','uint256','address','address','address','uint256','bytes32',child(child(T.bindingBundle,'corrections').arrayChildren,'approval')],
    [id('6529STREAM_ARTIST_BINDING_CORRECTION_RECORD_V1'),f.origin.chainId,f.origin.registry,f.origin.core,f.origin.manager,f.collections[0].collectionId,f.collections[0].bindingHash,correction.approval]);
  assert.equal(m.artistRecoveredMultipleGenerationHydrationCorrectionHash(f.origin,f.collections[0].collectionId,f.collections[0].bindingHash,correction.approval),expected);
});
