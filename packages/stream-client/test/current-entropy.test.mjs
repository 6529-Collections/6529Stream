import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { Interface, TypedDataEncoder, ZeroHash, id } from "ethers";
import { prepareFreshEntropyRecovery, readFreshEntropyRecoveryPreview, prepareEntropyRecoveryContentConsent,
  prepareEntropyIncident, prepareEntropyFeeCreditClaim, ENTROPY_RECOVERY_CONTENT_FAMILY, toSafeCall } from "../dist/index.js";
const fixture = JSON.parse(await readFile(new URL("./fixtures/current-entropy-abi.json", import.meta.url), "utf8"));
const recovery = new Interface(fixture.abis.recovery), coordinator = new Interface(fixture.abis.coordinator), artist = new Interface(fixture.abis.artist);
const host = "0x0000000000000000000000000000000000006529", registry = "0x0000000000000000000000000000000000000042", core = "0x0000000000000000000000000000000000000007";
const input = () => ({ oldRequestKey: id("old"), reasonURI: "ipfs://incident/é", providerEvidenceHash: id("corroboration") });
test("fresh recovery and Safe CALL preserve compiled input and independent native allowance", () => {
  const p = input(), a = prepareFreshEntropyRecovery(host, p, (1n << 255n) + 1n), b = prepareFreshEntropyRecovery(host, p, 0n);
  assert.equal(a.call.data, recovery.encodeFunctionData("requestFreshEntropy", [p]));
  assert.equal(a.previewCall.data, recovery.encodeFunctionData("freshRecoveryTransition", [p]));
  assert.equal(a.call.data, b.call.data); assert.equal(a.previewCall.value, 0n);
  assert.deepEqual(toSafeCall(a.call), { to: host, data: a.call.data, value: ((1n << 255n) + 1n).toString(), operation: 0 });
  p.reasonURI = "changed"; assert.notEqual(a.input.reasonURI, p.reasonURI); assert(Object.isFrozen(a.input));
});
test("quote preserves block selection and full-width fee; malformed and absent output fail", async () => {
  const p = prepareFreshEntropyRecovery(host, input(), 1n), output = [id("new"), id("state"), (1n << 255n) + 9n];
  const q = await readFreshEntropyRecoveryPreview({ call: async c => {
    assert.equal(c.blockTag, 12345678); assert.equal(c.to, host); assert.equal(c.value, 0n);
    assert.equal(c.data, p.previewCall.data); return recovery.encodeFunctionResult("freshRecoveryTransition", output);
  } }, p, { blockTag: 12345678 });
  assert.equal(q.providerFee, output[2]); assert.equal(q.requestKey, output[0]); assert.equal(q.oldRequestKey, p.input.oldRequestKey);
  for (const raw of ["0x", recovery.encodeFunctionResult("freshRecoveryTransition", [ZeroHash, output[1], 1n]),
    recovery.encodeFunctionResult("freshRecoveryTransition", output) + "00"]) {
    await assert.rejects(readFreshEntropyRecoveryPreview({ call: async () => raw }, p));
  }
  await assert.rejects(readFreshEntropyRecoveryPreview({ call: async () => { throw Error("provider refused"); } }, p), /provider refused/);
});
test("entropy content consent uses exact original Artist tuple, domain and empty Safe authorization", async () => {
  const p = prepareFreshEntropyRecovery(host, input(), 99n), state = id("actual recovery state");
  const q = await readFreshEntropyRecoveryPreview({ call: async () => recovery.encodeFunctionResult("freshRecoveryTransition", [id("new"), state, 12n]) }, p);
  const auth = { nonce: (1n << 255n) + 4n, deadline: (1n << 63n) + 7n, signature: "0x" };
  const c = prepareEntropyRecoveryContentConsent(31337n, registry, core, (1n << 255n) + 3n, p, q, auth);
  assert.equal(c.payload.domain.name, "6529StreamArtistRegistry"); assert.equal(c.payload.primaryType, "StreamArtistContentConsent");
  assert.equal(c.payload.message.metadataContract, host); assert.equal(c.payload.message.familyId, id("6529STREAM_ENTROPY_RECOVERY_V1"));
  assert.equal(ENTROPY_RECOVERY_CONTENT_FAMILY, c.payload.message.familyId);
  assert.equal(c.payload.message.newStateHash, state);
  assert.equal(c.payload.digest, TypedDataEncoder.hash(c.payload.domain, c.payload.types, c.payload.message));
  const tuple = [c.payload.message.collectionId, host, ENTROPY_RECOVERY_CONTENT_FAMILY, state], authorization = [auth.nonce, auth.deadline, "0x"];
  assert.equal(c.call.data, artist.encodeFunctionData("recordContentConsent", [tuple, authorization]));
  assert.equal(c.digestCall.data, artist.encodeFunctionData("contentConsentDigest", [tuple, authorization]));
  assert.equal(toSafeCall(c.call).operation, 0); assert.equal(c.call.value, 0n);
  const signed = prepareEntropyRecoveryContentConsent(31337n, registry, core, c.payload.message.collectionId, p, q, { ...auth, signature: "0x1234abcd" });
  assert.equal(signed.payload.digest, c.payload.digest);
  for (const changed of [{ ...q, coordinator: core }, { ...q, oldRequestKey: id("other") }, { ...q, inputHash: id("changed reason or evidence") }]) {
    assert.throws(() => prepareEntropyRecoveryContentConsent(31337n, registry, core, 1n, p, changed, auth), /another recovery/);
  }
  assert.throws(() => prepareEntropyRecoveryContentConsent(31337n, registry, core, 0n, p, q, auth));
});
test("token and scope incident encodings use original distinct selectors and preserve evidence", () => {
  for (const [subject, method, key] of [
    [{ kind: "token", tokenId: (1n << 255n) + 2n }, "markEntropyRequestUnrecoverable", (1n << 255n) + 2n],
    [{ kind: "scope", scopeId: id("scope") }, "markEntropyScopeRequestUnrecoverable", id("scope")],
  ]) {
    const p = prepareEntropyIncident(host, subject, "ipfs://evidence", id("incident"));
    assert.equal(p.data, coordinator.encodeFunctionData(method, [key, "ipfs://evidence", id("incident")]));
    assert.equal(toSafeCall(p).value, "0");
  }
  for (const s of [{ kind: "token", tokenId: 0n }, { kind: "token", tokenId: 1 }, { kind: "scope", scopeId: ZeroHash }, { kind: "other" }]) {
    assert.throws(() => prepareEntropyIncident(host, s, "ipfs://evidence", id("incident")));
  }
});
test("fee credit claim has no executor override and preserves the original destination", () => {
  const c = prepareEntropyFeeCreditClaim(host, core);
  assert.equal(c.data, coordinator.encodeFunctionData("claimEntropyFeeCredit", [core]));
  assert.equal(toSafeCall(c).value, "0");
  assert.throws(() => prepareEntropyFeeCreditClaim(host, "0x" + "0".repeat(40)));
});
test("input checks reject rounded integers, ambiguous fields, missing hashes and oversized UTF-8 reasons", () => {
  for (const value of [1, -1n, 1n << 256n]) assert.throws(() => prepareFreshEntropyRecovery(host, input(), value));
  for (const patch of [{ oldRequestKey: ZeroHash }, { providerEvidenceHash: "0x01" }, { reasonURI: "" },
    { reasonURI: "é".repeat(1025) }, { extra: 1 }]) assert.throws(() => prepareFreshEntropyRecovery(host, { ...input(), ...patch }, 0n));
  assert.doesNotThrow(() => prepareFreshEntropyRecovery(host, { ...input(), reasonURI: "é".repeat(1024) }, 0n));
  assert.throws(() => prepareFreshEntropyRecovery("0x" + "0".repeat(40), input(), 0n));
});
