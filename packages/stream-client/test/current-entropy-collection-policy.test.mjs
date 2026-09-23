import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { AbiCoder, Interface, TypedDataEncoder, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import * as p from "../dist/current-entropy-collection-policy.js";
const fixture = JSON.parse(fs.readFileSync(new URL("./fixtures/current-entropy-collection-policy-abi.json", import.meta.url), "utf8"));
const coder = AbiCoder.defaultAbiCoder(), abi = new Interface(fixture.abis.policy), artist = new Interface(fixture.abis.artist), gov = new Interface(fixture.abis.executor);
const h = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`, a = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const max256 = (1n << 256n) - 1n, max64 = (1n << 64n) - 1n, max32 = (1n << 32n) - 1n;
const reveal = () => ({ declared: false, requestMode: 0n, revealOwnerRole: ZeroHash, requestSLOBlocks: 0n, revealFeePerTokenWei: 0n });
const zeroResolution = () => ({ providerCodeHash: ZeroHash, providerConfigHash: ZeroHash, recoveryPolicyHash: ZeroHash });
function snapshot() { return { chainId: (1n << 100n) + 3n, coordinator: a(1), core: a(2), governanceExecutor: a(3), collectionId: (1n << 120n) + 1n,
  config: { provider: ZeroAddress, publicRequests: false, locked: false, timeoutBlocks: 0n, providerConfigHash: ZeroHash, providerCodeHash: ZeroHash, collectionSalt: ZeroHash },
  providerEpoch: 0n, reveal: reveal(), recovery: { policyId: ZeroHash, policyHash: ZeroHash, maxFreshRecoveryAttempts: 0n, revision: 0n, lastActionId: ZeroHash },
  entry: { revision: 0n, mode: 0n, securityClass: 0n, renderRequirement: 0n, policyHash: ZeroHash, lastActionId: ZeroHash, artistConsentRecord: ZeroHash },
  collectionExists: true, collectionFrozen: false, collectionMintedEver: 0n, revealEscrow: 0n }; }
function disabled() { return { mode: 0n, securityClass: 1n, renderRequirement: 1n, provider: ZeroAddress, collectionSalt: ZeroHash, publicRequests: false, timeoutBlocks: 0n, reveal: reveal(), maxFreshRecoveryAttempts: 0n, recoveryPolicyId: ZeroHash }; }
function asyncInput() { return { mode: 2n, securityClass: 0n, renderRequirement: 0n, provider: a(10), collectionSalt: h(11), publicRequests: true, timeoutBlocks: 25n,
  reveal: { declared: true, requestMode: 1n, revealOwnerRole: id("ROLE_ENTROPY_REVEAL_OWNER"), requestSLOBlocks: 40n, revealFeePerTokenWei: (1n << 100n) + 19n }, maxFreshRecoveryAttempts: 0n, recoveryPolicyId: ZeroHash }; }
const resolution = () => ({ providerCodeHash: h(12), providerConfigHash: h(13), recoveryPolicyHash: ZeroHash });
const coordinates = s => Object.fromEntries(["chainId", "coordinator", "core", "governanceExecutor", "collectionId"].map(k => [k, s[k]]));
const state = s => Object.fromEntries(["config", "providerEpoch", "reveal", "recovery", "entry"].map(k => [k, s[k]]));
const configure = (s = snapshot(), input = asyncInput(), r = resolution()) => p.prepareEntropyCollectionPolicyConfigure(s, input, r);
const applied = plan => ({ ...plan.snapshot, ...plan.next });
const window = () => ({ notBefore: 100n + 259200n, expiresAfter: 100n + 259200n + 604800n, reasonHash: h(30), reasonURI: "ipfs://entropy/☃", manifestHash: ZeroHash });

test("five original capability calls and complete tuples match their exact frozen ABI", () => {
  const ours = new Interface(p.CURRENT_ENTROPY_COLLECTION_POLICY_ABI); let xor = 0n;
  ours.forEachFunction(f => { assert.equal(f.format("sighash"), abi.getFunction(f.name).format("sighash")); xor ^= BigInt(f.selector); });
  assert.equal(`0x${xor.toString(16).padStart(8, "0")}`, p.ENTROPY_COLLECTION_POLICY_INTERFACE_ID);
  const input = asyncInput(), encoded = p.encodeEntropyCollectionPolicyInput(input);
  assert.equal(encoded, coder.encode([abi.getFunction("configureCollectionEntropyPolicy").inputs[1]], [input]));
  assert.deepEqual(p.decodeEntropyCollectionPolicyInput(encoded), p.normalizeEntropyCollectionPolicyInput(input));
  const record = p.entropyCollectionPolicyRecord(snapshot());
  assert.equal(p.encodeEntropyCollectionPolicyRecord(record).length, 2 + 384 * 2);
  assert.equal(p.encodeEntropyCollectionPolicyRecord(record), abi.encodeFunctionResult("collectionEntropyPolicy", [record]));
  assert.deepEqual(p.decodeEntropyCollectionPolicyRecord(p.encodeEntropyCollectionPolicyRecord(record)), record);
  assert.throws(() => p.decodeEntropyCollectionPolicyInput(encoded + "00".repeat(32)));
  assert.throws(() => p.decodeEntropyCollectionPolicyRecord(p.encodeEntropyCollectionPolicyRecord(record) + "00".repeat(32)));
});

test("legacy public defaults never replace the raw zero namespace entry in configure state", () => {
  const s = snapshot(), r = p.entropyCollectionPolicyRecord(s);
  assert.equal(r.configured, false); assert.equal(r.explicitPolicy, false); assert.equal(r.mode, 2n); assert.equal(r.policyHash, ZeroHash);
  assert.equal(r.contentStateHash, keccak256(coder.encode(["bytes32", "bytes32", "bool"], [id("6529STREAM_ENTROPY_CONFIGURATION_V1"), ZeroHash, false])));
  assert.deepEqual(p.entropyCollectionPolicyEntryFromRecord(r), s.entry);
  const plan = configure(s), wrong = { ...state(s), entry: { ...s.entry, mode: r.mode, policyHash: r.policyHash } };
  assert.notEqual(plan.transition.oldValueHash, p.entropyCollectionPolicyStateHash(plan.transition.scopeHash, wrong));
  assert.throws(() => p.entropyCollectionPolicyEntryFromRecord({ ...r, revision: 1n }));
  assert.throws(() => p.entropyCollectionPolicyEntryFromRecord({ ...r, mode: 0n }));
});

test("V2 content hash matches the full original preimage and excludes fees, locks, revisions and evidence IDs", () => {
  const plan = configure(), s = plan.next, c = coordinates(plan.snapshot), e = s.entry, cfg = s.config, r = s.reveal, b = s.recovery;
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "uint8", "uint8", "uint8", "address", "bytes32", "bytes32", "uint32", "bytes32", "bool", "uint64", "bool", "uint8", "bytes32", "uint64", "bytes32", "bytes32", "uint16"],
    [id("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"), c.chainId, c.coordinator, c.core, c.collectionId, e.mode, e.securityClass, e.renderRequirement, cfg.provider, cfg.providerCodeHash, cfg.providerConfigHash, s.providerEpoch, cfg.collectionSalt, cfg.publicRequests, cfg.timeoutBlocks, r.declared, r.requestMode, r.revealOwnerRole, r.requestSLOBlocks, b.policyId, b.policyHash, b.maxFreshRecoveryAttempts]));
  assert.equal(s.entry.policyHash, expected);
  for (const next of [{ ...s, reveal: { ...r, revealFeePerTokenWei: max256 } }, { ...s, config: { ...cfg, locked: true } }, { ...s, entry: { ...e, revision: 99n, policyHash: h(99), lastActionId: h(98), artistConsentRecord: h(97) } }, { ...s, recovery: { ...b, revision: 99n, lastActionId: h(95) } }]) assert.equal(p.entropyCollectionPolicyHash(c, next), expected);
  assert.equal(p.entropyCollectionPolicyHash({ ...c, governanceExecutor: a(999) }, s), expected);
  assert.notEqual(p.entropyCollectionPolicyHash({ ...c, coordinator: a(999) }, s), expected);
  assert.notEqual(p.entropyCollectionPolicyHash(c, { ...s, entry: { ...e, renderRequirement: 1n } }), expected);
  assert.notEqual(p.entropyCollectionPolicyStateHash(plan.transition.scopeHash, { ...s, reveal: { ...r, revealFeePerTokenWei: max256 } }), plan.transition.newValueHash);
});

test("fresh DISABLED accepts both security classes and requires every provider/reveal/recovery field to be canonical zero", () => {
  for (const securityClass of [0n, 1n]) { const plan = configure(snapshot(), { ...disabled(), securityClass }, zeroResolution()); assert.equal(plan.next.providerEpoch, 0n); assert.equal(plan.next.entry.revision, 1n); assert.equal(plan.next.config.provider, ZeroAddress); }
  const input = disabled();
  for (const patch of [{ renderRequirement: 0n }, { provider: a(10) }, { collectionSalt: h(10) }, { publicRequests: true }, { timeoutBlocks: 1n }, { maxFreshRecoveryAttempts: 1n }, { recoveryPolicyId: h(10) }]) assert.throws(() => configure(snapshot(), { ...input, ...patch }, zeroResolution()));
  for (const field of Object.keys(input.reveal)) { const value = field === "declared" ? true : field === "revealOwnerRole" ? h(1) : 1n; assert.throws(() => configure(snapshot(), { ...input, reveal: { ...input.reveal, [field]: value } }, zeroResolution()), field); }
  assert.throws(() => configure({ ...snapshot(), revealEscrow: 1n }, input, zeroResolution()));
  assert.throws(() => configure(snapshot(), input, resolution()));
  assert.throws(() => configure(snapshot(), input, { ...zeroResolution(), recoveryPolicyHash: h(1) }));
});

test("INSTANT remains typed unsupported for either security class; ASYNC NOT_REQUIRED keeps fee declaration", () => {
  for (const securityClass of [0n, 1n]) assert.throws(() => configure(snapshot(), { ...asyncInput(), mode: 1n, securityClass }), error => error instanceof p.EntropyCollectionPolicyUnsupportedModeError && error.mode === 1n);
  const input = { ...asyncInput(), renderRequirement: 1n, securityClass: 1n }, plan = configure(snapshot(), input);
  assert.equal(plan.next.entry.renderRequirement, 1n); assert.equal(plan.next.reveal.revealFeePerTokenWei, input.reveal.revealFeePerTokenWei);
  for (const patch of [{ provider: ZeroAddress }, { timeoutBlocks: 0n }, { reveal: { ...input.reveal, declared: false } }, { reveal: { ...input.reveal, requestMode: 2n } }, { reveal: { ...input.reveal, revealOwnerRole: ZeroHash } }, { reveal: { ...input.reveal, requestSLOBlocks: 0n } }]) assert.throws(() => configure(snapshot(), { ...input, ...patch }));
  // These hashes are supplied facts; active providers and exact fee quote are deliberately left to pinned reads/simulation.
  assert.equal(configure(snapshot(), { ...input, reveal: { ...input.reveal, revealFeePerTokenWei: 0n } }).factsVerified, false);
});

test("provider epoch advances once on provider/config or recovery binding changes, never code hash alone", () => {
  const first = configure(), s = applied(first), input = asyncInput();
  assert.equal(first.next.providerEpoch, 1n);
  const code = configure(s, input, { ...resolution(), providerCodeHash: h(900) });
  assert.equal(code.next.providerEpoch, 1n); assert.notEqual(code.next.entry.policyHash, first.next.entry.policyHash);
  const binding = { ...input, recoveryPolicyId: h(40), maxFreshRecoveryAttempts: 2n };
  const both = configure(s, { ...binding, provider: a(20) }, { ...resolution(), providerConfigHash: h(80), recoveryPolicyHash: h(41) });
  assert.equal(both.next.providerEpoch, 2n); assert.equal(both.next.recovery.revision, 1n);
  const recoveryOnly = configure(s, binding, { ...resolution(), recoveryPolicyHash: h(41) }); assert.equal(recoveryOnly.next.providerEpoch, 2n);
  const content = configure(s, { ...input, collectionSalt: h(700) }); assert.equal(content.next.providerEpoch, 1n); assert.equal(content.next.recovery.revision, 0n);
  const removed = configure(applied(both), disabled(), zeroResolution()); assert.equal(removed.next.providerEpoch, 3n); assert.equal(removed.next.recovery.revision, 2n);
  assert.equal(removed.next.recovery.lastActionId, both.next.recovery.lastActionId);
  assert.throws(() => configure(s, { ...input, recoveryPolicyId: h(99) }));
});

test("explicit no-op and fee-only replacement reject but original first explicit conversion remains possible", () => {
  const first = configure(), s = applied(first), input = asyncInput();
  assert.throws(() => configure(s));
  assert.throws(() => configure(s, { ...input, reveal: { ...input.reveal, revealFeePerTokenWei: input.reveal.revealFeePerTokenWei + 1n } }), /fee-only/);
  const legacy = { ...s, entry: snapshot().entry };
  const converted = configure(legacy); assert.equal(converted.next.providerEpoch, s.providerEpoch); assert.equal(converted.next.entry.revision, 1n);
  const stateOnly = { ...s, entry: { ...s.entry, lastActionId: h(500), artistConsentRecord: h(501) }, recovery: { ...s.recovery, lastActionId: h(502) } };
  assert.equal(p.entropyCollectionPolicyStateHash(first.transition.scopeHash, state(stateOnly)), first.transition.newValueHash);
});

test("freeze is a separate class2 scope and op17 content state, retaining hash/epoch/recovery and incrementing only policy revision", () => {
  const first = configure(), s = applied(first), frozen = p.prepareEntropyCollectionPolicyFreeze(s);
  assert.equal(frozen.actionClass, 2n); assert.equal(frozen.next.config.locked, true);
  assert.equal(frozen.next.entry.policyHash, s.entry.policyHash); assert.equal(frozen.next.entry.revision, s.entry.revision + 1n);
  assert.equal(frozen.next.providerEpoch, s.providerEpoch); assert.deepEqual(frozen.next.recovery, s.recovery);
  assert.notEqual(frozen.transition.scopeHash, first.transition.scopeHash); assert.notEqual(frozen.transition.artistContentStateHash, first.transition.artistContentStateHash);
  assert.equal(frozen.transition.artistContentStateHash, p.entropyCollectionPolicyContentStateHash(s.entry.policyHash, true));
  assert.equal(frozen.previewCall.data, abi.encodeFunctionData("freezeCollectionEntropyPolicyTransition", [s.collectionId]));
  assert.equal(frozen.targetCall.data, abi.encodeFunctionData("freezeCollectionEntropyPolicy", [s.collectionId]));
  assert.throws(() => p.prepareEntropyCollectionPolicyFreeze(snapshot())); assert.throws(() => p.prepareEntropyCollectionPolicyFreeze(applied(frozen)));
});

test("lifetime mint/lock and exact revision overflow checks preserve unchanged-max branches", () => {
  for (const patch of [{ collectionExists: false }, { collectionFrozen: true }, { collectionMintedEver: 1n }, { config: { ...snapshot().config, locked: true } }, { entry: { ...snapshot().entry, revision: max64 } }]) assert.throws(() => configure({ ...snapshot(), ...patch }));
  const s = applied(configure());
  assert.throws(() => configure({ ...s, providerEpoch: max32 }, { ...asyncInput(), provider: a(90) }));
  assert.doesNotThrow(() => configure({ ...s, providerEpoch: max32 }, { ...asyncInput(), collectionSalt: h(80) }));
  assert.throws(() => configure({ ...s, recovery: { ...s.recovery, revision: max64 } }, { ...asyncInput(), recoveryPolicyId: h(40), maxFreshRecoveryAttempts: 1n }, { ...resolution(), recoveryPolicyHash: h(41) }));
  assert.doesNotThrow(() => p.prepareEntropyCollectionPolicyFreeze({ ...s, providerEpoch: max32, recovery: { ...s.recovery, revision: max64 } }));
  assert.equal(p.prepareEntropyCollectionPolicyFreeze({ ...s, entry: { ...s.entry, revision: max64 - 1n } }).next.entry.revision, max64);
});

test("legacy policy hash retains epoch1, premint epochs and recovery profiles and explicit V2 returns unavailable", () => {
  const first = configure(), legacy = { ...applied(first), entry: snapshot().entry };
  const one = p.entropyCollectionPolicyLegacyHash(coordinates(legacy), state(legacy)); assert.notEqual(one, ZeroHash);
  const two = p.entropyCollectionPolicyLegacyHash(coordinates(legacy), { ...state(legacy), providerEpoch: 2n }); assert.notEqual(two, one);
  const fresh = p.entropyCollectionPolicyLegacyHash(coordinates(legacy), { ...state(legacy), recovery: { ...legacy.recovery, policyId: h(40), policyHash: h(41), maxFreshRecoveryAttempts: 2n } }); assert.notEqual(fresh, one);
  assert.equal(p.entropyCollectionPolicyRecord(legacy).policyHash, one);
  assert.equal(p.entropyCollectionPolicyLegacyHash(coordinates(legacy), { ...state(legacy), reveal: { ...legacy.reveal, revealFeePerTokenWei: max256 } }), one);
  assert.equal(p.entropyCollectionPolicyLegacyHash(coordinates(legacy), first.next), ZeroHash);
  assert.equal(p.entropyCollectionPolicyRecord(applied(first)).explicitPolicy, true);
  assert.deepEqual(p.entropyCollectionPolicyEntryFromRecord(p.entropyCollectionPolicyRecord(applied(first))), first.next.entry);
});

test("original Artist op17 domain binds actual facade and exact fourth transition word, with caller distinct from signer", () => {
  const plan = configure(), auth = { nonce: max256, deadline: max64, signature: "0x" }, registry = a(100), signer = a(101);
  const direct = p.prepareEntropyCollectionPolicyArtistConsent(plan, registry, signer, signer, auth);
  const relay = p.prepareEntropyCollectionPolicyArtistConsent(plan, registry, a(102), signer, auth);
  assert.equal(direct.direct, true); assert.equal(relay.direct, false); assert.equal(direct.payload.digest, relay.payload.digest);
  const terms = { collectionId: plan.snapshot.collectionId, metadataContract: plan.snapshot.coordinator, familyId: id("6529STREAM_ENTROPY_CONFIGURATION_V1"), newStateHash: plan.transition.artistContentStateHash };
  assert.equal(direct.call.data, artist.encodeFunctionData("recordContentConsent", [terms, [auth.nonce, auth.deadline, "0x"]]));
  const fields = "address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline".split(",").map(f => { const [type, name] = f.split(" "); return { type, name }; });
  const message = { core: plan.snapshot.core, ...terms, nonce: auth.nonce, deadline: auth.deadline };
  assert.equal(direct.payload.digest, TypedDataEncoder.hash({ name: "6529StreamArtistRegistry", version: "1", chainId: plan.snapshot.chainId, verifyingContract: registry }, { StreamArtistContentConsent: fields }, message));
  for (const signature of ["0x12", "0x" + "11".repeat(64), "0x" + "22".repeat(65), "0x" + "33".repeat(512)]) {
    const proof = p.prepareEntropyCollectionPolicyArtistConsent(plan, registry, signer, signer, { ...auth, signature }); assert.equal(proof.direct, false); assert.equal(proof.payload.digest, direct.payload.digest);
  }
  const frozen = p.prepareEntropyCollectionPolicyFreeze(applied(plan)); assert.notEqual(p.prepareEntropyCollectionPolicyArtistConsent(frozen, registry, signer, signer, auth).payload.digest, direct.payload.digest);
  assert.deepEqual(p.normalizeEntropyCollectionPolicyArtistConsent(relay), relay);
  assert.throws(() => p.normalizeEntropyCollectionPolicyArtistConsent({ ...relay, direct: true }));
});

test("Artist record uses the original content-host record order and execution timestamp rather than deadline", () => {
  const plan = configure(), facts = { registry: a(100), artistId: h(101), signer: a(102), authorityClass: 3n, nonce: max256, observedAt: max64 };
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"), plan.snapshot.chainId, facts.registry, plan.snapshot.coordinator, plan.snapshot.core, plan.snapshot.collectionId, p.ENTROPY_COLLECTION_POLICY_FAMILY, plan.transition.artistContentStateHash, facts.artistId, facts.signer, facts.authorityClass, facts.nonce, facts.observedAt]));
  assert.equal(p.entropyCollectionPolicyArtistRecordHash(plan, facts), expected);
  assert.notEqual(p.entropyCollectionPolicyArtistRecordHash(plan, { ...facts, observedAt: max64 - 1n }), expected);
});

test("both original GovV2 classes retain call/aggregate hashes, exact ABI and timing floors", () => {
  const first = configure();
  for (const plan of [first, p.prepareEntropyCollectionPolicyFreeze(applied(first))]) {
    const w = window(), b = p.entropyCollectionPolicyGovernanceBatch(plan, max256, w), calls = [plan.governanceCall], datas = [plan.targetCall.data];
    assert.equal(b.publicationCall.data, gov.encodeFunctionData("publishGovernanceCallData", [datas]));
    assert.equal(b.scheduleCall.data, gov.encodeFunctionData("scheduleGovernanceBatch", [plan.actionClass, calls, b.scopeHash, b.oldValueHash, b.newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash]));
    assert.equal(b.executionCall.data, gov.encodeFunctionData("executeGovernanceBatch", [b.actionId, calls, datas]));
    for (const call of [plan.targetCall, b.publicationCall, b.scheduleCall, b.executionCall]) assert.equal(call.value, 0n);
    assert.equal(b.publicationKey, keccak256(plan.governanceCall.callDataHash)); assert.notEqual(b.scopeHash, plan.transition.scopeHash);
    assert.deepEqual(p.normalizeEntropyCollectionPolicyGovernanceBatch(b), b);
    p.assertEntropyCollectionPolicyGovernanceWindow(plan.actionClass, w, 100n);
    const delay = plan.actionClass === 1n ? 172800n : 259200n;
    p.assertEntropyCollectionPolicyGovernanceWindow(plan.actionClass, { ...w, notBefore: 100n + delay }, 100n);
    assert.throws(() => p.assertEntropyCollectionPolicyGovernanceWindow(plan.actionClass, { ...w, notBefore: 99n + delay }, 100n));
    assert.throws(() => p.assertEntropyCollectionPolicyGovernanceWindow(plan.actionClass, { ...w, expiresAfter: w.notBefore + 604799n }, 100n));
    assert.throws(() => p.assertEntropyCollectionPolicyGovernanceWindow(plan.actionClass, { ...w, expiresAfter: 100n + 31536001n }, 100n));
  }
});

test("strict exact widths and immutable snapshots refuse input mutation and manufactured verification", () => {
  const s = snapshot(), input = asyncInput(), d = resolution(), plan = configure(s, input, d);
  s.config.collectionSalt = h(888); input.reveal.requestMode = 0n; d.providerCodeHash = h(888);
  assert.equal(plan.snapshot.config.collectionSalt, ZeroHash); assert.equal(plan.input.reveal.requestMode, 1n); assert.equal(plan.resolution.providerCodeHash, h(12));
  assert.throws(() => { plan.next.entry.revision = 100n; }); assert.throws(() => { plan.input.reveal.declared = false; });
  for (const patch of [{ mode: 3n }, { securityClass: 2n }, { renderRequirement: 2n }, { timeoutBlocks: 1n << 64n }, { maxFreshRecoveryAttempts: 65536n }, { provider: "0x01" }, { publicRequests: 1n }, { injected: true }]) assert.throws(() => p.normalizeEntropyCollectionPolicyInput({ ...asyncInput(), ...patch }));
  for (const patch of [{ chainId: 1 }, { collectionMintedEver: max256 + 1n }, { providerEpoch: 1n << 32n }, { collectionExists: 1n }, { extra: true }]) assert.throws(() => p.normalizeEntropyCollectionPolicySnapshot({ ...snapshot(), ...patch }));
  for (const patch of [{ factsVerified: true }, { targetCall: { ...plan.targetCall, value: 1n } }, { next: { ...plan.next, providerEpoch: 99n } }, { transition: { ...plan.transition, artistContentStateHash: plan.next.entry.policyHash } }]) assert.throws(() => p.normalizeEntropyCollectionPolicyPlan({ ...plan, ...patch }));
  assert.deepEqual(p.normalizeEntropyCollectionPolicyPlan(plan), plan);
});
