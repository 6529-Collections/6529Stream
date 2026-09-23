import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, TypedDataEncoder, ZeroAddress, id, keccak256 } from "ethers";
import * as dutch from "../dist/current-native-allowlist-dutch.js";
import * as clearing from "../dist/current-native-allowlist-clearing.js";

// Literal source layouts at 2dc3ea7e. These oracles establish caller encoding,
// not live proof eligibility, authorization or contract execution acceptance.
const coder = AbiCoder.defaultAbiCoder();
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chainId = 31337n, adapter = A(1), payer = A(2), owner = A(3);
const scheduleType = "tuple(uint96 startPrice,uint96 restingPrice,uint64 startTime,uint64 endTime,uint8 decayKind,uint32 stepSeconds,uint96 stepAmount)";
const dutchConfigType = `tuple(uint256 collectionId,bytes32 phaseId,${scheduleType} schedule,uint64 maxSaleQuantity,uint64 closesAt,bool declaredFree,bytes32 mintPolicyHash)`;
const clearingConfigType = `tuple(uint256 collectionId,bytes32 phaseId,${scheduleType} schedule,uint64 maxSaleQuantity,uint64 closesAt,uint64 finalizationWindowSeconds,uint64 absoluteEscapeDeadline,uint8 primaryPolicyMode,bytes32 mintPolicyHash)`;
const proofType = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)";
const schedule = { startPrice: 101n, restingPrice: 11n, startTime: 100n, endTime: 160n,
  decayKind: 0n, stepSeconds: 0n, stepAmount: 0n };
const shared = { collectionId: 9007199254740997n, phaseId: id("moving phase"), schedule,
  maxSaleQuantity: (1n << 64n) - 1n, closesAt: 200n, mintPolicyHash: id("mint policy") };
const dutchConfig = { ...shared, declaredFree: true };
const clearingConfig = { ...shared, finalizationWindowSeconds: 50n, absoluteEscapeDeadline: 300n, primaryPolicyMode: 1n };
const counter = id("selected counter"), baseline = id("baseline policy"), assignment = id("assignment");
const saleNonce = (1n << 255n) + 123n;
const plainProof = { maxCount: 1n, hasPriceOverride: false, priceOverride: 0n, proof: [] };
const pricedProof = { maxCount: (1n << 64n) - 1n, hasPriceOverride: true, priceOverride: 40n, proof: [id("sibling")] };

function saleId(kind, config) {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), chainId, adapter, kind, config.collectionId, config.phaseId, saleNonce]));
}
function scheduleHash(selectedSaleId, s = schedule) {
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", "bytes32", "uint96", "uint96", "uint64", "uint64", "uint8", "uint32", "uint96"],
    [id("6529STREAM_DUTCH_SCHEDULE_V1"), chainId, adapter, selectedSaleId,
      s.startPrice, s.restingPrice, s.startTime, s.endTime, s.decayKind, s.stepSeconds, s.stepAmount],
  ));
}
function windowHash(c = clearingConfig) {
  return keccak256(coder.encode(["bytes32", "uint64", "uint64", "uint64", "bytes32", "bytes32"],
    [id("6529STREAM_CLEARING_WINDOW_POLICY_V1"), c.closesAt, c.finalizationWindowSeconds, c.absoluteEscapeDeadline,
      id("OBSERVED_GLOBAL_OR_LOCAL_PAUSE_UNION"), id("ABSOLUTE_ESCAPE_PAUSED_EQUALITY_UNPAUSED_FINALIZE_EQUALITY")]));
}
function originalDutchHash(selectedSaleId, c = dutchConfig) {
  return keccak256(coder.encode(["bytes32", "bytes32", dutchConfigType, "bytes32", "bytes32", "bytes32", "uint8", "address"],
    [id("6529STREAM_NATIVE_DUTCH_CONFIG_V1"), selectedSaleId, c, scheduleHash(selectedSaleId, c.schedule), baseline, assignment, 0n, ZeroAddress]));
}
function originalClearingHash(selectedSaleId, c = clearingConfig) {
  return keccak256(coder.encode(["bytes32", "bytes32", clearingConfigType, "bytes32", "bytes32", "bytes32", "address"],
    [id("6529STREAM_NATIVE_CLEARING_CONFIG_V1"), selectedSaleId, c, scheduleHash(selectedSaleId, c.schedule), windowHash(c), baseline, ZeroAddress]));
}
function wrappedHash(domain, original) {
  return keccak256(coder.encode(["bytes32", "bytes32", "bytes32"], [id(domain), original, counter]));
}
function originalDutchAuthorization(selectedSaleId, configHash) {
  return { saleId: selectedSaleId, saleConfigHash: configHash, payer, executor: payer, recipient: A(4), artist: A(5),
    tokenDataHash: keccak256("0x00123400"), mintCommitment: id("commitment"), executionNonce: saleNonce,
    nonce: id("authorization nonce"), deadline: (1n << 64n) - 1n, expectedPrimaryPolicyHash: baseline, unitPrice: 90n };
}
const dutchFields = [
  ["saleId", "bytes32"], ["saleConfigHash", "bytes32"], ["payer", "address"], ["executor", "address"],
  ["recipient", "address"], ["artist", "address"], ["tokenDataHash", "bytes32"], ["mintCommitment", "bytes32"],
  ["executionNonce", "uint256"], ["nonce", "bytes32"], ["deadline", "uint64"], ["expectedPrimaryPolicyHash", "bytes32"], ["unitPrice", "uint256"],
].map(([name, type]) => ({ name, type }));
const clearingFields = [
  ...dutchFields.slice(0, 8), { name: "purchaseNonce", type: "uint256" }, ...dutchFields.slice(8),
  { name: "hasPriceOverride", type: "bool" }, { name: "priceOverride", type: "uint256" },
  { name: "windowPolicyHash", type: "bytes32" }, { name: "maximumNominalFinalizeBy", type: "uint64" },
  { name: "absoluteEscapeDeadline", type: "uint64" },
];

test("moving-price ABI fixture retains its exact committed capture and additive ingress", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-moving-price-abi.json", import.meta.url)));
  assert.equal(fixture.sourceCommit, "2dc3ea7ee35d4e5d698a2245bed54fcb03665819");
  assert.equal(fixture.sourceTree, "f5cb1a0abd375bbaa087df409775150a884d3767");
  assert.equal(fixture.sourceCount, 290);
  assert.equal(fixture.inputSha256, "996210da666b0f63930cf10f20ac61c4397bc2451b8931e1690c6432d4811ae6");
  assert.equal(fixture.outputSha256, "ad0f34dc0c3ee118d6d5fc117263902d5294f9933b90aef46508ab40ba65cf06");
  assert.equal(Object.keys(fixture.sources).length, 17);
  for (const key of ["dutch", "clearing"]) {
    const iface = new Interface(fixture.abis[key]);
    const ingress = iface.getFunction("purchaseWithAllowlist");
    assert.equal(ingress.stateMutability, "payable");
    assert.equal(ingress.inputs[1].type, "bytes");
  }
});

test("Dutch registration binds schedule and both explicit economic facts before the allowlist wrapper", async () => {
  const selectedSaleId = saleId(3n, dutchConfig);
  const expectedSchedule = scheduleHash(selectedSaleId);
  const original = originalDutchHash(selectedSaleId);
  const wrapped = wrappedHash("6529STREAM_NATIVE_ALLOWLIST_DUTCH_CONFIG_V1", original);
  const facts = { expectedPrimaryPolicyHash: baseline, primaryAssignmentHash: assignment };
  assert.equal(dutch.nativeAllowlistDutchSaleId(chainId, adapter, shared.collectionId, shared.phaseId, saleNonce), selectedSaleId);
  assert.equal(dutch.nativeDutchScheduleHash(chainId, adapter, selectedSaleId, schedule), expectedSchedule);
  assert.equal(dutch.nativeDutchOriginalConfigHash(selectedSaleId, dutchConfig, expectedSchedule, facts), original);
  assert.equal(dutch.nativeAllowlistDutchConfigHash(original, counter), wrapped);
  const registration = dutch.prepareNativeAllowlistDutchRegistration(chainId, adapter, owner, saleNonce, dutchConfig, counter, facts);
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-moving-price-abi.json", import.meta.url)));
  assert.equal(registration.call.data, new Interface(fixture.abis.dutch).encodeFunctionData("registerAllowlistDutchSale", [dutchConfig, counter]));
  assert.equal(registration.configHash, wrapped);
  assert.equal(registration.call.value, 0n);
  assert.equal(registration.expectedHashFactsRequirePostRegistrationReadback, true);
  assert.notEqual(dutch.nativeDutchOriginalConfigHash(selectedSaleId, dutchConfig, expectedSchedule,
    { ...facts, primaryAssignmentHash: id("changed assignment") }), original);
});

test("clearing hashes bind original window rules, full-width IDs and the independent baseline", () => {
  const selectedSaleId = saleId(4n, clearingConfig);
  assert.equal(clearing.nativeClearingSaleId(chainId, adapter, shared.collectionId, shared.phaseId, saleNonce), selectedSaleId);
  assert.equal(clearing.nativeClearingScheduleHash(chainId, adapter, selectedSaleId, schedule), scheduleHash(selectedSaleId));
  assert.equal(clearing.nativeClearingWindowPolicyHash(clearingConfig), windowHash());
  const original = originalClearingHash(selectedSaleId);
  assert.equal(clearing.nativeClearingOriginalConfigHash(chainId, adapter, selectedSaleId, clearingConfig, baseline), original);
  assert.equal(clearing.nativeAllowlistClearingConfigHash(original, counter), wrappedHash("6529STREAM_NATIVE_ALLOWLIST_CLEARING_CONFIG_V1", original));
  const purchaseNonce = (1n << 254n) + 7n;
  const purchaseId = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "uint256"],
    [id("6529STREAM_SALE_PURCHASE_V1"), chainId, adapter, selectedSaleId, payer, purchaseNonce]));
  assert.equal(clearing.nativeClearingPurchaseId(chainId, adapter, selectedSaleId, payer, purchaseNonce), purchaseId);
  assert.notEqual(clearing.nativeClearingWindowPolicyHash({ ...clearingConfig, absoluteEscapeDeadline: 301n }), windowHash());
  assert.notEqual(clearing.nativeClearingOriginalConfigHash(chainId, adapter, selectedSaleId, clearingConfig, id("different baseline")), original);
});

test("both schedule producers preserve upward linear charges and partial final step boundaries", () => {
  const vectors = [[99n, 101n], [100n, 101n], [101n, 100n], [129n, 58n], [159n, 13n], [160n, 11n], [170n, 11n]];
  for (const [timestamp, expected] of vectors) {
    assert.equal(dutch.nativeDutchSchedulePrice(schedule, timestamp), expected);
    assert.equal(clearing.nativeClearingSchedulePrice(schedule, timestamp), expected);
  }
  const stepped = { ...schedule, decayKind: 1n, stepSeconds: 17n, stepAmount: 23n };
  for (const [timestamp, expected] of [[116n, 101n], [117n, 78n], [151n, 32n], [159n, 32n], [160n, 11n]]) {
    assert.equal(dutch.nativeDutchSchedulePrice(stepped, timestamp), expected);
    assert.equal(clearing.nativeClearingSchedulePrice(stepped, timestamp), expected);
  }
  for (const invalid of [{ ...stepped, stepSeconds: 1n << 32n }, { ...schedule, startPrice: 1n << 96n }]) {
    assert.throws(() => dutch.nativeDutchSchedulePrice(invalid, 100n));
    assert.throws(() => clearing.nativeClearingSchedulePrice(invalid, 100n));
  }
});

test("Dutch leaf ceilings never raise schedule price and explicit free permission applies to positive schedules", () => {
  for (const [proof, expected] of [[plainProof, 80n], [pricedProof, 40n], [{ ...pricedProof, priceOverride: (1n << 255n) + 1n }, 80n]]) {
    assert.deepEqual(dutch.nativeAllowlistDutchCharge(80n, false, proof),
      { overridden: proof.hasPriceOverride, schedulePrice: 80n, chargedAmount: expected });
  }
  assert.equal(dutch.nativeAllowlistDutchCharge(80n, true, { ...pricedProof, priceOverride: 0n }).chargedAmount, 0n);
  assert.throws(() => dutch.nativeAllowlistDutchCharge(80n, false, { ...pricedProof, priceOverride: 0n }));
  assert.throws(() => dutch.nativeAllowlistDutchCharge(80n, true, { ...plainProof, priceOverride: 1n }));
});

test("Dutch and clearing keep original separate EIP712 domains and raw signed ceilings", () => {
  const dutchSaleId = saleId(3n, dutchConfig);
  const dutchHash = wrappedHash("6529STREAM_NATIVE_ALLOWLIST_DUTCH_CONFIG_V1", originalDutchHash(dutchSaleId));
  const dutchAuth = originalDutchAuthorization(dutchSaleId, dutchHash);
  const dutchPayload = dutch.nativeDutchAuthorizationPayload(chainId, adapter, dutchAuth);
  assert.equal(dutchPayload.digest, TypedDataEncoder.hash(
    { name: "6529StreamNativeDutchSale", version: "1", chainId, verifyingContract: adapter },
    { DutchAuthorization: dutchFields }, dutchAuth));
  const clearingSaleId = saleId(4n, clearingConfig);
  const clearingHash = wrappedHash("6529STREAM_NATIVE_ALLOWLIST_CLEARING_CONFIG_V1", originalClearingHash(clearingSaleId));
  const auth = { ...originalDutchAuthorization(clearingSaleId, clearingHash), purchaseNonce: saleNonce + 1n,
    hasPriceOverride: true, priceOverride: (1n << 255n) + 17n, windowPolicyHash: windowHash(),
    maximumNominalFinalizeBy: 250n, absoluteEscapeDeadline: 300n };
  const clearingPayload = clearing.nativeClearingAuthorizationTypedData(chainId, adapter, auth);
  assert.equal(clearingPayload.digest, TypedDataEncoder.hash(
    { name: "6529StreamNativeClearingSale", version: "1", chainId, verifyingContract: adapter },
    { ClearingAuthorization: clearingFields }, auth));
  assert.equal(clearingPayload.message.priceOverride, auth.priceOverride);
  const noOverride = { ...auth, hasPriceOverride: false, priceOverride: 0n };
  assert.notEqual(clearing.nativeClearingAuthorizationTypedData(chainId, adapter, noOverride).digest, clearingPayload.digest);
  assert.throws(() => clearing.nativeClearingAuthorizationTypedData(chainId, adapter, { ...auth, hasPriceOverride: "true" }));
});

test("Dutch purchase CALL includes exact resolver bytes while retaining signed maximum and explicit funding", async () => {
  const selectedSaleId = saleId(3n, dutchConfig);
  const configHash = wrappedHash("6529STREAM_NATIVE_ALLOWLIST_DUTCH_CONFIG_V1", originalDutchHash(selectedSaleId));
  const auth = originalDutchAuthorization(selectedSaleId, configHash);
  const groups = [{ counterId: id("other counter"), proof: plainProof }, { counterId: counter, proof: pricedProof }];
  const input = { tokenData: "0x00123400", platformSignature: "0xaaaa", artistSignature: "0xbb",
    saleFundingMaximum: 80n, revealFeeAllowance: 7n, proofGroups: groups };
  const facts = { expectedPrimaryPolicyHash: baseline, primaryAssignmentHash: assignment };
  const prepared = dutch.prepareNativeAllowlistDutchPurchase(chainId, adapter, dutchConfig, counter, facts, auth, input);
  const resolver = coder.encode([`${proofType}[][]`], [[[plainProof], [pricedProof]]]);
  const data = { authorization: auth, tokenData: input.tokenData, platformSignature: input.platformSignature, artistSignature: input.artistSignature };
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-moving-price-abi.json", import.meta.url)));
  assert.equal(prepared.call.data, new Interface(fixture.abis.dutch).encodeFunctionData("purchaseWithAllowlist", [data, resolver]));
  assert.equal(prepared.resolverData, resolver);
  assert.equal(prepared.call.value, 87n);
  assert.equal(prepared.payload.message.unitPrice, 90n);
  assert.equal(prepared.caller, payer);
  groups[0].counterId = id("caller metadata only");
  assert.equal(dutch.prepareNativeAllowlistDutchPurchase(chainId, adapter, dutchConfig, counter, facts, auth, input).call.data, prepared.call.data);
});

test("clearing proof producer requires exact signed flag and full-width price without narrowing", () => {
  const selectedSaleId = saleId(4n, clearingConfig);
  const configHash = wrappedHash("6529STREAM_NATIVE_ALLOWLIST_CLEARING_CONFIG_V1", originalClearingHash(selectedSaleId));
  const auth = { ...originalDutchAuthorization(selectedSaleId, configHash), purchaseNonce: 1n, hasPriceOverride: true,
    priceOverride: (1n << 255n) + 1n, windowPolicyHash: windowHash(), maximumNominalFinalizeBy: 250n, absoluteEscapeDeadline: 300n };
  const proof = { ...pricedProof, priceOverride: auth.priceOverride };
  const groups = [{ counterId: id("other counter"), proof: plainProof }, { counterId: counter, proof }];
  assert.equal(clearing.nativeAllowlistClearingResolverData(groups, counter, auth), coder.encode([`${proofType}[][]`], [[[plainProof], [proof]]]));
  assert.throws(() => clearing.nativeAllowlistClearingResolverData(groups, counter, { ...auth, priceOverride: 101n }));
  assert.throws(() => clearing.nativeAllowlistClearingResolverData(groups, counter, { ...auth, hasPriceOverride: false, priceOverride: 0n }));
  assert.throws(() => clearing.nativeAllowlistClearingResolverData([{ counterId: counter, proof: plainProof }], counter, auth));
});

test("clearing financial and refund CALLs preserve original selectors and zero value", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-native-moving-price-abi.json", import.meta.url)));
  const abi = new Interface(fixture.abis.clearing);
  const client = new clearing.CurrentNativeAllowlistClearingClient(chainId, adapter);
  const selectedSaleId = saleId(4n, clearingConfig), purchaseId = id("original purchase");
  const calls = [
    [client.fixClearingPrice(selectedSaleId, owner), "fixClearingPrice", [selectedSaleId]],
    [client.settlePurchaseSupplement(purchaseId, owner), "settlePurchaseSupplement", [purchaseId]],
    [client.synchronizeRebate(selectedSaleId, payer, owner), "synchronizeRebate", [selectedSaleId, payer]],
    [client.claimRefund(selectedSaleId, payer, A(8)), "claimRefund", [selectedSaleId, A(8)]],
  ];
  for (const [prepared, method, args] of calls) {
    assert.equal(prepared.call.data, abi.encodeFunctionData(method, args));
    assert.equal(prepared.call.value, 0n);
    assert.equal(prepared.call.to, adapter);
  }
  assert.equal(calls[3][0].caller, payer);
});
