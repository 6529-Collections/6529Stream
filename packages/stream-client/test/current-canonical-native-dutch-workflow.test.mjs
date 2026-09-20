import test from "node:test";
import assert from "node:assert/strict";
import { ZeroHash, ZeroAddress, Interface } from "ethers";
import { setup, A, H, safe, indexedSafe, CODE_HASH } from "./current-canonical-dutch-workflow-fixture.mjs";
import * as n from "../dist/current-canonical-native-dutch.js";
import * as w from "../dist/current-canonical-native-dutch-workflow.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";
import { compiledABI } from "./current-canonical-dutch-fixture.mjs";

test("native Dutch signed/public direct and both Safe layouts preserve original payer and receipts", async () => {
  for (const signed of [false,true]) for (const mode of ["direct","legacy","indexed"]) {
    const f=setup({signed,mode,price:100n}); const saved=await f.capture();
    assert.equal((await f.simulate(saved)).receipt.chargedAmount,100n);
    f.install(); const r=await f.reconcile(saved);
    assert.equal(r.purchaseReceipt.tokenId,123n); assert.ok(r.settlement);
  }
});

test("native price drift changes committed amount while preserving original execution/root/key", async () => {
  const f=setup({startPrice:1000n,price:10n,credit:7n}); const saved=await f.capture();
  assert.ok(saved.candidate.sale.amount>10n); f.install(); const r=await f.reconcile(saved);
  assert.equal(r.purchaseReceipt.chargedAmount,10n);
  assert.equal(r.purchaseReceipt.executionId,saved.candidate.executionBinding.executionId);
  assert.equal(r.purchaseReceipt.operationRoot,saved.candidate.operationIdentityCommitment);
  assert.equal(r.purchaseReceipt.settlementKey,f.receipt.settlementKey);
  assert.notEqual(r.settlement.result.candidateCommitment,n.canonicalNativeDutchCandidateCommitment(1n,A(13),saved.candidate));
});

test("native resting FREE retains mint/authorization, full excess credit and no paid evidence", async () => {
  for (const mode of ["direct","legacy","indexed"]) {
    const f=setup({mode,startPrice:100n,price:0n,credit:3n}); const saved=await f.capture();
    f.install(); const r=await f.reconcile(saved);
    assert.equal(r.purchaseReceipt.chargedAmount,0n); assert.equal(r.purchaseReceipt.revealCredit,103n);
    assert.equal(r.purchaseReceipt.settlementKey,ZeroHash); assert.equal(r.settlement,null);
    assert.equal(f.state.calls.some(c=>c.name==="settlementResult"),false);
  }
});

test("reveal funding and bounded AT_MINT success/failure preserve source outcome", async () => {
  for(const revealSuccess of [false,true]) {
    const f=setup({fee:7n,credit:5n,revealSuccess});const saved=await f.capture();f.install();const r=await f.reconcile(saved);
    assert.equal(r.purchaseReceipt.revealFee,7n);assert.equal(r.revealAttempt.succeeded,revealSuccess);
    if(revealSuccess)assert.equal(r.revealAttempt.providerRequestId,0n);
  }
  const f=setup({declared:true,notRequired:true,fee:7n});const saved=await f.capture();f.install();assert.equal((await f.reconcile(saved)).revealAttempt,null);
});

test("local refunds and historical kind3 revocations survive commerce dependency loss on every transport", async () => {
  for(const mode of ["direct","legacy","indexed"])for(const revoke of [false,true]) {
    const f=setup({mode,signed:true});
    if(revoke)f.changeRequest({kind:"voidMintImmediateSaleAuthorization",authorization:f.authorization,authorizer:A(31),authorizerKind:2n,revocationSignature:"0x"});
    else {f.state.historicalCredit=10n;f.state.historicalLiability=15n;f.changeRequest({kind:"claimRefund",saleId:f.saleId,recipient:A(35)});}
    f.state.codeGone=new Set([A(13),A(14),A(15),A(19),A(20),...(revoke?[]:[A(11),A(12)])]);
    const saved=await f.capture();await f.simulate(saved);f.install();const r=await f.reconcile(saved);
    assert.equal(revoke?r.revokedAuthorizationId:r.refundedAmount,revoke?f.batch.authorizationId:10n);
    assert.equal(f.state.calls.some(c=>c.name==="saleRecord"),false);
  }
});

test("mined seller deadline and Manager phase/grace boundaries are inclusive", async () => {
  for(const options of [{signed:true,deadline:110n},{phaseEnd:110n},{grace:true,graceUntil:110n}]) {
    const f=setup(options);const saved=await f.capture();f.install();await f.reconcile(saved);
  }
  for(const options of [{signed:true,deadline:109n},{phaseEnd:109n},{grace:true,graceUntil:109n}]) {
    const f=setup(options);const saved=await f.capture();f.install();await assert.rejects(f.reconcile(saved),/expired/);
  }
});

test("both Safe formats reject wrong independent hash, operation/value substitution and early success", async () => {
  for(const mode of ["legacy","indexed"])for(const fault of ["hash","operation","value","early","failure"]) {
    const f=setup({mode});const saved=await f.capture();f.install();
    if(fault==="hash"){await assert.rejects(f.reconcile(saved,{expectedSafeTxHash:H("wrong")}));continue;}
    if(fault==="operation"||fault==="value") {const a=[...safe.decodeFunctionData("execTransaction",f.state.tx.data)];a[fault==="operation"?3:1]=fault==="operation"?1n:a[1]+1n;f.state.tx.data=safe.encodeFunctionData("execTransaction",a);}
    if(fault==="early"){f.state.logs.unshift(f.state.logs.pop());f.renumber();}
    if(fault==="failure"){const log=f.state.logs.at(-1);Object.assign(log,safe.encodeEventLog(safe.getEvent("ExecutionFailure"),[H("safe-transaction"),0n]));}
    await assert.rejects(f.reconcile(saved));
  }
});

test("immutable local history and shared Safe planner preserve actual original call", async () => {
  const f=setup({mode:"legacy"});const saved=await f.capture();f.install();
  f.state.codeGone=new Set([A(11),A(12),A(13),A(14),A(15),A(19),A(20)]);
  assert.equal((await f.inspect()).receipt.executionId,f.receipt.executionId);
  const plan=createSafeCallPlan(1n,"Dutch purchase",[{safe:f.caller,intent:"Original native Dutch purchase",call:f.prepared.call,abi:compiledABI("nativeDutch")}]);
  verifySafeCallPlan(plan,[compiledABI("nativeDutch")]);assert.equal(plan.steps[0].transaction.value,f.prepared.call.value.toString());
  assert.equal(saved.prepared.request.kind,"purchasePublic");
});


test("same-leaf price counter override replaces signed ceiling without rewriting authorization",async()=>{
  const f=setup({signed:true,allowlist:true,maximum:1n,startPrice:100n,price:0n});
  const saved=await f.capture();assert.equal(saved.candidate.sale.amount,0n);assert.equal(saved.prepared.request.authorization.unitPrice,1n);
  f.install();assert.equal((await f.reconcile(saved)).settlement,null);
  const bad=setup({allowlist:true,price:0n});bad.state.overrides.set("phaseCounterIds",()=>[[H("other")]]);
  await assert.rejects(bad.capture());
});

test("paid capture can reach FREE before the immediately preceding block without false quote currentness",async()=>{
  const f=setup({startPrice:100n,price:0n,minedBlock:12});const saved=await f.capture();assert.ok(saved.candidate.sale.amount>0n);
  f.install();assert.equal((await f.reconcile(saved)).purchaseReceipt.chargedAmount,0n);
});

test("exact reviewed route helper pins protect local exits and local linked reads without commerce",async()=>{
  for(const route of ["refund","history","revocation"]) {
    const f=setup({signed:true});f.d[`${route}LinkedDependencies`]=[{address:A(80),codeHash:CODE_HASH}];
    if(route==="refund"){f.state.historicalCredit=1n;f.state.historicalLiability=1n;f.changeRequest({kind:"claimRefund",saleId:f.saleId,recipient:A(35)});}
    if(route==="revocation")f.changeRequest({kind:"voidMintImmediateSaleAuthorization",authorization:f.authorization,authorizer:A(31),authorizerKind:2n,revocationSignature:"0x"});
    f.state.codeGone.add(A(80));await assert.rejects(route==="history"?f.inspect():f.capture(),/Runtime pin/);
  }
});

test("copied logs, canonical returns, mined metadata, original domain and infrastructure pins reject contradictions",async()=>{
  for(const fault of ["removed","fractional","hash","endpoint","mutation"]) {
    const f=setup({mode:"legacy"});const saved=await f.capture();f.install();
    if(fault==="removed")f.state.logs[0].removed=true;
    if(fault==="fractional")f.state.logs[0].index=0.5;
    if(fault==="hash")f.state.logs[0].blockHash=H("wrong");
    if(fault==="endpoint")f.state.receipt.from=A(91);
    if(fault==="mutation")f.state.mutateAfterReceipt=()=>{Object.assign(f.state.logs.at(-1),safe.encodeEventLog(safe.getEvent("ExecutionSuccess"),[H("wrong"),0n]));};
    if(fault==="mutation")await f.reconcile(saved);else await assert.rejects(f.reconcile(saved));
  }
  const f=setup({signed:true});f.state.overrides.set("eip712Domain",()=>["0x0f","wrong","1",1n,A(10),ZeroHash,[]]);await assert.rejects(f.capture(),/domain/);
  const g=setup();g.provider.getCode=async()=>`0xef0100${A(81).slice(2)}`;await assert.rejects(g.capture(),/Runtime pin/);
});


test("fresh simulation reprices the immutable request and completed token may already be burned",async()=>{
  const f=setup({startPrice:1000n,price:10n});const saved=await f.capture();
  const next=await w.simulateCanonicalNativeDutch(f.provider,saved,{blockTag:11,gasLimit:5_000_000n});
  assert.equal(next.receipt.chargedAmount,10n);assert.equal(next.capture.prepared.call.data,saved.prepared.call.data);
  f.install();f.state.overrides.set("tokenCollectionIdentity",()=>[true,1n,1n,true]);f.state.overrides.set("tokenLifecycle",()=>[3n]);
  assert.equal((await f.reconcile(saved)).purchaseReceipt.tokenId,123n);
});
