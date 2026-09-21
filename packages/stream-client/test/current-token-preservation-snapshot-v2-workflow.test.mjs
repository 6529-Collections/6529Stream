import test from "node:test";
import assert from "node:assert/strict";
import { id, keccak256 } from "ethers";
import * as w from "../dist/current-token-preservation-snapshot-v2-workflow.js";
import * as p from "../dist/current-token-preservation-snapshot-v2.js";
import { setup, A, H, Z, ZA, coder, safe } from "./current-token-preservation-snapshot-v2-workflow-fixture.mjs";
const capture=f=>w.captureTokenPreservationSnapshotV2(f.provider,f.d,f.caller,{kind:"publishSnapshot",publication:f.publication},{blockTag:10,gasLimit:50000000n});
const reconcile=(f,c,m)=>w.reconcileTokenPreservationSnapshotV2Receipt(f.provider,c,m.txHash,m.options);
const historical=(f,key,tag=12)=>w.inspectTokenPreservationSnapshotV2History(f.provider,f.d,key,{blockTag:tag});
const current=(f,tag=12)=>w.inspectTokenPreservationSnapshotV2Current(f.provider,f.d,f.scope,{blockTag:tag});
const failure=()=>Object.assign(Error("Original source call reverted"),{code:"CALL_EXCEPTION",data:"0x1234"});

test("both snapshot families publish through direct and both original Safe receipt layouts",async()=>{
  for(const scopeKind of ["collection","scoped"])for(const transport of ["direct","legacy","indexed"]){
    const f=setup({scopeKind});const c=await capture(f);const checked=await w.simulateTokenPreservationSnapshotV2(f.provider,c,{blockTag:11});
    assert.equal(checked.persisted,false);assert.ok(f.calls.some(q=>q.name==="publishSnapshot"&&q.from===f.caller&&q.gasLimit===50000000n));
    const m=f.mine(c,transport);const result=await reconcile(f,c,m);assert.deepEqual(result.receipt,m.item.receipt);
    assert.equal(result.finalityEstablished,false);assert.equal(result.receiptAttribution,"unchanged-preceding-block-and-exact-end-block");
    const h=await historical(f,m.item.receipt.recordHash);assert.equal(h.immutableHistoryAuthenticated,true);
    assert.equal((await current(f)).exists,true);
  }
});

test("all closed scopes preserve covered mixed producer rows and independent grant precedence",async()=>{
  for(const [scopeKind,scopeType]of [["collection",0n],["scoped",1n],["scoped",2n],["scoped",3n]]){
    const f=setup({scopeKind,scopeType,snapshotClass:8n,displayClass:7n,burned:true});const c=await capture(f);
    assert.equal(c.stage.receipt.authorizationClass,8n);assert.equal(c.stage.receipt.displayAuthorizationClass,7n);
    assert.equal(c.stage.source.outputs.outputRoot,f.base.manifest.outputRoot);
    const grants=f.calls.filter(q=>q.name==="familyWriter");assert.equal(grants.length,3);
    assert.deepEqual(grants.map(q=>[q.args[0],q.args[2]]),[[9n,7n],[0n,8n],[9n,7n]]);
    assert.ok(!f.calls.some(q=>q.name==="ownerOf"||q.name==="selectionAt"));
    const m=f.mine(c);await reconcile(f,c,m);
  }
});

test("preview ignores caller expected hash and chunk availability; publication requires both",async()=>{
  for(const scopeKind of ["collection","scoped"]){const f=setup({scopeKind});const bad={...f.publication,expectedSourceHash:H(999)};
    f.carriers.forEach(x=>f.store.delete(x.hash));
    const preview=await w.previewTokenPreservationSnapshotV2(f.provider,f.d,bad,f.caller,{blockTag:10});
    assert.equal(preview.storeAvailabilityChecked,false);assert.equal(preview.readyPublication.expectedSourceHash,f.publication.expectedSourceHash);
    assert.ok(!f.calls.some(q=>q.name==="chunk"));
    await assert.rejects(()=>capture(f),/address|uploaded/);
    f.refresh();await assert.rejects(()=>w.captureTokenPreservationSnapshotV2(f.provider,f.d,f.caller,{kind:"publishSnapshot",publication:bad},{blockTag:10,gasLimit:50000000n}),/source differs/);
    await capture(f);
  }
});

test("definition reads authenticate all original chunks including the 15067-byte collection schema",async()=>{
  const f=setup({scopeKind:"collection"});const c=await capture(f);assert.equal(c.stage.definitions.length,5);
  assert.ok(f.docs.some(d=>d.byteLength===15067n));assert.ok(f.calls.filter(q=>q.name==="documentChunkHashAt").length>5);
  for(const fault of ["retired","hash","chunkCount","bytes"]){const n=setup({scopeKind:"collection"});
    n.hook=q=>{if(q.name==="documentFacts"){const d=n.docs.find(d=>d.id===q.args[0]);return[{exists:true,status:fault==="retired"?1n:0n,kind:d.kind,contentHash:fault==="hash"?H(998):d.hash,canonicalizationId:id("RAW_BYTES"),supersedesId:Z,totalBytes:d.byteLength,declarationHash:H(560),chunkCount:fault==="chunkCount"?65n:BigInt(n.documentChunks.get(d.id).length)}];}
      if(fault==="bytes"&&q.name==="readChunk")return["0x1234"];};
    await assert.rejects(()=>capture(n),/definition|Definition/);
  }
});

test("both grants are mandatory and class7 wins independently when both classes are available",async()=>{
  for(const family of [id("6529STREAM_RECORD_FAMILY_SNAPSHOT_V1"),id("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1")]){
    const f=setup();f.hook=q=>q.name==="familyWriter"&&q.args[1]===family?[false,0n]:undefined;
    await assert.rejects(()=>capture(f),/independent.*grant/);
  }
  const f=setup({snapshotClass:7n,displayClass:7n});f.hook=q=>q.name==="familyWriter"?[true,q.args[1]===id("6529STREAM_RECORD_FAMILY_SNAPSHOT_V1")?3n:4n]:undefined;
  const c=await capture(f);assert.equal(c.stage.receipt.authorizationClass,7n);assert.equal(c.stage.receipt.displayAuthorizationClass,7n);
  assert.equal(f.calls.filter(q=>q.name==="familyWriter").length,2);
});

test("current eligibility retains recorded grants and lock while local history survives upstream retirement",async()=>{
  for(const scopeKind of ["collection","scoped"]){const f=setup({scopeKind});const c=await capture(f);const m=f.mine(c);f.revoked=true;f.lock={recordHash:f.head,revision:1n,actionId:H(998),lockedAt:1013n};f.calls.length=0;
    const inspected=await current(f);assert.equal(inspected.publisherReauthorized,false);assert.ok(!f.calls.some(q=>q.name==="familyWriter"));
    const keep=new Set([f.pins.snapshot.address,f.pins.historyLink.address,...m.item.carriers.map(x=>x.pointer)]);
    f.codeHook=to=>keep.has(to)?undefined:"0x";f.calls.length=0;
    const h=await historical(f,f.head);assert.equal(h.currentEligibilityChecked,false);assert.ok(!f.calls.some(q=>q.name==="requireCurrentManifest"||q.name==="familyWriter"));
    await assert.rejects(()=>current(f),/runtime/);
    f.codeHook=to=>to===f.pins.historyLink.address?"0x":undefined;await assert.rejects(()=>historical(f,f.head),/runtime/);
  }
});

test("current source diagnostics refuse changed output or policies without rewriting retained history",async()=>{
  for(const fault of ["output","policy","route"]){const f=setup();const c=await capture(f);const m=f.mine(c);
    f.hook=q=>{if(fault==="output"&&q.name==="requireCurrentManifest")return[{...f.source.outputs,outputRoot:H(996)}];if(fault==="policy"&&q.name==="sourcePolicyAt")return[{...f.source.entropy.policies[0],frozen:false}];if(fault==="route"&&q.name==="requireCurrentRoute")return[{componentType:id("ENTROPY_COORDINATOR"),component:A(999),interfaceId:"0x8004d4f5",codeHash:H(996)}];};
    await assert.rejects(()=>current(f),/root|frozen|route/i);assert.equal((await historical(f,m.item.receipt.recordHash)).receipt.recordHash,m.item.receipt.recordHash);
  }
});

test("closed full scopes, lineage, lock and inclusive effective time are authenticated before publication",async()=>{
  for(const fault of ["time","head","revision","lock"]){const f=setup();if(fault==="time")f.publication.effectiveAt=1011n;if(fault==="head")f.publication.expectedHead=H(995);if(fault==="revision")f.publication.expectedRevision=1n;if(fault==="lock")f.lock.actionId=H(996);
    await assert.rejects(()=>capture(f),/lineage|time|locked|head|predecessor/i);
  }
  const f=setup();f.publication.effectiveAt=1010n;f.refresh();await capture(f);
  const bad={...f.publication,scope:{...f.scope,scopeType:4n}};await assert.rejects(()=>w.previewTokenPreservationSnapshotV2(f.provider,f.d,bad,f.caller,{blockTag:10}),/scope|profile/i);
  const empty=setup();const result=await current(empty,10);assert.equal(result.exists,false);assert.equal(result.current,null);
});

test("current Metadata/Router selection, reciprocal pins and original producer capabilities are enforced",async()=>{
  for(const fault of ["selected","eligibility","reciprocal","capability","profile","factory"]){const f=setup();
    f.hook=q=>{if(fault==="selected"&&q.name==="getSatellitePointer"&&q.args[0]===id("COLLECTION_METADATA"))return[A(888),f.pins.metadata.codeHash,false,id("COLLECTION_METADATA"),"0x7e8260f8",f.pins.moduleRegistry.address,1n,H(1),H(2),1n];if(fault==="eligibility"&&q.name==="isModuleEligible")return[false];if(fault==="reciprocal"&&q.to===f.pins.selection.address&&q.name==="metadataRouter")return[A(888)];if(fault==="capability"&&q.to===f.pins.source.address&&q.name==="supportsInterface")return[false];if(fault==="profile"&&q.name==="preservationOutputProfile")return[H(888)];if(fault==="factory"&&q.name==="sourceSetForPlan")return[A(888),H(888)];};
    await assert.rejects(()=>capture(f),/selection|ineligible|dependency|capability|family|registration/i);
  }
});

test("collection root record and binding are required; scoped sources never query a collection root",async()=>{
  for(const fault of ["head","binding","record"]){const f=setup({scopeKind:"collection"});f.hook=q=>{
    if(fault==="head"&&q.name==="collectionContentRootHead")return[H(998)];
    if(fault==="binding"&&q.name==="preservationPolicyContentRootBinding")return[{...f.source.rootBinding,outputRoot:H(998)}];
    if(fault==="record"&&q.name==="contentRootRecord")return[{...f.source.root,artistConsent:Z}];};
    await assert.rejects(()=>capture(f),/root|binding|zero/i);
  }
  const f=setup();await capture(f);assert.ok(!f.calls.some(q=>q.name==="collectionContentRootHead"||q.name==="contentRootRecord"));
});

test("original preview remains authoritative for nested source and publisher admission",async()=>{
  const f=setup();const error=failure();f.hook=q=>{if(q.name==="previewSnapshot")throw error;};
  await assert.rejects(()=>capture(f),e=>e===error);
  f.hook=q=>q.name==="previewSnapshot"?[H(998),f.canonical]:undefined;
  await assert.rejects(()=>capture(f),/preview/);
});

test("receipt event identity/order and exact mined state reject omitted, extra and contradictory evidence",async()=>{
  for(const fault of ["missing","duplicate","schema","store","head","payload"]){const f=setup();const c=await capture(f);const m=f.mine(c,"legacy");
    if(fault==="missing")f.receipt.logs.shift();
    if(fault==="duplicate"){f.receipt.logs.splice(1,0,{...f.receipt.logs[0]});f.receipt.logs.forEach((r,i)=>r.index=i);}
    if(fault==="schema"){const r=m.item;const e=f.host.encodeEventLog(f.host.getEvent("ScopedPolicySnapshotPublished"),[1n,r.receipt.scopeSubject,r.publication.snapshotId,r.receipt.recordHash,r.publication,r.receipt]);Object.assign(f.receipt.logs[0],e);}
    if(fault==="store")f.receipt.logs[0].address=f.pins.store.address;
    if(fault==="head")f.hook=q=>q.blockTag===12&&q.name==="currentSnapshot"?[{...m.item.receipt,recordHash:H(999)}]:undefined;
    if(fault==="payload")f.hook=q=>q.blockTag===12&&q.name==="snapshotPayload"?[`${m.item.canonical}00`]:undefined;
    await assert.rejects(()=>reconcile(f,c,m),/exactly one|Published|snapshot|Snapshot|payload|canonical|head/i);
  }
});

test("both Safe layouts require exact hash, success, CALL operation, original caller/value/data and event order",async()=>{
  for(const transport of ["legacy","indexed"])for(const fault of ["hash","failure","operation","value","order"]){const f=setup();const c=await capture(f);const m=f.mine(c,transport);
    if(fault==="hash")m.options.expectedSafeTxHash=H(888);
    if(fault==="failure"){const e=safe.encodeEventLog(safe.getEvent("ExecutionFailure"),[H(901),0n]);Object.assign(f.receipt.logs[1],e);}
    if(fault==="operation"||fault==="value")f.transaction.data=safe.encodeFunctionData("execTransaction",[f.pins.snapshot.address,fault==="value"?1n:0n,c.prepared.call.data,fault==="operation"?1:0,0,0,0,ZA,ZA,"0x12"]);
    if(fault==="order"){f.receipt.logs.reverse();f.receipt.logs.forEach((r,i)=>r.index=i);}
    await assert.rejects(()=>reconcile(f,c,m));
  }
});

test("mined runtime checks include all source targets, dynamic factory and both reviewed link rosters",async()=>{
  for(const target of ["snapshot","source","factory","moduleRegistry","link","historyLink"]){const f=setup();const c=await capture(f);const m=f.mine(c);f.codeHook=(to,tag)=>tag===12&&to===f.pins[target].address?"0x6001":undefined;
    await assert.rejects(()=>reconcile(f,c,m),/runtime/);
  }
});

test("receipt envelope metadata and caller-owned inputs are copied before asynchronous reads",async()=>{
  const f=setup();const dep=structuredClone(f.d),request={kind:"publishSnapshot",publication:structuredClone(f.publication)},options={blockTag:10,gasLimit:50000000n};
  f.networkHook=()=>{dep.snapshot.address=A(999);request.publication.reasonHash=H(999);options.blockTag=11;};
  const c=await w.captureTokenPreservationSnapshotV2(f.provider,dep,f.caller,request,options);assert.equal(c.observed.blockNumber,10);assert.equal(c.prepared.request.publication.reasonHash,f.publication.reasonHash);f.networkHook=null;
  const m=f.mine(c);const getTransaction=f.provider.getTransaction;f.provider.getTransaction=async()=>{f.receipt.logs[0].data="0x";return getTransaction();};await reconcile(f,c,m);
  for(const fault of ["removed","hash","index","endpoint"]){const n=setup();const cap=await capture(n);const mine=n.mine(cap);if(fault==="removed")n.receipt.logs[0].removed=true;if(fault==="hash")delete n.receipt.logs[0].blockHash;if(fault==="index")n.receipt.logs[0].index=NaN;if(fault==="endpoint")n.receipt.from=A(888);await assert.rejects(()=>reconcile(n,cap,mine));}
});

test("saved block reorg and prior/end-block conflicts require recapture",async()=>{
  const f=setup();const c=await capture(f);const original=f.provider.getBlock;f.provider.getBlock=async tag=>({...await original(tag),hash:tag===10?H(888):H(10000+tag)});
  await assert.rejects(()=>w.simulateTokenPreservationSnapshotV2(f.provider,c,{blockTag:11}),/block changed/);
  const n=setup();const cap=await capture(n);const m=n.mine(cap);n.hook=q=>q.blockTag===11&&q.name==="familyWriter"?[true,9n]:undefined;await assert.rejects(()=>reconcile(n,cap,m),/preview|changed/);
  const end=setup();const ec=await capture(end);const em=end.mine(ec);end.hook=q=>q.blockTag===12&&q.name==="snapshotCount"?[2n]:undefined;await assert.rejects(()=>reconcile(end,ec,em),/count/);
});

test("fully rehashed TOKEN history still joins all source scopes to the stored publication",async()=>{
  const f=setup({scopeType:1n});const c=await capture(f);const m=f.mine(c);const forged=structuredClone(f.source);forged.scope.collectionId=99n;
  const bad=f.put(f.publication,forged);assert.notEqual(bad.receipt.recordHash,m.item.receipt.recordHash);
  await assert.rejects(()=>historical(f,bad.receipt.recordHash),/Full source scope/);
  const contradictory=f.put({...f.publication,expectedHead:m.item.receipt.recordHash,expectedRevision:1n},f.source,1013n,m.item.receipt.chainHash);
  await historical(f,contradictory.receipt.recordHash);
  f.records.set(m.item.receipt.recordHash,{...m.item,publication:{...m.item.publication,scope:{...f.scope,collectionId:99n}}});
  await assert.rejects(()=>historical(f,contradictory.receipt.recordHash),/predecessor full scope/);
});

test("refusal preserves the original RPC error and qualifies only observed retained-state equality",async()=>{
  for(const code of ["CALL_EXCEPTION","NETWORK_ERROR"]){const f=setup();const c=await capture(f);const error=Object.assign(Error("refused"),{code});f.hook=q=>{if(q.blockTag===11&&q.name==="publishSnapshot")throw error;};
    const r=await w.observeTokenPreservationSnapshotV2Refusal(f.provider,c,{blockTag:11});assert.equal(r.error,error);assert.equal(r.outcome,code==="CALL_EXCEPTION"?"execution-reverted":"rpc-failed");assert.equal(r.nativeRollbackProven,false);
  }
  const f=setup();const c=await capture(f);assert.equal((await w.observeTokenPreservationSnapshotV2Refusal(f.provider,c,{blockTag:11})).outcome,"succeeded");
});

test("governed gas raises preserve current/history hashes while saved publication needs recapture",async()=>{
  const f=setup();const cap=await capture(f);const m=f.mine(cap);
  f.hook=q=>q.name==="dependencies"&&q.to===f.pins.snapshot.address&&q.blockTag>=11?[{...f.deps,readGas:f.deps.readGas+1n,sourceGas:f.deps.sourceGas+1n,inventoryGas:f.deps.inventoryGas+1n}]:undefined;
  assert.equal((await current(f)).current.receipt.sourceHash,cap.stage.sourceHash);
  assert.equal((await historical(f,m.item.receipt.recordHash)).receipt.manifestHash,m.item.receipt.manifestHash);
  await assert.rejects(()=>w.simulateTokenPreservationSnapshotV2(f.provider,cap,{blockTag:11}),/changed/);
});

test("fresh publication refuses revoked grants while retained current does not reauthorize",async()=>{
  const f=setup();const cap=await capture(f);const m=f.mine(cap);f.revoked=true;
  const next={...f.publication,snapshotId:H(999),expectedHead:m.item.receipt.recordHash,expectedRevision:1n};
  await assert.rejects(()=>w.previewTokenPreservationSnapshotV2(f.provider,f.d,next,f.caller,{blockTag:12}),/grant/);
  assert.equal((await current(f)).exists,true);
});

test("Store STOP integrity, source policy/resource bounds and unsupported delegation runtime are refused",async()=>{
  for(const fault of ["prefix","length"]){const f=setup();if(fault==="prefix")f.code.set(f.carriers[0].pointer,`0x01${f.carriers[0].data.slice(2)}`);else f.store.set(f.carriers[0].hash,{...f.carriers[0],length:1n});await assert.rejects(()=>capture(f),/carrier|uploaded/);}
  const f=setup();f.hook=q=>q.name==="sourceCount"?[631n]:undefined;await assert.rejects(()=>capture(f),/policy count/);
  const gas=setup();gas.hook=q=>q.name==="dependencies"&&q.to===gas.pins.snapshot.address?[{...gas.deps,inventoryGas:1n<<32n}]:undefined;await assert.rejects(()=>capture(gas),/gas bounds/);
  const delegation=setup();const marker=`0xef0100${A(999).slice(2)}`;delegation.code.set(delegation.pins.snapshot.address,marker);delegation.d.snapshot.codeHash=keccak256(marker);await assert.rejects(()=>capture(delegation),/runtime/);
});

test("concrete block options stay detached and receipt must be later with bounded outer calldata",async()=>{
  const f=setup();const cap=await capture(f);const m=f.mine(cap);const options={blockTag:12};f.networkHook=()=>{options.blockTag=13;};f.calls.length=0;
  await w.inspectTokenPreservationSnapshotV2History(f.provider,f.d,m.item.receipt.recordHash,options);assert.ok(f.calls.every(q=>q.blockTag===12));f.networkHook=null;
  const huge=setup();const hc=await capture(huge);const hm=huge.mine(hc,"legacy");huge.transaction.data=`0x${"00".repeat(2097152+16384+1)}`;await assert.rejects(()=>reconcile(huge,hc,hm),/oversized/);
  const early=setup();const ec=await capture(early);const em=early.mine(ec);for(const obj of [early.receipt,early.transaction,...early.receipt.logs]){obj.blockNumber=10;obj.blockHash=H(10010);}await assert.rejects(()=>reconcile(early,ec,em),/follow captured/);
});
