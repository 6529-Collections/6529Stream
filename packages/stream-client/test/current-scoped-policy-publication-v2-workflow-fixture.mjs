// Compiler-ABI RPC fixtures only: no Solidity rendering, archival ceremony or native admission is claimed.
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id, keccak256, toUtf8Bytes } from 'ethers';
import * as pub from '../dist/current-scoped-policy-publication-v2.js';
import * as graph from '../dist/current-scoped-policy-graph-v2.js';
import { setup as graphSetup, A, H, pin, safe } from './current-scoped-policy-graph-v2-workflow-fixture.mjs';
import { fixture, compiledInterfaces as c } from './current-scoped-policy-publication-v2-fixture.mjs';
export { A, H, pin, safe, c, pub };
export const coder = AbiCoder.defaultAbiCoder();
function zero(p) {
  if (p.baseType === 'tuple') return Object.fromEntries(p.components.map(x => [x.name, zero(x)]));
  if (p.baseType === 'array') return Array.from({length: Math.max(0, p.arrayLength)}, () => zero(p.arrayChildren));
  if (p.type === 'address') return ZeroAddress;
  if (p.type === 'bool') return false;
  if (p.type === 'string') return '';
  if (p.type.startsWith('uint')) return 0n;
  if (p.type.startsWith('bytes')) return '0x' + '00'.repeat(Number(p.type.slice(5)) || 0);
  throw Error(p.type);
}
const fragments = new Map();
for (const row of Object.values(fixture.abis).flat()) {
  if (row.type !== 'function') continue;
  const f = new Interface([row]).fragments[0];
  if (!fragments.has(f.format('sighash'))) fragments.set(f.format('sighash'), row);
}
const all = new Interface([...fragments.values()]);
const documents = new Map();
const outputText = fixture.sourceTexts['smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol'];
for (const match of outputText.matchAll(/return bytes\(\s*'([^']+)'/g)) {
  const text=match[1], name=JSON.parse(text).name;
  documents.set(id(name),{text,name,kind:name.includes('STREAM_ABI')?1n:0n});
}
const snapshotText=fixture.sourceTexts['smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol'];
for (const match of snapshotText.matchAll(/string internal constant (SCHEMA|PROFILE|CANON)_DOCUMENT\s*=\s*("(?:\\.|[^"\\])*")/g)) {
  const text=JSON.parse(match[2]),name=JSON.parse(text).name;
  documents.set(id(name),{text,name,kind:match[1]==='SCHEMA'?0n:match[1]==='PROFILE'?2n:1n});
}

export function setup(options = {}) {
  const scope = options.scope ?? (options.count === 2
    ? {scopeType: 2n, collectionId: 7n, tokenId: 0n, scopeId: H(700)}
    : {scopeType: 1n, collectionId: 7n, tokenId: 11n, scopeId: ZeroHash});
  const base = graphSetup({beforeCount: 7, afterCount: 7, mixed: options.count === 2, scope});
  if (options.finalized || options.asyncNotRequired) {
    const row=base.policies[0];
    row.collectionPolicy.mode=2n;
    row.collectionPolicy.renderRequirement=options.finalized?0n:1n;
    row.collectionPolicy.providerEpoch=1n;
    row.componentDataHash=keccak256(coder.encode(['bytes32','uint256','address','address',graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE,
      graph.SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE],[id('6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V2'),1n,A(1),row.coordinator,scope,row.collectionPolicy]));
    base.policyChainHash=graph.scopedPolicyGraphV2PolicyChain(base.dependencies,scope,base.plan,base.progress.commitment,base.policies);
    base.dataHash=graph.scopedPolicyGraphV2SourceSetDataHash(scope,base.plan,base.progress.commitment,base.policyChainHash,
      base.membership,A(9),pin(A(9)).codeHash);
    base.state.hooks.result=e=>e.method==='originalPolicyChainHash'?[base.policyChainHash]:e.method==='sourceSetDataHash'?[base.dataHash]:undefined;
  }
  const count = Number(base.membership.tokenCount);
  const coords = {chainId: 1n, core: A(1), metadata: A(2), checkpoint: A(201), output: A(202), snapshot: A(203)};
  const deployment = {graph: base.deployment, linkedDependencies: [pin(A(120)), pin(A(121))]};
  const historyDeployment = {chainId: 1n, core: A(1), metadata: A(2), checkpoint: pin(A(201)), output: pin(A(202)),
    snapshot: pin(A(203)), linkedDependencies: deployment.linkedDependencies};
  const selectionId = H(301), salt = H(302), artifactHash = H(303), coverageHash = H(304), artistId = H(305);
  const renderer = {...zero(c.selection.getFunction('selectionAt').outputs[0]).selection, registry: A(150), registryCodeHash: pin(A(150)).codeHash,
    versionKey: H(350), renderer: A(151), rendererCodeHash: pin(A(151)).codeHash, rendererId: id('6529STREAM_RENDERER_V1'),
    rendererVersion: id('6529STREAM_STATIC_RENDERER_V1'), contextVersion: H(351), schemaHash: H(352), readSetHash: H(353), registrationHash: H(354)};
  const configs = [], sources = [], rows = [], entropies = [], terminals = [], outputs = [], payloads = [];
  for (let i = 0; i < count; i++) {
    const tokenId = BigInt(11+i), coordinator = base.policies[i]?.coordinator ?? A(70);
    const config = {...zero(c.staticRouter.getFunction('resolvedMetadataConfig').outputs[0]), recordHash: H(400+i),
      collectionId: 7n, tokenId, revision: 1n, sourceSnapshotHash: H(420+i), selection: renderer,
      config: {mode: 1n, renderer: A(151), baseURI: '', pendingURI: '', offchainURIIdMode: 0n, frozen: true}};
    const source = {...zero(c.staticRouter.getFunction('staticRenderSourceForConfig').outputs[0]), chainId: 1n,
      configured: true, name: 'Original STATIC', description: 'RPC fixture', imageURI: '', script: '/* exact original fixture */'};
    const row = {tokenId, configRecordHash: config.recordHash, configHash: keccak256(c.staticRouter.encodeFunctionResult('resolvedMetadataConfig',[config])),
      sourceSnapshotHash: config.sourceSnapshotHash, rawSourceHash: keccak256(coder.encode([c.staticRouter.getFunction('staticRenderSourceForConfig').outputs[0]],[source])),
      selection: renderer, sources: [A(151), A(152), A(153), coordinator, A(154), A(155)],
      sourceCodeHashes: [A(151), A(152), A(153), coordinator, A(154), A(155)].map(x=>pin(x).codeHash)};
    const entropy = {coordinator, coordinatorCodeHash: pin(coordinator).codeHash, policyHash: base.policies[i]?.policyHash ?? H(40),
      status: options.finalized ? 5n : options.asyncNotRequired ? 2n : 1n, mode: options.finalized || options.asyncNotRequired ? 2n : 0n, securityClass: 0n,
      renderRequirement: options.finalized ? 0n : 1n, terminal: !options.finalized, finalized: !!options.finalized,
      seed: options.finalized && !options.zeroSeed ? H(430+i) : ZeroHash};
    const terminal = {entropy, configRecordHash: config.recordHash, versionKey: renderer.versionKey, renderer: renderer.renderer,
      rendererCodeHash: renderer.rendererCodeHash, registry: renderer.registry, registryCodeHash: renderer.registryCodeHash,
      admissionHash: H(450+i), policyChainHash: base.policyChainHash, evidenceHash: H(460+i)};
    const json = JSON.stringify({tokenId: String(tokenId), fixture: 'source-qualified RPC'}), html = `<html>${tokenId}</html>`, data = '0x0102';
    const terminalAdmissionHash = options.finalized ? ZeroHash : keccak256(c.readiness.encodeFunctionResult('requireTerminalRenderReady',[terminal]));
    const output = {leaf: {tokenId, metadataHash: keccak256(toUtf8Bytes(json)), imageHash: ZeroHash,
      animationHash: keccak256(toUtf8Bytes(html)), contentHash: ZeroHash, tokenDataHash: keccak256(data)},
      selectionRowHash: pub.scopedPolicyPublicationV2SelectionRowHash(1n,A(1),A(5),row),
      sourceFactsHash: pub.scopedPolicyPublicationV2SourceFactsHash({configHash: row.configHash, rawSourceHash: row.rawSourceHash,
        coordinator, entropy, entropySourceSet: base.set, entropySourceSetCodeHash: pin(base.set).codeHash,
        inventoryHash: base.progress.commitment, policyChainHash: base.policyChainHash, terminalReadiness: A(200),
        terminalReadinessCodeHash: pin(A(200)).codeHash, terminalAdmissionHash}),
      htmlHash: keccak256(toUtf8Bytes(html)), entropy, terminalAdmissionHash};
    configs.push(config); sources.push({source,json,html,data}); rows.push(row); entropies.push(entropy); terminals.push(terminal); outputs.push(output);
    payloads.push({tokenId,image:'0x',animation:'0x'+Buffer.from(html).toString('hex')});
  }
  const selected = {scope,membershipHash: base.membership.membershipHash,collectionStateHash:H(310),tokenCount:BigInt(count),
    nextIndex:BigInt(count),selectionRoot:H(311)};
  const identity = {selectionCheckpoint:A(7),selectionId,selection:selected,entropySourceSet:base.set,entropySourceSetCodeHash:pin(base.set).codeHash,
    terminalReadiness:A(200),terminalReadinessCodeHash:pin(A(200)).codeHash,inventoryHash:base.progress.commitment,policyChainHash:base.policyChainHash,salt};
  const checkpointId = pub.scopedPolicyPublicationV2CheckpointId(coords,identity);
  const initial = pub.scopedPolicyPublicationV2InitialContentPlan(identity);
  function contentAt(n) {
    let leafChainHash=ZeroHash, outputRoot=ZeroHash;
    for (let i=0;i<n;i++) { leafChainHash=pub.scopedPolicyPublicationV2LeafChain(leafChainHash,BigInt(i),pub.scopedPolicyPublicationV2LeafHash(1n,A(1),outputs[i].leaf));
      outputRoot=pub.scopedPolicyPublicationV2OutputChain(outputRoot,BigInt(i),outputs[i]); }
    return {...initial,nextIndex:BigInt(n),leafChainHash,outputRoot,contentRoot:n===count ? pub.scopedPolicyPublicationV2ContentRoot(1n,A(1),outputs.map(x=>x.leaf)):ZeroHash};
  }
  const complete = contentAt(count);
  const canonical = pub.scopedPolicyPublicationV2OutputManifestBytes(coords,checkpointId,complete,base.set,outputs);
  const coverage = {completionHash:coverageHash,artifactHash,artistId,schemaId:pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA,
    canonicalizationId:pub.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION,contentHash:keccak256(canonical),
    byteLength:BigInt((canonical.length-2)/2),chunkCount:BigInt(Math.ceil((canonical.length-2)/2/8192)),firstFamilyRecordHash:H(320),
    secondFamilyRecordHash:H(321),validationEpoch:1n,evidenceChainHash:H(322)};
  const manifest = pub.scopedPolicyPublicationV2Manifest(coords,checkpointId,complete,base.set,coverage);
  const planHash = pub.scopedPolicyPublicationV2ManifestPlanHash(coords,A(14),manifest);
  const recordHash = pub.scopedPolicyPublicationV2ManifestRecordHash(planHash);
  const artist = {locked:true,registry:A(20),registryCodeHash:pin(A(20)).codeHash,artistId,bindingGeneration:1n,bindingHash:H(330),
    nominatedArtist:A(31),identityRecordHash:H(331),acceptanceRecordHash:H(332),acceptedAt:100n,lockedAt:101n,snapshotHash:H(333)};
  const dependencies = graph.scopedPolicyGraphV2SnapshotDependencies(base.recipe,base.full);
  const source = {scope,membership:base.membership,artist,selection:selected,content:complete,outputs:manifest,sourceFactory:A(101),
    sourceFactoryCodeHash:pin(A(101)).codeHash,factoryDependenciesHash:base.deployment.sourceFactoryDependenciesHash,
    entropy:{planId:base.plan,inventoryHash:base.progress.commitment,policyChainHash:base.policyChainHash,policyCount:BigInt(base.policies.length),
      allFrozen:true,policies:base.policies}};
  const publication = {scope,snapshotId:H(340),expectedHead:ZeroHash,expectedRevision:0n,outputManifestRecord:recordHash,
    coordinatorInventoryPlan:base.plan,expectedSourceHash:pub.scopedPolicyPublicationV2SourceHash(coords,dependencies,source),
    manifestURI:'ipfs://original-snapshot',effectiveAt:999n,reasonHash:H(341)};
  const grants = {authorizationClass:7n,grantRevision:1n,displayAuthorizationClass:options.displayGlobal?8n:7n,displayGrantRevision:2n};
  function snapshotReceipt(timestamp=0n) {
    const r=pub.scopedPolicyPublicationV2PreviewReceipt(coords,publication,base.caller,grants,publication.expectedSourceHash);
    if(timestamp===0n)return r;
    const canonical=snapshotBytes();
    const fields={...r,recordedAt:timestamp,manifestHash:keccak256(canonical),manifestBytes:BigInt((canonical.length-2)/2)};
    fields.recordHash=pub.scopedPolicyPublicationV2SnapshotRecordHash(coords,publication,fields);
    fields.chainHash=pub.scopedPolicyPublicationV2SnapshotChainHash(coords,scope,ZeroHash,1n,fields.recordHash);
    return fields;
  }
  function snapshotBytes() { return pub.scopedPolicyPublicationV2SnapshotBytes(coords,dependencies,publication,snapshotReceipt(),source); }
  const state={hooks:{},calls:[],contentBefore:options.contentBefore??0,contentKnown:options.contentKnown??true,
    outputBefore:options.outputBefore??0,outputKnown:options.outputKnown??true,after:null,publicationPresent:false,missingChunks:false,
    reject:false,raw:null, code:new Map()};
  const chunks=pub.scopedPolicyPublicationV2Chunks(canonical);
  chunks.forEach((x,i)=>state.code.set(A(500+i),x.runtime));
  const snapshotChunks=pub.scopedPolicyPublicationV2Chunks(snapshotBytes());
  snapshotChunks.forEach((x,i)=>state.code.set(A(550+i),x.runtime));
  const emptyContent=zero(c.checkpoint.getFunction('checkpoint').outputs[0]);
  const emptyOutput=zero(c.output.getFunction('manifestPlan').outputs[0]);
  const emptyReceipt=zero(c.snapshot.getFunction('currentSnapshot').outputs[0]);
  const emptyLock=zero(c.snapshot.getFunction('snapshotLock').outputs[0]);
  const originalCall=base.provider.call, originalCode=base.provider.getCode;
  const provider={...base.provider,getCode:async(target,tag)=>{
    const override=await state.hooks.code?.(target,tag);
    return override??state.code.get(target)??originalCode(target,tag);
  },call:async tx=>{
    const target=tx.to,tag=tx.blockTag;
    const iface=target===A(7)?c.selection:target===A(201)?c.checkpoint:target===A(202)?c.output:target===A(203)?c.snapshot:all;
    const parsed=iface.parseTransaction({data:tx.data});
    if(!parsed)return originalCall(tx);
    const {name:method,args}=parsed, event={target,tag,method,args,tx,iface};
    state.calls.push(event);
    const changed=await state.hooks.call?.(event);
    if(changed!==undefined)return typeof changed==='string'?changed:iface.encodeFunctionResult(method,changed);
    let values;
    const after=tag>=12&&state.after;
    if(target===A(7)&&['checkpoint','requireCurrentCheckpoint'].includes(method)) values=[selected];
    else if(target===A(7)&&method==='selectionAt') values=[rows[Number(args[1])]];
    else if(target===A(201)&&['checkpoint','requireCurrentCheckpoint'].includes(method)) {
      const cp=after?.content??(state.contentKnown?contentAt(state.contentBefore):emptyContent);
      if(method==='requireCurrentCheckpoint'&&cp.nextIndex!==cp.tokenCount)throw Error('original incomplete checkpoint');
      values=[cp];
    } else if(target===A(201)&&method==='outputAt') values=[outputs[Number(args[1])]];
    else if(target===A(202)&&method==='manifestPlan') values=[after?.output??(state.outputKnown?{manifest,nextIndex:BigInt(state.outputBefore),recordHash:state.outputBefore===count?recordHash:ZeroHash}:emptyOutput)];
    else if(target===A(202)&&['manifestRecord','requireCurrentManifest'].includes(method)) values=[manifest];
    else if(target===A(202)&&method==='artifactCoverage') values=[A(14)];
    else if(target===A(202)&&method==='contentCheckpoint') values=[A(201)];
    else if(method==='requireArtifactCoverage') values=[coverage];
    else if(method==='artifactChunk') {const i=Number(args[1]);values=[A(500+i),keccak256(chunks[i].runtime)];}
    else if(method==='resolvedMetadataConfig') values=[configs[Number(args[0]-11n)]];
    else if(method==='staticRenderSourceForConfig') {const i=configs.findIndex(x=>x.recordHash===args[1]);values=[sources[i].source,configs[i].config];}
    else if(method==='coordinatorAtMint') values=[entropies[Number(args[0]-11n)].coordinator];
    else if(method==='tokenEntropyReadiness') values=[entropies[Number(args[0]-11n)]];
    else if(method==='requireTerminalRenderReady') values=[terminals[Number(args[0]-11n)]];
    else if(method==='staticTokenRenderFacts') {const e=entropies[Number(args[0]-11n)];values=[e.status,e.seed,A(71)];}
    else if(method==='tokenData') values=[sources[Number(args[0]-11n)].data];
    else if(method==='tokenJSON') values=[sources[Number(args[0]-11n)].json];
    else if(method==='tokenHTML') values=[sources[Number(args[0]-11n)].html];
    else if(method==='artistPresentation') values=[artist];
    else if(method==='familyWriter') {
      const display=args[1]===id('6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1');
      const wanted=display?grants.displayAuthorizationClass:grants.authorizationClass;
      values=[args[2]===wanted,args[2]===wanted?(display?grants.displayGrantRevision:grants.grantRevision):0n];
    } else if(target===A(203)&&method==='previewSnapshot') values=[publication.expectedSourceHash,snapshotBytes()];
    else if(target===A(203)&&method==='currentSnapshot') values=[after?.snapshot??(state.publicationPresent?snapshotReceipt(1012n):emptyReceipt)];
    else if(target===A(203)&&method==='snapshotCount') values=[after?.snapshot||state.publicationPresent?1n:0n];
    else if(target===A(203)&&method==='snapshotLock') values=[emptyLock];
    else if(target===A(203)&&method==='snapshotRecord') values=[publication,snapshotReceipt(1012n)];
    else if(target===A(203)&&method==='snapshotPayload') values=[snapshotBytes()];
    else if(target===A(203)&&method==='snapshotAt') values=[snapshotReceipt(1012n).recordHash];
    else if(target===A(203)&&method==='requireCurrent') values=[snapshotReceipt(1012n)];
    else if(method==='document') {const d=documents.get(args[0]); values=[{exists:true,status:0n,declarationHash:H(999),specification:{name:d.name,kind:d.kind,contentHash:keccak256(toUtf8Bytes(d.text)),canonicalizationId:id('RAW_BYTES'),supersedesId:ZeroHash,uri:'ipfs://original-document',totalBytes:BigInt(Buffer.byteLength(d.text))},chunkHashes:[]}];}
    else if(method==='documentBytes') values=['0x'+Buffer.from(documents.get(args[0]).text).toString('hex')];
    else if(method==='chunk') {const i=snapshotChunks.findIndex(x=>x.hash===args[0]);values=i<0||state.missingChunks?[ZeroAddress,0n]:[A(550+i),snapshotChunks[i].byteLength];}
    else if(['begin','append','beginManifest','verifyNextOutputs','publishSnapshot'].includes(method)&&[A(201),A(202),A(203)].includes(target)) {
      if(state.reject)throw Object.assign(Error('original bounded call refused'),{code:'CALL_EXCEPTION'});
      if(tx.from!==base.caller)throw Error('actual original caller differs');
      values=method==='begin'?[checkpointId]:method==='append'?[]:method==='beginManifest'?[planHash]
        :method==='verifyNextOutputs'?[BigInt(state.outputBefore)+args[1]===BigInt(count)?recordHash:ZeroHash]:[snapshotReceipt(BigInt(1000+tag)).recordHash];
    } else return originalCall(tx);
    const modified=await state.hooks.result?.({...event,values});
    const encoded=iface.encodeFunctionResult(method,modified??values);
    return state.raw?state.raw(event,encoded):encoded;
  }};
  function request(kind) {
    if(kind==='begin') return {kind,selectionId,salt};
    if(kind==='append') return {kind,id:checkpointId,payloads:payloads.slice(state.contentBefore)};
    if(kind==='beginManifest')return {kind,checkpointHash:checkpointId,artifactHash,coverageHash,artistId};
    if(kind==='verifyNextOutputs')return {kind,planHash,count:BigInt(count-state.outputBefore)};
    return {kind:'publishSnapshot',publication};
  }
  function install(capture,mode='direct') {
    const s=capture.stage,r=capture.prepared.request,logs=[];
    function emit(target,iface,name,args){const l=iface.encodeEventLog(iface.getEvent(name),args);logs.push({address:target,topics:[...l.topics],data:l.data});}
    if(s.kind==='checkpoint') {
      state.after={content:s.expected};
      if(r.kind==='begin'&&s.before.tokenCount===0n)emit(A(201),c.checkpoint,'StaticContentStarted',[2n,s.key,r.salt,s.expected]);
      if(r.kind==='append') {
        s.appended.forEach((o,i)=>emit(A(201),c.checkpoint,'StaticContentAppended',[2n,s.key,s.before.nextIndex+BigInt(i),o,pub.scopedPolicyPublicationV2LeafHash(1n,A(1),o.leaf)]));
        if(s.expected.nextIndex===s.expected.tokenCount)emit(A(201),c.checkpoint,'StaticContentCompleted',[2n,s.key,s.expected.contentRoot,s.expected.outputRoot,s.expected.tokenCount]);
      }
    } else if(s.kind==='output') {
      state.after={output:s.expected};
      if(r.kind==='beginManifest'&&s.before.manifest.tokenCount===0n)emit(A(202),c.output,'OutputManifestStarted',[2n,s.key,s.expected.manifest]);
      if(r.kind==='verifyNextOutputs') {
        emit(A(202),c.output,'OutputManifestAdvanced',[2n,s.key,s.before.nextIndex,s.expected.nextIndex]);
        if(s.expected.recordHash!==ZeroHash)emit(A(202),c.output,'OutputManifestVerified',[2n,s.expected.recordHash,s.key,s.expected.manifest]);
      }
    } else {const record=snapshotReceipt(1012n);state.after={snapshot:record};emit(A(203),c.snapshot,'ScopedPolicySnapshotPublished',[2n,record.scopeSubject,publication.snapshotId,record.recordHash,publication,record]);}
    let from=base.caller,to=capture.prepared.call.to,data=capture.prepared.call.data;
    if(mode!=='direct') {
      from=A(31);to=base.caller;data=safe.encodeFunctionData('execTransaction',[capture.prepared.call.to,0n,data,0,10000000n,0n,0n,ZeroAddress,ZeroAddress,'0x1234']);
      if(mode==='indexed')logs.push({address:base.caller,topics:[safe.getEvent('ExecutionSuccess').topicHash,H(901)],data:coder.encode(['uint256'],[0n])});
      else emit(base.caller,safe,'ExecutionSuccess',[H(901),0n]);
    }
    base.state.receipt={status:1,hash:H(900),from,to,blockNumber:12,blockHash:H(1012),logs};
    base.state.transaction={hash:H(900),from,to,blockNumber:12,blockHash:H(1012),chainId:1n,data,value:0n};
    base.renumber();
    return {txHash:H(900),options:mode==='direct'?{execution:'direct'}:{execution:'safe',expectedSafeTxHash:H(901)}};
  }
  return {base,provider,state,coords,deployment,historyDeployment,scope,caller:base.caller,request,install,renumber:base.renumber,
    configs,sources,rows,entropies,terminals,outputs,payloads,selected,initial,complete,contentAt,checkpointId,manifest,planHash,recordHash,
    coverage,canonical,artist,publication,grants,source,dependencies,snapshotBytes,snapshotReceipt,emptyContent,emptyOutput,emptyReceipt};
}
