// ABI129 RPC consistency fixtures. No real Artist authority, native execution,
// archival ceremony, or nested-gas admission is established by these mocks.
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id, keccak256, toUtf8Bytes } from 'ethers';
import { setup as publicationSetup, A, H, pin, safe } from './current-scoped-policy-publication-v2-workflow-fixture.mjs';
import { fixture, compiledInterfaces as c } from './current-scoped-policy-root-v2-fixture.mjs';
import * as root from '../dist/current-scoped-policy-root-v2.js';
import * as pub from '../dist/current-scoped-policy-publication-v2.js';
import * as graph from '../dist/current-scoped-policy-graph-v2.js';
import { ARTIST_RECOVERY_TERMINAL_TUPLE } from '../dist/current-artist-recovery-adjudication.js';
export { A, H, pin, safe, root, c, fixture };
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
const unique = new Map();
for (const row of [...Object.values(fixture.abis).flat(), ...Object.values(fixture.libraryAbis).flat()]) {
  if (!['function','event'].includes(row.type)) continue;
  if (row.type === 'function' && !Object.values(fixture.abis).some(a => a.includes(row))) continue;
  const f = new Interface([row]).fragments[0];
  if (!unique.has(f.type+f.format('sighash'))) unique.set(f.type+f.format('sighash'),row);
}
export const all = new Interface([...unique.values()]);
const docs = new Map();
for (const suffix of ['StreamScopedPolicyOutputSchemasV2.sol','StreamScopedPolicyContentRootSchemasV2.sol']) {
  const text=Object.entries(fixture.sourceTexts).find(([k])=>k.endsWith(suffix))[1];
  for (const m of text.matchAll(/return bytes\(\s*'([^']+)'/g)) {
    const name=JSON.parse(m[1]).name;
    docs.set(id(name),{name,text:m[1],kind:name.includes('STREAM_ABI')?1n:0n});
  }
}
export const domains=['binding_lifecycle','collaborator_lifecycle','identity_authority','acceptance_lifecycle','attribution_lifecycle','payout_lifecycle','consent_finality'].map(x=>id('domain:'+x));
export const SNAPSHOT='(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)';
const digest=(types,values)=>keccak256(coder.encode(types,values));

export function setup(options={}) {
  const scope=options.scope??{scopeType:1n,collectionId:7n,tokenId:11n,scopeId:ZeroHash};
  const base=publicationSetup({scope,contentBefore:1,outputBefore:1});
  base.state.publicationPresent=true;
  const components=[...Array.from({length:7},(_,i)=>A(800+i)),A(20),A(808),A(1),A(810),A(811),A(5),A(813),A(814),A(815)].map(pin);
  const deployment={chainId:1n,core:pin(A(1)),router:pin(A(5)),metadata:pin(A(2)),finality:pin(A(850)),provider:pin(A(851)),
    artist:{chainId:1n,registry:pin(A(20)),coordinator:pin(A(816)),components,reads:pin(A(817))},
    linkedDependencies:{root:[pin(A(820))],snapshot:[pin(A(120)),pin(A(121))],artist:[pin(A(821))]}};
  const coordinates={chainId:1n,core:A(1),router:A(5),artistRegistry:A(20)};
  const historyDeployment={chainId:1n,core:A(1),artistRegistry:A(20),router:pin(A(5)),linkedDependencies:deployment.linkedDependencies.root};
  const publisher=A(30),signer=options.signer??A(31),caller=options.relay?A(32):signer;
  const authorization={signer,nonce:options.nonce??0n,deadline:options.deadline??2000n,signature:options.signature??'0x'};
  const snapshotReceipt=base.snapshotReceipt(1001n);
  const publication={scope,expectedPredecessor:ZeroHash,snapshotRecordHash:snapshotReceipt.recordHash,snapshotRevision:1n,manifestURI:'ipfs://original-root'};
  const binding={artistId:base.artist.artistId,artistAddress:signer,identityRecordHash:base.artist.identityRecordHash,bindingHash:base.artist.bindingHash,
    generation:1n,consentMode:1n,saleConsentScope:0n,registryImmutabilityElection:0n,proposer:signer,accepted:true};
  const authorityClass=options.authorityClass??1n;
  const authority={address:signer,authorityClass,status:authorityClass===1n?1n:3n,identityRecordHash:binding.identityRecordHash};
  const before=domains.map((domainId,i)=>({domainId,revision:BigInt(4+i),stateRoot:H(900+i),recordChainTip:H(910+i)}));
  const emptySnapshot={domainId:ZeroHash,revision:0n,stateRoot:ZeroHash,recordChainTip:ZeroHash};
  const configurationHash=H(940),currentContent=H(941),postContent=H(942);
  const state={hooks:{},calls:[],after:null,rootAfter:null,consentPresent:options.consentPresent??true,closed:false,
    aggregate:{revision:0n,transitionChain:ZeroHash},legacyHead:ZeroHash,legacyState:H(944),grantClass:options.global?8n:7n,
    rejected:false,code:new Map(),raw:null,logs:[],tx:null,receipt:null,blockHashes:new Map(),network:1n,
    pendingEstate:options.estate?H(947):ZeroHash,notice:{recordHash:options.dormancy?H(948):ZeroHash,phase:options.dormancy?1n:0n,terminalHash:ZeroHash},
    ratification:options.ratified?[true,currentContent,H(949)]:[false,ZeroHash,ZeroHash],evolution:[ZeroHash,ZeroHash],
    ownerPayloads:components.map(()=>[]),archivePayloads:[],replayCells:new Map()};
  if(options.dedup) {
    const row={pointer:A(960),payloadType:id('ARTIST_SIGNATURE_BUNDLE'),payloadHash:keccak256(authorization.signature)};
    state.ownerPayloads[2].push(row); state.archivePayloads.push(row);state.code.set(row.pointer,'0x00'+authorization.signature.slice(2));
  }
  function preview() {
    const route={finality:deployment.finality.address,provider:deployment.provider.address,snapshot:A(203),
      codeHashes:[deployment.core.codeHash,deployment.artist.registry.codeHash,deployment.router.codeHash,deployment.finality.codeHash,deployment.provider.codeHash,pin(A(203)).codeHash],
      metadata:A(2),metadataCodeHash:pin(A(2)).codeHash,scope};
    const prepared=root.scopedPolicyRootV2PreparedRecord(coordinates,{publication,route,source:base.source,dependencies:base.dependencies,receipt:snapshotReceipt,
      publisher,authorizationClass:state.grantClass,grantRevision:1n});
    const legacy=state.legacyHead===ZeroHash?root.scopedPolicyRootV2EmptyLegacyFamily(coordinates,scope.collectionId):state.legacyState;
    const aggregate=root.scopedPolicyRootV2NextAggregate(coordinates,state.aggregate,publication.expectedPredecessor,prepared.record);
    return {...prepared,aggregate,legacy,currentFamily:root.scopedPolicyRootV2FamilyHash(coordinates,scope.collectionId,legacy,state.aggregate),
      nextFamily:root.scopedPolicyRootV2FamilyHash(coordinates,scope.collectionId,legacy,aggregate)};
  }
  function consentRecord(key=H(950)) { return {recordHash:key,artistId:binding.artistId,bindingGeneration:1n,
    terms:{collectionId:scope.collectionId,metadataContract:A(5),familyId:id('CONTENT_ROOT'),newStateHash:preview().nextFamily},authorityClass}; }
  function completed(timestamp) {
    const p=preview(),record={...p.record,artistConsent:state.after?.record.recordHash??H(950),publishedAt:timestamp};
    return {record,binding:p.binding,aggregate:p.aggregate,recordHash:root.scopedPolicyRootV2RecordHash(coordinates,record,p.binding,p.aggregate)};
  }
  const targets=new Map([[A(20),c.artist],[A(816),c.artistCoordinator],[A(800),c.bindingHost],[A(801),c.collaboratorHost],
    [A(802),c.identity],[A(803),c.acceptanceHost],[A(804),c.attributionHost],[A(805),c.payoutHost],[A(806),c.consent],[A(808),c.archive],
    [A(5),c.router],[A(203),c.snapshot],[A(850),c.finality],[A(851),c.provider]]);
  function interfaceFor(target,data) {
    const preferred=targets.get(target);
    return preferred?.parseTransaction({data})?preferred:all;
  }
  const provider={...base.provider,
    getNetwork:async()=>{await state.hooks.network?.();return {chainId:state.network};},
    getBlock:async tag=>{await state.hooks.block?.(tag);return {number:tag,hash:state.blockHashes.get(tag)??H(1000+tag),timestamp:1000+tag};},
    getCode:async(target,tag)=>await state.hooks.code?.(target,tag)??state.code.get(target)??base.provider.getCode(target,tag),
    getTransaction:async()=>{await state.hooks.transaction?.();return state.tx;},
    getTransactionReceipt:async()=>{await state.hooks.receipt?.();return state.receipt;},
    call:async tx=>{
      const target=tx.to,tag=tx.blockTag,iface=interfaceFor(target,tx.data),parsed=iface.parseTransaction({data:tx.data});
      if(!parsed)return base.provider.call(tx);
      const {name:method,args}=parsed,e={target,tag,method,args,tx,iface};state.calls.push(e);
      const override=await state.hooks.call?.(e);
      if(override!==undefined)return typeof override==='string'?override:iface.encodeFunctionResult(method,override);
      const after=tag>=(state.consentBlock??12)?state.after:null,finished=tag>=(state.rootBlock??12)?state.rootAfter:null;
      const i=components.findIndex(x=>x.address===target);
      let values;
      if(method==='getSatellitePointer') {
        const dest=args[0]===id('ARTWORK_FINALITY_REGISTRY')?A(850):args[0]===id('ARTIST_REGISTRY')?A(20):args[0]===id('METADATA_ROUTER')?A(5):A(2);
        values=[dest,pin(dest).codeHash,false,H(991),'0x12345678',A(106),1n,H(992),H(993),1n];
      } else if(method==='core'||method==='coreReads')values=[A(1)];
      else if(method==='artistRegistry'||method==='sanctionReads')values=[A(20)];
      else if(method==='metadataHost'||method==='metadataReads')values=[A(2)];
      else if(method==='scopeEvidenceProvider')values=[A(851)];
      else if(method==='scopeEvidenceProviderCodeHash')values=[pin(A(851)).codeHash];
      else if(method==='finalityRegistry')values=[A(850)];
      else if(method==='finalityRegistryCodeHash')values=[pin(A(850)).codeHash];
      else if(method==='gasParameter')values=[1000000n];
      else if(method==='scopedPolicySnapshotValidationGas')values=[2000000n];
      else if(method==='scopedPolicySnapshotHost')values=[A(203)];
      else if(method==='scopedPolicySnapshotCodeHash')values=[pin(A(203)).codeHash];
      else if(method==='scopedPolicySnapshotProfile')values=[pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE];
      else if(method==='supportsInterface')values=[true];
      else if(method==='collectionExists')values=[true];
      else if(method==='collectionFreezeStatus')values=[false];
      else if(method==='artworkFreezeMode')values=[0n];
      else if(method==='collectionArtistState')values=[2n,1n,binding.artistId,authority.status,binding.bindingHash];
      else if(method==='familyWriter')values=[args[2]===state.grantClass,args[2]===state.grantClass?1n:0n];
      else if(method==='document'&&docs.has(args[0])) {
        const d=docs.get(args[0]);values=[{exists:true,status:0n,declarationHash:H(999),specification:{name:d.name,kind:d.kind,contentHash:keccak256(toUtf8Bytes(d.text)),canonicalizationId:id('RAW_BYTES'),supersedesId:ZeroHash,uri:'ipfs://definition',totalBytes:BigInt(Buffer.byteLength(d.text))},chunkHashes:[]}];
      } else if(method==='documentBytes'&&docs.has(args[0]))values=['0x'+Buffer.from(docs.get(args[0]).text).toString('hex')];
      else if(target===A(203)&&['requireCurrent','currentSnapshot'].includes(method))values=[snapshotReceipt];
      else if(target===A(203)&&method==='snapshotRecord')values=[base.publication,snapshotReceipt];
      else if(target===A(203)&&method==='snapshotAt')values=[snapshotReceipt.recordHash];
      else if(method==='previewScopedPolicyContentRootPublication')values=[preview().nextFamily];
      else if(method==='scopedContentRootHead')values=[finished?.recordHash??publication.expectedPredecessor];
      else if(method==='scopedContentRootAggregate')values=[finished?.aggregate??state.aggregate];
      else if(method==='collectionContentRootHead')values=[state.legacyHead];
      else if(method==='contentRootRecord')values=[{...zero(iface.getFunction(method).outputs[0]),stateHash:state.legacyState}];
      else if(method==='artistContentFamilyState')values=[true,finished?root.scopedPolicyRootV2FamilyHash(coordinates,scope.collectionId,preview().legacy,finished.aggregate):preview().currentFamily];
      else if(method==='currentArtistContentState')values=[A(5),finished?postContent:currentContent];
      else if(method==='artistContentEvolution')values=finished&&state.ratification[0]?[state.ratification[2],postContent]:state.evolution;
      else if(method==='firstReleaseRatification')values=state.ratification;
      else if(method==='consumedArtistContentConsent')values=[!!finished];
      else if(method==='contentConsentEvidence') {
        if(target!==A(20)||tx.from!==A(5))throw Error('Original evidence caller is Router');
        values=[after?.record.recordHash??(state.consentPresent?H(950):ZeroHash)];
      } else if(['contentConsentRecord','contentConsentAt'].includes(method)) {
        if(target!==A(806))throw Error('Wrong immutable Consent owner');values=[after?.record??consentRecord()];
      } else if(method==='scopedContentRootRecord')values=[finished?.record??completed(1012n).record];
      else if(method==='scopedPolicyContentRootBinding')values=[finished?.binding??preview().binding];
      else if(['scopedContentRoot','scopedTokenContentRoot'].includes(method))values=[base.manifest.contentRoot,base.manifest.tokenCount,pub.SCOPED_POLICY_PUBLICATION_V2_LEAF_SCHEMA];
      else if(method==='suiteConfiguration')values=[{registry:A(20),archive:A(808),owners:components.slice(0,7).map(x=>x.address),core:A(1),mintManager:A(810),roleRegistry:A(811),metadata:A(5),primaryResolver:A(813),royaltyResolver:A(814),primaryRevenueClass:H(980),validator:A(815)}];
      else if(method==='configurationHash')values=[configurationHash];
      else if(method==='reads')values=[A(817)];
      else if(method==='deploymentChainId')values=[1n];
      else if(method==='mintManager')values=[A(810)];
      else if(method==='operationCoordinator')values=[A(816)];
      else if(method==='archiveV2')values=[A(808)];
      else if(method==='domainId')values=[domains[i]];
      else if(method==='artistRegistryCutover')values=[false,ZeroAddress,0n];
      else if(method==='binding')values=[binding];
      else if(method==='bindingTerms')values=[{collaboratorSetHash:H(981),capabilityPolicySetHash:H(982),mode:0n,threshold:0n,count:0n}];
      else if(method==='acceptedCount')values=[0n];
      else if(method==='attributionState')values=[2n,1n];
      else if(method==='authorityState')values=[authority.address,authority.authorityClass,authority.status,authority.identityRecordHash];
      else if(method==='currentAuthorityCapabilities')values=[{authorityAddress:signer,authorityClass,status:authority.status,effectiveCapabilities:128n,activationRecordHash:H(983)}];
      else if(method==='gasParameterInfo')values=[400000n,50000n,2n,1n];
      else if(method==='contentConsentDigest')values=[root.prepareScopedPolicyRootV2Call(coordinates,caller,{kind:'recordContentConsent',collectionId:scope.collectionId,newFamilyStateHash:args[0].newStateHash,signer,authorityClass:authorityClass===4n?3n:authorityClass,authorization:{nonce:args[1].nonce,deadline:args[1].time,signature:args[1].signature}}).consent.payload.digest];
      else if(method==='artistAuthorizationState')values=[{digestObserved:!!after,digestRevoked:false,nonceConsumed:!!after,nonceRevoked:false,nextUnusedNonce:after?authorization.nonce+1n:options.nonceHint??authorization.nonce}];
      else if(method==='ownerStateSnapshotV2')values=[after?.snapshots[i]??before[i]];
      else if(method==='artistNativeReceiptCount')values=[after?(i===6?1n:i===2&&options.dormancy?1n:0n):0n];
      else if(method==='artistNativeReceiptAt')values=[after.natives[i]];
      else if(method==='artistNativeReceiptRevisionAt')values=[after.snapshots[i].revision];
      else if(method==='storedPayloadCount')values=[BigInt((i===8?after?.archivePayloads??state.archivePayloads:after?.ownerPayloads[i]??state.ownerPayloads[i]).length)];
      else if(method==='storedPayloadAt'){const rows=i===8?after?.archivePayloads??state.archivePayloads:after?.ownerPayloads[i]??state.ownerPayloads[i];const r=rows[Number(args[0])];values=[r.pointer,r.payloadType,r.payloadHash];}
      else if(method==='dormancyNotice')values=after?.terminal?[state.notice.recordHash,2n,after.terminal.recordHash]:[state.notice.recordHash,state.notice.phase,state.notice.terminalHash];
      else if(method==='estateActivationState')values=after&&authorityClass===1n?[ZeroAddress,0n,ZeroHash]:state.pendingEstate===ZeroHash?[ZeroAddress,0n,ZeroHash]:[A(39),1500n,state.pendingEstate];
      else if(method==='dormancyRecord')values=[{...zero(iface.getFunction(method).outputs[0]),recordHash:state.notice.recordHash},2n,after.terminal];
      else if(method==='signatureBundle')values=[authorization.signature];
      else if(method==='replayCell') {if(!after?.cells.has(args[0]))throw Error('Exact replay key unavailable');values=[after.cells.get(args[0])];}
      else if(method==='artistEvidenceBytesV2')values=[after.archiveBytes];
      else if(method==='artistEvidenceMetadataV2')values=[keccak256(after.archiveBytes),A(961),BigInt((after.archiveBytes.length-2)/2),BigInt(state.consentBlock)];
      else if(['recordContentConsent','publishScopedPolicyContentRootPublication'].includes(method)) {
        if(state.rejected)throw Object.assign(Error('Original execution refused'),{code:'CALL_EXCEPTION'});
        if(method==='recordContentConsent') {
          if(tx.from!==caller)throw Error('Wrong consent caller');
          values=[root.scopedPolicyRootV2ConsentRecordHash(coordinates,{terms:consentRecord().terms,artistId:binding.artistId,signer,authorityClass,nonce:authorization.nonce,observedAt:BigInt(1000+tag)})];
        } else {if(tx.from!==publisher)throw Error('Wrong root publisher');values=[completed(BigInt(1000+tag)).recordHash];}
      } else return base.provider.call(tx);
      const modified=await state.hooks.result?.({...e,values});
      const raw=iface.encodeFunctionResult(method,modified??values);
      return state.raw?state.raw(e,raw):raw;
    }};
  function emit(target,name,args) {
    const row=all.encodeEventLog(all.getEvent(name),args);state.logs.push({address:target,topics:row.topics,data:row.data});
  }
  function replayKey(index,surface,scope_) {return digest(['bytes32','uint256','address','address','address','address','bytes32','bytes32','bytes32'],
    [id('6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2'),1n,A(20),A(816),A(808),components[index].address,domains[index],id(surface),scope_]);}
  function install(capture,mode='direct',block=12) {
    state.logs=[];const consent=capture.kind==='consent';
    if(consent)state.consentBlock=block;else state.rootBlock=block;
    const timestamp=BigInt(1000+block);
    if(consent) {
      const q=capture.prepared.request,recordHash=root.scopedPolicyRootV2ConsentRecordHash(coordinates,{terms:consentRecord().terms,artistId:binding.artistId,signer,authorityClass,nonce:authorization.nonce,observedAt:timestamp});
      const record=consentRecord(recordHash),snapshots=structuredClone(before),ownerPayloads=structuredClone(state.ownerPayloads),archivePayloads=structuredClone(state.archivePayloads),cells=new Map(),natives={};
      for(const i of [2,6])snapshots[i]={...snapshots[i],revision:snapshots[i].revision+1n,stateRoot:H(970+i),recordChainTip:i===2?snapshots[i].recordChainTip:H(979)};
      const sigRow={pointer:A(960),payloadType:id('ARTIST_SIGNATURE_BUNDLE'),payloadHash:keccak256(authorization.signature)};
      if(!options.dedup){ownerPayloads[2].push(sigRow);emit(A(802),'ArtistStoredPayload',[1n,0n,sigRow.payloadType,sigRow.payloadHash,sigRow.pointer]);}
      state.code.set(A(960),'0x00'+authorization.signature.slice(2));
      const addCell=(i,surface,scope_,commitment)=>cells.set(replayKey(i,surface,scope_),{commitment,touchedRevision:snapshots[i].revision,kind:1n,status:2n});
      if(options.estate&&authorityClass===1n){emit(A(802),'ArtistEstateActivationCancelled',[1n,binding.artistId,signer,1n,state.pendingEstate]);addCell(2,'identity_authority.replay.activation_cancellation_key',state.pendingEstate,state.pendingEstate);}
      if(options.activity)emit(A(802),'ArtistUnavailabilityActivityRecorded',[1n,binding.artistId,signer,authorityClass,17n,3n,4n]);
      let terminal=null;
      if(options.dormancy&&authorityClass===1n) {
        const fields={...zero(c.artistDormancy.getFunction('dormancyRecord').outputs[2]),noticeHash:state.notice.recordHash,actor:signer,authorityClass:1n,observedAt:timestamp};
        const cancellationHash=digest(['bytes32','uint256','address','address',ARTIST_RECOVERY_TERMINAL_TUPLE,'uint256'],[id('6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1'),1n,A(20),A(802),fields,1n]);
        terminal={...fields,recordHash:cancellationHash};
        emit(A(802),'ArtistDormancyCancelled',[1n,binding.artistId,state.notice.recordHash,signer,1n,cancellationHash]);
        emit(A(802),'ArtistDormancyCancellationContext',[1n,binding.artistId,cancellationHash,{chainId:1n,registry:A(20),identityOwner:A(802),recorder:signer,recorderAuthorityClass:1n},terminal,1n]);
        natives[2]={operation:42n,artistId:binding.artistId,collectionId:0n,recordHash:cancellationHash};
        addCell(2,'identity_authority.replay.dormancy_cancellation_key',state.notice.recordHash,cancellationHash);
      }
      natives[6]={operation:17n,artistId:binding.artistId,collectionId:scope.collectionId,recordHash};
      emit(A(806),'ArtistContentConsentRecorded',[1n,scope.collectionId,id('CONTENT_ROOT'),signer,record.terms.newStateHash,authorityClass,authorization.nonce,timestamp,recordHash]);
      emit(A(806),'ArtistContentRecordContext',[1n,recordHash,A(5),binding.artistId]);
      const signature=capture.prepared.consent;
      const inner=root.encodeScopedPolicyRootV2ConsentPayload({binding,terms:record.terms,authorization:{nonce:authorization.nonce,deadline:authorization.deadline,signature:authorization.signature},
        proof:{signer,digest:signature.payload.digest,direct:signature.direct},currentFamilyState:capture.preview.currentFamily});
      const archiveBytes=coder.encode(['uint16','bytes32','uint16','address','bytes32',SNAPSHOT+'[7]',SNAPSHOT+'[7]','bytes'],[1n,configurationHash,17n,caller,recordHash,
        before.map((x,i)=>[0,1,2,4,6].includes(i)?x:emptySnapshot),snapshots.map((x,i)=>[0,1,2,4,6].includes(i)?x:emptySnapshot),inner]);
      const evidenceId=root.scopedPolicyRootV2ConsentEvidenceId(coordinates,A(816),caller,recordHash);
      state.code.set(A(961),'0x00'+archiveBytes.slice(2));
      const operation={pointer:A(961),payloadType:id('ARTIST_OPERATION_EVIDENCE'),payloadHash:keccak256(archiveBytes)};
      archivePayloads.push(operation);emit(A(808),'ArtistStoredPayload',[1n,BigInt(archivePayloads.length-1),operation.payloadType,operation.payloadHash,operation.pointer]);
      emit(A(808),'ArtistArchiveEvidenceAppendedV2',[evidenceId,1n,operation.payloadHash,operation.pointer,BigInt((archiveBytes.length-2)/2)]);
      if(!options.dedup){archivePayloads.push(sigRow);emit(A(808),'ArtistStoredPayload',[1n,BigInt(archivePayloads.length-1),sigRow.payloadType,sigRow.payloadHash,sigRow.pointer]);}
      addCell(2,'identity_authority.replay.nonce_allocator',digest(['bytes32','uint256'],[binding.artistId,q.authorization.nonce]),signature.payload.digest);
      addCell(2,'identity_authority.replay.authorization_consumed_digest',digest(['bytes32','bytes32'],[binding.artistId,signature.payload.digest]),signature.payload.digest);
      const innerScope=digest(['(uint256,address,bytes32,bytes32)','uint64'],[Object.values(record.terms),1n]);
      addCell(6,'consent_finality.replay.content_consent_key',digest(['bytes32','bytes32'],[innerScope,recordHash]),recordHash);
      state.after={record,snapshots,ownerPayloads,archivePayloads,archiveBytes,evidenceId,cells,natives,terminal};
    } else {
      const result=completed(timestamp);state.rootAfter=result;
      const subject=graph.scopedPolicyGraphV2ScopeSubject(1n,A(1),scope);
      emit(A(5),'ScopedContentRootPublished',[2n,scope.collectionId,subject,result.recordHash,result.record,result.aggregate]);
      emit(A(5),'ScopedPolicyContentRootBindingPublished',[2n,scope.collectionId,subject,result.recordHash,result.binding]);
      emit(A(5),'ArtistContentConsentApplied',[scope.collectionId,id('CONTENT_ROOT'),capture.consent.recordHash,postContent,1n]);
    }
    const txHash=H(990),blockHash=H(1000+block),call=capture.prepared.call,actor=capture.prepared.caller;
    state.tx={hash:txHash,chainId:1n,blockNumber:block,blockHash,from:actor,to:call.to,data:call.data,value:0n};
    if(mode!=='direct') {
      state.tx={...state.tx,from:A(999),to:actor,data:safe.encodeFunctionData('execTransaction',[call.to,0n,call.data,0n,0n,0n,0n,ZeroAddress,ZeroAddress,'0x01'])};
      const iface=mode==='indexed'?new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']):safe;
      const event=iface.encodeEventLog(iface.getEvent('ExecutionSuccess'),[H(995),0n]);state.logs.push({address:actor,...event});
    }
    state.receipt={hash:txHash,status:1,blockNumber:block,blockHash,from:state.tx.from,to:state.tx.to,logs:state.logs};
    renumber();return {txHash,options:mode==='direct'?{execution:'direct'}:{execution:'safe',expectedSafeTxHash:H(995)}};
  }
  function renumber(){state.logs.forEach((x,i)=>Object.assign(x,{index:i,transactionHash:H(990),blockHash:state.tx?.blockHash??H(1012),blockNumber:state.tx?.blockNumber??12,removed:false}));}
  return {provider,deployment,historyDeployment,coordinates,publication,base,scope,publisher,signer,caller,authorization,state,
    preview,consentRecord,completed,install,renumber,emit,binding,authority,before,snapshotReceipt,replayKey,configurationHash};
}
