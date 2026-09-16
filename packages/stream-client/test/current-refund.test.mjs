import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, id, keccak256, concat, ZeroAddress, getAddress } from "ethers";
import { CurrentNativeRefundClaimsClient, toSafeCall } from "../dist/index.js";
import { refundFixture } from "../scripts/generate-current-refund-fixture.mjs";
const fixture=JSON.parse(await readFile(new URL("./fixtures/current-refund-abi.json",import.meta.url),"utf8"));
const coder=AbiCoder.defaultAbiCoder(),addr=n=>getAddress(`0x${n.toString(16).padStart(40,"0")}`);
const host=addr(101),core=addr(102),modules=addr(103),registry=addr(104),account=addr(105),delegate=addr(106),receiver=addr(107);
const chain=31337n,saleId=id("native sale"),index=(1n<<200n)+3n,credit=(1n<<220n)+17n;
const witness=(walletWide=false)=>({walletWide,index});
function rpc(kind="fixed") {
 const abi=new Interface(fixture.abis[kind]),client=new CurrentNativeRefundClaimsClient(chain,host,fixture.abis[kind]);
 const code="0x60016000",codeHash=keccak256(code);
 const pins={core,adapterCodeHash:codeHash,moduleRegistry:modules,moduleRegistryCodeHash:codeHash,delegateRegistry:registry,
  delegateRegistryCodeHash:codeHash,usecase:2n,baseManifestHash:id("original base")};
 const manifest=coder.encode(["bytes32","uint256","address","bytes32","address","address","bytes32","uint256"],
  [id("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"),chain,host,pins.baseManifestHash,core,registry,codeHash,2n]);
 const state={row:[BigInt(account),BigInt(delegate),900n,1100n,1n,0n],raw:undefined,manifest,code,credit,
  configuration:[chain,core,registry,codeHash,2n,pins.baseManifestHash,modules,codeHash],blockHash:id("block7"),calls:[],keys:[]};
 const provider={getNetwork:async()=>({chainId:chain}),getBlock:async()=>({number:7,timestamp:1000,hash:state.blockHash}),
  getCode:async(target,at)=>{assert.equal(at,7);assert([host,registry].includes(target),"no module code gate on claims");return state.code;},
  call:async tx=>{state.calls.push(tx);assert.equal(tx.blockTag,7);assert.notEqual(tx.to,modules,"no module admission on earned credit");
   if(tx.to===registry){assert.equal(tx.data.slice(0,10),id("globalDelegationHashes(bytes32,uint256)").slice(0,10));
    const [key,rowIndex]=coder.decode(["bytes32","uint256"],"0x"+tx.data.slice(10));assert.equal(rowIndex,index);state.keys.push(key);
    return state.raw??coder.encode(Array(6).fill("uint256"),state.row);}
   assert.equal(tx.to,host);const parsed=abi.parseTransaction(tx);
   const values={refundDelegationConfiguration:state.configuration,refundDelegationManifest:state.manifest,
    refundDelegationManifestHash:keccak256(state.manifest),refundableBalance:state.credit};
   if(parsed.name in values)return abi.encodeFunctionResult(parsed.name,[values[parsed.name]]);
   assert.equal(tx.value,0n);assert.equal(tx.from,parsed.name==="claimRefundFor"?delegate:account);return abi.encodeFunctionResult(parsed.name,parsed.name==="claimRefundFor"?[state.credit]:[]);}};
 return {client,abi,pins,state,provider};
}
test("four compiled refund hosts preserve full-width principal-only and own Safe CALLs",()=>{
 for(const kind of Object.keys(fixture.abis)){
  const {client,abi}=rpc(kind),p=client.claimFor(delegate,saleId,account,witness());
  assert.equal(p.caller,delegate);assert.equal(p.call.value,0n);
  assert.equal(p.call.data,abi.encodeFunctionData("claimRefundFor",[saleId,account,[false,index]]));
  assert.deepEqual(toSafeCall(p.call),{to:host,value:"0",data:p.call.data,operation:0});
  const own=client.claim(account,saleId,receiver);assert.equal(own.caller,account);
  assert.equal(own.call.data,abi.encodeFunctionData("claimRefund",[saleId,receiver]));assert(Object.isFrozen(p.call));
 }
});
test("refund preparation refuses delegate redirection, lossy indices and invalid callers",()=>{
 const {client}=rpc();for(const bad of [0,1,"1",-1n,1n<<256n])assert.throws(()=>client.claimFor(delegate,saleId,account,{walletWide:false,index:bad}));
 for(const bad of [{...witness(),receiver},{index},{walletWide:1,index}])assert.throws(()=>client.claimFor(delegate,saleId,account,bad));
 for(const bad of [ZeroAddress,host]){assert.throws(()=>client.claimFor(delegate,saleId,bad,witness()));assert.throws(()=>client.claim(account,saleId,bad));}
 assert.throws(()=>client.claimFor(account,saleId,account,witness()));assert.throws(()=>new CurrentNativeRefundClaimsClient(31337,host,fixture.abis.fixed));
});
test("selected refund ABI must retain exact nonpayable and complete configuration tuples",()=>{
 for(const mutate of [a=>a.find(x=>x.name==="claimRefundFor").stateMutability="payable",
  a=>a.find(x=>x.name==="claimRefundFor").inputs[2].components[1].type="uint64",
  a=>a.find(x=>x.name==="refundDelegationConfiguration").outputs[0].components[0].name="otherChain"]){
  const abi=structuredClone(fixture.abis.fixed);mutate(abi);assert.throws(()=>new CurrentNativeRefundClaimsClient(chain,host,abi));}
 assert.throws(()=>new CurrentNativeRefundClaimsClient(chain,host,[]));
});
test("both full-row scopes join original immutable manifest, code and one observed block",async()=>{
 for(const kind of Object.keys(fixture.abis))for(const walletWide of [false,true]){
  const {client,pins,state,provider}=rpc(kind);const result=await client.observeDelegation(provider,pins,account,delegate,witness(walletWide),7);
  const scope=walletWide?"0x8888888888888888888888888888888888888888":core;
  assert.equal(state.keys[0],keccak256(concat([account,scope,delegate,coder.encode(["uint256"],[2n])])));
  assert.equal(result.blockNumber,7);assert.equal(result.manifestHash,keccak256(state.manifest));assert.equal(result.startDate,900n);
  assert.equal(result.expiryDate,1100n);assert(Object.isFrozen(result.witness));
 }
});
test("revoked, expired, partial, malformed rows and deployment drift fail terminally",async()=>{
 const mutations=[s=>s.row[0]=BigInt(receiver),s=>s.row[1]=BigInt(receiver),s=>s.row[2]=1001n,s=>s.row[3]=1000n,
  s=>s.row[4]=0n,s=>s.row[5]=1n,s=>s.raw="0x",s=>s.raw="0x"+"00".repeat(160),s=>s.raw="0x"+"00".repeat(224),
  s=>s.code="0x",s=>s.code="0x60026000",s=>s.manifest="0x",s=>s.configuration[0]=1n,s=>s.configuration[6]=receiver];
 for(const mutate of mutations){const {client,pins,state,provider}=rpc();mutate(state);await assert.rejects(client.observeDelegation(provider,pins,account,delegate,witness(),7));}
 const {client,pins,provider}=rpc();for(const usecase of [0n,998n,999n,2])await assert.rejects(client.observeDelegation(provider,{...pins,usecase},account,delegate,witness(),7));
 await assert.rejects(client.observeDelegation({...provider,call:async()=>{throw Error("unavailable");}},pins,account,delegate,witness(),7),/unavailable/);
 await assert.rejects(client.observeDelegation({...provider,getNetwork:async()=>({chainId:1n})},pins,account,delegate,witness(),7),/chain differs/);
 let blocks=0;await assert.rejects(client.observeDelegation({...provider,getBlock:async()=>({number:7,timestamp:1000,hash:id(String(++blocks))})},pins,account,delegate,witness(),7),/block changed/);
});
test("refund observation copies mutable pins and witness before the first await",async()=>{
 const {client,pins,provider}=rpc(),w=witness(),original=provider.getNetwork;
 provider.getNetwork=async()=>{pins.usecase=999n;pins.core=receiver;w.walletWide=true;w.index=0n;return original();};
 const result=await client.observeDelegation(provider,pins,account,delegate,w,7);assert.equal(result.witness.index,index);assert.equal(result.witness.walletWide,false);
});
test("credit read is canonical/full-width and simulation requires exact zero-value CALL",async()=>{
 const {client,provider,abi}=rpc();assert.equal(await client.readCredit(provider,saleId,account,7),credit);
 const p=client.claimFor(delegate,saleId,account,witness());assert.equal(await client.simulate(provider,p,7),abi.encodeFunctionResult("claimRefundFor",[credit]));
 for(const call of [{...p.call,value:1n},{...p.call,to:receiver}])await assert.rejects(client.simulate(provider,{...p,call},7));
 await assert.rejects(client.readCredit({...provider,call:async()=>coder.encode(["uint256","uint256"],[credit,0n])},saleId,account,7),/Noncanonical/);
 await assert.rejects(client.simulate({...provider,getNetwork:async()=>({chainId:1n})},p,7));
});
test("explicit refund fixture extraction rejects failed and incomplete compiler output",()=>{
 const targets={fixed:"StreamNativeFixedPriceSaleAdapter",dutch:"StreamNativeDutchSale",clearing:"StreamNativeClearingSale",window:"StreamNativeRefundWindowSale"};
 const input={language:"Solidity",sources:{}},output={contracts:{}};
 for(const [kind,name]of Object.entries(targets)){const source=`smart-contracts/domains/mint/${name}.sol`;input.sources[source]={content:"pragma solidity ^0.8.19;"};output.contracts[source]={[name]:{abi:fixture.abis[kind]}};}
 const generated=refundFixture(Buffer.from(JSON.stringify(input)),Buffer.from(JSON.stringify(output)));assert.deepEqual(generated.abis,fixture.abis);assert.match(generated.qualification,/no deployment/);
 assert.throws(()=>refundFixture(JSON.stringify(input),JSON.stringify({...output,errors:[{severity:"error"}]})));
 const bad=structuredClone(output);delete bad.contracts[Object.keys(bad.contracts)[0]];assert.throws(()=>refundFixture(JSON.stringify(input),JSON.stringify(bad)));
});
test("read-only refund example returns simulated Safe coordinates with no signer or sender",async()=>{
 const {reviewNativeRefundClaim}=await import("../examples/current-secondary.mjs"),{client,pins,provider}=rpc();
 const delegated=await reviewNativeRefundClaim(client,provider,delegate,account,saleId,{witness:witness(),pins},7);
 assert.equal(delegated.credit,credit);assert.equal(delegated.caller,delegate);assert.equal(delegated.safeCall.value,"0");
 const own=await reviewNativeRefundClaim(client,provider,account,account,saleId,undefined,7);assert.equal(own.caller,account);assert.equal(own.observation,undefined);
 await assert.rejects(reviewNativeRefundClaim(client,provider,delegate,account,saleId,undefined,7),/requires/);
});

test("refund example keeps observed and prepared witness equal when caller input mutates during reads",async()=>{
 const {reviewNativeRefundClaim}=await import("../examples/current-secondary.mjs"),{client,pins,provider,abi}=rpc();
 const w=witness(), original=provider.getNetwork;
 provider.getNetwork=async()=>{w.index=0n;w.walletWide=true;pins.usecase=999n;return original();};
 const result=await reviewNativeRefundClaim(client,provider,delegate,account,saleId,{witness:w,pins},7);
 assert.equal(result.observation.witness.index,index);
 assert.equal(result.safeCall.data,abi.encodeFunctionData("claimRefundFor",[saleId,account,[false,index]]));
});
