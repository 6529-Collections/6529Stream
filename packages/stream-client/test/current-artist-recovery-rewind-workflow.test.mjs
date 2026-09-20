import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as legacy from '../dist/current-artist-recovery-adjudication.js';
import * as rewind from '../dist/current-artist-recovery-rewind.js';
const pure = {...legacy,...rewind, artistRecoveryVestingCommitment:rewind.artistRecoveryRewindVestingCommitment, artistRecoveryCancellationHash:rewind.artistRecoveryRewindCancellationHash, artistRecoveryOperationEvidenceId:rewind.artistRecoveryRewindOperationEvidenceId};
import * as workflow from '../dist/current-artist-recovery-rewind-workflow.js';
const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/current-artist-recovery-rewind-abi.json', import.meta.url), 'utf8'));
const fragments = new Map();
for (const key of ['registry','coordinator','identity','payout','evidence','selection','archive','core','executor','roleRegistry','dormancyReconstruction','actionEvents']) {
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
function setup(options={}) {
  const pins = Array.from({length:16},(_,i)=>({address:addr(100+i),codeHash}));
  const d = {artist:{chainId:1n,registry:pins[7],coordinator:{address:addr(200),codeHash},components:pins,reads:{address:addr(201),codeHash}},
    evidence:{address:addr(202),codeHash},selection:{address:addr(203),codeHash},governance:{address:addr(204),codeHash}};
  const c = {chainId:1n,registry:pins[7].address,identityOwner:pins[2].address,identityCodeHash:codeHash,payoutOwner:pins[5].address,payoutCodeHash:codeHash,coordinator:d.artist.coordinator.address,
    archive:pins[8].address,core:pins[9].address,manager:pins[10].address,evidencePublisher:d.evidence.address,selectionPreparation:d.selection.address};
  const request = {artistId:hash('artist'),newAddress:addr(500),vestedAuthorityClass:1n,expectedCauseHash:hash('cause'),expectedResolutionHash:ZeroHash,
    evidenceHash:hash('evidence'),reasonHash:hash('reason'),supersededRecordHashes:[]};
  const acceptance = {nonce:0n,time:2000000n,signature:'0x'};
  const snapshot = {domainId:domains[2],revision:5n,stateRoot:hash('before-root'),recordChainTip:hash('before-tip')};
  const payoutSnapshot = {domainId:domains[5],revision:0n,stateRoot:hash('payout-root'),recordChainTip:hash('payout-tip')};
  const payoutOriginal = {recordHash:ZeroHash,terms:{artistId:request.artistId,payoutAccount:addr(750),previousDesignationRecordHash:ZeroHash},signer:addr(501),authorityClass:1n,nonce:4n,signedAt:80n};
  payoutOriginal.recordHash=rewind.artistRecoveryRewindPayoutRecordHash(c,payoutOriginal);
  if(options.payout)request.supersededRecordHashes=[payoutOriginal.recordHash];
  const manifest = {artistId:request.artistId,identity:{snapshot,receiptCount:0n},payout:{snapshot:payoutSnapshot,receiptCount:0n},causeHash:request.expectedCauseHash,resolutionHash:ZeroHash,executedHead:ZeroHash,
    basis:0n,requestCommitment:pure.artistRecoveryRequestCommitment(request),resolutionEvidenceHash:hash('evidence'),contestedVestings:[],supersededRecords:options.payout?[{kind:4n,recordHash:payoutOriginal.recordHash}]:[]};
  if(options.payout){manifest.payout.receiptCount=1n;payoutSnapshot.revision=1n;}
  let manifestHash = rewind.artistRecoveryRewindManifestHash(c,manifest);
  const basis = {identity:{manifestHash,artistId:request.artistId,ownerCodeHash:codeHash,identity:manifest.identity,
    inventory:zero(rewind.ARTIST_RECOVERY_REWIND_IDENTITY_INVENTORY_TUPLE),guardianHistory:{count:0n,ownerRevision:0n,commitment:ZeroHash},sourceCommitment:hash('source')},
    payoutCodeHash:codeHash,payout:manifest.payout,payoutInventory:zero(rewind.ARTIST_RECOVERY_REWIND_PAYOUT_INVENTORY_TUPLE),sourceCommitment:ZeroHash};
  if(options.payout)basis.payoutInventory.stable={account:payoutOriginal.terms.payoutAccount,recordHash:payoutOriginal.recordHash};
  basis.sourceCommitment=rewind.artistRecoveryRewindSelectionSourceHash(c,basis);
  const progress = {...zero(rewind.ARTIST_RECOVERY_REWIND_SELECTION_PROGRESS_TUPLE),complete:true};
  if(options.payout){progress.payoutProcessed=1n;progress.seenExclusions=1n;progress.payoutScanCommitment=hash('payout-scan');}
  let selectionKey = rewind.artistRecoveryRewindSelectionKey(c,basis);
  const selectionResult = {...zero(rewind.ARTIST_RECOVERY_REWIND_SELECTION_RESULT_TUPLE),sourceKey:selectionKey,manifestHash,
    sourceCommitment:basis.sourceCommitment,inventoryCommitment:rewind.artistRecoveryRewindSelectionInventoryHash(c,basis.identity.inventory,basis.payoutInventory)};
  selectionResult.guardians.sourceKey=selectionKey;
  selectionResult.guardians.commitment=rewind.artistRecoveryRewindGuardianResultHash(c,basis.identity.guardianHistory,selectionResult.guardians);
  selectionResult.commitment=rewind.artistRecoveryRewindSelectionResultHash(c,selectionResult);progress.resultCommitment=selectionResult.commitment;
  const context = {...zero(pure.ARTIST_RECOVERY_CONTEXT_TUPLE),scopeHash:rewind.artistRecoveryRewindScopeHash(c,request.artistId),oldValueHash:hash('old'),causeHash:request.expectedCauseHash,
    incumbent:addr(501),postContestSeconds:259200n,standingTailSeconds:2592000n,timingRevision:1n};
  context.newValueHash = rewind.artistRecoveryRewindIntentHash(context,request,acceptance);
  const role = pure.ARTIST_RECOVERY_ARBITER_ROLE;
  const state = {manifest:true,selection:true,complete:true,revision:5n,rawOverride:null,codeOverride:null,readOverride:null,blockOverride:null,
    associations:new Map(),evidenceStates:new Map(),records:new Map(),vestings:new Map(),archives:new Map(),metadata:new Map(),carriers:new Map(),
    catalogs:new Map([[c.identityOwner,[]],[c.archive,[]]]),native:[],replays:new Map(),calls:[],published:false,status:0n,nonce:0n,batch:null,receipt:null,tx:null,
    effectiveBlock:11,timeOffset:0n,notice:null,afterSnapshot:null,payoutPublished:!!options.payout,identityStatuses:new Map(),recordValues:new Map(),documents:new Map(),guardianEntries:new Map(),standingScopes:new Map(),payoutStatuses:new Map(),continuations:new Map(),beforeNative:[],
    payoutNative:options.payout?[{operation:18n,artistId:request.artistId,collectionId:0n,recordHash:payoutOriginal.recordHash}]:[],
    selectedRows:new Map(options.payout?[[payoutOriginal.recordHash,[4n,{recordHash:payoutOriginal.recordHash,originalDataHash:keccak256(coder.encode([abi.getFunction('designationRecord').outputs[0].format('full'),rewind.ARTIST_RECOVERY_REWIND_PAYOUT_ORIGINAL_TUPLE,'bytes32'],[payoutOriginal.terms,payoutOriginal,rewind.artistRecoveryRewindPayoutOriginalHash(c,payoutOriginal)])),admissionProof:hash('payout-proof'),nonce:4n,nativeIndex:0n},false,true]]]:[])};
  const clock = tag => (tag >= 20 ? 400000n : 100n + BigInt(tag)) + state.timeOffset;
  const sourceCause = {...zero(pure.ARTIST_RECOVERY_CAUSE_TUPLE),causeHash:request.expectedCauseHash,
    facts:{...zero(pure.ARTIST_RECOVERY_CAUSE_TUPLE).facts,artistId:request.artistId,kind:1n,authorityClass:1n,priorStatus:1n,incumbent:context.incumbent}};
  function at(tag) { return tag >= state.effectiveBlock; }
  function observed(name, args, to, tag) {
    const post = at(tag), b = state.batch;
    switch(name) {
      case 'reads': return [d.artist.reads.address];
      case 'suiteConfiguration': return [{registry:c.registry,archive:c.archive,owners:pins.slice(0,7).map(x=>x.address),core:c.core,mintManager:c.manager,
        roleRegistry:pins[11].address,metadata:pins[12].address,primaryResolver:pins[13].address,royaltyResolver:pins[14].address,primaryRevenueClass:hash('PRIMARY_SALE'),validator:pins[15].address}];
      case 'deploymentChainId': return [1n];
      case 'configurationHash': return [hash('configuration')];
      case 'core': return [c.core];
      case 'mintManager': return [c.manager];
      case 'operationCoordinator': case 'coordinator': return [c.coordinator];
      case 'artistRegistry': return [c.registry];
      case 'archiveV2': case 'archive': return [c.archive];
      case 'domainId': return [domains[pins.findIndex(v=>v.address===to)]];
      case 'owner': return [to===d.evidence.address||to===d.selection.address?c.identityOwner:to===pins[11].address?d.governance.address:addr(600)];
      case 'roleRegistry': return [pins[11].address];
      case 'artistWindowAuthority': return [d.governance.address];
      case 'getSatellitePointer': return [c.registry,codeHash,false,hash('ARTIST_REGISTRY'),'0x12345678',pins[11].address,1n,hash('module'),hash('deployment'),1n];
      case 'artistRegistryCutover': return abi.getFunction(name).outputs.map(zero);
      case 'recoveryRewindEvidenceBinding': return [d.evidence.address,codeHash];
      case 'recoveryRewindSelectionBinding': return [d.selection.address,codeHash];
      case 'recoveryExecutorBinding': return [d.governance.address,codeHash];
      case 'ownerStateSnapshotV2': return [to===c.payoutOwner?(post&&state.payoutAfter||payoutSnapshot):post&&state.afterSnapshot?state.afterSnapshot:tag>=state.preparedAtBlock?state.registeredSnapshot:snapshot];
      case 'resolutionManifestV3': {
        if (!state.manifest && !post) throw Object.assign(Error('unknown'),{code:'CALL_EXCEPTION',data:abi.encodeErrorResult('InvalidRecoveryRewindManifest',[args[0]])});
        return [manifest,codeHash,codeHash];
      }
      case 'publishResolutionManifestV3': return [rewind.artistRecoveryRewindManifestHash(c,args[0])];
      case 'publishAppealV3': return [rewind.artistRecoveryRewindAppealHash(c,args[0])];
      case 'appealEvidenceV3': {
        if (!state.appeal || (!state.appealBefore&&!post)) throw Object.assign(Error('unknown'),{code:'CALL_EXCEPTION',data:abi.encodeErrorResult('InvalidRecoveryRewindAppeal',[args[0]])});
        return [state.appeal,codeHash,codeHash];
      }
      case 'recoveryRewindBasisV3': return [basis.identity];
      case 'payoutOwner': return [c.payoutOwner];
      case 'recoveryRewindInventoryV3': return [post&&state.identityInventory||basis.identity.inventory];
      case 'payoutRewindInventoryV3': return [post&&state.payoutInventory||basis.payoutInventory];
      case 'preparationSealV3': return [tag>=state.preparedAtBlock?state.seal:zero(rewind.ARTIST_RECOVERY_REWIND_PREPARATION_SEAL_TUPLE)];
      case 'selectionResultV3': return [selectionResult];
      case 'selectionRecordV3': return state.selectedRows.get(args[1]);
      case 'guardianSetRecord': case 'successorDesignationRecord': case 'estateDirectiveRecord':
      case 'identityRevisionRecord': case 'stewardSanctionGrantRecord': case 'standingRevocationRecord': return [state.recordValues.get(args[0])];
      case 'estateDirectivePayload': case 'identityDocumentBytes': return [state.documents.get(args[0])];
      case 'recoveryRecordStatusV3': return [post&&state.identityStatuses.get(args[1])||zero(rewind.ARTIST_RECOVERY_REWIND_STATUS_TUPLE)];
      case 'recoveryRevisionContinuationV3': case 'recoveryStandingContinuationV3': case 'recoveryCapabilityContinuationV3': return [state.continuations.get(args[0])];
      case 'recoveryStandingScopeV3': return state.standingScopes.get(args[1]);
      case 'identity': return [{...zero(abi.getFunction(name).outputs[0]),identityRecordHash:hash('registration-document')}];
      case 'designationRecord': return [payoutOriginal.terms];
      case 'payoutRecoveryRecordStatusV3': return [post&&state.payoutStatuses.get(args[0])||zero(rewind.ARTIST_RECOVERY_REWIND_STATUS_TUPLE)];
      case 'payoutRecoveryContinuationV3': return [state.continuations.get(args[0])];
      case 'payoutOriginalV3': if(!state.payoutPublished&&!post)throw Object.assign(Error('unknown'),{code:'CALL_EXCEPTION',data:abi.encodeErrorResult('InvalidRecoveryPayoutOriginal',[args[0]])}); return [payoutOriginal,rewind.artistRecoveryRewindPayoutOriginalHash(c,payoutOriginal),codeHash,codeHash];
      case 'publishPayoutOriginalV3': return [rewind.artistRecoveryRewindPayoutOriginalHash(c,args[0])];
      case 'guardianHistoryState': {
        const association = post ? state.associations.get(args[3]) : state.preparedAssociation;
        return [basis.identity.guardianHistory,state.guardianEntries.get(args[1])||zero(abi.getFunction(name).outputs[1]),association?{artistId:request.artistId,count:basis.identity.guardianHistory.count,historyCommitment:basis.identity.guardianHistory.commitment,associationHash:association.associationHash}:zero(pure.ARTIST_RECOVERY_HISTORY_SNAPSHOT_TUPLE),0n];
      }
      case 'selectionV3': return [(state.selection||post)?basis:zero(rewind.ARTIST_RECOVERY_REWIND_SELECTION_BASIS_TUPLE),
        state.complete||post?progress:zero(rewind.ARTIST_RECOVERY_REWIND_SELECTION_PROGRESS_TUPLE)];
      case 'beginSelectionV3': return [selectionKey];
      case 'continueSelectionV3': return [progress];
      case 'requireSelectionV3': if (!state.complete&&!post) throw Error('selection incomplete'); return [selectionResult];
      case 'retainedMemberV3': return [args[1]===addr(700)];
      case 'identityRecoveryContextV3': return [context];
      case 'guardianRecoveryAuthorityRoleV3': return [role];
      case 'operativeEstateDirective': return [ZeroHash];
      case 'identityContestCause': return [state.notice?state.notice.cause:sourceCause];
      case 'dormancyResolutionState': { const n=post&&state.noticeAfter?state.noticeAfter:state.notice; return [n.notice.recordHash,n.phase,n.terminal.recordHash]; }
      case 'dormancyRecord': { const n=post&&state.noticeAfter?state.noticeAfter:state.notice; return [n.notice,n.phase,n.terminal]; }
      case 'identityRecoveryActionState': {
        const association = post ? state.associations.get(args[1])||(tag>=state.preparedAtBlock?state.preparedAssociation:undefined) : (tag>=state.preparedAtBlock?state.preparedAssociation:undefined);
        return [association||zero(pure.ARTIST_RECOVERY_ACTION_ASSOCIATION_TUPLE),{vetoer:ZeroAddress,reasonHash:ZeroHash,vetoedAt:0n},post?state.executed||ZeroHash:ZeroHash,0n];
      }
      case 'identityRecoveryEvidenceStateV3': return [(post?state.evidenceStates.get(args[1]):null)||(tag>=state.preparedAtBlock?state.preparedState:null)||zero(rewind.ARTIST_RECOVERY_REWIND_EVIDENCE_STATE_TUPLE)];
      case 'rotationAcceptanceNonceState': return [post&&!!state.executed,0n];
      case 'replayCell': return [post&&state.replays.get(args[0])||{commitment:ZeroHash,touchedRevision:0n,kind:0n,status:0n}];
      case 'artistNativeReceiptCount': return [to===c.payoutOwner?BigInt(state.payoutNative?.length||0):post?BigInt(state.native.length):BigInt(state.beforeNative?.length||0)];
      case 'artistNativeReceiptAt': return [(to===c.payoutOwner?state.payoutNative:post?state.native:state.beforeNative)?.[Number(args[0])]];
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
      case 'registerIdentityRecoveryActionV3': return [hash('simulation-association')];
      case 'executeGovernanceBatch': return [];
      case 'governanceAction': return [{status:post?state.status:1n,actionClass:2n,target:b.targetCall.to,value:0n,selector:b.governanceCall.selector,
        callHash:b.callsHash,scopeHash:b.scopeHash,oldValueHash:b.oldValueHash,newValueHash:b.newValueHash,notBefore:b.window.notBefore,expiresAfter:b.window.expiresAfter,
        proposer:addr(600),executor:post?addr(601):ZeroAddress,canceller:ZeroAddress,vetoer:ZeroAddress,reasonHash:b.window.reasonHash,reasonURI:b.window.reasonURI,manifestHash:b.window.manifestHash}];
      case 'terminalFreezeGuardianConfigCommitment': return [hash('guardian-commitment')];
      case 'guardianRecoverySelection': return [selectionResult.guardians,zero(pure.ARTIST_RECOVERY_GUARDIAN_RECORD_TUPLE)];
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
      const parsed=abi.parseTransaction({data:tx.data}), name=parsed.name, args=parsed.fragment.inputs.map((p,i)=>plain(p,parsed.args[i])), tag=tx.blockTag;
      state.calls.push({...tx,name,args});
      const override=state.readOverride?.(name,args,tx.to,tag,tx);
      if(override!==undefined)return typeof override==='string'?override:abi.encodeFunctionResult(parsed.fragment,override);
      const result=observed(name,args,tx.to,tag);
      return state.rawOverride?.(name,result)??abi.encodeFunctionResult(parsed.fragment,result);
    },
    async getTransaction(){return state.tx;},async getTransactionReceipt(){return state.receipt;}
  };
  function call(input,caller=addr(600)){return rewind.prepareArtistRecoveryRewindCall(c,caller,input);}
  async function capture(input,caller=addr(600)){return workflow.captureArtistRecoveryRewind(provider,d,call(input,caller),{blockTag:10});}
  async function gov(){
    const cap=await capture({kind:'identityRecoveryContextV3',request,acceptance,manifestHash});
    const prepared=workflow.prepareArtistRecoveryRewindGovernance(cap,addr(600),0n,{notBefore:300000n+state.timeOffset,expiresAfter:1000000n+state.timeOffset,reasonHash:request.reasonHash,reasonURI:'ipfs://review',manifestHash:hash('system-manifest')});
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
  const out={d,c,request,acceptance,manifest,manifestHash,basis,progress,selectionKey,selectionResult,context,snapshot,payoutSnapshot,payoutOriginal,state,provider,call,capture,gov,event,receipt,clock};
  out.refresh=()=>{
    manifest.supersededRecords.sort((a,b)=>a.recordHash.localeCompare(b.recordHash));
    request.supersededRecordHashes=manifest.supersededRecords.map(x=>x.recordHash).sort();
    manifest.requestCommitment=pure.artistRecoveryRequestCommitment(request);
    manifest.identity.receiptCount=BigInt(state.beforeNative.length);manifest.payout.receiptCount=BigInt(state.payoutNative.length);
    manifestHash=rewind.artistRecoveryRewindManifestHash(c,manifest);out.manifestHash=manifestHash;
    basis.identity.manifestHash=manifestHash;basis.sourceCommitment=rewind.artistRecoveryRewindSelectionSourceHash(c,basis);
    selectionKey=rewind.artistRecoveryRewindSelectionKey(c,basis);out.selectionKey=selectionKey;
    Object.assign(selectionResult,{sourceKey:selectionKey,manifestHash,sourceCommitment:basis.sourceCommitment,
      inventoryCommitment:rewind.artistRecoveryRewindSelectionInventoryHash(c,basis.identity.inventory,basis.payoutInventory)});
    selectionResult.guardians.sourceKey=selectionKey;
    selectionResult.guardians.commitment=rewind.artistRecoveryRewindGuardianResultHash(c,basis.identity.guardianHistory,selectionResult.guardians);
    selectionResult.commitment=rewind.artistRecoveryRewindSelectionResultHash(c,selectionResult);
    Object.assign(progress,{identityProcessed:manifest.identity.receiptCount,payoutProcessed:manifest.payout.receiptCount,
      guardiansProcessed:basis.identity.guardianHistory.count,seenExclusions:(1n<<BigInt(manifest.supersededRecords.length))-1n,resultCommitment:selectionResult.commitment});
    context.newValueHash=rewind.artistRecoveryRewindIntentHash(context,request,acceptance);
  };
  return out;
}

function associationFor(s,g,actor,time=112n) {
  const b=g.batch;
  const a={...zero(pure.ARTIST_RECOVERY_ACTION_ASSOCIATION_TUPLE),artistId:s.request.artistId,requestHash:keccak256(pure.encodeArtistRecoveryRequest(s.request)),
    acceptanceHash:keccak256(pure.encodeArtistRecoveryAuthorization(s.acceptance)),contextHash:keccak256(pure.encodeArtistRecoveryContext(s.context)),
    action:{actionId:b.actionId,callsHash:b.callsHash,callIndex:0n,callDataHash:b.governanceCall.callDataHash,executor:b.executor,executorCodeHash:codeHash,
      proposer:g.proposer,roleMutationHash:hash('role-mutation'),roleRevision:1n,notBefore:b.window.notBefore,expiresAfter:b.window.expiresAfter,minimumDelay:259200n,manifestHash:b.window.manifestHash},
    preparedBy:actor,preparedAt:time,ownerRevision:6n};
  a.associationHash=rewind.artistRecoveryRewindPreparationHash(s.c,ZeroHash,s.manifestHash,hash('policy'),s.selectionResult,a);
  const state={manifestHash:s.manifestHash,sourceKey:s.selectionKey,sourceCommitment:s.basis.sourceCommitment,selectionCommitment:s.selectionResult.commitment,
    policyCommitment:hash('policy'),requiredRole:pure.ARTIST_RECOVERY_ARBITER_ROLE,effectiveCapabilities:4095n,associationHash:a.associationHash,
    sources:{identityBefore:s.manifest.identity,payout:s.manifest.payout,associationHash:a.associationHash}};
  return {a,state};
}
function evidenceFor(s){return {manifestHash:s.manifestHash,manifest:s.manifest,appeal:zero(rewind.ARTIST_RECOVERY_REWIND_APPEAL_DOCUMENT_TUPLE),
  appealAuthority:zero(pure.ARTIST_RECOVERY_APPEAL_AUTHORITY_TUPLE),facts:{payout:s.manifest.payout,payoutInventory:s.basis.payoutInventory,selection:s.selectionResult}};}
function noticeBytes(n){return n?pure.encodeArtistRecoveryNoticeEvidence(n):'0x';}
function saveArchive(s,op,actor,commitment,payload,before,after,tag) {
  const evidenceId=pure.artistRecoveryOperationEvidenceId(s.c,op,actor,commitment);
  const b=Array.from({length:7},()=>zero('(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)'));
  const a=structuredClone(b);b[2]=before;a[2]=after;b[5]=s.payoutSnapshot;a[5]=s.state.payoutAfter||s.payoutSnapshot;
  const raw=pure.encodeArtistRecoveryOperationEvidence({schemaVersion:1n,configurationHash:hash('configuration'),operation:op,actor,primaryRecordHash:op===35n?commitment:ZeroHash,before:b,after:a,payload});
  const pointer=addr(900);s.state.archives.set(evidenceId,raw);s.state.carriers.set(pointer,`0x00${raw.slice(2)}`);
  s.state.metadata.set(evidenceId,[keccak256(raw),pointer,BigInt((raw.length-2)/2),BigInt(tag)]);
  return {evidenceId,raw,event:s.event(s.c.archive,'ArtistArchiveEvidenceAppendedV2',[evidenceId,1n,keccak256(raw),pointer,BigInt((raw.length-2)/2)])};
}
function sealFor(s,g,a,state,after) {
  const seal={manifestHash:s.manifestHash,sourceKey:s.selectionKey,actionId:g.batch.actionId,associationHash:a.associationHash,
    identityBefore:s.manifest.identity,identityAfterPreparation:after,payout:s.manifest.payout,evidenceStateHash:keccak256(rewind.encodeArtistRecoveryRewindEvidenceState(state)),commitment:ZeroHash};
  seal.commitment=rewind.artistRecoveryRewindPreparationSealHash(s.c,seal);return seal;
}
function installRegistration(s,g,actor,tag=12){
  const {a,state}=associationFor(s,g,actor,s.clock(tag));
  const after={...s.snapshot,revision:6n,stateRoot:hash('registered-root')};
  s.state.effectiveBlock=tag;s.state.preparedAtBlock=tag;s.state.afterSnapshot=after;s.state.status=1n;s.state.published=true;
  s.state.seal=sealFor(s,g,a,state,after);
  s.state.associations.set(g.batch.actionId,a);s.state.evidenceStates.set(g.batch.actionId,state);
  s.state.replays.set(replayKey(s,'identity_authority.replay.recovery_preparation',g.batch.actionId),{commitment:a.associationHash,touchedRevision:6n,kind:1n,status:2n});
  const payload=rewind.encodeArtistRecoveryRewindPreparationPayload({tag:id('6529STREAM_ARTIST_RECOVERY_REWIND_PREPARATION_EVIDENCE_V3'),
    request:s.request,acceptance:s.acceptance,context:s.context,association:a,state,evidence:evidenceFor(s),preparationSeal:s.state.seal,notice:noticeBytes(s.state.notice)});
  const archive=saveArchive(s,65534n,actor,a.associationHash,payload,s.snapshot,after,tag);
  const logs=[s.event(s.c.identityOwner,'ArtistIdentityRecoveryPrepared',[1n,s.request.artistId,g.batch.actionId,a.associationHash,a.guardian.recordHash,actor,s.clock(tag)]),
    s.event(s.c.selectionPreparation,'RecoveryRewindPreparationSealed',[s.selectionKey,g.batch.actionId,s.state.seal.commitment]),archive.event];
  return {a,state,after,archive,logs};
}
function replayKey(s,surface,scope){return keccak256(coder.encode(['bytes32','uint256','address','address','address','address','bytes32','bytes32','bytes32'],
  [id('6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2'),1n,s.c.registry,s.c.coordinator,s.c.archive,s.c.identityOwner,domains[2],id(surface),scope]));}
function installPayout(s,g,recordHash,identityAfter){
  if(!s.manifest.supersededRecords.some(r=>r.kind===4n))return {mutation:ZeroHash,event:null};
  const b=g.batch,e=rewind.artistRecoveryRewindEnvironment(s.c),E=rewind.ARTIST_RECOVERY_REWIND_ENVIRONMENT_TUPLE,artistId=s.request.artistId;
  const after={...s.payoutSnapshot,revision:s.payoutSnapshot.revision+1n,stateRoot:hash('payout-after')};s.state.payoutAfter=after;
  const stable={account:ZeroAddress,recordHash:ZeroHash},candidate={...stable};
  const continuation={artistId,recoveryRecordHash:recordHash,actionId:b.actionId,manifestHash:s.manifestHash,planCommitment:s.selectionResult.commitment,
    identityOwnerRevision:identityAfter.revision,stable,candidate,releasedChildRecordHash:s.payoutOriginal.recordHash,
    previousContinuationHash:ZeroHash,payoutOwnerRevision:after.revision,continuationHash:ZeroHash};
  continuation.continuationHash=rewind.artistRecoveryRewindPayoutContinuationHash(s.c,continuation);s.state.continuations.set(continuation.continuationHash,continuation);
  const status={artistId,kind:4n,recoveryRecordHash:recordHash,actionId:b.actionId,planCommitment:s.selectionResult.commitment};
  s.state.payoutStatuses.set(s.payoutOriginal.recordHash,status);
  const statuses=keccak256(coder.encode(['bytes32','uint16',E,'bytes32','bytes32',rewind.ARTIST_RECOVERY_REWIND_STATUS_TUPLE],
    [id('6529STREAM_ARTIST_RECOVERY_PAYOUT_STATUS_V3'),3n,e,ZeroHash,s.payoutOriginal.recordHash,status]));
  s.state.payoutInventory={stable,candidate,supersessionStateCommitment:statuses,continuationCommitment:continuation.continuationHash};
  const key=(surface,scope)=>keccak256(coder.encode(['bytes32','uint256','address','address','address','address','bytes32','bytes32','bytes32'],
    [id('6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2'),1n,s.c.registry,s.c.coordinator,s.c.archive,s.c.payoutOwner,domains[5],id(surface),scope]));
  const chainKey=key('payout_lifecycle.replay.designation_chain',keccak256(coder.encode(['bytes32'],[artistId])));
  const recoveryKey=key('payout_lifecycle.replay.recovery_rewind',recordHash);
  const cell={commitment:ZeroHash,touchedRevision:after.revision,kind:3n,status:1n},spent={commitment:s.selectionResult.commitment,touchedRevision:after.revision,kind:1n,status:2n};
  s.state.replays.set(chainKey,cell);s.state.replays.set(recoveryKey,spent);
  const plan={artistId,manifestHash:s.manifestHash,actionId:b.actionId,associationHash:s.state.preparedAssociation.associationHash,
    contextHash:keccak256(pure.encodeArtistRecoveryContext(s.context)),recoveryRecordHash:recordHash,planCommitment:s.selectionResult.commitment,
    source:s.manifest.payout,beforeInventory:s.basis.payoutInventory,selected:s.selectionResult.payout,supersededPayoutRecordHashes:[s.payoutOriginal.recordHash]};
  const action=keccak256(coder.encode(['bytes32','uint16',E,rewind.ARTIST_RECOVERY_REWIND_PAYOUT_APPLY_TUPLE],[id('6529STREAM_ARTIST_RECOVERY_PAYOUT_APPLY_V3'),3n,e,plan]));
  const state=keccak256(coder.encode([rewind.ARTIST_RECOVERY_REWIND_PAYOUT_TUPLE,rewind.ARTIST_RECOVERY_REWIND_PAYOUT_TUPLE,'bytes32',rewind.ARTIST_RECOVERY_REWIND_PAYOUT_CONTINUATION_TUPLE],[stable,candidate,statuses,continuation]));
  const cellType='(bytes32 commitment,uint64 touchedRevision,uint8 kind,uint8 status)';
  const replay=keccak256(coder.encode(['bytes32',cellType,cellType,'bytes32',cellType],[chainKey,zero(cellType),cell,recoveryKey,spent]));
  const mutation=keccak256(coder.encode(['bytes32','bytes32','bytes32'],[action,state,replay]));
  return {mutation,event:s.event(s.c.payoutOwner,'ArtistPayoutRecoveryRewindApplied',[3n,artistId,recordHash,b.actionId,s.selectionResult.commitment,continuation.continuationHash,mutation])};
}
// These RPC fixtures exercise compiler-exact joins; original selection admission remains the simulated contract call.
function addIdentityFamilies(s,{class3=false}={}) {
  const methods=['guardianSetRecord','successorDesignationRecord','estateDirectiveRecord','identityRevisionRecord',null,'stewardSanctionGrantRecord','standingRevocationRecord'];
  const operations=[28n,36n,37n,25n,18n,19n,51n], hashes=new Map();
  for(const kind of [0,2,1,3,5,6]){
    const name=methods[kind],type=abi.getFunction(name).outputs[0],record=zero(type);
    Object.assign(record,{recordHash:hash(`family-${kind}`),signer:s.context.incumbent,authorityClass:1n,nonce:BigInt(kind+1),signedAt:90n});
    if(record.terms)record.terms.artistId=s.request.artistId;else record.artistId=s.request.artistId;
    let data;
    if(kind===0){Object.assign(record.terms,{guardians:[addr(700)],approvalThreshold:1n,minContestSeconds:259200n});}
    if(kind===1){Object.assign(record.terms,{successor:s.request.newAddress,successorKind:1n,grantedCapabilities:4095n,directiveHash:hashes.get(2)});}
    if(kind===2){Object.assign(record.terms,{grantedCapabilities:4095n,directivePayloadHash:keccak256('0x1234')});s.state.documents.set(record.recordHash,'0x1234');}
    if(kind===3){
      Object.assign(record,{previousRecordHash:hash('registration-document'),revisedRecordHash:keccak256('0x5678'),identityRecordURI:'ipfs://revision',displayName:'Revised'});
      record.recordHash=keccak256(coder.encode(['bytes32','uint256','address','bytes32','bytes32','bytes32','address','uint8','uint256','uint64'],
        [id('6529STREAM_ARTIST_IDENTITY_REVISION_RECORD_V1'),1n,s.c.registry,s.request.artistId,record.previousRecordHash,record.revisedRecordHash,record.signer,1n,record.nonce,record.signedAt]));
      s.state.documents.set(record.revisedRecordHash,'0x5678');
    }
    if(kind===5){Object.assign(record.terms,{granted:false,statementHash:hash('withdrawn-steward-grant')});}
    if(kind===6){Object.assign(record.terms,{revokedAddress:addr(760),reasonHash:hash('standing-reason'),retiredTransitionRecordHash:hash('retirement')});}
    hashes.set(kind,record.recordHash);s.state.recordValues.set(record.recordHash,record);
    data=kind===2||kind===3?coder.encode([type.format('full'),'bytes'],[record,kind===2?'0x1234':'0x5678']):coder.encode([type.format('full')],[record]);
    const selected={recordHash:record.recordHash,originalDataHash:keccak256(data),admissionProof:hash(`admission-${kind}`),nonce:record.nonce,nativeIndex:BigInt(s.state.beforeNative.length)};
    const excluded=kind===3||kind===6;
    s.state.selectedRows.set(record.recordHash,[BigInt(kind),selected,!excluded,true]);
    s.state.beforeNative.push({operation:operations[kind],artistId:s.request.artistId,collectionId:0n,recordHash:record.recordHash});
    if(excluded)s.manifest.supersededRecords.push({kind:BigInt(kind),recordHash:record.recordHash});
    if(kind===0){
      const entry={artistId:s.request.artistId,index:1n,ownerRevision:1n,recordHash:record.recordHash,recordDataHash:selected.originalDataHash,previousCommitment:ZeroHash,commitment:ZeroHash};
      entry.commitment=keccak256(coder.encode(['bytes32','uint256','address','address','bytes32','uint64','uint64','bytes32','bytes32','bytes32'],
        [id('6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1'),1n,s.c.registry,s.c.identityOwner,entry.artistId,1n,1n,entry.recordHash,entry.recordDataHash,ZeroHash]));
      s.state.guardianEntries.set(1n,entry);Object.assign(s.basis.identity.guardianHistory,{count:1n,ownerRevision:1n,commitment:entry.commitment});
      Object.assign(s.selectionResult.guardians,{selectedRecordHash:record.recordHash,selectedDataHash:selected.originalDataHash,selectedNonce:record.nonce});
      s.basis.identity.inventory.guardians.stable=record.recordHash;
    }
    const families={1:['designation','designations'],2:['directive','directives'],3:['identityRevision','revisions'],5:['sanctionGrant','sanctionGrants']};
    if(families[kind]){const [result,inventory]=families[kind];s.basis.identity.inventory[inventory].stable=record.recordHash;
      if(!excluded)s.selectionResult[result].operative=selected;}
    if(kind===6){
      const row={priorAddress:record.terms.revokedAddress,retirementHash:record.terms.retiredTransitionRecordHash,expectedRevocationRecordHash:record.recordHash,
        retainedRevocation:zero(rewind.ARTIST_RECOVERY_REWIND_SELECTED_RECORD_TUPLE),independentJudgmentHash:ZeroHash,continuationCommitment:ZeroHash};
      s.selectionResult.standing=[row];s.state.standingScopes.set(row.priorAddress,[row.retirementHash,row.expectedRevocationRecordHash,ZeroHash,ZeroHash]);
    }
  }
  if(class3){s.request.vestedAuthorityClass=3n;s.state.activation=hash('activation');s.state.beforeNative.push({operation:40n,artistId:s.request.artistId,collectionId:0n,recordHash:s.state.activation});}
  s.refresh();return hashes;
}
function installIdentityEffects(s,g,recordHash,after){
  const b=g.batch,artistId=s.request.artistId,result=s.selectionResult,env=rewind.artistRecoveryRewindEnvironment(s.c);
  let statuses=s.basis.identity.inventory.supersessionStateCommitment;
  for(const ref of s.manifest.supersededRecords){
    if(ref.kind===4n)continue;
    const status={artistId,kind:ref.kind,recoveryRecordHash:recordHash,actionId:b.actionId,planCommitment:result.commitment};s.state.identityStatuses.set(ref.recordHash,status);
    if(ref.kind!==0n)statuses=keccak256(coder.encode(['bytes32','bytes32',rewind.ARTIST_RECOVERY_REWIND_STATUS_TUPLE],[statuses,ref.recordHash,status]));
  }
  statuses=keccak256(coder.encode(['bytes32','uint16',rewind.ARTIST_RECOVERY_REWIND_ENVIRONMENT_TUPLE,'bytes32','bytes32','bytes32','bytes32','bytes32'],
    [id('6529STREAM_ARTIST_RECOVERY_REWIND_IDENTITY_STATUSES_V3'),3n,env,artistId,recordHash,b.actionId,result.commitment,statuses]));
  const inventory=structuredClone(s.basis.identity.inventory);inventory.supersessionStateCommitment=statuses;
  inventory.guardians={stable:result.guardians.selectedRecordHash,candidate:ZeroHash};
  for(const [field,selection] of [['designations','designation'],['directives','directive'],['revisions','identityRevision'],['sanctionGrants','sanctionGrant']])
    inventory[field]={stable:result[selection].operative.recordHash,candidate:result[selection].retainedCandidateRecordHash};
  const revision=s.manifest.supersededRecords.find(x=>x.kind===3n);
  if(revision){
    const value={artistId,recoveryRecordHash:recordHash,actionId:b.actionId,planCommitment:result.commitment,stableRevisionRecordHash:ZeroHash,
      stableDocumentHash:hash('registration-document'),resolvedChildRecordHash:revision.recordHash,ownerRevision:after.revision,continuationHash:ZeroHash};
    value.continuationHash=rewind.artistRecoveryRewindRevisionContinuationHash(s.c,value);s.state.continuations.set(value.continuationHash,value);inventory.revisionContinuationHash=value.continuationHash;
  }
  for(const selected of result.standing){
    const value={artistId,priorAddress:selected.priorAddress,retirementHash:selected.retirementHash,recoveryRecordHash:recordHash,actionId:b.actionId,
      planCommitment:result.commitment,retainedRevocationRecordHash:ZeroHash,supersededRevocationRecordHash:selected.expectedRevocationRecordHash,ownerRevision:after.revision,continuationHash:ZeroHash};
    value.continuationHash=rewind.artistRecoveryRewindStandingContinuationHash(s.c,value);s.state.continuations.set(value.continuationHash,value);
  }
  if(s.request.vestedAuthorityClass===3n){
    const value={artistId,originalActivationRecordHash:s.state.activation,originalActivationCapabilities:4095n,recoveryRecordHash:recordHash,actionId:b.actionId,
      manifestHash:s.manifestHash,planCommitment:result.commitment,designationRecordHash:result.designation.operative.recordHash,
      pairedDirectiveRecordHash:result.directive.operative.recordHash,forbiddenDirectiveRecordHash:result.directive.operative.recordHash,
      authorityAddress:s.request.newAddress,effectiveCapabilities:s.state.preparedState.effectiveCapabilities,commitment:ZeroHash};
    value.commitment=rewind.artistRecoveryRewindCapabilityContinuationHash(s.c,value);s.state.continuations.set(recordHash,value);
  }
  s.state.identityInventory=inventory;
}
function installExecution(s,g,tag=20){
  const {a,state}=associationFor(s,g,addr(602));s.state.preparedAtBlock=12;s.state.preparedAssociation=a;s.state.preparedState=state;
  const before={...s.snapshot,revision:s.snapshot.revision+1n,stateRoot:hash('registered-root')},after={...before,revision:7n,stateRoot:hash('executed-root'),recordChainTip:hash('executed-tip')};
  s.state.registeredSnapshot=before;s.state.seal=sealFor(s,g,a,state,before);s.state.effectiveBlock=tag;s.state.afterSnapshot=after;s.state.status=3n;s.state.published=true;
  const b=g.batch,fields={artistId:s.request.artistId,oldAddress:s.context.incumbent,newAddress:s.request.newAddress,vestedAuthorityClass:s.request.vestedAuthorityClass,
    evidenceHash:s.request.evidenceHash,reasonHash:s.request.reasonHash,supersededRecordsHash:pure.artistRecoverySupersededRecordsHash(s.request.supersededRecordHashes),governanceActionId:b.actionId,recoveredAt:s.clock(tag)};
  const recordHash=pure.artistRecoveryRecordHash(1n,s.c.registry,fields),digest=pure.artistRecoveryAcceptancePayload(1n,s.c.registry,s.request,s.context.incumbent,s.acceptance).digest;
  const governance={actionId:b.actionId,proposer:g.proposer,actionClass:2n,roleMutationHash:a.action.roleMutationHash,roleRevision:1n,
    scopeHash:s.context.scopeHash,oldValueHash:s.context.oldValueHash,newValueHash:s.context.newValueHash};
  const record={recordHash,fields,terms:s.request,executor:b.executor,proposer:g.proposer,governanceWitnessHash:keccak256(pure.encodeArtistRecoveryGovernanceWitness(governance)),
    contextHash:keccak256(pure.encodeArtistRecoveryContext(s.context)),acceptanceDigest:digest,acceptanceNonce:s.acceptance.nonce,acceptanceDeadline:s.acceptance.time,
    postContestSeconds:s.context.postContestSeconds,standingTailSeconds:s.context.standingTailSeconds,timingRevision:1n,delegationEpoch:1n,abandonedTransition:s.context.abandonedTransition};
  const vesting={artistId:s.request.artistId,transitionRecordHash:recordHash,operationId:35n,ownerRevision:7n,executedAt:s.clock(tag),oldAddress:s.context.incumbent,
    newAddress:s.request.newAddress,authorityClass:s.request.vestedAuthorityClass,guardians:s.basis.identity.guardianHistory,previousTransitionRecordHash:ZeroHash,previousCommitment:ZeroHash,commitment:ZeroHash};
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
    noticeEvents.push(s.event(s.c.identityOwner,'ArtistDormancyCancelled',[1n,s.request.artistId,terminal.noticeHash,s.request.newAddress,1n,terminal.recordHash]),
      s.event(s.c.identityOwner,'ArtistDormancyCancellationContext',[1n,s.request.artistId,terminal.recordHash,{chainId:1n,registry:s.c.registry,identityOwner:s.c.identityOwner,recorder:s.request.newAddress,recorderAuthorityClass:1n},terminal,s.state.notice.notice.priorActivity+1n]));
  }
  s.state.noticeAfter=noticeAfter;
  s.state.native.unshift(...s.state.beforeNative);
  s.state.native.push({operation:35n,artistId:s.request.artistId,collectionId:0n,recordHash},{operation:35n,artistId:s.request.artistId,collectionId:0n,recordHash:fields.supersededRecordsHash});
  const preimage=coder.encode(['bytes32','uint256','address',pure.ARTIST_RECOVERY_RECORD_FIELDS_TUPLE],['0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff',1n,s.c.registry,fields]);
  const payloadRows=[{kind:id('ARTIST_SIGNATURE_BUNDLE'),bytes:s.acceptance.signature},{kind:id('ARTIST_RECORD_PREIMAGE'),bytes:preimage}];
  const payloadEvents=[];
  for(const [i,row] of payloadRows.entries()){
    const pointer=addr(910+i),payloadHash=keccak256(row.bytes),saved={pointer,payloadType:row.kind,payloadHash};
    s.state.carriers.set(pointer,`0x00${row.bytes.slice(2)}`);s.state.catalogs.get(s.c.identityOwner).push(saved);s.state.catalogs.get(s.c.archive).push(saved);
    logs.push(s.event(s.c.identityOwner,'ArtistStoredPayload',[1n,BigInt(i),row.kind,payloadHash,pointer]));
    payloadEvents.push(s.event(s.c.archive,'ArtistStoredPayload',[1n,BigInt(i),row.kind,payloadHash,pointer]));
  }
  logs.push(...noticeEvents);
  logs.push(s.event(s.c.identityOwner,'ArtistIdentityRecovered',[2n,s.request.artistId,s.context.incumbent,s.request.newAddress,s.request.vestedAuthorityClass,s.request.evidenceHash,s.request.reasonHash,
    fields.supersededRecordsHash,s.clock(tag),recordHash,b.actionId,s.request.supersededRecordHashes]));
  installIdentityEffects(s,g,recordHash,after);
  const payoutEffect=installPayout(s,g,recordHash,after);
  if(payoutEffect.event)logs.push(payoutEffect.event);
  const payload=rewind.encodeArtistRecoveryRewindExecutionPayload({tag:id('6529STREAM_ARTIST_RECOVERY_REWIND_EXECUTION_EVIDENCE_V3'),
    request:s.request,acceptance:s.acceptance,proof:{signer:s.request.newAddress,digest,direct:false},governance,
    context:s.context,record,state,evidence:evidenceFor(s),payoutMutation:payoutEffect.mutation,noticeBefore:noticeBytes(s.state.notice),noticeAfter:noticeBytes(noticeAfter)});
  const archive=saveArchive(s,35n,b.executor,recordHash,payload,before,after,tag);logs.push(archive.event,...payloadEvents);
  logs.push(s.event(b.executor,'GovernanceActionExecuted',[1n,b.actionId,2n,b.targetCall.to,0n,b.governanceCall.selector,b.callsHash,b.scopeHash,b.oldValueHash,b.newValueHash,addr(601),b.window.manifestHash]),
    s.event(b.executor,'GovernanceActionPolicyValidated',[1n,b.actionId,2n,hash('profile'),hash('catalog')]));
  return {record,archive,logs};
}
function addNotice(s,phase){
  s.state.timeOffset=40000000n;s.acceptance.time+=s.state.timeOffset;
  s.context.newValueHash=rewind.artistRecoveryRewindIntentHash(s.context,s.request,s.acceptance);
  const cause={...zero(pure.ARTIST_RECOVERY_CAUSE_TUPLE),causeHash:s.request.expectedCauseHash,
    facts:{...zero(pure.ARTIST_RECOVERY_CAUSE_TUPLE).facts,artistId:s.request.artistId,kind:1n,authorityClass:1n,priorStatus:2n,incumbent:s.context.incumbent,enteredAt:40000010n}};
  const notice={...zero(pure.ARTIST_RECOVERY_NOTICE_TUPLE),recordHash:hash('notice'),terms:{artistId:s.request.artistId,evidenceHash:hash('notice-evidence'),reasonURI:'ipfs://notice'},incumbent:s.context.incumbent,
    priorActivity:3n,priorLivenessAt:1n,initiatedAt:40000000n,noticeEndsAt:55552000n,inactivitySeconds:31536000n,noticeSeconds:15552000n,timingRevision:1n,actionId:hash('notice-action'),witnessHash:hash('notice-witness')};
  notice.recordHash=keccak256(coder.encode(['bytes32','uint256','address','address','tuple(bytes32 artistId,bytes32 evidenceHash,string reasonURI)','address','uint64','uint64','uint64','uint64','uint64','uint64','uint256','bytes32','bytes32'],
    [id('6529STREAM_ARTIST_DORMANCY_NOTICE_V1'),1n,s.c.registry,s.c.identityOwner,notice.terms,notice.incumbent,notice.initiatedAt,notice.noticeEndsAt,notice.inactivitySeconds,notice.noticeSeconds,notice.timingRevision,notice.priorLivenessAt,notice.priorActivity,notice.actionId,notice.witnessHash]));
  const terminal=zero(pure.ARTIST_RECOVERY_TERMINAL_TUPLE);
  if(phase===2n){Object.assign(terminal,{noticeHash:notice.recordHash,actor:s.context.incumbent,authorityClass:1n,observedAt:40000090n});terminal.recordHash=pure.artistRecoveryCancellationHash(s.c,terminal,4n);}
  s.state.notice={cause,notice,phase,terminal};
}


test('V3 publication captures exact caller, both runtime pins and immutable input before await',async()=>{
  const s=setup();s.state.manifest=false;
  const input={kind:'publishResolutionManifestV3',manifest:structuredClone(s.manifest)},pending=s.capture(input);
  input.manifest.causeHash=hash('mutated');const c=await pending;
  assert.equal(c.result[0],s.manifestHash);assert.equal(c.prepared.input.manifest.causeHash,s.manifest.causeHash);
  assert.ok(Object.isFrozen(c.payoutSnapshot));assert.ok(s.state.calls.some(x=>x.name==='reads'));
  const bad=structuredClone(c);bad.ownerSnapshot.revision='5n';
  await assert.rejects(workflow.simulateArtistRecoveryRewind(s.provider,bad,{blockTag:11}),/Capture changed/);
});
test('complete original selection keeps both source snapshots and new-side replay separate',async()=>{
  const s=setup(),c=await s.capture({kind:'identityRecoveryContextV3',request:s.request,acceptance:s.acceptance,manifestHash:s.manifestHash});
  assert.equal(c.recovery.selection.result.commitment,s.selectionResult.commitment);
  assert.equal(c.recovery.context.scopeHash,s.context.scopeHash);assert.equal(c.recovery.acceptanceConsumed,false);
});
test('preparation65534 binds both owner snapshots, exact seal and one Archive',async()=>{
  const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'register',addr(602)),r=installRegistration(s,g,o.caller);
  const result=await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,s.receipt(o.call,o.caller,r.logs,12));
  const a=pure.decodeArtistRecoveryOperationEvidence(result.archiveBytes);
  assert.equal(a.primaryRecordHash,ZeroHash);assert.deepEqual(a.before[5],s.payoutSnapshot);assert.deepEqual(a.after[5],s.payoutSnapshot);
});
test('atomic35/no-Payout-change keeps original pair and both Safe success layouts',async()=>{
  for(const safe of [null,false,true]){
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
    const result=await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,s.receipt(o.call,o.caller,r.logs,20,safe!==null,safe===true));
    assert.equal(result.record.recordHash,r.record.recordHash);assert.deepEqual(result.nativeRecords.map(x=>x.operation),[35n,35n]);
  }
});
test('current living notice retains genuine42 before pair and phase2 original terminal',async()=>{
  for(const phase of [1n,2n]){
    const s=setup();addNotice(s,phase);const g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
    const result=await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,s.receipt(o.call,o.caller,r.logs,20));
    assert.deepEqual(result.nativeRecords.map(x=>x.operation),phase===1n?[42n,35n,35n]:[35n,35n]);
  }
});

test('Payout original publication and typed exclusion produce one atomic Payout apply without op18',async()=>{
  const p=setup({payout:true});p.state.payoutPublished=false;const input={kind:'publishPayoutOriginalV3',original:p.payoutOriginal};
  const captured=await p.capture(input);const evidenceHash=rewind.artistRecoveryRewindPayoutOriginalHash(p.c,p.payoutOriginal);
  const published=await workflow.inspectArtistRecoveryRewindReceipt(p.provider,captured,p.receipt(captured.prepared.call,captured.prepared.caller,
    [p.event(p.d.evidence.address,'RecoveryPayoutOriginalPublished',[evidenceHash,p.payoutOriginal.recordHash,p.request.artistId,codeHash,codeHash])]));
  assert.equal(published.retained[1],evidenceHash);
  const s=setup({payout:true}),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
  const result=await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,s.receipt(o.call,o.caller,r.logs,20,true,true));
  const envelope=pure.decodeArtistRecoveryOperationEvidence(result.archiveBytes);
  assert.equal(envelope.after[5].revision,envelope.before[5].revision+1n);
  assert.equal(s.state.payoutNative.length,1);assert.equal(result.nativeRecords.length,2);
});


test('all seven typed record families join original bytes, checkpoint, revision and standing continuations',async()=>{
  const s=setup({payout:true});addIdentityFamilies(s);
  const g=await s.gov();assert.equal(g.capture.recovery.selection.records.length,7);
  assert.equal(g.capture.recovery.selection.records.find(x=>x.kind===5n).retained,true);
  const o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
  const result=await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,s.receipt(o.call,o.caller,r.logs,20));
  assert.equal(result.record.recordHash,r.record.recordHash);
  assert.notEqual(s.state.identityInventory.revisionContinuationHash,ZeroHash);
});
test('class3 restored capability continuation binds designation, directive and original activation',async()=>{
  const s=setup();addIdentityFamilies(s,{class3:true});const g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
  await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,s.receipt(o.call,o.caller,r.logs,20,true));
  assert.equal(s.state.continuations.get(r.record.recordHash).effectiveCapabilities,4095n);
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
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'register',addr(602)),r=installRegistration(s,g,o.caller);
    const options=s.receipt(o.call,o.caller,r.logs,12);
    if(mutation==='replay')s.state.replays.clear();
    else rewriteArchive(s,r,e=>{
      if(mutation==='owner')e.after[0]={...s.snapshot};
      else {const v=structuredClone(rewind.decodeArtistRecoveryRewindPreparationPayload(e.payload));v.state.policyCommitment=hash('different');e.payload=rewind.encodeArtistRecoveryRewindPreparationPayload(v);}
    });
    await assert.rejects(workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options),/replay|differ/);
  }
});

test('execution replay omissions,42 native order and both empty-payload event omissions fail closed',async()=>{
  for(const mutation of ['action','retirement','native','payload']){
    const s=setup();addNotice(s,1n);const g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
    const options=s.receipt(o.call,o.caller,r.logs,20);
    if(mutation==='action')s.state.replays.delete(replayKey(s,'identity_authority.replay.recovery_action',keccak256(coder.encode(['bytes32','bytes32','bytes32','bytes32'],[g.batch.actionId,s.context.scopeHash,s.context.oldValueHash,s.context.newValueHash]))));
    if(mutation==='retirement')s.state.replays.delete(replayKey(s,'identity_authority.replay.standing_retirement',keccak256(coder.encode(['bytes32','address','bytes32'],[s.request.artistId,s.context.incumbent,r.record.recordHash]))));
    if(mutation==='native')[s.state.native[0],s.state.native[1]]=[s.state.native[1],s.state.native[0]];
    if(mutation==='payload')s.state.receipt.logs=s.state.receipt.logs.filter(l=>l.topics[0]!==abi.getEvent('ArtistStoredPayload').topicHash);
    renumber(s);await assert.rejects(workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options),/replay|differ|payload additions/);
  }
});

test('Archive synchronization must finish before Governance execution and Safe success',async()=>{
  for(const mutation of ['late-sync','early-safe','failure','delegatecall','inner-value','inner-data','outer-value']){
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
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
      const values=Array.from(safe.decodeFunctionData('execTransaction',s.state.tx.data));
      if(mutation==='delegatecall')values[3]=1n;
      if(mutation==='inner-value')values[1]=1n;
      if(mutation==='inner-data')values[2]='0x12345678';
      if(mutation==='outer-value')s.state.tx.value=1n;
      s.state.tx.data=safe.encodeFunctionData('execTransaction',values);
    }
    renumber(s);await assert.rejects(workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options),/order|Safe|CALL|chronology/);
  }
});

test('class2 schedule requires membership before commitment, scheduled then validation; same-block veto retained',async()=>{
  for(const status of [1n,5n]){
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'schedule',addr(600)),b=g.batch;
    s.state.published=true;s.state.nonce=1n;s.state.status=status;
    const logs=[s.event(b.executor,'TerminalFreezeActionMembershipUpdated',[1n,b.context.scopeHash,b.actionId,o.caller,true,1n,true,b.window.notBefore,0n,1n]),
      s.event(b.executor,'TerminalFreezeGuardianConfigCommitted',[1n,b.actionId,hash('guardian-commitment')]),
      s.event(b.executor,'GovernanceActionScheduled',[1n,b.actionId,2n,b.targetCall.to,0n,b.governanceCall.selector,b.callsHash,b.scopeHash,b.oldValueHash,b.newValueHash,b.window.notBefore,b.window.expiresAfter,0n,o.caller,b.window.reasonHash,b.window.reasonURI,b.window.manifestHash]),
      s.event(b.executor,'GovernanceActionPolicyValidated',[1n,b.actionId,1n,hash('profile'),hash('catalog')])];
    const options=s.receipt(o.call,o.caller,logs);
    await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options);
    s.state.receipt.logs.shift();renumber(s);
    await assert.rejects(workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options),/membership append/);
  }
});

test('eventless governance publication proves separate previous-block runtime and retained pointer',async()=>{
  const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'publish',addr(601));s.state.published=true;
  const options=s.receipt(o.call,o.caller,[],12,true,false);await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options);
  s.state.codeOverride=(to,tag)=>tag===11&&to===s.d.governance.address?'0x6001':undefined;
  await assert.rejects(workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options),/runtime/);
});
test('execution simulation uses the registered anchor and rejects stale owners and replay before original call',async()=>{
  const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601));installExecution(s,g);
  s.state.effectiveBlock=21;
  const result=await workflow.simulateArtistRecoveryRewindOperation(s.provider,o,{blockTag:20});assert.equal(result.facts.association.ownerRevision,6n);
  s.state.registeredSnapshot={...s.state.registeredSnapshot,stateRoot:hash('unsealed-change')};
  await assert.rejects(workflow.simulateArtistRecoveryRewindOperation(s.provider,o,{blockTag:20}),/snapshot changed/);
});

test('phase2 retained records allow later owner revisions without using a latest-record head',async()=>{
  const s=setup();addNotice(s,2n);const g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
  const options=s.receipt(o.call,o.caller,r.logs,20);s.state.afterSnapshot={...s.state.afterSnapshot,revision:8n,stateRoot:hash('later-root'),recordChainTip:hash('later-tip')};
  const result=await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options);assert.equal(result.record.recordHash,r.record.recordHash);
  assert.ok(!s.state.calls.some(x=>x.name==='latestIdentityRecovery'));
});

test('terminal membership cleanup allows original cause3 before target and rejects contradiction',async()=>{
  for(const mutation of ['none','wrong-cause','duplicate','late']){
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g),b=g.batch;
    const cleanup=s.event(b.executor,'TerminalFreezeActionMembershipUpdated',[1n,b.context.scopeHash,b.actionId,g.proposer,false,mutation==='wrong-cause'?2n:3n,true,b.window.notBefore,0n,0n]);
    if(mutation==='late')r.logs.splice(1,0,cleanup);else r.logs.unshift(cleanup);
    if(mutation==='duplicate')r.logs.unshift(cleanup);
    const options=s.receipt(o.call,o.caller,r.logs,20);
    if(mutation==='none')await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options);
    else await assert.rejects(workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options),/cleanup/);
  }
});



test('historical completed selection survives later guardian heads; live freshness and immutable prefix still hold',async()=>{
  const s=setup();addIdentityFamilies(s);
  const entry=s.state.guardianEntries.get(1n),head=s.basis.identity.guardianHistory;
  s.state.readOverride=(name,args,to)=>name==='guardianHistoryState'?[{...head,count:2n,ownerRevision:9n,commitment:hash('later-guardian')},
    args[1]===1n?entry:zero(abi.getFunction(name).outputs[1]),zero(pure.ARTIST_RECOVERY_HISTORY_SNAPSHOT_TUPLE),0n]
    :name==='ownerStateSnapshotV2'&&to===s.c.identityOwner?[{...s.snapshot,revision:9n,stateRoot:hash('later-state'),recordChainTip:hash('later-tip')}]
    :name==='artistNativeReceiptCount'&&to===s.c.identityOwner?[BigInt(s.state.beforeNative.length)+1n]:undefined;
  const historical=await s.capture({kind:'selectionResultV3',key:s.selectionKey});
  assert.equal(historical.selection.result.commitment,s.selectionResult.commitment);
  assert.ok(!s.state.calls.some(x=>x.name==='requireSelectionV3'));
  await assert.rejects(s.capture({kind:'requireSelectionV3',manifestHash:s.manifestHash}),/Guardian checkpoint differs/);
  s.state.guardianEntries.set(1n,{...entry,previousCommitment:hash('wrong-chain')});
  s.state.readOverride=(name,args)=>name==='guardianHistoryState'?[head,args[1]===1n?s.state.guardianEntries.get(1n):zero(abi.getFunction(name).outputs[1]),zero(pure.ARTIST_RECOVERY_HISTORY_SNAPSHOT_TUPLE),0n]:undefined;
  await assert.rejects(s.capture({kind:'selectionResultV3',key:s.selectionKey}),/differ/);
});
test('complete global prefixes include unrelated Payout rows without requesting their preimages',async()=>{
  const s=setup();s.state.beforeNative.push({operation:54n,artistId:hash('other'),collectionId:0n,recordHash:hash('other-identity')});
  s.state.payoutNative.push({operation:18n,artistId:hash('other'),collectionId:0n,recordHash:hash('other-payout')});s.refresh();
  const c=await s.capture({kind:'requireSelectionV3',manifestHash:s.manifestHash});
  assert.equal(c.selection.identityJournal.length,1);assert.equal(c.selection.payoutJournal.length,1);assert.equal(c.selection.records.length,0);
  assert.ok(!s.state.calls.some(x=>x.name==='payoutOriginalV3'||x.name==='designationRecord'));
  for(const owner of [s.c.identityOwner,s.c.payoutOwner]){
    s.state.readOverride=(name,args,to)=>name==='artistNativeReceiptCount'&&to===owner?[2n]:undefined;
    await assert.rejects(s.capture({kind:'requireSelectionV3',manifestHash:s.manifestHash}),/differ/);
  }
});
test('chunk budget consumes Identity before Payout and empty prefixes still persist completion',async()=>{
  for(const empty of [false,true]){
    const s=setup();
    if(!empty){s.state.beforeNative.push({operation:54n,artistId:hash('other'),collectionId:0n,recordHash:hash('i')});
      s.state.payoutNative.push({operation:18n,artistId:hash('other'),collectionId:0n,recordHash:hash('p')});s.refresh();}
    s.state.complete=false;
    const after={...zero(rewind.ARTIST_RECOVERY_REWIND_SELECTION_PROGRESS_TUPLE),identityProcessed:empty?0n:1n,complete:empty};
    s.state.readOverride=name=>name==='continueSelectionV3'?[after]:undefined;
    const c=await s.capture({kind:'continueSelectionV3',key:s.selectionKey,maximumRecords:1n});
    assert.equal(c.result[0].payoutProcessed,0n);assert.equal(c.result[0].complete,empty);
    s.state.readOverride=name=>name==='continueSelectionV3'?[{...after,payoutProcessed:1n}]:undefined;
    await assert.rejects(s.capture({kind:'continueSelectionV3',key:s.selectionKey,maximumRecords:1n}),/progress return/);
  }
  const s=setup();await assert.rejects(s.capture({kind:'continueSelectionV3',key:s.selectionKey,maximumRecords:65n}),/exceeds64/);
});
test('typed family, candidate, guardian and original-document contradictions are rejected',async()=>{
  for(const mutation of ['family','candidate','guardian-key','document','checkpoint-data']){
    const s=setup();const hashes=addIdentityFamilies(s);
    if(mutation==='family')s.selectionResult.designation.operative=s.selectionResult.directive.operative;
    if(mutation==='candidate')s.selectionResult.designation.retainedCandidateRecordHash=hashes.get(1);
    if(mutation==='document')s.state.documents.set(s.state.recordValues.get(hashes.get(3)).revisedRecordHash,'0xabcd');
    if(mutation==='checkpoint-data'){
      const entry=s.state.guardianEntries.get(1n);entry.recordDataHash=hash('wrong-bytes');
      entry.commitment=keccak256(coder.encode(['bytes32','uint256','address','address','bytes32','uint64','uint64','bytes32','bytes32','bytes32'],
        [id('6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1'),1n,s.c.registry,s.c.identityOwner,entry.artistId,1n,1n,entry.recordHash,entry.recordDataHash,ZeroHash]));
      s.basis.identity.guardianHistory.commitment=entry.commitment;
    }
    s.refresh();
    if(mutation==='guardian-key'){
      s.selectionResult.guardians.sourceKey=hash('wrong-key');s.selectionResult.guardians.commitment=rewind.artistRecoveryRewindGuardianResultHash(s.c,s.basis.identity.guardianHistory,s.selectionResult.guardians);
      s.selectionResult.commitment=rewind.artistRecoveryRewindSelectionResultHash(s.c,s.selectionResult);s.progress.resultCommitment=s.selectionResult.commitment;
    }
    await assert.rejects(s.capture({kind:'requireSelectionV3',manifestHash:s.manifestHash}),/differ|retained|Candidate|guardian|checkpoint/i);
  }
});
test('Payout mutation requires exact replay kinds, status, continuation and event before the one Archive',async()=>{
  for(const mutation of ['event','replay','status','continuation','late','native']){
    const s=setup({payout:true}),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
    const options=s.receipt(o.call,o.caller,r.logs,20);
    const topic=abi.getEvent('ArtistPayoutRecoveryRewindApplied').topicHash;
    if(mutation==='event')s.state.receipt.logs=s.state.receipt.logs.filter(x=>x.topics[0]!==topic);
    if(mutation==='replay')for(const [key,v] of s.state.replays)if(v.kind===3n)s.state.replays.set(key,{...v,kind:1n});
    if(mutation==='status')s.state.payoutStatuses.get(s.payoutOriginal.recordHash).kind=3n;
    if(mutation==='continuation')s.state.continuations.get(s.state.payoutInventory.continuationCommitment).releasedChildRecordHash=ZeroHash;
    if(mutation==='late'){const i=s.state.receipt.logs.findIndex(x=>x.topics[0]===topic);s.state.receipt.logs.push(...s.state.receipt.logs.splice(i,1));}
    if(mutation==='native')s.state.payoutNative.push({operation:18n,artistId:s.request.artistId,collectionId:0n,recordHash:hash('synthetic')});
    renumber(s);await assert.rejects(workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options),/differ|exactly one|Payout|ordering/);
  }
});
test('full dual-owner Archive and preparation seal cannot be omitted or altered consistently',async()=>{
  for(const mutation of ['payout-before','payout-after','seal','mutation']){
    const s=setup({payout:true}),g=await s.gov(),stage=mutation==='seal'?'register':'execute',o=workflow.prepareArtistRecoveryRewindOperation(g,stage,addr(601));
    const r=stage==='register'?installRegistration(s,g,o.caller):installExecution(s,g),options=s.receipt(o.call,o.caller,r.logs,stage==='register'?12:20);
    if(mutation==='seal')s.state.seal.identityAfterPreparation.stateRoot=hash('forged');
    else rewriteArchive(s,r,e=>{
      if(mutation==='payout-before')e.before[5]=zero('(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)');
      if(mutation==='payout-after')e.after[5].revision=e.before[5].revision;
      if(mutation==='mutation'){const value=structuredClone(rewind.decodeArtistRecoveryRewindExecutionPayload(e.payload));value.payoutMutation=hash('wrong-mutation');e.payload=rewind.encodeArtistRecoveryRewindExecutionPayload(value);}
    });
    await assert.rejects(workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options),/differ|revision|semantic receipt/);
  }
});
test('protocol hooks, wrong original caller/value/calldata, runtime drift and noncanonical reads fail closed',async()=>{
  const s=setup(),c=await s.capture({kind:'publishResolutionManifestV3',manifest:s.manifest});
  await assert.rejects(s.capture({kind:'recoverArtistIdentityV3',request:s.request,acceptance:s.acceptance,manifestHash:s.manifestHash}),/Governance/);
  s.state.rawOverride=(name,result)=>name==='ownerStateSnapshotV2'?`${abi.encodeFunctionResult(name,result)}00`:undefined;
  await assert.rejects(workflow.simulateArtistRecoveryRewind(s.provider,c,{blockTag:11}),/canonical|invalid length/);
  s.state.rawOverride=null;s.state.codeOverride=(to)=>to===s.c.payoutOwner?'0x6001':undefined;
  await assert.rejects(workflow.simulateArtistRecoveryRewind(s.provider,c,{blockTag:11}),/runtime/);
  for(const mutation of ['caller','value','calldata']){
    const t=setup(),cap=await t.capture({kind:'publishResolutionManifestV3',manifest:t.manifest}),options=t.receipt(cap.prepared.call,cap.prepared.caller,[],12);
    if(mutation==='caller')t.state.tx.from=addr(999);if(mutation==='value')t.state.tx.value=1n;if(mutation==='calldata')t.state.tx.data='0x12345678';
    await assert.rejects(workflow.inspectArtistRecoveryRewindReceipt(t.provider,cap,options),/differ|value|caller/i);
  }
});


test('nonzero revision, standing and class3 continuation fields cannot be substituted',async()=>{
  for(const family of ['revision','standing','capability']){
    const s=setup();addIdentityFamilies(s,{class3:true});const g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
    const options=s.receipt(o.call,o.caller,r.logs,20);
    const value=[...s.state.continuations.values()].find(v=>family==='revision'?'stableDocumentHash'in v:family==='standing'?'priorAddress'in v:'effectiveCapabilities'in v);
    if(family==='revision')value.stableDocumentHash=hash('wrong-document');
    if(family==='standing')value.retirementHash=hash('wrong-retirement');
    if(family==='capability')value.pairedDirectiveRecordHash=hash('wrong-pair');
    await assert.rejects(workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,options),/differ/);
  }
});
test('canonical APPEAL publication reuses retained bytes and requires separate prior-block pins',async()=>{
  const s=setup();s.state.appeal={resolutionManifestHash:s.manifestHash,hostileFindingsHash:hash('hostile'),findings:[{guardianRecordHash:hash('hostile-guardian'),parties:[addr(8)]}]};
  const c=await s.capture({kind:'publishAppealV3',document:s.state.appeal}),evidenceHash=rewind.artistRecoveryRewindAppealHash(s.c,s.state.appeal);
  const options=s.receipt(c.prepared.call,c.prepared.caller,[s.event(s.d.evidence.address,'RecoveryRewindAppealPublished',[evidenceHash,s.manifestHash,codeHash,codeHash])]);
  await workflow.inspectArtistRecoveryRewindReceipt(s.provider,c,options);
  const retry=s.receipt(c.prepared.call,c.prepared.caller,[],12,true);
  await workflow.inspectArtistRecoveryRewindReceipt(s.provider,c,retry);
  s.state.codeOverride=(to,tag)=>tag===11&&to===s.c.payoutOwner?'0x6001':undefined;
  await assert.rejects(workflow.inspectArtistRecoveryRewindReceipt(s.provider,c,retry),/runtime/);
});
test('full preparation seal authorizes exactly its post-preparation snapshot and unchanged Payout prefix',async()=>{
  for(const mutation of ['identity-root','payout-root','payout-count']){
    const s=setup(),g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601));installExecution(s,g);s.state.effectiveBlock=21;
    const old=s.state.readOverride;
    s.state.readOverride=(name,args,to,tag)=>tag===20&&name==='ownerStateSnapshotV2'&&to===(mutation==='identity-root'?s.c.identityOwner:s.c.payoutOwner)&&mutation!=='payout-count'
      ?[{...(mutation==='identity-root'?s.state.registeredSnapshot:s.payoutSnapshot),stateRoot:hash('same-revision-different-root')}]
      :tag===20&&name==='artistNativeReceiptCount'&&to===s.c.payoutOwner&&mutation==='payout-count'?[1n]:old?.(name,args,to,tag);
    await assert.rejects(workflow.simulateArtistRecoveryRewindOperation(s.provider,o,{blockTag:20}),/differ|snapshot changed/);
  }
});
test('concrete block reorganization and dependency delegation code are rejected',async()=>{
  const s=setup();let reads=0;
  s.state.blockOverride=tag=>({number:tag,hash:hash(++reads>1?'reorganized':`block${tag}`),timestamp:Number(s.clock(tag))});
  await assert.rejects(s.capture({kind:'publishResolutionManifestV3',manifest:s.manifest}),/changed|reorg/i);
  const t=setup(),delegated=`0xef0100${addr(8).slice(2)}`;
  t.d.evidence.codeHash=keccak256(delegated);t.state.codeOverride=to=>to===t.d.evidence.address?delegated:undefined;
  await assert.rejects(t.capture({kind:'publishResolutionManifestV3',manifest:t.manifest}),/runtime|delegat/i);
});


test('retained ineligible revision child remains occupied without inventing a stable fallback',async()=>{
  const s=setup(),hashes=addIdentityFamilies(s),child=hashes.get(3);
  s.manifest.supersededRecords=s.manifest.supersededRecords.filter(x=>x.kind!==3n);
  s.basis.identity.inventory.revisions={stable:ZeroHash,candidate:child};
  s.selectionResult.identityRevision.retainedCandidateRecordHash=child;
  const row=s.state.selectedRows.get(child);row[2]=true;row[3]=false;s.refresh();
  const g=await s.gov(),o=workflow.prepareArtistRecoveryRewindOperation(g,'execute',addr(601)),r=installExecution(s,g);
  const receipt=await workflow.inspectArtistRecoveryRewindOperationReceipt(s.provider,o,s.receipt(o.call,o.caller,r.logs,20));
  assert.equal(receipt.record.recordHash,r.record.recordHash);
  assert.deepEqual(s.state.identityInventory.revisions,{stable:ZeroHash,candidate:child});
  assert.equal(s.state.identityInventory.revisionContinuationHash,ZeroHash);
});
test('private paired-directive and protected-guardian admission failures propagate from the original call',async()=>{
  for(const failure of ['excluded paired directive','protected guardian prefix']){
    const s=setup();addIdentityFamilies(s,{class3:true});
    const rejection=Object.assign(Error(failure),{code:'CALL_EXCEPTION',data:'0x'});
    s.state.readOverride=(name,args,to,tag,tx)=>{if(name==='identityRecoveryContextV3'&&tx.from===addr(600))throw rejection;};
    await assert.rejects(s.capture({kind:'identityRecoveryContextV3',request:s.request,acceptance:s.acceptance,manifestHash:s.manifestHash}),error=>error===rejection);
    assert.ok(s.state.calls.some(x=>x.name==='identityRecoveryContextV3'&&x.from===addr(600)));
  }
});


test('selection begin and empty completion receipts preserve exact original events and eventless retries',async()=>{
  const begin=setup();begin.state.selection=false;begin.state.complete=false;
  const started=await begin.capture({kind:'beginSelectionV3',manifestHash:begin.manifestHash});
  begin.state.readOverride=(name,args,to,tag)=>name==='selectionV3'&&tag>=11?[begin.basis,zero(rewind.ARTIST_RECOVERY_REWIND_SELECTION_PROGRESS_TUPLE)]:undefined;
  const first=begin.receipt(started.prepared.call,started.prepared.caller,[begin.event(begin.d.selection.address,'RecoveryRewindSelectionBegun',[begin.selectionKey,begin.manifestHash])]);
  const initial=await workflow.inspectArtistRecoveryRewindReceipt(begin.provider,started,first);
  assert.equal(initial.selection.progress.complete,false);
  const empty=setup();empty.state.complete=false;
  const step=await empty.capture({kind:'continueSelectionV3',key:empty.selectionKey,maximumRecords:1n});
  const completed=empty.receipt(step.prepared.call,step.prepared.caller,[empty.event(empty.d.selection.address,'RecoveryRewindSelectionProgress',[empty.selectionKey,0n,0n,true])]);
  const done=await workflow.inspectArtistRecoveryRewindReceipt(empty.provider,step,completed);assert.equal(done.selection.progress.complete,true);
  const retry=setup(),saved=await retry.capture({kind:'continueSelectionV3',key:retry.selectionKey,maximumRecords:1n});
  await workflow.inspectArtistRecoveryRewindReceipt(retry.provider,saved,retry.receipt(saved.prepared.call,saved.prepared.caller,[],12,true,true));
  retry.state.receipt.logs.unshift({...retry.state.receipt.logs[0],...retry.event(retry.d.selection.address,'RecoveryRewindSelectionProgress',[retry.selectionKey,0n,0n,true])});renumber(retry);
  await assert.rejects(workflow.inspectArtistRecoveryRewindReceipt(retry.provider,saved,{transactionHash:hash('transaction'),execution:'safe'}),/Complete retry/);
});
test('first manifest publication needs its original event; same-block retention cannot prove eventless reuse',async()=>{
  const s=setup();s.state.manifest=false;const captured=await s.capture({kind:'publishResolutionManifestV3',manifest:s.manifest});
  const options=s.receipt(captured.prepared.call,captured.prepared.caller,[s.event(s.d.evidence.address,'RecoveryRewindManifestPublished',
    [s.manifestHash,s.request.artistId,s.request.expectedCauseHash,codeHash,codeHash])]);
  await workflow.inspectArtistRecoveryRewindReceipt(s.provider,captured,options);
  s.state.receipt.logs=[];
  await assert.rejects(workflow.inspectArtistRecoveryRewindReceipt(s.provider,captured,options),/exactly one/);
});
