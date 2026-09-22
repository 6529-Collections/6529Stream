// Compiler-encoded consistency fixtures. No native Registry, Identity, Executor, Safe or signature execution.
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as a from '../dist/current-artist-attribution.js';
import * as gov from '../dist/current-governance-executor-v2.js';
import * as gw from '../dist/current-governance-executor-v2-workflow.js';
import { compiledInterfaces as c, compiledLibraryEvents, compiledABI, compiledLibraryValueInterface } from './current-artist-attribution-source-fixture.mjs';
import { setup as governanceSetup, executorABI, safeABI, safeHash } from './current-governance-executor-v2-workflow-fixture.mjs';
export const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, '0')}`), H = n => `0x${BigInt(n).toString(16).padStart(64, '0')}`;
export const Z = ZeroHash, ZA = ZeroAddress, coder = AbiCoder.defaultAbiCoder(), copy = v => structuredClone(v);
export const methods = ['fileAttributionClaim','openAttributionDispute','recordCounterStatement','resolveAttributionDispute','revokeAttribution','vetoAttributionRepudiation','cancelAttributionRepudiation','executeAttributionRepudiation','withdrawAttributionDispute'];
const events = new Interface(['StreamArtistAttributionClaimState','StreamArtistDisputeState','StreamArtistDisputeWithdrawalState','StreamArtistRepudiationState','StreamArtistIdentityContestState','StreamArtistIdentityDismissalState','StreamArtistDormancyState','StreamArtistDormancyRecordEvents'].flatMap(n=>compiledLibraryEvents(n).fragments));
const indexedSafe = new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']);
const core = new Interface([...c.IStreamCorePointers.fragments,...c.IStreamCoreCollectionView.fragments]);
const manager = c.IStreamArtistManagerBinding;
const roles = c.IStreamRoleRegistry;
const claimEvidenceType = compiledLibraryValueInterface('StreamArtistPlatformEvidence').getFunction('read').outputs[0];
const owner = new Interface([...compiledABI('identity'),...compiledABI('attribution'),...compiledABI('binding')]);
export function zero(p) {
  if(p.baseType==='array')return p.arrayLength===-1?[]:Array.from({length:p.arrayLength},()=>zero(p.arrayChildren));
  if(p.baseType==='tuple')return Object.fromEntries(p.components.map(v=>[v.name,zero(v)]));
  if(p.type==='address')return ZA;if(p.type==='bool')return false;if(p.type==='string')return '';if(p.type==='bytes')return '0x';
  if(p.type.startsWith('bytes'))return `0x${'00'.repeat(Number(p.type.slice(5)))}`;return 0n;
}
function empty(iface,name){return zero(iface.getFunction(name).outputs[0]);}
export function setup(kind='openAttributionDispute', config={}) {
  if(!methods.includes(kind))throw Error('Unknown fixture operation');
  const g = governanceSetup('executeGovernanceBatch',{actionClass:1n,value:0n});
  const chainId=31337n,runtime='0x6001600055',codeHash=keccak256(runtime),pin=address=>({address,codeHash});
  const registry=A(1000),coordinator=A(1001),archive=A(1002),coreAddress=A(1003),mintManager=A(1004),owners=Array.from({length:7},(_,i)=>A(1010+i));
  const d={chainId,registry:pin(registry),coordinator:pin(coordinator),owners:owners.map(pin),archive:pin(archive),core:pin(coreAddress),mintManager:pin(mintManager),roleRegistry:g.deployment.roleRegistry,linkedDependencies:[pin(A(1020))]};
  const governed=kind==='resolveAttributionDispute'||(kind==='openAttributionDispute'&&config.governed),caller=governed?g.deployment.executor.address:A(0xa0a),signer=config.relayed?A(0xb0b):caller,cid=7n,artist=H(3000),coordinates={chainId,registry,core:coreAddress};
  const snapshots=owners.map((_,i)=>({domainId:H(5000+i),revision:10n,stateRoot:H(5010+i),recordChainTip:H(5020+i)}));
  const binding={artistId:artist,artistAddress:signer,identityRecordHash:H(3101),bindingHash:H(3102),generation:2n,consentMode:1n,saleConsentScope:0n,registryImmutabilityElection:0n,proposer:A(333),accepted:true};
  const head={disputeRecordHash:Z,counterStatementRecordHash:Z,resolutionActionId:Z,restoreState:2n,revocationReason:0n,open:false,reopened:false};
  const authorityHead={principal:signer,authorityClass:1n,latestTransition:Z,latestContest:Z,latestDismissal:Z};
  const identity={authorityAddress:signer,authorityClass:1n,status:1n,registeredAt:5n,lastAuthorityActionAt:6n,identityRecordHash:binding.identityRecordHash,identityRecordURI:'',displayName:'Fixture',nonceHint:0n};
  const standing={artistId:artist,bindingGeneration:2n,collaboratorIndex:0n,delegation:Z},authorization={nonce:8n,time:config.relayed?2000000n:0n,signature:config.relayed?'0x1234':'0x'};
  const filing={collectionId:cid,bindingGeneration:2n,disputeAction:kind==='recordCounterStatement'?3n:kind==='withdrawAttributionDispute'?2n:kind==='revokeAttribution'?4n:1n,evidenceHash:H(3200),reasonHash:H(3201)};
  const opening={recordHash:Z,terms:{...filing,disputeAction:1n},signer,authorityClass:1n,nonce:1n,recordedAt:900n,artistId:artist,bindingHash:binding.bindingHash,disputeRecordHash:Z,previousRecordHash:Z,standing:copy(standing),governanceActionId:Z};
  opening.recordHash=a.artistAttributionDisputeRecordHash(coordinates,opening);opening.disputeRecordHash=opening.recordHash;
  const priorRepudiation={recordHash:Z,terms:{...filing,disputeAction:4n},artistId:artist,signer,authorityClass:1n,nonce:4n,stagedAt:1000n,executableAt:260200n,bindingHash:binding.bindingHash,authorityHead:copy(authorityHead),capturedGuardianSet:H(3300),windowRevision:1n};
  priorRepudiation.recordHash=a.artistAttributionRepudiationRecordHash(coordinates,priorRepudiation);
  if(['recordCounterStatement','resolveAttributionDispute','withdrawAttributionDispute'].includes(kind))Object.assign(head,{disputeRecordHash:opening.recordHash,open:true});
  let request;
  if(kind==='fileAttributionClaim')request={kind,collectionId:cid,evidenceHash:H(3200),reasonHash:H(3201),reasonURI:'ipfs://claim'};
  else if(kind==='resolveAttributionDispute')request={kind,resolution:{collectionId:cid,bindingGeneration:2n,disputeRecordHash:opening.recordHash,resolution:1n,evidenceHash:filing.evidenceHash,reasonHash:filing.reasonHash,counterStatementRecordHash:Z}};
  else if(kind==='revokeAttribution')request={kind,filing,authorization};
  else if(['vetoAttributionRepudiation','cancelAttributionRepudiation','executeAttributionRepudiation'].includes(kind))request={kind,collectionId:cid,expectedRepudiation:priorRepudiation.recordHash,...(kind==='vetoAttributionRepudiation'?{reasonHash:H(3350)}:{})};
  else request={kind,filing,standing:governed?{artistId:Z,bindingGeneration:0n,collaboratorIndex:0n,delegation:Z}:standing,authorization:governed?{nonce:0n,time:0n,signature:'0x'}:authorization,...(kind==='openAttributionDispute'?{mode:governed?'governance':'signed'}:{})};
  const claimDoc={schemaVersion:1n,collectionId:cid,proposedArtist:A(444),claimRecordHash:Z,narrativeHash:H(3400)},reasonDoc={...claimDoc,narrativeHash:H(3401)};
  if(kind==='fileAttributionClaim'){request.evidenceHash=keccak256(coder.encode([claimEvidenceType],[claimDoc]));request.reasonHash=keccak256(coder.encode([claimEvidenceType],[reasonDoc]));}
  const prepared=a.prepareArtistAttributionCall(coordinates,caller,request),op=prepared.operationId;
  const readMask=op===10n?0x10:[44n,50n,61n].includes(op)?0x15:op===46n?0x11:[48n,49n].includes(op)?0x14:0x17,writeMask=[10n,46n,50n].includes(op)||(op===44n&&governed)?0x10:0x14;
  const state={codes:new Map(g.state.codes),reads:[],transactions:new Map(),receipts:new Map(),after:null,mutate:null,override:null,codeOverride:null,simulationError:null,simulationRaw:null,nonceUsed:false,head:copy(head),binding:copy(binding),identity:copy(identity),state:head.open?4n:2n,rawPending:'expectedRepudiation'in request?priorRepudiation.recordHash:Z,priorTerminal:{phase:1n,actor:ZA,reasonHash:Z,recordedAt:0n},snapshots:copy(snapshots),claims:[0n,Z],safeNonce:11n,current:true};
  if(config.pending){if(config.pending==='stale'){priorRepudiation.authorityHead.latestTransition=H(3339);priorRepudiation.recordHash=a.artistAttributionRepudiationRecordHash(coordinates,priorRepudiation);}state.rawPending=priorRepudiation.recordHash;if(config.pending==='closed')state.priorTerminal={phase:2n,actor:A(4444),reasonHash:H(3338),recordedAt:800n};}
  // Retained notice is a supplied original local record, not a simulated prior governance lifecycle.
  const dormancyRecord=c.identity.getFunction('dormancyRecord'),notice=zero(dormancyRecord.outputs[0]);
  Object.assign(notice,{recordHash:H(3360),terms:{artistId:artist,evidenceHash:H(3361),reasonURI:'ipfs://notice'},incumbent:signer,initiatedAt:100n,noticeEndsAt:40_000_000n,inactivitySeconds:63_072_000n,noticeSeconds:31_536_000n,timingRevision:1n,priorLivenessAt:6n,priorActivity:0n,actionId:H(3362),witnessHash:H(3363)});
  state.notice=config.activeNotice?[notice.recordHash,1n,Z]:[Z,0n,Z];if(config.activeNotice)state.identity.status=2n;
  [...d.owners,d.registry,d.coordinator,d.archive,d.core,d.mintManager,...d.linkedDependencies].forEach(v=>state.codes.set(v.address,runtime));state.codes.set(caller,runtime);
  const suite={registry,archive,owners,core:coreAddress,mintManager,roleRegistry:d.roleRegistry.address,metadata:A(1040),primaryResolver:A(1041),royaltyResolver:A(1042),primaryRevenueClass:H(1043),validator:A(1044)};
  const header=tag=>g.header(tag);
  const context=()=>kind==='resolveAttributionDispute'?a.artistAttributionResolutionContext(coordinates,request.resolution,state.binding,state.state,state.head):a.artistAttributionOpeningContext(coordinates,request.filing,state.binding,state.state,state.head);
  if(governed){
    const ctx=context(),call={target:registry,value:0n,selector:prepared.call.data.slice(0,10),callDataHash:keccak256(prepared.call.data),scopeHash:ctx.scopeHash,oldValueHash:ctx.oldValueHash,newValueHash:ctx.newValueHash};
    g.calls.splice(0,g.calls.length,call);g.callDatas.splice(0,g.callDatas.length,prepared.call.data);g.deployment.targets.splice(0,g.deployment.targets.length,pin(registry));
    const aggregate=gov.governanceExecutorV2BatchHashes(g.calls),action={...g.action,target:registry,value:0n,selector:call.selector,callHash:aggregate.callsHash,scopeHash:aggregate.scopeHash,oldValueHash:aggregate.oldValueHash,newValueHash:aggregate.newValueHash,reasonHash:filing.reasonHash};
    const actionId=gov.governanceExecutorV2ActionId({chainId,executor:g.deployment.executor.address},{actionClass:action.actionClass,callsHash:action.callHash,scopeHash:action.scopeHash,oldValueHash:action.oldValueHash,newValueHash:action.newValueHash,nonce:5n,notBefore:action.notBefore,expiresAfter:action.expiresAfter,reasonHash:action.reasonHash,manifestHash:action.manifestHash});
    g.request.actionId=actionId;g.state.actions.clear();g.state.actions.set(actionId,action);g.state.schedules.clear();g.state.schedules.set(actionId,{locator:g.historical,action,members:[],guardian:null});g.options.membershipSchedules=[];
    const r=g.state.receipts.get(g.historical.transactionHash),fragment=g.event(executorABI,'GovernanceActionScheduled',[1n,actionId,action.actionClass,action.target,action.value,action.selector,action.callHash,action.scopeHash,action.oldValueHash,action.newValueHash,action.notBefore,action.expiresAfter,5n,action.proposer,action.reasonHash,action.reasonURI,action.manifestHash]);
    r.logs[g.historical.logIndex]={...r.logs[g.historical.logIndex],...fragment};
    const policyIndex=g.historical.logIndex+1,policy=executorABI.parseLog(r.logs[policyIndex]);
    r.logs[policyIndex]={...r.logs[policyIndex],...g.event(executorABI,'GovernanceActionPolicyValidated',[1n,actionId,1n,policy.args[3],policy.args[4]])};
    const schedule={method:'scheduleGovernanceBatch',actionClass:action.actionClass,calls:g.calls,scopeHash:action.scopeHash,oldValueHash:action.oldValueHash,newValueHash:action.newValueHash,notBefore:action.notBefore,expiresAfter:action.expiresAfter,reasonHash:action.reasonHash,reasonURI:action.reasonURI,manifestHash:action.manifestHash};
    g.state.transactions.get(g.historical.transactionHash).data=gov.prepareGovernanceExecutorV2Call({chainId,executor:g.deployment.executor.address},g.caller,schedule).call.data;
    g.action=action;g.actionId=actionId;g.scope=call.scopeHash;g.scopes.splice(0,g.scopes.length,call.scopeHash);
    g.state.codes.set(g.pointer,`0x00${coder.encode(['bytes[]'],[g.callDatas]).slice(2)}`);state.codes.set(g.pointer,g.state.codes.get(g.pointer));
    const publicationKey=gov.governanceExecutorV2PublicationKey(g.callDatas);
    g.state.readOverride=({name,args})=>{if(name==='publishedCallData'&&args[0]!==publicationKey)throw Error('Unexpected fixture publication key');if(['scheduledCallData','scheduledCallDataPointer'].includes(name)&&args[0]!==actionId)throw Error('Unexpected fixture scheduled action');return undefined;};
  }
  function produce(timestamp){
    const emptyGov={actionId:Z,proposer:ZA,actionClass:0n,roleMutationHash:Z,roleRevision:0n,scopeHash:Z,oldValueHash:Z,newValueHash:Z},emptyContext={scopeHash:Z,oldValueHash:Z,newValueHash:Z,requiredClass:0n,restoredState:0n};
    const governance=governed?{...emptyGov,actionId:g.request.actionId,proposer:g.caller,actionClass:1n,roleMutationHash:H(700),roleRevision:1n,...Object.fromEntries(['scopeHash','oldValueHash','newValueHash'].map(k=>[k,context()[k]]))}:emptyGov;
    const before=snapshots.map((v,i)=>readMask&(1<<i)?copy(v):{domainId:Z,revision:0n,stateRoot:Z,recordChainTip:Z});
    const after=before.map((v,i)=>writeMask&(1<<i)?{...v,revision:v.revision+1n,stateRoot:H(6000+i),recordChainTip:H(6100+i)}:copy(v));
    let record,detail,newHead=copy(state.head),newState=state.state,terminal=copy(state.priorTerminal),pending=state.rawPending,outcome=null,contest=null,cause=null;
    const digest='filing'in request&&!governed?a.artistAttributionSigningPayload(coordinates,request.filing,request.authorization).digest:Z;
    const proof=governed?{signer:ZA,digest:Z,direct:false}:{signer,digest,direct:!config.relayed};
    if(op===10n){record={recordHash:Z,collectionId:cid,claimant:caller,evidenceHash:request.evidenceHash,reasonHash:request.reasonHash,reasonURI:request.reasonURI,filedAt:timestamp,proposedArtist:claimDoc.proposedArtist,previousRecordHash:state.claims[1],index:state.claims[0]+1n};record.recordHash=a.artistAttributionClaimRecordHash(coordinates,record);detail={operationId:op,id:cid,evidence:record.evidenceHash,reason:record.reasonHash,uri:record.reasonURI,e:claimDoc,r:reasonDoc,ep:H(3500),rp:H(3501)};}
    else if([44n,45n,61n].includes(op)){
      const admission={binding_:copy(state.binding),standing:copy(request.standing),signer:governed?g.caller:signer,authorityClass:governed?0n:1n,recordedAt:timestamp,digest};
      record={recordHash:Z,terms:copy(request.filing),signer:admission.signer,authorityClass:admission.authorityClass,nonce:request.authorization.nonce,recordedAt:timestamp,artistId:artist,bindingHash:state.binding.bindingHash,disputeRecordHash:op===44n?Z:state.head.disputeRecordHash,previousRecordHash:op===44n?state.head.disputeRecordHash:op===45n?state.head.counterStatementRecordHash:state.head.counterStatementRecordHash===Z?state.head.disputeRecordHash:state.head.counterStatementRecordHash,standing:copy(request.standing),governanceActionId:governance.actionId};
      record.recordHash=a.artistAttributionDisputeRecordHash(coordinates,record);if(op===44n)record.disputeRecordHash=record.recordHash;
      detail={operationId:op,p:request.filing,standing:request.standing,a:request.authorization,admission,proof,...(op===61n?{}:{context:governed?context():emptyContext,g:governance}),head:copy(state.head),ep:H(3500),rp:H(3501)};
      if(op===44n){newState=4n;Object.assign(newHead,{disputeRecordHash:record.recordHash,counterStatementRecordHash:Z,restoreState:state.state===5n?state.head.restoreState:state.state,open:true,reopened:state.state===5n});}
      if(op===45n)newHead.counterStatementRecordHash=record.recordHash;
      if(op===61n){newState=state.head.restoreState;newHead.open=false;newHead.revocationReason=0n;outcome={recordHash:record.recordHash,counterStatementRecordHash:state.head.counterStatementRecordHash,restoredState:newState};}
    }else if(op===46n){const ctx=context();record={terms:request.resolution,actionId:governance.actionId,actor:caller,proposer:g.caller,actionClass:1n,restoredState:ctx.restoredState,resolvedAt:timestamp,previousResolutionActionId:state.head.resolutionActionId,witnessHash:keccak256(a.encodeArtistAttributionGovernanceWitness(governance))};detail={operationId:op,p:request.resolution,b:state.binding,context:ctx,g:governance,ep:H(3500),rp:H(3501)};newState=record.restoredState;Object.assign(newHead,{resolutionActionId:record.actionId,open:false,revocationReason:request.resolution.resolution===2n?4n:0n});}
    else if(op===47n){const admission={binding_:state.binding,authorityHead,guardianSet:priorRepudiation.capturedGuardianSet,stagedAt:timestamp,executableAt:timestamp+259200n,windowRevision:1n};record={...copy(priorRepudiation),authorityHead:copy(authorityHead),recordHash:Z,terms:request.filing,nonce:request.authorization.nonce,stagedAt:timestamp,executableAt:admission.executableAt};record.recordHash=a.artistAttributionRepudiationRecordHash(coordinates,record);detail={operationId:op,p:request.filing,a:request.authorization,admission,proof};pending=record.recordHash;terminal={phase:1n,actor:ZA,reasonHash:Z,recordedAt:0n};}
    else{record=copy(priorRepudiation);detail={operationId:op,r:record};pending=Z;terminal={phase:op===48n?2n:op===49n?3n:4n,actor:caller,reasonHash:op===48n?request.reasonHash:op===50n?record.terms.reasonHash:Z,recordedAt:timestamp};
      if(op===50n){newState=5n;newHead.revocationReason=3n;}
      if(op===48n){
        contest=empty(c.identity,'identityContestRecord');Object.assign(contest,{terms:{artistId:artist,subjectRecordHash:Z,evidenceHash:record.recordHash,reasonHash:request.reasonHash},contester:caller,contestedAt:timestamp,priorStatus:state.identity.status,guardianSetRecordHash:record.capturedGuardianSet});
        contest.recordHash=keccak256(coder.encode(['bytes32','uint256','address','bytes32','address','bytes32','bytes32','bytes32','uint64'],['0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb',chainId,registry,artist,caller,Z,record.recordHash,request.reasonHash,timestamp]));
        cause=empty(c.identity,'identityContestCause');Object.assign(cause.facts,{artistId:artist,kind:1n,referenceHash:contest.recordHash,actor:caller,reasonHash:request.reasonHash,evidenceHash:record.recordHash,enteredAt:timestamp,incumbent:state.identity.authorityAddress,authorityClass:state.identity.authorityClass,priorStatus:state.identity.status});
        cause.causeHash=keccak256(coder.encode(['bytes32','uint256','address','address',c.identity.getFunction('identityContestCause').outputs[0].components[1]],[id('6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1'),chainId,registry,owners[2],cause.facts]));
        detail.proof={collectionId:cid,repudiationRecordHash:record.recordHash,capturedGuardianSet:record.capturedGuardianSet,currentGuardianSet:record.capturedGuardianSet,vetoer:caller,reasonHash:request.reasonHash,vetoedAt:timestamp};detail.contest=contest.recordHash;
      }
    }
    const value=record.recordHash??record.actionId,envelope={version:1n,configurationHash:H(7000),operation:op,actor:caller,value,before_:before,after_:after,payload:a.encodeArtistAttributionArchiveDetail(detail)},raw=a.encodeArtistAttributionArchiveEnvelope(envelope),evidenceId=a.artistAttributionEvidenceId(coordinates,coordinator,op,caller,value),pointer=A(1100);
    const attrNative=[10n,44n,45n,47n,61n].includes(op)?[{operation:op,artistId:op===10n?Z:artist,collectionId:cid,recordHash:value}]:[];
    const identityNative=op===48n?[contest.recordHash,cause.causeHash].map(recordHash=>({operation:48n,artistId:artist,collectionId:cid,recordHash})):[];
    let cancellation=null;
    if(config.activeNotice&&!governed&&[44n,45n,47n,49n,61n].includes(op)){
      cancellation=zero(dormancyRecord.outputs[2]);Object.assign(cancellation,{noticeHash:notice.recordHash,actor:op===49n?caller:proof.signer,authorityClass:1n,observedAt:timestamp});
      cancellation.recordHash=keccak256(coder.encode(['bytes32','uint256','address','address',dormancyRecord.outputs[2],'uint256'],[id('6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1'),chainId,registry,owners[2],cancellation,1n]));
      identityNative.push({operation:42n,artistId:artist,collectionId:0n,recordHash:cancellation.recordHash});
    }
    const oldTerminal=state.rawPending!==Z&&state.priorTerminal.phase===1n&&[44n,47n].includes(op)?{phase:5n,actor:ZA,reasonHash:op===44n?value:Z,recordedAt:timestamp}:null;
    if(op===44n&&oldTerminal)pending=Z;
    return {record,detail,value,envelope,raw,evidenceId,pointer,contentHash:keccak256(raw),newHead,newState,terminal,pending,outcome,contest,cause,attrNative,identityNative,after,oldTerminal,cancellation};
  }
  function dispatchAddress(target){if(target===registry)return c.registry;if(target===coordinator)return c.coordinator;if(target===archive)return c.archive;if(target===coreAddress)return core;if(target===mintManager)return manager;if(owners.includes(target))return owner;if(target===caller&&!governed)return safeABI;return null;}
  async function call(tx){
    const target=getAddress(tx.to),tag=Number(tx.blockTag);state.reads.push(copy(tx));if(state.mutate){const m=state.mutate;state.mutate=null;m();}
    const host=dispatchAddress(target);if(!host)return g.provider.call(tx);
    const parsed=host.parseTransaction({data:tx.data}),name=parsed.name,args=parsed.args,after=tag>=22?state.after:null,enc=values=>host.encodeFunctionResult(name,values);
    if(state.override){const v=state.override({target,tag,name,args,tx,host,after});if(v!==undefined)return v;}
    if(target===caller&&!governed){if(name==='nonce')return enc([state.safeNonce+(after?1n:0n)]);if(name==='getTransactionHash')return enc([safeHash(chainId,caller,Array.from(args))]);throw Error('Unexpected Safe fixture getter');}
    if(methods.includes(name)){if(target!==registry||name!==kind)throw Error('Unexpected Registry writer');if(state.simulationError)throw state.simulationError;if(state.simulationRaw!==null)return state.simulationRaw;return enc([48n,49n,50n].includes(op)?[]:[produce(BigInt(header(tag).timestamp)).value]);}
    switch(name){
      case 'suiteConfiguration':return enc([suite]);case 'configurationHash':return enc([H(7000)]);case 'deploymentChainId':return enc([chainId]);
      case 'core':return enc([coreAddress]);case 'mintManager':return enc([mintManager]);case 'artistRegistry':return enc([registry]);case 'operationCoordinator':return enc([coordinator]);case 'archiveV2':return enc([archive]);
      case 'domainId':return enc([snapshots[owners.indexOf(target)].domainId]);case 'artistRegistryCutover':return enc([!state.current,ZA,0n]);case 'getSatellitePointer':return enc([registry,codeHash,false,Z,'0x00000000',ZA,0n,Z,Z,1n]);case 'collectionExists':return enc([true]);case 'governanceAuthority':return enc([g.deployment.executor.address]);
      case 'ownerStateSnapshotV2':{const i=owners.indexOf(target);return enc([after?after.after[i]:state.snapshots[i]]);}
      case 'binding':return enc([state.binding]);case 'attributionState':return enc([after?after.newState:state.state,2n]);case 'attributionDispute':return enc([after?after.newHead:state.head]);case 'rawPendingRepudiation':return enc([after?after.pending:state.rawPending]);
      case 'attributionClaims':return enc(after&&op===10n?[after.record.index,after.record.recordHash]:state.claims);
      case 'attributionClaimRecord':if(after&&op===10n&&args[0]===after.value)return enc([after.record]);break;
      case 'attributionDisputeRecord':if(after&&[44n,45n,61n].includes(op)&&args[0]===after.value)return enc([after.record]);if(args[0]===opening.recordHash)return enc([opening]);break;
      case 'attributionDisputeResolution':if(after&&op===46n&&args[0]===after.value)return enc([after.record]);break;
      case 'attributionDisputeWithdrawal':if(after?.outcome)return enc([after.outcome]);return enc([empty(c.attribution,name)]);
      case 'attributionRepudiationRecord':if(after&&op===47n&&args[0]===after.value)return enc([after.record]);if(args[0]===priorRepudiation.recordHash)return enc([priorRepudiation]);break;
      case 'attributionRepudiationTerminal':return enc([after&&args[0]===after.value?after.terminal:after?.oldTerminal??state.priorTerminal]);
      case 'attributionDisputeDigest':case 'attributionRepudiationDigest':return enc([prepared.signingPayload.digest]);
      case 'attributionDisputeOpeningContext':case 'attributionDisputeResolutionContext':return enc([context()]);
      case 'identity':return enc([{...state.identity,...(after&&(op===49n||after.cancellation)?{lastAuthorityActionAt:BigInt(header(tag).timestamp)}:{}),...(after?.cancellation?{status:1n}:{}),...(after&&op===48n?{status:4n}:{})}]);
      case 'authorityState':return enc([state.identity.authorityAddress,state.identity.authorityClass,after&&op===48n?4n:state.identity.status,state.identity.identityRecordHash]);
      case 'lastArtistTransition':case 'latestIdentityContestDismissal':return enc([Z]);case 'latestIdentityContest':return enc([after?.contest?.recordHash??Z]);case 'dormancyNotice':return enc(after?.cancellation?[notice.recordHash,2n,after.cancellation.recordHash]:state.notice);case 'nonceUsed':return enc([after?true:state.nonceUsed]);
      case 'dormancyRecord':if(args[0]===notice.recordHash)return enc([notice,after?.cancellation?2n:state.notice[1],after?.cancellation??zero(dormancyRecord.outputs[2])]);break;
      case 'identityContestRecord':if(after?.contest)return enc([after.contest]);break;case 'identityContestCause':if(after?.cause)return enc([after.cause]);break;
      case 'artistNativeReceiptCount':return enc([after?BigInt(target===owners[4]?after.attrNative.length:after.identityNative.length):0n]);
      case 'artistNativeReceiptAt':if(after)return enc([(target===owners[4]?after.attrNative:after.identityNative)[Number(args[0])]]);break;
      case 'artistNativeReceiptRevisionAt':return enc([11n]);
      case 'artistEvidenceMetadataV2':if(after&&args[0]===after.evidenceId)return enc([after.contentHash,after.pointer,BigInt((after.raw.length-2)/2),22n]);break;
      case 'artistEvidenceBytesV2':if(after&&args[0]===after.evidenceId)return enc([after.raw]);break;
    }
    throw Error(`Unimplemented exact fixture getter ${name}`);
  }
  const provider={getNetwork:async()=>({chainId}),getBlock:async tag=>header(tag),getCode:async(address,tag)=>{const target=getAddress(address);if(state.codeOverride){const v=state.codeOverride(target,Number(tag));if(v!==undefined)return v;}return state.codes.get(target)??await g.provider.getCode(target,tag);},call,getTransactionReceipt:async hash=>state.receipts.get(hash)??await g.provider.getTransactionReceipt(hash),getTransaction:async hash=>{if(state.transactionHook)state.transactionHook(hash);return state.transactions.get(hash)??await g.provider.getTransaction(hash);}};
  const options={blockTag:20,gasLimit:9_000_000n};
  async function governanceCapture(){return gw.captureGovernanceExecutorV2(provider,g.deployment,g.caller,g.request,g.options);}
  function event(name,args,address=owners[4]){const encoded=events.encodeEventLog(events.getEvent(name),args);return {address,...encoded};}
  function mine(capture,mode='direct'){
    const timestamp=BigInt(header(22).timestamp),f=produce(timestamp),r=f.record,logs=[];state.after=f;state.codes.set(f.pointer,`0x00${f.raw.slice(2)}`);
    const cancellationEvents=()=>f.cancellation?[event('ArtistDormancyCancelled',[1n,artist,notice.recordHash,f.cancellation.actor,f.cancellation.authorityClass,f.cancellation.recordHash],owners[2]),event('ArtistDormancyCancellationContext',[1n,artist,f.cancellation.recordHash,{chainId,registry,identityOwner:owners[2],recorder:f.cancellation.actor,recorderAuthorityClass:f.cancellation.authorityClass},f.cancellation,1n],owners[2])]:[];
    if(op!==49n)logs.push(...cancellationEvents());
    if(op===10n)logs.push(event('AttributionClaimFiled',[1n,cid,caller,r.evidenceHash,r.reasonHash,r.reasonURI,timestamp,r.recordHash]));
    else if([44n,45n,61n].includes(op)){
      if(op===44n)logs.push(event('AttributionDisputeOpened',[1n,cid,r.signer,2n,r.authorityClass,r.terms.evidenceHash,r.terms.reasonHash,r.nonce,timestamp,r.recordHash]));
      if(op===45n)logs.push(event('AttributionCounterStatementRecorded',[1n,cid,r.disputeRecordHash,r.signer,2n,r.authorityClass,r.terms.evidenceHash,r.terms.reasonHash,r.nonce,timestamp,r.recordHash]));
      if(op===61n)logs.push(event('AttributionDisputeWithdrawn',[1n,cid,r.disputeRecordHash,r.signer,2n,r.authorityClass,r.terms.evidenceHash,r.terms.reasonHash,r.nonce,timestamp,r.recordHash,f.outcome.counterStatementRecordHash,f.outcome.restoredState]));
      if(op!==45n)logs.push(event('ArtistAttributionStateChanged',[1n,cid,f.newState,2n,state.state,caller,r.authorityClass,r.recordHash,r.terms.reasonHash,'']));
      logs.push(event('AttributionDisputeRecordContext',[1n,chainId,registry,r.recordHash,r.terms.disputeAction,artist,r.bindingHash,r.disputeRecordHash,r.previousRecordHash,r.standing.artistId,r.standing.delegation,r.governanceActionId]));
      if(op===44n&&f.oldTerminal)logs.push(event('AttributionRepudiationInvalidated',[1n,cid,state.rawPending,Z,r.recordHash]));
    }else if(op===46n){logs.push(event('AttributionDisputeResolved',[1n,cid,r.terms.disputeRecordHash,r.terms.resolution,r.restoredState,r.terms.evidenceHash,r.terms.reasonHash,r.terms.counterStatementRecordHash,r.actionId]));logs.push(event('ArtistAttributionStateChanged',[1n,cid,r.restoredState,2n,4n,caller,0n,r.terms.disputeRecordHash,r.terms.reasonHash,'']));}
    else if(op===47n){if(f.oldTerminal)logs.push(event('AttributionRepudiationInvalidated',[1n,cid,state.rawPending,a.artistAttributionAuthorityHeadHash(r.authorityHead),Z]));logs.push(event('AttributionRepudiationStaged',[1n,cid,artist,r.signer,2n,r.authorityClass,r.terms.evidenceHash,r.terms.reasonHash,r.nonce,timestamp,r.executableAt,r.recordHash]));logs.push(event('AttributionRepudiationContext',[1n,chainId,registry,r.recordHash,r.bindingHash,r.authorityHead,r.capturedGuardianSet,r.windowRevision]));}
    else if(op===48n){logs.push(event('AttributionRepudiationVetoed',[1n,cid,caller,r.recordHash,request.reasonHash]));logs.push(event('ArtistIdentityContested',[1n,artist,caller,Z,r.recordHash,request.reasonHash,timestamp,f.contest.recordHash],owners[2]));logs.push(event('ArtistIdentityContestCauseCaptured',[1n,artist,f.cause.causeHash,...Object.values(f.cause.facts).slice(1)],owners[2]));}
    else if(op===49n)logs.push(event('AttributionRepudiationCancelled',[1n,cid,caller,r.recordHash,r.authorityClass]));
    else logs.push(event('ArtistAttributionStateChanged',[1n,cid,5n,2n,state.state,caller,r.authorityClass,r.recordHash,r.terms.reasonHash,'']));
    if(op===49n)logs.push(...cancellationEvents());
    logs.push({address:archive,...c.archive.encodeEventLog(c.archive.getEvent('ArtistArchiveEvidenceAppendedV2'),[f.evidenceId,1n,f.contentHash,f.pointer,BigInt((f.raw.length-2)/2)])});
    let hash=H(8000),tx={from:caller,to:registry,data:capture.prepared.call.data,value:0n},receiptOptions={execution:'direct'};
    if(governed){const mined=g.mine(config.governanceCapture,mode);hash=mined.hash;tx=copy(mined.tx);delete tx.hash;receiptOptions=copy(mined.options);delete receiptOptions.outerValue;logs.push(...mined.receipt.logs.map(({address,topics,data})=>({address,topics,data})));}
    else if(mode!=='direct'){const values=[registry,0n,capture.prepared.call.data,0n,1000000n,0n,0n,ZA,ZA,state.safeNonce],expectedSafeTxHash=safeHash(chainId,caller,values);tx={from:A(9999),to:caller,data:safeABI.encodeFunctionData('execTransaction',[...values.slice(0,9),'0x1234']),value:0n};const sf=mode==='indexed'?indexedSafe:safeABI;logs.push({address:caller,...sf.encodeEventLog(sf.getEvent('ExecutionSuccess'),[expectedSafeTxHash,0n])});receiptOptions={execution:'safe',nonce:state.safeNonce,safeCodeHash:codeHash,expectedSafeTxHash};}
    const block=header(22),transaction={...tx,hash,chainId,blockNumber:22,blockHash:block.hash},receipt={status:1,hash,from:tx.from,to:tx.to,blockNumber:22,blockHash:block.hash,logs:logs.map((v,index)=>({...v,index,removed:false,transactionHash:hash,blockNumber:22,blockHash:block.hash}))};
    state.transactions.set(hash,transaction);state.receipts.set(hash,receipt);return {hash,receipt,transaction,options:receiptOptions,facts:f};
  }
  return {provider,state,deployment:d,caller,request,prepared,options,governed,governance:g,governanceCapture,config,produce,mine,event,events,header,snapshots,binding,head,identity,opening,priorRepudiation,historyDeployment:{chainId,registry,core:coreAddress,mintManager,coordinator,attribution:pin(owners[4]),archive:pin(archive),historyDependencies:[]},coordinates,runtime,codeHash,owners,claimDoc,reasonDoc};
}
