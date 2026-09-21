// Compiler-encoded RPC consistency fixtures. These mocks do not execute Solidity or establish
// native producer admission, byte-pattern acceptance, nested gas capacity, or atomic rollback.
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id, keccak256, toUtf8Bytes, hexlify, getAddress } from "ethers";
import { compiledInterfaces as compiled } from "./current-preservation-v2-fixture.mjs";
import * as p from "../dist/current-token-preservation-output-v2.js";
export const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
export const H = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
export const Z = ZeroHash, ZA = ZeroAddress;
export const coder = AbiCoder.defaultAbiCoder();
export const cp = compiled.StreamPreservationPolicyContentCheckpointV2;
export const op = compiled.StreamPreservationPolicyOutputManifestV2;
const router = compiled.StreamMetadataRouter;
const sel = compiled.StreamStaticSelectionCheckpoint;
const source = compiled.StreamFinalityEntropyPolicySourceSet;
const factory = compiled.StreamFinalityScopedEntropyPolicySourceFactoryV2;
const readiness = compiled.StreamTerminalEntropyReadiness;
const registry = compiled.IStreamPreservationRegistryV1;
const producer = compiled.StreamPreservationRendererV1;
const core = compiled.StreamCore;
const coverageABI = compiled.StreamFinalityArtifactCoverage;
const schema = compiled.StreamSchemaRegistry;
const entropy = compiled.IStreamStaticEntropySource;
export const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);
const indexedSafe = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)"]);
function encoded(iface, name, value) { return coder.encode([iface.getFunction(name).outputs[0]], [value]); }
export function zeroResult(iface, name) {
  const zero = t => t.baseType === "tuple" ? t.components.map(zero) : t.baseType === "array"
    ? Array.from({ length: t.arrayLength }, () => zero(t.arrayChildren))
    : t.type === "address" ? ZA : t.type === "bool" ? false : t.type.startsWith("bytes") ? Z : 0n;
  return plain(iface.decodeFunctionResult(name, iface.encodeFunctionResult(name, iface.getFunction(name).outputs.map(zero)))[0]);
}
function plain(v) { return v && typeof v.toObject === "function" ? Object.fromEntries(Object.entries(v.toObject()).map(([k,x])=>[k,plain(x)])) : Array.isArray(v) ? v.map(plain) : v; }
export function setup(options = {}) {
  const kind = options.scopeKind ?? "scoped";
  const scopeType = options.scopeType ?? (kind === "collection" ? 0n : 2n);
  const length = options.tokens ?? (scopeType === 1n ? 1 : 2);
  const code = new Map();
  const pin = n => { const address = A(n), raw = `0x6000${n.toString(16).padStart(4, "0")}`; code.set(address, raw); return {address, codeHash:keccak256(raw)}; };
  const pins = Object.fromEntries(["checkpoint","output","core","router","selection","source","readiness","coverage","schema","factory","membership","metadata","entropy","registry","renderer","attribution","producer0","producer1","link"].map((name,i)=>[name,pin(i+1)]));
  const d = { chainId:1n, scopeKind:kind, checkpoint:pins.checkpoint, output:pins.output, linkedDependencies:[pins.link] };
  const coords = {chainId:1n,scopeKind:kind,core:pins.core.address,metadataRouter:pins.router.address,checkpoint:pins.checkpoint.address,output:pins.output.address};
  const scope = {scopeType,collectionId:9n,tokenId:scopeType===1n?10n:0n,scopeId:scopeType>1n?H(70):Z};
  const selection = {scope,membershipHash:H(71),collectionStateHash:H(72),tokenCount:BigInt(length),nextIndex:BigInt(length),selectionRoot:H(73)};
  const factoryDeps = {targets:[pins.core.address,pins.metadata.address,pins.membership.address,pins.entropy.address],codeHashes:[pins.core.codeHash,pins.metadata.codeHash,pins.membership.codeHash,pins.entropy.codeHash],chainId:1n,readGas:300000n,inventoryGas:500000n};
  const factoryHash = keccak256(encoded(factory,"dependencies",factoryDeps));
  const inventoryHash=H(75), policyChainHash=H(76), selectionId=H(77), salt=H(78);
  const rows=[], configurations=[], sources=[], entropies=[], terminals=[], bindings=[], admissions=[], outputs=[], animations=[], jsons=[];
  const html = options.html ?? hexlify(toUtf8Bytes("<html>preserved</html>"));
  const json = options.json ?? hexlify(toUtf8Bytes('{"image":"","animation_url":"data:text/html;base64,PGh0bWw+cHJlc2VydmVkPC9odG1sPg=="}'));
  for(let i=0;i<length;i++) {
    const tokenId=10n+BigInt(i), pr=pins[i%2?"producer1":"producer0"];
    const selectionRow={registry:pins.registry.address,registryCodeHash:pins.registry.codeHash,versionKey:H(100+i),renderer:pins.renderer.address,rendererCodeHash:pins.renderer.codeHash,rendererId:id("6529STREAM_RENDERER_V1"),rendererVersion:id("6529STREAM_STATIC_RENDERER_V1"),contextVersion:H(110),schemaHash:H(111),readSetHash:H(112),registrationHash:H(113)};
    const config={recordHash:H(120+i),previous:Z,collectionId:9n,tokenId,revision:1n,defaultRevision:0n,level:1n,sourceSnapshotHash:H(130+i),selection:selectionRow,config:{mode:1n,renderer:pins.renderer.address,baseURI:"",pendingURI:"",offchainURIIdMode:0n,frozen:true}};
    const raw={chainId:1n,configured:true,name:"Preserved",description:"",imageURI:"",animationBaseURI:"",script:"",scriptManifest:{host:ZA,codeHash:Z,manifestHash:Z},mediaManifest:{host:ZA,codeHash:Z,manifestHash:Z}};
    const row={tokenId,configRecordHash:config.recordHash,configHash:keccak256(encoded(router,"resolvedMetadataConfig",config)),sourceSnapshotHash:config.sourceSnapshotHash,rawSourceHash:keccak256(coder.encode([router.getFunction("staticRenderSourceForConfig").outputs[0]],[raw])),selection:selectionRow,sources:[pins.core.address,pins.router.address,pins.metadata.address,pins.entropy.address,pins.attribution.address,pins.membership.address],sourceCodeHashes:[pins.core.codeHash,pins.router.codeHash,pins.metadata.codeHash,pins.entropy.codeHash,pins.attribution.codeHash,pins.membership.codeHash]};
    const status=options.finalized?5n:options.notRequired?2n:1n;
    const e={coordinator:pins.entropy.address,coordinatorCodeHash:pins.entropy.codeHash,policyHash:H(140+i),status,mode:status===1n?0n:2n,securityClass:0n,renderRequirement:options.finalized?0n:1n,terminal:!options.finalized,finalized:!!options.finalized,seed:Z};
    const terminal={entropy:e,configRecordHash:row.configRecordHash,versionKey:selectionRow.versionKey,renderer:selectionRow.renderer,rendererCodeHash:selectionRow.rendererCodeHash,registry:selectionRow.registry,registryCodeHash:selectionRow.registryCodeHash,admissionHash:H(150+i),policyChainHash,evidenceHash:H(160+i)};
    const b={producer:pr.address,producerCodeHash:pr.codeHash,profile:i%2?p.TOKEN_PRESERVATION_OUTPUT_V2_CURRENT_ARTIST_PRODUCER:p.TOKEN_PRESERVATION_OUTPUT_V2_ORIGINAL_PRODUCER,core:pins.core.address,metadataRouter:pins.router.address,liveRenderer:pins.renderer.address,liveRendererCodeHash:pins.renderer.codeHash,attribution:pins.attribution.address,attributionCodeHash:pins.attribution.codeHash};
    const a={registry:pins.registry.address,registryCodeHash:pins.registry.codeHash,versionKey:selectionRow.versionKey,registrationHash:H(170+i),readSetHash:H(180+i),analysisHash:H(190+i),goldenHash:H(200+i)};
    const terminalAdmissionHash=options.finalized?Z:keccak256(encoded(readiness,"requireTerminalRenderReady",terminal));
    const output={leaf:{tokenId,metadataHash:keccak256(json),imageHash:Z,animationHash:keccak256(html),contentHash:Z,tokenDataHash:keccak256("0x1234")},selectionRowHash:p.tokenPreservationOutputV2SelectionRowHash(1n,pins.core.address,pins.router.address,row),sourceFactsHash:p.tokenPreservationOutputV2SourceFactsHash(kind,{preservation:b,admission:a,configHash:row.configHash,rawSourceHash:row.rawSourceHash,coordinator:pins.entropy.address,entropy:e,entropySourceSet:pins.source.address,entropySourceSetCodeHash:pins.source.codeHash,inventoryHash,policyChainHash,terminalReadiness:pins.readiness.address,terminalReadinessCodeHash:pins.readiness.codeHash,terminalAdmissionHash}),htmlHash:keccak256(html),entropy:e,terminalAdmissionHash,preservation:b,preservationAdmission:a};
    rows.push(row);configurations.push(config);sources.push(raw);entropies.push(e);terminals.push(terminal);bindings.push(b);admissions.push(a);outputs.push(output);animations.push(html);jsons.push(json);
  }
  const identity={selectionCheckpoint:pins.selection.address,selectionId,selection,entropySourceSet:pins.source.address,entropySourceSetCodeHash:pins.source.codeHash,terminalReadiness:pins.readiness.address,terminalReadinessCodeHash:pins.readiness.codeHash,inventoryHash,policyChainHash,salt};
  const key=p.tokenPreservationOutputV2CheckpointId(coords,identity);
  const initial=p.tokenPreservationOutputV2InitialContentPlan(kind,identity);
  function content(n) {let leafChainHash=Z,outputRoot=Z;for(let i=0;i<n;i++){leafChainHash=p.tokenPreservationOutputV2LeafChain(leafChainHash,BigInt(i),p.tokenPreservationOutputV2LeafHash(1n,pins.core.address,outputs[i].leaf));outputRoot=p.tokenPreservationOutputV2OutputChain(outputRoot,BigInt(i),outputs[i]);}return {...initial,nextIndex:BigInt(n),leafChainHash,outputRoot,contentRoot:n===length?p.tokenPreservationOutputV2ContentRoot(1n,pins.core.address,outputs.map(r=>r.leaf)):Z};}
  const completed=content(length);
  const canonical=p.tokenPreservationOutputV2ManifestBytes(coords,key,completed,pins.source.address,outputs);
  const coverage={completionHash:H(220),artifactHash:H(221),artistId:H(222),schemaId:p.TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA,canonicalizationId:p.TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION,contentHash:keccak256(canonical),byteLength:BigInt((canonical.length-2)/2),chunkCount:BigInt(Math.ceil((canonical.length-2)/2/8192)),firstFamilyRecordHash:H(223),secondFamilyRecordHash:H(224),validationEpoch:1n,evidenceChainHash:H(225)};
  const chunks=[];
  for(let i=0;i<Number(coverage.chunkCount);i++){const address=A(300+i),raw=`0x00${canonical.slice(2+i*16384,2+(i+1)*16384)}`;code.set(address,raw);chunks.push({address,codeHash:keccak256(raw)});}
  const manifest=p.tokenPreservationOutputV2Manifest(coords,key,completed,pins.source.address,coverage);
  const planHash=p.tokenPreservationOutputV2ManifestPlanHash(coords,pins.coverage.address,manifest);
  const recordHash=p.tokenPreservationOutputV2RecordHash(planHash);
  const method=options.method??"append", prefix=options.prefix??0;
  const request=method==="begin"?{kind:method,selectionId,salt}:method==="append"?{kind:method,id:key,payloads:rows.slice(prefix,prefix+(options.appendCount??Math.min(4,length-prefix))).map((r,i)=>({tokenId:r.tokenId,producer:bindings[prefix+i].producer,image:"0x",animation:animations[prefix+i]}))}:method==="beginManifest"?{kind:method,checkpointHash:key,artifactHash:coverage.artifactHash,coverageHash:coverage.completionHash,artistId:coverage.artistId}:{kind:method,planHash,count:options.count??BigInt(length)};
  const f={d,coords,pins,code,scope,selection,identity,key,initial,completed,content,rows,configurations,sources,entropies,terminals,bindings,admissions,outputs,animations,jsons,coverage,canonical,chunks,manifest,planHash,recordHash,request,caller:A(90),calls:[],hook:null,codeHook:null,networkHook:null,receipt:null,transaction:null,minedCapture:null};
  const targets=new Map([[pins.checkpoint.address,cp],[pins.output.address,op],[pins.selection.address,sel],[pins.source.address,source],[pins.factory.address,factory],[pins.router.address,router],[pins.readiness.address,readiness],[pins.registry.address,registry],[pins.producer0.address,producer],[pins.producer1.address,producer],[pins.core.address,core],[pins.coverage.address,coverageABI],[pins.schema.address,schema],[pins.entropy.address,entropy]]);
  const beforeContent=()=>method==="begin"?(options.retry?content(prefix):zeroResult(cp,"checkpoint")):method==="append"?content(prefix):completed;
  const beforePlan=()=>method==="beginManifest"&&!options.retry?zeroResult(op,"manifestPlan"):{manifest,nextIndex:BigInt(options.verified??0),recordHash:(options.verified??0)===length?recordHash:Z};
  function result(name,args,to,tag) {
    const i=args.length&&typeof args[0]==="bigint"?Number(args[0]-10n):0, blockAfter=tag>=12&&f.minedCapture;
    if(to===pins.checkpoint.address){const values={core:pins.core.address,coreCodeHash:pins.core.codeHash,deploymentChainId:1n,entropySourceSet:pins.source.address,entropySourceSetCodeHash:pins.source.codeHash,factoryDependenciesHash:kind==="scoped"?factoryHash:Z,metadataRouter:pins.router.address,preservationOutputProfile:p.TOKEN_PRESERVATION_OUTPUT_V2_FAMILY,preservationPolicyProfile:p.tokenPreservationOutputV2CheckpointProfile(kind),routerCodeHash:pins.router.codeHash,scoped:kind==="scoped",selectionCheckpoint:pins.selection.address,selectionCodeHash:pins.selection.codeHash,sourceFactory:kind==="scoped"?pins.factory.address:ZA,sourceFactoryCodeHash:kind==="scoped"?pins.factory.codeHash:Z,terminalReadiness:pins.readiness.address,terminalReadinessCodeHash:pins.readiness.codeHash,gasParameter:3000000n};if(name in values)return[values[name]];if(name==="checkpoint")return[blockAfter&&f.minedCapture.stage.kind==="checkpoint"?f.minedCapture.stage.expected:beforeContent()];if(name==="requireCurrentCheckpoint")return[completed];if(name==="outputAt")return[outputs[Number(args[1])]];if(name==="begin")return[key];if(name==="append")return[];}
    if(to===pins.output.address){const values={checkpointCodeHash:pins.checkpoint.codeHash,checkpointProfile:p.tokenPreservationOutputV2CheckpointProfile(kind),core:pins.core.address,coverageCodeHash:pins.coverage.codeHash,deploymentChainId:1n,outputProfile:p.TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_PROFILE,schemaCodeHash:pins.schema.codeHash,schemaRegistry:pins.schema.address,contentCheckpoint:pins.checkpoint.address,artifactCoverage:pins.coverage.address,gasParameter:3000000n};if(name in values)return[values[name]];if(name==="manifestPlan")return[blockAfter&&f.minedCapture.stage.kind==="output"?f.minedCapture.stage.expected:beforePlan()];if(name==="manifestRecord"||name==="requireCurrentManifest")return[manifest];if(name==="beginManifest")return[planHash];if(name==="verifyNextOutputs")return[(BigInt(options.verified??0)+request.count===BigInt(length))?recordHash:Z];}
    if(to===pins.selection.address){if(name==="checkpoint"||name==="requireCurrentCheckpoint")return[selection];if(name==="selectionAt")return[rows[Number(args[1])]];if(name==="metadataHost")return[pins.metadata.address];if(name==="scopeMembership")return[pins.membership.address];}
    if(to===pins.source.address){const values={core:pins.core.address,SOURCE_SET_PROFILE:id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"),factory:pins.factory.address,sourceScope:scope,scopeMembershipFacts:{scopeSubject:H(230),scopeManifestHash:H(231),sourceRecordHash:H(232),tokenCount:BigInt(length),tokenListHash:H(233),membershipHash:selection.membershipHash,inventoryCount:1n,inventoryPrefixHash:H(234)},originalInventoryHash:inventoryHash,originalPolicyChainHash:policyChainHash,inventoryPlan:H(235)};if(name in values)return[values[name]];if(name==="requireCurrentSourceSet")return[];if(name==="tokenEntropyReadiness")return[entropies[i]];}
    if(to===pins.factory.address){if(name==="dependencies")return[factoryDeps];if(name==="currentInventoryPlan")return[H(235)];if(name==="sourceSetForPlan")return[pins.source.address,pins.source.codeHash];if(name==="requireCurrentRoute")return[{componentType:id("ENTROPY_COORDINATOR"),component:pins.source.address,interfaceId:"0x8004d4f5",codeHash:pins.source.codeHash}];}
    if(to===pins.router.address){if(name==="resolvedMetadataConfig")return[configurations[i]];if(name==="staticRenderSourceForConfig"){const index=rows.findIndex(r=>r.configRecordHash===args[1]);return[sources[index],configurations[index].config];}}
    if(to===pins.readiness.address){const values={core:pins.core.address,metadataRouter:pins.router.address,entropySourceSet:pins.source.address};if(name in values)return[values[name]];if(name==="requireTerminalRenderReady")return[terminals[i]];}
    if(to===pins.registry.address&&name==="requirePreservation"){const index=rows.findIndex(r=>r.selection.versionKey===args[0]);const {metadataRouter,...rest}=bindings[index];return[{...rest,router:metadataRouter},admissions[index]];}
    if(to===pins.producer0.address||to===pins.producer1.address){const index=to===pins.producer0.address?0:1,b=bindings[index]??bindings[0];if(name==="preservationProfile")return[b.profile];if(name==="preservationBinding")return[b.core,b.metadataRouter,b.liveRenderer,b.liveRendererCodeHash,b.attribution,b.attributionCodeHash];if(name==="preservationTokenJSON")return{raw:coder.encode(["bytes"],[jsons[i]])};if(name==="preservationTokenHTML")return{raw:coder.encode(["bytes"],[animations[i]])};}
    if(to===pins.core.address){if(name==="coordinatorAtMint")return[pins.entropy.address];if(name==="tokenData")return["0x1234"];if(name==="tokenCollectionIdentity")return[true,9n,args[0],!!options.burned];}
    if(to===pins.entropy.address&&name==="staticTokenRenderFacts")return[5n,Z,A(45)];
    if(to===pins.coverage.address){if(name==="core")return[pins.core.address];if(name==="schemaRegistry")return[pins.schema.address];if(name==="requireArtifactCoverage")return[coverage];if(name==="artifactChunk"){const chunk=chunks[Number(args[1])];return[chunk.address,chunk.codeHash];}}
    if(to===pins.schema.address){const key=args[0],raw=p.tokenPreservationOutputV2Definition(key),index=key===p.TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA?0:1;if(name==="documentBytes")return[raw];if(name==="document")return[{exists:true,status:0n,declarationHash:H(250),specification:{name:index?"STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2":"STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2",kind:BigInt(index),contentHash:keccak256(raw),canonicalizationId:id("RAW_BYTES"),supersedesId:Z,uri:"",totalBytes:BigInt((raw.length-2)/2)},chunkHashes:[keccak256(raw)]}];}
    throw Error(`Unhandled ${to} ${name}`);
  }
  f.provider={async getNetwork(){f.networkHook?.();return{chainId:1n};},async getBlock(tag){return{number:tag,hash:H(10000+tag),timestamp:1000+tag};},async getCode(to,tag){return f.codeHook?.(to,tag)??code.get(to)??"0x";},async call(tx){const iface=targets.get(tx.to);if(!iface)throw Error(`Unknown target ${tx.to}`);const q=iface.parseTransaction({data:tx.data});if(!q)throw Error('Unknown selector');const call={...tx,name:q.name,args:q.args};f.calls.push(call);const altered=await f.hook?.(call);const value=altered??result(q.name,q.args,tx.to,tx.blockTag);return value.raw??iface.encodeFunctionResult(q.name,value);},async getTransactionReceipt(){return f.receipt;},async getTransaction(){return f.transaction;} };
  f.mine=(capture,transport="direct")=>{
    f.minedCapture=capture;const logs=[];const emit=(target,ifc,name,values)=>{const e=ifc.encodeEventLog(ifc.getEvent(name),values);logs.push({address:target,...e});};const s=capture.stage,r=capture.prepared.request;
    if(s.kind==="checkpoint"){if(r.kind==="begin"&&s.before.tokenCount===0n)emit(pins.checkpoint.address,cp,"StaticContentStarted",[1n,s.key,r.salt,s.expected]);if(r.kind==="append"){s.appended.forEach((row,i)=>emit(pins.checkpoint.address,cp,"StaticContentAppended",[1n,s.key,s.before.nextIndex+BigInt(i),row,p.tokenPreservationOutputV2LeafHash(1n,pins.core.address,row.leaf)]));if(s.expected.nextIndex===s.expected.tokenCount)emit(pins.checkpoint.address,cp,"StaticContentCompleted",[1n,s.key,s.expected.contentRoot,s.expected.outputRoot,s.expected.tokenCount]);}}
    else {if(r.kind==="beginManifest"&&s.before.manifest.tokenCount===0n)emit(pins.output.address,op,"OutputManifestStarted",[2n,s.key,s.expected.manifest]);if(r.kind==="verifyNextOutputs"){emit(pins.output.address,op,"OutputManifestAdvanced",[2n,s.key,s.before.nextIndex,s.expected.nextIndex]);if(s.expected.recordHash!==Z)emit(pins.output.address,op,"OutputManifestVerified",[2n,s.expected.recordHash,s.key,s.expected.manifest]);}}
    const txHash=H(900),safeHash=H(901);let from=f.caller,to=capture.prepared.call.to,data=capture.prepared.call.data;
    if(transport!=="direct"){from=A(91);to=f.caller;data=safe.encodeFunctionData("execTransaction",[capture.prepared.call.to,0n,capture.prepared.call.data,0,0,0,0,ZA,ZA,"0x12"]);emit(f.caller,transport==="indexed"?indexedSafe:safe,"ExecutionSuccess",[safeHash,0n]);}
    f.receipt={status:1,hash:txHash,blockNumber:12,blockHash:H(10012),from,to,logs:logs.map((log,index)=>({...log,index,removed:false,transactionHash:txHash,blockNumber:12,blockHash:H(10012)}))};
    f.transaction={hash:txHash,blockNumber:12,blockHash:H(10012),from,to,data,value:0n,chainId:1n};return{txHash,options:transport==="direct"?{execution:"direct"}:{execution:"safe",expectedSafeTxHash:safeHash}};
  };
  return f;
}
