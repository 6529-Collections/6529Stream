import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, id, keccak256 } from "ethers";
import * as burn from "../dist/current-burn-mint.js";

// Independent literal production preimages from 57d70b58 / integrated 9acd68f7.
// These establish encoding only; no source permission, fee or execution claim.
const coder = AbiCoder.defaultAbiCoder();
const address = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chainId = 31337n, gate = address(1), core = address(2), registry = address(3);
const config = { manager: address(4), targetCollectionId: 9007199254740993n, phaseId: id("burn phase"),
  sourceCollectionIds: [1n, 9007199254740995n], sourcesPerMint: 2n,
  startsAt: 0n, endsAt: (1n << 64n) - 1n, prepared: true, nativeSaleAdapter: ZeroAddress };
const configType = "tuple(address manager,uint256 targetCollectionId,bytes32 phaseId,uint256[] sourceCollectionIds,uint8 sourcesPerMint,uint64 startsAt,uint64 endsAt,bool prepared,address nativeSaleAdapter)";
function configHash(value) {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", configType],
    [id("6529STREAM_BURN_MINT_CONFIG_V1"), chainId, gate, core, registry, value]));
}

test("burn program hash binds the complete dynamic source list and route configuration", () => {
  assert.equal(burn.burnMintProgramConfigHash(chainId, gate, core, registry, config), configHash(config));
  for (const changed of [{ ...config, prepared: false }, { ...config, prepared: false, nativeSaleAdapter: address(5) },
    { ...config, sourceCollectionIds: [1n, 9007199254740997n] }, { ...config, sourcesPerMint: 1n }]) {
    assert.equal(burn.burnMintProgramConfigHash(chainId, gate, core, registry, changed), configHash(changed));
    assert.notEqual(configHash(changed), configHash(config));
  }
  assert.notEqual(burn.burnMintProgramConfigHash(chainId, address(6), core, registry, config), configHash(config));
  assert.throws(() => burn.burnMintProgramConfigHash(chainId, gate, core, registry, { ...config, endsAt: 1n << 64n }));
  assert.throws(() => burn.burnMintProgramConfigHash(chainId, gate, core, registry, { ...config, prepared: 1n }));
});

test("burn nullifier retains original chain, Core and full-width source token identity", () => {
  const tokenId = (1n << 255n) + 6529n;
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "uint256"],
    [id("6529STREAM_BURN_NULLIFIER_V1"), chainId, core, tokenId]));
  assert.equal(burn.burnMintNullifier(chainId, core, tokenId), expected);
  assert.notEqual(burn.burnMintNullifier(chainId + 1n, core, tokenId), expected);
  assert.notEqual(burn.burnMintNullifier(chainId, address(6), tokenId), expected);
  assert.notEqual(burn.burnMintNullifier(chainId, core, tokenId + 1n), expected);
});

test("source producer preserves ordered IDs and rejects noncanonical or wrong-ratio lists", () => {
  const sources = [1n, 2n, 9007199254740993n, 9007199254740995n];
  const normalized = burn.normalizeBurnMintSources(sources, 2n, 2n);
  assert.deepEqual(normalized, sources);
  assert.equal(Object.isFrozen(normalized), true);
  sources[0] = 99n;
  assert.equal(normalized[0], 1n);
  for (const invalid of [[], [2n, 1n], [1n, 1n], [1n, 2n, 3n]]) {
    assert.throws(() => burn.normalizeBurnMintSources(invalid, 2n, 1n));
  }
  assert.throws(() => burn.normalizeBurnMintSources(Array.from({ length: 17 }, (_, i) => BigInt(i + 1)), 1n, 17n));
  assert.throws(() => burn.normalizeBurnMintSources([1n], 1, 1n));
});
