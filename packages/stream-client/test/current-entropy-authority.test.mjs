import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { prepareAuthorityRecipe, requireSameAuthorityRecipe, readAuthorityJSON } from "../examples/current-entropy-authority.mjs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id, keccak256, toUtf8Bytes, getAddress } from "ethers";
import { CurrentEntropyAuthorityClient, ENTROPY_FINDING_HYDRATION_PROFILE, requireSafeExecution } from "../dist/index.js";
const fixture=JSON.parse(readFileSync(new URL("./fixtures/current-entropy-authority-abi.json",import.meta.url),"utf8"));
const abi=Object.fromEntries(Object.entries(fixture.abis).map(([k,v])=>[k,new Interface(v)]));
const coder=AbiCoder.defaultAbiCoder(), A=n=>getAddress(`0x${BigInt(n).toString(16).padStart(40,"0")}`), H=id;
const code="0x6000600055", codeHash=keccak256(code), chain=31337n, collection=9007199254740997n;
const deployment={core:A(1),artist:A(2),entropy:A(3),coreCodeHash:codeHash,artistCodeHash:codeHash,entropyCodeHash:codeHash};
const coordinator=A(4),owners=Array.from({length:7},(_,i)=>A(10+i)),safe=A(50),origin=A(70);
const recovery={oldRequestKey:H("old"),reasonURI:"ipfs://reason",providerEvidenceHash:H("provider evidence")};
const INTENT="tuple(uint256,uint256,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)";
const TARGET="tuple(address,tuple(bytes32,string,bytes32),bytes32,bytes32)";
function intentHash(i){return keccak256(coder.encode(["bytes32","uint256","address","address",INTENT],[H("6529STREAM_ENTROPY_ARTIST_RECOVERY_INTENT_V1"),chain,deployment.entropy,deployment.core,Object.values(i)]));}
function evidenceHash(original,target,i){return keccak256(coder.encode(["bytes32","uint256","address","address",TARGET,INTENT,"bytes32"],[H("6529STREAM_ARTIST_ENTROPY_UNAVAILABILITY_V1"),chain,original,deployment.core,[target.coordinator,Object.values(target.recovery),target.intentHash,target.unavailableEvidenceHash],Object.values(i),codeHash]));}
function recordHash(original,r){return keccak256(coder.encode(["bytes32","uint256","address","bytes32","uint256","bytes32","bytes32","bytes32","uint64","uint64"],[H("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_RECORD_V1"),chain,original,r.terms.artistId,r.terms.collectionId,r.terms.evidenceHash,r.terms.reasonHash,r.governanceActionId,r.noticeEndsAt,r.recordedAt]));}
function request(){
 const snapshot={domainId:H("owner domain"),revision:3n,stateRoot:H("state"),recordChainTip:H("tip")};
 const checkpoint={schema:H("checkpoint"),ownerState:snapshot,replayRoot:H("replay"),replayCount:1n,nonceRoot:H("nonces"),nonceIndexCount:1n};
 return {authority:{bindingIndex:0n,artistId:H("artist"),collectionId:collection,expectedSource:Array.from({length:7},()=>structuredClone(checkpoint)),replayOrigins:Array.from({length:7},()=>[{surface:H("surface"),scope:H("scope")}]),policies:[]},includePayout:true,publications:true,
 economics:[{collectionId:collection,resolver:A(80),revenueClass:H("PRIMARY_SALE"),scope:2n,scopeId:9007199254741009n,assignmentHash:H("assignment")}],
 attestations:[{terms:{collectionId:collection,subjectKind:7n,subjectId:H("subject"),subjectStateHash:H("subject state"),schemaId:H("schema"),statementHash:H("statement"),statementURI:"ipfs://statement"},nonce:9007199254741011n}]};
}
// Synthetic selected RPC transport only. Literal preimages above are independent of helper hashing.
class RPC {
 number=100; timestamp=500; calls=[]; safeNonce=3n; nonceReads=0; nonceDrift=false; fee=9007199254740995n; valid=true; malformed=null; badPointer=false; badRuntime=false; reorg=false; failed=false; completed=false; badReceipt=false; hydration=ZeroHash; partial=false; sourceChanged=false; unknownOrigin=false; wrongOwner=false;
 intent={collectionId:collection,tokenId:collection+1n,scopeId:ZeroHash,oldRequestKey:recovery.oldRequestKey,newRequestKey:H("new"),priorJournalHead:H("prior"),journalHead:H("journal"),currentContentStateHash:H("current content"),contentStateHash:H("new content"),requestPolicyHash:H("request policy"),incidentEvidenceHash:H("incident"),providerEvidenceHash:recovery.providerEvidenceHash,reasonHash:keccak256(toUtf8Bytes(recovery.reasonURI))};
 constructor(){
  this.target={coordinator:deployment.entropy,recovery:{...recovery},intentHash:intentHash(this.intent),unavailableEvidenceHash:H("unavailable")};
  this.record={recordHash:ZeroHash,terms:{artistId:H("artist"),collectionId:collection,evidenceHash:evidenceHash(origin,this.target,this.intent),reasonHash:H("governance reason")},governanceActionId:H("governance action"),noticeEndsAt:490n,recordedAt:100n,noticeSeconds:390n,timingRevision:1n,bindingGeneration:1n,bindingHash:H("binding")};
  this.record.recordHash=recordHash(origin,this.record);
  this.admission={target:this.target,intent:{...this.intent},coordinatorCodeHash:codeHash,activityEpoch:9n,governanceWitnessHash:H("governance witness")};
 }
 async getNetwork(){return {chainId:chain};}
 async getBlock(tag){return {number:this.number,timestamp:this.timestamp,hash:H(this.reorg&&tag!=="latest"?"changed":`block:${this.number}`)};}
 async getCode(a){return this.badRuntime&&a===deployment.entropy?"0x6001":code;}
 async call(tx){
  this.calls.push(tx);
  if(tx.to===safe&&tx.data==="0xaffed0e0"){this.nonceReads++;return coder.encode(["uint256"],[this.safeNonce+(this.nonceDrift&&this.nonceReads>1?1n:0n)]);}
  let k=Object.keys(deployment).find(k=>deployment[k]===tx.to); if(tx.to===coordinator) k="coordinator";if(owners.includes(tx.to))k="owner";
  assert(abi[k],`Unknown target ${tx.to}`);const parsed=abi[k].parseTransaction(tx),n=parsed.name,a=parsed.args;let out;
  if(n==="core")out=[deployment.core];
  else if(n==="artistRegistry")out=[this.wrongOwner?A(99):deployment.artist];
  else if(n==="operationCoordinator")out=[coordinator];
  else if(n==="getSatellitePointer")out=[this.badPointer?A(99):a[0]===H("ARTIST_REGISTRY")?deployment.artist:deployment.entropy,codeHash,false,ZeroHash,"0x00000000",ZeroAddress,0n,ZeroHash,ZeroHash,0n];
  else if(n==="authorityHydrationSuite")out=[{registry:deployment.artist,archive:A(40),owners,core:deployment.core,mintManager:A(41),roleRegistry:A(42),metadata:A(43),primaryResolver:A(44),royaltyResolver:A(45),primaryRevenueClass:H("PRIMARY_SALE"),validator:A(46)}];
  else if(n==="artistEntropyRecoveryIntent")out=[this.intent];
  else if(n==="freshRecoveryTransition")out=[this.intent.newRequestKey,this.intent.contentStateHash,this.fee];
  else if(n==="entropyUnavailabilityFindingContext")out=[{scopeHash:H("scope"),oldValueHash:ZeroHash,newValueHash:H("new state"),noticeSeconds:7776000n,timingRevision:1n}];
  else if(n==="entropyUnavailabilityFindingRecord")out=[this.record,this.admission];
  else if(n==="entropyUnavailabilityFindingOrigin"){assert.equal(tx.to,owners[2]);out=[this.unknownOrigin?ZeroAddress:origin];}
  else if(n==="verifyEntropyRecoveryUnavailability")out=[this.valid,this.record.recordHash,this.record.terms.artistId,this.record.noticeEndsAt];
  else if(n==="entropyUnavailabilityEvidence")out=this.completed?[this.record.recordHash,this.badReceipt?H("wrong intent"):this.target.intentHash,this.record.noticeEndsAt]:[ZeroHash,ZeroHash,0n];
  else if(n==="requestFreshEntropyWithUnavailability"){assert.equal(tx.from,safe);assert.equal(tx.value,this.fee+100n);if(this.failed)throw Error("GS013/callback rejection");out=[this.intent.newRequestKey,2n**200n];}
  else if(n==="authorityHydrationCommitment")out=[this.partial&&tx.to===owners[6]?H("other"):this.hydration];
  else if(n==="hydrateArtistAuthorityWithEntropyFindings"){assert.equal(tx.from,safe);if(this.failed)throw Error("Archive append rejected");out=[this.sourceChanged?H("changed source"):H("hydration complete")];}
  else throw Error(`Unhandled ${n}`);
  const raw=abi[k].encodeFunctionResult(n,out);return this.malformed===n?raw+"00".repeat(32):raw;
 }
}
const make=()=>new CurrentEntropyAuthorityClient(chain,deployment,fixture.abis);
const quote=(c,r)=>c.quoteRecovery(r,safe,recovery,r.record.recordHash,r.fee+100n);

test("finding context uses full literal intent/target evidence and original governance call",async()=>{
 const c=make(),r=new RPC(),p=await c.quoteFinding(r,{artistId:H("artist"),recovery,unavailableEvidenceHash:H("unavailable"),reasonHash:H("governance reason")});
 assert.equal(p.target.intentHash,intentHash(r.intent));assert.equal(p.terms.evidenceHash,evidenceHash(deployment.artist,p.target,r.intent));
 assert.equal(p.terms.collectionId,collection);assert.equal(p.call.value,0n);assert.equal(p.context.noticeSeconds,7776000n);
 const parsed=abi.artist.parseTransaction(p.call);assert.equal(parsed.name,"recordEntropyUnavailabilityFinding");assert.equal(parsed.args.target.intentHash,p.target.intentHash);
 assert.throws(()=>c.safeCall(p),/Unrecognized/);assert.equal(r.calls.some(x=>x.data===p.call.data),false);
});
test("successor finding preserves original ten-word domain and actual Identity owner provenance",async()=>{
 const c=make(),r=new RPC(),p=await quote(c,r);assert.equal(p.originalRegistry,origin);assert.equal(c.findingRecordHash(origin,r.record),r.record.recordHash);assert.notEqual(c.findingRecordHash(deployment.artist,r.record),r.record.recordHash);
 const changed={...r.record,timingRevision:50n};assert.equal(c.findingRecordHash(origin,changed),r.record.recordHash); // outside original ten words, still checked onchain
 assert.equal(p.intentHash,intentHash(r.intent));assert.equal(p.providerFee,r.fee);assert.equal(c.safeCall(p).call.value,(r.fee+100n).toString());
 assert.equal(c.safeCall(p).call.operation,0);assert.equal(c.safeCall(p).safe,safe);
 assert.equal(abi.entropy.parseTransaction(p.call).name,"requestFreshEntropyWithUnavailability");
});
test("scope target is preserved; no token guessing or narrowing of full-width values",async()=>{
 const c=make(),r=new RPC();r.intent.tokenId=0n;r.intent.scopeId=H("scope subject");
 const p=await c.quoteFinding(r,{artistId:H("artist"),recovery,unavailableEvidenceHash:H("evidence"),reasonHash:H("reason")});
 assert.equal(p.intent.scopeId,r.intent.scopeId);assert.equal(p.intent.tokenId,0n);assert.equal(p.target.intentHash,intentHash(r.intent));
});
test("runtime, selection, reciprocal owners, canonical returns and block reorg fail closed",async()=>{
 for(const key of ["badPointer","badRuntime","wrongOwner","reorg"]){const r=new RPC();r[key]=true;await assert.rejects(quote(make(),r));}
 for(const method of ["getSatellitePointer","artistEntropyRecoveryIntent","freshRecoveryTransition","verifyEntropyRecoveryUnavailability"]){const r=new RPC();r.malformed=method;await assert.rejects(quote(make(),r));}
});
test("changed full intent, unknown origin, bad old record and unavailable activity cannot authorize recovery",async()=>{
 for(const change of [r=>r.unknownOrigin=true,r=>r.valid=false,r=>r.record.governanceActionId=H("forged action"),r=>r.admission.intent.requestPolicyHash=H("wrong policy"),r=>r.admission.target.recovery.reasonURI="changed",r=>r.admission.coordinatorCodeHash=H("wrong runtime")]){const r=new RPC();change(r);await assert.rejects(quote(make(),r));}
});
test("timestamp notice and separate bigint native allowance are enforced",async()=>{
 const c=make(),r=new RPC();r.timestamp=489;await assert.rejects(quote(c,r),/notice/);r.timestamp=490;
 await assert.rejects(c.quoteRecovery(r,safe,recovery,r.record.recordHash,r.fee-1n),/allowance/);
 await assert.rejects(c.quoteRecovery(r,safe,recovery,r.record.recordHash,Number(r.fee)),/bigint/);
 assert.equal((await quote(c,r)).noticeEndsAt,490n);
});
test("failed Safe target keeps exact bytes; pending retry rechecks caller, fee and receipt",async()=>{
 const c=make(),r=new RPC(),p=await quote(c,r),before=c.safeCall(p);r.failed=true;await assert.rejects(c.resume(r,p),/rejection/);assert.deepEqual(c.safeCall(p),before);
 r.failed=false;assert.equal(await c.resume(r,p),"pending");assert.deepEqual(c.safeCall(p),before);
 const attempt=r.calls.filter(x=>x.data===p.call.data);assert.equal(attempt.length,2);assert.deepEqual(attempt[0],attempt[1]);assert.equal(attempt[0].blockTag,"pending");
 r.fee++;await assert.rejects(c.resume(r,p),/quote changed/);r.fee--;r.completed=true;assert.equal(await c.resume(r,p),"completed");r.badReceipt=true;await assert.rejects(c.resume(r,p),/receipt conflict/);
 const events=new Interface(["event ExecutionFailure(bytes32 txHash,uint256 payment)"]),event=events.encodeEventLog(events.getEvent("ExecutionFailure"),[H("safe tx"),0n]);
 assert.throws(()=>requireSafeExecution({status:1,logs:[{address:safe,...event}]},safe,H("safe tx")),/target execution failed/);
});
test("complete explicit hydration tuple preserves original profile, source headers and nonce width",async()=>{
 const c=make(),r=new RPC(),raw=request();r.badPointer=true;const p=await c.quoteHydration(r,safe,raw); // pre-cutover destination is intentional
 assert.equal(ENTROPY_FINDING_HYDRATION_PROFILE,H("6529STREAM_ARTIST_ENTROPY_FINDING_HYDRATION_V1"));
 assert.equal(p.call.data,abi.artist.encodeFunctionData("hydrateArtistAuthorityWithEntropyFindings",[raw]));assert.equal(p.call.value,0n);
 assert.equal(p.request.authority.expectedSource.length,7);assert.equal(p.request.attestations[0].nonce,9007199254741011n);
 raw.authority.expectedSource[0].ownerState.revision=99n;assert.equal(p.request.authority.expectedSource[0].ownerState.revision,3n);
 assert.equal(await c.resume(r,p),"pending");r.hydration=p.commitment;assert.equal(await c.resume(r,p),"completed");r.partial=true;await assert.rejects(c.resume(r,p),/conflict/);
});
test("hydration dependencies, complete seven-source shape, widths and extra fields reject",async()=>{
 for(const change of [r=>r.authority.expectedSource.pop(),r=>r.authority.replayOrigins.pop(),r=>r.includePayout=false,r=>r.economics=[],r=>r.attestations=[],r=>r.authority.expectedSource[0].ownerState.revision=2n**64n,r=>r.attestations[0].nonce=3,r=>r.unrelated=true]){const input=request();change(input);await assert.rejects(make().quoteHydration(new RPC(),safe,input));}
});
test("Archive failure and source drift preserve original Safe hydration call and completion commitment",async()=>{
 const c=make(),r=new RPC(),p=await c.quoteHydration(r,safe,request()),saved=c.safeCall(p);r.failed=true;await assert.rejects(c.resume(r,p),/Archive/);assert.deepEqual(c.safeCall(p),saved);
 r.failed=false;assert.equal(await c.resume(r,p),"pending");r.sourceChanged=true;await assert.rejects(c.resume(r,p),/commitment changed/);assert.deepEqual(c.safeCall(p),saved);
 await assert.rejects(c.resume(r,{...p}),/another client/);await assert.rejects(make().resume(r,p),/another client/);
});


test("read-only Safe recipe commits nonce/call/pins and rejects a changed external retry file",async()=>{
 const r=new RPC(),config={chainId:chain.toString(),deployment,caller:safe,operation:"recovery",recovery,finding:r.record.recordHash,nativeAllowance:(r.fee+100n).toString()};
 await assert.rejects(prepareAuthorityRecipe(r,{...config,chainId:Number(chain)},fixture.abis),/decimal string/);
 await assert.rejects(prepareAuthorityRecipe(r,{...config,nativeAllowance:Number(r.fee)},fixture.abis),/decimal string/);
 const first=await prepareAuthorityRecipe(r,config,fixture.abis);assert.equal(first.execution.call.operation,0);assert.equal(first.execution.safeNonce,"3");
 const retry=await prepareAuthorityRecipe(r,config,fixture.abis);assert.deepEqual(requireSameAuthorityRecipe(retry,first,first.executionHash),retry);
 const changed=structuredClone(first);changed.execution.call.value="0";assert.throws(()=>requireSameAuthorityRecipe(retry,changed,first.executionHash),/differs/);
 r.safeNonce++;const next=await prepareAuthorityRecipe(r,config,fixture.abis);assert.throws(()=>requireSameAuthorityRecipe(next,first,first.executionHash),/differs/);
 const drifting=new RPC();drifting.nonceDrift=true;await assert.rejects(prepareAuthorityRecipe(drifting,config,fixture.abis),/nonce changed/);
});
test("example JSON preserves tagged full-width integers without guessing text",()=>{
 const dir=mkdtempSync(join(tmpdir(),"entropy-authority-client-"));try{
  const file=join(dir,"request.json");writeFileSync(file,JSON.stringify({nonce:{$bigint:"9007199254740999"},reasonURI:"123"}));
  assert.deepEqual(readAuthorityJSON(file),{nonce:9007199254740999n,reasonURI:"123"});
  writeFileSync(file,JSON.stringify({nonce:{$bigint:"01"}}));assert.throws(()=>readAuthorityJSON(file),/tagged bigint/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
