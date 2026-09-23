import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, getCreate2Address, id, keccak256 } from "ethers";
import { SPLIT_PROFILE_DOMAIN, SPLIT_WALLET_IMPLEMENTATION_INTERFACE_ID, canonicalizeSplitEntries,
  normalizeSplitFactoryCall, normalizeSplitFactoryContext, normalizeSplitFactorySnapshot, normalizeSplitProfile,
  predictSplitWallet, prepareSplitFactoryCall, prepareSplitProfile, splitEntriesHash, splitProfileId,
  splitWalletCloneHashes, splitWalletCloneInitCode, splitWalletCloneRuntime, splitWalletDomainSeparator,
  splitWalletReleaseRevocationTypedData, splitWalletReleaseTypedData, verifySplitWalletCloneRuntime } from "../dist/current-split-factory.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-split-factory-abi.json", import.meta.url), "utf8"));
const factoryAbi = new Interface(fixture.abis.factory), companionAbi = new Interface(fixture.abis.implementationInterface);
const coder = AbiCoder.defaultAbiCoder(), A = value => getAddress(`0x${BigInt(value).toString(16).padStart(40, "0")}`);
const B = value => `0x${BigInt(value).toString(16).padStart(64, "0")}`;
const chainId = (1n << 255n) + 1n;
function inputSnapshot(factory = A(10), implementation = A(11)) {
  const runtime = `0x3615603257363d3d373d3d3d363d73${implementation.slice(2).toLowerCase()}5af43d82803e903d91603057fd5bf35b00`;
  return { context: { chainId, factory, profileDomain: id("6529STREAM_SPLIT_PROFILE_V1"), schemaVersion: 1n,
    walletVersion: 4n, initCodeHash: keccak256(`0x3d603480600a3d3981f3${runtime.slice(2)}`),
    runtimeCodeHash: keccak256(runtime), assetPolicyRegistry: A(12) }, factoryCodeHash: id("factory code"),
    assetPolicyCodeHash: id("asset policy code"), implementation: { address: implementation, codeHash: id("implementation code") } };
}
const rows = () => [
  { account: A(257), sharePpm: 100_000n, labelId: B(2) },
  { account: A(256), sharePpm: 600_000n, labelId: ZeroHash },
  { account: A(257), sharePpm: 300_000n, labelId: B(1) },
];
const profile = snapshot => prepareSplitProfile(snapshot.context, rows(), ZeroHash);
const release = () => ({ asset: ZeroAddress, account: A(256), recipient: A(400),
  releasableSnapshot: (1n << 256n) - 1n, nonce: ZeroHash, deadline: (1n << 64n) - 1n });

test("exact source clone variant and companion distinguish implementations and reject standard clones", () => {
  const implementation = A(11), runtime = splitWalletCloneRuntime(implementation), init = splitWalletCloneInitCode(implementation);
  assert.equal(runtime, `0x3615603257363d3d373d3d3d363d73${implementation.slice(2)}5af43d82803e903d91603057fd5bf35b00`);
  assert.equal(init, `0x3d603480600a3d3981f3${runtime.slice(2)}`);
  assert.equal((runtime.length - 2) / 2, 52); assert.equal((init.length - 2) / 2, 62);
  assert.deepEqual(splitWalletCloneHashes(implementation), { initCodeHash: keccak256(init), runtimeCodeHash: keccak256(runtime) });
  assert.equal(verifySplitWalletCloneRuntime(implementation, runtime), keccak256(runtime));
  assert.notEqual(splitWalletCloneHashes(A(12)).runtimeCodeHash, keccak256(runtime));
  assert.throws(() => verifySplitWalletCloneRuntime(A(12), runtime));
  assert.throws(() => verifySplitWalletCloneRuntime(implementation, `${runtime.slice(0, -2)}01`));
  assert.throws(() => verifySplitWalletCloneRuntime(implementation, `0x363d3d373d3d3d363d73${implementation.slice(2)}5af43d82803e903d91602b57fd5bf3`));
  assert.throws(() => splitWalletCloneRuntime(ZeroAddress));
  const companionId = fixture.abis.implementationInterface.filter(row => row.type === "function")
    .reduce((value, row) => value ^ BigInt(companionAbi.getFunction(row.name).selector), 0n);
  assert.equal(companionId, BigInt(SPLIT_WALLET_IMPLEMENTATION_INTERFACE_ID));
});

test("canonical profiles sort numeric account and labels, aggregate accounts, and preserve input rows", () => {
  const input = rows(), original = structuredClone(input), p = profile(inputSnapshot());
  const expected = [input[1], input[2], input[0]];
  assert.deepEqual(canonicalizeSplitEntries(input), expected); assert.deepEqual(input, original);
  assert.deepEqual(p.entries, expected); assert.deepEqual(p.accounts, [A(256), A(257)]);
  assert.deepEqual(p.aggregateSharePpm, [600_000n, 400_000n]);
  const entryParam = factoryAbi.getFunction("profileIdFor").inputs[0];
  assert.equal(p.entriesHash, keccak256(coder.encode([entryParam], [expected])));
  assert.equal(splitEntriesHash(input), p.entriesHash);
  assert.equal(splitProfileId(p.context, [...input].reverse(), ZeroHash), p.profileId);
});

test("entry validation covers exact bounds, duplicate identities and total rather than lossy inputs", () => {
  const boundary = Array.from({ length: 64 }, (_, n) => ({ account: A(n + 1), sharePpm: 15_625n, labelId: ZeroHash }));
  assert.equal(canonicalizeSplitEntries(boundary).length, 64);
  assert.throws(() => canonicalizeSplitEntries([...boundary, { ...boundary[0], account: A(100) }]));
  assert.throws(() => canonicalizeSplitEntries([]));
  assert.throws(() => canonicalizeSplitEntries([{ account: A(1), sharePpm: 200_000n, labelId: ZeroHash },
    { account: A(1), sharePpm: 800_000n, labelId: ZeroHash }]), /Duplicate/);
  for (const patch of [{ account: ZeroAddress }, { sharePpm: 0n }, { sharePpm: 1_000_001n },
    { sharePpm: 1_000_000 }, { sharePpm: 1n << 32n }, { labelId: "0x00" }, { unknown: 1 }]) {
    assert.throws(() => canonicalizeSplitEntries([{ account: A(1), sharePpm: 1_000_000n, labelId: ZeroHash, ...patch }]));
  }
  assert.throws(() => canonicalizeSplitEntries([{ account: A(1), sharePpm: 999_999n, labelId: ZeroHash }]), /total/);
});

test("factory snapshots bind both per-factory clone hashes and retain explicitly historical v3 context", () => {
  const input = inputSnapshot(), s = normalizeSplitFactorySnapshot(input);
  assert.equal(s.context.chainId, chainId);
  for (const name of ["initCodeHash", "runtimeCodeHash"]) {
    assert.throws(() => normalizeSplitFactorySnapshot({ ...input, context: { ...input.context, [name]: id("unrelated") } }), /code hashes/);
  }
  assert.throws(() => normalizeSplitFactorySnapshot({ ...input, implementation: null }));
  assert.throws(() => normalizeSplitFactorySnapshot({ ...input, implementation: { ...input.implementation, codeHash: ZeroHash } }));
  assert.throws(() => normalizeSplitFactorySnapshot({ ...input, context: { ...input.context, walletVersion: 5n } }));
  const historical = normalizeSplitFactorySnapshot({ ...input, context: { ...input.context, walletVersion: 3n,
    initCodeHash: id("retained v3 init"), runtimeCodeHash: id("retained v3 runtime") }, implementation: null });
  assert.equal(historical.implementation, null); assert.equal(historical.context.walletVersion, 3n);
  assert.notEqual(profile(historical).profileId, profile(s).profileId);
  assert.throws(() => normalizeSplitFactorySnapshot({ ...historical, implementation: input.implementation }));
  // The pure original preimage codec accepts a uint16 version; planning only supports reviewed v3/v4 semantics.
  assert.equal(normalizeSplitFactoryContext({ ...input.context, walletVersion: 65535n }).walletVersion, 65535n);
  for (const patch of [{ chainId: 1 }, { chainId: 0n }, { chainId: 1n << 256n }, { walletVersion: 1n << 16n },
    { schemaVersion: 2n }, { profileDomain: id("other domain") }, { factory: ZeroAddress }, { initCodeHash: ZeroHash }, { extra: 1 }]) {
    assert.throws(() => normalizeSplitFactoryContext({ ...input.context, ...patch }));
  }
});

test("profile identity commits the entire original context and wallet prediction uses its profile salt", () => {
  const p = profile(inputSnapshot()), c = p.context;
  const original = keccak256(coder.encode(["bytes32", "uint256", "address", "uint16", "uint16", "bytes32", "bytes32", "address", "bytes32", "bytes32"],
    [SPLIT_PROFILE_DOMAIN, chainId, c.factory, 1n, 4n, c.initCodeHash, c.runtimeCodeHash, c.assetPolicyRegistry, p.entriesHash, ZeroHash]));
  assert.equal(p.profileId, original); assert.equal(p.wallet, getCreate2Address(c.factory, original, c.initCodeHash));
  for (const patch of [{ chainId: chainId - 1n }, { factory: A(20) }, { walletVersion: 3n }, { initCodeHash: id("init") },
    { runtimeCodeHash: id("runtime") }, { assetPolicyRegistry: A(21) }]) {
    assert.notEqual(prepareSplitProfile({ ...c, ...patch }, rows(), ZeroHash).profileId, original);
  }
  assert.notEqual(prepareSplitProfile(c, rows(), B(1)).profileId, original);
  const other = profile(inputSnapshot(A(30), A(31)));
  assert.notEqual(other.wallet, p.wallet); assert.notEqual(other.context.initCodeHash, c.initCodeHash);
  assert.equal(predictSplitWallet(c, ZeroHash), getCreate2Address(c.factory, ZeroHash, c.initCodeHash));
});

test("profile reconstruction rejects forged identity, aggregate, prediction and noncanonical row order", () => {
  const p = profile(inputSnapshot());
  assert.deepEqual(normalizeSplitProfile(structuredClone(p)), p);
  for (const patch of [{ profileId: B(1) }, { wallet: A(700) }, { entriesHash: B(2) },
    { accounts: [...p.accounts].reverse() }, { aggregateSharePpm: [400_000n, 600_000n] },
    { entries: [...p.entries].reverse() }, { registered: true }]) {
    assert.throws(() => normalizeSplitProfile({ ...p, ...patch }));
  }
});

test("registration, create-and-deploy and deployment remain distinct exact factory calls with an explicit caller", () => {
  const s = inputSnapshot(), p = profile(s), caller = A(99);
  for (const [kind, method] of [["register-profile", "registerProfile"], ["create-profile", "createProfile"], ["deploy-wallet", "deployWallet"]]) {
    const plan = prepareSplitFactoryCall(s, caller, { kind, profile: p });
    assert.equal(plan.caller, caller); assert.equal(plan.call.to, s.context.factory); assert.equal(plan.call.value, 0n);
    assert.equal(plan.call.data, factoryAbi.encodeFunctionData(method, kind === "deploy-wallet" ? [p.profileId] : [p.entries, p.metadataURIHash]));
    assert.equal(plan.predictionOnly, true); assert.equal("deployed" in plan, false); assert.equal("registered" in plan, false);
    assert.deepEqual(normalizeSplitFactoryCall(structuredClone(plan)), plan);
    assert.equal(factoryAbi.parseTransaction({ data: plan.call.data }).name, method);
  }
  assert.throws(() => prepareSplitFactoryCall(s, caller, { kind: "initialize", profile: p }));
  assert.throws(() => prepareSplitFactoryCall(s, ZeroAddress, { kind: "deploy-wallet", profile: p }));
  assert.throws(() => prepareSplitFactoryCall(s, caller, { kind: "register-profile", profile: profile(inputSnapshot(A(50), A(51))) }), /context/);
});

test("plans and payloads copy nested inputs before external async work and reject altered reviewed call data", async () => {
  const s = inputSnapshot(), input = rows(), p = structuredClone(prepareSplitProfile(s.context, input, ZeroHash));
  const plan = prepareSplitFactoryCall(s, A(99), { kind: "create-profile", profile: p });
  const expected = structuredClone(plan), message = release(), payload = splitWalletReleaseTypedData(s, p, message);
  s.context.chainId = 1n; s.implementation.address = A(500); input[0].sharePpm = 1n;
  p.entries[0].account = A(600); p.accounts.reverse(); message.recipient = A(700);
  await Promise.resolve();
  assert.deepEqual(plan, expected); assert.equal(payload.message.recipient, A(400));
  for (const item of [plan, plan.snapshot, plan.snapshot.context, plan.snapshot.implementation, plan.request, plan.request.profile,
    plan.request.profile.entries, plan.request.profile.entries[0], plan.request.profile.accounts, plan.request.profile.aggregateSharePpm, plan.call,
    payload, payload.domain, payload.message, payload.types, payload.types[payload.primaryType], payload.types[payload.primaryType][0]]) {
    assert.equal(Object.isFrozen(item), true);
  }
  for (const patch of [{ call: { ...plan.call, to: A(800) } }, { call: { ...plan.call, value: 1n } },
    { call: { ...plan.call, data: "0x" } }, { predictionOnly: false }, { approval: true }]) {
    assert.throws(() => normalizeSplitFactoryCall({ ...plan, ...patch }));
  }
});

test("release and revocation use original wallet-domain schemas with native assets, zero nonce and full-width snapshot", () => {
  const s = inputSnapshot(), p = profile(s), message = release(), payload = splitWalletReleaseTypedData(s, p, message);
  const domain = { name: "6529StreamSplitWallet", version: "1", chainId, verifyingContract: p.wallet };
  const types = { StreamReleaseAuthorization: [
    { name: "asset", type: "address" }, { name: "account", type: "address" }, { name: "recipient", type: "address" },
    { name: "releasableSnapshot", type: "uint256" }, { name: "nonce", type: "bytes32" }, { name: "deadline", type: "uint64" },
  ] };
  assert.deepEqual(payload.domain, domain); assert.deepEqual(payload.types, types);
  assert.equal(payload.digest, TypedDataEncoder.hash(domain, types, message));
  assert.equal(splitWalletDomainSeparator(p), TypedDataEncoder.hashDomain(domain));
  for (const verifyingContract of [s.context.factory, s.implementation.address, A(1000)]) {
    assert.notEqual(payload.digest, TypedDataEncoder.hash({ ...domain, verifyingContract }, types, message));
  }
  const revocation = { account: message.account, nonce: ZeroHash, deadline: 0n };
  const revoke = splitWalletReleaseRevocationTypedData(s, p, revocation);
  assert.equal(revoke.primaryType, "StreamReleaseAuthorizationRevocation");
  assert.equal(revoke.digest, TypedDataEncoder.hash(domain, { StreamReleaseAuthorizationRevocation: [
    { name: "account", type: "address" }, { name: "nonce", type: "bytes32" }, { name: "deadline", type: "uint64" },
  ] }, revocation));
});

test("signing payloads reject alternate contexts, invented fields, zero principals and integer overflow", () => {
  const s = inputSnapshot(), p = profile(s), message = release();
  assert.throws(() => splitWalletReleaseTypedData(s, profile(inputSnapshot(A(20), A(21))), message));
  for (const patch of [{ account: ZeroAddress }, { recipient: ZeroAddress }, { releasableSnapshot: 1n << 256n },
    { releasableSnapshot: -1n }, { deadline: 1n << 64n }, { deadline: 1 }, { nonce: "0x" }, { verifyingContract: s.context.factory }]) {
    assert.throws(() => splitWalletReleaseTypedData(s, p, { ...message, ...patch }));
  }
  const revoke = { account: A(256), nonce: ZeroHash, deadline: 0n };
  for (const patch of [{ account: ZeroAddress }, { deadline: 1n << 64n }, { nonce: "0x" }, { recipient: A(257) }]) {
    assert.throws(() => splitWalletReleaseRevocationTypedData(s, p, { ...revoke, ...patch }));
  }
});
