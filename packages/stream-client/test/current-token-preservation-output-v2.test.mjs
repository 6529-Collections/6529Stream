import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import * as p from "../dist/current-token-preservation-output-v2.js";
import { toSafeCall } from "../dist/safe.js";
import { fixture, compiledInterfaces as ci } from "./current-preservation-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash;
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = n => id(String(n));
const cp = ci.StreamPreservationPolicyContentCheckpointV2;
const scoped = ci.StreamScopedPreservationPolicyContentCheckpointV2;
const output = ci.StreamPreservationPolicyOutputManifestV2;
const reg = ci.IStreamPreservationRegistryV1;
const select = ci.IStreamStaticSelectionCheckpoint;
const C = { chainId: 1n, core: A(1), metadataRouter: A(2), checkpoint: A(3), output: A(4), scopeKind: "collection" };
const ctor = cp.getFunction("outputAt").outputs[0];
const T = {
  ContentPlan: cp.getFunction("checkpoint").outputs[0], Output: ctor,
  Manifest: output.getFunction("manifestRecord").outputs[0], OutputPlan: output.getFunction("manifestPlan").outputs[0],
  Payload: cp.getFunction("append").inputs[1].arrayChildren,
  SelectionPlan: select.getFunction("checkpoint").outputs[0], TokenSelection: select.getFunction("selectionAt").outputs[0],
  Binding: ctor.components.find(c => c.name === "preservation"), Admission: ctor.components.find(c => c.name === "preservationAdmission"),
  Leaf: ctor.components.find(c => c.name === "leaf"), TokenReadiness: ctor.components.find(c => c.name === "entropy"),
  RegistryBinding: reg.getFunction("requirePreservation").outputs[0], RegistryRecord: reg.getFunction("preservationRecord").outputs[0],
  RegistryRead: reg.getFunction("preservationReads").outputs[0].arrayChildren,
  RegistryRegistration: reg.getFunction("registerPreservation").inputs[0],
  Coverage: ci.IStreamFinalityArtifactCoverage.getFunction("requireArtifactCoverage").outputs[0],
};
T.Scope = T.SelectionPlan.components[0];
T.RendererSelection = T.TokenSelection.components.find(c => c.name === "selection");
const terminalABI = Object.values(fixture.abis).flat().find(f => f.type === "function" && f.name === "requireTerminalRenderReady");
T.TerminalEvidence = ParamType.from(terminalABI.outputs[0]);
const hash = (types, values) => keccak256(coder.encode(types, values));
const family = id("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
const original = id("6529STREAM_PRESERVATION_RENDER_V1"), current = id("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1");
const copy = structuredClone;
function zero(t) {
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(c => [c.name, zero(c)]));
  if (t.baseType === "array") return Array.from({ length: t.arrayLength === -1 ? 0 : t.arrayLength }, () => zero(t.arrayChildren));
  if (t.type.startsWith("uint")) return 0n;
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  return t.type === "bytes" ? "0x" : `0x${"00".repeat(Number(t.type.slice(5)))}`;
}
const collection = { scopeType: 0n, collectionId: 12n, tokenId: 0n, scopeId: Z };
function row(tokenId = 1n, profile = original) {
  const entropy = { coordinator: A(20), coordinatorCodeHash: H(20), policyHash: H(21), status: 5n, mode: 2n,
    securityClass: 0n, renderRequirement: 0n, terminal: false, finalized: true, seed: Z };
  const preservation = { producer: A(profile === original ? 30 : 31), producerCodeHash: H(profile), profile, core: C.core,
    metadataRouter: C.metadataRouter, liveRenderer: A(32), liveRendererCodeHash: H(32), attribution: A(33), attributionCodeHash: H(33) };
  const admission = { registry: A(40), registryCodeHash: H(40), versionKey: H(41), registrationHash: H(42), readSetHash: H(43), analysisHash: H(44), goldenHash: H(45) };
  const selection = { tokenId, configRecordHash: H("config record"), configHash: H("config"), sourceSnapshotHash: H("snapshot"), rawSourceHash: H("raw"),
    selection: { ...zero(T.RendererSelection), registry: admission.registry, registryCodeHash: admission.registryCodeHash, versionKey: admission.versionKey,
      renderer: preservation.liveRenderer, rendererCodeHash: preservation.liveRendererCodeHash },
    sources: [C.core, C.metadataRouter, A(50), entropy.coordinator, A(51), A(52)], sourceCodeHashes: [H(1), H(2), H(50), entropy.coordinatorCodeHash, H(51), H(52)] };
  const leaf = { tokenId, metadataHash: H(`json${tokenId}`), imageHash: Z, animationHash: H(`html${tokenId}`), contentHash: Z, tokenDataHash: H(`data${tokenId}`) };
  return { output: { leaf, selectionRowHash: H(`selection${tokenId}`), sourceFactsHash: H(`source${tokenId}`), htmlHash: leaf.animationHash,
    entropy, terminalAdmissionHash: Z, preservation, preservationAdmission: admission }, selection };
}
function leafHash(value) {
  return hash(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    ["0x61d75cd1a57d24657b860f99f77c15e5f8556fb725b56a96dd770205f9352b0d", C.chainId, C.core, ...Object.values(value)]);
}
function node(a, b) { return hash(["bytes32", "bytes32", "bytes32"], ["0x7239fc0713b7ccc92b7eef3087150a1f32037aff6ab05f5bf78db4f8ab71a6ea", a, b]); }
function tree(rows) {
  let level = rows.map(r => leafHash(r.leaf));
  while (level.length > 1) { const next = []; for (let i = 0; i < level.length; i += 2) next.push(i + 1 < level.length ? node(level[i], level[i + 1]) : level[i]); level = next; }
  return level[0];
}
function example(count = 3, scope = collection) {
  const rows = Array.from({ length: count }, (_, i) => row(BigInt(i + 1), i % 2 ? current : original).output);
  const selected = { scope, membershipHash: H(60), collectionStateHash: H(61), tokenCount: BigInt(count), nextIndex: BigInt(count), selectionRoot: H(62) };
  const identity = { selectionCheckpoint: A(63), selectionId: H(63), selection: selected, entropySourceSet: A(64), entropySourceSetCodeHash: H(64),
    terminalReadiness: A(65), terminalReadinessCodeHash: H(65), inventoryHash: H(66), policyChainHash: H(67), salt: Z };
  let leafChainHash = Z, outputRoot = Z;
  rows.forEach((r, i) => {
    leafChainHash = hash(["bytes32", "bytes32", "uint256", "bytes32"], [id("6529STREAM_PRESERVATION_POLICY_CONTENT_LEAVES_V1"), leafChainHash, BigInt(i), leafHash(r.leaf)]);
    outputRoot = hash(["bytes32", "bytes32", "uint256", T.Output], [id("6529STREAM_PRESERVATION_POLICY_OUTPUTS_V1"), outputRoot, BigInt(i), r]);
  });
  const content = { selectionId: identity.selectionId, selectionHash: hash([T.SelectionPlan], [selected]), inventoryHash: identity.inventoryHash,
    policyChainHash: identity.policyChainHash, scope, tokenCount: BigInt(count), nextIndex: BigInt(count), leafChainHash, contentRoot: tree(rows), outputRoot, preservationProfile: family };
  return { rows, selected, identity, content, checkpointHash: H(70) };
}
const canonicalTypes = ["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "address", "bytes32", "bytes32", "address", "bytes32", T.Scope, "bytes32", "bytes32", "uint64", `${T.Output.format("full")}[]`];
function canonical(c, f) {
  return coder.encode(canonicalTypes, [id("STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2"), c.chainId, c.core, c.checkpoint, f.checkpointHash,
    hash([T.ContentPlan], [f.content]), f.identity.entropySourceSet, f.content.inventoryHash, f.content.policyChainHash, c.metadataRouter,
    family, f.content.scope, f.content.contentRoot, f.content.outputRoot, f.content.tokenCount, f.rows]);
}
function covered(f, c = C) {
  const raw = canonical(c, f);
  return { completionHash: H(80), artifactHash: H(81), artistId: H(82), schemaId: id("STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2"),
    canonicalizationId: id("STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2"), contentHash: keccak256(raw), byteLength: BigInt((raw.length - 2) / 2),
    chunkCount: BigInt(Math.ceil(((raw.length - 2) / 2) / 8192)), firstFamilyRecordHash: H(83), secondFamilyRecordHash: H(84), validationEpoch: 1n, evidenceChainHash: H(85) };
}

test("original compiler tuples preserve names, widths, fixed arrays and structural zero values", () => {
  const shape = t => ({ type: t.format("sighash"), fields: t.components?.map(c => ({ name: c.name, ...shape(c) })), child: t.arrayChildren ? shape(t.arrayChildren) : undefined });
  for (const [name, type] of Object.entries(T)) {
    const key = `TOKEN_PRESERVATION_OUTPUT_V2_${name.replace(/([a-z])([A-Z])/g, "$1_$2").toUpperCase()}_TUPLE`;
    assert.deepEqual(shape(ParamType.from(p[key])), shape(type), name);
    const value = zero(type), raw = coder.encode([type], [value]);
    assert.equal(p[`encodeTokenPreservationOutputV2${name}`](value), raw);
    assert.deepEqual(p[`decodeTokenPreservationOutputV2${name}`](raw), value);
    assert.throws(() => p[`decodeTokenPreservationOutputV2${name}`](`${raw}${"00".repeat(32)}`), /canonical/);
  }
  assert.equal((p.encodeTokenPreservationOutputV2ContentPlan(zero(T.ContentPlan)).length - 2) / 2, 448);
  assert.equal((p.encodeTokenPreservationOutputV2Output(zero(T.Output)).length - 2) / 2, 1152);
  assert.equal((p.encodeTokenPreservationOutputV2Manifest(zero(T.Manifest)).length - 2) / 2, 608);
});

test("all public fragments match genuine hosts and expose only the four operational mutations", () => {
  for (const [kind, originals] of [["checkpoint", [cp, scoped]], ["output", [output]], ["producer", [ci.IStreamPreservationRendererV1]], ["registry", [reg]]]) {
    const own = p.tokenPreservationOutputV2Interface(kind);
    for (const f of own.fragments) for (const original of originals) {
      const witness = f.type === "function" ? original.getFunction(f.format("sighash")) : original.getEvent(f.format("sighash"));
      assert.ok(witness, f.name);
      if (f.type === "function") { assert.equal(f.selector, witness.selector); assert.equal(f.stateMutability, witness.stateMutability); assert.deepEqual(f.outputs.map(o => o.format("sighash")), witness.outputs.map(o => o.format("sighash"))); }
      else { assert.equal(f.topicHash, witness.topicHash); assert.deepEqual(f.inputs.map(v => Boolean(v.indexed)), witness.inputs.map(v => Boolean(v.indexed))); }
    }
    assert.equal(own.getFunction("raiseGasParameter"), null);
    assert.equal(own.getFunction("registerPreservation"), null);
  }
  const names = ["checkpoint", "output"].flatMap(k => p.tokenPreservationOutputV2Interface(k).fragments.filter(f => f.type === "function" && f.stateMutability === "nonpayable").map(f => f.name));
  assert.deepEqual(names, ["begin", "append", "beginManifest", "verifyNextOutputs"]);
  const source = fixture.sourceTexts["smart-contracts/domains/finality/StreamPreservationPolicyContentCheckpointBaseV1.sol"];
  assert.match(source, /emit StaticContentStarted\(1,/);
  assert.match(source, /emit StaticContentAppended\(1,/);
  assert.match(fixture.sourceTexts["smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestBase.sol"], /return _familyV2 \? 2 : 1/);
});

test("three exact frozen Solidity definitions preserve V2 schema and original leaf interpretation", () => {
  const source = fixture.sourceTexts["smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV2.sol"];
  const docs = [...source.matchAll(/return bytes\(\s*'((?:[^'\\]|\\.)*)'\s*\)/g)].map(m => m[1].replaceAll("\\'", "'"));
  assert.equal(docs.length, 3);
  for (const [i, name] of ["SCHEMA", "CANONICALIZATION", "LEAF_SCHEMA"].entries()) {
    const actual = p.tokenPreservationOutputV2Definition(p[`TOKEN_PRESERVATION_OUTPUT_V2_${name}`]);
    assert.equal(actual, `0x${Buffer.from(docs[i]).toString("hex")}`);
    assert.equal(keccak256(actual), p[`TOKEN_PRESERVATION_OUTPUT_V2_${name}_HASH`]);
    assert.equal(BigInt((actual.length - 2) / 2), p[`TOKEN_PRESERVATION_OUTPUT_V2_${name}_BYTES`]);
    assert.ok(!docs[i].endsWith("\n"));
  }
  assert.throws(() => p.tokenPreservationOutputV2Definition(H("unknown")));
});

test("closed scope and producer family admission remain separate from raw codecs", () => {
  for (const scope of [collection, { ...collection, scopeType: 1n, tokenId: 4n }, { ...collection, scopeType: 2n, scopeId: H(4) }, { ...collection, scopeType: 3n, scopeId: H(5) }]) {
    const kind = scope.scopeType === 0n ? "collection" : "scoped";
    assert.deepEqual(p.validateTokenPreservationOutputV2Scope(kind, scope), scope);
    assert.throws(() => p.validateTokenPreservationOutputV2Scope(kind === "collection" ? "scoped" : "collection", scope));
  }
  assert.doesNotThrow(() => p.normalizeTokenPreservationOutputV2Scope(zero(T.Scope)));
  for (const value of [{ ...collection, scopeType: 4n }, { ...collection, tokenId: 1n }, { ...collection, collectionId: 0n }]) assert.throws(() => p.validateTokenPreservationOutputV2Scope("collection", value));
  for (const profile of [original, current]) assert.doesNotThrow(() => p.validateTokenPreservationOutputV2Binding(row(1n, profile).output.preservation));
  for (const profile of [family, id("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1"), Z]) assert.throws(() => p.validateTokenPreservationOutputV2Binding(row(1n, profile).output.preservation));
});

test("producer and Registry preimages and exact512 return retain distinct field spellings", () => {
  const { output: o, selection } = row(), b = o.preservation, a = o.preservationAdmission;
  const rb = { producer: b.producer, producerCodeHash: b.producerCodeHash, profile: b.profile, core: b.core, router: b.metadataRouter,
    liveRenderer: b.liveRenderer, liveRendererCodeHash: b.liveRendererCodeHash, attribution: b.attribution, attributionCodeHash: b.attributionCodeHash };
  assert.equal(p.tokenPreservationOutputV2BindingHash(b), hash(["bytes32", T.Binding], [id("6529STREAM_PRESERVATION_OUTPUT_BINDING_V1"), b]));
  assert.equal(p.tokenPreservationOutputV2RegistryKey(a.versionKey, b.producer, b.profile), hash(["bytes32", "bytes32", "address", "bytes32"], [id("6529STREAM_PRESERVATION_KEY_V1"), a.versionKey, b.producer, b.profile]));
  const raw = reg.encodeFunctionResult("requirePreservation", [rb, a]);
  assert.equal(p.encodeTokenPreservationOutputV2RegistryAdmission(rb, a), raw);
  assert.deepEqual(p.decodeTokenPreservationOutputV2RegistryAdmission(raw), { binding: rb, admission: a });
  assert.equal(p.validateTokenPreservationOutputV2Admission(b, a, selection, rb).factsVerified, false);
  for (const mutate of [v => v.registry = A(999), v => v.registryCodeHash = H(999), v => v.versionKey = H(999), v => v.goldenHash = Z]) {
    const altered = copy(a); mutate(altered); assert.throws(() => p.validateTokenPreservationOutputV2Admission(b, altered, selection, rb));
  }
  assert.throws(() => p.validateTokenPreservationOutputV2Admission(b, a, selection, { ...rb, producer: A(999) }));
  assert.throws(() => p.decodeTokenPreservationOutputV2RegistryAdmission(`${raw}00`));
  assert.throws(() => p.normalizeTokenPreservationOutputV2RegistryBinding(b));
  const reads = [{ targetIndex: 65535n, selector: "0x12345678", maxReturnBytes: (1n << 32n) - 1n, exact: false }];
  assert.equal(p.encodeTokenPreservationOutputV2RegistryReads(reads), reg.encodeFunctionResult("preservationReads", [reads]));
  assert.deepEqual(p.decodeTokenPreservationOutputV2RegistryReads(p.encodeTokenPreservationOutputV2RegistryReads(reads)), reads);
  assert.equal(p.tokenPreservationOutputV2RegistryReadSetHash(H(100), reads), hash(["bytes32", "bytes32", reg.getFunction("preservationReads").outputs[0]], [id("6529STREAM_RENDERER_READ_SET_V1"), H(100), reads]));
  assert.throws(() => p.encodeTokenPreservationOutputV2RegistryReads(Array(129).fill(reads[0])));
});

test("checkpoint identity includes fixed family while initial plans preserve uint64 and retry progress distinction", () => {
  const f = example(), i = f.identity;
  const expected = hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "address", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2"), C.chainId, C.checkpoint, i.selectionCheckpoint, i.selectionId, hash([T.SelectionPlan], [i.selection]),
      i.entropySourceSet, i.entropySourceSetCodeHash, i.terminalReadiness, i.terminalReadinessCodeHash, i.inventoryHash, i.policyChainHash, family, i.salt]);
  assert.equal(p.tokenPreservationOutputV2CheckpointId(C, i), expected);
  assert.notEqual(p.tokenPreservationOutputV2CheckpointId({ ...C, scopeKind: "scoped" }, i), expected);
  for (const key of ["selectionId", "entropySourceSetCodeHash", "terminalReadinessCodeHash", "inventoryHash", "policyChainHash", "salt"]) assert.notEqual(p.tokenPreservationOutputV2CheckpointId(C, { ...i, [key]: H(999) }), expected);
  const initial = p.tokenPreservationOutputV2InitialContentPlan("collection", i);
  assert.equal(initial.nextIndex, 0n); assert.equal(initial.preservationProfile, family);
  assert.notDeepEqual(initial, f.content);
  const maximum = (1n << 64n) - 1n;
  assert.equal(p.tokenPreservationOutputV2InitialContentPlan("collection", { ...i, selection: { ...i.selection, tokenCount: maximum, nextIndex: maximum } }).tokenCount, maximum);
  assert.throws(() => p.tokenPreservationOutputV2InitialContentPlan("collection", { ...i, selection: { ...i.selection, nextIndex: 1n } }));
});

test("source facts use dynamic320-byte entropy and commit actual producer plus Registry admission", () => {
  const f = example(), o = f.rows[0];
  const facts = { preservation: o.preservation, admission: o.preservationAdmission, configHash: H(90), rawSourceHash: H(91), coordinator: o.entropy.coordinator,
    entropy: o.entropy, entropySourceSet: f.identity.entropySourceSet, entropySourceSetCodeHash: f.identity.entropySourceSetCodeHash, inventoryHash: f.identity.inventoryHash,
    policyChainHash: f.identity.policyChainHash, terminalReadiness: f.identity.terminalReadiness, terminalReadinessCodeHash: f.identity.terminalReadinessCodeHash, terminalAdmissionHash: Z };
  const expected = hash(["bytes32", "bytes32", T.Binding, T.Admission, "bytes32", "bytes32", "address", "bytes", "address", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32"],
    [id("6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2"), family, facts.preservation, facts.admission, facts.configHash, facts.rawSourceHash, facts.coordinator,
      coder.encode([T.TokenReadiness], [facts.entropy]), facts.entropySourceSet, facts.entropySourceSetCodeHash, facts.inventoryHash, facts.policyChainHash,
      facts.terminalReadiness, facts.terminalReadinessCodeHash, facts.terminalAdmissionHash]);
  assert.equal(p.tokenPreservationOutputV2SourceFactsHash("collection", facts), expected);
  assert.notEqual(p.tokenPreservationOutputV2SourceFactsHash("scoped", facts), expected);
  assert.notEqual(p.tokenPreservationOutputV2SourceFactsHash("collection", { ...facts, admission: { ...facts.admission, analysisHash: H(999) } }), expected);
  assert.notEqual(p.tokenPreservationOutputV2SourceFactsHash("collection", { ...facts, preservation: { ...facts.preservation, profile: current } }), expected);
  assert.equal(p.tokenPreservationOutputV2SelectionRowHash(C.chainId, C.core, C.metadataRouter, row().selection), hash(["bytes32", "uint256", "address", "address", T.TokenSelection], [id("6529STREAM_STATIC_SELECTION_ROW_V1"), C.chainId, C.core, C.metadataRouter, row().selection]));
});

test("terminal branches preserve zero seed and finalized status5 allows zero native seed", () => {
  const o = row().output;
  assert.doesNotThrow(() => p.validateTokenPreservationOutputV2Output(o));
  for (const [status, mode] of [[1n, 0n], [2n, 2n]]) {
    const terminal = { ...o, entropy: { ...o.entropy, terminal: true, finalized: false, renderRequirement: 1n, status, mode }, terminalAdmissionHash: H(99) };
    assert.doesNotThrow(() => p.validateTokenPreservationOutputV2Output(terminal));
    assert.throws(() => p.validateTokenPreservationOutputV2Output({ ...terminal, entropy: { ...terminal.entropy, seed: H(99) } }));
    assert.throws(() => p.validateTokenPreservationOutputV2Output({ ...terminal, terminalAdmissionHash: Z }));
  }
  for (const mutate of [x => x.entropy.status = 4n, x => x.entropy.finalized = false, x => x.leaf.contentHash = H(99), x => x.htmlHash = H(99), x => x.terminalAdmissionHash = H(99)]) {
    const value = copy(o); mutate(value); assert.throws(() => p.validateTokenPreservationOutputV2Output(value));
  }
});

test("original ordered tree and rolling V1 chains preserve odd nodes and all row evidence", () => {
  const f = example(5);
  assert.equal(p.tokenPreservationOutputV2ContentRoot(C.chainId, C.core, f.rows.map(r => r.leaf)), tree(f.rows));
  assert.equal(p.tokenPreservationOutputV2LeafHash(C.chainId, C.core, f.rows[0].leaf), leafHash(f.rows[0].leaf));
  assert.equal(p.tokenPreservationOutputV2NodeHash(H(1), H(2)), node(H(1), H(2)));
  let l = Z, o = Z;
  f.rows.forEach((r, i) => { l = p.tokenPreservationOutputV2LeafChain(l, BigInt(i), leafHash(r.leaf)); o = p.tokenPreservationOutputV2OutputChain(o, BigInt(i), r); });
  assert.equal(l, f.content.leafChainHash); assert.equal(o, f.content.outputRoot);
  assert.throws(() => p.tokenPreservationOutputV2ContentRoot(C.chainId, C.core, f.rows.map(r => r.leaf).reverse()));
  assert.throws(() => p.tokenPreservationOutputV2ContentRoot(C.chainId, C.core, [f.rows[0].leaf, f.rows[0].leaf]));
  assert.notEqual(p.tokenPreservationOutputV2OutputChain(Z, 0n, { ...f.rows[0], preservationAdmission: { ...f.rows[0].preservationAdmission, goldenHash: H(999) } }), p.tokenPreservationOutputV2OutputChain(Z, 0n, f.rows[0]));
});

test("canonical manifest has exact608 offset640 header and1152 rows with mixed admitted profiles", () => {
  const f = example(), raw = p.tokenPreservationOutputV2ManifestBytes(C, f.checkpointHash, f.content, f.identity.entropySourceSet, f.rows);
  assert.equal(raw, canonical(C, f));
  assert.equal((raw.length - 2) / 2, 640 + 1152 * 3);
  assert.equal(BigInt(`0x${raw.slice(2 + 18 * 64, 2 + 19 * 64)}`), 608n);
  const d = p.decodeTokenPreservationOutputV2ManifestBytes(raw);
  assert.equal(d.rows[1].preservation.profile, current);
  assert.ok(Object.isFrozen(d.rows[1].preservation));
  assert.throws(() => p.decodeTokenPreservationOutputV2ManifestBytes(`${raw}00`));
  const wrongOffset = `${raw.slice(0, 2 + 18 * 64)}${(640n).toString(16).padStart(64, "0")}${raw.slice(2 + 19 * 64)}`;
  assert.throws(() => p.decodeTokenPreservationOutputV2ManifestBytes(wrongOffset));
  for (const mutate of [x => x.rows[0].preservation.profile = family, x => x.rows[0].preservation.core = A(999), x => x.rows.reverse(), x => x.content.outputRoot = H(999)]) {
    const x = copy(f); mutate(x); assert.throws(() => p.tokenPreservationOutputV2ManifestBytes(C, x.checkpointHash, x.content, x.identity.entropySourceSet, x.rows));
    assert.throws(() => p.decodeTokenPreservationOutputV2ManifestBytes(canonical(C, x)));
  }
  const one = example(1, { ...collection, scopeType: 1n, tokenId: 1n }), sc = { ...C, scopeKind: "scoped" };
  assert.equal(p.tokenPreservationOutputV2ManifestBytes(sc, one.checkpointHash, one.content, one.identity.entropySourceSet, one.rows), canonical(sc, one));
  // Recompute the full checkpoint state hash from a self-consistent wrong TOKEN scope.
  // Every leaf/root and producer admission remains unchanged, so only exact membership can reject it.
  const wrongToken = copy(one);
  wrongToken.content.scope.tokenId = 2n;
  assert.throws(() => p.tokenPreservationOutputV2ManifestBytes(sc, wrongToken.checkpointHash, wrongToken.content, wrongToken.identity.entropySourceSet, wrongToken.rows), /TOKEN manifest member/);
  assert.throws(() => p.decodeTokenPreservationOutputV2ManifestBytes(canonical(sc, wrongToken)), /TOKEN manifest member/);
});

test("actual covered manifest bound admits454 rows and refuses455 without restricting raw uint64 plans", () => {
  const f = example(454), raw = p.tokenPreservationOutputV2ManifestBytes(C, f.checkpointHash, f.content, f.identity.entropySourceSet, f.rows);
  assert.equal((raw.length - 2) / 2, 523648);
  assert.equal(p.decodeTokenPreservationOutputV2ManifestBytes(raw).rows.length, 454);
  assert.throws(() => p.tokenPreservationOutputV2ManifestBytes(C, f.checkpointHash, { ...f.content, tokenCount: 455n, nextIndex: 455n }, f.identity.entropySourceSet, [...f.rows, row(455n).output]));
});

test("covered source fields and original plan/record history hashes reject rehashed nonfamily scope substitution", () => {
  const f = example(), coverage = covered(f), m = p.tokenPreservationOutputV2Manifest(C, f.checkpointHash, f.content, f.identity.entropySourceSet, coverage);
  assert.equal(m.manifestHash, keccak256(canonical(C, f)));
  const planHash = hash(["bytes32", "uint256", "address", "address", "address", "address", T.Manifest], [id("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_PLAN_V2"), C.chainId, C.output, C.core, C.checkpoint, A(90), m]);
  assert.equal(p.tokenPreservationOutputV2ManifestPlanHash(C, A(90), m), planHash);
  const recordHash = hash(["bytes32", "bytes32"], [id("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V2"), planHash]);
  assert.equal(p.tokenPreservationOutputV2RecordHash(planHash), recordHash);
  const plan = { manifest: m, nextIndex: m.tokenCount, recordHash };
  assert.equal(p.authenticateTokenPreservationOutputV2History(C, A(90), planHash, plan).currentnessChecked, false);
  assert.throws(() => p.authenticateTokenPreservationOutputV2History(C, A(91), planHash, plan));
  const bad = { ...m, preservationProfile: original }, changed = p.tokenPreservationOutputV2ManifestPlanHash(C, A(90), bad);
  assert.throws(() => p.authenticateTokenPreservationOutputV2History(C, A(90), changed, { ...plan, manifest: bad, recordHash: p.tokenPreservationOutputV2RecordHash(changed) }), /history/);
  for (const mutate of [c => c.schemaId = H(99), c => c.canonicalizationId = H(99), c => c.byteLength++, c => c.chunkCount++, c => c.secondFamilyRecordHash = c.firstFamilyRecordHash]) {
    const value = copy(coverage); mutate(value); assert.throws(() => p.tokenPreservationOutputV2Manifest(C, f.checkpointHash, f.content, f.identity.entropySourceSet, value));
  }
});

test("four operational calls and real read targets reconstruct exactly without lock/gas/register mutations", () => {
  const payload = { tokenId: 1n, producer: A(30), image: "0x", animation: "0x0102" };
  const requests = [{ kind: "begin", selectionId: H(1), salt: Z }, { kind: "append", id: H(2), payloads: [payload] },
    { kind: "beginManifest", checkpointHash: H(3), artifactHash: H(4), coverageHash: H(5), artistId: H(6) }, { kind: "verifyNextOutputs", planHash: H(7), count: 16n }];
  for (const request of requests) {
    const call = p.prepareTokenPreservationOutputV2Call(C, A(99), request), original = request.kind === "begin" || request.kind === "append" ? cp : output;
    assert.equal(call.call.data, original.encodeFunctionData(request.kind, Object.values(request).slice(1)));
    assert.equal(call.call.value, 0n); assert.equal(call.factsVerified, false); assert.deepEqual(p.normalizeTokenPreservationOutputV2Call(call), call);
    for (const mutate of [v => v.call.to = A(998), v => v.call.value = 1n, v => v.call.data += "00", v => v.factsVerified = true]) {
      const v = copy(call); mutate(v); assert.throws(() => p.normalizeTokenPreservationOutputV2Call(v));
    }
  }
  for (const kind of ["lockSnapshot", "raiseGasParameter", "registerPreservation", "publishReference"]) assert.throws(() => p.prepareTokenPreservationOutputV2Call(C, A(99), { kind }));
  const reads = [{ host: "checkpoint", kind: "checkpoint", id: Z }, { host: "checkpoint", kind: "outputAt", id: H(2), index: 0n },
    { host: "output", kind: "manifestRecord", recordHash: H(2) }, { host: "output", kind: "requireCurrentManifest", recordHash: H(2), artistId: H(3) },
    { host: "producer", kind: "preservationBinding", target: A(30) }, { host: "producer", kind: "preservationTokenJSON", target: A(30), tokenId: 1n },
    { host: "registry", kind: "preservationReads", target: A(40), key: H(4) }, { host: "registry", kind: "requirePreservation", target: A(40), versionKey: H(4), producer: A(30), profile: original }];
  for (const request of reads) { const r = p.prepareTokenPreservationOutputV2Read(C, request); assert.deepEqual(p.normalizeTokenPreservationOutputV2Read(r), r); }
  assert.throws(() => p.prepareTokenPreservationOutputV2Read(C, { host: "registry", kind: "registerPreservation", target: A(40) }));
  assert.throws(() => p.prepareTokenPreservationOutputV2Read(C, { host: "producer", kind: "preservationBinding", target: A(30), tokenId: 1n }));
});

test("strict exact shapes, dense arrays, widths and detached mutation preserve source snapshots", () => {
  const f = row();
  for (const mutate of [v => delete v.sources[1], v => v.sources.extra = 1, v => v.sources[Symbol()] = 1,
    v => Object.defineProperty(v.sources, "hidden", { value: 1 }), v => v.tokenId = 1, v => v.extra = 1]) {
    const v = copy(f.selection); mutate(v); assert.throws(() => p.normalizeTokenPreservationOutputV2TokenSelection(v));
  }
  assert.throws(() => p.normalizeTokenPreservationOutputV2ContentPlan({ ...example().content, tokenCount: 1n << 64n }));
  assert.throws(() => p.normalizeTokenPreservationOutputV2TokenReadiness({ ...f.output.entropy, status: 256n }));
  assert.throws(() => p.normalizeTokenPreservationOutputV2Scope({ ...collection, scopeType: 5n }));
  const raw = p.encodeTokenPreservationOutputV2TokenReadiness(f.output.entropy), dirty = `${raw.slice(0, 2 + 7 * 64)}${"2".padStart(64, "0")}${raw.slice(2 + 8 * 64)}`;
  assert.throws(() => p.decodeTokenPreservationOutputV2TokenReadiness(dirty), /canonical/);
  const input = { kind: "append", id: H(1), payloads: [{ tokenId: 1n, producer: A(30), image: "0x", animation: "0x01" }] };
  const prepared = p.prepareTokenPreservationOutputV2Call(C, A(99), input); input.payloads[0].producer = A(999);
  assert.equal(prepared.request.payloads[0].producer, A(30)); assert.ok(Object.isFrozen(prepared.request.payloads));
});

test("four maximum source payloads fit whole calldata and next-byte limits reject before transport", () => {
  const animation = `0x${"11".repeat(16777216)}`, image = `0x${"22".repeat(2048)}`;
  const request = { kind: "append", id: H(1), payloads: Array.from({ length: 4 }, (_, i) => ({ tokenId: BigInt(i + 1), producer: A(30), image, animation })) };
  const call = p.prepareTokenPreservationOutputV2Call(C, A(99), request);
  assert.equal((call.call.data.length - 2) / 2, 67118052);
  const safe = toSafeCall(call.call);
  assert.equal(safe.to, call.call.to);
  assert.equal(safe.data, call.call.data);
  assert.equal(safe.value, "0");
  assert.equal(safe.operation, 0);
  assert.ok((call.call.data.length - 2) / 2 < p.TOKEN_PRESERVATION_OUTPUT_V2_MAX_CALL_BYTES);
  assert.throws(() => p.normalizeTokenPreservationOutputV2Request({ ...request, payloads: [ { ...request.payloads[0], animation: `${animation}00` } ] }), /bound/);
  assert.throws(() => p.normalizeTokenPreservationOutputV2Request({ ...request, payloads: [ { ...request.payloads[0], image: `${image}00` } ] }), /bound/);
  assert.throws(() => p.normalizeTokenPreservationOutputV2Request({ ...request, payloads: Array(5).fill(request.payloads[0]) }), /array/);
  assert.throws(() => p.normalizeTokenPreservationOutputV2Request({ kind: "verifyNextOutputs", planHash: H(1), count: 17n }), /batch/);
});
