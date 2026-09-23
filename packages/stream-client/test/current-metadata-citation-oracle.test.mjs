import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import * as client from "../dist/current-metadata-citation.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-metadata-citation-abi.json", import.meta.url), "utf8"));
// Public library ABI parameters retain nominal types; the compiler's separate
// methodIdentifiers witness owns its selector, not ethers' contract ABI parser.
const abi = Object.fromEntries(Object.entries(fixture.abis).filter(([name]) => name !== "encoding").map(([name, entries]) => [name, new Interface(entries)]));
const coder = AbiCoder.defaultAbiCoder(), address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const hash = (types, values) => keccak256(coder.encode(types, values));
const source = name => fixture.sourceTexts[`smart-contracts/domains/metadata/${name}.sol`];
const governance = name => fixture.sourceTexts[`smart-contracts/domains/governance/${name}.sol`];
const registrationType = abi.currentRegistry.getFunction("registerCurrentCitation").inputs[0];
const readsType = abi.currentRegistry.getFunction("registerCurrentCitation").inputs[1];
const targetType = abi.registryInterface.getFunction("targetAt").outputs[0];
const targetsType = ParamType.from({ type: "tuple[]", components: targetType.components });
const requestType = abi.currentRenderer.getFunction("renderCurrent").inputs[0];
const versionType = abi.registryInterface.getFunction("version").outputs[0];
const recordType = abi.currentRegistry.getFunction("currentCitationRecord").outputs[0];
const callsType = abi.executor.getFunction("scheduleGovernanceBatch").inputs[1];
const actionIdentityType = abi.governanceIdentity.getFunction("governanceActionId").inputs[0];
// Source-declared internal envelopes. Neither has a public compiler ABI witness.
const analysisFields = [
  ["bytes32", "analysisProfile"], ["bytes32", "outputProfile"], ["bytes4", "selector"], ["address", "renderer"],
  ["bytes32", "runtimeHash"], ["address", "encoding"], ["bytes32", "encodingRuntimeHash"], ["bytes32", "readSetHash"],
  ["bytes32", "originalRegistrationHash"], ["bytes32", "toolHash"], ["bytes32", "findingsHash"], ["bool", "passed"],
];
const analysisType = ParamType.from({ type: "tuple", components: analysisFields.map(([type, name]) => ({ type, name })) });
const goldensType = ParamType.from({ type: "tuple[]", components: [
  { type: "tuple", name: "request", components: requestType.components }, { type: "uint8", name: "mode" }, { type: "bytes32", name: "outputHash" },
] });
const profile = id("6529STREAM_CURRENT_BASE_CITATION_V1"), analysisProfile = id("6529STREAM_CURRENT_BASE_CITATION_ANALYSIS_ABI_V1");
const renderSelector = abi.currentRenderer.getFunction("renderCurrent").selector;
const encoderSignature = "renderCurrent(IStreamRenderer.RenderRequest,StreamStaticRenderEncoding.Prepared,string,address,uint8)";
const encoderSelector = `0x${fixture.librarySelectorEvidence.methodIdentifiers[encoderSignature]}`;
const targetSetHash = targets => hash([targetsType], [targets]);
const readSetHash = (targets, reads) => hash(["bytes32", "bytes32", readsType], [id("6529STREAM_RENDERER_READ_SET_V1"), targetSetHash(targets), reads]);
function sample() {
  const targets = [{ target: address(90), codeHash: id("Core runtime"), role: id("CORE") },
    { target: address(100), codeHash: id("encoding runtime"), role: id("METADATA_COMPANION") }];
  const originalReads = [{ targetIndex: 0n, selector: "0x12345678", maxReturnBytes: 32n, exact: true }];
  const reads = [...originalReads, { targetIndex: 1n, selector: encoderSelector, maxReturnBytes: 2048n, exact: false }];
  const emptyRegistration = { versionKey: ZeroHash, profile: ZeroHash, selector: "0x00000000", encoding: ZeroAddress,
    encodingRuntimeHash: ZeroHash, analysisDocument: ZeroHash, goldenDocument: ZeroHash };
  const snapshot = { chainId: (1n << 230n) + 1n, registry: address(40), schemaRegistry: address(50), schemaRegistryCodeHash: id("schema runtime"),
    governanceExecutor: address(60), targets, originalReads,
    originalVersion: { exists: true, deprecated: false, renderer: address(70), runtimeHash: id("renderer runtime"), registrationHash: id("original registration"),
      readSetHash: readSetHash(targets, originalReads), analysisHash: id("original analysis"), goldenHash: id("original golden"), actionId: id("original action") },
    currentRecord: { registration: emptyRegistration, registrationHash: ZeroHash, readSetHash: ZeroHash, analysisHash: ZeroHash, goldenHash: ZeroHash, actionId: ZeroHash } };
  const registration = { versionKey: id("original version key"), profile, selector: renderSelector, encoding: address(100),
    encodingRuntimeHash: targets[1].codeHash, analysisDocument: id("current analysis document"), goldenDocument: id("current golden document") };
  const request = { core: address(90), tokenId: (1n << 256n) - 1n, collectionId: (1n << 220n) + 3n, collectionSerial: 99n,
    tokenHash: id("token identity"), state: 3n, mode: 2n, collectionSupplyMode: 1n, collectionStatus: 2n,
    viewId: ZeroHash, viewManifestHash: ZeroHash, metadataSnapshotHash: id("original snapshot field") };
  const goldens = [0n, 1n, 2n].map(mode => ({ request, mode, outputHash: id(`independently supplied output ${mode}`) }));
  const analysis = { analysisProfile, outputProfile: profile, selector: renderSelector, renderer: snapshot.originalVersion.renderer,
    runtimeHash: snapshot.originalVersion.runtimeHash, encoding: registration.encoding, encodingRuntimeHash: registration.encodingRuntimeHash,
    readSetHash: readSetHash(targets, reads), originalRegistrationHash: snapshot.originalVersion.registrationHash,
    toolHash: id("named analysis tool"), findingsHash: id("retained findings"), passed: true };
  return { snapshot, registration, reads, request, goldens, analysis };
}
function declaration(s, r, reads) {
  return hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "bytes32", registrationType, readsType],
    [id("6529STREAM_CURRENT_CITATION_REGISTRATION_V1"), s.chainId, s.registry, s.schemaRegistry, s.schemaRegistryCodeHash,
      targetSetHash(s.targets), s.originalVersion.registrationHash, r, reads]);
}
const stateHash = h => hash(["bytes32", "bytes32"], [id("6529STREAM_CURRENT_CITATION_STATE_V1"), h]);
const interfaceId = intf => { let n = 0n; intf.forEachFunction(f => { n ^= BigInt(f.selector); }); return `0x${n.toString(16).padStart(8, "0")}`; };

test("citation fixture and separate nominal library selector retain exact frozen source provenance", () => {
  assert.equal(fixture.sourceCommit, "680d5aaa7384438a6e1264bc17eca5a604abcb0f");
  assert.equal(fixture.sourceCount, 1055);
  assert.equal(fixture.inputSha256, "f90c651734bfc3e320bc0f3cbb856a5d13a55d0ac9034534e48ef53b8b8a0626");
  assert.equal(fixture.outputSha256, "549a36627ce9f8e35fbd0ac3851c9c8a5ccac1f3c38e2cf763c9c7d97cfdc174");
  assert.equal(Object.values(fixture.abis).reduce((n, rows) => n + rows.length, 0), 248);
  assert.equal(Object.keys(fixture.sourceHashes).length, 198); assert.equal(Object.keys(fixture.sourceTexts).length, 39);
  for (const [path, text] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(text).digest("hex"), fixture.sourceHashes[path]);
  const witness = fixture.librarySelectorEvidence;
  assert.equal(witness.artifactSha256, "25dbe8abd0de4abc4798305f128a202071e0a33a48151794a304f541be51ef9f");
  assert.equal(Object.keys(witness.sourceKeccak256).length, 15);
  for (const [path, expected] of Object.entries(witness.sourceKeccak256)) assert.equal(keccak256(toUtf8Bytes(fixture.sourceTexts[path])), expected);
  assert.equal(encoderSelector, "0x55bbfc11"); assert.equal(id(encoderSignature).slice(0, 10), encoderSelector);
  assert.notEqual(encoderSelector, renderSelector);
});

test("base work identity retains full unsigned decimal values and lowercase original Core bytes", () => {
  const max = (1n << 256n) - 1n, core = "0x0123456789aBCdef0123456789AbCdEf01234567";
  assert.equal(client.metadataWorkCitation(max, core.toLowerCase(), max), `eip155:${max}/erc721:${core.toLowerCase()}/${max}`);
  assert.equal(client.metadataWorkCitation(0n, ZeroAddress, 0n), `eip155:0/erc721:${ZeroAddress}/0`);
  assert.throws(() => client.metadataWorkCitation(max + 1n, address(1), 0n));
  assert.throws(() => client.metadataWorkCitation(1n, address(1), -1n));
  assert.match(source("StreamMetadataCitation"), /Strings\.toHexString\(uint256\(uint160\(originalCore\)\), 20\)/);
  assert.match(source("StreamMetadataCitation"), /Strings\.toString\(globalTokenId\)/);
});

test("all public tuple and interface constants match compiler ABI while internal evidence layouts match declarations", () => {
  for (const [name, type] of [["REGISTRATION", registrationType], ["READ", readsType.arrayChildren], ["TARGET", targetType],
    ["RENDER_REQUEST", requestType], ["VERSION", versionType], ["RECORD", recordType], ["GOVERNANCE_CALL", callsType.arrayChildren],
    ["ANALYSIS", analysisType], ["GOLDEN_VECTOR", goldensType.arrayChildren]]) {
    assert.equal(ParamType.from(client[`METADATA_CITATION_${name}_TUPLE`]).format("sighash"), type.format("sighash"), name);
  }
  const text = fixture.sourceTexts["smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol"];
  const declaration = text.match(/struct CurrentAnalysis\s*\{([^}]+)\}/)[1];
  assert.deepEqual([...declaration.matchAll(/(bytes32|bytes4|address|bool)\s+(\w+);/g)].map(m => [m[1], m[2]]), analysisFields);
  assert.match(text, /struct CurrentGoldenVector\s*\{\s*R\.RenderRequest request;\s*uint8 mode;\s*bytes32 outputHash;/);
  assert.equal(client.METADATA_CITATION_REGISTRY_INTERFACE_ID, interfaceId(abi.currentRegistry));
  assert.equal(client.METADATA_CITATION_RENDERER_INTERFACE_ID, interfaceId(abi.currentRenderer));
  assert.equal(client.METADATA_CITATION_RENDER_SELECTOR, renderSelector);
  assert.equal(client.METADATA_CITATION_ENCODING_SELECTOR, encoderSelector);
  const event = new Interface(client.CURRENT_METADATA_CITATION_ABI).getEvent("CurrentCitationRegistered");
  assert.equal(event.format("full"), abi.currentRegistry.getEvent("CurrentCitationRegistered").format("full"));
});

test("current declaration binds exact original read roster, source pins, old registration and hashed absence", () => {
  const { snapshot: s, registration: r, reads } = sample(), expected = declaration(s, r, reads);
  const plan = client.prepareMetadataCitationRegistration(s, r, reads);
  assert.equal(client.metadataCitationTargetSetHash(s.targets), targetSetHash(s.targets));
  assert.equal(client.metadataCitationReadSetHash(s.targets, reads), readSetHash(s.targets, reads));
  assert.equal(plan.registrationHash, expected); assert.equal(plan.readSetHash, readSetHash(s.targets, reads));
  assert.deepEqual(plan.transition, { scopeHash: hash(["bytes32", "uint256", "address", "bytes32"],
    [id("6529STREAM_CURRENT_CITATION_SCOPE_V1"), s.chainId, s.registry, r.versionKey]), oldValueHash: stateHash(ZeroHash), newValueHash: stateHash(expected) });
  assert.notEqual(plan.transition.oldValueHash, ZeroHash); assert.equal(plan.actionClass, 1n); assert.equal(plan.factsVerified, false);
  assert.equal(plan.targetCall.data, abi.currentRegistry.encodeFunctionData("registerCurrentCitation", [r, reads]));
  for (const changed of [{ ...s, chainId: s.chainId + 1n }, { ...s, registry: address(41) },
    { ...s, schemaRegistryCodeHash: id("changed schema code") }, { ...s, originalVersion: { ...s.originalVersion, registrationHash: id("changed original") } }]) {
    assert.notEqual(client.metadataCitationDeclarationHash(changed, r, reads), expected);
  }
  assert.throws(() => client.prepareMetadataCitationRegistration(s, r, reads.slice(1)), /original/);
  assert.throws(() => client.prepareMetadataCitationRegistration(s, r, [reads[0], { ...reads[1], selector: renderSelector }]), /encoder/);
});

test("analysis and all-three-mode golden bytes retain the distinct current canonical envelopes", () => {
  const { snapshot, registration, reads, analysis, goldens } = sample();
  const plan = client.prepareMetadataCitationRegistration(snapshot, registration, reads);
  const expectedAnalysis = coder.encode([analysisType], [analysis]), expectedGoldens = coder.encode([goldensType], [goldens]);
  const evidence = client.validateMetadataCitationEvidence(plan, analysis, goldens);
  assert.equal(evidence.analysisBytes, expectedAnalysis); assert.equal(evidence.goldenBytes, expectedGoldens);
  assert.equal(evidence.analysisHash, keccak256(expectedAnalysis)); assert.equal(evidence.goldenHash, keccak256(expectedGoldens));
  assert.deepEqual(client.decodeMetadataCitationAnalysis(expectedAnalysis), analysis);
  assert.deepEqual(client.decodeMetadataCitationGoldenVectors(expectedGoldens), goldens);
  assert.throws(() => client.decodeMetadataCitationAnalysis(`${expectedAnalysis}00`), /canonical|length/);
  assert.throws(() => client.decodeMetadataCitationGoldenVectors(`${expectedGoldens}00`), /canonical|length/);
  assert.throws(() => client.validateMetadataCitationEvidence(plan, { ...analysis, outputProfile: id("old profile") }, goldens));
  assert.throws(() => client.encodeMetadataCitationGoldenVectors([goldens[0], goldens[1], goldens[1]]), /three modes/);
  assert.throws(() => client.encodeMetadataCitationGoldenVectors([...goldens.slice(0, 2), { ...goldens[2], mode: 3n }]), /JSON/);
});

test("class1 governance batch and all three exact calls retain the original compiler-witnessed identity", () => {
  const { snapshot: s, registration: r, reads } = sample(), plan = client.prepareMetadataCitationRegistration(s, r, reads);
  const window = { notBefore: 172801n, expiresAfter: 777601n, reasonHash: id("reason"), reasonURI: "ipfs://citation-review", manifestHash: id("manifest") };
  const nonce = (1n << 240n) + 2n, batch = client.metadataCitationGovernanceBatch(plan, nonce, window), calls = [plan.governanceCall];
  const callsHash = hash(["bytes32", callsType], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain, field) => hash(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, calls.map(c => c[field])]);
  const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash");
  const oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash");
  const newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
  const identity = { actionClass: 1n, callsHash, scopeHash, oldValueHash, newValueHash, nonce,
    notBefore: window.notBefore, expiresAfter: window.expiresAfter, reasonHash: window.reasonHash, manifestHash: window.manifestHash };
  const actionId = hash(["bytes32", "uint256", "address", actionIdentityType], ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", s.chainId, s.governanceExecutor, identity]);
  assert.equal(batch.callsHash, callsHash); assert.equal(batch.actionId, actionId);
  assert.equal(batch.publicationKey, keccak256(keccak256(plan.targetCall.data)));
  assert.equal(batch.publicationCall.data, abi.executor.encodeFunctionData("publishGovernanceCallData", [[plan.targetCall.data]]));
  assert.equal(batch.scheduleCall.data, abi.executor.encodeFunctionData("scheduleGovernanceBatch", [1n, calls, scopeHash, oldValueHash, newValueHash, window.notBefore, window.expiresAfter, window.reasonHash, window.reasonURI, window.manifestHash]));
  assert.equal(batch.executionCall.data, abi.executor.encodeFunctionData("executeGovernanceBatch", [actionId, calls, [plan.targetCall.data]]));
  assert.match(governance("StreamGovernanceBootstrap"), /callDataKey = keccak256\(abi\.encodePacked\(hashes\)\)/);
  assert.doesNotThrow(() => client.assertMetadataCitationGovernanceWindow(window, 1n));
  assert.throws(() => client.assertMetadataCitationGovernanceWindow({ ...window, notBefore: window.notBefore - 1n }, 1n));
});

test("current record and render calls remain separate from old selectors and historical output", () => {
  const { snapshot, registration, reads, request } = sample(), registrationHash = declaration(snapshot, registration, reads);
  const record = { registration, registrationHash, readSetHash: readSetHash(snapshot.targets, reads), analysisHash: id("analysis"), goldenHash: id("goldens"), actionId: id("action") };
  const raw = coder.encode([recordType], [record]);
  assert.equal(client.encodeMetadataCitationRecord(record), raw); assert.deepEqual(client.decodeMetadataCitationRecord(raw), record);
  for (const mode of [0n, 1n, 2n, 3n]) {
    const call = client.prepareMetadataCitationRenderCall(snapshot.originalVersion.renderer, request, mode);
    assert.equal(call.data, abi.currentRenderer.encodeFunctionData("renderCurrent", [request, mode]));
    assert.notEqual(call.data.slice(0, 10), abi.renderer.getFunction("tokenURI").selector);
    assert.notEqual(call.data.slice(0, 10), abi.renderer.getFunction("renderView").selector);
  }
  assert.match(source("StreamRendererV1"), /return _render\(r, 1, false\)/);
  assert.match(source("StreamRendererV1"), /return _render\(r, mode, false\)/);
  assert.match(source("StreamRendererV1"), /return _render\(r, mode, true\)/);
  const retained = source("StreamRendererRegistry").split("function requireCurrentCitation")[1].split("function _currentDeclaration")[0];
  assert.match(retained, /bindingsInternal/); assert.doesNotMatch(retained, /_document\(|\.deprecated/);
});
