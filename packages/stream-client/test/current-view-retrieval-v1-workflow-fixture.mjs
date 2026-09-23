// Compiler-encoded RPC consistency fixtures only. They do not execute native checkpoint,
// Archive proofs, signatures, Safe guards, nested gas limits or atomic contract rollback.
import { AbiCoder, Interface, SigningKey, ZeroAddress, ZeroHash, computeAddress, getAddress, id, keccak256, sha256, toUtf8Bytes } from 'ethers';
import { compiledInterfaces as compiled } from './current-view-retrieval-v1-fixture.mjs';
import * as p from '../dist/current-view-retrieval-v1.js';
import * as view from '../dist/current-tagged-policy-view-v2.js';
export const coder=AbiCoder.defaultAbiCoder(), Z=ZeroHash, ZA=ZeroAddress;
export const A=n=>getAddress('0x'+BigInt(n).toString(16).padStart(40,'0'));
export const H=n=>id('retrieval-workflow:'+n);
export const host=compiled.StreamViewRetrievalWitnessV1, checkpoint=compiled.IStreamViewPreservationContentCheckpointV1;
export const archive=compiled.IStreamExternalArtifactCoverage, pair=compiled.IStreamExternalArtifactCurrentPair;
export const router=compiled.IStreamMetadataServingFacts, store=compiled.StreamSchemaDocumentStore;
export const capability=new Interface(['function supportsInterface(bytes4 id) view returns(bool)']);
const coreRead=new Interface(['function core() view returns(address)']);
export const safe=new Interface(['function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)',
  'event ExecutionSuccess(bytes32 txHash,uint256 payment)','event ExecutionFailure(bytes32 txHash,uint256 payment)']);
const indexedSafe=new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']);
export const zero=t=>t.baseType==='tuple'?Object.fromEntries(t.components.map(c=>[c.name,zero(c)])):t.baseType==='array'?Array.from({length:t.arrayLength<0?0:t.arrayLength},()=>zero(t.arrayChildren)):t.type==='address'?ZA:t.type==='bool'?false:t.type==='bytes'?'0x':t.type.startsWith('bytes')?Z:t.type==='string'?'':0n;
const stamp=tag=>1000n+BigInt(tag);
export const archiveReceiptHash=(c,r)=>keccak256(coder.encode(['bytes32','uint256','address',archive.getFunction('receipt').outputs[0]],[id('6529STREAM_EXTERNAL_RECEIPT_V1'),c.chainId,c.archive,r]));
function callError(name='InvalidViewRetrieval',args=[]){return Object.assign(Error('Mock original execution refused'),{code:'CALL_EXCEPTION',data:host.encodeErrorResult(name,args)});}
export function setup(options={}) {
  const code=new Map(), pins={};
  for(const [i,name]of ['witness','core','router','checkpoint','archive','artist','finality','provider','metadata','schemas','store','views','membership','registry','renderer','factory','sourceSet','authority','serving','attribution','linked','bytesLinked'].entries()){
    const address=A(i+1),runtime='0x60'+(i+1).toString(16).padStart(2,'0')+'6000';code.set(address,runtime);pins[name]={address,codeHash:keccak256(runtime)};
  }
  const configuration={core:pins.core.address,coreCodeHash:pins.core.codeHash,router:pins.router.address,routerCodeHash:pins.router.codeHash,
    checkpoint:pins.checkpoint.address,checkpointCodeHash:pins.checkpoint.codeHash,archive:pins.archive.address,archiveCodeHash:pins.archive.codeHash,
    chainId:1n,readGas:50000n,sourceGas:1000000n,archiveGas:2000000n,signatureGas:90000n};
  const d={chainId:1n,witness:pins.witness,configuration,linkedDependencies:[pins.linked,pins.bytesLinked],historyLinkedDependencies:[pins.bytesLinked]};
  const hd={chainId:d.chainId,witness:d.witness,configuration,historyLinkedDependencies:d.historyLinkedDependencies};
  const coordinates={chainId:1n,witness:pins.witness.address};
  const scope={scopeType:4n,collectionId:9n,tokenId:0n,scopeId:H(options.scope??'scope')};
  const cp=zero(checkpoint.getFunction('currentSource').outputs[0]);
  cp.adoption.input={scope,viewId:H('view-id'),viewRecordHash:H('declaration'),expectedPrevious:Z,rendererRegistry:pins.registry.address,rendererVersionKey:H('renderer-version'),expectedSourceHash:H('source')};
  const route=cp.adoption.source.route;
  for(const name of ['core','router','artist','finality','provider','metadata','schemas','store'])Object.assign(route,{[name]:pins[name].address,[name+'CodeHash']:pins[name].codeHash});
  route.binding={views:pins.views.address,viewsCodeHash:pins.views.codeHash,membership:pins.membership.address,membershipCodeHash:pins.membership.codeHash,readGas:50000n,sourceGas:1000000n};
  Object.assign(cp.adoption.source.renderer,{registry:pins.registry.address,registryCodeHash:pins.registry.codeHash,renderer:pins.renderer.address,rendererCodeHash:pins.renderer.codeHash});
  for(const name of ['versionKey','rendererId','rendererVersion','contextVersion','schemaHash','readSetHash','registrationHash'])cp.adoption.source.renderer[name]=H(name);
  Object.assign(cp.adoption,{sourceHash:H('adoption-source'),recordHash:H('adoption-record'),revision:1n,actor:A(71),authorizationClass:7n,grantCollectionId:9n,grantRevision:1n,artistConsent:H('consent'),adoptedAt:995n,aggregate:{revision:1n,transitionChain:H('aggregate')}});
  const requestedURI=options.requestedURI??'https://museum.example/image';
  const viewPayload=view.encodeTaggedPolicyViewV2Payload({contextVersion:view.TAGGED_POLICY_VIEW_V2_CONTEXT,name:'Original VIEW',description:'Mock supplied source facts',imageURI:requestedURI,script:'0x3c703e783c2f703e'});
  cp.adoption.source.payloadBytes=BigInt((viewPayload.length-2)/2);cp.adoption.source.payloadHash=keccak256(viewPayload);
  for(const row of p.currentViewRetrievalV1Chunks(viewPayload)){const pointer=A(200+Number(row.index));cp.adoption.source.payloadPointers[Number(row.index)]=pointer;cp.adoption.source.payloadChunkHashes[Number(row.index)]=row.hash;code.set(pointer,row.runtime);}
  Object.assign(cp.policy,{core:pins.core.address,coreCodeHash:pins.core.codeHash,factory:pins.factory.address,factoryCodeHash:pins.factory.codeHash,sourceSet:pins.sourceSet.address,sourceSetCodeHash:pins.sourceSet.codeHash,chainId:1n,scope,inventoryPlan:H('plan'),inventoryHash:H('inventory'),policyChainHash:H('policy-chain'),policyCount:1n});
  cp.preservation={core:pins.core.address,router:pins.router.address,liveRenderer:pins.renderer.address,liveRendererRuntimeHash:pins.renderer.codeHash,preservationAttribution:pins.attribution.address,preservationAttributionRuntimeHash:pins.attribution.codeHash};
  cp.admission={registry:pins.registry.address,registryCodeHash:pins.registry.codeHash,versionKey:H('pv'),registrationHash:H('pr'),readSetHash:H('rs'),analysisHash:H('analysis'),goldenHash:H('golden')};cp.contextHash=H('checkpoint-context');
  const cpConfiguration={core:configuration.core,coreCodeHash:configuration.coreCodeHash,router:configuration.router,routerCodeHash:configuration.routerCodeHash,authority:pins.authority.address,authorityCodeHash:pins.authority.codeHash,serving:pins.serving.address,servingCodeHash:pins.serving.codeHash,servingConfigurationHash:H('serving-config'),chainId:1n,readGas:50000n,servingGas:1000000n};
  const artist={locked:true,registry:pins.artist.address,registryCodeHash:pins.artist.codeHash,artistId:H('artist-id'),bindingGeneration:1n,bindingHash:H('binding'),nominatedArtist:A(70),identityRecordHash:H('identity'),acceptanceRecordHash:H('acceptance'),acceptedAt:990n,lockedAt:994n,snapshotHash:H('artist-snapshot')};
  // Public deterministic test key, never a funded signer or runtime-campaign credential.
  const key=new SigningKey('0x'+'00'.repeat(31)+'02');
  const own=['own-key','7702-own'].includes(options.signatureMode),writer=own?computeAddress(key.publicKey):A(80);
  const caller=options.signatureMode?A(81):writer;
  code.set(writer,options.signatureMode?.startsWith('7702')?'0xef0100'+A(82).slice(2):options.signatureMode==='contract'?'0x60036000':'0x');
  const objects=new Map(),receipts=new Map(),families=new Map();
  function makeObject(label,bytes='0x010203',locator=H(label+'-tx')){
    const object={artistId:artist.artistId,schemaId:H('object-schema'),canonicalizationId:id('RAW_BYTES'),contentHash:keccak256(bytes),sha256Digest:sha256(bytes),arweaveDataRoot:H(label+'-root'),byteSize:BigInt((bytes.length-2)/2),formatId:H('format'),formatCatalogId:H('format-catalog'),formatCatalogHash:H('catalog')};
    const objectHash=H(label+'-object'),firstFamilyRecordHash=H(label+'-family1'),secondFamilyRecordHash=H(label+'-family2'),identifier='0x123456';
    const first={objectHash,familyRecordHash:firstFamilyRecordHash,storageIdentifierHash:keccak256(locator),evidenceClass:H('endowed'),proofProfileHash:H('native-proof'),proofRecordHash:H(label+'-checkpoint'),writer:A(83),observedAt:997n,nonce:1n,deadline:1000n};
    const second={objectHash,familyRecordHash:secondFamilyRecordHash,storageIdentifierHash:keccak256(identifier),evidenceClass:id('ATTESTED_POSSESSION'),proofProfileHash:id('STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1'),proofRecordHash:H('possession'),writer,observedAt:998n,nonce:2n,deadline:1000n};
    const coverage={coverageHash:H(label+'-coverage'),objectHash,artistId:object.artistId,contentHash:object.contentHash,sha256Digest:object.sha256Digest,arweaveDataRoot:object.arweaveDataRoot,byteSize:object.byteSize,firstFamilyRecordHash,secondFamilyRecordHash,firstReceiptHash:archiveReceiptHash(configuration,first),secondReceiptHash:archiveReceiptHash(configuration,second),firstFixityHash:H(label+'-fixity1'),secondFixityHash:H(label+'-fixity2'),checkpointHash:first.proofRecordHash,profileHash:id('STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1')};
    const family=zero(archive.getFunction('family').outputs[0]);Object.assign(family,{familyId:H('family-id'),economics:2n,storingAgent:writer});
    families.set(secondFamilyRecordHash,[family,1n,1n]);receipts.set(coverage.firstReceiptHash,[first,locator,'0x44']);receipts.set(coverage.secondReceiptHash,[second,identifier,'0x55']);
    const {coverageHash,...currentPair}=coverage;const facts={object,coverage,pair:currentPair};objects.set(coverageHash,facts);return facts;
  }
  const target=makeObject('target','0x010203',options.finalTransaction??H('final-tx'));
  let steps=options.steps??[],resolvedURI=options.resolvedURI??requestedURI;
  if(options.arweave){const transactionId='0x'+'11'.repeat(32),manifest=makeObject('manifest','0x7b226d6f636b223a747275657d',transactionId);const root='ar://'+Buffer.from(transactionId.slice(2),'hex').toString('base64url');
    steps=[{kind:3n,fromURI:root+'/index',toURI:resolvedURI,status:0n,manifestObject:manifest.coverage.objectHash,manifestCoverage:manifest.coverage.coverageHash,manifestBytes:'0x7b226d6f636b223a747275657d'}];}
  const observation={source:{scope,core:configuration.core,router:configuration.router,adoptionRecord:cp.adoption.recordHash,adoptionSourceHash:cp.adoption.sourceHash,declaration:route.binding.views,declarationRecord:cp.adoption.input.viewRecordHash,payloadHash:cp.adoption.source.payloadHash,checkpointContextHash:cp.contextHash,requestedURI,artistId:artist.artistId,artistPresentationHash:keccak256(coder.encode([router.getFunction('artistPresentation').outputs[0]],[artist]))},object:target.object,coverage:target.coverage,steps,resolvedURI,writer,observedAt:1000n,nonce:0n,deadline:options.deadline??2000n};
  const request={scope,coverageHash:target.coverage.coverageHash,steps,resolvedURI,observedAt:observation.observedAt,nonce:observation.nonce,deadline:observation.deadline};
  const digest=p.currentViewRetrievalV1Digest(coordinates,configuration,observation);
  const signature=own?key.sign(digest).serialized:options.signature??'0x';
  const payload=p.currentViewRetrievalV1Payload(observation,signature),chunks=p.currentViewRetrievalV1Chunks(payload),chunkRecords=new Map();
  chunks.forEach(row=>{const pointer=A(300+Number(row.index));code.set(pointer,row.runtime);chunkRecords.set(row.hash,[pointer,row.byteLength]);});
  const admission={proof:{backend:1n,coverageHash:target.coverage.coverageHash,objectHash:target.coverage.objectHash},originalBundleHash:H('original-bundle'),immutablePartsHash:H('immutable-parts'),externalOriginal:target.coverage,onchainOriginal:zero(host.getFunction('requireCurrent').outputs[1].components[4])};
  const historical=p.currentViewRetrievalV1PreviewReceipt(coordinates,configuration,observation,signature,1008n);
  const f={d,hd,coordinates,pins,code,configuration,cp,cpConfiguration,artist,objects,receipts,families,observation,request,signature,payload,chunks,chunkRecords,admission,digest,caller,writer,
    historical,mode:options.mode??'publish',mined:null,receipt:null,transaction:null,calls:[],hook:null,codeHook:null,networkHook:null,
    nonceBefore:options.mode==='revoke',epochBefore:0n,revokedBefore:false,missingChunks:false,currentFailure:false,signatureFailure:false,pairRefresh:false,callFailure:null,chainId:1n};
  const after=tag=>f.mined&&tag>=12;
  function recordAt(hash,tag){if(f.mode==='revoke'&&hash===historical.recordHash)return historical;if(after(tag)&&f.mined.kind==='publish'&&hash===f.mined.record.recordHash)return f.mined.record;throw callError('ViewRetrievalUnknown',[hash]);}
  function nonce(tag){return f.nonceBefore||!!(after(tag)&&f.mined.kind==='publish');}
  function value(to,q,tag,tx){const name=q.name,args=q.args;
    if(to===pins.witness.address){
      if(name==='configuration')return[configuration];if(name==='configurationHash')return[p.currentViewRetrievalV1ConfigurationHash(configuration)];if(name==='retrievalProfile')return[p.CURRENT_VIEW_RETRIEVAL_V1_PROFILE];if(name==='supportsInterface')return[args[0]==='0x01ffc9a7'||args[0]===p.currentViewRetrievalV1InterfaceId()];
      if(name==='nonceUsed')return[nonce(tag)];if(name==='revocationEpoch')return[f.epochBefore+(after(tag)&&f.mined.kind==='revoke'?1n:0n)];if(name==='revoked')return[f.revokedBefore||!!(after(tag)&&f.mined.kind==='revoke')];
      if(name==='record')return[recordAt(args[0],tag)];if(name==='encoded'){recordAt(args[0],tag);return[payload];}
      if(name==='prepare'){if(f.currentFailure||stamp(tag)>request.deadline)throw callError();return[observation,digest];}
      if(name==='publish'){if(f.callFailure)throw f.callFailure;if(f.currentFailure||f.signatureFailure||nonce(tag)||f.missingChunks||stamp(tag)>request.deadline)throw callError();return[p.currentViewRetrievalV1PreviewReceipt(coordinates,configuration,observation,args[1],stamp(tag)).recordHash];}
      if(name==='revoke'){if(f.callFailure)throw f.callFailure;const r=recordAt(args[0],tag);if(getAddress(tx.from)!==r.writer||f.revokedBefore)throw callError();return[];}
      if(name==='requireCurrent'||name==='requireCorrespondence'){if(f.currentFailure||f.revokedBefore||after(tag)&&f.mined.kind==='revoke')throw callError();const r=recordAt(args[0],tag);return name==='requireCurrent'?[r,admission]:[observation.source,r,admission];}
      throw Error('Unexpected witness method '+name);
    }
    if(to===pins.checkpoint.address){if(name==='supportsInterface')return[args[0]==='0xc5a3fffa'];if(name==='configuration')return[cpConfiguration];if(name==='checkpointProfile')return[id('6529STREAM_ADOPTED_VIEW_PRESERVATION_CHECKPOINT_V1')];if(name==='currentSource'){if(f.currentFailure)throw callError();return[cp];}throw Error('Unexpected checkpoint method '+name);}
    if(to===pins.router.address){if(name==='core')return[pins.core.address];if(name==='artistPresentation')return[artist];throw Error('Unexpected Router method '+name);}
    if(to===pins.archive.address){
      if(name==='supportsInterface')return[args[0]==='0x138c8955'];if(name==='core')return[pins.core.address];if(name==='profileHash')return[id('STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1')];
      if(name==='coverage')return[objects.get(args[0]).coverage];if(name==='objectIdentity')return[[...objects.values()].find(v=>v.coverage.objectHash===args[0]).object];
      if(name==='receipt')return receipts.get(args[0]);if(name==='family')return families.get(args[0]);
      if(name==='currentReceiptPair'){const row=[...objects.values()].find(v=>v.coverage.firstReceiptHash===args[0]&&v.coverage.secondReceiptHash===args[1]&&v.coverage.artistId===args[2]&&v.coverage.objectHash===args[3]);if(!row)throw callError();return[f.pairRefresh?{...row.pair,firstFixityHash:H('refresh1'),secondFixityHash:H('refresh2')}:row.pair];}
      throw Error('Unexpected Archive method '+name);
    }
    if(to===pins.store.address&&name==='chunk')return f.missingChunks?[ZA,0n]:chunkRecords.get(args[0]);
    throw Error('Unexpected target/method '+to+' '+name);
  }
  const interfaces=new Map([[pins.witness.address,[host]],[pins.checkpoint.address,[checkpoint,capability]],[pins.router.address,[router,coreRead]],[pins.archive.address,[archive,pair]],[pins.store.address,[store]]]);
  f.provider={async getNetwork(){f.networkHook?.();return{chainId:f.chainId};},async getBlock(tag){return{number:tag,hash:H('block-'+tag),timestamp:Number(stamp(tag))};},
    async getCode(address,tag){return f.codeHook?.(getAddress(address),tag)??code.get(getAddress(address))??'0x';},
    async call(tx){const target=getAddress(tx.to);let parsed,ifc;for(const candidate of interfaces.get(target)??[]){try{const decoded=candidate.parseTransaction({data:tx.data});if(decoded){parsed=decoded;ifc=candidate;break;}}catch{}}
      if(!parsed)throw Error('Unexpected mock target/selector');const call={...tx,to:target,name:parsed.name,args:parsed.args};f.calls.push(call);const override=await f.hook?.(call);if(override?.raw)return override.raw;return ifc.encodeFunctionResult(parsed.fragment,override??value(target,parsed,tx.blockTag,tx));},
    async getTransaction(){return f.transaction;},async getTransactionReceipt(){return f.receipt;}};
  f.callRequest=()=>f.mode==='revoke'?{kind:'revoke',recordHash:historical.recordHash,reasonHash:H('reason')}:{kind:'publish',request,signature};
  f.opts=()=>({blockTag:10,gasLimit:10000000n});
  f.mine=(capture,transport='direct')=>{
    const record=capture.stage.kind==='publish'?p.currentViewRetrievalV1PreviewReceipt(coordinates,configuration,capture.stage.preview.observation,capture.prepared.request.signature,stamp(12)):historical;
    f.mined={kind:capture.stage.kind,record};const txHash=H('tx'),blockHash=H('block-12'),logs=[];
    const emit=(address,ifc,name,args)=>logs.push({address,...ifc.encodeEventLog(name,args)});
    if(capture.stage.kind==='publish')emit(pins.witness.address,host,'ViewRetrievalRecorded',[record.recordHash,record.sourceKey,record.writer,record]);
    else emit(pins.witness.address,host,'ViewRetrievalRevoked',[historical.recordHash,capture.prepared.caller,capture.prepared.request.reasonHash]);
    let from=capture.prepared.caller,to=pins.witness.address,data=capture.prepared.call.data,expectedSafeTxHash=null;
    if(transport!=='direct'){expectedSafeTxHash=H('safe-tx');to=capture.prepared.caller;from=A(90);data=safe.encodeFunctionData('execTransaction',[pins.witness.address,0n,data,0n,0n,0n,0n,ZA,ZA,'0x1234']);emit(to,transport==='indexed'?indexedSafe:safe,'ExecutionSuccess',[expectedSafeTxHash,0n]);}
    f.receipt={status:1,hash:txHash,from,to,blockNumber:12,blockHash,logs:logs.map((log,index)=>({...log,index,transactionHash:txHash,blockNumber:12,blockHash,removed:false}))};
    f.transaction={hash:txHash,from,to,data,value:0n,chainId:1n,blockNumber:12,blockHash};
    return{hash:txHash,options:transport==='direct'?{execution:'direct'}:{execution:'safe',expectedSafeTxHash},record};
  };
  return f;
}
