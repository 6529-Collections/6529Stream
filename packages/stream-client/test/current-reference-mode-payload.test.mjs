import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as mode from "../dist/current-reference-mode-payload.js";
import { referenceEnvironmentCanonicalBytes } from "../dist/current-reference-environment.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-reference-mode-payload-abi.json", import.meta.url), "utf8"));
const compiled = new Interface(fixture.abis.companion), coder = AbiCoder.defaultAbiCoder();
const publicationType = compiled.getFunction("prepareModePublication").inputs[0];
const [, receiptType, sourceType, evidenceType, factsType] = compiled.getFunction("prepareModePayload").inputs;
const fullTypes = ["bytes32", publicationType, receiptType, sourceType, evidenceType, factsType, "bytes"];
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`), host = A(10), caller = A(11), chain = (1n << 240n) + 6529n;
function zero(type) {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(field => [field.name, zero(field)]));
  if (type.baseType === "array") return type.arrayLength === -1 ? [] : Array.from({ length: type.arrayLength }, () => zero(type.arrayChildren));
  if (type.type === "string") return "";
  if (type.type === "address") return ZeroAddress;
  if (type.type === "bytes") return "0x";
  if (type.type === "bool") return false;
  if (type.type.startsWith("bytes")) return `0x${"00".repeat(Number(type.type.slice(5)))}`;
  return 0n;
}
function environment() {
  const e = { objectHash: id("object"), coverageHash: id("coverage"), manifestHash: ZeroHash, manifestBytes: 0n,
    engineName: "engine", engineVersion: "1", engineExecutableSha256: id("engine bytes"), toolchainName: "tool",
    toolchainVersion: "1", toolchainSha256: id("tool bytes"), engineExecutablePath: "engine.exe", toolchainPath: "tool.exe",
    packageFiles: [{ path: "engine.exe", byteSize: 1n, sha256Digest: id("engine bytes") }, { path: "tool.exe", byteSize: 2n, sha256Digest: id("tool bytes") }],
    platformPrerequisites: [{ path: "C:\\Windows\\é.dll", byteSize: 0n, sha256Digest: id("platform") }],
    operatingSystem: "Windows", operatingSystemVersion: "Server", architecture: "AMD64", viewportWidth: 1920n,
    viewportHeight: 1080n, devicePixelRatio: 1n, colorSpace: "srgb", softwareRasterization: true,
    captureProfile: id("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"), licenseNote: "L" };
  const canonical = referenceEnvironmentCanonicalBytes(e);
  return { ...e, manifestHash: keccak256(canonical), manifestBytes: BigInt((canonical.length - 2) / 2) };
}
function vector() {
  const publication = zero(publicationType); publication.environment = environment();
  publication.collectionId = (1n << 252n) + 1n; publication.expectedRevision = (1n << 63n) + 3n;
  publication.referenceId = id("ref"); publication.expectedSourcesHash = id("supplied source"); publication.manifestURI = "ipfs://original";
  const captureType = publicationType.components.find(p => p.name === "captures").arrayChildren;
  publication.captures = [{ ...zero(captureType), tokenId: (1n << 255n) + 5n, collectionSerial: (1n << 251n) + 2n,
    animationHTML: "0x00ff616263", repeatCaptureSha256: [id("repeat 1"), id("repeat 2")], environmentManifestHash: publication.environment.manifestHash }];
  const receipt = { ...zero(receiptType), recordHash: id("record"), recordChainHash: id("record chain"), payloadHash: id("payload"),
    payloadBytes: (1n << 32n) - 1n, recordedAt: (1n << 64n) - 1n, recorder: A(12), authorizationClass: 8n,
    grantRevision: (1n << 63n) + 1n, effectiveAt: (1n << 63n) + 2n, collectionId: publication.collectionId };
  const source = zero(sourceType); source.mintedEver = (1n << 255n) + 7n;
  const sampleType = sourceType.components.find(p => p.name === "samples").arrayChildren;
  source.samples = [{ ...zero(sampleType), tokenId: publication.captures[0].tokenId, originalCoordinator: A(13) }];
  const evidence = zero(evidenceType); evidence.mode = 1n; evidence.repeats = [{ objectHash: id("repeat object"), coverageHash: id("repeat coverage") }];
  evidence.perceptual.threshold = -(1n << 63n); evidence.perceptual.scores = [(1n << 63n) - 1n, -1n];
  evidence.perceptual.metric.tool = "metric\n工具"; evidence.curated.condition.examinerName = "inactive branch retained";
  evidence.curated.intent.display.color.digest = "0x01fe";
  evidence.curated.properties = [{ id: id("property b"), name: "B", significantValue: "second" }, { id: id("property a"), name: "A", significantValue: "first" }];
  evidence.curated.condition.assessments = [{ propertyId: id("property b"), conforms: true, observation: "exact order" }];
  const facts = zero(factsType); facts.mode = 2n; facts.evidenceHash = id("independently supplied fact");
  facts.repeats = [{ ...source.environmentCoverage, byteSize: (1n << 64n) - 1n }];
  return { publication, input: { receipt, source, evidence, facts } };
}
function snapshots(v = vector(), c = chain, h = host) {
  const publication = mode.prepareReferenceModePublication(c, h, v.publication);
  return { publication, payload: mode.prepareReferenceModePayload(publication, v.input) };
}
function originalPayload(s) { return coder.encode(fullTypes, [id("6529STREAM_REFERENCE_MODE_PAYLOAD_V1"), s.publication.publication,
  s.input.receipt, s.input.source, s.input.evidence, s.input.facts, s.publication.environment.canonical]); }

test("compiled original tuple and exact permissionless selectors remain unchanged", () => {
  const v = vector(), { publication, payload } = snapshots(v), client = new Interface(mode.CURRENT_REFERENCE_MODE_PAYLOAD_ABI);
  assert.equal(ParamType.from(mode.REFERENCE_MODE_PUBLICATION_TUPLE).format("sighash"), publicationType.format("sighash"));
  for (const [name, selector] of [["prepareModePublication", "0x7be6d49e"], ["prepareModePayload", "0xc1d98193"],
    ["preparedModePublication", "0xf9593e91"], ["preparedModePayload", "0x73f4cd7c"]]) {
    assert.equal(client.getFunction(name).selector, selector); assert.equal(client.getFunction(name).format("sighash"), compiled.getFunction(name).format("sighash"));
  }
  assert.equal(mode.REFERENCE_MODE_PAYLOAD_PREPARATION_INTERFACE_ID, "0x3092a6e0");
  assert.equal(publication.canonical, coder.encode([publicationType], [v.publication]));
  assert.equal(payload.canonical, originalPayload(payload));
  for (const name of ["ReferenceModePublicationPrepared", "ReferenceModePayloadPrepared"]) assert.equal(client.getEvent(name).topicHash, compiled.getEvent(name).topicHash);
});

test("original identities bind full-width chain and actual host independently of preparer", () => {
  const { publication: p, payload: s } = snapshots();
  assert.equal(p.publicationPreparationId, keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "uint32"],
    [id("6529STREAM_REFERENCE_MODE_PUBLICATION_PREPARATION_V1"), chain, host, keccak256(p.canonical), BigInt((p.canonical.length - 2) / 2)])));
  const lengthsAndHashes = [p.contentHash, p.byteLength];
  for (const [type, value] of [[receiptType, s.input.receipt], [sourceType, s.input.source], [evidenceType, s.input.evidence], [factsType, s.input.facts]]) {
    const bytes = coder.encode([type], [value]); lengthsAndHashes.push(keccak256(bytes), BigInt((bytes.length - 2) / 2));
  }
  lengthsAndHashes.push(p.environment.contentHash, p.environment.byteLength);
  const componentsType = "(bytes32,uint32,bytes32,uint32,bytes32,uint32,bytes32,uint32,bytes32,uint32,bytes32,uint32)";
  assert.deepEqual(Object.values(s.components), lengthsAndHashes);
  assert.equal(s.payloadPreparationId, keccak256(coder.encode(["bytes32", "uint256", "address", componentsType],
    [id("6529STREAM_REFERENCE_MODE_PAYLOAD_PREPARATION_V1"), chain, host, lengthsAndHashes])));
  assert.equal(s.components.receiptBytes, 640n);
  assert.equal(s.components.environmentHash, keccak256(p.environment.canonical));
  assert.notEqual(s.components.environmentHash, keccak256(coder.encode(["bytes"], [p.environment.canonical])));
  for (const other of [snapshots(vector(), chain + 1n, host), snapshots(vector(), chain, A(99))]) {
    assert.equal(other.payload.canonical, s.canonical); assert.notEqual(other.publication.publicationPreparationId, p.publicationPreparationId);
    assert.notEqual(other.payload.payloadPreparationId, s.payloadPreparationId);
  }
  assert.equal(mode.prepareReferenceModePayloadCall(s, caller).identity, mode.prepareReferenceModePayloadCall(s, A(100)).identity);
});

test("normalizes exactly five receipt fields while retaining every other original field", () => {
  const v = vector(), { publication, payload } = snapshots(v), excluded = new Set(["recordHash", "recordChainHash", "payloadHash", "payloadBytes", "recordedAt"]);
  for (const field of receiptType.components) {
    const current = v.input.receipt[field.name];
    const replacement = field.type === "bytes32" ? id(`changed ${field.name}`) : field.type === "address" ? A(98) : current > 0n ? current - 1n : 1n;
    const result = mode.prepareReferenceModePayload(publication, { ...v.input, receipt: { ...v.input.receipt, [field.name]: replacement } });
    if (excluded.has(field.name)) assert.equal(result.payloadPreparationId, payload.payloadPreparationId, field.name);
    else assert.notEqual(result.payloadPreparationId, payload.payloadPreparationId, field.name);
  }
  assert.deepEqual(mode.normalizeReferenceModeReceipt(v.input.receipt), { ...v.input.receipt,
    recordHash: ZeroHash, recordChainHash: ZeroHash, payloadHash: ZeroHash, payloadBytes: 0n, recordedAt: 0n });
  assert.equal(v.input.receipt.recordHash, id("record"));
  assert.throws(() => mode.normalizeReferenceModeReceipt({ ...v.input.receipt, recordedAt: 1n << 64n }), /uint64/);
});

test("retains inactive branches, array order and structurally valid unadmitted facts", () => {
  const v = vector(), { publication, payload } = snapshots(v);
  assert.equal(payload.input.evidence.mode, 1n); assert.equal(payload.input.facts.mode, 2n);
  assert.equal(payload.input.evidence.curated.condition.examinerName, "inactive branch retained");
  assert.deepEqual(payload.input.evidence.curated.properties, v.input.evidence.curated.properties);
  const changed = structuredClone(v.input); changed.evidence.curated.condition.examinerName += " changed";
  assert.notEqual(mode.prepareReferenceModePayload(publication, changed).payloadPreparationId, payload.payloadPreparationId);
  changed.evidence.curated.properties.reverse();
  assert.deepEqual(mode.prepareReferenceModePayload(publication, changed).input.evidence.curated.properties, changed.evidence.curated.properties);
  const zeroPub = { ...zero(publicationType), environment: environment() };
  const zeroSnapshot = mode.prepareReferenceModePublication(chain, host, zeroPub);
  assert.doesNotThrow(() => mode.prepareReferenceModePayload(zeroSnapshot, { receipt: zero(receiptType), source: zero(sourceType), evidence: zero(evidenceType), facts: zero(factsType) }));
  assert.equal("authorized" in payload, false); assert.equal("current" in payload, false);
});

test("preparation derives authentic Environment bytes and checks every capture reference", () => {
  const v = vector(), { publication: p } = snapshots(v);
  assert.equal(p.descriptor.environmentId, p.environment.environmentId);
  assert.equal(p.descriptor.environmentHash, v.publication.environment.manifestHash);
  const second = structuredClone(v.publication.captures[0]); second.environmentManifestHash = ZeroHash;
  assert.throws(() => mode.prepareReferenceModePublication(chain, host, { ...v.publication, captures: [...v.publication.captures, second] }), /Capture environment/);
  assert.throws(() => mode.prepareReferenceModePublication(chain, host, { ...v.publication, environment: { ...v.publication.environment, manifestHash: id("wrong manifest") } }), /manifest/);
  const changed = structuredClone(v.publication); changed.environment.coverageHash = id("other coverage");
  const other = mode.prepareReferenceModePublication(chain, host, changed);
  assert.equal(other.environment.canonical, p.environment.canonical); assert.notEqual(other.descriptor.environmentId, p.descriptor.environmentId);
  assert.notEqual(other.publicationPreparationId, p.publicationPreparationId);
});

test("canonical decoding roundtrips complete structs and rejects changed normalized fields", () => {
  const { payload: s } = snapshots();
  assert.deepEqual(mode.decodeReferenceModePayload(chain, host, s.canonical), s);
  for (const field of ["recordHash", "recordChainHash", "payloadHash", "payloadBytes", "recordedAt"]) {
    const receipt = { ...s.input.receipt, [field]: field.endsWith("Hash") ? id("not normalized") : 1n };
    const raw = coder.encode(fullTypes, [mode.REFERENCE_MODE_PAYLOAD_DOMAIN, s.publication.publication, receipt,
      s.input.source, s.input.evidence, s.input.facts, s.publication.environment.canonical]);
    assert.throws(() => mode.decodeReferenceModePayload(chain, host, raw), /canonical normalized/);
  }
});

test("canonical decoding rejects changed domain, Environment, trailing bytes and padding", () => {
  const { payload: s } = snapshots();
  const values = [mode.REFERENCE_MODE_PAYLOAD_DOMAIN, s.publication.publication, s.input.receipt,
    s.input.source, s.input.evidence, s.input.facts, s.publication.environment.canonical];
  assert.throws(() => mode.decodeReferenceModePayload(chain, host, coder.encode(fullTypes, [id("alternate domain"), ...values.slice(1)])), /domain/);
  assert.throws(() => mode.decodeReferenceModePayload(chain, host, coder.encode(fullTypes, [...values.slice(0, 6), "0x00"])), /Environment bytes/);
  assert.throws(() => mode.decodeReferenceModePayload(chain, host, s.canonical + "00"), /canonical/);
  assert.ok(s.publication.environment.byteLength % 32n !== 0n);
  assert.throws(() => mode.decodeReferenceModePayload(chain, host, s.canonical.slice(0, -2) + "01"), /canonical/);
  assert.throws(() => mode.decodeReferenceModePayload(chain, host, s.canonical.slice(0, -64)));
});

test("preserves original signed int64 extrema and full-width unsigned values without number coercion", () => {
  const v = vector(), normalized = mode.normalizeReferenceModeEvidence(v.input.evidence);
  assert.equal(normalized.perceptual.threshold, -(1n << 63n)); assert.equal(normalized.perceptual.scores[0], (1n << 63n) - 1n);
  for (const bad of [-(1n << 63n) - 1n, 1n << 63n, 1, "1"]) assert.throws(() => mode.normalizeReferenceModeEvidence({ ...v.input.evidence,
    perceptual: { ...v.input.evidence.perceptual, threshold: bad } }), /int64 bigint/);
  for (const bad of [-(1n << 63n) - 1n, 1n << 63n]) assert.throws(() => mode.normalizeReferenceModeEvidence({ ...v.input.evidence,
    perceptual: { ...v.input.evidence.perceptual, scores: [bad] } }), /int64 bigint/);
  const max = { ...v.publication, collectionId: (1n << 256n) - 1n, expectedRevision: (1n << 64n) - 1n };
  assert.equal(mode.normalizeReferenceModePublication(max).expectedRevision, (1n << 64n) - 1n);
  for (const patch of [{ collectionId: 1n << 256n }, { collectionId: -1n }, { collectionId: 1 }, { expectedRevision: 1n << 64n }]) {
    assert.throws(() => mode.normalizeReferenceModePublication({ ...max, ...patch }), /bigint/);
  }
  assert.throws(() => mode.normalizeReferenceModeReceipt({ ...v.input.receipt, authorizationClass: 256n }), /uint8/);
});

test("original enums are width-checked without adding metric, reference or admission profiles", () => {
  const v = vector();
  for (const modeValue of [0n, 1n, 2n]) assert.equal(mode.normalizeReferenceModeEvidence({ ...v.input.evidence, mode: modeValue }).mode, modeValue);
  for (const modeValue of [3n, 256n, 1]) assert.throws(() => mode.normalizeReferenceModeEvidence({ ...v.input.evidence, mode: modeValue }));
  assert.throws(() => mode.normalizeReferenceModeFacts({ ...v.input.facts, mode: 3n }), /enum/);
  for (const field of ["origin", "status"]) {
    const changed = structuredClone(v.input.evidence);
    if (field === "origin") changed.curated.intent.artist.origin = 2n; else changed.curated.intent.interview.status = 2n;
    assert.throws(() => mode.normalizeReferenceModeEvidence(changed), /enum/);
  }
  const changed = structuredClone(v.input.evidence); changed.curated.intent.display.color.algorithm = 65535n;
  changed.curated.intent.display.color.digest = "0x"; changed.perceptual.metric.scale = 0n;
  assert.doesNotThrow(() => mode.normalizeReferenceModeEvidence(changed));
  changed.curated.intent.display.color.algorithm = 65536n;
  assert.throws(() => mode.normalizeReferenceModeEvidence(changed), /uint16/);
});

test("text preserves exact Unicode, controls and empty strings; byte fields remain arbitrary bytes", () => {
  const v = vector(); v.input.evidence.curated.condition.examinerName = '\u0000\n"\\e\u0301😀';
  v.input.evidence.curated.intent.display.color.digest = "0xff00fe";
  const { payload } = snapshots(v); assert.deepEqual(mode.decodeReferenceModePayload(chain, host, payload.canonical), payload);
  const composed = structuredClone(v.input); composed.evidence.curated.condition.examinerName = "é";
  const decomposed = structuredClone(v.input); decomposed.evidence.curated.condition.examinerName = "e\u0301";
  assert.notEqual(mode.prepareReferenceModePayload(payload.publication, composed).contentHash, mode.prepareReferenceModePayload(payload.publication, decomposed).contentHash);
  for (const invalid of ["\ud800", "\udc00"]) {
    const input = structuredClone(v.input.evidence); input.curated.condition.examinerName = invalid;
    assert.throws(() => mode.normalizeReferenceModeEvidence(input), /UTF-8 scalar/);
  }
  for (const invalid of ["0x0", "0xzz", new Uint8Array([1])]) {
    const input = structuredClone(v.input.evidence); input.curated.intent.display.color.digest = invalid;
    assert.throws(() => mode.normalizeReferenceModeEvidence(input), /hex bytes/);
  }
});

test("rejects missing, unknown and sparse nested structures before ABI encoding", () => {
  const v = vector();
  for (const mutate of [input => { input.extra = undefined; }, input => { input.curated.intent.display.color.extra = 1; },
    input => { delete input.curated.intent.display.color.uri; }, input => { input.perceptual.scores = new Array(1); },
    input => { input.perceptual.scores.extra = "ignored"; }, input => { input.curated.condition.assessments[0].conforms = 1; },
    input => { input[Symbol("hidden")] = true; }]) {
    const input = structuredClone(v.input.evidence); mutate(input); assert.throws(() => mode.normalizeReferenceModeEvidence(input));
  }
  const changed = structuredClone(v.publication); changed.environment.packageFiles.extra = true;
  assert.throws(() => mode.normalizeReferenceModePublication(changed), /dense/);
  const badCapture = structuredClone(v.publication); badCapture.captures[0].repeatCaptureSha256.push(id("third"));
  assert.throws(() => mode.normalizeReferenceModePublication(badCapture), /exactly 2/);
  assert.throws(() => mode.prepareReferenceModePayload(snapshots(v).publication, { ...v.input, signature: "0x" }), /unknown/);
});

test("publication bound includes full original ABI overhead and permits an independently preparable large publication", () => {
  const v = vector(); v.publication.captures[0].animationHTML = "0x";
  const base = mode.prepareReferenceModePublication(chain, host, v.publication);
  v.publication.captures[0].animationHTML = `0x${"ab".repeat(Number(524288n - base.byteLength))}`;
  const maximum = mode.prepareReferenceModePublication(chain, host, v.publication);
  assert.equal(maximum.byteLength, 524288n);
  assert.throws(() => mode.prepareReferenceModePayload(maximum, v.input), /524288/);
  v.publication.captures[0].animationHTML += "ab";
  assert.throws(() => mode.prepareReferenceModePublication(chain, host, v.publication), /524288/);
});

test("complete payload bound includes all seven fields and canonical Environment", () => {
  const v = vector(), base = snapshots(v).payload;
  v.input.evidence.curated.condition.credentials.digest = `0x${"cd".repeat(Number(524288n - base.byteLength))}`;
  const maximum = snapshots(v).payload;
  assert.equal(maximum.byteLength, 524288n); assert.ok(maximum.components.evidenceBytes < 524288n);
  assert.deepEqual(mode.decodeReferenceModePayload(chain, host, maximum.canonical), maximum);
  v.input.evidence.curated.condition.credentials.digest += "cd";
  assert.throws(() => snapshots(v), /524288/);
  const excessive = structuredClone(v.input.source); excessive.samples = new Array(16385).fill(v.input.source.samples[0]);
  assert.throws(() => mode.normalizeReferenceModeSourceFacts(excessive), /bounded array/);
});

test("snapshots copy and freeze every nested value before asynchronous use", async () => {
  const v = vector(), { publication, payload } = snapshots(v), saved = structuredClone(payload);
  v.publication.environment.packageFiles[0].byteSize = 99n; v.publication.captures[0].repeatCaptureSha256[0] = ZeroHash;
  v.input.evidence.curated.properties.reverse(); v.input.evidence.curated.intent.display.color.digest = "0x";
  v.input.facts.repeats[0].byteSize = 0n;
  await Promise.resolve(); assert.deepEqual(payload, saved);
  const frozen = value => { if (value && typeof value === "object") { assert.equal(Object.isFrozen(value), true); Object.values(value).forEach(frozen); } };
  frozen(payload); assert.deepEqual(mode.normalizeReferenceModePublicationSnapshot(structuredClone(publication)), publication);
  assert.deepEqual(mode.normalizeReferenceModePayloadSnapshot(structuredClone(payload)), payload);
});

test("snapshot reconstruction rejects substituted IDs, descriptors, facts and unsigned derived labels", () => {
  const { publication, payload } = snapshots();
  for (const mutate of [s => { s.publicationPreparationId = id("substitution"); }, s => { s.descriptor.publicationBytes += 1n; },
    s => { s.environment.packageInventory.inventoryId = id("other"); }, s => { s.descriptor.extra = undefined; },
    s => { s.canonical += "00"; }, s => { s.publication.expectedSourcesHash = ZeroHash; }]) {
    const s = structuredClone(publication); mutate(s); assert.throws(() => mode.normalizeReferenceModePublicationSnapshot(s));
  }
  for (const mutate of [s => { s.payloadPreparationId = id("substitution"); }, s => { s.components.receiptBytes = 641n; },
    s => { s.input.evidence.curated.condition.examinerName = "changed"; }, s => { s.input.receipt.recordHash = id("noncanonical"); },
    s => { s.components.extra = undefined; }, s => { s.contentHash = ZeroHash; }]) {
    const s = structuredClone(payload); mutate(s); assert.throws(() => mode.normalizeReferenceModePayloadSnapshot(s));
  }
});

test("original calls preserve actual permissionless caller, zero value and full tuples", () => {
  const { publication, payload } = snapshots();
  const p = mode.prepareReferenceModePublicationCall(publication, caller), s = mode.prepareReferenceModePayloadCall(payload, caller);
  assert.equal(p.caller, caller); assert.equal(s.caller, caller); assert.equal(p.call.to, host); assert.equal(s.call.to, host);
  assert.equal(p.call.value, 0n); assert.equal(s.call.value, 0n);
  assert.equal(p.call.data, compiled.encodeFunctionData("prepareModePublication", [publication.publication]));
  assert.equal(s.call.data, compiled.encodeFunctionData("prepareModePayload", [publication.publicationPreparationId,
    payload.input.receipt, payload.input.source, payload.input.evidence, payload.input.facts]));
  assert.deepEqual(mode.normalizeReferenceModePreparationCall(structuredClone(p)), p);
  assert.deepEqual(mode.normalizeReferenceModePreparationCall(structuredClone(s)), s);
  for (const patch of [{ kind: "publish" }, { call: { ...s.call, value: 1n } }, { call: { ...s.call, to: A(77) } },
    { call: { ...s.call, transport: undefined } }, { caller: ZeroAddress }, { identity: ZeroHash }]) {
    assert.throws(() => mode.normalizeReferenceModePreparationCall({ ...s, ...patch }));
  }
  for (const c of [0n, 1n << 256n, 1]) assert.throws(() => mode.prepareReferenceModePublication(c, host, publication.publication));
  assert.throws(() => mode.prepareReferenceModePublication(chain, ZeroAddress, publication.publication));
  assert.throws(() => mode.prepareReferenceModePayloadCall(payload, ZeroAddress));
});
