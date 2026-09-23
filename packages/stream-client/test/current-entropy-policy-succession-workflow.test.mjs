import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as pure from "../dist/current-entropy-policy-succession.js";
import * as flow from "../dist/current-entropy-policy-succession-workflow.js";
import { createSafeCallPlan } from "../dist/safe-plan.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-entropy-policy-succession-abi.json", import.meta.url)));
const abi = new Interface(Object.values(fixture.abis).flat().filter(v => v.type === "function" || v.type === "event"));
const coder = AbiCoder.defaultAbiCoder(), H = s => id(`succession:${s}`);
const A = n => getAddress(`0x${n.toString(16).padStart(40, "0")}`);
const runtime = "0x6001600055", codeHash = keccak256(runtime), pin = n => ({ address: A(n), codeHash });
const deployment = { chainId: 1n, core: pin(1), moduleRegistry: pin(2), executor: pin(3), roleRegistry: pin(4), predecessor: pin(5), candidate: pin(6), manifest: pin(7) };
const config = { chainId: 1n, core: A(1), moduleRegistry: A(2), executor: A(3), roleRegistry: A(4), predecessor: A(5), predecessorCodeHash: codeHash, candidate: A(6), candidateCodeHash: codeHash, manifest: A(7) };
const caller = A(20), providerAddress = A(21), pointerAddress = A(22), payload = A(23), chunk = A(24);
const ENTROPY = id("ENTROPY_COORDINATOR"), MODULES = id("MODULE_REGISTRY"), MANIFEST = id("SYSTEM_MANIFEST");
const emptyRecovery = { policyId: ZeroHash, policyHash: ZeroHash, maxFreshRecoveryAttempts: 0n, revision: 0n, lastActionId: ZeroHash };
const emptyReveal = { declared: false, requestMode: 0n, revealOwnerRole: ZeroHash, requestSLOBlocks: 0n, revealFeePerTokenWei: 0n };
function policy(cid = 1n, mode = 0n, render = 0n) {
  const p = { collectionId: cid, profile: 1n, policyOrigin: config.predecessor, policyOriginCodeHash: codeHash,
    record: { configured: true, explicitPolicy: true, frozen: false, mode, securityClass: mode === 1n ? 1n : 0n, renderRequirement: render,
      revision: 1n, providerEpoch: mode === 0n ? 0n : 1n, policyHash: ZeroHash, contentStateHash: ZeroHash, lastActionId: H("authored"), artistConsentRecord: H("consent") },
    policy: { mode, securityClass: mode === 1n ? 1n : 0n, renderRequirement: render, provider: mode === 0n ? ZeroAddress : providerAddress,
      collectionSalt: mode === 0n ? ZeroHash : H("salt"), publicRequests: false, timeoutBlocks: mode === 2n ? 4n : 0n,
      reveal: mode === 2n ? { declared: true, requestMode: 1n, revealOwnerRole: id("ROLE_ENTROPY_REVEAL_OWNER"), requestSLOBlocks: 4n, revealFeePerTokenWei: 2n } : emptyReveal,
      maxFreshRecoveryAttempts: 0n, recoveryPolicyId: ZeroHash }, providerCodeHash: mode === 0n ? ZeroHash : codeHash,
    providerConfigHash: mode === 0n ? ZeroHash : H("provider-config"), recovery: emptyRecovery };
  return rehash(p);
}
function rehash(input) {
  const p = structuredClone(input);
  p.record.policyHash = pure.entropyPolicySuccessionPolicyHash(1n, config.core, p);
  p.record.contentStateHash = pure.entropyPolicySuccessionContentStateHash(p.record.policyHash, p.record.frozen);
  return p;
}
const registration = { module: config.candidate, moduleType: ENTROPY, moduleVersion: H("version"), interfaceId: pure.ENTROPY_POLICY_SUCCESSION_COORDINATOR_INTERFACE_ID,
  moduleGasLimit: 2_000_000n, expectedRuntimeCodeHash: codeHash, deploymentManifestHash: H("deployment"), moduleManifestHash: H("module-manifest"), moduleManifestURI: "ipfs://module" };
function ptr(target, kind, revision = 1n) {
  return { target, codeHash, frozen: false, moduleType: kind, interfaceId: pure.ENTROPY_POLICY_SUCCESSION_COORDINATOR_INTERFACE_ID,
    registry: config.moduleRegistry, registryStatus: 1n, moduleManifestHash: H("module-manifest"), deploymentManifestHash: H("deployment"), revision };
}
const moduleKeys = ["revenueResolver", "metadataRouter", "collectionMetadata", "entropyCoordinator", "mintManager", "mintLedger", "artistRegistry", "streamAdminsOrGovernance", "artworkFinalityRegistry", "moduleRegistry", "stateExportPublisher"];
const discoveryKeys = ["eventCatalogHash", "compatibilityMatrixHash", "numericIdCatalogHash", "schemaCatalogHash", "canonicalizationCatalogHash", "specBundleHash", "reconstructionClientHash"];
const manifestState = { manifestHash: H("old-manifest"), manifestURI: "ipfs://old", modules: Object.fromEntries(moduleKeys.map((k, i) => [k, k === "entropyCoordinator" ? config.predecessor : k === "moduleRegistry" ? config.moduleRegistry : A(100 + i)])),
  discovery: Object.fromEntries(discoveryKeys.map(k => [k, H(k)])), revision: 1n, payloadRoot: A(25) };
function manifestData() {
  const PAYLOAD = "0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81", JCS = "0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044";
  const ROOT = "0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b", LEAF = "0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5", LIST = "0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839";
  const h = keccak256("0x7b7d"), leaf = keccak256(coder.encode(["bytes32", "uint256", "uint32", "bytes32"], [LEAF, 0n, 2n, h]));
  const list = keccak256(coder.encode(["bytes32", "uint32", "bytes32[]"], [LIST, 2n, [leaf]]));
  const hash = keccak256(coder.encode(["bytes32", "uint16", "bytes32", "bytes32", "uint32", "uint16", "bytes32"], [ROOT, 1n, PAYLOAD, JCS, 2n, 1n, list]));
  const descriptor = coder.encode(["bytes4", "uint16", "bytes32", "bytes32", "uint32", "uint16", "tuple(address pointer,uint32 payloadLength,bytes32 payloadHash)[]"], ["0x6c9d2530", 1n, PAYLOAD, JCS, 2n, 1n, [[chunk, 2n, h]]]);
  return { hash, descriptor };
}
const md = manifestData();
const update = { manifestHash: md.hash, manifestURI: "ipfs://next", ...manifestState.discovery };
const baseHistory = { initialRows: [{ actionClass: 3n, target: config.manifest, selector: abi.getFunction("publishStreamSystemManifest").selector,
  targetCodeHash: codeHash, targetProfileHash: H("base-profile"), callType: 1n, valuePolicy: 0n, valueLimit: 0n, valueSemanticsHash: ZeroHash }], extensions: [] };
const catalog = pure.entropyPolicySuccessionCatalogHistory(1n, config.executor, H("candidate-profile"), baseHistory).state;
const emptyReceipt = pure.decodeEntropyPolicySuccessionImportReceipt(`0x${"00".repeat(544)}`);
function initial(policies = [policy()], state = 0n, copied = 0, confirmed = 0n) {
  const inv = pure.entropyPolicySuccessionInventory(policies.map(p => p.collectionId), BigInt(policies.length));
  let receipt = { ...emptyReceipt };
  if (state !== 0n) {
    receipt = { ...receipt, state, nonce: 1n, predecessor: config.predecessor, predecessorCodeHash: codeHash, pointerRevision: 1n,
      ...inv, manifestHash: H("import-manifest"), nextIndex: BigInt(copied), requiredRelayCount: BigInt(policies.slice(0, copied).filter(pure.entropyPolicySuccessionRouteRequired).length), confirmedRelayCount: confirmed,
      beginActionId: H("begin"), sealActionId: state >= 2n ? H("seal") : ZeroHash, activationActionId: state === 3n ? H("activation") : ZeroHash };
    receipt.importHash = pure.entropyPolicySuccessionImportHash(config, receipt);
    receipt.exportDigest = pure.entropyPolicySuccessionInitialExportDigest(receipt.importHash);
    policies.slice(0, copied).forEach((p, index) => {
      receipt.exportDigest = pure.entropyPolicySuccessionAppendExportDigest(receipt.exportDigest, BigInt(index), p.collectionId, pure.entropyPolicySuccessionExportHash(p), ZeroHash);
    });
  }
  return { source: structuredClone(policies), candidate: structuredClone(policies.slice(0, copied)), sourceSerial: inv.serial, candidateSerial: BigInt(copied), receipt,
    pointer: ptr(state === 3n ? config.candidate : config.predecessor, ENTROPY, state === 3n ? 2n : 1n), manifest: structuredClone(manifestState),
    catalog: structuredClone(catalog), nonce: 3n, recoveries: [], imported: policies.slice(0, copied).map(p => ({ importHash: receipt.importHash, exportHash: pure.entropyPolicySuccessionExportHash(p), policyOrigin: p.policyOrigin, policyOriginCodeHash: p.policyOriginCodeHash, policyHash: p.record.policyHash })), routes: new Map() };
}
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const success = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const successIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)"]);

// Compiled ABI stubs exercise client joins. They do not establish native contract admission.
function setup(start = initial()) {
  const states = new Map([[10, structuredClone(start)]]), times = new Map([[10, 1000n]]);
  const env = { states, times, calls: [], override: null, codeOverride: null, blockOverride: null, beforeCall: null, op: null, tx: null, receipt: null,
    publishedFrom: Infinity, actionStatus: 1n, providerState: 1n, throwOriginal: false };
  const at = tag => states.get(tag) ?? states.get(10);
  const head = tag => ({ number: tag, hash: H(`block-${tag}`), timestamp: Number(times.get(tag) ?? 1000n) });
  const encode = (f, v) => abi.encodeFunctionResult(f, v);
  const provider = {
    async getNetwork() { return { chainId: 1n }; },
    async getBlock(tag) { return env.blockOverride?.(tag) ?? head(tag); },
    async getCode(target, tag) {
      const override = env.codeOverride?.(target, tag); if (override !== undefined) return override;
      if (target === pointerAddress) return `0x00${coder.encode(["bytes[]"], [env.op.prepared.batch.plan.callDatas]).slice(2)}`;
      if (target === payload) return `0x00${md.descriptor.slice(2)}`;
      if (target === chunk) return "0x007b7d";
      return runtime;
    },
    async call(tx) {
      const parsed = abi.parseTransaction({ data: tx.data }), { name, args } = parsed, tag = tx.blockTag, s = at(tag);
      env.calls.push({ name, args, tx }); env.beforeCall?.(name, tx);
      const override = env.override?.(name, args, tx, s); if (override !== undefined) return typeof override === "string" ? override : encode(parsed.fragment, override);
      const hostCandidate = tx.to === config.candidate;
      const inv = hostCandidate ? s.candidate : s.source;
      const invHeader = pure.entropyPolicySuccessionInventory(inv.map(v => v.collectionId), hostCandidate ? s.candidateSerial : s.sourceSerial);
      let out;
      switch (name) {
        case "core": out = [config.core]; break;
        case "authority": case "governanceExecutor": case "owner": out = [config.executor]; break;
        case "roleRegistry": out = [config.roleRegistry]; break;
        case "streamModuleType": out = [ENTROPY]; break;
        case "streamModuleVersion": out = [registration.moduleVersion]; break;
        case "streamModuleInterfaceId": out = [registration.interfaceId]; break;
        case "streamModuleManifest": out = [registration.moduleManifestURI, registration.moduleManifestHash]; break;
        case "streamModuleDeploymentManifestHash": out = [registration.deploymentManifestHash]; break;
        case "getSatellitePointer": out = Object.values(args[0] === ENTROPY ? s.pointer : ptr(args[0] === MODULES ? config.moduleRegistry : config.manifest, args[0])); break;
        case "entropyPolicyInventory": out = Object.values(invHeader); break;
        case "entropyPolicyCollectionAt": out = [inv[Number(args[0])].collectionId]; break;
        case "exportEntropyPolicy": out = [inv.find(v => v.collectionId === args[0])]; break;
        case "exportEntropyRecovery": out = [s.recoveries.find(v => v.policyId === args[0])]; break;
        case "entropyPolicyImport": out = [s.receipt]; break;
        case "importedEntropyPolicy": out = Object.values(s.imported[s.source.findIndex(v => v.collectionId === args[0])]); break;
        case "entropyPolicyImportReady": out = [pure.entropyPolicySuccessionImportReady(s.receipt, args[0], args[1], args[2], {count:args[3],serial:args[4],idDigest:args[5]})]; break;
        case "moduleRecord": out = [{ status: 1n, ...registration, runtimeCodeHash: codeHash, registeredAt: 1n, statusUpdatedAt: 1n, revision: 1n }]; break;
        case "streamSystemManifest": out = [s.manifest.manifestHash, s.manifest.manifestURI, ...Object.values(s.manifest.modules), ...Object.values(s.manifest.discovery), s.manifest.revision]; break;
        case "streamSystemManifestPointer": out = [s.manifest.payloadRoot]; break;
        case "governanceNonce": out = [s.nonce]; break;
        case "governanceActionPolicyState": out = Object.values(s.catalog); break;
        case "isModuleEligible": case "isProposer": case "supportsInterface": case "collectionExists": out = [true]; break;
        case "uncoveredPendingRequestCount": out = [0n]; break;
        case "entropyProviderRecord": out = [{ state: env.providerState, runtimeCodeHash: codeHash, revision: 1n, reasonHash: H("reason"), lastActionId: H("provider-action") }]; break;
        case "coordinator": out = [config.predecessor]; break;
        case "streamEntropyProviderConfigHash": out = [H("provider-config")]; break;
        case "entropyRelayAdmission": out = Object.values(s.routes.get(`${tx.to}:${args[0]}:${args[1]}`) ?? { successorCodeHash: ZeroHash, importHash: ZeroHash, policyHash: ZeroHash }); break;
        case "entropyPolicyImportTransition": case "entropyPolicyImportSealTransition": case "entropyPolicyImportActivationTransition": case "entropyRelayAdmissionTransition": {
          let req;
          const common = { receipt: s.receipt, predecessorInventory: pure.entropyPolicySuccessionInventory(s.source.map(v => v.collectionId), s.sourceSerial), candidateInventory: pure.entropyPolicySuccessionInventory(s.candidate.map(v => v.collectionId), s.candidateSerial) };
          if (name === "entropyPolicyImportTransition") req = { kind: "begin", ...common, pointer: s.pointer, manifestHash: args[1] };
          else if (name === "entropyPolicyImportSealTransition") req = { kind: "seal", ...common };
          else if (name === "entropyPolicyImportActivationTransition") req = { kind: "cutover", ...common, pointer: s.pointer, registration, registrationStatus: 1n, manifestState: s.manifest, payload, update };
          else {
            const p = s.source.find(v => v.collectionId === args[0]);
            req = { kind: "admit-route", origin: { target: p.policyOrigin, codeHash }, receipt: s.receipt, policy: p, recovery: s.recoveries.find(v => v.policyId === p.recovery.policyId) ?? null,
              importedPolicy: s.imported[s.source.indexOf(p)], currentAdmission: { successorCodeHash: ZeroHash, importHash: ZeroHash, policyHash: ZeroHash }, predecessorAdmission: p.policyOrigin === config.predecessor ? null : s.routes.get(`${p.policyOrigin}:${p.collectionId}:${config.predecessor}`) };
          }
          const plan = pure.prepareEntropyPolicySuccessionPlan(config, req), call = plan.calls[name === "entropyPolicyImportActivationTransition" ? 1 : 0];
          out = [call.scopeHash, call.oldValueHash, call.newValueHash]; break;
        }
        case "systemManifestBootstrapState": out = abi.getFunction(name).outputs.map((v, i) => v.type === "bool" ? true : v.type === "address" ? (i === 13 ? config.manifest : A(50 + i)) : v.type === "bytes32" ? H(`bootstrap-${i}`) : 1n); break;
        case "minimumDelay": out = [172800n]; break;
        case "publishedCallData": out = [tag >= env.publishedFrom ? pointerAddress : ZeroAddress]; break;
        case "publishGovernanceCallData": out = [pointerAddress]; break;
        case "scheduleGovernanceBatch": out = [env.op.prepared.batch.actionId]; break;
        case "governanceAction": {
          const b = env.op.prepared.batch, first = b.plan.calls[0];
          out = [{ status: env.actionStatus, actionClass: b.plan.actionClass, target: first.target, value: 0n, selector: first.selector, callHash: b.callsHash,
            scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash, notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter,
            proposer: env.op.prepared.proposer, executor: env.actionStatus === 3n ? env.op.caller : ZeroAddress, canceller: ZeroAddress, vetoer: ZeroAddress,
            reasonHash: b.window.reasonHash, reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash }]; break;
        }
        case "scheduledCallData": out = [env.op.prepared.batch.plan.callDatas]; break;
        case "scheduledCallDataPointer": out = [pointerAddress]; break;
        default:
          if (env.throwOriginal) throw Error("original source call reverted");
          out = [];
      }
      if (env.throwOriginal && ["scheduleGovernanceBatch", "executeGovernanceBatch", "importNextEntropyPolicy", "confirmEntropyRelayRoute"].includes(name)) throw Error("original source call reverted");
      return encode(parsed.fragment, out);
    },
    async getTransaction() { return env.tx; },
    async getTransactionReceipt() { return env.receipt; },
  };
  env.provider = provider; env.at = at; env.head = head;
  return env;
}
async function inspect(env, request, tag = 10) {
  const c = await flow.captureEntropyPolicySuccession(env.provider, deployment, { blockTag: tag });
  return flow.prepareEntropyPolicySuccession(env.provider, c, request);
}
function gov(env, i, stage = "execute") {
  const window = { notBefore: 200000n, expiresAfter: 900000n, reasonHash: H("governance-reason"), reasonURI: "ipfs://reason", manifestHash: H("governance-manifest") };
  const prepared = flow.prepareEntropyPolicySuccessionGovernance(i, caller, window);
  env.op = flow.entropyPolicySuccessionGovernanceCall(prepared, stage, caller); return env.op;
}
function log(env, name, host, values, index) {
  const encoded = abi.encodeEventLog(abi.getEvent(name), values);
  return { ...encoded, address: host, index, removed: false, blockNumber: 11, blockHash: H("block-11"), transactionHash: H("transaction") };
}
function install(env, op, logs, safe = null) {
  env.op = op;
  env.tx = { hash: H("transaction"), blockNumber: 11, blockHash: H("block-11"), chainId: 1n, from: caller, to: op.call.to, value: 0n, data: op.call.data };
  env.receipt = { hash: H("transaction"), blockNumber: 11, blockHash: H("block-11"), status: 1, logs: logs.map((l, i) => ({ ...l, index: i })) };
  if (safe) {
    env.tx.to = caller;
    env.tx.data = safeAbi.encodeFunctionData("execTransaction", [op.call.to, op.call.value, op.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x"]);
    const encoder = safe === "indexed" ? successIndexed : success;
    env.receipt.logs.push({ ...encoder.encodeEventLog(encoder.getEvent("ExecutionSuccess"), [H("safe"), 0n]), address: caller,
      index: env.receipt.logs.length, removed: false, blockNumber: 11, blockHash: H("block-11"), transactionHash: H("transaction") });
  }
  return safe ? { transport: "safe", transactionHash: H("transaction"), safe: caller, safeTransactionHash: H("safe") } : { transport: "direct", transactionHash: H("transaction") };
}
function governanceLogs(env, op, start) {
  const b = op.prepared.batch, first = b.plan.calls[0], common = [1n, b.actionId, b.plan.actionClass, first.target, 0n, first.selector, b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash];
  return [log(env, "GovernanceActionExecuted", config.executor, [...common, op.caller, b.window.manifestHash], start),
    log(env, "GovernanceActionPolicyValidated", config.executor, [1n, b.actionId, 2n, env.at(10).catalog.candidateProfileHash, env.at(10).catalog.catalogHash], start + 1)];
}

test("complete insertion-order inventories and mixed DISABLED/INSTANT/ASYNC profiles remain accounting observations", async () => {
  const env = setup(initial([policy(9n), policy(2n, 1n), policy(8n, 2n, 0n)]));
  const c = await flow.captureEntropyPolicySuccession(env.provider, deployment, { blockTag: 10 });
  assert.deepEqual(c.predecessor.policies.map(v => v.collectionId), [9n, 2n, 8n]);
  assert.equal(c.ready, false);
  assert.equal(env.calls.some(v => v.name === "entropyProviderRecord"), false);
  const i = await flow.prepareEntropyPolicySuccession(env.provider, c, { kind: "begin", manifestHash: H("import-manifest") });
  assert.equal(i.plan.actionClass, 1n);
  assert.equal(i.nestedGasEquivalence, false);
});

test("canonical returns, complete inventory digest, runtime, chain and concrete-block bounds fail closed", async () => {
  for (const which of ["trailing", "inventory", "runtime", "chain", "bound"]) {
    const env = setup();
    if (which === "trailing") env.override = n => n === "entropyPolicyInventory" ? `${abi.encodeFunctionResult(n, [1n, 1n, H("bad")])}00` : undefined;
    if (which === "inventory") env.override = n => n === "entropyPolicyInventory" ? [1n, 1n, H("bad")] : undefined;
    if (which === "bound") env.override = n => n === "entropyPolicyInventory" ? [257n, 257n, H("too-many")] : undefined;
    if (which === "runtime") env.codeOverride = () => "0x";
    if (which === "chain") env.provider.getNetwork = async () => ({ chainId: 2n });
    await assert.rejects(flow.captureEntropyPolicySuccession(env.provider, deployment, { blockTag: 10 }));
  }
  await assert.rejects(flow.captureEntropyPolicySuccession(setup().provider, deployment, { blockTag: "latest" }));
});

test("pre-await capture and request copies resist caller mutation and type-collision forgery", async () => {
  const env = setup(), input = structuredClone(deployment);
  env.beforeCall = () => { input.candidate.address = A(999); };
  const c = await flow.captureEntropyPolicySuccession(env.provider, input, { blockTag: 10 });
  assert.equal(c.deployment.candidate.address, config.candidate);
  env.beforeCall = null;
  const bad = structuredClone(c); bad.receipt.state = "0n";
  await assert.rejects(flow.prepareEntropyPolicySuccession(env.provider, bad, { kind: "begin", manifestHash: H("import-manifest") }), /Capture hash/);
  const request = { kind: "begin", manifestHash: H("import-manifest") };
  env.beforeCall = () => { request.manifestHash = H("mutated"); };
  const i = await flow.prepareEntropyPolicySuccession(env.provider, c, request);
  assert.equal(i.plan.request.manifestHash, H("import-manifest"));
});

test("permissionless ordered copy uses actual caller and propagates original private freshness failures", async () => {
  const env = setup(initial([policy()], 1n));
  const i = await inspect(env, { kind: "copy", expectedIndex: 0n });
  env.op = flow.entropyPolicySuccessionCall(i, caller);
  await flow.simulateEntropyPolicySuccession(env.provider, env.op, { blockTag: 10, gasLimit: 5_000_000n });
  assert.equal(env.calls.at(-1).tx.from, caller);
  await assert.rejects(inspect(env, { kind: "copy", expectedIndex: 1n }), /next staged/);
  env.throwOriginal = true;
  await assert.rejects(flow.simulateEntropyPolicySuccession(env.provider, env.op, { blockTag: 10, gasLimit: 5_000_000n }), /original source/);
});

test("source serial or selected pointer drift blocks new progress while retained state stays readable", async () => {
  const env = setup(initial([policy()], 1n));
  env.at(10).sourceSerial = 2n;
  assert.equal((await flow.captureEntropyPolicySuccession(env.provider, deployment, { blockTag: 10 })).receipt.state, 1n);
  await assert.rejects(inspect(env, { kind: "copy", expectedIndex: 0n }), /Predecessor inventory changed/);
  env.at(10).sourceSerial = 1n; env.at(10).pointer.revision = 2n;
  await assert.rejects(inspect(env, { kind: "copy", expectedIndex: 0n }), /Selected predecessor changed/);
});

test("ACTIVE historical import survives later source and local authorship changes and reports ready=false", async () => {
  const s = initial([policy()], 3n, 1);
  s.source[0].policy.reveal.revealFeePerTokenWei = 0n;
  s.source.push(policy(4n)); s.sourceSerial = 3n;
  s.candidate[0] = rehash({ ...s.candidate[0], policyOrigin: config.candidate });
  s.candidate.push(policy(3n)); s.candidateSerial = 3n;
  const env = setup(s); env.providerState = 2n;
  const c = await flow.captureEntropyPolicySuccession(env.provider, deployment, { blockTag: 10 });
  assert.equal(c.ready, false); assert.equal(c.receipt.state, 3n);
  assert.notEqual(c.imported[0].receipt.exportHash, pure.entropyPolicySuccessionExportHash(c.candidate.policies[0]));
  await assert.rejects(flow.prepareEntropyPolicySuccession(env.provider, c, { kind: "seal" }), /No staged/);
});

test("ASYNC NOT_REQUIRED needs route while DISABLED and INSTANT NOT_REQUIRED reject confirmation", async () => {
  for (const p of [policy(), policy(1n, 1n)]) {
    const env = setup(initial([p], 1n, 1));
    await assert.rejects(inspect(env, { kind: "confirm-route", collectionId: 1n }), /needs no relay/);
  }
  const env = setup(initial([policy(1n, 2n, 0n)], 1n, 1));
  const s = env.at(10), p = s.source[0];
  s.routes.set(`${p.policyOrigin}:1:${config.candidate}`, { successorCodeHash: codeHash, importHash: s.receipt.importHash, policyHash: p.record.policyHash });
  const i = await inspect(env, { kind: "confirm-route", collectionId: 1n });
  env.op = flow.entropyPolicySuccessionCall(i, caller);
  await flow.simulateEntropyPolicySuccession(env.provider, env.op, { blockTag: 10, gasLimit: 1_000_000n });
  env.throwOriginal = true;
  await assert.rejects(flow.simulateEntropyPolicySuccession(env.provider, env.op, { blockTag: 10, gasLimit: 1_000_000n }), /original source/);
});

test("origin admission uses copied export and immutable conflict checks; no live grant or Artist reads", async () => {
  const env = setup(initial([policy(1n, 2n, 1n)], 1n, 1));
  const i = await inspect(env, { kind: "admit-route", collectionId: 1n });
  assert.equal(i.plan.targetCalls[0].to, config.predecessor);
  assert.equal(i.plan.actionClass, 1n);
  env.at(10).routes.set(`${config.predecessor}:1:${config.candidate}`, { successorCodeHash: codeHash, importHash: env.at(10).receipt.importHash, policyHash: env.at(10).source[0].record.policyHash });
  await assert.rejects(inspect(env, { kind: "admit-route", collectionId: 1n }), /admission|route|immutable/i);
});

test("cutover is exact pointer -> activation -> manifest and only full Executor simulation", async () => {
  const env = setup(initial([policy()], 2n, 1));
  const i = await inspect(env, { kind: "cutover", payload, update });
  assert.deepEqual(i.plan.targetCalls.map(v => abi.parseTransaction({ data: v.data }).name), ["updateSatellitePointer", "activateEntropyPolicyImport", "publishStreamSystemManifest"]);
  assert.equal(i.plan.actionClass, 3n);
  const o = gov(env, i); env.publishedFrom = 0; env.times.set(10, 200000n);
  // Re-capture the same plan at an executable timestamp (capture hash itself is immutable).
  const ready = await inspect(env, { kind: "cutover", payload, update });
  env.op = flow.entropyPolicySuccessionGovernanceCall(flow.prepareEntropyPolicySuccessionGovernance(ready, caller, o.prepared.batch.window), "execute", caller);
  await flow.simulateEntropyPolicySuccession(env.provider, env.op, { blockTag: 10, gasLimit: 30_000_000n });
  assert.equal(env.calls.filter(v => v.name === "activateEntropyPolicyImport").length, 0);
  const safePlan = createSafeCallPlan(1n, "Activate succession", [{safe:caller,intent:"Execute exact cutover",call:env.op.call,abi:fixture.abis.executor}]);
  assert.equal(safePlan.steps[0].transaction.operation, 0);
});

test("catalog stages prove retained history, deduplicate exact canonical rows and append a fresh manifest", async () => {
  const env = setup();
  const inventory = pure.entropyPolicySuccessionCatalogInventory(config, codeHash, catalog.candidateProfileHash, baseHistory, [], H("deployment-profile"));
  const request = { kind: "catalog", inventory, baseHistory, deploymentHash: H("deployment-profile"), completedRows: 0n, payload, update };
  const i = await inspect(env, request);
  assert.equal(i.plan.actionClass, 3n);
  assert.deepEqual(i.plan.targetCalls.map(v => abi.parseTransaction({ data: v.data }).name), ["extendGovernanceActionPolicy", "publishStreamSystemManifest"]);
  const bad = structuredClone(request); bad.inventory.baseCatalogHash = H("invented");
  await assert.rejects(inspect(env, bad), /catalog|canonical/i);
  const arbitrary = structuredClone(request); arbitrary.inventory.additions[0].selector = "0xffffffff";
  await assert.rejects(inspect(env, arbitrary), /catalog|canonical/i);
});

function installLifecycle(env, op, transport = null) {
  const i = op.kind === "permissionless" ? op.inspection : op.prepared.inspection;
  const b = structuredClone(env.at(10)), after = structuredClone(b), req = i.plan.request;
  const actionId = op.kind === "governance" ? op.prepared.batch.actionId : null;
  const logs = [];
  if (req.kind === "begin") {
    const next = initial(b.source, 1n).receipt;
    next.manifestHash = req.manifestHash; next.beginActionId = actionId;
    next.importHash = pure.entropyPolicySuccessionImportHash(config, next);
    next.exportDigest = pure.entropyPolicySuccessionInitialExportDigest(next.importHash); after.receipt = next;
    logs.push(log(env, "EntropyPolicyImportBegun", config.candidate, [1n, next.importHash, config.predecessor, 1n, codeHash, 1n, next.count, next.serial, next.idDigest, next.manifestHash, actionId], 0));
  } else if (req.kind === "copy") {
    const p = b.source[Number(req.expectedIndex)], r = b.recoveries.find(r => r.policyId === p.recovery.policyId);
    after.candidate.push(structuredClone(p)); after.candidateSerial++;
    const exportHash = pure.entropyPolicySuccessionExportHash(p);
    after.imported.push({ importHash: b.receipt.importHash, exportHash, policyOrigin: p.policyOrigin, policyOriginCodeHash: p.policyOriginCodeHash, policyHash: p.record.policyHash });
    after.receipt.nextIndex++;
    if (pure.entropyPolicySuccessionRouteRequired(p)) after.receipt.requiredRelayCount++;
    after.receipt.exportDigest = pure.entropyPolicySuccessionAppendExportDigest(b.receipt.exportDigest, req.expectedIndex, p.collectionId, exportHash, r ? pure.entropyPolicySuccessionRecoveryExportHash(r) : ZeroHash);
    if (r && !b.candidate.some(v => v.recovery.policyId === r.policyId)) logs.push(log(env, "EntropyRecoveryPolicyImported", config.candidate, [1n, b.receipt.importHash, r.policyId, r.policyOrigin, r.policyOriginCodeHash, r.policyHash], 0));
    logs.push(log(env, "EntropyPolicyImported", config.candidate, [1n, b.receipt.importHash, p.collectionId, p.policyOrigin, req.expectedIndex, p.policyOriginCodeHash, p.record.policyHash, after.receipt.exportDigest], logs.length));
  } else if (req.kind === "confirm-route") {
    const p = b.source.find(v => v.collectionId === req.collectionId); after.receipt.confirmedRelayCount++;
    logs.push(log(env, "EntropyRelayRouteConfirmed", config.candidate, [1n, b.receipt.importHash, p.collectionId, p.policyOrigin, p.record.policyHash], 0));
  } else if (req.kind === "seal") {
    after.receipt.state = 2n; after.receipt.sealActionId = actionId;
    logs.push(log(env, "EntropyPolicyImportSealed", config.candidate, [1n, b.receipt.importHash, b.receipt.exportDigest, b.receipt.count, b.receipt.confirmedRelayCount, actionId], 0));
  } else if (req.kind === "admit-route") {
    const p = req.policy;
    after.routes.set(`${p.policyOrigin}:${p.collectionId}:${config.candidate}`, { successorCodeHash: codeHash, importHash: b.receipt.importHash, policyHash: p.record.policyHash });
    logs.push(log(env, "EntropyRelayAdmitted", p.policyOrigin, [1n, p.collectionId, config.candidate, b.receipt.importHash, codeHash, p.record.policyHash, actionId], 0));
  } else if (req.kind === "catalog") {
    const rows = req.inventory.additions.slice(Number(req.completedRows), Number(req.completedRows) + 64);
    after.catalog = pure.entropyPolicySuccessionCatalogExtension(1n, config.executor, b.catalog, rows).state;
    logs.push(log(env, "GovernanceActionPolicyExtended", config.executor, [after.catalog.revision, b.catalog.catalogHash, after.catalog.catalogHash, b.catalog.entryCount, after.catalog.entryCount], 0));
  } else if (req.kind === "cutover") {
    after.receipt.state = 3n; after.receipt.activationActionId = actionId;
    after.pointer = ptr(config.candidate, ENTROPY, 2n);
    after.manifest.modules.entropyCoordinator = config.candidate;
    logs.push(log(env, "CoreSatellitePointerUpdated", config.core, [1n, ENTROPY, actionId, config.candidate, config.predecessor], 0));
    logs.push(log(env, "EntropyPolicyImportActivated", config.candidate, [1n, b.receipt.importHash, actionId], 1));
  }
  if (req.kind === "cutover" || req.kind === "catalog") {
    after.manifest = { ...after.manifest, manifestHash: update.manifestHash, manifestURI: update.manifestURI, discovery: { ...manifestState.discovery }, revision: 2n, payloadRoot: payload };
    logs.push(log(env, "StreamSystemManifestPublished", config.manifest, [1n, update.manifestHash, payload, actionId], logs.length));
  }
  if (op.kind === "governance") { logs.push(...governanceLogs(env, op, logs.length)); env.times.set(11, 200000n); env.actionStatus = 3n; env.publishedFrom = 0; }
  env.states.set(11, after);
  return install(env, op, logs, transport);
}

test("direct and both Safe layouts reconcile non-idempotent copy, confirm, begin, seal, route and cutover", async () => {
  const cases = [
    [initial(), { kind: "begin", manifestHash: H("import-manifest") }],
    [initial([policy()], 1n), { kind: "copy", expectedIndex: 0n }],
    [initial([policy()], 1n, 1), { kind: "seal" }],
    [initial([policy()], 2n, 1), { kind: "cutover", payload, update }],
    [initial([policy(1n, 2n, 1n)], 1n, 1), { kind: "admit-route", collectionId: 1n }],
  ];
  for (const [s, request] of cases) for (const transport of [null, "plain", "indexed"]) {
    const env = setup(s), i = await inspect(env, request);
    const op = i.plan.actionClass === null ? flow.entropyPolicySuccessionCall(i, caller) : gov(env, i);
    const e = installLifecycle(env, op, transport);
    const receipt = await flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e);
    assert.equal(receipt.verified, true);
  }
  const env = setup(initial([policy(1n, 2n, 0n)], 1n, 1));
  const p = env.at(10).source[0];
  env.at(10).routes.set(`${p.policyOrigin}:1:${config.candidate}`, { successorCodeHash: codeHash, importHash: env.at(10).receipt.importHash, policyHash: p.record.policyHash });
  const op = flow.entropyPolicySuccessionCall(await inspect(env, { kind: "confirm-route", collectionId: 1n }), caller);
  const e = installLifecycle(env, op);
  assert.equal((await flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e)).after.receipt.confirmedRelayCount, 1n);
});

test("catalog execution joins old policy validation with new catalog and unchanged-module manifest tail", async () => {
  const env = setup();
  const inventory = pure.entropyPolicySuccessionCatalogInventory(config, codeHash, catalog.candidateProfileHash, baseHistory, [], H("deployment-profile"));
  const i = await inspect(env, { kind: "catalog", inventory, baseHistory, deploymentHash: H("deployment-profile"), completedRows: 0n, payload, update });
  const op = gov(env, i), e = installLifecycle(env, op, "plain");
  const r = await flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e);
  assert.equal(r.after.catalog.revision, 1n);
  assert.equal(r.after.manifestState.modules.entropyCoordinator, config.predecessor);
  env.receipt.logs = env.receipt.logs.filter(l => l.topics[0] !== abi.getEvent("StreamSystemManifestPublished").topicHash);
  await assert.rejects(flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e), /StreamSystemManifestPublished/);
});

test("cutover receipt rejects missing or reordered mandatory tails and caller/call/value substitution", async () => {
  for (const bad of ["missing", "order", "value", "data", "caller", "state"]) {
    const env = setup(initial([policy()], 2n, 1)), op = gov(env, await inspect(env, { kind: "cutover", payload, update })), e = installLifecycle(env, op);
    if (bad === "missing") env.receipt.logs.splice(2, 1);
    if (bad === "order") { [env.receipt.logs[0], env.receipt.logs[1]] = [env.receipt.logs[1], env.receipt.logs[0]]; env.receipt.logs.forEach((l, i) => l.index = i); }
    if (bad === "value") env.tx.value = 1n;
    if (bad === "data") env.tx.data = `${env.tx.data}00`;
    if (bad === "caller") env.tx.from = A(400);
    if (bad === "state") env.at(11).receipt.confirmedRelayCount = 1n;
    await assert.rejects(flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e));
  }
});

test("Safe rejects early success, failure, delegatecall, wrong inner target and nonzero outer value", async () => {
  for (const bad of ["early", "failure", "delegate", "target", "outer"]) {
    const env = setup(initial([policy()], 1n)), op = flow.entropyPolicySuccessionCall(await inspect(env, { kind: "copy", expectedIndex: 0n }), caller);
    const e = installLifecycle(env, op, "plain");
    if (bad === "early") { env.receipt.logs.unshift(env.receipt.logs.pop()); env.receipt.logs.forEach((l, i) => l.index = i); }
    if (bad === "failure") Object.assign(env.receipt.logs.at(-1), success.encodeEventLog(success.getEvent("ExecutionFailure"), [H("safe"), 0n]));
    if (bad === "outer") env.tx.value = 1n;
    if (bad === "delegate" || bad === "target") env.tx.data = safeAbi.encodeFunctionData("execTransaction", [bad === "target" ? A(400) : op.call.to, 0n, op.call.data, bad === "delegate" ? 1n : 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x"]);
    await assert.rejects(flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e));
  }
});

test("published call bytes are immutable; eventless retries need prior-block pin and retained pointer", async () => {
  for (const retry of [false, true]) {
    const env = setup(), op = gov(env, await inspect(env, { kind: "begin", manifestHash: H("import-manifest") }), "publish");
    env.publishedFrom = retry ? 10 : 11;
    const logs = retry ? [] : [log(env, "GovernanceCallDataPublished", config.executor, [1n, op.prepared.batch.publicationKey, pointerAddress, caller], 0)];
    const e = install(env, op, logs, "indexed");
    assert.equal((await flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e)).publication, retry ? "reused" : "created");
    if (!retry) {
      env.receipt.logs = env.receipt.logs.filter(l => l.address !== config.executor);
      await assert.rejects(flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e), /GovernanceCallDataPublished/);
    } else {
      // Receipt12/prior11/capture10 isolates the dedicated prior-block runtime check.
      env.receipt.blockNumber = env.tx.blockNumber = 12;
      env.receipt.blockHash = env.tx.blockHash = H("block-12");
      env.receipt.logs.forEach(l => { l.blockNumber = 12; l.blockHash = H("block-12"); });
      env.codeOverride = (target, tag) => target === config.executor && tag === 11 ? "0x6000" : undefined;
      await assert.rejects(flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e), /Pinned runtime/);
    }
  }
});

test("class1/class3 schedule uses ordinary48h, exact nonce/publication and Scheduled before PolicyValidated", async () => {
  const env = setup(), op = gov(env, await inspect(env, { kind: "begin", manifestHash: H("import-manifest") }), "schedule");
  env.publishedFrom = 0;
  await flow.simulateEntropyPolicySuccession(env.provider, op, { blockTag: 10, gasLimit: 5_000_000n });
  const b = op.prepared.batch, first = b.plan.calls[0];
  const logs = [log(env, "GovernanceActionScheduled", config.executor, [1n, b.actionId, 1n, first.target, 0n, first.selector, b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash, b.window.notBefore, b.window.expiresAfter, b.nonce, caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash], 0),
    log(env, "GovernanceActionPolicyValidated", config.executor, [1n, b.actionId, 1n, catalog.candidateProfileHash, catalog.catalogHash], 1)];
  const e = install(env, op, logs);
  for (const status of [1n, 2n]) { env.actionStatus = status; assert.equal((await flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e)).verified, true); }
  env.actionStatus = 3n;
  await assert.rejects(flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e), /Impossible/);
  env.actionStatus = 1n; env.receipt.logs.reverse(); env.receipt.logs.forEach((l, i) => l.index = i);
  await assert.rejects(flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e), /out of order/);
  env.at(10).nonce++;
  await assert.rejects(flow.simulateEntropyPolicySuccession(env.provider, op, { blockTag: 10, gasLimit: 5_000_000n }), /Captured state changed|Historical/);
});

test("SEALED live readiness becomes false after source-header or selected-pointer revision drift", async () => {
  for (const change of ["serial", "pointer"]) {
    const env = setup(initial([policy()], 2n, 1));
    if (change === "serial") env.at(10).sourceSerial++;
    else env.at(10).pointer.revision++;
    const c = await flow.captureEntropyPolicySuccession(env.provider, deployment, { blockTag: 10 });
    assert.equal(c.receipt.state, 2n); assert.equal(c.ready, false);
    await assert.rejects(flow.prepareEntropyPolicySuccession(env.provider, c, { kind: "cutover", payload, update }), /inventory changed|predecessor changed/i);
  }
});

test("canonical catalog preparation requires sealed bootstrap with exact system manifest satellite", async () => {
  const env = setup();
  const inventory = pure.entropyPolicySuccessionCatalogInventory(config, codeHash, catalog.candidateProfileHash, baseHistory, [], H("deployment-profile"));
  const request = { kind: "catalog", inventory, baseHistory, deploymentHash: H("deployment-profile"), completedRows: 0n, payload, update };
  env.override = name => name === "systemManifestBootstrapState" ? abi.getFunction(name).outputs.map((v, i) => v.type === "bool" ? true : v.type === "address" ? A(300 + i) : v.type === "bytes32" ? H(i) : 1n) : undefined;
  await assert.rejects(inspect(env, request), /Bootstrap SystemManifest/);
  env.override = name => name === "systemManifestBootstrapState" ? abi.getFunction(name).outputs.map((v, i) => v.type === "bool" ? false : v.type === "address" ? config.manifest : v.type === "bytes32" ? H(i) : 1n) : undefined;
  await assert.rejects(inspect(env, request), /sealed ordinary/);
});

function recoverySetup(copied = 0, separateOrigin = false) {
  const r = { policyId: H("recovery"), policy: { exists: true, frozen: true, maxFreshRecoveryAttempts: 1n,
    incidentDeclarerRole: id("ROLE_ENTROPY_INCIDENT_DECLARER"), reasonSchemaHash: H("reason-schema"), policyManifestHash: H("recovery-manifest"),
    steps: [{ provider: providerAddress, providerEpoch: 2n, providerConfigHash: H("provider-config"), notBeforeBlocks: 1n, acceptLateOriginalFulfillment: false },
      { provider: A(90), providerEpoch: 1n, providerConfigHash: H("provider-config"), notBeforeBlocks: 1n, acceptLateOriginalFulfillment: false }] },
    policyHash: ZeroHash, revision: 1n, lastActionId: H("recovery-action"), policyOrigin: separateOrigin ? A(91) : config.predecessor,
    policyOriginCodeHash: codeHash, successor: ZeroAddress, successorCodeHash: ZeroHash };
  r.policyHash = pure.entropyPolicySuccessionRecoveryHash(1n, config.core, r);
  const policies = [1n, 2n].map(cid => {
    const p = policy(cid, 2n, 1n);
    p.policy.maxFreshRecoveryAttempts = 1n; p.policy.recoveryPolicyId = r.policyId;
    p.recovery = { policyId: r.policyId, policyHash: r.policyHash, maxFreshRecoveryAttempts: 1n, revision: 1n, lastActionId: H("binding-action") };
    return rehash(p);
  });
  const s = initial(policies, 1n, copied); s.recoveries = [r];
  s.receipt.exportDigest = pure.entropyPolicySuccessionInitialExportDigest(s.receipt.importHash);
  policies.slice(0, copied).forEach((p, i) => {
    s.receipt.exportDigest = pure.entropyPolicySuccessionAppendExportDigest(s.receipt.exportDigest, BigInt(i), p.collectionId, pure.entropyPolicySuccessionExportHash(p), pure.entropyPolicySuccessionRecoveryExportHash(r));
  });
  return setup(s);
}

test("copy checks every recovery step against collection policy origin even if recovery origin differs", async () => {
  const env = recoverySetup(0, true);
  const i = await inspect(env, { kind: "copy", expectedIndex: 0n });
  assert.equal(i.plan.request.expectedIndex, 0n);
  assert.equal(env.calls.filter(v => v.name === "coordinator" && v.tx.to === A(90)).length > 0, true);
  env.override = (name, args, tx) => name === "coordinator" && tx.to === A(90) ? [A(91)] : undefined;
  await assert.rejects(inspect(env, { kind: "copy", expectedIndex: 0n }), /another origin/);
  env.override = (name, args) => name === "entropyProviderRecord" && args[0] === A(90)
    ? [{ state: 2n, runtimeCodeHash: codeHash, revision: 2n, reasonHash: H("retired"), lastActionId: H("retire") }] : undefined;
  await assert.rejects(inspect(env, { kind: "copy", expectedIndex: 0n }), /not ACTIVE/);
});

test("first shared recovery copy emits before policy; later copy emits no duplicate recovery event", async () => {
  for (const copied of [0, 1]) {
    const env = recoverySetup(copied), op = flow.entropyPolicySuccessionCall(await inspect(env, { kind: "copy", expectedIndex: BigInt(copied) }), caller);
    const e = installLifecycle(env, op, "plain");
    assert.equal((await flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e)).verified, true);
    if (copied === 0) {
      [env.receipt.logs[0], env.receipt.logs[1]] = [env.receipt.logs[1], env.receipt.logs[0]];
      env.receipt.logs.forEach((l, i) => l.index = i);
      await assert.rejects(flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e), /out of order/);
    } else {
      const r = env.at(10).recoveries[0];
      env.receipt.logs.unshift(log(env, "EntropyRecoveryPolicyImported", config.candidate, [1n, env.at(10).receipt.importHash, r.policyId, r.policyOrigin, codeHash, r.policyHash], 0));
      env.receipt.logs.forEach((l, i) => l.index = i);
      await assert.rejects(flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e), /Unexpected repeated/);
    }
  }
});

test("multi-hop route retains ultimate origin and requires its prior admission to immediate predecessor", async () => {
  const p = rehash({ ...policy(1n, 2n, 1n), policyOrigin: A(92) });
  const env = setup(initial([p], 1n, 1));
  env.override = name => name === "coordinator" ? [p.policyOrigin] : undefined;
  await assert.rejects(inspect(env, { kind: "admit-route", collectionId: 1n }), /prior|predecessor|admission/i);
  env.at(10).routes.set(`${p.policyOrigin}:1:${config.predecessor}`, { successorCodeHash: codeHash, importHash: H("previous-generation"), policyHash: p.record.policyHash });
  const i = await inspect(env, { kind: "admit-route", collectionId: 1n });
  assert.equal(i.plan.targetCalls[0].to, p.policyOrigin);
  const op = gov(env, i), e = installLifecycle(env, op, "indexed");
  assert.equal((await flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e)).verified, true);
});

test("same-block borrowing, later progress, reorg and malformed log evidence fail closed", async () => {
  for (const bad of ["same", "later", "reorg", "log"]) {
    const env = setup(initial([policy(), policy(2n)], 1n)), op = flow.entropyPolicySuccessionCall(await inspect(env, { kind: "copy", expectedIndex: 0n }), caller);
    const e = installLifecycle(env, op);
    if (bad === "same") {
      env.receipt.blockNumber = env.tx.blockNumber = 10; env.receipt.blockHash = env.tx.blockHash = H("block-10");
      env.receipt.logs.forEach(l => { l.blockNumber = 10; l.blockHash = H("block-10"); });
    }
    if (bad === "later") env.at(11).receipt.nextIndex = 2n;
    if (bad === "reorg") env.blockOverride = tag => ({ ...env.head(tag), hash: H("reorg") });
    if (bad === "log") env.receipt.logs[0].data += "00";
    await assert.rejects(flow.reconcileEntropyPolicySuccessionReceipt(env.provider, op, e));
  }
});

test("live progress requires both registered eligible Coordinators and rejects delegated runtime pins", async () => {
  const env = setup(initial([policy()], 1n));
  env.override = (name, args) => name === "isModuleEligible" && args[0] === config.predecessor ? [false] : undefined;
  await assert.rejects(inspect(env, { kind: "copy", expectedIndex: 0n }), /not eligible/);
  const code = `0xef0100${A(500).slice(2)}`, d = structuredClone(deployment);
  d.candidate.codeHash = keccak256(code);
  const delegated = setup(); delegated.codeOverride = target => target === config.candidate ? code : undefined;
  await assert.rejects(flow.captureEntropyPolicySuccession(delegated.provider, d, { blockTag: 10 }), /Pinned runtime/);
});
