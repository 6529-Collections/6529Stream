import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroHash, concat, getAddress, id, keccak256, toBeHex } from "ethers";
import * as mode from "../dist/current-reference-mode-payload.js";
import { referenceEnvironmentCanonicalBytes } from "../dist/current-reference-environment.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-reference-mode-payload-abi.json", import.meta.url), "utf8"));
const historical = JSON.parse(readFileSync(new URL("./fixtures/current-reference-environment-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([name, rows]) => [name, new Interface(rows)]));
const coder = AbiCoder.defaultAbiCoder(), address = n => getAddress(toBeHex(n, 20));
const chainId = (1n << 249n) + 31337n, host = address(42), caller = address(84);
const pubType = abi.companion.getFunction("prepareModePublication").inputs[0];
const [, receiptType, sourceType, evidenceType, factsType] = abi.companion.getFunction("prepareModePayload").inputs;
const descriptorType = abi.companion.getFunction("preparedModePublication").outputs[0];
const componentType = "(bytes32,uint32,bytes32,uint32,bytes32,uint32,bytes32,uint32,bytes32,uint32,bytes32,uint32)";
const payloadTypes = ["bytes32", pubType, receiptType, sourceType, evidenceType, factsType, "bytes"];
const zeroed = { recordHash: ZeroHash, recordChainHash: ZeroHash, payloadHash: ZeroHash, payloadBytes: 0n, recordedAt: 0n };
const text = name => fixture.sourceTexts[`smart-contracts/domains/preservation/${name}.sol`];

// Values come from every compiler-owned component, independently of the client's handwritten tuples.
function vector(type, path = "root") {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(row => [row.name, vector(row, `${path}.${row.name}`)]));
  if (type.baseType === "array") return Array.from({ length: type.arrayLength === -1 ? 2 : type.arrayLength }, (_, i) => vector(type.arrayChildren, `${path}[${i}]`));
  if (type.type === "address") return address(21);
  if (type.type === "bool") return true;
  if (type.type === "string") return `Unicode é / ${path}`;
  if (type.type === "bytes") return "0xabcdef01020304";
  if (type.type === "bytes32") return id(path);
  if (type.type.startsWith("int")) return -(1n << BigInt(Number(type.type.slice(3)) - 2));
  if (type.type.startsWith("uint")) {
    const bits = Number(type.type.slice(4));
    return bits === 8 ? 1n : (1n << BigInt(bits - 2)) + 7n;
  }
  throw Error(`Unexpected original type ${type.type}`);
}
function environment() {
  const e = { objectHash: id("environment object"), coverageHash: id("environment coverage"), manifestHash: ZeroHash, manifestBytes: 0n,
    engineName: "Browser", engineVersion: "1", engineExecutableSha256: id("engine"), toolchainName: "Capture", toolchainVersion: "2",
    toolchainSha256: id("toolchain"), engineExecutablePath: "engine.exe", toolchainPath: "toolchain.exe",
    packageFiles: [{ path: "engine.exe", byteSize: 111n, sha256Digest: id("engine") }, { path: "toolchain.exe", byteSize: 222n, sha256Digest: id("toolchain") }],
    platformPrerequisites: [{ path: "C:\\Windows\\library.dll", byteSize: 333n, sha256Digest: id("platform") }],
    operatingSystem: "Windows", operatingSystemVersion: "Server", architecture: "AMD64", viewportWidth: 640n, viewportHeight: 480n,
    devicePixelRatio: 1n, colorSpace: "srgb", softwareRasterization: true, captureProfile: id("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"), licenseNote: "Original declarations" };
  const canonical = referenceEnvironmentCanonicalBytes(e);
  return { ...e, manifestHash: keccak256(canonical), manifestBytes: BigInt((canonical.length - 2) / 2) };
}
function inputs() {
  const publication = vector(pubType, "Publication");
  publication.environment = environment();
  for (const capture of publication.captures) capture.environmentManifestHash = publication.environment.manifestHash;
  return { publication, input: { receipt: vector(receiptType, "Receipt"), source: vector(sourceType, "SourceFacts"),
    evidence: vector(evidenceType, "Evidence"), facts: vector(factsType, "Facts") } };
}
function original(values) {
  const publicationRaw = coder.encode([pubType], [values.publication]);
  const normalized = { ...values.input.receipt, ...zeroed }, receiptRaw = coder.encode([receiptType], [normalized]);
  const environmentRaw = referenceEnvironmentCanonicalBytes(values.publication.environment);
  const rows = [[pubType, values.publication], [receiptType, normalized], [sourceType, values.input.source],
    [evidenceType, values.input.evidence], [factsType, values.input.facts]].map(([type, value]) => coder.encode([type], [value]));
  const components = [...rows, environmentRaw].flatMap(raw => [keccak256(raw), BigInt((raw.length - 2) / 2)]);
  const canonical = coder.encode(payloadTypes, [id("6529STREAM_REFERENCE_MODE_PAYLOAD_V1"), values.publication, normalized,
    values.input.source, values.input.evidence, values.input.facts, environmentRaw]);
  return { publicationRaw, receiptRaw, environmentRaw, normalized, rows, components, canonical };
}

test("Mode preparation fixture pins exact integrated ABI57 and preserves historical Environment source", () => {
  assert.equal(fixture.sourceCommit, "9beafd1ab5e5a5c8403f24958e49801f34625e66");
  assert.equal(fixture.sourceCount, 2248);
  assert.equal(fixture.inputSha256, "84adf2af8226b1f052b12546a4afdd2e58d05ac276a7f6705e5a55ff686f34df");
  assert.equal(fixture.outputSha256, "8ce143a79e67363cf84b0b8b6c7435006771c1acc1037dfdf14562d6b3c7b341");
  assert.equal(Object.keys(fixture.sourceHashes).length, 107); assert.equal(Object.keys(fixture.sourceTexts).length, 10);
  assert.equal(Object.values(fixture.abis).flat().length, 33);
  for (const [path, literal] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(literal).digest("hex"), fixture.sourceHashes[path]);
  for (const path of ["smart-contracts/domains/preservation/StreamReferenceRenderPreparation.sol",
    "smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol", "smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol"]) {
    assert.equal(fixture.sourceHashes[path], historical.sources[path], path);
  }
  assert.match(fixture.qualification, /confers no source or writer authority/);
});

test("all companion selectors, event tuple widths and own ERC165 identity match original compiler output", () => {
  const expected = { prepareModePublication: "0x7be6d49e", prepareModePayload: "0xc1d98193", preparedModePublication: "0xf9593e91", preparedModePayload: "0x73f4cd7c" };
  const client = new Interface(mode.CURRENT_REFERENCE_MODE_PAYLOAD_ABI);
  let interfaceId = 0n;
  for (const [name, selector] of Object.entries(expected)) {
    const method = abi.companion.getFunction(name);
    assert.equal(method.selector, selector); assert.equal(abi.host.getFunction(name).selector, selector);
    assert.equal(client.getFunction(name).format("sighash"), method.format("sighash"));
    assert.deepEqual(client.getFunction(name).outputs.map(v => v.format("sighash")), method.outputs.map(v => v.format("sighash")));
    interfaceId ^= BigInt(selector);
  }
  assert.equal(toBeHex(interfaceId, 4), mode.REFERENCE_MODE_PAYLOAD_PREPARATION_INTERFACE_ID);
  assert.equal(toBeHex(interfaceId, 4), "0x3092a6e0");
  assert.deepEqual(descriptorType.components.map(row => row.type), ["bytes32", "uint32", "bytes32", "bytes32", "uint32"]);
  assert.equal(abi.companion.getEvent("ReferenceModePublicationPrepared").inputs[1].indexed, true);
  assert.equal(abi.companion.getEvent("ReferenceModePayloadPrepared").inputs[2].indexed, true);
});

test("full original Publication, component identities and seven-field payload match compiler-owned tuples", () => {
  const values = inputs(), expected = original(values), publication = mode.prepareReferenceModePublication(chainId, host, values.publication);
  const payload = mode.prepareReferenceModePayload(publication, values.input);
  assert.equal(publication.canonical, expected.publicationRaw);
  assert.equal(publication.publicationPreparationId, keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "uint32"],
    [id("6529STREAM_REFERENCE_MODE_PUBLICATION_PREPARATION_V1"), chainId, host, keccak256(expected.publicationRaw), BigInt((expected.publicationRaw.length - 2) / 2)])));
  assert.equal(payload.canonical, expected.canonical);
  assert.equal(payload.contentHash, keccak256(expected.canonical));
  assert.equal(payload.payloadPreparationId, keccak256(coder.encode(["bytes32", "uint256", "address", componentType],
    [id("6529STREAM_REFERENCE_MODE_PAYLOAD_PREPARATION_V1"), chainId, host, expected.components])));
  assert.deepEqual(Object.values(payload.components), expected.components);
  assert.deepEqual(payload.input.receipt, expected.normalized);
  assert.equal(payload.input.evidence.perceptual.threshold, values.input.evidence.perceptual.threshold);
  assert.deepEqual(mode.decodeReferenceModePayload(chainId, host, expected.canonical), payload);
});

test("the fixed assembler's original 26-word head and ordered dynamic tails reproduce full ABI encoding", () => {
  const values = inputs(), expected = original(values);
  const tails = [expected.rows[0], ...expected.rows.slice(2), coder.encode(["bytes"], [expected.environmentRaw])];
  let cursor = 26n * 32n;
  const offsets = tails.map(raw => { const at = cursor; cursor += BigInt((raw.length - 2) / 2 - 32); return toBeHex(at, 32); });
  const assembled = concat([id("6529STREAM_REFERENCE_MODE_PAYLOAD_V1"), offsets[0], expected.receiptRaw,
    ...offsets.slice(1), ...tails.map(raw => `0x${raw.slice(66)}`)]);
  assert.equal(assembled, expected.canonical);
  assert.equal(cursor, BigInt((assembled.length - 2) / 2));
  assert.match(text("StreamReferenceModePayloadEncoding"), /uint256 length = 832/);
  assert.match(text("StreamReferenceModePayloadEncoding"), /uint256 word = i == 0 \? 1 : 21 \+ i/);
});

test("exactly five receipt fields are excluded and every other original receipt field changes the payload identity", () => {
  const values = inputs(), publication = mode.prepareReferenceModePublication(chainId, host, values.publication);
  const baseline = mode.prepareReferenceModePayload(publication, values.input);
  const assigned = [...text("StreamReferenceModePayloadEncoding").matchAll(/r\.(\w+) = 0;/g)].map(m => m[1]);
  assert.deepEqual(assigned, Object.keys(zeroed));
  for (const row of receiptType.components) {
    const value = values.input.receipt[row.name];
    const changed = typeof value === "bigint" ? value + 1n : row.type === "address" ? address(123) : id(`changed ${row.name}`);
    const payload = mode.prepareReferenceModePayload(publication, { ...values.input, receipt: { ...values.input.receipt, [row.name]: changed } });
    assert.equal(payload.payloadPreparationId === baseline.payloadPreparationId, Object.hasOwn(zeroed, row.name), row.name);
  }
});

test("ordinary preparation calls use complete original inputs and independent caller identity", () => {
  const values = inputs(), publication = mode.prepareReferenceModePublication(chainId, host, values.publication), payload = mode.prepareReferenceModePayload(publication, values.input);
  const first = mode.prepareReferenceModePublicationCall(publication, caller), second = mode.prepareReferenceModePayloadCall(payload, address(85));
  assert.deepEqual(first.call, { to: host, value: 0n, data: abi.host.encodeFunctionData("prepareModePublication", [values.publication]) });
  assert.deepEqual(second.call, { to: host, value: 0n, data: abi.host.encodeFunctionData("prepareModePayload", [publication.publicationPreparationId,
    payload.input.receipt, values.input.source, values.input.evidence, values.input.facts]) });
  assert.equal(first.caller, caller); assert.equal(second.caller, address(85));
  assert.equal(abi.host.getFunction("publishModeReference").inputs.length, 2);
  assert.equal(abi.host.getFunction("publishModeReference").inputs[0].format("sighash"), pubType.format("sighash"));
  assert.equal(abi.host.getFunction("publishModeReference").inputs[1].format("sighash"), evidenceType.format("sighash"));
});

test("preview's returned source hash and original fresh validation precede lookup of prepared bytes", () => {
  const preparation = text("StreamReferenceModePreparation");
  const staged = preparation.split("function prepareStaged(")[1].split("function _validate(")[0];
  assert.ok(staged.indexOf("_validate(") < staged.indexOf("Payload.lookup("));
  assert.match(preparation, /p\.expectedSourcesHash = result\.sourcesHash/);
  assert.match(preparation, /receipt\.sourcesHash = result\.sourcesHash/);
  assert.match(preparation, /writing && \(p\.expectedSourcesHash == 0 \|\| p\.expectedSourcesHash != result\.sourcesHash\)/);
  const values = inputs(), first = mode.prepareReferenceModePublication(chainId, host, values.publication);
  const returned = mode.prepareReferenceModePublication(chainId, host, { ...values.publication, expectedSourcesHash: id("observed returned source") });
  assert.notEqual(first.publicationPreparationId, returned.publicationPreparationId);
});

test("intact preparation retries still check original retained publication and Environment prerequisites", () => {
  const preparation = text("StreamReferenceModePayloadPreparation");
  const publicationRetry = preparation.split("if (saved.canonical.contentHash != 0)")[1].split("P.PublicationDescriptor memory descriptor")[0];
  assert.match(publicationRetry, /Bytes\.requireIntact\(saved\.canonical\)/);
  assert.match(publicationRetry, /_environment\(inventories, saved\.descriptor\)/);
  assert.doesNotMatch(publicationRetry, /emit/);
  const payload = preparation.split("function preparePayload(")[1].split("function lookup(")[0];
  assert.ok(payload.indexOf("Bytes.read(saved.canonical)") < payload.indexOf("if (state.payloads[id].contentHash != 0)"));
  assert.ok(payload.indexOf("_environment(inventories, descriptor)") < payload.indexOf("if (state.payloads[id].contentHash != 0)"));
  assert.match(preparation, /offset \+= 8192/);
  assert.match(preparation, /scratch\[0\] != 0 \|\| actual != chunkHash/);
  assert.match(preparation, /pointer\.code\.length != size \+ 1/);
});
