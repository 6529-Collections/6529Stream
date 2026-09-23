import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { AbiCoder, FunctionFragment, ParamType, concat, id, keccak256 } from "ethers";
import { rootInterludeFixture as f, rootInterludeReport as report, rootInterludeInterfaces as interfaces } from "./current-preservation-root-interlude-source-fixture.mjs";
import { setup } from "./current-preservation-root-interlude-transport-fixture.mjs";
import { preparePreservationRootInterludePacket } from "../examples/current-preservation-root-interlude-packet.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const utf8 = value => Buffer.from(value, "utf8");
const types = values => `(${values.map(p => ParamType.from(p).format("sighash")).join(",")})`;
const expectedContracts = {
  core: "StreamCore", registry: "StreamArtistOnboardingRegistry", coordinator: "StreamArtistOnboardingCoordinator",
  metadata: "StreamCollectionMetadataV1", router: "StreamMetadataRouter", artistSafe: "OfficialSafe",
  "identityOwner=owners[2]": "StreamArtistIdentityAuthority", "consentOwner=owners[6]": "StreamArtistConsentFinalityLifecycle",
  "output=graph.children[2]": "StreamPreservationPolicyOutputManifestV2",
  "snapshot=graph.children[3]": "StreamScopedPreservationPolicySnapshotPublicationV2",
};

test("root transport witness preserves exact original source report, tool and clarified manifest", () => {
  const bytes = readFileSync(new URL("./fixtures/current-preservation-root-interlude-source.json", import.meta.url));
  assert.equal(bytes.length, 1162161);
  assert.equal(sha(bytes), "6031aa72b4db7909a6643aa0d8ce3ee74985104078b1066361ddebf241697fef");
  assert.equal(f.sourceCommit, "61d0efc5c88db67126a1af2e3ccaa6d1ddecb41d");
  assert.equal(f.sourceTree, "9c45ed2cefaf73faadec15e49a72945f84310d0d");
  assert.equal(f.sourceReport.sha256, "5537434a6b43233bcc2c6f577659c18a045db0144c8dbb2c8d74d9f3ef82f5df");
  assert.equal(f.tool.sha256, "0c9d4afe6a5a9df72a5b560bda3fe5684fe63c378e6b4746aa8afcb753cda178");
  assert.equal(f.manifest.sha256, "51c4b4fd180da69b40b797666d0f99920798a9e554f410f737647bc026e26901");
  for (const entry of [f.sourceReport, f.tool, f.manifest]) {
    assert.equal(utf8(entry.text).length, entry.bytes); assert.equal(sha(utf8(entry.text)), entry.sha256);
  }
  assert.equal(f.compiler.sourceCommit, "a2973d360f6ab18881c04d58193f855704ec56d3");
  assert.equal(f.compiler.literalSources, 4059);
  assert.equal(f.compiler.inputSha256, "bdeb13c7467525241cfdc4fffe97e11aefbbd310972606eefe1ebebe47358234");
  assert.equal(f.compiler.outputSha256, "b6b473ed08be283b2efba661132193670d8f2ff2d39e06cd1bb6f31729573da6");
  assert.match(f.qualification, /not a complete linked-runtime closure/);
});

test("all reported and supplemental source pins remain separate from runtime admission", () => {
  const manifest = JSON.parse(f.manifest.text), pins = [...report.sourcePins, ...manifest.supplementalSourcePins];
  assert.equal(report.sourcePins.length, 41); assert.equal(manifest.supplementalSourcePins.length, 5);
  assert.equal(Object.keys(f.sources).length, 51);
  assert.equal(Object.values(f.sources).reduce((sum, s) => sum + s.bytes, 0), 942042);
  for (const [path, source] of Object.entries(f.sources)) {
    assert.equal(utf8(source.text).length, source.bytes, path); assert.equal(sha(utf8(source.text)), source.sha256, path);
  }
  for (const pin of pins) {
    assert.equal(f.sources[pin.path].sha256, pin.sha256, pin.path); assert.equal(f.sources[pin.path].bytes, pin.bytes, pin.path);
  }
  assert.equal(manifest.status, "OFFLINE_TOOL_TESTS_PASS_REAL_RPC_NOT_RUN");
  assert.equal(manifest.documentationAmendment.toolBehaviorChanged, false);
  assert.equal(manifest.documentationAmendment.previousManifestSha256, "b1b6451bb9799e08f9d3f979a187895c12d66c136fe3fa0a3ddf7ae9075dc5dc");
});

test("all thirty-five selected ordinary compiler functions retain original layouts and selectors", () => {
  assert.equal(f.methods.length, 35); assert.equal(report.abi.length, 35);
  for (const entry of f.methods) {
    const original = report.abi.find(e => e.target === entry.target && e.signature === entry.signature);
    assert.ok(original); assert.equal(entry.contract, expectedContracts[entry.target]);
    assert.equal(entry.abi.type, "function");
    const fn = FunctionFragment.from(entry.abi);
    assert.equal(fn.format("sighash"), original.signature);
    assert.equal(id(original.signature).slice(0, 10), original.selector);
    assert.equal(entry.selector, original.selector); assert.equal(types(entry.abi.outputs), original.returns);
    assert.equal(f.sources[entry.source].sha256, entry.compilerSourceSha256);
  }
  for (const [domain, hash] of Object.entries(report.constants)) assert.equal(id(domain), hash);
  const writes = f.methods.filter(m => !["view", "pure"].includes(m.abi.stateMutability));
  assert.deepEqual(writes.map(m => m.signature), [
    "recordContentConsent((uint256,address,bytes32,bytes32),(uint256,uint64,bytes))",
    "publishVerifiedPreservationPolicyContentRoot((uint256,bytes32,bytes32,string))",
    "publishScopedPreservationPolicyContentRootPublication(((uint8,uint256,uint256,bytes32),bytes32,bytes32,uint64,string))",
    "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)",
  ]);
});

test("portable synthetic inputs keep their exact source identities without becoming deployment defaults", () => {
  const manifest = JSON.parse(f.manifest.text);
  assert.equal(Object.keys(f.syntheticInputs).length, 4);
  for (const [path, entry] of Object.entries(f.syntheticInputs)) {
    const expected = manifest.files.find(row => row.path === path); assert.ok(expected);
    assert.equal(sha(utf8(entry.text)), expected.sha256); assert.equal(entry.sha256, expected.sha256);
    assert.equal(utf8(entry.text).length, expected.bytes); assert.equal(entry.bytes, expected.bytes);
    assert.match(path, /^example\.synthetic\.(collection|scoped)\.(admission|request)\.json$/);
  }
});

// Independent ABI and manual EIP-712 oracles deliberately do not import adapter
// fragments, Safe types, hash helpers or expected fixture outputs.
const paths = [["collection", "consent"], ["scoped", "consent"], ["collection", "root"], ["scoped", "root"]];
const high = { chainId: (1n << 180n) + 37n, nonce: (1n << 230n) + 5n, collectionId: (1n << 220n) + 9n, safeTxGas: (1n << 200n) + 3n };
const prepare = s => preparePreservationRootInterludePacket(s.packetText, s.manifest, { expectedPacketSha256: s.expectedPacketSha256 });

test("all closed inner routes match genuine compiler ABI with full-width integer inputs", () => {
  for (const [kind, phase] of paths) {
    const s = setup(kind, phase, high), p = prepare(s), original = s.packet;
    const role = phase === "consent" ? "registry" : "router";
    const method = phase === "consent" ? "recordContentConsent" : kind === "collection"
      ? "publishVerifiedPreservationPolicyContentRoot" : "publishScopedPreservationPolicyContentRootPublication";
    const args = phase === "consent" ? [original.consent, original.authorization] : [original.request.publication];
    const calldata = interfaces[role].encodeFunctionData(method, args);
    assert.equal(p.inner.data, calldata);
    assert.equal(p.inner.to, original.admission.roles[role].address);
    assert.equal(p.transaction.data, calldata);
    assert.equal(p.transaction.safeTxGas, high.safeTxGas);
    const decoded = interfaces[role].decodeFunctionData(method, calldata);
    const collectionId = kind === "scoped" && phase === "root" ? decoded[0][0][1] : decoded[0][0];
    assert.equal(collectionId, high.collectionId);
  }
});

test("manual original Safe domain and struct hashing join all ten packet fields", () => {
  const abi = AbiCoder.defaultAbiCoder();
  const domainType = id("EIP712Domain(uint256 chainId,address verifyingContract)");
  const safeType = id("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)");
  for (const [kind, phase] of paths) for (const options of [{}, high]) {
    const s = setup(kind, phase, options), p = prepare(s), tx = s.packet.unsigned.transaction;
    const domain = keccak256(abi.encode(["bytes32", "uint256", "address"], [domainType, s.packet.chainId, s.packet.unsigned.safe]));
    const structure = keccak256(abi.encode(
      ["bytes32", "address", "uint256", "bytes32", "uint8", "uint256", "uint256", "uint256", "address", "address", "uint256"],
      [safeType, tx[0], tx[1], keccak256(tx[2]), ...tx.slice(3)],
    ));
    assert.equal(p.expectedSafeTxHash, keccak256(concat(["0x1901", domain, structure])));
    assert.equal(p.transaction.nonce, tx[9]);
    assert.equal(p.safe.nonce, tx[9]);
    assert.equal(p.deploymentProvenanceIndependentlyVerified, false);
    assert.equal(p.originalProtocolStateIndependentlyVerified, false);
  }
});

test("transport saves the genuine payable Safe envelope while leaving signatures and protocol evidence unverified", async () => {
  for (const [kind, phase] of paths) {
    const s = setup(kind, phase, high), captured = await s.driver.capturePacket(s.packetText, { expectedPacketSha256: s.expectedPacketSha256 });
    const input = s.signed(), saved = await s.driver.saveSignedEnvelope(captured.id, input);
    const decoded = interfaces.artistSafe.decodeFunctionData("execTransaction", input.data);
    assert.equal(interfaces.artistSafe.getFunction("execTransaction").stateMutability, "payable");
    assert.deepEqual(Array.from(decoded).slice(0, 9).map(v => typeof v === "string" ? v.toLowerCase() : v), s.packet.unsigned.transaction.slice(0, 9));
    assert.equal(interfaces.artistSafe.encodeFunctionData("execTransaction", decoded), saved.transaction.data);
    assert.equal(saved.nonce, s.packet.unsigned.transaction[9]);
    assert.equal(saved.signedEnvelopeHash, keccak256(input.data));
    assert.equal(saved.ownerSignaturesVerified, false);
    const mined = s.mine(saved), observed = await s.driver.inspectSubmission(saved.id, mined.hash);
    assert.equal(observed.outcome, "success");
    assert.equal(observed.originalProtocolReceiptVerified, false);
    assert.equal(observed.applicationEventSchemasAuthenticated, false);
  }
});
