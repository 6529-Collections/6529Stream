import test from "node:test";
import assert from "node:assert/strict";
import { Interface, id, keccak256 } from "ethers";
import { setup, environment, fileRows, A,H,Z,ZA,coder,safe,r,c } from "./current-token-preservation-reference-v2-workflow-fixture.mjs";
import * as w from "../dist/current-token-preservation-reference-v2-workflow.js";
import * as io from "../dist/current-scoped-policy-inventory-archive-workflow-internal.js";
const capture=(f,request={kind:"publishReference",publication:f.publication})=>w.captureTokenPreservationReferenceV2(f.provider,f.d,f.caller,request,{blockTag:10});
const simulate=(f,value)=>w.simulateTokenPreservationReferenceV2(f.provider,value,{blockTag:11,gasLimit:90000000n});
const reconcile=(f,value,mined)=>w.reconcileTokenPreservationReferenceV2Receipt(f.provider,value,mined.txHash,mined.options);
const current=f=>w.inspectTokenPreservationReferenceV2Current(f.provider,f.d,f.scope,{blockTag:13});
const history=(f,key=f.head)=>w.inspectTokenPreservationReferenceV2History(f.provider,f.historyDeployment,key,{blockTag:13});
const request=(kind)=>kind==="prepareEnvironment"?{kind,environment:environment()}:{kind,rows:fileRows(kind==="prepareFileInventoryFromParts"?65:2),relative:true};
function replaceEvent(f,index,name,args){const event=f.host.encodeEventLog(f.host.getEvent(name),args);Object.assign(f.receipt.logs[index],event);}
const pubName=f=>f.d.scopeKind==="collection"?"PolicyReferencePublished":"ScopedPolicyReferencePublished";

for(const kind of ["prepareFileInventory","prepareFileInventoryPart","prepareFileInventoryFromParts","prepareEnvironment"]){
 test(`${kind}: both families and direct/legacy/indexed Safe receipts`,async()=>{
  for(const scopeKind of ["collection","scoped"])for(const transport of ["direct","legacy","indexed"]){
   const f=setup({scopeKind});const q=request(kind);f.preparation(q);const cap=await capture(f,q);const sim=await simulate(f,cap);assert.equal(sim.identity,cap.prepared.preparation.id);
   const result=await reconcile(f,cap,f.mine(cap,transport));assert.equal(result.result.kind,"preparation");assert.equal(result.result.receiptHadPreparationEvent,kind!=="prepareFileInventory");assert.equal(result.execution,transport==="direct"?"direct":"safe");
  }
 });
}
for(const scopeKind of ["collection","scoped"]){
 test(`${scopeKind} publish: preview, capture, original simulation and all three receipts`,async()=>{
  for(const transport of ["direct","legacy","indexed"]){const f=setup({scopeKind});const preview=await w.previewTokenPreservationReferenceV2(f.provider,f.d,f.caller,{...f.publication,observation:{...f.publication.observation,expectedSourcesHash:Z}},{blockTag:10});assert.equal(preview.storeAvailabilityChecked,false);assert.equal(preview.sourceHash,f.publication.observation.expectedSourcesHash);
   const cap=await capture(f);const sim=await simulate(f,cap);assert.equal(sim.persisted,false);assert.equal(sim.scope,"original-inner-call");const mined=f.mine(cap,transport),result=await reconcile(f,cap,mined);assert.equal(result.result.receipt.observation.recordHash,mined.item.receipt.observation.recordHash);assert.equal(result.finalityEstablished,false);assert.equal((await history(f)).currentnessChecked,false);assert.equal((await current(f)).currentnessChecked,true);
  }
 });
}

test("retained preparation retries bypass prerequisites but keep Store/helper pins",async()=>{
 for(const kind of ["prepareFileInventory","prepareFileInventoryPart","prepareFileInventoryFromParts","prepareEnvironment"]){const f=setup();const q=request(kind),plan=f.preparation(q);f.prepared.clear();f.prepared.set(plan.preparation.id,plan.preparation.canonical);const cap=await capture(f,q);assert.equal(cap.stage.retainedBefore,true);assert.deepEqual(cap.stage.prerequisites,[]);const mined=f.mine(cap,"indexed");assert.equal(mined.item,null);assert.equal((await reconcile(f,cap,mined)).result.receiptHadPreparationEvent,false);}
 const f=setup(),q=request("prepareEnvironment"),plan=f.preparation(q);f.prepared.set(plan.preparation.id,plan.preparation.canonical);f.codeHook=to=>to===f.pins.store.address?"0x":undefined;await assert.rejects(capture(f,q),/runtime/i);
});

test("both preuploaded streams are required only for publication capture",async()=>{
 for(const scopeKind of ["collection","scoped"]){const f=setup({scopeKind});for(const raw of [f.canonical,r.encodeTokenPreservationReferenceV2Publication(f.publication)])for(let offset=2;offset<raw.length;offset+=16384)f.base.store.delete(keccak256(`0x${raw.slice(offset,offset+16384)}`));const p=await w.previewTokenPreservationReferenceV2(f.provider,f.d,f.caller,f.publication,{blockTag:10});assert.equal(p.storeAvailabilityChecked,false);await assert.rejects(capture(f),/address|chunk/i);f.retain(p.canonical);await assert.rejects(capture(f),/address|chunk/i);f.retain(r.encodeTokenPreservationReferenceV2Publication(f.publication));assert.equal((await capture(f)).stage.kind,"publication");}
});

test("CURATOR3 precedes global8, and current/history keep recorded grant after revocation",async()=>{
 for(const global of [false,true]){const f=setup({global});if(!global)f.hook=call=>call.name==="familyWriter"&&call.args[1]===id("6529STREAM_RECORD_FAMILY_CURATOR_V1")&&call.args[2]===8n&&!f.revoked?[true,999n]:undefined;const cap=await capture(f);assert.equal(cap.stage.preview.receipt.observation.authorizationClass,global?8n:3n);f.mine(cap);f.revoked=true;assert.equal((await current(f)).receipt.observation.authorizationClass,global?8n:3n);assert.equal((await history(f)).receipt.observation.authorizationClass,global?8n:3n);await assert.rejects(w.previewTokenPreservationReferenceV2(f.provider,f.d,f.caller,{...f.publication,observation:{...f.publication.observation,expectedHead:f.head,expectedRevision:1n,referenceId:H(6600)}},{blockTag:13}),/CURATOR/);}
});

test("current fixity refresh preserves original receipt pair while new publication refuses stale coverage",async()=>{
 const f=setup(),cap=await capture(f);f.mine(cap);f.refreshed=true;const value=await current(f);assert.equal(value.source.environmentCoverage.firstFixityHash,f.source.environmentCoverage.firstFixityHash);assert.equal(value.coverage[0].currentPair.firstFixityHash,H(790));assert.ok(f.calls.some(c=>c.name==="currentReceiptPair"&&c.args[0]===f.coverages[0].firstReceiptHash));const q={...f.publication,observation:{...f.publication.observation,referenceId:H(6601),expectedHead:f.head,expectedRevision:1n}};await assert.rejects(w.previewTokenPreservationReferenceV2(f.provider,f.d,f.caller,q,{blockTag:13}),/coverage stale/);
 f.hook=call=>call.name==="currentReceiptPair"?[{...value.coverage[0].currentPair,firstReceiptHash:H(999)}]:undefined;await assert.rejects(current(f),/receipt pair identity/i);
});

test("first/last authoritative endpoints preserve burned identity and both admitted producer profiles",async()=>{
 for(const options of [{tokens:5,burned:true},{scopeType:1n,tokens:1,finalized:true},{scopeType:3n,tokens:2,notRequired:true}]){const f=setup(options),cap=await capture(f);assert.deepEqual(cap.stage.preview.source.samples.map(r=>r.membershipIndex),options.tokens===1?[0n]:[0n,BigInt(options.tokens-1)]);assert.equal(cap.stage.preview.source.samples[0].observation.seed,Z);if(options.tokens===2)assert.notEqual(cap.stage.preview.source.samples[0].preservation.profile,cap.stage.preview.source.samples[1].preservation.profile);f.mine(cap);assert.equal((await current(f)).currentnessChecked,true);}
 const f=setup({tokens:5});f.hook=call=>call.name==="scopeTokenAt"&&call.args[1]===4n?[f.token.rows[1].tokenId]:undefined;await assert.rejects(capture(f),/first\/last/);
});

test("sample admission/runtime/entropy and actual byte predicates stay bound to original rows",async()=>{
 for(const fault of ["binding","admission","entropy","html","serial"]){const f=setup();f.hook=call=>{if(fault==="binding"&&call.name==="preservationBinding")return[f.coords.core,f.pins.router.address,f.pins.renderer.address,f.pins.renderer.codeHash,A(999),f.pins.attribution.codeHash];if(fault==="admission"&&call.name==="requirePreservation"){const i=f.token.rows.findIndex(r=>r.selection.versionKey===call.args[0]),{metadataRouter,...rest}=f.token.bindings[i];return[{...rest,router:metadataRouter},{...f.token.admissions[i],goldenHash:H(999)}];}if(fault==="entropy"&&call.name==="tokenEntropyReadiness")return[{...f.token.entropies[0],seed:H(999)}];if(fault==="html"&&call.name==="preservationTokenHTML")return{raw:coder.encode(["bytes"],["0xff"])};if(fault==="serial"&&call.name==="tokenCollectionIdentity")return[true,f.scope.collectionId,999n,false];};await assert.rejects(capture(f),/differ|changed/);}
});

test("canonical producer bytes preserve invalid UTF8; original capped call remains decisive",async()=>{
 const f=setup({html:"0xff",json:"0xfe"});const cap=await capture(f);assert.equal(cap.stage.preview.source.samples[0].observation.htmlBytes,1n);const error=Object.assign(Error("original JSON byte-pattern rejected"),{code:"CALL_EXCEPTION",data:"0x1234"});f.hook=call=>{if(call.name==="publishReference")throw error;};await assert.rejects(simulate(f,cap),value=>value===error);const refused=await w.observeTokenPreservationReferenceV2Refusal(f.provider,cap,{blockTag:11,gasLimit:90000000n});assert.equal(refused.error,error);assert.equal(refused.rollbackProven,false);
});

test("seven complete RAW definitions include large schemas and reject first-version/chunk contradictions",async()=>{
 for(const scopeKind of ["collection","scoped"]){const f=setup({scopeKind}),cap=await capture(f);assert.equal(cap.stage.kind,"publication");const schema=f.docs[0];assert.ok(schema.byteLength>28000n);assert.ok(f.calls.filter(c=>c.name==="documentChunkHashAt"&&c.args[0]===schema.id).length>=4);}
 for(const field of ["supersedesId","declarationHash","chunkCount"]){const f=setup();f.hook=call=>{if(call.name==="documentFacts"&&call.args[0]===f.docs[0].id){const d=f.docs[0];return[{exists:true,status:0n,kind:d.kind,contentHash:d.hash,canonicalizationId:id("RAW_BYTES"),supersedesId:field==="supersedesId"?H(1):Z,totalBytes:d.byteLength,declarationHash:field==="declarationHash"?Z:H(2),chunkCount:field==="chunkCount"?0n:4n}];}};await assert.rejects(capture(f),/definition|bytes32/i);}
});

test("current/history allow legal gas raises while reviewed publication recapture refuses drift",async()=>{
 const f=setup(),cap=await capture(f);f.mine(cap);f.deps.readGas+=1n;f.deps.sourceGas+=1n;f.deps.snapshotGas+=1n;f.deps.archiveGas+=1n;assert.equal((await current(f)).receipt.observation.sourcesHash,cap.stage.preview.sourceHash);assert.equal((await history(f)).receipt.observation.sourcesHash,cap.stage.preview.sourceHash);await assert.rejects(simulate(f,cap),/reconstruction|changed/i);
});

test("history remains local after upstream retirement, authenticates predecessor and rejects rehashed scope contradictions",async()=>{
 for(const scopeKind of ["collection","scoped"]){const f=setup({scopeKind,scopeType:scopeKind==="collection"?0n:1n,tokens:1}),first=f.put();const p={...f.publication,observation:{...f.publication.observation,referenceId:H(6800),expectedHead:first.receipt.observation.recordHash,expectedRevision:1n}};const second=f.put(p,f.source,1013n,first.receipt.observation.recordChainHash);f.head=second.receipt.observation.recordHash;f.mined=true;f.codeHook=to=>[f.pins.snapshot.address,f.pins.router.address,f.pins.archive.address,f.pins.metadata.address,f.pins.core.address].includes(to)?"0x":undefined;const old=await history(f);assert.equal(old.receipt.observation.revision,2n);assert.equal(old.currentnessChecked,false);await assert.rejects(current(f),/runtime/);
  const altered=structuredClone(f.source);altered.snapshotSource.scope.collectionId+=1n;const bad=f.put(f.publication,altered);await assert.rejects(history(f,bad.receipt.observation.recordHash),/scope|source|snapshot/i);
 }
});

test("preparation, source and history helper pins are route-specific, and all writes recheck mined helper code",async()=>{
 for(const preparation of [true,false]){for(const pin of [preparation?"prepLink":"link",preparation?"reference":"source"]){const f=setup(),q=preparation?request("prepareFileInventoryPart"):{kind:"publishReference",publication:f.publication};if(preparation)f.preparation(q);const cap=await capture(f,q),mined=f.mine(cap);f.codeHook=(to,tag)=>tag===12&&to===f.pins[pin].address?"0x6000":undefined;await assert.rejects(reconcile(f,cap,mined),/runtime/);}}
 const f=setup(),row=f.put();f.head=row.receipt.observation.recordHash;f.codeHook=to=>to===f.pins.referenceHistory.address?"0x":undefined;await assert.rejects(history(f),/runtime/);
 const g=setup(),q=request("prepareFileInventory"),plan=g.preparation(q);g.prepared.set(plan.preparation.id,plan.preparation.canonical);g.codeHook=to=>[g.pins.metadata.address,g.pins.archive.address,g.pins.snapshot.address].includes(to)?"0x":undefined;assert.equal((await capture(g,q)).stage.retainedBefore,true);
});

test("receipt event identity/order, Store silence, end head and same-block progress are conservative",async()=>{
 for(const fault of ["missing","duplicate","schema","store","head","earlier"]){const f=setup(),cap=await capture(f),mined=f.mine(cap,"indexed");if(fault==="missing")f.receipt.logs.shift();if(fault==="duplicate")f.receipt.logs.splice(1,0,{...f.receipt.logs[0],index:1});if(fault==="schema")replaceEvent(f,0,pubName(f),[1n,mined.item.receipt.scopeSubject,f.publication.observation.referenceId,mined.item.receipt.observation.recordHash,mined.item.receipt,""]);if(fault==="store")f.receipt.logs.push({...f.receipt.logs[0],address:f.pins.store.address,index:2});if(fault==="head")f.hook=call=>call.name==="currentReference"&&call.blockTag===12?[{...mined.item.receipt,observation:{...mined.item.receipt.observation,recordHash:H(999)}}]:undefined;if(fault==="earlier")f.hook=call=>call.name==="referenceCount"&&call.blockTag===11?[1n]:undefined;await assert.rejects(reconcile(f,cap,mined));}
 const f=setup(),cap=await capture(f),mined=f.mine(cap,"legacy");f.receipt.logs[0].index=2;await assert.rejects(reconcile(f,cap,mined),/Safe|index|order/i);
});

test("direct and Safe envelopes require exact caller/value/calldata, independent hash, complete copied metadata",async()=>{
 for(const fault of ["sender","value","target","hash","missingMetadata","removed","failure","calldata"]){const f=setup(),q=request("prepareFileInventory"),plan=f.preparation(q),cap=await capture(f,q),mined=f.mine(cap,fault==="sender"||fault==="target"?"direct":"indexed");if(fault==="sender")f.transaction.from=A(99);if(fault==="target")f.transaction.to=A(99);if(fault==="value")f.transaction.value=1n;if(fault==="hash")mined.options.expectedSafeTxHash=H(999);if(fault==="missingMetadata")delete f.receipt.logs[0].transactionHash;if(fault==="removed")f.receipt.logs[0].removed=true;if(fault==="failure")Object.assign(f.receipt.logs[0],safe.encodeEventLog("ExecutionFailure",[H(901),0n]));if(fault==="calldata")f.transaction.data=safe.encodeFunctionData("execTransaction",[f.pins.reference.address,0n,plan.call.data,1,0,0,0,ZA,ZA,"0x"]);await assert.rejects(reconcile(f,cap,mined));}
});

test("caller inputs and receipt logs are detached before the first provider await",async()=>{
 const f=setup(),q=request("prepareFileInventoryPart"),plan=f.preparation(q),d=structuredClone(f.d),requestCopy=structuredClone(q),opts={blockTag:10};f.networkHook=()=>{d.reference.codeHash=H(999);requestCopy.rows[0].path="mutated";opts.blockTag=99;};const cap=await w.captureTokenPreservationReferenceV2(f.provider,d,f.caller,requestCopy,opts);assert.equal(cap.observed.blockNumber,10);assert.equal(cap.prepared.call.data,plan.call.data);f.networkHook=null;const mined=f.mine(cap,"indexed");const originalBlock=f.provider.getBlock;f.provider.getBlock=async tag=>{f.receipt.logs[0].data="0x";return originalBlock(tag);};assert.equal((await reconcile(f,cap,mined)).result.identity,plan.preparation.id);
});

test("saved call substitution, reorg, malformed canonical RPC and explicit resource bounds refuse",async()=>{
 const f=setup(),q=request("prepareFileInventory"),plan=f.preparation(q),cap=await capture(f,q);const tampered=structuredClone(cap);tampered.prepared.call.data="0x12345678";const{captureHash,...body}=tampered;tampered.captureHash=io.fingerprint(body);await assert.rejects(simulate(f,tampered),/reconstruction|differs/);const original=f.provider.getBlock;f.provider.getBlock=async tag=>({...await original(tag),hash:H(999)});await assert.rejects(simulate(f,cap),/block/i);f.provider.getBlock=original;f.hook=call=>call.name==="dependencies"?{raw:f.host.encodeFunctionResult("dependencies",[f.deps])+"00".repeat(32)}:undefined;await assert.rejects(capture(f,q),/canonical/);f.hook=null;const mined=f.mine(cap);f.transaction.data="0x"+"00".repeat(io.MAX_CALL+16385);await assert.rejects(reconcile(f,cap,mined),/oversized/);await assert.rejects(w.captureTokenPreservationReferenceV2(f.provider,{...f.d,linkedDependencies:{...f.d.linkedDependencies,source:Array.from({length:257},()=>f.pins.link)}},f.caller,q,{blockTag:10}),/limit/);
});

test("refusal preserves exact execution and RPC errors and only reports observed retained-state equality",async()=>{
 const f=setup(),q=request("prepareFileInventory"),plan=f.preparation(q),cap=await capture(f,q);for(const execution of [true,false]){const error=Object.assign(Error(execution?"original failure":"RPC unavailable"),{code:execution?"CALL_EXCEPTION":"NETWORK_ERROR"});f.hook=call=>{if(call.name==="prepareFileInventory")throw error;};const out=await w.observeTokenPreservationReferenceV2Refusal(f.provider,cap,{blockTag:11,gasLimit:1000000n});assert.equal(out.error,error);assert.equal(out.outcome,execution?"execution-reverted":"rpc-failed");assert.equal(out.retainedStateUnchanged,true);assert.equal(out.rollbackProven,false);}f.hook=null;await assert.rejects(w.observeTokenPreservationReferenceV2Refusal(f.provider,cap,{blockTag:11,gasLimit:1000000n}),/did not refuse/);
});

test("publication uses an intact optional environment cache, or requires both original inventories",async()=>{
 for(const scopeKind of ["collection","scoped"]){const f=setup({scopeKind,cachedEnvironment:true});const environmentEntry=[...f.prepared].find(([,raw])=>keccak256(raw)===f.publication.observation.environment.manifestHash);assert.ok(environmentEntry);f.prepared.clear();f.prepared.set(...environmentEntry);assert.equal((await capture(f)).stage.kind,"publication");const g=setup({scopeKind});g.prepared.clear();await assert.rejects(capture(g),/inventories unavailable/);await assert.rejects(current(g),/No current reference/);}
});
