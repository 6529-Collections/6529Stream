// Compiler-shaped provider observations only: no native role mutation or Safe signature execution.
import { AbiCoder, Interface, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import { governanceExecutorV2Interfaces as compiled } from './current-governance-executor-v2-source-fixture.mjs';
import * as pure from '../dist/current-role-registry-operational.js';
import * as workflow from '../dist/current-role-registry-operational-workflow.js';
export const A = n => getAddress('0x' + BigInt(n).toString(16).padStart(40, '0'));
export const H = text => id('operational-role-test:' + text);
export const copy = value => structuredClone(value);
export const registry = compiled.StreamRoleRegistry, executor = compiled.StreamGovernanceExecutor;
export const safe = new Interface([
  'function masterCopy() view returns(address)', 'function VERSION() view returns(string)',
  'function nonce() view returns(uint256)', 'function getOwners() view returns(address[])', 'function getThreshold() view returns(uint256)',
  'function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)',
  'function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool success)',
  'event ExecutionSuccess(bytes32 txHash,uint256 payment)', 'event ExecutionFailure(bytes32 txHash,uint256 payment)',
]);
const indexedSafe = new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)', 'event ExecutionFailure(bytes32 indexed txHash,uint256 payment)']);
const names = ['to','value','data','operation','safeTxGas','baseGas','gasPrice','gasToken','refundReceiver','nonce'];
const types = { SafeTx: names.map((name,i) => ({ name, type: ['address','uint256','bytes','uint8','uint256','uint256','uint256','address','address','uint256'][i] })) };
const coder = AbiCoder.defaultAbiCoder();
export function originalMutation(chainId, address, previous, request, global) {
  const revision = previous.revision + 1n;
  return { chainHash: keccak256(coder.encode(['bytes32','bytes32','uint256','address','bytes32','address','bool','uint64'],
    [id(global ? '6529STREAM_GLOBAL_ROLE_MUTATION_V1' : '6529STREAM_ROLE_MUTATION_V1'),previous.chainHash,chainId,address,request.role,request.holder,request.kind==='grantRole',revision])), revision };
}
export function originalAfter(chainId, address, before, request) {
  const result = copy(before), index = result.holders.indexOf(request.holder);
  if (request.kind === 'grantRole') result.holders.push(request.holder);
  else { result.holders[index] = result.holders.at(-1); result.holders.pop(); }
  result.roleState = originalMutation(chainId,address,before.roleState,request,false);
  result.globalState = originalMutation(chainId,address,before.globalState,request,true);
  return result;
}
export function setup({ kind = 'grantRole', transport = 'direct', role = pure.ROLE_REGISTRY_OPERATIONAL_ROLES.ROLE_FIXITY_OPERATOR, chainId = 1n, version = '1.4.1' } = {}) {
  const code = new Map();
  const pin = (n, runtime) => { code.set(A(n),runtime); return { address:A(n),codeHash:keccak256(runtime) }; };
  const d = { chainId,registry:pin(1,'0x60016000'),executor:pin(2,'0x60026000'),executorLinkedDependencies:[pin(3,'0x60036000')] };
  const caller = A(4), safeDeployment = { safe:pin(4,'0x60046000'),singleton:pin(5,'0x60056000'),version };
  if (transport === 'direct') code.delete(caller);
  const coordinates = { chainId,registry:d.registry.address,executor:d.executor.address };
  const request = { kind,role,holder:kind==='grantRole'?A(23):A(21) };
  const prepared = pure.prepareRoleRegistryOperationalCall(coordinates,caller,request);
  const initial = { holders:kind==='grantRole'?[A(20),A(21)]:[A(20),A(21),A(22)],
    roleState:{chainHash:H('role-before'),revision:4n}, globalState:{chainHash:H('global-before'),revision:9n},
    managerEnabled:true,managerState:{chainHash:H('manager-before'),revision:1n} };
  const state = { chainId, before:copy(initial), after:originalAfter(chainId,d.registry.address,initial,request),
    current:null,nonce:7n,endNonce:8n,owners:[A(30),A(31)],threshold:2n,version,sealed:true,bound:true,
    registryOwner:d.executor.address,executorRegistry:d.registry.address,registryHash:d.registry.codeHash,
    calls:[],transactions:new Map(),receipts:new Map(),callHook:null,blockHook:null,codeHook:null,receiptHook:null,transactionHook:null,
    originalError:null,originalRaw:'0x',safeHashOverride:null };
  const block = n => ({number:n,hash:H('block-'+n),timestamp:1000+n});
  const at = tag => tag >= 13 && state.current ? state.current : tag>=12 ? state.after : state.before;
  const provider = {
    async getNetwork(){return {chainId:state.chainId};},
    async getBlock(n){return state.blockHook?.(n)??block(n);},
    async getCode(a,n){return state.codeHook?.(a,n)??code.get(getAddress(a))??'0x';},
    async getTransactionReceipt(h){state.receiptHook?.(h);return state.receipts.get(h)??null;},
    async getTransaction(h){state.transactionHook?.(h);return state.transactions.get(h)??null;},
    async call(tx){
      if(!Number.isSafeInteger(tx.blockTag))throw Error('Mock requires concrete block');
      const target=getAddress(tx.to), iface=target===d.registry.address?registry:target===d.executor.address?executor:target===caller?safe:null;
      if(!iface)throw Error('Unknown mock target');
      const q=iface.parseTransaction({data:tx.data});if(!q)throw Error('Unknown mock selector');
      state.calls.push({...copy(tx),name:q.name});
      const hooked=await state.callHook?.({...tx,name:q.name,args:q.args});
      if(hooked?.raw!==undefined)return hooked.raw;
      if(hooked!==undefined)return iface.encodeFunctionResult(q.fragment,hooked);
      const row=at(tx.blockTag);let result;
      if(target===d.registry.address){
        switch(q.name){
          case 'owner':result=[state.registryOwner];break;
          case 'SCHEMA_VERSION':result=[1n];break;
          case 'roleGrantClass':if(q.args.role!==role)throw Error('Unexpected role');result=[2n];break;
          case 'roleHolderCount':if(q.args.role!==role)throw Error('Unexpected role');result=[BigInt(row.holders.length)];break;
          case 'roleHolderAt':if(q.args.role!==role)throw Error('Unexpected role');if(!row.holders[Number(q.args.index)])throw Error('Bad holder index');result=[row.holders[Number(q.args.index)]];break;
          case 'hasRole':if(q.args.role!==role)throw Error('Unexpected role');result=[row.holders.includes(getAddress(q.args.account))];break;
          case 'roleMutationState':if(q.args.role!==role)throw Error('Unexpected role');result=[row.roleState.chainHash,row.roleState.revision];break;
          case 'globalRoleMutationState':result=[row.globalState.chainHash,row.globalState.revision];break;
          case 'isRoleManager':if(getAddress(q.args.account)!==caller)throw Error('Unexpected manager');result=[row.managerEnabled];break;
          case 'roleManagerConfigMutationState':if(getAddress(q.args.account)!==caller)throw Error('Unexpected manager');result=[row.managerState.chainHash,row.managerState.revision];break;
          case 'grantRole':case 'revokeRole':
            if(q.name!==request.kind||q.args.role!==request.role||getAddress(q.args.holder)!==request.holder||getAddress(tx.from)!==caller||tx.value!==0n)throw Error('Original mock mutation differs');
            if(state.originalError)throw state.originalError;return state.originalRaw;
          default:throw Error('Unapproved registry method '+q.name);
        }
      }else if(target===d.executor.address){
        if(q.name==='roleRegistry')result=[state.executorRegistry];
        else if(q.name==='systemManifestBootstrapState'){
          result=q.fragment.outputs.map(x=>x.type==='bool'?false:x.type==='address'?ZeroAddress:x.type==='bytes32'?ZeroHash:0n);
          Object.assign(result,{0:state.bound,1:state.sealed,2:state.executorRegistry,3:state.registryHash});
        }else throw Error('Unapproved Executor method '+q.name);
      }else{
        switch(q.name){
          case 'masterCopy':result=[safeDeployment.singleton.address];break;
          case 'VERSION':result=[state.version];break;
          case 'nonce':result=[tx.blockTag>=12?state.endNonce:state.nonce];break;
          case 'getOwners':result=[state.owners];break;
          case 'getThreshold':result=[state.threshold];break;
          case 'getTransactionHash':result=[state.safeHashOverride??TypedDataEncoder.hash({chainId,verifyingContract:caller},types,Object.fromEntries(names.map((k,i)=>[k,q.args[i]])))];break;
          default:throw Error('Unapproved Safe method '+q.name);
        }
      }
      return iface.encodeFunctionResult(q.fragment,result);
    },
  };
  const capture=()=>workflow.captureRoleRegistryOperational(provider,d,prepared,{blockTag:10,gasLimit:1000000n,...(transport==='direct'?{}:{safe:safeDeployment})});
  function mine({layout=transport==='indexed'?'indexed':'legacy',outcome='success',guard=true,signatures='0x',fields={}}={}){
    const hash=H('transaction'),b=block(12), logs=[];
    logs.push({address:d.registry.address,...registry.encodeEventLog('RoleMutationCommitted',[1n,role,request.holder,kind==='grantRole',state.after.roleState.chainHash,state.after.roleState.revision,state.after.globalState.chainHash,state.after.globalState.revision,ZeroHash])});
    logs.push({address:d.registry.address,...registry.encodeEventLog(kind==='grantRole'?'StreamRoleGranted':'StreamRoleRevoked',[1n,role,request.holder,2n,caller,ZeroHash])});
    let data=prepared.call.data,to=d.registry.address,from=caller,expectedSafeTxHash=null;
    if(transport!=='direct'){
      const values={to,value:0n,data,operation:0n,safeTxGas:150000n,baseGas:30000n,gasPrice:1n,gasToken:ZeroAddress,refundReceiver:A(40),nonce:state.nonce,...fields};
      expectedSafeTxHash=TypedDataEncoder.hash({chainId,verifyingContract:caller},types,values);
      data=safe.encodeFunctionData('execTransaction',[...names.slice(0,9).map(k=>values[k]),signatures]);to=caller;from=A(41);
      logs.push({address:caller,...(layout==='indexed'?indexedSafe:safe).encodeEventLog(outcome==='failure'?'ExecutionFailure':'ExecutionSuccess',[expectedSafeTxHash,123n])});
      if(guard)logs.push({address:A(42),topics:[H('guard-after-safe')],data:'0x'});
    }
    const transaction={hash,from,to,data,value:0n,chainId,blockNumber:12,blockHash:b.hash};
    const receipt={hash,from,to,status:outcome==='revert'?0:1,blockNumber:12,blockHash:b.hash,
      logs:logs.map((l,index)=>({...l,index,transactionHash:hash,blockHash:b.hash,blockNumber:12,removed:false}))};
    state.transactions.set(hash,transaction);state.receipts.set(hash,receipt);
    const receiptOptions=transport==='direct'?{execution:'direct'}:{execution:'safe',safe:safeDeployment,expectedSafeTxHash};
    return {hash,transaction,receipt,receiptOptions,expectedSafeTxHash};
  }
  return {d,coordinates,caller,request,prepared,state,provider,code,block,safeDeployment,capture,mine};
}
