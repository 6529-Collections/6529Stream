import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, ZeroHash, concat, id, keccak256 } from "ethers";
import * as curated from "../dist/current-curated-content.js";

const coder = AbiCoder.defaultAbiCoder();
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const H = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
const chain = 31337n, adapter = A(1), manager = A(2), buyer = A(3), sale = id("immutable sale"), phase = id("phase");
const encodeHash = (types, values) => keccak256(coder.encode(types, values));
const leaf = (contentId, dataHash) => keccak256(encodeHash(
  ["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
  [id("6529STREAM_CONTENT_LEAF_V1"), chain, adapter, sale, contentId, dataHash]));
const pair = (a, b) => keccak256(concat(BigInt(a) < BigInt(b) ? [a, b] : [b, a]));
const input = () => ({ chainId: chain, adapter, manager, saleId: sale, collectionId: 9007199254740993n,
  phaseId: phase, counterId: id("context counter"), rows: [
    { contentId: H(0), tokenDataHash: keccak256("0x"), previewURI: "ipfs://empty-work" },
    { contentId: H(2), tokenDataHash: keccak256("0x1234"), previewURI: "ipfs://work-two" },
    { contentId: H(9), tokenDataHash: keccak256("0xff"), previewURI: "ipfs://work-nine" },
  ] });

test("final carrier fixture pins the joined commit and selected compiled shapes", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-curated-abi.json", import.meta.url), "utf8"));
  assert.equal(fixture.sourceCommit, "5605d019bc9cb933398f626df77b84d1cd2a51ba");
  assert.equal(fixture.sourceTree, "0b12c46b997a6682cd48e2d8d7049d55ff6d755d");
  assert.equal(fixture.sourceCount, 128); assert.equal(Object.keys(fixture.sources).length, 128);
  assert.equal(fixture.inputSha256, "d1db6188f922acc490973cae67fbfecdd4fcfb31df18b909901acb57bb6a8101");
  assert.equal(fixture.outputSha256, "a2783ea8778a84012c7c9b96d9983b434fdb75e6ceade1dbbe2bf8a26aa14ca7");
  for (const [key, target] of Object.entries(fixture.selections)) {
    const iface = new Interface(fixture.abis[key]);
    for (const name of target.methods) assert(iface.getFunction(name), `${key}.${name}`);
  }
  const fixed = new Interface(fixture.abis.fixed), priv = new Interface(fixture.abis.private);
  assert.equal(fixed.getFunction("commitSelection").stateMutability, "payable");
  assert.equal(fixed.getFunction("selectionDeposit").outputs[0].components[2].type, "uint8");
  assert.equal(priv.getFunction("purchasePrivateContent").inputs[0].components.length, 24);
  assert.equal(priv.getFunction("curatedSaleAuthorizationBinding").outputs.length, 5);
});

test("sale, purchase, content and selection hashes preserve original distinct domains", () => {
  const nonce = (1n << 200n) + 17n;
  for (const kind of [0n, 5n]) {
    const expected = encodeHash(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
      [id("6529STREAM_SALE_V1"), chain, adapter, kind, 9n, phase, nonce]);
    assert.equal(curated.curatedSaleId(chain, adapter, kind, 9n, phase, nonce), expected);
  }
  assert.throws(() => curated.curatedSaleId(chain, adapter, 1n, 9n, phase, nonce));
  const purchase = encodeHash(["bytes32", "uint256", "address", "bytes32", "address", "uint256"],
    [id("6529STREAM_SALE_PURCHASE_V1"), chain, adapter, sale, buyer, nonce]);
  assert.equal(curated.curatedPurchaseId(chain, adapter, sale, buyer, nonce), purchase);
  const dataHash = keccak256("0x"), content = leaf(ZeroHash, dataHash);
  assert.equal(curated.curatedContentLeaf(chain, adapter, sale, ZeroHash, dataHash), content);
  assert.equal(curated.curatedContentContextHash(chain, adapter, sale, ZeroHash), encodeHash(
    ["bytes32", "uint256", "address", "bytes32", "bytes32"], [id("6529STREAM_CONTENT_CONTEXT_V1"), chain, adapter, sale, ZeroHash]));
  const commitment = encodeHash(["bytes32", "uint256", "address", "bytes32", "address", "bytes32", "bytes32"],
    [id("6529STREAM_CONTENT_COMMIT_V1"), chain, adapter, sale, buyer, content, ZeroHash]);
  assert.equal(curated.curatedSelectionCommitment(chain, adapter, sale, buyer, content, ZeroHash), commitment);
  assert.notEqual(commitment, purchase);
  for (const args of [[chain + 1n, adapter, sale, buyer], [chain, A(9), sale, buyer], [chain, adapter, id("other sale"), buyer], [chain, adapter, sale, A(9)]]) {
    assert.notEqual(curated.curatedSelectionCommitment(...args, content, ZeroHash), commitment);
  }
});

test("three-row manifest preserves ID order, exact ABI bytes and odd-leaf promotion", () => {
  const source = input(), manifest = curated.buildCuratedManifest(source), leaves = source.rows.map(r => leaf(r.contentId, r.tokenDataHash));
  const root = pair(pair(leaves[0], leaves[1]), leaves[2]);
  assert.equal(manifest.publication.manifestRoot, root);
  assert.notEqual(root, pair(pair(leaves[0], leaves[1]), pair(leaves[2], leaves[2])));
  assert.deepEqual(manifest.selections.map(s => s.proof), [[leaves[1], leaves[2]], [leaves[0], leaves[2]], [pair(leaves[0], leaves[1])]]);
  const raw = coder.encode(["tuple(bytes32 contentId,bytes32 tokenDataHash,string previewURI)[]"], [source.rows]);
  assert.equal(manifest.manifestBytes, raw); assert.equal(manifest.publication.manifestHash, keccak256(raw));
  const tuple = "tuple(uint256 chainId,address manager,address house,bytes32 saleId,uint256 collectionId,bytes32 phaseId,bytes32 manifestRoot,bytes32 manifestHash,bytes32 counterId)";
  const expected = encodeHash(["bytes32", tuple, "bytes32", "bytes32"],
    [id("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1"), manifest.publication, id("manager code"), id("carrier code")]);
  assert.equal(curated.curatedContentGateConfigHash(manifest, id("manager code"), id("carrier code")), expected);
  assert.throws(() => curated.curatedContentGateConfigHash({ ...manifest, publication: { ...manifest.publication, manifestRoot: H(1) } }, id("manager code"), id("carrier code")));
});

test("manifest selections compose directly with proof verification and purchase normalization", () => {
  const manifest = curated.buildCuratedManifest(input());
  for (const [index, raw] of ["0x", "0x1234", "0xff"].entries()) {
    const content = manifest.selections[index];
    assert.equal(curated.verifyCuratedContentProof(chain, adapter, sale, manifest.publication.manifestRoot, content), true);
    const selected = curated.normalizeCuratedSelection({ content, tokenData: raw, mintCommitment: id("mint"), recipient: buyer, purchaseNonce: 1n });
    assert.deepEqual(selected.content, content); assert(Object.isFrozen(selected.content.proof));
    assert.equal(curated.verifyCuratedContentProof(chain, adapter, id("other sale"), manifest.publication.manifestRoot, content), false);
  }
  const single = curated.buildCuratedManifest({ ...input(), rows: [input().rows[0]] });
  assert.deepEqual(single.selections[0].proof, []);
  assert.equal(single.publication.manifestRoot, leaf(ZeroHash, keccak256("0x")));
});

test("manifest builders reject silent sorting, duplicate IDs and invalid previews; inputs are snapshotted", () => {
  const source = input(), manifest = curated.buildCuratedManifest(source);
  assert.throws(() => curated.buildCuratedManifest({ ...input(), rows: input().rows.toReversed() }), /increasing/);
  assert.throws(() => curated.buildCuratedManifest({ ...input(), rows: [source.rows[0], source.rows[0]] }), /increasing/);
  assert.throws(() => curated.buildCuratedManifest({ ...input(), rows: [{ ...source.rows[0], previewURI: "" }] }), /preview/);
  assert.throws(() => curated.buildCuratedManifest({ ...input(), rows: [{ ...source.rows[0], tokenDataHash: ZeroHash }] }), /bytes32/);
  assert.throws(() => curated.buildCuratedManifest({ ...input(), rows: [{ ...source.rows[0], previewURI: "é".repeat(4097) }] }), /bound/);
  source.rows[0].previewURI = "changed"; source.rows.reverse(); source.saleId = H(2);
  assert.equal(manifest.rows[0].previewURI, "ipfs://empty-work"); assert.equal(manifest.coordinates.saleId, sale);
  assert(Object.isFrozen(manifest.rows)); assert(Object.isFrozen(manifest.publication));
});

test("selection enforces carrier byte/hash/nonce rules and strict delegation booleans", () => {
  const make = raw => ({ content: { contentId: ZeroHash, tokenDataHash: keccak256(raw), proof: [] }, tokenData: raw,
    mintCommitment: id("mint"), recipient: buyer, purchaseNonce: 1n });
  assert.doesNotThrow(() => curated.normalizeCuratedSelection(make(`0x${"01".repeat(8192)}`)));
  assert.throws(() => curated.normalizeCuratedSelection(make(`0x${"01".repeat(8193)}`)), /byte limit/);
  assert.throws(() => curated.normalizeCuratedSelection({ ...make("0x"), tokenData: "0x01" }), /selected hash/);
  assert.throws(() => curated.normalizeCuratedSelection({ ...make("0x"), mintCommitment: ZeroHash }));
  assert.throws(() => curated.normalizeCuratedSelection({ ...make("0x"), purchaseNonce: 0n }));
  assert.throws(() => curated.normalizeCuratedDelegationWitness({ walletWide: "false", index: 0n }), /boolean/);
  assert.deepEqual(curated.normalizeCuratedDelegationWitness({ walletWide: false, index: 1n << 200n }), { walletWide: false, index: 1n << 200n });
});

async function gateFixture() {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-curated-abi.json", import.meta.url), "utf8"));
  const iface = new Interface(fixture.abis.gate), manifest = curated.buildCuratedManifest(input());
  const gate = A(10), managerCode = "0x6001", adapterCode = "0x6002";
  const configHash = curated.curatedContentGateConfigHash(manifest, keccak256(managerCode), keccak256(adapterCode));
  const values = { publication: manifest.publication, manifestBytes: manifest.manifestBytes, itemCount: 3n,
    contentPurchaseVersion: id("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1"), managerCodeHash: keccak256(managerCode),
    houseCodeHash: keccak256(adapterCode), gateConfigHash: configHash };
  const calls = [];
  const provider = {
    getNetwork: async () => ({ chainId: chain }),
    call: async tx => {
      assert.equal(tx.to.toLowerCase(), gate); assert.equal(tx.blockTag, 99); calls.push(tx);
      const parsed = iface.parseTransaction(tx);
      return iface.encodeFunctionResult(parsed.fragment, [values[parsed.name]]);
    },
    getCode: async (target, block) => { assert.equal(block, 99); return target === manager ? managerCode : adapterCode; },
  };
  return { provider, manifest, gate, configHash, values, calls, iface };
}

test("pinned manifest readback compares complete retained bytes, capability and saved runtime observations", async () => {
  const f = await gateFixture();
  const result = await curated.inspectCuratedManifest(f.provider, f.gate, f.manifest, { blockTag: 99 });
  assert.equal(result.gateConfigHash, f.configHash); assert.equal(f.calls.length, 7);
  assert.match(result.evidenceBoundary, /no reorg check/);
  f.values.contentPurchaseVersion = id("auction-only gate");
  await assert.rejects(curated.inspectCuratedManifest(f.provider, f.gate, f.manifest, { blockTag: 99 }), /capability/);
});

test("manifest readback rejects altered bytes, oversized replies, malformed tuples and changed bound runtimes", async () => {
  const f = await gateFixture();
  const run = provider => curated.inspectCuratedManifest(provider, f.gate, f.manifest, { blockTag: 99 });
  await assert.rejects(run({ ...f.provider, getNetwork: async () => ({ chainId: 1n }) }), /chain/);
  await assert.rejects(run({ ...f.provider, call: async () => `0x${"00".repeat(289)}` }), /oversized/);
  await assert.rejects(run({ ...f.provider, call: async () => "0x" }));
  await assert.rejects(run({ ...f.provider, getCode: async () => "0x6003" }), /runtime differs/);
  f.values.manifestBytes = f.manifest.manifestBytes.replace(/.{2}$/, "ff");
  await assert.rejects(run(f.provider), /bytes or count/);
  await assert.rejects(curated.inspectCuratedManifest(f.provider, f.gate, f.manifest, { blockTag: "latest" }), /Concrete/);
});

test("manifest inspection snapshots caller coordinates and rows before its first await", async () => {
  const f = await gateFixture();
  const expected = { ...f.manifest, coordinates: { ...f.manifest.coordinates }, rows: f.manifest.rows.map(row => ({ ...row })) };
  const provider = { ...f.provider, getNetwork: async () => {
    expected.coordinates.adapter = A(19); expected.rows[0].previewURI = "changed-during-await";
    return { chainId: chain };
  } };
  const result = await curated.inspectCuratedManifest(provider, f.gate, expected, { blockTag: 99 });
  assert.equal(result.publication.house, adapter); assert.equal(result.gateConfigHash, f.configHash);
});
