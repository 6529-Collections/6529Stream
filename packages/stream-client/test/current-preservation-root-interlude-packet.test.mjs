import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { AbiCoder, FunctionFragment, ZeroAddress, ZeroHash, concat, id, keccak256 } from "ethers";
import { rootInterludeInterfaces, rootInterludeSyntheticText } from "./current-preservation-root-interlude-source-fixture.mjs";
import {
  parsePreservationRootInterludePacket,
  preparePreservationRootInterludePacket,
  PRESERVATION_ROOT_INTERLUDE_MAX_PACKET_BYTES,
} from "../examples/current-preservation-root-interlude-packet.mjs";

// Manually assembled unsigned source-tool-shaped packets. No RPC/native/tool execution asserted.
const coder = AbiCoder.defaultAbiCoder();
const A = n => "0x" + n.toString(16).padStart(40, "0");
const H = name => id("root-interlude-test:" + name);
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const SOURCE = "61d0efc5c88db67126a1af2e3ccaa6d1ddecb41d";
const REPORT = "5537434a6b43233bcc2c6f577659c18a045db0144c8dbb2c8d74d9f3ef82f5df";
const TOOL = "0c9d4afe6a5a9df72a5b560bda3fe5684fe63c378e6b4746aa8afcb753cda178";
const CAST = "b2541a63789931fc4c170e2502c16c3be259f2da4daba1a8d05ea5cfa7729baa";
const SCOPE = "(uint8,uint256,uint256,bytes32)";
const CP = "(uint256,bytes32,bytes32,string)";
const SP = `(${SCOPE},bytes32,bytes32,uint64,string)`;
const CONSENT = "(uint256,address,bytes32,bytes32)";
const AUTH = "(uint256,uint64,bytes)";
const TX_TYPES = ["address", "uint256", "bytes", "uint8", "uint256", "uint256", "uint256", "address", "address", "uint256"];
function canonical(value) {
  if (typeof value === "bigint") return String(value);
  if (Array.isArray(value)) return "[" + value.map(canonical).join(",") + "]";
  if (value && typeof value === "object") return "{" + Object.keys(value).sort().map(k => JSON.stringify(k) + ":" + canonical(value[k])).join(",") + "}";
  return JSON.stringify(value);
}
const bytes = value => canonical(value) + "\n";
function calldata(signature, values) {
  return id(signature).slice(0, 10) + coder.encode(FunctionFragment.from(signature).inputs, values).slice(2);
}
function safeHash(chain, safe, tx) {
  const domain = keccak256(coder.encode(["bytes32", "uint256", "address"], [id("EIP712Domain(uint256 chainId,address verifyingContract)"), chain, safe]));
  // bytes data is hashed as a fixed bytes32 in the real struct preimage.
  const fixed = keccak256(coder.encode(["bytes32", "address", "uint256", "bytes32", ...TX_TYPES.slice(3)], [id("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"), tx[0], tx[1], keccak256(tx[2]), ...tx.slice(3)]));
  return keccak256(concat(["0x1901", domain, fixed]));
}
function fixture(phase = "consent", scopeType = 0n, version = "1.4.1") {
  const kind = scopeType === 0n ? "collection" : "scoped";
  const cid = (1n << 200n) + 19n;
  const scope = [scopeType, cid, scopeType === 1n ? (1n << 220n) + 3n : 0n, scopeType >= 2n ? H("scope") : ZeroHash];
  const original = part => JSON.parse(rootInterludeSyntheticText(kind, part), (_k, v, context) => typeof v === "number" ? BigInt(context.source) : v);
  const admission = original("admission"), roles = admission.roles;
  const request = original("request");
  request.scope = scope;
  request.publication[0] = kind === "collection" ? cid : scope;
  request.publication[request.publication.length - 1] = kind === "collection" ? "ar://literal/é/%2F" : "https://museum.example/作品#literal";
  request.expectedManifest[13] = scope;
  request.safeTxGas = (1n << 54n) + 11n;
  request.deadline = 9999n;
  const publication = request.publication;
  const p = {
    schemaVersion: 1n, phase, sourceReportSha256: REPORT, sourceCommit: SOURCE, castSha256: CAST,
    admission, request, admissionHash: sha(bytes(admission)), requestHash: sha(bytes(request)),
    chainId: 31337n, anchor: { number: 22n, hash: H("block"), timestamp: 1234n },
    rpcBlockId: { blockHash: H("block"), requireCanonical: true }, reads: [],
    limitations: ["Unsigned only; no transactions sent or keys handled.", "Block pin is not a state reservation.", "No native, gas, deployment, or state-import acceptance asserted."],
    aggregateBefore: [3n, H("aggregate")], toolSha256: TOOL,
    admissionFileSha256: sha("pretty admission bytes"), requestFileSha256: sha("pretty request bytes"),
  };
  let to, data;
  if (phase === "consent") {
    p.consent = [cid, roles.router.address, id("CONTENT_ROOT"), H("new-family")];
    p.authorization = [(1n << 240n) + 7n, request.deadline, "0x"];
    p.digest = H("consent-digest"); p.currentFamily = H("current-family");
    p.currentContent = [roles.router.address, H("content")]; p.evolution = [H("evolution"), H("policy")];
    to = roles.registry.address; data = calldata(`recordContentConsent(${CONSENT},${AUTH})`, [p.consent, p.authorization]);
  } else {
    p.consentPacketHash = sha("canonical prior packet\n"); p.priorPacketFileSha256 = p.consentPacketHash;
    p.consentReceiptTxHash = H("consent-transaction"); p.consentRecord = H("consent-record"); p.newFamily = H("new-family");
    to = roles.router.address;
    data = calldata(kind === "collection" ? `publishVerifiedPreservationPolicyContentRoot(${CP})` : `publishScopedPreservationPolicyContentRootPublication(${SP})`, [publication]);
  }
  const nonce = (1n << 255n) + 123n;
  const transaction = [to, 0n, data, 0n, request.safeTxGas, 0n, 0n, ZeroAddress, ZeroAddress, nonce];
  p.unsigned = { safe: roles.artistSafe.address, owners: [...admission.safeOwners], threshold: 2n, nonce,
    transaction, transactionHash: safeHash(p.chainId, roles.artistSafe.address, transaction),
    inner: { to, value: 0n, data, operation: 0n },
  };
  const manifest = { schemaVersion: 1, chainId: 31337n, sourceCommit: SOURCE, sourceReportSha256: REPORT,
    toolSha256: TOOL, castSha256: CAST, bootstrapManifestSha256: admission.bootstrapManifestSha256,
    clientPrerequisitePacketSha256: admission.clientPrerequisitePacketSha256, admissionHash: p.admissionHash,
    registry: { ...roles.registry }, router: { ...roles.router },
    artistSafe: { ...roles.artistSafe, version, singleton: { address: A(200), codeHash: H("singleton") } },
  };
  return { p, manifest };
}
function prepared(f) {
  const text = bytes(f.p);
  return preparePreservationRootInterludePacket(text, f.manifest, { expectedPacketSha256: sha(text) });
}
function rehash(f, admission = false) {
  f.p.admissionHash = sha(bytes(f.p.admission)); f.p.requestHash = sha(bytes(f.p.request));
  if (admission) f.manifest.admissionHash = f.p.admissionHash;
}

test("all two phases, four original scopes and both supported Safe versions retain exact high integers", () => {
  for (const phase of ["consent", "root"]) for (const scope of [0n, 1n, 2n, 3n]) for (const version of ["1.3.0", "1.4.1"]) {
    const f = fixture(phase, scope, version), result = prepared(f);
    assert.equal(result.phase, phase); assert.equal(result.kind, f.p.request.kind);
    assert.equal(result.safe.nonce, f.p.unsigned.nonce);
    assert.equal(result.transaction.safeTxGas, f.p.request.safeTxGas);
    assert.equal(result.expectedSafeTxHash, f.p.unsigned.transactionHash);
    assert.equal(result.originalPacket.request.scope[1], f.p.request.scope[1]);
    assert.deepEqual(result.inner, f.p.unsigned.inner);
    const iface = rootInterludeInterfaces[phase === "consent" ? "registry" : "router"];
    const decoded = iface.parseTransaction({ data: result.inner.data });
    assert.equal(iface.encodeFunctionData(decoded.fragment, decoded.args), result.inner.data);
    assert.equal(result.anchor.number, 22);
    assert.equal(result.originalProtocolStateIndependentlyVerified, false);
    assert.equal(result.deploymentProvenanceIndependentlyVerified, false);
  }
});

test("lossless canonical parser rejects duplicate keys, floating/exponent numbers and byte drift", () => {
  const f = fixture(), text = bytes(f.p);
  assert.equal(parsePreservationRootInterludePacket(text).authorization[0], f.p.authorization[0]);
  for (const bad of [text.trimEnd(), text + "\n", " " + text, text.replace('"schemaVersion":1', '"schemaVersion":1.0'), text.replace('"schemaVersion":1', '"schemaVersion":1e0'), text.replace('"phase":"consent"', '"phase":"consent","phase":"consent"'), text.replace('"timestamp":1234', '"timestamp":-0')]) {
    assert.throws(() => parsePreservationRootInterludePacket(bad));
  }
  assert.throws(() => preparePreservationRootInterludePacket(f.p, f.manifest, { expectedPacketSha256: sha(text) }));
  assert.throws(() => preparePreservationRootInterludePacket(text, f.manifest, { expectedPacketSha256: sha("wrong") }));
});

test("Python Unicode scalar ordering and literal UTF8 survive while escaped or invalid alternatives reject", () => {
  const text = '{"a":"😀\u007f","\uE000":1,"𐀀":2}\n';
  const p = parsePreservationRootInterludePacket(text);
  assert.equal(p["𐀀"], 2n);
  assert.throws(() => parsePreservationRootInterludePacket('{"a":"\\ud800"}\n'));
  assert.throws(() => parsePreservationRootInterludePacket('{"a":"\\udc00"}\n'));
  assert.throws(() => parsePreservationRootInterludePacket('{"a":"\\u00e9"}\n'));
  assert.equal(parsePreservationRootInterludePacket('{"a":"é"}\n').a, "é");
});

test("raw bytes, recursion, nodes, arrays, strings and scalar widths have finite bounds", () => {
  assert.throws(() => parsePreservationRootInterludePacket(" ".repeat(PRESERVATION_ROOT_INTERLUDE_MAX_PACKET_BYTES + 1)));
  assert.throws(() => parsePreservationRootInterludePacket('{"a":' + "[".repeat(65) + "0" + "]".repeat(65) + "}\n"));
  assert.throws(() => parsePreservationRootInterludePacket(bytes({ a: Array(4097).fill(null) })));
  assert.throws(() => parsePreservationRootInterludePacket(bytes({ a: Array.from({ length: 17 }, () => Array(4096).fill(null)) })));
  assert.throws(() => parsePreservationRootInterludePacket(bytes({ a: "x".repeat(2 * 1024 * 1024 + 1) })));
  const f = fixture(); f.p.unsigned.nonce = 1n << 256n; assert.throws(() => prepared(f));
  const block = fixture(); block.p.anchor.number = 1n << 54n; assert.throws(() => prepared(block), /block number/);
});

test("source/tool/cast and independently accepted admission pins are explicit, not inferred provenance", () => {
  for (const key of ["sourceCommit", "sourceReportSha256", "toolSha256", "castSha256"]) {
    const f = fixture(); f.p[key] = key === "sourceCommit" ? "a".repeat(40) : "a".repeat(64); assert.throws(() => prepared(f));
  }
  for (const name of ["registry", "router", "artistSafe"]) {
    const f = fixture(); f.manifest[name].address = A(300); assert.throws(() => prepared(f));
  }
  const f = fixture(); f.p.admission.bootstrapManifestSha256 = sha("changed"); rehash(f, true); assert.throws(() => prepared(f));
  const unreviewed = fixture(); unreviewed.p.admission.roles.core.codeHash = H("changed"); rehash(unreviewed); assert.throws(() => prepared(unreviewed));
  const claim = fixture(); claim.p.claimedToolExecutionVerified = true; assert.throws(() => prepared(claim));
});

test("runtime pins deduplicate identical pairs and reject conflicting aliases or overwide roles", () => {
  const same = fixture(); same.p.admission.roles.alias = { ...same.p.admission.roles.core }; rehash(same, true);
  assert.equal(prepared(same).runtimePins.length, new Set(Object.values(same.p.admission.roles).map(r => r.address)).size + 1);
  const conflict = fixture(); conflict.p.admission.roles.alias = { address: conflict.p.admission.roles.core.address, codeHash: H("bad") }; rehash(conflict, true); assert.throws(() => prepared(conflict));
  const singleton = fixture(); singleton.manifest.artistSafe.singleton.address = singleton.manifest.artistSafe.address; assert.throws(() => prepared(singleton));
  const many = fixture(); for (let i = 0; i < 65; i++) many.p.admission.roles["extra" + i] = { address: A(i + 100), codeHash: H("extra" + i) }; rehash(many, true); assert.throws(() => prepared(many));
});

test("only original consent terms and empty principal authorization produce a consent transaction", () => {
  for (const mutate of [f => { f.p.consent[0]++; }, f => { f.p.consent[1] = A(100); }, f => { f.p.consent[2] = H("other-family"); }, f => { f.p.authorization[2] = "0x12"; }, f => { f.p.authorization[1]--; }, f => { f.p.consent[3] = f.p.currentFamily; }]) {
    const f = fixture(); mutate(f); assert.throws(() => prepared(f));
  }
  const f = fixture(); f.p.anchor.timestamp = f.p.request.deadline; assert.throws(() => prepared(f), /Expired/);
  const root = fixture("root"); root.p.anchor.timestamp = root.p.request.deadline + 1n;
  assert.equal(prepared(root).phase, "root"); // Retained consent is not freshly deadline-authorized by this root packet.
});

test("root route preserves full scoped request, literal URI, prior packet coordinate and fixed target", () => {
  for (const scope of [0n, 1n, 2n, 3n]) {
    const f = fixture("root", scope); f.p.request.publication[0] = scope === 0n ? 5n : [1n, 9n, 1n, ZeroHash]; rehash(f); assert.throws(() => prepared(f));
  }
  const f = fixture("root"); f.p.priorPacketFileSha256 = sha("other"); assert.throws(() => prepared(f));
  const view = fixture("root", 2n); view.p.request.scope[0] = 4n; view.p.request.publication[0][0] = 4n; rehash(view); assert.throws(() => prepared(view));
  const uri = fixture("root"); uri.p.request.publication[3] += "/"; rehash(uri); assert.throws(() => prepared(uri), /transaction/);
  const phase = fixture("root"); phase.p.phase = "verified-root"; assert.throws(() => prepared(phase), /Only consent\/root/);
});

test("all ten Safe transaction fields and inner mirror are checked even with a recomputed Safe hash", () => {
  for (let i = 0; i < 10; i++) {
    const f = fixture();
    f.p.unsigned.transaction[i] = i === 0 || i === 7 || i === 8 ? A(123) : i === 2 ? "0x12345678" : f.p.unsigned.transaction[i] + 1n;
    f.p.unsigned.transactionHash = safeHash(f.p.chainId, f.p.unsigned.safe, f.p.unsigned.transaction);
    assert.throws(() => prepared(f));
  }
  for (const key of ["to", "value", "data", "operation"]) {
    const f = fixture(); f.p.unsigned.inner[key] = key === "to" ? A(123) : key === "data" ? "0x12345678" : 1n; assert.throws(() => prepared(f));
  }
  const hash = fixture(); hash.p.unsigned.transactionHash = H("different"); assert.throws(() => prepared(hash), /EIP712/);
});

test("Safe owner order, threshold, version and exact nonce are separate from signed inner calldata", () => {
  const reordered = fixture(); reordered.p.unsigned.owners.reverse(); assert.throws(() => prepared(reordered));
  const duplicates = fixture(); duplicates.p.unsigned.owners[1] = duplicates.p.unsigned.owners[0]; assert.throws(() => prepared(duplicates));
  const threshold = fixture(); threshold.p.unsigned.threshold = 1n; assert.throws(() => prepared(threshold));
  const version = fixture(); version.manifest.artistSafe.version = "unknown"; assert.throws(() => prepared(version));
  const nonce = fixture(); nonce.p.unsigned.nonce++; assert.throws(() => prepared(nonce));
});

test("canonical admission/request SHA is distinct from source file SHA and documentary read integrity", () => {
  const f = fixture();
  const row = { role: "core", target: f.p.admission.roles.core.address, code: "0x6000", codeSha256: sha(Buffer.from("6000", "hex")), blockHash: f.p.anchor.hash };
  f.p.reads.push(row);
  f.p.reads.push({ role: "artistSafe", target: f.p.unsigned.safe, calldata: "0xaffed0e0", returndata: coder.encode(["uint256"], [f.p.unsigned.nonce]), blockHash: f.p.anchor.hash });
  f.p.reads[1].returndataSha256 = sha(Buffer.from(f.p.reads[1].returndata.slice(2), "hex"));
  const result = prepared(f);
  assert.notEqual(result.admissionHash, result.originalPacket.admissionFileSha256);
  assert.notEqual(result.requestHash, result.originalPacket.requestFileSha256);
  const bad = structuredClone(f); bad.p.reads[0].codeSha256 = sha("different"); assert.throws(() => prepared(bad));
  const block = structuredClone(f); block.p.reads[1].blockHash = H("other"); assert.throws(() => prepared(block));
  const changed = fixture(); changed.p.request.deadline++; assert.throws(() => prepared(changed), /request hash/);
});

test("immutable results detach manifest inputs and expose no signing, RPC, or arbitrary-route method", () => {
  const f = fixture(), result = prepared(f);
  f.manifest.artistSafe.singleton.codeHash = H("changed");
  assert.equal(result.runtimePins.at(-1).codeHash, H("singleton"));
  assert.throws(() => { result.transaction.nonce = 0n; }, TypeError);
  assert.throws(() => { result.originalPacket.request.publication[0] = 0n; }, TypeError);
  assert.throws(() => { result.safe.owners.push(A(100)); }, TypeError);
  assert.equal(result.send, undefined); assert.equal(result.sign, undefined);
});
