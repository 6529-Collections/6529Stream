import test from 'node:test';
import assert from 'node:assert/strict';
import { AbiCoder, FunctionFragment, Interface, ZeroHash, id, keccak256 } from 'ethers';
import * as p from '../dist/current-role-registry-operational.js';
import { toSafeCall } from '../dist/safe.js';
import { governanceExecutorV2Fixture as fixture, governanceExecutorV2Interfaces as compiled } from './current-governance-executor-v2-source-fixture.mjs';
import { A, H, copy, setup, originalAfter } from './current-role-registry-operational-workflow-fixture.mjs';
const role = p.ROLE_REGISTRY_OPERATIONAL_ROLES.ROLE_FIXITY_OPERATOR;
const coordinates = {chainId:1n,registry:A(1),executor:A(2)};
const call = (kind='grantRole',holder=A(23)) => p.prepareRoleRegistryOperationalCall(coordinates,A(4),{kind,role,holder});

test('operational source pin, seven original role names and complete public fragments match ABI164',()=>{
  assert.equal(p.ROLE_REGISTRY_OPERATIONAL_SOURCE_COMMIT,fixture.sourceCommit);
  assert.equal(Object.keys(p.ROLE_REGISTRY_OPERATIONAL_ROLES).length,7);
  for(const [name,hash] of Object.entries(p.ROLE_REGISTRY_OPERATIONAL_ROLES))assert.equal(hash,id(name));
  const iface=p.roleRegistryOperationalInterface();
  for(const fragment of iface.fragments){
    const other=fragment.type==='function'?compiled.StreamRoleRegistry.getFunction(fragment.format('sighash')):compiled.StreamRoleRegistry.getEvent(fragment.format('sighash'));
    assert.equal(fragment.format('full'),other.format('full'));
  }
  assert.deepEqual(iface.fragments.filter(f=>f.type==='function'&&f.stateMutability==='nonpayable').map(f=>f.name).sort(),['grantRole','revokeRole']);
});

test('all fourteen method/role plans independently encode original calls and generic Safe CALL',()=>{
  for(const role of Object.values(p.ROLE_REGISTRY_OPERATIONAL_ROLES))for(const kind of ['grantRole','revokeRole']){
    const prepared=p.prepareRoleRegistryOperationalCall(coordinates,A(4),{kind,role,holder:A(23)});
    assert.equal(prepared.call.data,compiled.StreamRoleRegistry.encodeFunctionData(kind,[role,A(23)]));
    assert.deepEqual(toSafeCall(prepared.call),{to:A(1),value:'0',data:prepared.call.data,operation:0});
    assert.equal(prepared.factsVerified,false);assert.deepEqual(p.normalizeRoleRegistryOperationalCall(prepared),prepared);
  }
});

test('exact original role and global domain hashes retain full-width chain and uint64 revision',()=>{
  const c={...coordinates,chainId:(1n<<240n)+17n}, request={kind:'grantRole',role,holder:A(23)};
  const before={chainHash:H('large'),revision:(1n<<63n)+9n}, coder=AbiCoder.defaultAbiCoder();
  for(const global of [false,true]){
    const result=p.roleRegistryOperationalMutationHash(c,before,request,global);
    const expected=keccak256(coder.encode(['bytes32','bytes32','uint256','address','bytes32','address','bool','uint64'],
      [id(global?'6529STREAM_GLOBAL_ROLE_MUTATION_V1':'6529STREAM_ROLE_MUTATION_V1'),before.chainHash,c.chainId,c.registry,role,request.holder,true,before.revision+1n]));
    assert.equal(result.chainHash,expected);assert.equal(result.revision,before.revision+1n);
  }
  assert.notEqual(p.roleRegistryOperationalMutationHash(c,before,request,false).chainHash,p.roleRegistryOperationalMutationHash(c,before,request,true).chainHash);
});

test('grant appends; middle revoke swaps last; final revoke does not invent a moved holder',()=>{
  for(const kind of ['grantRole','revokeRole']){
    const f=setup({kind}), out=p.roleRegistryOperationalTransition(f.prepared,f.state.before);
    assert.deepEqual(out.after,originalAfter(1n,A(1),f.state.before,f.request));
    assert.equal(out.factsVerified,false);
    if(kind==='revokeRole'){assert.deepEqual(out.after.holders,[A(20),A(22)]);assert.equal(out.removedIndex,1);assert.equal(out.movedHolder,A(22));}
  }
  const f=setup({kind:'revokeRole'}), last=call('revokeRole',A(22));
  const out=p.roleRegistryOperationalTransition(last,f.state.before);
  assert.deepEqual(out.after.holders,[A(20),A(21)]);assert.equal(out.movedHolder,null);
});

test('no-op, missing manager and both uint64 overflow branches refuse before a claimed transition',()=>{
  const f=setup();
  assert.throws(()=>p.roleRegistryOperationalTransition(call('grantRole',A(20)),f.state.before),/already granted/);
  assert.throws(()=>p.roleRegistryOperationalTransition(call('revokeRole'),f.state.before),/not granted/);
  assert.throws(()=>p.roleRegistryOperationalTransition(f.prepared,{...f.state.before,managerEnabled:false}),/RoleManager/);
  for(const field of ['roleState','globalState']){
    const before=copy(f.state.before);before[field].revision=(1n<<64n)-1n;
    if(field==='roleState')before.globalState.revision=before.roleState.revision;
    assert.throws(()=>p.roleRegistryOperationalTransition(f.prepared,before),/overflow/);
  }
});

test('root/scoped/arbitrary roles and owning Executor caller never become manager plans',()=>{
  for(const badRole of [id('ROLE_PAUSE_GUARDIAN'),id('ROLE_COLLECTION_FINALITY_ADMIN'),id('ROLE_TREASURY'),id('arbitrary'),ZeroHash]){
    assert.throws(()=>p.prepareRoleRegistryOperationalCall(coordinates,A(4),{kind:'grantRole',role:badRole,holder:A(23)}));
  }
  assert.throws(()=>p.prepareRoleRegistryOperationalCall(coordinates,A(2),{kind:'grantRole',role,holder:A(23)}),/Executor/);
  assert.throws(()=>p.prepareRoleRegistryOperationalCall(coordinates,A(4),{kind:'registerRoleManager',role,holder:A(23)}),/Unsupported/);
});

test('raw chain codec preserves empty facts while supplied source validation joins revisions and lists',()=>{
  assert.deepEqual(p.normalizeRoleRegistryOperationalChain({chainHash:ZeroHash,revision:0n}),{chainHash:ZeroHash,revision:0n});
  const empty={holders:[],roleState:{chainHash:ZeroHash,revision:0n},globalState:{chainHash:ZeroHash,revision:0n},managerEnabled:false,managerState:{chainHash:ZeroHash,revision:0n}};
  assert.deepEqual(p.validateRoleRegistryOperationalState(empty),empty);
  assert.throws(()=>p.validateRoleRegistryOperationalState({...empty,holders:[A(9)]}),/Impossible/);
  assert.throws(()=>p.validateRoleRegistryOperationalState({...empty,managerEnabled:true}),/Impossible/);
  assert.throws(()=>p.validateRoleRegistryOperationalState({...empty,managerState:{chainHash:H('manager'),revision:1n}}),/Impossible/);
  assert.throws(()=>p.validateRoleRegistryOperationalState({...empty,roleState:{chainHash:H('bad'),revision:0n}}),/chain\/revision/);
  assert.throws(()=>p.normalizeRoleRegistryOperationalChain({chainHash:ZeroHash,revision:1n<<64n}));
});

test('dense bounded unique holder rows reject holes, inherited indices and hidden/symbol properties',()=>{
  const f=setup();
  for(const malformed of [new Array(2),[A(20),A(20)],Array(p.ROLE_REGISTRY_OPERATIONAL_MAX_HOLDERS+1).fill(A(20))]){
    assert.throws(()=>p.normalizeRoleRegistryOperationalState({...f.state.before,holders:malformed}));
  }
  for(const key of ['hidden',Symbol('extra')]){
    const rows=[A(20)];Object.defineProperty(rows,key,{value:1,enumerable:false});
    assert.throws(()=>p.normalizeRoleRegistryOperationalState({...f.state.before,holders:rows}));
  }
  const inherited=new Array(1);Object.setPrototypeOf(inherited,{0:A(20)});
  assert.throws(()=>p.normalizeRoleRegistryOperationalState({...f.state.before,holders:inherited}));
});

test('plans and transitions are detached deeply readonly and reconstruct rather than trust supplied CALL',()=>{
  const c=copy(coordinates),r={kind:'grantRole',role,holder:A(23)},prepared=p.prepareRoleRegistryOperationalCall(c,A(4),r);
  c.registry=A(9);r.holder=A(9);assert.equal(prepared.call.to,A(1));assert.equal(prepared.request.holder,A(23));
  assert.ok(Object.isFrozen(prepared.request));assert.ok(Object.isFrozen(prepared.call));
  for(const replacement of [{value:1n},{to:A(9)},{data:prepared.call.data+'00'},{data:'0x'}]){
    assert.throws(()=>p.normalizeRoleRegistryOperationalCall({...prepared,call:{...prepared.call,...replacement}}));
  }
  assert.throws(()=>p.normalizeRoleRegistryOperationalCall({...prepared,factsVerified:true}));
  const f=setup(),before=copy(f.state.before),transition=p.roleRegistryOperationalTransition(f.prepared,before);
  before.holders[0]=A(99);assert.equal(transition.before.holders[0],A(20));assert.ok(Object.isFrozen(transition.after.holders));
});

test('closed read planner agrees with actual methods and rejects unrelated governance routes',()=>{
  const requests=[{kind:'owner'},{kind:'SCHEMA_VERSION'},{kind:'globalRoleMutationState'},
    {kind:'isRoleManager',account:A(4)},{kind:'roleManagerConfigMutationState',account:A(4)},
    {kind:'roleGrantClass',role},{kind:'roleHolderCount',role},{kind:'roleMutationState',role},
    {kind:'hasRole',role,account:A(23)},{kind:'roleHolderAt',role,index:0n}];
  for(const request of requests){const out=p.prepareRoleRegistryOperationalRead(A(1),request);assert.equal(compiled.StreamRoleRegistry.parseTransaction(out).name,request.kind);assert.equal(out.value,0n);}
  assert.throws(()=>p.prepareRoleRegistryOperationalRead(A(1),{kind:'registerRoleManager',account:A(4)}),/Unsupported/);
  assert.throws(()=>p.prepareRoleRegistryOperationalRead(A(1),{kind:'owner',extra:1}));
});

test('operational holder admission does not invent root guardian code or redundancy restrictions',()=>{
  const f=setup();
  for(const holder of [A(300),A(301),f.caller,coordinates.executor]){
    const out=p.roleRegistryOperationalTransition(call('grantRole',holder),f.state.before);
    assert.equal(out.after.holders.at(-1),holder);assert.equal(out.factsVerified,false);
  }
  const max=p.ROLE_REGISTRY_OPERATIONAL_MAX_HOLDERS;
  const full={...f.state.before,holders:Array.from({length:max},(_,i)=>A(i+10000)),roleState:{chainHash:H('full-role'),revision:BigInt(max)},globalState:{chainHash:H('full-global'),revision:BigInt(max+1)}};
  assert.throws(()=>p.roleRegistryOperationalTransition(f.prepared,full),/Client holder/);
});
