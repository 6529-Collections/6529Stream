import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Interface, id, keccak256, toUtf8Bytes } from "ethers";
import {
  NATIVE_ALLOWLIST_PRICE_KIND,
  inspectNativeAllowlistPricePurchase,
  inspectNativeAllowlistPriceRegistration,
  nativeAllowlistPriceMatrix,
  nativeAllowlistPriceProgramConfigHash,
  nativeAllowlistPriceSaleId,
  nativePriceProgramOriginalConfigHash,
  prepareNativeAllowlistPricePurchase,
  prepareNativeAllowlistPriceRegistration,
  simulateNativeAllowlistPricePurchase,
  simulateNativeAllowlistPriceRegistration,
} from "../dist/current-native-allowlist-price.js";

const chainId = 31337n, A = n => `0x${n.toString(16).padStart(40, "0")}`, adapter = A(1), owner = A(2), payer = A(3), recipient = A(4), artist = A(5), core = A(6), manager = A(7);
const h = value => keccak256(toUtf8Bytes(value)), zero32 = `0x${"00".repeat(32)}`;
const baseConfig = Object.freeze({ collectionId: 9n, phaseId: h("phase"), kind: NATIVE_ALLOWLIST_PRICE_KIND.FIXED,
  minUnitPrice: 100n, maxUnitPrice: 100n, maxSaleQuantity: 10n, startsAt: 1n, endsAt: 0n, closeRule: 2n,
  mintPolicyHash: h("mint-policy"), primaryAssignmentHash: h("assignment") });
const policy = Object.freeze({ counterId: h("price-counter"), allowFree: true });
const proof = Object.freeze({ maxCount: 2n, hasPriceOverride: true, priceOverride: 150n, proof: Object.freeze([h("sibling")]) });
const otherProof = Object.freeze({ maxCount: 2n, hasPriceOverride: false, priceOverride: 0n, proof: Object.freeze([]) });

async function fixtureInterface() {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-allowlist-price-abi.json", import.meta.url)));
  return { fixture, iface: new Interface(fixture.abi) };
}
function authorization(config = baseConfig, selectedPolicy = policy, saleNonce = 4n) {
  const saleId = nativeAllowlistPriceSaleId(chainId, adapter, config, saleNonce), original = nativePriceProgramOriginalConfigHash(saleId, config);
  return Object.freeze({ saleId, saleConfigHash: nativeAllowlistPriceProgramConfigHash(original, selectedPolicy), payer, executor: payer, recipient, artist,
    tokenDataHash: keccak256("0x1234"), mintCommitment: h("mint"), executionNonce: 1n, nonce: h("nonce"), deadline: 999999n,
    expectedPrimaryPolicyHash: h("primary"), unitPrice: config.minUnitPrice });
}
function preparedPurchase() {
  return prepareNativeAllowlistPricePurchase(chainId, adapter, baseConfig, policy, authorization(), { chosenUnitPrice: 150n, tokenData: "0x1234",
    platformSignature: "0xaa", artistSignature: "0xbb", revealFeeAllowance: 9n,
    proofGroups: [{ counterId: h("other-counter"), proof: otherProof }, { counterId: policy.counterId, proof }] });
}
function result(chargedAmount = 150n) {
  return [1n, h("execution"), h("root"), h("operation"), 77n, chargedAmount, h("settlement"), false];
}
function provider(iface, controls = {}) {
  const prepared = preparedPurchase(), auth = prepared.authorization;
  return { getNetwork: async () => ({ chainId }), call: async tx => {
    assert.equal(tx.blockTag, 123); const parsed = iface.parseTransaction({ data: tx.data });
    switch (parsed.name) {
      case "owner": return iface.encodeFunctionResult(parsed.fragment, [controls.wrongOwner ? A(99) : owner]);
      case "nextSaleNonce": return iface.encodeFunctionResult(parsed.fragment, [controls.wrongNonce ? 5n : 4n]);
      case "core": return iface.encodeFunctionResult(parsed.fragment, [core]);
      case "mintManager": return iface.encodeFunctionResult(parsed.fragment, [manager]);
      case "priceProgramIdFor": return iface.encodeFunctionResult(parsed.fragment, [auth.saleId]);
      case "priceProgramRecord": return iface.encodeFunctionResult(parsed.fragment, [[baseConfig, 4n, auth.saleConfigHash, [10n, 3n], 1n, Boolean(controls.closed)]]);
      case "allowlistPricePolicy": return iface.encodeFunctionResult(parsed.fragment, [[controls.wrongPolicy ? h("wrong") : policy.counterId, true]]);
      case "priceProgramAuthorizationDigest": return iface.encodeFunctionResult(parsed.fragment, [controls.wrongDigest ? h("wrong-digest") : prepared.payload.digest]);
      case "saleRevealQuote": return iface.encodeFunctionResult(parsed.fragment, [[A(8), h("coordinator-code"), [true, 0n, h("role"), 40n, controls.fee ?? 7n]]]);
      case "previewAllowlistPriceProgram": {
        assert.equal(tx.from.toLowerCase(), payer.toLowerCase());
        if (controls.previewReject) throw new Error("execution reverted: InvalidSaleAllowlistProof");
        return iface.encodeFunctionResult(parsed.fragment, [result(controls.wrongCharge ? 151n : 150n)]);
      }
      case "executeAllowlistPriceProgram": {
        assert.equal(tx.from.toLowerCase(), payer.toLowerCase()); assert.equal(tx.value, 159n);
        return iface.encodeFunctionResult(parsed.fragment, [result()]);
      }
      case "registerAllowlistPriceProgram": return iface.encodeFunctionResult(parsed.fragment, [auth.saleId]);
      default: throw new Error(`unexpected ${parsed.name}`);
    }
  } };
}

test("compiler fixture is pinned to the accepted f174 source and exact callable shapes", async () => {
  const { fixture, iface } = await fixtureInterface();
  assert.equal(fixture.sourceCommit, "f1745f33be3e601aca75a89ffe428f534a352615"); assert.equal(fixture.sourceTree, "b4d68b320f8a7dfde2b5f4caba4218b8713b27b3");
  assert.equal(fixture.sourceCount, 159); assert.equal(fixture.inputSha256, "c59a2da7dcecfa40e5b3e9ac4223bcc4ed111c5bfd2edc46c9c49b093289b7e6");
  assert.equal(fixture.outputSha256, "c2e32bb4330404d4a923d810b4a32a801eeaf9ff2f9b478cbefbb0201b51b677");
  assert.equal(fixture.methods.length, 12); for (const name of fixture.methods) assert.ok(iface.getFunction(name).selector);
});

test("registration binds exact sale/config hashes and requires the pinned live owner nonce", async () => {
  const { iface } = await fixtureInterface(), prepared = prepareNativeAllowlistPriceRegistration(chainId, adapter, owner, 4n, baseConfig, policy), p = provider(iface);
  assert.equal(prepared.saleId, authorization().saleId); assert.equal(prepared.configHash, authorization().saleConfigHash); assert.equal(prepared.expectedNonceMustBeLiveChecked, true);
  const parsed = iface.parseTransaction({ data: prepared.call.data }); assert.equal(parsed.name, "registerAllowlistPriceProgram"); assert.equal(prepared.call.value, 0n);
  assert.equal((await inspectNativeAllowlistPriceRegistration(p, prepared, { blockTag: 123 })).mintManager.toLowerCase(), manager.toLowerCase());
  assert.equal(await simulateNativeAllowlistPriceRegistration(p, prepared, { blockTag: 123 }), prepared.saleId);
  await assert.rejects(inspectNativeAllowlistPriceRegistration(provider(iface, { wrongNonce: true }), prepared, { blockTag: 123 }), /Live sale nonce/);
  await assert.rejects(inspectNativeAllowlistPriceRegistration(provider(iface, { wrongOwner: true }), prepared, { blockTag: 123 }), /current adapter owner/);
});

test("fixed override replaces the original fixed band, including above its public price", () => {
  assert.deepEqual(nativeAllowlistPriceMatrix(baseConfig, policy, 100n, proof), { overridden: true, effectiveMinimum: 150n, effectiveMaximum: 150n });
  assert.deepEqual(nativeAllowlistPriceMatrix(baseConfig, policy, 100n, otherProof), { overridden: false, effectiveMinimum: 100n, effectiveMaximum: 100n });
  assert.throws(() => nativeAllowlistPriceMatrix(baseConfig, { ...policy, allowFree: false }, 100n, { ...proof, priceOverride: 0n }), /not declared/);
  assert.throws(() => nativeAllowlistPriceMatrix(baseConfig, policy, 99n, proof), /Signed unit price/);
});

test("zero and pay-what-you-want matrices preserve their distinct price rules", () => {
  const zero = { ...baseConfig, kind: 12n, minUnitPrice: 0n, maxUnitPrice: 0n, primaryAssignmentHash: zero32 };
  assert.deepEqual(nativeAllowlistPriceMatrix(zero, { ...policy, allowFree: false }, 0n, { ...proof, priceOverride: 0n }), { overridden: true, effectiveMinimum: 0n, effectiveMaximum: 0n });
  assert.throws(() => nativeAllowlistPriceMatrix(zero, { ...policy, allowFree: false }, 0n, proof), /only a zero/);
  const pwyw = { ...baseConfig, kind: 13n, minUnitPrice: 20n, maxUnitPrice: 200n };
  assert.deepEqual(nativeAllowlistPriceMatrix(pwyw, { ...policy, allowFree: false }, 80n, { ...proof, priceOverride: 0n }), { overridden: true, effectiveMinimum: 20n, effectiveMaximum: 200n });
  assert.deepEqual(nativeAllowlistPriceMatrix(pwyw, { ...policy, allowFree: false }, 80n, otherProof), { overridden: false, effectiveMinimum: 80n, effectiveMaximum: 200n });
});

test("purchase prepares exact proof entrypoint, value and original native signing domain", async () => {
  const { iface } = await fixtureInterface(), prepared = preparedPurchase(), parsed = iface.parseTransaction({ data: prepared.call.data });
  assert.equal(parsed.name, "executeAllowlistPriceProgram"); assert.equal(prepared.call.value, 159n); assert.equal(prepared.caller.toLowerCase(), payer.toLowerCase());
  assert.equal(prepared.payload.domain.name, "6529StreamNativePricePrograms"); assert.equal(prepared.payload.primaryType, "NativePriceProgramAuthorization");
  assert.equal(parsed.args[0].authorization.unitPrice, 100n); assert.equal(parsed.args[0].chosenUnitPrice, 150n); assert.equal(parsed.args[1], prepared.resolverData);
});

test("pinned inspection validates record, digest, quote and canonical live preview before exact simulation", async () => {
  const { iface } = await fixtureInterface(), prepared = preparedPurchase(), p = provider(iface);
  const inspected = await inspectNativeAllowlistPricePurchase(p, prepared, { blockTag: 123 });
  assert.equal(inspected.preview.chargedAmount, 150n); assert.equal(inspected.revealFeePerTokenWei, 7n);
  assert.equal((await simulateNativeAllowlistPricePurchase(p, prepared, { blockTag: 123 })).tokenId, 77n);
  await assert.rejects(inspectNativeAllowlistPricePurchase(provider(iface, { wrongPolicy: true }), prepared, { blockTag: 123 }), /Stored allowlist price policy/);
  await assert.rejects(inspectNativeAllowlistPricePurchase(provider(iface, { wrongDigest: true }), prepared, { blockTag: 123 }), /digest getter/);
  await assert.rejects(inspectNativeAllowlistPricePurchase(provider(iface, { fee: 10n }), prepared, { blockTag: 123 }), /fee allowance/);
  await assert.rejects(inspectNativeAllowlistPricePurchase(provider(iface, { previewReject: true }), prepared, { blockTag: 123 }), /InvalidSaleAllowlistProof/);
  await assert.rejects(inspectNativeAllowlistPricePurchase(provider(iface, { wrongCharge: true }), prepared, { blockTag: 123 }), /charged amount/);
  await assert.rejects(inspectNativeAllowlistPricePurchase(p, { ...prepared, call: { ...prepared.call, value: 158n } }, { blockTag: 123 }), /canonical reconstruction/);
  await assert.rejects(inspectNativeAllowlistPricePurchase(p, { ...prepared, payload: { ...prepared.payload, domain: { ...prepared.payload.domain, name: "forged" } } }, { blockTag: 123 }), /canonical reconstruction/);
});

test("builders reject coercion, ambiguous prices, payer substitution and mutable asynchronous inputs", async () => {
  assert.throws(() => prepareNativeAllowlistPriceRegistration(chainId, adapter, owner, 4n, { ...baseConfig, kind: 256n }, policy), /uint8/);
  assert.throws(() => prepareNativeAllowlistPriceRegistration(chainId, adapter, owner, 4n, baseConfig, { ...policy, allowFree: "false" }), /boolean/);
  assert.throws(() => prepareNativeAllowlistPricePurchase(chainId, adapter, baseConfig, policy, { ...authorization(), executor: A(99) }, preparedPurchase().input), /payer, executor/);
  assert.throws(() => prepareNativeAllowlistPricePurchase(chainId, adapter, baseConfig, policy, authorization(), { ...preparedPurchase().input,
    proofGroups: [{ counterId: policy.counterId, proof }, { counterId: h("other"), proof: { ...proof, priceOverride: 1n } }] }), /Only the selected/);
  const { iface } = await fixtureInterface(), prepared = preparedPurchase(); let release;
  const gate = new Promise(resolve => { release = resolve; }), base = provider(iface), options = { blockTag: 123 };
  const delayed = { ...base, getNetwork: async () => { await gate; return { chainId }; } };
  const mutable = { ...prepared, input: { ...prepared.input, proofGroups: prepared.input.proofGroups.map(group => ({ ...group, proof: { ...group.proof, proof: [...group.proof.proof] } })) } };
  const pending = inspectNativeAllowlistPricePurchase(delayed, mutable, options); options.blockTag = 124; mutable.input.proofGroups[0].proof.proof.push(h("mutate")); release();
  assert.equal((await pending).preview.chargedAmount, 150n);
});
