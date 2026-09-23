import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as m from "../dist/current-artist-recovered-multiple-hydration.js";
import * as old from "../dist/current-artist-recovered-hydration.js";
import * as consent from "../dist/current-artist-recovered-consent-hydration.js";
import * as h from "../dist/current-artist-authority-hydration.js";
import { createArtistRecoveredHydrationCodec } from "../dist/internal/artist-recovered-hydration-codec.js";
import { fixture, compiledInterfaces, compiledLibraryValueInterface, libraryValueABI } from "./current-artist-recovered-multiple-hydration-source-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash;
const H = n => "0x" + BigInt(n).toString(16).padStart(64, "0");
const A = n => getAddress("0x" + BigInt(n).toString(16).padStart(40, "0"));
const seven = fn => Array.from({ length: 7 }, (_, i) => fn(i));
const hash = (types, values) => keccak256(coder.encode(types, values));
const clone = structuredClone;
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

// Synthetic source-shaped envelope. Identity/Payout private record semantics and the
// original producer, runtime state and Registry execution are deliberately mocked.
// This constructor is kept local so importing this file does not provide test support API.
function sample({ classes = [1n, 3n], oneArtist = false } = {}) {
  const ids = oneArtist ? [H(1000)] : [H(1000), H(1001)];
  const chainId = (1n << 200n) + 11n;
  const suite = { registry: A(1), archive: A(3), owners: seven(i => A(10 + i)), core: A(4), mintManager: A(5),
    roleRegistry: A(6), metadata: A(7), primaryResolver: A(8), royaltyResolver: A(9), primaryRevenueClass: H(8), validator: A(17) };
  const origin = { chainId, registry: suite.registry, coordinator: A(2), archive: suite.archive, owners: suite.owners,
    ownerCodeHashes: seven(i => H(100 + i)), core: suite.core, manager: suite.mintManager,
    suiteConfigurationHash: hash([h.ARTIST_HYDRATION_SUITE_TUPLE], [suite]) };
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
  const data = seven(i => {
    const local = m.artistRecoveredMultipleHydrationOwnerProvenance(provenance, i);
    const payload = { provenance: local, nonces: i === 2 ? clone(nonces) : [], publications: [], semanticState: coder.encode(["bytes32", "uint16", "uint8", T.state], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_BASE_V1"), 1n, BigInt(i), states[i]]) };
    const sourceKeys = logical[i].map(v => m.artistRecoveredMultipleHydrationReplayKey(origin, i, v));
    return { typedState: m.encodeArtistRecoveredMultipleHydrationOwnerPayload(payload, i, features), origins: logical[i], sourceKeys,
      cells: sourceKeys.map(key => aliases[i].find(a => a.originalKey === key).cell), nonces: [] };
  });
  const before_ = seven(i => ({ domainId: m.artistRecoveredMultipleHydrationOwnerDomain(i), revision: i === 2 ? 1n + BigInt(artists.length + collections.length) : 0n, stateRoot: H(300 + i), recordChainTip: H(320 + i) }));
  const query = { ...clone(collections[0]), records: clone(artists.find(a => a.artistId === collections[0].artistId).records) };
  const prepared = { admission: { prior: origin.registry, sourceCoordinator: origin.coordinator, source: suite, provenance, artists, collections, before_ }, query, data, timing,
    externalGuards: { schema: id("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1"), provenanceCommitment: m.artistRecoveredMultipleHydrationProvenanceHash(provenance), artistId: ids[0], actions: [], finality: [], entropy: [] } };
  const request = { records: { authority: { bindingIndex: 0n, artistIds: ids, collections: collections.map(q => ({ artistId: q.artistId, collectionId: q.collectionId, policies: [] })), expectedSource: checkpoints, replayOrigins: logical }, witnesses: [] },
    expectedCapabilities: seven(i => ({ profile: m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_PROFILE, version: 1n, ownerIndex: BigInt(i), ownerDomain: m.artistRecoveredMultipleHydrationOwnerDomain(i), checkpointSchema: m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_CHECKPOINT_SCHEMA, stateSchema: m.artistRecoveredMultipleHydrationOwnerTag(i), supportedFeatures: 524287n })),
    expectedSourceImportCommitment: Z, expectedSemanticInventory: m.artistRecoveredMultipleHydrationSemanticInventory(prepared) };
  return { request, prepared, states, identities, payouts, nonces, provenance, features, origin, bindings, coords: { chainId, registry: A(101), coordinator: A(102) } };
}

function replaceState(f, owner, mutate) {
  const p = clone(m.decodeArtistRecoveredMultipleHydrationOwnerPayload(f.prepared.data[owner].typedState, owner).payload);
  const s = clone(m.decodeArtistRecoveredMultipleHydrationState(p.semanticState, owner, p.provenance)); mutate(s);
  p.semanticState = coder.encode(["bytes32", "uint16", "uint8", T.state], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_BASE_V1"), 1n, BigInt(owner), s]);
  f.prepared.data[owner].typedState = m.encodeArtistRecoveredMultipleHydrationOwnerPayload(p, owner, f.features);
}

test("ABI167 closed profile constants and canonical aggregate State match original compiler", () => {
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_SOURCE, "99e9503020ea713b558835ac6fe1a034e36994a2");
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_BASE, 262144n);
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_ALLOWED_FEATURES, 262175n);
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_KNOWN_FEATURES, 524287n);
  const f = sample(), p = m.artistRecoveredMultipleHydrationOwnerProvenance(f.provenance, 2);
  const bytes = coder.encode(["bytes32", "uint16", "uint8", T.state], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_BASE_V1"), 1n, 2n, f.states[2]]);
  assert.equal(m.encodeArtistRecoveredMultipleHydrationState(f.states[2], 2, p), bytes);
  assert.deepEqual(m.decodeArtistRecoveredMultipleHydrationState(bytes, 2, p), f.states[2]);
  assert.throws(() => m.decodeArtistRecoveredMultipleHydrationState(bytes, 5, p));
  assert.throws(() => m.decodeArtistRecoveredMultipleHydrationState(bytes + "00", 2, p), /canonical/);
});

test("complete two-Artist and one-Artist plural collections retain class1/class3/mixed required masks", () => {
  for (const classes of [[1n, 1n], [3n, 3n], [1n, 3n]]) {
    const f = sample({ classes });
    assert.deepEqual(m.normalizeArtistRecoveredMultipleHydrationPrepared(f.prepared), f.prepared);
    assert.equal(f.features, classes[0] === classes[1] ? classes[0] === 1n ? 262145n : 262146n : 262147n);
    assert.deepEqual(m.decodeArtistRecoveredMultipleHydrationPrepared(m.encodeArtistRecoveredMultipleHydrationPrepared(f.prepared)), f.prepared);
  }
  const f = sample({ oneArtist: true });
  assert.equal(f.prepared.admission.before_[2].revision, 4n);
  assert.doesNotThrow(() => m.normalizeArtistRecoveredMultipleHydrationPrepared(f.prepared));
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_VALIDATION.completeIdentityAndPayoutSemanticsIndependentlyVerified, false);
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_HYDRATION_VALIDATION.actualRegistrySimulationRequired, true);
});

test("original semantic inventory and operation60 commitment use complete compiler tuples", () => {
  const f = sample(), p = f.prepared, a = child(T.prepared, "admission"), d = child(T.prepared, "data");
  const timing = child(T.prepared, "timing"), guards = child(T.prepared, "externalGuards"), query = child(T.prepared, "query");
  const requestType = compiledInterfaces.registry.getFunction("hydrateRecoveredArtistAuthority").inputs[0];
  const expectedInventory = hash(["bytes32", "uint16", "bytes32", query, d, timing, guards], [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n,
    m.artistRecoveredMultipleHydrationProvenanceHash(f.provenance), p.query, p.data, p.timing, p.externalGuards]);
  assert.equal(m.artistRecoveredMultipleHydrationSemanticInventory(p), expectedInventory);
  const expected = hash(["bytes32", "uint16", "uint256", "address", "address", "address", "address", requestType,
    child(a, "artists"), child(a, "collections"), query, d, timing, guards, child(a, "before_")],
  [id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1"), 1n, f.coords.chainId, f.coords.registry, f.coords.coordinator,
    p.admission.prior, p.admission.sourceCoordinator, f.request, p.admission.artists, p.admission.collections, p.query, p.data, p.timing, p.externalGuards, p.admission.before_]);
  assert.equal(m.artistRecoveredMultipleHydrationCommitment(f.coords, f.request, p), expected);
  const changed = clone(f.request); changed.records.authority.collections[1].policies.push({ phaseId: H(500), policyHash: H(501) });
  assert.throws(() => m.artistRecoveredMultipleHydrationCommitment(f.coords, changed, p), /certificate/);
});

test("Request keeps all selectors, full uint256 and closed entrypoint; advertisements do not widen profile", () => {
  const f = sample(), request = f.request, draft = { ...request, expectedSemanticInventory: Z };
  assert.doesNotThrow(() => m.normalizeArtistRecoveredMultipleHydrationRequestDraft(draft));
  assert.throws(() => m.prepareArtistRecoveredMultipleHydrationCall(f.coords.registry, A(900), draft), /nonzero/);
  const plan = m.prepareArtistRecoveredMultipleHydrationCall(f.coords.registry, A(900), request);
  assert.equal(plan.call.data, compiledInterfaces.registry.encodeFunctionData("hydrateRecoveredArtistAuthority", [request]));
  assert.equal(plan.call.value, 0n); assert.equal(plan.factsVerified, false);
  assert.deepEqual(m.decodeArtistRecoveredMultipleHydrationRequest(m.encodeArtistRecoveredMultipleHydrationRequest(request)), request);
  const raw = m.artistRecoveredMultipleHydrationPreparationCalldata(f.prepared.admission.source, draft);
  assert.equal(raw.slice(0, 10), "0x72c84763");
  const prepare = compiledLibraryValueInterface("prepared").fragments.find(x => x.type === "function" && x.name === "prepare" && x.inputs.length === 2);
  assert.equal(raw.slice(10), coder.encode(prepare.inputs, [f.prepared.admission.source, draft]).slice(2));
  for (const field of ["to", "value", "data"]) {
    const altered = clone(plan); altered.call[field] = field === "to" ? A(901) : field === "value" ? 1n : plan.call.data + "00";
    assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationCall(altered));
  }
  for (const mask of [255n, 511n, 524287n, 262176n, 393216n]) {
    const owner = m.decodeArtistRecoveredMultipleHydrationOwnerPayload(f.prepared.data[0].typedState, 0).payload;
    assert.throws(() => m.encodeArtistRecoveredMultipleHydrationOwnerPayload(owner, 0, mask), /header/);
  }
  assert.doesNotThrow(() => m.validateArtistRecoveredMultipleHydrationCapability(request.expectedCapabilities[0], 0, 262145n));
  assert.throws(() => m.validateArtistRecoveredMultipleHydrationCapability(request.expectedCapabilities[0], 0, 524287n));
});

test("old255/511 adapters retain singleton limits and reject the new aggregate envelopes", () => {
  const f = sample();
  assert.throws(() => old.normalizeArtistRecoveredHydrationRequest(f.request), /one Artist/);
  assert.throws(() => consent.normalizeArtistRecoveredConsentHydrationRequest(f.request), /one Artist/);
  assert.throws(() => old.decodeArtistRecoveredHydrationOwnerPayload(f.prepared.data[2].typedState, 2), /header/);
  assert.throws(() => consent.decodeArtistRecoveredConsentHydrationOwnerPayload(f.prepared.data[2].typedState, 2), /header/);
  assert.deepEqual(old.ARTIST_RECOVERED_HYDRATION_SHAPES, { first: 31n, economics: 63n, delegation: 127n, attestation: 255n });
  const single = clone(f.request); single.records.authority.artistIds = [single.records.authority.collections[0].artistId]; single.records.authority.collections.length = 1;
  assert.doesNotThrow(() => old.normalizeArtistRecoveredHydrationRequest(single));
  assert.doesNotThrow(() => consent.normalizeArtistRecoveredConsentHydrationRequest(single));
  assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationRequest(single), /plural/);
});

test("anchor preserves first collection identity while using that Artist's complete records", () => {
  const f = sample(), state = f.states[0], before = clone(state.collections[0]);
  const q = m.artistRecoveredMultipleHydrationAnchor(state);
  assert.equal(q.artistId, state.artists[1].artistId);
  assert.deepEqual(q.records, state.artists[1].records);
  assert.deepEqual(state.collections[0], before);
  const bad = clone(f.prepared); bad.query.records = bad.admission.collections[0].records;
  assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationPrepared(bad), /anchor/);
  for (const owner of [0, 2, 5, 6]) {
    const altered = sample(); replaceState(altered, owner, s => { s.artists[1].records.pop(); });
    assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationPrepared(altered.prepared), /scope|partition/);
  }
});

test("complete original occurrence partitions cannot be projected, collapsed or cross-associated", () => {
  for (const mutate of [p => p.admission.artists[0].records.pop(), p => p.admission.collections[0].records.pop(),
    p => { p.admission.collections[0].artistId = p.admission.artists[0].artistId; },
    p => { p.admission.before_[2].revision = 3n; }]) {
    const f = sample(); mutate(f.prepared); assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationPrepared(f.prepared));
  }
  const f = sample(), c = f.request.records.authority;
  for (const mutate of [a => a.artistIds.reverse(), a => a.collections.reverse(), a => { a.artistIds[1] = a.artistIds[0]; },
    a => { a.collections[0].artistId = H(9999); }, a => { a.bindingIndex = 1n; }]) {
    const request = clone(f.request); mutate(request.records.authority); assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationRequest(request));
  }
  assert.ok(c.collections[0].collectionId > 2n ** 200n);
});

test("global Identity nonce bijection preserves insertion order and distinct current authorities", () => {
  const f = sample(), checkpoint = f.provenance.eras[0].checkpoints[2];
  const result = m.artistRecoveredMultipleHydrationNonceUnion(f.states[2], f.nonces, checkpoint);
  assert.deepEqual(result.map(r => r.key), f.nonces.map(r => r.index.key));
  assert.notEqual(result[0].key, f.states[2].artists[0].artistId);
  const run = mutate => {
    const s = clone(f.states[2]), b = f.identities.map(value => clone(value)); mutate(b);
    s.rows = b.map(row => coder.encode([T.identity], [row]));
    return m.artistRecoveredMultipleHydrationNonceUnion(s, f.nonces, checkpoint);
  };
  assert.throws(() => run(b => { b[1].identity.authorityAddress = b[0].identity.authorityAddress; }), /authority/);
  assert.throws(() => run(b => { b[0].nextRegistrationNonce = 1n; }), /registration/);
  assert.throws(() => run(b => { b[0].timing.checkpoint.root = H(99); }), /timing/);
  assert.throws(() => run(b => { b[0].nonces[0].key = b[1].artistId; }), /nonce/);
  assert.throws(() => run(b => { b[0].nonces.push(clone(b[0].nonces[0])); }), /nonce/);
  assert.throws(() => run(b => { b[0].nonces[0].words[0].words[31] = 9n; }), /nonce/);
});

test("local empty nonce lists and rotation-vs-estate key recipes retain original distinctions", () => {
  const f = sample(), identities = f.identities.map(value => clone(value));
  const first = identities[0], second = identities[1]; first.nonces = [];
  const rotation = zero(child(T.identity, "rotations").arrayChildren); rotation.record.terms.newAddress = A(810); second.rotations = [rotation];
  const estate = zero(child(T.identity, "estates").arrayChildren); estate.request.terms.successor = A(811); second.estates = [estate];
  const keys = [hash(["bytes32", "bytes32", "address"], [id("rotation_acceptance"), second.artistId, A(810)]),
    hash(["string", "bytes32", "address"], ["estate_activation", second.artistId, A(811)])];
  second.nonces = [4n, 5n].map((kind, i) => ({ kind, key: keys[i], hint: 0n, words: clone(f.nonces[0].words) }));
  const inventory = second.nonces.map(n => ({ index: { kind: n.kind, key: n.key, prefixCount: 1n }, words: n.words }));
  const state = { ...f.states[2], rows: identities.map(b => coder.encode([T.identity], [b])) };
  assert.equal(m.artistRecoveredMultipleHydrationNonceUnion(state, inventory, f.provenance.eras[0].checkpoints[2]).length, 2);
  second.nonces.reverse(); state.rows = identities.map(b => coder.encode([T.identity], [b]));
  assert.throws(() => m.artistRecoveredMultipleHydrationNonceUnion(state, inventory, f.provenance.eras[0].checkpoints[2]), /reordered/);
  second.nonces.reverse(); second.nonces[1].key = hash(["bytes32", "bytes32", "address"], [id("estate_activation"), second.artistId, A(811)]);
  inventory[1].index.key = second.nonces[1].key; state.rows = identities.map(b => coder.encode([T.identity], [b]));
  assert.throws(() => m.artistRecoveredMultipleHydrationNonceUnion(state, inventory, f.provenance.eras[0].checkpoints[2]), /nonce/);
});

test("each Artist requires recovered class1/3 and shared complete timing while permissions remain literal", () => {
  for (const change of [b => { b.identity.authorityClass = 4n; }, b => { b.recoveries = []; },
    b => { b.recoveries[0].record.fields.vestedAuthorityClass = 4n; }, b => { b.sourceSnapshot.revision++; }]) {
    const f = sample(); replaceState(f, 2, s => { const b = clone(f.identities[0]); change(b); s.rows[0] = coder.encode([T.identity], [b]); });
    assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationPrepared(f.prepared));
  }
  const f = sample();
  assert.equal(m.artistRecoveredMultipleHydrationRequiredFeatures(f.identities, f.payouts, 1n), 262147n);
  assert.equal(m.artistRecoveredMultipleHydrationRequiredFeatures(f.identities, f.payouts, 2n), 262163n);
  const b = clone(f.identities); b[0].actions = [zero(child(T.identity, "actions").arrayChildren)];
  b[0].actions[0].evidenceV2.manifestHash = H(90); b[0].actions[0].evidenceV3.manifestHash = H(91);
  assert.equal(m.artistRecoveredMultipleHydrationRequiredFeatures(b, f.payouts, 2n), 262175n);
});

test("generation/economics/delegation/content/platform profiles cannot hide inside re-encoded multiple rows", () => {
  for (const change of [b => { b.item.generation = 2n; b.history.generation = 2n; }, b => { b.item.consentMode = 2n; b.history.consentMode = 2n; },
    b => { b.terms.count = 1n; }, b => { b.terminal.kind = 1n; }, b => { b.item.artistId = Z; b.history.artistId = Z; }]) {
    const f = sample(); replaceState(f, 0, s => { const b = clone(f.bindings[0]); change(b); s.rows[0] = coder.encode([T.binding], [b]); });
    assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationPrepared(f.prepared), /Binding/);
  }
  const f = sample(), request = clone(f.request);
  request.records.witnesses = [{ collectionId: request.records.authority.collections[0].collectionId, economics: [], attestations: [] }];
  assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationRequestDraft(request), /witness/);
  const delegated = sample(); replaceState(delegated, 2, s => { const b = clone(delegated.identities[0]); b.delegations = [zero(child(T.identity, "delegations").arrayChildren)]; s.rows[0] = coder.encode([T.identity], [b]); });
  assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationPrepared(delegated.prepared), /delegation/);
  const attribution = sample(); replaceState(attribution, 4, s => { const b = coder.decode([`tuple(${T.attribution.format("full")} state,bytes32 proposalOrigin)`], s.rows[0])[0];
    s.rows[0] = coder.encode([`tuple(${T.attribution.format("full")} state,bytes32 proposalOrigin)`], [{ state: { ...Object.fromEntries(T.attribution.components.map((p, i) => [p.name, b.state[i]])), item: { state: 2n, generation: 2n } }, proposalOrigin: b.proposalOrigin }]); });
  assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationPrepared(attribution.prepared), /Attribution/);
});

test("original era collection clocks, whole provenance and same-era acceptance are retained", () => {
  const f = sample();
  const corrupted = clone(f.prepared);
  const payload = clone(m.decodeArtistRecoveredMultipleHydrationOwnerPayload(corrupted.data[0].typedState, 0).payload);
  payload.provenance.eras[0].checkpoint.ownerState.revision++;
  corrupted.data[0].typedState = m.encodeArtistRecoveredMultipleHydrationOwnerPayload(payload, 0, f.features);
  assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationPrepared(corrupted), /provenance/);
  const other = sample(); replaceState(other, 4, s => {
    const row = { state: { provenance: m.artistRecoveredMultipleHydrationOwnerProvenanceHash(m.artistRecoveredMultipleHydrationOwnerProvenance(other.provenance, 4), 4),
      artistId: s.collections[0].artistId, collectionId: s.collections[0].collectionId, bindingHash: s.collections[0].bindingHash, item: { state: 2n, generation: 1n } }, proposalOrigin: H(999) };
    s.rows[0] = coder.encode([`tuple(${T.attribution.format("full")} state,bytes32 proposalOrigin)`], [row]);
  });
  assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationPrepared(other.prepared), /era/);
});

test("paged evidence reconstructs exact original bytes and retained profile partitions", () => {
  const f = sample(), bytes = m.encodeArtistRecoveredMultipleHydrationProfileEvidence(f.request, f.prepared);
  const decoded = m.decodeArtistRecoveredMultipleHydrationProfileEvidence(bytes);
  assert.deepEqual(decoded.artists, f.prepared.admission.artists);
  assert.deepEqual(decoded.collections, f.prepared.admission.collections);
  const pages = m.artistRecoveredMultipleHydrationEvidencePages(bytes);
  const descriptor = m.artistRecoveredMultipleHydrationEvidenceDescriptor(bytes);
  assert.equal(m.assembleArtistRecoveredMultipleHydrationEvidence(descriptor, pages), bytes);
  assert.throws(() => m.decodeArtistRecoveredMultipleHydrationProfileEvidence(bytes + "00"), /canonical/);
  assert.throws(() => m.assembleArtistRecoveredMultipleHydrationEvidence(descriptor, [...pages, "0x00"]));
});

test("strict owned values, immutable copies and aggregate allocation guards precede deep copies", () => {
  const f = sample(), plan = m.prepareArtistRecoveredMultipleHydrationCall(f.coords.registry, A(999), f.request);
  f.request.records.authority.artistIds[0] = H(9);
  assert.notEqual(plan.request.records.authority.artistIds[0], H(9));
  assert.ok(Object.isFrozen(plan.request.records.authority.collections));
  for (const mutate of [r => { r.extra = 1; }, r => { delete r.expectedCapabilities[2]; }, r => { r.records.authority.bindingIndex = 0; },
    r => { r.records.authority.artistIds[Symbol("hidden")] = true; }, r => { Object.defineProperty(r.records.authority, "artistIds", { get() { throw Error("Getter must not execute"); } }); }]) {
    const bad = clone(plan.request); mutate(bad); assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationRequest(bad), /exact|dense|bigint|owned/);
  }
  const state = clone(f.states[2]), repeated = "0x" + "11".repeat(200_000);
  state.rows = Array(100).fill(repeated);
  assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationState(state), /allocation/);
  const hugeCount = "0x" + "ff".repeat(32);
  assert.throws(() => m.decodeArtistRecoveredMultipleHydrationIdentity(hugeCount), /offset|allocation/);
});

test("warm Identity schemas avoid reparsing while preserving ABI bytes and fresh value validation", () => {
  const f = sample(), identity = f.identities[0];
  const expected = coder.encode([T.identity], [identity]);
  assert.equal(m.encodeArtistRecoveredMultipleHydrationIdentity(identity), expected);
  const saved = m.decodeArtistRecoveredMultipleHydrationIdentity(expected);
  assert.deepEqual(saved, identity);
  const original = ParamType.from;
  let parsedStrings = 0;
  ParamType.from = function(value, ...args) {
    if (typeof value === "string") parsedStrings++;
    return Reflect.apply(original, this, [value, ...args]);
  };
  try {
    assert.equal(m.encodeArtistRecoveredMultipleHydrationIdentity(identity), expected);
    assert.deepEqual(m.decodeArtistRecoveredMultipleHydrationIdentity(expected), saved);
    identity.nonces[0].words[0].words[31] = 9n;
    const changed = m.encodeArtistRecoveredMultipleHydrationIdentity(identity);
    assert.notEqual(changed, expected);
    assert.equal(changed, coder.encode([T.identity], [identity]));
    assert.equal(saved.nonces[0].words[0].words[31], 0n);
    identity.nextRegistrationNonce = 2;
    assert.throws(() => m.encodeArtistRecoveredMultipleHydrationIdentity(identity), /bigint/);
    Object.defineProperty(identity, "nextRegistrationNonce", { get() { throw Error("Getter must not execute"); } });
    assert.throws(() => m.normalizeArtistRecoveredMultipleHydrationIdentity(identity), /owned/);
    assert.throws(() => m.decodeArtistRecoveredMultipleHydrationIdentity(expected + "00".repeat(32)), /canonical/);
    assert.equal(parsedStrings, 0, "warm known schemas must not be reparsed for each payload");
  } finally {
    ParamType.from = original;
  }
});

test("schema reuse retains tuple field names and validation after the private cache fills", () => {
  const engine = createArtistRecoveredHydrationCodec(262175n);
  const left = "tuple(uint256 source)", right = "tuple(uint256 destination)";
  const input = { source: 7n }, saved = engine.normalizeTuple(left, input);
  const bytes = coder.encode([left], [input]);
  assert.deepEqual(engine.decodeTuple(left, bytes), { source: 7n });
  assert.deepEqual(engine.decodeTuple(right, bytes), { destination: 7n });
  assert.throws(() => engine.normalizeTuple(right, input), /exact/);
  // JavaScript callers of the private engine can still supply mutable ABI objects.
  const schema = { type: "tuple", components: [{ type: "uint256", name: "before" }] };
  assert.deepEqual(engine.normalizeTuple(schema, { before: 7n }), { before: 7n });
  schema.components[0].name = "after";
  assert.deepEqual(engine.decodeTuple(schema, bytes), { after: 7n });
  assert.throws(() => engine.normalizeTuple(schema, { before: 7n }), /exact/);
  for (let i = 0; i < 130; i++) {
    const name = `field${i}`, type = `tuple(uint256 ${name})`;
    assert.deepEqual(engine.decodeTuple(type, bytes), { [name]: 7n });
  }
  input.source = 8n;
  assert.equal(saved.source, 7n);
  assert.equal(engine.encodeTupleValues([left], [engine.normalizeTuple(left, input)]), coder.encode([left], [input]));
  assert.throws(() => engine.decodeTuple(right, bytes + "00".repeat(32)), /canonical/);
  assert.throws(() => engine.normalizeTuple(left, { source: 8 }), /bigint/);
  // Oversize valid schema keys remain accepted but are parsed without retention.
  const longName = "x".repeat(65_536), longType = `tuple(uint256 ${longName})`;
  assert.deepEqual(engine.normalizeTuple(longType, { [longName]: 9n }), { [longName]: 9n });
});

test("same original owner commitment transition is applied once across a plural graph", () => {
  const f = sample(), commitment = m.artistRecoveredMultipleHydrationCommitment(f.coords, f.request, f.prepared);
  const destination = { ...f.origin, registry: f.coords.registry, coordinator: f.coords.coordinator, archive: A(103), owners: seven(i => A(110 + i)), ownerCodeHashes: seven(i => H(600 + i)) };
  for (let i = 0; i < 7; i++) {
    const before = f.prepared.admission.before_[i];
    const after = m.artistRecoveredMultipleHydrationOwnerAfter(destination, i, before, f.prepared.query, f.prepared.data[i], commitment, A(900), []);
    assert.equal(after.revision, before.revision + 1n);
    assert.equal(after.recordChainTip, before.recordChainTip);
    assert.notEqual(after.stateRoot, before.stateRoot);
  }
});
