import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, TypedDataEncoder, ZeroHash, concat, id, keccak256, toUtf8Bytes } from "ethers";
import { currentArtistTypedData, currentArtistTypedDataFromJSON, prepareCurrentArtistOperation, assertCurrentArtistDigest, toSafeCall, toJSON, walletTypedData } from "../dist/index.js";

const hashes = await readFile(new URL("../../../smart-contracts/domains/artist/StreamArtistHashes.sol", import.meta.url), "utf8");
const collabHashes = await readFile(new URL("../../../smart-contracts/domains/artist/StreamArtistCollaboratorHashes.sol", import.meta.url), "utf8");
const fixture = JSON.parse(await readFile(new URL("./fixtures/current-artist-operation-abi.json", import.meta.url), "utf8"));
const iface = new Interface(fixture.abi), coder = AbiCoder.defaultAbiCoder();
const registry = "0x0000000000000000000000000000000000000011", address = "0x0000000000000000000000000000000000000022";
const types = {
  artistAcceptance: "StreamArtistAcceptance", artistPolicyConsent: "StreamArtistPolicyConsent",
  artistEconomicsConsent: "StreamArtistEconomicsConsent", artistPayoutDesignation: "StreamArtistPayoutDesignation",
  artistAttestation: "StreamArtistAttestation", artistContentRatification: "StreamArtistContentRatification",
  collaboratorIdentityAcceptance: "StreamCollaboratorIdentityAcceptance", collaboratorAcceptance: "StreamCollaboratorAcceptance",
};
const document = "0x1234", statement = "0x5678", statementURI = "urn:stream:test:statement";
function fields(kind) {
  const source = kind.startsWith("collaborator") ? collabHashes : hashes;
  const declaration = source.match(new RegExp('"' + types[kind] + '\\(([^"]+)\\)"'))?.[1];
  assert(declaration, "canonical source type declaration exists");
  return declaration.split(",").map(s => { const [type, name] = s.split(" "); return { type, name }; });
}
function message(kind) {
  return Object.fromEntries(fields(kind).map(({ name, type }) => [name,
    type === "address" ? address : name === "identityRecordHash" ? keccak256(document)
      : name === "statementHash" ? keccak256(statement) : name === "statementURIHash" ? keccak256(toUtf8Bytes(statementURI))
      : type === "bytes32" ? id(name) : type === "uint8" ? 1n : 9007199254740993n]));
}
function submission(kind, signature = "0x123456") {
  return { signature, ...(kind === "artistEconomicsConsent" ? { collectionId: 1n } : {}),
    ...(kind === "artistAttestation" ? { statementURI, statement } : {}),
    ...(kind === "collaboratorIdentityAcceptance" ? { document, displayName: "Collaborator" } : {}) };
}
function plan(kind, sig = "0x123456") { return prepareCurrentArtistOperation(kind, 31337n, registry, message(kind), submission(kind, sig)); }

test("eight current Artist schemas reproduce the canonical Solidity preimages", () => {
  const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), 31337n, registry]));
  for (const kind of Object.keys(types)) {
    const m = message(kind), fs = fields(kind), p = currentArtistTypedData(kind, 31337n, registry, m);
    assert.equal(p.primaryType, types[kind]); assert.deepEqual(p.types[p.primaryType], fs);
    const typeHash = id(types[kind] + "(" + fs.map(f => f.type + " " + f.name).join(",") + ")");
    const structure = keccak256(coder.encode(["bytes32", ...fs.map(f => f.type)], [typeHash, ...fs.map(f => m[f.name])]));
    assert.equal(p.digest, keccak256(concat(["0x1901", domain, structure])));
    assert.equal(TypedDataEncoder.hash(p.domain, p.types, p.message), p.digest);
  }
});

test("each signed field and both domain coordinates affect every current Artist digest", () => {
  for (const kind of Object.keys(types)) {
    const m = message(kind), original = currentArtistTypedData(kind, 31337n, registry, m).digest;
    for (const f of fields(kind)) {
      const value = f.type === "address" ? registry : f.type === "bytes32" ? ZeroHash : m[f.name] + 1n;
      assert.notEqual(currentArtistTypedData(kind, 31337n, registry, { ...m, [f.name]: value }).digest, original);
    }
    assert.notEqual(currentArtistTypedData(kind, 1n, registry, m).digest, original);
    assert.notEqual(currentArtistTypedData(kind, 31337n, address, m).digest, original);
  }
});

test("all eight write and digest calls decode with the actual compiled facade ABI and retain Safe CALL semantics", () => {
  assert.equal(fixture.abi.length, 16);
  for (const kind of Object.keys(types)) {
    const p = plan(kind), write = iface.parseTransaction(p.call), read = iface.parseTransaction(p.digestCall);
    assert.equal(write.name, p.method); assert.equal(read.name, p.digestMethod);
    const authIndex = kind === "collaboratorIdentityAcceptance" ? 2 : 1;
    assert.equal(write.args[authIndex].nonce, p.payload.message.nonce);
    assert.equal(write.args[authIndex].time, p.payload.message.deadline ?? p.payload.message.signedAt);
    assert.equal(write.args[authIndex].signature, "0x123456"); assert.equal(read.args[authIndex].signature, "0x");
    assert.deepEqual(toSafeCall(p.call), { to: registry, value: "0", data: p.call.data, operation: 0 });
    assert.equal(p.digestCall.to, registry);
  }
  const economics = plan("artistEconomicsConsent");
  assert.equal(iface.parseTransaction(economics.call).args[0].collectionId, 1n);
  assert(!Object.hasOwn(economics.payload.message, "collectionId"), "preserve permanent economics signature");
  const collaborator = plan("collaboratorAcceptance");
  assert.equal(iface.parseTransaction(collaborator.call).args[0].generation, collaborator.payload.message.bindingGeneration);
  assert.equal(iface.parseTransaction(collaborator.call).args[0].account, collaborator.payload.message.collaborator);
});

test("document and statement hash mismatches cannot produce calls", () => {
  assert.throws(() => prepareCurrentArtistOperation("collaboratorIdentityAcceptance", 31337n, registry, message("collaboratorIdentityAcceptance"),
    { ...submission("collaboratorIdentityAcceptance"), document: "0x99" }), /document differs/);
  assert.throws(() => prepareCurrentArtistOperation("artistAttestation", 31337n, registry, message("artistAttestation"),
    { ...submission("artistAttestation"), statement: "0x99" }), /statement bytes differ/);
  assert.throws(() => prepareCurrentArtistOperation("artistAttestation", 31337n, registry, message("artistAttestation"),
    { ...submission("artistAttestation"), statementURI: "changed" }), /URI differs/);
  assert.throws(() => prepareCurrentArtistOperation("artistEconomicsConsent", 31337n, registry, message("artistEconomicsConsent"),
    { signature: "0x", collectionId: 1 }), /bigint/);
});

test("direct-authority calls retain empty signature while relayed dated records require signedAt", () => {
  for (const kind of Object.keys(types)) {
    const direct = plan(kind, "0x"), decoded = iface.parseTransaction(direct.call);
    assert.equal(decoded.args[kind === "collaboratorIdentityAcceptance" ? 2 : 1].signature, "0x");
    assert.throws(() => prepareCurrentArtistOperation(kind, 31337n, registry, message(kind), submission(kind, "0x1")), /complete hex bytes/);
  }
  for (const kind of ["artistPayoutDesignation", "artistAttestation"]) {
    const m = { ...message(kind), signedAt: 0n };
    assert.throws(() => prepareCurrentArtistOperation(kind, 31337n, registry, m, submission(kind)), /explicit signedAt/);
    assert(prepareCurrentArtistOperation(kind, 31337n, registry, m, submission(kind, "0x")));
  }
});

test("current Artist JSON rejects lossy numbers, missing/extra fields, invalid kinds and uint overflow", () => {
  for (const kind of Object.keys(types)) {
    const m = message(kind), p = currentArtistTypedData(kind, 31337n, registry, m);
    const request = JSON.parse(toJSON({ kind, chainId: 31337n, verifyingContract: registry, message: m }));
    assert.equal(currentArtistTypedDataFromJSON(request).digest, p.digest);
    assert.throws(() => currentArtistTypedDataFromJSON({ ...request, message: { ...request.message, nonce: Number(m.nonce) } }), /decimal string/);
    for (const f of fields(kind)) {
      const { [f.name]: ignored, ...missing } = m;
      assert.throws(() => currentArtistTypedData(kind, 31337n, registry, missing));
      if (f.type.startsWith("uint")) for (const bad of [-1n, 1n << BigInt(f.type.slice(4)), "1", 1]) {
        assert.throws(() => currentArtistTypedData(kind, 31337n, registry, { ...m, [f.name]: bad }));
      }
    }
    assert.throws(() => currentArtistTypedData(kind, 31337n, registry, { ...m, extra: true }));
    const wallet = walletTypedData(p), { EIP712Domain, ...walletTypes } = wallet.types;
    assert.equal(TypedDataEncoder.hash(wallet.domain, walletTypes, wallet.message), p.digest);
    m.nonce = 1n; assert.notEqual(m.nonce, p.message.nonce);
    assert.throws(() => { p.message.nonce = 2n; });
  }
  for (const kind of ["__proto__", "constructor", "auction"]) assert.throws(() => currentArtistTypedData(kind, 31337n, registry, {}), /Unknown/);
});

test("live digest comparison checks chain and rejects stale or foreign current facade results", async () => {
  for (const kind of Object.keys(types)) {
    const p = plan(kind), observed = [];
    const provider = { getNetwork: async () => ({ chainId: 31337n }), call: async tx => {
      observed.push(tx); return iface.encodeFunctionResult(p.digestMethod, [p.payload.digest]);
    } };
    await assertCurrentArtistDigest(provider, p, { blockTag: 123 });
    assert.deepEqual(observed, [{ ...p.digestCall, blockTag: 123 }]);
    await assert.rejects(assertCurrentArtistDigest({ ...provider, getNetwork: async () => ({ chainId: 1n }) }, p), /chain/);
    await assert.rejects(assertCurrentArtistDigest({ ...provider, call: async () => iface.encodeFunctionResult(p.digestMethod, [ZeroHash]) }, p), /differs/);
    await assert.rejects(assertCurrentArtistDigest({ ...provider, call: async () => "0x" }, p));
  }
});

test("direct Safe onboarding example checks the facade before exporting and cannot discard relayed signatures", async () => {
  const { prepareArtistSafeCall } = await import("../examples/current-artist-onboarding.mjs");
  const kind = "artistAcceptance", p = plan(kind, "0x");
  const provider = { getNetwork: async () => ({ chainId: 31337n }),
    call: async tx => { assert.equal(tx.data, p.digestCall.data); return iface.encodeFunctionResult(p.digestMethod, [p.payload.digest]); } };
  const result = await prepareArtistSafeCall(provider, kind, 31337n, registry, message(kind));
  assert.deepEqual(result.transaction, toSafeCall(p.call));
  await assert.rejects(prepareArtistSafeCall(provider, kind, 31337n, registry, message(kind), { signature: "0x1234" }), /relayed signature/);
  await assert.rejects(prepareArtistSafeCall({ ...provider, call: async () => iface.encodeFunctionResult(p.digestMethod, [ZeroHash]) },
    kind, 31337n, registry, message(kind)), /differs/);
});
