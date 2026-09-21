import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes, sha256 } from "ethers";
import * as p from "../dist/current-authority-preservation-inventory-v1.js";
import { toSafeCall } from "../dist/safe.js";
import { fixture, compiledInterfaces as ci } from "./current-authority-preservation-archive-v1-fixture.mjs";
const P = "CurrentAuthorityPreservationInventoryV1", pre = "currentAuthorityPreservationInventoryV1";
const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash, H = x => id(String(x));
const A = x => getAddress(`0x${BigInt(x).toString(16).padStart(40, "0")}`), copy = structuredClone;
const host = { collection: ci.StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1, scoped: ci.StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 };
const f = (t, name) => t.components.find(c => c.name === name);
const out = (kind, name) => host[kind].getFunction(name).outputs[0];
const input = (kind, name, index) => host[kind].getFunction(name).inputs[index];
const T = {
  Dependencies: out("collection", "dependencies"), OriginDependencies: out("collection", "originDependencies"),
  AuthorityDependencies: out("collection", "authorityDependencies"), AuthorityAnchors: ci.IStreamArtistCurrentAuthorityResolver.getFunction("anchors").outputs[0],
  Origin: out("collection", "originAt"), Selection: ci.IStreamArtistCurrentAuthorityResolver.getFunction("currentSelection").outputs[0],
  Capture: out("collection", "authoritySelection"), RecordOrigin: out("collection", "artistArchiveOrigin"),
  ReceiptWitness: input("collection", "appendWork", 3), Item: host.collection.getEvent("InventorySegmentRecorded").inputs[3].arrayChildren,
  Segment: out("collection", "inventorySegment"), TokenProgress: out("scoped", "tokenProgress"), Scope: input("scoped", "beginInventory", 0),
  Work: input("collection", "appendWork", 1), Rights: input("collection", "appendRights", 1), Intent: input("collection", "appendIntent", 1),
  IntentWaiver: input("collection", "appendIntentWaiver", 1), Interview: input("collection", "appendInterview", 1),
  Payload: input("collection", "appendToken", 1), Aggregate: input("collection", "appendRootAuthorization", 3),
};
for (const [suffix, method] of [["Context", "sourceContext"], ["Plan", "plan"], ["Evidence", "inventoryEvidence"]]) {
  T[`Collection${suffix}`] = out("collection", method); T[`Scoped${suffix}`] = out("scoped", method);
}
T.OriginEnvironment = f(T.Origin, "environment");
T.ArtistPresentation = f(f(T.ScopedContext, "snapshotSource"), "artist");
T.Association = f(f(T.ScopedContext, "conservation"), "association");
const h = (types, values) => keccak256(coder.encode(types, values));
const tuple = (kind, name) => T[(kind === "collection" ? "Collection" : "Scoped") + name];
const profile = kind => H(`6529STREAM_CURRENT_AUTHORITY_${kind === "scoped" ? "SCOPED_" : ""}PRESERVATION_POLICY_RENDER_CRITICAL_INVENTORY_V1`);
function zero(t) {
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(c => [c.name, zero(c)]));
  if (t.baseType === "array") return Array.from({ length: Math.max(0, t.arrayLength) }, () => zero(t.arrayChildren));
  if (t.type.startsWith("uint")) return 0n;
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  return t.type === "bytes" ? "0x" : `0x${"00".repeat(Number(t.type.slice(5)))}`;
}
const coords = kind => ({ chainId: 1n << 200n, core: A(1), inventory: A(99), scopeKind: kind });
const originHash = o => h(["bytes32", "uint16", T.OriginEnvironment], [H("6529STREAM_ARTIST_RECOVERED_HYDRATION_ORIGIN_V1"), 1n, o.environment]);
const pinHash = o => h(["bytes32", T.Origin], [H("6529STREAM_ARTIST_ARCHIVE_ORIGIN_V1"), o]);
function origin(base = 200) {
  return { environment: { chainId: coords("collection").chainId, registry: A(base), coordinator: A(base + 1), archive: A(base + 2),
    owners: Array.from({ length: 7 }, (_, i) => A(base + 3 + i)), ownerCodeHashes: Array.from({ length: 7 }, (_, i) => H(base + 3 + i)),
    core: A(1), manager: A(5), suiteConfigurationHash: H(base + 20) }, registryCodeHash: H(base), coordinatorCodeHash: H(base + 1), archiveCodeHash: H(base + 2) };
}
function captured() {
  const d = { targets: Array.from({ length: 12 }, (_, i) => A(i + 1)), codeHashes: Array.from({ length: 12 }, (_, i) => H(i + 1)),
    artistTargets: Array.from({ length: 5 }, (_, i) => A(100 + i)), artistCodeHashes: Array.from({ length: 5 }, (_, i) => H(100 + i)),
    artistContentOwner: A(106), artistContentOwnerCodeHash: H(106), chainId: coords("collection").chainId,
    readGas: 50000n, sourceGas: 100000n, selectionGas: 80000n, snapshotGas: 90000n, referenceGas: 110000n };
  const od = { worker: A(600), workerCodeHash: H(600), originGas: 50000n, profile: H("6529STREAM_ARTIST_ARCHIVE_ORIGIN_V1") };
  const ad = { resolver: A(601), resolverCodeHash: H(601), resolverGas: 50000n };
  const anchors = { targets: [d.targets[0], d.targets[1], d.targets[4], d.artistTargets[0], A(602)],
    codeHashes: [d.codeHashes[0], d.codeHashes[1], d.codeHashes[4], d.artistCodeHashes[0], H(602)], finalityRegistry: A(603), chainId: d.chainId, readGas: 50000n };
  const o = origin(), selection = { origin: o, completion: H(604), selectionHash: Z };
  selection.selectionHash = h(["bytes32", T.AuthorityAnchors, T.Origin, "bytes32"], [H("6529STREAM_ARTIST_CURRENT_AUTHORITY_V1"), anchors, o, selection.completion]);
  const selected = { ...copy(d), artistTargets: [o.environment.registry, o.environment.coordinator, o.environment.owners[2], o.environment.owners[4], o.environment.archive],
    artistCodeHashes: [o.registryCodeHash, o.coordinatorCodeHash, o.environment.ownerCodeHashes[2], o.environment.ownerCodeHashes[4], o.archiveCodeHash],
    artistContentOwner: o.environment.owners[6], artistContentOwnerCodeHash: o.environment.ownerCodeHashes[6] };
  return { d, od, ad, anchors, capture: { dependencies: selected, selection } };
}
// Compiler-shaped supplied observations, not a native-admitted lifecycle or RPC provenance claim.
function example(kind = "collection", scopeType = kind === "collection" ? 0n : 1n) {
  const x = captured(), c = coords(kind), ctx = zero(tuple(kind, "Context"));
  const scope = { scopeType, collectionId: 3n, tokenId: scopeType === 1n ? 11n : 0n, scopeId: scopeType > 1n ? H(scopeType) : Z };
  const subject = p.currentAuthorityPreservationInventoryV1ScopeSubject(c.chainId, c.core, scope);
  const common = kind === "collection" ? ctx.records : ctx, source = kind === "collection" ? ctx.source : ctx.snapshotSource;
  if (kind === "collection") common.collectionId = scope.collectionId; else ctx.scope = scope;
  common.subject = subject; common.artistId = H("artist"); common.tokenCount = 1n;
  source.scope = copy(scope); source.membership.scopeSubject = subject; source.membership.tokenCount = 1n;
  source.membership.membershipHash = H("membership"); source.artist.artistId = common.artistId;
  Object.assign(source.artist, { locked: true, registry: x.capture.selection.origin.environment.registry, registryCodeHash: x.capture.selection.origin.registryCodeHash,
    bindingGeneration: 2n, bindingHash: H("binding"), identityRecordHash: H("identity"), acceptanceRecordHash: H("acceptance"), nominatedArtist: A(700), acceptedAt: 3n, lockedAt: 4n });
  source.artist.snapshotHash = p.currentAuthorityPreservationInventoryV1PresentationHash(x.capture.dependencies, scope.collectionId, source.artist);
  common.conservation.association = { artistId: common.artistId, generation: source.artist.bindingGeneration, bindingHash: source.artist.bindingHash, identityRecordHash: source.artist.identityRecordHash };
  source.selection.scope = copy(scope); source.selection.tokenCount = 1n;
  source.content.scope = copy(scope); source.content.tokenCount = 1n; source.content.preservationProfile = H("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
  source.content.inventoryHash = H("inventory"); source.content.selectionId = H("selectionId"); source.content.selectionHash = H("selectionHash");
  source.outputs.scope = copy(scope); source.outputs.tokenCount = 1n; source.outputs.preservationProfile = source.content.preservationProfile; source.outputs.checkpointHash = H("checkpoint");
  common.descriptions.scopeSubject = subject; common.rootRecordHash = H("root");
  ctx.snapshot.recordHash = H("snapshot"); ctx.snapshot.revision = 1n; ctx.snapshot.scopeSubject = subject;
  ctx.referenceRender.scopeSubject = subject; ctx.referenceRender.observation.collectionId = scope.collectionId;
  ctx.referenceRender.observation.snapshotRecordHash = ctx.snapshot.recordHash; ctx.referenceRender.observation.snapshotRevision = 1n;
  ctx.referenceRender.observation.recordHash = H("reference"); ctx.referenceRender.observation.sourcesHash = H("referenceSource");
  if (kind === "collection") ctx.referenceSourceHash = ctx.referenceRender.observation.sourcesHash;
  else { ctx.outputManifestRecord = H("output"); ctx.selectionId = source.content.selectionId; ctx.selectionHash = source.content.selectionHash; }
  common.tokenInventoryHash = kind === "collection" ? source.content.inventoryHash : source.membership.membershipHash;
  common.checkpointHash = source.outputs.checkpointHash;
  function rehash() {
    common.nativeHash = keccak256(coder.encode([f(tuple(kind, "Context"), kind === "collection" ? "source" : "snapshotSource")], [source]));
    const lineageHash = p.currentAuthorityPreservationInventoryV1LineageHash(x.capture.dependencies, scope.collectionId, source.artist, common.conservation.association, x.capture.selection.origin, x.capture.selection.origin);
    const dependencyHash = h(["bytes32", T.Dependencies, T.OriginDependencies, T.AuthorityDependencies], [profile(kind), x.d, x.od, x.ad]);
    const contextHash = h(["bytes32", "bytes32", "bytes32", "bytes32", "bytes32"], [H("6529STREAM_CURRENT_AUTHORITY_INVENTORY_CONTEXT_V1"), x.capture.selection.selectionHash, keccak256(coder.encode([T.Dependencies], [x.capture.dependencies])), keccak256(coder.encode([tuple(kind, "Context")], [ctx])), lineageHash]);
    const planId = h(["bytes32", "uint256", "address", "bytes32", "bytes32"], [profile(kind), c.chainId, c.inventory, dependencyHash, contextHash]);
    return { lineageHash, dependencyHash, contextHash, planId };
  }
  return { ...x, c, ctx, source, common, scope, rehash };
}

import * as a from "../dist/current-authority-preservation-archive-v1.js";

function sealed(kind) {
  const x = example(kind), hashes = x.rehash(), rawPlan = zero(tuple(kind, "Plan")), plan = kind === "collection" ? rawPlan : rawPlan.progress;
  if (kind === "scoped") rawPlan.scope = x.scope;
  Object.assign(plan, { collectionId: 3n, subject: x.common.subject, artistId: x.common.artistId, sourceContextHash: hashes.contextHash,
    tokenCount: 1n, nextToken: 1n, completedStages: 8n });
  const segment = p.currentAuthorityPreservationInventoryV1Segment(p.currentAuthorityPreservationInventoryV1SegmentKey(kind, hashes.planId, 0n), H("source-witness"), [absent()]);
  plan.segmentCount = 1n; plan.itemCount = 1n; plan.segmentChainHash = p.currentAuthorityPreservationInventoryV1AppendSegment(Z, 0n, segment);
  const e = copy(p.currentAuthorityPreservationInventoryV1Evidence(x.c, hashes.planId, x.ctx, rawPlan));
  const original = kind === "collection" ? e : e.inventory, root = p.currentAuthorityPreservationInventoryV1OriginSetHash([x.capture.selection.origin]);
  const digest = h(["bytes32", "uint256", "address", "bytes32", "bytes32", tuple(kind, "Evidence"), "bytes32", "uint256"],
    [profile(kind), x.c.chainId, x.c.inventory, hashes.dependencyHash, x.capture.selection.selectionHash, e, root, 1n]);
  original.renderCriticalEvidenceHash = digest; plan.renderCriticalEvidenceHash = digest;
  return { ...x, hashes, root, evidence: e, original, plan: rawPlan, segment, digest,
    history: { coordinates: x.c, dependencies: x.d, originDependencies: x.od, authorityDependencies: x.ad, authorityAnchors: x.anchors,
      capture: x.capture, context: x.ctx, lineageHash: hashes.lineageHash, plan: rawPlan, evidence: e, origins: [x.capture.selection.origin], segments: [segment] } };
}

const AP = "CurrentAuthorityPreservationArchiveV1";
const ahost = { collection: ci.StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1, scoped: ci.StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1 };
const af = (name, ...args) => a['currentAuthorityPreservationArchiveV1' + name](...args);
const ac = kind => ({ chainId: coords(kind).chainId, core: A(1), archive: A(900), scopeKind: kind });
const AT = {
  Dependencies: ahost.collection.getFunction("dependencies").outputs[0], Proof: ahost.collection.getFunction("coverNext").inputs[3],
  Admission: ahost.collection.getFunction("admittedItem").outputs[1], Progress: ahost.collection.getFunction("progress").outputs[0],
  Refresh: ahost.collection.getFunction("refresh").outputs[0], CollectionEvidence: ahost.collection.getFunction("bundleEvidence").outputs[0],
  ScopedEvidence: ahost.scoped.getFunction("bundleEvidence").outputs[0],
  OriginDependencies: ahost.collection.getFunction("originDependencies").outputs[0],
  AuthorityDependencies: ahost.collection.getFunction("authorityDependencies").outputs[0],
  AuthorityCapture: T.Capture, Origin: T.Origin, RecordOrigin: T.RecordOrigin,
};
AT.ExternalCoverage = f(AT.Admission, "externalOriginal"); AT.OnchainCoverage = f(AT.Admission, "onchainOriginal");
const RAW = H("RAW_BYTES"), noProof = { backend: 0n, objectHash: Z, coverageHash: Z };
const absent = () => ({ ...zero(T.Item), kind: 7n, role: H("absence"), source: A(8), sourceRecord: H("source-record") });
const ad = x => ({ targets: [x.d.targets[0], x.d.targets[1], x.c.inventory, x.d.targets[10], x.d.targets[11], x.d.artistTargets[4]],
  codeHashes: [x.d.codeHashes[0], x.d.codeHashes[1], H("inventory-runtime"), x.d.codeHashes[10], x.d.codeHashes[11], x.d.artistCodeHashes[4]],
  chainId: x.c.chainId, readGas: 50000n, archiveGas: 100000n });
const adomain = (kind, suffix) => H('6529STREAM_CURRENT_AUTHORITY_' + (kind === 'scoped' ? 'SCOPED_' : '') + 'PRESERVATION_POLICY_BUNDLE_' + suffix);
function archiveExample(kind) {
  const x = sealed(kind), c = ac(kind), d = ad(x), item = absent(), admission = af('IntrinsicAdmission', item, noProof);
  const depHash = h(['bytes32','bytes32',AT.Dependencies,AT.OriginDependencies,AT.AuthorityDependencies],
    [adomain(kind,'IMMUTABLE_STOP_AGGREGATE_V1'), profile(kind), d, x.od, x.ad]);
  const itemHash = p.currentAuthorityPreservationInventoryV1ItemHash(item);
  const chain = h(['bytes32','bytes32','bytes32','uint64','bytes32',AT.Admission,'bytes32'], [adomain(kind,'COVERED_ITEM_V1'),Z,x.hashes.planId,0n,itemHash,admission,Z]);
  const coverage = { inventoryPlan:x.hashes.planId,renderCriticalEvidenceHash:x.digest,itemCount:1n,evidenceChainHash:chain,bundleCoverageHash:Z };
  const e = kind === 'collection' ? coverage : {scope:x.scope,coverage};
  const covHash=h(['bytes32','uint256','address','bytes32','bytes32','bytes32','uint256',tuple(kind,'Evidence'),AT[kind==='collection'?'CollectionEvidence':'ScopedEvidence']],
    [adomain(kind,'ARCHIVE_COVERAGE_V1'),c.chainId,c.archive,depHash,adomain(kind,'IMMUTABLE_STOP_AGGREGATE_V1'),x.root,1n,x.evidence,e]);
  coverage.bundleCoverageHash=covHash;
  const progress={segmentIndex:1n,segmentItemIndex:0n,itemCount:1n,nextLink:Z,segmentChainHash:x.original.segmentChainHash,evidenceChainHash:chain,environmentHash:Z,complete:true};
  return {x,c,d,item,admission,depHash,chain,covHash,e,progress,history:{coordinates:c,dependencies:d,originDependencies:x.od,authorityDependencies:x.ad,
    inventory:x.history,evidence:e,progress,rows:[{item,admission,originHash:Z,recordOrigin:null}]}};
}

test('raw codecs match original compiler tuples, accept zeros and reject dirty/trailing/surplus fields',()=>{
  assert.equal(a.CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SOURCE,fixture.sourceCommit);
  for(const [name,t] of Object.entries(AT)) {
    const z=zero(t), raw=coder.encode([t],[z]);
    assert.equal(a['encode'+AP+name](z),raw,name);
    assert.deepEqual(a['decode'+AP+name](raw),a['normalize'+AP+name](z),name);
    assert.throws(()=>a['decode'+AP+name](raw+'00'.repeat(32)));
    assert.throws(()=>a['normalize'+AP+name]({...z,unexpected:0n}));
  }
  const z=zero(AT.Progress), raw=coder.encode([AT.Progress],[z]);
  assert.throws(()=>a.decodeCurrentAuthorityPreservationArchiveV1Progress(raw.slice(0,-2)+'02'));
  assert.throws(()=>a.normalizeCurrentAuthorityPreservationArchiveV1Progress({...z,itemCount:1n<<64n}));
  const d=ad(example());d.targets[Symbol('x')]=A(3);assert.throws(()=>a.normalizeCurrentAuthorityPreservationArchiveV1Dependencies(d));
});

test('each concrete host exposes exactly five original writes;10 CALL and Safe conversions retain byte/value identity',()=>{
  const requests=[{kind:'beginCoverage',id:H('p')},{kind:'beginRefresh',id:H('p')},{kind:'coverEmptySegment',id:H('p')},
    {kind:'refreshNext',id:H('p'),expectedIndex:0n},{kind:'coverNext',id:H('p'),item:absent(),nextLink:Z,proof:noProof}];
  for(const kind of ['collection','scoped']){
    assert.deepEqual(af('Interface',kind).fragments.filter(x=>x.type==='function'&&x.stateMutability==='nonpayable').map(x=>x.name).sort(),requests.map(x=>x.kind).sort());
    for(const r of requests){const call=a.prepareCurrentAuthorityPreservationArchiveV1Call(ac(kind),A(10),r);
      const args=r.kind==='coverNext'?[r.id,r.item,r.nextLink,r.proof]:r.kind==='refreshNext'?[r.id,r.expectedIndex]:[r.id];
      assert.equal(call.call.data,ahost[kind].encodeFunctionData(r.kind,args));assert.equal(call.factsVerified,false);
      assert.deepEqual(a.normalizeCurrentAuthorityPreservationArchiveV1Call(call),call);
      const safe=toSafeCall(call.call);assert.equal(safe.operation,0);assert.equal(safe.value,'0');assert.equal(safe.data,call.call.data);
      for(const bad of [{...call,caller:A(11),call:{...call.call,data:call.call.data+'00'}},{...call,call:{...call.call,value:1n}},{...call,call:{...call.call,to:A(4)}}])assert.throws(()=>a.normalizeCurrentAuthorityPreservationArchiveV1Call(bad));
    }
    for(const method of ['lock','raiseGas','bind','publishSnapshot'])assert.throws(()=>a.prepareCurrentAuthorityPreservationArchiveV1Call(ac(kind),A(10),{kind:method,id:H('p')}));
  }
});

test('dependency and three environment layers match independent compiler preimages with distinct domains and gas commitments',()=>{
  for(const kind of ['collection','scoped']){
    const {x,c,d,depHash}=archiveExample(kind);assert.equal(af('DependencyHash',kind,d,x.od,x.ad),depHash);
    assert.deepEqual(a.validateCurrentAuthorityPreservationArchiveV1Dependencies(c,d,x.od,x.ad),d);
    const base=h(['bytes32',AT.Dependencies,'bytes32','uint64','bytes32','uint64'],[H('6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1'),d,H('on'),2n,H('external'),0n]);
    assert.equal(af('BaseEnvironmentHash',d,H('on'),2n,H('external'),0n),base);
    const multi=h(['bytes32','bytes32',AT.OriginDependencies,'bytes32','bytes32','bytes32','uint256'],[H('6529STREAM_MULTI_ORIGIN_BUNDLE_ENVIRONMENT_V1'),base,x.od,profile(kind),x.hashes.planId,x.root,1n]);
    assert.equal(af('MultiOriginEnvironmentHash',base,x.od,kind,x.hashes.planId,x.root,1n),multi);
    assert.equal(af('EnvironmentHash',multi,x.ad,x.capture),h(['bytes32','bytes32',AT.AuthorityDependencies,AT.AuthorityCapture],[H('6529STREAM_CURRENT_AUTHORITY_BUNDLE_ENVIRONMENT_V1'),multi,x.ad,x.capture]));
    assert.notEqual(af('DependencyHash',kind,{...d,archiveGas:d.archiveGas+1n},x.od,x.ad),depHash);
    assert.doesNotThrow(()=>a.validateCurrentAuthorityPreservationArchiveV1Dependencies(c,{...d,archiveGas:1n<<240n},x.od,x.ad));
    assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1Dependencies(c,d,{...x.od,originGas:1n<<64n},x.ad));
    assert.throws(()=>af('BaseEnvironmentHash',d,H('on'),0n,H('external'),0n));
  }
});

const abiCases=[
 [0n,'COMPLETE_SIGNIFICANT_PROPERTIES','STREAM_REFERENCE_SIGNIFICANT_PROPERTIES_ABI_V1','STREAM_SOLIDITY_ABI_V1'],
 [0n,'METRIC_SUPPLEMENT_PAYLOAD','STREAM_REFERENCE_METRIC_SUPPLEMENT_ABI_V1','STREAM_SOLIDITY_ABI_V1'],
 [2n,'REFERENCE_MANIFEST','STREAM_REFERENCE_MODE_ABI_V1','STREAM_SOLIDITY_ABI_V1'],
 [2n,'CURATED_CONDITION_ORIGINAL_PAYLOAD','STREAM_REFERENCE_CURATED_CONDITION_ABI_V1','STREAM_SOLIDITY_ABI_V1'],
 [2n,'SCOPED_SNAPSHOT_MANIFEST','STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1','STREAM_SOLIDITY_ABI_V1'],
 [2n,'SCOPED_REFERENCE_MANIFEST','STREAM_SCOPED_REFERENCE_RENDER_ABI_V1','STREAM_SOLIDITY_ABI_V1'],
 ...[1,2].flatMap(v=>[
  [2n,'POLICY_SNAPSHOT_MANIFEST_V2','STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V'+v,'STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V'+v],
  [2n,'REFERENCE_MANIFEST','STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V'+v,'STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V'+v],
  [2n,'SCOPED_POLICY_SNAPSHOT_MANIFEST_V2','STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V'+v,'STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V'+v],
  [2n,'SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST','STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V'+v,'STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V'+v]]),
 [2n,'POLICY_SNAPSHOT_MANIFEST_V2','STREAM_POLICY_COLLECTION_SNAPSHOT_ABI_V2','STREAM_ABI_POLICY_COLLECTION_SNAPSHOT_V2'],
 [2n,'REFERENCE_MANIFEST','STREAM_POLICY_COLLECTION_REFERENCE_ABI_V2','STREAM_ABI_POLICY_COLLECTION_REFERENCE_V2'],
 [2n,'SCOPED_POLICY_SNAPSHOT_MANIFEST_V2','STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2','STREAM_ABI_SCOPED_POLICY_SNAPSHOT_V2'],
 [2n,'SCOPED_POLICY_REFERENCE_MANIFEST','STREAM_SCOPED_POLICY_REFERENCE_ABI_V2','STREAM_ABI_SCOPED_POLICY_REFERENCE_V2'],
];
test('exact18 source-backed native/original tuples include all4 repaired V2 cases and reject crossed pairs',()=>{
  const src=Object.entries(fixture.sourceTexts).find(([s])=>s.endsWith('/StreamInventoryAbiCorrespondence.sol'))[1];
  assert.equal(abiCases.length,18);
  for(const [kind,role,schema,canon] of abiCases){for(const literal of [role,schema,canon])assert.ok(src.includes('"'+literal+'"'));
    const item={...absent(),kind,role:H(role),schemaId:H(schema),canonicalizationId:H(canon),algorithm:1n,byteSize:20n,digest:H('payload')};
    const proof={backend:1n,coverageHash:H('coverage'),objectHash:H('object')};
    assert.equal(af('SupportedAbiCorrespondence',item),true);assert.deepEqual(a.validateCurrentAuthorityPreservationArchiveV1Proof(item,proof),proof);
    assert.doesNotThrow(()=>a.validateCurrentAuthorityPreservationArchiveV1Correspondence(item,{contentHash:item.digest,sha256Digest:Z,canonicalizationId:item.canonicalizationId,byteSize:20n}));
    for(const bad of [{...item,role:H('unknown')},{...item,schemaId:H('other')},{...item,canonicalizationId:H('other')},{...item,kind:1n},{...item,algorithm:2n},{...item,byteSize:0n}]){
      assert.equal(af('SupportedAbiCorrespondence',bad),false);assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1Proof(bad,proof));
    }
  }
});
test('special significant-properties reference is constrained by index, unknown size/schema, canonicalization and both algorithms',()=>{
  for(const algorithm of [1n,2n]){
    const item={...absent(),kind:4n,role:H('SIGNIFICANT_PROPERTIES'),sourceIndex:8n,algorithm,canonicalizationId:H('STREAM_SOLIDITY_ABI_V1'),digest:H('props')};
    assert.equal(af('SupportedAbiCorrespondence',item),true);
    const proof={backend:1n,coverageHash:H('coverage'),objectHash:H('object')};assert.doesNotThrow(()=>a.validateCurrentAuthorityPreservationArchiveV1Proof(item,proof));
    for(const patch of [{sourceIndex:7n},{schemaId:H('schema')},{byteSize:1n},{role:H('other')},{algorithm:0n}])assert.equal(af('SupportedAbiCorrespondence',{...item,...patch}),false);
    assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1Correspondence(item,{contentHash:H('props'),sha256Digest:H('props'),canonicalizationId:item.canonicalizationId,byteSize:0n}));
  }
});
test('five intrinsic branches retain original applicability and state commitment without implying external proof',()=>{
  const items=[absent(),{...absent(),kind:9n,algorithm:1n,canonicalizationId:RAW,digest:keccak256('0x')},
    {...absent(),kind:11n,algorithm:2n,canonicalizationId:RAW,digest:sha256('0x'),uri:'empty.bin'},
    {...absent(),kind:8n,algorithm:2n,canonicalizationId:RAW,digest:H('os'),byteSize:2n,uri:'os'},
    {...absent(),kind:6n,sourceIndex:1n,algorithm:1n,canonicalizationId:RAW,digest:H('state'),byteSize:2n}];
  for(const item of items){const parts=item.kind===6n?H('parts'):Z;const result=af('IntrinsicAdmission',item,noProof,parts);
    const expected=item.kind===6n?h(['bytes32',T.Item,'bytes32'],[H('STATE_RETAINED_ORIGINAL_AUTHORIZATION'),item,parts]):h(['bytes32',T.Item],[H('EXPLICIT_INVENTORY_APPLICABILITY'),item]);
    assert.equal(result.originalBundleHash,expected);assert.doesNotThrow(()=>a.validateCurrentAuthorityPreservationArchiveV1Admission(H('artist'),item,result));
    assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1Proof(item,{...noProof,objectHash:H('bad')}));
    assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1Admission(H('artist'),item,{...result,originalBundleHash:H('bad')}));
    assert.equal(af('CurrentObservation',H('artist'),item,result,result),Z);
  }
  assert.throws(()=>af('IntrinsicAdmission',{...items[2],digest:keccak256('0x')},noProof));
});

function externalExample(){
 const item={...absent(),kind:4n,algorithm:2n,canonicalizationId:RAW,byteSize:3n,digest:H('sha')},proof={backend:1n,coverageHash:H('coverage'),objectHash:H('object')};
 const original={...zero(AT.ExternalCoverage),coverageHash:proof.coverageHash,objectHash:proof.objectHash,artistId:H('artist'),contentHash:H('bytes'),sha256Digest:item.digest,
 arweaveDataRoot:H('root'),byteSize:3n,firstFamilyRecordHash:H('firstfamily'),secondFamilyRecordHash:H('secondfamily'),firstReceiptHash:H('firstreceipt'),secondReceiptHash:H('secondreceipt'),
 firstFixityHash:H('firstfixity'),secondFixityHash:H('secondfixity'),checkpointHash:H('checkpoint'),profileHash:H('profile')};
 const admission={...zero(AT.Admission),proof,originalBundleHash:H('bundle'),externalOriginal:original};
 const {coverageHash:ignored,...pair}=original;
 return {item,proof,original,admission,pair};
}
test('retained external receipts and current fixity are separate; onchain/current admissions remain byte-identical',()=>{
 const x=externalExample(),pair={...x.pair,firstFixityHash:H('fresh1'),secondFixityHash:H('fresh2')};
 assert.equal(af('CurrentObservation',H('artist'),x.item,x.admission,pair),keccak256(a.encodeCurrentAuthorityPreservationArchiveV1CurrentPair(pair)));
 for(const patch of [{firstReceiptHash:H('fresh-receipt')},{firstFamilyRecordHash:H('other-family')},{checkpointHash:H('new')},{firstFixityHash:Z}])assert.throws(()=>af('CurrentPairHash',x.original,{...pair,...patch}));
 const on={...absent(),kind:10n,algorithm:1n,canonicalizationId:RAW,byteSize:3n,digest:H('bytes')};
 const admission={...zero(AT.Admission),proof:{backend:2n,coverageHash:H('complete'),objectHash:H('artifact')},originalBundleHash:H('bundle'),immutablePartsHash:H('parts'),
 onchainOriginal:{...zero(AT.OnchainCoverage),completionHash:H('complete'),artifactHash:H('artifact'),artistId:H('artist'),contentHash:on.digest,canonicalizationId:RAW,byteLength:3n}};
 assert.equal(af('CurrentObservation',H('artist'),on,admission,admission),Z);
 assert.throws(()=>af('CurrentObservation',H('artist'),on,admission,{...admission,immutablePartsHash:H('new')}));
 assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1Proof({...on,kind:5n},admission.proof));
});
test('external object correspondence joins retained artist/schema/format/catalog, with original registered-document catalog exception',()=>{
 const x=externalExample();const object={artistId:H('artist'),schemaId:H('schema'),canonicalizationId:RAW,contentHash:x.original.contentHash,sha256Digest:x.original.sha256Digest,
 arweaveDataRoot:x.original.arweaveDataRoot,byteSize:3n,formatId:H('fmt'),formatCatalogId:H('catalog'),formatCatalogHash:H('catalogHash')};
 const row={...x.item,schemaId:object.schemaId,formatId:object.formatId,catalogId:object.formatCatalogId,catalogHash:object.formatCatalogHash};
 assert.doesNotThrow(()=>a.validateCurrentAuthorityPreservationArchiveV1ExternalObject(H('artist'),row,x.proof,object,x.original));
 for(const patch of [{artistId:H('wrong')},{schemaId:H('wrong')},{formatId:H('wrong')},{formatCatalogHash:H('wrong')},{sha256Digest:H('wrong')}])assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1ExternalObject(H('artist'),row,x.proof,{...object,...patch},x.original));
 assert.doesNotThrow(()=>a.validateCurrentAuthorityPreservationArchiveV1ExternalObject(H('artist'),{...row,kind:3n,catalogHash:H('documentCatalog')},x.proof,object,x.original));
});

test('ordered origin table rejects duplicate identities and state routes bind actual17/24 owner/provenance',()=>{
 const x=archiveExample('collection'),o=x.x.capture.selection.origin,second=origin(300),origins=[o,second];
 assert.equal(af('OriginSetHash',x.d,origins),p.currentAuthorityPreservationInventoryV1OriginSetHash(origins));
 assert.throws(()=>af('OriginSetHash',x.d,[o,o]));assert.throws(()=>af('OriginSetHash',x.d,[{...o,environment:{...o.environment,core:A(42)}}]));
 for(const operation of [17n,24n]){
  const fact={...zero(T.RecordOrigin),producer:second,actor:A(44),semanticRecordHash:H('semantic'),role:H('state'),sourceContextHash:x.x.original.sourceContextHash};
  fact.occurrence.receipt={operation,artistId:x.x.original.artistId,collectionId:x.x.original.collectionId,recordHash:H('record')};
  fact.occurrence.position.point={environmentHash:originHash(second),ownerIndex:operation===17n?6n:4n,ownerRevision:1n};
  const item={...absent(),kind:6n,role:fact.role,source:second.environment.archive,sourceRecord:p.currentAuthorityPreservationInventoryV1EvidenceId(fact),sourceIndex:1n,algorithm:1n,canonicalizationId:RAW};
  const result=a.validateCurrentAuthorityPreservationArchiveV1OriginRoute(x.d,x.x.hashes.planId,x.x.original,item,fact,origins);
  assert.equal(result.originHash,h(['bytes32',T.RecordOrigin],[H('6529STREAM_ARTIST_ARCHIVE_RECORD_ORIGIN_V1'),fact]));
  assert.deepEqual(result.dependencies.targets.slice(0,5),x.d.targets.slice(0,5));assert.equal(result.dependencies.targets[5],second.environment.archive);
  for(const mutate of [v=>{v.actor=ZeroAddress;},v=>{v.importCommitment=H('import');},v=>{v.occurrence.position.point.ownerIndex=0n;},v=>{v.occurrence.position.point.ownerRevision=0n;},v=>{v.sourceContextHash=H('other');}]){
   const bad=copy(fact);mutate(bad);assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1OriginRoute(x.d,x.x.hashes.planId,x.x.original,item,bad,origins));
  }
  assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1OriginRoute(x.d,x.x.hashes.planId,x.x.original,item,fact,[o]));
 }
 assert.equal(a.validateCurrentAuthorityPreservationArchiveV1OriginRoute(x.d,x.x.hashes.planId,x.x.original,absent(),null,[]).originHash,Z);
});

test('coverage and item preimages bind hostkind, sealed origins, exact item order and full scoped identity',()=>{
 for(const kind of ['collection','scoped']){const x=archiveExample(kind);
  assert.equal(af('ItemChain',kind,Z,x.x.hashes.planId,0n,p.currentAuthorityPreservationInventoryV1ItemHash(x.item),x.admission,Z),x.chain);
  assert.equal(af('CoverageHash',x.c,x.depHash,x.x.root,1n,x.x.evidence,x.e),x.covHash);
  assert.deepEqual(af('Evidence',x.c,x.depHash,x.x.root,1n,x.x.evidence,x.chain),x.e);
  assert.doesNotThrow(()=>a.validateCurrentAuthorityPreservationArchiveV1Evidence(x.c,x.depHash,x.x.root,1n,x.x.evidence,x.e));
  for(const mutate of [v=>{(kind==='collection'?v:v.coverage).inventoryPlan=H('other');},v=>{(kind==='collection'?v:v.coverage).itemCount++;}]){
   const bad=copy(x.e);mutate(bad);(kind==='collection'?bad:bad.coverage).bundleCoverageHash=af('CoverageHash',x.c,x.depHash,x.x.root,1n,x.x.evidence,bad);
   assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1Evidence(x.c,x.depHash,x.x.root,1n,x.x.evidence,bad));
  }
  assert.notEqual(af('CoverageHash',{...x.c,archive:A(901)},x.depHash,x.x.root,1n,x.x.evidence,x.e),x.covHash);
  if(kind==='scoped'){const bad=copy(x.e);bad.scope.collectionId++;bad.coverage.bundleCoverageHash=af('CoverageHash',x.c,x.depHash,x.x.root,1n,x.x.evidence,bad);assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1Evidence(x.c,x.depHash,x.x.root,1n,x.x.evidence,bad));}
 }
});

test('local history reconstructs both complete archives without current authority and explicitly excludes private initial observation reconstruction',()=>{
 for(const kind of ['collection','scoped']){const x=archiveExample(kind),result=a.authenticateCurrentAuthorityPreservationArchiveV1History(x.history);
  assert.equal(result.coverageHash,x.covHash);assert.equal(result.initialObservationChainIndependentlyReconstructed,false);
  for(const mutate of [v=>{v.rows[0].originHash=H('wrong');},v=>{v.rows[0].item.role=H('other');},v=>{v.rows=[];},v=>{v.progress.complete=false;},v=>{v.dependencies.targets[3]=A(88);},v=>{v.inventory.capture.selection.completion=H('new');},v=>{v.inventory.origins.push(origin(400));}]){const bad=copy(x.history);mutate(bad);assert.throws(()=>a.authenticateCurrentAuthorityPreservationArchiveV1History(bad));}
 }
});

test('refresh identity and explicit observation transitions preserve zero observations, final index and original environment',()=>{
 for(const kind of ['collection','scoped']){const c=ac(kind),env=H('env'),dep=H('deps'),plan=H('plan'),item=H('item');
  assert.equal(af('RefreshId',c,dep,plan,env),h(['bytes32','uint256','address','bytes32','bytes32','bytes32'],[adomain(kind,'REFRESH_V1'),c.chainId,c.archive,dep,plan,env]));
  const chain=h(['bytes32','bytes32','uint64','bytes32','bytes32'],[adomain(kind,'CURRENT_OBSERVATION_V1'),Z,0n,item,Z]);
  const before={environmentHash:env,nextIndex:0n,currentObservationChain:Z,complete:false},after={...before,nextIndex:1n,currentObservationChain:chain,complete:true};
  assert.equal(af('ObservationChain',kind,Z,0n,item,Z),chain);assert.deepEqual(a.validateCurrentAuthorityPreservationArchiveV1RefreshStep(kind,before,after,0n,1n,item,Z),after);
  for(const patch of [{environmentHash:H('other')},{nextIndex:2n},{complete:false},{currentObservationChain:Z}])assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1RefreshStep(kind,before,{...after,...patch},0n,1n,item,Z));
  assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1RefreshStep(kind,after,after,1n,1n,item,Z));
 }
});

test('exact next-link/empty-segment guards do not invent source reachability or begin-retry restrictions',()=>{
 const row=absent(),s=p.currentAuthorityPreservationInventoryV1Segment(H('key'),H('source'),[row]);
 const progress={...zero(AT.Progress),nextLink:s.firstLink};assert.doesNotThrow(()=>a.validateCurrentAuthorityPreservationArchiveV1NextItem(progress,s,row,Z));
 assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1NextItem({...progress,complete:true},s,row,Z));
 const empty=p.currentAuthorityPreservationInventoryV1Segment(H('key'),H('source'),[]);assert.doesNotThrow(()=>a.validateCurrentAuthorityPreservationArchiveV1EmptySegment(zero(AT.Progress),empty));
 assert.throws(()=>a.validateCurrentAuthorityPreservationArchiveV1EmptySegment({...zero(AT.Progress),segmentItemIndex:1n},empty));
});

test('local and current read plans remain distinct and reject cross-host getter/scope substitutions',()=>{
 for(const kind of ['collection','scoped']){const requests=[{kind:'bundleEvidence',id:H('id')},{kind:'admittedOriginHash',id:H('id'),index:0n},{kind:'refresh',key:H('key')},
  {kind:'requireFullCurrentCoverage',id:H('id')},{kind:'requireCoverage',id:H('id'),expectedHash:H('inventory-evidence'),...(kind==='scoped'?{scope:example(kind).scope}:{})}];
  for(const r of requests){const result=a.prepareCurrentAuthorityPreservationArchiveV1Read(ac(kind),ZeroAddress,r);assert.equal(result.call.data.slice(0,10),ahost[kind].getFunction(r.kind).selector);
   assert.equal(result.requiresCurrentObservations,r.kind.startsWith('require'));assert.deepEqual(a.normalizeCurrentAuthorityPreservationArchiveV1Read(result),result);
   assert.throws(()=>a.normalizeCurrentAuthorityPreservationArchiveV1Read({...result,requiresCurrentObservations:!result.requiresCurrentObservations}));
  }
  assert.throws(()=>a.prepareCurrentAuthorityPreservationArchiveV1Read(ac(kind),A(8),{kind:kind==='collection'?'scopedPreservationPolicyBundleArchiveProfile':'preservationPolicyBundleArchiveProfile'}));
 }
 assert.throws(()=>a.prepareCurrentAuthorityPreservationArchiveV1Read(ac('collection'),A(8),{kind:'requireCoverage',id:H('p'),expectedHash:H('x'),scope:example('scoped').scope}));
});

test('whole2MiB calldata bound, Unicode, caller-owned mutation, sparse and hidden array fields fail closed',()=>{
 const item={...absent(),kind:4n,algorithm:1n,canonicalizationId:RAW,digest:H('bytes'),uri:'a'.repeat(100)};
 const request={kind:'coverNext',id:H('p'),item,nextLink:Z,proof:{backend:1n,coverageHash:H('cov'),objectHash:H('obj')}};
 const first=a.prepareCurrentAuthorityPreservationArchiveV1Call(ac('collection'),A(10),request);item.uri='changed';assert.equal(first.request.item.uri,'a'.repeat(100));
 assert.throws(()=>a.prepareCurrentAuthorityPreservationArchiveV1Call(ac('collection'),A(10),{...request,item:{...item,uri:'\uD800'}}));
 const empty=a.prepareCurrentAuthorityPreservationArchiveV1Call(ac('collection'),A(10),{...request,item:{...item,uri:''}});
 const room=Math.floor((a.CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_MAX_BYTES-(empty.call.data.length-2)/2)/32)*32;
 const maximum=a.prepareCurrentAuthorityPreservationArchiveV1Call(ac('collection'),A(10),{...request,item:{...item,uri:'x'.repeat(room)}});
 assert.ok((maximum.call.data.length-2)/2<=a.CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_MAX_BYTES);
 assert.deepEqual(a.normalizeCurrentAuthorityPreservationArchiveV1Call(maximum),maximum);
 assert.throws(()=>a.prepareCurrentAuthorityPreservationArchiveV1Call(ac('collection'),A(10),{...request,item:{...item,uri:'x'.repeat(room+1)}}));
 const d=ad(example());delete d.targets[0];assert.throws(()=>a.normalizeCurrentAuthorityPreservationArchiveV1Dependencies(d));
 const d2=ad(example());Object.defineProperty(d2.targets,'hidden',{value:1});assert.throws(()=>a.normalizeCurrentAuthorityPreservationArchiveV1Dependencies(d2));
});
