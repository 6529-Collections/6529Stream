// Compiler-shaped consumer RPC fixture. Item/source producer execution and archival proofs are mocked.
// Empty segments exercise the original bundle consumer only; no ABI129 inventory producer emits one.
import { ZeroHash, ZeroAddress, id } from 'ethers';
import * as bundle from '../dist/current-scoped-policy-bundle-v2.js';
import * as w from '../dist/current-scoped-policy-bundle-v2-workflow.js';
import { setup as inventorySetup, inv, A, H, pin, safe, coder, empty, item, workerABI, plain, c } from './current-scoped-policy-inventory-v2-workflow-fixture.mjs';
export { bundle, w, inv, A, H, pin, safe, coder, c };
export const host=bundle.scopedPolicyBundleV2Interface();
export const methods=['beginCoverage','coverNext','coverEmptySegment','beginRefresh','refreshNext'];
const workers=['environment','admit','current'].map(method=>workerABI('bundleArchiveReads',method));
export function setup(options={}) {
  const f=inventorySetup(options);f.completed();
  if(options.empty){f.addSegment([]);f.state.before=f.plan(8n);f.state.before.progress.nextToken=f.context.tokenCount;
    f.state.evidence=f.evidence(f.state.before);f.state.before.progress.renderCriticalEvidenceHash=f.state.evidence.inventory.renderCriticalEvidenceHash;}
  const coords={chainId:1n,core:A(1),bundle:A(11000)},caller=f.caller,gasLimit=f.gasLimit;
  const deployment={chainId:1n,core:A(1),bundle:pin(coords.bundle),archiveReader:pin(A(11100)),linkedDependencies:[pin(A(11101))]};
  const historyDeployment={chainId:1n,core:A(1),bundle:deployment.bundle};
  const dependencies={targets:[A(1),A(2),f.coords.inventory,A(11001),A(11002),A(11003)],
    codeHashes:[A(1),A(2),f.coords.inventory,A(11001),A(11002),A(11003)].map(x=>pin(x).codeHash),chainId:1n,readGas:100000n,archiveGas:1000000n};
  const dependencyHash=bundle.scopedPolicyBundleV2DependencyHash(dependencies);
  const environment={onchainHash:H(41001),epoch:1n,externalHash:H(41002),revision:0n};
  const environmentHash=()=>bundle.scopedPolicyBundleV2EnvironmentHash(dependencies,environment.onchainHash,environment.epoch,environment.externalHash,environment.revision);
  const refreshId=()=>bundle.scopedPolicyBundleV2RefreshId(coords,dependencyHash,f.planId,environmentHash());
  const rows=f.state.segments.flatMap(x=>x.items);
  const proof={backend:0n,coverageHash:ZeroHash,objectHash:ZeroHash};
  function admission(row,index){
    if([6n,7n,8n,9n,11n].includes(row.kind))return bundle.scopedPolicyBundleV2IntrinsicAdmission(row,proof);
    if(options.external&&index===rows.length-1){
      const a=empty(bundle.SCOPED_POLICY_BUNDLE_V2_ADMISSION_TUPLE);
      a.proof={backend:1n,coverageHash:H(48001),objectHash:H(48002)};a.originalBundleHash=H(48003);
      Object.assign(a.externalOriginal,{coverageHash:a.proof.coverageHash,objectHash:a.proof.objectHash,artistId:f.context.artistId,
        contentHash:row.digest,sha256Digest:H(48004),arweaveDataRoot:H(48005),byteSize:row.byteSize,firstFamilyRecordHash:H(48006),secondFamilyRecordHash:H(48007),
        firstReceiptHash:H(48008),secondReceiptHash:H(48009),firstFixityHash:H(48010),secondFixityHash:H(48011),checkpointHash:H(48012),profileHash:H(48013)});
      return a;
    }
    const a=empty(bundle.SCOPED_POLICY_BUNDLE_V2_ADMISSION_TUPLE);a.proof={backend:2n,coverageHash:H(42000+index*2),objectHash:H(42001+index*2)};
    a.originalBundleHash=H(43000+index);a.immutablePartsHash=H(44000+index);
    Object.assign(a.onchainOriginal,{completionHash:a.proof.coverageHash,artifactHash:a.proof.objectHash,artistId:f.context.artistId,
      schemaId:row.schemaId,canonicalizationId:row.canonicalizationId,contentHash:row.digest,byteLength:row.byteSize,
      chunkCount:1n,firstFamilyRecordHash:H(45001),secondFamilyRecordHash:H(45002),validationEpoch:1n,evidenceChainHash:H(45003)});
    return a;
  }
  const admissions=rows.map((row,i)=>({item:row,admission:admission(row,i)}));
  const state={calls:[],hooks:{},before:empty(bundle.SCOPED_POLICY_BUNDLE_V2_PROGRESS_TUPLE),after:null,
    refreshBefore:empty(bundle.SCOPED_POLICY_BUNDLE_V2_REFRESH_TUPLE),refreshAfter:null,evidence:null,afterEvidence:null,
    admitted:admissions,workerResult:null,hostResult:null,reject:false,raw:null};
  function progress(itemCount,segmentIndex,complete=false){const p=empty(bundle.SCOPED_POLICY_BUNDLE_V2_PROGRESS_TUPLE);
    p.environmentHash=environmentHash();p.itemCount=BigInt(itemCount);p.segmentIndex=BigInt(segmentIndex);p.complete=complete;
    for(let i=0;i<itemCount;i++)p.evidenceChainHash=bundle.scopedPolicyBundleV2ItemChain(p.evidenceChainHash,f.planId,BigInt(i),inv.scopedPolicyInventoryV2ItemHash(rows[i]),admissions[i].admission);
    for(let i=0;i<segmentIndex;i++)p.segmentChainHash=inv.scopedPolicyInventoryV2AppendSegment(p.segmentChainHash,BigInt(i),f.state.segments[i].segment);
    if(!complete)p.nextLink=f.state.segments[segmentIndex].segment.firstLink;
    return p;
  }
  function evidence(p){const e={scope:f.context.scope,coverage:{inventoryPlan:f.planId,renderCriticalEvidenceHash:f.state.evidence.inventory.renderCriticalEvidenceHash,
    itemCount:p.itemCount,evidenceChainHash:p.evidenceChainHash,bundleCoverageHash:ZeroHash}};
    e.coverage.bundleCoverageHash=bundle.scopedPolicyBundleV2CoverageHash(coords,dependencyHash,f.state.evidence,e);return e;}
  function prepare(kind='beginCoverage'){
    if(kind==='coverNext'||kind==='coverEmptySegment'){
      const last=f.state.segments.length-1,rowCount=f.state.segments[last].items.length;
      state.before=progress(rows.length-rowCount,last);
      if(kind==='coverNext'){const row=rows[rows.length-rowCount];return {kind,id:f.planId,item:row,nextLink:ZeroHash,proof:admissions[rows.length-rowCount].admission.proof};}
    }
    if(kind==='beginRefresh'||kind==='refreshNext'){
      state.before=progress(rows.length,f.state.segments.length,true);state.evidence=evidence(state.before);
      if(kind==='refreshNext')state.refreshBefore={environmentHash:environmentHash(),nextIndex:0n,currentObservationChain:ZeroHash,complete:false};
    }
    return {kind,id:f.planId,...(kind==='refreshNext'?{expectedIndex:0n}:{})};
  }
  const baseCall=f.provider.call;
  const provider={...f.provider,call:async tx=>{
    state.calls.push({...tx});await state.hooks.call?.(tx);
    if(tx.to===deployment.archiveReader.address){const worker=workers.find(x=>x.selector===tx.data.slice(0,10));if(!worker)throw Error('Wrong nominal worker selector');
      const args=coder.decode(worker.inputs,'0x'+tx.data.slice(10));let values;
      if(worker.method==='environment')values=[environmentHash()];
      else if(worker.method==='current')values=[H(46001)];
      else {const row=plain(worker.inputs[2],args[2]),index=rows.findIndex(x=>inv.scopedPolicyInventoryV2ItemHash(x)===inv.scopedPolicyInventoryV2ItemHash(row));
        values=[admission(row,index),H(46001)];}
      values=await state.workerResult?.(worker,args,values)??values;return coder.encode(worker.outputs,values);
    }
    if(tx.to!==coords.bundle&&tx.to!==dependencies.targets[3]&&tx.to!==dependencies.targets[4])return baseCall(tx);
    const iface=tx.to===coords.bundle?host:tx.to===dependencies.targets[3]?c.artifactCoverage:c.externalCoverage;
    const parsed=iface.parseTransaction({data:tx.data});if(!parsed)throw Error('Unknown archive call');const name=parsed.name,args=parsed.args,after=tx.blockTag>=100;let values;
    const slots={core:0,metadataHost:1,renderCriticalInventory:2,artifactCoverage:3,externalCoverage:4};
    if(name in slots)values=[dependencies.targets[slots[name]]];
    else if(name==='dependencies')values=[dependencies];else if(name==='dependencyHash')values=[dependencyHash];
    else if(name==='supportsInterface')values=[true];else if(name==='scopedPolicyBundleArchiveProfile')values=[bundle.SCOPED_POLICY_BUNDLE_V2_PROFILE];
    else if(name==='deploymentChainId')values=[1n];
    else if(['coreCodeHash','metadataCodeHash','inventoryCodeHash'].includes(name))values=[dependencies.codeHashes[['coreCodeHash','metadataCodeHash','inventoryCodeHash'].indexOf(name)]];
    else if(name==='currentArtifactEnvironment'||name==='currentExternalArtifactEnvironment'){
      if(tx.gasLimit!==dependencies.archiveGas)throw Error('Original environment uses archiveGas');
      values=name==='currentArtifactEnvironment'?[environment.onchainHash,environment.epoch]:[environment.externalHash,environment.revision];}
    else if(name==='progress')values=[after&&state.after?state.after:state.before];
    else if(name==='refresh')values=[after&&state.refreshAfter?state.refreshAfter:state.refreshBefore];
    else if(name==='admittedItem'){const row=state.admitted[Number(args[1])];values=[row.item,row.admission];}
    else if(name==='bundleEvidence'||name==='requireCoverage'||name==='requireFullCurrentCoverage'){
      if(name==='requireCoverage'&&args[2]!==f.state.evidence.inventory.renderCriticalEvidenceHash)throw Error('Expected inventory evidence hash, not bundle coverage hash');
      values=[after&&state.afterEvidence?state.afterEvidence:state.evidence];}
    else {if(state.reject)throw Object.assign(Error('Original bundle execution reverted'),{code:'CALL_EXCEPTION'});values=name==='beginRefresh'?[refreshId()]:[];}
    values=await state.hostResult?.(name,args,values,tx)??values;const raw=iface.encodeFunctionResult(parsed.fragment,values);return state.raw?state.raw(name,raw):raw;
  }};
  function emit(name,args){const log=host.encodeEventLog(host.getEvent(name),args);return {address:coords.bundle,topics:[...log.topics],data:log.data};}
  function install(capture,mode='direct'){
    const s=capture.stage,q=capture.prepared.request;state.after=structuredClone(s.after);state.afterEvidence=s.evidence;
    state.refreshAfter=s.refreshAfter?structuredClone(s.refreshAfter):{environmentHash:environmentHash(),nextIndex:BigInt(rows.length),currentObservationChain:H(47000),complete:true};
    const logs=[];if(q.kind==='beginCoverage'&&!s.existing)logs.push(emit('ScopedBundleCoverageStarted',[2n,f.planId,f.state.evidence.inventory.renderCriticalEvidenceHash]));
    if(s.admitted)logs.push(emit('ScopedBundleItemAdmitted',[2n,f.planId,s.before.itemCount,inv.scopedPolicyInventoryV2ItemHash(s.admitted.item),s.admitted.admission]));
    if(s.after.complete&&!s.before.complete)logs.push(emit('ScopedBundleCoverageCompleted',[2n,f.planId,s.evidence.coverage.bundleCoverageHash,s.evidence]));
    if(q.kind==='refreshNext')logs.push(emit('ScopedBundleRefreshAdvanced',[2n,f.planId,s.refreshId,s.refreshAfter.nextIndex,s.refreshAfter.currentObservationChain,s.refreshAfter.complete]));
    const txHash=H(49000),block=100;let from=caller,to=coords.bundle,data=capture.prepared.call.data;
    if(mode!=='direct'){from=A(31);to=caller;data=safe.encodeFunctionData('execTransaction',[coords.bundle,0n,data,0,10000000n,0n,0n,ZeroAddress,ZeroAddress,'0x12']);
      const log=mode==='indexed'?{topics:[safe.getEvent('ExecutionSuccess').topicHash,H(49001)],data:coder.encode(['uint256'],[0n])}:safe.encodeEventLog(safe.getEvent('ExecutionSuccess'),[H(49001),0n]);logs.push({address:caller,topics:[...log.topics],data:log.data});}
    f.state.receipts.set(txHash,{status:1,hash:txHash,from,to,blockNumber:block,blockHash:f.header(block).hash,logs:f.logsFor(txHash,block,logs)});
    f.state.transactions.set(txHash,{hash:txHash,from,to,chainId:1n,blockNumber:block,blockHash:f.header(block).hash,data,value:0n});
    return {txHash,options:mode==='direct'?{execution:'direct'}:{execution:'safe',expectedSafeTxHash:H(49001)}};
  }
  return {f,coords,caller,gasLimit,deployment,historyDeployment,dependencies,dependencyHash,state,provider,prepare,install,environment,
    environmentHash,refreshId,rows,admissions,progress,evidence,emit,options:()=>f.options()};
}
