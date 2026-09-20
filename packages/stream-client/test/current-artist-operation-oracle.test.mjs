import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroHash, concat, getAddress, id, keccak256 } from "ethers";
import { currentArtistOperationTypedData, prepareCurrentArtistAction, CURRENT_ARTIST_OPERATION_ABI } from "../dist/current-artist-operation.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-operation-current-abi.json", import.meta.url), "utf8"));
const coverage = JSON.parse(readFileSync(new URL("../docs/current-artist-operation-coverage.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([name, rows]) => [name, new Interface(rows)]));
const coder = AbiCoder.defaultAbiCoder(), address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const chainId = (1n << 239n) + 31337n, registry = address(10), core = address(20), artistId = id("original artist");
const nonce = (1n << 211n) + 17n, deadline = (1n << 64n) - 1n, collectionId = (1n << 190n) + 71n;
const samples = {
  bindingRefusal: { core, collectionId, bindingGeneration: (1n << 63n) + 3n, bindingHash: id("binding"), reasonHash: id("reason"), nonce, deadline },
  saleConsent: { core, saleAdapter: address(30), collectionId, saleId: id("sale"), saleConfigHash: id("sale config"), nonce, deadline },
  royaltyFreeze: { core, resolver: address(31), collectionId, revenueClass: id("ROYALTY_ERC2981"), expectedAssignmentHash: id("assignment"), nonce, deadline },
  contentFreeze: { core, metadataContract: address(32), collectionId, lockClasses: [1n, 1n << 255n].map(n => `0x${n.toString(16).padStart(64, "0")}`), expectedStateHash: id("metadata state"), nonce, deadline },
  authorizationRevocation: { artistId, revokedDigest: ZeroHash, revokedNonce: nonce + 19n, nonce, deadline },
};
const originals = {
  bindingRefusal: [3n, "StreamArtistBindingRefusal(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 reasonHash,uint256 nonce,uint64 deadline)", "refuseArtistBinding", "bindingRefusalDigest"],
  saleConsent: [16n, "StreamArtistSaleConsent(address core,address saleAdapter,uint256 collectionId,bytes32 saleId,bytes32 saleConfigHash,uint256 nonce,uint64 deadline)", "recordSaleConsent", "saleConsentDigest"],
  royaltyFreeze: [20n, "StreamArtistRoyaltyFreeze(address core,address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash,uint256 nonce,uint64 deadline)", "authorizeArtistRoyaltyFreeze", "royaltyFreezeDigest"],
  contentFreeze: [21n, "StreamArtistContentFreeze(address core,address metadataContract,uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,uint256 nonce,uint64 deadline)", "authorizeArtistContentFreeze", "contentFreezeDigest"],
  authorizationRevocation: [54n, "StreamArtistAuthorizationRevocation(bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce,uint256 nonce,uint64 deadline)", "revokeArtistAuthorization", "authorizationRevocationDigest"],
};
function originalDigest(declaration, message, verifier = registry) {
  const fields = declaration.slice(declaration.indexOf("(") + 1, -1).split(",").map(field => field.split(" "));
  const types = ["bytes32"], values = [id(declaration)];
  for (const [type, name] of fields) {
    types.push(type === "bytes32[]" ? "bytes32" : type);
    values.push(type === "bytes32[]" ? keccak256(concat(message[name])) : message[name]);
  }
  const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), chainId, verifier]));
  return keccak256(concat(["0x1901", domain, keccak256(coder.encode(types, values))]));
}
function request(kind) {
  return { kind, chainId, registry, caller: address(40), signer: address(41), artistId, mode: "signature", signature: "0x123456",
    message: samples[kind], details: kind === "bindingRefusal" ? { reasonURI: "ipfs://original/reason/é" } : {} };
}
function originalTerms(kind, message, details) {
  switch (kind) {
    case "bindingRefusal": return [message.collectionId, message.bindingGeneration, message.bindingHash, message.reasonHash, details.reasonURI];
    case "saleConsent": return [message.collectionId, message.saleAdapter, message.saleId, message.saleConfigHash];
    case "royaltyFreeze": return [message.resolver, message.collectionId, message.revenueClass, message.expectedAssignmentHash];
    case "contentFreeze": return [message.collectionId, message.metadataContract, message.lockClasses, message.expectedStateHash];
    case "authorizationRevocation": return [message.artistId, message.revokedDigest, message.revokedNonce];
    default: throw Error("Unknown independent oracle kind");
  }
}

test("Artist operation fixture retains exact ABI49 provenance and original source texts", () => {
  assert.equal(fixture.sourceCommit, "18be311bc33e8007841f963f218ac8290e271015");
  assert.equal(fixture.sourceCount, 2172);
  assert.equal(fixture.inputSha256, "d72aaf4b8dd4af5db39420038b0c0655a85161071d11a8dc8c9e00f9bc372b64");
  assert.equal(fixture.outputSha256, "e21d5c31e1e10904cacc6577f27c3e036ac25d7c1999f8817d0b9cc6549fe15d");
  assert.equal(Object.keys(fixture.sourceHashes).length, 298);
  assert.equal(Object.keys(fixture.sourceTexts).length, 6);
  for (const [path, literal] of Object.entries(fixture.sourceTexts)) {
    assert.equal(createHash("sha256").update(literal).digest("hex"), fixture.sourceHashes[path]);
  }
  assert.match(fixture.qualification, /do not establish deployed Artist/);
});

test("coverage preserves all original IDs, successor facade naming, withdrawal and separate public variants", () => {
  assert.equal(coverage.sourceCommit, fixture.sourceCommit);
  assert.deepEqual(coverage.operations.map(row => row.id), Array.from({ length: 61 }, (_, i) => i + 1));
  const successor = coverage.operations[35];
  assert.equal(successor.operation, "designateSuccessor");
  assert.deepEqual(successor.methods, ["recordSuccessorDesignation"]);
  assert.equal(coverage.operations[60].operation, "withdrawAttributionDispute");
  assert.match(coverage.operations[60].scope, /outside original 1-60/);
  const methods = coverage.operations.flatMap(row => row.methods);
  assert.equal(methods.length, 79); assert.equal(new Set(methods).size, methods.length);
  for (const name of methods) assert.equal(fixture.publicMethods.filter(row => row.name === name).length, 1, name);
  const covered = new Set([...methods, ...coverage.additionalPublicMutations.map(row => row.method)]);
  assert.deepEqual(fixture.publicMethods.filter(row => !["view", "pure"].includes(row.stateMutability) && !covered.has(row.name)), []);
  assert.ok(coverage.operations[19].methods.includes("authorizeDelegatedRoyaltyFreeze"));
  assert.equal(coverage.operations[59].methods.length, 6);
});

test("compiler-selected calls retain original selectors, authorization widths and zero-value transaction semantics", () => {
  const expected = {
    refuseArtistBinding: "0x36f9a7b8", recordSaleConsent: "0x918713ec", authorizeArtistRoyaltyFreeze: "0xc3b3a4de",
    authorizeArtistContentFreeze: "0x04018800", revokeArtistAuthorization: "0xd5b33019",
  };
  for (const [name, selector] of Object.entries(expected)) {
    const method = abi.registry.getFunction(name);
    assert.equal(method.selector, selector); assert.equal(method.stateMutability, "nonpayable");
    assert.equal(method.inputs[1].format("sighash"), "(uint256,uint64,bytes)");
    assert.equal(fixture.publicMethods.find(row => row.name === name).signature, method.format("sighash"));
    assert.equal(id(method.format("sighash")).slice(0, 10), selector);
  }
  assert.equal(abi.registry.getFunction("authorizeArtistContentFreeze").inputs[0].components[2].type, "bytes32[]");
  assert.equal(abi.registry.getFunction("refuseArtistBinding").inputs[0].components.at(-1).type, "string");
});

test("receipt ABI comes from the actual semantic owners and original Archive", () => {
  assert.equal(abi.attribution.getEvent("ArtistBindingTerminationContext").inputs[0].type, "uint16");
  assert.equal(abi.consent.getEvent("ArtistSaleConsentRecorded").inputs[0].type, "uint16");
  assert.equal(abi.identity.getEvent("ArtistAuthorizationRevoked").inputs[1].name, "artistId");
  assert.equal(abi.identity.getEvent("ArtistAuthorizationRevoked").inputs[1].indexed, true);
  const event = abi.archive.getEvent("ArtistArchiveEvidenceAppendedV2");
  assert.ok(event.inputs.some(row => row.type === "bytes32" && row.indexed));
  assert.equal(abi.registry.getEvent("ArtistAuthorizationRevoked"), null);
});

test("five new payloads reproduce original contract hashes without TypedDataEncoder", () => {
  const texts = Object.values(fixture.sourceTexts).join("\n");
  for (const [kind, [, declaration]] of Object.entries(originals)) {
    if (kind === "bindingRefusal") assert.ok(texts.includes(`bytes32(${id(declaration)})`));
    else assert.ok(texts.includes(`"${declaration}"`), declaration);
    const payload = currentArtistOperationTypedData(kind, chainId, registry, samples[kind]);
    assert.equal(payload.digest, originalDigest(declaration, samples[kind]));
    assert.notEqual(payload.digest, originalDigest(declaration, samples[kind], address(99)));
    assert.equal(payload.domain.name, "6529StreamArtistRegistry"); assert.equal(payload.domain.version, "1");
    assert.equal(payload.domain.verifyingContract, registry);
  }
});

test("principal action calls and digest reads match original compiler tuples including the resolver-first freeze", () => {
  const handwritten = new Interface(CURRENT_ARTIST_OPERATION_ABI);
  for (const [kind, [operationId, , method, digestMethod]] of Object.entries(originals)) {
    const input = request(kind), prepared = prepareCurrentArtistAction(input), terms = originalTerms(kind, input.message, input.details);
    assert.equal(prepared.operationId, operationId); assert.equal(prepared.method, method); assert.equal(prepared.digestMethod, digestMethod);
    assert.deepEqual(prepared.call, { to: registry, value: 0n, data: abi.registry.encodeFunctionData(method, [terms, [nonce, deadline, input.signature]]) });
    assert.deepEqual(prepared.digestCall, { to: registry, value: 0n, data: abi.registry.encodeFunctionData(digestMethod, [terms, [nonce, deadline, "0x"]]) });
    for (const name of [method, digestMethod]) {
      const local = handwritten.getFunction(name), original = abi.registry.getFunction(name);
      assert.equal(local.format("sighash"), original.format("sighash"));
      assert.equal(local.stateMutability, original.stateMutability);
      assert.deepEqual(local.outputs.map(row => row.format("sighash")), original.outputs.map(row => row.format("sighash")));
    }
  }
});

test("unsigned refusal URI stays in reviewed calldata while locks are hashed as packed words", () => {
  const input = request("bindingRefusal"), prepared = prepareCurrentArtistAction(input);
  const alternate = prepareCurrentArtistAction({ ...input, details: { reasonURI: "ipfs://another/evidence" } });
  assert.equal(alternate.payload.digest, prepared.payload.digest); assert.notEqual(alternate.call.data, prepared.call.data);
  const [,, freezeWrite] = originals.contentFreeze;
  const freeze = prepareCurrentArtistAction(request("contentFreeze")), decoded = abi.registry.decodeFunctionData(freezeWrite, freeze.call.data);
  assert.deepEqual(Array.from(decoded[0].lockClasses), samples.contentFreeze.lockClasses);
  const reversed = { ...samples.contentFreeze, lockClasses: [...samples.contentFreeze.lockClasses].reverse() };
  assert.notEqual(originalDigest(originals.contentFreeze[1], reversed), freeze.payload.digest);
  assert.throws(() => currentArtistOperationTypedData("contentFreeze", chainId, registry, reversed), /strictly increasing/);
});
