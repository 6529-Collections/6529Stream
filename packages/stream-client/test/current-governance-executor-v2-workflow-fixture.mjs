// Compiler-encoded consistency mock. No native Executor, Safe, target, or signature execution.
import { AbiCoder, Interface, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as pure from '../dist/current-governance-executor-v2.js';
import { governanceExecutorV2Interfaces as compiler } from './current-governance-executor-v2-source-fixture.mjs';
export const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, '0')}`);
export const H = n => `0x${BigInt(n).toString(16).padStart(64, '0')}`;
export const Z = ZeroHash, ZA = ZeroAddress, coder = AbiCoder.defaultAbiCoder();
export const executorABI = compiler.StreamGovernanceExecutor, rolesABI = compiler.StreamRoleRegistry;
export const safeABI = new Interface([
  'function nonce() view returns(uint256)',
  'function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)',
  'function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool)',
  'event ExecutionSuccess(bytes32 txHash,uint256 payment)', 'event ExecutionFailure(bytes32 txHash,uint256 payment)'
]);
const indexedSafe = new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']);
const types = { SafeTx: ['to:address','value:uint256','data:bytes','operation:uint8','safeTxGas:uint256','baseGas:uint256','gasPrice:uint256','gasToken:address','refundReceiver:address','nonce:uint256'].map(s => { const [name,type] = s.split(':'); return {name,type}; }) };
export const safeHash = (chainId, safe, values) => TypedDataEncoder.hash({chainId,verifyingContract:safe}, types, Object.fromEntries(types.SafeTx.map((v,i) => [v.name,values[i]])));
export const copy = v => structuredClone(v);
const methods = ['publishGovernanceCallData','scheduleGovernanceAction','scheduleGovernanceBatch','executeGovernanceAction','executeGovernanceBatch','cancelGovernanceAction','vetoTerminalFreeze','materializeExpiredAction','pruneElapsedTerminalFreezeActions'];
export { methods };
function zero(param) {
  if (param.baseType === 'array') return param.arrayLength === -1 ? [] : Array.from({length:param.arrayLength},()=>zero(param.arrayChildren));
  if (param.baseType === 'tuple') return Object.fromEntries(param.components.map(p=>[p.name,zero(p)]));
  if (param.type === 'bool') return false;
  if (param.type === 'address') return ZA;
  if (param.type === 'string') return '';
  if (param.type === 'bytes') return '0x';
  if (param.type.startsWith('bytes')) return `0x${'00'.repeat(Number(param.type.slice(5)))}`;
  return 0n;
}
export function setup(method = 'executeGovernanceBatch', config = {}) {
  if (!methods.includes(method)) throw Error('Fixture unknown method');
  const chainId = 31337n, executor = A(100), caller = A(101), roles = A(102), target = A(103), link = A(104), pointer = A(105);
  const runtime = '0x6001600055', codeHash = keccak256(runtime), pin = address => ({address,codeHash});
  const d = {chainId,executor:pin(executor),linkedDependencies:[pin(link)],roleRegistry:pin(roles),targets:[pin(target)]};
  const now = 1_000_020n, historicalTimestamp = 600_000n;
  const state = { time: new Map([[5,historicalTimestamp],[20,now],[21,now+1n],[22,now+2n]]), blocks:new Map(), codes:new Map(),
    receipts:new Map(),transactions:new Map(),reads:[],calls:[], nonceBefore:6n,pendingBefore:0n,publishedBefore:false,sealed:true,bound:true,
    granted:true,proposer:true,canceller:true,redundant:true,root:caller,rootRevision:1n,roleDrift:false,sourceDrift:false,
    mutate:null,readOverride:null,simulateError:null,simulateRaw:null,after:null,safeNonce:9n,afterSafeNonce:10n,
    beforePages:new Map(), schedules:new Map(), actions:new Map() };
  [executor,caller,roles,target,link,A(106),A(107)].forEach(a=>state.codes.set(a,runtime));
  const actionClass = config.actionClass ?? (['vetoTerminalFreeze','pruneElapsedTerminalFreezeActions'].includes(method) ? 2n : 0n);
  const scheduling = method.startsWith('schedule'), existing = ['executeGovernanceAction','executeGovernanceBatch','cancelGovernanceAction','vetoTerminalFreeze','materializeExpiredAction'].includes(method);
  const data = config.native ? '0x' : '0x12345678'; if (config.native) state.codes.set(target,'0x');
  const calls = Array.from({length:config.batchSize ?? 1},(_,i)=>({target,value:config.value ?? 7n,selector:data==='0x'?'0x00000000':data,callDataHash:keccak256(data),scopeHash:H(200+i),oldValueHash:H(300+i),newValueHash:H(400+i)}));
  const callDatas = calls.map(()=>data), aggregate = pure.governanceExecutorV2BatchHashes(calls), scope = calls[0].scopeHash;
  const notBefore = scheduling ? now + pure.governanceExecutorV2MinimumDelay(actionClass) + 100n
    : method === 'vetoTerminalFreeze' ? now+100n : now-10n;
  const expiresAfter = method === 'materializeExpiredAction' ? now-1n : scheduling ? notBefore+604900n : now+700000n;
  const requestFields = {actionClass,notBefore,expiresAfter,reasonHash:H(500),reasonURI:'ipfs://fixture',manifestHash:H(501)};
  const single = {...requestFields,target,value:calls[0].value,selector:calls[0].selector,callData:data,scopeHash:calls[0].scopeHash,oldValueHash:calls[0].oldValueHash,newValueHash:calls[0].newValueHash};
  const identity = {...requestFields,...aggregate,nonce:5n}; delete identity.reasonURI;
  const actionId = pure.governanceExecutorV2ActionId({chainId,executor},identity);
  const action = {status:1n,actionClass,target,value:calls.reduce((a,c)=>a+c.value,0n),selector:calls[0].selector,callHash:aggregate.callsHash,
    scopeHash:aggregate.scopeHash,oldValueHash:aggregate.oldValueHash,newValueHash:aggregate.newValueHash,notBefore,expiresAfter,
    proposer:caller,executor:ZA,canceller:ZA,vetoer:ZA,reasonHash:requestFields.reasonHash,reasonURI:requestFields.reasonURI,manifestHash:requestFields.manifestHash};
  const publicationPayload = coder.encode(['bytes[]'],[callDatas]); state.codes.set(pointer,`0x00${publicationPayload.slice(2)}`);
  const catalog = [H(600),H(601),2n,1n];
  function header(tag) { const n=Number(tag), time=state.time.get(n) ?? 1_000_000n+BigInt(n); return {number:n,hash:state.blocks.get(n)??H(10000+n),timestamp:Number(time)}; }
  function event(iface,name,args,address=executor) { const encoded=iface.encodeEventLog(iface.getEvent(name),args); return {address,...encoded}; }
  function receipt(hash,number,logs,tx) {
    const h=header(number); const decorated=logs.map((l,index)=>({...l,index,removed:false,transactionHash:hash,blockNumber:number,blockHash:h.hash}));
    const t={hash,blockNumber:number,blockHash:h.hash,chainId,from:caller,to:executor,value:0n,data:'0x',...tx};
    const r={hash,blockNumber:number,blockHash:h.hash,from:t.from,to:t.to,status:1,logs:decorated};
    state.receipts.set(hash,r);state.transactions.set(hash,t);return r;
  }
  function guardian(scopes) {
    const global=id('ROLE_TERMINAL_FREEZE_VETO'), domain=id('6529STREAM_TERMINAL_GUARDIAN_CONFIG_V1'), holderDomain=id('6529STREAM_TERMINAL_GUARDIAN_HOLDER_V1');
    let commitment=Z;
    for(let i=0;i<=scopes.length;i++) {
      const role=i===0?global:keccak256(coder.encode(['bytes32','bytes32'],[global,scopes[i-1]]));
      const chain=state.roleDrift?H(799):H(700), revision=1n, holders=i===0?[A(106),A(107)]:[];
      commitment=i===0?keccak256(coder.encode(['bytes32','uint256','address','address','bytes32','bytes32','uint64'],[domain,chainId,executor,roles,codeHash,chain,revision]))
        :keccak256(coder.encode(['bytes32','bytes32','bytes32','bytes32','bytes32','uint64'],[id('6529STREAM_TERMINAL_GUARDIAN_SCOPE_V1'),commitment,scopes[i-1],role,chain,revision]));
      commitment=keccak256(coder.encode(['bytes32','bytes32','bytes32','uint256'],[holderDomain,commitment,role,holders.length]));
      holders.forEach((h,j)=>commitment=keccak256(coder.encode(['bytes32','bytes32','bytes32','uint256','address','bytes32'],[holderDomain,commitment,role,j,h,codeHash])));
    }
    return keccak256(coder.encode(['bytes32','bytes32','uint256'],[domain,commitment,scopes.length]));
  }
  const scopes=[...new Set(calls.map(c=>c.scopeHash))];
  function scheduledEvent(id,a,nonce) {return event(executorABI,'GovernanceActionScheduled',[1n,id,a.actionClass,a.target,a.value,a.selector,a.callHash,a.scopeHash,a.oldValueHash,a.newValueHash,a.notBefore,a.expiresAfter,nonce,a.proposer,a.reasonHash,a.reasonURI,a.manifestHash]);}
  function membership(row,present,cause,index,count) {return event(executorABI,'TerminalFreezeActionMembershipUpdated',[1n,row.scopeHash,row.actionId,row.proposer,present,cause,row.usesRootCapacity,row.vetoDeadline,BigInt(index),BigInt(count)]);}
  function addSchedule(id,a,nonce,memberScopes,usesRoot=true,hash=H(800),number=5) {
    const logs=[], members=memberScopes.map(s=>({scopeHash:s,actionId:id,proposer:a.proposer,usesRootCapacity:usesRoot,vetoDeadline:a.notBefore}));
    for(const row of members) logs.push(membership(row,true,1n,0,1));
    const g=a.actionClass===2n?guardian(memberScopes):null;
    if(g) logs.push(event(executorABI,'TerminalFreezeGuardianConfigCommitted',[1n,id,g]));
    const index=logs.length;logs.push(scheduledEvent(id,a,nonce));logs.push(event(executorABI,'GovernanceActionPolicyValidated',[1n,id,1n,catalog[0],catalog[1]]));
    receipt(hash,number,logs);const loc={transactionHash:hash,logIndex:index};
    state.schedules.set(id,{locator:loc,action:copy(a),members,guardian:g});state.actions.set(id,copy(a));
    return loc;
  }
  const historical = addSchedule(actionId,action,5n,actionClass===2n?scopes:[]);
  if(existing) state.pendingBefore=1n;
  if((existing||method==='pruneElapsedTerminalFreezeActions')&&actionClass===2n) for(const row of state.schedules.get(actionId).members) state.beforePages.set(row.scopeHash,[row]);
  if(method==='pruneElapsedTerminalFreezeActions') state.pendingBefore=1n;
  state.publishedBefore=existing||method==='scheduleGovernanceBatch';
  let request;
  switch(method) {
    case 'publishGovernanceCallData':request={method,callDatas};break;
    case 'scheduleGovernanceAction':request={method,request:single};break;
    case 'scheduleGovernanceBatch':request={method,...requestFields,...aggregate,calls};delete request.callsHash;break;
    case 'executeGovernanceAction':request={method,actionId,call:calls[0],callData:data};break;
    case 'executeGovernanceBatch':request={method,actionId,calls,callDatas};break;
    case 'cancelGovernanceAction':case 'vetoTerminalFreeze':request={method,actionId,reasonHash:Z};break;
    case 'materializeExpiredAction':request={method,actionId};break;
    case 'pruneElapsedTerminalFreezeActions':request={method,scopeHash:scope};break;
  }
  const options={blockTag:20,gasLimit:9_000_000n,...(existing?{schedule:historical}:{}),membershipSchedules:[{...historical,actionId}]};
  const emptyAction=zero(executorABI.getFunction('governanceAction').outputs[0]);
  const getAfter=tag=>Number(tag)>=22&&state.after;
  async function call(tx) {
    const tag=Number(tx.blockTag);state.reads.push({to:tx.to,data:tx.data,tag,from:tx.from,value:tx.value,gasLimit:tx.gasLimit});
    if(state.mutate){const m=state.mutate;state.mutate=null;m();}
    const host=getAddress(tx.to)===executor?executorABI:getAddress(tx.to)===roles?rolesABI:getAddress(tx.to)===caller?safeABI:null;
    if(!host) throw Error('Fixture unknown RPC target');
    const parsed=host.parseTransaction({data:tx.data}),name=parsed.name,args=parsed.args;const after=getAfter(tag);
    if(state.readOverride) {const override=state.readOverride({name,args,tag,tx,host});if(override!==undefined)return override;}
    const enc=values=>host.encodeFunctionResult(name,values);
    if(host===safeABI) {
      if(name==='nonce')return enc([after?state.afterSafeNonce:state.safeNonce]);
      if(name==='getTransactionHash')return enc([safeHash(chainId,caller,Array.from(args))]);
      throw Error('Fixture unexpected Safe method');
    }
    if(host===rolesABI) {
      if(name==='owner')return enc([executor]);
      if(name==='isRoleRedundant')return enc([state.redundant]);
      if(name==='hasRole')return enc([state.granted]);
      if(name==='roleMutationState')return enc([state.roleDrift?H(799):H(700),1n]);
      if(name==='roleHolderCount')return enc([args[0]===id('ROLE_TERMINAL_FREEZE_VETO')?2n:0n]);
      if(name==='roleHolderAt'&&args[0]===id('ROLE_TERMINAL_FREEZE_VETO')&&args[1]<2n)return enc([args[1]===0n?A(106):A(107)]);
      throw Error('Fixture unexpected RoleRegistry method');
    }
    if(methods.includes(name)) {
      state.calls.push(copy(tx));if(state.simulateError)throw state.simulateError;if(state.simulateRaw!==null)return state.simulateRaw;
      if(name==='publishGovernanceCallData')return enc([pointer]);
      if(name.startsWith('schedule'))return enc([pure.governanceExecutorV2ActionId({chainId,executor},pure.governanceExecutorV2ScheduleIdentity(request,state.nonceBefore))]);
      if(name==='pruneElapsedTerminalFreezeActions')return enc([BigInt((state.beforePages.get(args[0])??[]).filter(r=>BigInt(header(tag).timestamp)>=r.vetoDeadline).length)]);
      return enc([]);
    }
    switch(name) {
      case 'systemManifestBootstrapState':{const v=executorABI.getFunction(name).outputs.map(zero);v[0]=state.bound;v[1]=state.sealed;v[2]=roles;v[3]=codeHash;return enc(v);}
      case 'currentAction':return enc([false,Z,0n,Z,Z,Z]);
      case 'governanceNonce':return enc([after?after.nonce:state.nonceBefore]);
      case 'pendingScheduledActionCount':return enc([after?after.pending:state.pendingBefore]);
      case 'publishedCallData':return enc([(after?after.published:state.publishedBefore)?pointer:ZA]);
      case 'scheduledCallDataPointer':return enc([pointer]);
      case 'scheduledCallData':return enc([callDatas]);
      case 'governanceAction':case 'governanceActionFacts':{
        const a=copy(after?.actions?.get(args[0])??state.actions.get(args[0])??emptyAction);
        if(name==='governanceActionFacts')return enc([{status:a.status,actionClass:a.actionClass,callHash:a.callHash,notBefore:a.notBefore,expiresAfter:a.expiresAfter}]);
        if(a.status===1n&&BigInt(header(tag).timestamp)>a.expiresAfter)a.status=4n;return enc([a]);
      }
      case 'governanceRootState':return enc([state.root,codeHash,state.rootRevision]);
      case 'owner':return enc([state.root]);
      case 'governanceActionPolicyState':return enc(state.sourceDrift?[catalog[0],H(602),2n,2n]:catalog);
      case 'proposerConfig':return enc([state.proposer,1n,H(701)]);
      case 'isProposer':return enc([state.proposer]);
      case 'isCanceller':return enc([state.canceller]);
      case 'roleRegistry':return enc([roles]);
      case 'terminalFreezeLiveActionCaps':return enc([64n,48n,8n]);
      case 'terminalFreezeActionPage':{const list=(after?.pages??state.beforePages).get(args[0])??[];return enc([list.map(v=>v.actionId),list.map(v=>v.vetoDeadline),BigInt(list.length)]);}
      case 'terminalFreezeLiveActionUsage':{const list=(after?.pages??state.beforePages).get(args[0])??[];return enc([BigInt(list.length),BigInt(list.filter(v=>!v.usesRootCapacity).length),BigInt(list.filter(v=>!v.usesRootCapacity&&v.proposer===args[1]).length)]);}
      case 'terminalFreezeGuardianConfigCommitment':return enc([after?.guardians?.get(args[0])??state.schedules.get(args[0])?.guardian??Z]);
      default:throw Error(`Fixture unexpected Executor method ${name}`);
    }
  }
  const provider={getNetwork:async()=>({chainId}),getBlock:async tag=>header(tag),getCode:async(address,tag)=>{
    if(state.codeOverride){const r=state.codeOverride(getAddress(address),Number(tag));if(r!==undefined)return r;}
    return state.codes.get(getAddress(address))??'0x';},call,
    getTransactionReceipt:async hash=>state.receipts.get(hash)??null,
    getTransaction:async hash=>{if(state.transactionHook)state.transactionHook(hash);return state.transactions.get(hash)??null;}};
  function mine(capture,mode='direct', settings={}) {
    const q=capture.prepared.request,ob=capture.observation,scheduled=q.method.startsWith('schedule'),executing=q.method.startsWith('execute');
    const next={nonce:ob.nonce+(scheduled?1n:0n),pending:ob.pending+(scheduled?1n:ob.history?-1n:0n),published:state.publishedBefore||q.method==='publishGovernanceCallData'||scheduled,
      pages:new Map([...state.beforePages].map(([k,v])=>[k,copy(v)])),actions:new Map(state.actions),guardians:new Map()};
    const logs=[],timestamp=BigInt(header(22).timestamp);
    if((q.method==='publishGovernanceCallData'||q.method==='scheduleGovernanceAction')&&!state.publishedBefore)logs.push(event(executorABI,'GovernanceCallDataPublished',[1n,pure.governanceExecutorV2PublicationKey(ob.callDatas),pointer,capture.prepared.caller]));
    for(const page of ob.memberships){const list=copy(page.rows);const remove=(i,cause)=>{const row=list[i];list[i]=list.at(-1);list.pop();logs.push(membership(row,false,cause,i,list.length));};
      if(scheduled||q.method==='pruneElapsedTerminalFreezeActions'){
        for(let i=0;i<list.length;){if(timestamp>=list[i].vetoDeadline)remove(i,2n);else i++;}
        if(scheduled){const r=q.method==='scheduleGovernanceAction'?q.request:q;const row={scopeHash:page.scopeHash,actionId:ob.actionId,proposer:capture.prepared.caller,usesRootCapacity:capture.prepared.caller===state.root,vetoDeadline:r.notBefore};list.push(row);logs.push(membership(row,true,1n,list.length-1,list.length));}
      }else{const index=list.findIndex(v=>v.actionId===q.actionId);if(index>=0)remove(index,3n);}
      next.pages.set(page.scopeHash,list);
    }
    let endAction;
    if(scheduled){
      const r=q.method==='scheduleGovernanceAction'?q.request:q,c=q.method==='scheduleGovernanceAction'?[{target:r.target,value:r.value,selector:r.selector,callDataHash:keccak256(r.callData),scopeHash:r.scopeHash,oldValueHash:r.oldValueHash,newValueHash:r.newValueHash}]:q.calls,h=pure.governanceExecutorV2BatchHashes(c);
      endAction={...action,status:1n,actionClass:r.actionClass,notBefore:r.notBefore,expiresAfter:r.expiresAfter,proposer:capture.prepared.caller,target:c[0].target,value:c.reduce((n,v)=>n+v.value,0n),selector:c[0].selector,callHash:h.callsHash,scopeHash:h.scopeHash,oldValueHash:h.oldValueHash,newValueHash:h.newValueHash};
      if(r.actionClass===2n){logs.push(event(executorABI,'TerminalFreezeGuardianConfigCommitted',[1n,ob.actionId,ob.guardian.commitment]));next.guardians.set(ob.actionId,ob.guardian.commitment);}
      logs.push(scheduledEvent(ob.actionId,endAction,ob.nonce));logs.push(event(executorABI,'GovernanceActionPolicyValidated',[1n,ob.actionId,1n,catalog[0],catalog[1]]));next.actions.set(ob.actionId,endAction);
    }else if(ob.history){const a=ob.history.action,id=q.actionId;
      if(executing){endAction={...a,status:2n,executor:capture.prepared.caller};logs.push(event(executorABI,'GovernanceActionExecuted',[1n,id,a.actionClass,a.target,a.value,a.selector,a.callHash,a.scopeHash,a.oldValueHash,a.newValueHash,capture.prepared.caller,a.manifestHash]));logs.push(event(executorABI,'GovernanceActionPolicyValidated',[1n,id,2n,catalog[0],catalog[1]]));}
      else if(q.method==='cancelGovernanceAction'){endAction={...a,status:3n,canceller:capture.prepared.caller};logs.push(event(executorABI,'GovernanceActionCancelled',[1n,id,a.actionClass,a.target,a.selector,a.callHash,a.scopeHash,capture.prepared.caller,q.reasonHash,'']));}
      else if(q.method==='vetoTerminalFreeze'){endAction={...a,status:5n,vetoer:capture.prepared.caller};logs.push(event(executorABI,'GovernanceActionVetoed',[1n,id,a.actionClass,capture.prepared.caller,a.scopeHash,q.reasonHash]));}
      else{endAction={...a,status:4n};logs.push(event(executorABI,'GovernanceActionExpired',[1n,id,a.actionClass,capture.prepared.caller]));}
      next.actions.set(id,endAction);
    }
    state.after=next; const hash=H(900),tx={from:capture.prepared.caller,to:executor,data:capture.prepared.call.data,value:capture.prepared.call.value};let receiptOptions={execution:'direct'};
    if(mode!=='direct'){
      const values=[executor,capture.prepared.call.value,capture.prepared.call.data,0n,settings.safeTxGas??1000000n,0n,0n,ZA,ZA,state.safeNonce];
      const expectedSafeTxHash=safeHash(chainId,capture.prepared.caller,values);
      tx.from=A(120);tx.to=capture.prepared.caller;tx.value=settings.outerValue??0n;tx.data=safeABI.encodeFunctionData('execTransaction',[...values.slice(0,9),'0x1234']);
      logs.push(event(mode==='indexed'?indexedSafe:safeABI,'ExecutionSuccess',[expectedSafeTxHash,0n],capture.prepared.caller));
      receiptOptions={execution:'safe',nonce:state.safeNonce,outerValue:tx.value,safeCodeHash:codeHash,expectedSafeTxHash};
      if(settings.guardLog)logs.push({address:A(121),topics:[H(122)],data:'0x'});
    }
    const result=receipt(hash,22,logs,tx);return {hash,receipt:result,tx:state.transactions.get(hash),options:receiptOptions};
  }
  function addMember({deadline=now-1n,proposer=A(130),usesRoot=false,memberScope=scope,nonce=8n}={}){
    const a={...action,actionClass:2n,proposer,notBefore:deadline,expiresAfter:now+700000n};
    const aid=pure.governanceExecutorV2ActionId({chainId,executor},{actionClass:a.actionClass,callsHash:a.callHash,scopeHash:a.scopeHash,oldValueHash:a.oldValueHash,newValueHash:a.newValueHash,nonce,notBefore:a.notBefore,expiresAfter:a.expiresAfter,reasonHash:a.reasonHash,manifestHash:a.manifestHash});
    const loc=addSchedule(aid,a,nonce,[memberScope],usesRoot,H(1000+Number(nonce)));
    const row=state.schedules.get(aid).members[0];const list=state.beforePages.get(memberScope)??[];list.push(row);state.beforePages.set(memberScope,list);options.membershipSchedules.push({...loc,actionId:aid});return row;
  }
  return {provider,state,deployment:d,caller,request,options,actionId,action,calls,callDatas,scope,scopes,pointer,codeHash,runtime,now,historical,historyDeployment:{chainId,executor:d.executor,historyDependencies:d.linkedDependencies},mine,addMember,event,receipt,header,guardian};
}
