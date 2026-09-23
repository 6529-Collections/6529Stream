import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as root from "../dist/current-scoped-policy-root-v2.js";
import * as pub from "../dist/current-scoped-policy-publication-v2.js";
import * as graph from "../dist/current-scoped-policy-graph-v2.js";
import { compiledInterfaces as abi } from "./current-scoped-policy-root-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const h = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
const coordinates = { chainId: (1n << 200n) + 1n, core: address(1), router: address(2), artistRegistry: address(3) };
const scope = { scopeType: 1n, collectionId: (1n << 200n) + 2n, tokenId: (1n << 240n) + 3n, scopeId: ZeroHash };
const publication = { scope, expectedPredecessor: ZeroHash, snapshotRecordHash: h(31), snapshotRevision: 1n, manifestURI: "ipfs://root/作品" };
const aggregate = { revision: 1n, transitionChain: h(44) };
const publicationType = abi.router.getFunction("publishScopedPolicyContentRootPublication").inputs[0];
const recordType = abi.router.getFunction("scopedContentRootRecord").outputs[0];
const bindingType = abi.router.getFunction("scopedPolicyContentRootBinding").outputs[0];

function zero(type) {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(t => [t.name, zero(t)]));
  if (type.baseType === "array") return Array.from({ length: Math.max(0, type.arrayLength) }, () => zero(type.arrayChildren));
  if (type.type.startsWith("uint")) return 0n;
  if (type.type === "address") return ZeroAddress;
  if (type.type === "bool") return false;
  if (type.type === "string") return "";
  if (type.type === "bytes") return "0x";
  return `0x${"00".repeat(Number(type.type.slice(5)))}`;
}

function sampleRecord() {
  return { ...zero(recordType), publication: structuredClone(publication), snapshotHost: address(6),
    snapshotCodeHash: h(6), snapshotManifestHash: h(7), snapshotSourceHash: h(8), contentRoot: h(9),
    leafCount: (1n << 63n) + 1n, outputManifestHash: h(10), artistId: h(11), bindingGeneration: 2n,
    bindingHash: h(12), publisher: address(7), authorizationClass: 7n, grantRevision: 1n,
    routeHash: h(13), stateHash: ZeroHash, artistConsent: ZeroHash, publishedAt: 0n };
}

function consentRequest(overrides = {}) {
  return { kind: "recordContentConsent", collectionId: scope.collectionId, newFamilyStateHash: h(50),
    signer: address(9), authorityClass: 1n, authorization: { nonce: 0n, deadline: 100n, signature: "0x" }, ...overrides };
}

function snapshotFacts() {
  const dependencies = zero(ParamType.from(pub.SCOPED_POLICY_PUBLICATION_V2_DEPENDENCIES_TUPLE));
  dependencies.chainId = coordinates.chainId;
  dependencies.targets = Array.from({ length: 11 }, (_, i) => address(20 + i));
  dependencies.codeHashes = Array.from({ length: 11 }, (_, i) => h(120 + i));
  dependencies.targets[0] = coordinates.core;
  dependencies.targets[4] = coordinates.router;
  const route = { finality: address(4), provider: address(5), snapshot: address(6),
    codeHashes: [dependencies.codeHashes[0], h(2), dependencies.codeHashes[4], h(4), h(5), h(6)],
    metadata: dependencies.targets[1], metadataCodeHash: dependencies.codeHashes[1], scope: structuredClone(scope) };
  const source = zero(ParamType.from(pub.SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE));
  source.scope = structuredClone(scope);
  source.outputs.scope = structuredClone(scope);
  source.outputs.contentRoot = h(61);
  source.outputs.tokenCount = 1n;
  source.outputs.manifestHash = h(62);
  source.outputs.outputRoot = h(63);
  source.outputs.checkpointHash = h(64);
  source.outputs.checkpointStateHash = h(65);
  source.outputs.entropySourceSet = dependencies.targets[10];
  source.outputs.inventoryHash = h(66);
  source.outputs.policyChainHash = h(67);
  source.sourceFactory = address(41);
  source.sourceFactoryCodeHash = h(68);
  source.factoryDependenciesHash = h(69);
  source.artist.artistId = h(70);
  source.artist.bindingGeneration = 1n;
  source.artist.bindingHash = h(71);
  const receipt = zero(ParamType.from(pub.SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE));
  receipt.recordHash = publication.snapshotRecordHash;
  receipt.revision = publication.snapshotRevision;
  receipt.scopeSubject = graph.scopedPolicyGraphV2ScopeSubject(coordinates.chainId, coordinates.core, scope);
  receipt.recordedAt = 1n;
  receipt.manifestBytes = 4096n;
  receipt.manifestHash = h(72);
  receipt.chainHash = h(73);
  receipt.schemaHash = pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_SCHEMA_HASH;
  receipt.profileHash = pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_HASH;
  receipt.canonicalizationHash = pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_CANONICALIZATION_HASH;
  receipt.sourceHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", pub.SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"), coordinates.chainId, route.snapshot, dependencies.targets, dependencies.codeHashes, source]));
  return { publication: structuredClone(publication), route, source, dependencies, receipt, publisher: address(8), authorizationClass: 7n, grantRevision: 1n };
}

test("original raw tuples retain zero values and full widths with canonical ABI boundaries", () => {
  for (const [type, encode, decode] of [
    [publicationType, root.encodeScopedPolicyRootV2Publication, root.decodeScopedPolicyRootV2Publication],
    [recordType, root.encodeScopedPolicyRootV2Record, root.decodeScopedPolicyRootV2Record],
    [bindingType, root.encodeScopedPolicyRootV2Binding, root.decodeScopedPolicyRootV2Binding],
    [abi.router.getFunction("scopedContentRootAggregate").outputs[0], root.encodeScopedPolicyRootV2Aggregate, root.decodeScopedPolicyRootV2Aggregate],
  ]) {
    const raw = zero(type);
    assert.equal(encode(raw), coder.encode([type], [raw]));
    assert.deepEqual(decode(encode(raw)), raw);
    assert.throws(() => decode(encode(raw) + "00".repeat(32)), /canonical/);
  }
  assert.deepEqual(root.decodeScopedPolicyRootV2Record(root.encodeScopedPolicyRootV2Record(sampleRecord())), sampleRecord());
  assert.throws(() => root.normalizeScopedPolicyRootV2Publication({ ...publication, snapshotRevision: 1n << 64n }));
  assert.throws(() => root.normalizeScopedPolicyRootV2Publication({ ...publication, scope: { ...scope, scopeType: 5n } }));
  assert.throws(() => root.normalizeScopedPolicyRootV2Record({ ...sampleRecord(), leafCount: 1 }));
  assert.throws(() => root.normalizeScopedPolicyRootV2Aggregate({ revision: 0n, transitionChain: ZeroHash, source: "fake" }));
});

test("operational publications enforce original scoped coordinates and literal UTF8 URI grammar", () => {
  for (const manifestURI of ["https://x", "ipfs://x", "ar://x", "https://é/作品", `ipfs://${"é".repeat(1020)}a`]) {
    assert.equal(root.validateScopedPolicyRootV2Publication({ ...publication, manifestURI }).manifestURI, manifestURI);
  }
  for (const manifestURI of ["", "HTTPS://x", "https:///x", "https://?x", "https://#x", "ipfs://", "ar://", "ipfs://a b", "ipfs://a\u007f", "ipfs://\udc00", `ipfs://${"é".repeat(1021)}`]) {
    assert.throws(() => root.validateScopedPolicyRootV2Publication({ ...publication, manifestURI }));
  }
  for (const badScope of [{ ...scope, scopeType: 0n }, { ...scope, scopeType: 4n }, { ...scope, tokenId: 0n },
    { ...scope, scopeId: h(1) }, { ...scope, scopeType: 2n, tokenId: 0n, scopeId: ZeroHash }]) {
    assert.throws(() => root.validateScopedPolicyRootV2Publication({ ...publication, scope: badScope }));
  }
  assert.throws(() => root.validateScopedPolicyRootV2Publication({ ...publication, snapshotRecordHash: ZeroHash }));
  assert.throws(() => root.validateScopedPolicyRootV2Publication({ ...publication, snapshotRevision: 0n }));
  assert.equal(root.normalizeScopedPolicyRootV2Publication({ ...publication, manifestURI: "" }).manifestURI, "");
});

test("supplied snapshot facts project original binding and state without asserting live provenance", () => {
  const facts = snapshotFacts();
  const prepared = root.scopedPolicyRootV2PreparedRecord(coordinates, facts);
  assert.equal(prepared.factsVerified, false);
  assert.equal(prepared.binding.outputManifest, facts.dependencies.targets[8]);
  assert.equal(prepared.binding.checkpoint, facts.dependencies.targets[7]);
  assert.equal(prepared.binding.entropySourceSet, facts.dependencies.targets[10]);
  assert.equal(prepared.binding.rootSchemaHash, root.SCOPED_POLICY_ROOT_V2_SCHEMA_HASH);
  assert.equal(prepared.record.snapshotSourceHash, facts.receipt.sourceHash);
  assert.equal(prepared.record.stateHash, root.scopedPolicyRootV2StateHash(coordinates, prepared.record, prepared.binding));
  assert.equal(prepared.record.artistConsent, ZeroHash);
  assert.equal(prepared.record.publishedAt, 0n);
  facts.source.outputs.contentRoot = h(900);
  facts.dependencies.targets[8] = address(900);
  assert.notEqual(prepared.record.contentRoot, facts.source.outputs.contentRoot);
  assert.notEqual(prepared.binding.outputManifest, facts.dependencies.targets[8]);
  assert(Object.isFrozen(prepared.record.publication.scope));
  assert.throws(() => root.scopedPolicyRootV2PreparedRecord(coordinates, facts));
});

test("prepared source refuses rehashed wrong scope/route/receipt and incomplete publisher evidence", () => {
  for (const change of [
    f => { f.receipt.recordHash = h(100); },
    f => { f.receipt.revision++; },
    f => { f.receipt.scopeSubject = h(100); },
    f => { f.receipt.profileHash = h(100); },
    f => { f.receipt.sourceHash = h(100); },
    f => { f.dependencies.targets[0] = address(100); },
    f => { f.dependencies.codeHashes[4] = h(100); },
    f => { f.source.outputs.scope.collectionId++; },
    f => { f.authorizationClass = 1n; },
    f => { f.grantRevision = 0n; },
    f => { f.publisher = ZeroAddress; },
  ]) {
    const facts = snapshotFacts(); change(facts);
    assert.throws(() => root.scopedPolicyRootV2PreparedRecord(coordinates, facts));
  }
  const facts = snapshotFacts();
  const pins = facts.route.codeHashes;
  delete pins[0]; Object.setPrototypeOf(pins, { 0: h(1) }); pins.extra = h(2);
  assert.throws(() => root.scopedPolicyRootV2RouteHash(coordinates, facts.route));
});

test("state normalization and collection-wide aggregate preserve family versus record distinction", () => {
  const { record, binding } = root.scopedPolicyRootV2PreparedRecord(coordinates, snapshotFacts());
  const changedDerived = { ...record, stateHash: h(1), artistConsent: h(2), publishedAt: 99n };
  assert.equal(root.scopedPolicyRootV2StateHash(coordinates, changedDerived, binding), record.stateHash);
  const next = root.scopedPolicyRootV2NextAggregate(coordinates, { revision: 0n, transitionChain: ZeroHash }, ZeroHash, record);
  const legacy = root.scopedPolicyRootV2EmptyLegacyFamily(coordinates, scope.collectionId);
  const family = root.scopedPolicyRootV2FamilyHash(coordinates, scope.collectionId, legacy, next);
  assert.notEqual(family, record.stateHash);
  assert.notEqual(root.scopedPolicyRootV2FamilyHash(coordinates, scope.collectionId, legacy, { ...next, transitionChain: h(30) }), family);
  const consent = root.prepareScopedPolicyRootV2Call(coordinates, address(9), consentRequest({ newFamilyStateHash: family }));
  assert.equal(consent.consent.payload.message.newStateHash, family);
  assert.notEqual(consent.consent.payload.message.newStateHash, record.stateHash);
  assert.throws(() => root.scopedPolicyRootV2NextAggregate(coordinates, aggregate, h(1), record));
  assert.throws(() => root.scopedPolicyRootV2NextAggregate(coordinates, { ...aggregate, revision: (1n << 64n) - 1n }, ZeroHash, record));
});

test("V1/V2/V1 history requires known records, exact profile and publication-event aggregate", () => {
  const { record: base, binding } = root.scopedPolicyRootV2PreparedRecord(coordinates, snapshotFacts());
  const record = { ...base, artistConsent: h(80), publishedAt: 100n };
  const v2 = root.scopedPolicyRootV2RecordHash(coordinates, record, binding, aggregate);
  assert.equal(root.authenticateScopedPolicyRootV2History(coordinates, v2, record, binding, aggregate), "v2");
  const noBinding = zero(bindingType);
  const legacy = { ...record, stateHash: root.scopedPolicyRootV2LegacyStateHash(coordinates, record) };
  const v1 = root.scopedPolicyRootV2LegacyRecordHash(coordinates, legacy, aggregate);
  assert.equal(root.authenticateScopedPolicyRootV2History(coordinates, v1, legacy, noBinding, aggregate), "v1");
  const falseV1 = root.scopedPolicyRootV2LegacyRecordHash(coordinates, record, aggregate);
  assert.throws(() => root.authenticateScopedPolicyRootV2History(coordinates, falseV1, record, noBinding, aggregate));
  const later = { ...legacy, publication: { ...legacy.publication, expectedPredecessor: v2 }, publishedAt: 101n };
  later.stateHash = root.scopedPolicyRootV2LegacyStateHash(coordinates, later);
  const laterHash = root.scopedPolicyRootV2LegacyRecordHash(coordinates, later, { ...aggregate, revision: 3n });
  assert.equal(root.authenticateScopedPolicyRootV2History(coordinates, laterHash, later, noBinding, { ...aggregate, revision: 3n }), "v1");
  for (const bad of [{ ...binding, profileId: h(90) }, { ...noBinding, checkpoint: address(1) }]) {
    assert.throws(() => root.authenticateScopedPolicyRootV2History(coordinates, v2, record, bad, aggregate));
  }
  assert.throws(() => root.authenticateScopedPolicyRootV2History(coordinates, v2, zero(recordType), noBinding, aggregate));
  assert.throws(() => root.authenticateScopedPolicyRootV2History(coordinates, v2, record, binding, { ...aggregate, revision: 2n }));
});

test("original op17 calldata and domain preserve nonce0, empty1271 relay and class1/3 boundary", () => {
  const request = consentRequest();
  const direct = root.prepareScopedPolicyRootV2Call(coordinates, request.signer, request);
  const relay = root.prepareScopedPolicyRootV2Call(coordinates, address(10), request);
  assert.equal(direct.consent.direct, true);
  assert.equal(relay.consent.direct, false);
  assert.equal(direct.consent.payload.digest, relay.consent.payload.digest);
  assert.equal(direct.consent.payload.domain.verifyingContract, coordinates.artistRegistry);
  assert.equal(direct.consent.payload.domain.name, "6529StreamArtistRegistry");
  assert.equal(direct.consent.payload.domain.version, "1");
  const p = { collectionId: request.collectionId, metadataContract: coordinates.router, familyId: id("CONTENT_ROOT"), newStateHash: request.newFamilyStateHash };
  assert.equal(direct.call.data, abi.artist.encodeFunctionData("recordContentConsent", [p, { nonce: 0n, time: 100n, signature: "0x" }]));
  assert.equal(direct.consent.digestCall.data, abi.artist.encodeFunctionData("contentConsentDigest", [p, { nonce: 0n, time: 100n, signature: "0x" }]));
  assert.equal(root.prepareScopedPolicyRootV2Call(coordinates, address(10), consentRequest({ authorityClass: 3n })).consent.payload.digest, direct.consent.payload.digest);
  assert.throws(() => root.prepareScopedPolicyRootV2Call(coordinates, address(10), consentRequest({ authorityClass: 4n })));
  assert.equal(root.prepareScopedPolicyRootV2Call(coordinates, request.signer,
    consentRequest({ authorization: { nonce: 0n, deadline: 100n, signature: "0x01" } })).consent.direct, false);
});

test("signature/deadline bounds are separate from inclusion-time authentication", () => {
  const signature = `0x${"ab".repeat(4096)}`;
  const request = consentRequest({ authorization: { nonce: (1n << 256n) - 1n, deadline: (1n << 64n) - 1n, signature } });
  const prepared = root.prepareScopedPolicyRootV2Call(coordinates, address(10), request);
  assert.deepEqual(root.normalizeScopedPolicyRootV2Call(prepared), prepared);
  assert.throws(() => root.prepareScopedPolicyRootV2Call(coordinates, address(10), consentRequest({ authorization: { ...request.authorization, signature: signature + "00" } })));
  assert.throws(() => root.prepareScopedPolicyRootV2Call(coordinates, address(10), consentRequest({ authorization: { nonce: 0n, deadline: 1n << 64n, signature: "0x" } })));
  assert.equal(root.prepareScopedPolicyRootV2Call(coordinates, address(10), consentRequest({ authorization: { nonce: 0n, deadline: 0n, signature: "0x" } })).request.authorization.deadline, 0n);
});

test("operation17 record is independently encoded with observedAt instead of signature deadline", () => {
  const terms = { collectionId: scope.collectionId, metadataContract: coordinates.router, familyId: id("CONTENT_ROOT"), newStateHash: h(80) };
  const facts = { terms, artistId: h(81), signer: address(9), authorityClass: 3n, nonce: 0n, observedAt: 100n };
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"), coordinates.chainId, coordinates.artistRegistry, coordinates.router, coordinates.core,
      scope.collectionId, terms.familyId, terms.newStateHash, facts.artistId, facts.signer, facts.authorityClass, 0n, 100n]));
  assert.equal(root.scopedPolicyRootV2ConsentRecordHash(coordinates, facts), expected);
  assert.notEqual(root.scopedPolicyRootV2ConsentRecordHash(coordinates, { ...facts, observedAt: 101n }), expected);
  assert.throws(() => root.scopedPolicyRootV2ConsentRecordHash(coordinates, { ...facts, authorityClass: 4n }));
  assert.throws(() => root.scopedPolicyRootV2ConsentRecordHash(coordinates, { ...facts, terms: { ...terms, metadataContract: address(999) } }));
  const evidence = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), coordinates.chainId, coordinates.artistRegistry, address(8), 17n, address(10), expected]));
  assert.equal(root.scopedPolicyRootV2ConsentEvidenceId(coordinates, address(8), address(10), expected), evidence);
});

test("original flat op17 payload preserves full binding/proof and rejects dirty bool/trailing ABI", () => {
  const bindingType = abi.bindingHost.getFunction("binding").outputs[0];
  const termsType = abi.artist.getFunction("recordContentConsent").inputs[0];
  const authType = abi.artist.getFunction("recordContentConsent").inputs[1];
  const binding = { ...zero(bindingType), artistId: h(1), artistAddress: address(9), accepted: true, generation: 1n };
  const terms = { collectionId: scope.collectionId, metadataContract: coordinates.router, familyId: id("CONTENT_ROOT"), newStateHash: h(90) };
  const authorization = { nonce: 0n, deadline: 100n, signature: "0x1234" };
  const proof = { signer: address(9), digest: h(91), direct: false };
  const input = { binding, terms, authorization, proof, currentFamilyState: h(92) };
  const expected = coder.encode([bindingType, termsType, authType, "tuple(address signer,bytes32 digest,bool direct)", "bytes32"],
    [binding, terms, { nonce: 0n, time: 100n, signature: "0x1234" }, proof, input.currentFamilyState]);
  assert.equal(root.encodeScopedPolicyRootV2ConsentPayload(input), expected);
  assert.deepEqual(root.decodeScopedPolicyRootV2ConsentPayload(expected), input);
  assert.throws(() => root.decodeScopedPolicyRootV2ConsentPayload(expected + "00".repeat(32)));
  const dirty = expected.slice(0, 2 + 9 * 64) + h(2).slice(2) + expected.slice(2 + 10 * 64);
  assert.throws(() => root.decodeScopedPolicyRootV2ConsentPayload(dirty));
});

test("root publication is CALL0 to original Router with no Artist proof/Store arguments", () => {
  const input = structuredClone(publication);
  const prepared = root.prepareScopedPolicyRootV2Call(coordinates, address(8), { kind: "publishScopedPolicyContentRootPublication", publication: input });
  assert.equal(prepared.call.to, coordinates.router);
  assert.equal(prepared.call.value, 0n);
  assert.equal(prepared.call.data, abi.router.encodeFunctionData("publishScopedPolicyContentRootPublication", [input]));
  assert.equal(prepared.consent, null);
  input.manifestURI = "ipfs://changed";
  assert.equal(prepared.request.publication.manifestURI, publication.manifestURI);
  assert.deepEqual(root.normalizeScopedPolicyRootV2Call(prepared), prepared);
  for (const call of [{ ...prepared.call, value: 1n }, { ...prepared.call, to: address(99) }, { ...prepared.call, data: prepared.call.data + "00" }]) {
    assert.throws(() => root.normalizeScopedPolicyRootV2Call({ ...prepared, call }));
  }
  assert.throws(() => root.prepareScopedPolicyRootV2Call(coordinates, address(8), { kind: "lockSnapshot", scope }));
});

test("prepared signing metadata is detached and wholly reconstructed rather than trusted", () => {
  const request = consentRequest();
  const prepared = root.prepareScopedPolicyRootV2Call(coordinates, address(9), request);
  request.authorization.signature = "0x01";
  request.newFamilyStateHash = h(100);
  assert.equal(prepared.request.authorization.signature, "0x");
  assert(Object.isFrozen(prepared.consent.payload.message));
  assert(Object.isFrozen(prepared.consent.payload.types.StreamArtistContentConsent));
  for (const consent of [{ ...prepared.consent, direct: false },
    { ...prepared.consent, payload: { ...prepared.consent.payload, digest: h(999) } },
    { ...prepared.consent, [Symbol("hidden")]: 1 }]) {
    assert.throws(() => root.normalizeScopedPolicyRootV2Call({ ...prepared, consent }));
  }
  assert.throws(() => root.prepareScopedPolicyRootV2Call(coordinates, address(9), { ...consentRequest(), extra: true }));
});

test("closed read plans preserve preview caller/publisher separation and original read targets", () => {
  const requests = [
    { kind: "previewScopedPolicyContentRootPublication", publication, publisher: address(8) },
    { kind: "scopedContentRootHead", scope }, { kind: "scopedTokenContentRoot", scope },
    { kind: "scopedContentRootRecord", recordHash: h(1) }, { kind: "scopedPolicyContentRootBinding", recordHash: ZeroHash },
    { kind: "consumedArtistContentConsent", recordHash: h(2) },
    ...["scopedContentRootAggregate", "artistContentEvolution", "currentArtistContentState", "artistContentFamilyState", "firstReleaseRatification"].map(kind => ({ kind, collectionId: scope.collectionId })),
    ...["contentConsentEvidence", "contentConsentEvidenceForHost"].map(kind => ({ kind, collectionId: scope.collectionId, newFamilyStateHash: h(3) })),
  ];
  for (const request of requests) {
    const prepared = root.prepareScopedPolicyRootV2Read(coordinates, ZeroAddress, request);
    const expected = request.kind.startsWith("contentConsent") || request.kind === "firstReleaseRatification" ? abi.artist : abi.router;
    assert.equal(expected.parseTransaction(prepared.call).name, request.kind);
    assert.equal(prepared.call.to, expected === abi.artist ? coordinates.artistRegistry : coordinates.router);
    assert.deepEqual(root.normalizeScopedPolicyRootV2Read(prepared), prepared);
    assert.throws(() => root.normalizeScopedPolicyRootV2Read({ ...prepared, call: { ...prepared.call, data: "0x" } }));
  }
  assert.throws(() => root.prepareScopedPolicyRootV2Read(coordinates, address(9), { kind: "publishScopedPolicyContentRootPublication", publication }));
  assert.throws(() => root.prepareScopedPolicyRootV2Read(coordinates, address(9), { kind: "requireCurrent", publication }));
});
