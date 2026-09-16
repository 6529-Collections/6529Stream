import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, TypedDataEncoder, concat, id, keccak256, ZeroHash } from "ethers";
import { currentTypedData, currentTypedDataFromJSON, tokenProfileCustodyActivationTypedData, custodyRightsActivationTypedData, prepareCustodyActivation, prepareCustodyBid, prepareCustodySettlement, assertCustodyActivationDigest, toSafeCall, walletTypedData } from "../dist/index.js";
const fixture = JSON.parse(await readFile(new URL("./fixtures/current-custody-operation-abi.json", import.meta.url), "utf8"));
const house = "0x0000000000000000000000000000000000006529";
const artist = "0x0000000000000000000000000000000000000042";
const coder = AbiCoder.defaultAbiCoder();
const wrappers = { tokenProfileCustodyActivation: tokenProfileCustodyActivationTypedData, custodyRightsActivation: custodyRightsActivationTypedData };
function message(kind) {
  return { auctionId: id("auction"), baseConfigHash: id("base"), originHash: id("origin"), tokenId: (1n << 255n) + 7n,
    ...(kind === "custodyRightsActivation" ? { rightsMode: 4n } : {}), assignmentHash: id("assignment"), primaryPolicyHash: id("policy"), primaryPolicyMode: 1n,
    artist, nonce: id("nonce"), deadline: (1n << 63n) + 1n };
}
const signatures = { platformSignature: "0x123456", artistSignature: "0x0102030405" };

test("both custody approvals match independent Solidity EIP-712 preimages and compiled tuple widths", () => {
  for (const [kind, f] of Object.entries(fixture.families)) {
    const m = message(kind), p = wrappers[kind](31337n, house, m);
    const fields = f.typePreimage.slice(f.typePreimage.indexOf("(") + 1, -1).split(",").map(x => x.split(" "));
    const structure = keccak256(coder.encode(["bytes32", ...fields.map(x => x[0])], [id(f.typePreimage), ...fields.map(x => m[x[1]])]));
    const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"], [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id(f.domain), id("1"), 31337n, house]));
    assert.equal(p.digest, keccak256(concat(["0x1901", domain, structure])));
    assert.equal(TypedDataEncoder.from(p.types).encodeType(p.primaryType), f.typePreimage);
    const iface = new Interface(f.abi), tuple = iface.getFunction(f.getter).inputs[0];
    assert.deepEqual(tuple.components.map(x => [x.type, x.name]), fields);
    const rpc = walletTypedData(p), { EIP712Domain, ...types } = rpc.types;
    assert.equal(TypedDataEncoder.hash(rpc.domain, types, rpc.message), p.digest);
  }
});

test("every approval coordinate and family, chain and house is bound", () => {
  for (const [kind, f] of Object.entries(fixture.families)) {
    const m = message(kind), p = currentTypedData(kind, 31337n, house, m);
    for (const field of p.types[p.primaryType]) {
      const value = field.type === "address" ? house : field.type === "bytes32" ? ZeroHash : m[field.name] + 1n;
      assert.notEqual(currentTypedData(kind, 31337n, house, { ...m, [field.name]: value }).digest, p.digest);
    }
    assert.notEqual(currentTypedData(kind, 1n, house, m).digest, p.digest);
    assert.notEqual(currentTypedData(kind, 31337n, artist, m).digest, p.digest);
  }
  const { rightsMode, ...profile } = message("custodyRightsActivation");
  assert.notEqual(custodyRightsActivationTypedData(31337n, house, { ...profile, rightsMode }).digest, tokenProfileCustodyActivationTypedData(31337n, house, profile).digest);
});

test("activation, bidding and settlement use exact compiled entry families and preserve Safe CALL value", () => {
  for (const [kind, f] of Object.entries(fixture.families)) {
    const iface = new Interface(f.abi), m = message(kind), prepared = prepareCustodyActivation(kind, 31337n, house, m, signatures);
    assert.equal(prepared.call.data, iface.encodeFunctionData("activate" + f.stem, [m, signatures.platformSignature, signatures.artistSignature]));
    assert.equal(prepared.digestCall.data, iface.encodeFunctionData(f.getter, [m]));
    const decoded = iface.decodeFunctionData("activate" + f.stem, prepared.call.data);
    assert.equal(decoded[1], signatures.platformSignature); assert.equal(decoded[2], signatures.artistSignature);
    const bid = prepareCustodyBid(kind, house, m.auctionId, artist, 1234567890123456789n);
    assert.equal(bid.data, iface.encodeFunctionData("bid" + f.stem, [m.auctionId, artist]));
    assert.deepEqual(toSafeCall(bid), { to: house, data: bid.data, value: "1234567890123456789", operation: 0 });
    assert.equal(prepareCustodySettlement(kind, house, m.auctionId).data, iface.encodeFunctionData("settle" + f.stem, [m.auctionId]));
    assert.equal(toSafeCall(prepared.call).value, "0");
    m.nonce = ZeroHash; assert.notEqual(prepared.payload.message.nonce, ZeroHash);
    assert(Object.isFrozen(prepared.call)); assert(Object.isFrozen(prepared.payload.message));
  }
});

test("strict JSON retains uint256/uint64/uint8 precision and rejects malformed signatures and calls", () => {
  for (const kind of Object.keys(fixture.families)) {
    const m = message(kind), request = { kind, chainId: "31337", verifyingContract: house,
      message: Object.fromEntries(Object.entries(m).map(([k,v]) => [k, typeof v === "bigint" ? v.toString() : v])) };
    assert.equal(currentTypedDataFromJSON(request).digest, currentTypedData(kind, 31337n, house, m).digest);
    for (const [field, width] of [["tokenId", 256], ["deadline", 64], ["primaryPolicyMode", 8], ...(kind === "custodyRightsActivation" ? [["rightsMode", 8]] : [])]) {
      for (const value of ["01", "-1", 1, (1n << BigInt(width)).toString()]) assert.throws(() => currentTypedDataFromJSON({ ...request, message: { ...request.message, [field]: value } }));
    }
    for (const value of ["0x1", "bad", 123, undefined]) assert.throws(() => prepareCustodyActivation(kind, 31337n, house, m, { ...signatures, artistSignature: value }));
    assert.throws(() => prepareCustodyBid(kind, house, m.auctionId, artist, -1n));
    assert.throws(() => prepareCustodyBid(kind, house, m.auctionId, artist, 1n << 256n));
  }
  for (const kind of ["constructor", "__proto__", "legacy"]) assert.throws(() => prepareCustodySettlement(kind, house, id("auction")));
});

test("readback checks actual chain and getter result with the requested historical block", async () => {
  for (const [kind, f] of Object.entries(fixture.families)) {
    const p = prepareCustodyActivation(kind, 31337n, house, message(kind), signatures), iface = new Interface(f.abi);
    let calls = 0;
    const provider = { getNetwork: async () => ({ chainId: 31337n }), call: async tx => {
      calls++; assert.equal(tx.to, house); assert.equal(tx.data, p.digestCall.data); assert.equal(tx.blockTag, 123);
      return iface.encodeFunctionResult(f.getter, [p.payload.digest]);
    } };
    await assertCustodyActivationDigest(provider, p, { blockTag: 123 }); assert.equal(calls, 1);
    await assert.rejects(assertCustodyActivationDigest({ ...provider, getNetwork: async () => ({ chainId: 1n }) }, p), /chain differs/); assert.equal(calls, 1);
    await assert.rejects(assertCustodyActivationDigest({ ...provider, call: async () => iface.encodeFunctionResult(f.getter, [ZeroHash]) }, p), /getter differs/);
    await assert.rejects(assertCustodyActivationDigest({ ...provider, call: async () => "0x" }, p));
  }
});
