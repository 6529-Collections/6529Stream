import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import * as p from "../dist/current-entropy-instant.js";
import * as old from "../dist/current-entropy-collection-policy.js";

const fixture = JSON.parse(fs.readFileSync(new URL("./fixtures/current-entropy-instant-abi.json", import.meta.url), "utf8"));
const coder = AbiCoder.defaultAbiCoder(), abi = new Interface(fixture.abis.entropy), policyAbi = new Interface(fixture.abis.policy), gov = new Interface(fixture.abis.executor);
const h = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`, a = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const max256 = (1n << 256n) - 1n, max64 = (1n << 64n) - 1n, max32 = (1n << 32n) - 1n;
const reveal = () => ({ declared: false, requestMode: 0n, revealOwnerRole: ZeroHash, requestSLOBlocks: 0n, revealFeePerTokenWei: 0n });
function snapshot() { return { chainId: (1n << 100n) + 3n, coordinator: a(1), core: a(2), governanceExecutor: a(3), collectionId: (1n << 120n) + 1n,
  config: { provider: ZeroAddress, publicRequests: false, locked: false, timeoutBlocks: 0n, providerConfigHash: ZeroHash, providerCodeHash: ZeroHash, collectionSalt: ZeroHash },
  providerEpoch: 0n, reveal: reveal(), recovery: { policyId: ZeroHash, policyHash: ZeroHash, maxFreshRecoveryAttempts: 0n, revision: 0n, lastActionId: ZeroHash },
  entry: { revision: 0n, mode: 0n, securityClass: 0n, renderRequirement: 0n, policyHash: ZeroHash, lastActionId: ZeroHash, artistConsentRecord: ZeroHash },
  collectionExists: true, collectionFrozen: false, collectionMintedEver: 0n, revealEscrow: 0n }; }
function input() { return { mode: 1n, securityClass: 1n, renderRequirement: 0n, provider: a(10), collectionSalt: h(11), publicRequests: true, timeoutBlocks: 0n,
  reveal: reveal(), maxFreshRecoveryAttempts: 0n, recoveryPolicyId: ZeroHash }; }
const resolution = () => ({ providerCodeHash: h(12), providerConfigHash: p.entropyInstantProviderConfigHash(a(1)), recoveryPolicyHash: ZeroHash, instantMode: 1n, assumptionsHash: p.ENTROPY_INSTANT_ASSUMPTIONS_HASH });
const configure = (s = snapshot(), v = input(), r = resolution()) => p.prepareEntropyInstantPolicyConfigure(s, v, r);
const applied = plan => ({ ...plan.snapshot, ...plan.next });
function requestSnapshot() { const plan = configure(), s = applied(plan); return { chainId: s.chainId, coordinator: s.coordinator, core: s.core, collectionId: s.collectionId, tokenId: max256,
  config: s.config, policy: p.entropyInstantPolicyRecord(s), subject: { collectionId: s.collectionId, inputsHash: h(88), requestKey: ZeroHash, seed: ZeroHash, status: 3n },
  registeredAtBlock: (1n << 60n) + 1n, blockNumber: (1n << 60n) + 2n, tokenLifecycle: 2n, coordinatorAtMint: s.coordinator }; }
const request = (s = requestSnapshot(), caller = a(50), value = max256) => p.prepareEntropyInstantRequest(s, caller, value);
const coordinates = s => Object.fromEntries(["chainId", "coordinator", "core", "collectionId", "tokenId"].map(k => [k, s[k]]));
const window = () => ({ notBefore: 100n + 259200n, expiresAfter: 100n + 259200n + 604800n, reasonHash: h(30), reasonURI: "ipfs://instant/☃", manifestHash: ZeroHash });

test("new interface selectors and original request/event shapes match the frozen compiler", () => {
  const ours = new Interface(p.CURRENT_ENTROPY_INSTANT_ABI);
  ours.forEachFunction(f => assert.equal(f.format("sighash"), abi.getFunction(f.name).format("sighash")));
  ours.forEachEvent(e => assert.equal(e.format("full"), abi.getEvent(e.name).format("full")));
  const specs = [["instantProvider", p.ENTROPY_INSTANT_PROVIDER_INTERFACE_ID], ["instantIdentity", p.ENTROPY_INSTANT_IDENTITY_INTERFACE_ID], ["terminalFacts", p.ENTROPY_INSTANT_TERMINAL_FACTS_INTERFACE_ID]];
  for (const [key, expected] of specs) { let xor = 0n; new Interface(fixture.abis[key]).forEachFunction(f => { if (f.name !== "supportsInterface") xor ^= BigInt(f.selector); }); assert.equal(`0x${xor.toString(16).padStart(8, "0")}`, expected); }
  assert.equal(request().call.data, abi.encodeFunctionData("requestEntropy", [max256]));
  const source = fixture.sourceTexts["smart-contracts/domains/entropy/StreamEntropyProviderInstant.sol"];
  assert.ok(source.includes(p.ENTROPY_INSTANT_ASSUMPTIONS));
});

test("the separate policy profile preserves old ASYNC admission and rejects all forbidden INSTANT fields", () => {
  const s = snapshot(), v = input(), r = resolution();
  assert.throws(() => old.prepareEntropyCollectionPolicyConfigure(s, v, { providerCodeHash: r.providerCodeHash, providerConfigHash: r.providerConfigHash, recoveryPolicyHash: ZeroHash }), old.EntropyCollectionPolicyUnsupportedModeError);
  const async = { ...v, mode: 2n, securityClass: 0n, timeoutBlocks: 10n, reveal: { declared: true, requestMode: 1n, revealOwnerRole: id("ROLE_ENTROPY_REVEAL_OWNER"), requestSLOBlocks: 20n, revealFeePerTokenWei: 0n } };
  assert.equal(old.prepareEntropyCollectionPolicyConfigure(s, async, { providerCodeHash: r.providerCodeHash, providerConfigHash: r.providerConfigHash, recoveryPolicyHash: ZeroHash }).next.entry.mode, 2n);
  for (const patch of [{ mode: 0n }, { mode: 2n }, { securityClass: 0n }, { provider: ZeroAddress }, { timeoutBlocks: 1n }, { maxFreshRecoveryAttempts: 1n }, { recoveryPolicyId: h(1) }]) assert.throws(() => configure(s, { ...v, ...patch }, r));
  for (const field of Object.keys(v.reveal)) assert.throws(() => configure(s, { ...v, reveal: { ...v.reveal, [field]: field === "declared" ? true : field === "revealOwnerRole" ? h(1) : 1n } }, r), field);
  for (const patch of [{ instantMode: 0n }, { instantMode: 2n }, { assumptionsHash: ZeroHash }, { providerCodeHash: ZeroHash }, { providerConfigHash: ZeroHash }, { recoveryPolicyHash: h(1) }]) assert.throws(() => configure(s, v, { ...r, ...patch }));
  assert.throws(() => configure({ ...s, revealEscrow: 1n }));
  // A non-production assumptions hash is allowed by the original delayed-provider admission.
  assert.equal(configure(s, v, { ...r, assumptionsHash: h(9) }).factsVerified, false);
});

test("provider and recovery changes advance the epoch once; code-only change does not", () => {
  const first = configure(), current = applied(first);
  assert.equal(first.next.providerEpoch, 1n);
  const codeOnly = configure(current, input(), { ...resolution(), providerCodeHash: h(90) });
  assert.equal(codeOnly.next.providerEpoch, 1n); assert.notEqual(codeOnly.next.entry.policyHash, first.next.entry.policyHash);
  const oldRecovery = { ...current, recovery: { policyId: h(40), policyHash: h(41), maxFreshRecoveryAttempts: 2n, revision: 7n, lastActionId: h(42) } };
  const cleared = configure(oldRecovery, { ...input(), provider: a(20) }, { ...resolution(), providerConfigHash: h(43) });
  assert.equal(cleared.next.providerEpoch, 2n); assert.equal(cleared.next.recovery.revision, 8n);
  assert.deepEqual(cleared.next.recovery, { policyId: ZeroHash, policyHash: ZeroHash, maxFreshRecoveryAttempts: 0n, revision: 8n, lastActionId: h(42) });
  assert.equal(configure(oldRecovery).next.providerEpoch, 2n);
  assert.throws(() => configure(current), /no-op/);
  assert.equal(configure(current, { ...input(), collectionSalt: h(800) }).next.providerEpoch, 1n);
});

test("policy revision, epoch, recovery and lock boundaries preserve unchanged maximum values", () => {
  for (const patch of [{ collectionExists: false }, { collectionFrozen: true }, { collectionMintedEver: 1n }, { config: { ...snapshot().config, locked: true } }, { entry: { ...snapshot().entry, revision: max64 } }]) assert.throws(() => configure({ ...snapshot(), ...patch }));
  const s = applied(configure());
  assert.throws(() => configure({ ...s, providerEpoch: max32 }, { ...input(), provider: a(20) }));
  assert.equal(configure({ ...s, providerEpoch: max32 }, { ...input(), collectionSalt: h(81) }).next.providerEpoch, max32);
  assert.throws(() => configure({ ...s, recovery: { ...s.recovery, policyId: h(10), revision: max64 } }));
  assert.doesNotThrow(() => configure({ ...s, recovery: { ...s.recovery, revision: max64 } }, { ...input(), collectionSalt: h(82) }));
  const frozen = p.prepareEntropyInstantPolicyFreeze({ ...s, providerEpoch: max32, recovery: { ...s.recovery, revision: max64 } });
  assert.equal(frozen.next.providerEpoch, max32); assert.equal(frozen.next.recovery.revision, max64); assert.equal(frozen.next.entry.revision, 2n);
  assert.throws(() => p.prepareEntropyInstantPolicyFreeze(applied(frozen)));
  assert.throws(() => p.prepareEntropyInstantPolicyFreeze(snapshot()));
});

test("REQUIRED and NOT_REQUIRED share explicit policy mode but have different request eligibility", () => {
  const required = configure(), notRequired = configure(snapshot(), { ...input(), renderRequirement: 1n });
  assert.notEqual(required.next.entry.policyHash, notRequired.next.entry.policyHash);
  const s = requestSnapshot(), record = p.entropyInstantPolicyRecord(applied(notRequired));
  assert.throws(() => request({ ...s, policy: record, subject: { ...s.subject, status: 2n } }));
  assert.throws(() => request({ ...s, policy: record }));
  assert.equal(p.prepareEntropyInstantPolicyFreeze(applied(notRequired)).next.entry.renderRequirement, 1n);
  for (const status of [0n, 1n, 2n, 4n, 5n, 6n, 7n]) assert.throws(() => request({ ...s, subject: { ...s.subject, status } }));
});

test("original op17 direct/relay distinction and class1/class2 governance remain independent from preparation", () => {
  const configured = configure(), frozen = p.prepareEntropyInstantPolicyFreeze(applied(configured)), auth = { nonce: max256, deadline: max64, signature: "0x" };
  for (const plan of [configured, frozen]) {
    const direct = p.prepareEntropyInstantPolicyArtistConsent(plan, a(100), a(101), a(101), auth), relay = p.prepareEntropyInstantPolicyArtistConsent(plan, a(100), a(102), a(101), auth);
    assert.equal(direct.direct, true); assert.equal(relay.direct, false); assert.equal(direct.payload.digest, relay.payload.digest); assert.equal(relay.factsVerified, false);
    assert.deepEqual(p.normalizeEntropyInstantPolicyArtistConsent(relay), relay);
    assert.throws(() => p.normalizeEntropyInstantPolicyArtistConsent({ ...relay, direct: true }));
    assert.equal(p.prepareEntropyInstantPolicyArtistConsent(plan, a(100), a(101), a(101), { ...auth, signature: "0x1234" }).direct, false);
    const b = p.entropyInstantPolicyGovernanceBatch(plan, max256, window()), calls = [plan.governanceCall];
    assert.equal(b.publicationCall.data, gov.encodeFunctionData("publishGovernanceCallData", [[plan.targetCall.data]]));
    assert.equal(b.scheduleCall.data, gov.encodeFunctionData("scheduleGovernanceBatch", [plan.actionClass, calls, b.scopeHash, b.oldValueHash, b.newValueHash, b.window.notBefore, b.window.expiresAfter, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]));
    assert.equal(b.executionCall.data, gov.encodeFunctionData("executeGovernanceBatch", [b.actionId, calls, [plan.targetCall.data]]));
    assert.deepEqual(p.normalizeEntropyInstantPolicyGovernanceBatch(b), b);
    assert.throws(() => p.normalizeEntropyInstantPolicyGovernanceBatch({ ...b, actionId: h(9) }));
    const delay = plan.actionClass === 1n ? 172800n : 259200n;
    p.assertEntropyInstantPolicyGovernanceWindow(plan.actionClass, { ...window(), notBefore: 100n + delay }, 100n);
    assert.throws(() => p.assertEntropyInstantPolicyGovernanceWindow(plan.actionClass, { ...window(), notBefore: 99n + delay }, 100n));
  }
  assert.equal(configured.targetCall.data, policyAbi.encodeFunctionData("configureCollectionEntropyPolicy", [configured.snapshot.collectionId, input()]));
  assert.equal(frozen.targetCall.data, policyAbi.encodeFunctionData("freezeCollectionEntropyPolicy", [frozen.snapshot.collectionId]));
  assert.notEqual(configured.transition.artistContentStateHash, frozen.transition.artistContentStateHash);
});

test("later-block request guards retain actual Core delivery coordinates without inferring caller authority", () => {
  const s = requestSnapshot();
  for (const patch of [{ blockNumber: s.registeredAtBlock }, { blockNumber: s.registeredAtBlock - 1n }, { blockNumber: max64 + 1n }, { tokenLifecycle: 1n }, { tokenLifecycle: 3n }, { coordinatorAtMint: a(99) }, { subject: { ...s.subject, collectionId: 1n } },
    { policy: { ...s.policy, explicitPolicy: false } }, { policy: { ...s.policy, configured: false } }, { policy: { ...s.policy, revision: 0n } }, { policy: { ...s.policy, mode: 2n } }, { policy: { ...s.policy, securityClass: 0n } }]) assert.throws(() => request({ ...s, ...patch }));
  assert.equal(request({ ...s, registeredAtBlock: max64 - 1n, blockNumber: max64 }).snapshot.blockNumber, max64);
  const privateRequest = request({ ...s, config: { ...s.config, publicRequests: false } });
  assert.equal(privateRequest.factsVerified, false); // Role/requester evidence is deliberately external.
  assert.throws(() => request(s, ZeroAddress));
});

test("single token context/key keep exact full-width fields and explicitly exclude the original mint commitment", () => {
  const plan = request(), s = plan.snapshot, q = plan.requestPolicy;
  assert.equal(plan.context, coder.encode(["uint16", "address", "uint256", "uint256", "bytes32", "uint32", "bytes32", "uint16", "bytes32"], [1n, s.core, s.collectionId, max256, ZeroHash, q.providerEpoch, q.providerConfigHash, 1n, ZeroHash]));
  const key = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "uint256", "address", "uint32", "bytes32", "uint16"], [id("6529STREAM_ENTROPY_REQUEST_V1"), s.chainId, s.coordinator, s.core, s.collectionId, s.tokenId, q.provider, q.providerEpoch, q.providerConfigHash, 1n]));
  assert.equal(plan.requestKey, key);
  assert.equal(plan.providerRequestId, BigInt(keccak256(coder.encode(["bytes32", "bytes32", "uint16", "address", "uint32", "bytes32"], [id("6529STREAM_INSTANT_PROVIDER_REQUEST_V1"), key, 1n, q.provider, q.providerEpoch, q.providerConfigHash]))));
  assert.equal(plan.subjectKey, keccak256(coder.encode(["string", "uint256"], ["TOKEN", max256])));
  assert.equal(q.inputsHash, ZeroHash); assert.equal(s.subject.inputsHash, h(88));
  const changedMint = request({ ...s, subject: { ...s.subject, inputsHash: h(99) } });
  assert.equal(changedMint.requestKey, key); assert.equal(changedMint.context, plan.context); assert.equal(p.entropyInstantSeed(changedMint, h(22)), p.entropyInstantSeed(plan, h(22)));
  assert.throws(() => p.entropyInstantContext(coordinates(s), { ...q, inputsHash: h(1) }));
  assert.throws(() => p.entropyInstantRequestKey(coordinates(s), { ...q, requestAttempt: 2n }));
  assert.throws(() => p.normalizeEntropyInstantRequestCoordinates({ ...coordinates(s), scopeId: h(10) }));
});

test("request identity stays stable across timing retries while production raw/provenance/seed use the execution predecessor", () => {
  const first = request(), second = request({ ...first.snapshot, blockNumber: first.snapshot.blockNumber + 5n });
  assert.equal(first.requestKey, second.requestKey); assert.equal(first.providerRequestId, second.providerRequestId);
  const produce = (plan, blockHash) => p.entropyInstantRawResult(plan.requestKey, plan.context, plan.snapshot.blockNumber - 1n, blockHash, plan.requestPolicy.providerConfigHash, p.ENTROPY_INSTANT_ASSUMPTIONS_HASH);
  const one = produce(first, h(500)), two = produce(second, h(505));
  assert.notEqual(one.rawRandomness, two.rawRandomness); assert.notEqual(one.provenanceHash, two.provenanceHash); assert.notEqual(p.entropyInstantSeed(first, one.rawRandomness), p.entropyInstantSeed(second, two.rawRandomness));
  const changedContext = p.entropyInstantRawResult(first.requestKey, "0x12", first.snapshot.blockNumber - 1n, h(500), first.requestPolicy.providerConfigHash, p.ENTROPY_INSTANT_ASSUMPTIONS_HASH);
  assert.notEqual(changedContext.rawRandomness, one.rawRandomness);
  const changedConfig = p.entropyInstantRawResult(first.requestKey, first.context, first.snapshot.blockNumber - 1n, h(500), h(700), p.ENTROPY_INSTANT_ASSUMPTIONS_HASH);
  assert.equal(changedConfig.rawRandomness, one.rawRandomness); assert.notEqual(changedConfig.provenanceHash, one.provenanceHash);
});

test("zero raw randomness is valid and the full original seed binds collection salt separately from request identity", () => {
  const first = request(), salted = request({ ...first.snapshot, config: { ...first.snapshot.config, collectionSalt: h(800) } });
  assert.equal(salted.requestKey, first.requestKey); assert.equal(salted.context, first.context); assert.equal(salted.providerRequestId, first.providerRequestId);
  assert.notEqual(p.entropyInstantSeed(first, ZeroHash), ZeroHash); assert.notEqual(p.entropyInstantSeed(first, ZeroHash), p.entropyInstantSeed(salted, ZeroHash));
  const { snapshot: s, requestPolicy: q } = first;
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "address", "uint32", "bytes32", "bytes32", "uint256", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ENTROPY_SEED_V1"), s.chainId, s.coordinator, s.core, s.collectionId, h(s.tokenId), q.provider, q.providerEpoch, q.providerConfigHash, first.requestKey, first.providerRequestId, ZeroHash, q.collectionSalt, ZeroHash]));
  assert.equal(p.entropyInstantSeed(first, ZeroHash), expected);
  assert.throws(() => p.entropyInstantSeed(first, "0x"));
});

test("provider fee is zero and all supplied ETH belongs to the caller pull credit", () => {
  for (const value of [0n, 1n, max256]) {
    const plan = request(requestSnapshot(), a(70), value);
    assert.equal(plan.providerFee, 0n); assert.equal(plan.callerCredit, value); assert.equal(plan.value, value); assert.equal(plan.call.value, value); assert.equal(plan.caller, a(70));
    assert.equal(plan.call.to, plan.snapshot.coordinator); assert.equal(abi.decodeFunctionData("requestEntropy", plan.call.data).tokenId, max256);
  }
  assert.throws(() => request(requestSnapshot(), a(50), max256 + 1n));
});

test("complete terminal-facts codec preserves every original status without synthesizing finality", () => {
  const record = requestSnapshot().policy, terminal = new Interface(fixture.abis.terminalFacts);
  for (let status = 0n; status <= 7n; status++) {
    const facts = { collectionId: max256, policy: record, status, seed: ZeroHash, requestKey: status >= 4n ? h(100) : ZeroHash }, bytes = p.encodeEntropyInstantTerminalFacts(facts);
    assert.equal(bytes.length, 2 + 512 * 2); assert.equal(bytes, terminal.encodeFunctionResult("staticTerminalEntropyFacts", [facts.collectionId, record, status, facts.seed, facts.requestKey]));
    assert.deepEqual(p.decodeEntropyInstantTerminalFacts(bytes), facts); assert.equal(Object.hasOwn(p.decodeEntropyInstantTerminalFacts(bytes), "finalized"), false);
  }
  const facts = { collectionId: 0n, policy: record, status: 0n, seed: ZeroHash, requestKey: ZeroHash };
  assert.equal(p.normalizeEntropyInstantTerminalFacts(facts).collectionId, 0n);
  for (const status of [8n, 255n, 256n]) assert.throws(() => p.normalizeEntropyInstantTerminalFacts({ ...facts, status }));
  const bytes = p.encodeEntropyInstantTerminalFacts(facts);
  assert.throws(() => p.decodeEntropyInstantTerminalFacts(bytes.slice(0, -64))); assert.throws(() => p.decodeEntropyInstantTerminalFacts(bytes + "00".repeat(32)));
  assert.throws(() => p.decodeEntropyInstantTerminalFacts(bytes.slice(0, 66) + h(2).slice(2) + bytes.slice(130))); // Noncanonical boolean.
});

test("request snapshot codec preserves unknown zero tuple and rejects width or ABI padding drift", () => {
  const q = request().requestPolicy, bytes = p.encodeEntropyInstantRequestPolicySnapshot(q);
  assert.equal(bytes.length, 2 + 224 * 2); assert.equal(bytes, abi.encodeFunctionResult("requestPolicySnapshot", [q]));
  assert.deepEqual(p.decodeEntropyInstantRequestPolicySnapshot(bytes), q);
  const unknown = { provider: ZeroAddress, providerCodeHash: ZeroHash, providerEpoch: 0n, providerConfigHash: ZeroHash, collectionSalt: ZeroHash, inputsHash: ZeroHash, requestAttempt: 0n };
  assert.deepEqual(p.decodeEntropyInstantRequestPolicySnapshot(p.encodeEntropyInstantRequestPolicySnapshot(unknown)), unknown);
  for (const patch of [{ providerEpoch: max32 + 1n }, { requestAttempt: 65536n }, { providerEpoch: 1 }, { extra: true }]) assert.throws(() => p.normalizeEntropyInstantRequestPolicySnapshot({ ...q, ...patch }));
  assert.throws(() => p.decodeEntropyInstantRequestPolicySnapshot(bytes + "00".repeat(32)));
  assert.throws(() => p.decodeEntropyInstantRequestPolicySnapshot("0x01" + bytes.slice(4)));
});

test("immutable policy and request plans reconstruct reviewed inputs and reject forged derived fields", () => {
  const s = snapshot(), v = input(), d = resolution(), plan = configure(s, v, d);
  s.config.collectionSalt = h(899); v.reveal.declared = true; d.providerConfigHash = h(899);
  assert.equal(plan.snapshot.config.collectionSalt, ZeroHash); assert.equal(plan.input.reveal.declared, false); assert.notEqual(plan.resolution.providerConfigHash, h(899));
  assert.throws(() => { plan.next.entry.mode = 2n; }); assert.throws(() => { plan.input.reveal.declared = true; });
  assert.deepEqual(p.normalizeEntropyInstantPolicyPlan(plan), plan);
  for (const patch of [{ factsVerified: true }, { resolution: { ...plan.resolution, instantMode: 0n } }, { transition: { ...plan.transition, artistContentStateHash: h(1) } }, { targetCall: { ...plan.targetCall, value: 1n } }]) assert.throws(() => p.normalizeEntropyInstantPolicyPlan({ ...plan, ...patch }));
  const source = structuredClone(requestSnapshot()), prepared = request(source); source.subject.inputsHash = h(777); source.config.provider = a(777);
  assert.equal(prepared.snapshot.subject.inputsHash, h(88)); assert.equal(prepared.snapshot.config.provider.toLowerCase(), a(10));
  assert.throws(() => { prepared.snapshot.subject.status = 5n; });
  assert.deepEqual(p.normalizeEntropyInstantRequestPlan(prepared), prepared);
  for (const patch of [{ factsVerified: true }, { callerCredit: 0n }, { providerFee: 1n }, { context: "0x" }, { requestKey: h(10) }, { providerRequestId: 2n }, { call: { ...prepared.call, to: a(2) } }]) assert.throws(() => p.normalizeEntropyInstantRequestPlan({ ...prepared, ...patch }));
  assert.throws(() => p.normalizeEntropyInstantRequestSnapshot({ ...prepared.snapshot, blockNumber: 1 }));
  assert.throws(() => p.normalizeEntropyInstantRequestSnapshot({ ...prepared.snapshot, coordinatorAtMint: false }));
  assert.throws(() => p.normalizeEntropyInstantRequestSnapshot({ ...prepared.snapshot, subject: { ...prepared.snapshot.subject, status: 8n } }));
});
