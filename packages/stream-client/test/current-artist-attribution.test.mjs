import test from 'node:test';
import assert from 'node:assert/strict';
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, id, keccak256, concat } from 'ethers';
import * as p from '../dist/current-artist-attribution.js';
import { toSafeCall } from '../dist/safe.js';
import { fixture, compiledInterfaces } from './current-artist-attribution-source-fixture.mjs';

const abi = AbiCoder.defaultAbiCoder(), Z = ZeroHash, A = n => `0x${BigInt(n).toString(16).padStart(40,'0')}`, H = id;
const C = {chainId:(1n<<200n)+99n,registry:A(1),core:A(2)}, actor=A(3), signer=A(4);
const registry = compiledInterfaces.StreamArtistOnboardingRegistry;
const owner = compiledInterfaces.StreamArtistAttributionLifecycle;
const copy = x => structuredClone(x);
function zero(t) {
  const q=typeof t==='string'?ParamType.from(t):t;
  if(q.baseType==='tuple')return Object.fromEntries(q.components.map(c=>[c.name,zero(c)]));
  if(q.baseType==='array')return Array.from({length:q.arrayLength},()=>zero(q.arrayChildren));
  return q.type==='address'?ZeroAddress:q.type==='bool'?false:q.type==='string'?'':q.type==='bytes'?'0x':q.type.startsWith('bytes')?`0x${'00'.repeat(Number(q.type.slice(5)))}`:0n;
}
function originalType(name) {
  let result;
  function visit(v) { if(!v||typeof v!=='object')return; if(v.internalType===`struct ${name}`&&v.components){result=v;return;} for(const x of Object.values(v))if(typeof x==='object')Array.isArray(x)?x.forEach(visit):visit(x); }
  for(const list of [...Object.values(fixture.abis),...Object.values(fixture.libraryAbis)]){visit(list);if(result)return ParamType.from(result);}
  throw Error(`Missing original type ${name}`);
}
const T={filing:originalType('StreamArtistAttributionDisputeTypes.Filing'),standing:originalType('StreamArtistAttributionDisputeTypes.Standing'),authorization:originalType('StreamArtistOnboardingTypes.Authorization'),binding:originalType('StreamArtistOnboardingTypes.Binding'),head:originalType('StreamArtistAttributionDisputeTypes.Head'),context:originalType('StreamArtistAttributionDisputeTypes.Context'),admission:originalType('StreamArtistAttributionDisputeTypes.Admission'),proof:originalType('StreamArtistOnboardingTypes.SignerApproval'),governance:originalType('StreamArtistIdentityContestTypes.GovernanceWitness'),repudiation:originalType('StreamArtistRepudiationTypes.Record'),repudiationAdmission:originalType('StreamArtistRepudiationTypes.Admission'),guardian:originalType('StreamArtistRepudiationTypes.GuardianProof'),claimEvidence:originalType('StreamArtistPlatformTypes.Evidence'),snapshot:originalType('StreamArtistOnboardingTypes.Snapshot')};
const F = action => ({collectionId:(1n<<190n)+7n,bindingGeneration:(1n<<60n)+9n,disputeAction:action,evidenceHash:action===4n?Z:H('evidence'),reasonHash:H('reason')});
const auth = {nonce:0n,time:999n,signature:'0x1234'};
const standing = {artistId:H('artist'),bindingGeneration:F(1n).bindingGeneration,collaboratorIndex:0n,delegation:Z};
const binding = {...zero(T.binding),artistId:H('artist'),artistAddress:signer,identityRecordHash:H('identity'),bindingHash:H('binding'),generation:F(1n).bindingGeneration,consentMode:1n,accepted:true};
const head = {...zero(T.head),restoreState:2n};
const claim = {recordHash:Z,collectionId:F(1n).collectionId,claimant:actor,evidenceHash:H('evidence'),reasonHash:H('reason'),reasonURI:'ipfs://reason',filedAt:1000n,proposedArtist:signer,previousRecordHash:Z,index:1n};
const record = {recordHash:Z,terms:F(1n),signer,authorityClass:1n,nonce:auth.nonce,recordedAt:1000n,artistId:binding.artistId,bindingHash:binding.bindingHash,disputeRecordHash:H('opening'),previousRecordHash:Z,standing,governanceActionId:Z};
const repudiation = {recordHash:Z,terms:F(4n),artistId:binding.artistId,signer,authorityClass:3n,nonce:0n,stagedAt:1000n,executableAt:1000n+604800n,bindingHash:binding.bindingHash,authorityHead:{principal:signer,authorityClass:3n,latestTransition:H('transition'),latestContest:Z,latestDismissal:Z},capturedGuardianSet:Z,windowRevision:1n};
const resolution={collectionId:F(1n).collectionId,bindingGeneration:F(1n).bindingGeneration,disputeRecordHash:H('opening'),resolution:1n,evidenceHash:H('resolution evidence'),reasonHash:H('resolution reason'),counterStatementRecordHash:Z};
function requests() { return [
  {kind:'fileAttributionClaim',collectionId:claim.collectionId,evidenceHash:claim.evidenceHash,reasonHash:claim.reasonHash,reasonURI:claim.reasonURI},
  {kind:'openAttributionDispute',mode:'signed',filing:F(1n),standing,authorization:auth},
  {kind:'recordCounterStatement',filing:F(3n),standing,authorization:auth},
  {kind:'resolveAttributionDispute',resolution},
  {kind:'revokeAttribution',filing:F(4n),authorization:auth},
  {kind:'vetoAttributionRepudiation',collectionId:claim.collectionId,expectedRepudiation:H('pending'),reasonHash:H('veto')},
  {kind:'cancelAttributionRepudiation',collectionId:claim.collectionId,expectedRepudiation:H('pending')},
  {kind:'executeAttributionRepudiation',collectionId:claim.collectionId,expectedRepudiation:H('pending')},
  {kind:'withdrawAttributionDispute',filing:F(2n),standing,authorization:auth},
]; }
function args(r) { if(r.kind==='fileAttributionClaim')return[r.collectionId,r.evidenceHash,r.reasonHash,r.reasonURI];if(r.kind==='resolveAttributionDispute')return[r.resolution];if('filing'in r)return r.kind==='revokeAttribution'?[r.filing,r.authorization]:[r.filing,r.standing,r.authorization];return r.kind==='vetoAttributionRepudiation'?[r.collectionId,r.expectedRepudiation,r.reasonHash]:[r.collectionId,r.expectedRepudiation]; }

test('attribution exposes nine actual Registry writes and compiler witnessed linked-owner events',()=>{
  const iface=p.artistAttributionInterface(), fragments=iface.fragments.filter(f=>f.type==='function');
  assert.deepEqual(fragments.filter(f=>f.stateMutability==='nonpayable').map(f=>f.name).sort(),requests().map(r=>r.kind).sort());
  for(const f of fragments)assert.equal(f.format('full'),registry.getFunction(f.format('sighash')).format('full'));
  const events=new Interface([...fixture.abis.IStreamArtistAttributionClaims,...fixture.abis.IStreamArtistAttributionDisputeEvents,...fixture.abis.IStreamArtistAttributionRepudiation,...fixture.abis.IStreamArtistDisputeWithdrawal]);
  for(const f of new Interface(p.ARTIST_ATTRIBUTION_EVENTS_ABI).fragments)assert.equal(f.format('full'),events.getEvent(f.format('sighash')).format('full'));
  assert.equal(p.artistAttributionInterface('owner').getEvent('AttributionDisputeWithdrawn').topicHash,events.getEvent('AttributionDisputeWithdrawn').topicHash);
  assert.throws(()=>p.artistAttributionInterface('coordinator'));
});
test('raw codecs retain complete zero records, while exact owned objects and uint widths fail closed',()=>{
  for(const name of ['Filing','Standing','Head','Record','ResolutionRequest','Resolution','Context','Admission','Authorization','Binding','Snapshot','SignerApproval','Claim','AuthorityHead','RepudiationRecord','RepudiationAdmission','Terminal','GuardianProof','Withdrawal','ClaimEvidence','GovernanceWitness','Evidence']){
    const key=name.replace(/[a-z][A-Z]/g,x=>`${x[0]}_${x[1]}`).toUpperCase(), tuple=p[`ARTIST_ATTRIBUTION_${key}_TUPLE`], z=zero(tuple);
    assert.deepEqual(p[`decodeArtistAttribution${name}`](p[`encodeArtistAttribution${name}`](z)),z,name);
  }
  assert.throws(()=>p.normalizeArtistAttributionFiling({...F(1n),bindingGeneration:1n<<64n}));
  assert.throws(()=>p.normalizeArtistAttributionFiling({...F(1n),collectionId:1}));
  assert.throws(()=>p.normalizeArtistAttributionBinding({...binding,accepted:1n}));
  const symbol=F(1n);symbol[Symbol('extra')]=0;assert.throws(()=>p.normalizeArtistAttributionFiling(symbol));
  const accessor=F(1n);Object.defineProperty(accessor,'reasonHash',{get(){throw Error('executed getter');},enumerable:true});assert.throws(()=>p.normalizeArtistAttributionFiling(accessor),/Accessors/);
  assert.throws(()=>p.authenticateArtistAttributionClaimRecord(C,zero(p.ARTIST_ATTRIBUTION_CLAIM_TUPLE)));
});
test('ABI decoding rejects trailing bytes, dirty booleans, offsets and allocation bombs before accepting records',()=>{
  const raw=p.encodeArtistAttributionHead(head);assert.throws(()=>p.decodeArtistAttributionHead(raw+'00'.repeat(32)),/Noncanonical/);
  const dirty=raw.slice(0,2+5*64)+'2'.padStart(64,'0')+raw.slice(2+6*64);assert.throws(()=>p.decodeArtistAttributionHead(dirty));
  const bytes=p.encodeArtistAttributionAuthorization(auth), broken='0x'+'f'.repeat(64)+bytes.slice(66);assert.throws(()=>p.decodeArtistAttributionAuthorization(broken),/bound|offset/);
  assert.throws(()=>p.decodeArtistAttributionAuthorization('0x'+ '00'.repeat(65568)),/bounded/);
  assert.throws(()=>p.decodeArtistAttributionClaim('0x'));
});
test('all nine closed calls exactly match original calldata and unchanged zero-value Safe conversion',()=>{
  const operations=[10n,44n,45n,46n,47n,48n,49n,50n,61n];
  for(const [i,r]of requests().entries()){
    const out=p.prepareArtistAttributionCall(C,actor,r);
    assert.equal(out.call.data,registry.encodeFunctionData(r.kind,args(r)));assert.equal(out.operationId,operations[i]);
    assert.deepEqual(toSafeCall(out.call),{to:C.registry,value:'0',data:out.call.data,operation:0});
    assert.deepEqual(p.normalizeArtistAttributionCall(out),out);assert.equal(out.factsVerified,false);assert.equal(out.requiresGovernance,r.kind==='resolveAttributionDispute');
  }
  assert.throws(()=>p.prepareArtistAttributionCall(C,actor,{kind:'setOwner',target:actor}));
  assert.throws(()=>p.prepareArtistAttributionCall(C,ZeroAddress,requests()[0]));
  for(const r of requests().filter(x=>'filing'in x))assert.throws(()=>p.prepareArtistAttributionCall(C,actor,{...r,filing:{...r.filing,disputeAction:99n}}));
});
test('original dispute EIP712 schema binds every signed field with uint256 nonce and inclusive uint64 deadline',()=>{
  const domain=keccak256(abi.encode(['bytes32','bytes32','bytes32','uint256','address'],[H('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),H('6529StreamArtistRegistry'),H('1'),C.chainId,C.registry]));
  const typehash=H('StreamArtistAttributionDispute(address core,uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash,uint256 nonce,uint64 deadline)');
  for(const action of [1n,2n,3n,4n]){
    const f=F(action), a={nonce:(1n<<255n)+1n,time:(1n<<64n)-1n,signature:'0x'};
    const struct=keccak256(abi.encode(['bytes32','address','uint256','uint64','uint8','bytes32','bytes32','uint256','uint64'],[typehash,C.core,f.collectionId,f.bindingGeneration,action,f.evidenceHash,f.reasonHash,a.nonce,a.time]));
    assert.equal(p.artistAttributionSigningPayload(C,f,a).digest,keccak256(concat(['0x1901',domain,struct])));
  }
  assert.notEqual(p.artistAttributionSigningPayload(C,F(2n),auth).digest,p.artistAttributionSigningPayload(C,F(1n),auth).digest);
  assert.throws(()=>p.artistAttributionSigningPayload(C,{...F(2n),evidenceHash:Z},auth));
  assert.throws(()=>p.artistAttributionSigningPayload(C,F(4n),{...auth,signature:'0x'+'ab'.repeat(4097)}));
});
test('direct authorization is exact caller equality plus empty proof and relayed empty ERC1271 remains undecided',()=>{
  const direct={nonce:0n,time:0n,signature:'0x'};
  assert.equal(p.validateArtistAttributionAuthorization(actor,actor,direct,20n).direct,true);
  assert.throws(()=>p.validateArtistAttributionAuthorization(actor,signer,direct,20n),/deadline/);
  const relayed=p.validateArtistAttributionAuthorization(actor,signer,{...direct,time:20n},20n);assert.equal(relayed.direct,false);assert.equal(relayed.signatureExecutionVerified,false);
  assert.equal(p.validateArtistAttributionAuthorization(actor,actor,{...direct,time:20n},20n).direct,true);
  assert.throws(()=>p.validateArtistAttributionAuthorization(actor,actor,{...direct,time:20n},21n),/deadline/);
  assert.equal(p.validateArtistAttributionAuthorization(actor,actor,{...auth,time:20n},20n).direct,false);
});
test('governed opening carries empty source standing/auth and has no signing payload',()=>{
  const r={kind:'openAttributionDispute',mode:'governance',filing:F(1n),standing:zero(T.standing),authorization:zero(T.authorization)};
  const out=p.prepareArtistAttributionCall(C,actor,r);assert.equal(out.requiresGovernance,true);assert.equal(out.signingPayload,null);assert.equal(out.call.data,registry.encodeFunctionData(r.kind,args(r)));
  assert.throws(()=>p.prepareArtistAttributionCall(C,actor,{...r,standing}));
  assert.throws(()=>p.prepareArtistAttributionCall(C,actor,{...r,authorization:{...r.authorization,time:1n}}));
  assert.throws(()=>p.prepareArtistAttributionCall(C,actor,{...r,mode:'signed'}));
});
test('three native record commitments use the original nine twelve and thirteen words',()=>{
  const expectedClaim=keccak256(abi.encode(['bytes32','uint256','address','address','uint256','address','bytes32','bytes32','uint64'],[H('6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1'),C.chainId,C.registry,C.core,claim.collectionId,claim.claimant,claim.evidenceHash,claim.reasonHash,claim.filedAt]));
  assert.equal(p.artistAttributionClaimRecordHash(C,claim),expectedClaim);
  const f=record.terms, expectedDispute=keccak256(abi.encode(['bytes32','uint256','address','uint256','uint64','uint8','address','uint8','bytes32','bytes32','uint256','uint64'],[H('6529STREAM_ARTIST_DISPUTE_RECORD_V1'),C.chainId,C.registry,f.collectionId,f.bindingGeneration,f.disputeAction,record.signer,record.authorityClass,f.evidenceHash,f.reasonHash,record.nonce,record.recordedAt]));
  assert.equal(p.artistAttributionDisputeRecordHash(C,record),expectedDispute);
  const r=repudiation,expectedRepudiation=keccak256(abi.encode(['bytes32','uint256','address','uint256','uint64','bytes32','address','uint8','bytes32','bytes32','uint256','uint64','uint64'],[H('6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1'),C.chainId,C.registry,r.terms.collectionId,r.terms.bindingGeneration,r.artistId,r.signer,r.authorityClass,r.terms.evidenceHash,r.terms.reasonHash,r.nonce,r.stagedAt,r.executableAt]));
  assert.equal(p.artistAttributionRepudiationRecordHash(C,r),expectedRepudiation);
  assert.equal(p.artistAttributionDisputeRecordHash({...C,core:A(999)},record),expectedDispute);
  assert.notEqual(p.artistAttributionClaimRecordHash({...C,core:A(999)},claim),expectedClaim);
  assert.equal(p.artistAttributionClaimRecordHash(C,{...claim,reasonURI:'changed',index:900n,previousRecordHash:H('older')}),expectedClaim);
  assert.equal(p.artistAttributionDisputeRecordHash(C,{...record,standing:{...standing,artistId:H('other')},previousRecordHash:H('older')}),expectedDispute);
  assert.equal(p.authenticateArtistAttributionClaimRecord(C,{...claim,recordHash:expectedClaim}).recordHash,expectedClaim);
  assert.equal(p.authenticateArtistAttributionDisputeRecord(C,{...record,recordHash:expectedDispute}).recordHash,expectedDispute);
  assert.equal(p.authenticateArtistAttributionRepudiationRecord(C,{...r,recordHash:expectedRepudiation}).recordHash,expectedRepudiation);
  assert.throws(()=>p.authenticateArtistAttributionDisputeRecord(C,{...record,recordHash:expectedClaim}));
});
test('repudiation window floor overflow and authority head preserve original source predicates',()=>{
  assert.equal(p.artistAttributionExecutableAt(1000n,259200n),260200n);
  assert.throws(()=>p.artistAttributionExecutableAt(0n,604800n));assert.throws(()=>p.artistAttributionExecutableAt(1n,259199n));assert.throws(()=>p.artistAttributionExecutableAt((1n<<64n)-1n,259200n));
  const r={...repudiation,recordHash:p.artistAttributionRepudiationRecordHash(C,repudiation)};
  assert.throws(()=>p.authenticateArtistAttributionRepudiationRecord(C,{...r,authorityHead:{...r.authorityHead,principal:actor}}));
  assert.equal(p.artistAttributionAuthorityHeadHash(r.authorityHead),keccak256(abi.encode([originalType('StreamArtistRepudiationTypes.AuthorityHead')],[r.authorityHead])));
});
test('governance contexts independently bind scope state and required resolution class',()=>{
  const f=F(1n),scope=keccak256(abi.encode(['bytes32','uint256','address','address','uint256','uint64'],[H('6529STREAM_ARTIST_DISPUTE_OPEN_SCOPE_V1'),C.chainId,C.registry,C.core,f.collectionId,f.bindingGeneration])),old=keccak256(abi.encode([T.binding,'uint8',T.head],[binding,2n,head]));
  assert.deepEqual(p.artistAttributionOpeningContext(C,f,binding,2n,head),{scopeHash:scope,oldValueHash:old,newValueHash:keccak256(abi.encode(['bytes32','bytes32',T.filing],[scope,old,f])),requiredClass:1n,restoredState:2n});
  assert.equal(p.artistAttributionOpeningContext(C,f,binding,5n,{...head,revocationReason:4n}).restoredState,2n);
  assert.throws(()=>p.artistAttributionOpeningContext(C,f,binding,5n,{...head,revocationReason:3n}));
  const h={...head,open:true,disputeRecordHash:resolution.disputeRecordHash};
  assert.equal(p.artistAttributionResolutionContext(C,resolution,binding,4n,h).requiredClass,1n);
  assert.equal(p.artistAttributionResolutionContext(C,resolution,binding,4n,{...h,reopened:true}).requiredClass,2n);
  assert.equal(p.artistAttributionResolutionContext(C,{...resolution,resolution:2n},binding,4n,h).restoredState,5n);
  assert.throws(()=>p.artistAttributionResolutionContext(C,resolution,binding,4n,{...h,counterStatementRecordHash:H('new counter')}));
  assert.throws(()=>p.artistAttributionOpeningContext(C,f,{...binding,generation:2n},2n,head));
});
test('160-byte claim and 192-byte dispute documents preserve distinct source schemas and parents',()=>{
  const e={schemaVersion:1n,collectionId:claim.collectionId,proposedArtist:ZeroAddress,claimRecordHash:Z,narrativeHash:H('narrative')};
  const raw=abi.encode([T.claimEvidence],[e]);assert.equal(raw.length,322);assert.equal(p.encodeArtistAttributionClaimEvidence(e),raw);assert.deepEqual(p.validateArtistAttributionClaimEvidence(e,claim.collectionId),e);
  assert.throws(()=>p.validateArtistAttributionClaimEvidence({...e,claimRecordHash:H('existing claim')},claim.collectionId));
  const d={schemaVersion:1n,collectionId:claim.collectionId,bindingGeneration:binding.generation,bindingHash:binding.bindingHash,disputeRecordHash:H('opening'),narrativeHash:H('narrative')};
  const expected=abi.encode(['tuple(uint16 schemaVersion,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 disputeRecordHash,bytes32 narrativeHash)'],[d]);
  assert.equal(expected.length,386);assert.equal(p.encodeArtistAttributionEvidence(d),expected);assert.equal(p.artistAttributionEvidenceHash(d),keccak256(expected));
  assert.deepEqual(p.validateArtistAttributionEvidence(d,claim.collectionId,binding,H('opening')),d);
  assert.throws(()=>p.validateArtistAttributionEvidence(d,claim.collectionId,binding,H('other opening')));
  assert.throws(()=>p.decodeArtistAttributionEvidence(raw));
});
test('Archive payload is exactly flat eight-field original encoding with separate evidence identity',()=>{
  const snapshots=Array.from({length:7},()=>zero(T.snapshot)),env={version:1n,configurationHash:H('configuration'),operation:10n,actor,value:H('record'),before_:snapshots,after_:snapshots,payload:'0x123456'};
  const snapshotArray=ParamType.from({type:'tuple[7]',components:T.snapshot.components});
  const expected=abi.encode(['uint16','bytes32','uint16','address','bytes32',snapshotArray,snapshotArray,'bytes'],Object.values(env));
  assert.equal(p.encodeArtistAttributionArchiveEnvelope(env),expected);assert.deepEqual(p.decodeArtistAttributionArchiveEnvelope(expected),env);
  assert.notEqual(abi.encode([p.ARTIST_ATTRIBUTION_ARCHIVE_ENVELOPE_TUPLE],[env]),expected);
  const evidence=keccak256(abi.encode(['bytes32','uint256','address','address','uint16','address','bytes32'],[H('6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1'),C.chainId,C.registry,A(9),10n,actor,env.value]));
  assert.equal(p.artistAttributionEvidenceId(C,A(9),10n,actor,env.value),evidence);assert.equal(p.artistAttributionArchivePayloadHash(env),keccak256(expected));
  assert.throws(()=>p.decodeArtistAttributionArchiveEnvelope(expected+'00'.repeat(32)),/Noncanonical/);
  const sparse=copy(env);delete sparse.before_[0];assert.throws(()=>p.normalizeArtistAttributionArchiveEnvelope(sparse),/dense/);
  const hidden=copy(env);Object.defineProperty(hidden.after_,'hidden',{value:1});assert.throws(()=>p.normalizeArtistAttributionArchiveEnvelope(hidden),/dense/);
  assert.throws(()=>p.encodeArtistAttributionArchiveEnvelope({...env,payload:'0x'+'11'.repeat(24575)}),/bounded/);
});
test('all nine original Archive details roundtrip exact per-operation flat arguments',()=>{
  const common={p:F(1n),standing,a:auth,admission:{binding_:binding,standing,signer,authorityClass:1n,recordedAt:1000n,digest:H('digest')},proof:{signer,digest:H('digest'),direct:false},context:zero(T.context),g:zero(T.governance),head,ep:H('ep'),rp:H('rp')};
  const e={schemaVersion:1n,collectionId:claim.collectionId,proposedArtist:signer,claimRecordHash:Z,narrativeHash:H('narrative')};
  const rows=[
    [{operationId:10n,id:claim.collectionId,evidence:claim.evidenceHash,reason:claim.reasonHash,uri:claim.reasonURI,e,r:e,ep:H('ep'),rp:H('rp')},['uint256','bytes32','bytes32','string',T.claimEvidence,T.claimEvidence,'bytes32','bytes32']],
    ...[44n,45n].map(operationId=>[{operationId,...common,p:F(operationId===44n?1n:3n)},[T.filing,T.standing,T.authorization,T.admission,T.proof,T.context,T.governance,T.head,'bytes32','bytes32']]),
    [{operationId:61n,...Object.fromEntries(Object.entries(common).filter(([k])=>!['context','g'].includes(k))),p:F(2n)},[T.filing,T.standing,T.authorization,T.admission,T.proof,T.head,'bytes32','bytes32']],
    [{operationId:46n,p:resolution,b:binding,context:zero(T.context),g:zero(T.governance),ep:H('ep'),rp:H('rp')},[originalType('StreamArtistAttributionDisputeTypes.ResolutionRequest'),T.binding,T.context,T.governance,'bytes32','bytes32']],
    [{operationId:47n,p:F(4n),a:auth,admission:zero(T.repudiationAdmission),proof:common.proof},[T.filing,T.authorization,T.repudiationAdmission,T.proof]],
    [{operationId:48n,r:repudiation,proof:zero(T.guardian),contest:H('contest')},[T.repudiation,T.guardian,'bytes32']],
    ...[49n,50n].map(operationId=>[{operationId,r:repudiation},[T.repudiation]]),
  ];
  for(const [row,ts]of rows){const {operationId,...body}=row,expected=abi.encode(ts,Object.values(body));assert.equal(p.encodeArtistAttributionArchiveDetail(row),expected,`op${operationId}`);assert.deepEqual(p.decodeArtistAttributionArchiveDetail(operationId,expected),row);assert.throws(()=>p.decodeArtistAttributionArchiveDetail(operationId,expected+'00'.repeat(32)),/Noncanonical/);}
  assert.throws(()=>p.decodeArtistAttributionArchiveDetail(24n,'0x'));
});
test('closed host-specific read plans retain zero/unknown history without inventing admission',()=>{
  for(const host of ['registry','owner'])for(const kind of ['attributionClaimRecord','attributionDisputeRecord','attributionRepudiationRecord','attributionRepudiationTerminal']){
    const out=p.prepareArtistAttributionRead(A(10),{host,kind,recordHash:Z});assert.equal(out.data,(host==='registry'?registry:owner).encodeFunctionData(kind,[Z]));assert.equal(out.factsVerified,false);
  }
  assert.equal(p.prepareArtistAttributionRead(A(10),{host:'owner',kind:'rawPendingRepudiation',collectionId:0n}).data,owner.encodeFunctionData('rawPendingRepudiation',[0n]));
  assert.throws(()=>p.prepareArtistAttributionRead(A(10),{host:'registry',kind:'rawPendingRepudiation',collectionId:0n}),/unavailable/);
  assert.throws(()=>p.prepareArtistAttributionRead(A(10),{host:'owner',kind:'pendingRepudiation',collectionId:0n}),/unavailable/);
  assert.throws(()=>p.prepareArtistAttributionRead(A(10),{host:'registry',kind:'upgrade',data:'0x'}));
});
test('typed read decoding preserves Registry live and owner historical result shapes with canonical bytes',()=>{
  const claimRead=p.prepareArtistAttributionRead(A(10),{host:'registry',kind:'attributionClaimRecord',recordHash:H('claim')});
  const encoded=registry.encodeFunctionResult('attributionClaimRecord',[claim]);
  assert.deepEqual(p.decodeArtistAttributionRead(claimRead,encoded),claim);
  assert.throws(()=>p.decodeArtistAttributionRead(claimRead,encoded+'00'.repeat(32)),/Noncanonical/);
  assert.throws(()=>p.decodeArtistAttributionRead({...claimRead,data:'0x'},encoded),/Contradictory/);
  const pending=p.prepareArtistAttributionRead(A(10),{host:'registry',kind:'pendingRepudiation',collectionId:claim.collectionId});
  assert.deepEqual(p.decodeArtistAttributionRead(pending,registry.encodeFunctionResult('pendingRepudiation',[7n,900n,H('pending')])),{bindingGeneration:7n,executableAt:900n,repudiationRecordHash:H('pending')});
  const history=p.prepareArtistAttributionRead(A(10),{host:'owner',kind:'attributionState',collectionId:claim.collectionId});
  assert.deepEqual(p.decodeArtistAttributionRead(history,owner.encodeFunctionResult('attributionState',[5n,7n])),{state:5n,generation:7n});
  const count=p.prepareArtistAttributionRead(A(10),{host:'owner',kind:'attributionClaims',collectionId:0n});
  assert.deepEqual(p.decodeArtistAttributionRead(count,owner.encodeFunctionResult('attributionClaims',[0n,Z])),{count:0n,latestRecordHash:Z});
  const raw=p.prepareArtistAttributionRead(A(10),{host:'owner',kind:'rawPendingRepudiation',collectionId:1n});
  assert.equal(p.decodeArtistAttributionRead(raw,owner.encodeFunctionResult('rawPendingRepudiation',[H('retained')])),H('retained'));
});
test('immutable plans reject substituted calldata, signing message, schema or value and preserve exact text limits',()=>{
  const r=copy(requests()[1]),out=p.prepareArtistAttributionCall(C,actor,r);r.filing.reasonHash=H('later');assert.equal(out.request.filing.reasonHash,H('reason'));assert.ok(Object.isFrozen(out.request.filing));
  for(const mutation of [x=>x.call.value=1n,x=>x.call.data+='00',x=>x.signingPayload.message.reasonHash=H('changed'),x=>x.signingPayload.domain.chainId=1n,x=>x.signingPayload.types.StreamArtistAttributionDispute[0].name='other',x=>x.operationId=99n]){const v=copy(out);mutation(v);assert.throws(()=>p.normalizeArtistAttributionCall(v));}
  const claimRequest=requests()[0];assert.doesNotThrow(()=>p.prepareArtistAttributionCall(C,actor,{...claimRequest,reasonURI:'é'.repeat(2048)}));
  assert.throws(()=>p.prepareArtistAttributionCall(C,actor,{...claimRequest,reasonURI:'é'.repeat(2049)}));assert.throws(()=>p.prepareArtistAttributionCall(C,actor,{...claimRequest,reasonURI:'\udc00'}));
  assert.doesNotThrow(()=>p.prepareArtistAttributionCall(C,actor,{...requests()[4],authorization:{...auth,signature:'0x'+'ff'.repeat(4096)}}));
});
