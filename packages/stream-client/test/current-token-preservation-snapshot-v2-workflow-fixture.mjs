// Compiler-encoded source/receipt consistency fixtures. Original nested calls, coverage, producer
// admission and atomicity are mocked; these cases do not execute Solidity or a native Safe.
import { Interface, id, keccak256 } from "ethers";
import { compiledInterfaces as c } from "./current-preservation-v2-fixture.mjs";
import { setup as outputSetup, A, H, Z, ZA, coder, safe, zeroResult } from "./current-token-preservation-output-v2-workflow-fixture.mjs";
import * as p from "../dist/current-token-preservation-snapshot-v2.js";
import * as o from "../dist/current-token-preservation-output-v2.js";
export { A, H, Z, ZA, coder, safe };
const indexedSafe = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)"]);
const ownId=(key,exclude=["supportsInterface"])=>`0x${c[key].fragments.filter(f=>f.type==="function"&&!exclude.includes(f.name)).reduce((a,f)=>a^BigInt(c[key].getFunction(f.format("sighash")).selector),0n).toString(16).padStart(8,"0")}`;
function plain(v) { return v && typeof v.toObject === "function" ? Object.fromEntries(Object.entries(v.toObject()).map(([k,x])=>[k,plain(x)])) : Array.isArray(v) ? v.map(plain) : v; }
export function setup(options={}) {
  const kind=options.scopeKind??"scoped";
  const base=outputSetup({...options,scopeKind:kind,method:"beginManifest"});
  const pins={...base.pins}; const code=base.code;
  const pin=(name,n)=>{const address=A(n),raw=`0x6020${n.toString(16).padStart(4,"0")}`;code.set(address,raw);pins[name]={address,codeHash:keccak256(raw)};};
  pin("snapshot",400);pin("store",401);pin("moduleRegistry",402);pin("historyLink",403);
  const d={chainId:1n,scopeKind:kind,snapshot:pins.snapshot,linkedDependencies:[pins.link],historyLinkedDependencies:[pins.historyLink]};
  const coords={chainId:1n,scopeKind:kind,core:pins.core.address,metadata:pins.metadata.address,snapshot:pins.snapshot.address};
  const targets=["core","metadata","schema","store","router","membership","selection","checkpoint","output","coverage","source"].map(k=>pins[k]);
  const deps={targets:targets.map(x=>x.address),codeHashes:targets.map(x=>x.codeHash),chainId:1n,readGas:300000n,sourceGas:8000000n,inventoryGas:2000000n};
  const factoryDeps={targets:[pins.core.address,pins.metadata.address,pins.membership.address,pins.entropy.address],codeHashes:[pins.core.codeHash,pins.metadata.codeHash,pins.membership.codeHash,pins.entropy.codeHash],chainId:1n,readGas:300000n,inventoryGas:500000n};
  const factoryHash=keccak256(coder.encode([c.StreamFinalityScopedEntropyPolicySourceFactoryV2.getFunction("dependencies").outputs[0]],[factoryDeps]));
  const membership={scopeSubject:p.tokenPreservationSnapshotV2ScopeSubject(1n,pins.core.address,base.scope),scopeManifestHash:H(500),sourceRecordHash:H(501),tokenCount:base.selection.tokenCount,tokenListHash:H(502),membershipHash:base.selection.membershipHash,inventoryCount:1n,inventoryPrefixHash:H(503)};
  const artist={locked:true,registry:pins.registry.address,registryCodeHash:pins.registry.codeHash,artistId:base.manifest.artistId,bindingGeneration:1n,bindingHash:H(510),nominatedArtist:A(90),identityRecordHash:H(511),acceptanceRecordHash:H(512),acceptedAt:1n,lockedAt:2n,snapshotHash:H(513)};
  const policy={...p.decodeTokenPreservationSnapshotV2CoordinatorPolicy(`0x${"00".repeat(832)}`),coordinator:pins.entropy.address,indexedCodeHash:pins.entropy.codeHash,policyHash:H(520),componentDataHash:H(521),frozen:true};
  const source={scope:base.scope,membership,artist,selection:base.selection,content:base.completed,outputs:base.manifest,
    entropy:{planId:H(235),inventoryHash:base.completed.inventoryHash,policyChainHash:base.completed.policyChainHash,policyCount:1n,allFrozen:true,policies:[policy]}};
  const publication={scope:base.scope,snapshotId:H(530),expectedHead:Z,expectedRevision:0n,outputManifestRecord:base.recordHash,coordinatorInventoryPlan:H(235),expectedSourceHash:Z,manifestURI:options.uri??"",effectiveAt:900n,reasonHash:H(531)};
  if(kind==="scoped")Object.assign(source,{sourceFactory:pins.factory.address,sourceFactoryCodeHash:pins.factory.codeHash,factoryDependenciesHash:factoryHash});
  else {
    const m=base.manifest;
    source.rootBinding={profileId:id("6529STREAM_PRESERVATION_POLICY_CONTENT_V2"),outputManifest:pins.output.address,outputManifestCodeHash:pins.output.codeHash,checkpoint:pins.checkpoint.address,checkpointCodeHash:pins.checkpoint.codeHash,checkpointHash:m.checkpointHash,checkpointStateHash:m.checkpointStateHash,entropySourceSet:pins.source.address,entropySourceSetCodeHash:pins.source.codeHash,inventoryHash:m.inventoryHash,policyChainHash:m.policyChainHash,outputRoot:m.outputRoot,outputSchemaHash:o.TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA_HASH,outputCanonicalizationHash:o.TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION_HASH,leafSchemaHash:o.TOKEN_PRESERVATION_OUTPUT_V2_LEAF_SCHEMA_HASH,rootSchemaHash:p.TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_SCHEMA_HASH,rootCanonicalizationHash:p.TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_CANONICALIZATION_HASH,metadataRouter:pins.router.address,preservationOutputProfile:o.TOKEN_PRESERVATION_OUTPUT_V2_FAMILY};
    source.root={publication:{collectionId:base.scope.collectionId,expectedPredecessor:Z,verifiedManifestRecordHash:base.recordHash,manifestURI:""},contentRoot:m.contentRoot,leafCount:m.tokenCount,manifestHash:m.manifestHash,artistId:artist.artistId,bindingGeneration:artist.bindingGeneration,bindingHash:artist.bindingHash,publisher:A(80),authorizationClass:7n,grantRevision:1n,routeHash:H(532),stateHash:H(533),artistConsent:H(534),publishedAt:800n};
    publication.contentRootRecord=p.tokenPreservationSnapshotV2RootRecordHash(1n,pins.router.address,source.root,source.rootBinding);
  }
  const host=c[kind==="collection"?"StreamPreservationPolicySnapshotPublicationV2":"StreamScopedPreservationPolicySnapshotPublicationV2"];
  const authority={authorizationClass:options.snapshotClass??7n,grantRevision:3n,displayAuthorizationClass:options.displayClass??8n,displayGrantRevision:4n};
  const docs=[...(kind==="collection"?p.tokenPreservationSnapshotV2RootDefinitions():[]),...p.tokenPreservationSnapshotV2Definitions(kind)];
  const documentChunks=new Map(),store=new Map(),records=new Map();let nextPointer=5000;
  const retain=raw=>{const chunks=[];for(let offset=2;offset<raw.length;offset+=16384){const data=`0x${raw.slice(offset,offset+16384)}`,hash=keccak256(data);let saved=store.get(hash);if(!saved){saved={pointer:A(nextPointer++),length:BigInt((data.length-2)/2),hash,data};store.set(hash,saved);code.set(saved.pointer,`0x00${data.slice(2)}`);}chunks.push(saved);}return chunks;};
  for(const doc of docs)documentChunks.set(doc.id,retain(doc.data));
  const f={base,d,coords,deps,pins,code,source,publication,authority,docs,documentChunks,store,records,host,caller:A(90),scope:base.scope,calls:[],hook:null,codeHook:null,networkHook:null,receipt:null,transaction:null,head:Z,mined:false,revoked:false,lock:{recordHash:Z,revision:0n,actionId:Z,lockedAt:0n}};
  f.preview=(pub=publication)=>{const sourceHash=p.tokenPreservationSnapshotV2SourceHash(coords,deps,f.source),receipt=p.tokenPreservationSnapshotV2PreviewReceipt(coords,pub,f.caller,f.authority,sourceHash),canonical=p.tokenPreservationSnapshotV2SnapshotBytes(coords,deps,pub,receipt,f.source);return{sourceHash,receipt,canonical};};
  f.refresh=()=>{const v=f.preview();publication.expectedSourceHash=v.sourceHash;f.canonical=v.canonical;f.carriers=retain(v.canonical);return f;};
  f.put=(pub=publication,facts=f.source,time=1012n,prev=Z,grants=f.authority)=>{pub=structuredClone(pub);pub.expectedSourceHash=p.tokenPreservationSnapshotV2SourceHash(coords,deps,facts);let r=p.tokenPreservationSnapshotV2PreviewReceipt(coords,pub,f.caller,grants,pub.expectedSourceHash);const canonical=p.tokenPreservationSnapshotV2SnapshotBytes(coords,deps,pub,r,facts);r={...r,manifestHash:keccak256(canonical),manifestBytes:BigInt((canonical.length-2)/2),recordedAt:time};r.recordHash=p.tokenPreservationSnapshotV2RecordHash(coords,pub,r);r.chainHash=p.tokenPreservationSnapshotV2ChainHash(coords,pub.scope,prev,r.revision,r.recordHash);const item={publication:pub,receipt:r,canonical,carriers:retain(canonical)};records.set(r.recordHash,item);return item;};
  f.refresh();p.validateTokenPreservationSnapshotV2Source(coords,deps,publication,source);
  const contractMap=new Map([[pins.snapshot.address,host],[pins.core.address,c.StreamCore],[pins.metadata.address,c.StreamCollectionMetadataV1],[pins.router.address,c.StreamMetadataRouter],[pins.schema.address,c.StreamSchemaRegistry],[pins.store.address,c.StreamSchemaDocumentStore],[pins.membership.address,c.StreamFinalityScopeMembership],[pins.selection.address,c.StreamStaticSelectionCheckpoint],[pins.checkpoint.address,c[kind==="collection"?"StreamPreservationPolicyContentCheckpointV2":"StreamScopedPreservationPolicyContentCheckpointV2"]],[pins.output.address,c.StreamPreservationPolicyOutputManifestV2],[pins.coverage.address,c.StreamFinalityArtifactCoverage],[pins.source.address,c.StreamFinalityEntropyPolicySourceSet],[pins.factory.address,c.StreamFinalityScopedEntropyPolicySourceFactoryV2],[pins.moduleRegistry.address,c.StreamModuleRegistry]]);
  const current=tag=>tag>=12&&f.mined?records.get(f.head)?.receipt:options.prior?records.get(f.prior)?.receipt:zeroResult(host,"currentSnapshot");
  function result(name,args,to,tag){
    if(name==="supportsInterface")return[args[0]!=="0xffffffff"];
    if(to===pins.snapshot.address){
      if(name==="core")return[coords.core];if(name==="metadataHost")return[coords.metadata];if(name==="dependencies")return[deps];
      if(name==="preservationPolicySnapshotProfile"||name==="scopedPreservationPolicySnapshotProfile")return[p.tokenPreservationSnapshotV2Profile(kind)];
      if(name==="currentSnapshot")return[current(tag)];if(name==="snapshotCount")return[current(tag).revision];if(name==="snapshotLock")return[f.lock];
      if(name==="snapshotAt")return[args[1]===current(tag).revision-1n?current(tag).recordHash:f.prior];
      if(name==="snapshotRecord"){const r=records.get(args[0]);if(!r)throw Error("Unknown snapshot");return[r.publication,r.receipt];}
      if(name==="snapshotPayload")return[records.get(args[0]).canonical];
      if(name==="snapshotChunkCount")return[BigInt(records.get(args[0]).carriers.length)];
      if(name==="snapshotChunkAt"){const chunk=records.get(args[0]).carriers[Number(args[1])];return[chunk.pointer,chunk.hash,chunk.length];}
      if(name==="previewSnapshot"){const v=f.preview(args[0]);return[v.sourceHash,v.canonical];}
      if(name==="requireCurrent")return[records.get(args[1]).receipt];
      if(name==="publishSnapshot")return[f.put(args[0],f.source,BigInt(1000+tag),current(tag).chainHash).receipt.recordHash];
    }
    if(to===pins.core.address&&name==="getSatellitePointer"){
      const which=args[0]===id("COLLECTION_METADATA")?"metadata":args[0]===id("METADATA_ROUTER")?"router":"moduleRegistry";
      const cap=which==="metadata"?ownId("IStreamCollectionMetadataV1"):which==="router"?ownId("IStreamMetadataRouter"):ownId("IStreamModuleRegistry");
      return[pins[which].address,pins[which].codeHash,false,args[0],cap,pins.moduleRegistry.address,1n,H(550),H(551),1n];
    }
    if(to===pins.moduleRegistry.address&&name==="isModuleEligible")return[true];
    if(to===pins.metadata.address){const values={core:coords.core,schemaRegistry:pins.schema.address,chunkStore:pins.store.address,coreCodeHash:pins.core.codeHash,schemaRegistryCodeHash:pins.schema.codeHash,chunkStoreCodeHash:pins.store.codeHash,streamModuleType:id("COLLECTION_METADATA"),streamModuleInterfaceId:ownId("IStreamCollectionMetadataV1")};if(name in values)return[values[name]];if(name==="familyWriter"){const display=args[1]===id("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1"),cl=display?f.authority.displayAuthorizationClass:f.authority.authorizationClass,revision=display?f.authority.displayGrantRevision:f.authority.grantRevision;return[!f.revoked&&args[2]===cl,args[2]===cl?revision:0n];}}
    if(to===pins.router.address){const values={core:coords.core,streamModuleType:id("METADATA_ROUTER"),streamModuleInterfaceId:ownId("IStreamMetadataRouter"),artistPresentation:f.source.artist,collectionContentRootHead:publication.contentRootRecord,contentRootRecord:f.source.root,preservationPolicyContentRootBinding:f.source.rootBinding};if(name in values)return[values[name]];}
    if(to===pins.schema.address){if(name==="chunkStore")return[pins.store.address];const doc=docs.find(d=>d.id===args[0]);if(name==="documentFacts")return[{exists:true,status:0n,kind:doc.kind,contentHash:doc.hash,canonicalizationId:id("RAW_BYTES"),supersedesId:Z,totalBytes:doc.byteLength,declarationHash:H(560),chunkCount:BigInt(documentChunks.get(doc.id).length)}];if(name==="documentChunkHashAt")return[documentChunks.get(doc.id)[Number(args[1])].hash];}
    if(to===pins.store.address){const s=store.get(args[0]);if(name==="chunk")return s?[s.pointer,s.length]:[ZA,0n];if(name==="readChunk")return[s.data];}
    const common={core:coords.core,metadataHost:coords.metadata,metadataRouter:pins.router.address};
    if([pins.membership.address,pins.selection.address,pins.checkpoint.address,pins.output.address,pins.coverage.address,pins.source.address,pins.factory.address].includes(to)&&name in common)return[common[name]];
    if(to===pins.membership.address&&name==="requireScopeMembership")return[f.source.membership];
    if(to===pins.selection.address){if(name==="scopeMembership")return[pins.membership.address];if(name==="checkpoint")return[f.source.selection];}
    if(to===pins.checkpoint.address){const values={selectionCheckpoint:pins.selection.address,entropySourceSet:pins.source.address,entropySourceSetCodeHash:pins.source.codeHash,preservationPolicyProfile:o.tokenPreservationOutputV2CheckpointProfile(kind),preservationOutputProfile:o.TOKEN_PRESERVATION_OUTPUT_V2_FAMILY,sourceFactory:pins.factory.address,sourceFactoryCodeHash:pins.factory.codeHash,factoryDependenciesHash:factoryHash,checkpoint:f.source.content};if(name in values)return[values[name]];}
    if(to===pins.output.address){const values={contentCheckpoint:pins.checkpoint.address,artifactCoverage:pins.coverage.address,schemaRegistry:pins.schema.address,outputProfile:o.TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_PROFILE,requireCurrentManifest:f.source.outputs};if(name in values)return[values[name]];}
    if(to===pins.coverage.address){if(name==="schemaRegistry")return[pins.schema.address];if(name==="chunkStore")return[pins.store.address];}
    if(to===pins.source.address){const values={coreCodeHash:pins.core.codeHash,SOURCE_SET_PROFILE:id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"),factory:pins.factory.address,sourceScope:f.source.scope,scopeMembershipFacts:f.source.membership,inventoryPlan:f.source.entropy.planId,originalInventoryHash:f.source.entropy.inventoryHash,originalPolicyChainHash:f.source.entropy.policyChainHash,sourceCount:f.source.entropy.policyCount};if(name in values)return[values[name]];if(name==="requireCurrentSourceSet")return[];if(name==="sourcePolicyAt")return[f.source.entropy.policies[Number(args[0])]];}
    if(to===pins.factory.address){const values={dependencies:factoryDeps,scopeMembershipHost:pins.membership.address,coordinatorInventory:pins.entropy.address,scopedPolicyFactoryProfile:id("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2"),currentInventoryPlan:f.source.entropy.planId};if(name in values)return[values[name]];if(name==="sourceSetForPlan")return[pins.source.address,pins.source.codeHash];if(name==="requireCurrentRoute")return[{componentType:id("ENTROPY_COORDINATOR"),component:pins.source.address,interfaceId:"0x8004d4f5",codeHash:pins.source.codeHash}];}
    throw Error(`Unhandled ${to} ${name}`);
  }
  f.provider={async getNetwork(){f.networkHook?.();return{chainId:1n};},async getBlock(tag){return{number:tag,hash:H(10000+tag),timestamp:1000+tag};},async getCode(to,tag){return f.codeHook?.(to,tag)??code.get(to)??"0x";},async call(tx){const iface=contractMap.get(tx.to);if(!iface)throw Error(`Unknown target ${tx.to}`);const q=iface.parseTransaction({data:tx.data});const args=Array.from(q.args,plain);const call={...tx,name:q.name,args};f.calls.push(call);const override=await f.hook?.(call);const values=override??result(q.name,args,tx.to,tx.blockTag);return values.raw??iface.encodeFunctionResult(q.name,values);},async getTransactionReceipt(){return f.receipt;},async getTransaction(){return f.transaction;}};
  f.mine=(capture,transport="direct")=>{const item=f.put(capture.prepared.request.publication,capture.stage.source,1012n,capture.stage.before.current.chainHash);f.head=item.receipt.recordHash;f.mined=true;const name=kind==="collection"?"PolicySnapshotPublished":"ScopedPolicySnapshotPublished";const e=host.encodeEventLog(host.getEvent(name),[2n,item.receipt.scopeSubject,item.publication.snapshotId,item.receipt.recordHash,item.publication,item.receipt]);const logs=[{address:pins.snapshot.address,...e}];const txHash=H(900),safeHash=H(901);let from=f.caller,to=pins.snapshot.address,data=capture.prepared.call.data;
    if(transport!=="direct"){from=A(91);to=f.caller;data=safe.encodeFunctionData("execTransaction",[pins.snapshot.address,0n,data,0,0,0,0,ZA,ZA,"0x12"]);const si=transport==="indexed"?indexedSafe:safe;logs.push({address:f.caller,...si.encodeEventLog(si.getEvent("ExecutionSuccess"),[safeHash,0n])});}
    f.receipt={status:1,hash:txHash,blockNumber:12,blockHash:H(10012),from,to,logs:logs.map((log,index)=>({...log,index,removed:false,transactionHash:txHash,blockNumber:12,blockHash:H(10012)}))};f.transaction={hash:txHash,blockNumber:12,blockHash:H(10012),from,to,data,value:0n,chainId:1n};return{txHash,options:transport==="direct"?{execution:"direct"}:{execution:"safe",expectedSafeTxHash:safeHash},item};};
  return f;
}
