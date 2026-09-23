import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as pure from "../dist/current-entropy-collection-policy.js";
import * as flow from "../dist/current-entropy-collection-policy-workflow.js";
import { createSafeCallPlan } from "../dist/safe-plan.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-entropy-collection-policy-abi.json", import.meta.url)));
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
const asyncPolicy = { ...disabled, mode: 2n, provider, publicRequests: true, collectionSalt: H("salt"), timeoutBlocks: 50n,
  reveal: { declared: true, requestMode: 1n, revealOwnerRole: id("ROLE_ENTROPY_REVEAL_OWNER"), requestSLOBlocks: 30n, revealFeePerTokenWei: 5n } };
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
      if (name === "supportsInterface") out = [args[0] !== "0xffffffff"];
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
      else if (name === "collectionEntropyPolicy") out = [pure.entropyCollectionPolicyRecord(s)];
      else if (name === "collectionProviderEpoch") out = [s.providerEpoch];
      else if (name === "collectionRevealPolicy") out = [s.reveal];
      else if (name === "collectionFreshRecovery") out = [s.recovery];
      else if (name === "revealFeeEscrow") out = [s.revealEscrow];
      else if (name === "collectionExists") out = [s.collectionExists];
      else if (name === "collectionFreezeStatus") out = [s.collectionFrozen];
      else if (name === "collectionMintedEver") out = [s.collectionMintedEver];
      else if (name === "artistContentFamilyState") out = [true, pure.entropyCollectionPolicyRecord(s).contentStateHash];
      else if (name === "entropyProviderRecord") out = [{ state: 1n, runtimeCodeHash: codeHash, revision: 1n, reasonHash: H("provider-reason"), lastActionId: H("provider-action") }];
      else if (name === "isStreamEntropyProvider") out = [true];
      else if (name === "streamEntropyProviderConfigHash") out = [H("provider-config")];
      else if (name === "contextIndependentRequestFee") out = [5n];
      else if (name === "freshRecoveryPolicy") out = [{ exists: true, frozen: true, maxFreshRecoveryAttempts: 2n, incidentDeclarerRole: H("role"), reasonSchemaHash: H("reason"), policyManifestHash: H("manifest"), steps: state.recoverySteps }, H("recovery"), 1n, H("recovery-action")];
      else if (name === "collectionEntropyPolicyTransition" || name === "freezeCollectionEntropyPolicyTransition") {
        const p = name.startsWith("freeze") ? pure.prepareEntropyCollectionPolicyFreeze(s)
          : pure.prepareEntropyCollectionPolicyConfigure(s, pure.decodeEntropyCollectionPolicyInput(coder.encode([pure.ENTROPY_COLLECTION_POLICY_INPUT_TUPLE], [args[1]])),
            { providerCodeHash: args[1].mode === 2n ? codeHash : ZeroHash, providerConfigHash: args[1].mode === 2n ? H("provider-config") : ZeroHash,
              recoveryPolicyHash: args[1].maxFreshRecoveryAttempts ? H("recovery") : ZeroHash });
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
      else if (name === "recordContentConsent") out = [pure.entropyCollectionPolicyArtistRecordHash(state.consentCapture.consent.plan,
        { registry: deployment.artist.registry.address, artistId: binding.artistId, signer, authorityClass: state.actorClass,
          nonce: state.consentCapture.consent.authorization.nonce, observedAt: time(tag) })];
      else if (name === "contentConsentEvidenceForHost") out = [state.consentRecord];
      else if (name === "contentConsentRecord") out = [state.retained ?? { recordHash: state.consentRecord, artistId: binding.artistId,
        bindingGeneration: 1n, terms: { collectionId: 1n, metadataContract: deployment.coordinator.address,
          familyId: pure.ENTROPY_COLLECTION_POLICY_FAMILY, newStateHash: state.operation.prepared.batch.plan.transition.artistContentStateHash }, authorityClass: 1n }];
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
async function inspected(f, input = disabled, kind = "configure") {
  const c = await flow.captureEntropyCollectionPolicy(f.p, deployment, 1n, { blockTag: 10 });
  const i = await flow.inspectEntropyCollectionPolicy(f.p, c, kind === "freeze" ? { kind } : { kind, input });
  return i;
}
async function consent(f, i, actor = signer, signature = "0x", nonce = 1n) {
  const q = pure.prepareEntropyCollectionPolicyArtistConsent(i.plan, deployment.artist.registry.address, actor, signer, { nonce, deadline: 1000000n, signature });
  f.s.consentCapture = { consent: q };
  const c = await flow.captureEntropyCollectionPolicyConsent(f.p, i, q);
  f.s.consentCapture = c;
  return c;
}
function operation(f, i, stage = "publish") {
  const delay = i.plan.kind === "freeze" ? 259200n : 172800n;
  const prepared = flow.prepareEntropyCollectionPolicyGovernance(i, caller, { notBefore: 1000n + delay,
    expiresAfter: 1000n + delay + 604800n, reasonHash: H("reason"), reasonURI: "ipfs://Policy", manifestHash: H("manifest") });
  const o = flow.prepareEntropyCollectionPolicyOperation(prepared, stage, caller);
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
  const data = execution === "direct" ? call.data : safe.encodeFunctionData("execTransaction", [call.to, 0n, call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x"]);
  f.s.tx = { hash: H("transaction"), chainId: 1n, from: execution === "direct" ? actor : addr(900), to: execution === "direct" ? call.to : actor,
    data, value: 0n, blockNumber: tag, blockHash: H(`block-${tag}`) };
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
    familyId: pure.ENTROPY_COLLECTION_POLICY_FAMILY, newStateHash: c.inspection.plan.transition.artistContentStateHash };
  const record = pure.entropyCollectionPolicyArtistRecordHash(q.plan, { registry: q.registry, artistId: binding.artistId, signer,
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

test("twelve-word legacy reads preserve synthetic ASYNC and raw zero Entry; DISABLED transition joins fourth word", async () => {
  const f = setup(), i = await inspected(f);
  assert.equal(i.capture.record.mode, 2n);
  assert.equal(i.capture.record.configured, false);
  assert.equal(i.capture.snapshot.entry.mode, 0n);
  assert.equal(i.plan.next.providerEpoch, 0n);
  assert.notEqual(i.plan.transition.newValueHash, i.plan.transition.artistContentStateHash);
  assert.ok(Object.isFrozen(i.capture.deployment.artist.components[0]));
  const forged = structuredClone(i.capture);
  forged.snapshot.entry.revision = "0n";
  await assert.rejects(flow.inspectEntropyCollectionPolicy(f.p, forged, { kind: "configure", input: disabled }));
});

test("mutable policy prerequisites reject lifetime mints, frozen collection, locked config, INSTANT and disabled escrow", async () => {
  for (const patch of [{ collectionMintedEver: 1n }, { collectionFrozen: true }, { revealEscrow: 1n }, { config: { ...initial.config, locked: true } }]) {
    await assert.rejects(inspected(setup({ ...initial, ...patch })));
  }
  await assert.rejects(inspected(setup(), { ...disabled, mode: 1n }), /INSTANT/);
  await assert.rejects(inspected(setup(), { ...disabled, reveal: { ...disabled.reveal, declared: true } }));
});

test("ASYNC NOT_REQUIRED retains active provider, fee quote and only selected recovery prefix requirements", async () => {
  const f = setup(), p = { ...asyncPolicy, maxFreshRecoveryAttempts: 1n, recoveryPolicyId: H("recovery-id") };
  f.s.recoverySteps = [
    { provider, providerEpoch: 2n, providerConfigHash: H("provider-config"), notBeforeBlocks: 1n, acceptLateOriginalFulfillment: false },
    { provider: addr(999), providerEpoch: 3n, providerConfigHash: H("unused"), notBeforeBlocks: 1n, acceptLateOriginalFulfillment: false }
  ];
  const i = await inspected(f, p);
  assert.equal(i.plan.next.providerEpoch, 1n);
  assert.equal(i.plan.next.recovery.revision, 1n);
  assert.equal(i.plan.next.reveal.revealFeePerTokenWei, 5n);
  assert.ok(!f.s.calls.some(c => c.name === "entropyProviderRecord" && c.args[0] === addr(999)));
  await assert.rejects(inspected(setup(), { ...asyncPolicy, reveal: { ...asyncPolicy.reveal, revealFeePerTokenWei: 4n } }), /quote/);
  f.s.recoverySteps[0].providerEpoch = 1n;
  await assert.rejects(inspected(f, p), /epochs/);
  const unavailable = setup();
  unavailable.s.overrides = name => name === "entropyProviderRecord" ? [{ state: 2n, runtimeCodeHash: codeHash, revision: 2n, reasonHash: H("why"), lastActionId: H("act") }] : undefined;
  await assert.rejects(inspected(unavailable, asyncPolicy), /ACTIVE/);
});

function explicitState() {
  const next = pure.prepareEntropyCollectionPolicyConfigure(initial, asyncPolicy, { providerCodeHash: codeHash, providerConfigHash: H("provider-config"), recoveryPolicyHash: ZeroHash }).next;
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
  assert.equal((await flow.simulateEntropyCollectionPolicyConsent(f.p, c, { blockTag: 10 })).recordHash,
    pure.entropyCollectionPolicyArtistRecordHash(i.plan, { registry: deployment.artist.registry.address, artistId: binding.artistId, signer,
      authorityClass: 1n, nonce: 1n, observedAt: 1000n }));
  const relayed = await consent(f, i, caller, "0x", 27n);
  assert.equal(relayed.consent.direct, false);
  await flow.simulateEntropyCollectionPolicyConsent(f.p, relayed, { blockTag: 10 });
  assert.equal(f.s.calls.at(-1).from, caller);
  f.s.actorClass = 3n; f.s.actorStatus = 3n;
  await consent(f, i);
  f.s.overrides = name => name === "currentAuthorityCapabilities" ? [{ authorityAddress: signer, authorityClass: 3n, status: 3n, effectiveCapabilities: 0n, activationRecordHash: H("activation") }] : undefined;
  await assert.rejects(consent(f, i), /capability/);
});

test("op17 replay, deadline, malformed digest and simulated record failures never become readiness", async () => {
  const f = setup(), i = await inspected(f), c = await consent(f, i);
  const q = pure.prepareEntropyCollectionPolicyArtistConsent(i.plan, deployment.artist.registry.address, signer, signer, { nonce: 2n, deadline: 1000000n, signature: "0x" });
  f.s.consentCapture = { consent: q };
  await assert.rejects(flow.captureEntropyCollectionPolicyConsent(f.p, i, q), /authorization/);
  f.s.consentCapture = c;
  f.s.overrides = name => name === "recordContentConsent" ? [H("wrong-record")] : undefined;
  await assert.rejects(flow.simulateEntropyCollectionPolicyConsent(f.p, c, { blockTag: 10 }), /record/);
  f.s.overrides = name => name === "contentConsentDigest" ? `${coder.encode(["bytes32"], [c.consent.payload.digest])}00` : undefined;
  await assert.rejects(flow.captureEntropyCollectionPolicyConsent(f.p, i, c.consent), /Noncanonical/);
  const expired = pure.prepareEntropyCollectionPolicyArtistConsent(i.plan, deployment.artist.registry.address, signer, signer, { nonce: 1n, deadline: 999n, signature: "0x" });
  await assert.rejects(flow.captureEntropyCollectionPolicyConsent(f.p, i, expired), /deadline/);
});

test("original governance calls use actual caller, retained exact publication, class1/2 windows and guardians", async () => {
  for (const freezing of [false, true]) {
    const f = setup(freezing ? explicitState() : initial), i = await inspected(f, disabled, freezing ? "freeze" : "configure");
    const publish = operation(f, i);
    await flow.simulateEntropyCollectionPolicyOperation(f.p, publish, { blockTag: 10 });
    f.s.published = true;
    const schedule = operation(f, i, "schedule");
    const r = await flow.simulateEntropyCollectionPolicyOperation(f.p, schedule, { blockTag: 10 });
    assert.equal(r.artistConsentRecord, f.s.consentRecord);
    assert.equal(Boolean(r.guardians), freezing);
    const execute = operation(f, i, "execute");
    f.s.times.set(11, execute.prepared.batch.window.notBefore);
    await flow.simulateEntropyCollectionPolicyOperation(f.p, execute, { blockTag: 11 });
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
  await assert.rejects(flow.simulateEntropyCollectionPolicyOperation(f.p, o, { blockTag: 11 }), /window/);
  f.s.times.set(11, o.prepared.batch.window.notBefore);
  f.s.states.set(11, { ...initial, revealEscrow: 1n });
  await assert.rejects(flow.simulateEntropyCollectionPolicyOperation(f.p, o, { blockTag: 11 }));
  f.s.states.delete(11);
  f.s.overrides = (name, args, tx) => name === "governanceActionPolicyState" && tx.blockTag === 11 ? [H("profile"), H("changed"), 20n, 1n] : undefined;
  await assert.rejects(flow.simulateEntropyCollectionPolicyOperation(f.p, o, { blockTag: 11 }), /catalog/);
  const g = setup(explicitState()), gi = await inspected(g, undefined, "freeze"), go = operation(g, gi, "schedule");
  g.s.published = true; g.s.overrides = name => name === "isRoleRedundant" ? [false] : undefined;
  await assert.rejects(flow.simulateEntropyCollectionPolicyOperation(g.p, go, { blockTag: 10 }), /redundant/);
});

test("Artist receipt proves original record, flat op17 Archive and Safe ordering for both layouts", async () => {
  for (const mode of ["direct", "safe", "indexed"]) {
    const f = setup(), i = await inspected(f), c = await consent(f, i, mode === "direct" ? signer : caller);
    const opts = mined(f, c.consent.call, c.consent.caller, consentLogs(f, c), mode === "direct" ? "direct" : "safe", 11, mode === "indexed");
    const r = await flow.inspectEntropyCollectionPolicyConsentReceipt(f.p, c, opts);
    assert.equal(r.recordHash, f.s.consentRecord);
    assert.equal(r.evidenceId, f.s.evidenceId);
    assert.equal(r.events.at(-1).event, mode === "direct" ? "ArtistArchiveEvidenceAppendedV2" : "ExecutionSuccess");
  }
});

test("Artist Archive mutation, owner omission, replay contradiction, late and equal-block receipt reject", async () => {
  const f = setup(), i = await inspected(f), c = await consent(f, i);
  let opts = mined(f, c.consent.call, signer, consentLogs(f, c));
  f.s.receipt.logs = f.s.receipt.logs.filter(l => l.index !== 1);
  await assert.rejects(flow.inspectEntropyCollectionPolicyConsentReceipt(f.p, c, opts), /ContentRecordContext/);
  opts = mined(f, c.consent.call, signer, consentLogs(f, c));
  f.s.overrides = (name, args, tx) => name === "artistAuthorizationState" && tx.blockTag === 11
    ? [{ digestObserved: true, digestRevoked: true, nonceConsumed: true, nonceRevoked: false, nextUnusedNonce: 2n }] : undefined;
  await assert.rejects(flow.inspectEntropyCollectionPolicyConsentReceipt(f.p, c, opts), /authorization/);
  f.s.overrides = null;
  f.s.times.set(11, 1000001n);
  await assert.rejects(flow.inspectEntropyCollectionPolicyConsentReceipt(f.p, c, opts), /deadline/);
  f.s.times.delete(11); f.s.tx.blockNumber = 10; f.s.receipt.blockNumber = 10;
  await assert.rejects(flow.inspectEntropyCollectionPolicyConsentReceipt(f.p, c, opts), /chronology/);
});

test("publication first save and eventless retry need prior-block runtime/pointer proof", async () => {
  const f = setup(), i = await inspected(f), o = operation(f, i);
  f.s.published = true; f.s.existingFrom = 11;
  let opts = mined(f, o.call, caller, governanceLogs(f, o), "safe");
  await flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts);
  f.s.existingFrom = 0;
  opts = mined(f, o.call, caller, [], "safe", 12, true);
  await flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts);
  f.s.codeOverride = (a, tag) => a === deployment.governance.address && tag === 11 ? "0x6002" : undefined;
  await assert.rejects(flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts), /runtime/);
  f.s.codeOverride = null; f.s.existingFrom = 12;
  await assert.rejects(flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts), /previous-block/);
});

test("schedule exact original class1 and class2 events admit cancellation/veto while rejecting impossible states", async () => {
  for (const freezing of [false, true]) {
    const f = setup(freezing ? explicitState() : initial), i = await inspected(f, disabled, freezing ? "freeze" : "configure"), o = operation(f, i, "schedule");
    f.s.published = true;
    const opts = mined(f, o.call, caller, governanceLogs(f, o), "safe");
    f.s.actionStatus = freezing ? 5n : 2n;
    await flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts);
    f.s.actionStatus = 4n;
    await assert.rejects(flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts), /Scheduled/);
    f.s.actionStatus = 1n;
    const logs = f.s.receipt.logs;
    [logs[0], logs[logs.length - 2]] = [logs[logs.length - 2], logs[0]];
    logs.forEach((l, n) => { l.index = n; });
    await assert.rejects(flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts), /order|follow/);
  }
});

test("configure/freeze execution joins schema2 policy events and exact state; freeze prior prune may be eventless", async () => {
  for (const freezing of [false, true]) {
    const f = setup(freezing ? explicitState() : initial), i = await inspected(f, disabled, freezing ? "freeze" : "configure"), o = operation(f, i, "execute");
    f.s.published = true; f.s.actionStatus = 3n; f.s.times.set(11, o.prepared.batch.window.notBefore);
    let logs = governanceLogs(f, o);
    const opts = mined(f, o.call, caller, logs, "safe", 11, true);
    const r = await flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts);
    assert.equal(r.observed.record.artistConsentRecord, f.s.consentRecord);
    if (freezing) {
      f.s.receipt.logs.splice(0, 1);
      f.s.receipt.logs.forEach((l, n) => { l.index = n; });
      await flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts);
    }
    f.s.states.get(11).entry.lastActionId = H("other-action");
    await assert.rejects(flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts), /exact state/);
  }
});

test("pre-await mutation, runtime designation, selected-pointer mismatch and canonical read bounds reject", async () => {
  const f = setup(), supplied = structuredClone(deployment);
  f.s.beforeCall = () => { supplied.core.address = addr(999); supplied.artist.components[0].codeHash = H("mutated"); };
  const captured = await flow.captureEntropyCollectionPolicy(f.p, supplied, 1n, { blockTag: 10 });
  assert.deepEqual(captured.deployment, deployment);
  f.s.beforeCall = null;
  f.s.codeOverride = a => a === deployment.coordinator.address ? `0xef0100${addr(999).slice(2)}` : undefined;
  const delegated = structuredClone(deployment); delegated.coordinator.codeHash = keccak256(`0xef0100${addr(999).slice(2)}`);
  await assert.rejects(flow.captureEntropyCollectionPolicy(f.p, delegated, 1n, { blockTag: 10 }), /runtime/);
  f.s.codeOverride = null;
  f.s.overrides = name => name === "collectionProviderEpoch" ? "0x01" : undefined;
  await assert.rejects(flow.captureEntropyCollectionPolicy(f.p, deployment, 1n, { blockTag: 10 }));
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
    await assert.rejects(flow.inspectEntropyCollectionPolicyConsentReceipt(f.p, c, opts), /payload|advance/);
  }
});

test("Safe success ordering, failure and delegatecall cannot satisfy Artist or governance receipt transport", async () => {
  const f = setup(), i = await inspected(f), c = await consent(f, i, caller);
  let opts = mined(f, c.consent.call, caller, consentLogs(f, c), "safe");
  const logs = f.s.receipt.logs;
  logs.unshift(logs.pop()); logs.forEach((l, n) => { l.index = n; });
  await assert.rejects(flow.inspectEntropyCollectionPolicyConsentReceipt(f.p, c, opts), /Safe success must follow/);
  opts = mined(f, c.consent.call, caller, consentLogs(f, c), "safe");
  f.s.receipt.logs[f.s.receipt.logs.length - 1] = event("ExecutionFailure", [H("safeTx"), 0n], caller, 11, successPlain);
  f.s.receipt.logs.forEach((l, n) => { l.index = n; });
  await assert.rejects(flow.inspectEntropyCollectionPolicyConsentReceipt(f.p, c, opts), /one success/);
  opts = mined(f, c.consent.call, caller, consentLogs(f, c), "safe");
  const outer = Array.from(safe.decodeFunctionData("execTransaction", f.s.tx.data));
  outer[3] = 1n; f.s.tx.data = safe.encodeFunctionData("execTransaction", outer);
  await assert.rejects(flow.inspectEntropyCollectionPolicyConsentReceipt(f.p, c, opts), /ordinary/);
});

test("recovery revision writes only its own new action ID and original schema2 receipt fields", async () => {
  const f = setup();
  f.s.recoverySteps = [{ provider, providerEpoch: 2n, providerConfigHash: H("provider-config"), notBeforeBlocks: 1n, acceptLateOriginalFulfillment: true }];
  const i = await inspected(f, { ...asyncPolicy, maxFreshRecoveryAttempts: 1n, recoveryPolicyId: H("recovery-id") });
  const o = operation(f, i, "execute");
  f.s.published = true; f.s.actionStatus = 3n; f.s.times.set(11, o.prepared.batch.window.expiresAfter);
  const opts = mined(f, o.call, caller, governanceLogs(f, o));
  const result = await flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts);
  assert.equal(result.observed.snapshot.recovery.lastActionId, o.prepared.batch.actionId);
  assert.equal(result.observed.snapshot.recovery.revision, 1n);
  f.s.states.get(11).recovery.lastActionId = ZeroHash;
  await assert.rejects(flow.inspectEntropyCollectionPolicyReceipt(f.p, o, opts), /exact state/);
});

test("current-pointer and reorg checks reject cross-block evidence and direct dependency drift", async () => {
  const f = setup();
  f.s.overrides = (name, args) => name === "getSatellitePointer" && args[0] === id("ENTROPY_COORDINATOR")
    ? [deployment.coordinator.address, codeHash, false, args[0], "0x12345678", deployment.moduleRegistry.address, 2n, H("module"), H("deployment"), 1n] : undefined;
  await assert.rejects(flow.captureEntropyCollectionPolicy(f.p, deployment, 1n, { blockTag: 10 }), /ACTIVE/);
  f.s.overrides = null;
  let reads = 0;
  f.p.getBlock = async tag => ({ number: tag, timestamp: 1000, hash: ++reads === 1 ? H(`block-${tag}`) : H("reorg") });
  await assert.rejects(flow.captureEntropyCollectionPolicy(f.p, deployment, 1n, { blockTag: 10 }), /Block|block/);
});
