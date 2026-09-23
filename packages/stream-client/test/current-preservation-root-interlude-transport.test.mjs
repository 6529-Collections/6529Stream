import test from 'node:test';
import assert from 'node:assert/strict';
import { getAddress, keccak256 } from 'ethers';
import { fixture, setup, copy, A, H, Z, ZA, sha, safeABI, indexedSafe, createPreservationRootInterludeTransport } from './current-preservation-root-interlude-transport-fixture.mjs';

// Compiler-shaped JSON/RPC consistency tests only. Signatures, Safe execution, original
// op17/root admission and the Prepared verification tool are deliberately not executed.
const options={blockTag:11,gasLimit:4_000_000n};
async function saved(f){const p=await f.capture(),e=await f.driver.saveSignedEnvelope(p.id,f.signed());return{p,e};}
function renumber(receipt){receipt.logs.forEach((l,i)=>{l.index=i;});}
const json=x=>JSON.stringify(x,(_k,v)=>typeof v==='bigint'?v.toString():v);

test('both original phases/families and both Safe versions/layouts retain exact envelope and qualified success',async()=>{
 for(const kind of ['collection','scoped'])for(const phase of ['consent','root'])for(const version of ['1.3.0','1.4.1'])for(const layout of ['legacy','indexed']){
  const f=fixture({kind,phase,version}),{p,e}=await saved(f);
  assert.equal(p.ownerSignaturesVerified,false);assert.equal(e.ownerSignaturesVerified,false);
  assert.equal(e.transaction.to,f.safe);assert.equal(e.transaction.data,f.signed().data.toLowerCase());assert.equal(e.signedEnvelopeHash,keccak256(e.transaction.data));
  assert.equal(Object.isFrozen(e.fields),true);assert.equal(e.innerCallHash,keccak256(p.packet.inner.data));
  const simulated=await f.driver.simulateSavedEnvelope(e.id,options);assert.equal(simulated.outerCallSucceeded,true);assert.equal(simulated.safeInnerSucceeded,true);assert.equal(simulated.stateChangesPersisted,false);
  const mined=f.mine(e,{layout}),r=await f.driver.inspectSubmission(e.id,mined.hash);
  assert.equal(r.outcome,'success');assert.equal(r.targetApplicationLogs,1);assert.equal(r.targetApplicationOrderChecked,true);assert.equal(r.applicationEventSchemasAuthenticated,false);
  assert.equal(r.originalProtocolReceiptVerified,false);assert.equal(r.priorConsentReceiptIndependentlyVerified,false);assert.equal(r.intraBlockTraceProven,false);
  assert.equal(r.observations.prior.number,11);assert.equal(r.observations.end.number,12);assert.equal(r.observations.nonceAfter,e.nonce+1n);
  assert.ok(f.state.calls.every(x=>x.to.toLowerCase()===f.safe));assert.ok(f.state.calls.every(x=>Number.isInteger(x.blockTag)));
 }
});

test('capture joins chain, original header, runtime pins, singleton, owners, threshold, nonce and independent hash',async()=>{
 const cases=[
  [f=>f.state.chainId++,/chain/], [f=>f.state.blockHook=n=>({...f.block(n),hash:H('reorg')}),/anchor/],
  [f=>f.code.set(f.roles.consentOwner.address,'0x6002'),/runtime/], [f=>f.state.storage='0x'+'00'.repeat(12)+A(55).slice(2),/singleton/],
  [f=>f.state.version='1.2.0',/VERSION/], [f=>f.state.owners.reverse(),/roster/], [f=>f.state.threshold=1n,/threshold/],
  [f=>f.state.nonce++,/nonce/], [f=>f.state.hashOverride=H('wrong-safe-hash'),/hash/]
 ];
 for(const[alter,pattern]of cases){const f=fixture();alter(f);await assert.rejects(f.capture,pattern);}
 const f=fixture();f.state.callHook=({name})=>name==='getOwners'?[[f.state.owners[0],f.state.owners[0]]]:undefined;await assert.rejects(f.capture,/Duplicate/);
});

test('exact high chain IDs, nonces and collection IDs survive without Number coercion and checksum callers agree',async()=>{
 const high=(1n<<180n)+37n,f=fixture({chainId:high,nonce:(1n<<230n)+5n,collectionId:(1n<<220n)+9n});
 const manifest={...copy(f.manifest),chainId:high.toString()},driver=createPreservationRootInterludeTransport({provider:f.provider,manifest});
 const p=await driver.capturePacket(f.text(),{expectedPacketSha256:sha(f.text())}),input=f.signed();input.outerSender=getAddress(input.outerSender);
 const e=await driver.saveSignedEnvelope(p.id,input);assert.equal(e.nonce,f.nonce);assert.equal(p.packet.originalPacket.request.scope[1],(1n<<220n)+9n);
 const mined=f.mine(e);mined.transaction.from=getAddress(mined.transaction.from);mined.receipt.from=getAddress(mined.receipt.from);
 assert.equal((await driver.inspectSubmission(e.id,mined.hash)).outcome,'success');
 const sent=[];await driver.submitSavedEnvelope(e.id,{sendTransaction:tx=>{sent.push(tx);return H('sent');}},options);assert.equal(sent[0].chainId,high);
});

test('all ten Safe transaction fields are bound and arbitrary inner calls, signatures and wrappers are rejected',async()=>{
 const changes=[{to:A(90)},{value:1n},{data:'0x12345678'},{operation:1n},{safeTxGas:1n},{baseGas:1n},{gasPrice:1n},{gasToken:A(91)},{refundReceiver:A(92)},{nonce:55n}];
 for(const change of changes){const f=fixture(),p=await f.capture();await assert.rejects(()=>f.driver.saveSignedEnvelope(p.id,f.signed(change)),/ten packet fields/);}
 const f=fixture(),p=await f.capture();
 await assert.rejects(()=>f.driver.saveSignedEnvelope(p.id,{...f.signed(),data:'0x8d80ff0a'}),/execTransaction/);
 await assert.rejects(()=>f.driver.saveSignedEnvelope(p.id,{...f.signed(),data:f.signed().data+'00'.repeat(32)}),/Noncanonical/);
 await assert.rejects(()=>f.driver.saveSignedEnvelope(p.id,{...f.signed(),expectedSafeTxHash:H('wrong')}),/expected Safe hash/);
 const empty=fixture({signatures:'0x'}),ep=await empty.capture();await assert.rejects(()=>empty.driver.saveSignedEnvelope(ep.id,empty.signed()),/signatures required/);
 const giant=fixture({signatures:'0x'+'11'.repeat(65537)}),gp=await giant.capture();await assert.rejects(()=>giant.driver.saveSignedEnvelope(gp.id,giant.signed()),/excessive/);
});

test('capture/save own input before awaits and permit only one saved envelope per packet',async()=>{
 const f=fixture(),m=copy(f.manifest),driver=createPreservationRootInterludeTransport({provider:f.provider,manifest:m}),text=f.text(),o={expectedPacketSha256:sha(text)};
 f.state.networkHook=()=>{m.artistSafe.codeHash=H('changed');m.chainId=1n;o.expectedPacketSha256='0'.repeat(64);};
 const p=await driver.capturePacket(text,o);assert.equal(p.packet.originalPacket.chainId,f.state.chainId);f.state.networkHook=null;
 const input=f.signed(),original=input.data;f.state.networkHook=()=>{input.data='0x';input.outerSender=A(99);};
 const e=await driver.saveSignedEnvelope(p.id,input);assert.equal(e.transaction.data,original);assert.notEqual(e.transaction.from,A(99));f.state.networkHook=null;
 await assert.rejects(()=>driver.saveSignedEnvelope(p.id,f.signed()),/already saved/);
 assert.throws(()=>{e.fields.nonce=5n;},TypeError);
 const g=fixture(),gp=await g.capture(),results=await Promise.allSettled([g.driver.saveSignedEnvelope(gp.id,g.signed()),g.driver.saveSignedEnvelope(gp.id,g.signed())]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.filter(r=>r.status==='rejected').length,1);
});

test('signed eth_call distinguishes true, returned false, GS013 simulation and sanitized transport failure',async()=>{
 const f=fixture(),{e}=await saved(f);f.state.result=false;let r=await f.driver.simulateSavedEnvelope(e.id,options);assert.equal(r.outerCallSucceeded,true);assert.equal(r.safeInnerSucceeded,false);assert.equal(r.gs013SimulationObserved,false);
 f.state.callError={code:'CALL_EXCEPTION',reason:'GS013',data:'0x08c379a0',message:'https://secret:password@rpc',info:{headers:{authorization:'credential'}}};
 r=await f.driver.simulateSavedEnvelope(e.id,options);assert.equal(r.outerCallSucceeded,false);assert.equal(r.safeInnerSucceeded,null);assert.equal(r.gs013SimulationObserved,true);assert.equal(r.failure.code,'CALL_EXCEPTION');assert.doesNotMatch(json(r),/password|credential|https|headers|authorization/);
 f.state.callError={code:'SERVER_ERROR',data:'not-hex',message:'secret',info:{url:'credential'}};r=await f.driver.simulateSavedEnvelope(e.id,options);assert.equal(r.failure.code,'SERVER_ERROR');assert.equal(r.failure.data,null);assert.equal(r.gs013SimulationObserved,false);
 f.state.callError=null;f.state.callHook=({name})=>name==='execTransaction'?{raw:safeABI.encodeFunctionResult('execTransaction',[true])+'00'.repeat(32)}:undefined;
 r=await f.driver.simulateSavedEnvelope(e.id,options);assert.equal(r.outerCallSucceeded,false);assert.equal(r.failure.code,'UNKNOWN_ERROR');
});

test('submission is explicit and preserves signed bytes while outer relayer nonce, gas and fees vary',async()=>{
 const f=fixture(),{e}=await saved(f),sent=[];const transport={sendTransaction:async tx=>{sent.push(tx);return{hash:H('sent-'+sent.length)};}};
 assert.equal(sent.length,0);await f.driver.submitSavedEnvelope(e.id,transport,{...options,nonce:5n,gasPrice:2n});await f.driver.submitSavedEnvelope(e.id,transport,{...options,gasLimit:8_000_000n,nonce:6n,maxFeePerGas:4n,maxPriorityFeePerGas:1n});
 assert.equal(sent.length,2);assert.equal(sent[0].data,e.transaction.data);assert.equal(sent[1].data,e.transaction.data);assert.equal(sent[0].from,e.transaction.from);assert.equal(sent[0].nonce,5n);assert.equal(sent[1].nonce,6n);assert.equal(Object.isFrozen(sent[0]),true);
 await assert.rejects(()=>f.driver.submitSavedEnvelope(e.id,{},options),/fields/);
 await assert.rejects(()=>f.driver.submitSavedEnvelope(e.id,transport,{...options,gasPrice:1n,maxFeePerGas:1n}),/Conflicting/);
 await assert.rejects(()=>f.driver.submitSavedEnvelope(e.id,{sendTransaction:()=>{throw{code:'SERVER_ERROR',message:'https://secret@rpc',info:{authorization:'credential'}};}},options),error=>{assert.equal(error.code,'SERVER_ERROR');assert.doesNotMatch(json(error),/secret|credential|https/);assert.equal(error.cause,undefined);return true;});
});

test('outer revert with unchanged Safe nonce allows same bytes retry without claiming GS013 or rollback',async()=>{
 const f=fixture(),{e}=await saved(f),m=f.mine(e,{outcome:'revert'}),r=await f.driver.inspectSubmission(e.id,m.hash);
 assert.equal(r.outcome,'safe-outer-reverted');assert.equal(r.safeSignaturesRetryable,true);assert.equal(r.zeroGasGs013Compatible,true);assert.equal(r.gs013ReceiptCauseProven,false);assert.equal(r.rollbackIndependentlyProven,false);
 const sent=[];await f.driver.submitSavedEnvelope(e.id,{sendTransaction:tx=>{sent.push(tx);return H('retry');}},{blockTag:12,gasLimit:9_000_000n,nonce:99n});assert.equal(sent[0].data,e.transaction.data);assert.equal(sent[0].nonce,99n);
 const bad=f.mine(e,{outcome:'revert'});bad.receipt.logs.push({address:A(42),topics:[],data:'0x',index:0,transactionHash:bad.hash,blockNumber:12,blockHash:f.block(12).hash,removed:false});await assert.rejects(()=>f.driver.inspectSubmission(e.id,bad.hash),/Reverted/);
});

test('nonzero safeTxGas failure consumes Safe nonce while impossible zero-gas failure refuses',async()=>{
 const f=fixture({safeTxGas:200_000n}),{e}=await saved(f),m=f.mine(e,{outcome:'failure',layout:'indexed'}),r=await f.driver.inspectSubmission(e.id,m.hash);assert.equal(r.outcome,'safe-execution-failure');assert.equal(r.safeSignaturesRetryable,false);
 await assert.rejects(()=>f.driver.simulateSavedEnvelope(e.id,{blockTag:12,gasLimit:4_000_000n}),/nonce consumed/);
 const g=fixture(),ge=(await saved(g)).e,gm=g.mine(ge,{outcome:'failure'});await assert.rejects(()=>g.driver.inspectSubmission(ge.id,gm.hash),/Impossible failure/);
});

test('Safe receipt requires one canonical correctly hashed success/failure event for either layout',async()=>{
 for(const layout of ['legacy','indexed'])for(const mode of ['missing','duplicate','hash','extra-word','topics']){
  const f=fixture(),{e}=await saved(f),m=f.mine(e,{layout}),event=m.receipt.logs[1];
  if(mode==='missing')m.receipt.logs.splice(1,1);if(mode==='duplicate')m.receipt.logs.splice(2,0,copy(event));
  if(mode==='hash')Object.assign(event,(layout==='indexed'?indexedSafe:safeABI).encodeEventLog('ExecutionSuccess',[H('wrong'),0n]));
  if(mode==='extra-word')event.data+='00'.repeat(32);if(mode==='topics')event.topics.push(H('extra-topic'));renumber(m.receipt);
  await assert.rejects(()=>f.driver.inspectSubmission(e.id,m.hash),/Safe (event|transaction)|Noncanonical|Malformed/);
 }
});

test('original Consent owner and Router logs must precede Safe success while unrelated post-guard logs remain valid',async()=>{
 for(const phase of ['consent','root']){
  const f=fixture({phase}),{e}=await saved(f),m=f.mine(e);assert.equal(m.receipt.logs[0].address,f.applicationEmitter);assert.equal((await f.driver.inspectSubmission(e.id,m.hash)).outcome,'success');
  const first=m.receipt.logs.shift();m.receipt.logs.push(first);renumber(m.receipt);await assert.rejects(()=>f.driver.inspectSubmission(e.id,m.hash),/Application event follows/);
  const none=f.mine(e,{application:false}),r=await f.driver.inspectSubmission(e.id,none.hash);assert.equal(r.targetApplicationLogs,0);assert.equal(r.originalProtocolReceiptVerified,false);assert.equal(r.applicationEventSchemasAuthenticated,false);
 }
});

test('mined exact sender, target, value, signed calldata, chain and strictly later blocks are joined',async()=>{
 for(const[name,value]of [['from',A(999)],['to',A(998)],['value',1n],['data','0x1234'],['chainId',1n]]){
  const f=fixture(),{e}=await saved(f),m=f.mine(e);m.transaction[name]=value;await assert.rejects(()=>f.driver.inspectSubmission(e.id,m.hash),/Mined signed envelope|invalid mined/);
 }
 const f=fixture(),{e}=await saved(f);f.state.minedBlock=10;const m=f.mine(e);await assert.rejects(()=>f.driver.inspectSubmission(e.id,m.hash),/follow packet/);
 const g=fixture(),ge=(await saved(g)).e,gm=g.mine(ge);gm.transaction.blockHash=H('different');await assert.rejects(()=>g.driver.inspectSubmission(ge.id,gm.hash),/identity/);
});

test('all log identities and ordering plus exact prior/end Safe nonce reject concurrent attribution',async()=>{
 for(const alter of [m=>{m.receipt.logs[0].removed=true;},m=>{m.receipt.logs[0].transactionHash=H('other');},m=>{m.receipt.logs[0].blockNumber=11;},m=>{m.receipt.logs[0].blockHash=H('other');},m=>{m.receipt.logs[1].index=0;}]){
  const f=fixture(),{e}=await saved(f),m=f.mine(e);alter(m);await assert.rejects(()=>f.driver.inspectSubmission(e.id,m.hash),/log identity/);
 }
 for(const prior of [true,false]){const f=fixture(),{e}=await saved(f),m=f.mine(e);if(prior)f.state.nonce++;else f.state.endNonce++;await assert.rejects(()=>f.driver.inspectSubmission(e.id,m.hash),/nonce/);}
});

test('mined runtime and Safe roster pins are rechecked at both preceding and ending blocks',async()=>{
 for(const changedBlock of [11,12]){
  const f=fixture(),{e}=await saved(f),m=f.mine(e);f.state.codeHook=(a,n)=>a===f.roles.consentOwner.address&&n===changedBlock?'0x6002':undefined;await assert.rejects(()=>f.driver.inspectSubmission(e.id,m.hash),/runtime/);
  const g=fixture(),ge=(await saved(g)).e,gm=g.mine(ge);g.state.callHook=({name,blockTag})=>name==='getOwners'&&blockTag===changedBlock?[[A(123),g.state.owners[1]]]:undefined;await assert.rejects(()=>g.driver.inspectSubmission(ge.id,gm.hash),/roster/);
 }
});

test('receipt and transaction inputs are detached before later provider awaits and headers remain canonical',async()=>{
 const f=fixture(),{e}=await saved(f),m=f.mine(e);f.state.txHook=()=>{m.receipt.logs[1].data='0x';};assert.equal((await f.driver.inspectSubmission(e.id,m.hash)).outcome,'success');f.state.txHook=null;
 const g=fixture(),ge=(await saved(g)).e,gm=g.mine(ge);g.state.networkHook=()=>{gm.transaction.data='0x';gm.receipt.logs.length=0;};assert.equal((await g.driver.inspectSubmission(ge.id,gm.hash)).outcome,'success');
 const h=fixture();let count=0;h.state.blockHook=n=>({...h.block(n),hash:++count>1?H('reorg'):h.block(n).hash});await assert.rejects(h.capture,/Anchored block changed/);
 const j=fixture(),je=(await saved(j)).e,jm=j.mine(je);let endReads=0;j.state.blockHook=n=>({...j.block(n),hash:n===12&&++endReads>1?H('end-reorg'):j.block(n).hash});await assert.rejects(()=>j.driver.inspectSubmission(je.id,jm.hash),/Anchored block changed/);
});

test('capture is the only route, same-instance IDs are required and transport/client bounds are explicit',async()=>{
 const f=fixture();assert.deepEqual(Object.keys(f.driver).sort(),['capturePacket','inspectSubmission','saveSignedEnvelope','simulateSavedEnvelope','submitSavedEnvelope'].sort());
 await assert.rejects(()=>f.driver.saveSignedEnvelope(H('unknown'),f.signed()),/Unknown captured/);await assert.rejects(()=>f.driver.capturePacket(f.packet,{expectedPacketSha256:sha(f.text())}),/String/);
 const{e}=await saved(f),other=createPreservationRootInterludeTransport({provider:f.provider,manifest:f.manifest});await assert.rejects(()=>other.simulateSavedEnvelope(e.id,options),/Unknown saved/);
 for(const o of [{...options,blockTag:'latest'},{...options,blockTag:9},{...options,gasLimit:0n},{...options,gasLimit:100_000_001n},{...options,arbitraryCall:'0x'}])await assert.rejects(()=>f.driver.simulateSavedEnvelope(e.id,o));
 const huge=fixture();huge.state.codeHook=()=> '0x'+'60'.repeat(131073);await assert.rejects(huge.capture,/excessive/);
 const f2=fixture();f2.state.callHook=({name})=>name==='nonce'?{raw:safeABI.encodeFunctionResult('nonce',[f2.nonce])+'00'.repeat(32)}:undefined;await assert.rejects(f2.capture,/Noncanonical Safe read/);
});

test('provider failures never expose raw RPC URLs, headers, credentials or provider objects',async()=>{
 const f=fixture();f.state.networkHook=()=>{throw{code:'NETWORK_ERROR',message:'https://secret:token@rpc',info:{headers:{authorization:'private'}}};};
 await assert.rejects(f.capture,error=>{assert.equal(error.code,'NETWORK_ERROR');assert.doesNotMatch(json(error),/secret|token|https|headers|private/);assert.equal(error.cause,undefined);return true;});
 const g=fixture(),{p,e}=await saved(g);assert.doesNotMatch(json({p,e}),/"provider"|"signer"|"headers"|"connection"/);assert.equal(e.ownerSignaturesVerified,false);
});

test('portable oracle setup supplies exact packet bytes and explicit metadata without runtime defaults',()=>{
 const f=setup('scoped','root',{chainId:(1n<<150n)+1n,nonce:(1n<<220n)+7n});assert.equal(f.packetText,f.text());assert.equal(f.expectedPacketSha256,sha(f.packetText));assert.equal(f.manifest.chainId,(1n<<150n)+1n);assert.equal(f.packet.phase,'root');assert.equal(f.packet.unsigned.transaction.length,10);assert.equal(f.packet.unsigned.inner.operation,0n);assert.equal(f.packet.unsigned.transaction[8],ZA);assert.notEqual(f.expectedSafeTxHash,Z);
});
