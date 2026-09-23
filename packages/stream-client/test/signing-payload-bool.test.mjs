import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, concat, id, keccak256 } from "ethers";
import { buildSigningPayload } from "../dist/signing-payload.js";

const target = "0x0000000000000000000000000000000000006529";
const fields = [{ name: "hasPriceOverride", type: "bool" }, { name: "priceOverride", type: "uint256" }];
const coder = AbiCoder.defaultAbiCoder();

test("strict boolean signing preserves both values with the independent EIP712 preimage", () => {
  const domain = keccak256(coder.encode(
    ["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
      id("BooleanEncodingOracle"), id("1"), 31337n, target],
  ));
  const digests = [];
  for (const flag of [false, true]) {
    const message = { hasPriceOverride: flag, priceOverride: (1n << 255n) + 1n };
    const payload = buildSigningPayload(31337n, target, "BooleanEncodingOracle", "Price", fields, message);
    const structHash = keccak256(coder.encode(["bytes32", "bool", "uint256"],
      [id("Price(bool hasPriceOverride,uint256 priceOverride)"), flag, message.priceOverride]));
    assert.equal(payload.digest, keccak256(concat(["0x1901", domain, structHash])));
    message.hasPriceOverride = !flag;
    assert.equal(payload.message.hasPriceOverride, flag);
    assert.ok(Object.isFrozen(payload.message));
    digests.push(payload.digest);
  }
  assert.notEqual(digests[0], digests[1]);
});

test("boolean signing rejects truthy or numeric substitutes before encoding", () => {
  for (const flag of [0, 1, 0n, 1n, "false", "true", "", null, undefined, {}, []]) {
    assert.throws(() => buildSigningPayload(31337n, target, "BooleanEncodingOracle", "Price", fields,
      { hasPriceOverride: flag, priceOverride: 0n }), /hasPriceOverride must be boolean/);
  }
});
