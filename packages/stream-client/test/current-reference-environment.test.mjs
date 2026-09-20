import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8String } from "ethers";
import { REFERENCE_ENVIRONMENT_ABI_TUPLE, REFERENCE_ENVIRONMENT_CAPTURE_PROFILE, REFERENCE_ENVIRONMENT_MAX_BYTES,
  normalizeReferenceEnvironment, normalizeReferenceEnvironmentSnapshot, prepareReferenceEnvironment,
  referenceEnvironmentCanonicalBytes, referenceEnvironmentId } from "../dist/current-reference-environment.js";
import { prepareReferenceInventory } from "../dist/current-reference-inventory.js";

const chainId = (1n << 250n) + 6529n, host = getAddress("0x0000000000000000000000000000000000001234");
const coder = AbiCoder.defaultAbiCoder();
const independentTuple = "(bytes32,bytes32,bytes32,uint32,string,string,bytes32,string,string,bytes32,string,string,(string,uint64,bytes32)[],(string,uint64,bytes32)[],string,string,string,uint16,uint16,uint8,string,bool,bytes32,string)";
function environment() {
  return { objectHash: id("runtime object"), coverageHash: id("coverage record"), manifestHash: ZeroHash, manifestBytes: 0n,
    engineName: "Browser", engineVersion: "1.0", engineExecutableSha256: id("engine bytes"), toolchainName: "Capture",
    toolchainVersion: "2.0", toolchainSha256: id("toolchain bytes"), engineExecutablePath: "engine.exe", toolchainPath: "toolchain.exe",
    packageFiles: [{ path: "engine.exe", byteSize: (1n << 64n) - 1n, sha256Digest: id("engine bytes") },
      { path: "toolchain.exe", byteSize: 100n, sha256Digest: id("toolchain bytes") },
      { path: "zero.txt", byteSize: 0n, sha256Digest: id("zero byte declaration") }],
    platformPrerequisites: [{ path: "C:\\Windows\\é.dll", byteSize: 0n, sha256Digest: id("platform declaration") }],
    operatingSystem: "Windows", operatingSystemVersion: "Server", architecture: "AMD64", viewportWidth: 4096n,
    viewportHeight: 1n, devicePixelRatio: 1n, colorSpace: "srgb", softwareRasterization: true,
    captureProfile: id("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"), licenseNote: "L" };
}
function declared(e = environment()) {
  const raw = referenceEnvironmentCanonicalBytes(e);
  return { ...e, manifestHash: keccak256(raw), manifestBytes: BigInt((raw.length - 2) / 2) };
}
function values(e) {
  return [e.objectHash, e.coverageHash, e.manifestHash, e.manifestBytes, e.engineName, e.engineVersion,
    e.engineExecutableSha256, e.toolchainName, e.toolchainVersion, e.toolchainSha256, e.engineExecutablePath, e.toolchainPath,
    e.packageFiles.map(row => [row.path, row.byteSize, row.sha256Digest]), e.platformPrerequisites.map(row => [row.path, row.byteSize, row.sha256Digest]),
    e.operatingSystem, e.operatingSystemVersion, e.architecture, e.viewportWidth, e.viewportHeight, e.devicePixelRatio,
    e.colorSpace, e.softwareRasterization, e.captureProfile, e.licenseNote];
}
function independentJSON(e) {
  const rows = items => items.map(row => ({ byteSize: row.byteSize.toString(), path: row.path, sha256Digest: row.sha256Digest.toLowerCase() }));
  return JSON.stringify({ architecture: e.architecture, captureProfile: e.captureProfile.toLowerCase(), colorSpace: e.colorSpace,
    devicePixelRatio: e.devicePixelRatio.toString(), engineExecutablePath: e.engineExecutablePath,
    engineExecutableSha256: e.engineExecutableSha256.toLowerCase(), engineName: e.engineName, engineVersion: e.engineVersion,
    licenseBasis: "undetermined", licenseNote: e.licenseNote, operatingSystem: e.operatingSystem,
    operatingSystemVersion: e.operatingSystemVersion, packageFiles: rows(e.packageFiles), platformPrerequisites: rows(e.platformPrerequisites),
    runtimeObjectHash: e.objectHash.toLowerCase(), softwareRasterization: true, toolchainName: e.toolchainName,
    toolchainPath: e.toolchainPath, toolchainSha256: e.toolchainSha256.toLowerCase(), toolchainVersion: e.toolchainVersion,
    version: 1, viewportHeight: e.viewportHeight.toString(), viewportWidth: e.viewportWidth.toString() });
}

test("canonical environment preserves original key order, literal controls, Unicode and decimal strings", () => {
  const e = environment();
  e.licenseNote = '\u0000\u0001\b\f\n\r\t"\\/é😀\u2028e\u0301';
  const raw = toUtf8String(referenceEnvironmentCanonicalBytes(e));
  assert.equal(raw, independentJSON(e));
  assert.match(raw, /"byteSize":"18446744073709551615"/);
  assert.match(raw, /"devicePixelRatio":"1"/); assert.match(raw, /"version":1,/);
  assert.ok(raw.includes('\\u0000\\u0001\\b\\f\\n\\r\\t\\"\\\\/é😀\u2028e\u0301'));
  for (const absent of ["coverageHash", "manifestHash", "manifestBytes"]) assert.equal(Object.hasOwn(JSON.parse(raw), absent), false);
  assert.equal(REFERENCE_ENVIRONMENT_CAPTURE_PROFILE, id("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"));
  assert.notEqual(referenceEnvironmentCanonicalBytes({ ...e, engineName: "e\u0301" }), referenceEnvironmentCanonicalBytes({ ...e, engineName: "é" }));
});

test("canonical construction preserves manifest placeholders while prepared snapshots require exact declarations", () => {
  const e = environment(), original = structuredClone(e), raw = referenceEnvironmentCanonicalBytes(e);
  assert.deepEqual(e, original); assert.deepEqual(normalizeReferenceEnvironment(e), original);
  assert.equal(referenceEnvironmentCanonicalBytes({ ...e, manifestHash: id("unknown yet"), manifestBytes: 4294967295n }), raw);
  assert.throws(() => prepareReferenceEnvironment(chainId, host, e), /manifest/);
  const complete = declared(e), snapshot = prepareReferenceEnvironment(chainId, host, complete);
  assert.equal(snapshot.canonical, raw); assert.equal(snapshot.contentHash, complete.manifestHash);
  assert.equal(snapshot.byteLength, complete.manifestBytes); assert.deepEqual(snapshot.environment, complete);
  assert.throws(() => prepareReferenceEnvironment(chainId, host, { ...complete, manifestHash: id("wrong bytes") }), /manifest/);
  assert.throws(() => prepareReferenceEnvironment(chainId, host, { ...complete, manifestBytes: complete.manifestBytes + 1n }), /manifest/);
});

test("original complete ABI identity includes declarations absent from JSON and uses the actual host", () => {
  const e = declared(), expected = keccak256(coder.encode(["bytes32", "uint256", "address", independentTuple],
    [id("6529STREAM_REFERENCE_ENVIRONMENT_PREPARATION_V1"), chainId, host, values(e)]));
  assert.equal(referenceEnvironmentId(chainId, host, e), expected);
  assert.equal(prepareReferenceEnvironment(chainId, host, e).environmentId, expected);
  assert.equal(coder.encode([REFERENCE_ENVIRONMENT_ABI_TUPLE], [e]), coder.encode([independentTuple], [values(e)]));
  for (const patch of [{ coverageHash: id("different coverage") }, { manifestHash: id("different manifest") }, { manifestBytes: e.manifestBytes + 1n }]) {
    assert.equal(referenceEnvironmentCanonicalBytes({ ...e, ...patch }), referenceEnvironmentCanonicalBytes(e));
    assert.notEqual(referenceEnvironmentId(chainId, host, { ...e, ...patch }), expected);
  }
  assert.notEqual(referenceEnvironmentId(chainId + 1n, host, e), expected);
  assert.notEqual(referenceEnvironmentId(chainId, getAddress("0x0000000000000000000000000000000000005678"), e), expected);
  const changed = { ...e, packageFiles: e.packageFiles.map((row, index) => index === 0 ? { ...row, byteSize: row.byteSize - 1n } : row) };
  assert.notEqual(referenceEnvironmentId(chainId, host, changed), expected);
});

test("both inventory snapshots use original complete arrays and original true/false host-bound identities", () => {
  const e = declared(), s = prepareReferenceEnvironment(chainId, host, e);
  assert.deepEqual(s.packageInventory, prepareReferenceInventory(chainId, host, true, e.packageFiles));
  assert.deepEqual(s.platformInventory, prepareReferenceInventory(chainId, host, false, e.platformPrerequisites));
  assert.equal(s.packageInventory.rows.length, 3); assert.equal(s.packageInventory.rows[2].byteSize, 0n);
  assert.equal(s.platformInventory.rows[0].byteSize, 0n);
  assert.notEqual(s.packageInventory.inventoryId, s.environmentId);
  assert.equal("authority" in s, false); assert.equal("current" in s, false);
});

test("membership requires matching positive-size package members and permits the same engine/toolchain member", () => {
  const e = environment();
  for (const patch of [{ engineExecutablePath: "absent.exe" }, { toolchainSha256: id("wrong digest") },
    { engineExecutablePath: "zero.txt", engineExecutableSha256: e.packageFiles[2].sha256Digest }]) {
    assert.throws(() => normalizeReferenceEnvironment({ ...e, ...patch }), /package members/);
  }
  const shared = { ...e, toolchainPath: e.engineExecutablePath, toolchainSha256: e.engineExecutableSha256 };
  assert.equal(normalizeReferenceEnvironment(shared).toolchainPath, shared.engineExecutablePath);
  assert.doesNotThrow(() => prepareReferenceEnvironment(chainId, host, declared(shared)));
  assert.throws(() => normalizeReferenceEnvironment({ ...e, packageFiles: [{ ...e.packageFiles[0], byteSize: 0n }, ...e.packageFiles.slice(1)] }), /package members/);
});

test("file arrays remain strictly ordered without sorting or discarding zero-size historical declarations", () => {
  const e = environment();
  assert.throws(() => normalizeReferenceEnvironment({ ...e, packageFiles: [] }), /nonempty/);
  assert.throws(() => normalizeReferenceEnvironment({ ...e, platformPrerequisites: [] }), /nonempty/);
  assert.throws(() => normalizeReferenceEnvironment({ ...e, packageFiles: [...e.packageFiles].reverse() }), /increasing/);
  assert.throws(() => normalizeReferenceEnvironment({ ...e, packageFiles: [e.packageFiles[0], ...e.packageFiles] }), /increasing/);
  assert.throws(() => normalizeReferenceEnvironment({ ...e, packageFiles: [{ ...e.packageFiles[0], path: "../engine.exe" }, ...e.packageFiles.slice(1)] }));
  const platform = ["\ue000", "😀"].map(path => ({ path, byteSize: 0n, sha256Digest: id(path) }));
  assert.doesNotThrow(() => normalizeReferenceEnvironment({ ...e, platformPrerequisites: platform }));
  // UTF-16's default order differs here; the source uses UTF-8 byte order.
  assert.throws(() => normalizeReferenceEnvironment({ ...e, platformPrerequisites: [...platform].reverse() }), /increasing/);
});

test("original Windows still-capture requirements and uint widths reject alternate or lossy values", () => {
  const e = environment();
  for (const patch of [{ objectHash: ZeroHash }, { coverageHash: ZeroHash }, { engineExecutableSha256: ZeroHash }, { toolchainSha256: ZeroHash },
    { operatingSystem: "windows" }, { architecture: "ARM64" }, { colorSpace: "sRGB" }, { devicePixelRatio: 2n },
    { softwareRasterization: false }, { softwareRasterization: 1 }, { captureProfile: id("other profile") },
    { viewportWidth: 0n }, { viewportHeight: 4097n }, { viewportWidth: 1n << 16n }, { devicePixelRatio: 1n << 8n },
    { manifestBytes: 1n << 32n }, { manifestBytes: -1n }, { viewportWidth: 1920 }, { manifestBytes: 0 },
    { manifestHash: "0x" }, { unexpected: "field" }]) assert.throws(() => normalizeReferenceEnvironment({ ...e, ...patch }));
  for (const chain of [0n, 1n << 256n, 6529]) assert.throws(() => referenceEnvironmentId(chain, host, e));
  assert.throws(() => referenceEnvironmentId(chainId, ZeroAddress, e));
});

test("every original quoted field is nonempty, scalar UTF-8 and bounded in bytes", () => {
  const e = environment();
  const textFields = ["engineName", "engineVersion", "toolchainName", "toolchainVersion", "engineExecutablePath", "toolchainPath",
    "operatingSystem", "operatingSystemVersion", "architecture", "colorSpace", "licenseNote"];
  for (const name of textFields) for (const value of ["", "\ud800", "\udc00"]) {
    assert.throws(() => normalizeReferenceEnvironment({ ...e, [name]: value }));
  }
  for (const [name, bound] of [["engineName", 256], ["engineVersion", 256], ["toolchainName", 256],
    ["toolchainVersion", 256], ["operatingSystemVersion", 128], ["licenseNote", 16384]]) {
    assert.doesNotThrow(() => normalizeReferenceEnvironment({ ...e, [name]: "a".repeat(bound) }));
    assert.throws(() => normalizeReferenceEnvironment({ ...e, [name]: "a".repeat(bound + 1) }), /UTF-8 bytes/);
  }
  assert.doesNotThrow(() => normalizeReferenceEnvironment({ ...e, engineName: "😀".repeat(64) }));
  assert.throws(() => normalizeReferenceEnvironment({ ...e, engineName: "😀".repeat(65) }), /UTF-8 bytes/);
  const path = "a".repeat(1024), row = { path, byteSize: 1n, sha256Digest: e.engineExecutableSha256 };
  const longPath = { ...e, engineExecutablePath: path, toolchainPath: path, toolchainSha256: row.sha256Digest, packageFiles: [row] };
  assert.doesNotThrow(() => normalizeReferenceEnvironment(longPath));
  assert.throws(() => normalizeReferenceEnvironment({ ...longPath, engineExecutablePath: path + "a" }), /1024/);
});

test("the complete canonical byte bound includes inventories, escaped text and closing brace", () => {
  const e = environment();
  e.packageFiles = [e.packageFiles[0], ...Array.from({ length: 450 }, (_, n) => ({
    path: `pkg/${n.toString().padStart(4, "0")}/` + "x".repeat(1015), byteSize: 0n, sha256Digest: id(`file ${n}`),
  })), ...e.packageFiles.slice(1)];
  const initialLength = (referenceEnvironmentCanonicalBytes(e).length - 2) / 2;
  const needed = REFERENCE_ENVIRONMENT_MAX_BYTES - initialLength + 1;
  assert.ok(needed > 0 && needed <= 16384);
  e.licenseNote = "a".repeat(needed);
  const atLimit = declared(e), s = prepareReferenceEnvironment(chainId, host, atLimit);
  assert.equal(s.byteLength, 524288n);
  assert.throws(() => referenceEnvironmentCanonicalBytes({ ...e, licenseNote: e.licenseNote + "a" }), /524288/);
  // One input control byte becomes six JSON bytes and must be counted after escaping.
  assert.throws(() => referenceEnvironmentCanonicalBytes({ ...e, licenseNote: e.licenseNote.slice(0, -1) + "\u0000" }), /524288/);
});

test("snapshots deeply copy before awaits and reconstruct every label and embedded inventory", async () => {
  const e = declared(), s = prepareReferenceEnvironment(chainId, host, e), saved = structuredClone(s);
  e.packageFiles[0].byteSize = 1n; e.platformPrerequisites[0].path = "changed"; e.engineName = "changed";
  await Promise.resolve();
  assert.deepEqual(s, saved);
  for (const value of [s, s.environment, s.environment.packageFiles, s.environment.packageFiles[0], s.environment.platformPrerequisites,
    s.packageInventory, s.packageInventory.rows, s.packageInventory.rows[0], s.platformInventory, s.platformInventory.rows]) {
    assert.equal(Object.isFrozen(value), true);
  }
  assert.deepEqual(normalizeReferenceEnvironmentSnapshot(structuredClone(s)), s);
  for (const patch of [{ canonical: "0x" }, { contentHash: ZeroHash }, { environmentId: ZeroHash }, { byteLength: s.byteLength + 1n },
    { packageInventory: { ...s.packageInventory, relative: false } }, { platformInventory: { ...s.platformInventory, inventoryId: ZeroHash } },
    { environment: { ...s.environment, coverageHash: id("changed coverage") } }, { prepared: true }]) {
    assert.throws(() => normalizeReferenceEnvironmentSnapshot({ ...s, ...patch }));
  }
});
