/**
 * Closed packet-to-Safe transport for the original op17/root interlude.
 * The caller supplies reviewed manifest metadata, a Provider and (only when submitting)
 * an explicit sendTransaction callback. No RPC endpoint, key, signer, mining or submission
 * is constructed here. Source/runtime provenance remains supplied metadata.
 *
 * Packet, captured Safe state and the complete signed execTransaction bytes are retained
 * in same-instance maps. Serialized records do not restore those maps. Actual protocol
 * consent/root receipt verification remains a separate Prepared-tool operation, even when
 * the Safe reports success. An observed unchanged nonce permits attempting the same Safe
 * signatures in a new outer transaction; it does not prove GS013 or a successful retry.
 */
import { Interface, TypedDataEncoder, getAddress, keccak256, toUtf8Bytes } from 'ethers';
import { createPreservationRpcAdapter } from './current-preservation-caller-harness.mjs';
import { preparePreservationRootInterludePacket } from './current-preservation-root-interlude-packet.mjs';

const safeABI = new Interface([
  'function nonce() view returns(uint256)', 'function VERSION() view returns(string)',
  'function getOwners() view returns(address[])', 'function getThreshold() view returns(uint256)',
  'function getTransactionHash(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) view returns(bytes32)',
  'function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns(bool success)',
  'event ExecutionSuccess(bytes32 txHash,uint256 payment)', 'event ExecutionFailure(bytes32 txHash,uint256 payment)'
]);
const indexedSafe = new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)', 'event ExecutionFailure(bytes32 indexed txHash,uint256 payment)']);
const names = ['to','value','data','operation','safeTxGas','baseGas','gasPrice','gasToken','refundReceiver','nonce'];
const types = { SafeTx: names.map((name,index)=>({ name,type:['address','uint256','bytes','uint8','uint256','uint256','uint256','address','address','uint256'][index] })) };
const ZERO = '0x'+'00'.repeat(32), MAX_BYTES=2_097_152, MAX_OUTER=MAX_BYTES+131_072;
const failureCodes = new Set(['CALL_EXCEPTION','NETWORK_ERROR','SERVER_ERROR','TIMEOUT','UNKNOWN_ERROR','OFFCHAIN_FAULT','ACTION_REJECTED','INSUFFICIENT_FUNDS','NONCE_EXPIRED','REPLACEMENT_UNDERPRICED','TRANSACTION_REPLACED']);
function keys(v, required, optional=[]) {
  if(!v||typeof v!=='object'||Array.isArray(v)||Reflect.ownKeys(v).some(k=>typeof k!=='string'||![...required,...optional].includes(k))||required.some(k=>!Object.hasOwn(v,k)))throw Error('Missing or unknown fields');
}
function hex(v,maximum=MAX_OUTER){if(typeof v!=='string'||!/^0x[0-9a-fA-F]*$/.test(v)||(v.length-2)%2||(v.length-2)/2>maximum)throw Error('Invalid or excessive bytes');return v.toLowerCase();}
function hash(v){const h=hex(v,32);if(h.length!==66||h===ZERO)throw Error('Expected nonzero hash');return h;}
function address(v,allowZero=false){const a=getAddress(v).toLowerCase();if(!allowZero&&/^0x0{40}$/.test(a))throw Error('Zero address');return a;}
function uint(v){if(typeof v!=='bigint'||v<0n||v>=1n<<256n)throw Error('Expected uint256 bigint');return v;}
function block(v){if(!Number.isSafeInteger(v)||v<0)throw Error('Expected explicit nonnegative block number');return v;}
function gas(v){if(uint(v)===0n||v>100_000_000n)throw Error('Outer gas exceeds client bound');return v;}
function freeze(v){if(v&&typeof v==='object'){Object.values(v).forEach(freeze);Object.freeze(v);}return v;}
const own=v=>freeze(structuredClone(v));
const fingerprint=v=>keccak256(toUtf8Bytes(JSON.stringify(v,(_,x)=>typeof x==='bigint'?{$bigint:x.toString()}:x)));
function equal(a,b,message){if(fingerprint(a)!==fingerprint(b))throw Error(message);}
function summary(error){const code=failureCodes.has(error?.code)?error.code:'UNKNOWN_ERROR';let data=null;try{if(typeof error?.data==='string')data=hex(error.data,4096);}catch{/* never retain raw provider error */}
 return own({kind:code==='CALL_EXCEPTION'?'execution-reverted':'transport-failed',code,data,reason:code==='CALL_EXCEPTION'&&(error?.reason==='GS013'||error?.revert?.args?.[0]==='GS013')?'GS013':null});}
async function sendSafely(send,tx){try{return await send(tx);}catch(error){const details=summary(error),safe=new Error('Explicit send transport failed');safe.name='PreservationRootInterludeTransportError';safe.code=details.code;safe.summary=details;throw safe;}}
function transactionFields(v){return{to:address(v.to),value:uint(v.value),data:hex(v.data,MAX_BYTES),operation:uint(v.operation),safeTxGas:uint(v.safeTxGas),baseGas:uint(v.baseGas),gasPrice:uint(v.gasPrice),gasToken:address(v.gasToken,true),refundReceiver:address(v.refundReceiver,true),nonce:uint(v.nonce)};}
function decodeEnvelope(data,nonce){let parsed;try{parsed=safeABI.decodeFunctionData('execTransaction',data);}catch{throw Error('Expected direct Safe execTransaction calldata');}
 if(safeABI.encodeFunctionData('execTransaction',parsed).toLowerCase()!==data)throw Error('Noncanonical signed Safe envelope');
 const fields=transactionFields({...Object.fromEntries(names.slice(0,9).map(name=>[name,parsed[name]])),nonce});
 const signatures=hex(parsed.signatures,65536);if(signatures==='0x')throw Error('Supplied owner signatures required');return{fields,signatures};}

export function createPreservationRootInterludeTransport({provider,manifest: suppliedManifest}) {
  const detached=structuredClone(suppliedManifest);
  if(typeof detached.chainId==='string'&&/^[0-9]{1,78}$/.test(detached.chainId))detached.chainId=BigInt(detached.chainId);
  detached.chainId=uint(detached.chainId);
  const manifest=own(detached),rpc=createPreservationRpcAdapter(provider),packets=new Map(),envelopes=new Map(),byPacket=new Map();
  const getPacket=id=>{const p=packets.get(hash(id));if(!p)throw Error('Unknown captured packet');return p;};
  const getEnvelope=id=>{const e=envelopes.get(hash(id));if(!e)throw Error('Unknown saved envelope');return e;};
  async function header(tag){const n=block(tag),chain=await rpc.getNetwork();if(chain.chainId!==manifest.chainId)throw Error('RPC chain differs');const h=await rpc.getBlock(n);if(!h||h.number!==n)throw Error('Missing anchored block');return own({number:n,hash:hash(h.hash),timestamp:BigInt(block(h.timestamp))});}
  async function unchanged(saved){equal(await header(saved.number),saved,'Anchored block changed');}
  async function pin(p,tag){const runtime=hex(await rpc.getCode(address(p.address),tag),131072);if(runtime==='0x'||keccak256(runtime)!==hash(p.codeHash))throw Error('Reviewed runtime pin differs');}
  async function runtimes(p,tag){for(const entry of p.runtimePins)await pin(entry,tag);}
  async function readSafe(a,method,args,tag){const raw=hex(await rpc.call({to:a,data:safeABI.encodeFunctionData(method,args),blockTag:tag}),1_048_576);let decoded;try{decoded=safeABI.decodeFunctionResult(method,raw);}catch{throw Error('Malformed Safe read result');}if(safeABI.encodeFunctionResult(method,decoded).toLowerCase()!==raw)throw Error('Noncanonical Safe read result');return decoded[0];}
  async function safeState(p,tag){const a=address(p.safe.address),declared=manifest.artistSafe;await pin({address:a,codeHash:declared.codeHash},tag);await pin(declared.singleton,tag);
    const slot=hex(await rpc.getStorage(a,0,tag),32);if(slot!=='0x'+'00'.repeat(12)+address(declared.singleton.address).slice(2))throw Error('Safe singleton slot differs');
    const version=await readSafe(a,'VERSION',[],tag);if(version!==declared.version||!['1.3.0','1.4.1'].includes(version))throw Error('Unsupported or changed Safe VERSION');
    const rawOwners=await readSafe(a,'getOwners',[],tag);if(!Array.isArray(rawOwners)||!rawOwners.length||rawOwners.length>256)throw Error('Safe owner client bound');const owners=Array.from(rawOwners,x=>address(x));if(new Set(owners).size!==owners.length)throw Error('Duplicate Safe owner');
    const threshold=uint(await readSafe(a,'getThreshold',[],tag));if(threshold===0n||threshold>BigInt(owners.length))throw Error('Invalid Safe threshold');
    equal(owners,p.safe.owners.map(x=>address(x)),'Safe owner roster differs');if(threshold!==p.safe.threshold)throw Error('Safe threshold differs');
    return own({address:a,version,owners,threshold,nonce:uint(await readSafe(a,'nonce',[],tag)),codeHash:hash(declared.codeHash),singleton:{address:address(declared.singleton.address),codeHash:hash(declared.singleton.codeHash)}});
  }
  async function safeHash(p,tag){const fields=transactionFields(p.transaction),local=TypedDataEncoder.hash({chainId:manifest.chainId,verifyingContract:address(p.safe.address)},types,fields).toLowerCase();
    const original=hash(await readSafe(address(p.safe.address),'getTransactionHash',names.map(name=>fields[name]),tag));if(local!==hash(p.expectedSafeTxHash)||original!==local)throw Error('Independent Safe transaction hash differs');return local;}
  async function capturePacket(packetText,options){keys(options,['expectedPacketSha256']);const o=own(options),p=preparePreservationRootInterludePacket(packetText,manifest,o),observed=await header(p.anchor.number);equal(observed,p.anchor,'Packet anchor differs');
    await runtimes(p,observed.number);const safe=await safeState(p,observed.number);if(safe.nonce!==p.safe.nonce||safe.nonce!==p.transaction.nonce)throw Error('Packet Safe nonce differs');await safeHash(p,observed.number);await unchanged(observed);
    const id=fingerprint({packetHash:p.packetHash,admissionHash:p.admissionHash,requestHash:p.requestHash,anchor:observed,safe:p.safe.address});
    const value=own({id,packet:p,observed,safe,ownerSignaturesVerified:false,originalProtocolReceiptVerified:false,originalProtocolStateIndependentlyVerified:false,deploymentProvenanceIndependentlyVerified:false});packets.set(id,value);return value;
  }
  async function saveSignedEnvelope(packetId,input){const saved=getPacket(packetId),p=saved.packet;keys(input,['outerSender','data','nonce','expectedSafeTxHash']);const v=own(input);if(byPacket.has(saved.id))throw Error('Signed envelope already saved for packet');
    const data=hex(v.data),nonce=uint(v.nonce),expectedSafeTxHash=hash(v.expectedSafeTxHash),decoded=decodeEnvelope(data,nonce),fields=transactionFields(p.transaction);
    equal(decoded.fields,fields,'Signed Safe transaction differs from all ten packet fields');if(fields.operation!==0n||fields.value!==0n)throw Error('Packet requires ordinary zero-value CALL');
    if(expectedSafeTxHash!==hash(p.expectedSafeTxHash))throw Error('Signed expected Safe hash differs');await unchanged(saved.observed);const safe=await safeState(p,saved.observed.number);if(safe.nonce!==nonce)throw Error('Signed packet nonce differs');await safeHash(p,saved.observed.number);await unchanged(saved.observed);
    const transaction={from:address(v.outerSender),to:address(p.safe.address),value:0n,data},signedEnvelopeHash=keccak256(data),id=fingerprint({packetId:saved.id,transaction,signedEnvelopeHash,nonce,expectedSafeTxHash});
    if(byPacket.has(saved.id))throw Error('Signed envelope already saved for packet');const value=own({id,packetId:saved.id,transaction,fields:decoded.fields,signatures:decoded.signatures,nonce,expectedSafeTxHash,signedEnvelopeHash,innerCallHash:keccak256(fields.data),ownerSignaturesVerified:false,originalProtocolReceiptVerified:false});envelopes.set(id,value);byPacket.set(saved.id,id);return value;
  }
  async function preflight(e,tag){const p=getPacket(e.packetId);if(tag<p.observed.number)throw Error('Preflight predates packet');await unchanged(p.observed);const observed=await header(tag);await runtimes(p.packet,tag);const state=await safeState(p.packet,tag);if(state.nonce!==e.nonce)throw Error('Safe nonce consumed or changed; saved signatures cannot be retried');await safeHash(p.packet,tag);await unchanged(observed);return observed;}
  async function simulateSavedEnvelope(envelopeId,options){const e=getEnvelope(envelopeId);keys(options,['blockTag','gasLimit']);const o=own(options),tag=block(o.blockTag),limit=gas(o.gasLimit),observed=await preflight(e,tag);let result=null,failure=null;
    try{const raw=hex(await rpc.call({...e.transaction,gasLimit:limit,blockTag:tag}),1048576);const decoded=safeABI.decodeFunctionResult('execTransaction',raw);if(safeABI.encodeFunctionResult('execTransaction',decoded).toLowerCase()!==raw)throw Error('Noncanonical Safe execution return');result=decoded[0];}catch(error){failure=summary(error);}
    await unchanged(observed);return own({observed,result,failure,outerCallSucceeded:failure===null,safeInnerSucceeded:failure===null?result:null,stateChangesPersisted:false,gs013SimulationObserved:failure?.reason==='GS013',originalProtocolReceiptVerified:false});
  }
  async function submitSavedEnvelope(envelopeId,transport,options){const e=getEnvelope(envelopeId);keys(transport,['sendTransaction']);if(typeof transport.sendTransaction!=='function')throw Error('Explicit sendTransaction callback required');const send=transport.sendTransaction.bind(transport);
    keys(options,['blockTag','gasLimit'],['nonce','gasPrice','maxFeePerGas','maxPriorityFeePerGas']);const o=own(options),tag=block(o.blockTag),limit=gas(o.gasLimit);const fee={};for(const key of ['nonce','gasPrice','maxFeePerGas','maxPriorityFeePerGas'])if(o[key]!==undefined)fee[key]=uint(o[key]);if(o.gasPrice!==undefined&&(o.maxFeePerGas!==undefined||o.maxPriorityFeePerGas!==undefined))throw Error('Conflicting outer transaction fee fields');
    const observed=await preflight(e,tag);await unchanged(observed);const tx=own({...e.transaction,chainId:manifest.chainId,gasLimit:limit,...fee}),sent=await sendSafely(send,tx);
    return own({envelopeId:e.id,transactionHash:hash(typeof sent==='string'?sent:sent.hash),preflight:observed,signedEnvelopeHash:e.signedEnvelopeHash,originalProtocolReceiptVerified:false});
  }
  async function inspectSubmission(envelopeId,inputHash){const e=getEnvelope(envelopeId),p=getPacket(e.packetId),txHash=hash(inputHash),receipt=await rpc.getTransactionReceipt(txHash),transaction=await rpc.getTransaction(txHash);
    if(!receipt||!transaction||![0,1].includes(receipt.status)||receipt.hash!==txHash||transaction.hash!==txHash||transaction.chainId!==manifest.chainId)throw Error('Missing or invalid mined transaction');
    const n=block(receipt.blockNumber);if(n<=p.observed.number)throw Error('Receipt must follow packet block');for(const key of ['from','to','data','value'])if(transaction[key]!==e.transaction[key])throw Error('Mined signed envelope differs');if(receipt.from!==transaction.from||receipt.to!==transaction.to||receipt.blockHash!==transaction.blockHash||transaction.blockNumber!==n)throw Error('Receipt transaction identity differs');
    await unchanged(p.observed);const prior=await header(n-1),end=await header(n);if(end.hash!==receipt.blockHash)throw Error('Receipt block changed');let last=-1;
    for(const log of receipt.logs){if(log.removed!==false||log.transactionHash!==txHash||log.blockNumber!==n||log.blockHash!==end.hash||log.index<=last)throw Error('Receipt log identity/order differs');last=log.index;}
    await runtimes(p.packet,n-1);await runtimes(p.packet,n);const before=await safeState(p.packet,n-1),after=await safeState(p.packet,n);if(before.nonce!==e.nonce)throw Error('Prior Safe nonce differs');
    const events=[];for(const log of receipt.logs){if(log.address!==address(p.packet.safe.address)||!['ExecutionSuccess','ExecutionFailure'].some(name=>safeABI.getEvent(name).topicHash===log.topics[0]))continue;let parsed,iface;
      try{iface=log.topics.length===2?indexedSafe:safeABI;parsed=iface.parseLog(log);}catch{throw Error('Malformed original Safe event');}if(!parsed)throw Error('Malformed original Safe event');const encoded=iface.encodeEventLog(parsed.fragment,parsed.args);equal({data:encoded.data.toLowerCase(),topics:encoded.topics.map(t=>t.toLowerCase())},{data:log.data,topics:log.topics},'Noncanonical Safe event');if(hash(parsed.args.txHash)!==e.expectedSafeTxHash)throw Error('Safe event transaction hash differs');events.push({name:parsed.name,index:log.index});}
    let outcome;if(receipt.status===0){if(receipt.logs.length||events.length||after.nonce!==before.nonce)throw Error('Reverted Safe receipt/nonce differs');outcome='safe-outer-reverted';}
    else {if(events.length!==1||after.nonce!==before.nonce+1n)throw Error('Safe event/nonce attribution differs');outcome=events[0].name==='ExecutionFailure'?'safe-execution-failure':'success';if(outcome==='safe-execution-failure'&&e.fields.safeTxGas===0n&&e.fields.gasPrice===0n)throw Error('Impossible failure event for original zero-gas Safe mode');}
    const applicationEmitters=[address(p.packet.inner.to)];
    if(p.packet.phase==='consent')applicationEmitters.push(address(p.packet.originalPacket.admission.roles.consentOwner.address));
    let targetApplicationLogs=0;if(outcome==='success')for(const log of receipt.logs)if(applicationEmitters.includes(log.address)){if(log.index>=events[0].index)throw Error('Application event follows Safe success');targetApplicationLogs++;}
    await unchanged(prior);await unchanged(end);return own({transactionHash:txHash,envelopeId:e.id,packetId:p.id,phase:p.packet.phase,kind:p.packet.kind,outcome,observations:{capture:p.observed,prior,end,nonceBefore:before.nonce,nonceAfter:after.nonce},signedEnvelopeHash:e.signedEnvelopeHash,
      safeSignaturesRetryable:outcome==='safe-outer-reverted'&&before.nonce===after.nonce,zeroGasGs013Compatible:outcome==='safe-outer-reverted'&&e.fields.safeTxGas===0n&&e.fields.baseGas===0n&&e.fields.gasPrice===0n,gs013ReceiptCauseProven:false,rollbackIndependentlyProven:false,
      applicationEmitters,targetApplicationLogs,targetApplicationOrderChecked:outcome==='success',applicationEventSchemasAuthenticated:false,originalProtocolReceiptVerified:false,priorConsentReceiptIndependentlyVerified:false,intraBlockTraceProven:false});
  }
  return Object.freeze({capturePacket,saveSignedEnvelope,simulateSavedEnvelope,submitSavedEnvelope,inspectSubmission});
}
