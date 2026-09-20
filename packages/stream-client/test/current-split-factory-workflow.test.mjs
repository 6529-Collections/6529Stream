import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as pure from "../dist/current-split-factory.js";
import * as flow from "../dist/current-split-factory-workflow.js";

const fixture=JSON.parse(readFileSync(new URL("./fixtures/current-split-factory-abi.json",import.meta.url),"utf8"));
const abi=Object.fromEntries(Object.entries(fixture.abis).map(([k,v])=>[k,new Interface(v)]));
const A=n=>getAddress(`0x${BigInt(n).toString(16).padStart(40,"0")}`),factory=A(1),implementation=A(2),assetPolicy=A(3),caller=A(4),factoryCode="0x6001600055",implementationCode="0x6002600055",assetCode="0x6003600055";
const deployment={chainId:31337n,factory:{address:factory,codeHash:keccak256(factoryCode)},implementation:{address:implementation,codeHash:keccak256(implementationCode)},assetPolicy:{address:assetPolicy,codeHash:keccak256(assetCode)}};
const context={chainId:deployment.chainId,factory,profileDomain:id("6529STREAM_SPLIT_PROFILE_V1"),schemaVersion:1n,walletVersion:4n,...pure.splitWalletCloneHashes(implementation),assetPolicyRegistry:assetPolicy};
const entries=[{account:A(11),sharePpm:500000n,labelId:id("b")},{account:A(10),sharePpm:200000n,labelId:id("a")},{account:A(10),sharePpm:300000n,labelId:ZeroHash}],profile=pure.prepareSplitProfile(context,entries,id("metadata"));
const blockHash=n=>id(`block:${n}`);
function provider(options={}){
  const calls=[],seen=new Map(),selected=options.profile??profile,registered=tag=>typeof options.registered==="function"?options.registered(tag):!!options.registered,deployed=tag=>typeof options.deployed==="function"?options.deployed(tag):!!options.deployed;
  return {calls,async getNetwork(){options.mutate?.();return {chainId:options.chainId??deployment.chainId};},async getBlock(n){seen.set(n,(seen.get(n)??0)+1);return {number:n,hash:options.reorg&&seen.get(n)>1?id("changed"):blockHash(n)};},async getCode(target,tag){if(options.code){const value=options.code(target,tag);if(value!==undefined)return value;}return target===factory?factoryCode:target===implementation?implementationCode:target===assetPolicy?assetCode:target===selected.wallet&&deployed(tag)?pure.splitWalletCloneRuntime(implementation):"0x";},
    async call(tx){calls.push(tx);const target=getAddress(tx.to),tag=tx.blockTag,iface=target===factory?abi.factory:target===assetPolicy?abi.assetPolicy:abi.wallet,desc=iface.parseTransaction({data:tx.data}),name=desc.name,args=desc.args;const override=options.read?.(name,args,target,tag,tx);if(override?.raw!==undefined)return override.raw;if(override!==undefined)return iface.encodeFunctionResult(name,override);let out;
      if(name==="PROFILE_DOMAIN")out=[context.profileDomain];else if(name==="SCHEMA_VERSION")out=[1n];else if(name==="WALLET_VERSION")out=[4n];else if(name==="MAX_ENTRIES"||name==="MAX_UNIQUE_ACCOUNTS")out=[64n];else if(name==="SHARE_DENOMINATOR_PPM")out=[1000000n];else if(name==="assetPolicyRegistry")out=[assetPolicy];else if(name==="splitWalletImplementation")out=[implementation];else if(name==="splitWalletImplementationCodeHash")out=[deployment.implementation.codeHash];else if(name==="splitWalletInitCodeHash")out=[context.initCodeHash];else if(name==="splitWalletRuntimeCodeHash")out=[context.runtimeCodeHash];else if(name==="supportsInterface")out=[args[0]!=="0xffffffff"];else if(name==="isStreamAssetPolicyRegistry")out=[true];else if(name==="ASSET_STATUS_ACTIVE")out=[1n];
      else if(name==="factory")out=[factory];else if(name==="initialized")out=[true];else if(name==="profileId")out=[target===implementation?ZeroHash:selected.profileId];else if(name==="entriesHash")out=[target===implementation?ZeroHash:selected.entriesHash];else if(name==="metadataURIHash")out=[target===implementation?ZeroHash:selected.metadataURIHash];
      else if(name==="profileExists")out=[registered(tag)];else if(name==="splitWalletExists")out=[registered(tag)&&deployed(tag)];else if(name==="profileEntriesHash")out=[registered(tag)?selected.entriesHash:ZeroHash];else if(name==="profileMetadataURIHash")out=[registered(tag)?selected.metadataURIHash:ZeroHash];
      else if(name==="walletFor")out=[selected.wallet];else if(name==="profileIdFor")out=[selected.profileId];
      else if(name==="entryCount")out=[target===implementation?0n:BigInt(selected.entries.length)];else if(name==="uniqueAccountCount")out=[target===implementation?0n:BigInt(selected.accounts.length)];else if(name==="profileEntryCount")out=[registered(tag)?BigInt(selected.entries.length):0n];else if(name==="profileUniqueAccountCount")out=[registered(tag)?BigInt(selected.accounts.length):0n];
      else if(name==="profileEntry"||name==="entry"){const row=selected.entries[Number(args[name==="profileEntry"?1:0])];out=[row.account,row.sharePpm,row.labelId];}
      else if(name==="profileUniqueAccount"||name==="uniqueAccount"){const n=Number(args[name==="profileUniqueAccount"?1:0]);out=[selected.accounts[n],selected.aggregateSharePpm[n]];}
      else if(name==="aggregateSharePpm")out=[selected.aggregateSharePpm[selected.accounts.indexOf(args[0])]];
      else if(name==="createProfile"||name==="registerProfile"){if(options.registrationBlocked)throw Error("RevenueRuntimeUnavailable");out=[selected.profileId,selected.wallet];}
      else if(name==="deployWallet")out=[selected.wallet];else throw Error(`Unexpected ${name}`);return iface.encodeFunctionResult(name,out);
    }};
}
async function setup(options={},kind="create-profile"){const p=provider(options),capture=await flow.captureSplitFactory(p,deployment,{blockTag:10}),operation=flow.prepareSplitFactoryOperation(capture,options.profile??profile,kind,caller);return {p,capture,operation};}
const safeAbi=new Interface(["function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)"]);
function receipt(p,operation,eventSpecs,{safe=false,indexed=false,success=true,blockNumber=11}={}){const hash=id("transaction"),bh=blockHash(blockNumber),specs=[...eventSpecs],safeEvents=new Interface([`event ExecutionSuccess(bytes32 ${indexed?"indexed ":""}txHash,uint256 payment)`]);if(safe&&success)specs.push([caller,safeEvents,"ExecutionSuccess",[id("safeTx"),0n]]);const logs=specs.map(([address,iface,event,args],index)=>({...iface.encodeEventLog(iface.getEvent(event),args),address,index,transactionHash:hash,blockHash:bh,blockNumber,removed:false})),tx={hash,chainId:deployment.chainId,blockHash:bh,blockNumber,from:safe?A(99):caller,to:safe?caller:factory,value:0n,data:safe?safeAbi.encodeFunctionData("execTransaction",[factory,0n,operation.call.data,0,0,0,0,ZeroAddress,ZeroAddress,"0x"]):operation.call.data},r={hash,status:1,from:tx.from,to:tx.to,blockHash:bh,blockNumber,logs};p.getTransaction=async()=>tx;p.getTransactionReceipt=async()=>r;return {hash,tx,r};}
function profileEvents(selected=profile){return [[factory,abi.factory,"SplitProfileCreated",[selected.profileId,selected.entriesHash,selected.metadataURIHash,1n,4n,selected.wallet]],...selected.entries.map((row,n)=>[factory,abi.factory,"SplitProfileEntry",[selected.profileId,BigInt(n),row.account,1n,row.sharePpm,row.labelId]])];}
function walletEvent(name="SplitWalletDeployed"){return [factory,abi.factory,name,[profile.profileId,profile.wallet,4n,1n,context.initCodeHash,context.runtimeCodeHash]];}

test("capture pins actual singleton, V4 profile constants, exact per-factory clone hashes and immutability",async()=>{
  const {capture}=await setup();assert.equal(capture.snapshot.context.walletVersion,4n);assert.deepEqual(capture.snapshot.implementation,deployment.implementation);assert(Object.isFrozen(capture.snapshot.implementation));assert.equal((pure.splitWalletCloneRuntime(implementation).length-2)/2,52);
  for(const [name,answer]of [["WALLET_VERSION",[3n]],["splitWalletInitCodeHash",[id("universal-hash")]],["splitWalletImplementation",[A(999)]],["MAX_ENTRIES",[63n]]])await assert.rejects(flow.captureSplitFactory(provider({read:n=>n===name?answer:undefined}),deployment,{blockTag:10}));
});
test("implementation must remain locked with factory and empty immutable profile storage",async()=>{
  for(const [name,answer]of [["factory",[A(999)]],["initialized",[false]],["profileId",[profile.profileId]],["entryCount",[1n]],["metadataURIHash",[id("user-metadata")]]])await assert.rejects(flow.captureSplitFactory(provider({read:(n,a,t)=>n===name&&t===implementation?answer:undefined}),deployment,{blockTag:10}),/Singleton/);
  await assert.rejects(flow.captureSplitFactory(provider({code:a=>a===implementation?"0x6004600055":undefined}),deployment,{blockTag:10}),/runtime/);
});
test("capture snapshots before first await and rejects wrong chain, malformed bool and reorg",async()=>{
  const d=structuredClone(deployment),options={blockTag:10};const captured=await flow.captureSplitFactory(provider({mutate:()=>{d.factory.address=A(999);options.blockTag=99;}}),d,options);assert.equal(captured.deployment.factory.address,factory);assert.equal(captured.blockNumber,10);
  await assert.rejects(flow.captureSplitFactory(provider({chainId:1n}),deployment,{blockTag:10}),/chain/);await assert.rejects(flow.captureSplitFactory(provider({reorg:true}),deployment,{blockTag:10}),/Pinned block/);
  await assert.rejects(flow.captureSplitFactory(provider({read:n=>n==="isStreamAssetPolicyRegistry"?{raw:"0x"+"00".repeat(31)+"02"}:undefined}),deployment,{blockTag:10}),/Noncanonical/);
});
test("predicted, registered and initialized states stay distinct; prefunding is not a code test",async()=>{
  for(const [options,expected]of [[{},"unregistered"],[{registered:true},"registered"],[{registered:true,deployed:true},"initialized"]]){const {p,capture}=await setup(options);const out=await flow.inspectSplitFactoryProfile(p,capture,profile,{blockTag:10});assert.equal(out.status,expected);assert.equal(out.initialized,expected==="initialized");assert.equal(out.profile.wallet,profile.wallet);}
});
test("full original factory and clone rows and aggregates are checked at the pinned block",async()=>{
  for(const bad of ["profileEntry","profileUniqueAccount","entry","uniqueAccount","aggregateSharePpm"]){const {p,capture}=await setup({registered:true,deployed:true,read:(name,args,target)=>name===bad?(name==="aggregateSharePpm"?[1n]:name.endsWith("Entry")||name==="entry"?[A(90),1n,ZeroHash]:[A(90),1n]):undefined});await assert.rejects(flow.inspectSplitFactoryProfile(p,capture,profile,{blockTag:10}),/entry|aggregate/i);}
  const rows=Array.from({length:64},(_,n)=>({account:A(100+n),sharePpm:15625n,labelId:ZeroHash})),large=pure.prepareSplitProfile(context,rows,ZeroHash),{p,capture}=await setup({profile:large,registered:true,deployed:true});assert.equal((await flow.inspectSplitFactoryProfile(p,capture,large,{blockTag:10})).profile.entries.length,64);
});
test("unknown, wrong clone, false recognition and uninitialized storage fail closed",async()=>{
  for(const options of [{registered:true,deployed:true,code:a=>a===profile.wallet?pure.splitWalletCloneRuntime(A(999)):undefined},{registered:true,deployed:true,read:(n,a,t)=>n==="initialized"&&t===profile.wallet?[false]:undefined},{registered:true,deployed:true,read:n=>n==="splitWalletExists"?[false]:undefined},{registered:false,deployed:true},{registered:true,read:n=>n==="walletFor"?[A(999)]:undefined}]){const {p,capture}=await setup(options);await assert.rejects(flow.inspectSplitFactoryProfile(p,capture,profile,{blockTag:10}));}
});
test("all three operations simulate exact zero-value calldata from the actual caller",async()=>{
  for(const kind of ["register-profile","create-profile","deploy-wallet"]){const {p,operation}=await setup({registered:true},kind);const sim=await flow.simulateSplitFactoryOperation(p,operation,{blockTag:10});assert.equal(sim.operation.call.value,0n);assert.equal(p.calls.at(-1).from,caller);assert.equal(p.calls.at(-1).data,operation.call.data);}
  const {p,operation}=await setup({},"deploy-wallet");await assert.rejects(flow.simulateSplitFactoryOperation(p,operation,{blockTag:10}),/unknown profile/);
});
test("register and create retries require admission while existing-profile lazy deploy retains its original path",async()=>{
  for(const kind of ["register-profile","create-profile","deploy-wallet"]){const {p,operation}=await setup({registered:true,registrationBlocked:true},kind);if(kind==="deploy-wallet")await flow.simulateSplitFactoryOperation(p,operation,{blockTag:10});else await assert.rejects(flow.simulateSplitFactoryOperation(p,operation,{blockTag:10}),/Unavailable/);}
});
test("prepared-call tampering and implementation drift on retry cannot refresh reviewed inputs",async()=>{
  const {p,operation}=await setup({registered:true});const escaped=structuredClone(operation);escaped.call.data+="00";await assert.rejects(flow.simulateSplitFactoryOperation(p,escaped,{blockTag:10}),/reconstruction/);
  const drift=provider({registered:true,code:(a,tag)=>a===implementation&&tag===11?"0x6004600055":undefined});await assert.rejects(flow.simulateSplitFactoryOperation(drift,operation,{blockTag:11}),/runtime/);
});
test("direct create receipt binds registration, all canonical entry events and initialized clone",async()=>{
  const {p,operation}=await setup({registered:n=>n>=11,deployed:n=>n>=11}),tx=receipt(p,operation,[...profileEvents(),walletEvent()]);const out=await flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"direct"});assert.equal(out.registration,"created");assert.equal(out.deployment,"deployed");assert.equal(out.observed.status,"initialized");assert.equal(out.events.length,5);assert(Object.isFrozen(out.observed.profile.entries));
});
test("registration reports later same-block wallet creation as observation without attributing deployment",async()=>{
  const {p,operation}=await setup({registered:n=>n>=11,deployed:n=>n>=11},"register-profile"),tx=receipt(p,operation,profileEvents());const out=await flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"direct"});assert.equal(out.deployment,"not-requested");assert.equal(out.observed.deployed,true);assert.match(out.stateAttribution,/observation/);
});
test("registered create, discovered clone and all eventless retry variants retain exact readback",async()=>{
  for(const [kind,events_,expected]of [["create-profile",[walletEvent()],"deployed"],["deploy-wallet",[walletEvent("SplitWalletDiscovered")],"discovered"],["create-profile",[],"reused"],["deploy-wallet",[],"reused"],["register-profile",[],"not-requested"]]){const {p,operation}=await setup({registered:true,deployed:expected==="deployed"?n=>n>=11:true},kind),tx=receipt(p,operation,events_);const out=await flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"direct"});assert.equal(out.registration,"reused");assert.equal(out.deployment,expected);assert.equal(out.prior.registered,true);}
});
test("missing lifecycle events cannot borrow later same-block registration or deployment",async()=>{
  for(const [options,kind,message]of [[{registered:n=>n>=11},"register-profile",/registration evidence/],[{registered:true,deployed:n=>n>=11},"create-profile",/initialization evidence/],[{registered:true,deployed:n=>n>=11},"deploy-wallet",/initialization evidence/]]){const {p,operation}=await setup(options,kind),tx=receipt(p,operation,[]);await assert.rejects(flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"direct"}),message);}
});
test("Safe success must occur after the factory lifecycle events",async()=>{
  const {p,operation}=await setup({registered:n=>n>=11,deployed:n=>n>=11}),tx=receipt(p,operation,[...profileEvents(),walletEvent()],{safe:true});const success=tx.r.logs.pop();tx.r.logs.unshift(success);tx.r.logs.forEach((x,n)=>x.index=n);await assert.rejects(flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"safe"}),/success must follow/);
});
test("both Safe success event layouts verify the exact ordinary CALL and repeated input",async()=>{
  for(const indexed of [false,true]){const {p,operation}=await setup({registered:true,deployed:true},"deploy-wallet"),tx=receipt(p,operation,[],{safe:true,indexed});const out=await flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"safe"});assert.equal(out.events[0].event,"ExecutionSuccess");assert.equal(out.deployment,"reused");}
});
test("Safe failure, delegatecall, noncanonical topics and stale receipt block are rejected",async()=>{
  const {p,operation}=await setup({registered:true,deployed:true},"deploy-wallet");let tx=receipt(p,operation,[],{safe:true,success:false});await assert.rejects(flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"safe"}),/Safe requires/);
  tx=receipt(p,operation,[],{safe:true});tx.tx.data=safeAbi.encodeFunctionData("execTransaction",[factory,0n,operation.call.data,1,0,0,0,ZeroAddress,ZeroAddress,"0x"]);await assert.rejects(flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"safe"}),/ordinary/);
  tx=receipt(p,operation,[walletEvent()]);tx.r.logs[0].topics[1]="0x01";await assert.rejects(flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"direct"}),/bytes32/);
  tx=receipt(p,operation,[],{blockNumber:10});await assert.rejects(flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"direct"}),/chronology/);
});
test("receipt lifecycle composition and every canonical event field are enforced",async()=>{
  const {p,operation}=await setup({registered:true,deployed:true});let tx=receipt(p,operation,[...profileEvents().slice(0,-1),walletEvent()]);await assert.rejects(flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"direct"}),/count/);
  tx=receipt(p,operation,[...profileEvents(),walletEvent(),walletEvent("SplitWalletDiscovered")]);await assert.rejects(flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"direct"}),/composition/);
  const bad=walletEvent();bad[3][4]=id("wrong-init");tx=receipt(p,operation,[bad]);await assert.rejects(flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"direct"}),/deployment event/);
  tx=receipt(p,operation,[walletEvent()]);tx.r.logs[0].data+="00";await assert.rejects(flow.inspectSplitFactoryOperationReceipt(p,operation,{transactionHash:tx.hash,execution:"direct"}),/Noncanonical/);
});
