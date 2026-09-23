import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as instant from "../dist/current-entropy-instant.js";
import * as legacy from "../dist/current-entropy-collection-policy.js";
const pure = { ...legacy, ...instant };
import * as flow from "../dist/current-entropy-instant-workflow.js";
import { createSafeCallPlan } from "../dist/safe-plan.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-entropy-instant-abi.json", import.meta.url)));
const abi = new Interface(Object.values(fixture.abis).flat().filter(v => v.type === "function" || v.type === "event"));
const coder = AbiCoder.defaultAbiCoder();
const addr = n => getAddress(`0x${n.toString(16).padStart(40, "0")}`);
const H = n => id(`entropy-policy-${n}`);
const code = "0x6001600055", codeHash = keccak256(code);
const pin = n => ({ address: addr(n), codeHash });
const components = Array.from({ length: 16 }, (_, n) => pin(100 + n));
const deployment = { chainId: 1n, core: components[9], coordinator: pin(200), moduleRegistry: pin(201),
  governance: pin(202), roleRegistry: pin(203), artist: { chainId: 1n, registry: components[7], coordinator: pin(204), components } };
const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(n => id(`domain:${n}`));
const caller = addr(300), signer = addr(301), provider = addr(302), pointer = addr(303), archivePointer = addr(304);
const binding = { artistId: H("artist"), artistAddress: signer, identityRecordHash: H("identity"), bindingHash: H("binding"), generation: 1n,
  consentMode: 1n, saleConsentScope: 0n, registryImmutabilityElection: 0n, proposer: caller, accepted: true };
const disabled = { mode: 0n, securityClass: 0n, renderRequirement: 1n, provider: ZeroAddress, collectionSalt: ZeroHash,
  publicRequests: false, timeoutBlocks: 0n, reveal: { declared: false, requestMode: 0n, revealOwnerRole: ZeroHash,
    requestSLOBlocks: 0n, revealFeePerTokenWei: 0n }, maxFreshRecoveryAttempts: 0n, recoveryPolicyId: ZeroHash };
const instantInput = { ...disabled, mode: 1n, securityClass: 1n, renderRequirement: 0n, provider, publicRequests: true, collectionSalt: H("salt") };
const initial = { chainId: 1n, core: deployment.core.address, coordinator: deployment.coordinator.address,
  governanceExecutor: deployment.governance.address, collectionId: 1n,
  config: { provider: ZeroAddress, publicRequests: false, locked: false, timeoutBlocks: 0n, providerConfigHash: ZeroHash, providerCodeHash: ZeroHash, collectionSalt: ZeroHash },
  providerEpoch: 0n, reveal: disabled.reveal, recovery: { policyId: ZeroHash, policyHash: ZeroHash, maxFreshRecoveryAttempts: 0n, revision: 0n, lastActionId: ZeroHash },
  entry: { revision: 0n, mode: 0n, securityClass: 0n, renderRequirement: 0n, policyHash: ZeroHash, lastActionId: ZeroHash, artistConsentRecord: ZeroHash },
  collectionExists: true, collectionFrozen: false, collectionMintedEver: 0n, revealEscrow: 0n };
const safe = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const successPlain = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const successIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)"]);
const S = "(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
const B = "(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted)";
const C = "(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
const A = "(uint256 nonce,uint64 time,bytes signature)";
const P = "(address signer,bytes32 digest,bool direct)";

// Compiled-ABI RPC fixture: original eth_call is stubbed, so these tests prove client joins, not native admission.
function setup(base = initial) {
  const states = new Map([[10, structuredClone(base)]]), times = new Map([[10, 1000n]]), calls = [];
  const state = { states, times, calls, overrides: null, codeOverride: null, beforeCall: null,
    published: false, existingFrom: 0, consentRecord: H("record"), consentCapture: null,
    operation: null, receipt: null, tx: null, actionStatus: 1n, actorClass: 1n, actorStatus: 1n,
    nonceConsumed: false, catalogHash: H("catalog"), recoverySteps: [], retained: null, archive: null, evidenceId: null };
  const snap = tag => states.get(tag) ?? states.get(10);
  const time = tag => times.get(tag) ?? 1000n;
  const encode = (f, values) => abi.encodeFunctionResult(f, values);
  const providerApi = {
    async getNetwork() { return { chainId: 1n }; },
    async getBlock(tag) { return { number: tag, hash: H(`block-${tag}`), timestamp: Number(time(tag)) }; },
    async getCode(target, tag) {
      const changed = state.codeOverride?.(target, tag);
      if (changed !== undefined) return changed;
      if (target === pointer && state.operation) return `0x00${coder.encode(["bytes[]"], [[state.operation.prepared.batch.plan.targetCall.data]]).slice(2)}`;
      if (target === archivePointer && state.archive) return `0x00${state.archive.slice(2)}`;
      return code;
    },
    async call(tx) {
      await state.beforeCall?.(tx);
      const parsed = abi.parseTransaction({ data: tx.data });
      assert.ok(parsed, `Known selector ${tx.data.slice(0, 10)}`);
      const { name, args, fragment } = parsed, tag = tx.blockTag, s = snap(tag);
      calls.push({ name, args, to: tx.to, from: tx.from, tag });
      const changed = state.overrides?.(name, args, tx);
      if (changed !== undefined) return typeof changed === "string" ? changed : encode(fragment, changed);
      let out;
      if (name === "supportsInterface") out = [args[0] !== "0xffffffff" && args[0] !== "0x9cd4388e"];
      else if (name === "core") out = [deployment.core.address];
      else if (["authority", "governanceExecutor", "governanceAuthority"].includes(name)) out = [deployment.governance.address];
      else if (name === "roleRegistry") out = [deployment.roleRegistry.address];
      else if (name === "roleRegistryCodeHash") out = [codeHash];
      else if (name === "owner") out = [tx.to === deployment.roleRegistry.address ? deployment.governance.address : caller];
      else if (name === "getSatellitePointer") {
        const target = args[0] === id("ENTROPY_COORDINATOR") ? deployment.coordinator : args[0] === id("ARTIST_REGISTRY") ? deployment.artist.registry : deployment.moduleRegistry;
        out = [target.address, target.codeHash, false, args[0], "0x12345678", deployment.moduleRegistry.address, 1n, H("module"), H("deployment"), 1n];
      } else if (name === "systemManifestBootstrapState") {
        out = fragment.outputs.map(v => v.type === "bool" ? true : v.type === "address" ? caller : v.type === "bytes32" ? H("boot") : 1n);
        out[2] = deployment.roleRegistry.address; out[3] = codeHash;
      } else if (name === "minimumDelay") out = [args[0] === 1n ? 172800n : 259200n];
      else if (name === "governanceActionPolicyState") out = [H("profile"), state.catalogHash, 20n, 0n];
      else if (name === "governanceNonce") out = [tag >= 11 && state.operation?.stage !== "publish" ? 1n : 0n];
      else if (name === "collectionEntropyConfig") out = Object.values(s.config);
      else if (name === "collectionEntropyPolicy") out = [pure.entropyInstantPolicyRecord(s)];
      else if (name === "collectionProviderEpoch") out = [s.providerEpoch];
      else if (name === "collectionRevealPolicy") out = [s.reveal];
      else if (name === "collectionFreshRecovery") out = [s.recovery];
      else if (name === "revealFeeEscrow") out = [s.revealEscrow];
      else if (name === "collectionExists") out = [s.collectionExists];
      else if (name === "collectionFreezeStatus") out = [s.collectionFrozen];
      else if (name === "collectionMintedEver") out = [s.collectionMintedEver];
      else if (name === "artistContentFamilyState") out = [true, pure.entropyInstantPolicyRecord(s).contentStateHash];
      else if (name === "entropyProviderRecord") out = [{ state: 1n, runtimeCodeHash: codeHash, revision: 1n, reasonHash: H("provider-reason"), lastActionId: H("provider-action") }];
      else if (name === "isStreamInstantEntropyProvider") out = [true];
      else if (name === "instantEntropyProfile") out = [1n, pure.ENTROPY_INSTANT_ASSUMPTIONS_HASH];
      else if (name === "streamEntropyProviderFamily") out = [pure.ENTROPY_INSTANT_PROVIDER_FAMILY];
      else if (name === "streamEntropyProviderVersion") out = [pure.ENTROPY_INSTANT_PROVIDER_VERSION];
      else if (name === "streamEntropyProviderConfigHash") out = [H("provider-config")];
      else if (name === "contextIndependentRequestFee") out = [5n];
      else if (name === "freshRecoveryPolicy") out = [{ exists: true, frozen: true, maxFreshRecoveryAttempts: 2n, incidentDeclarerRole: H("role"), reasonSchemaHash: H("reason"), policyManifestHash: H("manifest"), steps: state.recoverySteps }, H("recovery"), 1n, H("recovery-action")];
      else if (name === "collectionEntropyPolicyTransition" || name === "freezeCollectionEntropyPolicyTransition") {
        const p = name.startsWith("freeze") ? pure.prepareEntropyInstantPolicyFreeze(s)
          : pure.prepareEntropyInstantPolicyConfigure(s, legacy.decodeEntropyCollectionPolicyInput(coder.encode([pure.ENTROPY_COLLECTION_POLICY_INPUT_TUPLE], [args[1]])),
            { providerCodeHash: args[1].mode === 1n ? codeHash : ZeroHash, providerConfigHash: args[1].mode === 1n ? H("provider-config") : ZeroHash,
              recoveryPolicyHash: ZeroHash, instantMode: 1n, assumptionsHash: pure.ENTROPY_INSTANT_ASSUMPTIONS_HASH });
        out = Object.values(p.transition);
      } else if (name === "suiteConfiguration") out = [{ registry: deployment.artist.registry.address, archive: components[8].address,
        owners: components.slice(0, 7).map(v => v.address), core: deployment.core.address, mintManager: components[10].address,
        roleRegistry: components[11].address, metadata: components[12].address, primaryResolver: components[13].address,
        royaltyResolver: components[14].address, primaryRevenueClass: H("primary"), validator: components[15].address }];
      else if (name === "deploymentChainId") out = [1n];
      else if (name === "mintManager") out = [components[10].address];
      else if (name === "operationCoordinator") out = [deployment.artist.coordinator.address];
      else if (name === "artistRegistry") out = [deployment.artist.registry.address];
      else if (name === "archiveV2") out = [components[8].address];
      else if (name === "domainId") out = [domains[components.findIndex(v => v.address === tx.to)]];
      else if (name === "artistRegistryCutover") out = [false, ZeroAddress, 0n];
      else if (name === "configurationHash") out = [H("artist-config")];
      else if (name === "gasParameterInfo") out = [500000n, 100000n, 2n, 1n];
      else if (name === "binding") out = [binding];
      else if (name === "attributionState") out = [2n, 1n];
      else if (name === "authorityState") out = [signer, state.actorClass, state.actorStatus, binding.identityRecordHash];
      else if (name === "bindingTerms") out = [{ collaboratorSetHash: H("collabs"), capabilityPolicySetHash: H("caps"), mode: 0n, threshold: 0n, count: 0n }];
      else if (name === "acceptedCount") out = [0n];
      else if (name === "collectionArtistState") out = [2n, 1n, binding.artistId, state.actorStatus, binding.bindingHash];
      else if (name === "currentAuthorityCapabilities") out = [{ authorityAddress: signer, authorityClass: state.actorClass, status: state.actorStatus, effectiveCapabilities: 128n, activationRecordHash: H("activation") }];
      else if (name === "contentConsentDigest") out = [state.consentCapture.consent.payload.digest];
      else if (name === "artistAuthorizationState") out = [{ digestObserved: state.nonceConsumed && tag > 10, digestRevoked: false,
        nonceConsumed: state.nonceConsumed && tag > 10, nonceRevoked: false, nextUnusedNonce: 1n }];
      else if (name === "recordContentConsent") out = [pure.entropyInstantPolicyArtistRecordHash(state.consentCapture.consent.plan,
        { registry: deployment.artist.registry.address, artistId: binding.artistId, signer, authorityClass: state.actorClass,
          nonce: state.consentCapture.consent.authorization.nonce, observedAt: time(tag) })];
      else if (name === "contentConsentEvidenceForHost") out = [state.consentRecord];
      else if (name === "contentConsentRecord") out = [state.retained ?? { recordHash: state.consentRecord, artistId: binding.artistId,
        bindingGeneration: 1n, terms: { collectionId: 1n, metadataContract: deployment.coordinator.address,
          familyId: legacy.ENTROPY_COLLECTION_POLICY_FAMILY, newStateHash: state.operation.prepared.batch.plan.transition.artistContentStateHash }, authorityClass: 1n }];
      else if (name === "isProposer") out = [false];
      else if (name === "publishedCallData") out = [state.published && tag >= state.existingFrom ? pointer : ZeroAddress];
      else if (name === "publishGovernanceCallData") out = [pointer];
      else if (name === "scheduleGovernanceBatch") out = [state.operation.prepared.batch.actionId];
      else if (name === "executeGovernanceBatch") out = [];
      else if (name === "scheduledCallData") out = [[state.operation.prepared.batch.plan.targetCall.data]];
      else if (name === "scheduledCallDataPointer") out = [pointer];
      else if (name === "governanceAction") {
        const b = state.operation.prepared.batch;
        out = [{ status: state.actionStatus, actionClass: b.plan.actionClass, target: b.plan.targetCall.to, value: 0n,
          selector: b.plan.governanceCall.selector, callHash: b.callsHash, scopeHash: b.scopeHash, oldValueHash: b.oldValueHash,
          newValueHash: b.newValueHash, notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter, proposer: caller,
          executor: state.actionStatus === 3n ? caller : ZeroAddress, canceller: ZeroAddress, vetoer: ZeroAddress,
          reasonHash: b.window.reasonHash, reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash }];
      } else if (name === "terminalFreezeVetoGuardianSet") out = [deployment.roleRegistry.address,
        keccak256(coder.encode(["bytes32", "bytes32"], [id("ROLE_TERMINAL_FREEZE_VETO"), args[0]])), 0n, id("ROLE_TERMINAL_FREEZE_VETO"), 2n, 0n];
      else if (name === "roleHolderCount") out = [args[0] === id("ROLE_TERMINAL_FREEZE_VETO") ? 2n : 0n];
      else if (name === "isRoleRedundant") out = [true];
      else if (name === "terminalFreezeGuardianConfigCommitment") out = [H("guardians")];
      else if (name === "artistEvidenceMetadataV2") out = [keccak256(state.archive), archivePointer, BigInt((state.archive.length - 2) / 2), 11n];
      else if (name === "artistEvidenceBytesV2") out = [state.archive];
      else throw Error(`Unhandled ${name}`);
      return encode(fragment, out);
    },
    async getTransactionReceipt() { return state.receipt; },
    async getTransaction() { return state.tx; }
  };
  return { p: providerApi, s: state, snap, time };
}
async function inspected(f, input = instantInput, kind = "configure") {
  const c = await flow.captureEntropyInstantPolicy(f.p, deployment, 1n, { blockTag: 10 });
  const i = await flow.inspectEntropyInstantPolicy(f.p, c, kind === "freeze" ? { kind } : { kind, input });
  return i;
}
async function consent(f, i, actor = signer, signature = "0x", nonce = 1n) {
  const q = pure.prepareEntropyInstantPolicyArtistConsent(i.plan, deployment.artist.registry.address, actor, signer, { nonce, deadline: 1000000n, signature });
  f.s.consentCapture = { consent: q };
  const c = await flow.captureEntropyInstantPolicyConsent(f.p, i, q);
  f.s.consentCapture = c;
  return c;
}
function operation(f, i, stage = "publish") {
  const delay = i.plan.kind === "freeze" ? 259200n : 172800n;
  const prepared = flow.prepareEntropyInstantPolicyGovernance(i, caller, { notBefore: 1000n + delay,
    expiresAfter: 1000n + delay + 604800n, reasonHash: H("reason"), reasonURI: "ipfs://Policy", manifestHash: H("manifest") });
  const o = flow.prepareEntropyInstantPolicyOperation(prepared, stage, caller);
  f.s.operation = o;
  return o;
}
function event(name, values, target, tag = 11, iface = abi) {
  return { address: target, ...iface.encodeEventLog(iface.getEvent(name), values), index: 0, removed: false,
    blockNumber: tag, blockHash: H(`block-${tag}`), transactionHash: H("transaction") };
}
function mined(f, call, actor, logs, execution = "direct", tag = 11, indexed = false) {
  if (execution === "safe") logs.push(event("ExecutionSuccess", [H("safeTx"), 0n], actor, tag, indexed ? successIndexed : successPlain));
  logs.forEach((v, i) => { v.index = i; });
  const data = execution === "direct" ? call.data : safe.encodeFunctionData("execTransaction", [call.to, call.value, call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x"]);
  f.s.tx = { hash: H("transaction"), chainId: 1n, from: execution === "direct" ? actor : addr(900), to: execution === "direct" ? call.to : actor,
    data, value: execution === "direct" ? call.value : 0n, blockNumber: tag, blockHash: H(`block-${tag}`) };
  f.s.receipt = { ...f.s.tx, status: 1, logs };
  return { transactionHash: H("transaction"), execution };
}
function governanceLogs(f, o, tag = 11) {
  const b = o.prepared.batch, d = deployment.governance.address;
  if (o.stage === "publish") return [event("GovernanceCallDataPublished", [1n, b.publicationKey, pointer, caller], d, tag)];
  const common = [1n, b.actionId, b.plan.actionClass, b.plan.targetCall.to, 0n, b.plan.governanceCall.selector,
    b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash];
  const logs = [];
  if (o.stage === "schedule") {
    if (b.plan.kind === "freeze") {
      logs.push(event("TerminalFreezeActionMembershipUpdated", [1n, b.plan.transition.scopeHash, b.actionId, caller, true, 1n, true, b.window.notBefore, 0n, 1n], d, tag));
      logs.push(event("TerminalFreezeGuardianConfigCommitted", [1n, b.actionId, H("guardians")], d, tag));
    }
    logs.push(event("GovernanceActionScheduled", [...common, b.window.notBefore, b.window.expiresAfter, b.nonce, caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash], d, tag));
  } else {
    const next = structuredClone(b.plan.next);
    next.entry.lastActionId = b.actionId; next.entry.artistConsentRecord = f.s.consentRecord;
    if (next.recovery.revision !== b.plan.snapshot.recovery.revision) next.recovery.lastActionId = b.actionId;
    f.s.states.set(tag, { ...structuredClone(b.plan.snapshot), ...next });
    if (b.plan.kind === "freeze") {
      logs.push(event("TerminalFreezeActionMembershipUpdated", [1n, b.plan.transition.scopeHash, b.actionId, caller, false, 3n, true, b.window.notBefore, 0n, 0n], d, tag));
      logs.push(event("CollectionEntropyPolicyFrozen", [2n, 1n, next.entry.policyHash, next.entry.revision, b.actionId, f.s.consentRecord], deployment.coordinator.address, tag));
    } else logs.push(event("CollectionEntropyPolicyConfigured", [2n, 1n, next.entry.policyHash, next.entry.revision,
      next.providerEpoch, b.plan.input, next.config.providerCodeHash, next.config.providerConfigHash, next.recovery.policyHash,
      b.actionId, f.s.consentRecord], deployment.coordinator.address, tag));
    logs.push(event("GovernanceActionExecuted", [...common, caller, b.window.manifestHash], d, tag));
  }
  logs.push(event("GovernanceActionPolicyValidated", [1n, b.actionId, o.stage === "schedule" ? 1n : 2n, H("profile"), H("catalog")], d, tag));
  return logs;
}
function consentLogs(f, c) {
  const q = c.consent, terms = { collectionId: 1n, metadataContract: deployment.coordinator.address,
    familyId: legacy.ENTROPY_COLLECTION_POLICY_FAMILY, newStateHash: c.inspection.plan.transition.artistContentStateHash };
  const record = pure.entropyInstantPolicyArtistRecordHash(q.plan, { registry: q.registry, artistId: binding.artistId, signer,
    authorityClass: f.s.actorClass, nonce: q.authorization.nonce, observedAt: 1000n });
  f.s.consentRecord = record;
  f.s.retained = { recordHash: record, artistId: binding.artistId, bindingGeneration: 1n, terms, authorityClass: f.s.actorClass };
  f.s.nonceConsumed = true;
  const before = domains.map((domainId, n) => (0x57 & (1 << n)) ? { domainId, revision: 4n, stateRoot: H(`before-${n}`), recordChainTip: H(`tip-${n}`) }
    : { domainId: ZeroHash, revision: 0n, stateRoot: ZeroHash, recordChainTip: ZeroHash });
  const after = before.map((v, n) => (0x44 & (1 << n)) ? { ...v, revision: 5n, stateRoot: H(`after-${n}`), recordChainTip: H(`next-tip-${n}`) } : v);
  const payload = coder.encode([B, C, A, P, "bytes32"], [binding, terms, { nonce: q.authorization.nonce, time: q.authorization.deadline, signature: q.authorization.signature },
    { signer, digest: q.payload.digest, direct: q.direct }, c.currentContentStateHash]);
  f.s.archive = coder.encode(["uint16", "bytes32", "uint16", "address", "bytes32", `${S}[7]`, `${S}[7]`, "bytes"], [1n, H("artist-config"), 17n, q.caller, record, before, after, payload]);
  f.s.evidenceId = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), 1n, q.registry, deployment.artist.coordinator.address, 17n, q.caller, record]));
  return [event("ArtistContentConsentRecorded", [1n, 1n, terms.familyId, signer, terms.newStateHash, f.s.actorClass, q.authorization.nonce, 1000n, record], components[6].address),
    event("ArtistContentRecordContext", [1n, record, terms.metadataContract, binding.artistId], components[6].address),
    event("ArtistArchiveEvidenceAppendedV2", [f.s.evidenceId, 1n, keccak256(f.s.archive), archivePointer, BigInt((f.s.archive.length - 2) / 2)], components[8].address)];
}

test("twelve-word legacy read and separate INSTANT transition retain raw zero Entry and fourth Artist word", async () => {
  const f = setup(), i = await inspected(f);
  assert.equal(i.capture.record.mode, 2n);
  assert.equal(i.capture.record.configured, false);
  assert.equal(i.capture.snapshot.entry.mode, 0n);
  assert.equal(i.plan.next.providerEpoch, 1n);
  assert.notEqual(i.plan.transition.newValueHash, i.plan.transition.artistContentStateHash);
  assert.ok(Object.isFrozen(i.capture.deployment.artist.components[0]));
  const forged = structuredClone(i.capture);
  forged.snapshot.entry.revision = "0n";
  await assert.rejects(flow.inspectEntropyInstantPolicy(f.p, forged, { kind: "configure", input: instantInput }));
});

test("INSTANT mutable prerequisites and unsupported modes, security, reveal/recovery fail closed", async () => {
  for (const patch of [{ collectionMintedEver: 1n }, { collectionFrozen: true }, { revealEscrow: 1n }, { config: { ...initial.config, locked: true } }]) {
    await assert.rejects(inspected(setup({ ...initial, ...patch })));
  }
  await assert.rejects(inspected(setup(), disabled));
  await assert.rejects(inspected(setup(), { ...instantInput, securityClass: 0n }));
  await assert.rejects(inspected(setup(), { ...instantInput, mode: 2n }));
  await assert.rejects(inspected(setup(), { ...instantInput, maxFreshRecoveryAttempts: 1n }));
  await assert.rejects(inspected(setup(), { ...instantInput, reveal: { ...disabled.reveal, declared: true } }));
});


function explicitState() {
  const next = pure.prepareEntropyInstantPolicyConfigure(initial, instantInput, { providerCodeHash: codeHash, providerConfigHash: H("provider-config"), recoveryPolicyHash: ZeroHash, instantMode: 1n, assumptionsHash: pure.ENTROPY_INSTANT_ASSUMPTIONS_HASH }).next;
  return { ...initial, ...next, entry: { ...next.entry, lastActionId: H("prior-action"), artistConsentRecord: H("prior-consent") } };
}
test("freeze preserves hash/epoch/reveal despite provider retirement and requires separate frozen op17 target", async () => {
  const f = setup(explicitState());
  f.s.overrides = name => { if (name === "entropyProviderRecord" || name === "contextIndependentRequestFee") throw Error("Freeze must not read live provider"); };
  const i = await inspected(f, undefined, "freeze");
  assert.equal(i.plan.next.entry.policyHash, i.capture.record.policyHash);
  assert.equal(i.plan.next.providerEpoch, i.capture.record.providerEpoch);
  assert.equal(i.plan.next.config.locked, true);
  assert.notEqual(i.plan.transition.artistContentStateHash, i.capture.record.contentStateHash);
  await assert.rejects(inspected(setup(), undefined, "freeze"));
});

test("actual caller op17 supports direct and empty relayed proof, original digest/record and current capability", async () => {
  const f = setup(), i = await inspected(f), c = await consent(f, i);
  assert.equal(c.consent.direct, true);
  assert.equal((await flow.simulateEntropyInstantPolicyConsent(f.p, c, { blockTag: 10 })).recordHash,
    pure.entropyInstantPolicyArtistRecordHash(i.plan, { registry: deployment.artist.registry.address, artistId: binding.artistId, signer,
      authorityClass: 1n, nonce: 1n, observedAt: 1000n }));
  const relayed = await consent(f, i, caller, "0x", 27n);
  assert.equal(relayed.consent.direct, false);
  await flow.simulateEntropyInstantPolicyConsent(f.p, relayed, { blockTag: 10 });
  assert.equal(f.s.calls.at(-1).from, caller);
  f.s.actorClass = 3n; f.s.actorStatus = 3n;
  await consent(f, i);
  f.s.overrides = name => name === "currentAuthorityCapabilities" ? [{ authorityAddress: signer, authorityClass: 3n, status: 3n, effectiveCapabilities: 0n, activationRecordHash: H("activation") }] : undefined;
  await assert.rejects(consent(f, i), /capability/);
});

test("op17 replay, deadline, malformed digest and simulated record failures never become readiness", async () => {
  const f = setup(), i = await inspected(f), c = await consent(f, i);
  const q = pure.prepareEntropyInstantPolicyArtistConsent(i.plan, deployment.artist.registry.address, signer, signer, { nonce: 2n, deadline: 1000000n, signature: "0x" });
  f.s.consentCapture = { consent: q };
  await assert.rejects(flow.captureEntropyInstantPolicyConsent(f.p, i, q), /authorization/);
  f.s.consentCapture = c;
  f.s.overrides = name => name === "recordContentConsent" ? [H("wrong-record")] : undefined;
  await assert.rejects(flow.simulateEntropyInstantPolicyConsent(f.p, c, { blockTag: 10 }), /record/);
  f.s.overrides = name => name === "contentConsentDigest" ? `${coder.encode(["bytes32"], [c.consent.payload.digest])}00` : undefined;
  await assert.rejects(flow.captureEntropyInstantPolicyConsent(f.p, i, c.consent), /Noncanonical/);
  const expired = pure.prepareEntropyInstantPolicyArtistConsent(i.plan, deployment.artist.registry.address, signer, signer, { nonce: 1n, deadline: 999n, signature: "0x" });
  await assert.rejects(flow.captureEntropyInstantPolicyConsent(f.p, i, expired), /deadline/);
});

test("original governance calls use actual caller, retained exact publication, class1/2 windows and guardians", async () => {
  for (const freezing of [false, true]) {
    const f = setup(freezing ? explicitState() : initial), i = await inspected(f, instantInput, freezing ? "freeze" : "configure");
    const publish = operation(f, i);
    await flow.simulateEntropyInstantPolicyOperation(f.p, publish, { blockTag: 10 });
    f.s.published = true;
    const schedule = operation(f, i, "schedule");
    const r = await flow.simulateEntropyInstantPolicyOperation(f.p, schedule, { blockTag: 10 });
    assert.equal(r.artistConsentRecord, f.s.consentRecord);
    assert.equal(Boolean(r.guardians), freezing);
    const execute = operation(f, i, "execute");
    f.s.times.set(11, execute.prepared.batch.window.notBefore);
    await flow.simulateEntropyInstantPolicyOperation(f.p, execute, { blockTag: 11 });
    assert.equal(f.s.calls.at(-1).name, "executeGovernanceBatch");
    assert.equal(f.s.calls.at(-1).from, caller);
    const safePlan = createSafeCallPlan(1n, "Execute reviewed entropy policy", [
      { safe: caller, intent: "Execute the original governance action", call: execute.call, abi: fixture.abis.executor }
    ]);
    assert.equal(safePlan.steps[0].transaction.operation, 0);
  }
});

test("stale transition/catalog/proposer/guardian and execution timing fail closed", async () => {
  const f = setup(), i = await inspected(f), o = operation(f, i, "execute");
  f.s.published = true;
  await assert.rejects(flow.simulateEntropyInstantPolicyOperation(f.p, o, { blockTag: 11 }), /window/);
  f.s.times.set(11, o.prepared.batch.window.notBefore);
  f.s.states.set(11, { ...initial, revealEscrow: 1n });
  await assert.rejects(flow.simulateEntropyInstantPolicyOperation(f.p, o, { blockTag: 11 }));
  f.s.states.delete(11);
  f.s.overrides = (name, args, tx) => name === "governanceActionPolicyState" && tx.blockTag === 11 ? [H("profile"), H("changed"), 20n, 1n] : undefined;
  await assert.rejects(flow.simulateEntropyInstantPolicyOperation(f.p, o, { blockTag: 11 }), /catalog/);
  const g = setup(explicitState()), gi = await inspected(g, undefined, "freeze"), go = operation(g, gi, "schedule");
  g.s.published = true; g.s.overrides = name => name === "isRoleRedundant" ? [false] : undefined;
  await assert.rejects(flow.simulateEntropyInstantPolicyOperation(g.p, go, { blockTag: 10 }), /redundant/);
});

test("Artist receipt proves original record, flat op17 Archive and Safe ordering for both layouts", async () => {
  for (const mode of ["direct", "safe", "indexed"]) {
    const f = setup(), i = await inspected(f), c = await consent(f, i, mode === "direct" ? signer : caller);
    const opts = mined(f, c.consent.call, c.consent.caller, consentLogs(f, c), mode === "direct" ? "direct" : "safe", 11, mode === "indexed");
    const r = await flow.inspectEntropyInstantPolicyConsentReceipt(f.p, c, opts);
    assert.equal(r.recordHash, f.s.consentRecord);
    assert.equal(r.evidenceId, f.s.evidenceId);
    assert.equal(r.events.at(-1).event, mode === "direct" ? "ArtistArchiveEvidenceAppendedV2" : "ExecutionSuccess");
  }
});

test("Artist Archive mutation, owner omission, replay contradiction, late and equal-block receipt reject", async () => {
  const f = setup(), i = await inspected(f), c = await consent(f, i);
  let opts = mined(f, c.consent.call, signer, consentLogs(f, c));
  f.s.receipt.logs = f.s.receipt.logs.filter(l => l.index !== 1);
  await assert.rejects(flow.inspectEntropyInstantPolicyConsentReceipt(f.p, c, opts), /ContentRecordContext/);
  opts = mined(f, c.consent.call, signer, consentLogs(f, c));
  f.s.overrides = (name, args, tx) => name === "artistAuthorizationState" && tx.blockTag === 11
    ? [{ digestObserved: true, digestRevoked: true, nonceConsumed: true, nonceRevoked: false, nextUnusedNonce: 2n }] : undefined;
  await assert.rejects(flow.inspectEntropyInstantPolicyConsentReceipt(f.p, c, opts), /authorization/);
  f.s.overrides = null;
  f.s.times.set(11, 1000001n);
  await assert.rejects(flow.inspectEntropyInstantPolicyConsentReceipt(f.p, c, opts), /deadline/);
  f.s.times.delete(11); f.s.tx.blockNumber = 10; f.s.receipt.blockNumber = 10;
  await assert.rejects(flow.inspectEntropyInstantPolicyConsentReceipt(f.p, c, opts), /chronology/);
});

test("publication first save and eventless retry need prior-block runtime/pointer proof", async () => {
  const f = setup(), i = await inspected(f), o = operation(f, i);
  f.s.published = true; f.s.existingFrom = 11;
  let opts = mined(f, o.call, caller, governanceLogs(f, o), "safe");
  await flow.inspectEntropyInstantPolicyReceipt(f.p, o, opts);
  f.s.existingFrom = 0;
  opts = mined(f, o.call, caller, [], "safe", 12, true);
  await flow.inspectEntropyInstantPolicyReceipt(f.p, o, opts);
  f.s.codeOverride = (a, tag) => a === deployment.governance.address && tag === 11 ? "0x6002" : undefined;
  await assert.rejects(flow.inspectEntropyInstantPolicyReceipt(f.p, o, opts), /runtime/);
  f.s.codeOverride = null; f.s.existingFrom = 12;
  await assert.rejects(flow.inspectEntropyInstantPolicyReceipt(f.p, o, opts), /previous-block/);
});

test("schedule exact original class1 and class2 events admit cancellation/veto while rejecting impossible states", async () => {
  for (const freezing of [false, true]) {
    const f = setup(freezing ? explicitState() : initial), i = await inspected(f, instantInput, freezing ? "freeze" : "configure"), o = operation(f, i, "schedule");
    f.s.published = true;
    const opts = mined(f, o.call, caller, governanceLogs(f, o), "safe");
    f.s.actionStatus = freezing ? 5n : 2n;
    await flow.inspectEntropyInstantPolicyReceipt(f.p, o, opts);
    f.s.actionStatus = 4n;
    await assert.rejects(flow.inspectEntropyInstantPolicyReceipt(f.p, o, opts), /Scheduled/);
    f.s.actionStatus = 1n;
    const logs = f.s.receipt.logs;
    [logs[0], logs[logs.length - 2]] = [logs[logs.length - 2], logs[0]];
    logs.forEach((l, n) => { l.index = n; });
    await assert.rejects(flow.inspectEntropyInstantPolicyReceipt(f.p, o, opts), /order|follow/);
  }
});

test("configure/freeze execution joins schema2 policy events and exact state; freeze prior prune may be eventless", async () => {
  for (const freezing of [false, true]) {
    const f = setup(freezing ? explicitState() : initial), i = await inspected(f, instantInput, freezing ? "freeze" : "configure"), o = operation(f, i, "execute");
    f.s.published = true; f.s.actionStatus = 3n; f.s.times.set(11, o.prepared.batch.window.notBefore);
    let logs = governanceLogs(f, o);
    const opts = mined(f, o.call, caller, logs, "safe", 11, true);
    const r = await flow.inspectEntropyInstantPolicyReceipt(f.p, o, opts);
    assert.equal(r.observed.record.artistConsentRecord, f.s.consentRecord);
    if (freezing) {
      f.s.receipt.logs.splice(0, 1);
      f.s.receipt.logs.forEach((l, n) => { l.index = n; });
      await flow.inspectEntropyInstantPolicyReceipt(f.p, o, opts);
    }
    f.s.states.get(11).entry.lastActionId = H("other-action");
    await assert.rejects(flow.inspectEntropyInstantPolicyReceipt(f.p, o, opts), /exact state/);
  }
});

test("pre-await mutation, runtime designation, selected-pointer mismatch and canonical read bounds reject", async () => {
  const f = setup(), supplied = structuredClone(deployment);
  f.s.beforeCall = () => { supplied.core.address = addr(999); supplied.artist.components[0].codeHash = H("mutated"); };
  const captured = await flow.captureEntropyInstantPolicy(f.p, supplied, 1n, { blockTag: 10 });
  assert.deepEqual(captured.deployment, deployment);
  f.s.beforeCall = null;
  f.s.codeOverride = a => a === deployment.coordinator.address ? `0xef0100${addr(999).slice(2)}` : undefined;
  const delegated = structuredClone(deployment); delegated.coordinator.codeHash = keccak256(`0xef0100${addr(999).slice(2)}`);
  await assert.rejects(flow.captureEntropyInstantPolicy(f.p, delegated, 1n, { blockTag: 10 }), /runtime/);
  f.s.codeOverride = null;
  f.s.overrides = name => name === "collectionProviderEpoch" ? "0x01" : undefined;
  await assert.rejects(flow.captureEntropyInstantPolicy(f.p, deployment, 1n, { blockTag: 10 }));
});

test("canonical Archive mutations cannot borrow matching hashes or change the exact owner write mask", async () => {
  for (const mutation of ["payload", "owner"]) {
    const f = setup(), i = await inspected(f), c = await consent(f, i);
    const logs = consentLogs(f, c);
    const types = ["uint16", "bytes32", "uint16", "address", "bytes32", `${S}[7]`, `${S}[7]`, "bytes"];
    const v = Array.from(coder.decode(types, f.s.archive));
    if (mutation === "payload") {
      const payloadTypes = [B, C, A, P, "bytes32"];
      const payload = Array.from(coder.decode(payloadTypes, v[7]));
      payload[4] = H("wrong-prior-content");
      v[7] = coder.encode(payloadTypes, payload);
    } else {
      v[6] = Array.from(v[6], x => Array.from(x));
      v[6][2][1] = 6n;
    }
    f.s.archive = coder.encode(types, v);
    logs[2] = event("ArtistArchiveEvidenceAppendedV2", [f.s.evidenceId, 1n, keccak256(f.s.archive), archivePointer,
      BigInt((f.s.archive.length - 2) / 2)], components[8].address);
    const opts = mined(f, c.consent.call, c.consent.caller, logs);
    await assert.rejects(flow.inspectEntropyInstantPolicyConsentReceipt(f.p, c, opts), /payload|advance/);
  }
});

test("Safe success ordering, failure and delegatecall cannot satisfy Artist or governance receipt transport", async () => {
  const f = setup(), i = await inspected(f), c = await consent(f, i, caller);
  let opts = mined(f, c.consent.call, caller, consentLogs(f, c), "safe");
  const logs = f.s.receipt.logs;
  logs.unshift(logs.pop()); logs.forEach((l, n) => { l.index = n; });
  await assert.rejects(flow.inspectEntropyInstantPolicyConsentReceipt(f.p, c, opts), /Safe success must follow/);
  opts = mined(f, c.consent.call, caller, consentLogs(f, c), "safe");
  f.s.receipt.logs[f.s.receipt.logs.length - 1] = event("ExecutionFailure", [H("safeTx"), 0n], caller, 11, successPlain);
  f.s.receipt.logs.forEach((l, n) => { l.index = n; });
  await assert.rejects(flow.inspectEntropyInstantPolicyConsentReceipt(f.p, c, opts), /one success/);
  opts = mined(f, c.consent.call, caller, consentLogs(f, c), "safe");
  const outer = Array.from(safe.decodeFunctionData("execTransaction", f.s.tx.data));
  outer[3] = 1n; f.s.tx.data = safe.encodeFunctionData("execTransaction", outer);
  await assert.rejects(flow.inspectEntropyInstantPolicyConsentReceipt(f.p, c, opts), /ordinary/);
});


test("current-pointer and reorg checks reject cross-block evidence and direct dependency drift", async () => {
  const f = setup();
  f.s.overrides = (name, args) => name === "getSatellitePointer" && args[0] === id("ENTROPY_COORDINATOR")
    ? [deployment.coordinator.address, codeHash, false, args[0], "0x12345678", deployment.moduleRegistry.address, 2n, H("module"), H("deployment"), 1n] : undefined;
  await assert.rejects(flow.captureEntropyInstantPolicy(f.p, deployment, 1n, { blockTag: 10 }), /ACTIVE/);
  f.s.overrides = null;
  let reads = 0;
  f.p.getBlock = async tag => ({ number: tag, timestamp: 1000, hash: ++reads === 1 ? H(`block-${tag}`) : H("reorg") });
  await assert.rejects(flow.captureEntropyInstantPolicy(f.p, deployment, 1n, { blockTag: 10 }), /Block|block/);
});

function requestFixture(profile = "source-delayed") {
  const configHash = profile === "bundled-blockhash" ? pure.entropyInstantProviderConfigHash(deployment.coordinator.address) : H("provider-config");
  const next = pure.prepareEntropyInstantPolicyConfigure(initial, instantInput, { providerCodeHash: codeHash,
    providerConfigHash: configHash, recoveryPolicyHash: ZeroHash, instantMode: 1n, assumptionsHash: pure.ENTROPY_INSTANT_ASSUMPTIONS_HASH }).next;
  const base = { ...initial, ...next, config: { ...next.config, locked: true }, collectionMintedEver: 1n,
    entry: { ...next.entry, lastActionId: H("prior-action"), artistConsentRecord: H("prior-consent") } };
  const f = setup(base), d = { chainId: 1n, core: deployment.core, coordinator: deployment.coordinator, providerProfile: profile };
  const r = { override: null, finalized: false, pendingNotification: false, failedNotification: false, plan: null,
    status: 3n, registeredAt: 9n, lifecycle: 2n, requester: false, authority: deployment.governance.address,
    raw: ZeroHash, provenance: ZeroHash, providerState: 1n, credit: 8n, total: 10n, publicRequests: true };
  const originalCall = f.p.call;
  f.p.call = async tx => {
    const parsed = abi.parseTransaction({ data: tx.data }), { name, args, fragment } = parsed, tag = tx.blockTag;
    const encode = result => typeof result === "string" ? result : abi.encodeFunctionResult(fragment, result);
    const overridden = r.override?.(name, args, tx);
    if (overridden !== undefined) return encode(overridden);
    const done = r.finalized && tag >= 11, plan = r.plan;
    const output = profile === "bundled-blockhash" && plan ? pure.entropyInstantRawResult(plan.requestKey, plan.context,
      BigInt(tag - 1), H(`block-${tag - 1}`), configHash, pure.ENTROPY_INSTANT_ASSUMPTIONS_HASH) : { rawRandomness: r.raw, provenanceHash: r.provenance };
    const seed = done ? pure.entropyInstantSeed(plan, output.rawRandomness) : ZeroHash;
    let out;
    if (name === "staticTerminalEntropyFacts") out = [1n, pure.entropyInstantPolicyRecord(base), done ? 5n : r.status, seed, done ? plan.requestKey : ZeroHash];
    else if (name === "tokenCollectionIdentity") out = [true, 1n, 1n, false];
    else if (name === "coordinatorAtMint") out = [d.coordinator.address];
    else if (name === "tokenLifecycle") out = [r.lifecycle];
    else if (name === "scopeEntropy") out = [{ collectionId: 1n, inputsHash: H("audited-mint-commitment"), requestKey: done ? plan.requestKey : ZeroHash, seed, status: done ? 5n : r.status }];
    else if (name === "tokenEntropy") out = [done ? 5n : r.status, seed, provider, base.providerEpoch, configHash, done ? plan.requestKey : ZeroHash, done ? plan.providerRequestId : 0n, done ? 1n : 0n];
    else if (name === "registeredAtBlock") out = [r.registeredAt];
    else if (name === "requesters") out = [r.requester];
    else if (name === "authority") out = [r.authority];
    else if (name === "collectionEntropyConfig") out = Object.values({ ...base.config, publicRequests: r.publicRequests });
    else if (name === "providerRequestKeys") out = [done ? plan.requestKey : ZeroHash];
    else if (name === "requests") out = done ? [plan.subjectKey, 7n, ZeroHash, provider, BigInt(tag), plan.providerRequestId, output.rawRandomness] : [ZeroHash, 0n, ZeroHash, ZeroAddress, 0n, 0n, ZeroHash];
    else if (name === "requestPolicySnapshot") out = [plan.requestPolicy];
    else if (name === "entropyFeeCredit") out = [done ? r.credit : 8n];
    else if (name === "totalFeeCredits") out = [done ? r.total : 10n];
    else if (name === "pendingRequestCount") out = [0n];
    else if (name === "nonterminalTokenCount") out = [done ? 2n : 3n];
    else if (name === "metadataNotificationPending") out = [r.pendingNotification];
    else if (name === "streamEntropyProviderConfigHash") out = [configHash];
    else if (name === "coordinator") out = [d.coordinator.address];
    else if (name === "entropyProviderRecord") out = [{ state: done ? r.providerState : 1n, runtimeCodeHash: codeHash, revision: 1n, reasonHash: H("reason"), lastActionId: H("action") }];
    else if (name === "requestEntropy") {
      assert.equal(tx.from, plan.caller);
      assert.equal(tx.value, plan.value);
      out = [plan.requestKey, plan.providerRequestId];
    } else if (name === "instantEntropy") {
      assert.equal(tx.from, d.coordinator.address);
      out = [output.rawRandomness, output.provenanceHash];
    } else return originalCall(tx);
    f.s.calls.push({ name, args, to: tx.to, from: tx.from, tag });
    return encode(out);
  };
  return { ...f, d, r, base };
}
async function requestCapture(f, value = 4n, actor = caller) {
  const c = await flow.captureEntropyInstantRequest(f.p, f.d, 7n, actor, value, { blockTag: 10 });
  f.r.plan = c.plan;
  return c;
}
function requestLogs(f, c, tag = 11) {
  const plan = c.plan;
  const result = c.deployment.providerProfile === "bundled-blockhash"
    ? pure.entropyInstantRawResult(plan.requestKey, plan.context, BigInt(tag - 1), H(`block-${tag - 1}`), c.provider.configHash, c.provider.assumptionsHash)
    : { rawRandomness: f.r.raw, provenanceHash: f.r.provenance };
  const seed = pure.entropyInstantSeed(plan, result.rawRandomness), target = f.d.coordinator.address;
  const logs = [];
  if (plan.value) logs.push(event("EntropyFeeCredited", [plan.caller, plan.value], target, tag));
  logs.push(event("EntropyRequested", [plan.requestKey, 7n, ZeroHash, provider, plan.providerRequestId], target, tag));
  logs.push(event("InstantEntropyProduced", [1n, plan.requestKey, plan.providerRequestId, result.rawRandomness, result.provenanceHash, 1n, c.provider.assumptionsHash], target, tag));
  logs.push(event("EntropyFinalized", [plan.requestKey, 7n, ZeroHash, seed, result.rawRandomness], target, tag));
  if (f.r.failedNotification) logs.push(event("MetadataNotificationFailed", [7n, plan.requestKey], target, tag));
  f.r.finalized = true;
  return logs;
}

test("direct sixteen-word facts reports every explicit status without provider or current-pointer reads", async () => {
  for (let status = 1n; status <= 7n; status++) {
    const f = requestFixture(); f.r.status = status;
    for (const mode of [0n, 1n, 2n]) {
      f.base.entry.mode = mode;
      const result = await flow.readEntropyInstantTerminalFacts(f.p, f.d, 7n, { blockTag: 10 });
      assert.equal(result.facts.status, status);
      assert.equal(result.facts.policy.mode, mode);
    }
    assert.ok(!f.s.calls.some(v => ["entropyProviderRecord", "getSatellitePointer", "governanceActionPolicyState", "tokenLifecycle"].includes(v.name)));
  }
  const f = requestFixture();
  f.r.override = name => name === "staticTerminalEntropyFacts" ? `0x${"00".repeat(513)}` : undefined;
  await assert.rejects(flow.readEntropyInstantTerminalFacts(f.p, f.d, 7n, { blockTag: 10 }));
  f.r.override = name => name === "staticTerminalEntropyFacts" ? [1n, pure.entropyInstantPolicyRecord(f.base), 8n, ZeroHash, ZeroHash] : undefined;
  await assert.rejects(flow.readEntropyInstantTerminalFacts(f.p, f.d, 7n, { blockTag: 10 }), /status/i);
});

test("request capture is original-coordinator pinned, later-block only and keeps mint commitment outside request inputs", async () => {
  const f = requestFixture(), c = await requestCapture(f);
  assert.equal(c.plan.snapshot.subject.inputsHash, H("audited-mint-commitment"));
  assert.equal(c.plan.requestPolicy.inputsHash, ZeroHash);
  assert.equal(c.plan.providerFee, 0n); assert.equal(c.plan.callerCredit, 4n);
  assert.equal(c.authorization, "public");
  assert.ok(!f.s.calls.some(v => ["getSatellitePointer", "governanceNonce", "collectionArtistState"].includes(v.name)));
  for (const [key, value] of [["registeredAt", 10n], ["lifecycle", 3n], ["status", 2n], ["status", 5n]]) {
    const bad = requestFixture(); bad.r[key] = value;
    await assert.rejects(requestCapture(bad));
  }
  const bad = requestFixture();
  bad.r.override = name => name === "coordinatorAtMint" ? [addr(999)] : undefined;
  await assert.rejects(requestCapture(bad), /identity/);
});

test("authority, configured requester and public short-circuits stay separate from admin-role original simulation", async () => {
  for (const path of ["authority", "requester", "public", "admin-role-simulation-required"]) {
    const f = requestFixture();
    f.r.publicRequests = path === "public";
    f.r.requester = path === "requester";
    if (path === "authority") f.r.authority = caller;
    const c = await requestCapture(f);
    assert.equal(c.authorization, path);
    const s = await flow.simulateEntropyInstantRequest(f.p, c, { blockTag: 10 });
    assert.equal(s.providerResult, null);
    assert.ok(!f.s.calls.some(v => v.name === "instantEntropy"));
    assert.ok(!f.s.calls.some(v => ["roleRegistry", "getSatellitePointer", "collectionArtistState"].includes(v.name)));
    if (path === "admin-role-simulation-required") {
      f.r.override = name => { if (name === "requestEntropy") throw Error("original Unauthorized"); };
      await assert.rejects(flow.simulateEntropyInstantRequest(f.p, c, { blockTag: 10 }), /Unauthorized/);
    }
  }
});

test("provider mode, marker, identity, ACTIVE pin and canonical return failures are rejected", async () => {
  const cases = [
    ["instantEntropyProfile", [0n, H("assumptions")]], ["instantEntropyProfile", [1n, ZeroHash]],
    ["isStreamInstantEntropyProvider", [false]], ["streamEntropyProviderFamily", [ZeroHash]],
    ["streamEntropyProviderVersion", [ZeroHash]], ["streamEntropyProviderConfigHash", [H("drift")]],
    ["entropyProviderRecord", [{ state: 2n, runtimeCodeHash: codeHash, revision: 2n, reasonHash: H("reason"), lastActionId: H("action") }]],
    ["instantEntropyProfile", `${coder.encode(["uint8", "bytes32"], [1n, H("a")])}00`],
    ["gasParameterInfo", [100000n, 100000n, 1n, 1n]]
  ];
  for (const [method, value] of cases) {
    const f = requestFixture(); f.r.override = name => name === method ? value : undefined;
    await assert.rejects(requestCapture(f), method);
  }
  const f = requestFixture();
  f.r.override = (name, args) => name === "supportsInterface" && args[0] === "0x9cd4388e" ? [true] : undefined;
  await assert.rejects(requestCapture(f), /interface/);
});

test("simulation binds actual caller/value, exact result and pinned block while bundled profile uses previous block", async () => {
  const f = requestFixture("bundled-blockhash"), c = await requestCapture(f, 23n);
  const a = await flow.simulateEntropyInstantRequest(f.p, c, { blockTag: 10 });
  const b = await flow.simulateEntropyInstantRequest(f.p, c, { blockTag: 11 });
  assert.notEqual(a.providerResult.rawRandomness, b.providerResult.rawRandomness);
  assert.equal(a.providerResult.sourceBlock, 9); assert.equal(b.providerResult.sourceBlock, 10);
  f.r.override = name => name === "requestEntropy" ? [H("wrong"), c.plan.providerRequestId] : undefined;
  await assert.rejects(flow.simulateEntropyInstantRequest(f.p, c, { blockTag: 10 }), /return differs/);
  f.r.override = name => { if (name === "instantEntropy") throw Error("No standalone inference"); };
  await flow.simulateEntropyInstantRequest(f.p, c, { blockTag: 10 });
  const generic = requestFixture(), gc = await requestCapture(generic);
  generic.r.override = name => { if (name === "instantEntropy") throw Error("Observer requires transient REQUESTED state"); };
  assert.equal((await flow.simulateEntropyInstantRequest(generic.p, gc, { blockTag: 10 })).providerResult, null);
});

test("request receipt joins zero raw, full caller credit and notification failure in direct and both Safe layouts", async () => {
  for (const mode of ["direct", "safe", "indexed"]) {
    const f = requestFixture(), c = await requestCapture(f, 9n);
    f.r.failedNotification = true; f.r.pendingNotification = true;
    const opts = mined(f, c.plan.call, c.plan.caller, requestLogs(f, c), mode === "direct" ? "direct" : "safe", 11, mode === "indexed");
    const r = await flow.inspectEntropyInstantRequestReceipt(f.p, c, opts);
    assert.equal(r.rawRandomness, ZeroHash); assert.equal(r.facts.status, 5n);
    assert.equal(r.credited, 9n); assert.equal(r.metadataNotificationFailed, true);
    assert.equal(r.metadataNotificationPending, true);
    assert.notEqual(r.facts.seed, ZeroHash);
  }
});

test("receipt uses mined previous block and tolerates later credit claims, notification retries and provider retirement", async () => {
  const f = requestFixture("bundled-blockhash"), c = await requestCapture(f);
  const simulation = await flow.simulateEntropyInstantRequest(f.p, c, { blockTag: 10 });
  f.r.credit = 0n; f.r.total = 0n; f.r.failedNotification = true; f.r.pendingNotification = false; f.r.providerState = 3n;
  const opts = mined(f, c.plan.call, c.plan.caller, requestLogs(f, c, 12), "safe", 12);
  const r = await flow.inspectEntropyInstantRequestReceipt(f.p, c, opts);
  assert.notEqual(r.rawRandomness, simulation.providerResult.rawRandomness);
  assert.equal(r.accounting.callerCredit, 0n); assert.equal(r.metadataNotificationPending, false);
  assert.equal(r.metadataNotificationFailed, true);
  const produced = f.s.receipt.logs.find(v => v.topics[0] === abi.getEvent("InstantEntropyProduced").topicHash);
  const wrong = event("InstantEntropyProduced", [1n, c.plan.requestKey, c.plan.providerRequestId, simulation.providerResult.rawRandomness,
    simulation.providerResult.provenanceHash, 1n, c.provider.assumptionsHash], f.d.coordinator.address, 12);
  Object.assign(produced, wrong, { index: produced.index });
  await assert.rejects(flow.inspectEntropyInstantRequestReceipt(f.p, c, opts));
});

test("request receipt rejects missing lifecycle/credit, wrong request storage and reverse mapping", async () => {
  for (const missing of ["EntropyRequested", "InstantEntropyProduced", "EntropyFinalized", "EntropyFeeCredited"]) {
    const f = requestFixture(), c = await requestCapture(f), opts = mined(f, c.plan.call, caller, requestLogs(f, c));
    f.s.receipt.logs = f.s.receipt.logs.filter(v => v.topics[0] !== abi.getEvent(missing).topicHash);
    await assert.rejects(flow.inspectEntropyInstantRequestReceipt(f.p, c, opts));
  }
  for (const method of ["requests", "providerRequestKeys", "requestPolicySnapshot"]) {
    const f = requestFixture(), c = await requestCapture(f), opts = mined(f, c.plan.call, caller, requestLogs(f, c));
    f.r.override = (name, args, tx) => name !== method || tx.blockTag === 10 ? undefined
      : name === "providerRequestKeys" ? [H("wrong")]
      : name === "requestPolicySnapshot" ? [{ ...c.plan.requestPolicy, inputsHash: H("mint-incorrectly-used") }]
      : [c.plan.subjectKey, 7n, ZeroHash, provider, 11n, c.plan.providerRequestId, H("wrong")];
    await assert.rejects(flow.inspectEntropyInstantRequestReceipt(f.p, c, opts));
  }
});

test("request Safe cannot borrow early success, failure, delegatecall or a different inner/outer value", async () => {
  for (const mutation of ["early", "failure", "delegatecall", "value", "outer"]) {
    const f = requestFixture(), c = await requestCapture(f), opts = mined(f, c.plan.call, caller, requestLogs(f, c), "safe");
    if (mutation === "early") {
      f.s.receipt.logs.unshift(f.s.receipt.logs.pop()); f.s.receipt.logs.forEach((v, n) => { v.index = n; });
    } else if (mutation === "failure") {
      const index = f.s.receipt.logs.length - 1;
      f.s.receipt.logs[index] = { ...event("ExecutionFailure", [H("safeTx"), 0n], caller, 11, successPlain), index };
    } else if (mutation === "outer") f.s.tx.value = 1n;
    else {
      const v = Array.from(safe.decodeFunctionData("execTransaction", f.s.tx.data));
      if (mutation === "value") v[1] = 0n; else v[3] = 1n;
      f.s.tx.data = safe.encodeFunctionData("execTransaction", v);
    }
    await assert.rejects(flow.inspectEntropyInstantRequestReceipt(f.p, c, opts), /Safe|identity|chronology/);
  }
});

test("request snapshots reject mutation, malformed facts, runtime designation, reorg and borrowed same-block proof", async () => {
  const f = requestFixture(), supplied = structuredClone(f.d), originalNetwork = f.p.getNetwork;
  f.p.getNetwork = async () => { supplied.core.address = addr(999); return originalNetwork(); };
  const c = await flow.captureEntropyInstantRequest(f.p, supplied, 7n, caller, 0n, { blockTag: 10 }); f.r.plan = c.plan;
  assert.equal(c.deployment.core.address, f.d.core.address);
  const forged = structuredClone(c); forged.plan.snapshot.subject.status = "3n";
  await assert.rejects(flow.simulateEntropyInstantRequest(f.p, forged, { blockTag: 10 }));
  const opts = mined(f, c.plan.call, caller, requestLogs(f, c), "direct", 10);
  await assert.rejects(flow.inspectEntropyInstantRequestReceipt(f.p, c, opts), /chronology/);
  const bad = requestFixture();
  bad.s.codeOverride = a => a === bad.d.coordinator.address ? `0xef0100${addr(999).slice(2)}` : undefined;
  const d = structuredClone(bad.d); d.coordinator.codeHash = keccak256(`0xef0100${addr(999).slice(2)}`);
  await assert.rejects(flow.captureEntropyInstantRequest(bad.p, d, 7n, caller, 0n, { blockTag: 10 }), /runtime/);
  const reorg = requestFixture(); let reads = 0;
  reorg.p.getBlock = async tag => ({ number: tag, timestamp: 1000, hash: ++reads === 1 ? H(`block-${tag}`) : H("reorg") });
  await assert.rejects(requestCapture(reorg), /block/);
});
