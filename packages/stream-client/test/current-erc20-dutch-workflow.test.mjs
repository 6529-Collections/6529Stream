import test from "node:test";
import assert from "node:assert/strict";
import { ZeroHash } from "ethers";
import { setup, A, H } from "./current-canonical-dutch-workflow-fixture.mjs";
import * as e from "../dist/current-erc20-dutch.js";

const lanes=["ByPayer","WithIntent","WithEIP2612Permit","WithPermit2"];

test("all four actual Payment routes support direct and both Safe layouts",async()=>{
  for(const lane of lanes)for(const mode of ["direct","legacy","indexed"]) {
    const f=setup({family:"erc20",lane,mode,signed:lane==="WithIntent",payer:lane==="WithIntent"?A(36):undefined,fee:7n,credit:3n});
    const saved=await f.capture();const sim=await f.simulate(saved);assert.equal(sim.paymentResult.revenueOutcome,2n);
    f.install();const r=await f.reconcile(saved);assert.equal(r.purchaseReceipt.chargedAmount,100n);assert.equal(r.purchaseReceipt.revealCredit,3n);
    assert.equal(r.settlement.result.asset,A(24));assert.ok(f.state.calls.some(c=>c.name==="resolveERC20DutchExecution"&&c.from===A(23)));
  }
});

test("FREE Payment authenticates intent but skips all permit authority and token movement",async()=>{
  for(const lane of lanes)for(const mode of ["direct","legacy","indexed"]) {
    const f=setup({family:"erc20",lane,mode,price:0n,permitMaximum:0n,permitDeadline:0n,credit:5n});
    f.state.overrides.set("assetPermitPolicy",()=>{throw Error("must not read free permit policy");});
    const saved=await f.capture();const sim=await f.simulate(saved);assert.equal(sim.paymentResult.revenueOutcome,1n);
    assert.equal(sim.paymentResult.settlement.settlementKey,ZeroHash);f.install();const r=await f.reconcile(saved);
    assert.equal(r.settlement,null);assert.equal(r.purchaseReceipt.revealCredit,5n);
    assert.equal(f.state.calls.some(c=>["nonces","nonceBitmap","allowance"].includes(c.name)),false);
  }
});

test("price drift recomputes paid commitment while identity/key and signed calldata stay unchanged",async()=>{
  const f=setup({family:"erc20",lane:"WithEIP2612Permit",signed:true,startPrice:1000n,price:10n});
  const saved=await f.capture();f.install();const r=await f.reconcile(saved);
  assert.equal(r.purchaseReceipt.chargedAmount,10n);assert.equal(r.purchaseReceipt.executionId,saved.candidate.executionBinding.executionId);
  assert.equal(r.purchaseReceipt.settlementKey,f.receipt.settlementKey);
  assert.notEqual(r.settlement.result.candidateCommitment,e.erc20DutchCandidateCommitment(1n,A(23),A(13),saved.candidate));
  assert.equal(saved.prepared.call.data,f.prepared.call.data);
});

test("paid maximum permits retain exact remainder and bitmap instead of charging the maximum",async()=>{
  for(const lane of ["WithEIP2612Permit","WithPermit2"]) {
    const f=setup({family:"erc20",lane,permitMaximum:1000n});const saved=await f.capture();f.install();await f.reconcile(saved);
    f.state.overrides.set(lane==="WithPermit2"?"nonceBitmap":"allowance",(call)=>[call.blockTag>=11?999n:lane==="WithPermit2"?0n:10000n]);
    await assert.rejects(f.reconcile(saved),/nonce bit|allowance/);
  }
});

test("FREE and paid intent deadlines remain authoritative, unlike ignored FREE permit deadlines",async()=>{
  for(const price of [0n,100n]) {
    const f=setup({family:"erc20",lane:"WithIntent",price,intentDeadline:109n});const saved=await f.capture();f.install();await assert.rejects(f.reconcile(saved),/deadline/);
  }
  const f=setup({family:"erc20",lane:"WithPermit2",permitDeadline:109n});const saved=await f.capture();f.install();await assert.rejects(f.reconcile(saved),/deadline/);
});

test("carrier refunds and Manager revocation are independent of unavailable Payment/token commerce",async()=>{
  for(const mode of ["direct","legacy","indexed"])for(const revoke of [false,true]) {
    const f=setup({family:"erc20",mode,signed:true});
    if(revoke)f.changeRequest({kind:"voidMintImmediateSaleAuthorization",authorization:f.authorization,authorizer:A(31),authorizerKind:2n,revocationSignature:"0x"});
    else {f.state.historicalCredit=10n;f.state.historicalLiability=15n;f.changeRequest({kind:"claimRefund",saleId:f.saleId,recipient:A(35)});}
    f.state.codeGone=new Set([A(13),A(14),A(15),A(19),A(20),A(23),A(24),A(25),...(revoke?[]:[A(11),A(12)])]);
    const saved=await f.capture();await f.simulate(saved);f.install();const r=await f.reconcile(saved);assert.equal(revoke?r.revokedAuthorizationId:r.refundedAmount,revoke?f.batch.authorizationId:10n);
  }
});


test("permit quote transitions from PAID to FREE both before and at inclusion",async()=>{
  for(const lane of ["WithEIP2612Permit","WithPermit2"])for(const minedBlock of [11,12]) {
    const f=setup({family:"erc20",lane,startPrice:100n,price:0n,minedBlock});const saved=await f.capture();assert.ok(saved.candidate.sale.amount>0n);
    f.install();const r=await f.reconcile(saved);assert.equal(r.settlement,null);assert.equal(r.purchaseReceipt.chargedAmount,0n);
    assert.equal(f.state.calls.filter(c=>c.tag===minedBlock&&["nonces","nonceBitmap","allowance"].includes(c.name)).length,0);
  }
});

test("paid intent must precede carrier start and original funding deltas cannot be substituted",async()=>{
  for(const fault of ["intent-order","payer-balance","payment-balance","phase","asset"]) {
    const f=setup({family:"erc20",lane:"WithIntent",signed:true,payer:A(36)});const saved=await f.capture();f.install();
    if(fault==="intent-order"){[f.state.logs[0],f.state.logs[1]]=[f.state.logs[1],f.state.logs[0]];f.renumber();}
    if(fault.includes("balance"))f.state.overrides.set("balanceOf",(call,args)=>[args[0]===A(36)?10000n-(call.blockTag>=11?(fault==="payer-balance"?99n:100n):0n):call.blockTag>=11&&args[0]===A(23)&&fault==="payment-balance"?1001n:1000n]);
    if(fault==="phase")f.state.overrides.set("phase",(call)=>call.to===A(23)?[call.blockTag>=11?1n:0n]:[true,{paused:false,startTime:1n,endTime:9000n,maxBatchQuantity:1n,configHash:H("phase"),metadataHash:H("metadata")}]);
    if(fault==="asset")f.state.overrides.set("assetPolicy",()=>[2n,H("asset-policy"),1n,0n]);
    await assert.rejects(f.reconcile(saved));
  }
});

test("ERC20 signed distinct payer is permitted only in Intent lane and public execution stays literal payer",async()=>{
  assert.throws(()=>setup({family:"erc20",lane:"ByPayer",signed:true,payer:A(36)}));
  assert.throws(()=>setup({family:"erc20",lane:"WithIntent",payer:A(36)}));
  const f=setup({family:"erc20",lane:"WithIntent",signed:true,payer:A(36),credit:9n});const saved=await f.capture();f.install();
  const r=await f.reconcile(saved);assert.equal(r.purchaseReceipt.revealCredit,9n);
  assert.ok(f.state.calls.some(c=>c.name==="refundableBalance"));
});

test("retained floor release from a former recorder joins by immutable hash and explicit locator",async()=>{
  const f=setup({family:"erc20",tier:"MUSEUM_GRADE_LITE",retainedFloor:true});const saved=await f.capture();f.install();
  await assert.rejects(f.reconcile(saved),/locator/);const r=await f.reconcile(saved,{releaseKey:f.release.releaseKey});
  assert.equal(r.settlement.release.recorder,A(88));
  f.state.overrides.set("releaseFloorReceipt",()=>[{...f.release,receiptHash:H("substituted")}]);await assert.rejects(f.reconcile(saved,{releaseKey:f.release.releaseKey}),/linkage/);
});

test("retained deprecated admission requires both original clocks/revisions; local history ignores later admission",async()=>{
  const f=setup({family:"erc20",deprecated:true});const saved=await f.capture();f.install();await f.reconcile(saved);
  f.state.row.status=3n;f.state.codeGone=new Set([A(11),A(12),A(13),A(14),A(15),A(23),A(24)]);assert.equal((await f.inspect()).status,2n);
  const bad=setup({family:"erc20",deprecated:true});bad.state.row.revision=1n;await assert.rejects(bad.capture(),/DEPRECATED/);
});


test("maximum uint256 permit approvals follow the original token and attested Permit2 exceptions",async()=>{
  const maximum=(1n<<256n)-1n;
  for(const options of [{lane:"WithEIP2612Permit",permitMaximum:maximum,retainMaximum:true},
    {lane:"WithPermit2",approval:maximum,allowanceMode:1n}, {lane:"WithPermit2",approval:maximum,allowanceMode:2n}]) {
    const f=setup({family:"erc20",...options});const saved=await f.capture();f.install();await f.reconcile(saved);
  }
});


test("FREE inclusion skips prior-block paid permit expiry, spent nonce and retired capability",async()=>{
  for(const lane of ["WithEIP2612Permit","WithPermit2"])for(const fault of ["expiry","nonce","capability"]) {
    const f=setup({family:"erc20",lane,startPrice:100n,price:0n,scheduleEnd:120n,minedBlock:12,
      ...(fault==="expiry"?{permitDeadline:100n}:{})});
    const saved=await f.capture();assert.ok(saved.candidate.sale.amount>0n);assert.ok(f.amountAt(110n)>0n);
    if(fault==="nonce")f.state.overrides.set(lane==="WithPermit2"?"nonceBitmap":"nonces",call=>[call.blockTag>=11?999n:lane==="WithPermit2"?0n:5n]);
    if(fault==="capability")f.state.overrides.set("assetPermitPolicy",call=>{
      if(call.blockTag>=11)throw Error("retired prior permit capability");
      return [{capabilities:3n,permit2AllowanceMode:1n,permit2:A(25),permit2CodeHash:f.d.asset.codeHash,
        assetCodeHash:f.d.asset.codeHash,assetPolicyHash:H("asset-policy"),assetPolicyRevision:1n,revision:1n}];
    });
    f.install();const r=await f.reconcile(saved);assert.equal(r.purchaseReceipt.chargedAmount,0n);assert.equal(r.settlement,null);
    assert.equal(f.state.calls.filter(c=>c.tag>=11&&["assetPermitPolicy","nonces","nonceBitmap","allowance"].includes(c.name)).length,0);
  }
});
