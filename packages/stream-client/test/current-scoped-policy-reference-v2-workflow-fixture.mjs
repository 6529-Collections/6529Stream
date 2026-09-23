// Source-qualified compiler RPC joins; original rendering, archival admission and EVM execution are mocked.
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id, keccak256, sha256, toUtf8Bytes } from 'ethers';
import * as ref from '../dist/current-scoped-policy-reference-v2.js';
import * as root from '../dist/current-scoped-policy-root-v2.js';
import * as graph from '../dist/current-scoped-policy-graph-v2.js';
import { prepareReferenceEnvironment, referenceEnvironmentCanonicalBytes } from '../dist/current-reference-environment.js';
import { prepareReferenceInventory, referenceInventoryParts } from '../dist/current-reference-inventory.js';
import { setup as publicationSetup, A, H, pin, safe, pub } from './current-scoped-policy-publication-v2-workflow-fixture.mjs';
import { fixture, compiledInterfaces as c, compiledLibraryEvents } from './current-scoped-policy-reference-v2-fixture.mjs';
export { A, H, pin, safe, ref, pub, c };
export const coder = AbiCoder.defaultAbiCoder();
export function zero(p) {
  if (p.baseType === 'tuple') return Object.fromEntries(p.components.map(x => [x.name, zero(x)]));
  if (p.baseType === 'array') return Array.from({length: Math.max(0, p.arrayLength)}, () => zero(p.arrayChildren));
  if (p.type === 'address') return ZeroAddress;
  if (p.type === 'bool') return false;
  if (p.type === 'string') return '';
  if (p.type.startsWith('uint')) return 0n;
  if (p.type.startsWith('bytes')) return '0x' + '00'.repeat(Number(p.type.slice(5)) || 0);
  throw Error(p.type);
}
const functions = new Map();
for (const row of Object.values(fixture.abis).flat()) {
  if (row.type !== 'function') continue;
  const fragment = new Interface([row]).fragments[0];
  if (!functions.has(fragment.format('sighash'))) functions.set(fragment.format('sighash'), row);
}
const all = new Interface([...functions.values()]);
const eventRows = [...Object.values(fixture.abis).flat(), ...Object.values(fixture.libraryAbis).flat()].filter(x => x.type === 'event');
const eventMap = new Map(eventRows.map(row => [new Interface([row]).fragments[0].format('sighash'), row]));
export const events = new Interface([...eventMap.values()]);
const documents = new Map();
for (const [path,value] of Object.entries(fixture.documents)) {
  const document=value.text;
  const definition=ref.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS.find(x=>x.contentHash===keccak256(toUtf8Bytes(document)));
  if(definition){const name=JSON.parse(document).name??path.split('/').at(-1).replace(/\.json$/,'');documents.set(definition.id,{name,document});}
}
for (const path of ['StreamReferenceRenderDefinitions.sol', 'StreamScopedPolicyReferenceDefinitionsV2.sol']) {
  const text = fixture.sourceTexts['smart-contracts/domains/records/' + path];
  for (const match of text.matchAll(/string\s+(?:public|internal)\s+constant\s+\w+\s*=\s*("(?:\\.|[^"\\])*")/g)) {
    const document = JSON.parse(match[1]);
    try { const name = JSON.parse(document).name; if (name) documents.set(id(name), {name, document}); } catch {}
  }
}
export function environment() {
  const value = {objectHash:H(6001), coverageHash:H(6002), manifestHash:ZeroHash, manifestBytes:0n,
    engineName:'Browser', engineVersion:'1', engineExecutableSha256:H(6003), toolchainName:'Capture', toolchainVersion:'1',
    toolchainSha256:H(6004), engineExecutablePath:'engine.exe', toolchainPath:'toolchain.exe',
    packageFiles:[{path:'engine.exe',byteSize:1n,sha256Digest:H(6003)},{path:'toolchain.exe',byteSize:2n,sha256Digest:H(6004)}],
    platformPrerequisites:[{path:'C:\\Windows\\fixture.dll',byteSize:3n,sha256Digest:H(6005)}],
    operatingSystem:'Windows', operatingSystemVersion:'Server', architecture:'AMD64', viewportWidth:640n, viewportHeight:480n,
    devicePixelRatio:1n, colorSpace:'srgb', softwareRasterization:true,
    captureProfile:id('STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1'), licenseNote:'Fixture evidence only'};
  const raw = referenceEnvironmentCanonicalBytes(value);
  return {...value,manifestHash:keccak256(raw),manifestBytes:BigInt((raw.length-2)/2)};
}
export function fileRows(count) {
  return Array.from({length:count}, (_,i) => ({path:`file-${String(i).padStart(4,'0')}.bin`,byteSize:BigInt(i),sha256Digest:H(7000+i)}));
}

export function setup(options = {}) {
  const base = publicationSetup({count:Math.min(options.count??1,2),scope:options.scope,finalized:options.finalized,
    asyncNotRequired:options.asyncNotRequired,zeroSeed:options.zeroSeed,contentBefore:options.count??1,outputBefore:options.count??1});
  // Extend retained RPC facts to exercise a real last index beyond1. This is not a native checkpoint construction.
  if((options.count??1)>2){
    const count=options.count;
    for(let i=2;i<count;i++){
      const tokenId=11n+BigInt(i),row={...structuredClone(base.rows[1]),tokenId};
      const data=base.sources[1].data,json=JSON.stringify({tokenId:String(tokenId),fixture:'source-qualified RPC'}),html=`<html>${tokenId}</html>`;
      const output={...structuredClone(base.outputs[1]),leaf:{...base.outputs[1].leaf,tokenId,metadataHash:keccak256(toUtf8Bytes(json)),animationHash:keccak256(toUtf8Bytes(html))},
        selectionRowHash:pub.scopedPolicyPublicationV2SelectionRowHash(1n,A(1),A(5),row),htmlHash:keccak256(toUtf8Bytes(html))};
      base.rows.push(row);base.sources.push({...base.sources[1],data,json,html});base.entropies.push(structuredClone(base.entropies[1]));base.outputs.push(output);
    }
    const g=base.base,s=base.source;
    s.membership.tokenCount=BigInt(count);
    const plan=graph.scopedPolicyGraphV2InventoryPlan(g.dependencies,base.scope,s.membership);
    const coordinators=g.policies.map(({coordinator,indexedCodeHash,firstTokenIndex})=>({coordinator,indexedCodeHash,firstTokenIndex}));
    const progress={...g.progress,processedTokens:BigInt(count),tokenCount:BigInt(count),coordinatorChain:graph.scopedPolicyGraphV2CoordinatorChain(plan,coordinators)};
    progress.commitment=graph.scopedPolicyGraphV2InventoryCommitment(plan,progress);
    const policyChainHash=graph.scopedPolicyGraphV2PolicyChain(g.dependencies,base.scope,plan,progress.commitment,g.policies);
    s.entropy={...s.entropy,planId:plan,inventoryHash:progress.commitment,policyChainHash};
    s.selection={...s.selection,tokenCount:BigInt(count),nextIndex:BigInt(count)};
    const identity={selectionCheckpoint:A(7),selectionId:base.complete.selectionId,selection:s.selection,entropySourceSet:g.set,
      entropySourceSetCodeHash:pin(g.set).codeHash,terminalReadiness:A(200),terminalReadinessCodeHash:pin(A(200)).codeHash,
      inventoryHash:progress.commitment,policyChainHash,salt:H(302)};
    const checkpointHash=pub.scopedPolicyPublicationV2CheckpointId(base.coords,identity);
    let leafChainHash=ZeroHash,outputRoot=ZeroHash;
    base.outputs.forEach((row,i)=>{leafChainHash=pub.scopedPolicyPublicationV2LeafChain(leafChainHash,BigInt(i),pub.scopedPolicyPublicationV2LeafHash(1n,A(1),row.leaf));
      outputRoot=pub.scopedPolicyPublicationV2OutputChain(outputRoot,BigInt(i),row);});
    s.content={...pub.scopedPolicyPublicationV2InitialContentPlan(identity),nextIndex:BigInt(count),leafChainHash,outputRoot,
      contentRoot:pub.scopedPolicyPublicationV2ContentRoot(1n,A(1),base.outputs.map(row=>row.leaf))};
    const raw=pub.scopedPolicyPublicationV2OutputManifestBytes(base.coords,checkpointHash,s.content,g.set,base.outputs);
    const coverage={...base.coverage,contentHash:keccak256(raw),byteLength:BigInt((raw.length-2)/2),chunkCount:BigInt(Math.ceil((raw.length-2)/16384))};
    s.outputs=pub.scopedPolicyPublicationV2Manifest(base.coords,checkpointHash,s.content,g.set,coverage);
    base.publication.coordinatorInventoryPlan=plan;
    base.publication.outputManifestRecord=pub.scopedPolicyPublicationV2ManifestRecordHash(pub.scopedPolicyPublicationV2ManifestPlanHash(base.coords,A(14),s.outputs));
    base.publication.expectedSourceHash=pub.scopedPolicyPublicationV2SourceHash(base.coords,base.dependencies,s);
  }
  const coords={chainId:1n,core:A(1),metadata:A(2),reference:A(9000)};
  const dependencies={targets:[A(1),A(2),A(3),A(4),A(5),A(203),A(9001)],
    codeHashes:[A(1),A(2),A(3),A(4),A(5),A(203),A(9001)].map(x=>pin(x).codeHash),chainId:1n,
    readGas:100000n,sourceGas:1000000n,snapshotGas:2000000n,archiveGas:3000000n};
  const deployment={chainId:1n,core:pin(A(1)),metadata:pin(A(2)),reference:pin(A(9000)),
    linkedDependencies:{preparation:[pin(A(9100))],source:[pin(A(9101))],history:[pin(A(9102))]}};
  const historyDeployment={chainId:1n,core:A(1),metadata:A(2),reference:deployment.reference,linkedDependencies:deployment.linkedDependencies.history};
  const scope=base.scope, caller=A(30), env=environment();
  const snapshotReceipt=base.snapshotReceipt(1001n);
  const rootCoords={chainId:1n,core:A(1),router:A(5),artistRegistry:A(20)};
  const rootPublication={scope,expectedPredecessor:ZeroHash,snapshotRecordHash:snapshotReceipt.recordHash,snapshotRevision:1n,manifestURI:'ipfs://retained-root'};
  const route={finality:A(850),provider:A(851),snapshot:A(203),metadata:A(2),metadataCodeHash:pin(A(2)).codeHash,scope,
    codeHashes:[A(1),A(20),A(5),A(850),A(851),A(203)].map(x=>pin(x).codeHash)};
  const preparedRoot=root.scopedPolicyRootV2PreparedRecord(rootCoords,{publication:rootPublication,route,source:base.source,
    dependencies:base.dependencies,receipt:snapshotReceipt,publisher:caller,authorizationClass:7n,grantRevision:1n});
  const rootRecord={...preparedRoot.record,artistConsent:H(6110),publishedAt:1002n};
  const aggregate=root.scopedPolicyRootV2NextAggregate(rootCoords,{revision:0n,transitionChain:ZeroHash},ZeroHash,preparedRoot.record);
  const rootKey=root.scopedPolicyRootV2RecordHash(rootCoords,rootRecord,preparedRoot.binding,aggregate);
  const coverages=[];
  function coverage(objectHash,coverageHash,n,digest) {
    const value={coverageHash,objectHash,artistId:base.artist.artistId,contentHash:H(n+1),sha256Digest:digest,
      arweaveDataRoot:H(n+2),byteSize:123n,firstFamilyRecordHash:H(n+3),secondFamilyRecordHash:H(n+4),
      firstReceiptHash:H(n+5),secondReceiptHash:H(n+6),firstFixityHash:H(n+7),secondFixityHash:H(n+8),checkpointHash:H(n+9),profileHash:H(n+10)};
    coverages.push(value);return value;
  }
  const zip=coverage(env.objectHash,env.coverageHash,6200,H(6220));
  const endpointIndexes=base.rows.length===1?[0]:[0,base.rows.length-1];
  const captures=endpointIndexes.map(i=>{
    const row=base.rows[i];
    const html='0x'+Buffer.from(base.sources[i].html).toString('hex');
    const png=coverage(H(6300+i*30),H(6301+i*30),6310+i*30,H(6330+i*30));
    return {tokenId:row.tokenId,collectionSerial:BigInt(i+1),metadataJSONHash:base.outputs[i].leaf.metadataHash,
      htmlHash:keccak256(html),htmlBytes:BigInt((html.length-2)/2),animationHTML:html,objectHash:png.objectHash,coverageHash:png.coverageHash,
      sourceSha256:sha256(html),repeatCaptureSha256:[png.sha256Digest,png.sha256Digest],environmentManifestHash:env.manifestHash,capturedAt:1003n};
  });
  const samples=captures.map((capture,j)=>{const i=endpointIndexes[j];return {membershipIndex:BigInt(i),selection:base.rows[i],entropy:base.entropies[i],
    terminalAdmissionHash:base.outputs[i].terminalAdmissionHash,observation:{tokenId:capture.tokenId,collectionSerial:capture.collectionSerial,
      originalCoordinator:base.entropies[i].coordinator,seed:base.entropies[i].seed,tokenDataHash:base.outputs[i].leaf.tokenDataHash,
      tokenDataBytes:BigInt((base.sources[i].data.length-2)/2),metadataJSONHash:capture.metadataJSONHash,htmlHash:capture.htmlHash,
      htmlBytes:capture.htmlBytes,captureCoverage:coverages[j+1]}};});
  const source={scopeSubject:snapshotReceipt.scopeSubject,snapshot:snapshotReceipt,snapshotSource:base.source,
    contentRootRecordHash:rootKey,contentRoot:rootRecord,contentRootBinding:preparedRoot.binding,environmentCoverage:zip,samples};
  const sourceHash=ref.scopedPolicyReferenceV2SourceHash(coords,dependencies,source);
  const publication={scope,observation:{collectionId:scope.collectionId,referenceId:H(6400),expectedHead:ZeroHash,expectedRevision:0n,
    snapshotRecordHash:snapshotReceipt.recordHash,snapshotRevision:1n,expectedSourcesHash:sourceHash,captures,environment:env,
    manifestURI:options.uri??'',effectiveAt:1004n,reasonHash:H(6401)}};
  const state={calls:[],hooks:{},prepared:new Map(),afterPrepared:new Map(),chunks:new Map(),code:new Map(),
    grantClass:options.global?8n:3n,grantRevision:1n,after:null,receipt:null,tx:null,network:1n,blockHashes:new Map(),
    reject:false,rpcFailure:false,refreshed:false,closed:false,raw:null};
  const envPrepared=prepareReferenceEnvironment(1n,A(9000),env);
  for (const item of [envPrepared.packageInventory,envPrepared.platformInventory]) state.prepared.set(item.inventoryId,item.canonical);
  if(options.retainedEnvironment)state.prepared.set(envPrepared.environmentId,envPrepared.canonical);
  function preupload(raw) {
    for(let i=2;i<raw.length;i+=16384){const chunk='0x'+raw.slice(i,i+16384),hash=keccak256(chunk);
      if(!state.chunks.has(hash)){const pointer=A(10000+state.chunks.size);state.chunks.set(hash,[pointer,BigInt((chunk.length-2)/2)]);state.code.set(pointer,'0x00'+chunk.slice(2));}}
  }
  function preview() {
    const receipt=ref.scopedPolicyReferenceV2PreviewReceipt(coords,publication,caller,{authorizationClass:state.grantClass,grantRevision:state.grantRevision},sourceHash);
    const canonical=ref.scopedPolicyReferenceV2PayloadBytes(coords,publication,receipt,source,envPrepared.canonical);
    return {receipt,canonical};
  }
  function completed(timestamp=1012n) {
    const {receipt,canonical}=preview();
    const value={...receipt,observation:{...receipt.observation,recordedAt:timestamp,payloadHash:keccak256(canonical),payloadBytes:BigInt((canonical.length-2)/2)}};
    value.observation.recordHash=ref.scopedPolicyReferenceV2RecordHash(coords,publication,value);
    value.observation.recordChainHash=ref.scopedPolicyReferenceV2ChainHash(coords,scope,ZeroHash,1n,value.observation.recordHash);
    return value;
  }
  preupload(preview().canonical);preupload(ref.encodeScopedPolicyReferenceV2Publication(publication));preupload(envPrepared.canonical);
  const emptyReceipt=zero(c.reference.getFunction('currentReference').outputs[0]);
  const emptyLock=zero(c.reference.getFunction('referenceLock').outputs[0]);
  const renderer=base.rows[0].selection;
  const registration={...zero(c.rendererRegistry.getFunction('registration').outputs[0]),renderer:renderer.renderer,
    manifest:{...zero(c.rendererRegistry.getFunction('registration').outputs[0]).manifest,rendererClass:id('STATIC'),rendererId:renderer.rendererId,
      rendererVersion:renderer.rendererVersion,contextVersion:renderer.contextVersion,schemaHash:renderer.schemaHash}};
  const provider={...base.provider,
    getNetwork:async()=>{await state.hooks.network?.();return {chainId:state.network};},
    getBlock:async tag=>{await state.hooks.block?.(tag);return {number:tag,hash:state.blockHashes.get(tag)??H(1000+tag),timestamp:1000+tag};},
    getCode:async(target,tag)=>await state.hooks.code?.(target,tag)??state.code.get(target)??base.provider.getCode(target,tag),
    getTransaction:async()=>{await state.hooks.transaction?.();return state.tx;},
    getTransactionReceipt:async()=>{await state.hooks.receipt?.();return state.receipt;},
    call:async tx=>{
      const target=tx.to,tag=tx.blockTag;
      const preferred=target===A(9000)?c.reference:target===A(9001)?c.externalCoverage:target===A(150)?c.rendererRegistry:
        target===A(203)?c.snapshot:target===A(1)?c.core:target===A(5)?c.router:all;
      const iface=preferred.parseTransaction({data:tx.data})?preferred:all;
      const parsed=iface.parseTransaction({data:tx.data});if(!parsed)return base.provider.call(tx);
      const {name:method,args}=parsed,e={target,tag,method,args,tx,iface};state.calls.push(e);
      const override=await state.hooks.call?.(e);
      if(override!==undefined)return typeof override==='string'?override:iface.encodeFunctionResult(parsed.fragment,override);
      let values;
      const after=tag>=12?state.after:null;
      if(target===A(9000)) {
        if(method==='dependencies')values=[dependencies];
        else if(method==='deploymentChainId')values=[1n];
        else if(method==='scopedPolicyReferenceProfile')values=[ref.SCOPED_POLICY_REFERENCE_V2_PROFILE];
        else if(['core','metadataHost','metadataRouter','snapshots','archiveCoverage'].includes(method))values=[dependencies.targets[{core:0,metadataHost:1,metadataRouter:4,snapshots:5,archiveCoverage:6}[method]]];
        else if(method==='preparedFileInventory') {
          const raw=(tag>=12?state.afterPrepared.get(args[0]):undefined)??state.prepared.get(args[0]);
          if(raw===undefined)throw Object.assign(Error('original private manifest unavailable'),{code:'CALL_EXCEPTION',data:id('InvalidSnapshotManifest()').slice(0,10)});
          values=[raw];
        } else if(method==='currentReference'||method==='requireCurrent') {
          if(method==='requireCurrent'&&state.closed)throw Object.assign(Error('original current source refused'),{code:'CALL_EXCEPTION'});
          values=[after??emptyReceipt];
        } else if(method==='referenceCount')values=[after?1n:0n];
        else if(method==='referenceAt')values=[after?.observation.recordHash??ZeroHash];
        else if(method==='referenceLock')values=[emptyLock];
        else if(method==='referenceRecord')values=[publication,after??completed()];
        else if(method==='referenceSource')values=[source];
        else if(method==='referencePayload')values=[preview().canonical];
        else if(method==='previewReference'){
          if(args[1]!==caller||tx.from!==caller)throw Error('Wrong actual preview publisher');
          values=[sourceHash,preview().canonical];
        } else if(method==='publishReference'||method.startsWith('prepare')) {
          if(state.rpcFailure)throw Object.assign(Error('RPC transport unavailable'),{code:'NETWORK_ERROR'});
          if(state.reject)throw Object.assign(Error('original capped source/render/preparation refused'),{code:'CALL_EXCEPTION',data:'0x12345678'});
          if(tx.from!==caller||tx.value!==0n)throw Error('Wrong original caller/value');
          if(method==='publishReference')values=[completed(BigInt(1000+tag)).observation.recordHash];
          else {
            const request=method==='prepareEnvironment'?{kind:method,environment:env}:{kind:method,rows:args[0].map(row=>({path:row.path,byteSize:row.byteSize,sha256Digest:row.sha256Digest})),relative:args[1]};
            values=[ref.prepareScopedPolicyReferenceV2Call(coords,caller,request).preparation.id];
          }
        }
      } else if(target===A(9001)) {
        if(method==='core')values=[A(1)];
        else if(method==='supportsInterface')values=[true];
        else if(method==='coverage'||method==='requireCoverage') {
          if(method==='requireCoverage'&&state.refreshed)throw Object.assign(Error('fresh coverage fixity no longer equals saved coverage'),{code:'CALL_EXCEPTION'});
          const row=coverages.find(x=>x.coverageHash===args[0]);
          if(method==='requireCoverage'&&(row.artistId!==args[1]||row.objectHash!==args[2]))throw Error('Coverage arguments differ');values=[row];
        } else if(method==='currentReceiptPair') {
          const row=coverages.find(x=>x.firstReceiptHash===args[0]&&x.secondReceiptHash===args[1]);
          if(row.artistId!==args[2]||row.objectHash!==args[3])throw Error('Original saved pair arguments differ');
          const {coverageHash,...pair}=row;values=[state.refreshed?{...pair,firstFixityHash:H(9801),secondFixityHash:H(9802)}:pair];
        } else if(method==='objectIdentity') {
          const row=coverages.find(x=>x.objectHash===args[0]);const isZip=row===zip;
          values=[{artistId:row.artistId,schemaId:id(isZip?'STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1':'STREAM_REFERENCE_PNG_OBJECT_V1'),canonicalizationId:id('RAW_BYTES'),
            contentHash:row.contentHash,sha256Digest:row.sha256Digest,arweaveDataRoot:row.arweaveDataRoot,byteSize:row.byteSize,
            formatId:id(isZip?'IANA:application/zip':'IANA:image/png'),formatCatalogId:id('STREAM_REFERENCE_NATIVE_FORMATS_V1'),
            formatCatalogHash:ref.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS.find(x=>x.id===id('STREAM_REFERENCE_NATIVE_FORMATS_V1')).contentHash}];
        }
      } else if(method==='snapshotRecord'&&target===A(203))values=[base.publication,snapshotReceipt];
      else if(method==='snapshotAt'&&target===A(203))values=[snapshotReceipt.recordHash];
      else if(method==='requireCurrent'&&target===A(203))values=[snapshotReceipt];
      else if(method==='scopedContentRootHead')values=[rootKey];
      else if(method==='scopedContentRootRecord')values=[rootRecord];
      else if(method==='scopedPolicyContentRootBinding')values=[preparedRoot.binding];
      else if(method==='scopeTokenAt')values=[base.rows[Number(args[1])].tokenId];
      else if(method==='selectionAt')values=[base.rows[Number(args[1])]];
      else if(method==='outputAt')values=[base.outputs[Number(args[1])]];
      else if(method==='manifestRecord')values=[base.source.outputs];
      else if(method==='tokenCollectionIdentity')values=[true,scope.collectionId,args[0]-10n,!!options.burned];
      else if(method==='tokenLifecycle')values=[options.burned?3n:2n];
      else if(method==='coordinatorAtMint')values=[base.entropies[Number(args[0]-11n)].coordinator];
      else if(method==='tokenEntropyReadiness')values=[base.entropies[Number(args[0]-11n)]];
      else if(method==='tokenData')values=[base.sources[Number(args[0]-11n)].data];
      else if(method==='tokenJSON')values=[base.sources[Number(args[0]-11n)].json];
      else if(method==='tokenHTML')values=[base.sources[Number(args[0]-11n)].html];
      else if(method==='registration'&&target===A(150))values=[registration];
      else if(method==='requireRetained'&&target===A(150))values=[renderer.renderer,renderer.rendererCodeHash];
      else if(method==='familyWriter')values=[args[2]===state.grantClass,args[2]===state.grantClass?state.grantRevision:0n];
      else if(method==='chunk'&&state.chunks.has(args[0]))values=state.chunks.get(args[0]);
      else if((method==='document'||method==='documentBytes')&&documents.has(args[0])){
        const doc=documents.get(args[0]),spec=ref.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS.find(x=>x.id===args[0]);
        values=method==='documentBytes'?['0x'+Buffer.from(doc.document).toString('hex')]:[{exists:true,status:0n,declarationHash:H(9901),
          specification:{name:doc.name,kind:spec.kind,contentHash:keccak256(toUtf8Bytes(doc.document)),canonicalizationId:id('RAW_BYTES'),
            supersedesId:ZeroHash,uri:'',totalBytes:BigInt(Buffer.byteLength(doc.document))},chunkHashes:[]}];
      }
      if(values===undefined)return base.provider.call(tx);
      const changed=await state.hooks.result?.({...e,values});
      const encoded=iface.encodeFunctionResult(parsed.fragment,changed??values);
      return state.raw?state.raw(e,encoded):encoded;
    }};
  function prepareRequest(kind,rows=fileRows(2),relative=true) {
    const request=kind==='prepareEnvironment'?{kind,environment:env}:{kind,rows,relative};
    const plan=ref.prepareScopedPolicyReferenceV2Call(coords,caller,request);
    preupload(plan.preparation.canonical);
    if(kind==='prepareFileInventoryFromParts')for(const part of referenceInventoryParts(prepareReferenceInventory(1n,A(9000),relative,rows)))state.prepared.set(part.partId,part.canonical);
    return request;
  }
  function renumber(){if(state.receipt)state.receipt.logs.forEach((log,index)=>Object.assign(log,{index,removed:false,
    transactionHash:H(900),blockHash:H(1012),blockNumber:12,transactionIndex:0}));}
  function install(capture,mode='direct') {
    const logs=[];
    function emit(name,args){const row=events.encodeEventLog(events.getEvent(name),args);logs.push({address:A(9000),topics:[...row.topics],data:row.data});}
    const request=capture.prepared.request,prepared=capture.prepared.preparation;
    if(prepared){state.afterPrepared.set(prepared.id,prepared.canonical);
      if(!capture.stage.retainedBefore){
        if(request.kind==='prepareEnvironment')emit('ReferenceEnvironmentPrepared',[1n,prepared.id,prepared.contentHash,prepared.byteLength]);
        if(request.kind==='prepareFileInventoryPart')emit('ReferenceInventoryPartPrepared',[1n,prepared.id,request.relative,BigInt(request.rows.length),prepared.contentHash,prepared.byteLength]);
        if(request.kind==='prepareFileInventoryFromParts')emit('ReferenceInventoryAssembled',[1n,prepared.id,request.relative,BigInt(request.rows.length),prepared.contentHash,prepared.byteLength]);
      }
    }else{state.after=completed();emit('ScopedPolicyReferencePublished',[2n,state.after.scopeSubject,publication.observation.referenceId,state.after.observation.recordHash,state.after,publication.observation.manifestURI]);}
    let from=caller,to=capture.prepared.call.to,data=capture.prepared.call.data;
    if(mode!=='direct'){
      from=A(31);to=caller;data=safe.encodeFunctionData('execTransaction',[capture.prepared.call.to,0n,data,0,10000000n,0n,0n,ZeroAddress,ZeroAddress,'0x1234']);
      const row=mode==='indexed'?{topics:[safe.getEvent('ExecutionSuccess').topicHash,H(901)],data:coder.encode(['uint256'],[0n])}
        :safe.encodeEventLog(safe.getEvent('ExecutionSuccess'),[H(901),0n]);logs.push({address:caller,topics:[...row.topics],data:row.data});
    }
    state.receipt={status:1,hash:H(900),from,to,blockNumber:12,blockHash:H(1012),logs};
    state.tx={hash:H(900),from,to,blockNumber:12,blockHash:H(1012),chainId:1n,data,value:0n};renumber();
    return {txHash:H(900),options:mode==='direct'?{execution:'direct'}:{execution:'safe',expectedSafeTxHash:H(901)}};
  }
  return {base,coords,dependencies,deployment,historyDeployment,scope,caller,env,envPrepared,snapshotReceipt,rootRecord,rootKey,
    source,sourceHash,publication,captures,coverages,preview,completed,state,provider,prepareRequest,preupload,install,renumber,emptyReceipt,emptyLock};
}
