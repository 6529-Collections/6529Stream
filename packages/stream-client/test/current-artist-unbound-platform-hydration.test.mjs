// Supplied-data proofs only; private Identity/Payout admission and native execution remain mocked.
import test from 'node:test';
import assert from 'node:assert/strict';
import { ParamType, id, keccak256, ZeroAddress } from 'ethers';
import {m,semanticFixture,refresh,coder,T,zero,hash,child,A,H,Z} from './current-artist-unbound-platform-hydration-semantic-fixture.mjs';
import {createArtistRecoveredHydrationCodec} from '../dist/internal/artist-recovered-hydration-codec.js';
import {compiledInterfaces,compiledLibraryValueInterface} from './current-artist-unbound-platform-hydration-source-fixture.mjs';
const clone=structuredClone, samples=new Map();
const sample=options=>{const key=JSON.stringify(options??{});if(!samples.has(key))samples.set(key,semanticFixture(options??{}));return samples.get(key);};
const local=(f,i=4)=>m.artistUnboundPlatformHydrationOwnerProvenance(f.provenance,i);
const prepared=f=>m.normalizeArtistUnboundPlatformHydrationPrepared(f.certificate);
const timeline=f=>m.validateArtistUnboundPlatformHydrationPlatformTimeline(f.platforms[0],local(f),{envelopes:f.envelopes});
const flat=(type,value)=>coder.encode(type.components,type.components.map(c=>value[c.name]));
const recomputeInventory=f=>{const p=f.certificate;f.request.expectedSemanticInventory=hash(['bytes32','uint16','bytes32',child(T.prepared,'query'),child(T.prepared,'data'),child(T.prepared,'timing'),child(T.prepared,'externalGuards')],[id('6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1'),1n,m.artistUnboundPlatformHydrationProvenanceHash(f.provenance),p.query,p.data,p.timing,p.externalGuards]);};
function replaceRow(f,owner,index,raw){const payload=clone(f.payloads[owner]),state=clone(f.states[owner]);state.rows[index]=raw;payload.semanticState=coder.encode(['bytes32','uint16','uint8',T.state],[m.ARTIST_UNBOUND_PLATFORM_HYDRATION_SCHEMA,1n,BigInt(owner),state]);f.certificate.data[owner].typedState=m.encodeArtistUnboundPlatformHydrationOwnerPayload(payload,owner,f.features);recomputeInventory(f);return f;}
function evidence(f){const p=f.certificate,fields=['bytes32','uint16','address','address',m.ARTIST_UNBOUND_PLATFORM_HYDRATION_REQUEST_TUPLE,`${child(T.prepared,'admission').components.find(c=>c.name==='artists').arrayChildren.format('full')}[]`,`${child(T.prepared,'admission').components.find(c=>c.name==='collections').arrayChildren.format('full')}[]`,child(T.prepared,'query'),child(T.prepared,'data'),child(T.prepared,'timing'),child(T.prepared,'externalGuards')];return coder.encode(fields,[m.ARTIST_UNBOUND_PLATFORM_HYDRATION_PROFILE,1n,p.admission.prior,p.admission.sourceCoordinator,f.request,p.admission.artists,p.admission.collections,p.query,p.data,p.timing,p.externalGuards]);}
function rehashEnvelope(f,index,edit){const e=m.decodeArtistUnboundPlatformHydrationArchiveEnvelope(f.envelopes[index]),changed=clone(e);edit(changed);const raw=flat(T.envelope,changed),b=f.platforms[0],row=b.operations[index],era=f.provenance.eras.findIndex(e=>e.originHash===row.originHash),o=f.provenance.origins[era];row.evidence.payloadHash=keccak256(raw);row.evidence.evidenceId=hash(['bytes32','uint256','address','address','uint16','address','bytes32'],[id('6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1'),o.chainId,o.registry,o.coordinator,changed.operation,changed.actor,changed.value]);f.envelopes[index]=raw;return changed;}

test('unbound profile is disjoint and every older profile keeps rejecting its owner headers',()=>{
 const f=sample();assert.equal(m.ARTIST_UNBOUND_PLATFORM_HYDRATION_SCHEMA,id('6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1'));assert.equal(m.ARTIST_UNBOUND_PLATFORM_HYDRATION_FEATURE,4194304n);assert.equal(m.ARTIST_UNBOUND_PLATFORM_HYDRATION_ALLOWED_FEATURES,4194335n);assert.equal(m.ARTIST_UNBOUND_PLATFORM_HYDRATION_ADVERTISED_FEATURES,8388607n);assert.equal(m.ARTIST_UNBOUND_PLATFORM_HYDRATION_KNOWN_FEATURES,33554431n);
 for(const mask of[255n,511n,262175n,524671n,1049087n,2276351n]){const old=createArtistRecoveredHydrationCodec(mask);assert.equal(old.artistRecoveredHydrationOriginHash(f.origin),m.artistUnboundPlatformHydrationOriginHash(f.origin));assert.throws(()=>old.decodeArtistRecoveredHydrationOwnerPayload(f.certificate.data[4].typedState,4),/feature|profile|header/);}
 assert.throws(()=>createArtistRecoveredHydrationCodec(4194304n),/profile|codec/);
});

test('original compiler Platform records and flat Archive carriers retain exact canonical bytes',()=>{
 const f=sample({correction:true}),b=f.platforms[0];
 for(const[name,type,value]of[['Platform',T.platform,b],['Catalogue',child(T.platform,'catalogues').arrayChildren,b.catalogues[0]],['PlatformOperationEvidence',child(T.platform,'operations').arrayChildren,b.operations[0]],['PlatformState',T.pState,b.state],['PlatformClaim',child(T.pClaim,'record'),b.claims[0].record],['PlatformContest',child(T.pContest,'record'),b.contests[0].record],['AttributionClaim',child(T.allegation,'record'),b.allegations[0].record],['PlatformStatus',child(T.platform,'status'),b.status]]){const raw=coder.encode([type],[value]);assert.equal(m[`encodeArtistUnboundPlatformHydration${name}`](value),raw);assert.deepEqual(m[`decodeArtistUnboundPlatformHydration${name}`](raw),value);assert.throws(()=>m[`decodeArtistUnboundPlatformHydration${name}`](`${raw}${'00'.repeat(32)}`),/canonical/);}
 for(const raw of f.envelopes){const e=m.decodeArtistUnboundPlatformHydrationArchiveEnvelope(raw);assert.equal(m.encodeArtistUnboundPlatformHydrationArchiveEnvelope(e),flat(T.envelope,e));assert.equal(m.encodeArtistUnboundPlatformHydrationArchiveEnvelope(e),raw);}
 const claim=m.decodeArtistUnboundPlatformHydrationClaimPayload(m.decodeArtistUnboundPlatformHydrationArchiveEnvelope(f.envelopes[1]).payload);assert.equal(m.encodeArtistUnboundPlatformHydrationClaimPayload(claim),flat(T.claimPayload,claim));
});

test('one zero-Artist Platform declaration has genuine empty-principal checkpoint and anchor',()=>{
 const f=sample(),p=prepared(f);assert.equal(p.admission.artists.length,0);assert.equal(p.admission.collections.length,1);assert.equal(p.query.artistId,Z);assert.deepEqual(p.query.records,p.admission.collections[0].records);assert.equal(f.features,4194304n);assert.equal(p.externalGuards.schema,m.ARTIST_UNBOUND_PLATFORM_HYDRATION_SCHEMA);
 assert.equal(m.decodeArtistUnboundPlatformHydrationEmptyIdentity(f.states[2].rows[0]).configurationHash,f.timing.configurationHash);assert.equal(f.states[2].rows.length,1);assert.equal(f.states[5].rows.length,0);for(const owner of[0,3,6])assert.deepEqual(f.states[owner].rows,['0x']);
 const observed=timeline(f);assert.equal(observed.factsVerified,false);assert.equal(observed.catalogueRowsIndependentlyVerified,false);m.validateArtistUnboundPlatformHydrationInput(f.input,p);
});

test('both claim families, contested and dismissed histories preserve original owner4 transitions',()=>{
 const f=sample({claims:true});prepared(f);const t=timeline(f),b=f.platforms[0];assert.equal(t.state.contestState,2n);assert.equal(b.claims.length,1);assert.equal(b.allegations.length,1);assert.notEqual(b.state.latestClaim,b.latestDisplayClaim);assert.equal(b.latestDisplayClaim,b.allegations[0].record.recordHash);
 for(const raw of f.envelopes){const e=m.decodeArtistUnboundPlatformHydrationArchiveEnvelope(raw);if(e.operation===11n)assert.equal(e.before_[4].recordChainTip,e.after_[4].recordChainTip);else assert.notEqual(e.before_[4].recordChainTip,e.after_[4].recordChainTip);}
 assert.equal(m.validateArtistUnboundPlatformHydrationPlatform(b,local(f)).guards.length,5);
});

test('sustained dispute plus unused correction approval is supported without activating a binding',()=>{
 const f=sample({correction:true});prepared(f);assert.equal(timeline(f).state.contestState,3n);const b=f.platforms[0];assert.notEqual(b.state.correction.recordHash,Z);assert.equal(b.state.correction.correctiveGeneration,0n);assert.equal(b.state.correction.accepted,false);assert.equal(b.status.originalCorrectionRecord,b.state.correction.recordHash);assert.equal(b.continuations.length,0);
 const bad=clone(f);bad.platforms[0].state.correction.correctiveGeneration=1n;refresh(bad);assert.throws(()=>prepared(bad),/correction|continuation|unbound|Platform/i);
});

test('mixed ordinary recovered Artists preserve full journals and independent Platform display history',()=>{
 const f=sample({mixed:true,claims:true}),p=prepared(f);assert.equal(p.admission.artists.length,2);assert.equal(p.admission.collections.length,4);assert.equal(p.admission.before_[2].revision,7n);assert.equal(p.query.artistId,Z);assert.equal(p.query.collectionId,f.collections[0].collectionId);assert.equal(f.features,4194307n);assert.equal(p.externalGuards.schema,id('6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1'));
 for(let i=0;i<7;i++){const s=m.decodeArtistUnboundPlatformHydrationState(f.payloads[i].semanticState,i,local(f,i));assert.deepEqual(s.artists,f.artists);assert.deepEqual(s.collections,f.collections);}
 assert.equal(timeline(f).factsVerified,false);for(const q of p.admission.artists)assert.ok(q.records.length>3);
});

test('repeated original provenance preserves three complete catalogues and era-local empty Identity guards',()=>{
 const f=sample({repeated:true,claims:true});prepared(f);timeline(f);assert.equal(f.provenance.eras.length,3);assert.equal(f.platforms[0].catalogues.length,3);assert.equal(f.features,4194320n);
 const p=local(f,2);assert.equal(m.validateArtistUnboundPlatformHydrationEmptyIdentity(p,[],f.collections,f.states[2].rows[0]).count,0n);assert.deepEqual(p.eras.map(e=>e.lowerRevision),[0n,3n,3n]);assert.deepEqual(p.eras.map(e=>e.checkpoint.replayCount),[1n,5n,7n]);
 const b=clone(f);b.provenance.aliases[2].find(a=>a.originHash===b.provenance.eras[2].originHash&&a.surface===id('identity_authority.replay.one_way_cutover_latch')).admittedAt.environmentHash=b.provenance.eras[0].originHash;assert.throws(()=>refresh(b),/chronology|point|origin|revision|alias|cell/i);
});

test('fully rehashed catalogue removal and substituted origin fail both Prepared and retained evidence',()=>{
 for(const mutate of[b=>{b.catalogues=[];},b=>{b.catalogues[0].originHash=H(98765);},b=>{b.catalogues[0].upper[6]++;}]){const f=clone(sample()),b=clone(f.platforms[0]);mutate(b);replaceRow(f,4,0,coder.encode([T.platform],[b]));assert.throws(()=>prepared(f),/catalogue/);assert.throws(()=>m.decodeArtistUnboundPlatformHydrationProfileEvidence(evidence(f)),/catalogue/);}
});

test('collection scopes, zero-Artist namespaces and mixed proposal origins cannot be rehashed away',()=>{
 // Deliberately bypass admitted semantic encoders: reconstruct original ABI wrappers
 // and every affected inner/outer commitment before invoking the validator under test.
 const rewrap=f=>{
  const fullHash=m.artistUnboundPlatformHydrationProvenanceHash(f.provenance);
  f.certificate.externalGuards.provenanceCommitment=fullHash;
  f.certificate.query={...clone(f.collections[0]),records:clone(f.collections[0].records)};
  for(let owner=0;owner<7;owner++){
   const p=clone(f.payloads[owner]),state=clone(f.states[owner]);p.provenance=local(f,owner);state.collections=clone(f.collections);state.artists=clone(f.artists);
   const commitment=m.artistUnboundPlatformHydrationOwnerProvenanceHash(p.provenance,owner);
   if(owner===4){const b=clone(f.platforms[0]);b.provenance=commitment;state.rows[0]=coder.encode([T.platform],[b]);}
   p.semanticState=coder.encode(['bytes32','uint16','uint8',T.state],[m.ARTIST_UNBOUND_PLATFORM_HYDRATION_SCHEMA,1n,BigInt(owner),state]);
   const last=p.provenance.eras.at(-1),header={profile:m.ARTIST_UNBOUND_PLATFORM_HYDRATION_PROFILE,version:1n,ownerIndex:BigInt(owner),sourceOrigin:last.originHash,priorImportCommitment:last.priorImportCommitment,semanticInventory:keccak256(p.semanticState),provenanceCommitment:commitment,replayAliasesCommitment:m.artistUnboundPlatformHydrationAliasesHash(p.provenance.aliases,owner),requiredFeatures:f.features,semanticRecordCount:BigInt(p.provenance.journal.length),replayAliasCount:BigInt(p.provenance.aliases.length),eraCount:BigInt(p.provenance.eras.length)};
   const payload=coder.encode(['bytes32','uint16',m.ARTIST_UNBOUND_PLATFORM_HYDRATION_OWNER_PAYLOAD_TUPLE],[id('6529STREAM_ARTIST_RECOVERED_OWNER_PAYLOAD_V1'),1n,p]);
   f.certificate.data[owner].typedState=coder.encode(['bytes32','uint16',m.ARTIST_UNBOUND_PLATFORM_HYDRATION_ENVELOPE_TUPLE],[m.artistUnboundPlatformHydrationOwnerTag(owner),1n,{header,payload}]);
  }
  recomputeInventory(f);
 };
 const f=clone(sample());f.collections[0].bindingHash=H(776);rewrap(f);
 assert.throws(()=>prepared(f),/Invalid complete collection partition/);assert.throws(()=>m.decodeArtistUnboundPlatformHydrationProfileEvidence(evidence(f)),/Invalid multiple collection query/);
 const mixed=clone(sample({mixed:true}));mixed.attributions[1].proposalOrigin=H(775);refresh(mixed);assert.throws(()=>prepared(mixed),/Unknown multiple row era/);
 const journal=clone(sample());journal.provenance.journals[4][0].receipt.operation=24n;rewrap(journal);
 assert.throws(()=>prepared(journal),/Invalid unbound Platform occurrence/);assert.throws(()=>m.decodeArtistUnboundPlatformHydrationProfileEvidence(evidence(journal)),/Native journal lies outside complete multiple State/);
});

test('Archive proofs bind actor and proposed Artist even when original native record hash omits them',()=>{
 const f=clone(sample());rehashEnvelope(f,0,e=>{e.actor=A(333);});assert.throws(()=>timeline(f),/Declaration Archive fields/);
 const claim=clone(sample({claims:true}));claim.platforms[0].claims[0].record.proposedArtist=A(334);assert.doesNotThrow(()=>m.validateArtistUnboundPlatformHydrationPlatform(claim.platforms[0],local(claim)));assert.throws(()=>timeline(claim),/Claim Archive fields/);
 const allegation=clone(sample({claims:true}));allegation.platforms[0].allegations[0].record.reasonURI='changed';assert.doesNotThrow(()=>m.validateArtistUnboundPlatformHydrationPlatform(allegation.platforms[0],local(allegation)));assert.throws(()=>timeline(allegation),/Allegation Archive fields/);
});

test('rehashed Archive payloads still require exact governance contexts and original state transition tips',()=>{
 const f=clone(sample({claims:true}));rehashEnvelope(f,3,e=>{const c=m.decodeArtistUnboundPlatformHydrationContestPayload(e.payload);e.payload=m.encodeArtistUnboundPlatformHydrationContestPayload({...c,governance:{...c.governance,actionClass:2n}});});assert.throws(()=>timeline(f),/governance context/);
 const tip=clone(sample({claims:true}));rehashEnvelope(tip,3,e=>{e.after_[4].recordChainTip=H(9090);});assert.throws(()=>timeline(tip),/record|transition|tip/i);
 const snapshot=clone(sample());rehashEnvelope(snapshot,0,e=>{e.after_[0].revision++;});assert.throws(()=>timeline(snapshot),/declaration|snapshot|owner/i);
});

test('complete inventory ordering and original catalogue index remain mandatory supplied facts',()=>{
 const f=clone(sample({claims:true}));[f.envelopes[1],f.envelopes[2]]=[f.envelopes[2],f.envelopes[1]];[f.platforms[0].operations[1],f.platforms[0].operations[2]]=[f.platforms[0].operations[2],f.platforms[0].operations[1]];assert.throws(()=>timeline(f),/order|timeline|Claim|Allegation/);
 const outside=clone(sample());outside.platforms[0].operations[0].evidence.catalogueIndex=outside.platforms[0].catalogues[0].count;assert.throws(()=>timeline(outside),/evidence|order/);
 const empty=clone(sample());empty.envelopes=[];assert.throws(()=>timeline(empty),/incomplete|inventory/i);
});

test('standalone profile evidence authenticates whole replay cells and zero-principal guards',()=>{
 const f=sample();assert.deepEqual(m.decodeArtistUnboundPlatformHydrationProfileEvidence(evidence(f)).request,f.request);
 const cell=clone(f);cell.certificate.data=clone(cell.certificate.data);cell.certificate.data[2].cells[0].touchedRevision++;assert.deepEqual(cell.provenance,f.provenance);recomputeInventory(cell);assert.throws(()=>m.decodeArtistUnboundPlatformHydrationProfileEvidence(evidence(cell)),/replay preimages/);
 const guard=clone(f);guard.certificate.externalGuards.schema=id('6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1');recomputeInventory(guard);assert.throws(()=>m.decodeArtistUnboundPlatformHydrationProfileEvidence(evidence(guard)),/external|guard/i);
 const cap=clone(f);cap.request.expectedCapabilities[4].supportedFeatures=255n;assert.throws(()=>m.decodeArtistUnboundPlatformHydrationProfileEvidence(evidence(cap)),/capability|features/i);
});

test('only original two-argument preparation and zero-value Registry operation60 calls are exposed',()=>{
 const f=sample(),registry=compiledInterfaces.registry,call=m.prepareArtistUnboundPlatformHydrationCall(A(500),A(501),f.input);assert.equal(call.call.data,registry.encodeFunctionData('hydrateRecoveredArtistAuthority',[f.request]));assert.equal(call.call.value,0n);assert.equal(call.factsVerified,false);assert.deepEqual(call.royaltyFreezes,[]);
 const original=compiledLibraryValueInterface('prepared').fragments.find(f=>f.type==='function'&&f.name==='prepare'&&f.inputs.length===2);assert.equal(m.artistUnboundPlatformHydrationPreparationCalldata(f.source,f.input),'0x72c84763'+coder.encode(original.inputs,[f.source,f.request]).slice(2));
 assert.throws(()=>m.normalizeArtistUnboundPlatformHydrationInput({...f.input,royaltyFreezes:['0x']}),/royalty/i);assert.throws(()=>m.normalizeArtistUnboundPlatformHydrationCall({...call,call:{...call.call,data:'0x'}}),/call|data|canonical/i);
 const detached=clone(f.input),saved=m.prepareArtistUnboundPlatformHydrationCall(A(500),A(501),detached);detached.request.records.authority.collections[0].collectionId++;assert.deepEqual(saved.request,f.request);assert.ok(Object.isFrozen(saved.request.records.authority.collections));
});

test('all public wrappers refuse accessors without invoking them and reject sparse or hidden properties',()=>{
 const f=sample();let reads=0;const input={royaltyFreezes:[]};Object.defineProperty(input,'request',{enumerable:true,get(){reads++;return f.request;}});assert.throws(()=>m.normalizeArtistUnboundPlatformHydrationInputDraft(input));assert.equal(reads,0);
 const facts={};Object.defineProperty(facts,'envelopes',{enumerable:true,get(){reads++;return f.envelopes;}});assert.throws(()=>m.validateArtistUnboundPlatformHydrationPlatformTimeline(f.platforms[0],local(f),facts));assert.equal(reads,0);
 const rows=[...f.envelopes];Object.defineProperty(rows,0,{enumerable:true,get(){reads++;return f.envelopes[0];}});assert.throws(()=>m.validateArtistUnboundPlatformHydrationPlatformTimeline(f.platforms[0],local(f),{envelopes:rows}));assert.equal(reads,0);
 const b=clone(f.platforms[0]);Object.defineProperty(b.catalogues,Symbol('extra'),{value:1});assert.throws(()=>m.normalizeArtistUnboundPlatformHydrationPlatform(b),/array|field|property|key/i);
});

test('canonical allocation guards reject oversized aggregate inputs and dirty ABI scalar words',()=>{
 const f=sample(),raw=f.envelopes[0],dirty='0x'+(2n).toString(16).padStart(64,'0')+raw.slice(66);assert.throws(()=>m.decodeArtistUnboundPlatformHydrationArchiveEnvelope(`${raw}${'00'.repeat(32)}`),/canonical/);assert.equal(m.decodeArtistUnboundPlatformHydrationArchiveEnvelope(dirty).version,2n); // raw codec is structural
 const huge='0x'+'11'.repeat(1024*1024);assert.throws(()=>m.validateArtistUnboundPlatformHydrationPlatformTimeline(f.platforms[0],local(f),{envelopes:Array(17).fill(huge)}),/Recovered aggregate allocation capacity/);
 const stateRaw=coder.encode([T.pState],[f.platforms[0].state]),dirtyBool=stateRaw.slice(0,2+18*64)+'2'.padStart(64,'0')+stateRaw.slice(2+19*64);assert.throws(()=>m.decodeArtistUnboundPlatformHydrationPlatformState(dirtyBool),/bool|canonical|word/i);
 const scalar=clone(f.platforms[0]);scalar.state.declaration.declaredAt=1n<<64n;assert.throws(()=>m.normalizeArtistUnboundPlatformHydrationPlatform(scalar),/uint64|range|width/i);
 const empty=m.encodeArtistUnboundPlatformHydrationEmptyIdentity(f.timing);assert.throws(()=>m.decodeArtistUnboundPlatformHydrationEmptyIdentity(`${empty}${'00'.repeat(32)}`),/canonical|timing/i);
});

test('original unbound preparation refuses economics witnesses and extended semantic features',()=>{
 const f=sample(),witness=zero(ParamType.from(m.ARTIST_UNBOUND_PLATFORM_HYDRATION_REQUEST_TUPLE).components[0].components[1].arrayChildren);
 assert.throws(()=>m.normalizeArtistUnboundPlatformHydrationInput({...f.input,request:{...f.request,records:{...f.request.records,witnesses:[witness]}}}),/witness|unsupported|extended/i);
 for(const feature of[32n,64n,128n,256n,512n,2097152n])assert.throws(()=>m.encodeArtistUnboundPlatformHydrationOwnerPayload(f.payloads[4],4,4194304n|feature),/feature|header|unsupported/i);
 const state=clone(f.states[4]);state.collections[0].policies=[{phaseId:H(9),policyHash:H(10)}];assert.throws(()=>m.validateArtistUnboundPlatformHydrationState(4,state,local(f)),/Platform|policy|scope|collection/i);
});
