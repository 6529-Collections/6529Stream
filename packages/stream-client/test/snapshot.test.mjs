import test from "node:test";
import assert from "node:assert/strict";
import { id, keccak256, ZeroAddress, ZeroHash, JsonRpcProvider } from "ethers";
import { StreamClient, contractInterface, snapshotSelectionFromJSON, captureSupportedState, packageSnapshot, verifySnapshotPackage, verifySnapshotReadback, canonicalJSON, validateSnapshot } from "../dist/index.js";

const names = ["core", "manager", "nativeSale", "erc20Sale", "auction", "artistRegistry", "entropy", "executor", "splitFactory", "primaryRevenue", "assetPolicy"];
const addresses = Object.fromEntries(names.map((name, i) => [name, "0x" + String(i + 1).padStart(40, "0")]));
const H = "0x" + "ab".repeat(32), oldCoordinator = "0x" + "99".padStart(40, "0");
const selection = snapshotSelectionFromJSON({ blockNumber: "100", collectionIds: ["1"], tokenIds: ["1"], saleIds: [H], phases: [{ collectionId: "1", phaseId: H }] });
const json = value => JSON.parse(JSON.stringify(value));
function mock({ lifecycle = 2n, failMethod, reorg = false, historical = false, owner = addresses.nativeSale } = {}) {
  const calls = []; let blockReads = 0;
  const zero = p => p.baseType === "array" ? [] : p.baseType === "tuple" ? p.components.map(zero) : /^u?int/.test(p.type) ? 0n : p.type === "bool" ? false : p.type === "address" ? ZeroAddress : p.type === "string" ? "" : p.type === "bytes" ? "0x" : "0x" + "00".repeat(Number(p.type.slice(5)));
  const provider = {
    getNetwork: async () => ({ chainId: 31337n }),
    getBlock: async tag => tag === "latest" ? { number: 102, hash: H } : { number: 100, hash: reorg && ++blockReads > 1 ? ZeroHash : H },
    getCode: async (address, tag) => { assert.equal(tag, "0x64"); calls.push({ code: address }); return "0x60006000"; },
    call: async tx => {
      assert.equal(tx.blockTag, "0x64"); assert.equal(tx.gasLimit, 16000000n);
      const contract = tx.to === oldCoordinator ? "entropy" : names.find(name => addresses[name] === tx.to);
      const iface = contractInterface(contract), parsed = iface.parseTransaction(tx), f = parsed.fragment, m = f.name;
      calls.push({ contract, method: m, address: tx.to });
      if (m === failMethod) throw Error("RPC failure with a private transport detail which must not leak");
      let output = f.outputs.map(zero);
      if (m === "core") output = [addresses.core];
      if (m === "mintManager") output = [addresses.manager];
      if (m === "artistRegistry") output = [addresses.artistRegistry];
      if (m === "splitFactory") output = [addresses.splitFactory];
      if (m === "revenueResolver") output = [addresses.primaryRevenue];
      if (m === "assetPolicyRegistry") output = [addresses.assetPolicy];
      if (m === "getSatellitePointer") {
        const mapping = { MINT_MANAGER: "manager", ARTIST_REGISTRY: "artistRegistry", ENTROPY_COORDINATOR: "entropy", STATE_EXPORT_PUBLISHER: "executor" };
        const key = Object.keys(mapping).find(key => id(key) === parsed.args[0]);
        output[0] = key ? addresses[mapping[key]] : ZeroAddress; output[1] = keccak256("0x60006000");
      }
      if (m === "collectionExists") output = [true];
      if (m === "tokenCollectionIdentity") output = [true, 1n, 1n, lifecycle === 3n];
      if (m === "tokenLifecycle") output = [lifecycle];
      if (m === "coordinatorAtMint") output = [lifecycle === 1n ? ZeroAddress : historical ? oldCoordinator : addresses.entropy];
      if (m === "ownerOf") output = [owner];
      if (m === "tokenURI" || m === "contractURI") output = ['data:application/json;base64,eyJuYW1lIjoiU3RyZWFtIn0='];
      if (m === "phase") output[0] = true;
      if (m === "saleRecord") { output[0][0][0] = 1n; output[0][0][3] = H; output[0][1] = 1n; }
      return iface.encodeFunctionResult(f, output);
    },
  };
  provider.send = async (method, params) => {
    if (method === "eth_chainId") return "0x7a69";
    if (method === "eth_getBlockByNumber") { const value = await provider.getBlock(params[0]); return { ...value, number: "0x" + value.number.toString(16) }; }
    if (method === "eth_getCode") return provider.getCode(...params);
    if (method === "eth_call") return provider.call({ ...params[0], gasLimit: BigInt(params[0].gas), blockTag: params[1] });
    throw Error("Unexpected RPC method " + method);
  };
  return { client: new StreamClient(provider, { schemaVersion: 1, chainId: 31337n, addresses }), calls };
}
test("selection is bounded, explicit and normalized without silently accepting duplicates", () => {
  const base = { blockNumber: "100", collectionIds: ["2", "1"], tokenIds: [], saleIds: [], phases: [] };
  assert.deepEqual(snapshotSelectionFromJSON(base).collectionIds, [1n, 2n]);
  for (const change of [{ collectionIds: ["1", "1"] }, { tokenIds: Array.from({ length: 33 }, (_, i) => String(i + 1)) }, { blockNumber: 100 }, { phases: [{ collectionId: "3", phaseId: H }] }]) assert.throws(() => snapshotSelectionFromJSON({ ...base, ...change }));
});
test("canonical format is key-order independent and rejects non-JSON/lossy values", () => {
  assert.equal(canonicalJSON({ b: "2", a: { y: true, x: "1" } }), '{"a":{"x":"1","y":true},"b":"2"}');
  for (const value of [1n, undefined, NaN, 1.5, -0, "\ud800", { ["\ud800"]: "invalid key" }, new Array(1)]) assert.throws(() => canonicalJSON(value));
});
test("capture verifies offline and by exact pinned-block readback with deterministic bytes", async () => {
  const f = mock(), first = await captureSupportedState(f.client, selection), second = await captureSupportedState(f.client, selection);
  const files = packageSnapshot(first);
  assert.equal(canonicalJSON(first), canonicalJSON(second));
  assert.equal(verifySnapshotPackage(files).block.hash, H);
  await verifySnapshotReadback(f.client, files);
  assert.equal(JSON.parse(files.publication).exportHash, keccak256(new TextEncoder().encode(files.snapshot)));
});
test("getter failure aborts capture with safe function identity; reorg also aborts", async () => {
  await assert.rejects(captureSupportedState(mock({ failMethod: "tokenURI" }).client, selection), /^SnapshotReadError: Supported getter failed: core.tokenURI/);
  await assert.rejects(captureSupportedState(mock({ reorg: true }).client, selection), /reorganized/);
});

test("fresh RPC observations bypass ethers cached block, call and code paths", async () => {
  const fixture = mock({ reorg: true }), requests = [];
  class CachedProvider extends JsonRpcProvider {
    constructor() { super(undefined, 31337, { staticNetwork: true, cacheTimeout: 60000, batchMaxCount: 1 }); }
    // If capture regresses to cached high-level methods these would hide the reorg.
    async getBlock(tag) { return { number: tag === "latest" ? 102 : 100, hash: H }; }
    async call() { throw Error("High-level cached call must not be used"); }
    async getCode() { throw Error("High-level cached code read must not be used"); }
    async _send(payload) {
      assert.equal(Array.isArray(payload), false); requests.push(payload.method);
      return [{ id: payload.id, jsonrpc: "2.0", result: await fixture.client.provider.send(payload.method, payload.params) }];
    }
  }
  const provider = new CachedProvider();
  try {
    await assert.rejects(captureSupportedState(new StreamClient(provider, fixture.client.config), selection), /reorganized/);
    assert.equal(requests.filter(method => method === "eth_getBlockByNumber").length, 3);
    assert.ok(requests.includes("eth_call")); assert.ok(requests.includes("eth_getCode"));
  } finally { provider.destroy(); }
});

test("returned snapshots cannot mutate trusted coverage or compiler/ABI identity", async () => {
  const snapshot = await captureSupportedState(mock().client, selection), before = packageSnapshot(snapshot);
  assert.throws(() => snapshot.coverage.included.push("all private state"), TypeError);
  assert.throws(() => { snapshot.compilation.compilerInputSha256 = H; }, TypeError);
  const artifact = Object.keys(snapshot.compilation.artifacts)[0];
  assert.throws(() => { snapshot.compilation.artifacts[artifact] = H; }, TypeError);
  assert.deepEqual(packageSnapshot(snapshot), before);
  const changed = json(snapshot); changed.compilation.artifacts[artifact] = H;
  assert.throws(() => validateSnapshot(changed), /ABI\/compiler identity/);
});
test("burned and prepared tokens retain identity without pretending ownerOf/tokenURI succeeded", async () => {
  for (const [lifecycle, reason] of [[3n, "burned"], [1n, "prepared-incomplete"]]) {
    const f = mock({ lifecycle }), snapshot = await captureSupportedState(f.client, selection);
    assert.deepEqual(snapshot.unavailable, [{ tokenId: "1", reason, methods: lifecycle === 1n ? ["ownerOf", "tokenURI", "tokenEntropy", "metadataNotificationPending"] : ["ownerOf", "tokenURI"] }]);
    assert.equal(f.calls.some(c => c.method === "ownerOf" || c.method === "tokenURI"), false);
    if (lifecycle === 1n) {
      assert.equal(f.calls.some(c => c.method === "tokenEntropy" || c.method === "metadataNotificationPending"), false);
      assert.equal(snapshot.reads.find(r => r.method === "coordinatorAtMint").value, ZeroAddress);
    }
    assert.ok(snapshot.reads.some(c => c.method === "tokenData"));
    verifySnapshotPackage(packageSnapshot(snapshot));
  }
});
test("token entropy reads follow stored mint coordinator and include its observed code hash", async () => {
  const f = mock({ historical: true }), snapshot = await captureSupportedState(f.client, selection);
  assert.ok(snapshot.reads.some(r => r.method === "tokenEntropy" && r.address === oldCoordinator));
  assert.ok(snapshot.contracts.some(c => c.address === oldCoordinator));
});
test("offline verifier rejects noncanonical files, altered facts, missing coverage, relabeling and hash mismatch", async () => {
  const snapshot = await captureSupportedState(mock().client, selection), files = packageSnapshot(snapshot);
  for (const bad of [{ ...files, snapshot: files.snapshot + "\n" }, { ...files, manifest: files.manifest.replace('snapshot.json', '../other.json') }, { ...files, publication: files.publication.replace(H.slice(2), "cd".repeat(32)) }]) assert.throws(() => verifySnapshotPackage(bad));
  for (const mutate of [s => s.reads.pop(), s => s.coverage.included.push("all private state"), s => { s.compilation.compilerInputSha256 = H; }, s => { s.reads.find(r => r.method === "ownerOf").value = addresses.manager; }, s => { s.contracts.pop(); }]) {
    const changed = json(snapshot); mutate(changed); assert.throws(() => validateSnapshot(changed));
  }
});
test("readback rejects coherently rehashed false facts and a changed canonical block", async () => {
  const original = packageSnapshot(await captureSupportedState(mock().client, selection));
  await assert.rejects(verifySnapshotReadback(mock({ owner: addresses.auction }).client, original), /readback differs/);
  const changed = json(JSON.parse(original.snapshot)); changed.block.hash = ZeroHash;
  const rebundled = packageSnapshot(changed); // Integrity alone cannot authenticate a chain observation.
  await assert.rejects(verifySnapshotReadback(mock().client, rebundled), /readback differs/);
});
