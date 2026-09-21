import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { posix } from "node:path";
import { AbiCoder, Fragment, FunctionFragment, Interface, ParamType, concat, id, keccak256 } from "ethers";
import ts from "typescript";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { governanceExecutorV2Fixture as f, governanceExecutorV2Interfaces as interfaces } from "./current-governance-executor-v2-source-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const sourceCount = values => Object.keys(values).length;
const itemCount = values => Object.values(values).reduce((count, entries) => count + entries.length, 0);
const selectorCount = values => Object.values(values).reduce((count, entries) => count + Object.keys(entries).length, 0);
const nine = {
  publishGovernanceCallData: "0x5447021f", scheduleGovernanceAction: "0xd1699cf2", scheduleGovernanceBatch: "0x9c954144",
  executeGovernanceAction: "0xed8259ec", executeGovernanceBatch: "0x2eccc33e", cancelGovernanceAction: "0xe2a10db5",
  vetoTerminalFreeze: "0x2d1585ec", materializeExpiredAction: "0x2098cfe6", pruneElapsedTerminalFreezeActions: "0xace3628e",
};

test("governance witness preserves ABI164 identity and full source/ordinary/nominal inventories", () => {
  const bytes = readFileSync(new URL("./fixtures/current-governance-executor-v2-abi.json", import.meta.url));
  assert.equal(bytes.length, 1905453); assert.equal(sha(bytes), "ab707e20e87cb91502df652f9f21f90906aa330595c2d243975f616101848d91");
  assert.equal(f.sourceCommit, "eda052c75dc9fd5c4e2e658bdf453ab01f5b7c0e");
  assert.equal(f.sourceTree, "1a71ae4ee9806c601237129d81e494058c547ee0");
  assert.equal(f.sourceCount, 4119); assert.equal(f.literalBytes, 48713655);
  assert.equal(f.inputSha256, "5fd1a5370ea1df068958317c48f67120e5cf9199ffe8e99ef5b99657b824374c");
  assert.equal(f.outputSha256, "9ccdd82f1dee6b2d3a1b5ff3562417f64db27d72903b8fe2c8c06387b293ca90");
  assert.equal(f.committedSourceBridge.sha256, "d4ef14a96f8018de4ea99176e19c80009707439d5e9e7d8d72a163d342dee9af");
  assert.deepEqual(f.committedSourceBridge.mismatches, []);
  assert.equal(sourceCount(f.sourceTexts), 42); assert.equal(sourceCount(f.abis), 23); assert.equal(itemCount(f.abis), 640); assert.equal(selectorCount(f.methodIdentifiers), 267);
  assert.equal(sourceCount(f.libraryAbis), 19); assert.equal(itemCount(f.libraryAbis), 249); assert.equal(selectorCount(f.libraryMethodIdentifiers), 139);
  assert.match(f.qualification, /Nominal library selectors are not wallet call surfaces/);
});

test("both original hosts retain their complete import closure and five source-pinned governance ADRs", () => {
  const visited = new Set();
  function visit(path) {
    if (visited.has(path)) return; visited.add(path);
    assert.ok(Object.hasOwn(f.sourceTexts, path), path);
    for (const imported of solidityImports(f.sourceTexts[path])) visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
  }
  visit(f.selections.StreamGovernanceExecutor.source); visit(f.selections.StreamRoleRegistry.source);
  assert.deepEqual([...visited].sort(), Object.keys(f.sourceTexts).sort());
  assert.equal(Object.values(f.sourceTexts).reduce((sum, text) => sum + Buffer.byteLength(text), 0), 495794);
  for (const [path, text] of Object.entries(f.sourceTexts)) {
    assert.equal(sha(text), f.sourceHashes[path]); assert.ok(f.committedSourceBridge.committedBlobSHA256[path]);
  }
  assert.equal(Object.keys(f.documents).length, 5);
  for (const document of Object.values(f.documents)) {
    assert.equal(sha(document.text), document.sha256); assert.equal(Buffer.byteLength(document.text), document.byteLength);
  }
  assert.match(f.documents["docs/adr/0032-governance-foundation-before-product-activation.md"].text, /foundation seal\s+alone cannot advance/);
});

test("all267 ordinary selectors bind genuine compiler fragments and nine lifecycle writes keep payable semantics", () => {
  for (const [name, abi] of Object.entries(f.abis)) {
    const selected = f.selections[name]; assert.equal(selected.full, true); assert.equal(selected.nominal, undefined);
    for (const row of abi.filter(row => row.type === "function")) {
      const signature = FunctionFragment.from(row).format("sighash");
      assert.equal(id(signature).slice(2, 10), f.methodIdentifiers[name][signature], `${name}:${signature}`);
    }
    assert.equal(abi.filter(row => row.type === "function").length, Object.keys(f.methodIdentifiers[name]).length, name);
  }
  assert.equal(f.abis.StreamGovernanceExecutor.length, 230); assert.equal(Object.keys(f.methodIdentifiers.StreamGovernanceExecutor).length, 74);
  assert.equal(f.abis.StreamRoleRegistry.length, 58); assert.equal(Object.keys(f.methodIdentifiers.StreamRoleRegistry).length, 28);
  for (const [name, selector] of Object.entries(nine)) {
    const fragment = interfaces.StreamGovernanceExecutor.getFunction(name);
    assert.equal(fragment.selector, selector);
    assert.equal(fragment.stateMutability, name.startsWith("executeGovernance") ? "payable" : "nonpayable");
  }
  for (const [name, selected] of Object.entries(f.librarySelections)) {
    assert.equal(selected.nominal, true); assert.equal(selected.full, true); assert.equal(interfaces[name], undefined);
    assert.match(f.sourceTexts[selected.source], new RegExp(`\\blibrary\\s+${name}\\b`));
  }
});

test("original V2 domains and publication preimage remain distinct from per-call transition commitments", () => {
  const source = f.sourceTexts[f.selections.StreamGovernanceExecutor.source];
  for (const domain of ["6529STREAM_GOVERNANCE_CALLS_V2", "6529STREAM_GOVERNANCE_ACTION_V2", "6529STREAM_GOVERNANCE_BATCH_SCOPE_V2", "6529STREAM_GOVERNANCE_BATCH_OLD_STATE_V2", "6529STREAM_GOVERNANCE_BATCH_NEW_STATE_V2"]) assert.ok(source.includes(id(domain)), domain);
  const bootstrap = f.sourceTexts[f.librarySelections.StreamGovernanceBootstrap.source];
  assert.match(bootstrap, /callDataKey = keccak256\(abi\.encodePacked\(hashes\)\)/);
  assert.match(source, /mapping\(bytes32 => uint256\) private _actionNonces/);
  assert.match(source, /facts\.status = row\.status/);
  assert.match(source, /bytes memory encoded = StreamGovernanceBootstrap\.encodeGovernanceAction/);
});

function sourceArray(path, name) {
  const source = ts.createSourceFile(path, readFileSync(new URL(path, import.meta.url), "utf8"), ts.ScriptTarget.Latest, true);
  let result;
  function visit(node) {
    if (ts.isVariableDeclaration(node) && node.name.getText(source) === name) {
      let initializer = node.initializer;
      if (initializer && ts.isCallExpression(initializer) && initializer.expression.getText(source) === "Object.freeze") initializer = initializer.arguments[0];
      while (initializer && (ts.isAsExpression(initializer) || ts.isSatisfiesExpression(initializer))) initializer = initializer.expression;
      assert.ok(initializer && ts.isArrayLiteralExpression(initializer), name);
      result = initializer.elements.map(element => { assert.ok(ts.isStringLiteral(element)); return element.text; });
    }
    ts.forEachChild(node, visit);
  }
  visit(source); assert.ok(result, name); return result;
}
const shape = fields => fields.map(field => ParamType.from(field, true).format("sighash"));

test("authored Executor ABI is compiler-backed and its mutable surface is exactly the nine methods", () => {
  const fragments = sourceArray("../src/current-governance-executor-v2.ts", "GOVERNANCE_EXECUTOR_V2_ABI").map(value => Fragment.from(value));
  const writes = [];
  for (const fragment of fragments) {
    const signature = fragment.format("sighash");
    const original = f.abis.StreamGovernanceExecutor.find(row => row.type === fragment.type && Fragment.from(row).format("sighash") === signature);
    assert.ok(original, signature);
    assert.deepEqual(shape(fragment.inputs), shape(original.inputs), signature);
    if (fragment.type === "function") {
      assert.equal(fragment.stateMutability, original.stateMutability, signature);
      assert.deepEqual(shape(fragment.outputs), shape(original.outputs), signature);
      if (!["view", "pure"].includes(fragment.stateMutability)) writes.push(fragment.name);
    } else if (fragment.type === "event") {
      assert.equal(fragment.anonymous, original.anonymous);
      assert.deepEqual(fragment.inputs.map(field => field.indexed === true), original.inputs.map(field => field.indexed === true), signature);
    }
  }
  assert.deepEqual(writes.sort(), Object.keys(nine).sort());
});

test("authored operational Registry ABI preserves compiler signatures and exactly two writes", () => {
  const fragments = sourceArray("../src/current-role-registry-operational.ts", "ROLE_REGISTRY_OPERATIONAL_ABI").map(value => Fragment.from(value));
  const writes = [];
  for (const fragment of fragments) {
    const signature = fragment.format("sighash");
    const original = f.abis.StreamRoleRegistry.find(row => row.type === fragment.type && Fragment.from(row).format("sighash") === signature);
    assert.ok(original, signature);
    assert.deepEqual(shape(fragment.inputs), shape(original.inputs), signature);
    if (fragment.type === "function") {
      assert.equal(fragment.stateMutability, original.stateMutability, signature);
      assert.deepEqual(shape(fragment.outputs), shape(original.outputs), signature);
      if (!["view", "pure"].includes(fragment.stateMutability)) writes.push(fragment.name);
    } else if (fragment.type === "event") {
      assert.deepEqual(fragment.inputs.map(field => field.indexed === true), original.inputs.map(field => field.indexed === true), signature);
    }
  }
  assert.deepEqual(writes.sort(), ["grantRole", "revokeRole"]);
});

test("independent compiler tuples bind multi-call value, aggregate domains, action nonce and packed publication key", async () => {
  const client = await import("../dist/current-governance-executor-v2.js");
  const coder = AbiCoder.defaultAbiCoder();
  const executor = "0x0000000000000000000000000000000000000001", caller = "0x0000000000000000000000000000000000000002";
  const c = { chainId: 31337n, executor }, callDatas = ["0x11223344aabb", "0x55667788ccdd"];
  const calls = callDatas.map((bytes, i) => ({ target: `0x${(i + 3).toString(16).padStart(40, "0")}`, value: BigInt(i + 7), selector: bytes.slice(0, 10), callDataHash: keccak256(bytes), scopeHash: id(`scope${i}`), oldValueHash: id(`old${i}`), newValueHash: id(`new${i}`) }));
  const tupleArray = interfaces.StreamGovernanceExecutor.getFunction("executeGovernanceBatch").inputs[1];
  const callsHash = keccak256(coder.encode(["bytes32", tupleArray], [id("6529STREAM_GOVERNANCE_CALLS_V2"), calls]));
  assert.equal(client.governanceExecutorV2CallsHash(calls), callsHash);
  const hashes = Object.fromEntries([["scopeHash", "SCOPE"], ["oldValueHash", "OLD_STATE"], ["newValueHash", "NEW_STATE"]].map(([field, suffix]) => [field, keccak256(coder.encode(["bytes32", "bytes32", "bytes32[]"], [id(`6529STREAM_GOVERNANCE_BATCH_${suffix}_V2`), callsHash, calls.map(call => call[field])]))]));
  assert.deepEqual(client.governanceExecutorV2BatchHashes(calls), { callsHash, ...hashes });
  const identity = { actionClass: 3n, callsHash, ...hashes, nonce: 19n, notBefore: 999999n, expiresAfter: 1604799n, reasonHash: id("reason"), manifestHash: id("manifest") };
  // The identity is static, so its ABI tuple encoding equals the source's flat abi.encode words.
  const actionId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64", "uint64", "bytes32", "bytes32"], [id("6529STREAM_GOVERNANCE_ACTION_V2"), c.chainId, executor, identity.actionClass, callsHash, hashes.scopeHash, hashes.oldValueHash, hashes.newValueHash, identity.nonce, identity.notBefore, identity.expiresAfter, identity.reasonHash, identity.manifestHash]));
  assert.equal(client.governanceExecutorV2ActionId(c, identity), actionId);
  assert.notEqual(client.governanceExecutorV2ActionId(c, { ...identity, nonce: 20n }), actionId);
  const prepared = client.prepareGovernanceExecutorV2Call(c, caller, { method: "executeGovernanceBatch", actionId, calls, callDatas });
  assert.equal(prepared.call.value, 15n);
  assert.equal(prepared.call.data, interfaces.StreamGovernanceExecutor.encodeFunctionData("executeGovernanceBatch", [actionId, calls, callDatas]));
  assert.equal(client.governanceExecutorV2PublicationKey(callDatas), keccak256(concat(callDatas.map(keccak256))));
  assert.notEqual(client.governanceExecutorV2PublicationKey(callDatas), keccak256(coder.encode(["bytes32[]"], [callDatas.map(keccak256)])));
});

test("independent original Registry domains and compiler calls authenticate nonfinal holder swap-pop", async () => {
  const client = await import("../dist/current-role-registry-operational.js");
  const coder = AbiCoder.defaultAbiCoder(), address = n => `0x${n.toString(16).padStart(40, "0")}`;
  const c = { chainId: 31337n, registry: address(11), executor: address(12) }, caller = address(13);
  const role = id("ROLE_FIXITY_OPERATOR"), request = { kind: "revokeRole", role, holder: address(22) };
  const plan = client.prepareRoleRegistryOperationalCall(c, caller, request);
  assert.equal(plan.call.data, interfaces.StreamRoleRegistry.encodeFunctionData("revokeRole", [role, request.holder]));
  const before = { holders: [address(21), address(22), address(23)], roleState: { chainHash: id("prior-role"), revision: 4n }, globalState: { chainHash: id("prior-global"), revision: 8n }, managerEnabled: true, managerState: { chainHash: id("manager"), revision: 1n } };
  const transition = client.roleRegistryOperationalTransition(plan, before);
  assert.deepEqual(transition.after.holders, [address(21), address(23)]);
  assert.equal(transition.removedIndex, 1); assert.equal(transition.movedHolder, address(23));
  for (const [field, domain] of [["roleState", "6529STREAM_ROLE_MUTATION_V1"], ["globalState", "6529STREAM_GLOBAL_ROLE_MUTATION_V1"]]) {
    const expected = keccak256(coder.encode(["bytes32", "bytes32", "uint256", "address", "bytes32", "address", "bool", "uint64"], [id(domain), before[field].chainHash, c.chainId, c.registry, role, request.holder, false, before[field].revision + 1n]));
    assert.equal(transition.after[field].chainHash, expected);
  }
  assert.equal(transition.factsVerified, false);
  assert.throws(() => client.prepareRoleRegistryOperationalCall(c, caller, { ...request, role: id("ROLE_TERMINAL_FREEZE_VETO") }), /seven operational/);
});
