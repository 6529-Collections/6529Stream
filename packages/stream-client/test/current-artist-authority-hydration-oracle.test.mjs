import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as client from "../dist/current-artist-authority-hydration.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-authority-hydration-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, value]) => [key, new Interface(value)]));
const coder = AbiCoder.defaultAbiCoder(), address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const hash = (types, values) => keccak256(coder.encode(types, values));
const source = name => fixture.sourceTexts[`smart-contracts/domains/artist/${name}.sol`];
const requestType = abi.artist.getFunction("hydrateArtistAuthority").inputs[0];
const multipleRequestType = abi.artist.getFunction("hydrateMultipleArtistAuthority").inputs[0];
const checkpointType = abi.checkpoint.getFunction("authorityCheckpoint").outputs[0];
const snapshotType = abi.owner.getFunction("ownerStateSnapshotV2").outputs[0];
const queryType = abi.hydrationOwner.getFunction("applyArtistAuthorityHydration").inputs[1];
const ownerDataType = abi.hydrationOwner.getFunction("applyArtistAuthorityHydration").inputs[2];
const cellType = abi.owner.getFunction("replayCell").outputs[0];
const bindingType = abi.delegationCodec.getFunction("binding").outputs[0];
const delegationIdentityType = abi.delegationCodec.getFunction("identity").outputs[0];
const delegationConsentType = abi.delegationCodec.getFunction("consent").outputs[0];
const nonceWordType = ownerDataType.components.at(-1).arrayChildren;
// Internal AH.Identity and MH.Bundle are source-derived; their nested public types have ABI witnesses.
const identityType = ParamType.from({ type: "tuple", components: [
  { type: "tuple", name: "item", components: abi.identity.getFunction("identity").outputs[0].components },
  { type: "bytes", name: "document" }, { type: "uint256", name: "nextRegistrationNonce" },
  { type: "uint256", name: "estateActivity" }, { type: "uint256", name: "dormancyActivity" },
  { type: "uint256", name: "findingActivity" }, { type: "bytes[]", name: "signatures" },
] });
const bundleType = ParamType.from({ type: "tuple", components: [
  { type: "tuple[]", name: "rows", components: [
    { type: "tuple", name: "query", components: queryType.components }, { type: "bytes", name: "state" },
    { type: "tuple[]", name: "nonces", components: nonceWordType.components },
  ] }, { type: "bytes32[]", name: "artistIds" }, { type: "uint256[]", name: "collectionIds" }, { type: "uint256", name: "registrationCount" },
] });
const tupleArray = (type, length = "") => ParamType.from({ type: `tuple[${length}]`, components: type.components });
const profiles = {
  baseline: ["hydrateArtistAuthority", "0x1f51c336", id("6529STREAM_ARTIST_LIVING_BASELINE_HYDRATION_V1")],
  multiple: ["hydrateMultipleArtistAuthority", "0x4739d03d", id("6529STREAM_ARTIST_MULTIPLE_LIVING_HYDRATION_V1")],
  delegation: ["hydrateArtistAuthorityWithDelegations", "0xe17666b4", id("6529STREAM_ARTIST_LIVING_DELEGATION_HYDRATION_V1")],
};
const chainId = (1n << 230n) + 31337n;
const coordinates = { chainId, registry: address(10), coordinator: address(11), predecessorRegistry: address(20), sourceCoordinator: address(21) };
function checkpoint(i) {
  return { schema: id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"),
    ownerState: { domainId: id(`domain ${i}`), revision: BigInt(i + 1), stateRoot: id(`source state ${i}`), recordChainTip: id(`source record ${i}`) },
    replayRoot: ZeroHash, replayCount: 0n, nonceRoot: ZeroHash, nonceIndexCount: 0n };
}
function request() {
  return { bindingIndex: 0n, artistId: id("original artist"), collectionId: (1n << 190n) + 99n,
    expectedSource: Array.from({ length: 7 }, (_, i) => checkpoint(i)), replayOrigins: Array.from({ length: 7 }, () => []),
    policies: [{ phaseId: id("phase"), policyHash: id("policy") }] };
}
function identity(registrations = 1n, signatures = ["0x1234", "0xabcd", "0x3344", "0x5566"]) {
  const document = "0x1020304050";
  return { item: { authorityAddress: address(30), authorityClass: 1n, status: 1n, registeredAt: 12n,
    lastAuthorityActionAt: 19n, identityRecordHash: keccak256(document), identityRecordURI: "ipfs://identity/é", displayName: "Original Artist",
    nonceHint: (1n << 200n) + 9n }, document, nextRegistrationNonce: registrations, estateActivity: 2n,
    dormancyActivity: 3n, findingActivity: 4n, signatures };
}
function binding(p = request(), delegated = false) {
  return { item: { artistId: p.artistId, artistAddress: address(30), identityRecordHash: identity().item.identityRecordHash,
    bindingHash: id("binding"), generation: 1n, consentMode: delegated ? 2n : 1n, saleConsentScope: 0n,
    registryImmutabilityElection: 0n, proposer: address(40), accepted: true },
  terms: { collaboratorSetHash: id("empty collaborators"), capabilityPolicySetHash: id("empty policies"), mode: 0n, threshold: 0n, count: 0n } };
}
function data(kind = "baseline", p = request()) {
  const rows = Array.from({ length: 7 }, () => ({ typedState: "0x", origins: [], sourceKeys: [], cells: [], nonces: [] }));
  rows[0].typedState = kind === "delegation"
    ? coder.encode(["bytes32", bindingType], [id("6529STREAM_ARTIST_LIVING_DELEGATION_BINDING_V1"), binding(p, true)])
    : coder.encode([bindingType], [binding(p)]);
  const rawIdentity = coder.encode([identityType], [identity()]);
  rows[2].typedState = kind === "delegation" ? coder.encode(["bytes32", delegationIdentityType],
    [id("6529STREAM_ARTIST_LIVING_DELEGATION_IDENTITY_V1"), { baseline: rawIdentity, epoch: 0n, revisions: [], grants: [], delegateNonces: [] }]) : rawIdentity;
  rows[2].nonces = [{ prefix: (1n << 200n) + 8n, words: Array.from({ length: 32 }, (_, i) => 1n << BigInt(i + 100)), exhausted: false }];
  rows[3].typedState = coder.encode(["tuple(bytes32 record,uint64 acceptedAt)"], [{ record: id("acceptance"), acceptedAt: 21n }]);
  rows[4].typedState = coder.encode(["uint8", "uint64"], [2n, 1n]);
  rows[6].typedState = kind === "delegation" ? coder.encode(["bytes32", delegationConsentType],
    [id("6529STREAM_ARTIST_LIVING_DELEGATION_CONSENT_V1"), { policies: [{ recordHash: id("policy record"), grant: ZeroHash }], sales: [] }])
    : coder.encode(["bytes32[]"], [[id("policy record")]]);
  return rows;
}
function query(p = request()) {
  return { artistId: p.artistId, collectionId: p.collectionId, bindingHash: id("binding"), policies: p.policies, records: [id("binding"), p.artistId, id("acceptance"), id("policy record")] };
}
function originalCommitment(profile, p, q, rows, c = coordinates) {
  return hash(["bytes32", "uint256", "address", "address", "address", "address", requestType, queryType, tupleArray(ownerDataType, 7)],
    [profile, c.chainId, c.registry, c.coordinator, c.predecessorRegistry, c.sourceCoordinator, p, q, rows]);
}
function profileBytes(profile, p, q, rows, c = coordinates) {
  return coder.encode(["bytes32", "address", "address", tupleArray(checkpointType, 7), queryType, tupleArray(ownerDataType, 7)],
    [profile, c.predecessorRegistry, c.sourceCoordinator, p.expectedSource, q, rows]);
}
function evidenceId(actor, commitment, c = coordinates) {
  return hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), c.chainId, c.registry, c.coordinator, 60n, actor, commitment]);
}
function replayKey(e, origin) {
  return hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), e.chainId, e.registry, e.coordinator, e.archive, e.owner, e.domain, origin.surface, origin.scope]);
}
function afterOwner(e, actor, before, q, row, commitment) {
  let delta = ZeroHash;
  for (let j = 0; j < row.origins.length; j++) {
    const key = row.origins[j].surface === id("identity_authority.replay.one_way_cutover_latch") ? row.sourceKeys[j] : replayKey(e, row.origins[j]);
    delta = hash(["bytes32", "bytes32", cellType], [delta, key, row.cells[j]]);
  }
  const nextState = hash([queryType, ownerDataType, "bytes32"], [q, row, commitment]);
  const root = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"), e.chainId, e.registry, e.coordinator, e.archive, e.owner, e.domain,
      before.revision, before.revision + 1n, before.stateRoot, hash(["uint16", "address", "bytes32"], [60n, actor, commitment]),
      nextState, delta, hash(["bytes32"], [ZeroHash])]);
  return { ...before, revision: before.revision + 1n, stateRoot: root };
}

test("Artist hydration fixture retains exact ABI67 provenance, all original tuple witnesses and source recipes", () => {
  assert.equal(fixture.sourceCommit, "be359669d736843e7f0c8a85eed6f06ec9521464");
  assert.equal(fixture.sourceCount, 2311);
  assert.equal(fixture.inputSha256, "dce7907bcef7668ae76048242727032374edd6a618d0e0070f6e84aeec27046f");
  assert.equal(fixture.outputSha256, "d7dae97ec114efc0bdd76084f69f5601e04db5a108faa3be235dbb665f9eaf2e");
  assert.equal(Object.values(fixture.abis).flat().length, 172);
  assert.equal(Object.keys(fixture.sourceHashes).length, 376);
  assert.equal(Object.keys(fixture.sourceTexts).length, 66);
  for (const [path, text] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(text).digest("hex"), fixture.sourceHashes[path]);
  assert.match(fixture.qualification, /do not establish native/);
  assert.match(source("StreamArtistOwnerCommit"), /keccak256\(abi\.encode\(record\)\)/);
  assert.match(source("StreamArtistHydrationCommit"), /uint16\(1\), x\.configurationHash, uint16\(60\), actor, value, before_, after_, profileBytes/);
});

test("three distinct capabilities retain original request widths and permissionless zero-value call ABI", () => {
  const interfaces = [abi.hydrationInterface, abi.multipleInterface, abi.delegationInterface];
  Object.entries(profiles).forEach(([profile, [method, selector]], i) => {
    const f = abi.artist.getFunction(method), own = interfaces[i].fragments.filter(x => x.type === "function" && x.name !== "supportsInterface");
    assert.equal(own.length, 1); assert.equal(own[0].selector, selector); assert.equal(f.selector, selector);
    assert.equal(f.stateMutability, "nonpayable"); assert.equal(f.outputs[0].type, "bytes32");
    assert.equal(f.inputs.length, 1);
    if (profile !== "multiple") assert.equal(f.inputs[0].format("sighash"), requestType.format("sighash"));
  });
  assert.deepEqual(requestType.components.map(x => x.name), ["bindingIndex", "artistId", "collectionId", "expectedSource", "replayOrigins", "policies"]);
  assert.deepEqual(multipleRequestType.components.map(x => x.name), ["bindingIndex", "artistIds", "collections", "expectedSource", "replayOrigins"]);
  assert.equal(requestType.components[3].arrayLength, 7);
  assert.equal(requestType.components[4].arrayLength, 7);
  assert.equal(abi.checkpoint.getFunction("authorityNonceWordAt").outputs[1].arrayLength, 32);
  assert.equal(ownerDataType.components.at(-1).arrayChildren.components[1].arrayLength, 32);
});

test("client tuple constants match compiler witnesses and source-derived internal envelopes", () => {
  for (const [constant, compiled] of [
    [client.ARTIST_HYDRATION_SINGLE_REQUEST_TUPLE, requestType], [client.ARTIST_HYDRATION_MULTIPLE_REQUEST_TUPLE, multipleRequestType],
    [client.ARTIST_HYDRATION_CHECKPOINT_TUPLE, checkpointType], [client.ARTIST_HYDRATION_SNAPSHOT_TUPLE, snapshotType],
    [client.ARTIST_HYDRATION_QUERY_TUPLE, queryType], [client.ARTIST_HYDRATION_OWNER_DATA_TUPLE, ownerDataType],
    [client.ARTIST_HYDRATION_BINDING_TUPLE, bindingType], [client.ARTIST_HYDRATION_DELEGATION_IDENTITY_TUPLE, delegationIdentityType],
    [client.ARTIST_HYDRATION_DELEGATION_CONSENT_TUPLE, delegationConsentType], [client.ARTIST_HYDRATION_IDENTITY_TUPLE, identityType],
    [client.ARTIST_HYDRATION_MULTIPLE_BUNDLE_TUPLE, bundleType],
  ]) assert.equal(ParamType.from(constant).format("sighash"), compiled.format("sighash"));
  for (const [kind, [method, selector, profile]] of Object.entries(profiles)) {
    assert.equal(client.ARTIST_HYDRATION_CAPABILITY_IDS[kind], selector);
    assert.equal(client.ARTIST_HYDRATION_PROFILES[kind], profile);
    assert.equal(new Interface(client.CURRENT_ARTIST_AUTHORITY_HYDRATION_ABI).getFunction(method).format("sighash"), abi.artist.getFunction(method).format("sighash"));
  }
  const ah = fixture.sourceTexts["smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol"];
  const mh = fixture.sourceTexts["smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol"];
  assert.match(ah, /struct Identity\s*\{\s*StreamArtistOnboardingTypes.Identity item;\s*bytes document;\s*uint256 nextRegistrationNonce;\s*uint256 estateActivity;\s*uint256 dormancyActivity;\s*uint256 findingActivity;\s*bytes\[\] signatures;/);
  assert.match(mh, /struct Bundle\s*\{\s*Row\[\] rows;\s*bytes32\[\] artistIds;\s*uint256\[\] collectionIds;\s*uint256 registrationCount;/);
});

test("baseline and delegation use identical original request tuple but distinct calls, tags and commitments", () => {
  const p = request(), q = query(p), actor = address(31), commitments = [];
  for (const kind of ["baseline", "delegation"]) {
    const input = { kind, request: p }, rows = data(kind, p), [method, selector, profile] = profiles[kind];
    const prepared = client.prepareArtistAuthorityHydrationCall(coordinates.registry, actor, input);
    assert.deepEqual(prepared.call, { to: coordinates.registry, data: abi.artist.encodeFunctionData(method, [p]), value: 0n });
    assert.equal(prepared.capabilityId, selector); assert.equal(prepared.profile, profile); assert.equal(prepared.factsVerified, false);
    const expected = originalCommitment(profile, p, q, rows);
    assert.equal(client.artistAuthorityHydrationCommitment(coordinates, input, q, rows), expected);
    commitments.push(expected);
    for (let i = 0; i < 7; i++) {
      const state = client.decodeArtistHydrationOwnerState(kind, i, rows[i].typedState);
      assert.equal(client.encodeArtistHydrationOwnerState(kind, i, state), rows[i].typedState);
    }
    for (const field of ["chainId", "registry", "coordinator", "predecessorRegistry", "sourceCoordinator"]) {
      const changed = { ...coordinates, [field]: field === "chainId" ? chainId + 1n : address(199) };
      assert.equal(client.artistAuthorityHydrationCommitment(changed, input, q, rows), originalCommitment(profile, p, q, rows, changed));
      assert.notEqual(client.artistAuthorityHydrationCommitment(changed, input, q, rows), expected);
    }
    assert.equal(client.artistAuthorityHydrationEvidenceId(coordinates, actor, expected), evidenceId(actor, expected));
    assert.notEqual(client.artistAuthorityHydrationEvidenceId(coordinates, address(32), expected), evidenceId(actor, expected));
  }
  assert.notEqual(...commitments);
});

function multiple() {
  const p = request(), ids = ["0x" + "01".padStart(64, "0"), "0x" + "02".padStart(64, "0")];
  const m = { bindingIndex: 0n, artistIds: ids, collections: [
    { artistId: ids[1], collectionId: p.collectionId, policies: p.policies },
    { artistId: ids[0], collectionId: p.collectionId + 1n, policies: [] },
  ], expectedSource: p.expectedSource, replayOrigins: p.replayOrigins };
  const base = { ...p, artistId: ids[1] }, q = { ...query(base), records: [] }, rows = data();
  rows[2].nonces = [];
  for (const owner of [0, 2, 3, 4, 6]) {
    let bundle;
    if (owner === 2) {
      bundle = { artistIds: ids, collectionIds: m.collections.map(x => x.collectionId), registrationCount: 2n,
        rows: ids.map(artistId => ({ query: { artistId, collectionId: 0n, bindingHash: ZeroHash, policies: [], records: [artistId] },
          state: coder.encode([identityType], [identity(2n, ["0x1234"])]),
          nonces: [{ prefix: (1n << 200n) + 8n, words: Array.from({ length: 32 }, (_, i) => 1n << BigInt(i + 100)), exhausted: false }] })) };
    } else {
      bundle = { artistIds: [], collectionIds: [], registrationCount: 0n, rows: m.collections.map(c => {
        const selected = { ...p, ...c }, rowQuery = { ...query(selected), policies: owner === 6 ? c.policies : [], records: [] };
        const all = data("baseline", selected);
        if (owner === 6) all[6].typedState = coder.encode(["bytes32[]"], [c.policies.map(() => id("policy record"))]);
        return { query: rowQuery, state: all[owner].typedState, nonces: [] };
      }) };
    }
    rows[owner].typedState = coder.encode(["bytes32", bundleType], [id("6529STREAM_ARTIST_MULTIPLE_LIVING_STATE_V1"), bundle]);
  }
  return { input: { kind: "multiple", request: m }, base, q, rows };
}

test("multiple profile hashes the first collection anchor and every tagged row, not the public request", () => {
  const { input, base, q, rows } = multiple(), profile = profiles.multiple[2];
  assert.notEqual(base.artistId, input.request.artistIds[0]);
  assert.deepEqual(client.artistAuthorityHydrationBaseRequest(input), base);
  const prepared = client.prepareArtistAuthorityHydrationCall(coordinates.registry, address(31), input);
  assert.equal(prepared.call.data, abi.artist.encodeFunctionData("hydrateMultipleArtistAuthority", [input.request]));
  const expected = originalCommitment(profile, base, q, rows);
  assert.equal(client.artistAuthorityHydrationCommitment(coordinates, input, q, rows), expected);
  const wrong = hash(["bytes32", "uint256", "address", "address", "address", "address", multipleRequestType, queryType, tupleArray(ownerDataType, 7)],
    [profile, chainId, coordinates.registry, coordinates.coordinator, coordinates.predecessorRegistry, coordinates.sourceCoordinator, input.request, q, rows]);
  assert.notEqual(expected, wrong);
  for (const owner of [0, 2, 3, 4, 6]) {
    const bundle = client.decodeArtistHydrationMultipleBundle(owner, rows[owner].typedState);
    assert.equal(client.encodeArtistHydrationMultipleBundle(owner, bundle), rows[owner].typedState);
  }
  assert.throws(() => client.artistAuthorityHydrationCommitment(coordinates, input, { ...q, artistId: input.request.artistIds[0] }, rows));
});

test("each original owner root binds actor, source bytes and replay rekeying while preserving record tip", () => {
  const p = request(), q = query(p), rows = data(), actor = address(31), commitment = originalCommitment(profiles.baseline[2], p, q, rows);
  for (let i = 0; i < 7; i++) {
    const domain = i === 2 ? id("domain:identity_authority") : id(`domain ${i}`);
    const env = { chainId, registry: coordinates.registry, coordinator: coordinates.coordinator, archive: address(50), owner: address(60 + i), domain };
    const before = { domainId: domain, revision: (1n << 63n) + BigInt(i), stateRoot: id(`before ${i}`), recordChainTip: id(`tip ${i}`) };
    const row = rows[i], origin = { surface: id(`guard ${i}`), scope: id(`scope ${i}`) };
    row.origins.push(origin); row.sourceKeys.push(id(`source key ${i}`));
    row.cells.push({ commitment: id(`original commitment ${i}`), touchedRevision: (1n << 63n) + 99n, kind: 1n, status: 2n });
    if (i === 2) {
      row.origins.push({ surface: id("identity_authority.replay.one_way_cutover_latch"), scope: ZeroHash });
      row.sourceKeys.push(id("original terminal latch")); row.cells.push({ commitment: id("cutover"), touchedRevision: 13n, kind: 1n, status: 2n });
    }
    const after = client.artistAuthorityHydrationOwnerAfter(env, before, actor, q, row, commitment);
    assert.deepEqual(after, afterOwner(env, actor, before, q, row, commitment));
    assert.equal(after.recordChainTip, before.recordChainTip); assert.equal(after.revision, before.revision + 1n);
    assert.equal(client.artistAuthorityHydrationReplayKey(env, origin), replayKey(env, origin));
    assert.notEqual(after.stateRoot, client.artistAuthorityHydrationOwnerAfter(env, before, address(32), q, row, commitment).stateRoot);
    if (i === 2) {
      const wrongDomain = { ...env, domain: id("domain:binding_lifecycle") };
      assert.throws(() => client.artistAuthorityHydrationReplayDelta(wrongDomain, row), /latch/);
    }
  }
});

test("original eight-field Archive envelope retains full profile bytes and exact seven-owner evidence", () => {
  for (const kind of ["baseline", "multiple", "delegation"]) {
    const multi = kind === "multiple" ? multiple() : null;
    const p = multi?.base ?? request(), q = multi?.q ?? query(p), rows = multi?.rows ?? data(kind, p), profile = profiles[kind][2];
    const commitment = originalCommitment(profile, p, q, rows), actor = address(31);
    const inner = { profile, predecessorRegistry: coordinates.predecessorRegistry, sourceCoordinator: coordinates.sourceCoordinator,
      expectedSource: p.expectedSource, query: q, ownerData: rows };
    const profileData = profileBytes(profile, p, q, rows);
    assert.equal(client.encodeArtistAuthorityHydrationProfileEvidence(inner), profileData);
    assert.deepEqual(client.decodeArtistAuthorityHydrationProfileEvidence(profileData), inner);
    const before = p.expectedSource.map(h => h.ownerState);
    const after = before.map((b, i) => afterOwner({ chainId, registry: coordinates.registry, coordinator: coordinates.coordinator, archive: address(50), owner: address(60 + i), domain: b.domainId }, actor, b, q, rows[i], commitment));
    const envelope = { schemaVersion: 1n, configurationHash: id("suite configuration"), operationId: 60n, actor, commitment, before, after, profileData };
    const expected = coder.encode(["uint16", "bytes32", "uint16", "address", "bytes32", tupleArray(snapshotType, 7), tupleArray(snapshotType, 7), "bytes"],
      [1n, envelope.configurationHash, 60n, actor, commitment, before, after, profileData]);
    assert.equal(client.encodeArtistAuthorityHydrationEvidence(envelope), expected);
    assert.deepEqual(client.decodeArtistAuthorityHydrationEvidence(expected), envelope);
    assert.throws(() => client.decodeArtistAuthorityHydrationEvidence(`${expected}${"00".repeat(32)}`), /canonical/);
    assert.throws(() => client.encodeArtistAuthorityHydrationEvidence(envelope, BigInt((expected.length - 2) / 2 - 1)), /carrier/);
    assert.throws(() => client.encodeArtistAuthorityHydrationEvidence({ ...envelope, operationId: 56n }));
  }
});

test("original events identify first collection and atomic Archive append without replacing evidence", () => {
  const anchor = abi.hydrationEvents.getEvent("ArtistAuthorityHydrated"), multi = abi.multipleEvents.getEvent("MultipleArtistAuthorityHydrated");
  assert.deepEqual(anchor.inputs.map(x => [x.type, x.indexed === true]), [["uint16", false], ["bytes32", true], ["uint256", true], ["address", true], ["bytes32", false], ["bytes32", false]]);
  assert.deepEqual(multi.inputs.map(x => x.name), ["predecessor", "commitment", "artistIds", "collectionIds"]);
  const archiveEvent = abi.archive.getEvent("ArtistArchiveEvidenceAppendedV2");
  assert.deepEqual(archiveEvent.inputs.map(x => x.name), ["evidenceId", "evidenceVersion", "contentHash", "pointer", "payloadSize"]);
  assert.match(source("StreamArtistHydrationCommit"), /if \(!added \|\| hash != keccak256\(evidence\)\) revert T.InvalidRecord\(\)/);
  assert.match(source("StreamArtistMultipleHydrationOperations"), /h\.q = inv\.collections\[0\]/);
  assert.match(source("StreamArtistMultipleHydrationOperations"), /base\.artistId = h\.q\.artistId/);
  assert.match(source("StreamArtistHydrationGuards"), /state\(\)\.sourceCells\[p\.sourceKeys\[j\]\] = p\.cells\[j\]/);
});
