import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256, toBeHex } from "ethers";
import * as h from "../dist/current-artist-authority-hydration.js";

const coder = AbiCoder.defaultAbiCoder();
const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-authority-hydration-abi.json", import.meta.url), "utf8"));
const original = new Interface(fixture.abis.artist), codec = new Interface(fixture.abis.delegationCodec);
const addr = n => getAddress(toBeHex(n, 20)), seven = fn => Array.from({ length: 7 }, (_, i) => fn(i));
const hash = (types, values) => keccak256(coder.encode(types, values));
const coords = { chainId: (1n << 200n) + 7n, registry: addr(1), coordinator: addr(2), predecessorRegistry: addr(3), sourceCoordinator: addr(4) };
const actor = addr(5), artistId = id("Artist"), collectionId = (1n << 180n) + 8n, bindingHash = id("binding");
const snapshots = () => seven(i => ({ domainId: i === 2 ? id("domain:identity_authority") : id(`owner${i}`), revision: BigInt(i), stateRoot: id(`state${i}`), recordChainTip: id(`tip${i}`) }));
const headers = () => snapshots().map((ownerState, i) => ({ schema: h.ARTIST_HYDRATION_CHECKPOINT_SCHEMA, ownerState,
  replayRoot: id(`replay${i}`), replayCount: 0n, nonceRoot: id(`nonce${i}`), nonceIndexCount: i === 2 ? 1n : 0n }));
const nonce = () => ({ prefix: (1n << 140n) + 2n, words: Array.from({ length: 32 }, (_, i) => (1n << BigInt(i)) + 1n), exhausted: false });
const single = () => ({ bindingIndex: 0n, artistId, collectionId, expectedSource: headers(), replayOrigins: seven(() => []), policies: [] });
function identity(count = 1n, records = 3) {
  const document = "0x123456";
  return { item: { authorityAddress: addr(10), authorityClass: 1n, status: 1n, registeredAt: 1n, lastAuthorityActionAt: 2n,
    identityRecordHash: keccak256(document), identityRecordURI: "ipfs://原本", displayName: "Artist", nonceHint: 0n },
    document, nextRegistrationNonce: count, estateActivity: (1n << 150n) + 2n, dormancyActivity: 3n, findingActivity: 4n, signatures: Array.from({ length: records }, () => "0x") };
}
function binding(artist = artistId, hash = bindingHash, consentMode = 1n) {
  return { item: { artistId: artist, artistAddress: addr(10), identityRecordHash: identity().item.identityRecordHash, bindingHash: hash,
    generation: 1n, consentMode, saleConsentScope: 0n, registryImmutabilityElection: 0n, proposer: addr(11), accepted: true },
    terms: { collaboratorSetHash: id("empty-collaborators"), capabilityPolicySetHash: id("policies"), mode: 0n, threshold: 0n, count: 0n } };
}
function baseData() {
  const states = [binding(), null, identity(), { record: id("acceptance"), acceptedAt: 5n }, { state: 2n, generation: 1n }, null, []];
  return states.map((state, i) => ({ typedState: h.encodeArtistHydrationOwnerState("baseline", i, state), origins: [], sourceKeys: [], cells: [], nonces: i === 2 ? [nonce()] : [] }));
}
const query = () => ({ artistId, collectionId, bindingHash, policies: [], records: [bindingHash, artistId, id("acceptance")] });
function delegationData() {
  const data = baseData();
  data[0].typedState = h.encodeArtistHydrationOwnerState("delegation", 0, binding(artistId, bindingHash, 2n));
  data[2].typedState = h.encodeArtistHydrationOwnerState("delegation", 2, { baseline: h.encodeArtistHydrationIdentity(identity()), epoch: 0n, revisions: [], grants: [], delegateNonces: [] });
  data[6].typedState = h.encodeArtistHydrationOwnerState("delegation", 6, { policies: [], sales: [] }); return data;
}
function multiple() {
  const artistIds = [toBeHex(1, 32), toBeHex(2, 32)];
  const collections = [{ artistId: artistIds[1], collectionId: 1n, policies: [] }, { artistId: artistIds[0], collectionId: 2n, policies: [] }];
  const request = { kind: "multiple", request: { bindingIndex: 0n, artistIds, collections, expectedSource: headers(), replayOrigins: seven(() => []) } };
  const qs = collections.map((c, i) => ({ ...c, bindingHash: id(`multiple binding${i}`), records: [] }));
  const data = seven(i => {
    let typedState = "0x";
    if (i === 2) {
      typedState = h.encodeArtistHydrationMultipleBundle(i, { rows: artistIds.map(a => ({ query: { artistId: a, collectionId: 0n, bindingHash: ZeroHash, policies: [], records: [] },
        state: h.encodeArtistHydrationIdentity(identity(2n, 0)), nonces: [nonce()] })), artistIds, collectionIds: [1n, 2n], registrationCount: 2n });
    } else if (i !== 1 && i !== 5) {
      typedState = h.encodeArtistHydrationMultipleBundle(i, { rows: qs.map(q => ({ query: q, nonces: [], state: h.encodeArtistHydrationOwnerState("baseline", i,
        i === 0 ? binding(q.artistId, q.bindingHash) : i === 3 ? { record: id(`accept${q.collectionId}`), acceptedAt: 1n } : i === 4 ? { state: 2n, generation: 1n } : []) })),
        artistIds: [], collectionIds: [], registrationCount: 0n });
    }
    return { typedState, origins: [], sourceKeys: [], cells: [], nonces: [] };
  });
  return { request, query: qs[0], data };
}

test("three public original requests and capability IDs match exact compiler ABI", () => {
  const cases = [ [{ kind: "baseline", request: single() }, "hydrateArtistAuthority"],
    [{ kind: "delegation", request: single() }, "hydrateArtistAuthorityWithDelegations"], [multiple().request, "hydrateMultipleArtistAuthority"] ];
  for (const [input, method] of cases) {
    const call = h.prepareArtistAuthorityHydrationCall(coords.registry, actor, input);
    assert.equal(call.call.data, original.encodeFunctionData(method, [input.request])); assert.equal(call.call.value, 0n);
    assert.equal(call.call.to, coords.registry); assert.equal(call.caller, actor); assert.equal(call.factsVerified, false);
    assert.equal(call.capabilityId, original.getFunction(method).selector);
    assert.equal(call.profile, h.ARTIST_HYDRATION_PROFILES[input.kind]); assert.deepEqual(h.normalizeArtistAuthorityHydrationCall(call), call);
  }
  assert.throws(() => h.prepareArtistAuthorityHydrationCall(coords.registry, ZeroAddress, cases[0][0]), /nonzero/);
  for (const kind of ["multiple-delegation", "payout", "readiness", "entropyFindings"])
    assert.throws(() => h.normalizeArtistAuthorityHydrationRequest({ kind, request: single() }), /Unsupported/);
});

test("frozen requests preserve replay insertion and policy receipt order with profile-specific bounds", () => {
  const r = single(), a = { surface: id("a"), scope: ZeroHash }, b = { surface: id("b"), scope: id("scope") };
  r.expectedSource[0].replayCount = 2n; r.replayOrigins[0] = [b, a];
  r.policies = [{ phaseId: id("z"), policyHash: id("p1") }, { phaseId: id("a"), policyHash: id("p2") }];
  const normalized = h.normalizeArtistAuthorityHydrationRequest({ kind: "baseline", request: r });
  assert.deepEqual(normalized.request.replayOrigins[0], [b, a]); assert.deepEqual(normalized.request.policies, r.policies);
  r.policies[0].phaseId = ZeroHash; r.replayOrigins[0][0].surface = ZeroHash;
  assert.notEqual(normalized.request.policies[0].phaseId, ZeroHash); assert.notEqual(normalized.request.replayOrigins[0][0].surface, ZeroHash);
  assert.ok(Object.isFrozen(normalized.request.expectedSource[0].ownerState));
  const changed = single(); changed.expectedSource[2].nonceIndexCount = 2n;
  assert.throws(() => h.normalizeArtistAuthorityHydrationRequest({ kind: "baseline", request: changed }), /checkpoint/);
  assert.doesNotThrow(() => h.normalizeArtistAuthorityHydrationRequest({ kind: "delegation", request: changed }));
  changed.expectedSource[2].nonceIndexCount = 129n;
  assert.throws(() => h.normalizeArtistAuthorityHydrationRequest({ kind: "delegation", request: changed }), /checkpoint/);
  const duplicate = single(); duplicate.policies = [{ phaseId: id("phase"), policyHash: id("policy") }, { phaseId: id("phase"), policyHash: id("policy") }];
  assert.throws(() => h.normalizeArtistAuthorityHydrationRequest({ kind: "baseline", request: duplicate }), /Duplicate/);
});

test("multiple profile validates complete ordered selections and anchors to the first collection's Artist", () => {
  const m = multiple(), base = h.artistAuthorityHydrationBaseRequest(m.request);
  assert.notEqual(base.artistId, m.request.request.artistIds[0]); assert.equal(base.artistId, m.request.request.collections[0].artistId);
  assert.equal(base.collectionId, 1n); assert.equal(base.bindingIndex, 0n);
  assert.doesNotThrow(() => h.artistAuthorityHydrationCommitment(coords, m.request, m.query, m.data));
  for (const patch of [{ artistIds: [...m.request.request.artistIds].reverse() }, { artistIds: [m.request.request.artistIds[0]] },
    { collections: [...m.request.request.collections].reverse() }, { artistIds: [...m.request.request.artistIds, toBeHex(3, 32)] }])
    assert.throws(() => h.normalizeArtistAuthorityHydrationRequest({ kind: "multiple", request: { ...m.request.request, ...patch } }));
  const foreign = { ...m.request, request: { ...m.request.request, collections: m.request.request.collections.map((c, i) => ({ ...c, collectionId: c.collectionId + 10n })) } };
  assert.throws(() => h.artistAuthorityHydrationCommitment(coords, foreign, { ...m.query, collectionId: 11n }, m.data), /inventory/);
});

test("baseline typed owner codecs preserve historical bytes and reject advanced or noncanonical states", () => {
  const data = baseData();
  data.forEach((d, i) => assert.equal(h.encodeArtistHydrationOwnerState("baseline", i, h.decodeArtistHydrationOwnerState("baseline", i, d.typedState)), d.typedState));
  assert.equal(h.decodeArtistHydrationOwnerState("baseline", 2, data[2].typedState).estateActivity, identity().estateActivity);
  assert.throws(() => h.decodeArtistHydrationOwnerState("baseline", 2, `${data[2].typedState}00`), /Noncanonical/);
  assert.throws(() => h.encodeArtistHydrationOwnerState("baseline", 0, binding(artistId, bindingHash, 2n)), /PRIMARY_ONLY/);
  assert.throws(() => h.encodeArtistHydrationOwnerState("baseline", 2, { ...identity(), document: "0xff" }), /Identity/);
  assert.throws(() => h.encodeArtistHydrationOwnerState("baseline", 2, identity(2n)), /Identity/);
  assert.equal(h.decodeArtistHydrationIdentity(h.encodeArtistHydrationIdentity(identity(2n))).nextRegistrationNonce, 2n);
  assert.throws(() => h.decodeArtistHydrationOwnerState("baseline", 1, "0x00"), /empty/);
  assert.throws(() => h.encodeArtistHydrationOwnerState("baseline", 5, {}), /null/);
  assert.throws(() => h.encodeArtistHydrationOwnerState("baseline", 4, { state: 1n, generation: 1n }), /attribution/);
});

test("delegation tags and original nested field layouts match compiler codec witnesses", () => {
  const data = delegationData();
  for (const [i, method, tag] of [[0, "binding", "BINDING"], [2, "identity", "IDENTITY"], [6, "consent", "CONSENT"]]) {
    const value = h.decodeArtistHydrationOwnerState("delegation", i, data[i].typedState);
    const tuple = codec.getFunction(method).outputs[0];
    assert.equal(data[i].typedState, coder.encode(["bytes32", tuple], [id(`6529STREAM_ARTIST_LIVING_DELEGATION_${tag}_V1`), value]));
    assert.throws(() => h.decodeArtistHydrationOwnerState("delegation", i, `${id("wrong")}${data[i].typedState.slice(66)}`), /tag/);
  }
  const d = h.decodeArtistHydrationOwnerState("delegation", 2, data[2].typedState);
  assert.throws(() => h.encodeArtistHydrationOwnerState("delegation", 2, { ...d, epoch: 1n }), /epoch/);
  assert.doesNotThrow(() => h.artistAuthorityHydrationCommitment(coords, { kind: "delegation", request: single() }, query(), data));
});

test("historical revoked grants retain original terms, full uses and zero constraints without fresh liveness", () => {
  const data = delegationData(), d = h.decodeArtistHydrationOwnerState("delegation", 2, data[2].typedState);
  const row = { recordHash: id("grant"), item: { grant: { artistId, delegate: addr(20), collectionId: 0n, capabilities: 1143n,
    notBefore: 1n, expiresAt: 2n, maxUses: 0n, constraintsHash: ZeroHash }, grantor: addr(10), nonce: (1n << 180n) + 1n,
    uses: (1n << 90n) + 1n, revoked: true, revocationRecordHash: id("revocation") }, epoch: 0n, current: id("later-grant") };
  const state = { ...d, grants: [row] };
  assert.deepEqual(h.decodeArtistHydrationOwnerState("delegation", 2, h.encodeArtistHydrationOwnerState("delegation", 2, state)).grants[0], row);
  assert.throws(() => h.encodeArtistHydrationOwnerState("delegation", 2, { ...state, grants: [{ ...row, item: { ...row.item, grant: { ...row.item.grant, capabilities: 8n } } }] }), /grant/);
  assert.throws(() => h.encodeArtistHydrationOwnerState("delegation", 2, { ...state, grants: [{ ...row, epoch: 1n }] }), /grant/);
});

test("all original commitment coordinates, complete data and multiple anchor match independent ABI", () => {
  for (const [input, q, data] of [[{ kind: "baseline", request: single() }, query(), baseData()],
    [{ kind: "delegation", request: single() }, query(), delegationData()], (() => { const m = multiple(); return [m.request, m.query, m.data]; })()]) {
    const reqType = original.getFunction("hydrateArtistAuthority").inputs[0];
    const apply = new Interface(fixture.abis.hydrationOwner).getFunction("applyArtistAuthorityHydration");
    const ownerArray = `tuple(${apply.inputs[2].components.map(p => p.format("full")).join(",")})[7]`;
    const expected = hash(["bytes32", "uint256", "address", "address", "address", "address", reqType, apply.inputs[1], ownerArray],
      [h.ARTIST_HYDRATION_PROFILES[input.kind], coords.chainId, coords.registry, coords.coordinator, coords.predecessorRegistry, coords.sourceCoordinator,
        h.artistAuthorityHydrationBaseRequest(input), q, data]);
    assert.equal(h.artistAuthorityHydrationCommitment(coords, input, q, data), expected);
    assert.notEqual(h.artistAuthorityHydrationCommitment({ ...coords, coordinator: addr(55) }, input, q, data), expected);
    assert.notEqual(h.artistAuthorityHydrationCommitment({ ...coords, chainId: coords.chainId + 1n }, input, q, data), expected);
  }
});

test("replay delta rekeys destination cells but preserves the historical predecessor terminal latch", () => {
  const env = { chainId: coords.chainId, registry: coords.registry, coordinator: coords.coordinator, archive: addr(6), owner: addr(7), domain: id("domain:identity_authority") };
  const regular = { surface: id("ordinary guard"), scope: id("scope") }, terminal = { surface: id("identity_authority.replay.one_way_cutover_latch"), scope: ZeroHash };
  const cells = [{ commitment: id("record1"), touchedRevision: 1n, kind: 1n, status: 2n }, { commitment: id("record2"), touchedRevision: 2n, kind: 1n, status: 2n }];
  const data = { typedState: "0x", origins: [regular, terminal], sourceKeys: [id("source1"), id("source2")], cells, nonces: [] };
  const key = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), env.chainId, env.registry, env.coordinator, env.archive, env.owner, env.domain, regular.surface, regular.scope]);
  assert.equal(h.artistAuthorityHydrationReplayKey(env, regular), key);
  const first = hash(["bytes32", "bytes32", h.ARTIST_HYDRATION_REPLAY_CELL_TUPLE], [ZeroHash, key, cells[0]]);
  assert.equal(h.artistAuthorityHydrationReplayDelta(env, data), hash(["bytes32", "bytes32", h.ARTIST_HYDRATION_REPLAY_CELL_TUPLE], [first, data.sourceKeys[1], cells[1]]));
  assert.throws(() => h.artistAuthorityHydrationReplayDelta({ ...env, domain: id("other") }, data), /cutover/);
  assert.throws(() => h.normalizeArtistHydrationOwnerData({ ...data, sourceKeys: [id("same"), id("same")] }), /replay/);
  assert.throws(() => h.artistAuthorityHydrationReplayDelta(env, { ...data, origins: [regular, regular] }), /Duplicate/);
});

test("predicted owner accumulator uses zero-record hash, actor and exact next-state preimage", () => {
  const env = { chainId: coords.chainId, registry: coords.registry, coordinator: coords.coordinator, archive: addr(6), owner: addr(7), domain: id("owner0") };
  const before = snapshots()[0], data = baseData()[0], q = query(), value = id("commitment");
  const after = h.artistAuthorityHydrationOwnerAfter(env, before, actor, q, data, value);
  const expected = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"), env.chainId, env.registry, env.coordinator, env.archive, env.owner, env.domain,
      before.revision, before.revision + 1n, before.stateRoot, hash(["uint16", "address", "bytes32"], [60, actor, value]),
      hash([h.ARTIST_HYDRATION_QUERY_TUPLE, h.ARTIST_HYDRATION_OWNER_DATA_TUPLE, "bytes32"], [q, data, value]), ZeroHash, hash(["bytes32"], [ZeroHash])]);
  assert.equal(after.stateRoot, expected); assert.equal(after.recordChainTip, before.recordChainTip); assert.equal(after.revision, before.revision + 1n);
  assert.notEqual(h.artistAuthorityHydrationOwnerAfter(env, before, addr(44), q, data, value).stateRoot, after.stateRoot);
  assert.throws(() => h.artistAuthorityHydrationOwnerAfter(env, { ...before, revision: (1n << 64n) - 1n }, actor, q, data, value), /uint64/);
});

test("profile and eight-field Archive evidence roundtrip, and only evidence identity binds the actor", () => {
  const input = { kind: "baseline", request: single() }, q = query(), data = baseData();
  const commitment = h.artistAuthorityHydrationCommitment(coords, input, q, data);
  const p = { profile: h.ARTIST_HYDRATION_PROFILES.baseline, predecessorRegistry: coords.predecessorRegistry, sourceCoordinator: coords.sourceCoordinator,
    expectedSource: input.request.expectedSource, query: q, ownerData: data };
  const profileData = h.encodeArtistAuthorityHydrationProfileEvidence(p);
  assert.deepEqual(h.decodeArtistAuthorityHydrationProfileEvidence(profileData), p);
  const evidence = { schemaVersion: 1n, configurationHash: id("suite configuration"), operationId: 60n, actor, commitment, before: snapshots(), after: snapshots(), profileData };
  const encoded = h.encodeArtistAuthorityHydrationEvidence(evidence);
  assert.deepEqual(h.decodeArtistAuthorityHydrationEvidence(encoded), evidence);
  assert.equal(h.artistAuthorityHydrationEvidenceId(coords, actor, commitment), hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), coords.chainId, coords.registry, coords.coordinator, 60, actor, commitment]));
  assert.notEqual(h.artistAuthorityHydrationEvidenceId(coords, addr(99), commitment), h.artistAuthorityHydrationEvidenceId(coords, actor, commitment));
  assert.throws(() => h.decodeArtistAuthorityHydrationEvidence(`${encoded}00`), /Noncanonical/);
  const innerLength = BigInt((profileData.length - 2) / 2);
  assert.throws(() => h.encodeArtistAuthorityHydrationEvidence(evidence, innerLength), /complete|Complete/);
  assert.throws(() => h.encodeArtistAuthorityHydrationEvidence({ ...evidence, operationId: 56n }), /operation60/);
});

test("proofs are immutable exact-width tuples and calldata cannot be substituted after planning", () => {
  const input = { kind: "baseline", request: single() }, call = h.prepareArtistAuthorityHydrationCall(coords.registry, actor, input);
  input.request.expectedSource[0].ownerState.revision = 99n;
  assert.notEqual(call.input.request.expectedSource[0].ownerState.revision, 99n);
  assert.throws(() => h.normalizeArtistAuthorityHydrationCall({ ...call, call: { ...call.call, value: 1n } }), /differs/);
  assert.throws(() => h.normalizeArtistAuthorityHydrationCall({ ...call, factsVerified: true }), /differs/);
  assert.throws(() => h.normalizeArtistAuthorityHydrationRequest({ ...input, signature: "0x" }), /exact/);
  assert.throws(() => h.normalizeArtistAuthorityHydrationRequest({ kind: "baseline", request: { ...single(), bindingIndex: 0 } }), /bigint/);
  assert.throws(() => h.normalizeArtistHydrationNonceWord({ ...nonce(), words: new Array(32) }), /dense/);
  assert.throws(() => h.normalizeArtistHydrationNonceWord({ ...nonce(), words: [0n] }), /length/);
  assert.throws(() => h.normalizeArtistHydrationSnapshot({ ...snapshots()[0], revision: 1n << 64n }), /uint64/);
  assert.throws(() => h.normalizeArtistHydrationQuery({ ...query(), collectionId: 1n << 256n }), /uint256/);
  assert.throws(() => h.encodeArtistHydrationIdentity({ ...identity(), item: { ...identity().item, displayName: "\udfff" } }), /Unicode/);
  const empty = baseData(); empty[2].nonces = [];
  assert.throws(() => h.artistAuthorityHydrationCommitment(coords, { kind: "baseline", request: single() }, query(), empty), /Incomplete/);
});
