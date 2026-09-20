import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, getAddress, id, keccak256, toUtf8Bytes, ZeroAddress, ZeroHash } from "ethers";
import * as e from "../dist/current-revenue-escrow.js";
import * as w from "../dist/current-revenue-escrow-workflow.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";
import { compiledABI, compiledInterfaces as c } from "./current-revenue-pull-fixture.mjs";

// Compiler-shaped RPC mocks isolate client joins; they do not demonstrate native admission.
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = name => id(name);
const codes = Object.fromEntries(["escrow", "executor", "factory", "runtime", "successor", "wallet", "roles"].map((name, i) => [name, `0x600${i}00`]));
const P = (n, name) => ({ address: A(n), codeHash: keccak256(codes[name]) });
const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);
const indexedSafe = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)"]);
const clone = structuredClone;
const emptyRecord = () => ({ status: 0n, creditKey: { revenueClass: ZeroHash, profileId: ZeroHash, wallet: ZeroAddress, asset: ZeroAddress },
  storedFactory: ZeroAddress, successorWallet: ZeroAddress, successorProfileId: ZeroHash, successorRuntimeCodeHash: ZeroHash,
  expectedAmount: 0n, recoveryManifest: { uri: "", uriHash: ZeroHash, contentHash: ZeroHash, schemaId: ZeroHash, canonicalizationHash: ZeroHash },
  executeAfter: 0n, reasonHash: ZeroHash, reasonURI: "" });

function setup(kind = "flushEscrow", mode = "direct", route = 0n, token = false) {
  const d = {
    chainId: 1n, escrow: P(1, "escrow"), executor: P(2, "executor"),
    origin: { factory: P(3, "factory"), walletCodeHash: keccak256(codes.wallet), assetRegistry: A(4), assetRegistryCodeHash: H("assets"),
      profileDomain: H("profile-domain"), initCodeHash: H("init"), schemaVersion: 1n, walletVersion: 4n },
    runtimeRegistry: P(5, "runtime"), successorFactories: [P(6, "successor")], roleRegistry: P(7, "roles"),
  };
  const oldEntries = [{ account: A(50), sharePpm: 1_000_000n, labelId: ZeroHash }];
  const newEntries = route ? [{ account: A(51), sharePpm: 1_000_000n, labelId: ZeroHash }] : clone(oldEntries);
  const profileId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint16", "uint16", "bytes32", "bytes32", "address", "bytes32", "bytes32"],
    [d.origin.profileDomain, 1n, A(3), 1n, 4n, d.origin.initCodeHash, d.origin.walletCodeHash, A(4), e.revenueEscrowEntriesHash(oldEntries), H("metadata")]));
  const key = { revenueClass: H("class"), profileId, wallet: A(8), asset: token ? A(11) : ZeroAddress };
  const document = {
    creditKey: key, successorFactory: A(6), successorWallet: A(9), successorProfileId: H("next-profile"), successorRuntimeCodeHash: d.origin.walletCodeHash,
    expectedAmount: 50n, route, oldEntries, oldMetadataURIHash: H("metadata"), successorEntries: newEntries,
    recipientNotices: route === 2n ? [{ account: A(50), evidenceHash: H("notice"), noticedAt: 50n }] : [],
    collectionNotices: route === 2n ? [{ core: A(80), collectionId: 1n, artistBound: false, artistAuthority: ZeroAddress, evidenceHash: ZeroHash, noticedAt: 0n }] : [],
    sourceCredits: route === 2n ? [{ producer: A(81), transactionHash: H("credit"), blockHash: H("credit-block"), blockNumber: 1n, logIndex: 0n, collectionIndex: 0n }] : [],
    incidentEvidenceHash: H("incident"), coverageStatementHash: route === 2n ? H("coverage") : ZeroHash,
  };
  const coords = { chainId: 1n, escrow: A(1) };
  const manifest = { uri: "ipfs://recovery", uriHash: keccak256(toUtf8Bytes("ipfs://recovery")), contentHash: e.revenueEscrowManifestHash(coords, document),
    schemaId: H("STREAM_ESCROW_RECOVERY_MANIFEST_V1"), canonicalizationHash: H("6529STREAM_ESCROW_RECOVERY_ABI_V1") };
  const terms = { creditKey: key, successorWallet: A(9), successorProfileId: document.successorProfileId,
    successorRuntimeCodeHash: document.successorRuntimeCodeHash, expectedAmount: 50n, recoveryManifest: manifest,
    executeAfter: 1_500_000n, reasonHash: H("reason"), reasonURI: "ipfs://reason" };
  const rid = e.revenueEscrowRecoveryId(coords, terms);
  const fullRecord = { status: 1n, creditKey: key, storedFactory: A(3), successorWallet: A(9), successorProfileId: terms.successorProfileId,
    successorRuntimeCodeHash: terms.successorRuntimeCodeHash, expectedAmount: 50n, recoveryManifest: manifest,
    executeAfter: terms.executeAfter, reasonHash: terms.reasonHash, reasonURI: terms.reasonURI };
  const actor = A(30), caller = ["scheduleEscrowRecovery", "cancelEscrowRecovery", "authorizeTerminalEscrowRecovery"].includes(kind) ? A(2) : actor;
  const requests = {
    flushEscrow: { kind, creditKey: key }, flushToVerifiedWalletBestEffort: { kind, creditKey: key },
    publishEscrowRecoveryManifest: { kind, document, manifest }, scheduleEscrowRecovery: { kind, terms },
    cancelEscrowRecovery: { kind, recoveryId: rid, reasonHash: H("cancel"), reasonURI: "ipfs://cancel" },
    executeEscrowRecovery: { kind, recoveryId: rid }, authorizeTerminalEscrowRecovery: { kind, recoveryId: rid },
    recordEscrowRecoveryConsent: { kind, recoveryId: rid, nonce: ZeroHash }, revokeEscrowRecoveryConsent: { kind, recoveryId: rid },
    submitEscrowRecoveryConsent: { kind, consent: { account: A(31), recoveryId: rid, nonce: ZeroHash, deadline: 4_000_000n }, signature: "0x" },
  };
  const prepared = e.prepareRevenueEscrowCall(coords, caller, requests[kind]);
  const blankAction = { status: 0n, actionClass: 0n, target: ZeroAddress, value: 0n, selector: "0x00000000", callHash: ZeroHash,
    scopeHash: ZeroHash, oldValueHash: ZeroHash, newValueHash: ZeroHash, notBefore: 0n, expiresAfter: 0n,
    proposer: ZeroAddress, executor: ZeroAddress, canceller: ZeroAddress, vetoer: ZeroAddress, reasonHash: ZeroHash, reasonURI: "", manifestHash: ZeroHash };
  const base = {
    amount: 50n, total: 100n, escrowBalance: 110n, walletBalance: 3n, successorBalance: 5n,
    record: ["executeEscrowRecovery", "cancelEscrowRecovery", "authorizeTerminalEscrowRecovery"].includes(kind) ? fullRecord : emptyRecord(),
    publishedAt: kind === "publishEscrowRecoveryManifest" ? 0n : 100n,
    consent: kind === "revokeEscrowRecoveryConsent", used: false, oldCode: codes.factory, walletCode: codes.wallet,
    factoryStatus: kind.startsWith("flush") ? 1n : 3n, runtimeStatus: 1n, publication: ZeroAddress, action: blankAction,
  };
  const s = { d, prepared, actor, mode, kind, rid, document, manifest, terms, fullRecord, base, after: null, postTag: 11,
    batch: null, timestamp: 2_000_000n, codeOverrides: new Map(), calls: [], logs: [], tx: null, receipt: null,
    fail: null, custom: null, readHook: null, chainId: 1n, reorg: false, gasSeen: null };
  const at = tag => s.after && tag >= s.postTag ? s.after : s.base;
  const encode = (which, name, value) => c[which].encodeFunctionResult(name, value);
  s.event = (which, name, fields) => {
    const f = c[which].getEvent(name), values = f.inputs.map(input => fields[input.name]);
    const out = c[which].encodeEventLog(f, values);
    return { address: which === "executor" ? A(2) : A(1), topics: out.topics, data: out.data };
  };
  s.provider = {
    getNetwork: async () => ({ chainId: s.chainId }),
    getBlock: async tag => ({ number: tag, hash: H(`block-${tag}${s.reorg ? "-changed" : ""}`), timestamp: Number(s.timestamp + BigInt(tag - 10)) }),
    getCode: async (target, tag) => {
      if (s.codeOverrides.has(`${target}:${tag}`)) return s.codeOverrides.get(`${target}:${tag}`);
      const state = at(tag);
      if (target === A(3)) return state.oldCode;
      if (target === A(8)) return state.walletCode;
      if (target === A(9)) return codes.wallet;
      if (target === A(90)) return `0x00${coder.encode(["bytes[]"], [[s.prepared.call.data]]).slice(2)}`;
      return ({ [A(1)]: codes.escrow, [A(2)]: codes.executor, [A(5)]: codes.runtime, [A(6)]: codes.successor, [A(7)]: codes.roles })[target] ?? "0x";
    },
    getBalance: async (target, tag) => target === A(1) ? at(tag).escrowBalance : target === A(8) ? at(tag).walletBalance : at(tag).successorBalance,
    getTransaction: async () => s.tx,
    getTransactionReceipt: async () => s.receipt,
    call: async request => {
      const { to, data, blockTag: tag } = request, state = at(tag);
      if (s.readHook) await s.readHook(request);
      const which = to === A(1) ? "escrow" : to === A(2) ? "executor" : to === A(5) ? "runtime" : to === A(7) ? "roles"
        : to === A(8) || to === A(9) ? "wallet" : to === A(11) ? "erc20" : "factory";
      const parsed = c[which].parseTransaction({ data }), name = parsed.name, args = [...parsed.args];
      s.calls.push({ to, name, args: [...args], tag, from: request.from });
      if (s.fail === name) throw Object.assign(Error(`original ${name} rejection`), { code: "CALL_EXCEPTION" });
      if (s.custom) { const v = s.custom({ to, name, args, tag, state }); if (v !== undefined) return v; }
      if (to === A(1) && name === kind) {
        assert.equal(request.from, caller); s.gasSeen = request.gasLimit;
        return prepared.expectedReturn;
      }
      if (["publishGovernanceCallData", "scheduleGovernanceBatch", "executeGovernanceBatch"].includes(name)) {
        assert.equal(request.from, actor); s.gasSeen = request.gasLimit;
        return name === "publishGovernanceCallData" ? coder.encode(["address"], [A(90)]) : name === "scheduleGovernanceBatch" ? coder.encode(["bytes32"], [s.batch.actionId]) : "0x";
      }
      const scalar = {
        splitFactory: A(3), factoryCodeHash: d.origin.factory.codeHash, walletCodeHash: d.origin.walletCodeHash,
        assetPolicyRegistry: A(4), registryCodeHash: d.origin.assetRegistryCodeHash, governanceAuthority: A(2),
        revenueRuntimeRegistry: A(5), revenueRuntimeRegistryCodeHash: d.runtimeRegistry.codeHash, gasParameter: 400_000n,
        escrowOwed: state.amount, totalOwed: state.total, escrowRecoveryConsentRecorded: args[1] === A(50) ? true : state.consent,
        isEscrowRecoveryConsentNonceUsed: state.used, profileExists: true, splitWalletExists: true,
        walletFor: to === A(3) ? A(8) : A(9), profileEntriesHash: e.revenueEscrowEntriesHash(to === A(3) ? document.oldEntries : document.successorEntries),
        splitWalletRuntimeCodeHash: d.origin.walletCodeHash, factory: to === A(8) ? A(3) : A(6),
        profileId: to === A(8) ? profileId : document.successorProfileId,
        escrowRecoveryAffectedAccountCount: BigInt(e.revenueEscrowAffectedAccounts(document).length),
        escrowRecoveryAffectedAccountAt: e.revenueEscrowAffectedAccounts(document)[Number(args[1])],
        isProposer: true, owner: A(99), governanceNonce: 7n, publishedCallData: state.publication, scheduledCallDataPointer: state.publication,
        roleRegistry: A(7), isRoleRedundant: true, terminalFreezeGuardianConfigCommitment: H("guardian-commit"), supportsInterface: true,
      };
      if (name === "escrowRecoveryConsentDigest") return encode(which, name, [e.revenueEscrowConsentTypedData(coords, { account: args[0], recoveryId: args[1], nonce: args[2], deadline: args[3] }).digest]);
      if (name === "balanceOf") return encode(which, name, [args[0] === A(1) ? state.escrowBalance : args[0] === A(8) ? state.walletBalance : state.successorBalance]);
      if (name === "escrowCreditIdentity") return encode(which, name, [A(3), d.origin.factory.codeHash, d.origin.walletCodeHash]);
      if (name === "escrowRecoveryRecord") return encode(which, name, [state.record]);
      if (name === "escrowRecoveryManifest") return encode(which, name, [state.publishedAt ? e.encodeRevenueEscrowDocument(document) : "0x", state.publishedAt]);
      if (name === "factoryRecord") return encode(which, name, [{ status: args[0] === A(3) ? state.factoryStatus : 1n,
        codeHash: args[0] === A(3) ? d.origin.factory.codeHash : d.successorFactories[0].codeHash,
        runtimeCodeHash: d.origin.walletCodeHash, revision: 1n, lastActionId: H("old-action"), incidentManifestHash: H("incident") }]);
      if (name === "runtimeRecord") return encode(which, name, [{ status: state.runtimeStatus, revision: 1n, incidentManifestHash: H("incident"), lastActionId: H("action") }]);
      if (name === "escrowRecoveryTransitionHashes") return encode(which, name, [rid, H("scope"), H("old"), H("new")]);
      if (["escrowRecoveryCancellationHashes", "escrowRecoveryTerminalHashes"].includes(name)) return encode(which, name, [H("scope"), H("old"), H("new")]);
      if (name === "systemManifestBootstrapState") {
        const f = c.executor.getFunction(name);
        return encode(which, name, f.outputs.map((o, i) => o.type === "bool" ? true : o.type === "address" ? A(i + 100) : o.type === "bytes32" ? H(`boot-${i}`) : 1n));
      }
      if (name === "governanceActionPolicyState") return encode(which, name, [H("candidate"), H("catalog"), 10n, 0n]);
      if (name === "governanceAction") return encode(which, name, [state.action]);
      if (name === "scheduledCallData") return encode(which, name, [[s.prepared.call.data]]);
      if (name === "minimumDelay") return encode(which, name, [args[0] === 4n ? 14n * 86400n : args[0] === 2n ? 72n * 3600n : 0n]);
      if (name === "terminalFreezeVetoGuardianSet") return encode(which, name, [A(7), H("scoped"), 0n, H("ROLE_TERMINAL_FREEZE_VETO"), 2n, 3_000_000n]);
      if (Object.hasOwn(scalar, name)) return encode(which, name, [scalar[name]]);
      throw Error(`Unexpected ${which}.${name}`);
    },
  };
  s.capture = () => w.captureRevenueEscrow(s.provider, d, prepared, { blockTag: 10 });
  s.install = (call = prepared.call, txCaller = caller, logs = []) => {
    const txHash = H("transaction"), blockHash = H(`block-${s.postTag}`);
    s.logs = logs;
    const data = mode === "direct" ? call.data : safe.encodeFunctionData("execTransaction", [call.to, call.value, call.data, 0n, 1n, 2n, 0n, ZeroAddress, ZeroAddress, "0x1234"]);
    if (mode !== "direct") {
      const event = (mode === "indexed" ? indexedSafe : safe).encodeEventLog("ExecutionSuccess", [H("safe-transaction"), 0n]);
      s.logs.push({ address: txCaller, topics: event.topics, data: event.data });
    }
    s.logs.forEach((log, i) => Object.assign(log, { index: i, transactionHash: txHash, blockHash, blockNumber: s.postTag, removed: false }));
    s.tx = { hash: txHash, to: mode === "direct" ? call.to : txCaller, from: mode === "direct" ? txCaller : A(32), value: 0n, data, blockNumber: s.postTag, blockHash, chainId: 1n };
    s.receipt = { hash: txHash, status: 1, from: s.tx.from, to: s.tx.to, blockNumber: s.postTag, blockHash, logs: s.logs };
    return txHash;
  };
  s.options = () => mode === "direct" ? { execution: "direct" } : { execution: "safe", expectedSafeTxHash: H("safe-transaction") };
  s.targetLogs = () => {
    s.after = clone(s.base);
    const schemaVersion = 1n;
    if (kind.startsWith("flush")) {
      Object.assign(s.after, { amount: 0n, total: 50n, escrowBalance: 60n, walletBalance: 53n });
      return [s.event("escrow", "EscrowFlushed", { schemaVersion, ...key, amount: 50n, remainingOwed: 0n })];
    }
    if (kind === "publishEscrowRecoveryManifest") {
      if (s.base.publishedAt) return [];
      s.after.publishedAt = s.timestamp + BigInt(s.postTag - 10);
      return [s.event("escrow", "EscrowRecoveryManifestPublished", { schemaVersion, contentHash: manifest.contentHash, publisher: caller,
        creditKeyHash: keccak256(coder.encode([e.REVENUE_ESCROW_KEY_TUPLE], [key])), oldEntriesHash: e.revenueEscrowEntriesHash(document.oldEntries),
        successorEntriesHash: e.revenueEscrowEntriesHash(document.successorEntries), affectedAccountsHash: keccak256(coder.encode(["address[]"], [e.revenueEscrowAffectedAccounts(document)])),
        route, publishedAt: s.after.publishedAt, canonicalDocument: e.encodeRevenueEscrowDocument(document) })];
    }
    if (kind === "recordEscrowRecoveryConsent" || kind === "submitEscrowRecoveryConsent" || kind === "revokeEscrowRecoveryConsent") {
      s.after.consent = kind !== "revokeEscrowRecoveryConsent";
      if (kind !== "revokeEscrowRecoveryConsent") s.after.used = true;
      return [s.event("escrow", kind === "revokeEscrowRecoveryConsent" ? "EscrowRecoveryConsentRevoked" : "EscrowRecoveryConsentRecorded", {
        schemaVersion, recoveryId: rid, account: kind === "submitEscrowRecoveryConsent" ? A(31) : caller, nonce: ZeroHash })];
    }
    if (kind === "executeEscrowRecovery") {
      Object.assign(s.after, { amount: 0n, total: 50n, escrowBalance: 60n, successorBalance: 55n, record: { ...fullRecord, status: 3n } });
      return [s.event("escrow", "EscrowRecoveryExecuted", { schemaVersion, recoveryId: rid, revenueClass: key.revenueClass, profileId: key.profileId,
        oldWallet: A(8), successorWallet: A(9), movedAmount: 50n, recoveryManifestContentHash: manifest.contentHash, reasonHash: terms.reasonHash, reasonURI: terms.reasonURI })];
    }
    if (kind === "scheduleEscrowRecovery") {
      s.after.record = clone(fullRecord);
      return [s.event("escrow", "EscrowRecoveryScheduled", { schemaVersion, recoveryId: rid, ...key, successorWallet: A(9),
        successorProfileId: terms.successorProfileId, expectedAmount: 50n, recoveryManifestContentHash: manifest.contentHash,
        executeAfter: terms.executeAfter, reasonHash: terms.reasonHash, reasonURI: terms.reasonURI })];
    }
    if (kind === "cancelEscrowRecovery") {
      s.after.record.status = 2n;
      return [s.event("escrow", "EscrowRecoveryCancelled", { schemaVersion, recoveryId: rid, revenueClass: key.revenueClass, profileId: key.profileId,
        reasonHash: H("cancel"), reasonURI: "ipfs://cancel" })];
    }
    return [s.event("escrow", "EscrowRecoveryTerminalAuthorized", { schemaVersion, recoveryId: rid, actionId: s.batch.actionId,
      manifestContentHash: manifest.contentHash, authorizedAt: s.timestamp + BigInt(s.postTag - 10) })];
  };
  s.batchSetup = async (stage = "execute") => {
    const capture = await s.capture();
    const delay = prepared.actionClass === 4n ? 14n * 86400n : prepared.actionClass === 2n ? 72n * 3600n : 0n;
    const window = { notBefore: stage === "execute" ? s.timestamp - 1n : s.timestamp + delay + 10n,
      expiresAfter: s.timestamp + delay + 8n * 86400n, reasonHash: H("governance-reason"), reasonURI: "ipfs://governance", manifestHash: H("system-manifest") };
    const batch = e.prepareRevenueEscrowGovernanceBatch(prepared, A(2), capture.transition, 7n, window);
    s.batch = batch;
    s.action = status => ({ status, actionClass: prepared.actionClass, target: A(1), value: 0n, selector: batch.governanceCall.selector,
      callHash: batch.callsHash, scopeHash: batch.scopeHash, oldValueHash: batch.oldValueHash, newValueHash: batch.newValueHash,
      notBefore: window.notBefore, expiresAfter: window.expiresAfter, proposer: actor, executor: status === 3n ? actor : ZeroAddress,
      canceller: ZeroAddress, vetoer: ZeroAddress, reasonHash: window.reasonHash, reasonURI: window.reasonURI, manifestHash: window.manifestHash });
    if (stage !== "publish") s.base.publication = A(90);
    if (stage === "execute") s.base.action = s.action(1n);
    return w.prepareRevenueEscrowGovernanceStage(s.provider, capture, { stage, caller: actor, nonce: 7n, window, blockTag: 10 });
  };
  s.govLogs = stage => {
    const b = s.batch, common = { schemaVersion: 1n, actionId: b.actionId, actionClass: prepared.actionClass,
      target: A(1), value: 0n, selector: b.governanceCall.selector, callHash: b.callsHash,
      scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash, manifestHash: b.window.manifestHash };
    let logs = [];
    if (stage === "publish") {
      s.after = clone(s.base); s.after.publication = A(90);
      return s.base.publication !== ZeroAddress ? [] : [s.event("executor", "GovernanceCallDataPublished", { schemaVersion: 1n, callDataKey: b.publicationKey, pointer: A(90), publisher: actor })];
    }
    if (stage === "execute") {
      logs = s.targetLogs(); s.after.action = s.action(3n);
      logs.push(s.event("executor", "GovernanceActionExecuted", { ...common, executor: actor }));
    } else {
      s.after = clone(s.base); s.after.action = s.action(1n);
      if (prepared.actionClass === 2n) logs.push(
        s.event("executor", "TerminalFreezeActionMembershipUpdated", { schemaVersion: 1n, scopeHash: b.transition.scopeHash, actionId: b.actionId,
          proposer: actor, present: true, mutationCause: 1n, usesRootCapacity: false, vetoDeadline: b.window.notBefore, rawIndex: 0n, remainingCount: 1n }),
        s.event("executor", "TerminalFreezeGuardianConfigCommitted", { schemaVersion: 1n, actionId: b.actionId, commitment: H("guardian-commit") }),
      );
      logs.push(s.event("executor", "GovernanceActionScheduled", { ...common, notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter,
        nonce: 7n, proposer: actor, reasonHash: b.window.reasonHash, reasonURI: b.window.reasonURI }));
    }
    logs.push(s.event("executor", "GovernanceActionPolicyValidated", { schemaVersion: 1n, actionId: b.actionId, phase: stage === "execute" ? 2n : 1n,
      candidateProfileHash: H("candidate"), catalogHash: H("catalog") }));
    return logs;
  };
  return s;
}

test("seven permissionless methods use actual sender and exact direct/legacy/indexed Safe receipts", async () => {
  for (const mode of ["direct", "legacy", "indexed"]) for (const kind of ["flushEscrow", "flushToVerifiedWalletBestEffort", "publishEscrowRecoveryManifest",
    "executeEscrowRecovery", "recordEscrowRecoveryConsent", "submitEscrowRecoveryConsent", "revokeEscrowRecoveryConsent"]) {
    const s = setup(kind, mode), captured = await s.capture();
    const simulated = await w.simulateRevenueEscrow(s.provider, captured, { blockTag: 10, gasLimit: 5_000_000n });
    assert.equal(simulated.returnData, s.prepared.expectedReturn);
    const tx = s.install(undefined, undefined, s.targetLogs());
    const result = await w.reconcileRevenueEscrowReceipt(s.provider, captured, tx, s.options());
    assert.equal(result.attribution, "exact-prior-and-end-block");
  }
});

test("governed class4/0/2 targets execute only through original Executor on all three transports", async () => {
  for (const mode of ["direct", "legacy", "indexed"]) for (const kind of ["scheduleEscrowRecovery", "cancelEscrowRecovery", "authorizeTerminalEscrowRecovery"]) {
    const s = setup(kind, mode, kind === "authorizeTerminalEscrowRecovery" ? 2n : 0n), stage = await s.batchSetup();
    await assert.rejects(w.simulateRevenueEscrow(s.provider, stage.capture, { blockTag: 10, gasLimit: 5_000_000n }), /Executor/);
    const simulated = await w.simulateRevenueEscrowGovernanceStage(s.provider, stage, { blockTag: 10, gasLimit: 5_000_000n });
    assert.equal(simulated.returnData, "0x");
    const tx = s.install(stage.call, stage.caller, s.govLogs("execute"));
    const result = await w.reconcileRevenueEscrowGovernanceReceipt(s.provider, stage, tx, s.options());
    assert.equal(result.actionId, stage.batch.actionId);
  }
});

test("all three action classes publish and schedule through original Executor; class2 retains guardian evidence", async () => {
  for (const kind of ["scheduleEscrowRecovery", "cancelEscrowRecovery", "authorizeTerminalEscrowRecovery"]) for (const name of ["publish", "schedule"]) {
    const s = setup(kind, "indexed", kind === "authorizeTerminalEscrowRecovery" ? 2n : 0n), stage = await s.batchSetup(name);
    await w.simulateRevenueEscrowGovernanceStage(s.provider, stage, { blockTag: 10, gasLimit: 5_000_000n });
    const tx = s.install(stage.call, stage.caller, s.govLogs(name));
    assert.equal((await w.reconcileRevenueEscrowGovernanceReceipt(s.provider, stage, tx, s.options())).stage, name);
  }
});

test("lost old factory remains recoverable, while ordinary flush requires its executable runtime", async () => {
  const recovered = setup("executeEscrowRecovery"); recovered.base.oldCode = "0x";
  const capture = await recovered.capture();
  assert.equal(recovered.calls.some(call => call.to === A(3) && call.name === "profileEntriesHash"), false);
  const tx = recovered.install(undefined, undefined, recovered.targetLogs());
  await w.reconcileRevenueEscrowReceipt(recovered.provider, capture, tx, recovered.options());
  const flush = setup(); flush.base.oldCode = "0x";
  await assert.rejects(flush.capture(), /Runtime pin/);
});

test("consent, revoke, cancellation and local history do not require live factory/runtime admission", async () => {
  for (const kind of ["recordEscrowRecoveryConsent", "submitEscrowRecoveryConsent", "revokeEscrowRecoveryConsent", "cancelEscrowRecovery"]) {
    const s = setup(kind); s.base.oldCode = "0x";
    s.codeOverrides.set(`${A(5)}:10`, "0x");
    if (kind === "revokeEscrowRecoveryConsent") s.base.record = { ...s.fullRecord, status: 2n };
    await s.capture();
    assert.equal(s.calls.some(call => call.to === A(5)), false);
  }
  const s = setup("executeEscrowRecovery"); s.base.oldCode = "0x";
  s.codeOverrides.set(`${A(5)}:10`, "0x");
  const result = await w.inspectRevenueEscrowHistory(s.provider, { chainId: 1n, escrow: s.d.escrow }, { recoveryId: s.rid }, { blockTag: 10 });
  assert.equal(result.record.status, 1n);
  assert.equal(s.calls.every(call => call.to === A(1)), true);
});

test("nonce0/preconsent/fresh-nonce repeat and CANCELLED revocation preserve original asymmetry", async () => {
  const s = setup("recordEscrowRecoveryConsent"); s.base.consent = true;
  const capture = await s.capture();
  assert.equal(capture.consent.nonce, ZeroHash);
  const tx = s.install(undefined, undefined, s.targetLogs());
  await w.reconcileRevenueEscrowReceipt(s.provider, capture, tx, s.options());
  s.base.used = true;
  await assert.rejects(s.capture(), /nonce consumed/);
  const cancelled = setup("revokeEscrowRecoveryConsent"); cancelled.base.record = { ...cancelled.fullRecord, status: 2n };
  await cancelled.capture();
  cancelled.base.record.status = 3n;
  await assert.rejects(cancelled.capture(), /cannot be revoked/);
});

test("retained manifest publication is eventless after incident/credit changes and needs prior evidence", async () => {
  const s = setup("publishEscrowRecoveryManifest", "legacy");
  Object.assign(s.base, { publishedAt: 100n, amount: 0n, factoryStatus: 1n, oldCode: "0x" });
  const capture = await s.capture(), tx = s.install(undefined, undefined, s.targetLogs());
  assert.equal((await w.reconcileRevenueEscrowReceipt(s.provider, capture, tx, s.options())).outcome, "publication-retained");
  const fresh = setup("publishEscrowRecoveryManifest"), freshCapture = await fresh.capture();
  const omitted = fresh.install(undefined, undefined, fresh.targetLogs().slice(1));
  await assert.rejects(w.reconcileRevenueEscrowReceipt(fresh.provider, freshCapture, omitted, fresh.options()), /Expected one/);
});

test("ETH recovery accepts surplus donations, normal ETH flush and token recovery demand exact deltas", async () => {
  for (const [kind, token, allowed] of [["executeEscrowRecovery", false, true], ["flushEscrow", false, false], ["executeEscrowRecovery", true, false]]) {
    const s = setup(kind, "direct", 0n, token), capture = await s.capture();
    const tx = s.install(undefined, undefined, s.targetLogs()); s.after.escrowBalance += 2n;
    if (allowed) await w.reconcileRevenueEscrowReceipt(s.provider, capture, tx, s.options());
    else await assert.rejects(w.reconcileRevenueEscrowReceipt(s.provider, capture, tx, s.options()), /transfer deltas/);
  }
});

test("best-effort does not deploy or swallow failures; retained DEPRECATED flush remains valid", async () => {
  const s = setup("flushToVerifiedWalletBestEffort"); s.base.factoryStatus = 2n; s.base.runtimeStatus = 2n;
  const capture = await s.capture();
  assert.equal(s.calls.some(call => call.to === A(1) && call.name === "gasParameter"), false);
  s.fail = "flushToVerifiedWalletBestEffort";
  await assert.rejects(w.simulateRevenueEscrow(s.provider, capture, { blockTag: 10, gasLimit: 5_000_000n }), /original/);
  s.fail = null; s.base.walletCode = "0x";
  await assert.rejects(s.capture(), /cannot deploy/);
});

test("simulation pins caller/value/block/gas and rejects stale amount, late original failure and reorg", async () => {
  const s = setup(), capture = await s.capture();
  await assert.rejects(w.simulateRevenueEscrow(s.provider, capture, { blockTag: 9, gasLimit: 1n }), /predates/);
  await assert.rejects(w.simulateRevenueEscrow(s.provider, capture, { blockTag: 10, gasLimit: 100_000_001n }), /Gas limit/);
  s.after = { ...clone(s.base), amount: 51n }; s.postTag = 11;
  await assert.rejects(w.simulateRevenueEscrow(s.provider, capture, { blockTag: 11, gasLimit: 5_000_000n }), /state changed/);
  s.after = null; s.fail = "flushEscrow";
  await assert.rejects(w.simulateRevenueEscrow(s.provider, capture, { blockTag: 10, gasLimit: 5_000_000n }), /original/);
  s.fail = null; s.reorg = true;
  await assert.rejects(w.simulateRevenueEscrow(s.provider, capture, { blockTag: 10, gasLimit: 5_000_000n }), /Captured observation/);
});

test("receipt identity and copied logs reject removed/fractional/substituted evidence", async () => {
  for (const mutate of [s => s.logs[0].removed = true, s => s.logs[0].index = 0.5, s => s.logs[0].transactionHash = H("other"),
    s => s.tx.value = 1n, s => s.tx.from = A(99), s => s.after.amount = 1n]) {
    const s = setup(), capture = await s.capture(), tx = s.install(undefined, undefined, s.targetLogs());
    mutate(s);
    await assert.rejects(w.reconcileRevenueEscrowReceipt(s.provider, capture, tx, s.options()));
  }
  const s = setup("recordEscrowRecoveryConsent", "indexed"), capture = await s.capture(), tx = s.install(undefined, undefined, s.targetLogs());
  let mutated = false;
  s.readHook = () => { if (!mutated) { mutated = true; s.logs.at(-1).topics[1] = H("changed"); } };
  await w.reconcileRevenueEscrowReceipt(s.provider, capture, tx, s.options());
});

test("Safe independent hash, failure, early success, delegatecall and outer value are rejected", async () => {
  for (const variant of ["hash", "failure", "early", "delegate", "value", "unknown"]) {
    const s = setup("recordEscrowRecoveryConsent", "legacy"), capture = await s.capture(), tx = s.install(undefined, undefined, s.targetLogs());
    let options = s.options();
    if (variant === "hash") options = { ...options, expectedSafeTxHash: H("wrong") };
    if (variant === "failure") s.logs.at(-1).topics = [id("ExecutionFailure(bytes32,uint256)")];
    if (variant === "early") { s.logs.unshift(s.logs.pop()); s.logs.forEach((log, i) => log.index = i); }
    if (variant === "delegate") { const args = [...safe.decodeFunctionData("execTransaction", s.tx.data)]; args[3] = 1n; s.tx.data = safe.encodeFunctionData("execTransaction", args); }
    if (variant === "value") s.tx.value = 1n;
    if (variant === "unknown") options = { execution: "delegatecall" };
    await assert.rejects(w.reconcileRevenueEscrowReceipt(s.provider, capture, tx, options));
  }
});

test("governance rejects wrong class/transition, unsealed/bootstrap nonce and exact event reordering", async () => {
  const s = setup("scheduleEscrowRecovery"), stage = await s.batchSetup();
  await assert.rejects(w.simulateRevenueEscrowGovernanceStage(s.provider, { ...stage, batch: { ...stage.batch, transition: { ...stage.batch.transition, oldValueHash: H("wrong") } } }, { blockTag: 10, gasLimit: 5_000_000n }));
  const tx = s.install(stage.call, stage.caller, s.govLogs("execute"));
  [s.logs[0], s.logs[1]] = [s.logs[1], s.logs[0]]; s.logs.forEach((log, i) => log.index = i);
  await assert.rejects(w.reconcileRevenueEscrowGovernanceReceipt(s.provider, stage, tx, s.options()), /event order/);
  const wrongNonce = setup("cancelEscrowRecovery"), scheduled = await wrongNonce.batchSetup("schedule");
  wrongNonce.custom = ({ name }) => name === "governanceNonce" ? coder.encode(["uint256"], [8n]) : undefined;
  await assert.rejects(w.simulateRevenueEscrowGovernanceStage(wrongNonce.provider, scheduled, { blockTag: 10, gasLimit: 5_000_000n }), /nonce/);
});

test("class2 scheduling requires membership and guardian commitment in original order", async () => {
  for (const variant of ["missing", "order", "contradiction"]) {
    const s = setup("authorizeTerminalEscrowRecovery", "direct", 2n), stage = await s.batchSetup("schedule");
    let logs = s.govLogs("schedule");
    if (variant === "missing") logs.shift();
    if (variant === "order") [logs[0], logs[1]] = [logs[1], logs[0]];
    if (variant === "contradiction") logs.unshift(clone(logs[0]));
    const tx = s.install(stage.call, stage.caller, logs);
    await assert.rejects(w.reconcileRevenueEscrowGovernanceReceipt(s.provider, stage, tx, s.options()), /membership/);
  }
});

test("governance publication eventless retry requires prior pointer/runtime and exact retained bytes", async () => {
  const s = setup("cancelEscrowRecovery", "legacy"); s.base.publication = A(90);
  const stage = await s.batchSetup("publish"), tx = s.install(stage.call, stage.caller, s.govLogs("publish"));
  assert.equal((await w.reconcileRevenueEscrowGovernanceReceipt(s.provider, stage, tx, s.options())).outcome, "publication-retained");
  s.codeOverrides.set(`${A(90)}:10`, "0x00");
  await assert.rejects(w.reconcileRevenueEscrowGovernanceReceipt(s.provider, stage, tx, s.options()), /publication bytes/);
});

test("pre-await copies and generic Safe planner preserve original call without submission", async () => {
  const s = setup("recordEscrowRecoveryConsent"), input = clone(s.prepared), dep = clone(s.d);
  const pending = w.captureRevenueEscrow(s.provider, dep, input, { blockTag: 10 });
  input.request.nonce = H("mutated"); dep.escrow.codeHash = H("mutated");
  const capture = await pending;
  assert.equal(capture.prepared.request.nonce, ZeroHash);
  const plan = createSafeCallPlan(1n, "Escrow consent", [{ safe: capture.prepared.caller, intent: "Record original recovery consent", call: capture.prepared.call, abi: compiledABI.escrow }]);
  verifySafeCallPlan(plan, [compiledABI.escrow]);
  assert.equal(plan.steps[0].transaction.operation, 0);
  assert.equal(plan.steps[0].transaction.value, "0");
});

test("Executor owner schedules without proposer membership; neither authority is rejected", async () => {
  const s = setup("cancelEscrowRecovery");
  s.custom = ({ name }) => name === "owner" ? coder.encode(["address"], [s.actor]) : name === "isProposer" ? coder.encode(["bool"], [false]) : undefined;
  const stage = await s.batchSetup("schedule");
  await w.simulateRevenueEscrowGovernanceStage(s.provider, stage, { blockTag: 10, gasLimit: 5_000_000n });
  s.custom = ({ name }) => name === "isProposer" ? coder.encode(["bool"], [false]) : undefined;
  await assert.rejects(s.batchSetup("schedule"), /proposer authority/);
  const terminal = setup("authorizeTerminalEscrowRecovery", "direct", 2n), freeze = await terminal.batchSetup("schedule");
  const calls = terminal.calls.filter(call => call.name === "terminalFreezeVetoGuardianSet");
  assert.ok(calls.length);
  assert.ok(calls.every(call => call.args[0] === freeze.batch.transition.scopeHash));
  assert.notEqual(freeze.batch.transition.scopeHash, freeze.batch.scopeHash);
});

test("exact mined envelope rejects missing metadata and contradictory receipt endpoints", async () => {
  for (const mutate of [s => delete s.logs[0].transactionHash, s => delete s.logs[0].blockHash, s => delete s.logs[0].blockNumber,
    s => delete s.logs[0].removed, s => s.receipt.from = A(99), s => s.receipt.to = A(99)]) {
    const s = setup(), capture = await s.capture(), tx = s.install(undefined, undefined, s.targetLogs());
    mutate(s);
    await assert.rejects(w.reconcileRevenueEscrowReceipt(s.provider, capture, tx, s.options()));
  }
});

test("local history rejects missing manifest, invalid ref and noncanonical empty record", async () => {
  for (const variant of ["missing", "ref", "factory", "empty"]) {
    const s = setup("executeEscrowRecovery");
    if (variant === "missing") s.base.publishedAt = 0n;
    if (variant === "ref") s.base.record.recoveryManifest.schemaId = H("wrong");
    if (variant === "factory") s.base.record.storedFactory = A(99);
    if (variant === "empty") s.base.record.status = 0n;
    await assert.rejects(w.inspectRevenueEscrowHistory(s.provider, { chainId: 1n, escrow: s.d.escrow }, { recoveryId: s.rid }, { blockTag: 10 }));
  }
});

test("native deployable flush and both retained token flushes reconcile exact delivery", async () => {
  for (const [kind, token] of [["flushEscrow", false], ["flushEscrow", true], ["flushToVerifiedWalletBestEffort", true]]) {
    const s = setup(kind, "indexed", 0n, token);
    if (!token) s.base.walletCode = "0x";
    const capture = await s.capture(), logs = s.targetLogs();
    s.after.walletCode = codes.wallet;
    const tx = s.install(undefined, undefined, logs);
    await w.reconcileRevenueEscrowReceipt(s.provider, capture, tx, s.options());
    s.after.walletCode = "0x";
    await assert.rejects(w.reconcileRevenueEscrowReceipt(s.provider, capture, tx, s.options()), /must be deployed/);
  }
});

test("optional unbound legacy factory probe preserves failed/empty fallback and rejects malformed success", async () => {
  for (const probe of ["0x", coder.encode(["bool"], [false]), "revert"]) {
    const s = setup();
    s.custom = ({ name }) => {
      if (name === "revenueRuntimeRegistry") return coder.encode(["address"], [ZeroAddress]);
      if (name === "revenueRuntimeRegistryCodeHash") return coder.encode(["bytes32"], [ZeroHash]);
      if (name === "supportsInterface") {
        if (probe === "revert") throw Object.assign(Error("legacy"), { code: "CALL_EXCEPTION" });
        return probe;
      }
    };
    const capture = await s.capture();
    assert.equal(capture.noNestedGasEquivalence, true);
    assert.equal(s.calls.some(call => call.to === A(5)), false);
    await w.simulateRevenueEscrow(s.provider, capture, { blockTag: 10, gasLimit: 5_000_000n });
  }
  const bad = setup();
  bad.custom = ({ name }) => name === "revenueRuntimeRegistry" ? coder.encode(["address"], [ZeroAddress])
    : name === "revenueRuntimeRegistryCodeHash" ? coder.encode(["bytes32"], [ZeroHash])
      : name === "supportsInterface" ? "0x01" : undefined;
  await assert.rejects(bad.capture(), /Malformed optional/);
});

test("terminal cleanup is optional but exact cause3 removal must precede the target", async () => {
  for (const variant of ["valid", "wrong-cause", "duplicate", "late"]) {
    const s = setup("authorizeTerminalEscrowRecovery", "indexed", 2n), stage = await s.batchSetup();
    const cleanup = s.event("executor", "TerminalFreezeActionMembershipUpdated", { schemaVersion: 1n,
      scopeHash: stage.batch.transition.scopeHash, actionId: stage.batch.actionId, proposer: s.actor, present: false,
      mutationCause: variant === "wrong-cause" ? 2n : 3n, usesRootCapacity: false, vetoDeadline: stage.batch.window.notBefore,
      rawIndex: 0n, remainingCount: 0n });
    const logs = s.govLogs("execute");
    if (variant === "late") logs.splice(1, 0, cleanup);
    else logs.unshift(cleanup);
    if (variant === "duplicate") logs.unshift(clone(cleanup));
    const tx = s.install(stage.call, stage.caller, logs);
    if (variant === "valid") await w.reconcileRevenueEscrowGovernanceReceipt(s.provider, stage, tx, s.options());
    else await assert.rejects(w.reconcileRevenueEscrowGovernanceReceipt(s.provider, stage, tx, s.options()), /Terminal|terminal/);
  }
});

test("mature notice/class windows and original terminal replay are checked without fabricated private getters", async () => {
  const s = setup("scheduleEscrowRecovery"), stage = await s.batchSetup();
  const tx = s.install(stage.call, stage.caller, s.govLogs("execute"));
  // This mocked young publication isolates the receipt-time guard; original transition admission remains separate.
  s.base.publishedAt = s.timestamp - 100n;
  const youngerCapture = await s.capture();
  const young = { ...stage, capture: youngerCapture };
  await assert.rejects(w.reconcileRevenueEscrowGovernanceReceipt(s.provider, young, tx, s.options()), /notice period/);
  const terminal = setup("authorizeTerminalEscrowRecovery", "direct", 2n), terminalStage = await terminal.batchSetup();
  terminal.fail = "executeGovernanceBatch";
  await assert.rejects(w.simulateRevenueEscrowGovernanceStage(terminal.provider, terminalStage, { blockTag: 10, gasLimit: 5_000_000n }), /original/);
  const schedule = setup("cancelEscrowRecovery"), valid = await schedule.batchSetup("schedule");
  await assert.rejects(w.prepareRevenueEscrowGovernanceStage(schedule.provider, valid.capture,
    { stage: "schedule", caller: schedule.actor, nonce: 7n, window: { ...valid.batch.window, notBefore: schedule.timestamp - 1n }, blockTag: 10 }), /window/);
});
