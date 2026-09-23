import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id } from "ethers";
import { currentBurnFinalityFixture } from "../scripts/generate-current-burn-finality-fixture.mjs";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-burn-finality-abi.json", import.meta.url), "utf8"));
const erc20Fixture = JSON.parse(readFileSync(new URL("./fixtures/current-erc20-burn-mint-abi.json", import.meta.url), "utf8"));
const gate = new Interface(fixture.abis.gate), core = new Interface(fixture.abis.core);
const redemption = new Interface(fixture.abis.redemption), finality = new Interface(fixture.abis.finality);
const coder = AbiCoder.defaultAbiCoder();
const address = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;

test("dedicated ERC20 gate keeps the original program encoding but authenticates a separate carrier", () => {
  const erc20Gate = new Interface(erc20Fixture.abis.gate), carrier = new Interface(erc20Fixture.abis.sale);
  assert.equal(erc20Fixture.sourceCommit, "c717a3e10dca06950353c66c6493de41cdfcb9e1");
  for (const name of ["program", "allowedSourceCollections"]) {
    assert.equal(erc20Gate.getFunction(name).format("sighash"), gate.getFunction(name).format("sighash"));
    assert.deepEqual(erc20Gate.getFunction(name).outputs.map(p => p.format("sighash")), gate.getFunction(name).outputs.map(p => p.format("sighash")));
  }
  assert.equal(erc20Gate.getEvent("BurnMintProgramConfigured").format("full"), gate.getEvent("BurnMintProgramConfigured").format("full"));
  // ERC165 excludes inherited IStreamMintGate functions from this interface ID.
  const own = ["core", "erc20SaleAdapter", "erc20SaleCodeHash", "configureProgram", "program", "programConfigHash", "allowedSourceCollections", "burnNullifier", "previewERC20Burn", "executeERC20Burn"];
  assert.equal(own.reduce((n, name) => n ^ BigInt(erc20Gate.getFunction(name).selector), 0n), 0xdf1ac32an);
  for (const [abi, methods] of [[erc20Gate, { erc20SaleAdapter: "address", erc20SaleCodeHash: "bytes32", supportsInterface: "bool" }],
    [carrier, { core: "address", coreCodeHash: "bytes32", moduleRegistry: "address", moduleRegistryCodeHash: "bytes32", mintManager: "address", mintManagerCodeHash: "bytes32" }]]) {
    for (const [name, type] of Object.entries(methods)) {
      const fn = abi.getFunction(name);
      assert.equal(fn.stateMutability, "view");
      assert.deepEqual(fn.outputs.map(p => p.type), [type]);
    }
  }
});

test("burn warning evidence pins compiler inputs and only exact view/event interfaces", () => {
  assert.equal(fixture.sourceCommit, "2e0fca1aef41a023d76a9717651a699bbd7db155");
  assert.equal(fixture.sourceCount, 2098);
  assert.equal(Object.keys(fixture.sources).length, 10);
  assert.match(fixture.qualification, /no current-stack execution/);
  assert.throws(() => currentBurnFinalityFixture(Buffer.from("{}"), Buffer.from("{}")), /exact frozen/);
  for (const abi of Object.values(fixture.abis)) {
    for (const item of abi) {
      assert(["event", "function"].includes(item.type));
      if (item.type === "function") assert.equal(item.stateMutability, "view");
    }
  }
  for (const name of ["collectionExists", "collectionHasMaxSupply", "collectionFreezeStatus", "collectionBurnsBlocked"]) {
    assert.equal(core.getFunction(name).outputs[0].type, "bool");
  }
  assert.equal(core.getFunction("collectionBurnsBlockedAtBlock").outputs[0].type, "uint64");
  assert.equal(finality.getFunction("finalityStateForScope"), null);
});

test("burn-mint discovery retains the original indexed identity and complete dynamic program", () => {
  const config = { manager: address(4), targetCollectionId: (1n << 220n) + 2n, phaseId: id("phase"),
    sourceCollectionIds: [1n, (1n << 200n) + 1n], sourcesPerMint: 2n,
    startsAt: 7n, endsAt: 900n, prepared: false, nativeSaleAdapter: address(5) };
  const event = gate.getEvent("BurnMintProgramConfigured"), configHash = id("config");
  assert.equal(event.format("sighash"), "BurnMintProgramConfigured(uint16,uint256,address,bytes32,bytes32,(address,uint256,bytes32,uint256[],uint8,uint64,uint64,bool,address))");
  assert.deepEqual(event.inputs.filter(input => input.indexed).map(input => input.name), ["targetCollectionId", "manager", "phaseId"]);
  const encoded = gate.encodeEventLog(event, [1n, config.targetCollectionId, config.manager, config.phaseId, configHash, config]);
  const decoded = gate.decodeEventLog(event, encoded.data, encoded.topics);
  assert.equal(decoded.targetCollectionId, config.targetCollectionId);
  assert.deepEqual(Array.from(decoded.config.sourceCollectionIds), config.sourceCollectionIds);
  assert.equal(gate.getFunction("program").outputs[0].components[0].components.length, 9);
});

test("redemption discovery uses kind-nine SaleConfigured and separate immutable terms", () => {
  assert.equal(redemption.getEvent("ProgramConfigured"), null);
  const saleId = id("sale"), collection = (1n << 200n) + 73n, configHash = id("config");
  const configured = redemption.encodeEventLog("SaleConfigured", [1n, saleId, collection, ZeroHash, 9n, ZeroAddress, configHash, ZeroHash, 0n]);
  const parsed = redemption.parseLog(configured);
  assert.equal(parsed.args.saleKind, 9n); assert.equal(parsed.args.collectionId, collection);
  const terms = redemption.encodeEventLog("RedemptionTermsRecorded", [1n, saleId, id("terms"), 10n, 20n, 3n, address(8)]);
  assert.equal(redemption.parseLog(terms).args.saleNonce, 3n);
  const result = redemption.getFunction("program").outputs[0];
  assert.deepEqual(result.components[0].components.map(input => input.name), ["collectionId", "startTime", "endTime", "termsHash"]);
  assert.equal(result.components.at(-1).name, "cancelled");
});

test("collection scope encoding preserves scope zero and distinct token/release/season/view identities", () => {
  const collection = 9007199254740993n;
  for (const method of ["artworkScopeFinalityRecord", "artworkFreezeMode"]) {
    const collectionCall = finality.encodeFunctionData(method, [[0n, collection, 0n, ZeroHash]]);
    assert.equal(collectionCall, id(`${method}((uint8,uint256,uint256,bytes32))`).slice(0, 10)
      + coder.encode(["uint8", "uint256", "uint256", "bytes32"], [0n, collection, 0n, ZeroHash]).slice(2));
    for (const scopeType of [1n, 2n, 3n, 4n]) {
      const scope = [scopeType, collection, scopeType === 1n ? 7n : 0n, scopeType === 1n ? ZeroHash : id("scope")];
      assert.notEqual(finality.encodeFunctionData(method, [scope]), collectionCall);
    }
  }
  assert.deepEqual(finality.getFunction("collectionFinalityRecord").outputs[0].components.map(input => input.name),
    ["finalized", "finalityRecordHash", "manifestContentHash", "manifestURIHash", "finalityManifestURI", "componentsHash", "manifestPointer", "finalizedAt"]);
});
