import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, concat, getAddress, id, keccak256, zeroPadValue } from "ethers";
import * as p from "../dist/current-artist-guardian-rotation.js";

// Literal c636 compiler evidence, not regenerated from the codec under test.
const fixtureBytes = readFileSync(new URL("./fixtures/current-artist-recovered-multiple-consent-hydration-abi.json", import.meta.url));
const fixture = JSON.parse(fixtureBytes);
const original = new Interface(fixture.abis.StreamArtistOnboardingRegistry);
const events = new Interface(fixture.libraryAbis.StreamArtistRotationState.filter(x => x.type === "event"));
const abi = new Interface(p.CURRENT_ARTIST_GUARDIAN_ROTATION_ABI), coder = AbiCoder.defaultAbiCoder();
const h = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
const a = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const max64 = (1n << 64n) - 1n, max256 = (1n << 256n) - 1n, floor = 30n * 86400n;
const context = () => ({ chainId: max256, registry: a(1), caller: a(2) });
const guardians = () => ({ artistId: h(101), guardians: [a(10), a(11), a(12)], approvalThreshold: 2n, minContestSeconds: floor });
const rotation = () => ({ artistId: h(101), oldAddress: a(20), newAddress: a(21), reasonHash: h(102), expectedPreviousTransitionRecordHash: h(103) });
const auth = () => ({ nonce: max256, time: max64, signature: "0xaabb" });
const stage = () => ({ ...context(), kind: "stageRotation", terms: rotation(), oldAuthorization: auth(), newAuthorization: { ...auth(), signature: "0xccdd" } });
const set = () => ({ ...context(), kind: "setGuardians", terms: guardians(), authorization: auth() });
const hash = (types, values) => keccak256(coder.encode(types, values));
const writes = ["setArtistGuardians", "rotateArtistAddress", "approveArtistRotation", "vetoArtistRotation", "executeArtistRotation"];
const reads = ["guardianSetDigest", "rotationDigest", "rotationAcceptanceDigest", "guardianSet", "pendingRotation", "guardianSetRecord", "rotationRecord", "artistTransitionState", "lastArtistTransition", "activeAuthorityWindow", "rotationAcceptanceNonceState"];
const eventNames = ["ArtistGuardianSetUpdated", "ArtistRotationStaged", "ArtistRotationGuardianApproved", "ArtistRotationVetoed", "ArtistAddressRotated"];

function shape(q, named = false) {
  return { type: q.format("sighash"), ...(named ? { name: q.name } : {}),
    ...(q.components ? { components: q.components.map(c => shape(c, true)) } : {}),
    ...(q.arrayChildren ? { arrayLength: q.arrayLength, child: shape(q.arrayChildren) } : {}) };
}
function zero(q) {
  if (typeof q === "string") q = ParamType.from(q);
  if (q.baseType === "tuple") return Object.fromEntries(q.components.map(c => [c.name, zero(c)]));
  if (q.baseType === "array") return q.arrayLength === -1 ? [] : Array.from({ length: q.arrayLength }, () => zero(q.arrayChildren));
  if (q.type === "address") return ZeroAddress;
  if (q.type === "bool") return false;
  if (q.type === "bytes") return "0x";
  if (q.type.startsWith("bytes")) return `0x${"00".repeat(Number(q.type.slice(5)))}`;
  return 0n;
}
function domain(chainId = context().chainId, registry = context().registry, version = "1") {
  return hash(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id(version), chainId, registry]);
}
function signed(structHash, chainId, registry) { return keccak256(concat(["0x1901", domain(chainId, registry), structHash])); }
function guardianStruct(g, au, arrayHash = keccak256(concat(g.guardians.map(v => zeroPadValue(v, 32))))) {
  return hash(["bytes32", "bytes32", "bytes32", "uint32", "uint64", "uint256", "uint64"],
    [id("StreamArtistGuardianSet(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds,uint256 nonce,uint64 signedAt)"), g.artistId, arrayHash, g.approvalThreshold, g.minContestSeconds, au.nonce, au.time]);
}
function rotationStruct(r, au, acceptance = false) {
  return hash(["bytes32", "bytes32", "address", "address", ...(acceptance ? [] : ["bytes32"]), "uint256", "uint64"],
    [id(acceptance ? "StreamArtistRotationAcceptance(bytes32 artistId,address oldAddress,address newAddress,uint256 nonce,uint64 deadline)" : "StreamArtistKeyRotation(bytes32 artistId,address oldAddress,address newAddress,bytes32 reasonHash,uint256 nonce,uint64 deadline)"),
      r.artistId, r.oldAddress, r.newAddress, ...(acceptance ? [] : [r.reasonHash]), au.nonce, au.time]);
}

test("frozen full ABI provenance and exact five writes, eleven reads, five events", () => {
  assert.equal(createHash("sha256").update(fixtureBytes).digest("hex"), "fd13d766e7358355e995f1ec9ef6db3010eca5383f2506b0963c3c49916a8463");
  assert.equal(p.GUARDIAN_ROTATION_FIXTURE_SHA256, "fd13d766e7358355e995f1ec9ef6db3010eca5383f2506b0963c3c49916a8463");
  assert.equal(fixture.sourceCommit, "c636a5f176c5765d80d15ee20f41355a8911ea9c");
  assert.equal(p.GUARDIAN_ROTATION_SOURCE, fixture.sourceCommit);
  assert.equal(p.GUARDIAN_ROTATION_INTEGRATION, "9a1a3d299d796a3907c58fb68a497bd9fb8ab457");
  assert.deepEqual(abi.fragments.filter(f => f.type === "function").map(f => f.name).sort(), [...writes, ...reads].sort());
  for (const name of [...writes, ...reads]) {
    const actual = abi.getFunction(name), expected = original.getFunction(name);
    // Outer Solidity parameter names differ between facade and interface; nested struct names do not.
    assert.deepEqual(actual.inputs.map(v => shape(v)), expected.inputs.map(v => shape(v)), `${name} complete inputs`);
    assert.deepEqual(actual.outputs.map(v => shape(v)), expected.outputs.map(v => shape(v)), `${name} complete returns`);
    assert.equal(actual.stateMutability, expected.stateMutability, name);
    assert.equal(actual.selector, `0x${fixture.methodIdentifiers.StreamArtistOnboardingRegistry[expected.format("sighash")]}`, name);
  }
  assert.deepEqual(abi.fragments.filter(f => f.type === "event").map(f => f.name).sort(), [...eventNames].sort());
  for (const name of eventNames) {
    const actual = abi.getEvent(name), expected = events.getEvent(name);
    assert.equal(actual.topicHash, expected.topicHash, name);
    assert.equal(actual.anonymous, expected.anonymous, name);
    assert.deepEqual(actual.inputs.map(v => ({ ...shape(v, true), indexed: v.indexed === true })), expected.inputs.map(v => ({ ...shape(v, true), indexed: v.indexed === true })), name);
  }
});

test("all exported tuple shapes retain complete original nested return fields", () => {
  const cases = [
    [p.ARTIST_GUARDIAN_SET_TUPLE, original.getFunction("setArtistGuardians").inputs[0]],
    [p.ARTIST_ROTATION_TERMS_TUPLE, original.getFunction("rotateArtistAddress").inputs[0]],
    [p.ARTIST_ROTATION_AUTHORIZATION_TUPLE, original.getFunction("rotateArtistAddress").inputs[1]],
    [p.ARTIST_ROTATION_TRANSITION_TUPLE, original.getFunction("artistTransitionState").outputs[0]],
    [p.ARTIST_GUARDIAN_RECORD_TUPLE, original.getFunction("guardianSetRecord").outputs[0]],
    [p.ARTIST_ROTATION_RECORD_TUPLE, original.getFunction("rotationRecord").outputs[0]],
    [p.ARTIST_ROTATION_ASSOCIATION_TUPLE, original.getFunction("guardianSetRecord").outputs[0].components.find(f => f.name === "provisional")],
  ];
  for (const [text, expected] of cases) assert.deepEqual(shape(ParamType.from(text)), shape(expected));
});

test("five unsigned operations exactly encode original facade selectors without facts or execution claims", () => {
  const cases = [
    [set(), 28, "setArtistGuardians", [guardians(), auth()], 1],
    [stage(), 29, "rotateArtistAddress", [rotation(), auth(), stage().newAuthorization], 2],
    [{ ...context(), kind: "approveRotation", artistId: h(101), expectedRotationRecordHash: h(104) }, 30, "approveArtistRotation", [h(101), h(104)], 0],
    [{ ...context(), kind: "vetoRotation", artistId: h(101), expectedRotationRecordHash: h(104), reasonHash: ZeroHash }, 31, "vetoArtistRotation", [h(101), h(104), ZeroHash], 0],
    [{ ...context(), kind: "executeRotation", artistId: h(101), expectedRotationRecordHash: h(104) }, 32, "executeArtistRotation", [h(101), h(104)], 0],
  ];
  for (const [request, operation, method, values, count] of cases) {
    const result = p.prepareGuardianRotationCall(request);
    assert.equal(result.operation, operation);
    assert.deepEqual(result.call, { to: context().registry, value: 0n, data: original.encodeFunctionData(method, values) });
    assert.equal(result.factsVerified, false);
    assert.equal(result.signing.length, count);
    assert.deepEqual(p.normalizeGuardianRotationCall(result), result);
    assert.equal(Object.hasOwn(result, "executed"), false);
  }
});

test("three independently reconstructed EIP712 hashes use original Registry v1 and padded guardian elements", () => {
  const g = guardians(), r = rotation(), au = auth(), c = context();
  const expected = [signed(guardianStruct(g, au)), signed(rotationStruct(r, au)), signed(rotationStruct(r, au, true))];
  for (const [i, kind, terms] of [[0, "guardianSet", g], [1, "rotation", r], [2, "rotationAcceptance", r]]) {
    const data = p.guardianRotationTypedData(kind, c.chainId, c.registry, terms, au);
    assert.equal(data.digest, expected[i]);
    assert.equal(p.guardianRotationDigest(kind, c.chainId, c.registry, terms, au), expected[i]);
    assert.deepEqual(data.domain, { name: "6529StreamArtistRegistry", version: "1", chainId: c.chainId, verifyingContract: c.registry });
    assert.notEqual(data.digest, signed(i === 0 ? guardianStruct(g, au) : rotationStruct(r, au, i === 2), c.chainId - 1n, c.registry));
    assert.notEqual(data.digest, signed(i === 0 ? guardianStruct(g, au) : rotationStruct(r, au, i === 2), c.chainId, a(99)));
  }
  assert.notEqual(expected[0], signed(guardianStruct(g, au, keccak256(concat(g.guardians)))));
  assert.notEqual(expected[0], signed(guardianStruct(g, au, hash(["address[]"], [g.guardians]))));
  assert.notEqual(expected[1], keccak256(concat(["0x1901", domain(c.chainId, c.registry, "2"), rotationStruct(r, au)])));
  const empty = { ...g, guardians: [], approvalThreshold: 0n, minContestSeconds: 0n };
  assert.equal(p.guardianRotationDigest("guardianSet", c.chainId, c.registry, empty, au), signed(guardianStruct(empty, au, keccak256("0x"))));
});

test("digest read calls strip signatures but preserve exact original terms and authorization widths", () => {
  const requests = [p.prepareGuardianRotationCall(set()), p.prepareGuardianRotationCall(stage())];
  const expected = [["guardianSetDigest", guardians(), auth()], ["rotationDigest", rotation(), auth()], ["rotationAcceptanceDigest", rotation(), stage().newAuthorization]];
  const signs = requests.flatMap(v => v.signing);
  expected.forEach(([method, terms, au], i) => {
    assert.deepEqual(signs[i].digestCall, { to: context().registry, value: 0n, data: original.encodeFunctionData(method, [terms, { ...au, signature: "0x" }]) });
    assert.equal(original.decodeFunctionData(method, signs[i].digestCall.data)[1].signature, "0x");
  });
});

test("rotation concurrency guard changes calldata but neither signature; reason belongs only to principal", () => {
  const first = p.prepareGuardianRotationCall(stage());
  const changedGuard = p.prepareGuardianRotationCall({ ...stage(), terms: { ...rotation(), expectedPreviousTransitionRecordHash: ZeroHash } });
  assert.notEqual(first.call.data, changedGuard.call.data);
  assert.deepEqual(first.signing.map(s => s.digest), changedGuard.signing.map(s => s.digest));
  assert.ok(first.signing.every(s => !Object.hasOwn(s.typedData.message, "expectedPreviousTransitionRecordHash")));
  const changedReason = p.prepareGuardianRotationCall({ ...stage(), terms: { ...rotation(), reasonHash: h(199) } });
  assert.notEqual(first.signing[0].digest, changedReason.signing[0].digest);
  assert.equal(first.signing[1].digest, changedReason.signing[1].digest);
  assert.equal(Object.hasOwn(first.signing[1].typedData.message, "reasonHash"), false);
  for (const patch of [{ artistId: h(199) }, { oldAddress: a(199) }, { newAddress: a(199) }]) {
    const changed = p.prepareGuardianRotationCall({ ...stage(), terms: { ...rotation(), ...patch } });
    first.signing.forEach((s, i) => assert.notEqual(s.digest, changed.signing[i].digest));
  }
});

test("each signed nonce and deadline is independent; signature bytes and transaction caller are not signed fields", () => {
  const first = p.prepareGuardianRotationCall(stage());
  for (const side of ["oldAuthorization", "newAuthorization"]) for (const field of ["nonce", "time"]) {
    const input = stage(); input[side] = { ...input[side], [field]: input[side][field] - 1n };
    const next = p.prepareGuardianRotationCall(input), i = side === "oldAuthorization" ? 0 : 1;
    assert.notEqual(next.signing[i].digest, first.signing[i].digest);
    assert.equal(next.signing[1 - i].digest, first.signing[1 - i].digest);
  }
  const changed = p.prepareGuardianRotationCall({ ...stage(), caller: a(99), oldAuthorization: { ...auth(), signature: "0x" } });
  assert.notEqual(changed.call.data, first.call.data);
  assert.deepEqual(changed.signing.map(s => s.digest), first.signing.map(s => s.digest));
  const g = p.prepareGuardianRotationCall(set());
  for (const patch of [{ artistId: h(199) }, { guardians: [a(10), a(11)] }, { approvalThreshold: 1n }, { minContestSeconds: 1n }]) {
    assert.notEqual(p.prepareGuardianRotationCall({ ...set(), terms: { ...guardians(), ...patch } }).signing[0].digest, g.signing[0].digest);
  }
});

test("acceptance kind4 lane is separate from principal kind1 at the same full uint256 nonce", () => {
  const result = p.prepareGuardianRotationCall(stage()), r = rotation();
  const lane = hash(["bytes32", "bytes32", "address"], [id("rotation_acceptance"), r.artistId, r.newAddress]);
  assert.equal(p.rotationAcceptanceLane(r.artistId, r.newAddress), lane);
  assert.deepEqual(result.signing.map(s => s.nonceLane), [{ kind: 1, scope: r.artistId }, { kind: 4, scope: lane }]);
  assert.deepEqual(result.signing.map(s => s.signer), [r.oldAddress, r.newAddress]);
  assert.equal(result.signing[0].typedData.message.nonce, result.signing[1].typedData.message.nonce);
  assert.notEqual(lane, p.rotationAcceptanceLane(h(999), r.newAddress));
  assert.notEqual(lane, p.rotationAcceptanceLane(r.artistId, a(999)));
  assert.equal(Object.hasOwn(p.prepareGuardianRotationCall(set()).signing[0], "signer"), false);
});

test("original record hashes match independent ABI preimages and inclusion times rather than signature digests", () => {
  const c = context(), g = guardians(), r = rotation(), au = auth();
  // Literal domains pinned in the original source retained by the frozen compiler packet.
  const guardianDomain = "0xfb979fce9edd361cf23ba8baee900f7054451db7b563ba0ab11a5ef3621cd297";
  const rotationDomain = "0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5";
  const source = fixture.sourceTexts["smart-contracts/domains/artist/StreamArtistRotationHashes.sol"];
  assert.ok(source.includes(guardianDomain) && source.includes(rotationDomain));
  const expectedG = hash(["bytes32", "uint256", "address", "bytes32", "address[]", "uint32", "uint64", "uint256", "uint64"], [guardianDomain, c.chainId, c.registry, g.artistId, g.guardians, g.approvalThreshold, g.minContestSeconds, au.nonce, max64]);
  const expectedR = hash(["bytes32", "uint256", "address", "bytes32", "address", "address", "bytes32", "uint256", "uint64", "uint64"], [rotationDomain, c.chainId, c.registry, r.artistId, r.oldAddress, r.newAddress, r.reasonHash, au.nonce, max64 - 1n, max64]);
  assert.equal(p.artistGuardianRecordHash(c.chainId, c.registry, g, au.nonce, max64), expectedG);
  assert.equal(p.artistRotationRecordHash(c.chainId, c.registry, r, au.nonce, max64 - 1n, max64), expectedR);
  assert.notEqual(expectedG, signed(guardianStruct(g, au)));
  assert.notEqual(expectedR, signed(rotationStruct(r, au)));
  assert.equal(p.artistRotationRecordHash(c.chainId, c.registry, { ...r, expectedPreviousTransitionRecordHash: ZeroHash }, au.nonce, max64 - 1n, max64), expectedR);
  assert.notEqual(p.artistGuardianRecordHash(c.chainId, c.registry, g, au.nonce, max64 - 1n), expectedG);
  assert.notEqual(p.artistRotationRecordHash(c.chainId, c.registry, r, au.nonce - 1n, max64 - 1n, max64), expectedR);
  for (const [start, end] of [[0n, 1n], [2n, 2n], [2n, 1n], [max64, max64 + 1n]]) assert.throws(() => p.artistRotationRecordHash(c.chainId, c.registry, r, au.nonce, start, end));
  assert.throws(() => p.artistGuardianRecordHash(c.chainId, c.registry, g, au.nonce, 0n));
});

test("guardian count, sorting, uniqueness, threshold and thirty-day floor are enforced at exact boundaries", () => {
  const g = guardians(), eight = Array.from({ length: 8 }, (_, i) => a(i + 1));
  assert.equal(p.normalizeArtistGuardianSet({ ...g, guardians: eight, approvalThreshold: 8n }).guardians.length, 8);
  assert.deepEqual(p.normalizeArtistGuardianSet({ ...g, guardians: [], approvalThreshold: 0n, minContestSeconds: 0n }).guardians, []);
  for (const patch of [{ guardians: [...eight, a(9)] }, { guardians: [...g.guardians].reverse() }, { guardians: [a(10), a(10)] }, { guardians: [ZeroAddress] }, { guardians: [], approvalThreshold: 1n }, { approvalThreshold: 0n }, { approvalThreshold: 4n }, { approvalThreshold: 1n << 32n }, { minContestSeconds: floor + 1n }, { minContestSeconds: -1n }, { minContestSeconds: max64 + 1n }, { minContestSeconds: 1 }, { artistId: ZeroHash }]) {
    assert.throws(() => p.normalizeArtistGuardianSet({ ...g, ...patch }));
  }
  const sparse = [a(1), , a(3)], extra = [a(1)]; extra.tag = "extra";
  for (const array of [sparse, extra]) assert.throws(() => p.normalizeArtistGuardianSet({ ...g, guardians: array, approvalThreshold: 1n }));
});

test("uint widths, bytes, exact keys, addresses and per-operation time rules refuse malformed input", () => {
  for (const patch of [{ nonce: -1n }, { nonce: max256 + 1n }, { nonce: 1 }, { time: -1n }, { time: max64 + 1n }, { signature: "0x0" }, { signature: "0xzz" }, { signature: `0x${"aa".repeat(4097)}` }, { deadline: 1n }]) assert.throws(() => p.normalizeArtistRotationAuthorization({ ...auth(), ...patch }));
  assert.equal(p.normalizeArtistRotationAuthorization({ ...auth(), signature: `0x${"aa".repeat(4096)}` }).signature.length, 8194);
  for (const patch of [{ oldAddress: ZeroAddress }, { newAddress: rotation().oldAddress }, { artistId: "0x12" }, { reasonHash: "0x" }, { expectedPreviousTransitionRecordHash: "0x12" }, { arbitrary: 1 }]) assert.throws(() => p.normalizeArtistRotationTerms({ ...rotation(), ...patch }));
  for (const patch of [{ chainId: 0n }, { chainId: max256 + 1n }, { chainId: 1 }, { registry: ZeroAddress }, { caller: ZeroAddress }, { kind: "recoverArtist" }, { value: 1n }]) assert.throws(() => p.prepareGuardianRotationCall({ ...stage(), ...patch }));
  for (const side of ["oldAuthorization", "newAuthorization"]) assert.throws(() => p.prepareGuardianRotationCall({ ...stage(), [side]: { ...auth(), time: 0n, signature: "0x" } }));
  assert.throws(() => p.prepareGuardianRotationCall({ ...set(), authorization: { ...auth(), time: 0n } }));
  const direct = p.prepareGuardianRotationCall({ ...set(), authorization: { nonce: 0n, time: 0n, signature: "0x" } });
  assert.equal(direct.request.authorization.time, 0n);
  assert.equal(direct.factsVerified, false); // No guessed inclusion timestamp or authority verification.
  for (const kind of ["approveRotation", "vetoRotation", "executeRotation"]) assert.throws(() => p.prepareGuardianRotationCall({ ...context(), kind, artistId: h(1), expectedRotationRecordHash: ZeroHash, ...(kind === "vetoRotation" ? { reasonHash: ZeroHash } : {}) }));
});

test("prepared values are detached/frozen and every encoded or signing mutation is detected", () => {
  const input = set(), result = p.prepareGuardianRotationCall(input);
  input.terms.guardians[0] = a(1); input.authorization.signature = "0x";
  assert.deepEqual(result.request.terms.guardians, guardians().guardians);
  assert.equal(result.request.authorization.signature, auth().signature);
  assert.throws(() => result.request.terms.guardians.push(a(99)), TypeError);
  assert.throws(() => { result.signing[0].typedData.domain.chainId = 1n; }, TypeError);
  for (const mutate of [v => { v.operation = 29; }, v => { v.call.to = a(99); }, v => { v.call.value = 1n; }, v => { v.call.data = "0x"; }, v => { v.factsVerified = true; }, v => { v.signing[0].digest = h(99); }, v => { v.signing[0].nonceLane.kind = 4; }, v => { v.signing[0].digestCall.data = "0x"; }, v => { v.signing = []; }, v => { v.extra = 1; }]) {
    const changed = structuredClone(result); mutate(changed); assert.throws(() => p.normalizeGuardianRotationCall(changed));
  }
});

function readValues() {
  const g = zero(p.ARTIST_GUARDIAN_RECORD_TUPLE), r = zero(p.ARTIST_ROTATION_RECORD_TUPLE);
  Object.assign(g, { recordHash: h(201), terms: guardians(), signer: a(20), authorityClass: 1n, nonce: max256, signedAt: max64, previousOperativeRecordHash: h(202), provisional: { transitionRecordHash: h(203), windowEndsAt: max64 } });
  Object.assign(r, { recordHash: h(211), terms: rotation(), guardianSetRecordHash: g.recordHash, approvalThreshold: 2n, guardianApprovals: 1n, oldNonce: max256, newNonce: max256, effectiveWindow: floor, standingTail: floor, timingRevision: max64 });
  Object.assign(r.transition, { artistId: rotation().artistId, recordHash: r.recordHash, stagedAt: 1n, contestEndsAt: 2n, executedAt: 3n, postWindowEndsAt: max64, contestedAt: 4n, phase: 3n });
  return {
    guardianSet: [g.terms.guardians, 2n, floor, g.recordHash], pendingRotation: [r.terms.oldAddress, r.terms.newAddress, max64, 1n, r.recordHash],
    guardianSetRecord: [g], rotationRecord: [r], artistTransitionState: [r.transition], lastArtistTransition: [r.recordHash],
    activeAuthorityWindow: [r.recordHash, max64, true], rotationAcceptanceNonceState: [false, max256],
  };
}

test("all eight state reads preserve full original return encodings and decode immutable named shapes", () => {
  for (const [method, values] of Object.entries(readValues())) {
    const args = method === "rotationAcceptanceNonceState" ? [h(101), a(21), max256] : [h(101)];
    assert.deepEqual(p.prepareGuardianRotationRead(context().registry, method, args), { to: context().registry, value: 0n, data: original.encodeFunctionData(method, args) });
    const raw = original.encodeFunctionResult(method, values), decoded = p.decodeGuardianRotationRead(method, raw);
    const outputs = abi.getFunction(method).outputs;
    const reencoded = abi.encodeFunctionResult(method, outputs.length === 1 ? [decoded] : outputs.map(f => decoded[f.name]));
    assert.equal(reencoded, raw, method);
    if (typeof decoded === "object") assert.ok(Object.isFrozen(decoded));
  }
  const record = p.decodeGuardianRotationRead("rotationRecord", original.encodeFunctionResult("rotationRecord", readValues().rotationRecord));
  assert.equal(record.transition.postWindowEndsAt, max64);
  assert.equal(record.terms.expectedPreviousTransitionRecordHash, rotation().expectedPreviousTransitionRecordHash);
  assert.equal(record.newNonce, max256);
  assert.throws(() => { record.transition.phase = 0n; }, TypeError);
});

test("read decoding refuses trailing, truncated, noncanonical narrow words, bool and oversized bytes", () => {
  for (const [method, values] of Object.entries(readValues())) {
    const raw = original.encodeFunctionResult(method, values);
    assert.throws(() => p.decodeGuardianRotationRead(method, `${raw}${"00".repeat(32)}`), method);
    assert.throws(() => p.decodeGuardianRotationRead(method, raw.slice(0, -2)), method);
  }
  const replaceWord = (raw, index, value) => `${raw.slice(0, 2 + 64 * index)}${h(value).slice(2)}${raw.slice(2 + 64 * (index + 1))}`;
  const window = original.encodeFunctionResult("activeAuthorityWindow", readValues().activeAuthorityWindow);
  assert.throws(() => p.decodeGuardianRotationRead("activeAuthorityWindow", replaceWord(window, 2, 2n)));
  assert.throws(() => p.decodeGuardianRotationRead("activeAuthorityWindow", replaceWord(window, 1, 1n << 64n)));
  const pending = original.encodeFunctionResult("pendingRotation", readValues().pendingRotation);
  assert.throws(() => p.decodeGuardianRotationRead("pendingRotation", replaceWord(pending, 3, 1n << 32n)));
  assert.throws(() => p.decodeGuardianRotationRead("pendingRotation", replaceWord(pending, 0, 1n << 160n)));
  for (const raw of ["0x0", `0x${"00".repeat(16385)}`]) assert.throws(() => p.decodeGuardianRotationRead("lastArtistTransition", raw));
});

test("read canonical shape does not authenticate records; known absent state remains representable", () => {
  assert.deepEqual(p.decodeGuardianRotationRead("guardianSet", original.encodeFunctionResult("guardianSet", [[], 0n, 0n, ZeroHash])), { guardians: [], approvalThreshold: 0n, minContestSeconds: 0n, recordHash: ZeroHash });
  assert.deepEqual(p.decodeGuardianRotationRead("guardianSetRecord", original.encodeFunctionResult("guardianSetRecord", [zero(p.ARTIST_GUARDIAN_RECORD_TUPLE)])), zero(p.ARTIST_GUARDIAN_RECORD_TUPLE));
  const forged = structuredClone(readValues().rotationRecord[0]); forged.recordHash = h(999);
  assert.equal(p.decodeGuardianRotationRead("rotationRecord", original.encodeFunctionResult("rotationRecord", [forged])).recordHash, h(999));
  for (const method of ["guardianSet", "guardianSetRecord"]) {
    const bad = method === "guardianSet" ? [[a(2), a(1)], 1n, 0n, h(1)] : [{ ...readValues().guardianSetRecord[0], terms: { ...guardians(), guardians: [a(2), a(1)] } }];
    assert.throws(() => p.decodeGuardianRotationRead(method, original.encodeFunctionResult(method, bad)));
  }
  for (const method of ["artistTransitionState", "rotationRecord"]) {
    const bad = structuredClone(readValues()[method][0]); if (method === "rotationRecord") bad.transition.phase = 4n; else bad.phase = 4n;
    assert.throws(() => p.decodeGuardianRotationRead(method, original.encodeFunctionResult(method, [bad])));
  }
});

test("read method and argument bounds are narrow; digest getters come only from prepared signing", () => {
  for (const method of ["guardianSetDigest", "rotationDigest", "rotationAcceptanceDigest", "executeArtistRotation", "nonceState", "unknown"]) {
    assert.throws(() => p.prepareGuardianRotationRead(context().registry, method, [h(1)]));
    assert.throws(() => p.decodeGuardianRotationRead(method, "0x"));
  }
  for (const args of [[], [h(1), a(2)], [h(1), a(2), -1n], [h(1), a(2), max256 + 1n], [h(1), ZeroAddress, 0n], [ZeroHash, a(2), 0n]]) assert.throws(() => p.prepareGuardianRotationRead(context().registry, "rotationAcceptanceNonceState", args));
  assert.throws(() => p.prepareGuardianRotationRead(context().registry, "guardianSet", [h(1), h(2)]));
  assert.throws(() => p.prepareGuardianRotationRead(ZeroAddress, "guardianSet", [h(1)]));
  assert.equal(p.prepareGuardianRotationRead(context().registry, "lastArtistTransition", [ZeroHash]).data, original.encodeFunctionData("lastArtistTransition", [ZeroHash]));
});
