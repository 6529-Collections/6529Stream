import test from "node:test";
import assert from "node:assert/strict";
import { keccak256, id } from "ethers";
import * as w from "../dist/current-token-preservation-output-v2-workflow.js";
import * as p from "../dist/current-token-preservation-output-v2.js";
import { setup, A, H, Z, cp, op, safe, coder } from "./current-token-preservation-output-v2-workflow-fixture.mjs";
const options={blockTag:10,gasLimit:50000000n};
const capture=f=>w.captureTokenPreservationOutputV2(f.provider,f.d,f.caller,f.request,options);
async function successful(f,transport="direct") {const c=await capture(f);await w.simulateTokenPreservationOutputV2(f.provider,c,{blockTag:11});const mined=f.mine(c,transport);return{c,result:await w.reconcileTokenPreservationOutputV2Receipt(f.provider,c,mined.txHash,mined.options),mined};}
function changeEvent(f,index,ifc,name,mutate){const log=f.receipt.logs[index],values=Array.from(ifc.decodeEventLog(name,log.data,log.topics));mutate(values);Object.assign(log,ifc.encodeEventLog(ifc.getEvent(name),values));}
test("all four source writes capture/simulate/reconcile direct and both Safe event layouts",async()=>{
  for(const method of ["begin","append","beginManifest","verifyNextOutputs"])for(const transport of ["direct","legacy","indexed"]){const f=setup({method});const {result}=await successful(f,transport);assert.equal(result.eventlessRetry,false);assert.equal(result.finalityEstablished,false);assert.ok(f.calls.some(c=>c.name===method&&c.from===f.caller));}
});
test("COLLECTION TOKEN RELEASE SEASON preserve mixed producer markers and burned token identity",async()=>{
  for(const scopeType of [0n,1n,2n,3n]){const f=setup({scopeKind:scopeType===0n?"collection":"scoped",scopeType,burned:true});const {c}=await successful(f);assert.equal(c.stage.expected.scope.scopeType,scopeType);assert.equal(c.stage.appended[0].preservation.profile,p.TOKEN_PRESERVATION_OUTPUT_V2_ORIGINAL_PRODUCER);if(scopeType!==1n)assert.equal(c.stage.appended[1].preservation.profile,p.TOKEN_PRESERVATION_OUTPUT_V2_CURRENT_ARTIST_PRODUCER);}
});
test("checkpoint begin retry rechecks Selection/source and authenticates prefix without rerendering",async()=>{
  const f=setup({method:"begin",retry:true,prefix:1});f.hook=q=>{if(q.name.startsWith("preservationToken"))throw Error("must not render retry");};const {result}=await successful(f);assert.equal(result.eventlessRetry,true);assert.ok(f.calls.some(c=>c.name==="requireCurrentSourceSet"));
  const g=setup({method:"begin",retry:true,prefix:1});g.hook=q=>{if(q.name==="requireCurrentSourceSet")throw Error("stale source");};await assert.rejects(capture(g),/stale source/);
});
test("append rerenders saved prefix and rejects changed producer output or mismatched new payload",async()=>{
  const f=setup({prefix:1,appendCount:1});await successful(f);
  const g=setup({prefix:1});g.hook=q=>q.name==="preservationTokenJSON"&&q.args[0]===10n?{raw:coder.encode(["bytes"],["0xffff"])}:undefined;await assert.rejects(capture(g),/stale/);
  const h=setup();h.request.payloads[0].animation="0xff";await assert.rejects(capture(h),/animation/);
});
test("exact selected Registry full binding and seven admission fields are required without ACTIVE reauthorization",async()=>{
  for(const field of ["registry","registryCodeHash","versionKey","registrationHash","readSetHash","analysisHash","goldenHash"]){const f=setup();f.admissions[0][field]=field==="registry"?A(88):Z;await assert.rejects(capture(f));}
  const f=setup();f.hook=q=>{if(q.name==="requirePreservation"){const {metadataRouter,...b}=f.bindings[0];return[{...b,router:A(88)},f.admissions[0]];}};await assert.rejects(capture(f),/full producer binding/);
  const g=setup();await capture(g);assert.equal(g.calls.some(q=>/isEligible|requireAssignable|requireActive/.test(q.name)),false);
});
test("VIEW and unknown producers, source registration drift and full scope aliases refuse",async()=>{
  for(const marker of [id("6529STREAM_VIEW_PRESERVATION_RENDER_V1"),H(999)]){const f=setup();f.hook=q=>q.name==="preservationProfile"?[marker]:undefined;await assert.rejects(capture(f),/closed token/);}
  const f=setup();f.hook=q=>q.name==="sourceSetForPlan"?[A(99),H(99)]:undefined;await assert.rejects(capture(f),/registration/);
  const g=setup({scopeType:1n});g.hook=q=>q.name==="sourceScope"?[{...g.scope,collectionId:10n}]:undefined;await assert.rejects(capture(g),/Full source scope/);
});
test("terminal DISABLED/ASYNC_NOT_REQUIRED and finalized ASYNC zero seed use distinct exact evidence",async()=>{
  for(const v of [{},{notRequired:true},{finalized:true}]){const f=setup(v),c=await capture(f);assert.equal(c.stage.appended[0].entropy.seed,Z);assert.equal(f.calls.some(q=>q.name==="staticTokenRenderFacts"),!!v.finalized);}
  const f=setup({finalized:true});f.hook=q=>q.name==="staticTokenRenderFacts"?[5n,H(5),A(45)]:undefined;await assert.rejects(capture(f),/Native finalized/);
  const g=setup();g.terminals[0].policyChainHash=H(999);await assert.rejects(capture(g),/Terminal source/);
});
test("partial verify admits retained bytes after source retirement while final verify requires full current admission",async()=>{
  const f=setup({method:"verifyNextOutputs",count:1n});f.codeHook=(to)=>to===f.pins.source.address?"0x":undefined;f.hook=q=>{if(["requireCurrentSourceSet","requireArtifactCoverage","document"].includes(q.name))throw Error("should skip current");};const {c}=await successful(f);assert.equal(c.stage.currentAdmission,false);
  const g=setup({method:"verifyNextOutputs",verified:1,count:1n});g.hook=q=>{if(q.name==="requireCurrentSourceSet")throw Error("stale final");};await assert.rejects(capture(g),/stale final/);
  const h=setup({method:"verifyNextOutputs",verified:1,count:1n});const {result}=await successful(h);assert.equal(result.result.recordHash,h.recordHash);
});
test("genuine covered bytes and only two V2 interpretation documents precede manifest starts",async()=>{
  const f=setup({method:"beginManifest"});await successful(f);const docs=f.calls.filter(q=>q.name==="document").map(q=>q.args[0]);assert.ok(docs.length>0);assert.equal(docs.includes(p.TOKEN_PRESERVATION_OUTPUT_V2_LEAF_SCHEMA),false);
  const g=setup({method:"beginManifest"});g.coverage.secondFamilyRecordHash=g.coverage.firstFamilyRecordHash;await assert.rejects(capture(g),/coverage/);
  const h=setup({method:"beginManifest"});h.code.set(h.chunks[0].address,`0x01${h.canonical.slice(2)}`);await assert.rejects(capture(h),/STOP/);
});
test("fresh and retained beginManifest event semantics, exact verify bounds and completion retry refusal",async()=>{
  const f=setup({method:"beginManifest",retry:true,verified:1});const {result}=await successful(f);assert.equal(result.eventlessRetry,true);
  const g=setup({method:"beginManifest"});const c=await capture(g),m=g.mine(c);g.receipt.logs=[];await assert.rejects(w.reconcileTokenPreservationOutputV2Receipt(g.provider,c,m.txHash,m.options),/event/);
  await assert.rejects(capture(setup({method:"verifyNextOutputs",verified:2,count:1n})),/remaining/);
  const h=setup({method:"verifyNextOutputs"});h.request.count=17n;await assert.rejects(capture(h));
});
test("checkpoint schema1 and output schema2 exact event count/order/full tuple joins",async()=>{
  for(const mutation of ["schema","missing","duplicate","order","row"]){const f=setup(),c=await capture(f),m=f.mine(c);if(mutation==="schema")changeEvent(f,0,cp,"StaticContentAppended",v=>v[0]=2n);if(mutation==="missing")f.receipt.logs.pop();if(mutation==="duplicate")f.receipt.logs.push({...f.receipt.logs[0],index:3});if(mutation==="order"){[f.receipt.logs[0],f.receipt.logs[1]]=[f.receipt.logs[1],f.receipt.logs[0]];f.receipt.logs.forEach((r,i)=>r.index=i);}if(mutation==="row")changeEvent(f,0,cp,"StaticContentAppended",v=>v[4]=H(999));await assert.rejects(w.reconcileTokenPreservationOutputV2Receipt(f.provider,c,m.txHash,m.options),/event|order/);}
  const f=setup({method:"verifyNextOutputs"}),c=await capture(f),m=f.mine(c);changeEvent(f,0,op,"OutputManifestAdvanced",v=>v[0]=1n);await assert.rejects(w.reconcileTokenPreservationOutputV2Receipt(f.provider,c,m.txHash,m.options),/event/);
});
test("saved block, prior state and exact end block attribution reject reorg/concurrent progress",async()=>{
  const f=setup(),c=await capture(f);f.provider.getBlock=async tag=>({number:tag,hash:H(99000+tag),timestamp:1000+tag});await assert.rejects(w.simulateTokenPreservationOutputV2(f.provider,c,{blockTag:11}),/Pinned block/);
  const g=setup(),d=await capture(g),m=g.mine(d);g.hook=q=>q.name==="checkpoint"&&q.blockTag===11?[g.content(1)]:undefined;await assert.rejects(w.reconcileTokenPreservationOutputV2Receipt(g.provider,d,m.txHash,m.options),/changed|remaining rows/);
  const h=setup({prefix:0,appendCount:1}),e=await capture(h),n=h.mine(e);h.hook=q=>q.name==="checkpoint"&&q.blockTag===12?[h.completed]:undefined;await assert.rejects(w.reconcileTokenPreservationOutputV2Receipt(h.provider,e,n.txHash,n.options),/Mined checkpoint/);
});
test("receipt-block host/link/producer/source/carrier runtime changes are rejected",async()=>{
  for(const key of ["link","producer0","source","selection"]){const f=setup(),c=await capture(f),m=f.mine(c);f.codeHook=(to,tag)=>tag===12&&to===f.pins[key].address?"0x6000":undefined;await assert.rejects(w.reconcileTokenPreservationOutputV2Receipt(f.provider,c,m.txHash,m.options),/runtime/);}
  const f=setup({method:"verifyNextOutputs",count:1n}),c=await capture(f),m=f.mine(c);f.codeHook=(to,tag)=>tag===12&&to===f.chunks[0].address?"0x6000":undefined;await assert.rejects(w.reconcileTokenPreservationOutputV2Receipt(f.provider,c,m.txHash,m.options),/runtime/);
});
test("local historical roots remain readable after upstream loss while current requires actual producers",async()=>{
  const f=setup({method:"beginManifest",retry:true,verified:2});f.codeHook=to=>[f.pins.source.address,f.pins.producer0.address,f.pins.registry.address].includes(to)?"0x":undefined;
  const h=await w.inspectTokenPreservationOutputV2History(f.provider,f.d,{kind:"manifest",recordHash:f.recordHash},{blockTag:10});assert.equal(h.currentAdmissionChecked,false);
  const g=await w.inspectTokenPreservationOutputV2History(f.provider,f.d,{kind:"checkpoint",id:f.key},{blockTag:10});assert.equal(g.retained.outputs.length,2);
  await assert.rejects(w.inspectTokenPreservationOutputV2Current(f.provider,f.d,{kind:"checkpoint",id:f.key},{blockTag:10}),/runtime/);
  const alive=setup({method:"beginManifest",retry:true,verified:2});await w.inspectTokenPreservationOutputV2Current(alive.provider,alive.d,{kind:"manifest",recordHash:alive.recordHash},{blockTag:10});
});
test("refusal retains exact RPC error, fixed state observations and never claims rollback",async()=>{
  for(const code of ["CALL_EXCEPTION","NETWORK_ERROR"]){const f=setup(),c=await capture(f),failure=Object.assign(Error("original capped JSON/image refusal"),{code});f.hook=q=>{if(q.name==="append")throw failure;};const r=await w.observeTokenPreservationOutputV2Refusal(f.provider,c,{blockTag:11});assert.equal(r.error,failure);assert.equal(r.nativeRollbackProven,false);assert.equal(r.retainedStateUnchanged,true);assert.equal(r.outcome,code==="CALL_EXCEPTION"?"execution-reverted":"rpc-failed");}
});
test("Safe independent hash, CALL operation/value and success ordering are exact",async()=>{
  for(const fault of ["hash","operation","value","early","failure"]){const f=setup(),c=await capture(f),m=f.mine(c,"indexed");if(fault==="hash")m.options.expectedSafeTxHash=H(333);if(fault==="operation"||fault==="value"){const args=Array.from(safe.decodeFunctionData("execTransaction",f.transaction.data));args[fault==="operation"?3:1]=1n;f.transaction.data=safe.encodeFunctionData("execTransaction",args);}if(fault==="early"){f.receipt.logs.unshift(f.receipt.logs.pop());f.receipt.logs.forEach((r,i)=>r.index=i);}if(fault==="failure"){const log=f.receipt.logs.at(-1);Object.assign(log,safe.encodeEventLog(safe.getEvent("ExecutionFailure"),[H(901),0n]));}await assert.rejects(w.reconcileTokenPreservationOutputV2Receipt(f.provider,c,m.txHash,m.options));}
});
test("RPC inputs/options and mined logs are detached before first asynchronous mutation",async()=>{
  const f=setup(),d=structuredClone(f.d),q=structuredClone(f.request),o={...options};f.networkHook=()=>{d.scopeKind="collection";q.payloads[0].tokenId=999n;o.blockTag=55;};const c=await w.captureTokenPreservationOutputV2(f.provider,d,f.caller,q,o);assert.equal(c.deployment.scopeKind,"scoped");assert.equal(c.prepared.request.payloads[0].tokenId,10n);assert.ok(f.calls.every(r=>r.blockTag===10));
  f.networkHook=null;const m=f.mine(c);const original=f.provider.getTransaction;f.provider.getTransaction=async()=>{f.receipt.logs[0].data="0x";return original();};await w.reconcileTokenPreservationOutputV2Receipt(f.provider,c,m.txHash,m.options);
});
test("malformed canonical RPC, receipt identity/index/removal and concrete client bounds refuse",async()=>{
  const f=setup();f.hook=q=>q.name==="core"?{raw:`${coder.encode(["address"],[f.pins.core.address])}00`}:undefined;await assert.rejects(capture(f));
  for(const fault of ["removed","fraction","metadata","endpoint"]){const g=setup(),c=await capture(g),m=g.mine(c);if(fault==="removed")g.receipt.logs[0].removed=true;if(fault==="fraction")g.receipt.logs[0].index=0.5;if(fault==="metadata")delete g.receipt.logs[0].transactionHash;if(fault==="endpoint")g.receipt.to=A(99);await assert.rejects(w.reconcileTokenPreservationOutputV2Receipt(g.provider,c,m.txHash,m.options));}
  const g=setup({method:"begin"});g.selection.tokenCount=16385n;g.selection.nextIndex=16385n;await assert.rejects(capture(g),/Client checkpoint row bound/);
});
test("canonical EVM string bytes preserve invalid UTF8 without claiming original pattern admission",async()=>{
  const f=setup({json:"0xfffe",html:"0xff"});const c=await capture(f);assert.equal(c.stage.appended[0].leaf.metadataHash,keccak256("0xfffe"));assert.equal(c.stage.appended[0].leaf.animationHash,keccak256("0xff"));
  f.hook=q=>{if(q.name==="append")throw Object.assign(Error("original JSON pattern refused"),{code:"CALL_EXCEPTION"});};await assert.rejects(w.simulateTokenPreservationOutputV2(f.provider,c,{blockTag:11}),/pattern refused/);
});
test("task-local direct and Safe transport admit append calldata above the historical 2MiB cap",async()=>{
  const html=`0x${"61".repeat(2_097_153)}`;
  for(const transport of ["direct","indexed"]){const f=setup({tokens:1,scopeType:1n,html});const {c}=await successful(f,transport);assert.ok((c.prepared.call.data.length-2)/2>2_097_152);}
});
test("producer exact 16MiB string plus ABI64 is accepted and one byte over is refused",async()=>{
  const raw=`0x${"61".repeat(16_777_216)}`;
  const f=setup({tokens:1,scopeType:1n,json:raw});const c=await capture(f);assert.equal(c.stage.appended[0].leaf.metadataHash,keccak256(raw));
  const g=setup({tokens:1,scopeType:1n});g.hook=q=>q.name==="preservationTokenJSON"?{raw:coder.encode(["bytes"],[`${raw}61`])}:undefined;await assert.rejects(capture(g),/oversized/);
});
test("fully rehashed local TOKEN history rejects a different member and multi-token count without live admission",async()=>{
  const f=setup({method:"beginManifest",scopeType:1n});const output=structuredClone(f.outputs[0]);output.leaf.tokenId=99n;
  const leafHash=p.tokenPreservationOutputV2LeafHash(1n,f.pins.core.address,output.leaf);
  const forged={...f.completed,leafChainHash:p.tokenPreservationOutputV2LeafChain(Z,0n,leafHash),outputRoot:p.tokenPreservationOutputV2OutputChain(Z,0n,output),contentRoot:p.tokenPreservationOutputV2ContentRoot(1n,f.pins.core.address,[output.leaf])};
  f.hook=q=>q.name==="checkpoint"?[forged]:q.name==="outputAt"?[output]:undefined;
  await assert.rejects(w.inspectTokenPreservationOutputV2History(f.provider,f.d,{kind:"checkpoint",id:f.key},{blockTag:10}),/full TOKEN identity/);
  const g=setup({method:"beginManifest",retry:true,verified:2});const manifest={...g.manifest,scope:{scopeType:1n,collectionId:9n,tokenId:10n,scopeId:Z}};
  const key=p.tokenPreservationOutputV2ManifestPlanHash(g.coords,g.pins.coverage.address,manifest),record=p.tokenPreservationOutputV2RecordHash(key);
  g.hook=q=>q.name==="manifestRecord"?[manifest]:q.name==="manifestPlan"?[{manifest,nextIndex:2n,recordHash:record}]:undefined;
  await assert.rejects(w.inspectTokenPreservationOutputV2History(g.provider,g.d,{kind:"manifest",recordHash:record},{blockTag:10}),/TOKEN manifest count/);
});
test("current reader snapshots block options and receipt outer/runtime infrastructure bounds are explicit",async()=>{
  const f=setup({method:"beginManifest",retry:true,verified:2}),o={blockTag:10};f.networkHook=()=>{o.blockTag=99;};await w.inspectTokenPreservationOutputV2Current(f.provider,f.d,{kind:"checkpoint",id:f.key},o);assert.ok(f.calls.every(c=>c.blockTag===10));
  const g=setup(),d=structuredClone(g.d),marker=`0xef0100${A(80).slice(2)}`;g.code.set(d.checkpoint.address,marker);d.checkpoint.codeHash=keccak256(marker);await assert.rejects(w.captureTokenPreservationOutputV2(g.provider,d,g.caller,g.request,options),/runtime/);
  const h=setup(),c=await capture(h),m=h.mine(c);h.receipt.blockNumber=10;h.receipt.blockHash=H(10010);h.receipt.logs.forEach(r=>{r.blockNumber=10;r.blockHash=H(10010);});h.transaction.blockNumber=10;h.transaction.blockHash=H(10010);await assert.rejects(w.reconcileTokenPreservationOutputV2Receipt(h.provider,c,m.txHash,m.options),/follow capture/);
});
