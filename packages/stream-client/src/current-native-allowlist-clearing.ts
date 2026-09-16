import {
  AbiCoder,
  Interface,
  ZeroAddress,
  getAddress,
  id,
  isHexString,
  keccak256,
} from "ethers";
import type { BlockTag, Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";
import {
  mintAllowlistResolverData,
  type MintAllowlistProof,
} from "./current-mint-gates.js";

export const NATIVE_ALLOWLIST_CLEARING_MAX_GROUPS = 16;

export interface NativeClearingSchedule {
  readonly startPrice: bigint;
  readonly restingPrice: bigint;
  readonly startTime: bigint;
  readonly endTime: bigint;
  readonly decayKind: bigint;
  readonly stepSeconds: bigint;
  readonly stepAmount: bigint;
}

export interface NativeAllowlistClearingConfig {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly schedule: NativeClearingSchedule;
  readonly maxSaleQuantity: bigint;
  readonly closesAt: bigint;
  readonly finalizationWindowSeconds: bigint;
  readonly absoluteEscapeDeadline: bigint;
  readonly primaryPolicyMode: bigint;
  readonly mintPolicyHash: Hex;
}

export interface NativeClearingAuthorization {
  readonly saleId: Hex;
  readonly saleConfigHash: Hex;
  readonly payer: Address;
  readonly executor: Address;
  readonly recipient: Address;
  readonly artist: Address;
  readonly tokenDataHash: Hex;
  readonly mintCommitment: Hex;
  readonly purchaseNonce: bigint;
  readonly executionNonce: bigint;
  readonly nonce: Hex;
  readonly deadline: bigint;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly unitPrice: bigint;
  readonly hasPriceOverride: boolean;
  readonly priceOverride: bigint;
  readonly windowPolicyHash: Hex;
  readonly maximumNominalFinalizeBy: bigint;
  readonly absoluteEscapeDeadline: bigint;
}

/** Counter IDs are unchecked caller labels. The contract validates positional proofs against live counter order. */
export interface NativeAllowlistClearingProofGroup {
  readonly counterId: Hex;
  readonly proof: MintAllowlistProof;
}

export interface NativeAllowlistClearingPurchaseInput {
  readonly tokenData: Hex;
  readonly platformSignature: Hex;
  readonly artistSignature: Hex;
  readonly maximumPaymentAllowance: bigint;
  readonly revealFeeAllowance: bigint;
  readonly proofGroups: readonly NativeAllowlistClearingProofGroup[];
}

export interface PreparedNativeAllowlistClearingRegistration {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly runtimeHash: Hex;
  readonly caller: Address;
  readonly expectedNonce: bigint;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly config: NativeAllowlistClearingConfig;
  readonly counterId: Hex;
  readonly saleId: Hex;
  readonly priceScheduleHash: Hex;
  readonly windowPolicyHash: Hex;
  readonly originalConfigHash: Hex;
  readonly configHash: Hex;
  readonly baselineProvenance: "caller-supplied-unverified-until-sale-record";
  readonly call: UnsignedCall;
}

export interface NativeAllowlistClearingSaleInspection {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly runtimeHash: Hex;
  readonly owner: Address;
  readonly entropyCoordinator: Address;
  readonly config: NativeAllowlistClearingConfig;
  readonly saleId: Hex;
  readonly saleNonce: bigint;
  readonly counterId: Hex;
  readonly configHash: Hex;
  readonly originalConfigHash: Hex;
  readonly priceScheduleHash: Hex;
  readonly windowPolicyHash: Hex;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly currentSchedulePrice: bigint;
  readonly nextPurchaseNonce: bigint;
  readonly revealFeePerTokenWei: bigint;
}

export interface NativeAllowlistClearingPurchaseResult {
  readonly purchaseId: Hex;
  readonly tokenId: bigint;
  readonly chargedAmount: bigint;
  readonly floorRevenue: bigint;
  readonly heldOverage: bigint;
  readonly revealFeeForwarded: bigint;
  readonly excessCredited: bigint;
  readonly executionId: Hex;
  readonly operationRoot: Hex;
  readonly operationId: Hex;
  readonly settlementKey: Hex;
  readonly escrowed: boolean;
}

export interface PreparedNativeAllowlistClearingPurchase {
  readonly caller: Address;
  readonly inspection: NativeAllowlistClearingSaleInspection;
  readonly authorization: NativeClearingAuthorization;
  readonly payload: SigningPayload<NativeClearingAuthorization>;
  readonly input: NativeAllowlistClearingPurchaseInput;
  readonly resolverData: Hex;
  readonly schedulePrice: bigint;
  readonly chargedAmount: bigint;
  readonly call: UnsignedCall;
  readonly simulation: NativeAllowlistClearingPurchaseResult;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}

export interface PreparedNativeClearingCall {
  readonly caller: Address;
  readonly intent: string;
  readonly call: UnsignedCall;
}

const coder = AbiCoder.defaultAbiCoder();
const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const MAX_BYTES = 4_194_304;
const scheduleTuple = "tuple(uint96 startPrice,uint96 restingPrice,uint64 startTime,uint64 endTime,uint8 decayKind,uint32 stepSeconds,uint96 stepAmount)";
const configTuple = `tuple(uint256 collectionId,bytes32 phaseId,${scheduleTuple} schedule,uint64 maxSaleQuantity,uint64 closesAt,uint64 finalizationWindowSeconds,uint64 absoluteEscapeDeadline,uint8 primaryPolicyMode,bytes32 mintPolicyHash)`;
const authorizationTuple = "tuple(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 purchaseNonce,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice,bool hasPriceOverride,uint256 priceOverride,bytes32 windowPolicyHash,uint64 maximumNominalFinalizeBy,uint64 absoluteEscapeDeadline)";
const purchaseTuple = `tuple(${authorizationTuple} authorization,bytes tokenData,bytes platformSignature,bytes artistSignature)`;
const resultTuple = "tuple(bytes32 purchaseId,uint256 tokenId,uint256 chargedAmount,uint256 floorRevenue,uint256 heldOverage,uint256 revealFeeForwarded,uint256 excessCredited,bytes32 executionId,bytes32 operationRoot,bytes32 operationId,bytes32 settlementKey,bool escrowed)";
const recordTuple = `tuple(${configTuple} config,uint256 saleNonce,bytes32 configHash,bytes32 priceScheduleHash,bytes32 windowPolicyHash,bytes32 expectedPrimaryPolicyHash,tuple(uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision) lifecycle,uint64 soldOutAt,uint64 earlyCloseAt,uint64 priceFixedAt,uint64 terminalAt,uint64 terminalToll,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash)`;
const supplementalResultTuple = "tuple(bytes32 candidateCommitment,bytes32 settlementKey,bytes32 purchaseId,bytes32 originalFloorSettlementKey,uint256 tokenId,bytes32 profileId,address wallet,uint256 amount,address executor,bytes32 executionId,bool escrowed,bytes32 originalOperationRoot,bytes32 originalOperationId,bytes32 originalExpectedPrimaryPolicyHash,bytes32 currentPrimaryPolicyHash,bool policyDrift)";
const clearingAbi = new Interface([
  `function registerAllowlistClearingSale(${configTuple},bytes32) returns (bytes32)`,
  "function allowlistPriceCounter(bytes32) view returns (bytes32)",
  "function owner() view returns (address)",
  "function nextSaleNonce() view returns (uint256)",
  "function saleIdFor(uint256,bytes32,uint256) view returns (bytes32)",
  `function saleRecord(bytes32) view returns (${recordTuple})`,
  "function currentPrice(bytes32) view returns (uint256)",
  "function nextPurchaseNonce(bytes32,address) view returns (uint256)",
  `function authorizationDigest(${authorizationTuple}) view returns (bytes32)`,
  "function eip712Domain() view returns (bytes1,string,string,uint256,address,bytes32,uint256[])",
  `function purchaseWithAllowlist(${purchaseTuple},bytes) payable returns (${resultTuple})`,
  "function refundableBalance(bytes32,address) view returns (uint256)",
  "function claimRefund(bytes32,address) returns (uint256)",
  "function fixClearingPrice(bytes32)",
  `function settlePurchaseSupplement(bytes32) returns (${supplementalResultTuple})`,
  "function synchronizeRebate(bytes32,address) returns (uint256)",
  "function entropyCoordinator() view returns (address)",
]);
const entropyAbi = new Interface([
  "function collectionRevealPolicy(uint256) view returns (tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei))",
]);
const domains = Object.freeze({
  sale: id("6529STREAM_SALE_V1") as Hex,
  schedule: id("6529STREAM_DUTCH_SCHEDULE_V1") as Hex,
  window: id("6529STREAM_CLEARING_WINDOW_POLICY_V1") as Hex,
  originalConfig: id("6529STREAM_NATIVE_CLEARING_CONFIG_V1") as Hex,
  allowlistConfig: id("6529STREAM_NATIVE_ALLOWLIST_CLEARING_CONFIG_V1") as Hex,
  pauseUnion: id("OBSERVED_GLOBAL_OR_LOCAL_PAUSE_UNION") as Hex,
  equality: id("ABSOLUTE_ESCAPE_PAUSED_EQUALITY_UNPAUSED_FINALIZE_EQUALITY") as Hex,
  purchase: id("6529STREAM_SALE_PURCHASE_V1") as Hex,
});
const authorizationFields = [
  { name: "saleId", type: "bytes32" },
  { name: "saleConfigHash", type: "bytes32" },
  { name: "payer", type: "address" },
  { name: "executor", type: "address" },
  { name: "recipient", type: "address" },
  { name: "artist", type: "address" },
  { name: "tokenDataHash", type: "bytes32" },
  { name: "mintCommitment", type: "bytes32" },
  { name: "purchaseNonce", type: "uint256" },
  { name: "executionNonce", type: "uint256" },
  { name: "nonce", type: "bytes32" },
  { name: "deadline", type: "uint64" },
  { name: "expectedPrimaryPolicyHash", type: "bytes32" },
  { name: "unitPrice", type: "uint256" },
  { name: "hasPriceOverride", type: "bool" },
  { name: "priceOverride", type: "uint256" },
  { name: "windowPolicyHash", type: "bytes32" },
  { name: "maximumNominalFinalizeBy", type: "uint64" },
  { name: "absoluteEscapeDeadline", type: "uint64" },
] as const;

function exactKeys(value: unknown, keys: readonly string[], name: string): asserts value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...keys].sort().join(",")) {
    throw new Error(`${name} contains missing or unknown properties`);
  }
}
function uint(value: unknown, bits: number, name: string, nonzero = false): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits) || (nonzero && value === 0n)) {
    throw new Error(`${name} must be ${nonzero ? "a positive" : "a nonnegative"} bigint fitting uint${bits}`);
  }
  return value;
}
function address(value: unknown, name: string, allowZero = false): Address {
  if (typeof value !== "string") throw new Error(`${name} must be an address string`);
  const normalized = getAddress(value) as Address;
  if (!allowZero && normalized === ZeroAddress) throw new Error(`${name} must be nonzero`);
  return normalized;
}
function bytes32(value: unknown, name: string, nonzero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (nonzero && value.toLowerCase() === ZERO32)) {
    throw new Error(`${name} must be ${nonzero ? "a nonzero" : "a"} bytes32`);
  }
  return value as Hex;
}
function bytes(value: unknown, name: string, maximum = MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value) || (value.length - 2) % 2 !== 0 || (value.length - 2) / 2 > maximum) {
    throw new Error(`${name} must contain complete hex bytes no longer than ${maximum} bytes`);
  }
  return value as Hex;
}
function same(left: unknown, right: string): boolean {
  return typeof left === "string" && left.toLowerCase() === right.toLowerCase();
}
function concreteBlock(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw new Error("A concrete nonnegative block number is required");
  return value;
}
function runtimeHash(value: unknown): Hex {
  if (typeof value !== "string" || !isHexString(value) || value === "0x") throw new Error("Clearing adapter has no runtime");
  return keccak256(value) as Hex;
}
function call(adapter: Address, method: string, args: readonly unknown[], value = 0n): UnsignedCall {
  return Object.freeze({ to: address(adapter, "adapter"), data: clearingAbi.encodeFunctionData(method, args) as Hex,
    value: uint(value, 256, "call value") });
}

function normalizeSchedule(value: NativeClearingSchedule): NativeClearingSchedule {
  exactKeys(value, ["startPrice", "restingPrice", "startTime", "endTime", "decayKind", "stepSeconds", "stepAmount"], "clearing schedule");
  const schedule = Object.freeze({
    startPrice: uint(value.startPrice, 96, "startPrice", true),
    restingPrice: uint(value.restingPrice, 96, "restingPrice", true),
    startTime: uint(value.startTime, 64, "startTime"),
    endTime: uint(value.endTime, 64, "endTime"),
    decayKind: uint(value.decayKind, 8, "decayKind"),
    stepSeconds: uint(value.stepSeconds, 32, "stepSeconds"),
    stepAmount: uint(value.stepAmount, 96, "stepAmount"),
  });
  if (schedule.startPrice < schedule.restingPrice || schedule.endTime <= schedule.startTime || schedule.decayKind > 1n) {
    throw new Error("Invalid positive clearing schedule");
  }
  if (schedule.decayKind === 0n && (schedule.stepSeconds !== 0n || schedule.stepAmount !== 0n)) {
    throw new Error("Linear clearing schedule cannot include step fields");
  }
  if (schedule.decayKind === 1n && (schedule.stepSeconds === 0n || schedule.stepAmount === 0n)) {
    throw new Error("Stepped clearing schedule requires positive step fields");
  }
  return schedule;
}

export function normalizeNativeAllowlistClearingConfig(value: NativeAllowlistClearingConfig): NativeAllowlistClearingConfig {
  exactKeys(value, ["collectionId", "phaseId", "schedule", "maxSaleQuantity", "closesAt", "finalizationWindowSeconds",
    "absoluteEscapeDeadline", "primaryPolicyMode", "mintPolicyHash"], "allowlist clearing config");
  const config = Object.freeze({
    collectionId: uint(value.collectionId, 256, "collectionId", true),
    phaseId: bytes32(value.phaseId, "phaseId", true),
    schedule: normalizeSchedule(value.schedule),
    maxSaleQuantity: uint(value.maxSaleQuantity, 64, "maxSaleQuantity", true),
    closesAt: uint(value.closesAt, 64, "closesAt"),
    finalizationWindowSeconds: uint(value.finalizationWindowSeconds, 64, "finalizationWindowSeconds", true),
    absoluteEscapeDeadline: uint(value.absoluteEscapeDeadline, 64, "absoluteEscapeDeadline"),
    primaryPolicyMode: uint(value.primaryPolicyMode, 8, "primaryPolicyMode"),
    mintPolicyHash: bytes32(value.mintPolicyHash, "mintPolicyHash", true),
  });
  const nominal = config.closesAt + config.finalizationWindowSeconds;
  if (config.closesAt < config.schedule.endTime || nominal >= 1n << 64n || nominal > config.absoluteEscapeDeadline
    || config.primaryPolicyMode !== 1n) throw new Error("Invalid clearing close, finalization or policy envelope");
  return config;
}

export function normalizeNativeAllowlistClearingAuthorization(value: NativeClearingAuthorization): NativeClearingAuthorization {
  exactKeys(value, authorizationFields.map(field => field.name), "clearing authorization");
  if (typeof value.hasPriceOverride !== "boolean") throw new Error("hasPriceOverride must be boolean");
  const authorization = Object.freeze({
    saleId: bytes32(value.saleId, "saleId", true), saleConfigHash: bytes32(value.saleConfigHash, "saleConfigHash", true),
    payer: address(value.payer, "payer"), executor: address(value.executor, "executor"), recipient: address(value.recipient, "recipient"),
    artist: address(value.artist, "artist"), tokenDataHash: bytes32(value.tokenDataHash, "tokenDataHash"),
    mintCommitment: bytes32(value.mintCommitment, "mintCommitment", true), purchaseNonce: uint(value.purchaseNonce, 256, "purchaseNonce", true),
    executionNonce: uint(value.executionNonce, 256, "executionNonce", true), nonce: bytes32(value.nonce, "nonce"),
    deadline: uint(value.deadline, 64, "deadline"), expectedPrimaryPolicyHash: bytes32(value.expectedPrimaryPolicyHash, "expectedPrimaryPolicyHash", true),
    unitPrice: uint(value.unitPrice, 256, "unitPrice"), hasPriceOverride: value.hasPriceOverride,
    priceOverride: uint(value.priceOverride, 256, "priceOverride"), windowPolicyHash: bytes32(value.windowPolicyHash, "windowPolicyHash", true),
    maximumNominalFinalizeBy: uint(value.maximumNominalFinalizeBy, 64, "maximumNominalFinalizeBy"),
    absoluteEscapeDeadline: uint(value.absoluteEscapeDeadline, 64, "authorization absoluteEscapeDeadline"),
  });
  if (!authorization.hasPriceOverride && authorization.priceOverride !== 0n) throw new Error("Disabled signed override must have price zero");
  return authorization;
}

function normalizeProof(value: MintAllowlistProof, name: string): MintAllowlistProof {
  exactKeys(value, ["maxCount", "hasPriceOverride", "priceOverride", "proof"], name);
  if (!Array.isArray(value.proof) || value.proof.length > 256) throw new Error(`${name}.proof exceeds the client boundary`);
  if (typeof value.hasPriceOverride !== "boolean") throw new Error(`${name}.hasPriceOverride must be boolean`);
  const priceOverride = uint(value.priceOverride, 256, `${name}.priceOverride`);
  if (!value.hasPriceOverride && priceOverride !== 0n) throw new Error("Disabled proof override must have price zero");
  return Object.freeze({ maxCount: uint(value.maxCount, 64, `${name}.maxCount`, true), hasPriceOverride: value.hasPriceOverride,
    priceOverride, proof: Object.freeze(value.proof.map((item, index) => bytes32(item, `${name}.proof[${index}]`))) });
}

function normalizeGroups(value: readonly NativeAllowlistClearingProofGroup[], selectedCounter?: Hex): readonly NativeAllowlistClearingProofGroup[] {
  if (!Array.isArray(value) || value.length === 0 || value.length > NATIVE_ALLOWLIST_CLEARING_MAX_GROUPS) {
    throw new Error("proofGroups must contain 1 through 16 ordered single-token groups");
  }
  const selected = selectedCounter === undefined ? undefined : bytes32(selectedCounter, "selected counter", true);
  const seen = new Set<string>();
  let selectedCount = 0;
  const groups = value.map((group, index) => {
    exactKeys(group, ["counterId", "proof"], `proofGroups[${index}]`);
    const counterId = bytes32(group.counterId, `proofGroups[${index}].counterId`, true);
    const key = counterId.toLowerCase();
    if (seen.has(key)) throw new Error("Proof counter labels must be unique");
    seen.add(key);
    const proof = normalizeProof(group.proof as MintAllowlistProof, `proofGroups[${index}].proof`);
    if (selected !== undefined && same(counterId, selected)) selectedCount++;
    else if (selected !== undefined && proof.hasPriceOverride) throw new Error("Only the selected counter may enable a price override");
    return Object.freeze({ counterId, proof });
  });
  if (selected !== undefined && selectedCount !== 1) throw new Error("Proof labels must contain the selected counter exactly once");
  return Object.freeze(groups);
}

export function nativeClearingSaleId(chainId: bigint, adapter: Address, collectionId: bigint, phaseId: Hex, nonce: bigint): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [domains.sale, uint(chainId, 256, "chainId", true), address(adapter, "adapter"), 4n,
      uint(collectionId, 256, "collectionId", true), bytes32(phaseId, "phaseId", true), uint(nonce, 256, "nonce", true)])) as Hex;
}

export function nativeClearingPurchaseId(chainId: bigint, adapter: Address, saleId: Hex, buyer: Address, nonce: bigint): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "uint256"],
    [domains.purchase, uint(chainId, 256, "chainId", true), address(adapter, "adapter"), bytes32(saleId, "saleId", true),
      address(buyer, "buyer"), uint(nonce, 256, "purchase nonce", true)])) as Hex;
}

export function nativeClearingScheduleHash(chainId: bigint, adapter: Address, saleId: Hex, schedule: NativeClearingSchedule): Hex {
  const value = normalizeSchedule(schedule);
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "uint96", "uint96", "uint64", "uint64", "uint8", "uint32", "uint96"],
    [domains.schedule, uint(chainId, 256, "chainId", true), address(adapter, "adapter"), bytes32(saleId, "saleId", true),
      value.startPrice, value.restingPrice, value.startTime, value.endTime, value.decayKind, value.stepSeconds, value.stepAmount])) as Hex;
}

export function nativeClearingWindowPolicyHash(config: NativeAllowlistClearingConfig): Hex {
  const value = normalizeNativeAllowlistClearingConfig(config);
  return keccak256(coder.encode(["bytes32", "uint64", "uint64", "uint64", "bytes32", "bytes32"],
    [domains.window, value.closesAt, value.finalizationWindowSeconds, value.absoluteEscapeDeadline, domains.pauseUnion, domains.equality])) as Hex;
}

export function nativeClearingOriginalConfigHash(chainId: bigint, adapter: Address, saleId: Hex,
  config: NativeAllowlistClearingConfig, expectedPrimaryPolicyHash: Hex): Hex {
  const value = normalizeNativeAllowlistClearingConfig(config);
  const schedule = nativeClearingScheduleHash(chainId, adapter, saleId, value.schedule);
  const windows = nativeClearingWindowPolicyHash(value);
  return keccak256(coder.encode(["bytes32", "bytes32", configTuple, "bytes32", "bytes32", "bytes32", "address"],
    [domains.originalConfig, bytes32(saleId, "saleId", true), value, schedule, windows,
      bytes32(expectedPrimaryPolicyHash, "expectedPrimaryPolicyHash", true), ZeroAddress])) as Hex;
}

export function nativeAllowlistClearingConfigHash(originalConfigHash: Hex, counterId: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "bytes32", "bytes32"], [domains.allowlistConfig,
    bytes32(originalConfigHash, "originalConfigHash", true), bytes32(counterId, "counterId", true)])) as Hex;
}

export function nativeClearingSchedulePrice(schedule: NativeClearingSchedule, timestamp: bigint): bigint {
  const value = normalizeSchedule(schedule), at = uint(timestamp, 256, "timestamp");
  if (at <= value.startTime) return value.startPrice;
  if (at >= value.endTime) return value.restingPrice;
  const elapsed = at - value.startTime, delta = value.startPrice - value.restingPrice;
  if (value.decayKind === 0n) return value.startPrice - delta * elapsed / (value.endTime - value.startTime);
  const reduction = elapsed / value.stepSeconds * value.stepAmount;
  return reduction >= delta ? value.restingPrice : value.startPrice - reduction;
}

export function nativeClearingAuthorizationTypedData(chainId: bigint, adapter: Address,
  authorization: NativeClearingAuthorization): SigningPayload<NativeClearingAuthorization> {
  return buildSigningPayload(uint(chainId, 256, "chainId", true), address(adapter, "adapter"),
    "6529StreamNativeClearingSale", "ClearingAuthorization", authorizationFields,
    normalizeNativeAllowlistClearingAuthorization(authorization));
}

export function nativeAllowlistClearingResolverData(groups: readonly NativeAllowlistClearingProofGroup[],
  selectedCounter: Hex, authorization: NativeClearingAuthorization): Hex {
  const normalizedAuthorization = normalizeNativeAllowlistClearingAuthorization(authorization);
  const normalizedGroups = normalizeGroups(groups, selectedCounter);
  const selected = normalizedGroups.find(group => same(group.counterId, selectedCounter))!;
  if (selected.proof.hasPriceOverride !== normalizedAuthorization.hasPriceOverride
    || selected.proof.priceOverride !== normalizedAuthorization.priceOverride) {
    throw new Error("Selected proof flag and full-width price must equal the signed authorization");
  }
  return mintAllowlistResolverData(normalizedGroups.map(group => [group.proof]));
}

function resultConfig(value: any): NativeAllowlistClearingConfig {
  return normalizeNativeAllowlistClearingConfig({ collectionId: value.collectionId, phaseId: value.phaseId,
    schedule: { startPrice: value.schedule.startPrice, restingPrice: value.schedule.restingPrice, startTime: value.schedule.startTime,
      endTime: value.schedule.endTime, decayKind: value.schedule.decayKind, stepSeconds: value.schedule.stepSeconds, stepAmount: value.schedule.stepAmount },
    maxSaleQuantity: value.maxSaleQuantity, closesAt: value.closesAt, finalizationWindowSeconds: value.finalizationWindowSeconds,
    absoluteEscapeDeadline: value.absoluteEscapeDeadline, primaryPolicyMode: value.primaryPolicyMode, mintPolicyHash: value.mintPolicyHash });
}
function sameConfig(left: NativeAllowlistClearingConfig, right: NativeAllowlistClearingConfig): boolean {
  return JSON.stringify(left, (_, item) => typeof item === "bigint" ? item.toString() : item)
    === JSON.stringify(right, (_, item) => typeof item === "bigint" ? item.toString() : item);
}
function decodePurchaseResult(value: any): NativeAllowlistClearingPurchaseResult {
  return Object.freeze({ purchaseId: bytes32(value.purchaseId, "purchaseId", true), tokenId: uint(value.tokenId, 256, "tokenId", true),
    chargedAmount: uint(value.chargedAmount, 256, "chargedAmount"), floorRevenue: uint(value.floorRevenue, 256, "floorRevenue"),
    heldOverage: uint(value.heldOverage, 256, "heldOverage"), revealFeeForwarded: uint(value.revealFeeForwarded, 256, "revealFeeForwarded"),
    excessCredited: uint(value.excessCredited, 256, "excessCredited"), executionId: bytes32(value.executionId, "executionId", true),
    operationRoot: bytes32(value.operationRoot, "operationRoot", true), operationId: bytes32(value.operationId, "operationId", true),
    settlementKey: bytes32(value.settlementKey, "settlementKey", true), escrowed: Boolean(value.escrowed) });
}

export class CurrentNativeAllowlistClearingClient {
  readonly chainId: bigint;
  readonly adapter: Address;

  constructor(chainId: bigint, adapter: Address) {
    this.chainId = uint(chainId, 256, "chainId", true);
    this.adapter = address(adapter, "adapter");
    Object.freeze(this);
  }

  async #block(provider: Pick<Provider, "getBlock">, tag: BlockTag): Promise<{ number: number; hash: Hex; timestamp: bigint }> {
    const block = await provider.getBlock(tag);
    if (!block?.hash) throw new Error("Pinned clearing block is unavailable");
    return { number: concreteBlock(block.number), hash: bytes32(block.hash, "block hash", true), timestamp: BigInt(block.timestamp) };
  }

  async #read(provider: Pick<Provider, "call">, target: Address, iface: Interface, method: string,
    args: readonly unknown[], blockTag: number): Promise<any> {
    const data = iface.encodeFunctionData(method, args);
    const raw = await provider.call({ to: target, data, blockTag });
    if (typeof raw !== "string" || !isHexString(raw) || (raw.length - 2) % 2 !== 0) throw new Error(`Malformed ${method} return`);
    const decoded = iface.decodeFunctionResult(method, raw);
    if (!same(iface.encodeFunctionResult(method, decoded), raw)) throw new Error(`Noncanonical ${method} return`);
    return decoded;
  }

  async prepareRegistration(
    provider: Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">,
    configInput: NativeAllowlistClearingConfig,
    counterIdInput: Hex,
    expectedPrimaryPolicyHashInput: Hex,
    callerInput: Address,
    blockTag: BlockTag = "latest",
  ): Promise<PreparedNativeAllowlistClearingRegistration> {
    const config = normalizeNativeAllowlistClearingConfig(configInput);
    const counterId = bytes32(counterIdInput, "counterId", true);
    const expectedPrimaryPolicyHash = bytes32(
      expectedPrimaryPolicyHashInput,
      "expectedPrimaryPolicyHash",
      true,
    );
    const caller = address(callerInput, "registration caller");
    const block = await this.#block(provider, blockTag);
    const at = block.number;
    if ((await provider.getNetwork()).chainId !== this.chainId) {
      throw new Error("RPC chain differs from clearing client");
    }
    const observedRuntimeHash = runtimeHash(await provider.getCode(this.adapter, at));
    const [owner, nonce] = await Promise.all([
      this.#read(provider, this.adapter, clearingAbi, "owner", [], at),
      this.#read(provider, this.adapter, clearingAbi, "nextSaleNonce", [], at),
    ]);
    if (!same(owner[0], caller)) {
      throw new Error("Registration caller is not the current adapter owner");
    }
    const expectedNonce = uint(nonce[0], 256, "nextSaleNonce", true);
    const saleId = nativeClearingSaleId(
      this.chainId,
      this.adapter,
      config.collectionId,
      config.phaseId,
      expectedNonce,
    );
    const [canonical] = await this.#read(
      provider,
      this.adapter,
      clearingAbi,
      "saleIdFor",
      [config.collectionId, config.phaseId, expectedNonce],
      at,
    );
    if (!same(canonical, saleId)) {
      throw new Error("Canonical clearing sale ID differs from local recomputation");
    }
    const priceScheduleHash = nativeClearingScheduleHash(
      this.chainId,
      this.adapter,
      saleId,
      config.schedule,
    );
    const windowPolicyHash = nativeClearingWindowPolicyHash(config);
    const originalConfigHash = nativeClearingOriginalConfigHash(
      this.chainId,
      this.adapter,
      saleId,
      config,
      expectedPrimaryPolicyHash,
    );
    const configHash = nativeAllowlistClearingConfigHash(originalConfigHash, counterId);
    const unsigned = call(this.adapter, "registerAllowlistClearingSale", [config, counterId]);
    const simulated = await provider.call({ ...unsigned, from: caller, blockTag: at });
    const decoded = clearingAbi.decodeFunctionResult("registerAllowlistClearingSale", simulated);
    const canonicalSimulation = clearingAbi.encodeFunctionResult(
      "registerAllowlistClearingSale",
      decoded,
    );
    if (!same(canonicalSimulation, simulated) || !same(decoded[0], saleId)) {
      throw new Error("Registration simulation returned a noncanonical or unexpected sale ID");
    }
    if (!same((await provider.getBlock(at))?.hash ?? "", block.hash)) {
      throw new Error("Pinned registration block changed");
    }
    return Object.freeze({
      chainId: this.chainId,
      adapter: this.adapter,
      blockNumber: at,
      blockHash: block.hash,
      runtimeHash: observedRuntimeHash,
      caller,
      expectedNonce,
      expectedPrimaryPolicyHash,
      config,
      counterId,
      saleId,
      priceScheduleHash,
      windowPolicyHash,
      originalConfigHash,
      configHash,
      baselineProvenance: "caller-supplied-unverified-until-sale-record",
      call: unsigned,
    });
  }

  async inspectSale(
    provider: Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">,
    saleIdInput: Hex,
    payerInput: Address,
    blockTag: BlockTag = "latest",
  ): Promise<NativeAllowlistClearingSaleInspection> {
    const saleId = bytes32(saleIdInput, "saleId", true);
    const payer = address(payerInput, "payer");
    const block = await this.#block(provider, blockTag);
    const at = block.number;
    if ((await provider.getNetwork()).chainId !== this.chainId) {
      throw new Error("RPC chain differs from clearing client");
    }
    const runtime = runtimeHash(await provider.getCode(this.adapter, at));
    const reads = await Promise.all([
      this.#read(provider, this.adapter, clearingAbi, "saleRecord", [saleId], at),
      this.#read(provider, this.adapter, clearingAbi, "allowlistPriceCounter", [saleId], at),
      this.#read(provider, this.adapter, clearingAbi, "currentPrice", [saleId], at),
      this.#read(provider, this.adapter, clearingAbi, "nextPurchaseNonce", [saleId, payer], at),
      this.#read(provider, this.adapter, clearingAbi, "owner", [], at),
      this.#read(provider, this.adapter, clearingAbi, "entropyCoordinator", [], at),
    ]);
    const [recordResult, counterResult, priceResult, nonceResult, ownerResult, entropyResult] = reads;
    const record = recordResult[0];
    const saleNonce = uint(record.saleNonce, 256, "saleNonce", true);
    const config = resultConfig(record.config);
    const counterId = bytes32(counterResult[0], "allowlist counter", true);
    const expectedSaleId = nativeClearingSaleId(
      this.chainId,
      this.adapter,
      config.collectionId,
      config.phaseId,
      saleNonce,
    );
    const [canonicalId] = await this.#read(
      provider,
      this.adapter,
      clearingAbi,
      "saleIdFor",
      [config.collectionId, config.phaseId, saleNonce],
      at,
    );
    if (!same(saleId, expectedSaleId) || !same(canonicalId, expectedSaleId)) {
      throw new Error("Stored clearing sale identity differs");
    }
    const expectedPrimaryPolicyHash = bytes32(
      record.expectedPrimaryPolicyHash,
      "stored expectedPrimaryPolicyHash",
      true,
    );
    const priceScheduleHash = nativeClearingScheduleHash(
      this.chainId,
      this.adapter,
      saleId,
      config.schedule,
    );
    const windowPolicyHash = nativeClearingWindowPolicyHash(config);
    const originalConfigHash = nativeClearingOriginalConfigHash(
      this.chainId,
      this.adapter,
      saleId,
      config,
      expectedPrimaryPolicyHash,
    );
    const configHash = nativeAllowlistClearingConfigHash(originalConfigHash, counterId);
    const hashMismatch = !same(record.priceScheduleHash, priceScheduleHash)
      || !same(record.windowPolicyHash, windowPolicyHash)
      || !same(record.configHash, configHash);
    if (hashMismatch) {
      throw new Error("Stored clearing hash commitments differ from reconstruction");
    }
    const currentSchedulePrice = uint(priceResult[0], 256, "currentPrice", true);
    if (currentSchedulePrice !== nativeClearingSchedulePrice(config.schedule, block.timestamp)) {
      throw new Error("Current schedule price differs from pinned timestamp");
    }
    const entropyCoordinator = address(entropyResult[0], "entropy coordinator");
    const revealResult = await this.#read(
      provider,
      entropyCoordinator,
      entropyAbi,
      "collectionRevealPolicy",
      [config.collectionId],
      at,
    );
    const reveal = revealResult[0];
    if (reveal.declared !== true || reveal.requestMode > 1n) {
      throw new Error("Missing or unsupported reveal policy");
    }
    if (!same((await provider.getBlock(at))?.hash ?? "", block.hash)) {
      throw new Error("Pinned sale inspection block changed");
    }
    return Object.freeze({
      chainId: this.chainId,
      adapter: this.adapter,
      blockNumber: at,
      blockHash: block.hash,
      runtimeHash: runtime,
      owner: address(ownerResult[0], "adapter owner", true),
      entropyCoordinator,
      config,
      saleId,
      saleNonce,
      counterId,
      configHash,
      originalConfigHash,
      priceScheduleHash,
      windowPolicyHash,
      expectedPrimaryPolicyHash,
      currentSchedulePrice,
      nextPurchaseNonce: uint(nonceResult[0], 256, "nextPurchaseNonce", true),
      revealFeePerTokenWei: uint(
        reveal.revealFeePerTokenWei,
        256,
        "revealFeePerTokenWei",
      ),
    });
  }

  async preparePurchase(
    provider: Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">,
    authorizationInput: NativeClearingAuthorization,
    inputValue: NativeAllowlistClearingPurchaseInput,
    blockTag: BlockTag = "latest",
  ): Promise<PreparedNativeAllowlistClearingPurchase> {
    const authorization = normalizeNativeAllowlistClearingAuthorization(authorizationInput);
    exactKeys(
      inputValue,
      [
        "tokenData",
        "platformSignature",
        "artistSignature",
        "maximumPaymentAllowance",
        "revealFeeAllowance",
        "proofGroups",
      ],
      "clearing purchase input",
    );
    const input = Object.freeze({
      tokenData: bytes(inputValue.tokenData, "tokenData"),
      platformSignature: bytes(inputValue.platformSignature, "platformSignature", 65_536),
      artistSignature: bytes(inputValue.artistSignature, "artistSignature", 65_536),
      maximumPaymentAllowance: uint(
        inputValue.maximumPaymentAllowance,
        256,
        "maximumPaymentAllowance",
      ),
      revealFeeAllowance: uint(inputValue.revealFeeAllowance, 256, "revealFeeAllowance"),
      proofGroups: normalizeGroups(inputValue.proofGroups),
    });
    if (!same(authorization.payer, authorization.executor)) {
      throw new Error("Clearing payer, executor and actual caller must match");
    }
    if (!same(authorization.tokenDataHash, keccak256(input.tokenData))) {
      throw new Error("Token data differs from signed hash");
    }
    const inspection = await this.inspectSale(
      provider,
      authorization.saleId,
      authorization.payer,
      blockTag,
    );
    const groups = normalizeGroups(input.proofGroups, inspection.counterId);
    const resolverData = nativeAllowlistClearingResolverData(
      groups,
      inspection.counterId,
      authorization,
    );
    const immutableMismatch = !same(authorization.saleConfigHash, inspection.configHash)
      || !same(authorization.windowPolicyHash, inspection.windowPolicyHash)
      || authorization.purchaseNonce !== inspection.nextPurchaseNonce
      || authorization.absoluteEscapeDeadline !== inspection.config.absoluteEscapeDeadline
      || authorization.maximumNominalFinalizeBy
        < inspection.config.closesAt + inspection.config.finalizationWindowSeconds;
    if (immutableMismatch) {
      throw new Error("Authorization differs from the current immutable sale or purchase window");
    }
    const belowFloor = authorization.hasPriceOverride
      && authorization.priceOverride < inspection.config.schedule.restingPrice;
    if (belowFloor) {
      throw new Error("Signed allowlist ceiling is below the positive resting floor");
    }
    const useOverride = authorization.hasPriceOverride
      && authorization.priceOverride < inspection.currentSchedulePrice;
    const chargedAmount = useOverride
      ? authorization.priceOverride
      : inspection.currentSchedulePrice;
    if (authorization.unitPrice < chargedAmount) {
      throw new Error("Signed maximum is below the pinned charged amount");
    }
    if (input.revealFeeAllowance < inspection.revealFeePerTokenWei) {
      throw new Error("Reveal fee allowance is below the pinned fee");
    }
    const value = input.maximumPaymentAllowance + input.revealFeeAllowance;
    if (value >= 1n << 256n) {
      throw new Error("Combined purchase and reveal allowance overflows uint256");
    }
    if (value - inspection.revealFeePerTokenWei < chargedAmount) {
      throw new Error("Combined value after the live reveal fee is below the pinned charged amount");
    }
    const payload = nativeClearingAuthorizationTypedData(
      this.chainId,
      this.adapter,
      authorization,
    );
    const at = inspection.blockNumber;
    const [digest, domain] = await Promise.all([
      this.#read(provider, this.adapter, clearingAbi, "authorizationDigest", [authorization], at),
      this.#read(provider, this.adapter, clearingAbi, "eip712Domain", [], at),
    ]);
    if (!same(digest[0], payload.digest)) {
      throw new Error("Current authorization digest differs from signing payload");
    }
    const domainMismatch = domain[0] !== "0x0f"
      || domain[1] !== "6529StreamNativeClearingSale"
      || domain[2] !== "1"
      || domain[3] !== this.chainId
      || !same(domain[4], this.adapter)
      || !same(domain[5], ZERO32)
      || (domain[6] as readonly unknown[]).length !== 0;
    if (domainMismatch) {
      throw new Error("Current EIP-712 domain differs from the original clearing domain");
    }
    const execution = Object.freeze({
      authorization,
      tokenData: input.tokenData,
      platformSignature: input.platformSignature,
      artistSignature: input.artistSignature,
    });
    const unsigned = call(this.adapter, "purchaseWithAllowlist", [execution, resolverData], value);
    const raw = await provider.call({ ...unsigned, from: authorization.payer, blockTag: at });
    const decoded = clearingAbi.decodeFunctionResult("purchaseWithAllowlist", raw);
    const canonicalResult = clearingAbi.encodeFunctionResult("purchaseWithAllowlist", decoded);
    if (!same(canonicalResult, raw)) {
      throw new Error("Noncanonical purchase simulation result");
    }
    const simulation = decodePurchaseResult(decoded[0]);
    const expectedPurchaseId = nativeClearingPurchaseId(
      this.chainId,
      this.adapter,
      authorization.saleId,
      authorization.payer,
      authorization.purchaseNonce,
    );
    const simulationMismatch = simulation.chargedAmount !== chargedAmount
      || simulation.revealFeeForwarded !== inspection.revealFeePerTokenWei
      || simulation.excessCredited !== value - chargedAmount - inspection.revealFeePerTokenWei
      || !same(simulation.purchaseId, expectedPurchaseId);
    if (simulationMismatch) {
      throw new Error("Purchase simulation differs from pinned price, fee or identity");
    }
    if (!same((await provider.getBlock(at))?.hash ?? "", inspection.blockHash)) {
      throw new Error("Pinned purchase simulation block changed");
    }
    return Object.freeze({
      caller: authorization.payer,
      inspection,
      authorization,
      payload,
      input: Object.freeze({ ...input, proofGroups: groups }),
      resolverData,
      schedulePrice: inspection.currentSchedulePrice,
      chargedAmount,
      call: unsigned,
      simulation,
      checked: Object.freeze([
        "stored sale and wrapped hash commitments",
        "original EIP-712 digest and domain",
        "same-leaf full-width price equality",
        "current schedule price, nonce, window and reveal fee",
        "sender-aware payable proof/signature/current-state simulation",
      ]),
      limitations: Object.freeze([
        "counter IDs are unchecked caller labels; the simulation validates positional witnesses against live order",
        "the observed runtime hash is not compared with a canonical deployment hash",
        "inspection does not reserve state or prove later inclusion, Safe execution, supplemental settlement or refund completion",
      ]),
    });
  }

  async readRefund(
    provider: Pick<Provider, "getNetwork" | "call">,
    saleIdInput: Hex,
    accountInput: Address,
    blockTag: BlockTag = "latest",
  ): Promise<bigint> {
    const saleId = bytes32(saleIdInput, "saleId", true);
    const account = address(accountInput, "refund account");
    if ((await provider.getNetwork()).chainId !== this.chainId) {
      throw new Error("RPC chain differs from clearing client");
    }
    const data = clearingAbi.encodeFunctionData("refundableBalance", [saleId, account]);
    const raw = await provider.call({ to: this.adapter, data, blockTag });
    const decoded = clearingAbi.decodeFunctionResult("refundableBalance", raw);
    if (!same(clearingAbi.encodeFunctionResult("refundableBalance", decoded), raw)) {
      throw new Error("Noncanonical refundableBalance return");
    }
    return uint(decoded[0], 256, "refundableBalance");
  }

  claimRefund(saleId: Hex, creditedCaller: Address, recipient: Address): PreparedNativeClearingCall {
    const caller = address(creditedCaller, "credited caller");
    const destination = address(recipient, "refund recipient");
    if (same(destination, this.adapter)) {
      throw new Error("Refund recipient cannot be the clearing adapter");
    }
    return Object.freeze({
      caller,
      intent: "Credited payer claims currently owed clearing refund without new sale admission",
      call: call(this.adapter, "claimRefund", [
        bytes32(saleId, "saleId", true),
        destination,
      ]),
    });
  }

  fixClearingPrice(saleId: Hex, caller: Address): PreparedNativeClearingCall {
    return Object.freeze({
      caller: address(caller, "keeper"),
      intent: "Permissionless price fixing at the immutable schedule reference",
      call: call(this.adapter, "fixClearingPrice", [bytes32(saleId, "saleId", true)]),
    });
  }

  settlePurchaseSupplement(purchaseId: Hex, caller: Address): PreparedNativeClearingCall {
    return Object.freeze({
      caller: address(caller, "keeper"),
      intent: "Permissionless original supplemental financial-leg settlement",
      call: call(this.adapter, "settlePurchaseSupplement", [
        bytes32(purchaseId, "purchaseId", true),
      ]),
    });
  }

  synchronizeRebate(saleId: Hex, payer: Address, caller: Address): PreparedNativeClearingCall {
    return Object.freeze({
      caller: address(caller, "keeper"),
      intent: "Permissionless rebate event synchronization; entitlement exists independently",
      call: call(this.adapter, "synchronizeRebate", [
        bytes32(saleId, "saleId", true),
        address(payer, "payer"),
      ]),
    });
  }
}
