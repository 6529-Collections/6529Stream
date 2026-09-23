import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import * as p from "../dist/current-authority-preservation-inventory-v1.js";
import { toSafeCall } from "../dist/safe.js";
import { fixture, compiledInterfaces as ci } from "./current-preservation-v2-fixture.mjs";
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

test("all29 raw named codecs match compiled field shapes, preserve zero and reject noncanonical bytes", () => {
  for (const [name, type] of Object.entries(T)) {
    const z = zero(type), expected = coder.encode([type], [z]);
    assert.equal(p[`encode${P}${name}`](z), expected, name);
    assert.deepEqual(p[`decode${P}${name}`](expected), p[`normalize${P}${name}`](z), name);
    assert.throws(() => p[`decode${P}${name}`](expected + "00".repeat(32)), /Noncanonical/, name);
  }
  assert.throws(() => p.normalizeCurrentAuthorityPreservationInventoryV1ReceiptWitness({ lane: 2n, index: 0n }), /enum/);
  assert.throws(() => p.decodeCurrentAuthorityPreservationInventoryV1ReceiptWitness(coder.encode(["uint256", "uint256"], [256n, 0n])));
});

test("selection and capture are original immutable anchor projection, never caller-selected Core or source replacement", () => {
  const x = captured();
  assert.equal(p.currentAuthorityPreservationInventoryV1SelectionHash(x.anchors, x.capture.selection.origin, x.capture.selection.completion), x.capture.selection.selectionHash);
  assert.deepEqual(p.currentAuthorityPreservationInventoryV1CaptureDependencies(x.d, x.capture.selection), x.capture.dependencies);
  assert.deepEqual(p.validateCurrentAuthorityPreservationInventoryV1Capture(x.d, x.anchors, x.capture), x.capture);
  for (const mutate of [v => { v.dependencies.targets[0] = A(999); }, v => { v.dependencies.readGas++; }, v => { v.selection.completion = H("wrong"); }]) {
    const v = copy(x.capture); mutate(v); assert.throws(() => p.validateCurrentAuthorityPreservationInventoryV1Capture(x.d, x.anchors, v));
  }
  assert.equal(x.d.artistTargets[0], A(100));
});

test("dependency hash includes all original gas and host-kind domains while constructor bounds remain separate", () => {
  const x = captured();
  for (const kind of ["collection", "scoped"]) {
    const expected = h(["bytes32", T.Dependencies, T.OriginDependencies, T.AuthorityDependencies], [profile(kind), x.d, x.od, x.ad]);
    assert.equal(p.currentAuthorityPreservationInventoryV1DependencyHash(kind, x.d, x.od, x.ad), expected);
    assert.deepEqual(p.validateCurrentAuthorityPreservationInventoryV1Dependencies(coords(kind), x.d, x.od, x.ad), x.d);
    assert.notEqual(p.currentAuthorityPreservationInventoryV1DependencyHash(kind, { ...x.d, referenceGas: x.d.referenceGas + 1n }, x.od, x.ad), expected);
  }
  assert.doesNotThrow(() => p.validateCurrentAuthorityPreservationInventoryV1Dependencies(coords("collection"), { ...x.d, sourceGas: 1n << 240n }, x.od, x.ad));
  for (const field of ["originGas", "resolverGas"]) assert.throws(() => p.validateCurrentAuthorityPreservationInventoryV1Dependencies(coords("collection"), x.d, { ...x.od, ...(field === "originGas" ? { originGas: 1n << 64n } : {}) }, { ...x.ad, ...(field === "resolverGas" ? { resolverGas: 1n << 64n } : {}) }));
});

test("context and plan original preimages bind captured gas, historic lineage, actual host and host kind", () => {
  for (const kind of ["collection", "scoped"]) {
    const x = example(kind), expected = x.rehash();
    assert.deepEqual(p.validateCurrentAuthorityPreservationInventoryV1Context(x.c, x.ctx), x.ctx);
    assert.equal(p.currentAuthorityPreservationInventoryV1ContextHash(x.capture, keccak256(coder.encode([tuple(kind, "Context")], [x.ctx])), expected.lineageHash), expected.contextHash);
    assert.equal(p.currentAuthorityPreservationInventoryV1PlanId(x.c, expected.dependencyHash, expected.contextHash), expected.planId);
    assert.notEqual(p.currentAuthorityPreservationInventoryV1PlanId({ ...x.c, inventory: A(98) }, expected.dependencyHash, expected.contextHash), expected.planId);
  }
});

test("fully rehashed full-scope and four-field association substitutions are rejected without live reads", () => {
  for (const kind of ["collection", "scoped"]) for (const mutation of [x => { x.source.scope.collectionId++; }, x => { x.common.conservation.association.generation++; }, x => { x.common.conservation.association.bindingHash = H("wrong"); }, x => { x.common.conservation.association.identityRecordHash = H("wrong"); }]) {
    const x = example(kind), before = x.rehash(); mutation(x); const after = x.rehash();
    assert.notEqual(after.contextHash, before.contextHash); assert.notEqual(after.planId, before.planId);
    assert.throws(() => p.validateCurrentAuthorityPreservationInventoryV1Context(x.c, x.ctx), /scope|association/);
  }
  const x = example("collection"); x.ctx.records.snapshot.recordHash = H("invented legacy"); x.rehash();
  assert.throws(() => p.validateCurrentAuthorityPreservationInventoryV1Context(x.c, x.ctx), /Legacy receipt/);
});

test("origin environment, pin and ordered set use three distinct original domains and dedup exact environment", () => {
  const a = origin(), b = origin(300);
  assert.equal(p.currentAuthorityPreservationInventoryV1OriginEnvironmentHash(a.environment), originHash(a));
  assert.equal(p.currentAuthorityPreservationInventoryV1OriginPinHash(a), pinHash(a));
  const rows = p.currentAuthorityPreservationInventoryV1Origins([a, b, a]); assert.equal(rows.length, 2);
  let chain = Z;
  for (const [i, o] of [a, b].entries()) chain = h(["bytes32", "bytes32", "uint256", "bytes32"], [H("6529STREAM_ARTIST_ARCHIVE_ORIGIN_SET_ITEM_V1"), chain, BigInt(i), pinHash(o)]);
  assert.equal(p.currentAuthorityPreservationInventoryV1OriginSetHash([a, b, a]), h(["bytes32", "uint256", "bytes32"], [H("6529STREAM_ARTIST_ARCHIVE_ORIGIN_SET_V1"), 2n, chain]));
  assert.notEqual(p.currentAuthorityPreservationInventoryV1OriginSetHash([b, a]), p.currentAuthorityPreservationInventoryV1OriginSetHash([a, b]));
  assert.throws(() => p.currentAuthorityPreservationInventoryV1Origins([a, { ...a, archiveCodeHash: H("changed") }]), /Conflicting/);
  assert.throws(() => p.currentAuthorityPreservationInventoryV1OriginSetHash([]));
  assert.throws(() => p.currentAuthorityPreservationInventoryV1Origins(Array.from({ length: 18 }, (_, i) => origin(1000 + i * 30))), /limit/);
});

test("record provenance and evidence ID preserve original operation/actor/domain; locator is not authorization", () => {
  const r = zero(T.RecordOrigin); r.producer = origin(); r.actor = A(33); r.semanticRecordHash = H("semantic"); r.role = H("role"); r.sourceContextHash = H("ctx");
  r.occurrence.position.point.environmentHash = originHash(r.producer); r.occurrence.receipt.operation = 17n; r.occurrence.receipt.recordHash = H("native");
  assert.equal(p.currentAuthorityPreservationInventoryV1RecordOriginHash(r), h(["bytes32", T.RecordOrigin], [H("6529STREAM_ARTIST_ARCHIVE_RECORD_ORIGIN_V1"), r]));
  const evidence = h(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [H("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), r.producer.environment.chainId, r.producer.environment.registry, r.producer.environment.coordinator, 17n, r.actor, r.occurrence.receipt.recordHash]);
  assert.equal(p.currentAuthorityPreservationInventoryV1EvidenceId(r), evidence);
  const row = { ...zero(T.Item), kind: 6n, role: r.role, source: r.producer.environment.archive, sourceRecord: evidence, sourceIndex: 1n, provenanceHash: p.currentAuthorityPreservationInventoryV1RecordOriginHash(r) };
  assert.deepEqual(p.validateCurrentAuthorityPreservationInventoryV1RecordOrigin(r.sourceContextHash, row, r, r.occurrence.receipt.recordHash, r.actor, r.role), r);
  assert.throws(() => p.validateCurrentAuthorityPreservationInventoryV1RecordOrigin(r.sourceContextHash, { ...row, kind: 4n }, r, Z, r.actor, r.role));
  assert.throws(() => p.validateCurrentAuthorityPreservationInventoryV1RecordOrigin(r.sourceContextHash, row, r, H("other receipt"), r.actor, r.role));
});

test("item/link/segment chains keep duplicate role occurrences and explicit empty consumer segments", () => {
  const row = { ...zero(T.Item), kind: 7n, role: H("absent"), source: A(4) }, key = H("key"), witness = H("witness");
  assert.equal(p.currentAuthorityPreservationInventoryV1ItemHash(row), h(["bytes32", T.Item], [H("6529STREAM_PRESERVATION_ITEM_V1"), row]));
  const s = p.currentAuthorityPreservationInventoryV1Segment(key, witness, [row, row]);
  const tail = h(["bytes32", "bytes32", "uint64", "uint64", "bytes32", "bytes32"], [H("6529STREAM_PRESERVATION_ITEM_LINK_V1"), key, 2n, 1n, p.currentAuthorityPreservationInventoryV1ItemHash(row), Z]);
  assert.equal(s.firstLink, p.currentAuthorityPreservationInventoryV1Link(key, 2n, 0n, row, tail));
  assert.throws(() => p.currentAuthorityPreservationInventoryV1Link(key, 2n, 0n, row, Z));
  assert.equal(p.currentAuthorityPreservationInventoryV1AppendSegment(Z, 4n, s), h(["bytes32", "bytes32", "uint64", T.Segment], [H("6529STREAM_PRESERVATION_SEGMENT_V1"), Z, 4n, s]));
  assert.equal(p.currentAuthorityPreservationInventoryV1Segment(key, witness, []).firstLink, Z);
  assert.notEqual(p.currentAuthorityPreservationInventoryV1SegmentKey("collection", H("plan"), 0n), p.currentAuthorityPreservationInventoryV1SegmentKey("scoped", H("plan"), 0n));
});

test("presentation and lineage preimages preserve original Router and bound association fields", () => {
  const x = example(), presented = x.source.artist, d = x.capture.dependencies, a = x.common.conservation.association, o = x.capture.selection.origin;
  const expected = h(["bytes32", "uint256", "address", "address", "uint256", T.ArtistPresentation, T.Association, "bytes32", "bytes32"],
    [H("6529STREAM_ARTIST_ARCHIVE_PRESENTATION_LINEAGE_V1"), d.chainId, d.targets[0], d.targets[4], 3n, presented, a, pinHash(o), pinHash(o)]);
  assert.equal(p.currentAuthorityPreservationInventoryV1LineageHash(d, 3n, presented, a, o, o), expected);
  assert.notEqual(p.currentAuthorityPreservationInventoryV1LineageHash({ ...d, targets: [d.targets[0], ...d.targets.slice(1, 4), A(991), ...d.targets.slice(5)] }, 3n, presented, a, o, o), expected);
  assert.notEqual(p.currentAuthorityPreservationInventoryV1LineageHash(d, 3n, presented, { ...a, generation: 3n }, o, o), expected);
});

function sealed(kind) {
  const x = example(kind), hashes = x.rehash(), rawPlan = zero(tuple(kind, "Plan")), plan = kind === "collection" ? rawPlan : rawPlan.progress;
  if (kind === "scoped") rawPlan.scope = x.scope;
  Object.assign(plan, { collectionId: 3n, subject: x.common.subject, artistId: x.common.artistId, sourceContextHash: hashes.contextHash,
    tokenCount: 1n, nextToken: 1n, completedStages: 8n });
  const segment = p.currentAuthorityPreservationInventoryV1Segment(p.currentAuthorityPreservationInventoryV1SegmentKey(kind, hashes.planId, 0n), H("source-witness"), [{ ...zero(T.Item), kind: 7n }]);
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
test("both complete evidence domains and retained history rejoin capture, lineage, ordered segments and plan seal", () => {
  for (const kind of ["collection", "scoped"]) {
    const x = sealed(kind);
    assert.equal(p.currentAuthorityPreservationInventoryV1EvidenceHash(x.c, x.hashes.dependencyHash, x.capture.selection.selectionHash, x.evidence, x.root, 1n), x.digest);
    assert.equal(p.authenticateCurrentAuthorityPreservationInventoryV1History(x.history).evidenceHash, x.digest);
    // No live source/resolver argument exists: these are local retained commitments only.
    for (const mutation of [v => { v.capture.selection.completion = H("later"); }, v => { v.segments = []; }, v => { v.origins.push(origin(500)); }, v => { v.lineageHash = H("changed"); }]) {
      const bad = copy(x.history); mutation(bad); assert.throws(() => p.authenticateCurrentAuthorityPreservationInventoryV1History(bad));
    }
  }
});

test("all19 writes per host use original compiler selectors, zero value and generic Safe CALL", () => {
  const common = [
    { kind: "appendWork", planId: H("plan"), witness: zero(T.Work), originalActor: ZeroAddress, receipt: { lane: 0n, index: 0n } },
    { kind: "appendRights", planId: H("plan"), witness: zero(T.Rights) },
    ...["Intent", "IntentWaiver", "Interview"].map(name => ({ kind: `append${name}`, planId: H("plan"), witness: zero(T[name]), originalActor: A(7), receipt: { lane: 1n, index: 9n } })),
    ...["appendInterviewWaiver", "appendDefinition", "appendTokenPreservation", "appendOriginRuntime", "sealInventory"].map(kind => ({ kind, planId: H("plan") })),
  ];
  for (const kind of ["collection", "scoped"]) {
    const scoped = kind === "scoped", scope = example(kind).scope;
    const requests = [...common, { kind: "beginInventory", ...(scoped ? { scope } : { collectionId: 3n }) },
      ...["appendNative", "appendReference"].map(name => ({ kind: name, planId: H("plan"), ...(scoped ? { maxChunks: 64n } : {}) })),
      { kind: "appendRootAuthorization", planId: H("plan"), originalActor: A(7), observedAt: (1n << 64n) - 1n, aggregate: { revision: 2n, transitionChain: H("chain") }, receipt: { lane: 1n, index: 0n }, ...(scoped ? { originalLegacyFamilyHash: H("legacy") } : {}) },
      { kind: scoped ? "appendTokenOutput" : "appendToken", planId: H("plan"), payload: { tokenId: 1n, producer: A(4), image: "0x", animation: "0x01" } },
      ...(scoped ? ["appendTokenScript", "appendTokenLibrary", "appendTokenRenderer", "appendTokenCitation"] : ["appendScript", "appendLibrary", "appendRenderer", "appendCurrentProfile"]).map(name => ({ kind: name, planId: H("plan") }))];
    assert.equal(requests.length, 19);
    for (const r of requests) {
      const result = p.prepareCurrentAuthorityPreservationInventoryV1Call(coords(kind), A(8), r), fragment = host[kind].getFunction(r.kind);
      assert.equal(result.call.data.slice(0, 10), fragment.selector);
      assert.equal(host[kind].encodeFunctionData(fragment, host[kind].decodeFunctionData(fragment, result.call.data)), result.call.data);
      assert.deepEqual(p.normalizeCurrentAuthorityPreservationInventoryV1Call(result), result);
      const safe = toSafeCall(result.call); assert.equal(safe.operation, 0); assert.equal(safe.value, "0"); assert.equal(safe.data, result.call.data);
      assert.throws(() => p.normalizeCurrentAuthorityPreservationInventoryV1Call({ ...result, call: { ...result.call, value: 1n } }));
    }
  }
});

test("closed host requests reject old stage names, arbitrary family, invalid batch and legacy Work misuse", () => {
  const r = { kind: "appendNative", planId: H("plan"), maxChunks: 1n };
  assert.throws(() => p.prepareCurrentAuthorityPreservationInventoryV1Call(coords("collection"), A(8), r));
  assert.throws(() => p.prepareCurrentAuthorityPreservationInventoryV1Call(coords("scoped"), A(8), { ...r, maxChunks: 65n }));
  assert.throws(() => p.prepareCurrentAuthorityPreservationInventoryV1Call(coords("scoped"), A(8), { kind: "appendCurrentProfile", planId: H("plan") }));
  assert.throws(() => p.prepareCurrentAuthorityPreservationInventoryV1Call(coords("collection"), A(8), { kind: "sealInventory", planId: H("plan"), family: H("VIEW") }));
  for (const method of ["beginCoverage", "raiseGas", "lockInventory"]) assert.throws(() => p.prepareCurrentAuthorityPreservationInventoryV1Call(coords("collection"), A(8), { kind: method, planId: H("plan") }));
  assert.equal(p.validateCurrentAuthorityPreservationInventoryV1WorkActor(ZeroAddress, Z, { lane: 0n, index: 0n }), ZeroAddress);
  for (const [actor, hash, receipt] of [[A(2), Z, { lane: 0n, index: 0n }], [ZeroAddress, Z, { lane: 1n, index: 0n }], [ZeroAddress, Z, { lane: 0n, index: 1n }], [ZeroAddress, H("attestation"), { lane: 0n, index: 0n }]]) assert.throws(() => p.validateCurrentAuthorityPreservationInventoryV1WorkActor(actor, hash, receipt));
  assert.equal(p.validateCurrentAuthorityPreservationInventoryV1WorkActor(A(2), H("attestation"), { lane: 1n, index: 1n }), A(2));
});

test("inventory-specific HTML/image admission is1..40960/2048; raw codecs stay structural", () => {
  const payload = { tokenId: 1n, producer: A(4), image: "0x" + "ff".repeat(2048), animation: "0x" + "ab".repeat(40960) };
  assert.deepEqual(p.validateCurrentAuthorityPreservationInventoryV1Payload(payload), payload);
  for (const bad of [{ ...payload, animation: payload.animation + "00" }, { ...payload, image: payload.image + "00" }, { ...payload, tokenId: 0n }, { ...payload, animation: "0x" }]) {
    assert.doesNotThrow(() => p.encodeCurrentAuthorityPreservationInventoryV1Payload(bad));
    assert.throws(() => p.validateCurrentAuthorityPreservationInventoryV1Payload(bad));
  }
});

test("progress separates8 common stages, six per-token phases and origin closure; begin retry has no invented progress veto", () => {
  const base = { ...zero(T.CollectionPlan), collectionId: 3n, tokenCount: 1n, completedStages: 8n }, t = { phase: 5n, row: 0n, count: 0n };
  assert.doesNotThrow(() => p.validateCurrentAuthorityPreservationInventoryV1Stage("collection", { kind: "appendTokenPreservation", planId: H("plan") }, base, t));
  assert.throws(() => p.validateCurrentAuthorityPreservationInventoryV1Stage("collection", { kind: "appendRenderer", planId: H("plan") }, base, t));
  const end = { ...base, nextToken: 1n };
  assert.doesNotThrow(() => p.validateCurrentAuthorityPreservationInventoryV1Stage("collection", { kind: "appendOriginRuntime", planId: H("plan") }, end, { phase: 0n, row: 0n, count: 0n }, 2n, 1n));
  assert.throws(() => p.validateCurrentAuthorityPreservationInventoryV1Stage("collection", { kind: "sealInventory", planId: H("plan") }, end, { phase: 0n, row: 0n, count: 0n }, 2n, 1n));
  assert.doesNotThrow(() => p.validateCurrentAuthorityPreservationInventoryV1Stage("collection", { kind: "beginInventory", collectionId: 3n }, { ...end, renderCriticalEvidenceHash: H("sealed") }, t));
});

test("31 exact definition slots preserve common bytes and separate V2 family documents", () => {
  for (const kind of ["collection", "scoped"]) {
    const list = p.currentAuthorityPreservationInventoryV1Definitions(kind); assert.equal(list.length, 31);
    const docs = Object.values(fixture.documents).map(x => [keccak256(toUtf8Bytes(x.text)), BigInt(toUtf8Bytes(x.text).length)]);
    for (const row of list) {
      const retained = docs.find(([hash]) => hash === row.hash);
      if (retained) assert.equal(row.byteLength, retained[1]);
      assert.equal(p.currentAuthorityPreservationInventoryV1Definition(kind, row.index).id, row.id);
    }
    assert.throws(() => p.currentAuthorityPreservationInventoryV1Definition(kind, 31n));
  }
  assert.deepEqual(p.currentAuthorityPreservationInventoryV1Definitions("collection").slice(0, 20), p.currentAuthorityPreservationInventoryV1Definitions("scoped").slice(0, 20));
  assert.notEqual(p.currentAuthorityPreservationInventoryV1Definition("collection", 20n).id, p.currentAuthorityPreservationInventoryV1Definition("scoped", 20n).id);
});

test("read planners preserve retained-vs-current meaning and reject cross-host getters and call substitution", () => {
  for (const kind of ["collection", "scoped"]) {
    for (const r of [{ kind: "sourceContext", planId: H("plan") }, { kind: "authoritySelection", planId: H("plan") }, { kind: "originAt", planId: H("plan"), index: 3n }, { kind: "requireCurrent", scope: example(kind).scope }, { kind: "requireFullDefinitionBytes", planId: H("plan") }]) {
      const call = p.prepareCurrentAuthorityPreservationInventoryV1Read(coords(kind), r);
      assert.equal(call.call.data.slice(0, 10), host[kind].getFunction(r.kind).selector);
      assert.equal(call.requiresCurrentSources, r.kind.startsWith("require"));
      assert.deepEqual(p.normalizeCurrentAuthorityPreservationInventoryV1Read(call), call);
      assert.throws(() => p.normalizeCurrentAuthorityPreservationInventoryV1Read({ ...call, requiresCurrentSources: !call.requiresCurrentSources }));
    }
  }
  assert.throws(() => p.prepareCurrentAuthorityPreservationInventoryV1Read(coords("scoped"), { kind: "deploymentChainId" }));
});

test("deep copies, exact owned arrays/objects, enum widths, Unicode and whole-call2MiB bounds", () => {
  const x = captured(), normalized = p.normalizeCurrentAuthorityPreservationInventoryV1Capture(x.capture);
  x.capture.dependencies.targets[0] = A(991); assert.equal(normalized.dependencies.targets[0], A(1));
  assert.throws(() => { normalized.selection.origin.environment.owners[0] = A(992); }, TypeError);
  for (const mutate of [a => { delete a[0]; }, a => { a.extra = 1; }, a => { Object.defineProperty(a, "hidden", { value: 1 }); }, a => { a[Symbol()] = 1; }]) {
    const d = captured().d; mutate(d.targets); assert.throws(() => p.normalizeCurrentAuthorityPreservationInventoryV1Dependencies(d));
  }
  assert.throws(() => p.normalizeCurrentAuthorityPreservationInventoryV1TokenProgress({ phase: 256n, row: 0n, count: 0n }));
  const w = zero(T.Work); w.full.title = "\ud800"; assert.throws(() => p.normalizeCurrentAuthorityPreservationInventoryV1Work(w));
  const r = { kind: "appendRights", planId: H("plan"), witness: zero(T.Rights) }, c = coords("collection");
  const initial = p.prepareCurrentAuthorityPreservationInventoryV1Call(c, A(7), r), fixed = (initial.call.data.length - 2) / 2;
  r.witness.licensor.name = "x".repeat(Math.floor((2097152 - fixed) / 32) * 32);
  const full = p.prepareCurrentAuthorityPreservationInventoryV1Call(c, A(7), r);
  assert.ok((full.call.data.length - 2) / 2 <= 2097152); assert.deepEqual(p.normalizeCurrentAuthorityPreservationInventoryV1Call(full), full);
  r.witness.licensor.name += "x".repeat(32); assert.throws(() => p.prepareCurrentAuthorityPreservationInventoryV1Call(c, A(7), r), /bytes/);
});
