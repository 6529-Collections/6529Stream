import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as client from "../dist/current-artist-authority-hydration.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-multiple-delegation-abi.json", import.meta.url), "utf8"));
const previous = JSON.parse(readFileSync(new URL("./fixtures/current-artist-authority-hydration-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([name, entries]) => [name, new Interface(entries)]));
const coder = AbiCoder.defaultAbiCoder();
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const hash = (types, values) => keccak256(coder.encode(types, values));
const source = name => fixture.sourceTexts[`smart-contracts/domains/artist/${name}.sol`];
const profile = id("6529STREAM_ARTIST_MULTIPLE_LIVING_DELEGATION_V1");
const singleRequest = abi.artist.getFunction("hydrateArtistAuthority").inputs[0];
const multipleRequest = abi.artist.getFunction("hydrateMultipleArtistAuthority").inputs[0];
const checkpoint = abi.checkpoint.getFunction("authorityCheckpoint").outputs[0];
const snapshot = abi.owner.getFunction("ownerStateSnapshotV2").outputs[0];
const query = abi.hydrationOwner.getFunction("applyArtistAuthorityHydration").inputs[1];
const ownerData = abi.hydrationOwner.getFunction("applyArtistAuthorityHydration").inputs[2];
const delegationIdentity = abi.delegationCodec.getFunction("identity").outputs[0];
const array = (type, length = "") => ParamType.from({ type: `tuple[${length}]`, components: type.components });
// The nested AH.Identity remains internal, with its item witnessed by the public identity getter.
const identity = ParamType.from({ type: "tuple", components: [
  { type: "tuple", name: "item", components: abi.identity.getFunction("identity").outputs[0].components },
  { type: "bytes", name: "document" }, { type: "uint256", name: "nextRegistrationNonce" },
  { type: "uint256", name: "estateActivity" }, { type: "uint256", name: "dormancyActivity" },
  { type: "uint256", name: "findingActivity" }, { type: "bytes[]", name: "signatures" },
] });
const schemas = [
  [0, "bindings", "BINDINGS", "ARTIST_HYDRATION_MULTIPLE_DELEGATION_BINDINGS_TUPLE"],
  [2, "identity", "IDENTITIES", "ARTIST_HYDRATION_MULTIPLE_DELEGATION_IDENTITIES_TUPLE"],
  [3, "acceptances", "ACCEPTANCES", "ARTIST_HYDRATION_MULTIPLE_DELEGATION_ACCEPTANCES_TUPLE"],
  [4, "attributions", "ATTRIBUTIONS", "ARTIST_HYDRATION_MULTIPLE_DELEGATION_ATTRIBUTIONS_TUPLE"],
  [6, "consents", "CONSENTS", "ARTIST_HYDRATION_MULTIPLE_DELEGATION_CONSENTS_TUPLE"],
].map(([owner, method, tag, constant]) => ({ owner, method, constant,
  tag: id(`6529STREAM_ARTIST_MULTIPLE_DELEGATION_${tag}_V1`), type: abi.multipleDelegationCodec.getFunction(method).outputs[0] }));
const coordinates = { chainId: (1n << 210n) + 1n, registry: address(10), coordinator: address(11), predecessorRegistry: address(20), sourceCoordinator: address(21) };

// Structural ABI/hash oracle. Native admission, source-derived record identities and sparse
// nonce validity are independently checked by the original call in the workflow.
function sample(signature = "0x") {
  const artists = [id("Artist A"), id("Artist B")].sort((a, b) => BigInt(a) < BigInt(b) ? -1 : 1);
  const collections = [{ artistId: artists[1], collectionId: (1n << 170n) + 1n, policies: [] },
    { artistId: artists[0], collectionId: (1n << 170n) + 2n, policies: [] }];
  const expectedSource = Array.from({ length: 7 }, (_, i) => ({ schema: id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"),
    ownerState: { domainId: id(`domain ${i}`), revision: BigInt(i + 1), stateRoot: id(`state ${i}`), recordChainTip: id(`tip ${i}`) },
    replayRoot: ZeroHash, replayCount: 0n, nonceRoot: ZeroHash, nonceIndexCount: i === 2 ? 2n : 0n }));
  const request = { bindingIndex: 0n, artistIds: artists, collections, expectedSource, replayOrigins: Array.from({ length: 7 }, () => []) };
  const baseline = artists.map((_, a) => {
    const document = `0x01020${a + 1}`;
    return { item: { authorityAddress: address(100 + a), authorityClass: 1n, status: 1n, registeredAt: 10n,
      lastAuthorityActionAt: 20n, identityRecordHash: keccak256(document), identityRecordURI: "ipfs://source", displayName: `Artist ${a}`, nonceHint: 2n },
    document, nextRegistrationNonce: 2n, estateActivity: 0n, dormancyActivity: 0n, findingActivity: 0n,
    signatures: [signature, "0x", "0x"] };
  });
  const bindings = collections.map((c, i) => {
    const original = baseline[artists.indexOf(c.artistId)];
    return { collectionId: c.collectionId, state: { item: { artistId: c.artistId, artistAddress: original.item.authorityAddress,
      identityRecordHash: original.item.identityRecordHash, bindingHash: id(`binding ${i}`), generation: 1n,
      consentMode: i === 0 ? 2n : 1n, saleConsentScope: 0n, registryImmutabilityElection: 0n, proposer: address(50), accepted: true },
    terms: { collaboratorSetHash: ZeroHash, capabilityPolicySetHash: ZeroHash, mode: 0n, threshold: 0n, count: 0n } } };
  });
  const states = {
    0: bindings,
    2: { rows: artists.map((artistId, a) => {
      const c = collections.findIndex(c => c.artistId === artistId);
      return { artistId, records: [id(`binding ${c}`), artistId, id(`acceptance ${c}`)],
        state: coder.encode(["bytes32", delegationIdentity], [id("6529STREAM_ARTIST_LIVING_DELEGATION_IDENTITY_V1"),
          { baseline: coder.encode([identity], [baseline[a]]), epoch: 0n, revisions: [], grants: [], delegateNonces: [] }]),
        nonces: [{ prefix: 0n, words: [3n, ...Array(31).fill(0n)], exhausted: false }] };
    }), collectionIds: collections.map(c => c.collectionId) },
    3: bindings.map((b, i) => ({ bindingHash: b.state.item.bindingHash, state: { record: id(`acceptance ${i}`), acceptedAt: 21n } })),
    4: collections.map(c => ({ collectionId: c.collectionId, state: 2n, generation: 1n })),
    6: collections.map(c => ({ collectionId: c.collectionId, policies: [], state: { policies: [], sales: [] } })),
  };
  const rows = Array.from({ length: 7 }, () => ({ typedState: "0x", origins: [], sourceKeys: [], cells: [], nonces: [] }));
  for (const schema of schemas) rows[schema.owner].typedState = coder.encode(["bytes32", schema.type], [schema.tag, states[schema.owner]]);
  const base = { bindingIndex: 0n, artistId: collections[0].artistId, collectionId: collections[0].collectionId,
    expectedSource, replayOrigins: request.replayOrigins, policies: collections[0].policies };
  const q = { artistId: base.artistId, collectionId: base.collectionId, bindingHash: bindings[0].state.item.bindingHash, policies: [], records: [] };
  return { input: { kind: "multiple-delegation", request }, base, q, rows, states };
}
const commitment = (s, selected = profile) => hash(["bytes32", "uint256", "address", "address", "address", "address", singleRequest, query, array(ownerData, 7)],
  [selected, coordinates.chainId, coordinates.registry, coordinates.coordinator, coordinates.predecessorRegistry, coordinates.sourceCoordinator, s.base, s.q, s.rows]);

test("additive combined fixture retains exact ABI69 provenance and complete selected source closure", () => {
  assert.equal(fixture.sourceCommit, "1647c5c03113e2406d44793417608321f77b552a");
  assert.equal(fixture.inputSha256, "285d265b2623a08c99c4fb756486630d555bd7a36d7d07af2bad34ff65360765");
  assert.equal(fixture.outputSha256, "d38a56d0295ca9a9008d369eba986f46f3a960af03b4223e7bfeb4f6e5728677");
  assert.equal(fixture.sourceCount, 2328);
  assert.equal(Object.values(fixture.abis).reduce((n, rows) => n + rows.length, 0), 180);
  assert.equal(Object.keys(fixture.sourceHashes).length, 388);
  assert.equal(Object.keys(fixture.sourceTexts).length, 73);
  for (const [path, text] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(text).digest("hex"), fixture.sourceHashes[path], path);
  assert.match(fixture.sourceTexts["smart-contracts/interfaces/stream/artist/StreamArtistMultipleDelegationHydrationTypes.sol"], /struct Identities/);
  assert.match(fixture.qualification, /do not establish native/);
  assert.equal(previous.sourceCommit, "be359669d736843e7f0c8a85eed6f06ec9521464");
});

test("combined profile keeps the original multiple request and selector without a caller profile field", () => {
  const s = sample(), call = client.prepareArtistAuthorityHydrationCall(coordinates.registry, address(30), s.input);
  const prior = new Interface(previous.abis.artist).getFunction("hydrateMultipleArtistAuthority");
  assert.equal(multipleRequest.format("full"), prior.inputs[0].format("full"));
  assert.equal(call.call.data, abi.artist.encodeFunctionData("hydrateMultipleArtistAuthority", [s.input.request]));
  assert.equal(call.capabilityId, "0x4739d03d"); assert.equal(call.profile, profile); assert.equal(call.factsVerified, false);
  const old = client.prepareArtistAuthorityHydrationCall(coordinates.registry, address(30), { ...s.input, kind: "multiple" });
  assert.equal(old.call.data, call.call.data); assert.notEqual(old.profile, call.profile);
  assert.deepEqual(multipleRequest.components.map(c => c.name), ["bindingIndex", "artistIds", "collections", "expectedSource", "replayOrigins"]);
});

test("all five compact owner schemas match compiler outputs and retain closed original tags", () => {
  const s = sample();
  for (const schema of schemas) {
    assert.equal(ParamType.from(client[schema.constant]).format("sighash"), schema.type.format("sighash"));
    assert.equal(client.encodeArtistHydrationOwnerState("multiple-delegation", schema.owner, s.states[schema.owner]), s.rows[schema.owner].typedState);
    assert.deepEqual(client.decodeArtistHydrationOwnerState("multiple-delegation", schema.owner, s.rows[schema.owner].typedState), s.states[schema.owner]);
    const wrong = coder.encode(["bytes32", schema.type], [id("6529STREAM_ARTIST_MULTIPLE_LIVING_STATE_V1"), s.states[schema.owner]]);
    assert.throws(() => client.decodeArtistHydrationOwnerState("multiple-delegation", schema.owner, wrong), /tag/);
    assert.throws(() => client.decodeArtistHydrationOwnerState("multiple-delegation", schema.owner, `${s.rows[schema.owner].typedState}00`), /canonical|length/);
  }
  assert.equal(client.encodeArtistHydrationOwnerState("multiple-delegation", 1, null), "0x");
  assert.equal(client.encodeArtistHydrationOwnerState("multiple-delegation", 5, null), "0x");
  assert.throws(() => client.decodeArtistHydrationOwnerState("multiple-delegation", 1, "0x00"));
  assert.throws(() => client.decodeArtistHydrationOwnerState("multiple-delegation", 5, "0x00"));
});

test("nested delegation Identity preserves the full registration allocator and original DH tag", () => {
  const s = sample(), raw = s.states[2].rows[0].state;
  const decoded = client.decodeArtistHydrationDelegationIdentity(raw);
  assert.equal(client.decodeArtistHydrationIdentity(decoded.baseline).nextRegistrationNonce, 2n);
  assert.equal(client.encodeArtistHydrationDelegationIdentity(decoded), raw);
  assert.throws(() => client.decodeArtistHydrationOwnerState("delegation", 2, raw), /Identity/);
  assert.throws(() => client.decodeArtistHydrationDelegationIdentity(`${raw}00`), /canonical|length/);
  assert.throws(() => client.decodeArtistHydrationDelegationIdentity(coder.encode(["bytes32", delegationIdentity], [profile, decoded])), /tag/);
});

test("combined commitment binds the complete compact inventory through the original first-collection anchor", () => {
  const s = sample(), expected = commitment(s);
  assert.notEqual(s.base.artistId, s.input.request.artistIds[0]);
  assert.deepEqual(client.artistAuthorityHydrationBaseRequest(s.input), s.base);
  assert.equal(client.artistAuthorityHydrationCommitment(coordinates, s.input, s.q, s.rows), expected);
  assert.notEqual(expected, commitment(s, id("6529STREAM_ARTIST_MULTIPLE_LIVING_HYDRATION_V1")));
  const wrong = hash(["bytes32", "uint256", "address", "address", "address", "address", multipleRequest, query, array(ownerData, 7)],
    [profile, coordinates.chainId, coordinates.registry, coordinates.coordinator, coordinates.predecessorRegistry, coordinates.sourceCoordinator, s.input.request, s.q, s.rows]);
  assert.notEqual(expected, wrong);
  const changed = sample("0x1234");
  assert.notEqual(client.artistAuthorityHydrationCommitment(coordinates, changed.input, changed.q, changed.rows), expected);
  assert.throws(() => client.artistAuthorityHydrationCommitment(coordinates, s.input, { ...s.q, artistId: s.input.request.artistIds[0] }, s.rows));
});

test("combined Archive uses the original eight-field envelope and refuses a larger carrier", () => {
  const s = sample(), actor = address(30), value = commitment(s);
  const inner = { profile, predecessorRegistry: coordinates.predecessorRegistry, sourceCoordinator: coordinates.sourceCoordinator,
    expectedSource: s.base.expectedSource, query: s.q, ownerData: s.rows };
  const profileData = coder.encode(["bytes32", "address", "address", array(checkpoint, 7), query, array(ownerData, 7)],
    [profile, coordinates.predecessorRegistry, coordinates.sourceCoordinator, s.base.expectedSource, s.q, s.rows]);
  assert.equal(client.encodeArtistAuthorityHydrationProfileEvidence(inner), profileData);
  const before = s.base.expectedSource.map(h => h.ownerState), after = before.map(b => ({ ...b, revision: b.revision + 1n, stateRoot: id(`after ${b.domainId}`) }));
  const envelope = { schemaVersion: 1n, configurationHash: id("configuration"), operationId: 60n, actor, commitment: value, before, after, profileData };
  const expected = coder.encode(["uint16", "bytes32", "uint16", "address", "bytes32", array(snapshot, 7), array(snapshot, 7), "bytes"],
    [1n, envelope.configurationHash, 60n, actor, value, before, after, profileData]);
  assert.equal(client.encodeArtistAuthorityHydrationEvidence(envelope), expected);
  assert.deepEqual(client.decodeArtistAuthorityHydrationEvidence(expected), envelope);
  assert.throws(() => client.encodeArtistAuthorityHydrationEvidence(envelope, 24576n), /carrier/);
  const huge = sample(`0x${"ab".repeat(10000)}`);
  const hugeProfile = client.encodeArtistAuthorityHydrationProfileEvidence({ ...inner, ownerData: huge.rows });
  assert.throws(() => client.encodeArtistAuthorityHydrationEvidence({ ...envelope, profileData: hugeProfile }), /carrier/);
});

test("source-selected combined import preserves original events and exact historical boundaries", () => {
  const selection = source("StreamArtistMultipleDelegationSelection");
  assert.match(selection, /op == 25 \|\| op == 26 \|\| op == 27/);
  assert.match(selection, /artistNativeReceiptAt\(i\)\.operation == 16/);
  assert.match(selection, /binding\(r\.collectionId\)\.consentMode == 2/);
  assert.match(source("StreamArtistMultipleHydrationOperations"), /if \(StreamArtistMultipleDelegationSelection\.required\(source\)\)/);
  assert.match(source("StreamArtistMultipleDelegationSource"), /h\.q = inv\.collections\[0\]/);
  assert.match(source("StreamArtistMultipleDelegationFacts"), /uses\[a\]\[g\] != state\.grants\[g\]\.item\.uses/);
  assert.match(source("StreamArtistMultipleDelegationFacts"), /row\.artistId, delegate/);
  assert.equal(abi.multipleDelegationSelection.getEvent("MultipleArtistAuthorityHydrated").format("full"), abi.multipleEvents.getEvent("MultipleArtistAuthorityHydrated").format("full"));
  assert.match(source("StreamArtistHydrationCommit"), /if \(!added \|\| hash != keccak256\(evidence\)\) revert T.InvalidRecord\(\)/);
});
