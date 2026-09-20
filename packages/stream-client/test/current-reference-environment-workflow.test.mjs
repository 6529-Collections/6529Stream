import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as pure from "../dist/current-reference-environment.js";
import * as flow from "../dist/current-reference-environment-workflow.js";
import { prepareReferenceInventoryPlan } from "../dist/current-reference-inventory-workflow.js";

const fixture=JSON.parse(readFileSync(new URL("./fixtures/current-reference-environment-abi.json",import.meta.url),"utf8"));
const abi=Object.fromEntries(Object.entries(fixture.abis).map(([k,v])=>[k,new Interface(v)])),A=n=>getAddress(`0x${BigInt(n).toString(16).padStart(40,"0")}`),host=A(1),store=A(2),preparer=A(3),uploader=A(4),hostCode="0x6001",storeCode="0x6002",chainId=31337n;
const deployment={chainId,publicationHost:{address:host,codeHash:keccak256(hostCode)},store:{address:store,codeHash:keccak256(storeCode)}},blockHash=n=>id(`block:${n}`);
function snapshot(note="undetermined") { const e={objectHash:id("object"),coverageHash:id("coverage"),manifestHash:ZeroHash,manifestBytes:0n,engineName:"Chromium",engineVersion:"1",engineExecutableSha256:id("engine"),toolchainName:"tool",toolchainVersion:"2",toolchainSha256:id("tool"),engineExecutablePath:"bin/engine.exe",toolchainPath:"bin/tool.exe",packageFiles:[{path:"bin/engine.exe",byteSize:100n,sha256Digest:id("engine")},{path:"bin/tool.exe",byteSize:200n,sha256Digest:id("tool")}],platformPrerequisites:[{path:"C:\\Windows\\system.dll",byteSize:300n,sha256Digest:id("platform")}],operatingSystem:"Windows",operatingSystemVersion:"server",architecture:"AMD64",viewportWidth:1024n,viewportHeight:768n,devicePixelRatio:1n,colorSpace:"srgb",softwareRasterization:true,captureProfile:pure.REFERENCE_ENVIRONMENT_CAPTURE_PROFILE,licenseNote:note};const canonical=pure.referenceEnvironmentCanonicalBytes(e);return pure.prepareReferenceEnvironment(chainId,host,{...e,manifestHash:keccak256(canonical),manifestBytes:BigInt((canonical.length-2)/2)}); }
function plan(note){return flow.prepareReferenceEnvironmentPlan(deployment,preparer,snapshot(note),{uploader});}
function provider(plan,options={}) { const calls=[],estimates=[],headers=new Map(),state=(name,tag)=>typeof options[name]==="function"?options[name](tag):!!options[name],snap=plan.snapshot;
  return {calls,estimates,async getNetwork(){options.mutate?.();return {chainId:options.chainId??chainId};},async getBlock(n){headers.set(n,(headers.get(n)??0)+1);return {number:n,hash:options.reorg&&headers.get(n)>1?id("reorg"):blockHash(n)};},async getCode(target,tag){if(options.code){const x=options.code(target,tag);if(x!==undefined)return x;}if(target===host)return hostCode;if(target===store)return storeCode;const index=plan.chunks.findIndex((_,n)=>target===A(100+n));return index>=0?"0x00"+plan.chunks[index].bytes.slice(2):"0x";},
    async call(tx){calls.push(tx);const iface=tx.to===store?abi.store:abi.host,desc=iface.parseTransaction({data:tx.data}),name=desc.name,args=desc.args,tag=tx.blockTag,override=options.read?.(name,args,tx.to,tag,tx);if(override?.raw!==undefined)return override.raw;if(override!==undefined)return iface.encodeFunctionResult(name,override);let out;
      if(name==="deploymentChainId")out=[chainId];else if(name==="dependencies"){const targets=Array(7).fill(ZeroAddress),hashes=Array(7).fill(ZeroHash);targets[3]=store;hashes[3]=deployment.store.codeHash;out=[[targets,hashes,chainId,ZeroHash,ZeroHash,0,100000,100000,100000,100000]];}
      else if(name==="MAX_CHUNK_BYTES")out=[8192n];else if(name==="supportsInterface")out=[true];
      else if(name==="preparedFileInventory"){const identity=args[0],kind=identity===snap.environmentId?"retained":identity===snap.packageInventory.inventoryId?"package":identity===snap.platformInventory.inventoryId?"platform":null;if(!kind||!state(kind,tag)){const e=new Error("InvalidSnapshotManifest");e.code="CALL_EXCEPTION";e.data=id("InvalidSnapshotManifest()").slice(0,10);throw e;}out=[kind==="retained"?snap.canonical:kind==="package"?snap.packageInventory.canonical:snap.platformInventory.canonical];}
      else if(name==="chunk"){const n=plan.chunks.findIndex(c=>c.hash===args[0]);out=state("chunks",tag)&&n>=0?[A(100+n),BigInt((plan.chunks[n].bytes.length-2)/2)]:[ZeroAddress,0n];}
      else if(name==="publishChunk"){const n=plan.chunks.findIndex(c=>c.bytes===args[0]);out=[keccak256(args[0]),A(100+n)];}
      else if(name==="prepareEnvironment")out=[snap.environmentId];else throw Error(`Unexpected ${name}`);return iface.encodeFunctionResult(name,out);
    },async send(method,params){estimates.push({method,params});return options.gas??"0x10000";}};
}
const safeAbi=new Interface(["function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)"]);
function receipt(p,plan,index,eventSpecs,{safe=false,indexed=false,success=true,blockNumber=11}={}) {const s=plan.steps[index],hash=id("tx"),bh=blockHash(blockNumber),specs=[...eventSpecs],safeEvents=new Interface([`event ExecutionSuccess(bytes32 ${indexed?"indexed ":""}txHash,uint256 payment)`]);if(safe&&success)specs.push([s.caller,safeEvents,"ExecutionSuccess",[id("safeTx"),0n]]);const logs=specs.map(([address,iface,name,args],n)=>({...iface.encodeEventLog(iface.getEvent(name),args),address,index:n,transactionHash:hash,blockHash:bh,blockNumber,removed:false})),tx={hash,chainId,blockNumber,blockHash:bh,from:safe?A(99):s.caller,to:safe?s.caller:s.call.to,value:0n,data:safe?safeAbi.encodeFunctionData("execTransaction",[s.call.to,0n,s.call.data,0,0,0,0,ZeroAddress,ZeroAddress,"0x"]):s.call.data},r={hash,status:1,blockNumber,blockHash:bh,from:tx.from,to:tx.to,logs};p.getTransaction=async()=>tx;p.getTransactionReceipt=async()=>r;return {hash,tx,r};}
const envEvent=plan=>[host,abi.host,"ReferenceEnvironmentPrepared",[1n,plan.snapshot.environmentId,plan.snapshot.contentHash,plan.snapshot.byteLength]],chunkEvent=(plan,n=0)=>[store,abi.store,"ChunkPublished",[plan.chunks[n].hash,A(100+n),BigInt((plan.chunks[n].bytes.length-2)/2)]];

test("plan preserves original full tuple, host identity, independent callers and exact8192byte chunks",()=>{
  const p=plan("x".repeat(16384));assert(p.chunks.length>1);assert.equal(p.chunks[0].bytes.length,16386);assert.equal(p.steps[0].caller,uploader);assert.equal(p.steps.at(-1).caller,preparer);const decoded=abi.host.decodeFunctionData("prepareEnvironment",p.steps.at(-1).call.data);assert.equal(decoded[0].coverageHash,p.snapshot.environment.coverageHash);assert.equal(decoded[0].packageFiles.length,2);assert(Object.isFrozen(p.snapshot.environment.packageFiles));
  const inventory=prepareReferenceInventoryPlan(deployment,preparer,p.snapshot.packageInventory,{mode:"staged",uploader});assert.equal(inventory.snapshot.inventoryId,p.snapshot.packageInventory.inventoryId);assert.equal(p.steps.length,p.chunks.length+1);
});
test("prerequisites are exact complete inventories, independently combined with environment chunks",async()=>{
  const p=plan();for(const [options,ready]of [[{},false],[{package:true,chunks:true},false],[{package:true,platform:true},false],[{package:true,platform:true,chunks:true},true]]){const i=await flow.inspectReferenceEnvironmentPreparation(provider(p,options),p,{blockTag:10});assert.equal(i.completed,false);assert.equal(i.steps.at(-1).status,ready?"ready":"blocked");assert.equal(i.prerequisites.package,!!options.package);}
});
test("retained-first retry skips inventories and chunk history but still verifies host and Store",async()=>{
  const p=plan(),rpc=provider(p,{retained:true});const i=await flow.inspectReferenceEnvironmentPreparation(rpc,p,{blockTag:10});assert.equal(i.completed,true);assert.equal(i.prerequisites,null);assert.equal(i.chunkAvailability.length,0);assert.equal(rpc.calls.filter(x=>abi.host.parseTransaction({data:x.data})?.name==="preparedFileInventory").length,1);await flow.simulateReferenceEnvironmentStep(rpc,p,p.steps.length-1,{blockTag:10});await assert.rejects(flow.simulateReferenceEnvironmentStep(rpc,p,0,{blockTag:10}),/unnecessary/);
  await assert.rejects(flow.inspectReferenceEnvironmentPreparation(provider(p,{retained:true,code:a=>a===store?"0x6003":undefined}),p,{blockTag:10}),/runtime/);
});
test("current/mode hosts share exactABI and unsupported capability or dependency mismatches reject",async()=>{
  assert.equal(abi.host.getFunction("prepareEnvironment").format("full"),abi.modeHost.getFunction("prepareEnvironment").format("full"));const p=plan();for(const [name,result]of [["supportsInterface",[false]],["deploymentChainId",[1n]],["MAX_CHUNK_BYTES",[4096n]]])await assert.rejects(flow.inspectReferenceEnvironmentPreparation(provider(p,{read:n=>n===name?result:undefined}),p,{blockTag:10}),/dependency|capability/);
  const delegated="0xef0100"+A(90).slice(2),d={...deployment,publicationHost:{address:host,codeHash:keccak256(delegated)}},changed=flow.prepareReferenceEnvironmentPlan(d,preparer,p.snapshot);await assert.rejects(flow.inspectReferenceEnvironmentPreparation(provider(changed,{code:a=>a===host?delegated:undefined}),changed,{blockTag:10}),/runtime/);
});
test("canonicalRPC, exact SSTORE2 chunks and retained payload equality fail closed",async()=>{
  const p=plan();await assert.rejects(flow.inspectReferenceEnvironmentPreparation(provider(p,{read:n=>n==="supportsInterface"?{raw:"0x"+"00".repeat(31)+"02"}:undefined}),p,{blockTag:10}),/Noncanonical/);
  await assert.rejects(flow.inspectReferenceEnvironmentPreparation(provider(p,{chunks:true,code:a=>a===A(100)?"0x01"+p.chunks[0].bytes.slice(2):undefined}),p,{blockTag:10}),/STOP/);
  await assert.rejects(flow.inspectReferenceEnvironmentPreparation(provider(p,{read:(n,args)=>n==="preparedFileInventory"&&args[0]===p.snapshot.environmentId?["0x1234"]:undefined}),p,{blockTag:10}),/Retained bytes/);
});
test("snapshot reconstruction precedes awaits and concrete block reorgs are detected",async()=>{
  const p=plan(),escaped=structuredClone(p),opts={blockTag:10},rpc=provider(p,{mutate:()=>{escaped.snapshot.environment.coverageHash=id("changed");opts.blockTag=99;}});const i=await flow.inspectReferenceEnvironmentPreparation(rpc,escaped,opts);assert.equal(i.plan.snapshot.environment.coverageHash,p.snapshot.environment.coverageHash);assert.equal(i.blockNumber,10);
  await assert.rejects(flow.inspectReferenceEnvironmentPreparation(provider(p,{reorg:true}),p,{blockTag:10}),/Pinned block/);
  escaped.snapshot.environmentId=id("fake");await assert.rejects(flow.inspectReferenceEnvironmentPreparation(provider(p),escaped,{blockTag:10}),/differs/);
});
test("actual caller simulations and pinned gas quotes cover upload and fullinput preparation only when executable",async()=>{
  const p=plan(),rpc=provider(p,{package:true,platform:true,chunks:true});for(const index of [0,p.steps.length-1]){const result=await flow.simulateReferenceEnvironmentStep(rpc,p,index,{blockTag:10});assert.equal(result.identity,p.steps[index].identity);assert.equal(rpc.calls.at(-1).from,p.steps[index].caller);const quote=await flow.quoteReferenceEnvironmentStepGas(rpc,p,index,{blockTag:10,maximumGas:65535n});assert.equal(quote.scope,"inner-call");assert.equal(quote.withinMaximum,false);assert.deepEqual(rpc.estimates.at(-1),{method:"eth_estimateGas",params:[{from:p.steps[index].caller,to:p.steps[index].call.to,data:p.steps[index].call.data,value:"0x0"},"0xa"]});}
  const blocked=provider(p);await assert.rejects(flow.quoteReferenceEnvironmentStepGas(blocked,p,p.steps.length-1,{blockTag:10}),/blocked/);assert.equal(blocked.estimates.length,0);await assert.rejects(flow.quoteReferenceEnvironmentStepGas(provider(p,{package:true,platform:true,chunks:true,gas:"0x0100"}),p,0,{blockTag:10}),/quantity/);
});
test("retained upload simulations must return the observed immutable pointer before gas estimation",async()=>{
  const p=plan(),options={chunks:true,read:name=>name==="publishChunk"?[p.chunks[0].hash,A(200)]:undefined},rpc=provider(p,options);await assert.rejects(flow.simulateReferenceEnvironmentStep(rpc,p,0,{blockTag:10}),/retained chunk pointer/);await assert.rejects(flow.quoteReferenceEnvironmentStepGas(rpc,p,0,{blockTag:10}),/retained chunk pointer/);assert.equal(rpc.estimates.length,0);
  const fresh=await flow.simulateReferenceEnvironmentStep(provider(p,{...options,chunks:false}),p,0,{blockTag:10});assert.equal(fresh.pointer,A(200));
});
test("direct first retention and eventless environment retry prove exact identity and previous block",async()=>{
  const p=plan(),index=p.steps.length-1;for(const reused of [false,true]){const rpc=provider(p,{retained:n=>reused||n>=11}),tx=receipt(rpc,p,index,reused?[]:[envEvent(p)]),out=await flow.inspectReferenceEnvironmentStepReceipt(rpc,p,index,{transactionHash:tx.hash,execution:"direct"});assert.equal(out.retention,reused?"reused":"created");assert.equal(out.priorBlock.retained,reused);assert.equal(out.identity,p.snapshot.environmentId);assert(Object.isFrozen(out.plan.snapshot.environment));}
});
test("Store upload firstevent and eventless retries verify canonical pointer runtime and old availability",async()=>{
  const p=plan();for(const reused of [false,true]){const rpc=provider(p,{chunks:n=>reused||n>=11}),tx=receipt(rpc,p,0,reused?[]:[chunkEvent(p)]),out=await flow.inspectReferenceEnvironmentStepReceipt(rpc,p,0,{transactionHash:tx.hash,execution:"direct"});assert.equal(out.retention,reused?"reused":"created");assert.equal(out.priorBlock.retained,reused);}
  const swapped=provider(p,{chunks:true,read:(name,args,target,tag)=>name==="chunk"&&tag===10?[A(200),BigInt((p.chunks[0].bytes.length-2)/2)]:undefined,code:target=>target===A(200)?"0x00"+p.chunks[0].bytes.slice(2):undefined}),tx=receipt(swapped,p,0,[]);await assert.rejects(flow.inspectReferenceEnvironmentStepReceipt(swapped,p,0,{transactionHash:tx.hash,execution:"direct"}),/Immutable retained chunk pointer changed/);
});
test("both Safe layouts verify exact zero CALL and success after retention",async()=>{
  const p=plan(),index=p.steps.length-1;for(const indexed of [false,true]){const rpc=provider(p,{retained:n=>n>=11}),tx=receipt(rpc,p,index,[envEvent(p)],{safe:true,indexed}),out=await flow.inspectReferenceEnvironmentStepReceipt(rpc,p,index,{transactionHash:tx.hash,execution:"safe"});assert.deepEqual(out.events.map(e=>e.event),["ReferenceEnvironmentPrepared","ExecutionSuccess"]);}
});
test("missing events cannot borrow receiptblock writes and firstevents cannot contradict prior immutable bytes",async()=>{
  const p=plan();for(const index of [0,p.steps.length-1]){const rpc=provider(p,{chunks:n=>n>=11,retained:n=>n>=11}),tx=receipt(rpc,p,index,[]);await assert.rejects(flow.inspectReferenceEnvironmentStepReceipt(rpc,p,index,{transactionHash:tx.hash,execution:"direct"}),/prior-block retained/);}
  const rpc=provider(p,{retained:true}),tx=receipt(rpc,p,p.steps.length-1,[envEvent(p)]);await assert.rejects(flow.inspectReferenceEnvironmentStepReceipt(rpc,p,p.steps.length-1,{transactionHash:tx.hash,execution:"direct"}),/contradicts/);
});
test("Safe failure/order, noncanonical event and wrong complete tuple transaction fail closed",async()=>{
  const p=plan(),index=p.steps.length-1,rpc=provider(p,{retained:n=>n>=11});let tx=receipt(rpc,p,index,[envEvent(p)],{safe:true,success:false});await assert.rejects(flow.inspectReferenceEnvironmentStepReceipt(rpc,p,index,{transactionHash:tx.hash,execution:"safe"}),/one Safe/);
  tx=receipt(rpc,p,index,[envEvent(p)],{safe:true});tx.r.logs.reverse().forEach((x,n)=>x.index=n);await assert.rejects(flow.inspectReferenceEnvironmentStepReceipt(rpc,p,index,{transactionHash:tx.hash,execution:"safe"}),/must follow/);
  tx=receipt(rpc,p,index,[envEvent(p)]);tx.r.logs[0].data+="00";await assert.rejects(flow.inspectReferenceEnvironmentStepReceipt(rpc,p,index,{transactionHash:tx.hash,execution:"direct"}),/Noncanonical/);
  tx=receipt(rpc,p,index,[envEvent(p)]);tx.tx.data=abi.host.encodeFunctionData("prepareEnvironment",[{...p.snapshot.environment,coverageHash:id("different")}]);await assert.rejects(flow.inspectReferenceEnvironmentStepReceipt(rpc,p,index,{transactionHash:tx.hash,execution:"direct"}),/Direct/);
});
