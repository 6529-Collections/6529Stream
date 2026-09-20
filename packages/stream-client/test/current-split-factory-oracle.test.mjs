import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroHash, concat, getAddress, getCreate2Address, id, keccak256 } from "ethers";
import { normalizeSplitFactorySnapshot, prepareSplitProfile, prepareSplitFactoryCall, splitWalletCloneRuntime,
  splitWalletCloneInitCode, splitWalletDomainSeparator, splitWalletReleaseTypedData, splitWalletReleaseRevocationTypedData } from "../dist/current-split-factory.js";
import { createSplitFactorySafeReview } from "../examples/current-split-factory.mjs";
import { verifySafeCallPlan } from "../dist/safe-plan.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-split-factory-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, rows]) => [key, new Interface(rows)]));
const coder = AbiCoder.defaultAbiCoder(), A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = (types, values) => keccak256(coder.encode(types, values));
const chainId = (1n << 237n) + 31337n;
function snapshot(factory = A(10), implementation = A(11)) {
  // Literal bytecode from StreamSplitWalletDeployment, independent of the client constructor.
  const runtime = `0x3615603257363d3d373d3d3d363d73${implementation.slice(2).toLowerCase()}5af43d82803e903d91603057fd5bf35b00`;
  const initCode = `0x3d603480600a3d3981f3${runtime.slice(2)}`;
  return normalizeSplitFactorySnapshot({ context: { chainId, factory, profileDomain: id("6529STREAM_SPLIT_PROFILE_V1"),
    schemaVersion: 1n, walletVersion: 4n, initCodeHash: keccak256(initCode), runtimeCodeHash: keccak256(runtime), assetPolicyRegistry: A(12) },
    factoryCodeHash: id("reviewed factory code"), assetPolicyCodeHash: id("reviewed asset policy code"),
    implementation: { address: implementation, codeHash: id(`implementation runtime:${factory}`) } });
}
const entries = [
  { account: A(42), sharePpm: 250000n, labelId: id("artist") },
  { account: A(41), sharePpm: 500000n, labelId: ZeroHash },
  { account: A(42), sharePpm: 250000n, labelId: id("curator") },
];

test("clone compiler fixture preserves its exact production binding and single test-only exception", () => {
  assert.equal(fixture.sourceCommit, "7382327933c90638e8552fc8dd0340e9de53c449");
  assert.equal(fixture.sourceCount, 31); assert.equal(Object.keys(fixture.sources).length, 31);
  assert.equal(fixture.inputSha256, "80edca9e4bde72d2ea6aa5421ce28424997608b3459554db34f22786bd464c8b");
  assert.equal(fixture.outputSha256, "3027012564f0782f8e9a0160d70ced192544a87ada9481b282acbd772245376a");
  assert.equal(Object.values(fixture.abis).reduce((sum, rows) => sum + rows.length, 0), 215);
  assert.equal(fixture.sourceExceptions.length, 1);
  assert.equal(fixture.sourceExceptions[0].path, "test/unit/revenue/StreamSplitWalletClones.t.sol");
  assert.equal(fixture.sourceExceptions[0].capturedSha256, fixture.sources[fixture.sourceExceptions[0].path]);
  assert.match(fixture.qualification, /not the final native test input/);
  for (const row of fixture.abis.factoryInterface.filter(row => row.type === "function")) {
    const concrete = abi.factory.getFunction(row.name), original = abi.factoryInterface.getFunction(row.name);
    assert.equal(concrete.format("sighash"), original.format("sighash"));
    assert.deepEqual(concrete.outputs.map(p => p.format("sighash")), original.outputs.map(p => p.format("sighash")));
    // Solidity emits constant getter implementations as view, while this interface declares pure.
    assert.equal(concrete.stateMutability, original.stateMutability === "pure" ? "view" : original.stateMutability);
  }
});

test("original factory selectors and events retain view hash getters and an additive implementation companion", () => {
  assert.equal(abi.factory.getFunction("splitWalletInitCodeHash").selector, "0x57de32be");
  assert.equal(abi.factory.getFunction("splitWalletRuntimeCodeHash").selector, "0x914575a9");
  for (const name of ["splitWalletInitCodeHash", "splitWalletRuntimeCodeHash"]) {
    assert.equal(abi.factory.getFunction(name).stateMutability, "view");
    assert.equal(abi.factoryInterface.getFunction(name).stateMutability, "view");
  }
  const implementationId = fixture.abis.implementationInterface.filter(row => row.type === "function")
    .reduce((value, row) => value ^ BigInt(abi.implementationInterface.getFunction(row.name).selector), 0n);
  assert.equal(implementationId, 0x507ff672n);
  const inherited = new Set(["gasParameter", "gasParameterIds", "gasParameterInfo", "governanceAuthority", "raiseGasParameter"]);
  const originalFactoryId = fixture.abis.factoryInterface.filter(row => row.type === "function" && !inherited.has(row.name))
    .reduce((value, row) => value ^ BigInt(abi.factoryInterface.getFunction(row.name).selector), 0n);
  assert.equal(originalFactoryId, 0x620f84aan);
  assert.equal(abi.factoryInterface.getFunction("splitWalletImplementation"), null);
  assert.equal(abi.wallet.getFunction("supportsInterface"), null);
  assert.deepEqual(abi.factory.getEvent("SplitWalletImplementationPinned").inputs.map(row => [row.name, row.type, row.indexed]), [
    ["schemaVersion", "uint16", false], ["implementation", "address", true], ["runtimeCodeHash", "bytes32", true],
    ["walletVersion", "uint16", false], ["cloneInitCodeHash", "bytes32", false], ["cloneRuntimeCodeHash", "bytes32", false],
  ]);
  for (const name of ["SplitWalletDeployed", "SplitWalletDiscovered"]) {
    assert.deepEqual(abi.factory.getEvent(name).inputs.map(row => [row.type, row.indexed]), [
      ["bytes32", true], ["address", true], ["uint16", true], ["uint16", false], ["bytes32", false], ["bytes32", false],
    ]);
  }
});

test("v4 clone bytes, full profile identity and CREATE2 match independent original preimages across factories", () => {
  const s = snapshot(), p = prepareSplitProfile(s.context, entries, id("metadata"));
  const sorted = [...entries].sort((a, b) => BigInt(a.account) === BigInt(b.account)
    ? (BigInt(a.labelId) < BigInt(b.labelId) ? -1 : 1) : (BigInt(a.account) < BigInt(b.account) ? -1 : 1));
  const tuple = abi.factory.getFunction("profileIdFor").inputs[0];
  const entriesHash = H([tuple], [sorted]);
  const c = s.context;
  const profileId = H(["bytes32", "uint256", "address", "uint16", "uint16", "bytes32", "bytes32", "address", "bytes32", "bytes32"],
    [id("6529STREAM_SPLIT_PROFILE_V1"), chainId, c.factory, 1n, 4n, c.initCodeHash, c.runtimeCodeHash, c.assetPolicyRegistry, entriesHash, id("metadata")]);
  assert.equal(p.entriesHash, entriesHash); assert.equal(p.profileId, profileId);
  assert.equal(p.wallet, getCreate2Address(c.factory, profileId, c.initCodeHash));
  assert.deepEqual(p.accounts, [A(41), A(42)]); assert.deepEqual(p.aggregateSharePpm, [500000n, 500000n]);
  assert.equal(splitWalletCloneRuntime(s.implementation.address).length, 2 + 52 * 2);
  assert.equal(splitWalletCloneInitCode(s.implementation.address).length, 2 + 62 * 2);
  assert.equal(keccak256(splitWalletCloneRuntime(s.implementation.address)), c.runtimeCodeHash);
  assert.equal(keccak256(splitWalletCloneInitCode(s.implementation.address)), c.initCodeHash);
  const other = snapshot(A(20), A(21)), q = prepareSplitProfile(other.context, entries, id("metadata"));
  assert.notEqual(q.context.initCodeHash, c.initCodeHash); assert.notEqual(q.context.runtimeCodeHash, c.runtimeCodeHash);
  assert.notEqual(q.profileId, p.profileId); assert.notEqual(q.wallet, p.wallet);
  const v3 = prepareSplitProfile({ ...c, walletVersion: 3n }, entries, id("metadata"));
  assert.notEqual(v3.profileId, p.profileId); assert.notEqual(v3.wallet, p.wallet);
  for (const patch of [{ chainId: chainId + 1n }, { factory: A(29) }, { initCodeHash: id("other init") },
    { runtimeCodeHash: id("other runtime") }, { assetPolicyRegistry: A(30) }]) {
    assert.notEqual(prepareSplitProfile({ ...c, ...patch }, entries, id("metadata")).profileId, p.profileId);
  }
});

test("all three prepared public calls match compiler tuples without exposing wallet initialization", () => {
  const s = snapshot(), p = prepareSplitProfile(s.context, entries, ZeroHash), caller = A(81);
  for (const [kind, method] of [["register-profile", "registerProfile"], ["create-profile", "createProfile"], ["deploy-wallet", "deployWallet"]]) {
    const call = prepareSplitFactoryCall(s, caller, { kind, profile: p });
    assert.deepEqual(call.call, { to: s.context.factory, value: 0n,
      data: abi.factory.encodeFunctionData(method, kind === "deploy-wallet" ? [p.profileId] : [p.entries, ZeroHash]) });
    assert.equal(call.caller, caller); assert.equal(call.predictionOnly, true);
  }
  assert.throws(() => prepareSplitFactoryCall(s, caller, { kind: "initialize", profile: p }));
});

test("v4 release and revocation preserve domain version1 at the individual wallet and original full-width fields", () => {
  const s = snapshot(), p = prepareSplitProfile(s.context, entries, ZeroHash);
  const domain = H(["bytes32", "bytes32", "bytes32", "uint256", "address"], [
    id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamSplitWallet"), id("1"), chainId, p.wallet,
  ]);
  assert.equal(splitWalletDomainSeparator(p), domain);
  const message = { asset: A(91), account: A(41), recipient: A(92), releasableSnapshot: (1n << 245n) + 123n,
    nonce: id("opaque nonce"), deadline: (1n << 64n) - 1n };
  const payload = splitWalletReleaseTypedData(s, p, message);
  const tuple = abi.wallet.getFunction("releaseAuthorizationDigest").inputs[0];
  assert.deepEqual(tuple.components.map(row => [row.name, row.type]), [
    ["asset", "address"], ["account", "address"], ["recipient", "address"], ["releasableSnapshot", "uint256"], ["nonce", "bytes32"], ["deadline", "uint64"],
  ]);
  const structHash = H(["bytes32", tuple], [id("StreamReleaseAuthorization(address asset,address account,address recipient,uint256 releasableSnapshot,bytes32 nonce,uint64 deadline)"), message]);
  assert.equal(payload.digest, keccak256(concat(["0x1901", domain, structHash])));
  assert.equal(payload.domain.verifyingContract, p.wallet); assert.equal(payload.domain.version, "1");
  assert.notEqual(payload.domain.verifyingContract, s.context.factory); assert.notEqual(payload.domain.verifyingContract, s.implementation.address);
  const revocation = { account: message.account, nonce: message.nonce, deadline: message.deadline };
  const revoke = splitWalletReleaseRevocationTypedData(s, p, revocation);
  const revokeHash = H(["bytes32", "address", "bytes32", "uint64"], [id("StreamReleaseAuthorizationRevocation(address account,bytes32 nonce,uint64 deadline)"), ...Object.values(revocation)]);
  assert.equal(revoke.digest, keccak256(concat(["0x1901", domain, revokeHash])));
  const other = prepareSplitProfile(s.context, entries, id("different profile"));
  assert.notEqual(splitWalletReleaseTypedData(s, other, message).digest, payload.digest);
});

test("Safe example preserves every original factory CALL and the actual wallet prediction", () => {
  const s = snapshot(), profile = prepareSplitProfile(s.context, entries, ZeroHash), safe = A(110);
  const capture = { deployment: { chainId, factory: { address: s.context.factory, codeHash: s.factoryCodeHash },
    assetPolicy: { address: s.context.assetPolicyRegistry, codeHash: s.assetPolicyCodeHash }, implementation: s.implementation },
    snapshot: s, blockNumber: 20, blockHash: id("reviewed block") };
  for (const [kind, method] of [["register-profile", "registerProfile"], ["create-profile", "createProfile"], ["deploy-wallet", "deployWallet"]]) {
    const result = createSplitFactorySafeReview({ capture, profile, kind, safe, factoryAbi: fixture.abis.factory });
    const plan = verifySafeCallPlan(result.safePlan, [fixture.abis.factory]);
    assert.equal(plan.chainId, chainId); assert.equal(plan.steps.length, 1);
    assert.equal(plan.steps[0].safe, safe); assert.equal(plan.steps[0].transaction.operation, 0);
    assert.equal(plan.steps[0].transaction.to, s.context.factory); assert.equal(plan.steps[0].transaction.value, "0");
    assert.equal(abi.factory.parseTransaction(plan.steps[0].transaction).name, method);
    assert.equal(result.review.predictedWallet, profile.wallet); assert.equal(result.review.predictionOnly, true);
    assert.equal(result.review.entriesHash, profile.entriesHash); assert.equal(result.operation.caller, safe);
  }
});
