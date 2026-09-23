import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Interface, TypedDataEncoder, id, keccak256, toUtf8Bytes } from "ethers";
import {
  inspectPlatformCustodyRegistration, inspectPlatformRightsRegistration,
  inspectPlatformTokenCustodyActivation, platformCustodyOriginHash,
  platformRightsConfigurationHash, platformTokenCustodyConfigurationHash,
  preparePlatformCustodyRegistration, preparePlatformRightsRegistration,
  preparePlatformTokenCustodyActivation, preparePlatformTokenCustodyBid,
  prepareSignedPlatformTokenCustodyBid, simulatePreparedPlatformWrite,
} from "../dist/current-platform.js";

const chainId = 31337n;
const house = "0x1000000000000000000000000000000000000001";
const poster = "0x2000000000000000000000000000000000000002";
const executor = "0x3000000000000000000000000000000000000003";
const resolver = "0x4000000000000000000000000000000000000004";
const artist = "0x5000000000000000000000000000000000000005";
const h = text => keccak256(toUtf8Bytes(text));
const tokenData = "0x123456";
const zero = `0x${"00".repeat(32)}`;
const clock = { startTime: 1n, endTime: 2n, firstBidDuration: 0n, antiSnipeWindow: 0n, antiSnipeExtension: 0n, maxTotalExtension: 0n, startOnFirstBid: false, hardClose: true };
const deferred = { collectionId: 7n, phaseId: h("phase"), tokenId: 0n, mintAtSettlement: true, artworkCommitment: keccak256(tokenData), contentManifestRoot: zero, mintCommitment: h("mint"), poster, reservePrice: 10n, minIncrementBps: 100n, incrementFloorWaived: false, clock, expectedPrimaryPolicyHash: h("policy"), primaryPolicyMode: 1n, settlementWindow: 86400n, mintPolicyHash: h("mint-policy") };
const custody = { ...deferred, tokenId: 41n, mintAtSettlement: false, artworkCommitment: zero };
const original = { mode: 8n, assignmentHash: h("assignment"), templateId: h("template") };
const declaration = h("declaration"), nonce = h("nonce");
const configHash = platformRightsConfigurationHash(chainId, house, deferred, original, declaration);
const creation = { configHash, declarationHash: declaration, nonce, deadline: 9_999_999_999n };

test("compiled fixture contains every selected function with exact source provenance", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-platform-abi.json", import.meta.url)));
  assert.equal(fixture.provenance.compilerInputSha256, "6b5a36b391f91187447d38e77939ca882df43ccb978924b8d69e7c2a5abb8012");
  assert.equal(fixture.provenance.compilerOutputSha256, "0719df2601b45dbb79e65d41d0b378a7e858677390062ab4307a2441cc97a9eb");
  for (const contract of fixture.contracts) {
    const iface = new Interface(contract.abi);
    assert.deepEqual(contract.abi.filter(x => x.type === "function").map(x => x.name).sort(), [...contract.methods].sort());
    for (const method of contract.methods) assert.ok(iface.getFunction(method).selector.startsWith("0x"));
  }
});

test("families 8/9 require template IDs and 10/11 require zero template IDs", () => {
  assert.throws(() => platformRightsConfigurationHash(chainId, house, deferred, { ...original, mode: 10n }, declaration), /Template ID presence/);
  assert.doesNotThrow(() => platformRightsConfigurationHash(chainId, house, deferred, { ...original, mode: 10n, templateId: zero }, declaration));
  assert.throws(() => platformRightsConfigurationHash(chainId, house, deferred, { ...original, mode: 7n }, declaration), /8 through 11/);
});

test("configuration validation rejects integer overflow, boolean coercion and unknown properties", () => {
  assert.throws(() => platformRightsConfigurationHash(chainId, house, { ...deferred, reservePrice: 1n << 96n }, original, declaration), /uint96/);
  assert.throws(() => platformRightsConfigurationHash(chainId, house, { ...deferred, mintAtSettlement: "true" }, original, declaration), /boolean|family/);
  assert.throws(() => platformRightsConfigurationHash(chainId, house, { ...deferred, surprise: 1n }, original, declaration), /unknown properties/);
});

test("rights registration binds caller, config, source preimage and exact typed domain", () => {
  const prepared = preparePlatformRightsRegistration(chainId, house, deferred, original, tokenData, creation, "0x1234");
  assert.equal(prepared.caller, poster); assert.equal(prepared.call.value, 0n);
  assert.equal(prepared.payload.domain.name, "6529StreamPlatformNativeRightsAuction");
  assert.equal(prepared.payload.primaryType, "PlatformNativeAuctionCreation");
  assert.equal(prepared.payload.digest, TypedDataEncoder.hash(prepared.payload.domain, prepared.payload.types, prepared.payload.message));
  assert.throws(() => preparePlatformRightsRegistration(chainId, house, deferred, original, "0x99", creation, "0x1234"), /artworkCommitment/);
});

test("prepared custody uses executor rather than poster and exact reveal deposit", () => {
  const custodyHash = platformRightsConfigurationHash(chainId, house, custody, original, declaration);
  const auth = { configHash: custodyHash, declarationHash: declaration, tokenDataHash: keccak256(tokenData), expectedSaleNonce: 2n, expectedTokenId: 41n, expectedCollectionSerial: 1n, expectedOperationNonce: 4n, contextHash: h("context"), executor, revealFeeDeposit: 123n, nonce: h("custody-nonce"), deadline: 9_999_999_999n };
  const prepared = preparePlatformCustodyRegistration(chainId, house, custody, original, tokenData, auth, "0xabcd");
  assert.notEqual(executor, poster); assert.equal(prepared.caller, executor); assert.equal(prepared.call.value, 123n);
  assert.throws(() => preparePlatformCustodyRegistration(chainId, house, custody, original, tokenData, { ...auth, revealFeeDeposit: -1n }, "0xabcd"), /uint256/);
});

test("known-token activation is nonpayable, ALLOW_CURRENT and family 12/13 only", () => {
  const auth = { auctionId: h("auction"), baseConfigHash: h("base"), originHash: h("origin"), tokenId: 41n, declarationHash: declaration, rightsMode: 12n, assignmentHash: h("token-assignment"), primaryPolicyHash: h("token-policy"), primaryPolicyMode: 1n, nonce: h("activation-nonce"), deadline: 9_999_999_999n };
  const prepared = preparePlatformTokenCustodyActivation(chainId, house, poster, auth, "0xbeef"); assert.equal(prepared.call.value, 0n); assert.equal(prepared.caller, poster);
  assert.throws(() => preparePlatformTokenCustodyActivation(chainId, house, poster, { ...auth, rightsMode: 11n }, "0xbeef"), /12 or 13/);
  assert.throws(() => preparePlatformTokenCustodyActivation(chainId, house, poster, { ...auth, primaryPolicyMode: 0n }, "0xbeef"), /ALLOW_CURRENT/);
});

test("effective token-custody config rejects a substituted digest", () => {
  const auth = { auctionId: h("auction"), baseConfigHash: h("base"), originHash: h("origin"), tokenId: 41n, declarationHash: declaration, rightsMode: 13n, assignmentHash: h("token-assignment"), primaryPolicyHash: h("token-policy"), primaryPolicyMode: 1n, nonce: h("activation-nonce"), deadline: 9_999_999_999n };
  assert.ok(platformTokenCustodyConfigurationHash(chainId, house, auth).startsWith("0x"));
  assert.throws(() => platformTokenCustodyConfigurationHash(chainId, house, auth, h("wrong")), /differs/);
});

test("custody origin hash rejects boolean coercion and changes on reveal funding", () => {
  const origin = { manager: executor, managerCodeHash: h("manager-code"), operationRoot: h("root"), operationId: h("operation"), authorizationId: h("authorization"), tokenDataHash: keccak256(tokenData), tokenId: 41n, collectionSerial: 1n, operationNonce: 4n, fundingAccount: executor, revealFeeForwarded: 123n, eligible: true };
  assert.notEqual(platformCustodyOriginHash(origin), platformCustodyOriginHash({ ...origin, revealFeeForwarded: 124n }));
  assert.throws(() => platformCustodyOriginHash({ ...origin, eligible: "true" }), /boolean/);
});

test("known-token bids expose exact sale amount and enforce zero reveal fee", () => {
  const auctionId = h("auction"), direct = preparePlatformTokenCustodyBid(house, auctionId, poster, 500n, 0n); assert.equal(direct.value, 500n);
  assert.throws(() => preparePlatformTokenCustodyBid(house, auctionId, poster, 500n, 1n), /zero reveal fee/);
  const signed = { auctionId, configHash: h("effective"), payer: poster, executor, deliverTo: poster, amount: 500n, maxRevealFee: 9n, nonce: h("bid-nonce"), deadline: 999n, finalizeBy: 1000n };
  assert.equal(prepareSignedPlatformTokenCustodyBid(house, signed, "0x1234", 0n).value, 500n);
  assert.throws(() => prepareSignedPlatformTokenCustodyBid(house, signed, "0x1234", 1n), /zero actual reveal fee/);
});

test("write simulation rejects tampered wallet domain, call bytes, caller and nonconcrete blocks", async () => {
  const prepared = preparePlatformRightsRegistration(chainId, house, deferred, original, tokenData, creation, "0x1234");
  const provider = { getNetwork: async () => ({ chainId }), call: async tx => { assert.equal(tx.blockTag, 123); return "0x"; } };
  assert.equal(await simulatePreparedPlatformWrite(provider, prepared, { blockTag: 123 }), "0x");
  await assert.rejects(simulatePreparedPlatformWrite(provider, { ...prepared, payload: { ...prepared.payload, domain: { ...prepared.payload.domain, name: "forged" } } }, { blockTag: 123 }), /wallet-visible payload/);
  await assert.rejects(simulatePreparedPlatformWrite(provider, { ...prepared, caller: executor }, { blockTag: 123 }), /caller/);
  await assert.rejects(simulatePreparedPlatformWrite(provider, { ...prepared, call: { ...prepared.call, data: prepared.digestCall.data } }, { blockTag: 123 }), /differs|decode/);
  await assert.rejects(simulatePreparedPlatformWrite(provider, prepared, { blockTag: "latest" }), /concrete/);
});

test("synthetic pinned reads check encodings but do not claim runtime acceptance", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-platform-abi.json", import.meta.url)));
  const all = fixture.contracts.flatMap(x => x.abi), iface = new Interface(all);
  const prepared = preparePlatformRightsRegistration(chainId, house, deferred, original, tokenData, creation, "0x1234");
  const provider = { getNetwork: async () => ({ chainId }), call: async tx => {
    assert.equal(tx.blockTag, 444); const parsed = iface.parseTransaction({ data: tx.data });
    switch (parsed.name) {
      case "platformRightsCreationDigest": return iface.encodeFunctionResult(parsed.fragment, [prepared.payload.digest]);
      case "platformRightsConfigurationHash": return iface.encodeFunctionResult(parsed.fragment, [configHash]);
      case "revenueResolver": return iface.encodeFunctionResult(parsed.fragment, [resolver]);
      case "artistRegistry": return iface.encodeFunctionResult(parsed.fragment, [artist]);
      case "platformWorksDeclaration": return iface.encodeFunctionResult(parsed.fragment, [true, declaration, 100n]);
      case "platformWorksContest": return iface.encodeFunctionResult(parsed.fragment, [0n, zero]);
      case "platformWorksCorrection": return iface.encodeFunctionResult(parsed.fragment, [0n, zero]);
      case "resolvePrimaryAssignment": return iface.encodeFunctionResult(parsed.fragment, [[true, 1n, 7n, 2n, zero, original.templateId, zero, original.assignmentHash, false]]);
      default: throw Error(`unexpected ${parsed.name}`);
    }
  } };
  const result = await inspectPlatformRightsRegistration(provider, prepared, deferred, original, { resolver, artistRegistry: artist }, { blockTag: 444 });
  assert.equal(result.writeSimulationRequired, true); assert.match(result.unavailable.join(" "), /signature acceptance/); assert.match(result.unavailable.join(" "), /reorg/);
});

test("synthetic inspection rejects a source contract not bound to the house", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-platform-abi.json", import.meta.url))), iface = new Interface(fixture.contracts.flatMap(x => x.abi));
  const prepared = preparePlatformRightsRegistration(chainId, house, deferred, original, tokenData, creation, "0x1234");
  const provider = { getNetwork: async () => ({ chainId }), call: async tx => { const p = iface.parseTransaction({ data: tx.data }); if (p.name === "platformRightsCreationDigest") return iface.encodeFunctionResult(p.fragment, [prepared.payload.digest]); if (p.name === "platformRightsConfigurationHash") return iface.encodeFunctionResult(p.fragment, [configHash]); if (p.name === "revenueResolver") return iface.encodeFunctionResult(p.fragment, [executor]); if (p.name === "artistRegistry") return iface.encodeFunctionResult(p.fragment, [artist]); throw Error("unexpected"); } };
  await assert.rejects(inspectPlatformRightsRegistration(provider, prepared, deferred, original, { resolver, artistRegistry: artist }, { blockTag: 1 }), /immutable bindings/);
});

test("synthetic prepared-custody inspection binds distinct executor, source and exact value", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-platform-abi.json", import.meta.url))), iface = new Interface(fixture.contracts.flatMap(x => x.abi));
  const custodyHash = platformRightsConfigurationHash(chainId, house, custody, original, declaration);
  const auth = { configHash: custodyHash, declarationHash: declaration, tokenDataHash: keccak256(tokenData), expectedSaleNonce: 2n, expectedTokenId: 41n, expectedCollectionSerial: 1n, expectedOperationNonce: 4n, contextHash: h("context"), executor, revealFeeDeposit: 123n, nonce: h("custody-nonce"), deadline: 9_999_999_999n };
  const prepared = preparePlatformCustodyRegistration(chainId, house, custody, original, tokenData, auth, "0xabcd");
  const provider = { getNetwork: async () => ({ chainId }), call: async tx => { assert.equal(tx.blockTag, 555); const p = iface.parseTransaction({ data: tx.data }); switch (p.name) {
    case "platformCustodyAcquisitionDigest": return iface.encodeFunctionResult(p.fragment, [prepared.payload.digest]);
    case "platformRightsConfigurationHash": return iface.encodeFunctionResult(p.fragment, [custodyHash]);
    case "revenueResolver": return iface.encodeFunctionResult(p.fragment, [resolver]);
    case "artistRegistry": return iface.encodeFunctionResult(p.fragment, [artist]);
    case "platformWorksDeclaration": return iface.encodeFunctionResult(p.fragment, [true, declaration, 100n]);
    case "platformWorksContest": return iface.encodeFunctionResult(p.fragment, [2n, h("dismissed-claim")]);
    case "platformWorksCorrection": return iface.encodeFunctionResult(p.fragment, [0n, zero]);
    case "resolvePrimaryAssignment": return iface.encodeFunctionResult(p.fragment, [[true, 1n, 7n, 2n, zero, original.templateId, zero, original.assignmentHash, false]]);
    default: throw Error(`unexpected ${p.name}`);
  } } };
  const result = await inspectPlatformCustodyRegistration(provider, prepared, custody, original, { resolver, artistRegistry: artist }, { blockTag: 555 });
  assert.equal(prepared.caller, executor); assert.equal(prepared.call.value, 123n); assert.equal(result.writeSimulationRequired, true);
});

test("synthetic token activation checks stored auction/origin/poster and refuses inherited assignment", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-platform-abi.json", import.meta.url))), iface = new Interface(fixture.contracts.flatMap(x => x.abi));
  const origin = { manager: executor, managerCodeHash: h("manager-code"), operationRoot: h("root"), operationId: h("operation"), authorizationId: h("authorization"), tokenDataHash: keccak256(tokenData), tokenId: 41n, collectionSerial: 1n, operationNonce: 4n, fundingAccount: executor, revealFeeForwarded: 123n, eligible: true };
  const baseConfigHash = platformRightsConfigurationHash(chainId, house, custody, original, declaration), auctionId = h("auction"), tokenAssignment = h("token-assignment");
  const auth = { auctionId, baseConfigHash, originHash: platformCustodyOriginHash(origin), tokenId: 41n, declarationHash: declaration, rightsMode: 12n, assignmentHash: tokenAssignment, primaryPolicyHash: h("token-policy"), primaryPolicyMode: 1n, nonce: h("activation-nonce"), deadline: 9_999_999_999n };
  const prepared = preparePlatformTokenCustodyActivation(chainId, house, poster, auth, "0xbeef"), saleId = h("sale"), z = "0x0000000000000000000000000000000000000000";
  const auction = { config: custody, configHash: baseConfigHash, saleId, saleNonce: 2n, auctionNonce: 2n, status: 1n, clock: { originalEnd: 2n, nominalEnd: 2n, budgetWarningEmitted: false }, pauseBaseline: 0n, terminalToll: 0n, bindingGeneration: 0n, artistId: zero, bindingHash: zero, creationDigest: h("creation"), lifecycle: { saleCreatedAt: 1n, saleAdapterRegistryRevision: 1n }, winner: { payer: z, executor: z, deliverTo: z, amount: 0n, revealFee: 0n, bidIndex: 0n, authorizationDigest: zero, signedFinalizeBy: 0n, signed: false }, tokenId: 41n, settlementKey: zero, nftClaimant: z };
  const makeProvider = scope => ({ getNetwork: async () => ({ chainId }), call: async tx => { const p = iface.parseTransaction({ data: tx.data }); switch (p.name) {
    case "platformTokenCustodyDigest": return iface.encodeFunctionResult(p.fragment, [prepared.payload.digest]);
    case "platformTokenCustodyNonceUsed": return iface.encodeFunctionResult(p.fragment, [false]);
    case "custodyOrigin": return iface.encodeFunctionResult(p.fragment, [origin]);
    case "auction": return iface.encodeFunctionResult(p.fragment, [auction]);
    case "auctionDeadlines": return iface.encodeFunctionResult(p.fragment, [2n, 86402n, 0n, 0n]);
    case "platformAuctionDeclaration": return iface.encodeFunctionResult(p.fragment, [declaration]);
    case "revenueResolver": return iface.encodeFunctionResult(p.fragment, [resolver]);
    case "artistRegistry": return iface.encodeFunctionResult(p.fragment, [artist]);
    case "platformWorksDeclaration": return iface.encodeFunctionResult(p.fragment, [true, declaration, 100n]);
    case "platformWorksContest": return iface.encodeFunctionResult(p.fragment, [0n, zero]);
    case "platformWorksCorrection": return iface.encodeFunctionResult(p.fragment, [0n, zero]);
    case "resolvePrimaryAssignment": return iface.encodeFunctionResult(p.fragment, [[true, scope, scope === 2n ? 41n : 7n, 1n, h("profile"), zero, zero, tokenAssignment, false]]);
    default: throw Error(`unexpected ${p.name}`);
  } } });
  const ok = await inspectPlatformTokenCustodyActivation(makeProvider(2n), prepared, custody, { resolver, artistRegistry: artist }, { blockTag: 777 }); assert.equal(ok.writeSimulationRequired, true);
  await assert.rejects(inspectPlatformTokenCustodyActivation(makeProvider(1n), prepared, custody, { resolver, artistRegistry: artist }, { blockTag: 777 }), /source family/);
});
