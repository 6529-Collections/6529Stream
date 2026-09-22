// Supplied-data validation only; original signature/private admission and EVM execution remain separate.
import test from 'node:test';
import assert from 'node:assert/strict';
import { AbiCoder, ParamType, id, keccak256, ZeroHash } from 'ethers';
import * as m from '../dist/current-artist-recovered-multiple-dispute-hydration.js';
import { createArtistRecoveredHydrationCodec } from '../dist/internal/artist-recovered-hydration-codec.js';
import { semanticFixture } from './current-artist-recovered-multiple-dispute-hydration-semantic-fixture.mjs';
import { compiledInterfaces, multipleDisputeTuple, compiledLibraryValueInterface } from './current-artist-recovered-multiple-dispute-hydration-source-fixture.mjs';

const coder=AbiCoder.defaultAbiCoder(),clone=structuredClone,Z=ZeroHash,cache=new Map();
const sample=(options={})=>{const key=JSON.stringify(options);if(!cache.has(key))cache.set(key,semanticFixture({options}));return cache.get(key);};
const P='ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_';
const T={state:multipleDisputeTuple('StreamArtistRecoveredMultipleTypes.State'),inventory:multipleDisputeTuple('StreamArtistRecoveredMultipleGenerationTypes.Inventory'),history:multipleDisputeTuple('StreamArtistRecoveredDisputeHistoryTypes.Bundle')};
const preparedType=compiledLibraryValueInterface('prepared').fragments.find(f=>f.type==='function'&&f.name==='prepare'&&f.inputs.length===2).outputs[0];
const child=(type,name)=>type.components.find(c=>c.name===name);
const histories=f=>f.attribution.map(b=>b.history),provenance=f=>f.certificate.admission.provenance;
const local=(f,i=4)=>m.artistRecoveredMultipleDisputeHydrationOwnerProvenance(provenance(f),i);
const envelopeBytes=f=>f.clocks.operations.map(op=>{const row=f.archiveRows.find(r=>r.evidenceId===op.evidence.evidenceId);assert.ok(row,'Selected Archive operation requires its original raw envelope');return row.raw;});
const clockOf=f=>m.validateArtistRecoveredMultipleDisputeHydrationClocks(f.states[4],provenance(f),f.clocks,{envelopes:envelopeBytes(f),bindings:f.bindings,acceptances:f.acceptances});
const disputes=(f,rows=histories(f),facts={envelopes:envelopeBytes(f)},inventory=f.clocks,clock=clockOf(f))=>m.validateArtistRecoveredMultipleDisputeHydrationDisputes(f.states[4],provenance(f),inventory,rows,clock,facts);
const identities=(f,rows=f.identities)=>m.validateArtistRecoveredMultipleDisputeHydrationIdentityFacts(rows,f.states[4],f.clocks,f.acceptances,provenance(f),histories(f));
function complete(f){const p=m.normalizeArtistRecoveredMultipleDisputeHydrationPrepared(f.certificate);m.validateArtistRecoveredMultipleDisputeHydrationInput(f.input,p);assert.equal(disputes(f).factsVerified,false);identities(f);return p;}

// Rebuild outer commitments independently so semantic negatives reach the intended proof.
function inventoryHash(f){const p=f.certificate;f.request.expectedSemanticInventory=keccak256(coder.encode(['bytes32','uint16','bytes32',child(preparedType,'query'),child(preparedType,'data'),child(preparedType,'timing'),child(preparedType,'externalGuards')],[id('6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1'),1n,m.artistRecoveredMultipleDisputeHydrationProvenanceHash(provenance(f)),p.query,p.data,p.timing,p.externalGuards]));}
function replaceSemantic(f,owner,edit){
 const payload=clone(f.payloads[owner]),decoded=coder.decode(['bytes32','uint16','uint8',T.state,'bytes'],payload.semanticState),state=clone(f.states[owner]),aux={raw:decoded[4]};edit(state,aux);
 payload.semanticState=coder.encode(['bytes32','uint16','uint8',T.state,'bytes'],[m[P+'SCHEMA'],1n,BigInt(owner),state,aux.raw]);
 const {header}=m.decodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(f.certificate.data[owner].typedState,owner);
 const inner=coder.encode(['bytes32','uint16',m[P+'OWNER_PAYLOAD_TUPLE']],[m[P+'PAYLOAD_SCHEMA'],1n,payload]);
 f.certificate.data[owner].typedState=coder.encode(['bytes32','uint16',m[P+'ENVELOPE_TUPLE']],[m.artistRecoveredMultipleDisputeHydrationOwnerTag(owner),1n,{header:{...header,semanticInventory:keccak256(payload.semanticState)},payload:inner}]);inventoryHash(f);
}
function evidence(f){const p=f.certificate,admission=child(preparedType,'admission');return coder.encode(['bytes32','uint16','address','address',m[P+'REQUEST_TUPLE'],child(admission,'artists'),child(admission,'collections'),child(preparedType,'query'),child(preparedType,'data'),child(preparedType,'timing'),child(preparedType,'externalGuards')],[m[P+'PROFILE'],1n,p.admission.prior,p.admission.sourceCoordinator,f.request,p.admission.artists,p.admission.collections,p.query,p.data,p.timing,p.externalGuards]);}

test('dispute profile preserves historical domains while every prior codec refuses its feature',()=>{
 const f=sample();assert.equal(m[P+'BASE'],16777216n);assert.equal(m[P+'ALLOWED_FEATURES'],16956415n);assert.equal(m[P+'SCHEMA'],id('6529STREAM_ARTIST_MULTIPLE_DISPUTE_HISTORY_V1'));assert.equal(m[P+'KNOWN_FEATURES'],33554431n);
 for(const mask of[255n,511n,262175n,524671n,1049087n,2276351n,4194335n]){const old=createArtistRecoveredHydrationCodec(mask);assert.equal(old.artistRecoveredHydrationOriginHash(f.origin),m.artistRecoveredMultipleDisputeHydrationOriginHash(f.origin));for(let owner=0;owner<7;owner++)assert.equal(old.artistRecoveredHydrationOwnerDomain(owner),m.artistRecoveredMultipleDisputeHydrationOwnerDomain(owner));assert.throws(()=>old.decodeArtistRecoveredHydrationOwnerPayload(f.certificate.data[4].typedState,4),/feature|profile|header/i);}
 assert.throws(()=>createArtistRecoveredHydrationCodec(16777216n),/profile/);
 for(const features of[f.features&~8192n,f.features&~16777216n,f.features|4194304n,f.features|8388608n])assert.throws(()=>m.encodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(f.payloads[4],4,features),/feature|header|profile/i);
});

test('original compiler dispute and generation tuples round trip with canonical trailing-byte refusal',()=>{
 const f=sample();for(const[name,type,value]of[['Inventory',T.inventory,f.clocks],['AttributionHistory',T.history,histories(f)[0]],['BindingBundle',multipleDisputeTuple('StreamArtistRecoveredBindingCorrectionTypes.Bundle'),f.bindings[0]],['AcceptanceBundle',multipleDisputeTuple('StreamArtistRecoveredAcceptedGenerationTypes.AcceptanceBundle'),f.acceptances[0]]]){const raw=coder.encode([type],[value]);assert.equal(m['encodeArtistRecoveredMultipleDisputeHydration'+name](value),raw);assert.deepEqual(m['decodeArtistRecoveredMultipleDisputeHydration'+name](raw),value);assert.throws(()=>m['decodeArtistRecoveredMultipleDisputeHydration'+name](raw+'00'.repeat(32)),/canonical/);}
 const value=f.attribution[0],raw=coder.encode([m[P+'ATTRIBUTION_TUPLE']],[value]);assert.equal(m.encodeArtistRecoveredMultipleDisputeHydrationAttribution(value),raw);assert.deepEqual(m.decodeArtistRecoveredMultipleDisputeHydrationAttribution(raw),value);
});

for(const history of['withdrawal','pending','cancel','veto','executed','pending-revoked','reopen'])test(`complete ${history} history retains original op60 scope and independent clock facts`,()=>{
 const f=sample({history,attestations:false}),p=complete(f),rows=histories(f);
 assert.ok(p.admission.artists.length>1||p.admission.collections.length>1);assert.equal(provenance(f).journals[4].some(j=>j.receipt.operation===24n),false);assert.ok(f.clocks.catalogues.length>0);assert.equal(f.features&16785408n,16785408n);
 assert.deepEqual(p.query.records,p.admission.artists.find(a=>a.artistId===p.query.artistId).records);
 if(history==='withdrawal'){const all=rows.flatMap(b=>b.disputes);for(const action of[1n,2n,3n])assert.ok(all.some(r=>r.record.terms.disputeAction===action));assert.ok(all.some(r=>r.withdrawal.recordHash!==Z));}
 if(history==='pending')assert.ok(rows.flatMap(b=>b.repudiations).filter(r=>r.terminal.phase===1n).length>1);
 if(history==='cancel')assert.ok(rows.some(b=>b.repudiations.some(r=>r.terminal.phase===3n)));
 if(history==='veto'){const vetoes=rows.flatMap(b=>b.repudiations).filter(r=>r.terminal.phase===2n);assert.ok(vetoes.length);assert.equal(provenance(f).journals[2].filter(j=>j.receipt.operation===48n).length,2*vetoes.length);}
 if(history==='executed')assert.ok(rows.some(b=>b.repudiations.some(r=>r.terminal.phase===4n)));
 if(history==='pending-revoked')assert.ok(rows.some(b=>b.generations.some((g,i)=>!g.accepted&&b.heads[i].revocationReason===4n)));
 if(history==='reopen')assert.ok(rows.some(b=>b.heads.some(h=>h.reopened)));
});

test('signed history preserves original consumed lanes and cross-family grant accounting',()=>{
 const f=sample({delegated:true,attestations:true,royalties:true});complete(f);assert.ok(f.identities.some(b=>b.delegations.length));assert.ok(histories(f).some(b=>b.disputes.some(r=>r.record.standing.delegation!==Z)));
 const body=m.encodeArtistRecoveredMultipleDisputeHydrationProfileEvidence(f.request,f.certificate);assert.deepEqual(m.decodeArtistRecoveredMultipleDisputeHydrationProfileEvidence(body).request,f.request);
 const bad=clone(f);const grant=bad.identities.flatMap(b=>b.delegations)[0];grant.record.uses++;
 const at=bad.identities.findIndex(b=>b.delegations.includes(grant));replaceSemantic(bad,2,s=>{s.rows[at]=coder.encode([m[P+'IDENTITY_TUPLE']],[bad.identities[at]]);});
 assert.throws(()=>m.normalizeArtistRecoveredMultipleDisputeHydrationPrepared(bad.certificate),/grant|use|conserv|delegat/i);assert.throws(()=>m.decodeArtistRecoveredMultipleDisputeHydrationProfileEvidence(evidence(bad)),/grant|use|conserv|delegat/i);
});

test('repeated recovery keeps original signed opening and counter before successor withdrawal',()=>{
 const f=sample({repeated:true}),p=complete(f),v=provenance(f);assert.equal(v.origins.length,2);assert.equal(p.admission.sourceCoordinator,v.origins[1].coordinator);assert.ok(f.features&16n);
 for(const operation of[44n,45n]){const ops=f.clocks.operations.filter(o=>o.operation===operation);assert.ok(ops.length);assert.ok(ops.every(o=>o.originHash===v.eras[0].originHash));}
 const withdrawals=histories(f).flatMap(b=>b.disputes).filter(r=>r.record.terms.disputeAction===2n);assert.ok(withdrawals.length);assert.ok(withdrawals.every(r=>r.point.environmentHash===v.eras[1].originHash));
 const opening=histories(f).flatMap(b=>b.disputes).find(r=>r.record.terms.disputeAction===1n);assert.ok(opening);
 const old=v.aliases[4].find(a=>a.originHash===v.eras[0].originHash&&a.surface===id('attribution_lifecycle.replay.dispute_key')&&a.cell.commitment===opening.record.recordHash);assert.ok(old);
 const carried=v.aliases[4].find(a=>a.originHash===v.eras[1].originHash&&a.surface===old.surface&&a.scope===old.scope);assert.ok(carried);assert.deepEqual(carried.cell,old.cell);assert.deepEqual(carried.admittedAt,old.admittedAt);assert.notEqual(carried.originalKey,old.originalKey);
 const bad=clone(v),changed=bad.aliases[4].find(a=>a.originalKey===carried.originalKey);changed.cell.commitment=id('substituted carried original record');
 const rejoined=clone(histories(f)),ownerProvenance=m.artistRecoveredMultipleDisputeHydrationOwnerProvenance(bad,4),commitment=m.artistRecoveredMultipleDisputeHydrationOwnerProvenanceHash(ownerProvenance,4);for(const row of rejoined)row.provenance=commitment;
 assert.throws(()=>m.validateArtistRecoveredMultipleDisputeHydrationDisputes(f.states[4],bad,f.clocks,rejoined,clockOf(f),{envelopes:envelopeBytes(f)}),/Generation replay alias identity mismatch/);
});

test('fully rehashed complete catalogue changes fail Prepared and standalone evidence',()=>{
 for(const mutate of[inventory=>inventory.catalogues.pop(),inventory=>{inventory.catalogues[0].originHash=id('substituted original origin');},inventory=>{inventory.catalogues[0].upper[6]++;}]){
  const f=clone(sample()),changed=clone(f.clocks);mutate(changed);for(const owner of[0,4])replaceSemantic(f,owner,(_s,aux)=>{aux.raw=coder.encode([T.inventory],[changed]);});
  assert.throws(()=>m.normalizeArtistRecoveredMultipleDisputeHydrationPrepared(f.certificate),/catalogue|cutoff|partition|inventory/i);assert.throws(()=>m.decodeArtistRecoveredMultipleDisputeHydrationProfileEvidence(evidence(f)),/catalogue|cutoff|partition|inventory/i);
 }
});

test('whole replay-cell preimages remain authenticated after recomputing semantic inventory',()=>{
 const f=clone(sample());f.certificate.data=clone(f.certificate.data);const owner=f.certificate.data.findIndex(d=>d.cells.length);assert.ok(owner>=0);f.certificate.data[owner].cells[0].commitment=id('replaced replay body');inventoryHash(f);
 assert.throws(()=>m.decodeArtistRecoveredMultipleDisputeHydrationProfileEvidence(evidence(f)),/Evidence guard inventory differs from retained current-origin aliases/);
});

test('original signature presence and consumed nonce bits cannot be removed from an admitted history',()=>{
 const f=sample(),signed=histories(f).flatMap(b=>b.disputes).find(r=>r.record.governanceActionId===Z);assert.ok(signed);
 const missing=clone(f.identities),identity=missing.find(b=>b.artistId===signed.record.artistId)||missing.find(b=>b.signatures.some(s=>s.recordHash===signed.record.recordHash));assert.ok(identity);identity.signatures=identity.signatures.filter(s=>s.recordHash!==signed.record.recordHash);assert.throws(()=>identities(f,missing),/signature/);
 const nonce=clone(f.identities);for(const b of nonce)for(const lane of b.nonces)for(const word of lane.words)word.words=word.words.map(()=>0n);assert.throws(()=>identities(f,nonce),/nonce|consum|word/i);
});

test('collection history heads and immutable withdrawal outcomes cannot replace original chain facts',()=>{
 const f=sample(),rows=clone(histories(f)),opening=rows.flatMap(b=>b.disputes).find(r=>r.withdrawal.recordHash!==Z);assert.ok(opening);opening.withdrawal.counterStatementRecordHash=id('wrong final counter');assert.throws(()=>disputes(f,rows),/withdraw|counter|chain|outcome/i);
 const head=clone(histories(f));head[0].heads[0].disputeRecordHash=id('wrong original head');assert.throws(()=>disputes(f,head),/head|chain|dispute/i);
});

test('original Archive payload identities survive independent evidence rehashing',()=>{
 const f=sample(),inventory=clone(f.clocks),raws=envelopeBytes(f),at=inventory.operations.findIndex(r=>[44n,45n,61n].includes(r.operation));assert.ok(at>=0);
 const e=clone(m.decodeArtistRecoveredMultipleDisputeHydrationArchiveEnvelope(raws[at]));e.actor='0x0000000000000000000000000000000000000999';raws[at]=m.encodeArtistRecoveredMultipleDisputeHydrationArchiveEnvelope(e);inventory.operations[at].evidence.payloadHash=keccak256(raws[at]);
 assert.throws(()=>disputes(f,histories(f),{envelopes:raws},inventory),/Archive identity|Archive.*actor|Archive.*evidence/i);
});

test('non-native resolution and terminal points cannot alias an original binding or native clock',()=>{
 const f=sample({history:'reopen'}),rows=clone(histories(f)),row=rows.flatMap(b=>b.resolutions)[0];assert.ok(row);row.point=clone(provenance(f).journals[4][0].position.point);assert.throws(()=>disputes(f,rows),/Duplicate or native-overlapping auxiliary dispute mutation/);
 const veto=sample({history:'veto'}),bad=clone(histories(veto)),terminal=bad.flatMap(b=>b.repudiations).find(r=>r.terminal.phase===2n);assert.ok(terminal);terminal.terminalPoint=clone(terminal.point);assert.throws(()=>disputes(veto,bad),/point|clock|terminal|repudiation|order/i);
});

test('veto requires its exact original Identity Contest and Cause pair',()=>{
 const f=sample({history:'veto'}),bad=clone(f.identities),owner=bad.find(b=>b.causes.length);assert.ok(owner);owner.causes=[];assert.throws(()=>identities(f,bad),/veto|cause|contest/i);
 const missing=clone(f.identities),id=missing.find(b=>b.contests.length);assert.ok(id);id.contests=[];assert.throws(()=>identities(f,missing),/veto|contest/i);
});

test('pending repudiation pointers and terminal phase changes require original history',()=>{
 const f=sample({history:'pending'}),rows=clone(histories(f)),target=rows.find(b=>b.pending!==Z);assert.ok(target);target.pending=Z;assert.throws(()=>disputes(f,rows),/pending/);
 const terminal=clone(histories(f)),r=terminal.flatMap(b=>b.repudiations).find(r=>r.terminal.phase===1n);r.terminal.phase=5n;assert.throws(()=>disputes(f,terminal),/invalidation|terminal|repudiation|time/i);
});

test('public input wrappers refuse accessor execution and noncanonical ABI allocation',()=>{
 const f=sample();let reads=0;const input={royaltyFreezes:[]};Object.defineProperty(input,'request',{enumerable:true,get(){reads++;return f.request;}});assert.throws(()=>m.normalizeArtistRecoveredMultipleDisputeHydrationInputDraft(input));assert.equal(reads,0);
 const facts={};Object.defineProperty(facts,'envelopes',{enumerable:true,get(){reads++;return envelopeBytes(f);}});assert.throws(()=>disputes(f,histories(f),facts));assert.equal(reads,0);
 const raw=m.encodeArtistRecoveredMultipleDisputeHydrationAttributionHistory(histories(f)[0]);assert.throws(()=>m.decodeArtistRecoveredMultipleDisputeHydrationAttributionHistory(raw+'00'.repeat(32)),/canonical/);
 const malformed='0x'+'ff'.repeat(32);assert.throws(()=>m.decodeArtistRecoveredMultipleDisputeHydrationInventory(malformed),/offset|capacity|trunc|bound|data|ABI/i);
 const huge='0x'+'11'.repeat(1024*1024);assert.throws(()=>disputes(f,histories(f),{envelopes:Array(17).fill(huge)}),/Recovered aggregate allocation capacity/);
});

test('original royalty and no-royalty preparation routes retain their exact selectors and zero-value CALL',()=>{
 for(const royalties of[false,true]){const f=sample({royalties}),target='0x0000000000000000000000000000000000000500',caller='0x0000000000000000000000000000000000000501',call=m.prepareArtistRecoveredMultipleDisputeHydrationCall(target,caller,f.input),method=royalties?'hydrateRecoveredArtistAuthorityWithConsents':'hydrateRecoveredArtistAuthority';assert.equal(call.call.value,0n);assert.equal(call.factsVerified,false);assert.equal(call.call.data,compiledInterfaces.registry.encodeFunctionData(method,royalties?[f.request,f.input.royaltyFreezes]:[f.request]));const data=m.artistRecoveredMultipleDisputeHydrationPreparationCalldata(f.source,f.input);assert.equal(data.slice(0,10),royalties?'0x4925300f':'0x72c84763');const detached=clone(f.input),saved=m.prepareArtistRecoveredMultipleDisputeHydrationCall(target,caller,detached);detached.request.records.authority.collections[0].collectionId++;assert.deepEqual(saved.request,f.request);assert.ok(Object.isFrozen(saved.request.records.authority.collections));}
});
