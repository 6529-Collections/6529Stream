import test from "node:test";
import assert from "node:assert/strict";
import { keccak256, toUtf8Bytes } from "ethers";
import * as workflow from "../dist/current-tagged-policy-view-v2-workflow.js";
import * as view from "../dist/current-tagged-policy-view-v2.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";
import { compiledABI } from "./current-tagged-policy-view-v2-fixture.mjs";
import { setup, A, H, Z, ZA, c, safeABI } from "./current-tagged-policy-view-v2-workflow-fixture.mjs";

const capture = f => workflow.captureTaggedPolicyViewV2(f.provider, f.d, f.caller, f.input, { blockTag: 10 });
const normalizeLogs = f => f.receipt.logs.forEach((log, index) => { log.index = index; });

test("preflight derives the literal source and original op17 terms before stored consent is required", async () => {
  const f = setup();
  f.overrides = entry => { if (entry.name === "contentConsentEvidence") throw Error("No consent yet"); };
  const preflight = await workflow.preflightTaggedPolicyViewV2(f.provider, f.d, f.caller, f.input, { blockTag: 10 });
  assert.notEqual(preflight.input.expectedSourceHash, Z);
  assert.equal(preflight.consentTerms.newStateHash, f.family);
  assert.notEqual(preflight.consentTerms.newStateHash, preflight.input.expectedSourceHash);
  assert.equal(preflight.input.scope.scopeId, H("scope"));
  assert.notEqual(preflight.input.scope.scopeId, preflight.input.viewId);
  assert.equal(preflight.aggregate.revision, 5n);
  assert.ok(Object.isFrozen(preflight.source.payloadPointers));
  await assert.rejects(capture(f), /No consent yet/);
});

test("complete stored op17 capture and actual caller/value/gas original-call simulation", async () => {
  const f = setup();
  const saved = await capture(f);
  assert.equal(saved.consent.authorityClass, 1n);
  const simulation = await workflow.simulateTaggedPolicyViewV2(f.provider, saved, { blockTag: 11, gasLimit: 9_000_000n });
  assert.notEqual(simulation.recordHash, Z);
  const call = f.calls.findLast(row => row.name === "adoptPolicyView").request;
  assert.equal(call.from, f.caller);
  assert.equal(call.value, 0n);
  assert.equal(call.gasLimit, 9_000_000n);
  assert.equal(call.data, saved.prepared.call.data);
  assert.equal(f.calls.some(row => row.name === "recordContentConsent"), false);
  await assert.rejects(workflow.simulateTaggedPolicyViewV2(f.provider, saved, { blockTag: 9, gasLimit: 1n }), /precedes/);
  f.overrides = row => row.name === "adoptPolicyView" ? [H("unrelated result")] : undefined;
  await assert.rejects(workflow.simulateTaggedPolicyViewV2(f.provider, saved, { blockTag: 11, gasLimit: 1n }), /record hash differs/);
});

test("DISPLAY class7 precedes8, collection before global; original op17 consumption accepts only1/3", async () => {
  for (const [writerClass, grantCid, authorityClass] of [[7n, 0n, 3n], [8n, 13n, 1n], [8n, 0n, 3n]]) {
    const f = setup(); Object.assign(f, { writerClass, grantCid }); f.consent.authorityClass = authorityClass;
    const saved = await capture(f);
    assert.equal(saved.preflight.authorizationClass, writerClass);
    assert.equal(saved.preflight.grantCollectionId, grantCid);
    assert.equal(saved.consent.authorityClass, authorityClass);
  }
  for (const mutate of [f => { f.writerClass = 6n; }, f => { f.consent.authorityClass = 4n; },
    f => { f.consent.terms.newStateHash = H("wrong family"); }]) {
    const f = setup(); mutate(f); await assert.rejects(capture(f));
  }
});

test("literal source/schema/selected roster, membership and complete original inventory mismatches reject", async () => {
  const cases = [
    entry => entry.name === "getSatellitePointer" ? [A(99), H("runtime"), false, H("role"), "0x12345678", A(99), 1n, H("m"), H("d"), 2n] : undefined,
    entry => entry.name === "collectionFreezeStatus" ? [true] : undefined,
    entry => entry.name === "artworkFreezeMode" ? [2n] : undefined,
    entry => entry.name === "staticMetadataActivation" ? [Z, 0n, Z] : undefined,
    entry => entry.name === "artistContentLockState" ? [true, true] : undefined,
    entry => entry.name === "selectedViewRecord" ? [H("replaced"), false] : undefined,
    entry => entry.name === "requireCurrentSelection" ? (() => { throw Error("stale original policy"); })() : undefined,
    entry => entry.name === "sourceCount" ? [257n] : undefined,
    entry => entry.name === "requireCoordinator" ? [{ coordinator: A(99), indexedCodeHash: H("wrong"), firstTokenIndex: 0n }] : undefined,
    entry => entry.name === "isModuleEligible" ? [false] : undefined
  ];
  for (const override of cases) { const f = setup(); f.overrides = override; await assert.rejects(capture(f)); }
});

test("payload/document/runtime bounds and pre-await input snapshots are enforced", async () => {
  const f = setup();
  const suppliedInput = structuredClone(f.input);
  const suppliedDeployment = structuredClone(f.d);
  f.provider.getNetwork = async () => {
    suppliedInput.viewId = H("caller mutation");
    suppliedDeployment.router.codeHash = H("caller replaced runtime pin");
    return { chainId: f.d.chainId };
  };
  const copied = await workflow.captureTaggedPolicyViewV2(f.provider, suppliedDeployment, f.caller, suppliedInput, { blockTag: 10 });
  assert.equal(copied.preflight.input.viewId, f.manifest.viewId);
  assert.equal(copied.preflight.deployment.router.codeHash, f.d.router.codeHash);
  assert.notEqual(suppliedInput.viewId, copied.preflight.input.viewId);
  for (const fault of ["carrier", "schema", "code", "delegation"]) {
    const x = setup();
    if (fault === "carrier") x.codes.set(A(101), `0x01${x.rawPayload.slice(2)}`);
    if (fault === "schema") x.documents.set(x.manifest.schemaId, "0x12");
    if (fault === "code") x.codes.set(x.d.router.address, "0x6001");
    if (fault === "delegation") { const raw = `0xef0100${A(199).slice(2)}`; x.codes.set(x.d.router.address, raw); x.d.router.codeHash = keccak256(raw); }
    await assert.rejects(capture(x));
  }
});

test("both grants use exact original first-match precedence and source drift requires recapture", async () => {
  const f = setup();
  f.overrides = entry => entry.name === "familyWriter" ? [true, 9n] : undefined;
  const saved = await capture(f);
  assert.equal(saved.preflight.authorizationClass, 7n);
  assert.equal(saved.preflight.grantCollectionId, 13n);
  f.overrides = entry => entry.name === "familyWriter" && entry.tag === 11 ? [false, 9n] : undefined;
  await assert.rejects(workflow.simulateTaggedPolicyViewV2(f.provider, saved, { blockTag: 11, gasLimit: 8_000_000n }), /writer authority/);
});

test("refusal binds a self-consistently rehashed prepared call to the captured VIEW", async () => {
  const f = setup(); const saved = structuredClone(await capture(f));
  saved.prepared = view.prepareTaggedPolicyViewV2Call(f.coords, f.caller, { kind: "adoptPolicyView",
    input: { ...saved.preflight.input, scope: { ...saved.preflight.input.scope, scopeId: H("another VIEW") } } });
  const tagged = value => {
    if (value === null) return ["null"];
    if (typeof value === "string" || typeof value === "boolean") return [typeof value, value];
    if (typeof value === "bigint") return ["bigint", value.toString()];
    if (typeof value === "number") return ["number", value];
    if (Array.isArray(value)) return ["array", value.map(tagged)];
    return ["object", Object.keys(value).sort().map(key => [key, tagged(value[key])])];
  };
  const { captureHash: _old, ...body } = saved;
  saved.captureHash = keccak256(toUtf8Bytes(JSON.stringify(tagged(body))));
  await assert.rejects(workflow.observeTaggedPolicyViewV2Refusal(f.provider, saved, { blockTag: 11, gasLimit: 1n }), /captured VIEW/);
});

test("shared Safe verifier uses copied receipt logs despite later provider mutation", async () => {
  const f = setup(); const saved = await capture(f); const mined = f.install(saved, "indexed");
  mined.options.expectedSafeTxHash = H("not the original execution");
  f.provider.getTransaction = async () => {
    f.receipt.logs.at(-1).topics[1] = mined.options.expectedSafeTxHash;
    return f.transaction;
  };
  await assert.rejects(workflow.reconcileTaggedPolicyViewV2Receipt(f.provider, saved, mined.txHash, mined.options), /matching Safe execution/);
});

test("V1 predecessor and a V2 successor share scope revision and collection aggregate independently", async () => {
  const f = setup(); const initial = await capture(f); f.install(initial);
  const old = structuredClone(f.resultRecord);
  old.source.renderer.contextVersion = view.TAGGED_POLICY_VIEW_V1_CONTEXT;
  old.source.renderer.renderer = A(110);
  old.source.renderer.rendererCodeHash = H("old V1 renderer runtime");
  old.aggregate = structuredClone(f.aggregate);
  old.adoptedAt = 80n;
  old.recordHash = view.taggedPolicyViewV2RecordHash(f.coords, old, Z);
  f.addHistory(old, Z, A(103));
  f.resultRecord = null;
  f.input.expectedPrevious = old.recordHash;
  const saved = await capture(f);
  assert.equal(saved.preflight.previousRevision, 1n);
  const mined = f.install(saved);
  const receipt = await workflow.reconcileTaggedPolicyViewV2Receipt(f.provider, saved, mined.txHash, mined.options);
  assert.equal(receipt.record.revision, 2n);
  assert.equal(receipt.record.aggregate.revision, 6n);
});

test("all four Router serving methods keep actual calldata and do not call fresh adoption prerequisites", async () => {
  const f = setup(); const saved = await capture(f); f.install(saved);
  const serving = { chainId: f.d.chainId, core: f.d.core.address, coreCodeHash: f.d.core.codeHash,
    router: f.d.router, linkedDependencies: f.d.linkedDependencies };
  f.overrides = entry => {
    if (["familyWriter", "requireCurrentSelection", "contentConsentEvidence", "artworkFreezeMode", "version", "requireAssignable"].includes(entry.name)) {
      throw Error("No fresh adoption dependency allowed while serving");
    }
  };
  for (const kind of ["tokenJSONForView", "tokenHTMLForView", "historicalTokenJSONForView", "historicalTokenHTMLForView"]) {
    const request = kind.startsWith("historical") ? { kind, tokenId: 77n, recordHash: f.resultRecord.recordHash }
      : { kind, tokenId: 77n, scopeId: f.input.scope.scopeId };
    const result = await workflow.renderTaggedPolicyViewV2(f.provider, serving, f.caller, request, { blockTag: 15, gasLimit: 8_000_000n });
    assert.equal(result.output, f.output);
    const call = f.calls.findLast(row => row.name === kind);
    assert.equal(call.to, f.d.router.address);
    assert.equal(call.request.from, f.caller);
    assert.equal(call.request.value, 0n);
  }
  // Same collection and a genuine outer record hash still cannot label a different scope.
  await assert.rejects(workflow.renderTaggedPolicyViewV2(f.provider, serving, f.caller,
    { kind: "tokenJSONForView", tokenId: 77n, scopeId: H("another scope") }, { blockTag: 15, gasLimit: 1n }), /another scope/);
  f.overrides = entry => entry.name === "historicalTokenJSONForView" ? c.router.encodeFunctionResult(entry.name, [f.output]) + "00" : undefined;
  await assert.rejects(workflow.renderTaggedPolicyViewV2(f.provider, serving, f.caller,
    { kind: "historicalTokenJSONForView", tokenId: 77n, recordHash: f.resultRecord.recordHash }, { blockTag: 15, gasLimit: 1n }), /Noncanonical|invalid length/);
});

test("original Artist selection preserves runtime identity without inventing an ACTIVE-row gate", async () => {
  const f = setup();
  f.overrides = entry => {
    if (entry.name === "getSatellitePointer" && entry.args[0] === H("ARTIST_REGISTRY")) {
      const result = f.defaultCall(entry); result[6] = 2n; return result;
    }
  };
  assert.equal((await capture(f)).consent.recordHash, f.consent.recordHash);
  f.overrides = entry => entry.name === "suiteConfiguration"
    ? [{ ...f.defaultCall(entry)[0], metadata: A(199) }] : undefined;
  await assert.rejects(capture(f), /Artist suite differs/);
});

test("direct and both original Safe layouts reconcile exact schema2/profile/op17/carrier and independent scope/aggregate revisions", async () => {
  for (const mode of ["direct", "legacy", "indexed"]) {
    const f = setup(); const saved = await capture(f); const mined = f.install(saved, mode);
    const result = await workflow.reconcileTaggedPolicyViewV2Receipt(f.provider, saved, mined.txHash, mined.options);
    assert.equal(result.record.revision, 1n);
    assert.equal(result.record.aggregate.revision, 6n);
    assert.equal(result.record.adoptedAt, 120n);
    assert.equal(result.record.actor, f.caller);
    assert.equal(result.contentStateHash, f.afterContent);
    assert.notEqual(result.contentStateHash, f.family);
  }
});

test("eventless Store publication needs exact prior catalog and STOP carrier; new events obey source order", async () => {
  const f = setup(); f.priorCatalog = true; const saved = await capture(f); const mined = f.install(saved);
  await workflow.reconcileTaggedPolicyViewV2Receipt(f.provider, saved, mined.txHash, mined.options);
  f.priorCatalog = false;
  await assert.rejects(workflow.reconcileTaggedPolicyViewV2Receipt(f.provider, saved, mined.txHash, mined.options), /prior-block/);
  const x = setup(); const before = await capture(x); const receipt = x.install(before);
  x.receipt.logs.push(x.receipt.logs.shift()); normalizeLogs(x);
  await assert.rejects(workflow.reconcileTaggedPolicyViewV2Receipt(x.provider, before, receipt.txHash, receipt.options), /publication follows/);
});

test("Safe target/value/data/operation/hash/failure/early success and mandatory mined envelope joins reject", async () => {
  const mutators = [
    (f, m) => { m.options.expectedSafeTxHash = H("other"); },
    f => { f.transaction.value = 1n; },
    f => { const a = [...safeABI.decodeFunctionData("execTransaction", f.transaction.data)]; a[3] = 1n; f.transaction.data = safeABI.encodeFunctionData("execTransaction", a); },
    f => { f.receipt.logs.at(-1).topics[0] = safeABI.getEvent("ExecutionFailure").topicHash; },
    f => { f.receipt.logs.unshift(f.receipt.logs.pop()); normalizeLogs(f); },
    f => { f.receipt.logs[0].removed = true; },
    f => { delete f.receipt.logs[0].transactionHash; },
    f => { f.receipt.logs[0].index = NaN; },
    f => { f.receipt.from = A(99); },
    f => { f.transaction.data += "00"; }
  ];
  for (const mutate of mutators) {
    const f = setup(); const saved = await capture(f); const mined = f.install(saved, "indexed"); mutate(f, mined);
    await assert.rejects(workflow.reconcileTaggedPolicyViewV2Receipt(f.provider, saved, mined.txHash, mined.options));
  }
});

test("missing application/adoption and contradictory immutable carrier/head/owner readbacks reject", async () => {
  const mutators = [
    f => { f.receipt.logs.splice(1, 1); },
    f => { f.receipt.logs.splice(2, 1); },
    f => { f.codes.set(f.resultCarrier.pointer, "0x00"); },
    f => { f.overrides = e => e.name === "viewAdoptionHead" && e.tag === 12 ? [H("later same-block adoption")] : undefined; },
    f => { f.overrides = e => e.name === "consumedArtistContentConsent" && e.tag === 12 ? [false] : undefined; },
    f => { f.codeOverride = (target, tag) => target === f.d.artistConsentOwner.address && tag === 12 ? "0x6001" : undefined; }
  ];
  for (const mutate of mutators) {
    const f = setup(); const saved = await capture(f); const mined = f.install(saved); mutate(f);
    await assert.rejects(workflow.reconcileTaggedPolicyViewV2Receipt(f.provider, saved, mined.txHash, mined.options));
  }
});

test("preflight and receipt preserve first-release ratification continuity without new signature validation", async () => {
  const f = setup(); f.ratification = [true, f.beforeContent, H("ratification")];
  const saved = await capture(f); const mined = f.install(saved);
  await workflow.reconcileTaggedPolicyViewV2Receipt(f.provider, saved, mined.txHash, mined.options);
  assert.equal(f.calls.some(row => /Digest|nonce|signature|AuthorizationState/.test(row.name)), false);
  const x = setup(); x.ratification = [true, H("different state"), H("ratification")];
  await assert.rejects(capture(x), /evolution is broken/);
});

test("stale source/replaced capture block rejects; failed-call observations distinguish execution revert from RPC failure", async () => {
  const f = setup(); const saved = await capture(f);
  f.overrides = entry => { if (entry.name === "adoptPolicyView") throw Object.assign(Error("original late refusal"), { code: "CALL_EXCEPTION" }); };
  const observed = await workflow.observeTaggedPolicyViewV2Refusal(f.provider, saved, { blockTag: 11, gasLimit: 8_000_000n });
  assert.equal(observed.outcome, "execution-reverted"); assert.equal(observed.unchanged, true);
  assert.equal(observed.evidence, "same-block-rpc-observation-only");
  f.overrides = entry => { if (entry.name === "adoptPolicyView") throw Object.assign(Error("RPC disconnected"), { code: "NETWORK_ERROR" }); };
  assert.equal((await workflow.observeTaggedPolicyViewV2Refusal(f.provider, saved, { blockTag: 11, gasLimit: 8_000_000n })).outcome, "rpc-failed");
  f.wrongChain = true;
  await assert.rejects(workflow.observeTaggedPolicyViewV2Refusal(f.provider, saved, { blockTag: 11, gasLimit: 1n }), /Wrong chain/);
  f.wrongChain = false;
  f.header = n => ({ number: n, hash: H(`replacement${n}`), timestamp: n * 10 });
  await assert.rejects(workflow.simulateTaggedPolicyViewV2(f.provider, saved, { blockTag: 11, gasLimit: 1n }), /Pinned block changed/);
});

test("immutable V1/V2 history survives absent current sources; serving uses original Router and historical burned distinction", async () => {
  const f = setup(); const saved = await capture(f); f.install(saved);
  const history = { chainId: f.d.chainId, core: f.d.core.address, router: f.d.router, linkedDependencies: f.d.linkedDependencies };
  const key = f.resultRecord.recordHash;
  f.overrides = entry => {
    if (["requireCurrentSelection", "familyWriter", "selectedViewRecord", "contentConsentEvidence"].includes(entry.name)) throw Error("Current adoption source unavailable");
  };
  const retained = await workflow.inspectTaggedPolicyViewV2History(f.provider, history, key, { blockTag: 15 });
  assert.equal(retained.currentAdmission, "not-queried");
  const old = structuredClone(f.resultRecord); old.source.renderer.contextVersion = view.TAGGED_POLICY_VIEW_V1_CONTEXT;
  old.recordHash = view.taggedPolicyViewV2RecordHash(f.coords, old, Z); f.addHistory(old, Z, A(103));
  assert.equal((await workflow.inspectTaggedPolicyViewV2History(f.provider, history, old.recordHash, { blockTag: 15 })).profile, Z);
  const serve = { ...history, coreCodeHash: f.d.core.codeHash };
  f.overrides = entry => entry.name === "tokenCollectionIdentity" ? [true, 13n, 1n, true]
    : entry.name === "tokenLifecycle" ? [3n] : undefined;
  const output = await workflow.renderTaggedPolicyViewV2(f.provider, serve, f.caller,
    { kind: "historicalTokenJSONForView", tokenId: 77n, recordHash: key }, { blockTag: 15, gasLimit: 8_000_000n });
  assert.equal(output.output, f.output);
  await assert.rejects(workflow.renderTaggedPolicyViewV2(f.provider, serve, f.caller,
    { kind: "tokenJSONForView", tokenId: 77n, scopeId: f.input.scope.scopeId }, { blockTag: 15, gasLimit: 8_000_000n }), /unavailable/);
});

test("generic Safe plan round-trip retains exact original adoption selector and actual caller", async () => {
  const f = setup(); const saved = await capture(f);
  const plan = createSafeCallPlan(f.d.chainId, "Adopt original tagged VIEW", [{ safe: f.caller, intent: "Adopt reviewed source",
    call: saved.prepared.call, abi: compiledABI("router") }]);
  verifySafeCallPlan(plan, [compiledABI("router")]);
  assert.equal(plan.steps[0].transaction.to, f.d.router.address);
  assert.equal(plan.steps[0].transaction.value, "0");
  assert.equal(plan.steps[0].transaction.operation, 0);
});
