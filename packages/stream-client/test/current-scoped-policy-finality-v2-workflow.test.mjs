import test from "node:test";
import assert from "node:assert/strict";
import { ZeroAddress as Z, ZeroHash as H0, id, keccak256 } from "ethers";
import * as w from "../dist/current-scoped-policy-finality-v2-workflow.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";
import { setup, A, H, pin, coder, safe, c, p, fixture } from "./current-scoped-policy-finality-v2-workflow-fixture.mjs";

const options = { blockTag: 10, gasLimit: 90000000n };
const capture = f => w.captureScopedPolicyFinalityV2(f.provider, f.deployment, f.prepared, options);
const reconcile = (f, saved, tx) => w.reconcileScopedPolicyFinalityV2Receipt(f.provider, saved, tx.txHash, tx.options);
const stages = ["stageFinalityManifest", "publishGovernanceCallData", "scheduleGovernanceBatch", "executeGovernanceBatch"];
function replaceEvent(f, target, iface, name, mutate) {
  const log = f.state.receipt.logs.find(log => log.address === target && log.topics[0] === iface.getEvent(name).topicHash);
  assert.ok(log, name);
  const args = [...iface.decodeEventLog(name, log.data, log.topics)];
  mutate(args);
  const encoded = iface.encodeEventLog(iface.getEvent(name), args);
  log.topics = [...encoded.topics]; log.data = encoded.data;
}

test("four original outer stages capture, simulate and reconcile direct/legacy/indexed Safe CALL", async () => {
  for (const kind of stages) {
    const f = setup({ kind });
    const saved = await capture(f);
    const simulation = await w.simulateScopedPolicyFinalityV2(f.provider, saved, { ...options, blockTag: 11 });
    assert.equal(simulation.originalCallSimulated, true);
    assert.equal(simulation.submitted, false);
    for (const mode of ["direct", "legacy", "indexed"]) {
      const result = await reconcile(f, saved, f.installReceipt(mode));
      assert.equal(result.kind, kind);
      assert.equal(result.exactCallAuthenticated, true);
      assert.equal(result.receiptAttribution, "unchanged-preceding-block-and-exact-end-block");
      assert.equal(result.history?.status ?? null, kind === "executeGovernanceBatch" ? "finalized" : null);
    }
  }
});

test("TOKEN, RELEASE and SEASON retain full original scope and permanent manifest identities", async () => {
  for (const scope of [
    { scopeType: 1n, collectionId: 7n, tokenId: 11n, scopeId: H0 },
    { scopeType: 2n, collectionId: 7n, tokenId: 0n, scopeId: H(22) },
    { scopeType: 3n, collectionId: 7n, tokenId: 0n, scopeId: H(33) }
  ]) {
    const f = setup({ kind: "executeGovernanceBatch", scope });
    const saved = await capture(f), tx = f.installReceipt();
    const r = await reconcile(f, saved, tx);
    assert.deepEqual(r.history.record.scope, scope);
    assert.equal(r.history.record.finalityRecordHash, f.plan.execution.finalityRecordHash);
    assert.equal(r.history.components.length, 10);
  }
});

test("manifest and Executor publication retries are eventless only with retained prior bytes", async () => {
  for (const kind of stages.slice(0, 2)) {
    const retained = setup({ kind, stagedBefore: true, publishedBefore: true });
    const old = await capture(retained), tx = retained.installReceipt("indexed");
    assert.equal(retained.state.receipt.logs.length, 1);
    await reconcile(retained, old, tx);
    const fresh = setup({ kind }), saved = await capture(fresh), freshTx = fresh.installReceipt();
    fresh.state.receipt.logs.length = 0;
    await assert.rejects(reconcile(fresh, saved, freshTx), /event count/);
  }
});

test("local staging and publication remain available when source/Artist/roles are unavailable", async () => {
  for (const kind of stages.slice(0, 2)) {
    const f = setup({ kind });
    for (const a of [f.coords.artist, f.deployment.roles.address, f.deployment.source.provider.address, f.coords.core]) f.state.missingCode.add(a);
    f.base.state.failCurrent = true;
    const saved = await capture(f);
    await w.simulateScopedPolicyFinalityV2(f.provider, saved, { ...options, blockTag: 11 });
    await reconcile(f, saved, f.installReceipt());
  }
});

test("source admission rejects stale graph, absent V2 root and changed actual full evidence", async () => {
  for (const failure of ["graph", "root", "core", "inventory", "bundle", "context", "adapter", "configuration"]) {
    const f = setup();
    if (failure === "graph") f.base.state.failCurrent = true;
    if (failure === "root") f.base.state.tagged = false;
    if (failure === "core") f.state.coreFacts.collectionConfigHash = H(999);
    if (failure === "inventory") f.inventory.inventory.itemCount++;
    if (failure === "bundle") f.bundle.coverage.bundleCoverageHash = H(999);
    if (failure === "adapter") f.discoveryConfiguration.routerAdapters[0] = A(999);
    if (failure === "configuration") f.sourceConfiguration.profiles[0].configurationHash = H(999);
    if (failure === "context") f.state.hooks.result = ({ method, values }) => method === "finalityExecutionContextWithArchive"
      ? [{ ...values[0], newValueHash: H(999) }] : undefined;
    await assert.rejects(capture(f), /drift|V2|profile|differ|commitment/);
  }
});

test("active input definitions and retired retained sanction definitions have distinct rules", async () => {
  const f = setup();
  assert.ok([...f.documents.values()].slice(2).every(d => d.doc.status === 1n));
  await capture(f);
  f.documents.get(p.SCOPED_POLICY_FINALITY_V2_SCHEMA).facts.status = 1n;
  await assert.rejects(capture(f), /Active finality/);
  const g = setup();
  g.documents.get(id("6529STREAM_ARTIST_SANCTION_CEREMONY_V1")).raw = "0x1234";
  await assert.rejects(capture(g), /Sanction definition bytes/);
});

test("archive coverage binds the existing Artist sanction, two distinct families and complete byte count", async () => {
  for (const field of ["artistId", "contentHash", "chunkCount", "secondFamilyRecordHash"]) {
    const f = setup();
    f.state.hooks.result = ({ method, values }) => method === "requireArtifactCoverage"
      ? [{ ...values[0], [field]: field === "chunkCount" ? 1n : field === "secondFamilyRecordHash" ? values[0].firstFamilyRecordHash : H(999) }]
      : undefined;
    await assert.rejects(capture(f), /archive|families/i);
  }
});

test("schedule owner authority is independent of registered proposer; execute uses stored proposer role", async () => {
  const owner = setup({ caller: A(805) }); owner.state.isProposer = false;
  assert.equal((await capture(owner)).governance.usesRootCapacity, true);
  const stranger = setup(); stranger.state.isProposer = false;
  await assert.rejects(capture(stranger), /proposer authority/);
  const exec = setup({ kind: "executeGovernanceBatch", caller: A(40), proposer: A(30) });
  const saved = await capture(exec);
  assert.equal(saved.governance.action.proposer, A(30));
  const result = await reconcile(exec, saved, exec.installReceipt("legacy"));
  assert.equal(result.history.executionWitness.proposer, A(30));
  exec.state.hasAdmin = false;
  exec.state.receipt = null;
  await assert.rejects(capture(exec), /Stored proposer/);
});

test("Executor prerequisites reject unbound/unsealed/catalog/nonce/guardian and scheduled context drift", async () => {
  for (const fault of ["bound", "sealed", "catalog", "nonce", "guardian", "calldata", "scope"]) {
    const f = setup({ kind: ["guardian", "calldata", "scope"].includes(fault) ? "executeGovernanceBatch" : "scheduleGovernanceBatch" });
    if (fault === "bound") f.state.bound = false;
    if (fault === "sealed") f.state.sealed = false;
    if (fault === "catalog") f.state.catalog[2] = 0n;
    if (fault === "guardian") f.state.guardianCommitment = H(999);
    f.state.hooks.result = ({ method, values }) => fault === "nonce" && method === "governanceNonce" ? [100n]
      : fault === "calldata" && method === "scheduledCallData" ? [["0x1234"]]
      : fault === "scope" && method === "governanceAction" ? [{ ...values[0], scopeHash: f.plan.execution.scopeHash }] : undefined;
    await assert.rejects(capture(f), /bound|sealed|catalog|nonce|guardian|calldata|scopeHash/i);
  }
});

test("inclusive class-2 execution endpoints and mined expiration are enforced", async () => {
  for (const end of ["notBefore", "expiresAfter"]) {
    const f = setup({ kind: "executeGovernanceBatch" });
    f.provider.getBlock = async tag => ({ number: tag, hash: H(1000 + tag), timestamp: Number(f.batch.window[end]) });
    const saved = await capture(f);
    const tx = f.installReceipt();
    // Source-shaped mined timestamp in the retained record follows the controlled block.
    f.state.hooks.result = ({ method, values }) => method === "artworkScopeFinalityRecord" && values[0].finalized
      ? [{ ...values[0], finalizedAt: f.batch.window[end] }] : undefined;
    await reconcile(f, saved, tx);
  }
  const expired = setup({ kind: "executeGovernanceBatch" });
  expired.provider.getBlock = async tag => ({ number: tag, hash: H(1000 + tag),
    timestamp: Number(expired.batch.window.expiresAfter + (tag === 12 ? 1n : 0n)) });
  const saved = await capture(expired);
  await assert.rejects(reconcile(expired, saved, expired.installReceipt()), /outside inclusive/);
});

test("original calls remain decisive for catalog/source refusal; RPC failure is distinct from execution revert", async () => {
  for (const code of ["CALL_EXCEPTION", "NETWORK_ERROR"]) {
    const f = setup(), saved = await capture(f);
    f.state.originalFailure = Object.assign(Error("Original target/catalog refusal"), { code, data: "0x1234" });
    await assert.rejects(w.simulateScopedPolicyFinalityV2(f.provider, saved, { ...options, blockTag: 11 }), /Original target/);
    const refused = await w.observeScopedPolicyFinalityV2Refusal(f.provider, saved, { ...options, blockTag: 11 });
    assert.equal(refused.outcome, code === "CALL_EXCEPTION" ? "execution-reverted" : "rpc-failed");
    assert.equal(refused.nativeRollbackProven, false);
    assert.equal(refused.failure.data, "0x1234");
  }
});

test("history authenticates retained manifest Core facts and ten components despite all upstream retirement", async () => {
  const f = setup({ finalized: true });
  for (const a of [f.coords.core, f.coords.metadata, f.coords.artist, f.coords.executor, f.coords.artifactCoverage, f.deployment.source.provider.address]) f.state.missingCode.add(a);
  const history = await w.inspectScopedPolicyFinalityV2History(f.provider, f.historyDeployment, f.scope, { blockTag: 20 });
  assert.equal(history.status, "finalized");
  assert.equal(history.currentnessChecked, false);
  assert.equal(history.transactionAuthenticated, false);
  assert.ok(f.state.calls.every(call => call.target === f.coords.registry));
  const empty = setup();
  assert.equal((await w.inspectScopedPolicyFinalityV2History(empty.provider, empty.historyDeployment, empty.scope, { blockTag: 10 })).status, "empty");
});

test("history rejects fully rehashed zero archive proof fields without requiring live archive reads", async () => {
  for (const key of ["artifactHash", "completionHash"]) {
    const f = setup({ finalized: true });
    f.archiveWitness.proof = { ...f.proof, [key]: H0 };
    f.archiveWitness.evidenceHash = p.scopedPolicyFinalityV2ArchiveEvidenceHash(f.coords, f.archiveWitness.proof);
    await assert.rejects(w.inspectScopedPolicyFinalityV2History(f.provider, f.historyDeployment, f.scope, { blockTag: 20 }), /hash|zero|bytes32/i);
  }
});

test("historical scope, components, canonical bytes, future timestamp and empty records join exactly", async () => {
  for (const fault of ["scope", "component", "manifest", "future", "empty"]) {
    const f = setup({ finalized: fault !== "empty" });
    f.state.hooks.result = ({ method, values }) => {
      if (method === "artworkScopeFinalityRecord" && fault === "scope") return [{ ...values[0], scope: { ...f.scope, collectionId: 8n } }];
      if (method === "artworkScopeFinalityRecord" && fault === "future") return [{ ...values[0], finalizedAt: 999999999n }];
      if (method === "artworkScopeFinalityRecord" && fault === "empty") return [{ ...values[0], finalityRecordHash: H(999) }];
      if (method === "finalityComponentsForScope" && fault === "component") return [[...values[0].slice(0, -1), { ...values[0].at(-1), dataHash: H(999) }]];
      if (method === "finalityManifestBytes" && fault === "manifest") return [`${values[0]}00`];
    };
    await assert.rejects(w.inspectScopedPolicyFinalityV2History(f.provider, f.historyDeployment, f.scope, { blockTag: 20 }));
  }
});

test("current diagnostic false is distinct from retained finalization and range checks are explicitly partial", async () => {
  const f = setup({ finalized: true }); f.state.diagnosticMatches = false;
  const current = await w.inspectScopedPolicyFinalityV2Current(f.provider, f.diagnosticDeployment, f.scope, { ...options, blockTag: 20 });
  assert.equal(current.matches, false); assert.equal(current.historical.status, "finalized");
  assert.equal(current.freshFinalizationAdmissionChecked, false);
  const range = await w.inspectScopedPolicyFinalityV2Current(f.provider, f.diagnosticDeployment, f.scope,
    { ...options, blockTag: 20, range: { start: 0n, limit: 2n } });
  assert.equal(range.scope, "selected-component-range");
  f.state.missingCode.add(f.deployment.linkedDependencies[0].address);
  await assert.rejects(w.inspectScopedPolicyFinalityV2Current(f.provider, f.diagnosticDeployment, f.scope, { ...options, blockTag: 20 }), /runtime/i);
  assert.equal((await w.inspectScopedPolicyFinalityV2History(f.provider, f.historyDeployment, f.scope, { blockTag: 20 })).status, "finalized");
});

test("execution receipts reject missing, duplicate or reordered exact events", async () => {
  for (const fault of ["missing", "duplicate", "order", "witness"]) {
    const f = setup({ kind: "executeGovernanceBatch" }), saved = await capture(f), tx = f.installReceipt("indexed");
    if (fault === "missing") f.state.receipt.logs.splice(3, 1);
    if (fault === "duplicate") f.state.receipt.logs.splice(3, 0, structuredClone(f.state.receipt.logs[3]));
    if (fault === "order") [f.state.receipt.logs[1], f.state.receipt.logs[2]] = [f.state.receipt.logs[2], f.state.receipt.logs[1]];
    if (fault === "witness") replaceEvent(f, f.coords.registry, c.finality, "FinalityExecutionWitnessRecorded", args => { args[5] = H(999); });
    f.renumber();
    await assert.rejects(reconcile(f, saved, tx), /event|matching|order|exactly one|Recorded differs/i);
  }
});

test("receipt runtime checks cover dynamic routes/sourceSet, graph children, linked workers, root and guardians", async () => {
  const f = setup(), saved = await capture(f), tx = f.installReceipt();
  for (const address of [A(600), f.base.set, f.base.childAddresses[0], f.deployment.linkedDependencies[0].address,
    f.state.root.address, f.guardianHolders[0][0].address]) {
    f.state.hooks.code = (target, tag) => tag === 12 && target === address ? "0x6001" : undefined;
    await assert.rejects(reconcile(f, saved, tx), /runtime/i);
  }
});

test("changed preceding state and extra same-block completion are conservatively refused", async () => {
  const f = setup(), saved = await capture(f), tx = f.installReceipt();
  f.state.hooks.result = ({ method, tag }) => method === "governanceNonce" && tag === 11 ? [5n] : undefined;
  await assert.rejects(reconcile(f, saved, tx), /nonce changed/);
  f.state.hooks.result = ({ method, tag }) => method === "governanceNonce" && tag === 12 ? [6n] : undefined;
  await assert.rejects(reconcile(f, saved, tx), /Mined governance nonce/);
  f.state.hooks.result = undefined;
  f.state.blockHashes.set(10, H(999));
  await assert.rejects(reconcile(f, saved, tx), /block|reorg/i);
});

test("Safe requires independent hash, success after target, exact CALL and unchanged original data/value", async () => {
  const f = setup({ kind: "stageFinalityManifest" }), saved = await capture(f);
  for (const fault of ["hash", "missingHash", "failure", "order", "delegate", "value", "data"]) {
    const tx = f.installReceipt("legacy");
    if (fault === "hash") tx.options.expectedSafeTxHash = H(999);
    if (fault === "missingHash") delete tx.options.expectedSafeTxHash;
    if (fault === "failure") f.state.receipt.logs.at(-1).topics[0] = safe.getEvent("ExecutionFailure").topicHash;
    if (fault === "order") f.state.receipt.logs.reverse();
    if (["delegate", "value", "data"].includes(fault)) {
      const args = [...safe.decodeFunctionData("execTransaction", f.state.transaction.data)];
      args[fault === "delegate" ? 3 : fault === "value" ? 1 : 2] = fault === "delegate" ? 1n : fault === "value" ? 1n : "0x1234";
      f.state.transaction.data = safe.encodeFunctionData("execTransaction", args);
    }
    f.renumber();
    await assert.rejects(reconcile(f, saved, tx));
  }
});

test("receipt transport copies complete logs before first post-receipt await and rejects malformed identities", async () => {
  const f = setup({ kind: "stageFinalityManifest" }), saved = await capture(f), tx = f.installReceipt("indexed");
  f.state.hooks.transaction = () => { f.state.receipt.logs[0].data = "0x"; };
  await reconcile(f, saved, tx);
  f.state.hooks.transaction = undefined;
  for (const fault of ["removed", "index", "block", "from", "missing"]) {
    const t = f.installReceipt();
    if (fault === "removed") f.state.receipt.logs[0].removed = true;
    if (fault === "index") f.state.receipt.logs[0].index = NaN;
    if (fault === "block") f.state.receipt.logs[0].blockHash = H(999);
    if (fault === "from") f.state.receipt.from = A(999);
    if (fault === "missing") delete f.state.receipt.logs[0].transactionHash;
    await assert.rejects(reconcile(f, saved, t));
  }
});

test("pre-await ownership, network and bounded data reject contradictory caller-controlled inputs", async () => {
  const f = setup({ kind: "stageFinalityManifest" });
  const d = structuredClone(f.deployment), plan = structuredClone(f.prepared), o = { ...options };
  f.state.hooks.network = () => { d.registry.address = A(999); plan.call.data = "0x"; o.blockTag = 11; };
  const saved = await w.captureScopedPolicyFinalityV2(f.provider, d, plan, o);
  assert.equal(saved.observed.blockNumber, 10); assert.equal(saved.deployment.registry.address, f.coords.registry);
  f.state.hooks.network = undefined; f.state.network = 2n;
  await assert.rejects(capture(f), /chain/i);
  f.state.network = 1n;
  await assert.rejects(w.captureScopedPolicyFinalityV2(f.provider, f.deployment, f.prepared, { ...options, blockTag: -1 }));
  await assert.rejects(w.captureScopedPolicyFinalityV2(f.provider, f.deployment, f.prepared, { ...options, gasLimit: 100000001n }));
  const marker = `0xef0100${A(900).slice(2)}`, bad = structuredClone(f.deployment);
  bad.registry.codeHash = keccak256(marker); f.state.hooks.code = target => target === f.coords.registry ? marker : undefined;
  await assert.rejects(w.captureScopedPolicyFinalityV2(f.provider, bad, f.prepared, options), /delegated|runtime/i);
});

test("generic Safe planning preserves each outer call and excludes direct Registry finalization", async () => {
  for (const kind of stages) {
    const f = setup({ kind }), abi = fixture.abis[kind === "stageFinalityManifest" ? "finality" : "executor"];
    const plan = createSafeCallPlan(1n, "Original historical scoped finality stage", [{ safe: f.caller,
      intent: "Perform the reviewed original stage", call: f.prepared.call, abi }]);
    assert.equal(verifySafeCallPlan(plan, [abi]).hash, plan.hash);
    assert.equal(plan.steps[0].transaction.operation, 0);
    assert.notEqual(f.prepared.call.data.slice(0, 10), f.plan.targetCall.data.slice(0, 10));
  }
  const f = setup();
  assert.throws(() => p.prepareScopedPolicyFinalityV2Call(f.coords, f.caller, { kind: "finalizeArtworkScopeWithArchive", batch: f.batch }));
});

test("terminal membership compacts at the exact deadline and execution permits already-pruned membership", async () => {
  const f = setup(), old = H(980), live = H(981), deadline = BigInt(f.time(12));
  f.state.hooks.result = ({ method, tag }) => method === "terminalFreezeActionPage"
    ? tag < 12 ? [[old, live], [deadline, f.batch.window.notBefore], 2n]
      : [[live, f.batch.actionId], [f.batch.window.notBefore, f.batch.window.notBefore], 2n] : undefined;
  const saved = await capture(f), tx = f.installReceipt();
  replaceEvent(f, f.coords.executor, c.executor, "TerminalFreezeActionMembershipUpdated", args => { args[8] = 1n; args[9] = 2n; });
  const removed = c.executor.encodeEventLog(c.executor.getEvent("TerminalFreezeActionMembershipUpdated"),
    [1n, f.plan.execution.scopeHash, old, A(33), false, 2n, false, deadline, 0n, 1n]);
  f.state.receipt.logs.unshift({ address: f.coords.executor, topics: [...removed.topics], data: removed.data });
  f.renumber();
  await reconcile(f, saved, tx);
  const originalRemoval = structuredClone(f.state.receipt.logs[0]);
  replaceEvent(f, f.coords.executor, c.executor, "TerminalFreezeActionMembershipUpdated", args => { args[8] = 1n; });
  await assert.rejects(reconcile(f, saved, tx), /membership removal differs/);
  f.state.receipt.logs[0] = structuredClone(originalRemoval);
  replaceEvent(f, f.coords.executor, c.executor, "TerminalFreezeActionMembershipUpdated", args => { args[5] = 3n; });
  await assert.rejects(reconcile(f, saved, tx), /membership removal differs/);
  f.state.receipt.logs[0] = structuredClone(originalRemoval);
  [f.state.receipt.logs[0], f.state.receipt.logs[1]] = [f.state.receipt.logs[1], f.state.receipt.logs[0]];
  f.renumber();
  await assert.rejects(reconcile(f, saved, tx), /membership removal differs/);
  const e = setup({ kind: "executeGovernanceBatch" });
  e.state.hooks.result = ({ method }) => method === "terminalFreezeActionPage" ? [[], [], 0n] : undefined;
  const prior = await capture(e), executed = e.installReceipt();
  e.state.receipt.logs.shift(); e.renumber();
  await reconcile(e, prior, executed);
});

test("strict-later receipt, outer byte cap, direct endpoints and canonical RPC bounds remain explicit", async () => {
  const f = setup({ kind: "stageFinalityManifest" }), saved = await capture(f);
  for (const fault of ["same-block", "outer", "caller", "target", "value", "transport"]) {
    const tx = f.installReceipt();
    if (fault === "same-block") {
      Object.assign(f.state.receipt, { blockNumber: 10, blockHash: H(1010) });
      Object.assign(f.state.transaction, { blockNumber: 10, blockHash: H(1010) });
    }
    if (fault === "outer") f.state.transaction.data = `0x${"00".repeat(2097152 + 16385)}`;
    if (fault === "caller") f.state.transaction.from = f.state.receipt.from = A(99);
    if (fault === "target") f.state.transaction.to = f.state.receipt.to = A(99);
    if (fault === "value") f.state.transaction.value = 1n;
    if (fault === "transport") tx.options.execution = "delegatecall";
    f.renumber();
    await assert.rejects(reconcile(f, saved, tx));
  }
  f.state.hooks.call = ({ method }) => method === "finalityManifestStored" ? `0x${"00".repeat(31)}02` : undefined;
  await assert.rejects(capture(f), /canonical/i);
});

test("diagnostic options and reviewed links are copied before the first asynchronous provider read", async () => {
  const f = setup({ finalized: true }), deployment = structuredClone(f.diagnosticDeployment);
  const request = { ...options, blockTag: 20, range: { start: 0n, limit: 2n } };
  f.state.hooks.network = () => { request.blockTag = 21; request.range.limit = 99n; deployment.linkedDependencies[0].address = A(999); };
  const result = await w.inspectScopedPolicyFinalityV2Current(f.provider, deployment, f.scope, request);
  assert.equal(result.historical.observed.blockNumber, 20);
  assert.deepEqual(result.range, { start: 0n, limit: 2n });
  assert.ok(f.state.calls.every(call => call.tag === 20));
});
