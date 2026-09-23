// Compiler-encoded mock of the reviewed source/read boundaries, not an executed native graph.
import assert from 'node:assert/strict';
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as rh from '../dist/current-artist-recovered-multiple-hydration.js';
import * as workflow from '../dist/current-artist-recovered-multiple-hydration-workflow.js';
import { ARTIST_HYDRATION_SUITE_TUPLE } from '../dist/current-artist-authority-hydration.js';
import { fixture, compiledABI, compiledLibraryEvents, compiledLibraryValueInterface, libraryValueABI } from './current-artist-recovered-multiple-hydration-source-fixture.mjs';
export { rh, workflow, fixture };
export const coder=AbiCoder.defaultAbiCoder(), A=n=>getAddress(`0x${BigInt(n).toString(16).padStart(40,'0')}`), H=v=>id(String(v));
export const hash=(types,values)=>keccak256(coder.encode(types,values));
const domains=Array.from({length:7},(_,i)=>rh.artistRecoveredMultipleHydrationOwnerDomain(i));
const ordinary=['registry','coordinator','archive','owner','identity','checkpoint','recoveredOwner','chronology','history','nativeReceipts','reconstruction','timing','coreHost','governanceFacts','finalityRecovery','finalityBinding','entropyUnavailability','entropyFreshRecovery','hydrationOwner','hydrationCoordinator','recoveredCoordinator'];
export const abi=new Interface(ordinary.flatMap(name=>compiledABI(name)).filter(row=>row.type!=='constructor').concat(compiledLibraryEvents('commit').fragments));
// Concrete compiler ABIs are immutable fixture inputs; parse each target alias once.
const targetInterfaces=new Map(['binding','collaborator','identity','acceptance','attribution','payout','consent','registry','archive','coordinator','coreHost'].map(name=>[name,new Interface(compiledABI(name))]));
export const preparedAbi=compiledLibraryValueInterface('prepared');
export const safeABI=new Interface(['function nonce() view returns(uint256)','function getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256) view returns(bytes32)','function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) payable returns(bool)','event ExecutionSuccess(bytes32 txHash,uint256 payment)','event ExecutionFailure(bytes32 txHash,uint256 payment)']);
const indexedSafe=new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)','event ExecutionFailure(bytes32 indexed txHash,uint256 payment)']);
const safeTypes={SafeTx:['to:address','value:uint256','data:bytes','operation:uint8','safeTxGas:uint256','baseGas:uint256','gasPrice:uint256','gasToken:address','refundReceiver:address','nonce:uint256'].map(s=>{const[name,type]=s.split(':');return{name,type};})};
export const safeHash=(chainId,address,values)=>TypedDataEncoder.hash({chainId,verifyingContract:address},safeTypes,Object.fromEntries(safeTypes.SafeTx.map((f,i)=>[f.name,values[i]])));
const zeroCell=()=>({commitment:ZeroHash,touchedRevision:0n,kind:0n,status:0n});
export function zeroValue(value){const p=typeof value==='string'?ParamType.from(value):value;if(p.baseType==='tuple')return Object.fromEntries(p.components.map(f=>[f.name,zeroValue(f)]));if(p.baseType==='array')return Array.from({length:Math.max(0,p.arrayLength)},()=>zeroValue(p.arrayChildren));if(p.type==='address')return ZeroAddress;if(p.type==='bool')return false;if(p.type==='string')return '';if(p.type==='bytes')return '0x';if(p.type.startsWith('bytes'))return `0x${'00'.repeat(Number(p.type.slice(5)))}`;return 0n;}

const abiTypes = new Map();
function findType(name) {
  if (abiTypes.has(name)) return abiTypes.get(name);
  function visit(p) {
    if (p.internalType === `struct ${name}`) return ParamType.from({ ...p, name: "" });
    for (const c of p.components ?? []) { const found = visit(c); if (found) return found; }
  }
  for (const group of [fixture.abis, fixture.libraryAbis]) {
    for (const [key, entries] of Object.entries(group)) {
      const rows = group === fixture.libraryAbis ? libraryValueABI(key) : entries;
      for (const e of rows) for (const p of [...(e.inputs ?? []), ...(e.outputs ?? [])]) {
        const found = visit(p); if (found) { abiTypes.set(name, found); return found; }
      }
    }
  }
  throw Error(`Missing compiler tuple ${name}`);
}
const T = {
  state: findType("StreamArtistRecoveredMultipleTypes.State"),
  identity: findType("StreamArtistRecoveredIdentityHydrationTypes.Bundle"),
  payout: findType("StreamArtistRecoveredPayoutTypes.Bundle"),
  binding: findType("StreamArtistRecoveredSimpleHydrationTypes.Binding"),
  acceptance: findType("StreamArtistRecoveredSimpleHydrationTypes.Acceptance"),
  attribution: findType("StreamArtistRecoveredCollectionHydration.AttributionBundle"),
  policy: findType("StreamArtistRecoveredCollectionHydration.PolicyBundle"),
};
// Select overload by arity; the retained nominal selector is checked separately.
T.prepared = compiledLibraryValueInterface("prepared").fragments.find(f => f.type === "function" && f.name === "prepare" && f.inputs.length === 2).outputs[0];
function zero(t) {
  if (t.baseType === "array") return Array.from({ length: t.arrayLength < 0 ? 0 : t.arrayLength }, () => zero(t.arrayChildren));
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(c => [c.name, zero(c)]));
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  if (t.type === "bytes") return "0x";
  if (t.type.startsWith("bytes")) return "0x" + "00".repeat(Number(t.type.slice(5)));
  return 0n;
}
const child = (t, name) => t.components.find(c => c.name === name);
const emptyHash = domain => hash(["bytes32", "bytes32[]"], [id(domain), []]);


function semanticFixture({source:suite,origin,before,options,codes}) {
  const {classes=[1n,3n],oneArtist=false}=options; const m=rh,Z=ZeroHash,clone=structuredClone,seven=fn=>Array.from({length:7},(_,i)=>fn(i));
  const H=n=>"0x"+BigInt(n).toString(16).padStart(64,"0");
  const ids = oneArtist ? [H(1000)] : [H(1000), H(1001)];
  const chainId=origin.chainId;
  const originHash = m.artistRecoveredMultipleHydrationOriginHash(origin);
  const collections = [0, 1].map(i => ({ artistId: ids[oneArtist ? 0 : 1 - i], collectionId: (1n << 240n) + BigInt(i + 3), bindingHash: Z, policies: [], records: [] }));
  const bindings = collections.map((q, i) => {
    const b = zero(T.binding);
    Object.assign(b.item, { artistId: q.artistId, artistAddress: A(50 + i), identityRecordHash: H(1200 + i), generation: 1n,
      consentMode: 1n, proposer: A(70), accepted: true });
    q.bindingHash = hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"],
      [id("6529STREAM_ARTIST_BINDING_V1"), chainId, suite.registry, suite.core, q.collectionId, 1n, q.artistId, b.item.artistAddress,
        b.item.identityRecordHash, 1n, 0n, 0n, emptyHash("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), emptyHash("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1")]);
    b.item.bindingHash = q.bindingHash; b.history = clone(b.item);
    b.scope = { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash };
    b.terms.collaboratorSetHash = emptyHash("6529STREAM_ARTIST_COLLABORATOR_SET_V1");
    b.terms.capabilityPolicySetHash = emptyHash("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1");
    return b;
  });
  const journals = seven(() => []), logical = seven(() => []), aliases = seven(() => []);
  function row(owner, operation, artistId, collectionId, recordHash, revision) {
    const item = { position: { point: { environmentHash: originHash, ownerIndex: BigInt(owner), ownerRevision: revision }, nativeIndex: BigInt(journals[owner].length) },
      receipt: { operation, artistId, collectionId, recordHash } };
    journals[owner].push(item); return item;
  }
  function alias(owner, j, surface, scope) {
    const logicalRow = { surface: id(surface), scope }; logical[owner].push(logicalRow);
    aliases[owner].push({ originHash, ownerIndex: BigInt(owner), ...logicalRow,
      originalKey: m.artistRecoveredMultipleHydrationReplayKey(origin, owner, logicalRow),
      cell: { commitment: j.receipt.recordHash, touchedRevision: j.position.point.ownerRevision, kind: 1n, status: 2n }, admittedAt: clone(j.position.point) });
  }
  collections.forEach((q, i) => {
    const j = row(0, 1n, q.artistId, q.collectionId, q.bindingHash, BigInt(2 * i + 1));
    alias(0, j, "binding_lifecycle.replay.proposal_key", hash(["uint256", "uint64"], [q.collectionId, 1n]));
    const a = row(3, 2n, q.artistId, q.collectionId, H(1300 + i), BigInt(i + 1));
    alias(3, a, "acceptance_lifecycle.replay.record_uniqueness", H(1400 + i));
  });
  ids.forEach((artistId, i) => {
    row(2, 1n, artistId, 0n, artistId, BigInt(3 * i + 1));
    row(2, 35n, artistId, 0n, H(1500 + i), BigInt(3 * i + 2));
    row(2, 35n, artistId, 0n, H(1600 + i), BigInt(3 * i + 2));
  });
  for (const rows of aliases) rows.sort((a, b) => BigInt(a.originalKey) < BigInt(b.originalKey) ? -1 : 1);
  const nonces = ids.toReversed().map(artistId => ({ index: { kind: 1n, key: artistId, prefixCount: 1n }, words: [{ prefix: 0n, words: Array.from({ length: 32 }, (_, i) => i === 0 ? 1n : 0n), exhausted: false }] }));
  const checkpoints = seven(i => ({ schema: m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_CHECKPOINT_SCHEMA,
    ownerState: { domainId: m.artistRecoveredMultipleHydrationOwnerDomain(i), revision: [4n, 0n, 10n, 2n, 4n, 0n, 0n][i], stateRoot: H(200 + i), recordChainTip: H(220 + i) },
    replayRoot: aliases[i].length ? H(240 + i) : Z, replayCount: BigInt(aliases[i].length), nonceRoot: i === 2 ? H(280) : Z, nonceIndexCount: i === 2 ? BigInt(nonces.length) : 0n }));
  for (const [domain, field] of [["STATE", "stateRoot"], ["RECORD", "recordChainTip"]]) checkpoints[1].ownerState[field] = hash(
    ["bytes32", "uint256", "address", "address", "address", "address", "bytes32"],
    [id(`6529STREAM_ARTIST_OWNER_${domain}_GENESIS_V2`), chainId, origin.registry, origin.coordinator, origin.archive, origin.owners[1], m.artistRecoveredMultipleHydrationOwnerDomain(1)]);
  const provenance = { origins: [origin], eras: [{ originHash, priorImportCommitment: Z, checkpoints, nativeCounts: journals.map(rows => BigInt(rows.length)), lowerRevisions: seven(() => 0n) }], journals, aliases };
  const artists = ids.map(artistId => ({ artistId, collectionId: 0n, bindingHash: Z, policies: [], records: journals.flat().filter(j => j.receipt.artistId === artistId).map(j => j.receipt.recordHash) }));
  collections.forEach(q => { q.records = journals.flat().filter(j => j.receipt.collectionId === q.collectionId).map(j => j.receipt.recordHash); });
  const timing = { schema: id("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1"), version: 1n, count: 0n, root: Z, configurationHash: H(400) };
  const identities = artists.map((a, i) => {
    const b = zero(T.identity); b.artistId = a.artistId; b.sourceSnapshot = clone(checkpoints[2].ownerState); b.nextRegistrationNonce = BigInt(artists.length);
    Object.assign(b.identity, { authorityAddress: A(400 + i), authorityClass: classes[i], status: 1n });
    b.timing.checkpoint = clone(timing);
    b.nonces = [{ kind: 1n, key: a.artistId, hint: 0n, words: clone(nonces.find(n => n.index.key === a.artistId).words) }];
    const recovery = zero(child(T.identity, "recoveries").arrayChildren); recovery.record.fields.vestedAuthorityClass = classes[i];
    b.recoveries = [recovery]; return b;
  });
  const payouts = artists.map(a => { const b = zero(T.payout); b.artistId = a.artistId; b.sourceSnapshot = clone(checkpoints[5].ownerState); return b; });
  const states = seven(owner => {
    const local = m.artistRecoveredMultipleHydrationOwnerProvenance(provenance, owner), commitment = m.artistRecoveredMultipleHydrationOwnerProvenanceHash(local, owner);
    let rows = [];
    if (owner === 0) rows = bindings.map(b => { b.provenanceCommitment = commitment; return coder.encode([T.binding], [b]); });
    if (owner === 2) rows = identities.map(b => coder.encode([T.identity], [b]));
    if (owner === 3) rows = collections.map((q, i) => coder.encode([T.acceptance], [{ scope: { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash }, provenanceCommitment: commitment, record: H(1300 + i), acceptedAt: 1n }]));
    if (owner === 4) rows = collections.map(q => coder.encode([`tuple(${T.attribution.format("full")} state,bytes32 proposalOrigin)`], [{ state: { provenance: commitment, artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash, item: { state: 2n, generation: 1n } }, proposalOrigin: originHash }]));
    if (owner === 5) rows = payouts.map(b => coder.encode(["bytes32", T.payout], [id("6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1"), b]));
    if (owner === 6) rows = collections.map(q => coder.encode([T.policy], [{ provenance: commitment, artistId: q.artistId, collectionId: q.collectionId, policies: [], records: [] }]));
    return { artists: clone(artists), collections: clone(collections), rows };
  });
  const features = 262144n | classes.slice(0, artists.length).reduce((bits, c) => bits | (c === 1n ? 1n : 2n), 0n);
  for(const i of [2,4,6])codes.set(A(90+i),"0x001234");
  const data = seven(i => {
    const local = m.artistRecoveredMultipleHydrationOwnerProvenance(provenance, i);
    const payload = { provenance: local, nonces: i === 2 ? clone(nonces) : [], publications: [2,4,6].includes(i) ? [{pointer:A(90+i),payloadType:H(800+i),payloadHash:keccak256("0x1234")}] : [], semanticState: coder.encode(["bytes32", "uint16", "uint8", T.state], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_BASE_V1"), 1n, BigInt(i), states[i]]) };
    const sourceKeys = logical[i].map(v => m.artistRecoveredMultipleHydrationReplayKey(origin, i, v));
    return { typedState: m.encodeArtistRecoveredMultipleHydrationOwnerPayload(payload, i, features), origins: logical[i], sourceKeys,
      cells: sourceKeys.map(key => aliases[i].find(a => a.originalKey === key).cell), nonces: [] };
  });
  const before_=before;
  const query = { ...clone(collections[0]), records: clone(artists.find(a => a.artistId === collections[0].artistId).records) };
  const prepared = { admission: { prior: origin.registry, sourceCoordinator: origin.coordinator, source: suite, provenance, artists, collections, before_ }, query, data, timing,
    externalGuards: { schema: id("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1"), provenanceCommitment: m.artistRecoveredMultipleHydrationProvenanceHash(provenance), artistId: ids[0], actions: [], finality: [], entropy: [] } };
  const request = { records: { authority: { bindingIndex: 0n, artistIds: ids, collections: collections.map(q => ({ artistId: q.artistId, collectionId: q.collectionId, policies: [] })), expectedSource: checkpoints, replayOrigins: logical }, witnesses: [] },
    expectedCapabilities: seven(i => ({ profile: m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_PROFILE, version: 1n, ownerIndex: BigInt(i), ownerDomain: m.artistRecoveredMultipleHydrationOwnerDomain(i), checkpointSchema: m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_CHECKPOINT_SCHEMA, stateSchema: m.artistRecoveredMultipleHydrationOwnerTag(i), supportedFeatures: 524287n })),
    expectedSourceImportCommitment: Z, expectedSemanticInventory: ZeroHash };
  return { request, certificate:prepared, states, identities, payouts, nonces, provenance, features, origin, bindings };
}


export function setup(options={}) {
  const codes=new Map(), pin=n=>{const address=A(n),code=`0x61${BigInt(n).toString(16).padStart(4,'0')}6000`;codes.set(address,code);return{address,codeHash:keccak256(code)};};
  const common=Array.from({length:7},(_,i)=>pin(50+i)),sourcePins=Array.from({length:9},(_,i)=>pin(10+i)).concat(common),destinationPins=Array.from({length:9},(_,i)=>pin(30+i)).concat(common);
  const deployment={chainId:1n,source:{registry:sourcePins[7],coordinator:pin(70),components:sourcePins},destination:{registry:destinationPins[7],coordinator:pin(71),components:destinationPins},preparationLibrary:pin(72),preparationDependencies:[pin(73)]};
  const caller=A(80);const safePin=pin(80);
  const suite=p=>({owners:p.slice(0,7).map(v=>v.address),registry:p[7].address,archive:p[8].address,core:p[9].address,mintManager:p[10].address,roleRegistry:p[11].address,metadata:p[12].address,primaryResolver:p[13].address,royaltyResolver:p[14].address,validator:p[15].address,primaryRevenueClass:H('PRIMARY_SALE')});
  const source=suite(sourcePins),destination=suite(destinationPins),origin={chainId:1n,registry:source.registry,coordinator:deployment.source.coordinator.address,archive:source.archive,owners:source.owners,ownerCodeHashes:sourcePins.slice(0,7).map(v=>v.codeHash),core:source.core,manager:source.mintManager,suiteConfigurationHash:hash([ARTIST_HYDRATION_SUITE_TUPLE],[source])};
  const before=domains.map((domainId,i)=>({domainId,revision:i===2?1n+BigInt((options.oneArtist?1:2)+2):0n,stateRoot:H(`destination root ${i}`),recordChainTip:H(`destination tip ${i}`)}));
  const material=semanticFixture({source,destination,origin,before,options,codes});
  const {certificate,request}=material,provenance=certificate.admission.provenance,checkpoints=provenance.eras.at(-1).checkpoints,journals=provenance.journals;
  // Keep at most seven entries. Any changed canonical bytes must pass the full decoder again.
  const ownerPayloadCache=new Map();
  const ownerPayload=i=>{
    const bytes=certificate.data[i].typedState, previous=ownerPayloadCache.get(i);
    if(previous?.bytes===bytes)return previous.payload;
    const payload=rh.decodeArtistRecoveredMultipleHydrationOwnerPayload(bytes,i).payload;
    ownerPayloadCache.set(i,{bytes,payload});return payload;
  };
  const sourceCatalogs=new Map([2,4,6].map(i=>[source.owners[i],ownerPayload(i).publications]));
  const state={codes,hooks:[],calls:[],mined:false,captured:null,catalogs:new Map(),metadata:new Map(),evidence:new Map(),
    beforeCatalogs:new Map([destination.owners[2],destination.owners[4],destination.owners[6],destination.archive].map(host=>[host,[]])),
    capabilities:request.expectedCapabilities,certificate,tx:null,receipt:null,safeNonce:4n,safeEndingNonce:5n,transactionHook:null,blockOverride:null};
  const sourceHosts=[...source.owners,source.registry,source.archive,deployment.source.coordinator.address];
  const provider={
    async getNetwork(){return{chainId:1n};},
    async getBlock(tag){return state.blockOverride?.(tag)??{number:tag,timestamp:100+tag,hash:H(`block${tag}`)};},
    async getCode(host,tag){for(const hook of state.hooks){const r=hook({method:'getCode',host:getAddress(host),tag});if(r!==undefined)return r;}return codes.get(getAddress(host))??'0x';},
    async call(tx){
      const host=getAddress(tx.to),tag=tx.blockTag;let fragment,args,selectedAbi=abi;
      if(host===caller){selectedAbi=safeABI;fragment=safeABI.getFunction(tx.data.slice(0,10));args=safeABI.decodeFunctionData(fragment,tx.data);}
      else if(tx.data.slice(0,10)===rh.ARTIST_RECOVERED_MULTIPLE_HYDRATION_PREPARE_SELECTOR){
        assert.equal(host,deployment.preparationLibrary.address);selectedAbi=preparedAbi;fragment=preparedAbi.fragments.find(f=>f.type==='function'&&f.name==='prepare'&&f.inputs.length===2);args=preparedAbi.decodeFunctionData(fragment,`${fragment.selector}${tx.data.slice(10)}`);
      }else{
        const ownerNames=['binding','collaborator','identity','acceptance','attribution','payout','consent'];
        const ownerIndex=source.owners.includes(host)?source.owners.indexOf(host):destination.owners.indexOf(host);
        const name=ownerIndex>=0?ownerNames[ownerIndex]:[source.registry,destination.registry].includes(host)?'registry':
          [source.archive,destination.archive].includes(host)?'archive':[deployment.source.coordinator.address,deployment.destination.coordinator.address].includes(host)?'coordinator':host===source.core?'coreHost':null;
        if(!name)throw Error('Unknown fixture target');
        const targetABI=targetInterfaces.get(name);fragment=targetABI.getFunction(tx.data.slice(0,10));
        if(!fragment)throw Error('Unsupported target getter');args=targetABI.decodeFunctionData(fragment,tx.data);
      }
      const method=fragment.name,encode=values=>selectedAbi.encodeFunctionResult(fragment,values);state.calls.push({method,host,tag,args,from:tx.from,value:tx.value,gasLimit:tx.gasLimit});
      for(const hook of state.hooks){const result=hook({method,host,tag,args,fragment,tx});if(result!==undefined)return typeof result==='string'?result:encode(result);}
      if(host===caller){if(method==='nonce')return encode([tag>=12?state.safeEndingNonce:state.safeNonce]);if(method==='getTransactionHash')return encode([safeHash(1n,caller,Array.from(args))]);throw Error('Unexpected Safe fixture call');}
      const isSource=sourceHosts.includes(host),selected=isSource?source:destination,owner=selected.owners.indexOf(host),post=state.mined&&tag>=12&&!isSource;
      const payload=owner>=0?ownerPayload(owner):null;
      switch(method){
        case 'prepare':assert.equal(tx.value,0n);return encode([state.certificate]);
        case 'hydrateRecoveredArtistAuthority':assert.equal(host,destination.registry);assert.equal(tx.value,0n);return encode([state.captured.commitment]);
        case 'authorityHydrationSuite':return encode([selected]);
        case 'deploymentChainId':return encode([1n]);
        case 'core':return encode([selected.core]);
        case 'mintManager':return encode([selected.mintManager]);
        case 'artistRegistry':return encode([selected.registry]);
        case 'operationCoordinator':return encode([isSource?deployment.source.coordinator.address:deployment.destination.coordinator.address]);
        case 'archiveV2':return encode([selected.archive]);
        case 'domainId':return encode([domains[owner]]);
        case 'configurationHash':return encode([H('destination configuration')]);
        case 'gasParameterInfo':return encode([1000000n,1n,2n,1n]);
        case 'getSatellitePointer':return encode([destination.registry,deployment.destination.registry.codeHash,true,H('ARTIST_REGISTRY'),'0x00000000',A(3),1n,H('deploy'),H('module'),1n]);
        case 'artistRegistryCutover':return encode(isSource?[true,destination.registry,90n]:[false,ZeroAddress,0n]);
        case 'importedHistoryBindingCount':return encode([1n]);
        case 'importedHistoryBinding':return encode([source.registry,1n,H('history'),H('binding')]);
        case 'artistHistoryPredecessorBinding':return encode([true,deployment.source.registry.codeHash,90n]);
        case 'importedLaneVerified':case 'artistHistoryLane':{
          const q=args[0]===1n?certificate.admission.artists.find(v=>v.artistId===args[1]):certificate.admission.collections.find(v=>v.collectionId===BigInt(args[1]));if(!q)throw Error('Unknown fixture lane');
          const value=[H(`lane${args[0]}:${args[1]}`),BigInt(q.records.length)];return encode(method==='importedLaneVerified'?[true,...value]:value);
        }
        case 'ownerStateSnapshotV2':return encode([isSource?checkpoints[owner].ownerState:post?state.captured.after[owner]:before[owner]]);
        case 'authorityCheckpoint':return encode([isSource?checkpoints[owner]:{schema:rh.ARTIST_RECOVERED_MULTIPLE_HYDRATION_CHECKPOINT_SCHEMA,ownerState:post?state.captured.after[owner]:before[owner],replayCount:owner===2?2n+2n*BigInt(certificate.admission.artists.length+certificate.admission.collections.length):0n,replayRoot:H(`destination replay${owner}`),nonceIndexCount:post?BigInt(payload.nonces.length):0n,nonceRoot:H(`destination nonce${owner}`)}]);
        case 'nextRegistrationNonce':return encode([isSource||post?BigInt(certificate.admission.artists.length):0n]);
        case 'recoveredAuthorityHydrationCapability':return encode([state.capabilities[owner]]);
        case 'authorityHydrationCommitment':return encode([post?state.captured.commitment:ZeroHash]);
        case 'recoveredHydrationImportedPrefix':return encode(post?[payload.provenance,state.captured.commitment,state.captured.after[owner].revision]:[{origins:[],eras:[],journal:[],aliases:[]},ZeroHash,0n]);
        case 'artistNativeReceiptCount':return encode([isSource?BigInt(journals[owner].length):0n]);
        case 'artistNativeReceiptAt':return encode([journals[owner][Number(args[0])].receipt]);
        case 'artistNativeReceiptRevisionAt':return encode([journals[owner][Number(args[0])].position.point.ownerRevision]);
        case 'authorityReplayAt':return encode([certificate.data[owner].sourceKeys[Number(args[0])],certificate.data[owner].cells[Number(args[0])]]);
        case 'replayCell':{
          const data=certificate.data[owner];if(isSource)return encode([data.cells[data.sourceKeys.indexOf(args[0])]]);
          const target={...origin,registry:destination.registry,coordinator:deployment.destination.coordinator.address,archive:destination.archive,owners:destination.owners,ownerCodeHashes:destinationPins.slice(0,7).map(v=>v.codeHash),suiteConfigurationHash:hash([ARTIST_HYDRATION_SUITE_TUPLE],[destination])};
          const index=data.origins.findIndex(v=>rh.artistRecoveredMultipleHydrationReplayKey(target,owner,v)===args[0]);
          if(index<0)return encode([zeroCell()]);const name=data.origins[index].surface;
          if(name===H('identity_authority.replay.one_way_cutover_latch'))return encode([zeroCell()]);
          if(owner===2&&['verified_lane_key','import_binding'].some(n=>name===H(`identity_authority.replay.${n}`)))return encode([{commitment:H(`destination guard${index}`),touchedRevision:before[2].revision,kind:1n,status:2n}]);
          return encode([post?data.cells[index]:zeroCell()]);
        }
        case 'recoveredHydrationReplayPoint':return encode([payload.provenance.aliases.find(v=>v.originalKey===args[0]).admittedAt]);
        case 'authorityNonceIndexAt':return encode([payload.nonces[Number(args[0])].index]);
        case 'authorityNonceWordAt':{const row=payload.nonces.find(v=>v.index.kind===args[0]&&v.index.key===args[1]).words[Number(args[2])];return encode([row.prefix,row.words,row.exhausted]);}
        case 'recoveredTimingCheckpoint':return encode([certificate.timing]);
        case 'recoveredTimingEntryAt':throw Error('No timing mutations in compact fixture');
        case 'artistArchiveMaxEvidenceBytesV2':return encode([24575n]);
        case 'storedPayloadCount':return encode([BigInt((isSource?sourceCatalogs.get(host):post?state.catalogs.get(host):state.beforeCatalogs.get(host))?.length??0)]);
        case 'storedPayloadAt':{const row=(isSource?sourceCatalogs.get(host):post?state.catalogs.get(host):state.beforeCatalogs.get(host))[Number(args[0])];return encode([row.pointer,row.payloadType,row.payloadHash]);}
        case 'artistEvidenceMetadataV2':return encode(state.metadata.get(args[0]));
        case 'artistEvidenceBytesV2':return encode([state.evidence.get(args[0])]);
        default:throw Error(`Unexpected original mock method ${method}`);
      }
    },
    async getTransaction(hash){if(state.transactionHook)state.transactionHook(hash);return state.tx;},async getTransactionReceipt(){return state.receipt;}
  };
  return{provider,deployment,request,certificate,state,source,destination,origin,before,caller,safePin,...material};
}
export async function capture(s){const c=await workflow.captureArtistRecoveredMultipleHydration(s.provider,s.deployment,s.caller,s.request,{blockTag:10,gasLimit:10000000n});s.state.captured=c;return c;}
export function install(s,c,mode='direct'){
  s.state.mined=true;s.state.catalogs=structuredClone(s.state.beforeCatalogs);const logs=[];
  const emit=(address,name,values,iface=abi)=>{const e=iface.encodeEventLog(iface.getEvent(name),values);logs.push({address,...e,index:logs.length,blockNumber:12,blockHash:H('block12'),transactionHash:H('tx'),removed:false});};
  const store=(host,row)=>{const list=s.state.catalogs.get(host)??[];if(list.some(v=>v.payloadType===row.payloadType&&v.payloadHash===row.payloadHash))return;emit(host,'ArtistStoredPayload',[1n,BigInt(list.length),row.payloadType,row.payloadHash,row.pointer]);list.push(row);s.state.catalogs.set(host,list);};
  for(const i of [2,4,6])for(const row of c.owners[i].payload.publications)store(s.destination.owners[i],row);
  const append=(evidenceId,payload,index)=>{const pointer=A(200+index),contentHash=keccak256(payload),size=BigInt((payload.length-2)/2);s.state.codes.set(pointer,`0x00${payload.slice(2)}`);s.state.evidence.set(evidenceId,payload);s.state.metadata.set(evidenceId,[contentHash,pointer,size,12n]);store(s.destination.archive,{pointer,payloadType:H('ARTIST_OPERATION_EVIDENCE'),payloadHash:contentHash});emit(s.destination.archive,'ArtistArchiveEvidenceAppendedV2',[evidenceId,1n,contentHash,pointer,size]);};
  const coordinates={chainId:1n,registry:s.destination.registry,coordinator:s.deployment.destination.coordinator.address};
  for(let i=0;i<c.descriptor.pageHashes.length;i++)append(rh.artistRecoveredMultipleHydrationPageId(coordinates,c.commitment,c.descriptor,BigInt(i)),`0x${c.profileEvidence.slice(2+i*40960,2+(i+1)*40960)}`,i);
  append(c.evidenceId,c.operationEvidence,c.descriptor.pageHashes.length);emit(s.deployment.destination.coordinator.address,'RecoveredArtistAuthorityHydrated',[1n,s.source.registry,c.commitment,c.prepared.request.expectedSemanticInventory,c.descriptor.payloadHash]);
  for(const i of [2,4,6])for(const row of c.owners[i].payload.publications)store(s.destination.archive,row);
  s.state.tx={hash:H('tx'),from:c.prepared.caller,to:c.prepared.registry,data:c.prepared.call.data,value:0n,chainId:1n,blockNumber:12,blockHash:H('block12')};let receiptOptions={execution:'direct'};
  if(mode!=='direct'){
    const values=[c.prepared.registry,0n,c.prepared.call.data,0n,1000000n,0n,0n,ZeroAddress,ZeroAddress,s.state.safeNonce],expectedSafeTxHash=safeHash(1n,c.prepared.caller,values);
    s.state.tx.from=A(81);s.state.tx.to=c.prepared.caller;s.state.tx.data=safeABI.encodeFunctionData('execTransaction',[...values.slice(0,9),'0x1234']);emit(c.prepared.caller,'ExecutionSuccess',[expectedSafeTxHash,0n],mode==='indexed'?indexedSafe:safeABI);
    receiptOptions={execution:'safe',expectedSafeTxHash,nonce:s.state.safeNonce,safeCodeHash:s.safePin.codeHash};
  }
  s.state.receipt={...s.state.tx,status:1,logs};return{logs,emit,options:receiptOptions};
}
export const run=(s,c,mined)=>workflow.reconcileArtistRecoveredMultipleHydrationReceipt(s.provider,c,H('tx'),mined.options);
export const renumber=logs=>logs.forEach((log,index)=>{log.index=index;});
