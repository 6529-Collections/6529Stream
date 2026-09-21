import test from "node:test";
import assert from "node:assert/strict";
import { Interface,ZeroAddress as Z,ZeroHash as H0,keccak256 } from "ethers";
import { setup,A,H,pin,code,safe,c,pure,w,coder } from "./current-view-complete-binding-workflow-fixture.mjs";
const capture=f=>w.captureViewCompleteBinding(f.provider,f.deployment,f.caller,f.state.kind,f.batch,{blockTag:10,gasLimit:50000000n});
const receipt=async(f,mode="direct")=>{const saved=await capture(f),tx=f.transaction(mode);return {saved,tx,result:await w.reconcileViewCompleteBindingReceipt(f.provider,saved,tx.txHash,tx.options)};};

test("all three genuine Executor stages simulate and reconcile direct and both Safe layouts",async()=>{
  for(const kind of ["publishGovernanceCallData","scheduleGovernanceBatch","executeGovernanceBatch"])for(const mode of ["direct","legacy","indexed"]){
    const f=await setup({kind,published:kind!=="publishGovernanceCallData"});const saved=await capture(f);
    const simulated=await w.simulateViewCompleteBinding(f.provider,saved,{blockTag:11});assert.equal(simulated.originalCallSimulated,true);
    const tx=f.transaction(mode),r=await w.reconcileViewCompleteBindingReceipt(f.provider,saved,tx.txHash,tx.options);
    assert.equal(r.kind,kind);assert.equal(r.finalityChecked,false);assert.equal(r.history!==null,kind==="executeGovernanceBatch");
  }
});
test("pre-bind discovery derives recipe source factory and supports both genuine factory domains",async()=>{
  for(const legacyFactory of [false,true]){const f=await setup({legacyFactory});assert.equal(f.preview.transition.newValueHash,pure.viewCompleteBindingProposalHash(f.basic,f.complete));assert.ok(f.state.calls.some(x=>x.method==="recipe"));assert.ok(!f.state.calls.some(x=>x.method==="viewPolicySourceFactoryV2"));}
});
test("source proposal is authentic, pending receipt is empty, and basic or complete binding consumes guard",async()=>{
  for(const which of ["bound","basicOnly"]){const f=await setup();f.state[which]=true;await assert.rejects(capture(f),/consumed/);}
  const f=await setup();f.state.hooks.result=({method,values})=>method==="completeViewPreservationBindingTransition"?[{...values[0],newValueHash:H(77)}]:undefined;await assert.rejects(capture(f),/transition differs/);
  const g=await setup();g.state.hooks.result=({method,values})=>method==="viewPreservationBindingReceipt"?[{...values[0],boundAt:1n}]:undefined;await assert.rejects(capture(g),/not empty/);
});
test("constructor authority, factory recipe and original roster contradictions reject",async()=>{
  for(const mutate of [f=>{f.capability.authority=A(999);},f=>{f.recipe.targets[2]=A(999);},f=>{f.anchor.artistTargets[0]=A(999);},f=>{f.inv.targets[0]=A(999);},f=>{f.snapshot.targets[9]=A(999);},f=>{f.ref.targets[5]=A(999);}]){const f=await setup();mutate(f);await assert.rejects(capture(f));}
});
test("owner can schedule without proposer membership, outsider cannot, execute never reads finality ADMIN",async()=>{
  const owner=await setup({caller:A(31)});owner.state.isProposer=false;assert.equal((await capture(owner)).governance.usesRootCapacity,true);
  const outsider=await setup();outsider.state.isProposer=false;await assert.rejects(capture(outsider),/proposer authority/);
  const execute=await setup({kind:"executeGovernanceBatch"});execute.state.isProposer=false;execute.state.hooks.call=({method})=>{if(method==="hasRole")throw Error("No finality role allowed");};await receipt(execute);
});
test("sealed ordinary governance, nonce, catalog and exact scheduled calls are bound",async()=>{
  for(const mutate of [f=>{f.state.sealed=false;},f=>{f.state.catalog[2]=0n;},f=>{f.state.hooks.result=({method,values})=>method==="governanceNonce"?[99n]:undefined;},f=>{f.state.published=false;}]){const f=await setup();mutate(f);await assert.rejects(capture(f));}
  const f=await setup({kind:"executeGovernanceBatch"});f.state.hooks.result=({method,values})=>method==="scheduledCallData"?[["0x"]]:undefined;await assert.rejects(capture(f),/calldata differs/);
});
test("target scope governs guardians rather than aggregate batch scope",async()=>{
  const f=await setup();assert.notEqual(f.batch.scopeHash,f.batch.transition.scopeHash);const saved=await capture(f);assert.equal(saved.governance.guardian.targetScope,f.batch.transition.scopeHash);
  const g=await setup({kind:"executeGovernanceBatch"});g.state.hooks.result=({method,values})=>method==="terminalFreezeGuardianConfigCommitment"?[H(123)]:undefined;await assert.rejects(capture(g),/guardian configuration/);
});
test("publication retries are eventless only with prior retained exact STOP calldata",async()=>{
  const f=await setup({kind:"publishGovernanceCallData",published:true});const r=await receipt(f);assert.equal(f.state.receipt.logs.length,0);assert.equal(r.result.history,null);
  const g=await setup({kind:"publishGovernanceCallData",published:false});const saved=await capture(g),tx=g.transaction();g.state.receipt.logs=[];await assert.rejects(w.reconcileViewCompleteBindingReceipt(g.provider,saved,tx.txHash,tx.options),/event count/);
  const h=await setup({kind:"scheduleGovernanceBatch"});h.state.hooks.code=(target)=>target===h.carrier?"0x006000":undefined;await assert.rejects(capture(h),/carrier differs/);
});
test("complete execution emits one CompleteBound and never a basic Bound event",async()=>{
  for(const fault of ["missing","duplicate","basic","hash","order"]){const f=await setup({kind:"executeGovernanceBatch"}),saved=await capture(f),tx=f.transaction();const logs=f.state.receipt.logs,index=logs.findIndex(l=>l.address===A(40));
    if(fault==="missing")logs.splice(index,1);if(fault==="duplicate")logs.splice(index,0,structuredClone(logs[index]));
    if(fault==="basic"){const i=c.StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1,e=i.encodeEventLog(i.getEvent("ViewPreservationBound"),[H(1),f.batch.actionId,A(301),H(2),H(3)]);logs.splice(index,0,{address:A(40),...e});}
    if(fault==="hash")logs[index].topics[1]=H(44);if(fault==="order")[logs[index],logs[index+1]]=[logs[index+1],logs[index]];
    f.reindex();await assert.rejects(w.reconcileViewCompleteBindingReceipt(f.provider,saved,tx.txHash,tx.options));
  }
});
test("paired mined receipts join action/time/dependency hashes even with canonical RPC responses",async()=>{
  for(const field of ["actionId","boundAt","basicBindingRecordHash","referenceDependenciesHash"]){const f=await setup({kind:"executeGovernanceBatch"}),saved=await capture(f),tx=f.transaction();f.state.hooks.result=({method,tag,values})=>method==="viewFinalitySourcesReceipt"&&tag===12?[{...values[0],[field]:field==="boundAt"?1n:H(22)}]:undefined;await assert.rejects(w.reconcileViewCompleteBindingReceipt(f.provider,saved,tx.txHash,tx.options));}
});
test("immutable history remains readable after sources and governance retire, while local worker must remain",async()=>{
  const f=await setup({kind:"executeGovernanceBatch"});await receipt(f);for(const a of [A(10),A(11),A(301),A(304),A(305),A(306),A(500)])f.state.missingCode.add(a);
  const h=await w.inspectViewCompleteBindingHistory(f.provider,f.historyDeployment,{blockTag:13});assert.equal(h.currentSourceAdmissionChecked,false);
  await assert.rejects(w.inspectViewCompleteBindingCurrent(f.provider,f.deployment,{blockTag:13,gasLimit:50000000n}));
  f.state.missingCode.add(f.deployment.bindingWorker.address);await assert.rejects(w.inspectViewCompleteBindingHistory(f.provider,f.historyDeployment,{blockTag:13}),/runtime/);
});
test("operative selection permits governed reference gas drift without rewriting initial hashes",async()=>{
  const f=await setup({kind:"executeGovernanceBatch"});await receipt(f);const old=f.complete.referenceDependenciesHash;f.ref.sourceGas=20000000n;f.ref.snapshotGas=21000000n;
  const current=await w.inspectViewCompleteBindingCurrent(f.provider,f.deployment,{blockTag:13,gasLimit:50000000n});assert.equal(current.history.complete.referenceDependenciesHash,old);assert.equal(current.dependencies.reference.sourceGas,20000000n);assert.equal(current.publicationCurrentnessChecked,false);
  f.state.hooks.result=({method,values})=>method==="viewFinalitySources"?[{...values[0],referencePublication:A(999)}]:undefined;await assert.rejects(w.inspectViewCompleteBindingCurrent(f.provider,f.deployment,{blockTag:13,gasLimit:50000000n}),/selection differs/);
});
test("saved capture block, source drift and preceding-block attribution fail closed",async()=>{
  const f=await setup();const saved=await capture(f);f.state.blockHashes.set(10,H(777));await assert.rejects(w.simulateViewCompleteBinding(f.provider,saved,{blockTag:11}),/block changed/);
  const g=await setup();const s=await capture(g);g.state.hooks.result=({method,tag,values})=>method==="governanceActionPolicyState"&&tag===11?[H(555),...values.slice(1)]:undefined;const tx=g.transaction();await assert.rejects(w.reconcileViewCompleteBindingReceipt(g.provider,s,tx.txHash,tx.options),/Preceding/);
});
test("source and linked runtime pins are rechecked at the receipt block",async()=>{
  for(const target of [A(399),A(401),A(406),A(304),A(501),A(503)]){const f=await setup({kind:"executeGovernanceBatch"}),saved=await capture(f),tx=f.transaction();f.state.hooks.code=(a,tag)=>a===target&&tag===12?"0x6001":undefined;await assert.rejects(w.reconcileViewCompleteBindingReceipt(f.provider,saved,tx.txHash,tx.options),/runtime/);}
});
test("direct and Safe transport reject wrong hash/value/CALL/failure and early success",async()=>{
  for(const fault of ["hash","delegate","value","failure","early"]){const f=await setup({kind:"executeGovernanceBatch"}),saved=await capture(f),tx=f.transaction("indexed");
    if(fault==="hash")tx.options.expectedSafeTxHash=H(999);if(fault==="delegate"||fault==="value"){const decoded=Array.from(safe.decodeFunctionData("execTransaction",f.state.transaction.data));decoded[fault==="delegate"?3:1]=1n;f.state.transaction.data=safe.encodeFunctionData("execTransaction",decoded);}
    if(fault==="failure")f.state.receipt.logs.at(-1).topics[0]=safe.getEvent("ExecutionFailure").topicHash;
    if(fault==="early")f.state.receipt.logs.unshift(f.state.receipt.logs.pop());f.reindex();await assert.rejects(w.reconcileViewCompleteBindingReceipt(f.provider,saved,tx.txHash,tx.options));
  }
});
test("receipt bytes are detached before provider awaits; metadata, removed logs and bounds reject",async()=>{
  const f=await setup({kind:"executeGovernanceBatch"}),saved=await capture(f),tx=f.transaction();f.state.hooks.transaction=()=>{f.state.receipt.logs[1].topics[1]=H(99);};await w.reconcileViewCompleteBindingReceipt(f.provider,saved,tx.txHash,tx.options);
  for(const mutate of [f=>{f.state.receipt.logs[0].removed=true;},f=>{f.state.receipt.logs[0].index=NaN;},f=>{delete f.state.receipt.logs[0].blockHash;},f=>{f.state.receipt.from=A(999);},f=>{f.state.transaction.data=`0x${"00".repeat(2097152+16385)}`;}]){const g=await setup({kind:"executeGovernanceBatch"}),s=await capture(g),t=g.transaction();mutate(g);await assert.rejects(w.reconcileViewCompleteBindingReceipt(g.provider,s,t.txHash,t.options));}
});
test("refusal preserves original RPC errors and distinguishes execution revert from transport failure",async()=>{
  for(const code of ["CALL_EXCEPTION","NETWORK_ERROR"]){const f=await setup({kind:"executeGovernanceBatch"}),saved=await capture(f),error=Object.assign(Error("original refusal"),{code});f.state.originalFailure=error;const r=await w.observeViewCompleteBindingRefusal(f.provider,saved,{blockTag:11});assert.equal(r.error,error);assert.equal(r.outcome,code==="CALL_EXCEPTION"?"execution-reverted":"rpc-failed");assert.equal(r.nativeRollbackProven,false);}
});
test("inputs are copied before the first await, and bound resource/canonical RPC failures reject",async()=>{
  const f=await setup(),d=structuredClone(f.deployment),candidate=structuredClone(f.candidate),options={blockTag:10,gasLimit:50000000n};f.state.hooks.network=()=>{d.provider.address=A(999);candidate.selection.referencePublication=A(998);options.blockTag=999;};const p=await w.previewViewCompleteBinding(f.provider,d,candidate,options);assert.equal(p.deployment.provider.address,A(40));assert.equal(p.candidate.selection.referencePublication,A(304));assert.equal(p.observed.blockNumber,10);
  const g=await setup();g.state.hooks.call=({method,iface})=>method==="viewPreservationBindingStatus"?`${iface.encodeFunctionResult(method,[0n])}00`:undefined;await assert.rejects(capture(g),/Noncanonical|invalid length/);
});
