import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, concat, getAddress, id, keccak256 } from "ethers";
import * as g from "../dist/current-governance-executor-v2.js";
import { toSafeCall } from "../dist/safe.js";
import { governanceExecutorV2Interfaces as compiled } from "./current-governance-executor-v2-source-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const host = compiled.StreamGovernanceExecutor;
const addr = n => getAddress(`0x${n.toString(16).padStart(40, "0")}`);
const c = { chainId: 31337n, executor: addr(1) }, caller = addr(2), day = 86400n;
const domains = {
  calls: "0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70",
  action: "0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b",
  scope: "0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c",
  oldValue: "0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7",
  newValue: "0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b",
};
const callType = host.getFunction("scheduleGovernanceBatch").inputs[1];
const requestType = host.getFunction("scheduleGovernanceAction").inputs[0];
const actionType = host.getFunction("governanceAction").outputs[0];
const identityType = "tuple(uint8 actionClass,bytes32 callsHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint256 nonce,uint64 notBefore,uint64 expiresAfter,bytes32 reasonHash,bytes32 manifestHash)";
function descriptor(data = "0x12345678aabb", value = 0n, scope = id("scope")) {
  return { target: addr(3), value, selector: data === "0x" ? "0x00000000" : data.slice(0, 10), callDataHash: keccak256(data), scopeHash: scope, oldValueHash: id("old"), newValueHash: id("new") };
}
function originalHashes(calls) {
  const callsHash = keccak256(coder.encode(["bytes32", callType], [domains.calls, calls]));
  const h = (domain, field) => keccak256(coder.encode(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, calls.map(x => x[field])]));
  return { callsHash, scopeHash: h(domains.scope, "scopeHash"), oldValueHash: h(domains.oldValue, "oldValueHash"), newValueHash: h(domains.newValue, "newValueHash") };
}
function single(overrides = {}) {
  const { callDataHash: _, ...call } = descriptor();
  return { actionClass: 1n, ...call, callData: "0x12345678aabb", notBefore: 200000n, expiresAfter: 900000n, reasonHash: ZeroHash, reasonURI: "", manifestHash: id("manifest"), ...overrides };
}
function batch(calls = [descriptor()], overrides = {}) {
  const { callsHash: _, ...transition } = originalHashes(calls);
  return { method: "scheduleGovernanceBatch", actionClass: 1n, calls, ...transition, notBefore: 200000n, expiresAfter: 900000n, reasonHash: ZeroHash, reasonURI: "", manifestHash: id("manifest"), ...overrides };
}
function state(calls = [descriptor()], overrides = {}) {
  const h = originalHashes(calls);
  return { status: 1n, actionClass: 1n, target: calls[0].target, value: calls.reduce((s, x) => s + x.value, 0n), selector: calls[0].selector, callHash: h.callsHash, scopeHash: h.scopeHash, oldValueHash: h.oldValueHash, newValueHash: h.newValueHash, notBefore: 200000n, expiresAfter: 900000n, proposer: caller, executor: ZeroAddress, canceller: ZeroAddress, vetoer: ZeroAddress, reasonHash: ZeroHash, reasonURI: "", manifestHash: id("manifest"), ...overrides };
}
function identity(action, nonce = 9n) {
  return { actionClass: action.actionClass, callsHash: action.callHash, scopeHash: action.scopeHash, oldValueHash: action.oldValueHash, newValueHash: action.newValueHash, nonce, notBefore: action.notBefore, expiresAfter: action.expiresAfter, reasonHash: action.reasonHash, manifestHash: action.manifestHash };
}
function originalId(coordinates, value) {
  return keccak256(coder.encode(["bytes32", "uint256", "address", identityType], [domains.action, coordinates.chainId, coordinates.executor, value]));
}
function zero(p) {
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(x => [x.name, zero(x)]));
  if (p.type === "address") return ZeroAddress;
  if (p.type === "string") return "";
  if (p.type.startsWith("bytes")) return p.type === "bytes" ? "0x" : `0x${"00".repeat(Number(p.type.slice(5)))}`;
  return 0n;
}
function word(n) { return BigInt(n).toString(16).padStart(64, "0"); }

test("finite ordinary ABI has nine original mutators, exact selected views/events and complete errors", () => {
  const client = g.governanceExecutorV2Interface();
  const writes = client.fragments.filter(x => x.type === "function" && !["view", "pure"].includes(x.stateMutability));
  assert.equal(writes.length, 9);
  for (const fragment of client.fragments) {
    const actual = fragment.type === "function" ? host.getFunction(fragment.format("sighash")) : fragment.type === "event" ? host.getEvent(fragment.format("sighash")) : host.getError(fragment.format("sighash"));
    assert.equal(fragment.format("full"), actual.format("full"));
  }
  assert.equal(client.fragments.filter(x => x.type === "error").length, host.fragments.filter(x => x.type === "error").length);
  assert.equal(client.getFunction("registerProposer"), null);
  assert.equal(client.getFunction("sealSystemManifestBootstrap"), null);
  assert.equal(client.getEvent("GovernanceActionScheduled").inputs.find(x => x.name === "nonce").type, "uint256");
});

test("raw canonical codecs retain zero records and full uint widths separately from admission", () => {
  const raw = zero(actionType);
  assert.deepEqual(g.decodeGovernanceExecutorV2Action(coder.encode([actionType], [raw])), raw);
  const request = single({ actionClass: 255n, value: (1n << 256n) - 1n, notBefore: (1n << 64n) - 1n, expiresAfter: (1n << 64n) - 1n });
  assert.equal(g.encodeGovernanceExecutorV2ScheduleAction(request), coder.encode([requestType], [request]));
  assert.deepEqual(g.decodeGovernanceExecutorV2ScheduleAction(g.encodeGovernanceExecutorV2ScheduleAction(request)), request);
  assert.throws(() => g.prepareGovernanceExecutorV2Call(c, caller, { method: "scheduleGovernanceAction", request }), /class/);
  assert.throws(() => g.normalizeGovernanceExecutorV2Action({ ...raw, status: 6n }), /status/);
  assert.throws(() => g.normalizeGovernanceExecutorV2ScheduleAction({ ...request, notBefore: 1n << 64n }), /uint64/);
  assert.throws(() => g.normalizeGovernanceExecutorV2ScheduleAction({ ...request, value: 1 }), /bigint/);
});

test("original compiler-shaped call and aggregate hashes preserve order, duplicates and individual scopes", () => {
  const calls = [descriptor(), descriptor("0xabcdef01", 12n, id("second")), descriptor()];
  assert.deepEqual(g.governanceExecutorV2BatchHashes(calls), originalHashes(calls));
  assert.equal(g.governanceExecutorV2CallsHash(calls), originalHashes(calls).callsHash);
  assert.notEqual(originalHashes(calls).scopeHash, calls[0].scopeHash);
  assert.notEqual(g.governanceExecutorV2CallsHash(calls), g.governanceExecutorV2CallsHash([...calls].reverse().slice(1)));
  assert.deepEqual(g.governanceExecutorV2DistinctScopes(calls), [id("scope"), id("second")]);
  assert.notEqual(g.governanceExecutorV2CallsHash([calls[0]]), g.governanceExecutorV2CallsHash([calls[0], calls[0]]));
});

test("single and batch1 share original identity, while nonce/chain/Executor/commitments are bound", () => {
  const one = { method: "scheduleGovernanceAction", request: single() }, many = batch();
  const a = g.governanceExecutorV2ScheduleIdentity(one, 1n << 200n);
  assert.deepEqual(a, g.governanceExecutorV2ScheduleIdentity(many, 1n << 200n));
  const expected = originalId(c, a);
  assert.equal(g.governanceExecutorV2ActionId(c, a), expected);
  for (const [field, value] of Object.entries({ actionClass: 2n, nonce: 1n, notBefore: 3n, expiresAfter: 4n, reasonHash: id("reason"), manifestHash: id("other"), callsHash: id("other"), scopeHash: id("other"), oldValueHash: id("other"), newValueHash: id("other") })) assert.notEqual(g.governanceExecutorV2ActionId(c, { ...a, [field]: value }), expected);
  assert.notEqual(g.governanceExecutorV2ActionId({ ...c, chainId: 2n }, a), expected);
  assert.notEqual(g.governanceExecutorV2ActionId({ ...c, executor: addr(7) }, a), expected);
  assert.equal(g.governanceExecutorV2ActionId(c, g.governanceExecutorV2ScheduleIdentity({ ...one, request: single({ reasonURI: "https://different.example/提示" }) }, a.nonce)), expected);
});

test("publication key is packed ordered hashes and original full SSTORE2 allocation is bounded", () => {
  const data = ["0x12345678", "0x", "0x12345678"];
  assert.equal(g.governanceExecutorV2PublicationKey(data), keccak256(concat(data.map(keccak256))));
  assert.notEqual(g.governanceExecutorV2PublicationKey(data), keccak256(coder.encode(["bytes32[]"], [data.map(keccak256)])));
  assert.equal(g.governanceExecutorV2CallDataPublication(data), coder.encode(["bytes[]"], [data]));
  assert.deepEqual(g.decodeGovernanceExecutorV2CallDataPublication(g.governanceExecutorV2CallDataPublication(data)), data);
  const accepted = [`0x${"12".repeat(24416)}`];
  assert.equal((g.governanceExecutorV2CallDataPublication(accepted).length - 2) / 2, 24544);
  assert.throws(() => g.governanceExecutorV2CallDataPublication([`${accepted[0]}12`]), /24575/);
  assert.throws(() => g.governanceExecutorV2CallDataPublication([`0x${"12".repeat(12224)}`, `0x${"34".repeat(12224)}`]), /24575/);
  assert.throws(() => g.governanceExecutorV2CallDataPublication([]), /empty/);
});

test("source windows use exact six floors, uint64 headroom and inclusive execution expiry", () => {
  const floors = [0n, 2n * day, 3n * day, 2n * day, 14n * day, 30n * day], now = 100n;
  for (let i = 0; i < 6; i++) {
    assert.equal(g.governanceExecutorV2MinimumDelay(BigInt(i)), floors[i]);
    const start = now + floors[i], expiry = start + (i ? 7n * day : 1n);
    g.governanceExecutorV2ValidateWindow(BigInt(i), start, expiry, now);
    assert.throws(() => g.governanceExecutorV2ValidateWindow(BigInt(i), start - 1n, expiry, now), /delay/);
    if (i) assert.throws(() => g.governanceExecutorV2ValidateWindow(BigInt(i), start, expiry - 1n, now), /floor/);
  }
  assert.throws(() => g.governanceExecutorV2MinimumDelay(6n), /retired/);
  assert.throws(() => g.governanceExecutorV2ValidateWindow(0n, now, now, now), /window/);
  g.governanceExecutorV2ValidateWindow(0n, now, now + 365n * day, now);
  assert.throws(() => g.governanceExecutorV2ValidateWindow(0n, now, now + 365n * day + 1n, now), /window/);
  const last = (1n << 64n) - 1n - 365n * day;
  g.governanceExecutorV2ValidateWindow(0n, last, last + 1n, last);
  assert.throws(() => g.governanceExecutorV2ValidateWindow(0n, last + 1n, last + 2n, last + 1n), /headroom/);
});

test("all nine plans exactly match original compiler calldata and native payable sums survive Safe CALL", () => {
  const payable = [descriptor("0x12345678aabb", 5n), descriptor("0x", 7n)];
  const requests = [
    { method: "publishGovernanceCallData", callDatas: ["0x12345678aabb"] },
    { method: "scheduleGovernanceAction", request: single({ value: 5n }) }, batch(payable),
    { method: "executeGovernanceAction", actionId: id("action"), call: payable[0], callData: "0x12345678aabb" },
    { method: "executeGovernanceBatch", actionId: id("action"), calls: payable, callDatas: ["0x12345678aabb", "0x"] },
    { method: "cancelGovernanceAction", actionId: id("action"), reasonHash: ZeroHash },
    { method: "vetoTerminalFreeze", actionId: id("action"), reasonHash: ZeroHash },
    { method: "materializeExpiredAction", actionId: id("action") },
    { method: "pruneElapsedTerminalFreezeActions", scopeHash: ZeroHash },
  ];
  for (const request of requests) {
    const p = g.prepareGovernanceExecutorV2Call(c, caller, request);
    const decoded = host.decodeFunctionData(request.method, p.call.data);
    assert.equal(host.encodeFunctionData(request.method, decoded), p.call.data);
    assert.equal(g.decodeGovernanceExecutorV2Call(p.call.data).method, request.method);
    assert.deepEqual(g.verifyGovernanceExecutorV2Call(p), p);
    const expectedValue = request.method === "executeGovernanceAction" ? 5n : request.method === "executeGovernanceBatch" ? 12n : 0n;
    assert.equal(p.call.value, expectedValue);
    assert.deepEqual(toSafeCall(p.call), { to: c.executor, value: String(expectedValue), data: p.call.data, operation: 0 });
    assert.equal(p.authorityIndependentlyVerified, false);
    assert.equal(p.targetEffectsIndependentlyVerified, false);
  }
});

test("batch aggregate substitution, mismatched data, short selectors, zero targets and value overflow reject", () => {
  for (const key of ["scopeHash", "oldValueHash", "newValueHash"]) assert.throws(() => g.prepareGovernanceExecutorV2Call(c, caller, { ...batch(), [key]: id("substitute") }), /aggregate/);
  assert.throws(() => g.validateGovernanceExecutorV2Calls([descriptor()], ["0xabcdef01"]), /Hash/);
  assert.throws(() => g.validateGovernanceExecutorV2Calls([descriptor()], []), /mismatched/);
  assert.throws(() => g.validateGovernanceExecutorV2Calls([{ ...descriptor(), target: ZeroAddress }], ["0x12345678aabb"]), /nonzero/);
  assert.throws(() => g.validateGovernanceExecutorV2Calls([{ ...descriptor(), selector: "0xabcdef01" }], ["0x12345678aabb"]), /selector/);
  assert.throws(() => g.validateGovernanceExecutorV2Calls([{ ...descriptor(), callDataHash: keccak256("0x1234") }], ["0x1234"]), /short/);
  assert.throws(() => g.validateGovernanceExecutorV2Calls([descriptor("0x", 1n)], ["0x"], 0n), /native/);
  assert.throws(() => g.validateGovernanceExecutorV2Calls([descriptor("0x", 0n)], ["0x"]), /native/);
  assert.equal(g.validateGovernanceExecutorV2Calls([descriptor("0x", 1n)], ["0x"], 1n).totalValue, 1n);
  assert.throws(() => g.validateGovernanceExecutorV2Calls([descriptor("0x", (1n << 256n) - 1n), descriptor("0x", 1n)], ["0x", "0x"]), /uint256/);
});

test("immutable action authentication uses original nonce and individual descriptors, never latest nonce", () => {
  const action = state(), i = identity(action), actionId = originalId(c, i);
  const result = g.authenticateGovernanceExecutorV2Action(c, actionId, i.nonce, action, [descriptor()], ["0x12345678aabb"]);
  assert.equal(result.provenanceIndependentlyVerified, false);
  assert.throws(() => g.authenticateGovernanceExecutorV2Action(c, actionId, i.nonce + 1n, action, [descriptor()], ["0x12345678aabb"]), /actionId/);
  for (const key of ["callHash", "scopeHash", "oldValueHash", "newValueHash"]) assert.throws(() => g.authenticateGovernanceExecutorV2Action(c, actionId, i.nonce, { ...action, [key]: id("wrong") }, [descriptor()], ["0x12345678aabb"]), /stored/);
  const terminal = { ...action, status: 2n, canceller: addr(9), reasonURI: "display may differ" };
  assert.equal(g.authenticateGovernanceExecutorV2Action(c, actionId, i.nonce, terminal, [descriptor()], ["0x12345678aabb"]).action.status, 2n);
  assert.throws(() => g.authenticateGovernanceExecutorV2Action(c, actionId, i.nonce, { ...action, status: 0n }, [descriptor()], ["0x12345678aabb"]), /unknown/);
});

test("stored and virtual status diverge only after expiry; veto prune and action expiry are distinct", () => {
  const facts = { status: 1n, actionClass: 2n, callHash: id("calls"), notBefore: 100n, expiresAfter: 200n };
  const before = g.governanceExecutorV2Lifecycle(facts, 99n);
  assert.equal(before.vetoWindow, true); assert.equal(before.executionWindow, false); assert.equal(before.elapsedVetoMembership, false);
  const start = g.governanceExecutorV2Lifecycle(facts, 100n);
  assert.equal(start.vetoWindow, false); assert.equal(start.executionWindow, true); assert.equal(start.elapsedVetoMembership, true); assert.equal(start.canMaterializeExpiry, false);
  const end = g.governanceExecutorV2Lifecycle(facts, 200n);
  assert.equal(end.executionWindow, true); assert.equal(end.cancellationWindow, true); assert.equal(end.virtualStatus, 1n);
  const expired = g.governanceExecutorV2Lifecycle(facts, 201n);
  assert.equal(expired.storedStatus, 1n); assert.equal(expired.virtualStatus, 4n); assert.equal(expired.canMaterializeExpiry, true); assert.equal(expired.cancellationWindow, false);
  for (const status of [0n, 2n, 3n, 4n, 5n]) assert.equal(g.governanceExecutorV2Lifecycle({ ...facts, status }, 101n).executionWindow, false);
});

test("finite read planner preserves original raw/virtual endpoints and canonical tuples", () => {
  for (const method of ["governanceAction", "governanceActionFacts", "scheduledCallData", "scheduledCallDataPointer", "terminalFreezeGuardianConfigCommitment"]) {
    const plan = g.prepareGovernanceExecutorV2Read(c, { method, args: [id("action")] });
    assert.equal(plan.call.data, host.encodeFunctionData(method, [id("action")]));
    assert.equal(plan.call.value, 0n);
  }
  const raw = state();
  assert.deepEqual(g.decodeGovernanceExecutorV2Read("governanceAction", host.encodeFunctionResult("governanceAction", [raw])), [raw]);
  g.prepareGovernanceExecutorV2Read(c, { method: "terminalFreezeActionPage", args: [ZeroHash, 0n, 64n] });
  assert.throws(() => g.prepareGovernanceExecutorV2Read(c, { method: "terminalFreezeActionPage", args: [ZeroHash, 0n, 65n] }), /64/);
  assert.throws(() => g.prepareGovernanceExecutorV2Read(c, { method: "registerProposer", args: [caller, true] }), /unsupported/);
  assert.throws(() => g.prepareGovernanceExecutorV2Read(c, { method: "minimumDelay", args: [6n] }), /retired/);
});

test("decoders reject dirty scalar padding, trailing bytes and hostile counts before materialization", () => {
  const good = g.encodeGovernanceExecutorV2Action(state());
  assert.throws(() => g.decodeGovernanceExecutorV2Action(`${good}${word(0)}`), /canonical/);
  const dirty = `0x${word(257)}${good.slice(66)}`;
  assert.throws(() => g.decodeGovernanceExecutorV2Action(dirty));
  const count = `0x${word(32)}${word(257)}`;
  assert.throws(() => g.decodeGovernanceExecutorV2Read("scheduledCallData", count), /array/);
  const huge = `0x${word(32)}${word(1n << 255n)}`;
  assert.throws(() => g.decodeGovernanceExecutorV2Read("scheduledCallData", huge), /allocation/);
  const call = g.prepareGovernanceExecutorV2Call(c, caller, { method: "materializeExpiredAction", actionId: id("action") });
  assert.throws(() => g.decodeGovernanceExecutorV2Call(`${call.call.data}00`), /canonical/);
  assert.throws(() => g.decodeGovernanceExecutorV2Call(host.encodeFunctionData("owner", [])), /unsupported/);
  assert.throws(() => g.decodeGovernanceExecutorV2Read("isProposer", `0x${word(2)}`), /canonical/);
});

test("strict ownership, scalar text and client resource bounds reject surplus/sparse/mutable inputs", () => {
  const s = single({ reasonURI: "https://example.test/提示?x=%#literal" });
  g.normalizeGovernanceExecutorV2ScheduleAction(s);
  assert.throws(() => g.normalizeGovernanceExecutorV2ScheduleAction({ ...s, reasonURI: "x".repeat(2049) }), /client/);
  assert.throws(() => g.normalizeGovernanceExecutorV2ScheduleAction({ ...s, reasonURI: "😀".repeat(513) }), /client/);
  assert.throws(() => g.normalizeGovernanceExecutorV2ScheduleAction({ ...s, reasonURI: "\udc00" }), /scalar/);
  assert.throws(() => g.normalizeGovernanceExecutorV2ScheduleAction({ ...s, surprise: true }), /fields/);
  assert.throws(() => g.governanceExecutorV2CallsHash(new Array(1)), /array|sparse/);
  const extra = [descriptor()]; Object.defineProperty(extra, "hidden", { value: 1 });
  assert.throws(() => g.governanceExecutorV2CallsHash(extra), /array/);
  const symbolic = [descriptor()]; symbolic[Symbol("extra")] = true;
  assert.throws(() => g.governanceExecutorV2CallsHash(symbolic), /array/);
  assert.throws(() => g.governanceExecutorV2CallsHash(Array(257).fill(descriptor())), /array/);
  const request = batch();
  const prepared = g.prepareGovernanceExecutorV2Call(c, caller, request);
  request.calls[0].value = 10n; request.reasonURI = "mutated";
  assert.equal(prepared.request.calls[0].value, 0n);
  assert.equal(prepared.request.reasonURI, "");
  assert.ok(Object.isFrozen(prepared.request.calls[0]));
});

test("cumulative input and aliased wire payload budgets fail without large nested allocation", () => {
  const blob = `0x${"ab".repeat(600000)}`;
  assert.throws(() => g.governanceExecutorV2PublicationKey([blob, blob, blob, blob]), /aggregate/);
  // Four offsets alias one encoded value: small retained wire, oversized materialized result.
  const wire = `0x${word(32)}${word(4)}${word(128).repeat(4)}${word(600000)}${blob.slice(2)}`;
  assert.throws(() => g.decodeGovernanceExecutorV2Read("scheduledCallData", wire), /aggregate/);
});

test("prepared call verification rejects value/target/data/operation and false authority substitutions", () => {
  const p = g.prepareGovernanceExecutorV2Call(c, caller, { method: "executeGovernanceAction", actionId: id("action"), call: descriptor("0x12345678aabb", 7n), callData: "0x12345678aabb" });
  for (const call of [{ ...p.call, value: 0n }, { ...p.call, to: addr(9) }, { ...p.call, data: `${p.call.data}00` }, { ...p.call, operation: 1 }]) assert.throws(() => g.verifyGovernanceExecutorV2Call({ ...p, call }), /substituted/);
  assert.throws(() => g.verifyGovernanceExecutorV2Call({ ...p, authorityIndependentlyVerified: true }), /substituted/);
  assert.throws(() => g.prepareGovernanceExecutorV2Call(c, caller, { method: "rotateGovernanceRoot", newRoot: addr(9) }), /unsupported/);
  assert.throws(() => g.prepareGovernanceExecutorV2Call(c, caller, { method: "cancelGovernanceAction", actionId: id("action"), reasonHash: ZeroHash, reasonURI: "not an input" }), /fields/);
});
