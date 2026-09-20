import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as pure from '../dist/current-artist-recovery-adjudication.js';
import * as workflow from '../dist/current-artist-recovery-adjudication-workflow.js';
const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/current-artist-recovery-adjudication-abi.json', import.meta.url), 'utf8'));
const fragments = new Map();
for (const key of ['registry','coordinator','identity','evidence','selection','archive','core','executor','roleRegistry','dormancyReconstruction','actionEvents']) {
  for (const row of fixture.abis[key]) {
    if (['function','event','error'].includes(row.type)) {
      const f = new Interface([row]).fragments[0];
      if (!fragments.has(f.format('sighash'))) fragments.set(f.format('sighash'), row);
    }
  }
}
const abi = new Interface([...fragments.values()]), coder = AbiCoder.defaultAbiCoder();
const addr = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, '0')}`);
const hash = label => id(label), code = '0x6000600055', codeHash = keccak256(code);
const domains = ['binding_lifecycle','collaborator_lifecycle','identity_authority','acceptance_lifecycle','attribution_lifecycle','payout_lifecycle','consent_finality'].map(v => id(`domain:${v}`));
function zero(type) {
  const f = p => p.baseType === 'tuple' ? Object.fromEntries(p.components.map(x => [x.name, f(x)]))
    : p.baseType === 'array' ? Array.from({length: Math.max(p.arrayLength, 0)}, () => f(p.arrayChildren))
    : p.type === 'address' ? ZeroAddress : p.type === 'bool' ? false : p.type === 'bytes' ? '0x'
    : p.type === 'string' ? '' : p.type.startsWith('bytes') ? `0x${'00'.repeat(Number(p.type.slice(5)))}` : 0n;
  return f(ParamType.from(type));
}
function plain(p, v) {
  if (p.baseType === 'tuple') return Object.fromEntries(p.components.map((x,i) => [x.name, plain(x,v[i])]));
  if (p.baseType === 'array') return Array.from(v,x=>plain(p.arrayChildren,x));
  return v;
}
const byFunction = (name, v) => abi.getFunction(name).inputs.map((p,i)=>plain(p,v[i]));
function setup() {
  const pins = Array.from({length:16},(_,i)=>({address:addr(100+i),codeHash}));
  const d = {artist:{chainId:1n,registry:pins[7],coordinator:{address:addr(200),codeHash},components:pins,reads:{address:addr(201),codeHash}},
    evidence:{address:addr(202),codeHash},selection:{address:addr(203),codeHash},governance:{address:addr(204),codeHash}};
  const c = {chainId:1n,registry:pins[7].address,owner:pins[2].address,ownerCodeHash:codeHash,coordinator:d.artist.coordinator.address,
    archive:pins[8].address,core:pins[9].address,mintManager:pins[10].address,evidencePublisher:d.evidence.address,selectionPreparation:d.selection.address};
  const request = {artistId:hash('artist'),newAddress:addr(500),vestedAuthorityClass:1n,expectedCauseHash:hash('cause'),expectedResolutionHash:ZeroHash,
    evidenceHash:hash('evidence'),reasonHash:hash('reason'),supersededRecordHashes:[]};
  const acceptance = {nonce:0n,time:2000000n,signature:'0x'};
  const manifest = {artistId:request.artistId,ownerRevision:5n,causeHash:request.expectedCauseHash,resolutionHash:ZeroHash,executedHead:ZeroHash,
    basis:0n,requestCommitment:pure.artistRecoveryRequestCommitment(request),resolutionEvidenceHash:hash('evidence'),contestedVestings:[],supersededRecordHashes:[]};
  const manifestHash = pure.artistRecoveryResolutionManifestHash(c,manifest);
  const basis = {manifestHash,artistId:request.artistId,ownerCodeHash:codeHash,history:{count:0n,ownerRevision:0n,commitment:ZeroHash},sourceCommitment:hash('source')};
  const progress = {...zero(pure.ARTIST_RECOVERY_SELECTION_PROGRESS_TUPLE),complete:true};
  const selectionKey = pure.artistRecoverySelectionKey(c,basis), selectionResult = pure.artistRecoverySelectionResult(c,basis,progress);
  const context = {...zero(pure.ARTIST_RECOVERY_CONTEXT_TUPLE),scopeHash:pure.artistRecoveryScopeHash(c,request.artistId),oldValueHash:hash('old'),causeHash:request.expectedCauseHash,
    incumbent:addr(501),postContestSeconds:259200n,standingTailSeconds:2592000n,timingRevision:1n};
  context.newValueHash = pure.artistRecoveryIntentHash(context,request,acceptance);
  const role = pure.ARTIST_RECOVERY_ARBITER_ROLE;
  const snapshot = {domainId:domains[2],revision:5n,stateRoot:hash('before-root'),recordChainTip:hash('before-tip')};
  const state = {manifest:true,selection:true,complete:true,revision:5n,rawOverride:null,codeOverride:null,readOverride:null,blockOverride:null,
    associations:new Map(),evidenceStates:new Map(),records:new Map(),vestings:new Map(),archives:new Map(),metadata:new Map(),carriers:new Map(),
    catalogs:new Map([[c.owner,[]],[c.archive,[]]]),native:[],replays:new Map(),calls:[],published:false,status:0n,nonce:0n,batch:null,receipt:null,tx:null,
    effectiveBlock:11,timeOffset:0n,notice:null,afterSnapshot:null};
  const clock = tag => (tag >= 20 ? 400000n : 100n + BigInt(tag)) + state.timeOffset;
  const sourceCause = {...zero(pure.ARTIST_RECOVERY_CAUSE_TUPLE),causeHash:request.expectedCauseHash,
    facts:{...zero(pure.ARTIST_RECOVERY_CAUSE_TUPLE).facts,artistId:request.artistId,kind:1n,authorityClass:1n,priorStatus:1n,incumbent:context.incumbent}};
  function at(tag) { return tag >= state.effectiveBlock; }
  function observed(name, args, to, tag) {
    const post = at(tag), b = state.batch;
    switch(name) {
      case 'reads': return [d.artist.reads.address];
      case 'suiteConfiguration': return [{registry:c.registry,archive:c.archive,owners:pins.slice(0,7).map(x=>x.address),core:c.core,mintManager:c.mintManager,
        roleRegistry:pins[11].address,metadata:pins[12].address,primaryResolver:pins[13].address,royaltyResolver:pins[14].address,primaryRevenueClass:hash('PRIMARY_SALE'),validator:pins[15].address}];
      case 'deploymentChainId': return [1n];
      case 'configurationHash': return [hash('configuration')];
      case 'core': return [c.core];
      case 'mintManager': return [c.mintManager];
      case 'operationCoordinator': case 'coordinator': return [c.coordinator];
      case 'artistRegistry': return [c.registry];
      case 'archiveV2': case 'archive': return [c.archive];
      case 'domainId': return [domains[pins.findIndex(v=>v.address===to)]];
      case 'owner': return [to===d.evidence.address||to===d.selection.address?c.owner:to===pins[11].address?d.governance.address:addr(600)];
      case 'roleRegistry': return [pins[11].address];
      case 'artistWindowAuthority': return [d.governance.address];
      case 'getSatellitePointer': return [c.registry,codeHash,false,hash('ARTIST_REGISTRY'),'0x12345678',pins[11].address,1n,hash('module'),hash('deployment'),1n];
      case 'artistRegistryCutover': return abi.getFunction(name).outputs.map(zero);
      case 'recoveryEvidenceBinding': return [d.evidence.address,codeHash];
      case 'recoverySelectionPreparationBinding': return [d.selection.address,codeHash];
      case 'recoveryExecutorBinding': return [d.governance.address,codeHash];
      case 'ownerStateSnapshotV2': return [post&&state.afterSnapshot?state.afterSnapshot:tag>=state.preparedAtBlock?state.registeredSnapshot:snapshot];
      case 'resolutionManifest': {
        if (!state.manifest && !post) throw Object.assign(Error('unknown'),{code:'CALL_EXCEPTION',data:abi.encodeErrorResult('InvalidRecoveryManifest',[args[0]])});
        return [manifest,codeHash];
      }
      case 'publishResolutionManifest': return [pure.artistRecoveryResolutionManifestHash(c,args[0])];
      case 'publishAppealV2': return [pure.artistRecoveryAppealHash(c,args[0])];
      case 'appealEvidenceV2': {
        if (!state.appeal || (!state.appealBefore&&!post)) throw Object.assign(Error('unknown'),{code:'CALL_EXCEPTION',data:abi.encodeErrorResult('InvalidRecoveryAppealEvidence',[args[0]])});
        return [state.appeal,codeHash];
      }
      case 'recoverySelectionBasisV2': return [basis];
      case 'guardianHistoryState': {
        const association = post ? state.associations.get(args[3]) : state.preparedAssociation;
        return [basis.history,zero(abi.getFunction(name).outputs[1]),association?{artistId:request.artistId,count:0n,historyCommitment:ZeroHash,associationHash:association.associationHash}:zero(pure.ARTIST_RECOVERY_HISTORY_SNAPSHOT_TUPLE),0n];
      }
      case 'selectionV2': return [(state.selection||post)?basis:zero(pure.ARTIST_RECOVERY_SELECTION_BASIS_TUPLE),
        {...progress,complete:state.complete||post}];
      case 'beginSelectionV2': return [selectionKey];
      case 'continueSelectionV2': return [progress];
      case 'requireSelectionV2': if (!state.complete&&!post) throw Error('selection incomplete'); return [selectionResult];
      case 'retainedMemberV2': return [args[1]===addr(700)];
      case 'identityRecoveryContextV2': return [context];
      case 'guardianRecoveryAuthorityRoleV2': return [role];
      case 'operativeEstateDirective': return [ZeroHash];
      case 'identityContestCause': return [state.notice?state.notice.cause:sourceCause];
      case 'dormancyResolutionState': { const n=post&&state.noticeAfter?state.noticeAfter:state.notice; return [n.notice.recordHash,n.phase,n.terminal.recordHash]; }
      case 'dormancyRecord': { const n=post&&state.noticeAfter?state.noticeAfter:state.notice; return [n.notice,n.phase,n.terminal]; }
      case 'identityRecoveryActionState': {
        const association = post ? state.associations.get(args[1])||(tag>=state.preparedAtBlock?state.preparedAssociation:undefined) : (tag>=state.preparedAtBlock?state.preparedAssociation:undefined);
        return [association||zero(pure.ARTIST_RECOVERY_ACTION_ASSOCIATION_TUPLE),{vetoer:ZeroAddress,reasonHash:ZeroHash,vetoedAt:0n},post?state.executed||ZeroHash:ZeroHash,0n];
      }
      case 'identityRecoveryEvidenceState': return [(post?state.evidenceStates.get(args[1]):null)||(tag>=state.preparedAtBlock?state.preparedState:null)||zero(pure.ARTIST_RECOVERY_EVIDENCE_STATE_TUPLE)];
      case 'rotationAcceptanceNonceState': return [post&&!!state.executed,0n];
      case 'replayCell': return [post&&state.replays.get(args[0])||{commitment:ZeroHash,touchedRevision:0n,kind:0n,status:0n}];
      case 'artistNativeReceiptCount': return [post?BigInt(state.native.length):0n];
      case 'artistNativeReceiptAt': return [state.native[Number(args[0])]];
      case 'storedPayloadCount': return [post?BigInt(state.catalogs.get(to).length):0n];
      case 'storedPayloadAt': { const r=state.catalogs.get(to)[Number(args[0])];return [r.pointer,r.payloadType,r.payloadHash]; }
      case 'systemManifestBootstrapState': { const out=abi.getFunction(name).outputs.map(zero); out[0]=true;out[1]=true;return out; }
      case 'governanceActionPolicyState': return [hash('profile'),hash('catalog'),1n,0n];
      case 'minimumDelay': return [259200n];
      case 'isProposer': case 'hasRole': return [true];
      case 'roleMutationState': return [hash('role-mutation'),1n];
      case 'governanceNonce': return [post?state.nonce:0n];
      case 'publishedCallData': return [state.published?addr(800):ZeroAddress];
      case 'publishGovernanceCallData': return [addr(800)];
      case 'scheduledCallData': return [[b.targetCall.data]];
      case 'scheduledCallDataPointer': return [addr(800)];
      case 'scheduleGovernanceBatch': return [b.actionId];
      case 'registerIdentityRecoveryActionV2': return [hash('simulation-association')];
      case 'executeGovernanceBatch': return [];
      case 'governanceAction': return [{status:post?state.status:1n,actionClass:2n,target:b.targetCall.to,value:0n,selector:b.governanceCall.selector,
        callHash:b.callsHash,scopeHash:b.scopeHash,oldValueHash:b.oldValueHash,newValueHash:b.newValueHash,notBefore:b.window.notBefore,expiresAfter:b.window.expiresAfter,
        proposer:addr(600),executor:post?addr(601):ZeroAddress,canceller:ZeroAddress,vetoer:ZeroAddress,reasonHash:b.window.reasonHash,reasonURI:b.window.reasonURI,manifestHash:b.window.manifestHash}];
      case 'terminalFreezeGuardianConfigCommitment': return [hash('guardian-commitment')];
      case 'guardianRecoverySelection': return [selectionResult,zero(pure.ARTIST_RECOVERY_GUARDIAN_RECORD_TUPLE)];
      case 'identityRecoveryRecord': return [state.records.get(args[0])];
      case 'guardianVestingSnapshot': return [state.vestings.get(args[1])];
      case 'identityRecoveryReceipts': return state.pair;
      case 'artistEvidenceBytesV2': return [state.archives.get(args[0])];
      case 'artistEvidenceMetadataV2': return state.metadata.get(args[0]);
      default: throw Error(`Unexpected ${name}`);
    }
  }
  const provider = {
    async getNetwork(){return {chainId:1n};},
    async getBlock(tag){return state.blockOverride?.(tag)||{number:tag,hash:hash(`block${tag}`),timestamp:Number(clock(tag))};},
    async getCode(to,tag){return state.codeOverride?.(to,tag)??state.carriers.get(to)??(to===addr(800)&&state.batch?`0x00${coder.encode(['bytes[]'],[[state.batch.targetCall.data]]).slice(2)}`:code);},
    async call(tx){
      const parsed=abi.parseTransaction({data:tx.data}), name=parsed.name, args=byFunction(name,parsed.args), tag=tx.blockTag;
      state.calls.push({...tx,name,args});
      const override=state.readOverride?.(name,args,tx.to,tag,tx);
      if(override!==undefined)return typeof override==='string'?override:abi.encodeFunctionResult(name,override);
      const result=observed(name,args,tx.to,tag);
      return state.rawOverride?.(name,result)??abi.encodeFunctionResult(name,result);
    },
    async getTransaction(){return state.tx;},async getTransactionReceipt(){return state.receipt;}
  };
  function call(input,caller=addr(600)){return pure.prepareArtistRecoveryAdjudicationCall(c,caller,input);}
  async function capture(input,caller=addr(600)){return workflow.captureArtistRecoveryAdjudication(provider,d,call(input,caller),{blockTag:10});}
  async function gov(){
    const cap=await capture({kind:'identityRecoveryContextV2',request,acceptance,manifestHash});
    const prepared=workflow.prepareArtistRecoveryAdjudicationGovernance(cap,addr(600),0n,{notBefore:300000n+state.timeOffset,expiresAfter:1000000n+state.timeOffset,reasonHash:request.reasonHash,reasonURI:'ipfs://review',manifestHash:hash('system-manifest')});
    state.batch=prepared.batch;return prepared;
  }
  function event(address,name,values){const e=abi.encodeEventLog(abi.getEvent(name),values);return {address,topics:e.topics,data:e.data};}
  function receipt(call,caller,logs,tag=11,safe=false,indexed=false){
    const transactionHash=hash('transaction');
    const safeAbi=new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)']);
    let tx={hash:transactionHash,chainId:1n,from:caller,to:call.to,value:0n,data:call.data,blockNumber:tag,blockHash:hash(`block${tag}`)};
    if(safe){tx={...tx,from:addr(999),to:caller,data:safeAbi.encodeFunctionData('execTransaction',[call.to,0n,call.data,0,0,0,0,ZeroAddress,ZeroAddress,'0x'])};
      const s=new Interface([`event ExecutionSuccess(bytes32 ${indexed?'indexed ':''}txHash,uint256 payment)`]);logs.push({address:caller,...s.encodeEventLog(s.getEvent('ExecutionSuccess'),[hash('safe'),0n])});}
    state.tx=tx;state.receipt={...tx,status:1,logs:logs.map((x,index)=>({...x,index,transactionHash,blockHash:tx.blockHash,blockNumber:tag,removed:false}))};
    return {transactionHash,execution:safe?'safe':'direct'};
  }
  return {d,c,request,acceptance,manifest,manifestHash,basis,progress,selectionKey,selectionResult,context,snapshot,state,provider,call,capture,gov,event,receipt,clock};
}

test('canonical manifest publication is caller-bound, immutable and accepts reviewed reads pin',async()=>{
  const s=setup();s.state.manifest=false;
  const input={kind:'publishResolutionManifest',manifest:structuredClone(s.manifest)};
  const pending=s.capture(input);input.manifest.causeHash=hash('mutated');
  const c=await pending;assert.equal(c.prepared.input.manifest.causeHash,s.manifest.causeHash);assert.ok(Object.isFrozen(c));
  assert.ok(s.state.calls.some(x=>x.name==='reads'));
  assert.equal(c.result[0],s.manifestHash);
  const bad=structuredClone(c);bad.ownerSnapshot.revision='5n';await assert.rejects(workflow.simulateArtistRecoveryAdjudication(s.provider,bad,{blockTag:11}),/Capture changed/);
});

test('publisher first/retry receipts require exact original event or previous-block retention',async()=>{
  for(const retry of [false,true]){
    const s=setup();s.state.manifest=retry;const c=await s.capture({kind:'publishResolutionManifest',manifest:s.manifest});
    const logs=retry?[]:[s.event(s.d.evidence.address,'RecoveryResolutionManifestPublished',[1n,s.manifestHash,s.request.artistId,s.request.expectedCauseHash,5n,codeHash])];
    const opts=s.receipt(c.prepared.call,c.prepared.caller,logs);
    assert.equal((await workflow.inspectArtistRecoveryAdjudicationReceipt(s.provider,c,opts)).retained[0].artistId,s.request.artistId);
    if(!retry){s.state.receipt.logs=[];await assert.rejects(workflow.inspectArtistRecoveryAdjudicationReceipt(s.provider,c,opts),/Expected exactly one/);}
  }
});

test('APPEAL canonical publication is permissionless and schema2, including eventless reuse',async()=>{
  for(const retry of [false,true]){
    const s=setup(),document={resolutionManifestHash:s.manifestHash,hostileFindingsHash:hash('findings'),findings:[{guardianRecordHash:hash('guardian'),parties:[addr(8)]}]};
    s.state.appeal=document;s.state.appealBefore=retry;const c=await s.capture({kind:'publishAppealV2',document});
    const logs=retry?[]:[s.event(s.d.evidence.address,'RecoveryAppealEvidencePublished',[2n,c.prepared.expectedReturnHash,s.manifestHash,codeHash])];
    const opts=s.receipt(c.prepared.call,c.prepared.caller,logs,11,true,true);
    assert.ok((await workflow.inspectArtistRecoveryAdjudicationReceipt(s.provider,c,opts)).events.length);
  }
});

test('complete selection is original live evidence and empty history still needs a completion step',async()=>{
  const s=setup();s.state.selection=false;s.state.complete=false;
  const begin=await s.capture({kind:'beginSelectionV2',manifestHash:s.manifestHash});assert.equal(begin.result[0],s.selectionKey);
  s.state.selection=true;const next=await s.capture({kind:'continueSelectionV2',key:s.selectionKey,maximumRecords:1n});
  assert.equal(next.result[0].complete,true);
  const opts=s.receipt(next.prepared.call,next.prepared.caller,[s.event(s.d.selection.address,'RecoverySelectionProgress',[s.selectionKey,0n,true])]);
  assert.equal((await workflow.inspectArtistRecoveryAdjudicationReceipt(s.provider,next,opts)).selection.result.commitment,s.selectionResult.commitment);
  await assert.rejects(s.capture({kind:'continueSelectionV2',key:s.selectionKey,maximumRecords:65n}),/exceeds64/);
});

test('completed retries revalidate original basis while retained membership uses saved evidence',async()=>{
  const s=setup();const c=await s.capture({kind:'continueSelectionV2',key:s.selectionKey,maximumRecords:2n});
  const opts=s.receipt(c.prepared.call,c.prepared.caller,[]);await workflow.inspectArtistRecoveryAdjudicationReceipt(s.provider,c,opts);
  s.state.readOverride=(name)=>{if(name==='recoverySelectionBasisV2')throw Error('owner anchor changed');};
  await assert.rejects(workflow.simulateArtistRecoveryAdjudication(s.provider,c,{blockTag:11}),/anchor changed/);
  const member=await s.capture({kind:'retainedMemberV2',key:s.selectionKey,actor:addr(700)});assert.equal(member.result[0],true);
});

test('pins, canonical return and concrete-block reorg failures propagate without selector fallback',async()=>{
  const s=setup();s.state.rawOverride=(name,result)=>name==='ownerStateSnapshotV2'?`${abi.encodeFunctionResult(name,result)}00`:undefined;
  await assert.rejects(s.capture({kind:'publishResolutionManifest',manifest:s.manifest}),/Noncanonical|invalid length/);
  s.state.rawOverride=null;s.state.codeOverride=(to)=>to===s.d.selection.address?'0x':undefined;
  await assert.rejects(s.capture({kind:'publishResolutionManifest',manifest:s.manifest}),/runtime/);
  s.state.codeOverride=null;let n=0;s.state.blockOverride=tag=>({number:tag,hash:hash(`changed${n++}`),timestamp:110});
  await assert.rejects(s.capture({kind:'publishResolutionManifest',manifest:s.manifest}),/Pinned block changed/);
});

test('context keeps source authenticated selection and separate new-side nonce lane',async()=>{
  const s=setup();const c=await s.capture({kind:'identityRecoveryContextV2',request:s.request,acceptance:s.acceptance,manifestHash:s.manifestHash});
  assert.equal(c.recovery.acceptanceDigest,pure.artistRecoveryAcceptancePayload(1n,s.c.registry,s.request,s.context.incumbent,s.acceptance).digest);
  assert.ok(s.state.calls.some(x=>x.name==='rotationAcceptanceNonceState'));
  assert.ok(!s.state.calls.some(x=>x.name==='artistAuthorizationState'));
  await assert.rejects(s.capture({kind:'recoverArtistIdentityV2',request:s.request,acceptance:s.acceptance,manifestHash:s.manifestHash}),/Governance operation/);
});

test('original class2 publication, schedule and registration simulations preserve each actual caller',async()=>{
  const s=setup(),g=await s.gov();s.state.published=true;s.state.status=1n;
  for(const stage of ['publish','schedule','register']){
    const o=workflow.prepareArtistRecoveryAdjudicationOperation(g,stage,stage==='schedule'?addr(600):addr(601));
    const out=await workflow.simulateArtistRecoveryAdjudicationOperation(s.provider,o,{blockTag:11});assert.equal(out.operation.caller,o.caller);
  }
  const bad=workflow.prepareArtistRecoveryAdjudicationOperation(g,'register',addr(601));
  await assert.rejects(workflow.simulateArtistRecoveryAdjudicationOperation(s.provider,bad,{blockTag:20}),/registration requires/);
  assert.throws(()=>workflow.prepareArtistRecoveryAdjudicationOperation(g,'schedule',addr(601)),/proposer/);
});
function associationFor(s,g,actor,time=112n) {
  const b=g.batch,state={manifestHash:s.manifestHash,basisCommitment:hash('basis-commitment'),selectionCommitment:s.selectionResult.commitment,
    requiredRole:pure.ARTIST_RECOVERY_ARBITER_ROLE,preparedFromOwnerRevision:5n,associationHash:ZeroHash};
  const a={associationHash:ZeroHash,artistId:s.request.artistId,requestHash:keccak256(pure.encodeArtistRecoveryRequest(s.request)),acceptanceHash:keccak256(pure.encodeArtistRecoveryAuthorization(s.acceptance)),
    contextHash:keccak256(pure.encodeArtistRecoveryContext(s.context)),action:{actionId:b.actionId,callsHash:b.callsHash,callIndex:0n,callDataHash:b.governanceCall.callDataHash,
      executor:b.executor,executorCodeHash:codeHash,proposer:g.proposer,roleMutationHash:hash('role-mutation'),roleRevision:1n,notBefore:b.window.notBefore,expiresAfter:b.window.expiresAfter,minimumDelay:259200n,manifestHash:b.window.manifestHash},
    guardian:zero(pure.ARTIST_RECOVERY_GUARDIAN_RECORD_TUPLE),preparedBy:actor,preparedAt:time,ownerRevision:6n};
  a.associationHash=pure.artistRecoveryPreparationHash(s.c,ZeroHash,s.manifestHash,state.basisCommitment,s.selectionResult,a);
  state.associationHash=a.associationHash;return {a,state};
}
function evidenceFor(s){return {manifestHash:s.manifestHash,manifest:s.manifest,appeal:zero(pure.ARTIST_RECOVERY_APPEAL_DOCUMENT_TUPLE),
  appealAuthority:zero(pure.ARTIST_RECOVERY_APPEAL_AUTHORITY_TUPLE),directive:zero(pure.ARTIST_RECOVERY_DIRECTIVE_RECORD_TUPLE)};}
function saveArchive(s,op,actor,commitment,payload,before,after,tag) {
  const evidenceId=pure.artistRecoveryOperationEvidenceId(s.c,op,actor,commitment);
  const b=Array.from({length:7},()=>zero('(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)'));
  const a=structuredClone(b);b[2]=before;a[2]=after;
  const raw=pure.encodeArtistRecoveryOperationEvidence({schemaVersion:1n,configurationHash:hash('configuration'),operation:op,actor,primaryRecordHash:op===35n?commitment:ZeroHash,before:b,after:a,payload});
  const pointer=addr(900);s.state.archives.set(evidenceId,raw);s.state.carriers.set(pointer,`0x00${raw.slice(2)}`);
  s.state.metadata.set(evidenceId,[keccak256(raw),pointer,BigInt((raw.length-2)/2),BigInt(tag)]);
  return {evidenceId,raw,event:s.event(s.c.archive,'ArtistArchiveEvidenceAppendedV2',[evidenceId,1n,keccak256(raw),pointer,BigInt((raw.length-2)/2)])};
}
function installRegistration(s,g,actor,tag=12){
  const {a,state}=associationFor(s,g,actor,s.clock(tag));
  const after={...s.snapshot,revision:6n,stateRoot:hash('registered-root')};
  s.state.effectiveBlock=tag;s.state.afterSnapshot=after;s.state.status=1n;s.state.published=true;
  s.state.associations.set(g.batch.actionId,a);s.state.evidenceStates.set(g.batch.actionId,state);
  s.state.replays.set(replayKey(s,'identity_authority.replay.recovery_preparation',g.batch.actionId),{commitment:a.associationHash,touchedRevision:6n,kind:1n,status:2n});
  const payload=pure.encodeArtistRecoveryPreparationEvidence({payload:{request:s.request,acceptance:s.acceptance,context:s.context,association:a,count:0n,
    history:{artistId:s.request.artistId,count:0n,historyCommitment:ZeroHash,associationHash:a.associationHash},selection:s.selectionResult,restored:a.guardian,state,evidence:evidenceFor(s)},notice:s.state.notice});
  const archive=saveArchive(s,65534n,actor,a.associationHash,payload,s.snapshot,after,tag);
  const logs=[s.event(s.c.owner,'ArtistIdentityRecoveryPrepared',[1n,s.request.artistId,g.batch.actionId,a.associationHash,a.guardian.recordHash,actor,s.clock(tag)]),archive.event];
  return {a,state,after,archive,logs};
}
function replayKey(s,surface,scope){return keccak256(coder.encode(['bytes32','uint256','address','address','address','address','bytes32','bytes32','bytes32'],
  [id('6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2'),1n,s.c.registry,s.c.coordinator,s.c.archive,s.c.owner,domains[2],id(surface),scope]));}
function installExecution(s,g,tag=20){
  const {a,state}=associationFor(s,g,addr(602));s.state.preparedAtBlock=12;s.state.preparedAssociation=a;s.state.preparedState=state;
  const before={...s.snapshot,revision:6n,stateRoot:hash('registered-root')},after={...before,revision:7n,stateRoot:hash('executed-root'),recordChainTip:hash('executed-tip')};
  s.state.registeredSnapshot=before;s.state.effectiveBlock=tag;s.state.afterSnapshot=after;s.state.status=3n;s.state.published=true;
  const b=g.batch,fields={artistId:s.request.artistId,oldAddress:s.context.incumbent,newAddress:s.request.newAddress,vestedAuthorityClass:1n,
    evidenceHash:s.request.evidenceHash,reasonHash:s.request.reasonHash,supersededRecordsHash:pure.artistRecoverySupersededRecordsHash([]),governanceActionId:b.actionId,recoveredAt:s.clock(tag)};
  const recordHash=pure.artistRecoveryRecordHash(1n,s.c.registry,fields),digest=pure.artistRecoveryAcceptancePayload(1n,s.c.registry,s.request,s.context.incumbent,s.acceptance).digest;
  const governance={actionId:b.actionId,proposer:g.proposer,actionClass:2n,roleMutationHash:a.action.roleMutationHash,roleRevision:1n,
    scopeHash:s.context.scopeHash,oldValueHash:s.context.oldValueHash,newValueHash:s.context.newValueHash};
  const record={recordHash,fields,terms:s.request,executor:b.executor,proposer:g.proposer,governanceWitnessHash:keccak256(pure.encodeArtistRecoveryGovernanceWitness(governance)),
    contextHash:keccak256(pure.encodeArtistRecoveryContext(s.context)),acceptanceDigest:digest,acceptanceNonce:s.acceptance.nonce,acceptanceDeadline:s.acceptance.time,
    postContestSeconds:s.context.postContestSeconds,standingTailSeconds:s.context.standingTailSeconds,timingRevision:1n,delegationEpoch:1n,abandonedTransition:s.context.abandonedTransition};
  const vesting={artistId:s.request.artistId,transitionRecordHash:recordHash,operationId:35n,ownerRevision:7n,executedAt:s.clock(tag),oldAddress:s.context.incumbent,
    newAddress:s.request.newAddress,authorityClass:1n,guardians:s.basis.history,previousTransitionRecordHash:ZeroHash,previousCommitment:ZeroHash,commitment:ZeroHash};
  vesting.commitment=pure.artistRecoveryVestingCommitment(s.c,vesting);s.state.vestings.set(recordHash,vesting);s.state.records.set(recordHash,record);
  s.state.associations.set(b.actionId,a);s.state.evidenceStates.set(b.actionId,state);s.state.executed=recordHash;
  s.state.pair=[hash('primary-receipt'),keccak256(coder.encode(['bytes32','uint16','bytes32','bytes32','bytes32'],['0x05c1b33dc3307a69a2b02b1fdcc96323c6c2dcb072805ca38ec6462ded34ce09',2n,recordHash,
    '0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae',fields.supersededRecordsHash])),hash('secondary-receipt')];
  function consume(surface,types,values,commitment){s.state.replays.set(replayKey(s,surface,keccak256(coder.encode(types,values))),{commitment,touchedRevision:7n,kind:1n,status:2n});}
  consume('identity_authority.replay.recovery_action',['bytes32','bytes32','bytes32','bytes32'],[b.actionId,s.context.scopeHash,s.context.oldValueHash,s.context.newValueHash],recordHash);
  consume('identity_authority.replay.standing_retirement',['bytes32','address','bytes32'],[s.request.artistId,s.context.incumbent,recordHash],recordHash);
  consume('identity_authority.replay.contest_resolution',['bytes32','bytes32'],[s.request.artistId,s.request.expectedCauseHash],recordHash);
  consume('identity_authority.replay.nonce_allocator',['bytes32','bytes32','address','uint256'],[id('rotation_acceptance'),s.request.artistId,s.request.newAddress,s.acceptance.nonce],digest);
  consume('identity_authority.replay.authorization_consumed_digest',['bytes32','bytes32'],[s.request.artistId,digest],digest);
  const logs=[],noticeEvents=[];let noticeAfter=s.state.notice;
  if(s.state.notice?.phase===1n){
    const terminal={...zero(pure.ARTIST_RECOVERY_TERMINAL_TUPLE),noticeHash:s.state.notice.notice.recordHash,actor:s.request.newAddress,authorityClass:1n,observedAt:s.clock(tag)};
    terminal.recordHash=pure.artistRecoveryCancellationHash(s.c,terminal,s.state.notice.notice.priorActivity+1n);
    noticeAfter={...s.state.notice,phase:2n,terminal};
    s.state.replays.set(replayKey(s,'identity_authority.replay.dormancy_cancellation_key',terminal.noticeHash),{commitment:terminal.recordHash,touchedRevision:7n,kind:1n,status:2n});
    s.state.native.push({operation:42n,artistId:s.request.artistId,collectionId:0n,recordHash:terminal.recordHash});
    noticeEvents.push(s.event(s.c.owner,'ArtistDormancyCancelled',[1n,s.request.artistId,terminal.noticeHash,s.request.newAddress,1n,terminal.recordHash]),
      s.event(s.c.owner,'ArtistDormancyCancellationContext',[1n,s.request.artistId,terminal.recordHash,{chainId:1n,registry:s.c.registry,identityOwner:s.c.owner,recorder:s.request.newAddress,recorderAuthorityClass:1n},terminal,s.state.notice.notice.priorActivity+1n]));
  }
  s.state.noticeAfter=noticeAfter;
  s.state.native.push({operation:35n,artistId:s.request.artistId,collectionId:0n,recordHash},{operation:35n,artistId:s.request.artistId,collectionId:0n,recordHash:fields.supersededRecordsHash});
  const preimage=coder.encode(['bytes32','uint256','address',pure.ARTIST_RECOVERY_RECORD_FIELDS_TUPLE],['0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff',1n,s.c.registry,fields]);
  const payloadRows=[{kind:id('ARTIST_SIGNATURE_BUNDLE'),bytes:s.acceptance.signature},{kind:id('ARTIST_RECORD_PREIMAGE'),bytes:preimage}];
  const payloadEvents=[];
  for(const [i,row] of payloadRows.entries()){
    const pointer=addr(910+i),payloadHash=keccak256(row.bytes),saved={pointer,payloadType:row.kind,payloadHash};
    s.state.carriers.set(pointer,`0x00${row.bytes.slice(2)}`);s.state.catalogs.get(s.c.owner).push(saved);s.state.catalogs.get(s.c.archive).push(saved);
    logs.push(s.event(s.c.owner,'ArtistStoredPayload',[1n,BigInt(i),row.kind,payloadHash,pointer]));
    payloadEvents.push(s.event(s.c.archive,'ArtistStoredPayload',[1n,BigInt(i),row.kind,payloadHash,pointer]));
  }
  logs.push(...noticeEvents);
  logs.push(s.event(s.c.owner,'ArtistIdentityRecovered',[2n,s.request.artistId,s.context.incumbent,s.request.newAddress,1n,s.request.evidenceHash,s.request.reasonHash,
    fields.supersededRecordsHash,s.clock(tag),recordHash,b.actionId,[]]));
  const payload=pure.encodeArtistRecoveryExecutionEvidence({payload:{request:s.request,acceptance:s.acceptance,proof:{signer:s.request.newAddress,digest,direct:false},governance,
    context:s.context,record,state,evidence:evidenceFor(s)},noticeBefore:s.state.notice,noticeAfter});
  const archive=saveArchive(s,35n,b.executor,recordHash,payload,before,after,tag);logs.push(archive.event,...payloadEvents);
  logs.push(s.event(b.executor,'GovernanceActionExecuted',[1n,b.actionId,2n,b.targetCall.to,0n,b.governanceCall.selector,b.callsHash,b.scopeHash,b.oldValueHash,b.newValueHash,addr(601),b.window.manifestHash]),
    s.event(b.executor,'GovernanceActionPolicyValidated',[1n,b.actionId,2n,hash('profile'),hash('catalog')]));
  return {record,archive,logs};
}
function addNotice(s,phase){
  s.state.timeOffset=40000000n;s.acceptance.time+=s.state.timeOffset;
  s.context.newValueHash=pure.artistRecoveryIntentHash(s.context,s.request,s.acceptance);
  const cause={...zero(pure.ARTIST_RECOVERY_CAUSE_TUPLE),causeHash:s.request.expectedCauseHash,
    facts:{...zero(pure.ARTIST_RECOVERY_CAUSE_TUPLE).facts,artistId:s.request.artistId,kind:1n,authorityClass:1n,priorStatus:2n,incumbent:s.context.incumbent,enteredAt:40000010n}};
  const notice={...zero(pure.ARTIST_RECOVERY_NOTICE_TUPLE),recordHash:hash('notice'),terms:{artistId:s.request.artistId,evidenceHash:hash('notice-evidence'),reasonURI:'ipfs://notice'},incumbent:s.context.incumbent,
    priorActivity:3n,priorLivenessAt:1n,initiatedAt:40000000n,noticeEndsAt:55552000n,inactivitySeconds:31536000n,noticeSeconds:15552000n,timingRevision:1n,actionId:hash('notice-action'),witnessHash:hash('notice-witness')};
  notice.recordHash=keccak256(coder.encode(['bytes32','uint256','address','address','tuple(bytes32 artistId,bytes32 evidenceHash,string reasonURI)','address','uint64','uint64','uint64','uint64','uint64','uint64','uint256','bytes32','bytes32'],
    [id('6529STREAM_ARTIST_DORMANCY_NOTICE_V1'),1n,s.c.registry,s.c.owner,notice.terms,notice.incumbent,notice.initiatedAt,notice.noticeEndsAt,notice.inactivitySeconds,notice.noticeSeconds,notice.timingRevision,notice.priorLivenessAt,notice.priorActivity,notice.actionId,notice.witnessHash]));
  const terminal=zero(pure.ARTIST_RECOVERY_TERMINAL_TUPLE);
  if(phase===2n){Object.assign(terminal,{noticeHash:notice.recordHash,actor:s.context.incumbent,authorityClass:1n,observedAt:40000090n});terminal.recordHash=pure.artistRecoveryCancellationHash(s.c,terminal,4n);}
  s.state.notice={cause,notice,phase,terminal};
}

test('registration receipt joins auxiliary65534 zero primary word and one owner revision',async()=>{
  const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'register',addr(602));
  const r=installRegistration(s,g,o.caller);const options=s.receipt(o.call,o.caller,r.logs,12);
  const result=await workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options);
  assert.equal(result.association.associationHash,r.a.associationHash);assert.equal(result.record,null);
  assert.equal(pure.decodeArtistRecoveryOperationEvidence(result.archiveBytes).primaryRecordHash,ZeroHash);
  s.state.receipt.logs=s.state.receipt.logs.filter(x=>x.topics[0]!==abi.getEvent('ArtistIdentityRecoveryPrepared').topicHash);
  await assert.rejects(workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options),/Expected exactly one/);
});

test('execution proves durable original35 record, adjacent pair, empty1271 payload and both Safe layouts',async()=>{
  for(const safe of [false,true]){
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'execute',addr(601));
    const r=installExecution(s,g);const options=s.receipt(o.call,o.caller,r.logs,20,safe,safe);
    const result=await workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options);
    assert.equal(result.record.recordHash,r.record.recordHash);assert.deepEqual(result.nativeRecords.map(x=>x.operation),[35n,35n]);
    assert.equal(s.state.catalogs.get(s.c.owner)[0].payloadHash,keccak256('0x'));
  }
});

test('current notice phase1 records42 before adjacent35, phase2 retains exact old terminal',async()=>{
  for(const phase of [1n,2n]){
    const s=setup();addNotice(s,phase);const g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'execute',addr(601));
    const r=installExecution(s,g);const options=s.receipt(o.call,o.caller,r.logs,20,true,false);
    const result=await workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options);
    assert.deepEqual(result.nativeRecords.map(x=>x.operation),phase===1n?[42n,35n,35n]:[35n,35n]);
  }
});
function renumber(s){s.state.receipt.logs.forEach((l,i)=>l.index=i);}
function rewriteArchive(s, r, mutate){
  const e=pure.decodeArtistRecoveryOperationEvidence(r.archive.raw);const changed=structuredClone(e);mutate(changed);
  const raw=pure.encodeArtistRecoveryOperationEvidence(changed),ptr=addr(900),tag=s.state.receipt.blockNumber;
  s.state.archives.set(r.archive.evidenceId,raw);s.state.carriers.set(ptr,`0x00${raw.slice(2)}`);
  s.state.metadata.set(r.archive.evidenceId,[keccak256(raw),ptr,BigInt((raw.length-2)/2),BigInt(tag)]);
  const log=s.state.receipt.logs.find(l=>l.topics[0]===abi.getEvent('ArtistArchiveEvidenceAppendedV2').topicHash);
  Object.assign(log,s.event(s.c.archive,'ArtistArchiveEvidenceAppendedV2',[r.archive.evidenceId,1n,keccak256(raw),ptr,BigInt((raw.length-2)/2)]));
}

test('registration replay and canonical Archive payload/owner omissions are rejected',async()=>{
  for(const mutation of ['replay','payload','owner']){
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'register',addr(602)),r=installRegistration(s,g,o.caller);
    const options=s.receipt(o.call,o.caller,r.logs,12);
    if(mutation==='replay')s.state.replays.clear();
    else rewriteArchive(s,r,e=>{
      if(mutation==='owner')e.after[0]={...s.snapshot};
      else {const decoded=pure.decodeArtistRecoveryPreparationEvidence(e.payload);const v=structuredClone(decoded);v.payload.state.basisCommitment=hash('different');e.payload=pure.encodeArtistRecoveryPreparationEvidence(v);}
    });
    await assert.rejects(workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options),/replay|differ/);
  }
});

test('execution replay omissions,42 native order and both empty-payload event omissions fail closed',async()=>{
  for(const mutation of ['action','retirement','native','payload']){
    const s=setup();addNotice(s,1n);const g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'execute',addr(601)),r=installExecution(s,g);
    const options=s.receipt(o.call,o.caller,r.logs,20);
    if(mutation==='action')s.state.replays.delete(replayKey(s,'identity_authority.replay.recovery_action',keccak256(coder.encode(['bytes32','bytes32','bytes32','bytes32'],[g.batch.actionId,s.context.scopeHash,s.context.oldValueHash,s.context.newValueHash]))));
    if(mutation==='retirement')s.state.replays.delete(replayKey(s,'identity_authority.replay.standing_retirement',keccak256(coder.encode(['bytes32','address','bytes32'],[s.request.artistId,s.context.incumbent,r.record.recordHash]))));
    if(mutation==='native')[s.state.native[0],s.state.native[1]]=[s.state.native[1],s.state.native[0]];
    if(mutation==='payload')s.state.receipt.logs=s.state.receipt.logs.filter(l=>l.topics[0]!==abi.getEvent('ArtistStoredPayload').topicHash);
    renumber(s);await assert.rejects(workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options),/replay|differ|payload additions/);
  }
});

test('Archive synchronization must finish before Governance execution and Safe success',async()=>{
  for(const mutation of ['late-sync','early-safe','failure','delegatecall']){
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'execute',addr(601)),r=installExecution(s,g);
    const options=s.receipt(o.call,o.caller,r.logs,20,true,true);
    if(mutation==='late-sync'){
      const logs=s.state.receipt.logs,rows=logs.filter(l=>l.address===s.c.archive&&l.topics[0]===abi.getEvent('ArtistStoredPayload').topicHash);
      s.state.receipt.logs=logs.filter(l=>!rows.includes(l));s.state.receipt.logs.splice(s.state.receipt.logs.length-1,0,...rows);
    } else if(mutation==='early-safe')s.state.receipt.logs.unshift(s.state.receipt.logs.pop());
    else if(mutation==='failure'){
      const failure=new Interface(['event ExecutionFailure(bytes32 indexed txHash,uint256 payment)']);
      Object.assign(s.state.receipt.logs.at(-1),failure.encodeEventLog(failure.getEvent('ExecutionFailure'),[hash('safe'),0n]));
    } else {
      const safe=new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)']);
      const values=Array.from(safe.decodeFunctionData('execTransaction',s.state.tx.data));values[3]=1n;s.state.tx.data=safe.encodeFunctionData('execTransaction',values);
    }
    renumber(s);await assert.rejects(workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options),/order|Safe|CALL/);
  }
});

test('class2 schedule requires membership before commitment, scheduled then validation; same-block veto retained',async()=>{
  for(const status of [1n,5n]){
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'schedule',addr(600)),b=g.batch;
    s.state.published=true;s.state.nonce=1n;s.state.status=status;
    const logs=[s.event(b.executor,'TerminalFreezeActionMembershipUpdated',[1n,b.context.scopeHash,b.actionId,o.caller,true,1n,true,b.window.notBefore,0n,1n]),
      s.event(b.executor,'TerminalFreezeGuardianConfigCommitted',[1n,b.actionId,hash('guardian-commitment')]),
      s.event(b.executor,'GovernanceActionScheduled',[1n,b.actionId,2n,b.targetCall.to,0n,b.governanceCall.selector,b.callsHash,b.scopeHash,b.oldValueHash,b.newValueHash,b.window.notBefore,b.window.expiresAfter,0n,o.caller,b.window.reasonHash,b.window.reasonURI,b.window.manifestHash]),
      s.event(b.executor,'GovernanceActionPolicyValidated',[1n,b.actionId,1n,hash('profile'),hash('catalog')])];
    const options=s.receipt(o.call,o.caller,logs);
    await workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options);
    s.state.receipt.logs.shift();renumber(s);
    await assert.rejects(workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options),/membership append/);
  }
});

test('eventless governance publication proves separate previous-block runtime and retained pointer',async()=>{
  const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'publish',addr(601));s.state.published=true;
  const options=s.receipt(o.call,o.caller,[],12,true,false);await workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options);
  s.state.codeOverride=(to,tag)=>tag===11&&to===s.d.governance.address?'0x6001':undefined;
  await assert.rejects(workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options),/runtime/);
});
test('execution simulation uses the registered anchor and rejects stale owners and replay before original call',async()=>{
  const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'execute',addr(601));installExecution(s,g);
  s.state.effectiveBlock=21;
  const result=await workflow.simulateArtistRecoveryAdjudicationOperation(s.provider,o,{blockTag:20});assert.equal(result.facts.association.ownerRevision,6n);
  s.state.registeredSnapshot={...s.state.registeredSnapshot,revision:7n};
  await assert.rejects(workflow.simulateArtistRecoveryAdjudicationOperation(s.provider,o,{blockTag:20}),/Owner changed/);
});

test('phase2 retained records allow later owner revisions without using a latest-record head',async()=>{
  const s=setup();addNotice(s,2n);const g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'execute',addr(601)),r=installExecution(s,g);
  const options=s.receipt(o.call,o.caller,r.logs,20);s.state.afterSnapshot={...s.state.afterSnapshot,revision:8n,stateRoot:hash('later-root'),recordChainTip:hash('later-tip')};
  const result=await workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options);assert.equal(result.record.recordHash,r.record.recordHash);
  assert.ok(!s.state.calls.some(x=>x.name==='latestIdentityRecovery'));
});

test('terminal membership cleanup allows original cause3 before target and rejects contradiction',async()=>{
  for(const mutation of ['none','wrong-cause','duplicate','late']){
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryAdjudicationOperation(g,'execute',addr(601)),r=installExecution(s,g),b=g.batch;
    const cleanup=s.event(b.executor,'TerminalFreezeActionMembershipUpdated',[1n,b.context.scopeHash,b.actionId,g.proposer,false,mutation==='wrong-cause'?2n:3n,true,b.window.notBefore,0n,0n]);
    if(mutation==='late')r.logs.splice(1,0,cleanup);else r.logs.unshift(cleanup);
    if(mutation==='duplicate')r.logs.unshift(cleanup);
    const options=s.receipt(o.call,o.caller,r.logs,20);
    if(mutation==='none')await workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options);
    else await assert.rejects(workflow.inspectArtistRecoveryAdjudicationOperationReceipt(s.provider,o,options),/cleanup/);
  }
});

test('APPEAL context retains canonical evidence and the actual executor-owned root role',async()=>{
  const s=setup();s.state.appeal={resolutionManifestHash:s.manifestHash,hostileFindingsHash:hash('hostile'),findings:[{guardianRecordHash:hash('hostile-guardian'),parties:[addr(8)]}]};
  s.state.appealBefore=true;s.request.evidenceHash=pure.artistRecoveryAppealHash(s.c,s.state.appeal);
  s.context.newValueHash=pure.artistRecoveryIntentHash(s.context,s.request,s.acceptance);
  s.state.readOverride=(name)=>name==='guardianRecoveryAuthorityRoleV2'?[pure.ARTIST_RECOVERY_APPEAL_ROLE]
    :name==='governanceRootState'?[addr(600),codeHash,1n]:undefined;
  const c=await s.capture({kind:'identityRecoveryContextV2',request:s.request,acceptance:s.acceptance,manifestHash:s.manifestHash});
  assert.equal(c.recovery.evidence.appealAuthority.root,addr(600));assert.equal(c.recovery.evidence.appeal.resolutionManifestHash,s.manifestHash);
  const old=s.state.readOverride;s.state.readOverride=(name,args,to)=>name==='owner'&&to===s.d.artist.components[11].address?[addr(999)]:old(name);
  await assert.rejects(s.capture({kind:'identityRecoveryContextV2',request:s.request,acceptance:s.acceptance,manifestHash:s.manifestHash}),/differ/);
});
