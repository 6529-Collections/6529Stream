import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroHash, ZeroAddress, getAddress, id, keccak256 } from "ethers";
import * as r from "../dist/current-artist-recovered-hydration.js";
import * as h from "../dist/current-artist-authority-hydration.js";

const coder = AbiCoder.defaultAbiCoder();
const Z = ZeroHash;
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
const clone = structuredClone;
const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-recovered-hydration-abi.json", import.meta.url), "utf8"));
const registry = new Interface(fixture.abis.registry);
const hash = (types, values) => keccak256(coder.encode(types, values));
const seven = fn => Array.from({ length: 7 }, (_, i) => fn(i));

// Synthetic structural certificate. Opaque semanticState deliberately makes no live admission claim.
function sample({ witnesses = false, history = false } = {}) {
  const chainId = (1n << 200n) + 11n;
  const suite = {
    registry: A(1), archive: A(3), owners: seven(i => A(10 + i)), core: A(4), mintManager: A(5),
    roleRegistry: A(6), metadata: A(7), primaryResolver: A(8), royaltyResolver: A(9), primaryRevenueClass: H(8), validator: A(17),
  };
  const origin = {
    chainId, registry: suite.registry, coordinator: A(2), archive: suite.archive, owners: suite.owners,
    ownerCodeHashes: seven(i => H(100 + i)), core: suite.core, manager: suite.mintManager,
    suiteConfigurationHash: hash([h.ARTIST_HYDRATION_SUITE_TUPLE], [suite]),
  };
  const originHash = r.artistRecoveredHydrationOriginHash(origin);
  const artistId = H(1000), collectionId = (1n << 240n) + 3n, bindingHash = H(1001);
  const journals = seven(() => []);
  function row(ownerIndex, operation, recordHash, cid, revision) {
    journals[ownerIndex].push({ position: { point: { environmentHash: originHash, ownerIndex: BigInt(ownerIndex), ownerRevision: revision }, nativeIndex: BigInt(journals[ownerIndex].length) },
      receipt: { operation, artistId, collectionId: cid, recordHash } });
  }
  row(0, 2n, bindingHash, collectionId, 1n);
  row(2, 1n, artistId, 0n, 1n);
  row(2, 35n, H(1002), 0n, 2n);
  row(2, 35n, H(1002), 0n, 2n); // Native occurrences may repeat a hash and revision.
  if (witnesses) {
    row(4, 24n, H(1003), collectionId, 1n);
    row(6, 15n, H(1004), collectionId, 1n);
  }
  const checkpoints = seven(i => ({ schema: r.ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA,
    ownerState: { domainId: r.artistRecoveredHydrationOwnerDomain(i), revision: 10n, stateRoot: H(200 + i), recordChainTip: H(220 + i) },
    replayRoot: Z, replayCount: 0n, nonceRoot: Z, nonceIndexCount: 0n }));
  const aliases = seven(() => []), logical = seven(() => []);
  if (history) {
    const surfaces = [id("identity_authority.replay.import_binding"), id("identity_authority.replay.one_way_cutover_latch"), id("ordinary.active")];
    for (const surface of surfaces) {
      const entry = { surface, scope: surface === surfaces[1] ? Z : H(2000) };
      logical[2].push(entry);
      const key = r.artistRecoveredHydrationReplayKey(origin, 2, entry);
      aliases[2].push({ originHash, ownerIndex: 2n, ...entry, originalKey: key,
        cell: { commitment: H(3333), touchedRevision: 2n, kind: 1n, status: 2n },
        admittedAt: { environmentHash: originHash, ownerIndex: 2n, ownerRevision: 2n } });
    }
    aliases[2].sort((a, b) => BigInt(a.originalKey) < BigInt(b.originalKey) ? -1 : 1);
    checkpoints[2].replayCount = 3n;
    checkpoints[2].replayRoot = H(2333);
  }
  const provenance = { origins: [origin], eras: [{ originHash, checkpoints, nativeCounts: journals.map(rows => BigInt(rows.length)), lowerRevisions: seven(() => 0n), priorImportCommitment: Z }], journals, aliases };
  const allRecords = journals.flat().map(row => row.receipt.recordHash);
  const collectionRecords = journals.flat().filter(row => row.receipt.collectionId !== 0n).map(row => row.receipt.recordHash);
  const artist = { artistId, collectionId: 0n, bindingHash: Z, policies: [], records: allRecords };
  const collection = { artistId, collectionId, bindingHash, policies: [], records: collectionRecords };
  const query = { ...collection, records: allRecords };
  const features = witnesses ? 161n : 1n;
  const data = seven(i => {
    const local = r.artistRecoveredHydrationOwnerProvenance(provenance, i);
    const payload = { provenance: local, nonces: [], semanticState: "0x1234", publications: [] };
    const sourceKeys = logical[i].map(originLogical => r.artistRecoveredHydrationReplayKey(origin, i, originLogical));
    return { typedState: r.encodeArtistRecoveredHydrationOwnerPayload(payload, i, features), origins: logical[i], sourceKeys,
      cells: sourceKeys.map(key => aliases[i].find(alias => alias.originalKey === key).cell), nonces: [] };
  });
  const before_ = seven(i => ({ domainId: r.artistRecoveredHydrationOwnerDomain(i), revision: i === 2 ? 3n : 0n, stateRoot: H(300 + i), recordChainTip: H(320 + i) }));
  const prepared = { admission: { prior: origin.registry, sourceCoordinator: origin.coordinator, source: suite, provenance, artists: [artist], collections: [collection], before_ },
    query, data, timing: { schema: id("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1"), version: 1n, count: 0n, root: Z, configurationHash: H(400) },
    externalGuards: { schema: id("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1"), provenanceCommitment: r.artistRecoveredHydrationProvenanceHash(provenance), artistId, actions: [], finality: [], entropy: [] } };
  const request = { records: { authority: { bindingIndex: 0n, artistIds: [artistId], collections: [{ artistId, collectionId, policies: [] }], expectedSource: checkpoints, replayOrigins: logical },
    witnesses: witnesses ? [{ collectionId, economics: [{ collectionId, resolver: suite.primaryResolver, revenueClass: H(55), scope: 2n, scopeId: collectionId, assignmentHash: H(56) }],
      attestations: [{ terms: { collectionId, subjectKind: 8n, subjectId: H(57), subjectStateHash: Z, schemaId: H(58), statementHash: H(59), statementURI: "ipfs://original" }, nonce: 0n }] }] : [] },
    expectedCapabilities: seven(i => ({ profile: r.ARTIST_RECOVERED_HYDRATION_PROFILE, version: 1n, ownerIndex: BigInt(i), ownerDomain: r.artistRecoveredHydrationOwnerDomain(i),
      checkpointSchema: r.ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA, stateSchema: r.artistRecoveredHydrationOwnerTag(i), supportedFeatures: 255n })),
    expectedSourceImportCommitment: Z, expectedSemanticInventory: r.artistRecoveredHydrationSemanticInventory(prepared) };
  const coords = { chainId, registry: A(101), coordinator: A(102) };
  const destination = { ...origin, registry: coords.registry, coordinator: coords.coordinator, archive: A(103), owners: seven(i => A(110 + i)), ownerCodeHashes: seven(i => H(500 + i)) };
  return { request, prepared, origin, provenance, coords, destination, features };
}

test("draft preparation is distinct from final permissionless Registry CALL", () => {
  const { request, prepared, coords } = sample();
  const draft = { ...request, expectedSemanticInventory: Z };
  r.normalizeArtistRecoveredHydrationRequestDraft(draft);
  assert.throws(() => r.prepareArtistRecoveredHydrationCall(coords.registry, A(900), draft), /nonzero/);
  const read = r.artistRecoveredHydrationPreparationCalldata(prepared.admission.source, draft);
  assert.equal(read.slice(0, 10), "0x72c84763");
  assert.equal(read.slice(10), coder.encode([h.ARTIST_HYDRATION_SUITE_TUPLE, r.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE], [prepared.admission.source, draft]).slice(2));
  const plan = r.prepareArtistRecoveredHydrationCall(coords.registry, A(900), request);
  assert.equal(plan.call.data, registry.encodeFunctionData("hydrateRecoveredArtistAuthority", [request]));
  assert.equal(plan.caller, A(900)); assert.equal(plan.call.value, 0n); assert.equal(plan.factsVerified, false);
  assert.throws(() => r.prepareArtistRecoveredHydrationCall(coords.registry, ZeroAddress, request));
});

test("strict complete request snapshots retain full widths and reject sparse or surplus fields", () => {
  const { request, coords } = sample();
  const plan = r.prepareArtistRecoveredHydrationCall(coords.registry, A(900), request);
  request.records.authority.collections[0].collectionId = 4n;
  assert.ok(plan.request.records.authority.collections[0].collectionId > 2n ** 53n);
  assert.ok(Object.isFrozen(plan.request.records.authority.collections));
  assert.throws(() => r.normalizeArtistRecoveredHydrationCall({ ...plan, call: { ...plan.call, value: 1n } }));
  const extra = clone(plan.request); extra.unrecognized = 1; assert.throws(() => r.normalizeArtistRecoveredHydrationRequest(extra), /exact/);
  const number = clone(plan.request); number.records.authority.bindingIndex = 0; assert.throws(() => r.normalizeArtistRecoveredHydrationRequest(number), /bigint/);
  const sparse = clone(plan.request); delete sparse.expectedCapabilities[2]; assert.throws(() => r.normalizeArtistRecoveredHydrationRequest(sparse), /dense/);
  assert.deepEqual(r.decodeArtistRecoveredHydrationRequest(r.encodeArtistRecoveredHydrationRequest(plan.request)), plan.request);
});

test("required features are actual source OR rather than advertised graph masks", () => {
  const facts = { currentAuthorityClass: 1n, recoveryAuthorityClasses: [3n], hasAdjudicationV2: false, hasRewindsV3: false, eraCount: 1n,
    economicsCount: 0n, hasDelegations: false, bindingConsentMode: 1n, saleConsentCount: 0n, attestationCount: 0n };
  assert.equal(r.artistRecoveredHydrationRequiredFeatures(facts), 3n);
  assert.equal(r.artistRecoveredHydrationRequiredFeatures({ ...facts, hasAdjudicationV2: true, hasRewindsV3: true, eraCount: 2n, economicsCount: 1n, saleConsentCount: 1n, attestationCount: 1n }), 255n);
  assert.throws(() => r.artistRecoveredHydrationRequiredFeatures({ ...facts, recoveryAuthorityClasses: [4n] }));
  const c = sample().request.expectedCapabilities[2];
  assert.doesNotThrow(() => r.validateArtistRecoveredHydrationCapability({ ...c, supportedFeatures: 1n }, 2, 1n));
  assert.throws(() => r.validateArtistRecoveredHydrationCapability(c, 2, 511n));
  assert.deepEqual(r.ARTIST_RECOVERED_HYDRATION_SHAPES, { first: 31n, economics: 63n, delegation: 127n, attestation: 255n });
});

test("origin identity binds complete suite, exact runtimes and all uint256 coordinates", () => {
  const { origin } = sample();
  const tuple = fixture.abis.recoveredOwner.find(f => f.name === "recoveredHydrationOrigin").outputs[0];
  assert.equal(r.artistRecoveredHydrationOriginHash(origin), hash(["bytes32", "uint16", tuple], [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_ORIGIN_V1"), 1n, origin]));
  const changed = clone(origin); changed.ownerCodeHashes[6] = H(9999);
  assert.notEqual(r.artistRecoveredHydrationOriginHash(changed), r.artistRecoveredHydrationOriginHash(origin));
});

test("native journal preserves owner-major occurrence order and adjacent equal revisions", () => {
  const { prepared } = sample();
  r.normalizeArtistRecoveredHydrationPrepared(prepared);
  const truncated = clone(prepared); truncated.admission.provenance.journals[2].pop();
  assert.throws(() => r.normalizeArtistRecoveredHydrationPrepared(truncated), /order/);
  const reordered = clone(prepared); reordered.admission.artists[0].records.reverse();
  assert.throws(() => r.normalizeArtistRecoveredHydrationPrepared(reordered), /partition/);
  const zeroRevision = clone(prepared); zeroRevision.admission.provenance.journals[2][0].position.point.ownerRevision = 0n;
  assert.throws(() => r.normalizeArtistRecoveredHydrationPrepared(zeroRevision), /order/);
  const importRow = clone(prepared); importRow.admission.provenance.journals[2][1].receipt.operation = 60n;
  assert.throws(() => r.normalizeArtistRecoveredHydrationPrepared(importRow), /native receipt/);
});

test("chronology follows eras, permits lower-bound auxiliary points and forbids cross-owner comparison", () => {
  const { provenance } = sample();
  const local = clone(r.artistRecoveredHydrationOwnerProvenance(provenance, 2));
  const second = { ...local.origins[0], registry: A(201), coordinator: A(202), owners: seven(i => A(210 + i)) };
  const secondHash = r.artistRecoveredHydrationOriginHash(second);
  local.origins.push(second);
  local.eras.push({ ...local.eras[0], originHash: secondHash, lowerRevision: 1n, nativeCount: 0n, priorImportCommitment: H(777), checkpoint: { ...local.eras[0].checkpoint, ownerState: { ...local.eras[0].checkpoint.ownerState, revision: 1n } } });
  const old = { environmentHash: local.eras[0].originHash, ownerIndex: 2n, ownerRevision: 10n };
  const current = { environmentHash: secondHash, ownerIndex: 2n, ownerRevision: 1n };
  assert.equal(r.compareArtistRecoveredHydrationPoints(local, old, current), -1);
  assert.throws(() => r.compareArtistRecoveredHydrationPoints(local, old, { ...current, ownerIndex: 1n }), /same original owner/);
});

test("replay aliases sort by full original key while active replay input keeps insertion order", () => {
  const { prepared, origin } = sample({ history: true });
  r.normalizeArtistRecoveredHydrationPrepared(prepared);
  const key = r.artistRecoveredHydrationReplayKey(origin, 2, prepared.data[2].origins[0]);
  assert.equal(key, hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), origin.chainId, origin.registry, origin.coordinator, origin.archive, origin.owners[2], id("domain:identity_authority"), prepared.data[2].origins[0].surface, prepared.data[2].origins[0].scope]));
  const swapped = clone(prepared.admission.provenance); swapped.aliases[2].reverse();
  assert.throws(() => r.normalizeArtistRecoveredHydrationProvenance(swapped), /alias or order/);
  const malformed = clone(prepared); malformed.data[2].sourceKeys[0] = H(88888);
  assert.throws(() => r.normalizeArtistRecoveredHydrationPrepared(malformed), /Guard inventory/);
});

test("nonce shape covers all original kinds, all32 words and consistent exhaustion", () => {
  const checkpoint = sample().provenance.eras[0].checkpoints[2];
  const c = { ...checkpoint, nonceIndexCount: 1n };
  const row = { index: { kind: 5n, key: H(999), prefixCount: 2n }, words: [0n, 1n].map(prefix => ({ prefix, words: Array(32).fill(2n ** 255n), exhausted: true })) };
  const normalized = r.normalizeArtistRecoveredHydrationNonceInventory([row], c);
  assert.equal(normalized[0].words[0].words[31], 2n ** 255n);
  const duplicate = clone(row); duplicate.words[1].prefix = 0n; assert.throws(() => r.normalizeArtistRecoveredHydrationNonceInventory([duplicate], c), /prefix/);
  const inconsistent = clone(row); inconsistent.words[1].exhausted = false; assert.throws(() => r.normalizeArtistRecoveredHydrationNonceInventory([inconsistent], c), /prefix/);
  const short = clone(row); short.words[0].words.pop(); assert.throws(() => r.normalizeArtistRecoveredHydrationNonceInventory([short], c), /dense/);
});

test("owner payload header counts native occurrences and publication catalog retains exact pointers/order", () => {
  const { prepared } = sample();
  const decoded = r.decodeArtistRecoveredHydrationOwnerPayload(prepared.data[2].typedState, 2);
  assert.equal(decoded.header.semanticRecordCount, 3n);
  const payload = { ...decoded.payload, publications: [{ pointer: A(700), payloadType: H(2), payloadHash: H(3) }, { pointer: A(701), payloadType: H(2), payloadHash: H(4) }] };
  const raw = r.encodeArtistRecoveredHydrationOwnerPayload(payload, 2, 1n);
  assert.deepEqual(r.decodeArtistRecoveredHydrationOwnerPayload(raw, 2).payload.publications, payload.publications);
  assert.throws(() => r.encodeArtistRecoveredHydrationOwnerPayload({ ...payload, publications: [payload.publications[0], { ...payload.publications[0], pointer: A(799) }] }, 2, 1n), /Duplicate publication/);
  assert.throws(() => r.normalizeArtistRecoveredHydrationPublications(payload.publications, 5), /no original publication/);
  assert.throws(() => r.decodeArtistRecoveredHydrationOwnerPayload(`${raw}${"00".repeat(32)}`, 2), /Noncanonical/);
});

test("complete witness families cannot be omitted, shortened or replaced with empty wrappers", () => {
  const { prepared, request, coords } = sample({ witnesses: true });
  r.artistRecoveredHydrationCommitment(coords, request, prepared);
  const missing = clone(request); missing.records.witnesses = [];
  assert.throws(() => r.artistRecoveredHydrationCommitment(coords, missing, prepared), /witness family/);
  const partial = clone(request); partial.records.witnesses[0].attestations = [];
  assert.throws(() => r.artistRecoveredHydrationCommitment(coords, partial, prepared), /witness family/);
  const empty = sample().request; empty.records.witnesses = [{ collectionId: empty.records.authority.collections[0].collectionId, economics: [], attestations: [] }];
  assert.throws(() => r.normalizeArtistRecoveredHydrationRequest(empty), /empty witness/);
});

test("semantic inventory and final commitment use original independent preimages; actor binds evidence only", () => {
  const { prepared: p, request, coords } = sample();
  const expectedInventory = hash(["bytes32", "uint16", "bytes32", h.ARTIST_HYDRATION_QUERY_TUPLE, `${h.ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`, r.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, r.ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE],
    [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, r.artistRecoveredHydrationProvenanceHash(p.admission.provenance), p.query, p.data, p.timing, p.externalGuards]);
  assert.equal(request.expectedSemanticInventory, expectedInventory);
  const value = r.artistRecoveredHydrationCommitment(coords, request, p);
  const expected = hash(["bytes32", "uint16", "uint256", "address", "address", "address", "address", r.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE, `${h.ARTIST_HYDRATION_QUERY_TUPLE}[]`, `${h.ARTIST_HYDRATION_QUERY_TUPLE}[]`, h.ARTIST_HYDRATION_QUERY_TUPLE,
    `${h.ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`, r.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, r.ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE, `${h.ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7]`],
    [r.ARTIST_RECOVERED_HYDRATION_PROFILE, 1n, coords.chainId, coords.registry, coords.coordinator, p.admission.prior, p.admission.sourceCoordinator, request, p.admission.artists, p.admission.collections, p.query, p.data, p.timing, p.externalGuards, p.admission.before_]);
  assert.equal(value, expected);
  assert.notEqual(r.artistRecoveredHydrationEvidenceId(coords, A(900), value), r.artistRecoveredHydrationEvidenceId(coords, A(901), value));
  const changed = clone(p); changed.admission.before_[0].stateRoot = H(9999);
  assert.equal(r.artistRecoveredHydrationSemanticInventory(changed), expectedInventory);
  assert.notEqual(r.artistRecoveredHydrationCommitment(coords, request, changed), value);
});

test("Prepared and profile evidence are canonical immutable bytes with distinct allocation bounds", () => {
  const { prepared, request } = sample();
  const raw = r.encodeArtistRecoveredHydrationPrepared(prepared);
  assert.deepEqual(r.decodeArtistRecoveredHydrationPrepared(raw), r.normalizeArtistRecoveredHydrationPrepared(prepared));
  assert.throws(() => r.decodeArtistRecoveredHydrationPrepared(`${raw}00`));
  const profile = r.encodeArtistRecoveredHydrationProfileEvidence(request, prepared);
  assert.equal(r.decodeArtistRecoveredHydrationProfileEvidence(profile).request.expectedSemanticInventory, request.expectedSemanticInventory);
  assert.ok(r.ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES > r.ARTIST_RECOVERED_HYDRATION_MAX_BYTES);
});

test("original page boundaries, full payload limits and page identities reject reorder and trailing data", () => {
  const { coords } = sample();
  for (const length of [1, 20_480, 20_481, 2_621_440]) {
    const payload = `0x${"a5".repeat(length)}`;
    const descriptor = r.artistRecoveredHydrationEvidenceDescriptor(payload);
    const pages = r.artistRecoveredHydrationEvidencePages(payload);
    assert.equal(pages.length, Math.ceil(length / 20_480));
    assert.equal(r.assembleArtistRecoveredHydrationEvidence(descriptor, pages), payload);
    assert.equal(r.artistRecoveredHydrationPageId(coords, H(777), descriptor, 0n), hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint256", "uint256", "uint256", "bytes32"],
      [r.ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA, coords.chainId, coords.registry, coords.coordinator, H(777), descriptor.payloadHash, BigInt(length), BigInt(pages.length), 0n, descriptor.pageHashes[0]]));
  }
  assert.throws(() => r.artistRecoveredHydrationEvidenceDescriptor("0x"));
  assert.throws(() => r.artistRecoveredHydrationEvidenceDescriptor(`0x${"00".repeat(2_621_441)}`));
  const payload = `0x${"11".repeat(20_480)}22`, descriptor = r.artistRecoveredHydrationEvidenceDescriptor(payload);
  assert.throws(() => r.assembleArtistRecoveredHydrationEvidence(descriptor, [...r.artistRecoveredHydrationEvidencePages(payload)].reverse()));
});

test("original eight-field operation envelope binds actual actor and tagged configuration", () => {
  const { prepared, request, coords } = sample();
  const commitment = r.artistRecoveredHydrationCommitment(coords, request, prepared);
  const descriptor = r.artistRecoveredHydrationEvidenceDescriptor(r.encodeArtistRecoveredHydrationProfileEvidence(request, prepared));
  const input = { schemaVersion: 1n, configurationHash: H(123), operationId: 60n, actor: A(900), commitment,
    before: prepared.admission.before_, after: prepared.admission.before_, profileData: r.encodeArtistRecoveredHydrationEvidenceCarrier(descriptor) };
  const raw = r.encodeArtistRecoveredHydrationOperationEvidence(input);
  assert.deepEqual(r.decodeArtistRecoveredHydrationOperationEvidence(raw), input);
  assert.throws(() => r.encodeArtistRecoveredHydrationOperationEvidence(input, (raw.length - 2) / 2 - 1), /bounded/);
  assert.throws(() => r.decodeArtistRecoveredHydrationOperationEvidence(`${raw}${"00".repeat(32)}`), /Noncanonical/);
});

test("owner roots use active and historical guard deltas plus hashed zero record delta", () => {
  const { prepared, destination } = sample({ history: true });
  const data = prepared.data[2], value = H(6000), actor = A(900);
  const historicalCells = data.origins.map((logical, i) => ({ logical, sourceKey: data.sourceKeys[i] })).filter(row => row.logical.surface !== id("ordinary.active"))
    .map(row => ({ sourceKey: row.sourceKey, cell: row.logical.surface === id("identity_authority.replay.one_way_cutover_latch")
      ? { commitment: Z, touchedRevision: 0n, kind: 0n, status: 0n }
      : { commitment: H(7000), touchedRevision: 1n, kind: 1n, status: 2n } }));
  let active = Z, historical = Z;
  const aliases = prepared.admission.provenance.aliases[2];
  for (let i = 0; i < data.origins.length; i++) {
    const key = r.artistRecoveredHydrationReplayKey(destination, 2, data.origins[i]);
    const local = historicalCells.find(row => row.sourceKey === data.sourceKeys[i]);
    if (local) historical = hash(["bytes32", r.ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE, "bytes32", h.ARTIST_HYDRATION_REPLAY_CELL_TUPLE], [historical, aliases.find(row => row.originalKey === local.sourceKey), key, local.cell]);
    else active = hash(["bytes32", "bytes32", h.ARTIST_HYDRATION_REPLAY_CELL_TUPLE], [active, key, data.cells[i]]);
  }
  const delta = hash(["bytes32", "uint16", "uint8", "bytes32", "bytes32", "bytes32"], [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_GUARDS_V1"), 1n, 2n, value, active, historical]);
  assert.equal(r.artistRecoveredHydrationOwnerReplayDelta(destination, 2, data, value, historicalCells), delta);
  const before = prepared.admission.before_[2];
  const after = r.artistRecoveredHydrationOwnerAfter(destination, 2, before, prepared.query, data, value, actor, historicalCells);
  const expected = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"), destination.chainId, destination.registry, destination.coordinator, destination.archive, destination.owners[2], before.domainId, before.revision, before.revision + 1n, before.stateRoot,
      hash(["uint16", "address", "bytes32"], [60n, actor, value]), hash([h.ARTIST_HYDRATION_QUERY_TUPLE, h.ARTIST_HYDRATION_OWNER_DATA_TUPLE, "bytes32"], [prepared.query, data, value]), delta, hash(["bytes32"], [Z])]);
  assert.equal(after.stateRoot, expected); assert.equal(after.recordChainTip, before.recordChainTip);
  assert.throws(() => r.artistRecoveredHydrationOwnerAfter(destination, 2, before, prepared.query, data, value, actor, []), /history admission/);
  assert.throws(() => r.artistRecoveredHydrationOwnerAfter(destination, 2, { ...before, revision: 2n ** 64n - 1n }, prepared.query, data, value, actor, historicalCells), /snapshot/);
});

test("full calldata byte bound includes selector and reconstructs every accepted near-boundary plan", () => {
  const { request, prepared, coords } = sample({ witnesses: true });
  request.records.witnesses[0].attestations[0].terms.statementURI = "";
  const baseLength = (registry.encodeFunctionData("hydrateRecoveredArtistAuthority", [request]).length - 2) / 2;
  const budget = r.ARTIST_RECOVERED_HYDRATION_MAX_BYTES - baseLength;
  const acceptedLength = budget - budget % 32;
  request.records.witnesses[0].attestations[0].terms.statementURI = "x".repeat(acceptedLength);
  const call = r.prepareArtistRecoveredHydrationCall(coords.registry, A(900), request);
  assert.deepEqual(r.normalizeArtistRecoveredHydrationCall(call), call);
  request.records.witnesses[0].attestations[0].terms.statementURI += "x";
  assert.throws(() => r.prepareArtistRecoveredHydrationCall(coords.registry, A(900), request), /bounded/);
  assert.throws(() => r.artistRecoveredHydrationPreparationCalldata(prepared.admission.source, request), /bounded/);
});

test("Prepared outer admission rejects invented artist binding and destination revisions", () => {
  const { prepared } = sample();
  for (const change of [
    p => { p.admission.artists[0].bindingHash = H(999); },
    p => { p.admission.artists[0].policies = [{ phaseId: H(1), policyHash: H(2) }]; },
    p => { p.admission.collections[0].bindingHash = Z; p.query.bindingHash = Z; },
    p => { p.admission.before_[2].revision = 4n; },
    p => { p.admission.before_[1].domainId = p.admission.before_[0].domainId; },
  ]) {
    const changed = clone(prepared); change(changed);
    assert.throws(() => r.normalizeArtistRecoveredHydrationPrepared(changed));
  }
});
