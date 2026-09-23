import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import * as f from "../dist/current-scoped-policy-finality-v2.js";
import { compiledInterfaces as ci, fixture } from "./current-scoped-policy-finality-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const H = name => id(name);
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const clone = value => structuredClone(value);
const C = { chainId: (1n << 160n) + 1n, core: A(1), metadata: A(2), registry: A(3), executor: A(4), artist: A(5), artifactCoverage: A(6) };
const T = { provider: A(7), discovery: A(8) };
const families = ["METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT", "MEDIA_MANIFEST", "SCRIPT_SOURCE", "DEPENDENCY_SOURCE", "COLLECTION_METADATA", "ENTROPY_COORDINATOR", "REFERENCE_RENDER"].map(H).sort();
function specimen(scope = { scopeType: 1n, collectionId: (1n << 200n) + 1n, tokenId: (1n << 220n) + 2n, scopeId: ZeroHash }) {
  const rows = families.map((componentType, i) => ({ componentType, component: A(100 + i), interfaceId: "0x12345678",
    codeHash: H(`code${i}`), moduleVersion: H(`version${i}`), manifestHash: H(`manifest${i}`), dataHash: H(`data${i}`) }));
  const inputs = Object.fromEntries(["rootRecordHash", "snapshotRecordHash", "referenceRenderRecordHash", "intentRecordHash", "intentWaiverRecordHash", "interviewEvidenceHash", "rightsStatementRecordHash", "workDescriptionRecordHash", "renderCriticalEvidenceHash", "bundleCoverageHash"].map(k => [k, k === "intentWaiverRecordHash" ? ZeroHash : H(k)]));
  const statement = { scope, coreFactsHash: H("historical core"), contentRoot: H("content root"), leafCount: scope.scopeType === 1n ? 1n : (1n << 63n) + 9n,
    contentRootSchemaId: H("root schema"), snapshotManifestHash: H("snapshot bytes"), referenceRenderManifestHash: H("reference bytes"),
    inputs, nonSanctionComponents: rows, entropyPolicy: 1n, postFreezePolicy: 1n, sanctionPolicy: 1n };
  const proof = { sanctionRecordHash: H("sanction"), artifactHash: H("artifact"), completionHash: H("completion") };
  const artist = { componentType: H("ARTIST_SANCTION"), component: C.artist, interfaceId: "0x8004d4f5", codeHash: H("Artist runtime"),
    moduleVersion: H("Artist version"), manifestHash: H("Artist manifest"), dataHash: proof.sanctionRecordHash };
  const components = [...rows, artist].sort((a, b) => a.componentType.localeCompare(b.componentType));
  const manifestBytes = f.scopedPolicyFinalityV2ManifestBytes(C, statement);
  const input = { manifestBytes, manifestURI: "", components, proof };
  const plan = f.prepareScopedPolicyFinalityV2Finalization(C, input);
  const window = { notBefore: 72n * 3600n, expiresAfter: 72n * 3600n + 7n * 86400n, reasonHash: H("reason"), reasonURI: "", manifestHash: H("governance manifest") };
  const batch = f.scopedPolicyFinalityV2GovernanceBatch(plan, 0n, window);
  const record = { finalized: true, scope, finalityRecordHash: plan.execution.finalityRecordHash, manifestContentHash: plan.manifest.contentHash,
    manifestURIHash: plan.manifest.uriHash, componentsHash: plan.execution.componentsHash, finalityManifestURI: "", manifestPointer: C.registry, finalizedAt: 1234n };
  return { statement, proof, components, input, plan, window, batch, record };
}
function zero(t) {
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(c => [c.name, zero(c)]));
  if (t.baseType === "array") return Array.from({ length: Math.max(0, t.arrayLength) }, () => zero(t.arrayChildren));
  if (t.type.startsWith("uint")) return 0n;
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  if (t.type === "bytes") return "0x";
  return `0x${"00".repeat(Number(t.type.slice(5)))}`;
}

test("all structural codecs preserve canonical empty original tuples without declaring readiness", () => {
  for (const [key, tuple] of Object.entries(f).filter(([k]) => k.endsWith("_TUPLE") && !k.endsWith("ACTION_IDENTITY_TUPLE"))) {
    const stem = key.slice("SCOPED_POLICY_FINALITY_V2_".length, -"_TUPLE".length).toLowerCase().split("_").map(s => s[0].toUpperCase() + s.slice(1)).join("");
    const value = zero(ParamType.from(tuple)), raw = coder.encode([tuple], [value]);
    assert.equal(f[`encodeScopedPolicyFinalityV2${stem}`](value), raw, stem);
    assert.deepEqual(f[`decodeScopedPolicyFinalityV2${stem}`](raw), value, stem);
    assert.throws(() => f[`decodeScopedPolicyFinalityV2${stem}`](`${raw}${"00".repeat(32)}`), /canonical|bound/);
  }
  assert.throws(() => f.validateScopedPolicyFinalityV2Scope(zero(ParamType.from(f.SCOPED_POLICY_FINALITY_V2_SCOPE_TUPLE))), /scope/);
});

test("canonical manifest matches the original flat compiler tuple and literal definitions", () => {
  const { statement, input } = specimen();
  const rawStatement = fixture.libraryAbis.scopedFinalityInputManifestReads.find(row => row.name === "encode").inputs[1];
  const valueType = p => ({ ...p, type: p.type === "StreamFinalityScopeType" ? "uint8" : p.type, ...(p.components ? { components: p.components.map(valueType) } : {}) });
  const st = ParamType.from(valueType(rawStatement));
  const expected = coder.encode(["bytes32", "bytes32", "uint256", "address", "address", "address", st],
    [H("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1"), H("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1"), C.chainId, C.core, C.metadata, C.registry, statement]);
  assert.equal(input.manifestBytes, expected);
  assert.deepEqual(f.decodeScopedPolicyFinalityV2Manifest(expected).statement, statement);
  for (const [name, path] of [["SCHEMA", "scoped-input-manifest-v1"], ["CANONICALIZATION", "scoped-input-manifest-abi-v1"]]) {
    const text = fixture.documents[`docs/schemas/finality/${path}.definition.json`].text;
    assert.equal(f[`SCOPED_POLICY_FINALITY_V2_${name}_DOCUMENT`], text);
    assert.equal(f[`SCOPED_POLICY_FINALITY_V2_${name}_HASH`], keccak256(toUtf8Bytes(text)));
    assert.equal(f[`SCOPED_POLICY_FINALITY_V2_${name}_BYTES`], BigInt(Buffer.byteLength(text)));
  }
});

test("manifest admission is closed to the actual three scoped native profiles", () => {
  for (const scopeType of [2n, 3n]) assert.doesNotThrow(() => specimen({ scopeType, collectionId: 1n, tokenId: 0n, scopeId: H("scope") }));
  const { statement } = specimen();
  for (const mutate of [s => s.scope.scopeType = 4n, s => s.scope.scopeType = 0n, s => s.scope.collectionId = 0n,
    s => s.scope.tokenId = 0n, s => s.scope.scopeId = H("bad"), s => s.leafCount = 2n, s => s.entropyPolicy = 2n,
    s => s.inputs.intentWaiverRecordHash = H("both"), s => s.inputs.intentRecordHash = ZeroHash,
    s => s.nonSanctionComponents.reverse(), s => s.nonSanctionComponents.pop(), s => s.nonSanctionComponents[0].dataHash = ZeroHash,
    s => s.nonSanctionComponents[0].componentType = H("unknown family")]) {
    const s = clone(statement); mutate(s);
    assert.throws(() => f.scopedPolicyFinalityV2ManifestBytes(C, s));
  }
});

test("canonical bytes reject dirty enums, trailing words, bad offsets, foreign coordinates and over-allocation", () => {
  const { input } = specimen();
  assert.throws(() => f.decodeScopedPolicyFinalityV2Manifest(`${input.manifestBytes}00`));
  const raw = input.manifestBytes.slice(2), offset = Number(BigInt(`0x${raw.slice(6 * 64, 7 * 64)}`));
  const dirty = `0x${raw.slice(0, offset * 2)}${"f".repeat(64)}${raw.slice(offset * 2 + 64)}`;
  assert.throws(() => f.decodeScopedPolicyFinalityV2Manifest(dirty));
  assert.throws(() => f.decodeScopedPolicyFinalityV2Manifest(`0x${"00".repeat(8193)}`), /bound/);
  assert.throws(() => f.prepareScopedPolicyFinalityV2Finalization({ ...C, metadata: A(999) }, input), /deployment/);
  assert.throws(() => f.normalizeScopedPolicyFinalityV2Scope({ scopeType: 5n, collectionId: 0n, tokenId: 0n, scopeId: ZeroHash }), /enum/);
  assert.equal(f.normalizeScopedPolicyFinalityV2ScopedCoreFacts({ ...zero(ParamType.from(f.SCOPED_POLICY_FINALITY_V2_SCOPED_CORE_FACTS_TUPLE)), scopeType: 255n }).scopeType, 255n);
});

test("finalization retains exact ten rows and immutable actual Artist sanction association", () => {
  const { input, plan } = specimen();
  assert.equal(plan.factsVerified, false);
  assert.equal(plan.targetCall.to, C.registry);
  assert.equal(plan.targetCall.value, 0n);
  assert.equal(plan.targetCall.data, ci.finality.encodeFunctionData("finalizeArtworkScopeWithArchive", [plan.scope, plan.components, plan.execution.finalityRecordHash, plan.manifest, plan.proof]));
  assert.equal(plan.contextCall.data, ci.finality.encodeFunctionData("finalityExecutionContextWithArchive", [plan.scope, plan.components, plan.execution.finalityRecordHash, plan.manifest, plan.proof]));
  for (const mutate of [x => x.components[0].dataHash = H("different independent row"), x => x.components.find(v => v.componentType === H("ARTIST_SANCTION")).component = A(500),
    x => x.components.find(v => v.componentType === H("ARTIST_SANCTION")).interfaceId = "0x1300f2d7", x => x.proof.sanctionRecordHash = H("other sanction"),
    x => x.proof.artifactHash = ZeroHash, x => x.components.reverse()]) {
    const value = clone(input); mutate(value); assert.throws(() => f.prepareScopedPolicyFinalityV2Finalization(C, value));
  }
});

test("archive proof changes target new state without rewriting permanent record or target scope", () => {
  const { input, plan } = specimen();
  const other = f.prepareScopedPolicyFinalityV2Finalization(C, { ...input, proof: { ...input.proof, completionHash: H("later retained coverage") } });
  assert.equal(other.execution.finalityRecordHash, plan.execution.finalityRecordHash);
  assert.equal(other.execution.scopeHash, plan.execution.scopeHash);
  assert.equal(other.execution.oldValueHash, plan.execution.oldValueHash);
  assert.notEqual(other.execution.newValueHash, plan.execution.newValueHash);
  const unarchived = keccak256(coder.encode(["bytes32", "bytes32", "bool", "bytes32"], [H("6529STREAM_FINALITY_EXECUTION_NEW_V1"), plan.execution.scopeHash, true, plan.execution.finalityRecordHash]));
  assert.notEqual(plan.execution.newValueHash, unarchived);
});

test("retained history authenticates without current Core and refuses full-scope/component/manifest substitution", () => {
  const { input, record } = specimen();
  const historical = { manifestBytes: input.manifestBytes, record, components: input.components };
  const observed = f.authenticateScopedPolicyFinalityV2History(C, historical);
  assert.equal(observed.factsVerified, false);
  for (const mutate of [x => x.record.scope.collectionId += 1n, x => x.record.finalized = false,
    x => x.record.manifestPointer = A(1000), x => x.record.manifestURIHash = H("incorrect"),
    x => x.record.componentsHash = H("incorrect"), x => x.record.finalityManifestURI = "changed",
    x => x.components[0].dataHash = H("different")]) {
    const x = clone(historical); mutate(x); assert.throws(() => f.authenticateScopedPolicyFinalityV2History(C, x));
  }
  assert.equal(observed.statement.coreFactsHash, H("historical core"));
  historical.record.finalizedAt = 9999n;
  assert.equal(observed.record.finalizedAt, 1234n);
});

test("Provider Sources use exact document profile, preserve full scope and reject future or legacy profiles", () => {
  const { statement } = specimen();
  const p = { profileHash: "0x2a9edb22fe6d8eb7105c2964dbcea97284c317242a3ee0c544dc04e6c3a4870b", referenceRender: A(9), referenceRenderCodeHash: H("r"),
    snapshots: A(10), snapshotsCodeHash: H("s"), entropyFactory: A(11), entropyFactoryCodeHash: H("e"), configurationHash: H("configuration") };
  assert.deepEqual(f.validateScopedPolicyFinalityV2Sources({ scope: statement.scope, profile: p }, statement.scope).profile, p);
  for (const profileHash of [ZeroHash, H("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2"), H("future current authority")]) {
    assert.throws(() => f.validateScopedPolicyFinalityV2Sources({ scope: statement.scope, profile: { ...p, profileHash } }, statement.scope), /profile/);
  }
  assert.throws(() => f.validateScopedPolicyFinalityV2Sources({ scope: { ...statement.scope, collectionId: 9n }, profile: p }, statement.scope));
});

test("gas constraints preserve uint256 fields, inclusive lower bounds and EIP150 headroom", () => {
  const c = { targets: Array.from({ length: 22 }, (_, i) => A(i + 100)), codeHashes: Array.from({ length: 22 }, (_, i) => H(`pin${i}`)), chainId: C.chainId,
    readGas: 50000n, componentSourceGas: 100000n, sourceGas: 100000n + 100000n / 63n + 100001n, inventoryDependencyHash: H("inventory") };
  assert.deepEqual(f.validateScopedPolicyFinalityV2NativeConfiguration(c), c);
  assert.throws(() => f.validateScopedPolicyFinalityV2NativeConfiguration({ ...c, sourceGas: c.sourceGas - 1n }));
  assert.throws(() => f.validateScopedPolicyFinalityV2NativeConfiguration({ ...c, componentSourceGas: 1n << 32n }));
  assert.equal(f.normalizeScopedPolicyFinalityV2NativeConfiguration({ ...c, sourceGas: 1n << 200n }).sourceGas, 1n << 200n);
  const hole = [...c.targets]; delete hole[1]; hole.extra = A(2);
  assert.throws(() => f.normalizeScopedPolicyFinalityV2NativeConfiguration({ ...c, targets: hole }));
  for (const key of [Symbol("surplus"), "hidden"]) {
    const targets = [...c.targets];
    Object.defineProperty(targets, key, { value: A(99), enumerable: false });
    assert.throws(() => f.normalizeScopedPolicyFinalityV2NativeConfiguration({ ...c, targets }), /array/);
  }
});

test("provider configuration excludes its derived hash while combined source configuration binds the full stored binding", () => {
  const native = zero(ci.provider.getFunction("nativeConfiguration").outputs[0]);
  native.chainId = C.chainId;
  const binding = { factory: A(90), factoryCodeHash: H("factory"), recipeHash: H("recipe"), sourceFactoryDependenciesHash: H("dependencies"), graphGas: 80000n, configurationHash: ZeroHash };
  const providerHash = f.scopedPolicyFinalityV2ProviderConfigurationHash(T.provider, native, binding);
  const stored = { ...binding, configurationHash: providerHash };
  assert.equal(f.scopedPolicyFinalityV2ProviderConfigurationHash(T.provider, native, stored), providerHash);
  const source = zero(ParamType.from(f.SCOPED_POLICY_FINALITY_V2_SOURCE_CONFIGURATION_TUPLE));
  source.chainId = C.chainId;
  assert.notEqual(f.scopedPolicyFinalityV2SourceConfigurationHash(T.provider, source, binding), f.scopedPolicyFinalityV2SourceConfigurationHash(T.provider, source, stored));
  assert.notEqual(f.scopedPolicyFinalityV2ProviderConfigurationHash(A(999), native, stored), providerHash);
  source.profiles.push(source.profiles[0]);
  assert.throws(() => f.normalizeScopedPolicyFinalityV2SourceConfiguration(source), /array/);
});

test("singleton class2 batches use original calls, aggregate transitions and exact outer ABI", () => {
  const { plan, batch } = specimen();
  assert.equal(batch.calls.length, 1);
  assert.equal(batch.calls[0].scopeHash, plan.execution.scopeHash);
  assert.notEqual(batch.scopeHash, plan.execution.scopeHash);
  assert.equal(batch.publicationKey, keccak256(keccak256(plan.targetCall.data)));
  assert.equal(batch.publicationCall.data, ci.executor.encodeFunctionData("publishGovernanceCallData", [[plan.targetCall.data]]));
  const schedule = ci.executor.decodeFunctionData("scheduleGovernanceBatch", batch.scheduleCall.data);
  assert.equal(schedule.actionClass, 2n);
  assert.equal(schedule.scopeHash, batch.scopeHash);
  assert.equal(batch.executionCall.data, ci.executor.encodeFunctionData("executeGovernanceBatch", [batch.actionId, batch.calls, batch.callDatas]));
  assert.notEqual(f.scopedPolicyFinalityV2GovernanceBatch(plan, 1n, batch.window).actionId, batch.actionId);
  for (const field of ["scopeHash", "oldValueHash", "newValueHash", "actionId", "publicationKey"]) {
    assert.throws(() => f.normalizeScopedPolicyFinalityV2GovernanceBatch({ ...batch, [field]: H("changed") }), /reconstruction/);
  }
});

test("original class2 schedule endpoints and uint64 headroom are exact", () => {
  const { window } = specimen();
  assert.doesNotThrow(() => f.assertScopedPolicyFinalityV2GovernanceWindow(window, 0n));
  assert.throws(() => f.assertScopedPolicyFinalityV2GovernanceWindow(window, 1n));
  assert.throws(() => f.normalizeScopedPolicyFinalityV2GovernanceWindow({ ...window, expiresAfter: window.expiresAfter - 1n }));
  assert.doesNotThrow(() => f.assertScopedPolicyFinalityV2GovernanceWindow({ ...window, expiresAfter: 365n * 86400n }, 0n));
  assert.throws(() => f.assertScopedPolicyFinalityV2GovernanceWindow({ ...window, expiresAfter: 365n * 86400n + 1n }, 0n));
  assert.throws(() => f.assertScopedPolicyFinalityV2GovernanceWindow(window, (1n << 64n) - 365n * 86400n));
  assert.throws(() => f.normalizeScopedPolicyFinalityV2GovernanceWindow({ ...window, expiresAfter: 1n << 64n }));
});

test("all four wallet stages are CALL0 and direct Registry finalization remains unavailable", () => {
  const { input, batch } = specimen();
  const requests = [{ kind: "stageFinalityManifest", manifestBytes: input.manifestBytes }, ...["publishGovernanceCallData", "scheduleGovernanceBatch", "executeGovernanceBatch"].map(kind => ({ kind, batch }))];
  for (const request of requests) {
    const prepared = f.prepareScopedPolicyFinalityV2Call(C, A(80), request);
    assert.equal(prepared.call.value, 0n); assert.equal(prepared.caller, A(80)); assert.equal(prepared.factsVerified, false);
    assert.equal(prepared.call.to, request.kind === "stageFinalityManifest" ? C.registry : C.executor);
    assert.deepEqual(f.normalizeScopedPolicyFinalityV2Call(prepared), prepared);
    assert.throws(() => f.normalizeScopedPolicyFinalityV2Call({ ...prepared, call: { ...prepared.call, value: 1n } }));
    assert.throws(() => f.normalizeScopedPolicyFinalityV2Call({ ...prepared, call: { ...prepared.call, extra: undefined } }));
  }
  for (const kind of ["finalizeArtworkScopeWithArchive", "scheduleArtworkTerminalFreeze", "raiseGasParameter", "finalizeCollectionArtwork"]) {
    assert.throws(() => f.prepareScopedPolicyFinalityV2Call(C, A(80), { kind, batch }));
  }
});

test("reads preserve original Registry-only provider contexts and unknown historical keys", () => {
  const { plan } = specimen();
  const prepared = { host: "provider", kind: "requirePreparedFinalityScopeInputsAndReview", plan };
  assert.throws(() => f.prepareScopedPolicyFinalityV2Read(C, T, A(500), prepared), /Registry caller/);
  const original = f.prepareScopedPolicyFinalityV2Read(C, T, C.registry, prepared);
  assert.equal(original.callerBoundary, "registry-only-read");
  assert.equal(original.call.data, ci.provider.encodeFunctionData(prepared.kind, [plan.scope, plan.manifest.contentHash, plan.components]));
  const history = f.prepareScopedPolicyFinalityV2Read(C, T, ZeroAddress, { host: "registry", kind: "finalityManifestStored", hash: ZeroHash });
  assert.equal(history.callerBoundary, "public-read");
  assert.equal(history.call.data, ci.finality.encodeFunctionData("finalityManifestStored", [ZeroHash]));
  assert.deepEqual(f.normalizeScopedPolicyFinalityV2Read(history), history);
  assert.throws(() => f.prepareScopedPolicyFinalityV2Read(C, T, ZeroAddress, { host: "provider", kind: "finalitySourceProfile", index: 3n }));
  assert.throws(() => f.prepareScopedPolicyFinalityV2Read(C, T, ZeroAddress, { host: "provider", kind: "stageFinalityManifest", manifestBytes: "0x" }));
  assert.throws(() => f.prepareScopedPolicyFinalityV2Read(C, T, ZeroAddress, { host: "registry", kind: "artworkTerminalFreezeAction", scope: plan.scope }));
});

test("prepared copies are detached and complete calldata, not only strings, enforces allocation bounds", () => {
  const { input } = specimen();
  const copy = clone(input), prepared = f.prepareScopedPolicyFinalityV2Finalization(C, copy);
  copy.proof.sanctionRecordHash = H("mutation"); copy.components[0].dataHash = H("mutation");
  assert.deepEqual(f.normalizeScopedPolicyFinalityV2Finalization(prepared), prepared);
  assert.ok(Object.isFrozen(prepared.components[0]));
  const baseBytes = (prepared.targetCall.data.length - 2) / 2;
  const limit = Math.floor((f.SCOPED_POLICY_FINALITY_V2_REGISTRY_MAX_BYTES - baseBytes) / 32) * 32;
  const edge = f.prepareScopedPolicyFinalityV2Finalization(C, { ...input, manifestURI: "x".repeat(limit) });
  assert.deepEqual(f.normalizeScopedPolicyFinalityV2Finalization(edge), edge);
  assert.throws(() => f.prepareScopedPolicyFinalityV2Finalization(C, { ...input, manifestURI: "x".repeat(limit + 1) }), /bound/);
  assert.throws(() => f.prepareScopedPolicyFinalityV2Finalization(C, { ...input, manifestURI: "\ud800" }), /UTF8/);
  const unicode = f.prepareScopedPolicyFinalityV2Finalization(C, { ...input, manifestURI: "ipfs://δοκιμή/作品" });
  assert.equal(unicode.manifest.uriHash, keccak256(toUtf8Bytes(unicode.manifest.uri)));
});
