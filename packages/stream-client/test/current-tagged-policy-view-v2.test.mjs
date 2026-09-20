import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, getAddress, hexlify, id, keccak256, toUtf8Bytes } from "ethers";
import * as view from "../dist/current-tagged-policy-view-v2.js";
import { compiledInterfaces } from "./current-tagged-policy-view-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const coordinates = { chainId: (1n << 150n) + 1n, core: address(1), router: address(2) };
const caller = address(3);
const collectionId = (1n << 180n) + 17n;
const clone = value => structuredClone(value);

function setup() {
  const payload = {
    contextVersion: view.TAGGED_POLICY_VIEW_V2_CONTEXT,
    name: "Original 🖼", description: "Complete original bytes", imageURI: "https://a.example/原作",
    script: hexlify(toUtf8Bytes("window.original = '🖼';")),
  };
  const canonical = view.encodeTaggedPolicyViewV2Payload(payload);
  const scope = { scopeType: 4n, collectionId, tokenId: 0n, scopeId: id("sealed membership") };
  const input = { scope, viewId: id("distinct declared view"), viewRecordHash: id("declaration"),
    expectedPrevious: ZeroHash, rendererRegistry: address(10), rendererVersionKey: ZeroHash,
    expectedSourceHash: ZeroHash };
  const membership = { scopeSubject: view.taggedPolicyViewV2ScopeSubject(coordinates, scope),
    scopeManifestHash: id("scope manifest"), sourceRecordHash: id("source record"), tokenCount: (1n << 80n) + 4n,
    tokenListHash: id("token list"), membershipHash: id("membership"), inventoryCount: 0n, inventoryPrefixHash: ZeroHash };
  const route = Object.fromEntries(["core", "router", "artist", "finality", "provider", "metadata", "schemas", "store"]
    .flatMap((key, i) => [[key, address(i + 1)], [`${key}CodeHash`, id(`${key} runtime`)]]));
  route.binding = { views: address(20), viewsCodeHash: id("views runtime"), membership: address(21),
    membershipCodeHash: id("membership runtime"), readGas: 50000n, sourceGas: 100000n };
  const renderer = { registry: input.rendererRegistry, registryCodeHash: id("registry runtime"),
    versionKey: ZeroHash, renderer: address(11), rendererCodeHash: id("renderer runtime"),
    rendererId: id("renderer"), rendererVersion: id("version"), contextVersion: view.TAGGED_POLICY_VIEW_V2_CONTEXT,
    schemaHash: view.TAGGED_POLICY_VIEW_V2_OUTPUT_SCHEMA_HASH, readSetHash: id("read set"), registrationHash: id("registration") };
  renderer.versionKey = keccak256(coder.encode(["bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_RENDERER_VERSION_V1"), renderer.rendererId, renderer.rendererVersion]));
  input.rendererVersionKey = renderer.versionKey;
  const source = { route, membership, renderer, schemaHash: view.TAGGED_POLICY_VIEW_V2_PAYLOAD_SCHEMA_HASH,
    manifestSchemaHash: view.TAGGED_POLICY_VIEW_V2_MANIFEST_SCHEMA_HASH, canonicalizationHash: id("raw bytes definition"),
    manifestPayloadHash: id("original manifest payload"), viewReceiptHash: id("view receipt"),
    payloadHash: keccak256(canonical), payloadBytes: BigInt((canonical.length - 2) / 2),
    payloadPointers: [address(30), ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress],
    payloadChunkHashes: [keccak256(canonical), ZeroHash, ZeroHash, ZeroHash, ZeroHash] };
  const binding = { core: coordinates.core, coreCodeHash: route.coreCodeHash, factory: address(22),
    factoryCodeHash: id("factory runtime"), sourceSet: address(23), sourceSetCodeHash: id("set runtime"),
    chainId: coordinates.chainId, scope, membership, inventoryPlan: id("plan"), inventoryHash: id("inventory"),
    policyChainHash: id("ordered policies"), policyCount: 2n };
  input.expectedSourceHash = view.taggedPolicyViewV2SourceHash(coordinates, input, source, binding);
  const record = { input, source, sourceHash: input.expectedSourceHash, recordHash: ZeroHash,
    revision: 1n, actor: caller, authorizationClass: 7n, grantCollectionId: collectionId,
    grantRevision: (1n << 62n) + 1n, artistConsent: id("op17"), adoptedAt: (1n << 63n) + 3n,
    aggregate: { revision: 0n, transitionChain: ZeroHash } };
  record.aggregate = view.taggedPolicyViewV2NextAggregate(coordinates, record.aggregate, record);
  record.recordHash = view.taggedPolicyViewV2RecordHash(coordinates, record);
  return { payload, canonical, scope, input, source, binding, record };
}

function saved(record, profile = view.TAGGED_POLICY_VIEW_V2_PROFILE) {
  record.recordHash = view.taggedPolicyViewV2RecordHash(coordinates, record, profile);
  const raw = view.encodeTaggedPolicyViewV2Record(record);
  const carrier = { pointer: address(50), contentHash: keccak256(raw), byteSize: BigInt((raw.length - 2) / 2) };
  return { raw, carrier, record };
}

function rule(mode = 2n, renderRequirement = 0n) {
  const policyHash = id("full entropy policy");
  const policy = { configured: true, explicitPolicy: true, frozen: true, mode, securityClass: 1n,
    renderRequirement, revision: 8n, providerEpoch: 7n, policyHash,
    contentStateHash: keccak256(coder.encode(["bytes32", "bytes32", "bool"], [id("6529STREAM_ENTROPY_CONFIGURATION_V1"), policyHash, true])),
    lastActionId: id("action"), artistConsentRecord: id("entropy op17") };
  return { coordinator: address(70), indexedCodeHash: id("coordinator runtime"), firstTokenIndex: 19n,
    frozen: true, moduleVersion: id("module"), moduleManifestHash: id("module manifest"),
    moduleSchemaHash: id("module schema"), deploymentManifestHash: id("deployment"), policyHash,
    provider: ZeroAddress, epoch: 0n, salt: ZeroHash, componentDataHash: id("component"),
    explicitPolicy: true, collectionPolicy: policy };
}

test("closed original payload bytes preserve UTF8 and separate admission URI from retained decode", () => {
  const f = setup();
  assert.deepEqual(view.decodeTaggedPolicyViewV2Payload(f.canonical), f.payload);
  assert.ok(Object.isFrozen(view.normalizeTaggedPolicyViewV2Payload(f.payload)));
  assert.equal(view.validateTaggedPolicyViewV2PayloadAdmission(f.payload).imageURI, f.payload.imageURI);
  for (const imageURI of ["HTTPS://a", "https:///a", "https://?q", "ipfs://", "ar://", "https://a/ x", "https://a/\x7f"]) {
    const raw = view.encodeTaggedPolicyViewV2Payload({ ...f.payload, imageURI });
    assert.equal(view.decodeTaggedPolicyViewV2Payload(raw).imageURI, imageURI);
    assert.throws(() => view.validateTaggedPolicyViewV2PayloadAdmission({ ...f.payload, imageURI }), /URI/);
  }
  for (const imageURI of ["", "ipfs://original", "ar://original", "https://a/%00"]) {
    assert.equal(view.validateTaggedPolicyViewV2PayloadAdmission({ ...f.payload, imageURI }).imageURI, imageURI);
  }
});

test("payload bounds count complete UTF8 bytes and reject noncanonical encodings", () => {
  const f = setup();
  for (const patch of [{ name: "" }, { name: "é".repeat(65) }, { description: "a".repeat(8193) },
    { imageURI: "a".repeat(2049) }, { script: "0x" }, { script: `0x${"00".repeat(24577)}` },
    { name: "\udc00" }, { description: "\ud800" }, { script: "0xc0af" },
    { contextVersion: view.TAGGED_POLICY_VIEW_V1_CONTEXT }]) {
    assert.throws(() => view.encodeTaggedPolicyViewV2Payload({ ...f.payload, ...patch }));
  }
  assert.throws(() => view.decodeTaggedPolicyViewV2Payload(`${f.canonical}${"00".repeat(32)}`), /Noncanonical/);
  assert.throws(() => view.decodeTaggedPolicyViewV2Payload(`0x${"00".repeat(40961)}`), /bound/);
  assert.equal(view.decodeTaggedPolicyViewV2Payload(view.encodeTaggedPolicyViewV2Payload({
    ...f.payload, name: "é".repeat(64), description: "a".repeat(8192), script: hexlify(toUtf8Bytes("x".repeat(24576))),
  })).name, "é".repeat(64));
});

test("full supplied source joins exact binding, scope, selected renderer and fixed unused chunk slots", () => {
  const f = setup();
  const checked = view.validateTaggedPolicyViewV2Source(coordinates, f.input, f.source, f.binding);
  assert.equal(checked.sourceHash, f.input.expectedSourceHash);
  assert.equal(checked.factsVerified, false);
  assert.ok(Object.isFrozen(checked.source.payloadPointers));
  for (const mutate of [x => x.binding.chainId++, x => x.binding.scope = { ...x.scope, scopeId: x.input.viewId },
    x => x.binding.membership = { ...x.source.membership, tokenCount: 3n },
    x => x.source.renderer.contextVersion = view.TAGGED_POLICY_VIEW_V1_CONTEXT,
    x => x.source.payloadPointers[4] = address(99), x => x.source.route.binding.readGas = 49999n,
    x => x.source.membership.inventoryCount = 1n, x => x.binding.policyCount = 0n,
    x => x.source.route.router = address(99)]) {
    const changed = clone(f); mutate(changed);
    assert.throws(() => view.validateTaggedPolicyViewV2Source(coordinates, changed.input, changed.source, changed.binding));
  }
  const altered = { ...f.binding, inventoryHash: id("other actual inventory") };
  assert.notEqual(view.taggedPolicyViewV2SourceHash(coordinates, f.input, f.source, altered), f.input.expectedSourceHash);
  assert.throws(() => view.validateTaggedPolicyViewV2Source(coordinates, f.input, f.source, altered), /Source hash changed/);
});

test("payload carrier verification retains all five ordered chunks with exact STOP and full digest", () => {
  const f = setup();
  const payload = { ...f.payload, description: "d".repeat(8192), script: hexlify(toUtf8Bytes("s".repeat(24576))) };
  const canonical = view.encodeTaggedPolicyViewV2Payload(payload);
  const chunks = Array.from({ length: Math.ceil((canonical.length - 2) / 16384) }, (_, i) => `0x${canonical.slice(2 + i * 16384, 2 + (i + 1) * 16384)}`);
  assert.equal(chunks.length, 5);
  const source = { ...f.source, payloadHash: keccak256(canonical), payloadBytes: BigInt((canonical.length - 2) / 2),
    payloadPointers: chunks.map((_, i) => address(80 + i)), payloadChunkHashes: chunks.map(keccak256) };
  const runtimes = chunks.map(chunk => `0x00${chunk.slice(2)}`);
  assert.deepEqual(view.validateTaggedPolicyViewV2PayloadCarriers(source, runtimes), payload);
  assert.throws(() => view.validateTaggedPolicyViewV2PayloadCarriers(source, [...runtimes].reverse()));
  assert.throws(() => view.validateTaggedPolicyViewV2PayloadCarriers(source, [runtimes[0].replace("0x00", "0x01"), ...runtimes.slice(1)]), /STOP/);
  assert.throws(() => view.validateTaggedPolicyViewV2PayloadCarriers(source, [runtimes[0] + "00", ...runtimes.slice(1)]), /STOP/);
  assert.throws(() => view.validateTaggedPolicyViewV2PayloadCarriers({ ...source, payloadHash: id("wrong") }, runtimes), /hash mismatch/);
});

test("known V1 and tagged V2 retain one authenticated outer history without payload reinterpretation", () => {
  const f = setup();
  const v2 = saved(clone(f.record));
  const v1 = saved({ ...clone(f.record), source: { ...f.source,
    renderer: { ...f.source.renderer, contextVersion: view.TAGGED_POLICY_VIEW_V1_CONTEXT } } }, ZeroHash);
  assert.notEqual(v1.record.recordHash, v2.record.recordHash);
  for (const [tag, old] of [[ZeroHash, v1], [view.TAGGED_POLICY_VIEW_V2_PROFILE, v2]]) {
    const result = view.authenticateTaggedPolicyViewV2Record(coordinates, tag, old.record.recordHash, old.raw, old.carrier);
    assert.equal(result.record.revision, 1n);
    assert.equal(result.profile, tag);
    assert.equal(result.factsVerified, false);
    assert.throws(() => view.authenticateTaggedPolicyViewV2Record(coordinates,
      tag === ZeroHash ? view.TAGGED_POLICY_VIEW_V2_PROFILE : ZeroHash, old.record.recordHash, old.raw, old.carrier));
    assert.throws(() => view.authenticateTaggedPolicyViewV2Record(coordinates, tag, id("unknown"), old.raw, old.carrier));
    assert.throws(() => view.authenticateTaggedPolicyViewV2Record(coordinates, tag, old.record.recordHash, old.raw,
      { ...old.carrier, pointer: ZeroAddress }));
  }
  assert.throws(() => view.normalizeTaggedPolicyViewV2Profile(id("unrecognized profile"), v2.carrier), /Unknown/);
  assert.throws(() => view.normalizeTaggedPolicyViewV2Profile(ZeroHash,
    { pointer: ZeroAddress, contentHash: ZeroHash, byteSize: 0n }));
  assert.throws(() => view.authenticateTaggedPolicyViewV2Record({ ...coordinates, chainId: coordinates.chainId + 1n },
    view.TAGGED_POLICY_VIEW_V2_PROFILE, v2.record.recordHash, v2.raw, v2.carrier));
});

test("prepared/aggregate/record identity excludes only the original self field and wraps the existing family", () => {
  const f = setup();
  assert.equal(view.taggedPolicyViewV2RecordHash(coordinates, { ...f.record, recordHash: id("ignored own field") }), f.record.recordHash);
  assert.notEqual(view.taggedPolicyViewV2RecordHash(coordinates, { ...f.record, artistConsent: id("different consent") }), f.record.recordHash);
  assert.notEqual(view.taggedPolicyViewV2PreparedHash(f.record), view.taggedPolicyViewV2PreparedHash({ ...f.record, actor: address(99) }));
  assert.equal(view.taggedPolicyViewV2FamilyState(coordinates, collectionId, id("legacy"), { revision: 0n, transitionChain: ZeroHash }), id("legacy"));
  assert.notEqual(view.taggedPolicyViewV2FamilyState(coordinates, collectionId, id("legacy"), f.record.aggregate), id("legacy"));
  assert.throws(() => view.taggedPolicyViewV2FamilyState(coordinates, collectionId, id("legacy"), { revision: 0n, transitionChain: id("bad") }));
  assert.throws(() => view.taggedPolicyViewV2NextAggregate(coordinates, { revision: (1n << 64n) - 1n, transitionChain: id("old") }, f.record), /uint64/);
  assert.deepEqual(view.taggedPolicyViewV2ConsentTerms(coordinates, collectionId, id("next")), {
    collectionId, metadataContract: coordinates.router, familyId: id("RENDERER_CONFIG"), newStateHash: id("next"),
  });
});

test("policy binding and all original record words use exact bigint widths and immutable copies", () => {
  const f = setup();
  assert.equal((view.encodeTaggedPolicyViewV2PolicyBinding(f.binding).length - 2) / 2, 736);
  assert.equal((view.encodeTaggedPolicyViewV2CoordinatorPolicy(rule()).length - 2) / 2, 832);
  const normalized = view.normalizeTaggedPolicyViewV2Record(f.record);
  f.record.source.payloadPointers[0] = address(99);
  assert.equal(normalized.source.payloadPointers[0], address(30));
  assert.throws(() => view.normalizeTaggedPolicyViewV2Record({ ...f.record, adoptedAt: 1n << 64n }), /uint64/);
  assert.throws(() => view.normalizeTaggedPolicyViewV2Record({ ...f.record, revision: 1 }), /bigint/);
  assert.throws(() => view.normalizeTaggedPolicyViewV2Record({ ...f.record, extra: true }), /unknown/);
  assert.throws(() => view.normalizeTaggedPolicyViewV2PolicyBinding({ ...f.binding, scope: { ...f.scope, scopeType: 5n } }), /scope/);
  const sparse = Array(5); sparse[0] = address(30);
  assert.throws(() => view.normalizeTaggedPolicyViewV2Source({ ...f.source, payloadPointers: sparse }), /dense/);
});

test("terminal explicit branches never invent a finalized seed; required ASYNC and legacy remain separate", () => {
  for (const [mode, status] of [[0n, 1n], [2n, 2n]]) {
    const r = rule(mode, 1n);
    const facts = { collectionId, policy: r.collectionPolicy, status, seed: ZeroHash, requestKey: ZeroHash };
    const output = view.taggedPolicyViewV2Entropy(r, collectionId, { kind: "explicit", facts });
    assert.equal(output.terminal, true); assert.equal(output.finalized, false); assert.equal(output.seed, ZeroHash);
    assert.equal((view.encodeTaggedPolicyViewV2TerminalFacts(facts).length - 2) / 2, 512);
    assert.throws(() => view.taggedPolicyViewV2Entropy(r, collectionId, { kind: "explicit", facts: { ...facts, seed: id("invented") } }));
    assert.throws(() => view.taggedPolicyViewV2Entropy(r, collectionId, { kind: "explicit", facts: { ...facts, requestKey: id("invented") } }));
  }
  const r = rule();
  const facts = { collectionId, policy: r.collectionPolicy, status: 5n, seed: id("actual seed"), requestKey: id("request") };
  const finalized = view.taggedPolicyViewV2Entropy(r, collectionId, { kind: "explicit", facts });
  assert.equal(finalized.finalized, true); assert.equal(finalized.terminal, false);
  for (const status of [0n, 3n, 4n, 6n, 7n, 255n]) {
    assert.throws(() => view.taggedPolicyViewV2Entropy(r, collectionId, { kind: "explicit", facts: { ...facts, status } }));
  }
  const instant = rule(1n, 0n);
  assert.throws(() => view.taggedPolicyViewV2Entropy(instant, collectionId,
    { kind: "explicit", facts: { ...facts, policy: instant.collectionPolicy } }));
  const empty = view.decodeTaggedPolicyViewV2Policy(`0x${"00".repeat(12 * 32)}`);
  const legacy = { ...r, explicitPolicy: false, provider: address(90), epoch: 1n, salt: id("salt"), collectionPolicy: empty };
  const retained = view.taggedPolicyViewV2Entropy(legacy, collectionId, { kind: "legacy", status: 5n, seed: ZeroHash, provider: ZeroAddress });
  assert.equal(retained.explicitPolicy, false); assert.deepEqual(retained.policy, empty);
  assert.throws(() => view.taggedPolicyViewV2Entropy(legacy, collectionId, { kind: "explicit", facts }));
  assert.throws(() => view.taggedPolicyViewV2Entropy(r, collectionId, { kind: "legacy", status: 5n, seed: ZeroHash, provider: ZeroAddress }));
});

test("exact original 512-byte facts preserve the full entropy family domain and reject dirty ABI booleans", () => {
  const originalPolicyTuple = "tuple(bool configured,bool explicitPolicy,bool frozen,uint8 mode,uint8 securityClass,uint8 renderRequirement,uint64 revision,uint32 providerEpoch,bytes32 policyHash,bytes32 contentStateHash,bytes32 lastActionId,bytes32 artistConsentRecord)";
  for (const [mode, requirement, status] of [[0n, 1n, 1n], [2n, 1n, 2n], [2n, 0n, 5n]]) {
    const r = rule(mode, requirement);
    const f = { collectionId, policy: r.collectionPolicy, status, seed: status === 5n ? id("final seed") : ZeroHash,
      requestKey: status === 5n ? id("original request") : ZeroHash };
    const raw = coder.encode(["uint256", originalPolicyTuple, "uint8", "bytes32", "bytes32"],
      [f.collectionId, f.policy, f.status, f.seed, f.requestKey]);
    assert.equal(raw.length, 1026);
    assert.deepEqual(view.decodeTaggedPolicyViewV2TerminalFacts(raw), f);
    assert.equal(view.taggedPolicyViewV2Entropy(r, collectionId, { kind: "explicit", facts: f }).finalized, status === 5n);
    const wrong = { ...r, collectionPolicy: { ...r.collectionPolicy,
      contentStateHash: keccak256(coder.encode(["bytes32", "bytes32", "bool"], [id("ENTROPY_CONFIGURATION"), r.policyHash, true])) } };
    assert.throws(() => view.taggedPolicyViewV2Entropy(wrong, collectionId,
      { kind: "explicit", facts: { ...f, policy: wrong.collectionPolicy } }), /explicit rule/);
    const dirtyBoolean = `${raw.slice(0, 2 + 64)}${"2".padStart(64, "0")}${raw.slice(2 + 128)}`;
    assert.throws(() => view.decodeTaggedPolicyViewV2TerminalFacts(dirtyBoolean), /Noncanonical/);
  }
});

test("adoption is the original unsigned Router CALL with no arbitrary Source injection", () => {
  const f = setup();
  const prepared = view.prepareTaggedPolicyViewV2Call(coordinates, caller, { kind: "adoptPolicyView", input: f.input });
  assert.equal(prepared.call.data, compiledInterfaces.policyRouter.encodeFunctionData("adoptPolicyView", [f.input]));
  assert.equal(prepared.call.to, coordinates.router); assert.equal(prepared.call.value, 0n);
  assert.equal(prepared.caller, caller); assert.equal(prepared.factsVerified, false);
  f.input.scope.collectionId++;
  assert.equal(prepared.request.input.scope.collectionId, collectionId);
  assert.deepEqual(view.normalizeTaggedPolicyViewV2Call(prepared), prepared);
  for (const patch of [{ value: 1n }, { to: caller }, { data: "0x" }]) {
    assert.throws(() => view.normalizeTaggedPolicyViewV2Call({ ...prepared, call: { ...prepared.call, ...patch } }));
  }
  assert.throws(() => view.prepareTaggedPolicyViewV2Call(coordinates, caller, { kind: "adoptPolicyView", input: f.input, source: f.source }), /unknown/);
  assert.throws(() => view.prepareTaggedPolicyViewV2Call(coordinates, caller,
    { kind: "adoptPolicyView", input: { ...f.input, expectedSourceHash: ZeroHash } }), /nonzero/);
  assert.throws(() => view.prepareTaggedPolicyViewV2Call(coordinates, ZeroAddress, { kind: "adoptPolicyView", input: f.input }));
  assert.throws(() => view.prepareTaggedPolicyViewV2Call(coordinates, caller, { kind: "adoptView", input: f.input }));
});

test("all original Router reads retain explicit caller and preview actor separately", () => {
  const f = setup();
  const requests = [
    { kind: "previewPolicyViewAdoption", input: { ...f.input, expectedSourceHash: ZeroHash }, actor: caller },
    { kind: "viewAdoptionHead", scope: f.scope }, { kind: "viewAdoptionAggregate", collectionId },
    ...["viewAdoptionEncoded", "viewAdoptionCarrier", "viewAdoptionProfile"].map(kind => ({ kind, recordHash: f.record.recordHash })),
    ...["tokenJSONForView", "tokenHTMLForView"].map(kind => ({ kind, tokenId: 1n << 190n, scopeId: f.scope.scopeId })),
    ...["historicalTokenJSONForView", "historicalTokenHTMLForView"].map(kind => ({ kind, tokenId: 1n << 190n, recordHash: f.record.recordHash })),
  ];
  for (const request of requests) {
    const read = view.prepareTaggedPolicyViewV2Read(coordinates, ZeroAddress, request);
    const abi = request.kind === "previewPolicyViewAdoption" || request.kind === "viewAdoptionProfile"
      ? compiledInterfaces.policyRouter : compiledInterfaces.viewRouter;
    assert.equal(read.call.data.slice(0, 10), abi.getFunction(request.kind).selector);
    assert.equal(read.call.value, 0n); assert.equal(read.caller, ZeroAddress);
    assert.deepEqual(view.normalizeTaggedPolicyViewV2Read(read), read);
  }
  assert.throws(() => view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "requireCurrent" }));
  assert.throws(() => view.prepareTaggedPolicyViewV2Read(coordinates, caller, { kind: "viewAdoptionProfile", recordHash: ZeroHash }));
});

test("renderer modes 0 through 3 preserve empty-golden limitation and closed read targets", () => {
  const request = { core: coordinates.core, tokenId: 0n, collectionId: 0n, collectionSerial: 0n,
    tokenHash: ZeroHash, state: 0n, mode: 1n, collectionSupplyMode: 0n, collectionStatus: 0n,
    viewId: ZeroHash, viewManifestHash: ZeroHash, metadataSnapshotHash: ZeroHash };
  for (const mode of [0n, 1n, 2n, 3n]) {
    const read = view.prepareTaggedPolicyViewV2RendererRead(address(11), ZeroAddress, { kind: "renderPolicyView", request, mode });
    assert.equal(read.call.data, compiledInterfaces.rendererInterface.encodeFunctionData("renderPolicyView", [request, mode]));
    assert.deepEqual(view.normalizeTaggedPolicyViewV2RendererRead(read), read);
    assert.equal(read.factsVerified, false);
  }
  for (const kind of ["sourceBindings", "encodingBinding", "policyViewBinding"]) {
    assert.equal(view.prepareTaggedPolicyViewV2RendererRead(address(11), caller, { kind }).call.data,
      compiledInterfaces.rendererInterface.encodeFunctionData(kind));
  }
  assert.throws(() => view.prepareTaggedPolicyViewV2RendererRead(address(11), caller, { kind: "renderPolicyView", request, mode: 4n }));
  assert.throws(() => view.prepareTaggedPolicyViewV2RendererRead(address(11), caller, { kind: "tokenURI", request: { ...request, collectionId: 1n } }));
  assert.throws(() => view.prepareTaggedPolicyViewV2RendererRead(address(11), caller, { kind: "tokenURI", request: { ...request, mode: 0n } }));
  const full = { ...request, tokenId: 1n, collectionId, collectionSerial: 1n, collectionStatus: 255n, collectionSupplyMode: 255n };
  assert.equal(view.normalizeTaggedPolicyViewV2RenderRequest(full).collectionStatus, 255n);
  assert.throws(() => view.normalizeTaggedPolicyViewV2RenderRequest({ ...full, state: 4n }));
});

test("output decoder caps original complete return bytes and preserves canonical Unicode", () => {
  const output = "{\"name\":\"原作🖼\"}";
  const raw = coder.encode(["string"], [output]);
  assert.equal(view.decodeTaggedPolicyViewV2Output(raw), output);
  assert.throws(() => view.decodeTaggedPolicyViewV2Output(`${raw}${"00".repeat(32)}`), /Noncanonical/);
  assert.throws(() => view.decodeTaggedPolicyViewV2Output(`0x${"00".repeat(262209)}`), /bound/);
});
