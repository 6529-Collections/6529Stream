// Compiler-shaped RPC evidence. Original source/item workers and EVM admission are mocked.
// This does not establish native producer reachability or actual archival availability.
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, id, keccak256 } from 'ethers';
import * as inv from '../dist/current-scoped-policy-inventory-v2.js';
import * as w from '../dist/current-scoped-policy-inventory-v2-workflow.js';
import { setup as referenceSetup, A, H, pin, safe, zero, pub } from './current-scoped-policy-reference-v2-workflow-fixture.mjs';
import { code } from './current-scoped-policy-graph-v2-workflow-fixture.mjs';
import { fixture, compiledInterfaces as c } from './current-scoped-policy-inventory-archive-v2-fixture.mjs';
export { inv, w, A, H, pin, safe, zero, c, fixture };
export const coder = AbiCoder.defaultAbiCoder();
export const empty = tuple => zero(ParamType.from(tuple));
export function plain(type, value) {
  const p = typeof type === 'string' ? ParamType.from(type) : type;
  if (p.baseType === 'array') return [...value].map(v => plain(p.arrayChildren, v));
  if (p.baseType === 'tuple') return Object.fromEntries(p.components.map((x, i) => [x.name, plain(x, value[i])]));
  return typeof value === 'string' && value.startsWith('0x') ? value.toLowerCase() : value;
}
function valueType(p) {
  const suffix = p.type.slice(p.type.indexOf('[') < 0 ? p.type.length : p.type.indexOf('['));
  if (p.components) return `(${p.components.map(x => `${valueType(x)} ${x.name}`).join(',')})${suffix}`;
  return /^(address|bool|string|bytes\d*|u?int\d*)(\[.*\])?$/.test(p.type) ? p.type : `uint8${suffix}`;
}
export function workerABI(key, method) {
  const entry = fixture.libraryAbis[key].find(x => x.type === 'function' && x.name === method);
  const selector = Object.entries(fixture.libraryMethodIdentifiers[key]).find(([sig]) => sig.startsWith(method + '('))[1];
  return { key, method, selector: '0x' + selector.replace(/^0x/, ''), inputs: entry.inputs.map(valueType), outputs: entry.outputs.map(valueType) };
}
const workerMap = {
  source: ['scopedPolicyRenderCriticalSourceReadsV2', 'current'],
  native: ['scopedPolicyRenderCriticalNativeReadsV2', 'items'],
  reference: ['scopedPolicyReferenceInventoryReadsV2', 'items'],
  originals: ['preservationOriginalReads', 'items'],
  artist: ['preservationArtistBundleReads', 'item'],
  root: ['scopedPolicyRenderCriticalRootAuthorizationV2', 'contentItem'],
  token: ['scopedPolicyRenderCriticalTokenReadsV2', 'tokenItems'],
  script: ['scopedPolicyRenderCriticalScriptReadsV2', 'items'],
  renderer: ['scopedPolicyRenderCriticalRendererReadsV2', 'item'],
  citation: ['scopedPolicyRenderCriticalCitationReadsV2', 'item']
};
export const workerCalls = Object.entries(workerMap).map(([role, [key, method]]) => ({ role, ...workerABI(key, method) }));
for (const method of ['work', 'rights', 'intent', 'waiver', 'interview']) workerCalls.push({ role: 'typedReferences', ...workerABI('preservationTypedReferences', method) });
for (const method of ['item', 'authenticateCatalogs', 'currentFactsHash']) workerCalls.push({ role: 'documents', ...workerABI('preservationDocumentReads', method) });
export const host = inv.scopedPolicyInventoryV2Interface();
export const methods = ['beginInventory', 'appendNative', 'appendReference', 'appendWork', 'appendRights', 'appendIntent', 'appendIntentWaiver',
  'appendInterview', 'appendInterviewWaiver', 'appendRootAuthorization', 'appendDefinition', 'appendTokenOutput', 'appendTokenScript',
  'appendTokenLibrary', 'appendTokenRenderer', 'appendTokenCitation', 'sealInventory'];
export function item(n = 1, changes = {}) {
  return { ...empty(inv.SCOPED_POLICY_INVENTORY_V2_ITEM_TUPLE), kind: 7n, role: H(20000+n), source: A(2),
    sourceRecord: H(21000+n), provenanceHash: H(22000+n), ...changes };
}
export function definitionItem(index) {
  const d = inv.SCOPED_POLICY_INVENTORY_V2_DEFINITIONS[index];
  return item(index, { kind: 3n, algorithm: 1n, canonicalizationId:id('RAW_BYTES'), digest: d.contentHash, byteSize: d.byteLength,
    catalogId: d.id, catalogHash: d.contentHash, provenanceHash: H(23000+index) });
}
export function setup(options = {}) {
  const ref = referenceSetup({ scope: options.scope });
  const coords = { chainId: 1n, core: A(1), inventory: A(10000) };
  const roles = ['source','native','reference','typedReferences','originals','artist','documents','root','token','script','renderer','citation'];
  const deployment = { chainId: 1n, core: A(1), inventory: pin(coords.inventory),
    workers: Object.fromEntries(roles.map((role, i) => [role, pin(A(10100+i))])), linkedDependencies: [pin(A(10200))] };
  const historyDeployment = { chainId: 1n, core: A(1), inventory: deployment.inventory };
  const dependencies = { targets: Array.from({length:12},(_,i)=>A(i+1)), codeHashes: Array.from({length:12},(_,i)=>pin(A(i+1)).codeHash),
    artistTargets: Array.from({length:5},(_,i)=>A(i+20)), artistCodeHashes: Array.from({length:5},(_,i)=>pin(A(i+20)).codeHash),
    artistContentOwner:A(25),artistContentOwnerCodeHash:pin(A(25)).codeHash,chainId:1n,
    readGas:100000n,sourceGas:1000000n,selectionGas:1000000n,snapshotGas:1000000n,referenceGas:1000000n };
  const context = empty(inv.SCOPED_POLICY_INVENTORY_V2_CONTEXT_TUPLE);
  const source = ref.base.source;
  Object.assign(context, {scope:ref.scope,subject:ref.snapshotReceipt.scopeSubject,artistId:source.artist.artistId,
    snapshot:ref.snapshotReceipt,snapshotSource:source,referenceRender:ref.completed(),
    nativeHash:keccak256(pub.encodeScopedPolicyPublicationV2Source(source)),
    rootRecordHash:ref.rootKey,tokenInventoryHash:source.membership.membershipHash,checkpointHash:source.outputs.checkpointHash,
    outputManifestRecord:ref.base.publication.outputManifestRecord,selectionId:source.content.selectionId,
    selectionHash:source.content.selectionHash,tokenCount:source.membership.tokenCount,interviewEvidenceHash:H(24001)});
  Object.assign(context.descriptions, {scopeSubject:context.subject,workDescriptionRecordHash:H(24002),rightsStatementRecordHash:H(24003),
    workPayloadHash:H(24004),rightsPayloadHash:H(24005),workSelectionHash:H(24006),rightsSelectionHash:H(24007),workRevision:1n,rightsRevision:1n});
  Object.assign(context.conservation.association,{artistId:context.artistId,bindingHash:source.artist.bindingHash,
    generation:source.artist.bindingGeneration,identityRecordHash:source.artist.identityRecordHash});
  Object.assign(context.conservation.record,{kind:options.waiver?2n:1n,recordHash:H(24008),payloadHash:H(24009)});
  Object.assign(context.conservation.interview,{recordHash:options.interviewWaiver?ZeroHash:H(24010),payloadHash:H(24011)});
  context.conservation.interviewStatus=options.interviewWaiver?1n:0n;
  context.conservation.selectionHash=H(24012);
  const dependencyHash=inv.scopedPolicyInventoryV2DependencyHash(dependencies);
  const planId=inv.scopedPolicyInventoryV2PlanId(coords,dependencyHash,context);
  const caller=A(30), gasLimit=10000000n;
  const state={network:1n,calls:[],hooks:{},code:new Map(),blockHashes:new Map(),segments:[],receipts:new Map(),transactions:new Map(),
    before:null,after:null,tokenBefore:{phase:0n,row:0n,count:0n},tokenAfter:null,evidence:null,afterEvidence:null,
    reject:false,rejectWorker:null,raw:null,workerResult:null,hostResult:null,afterBlock:100,sourceStale:false};
  function header(tag){return {number:tag,hash:state.blockHashes.get(tag)??H(50000+tag),timestamp:1000+tag};}
  function logsFor(txHash, block, logs){return logs.map((log,index)=>({...log,index,removed:false,transactionHash:txHash,
    blockHash:header(block).hash,blockNumber:block,transactionIndex:0}));}
  function emit(name,args){const e=host.encodeEventLog(host.getEvent(name),args);return {address:coords.inventory,topics:[...e.topics],data:e.data};}
  function addSegment(items,witness=H(25000+state.segments.length)){
    const index=BigInt(state.segments.length),segment=inv.scopedPolicyInventoryV2Segment(inv.scopedPolicyInventoryV2SegmentKey(planId,index),witness,items);
    const transactionHash=H(30000+Number(index)),block=2+Number(index);
    const row={locator:{transactionHash,logIndex:0},segment,items};state.segments.push(row);
    const log=emit('ScopedInventorySegmentRecorded',[2n,planId,index,segment,items]);
    state.receipts.set(transactionHash,{status:1,hash:transactionHash,from:caller,to:coords.inventory,blockNumber:block,blockHash:header(block).hash,logs:logsFor(transactionHash,block,[log])});
    state.transactions.set(transactionHash,{hash:transactionHash,from:caller,to:coords.inventory,chainId:1n,blockNumber:block,blockHash:header(block).hash,data:'0x',value:0n});
    return row;
  }
  function plan(stage=0n){let chain=ZeroHash,count=0n;state.segments.forEach((row,i)=>{chain=inv.scopedPolicyInventoryV2AppendSegment(chain,BigInt(i),row.segment);count+=row.segment.itemCount;});
    return {...empty(inv.SCOPED_POLICY_INVENTORY_V2_PLAN_TUPLE),scope:context.scope,progress:{collectionId:context.scope.collectionId,
      subject:context.subject,artistId:context.artistId,sourceContextHash:inv.scopedPolicyInventoryV2ContextHash(context),tokenCount:context.tokenCount,
      nextToken:0n,segmentCount:BigInt(state.segments.length),itemCount:count,segmentChainHash:chain,completedStages:stage,renderCriticalEvidenceHash:ZeroHash},
      nativeCursor:stage>0n?2n:0n,nativeCount:stage>0n?2n:0n,referenceCursor:stage>1n?2n:0n,referenceCount:stage>1n?2n:0n};}
  function evidence(p){const e={scope:context.scope,inventory:{planId,collectionId:context.scope.collectionId,scopeSubject:context.subject,
    artistId:context.artistId,originals:{rootRecordHash:context.rootRecordHash,snapshotRecordHash:context.snapshot.recordHash,
      referenceRenderRecordHash:context.referenceRender.observation.recordHash,intentRecordHash:context.conservation.record.kind===1n?context.conservation.record.recordHash:ZeroHash,
      intentWaiverRecordHash:context.conservation.record.kind===2n?context.conservation.record.recordHash:ZeroHash,interviewEvidenceHash:context.interviewEvidenceHash,
      rightsStatementRecordHash:context.descriptions.rightsStatementRecordHash,workDescriptionRecordHash:context.descriptions.workDescriptionRecordHash},
    sourceContextHash:p.progress.sourceContextHash,tokenInventoryHash:context.tokenInventoryHash,tokenCount:context.tokenCount,
    segmentCount:p.progress.segmentCount,itemCount:p.progress.itemCount,segmentChainHash:p.progress.segmentChainHash,renderCriticalEvidenceHash:ZeroHash}};
    e.inventory.renderCriticalEvidenceHash=inv.scopedPolicyInventoryV2EvidenceHash(coords,dependencyHash,e);return e;}
  function prepare(kind='beginInventory') {
    const stages={appendNative:0,appendReference:1,appendWork:2,appendRights:3,appendIntent:4,appendIntentWaiver:4,
      appendInterview:5,appendInterviewWaiver:5,appendRootAuthorization:6,appendDefinition:7,
      appendTokenOutput:8,appendTokenScript:8,appendTokenLibrary:8,appendTokenRenderer:8,appendTokenCitation:8,sealInventory:8};
    const stage=stages[kind]??0;
    if(stage>=1)addSegment([item(1),item(1)]);
    if(stage>=2)addSegment([item(2),item(3)]);
    for(let i=2;i<Math.min(stage,7);i++)addSegment([item(10+i)],i===6?context.rootRecordHash:H(25000+i));
    if(stage===8)for(let i=0;i<31;i++)addSegment([definitionItem(i)]);
    state.before=kind==='beginInventory'&&!options.existing?empty(inv.SCOPED_POLICY_INVENTORY_V2_PLAN_TUPLE):plan(BigInt(stage));
    if(kind==='appendIntentWaiver')context.conservation.record.kind=2n;
    if(kind==='appendInterviewWaiver'){context.conservation.interviewStatus=1n;context.conservation.interview.recordHash=ZeroHash;}
    const phases={appendTokenOutput:0n,appendTokenScript:1n,appendTokenLibrary:2n,appendTokenRenderer:3n,appendTokenCitation:4n};
    state.tokenBefore={phase:phases[kind]??0n,row:0n,count:0n};
    if(kind==='sealInventory')state.before.progress.nextToken=context.tokenCount;
    if(kind==='beginInventory')return {kind,scope:context.scope};
    if(['appendNative','appendReference'].includes(kind))return {kind,id:planId,maximum:2n};
    if(kind==='appendRootAuthorization')return {kind,id:planId,actor:caller,observedAt:1000n,originalAggregate:{revision:1n,transitionChain:H(24015)},originalLegacyFamilyHash:H(24016)};
    if(kind==='appendTokenOutput')return {kind,id:planId,payload:empty(inv.SCOPED_POLICY_INVENTORY_V2_PAYLOAD_TUPLE)};
    const witnesses={appendWork:'WORK',appendRights:'RIGHTS',appendIntent:'INTENT',appendIntentWaiver:'INTENT_WAIVER',appendInterview:'INTERVIEW'};
    if(witnesses[kind])return {kind,id:planId,witness:empty(inv[`SCOPED_POLICY_INVENTORY_V2_${witnesses[kind]}_TUPLE`]),
      ...(['appendWork','appendIntent','appendIntentWaiver','appendInterview'].includes(kind)?{originalActor:kind==='appendWork'?ZeroAddress:caller}:{})};
    return {kind,id:planId};
  }
  const provider={getNetwork:async()=>{await state.hooks.network?.();return {chainId:state.network};},getBlock:async tag=>{await state.hooks.block?.(tag);return header(tag);},
    getCode:async(address,tag)=>{await state.hooks.code?.(address,tag);return state.code.get(address)??code(address);},
    getTransactionReceipt:async hash=>{await state.hooks.receipt?.(hash);return state.receipts.get(hash)??null;},
    getTransaction:async hash=>{await state.hooks.transaction?.(hash);return state.transactions.get(hash)??null;},
    call:async tx=>{
      const call={...tx};state.calls.push(call);await state.hooks.call?.(call);
      const worker=workerCalls.find(x=>x.selector===tx.data.slice(0,10)&&deployment.workers[x.role].address===tx.to);
      if(worker){if(state.rejectWorker===worker.role)throw Object.assign(Error('Original source worker reverted'),{code:'CALL_EXCEPTION'});
        const args=coder.decode(worker.inputs,tx.data.slice(0,10)==='0x'?'0x':'0x'+tx.data.slice(10));let values;
        if(worker.role==='source'){if(state.sourceStale)throw Error('Source is stale');values=[context];}
        else if(worker.role==='native'||worker.role==='reference')values=[[item(1),item(1)],2n];
        else if(worker.role==='typedReferences'||worker.role==='originals'||worker.role==='token'||worker.role==='script')values=[[item(20),item(21)]];
        else if(worker.role==='artist'||worker.role==='root')values=[item(22)];
        else if(worker.role==='renderer'||worker.role==='citation')values=[item(23),1n];
        else if(worker.method==='authenticateCatalogs')values=[];
        else {const index=inv.SCOPED_POLICY_INVENTORY_V2_DEFINITIONS.findIndex(d=>d.id===args[1]);
          if(index<0)throw Error('Unknown exact definition');values=[worker.method==='item'?definitionItem(index):H(23000+index)];}
        values=await state.workerResult?.(worker,args,values)??values;return coder.encode(worker.outputs,values);
      }
      const iface=tx.to===coords.inventory?host:c.workSelection;
      const parsed=iface.parseTransaction({data:tx.data});if(!parsed)throw Error('Unknown original call');
      const name=parsed.name,args=parsed.args,after=tx.blockTag>=state.afterBlock;let values;
      const targets={core:0,metadataHost:1,metadataRouter:4,snapshots:5,referencePublisher:6,artifactCoverage:10,externalCoverage:11};
      if(name in targets)values=[dependencies.targets[targets[name]]];
      else if(name==='dependencies')values=[dependencies];else if(name==='dependencyHash')values=[dependencyHash];
      else if(name==='scopedPolicyInventoryProfile')values=[inv.SCOPED_POLICY_INVENTORY_V2_PROFILE];else if(name==='supportsInterface')values=[true];
      else if(name==='plan')values=[after&&state.after?state.after:state.before];
      else if(name==='tokenProgress')values=[after&&state.tokenAfter?state.tokenAfter:state.tokenBefore];
      else if(name==='sourceContext')values=[context];else if(name==='inventorySegment')values=[state.segments[Number(args[1])].segment];
      else if(name==='inventoryEvidence'||name==='requireCurrent')values=[after&&state.afterEvidence?state.afterEvidence:state.evidence];
      else if(name==='workSelectionAt'){const selected=zero(iface.getFunction(name).outputs[0]);Object.assign(selected,{recordHash:context.descriptions.workDescriptionRecordHash,selectionHash:context.descriptions.workSelectionHash});values=[selected];}
      else if(name==='requireFullDefinitionBytes')values=[];
      else {if(state.reject)throw Object.assign(Error('Original host execution reverted'),{code:'CALL_EXCEPTION'});
        values=name==='beginInventory'?[planId]:name==='sealInventory'?[evidence(state.before)]:[];}
      values=await state.hostResult?.(name,args,values,tx)??values;
      const encoded=iface.encodeFunctionResult(parsed.fragment,values);return state.raw?state.raw(name,encoded):encoded;
    }};
  function renumber(hash=H(49000)){const receipt=state.receipts.get(hash);receipt.logs=logsFor(hash,receipt.blockNumber,receipt.logs);}
  function install(capture,mode='direct'){
    const s=capture.stage;state.after=structuredClone(s.after);state.tokenAfter=structuredClone(s.tokenAfter);state.afterEvidence=s.evidence;
    const logs=[];if(capture.prepared.request.kind==='beginInventory'&&!s.existing)logs.push(emit('ScopedInventoryStarted',[2n,planId,context.scope,s.after.progress.sourceContextHash]));
    if(s.appended){logs.push(emit('ScopedInventorySegmentRecorded',[2n,planId,s.before.progress.segmentCount,s.appended.segment,s.appended.items]));state.segments.push({segment:s.appended.segment,items:s.appended.items});}
    if(s.evidence)logs.push(emit('ScopedInventoryCompleted',[2n,planId,s.evidence.inventory.renderCriticalEvidenceHash,s.evidence]));
    const txHash=H(49000),block=state.afterBlock;let from=caller,to=capture.prepared.call.to,data=capture.prepared.call.data;
    if(mode!=='direct'){from=A(31);to=caller;data=safe.encodeFunctionData('execTransaction',[capture.prepared.call.to,0n,data,0,10000000n,0n,0n,ZeroAddress,ZeroAddress,'0x12']);
      const row=mode==='indexed'?{topics:[safe.getEvent('ExecutionSuccess').topicHash,H(49001)],data:coder.encode(['uint256'],[0n])}:safe.encodeEventLog(safe.getEvent('ExecutionSuccess'),[H(49001),0n]);logs.push({address:caller,topics:[...row.topics],data:row.data});}
    state.receipts.set(txHash,{status:1,hash:txHash,from,to,blockNumber:block,blockHash:header(block).hash,logs:logsFor(txHash,block,logs)});
    state.transactions.set(txHash,{hash:txHash,from,to,chainId:1n,blockNumber:block,blockHash:header(block).hash,data,value:0n});
    return {txHash,options:mode==='direct'?{execution:'direct'}:{execution:'safe',expectedSafeTxHash:H(49001)}};
  }
  function completed(){const request=prepare('sealInventory');state.evidence=evidence(state.before);state.before.progress.renderCriticalEvidenceHash=state.evidence.inventory.renderCriticalEvidenceHash;return request;}
  const locators=()=>state.segments.filter(x=>x.locator).map(x=>x.locator);
  return {ref,coords,deployment,historyDeployment,dependencies,dependencyHash,context,planId,caller,gasLimit,state,provider,prepare,plan,evidence,
    addSegment,completed,locators,install,renumber,header,logsFor,emit,options:()=>({blockTag:90,gasLimit,segments:locators()})};
}
