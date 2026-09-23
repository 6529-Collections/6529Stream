import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, TypedDataEncoder, id, keccak256 } from "ethers";
import * as price from "../dist/current-native-allowlist-price.js";

// Literal production preimages at f1745f33, independent of client hash helpers.
// These are encoding oracles, not contract execution or proof-eligibility evidence.
const coder = AbiCoder.defaultAbiCoder();
const address = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chainId = 31337n, adapter = address(1), payer = address(2), owner = address(3);
const zero = `0x${"00".repeat(32)}`;
const configType = "tuple(uint256 collectionId,bytes32 phaseId,uint8 kind,uint256 minUnitPrice,uint256 maxUnitPrice,uint64 maxSaleQuantity,uint64 startsAt,uint64 endsAt,uint8 closeRule,bytes32 mintPolicyHash,bytes32 primaryAssignmentHash)";
const policyType = "tuple(bytes32 counterId,bool allowFree)";
const proofType = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)";
const config = { collectionId: 9007199254740997n, phaseId: id("oracle phase"), kind: 0n,
  minUnitPrice: 100n, maxUnitPrice: 100n, maxSaleQuantity: (1n << 64n) - 1n,
  startsAt: 1n, endsAt: 0n, closeRule: 2n, mintPolicyHash: id("mint policy"), primaryAssignmentHash: id("assignment") };
const policy = { counterId: id("selected counter"), allowFree: true };
const nonce = (1n << 255n) + 123n;
const proof = { maxCount: (1n << 64n) - 1n, hasPriceOverride: true, priceOverride: 150n, proof: [id("sibling")] };
const plain = { maxCount: 1n, hasPriceOverride: false, priceOverride: 0n, proof: [] };

function hashes(c = config, p = policy, saleNonce = nonce) {
  const saleId = keccak256(coder.encode(
    ["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), chainId, adapter, c.kind, c.collectionId, c.phaseId, saleNonce],
  ));
  const original = keccak256(coder.encode(["bytes32", "bytes32", configType],
    [id("6529STREAM_NATIVE_PRICE_PROGRAM_CONFIG_V1"), saleId, c]));
  const wrapped = keccak256(coder.encode(["bytes32", "bytes32", policyType],
    [id("6529STREAM_NATIVE_ALLOWLIST_PRICE_PROGRAM_CONFIG_V1"), original, p]));
  return { saleId, original, wrapped };
}
function purchaseInput(selectedProof = proof) {
  return { chosenUnitPrice: selectedProof.hasPriceOverride ? selectedProof.priceOverride : 100n,
    tokenData: "0x00123400", platformSignature: "0xdeadbeef", artistSignature: "0xaabb", revealFeeAllowance: 7n,
    proofGroups: [{ counterId: id("other counter"), proof: plain }, { counterId: policy.counterId, proof: selectedProof }] };
}
function authorization() {
  const h = hashes();
  return { saleId: h.saleId, saleConfigHash: h.wrapped, payer, executor: payer, recipient: address(4), artist: address(5),
    tokenDataHash: keccak256("0x00123400"), mintCommitment: id("commitment"), executionNonce: nonce,
    nonce: id("authorization nonce"), deadline: (1n << 64n) - 1n, expectedPrimaryPolicyHash: id("primary policy"), unitPrice: 100n };
}

test("allowlist registration preserves full-width sale ID and both configuration preimages", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-allowlist-price-abi.json", import.meta.url)));
  const abi = new Interface(fixture.abi);
  for (const c of [config, { ...config, kind: 1n, maxSaleQuantity: 0n }, { ...config, kind: 13n, maxUnitPrice: 200n }]) {
    const p = { ...policy, allowFree: c.kind !== 13n }, h = hashes(c, p);
    const prepared = price.prepareNativeAllowlistPriceRegistration(chainId, adapter, owner, nonce, c, p);
    assert.equal(prepared.saleId, h.saleId);
    assert.equal(prepared.originalConfigHash, h.original);
    assert.equal(prepared.configHash, h.wrapped);
    assert.equal(prepared.call.data, abi.encodeFunctionData("registerAllowlistPriceProgram", [c, p]));
    assert.equal(prepared.call.value, 0n);
    assert.notEqual(hashes(c, p, nonce + 1n).saleId, h.saleId);
  }
  assert.notEqual(hashes(config, { ...policy, allowFree: false }).wrapped, hashes().wrapped);
  assert.notEqual(hashes({ ...config, mintPolicyHash: id("changed policy") }).wrapped, hashes().wrapped);
});

test("pricing oracle distinguishes original fixed price, free declaration and PWYW floor", () => {
  for (const kind of [0n, 1n]) {
    const c = { ...config, kind, maxSaleQuantity: kind === 1n ? 0n : 10n };
    for (const override of [0n, 2n, 150n, (1n << 255n) + 1n]) {
      assert.deepEqual(price.nativeAllowlistPriceMatrix(c, policy, 100n, { ...proof, priceOverride: override }),
        { overridden: true, effectiveMinimum: override, effectiveMaximum: override });
    }
    assert.throws(() => price.nativeAllowlistPriceMatrix(c, { ...policy, allowFree: false }, 100n, { ...proof, priceOverride: 0n }));
    assert.throws(() => price.nativeAllowlistPriceMatrix(c, policy, 150n, proof));
  }
  const c = { ...config, kind: 13n, minUnitPrice: 10n, maxUnitPrice: 200n }, p = { ...policy, allowFree: false };
  for (const [selected, minimum] of [[plain, 100n], [{ ...proof, priceOverride: 0n }, 10n], [{ ...proof, priceOverride: 150n }, 150n]]) {
    assert.deepEqual(price.nativeAllowlistPriceMatrix(c, p, 100n, selected),
      { overridden: selected.hasPriceOverride, effectiveMinimum: minimum, effectiveMaximum: 200n });
  }
  const free = { ...config, kind: 12n, minUnitPrice: 0n, maxUnitPrice: 0n, primaryAssignmentHash: zero };
  assert.deepEqual(price.nativeAllowlistPriceMatrix(free, p, 0n, { ...proof, priceOverride: 0n }),
    { overridden: true, effectiveMinimum: 0n, effectiveMaximum: 0n });
  assert.throws(() => price.nativeAllowlistPriceMatrix(free, p, 0n, proof));
  assert.throws(() => price.nativeAllowlistPriceMatrix(free, policy, 0n, plain));
  assert.throws(() => price.nativeAllowlistPriceMatrix(config, policy, 100n, { ...plain, priceOverride: 1n }));
});

test("purchase retains the original EIP712 domain and encodes positional proofs in the new external CALL", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-allowlist-price-abi.json", import.meta.url)));
  const abi = new Interface(fixture.abi), auth = authorization(), input = purchaseInput();
  const prepared = price.prepareNativeAllowlistPricePurchase(chainId, adapter, config, policy, auth, input);
  const fields = [
    ["saleId", "bytes32"], ["saleConfigHash", "bytes32"], ["payer", "address"], ["executor", "address"],
    ["recipient", "address"], ["artist", "address"], ["tokenDataHash", "bytes32"], ["mintCommitment", "bytes32"],
    ["executionNonce", "uint256"], ["nonce", "bytes32"], ["deadline", "uint64"], ["expectedPrimaryPolicyHash", "bytes32"], ["unitPrice", "uint256"],
  ].map(([name, type]) => ({ name, type }));
  const domain = { name: "6529StreamNativePricePrograms", version: "1", chainId, verifyingContract: adapter };
  assert.equal(prepared.payload.digest, TypedDataEncoder.hash(domain, { NativePriceProgramAuthorization: fields }, auth));
  assert.deepEqual(prepared.payload.domain, domain);
  const resolver = coder.encode([`${proofType}[][]`], [[[plain], [proof]]]);
  const execution = { authorization: auth, chosenUnitPrice: 150n, tokenData: input.tokenData,
    platformSignature: input.platformSignature, artistSignature: input.artistSignature };
  assert.equal(prepared.resolverData, resolver);
  assert.equal(prepared.call.data, abi.encodeFunctionData("executeAllowlistPriceProgram", [execution, resolver]));
  assert.equal(prepared.call.value, 157n);
  assert.equal(prepared.caller, payer);
  assert.equal(prepared.payload.message.unitPrice, 100n);
  assert.equal(prepared.chargedAmount, 150n);
});

test("proof and price changes alter payable execution without creating a new signature field", () => {
  const auth = authorization();
  const a = price.prepareNativeAllowlistPricePurchase(chainId, adapter, config, policy, auth, purchaseInput());
  const b = price.prepareNativeAllowlistPricePurchase(chainId, adapter, config, policy, auth,
    purchaseInput({ ...proof, priceOverride: 0n, proof: [id("different sibling")] }));
  assert.equal(a.payload.digest, b.payload.digest);
  assert.notEqual(a.resolverData, b.resolverData);
  assert.notEqual(a.call.data, b.call.data);
  assert.equal(b.call.value, 7n);
  const relabeled = purchaseInput();
  relabeled.proofGroups[0].counterId = id("unchecked label");
  assert.equal(price.prepareNativeAllowlistPricePurchase(chainId, adapter, config, policy, auth, relabeled).call.data, a.call.data);
  assert.throws(() => price.prepareNativeAllowlistPricePurchase(chainId, adapter, config, policy, { ...auth, executor: address(9) }, purchaseInput()));
});

test("prepared price packets detach nested proofs and reject unselected price overrides", () => {
  const input = purchaseInput({ ...proof, proof: [...proof.proof] }), auth = authorization(), mutableConfig = { ...config };
  const prepared = price.prepareNativeAllowlistPricePurchase(chainId, adapter, mutableConfig, policy, auth, input);
  input.proofGroups[1].proof.proof[0] = id("mutated");
  input.proofGroups[1].proof.priceOverride = 1n;
  mutableConfig.minUnitPrice = 1n;
  auth.unitPrice = 1n;
  assert.equal(prepared.input.proofGroups[1].proof.proof[0], proof.proof[0]);
  assert.equal(prepared.input.proofGroups[1].proof.priceOverride, 150n);
  assert.equal(prepared.config.minUnitPrice, 100n);
  assert.equal(prepared.authorization.unitPrice, 100n);
  const extra = purchaseInput();
  extra.proofGroups[0].proof = { ...plain, hasPriceOverride: true };
  assert.throws(() => price.prepareNativeAllowlistPricePurchase(chainId, adapter, config, policy, authorization(), extra), /Only the selected/);
});
