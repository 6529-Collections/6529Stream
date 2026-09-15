import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, TypedDataEncoder, concat, id, keccak256, ZeroHash } from "ethers";
import { currentTypedData, currentTypedDataFromJSON, nativeFixedPriceSaleTypedData, nativePriceProgramTypedData, prepareNativeImmediateSale, prepareImmediateSaleRefund, readImmediateSaleRevealQuote, assertNativeImmediateSaleDigest, toSafeCall } from "../dist/index.js";
const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-immediate-abi.json", import.meta.url), "utf8"));
const iface = new Interface(fixture.abi), coder = AbiCoder.defaultAbiCoder();
const adapter = "0x0000000000000000000000000000000000006529", payer = "0x0000000000000000000000000000000000000042", other = "0x0000000000000000000000000000000000000007";
const tokenData = "0x010203", wrappers = { nativeFixedPriceSale: nativeFixedPriceSaleTypedData, nativePriceProgram: nativePriceProgramTypedData };
function message(kind) {
  return { saleId: id("sale"), saleConfigHash: id("config"), payer, executor: payer, recipient: other, artist: other,
    tokenDataHash: keccak256(tokenData), mintCommitment: id("mint"), executionNonce: (1n << 255n) + 1n,
    nonce: id("nonce"), deadline: (1n << 63n) + 1n, expectedPrimaryPolicyHash: id("policy"),
    ...(kind === "nativePriceProgram" ? { unitPrice: 600n } : {}) };
}
function input() { return { tokenData, platformSignature: "0x123456", artistSignature: "0xabc123", saleAmount: 777n, revealFeeAllowance: 20n }; }

test("both immediate-sale domains match Solidity preimages and compiled tuple coordinates", () => {
  for (const [kind, f] of Object.entries(fixture.families)) {
    const m = message(kind), p = wrappers[kind](31337n, adapter, m);
    const fields = f.typePreimage.slice(f.typePreimage.indexOf("(") + 1, -1).split(",").map(x => x.split(" "));
    const structure = keccak256(coder.encode(["bytes32", ...fields.map(x => x[0])], [id(f.typePreimage), ...fields.map(x => m[x[1]])]));
    const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"], [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id(f.domain), id("1"), 31337n, adapter]));
    assert.equal(p.digest, keccak256(concat(["0x1901", domain, structure])));
    const otherDomain = fixture.families[kind === "nativeFixedPriceSale" ? "nativePriceProgram" : "nativeFixedPriceSale"].domain;
    assert.notEqual(TypedDataEncoder.hash({ ...p.domain, name: otherDomain }, p.types, m), p.digest);
    assert.equal(TypedDataEncoder.from(p.types).encodeType(p.primaryType), f.typePreimage);
    assert.deepEqual(iface.getFunction(f.getter).inputs[0].components.map(x => [x.type, x.name]), fields);
    for (const field of fields) {
      const value = field[0] === "address" ? adapter : field[0] === "bytes32" ? ZeroHash : m[field[1]] + 1n;
      assert.notEqual(currentTypedData(kind, 31337n, adapter, { ...m, [field[1]]: value }).digest, p.digest);
    }
    assert.notEqual(currentTypedData(kind, 1n, adapter, m).digest, p.digest);
    assert.notEqual(currentTypedData(kind, 31337n, other, m).digest, p.digest);
  }
});

test("purchase calls preserve compiled structs, Safe signatures and separate reveal allowance", () => {
  for (const [kind, f] of Object.entries(fixture.families)) {
    const m = message(kind), data = input(), p = prepareNativeImmediateSale(kind, 31337n, adapter, m, data);
    const execution = { authorization: m, ...(kind === "nativePriceProgram" ? { chosenUnitPrice: 777n } : {}), tokenData, platformSignature: data.platformSignature, artistSignature: data.artistSignature };
    assert.equal(p.call.data, iface.encodeFunctionData(f.method, [execution]));
    assert.equal(p.digestCall.data, iface.encodeFunctionData(f.getter, [m]));
    assert.deepEqual(toSafeCall(p.call), { to: adapter, data: p.call.data, value: "797", operation: 0 });
    const q = prepareNativeImmediateSale(kind, 31337n, adapter, m, { ...data, revealFeeAllowance: 35n });
    assert.equal(p.payload.digest, q.payload.digest); assert.equal(q.call.value, 812n); assert.equal(q.call.data, p.call.data);
    if (kind === "nativePriceProgram") {
      const decoded = iface.decodeFunctionData(f.method, p.call.data)[0];
      assert.equal(decoded.authorization.unitPrice, 600n); assert.equal(decoded.chosenUnitPrice, 777n);
      const largerTip = prepareNativeImmediateSale(kind, 31337n, adapter, m, { ...data, saleAmount: 888n });
      assert.equal(largerTip.payload.digest, p.payload.digest); assert.equal(largerTip.call.value, 908n);
      assert.equal(iface.decodeFunctionData(f.method, largerTip.call.data)[0].chosenUnitPrice, 888n);
    }
    m.nonce = ZeroHash; data.saleAmount = 1n;
    assert.notEqual(p.payload.message.nonce, ZeroHash); assert.equal(p.call.value, 797n); assert(Object.isFrozen(p.call));
  }
});

test("strict JSON and input validation retain full widths and reject malformed data or overflowing value", () => {
  for (const kind of Object.keys(fixture.families)) {
    const m = message(kind), request = { kind, chainId: "31337", verifyingContract: adapter, message: Object.fromEntries(Object.entries(m).map(([k,v]) => [k, typeof v === "bigint" ? v.toString() : v])) };
    assert.equal(currentTypedDataFromJSON(request).digest, currentTypedData(kind, 31337n, adapter, m).digest);
    for (const [field, bits] of [["executionNonce", 256], ["deadline", 64], ...(kind === "nativePriceProgram" ? [["unitPrice", 256]] : [])]) {
      for (const bad of ["01", 1, "-1", (1n << BigInt(bits)).toString()]) assert.throws(() => currentTypedDataFromJSON({ ...request, message: { ...request.message, [field]: bad } }));
    }
    for (const bad of [1, -1n, 1n << 256n]) {
      assert.throws(() => prepareNativeImmediateSale(kind, 31337n, adapter, m, { ...input(), saleAmount: bad }));
      assert.throws(() => prepareNativeImmediateSale(kind, 31337n, adapter, m, { ...input(), revealFeeAllowance: bad }));
    }
    assert.throws(() => prepareNativeImmediateSale(kind, 31337n, adapter, m, { ...input(), saleAmount: (1n << 256n) - 1n, revealFeeAllowance: 1n }));
    for (const field of ["tokenData", "platformSignature", "artistSignature"]) assert.throws(() => prepareNativeImmediateSale(kind, 31337n, adapter, m, { ...input(), [field]: "0x1" }));
    assert.throws(() => prepareNativeImmediateSale(kind, 31337n, adapter, m, { ...input(), tokenData: "0x1234" }));
  }
  assert.throws(() => prepareNativeImmediateSale("constructor", 31337n, adapter, message("nativeFixedPriceSale"), input()));
});

test("refund calls use compiled calldata and zero-value Safe CALL semantics", () => {
  const c = prepareImmediateSaleRefund(adapter, id("sale"), payer);
  assert.equal(c.data, iface.encodeFunctionData("claimRefund", [id("sale"), payer]));
  assert.deepEqual(toSafeCall(c), { to: adapter, data: c.data, value: "0", operation: 0 });
  for (const bad of [adapter, "0x" + "0".repeat(40), "bad"]) assert.throws(() => prepareImmediateSaleRefund(adapter, id("sale"), bad));
});

test("live reveal quote decodes the compiled policy at the requested block", async () => {
  const q = [other, id("coordinator code"), [true, 0n, id("owner role"), 123n, 12n]];
  let calls = 0;
  const provider = { call: async tx => { calls++; assert.equal(tx.to, adapter); assert.equal(tx.data, iface.encodeFunctionData("saleRevealQuote", [id("sale")])); assert.equal(tx.blockTag, 123); return iface.encodeFunctionResult("saleRevealQuote", [q]); } };
  const actual = await readImmediateSaleRevealQuote(provider, adapter, id("sale"), { blockTag: 123 });
  assert.equal(actual.revealFeePerTokenWei, 12n); assert.equal(actual.requestSLOBlocks, 123n); assert.equal(actual.requestMode, 0n); assert.equal(calls, 1); assert(Object.isFrozen(actual));
  q[2][0] = false; await assert.rejects(readImmediateSaleRevealQuote(provider, adapter, id("sale"), { blockTag: 123 }));
  q[2][0] = true; q[2][1] = 2n; await assert.rejects(readImmediateSaleRevealQuote(provider, adapter, id("sale"), { blockTag: 123 }));
});

test("digest readback rejects wrong chain and wrong host digest", async () => {
  for (const kind of Object.keys(fixture.families)) {
    const p = prepareNativeImmediateSale(kind, 31337n, adapter, message(kind), input());
    let calls = 0;
    const provider = { getNetwork: async () => ({ chainId: 31337n }), call: async tx => { calls++; assert.equal(tx.data, p.digestCall.data); assert.equal(tx.blockTag, "latest"); return iface.encodeFunctionResult(p.digestMethod, [p.payload.digest]); } };
    await assertNativeImmediateSaleDigest(provider, p, { blockTag: "latest" }); assert.equal(calls, 1);
    await assert.rejects(assertNativeImmediateSaleDigest({ ...provider, getNetwork: async () => ({ chainId: 1n }) }, p), /chain/);
    assert.equal(calls, 1);
    await assert.rejects(assertNativeImmediateSaleDigest({ ...provider, call: async () => iface.encodeFunctionResult(p.digestMethod, [ZeroHash]) }, p), /differs/);
  }
});
