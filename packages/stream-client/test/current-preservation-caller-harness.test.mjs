// Unit tests use compiler-backed mock RPC fixtures. These are adapter/dispatch/envelope
// checks, not actual native, deployed Safe, signature, GS013 or rollback evidence.
import test from 'node:test';
import assert from 'node:assert/strict';
import { Interface,TypedDataEncoder,keccak256,getAddress } from 'ethers';
import { createPreservationCallerHarness,createPreservationRpcAdapter,preservationHarnessJSON,parsePreservationHarnessJSON } from '../examples/current-preservation-caller-harness.mjs';
import { setup as outputSetup,A,H,Z,ZA } from './current-token-preservation-output-v2-workflow-fixture.mjs';
import { setup as snapshotSetup } from './current-token-preservation-snapshot-v2-workflow-fixture.mjs';
import { setup as referenceSetup } from './current-token-preservation-reference-v2-workflow-fixture.mjs';
import { setup as inventorySetup } from './current-authority-preservation-inventory-v1-workflow-fixture.mjs';
import { setup as archiveSetup } from './current-authority-preservation-archive-v1-workflow-fixture.mjs';
const source='a2973d360f6ab18881c04d58193f855704ec56d3',client='b4d9fd73fbcf458b410dff32b8d03ab8f7bd5882';
const safeABI=new Interface([
  'function nonce() view returns(uint256)', 'function VERSION() view returns(string)',
  'function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)',
  'function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)',
  'event ExecutionSuccess(bytes32 txHash,uint256 payment)','event ExecutionFailure(bytes32 txHash,uint256 payment)'
]);
const indexed=new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)','event ExecutionFailure(bytes32 indexed txHash,uint256 payment)']);
const types={SafeTx:[['to','address'],['value','uint256'],['data','bytes'],['operation','uint8'],['safeTxGas','uint256'],['baseGas','uint256'],['gasPrice','uint256'],['gasToken','address'],['refundReceiver','address'],['nonce','uint256']].map(([name,type])=>({name,type}))};
function setup(family='output',options={}){
  const f=family==='output'?outputSetup({method:'begin'}):family==='snapshot'?snapshotSetup():family==='reference'?referenceSetup():family==='inventory'?inventorySetup():archiveSetup();
  if(options.caller)f.caller=getAddress(options.caller);
  const request=family==='output'?f.request:family==='snapshot'?{kind:'publishSnapshot',publication:f.publication}:family==='reference'?{kind:'prepareFileInventory',rows:[],relative:true}:family==='inventory'?f.prepare('beginInventory'):f.request('beginCoverage');
  if(family==='reference')f.preparation(request);
  const blockTag=['inventory','archive'].includes(family)?90:10,N=blockTag===90?100:12,safeCode='0x60006000',singletonCode='0x60016000',singleton=A(9010),version=options.version??'1.4.1';
  const s={nonce:7n,endNonce:8n,block:N,outerError:null,outerResult:true,calls:[],singletonCode,safeCode,version,hashOverride:null,storage:null};
  const provider={...f.provider,
    async getCode(a,tag){if(a.toLowerCase()===f.caller.toLowerCase())return s.safeCode;if(a.toLowerCase()===singleton.toLowerCase())return s.singletonCode;return f.provider.getCode(a,tag);},
    async getStorage(a,slot,tag){assert.equal(a.toLowerCase(),f.caller.toLowerCase());assert.equal(slot,0);assert.ok(Number.isSafeInteger(tag));return s.storage??'0x'+'00'.repeat(12)+singleton.slice(2).toLowerCase();},
    async call(tx){if(tx.to.toLowerCase()!==f.caller.toLowerCase())return f.provider.call(tx);s.calls.push(structuredClone(tx));const parsed=safeABI.parseTransaction({data:tx.data});let result;
      if(parsed.name==='nonce')result=[tx.blockTag>=s.block?s.endNonce:s.nonce];else if(parsed.name==='VERSION')result=[s.version];
      else if(parsed.name==='getTransactionHash'){const values=Object.fromEntries(types.SafeTx.map((v,i)=>[v.name,parsed.args[i]]));result=[s.hashOverride??TypedDataEncoder.hash({chainId:1n,verifyingContract:f.caller},types,values)];}
      else if(parsed.name==='execTransaction'){if(s.outerError)throw s.outerError;result=[s.outerResult];}else throw Error('Unexpected mock Safe call');return safeABI.encodeFunctionResult(parsed.fragment,result);
    }
  };
  const manifest={schemaVersion:1,chainId:1n,sourceCommit:source,clientCommit:client,deployments:{actual:{family,deployment:f.d}},safes:[{address:f.caller,codeHash:keccak256(safeCode),version,singleton:{address:singleton,codeHash:keccak256(singletonCode)}}]};
  const driver=createPreservationCallerHarness({provider,manifest}),scenario={deploymentId:'actual',caller:f.caller,request,blockTag,gasLimit:50000000n,...(['inventory','archive'].includes(family)?{segments:f.options?f.options().segments:f.opts().segments}:{})};
  const receipt=t=>f.state?f.state.receipts.get(t.hash??t.txHash):f.receipt,transaction=t=>f.state?f.state.transactions.get(t.hash??t.txHash):f.transaction;
  function envelope(plan,changes={}){const fields={to:plan.call.to,value:0n,data:plan.call.data,operation:0n,safeTxGas:0n,baseGas:0n,gasPrice:0n,gasToken:ZA,refundReceiver:ZA,nonce:s.nonce,...changes};return{execution:'safe',outerSender:A(91),nonce:fields.nonce,expectedSafeTxHash:TypedDataEncoder.hash({chainId:1n,verifyingContract:f.caller},types,fields),data:safeABI.encodeFunctionData('execTransaction',[fields.to,fields.value,fields.data,fields.operation,fields.safeTxGas,fields.baseGas,fields.gasPrice,fields.gasToken,fields.refundReceiver,'0x1234'])};}
  function mine(plan,saved=null,mode='legacy',outcome='success'){
    const t=f.mine(plan.capture,saved?mode:'direct'),r=receipt(t),tx=transaction(t),hash=t.hash??t.txHash;s.block=r.blockNumber;
    if(saved){Object.assign(tx,{from:saved.transaction.from,to:saved.transaction.to,data:saved.transaction.data,value:saved.transaction.value});Object.assign(r,{from:tx.from,to:tx.to});const eventInterface=mode==='indexed'?indexed:safeABI;
      const log=r.logs.at(-1),encoded=eventInterface.encodeEventLog(outcome==='failure'?'ExecutionFailure':'ExecutionSuccess',[saved.expectedSafeTxHash,0n]);Object.assign(log,encoded);
      if(outcome==='revert'){r.status=0;r.logs=[];s.endNonce=s.nonce;}else s.endNonce=s.nonce+1n;
    }
    return{...t,hash};
  }
  return{f,s,manifest,driver,scenario,provider,envelope,mine,receipt,transaction,N};
}

test('closed five-family driver calls actual capture/simulate/reconciler exports with mock RPC facts',async()=>{
  for(const family of ['output','snapshot','reference','inventory','archive']){const x=setup(family),p=await x.driver.captureScenario(x.scenario);await x.driver.simulateScenario(p.id,{blockTag:x.scenario.blockTag+1});const saved=await x.driver.saveSignedEnvelope(p.id,{execution:'direct'}),t=x.mine(p),r=await x.driver.inspectSubmission(saved.id,t.hash);
    assert.equal(r.outcome,'success');assert.ok(r.reconciled);assert.equal(r.observations.capture.blockNumber,x.scenario.blockTag);assert.equal(r.observations.prior.blockNumber,r.observations.end.blockNumber-1);assert.equal(r.gs013ReceiptCauseProven,false);
  }
});

test('real adapter forwards fixed ethers call/getCode/getBlock methods without owning transport',async()=>{
  const x=setup(),adapter=createPreservationRpcAdapter(x.provider);assert.equal((await adapter.getNetwork()).chainId,1n);assert.equal((await adapter.getBlock(10)).number,10);assert.equal(await adapter.getCode(x.f.caller,10),x.s.safeCode);
  assert.equal(await adapter.call({to:x.f.caller,data:safeABI.encodeFunctionData('nonce'),blockTag:10}),safeABI.encodeFunctionResult('nonce',[7n]));assert.equal('sendTransaction'in adapter,false);await assert.rejects(async()=>adapter.call({to:x.f.caller,data:'0x',blockTag:'latest'}),/explicit/);
});

test('Safe1.3 and1.4 canonical signed envelopes reconcile both event layouts through the original client',async()=>{
  for(const version of ['1.3.0','1.4.1'])for(const layout of ['legacy','indexed']){const x=setup('output',{version}),p=await x.driver.captureScenario(x.scenario),s=await x.driver.saveSignedEnvelope(p.id,x.envelope(p)),t=x.mine(p,s,layout),r=await x.driver.inspectSubmission(s.id,t.hash);assert.equal(r.outcome,'success');assert.equal(r.observations.nonceAfter,8n);assert.equal(r.safeSignaturesRetryable,false);assert.ok(r.reconciled);}
});

test('save once preserves exact Safe bytes; wrong inner CALL, signatures, independent hash or nonce rejects',async()=>{
  const x=setup(),p=await x.driver.captureScenario(x.scenario),valid=x.envelope(p);
  for(const fields of [{operation:1n},{to:A(991)},{value:1n},{data:'0x1234'}])await assert.rejects(x.driver.saveSignedEnvelope(p.id,x.envelope(p,fields)),/inner CALL/);
  const empty=[...safeABI.decodeFunctionData('execTransaction',valid.data)];empty[9]='0x';await assert.rejects(x.driver.saveSignedEnvelope(p.id,{...valid,data:safeABI.encodeFunctionData('execTransaction',empty)}),/lacks signatures/);
  await assert.rejects(x.driver.saveSignedEnvelope(p.id,{...valid,expectedSafeTxHash:H(992)}),/hash/);await assert.rejects(x.driver.saveSignedEnvelope(p.id,x.envelope(p,{nonce:8n})),/nonce/);
  const s=await x.driver.saveSignedEnvelope(p.id,valid);assert.equal(s.transaction.data,valid.data.toLowerCase());valid.data='0x';assert.notEqual(s.transaction.data,valid.data);await assert.rejects(x.driver.saveSignedEnvelope(p.id,x.envelope(p)),/already saved/);assert.throws(()=>{s.transaction.data='0x';},TypeError);
});

test('all-zero gas outer revert allows explicit same-Safe-bytes retry with a fresh relayer nonce',async()=>{
  const x=setup(),p=await x.driver.captureScenario(x.scenario),s=await x.driver.saveSignedEnvelope(p.id,x.envelope(p)),sent=[];
  const transport={async sendTransaction(tx){sent.push(tx);return{hash:H(801+sent.length)};}};
  const first=await x.driver.submitSavedEnvelope(s.id,transport,{blockTag:11,gasLimit:9000000n,nonce:41n});assert.equal(first.signedEnvelopeHash,s.signedEnvelopeHash);
  const t=x.mine(p,s,'legacy','revert'),r=await x.driver.inspectSubmission(s.id,t.hash);assert.equal(r.outcome,'safe-outer-reverted');assert.equal(r.safeSignaturesRetryable,true);assert.equal(r.zeroGasGs013Compatible,true);assert.equal(r.gs013ReceiptCauseProven,false);assert.equal(r.reconciled,null);
  await x.driver.submitSavedEnvelope(s.id,transport,{blockTag:12,gasLimit:11000000n,nonce:42n});assert.equal(sent[0].data,sent[1].data);assert.equal(sent[0].to,sent[1].to);assert.notEqual(sent[0].nonce,sent[1].nonce);assert.equal(sent.length,2);
});

test('nonzero safeTxGas ExecutionFailure consumes Safe nonce and refuses resubmitting old signatures',async()=>{
  const x=setup(),p=await x.driver.captureScenario(x.scenario),s=await x.driver.saveSignedEnvelope(p.id,x.envelope(p,{safeTxGas:3000000n})),t=x.mine(p,s,'indexed','failure'),r=await x.driver.inspectSubmission(s.id,t.hash);assert.equal(r.outcome,'safe-execution-failure');assert.equal(r.observations.nonceAfter,r.observations.nonceBefore+1n);assert.equal(r.safeSignaturesRetryable,false);assert.equal(r.reconciled,null);
  let sends=0;await assert.rejects(x.driver.submitSavedEnvelope(s.id,{sendTransaction:async()=>{sends++;return H(810);}},{blockTag:12,gasLimit:9000000n}),/nonce consumed/);assert.equal(sends,0);
});

test('GS013 is only simulation evidence; RPC errors and boolean false remain distinct',async()=>{
  const x=setup(),p=await x.driver.captureScenario(x.scenario),s=await x.driver.saveSignedEnvelope(p.id,x.envelope(p));x.s.outerError=Object.assign(Error('GS013'),{code:'CALL_EXCEPTION',reason:'GS013'});
  const r=await x.driver.simulateSavedEnvelope(s.id,{blockTag:11,gasLimit:10000000n});assert.equal(r.gs013SimulationObserved,true);assert.deepEqual(r.error,{kind:'execution-reverted',code:'CALL_EXCEPTION',data:null,reason:'GS013'});assert.equal(r.safeInnerSucceeded,null);assert.equal(r.stateChangesPersisted,false);
  x.s.outerError=Object.assign(Error('transport'),{code:'NETWORK_ERROR'});const failed=await x.driver.simulateSavedEnvelope(s.id,{blockTag:11,gasLimit:10000000n});assert.equal(failed.gs013SimulationObserved,false);assert.equal(failed.error.kind,'transport-failed');
  const y=setup(),yp=await y.driver.captureScenario(y.scenario),ys=await y.driver.saveSignedEnvelope(yp.id,y.envelope(yp,{safeTxGas:3000000n}));y.s.outerResult=false;const f=await y.driver.simulateSavedEnvelope(ys.id,{blockTag:11,gasLimit:10000000n});assert.equal(f.originalCallSucceeded,true);assert.equal(f.safeInnerSucceeded,false);
});

test('checksummed callers and Safe targets retain identical address identity across receipts',async()=>{
  const caller='0x000000000000000000000000000000000000aBcD';
  for(const execution of ['direct','safe']){const x=setup('output',{caller:caller.toLowerCase()}),p=await x.driver.captureScenario(x.scenario);assert.notEqual(p.capture.prepared.caller,p.capture.prepared.caller.toLowerCase());
    const s=await x.driver.saveSignedEnvelope(p.id,execution==='safe'?x.envelope(p):{execution}),t=x.mine(p,execution==='safe'?s:null);assert.equal((await x.driver.inspectSubmission(s.id,t.hash)).outcome,'success');}
});

test('transport failures are sanitized and evidence serialization refuses raw errors or connections',async()=>{
  const x=setup(),p=await x.driver.captureScenario(x.scenario),s=await x.driver.saveSignedEnvelope(p.id,x.envelope(p));
  const secret='fake-credential-for-redaction-test',raw=Object.assign(Error('https://rpc.invalid/'+secret),{code:'SERVER_ERROR',info:{headers:{authorization:secret}},cause:{url:secret},name:'PreservationTransportError',summary:{secret}});
  x.s.outerError=raw;const result=await x.driver.simulateSavedEnvelope(s.id,{blockTag:11,gasLimit:10000000n});assert.equal(result.error.kind,'transport-failed');assert.equal(preservationHarnessJSON(result).includes(secret),false);
  await assert.rejects(x.driver.submitSavedEnvelope(s.id,{sendTransaction:async()=>{throw raw;}},{blockTag:11,gasLimit:10000000n}),e=>{assert.equal(String(e).includes(secret),false);assert.equal(JSON.stringify(e).includes(secret),false);assert.equal(e.cause,undefined);return e.code==='SERVER_ERROR';});
  for(const value of [raw,{error:raw},{connection:{url:secret}},{provider:x.provider}])assert.throws(()=>preservationHarnessJSON(value),/public|metadata/);
  const provider={...x.provider,getNetwork:async()=>{throw raw;}};await assert.rejects(createPreservationCallerHarness({provider,manifest:x.manifest}).captureScenario(x.scenario),e=>!JSON.stringify(e).includes(secret)&&e.code==='SERVER_ERROR');
});

test('direct status-zero receipts cannot retain logs or assert GS013 causality',async()=>{
  const x=setup(),p=await x.driver.captureScenario(x.scenario),s=await x.driver.saveSignedEnvelope(p.id,{execution:'direct'}),t=x.mine(p);x.receipt(t).status=0;
  await assert.rejects(x.driver.inspectSubmission(s.id,t.hash),/cannot retain logs/);x.receipt(t).logs=[];const r=await x.driver.inspectSubmission(s.id,t.hash);assert.equal(r.outcome,'direct-outer-reverted');assert.equal(r.gs013ReceiptCauseProven,false);assert.equal(r.safeSignaturesRetryable,false);
});

test('no fake GS013 failure event, nonce drift, copied event, changed envelope or earlier receipt is accepted',async()=>{
  const x=setup(),p=await x.driver.captureScenario(x.scenario),s=await x.driver.saveSignedEnvelope(p.id,x.envelope(p)),t=x.mine(p,s,'legacy','failure');await assert.rejects(x.driver.inspectSubmission(s.id,t.hash),/Impossible/);
  x.mine(p,s);x.s.endNonce=9n;await assert.rejects(x.driver.inspectSubmission(s.id,t.hash),/nonce\/event/);x.s.endNonce=8n;
  x.transaction(t).data='0x';await assert.rejects(x.driver.inspectSubmission(s.id,t.hash),/envelope/);x.mine(p,s);x.receipt(t).logs.at(-1).transactionHash=H(999);await assert.rejects(x.driver.inspectSubmission(s.id,t.hash),/log identity/);
  x.mine(p,s);x.receipt(t).blockNumber=10;await assert.rejects(x.driver.inspectSubmission(s.id,t.hash),/later than capture/);
});

test('reviewed Safe proxy/singleton/version and network identity are checked at fixed blocks',async()=>{
  const x=setup(),p=await x.driver.captureScenario(x.scenario),e=x.envelope(p);
  x.s.singletonCode='0x6002';await assert.rejects(x.driver.saveSignedEnvelope(p.id,e),/runtime/);x.s.singletonCode='0x60016000';x.s.storage=Z;await assert.rejects(x.driver.saveSignedEnvelope(p.id,e),/singleton/);x.s.storage=null;x.s.version='1.2.0';await assert.rejects(x.driver.saveSignedEnvelope(p.id,e),/version/);
  x.s.version='1.4.1';x.provider.getNetwork=async()=>({chainId:2n});await assert.rejects(x.driver.saveSignedEnvelope(p.id,e),/chain differs/);
});

test('saved capture reorgs are refused and RPC logs are copied before subsequent provider awaits',async()=>{
  const x=setup(),p=await x.driver.captureScenario(x.scenario),s=await x.driver.saveSignedEnvelope(p.id,x.envelope(p,{safeTxGas:3000000n})),t=x.mine(p,s,'legacy','failure');
  const originalGet=x.provider.getTransaction;x.provider.getTransaction=async hash=>{x.receipt(t).logs.at(-1).transactionHash=H(9876);return originalGet(hash);};
  assert.equal((await x.driver.inspectSubmission(s.id,t.hash)).outcome,'safe-execution-failure');
  const originalBlock=x.provider.getBlock;x.provider.getBlock=async tag=>{const result=await originalBlock(tag);return tag===10?{...result,hash:H(9877)}:result;};
  await assert.rejects(x.driver.submitSavedEnvelope(s.id,{sendTransaction:async()=>{throw Error('must not submit');}},{blockTag:12,gasLimit:9000000n}),/Observed block changed/);
});

test('manifest/scenario/saved-envelope inputs are owned before provider awaits; unknown domains are closed',async()=>{
  const x=setup(),scenario=structuredClone(x.scenario);x.f.networkHook=()=>{scenario.request.selectionId=H(911);scenario.blockTag=11;};const p=await x.driver.captureScenario(scenario);assert.equal(p.observed.blockNumber,10);assert.equal(p.call.data,p.capture.prepared.call.data);
  assert.throws(()=>createPreservationCallerHarness({provider:x.provider,manifest:{...x.manifest,deployments:{bad:{family:'view',deployment:x.f.d}}}}),/Unsupported/);
  await assert.rejects(x.driver.captureScenario({...x.scenario,deploymentId:'missing'}),/Unknown/);await assert.rejects(x.driver.captureScenario({...x.scenario,segments:[]}),/Segments/);
  const encoded=preservationHarnessJSON(p),decoded=parsePreservationHarnessJSON(encoded);assert.equal(decoded.scenario.gasLimit,50000000n);assert.equal(decoded.call.data,p.call.data);
});

test('explicit send seam permits only outer transport fields, never call overrides or automatic submission',async()=>{
  const x=setup(),p=await x.driver.captureScenario(x.scenario),s=await x.driver.saveSignedEnvelope(p.id,{execution:'direct'});let sent=0;const transport={async sendTransaction(tx){sent++;assert.equal(tx.data,p.call.data);assert.equal(tx.from,x.f.caller);return H(920);}};
  await assert.rejects(x.driver.submitSavedEnvelope(s.id,transport,{blockTag:11,gasLimit:10000000n,data:'0x'}),/unknown/);assert.equal(sent,0);
  const result=await x.driver.submitSavedEnvelope(s.id,transport,{blockTag:11,gasLimit:10000000n,maxFeePerGas:2n,maxPriorityFeePerGas:1n});assert.equal(result.transactionHash,H(920));assert.equal(sent,1);
});
