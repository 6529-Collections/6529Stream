import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { Interface, TypedDataEncoder, ZeroHash } from "ethers";
import { currentTypedData, currentTypedDataFromJSON, typedDataFromJSON, walletTypedData, toJSON, BoundStreamClient, nativeAuctionCreationTypedData, nativeAuctionBidTypedData, nativeCustodyAcquisitionTypedData, preparedNativeCustodyAcquisitionTypedData } from "../dist/index.js";

const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-auction-digests.json", import.meta.url), "utf8"));
const wrappers = { nativeAuctionCreation: nativeAuctionCreationTypedData, nativeAuctionBid: nativeAuctionBidTypedData, nativeCustodyAcquisition: nativeCustodyAcquisitionTypedData, preparedNativeCustodyAcquisition: preparedNativeCustodyAcquisitionTypedData };
const types = { nativeAuctionCreation: ["6529StreamNativeEnglishAuction", "NativeAuctionCreation"], nativeAuctionBid: ["6529StreamNativeEnglishAuction", "NativeAuctionBid"], nativeCustodyAcquisition: ["6529StreamNativeCustodyAuction", "NativeCustodyAcquisition"], preparedNativeCustodyAcquisition: ["6529StreamPreparedNativeCustodyAuction", "PreparedNativeCustodyAcquisition"] };
const other = "0x0000000000000000000000000000000000000001";

test("four current helpers match actual native getter vectors and exact ABI tuple widths", () => {
  assert.deepEqual(fixture.vectors.map(v => v.request.kind).sort(), Object.keys(wrappers).sort());
  assert.equal(fixture.nativeBuildId, "9afed4da42860457");
  for (const vector of fixture.vectors) {
    const payload = currentTypedDataFromJSON(vector.request), [name, primaryType] = types[vector.request.kind];
    assert.equal(payload.domain.name, name); assert.equal(payload.domain.version, "1");
    assert.equal(payload.primaryType, primaryType); assert.equal(payload.digest, vector.digest);
    assert.deepEqual(payload.types[primaryType], vector.fields);
    assert.equal(TypedDataEncoder.from(payload.types).encodeType(primaryType), primaryType + "(" + vector.fields.map(f => f.type + " " + f.name).join(",") + ")");
    assert.equal(wrappers[vector.request.kind](BigInt(vector.request.chainId), vector.request.verifyingContract, payload.message).digest, vector.digest);
    const iface = new Interface(fixture.getterAbi);
    assert.equal(iface.encodeFunctionData(vector.getter, [payload.message]), vector.calldata);
    assert.equal(iface.decodeFunctionResult(vector.getter, vector.result)[0], vector.digest);
  }
});

test("every current signed field, chain and actual house changes the digest", () => {
  for (const vector of fixture.vectors) {
    const p = currentTypedDataFromJSON(vector.request), kind = vector.request.kind;
    assert.notEqual(currentTypedData(kind, 1n, fixture.house, p.message).digest, p.digest);
    assert.notEqual(currentTypedData(kind, 31337n, other, p.message).digest, p.digest);
    for (const field of vector.fields) {
      const changed = field.type === "address" ? other : field.type === "bytes32" ? ZeroHash : p.message[field.name] + 1n;
      assert.notEqual(currentTypedData(kind, 31337n, fixture.house, { ...p.message, [field.name]: changed }).digest, p.digest, kind + "." + field.name);
    }
  }
});

test("single-step and prepared custody sign different domains for exactly the same twelve coordinates", () => {
  const [single, prepared] = fixture.vectors.slice(2);
  assert.deepEqual(single.request.message, prepared.request.message);
  assert.notEqual(single.digest, prepared.digest);
  for (const vector of fixture.vectors) assert.throws(() => typedDataFromJSON(vector.request), /Unknown signing kind/);
  assert.throws(() => currentTypedDataFromJSON({ ...single.request, kind: "auction" }), /Unknown current/);
});

test("all current fields reject omissions, extras, wrong types and unsigned integer overflow", () => {
  for (const vector of fixture.vectors) {
    const p = currentTypedDataFromJSON(vector.request), kind = vector.request.kind;
    assert.throws(() => currentTypedData(kind, 31337n, fixture.house, { ...p.message, extra: true }));
    for (const field of vector.fields) {
      const { [field.name]: removed, ...missing } = p.message;
      assert.throws(() => currentTypedData(kind, 31337n, fixture.house, missing));
      const bad = field.type === "address" ? ["0x12", 1n] : field.type === "bytes32" ? ["0x12", 1n] : [1, "1", -1n, 1n << BigInt(field.type.slice(4))];
      for (const value of bad) assert.throws(() => currentTypedData(kind, 31337n, fixture.house, { ...p.message, [field.name]: value }), kind + "." + field.name);
    }
    for (const chain of [0n, -1n, 1n << 256n, 1]) assert.throws(() => currentTypedData(kind, chain, fixture.house, p.message));
  }
});

test("current JSON and immutable wallet payloads preserve high-width values without accepting lossy numbers", () => {
  for (const vector of fixture.vectors) {
    const request = structuredClone(vector.request), p = currentTypedDataFromJSON(request);
    const integer = vector.fields.find(f => f.type.startsWith("uint")).name;
    const original = p.message[integer]; assert(original > BigInt(Number.MAX_SAFE_INTEGER));
    request.message[integer] = "1"; assert.equal(p.message[integer], original);
    assert.throws(() => { p.message[integer] = 1n; });
    assert.throws(() => { p.domain.chainId = 1n; });
    assert.throws(() => { p.types[p.primaryType][0].name = "changed"; });
    assert.equal(currentTypedDataFromJSON(JSON.parse(toJSON(vector.request))).digest, p.digest);
    for (const value of [Number(original), "01", "-1", "1e3", " 1"]) assert.throws(() => currentTypedDataFromJSON({ ...vector.request, message: { ...vector.request.message, [integer]: value } }));
    assert.throws(() => currentTypedDataFromJSON({ ...vector.request, chainId: 31337 }));
    assert.throws(() => currentTypedDataFromJSON({ ...vector.request, extra: true }));
    const rpc = walletTypedData(p); const { EIP712Domain, ...fields } = rpc.types;
    assert.equal(TypedDataEncoder.hash(rpc.domain, fields, rpc.message), p.digest);
    assert.equal(rpc.message[integer], original.toString()); assert.equal(EIP712Domain.length, 4);
  }
  for (const kind of ["__proto__", "constructor", "toString"]) assert.throws(() => currentTypedData(kind, 31337n, fixture.house, {}), /Unknown current/);
});

test("the current bound client checks canonical getter bytes and refuses a substituted custody domain or house", async () => {
  const iface = new Interface(fixture.getterAbi);
  let calls = 0;
  const provider = { getNetwork: async () => ({ chainId: 31337n }), call: async tx => {
    calls++; assert.equal(tx.to.toLowerCase(), fixture.house.toLowerCase());
    const vector = fixture.vectors.find(v => v.calldata === tx.data); assert(vector, "exact original getter calldata"); return vector.result;
  } };
  const config = { schemaVersion: 1, chainId: 31337n, addresses: { core: other, nativeAuction: fixture.house, preparedCustody: fixture.house } };
  const client = new BoundStreamClient(provider, config, { core: [], nativeAuction: fixture.getterAbi, preparedCustody: fixture.getterAbi });
  for (const vector of fixture.vectors) {
    const p = currentTypedDataFromJSON(vector.request); await client.assertDigest(p, "nativeAuction", vector.getter, [p.message]);
    assert.equal(iface.encodeFunctionData(vector.getter, [p.message]), vector.calldata);
  }
  const prepared = currentTypedDataFromJSON(fixture.vectors[3].request);
  await client.assertDigest(prepared, "preparedCustody", "preparedCustodyAcquisitionDigest", [prepared.message]);
  await assert.rejects(client.assertDigest(prepared, "nativeAuction", "custodyAcquisitionDigest", [prepared.message]), /differs/);
  const before = calls;
  await assert.rejects(client.assertDigest(currentTypedData("preparedNativeCustodyAcquisition", 31337n, other, prepared.message), "preparedCustody", "preparedCustodyAcquisitionDigest", [prepared.message]), /domain differs/);
  assert.equal(calls, before);
});

test("current creation review checks the canonical configuration and getter before returning a signable payload", async () => {
  const { reviewNativeAuctionCreation } = await import("../examples/current-auction-signing.mjs");
  const vector = fixture.vectors[0], authorization = currentTypedDataFromJSON(vector.request).message;
  const configuration = Object.freeze({ fixture: "caller-supplied current configuration" });
  const sequence = [];
  const client = {
    config: { chainId: 31337n }, address: name => { assert.equal(name, "nativeAuction"); return fixture.house; },
    read: async (name, getter, args) => { assert.equal(name, "nativeAuction"); assert.equal(getter, "auctionConfigurationHash"); assert.equal(args[0], configuration); sequence.push("configuration"); return authorization.configHash; },
    assertDigest: async (payload, name, getter, args) => { assert.equal(name, "nativeAuction"); assert.equal(getter, vector.getter); assert.equal(payload.digest, vector.digest); assert.equal(args[0], payload.message); sequence.push("digest"); },
  };
  const reviewed = await reviewNativeAuctionCreation(client, configuration, authorization);
  assert.equal(reviewed.digest, vector.digest); assert.deepEqual(sequence, ["configuration", "digest"]);
  sequence.length = 0;
  await assert.rejects(reviewNativeAuctionCreation({ ...client, read: async () => ZeroHash }, configuration, authorization), /configuration differs/);
  assert.deepEqual(sequence, [], "mismatched configuration cannot return a signable result");
  await assert.rejects(reviewNativeAuctionCreation({ ...client, assertDigest: async () => { throw new Error("getter mismatch"); } }, configuration, authorization), /getter mismatch/);
});
