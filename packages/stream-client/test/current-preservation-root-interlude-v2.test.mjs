import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { AbiCoder, FunctionFragment, Interface, ParamType, concat, id, keccak256 } from "ethers";
import * as oldPacket from "../examples/current-preservation-root-interlude-packet.mjs";
import * as packetModule from "../examples/current-preservation-root-interlude-packet-v2.mjs";
import { createPreservationRootInterludeTransport } from "../examples/current-preservation-root-interlude-transport-v2.mjs";
import { setup as oldSetup, canonical } from "./current-preservation-root-interlude-transport-fixture.mjs";
import { rootInterludeFixture as oldFixture } from "./current-preservation-root-interlude-source-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const bytes = readFileSync(new URL("./fixtures/current-preservation-root-interlude-v2-source.json", import.meta.url));
const f = JSON.parse(bytes), manifest = JSON.parse(f.manifest.text), report = JSON.parse(f.evidence["source-plan.json"].text);
const paths = [["collection", "consent"], ["scoped", "consent"], ["collection", "root"], ["scoped", "root"]];
const interfaces = Object.fromEntries([...new Set(f.methods.map(m => m.target))].map(target => [target, new Interface(f.methods.filter(m => m.target === target).map(m => m.abi))]));
const high = { chainId: (1n << 180n) + 37n, nonce: (1n << 230n) + 5n, collectionId: (1n << 220n) + 9n };
const exactJson = text => JSON.parse(text, (_key, value, context) => typeof value === "number" ? BigInt(context.source) : value);

function setup(kind = "collection", phase = "consent", options = {}) {
  const s = oldSetup(kind, phase, options), p = s.packet;
  p.admission = exactJson(f.syntheticInputs[`example.synthetic.${kind}.admission.json`].text);
  p.admission.chainId = p.chainId;
  p.sourceCommit = packetModule.PRESERVATION_ROOT_INTERLUDE_SOURCE_COMMIT;
  p.sourceReportSha256 = packetModule.PRESERVATION_ROOT_INTERLUDE_SOURCE_REPORT_SHA256;
  p.toolSha256 = packetModule.PRESERVATION_ROOT_INTERLUDE_TOOL_SHA256;
  p.admissionHash = sha(canonical(p.admission)); p.admissionFileSha256 = p.admissionHash;
  s.manifest = { ...s.manifest, sourceCommit: p.sourceCommit, sourceReportSha256: p.sourceReportSha256,
    toolSha256: p.toolSha256, admissionHash: p.admissionHash };
  s.packetText = s.text(); s.expectedPacketSha256 = sha(s.packetText);
  s.driver = createPreservationRootInterludeTransport({ provider: s.provider, manifest: s.manifest });
  s.capture = () => s.driver.capturePacket(s.text(), { expectedPacketSha256: sha(s.text()) });
  return s;
}
const prepare = s => packetModule.preparePreservationRootInterludePacket(s.text(), s.manifest, { expectedPacketSha256: sha(s.text()) });
const options = { blockTag: 11, gasLimit: 4_000_000n };

test("v2 retains exact reviewed source/tool identities and all portable evidence hashes", () => {
  assert.equal(bytes.length, 1373751); assert.equal(sha(bytes), "3318f5aa60deb4288dd807e91d74172a5eff99c24c5cb5593a4da954aa2efb5b");
  assert.equal(f.sourceCommit, "eda052c75dc9fd5c4e2e658bdf453ab01f5b7c0e");
  assert.equal(f.sourceTree, "1a71ae4ee9806c601237129d81e494058c547ee0");
  assert.equal(f.manifest.sha256, "cd955be78e90fe333276c3731581cb71799586d96bcba7d1c27fe4abe3dc1a55");
  assert.equal(manifest.files.length, 27); assert.equal(manifest.toolVersion, 2);
  assert.equal(f.evidence["interlude.py"].sha256, packetModule.PRESERVATION_ROOT_INTERLUDE_TOOL_SHA256);
  assert.equal(f.evidence["source-plan.json"].sha256, packetModule.PRESERVATION_ROOT_INTERLUDE_SOURCE_REPORT_SHA256);
  assert.equal(f.evidence["evidence/source-abi-rejoin-review.json"].sha256, "2e195215ce94bfc626a10c638aa104da70e35aeee9d6a19161256edbdf10c35e");
  for (const [path, entry] of Object.entries({ ...f.evidence, ...f.syntheticInputs })) {
    const pin = manifest.files.find(row => row.path === path); assert.ok(pin);
    assert.equal(sha(entry.text), pin.sha256); assert.equal(entry.sha256, pin.sha256);
    assert.equal(Buffer.byteLength(entry.text), pin.bytes); assert.equal(entry.bytes, pin.bytes);
  }
  assert.equal(sha(f.manifest.text), f.manifest.sha256);
});

test("all59 reviewed raw sources and35 genuine ABI164 declarations remain qualified source evidence", () => {
  assert.equal(report.sourcePins.length, 59); assert.equal(Object.keys(f.sources).length, 59);
  assert.equal(Object.values(f.sources).reduce((n, row) => n + row.bytes, 0), 1032076);
  for (const pin of report.sourcePins) {
    const source = f.sources[pin.path]; assert.equal(sha(source.text), pin.sha256);
    assert.equal(Buffer.byteLength(source.text), pin.bytes); assert.equal(source.sha256, pin.sha256);
  }
  assert.equal(f.compiler.literalSources, 4119);
  assert.equal(f.compiler.inputSha256, "5fd1a5370ea1df068958317c48f67120e5cf9199ffe8e99ef5b99657b824374c");
  assert.equal(f.compiler.outputSha256, "9ccdd82f1dee6b2d3a1b5ff3562417f64db27d72903b8fe2c8c06387b293ca90");
  assert.equal(f.methods.length, 35);
  for (const method of f.methods) {
    assert.equal(FunctionFragment.from(method.abi).format("sighash"), method.signature);
    assert.equal(id(method.signature).slice(0, 10), method.selector);
    assert.equal(`(${method.abi.outputs.map(p => ParamType.from(p).format("sighash")).join(",")})`, method.returns);
    assert.equal(sha(f.sources[method.source].text), method.compilerSourceSha256);
    const prior = oldFixture.methods.find(row => row.target === method.target && row.signature === method.signature);
    assert.deepEqual(method.abi, prior.abi);
  }
  assert.match(f.qualification, /not a complete linked-runtime closure/);
});

test("strict v2 derivatives preserve all original bytes except the reviewed constants and import", () => {
  const read = name => readFileSync(new URL(`../examples/current-preservation-root-interlude-${name}.mjs`, import.meta.url), "utf8");
  const packet = read("packet"), transport = read("transport");
  assert.equal(sha(packet), "ad828865120d54d4c0f89f4109819182ebbf92c5c8e3d9575ed1e2fd19dab5ce");
  assert.equal(sha(transport), "3c7188751b4372075332e3ae1f42ff2439923a729649e08cdc899affbcc440ad");
  let expected = packet;
  for (const key of ["PRESERVATION_ROOT_INTERLUDE_SOURCE_COMMIT", "PRESERVATION_ROOT_INTERLUDE_SOURCE_REPORT_SHA256", "PRESERVATION_ROOT_INTERLUDE_TOOL_SHA256"]) {
    assert.equal(expected.split(oldPacket[key]).length, 2); expected = expected.replace(oldPacket[key], packetModule[key]);
  }
  assert.equal(read("packet-v2"), expected);
  assert.equal(read("transport-v2"), transport.replace("'./current-preservation-root-interlude-packet.mjs'", "'./current-preservation-root-interlude-packet-v2.mjs'"));
  assert.equal(packetModule.PRESERVATION_ROOT_INTERLUDE_CAST_SHA256, oldPacket.PRESERVATION_ROOT_INTERLUDE_CAST_SHA256);
});

test("original Python tool algorithm restores byte-for-byte while v1 input and source evidence remain intact", () => {
  const v2 = f.evidence["interlude.py"].text;
  const before = packetModule.PRESERVATION_ROOT_INTERLUDE_SOURCE_REPORT_SHA256;
  assert.equal(v2.split(before).length, 2);
  assert.equal(v2.replace(before, oldPacket.PRESERVATION_ROOT_INTERLUDE_SOURCE_REPORT_SHA256), oldFixture.tool.text);
  for (const kind of ["collection", "scoped"]) {
    const path = `example.synthetic.${kind}.request.json`;
    assert.equal(f.syntheticInputs[path].text, oldFixture.syntheticInputs[path].text);
    const admission = exactJson(f.syntheticInputs[`example.synthetic.${kind}.admission.json`].text);
    assert.equal(admission.sourceCommit, f.sourceCommit);
    assert.equal(admission.sourceReportSha256, packetModule.PRESERVATION_ROOT_INTERLUDE_SOURCE_REPORT_SHA256);
  }
});

test("v2 four routes bind compiler calldata and independently hashed full-width Safe fields", () => {
  const abi = AbiCoder.defaultAbiCoder();
  for (const [kind, phase] of paths) {
    const s = setup(kind, phase, high), p = prepare(s), original = s.packet, tx = original.unsigned.transaction;
    const role = phase === "consent" ? "registry" : "router";
    const method = phase === "consent" ? "recordContentConsent" : kind === "collection" ? "publishVerifiedPreservationPolicyContentRoot" : "publishScopedPreservationPolicyContentRootPublication";
    const args = phase === "consent" ? [original.consent, original.authorization] : [original.request.publication];
    assert.equal(p.inner.data, interfaces[role].encodeFunctionData(method, args));
    const domain = keccak256(abi.encode(["bytes32", "uint256", "address"], [id("EIP712Domain(uint256 chainId,address verifyingContract)"), original.chainId, original.unsigned.safe]));
    const structure = keccak256(abi.encode(["bytes32", "address", "uint256", "bytes32", "uint8", "uint256", "uint256", "uint256", "address", "address", "uint256"],
      [id("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"), tx[0], tx[1], keccak256(tx[2]), ...tx.slice(3)]));
    assert.equal(p.expectedSafeTxHash, keccak256(concat(["0x1901", domain, structure])));
    assert.equal(p.sourceCommit, f.sourceCommit); assert.equal(p.transaction.nonce, high.nonce);
  }
});

test("both strict versions reject foreign, mixed and unreviewed source identities", () => {
  const old = oldSetup(), current = setup();
  assert.throws(() => oldPacket.preparePreservationRootInterludePacket(current.text(), current.manifest, { expectedPacketSha256: sha(current.text()) }), /Source commit/);
  assert.throws(() => prepare(old), /Source commit/);
  for (const key of ["sourceCommit", "sourceReportSha256", "toolSha256"]) {
    const mixed = setup(); mixed.manifest[key] = old.manifest[key]; assert.throws(() => prepare(mixed));
    const changedPacket = setup(); changedPacket.packet[key] = old.packet[key]; assert.throws(() => prepare(changedPacket));
  }
  const unknown = setup(); unknown.manifest.sourceCommit = "f".repeat(40); unknown.packet.sourceCommit = unknown.manifest.sourceCommit;
  assert.throws(() => prepare(unknown), /Source commit/);
});

test("v2 transport captures and sends only the exact original Safe envelope for all four routes", async () => {
  for (const [kind, phase] of paths) {
    const s = setup(kind, phase, high), p = await s.capture(), input = s.signed(), e = await s.driver.saveSignedEnvelope(p.id, input);
    const decoded = interfaces.artistSafe.decodeFunctionData("execTransaction", e.transaction.data);
    assert.equal(interfaces.artistSafe.encodeFunctionData("execTransaction", decoded), input.data);
    assert.equal(e.nonce, high.nonce); assert.equal(e.ownerSignaturesVerified, false);
    const simulation = await s.driver.simulateSavedEnvelope(e.id, options); assert.equal(simulation.safeInnerSucceeded, true);
    const sent = []; await s.driver.submitSavedEnvelope(e.id, { sendTransaction: tx => { sent.push(tx); return id("v2-outer-tx"); } }, { ...options, nonce: 77n });
    assert.equal(sent.length, 1); assert.equal(sent[0].data, input.data); assert.equal(sent[0].nonce, 77n);
    const mined = s.mine(e), observed = await s.driver.inspectSubmission(e.id, mined.hash);
    assert.equal(observed.outcome, "success"); assert.equal(observed.targetApplicationLogs, 1);
    assert.equal(observed.originalProtocolReceiptVerified, false); assert.equal(observed.priorConsentReceiptIndependentlyVerified, false);
    assert.equal(observed.applicationEventSchemasAuthenticated, false); assert.equal(observed.intraBlockTraceProven, false);
  }
});

test("v2 source refusal precedes provider observations and arbitrary signed fields stay closed", async () => {
  const bad = setup(); bad.packet.sourceCommit = oldPacket.PRESERVATION_ROOT_INTERLUDE_SOURCE_COMMIT;
  let networkReads = 0; bad.state.networkHook = () => { networkReads++; };
  await assert.rejects(bad.capture, /sourceCommit/); assert.equal(networkReads, 0);
  const s = setup(), p = await s.capture();
  for (const change of [{ value: 1n }, { operation: 1n }, { data: "0x12345678" }, { nonce: 9n }]) {
    await assert.rejects(() => s.driver.saveSignedEnvelope(p.id, s.signed(change)), /ten packet fields/);
  }
});

test("v2 retains separate outer-revert retry and consumed-nonce failure observations", async () => {
  for (const phase of ["consent", "root"]) {
    const s = setup("collection", phase), p = await s.capture(), e = await s.driver.saveSignedEnvelope(p.id, s.signed());
    const mined = s.mine(e, { outcome: "revert" }), r = await s.driver.inspectSubmission(e.id, mined.hash);
    assert.equal(r.safeSignaturesRetryable, true); assert.equal(r.gs013ReceiptCauseProven, false); assert.equal(r.rollbackIndependentlyProven, false);
    const t = setup("scoped", phase, { safeTxGas: 200_000n }), captured = await t.capture(), saved = await t.driver.saveSignedEnvelope(captured.id, t.signed());
    const failed = t.mine(saved, { outcome: "failure" }), receipt = await t.driver.inspectSubmission(saved.id, failed.hash);
    assert.equal(receipt.outcome, "safe-execution-failure"); assert.equal(receipt.safeSignaturesRetryable, false);
    await assert.rejects(() => t.driver.simulateSavedEnvelope(saved.id, { ...options, blockTag: 12 }), /nonce consumed/);
  }
});
