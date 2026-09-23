import test from "node:test";
import assert from "node:assert/strict";
import { ZeroAddress, ZeroHash, id, keccak256, toUtf8Bytes } from "ethers";
import * as workflow from "../dist/current-scoped-policy-graph-v2-workflow.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";
import { compiledABI } from "./current-scoped-policy-graph-v2-fixture.mjs";
import { setup, A, H, pin, code, safe, coder } from "./current-scoped-policy-graph-v2-workflow-fixture.mjs";

const capture = (f, kind = "prepareGraph", maximumChildren = 3n) => workflow.captureScopedPolicyGraphV2(f.provider,
  f.deployment, f.caller, kind === "prepareGraph" ? { kind, scope: f.scope, maximumChildren } : { kind, scope: f.scope }, { blockTag: 10 });
const simulate = (f, saved, blockTag = 11) => workflow.simulateScopedPolicyGraphV2(f.provider, saved, { blockTag, gasLimit: 10000000n });
const reconcile = (f, saved, receipt) => workflow.reconcileScopedPolicyGraphV2Receipt(f.provider, saved, receipt.txHash, receipt.options);
const historyDeployment = f => ({ chainId: f.deployment.chainId, publicationFactory: f.deployment.publicationFactory,
  recipeHash: f.deployment.recipeHash, sourceFactoryDependenciesHash: f.deployment.sourceFactoryDependenciesHash });

test("source CREATE and retained retry use original direct and both Safe CALL layouts", async () => {
  for (const existing of [false, true]) for (const mode of ["direct", "legacy", "indexed"]) {
    const f = setup({ sourceBefore: existing, beforeCount: 0, afterCount: 0 });
    const saved = await capture(f, "prepareSourceSet");
    assert.equal(saved.sourceSet !== null, existing);
    const checked = await simulate(f, saved);
    assert.equal(checked.result, f.set);
    assert.equal(checked.persisted, false);
    const receipt = f.installReceipt(saved.prepared, mode);
    const result = await reconcile(f, saved, receipt);
    assert.equal(result.createdSourceSet !== null, !existing);
    assert.equal(result.eventlessRetry, existing);
    assert.equal(result.after.inventory.policyChainHash, f.policyChainHash);
  }
});

test("all graph progress boundaries and full retries preserve exact prefix in all transports", async () => {
  for (const [beforeCount, maximumChildren, afterCount] of [[0, 1, 1], [1, 2, 3], [5, 7, 7], [7, 7, 7]]) {
    for (const mode of ["direct", "legacy", "indexed"]) {
      const f = setup({ beforeCount, afterCount });
      const saved = await capture(f, "prepareGraph", BigInt(maximumChildren));
      const checked = await simulate(f, saved);
      assert.equal(checked.result.preparedChildren, BigInt(afterCount));
      const result = await reconcile(f, saved, f.installReceipt(saved.prepared, mode));
      assert.equal(result.createdChildren.length, afterCount - beforeCount);
      assert.equal(result.eventlessRetry, beforeCount === 7);
      assert.equal(result.after.graph.graphId, f.graphId);
      assert.deepEqual(result.after.graph.children.slice(0, beforeCount), saved.graph.children.slice(0, beforeCount));
    }
  }
});

test("TOKEN RELEASE SEASON use complete actual scope and current graph, partial remains insufficient", async () => {
  for (const scopeType of [1n, 2n, 3n]) {
    const scope = { scopeType, collectionId: 7n, tokenId: scopeType === 1n ? 11n : 0n, scopeId: scopeType === 1n ? ZeroHash : H(11) };
    const f = setup({ beforeCount: 7, afterCount: 7, scope });
    const current = await workflow.inspectScopedPolicyGraphV2Current(f.provider, f.deployment, scope, { blockTag: 10 });
    assert.equal(current.currentnessChecked, true);
    assert.deepEqual(current.graph.scope, scope);
  }
  const f = setup({ beforeCount: 6 });
  await assert.rejects(workflow.inspectScopedPolicyGraphV2Current(f.provider, f.deployment, f.scope, { blockTag: 10 }), /incomplete/);
  for (const scopeType of [0n, 4n]) await assert.rejects(workflow.captureScopedPolicyGraphV2(f.provider, f.deployment, f.caller,
    { kind: "prepareSourceSet", scope: { scopeType, collectionId: 7n, tokenId: 0n, scopeId: H(11) } }, { blockTag: 10 }), /TOKEN, RELEASE or SEASON/i);
});

test("complete ordered original coordinators retain explicit and legacy full policies", async () => {
  const f = setup({ mixed: true });
  const saved = await capture(f);
  assert.equal(saved.inventory.policies.length, 2);
  assert.equal(saved.inventory.policies[0].explicitPolicy, true);
  assert.equal(saved.inventory.policies[1].explicitPolicy, false);
  assert.equal(f.state.calls.some(call => call.target === A(72) && call.method === "collectionEntropyPolicy"), false);
  assert.equal(f.state.calls.some(call => call.target === A(70) && call.method === "supportsInterface"
    && call.args[0] === "0x4583f7e1"), true);
  const fallback = setup({ mixed: true });
  fallback.state.hooks.call = ({ target, method, args }) => target === A(72) && method === "supportsInterface"
    && args[0] === "0x4583f7e1" ? [true] : undefined;
  const supportedLegacy = await capture(fallback);
  assert.equal(supportedLegacy.inventory.policies[1].explicitPolicy, false);
  assert.equal(fallback.state.calls.some(call => call.target === A(72) && call.method === "collectionEntropyPolicy"), true);
  for (const mutate of [
    ({ method, values }) => method === "requireCompleteInventory" ? [{ ...values[0], complete: false }] : undefined,
    ({ method, values }) => method === "requireCoordinator" ? [{ ...values[0], firstTokenIndex: 1n }] : undefined,
    ({ method, values }) => method === "sourcePolicyAt" ? [{ ...values[0], policyHash: H(999) }] : undefined,
    ({ method, values }) => method === "collectionEntropyPolicy" ? [{ ...values[0], frozen: false }] : undefined,
    ({ method }) => method === "entropyPolicyFrozen" ? [false, H(1), ZeroAddress, 0n, ZeroHash] : undefined
  ]) {
    const n = setup({ mixed: true }); n.state.hooks.result = mutate;
    await assert.rejects(capture(n), /inventory|Coordinator|policy|evidence|frozen/i);
  }
});

test("source preparation does not inherit selected Metadata/Router or graph-child gates", async () => {
  const f = setup({ sourceBefore: false, beforeCount: 0, afterCount: 0 });
  f.state.wrongSelection = true;
  const saved = await capture(f, "prepareSourceSet");
  await simulate(f, saved);
  assert.equal(f.state.calls.some(call => call.method === "getSatellitePointer"), false);
  const g = setup(); g.state.wrongSelection = true;
  await assert.rejects(capture(g), /selected host/i);
});

test("snapshot/reference allow original monotonic gas raises and reject fixed dependency substitution", async () => {
  const f = setup({ beforeCount: 7, afterCount: 7 });
  f.state.hooks.result = ({ target, method, values }) => method === "dependencies" && target === f.childAddresses[3]
    ? [{ ...values[0], readGas: 250000n, sourceGas: 300000n, inventoryGas: 350000n }]
    : method === "dependencies" && target === f.childAddresses[4]
      ? [{ ...values[0], readGas: 250000n, sourceGas: 300000n, snapshotGas: 350000n, archiveGas: 300000n }] : undefined;
  const saved = await capture(f);
  assert.equal(saved.childDependencies.snapshot.readGas, 250000n);
  assert.equal(saved.childDependencies.reference.snapshotGas, 350000n);
  for (const mutate of [
    ({ target, method, values }, n) => method === "dependencies" && target === n.childAddresses[3] ? [{ ...values[0], readGas: 1n }] : undefined,
    ({ target, method, values }, n) => method === "dependencies" && target === n.childAddresses[4] ? [{ ...values[0], chainId: 2n }] : undefined,
    ({ method }) => method === "dependencyHash" ? [H(999)] : undefined
  ]) {
    const n = setup({ beforeCount: 7 }); n.state.hooks.result = args => mutate(args, n);
    await assert.rejects(capture(n), /gas|dependenc/i);
  }
});

test("saved currentness catches original-block reorg, source drift, and concurrent prefix changes", async () => {
  const f = setup({ beforeCount: 2, afterCount: 5 });
  const saved = await capture(f);
  f.state.blockHashes.set(10, H(9000));
  await assert.rejects(simulate(f, saved), /Pinned block changed/);
  f.state.blockHashes.clear();
  f.state.hooks.result = ({ method, tag, values }) => method === "graphForPlan" && tag === 11 ? [f.graphAt(3)] : undefined;
  await assert.rejects(simulate(f, saved), /facts changed/i);
  f.state.hooks.result = undefined;
  f.state.failCurrent = true;
  await assert.rejects(simulate(f, saved), /source drift/);
  f.state.failCurrent = false;
  await assert.rejects(simulate(f, saved, 9), /before capture/);
});

test("immutable local graph history survives former dependency loss and has canonical missing semantics", async () => {
  const f = setup({ beforeCount: 7, afterCount: 7 });
  f.state.hooks.code = target => target === f.deployment.publicationFactory.address ? undefined : "0x";
  const historical = await workflow.inspectScopedPolicyGraphV2History(f.provider, historyDeployment(f), f.plan, { blockTag: 10 });
  assert.equal(historical.status, "complete");
  assert.equal(historical.currentnessChecked, false);
  assert.equal((await workflow.inspectScopedPolicyGraphV2History(f.provider, historyDeployment(f), ZeroHash, { blockTag: 10 })).status, "missing");
  await assert.rejects(workflow.inspectScopedPolicyGraphV2Current(f.provider, f.deployment, f.scope, { blockTag: 10 }), /runtime/);
  for (const delta of [{ sourceSet: ZeroAddress }, { sourceSetCodeHash: ZeroHash }, { inventoryPlan: ZeroHash }]) {
    f.state.hooks.result = ({ method, values }) => {
      if (method !== "graphForPlan") return undefined;
      const forged = { ...values[0], ...delta };
      forged.graphId = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "bytes32",
        f.pure.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, "bytes32", "address", "bytes32"],
      [id("6529STREAM_SCOPED_POLICY_PUBLICATION_GRAPH_V2"), 1n, f.coordinates.publicationFactory,
        f.deployment.recipeHash, f.deployment.sourceFactoryDependenciesHash, forged.scope,
        forged.inventoryPlan, forged.sourceSet, forged.sourceSetCodeHash]));
      return [forged];
    };
    await assert.rejects(workflow.inspectScopedPolicyGraphV2History(f.provider, historyDeployment(f), f.plan,
      { blockTag: 10 }), /Zero address|Expected bytes32/);
  }
  f.state.hooks.result = ({ method, values }) => method === "graphForPlan" ? [{ ...values[0], graphId: ZeroHash }] : undefined;
  await assert.rejects(workflow.inspectScopedPolicyGraphV2History(f.provider, historyDeployment(f), f.plan, { blockTag: 10 }), /missing graph/i);
});

test("stable six-word provider binding exposes snapshot before actual V2 root selects sources", async () => {
  for (const tagged of [false, true]) for (const includeSanction of [false, true]) {
    const f = setup({ beforeCount: 7, afterCount: 7, tagged });
    const result = await workflow.inspectScopedPolicyGraphV2Discovery(f.provider, f.discoveryDeployment, f.scope,
      { blockTag: 10, includeRoutes: true, includeSanction });
    assert.equal(result.snapshot.address, f.childAddresses[3]);
    assert.equal(result.selection, tagged ? "scoped-policy-v2" : "prior-profile");
    assert.equal(result.routes.length, includeSanction ? 10 : 9);
    assert.equal(result.finalityEstablished, false);
    assert.equal(result.binding.configurationHash, f.binding.configurationHash);
  }
});

test("discovery rejects partial zero tags, wrong provider/recipe/root and malformed route joins", async () => {
  for (const mutate of [
    ({ method, values }) => method === "scopedPolicyPublicationBinding" ? [{ ...values[0], graphGas: values[0].graphGas + 1n }] : undefined,
    ({ method, values }) => method === "scopedPolicyContentRootBinding" ? [{ ...values[0], outputManifest: A(888) }] : undefined,
    ({ method, values }) => method === "requireCurrentRoutes" ? [[...values[0]].reverse()] : undefined,
    ({ method, values }) => method === "finalitySourcesForScope" ? [{ ...values[0], profile: { ...values[0].profile, snapshots: A(888) } }] : undefined
  ]) {
    const f = setup({ beforeCount: 7, tagged: true }); f.state.hooks.result = mutate;
    await assert.rejects(workflow.inspectScopedPolicyGraphV2Discovery(f.provider, f.discoveryDeployment, f.scope,
      { blockTag: 10, includeRoutes: true, includeSanction: true }), /binding|preimage|profile|ordering|families/i);
  }
  const f = setup({ beforeCount: 7, tagged: true });
  f.state.hooks.result = ({ method, values }) => method === "scopedPolicyContentRootBinding" ? [{ ...values[0], profileId: ZeroHash }]
    : method === "finalitySourcesForScope" ? [{ ...values[0], profile: { ...values[0].profile, profileHash: H(2) } }] : undefined;
  await assert.rejects(workflow.inspectScopedPolicyGraphV2Discovery(f.provider, f.discoveryDeployment, f.scope,
    { blockTag: 10, includeRoutes: false, includeSanction: false }), /absent V2 root/);
});

test("graph receipt requires exact consecutive new-child schema/event count and order", async () => {
  for (const mutate of [
    f => f.state.receipt.logs.splice(0, 1),
    f => f.state.receipt.logs.reverse(),
    f => f.state.receipt.logs.push(structuredClone(f.state.receipt.logs[0])),
    f => { const e = f.c.publicationFactory.encodeEventLog(f.c.publicationFactory.getEvent("ScopedPolicyPublicationChildPrepared"),
      [1n, f.graphId, f.plan, 0n, f.childAddresses[0], pin(f.childAddresses[0]).codeHash]); Object.assign(f.state.receipt.logs[0], e); },
    f => { f.state.afterCount = 4; },
    f => f.state.missingCode.add(f.childAddresses[2])
  ]) {
    const f = setup(); const saved = await capture(f); const receipt = f.installReceipt(saved.prepared);
    mutate(f); f.renumber();
    await assert.rejects(reconcile(f, saved, receipt), /event|progress|runtime/i);
  }
});

test("source creation binds data/runtime, while eventless retries require retained prior entry", async () => {
  for (const mutate of [
    f => { f.state.receipt.logs = []; },
    f => { const e = f.c.sourceFactory.encodeEventLog(f.c.sourceFactory.getEvent("EntropySourceSetPrepared"),
      [f.plan, f.set, f.membership.scopeSubject, pin(f.set).codeHash, H(900)]); Object.assign(f.state.receipt.logs[0], e); },
    f => { f.state.hooks.result = ({ method, tag, values }) => method === "sourceSetDataHash" && tag === 12 ? [H(900)] : undefined; }
  ]) {
    const f = setup({ sourceBefore: false, afterCount: 0 }); const saved = await capture(f, "prepareSourceSet");
    const receipt = f.installReceipt(saved.prepared); mutate(f); f.renumber();
    await assert.rejects(reconcile(f, saved, receipt), /event|evidence/i);
  }
  const f = setup({ sourceBefore: true, afterCount: 0 }); const saved = await capture(f, "prepareSourceSet");
  const receipt = f.installReceipt(saved.prepared);
  f.state.hooks.result = ({ method, tag }) => method === "sourceSetForPlan" && tag === 11 ? [ZeroAddress, ZeroHash] : undefined;
  await assert.rejects(reconcile(f, saved, receipt), /facts changed/i);
});

test("direct and Safe receipt transport binds independent hash, exact CALL, endpoints and ordering", async () => {
  for (const mutate of [
    (f, receipt) => { receipt.options.expectedSafeTxHash = H(999); },
    f => { const last = f.state.receipt.logs.at(-1); last.topics[0] = safe.getEvent("ExecutionFailure").topicHash; },
    f => f.state.receipt.logs.unshift(f.state.receipt.logs.pop()),
    f => { const tx = safe.decodeFunctionData("execTransaction", f.state.transaction.data); f.state.transaction.data = safe.encodeFunctionData("execTransaction",
      [tx.to, tx.value, tx.data, 1, tx.safeTxGas, tx.baseGas, tx.gasPrice, tx.gasToken, tx.refundReceiver, tx.signatures]); },
    f => { f.state.transaction.value = 1n; },
    f => { f.state.transaction.from = A(999); },
    f => { f.state.receipt.logs[0].removed = true; },
    f => { f.state.receipt.logs[0].index = NaN; },
    f => { delete f.state.receipt.logs[0].blockHash; }
  ]) {
    const f = setup(); const saved = await capture(f); const receipt = f.installReceipt(saved.prepared, "indexed");
    mutate(f, receipt);
    if (f.state.receipt.logs[0]?.address === f.caller) f.renumber();
    await assert.rejects(reconcile(f, saved, receipt), /Safe|safe|value|envelope|identity|block|index|CALL|execution/i);
  }
  const f = setup(); const saved = await capture(f); const receipt = f.installReceipt(saved.prepared);
  f.state.transaction.data = "0x12345678";
  await assert.rejects(reconcile(f, saved, receipt), /Direct caller/);
  await assert.rejects(workflow.reconcileScopedPolicyGraphV2Receipt(f.provider, saved, receipt.txHash, { execution: "delegatecall" }), /Unknown execution/);
});

test("copied receipt bytes resist post-await mutation and legal unrelated zero topics remain accepted", async () => {
  const f = setup(); const saved = await capture(f); const receipt = f.installReceipt(saved.prepared, "legacy");
  f.state.receipt.logs.unshift({ address: A(900), topics: [ZeroHash], data: "0x" }); f.renumber();
  f.state.hooks.transaction = () => { f.state.receipt.logs.at(-1).data = coder.encode(["bytes32", "uint256"], [H(999), 0n]); };
  const result = await reconcile(f, saved, receipt);
  assert.equal(result.createdChildren.length, 3);
});

test("refusal reports original revert versus RPC failure and only observed retention", async () => {
  for (const code of ["CALL_EXCEPTION", "NETWORK_ERROR"]) {
    const f = setup({ beforeCount: 7 }); const saved = await capture(f);
    f.state.hooks.call = ({ method, tag }) => { if (tag === 11 && method === "prepareGraph") throw Object.assign(Error("deliberate refusal"), { code }); };
    const result = await workflow.observeScopedPolicyGraphV2Refusal(f.provider, saved, { blockTag: 11, gasLimit: 10000000n });
    assert.equal(result.outcome, code === "CALL_EXCEPTION" ? "execution-reverted" : "rpc-failed");
    assert.equal(result.retainedGraphUnchanged, true); assert.equal(result.retainedSourceUnchanged, true); assert.equal(result.rollbackProven, false);
  }
});

test("input snapshots, canonical RPC bounds and gas limits are enforced before trusting observations", async () => {
  const f = setup(); const d = structuredClone(f.deployment), scope = structuredClone(f.scope);
  f.state.hooks.network = () => { d.recipeHash = H(999); scope.tokenId = 777n; };
  const saved = await workflow.captureScopedPolicyGraphV2(f.provider, d, f.caller,
    { kind: "prepareGraph", scope, maximumChildren: 3n }, { blockTag: 10 });
  assert.equal(saved.prepared.request.scope.tokenId, 11n); assert.equal(saved.deployment.recipeHash, f.deployment.recipeHash);
  f.state.hooks.network = undefined;
  for (const gasLimit of [0n, 100000001n]) await assert.rejects(workflow.simulateScopedPolicyGraphV2(f.provider, saved, { blockTag: 11, gasLimit }), /Gas limit/);
  const n = setup(); n.state.raw = (event, value) => event.method === "recipeHash" ? `${value}${"00".repeat(32)}` : value;
  await assert.rejects(capture(n), /Noncanonical RPC/);
  const marker = `0xef0100${A(900).slice(2)}`;
  const m = setup(); m.deployment.publicationFactory.codeHash = keccak256(marker);
  m.state.hooks.code = target => target === m.deployment.publicationFactory.address ? marker : undefined;
  await assert.rejects(capture(m), /runtime/);
  const q = setup(); q.progress.coordinatorCount = 257n; q.progress.tokenCount = 257n; q.progress.processedTokens = 257n;
  await assert.rejects(capture(q), /bounded inventory/);
});

test("generic Safe planner round-trip keeps actual factory method, value and caller", async () => {
  for (const kind of ["prepareSourceSet", "prepareGraph"]) {
    const f = setup(); const saved = await capture(f, kind);
    const catalog = compiledABI(kind === "prepareGraph" ? "publicationFactory" : "sourceFactory");
    const plan = createSafeCallPlan(1n, "Prepare scoped policy graph", [{ safe: f.caller, intent: "Permissionless preparation", call: saved.prepared.call, abi: catalog }]);
    verifySafeCallPlan(plan, [catalog]);
    assert.equal(plan.steps[0].transaction.operation, 0);
    assert.equal(plan.steps[0].transaction.value, "0");
    assert.equal(plan.steps[0].transaction.to, saved.prepared.call.to);
    assert.equal(plan.steps[0].transaction.data, saved.prepared.call.data);
    const corrupt = structuredClone(plan); corrupt.steps[0].transaction.operation = 1;
    assert.throws(() => verifySafeCallPlan(corrupt, [catalog]), /CALL|operation/);
  }
});

test("full retries still recheck actual current source and mined child runtimes", async () => {
  const f = setup({ beforeCount: 7, afterCount: 7 }); const saved = await capture(f);
  const receipt = f.installReceipt(saved.prepared);
  f.state.hooks.call = ({ method, tag }) => { if (tag === 12 && method === "requireCurrentSourceSet") throw Error("mined source stale"); };
  await assert.rejects(reconcile(f, saved, receipt), /source stale/);
  f.state.hooks.call = undefined;
  f.state.hooks.code = (target, tag) => tag === 12 && target === f.childAddresses[6] ? "0x6001" : undefined;
  await assert.rejects(reconcile(f, saved, receipt), /runtime/);
});

test("original empty V1 binding, impossible zero-child persistence and reviewed worker pins stay distinct", async () => {
  const f = setup({ beforeCount: 7, afterCount: 7, tagged: false });
  f.state.hooks.result = ({ method, values }) => method === "scopedContentRootHead" ? [H(777)]
    : method === "scopedPolicyContentRootBinding" ? [f.c.router.decodeFunctionResult(method, `0x${"00".repeat(736)}`)[0]] : undefined;
  const priorProfile = await workflow.inspectScopedPolicyGraphV2Discovery(f.provider, f.discoveryDeployment, f.scope,
    { blockTag: 10, includeRoutes: false, includeSanction: false });
  assert.equal(priorProfile.selection, "prior-profile");
  const n = setup();
  n.state.hooks.result = ({ method }) => method === "graphForPlan" ? [{ ...n.full, preparedChildren: 0n }] : undefined;
  await assert.rejects(capture(n), /child count/);
  const w = setup(); const saved = await capture(w); const receipt = w.installReceipt(saved.prepared);
  w.state.hooks.code = (target, tag) => tag === 12 && target === w.deployment.linkedDependencies[0].address ? "0x" : undefined;
  await assert.rejects(reconcile(w, saved, receipt), /runtime/);
  const b = setup(); const original = await capture(b); const tx = b.installReceipt(original.prepared, "legacy");
  b.state.transaction.data = `0x${"00".repeat(81921)}`;
  await assert.rejects(reconcile(b, original, tx), /oversized bytes/);
});
