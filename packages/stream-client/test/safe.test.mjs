import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, id, ZeroAddress } from "ethers";
import { requireSafeExecution, toSafeCall } from "../dist/index.js";

const safe = "0x0000000000000000000000000000000000000001";
const target = "0x0000000000000000000000000000000000000002";
const hash = "0x" + "ab".repeat(32);
const otherHash = "0x" + "cd".repeat(32);
function log(name = "ExecutionSuccess", txHash = hash, address = safe) {
  return { address, topics: [id(`${name}(bytes32,uint256)`)], data: AbiCoder.defaultAbiCoder().encode(["bytes32", "uint256"], [txHash, 71n]) };
}
function receipt(...logs) { return { status: 1, logs }; }
function indexedLog(name = "ExecutionSuccess", txHash = hash, address = safe) {
  return { address, topics: [id(`${name}(bytes32,uint256)`), txHash], data: AbiCoder.defaultAbiCoder().encode(["uint256"], [71n]) };
}

test("Safe CALL conversion preserves calldata and exact large native value", () => {
  const value = 9007199254740993999n;
  const call = toSafeCall({ to: target, data: "0x11223344", value });
  assert.deepEqual(call, { to: target, data: "0x11223344", value: "9007199254740993999", operation: 0 });
  assert.ok(Object.isFrozen(call));
  assert.equal(toSafeCall({ to: target, data: "0x", value: 0n }).data, "0x");
});
test("Safe CALL conversion rejects malformed targets, bytes and uint256 values", () => {
  const call = { to: target, data: "0x12", value: 0n };
  for (const value of [-1n, 1n << 256n, 1]) assert.throws(() => toSafeCall({ ...call, value }));
  for (const data of ["0x1", "0xGG", "12", { toString: () => "0x12" }]) assert.throws(() => toSafeCall({ ...call, data }));
  assert.throws(() => toSafeCall({ ...call, to: ZeroAddress }));
});
test("Safe receipt binds exact emitter and independently supplied Safe transaction hash", () => {
  const result = requireSafeExecution(receipt(log("ExecutionFailure", otherHash), log("ExecutionSuccess", hash, target), log()), safe, hash);
  assert.deepEqual(result, { safe, safeTxHash: hash, payment: 71n });
  assert.ok(Object.isFrozen(result));
});
test("successful outer receipt with failed Safe target never reports success", () => {
  assert.throws(() => requireSafeExecution(receipt(log("ExecutionFailure")), safe, hash), /target execution failed/);
  for (const status of [0, null]) assert.throws(() => requireSafeExecution({ ...receipt(log()), status }, safe, hash), /outer receipt/);
});
test("missing, wrong-emitter, wrong-hash and duplicate Safe events fail closed", () => {
  for (const item of [receipt(), receipt(log("ExecutionSuccess", hash, target)), receipt(log("ExecutionSuccess", otherHash)), receipt(log(), log()), receipt(log(), log("ExecutionFailure"))]) {
    assert.throws(() => requireSafeExecution(item, safe, hash), /matching Safe execution/);
  }
});
test("module events and ordinary target logs cannot substitute for execTransaction", () => {
  const module = { address: safe, topics: [id("ExecutionFromModuleSuccess(address)")], data: AbiCoder.defaultAbiCoder().encode(["address"], [target]) };
  assert.throws(() => requireSafeExecution(receipt(module), safe, hash), /matching Safe execution/);
});
test("malformed execution payloads and caller expectations are rejected", () => {
  for (const changed of [{ data: "0x" }, { data: log().data + "00" }, { topics: [...log().topics, hash] }]) {
    assert.throws(() => requireSafeExecution(receipt({ ...log(), ...changed }), safe, hash), /Malformed/);
  }
  assert.throws(() => requireSafeExecution(receipt(log()), safe, "0xab"), /bytes32/);
  assert.throws(() => requireSafeExecution(receipt(log()), safe, { toString: () => hash }), /bytes32/);
  assert.throws(() => requireSafeExecution(receipt(log()), ZeroAddress, hash), /nonzero/);
});
test("Safe 1.4.1 and 1.5.0 indexed transaction hashes bind actual success or failure", () => {
  assert.equal(requireSafeExecution(receipt(indexedLog()), safe, hash).payment, 71n);
  assert.throws(() => requireSafeExecution(receipt(indexedLog("ExecutionFailure")), safe, hash), /target execution failed/);
  assert.throws(() => requireSafeExecution(receipt(indexedLog("ExecutionSuccess", otherHash)), safe, hash), /matching Safe execution/);
  assert.throws(() => requireSafeExecution(receipt(indexedLog("ExecutionSuccess", hash, target)), safe, hash), /matching Safe execution/);
  assert.throws(() => requireSafeExecution(receipt(indexedLog(), indexedLog()), safe, hash), /matching Safe execution/);
});
test("indexed execution logs require one exact bytes32 hash and payment word", () => {
  for (const changed of [{ data: "0x" }, { data: indexedLog().data + "00" }, { topics: [indexedLog().topics[0], "0xab"] }, { topics: [...indexedLog().topics, hash] }]) {
    assert.throws(() => requireSafeExecution(receipt({ ...indexedLog(), ...changed }), safe, hash), /Malformed/);
  }
});
