import {
  AbiCoder, Interface, ZeroAddress, getAddress, id, isHexString, keccak256,
} from "ethers";
import type { BlockTag, Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";

export interface PlatformClockConfiguration {
  readonly startTime: bigint; readonly endTime: bigint; readonly firstBidDuration: bigint;
  readonly antiSnipeWindow: bigint; readonly antiSnipeExtension: bigint;
  readonly maxTotalExtension: bigint; readonly startOnFirstBid: boolean; readonly hardClose: boolean;
}
export interface PlatformAuctionConfiguration {
  readonly collectionId: bigint; readonly phaseId: Hex; readonly tokenId: bigint;
  readonly mintAtSettlement: boolean; readonly artworkCommitment: Hex;
  readonly contentManifestRoot: Hex; readonly mintCommitment: Hex; readonly poster: Address;
  readonly reservePrice: bigint; readonly minIncrementBps: bigint;
  readonly incrementFloorWaived: boolean; readonly clock: PlatformClockConfiguration;
  readonly expectedPrimaryPolicyHash: Hex; readonly primaryPolicyMode: bigint;
  readonly settlementWindow: bigint; readonly mintPolicyHash: Hex;
}
export interface PlatformOriginalPolicy {
  /** 8/9: collection/default TEMPLATE; 10/11: collection/default PROFILE. */
  readonly mode: bigint; readonly assignmentHash: Hex; readonly templateId: Hex;
}
export interface PlatformCreationAuthorization {
  readonly configHash: Hex; readonly declarationHash: Hex; readonly nonce: Hex; readonly deadline: bigint;
}
export interface PlatformCustodyAuthorization {
  readonly configHash: Hex; readonly declarationHash: Hex; readonly tokenDataHash: Hex;
  readonly expectedSaleNonce: bigint; readonly expectedTokenId: bigint;
  readonly expectedCollectionSerial: bigint; readonly expectedOperationNonce: bigint;
  readonly contextHash: Hex; readonly executor: Address; readonly revealFeeDeposit: bigint;
  readonly nonce: Hex; readonly deadline: bigint;
}
export interface PlatformTokenCustodyAuthorization {
  readonly auctionId: Hex; readonly baseConfigHash: Hex; readonly originHash: Hex;
  readonly tokenId: bigint; readonly declarationHash: Hex; readonly rightsMode: bigint;
  readonly assignmentHash: Hex; readonly primaryPolicyHash: Hex;
  readonly primaryPolicyMode: bigint; readonly nonce: Hex; readonly deadline: bigint;
}
export interface PlatformBidAuthorization {
  readonly auctionId: Hex; readonly configHash: Hex; readonly payer: Address;
  readonly executor: Address; readonly deliverTo: Address; readonly amount: bigint;
  readonly maxRevealFee: bigint; readonly nonce: Hex; readonly deadline: bigint;
  readonly finalizeBy: bigint;
}
export interface PlatformCustodyOrigin {
  readonly manager: Address; readonly managerCodeHash: Hex; readonly operationRoot: Hex;
  readonly operationId: Hex; readonly authorizationId: Hex; readonly tokenDataHash: Hex;
  readonly tokenId: bigint; readonly collectionSerial: bigint; readonly operationNonce: bigint;
  readonly fundingAccount: Address; readonly revealFeeForwarded: bigint; readonly eligible: boolean;
}
export interface PreparedPlatformWrite<T extends object> {
  readonly kind: "rights-registration" | "custody-registration" | "token-custody-activation";
  readonly caller: Address; readonly payload: SigningPayload<T>;
  readonly call: UnsignedCall; readonly digestCall: UnsignedCall;
  readonly configurationCall?: UnsignedCall;
}
export interface PlatformInspection {
  readonly blockTag: number; readonly checked: readonly string[];
  /** Contract facts that have no public getter and therefore remain write-simulation checks. */
  readonly unavailable: readonly string[];
  readonly writeSimulationRequired: true;
}
export interface PlatformSourceRead {
  readonly resolver: Address; readonly artistRegistry: Address;
}

const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const coder = AbiCoder.defaultAbiCoder();
const clockTuple = "tuple(uint64 startTime,uint64 endTime,uint32 firstBidDuration,uint32 antiSnipeWindow,uint32 antiSnipeExtension,uint32 maxTotalExtension,bool startOnFirstBid,bool hardClose)";
const configTuple = `tuple(uint256 collectionId,bytes32 phaseId,uint256 tokenId,bool mintAtSettlement,bytes32 artworkCommitment,bytes32 contentManifestRoot,bytes32 mintCommitment,address poster,uint96 reservePrice,uint16 minIncrementBps,bool incrementFloorWaived,${clockTuple} clock,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,uint32 settlementWindow,bytes32 mintPolicyHash)`;
const originalTuple = "tuple(uint8 mode,bytes32 assignmentHash,bytes32 templateId)";
const custodyTuple = "tuple(bytes32 configHash,bytes32 declarationHash,bytes32 tokenDataHash,uint256 expectedSaleNonce,uint256 expectedTokenId,uint256 expectedCollectionSerial,uint256 expectedOperationNonce,bytes32 contextHash,address executor,uint256 revealFeeDeposit,bytes32 nonce,uint64 deadline)";
const tokenAuthorizationTuple = "tuple(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,bytes32 declarationHash,uint8 rightsMode,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,bytes32 nonce,uint64 deadline)";
const bidTuple = "tuple(bytes32 auctionId,bytes32 configHash,address payer,address executor,address deliverTo,uint256 amount,uint256 maxRevealFee,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const originTuple = "tuple(address manager,bytes32 managerCodeHash,bytes32 operationRoot,bytes32 operationId,bytes32 authorizationId,bytes32 tokenDataHash,uint256 tokenId,uint256 collectionSerial,uint256 operationNonce,address fundingAccount,uint256 revealFeeForwarded,bool eligible)";
const auctionTuple = `tuple(${configTuple} config,bytes32 configHash,bytes32 saleId,uint256 saleNonce,uint256 auctionNonce,uint8 status,tuple(uint64 originalEnd,uint64 nominalEnd,bool budgetWarningEmitted) clock,uint64 pauseBaseline,uint64 terminalToll,uint64 bindingGeneration,bytes32 artistId,bytes32 bindingHash,bytes32 creationDigest,tuple(uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision) lifecycle,tuple(address payer,address executor,address deliverTo,uint256 amount,uint256 revealFee,uint256 bidIndex,bytes32 authorizationDigest,uint64 signedFinalizeBy,bool signed) winner,uint256 tokenId,bytes32 settlementKey,address nftClaimant)`;
const auctionInterface = new Interface([
  `function platformRightsConfigurationHash(${configTuple},${originalTuple},bytes32) view returns (bytes32)`,
  "function platformRightsCreationDigest((bytes32 configHash,bytes32 declarationHash,bytes32 nonce,uint64 deadline)) view returns (bytes32)",
  `function registerPlatformRightsAuction(${configTuple},${originalTuple},bytes,(bytes32 configHash,bytes32 declarationHash,bytes32 nonce,uint64 deadline),bytes) returns (bytes32)`,
  `function platformCustodyAcquisitionDigest(${custodyTuple}) view returns (bytes32)`,
  `function registerPlatformCustodyAuction(${configTuple},${originalTuple},bytes,${custodyTuple},bytes) payable returns (bytes32)`,
  `function platformTokenCustodyDigest(${tokenAuthorizationTuple}) view returns (bytes32)`,
  `function activatePlatformTokenCustody(${tokenAuthorizationTuple},bytes)`,
  "function platformTokenCustodyNonceUsed(bytes32) view returns (bool)",
  "function revenueResolver() view returns (address)",
  "function artistRegistry() view returns (address)",
  "function platformAuctionDeclaration(bytes32) view returns (bytes32)",
  `function auction(bytes32) view returns (${auctionTuple})`,
  "function auctionDeadlines(bytes32) view returns (uint64,uint64,uint64,uint64)",
  `function custodyOrigin(bytes32) view returns (${originTuple})`,
  "function platformTokenCustodyConfigurationHash(bytes32) view returns (bytes32)",
  `function platformTokenCustodyActivation(bytes32) view returns (tuple(${tokenAuthorizationTuple} authorization,bytes32 authorizationDigest,bytes32 effectiveConfigHash))`,
  "function bidPlatformTokenCustody(bytes32,address) payable",
  `function bidSignedPlatformTokenCustody(${bidTuple},bytes) payable`,
  "function settlePlatformTokenCustody(bytes32) returns (uint256,bytes32)",
]);
const resolverInterface = new Interface([
  "function resolvePrimaryAssignment(uint256,uint256,bytes32) view returns ((bool exists,uint8 scope,uint256 scopeId,uint8 assignmentType,bytes32 profileId,bytes32 templateId,bytes32 policyHash,bytes32 assignmentHash,bool frozen))",
]);
const artistInterface = new Interface([
  "function platformWorksDeclaration(uint256) view returns (bool,bytes32,uint64)",
  "function platformWorksContest(uint256) view returns (uint8,bytes32)",
  "function platformWorksCorrection(uint256) view returns (uint64,bytes32)",
]);
const primarySale = id("PRIMARY_SALE") as Hex;

const creationFields = [
  { name: "configHash", type: "bytes32" }, { name: "declarationHash", type: "bytes32" },
  { name: "nonce", type: "bytes32" }, { name: "deadline", type: "uint64" },
] as const;
const custodyFields = [
  { name: "configHash", type: "bytes32" }, { name: "declarationHash", type: "bytes32" },
  { name: "tokenDataHash", type: "bytes32" }, { name: "expectedSaleNonce", type: "uint256" },
  { name: "expectedTokenId", type: "uint256" }, { name: "expectedCollectionSerial", type: "uint256" },
  { name: "expectedOperationNonce", type: "uint256" }, { name: "contextHash", type: "bytes32" },
  { name: "executor", type: "address" }, { name: "revealFeeDeposit", type: "uint256" },
  { name: "nonce", type: "bytes32" }, { name: "deadline", type: "uint64" },
] as const;
const tokenFields = [
  { name: "auctionId", type: "bytes32" }, { name: "baseConfigHash", type: "bytes32" },
  { name: "originHash", type: "bytes32" }, { name: "tokenId", type: "uint256" },
  { name: "declarationHash", type: "bytes32" }, { name: "rightsMode", type: "uint8" },
  { name: "assignmentHash", type: "bytes32" }, { name: "primaryPolicyHash", type: "bytes32" },
  { name: "primaryPolicyMode", type: "uint8" }, { name: "nonce", type: "bytes32" },
  { name: "deadline", type: "uint64" },
] as const;

function uint(value: bigint, bits: number, name: string): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`${name} must fit uint${bits} bigint`);
  return value;
}
function hex32(value: Hex, name: string, zero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (!zero && value.toLowerCase() === ZERO32)) throw Error(`${name} must be ${zero ? "a" : "a nonzero"} bytes32 value`);
  return value;
}
function address(value: Address, name: string): Address {
  const out = getAddress(value) as Address; if (out === ZeroAddress) throw Error(`${name} must be nonzero`); return out;
}
function bytes(value: Hex, name: string, empty = true): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (!empty && value === "0x")) throw Error(`${name} must contain complete hex bytes`); return value;
}
function call(to: Address, method: string, args: readonly unknown[], value = 0n): UnsignedCall {
  address(to, "house"); uint(value, 256, "value");
  return Object.freeze({ to, data: auctionInterface.encodeFunctionData(method, args) as Hex, value });
}
function concreteBlock(blockTag: number): number {
  if (!Number.isSafeInteger(blockTag) || blockTag < 0) throw Error("A concrete nonnegative block number is required"); return blockTag;
}
function sameTuple(type: string, left: unknown, right: unknown): boolean { return coder.encode([type], [left]).toLowerCase() === coder.encode([type], [right]).toLowerCase(); }
function sameJSON(left: unknown, right: unknown): boolean { return JSON.stringify(left, (_, v) => typeof v === "bigint" ? v.toString() : v) === JSON.stringify(right, (_, v) => typeof v === "bigint" ? v.toString() : v); }
function namedTuple(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || !("toObject" in value) || typeof (value as { toObject?: unknown }).toObject !== "function") throw Error("Expected decoded named tuple");
  return (value as { toObject(deep: boolean): Record<string, unknown> }).toObject(true);
}
function exactKeys(value: object, expected: readonly string[], name: string): void {
  if (Object.keys(value).sort().join(",") !== [...expected].sort().join(",")) throw Error(`${name} contains missing or unknown properties`);
}
function validateConfig(c: PlatformAuctionConfiguration, custody: boolean): void {
  exactKeys(c, ["collectionId", "phaseId", "tokenId", "mintAtSettlement", "artworkCommitment", "contentManifestRoot", "mintCommitment", "poster", "reservePrice", "minIncrementBps", "incrementFloorWaived", "clock", "expectedPrimaryPolicyHash", "primaryPolicyMode", "settlementWindow", "mintPolicyHash"], "configuration");
  exactKeys(c.clock, ["startTime", "endTime", "firstBidDuration", "antiSnipeWindow", "antiSnipeExtension", "maxTotalExtension", "startOnFirstBid", "hardClose"], "clock configuration");
  for (const [n, v] of [["mintAtSettlement", c.mintAtSettlement], ["incrementFloorWaived", c.incrementFloorWaived], ["startOnFirstBid", c.clock.startOnFirstBid], ["hardClose", c.clock.hardClose]] as const) if (typeof v !== "boolean") throw Error(`${n} must be boolean`);
  uint(c.collectionId, 256, "collectionId"); if (c.collectionId === 0n) throw Error("collectionId must be nonzero");
  hex32(c.phaseId, "phaseId"); uint(c.tokenId, 256, "tokenId"); address(c.poster, "poster");
  hex32(c.artworkCommitment, "artworkCommitment", custody); hex32(c.contentManifestRoot, "contentManifestRoot", true);
  hex32(c.mintCommitment, "mintCommitment"); hex32(c.expectedPrimaryPolicyHash, "expectedPrimaryPolicyHash");
  hex32(c.mintPolicyHash, "mintPolicyHash"); uint(c.reservePrice, 96, "reservePrice");
  uint(c.minIncrementBps, 16, "minIncrementBps"); uint(c.primaryPolicyMode, 8, "primaryPolicyMode");
  uint(c.settlementWindow, 32, "settlementWindow"); if (c.primaryPolicyMode !== 1n) throw Error("Platform auctions require ALLOW_CURRENT (1)");
  if (custody !== !c.mintAtSettlement || (custody ? c.tokenId === 0n || c.artworkCommitment !== ZERO32 || c.contentManifestRoot !== ZERO32 : c.tokenId !== 0n || c.contentManifestRoot !== ZERO32)) throw Error("Configuration does not match the selected platform acquisition family");
  for (const [n, v, b] of [["startTime", c.clock.startTime, 64], ["endTime", c.clock.endTime, 64], ["firstBidDuration", c.clock.firstBidDuration, 32], ["antiSnipeWindow", c.clock.antiSnipeWindow, 32], ["antiSnipeExtension", c.clock.antiSnipeExtension, 32], ["maxTotalExtension", c.clock.maxTotalExtension, 32]] as const) uint(v, b, n);
}
function validateOriginal(p: PlatformOriginalPolicy): void {
  uint(p.mode, 8, "original mode"); if (p.mode < 8n || p.mode > 11n) throw Error("Original policy mode must be 8 through 11");
  hex32(p.assignmentHash, "assignmentHash"); hex32(p.templateId, "templateId", p.mode >= 10n);
  if ((p.mode <= 9n) !== (p.templateId !== ZERO32)) throw Error("Template ID presence differs from the selected original policy mode");
}
function validateCreation(a: PlatformCreationAuthorization): void { hex32(a.configHash, "configHash"); hex32(a.declarationHash, "declarationHash"); hex32(a.nonce, "nonce"); uint(a.deadline, 64, "deadline"); }
function validateCustody(a: PlatformCustodyAuthorization): void {
  for (const n of ["configHash", "declarationHash", "tokenDataHash", "contextHash", "nonce"] as const) hex32(a[n], n);
  for (const n of ["expectedSaleNonce", "expectedTokenId", "expectedCollectionSerial", "expectedOperationNonce", "revealFeeDeposit"] as const) uint(a[n], 256, n);
  uint(a.deadline, 64, "deadline"); address(a.executor, "executor");
}
function validateToken(a: PlatformTokenCustodyAuthorization): void {
  for (const n of ["auctionId", "baseConfigHash", "originHash", "declarationHash", "assignmentHash", "primaryPolicyHash", "nonce"] as const) hex32(a[n], n);
  uint(a.tokenId, 256, "tokenId"); if (a.tokenId === 0n) throw Error("tokenId must be nonzero");
  uint(a.rightsMode, 8, "rightsMode"); if (a.rightsMode !== 12n && a.rightsMode !== 13n) throw Error("Known-token rights mode must be 12 or 13");
  uint(a.primaryPolicyMode, 8, "primaryPolicyMode"); if (a.primaryPolicyMode !== 1n) throw Error("Known-token activation requires ALLOW_CURRENT (1)"); uint(a.deadline, 64, "deadline");
}

export function platformRightsConfigurationHash(chainId: bigint, house: Address, config: PlatformAuctionConfiguration, original: PlatformOriginalPolicy, declarationHash: Hex): Hex {
  uint(chainId, 256, "chainId"); if (chainId === 0n) throw Error("chainId must be positive"); address(house, "house"); validateConfig(config, !config.mintAtSettlement); validateOriginal(original); hex32(declarationHash, "declarationHash");
  return keccak256(coder.encode(["bytes32", "uint256", "address", configTuple, originalTuple, "bytes32"], [id("6529STREAM_PLATFORM_NATIVE_RIGHTS_CONFIG_V1"), chainId, house, config, original, declarationHash])) as Hex;
}
export function platformCreationSigningPayload(chainId: bigint, house: Address, authorization: PlatformCreationAuthorization): SigningPayload<PlatformCreationAuthorization> {
  validateCreation(authorization); return buildSigningPayload(chainId, house, "6529StreamPlatformNativeRightsAuction", "PlatformNativeAuctionCreation", creationFields, authorization);
}
export function platformCustodySigningPayload(chainId: bigint, house: Address, authorization: PlatformCustodyAuthorization): SigningPayload<PlatformCustodyAuthorization> {
  validateCustody(authorization); return buildSigningPayload(chainId, house, "6529StreamPlatformPreparedCustodyAuction", "PlatformPreparedCustodyAcquisition", custodyFields, authorization);
}
export function platformTokenCustodySigningPayload(chainId: bigint, house: Address, authorization: PlatformTokenCustodyAuthorization): SigningPayload<PlatformTokenCustodyAuthorization> {
  validateToken(authorization); return buildSigningPayload(chainId, house, "6529StreamPlatformTokenCustodyRights", "PlatformTokenCustodyRights", tokenFields, authorization);
}
export function platformCustodyOriginHash(origin: PlatformCustodyOrigin): Hex {
  address(origin.manager, "origin manager"); address(origin.fundingAccount, "origin fundingAccount");
  for (const n of ["managerCodeHash", "operationRoot", "operationId", "authorizationId", "tokenDataHash"] as const) hex32(origin[n], `origin ${n}`);
  for (const n of ["tokenId", "collectionSerial", "operationNonce", "revealFeeForwarded"] as const) uint(origin[n], 256, `origin ${n}`);
  if (typeof origin.eligible !== "boolean") throw Error("origin eligible must be boolean");
  return keccak256(coder.encode([originTuple], [origin])) as Hex;
}
export function platformTokenCustodyConfigurationHash(chainId: bigint, house: Address, authorization: PlatformTokenCustodyAuthorization, authorizationDigest?: Hex): Hex {
  const expected = platformTokenCustodySigningPayload(chainId, house, authorization).digest;
  const digest = authorizationDigest ?? expected;
  hex32(digest, "authorizationDigest");
  if (digest.toLowerCase() !== expected.toLowerCase()) throw Error("authorizationDigest differs from independent platform token-custody digest");
  // Solidity hashes only authorization and authorizationDigest, in Activation field order.
  validateToken(authorization);
  return keccak256(coder.encode(["bytes32", "uint256", "address", tokenAuthorizationTuple, "bytes32"], [id("6529STREAM_PLATFORM_TOKEN_CUSTODY_ALLOW_CURRENT_CONFIG_V1"), chainId, house, authorization, digest])) as Hex;
}

export function preparePlatformRightsRegistration(chainId: bigint, house: Address, config: PlatformAuctionConfiguration, original: PlatformOriginalPolicy, tokenData: Hex, authorization: PlatformCreationAuthorization, platformSignature: Hex): PreparedPlatformWrite<PlatformCreationAuthorization> {
  validateConfig(config, false); validateOriginal(original); bytes(tokenData, "tokenData"); bytes(platformSignature, "platformSignature", false);
  const computed = platformRightsConfigurationHash(chainId, house, config, original, authorization.declarationHash);
  if (computed.toLowerCase() !== authorization.configHash.toLowerCase()) throw Error("Authorization configHash differs from independent platform configuration hash");
  if (keccak256(tokenData).toLowerCase() !== config.artworkCommitment.toLowerCase()) throw Error("tokenData differs from artworkCommitment");
  const payload = platformCreationSigningPayload(chainId, house, authorization);
  return Object.freeze({ kind: "rights-registration", caller: address(config.poster, "poster"), payload,
    call: call(house, "registerPlatformRightsAuction", [config, original, tokenData, authorization, platformSignature]),
    digestCall: call(house, "platformRightsCreationDigest", [authorization]),
    configurationCall: call(house, "platformRightsConfigurationHash", [config, original, authorization.declarationHash]),
  });
}
export function preparePlatformCustodyRegistration(chainId: bigint, house: Address, config: PlatformAuctionConfiguration, original: PlatformOriginalPolicy, tokenData: Hex, authorization: PlatformCustodyAuthorization, platformSignature: Hex): PreparedPlatformWrite<PlatformCustodyAuthorization> {
  validateConfig(config, true); validateOriginal(original); validateCustody(authorization); bytes(tokenData, "tokenData"); bytes(platformSignature, "platformSignature", false);
  const actual = platformRightsConfigurationHash(chainId, house, config, original, authorization.declarationHash);
  if (actual.toLowerCase() !== authorization.configHash.toLowerCase()) throw Error("Authorization configHash differs from independent platform configuration hash");
  if (keccak256(tokenData).toLowerCase() !== authorization.tokenDataHash.toLowerCase()) throw Error("tokenData differs from tokenDataHash");
  if (authorization.expectedTokenId !== config.tokenId) throw Error("Expected token ID differs from configuration");
  const payload = platformCustodySigningPayload(chainId, house, authorization);
  return Object.freeze({ kind: "custody-registration", caller: address(authorization.executor, "executor"), payload,
    call: call(house, "registerPlatformCustodyAuction", [config, original, tokenData, authorization, platformSignature], authorization.revealFeeDeposit),
    digestCall: call(house, "platformCustodyAcquisitionDigest", [authorization]),
    configurationCall: call(house, "platformRightsConfigurationHash", [config, original, authorization.declarationHash]),
  });
}
export function preparePlatformTokenCustodyActivation(chainId: bigint, house: Address, poster: Address, authorization: PlatformTokenCustodyAuthorization, platformSignature: Hex): PreparedPlatformWrite<PlatformTokenCustodyAuthorization> {
  validateToken(authorization); bytes(platformSignature, "platformSignature", false); const payload = platformTokenCustodySigningPayload(chainId, house, authorization);
  return Object.freeze({ kind: "token-custody-activation", caller: address(poster, "poster"), payload,
    call: call(house, "activatePlatformTokenCustody", [authorization, platformSignature]), digestCall: call(house, "platformTokenCustodyDigest", [authorization]) });
}
export function preparePlatformTokenCustodyBid(house: Address, auctionId: Hex, deliverTo: Address, amount: bigint, revealFee: bigint): UnsignedCall {
  hex32(auctionId, "auctionId"); address(deliverTo, "deliverTo"); uint(amount, 256, "amount"); uint(revealFee, 256, "revealFee"); if (amount === 0n) throw Error("amount must be nonzero"); if (revealFee !== 0n) throw Error("Known-token custody bids require zero reveal fee"); return call(house, "bidPlatformTokenCustody", [auctionId, deliverTo], amount);
}
export function prepareSignedPlatformTokenCustodyBid(house: Address, authorization: PlatformBidAuthorization, signature: Hex, actualRevealFee: bigint): UnsignedCall {
  for (const n of ["auctionId", "configHash", "nonce"] as const) hex32(authorization[n], n); for (const n of ["payer", "executor", "deliverTo"] as const) address(authorization[n], n);
  for (const n of ["amount", "maxRevealFee"] as const) uint(authorization[n], 256, n); uint(authorization.deadline, 64, "deadline"); uint(authorization.finalizeBy, 64, "finalizeBy"); uint(actualRevealFee, 256, "actualRevealFee"); bytes(signature, "signature", false);
  if (authorization.amount === 0n || actualRevealFee !== 0n) throw Error("Known-token custody signed bids require a nonzero amount and zero actual reveal fee");
  return call(house, "bidSignedPlatformTokenCustody", [authorization, signature], authorization.amount);
}
export function preparePlatformTokenCustodySettlement(house: Address, auctionId: Hex): UnsignedCall { hex32(auctionId, "auctionId"); return call(house, "settlePlatformTokenCustody", [auctionId]); }

async function rpc(provider: Pick<Provider, "call">, target: Address, iface: Interface, method: string, args: readonly unknown[], blockTag: BlockTag): Promise<readonly unknown[]> {
  const raw = await provider.call({ to: target, data: iface.encodeFunctionData(method, args), blockTag }); if (!isHexString(raw, true)) throw Error(`Malformed ${method} return bytes`);
  const decoded = iface.decodeFunctionResult(method, raw); if (iface.encodeFunctionResult(method, decoded).toLowerCase() !== raw.toLowerCase()) throw Error(`Noncanonical ${method} return bytes`); return Array.from(decoded);
}
async function baseInspect(provider: Pick<Provider, "getNetwork" | "call">, prepared: PreparedPlatformWrite<object>, blockTag: BlockTag, digestMethod: string): Promise<string[]> {
  validatePreparedPacket(prepared);
  if ((await provider.getNetwork()).chainId !== BigInt(prepared.payload.domain.chainId ?? 0)) throw Error("RPC chain differs from platform signing domain");
  const [digest] = await rpc(provider, prepared.call.to, auctionInterface, digestMethod, [prepared.payload.message], blockTag);
  if (String(digest).toLowerCase() !== prepared.payload.digest.toLowerCase()) throw Error("Canonical digest getter differs from independent typed-data digest");
  return ["RPC chain matches signing domain", "canonical digest getter matches independent typed-data digest"];
}
function validatePreparedPacket(prepared: PreparedPlatformWrite<object>): void {
  if (!prepared || typeof prepared !== "object") throw Error("Expected prepared PLATFORM write");
  const target = address(prepared.call.to, "prepared target"), domainTarget = address(prepared.payload.domain.verifyingContract as Address, "signing domain target");
  if (target !== domainTarget || prepared.digestCall.to.toLowerCase() !== target.toLowerCase() || prepared.digestCall.value !== 0n) throw Error("Prepared call targets differ from signing domain");
  const parsed = auctionInterface.parseTransaction({ data: prepared.call.data, value: prepared.call.value }); if (!parsed) throw Error("Prepared call does not decode");
  const expectedMethod = prepared.kind === "rights-registration" ? "registerPlatformRightsAuction" : prepared.kind === "custody-registration" ? "registerPlatformCustodyAuction" : prepared.kind === "token-custody-activation" ? "activatePlatformTokenCustody" : undefined;
  if (!expectedMethod || parsed.name !== expectedMethod) throw Error("Prepared call method differs from declared PLATFORM write kind");
  if (auctionInterface.encodeFunctionData(parsed.fragment, parsed.args).toLowerCase() !== prepared.call.data.toLowerCase()) throw Error("Prepared call is noncanonical");
  let rebuilt: SigningPayload<object>, auth: unknown, method: string, expectedValue = 0n;
  if (prepared.kind === "rights-registration") {
    method = "registerPlatformRightsAuction"; const creationAuth = namedTuple(parsed.args[3]); auth = creationAuth; const config = namedTuple(parsed.args[0]) as unknown as PlatformAuctionConfiguration, original = namedTuple(parsed.args[1]) as unknown as PlatformOriginalPolicy;
    validateConfig(config, false); validateOriginal(original);
    rebuilt = platformCreationSigningPayload(BigInt(prepared.payload.domain.chainId ?? 0), target, creationAuth as unknown as PlatformCreationAuthorization); address(config.poster, "poster");
    const computed = platformRightsConfigurationHash(BigInt(prepared.payload.domain.chainId ?? 0), target, config, original, creationAuth.declarationHash as Hex);
    if (computed.toLowerCase() !== String(creationAuth.configHash).toLowerCase() || prepared.caller.toLowerCase() !== String(config.poster).toLowerCase() || keccak256(parsed.args[2]).toLowerCase() !== String(config.artworkCommitment).toLowerCase() || parsed.args[4] === "0x") throw Error("Prepared rights configuration/caller/token data/signature differs");
  } else if (prepared.kind === "custody-registration") {
    method = "registerPlatformCustodyAuction"; const custodyAuth = namedTuple(parsed.args[3]), config = namedTuple(parsed.args[0]) as unknown as PlatformAuctionConfiguration, original = namedTuple(parsed.args[1]) as unknown as PlatformOriginalPolicy; validateConfig(config, true); validateOriginal(original); auth = custodyAuth; rebuilt = platformCustodySigningPayload(BigInt(prepared.payload.domain.chainId ?? 0), target, custodyAuth as unknown as PlatformCustodyAuthorization); expectedValue = BigInt(custodyAuth.revealFeeDeposit as bigint);
    const computed = platformRightsConfigurationHash(BigInt(prepared.payload.domain.chainId ?? 0), target, config, original, custodyAuth.declarationHash as Hex);
    if (computed.toLowerCase() !== String(custodyAuth.configHash).toLowerCase() || prepared.caller.toLowerCase() !== String(custodyAuth.executor).toLowerCase() || keccak256(parsed.args[2]).toLowerCase() !== String(custodyAuth.tokenDataHash).toLowerCase() || parsed.args[4] === "0x") throw Error("Prepared custody configuration/caller/token data/signature differs");
  } else if (prepared.kind === "token-custody-activation") {
    method = "activatePlatformTokenCustody"; auth = namedTuple(parsed.args[0]); rebuilt = platformTokenCustodySigningPayload(BigInt(prepared.payload.domain.chainId ?? 0), target, auth as unknown as PlatformTokenCustodyAuthorization); if (parsed.args[1] === "0x") throw Error("Prepared activation signature is empty");
  } else throw Error("Unknown prepared PLATFORM write kind");
  if (parsed.name !== method || prepared.call.value !== expectedValue || !sameTuple(prepared.kind === "rights-registration" ? "tuple(bytes32 configHash,bytes32 declarationHash,bytes32 nonce,uint64 deadline)" : prepared.kind === "custody-registration" ? custodyTuple : tokenAuthorizationTuple, auth, prepared.payload.message) || !sameJSON(rebuilt, prepared.payload)) throw Error("Prepared call, wallet-visible payload or value differs from canonical reconstruction");
  const expectedDigest = call(target, prepared.kind === "rights-registration" ? "platformRightsCreationDigest" : prepared.kind === "custody-registration" ? "platformCustodyAcquisitionDigest" : "platformTokenCustodyDigest", [auth]);
  if (expectedDigest.data.toLowerCase() !== prepared.digestCall.data.toLowerCase()) throw Error("Prepared digest call differs from canonical authorization");
}
async function sourceInspect(provider: Pick<Provider, "call">, house: Address, source: PlatformSourceRead, config: PlatformAuctionConfiguration, originalMode: bigint, declaration: Hex, tokenId: bigint, expectedAssignment: Hex, blockTag: BlockTag): Promise<string[]> {
  address(source.resolver, "resolver"); address(source.artistRegistry, "artistRegistry");
  const [boundResolver] = await rpc(provider, house, auctionInterface, "revenueResolver", [], blockTag), [boundArtist] = await rpc(provider, house, auctionInterface, "artistRegistry", [], blockTag);
  if (String(boundResolver).toLowerCase() !== source.resolver.toLowerCase() || String(boundArtist).toLowerCase() !== source.artistRegistry.toLowerCase()) throw Error("Supplied source contracts differ from the house's immutable bindings");
  const [declared, currentDeclaration] = await rpc(provider, source.artistRegistry, artistInterface, "platformWorksDeclaration", [config.collectionId], blockTag);
  const [contest, claim] = await rpc(provider, source.artistRegistry, artistInterface, "platformWorksContest", [config.collectionId], blockTag);
  const [generation, approval] = await rpc(provider, source.artistRegistry, artistInterface, "platformWorksCorrection", [config.collectionId], blockTag);
  if (!declared || String(currentDeclaration).toLowerCase() !== declaration.toLowerCase() || (BigInt(String(contest)) !== 0n && BigInt(String(contest)) !== 2n) || (BigInt(String(contest)) === 0n ? String(claim).toLowerCase() !== ZERO32 : String(claim).toLowerCase() === ZERO32) || BigInt(String(generation)) !== 0n || String(approval).toLowerCase() !== ZERO32) throw Error("Current PLATFORM_WORKS declaration/contest/correction getters differ from reviewed authorization");
  const [resolved] = await rpc(provider, source.resolver, resolverInterface, "resolvePrimaryAssignment", [config.collectionId, tokenId, primarySale], blockTag) as readonly [Record<string, unknown>];
  const mode = Number(originalMode), wantedScope = mode === 8 || mode === 10 ? 1n : mode === 9 || mode === 11 ? 0n : 2n, wantedType = mode === 8 || mode === 9 || mode === 13 ? 2n : 1n;
  if (!resolved.exists || BigInt(String(resolved.scope)) !== wantedScope || BigInt(String(resolved.scopeId)) !== (wantedScope === 2n ? tokenId : wantedScope === 1n ? config.collectionId : 0n) || BigInt(String(resolved.assignmentType)) !== wantedType || String(resolved.assignmentHash).toLowerCase() !== expectedAssignment.toLowerCase()) throw Error("Current primary assignment getter differs from reviewed source family");
  return ["house resolver and Artist registry bindings match", "current declaration/contest/correction getters match", "current primary assignment source and hash match"];
}
export async function inspectPlatformRightsRegistration(provider: Pick<Provider, "getNetwork" | "call">, prepared: PreparedPlatformWrite<PlatformCreationAuthorization>, config: PlatformAuctionConfiguration, original: PlatformOriginalPolicy, source: PlatformSourceRead, options: { readonly blockTag: number }): Promise<PlatformInspection> {
  validateConfig(config, false); validateOriginal(original); const blockTag = concreteBlock(options?.blockTag); const checked = await baseInspect(provider, prepared, blockTag, "platformRightsCreationDigest");
  const parsed = auctionInterface.parseTransaction({ data: prepared.call.data }); if (!parsed || !sameTuple(configTuple, parsed.args[0], config) || !sameTuple(originalTuple, parsed.args[1], original)) throw Error("Prepared registration call differs from reviewed configuration/original policy");
  const [hash] = await rpc(provider, prepared.call.to, auctionInterface, "platformRightsConfigurationHash", [config, original, prepared.payload.message.declarationHash], blockTag);
  if (String(hash).toLowerCase() !== prepared.payload.message.configHash.toLowerCase()) throw Error("Canonical configuration getter differs from authorization"); checked.push("canonical configuration getter matches", ...await sourceInspect(provider, prepared.call.to, source, config, original.mode, prepared.payload.message.declarationHash, 0n, original.assignmentHash, blockTag));
  return Object.freeze({ blockTag, checked: Object.freeze(checked), unavailable: Object.freeze(["shared platform creation nonce has no public getter", "complete admission/runtime/template grammar and platform signature acceptance require exact write simulation", "numeric block pin has no reorg hash check"]), writeSimulationRequired: true });
}
export async function inspectPlatformCustodyRegistration(provider: Pick<Provider, "getNetwork" | "call">, prepared: PreparedPlatformWrite<PlatformCustodyAuthorization>, config: PlatformAuctionConfiguration, original: PlatformOriginalPolicy, source: PlatformSourceRead, options: { readonly blockTag: number }): Promise<PlatformInspection> {
  validateConfig(config, true); validateOriginal(original); const blockTag = concreteBlock(options?.blockTag); const checked = await baseInspect(provider, prepared, blockTag, "platformCustodyAcquisitionDigest");
  const parsed = auctionInterface.parseTransaction({ data: prepared.call.data }); if (!parsed || !sameTuple(configTuple, parsed.args[0], config) || !sameTuple(originalTuple, parsed.args[1], original)) throw Error("Prepared custody call differs from reviewed configuration/original policy");
  const [hash] = await rpc(provider, prepared.call.to, auctionInterface, "platformRightsConfigurationHash", [config, original, prepared.payload.message.declarationHash], blockTag);
  if (String(hash).toLowerCase() !== prepared.payload.message.configHash.toLowerCase()) throw Error("Canonical configuration getter differs from authorization"); checked.push("canonical configuration getter matches", ...await sourceInspect(provider, prepared.call.to, source, config, original.mode, prepared.payload.message.declarationHash, 0n, original.assignmentHash, blockTag));
  return Object.freeze({ blockTag, checked: Object.freeze(checked), unavailable: Object.freeze(["shared platform creation nonce and expected mint coordinates have no single public admission getter", "complete admission/runtime/template grammar, exact reveal fee and platform signature acceptance require exact write simulation", "numeric block pin has no reorg hash check"]), writeSimulationRequired: true });
}
export async function inspectPlatformTokenCustodyActivation(provider: Pick<Provider, "getNetwork" | "call">, prepared: PreparedPlatformWrite<PlatformTokenCustodyAuthorization>, config: PlatformAuctionConfiguration, source: PlatformSourceRead, options: { readonly blockTag: number }): Promise<PlatformInspection> {
  validateConfig(config, true); const blockTag = concreteBlock(options?.blockTag), a = prepared.payload.message, checked = await baseInspect(provider, prepared, blockTag, "platformTokenCustodyDigest");
  const [used] = await rpc(provider, prepared.call.to, auctionInterface, "platformTokenCustodyNonceUsed", [a.nonce], blockTag); if (used) throw Error("Platform token-custody nonce is already used");
  const [origin] = await rpc(provider, prepared.call.to, auctionInterface, "custodyOrigin", [a.auctionId], blockTag) as readonly [PlatformCustodyOrigin]; if (platformCustodyOriginHash(origin).toLowerCase() !== a.originHash.toLowerCase()) throw Error("Current custody origin differs from authorization");
  const [auction] = await rpc(provider, prepared.call.to, auctionInterface, "auction", [a.auctionId], blockTag) as readonly [Record<string, unknown>];
  const [endTime] = await rpc(provider, prepared.call.to, auctionInterface, "auctionDeadlines", [a.auctionId], blockTag);
  if (String(auction.configHash).toLowerCase() !== a.baseConfigHash.toLowerCase() || BigInt(String(auction.tokenId)) !== a.tokenId || BigInt(String(auction.status)) !== 1n || BigInt(String((auction.winner as Record<string, unknown>).bidIndex)) !== 0n || String((auction.config as Record<string, unknown>).poster).toLowerCase() !== prepared.caller.toLowerCase() || BigInt(String((auction.config as Record<string, unknown>).collectionId)) !== config.collectionId) throw Error("Current auction configuration, collection, token, status, bid state or original poster differs");
  const [storedDeclaration] = await rpc(provider, prepared.call.to, auctionInterface, "platformAuctionDeclaration", [auction.saleId], blockTag); if (String(storedDeclaration).toLowerCase() !== a.declarationHash.toLowerCase()) throw Error("Stored original platform declaration differs");
  checked.push("activation nonce is unused", "current custody origin hash matches", "auction config/token/status/pre-bid/original poster facts match", "stored auction declaration matches", `auction deadline read at pinned block (${String(endTime)})`, ...await sourceInspect(provider, prepared.call.to, source, config, a.rightsMode, a.declarationHash, a.tokenId, a.assignmentHash, blockTag));
  return Object.freeze({ blockTag, checked: Object.freeze(checked), unavailable: Object.freeze(["pause state, current timestamp comparison and full custody retention acceptance require exact write simulation", "complete admission/runtime/template grammar and platform signature acceptance require exact write simulation", "numeric block pin has no reorg hash check"]), writeSimulationRequired: true });
}
/** Exact target-level eth_call from the required caller. Success proves only this pinned RPC simulation. */
export async function simulatePreparedPlatformWrite(provider: Pick<Provider, "getNetwork" | "call">, prepared: PreparedPlatformWrite<object>, options: { readonly blockTag: number }): Promise<Hex> {
  const blockTag = concreteBlock(options?.blockTag); validatePreparedPacket(prepared); if ((await provider.getNetwork()).chainId !== BigInt(prepared.payload.domain.chainId ?? 0)) throw Error("RPC chain differs from platform signing domain");
  return await provider.call({ from: prepared.caller, ...prepared.call, blockTag }) as Hex;
}
