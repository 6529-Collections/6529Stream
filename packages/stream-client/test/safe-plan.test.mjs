import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { AbiCoder, Interface, getAddress, id, keccak256, toUtf8Bytes } from 'ethers';
import { abis, createSafeCallPlan, verifySafeCallPlan, simulateSafePlanStep, safeCallInventory } from '../dist/index.js';

const revenue = JSON.parse(await readFile(new URL('./fixtures/current-revenue-abi.json', import.meta.url), 'utf8'));
const custody = JSON.parse(await readFile(new URL('./fixtures/current-custody-operation-abi.json', import.meta.url), 'utf8'));
const catalog = [abis.core, revenue.abis.primary, custody.families.custodyRightsActivation.abi];
const ifaces = catalog.map(a => new Interface(a));
const A = n => '0x' + BigInt(n).toString(16).padStart(40,'0');
const chainId = 31337n, token = 9007199254740993n, nativeValue = 9007199254740995n;
const input = () => [
  { safe:A(1),intent:'Approve the custody contract for this exact NFT',abi:catalog[0],call:{to:A(10),value:0n,data:ifaces[0].encodeFunctionData('approve',[A(11),token])} },
  { safe:A(2),intent:'Transfer Resolver ownership to the governed executor',abi:catalog[1],call:{to:A(12),value:0n,data:ifaces[1].encodeFunctionData('transferOwnership',[A(13)])} },
  { safe:A(1),intent:'Bid with the reviewed native amount and deliver to the collector Safe',abi:catalog[2],call:{to:A(11),value:nativeValue,data:ifaces[2].encodeFunctionData('bidCustodyRights',[id('auction'),A(1)])} },
];

test('Safe plans preserve approval, owner action, bidder identity and exact native value across callers',()=>{
  const inputs=input(),plan=createSafeCallPlan(chainId,'Reviewed caller sequence',inputs);
  assert.equal(plan.hash,'0xc1b5f390e674c20b4c1ca7a87c97c19ab24b1804114d3c871b7cbefee874e7aa');
  assert.equal(plan.steps.length,3);assert.equal(plan.steps[0].arguments[1],token.toString());
  assert.equal(plan.steps[1].safe,A(2));assert.equal(plan.steps[2].transaction.value,nativeValue.toString());
  for(let i=0;i<3;i++){
    assert.equal(plan.steps[i].transaction.data,inputs[i].call.data);assert.equal(plan.steps[i].transaction.to.toLowerCase(),inputs[i].call.to.toLowerCase());
    assert.equal(plan.steps[i].transaction.operation,0);assert(Object.isFrozen(plan.steps[i].transaction));
  }
  assert(Object.isFrozen(plan.steps));assert(Object.isFrozen(plan.steps[0].arguments));
  inputs[0].call.value=99n;inputs[0].intent='mutated';assert.equal(plan.steps[0].transaction.value,'0');
  assert.deepEqual(verifySafeCallPlan(plan,catalog),plan);
});

const receiveAbi=[{type:'receive',stateMutability:'payable'}];
const fallbackAbi=[{type:'fallback',stateMutability:'payable'}];
const dispatchAbi=[
  {type:'function',name:'known',stateMutability:'nonpayable',inputs:[{name:'value',type:'uint256'}],outputs:[]},
  {type:'receive',stateMutability:'payable'},
  {type:'fallback',stateMutability:'payable'},
];

test('explicit receive route preserves positive ETH, empty calldata and Safe caller through verification and simulation',async()=>{
  const call={to:A(30),value:17n,data:'0x'};
  const plan=createSafeCallPlan(chainId,'Receive contribution',[{safe:A(31),intent:'Send the reviewed native contribution',call,abi:receiveAbi,route:'receive'}]);
  const step=plan.steps[0];
  assert.equal(step.route,'receive');assert.equal(step.method,'receive()');assert.deepEqual(step.arguments,[]);
  assert.deepEqual(step.transaction,{to:A(30),value:'17',data:'0x',operation:0});
  assert.deepEqual(verifySafeCallPlan(plan,[receiveAbi]),plan);
  const calls=[],provider={getNetwork:async()=>({chainId}),call:async tx=>(calls.push(tx),'0x')};
  await simulateSafePlanStep(provider,plan,[receiveAbi],0);
  assert.deepEqual(calls,[{from:getAddress(A(31)),to:getAddress(A(30)),data:'0x',value:17n}]);
  const zero=createSafeCallPlan(chainId,'Zero-value receive',[{safe:A(31),intent:'Exercise payable receive with zero value',call:{...call,value:0n},abi:receiveAbi,route:'receive'}]);
  assert.equal(zero.steps[0].transaction.value,'0');
});

test('explicit fallback route accepts unknown and short calldata and preserves payable value',()=>{
  for(const data of ['0x12','0x12345678']){
    const call={to:A(32),value:9n,data};
    const plan=createSafeCallPlan(chainId,'Dispatch unknown calldata',[{safe:A(33),intent:'Use the reviewed payable fallback',call,abi:fallbackAbi,route:'fallback'}]);
    const step=plan.steps[0];
    assert.equal(step.route,'fallback');assert.equal(step.method,'fallback(bytes)');assert.deepEqual(step.arguments,[data]);
    assert.deepEqual(step.transaction,{to:A(32),value:'9',data,operation:0});
    assert.deepEqual(verifySafeCallPlan(plan,[fallbackAbi]),plan);
  }
  const zero=createSafeCallPlan(chainId,'Zero-value fallback',[{safe:A(33),intent:'Use payable fallback with zero value',call:{to:A(32),value:0n,data:'0x'},abi:fallbackAbi,route:'fallback'}]);
  assert.equal(zero.steps[0].transaction.value,'0');
});

test('fallback route follows Solidity dispatch precedence and enforces the compiled handler and payable rule',()=>{
  const iface=new Interface(dispatchAbi),known=iface.encodeFunctionData('known',[1n]);
  const make=(route,abi,data,value=0n)=>createSafeCallPlan(chainId,'Dispatch route',[{safe:A(34),intent:'Reviewed dispatch',call:{to:A(35),data,value},abi,route}]);
  assert.throws(()=>make('fallback',dispatchAbi,'0x'),/dispatches to receive/);
  assert.throws(()=>make('fallback',dispatchAbi,known),/known function selector/);
  assert.throws(()=>make('receive',dispatchAbi,'0x12'),/empty calldata/);
  assert.throws(()=>make('receive',fallbackAbi,'0x'),/requires a compiled ABI receive/);
  assert.throws(()=>make('fallback',receiveAbi,'0x12'),/requires a compiled ABI fallback/);
  const nonpayable=[{type:'fallback',stateMutability:'nonpayable'}];
  assert.equal(make('fallback',nonpayable,'0x12').steps[0].transaction.value,'0');
  assert.throws(()=>make('fallback',nonpayable,'0x12',1n),/Nonpayable fallback/);
  // Without receive(), empty calldata dispatches to fallback.
  assert.equal(make('fallback',fallbackAbi,'0x').steps[0].route,'fallback');
  // No explicit route means ordinary function parsing; undecodable data is never inferred as fallback.
  assert.throws(()=>createSafeCallPlan(chainId,'Implicit raw data',[{safe:A(34),intent:'No implicit fallback',call:{to:A(35),data:'0x1234',value:0n},abi:fallbackAbi}]),/explicit receive\/fallback route/);
});

test('ordered mixed function, receive and fallback plans verify, simulate, bind route hashes and reject route tampering',async()=>{
  const functionInput=input()[0];
  const rows=[
    {...functionInput,intent:'Keep the existing function transaction first'},
    {safe:A(41),intent:'Receive the exact native amount',abi:dispatchAbi,route:'receive',call:{to:A(42),data:'0x',value:3n}},
    {safe:A(43),intent:'Send unknown bytes to fallback',abi:dispatchAbi,route:'fallback',call:{to:A(44),data:'0x1234',value:0n}},
  ];
  const catalog=[functionInput.abi,dispatchAbi,dispatchAbi],plan=createSafeCallPlan(chainId,'Ordered mixed dispatch',rows);
  assert.deepEqual(plan.steps.map(s=>s.route??'function'),['function','receive','fallback']);
  assert.deepEqual(verifySafeCallPlan(plan,catalog),plan);
  const calls=[],provider={getNetwork:async()=>({chainId}),call:async tx=>(calls.push(tx),'0x')};
  await simulateSafePlanStep(provider,plan,catalog,1);await simulateSafePlanStep(provider,plan,catalog,2);
  assert.deepEqual(calls,[{from:getAddress(A(41)),to:getAddress(A(42)),data:'0x',value:3n},{from:getAddress(A(43)),to:getAddress(A(44)),data:'0x1234',value:0n}]);
  assert.throws(()=>verifySafeCallPlan({...plan,steps:[plan.steps[0],{...plan.steps[1],route:'fallback'},plan.steps[2]]},catalog));
  assert.throws(()=>verifySafeCallPlan({...plan,steps:[plan.steps[0],plan.steps[1],{...plan.steps[2],arguments:['0xabcd']}]},catalog));
  const receive=createSafeCallPlan(chainId,'Same raw bytes',[{safe:A(50),intent:'Same raw bytes',abi:receiveAbi,route:'receive',call:{to:A(51),data:'0x',value:1n}}]);
  const fallback=createSafeCallPlan(chainId,'Same raw bytes',[{safe:A(50),intent:'Same raw bytes',abi:fallbackAbi,route:'fallback',call:{to:A(51),data:'0x',value:1n}}]);
  assert.notEqual(receive.steps[0].hash,fallback.steps[0].hash);
  assert.notEqual(receive.hash,fallback.hash);
});

test('independent literal review hash binds chain, order, caller, target, bytes, value and readable intent',()=>{
  const p=createSafeCallPlan(chainId,'Reviewed caller sequence',input()),coder=AbiCoder.defaultAbiCoder();
  const hashes=p.steps.map((s,i)=>keccak256(coder.encode(['bytes32','uint256','uint256','address','address','uint256','bytes32','bytes32','bytes32'],
    [id('6529STREAM_SAFE_CALL_PLAN_STEP_V1'),chainId,i,s.safe,s.transaction.to,BigInt(s.transaction.value),keccak256(s.transaction.data),id(s.method),keccak256(toUtf8Bytes(s.intent))])));
  assert.deepEqual(hashes,p.steps.map(s=>s.hash));
  const literal=keccak256(coder.encode(['bytes32','uint256','bytes32','bytes32[]'],[id('6529STREAM_SAFE_CALL_PLAN_V1'),chainId,id(p.title),hashes]));
  assert.equal(literal,p.hash);
  assert.notEqual(createSafeCallPlan(chainId+1n,p.title,input()).hash,p.hash);
  assert.notEqual(createSafeCallPlan(chainId,p.title,input().reverse()).hash,p.hash);
});

test('verification rejects altered readable arguments, target/value/method, order and DELEGATECALL',()=>{
  const p=createSafeCallPlan(chainId,'Reviewed caller sequence',input());
  for(const altered of [
    {...p.steps[0],arguments:[A(99),token.toString()]},
    {...p.steps[0],safe:A(99)},
    {...p.steps[0],method:'other(uint256)'},
    {...p.steps[0],index:1},
    {...p.steps[0],transaction:{...p.steps[0].transaction,to:A(99)}},
    {...p.steps[0],transaction:{...p.steps[0].transaction,value:'01'}},
    {...p.steps[0],transaction:{...p.steps[0].transaction,operation:1}},
  ]) assert.throws(()=>verifySafeCallPlan({...p,steps:[altered,...p.steps.slice(1)]},catalog));
  assert.throws(()=>verifySafeCallPlan(p,catalog.slice(1)),/shape differs/);
});

test('malformed bytes, unsupported selector, view function, unsafe values and nonpayable ETH fail before planning',()=>{
  const s=input()[0],make=x=>createSafeCallPlan(chainId,'Reviewed call',[{...s,...x}]);
  assert.throws(()=>make({call:{...s.call,data:s.call.data+'00'.repeat(32)}}),/Noncanonical/);
  assert.throws(()=>make({call:{...s.call,data:'0x12345678'}}),/known/);
  assert.throws(()=>make({call:{...s.call,data:ifaces[0].encodeFunctionData('ownerOf',[token])}}),/state-changing/);
  assert.throws(()=>make({call:{...s.call,value:1n}}),/Nonpayable/);
  assert.throws(()=>make({call:{...s.call,value:1}}),/bigint/);
  assert.throws(()=>make({safe:A(0)}),/nonzero/);
  assert.throws(()=>make({intent:''}),/intent/);
  assert.throws(()=>createSafeCallPlan(0n,'x',input()),/positive/);
});

test('simulation keeps failed CALL bytes, sender and value identical and enforces the chain',async()=>{
  const p=createSafeCallPlan(chainId,'Reviewed caller sequence',input()),calls=[];
  let wrong=false,failed=true;
  const provider={getNetwork:async()=>({chainId:wrong?1n:chainId}),call:async tx=>{calls.push(tx);if(failed)throw Error('Target reverted');return '0x';}};
  await assert.rejects(simulateSafePlanStep(provider,p,catalog,2),/Target reverted/);
  failed=false;await simulateSafePlanStep(provider,p,catalog,2);
  assert.deepEqual(calls[0],calls[1]);assert.equal(calls[1].value,nativeValue);assert.equal(calls[1].from,A(1));
  wrong=true;await assert.rejects(simulateSafePlanStep(provider,p,catalog,2),/chain differs/);assert.equal(calls.length,2);
  await assert.rejects(simulateSafePlanStep(provider,p,catalog,3),/Invalid plan step/);
});

test('inventory includes every supplied write selector, owner/admin calls and payable actions, excluding reads',()=>{
  for(const [i,abi] of catalog.entries()){
    const inventory=safeCallInventory(abi),functions=ifaces[i].fragments.filter(f=>f.type==='function'&&!f.constant);
    assert.equal(inventory.length,functions.length);
    for(const f of functions) assert(inventory.some(x=>x.selector===f.selector&&x.method===f.format('sighash')&&x.payable===f.payable));
  }
  assert(safeCallInventory(catalog[1]).some(x=>x.method==='transferOwnership(address)'));
  assert(safeCallInventory(catalog[2]).some(x=>x.method==='bidCustodyRights(bytes32,address)'&&x.payable));
});

test('nested template rows remain readable canonical arrays with full-width integers',()=>{
  const rows=[[A(7),'0x'+'00'.repeat(32),1000000n,id('artist share')]];
  const call={to:A(12),value:0n,data:ifaces[1].encodeFunctionData('createPrimaryTemplate',[rows,id('metadata')])};
  const plan=createSafeCallPlan(chainId,'Register template',[{safe:A(2),intent:'Register the reviewed payout rows',abi:catalog[1],call}]);
  assert.deepEqual(plan.steps[0].arguments[0],[[A(7),'0x'+'00'.repeat(32),'1000000',id('artist share')]]);
  assert.deepEqual(verifySafeCallPlan(plan,[catalog[1]]),plan);
});
