import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, concat, id, keccak256, ZeroHash } from "ethers";
import { prepareScriptManifest, prepareMediaManifest, readManifestContentState, prepareManifestContentConsent, assertCurrentArtistDigest, toSafeCall } from "../dist/index.js";
const fixture = JSON.parse(await readFile(new URL("./fixtures/current-manifest-abi.json", import.meta.url), "utf8"));
const iface = new Interface(fixture.abi), coder = AbiCoder.defaultAbiCoder();
const router = "0x0000000000000000000000000000000000006529", registry = "0x0000000000000000000000000000000000000042", core = "0x0000000000000000000000000000000000000007";
const collectionId = (1n << 255n) + 19n;
function script() { return { scriptHash: id("bytes"), rendererCompatibility: id("renderer"), sourceType: 1n, libraryURI: "", scriptURI: "urn:script", sourcePointer: "", mimeType: "text/javascript", chunkCount: 1n, executable: true }; }
function media() { return { imageSourceType: 5n, imageURI: "ipfs://image", imageHash: ZeroHash, imageMimeType: "image/png", animationSourceType: 0n, animationURI: "", animationHash: ZeroHash, animationMimeType: "", contentSourceType: 7n, contentURI: "https://example.test/art", contentHash: id("art"), contentMimeType: "application/pdf", manifestURI: "https://example.test/manifest", manifestHash: ZeroHash, alternatesURI: "", alternatesHash: ZeroHash }; }
const families = [["Script", prepareScriptManifest, script, "SCRIPT"], ["Media", prepareMediaManifest, media, "MEDIA_MANIFEST"]];
test("manifest calls match compiled full structs and remain zero-value Safe CALLs", () => {
  for (const [kind, prepare, value, family] of families) {
    const m = value(), p = prepare(router, collectionId, m);
    assert.equal(p.call.data, iface.encodeFunctionData(`setCollection${kind}Manifest`, [collectionId, m]));
    assert.equal(p.previewCall.data, iface.encodeFunctionData(`previewArtist${kind}ManifestState`, [collectionId, m]));
    assert.equal(p.familyId, id(family));
    assert.deepEqual(toSafeCall(p.call), { to: router, value: "0", data: p.call.data, operation: 0 });
    const original = p.call.data; m.mimeType = "mutated"; assert.equal(p.call.data, original); assert(Object.isFrozen(p));
  }
});
test("absent external hashes round-trip without replacing them with URI hashes", () => {
  const m = media(), p = prepareMediaManifest(router, collectionId, m);
  const [, result] = iface.decodeFunctionData("setCollectionMediaManifest", p.call.data);
  assert.equal(result.imageHash, ZeroHash); assert.equal(result.manifestHash, ZeroHash);
  assert.equal(result.imageURI, m.imageURI); assert.notEqual(id(m.imageURI), result.imageHash);
});
test("manifest input validation rejects rounded integers, unknown enum values and malformed tuples", () => {
  for (const bad of [0n, -1n, 1, 1n << 256n]) assert.throws(() => prepareScriptManifest(router, bad, script()));
  for (const bad of [1, -1n, 1n << 256n]) assert.throws(() => prepareScriptManifest(router, 1n, { ...script(), chunkCount: bad }));
  for (const bad of [1, 9n, -1n]) assert.throws(() => prepareScriptManifest(router, 1n, { ...script(), sourceType: bad }));
  for (const patch of [{ extra: true }, { executable: "false" }, { scriptHash: "0x1234" }, { libraryURI: null }]) assert.throws(() => prepareScriptManifest(router, 1n, { ...script(), ...patch }));
  assert.throws(() => prepareMediaManifest("0x" + "0".repeat(40), 1n, media()));
  assert.throws(() => prepareMediaManifest(router, 1n, { ...media(), animationSourceType: 256n }));
});
test("preview reads exact current family state and propagates block tags and contract failures", async () => {
  for (const [, prepare, value] of families) {
    const p = prepare(router, collectionId, value()), state = id("actual preview");
    const provider = { call: async tx => { assert.equal(tx.to, router); assert.equal(tx.data, p.previewCall.data); assert.equal(tx.blockTag, 123); return iface.encodeFunctionResult(p.previewMethod, [state]); } };
    assert.equal(await readManifestContentState(provider, p, { blockTag: 123 }), state);
    await assert.rejects(readManifestContentState({ call: async () => iface.encodeFunctionResult(p.previewMethod, [ZeroHash]) }, p), /Missing/);
    await assert.rejects(readManifestContentState({ call: async () => { throw new Error("locked profile"); } }, p), /locked profile/);
  }
});
test("content consent preserves original Solidity digest, full widths, and actual Safe execution", async () => {
  for (const [, prepare, value] of families) {
    const p = prepare(router, collectionId, value()), state = id("consented family"), auth = { nonce: (1n << 255n) + 2n, deadline: (1n << 63n) + 3n, signature: "0x" };
    const c = prepareManifestContentConsent(31337n, registry, core, p, state, auth);
    const structure = keccak256(coder.encode(["bytes32", "address", "address", "uint256", "bytes32", "bytes32", "uint256", "uint64"], [id(fixture.contentConsentTypePreimage), core, router, collectionId, p.familyId, state, auth.nonce, auth.deadline]));
    const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"], [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), 31337n, registry]));
    assert.equal(c.payload.digest, keccak256(concat(["0x1901", domain, structure])));
    const terms = [collectionId, router, p.familyId, state];
    assert.equal(c.call.data, iface.encodeFunctionData("recordContentConsent", [terms, [auth.nonce, auth.deadline, "0x"]]));
    assert.equal(c.digestCall.data, iface.encodeFunctionData("contentConsentDigest", [terms, [auth.nonce, auth.deadline, "0x"]]));
    assert.equal(toSafeCall(c.call).to, registry); assert.equal(toSafeCall(c.call).operation, 0);
    const relayed = prepareManifestContentConsent(31337n, registry, core, p, state, { ...auth, signature: "0x1234abcd" });
    assert.equal(relayed.payload.digest, c.payload.digest); assert.equal(iface.decodeFunctionData("recordContentConsent", relayed.call.data)[1].signature, "0x1234abcd");
    const provider = { getNetwork: async () => ({ chainId: 31337n }), call: async tx => { assert.equal(tx.data, c.digestCall.data); return iface.encodeFunctionResult("contentConsentDigest", [c.payload.digest]); } };
    await assertCurrentArtistDigest(provider, c);
    await assert.rejects(assertCurrentArtistDigest({ ...provider, getNetwork: async () => ({ chainId: 1n }) }, c), /chain/);
    assert.notEqual(prepareManifestContentConsent(31337n, registry, core, p, id("drift"), auth).payload.digest, c.payload.digest);
    for (const bad of [{ deadline: 1n << 64n }, { nonce: 1 }, { signature: "0x1" }]) assert.throws(() => prepareManifestContentConsent(31337n, registry, core, p, state, { ...auth, ...bad }));
    assert.throws(() => prepareManifestContentConsent(31337n, registry, core, p, ZeroHash, auth));
  }
});
