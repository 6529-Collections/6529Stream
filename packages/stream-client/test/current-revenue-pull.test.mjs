import test from "node:test";
import assert from "node:assert/strict";
import { Interface, ZeroAddress, ZeroHash, getAddress } from "ethers";
import * as p from "../dist/current-revenue-pull.js";
import { compiledInterfaces as abi } from "./current-revenue-pull-fixture.mjs";

const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const actor = A(1), target = A(2), account = A(3), recipient = A(4);
const authorization = { asset: ZeroAddress, account, recipient, releasableSnapshot: 1n << 190n, nonce: ZeroHash, deadline: (1n << 64n) - 1n };
const requests = [
  { kind: "syncAsset", asset: ZeroAddress },
  { kind: "release", asset: ZeroAddress, account, recipient: account },
  { kind: "releaseWithAuthorization", authorization, signature: "0x" },
  { kind: "revokeReleaseAuthorization", nonce: ZeroHash },
  { kind: "revokeReleaseAuthorizationBySignature", account, nonce: ZeroHash, deadline: 0n, signature: "0x1234" },
  { kind: "claimMany", claims: [{ wallet: target, asset: ZeroAddress, account }], continueOnFailure: true },
  { kind: "syncAndClaimMany", claims: [], continueOnFailure: false },
];

test("all seven method selectors and full call values use the original compiled ABI", () => {
  for (const request of requests) {
    const plan = p.prepareRevenuePullCall(target, actor, request);
    const iface = p.isRevenuePullRouterRequest(request) ? abi.router : abi.wallet;
    const parsed = iface.parseTransaction(plan.call);
    assert.equal(parsed.name, request.kind);
    assert.equal(iface.encodeFunctionData(parsed.fragment, parsed.args), plan.call.data);
    assert.equal(plan.call.value, 0n);
    assert.equal(plan.caller, actor);
    assert.equal(plan.factsVerified, false);
    const safe = p.revenuePullSafePlan(1n << 100n, plan, "Review pull");
    assert.equal(safe.steps[0].transaction.operation, 0);
    assert.equal(safe.steps[0].transaction.value, "0");
  }
  for (const [fragments, compiled] of [[p.REVENUE_PULL_WALLET_ABI, abi.wallet], [p.REVENUE_PULL_ROUTER_ABI, abi.router]]) {
    for (const f of new Interface(fragments).fragments) {
      const actual = f.type === "event" ? compiled.getEvent(f.format("sighash"))
        : f.type === "error" ? compiled.getError(f.format("sighash")) : compiled.getFunction(f.format("sighash"));
      assert.equal(actual.format("sighash"), f.format("sighash"));
    }
  }
});

test("direct alternate recipient authority is actual account caller; signed path has no bypass", () => {
  assert.throws(() => p.prepareRevenuePullCall(target, actor, { kind: "release", asset: ZeroAddress, account, recipient }), /actual account/);
  assert.equal(p.prepareRevenuePullCall(target, account, { kind: "release", asset: ZeroAddress, account, recipient }).caller, account);
  const signed = p.prepareRevenuePullCall(target, account, requests[2]);
  assert.equal(signed.request.signature, "0x");
});

test("router order, duplicates, zero raw targets and empty batches are preserved", () => {
  const row = { wallet: ZeroAddress, asset: ZeroAddress, account: ZeroAddress };
  const request = { kind: "claimMany", claims: [row, row, { wallet: target, asset: A(8), account }], continueOnFailure: true };
  const call = p.prepareRevenuePullCall(target, actor, request);
  assert.equal(call.request.claims.length, 3);
  assert.deepEqual(call.request.claims[0], call.request.claims[1]);
  assert.equal(call.request.claims[2].asset, A(8));
  assert.equal(p.prepareRevenuePullCall(target, actor, requests[6]).request.claims.length, 0);
  request.claims[0].account = actor;
  assert.equal(call.request.claims[0].account, ZeroAddress);
  assert(Object.isFrozen(call.request.claims[0]));
});

test("exact widths, dense client bounds and complete-call reconstruction reject malformed inputs", () => {
  assert.throws(() => p.prepareRevenuePullCall(target, actor, { ...requests[2], authorization: { ...authorization, deadline: 1n << 64n } }), /uint64/);
  assert.throws(() => p.prepareRevenuePullCall(target, actor, { ...requests[2], authorization: { ...authorization, releasableSnapshot: 1 } }), /bigint/);
  assert.throws(() => p.prepareRevenuePullCall(target, actor, { ...requests[0], invented: true }), /unknown/);
  assert.throws(() => p.prepareRevenuePullCall(target, actor, { ...requests[5], claims: Array(2) }), /dense/);
  assert.throws(() => p.prepareRevenuePullCall(target, actor, { ...requests[5], claims: Array(65).fill(requests[5].claims[0]) }), /bounded/);
  assert.throws(() => p.prepareRevenuePullCall(target, actor, { ...requests[2], signature: `0x${"ab".repeat(p.REVENUE_PULL_MAX_BYTES)}` }), /oversized/);
  const plan = structuredClone(p.prepareRevenuePullCall(target, actor, requests[0]));
  plan.call.value = 1n;
  assert.throws(() => p.normalizeRevenuePullCall(plan), /differs/);
});

test("full-width observed receipts use floor entitlement and saturate without conflating release with sync", () => {
  const balance = 1n << 200n;
  const out = p.revenuePullEntitlement(balance, 7n, 333333n, 10n);
  assert.equal(out.observedReceived, balance + 7n);
  assert.equal(out.releasable, (balance + 7n) * 333333n / 1000000n - 10n);
  assert.equal(p.revenuePullEntitlement(0n, 5n, 1n, 1n).releasable, 0n);
  assert.throws(() => p.revenuePullEntitlement((1n << 256n) - 1n, 1n, 1n, 0n));
  assert.throws(() => p.revenuePullEntitlement(1n, 0n, 1000001n, 0n));
});
