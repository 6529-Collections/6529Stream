import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroHash, concat, id, keccak256 } from "ethers";
import * as platform from "../dist/current-platform.js";

// Independent literal Solidity preimages. These are encoding checks, not
// deployed digest observations or evidence that a signature admits a write.
const coder = AbiCoder.defaultAbiCoder();
const address = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chainId = 31337n, house = address(1);
const configType = "tuple(uint256 collectionId,bytes32 phaseId,uint256 tokenId,bool mintAtSettlement,bytes32 artworkCommitment,bytes32 contentManifestRoot,bytes32 mintCommitment,address poster,uint96 reservePrice,uint16 minIncrementBps,bool incrementFloorWaived,tuple(uint64 startTime,uint64 endTime,uint32 firstBidDuration,uint32 antiSnipeWindow,uint32 antiSnipeExtension,uint32 maxTotalExtension,bool startOnFirstBid,bool hardClose) clock,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,uint32 settlementWindow,bytes32 mintPolicyHash)";
const originalType = "tuple(uint8 mode,bytes32 assignmentHash,bytes32 templateId)";
const originType = "tuple(address manager,bytes32 managerCodeHash,bytes32 operationRoot,bytes32 operationId,bytes32 authorizationId,bytes32 tokenDataHash,uint256 tokenId,uint256 collectionSerial,uint256 operationNonce,address fundingAccount,uint256 revealFeeForwarded,bool eligible)";
const creationType = "PlatformNativeAuctionCreation(bytes32 configHash,bytes32 declarationHash,bytes32 nonce,uint64 deadline)";
const custodyType = "PlatformPreparedCustodyAcquisition(bytes32 configHash,bytes32 declarationHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,bytes32 nonce,uint64 deadline)";
const activationType = "PlatformTokenCustodyRights(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,bytes32 declarationHash,uint8 rightsMode,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,bytes32 nonce,uint64 deadline)";
const fields = type => type.slice(type.indexOf("(") + 1, -1).split(",").map(field => {
  const [type, name] = field.split(" ");
  return { type, name };
});
function oracleDigest(name, type, message, chain = chainId, verifier = house) {
  const schema = fields(type);
  const domain = keccak256(coder.encode(
    ["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id(name), id("1"), chain, verifier],
  ));
  const body = keccak256(coder.encode(
    ["bytes32", ...schema.map(field => field.type)],
    [id(type), ...schema.map(field => message[field.name])],
  ));
  return keccak256(concat(["0x1901", domain, body]));
}
const declaration = id("platform declaration");
const config = {
  collectionId: 9007199254740993n, phaseId: id("phase"), tokenId: 0n,
  mintAtSettlement: true, artworkCommitment: id("artwork"), contentManifestRoot: ZeroHash,
  mintCommitment: id("mint"), poster: address(2), reservePrice: 10n ** 18n,
  minIncrementBps: 500n, incrementFloorWaived: false,
  clock: { startTime: 2000000000n, endTime: 2000086400n, firstBidDuration: 0n,
    antiSnipeWindow: 300n, antiSnipeExtension: 300n, maxTotalExtension: 1800n,
    startOnFirstBid: false, hardClose: false },
  expectedPrimaryPolicyHash: id("primary policy"), primaryPolicyMode: 1n,
  settlementWindow: 86400n, mintPolicyHash: id("mint policy"),
};
const original = { mode: 8n, assignmentHash: id("assignment"), templateId: id("template") };
const creation = { configHash: id("config"), declarationHash: declaration, nonce: id("creation nonce"), deadline: 2000009000n };
const custody = { configHash: id("custody config"), declarationHash: declaration, tokenDataHash: id("artwork"),
  expectedSaleNonce: 9007199254740995n, expectedTokenId: 9007199254740996n,
  expectedCollectionSerial: 9007199254740997n, expectedOperationNonce: 9007199254740998n,
  contextHash: id("context"), executor: address(2), revealFeeDeposit: 2000n,
  nonce: id("custody nonce"), deadline: 2000009000n };
const activation = { auctionId: id("auction"), baseConfigHash: id("base config"), originHash: id("origin"),
  tokenId: 9007199254740996n, declarationHash: declaration, rightsMode: 12n,
  assignmentHash: id("token assignment"), primaryPolicyHash: id("token policy"), primaryPolicyMode: 1n,
  nonce: id("activation nonce"), deadline: 2000009000n };

for (const [label, helper, domain, type, message] of [
  ["creation", "platformCreationSigningPayload", "6529StreamPlatformNativeRightsAuction", creationType, creation],
  ["prepared custody", "platformCustodySigningPayload", "6529StreamPlatformPreparedCustodyAuction", custodyType, custody],
  ["known-token custody", "platformTokenCustodySigningPayload", "6529StreamPlatformTokenCustodyRights", activationType, activation],
]) {
  test(`${label} matches the literal domain and binds every field, chain and house`, () => {
    const build = platform[helper];
    const payload = build(chainId, house, message);
    assert.equal(payload.digest, oracleDigest(domain, type, message));
    assert.deepEqual(payload.types[payload.primaryType], fields(type));
    assert.equal(Object.hasOwn(payload.message, "artist"), false);
    assert.notEqual(build(chainId + 1n, house, message).digest, payload.digest);
    assert.notEqual(build(chainId, address(3), message).digest, payload.digest);
    for (const field of fields(type)) {
      const value = field.type === "bytes32" ? id(`changed:${field.name}`)
        : field.type === "address" ? address(4) : message[field.name] + 1n;
      const changed = { ...message, [field.name]: value };
      if (field.name === "primaryPolicyMode") {
        assert.throws(() => build(chainId, house, changed), /ALLOW_CURRENT/);
        continue;
      }
      assert.equal(build(chainId, house, changed).digest, oracleDigest(domain, type, changed));
      assert.notEqual(build(chainId, house, changed).digest, payload.digest, field.name);
    }
    assert.throws(() => build(chainId, house, { ...message, artist: address(9) }));
    assert.throws(() => build(chainId, house, { ...message, deadline: Number(message.deadline) }));
    assert.throws(() => build(chainId, house, { ...message, deadline: 1n << 64n }));
  });
}

test("PLATFORM original configuration includes nested clock, exact policy and declaration", () => {
  const oracle = (c, o, d, chain = chainId, verifier = house) => keccak256(coder.encode(
    ["bytes32", "uint256", "address", configType, originalType, "bytes32"],
    [id("6529STREAM_PLATFORM_NATIVE_RIGHTS_CONFIG_V1"), chain, verifier, c, o, d],
  ));
  const build = platform.platformRightsConfigurationHash;
  const expected = oracle(config, original, declaration);
  assert.equal(build(chainId, house, config, original, declaration), expected);
  const mutations = [
    [{ ...config, poster: address(8) }, original, declaration],
    [{ ...config, tokenId: 9007199254740996n, mintAtSettlement: false, artworkCommitment: ZeroHash }, original, declaration],
    [{ ...config, clock: { ...config.clock, antiSnipeWindow: 301n } }, original, declaration],
    [{ ...config, clock: { ...config.clock, hardClose: true } }, original, declaration],
    [config, { ...original, mode: 9n }, declaration],
    [config, { ...original, assignmentHash: id("changed assignment") }, declaration],
    [config, { ...original, templateId: id("changed template") }, declaration],
    [config, original, id("changed declaration")],
  ];
  for (const [c, o, d] of mutations) {
    assert.equal(build(chainId, house, c, o, d), oracle(c, o, d));
    assert.notEqual(build(chainId, house, c, o, d), expected);
  }
  assert.equal(build(chainId + 1n, house, config, original, declaration), oracle(config, original, declaration, chainId + 1n));
  assert.notEqual(build(chainId + 1n, house, config, original, declaration), expected);
  assert.notEqual(build(chainId, address(8), config, original, declaration), expected);
});

test("custody origin preserves acquisition funding and operation coordinates", () => {
  const origin = { manager: address(5), managerCodeHash: id("manager runtime"), operationRoot: id("root"),
    operationId: id("operation"), authorizationId: id("authorization"), tokenDataHash: id("artwork"),
    tokenId: 9007199254740996n, collectionSerial: 9007199254740997n,
    operationNonce: 9007199254740998n, fundingAccount: address(6), revealFeeForwarded: 2000n, eligible: true };
  const oracle = value => keccak256(coder.encode([originType], [value]));
  assert.equal(platform.platformCustodyOriginHash(origin), oracle(origin));
  for (const [name, value] of Object.entries(origin)) {
    const changed = typeof value === "bigint" ? value + 1n : typeof value === "boolean" ? !value
      : value.length === 42 ? address(9) : id(`changed:${name}`);
    const next = { ...origin, [name]: changed };
    assert.equal(platform.platformCustodyOriginHash(next), oracle(next));
    assert.notEqual(platform.platformCustodyOriginHash(next), oracle(origin), name);
  }
});

test("effective token-custody configuration binds the authorization and its separate domain digest", () => {
  const digest = oracleDigest("6529StreamPlatformTokenCustodyRights", activationType, activation);
  const tuple = `tuple(${activationType.slice(activationType.indexOf("(") + 1, -1)})`;
  const expected = keccak256(coder.encode(
    ["bytes32", "uint256", "address", tuple, "bytes32"],
    [id("6529STREAM_PLATFORM_TOKEN_CUSTODY_ALLOW_CURRENT_CONFIG_V1"), chainId, house, activation, digest],
  ));
  assert.equal(platform.platformTokenCustodyConfigurationHash(chainId, house, activation), expected);
  assert.equal(platform.platformTokenCustodyConfigurationHash(chainId, house, activation, digest), expected);
  assert.throws(() => platform.platformTokenCustodyConfigurationHash(chainId, house, activation, id("unrelated digest")));
  assert.notEqual(platform.platformTokenCustodyConfigurationHash(chainId, house, { ...activation, rightsMode: 13n }), expected);
  assert.notEqual(platform.platformTokenCustodyConfigurationHash(chainId + 1n, house, activation), expected);
  assert.notEqual(platform.platformTokenCustodyConfigurationHash(chainId, address(8), activation), expected);
});
