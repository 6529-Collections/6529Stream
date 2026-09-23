import test from "node:test";
import assert from "node:assert/strict";
import { Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as pure from "../dist/current-revenue-pull.js";
import * as flow from "../dist/current-revenue-pull-workflow.js";
import * as split from "../dist/current-split-factory.js";
import { compiledInterfaces as abi } from "./current-revenue-pull-fixture.mjs";

const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const factory = A(1), implementation = A(2), assetPolicy = A(3), caller = A(4), account = A(10), router = A(20), token = A(30);
const codes = { factory: "0x6001600055", implementation: "0x6002600055", assetPolicy: "0x6003600055", router: "0x6004600055", token: "0x6005600055" };
const pin = (address, name) => ({ address, codeHash: keccak256(codes[name]) });
const factoryDeployment = { chainId: 31337n, factory: pin(factory, "factory"), implementation: pin(implementation, "implementation"), assetPolicy: pin(assetPolicy, "assetPolicy") };
const context = { chainId: 31337n, factory, profileDomain: id("6529STREAM_SPLIT_PROFILE_V1"), schemaVersion: 1n, walletVersion: 4n, ...split.splitWalletCloneHashes(implementation), assetPolicyRegistry: assetPolicy };
const profile = split.prepareSplitProfile(context, [{ account, sharePpm: 1000000n, labelId: ZeroHash }], ZeroHash);
const hash = n => id(`block:${n}`);
const readAbi = new Interface([
  ...pure.REVENUE_PULL_WALLET_ABI,
  "function balanceOf(address) view returns(uint256)",
]);

function provider(options = {}) {
  const calls = [], hits = new Map();
  const state = tag => ({ balance: 100n, total: 0n, released: 0n, initialized: true, last: 100n,
    used: false, status: 1n, grace: 0n, ...options.state?.(tag) });
  return {
    calls, state,
    async getNetwork() { options.mutate?.(); return { chainId: options.chainId ?? 31337n }; },
    async getBlock(n) {
      hits.set(n, (hits.get(n) ?? 0) + 1);
      return { number: n, hash: options.reorg && hits.get(n) > 1 ? id("changed") : hash(n), timestamp: 1000 + n };
    },
    async getBalance(target, tag) { assert.equal(target, profile.wallet); return state(tag).balance; },
    async getCode(target, tag) {
      const changed = options.code?.(target, tag);
      if (changed !== undefined) return changed;
      return target === factory ? codes.factory : target === implementation ? codes.implementation
        : target === assetPolicy ? codes.assetPolicy : target === router ? codes.router
        : target === token ? codes.token : target === profile.wallet ? split.splitWalletCloneRuntime(implementation) : "0x";
    },
    async call(tx) {
      calls.push(tx);
      const target = getAddress(tx.to), tag = tx.blockTag, s = state(tag);
      const iface = target === factory ? abi.factory : target === assetPolicy ? abi.assets
        : target === router ? abi.router : target === token ? readAbi : abi.wallet;
      const parsed = iface.parseTransaction({ data: tx.data }), name = parsed.name, args = parsed.args;
      const override = options.read?.(name, args, target, tag, tx);
      if (override?.raw !== undefined) return override.raw;
      if (override !== undefined) return iface.encodeFunctionResult(parsed.fragment, override);
      let out;
      if (name === "PROFILE_DOMAIN") out = [context.profileDomain];
      else if (name === "SCHEMA_VERSION") out = [1n];
      else if (name === "WALLET_VERSION") out = [4n];
      else if (name === "MAX_ENTRIES" || name === "MAX_UNIQUE_ACCOUNTS") out = [64n];
      else if (name === "SHARE_DENOMINATOR_PPM") out = [1000000n];
      else if (name === "assetPolicyRegistry") out = [assetPolicy];
      else if (name === "splitWalletImplementation") out = [implementation];
      else if (name === "splitWalletImplementationCodeHash") out = [keccak256(codes.implementation)];
      else if (name === "splitWalletInitCodeHash") out = [context.initCodeHash];
      else if (name === "splitWalletRuntimeCodeHash") out = [context.runtimeCodeHash];
      else if (name === "supportsInterface") out = [args[0] !== "0xffffffff"];
      else if (name === "isStreamAssetPolicyRegistry") out = [true];
      else if (name === "ASSET_STATUS_ACTIVE") out = [1n];
      else if (name === "factory") out = [factory];
      else if (name === "initialized") out = [true];
      else if (name === "profileId") out = [target === implementation ? ZeroHash : profile.profileId];
      else if (name === "entriesHash") out = [target === implementation ? ZeroHash : profile.entriesHash];
      else if (name === "metadataURIHash") out = [ZeroHash];
      else if (name === "profileExists" || name === "splitWalletExists") out = [true];
      else if (name === "profileEntriesHash") out = [profile.entriesHash];
      else if (name === "profileMetadataURIHash") out = [ZeroHash];
      else if (name === "walletFor") out = [profile.wallet];
      else if (name === "profileIdFor") out = [profile.profileId];
      else if (name === "entryCount" || name === "uniqueAccountCount") out = [target === implementation ? 0n : 1n];
      else if (name === "profileEntryCount" || name === "profileUniqueAccountCount") out = [1n];
      else if (name === "entry" || name === "profileEntry") out = [account, 1000000n, ZeroHash];
      else if (name === "uniqueAccount" || name === "profileUniqueAccount") out = [account, 1000000n];
      else if (name === "aggregateSharePpm") out = [args[0] === account ? 1000000n : 0n];
      else if (name === "gasParameter") out = [400000n];
      else if (name === "totalReleased") out = [s.total];
      else if (name === "accountReleased") out = [args[1] === account ? s.released : 0n];
      else if (name === "assetObservationInitialized") out = [s.initialized];
      else if (name === "lastObservedReceived") out = [s.last];
      else if (name === "balanceOf") out = [s.balance];
      else if (name === "assetStatus") out = [s.status];
      else if (name === "assetReleaseGraceUntil") out = [s.grace];
      else if (name === "observedReceived" || name === "syncAsset") out = [s.balance + s.total];
      else if (name === "releasable") out = [args[1] === account ? s.balance + s.total - s.released : 0n];
      else if (name === "isReleaseAuthorizationNonceUsed") out = [s.used];
      else if (name === "domainSeparator") out = [split.splitWalletDomainSeparator(profile)];
      else if (name === "releaseAuthorizationDigest") out = [split.splitWalletReleaseTypedData(snapshot(), profile, Object.fromEntries(["asset", "account", "recipient", "releasableSnapshot", "nonce", "deadline"].map((key, i) => [key, args[0][i]]))).digest];
      else if (name === "releaseRevocationDigest") out = [split.splitWalletReleaseRevocationTypedData(snapshot(), profile, { account: args[0], nonce: args[1], deadline: args[2] }).digest];
      else if (name === "release" || name === "releaseWithAuthorization") out = [s.balance + s.total - s.released];
      else if (name === "revokeReleaseAuthorization" || name === "revokeReleaseAuthorizationBySignature") out = [];
      else if (name === "claimMany" || name === "syncAndClaimMany") out = [args[0].map((_, i) => i ? 0n : s.balance)];
      else throw Error(`Unexpected ${name}`);
      return iface.encodeFunctionResult(parsed.fragment, out);
    },
  };
}
function snapshot() {
  return { context, factoryCodeHash: keccak256(codes.factory), assetPolicyCodeHash: keccak256(codes.assetPolicy), implementation: factoryDeployment.implementation };
}
const release = asset => ({ kind: "release", asset, account, recipient: account });
const claim = asset => ({ wallet: profile.wallet, asset, account });
const auth = deadline => ({ asset: ZeroAddress, account, recipient: A(50), releasableSnapshot: 100n, nonce: ZeroHash, deadline });
function deployment(request) {
  const routed = pure.isRevenuePullRouterRequest(request);
  const assets = routed ? request.claims.map(x => x.asset) : request.kind === "releaseWithAuthorization"
    ? [request.authorization.asset] : "asset" in request ? [request.asset] : [];
  return { chainId: 31337n, wallets: routed && !request.claims.length ? [] : [{ factory: factoryDeployment, profile }],
    router: routed ? pin(router, "router") : null,
    assets: [...new Set(assets)].filter(x => x !== ZeroAddress).map(x => pin(x, "token")) };
}
async function setup(request = release(ZeroAddress), options = {}, actor = caller) {
  const p = provider(options), d = deployment(request);
  const prepared = pure.prepareRevenuePullCall(pure.isRevenuePullRouterRequest(request) ? router : profile.wallet, actor, request);
  const captured = await flow.captureRevenuePull(p, d, prepared, { blockTag: 10 });
  return { p, d, prepared, captured };
}
const safeAbi = new Interface(["function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)"]);
function receipt(p, prepared, specs, { safe = false, indexed = false, success = true } = {}) {
  const transactionHash = id("transaction"), blockNumber = 11, blockHash = hash(11), safeTxHash = id("independently-verified-safe-hash");
  const rows = [...specs];
  if (safe) {
    const event = success ? "ExecutionSuccess" : "ExecutionFailure";
    const iface = new Interface([`event ${event}(bytes32 ${indexed ? "indexed " : ""}txHash,uint256 payment)`]);
    rows.push([prepared.caller, iface, event, [safeTxHash, 0n]]);
  }
  const logs = rows.map(([address, iface, name, args], index) => ({ ...iface.encodeEventLog(iface.getEvent(name), args), address, index, transactionHash, blockHash, blockNumber, removed: false }));
  const tx = { hash: transactionHash, chainId: 31337n, blockHash, blockNumber, from: safe ? A(99) : prepared.caller,
    to: safe ? prepared.caller : prepared.target, value: 0n, data: safe
      ? safeAbi.encodeFunctionData("execTransaction", [prepared.target, 0n, prepared.call.data, 0, 0, 0, 0, ZeroAddress, ZeroAddress, "0x"])
      : prepared.call.data };
  const r = { hash: transactionHash, status: 1, from: tx.from, to: tx.to, blockHash, blockNumber, logs };
  p.getTransaction = async () => tx; p.getTransactionReceipt = async () => r;
  const options = safe ? { transactionHash, execution: "safe", expectedSafeTxHash: safeTxHash } : { transactionHash, execution: "direct" };
  return { tx, receipt: r, options };
}
const paid = (amount = 100n, total = amount, recipient = account) => [profile.wallet, abi.wallet, "NativeReleased", [profile.profileId, account, recipient, amount, total, 100n]];
const initialized = (asset = ZeroAddress, amount = 100n) => [profile.wallet, abi.wallet, "AssetObservationInitialized", [profile.profileId, asset, amount]];
const failed = (index, operation, reason = "0x1234") => [router, abi.router, "ClaimFailed", [profile.wallet, ZeroAddress, account, 1n, BigInt(index), abi.wallet.getFunction(operation).selector, BigInt((reason.length - 2) / 2), reason]];
const releasedState = tag => tag === 11 ? { balance: 0n, total: 100n, released: 100n } : {};

test("capture authenticates initialized clone and source accounting, snapshots before awaits", async () => {
  const { p, captured } = await setup();
  assert.equal(captured.assets[0].releasable, 100n);
  assert.equal(captured.admission, "observed; original target simulation required");
  assert(Object.isFrozen(captured.wallets[0].profile.entries));
  for (const options of [{ chainId: 2n }, { reorg: true }, { code: a => a === profile.wallet ? "0x6000" : undefined },
    { read: n => n === "observedReceived" ? [99n] : undefined }]) await assert.rejects(setup(release(ZeroAddress), options));
  const request = pure.prepareRevenuePullCall(profile.wallet, caller, release(ZeroAddress));
  const d = structuredClone(deployment(request.request));
  const captured2 = await flow.captureRevenuePull(provider({ mutate: () => { d.wallets[0].profile.wallet = A(900); } }), d, request, { blockTag: 10 });
  assert.equal(captured2.prepared.target, profile.wallet);
  assert(p.calls.every(x => x.blockTag === 10));
});

test("deprecated eligibility uses initialized OR strictly before grace; native bypass and high-water are distinct", async () => {
  for (const [initial, grace, eligible] of [[false, 1010n, false], [false, 1011n, true], [true, 0n, true]]) {
    const { captured } = await setup(release(token), { state: () => ({ initialized: initial, status: 3n, grace }) });
    assert.equal(captured.assets[0].eligible, eligible);
  }
  const { captured } = await setup(release(token), { state: () => ({ last: 101n }) });
  assert.equal(captured.assets[0].highWaterIntact, false);
  const native = await setup(release(ZeroAddress), { read: n => { if (n === "assetStatus") throw Error("native policy read"); } });
  assert.equal(native.captured.assets[0].status, null);
});

test("all seven simulations preserve caller/value/gas and exact results including empty router", async () => {
  const requests = [release(ZeroAddress), { kind: "syncAsset", asset: ZeroAddress },
    { kind: "releaseWithAuthorization", authorization: auth(1010n), signature: "0x" },
    { kind: "revokeReleaseAuthorization", nonce: ZeroHash },
    { kind: "revokeReleaseAuthorizationBySignature", account, nonce: ZeroHash, deadline: 1010n, signature: "0x" },
    { kind: "claimMany", claims: [claim(ZeroAddress), claim(ZeroAddress)], continueOnFailure: true },
    { kind: "syncAndClaimMany", claims: [], continueOnFailure: false }];
  for (const request of requests) {
    const { p, captured } = await setup(request);
    const result = await flow.simulateRevenuePull(p, captured, { blockTag: 10, gasLimit: 900000n });
    const tx = p.calls.at(-1);
    assert.equal(tx.from, caller); assert.equal(tx.value, 0n); assert.equal(tx.gasLimit, 900000n);
    assert.equal(tx.data, captured.prepared.call.data);
    if (request.kind === "claimMany") assert.deepEqual(result.amounts, [100n, 0n]);
  }
});

test("original simulation remains authoritative for ERC1271 empty proofs, designated EOAs and rollback", async () => {
  const request = { kind: "releaseWithAuthorization", authorization: auth(1010n), signature: "0x" };
  const { p, captured } = await setup(request, { code: a => a === account ? `0xef0100${"12".repeat(20)}` : undefined });
  await flow.simulateRevenuePull(p, captured, { blockTag: 10, gasLimit: 1000000n });
  const fail = provider({ read: n => { if (n === "releaseWithAuthorization") throw Error("InvalidReleaseSignature"); } });
  await assert.rejects(flow.simulateRevenuePull(fail, captured, { blockTag: 10, gasLimit: 1000000n }), /InvalidReleaseSignature/);
  const bad = provider({ read: n => n === "releaseWithAuthorization" ? { raw: "0x" } : undefined });
  await assert.rejects(flow.simulateRevenuePull(bad, captured, { blockTag: 10, gasLimit: 1000000n }));
  const escaped = structuredClone(captured); escaped.assets[0].releasable = 1n;
  await assert.rejects(flow.simulateRevenuePull(p, escaped, { blockTag: 10, gasLimit: 1000000n }), /Saved capture/);
});

test("direct native and ERC20 receipts join exact wallet payment events and conservative end-block state", async () => {
  const { p, captured, prepared } = await setup(release(ZeroAddress), { state: releasedState });
  const tx = receipt(p, prepared, [paid()]);
  const result = await flow.inspectRevenuePullReceipt(p, captured, tx.options);
  assert.equal(result.items[0].amount, 100n);
  assert.match(result.stateAttribution, /end-block/);
  const erc = await setup(release(token), { state: releasedState });
  const e = [profile.wallet, abi.wallet, "ERC20Released", [profile.profileId, token, account, account, 100n, 100n, 100n]];
  const ercTx = receipt(erc.p, erc.prepared, [e]);
  assert.equal((await flow.inspectRevenuePullReceipt(erc.p, erc.captured, ercTx.options)).items[0].claim.asset, token);
  const later = await setup(release(ZeroAddress), { state: tag => tag === 11 ? { balance: 5n, total: 150n, released: 150n, last: 155n } : {} });
  const laterTx = receipt(later.p, later.prepared, [paid()]);
  assert.equal((await flow.inspectRevenuePullReceipt(later.p, later.captured, laterTx.options)).items[0].amount, 100n);
});

test("both Safe layouts require independent hash and exact inner CALL plus protocol receipt", async () => {
  for (const indexed of [false, true]) {
    const { p, captured, prepared } = await setup(release(ZeroAddress), { state: releasedState });
    const tx = receipt(p, prepared, [paid()], { safe: true, indexed });
    assert.equal((await flow.inspectRevenuePullReceipt(p, captured, tx.options)).events.at(-1).name, "ExecutionSuccess");
    await assert.rejects(flow.inspectRevenuePullReceipt(p, captured, { ...tx.options, expectedSafeTxHash: id("wrong") }), /matching Safe/);
    tx.tx.data = safeAbi.encodeFunctionData("execTransaction", [profile.wallet, 0n, prepared.call.data, 1, 0, 0, 0, ZeroAddress, ZeroAddress, "0x"]);
    await assert.rejects(flow.inspectRevenuePullReceipt(p, captured, tx.options), /ordinary/);
  }
});

test("duplicate router claims retain first payment and second indexed failure without zero inference", async () => {
  const request = { kind: "claimMany", claims: [claim(ZeroAddress), claim(ZeroAddress)], continueOnFailure: true };
  const { p, captured, prepared } = await setup(request, { state: releasedState });
  const tx = receipt(p, prepared, [paid(), failed(1, "release")]);
  const result = await flow.inspectRevenuePullReceipt(p, captured, tx.options);
  assert.deepEqual(result.items.map(x => x.outcome), ["released", "failed"]);
  assert.equal(result.items[1].amount, null);
  const bad = receipt(p, prepared, [paid(), failed(0, "release")]);
  await assert.rejects(flow.inspectRevenuePullReceipt(p, captured, bad.options), /index/);
});

test("sync-success/release-failure preserves observation while failed sync skips release", async () => {
  const request = { kind: "syncAndClaimMany", claims: [claim(ZeroAddress), claim(ZeroAddress)], continueOnFailure: true };
  const { p, captured, prepared } = await setup(request, { state: tag => ({ initialized: tag === 11, last: tag === 11 ? 100n : 0n }) });
  const tx = receipt(p, prepared, [initialized(), failed(0, "release"), failed(1, "syncAsset")]);
  const result = await flow.inspectRevenuePullReceipt(p, captured, tx.options);
  assert.deepEqual(result.items.map(x => x.sync), ["retained", "failed"]);
  assert.equal(result.observed.assets[0].initialized, true);
});

test("zero sync initialization and eventless no-op require original prior history", async () => {
  const request = { kind: "syncAsset", asset: ZeroAddress };
  const fresh = await setup(request, { state: tag => ({ balance: 0n, initialized: tag === 11, last: 0n }) });
  const created = receipt(fresh.p, fresh.prepared, [initialized(ZeroAddress, 0n)]);
  assert.equal((await flow.inspectRevenuePullReceipt(fresh.p, fresh.captured, created.options)).synchronization, "observation-event");
  const absent = receipt(fresh.p, fresh.prepared, []);
  await assert.rejects(flow.inspectRevenuePullReceipt(fresh.p, fresh.captured, absent.options), /prior initialized/);
  const old = await setup(request);
  const noOp = receipt(old.p, old.prepared, []);
  assert.equal((await flow.inspectRevenuePullReceipt(old.p, old.captured, noOp.options)).synchronization, "eventless-with-prior-initialization");
});

test("signed exact amount/nonce0/deadline equality and both revocations reconcile original state", async () => {
  const request = { kind: "releaseWithAuthorization", authorization: auth(1011n), signature: "0x" };
  const signed = await setup(request, { state: tag => ({ ...releasedState(tag), used: tag === 11 }) });
  const tx = receipt(signed.p, signed.prepared, [paid(100n, 100n, A(50))]);
  assert.equal((await flow.inspectRevenuePullReceipt(signed.p, signed.captured, tx.options)).observed.nonce.used, true);
  for (const request of [{ kind: "revokeReleaseAuthorization", nonce: ZeroHash },
    { kind: "revokeReleaseAuthorizationBySignature", account, nonce: ZeroHash, deadline: 1011n, signature: "0x" }]) {
    const x = await setup(request, { state: tag => ({ used: tag === 11 }) });
    const e = [profile.wallet, abi.wallet, "ReleaseAuthorizationRevoked", [request.account ?? caller, ZeroHash, 1n]];
    const tx = receipt(x.p, x.prepared, [e]);
    assert.equal((await flow.inspectRevenuePullReceipt(x.p, x.captured, tx.options)).observed.nonce.used, true);
  }
});

test("empty router succeeds; atomic rollback and absent payment events never become successful items", async () => {
  const empty = await setup({ kind: "claimMany", claims: [], continueOnFailure: true });
  const emptyTx = receipt(empty.p, empty.prepared, []);
  assert.deepEqual((await flow.inspectRevenuePullReceipt(empty.p, empty.captured, emptyTx.options)).items, []);
  const atomic = await setup({ kind: "claimMany", claims: [claim(ZeroAddress)], continueOnFailure: false });
  let tx = receipt(atomic.p, atomic.prepared, [failed(0, "release")]);
  await assert.rejects(flow.inspectRevenuePullReceipt(atomic.p, atomic.captured, tx.options), /failure/);
  tx = receipt(atomic.p, atomic.prepared, []);
  await assert.rejects(flow.inspectRevenuePullReceipt(atomic.p, atomic.captured, tx.options), /Missing release/);
  tx.receipt.status = 0;
  await assert.rejects(flow.inspectRevenuePullReceipt(atomic.p, atomic.captured, tx.options), /success/);
});

test("malformed failure prefixes, callback ambiguity, fake payment and changed receipt blocks fail closed", async () => {
  const request = { kind: "claimMany", claims: [claim(ZeroAddress)], continueOnFailure: true };
  const x = await setup(request, { state: releasedState });
  let tx = receipt(x.p, x.prepared, [paid(), paid()]);
  await assert.rejects(flow.inspectRevenuePullReceipt(x.p, x.captured, tx.options), /Unattributed/);
  const failure = failed(0, "release"); failure[3][6] = 10n;
  tx = receipt(x.p, x.prepared, [failure]);
  await assert.rejects(flow.inspectRevenuePullReceipt(x.p, x.captured, tx.options), /reason length/);
  tx = receipt(x.p, x.prepared, [paid(100n, 99n)]);
  await assert.rejects(flow.inspectRevenuePullReceipt(x.p, x.captured, tx.options), /cumulative/);
  tx = receipt(x.p, x.prepared, [paid()]); tx.receipt.logs[0].data += "00";
  await assert.rejects(flow.inspectRevenuePullReceipt(x.p, x.captured, tx.options), /Noncanonical|Malformed/);
  tx = receipt(x.p, x.prepared, [paid()]); tx.receipt.blockHash = id("different");
  await assert.rejects(flow.inspectRevenuePullReceipt(x.p, x.captured, tx.options), /identity/);
});

test("sync can follow earlier same-block initialization; signed revocation still checks mined deadline", async () => {
  const x = await setup({ kind: "syncAsset", asset: ZeroAddress }, { state: tag => ({ initialized: tag === 11, last: tag === 11 ? 100n : 0n }) });
  const synced = [profile.wallet, abi.wallet, "AssetSynced", [profile.profileId, ZeroAddress, 0n, 100n]];
  const tx = receipt(x.p, x.prepared, [synced]);
  assert.equal((await flow.inspectRevenuePullReceipt(x.p, x.captured, tx.options)).synchronization, "observation-event");
  const expired = await setup({ kind: "revokeReleaseAuthorizationBySignature", account, nonce: ZeroHash, deadline: 1010n, signature: "0x" }, { state: tag => ({ used: tag === 11 }) });
  const revoked = receipt(expired.p, expired.prepared, [[profile.wallet, abi.wallet, "ReleaseAuthorizationRevoked", [account, ZeroHash, 1n]]]);
  await assert.rejects(flow.inspectRevenuePullReceipt(expired.p, expired.captured, revoked.options), /after deadline/);
});

test("provider-owned transaction and log objects cannot mutate during later header awaits", async () => {
  const x = await setup(release(ZeroAddress), { state: releasedState });
  const tx = receipt(x.p, x.prepared, [paid()]);
  const getBlock = x.p.getBlock;
  let copied = false;
  const getReceipt = x.p.getTransactionReceipt;
  x.p.getTransactionReceipt = async () => { copied = true; return getReceipt(); };
  x.p.getBlock = async n => {
    if (copied) {
      tx.tx.from = A(999);
      tx.receipt.logs[0].data = "0x";
      tx.receipt.logs[0].topics[1] = id("changed");
    }
    return getBlock(n);
  };
  const result = await flow.inspectRevenuePullReceipt(x.p, x.captured, tx.options);
  assert.equal(result.items[0].amount, 100n);
});

test("all seven original methods reconcile through both Safe event layouts", async () => {
  const cases = [
    [release(ZeroAddress), [paid()], releasedState],
    [{ kind: "syncAsset", asset: ZeroAddress }, [], () => ({})],
    [{ kind: "releaseWithAuthorization", authorization: auth(1011n), signature: "0x" },
      [paid(100n, 100n, A(50))], tag => ({ ...releasedState(tag), used: tag === 11 })],
    [{ kind: "revokeReleaseAuthorization", nonce: ZeroHash },
      [[profile.wallet, abi.wallet, "ReleaseAuthorizationRevoked", [caller, ZeroHash, 1n]]], tag => ({ used: tag === 11 })],
    [{ kind: "revokeReleaseAuthorizationBySignature", account, nonce: ZeroHash, deadline: 1011n, signature: "0x" },
      [[profile.wallet, abi.wallet, "ReleaseAuthorizationRevoked", [account, ZeroHash, 1n]]], tag => ({ used: tag === 11 })],
    [{ kind: "claimMany", claims: [claim(ZeroAddress), claim(ZeroAddress)], continueOnFailure: true },
      [paid(), failed(1, "release")], releasedState],
    [{ kind: "syncAndClaimMany", claims: [claim(ZeroAddress)], continueOnFailure: true },
      [failed(0, "release")], () => ({})],
  ];
  for (const [request, specs, state] of cases) {
    for (const indexed of [false, true]) {
      const x = await setup(request, { state });
      const tx = receipt(x.p, x.prepared, specs, { safe: true, indexed });
      const out = await flow.inspectRevenuePullReceipt(x.p, x.captured, tx.options);
      assert.equal(out.events.at(-1).name, "ExecutionSuccess");
      assert.equal(out.capture.prepared.request.kind, request.kind);
    }
  }
});
