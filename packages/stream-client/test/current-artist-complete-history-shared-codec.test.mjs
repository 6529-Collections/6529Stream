import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import { compiledLibraryValueInterface } from "./current-artist-recovered-multiple-dispute-hydration-source-fixture.mjs";

// An isolated targeted TypeScript emit can be selected without replacing package dist.
const dist = process.env.STREAM_CLIENT_SHARED_CODEC_DIST ?? "../dist/";
const m = await import(new URL(`${dist.replace(/\/$/, "")}/internal/artist-recovered-hydration-codec.js`, import.meta.url));
const complete = m.createArtistRecoveredHydrationCodec(33816575n);
const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash;
const H = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const seven = fn => Array.from({ length: 7 }, (_, i) => fn(i));
const hash = (types, values) => keccak256(coder.encode(types, values));
const child = (type, name) => type.components.find(c => c.name === name);
const array = (type, length = -1) => ParamType.from({ type: `tuple[${length < 0 ? "" : length}]`, components: type.components });
const clone = structuredClone;
const oldMasks = [255n, 511n, 262175n, 524671n, 1049087n, 2276351n, 4194335n, 16956415n];
const profile = id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1");
const checkpointSchema = id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1");
const names = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"];
const tags = ["BINDING", "COLLABORATOR", "IDENTITY", "ACCEPTANCE", "ATTRIBUTION", "PAYOUT", "CONSENT"];
const domain = i => id(`domain:${names[i]}`);
const tag = i => id(`6529STREAM_ARTIST_RECOVERED_${tags[i]}_STATE_V1`);

// These original Request/Prepared/payload ABI tuples are compiler witnesses retained
// by the preceding source profile, not newly claimed COMPLETE semantic witnesses.
const prepare = compiledLibraryValueInterface("prepared").fragments.find(f => f.type === "function" && f.name === "prepare" && f.inputs.length === 2);
const payloadDecode = compiledLibraryValueInterface("payload").getFunction("decode");
const T = { request: prepare.inputs[1], prepared: prepare.outputs[0], header: payloadDecode.outputs[0], payload: payloadDecode.outputs[1] };
T.admission = child(T.prepared, "admission"); T.provenance = child(T.admission, "provenance");
T.origin = child(T.provenance, "origins").arrayChildren; T.local = child(T.payload, "provenance");
T.suite = child(T.admission, "source"); T.query = child(T.prepared, "query");
T.data = child(T.prepared, "data"); T.timing = child(T.prepared, "timing"); T.external = child(T.prepared, "externalGuards");
T.before = child(T.admission, "before_"); T.capability = child(T.request, "expectedCapabilities").arrayChildren;
T.authority = child(child(T.request, "records"), "authority");
T.witness = child(child(T.request, "records"), "witnesses").arrayChildren;
T.economics = child(T.witness, "economics").arrayChildren; T.attestation = child(T.witness, "attestations").arrayChildren;
T.envelope = ParamType.from({ type: "tuple", components: [T.header, { name: "payload", type: "bytes" }] });

function zero(t) {
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(c => [c.name, zero(c)]));
  if (t.baseType === "array") return Array.from({ length: Math.max(0, t.arrayLength) }, () => zero(t.arrayChildren));
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  if (t.type === "bytes") return "0x";
  if (t.type.startsWith("bytes")) return `0x${"00".repeat(Number(t.type.slice(5)))}`;
  return 0n;
}
const provenanceHash = p => hash(["bytes32", "uint16", T.provenance], [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_PROVENANCE_V1"), 1n, p]);
function local(p, i) {
  return { origins: clone(p.origins), eras: p.eras.map(e => ({ originHash: e.originHash, checkpoint: clone(e.checkpoints[i]), nativeCount: e.nativeCounts[i], lowerRevision: e.lowerRevisions[i], priorImportCommitment: e.priorImportCommitment })), journal: clone(p.journals[i]), aliases: clone(p.aliases[i]) };
}
function originalEnvelope(payload, i, features) {
  const p = payload.provenance, last = p.eras.at(-1);
  const header = { profile, version: 1n, ownerIndex: BigInt(i), sourceOrigin: last.originHash, priorImportCommitment: last.priorImportCommitment,
    semanticInventory: keccak256(payload.semanticState),
    provenanceCommitment: hash(["bytes32", "uint16", "bytes32", T.local], [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_V1"), 1n, domain(i), p]),
    replayAliasesCommitment: hash(["bytes32", "uint16", "bytes32", child(T.local, "aliases")], [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_ALIASES_V1"), 1n, domain(i), p.aliases]),
    requiredFeatures: features, semanticRecordCount: BigInt(p.journal.length), replayAliasCount: BigInt(p.aliases.length), eraCount: BigInt(p.eras.length) };
  return coder.encode(["bytes32", "uint16", T.envelope], [tag(i), 1n, { header, payload: coder.encode(["bytes32", "uint16", T.payload], [id("6529STREAM_ARTIST_RECOVERED_OWNER_PAYLOAD_V1"), 1n, payload]) }]);
}
function inventory(p) {
  return hash(["bytes32", "uint16", "bytes32", T.query, T.data, T.timing, T.external], [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, provenanceHash(p.admission.provenance), p.query, p.data, p.timing, p.externalGuards]);
}

// Deliberately structural synthetic facts: semanticState is opaque. This fixture
// proves no complete-family admission, private state, source reads or execution.
function sample({ shape = "historical", witnesses = false, features = 33554432n, accountNonce = false } = {}) {
  const p = zero(T.prepared), c = p.admission, source = c.source;
  Object.assign(source, { registry: A(1), archive: A(3), owners: seven(i => A(10 + i)), core: A(4), mintManager: A(5), roleRegistry: A(6), metadata: A(7), primaryResolver: A(8), royaltyResolver: A(9), primaryRevenueClass: H(8), validator: A(17) });
  const origin = { chainId: (1n << 200n) + 11n, registry: source.registry, coordinator: A(2), archive: source.archive, owners: clone(source.owners), ownerCodeHashes: seven(i => H(100 + i)), core: source.core, manager: source.mintManager, suiteConfigurationHash: hash([T.suite], [source]) };
  const originHash = hash(["bytes32", "uint16", T.origin], [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_ORIGIN_V1"), 1n, origin]);
  const ids = shape === "empty" ? [] : shape === "single" ? [H(1000)] : shape === "oldPlural" ? [H(1000), H(1001)] : [H(1000), H(1001), H(1002)];
  c.artists = ids.map(artistId => ({ artistId, collectionId: 0n, bindingHash: Z, policies: [], records: [] }));
  const cid = (1n << 240n) + 1n;
  c.collections = [{ artistId: ids.at(-1) ?? Z, collectionId: cid, bindingHash: ids.length ? H(500) : Z, policies: [], records: [] }];
  if (shape === "oldPlural") c.collections.unshift({ artistId: ids[0], collectionId: cid - 1n, bindingHash: H(499), policies: [], records: [] });
  const journals = seven(() => []);
  const row = (owner, operation, artistId, collectionId, recordHash) => journals[owner].push({ receipt: { operation, artistId, collectionId, recordHash }, position: { point: { environmentHash: originHash, ownerIndex: BigInt(owner), ownerRevision: BigInt(journals[owner].length + 1) }, nativeIndex: BigInt(journals[owner].length) } });
  ids.forEach((artistId, i) => row(2, shape === "historical" && i === 1 ? 6n : 1n, artistId, 0n, artistId));
  for (const q of c.collections) {
    if (ids.length) row(0, 1n, shape === "historical" ? ids[0] : q.artistId, q.collectionId, q.bindingHash);
    if (shape === "historical" || !ids.length) row(4, 8n, Z, q.collectionId, H(600));
  }
  if (shape === "historical") { row(1, 5n, ids[1], cid, H(601)); row(6, 52n, ids[0], cid, H(602)); row(6, 12n, ids[2], cid, H(603)); }
  if (witnesses) { row(6, 15n, ids[0], cid, H(604)); row(6, 15n, ids.at(-1), cid, H(605)); row(4, 24n, ids[0], cid, H(606)); }
  const nonces = accountNonce ? [{ index: { kind: 3n, key: H(44), prefixCount: 1n }, words: [{ prefix: 0n, words: Array.from({ length: 32 }, (_, i) => i === 0 ? 1n : 0n), exhausted: false }] }] : [];
  const checkpoints = seven(i => ({ schema: checkpointSchema, ownerState: { domainId: domain(i), revision: BigInt(journals[i].length), stateRoot: H(200 + i), recordChainTip: H(220 + i) }, replayRoot: Z, replayCount: 0n, nonceRoot: i === 2 && nonces.length ? H(280) : Z, nonceIndexCount: i === 2 ? BigInt(nonces.length) : 0n }));
  c.provenance = { origins: [origin], eras: [{ originHash, priorImportCommitment: Z, checkpoints, nativeCounts: journals.map(rows => BigInt(rows.length)), lowerRevisions: seven(() => 0n) }], journals, aliases: seven(() => []) };
  c.prior = source.registry; c.sourceCoordinator = origin.coordinator;
  c.before_ = seven(i => ({ domainId: domain(i), revision: i === 2 ? 1n + BigInt(c.artists.length + c.collections.length) : 0n, stateRoot: H(300 + i), recordChainTip: H(320 + i) }));
  for (const a of c.artists) a.records = journals.flat().filter(j => j.receipt.artistId === a.artistId).map(j => j.receipt.recordHash);
  for (const q of c.collections) q.records = journals.flat().filter(j => j.receipt.collectionId === q.collectionId).map(j => j.receipt.recordHash);
  const first = c.collections[0]; p.query = { ...clone(first), records: clone(first.artistId === Z ? first.records : c.artists.find(a => a.artistId === first.artistId).records) };
  p.timing = { schema: id("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1"), version: 1n, count: 0n, root: Z, configurationHash: H(400) };
  p.externalGuards = { schema: id(ids.length ? "6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1" : "6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1"), artistId: ids[0] ?? Z, provenanceCommitment: provenanceHash(c.provenance), actions: [], finality: [], entropy: [] };
  const payloads = seven(i => ({ provenance: local(c.provenance, i), nonces: i === 2 ? clone(nonces) : [], semanticState: "0x1234", publications: [] }));
  p.data = payloads.map((payload, i) => ({ typedState: originalEnvelope(payload, i, features), origins: [], sourceKeys: [], cells: [], nonces: [] }));
  const r = zero(T.request); r.expectedSemanticInventory = inventory(p);
  r.records.authority = { ...r.records.authority, artistIds: clone(ids), collections: c.collections.map(({ artistId, collectionId, policies }) => ({ artistId, collectionId, policies: clone(policies) })), expectedSource: clone(checkpoints), replayOrigins: seven(() => []) };
  r.expectedCapabilities = seven(i => ({ profile, version: 1n, ownerIndex: BigInt(i), ownerDomain: domain(i), checkpointSchema, stateSchema: tag(i), supportedFeatures: (1n << 26n) - 1n }));
  if (witnesses) {
    const e = zero(T.economics); Object.assign(e, { collectionId: cid, resolver: source.primaryResolver });
    const a = zero(T.attestation); a.terms.collectionId = cid;
    r.records.witnesses = [{ collectionId: cid, economics: [e, clone(e)], attestations: [a] }];
  }
  return { p, r, payloads, origin, coords: { chainId: origin.chainId, registry: A(900), coordinator: A(901) } };
}

test("COMPLETE is a separately closed factory mask and retains original wire bytes", () => {
  assert.throws(() => m.createArtistRecoveredHydrationCodec(33554432n), /profile/);
  const f = sample();
  assert.equal(complete.encodeArtistRecoveredHydrationRequest(f.r), coder.encode([T.request], [f.r]));
  assert.deepEqual(complete.decodeArtistRecoveredHydrationRequest(coder.encode([T.request], [f.r])), f.r);
  for (let i = 0; i < 7; i++) assert.equal(complete.encodeArtistRecoveredHydrationOwnerPayload(f.payloads[i], i, 33554432n), f.p.data[i].typedState);
  for (const mask of oldMasks) assert.throws(() => m.createArtistRecoveredHydrationCodec(mask).decodeArtistRecoveredHydrationOwnerPayload(f.p.data[4].typedState, 4), /header/);
});

test("COMPLETE selectors admit former principals, collaborator principals, singleton and empty graphs", () => {
  for (const shape of ["historical", "single", "empty"]) {
    const { r } = sample({ shape }); assert.deepEqual(complete.normalizeArtistRecoveredHydrationRequest(r), r);
  }
  for (const mask of oldMasks) assert.throws(() => m.createArtistRecoveredHydrationCodec(mask).normalizeArtistRecoveredHydrationRequest(sample().r));
});

test("COMPLETE selectors retain strict order, membership, boundedness and empty-head policies", () => {
  const base = sample().r;
  for (const mutate of [r => r.records.authority.artistIds.reverse(), r => r.records.authority.artistIds.push(Z), r => r.records.authority.bindingIndex = 1n, r => r.records.authority.collections[0].artistId = H(999), r => r.records.authority.collections = [], r => r.records.authority.artistIds = Array.from({ length: 129 }, (_, i) => H(i + 1))]) {
    const r = clone(base); mutate(r); assert.throws(() => complete.normalizeArtistRecoveredHydrationRequest(r));
  }
  const empty = sample({ shape: "empty" }).r; empty.records.authority.collections[0].policies = [{ phaseId: H(1), policyHash: H(2) }];
  assert.throws(() => complete.normalizeArtistRecoveredHydrationRequest(empty), /collection/);
});

test("COMPLETE Prepared partitions full principal journals and permits Platform history before a bound head", () => {
  const { p } = sample({ accountNonce: true });
  assert.deepEqual(complete.normalizeArtistRecoveredHydrationPrepared(p), p);
  assert.equal(complete.encodeArtistRecoveredHydrationPrepared(p), coder.encode([T.prepared], [p]));
  assert.deepEqual(complete.decodeArtistRecoveredHydrationPrepared(coder.encode([T.prepared], [p])), p);
  assert.equal(p.admission.provenance.journals[2][1].receipt.operation, 6n);
  assert.notEqual(p.admission.provenance.journals[0][0].receipt.artistId, p.admission.collections[0].artistId);
  assert.equal(p.admission.provenance.journals[4][0].receipt.artistId, Z);
});

test("COMPLETE registration and journal partition refusals precede opaque semantic admission", () => {
  const base = sample().p;
  for (const [mutate, error] of [
    [p => p.admission.provenance.journals[2][1].receipt.operation = 25n, /Artist occurrences/],
    [p => p.admission.provenance.journals[2][1].receipt.recordHash = H(777), /registration/],
    [p => p.admission.provenance.journals[1][0].receipt.artistId = H(777), /outside/],
    [p => p.admission.provenance.journals[4][0].receipt.operation = 24n, /Platform occurrence/],
    [p => p.admission.artists[0].records.pop(), /Artist occurrences/],
    [p => p.admission.collections[0].records.pop(), /collection occurrences/],
  ]) { const p = clone(base); mutate(p); assert.throws(() => complete.normalizeArtistRecoveredHydrationPrepared(p), error); }
});

test("COMPLETE zero-principal anchor and U.TAG external snapshot remain exact", () => {
  const { p } = sample({ shape: "empty" }); assert.deepEqual(complete.normalizeArtistRecoveredHydrationPrepared(p), p);
  assert.deepEqual(p.query.records, p.admission.collections[0].records);
  for (const mutate of [v => v.externalGuards.artistId = H(1), v => v.externalGuards.schema = id("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1"), v => v.externalGuards.provenanceCommitment = H(3), v => v.query.records = []]) {
    const changed = clone(p); mutate(changed); assert.throws(() => complete.normalizeArtistRecoveredHydrationPrepared(changed), /guard|anchor/);
  }
  const nonempty = sample().p; nonempty.externalGuards = clone(p.externalGuards);
  assert.throws(() => complete.normalizeArtistRecoveredHydrationPrepared(nonempty), /guards belong/);
});

test("COMPLETE joins every repeated economics and attestation witness without assigning a current Artist", () => {
  const f = sample({ witnesses: true });
  assert.doesNotThrow(() => complete.artistRecoveredHydrationCommitment(f.coords, f.r, f.p));
  for (const mutate of [r => r.records.witnesses[0].economics.pop(), r => r.records.witnesses[0].attestations = [], r => r.records.witnesses.push(clone(r.records.witnesses[0])), r => r.records.witnesses[0].economics[0].resolver = A(777)]) {
    const r = clone(f.r); mutate(r); assert.throws(() => complete.artistRecoveredHydrationCommitment(f.coords, r, f.p), /witness|partition|order/);
  }
  const none = sample(); assert.doesNotThrow(() => complete.artistRecoveredHydrationCommitment(none.coords, none.r, none.p));
});

test("COMPLETE headers require only their own bit plus actual allowed features", () => {
  const f = sample({ shape: "empty" });
  for (const bits of [33554432n, 33554432n | 65536n, 33816575n]) assert.doesNotThrow(() => complete.encodeArtistRecoveredHydrationOwnerPayload(f.payloads[4], 4, bits));
  for (const bits of [0n, 262143n, 33554432n | 262144n, 33554432n | 16777216n]) assert.throws(() => complete.encodeArtistRecoveredHydrationOwnerPayload(f.payloads[4], 4, bits), /header/);
  const capability = clone(f.r.expectedCapabilities[4]); capability.supportedFeatures = 33554432n;
  assert.doesNotThrow(() => complete.validateArtistRecoveredHydrationCapability(capability, 4, 33554432n));
  assert.throws(() => complete.validateArtistRecoveredHydrationCapability(capability, 4, 33554433n), /capability/);
});

test("COMPLETE keeps the original semantic inventory and fifteen-field operation60 commitment", () => {
  for (const shape of ["historical", "single", "empty"]) {
    const f = sample({ shape }), p = f.p;
    assert.equal(complete.artistRecoveredHydrationSemanticInventory(p), inventory(p));
    const expected = hash(["bytes32", "uint16", "uint256", "address", "address", "address", "address", T.request, array(T.query), array(T.query), T.query, T.data, T.timing, T.external, T.before],
      [profile, 1n, f.coords.chainId, f.coords.registry, f.coords.coordinator, p.admission.prior, p.admission.sourceCoordinator, f.r, p.admission.artists, p.admission.collections, p.query, p.data, p.timing, p.externalGuards, p.admission.before_]);
    assert.equal(complete.artistRecoveredHydrationCommitment(f.coords, f.r, p), expected);
    const call = complete.prepareArtistRecoveredHydrationCall(f.coords.registry, A(999), f.r);
    assert.equal(call.call.data, `0xb80889ba${coder.encode([T.request], [f.r]).slice(2)}`);
    assert.equal(call.factsVerified, false); assert.equal(call.call.value, 0n);
  }
});

test("every older closed profile preserves original request/payload bytes and its feature gate", () => {
  const features = [1n, 1n, 262145n, 524289n, 1048705n, 2097665n, 4194304n, 16785409n];
  for (let i = 0; i < oldMasks.length; i++) {
    const engine = m.createArtistRecoveredHydrationCodec(oldMasks[i]);
    const f = sample({ shape: i < 2 ? "single" : i === 6 ? "empty" : "oldPlural", features: features[i], witnesses: i === 4 });
    assert.equal(engine.encodeArtistRecoveredHydrationRequest(f.r), coder.encode([T.request], [f.r]));
    assert.equal(engine.encodeArtistRecoveredHydrationOwnerPayload(f.payloads[4], 4, features[i]), f.p.data[4].typedState);
    assert.deepEqual(engine.decodeArtistRecoveredHydrationOwnerPayload(f.p.data[4].typedState, 4).payload, f.payloads[4]);
    assert.throws(() => engine.encodeArtistRecoveredHydrationOwnerPayload(f.payloads[4], 4, features[i] | 33554432n), /header/);
  }
});

test("COMPLETE normalization copies caller inputs and refuses array/property accessors before invocation", () => {
  const f = sample(), saved = complete.normalizeArtistRecoveredHydrationRequest(f.r);
  f.r.records.authority.artistIds[0] = H(777); assert.notEqual(saved.records.authority.artistIds[0], H(777));
  assert.ok(Object.isFrozen(saved.records.authority.artistIds));
  let invoked = 0;
  const r = sample().r; Object.defineProperty(r, "records", { enumerable: true, get() { invoked++; throw Error("executed"); } });
  assert.throws(() => complete.normalizeArtistRecoveredHydrationRequest(r), /owned/);
  const p = sample().p; Object.defineProperty(p.admission.artists, "0", { enumerable: true, get() { invoked++; throw Error("executed"); } });
  assert.throws(() => complete.normalizeArtistRecoveredHydrationPrepared(p), /owned/);
  assert.equal(invoked, 0);
  const sparse = sample().r; delete sparse.records.authority.artistIds[0];
  assert.throws(() => complete.normalizeArtistRecoveredHydrationRequest(sparse), /dense/);
});
