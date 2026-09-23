import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as client from "../dist/current-entropy-collection-policy.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-entropy-collection-policy-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([k, v]) => [k, new Interface(v)]));
const coder = AbiCoder.defaultAbiCoder(), hash = (types, values) => keccak256(coder.encode(types, values));
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`), clone = structuredClone;
const source = name => fixture.sourceTexts[`smart-contracts/domains/entropy/${name}.sol`];
const artistSource = name => fixture.sourceTexts[`smart-contracts/domains/artist/${name}.sol`];
const inputType = abi.policy.getFunction("configureCollectionEntropyPolicy").inputs[1];
const recordType = abi.policy.getFunction("collectionEntropyPolicy").outputs[0];
const configType = ParamType.from({ type: "tuple", components: abi.entropy.getFunction("collectionEntropyConfig").outputs });
const revealType = abi.entropy.getFunction("collectionRevealPolicy").outputs[0];
const recoveryType = abi.entropy.getFunction("collectionFreshRecovery").outputs[0];
const callsType = abi.executor.getFunction("scheduleGovernanceBatch").inputs[1];
const identityType = abi.governanceIdentity.getFunction("governanceActionId").inputs[0];
const family = id("6529STREAM_ENTROPY_CONFIGURATION_V1");
const coords = s => Object.fromEntries(["chainId", "coordinator", "core", "governanceExecutor", "collectionId"].map(k => [k, s[k]]));
const state = s => Object.fromEntries(["config", "providerEpoch", "reveal", "recovery", "entry"].map(k => [k, s[k]]));
const content = (policyHash, frozen) => hash(["bytes32", "bytes32", "bool"], [family, policyHash, frozen]);
function sample() {
  const snapshot = { chainId: (1n << 230n) + 1n, coordinator: address(10), core: address(20), governanceExecutor: address(30), collectionId: (1n << 250n) + 3n,
    config: { provider: ZeroAddress, publicRequests: false, locked: false, timeoutBlocks: 0n, providerConfigHash: ZeroHash, providerCodeHash: ZeroHash, collectionSalt: ZeroHash },
    providerEpoch: 0n, reveal: { declared: false, requestMode: 0n, revealOwnerRole: ZeroHash, requestSLOBlocks: 0n, revealFeePerTokenWei: 0n },
    recovery: { policyId: ZeroHash, policyHash: ZeroHash, maxFreshRecoveryAttempts: 0n, revision: 0n, lastActionId: ZeroHash },
    entry: { revision: 0n, mode: 0n, securityClass: 0n, renderRequirement: 0n, policyHash: ZeroHash, lastActionId: ZeroHash, artistConsentRecord: ZeroHash },
    collectionExists: true, collectionFrozen: false, collectionMintedEver: 0n, revealEscrow: 0n };
  const input = { mode: 2n, securityClass: 0n, renderRequirement: 0n, provider: address(40), collectionSalt: id("salt"), publicRequests: true, timeoutBlocks: 123n,
    reveal: { declared: true, requestMode: 1n, revealOwnerRole: id("ROLE_ENTROPY_REVEAL_OWNER"), requestSLOBlocks: 456n, revealFeePerTokenWei: (1n << 180n) + 7n },
    maxFreshRecoveryAttempts: 2n, recoveryPolicyId: id("frozen recovery ID") };
  const resolution = { providerCodeHash: id("provider runtime"), providerConfigHash: id("provider configuration"), recoveryPolicyHash: id("frozen recovery commitment") };
  return { snapshot, input, resolution };
}
function semantic(c, s) {
  const { config: p, reveal: r, recovery: b, entry: e } = s;
  return hash(["bytes32", "uint256", "address", "address", "uint256", "uint8", "uint8", "uint8", "address", "bytes32", "bytes32", "uint32", "bytes32", "bool", "uint64", "bool", "uint8", "bytes32", "uint64", "bytes32", "bytes32", "uint16"],
    [id("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"), c.chainId, c.coordinator, c.core, c.collectionId, e.mode, e.securityClass, e.renderRequirement, p.provider, p.providerCodeHash, p.providerConfigHash, s.providerEpoch, p.collectionSalt, p.publicRequests, p.timeoutBlocks,
      r.declared, r.requestMode, r.revealOwnerRole, r.requestSLOBlocks, b.policyId, b.policyHash, b.maxFreshRecoveryAttempts]);
}
function scope(c, kind) {
  return hash(["bytes32", "uint256", "address", "address", "uint256", "bytes4"], [id("6529STREAM_ENTROPY_COLLECTION_POLICY_SCOPE_V1"), c.chainId, c.coordinator, c.core, c.collectionId,
    abi.policy.getFunction(kind === "configure" ? "configureCollectionEntropyPolicy" : "freezeCollectionEntropyPolicy").selector]);
}
function stateHash(scope, s) {
  const { recovery: r, entry: e } = s;
  return hash(["bytes32", "bytes32", configType, "uint32", revealType, "bytes32", "bytes32", "uint16", "uint64", "uint64", "uint8", "uint8", "uint8", "bytes32"],
    [id("6529STREAM_ENTROPY_COLLECTION_POLICY_STATE_V1"), scope, s.config, s.providerEpoch, s.reveal, r.policyId, r.policyHash, r.maxFreshRecoveryAttempts, r.revision, e.revision, e.mode, e.securityClass, e.renderRequirement, e.policyHash]);
}
function nextState(s, p, d) {
  const changedRecovery = s.recovery.policyId !== p.recoveryPolicyId || s.recovery.policyHash !== d.recoveryPolicyHash || s.recovery.maxFreshRecoveryAttempts !== p.maxFreshRecoveryAttempts;
  const changedProvider = s.config.provider !== p.provider || s.config.providerConfigHash !== d.providerConfigHash;
  const next = { config: { provider: p.provider, publicRequests: p.publicRequests, locked: false, timeoutBlocks: p.timeoutBlocks, providerConfigHash: d.providerConfigHash, providerCodeHash: d.providerCodeHash, collectionSalt: p.collectionSalt },
    reveal: clone(p.reveal), providerEpoch: s.providerEpoch + (changedProvider || changedRecovery ? 1n : 0n),
    recovery: { policyId: p.recoveryPolicyId, policyHash: d.recoveryPolicyHash, maxFreshRecoveryAttempts: p.maxFreshRecoveryAttempts, revision: s.recovery.revision + (changedRecovery ? 1n : 0n), lastActionId: s.recovery.lastActionId },
    entry: { ...s.entry, revision: s.entry.revision + 1n, mode: p.mode, securityClass: p.securityClass, renderRequirement: p.renderRequirement } };
  next.entry.policyHash = semantic(s, next); return next;
}
function legacy(c, s) {
  const p = s.config, r = s.reveal, b = s.recovery;
  if (s.entry.revision !== 0n || p.provider === ZeroAddress || !r.declared) return ZeroHash;
  const salt = hash(["bytes32", "uint256", "address", "address", "uint256", "bytes32"], [id("6529STREAM_ENTROPY_COLLECTION_SALT_V1"), c.chainId, c.coordinator, c.core, c.collectionId, p.collectionSalt]);
  const provider = hash(["bytes32", "address", "bytes32", "uint32", "bytes32", "bytes32", "bool", "uint64"], [id("6529STREAM_ENTROPY_SINGLE_PROVIDER_POLICY_V1"), p.provider, p.providerCodeHash, s.providerEpoch, p.providerConfigHash, salt, p.publicRequests, p.timeoutBlocks]);
  const reveal = hash(["bytes32", "uint8", "bytes32", "uint64"], [id("6529STREAM_ENTROPY_DECLARED_REVEAL_POLICY_V1"), r.requestMode, r.revealOwnerRole, r.requestSLOBlocks]);
  return b.maxFreshRecoveryAttempts === 0n
    ? hash(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32"], [id("6529STREAM_ENTROPY_FINALITY_POLICY_V1"), c.chainId, c.coordinator, c.core, c.collectionId, id(s.providerEpoch === 1n ? "6529STREAM_ENTROPY_EPOCH1_NO_FRESH_RECOVERY_V1" : "6529STREAM_ENTROPY_PREMINT_EPOCHS_NO_FRESH_RECOVERY_V1"), provider, reveal])
    : hash(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "uint16"], [id("6529STREAM_ENTROPY_FINALITY_FRESH_POLICY_V1"), c.chainId, c.coordinator, c.core, c.collectionId, provider, reveal, b.policyId, b.policyHash, b.maxFreshRecoveryAttempts]);
}

test("policy fixture retains separate compiler provenance and exact source hashes", () => {
  assert.equal(fixture.sourceCommit, "d7fb42128cdef9dd9716d1f955ee3aba610f085b"); assert.equal(fixture.sourceCount, 1034);
  assert.equal(fixture.inputSha256, "31585c207bf1a77e652c9bd2f463dc2375a56a50cf08ad6db67e461ef47a7027");
  assert.equal(fixture.outputSha256, "9ef754a4cdfc8f80d02e646ee39e6229f01639d9558608ca90c6c6df144389c6");
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 533);
  assert.equal(Object.keys(fixture.sourceHashes).length, 419); assert.equal(Object.keys(fixture.sourceTexts).length, 51);
  assert.equal(Object.keys(fixture.governanceWitness.sourceHashes).length, 35);
  assert.equal(fixture.governanceWitness.inputSha256, "dc9032a36b5a9d54c9a6f75259ad15057131dede213bbb6a315f2129154c8f13");
  assert.equal(fixture.selections.executor.capture, "governance"); assert.equal(fixture.selections.entropy.capture, "policy");
  for (const [path, text] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(text).digest("hex"), fixture.sourceHashes[path]);
  for (const [path, expected] of Object.entries(fixture.governanceWitness.sourceHashes)) assert.equal(fixture.sourceHashes[path], expected);
});

test("five selectors, twelve-word read and public tuples match original compiler witnesses", () => {
  const expected = { collectionEntropyPolicy: "0x48ff96eb", collectionEntropyPolicyTransition: "0xd0782f94", configureCollectionEntropyPolicy: "0xe6781f9e", freezeCollectionEntropyPolicy: "0x58173aef", freezeCollectionEntropyPolicyTransition: "0x636b6bef" };
  const actual = new Interface(client.CURRENT_ENTROPY_COLLECTION_POLICY_ABI); let interfaceId = 0n;
  for (const [name, selector] of Object.entries(expected)) {
    assert.equal(actual.getFunction(name).selector, selector); assert.equal(abi.policy.getFunction(name).selector, selector); interfaceId ^= BigInt(selector);
  }
  assert.equal(`0x${interfaceId.toString(16).padStart(8, "0")}`, client.ENTROPY_COLLECTION_POLICY_INTERFACE_ID);
  assert.equal(recordType.components.length, 12);
  for (const [name, type] of [["INPUT", inputType], ["RECORD", recordType], ["CONFIG", configType], ["REVEAL", revealType], ["RECOVERY", recoveryType], ["GOVERNANCE_CALL", callsType.arrayChildren]]) {
    assert.equal(ParamType.from(client[`ENTROPY_COLLECTION_POLICY_${name}_TUPLE`]).format("sighash"), type.format("sighash"));
  }
  const fields = source("StreamEntropyCollectionPolicyState").match(/struct Entry\s*\{([^}]+)\}/)[1];
  assert.deepEqual([...fields.matchAll(/(?:uint64|P\.Mode|P\.SecurityClass|P\.RenderRequirement|bytes32)\s+(\w+);/g)].map(m => m[1]), ["revision", "mode", "securityClass", "renderRequirement", "policyHash", "lastActionId", "artistConsentRecord"]);
  for (const name of ["CollectionEntropyPolicyConfigured", "CollectionEntropyPolicyFrozen", "TokenEntropyPolicyRegistered"]) assert.equal(actual.getEvent(name).format("full"), abi.policy.getEvent(name).format("full"));
});

test("configure reconstructs independent content, state, scope and exact fourth-word Artist identity", () => {
  const { snapshot: s, input: p, resolution: d } = sample(), next = nextState(s, p, d), key = scope(s, "configure");
  const plan = client.prepareEntropyCollectionPolicyConfigure(s, p, d);
  assert.deepEqual(plan.next, next);
  assert.deepEqual(plan.transition, { scopeHash: key, oldValueHash: stateHash(key, s), newValueHash: stateHash(key, next), artistContentStateHash: content(next.entry.policyHash, false) });
  assert.equal(plan.targetCall.data, abi.policy.encodeFunctionData("configureCollectionEntropyPolicy", [s.collectionId, p]));
  assert.equal(plan.previewCall.data, abi.policy.encodeFunctionData("collectionEntropyPolicyTransition", [s.collectionId, p]));
  assert.equal(plan.actionClass, 1n); assert.equal(plan.factsVerified, false);
  assert.notEqual(plan.transition.artistContentStateHash, plan.transition.newValueHash); assert.notEqual(plan.transition.artistContentStateHash, next.entry.policyHash);
  for (const field of ["core", "coordinator", "collectionId", "chainId"]) {
    const other = { ...coords(s), [field]: typeof s[field] === "bigint" ? s[field] + 1n : address(999) };
    assert.notEqual(client.entropyCollectionPolicyHash(other, next), next.entry.policyHash, field);
  }
});

test("legacy public ASYNC record stays distinct from its zero private entry and all original domains", () => {
  const { snapshot: empty, input: p, resolution: d } = sample();
  const emptyRead = client.entropyCollectionPolicyRecord(empty);
  assert.equal(emptyRead.configured, false); assert.equal(emptyRead.mode, 2n); assert.equal(emptyRead.contentStateHash, content(ZeroHash, false));
  assert.notEqual(emptyRead.contentStateHash, ZeroHash); assert.deepEqual(client.entropyCollectionPolicyEntryFromRecord(emptyRead), empty.entry);
  const s = { ...empty, ...nextState(empty, p, d), entry: empty.entry };
  for (const epoch of [1n, 2n, 0xffffffffn]) for (const fresh of [false, true]) {
    const observed = { ...s, providerEpoch: epoch, recovery: fresh ? s.recovery : empty.recovery };
    const expected = legacy(s, observed), record = client.entropyCollectionPolicyRecord(observed);
    assert.equal(client.entropyCollectionPolicyLegacyHash(coords(s), state(observed)), expected); assert.equal(record.policyHash, expected);
    assert.equal(record.mode, 2n); assert.deepEqual(client.entropyCollectionPolicyEntryFromRecord(record), empty.entry);
    const key = scope(s, "configure"); assert.notEqual(stateHash(key, observed), stateHash(key, { ...observed, entry: { ...empty.entry, mode: 2n, policyHash: record.policyHash } }));
    const raw = coder.encode([recordType], [record]); assert.equal(client.encodeEntropyCollectionPolicyRecord(record), raw); assert.deepEqual(client.decodeEntropyCollectionPolicyRecord(raw), record);
    assert.throws(() => client.decodeEntropyCollectionPolicyRecord(raw + "00".repeat(32)));
  }
  const explicit = { ...s, entry: { ...s.entry, revision: 1n, policyHash: id("explicit") } };
  assert.equal(client.entropyCollectionPolicyLegacyHash(coords(explicit), state(explicit)), ZeroHash);
  assert.match(source("StreamEntropyCoordinatorReads"), /PolicyState\.explicitPolicy\(collectionId\)/);
});

test("fee and epoch semantics preserve code-only changes, recovery revisions and terminal freeze", () => {
  const { snapshot: initial, input: p, resolution: d } = sample(), s = { ...initial, ...nextState(initial, p, d) };
  const fee = clone(s); fee.reveal.revealFeePerTokenWei += 1n;
  assert.equal(semantic(s, fee), s.entry.policyHash); assert.notEqual(stateHash(scope(s, "configure"), fee), stateHash(scope(s, "configure"), s));
  assert.throws(() => client.prepareEntropyCollectionPolicyConfigure(s, { ...p, reveal: fee.reveal }, d), /fee-only|no-op/);
  const code = client.prepareEntropyCollectionPolicyConfigure(s, p, { ...d, providerCodeHash: id("new runtime only") });
  assert.equal(code.next.providerEpoch, s.providerEpoch); assert.equal(code.next.recovery.revision, s.recovery.revision);
  const changed = client.prepareEntropyCollectionPolicyConfigure(s, { ...p, provider: address(41), recoveryPolicyId: id("different recovery") }, { ...d, recoveryPolicyHash: id("different recovery hash") });
  assert.equal(changed.next.providerEpoch, s.providerEpoch + 1n); assert.equal(changed.next.recovery.revision, s.recovery.revision + 1n);
  const freeze = client.prepareEntropyCollectionPolicyFreeze(s), key = scope(s, "freeze"), expected = { ...state(s), config: { ...s.config, locked: true }, entry: { ...s.entry, revision: s.entry.revision + 1n } };
  assert.deepEqual(freeze.next, expected); assert.equal(freeze.actionClass, 2n);
  assert.deepEqual(freeze.transition, { scopeHash: key, oldValueHash: stateHash(key, s), newValueHash: stateHash(key, expected), artistContentStateHash: content(s.entry.policyHash, true) });
  assert.equal(freeze.targetCall.data, abi.policy.encodeFunctionData("freezeCollectionEntropyPolicy", [s.collectionId]));
  assert.notEqual(freeze.transition.artistContentStateHash, content(s.entry.policyHash, false));
  assert.equal(freeze.next.entry.policyHash, s.entry.policyHash); assert.equal(freeze.next.providerEpoch, s.providerEpoch);
});

test("DISABLED is explicit, ASYNC NOT_REQUIRED retains reveal fee and INSTANT never falls back", () => {
  const { snapshot: s, input: p, resolution: d } = sample();
  const disabled = { ...p, mode: 0n, renderRequirement: 1n, provider: ZeroAddress, collectionSalt: ZeroHash, publicRequests: false, timeoutBlocks: 0n,
    reveal: s.reveal, maxFreshRecoveryAttempts: 0n, recoveryPolicyId: ZeroHash };
  const zero = { providerCodeHash: ZeroHash, providerConfigHash: ZeroHash, recoveryPolicyHash: ZeroHash };
  for (const securityClass of [0n, 1n]) {
    const plan = client.prepareEntropyCollectionPolicyConfigure(s, { ...disabled, securityClass }, zero);
    assert.equal(plan.next.providerEpoch, 0n); assert.equal(client.entropyCollectionPolicyRecord({ ...s, ...plan.next }).configured, true);
    assert.throws(() => client.prepareEntropyCollectionPolicyConfigure(s, { ...p, mode: 1n, securityClass }, d), client.EntropyCollectionPolicyUnsupportedModeError);
  }
  assert.throws(() => client.prepareEntropyCollectionPolicyConfigure({ ...s, revealEscrow: 1n }, disabled, zero));
  assert.throws(() => client.prepareEntropyCollectionPolicyConfigure(s, { ...disabled, reveal: { ...s.reveal, declared: true } }, zero));
  const nr = client.prepareEntropyCollectionPolicyConfigure(s, { ...p, renderRequirement: 1n }, d);
  assert.equal(nr.next.reveal.revealFeePerTokenWei, p.reveal.revealFeePerTokenWei); assert.equal(nr.next.reveal.declared, true);
  assert.throws(() => client.prepareEntropyCollectionPolicyConfigure(s, { ...p, renderRequirement: 1n, reveal: s.reveal }, d));
  assert.throws(() => client.prepareEntropyCollectionPolicyConfigure({ ...s, collectionMintedEver: 1n }, p, d));
  assert.throws(() => client.prepareEntropyCollectionPolicyFreeze(s));
});

test("Artist signing, direct caller semantics and observed-time record keep original operation17 domains", () => {
  const { snapshot: s, input: p, resolution: d } = sample(), plan = client.prepareEntropyCollectionPolicyConfigure(s, p, d);
  const registry = address(50), signer = address(60), caller = address(70), auth = { nonce: (1n << 240n) + 3n, deadline: 900000n, signature: "0x1234" };
  const prepared = client.prepareEntropyCollectionPolicyArtistConsent(plan, registry, caller, signer, auth);
  const fields = "address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline".split(",").map(v => { const [type, name] = v.split(" "); return { type, name }; });
  const message = { core: s.core, metadataContract: s.coordinator, collectionId: s.collectionId, familyId: family, newStateHash: plan.transition.artistContentStateHash, nonce: auth.nonce, deadline: auth.deadline };
  const expectedDigest = TypedDataEncoder.hash({ name: "6529StreamArtistRegistry", version: "1", chainId: s.chainId, verifyingContract: registry }, { StreamArtistContentConsent: fields }, message);
  assert.equal(prepared.payload.digest, expectedDigest); assert.equal(prepared.direct, false);
  const terms = [s.collectionId, s.coordinator, family, message.newStateHash];
  assert.equal(prepared.call.data, abi.artist.encodeFunctionData("recordContentConsent", [terms, [auth.nonce, auth.deadline, auth.signature]]));
  assert.equal(prepared.digestCall.data, abi.artist.encodeFunctionData("contentConsentDigest", [terms, [auth.nonce, auth.deadline, "0x"]]));
  assert.equal(client.prepareEntropyCollectionPolicyArtistConsent(plan, registry, signer, signer, { ...auth, signature: "0x" }).direct, true);
  assert.equal(client.prepareEntropyCollectionPolicyArtistConsent(plan, registry, caller, signer, { ...auth, signature: "0x" }).direct, false);
  const facts = { registry, artistId: id("Artist"), signer, authorityClass: 3n, nonce: auth.nonce, observedAt: 700000n };
  const expectedRecord = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"), s.chainId, registry, s.coordinator, s.core, s.collectionId, family, message.newStateHash, facts.artistId, signer, 3n, auth.nonce, facts.observedAt]);
  assert.equal(client.entropyCollectionPolicyArtistRecordHash(plan, facts), expectedRecord);
  assert.notEqual(client.entropyCollectionPolicyArtistRecordHash(plan, { ...facts, observedAt: auth.deadline }), expectedRecord);
  assert.match(artistSource("StreamArtistContentOperations"), /T\.ActionContext\(17, actor, before_\[2\]\)/);
  assert.match(artistSource("StreamArtistContentOperations"), /abi\.encode\(b, p, a, proof, current\)/);
});

test("class1 and class2 governance identities retain exact compiler tuples and timing floors", () => {
  const { snapshot: s, input: p, resolution: d } = sample(), configure = client.prepareEntropyCollectionPolicyConfigure(s, p, d), freeze = client.prepareEntropyCollectionPolicyFreeze({ ...s, ...configure.next });
  const nonce = (1n << 220n) + 5n;
  for (const plan of [configure, freeze]) {
    const window = { notBefore: plan.actionClass === 1n ? 172801n : 259201n, expiresAfter: 900000n, reasonHash: id("review"), reasonURI: "ipfs://exact-review", manifestHash: id("manifest") };
    const batch = client.entropyCollectionPolicyGovernanceBatch(plan, nonce, window), calls = [plan.governanceCall];
    const callsHash = hash(["bytes32", callsType], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
    const aggregate = (domain, field) => hash(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, [plan.governanceCall[field]]]);
    const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash"), oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash"), newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
    const identity = { actionClass: plan.actionClass, callsHash, scopeHash, oldValueHash, newValueHash, nonce, notBefore: window.notBefore, expiresAfter: window.expiresAfter, reasonHash: window.reasonHash, manifestHash: window.manifestHash };
    const actionId = hash(["bytes32", "uint256", "address", identityType], ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", s.chainId, s.governanceExecutor, identity]);
    assert.equal(batch.callsHash, callsHash); assert.equal(batch.actionId, actionId); assert.equal(batch.publicationKey, keccak256(keccak256(plan.targetCall.data)));
    assert.equal(batch.publicationCall.data, abi.executor.encodeFunctionData("publishGovernanceCallData", [[plan.targetCall.data]]));
    assert.equal(batch.scheduleCall.data, abi.executor.encodeFunctionData("scheduleGovernanceBatch", [plan.actionClass, calls, scopeHash, oldValueHash, newValueHash, window.notBefore, window.expiresAfter, window.reasonHash, window.reasonURI, window.manifestHash]));
    assert.equal(batch.executionCall.data, abi.executor.encodeFunctionData("executeGovernanceBatch", [actionId, calls, [plan.targetCall.data]]));
    client.assertEntropyCollectionPolicyGovernanceWindow(plan.actionClass, window, 1n);
    assert.throws(() => client.assertEntropyCollectionPolicyGovernanceWindow(plan.actionClass, { ...window, notBefore: window.notBefore - 1n }, 1n));
  }
  assert.match(source("StreamEntropyCollectionPolicy"), /_authorize\(core, authority, id, p, 1\)/);
  assert.match(source("StreamEntropyCollectionPolicy"), /_authorize\(core, authority, id, p, 2\)/);
  assert.match(source("StreamEntropyCollectionPolicy"), /s\.actions\[id\]\[p\.entry\.lastActionId\]/);
  assert.match(source("StreamEntropyCollectionPolicy"), /s\.consents\[p\.entry\.artistConsentRecord\]/);
});
