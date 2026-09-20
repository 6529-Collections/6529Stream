import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroHash, concat, getAddress, getBytes, id, keccak256 } from "ethers";
import { prepareReferenceEnvironment, referenceEnvironmentId, referenceEnvironmentCanonicalBytes, REFERENCE_ENVIRONMENT_ABI_TUPLE } from "../dist/current-reference-environment.js";
import { createReferenceEnvironmentSafeReview } from "../examples/current-reference-environment.mjs";
import { verifySafeCallPlan } from "../dist/safe-plan.js";
import { referenceEnvironmentCorpus } from "../scripts/generate-current-reference-environment-corpus.mjs";

const read = name => JSON.parse(readFileSync(new URL(`./fixtures/${name}.json`, import.meta.url), "utf8"));
const fixture = read("current-reference-environment-abi"), old = read("current-reference-inventory-abi");
const corpus = read("current-reference-environment-corpus"), inventories = read("current-reference-inventory-corpus");
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, rows]) => [key, new Interface(rows)]));
const coder = AbiCoder.defaultAbiCoder(), A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`), chainId = (1n << 237n) + 31337n, host = A(10);
const fields = ["objectHash", "coverageHash", "manifestHash", "manifestBytes", "engineName", "engineVersion", "engineExecutableSha256",
  "toolchainName", "toolchainVersion", "toolchainSha256", "engineExecutablePath", "toolchainPath", "packageFiles", "platformPrerequisites",
  "operatingSystem", "operatingSystemVersion", "architecture", "viewportWidth", "viewportHeight", "devicePixelRatio", "colorSpace",
  "softwareRasterization", "captureProfile", "licenseNote"];
function originalEnvironment() {
  const environment = { ...corpus.fields, coverageHash: id("synthetic test coverage; not a live coverage claim") };
  for (const name of ["manifestBytes", "viewportWidth", "viewportHeight", "devicePixelRatio"]) environment[name] = BigInt(environment[name]);
  for (const name of ["packageFiles", "platformPrerequisites"]) environment[name] = inventories.inventories[name].rows.map(row => ({ ...row, byteSize: BigInt(row.byteSize) }));
  return environment;
}
function smallEnvironment() {
  const environment = { ...originalEnvironment(), manifestHash: ZeroHash, manifestBytes: 0n,
    packageFiles: [{ path: "engine/chrome.exe", byteSize: (1n << 64n) - 1n, sha256Digest: corpus.fields.engineExecutableSha256 },
      { path: "tool/reference_capture.py", byteSize: 1n, sha256Digest: corpus.fields.toolchainSha256 }],
    platformPrerequisites: [{ path: "C:\\Windows\\é.dll", byteSize: 0n, sha256Digest: id("system digest") }] };
  const canonical = referenceEnvironmentCanonicalBytes(environment);
  return { ...environment, manifestHash: keccak256(canonical), manifestBytes: BigInt(getBytes(canonical).length) };
}

test("environment compiler fixture retains exact provenance and the complete original 24-field tuple", () => {
  assert.equal(fixture.sourceCommit, "dfe75d52a2baa3fc394b0a94140565cd3ce850f4"); assert.equal(fixture.sourceCount, 127);
  assert.equal(Object.keys(fixture.sources).length, 127); assert.equal(Object.values(fixture.abis).reduce((n, rows) => n + rows.length, 0), 33);
  assert.equal(fixture.inputSha256, "d8c2ec0ad23d30802f2f5d36a63c20a608a370449e449b281daeccb8f27a149f");
  assert.equal(fixture.outputSha256, "57a037664968f7d7f0ac96c7583732bff23d6f37edc550a5361327417c6c8f9b");
  const tuple = abi.host.getFunction("prepareEnvironment").inputs[0];
  assert.deepEqual(tuple.components.map(row => row.name), fields);
  assert.equal(tuple.format("sighash"), abi.environmentJson.getFunction("manifest").inputs[0].format("sighash"));
  assert.equal(abi.host.getFunction("prepareEnvironment").format("full"), abi.modeHost.getFunction("prepareEnvironment").format("full"));
  assert.equal(abi.companion.getFunction("prepareEnvironment").selector, abi.host.getFunction("prepareEnvironment").selector);
  const testInterface = new Interface([`function sample(${REFERENCE_ENVIRONMENT_ABI_TUPLE})`]);
  assert.equal(testInterface.getFunction("sample").inputs[0].format("sighash"), tuple.format("sighash"));
  assert.deepEqual(abi.host.getEvent("ReferenceEnvironmentPrepared").inputs.map(p => [p.name, p.type, p.indexed]), [
    ["schemaVersion", "uint16", false], ["environmentId", "bytes32", true], ["contentHash", "bytes32", false], ["byteLength", "uint32", false],
  ]);
});

test("additive environment capability retains every selected original inventory and Store ABI entry", () => {
  for (const name of ["host", "modeHost", "store"]) {
    const oldAbi = new Interface(old.abis[name]);
    for (const row of old.abis[name]) {
      const current = row.type === "function" ? abi[name].getFunction(row.name) : abi[name].getEvent(row.name);
      const previous = row.type === "function" ? oldAbi.getFunction(row.name) : oldAbi.getEvent(row.name);
      assert.equal(current.format("full"), previous.format("full"));
    }
  }
});

test("full 1048/102-row environment reproduces the exact retained 179418 canonical bytes", () => {
  const snapshot = prepareReferenceEnvironment(chainId, host, originalEnvironment()), raw = Buffer.from(getBytes(snapshot.canonical));
  assert.equal(snapshot.byteLength, 179418n); assert.equal(raw.length, corpus.canonicalByteLength);
  assert.equal(snapshot.contentHash, corpus.canonicalKeccak256);
  assert.equal(createHash("sha256").update(raw).digest("hex"), corpus.sourceEnvironmentSha256);
  assert.equal(snapshot.packageInventory.rows.length, 1048); assert.equal(snapshot.platformInventory.rows.length, 102);
  assert.deepEqual(referenceEnvironmentCorpus(raw, inventories), corpus);
  assert.equal(snapshot.environment.manifestHash, snapshot.contentHash); assert.equal(snapshot.environment.manifestBytes, snapshot.byteLength);
});

test("preparation identity uses the original compiled tuple, full widths, actual host and omitted JSON declarations", () => {
  const environment = smallEnvironment(), tuple = abi.host.getFunction("prepareEnvironment").inputs[0];
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", tuple],
    [id("6529STREAM_REFERENCE_ENVIRONMENT_PREPARATION_V1"), chainId, host, environment]));
  const snapshot = prepareReferenceEnvironment(chainId, host, environment);
  assert.equal(snapshot.environmentId, expected);
  for (const patch of [{ coverageHash: id("different attributed coverage") }, { manifestHash: id("different declared manifest") }, { manifestBytes: environment.manifestBytes + 1n }]) {
    const altered = { ...environment, ...patch };
    assert.equal(referenceEnvironmentCanonicalBytes(altered), snapshot.canonical);
    assert.notEqual(referenceEnvironmentId(chainId, host, altered), expected);
    if (patch.manifestHash || patch.manifestBytes) assert.throws(() => prepareReferenceEnvironment(chainId, host, altered));
  }
  assert.notEqual(referenceEnvironmentId(chainId + 1n, host, environment), expected);
  assert.notEqual(referenceEnvironmentId(chainId, A(11), environment), expected);
  assert.notEqual(snapshot.environmentId, snapshot.packageInventory.inventoryId);
  assert.notEqual(snapshot.environmentId, snapshot.platformInventory.inventoryId);
});

test("environment Safe example preserves original chunks, both prerequisite identities and separate actual callers", () => {
  const deployment = { chainId, publicationHost: { address: host, codeHash: id("host runtime") }, store: { address: A(20), codeHash: id("Store runtime") } };
  for (const publicationAbi of [fixture.abis.host, fixture.abis.modeHost]) {
    const result = createReferenceEnvironmentSafeReview({ deployment, environment: smallEnvironment(), uploaderSafe: A(21), preparerSafe: A(22), storeAbi: fixture.abis.store, publicationAbi });
    const plan = verifySafeCallPlan(result.safePlan, result.abis), p = result.preparation;
    const uploads = plan.steps.slice(0, -1), final = plan.steps.at(-1);
    const bytes = uploads.map(step => {
      assert.equal(step.safe, A(21)); assert.equal(step.transaction.to, A(20));
      assert.equal(step.transaction.value, "0"); assert.equal(step.transaction.operation, 0);
      return abi.store.decodeFunctionData("publishChunk", step.transaction.data)[0];
    });
    assert.equal(concat(bytes), p.snapshot.canonical);
    assert.equal(final.safe, A(22)); assert.equal(final.transaction.to, host); assert.equal(final.transaction.operation, 0);
    assert.equal(final.transaction.data, abi.host.encodeFunctionData("prepareEnvironment", [p.snapshot.environment]));
    assert.equal(result.prerequisites.packageInventory, p.snapshot.packageInventory.inventoryId);
    assert.equal(result.prerequisites.platformInventory, p.snapshot.platformInventory.inventoryId);
  }
});
