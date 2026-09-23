/**
 * Explicit RPC driver for admitted preservation deployments. Import this module; it never
 * constructs a provider, loads keys, starts a server, mines, signs or submits on import.
 *
 * const driver = createPreservationCallerHarness({ provider, manifest });
 * const plan = await driver.captureScenario(scenario);
 * await driver.simulateScenario(plan.id, { blockTag: scenario.blockTag });
 * const saved = await driver.saveSignedEnvelope(plan.id, reviewedEnvelope);
 * // Explicit caller authorization/submission seam; signer setup lives outside this module:
 * const attempt = await driver.submitSavedEnvelope(saved.id,
 *   { sendTransaction: tx => reviewedSigner.sendTransaction(tx) },
 *   { blockTag: preflightBlock, gasLimit: outerGas });
 * const observed = await driver.inspectSubmission(saved.id, attempt.transactionHash);
 *
 * A saved Safe envelope is the full signed execTransaction calldata, NOT a signed Ethereum
 * transaction. An outer revert consumes the submitting EOA's nonce; retry needs a new outer
 * transaction while preserving the exact Safe calldata/signatures and Safe nonce.
 * Manifest source/runtime/linked-closure admission remains an explicit reviewed input.
 * saveSignedEnvelope returns a frozen serializable record; the caller owns durable storage.
 * It does not sign, validate the owner signatures, or restore captures after process restart.
 * Retry eligibility reports the observed Safe nonce only; fresh execution remains decisive.
 */
import { Interface, TypedDataEncoder, getAddress, keccak256, toUtf8Bytes } from 'ethers';
import * as output from '../dist/current-token-preservation-output-v2-workflow.js';
import * as snapshot from '../dist/current-token-preservation-snapshot-v2-workflow.js';
import * as reference from '../dist/current-token-preservation-reference-v2-workflow.js';
import * as inventory from '../dist/current-authority-preservation-inventory-v1-workflow.js';
import * as archive from '../dist/current-authority-preservation-archive-v1-workflow.js';

const families = Object.freeze({
  output: [output.captureTokenPreservationOutputV2, output.simulateTokenPreservationOutputV2, output.reconcileTokenPreservationOutputV2Receipt],
  snapshot: [snapshot.captureTokenPreservationSnapshotV2, snapshot.simulateTokenPreservationSnapshotV2, snapshot.reconcileTokenPreservationSnapshotV2Receipt],
  reference: [reference.captureTokenPreservationReferenceV2, reference.simulateTokenPreservationReferenceV2, reference.reconcileTokenPreservationReferenceV2Receipt],
  inventory: [inventory.captureCurrentAuthorityPreservationInventoryV1, inventory.simulateCurrentAuthorityPreservationInventoryV1, inventory.reconcileCurrentAuthorityPreservationInventoryV1Receipt],
  archive: [archive.captureCurrentAuthorityPreservationArchiveV1, archive.simulateCurrentAuthorityPreservationArchiveV1, archive.reconcileCurrentAuthorityPreservationArchiveV1Receipt]
});
const safeABI = new Interface([
  'function nonce() view returns(uint256)', 'function VERSION() view returns(string)',
  'function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)',
  'function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)',
  'event ExecutionSuccess(bytes32 txHash,uint256 payment)', 'event ExecutionFailure(bytes32 txHash,uint256 payment)'
]);
const safeIndexed = new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)', 'event ExecutionFailure(bytes32 indexed txHash,uint256 payment)']);
const safeTypes = { SafeTx: [
  ['to','address'],['value','uint256'],['data','bytes'],['operation','uint8'],['safeTxGas','uint256'],['baseGas','uint256'],['gasPrice','uint256'],['gasToken','address'],['refundReceiver','address'],['nonce','uint256']
].map(([name,type])=>({name,type})) };
const MAX_CALL = 4 * 16777216 + 65536 + 16384;
const ZERO = '0x' + '00'.repeat(32);
const same = (a,b) => a === b;
function keys(value, required, optional=[]) {
  if (!value || typeof value!=='object' || Array.isArray(value) || Reflect.ownKeys(value).some(k=>typeof k!=='string'||![...required,...optional].includes(k)) || required.some(k=>!Object.hasOwn(value,k))) throw Error('Missing or unknown fields');
}
function address(v) { const result=getAddress(v).toLowerCase(); if (/^0x0{40}$/.test(result)) throw Error('Zero address'); return result; }
function hex(v,max=MAX_CALL) { if(typeof v!=='string'||!/^0x[0-9a-fA-F]*$/.test(v)||(v.length-2)%2||(v.length-2)/2>max) throw Error('Invalid or excessive bytes'); return v.toLowerCase(); }
function hash(v) { const result=hex(v,32);if(result.length!==66||result===ZERO)throw Error('Expected nonzero hash');return result; }
function uint(v) { if(typeof v!=='bigint'||v<0n||v>=1n<<256n)throw Error('Expected uint256 bigint');return v; }
function block(v) { if(!Number.isSafeInteger(v)||v<0)throw Error('Expected explicit nonnegative block number');return v; }
function gas(v) { if(uint(v)===0n)throw Error('Expected positive gas limit');return v; }
function freeze(v) { if(v&&typeof v==='object'){Object.values(v).forEach(freeze);Object.freeze(v);}return v; }
const owned = v => freeze(structuredClone(v));
function fingerprint(v) { return keccak256(toUtf8Bytes(JSON.stringify(v,(_,x)=>typeof x==='bigint'?{$bigint:x.toString()}:x))); }
function pin(v) {keys(v,['address','codeHash']);return{address:address(v.address),codeHash:hash(v.codeHash)};}
function capturedBlock(c) {const o=c.observed;return{blockNumber:block(o.blockNumber),blockHash:hash(o.blockHash),timestamp:uint(o.timestamp)};}
const compactCall = v => ({to:address(v.to),data:hex(v.data),value:uint(v.value)});
function receiptSnapshot(r) {
  if(!r)return null;
  if(!Array.isArray(r.logs)||r.logs.length>65536)throw Error('Receipt log limit');
  let bytes=0;
  const logs=r.logs.map(l=>{const data=hex(l.data,16777216);bytes+=(data.length-2)/2;if(bytes>16777216||!Array.isArray(l.topics)||l.topics.length>4)throw Error('Receipt log bound');return{address:address(l.address),data,topics:l.topics.map(t=>{const x=hex(t,32);if(x.length!==66)throw Error('Topic width');return x;}),index:block(l.index),transactionHash:hash(l.transactionHash),blockNumber:block(l.blockNumber),blockHash:hash(l.blockHash),removed:l.removed,transactionIndex:l.transactionIndex};});
  return owned({status:r.status,hash:hash(r.hash),from:address(r.from),to:address(r.to),blockNumber:block(r.blockNumber),blockHash:hash(r.blockHash),logs});
}
function txSnapshot(t) {return t?owned({hash:hash(t.hash),from:address(t.from),to:address(t.to),data:hex(t.data),value:uint(t.value),chainId:uint(t.chainId),blockNumber:block(t.blockNumber),blockHash:hash(t.blockHash)}):null;}

// Never retain ethers error/info/cause/request objects: they can contain RPC credentials.
const failureCodes = new Set(['CALL_EXCEPTION','NETWORK_ERROR','SERVER_ERROR','TIMEOUT','UNKNOWN_ERROR','OFFCHAIN_FAULT','ACTION_REJECTED','INSUFFICIENT_FUNDS','NONCE_EXPIRED','REPLACEMENT_UNDERPRICED','TRANSACTION_REPLACED']);
const transportFailures = new WeakMap();
function failureSummary(error) {
  if(error&&typeof error==='object'&&transportFailures.has(error))return transportFailures.get(error);
  const code=failureCodes.has(error?.code)?error.code:'UNKNOWN_ERROR';
  const data=typeof error?.data==='string'&&/^0x[0-9a-fA-F]*$/.test(error.data)&&error.data.length%2===0&&error.data.length<=8194?error.data.toLowerCase():null;
  return owned({kind:code==='CALL_EXCEPTION'?'execution-reverted':'transport-failed',code,data,
    reason:code==='CALL_EXCEPTION'&&(error?.reason==='GS013'||error?.revert?.args?.[0]==='GS013')?'GS013':null});
}
async function transportCall(operation) {
  try{return await operation();}catch(error){const summary=failureSummary(error),safe=new Error(summary.kind==='execution-reverted'?'Original call reverted':'RPC transport failed');
    safe.name='PreservationTransportError';safe.code=summary.code;safe.summary=summary;safe.data=summary.data;safe.reason=summary.reason;transportFailures.set(safe,summary);throw safe;}
}

/** Ethers Provider-compatible fixed-block adapter. No signing or submission capability. */
export function createPreservationRpcAdapter(provider) {
  for(const method of ['getNetwork','getBlock','getCode','call','getTransaction','getTransactionReceipt'])if(typeof provider?.[method]!=='function')throw Error('Missing provider method '+method);
  return Object.freeze({
    getNetwork:()=>transportCall(()=>provider.getNetwork()), getBlock:tag=>{const n=block(tag);return transportCall(()=>provider.getBlock(n));},
    getCode:(a,tag)=>{const target=getAddress(address(a)),n=block(tag);return transportCall(()=>provider.getCode(target,n));},
    call:tx=>{const request=owned({...tx,blockTag:block(tx.blockTag)});return transportCall(()=>provider.call(request));},
    getTransaction:async h=>{const id=hash(h);return txSnapshot(await transportCall(()=>provider.getTransaction(id)));},
    getTransactionReceipt:async h=>{const id=hash(h);return receiptSnapshot(await transportCall(()=>provider.getTransactionReceipt(id)));},
    getStorage:(a,slot,tag)=>{if(typeof provider.getStorage!=='function')throw Error('Safe proxy requires provider.getStorage');const target=address(a),n=block(tag);return transportCall(()=>provider.getStorage(target,slot,n));}
  });
}

/** JSON roundtrip for public call/evidence objects only; never pass signer/private-key objects. */
export function preservationHarnessJSON(value) {
  const forbidden=/^(provider|signer|privatekey|mnemonic|password|secret|credentials?|apikey|authorization|headers?|connection|url|rpcurl|message|stack|cause|info)$/i;
  const ancestors=new Set();
  function validate(v){if(v===null||['string','boolean','number','bigint','undefined'].includes(typeof v))return;
    if(typeof v!=='object'||(!Array.isArray(v)&&Object.getPrototypeOf(v)!==Object.prototype&&Object.getPrototypeOf(v)!==null))throw Error('Only public plain evidence can be serialized');
    if(ancestors.has(v))throw Error('Cyclic evidence cannot be serialized');ancestors.add(v);
    for(const k of Reflect.ownKeys(v)){if(k==='length'&&Array.isArray(v))continue;const descriptor=Object.getOwnPropertyDescriptor(v,k);
      if(typeof k!=='string'||forbidden.test(k)||!descriptor||!('value'in descriptor))throw Error('Private or error/connection metadata cannot be serialized');validate(descriptor.value);}ancestors.delete(v);}
  validate(value);return JSON.stringify(value,(_,v)=>typeof v==='bigint'?{$bigint:v.toString()}:v,2);
}
export const parsePreservationHarnessJSON = text => JSON.parse(text,(_,v)=>v&&typeof v==='object'&&Object.keys(v).length===1&&typeof v.$bigint==='string'&&/^(0|[1-9][0-9]*)$/.test(v.$bigint)?BigInt(v.$bigint):v);

/**
 * @param {{provider: import('ethers').Provider, manifest: {
 * schemaVersion: 1, chainId: bigint, sourceCommit: string, clientCommit: string,
 * deployments: Record<string,{family:'output'|'snapshot'|'reference'|'inventory'|'archive',deployment:object}>,
 * safes: readonly {address:string,codeHash:string,version:'1.3.0'|'1.4.1',singleton:{address:string,codeHash:string}}[]
 * }}} input Reviewed deployed addresses/pins, never inferred from placeholder defaults.
 */
export function createPreservationCallerHarness({provider,manifest: supplied}) {
  const manifest=owned(supplied);keys(manifest,['schemaVersion','chainId','sourceCommit','clientCommit','deployments','safes']);
  if(manifest.schemaVersion!==1||uint(manifest.chainId)===0n||![manifest.sourceCommit,manifest.clientCommit].every(v=>typeof v==='string'&&/^[a-f0-9]{40}$/.test(v)))throw Error('Explicit source/client/chain manifest required');
  if(!manifest.deployments||Array.isArray(manifest.deployments)||Object.keys(manifest.deployments).length===0)throw Error('Explicit admitted deployments required');
  for(const [name,v]of Object.entries(manifest.deployments)){keys(v,['family','deployment']);if(!name||name.length>128||!Object.hasOwn(families,v.family)||v.deployment?.chainId!==manifest.chainId)throw Error('Unsupported deployment family/chain');}
  if(!Array.isArray(manifest.safes)||manifest.safes.length>256)throw Error('Invalid Safe inventory');
  const safes=new Map();for(const s of manifest.safes){keys(s,['address','codeHash','version','singleton']);if(!['1.3.0','1.4.1'].includes(s.version))throw Error('Unsupported reviewed Safe version');const p=pin({address:s.address,codeHash:s.codeHash});if(safes.has(p.address))throw Error('Duplicate Safe');safes.set(p.address,{...p,version:s.version,singleton:pin(s.singleton)});}
  const rpc=createPreservationRpcAdapter(provider),plans=new Map(),envelopes=new Map(),savedByPlan=new Map();
  const getPlan=id=>{const p=plans.get(hash(id));if(!p)throw Error('Unknown captured plan');return p;};
  const getEnvelope=id=>{const e=envelopes.get(hash(id));if(!e)throw Error('Unknown saved envelope');return e;};
  async function header(tag) {if((await rpc.getNetwork()).chainId!==manifest.chainId)throw Error('RPC chain differs');const h=await rpc.getBlock(tag);if(!h||h.number!==tag)throw Error('Missing block');return owned({blockNumber:tag,blockHash:hash(h.hash),timestamp:BigInt(block(h.timestamp))});}
  async function unchanged(h) {const now=await header(h.blockNumber);if(fingerprint(now)!==fingerprint(h))throw Error('Observed block changed');}
  async function readSafe(a,name,args,tag) {const data=safeABI.encodeFunctionData(name,args),raw=hex(await rpc.call({to:a,data,blockTag:tag}));const result=safeABI.decodeFunctionResult(name,raw);if(safeABI.encodeFunctionResult(name,result).toLowerCase()!==raw)throw Error('Noncanonical Safe response');return result[0];}
  async function observeSafe(a,tag) {
    const s=safes.get(address(a));if(!s)throw Error('Safe missing from reviewed manifest');
    for(const p of [s,s.singleton]){const code=hex(await rpc.getCode(p.address,tag),131072);if(code==='0x'||keccak256(code)!==p.codeHash)throw Error('Safe runtime differs');}
    const slot=hex(await rpc.getStorage(a,0,tag),32);if(slot!==`0x${'00'.repeat(12)}${s.singleton.address.slice(2)}`)throw Error('Safe singleton differs');
    if(await readSafe(a,'VERSION',[],tag)!==s.version)throw Error('Safe version differs');
    return owned({address:s.address,version:s.version,nonce:uint(await readSafe(a,'nonce',[],tag)),codeHash:s.codeHash,singleton:s.singleton});
  }
  function safeFields(data,nonce) {const decoded=safeABI.decodeFunctionData('execTransaction',data);if(safeABI.encodeFunctionData('execTransaction',decoded).toLowerCase()!==data)throw Error('Noncanonical Safe envelope');return{to:decoded.to.toLowerCase(),value:decoded.value,data:decoded.data.toLowerCase(),operation:decoded.operation,safeTxGas:decoded.safeTxGas,baseGas:decoded.baseGas,gasPrice:decoded.gasPrice,gasToken:decoded.gasToken.toLowerCase(),refundReceiver:decoded.refundReceiver.toLowerCase(),nonce,signatures:decoded.signatures.toLowerCase()};}
  async function captureScenario(input) {
    const s=owned(input);keys(s,['deploymentId','caller','request','blockTag','gasLimit'],['segments']);const selected=manifest.deployments[s.deploymentId];if(!selected)throw Error('Unknown deployment');
    const tag=block(s.blockTag),limit=gas(s.gasLimit),caller=address(s.caller),family=selected.family;
    const options=family==='reference'?{blockTag:tag}:{blockTag:tag,gasLimit:limit};
    if(family==='inventory'||family==='archive'){if(!Array.isArray(s.segments))throw Error('Authenticated segment locators required');options.segments=s.segments;}else if(s.segments!==undefined)throw Error('Segments only apply to inventory/archive');
    const captured=await families[family][0](rpc,selected.deployment,caller,s.request,options),call=compactCall(captured.prepared.call);if(call.value!==0n||address(captured.prepared.caller)!==caller)throw Error('Captured CALL differs');
    const value={family,scenario:s,capture:captured,call,observed:capturedBlock(captured),sourceCommit:manifest.sourceCommit,clientCommit:manifest.clientCommit,deploymentProvenanceIndependentlyVerified:false};const id=fingerprint({family,deploymentId:s.deploymentId,captureHash:captured.captureHash,gasLimit:limit});const result=owned({id,...value});plans.set(id,result);return result;
  }
  async function simulateScenario(planId,options) {const p=getPlan(planId),o=owned(options);keys(o,['blockTag']);const tag=block(o.blockTag);if(tag<p.observed.blockNumber)throw Error('Simulation predates capture');return families[p.family][1](rpc,p.capture,['output','snapshot'].includes(p.family)?{blockTag:tag}:{blockTag:tag,gasLimit:p.scenario.gasLimit});}
  async function saveSignedEnvelope(planId,input) {
    const p=getPlan(planId),s=owned(input);if(savedByPlan.has(p.id))throw Error('Signed envelope already saved for this plan');
    let transaction,safe=null,expectedSafeTxHash=null,nonce=null,fields=null;
    if(s.execution==='direct'){keys(s,['execution']);transaction={...p.call,from:address(p.capture.prepared.caller)};}
    else if(s.execution==='safe'){
      keys(s,['execution','outerSender','data','nonce','expectedSafeTxHash']);nonce=uint(s.nonce);expectedSafeTxHash=hash(s.expectedSafeTxHash);const data=hex(s.data),target=address(p.capture.prepared.caller);fields=safeFields(data,nonce);
      if(fields.operation!==0n||fields.to!==p.call.to||fields.value!==p.call.value||fields.data!==p.call.data||fields.signatures==='0x')throw Error('Signed Safe inner CALL differs or lacks signatures');
      safe=await observeSafe(target,p.observed.blockNumber);if(safe.nonce!==nonce)throw Error('Signed Safe nonce differs');
      const {signatures,...message}=fields;void signatures;const localHash=TypedDataEncoder.hash({chainId:manifest.chainId,verifyingContract:target},safeTypes,message).toLowerCase();
      const originalHash=await readSafe(target,'getTransactionHash',[fields.to,fields.value,fields.data,fields.operation,fields.safeTxGas,fields.baseGas,fields.gasPrice,fields.gasToken,fields.refundReceiver,nonce],p.observed.blockNumber);
      if(localHash!==expectedSafeTxHash||originalHash.toLowerCase()!==expectedSafeTxHash)throw Error('Independent Safe hash differs');
      transaction={from:address(s.outerSender),to:target,value:0n,data};
    }else throw Error('Unsupported execution transport');
    await unchanged(p.observed);if(savedByPlan.has(p.id))throw Error('Signed envelope already saved for this plan');
    const value={planId:p.id,execution:s.execution,transaction,safe,nonce,expectedSafeTxHash,fields,innerCallHash:keccak256(p.call.data),signedEnvelopeHash:keccak256(transaction.data)};
    const id=fingerprint({planId:p.id,execution:s.execution,from:transaction.from,to:transaction.to,value:transaction.value,
      signedEnvelopeHash:value.signedEnvelopeHash,innerCallHash:value.innerCallHash,nonce,expectedSafeTxHash});
    const result=owned({id,...value});envelopes.set(id,result);savedByPlan.set(p.id,id);return result;
  }
  async function preflight(e,tag) {const p=getPlan(e.planId);if(tag<p.observed.blockNumber)throw Error('Submission predates capture');await unchanged(p.observed);const h=await header(tag);if(e.safe&&(await observeSafe(e.safe.address,tag)).nonce!==e.nonce)throw Error('Safe nonce consumed or changed; saved signatures cannot be retried');return h;}
  async function simulateSavedEnvelope(envelopeId,options) {
    const e=getEnvelope(envelopeId),o=owned(options);keys(o,['blockTag','gasLimit']);const tag=block(o.blockTag),limit=gas(o.gasLimit),h=await preflight(e,tag);let result=null,error=null;
    try {result=hex(await rpc.call({...e.transaction,gasLimit:limit,blockTag:tag}));if(e.safe){const decoded=safeABI.decodeFunctionResult('execTransaction',result);if(safeABI.encodeFunctionResult('execTransaction',decoded).toLowerCase()!==result)throw Error('Noncanonical Safe return');result=decoded[0];}}catch(failure){error=failureSummary(failure);}
    await unchanged(h);return owned({observed:h,result,error,originalCallSucceeded:error===null,safeInnerSucceeded:e.safe&&error===null?result:null,stateChangesPersisted:false,gs013SimulationObserved:error?.reason==='GS013'});
  }
  /** The only submission seam. Caller explicitly supplies an authorized send transport. */
  async function submitSavedEnvelope(envelopeId,transport,options) {
    const e=getEnvelope(envelopeId),o=owned(options);keys(o,['blockTag','gasLimit'],['nonce','gasPrice','maxFeePerGas','maxPriorityFeePerGas']);keys(transport,['sendTransaction']);if(typeof transport.sendTransaction!=='function')throw Error('Explicit send transport required');
    const send=transport.sendTransaction.bind(transport);
    const tag=block(o.blockTag),h=await preflight(e,tag),tx={...e.transaction,chainId:manifest.chainId,gasLimit:gas(o.gasLimit)};
    for(const name of ['nonce','gasPrice','maxFeePerGas','maxPriorityFeePerGas'])if(o[name]!==undefined)tx[name]=uint(o[name]);
    if(o.gasPrice!==undefined&&(o.maxFeePerGas!==undefined||o.maxPriorityFeePerGas!==undefined))throw Error('Conflicting outer fee fields');await unchanged(h);
    const sent=await transportCall(()=>send(owned(tx)));return owned({envelopeId:e.id,transactionHash:hash(typeof sent==='string'?sent:sent.hash),preflight:h,signedEnvelopeHash:e.signedEnvelopeHash});
  }
  async function inspectSubmission(envelopeId,inputHash) {
    const e=getEnvelope(envelopeId),p=getPlan(e.planId),txHash=hash(inputHash),receipt=await rpc.getTransactionReceipt(txHash),transaction=await rpc.getTransaction(txHash);
    if(!receipt||!transaction||![0,1].includes(receipt.status)||receipt.hash!==txHash||transaction.hash!==txHash||transaction.chainId!==manifest.chainId)throw Error('Missing or invalid mined transaction');
    const n=receipt.blockNumber;if(n<=p.observed.blockNumber)throw Error('Receipt must be later than capture');
    for(const field of ['from','to','data','value'])if(!same(transaction[field],e.transaction[field]))throw Error('Mined saved envelope differs');
    if(receipt.from!==transaction.from||receipt.to!==transaction.to||receipt.blockHash!==transaction.blockHash||n!==transaction.blockNumber)throw Error('Receipt identity differs');
    await unchanged(p.observed);const prior=await header(n-1),end=await header(n);if(end.blockHash!==receipt.blockHash)throw Error('Receipt block changed');
    let last=-1;for(const l of receipt.logs){if(l.removed!==false||l.transactionHash!==txHash||l.blockNumber!==n||l.blockHash!==end.blockHash||l.index<=last)throw Error('Receipt log identity/order differs');last=l.index;}
    if(receipt.status===0&&receipt.logs.length)throw Error('Reverted transaction cannot retain logs');
    let nonceBefore=null,nonceAfter=null,outcome,reconciled=null;
    if(e.safe){nonceBefore=(await observeSafe(e.safe.address,n-1)).nonce;nonceAfter=(await observeSafe(e.safe.address,n)).nonce;if(nonceBefore!==e.nonce)throw Error('Prior Safe nonce differs');
      const events=receipt.logs.filter(l=>l.address===e.safe.address&&['ExecutionSuccess','ExecutionFailure'].some(name=>safeABI.getEvent(name).topicHash===l.topics[0])).map(l=>{const iface=l.topics.length===2?safeIndexed:safeABI;const parsed=iface.parseLog(l);const encoded=iface.encodeEventLog(parsed.fragment,parsed.args);if(encoded.data.toLowerCase()!==l.data||JSON.stringify(encoded.topics.map(x=>x.toLowerCase()))!==JSON.stringify(l.topics)||parsed.args.txHash.toLowerCase()!==e.expectedSafeTxHash)throw Error('Safe event hash/encoding differs');return{name:parsed.name,index:l.index};});
      if(receipt.status===0){if(receipt.logs.length||events.length||nonceAfter!==nonceBefore)throw Error('Reverted Safe attribution differs');outcome='safe-outer-reverted';}
      else {if(events.length!==1||nonceAfter!==nonceBefore+1n)throw Error('Safe nonce/event attribution differs');outcome=events[0].name==='ExecutionFailure'?'safe-execution-failure':'success';
        if(outcome==='safe-execution-failure'&&e.fields.safeTxGas===0n&&e.fields.gasPrice===0n)throw Error('Impossible failure event for GS013 gas mode');
      }
    }else outcome=receipt.status===1?'success':'direct-outer-reverted';
    if(outcome==='success')reconciled=await families[p.family][2](rpc,p.capture,txHash,e.safe?{execution:'safe',expectedSafeTxHash:e.expectedSafeTxHash}:{execution:'direct'});
    await unchanged(prior);await unchanged(end);
    return owned({transactionHash:txHash,envelopeId:e.id,outcome,observations:{capture:p.observed,prior,end,nonceBefore,nonceAfter},reconciled,
      signedEnvelopeHash:e.signedEnvelopeHash,safeSignaturesRetryable:outcome==='safe-outer-reverted'&&nonceBefore===nonceAfter,
      zeroGasGs013Compatible:outcome==='safe-outer-reverted'&&e.fields.safeTxGas===0n&&e.fields.baseGas===0n&&e.fields.gasPrice===0n,
      gs013ReceiptCauseProven:false,rollbackIndependentlyProven:false});
  }
  return Object.freeze({captureScenario,simulateScenario,saveSignedEnvelope,simulateSavedEnvelope,submitSavedEnvelope,inspectSubmission});
}
