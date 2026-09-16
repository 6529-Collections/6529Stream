import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { AbiCoder, Interface, id, keccak256, toUtf8Bytes } from 'ethers';
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
