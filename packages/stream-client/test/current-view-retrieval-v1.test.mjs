import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ParamType, SigningKey, ZeroAddress, ZeroHash, computeAddress, getAddress, hashMessage, id, keccak256, sha256 } from "ethers";
import * as api from "../dist/current-view-retrieval-v1.js";
import { toSafeCall } from "../dist/safe.js";
import { compiledInterfaces } from "./current-view-retrieval-v1-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const host = compiledInterfaces.StreamViewRetrievalWitnessV1;
const external = compiledInterfaces.IStreamExternalArtifactCoverage;
const Z = ZeroHash;
const A = n => getAddress(`0x${n.toString(16).padStart(40, "0")}`);
const H = label => id(`retrieval-test:${label}`);
const c = { chainId: 1n, witness: A(10) };
const d = {
  core: A(1), coreCodeHash: H("core"), router: A(2), routerCodeHash: H("router"),
  checkpoint: A(3), checkpointCodeHash: H("checkpoint"), archive: A(4), archiveCodeHash: H("archive"),
  chainId: 1n, readGas: 50000n, sourceGas: 200000n, archiveGas: 300000n, signatureGas: 100000n,
};
const key = new SigningKey(`0x${"01".padStart(64, "0")}`);
const writer = computeAddress(key.publicKey);
const scope = { scopeType: 4n, collectionId: 9n, tokenId: 0n, scopeId: H("scope") };
const requestType = host.getFunction("prepare").inputs[0];
const observationType = host.getFunction("prepare").outputs[0];
const sourceType = observationType.components.find(x => x.name === "source");
const scopeType = sourceType.components[0];
const configurationType = host.getFunction("configuration").outputs[0];
const receiptType = host.getFunction("record").outputs[0];
const admissionType = host.getFunction("requireCurrent").outputs[1];
const archiveReceiptType = external.getFunction("receipt").outputs[0];
const familyType = external.getFunction("family").outputs[0];
const clone = value => structuredClone(value);
const own = (type, value) => {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map((p, i) => [p.name, own(p, value[i])]));
  if (type.baseType === "array") return Array.from(value, v => own(type.arrayChildren, v));
  return value;
};
const zero = type => {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(p => [p.name, zero(p)]));
  if (type.baseType === "array") return [];
  if (type.type === "address") return ZeroAddress;
  if (type.type === "string") return "";
  if (type.type === "bytes") return "0x";
  if (type.type.startsWith("bytes")) return `0x${"00".repeat(Number(type.type.slice(5)))}`;
  if (type.type === "bool") return false;
  return 0n;
};
const abiHash = (types, values) => keccak256(coder.encode(types, values));
const configurationHash = config => abiHash(["bytes32", configurationType], [id("6529STREAM_VIEW_ATTRIBUTED_RETRIEVAL_V1"), config]);
const digest = (o, coords = c, config = d) => abiHash(["bytes32", "uint256", "address", "bytes32", observationType],
  [id("6529STREAM_VIEW_RETRIEVAL_OBSERVATION_V1"), coords.chainId, coords.witness, configurationHash(config), o]);
const sourceKey = s => abiHash(["bytes32", scopeType, "address", "address", "bytes32", "bytes32", "address", "bytes32", "bytes32", "string", "bytes32", "bytes32"],
  [id("6529STREAM_VIEW_RETRIEVAL_SOURCE_V1"), s.scope, s.core, s.router, s.adoptionRecord, s.adoptionSourceHash,
    s.declaration, s.declarationRecord, s.payloadHash, s.requestedURI, s.artistId, s.artistPresentationHash]);
const archiveHash = r => abiHash(["bytes32", "uint256", "address", archiveReceiptType], [id("6529STREAM_EXTERNAL_RECEIPT_V1"), c.chainId, d.archive, r]);
function sample() {
  const source = { scope: clone(scope), core: d.core, router: d.router, adoptionRecord: H("adoption"), adoptionSourceHash: H("adoption-source"),
    declaration: A(5), declarationRecord: H("declaration"), payloadHash: H("payload"), checkpointContextHash: H("context"),
    requestedURI: "https://archive.example/image%2f?x=1#literal", artistId: H("artist"), artistPresentationHash: H("presentation") };
  const object = { artistId: source.artistId, schemaId: H("schema"), canonicalizationId: id("RAW_BYTES"), contentHash: H("image"), sha256Digest: H("sha"),
    arweaveDataRoot: H("data-root"), byteSize: 123n, formatId: H("format"), formatCatalogId: H("catalog"), formatCatalogHash: H("catalog-hash") };
  const coverage = { coverageHash: H("coverage"), objectHash: H("object"), artistId: object.artistId, contentHash: object.contentHash,
    sha256Digest: object.sha256Digest, arweaveDataRoot: object.arweaveDataRoot, byteSize: object.byteSize,
    firstFamilyRecordHash: H("family1"), secondFamilyRecordHash: H("family2"), firstReceiptHash: H("receipt1"), secondReceiptHash: H("receipt2"),
    firstFixityHash: H("fixity1"), secondFixityHash: H("fixity2"), checkpointHash: H("checkpoint-record"), profileHash: id("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1") };
  return { source, object, coverage, steps: [], resolvedURI: source.requestedURI, writer, observedAt: 20n, nonce: 0n, deadline: 40n };
}
const requestOf = o => ({ scope: o.source.scope, coverageHash: o.coverage.coverageHash, steps: o.steps,
  resolvedURI: o.resolvedURI, observedAt: o.observedAt, nonce: o.nonce, deadline: o.deadline });
const step = (kind, fromURI, toURI, status = 0n) => ({ kind, fromURI, toURI, status, manifestObject: Z, manifestCoverage: Z, manifestBytes: "0x" });
const admission = (o = sample()) => ({ proof: { backend: 1n, coverageHash: o.coverage.coverageHash, objectHash: o.coverage.objectHash },
  originalBundleHash: H("original-bundle"), immutablePartsHash: H("immutable-parts"), externalOriginal: o.coverage,
  onchainOriginal: zero(admissionType.components.find(x => x.name === "onchainOriginal")) });
const ar = byte => `ar://${Buffer.alloc(32, byte).toString("base64url")}`;
function originalReceipt(o, signature = "0x", at = 25n) {
  const payload = coder.encode([observationType, "bytes"], [o, signature]);
  const r = { recordHash: Z, sourceKey: sourceKey(o.source), observationHash: digest(o), objectHash: o.coverage.objectHash,
    coverageHash: o.coverage.coverageHash, writer: o.writer, recordedAt: at, payloadHash: keccak256(payload), payloadBytes: BigInt((payload.length - 2) / 2) };
  r.recordHash = abiHash(["bytes32", "uint256", "address", "bytes32", receiptType], [id("6529STREAM_VIEW_RETRIEVAL_RECORD_V1"), c.chainId, c.witness, configurationHash(d), r]);
  return { r, payload };
}
function transaction(coverage, transactionId, index = 1) {
  const receipt = { objectHash: coverage.objectHash, familyRecordHash: coverage.firstFamilyRecordHash,
    storageIdentifierHash: keccak256(transactionId), evidenceClass: H("endowed"), proofProfileHash: H("native-profile"),
    proofRecordHash: coverage.checkpointHash, writer: A(30 + index), observedAt: 10n, nonce: BigInt(index), deadline: 15n };
  coverage.firstReceiptHash = archiveHash(receipt);
  return { receipt, locator: transactionId };
}

test("original host ABI and all structural tuple codecs remain exact and separately admitted", () => {
  const iface = api.currentViewRetrievalV1Interface();
  for (const f of iface.fragments) {
    const original = f.type === "function" ? host.getFunction(f.format("sighash"))
      : f.type === "error" ? host.getError(f.format("sighash")) : host.getEvent(f.format("sighash"));
    assert.equal(f.format("full"), original.format("full"));
  }
  let interfaceId = 0n;
  compiledInterfaces.IStreamViewRetrievalWitnessV1.forEachFunction(f => { interfaceId ^= BigInt(f.selector); });
  assert.equal(api.currentViewRetrievalV1InterfaceId(), `0x${interfaceId.toString(16).padStart(8, "0")}`);
  const witnesses = {
    Scope: scopeType, Configuration: configurationType, Source: sourceType,
    Step: requestType.components[2].arrayChildren, Request: requestType,
    Object: observationType.components[1], Coverage: observationType.components[2],
    CurrentPair: compiledInterfaces.IStreamExternalArtifactCurrentPair.getFunction("currentReceiptPair").outputs[0],
    Proof: admissionType.components[0], OnchainCoverage: admissionType.components[4], Admission: admissionType,
    Observation: observationType, Receipt: receiptType, ArchiveReceipt: archiveReceiptType, Family: familyType,
  };
  for (const [name, type] of Object.entries(witnesses)) {
    const value = zero(type);
    const raw = coder.encode([type], [value]);
    assert.equal(api[`encodeCurrentViewRetrievalV1${name}`](value), raw, name);
    assert.deepEqual(api[`decodeCurrentViewRetrievalV1${name}`](raw), value, name);
    assert.throws(() => api[`decodeCurrentViewRetrievalV1${name}`](`${raw}00`), undefined, name);
  }
  assert.throws(() => api.validateCurrentViewRetrievalV1Scope(zero(scopeType)), /VIEW/);
  assert.throws(() => api.validateCurrentViewRetrievalV1Observation(zero(observationType)), /VIEW/);
});

test("raw normalization owns all nested values and rejects sparse, surplus, narrow, malformed strings and dirty ABI", () => {
  const o = sample();
  o.steps = [step(1n, o.source.requestedURI, "https://next.example/x", 302n)];
  o.resolvedURI = o.steps[0].toURI;
  const normalized = api.normalizeCurrentViewRetrievalV1Observation(o);
  o.source.scope.scopeId = Z;
  o.steps[0].status = 999n;
  assert.equal(normalized.source.scope.scopeId, scope.scopeId);
  assert.equal(normalized.steps[0].status, 302n);
  assert(Object.isFrozen(normalized) && Object.isFrozen(normalized.steps) && Object.isFrozen(normalized.steps[0]));
  for (const bad of [new Array(1), Object.assign([], { extra: 1 }), Object.defineProperty([], "extra", { value: 1 }), Object.assign([], { [Symbol("surplus")]: 1 })]) {
    assert.throws(() => api.normalizeCurrentViewRetrievalV1Observation({ ...sample(), steps: bad }), /array/);
  }
  for (const bad of [{ ...scope, scopeType: 5n }, { ...scope, scopeType: 4 }, { ...scope, scopeType: -1n }, { ...scope, extra: 0n }]) {
    assert.throws(() => api.normalizeCurrentViewRetrievalV1Scope(bad));
  }
  assert.throws(() => api.normalizeCurrentViewRetrievalV1Step({ ...step(1n, "x", "y"), status: 65536n }), /uint16/);
  assert.throws(() => api.normalizeCurrentViewRetrievalV1Source({ ...sample().source, requestedURI: "\ud800" }));
  const raw = api.encodeCurrentViewRetrievalV1Scope(scope);
  assert.throws(() => api.decodeCurrentViewRetrievalV1Scope(`0x${"ff".repeat(31)}04${raw.slice(66)}`));
});

test("literal URI parser preserves broad HTTPS bytes and exact nonzero canonical Arweave roots", () => {
  for (const uri of ["https://A", "https://Éxample/x%20?x=1#fragment", "https://x/@a", "https://x\\path", "https://x", `${ar(1)}/nested?q=1#tag`]) {
    assert.equal(api.currentViewRetrievalV1URI(uri).kind, uri.startsWith("https") ? 1n : 3n);
  }
  const tx = api.currentViewRetrievalV1URI(ar(1));
  assert.equal(tx.kind, 2n);
  assert.equal(tx.transactionId, `0x${"01".repeat(32)}`);
  for (const uri of ["", "https://", "https:///x", "https://?x", "https://#x", "HTTPS://x", "ipfs://abc", "data:a", "https://x y", "https://x\x7f", "https://\udc00", `${ar(1)}/`, ar(0), `${ar(1)}=`, `${ar(1).slice(0, -1)}F`]) {
    assert.throws(() => api.currentViewRetrievalV1URI(uri), undefined, uri);
  }
  assert.equal(api.currentViewRetrievalV1URI(`https://x/${"a".repeat(2038)}`).kind, 1n);
  assert.throws(() => api.currentViewRetrievalV1URI(`https://x/${"a".repeat(2039)}`), /bytes/);
});

test("three original route kinds enforce order, HTTP status, manifest fields and terminal non-path", () => {
  const o = sample();
  o.source.requestedURI = "https://start.example/a";
  o.steps = [step(1n, o.source.requestedURI, "https://mirror.example/a", 301n), step(2n, "https://mirror.example/a", ar(1)),
    step(2n, ar(1), "https://final.example/a")];
  o.resolvedURI = "https://final.example/a";
  assert.deepEqual(api.validateCurrentViewRetrievalV1Observation(o), o);
  for (const mutate of [x => x.steps.reverse(), x => { x.steps[0].status = 304n; }, x => { x.steps[1].kind = 4n; },
    x => { x.steps[1].manifestObject = H("stray"); }, x => { x.steps[0].toURI = x.steps[0].fromURI; }, x => { x.resolvedURI += "/"; }]) {
    const bad = clone(o); mutate(bad); assert.throws(() => api.validateCurrentViewRetrievalV1Observation(bad));
  }
  const manifest = sample();
  manifest.source.requestedURI = `${ar(1)}/a`;
  manifest.steps = [{ ...step(3n, manifest.source.requestedURI, `${ar(2)}/b`), manifestObject: H("m1"), manifestCoverage: H("mc1"), manifestBytes: "0x01" },
    { ...step(3n, `${ar(2)}/b`, ar(3)), manifestObject: H("m2"), manifestCoverage: H("mc2"), manifestBytes: "0x02" }];
  manifest.resolvedURI = ar(3);
  assert(api.validateCurrentViewRetrievalV1Observation(manifest));
  for (const mutate of [x => { x.steps[0].toURI = "https://x"; }, x => { x.steps[0].manifestBytes = "0x"; },
    x => { x.steps[0].kind = 2n; }, x => { x.resolvedURI = `${ar(3)}/x`; x.steps[1].toURI = x.resolvedURI; }]) {
    const bad = clone(manifest); mutate(bad); assert.throws(() => api.validateCurrentViewRetrievalV1Observation(bad));
  }
  assert(api.validateCurrentViewRetrievalV1Observation(sample()));
  assert.throws(() => api.validateCurrentViewRetrievalV1Observation({ ...sample(), resolvedURI: "https://other.example/x" }), /URI/);
});

test("configuration, original digest/source key and scope-shared zero nonce use independent compiler preimages", () => {
  const o = sample();
  assert.equal(api.currentViewRetrievalV1ConfigurationHash(d), configurationHash(d));
  assert.equal(api.currentViewRetrievalV1Digest(c, d, o), digest(o));
  assert.equal(api.currentViewRetrievalV1SourceKey(o.source), sourceKey(o.source));
  const changed = clone(o); changed.source.checkpointContextHash = H("different-context");
  assert.equal(sourceKey(changed.source), sourceKey(o.source));
  assert.equal(api.currentViewRetrievalV1SourceKey(changed.source), sourceKey(o.source));
  assert.notEqual(api.currentViewRetrievalV1Digest(c, d, changed), digest(o));
  const nonce = abiHash(["bytes32", "address", "uint256"], [id("6529STREAM_VIEW_RETRIEVAL_NONCE_V1"), writer, 0n]);
  assert.equal(api.currentViewRetrievalV1NonceKey(writer, 0n), nonce);
  changed.source.scope.scopeId = H("other-scope");
  assert.equal(api.currentViewRetrievalV1NonceKey(changed.writer, changed.nonce), nonce);
  assert.notEqual(api.currentViewRetrievalV1ScopeKey(changed.source.scope), api.currentViewRetrievalV1ScopeKey(scope));
  assert.equal(api.currentViewRetrievalV1ScopeKey(scope), abiHash(["bytes32", scopeType], [id("6529STREAM_VIEW_RETRIEVAL_REVOCATION_SCOPE_V1"), scope]));
  assert.notEqual(api.currentViewRetrievalV1Digest({ ...c, witness: A(99) }, d, o), digest(o));
  assert.notEqual(api.currentViewRetrievalV1Digest(c, { ...d, signatureGas: d.signatureGas + 1n }, o), digest(o));
  assert.throws(() => api.currentViewRetrievalV1Digest({ ...c, chainId: 2n }, d, o), /chain/);
});

test("supplied prepare validation uses inclusive fresh times and exact request/source joins without nonce or signature input", () => {
  const o = sample();
  const r = requestOf(o);
  for (const timestamp of [20n, 40n]) assert(api.validateCurrentViewRetrievalV1Prepared(c, d, r, o, digest(o), { timestamp, adoptedAt: 20n, institutionalObservedAt: 20n }));
  for (const times of [{ timestamp: 19n, adoptedAt: 1n, institutionalObservedAt: 1n }, { timestamp: 41n, adoptedAt: 1n, institutionalObservedAt: 1n },
    { timestamp: 25n, adoptedAt: 21n, institutionalObservedAt: 1n }, { timestamp: 25n, adoptedAt: 1n, institutionalObservedAt: 21n },
    { timestamp: 1n << 64n, adoptedAt: 1n, institutionalObservedAt: 1n }]) {
    assert.throws(() => api.validateCurrentViewRetrievalV1Prepared(c, d, r, o, digest(o), times));
  }
  for (const config of [{ ...d, readGas: 49999n }, { ...d, sourceGas: 49999n }, { ...d, archiveGas: 16777217n },
    { ...d, signatureGas: 89999n }, { ...d, coreCodeHash: Z }, { ...d, checkpoint: ZeroAddress }]) {
    assert.throws(() => api.validateCurrentViewRetrievalV1Configuration(c, config));
  }
  for (const mutate of [x => { x.nonce = 1n; }, x => { x.source.router = A(99); }, x => { x.source.scope.scopeId = H("changed"); }, x => { x.coverage.coverageHash = H("changed"); }]) {
    const changed = clone(o); mutate(changed);
    assert.throws(() => api.validateCurrentViewRetrievalV1Prepared(c, d, r, changed, digest(changed), { timestamp: 25n, adoptedAt: 1n, institutionalObservedAt: 1n }));
  }
  assert.throws(() => api.validateCurrentViewRetrievalV1Prepared(c, d, r, o, H("wrong-digest"), { timestamp: 25n, adoptedAt: 1n, institutionalObservedAt: 1n }), /digest/);
});

test("canonical payload and mined receipt/history authenticate original compiler commitments without fresh authorization", () => {
  const o = sample();
  const signature = "0x1234"; // Deliberately not a valid fresh signature; immutable history never reauthorizes it.
  const { r, payload } = originalReceipt(o, signature);
  assert.equal(api.currentViewRetrievalV1Payload(o, signature), payload);
  assert.deepEqual(api.currentViewRetrievalV1PreviewReceipt(c, d, o, signature, 25n), r);
  assert.equal(api.currentViewRetrievalV1RecordHash(c, d, r), r.recordHash);
  assert.deepEqual(api.decodeCurrentViewRetrievalV1Payload(payload), { observation: o, signature });
  const history = api.authenticateCurrentViewRetrievalV1History(c, d, r, payload);
  assert.equal(history.signatureVerified, false);
  assert.equal(history.currentnessVerified, false);
  assert.equal(history.signature, signature);
  for (const field of Object.keys(r)) {
    const wrong = { ...r, [field]: typeof r[field] === "bigint" ? r[field] + 1n : field === "writer" ? A(88) : H(`wrong-${field}`) };
    assert.throws(() => api.authenticateCurrentViewRetrievalV1History(c, d, wrong, payload), undefined, field);
  }
  for (const raw of [`${payload}00`, `${payload}00`.slice(2), payload.slice(0, -2), `0x${"00".repeat(32)}${payload.slice(66)}`]) assert.throws(() => api.decodeCurrentViewRetrievalV1Payload(raw));
  for (const field of ["core", "router"]) {
    const changed = clone(o); changed.source[field] = A(88);
    const forged = originalReceipt(changed, signature);
    assert.throws(() => api.authenticateCurrentViewRetrievalV1History(c, d, forged.r, forged.payload), /Historical source/);
  }
  for (const mutate of [x => { x.object.canonicalizationId = H("unknown-canon"); },
    ...["artistId", "contentHash", "sha256Digest", "arweaveDataRoot"].map(field => x => { x.coverage[field] = H(`wrong-${field}`); }),
    x => { x.coverage.byteSize += 1n; },
    ...["firstReceiptHash", "secondReceiptHash", "firstFixityHash", "secondFixityHash"].map(field => x => { x.coverage[field] = Z; })]) {
    const changed = clone(o); mutate(changed);
    // Recompute full original payload, digest and record: these are inner immutable joins.
    const forged = originalReceipt(changed, signature);
    assert(api.validateCurrentViewRetrievalV1Observation(changed)); // Original raw Codec.shape remains weaker.
    assert.throws(() => api.authenticateCurrentViewRetrievalV1History(c, d, forged.r, forged.payload));
  }
});

test("complete 524288-byte payload limit, signature limit and 8192-byte STOP chunk plan are exact", () => {
  const o = sample();
  o.source.requestedURI = `${ar(1)}/path`;
  o.resolvedURI = ar(2);
  o.steps = [{ ...step(3n, o.source.requestedURI, o.resolvedURI), manifestObject: H("m"), manifestCoverage: H("mc"), manifestBytes: "0x01" }];
  const minimum = coder.encode([observationType, "bytes"], [o, "0x"]);
  const amount = 1 + 524288 - (minimum.length - 2) / 2;
  o.steps[0].manifestBytes = `0x${"ab".repeat(amount)}`;
  const maximum = api.currentViewRetrievalV1Payload(o, "0x");
  assert.equal((maximum.length - 2) / 2, 524288);
  assert.deepEqual(api.decodeCurrentViewRetrievalV1Payload(maximum).observation, o);
  const chunks = api.currentViewRetrievalV1Chunks(maximum);
  assert.equal(chunks.length, 64);
  assert.equal(`0x${chunks.map(x => x.data.slice(2)).join("")}`, maximum);
  for (const [index, row] of chunks.entries()) {
    assert.equal(row.index, BigInt(index)); assert.equal(row.byteLength, 8192n);
    assert.equal(row.hash, keccak256(row.data)); assert.equal(row.runtime, `0x00${row.data.slice(2)}`); assert.equal(row.runtimeHash, keccak256(row.runtime));
  }
  o.steps[0].manifestBytes += "ab".repeat(32);
  assert.throws(() => api.currentViewRetrievalV1Payload(o, "0x"), /bound/);
  assert.throws(() => api.currentViewRetrievalV1Chunks(`${maximum}00`), /bound/);
  assert.throws(() => api.currentViewRetrievalV1Chunks("0x"), /Empty/);
  assert(api.currentViewRetrievalV1Payload(sample(), `0x${"01".repeat(4096)}`));
  assert.throws(() => api.currentViewRetrievalV1Payload(sample(), `0x${"01".repeat(4097)}`), /bound/);
});

test("original direct, own-key, compact, EIP7702 and ERC1271 routes remain distinct", () => {
  const h = digest(sample());
  const sig = key.sign(h);
  for (const signature of [sig.serialized, sig.compactSerialized]) {
    const result = api.currentViewRetrievalV1SignatureRoute(A(90), writer, h, signature, "0x");
    assert.equal(result.route, "own-key"); assert.equal(result.runtimeVerified, false);
  }
  assert.equal(api.currentViewRetrievalV1SignatureRoute(writer, writer, h, "0x", "0x6000").route, "direct-writer");
  assert.equal(api.currentViewRetrievalV1SignatureRoute(A(90), writer, h, sig.serialized, "0x6000").route, "erc1271");
  const designated = `0xef0100${A(99).slice(2)}`;
  assert.equal(api.currentViewRetrievalV1SignatureRoute(A(90), writer, h, sig.serialized, designated).route, "own-key");
  assert.equal(api.currentViewRetrievalV1SignatureRoute(A(90), writer, h, "0x1234", designated).requiresContractValidation, true);
  for (const signature of ["0x", "0x1234", `${sig.serialized.slice(0, -2)}00`, key.sign(hashMessage(h)).serialized]) {
    assert.throws(() => api.currentViewRetrievalV1SignatureRoute(A(90), writer, h, signature, "0x"), /own-key/);
  }
  const highS = `0x${sig.r.slice(2)}${(0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141n - BigInt(sig.s)).toString(16).padStart(64, "0")}${sig.v === 27 ? "1c" : "1b"}`;
  assert.throws(() => api.currentViewRetrievalV1SignatureRoute(A(90), writer, h, highS, "0x"), /own-key/);
  const magic = `0x1626ba7e${"00".repeat(28)}`;
  assert.equal(api.validateCurrentViewRetrievalV1ERC1271Result(true, magic), magic);
  for (const [ok, raw] of [[false, magic], [true, "0x1626ba7e"], [true, `${magic}00`], [true, Z], [true, `0x${"00".repeat(28)}1626ba7e`]]) {
    assert.throws(() => api.validateCurrentViewRetrievalV1ERC1271Result(ok, raw));
  }
});

test("original institutional writer projection binds second receipt, family, status and identifier without claiming admission", () => {
  const o = sample();
  const identifier = "0x123456";
  const receipt = { objectHash: o.coverage.objectHash, familyRecordHash: o.coverage.secondFamilyRecordHash,
    storageIdentifierHash: keccak256(identifier), evidenceClass: id("ATTESTED_POSSESSION"), proofProfileHash: id("STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1"),
    proofRecordHash: H("proof"), writer, observedAt: 10n, nonce: 0n, deadline: 19n };
  const family = { ...zero(familyType), economics: 2n, storingAgent: writer };
  o.coverage.secondReceiptHash = archiveHash(receipt);
  assert.equal(api.currentViewRetrievalV1ArchiveReceiptHash(d, receipt), o.coverage.secondReceiptHash);
  const input = { receipt, identifier, family, status: 1n, revision: 2n };
  assert.deepEqual(api.validateCurrentViewRetrievalV1WriterEvidence(d, o.coverage, input), { writer, observedAt: 10n, originalAdmissionVerified: false });
  for (const change of [x => { x.receipt.objectHash = H("wrong"); }, x => { x.receipt.familyRecordHash = H("wrong"); }, x => { x.receipt.observedAt = 0n; },
    x => { x.family.storingAgent = A(99); }, x => { x.family.economics = 1n; }, x => { x.status = 0n; }, x => { x.revision = 0n; },
    x => { x.receipt.evidenceClass = H("wrong"); }, x => { x.receipt.proofProfileHash = H("wrong"); }, x => { x.identifier = "0x1234"; }]) {
    const bad = clone(input); change(bad);
    const coverage = { ...o.coverage, secondReceiptHash: archiveHash(bad.receipt) };
    assert.throws(() => api.validateCurrentViewRetrievalV1WriterEvidence(d, coverage, bad));
  }
});

test("same original Archive pair accepts later passing fixities and rejects substituted identities", () => {
  const o = sample();
  const { coverageHash, ...pair } = o.coverage;
  const changed = { ...pair, firstFixityHash: H("later1"), secondFixityHash: H("later2") };
  assert.deepEqual(api.validateCurrentViewRetrievalV1CurrentPair(o.coverage, changed), changed);
  for (const field of Object.keys(pair)) {
    const bad = { ...changed, [field]: field.includes("Fixity") ? Z : typeof pair[field] === "bigint" ? pair[field] + 1n : H(`wrong-${field}`) };
    assert.throws(() => api.validateCurrentViewRetrievalV1CurrentPair(o.coverage, bad), undefined, field);
  }
  assert.deepEqual(api.validateCurrentViewRetrievalV1ArchiveAdmission(o, admission(o)), admission(o));
  const wrong = admission(o); wrong.proof = { ...wrong.proof, backend: 2n };
  assert.throws(() => api.validateCurrentViewRetrievalV1ArchiveAdmission(o, wrong), /proof/);
  assert.throws(() => api.validateCurrentViewRetrievalV1ArchiveAdmission({ ...o, object: { ...o.object, byteSize: 124n } }, admission(o)), /byteSize/);
});

test("manifest route evidence authenticates supplied full bytes and original endowed transaction locators", () => {
  const o = sample();
  o.source.requestedURI = `${ar(1)}/selected/path`;
  o.resolvedURI = ar(2);
  const manifest = sample();
  const raw = "0x0102030405";
  manifest.object = { ...manifest.object, contentHash: keccak256(raw), sha256Digest: sha256(raw), byteSize: 5n };
  manifest.coverage = { ...manifest.coverage, objectHash: H("manifest-object"), coverageHash: H("manifest-coverage"),
    contentHash: manifest.object.contentHash, sha256Digest: manifest.object.sha256Digest, byteSize: 5n };
  const mtx = transaction(manifest.coverage, `0x${"01".repeat(32)}`);
  const final = transaction(o.coverage, `0x${"02".repeat(32)}`, 2);
  o.steps = [{ ...step(3n, o.source.requestedURI, o.resolvedURI), manifestObject: manifest.coverage.objectHash, manifestCoverage: manifest.coverage.coverageHash, manifestBytes: raw }];
  const rows = [{ stepIndex: 0n, object: manifest.object, admission: admission(manifest), transaction: mtx }];
  assert.equal(api.validateCurrentViewRetrievalV1RouteEvidence(d, o, rows, final).originalAdmissionVerified, false);
  for (const mutate of [x => { x[0].stepIndex = 1n; }, x => { x[0].object.byteSize = 4n; }, x => { x[0].object.contentHash = H("wrong"); },
    x => { x[0].object.sha256Digest = H("wrong"); }, x => { x[0].transaction.locator = `0x${"03".repeat(32)}`; },
    x => { x[0].admission.proof.objectHash = H("wrong"); }, x => { x[0].transaction.receipt.proofRecordHash = H("wrong"); }]) {
    const bad = clone(rows); mutate(bad); assert.throws(() => api.validateCurrentViewRetrievalV1RouteEvidence(d, o, bad, final));
  }
  assert.throws(() => api.validateCurrentViewRetrievalV1RouteEvidence(d, o, [], final), /Incomplete/);
  assert.throws(() => api.validateCurrentViewRetrievalV1RouteEvidence(d, o, rows, null), /missing/);
  assert.throws(() => api.validateCurrentViewRetrievalV1RouteEvidence(d, sample(), [], final), /Unexpected/);
  assert(api.validateCurrentViewRetrievalV1RouteEvidence(d, sample(), [], null));
});

test("revoke facts require original caller, one use and checked epoch without current source or relayed signature", () => {
  const { r } = originalReceipt(sample());
  const reason = H("reason");
  assert.deepEqual(api.validateCurrentViewRetrievalV1Revocation(writer, r, reason, false, 3n),
    { recordHash: r.recordHash, writer, reasonHash: reason, nextEpoch: 4n, factsVerified: false });
  for (const args of [[A(99), r, reason, false, 3n], [writer, r, Z, false, 3n], [writer, r, reason, true, 3n],
    [writer, r, reason, false, (1n << 64n) - 1n], [writer, { ...r, recordHash: Z }, reason, false, 3n]]) {
    assert.throws(() => api.validateCurrentViewRetrievalV1Revocation(...args));
  }
});

test("closed two CALL0 plans and all original reads reconstruct exact compiler calldata and generic Safe calls", () => {
  const requests = [{ kind: "publish", request: requestOf(sample()), signature: "0x1234" }, { kind: "revoke", recordHash: H("record"), reasonHash: H("reason") }];
  for (const request of requests) {
    const plan = api.prepareCurrentViewRetrievalV1Call(c, writer, request);
    const args = request.kind === "publish" ? [request.request, request.signature] : [request.recordHash, request.reasonHash];
    assert.equal(plan.call.data, host.encodeFunctionData(request.kind, args));
    assert.equal(plan.call.to, c.witness); assert.equal(plan.call.value, 0n); assert.equal(plan.factsVerified, false);
    assert.deepEqual(api.normalizeCurrentViewRetrievalV1Call(plan), plan);
    assert.deepEqual(toSafeCall(plan.call), { ...plan.call, value: "0", operation: 0 });
    for (const call of [{ ...plan.call, to: A(99) }, { ...plan.call, value: 1n }, { ...plan.call, data: `${plan.call.data}00` }]) {
      assert.throws(() => api.normalizeCurrentViewRetrievalV1Call({ ...plan, call }), /reconstruction/);
    }
  }
  for (const bad of [{ kind: "coverRetrievalNext" }, { ...requests[1], signature: "0x" }, { kind: "revoke", recordHash: Z, reasonHash: H("r") }]) {
    assert.throws(() => api.prepareCurrentViewRetrievalV1Call(c, writer, bad));
  }
  const reads = ["configuration", "configurationHash", "retrievalProfile"].map(kind => ({ kind }));
  reads.push({ kind: "prepare", request: requestOf(sample()) }, { kind: "supportsInterface", interfaceId: "0x01ffc9a7" },
    { kind: "nonceUsed", nonceKey: Z }, { kind: "revocationEpoch", scope });
  reads.push(...["record", "encoded", "requireCurrent", "requireCorrespondence", "revoked"].map(kind => ({ kind, recordHash: Z })));
  for (const input of reads) {
    const plan = api.prepareCurrentViewRetrievalV1Read(c, ZeroAddress, input);
    assert.equal(host.parseTransaction({ data: plan.call.data }).name, input.kind);
    assert.deepEqual(api.normalizeCurrentViewRetrievalV1Read(plan), plan);
    assert.throws(() => api.normalizeCurrentViewRetrievalV1Read({ ...plan, call: { ...plan.call, value: 1n } }), /reconstruction/);
  }
  assert.throws(() => api.prepareCurrentViewRetrievalV1Read(c, writer, { kind: "revoke", recordHash: H("r"), reasonHash: H("reason") }), /Unsupported/);
});

test("call planner owns input and bounds whole calldata, not just dynamic fields", () => {
  const input = { kind: "publish", request: requestOf(sample()), signature: "0x" };
  const saved = api.prepareCurrentViewRetrievalV1Call(c, writer, input);
  input.request.scope.scopeId = Z;
  assert.equal(saved.request.request.scope.scopeId, scope.scopeId);
  assert(Object.isFrozen(saved.request.request.steps));
  const o = sample();
  o.source.requestedURI = `${ar(1)}/p`;
  o.resolvedURI = ar(2);
  o.steps = [{ ...step(3n, o.source.requestedURI, o.resolvedURI), manifestObject: H("m"), manifestCoverage: H("mc"), manifestBytes: "0x01" }];
  const raw = host.encodeFunctionData("publish", [requestOf(o), "0x"]);
  const extra = 1048576 - ((raw.length - 2) / 2) - 4; // Original selector leaves a four-byte residue.
  o.steps[0].manifestBytes = `0x${"01".repeat(1 + Math.floor(extra / 32) * 32)}`;
  const plan = api.prepareCurrentViewRetrievalV1Call(c, writer, { kind: "publish", request: requestOf(o), signature: "0x" });
  assert((plan.call.data.length - 2) / 2 <= 1048576);
  assert.deepEqual(api.normalizeCurrentViewRetrievalV1Call(plan), plan);
  o.steps[0].manifestBytes += "01".repeat(32);
  assert.throws(() => api.prepareCurrentViewRetrievalV1Call(c, writer, { kind: "publish", request: requestOf(o), signature: "0x" }), /bound/);
});
