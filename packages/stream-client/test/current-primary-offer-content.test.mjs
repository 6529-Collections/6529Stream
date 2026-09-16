import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, ZeroHash, id, keccak256 } from "ethers";
import { buildCuratedManifest, curatedContentGateConfigHash, verifyCuratedContentProof } from "../dist/current-curated-content.js";
import { primaryOfferGateConfigHash, inspectPrimaryOfferManifest } from "../dist/current-primary-offer-content.js";

const fixture = JSON.parse(await readFile(new URL("./fixtures/current-primary-offer-abi.json", import.meta.url), "utf8"));
const abi = new Interface(fixture.abis.gate), coder = AbiCoder.defaultAbiCoder();
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chain = 31337n, adapter = A(1), manager = A(2), gate = A(3), phase = id("offer phase");
const saleId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
  [id("6529STREAM_SALE_V1"), chain, adapter, 6n, 8n, phase, 1n]));
const make = () => buildCuratedManifest({ chainId: chain, manager, adapter, saleId, collectionId: 8n, phaseId: phase,
  counterId: id("content once"), rows: [0n, 1n, 2n].map(n => ({ contentId: `0x${n.toString(16).padStart(64, "0")}`,
    tokenDataHash: keccak256(`0x0${n}`), previewURI: `ipfs://work-${n}` })) });
const managerCode = "0x60016002", adapterCode = "0x60026003";
const managerHash = keccak256(managerCode), adapterHash = keccak256(adapterCode);
const publicationTuple = "tuple(uint256 chainId,address manager,address house,bytes32 saleId,uint256 collectionId,bytes32 phaseId,bytes32 manifestRoot,bytes32 manifestHash,bytes32 counterId)";
function rpc(manifest = make(), overrides = {}) {
  const calls = [];
  const answers = { publication: [manifest.publication], manifestBytes: [manifest.manifestBytes], itemCount: [3n],
    gateConfigHash: [primaryOfferGateConfigHash(manifest, managerHash, adapterHash)], managerCodeHash: [managerHash],
    houseCodeHash: [adapterHash], offerPurchaseVersion: [id("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1")], ...overrides };
  return { calls, getNetwork: async () => ({ chainId: chain }), getCode: async (target, block) => {
    assert.equal(block, 77); return target === manager ? managerCode : adapterCode;
  }, call: async tx => {
    calls.push(tx); assert.equal(tx.to, gate); assert.equal(tx.blockTag, 77);
    const method = abi.parseTransaction(tx).name, value = answers[method];
    return typeof value === "string" ? value : abi.encodeFunctionResult(method, value);
  } };
}

test("offer gate retains original manifest preimages with an independent offer capability", () => {
  const manifest = make();
  const expected = keccak256(coder.encode(["bytes32", publicationTuple, "bytes32", "bytes32"],
    [id("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1"), manifest.publication, managerHash, adapterHash]));
  assert.equal(primaryOfferGateConfigHash(manifest, managerHash, adapterHash), expected);
  assert.notEqual(expected, curatedContentGateConfigHash(manifest, managerHash, adapterHash));
  assert.equal(manifest.rows[0].contentId, ZeroHash);
  for (const selected of manifest.selections) assert(verifyCuratedContentProof(chain, adapter, saleId, manifest.publication.manifestRoot, selected));
  assert.throws(() => primaryOfferGateConfigHash({ ...manifest, manifestBytes: "0x" }, managerHash, adapterHash), /complete rows/);
  assert.throws(() => primaryOfferGateConfigHash(manifest, ZeroHash, adapterHash), /runtime hash/);
});

test("offer inspector uses seven compiled getters at the pinned numeric block", async () => {
  const manifest = make(), provider = rpc(manifest);
  const result = await inspectPrimaryOfferManifest(provider, gate, manifest, { blockTag: 77 });
  assert.equal(result.gateConfigHash, primaryOfferGateConfigHash(manifest, managerHash, adapterHash));
  assert.equal(provider.calls.length, 7); assert(Object.isFrozen(result));
  assert.match(result.evidenceBoundary, /no reorg check/);
});

test("kind-5 capability, altered publication and altered full bytes cannot impersonate an offer gate", async () => {
  const manifest = make();
  for (const overrides of [
    { offerPurchaseVersion: [id("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1")] },
    { publication: [{ ...manifest.publication, saleId: id("different offer") }] },
    { manifestBytes: [manifest.manifestBytes.replace(/.$/, manifest.manifestBytes.endsWith("0") ? "1" : "0")] },
    { itemCount: [2n] }, { gateConfigHash: [id("different config")] },
  ]) await assert.rejects(inspectPrimaryOfferManifest(rpc(manifest, overrides), gate, manifest, { blockTag: 77 }));
});

test("offer reads reject oversized/noncanonical RPC results and runtime changes", async () => {
  const manifest = make();
  for (const overrides of [
    { publication: `${abi.encodeFunctionResult("publication", [manifest.publication])}${"00".repeat(32)}` },
    { itemCount: `0x${"00".repeat(64)}` },
    { manifestBytes: `0x${"00".repeat(10000)}` }, { managerCodeHash: [ZeroHash] },
  ]) await assert.rejects(inspectPrimaryOfferManifest(rpc(manifest, overrides), gate, manifest, { blockTag: 77 }));
  const provider = rpc(manifest); provider.getCode = async () => "0x6004";
  await assert.rejects(inspectPrimaryOfferManifest(provider, gate, manifest, { blockTag: 77 }), /runtime/);
  await assert.rejects(inspectPrimaryOfferManifest(rpc(manifest), gate, manifest, { blockTag: -1 }), /block/);
});

test("offer inspector snapshots all expected rows and coordinates before the first await", async () => {
  const stable = make(), expected = structuredClone(stable), options = { blockTag: 77 }, provider = rpc(stable);
  provider.getNetwork = async () => {
    expected.rows[0].previewURI = "ipfs://changed";
    expected.coordinates.adapter = A(9); expected.publication.saleId = id("changed"); options.blockTag = 99;
    return { chainId: chain };
  };
  const result = await inspectPrimaryOfferManifest(provider, gate, expected, options);
  assert.deepEqual(result.publication, stable.publication); assert.equal(result.blockTag, 77);
});
