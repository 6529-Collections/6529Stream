import {
  AbiCoder,
  Interface,
  ZeroAddress,
  getAddress,
  id,
  isHexString,
  keccak256,
} from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";
import { mintAllowlistResolverData } from "./current-mint-gates.js";
import type { MintAllowlistProof } from "./current-mint-gates.js";

export const NATIVE_ALLOWLIST_DUTCH_MAX_GROUPS = 16;

export interface NativeDutchPriceSchedule {
  readonly startPrice: bigint;
  readonly restingPrice: bigint;
  readonly startTime: bigint;
  readonly endTime: bigint;
  readonly decayKind: bigint;
  readonly stepSeconds: bigint;
  readonly stepAmount: bigint;
}

export interface NativeAllowlistDutchConfig {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly schedule: NativeDutchPriceSchedule;
  readonly maxSaleQuantity: bigint;
  readonly closesAt: bigint;
  readonly declaredFree: boolean;
  readonly mintPolicyHash: Hex;
}

export interface NativeDutchRegistrationHashFacts {
  readonly expectedPrimaryPolicyHash: Hex;
  readonly primaryAssignmentHash: Hex;
}

export interface NativeDutchAuthorization {
  readonly saleId: Hex;
  readonly saleConfigHash: Hex;
  readonly payer: Address;
  readonly executor: Address;
  readonly recipient: Address;
  readonly artist: Address;
  readonly tokenDataHash: Hex;
  readonly mintCommitment: Hex;
  readonly executionNonce: bigint;
  readonly nonce: Hex;
  readonly deadline: bigint;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly unitPrice: bigint;
}

/** Counter IDs are unchecked caller labels. The payable simulation validates witness positions. */
export interface NativeAllowlistDutchProofGroup {
  readonly counterId: Hex;
  readonly proof: MintAllowlistProof;
}

export interface NativeAllowlistDutchCharge {
  readonly overridden: boolean;
  readonly schedulePrice: bigint;
  readonly chargedAmount: bigint;
}

export interface PreparedNativeAllowlistDutchRegistration {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly expectedNonce: bigint;
  readonly config: NativeAllowlistDutchConfig;
  readonly counterId: Hex;
  readonly hashFacts: NativeDutchRegistrationHashFacts;
  readonly saleId: Hex;
  readonly scheduleHash: Hex;
  readonly originalConfigHash: Hex;
  readonly configHash: Hex;
  readonly expectedNonceMustBeLiveChecked: true;
  readonly expectedHashFactsRequirePostRegistrationReadback: true;
  readonly call: UnsignedCall;
}

export interface NativeAllowlistDutchPurchaseInput {
  readonly tokenData: Hex;
  readonly platformSignature: Hex;
  readonly artistSignature: Hex;
  readonly saleFundingMaximum: bigint;
  readonly revealFeeAllowance: bigint;
  readonly proofGroups: readonly NativeAllowlistDutchProofGroup[];
}

export interface PreparedNativeAllowlistDutchPurchase {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly config: NativeAllowlistDutchConfig;
  readonly counterId: Hex;
  readonly hashFacts: NativeDutchRegistrationHashFacts;
  readonly authorization: NativeDutchAuthorization;
  readonly input: NativeAllowlistDutchPurchaseInput;
  readonly payload: SigningPayload<NativeDutchAuthorization>;
  readonly resolverData: Hex;
  readonly call: UnsignedCall;
}

export interface NativeAllowlistDutchPurchaseResult {
  readonly revenueOutcome: bigint;
  readonly tokenId: bigint;
  readonly chargedAmount: bigint;
  readonly revealFeeForwarded: bigint;
  readonly excessCredited: bigint;
  readonly executionId: Hex;
  readonly operationRoot: Hex;
  readonly operationId: Hex;
  readonly settlementKey: Hex;
  readonly escrowed: boolean;
}

export interface NativeAllowlistDutchRecordInspection {
  readonly saleNonce: bigint;
  readonly configHash: Hex;
  readonly scheduleHash: Hex;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly primaryAssignmentHash: Hex;
  readonly mintedQuantity: bigint;
  readonly closed: boolean;
  readonly paused: boolean;
}

export interface NativeAllowlistDutchPurchaseInspection {
  readonly prepared: PreparedNativeAllowlistDutchPurchase;
  readonly record: NativeAllowlistDutchRecordInspection;
  readonly core: Address;
  readonly mintManager: Address;
  readonly entropyCoordinator: Address;
  readonly currentSchedulePrice: bigint;
  readonly expectedCharge: NativeAllowlistDutchCharge;
  readonly revealFeePerTokenWei: bigint;
  readonly effectiveSaleFundingMaximum: bigint;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}

export interface PreparedNativeDutchRefund {
  readonly adapter: Address;
  readonly saleId: Hex;
  readonly caller: Address;
  readonly recipient: Address;
  readonly call: UnsignedCall;
}

const coder = AbiCoder.defaultAbiCoder();
const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const MAX_BYTES = 4_194_304;
const scheduleTuple = "tuple(uint96 startPrice,uint96 restingPrice,uint64 startTime,uint64 endTime,uint8 decayKind,uint32 stepSeconds,uint96 stepAmount)";
const configTuple = `tuple(uint256 collectionId,bytes32 phaseId,${scheduleTuple} schedule,uint64 maxSaleQuantity,uint64 closesAt,bool declaredFree,bytes32 mintPolicyHash)`;
const authorizationTuple = "tuple(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice)";
const purchaseTuple = `tuple(${authorizationTuple} authorization,bytes tokenData,bytes platformSignature,bytes artistSignature)`;
const lifecycleTuple = "tuple(uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision)";
const recordTuple = `tuple(${configTuple} config,uint256 saleNonce,bytes32 configHash,bytes32 priceScheduleHash,bytes32 expectedPrimaryPolicyHash,bytes32 primaryAssignmentHash,${lifecycleTuple} lifecycle,uint64 mintedQuantity,bool closed,bool paused)`;
const resultTuple = "tuple(uint8 revenueOutcome,uint256 tokenId,uint256 chargedAmount,uint256 revealFeeForwarded,uint256 excessCredited,bytes32 executionId,bytes32 operationRoot,bytes32 operationId,bytes32 settlementKey,bool escrowed)";
const dutchAbi = new Interface([
  `function registerAllowlistDutchSale(${configTuple},bytes32) returns (bytes32)`,
  "function allowlistPriceCounter(bytes32) view returns (bytes32)",
  `function purchaseWithAllowlist(${purchaseTuple},bytes) payable returns (${resultTuple})`,
  "function saleIdFor(uint256,bytes32,uint256) view returns (bytes32)",
  `function saleRecord(bytes32) view returns (${recordTuple})`,
  "function currentPrice(bytes32) view returns (uint256)",
  `function authorizationDigest(${authorizationTuple}) view returns (bytes32)`,
  "function nextSaleNonce() view returns (uint256)",
  "function owner() view returns (address)",
  "function core() view returns (address)",
  "function mintManager() view returns (address)",
  "function entropyCoordinator() view returns (address)",
  "function paused() view returns (bool)",
  "function refundableBalance(bytes32,address) view returns (uint256)",
  "function claimRefund(bytes32,address)",
]);
const entropyAbi = new Interface([
  "function collectionRevealPolicy(uint256) view returns (tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei))",
]);
const domains = Object.freeze({
  sale: id("6529STREAM_SALE_V1") as Hex,
  schedule: id("6529STREAM_DUTCH_SCHEDULE_V1") as Hex,
  originalConfig: id("6529STREAM_NATIVE_DUTCH_CONFIG_V1") as Hex,
  allowlistConfig: id("6529STREAM_NATIVE_ALLOWLIST_DUTCH_CONFIG_V1") as Hex,
});
const authorizationFields = Object.freeze([
  { name: "saleId", type: "bytes32" },
  { name: "saleConfigHash", type: "bytes32" },
  { name: "payer", type: "address" },
  { name: "executor", type: "address" },
  { name: "recipient", type: "address" },
  { name: "artist", type: "address" },
  { name: "tokenDataHash", type: "bytes32" },
  { name: "mintCommitment", type: "bytes32" },
  { name: "executionNonce", type: "uint256" },
  { name: "nonce", type: "bytes32" },
  { name: "deadline", type: "uint64" },
  { name: "expectedPrimaryPolicyHash", type: "bytes32" },
  { name: "unitPrice", type: "uint256" },
]);
const purchaseChecked = Object.freeze([
  "RPC chain and exact stored sale record",
  "allowlist counter and canonical sale ID",
  "current Dutch schedule price and authorization digest",
  "declared reveal policy and attached funding maximum",
  "configured Core, Mint Manager and entropy coordinator addresses",
]);
const limitations = Object.freeze([
  "numeric block pin has no reorg hash check",
  "proof counter IDs are unchecked caller metadata; only exact payable simulation validates positional witnesses against live Manager state",
  "read-only inspection does not validate signatures, artist consent, live module admission or runtime code identity",
  "Safe threshold authority, inclusion-time state and future transaction acceptance remain outside this client",
]);

function exactKeys(
  value: unknown,
  keys: readonly string[],
  name: string,
): asserts value is Record<string, unknown> {
  if (
    value === null
    || typeof value !== "object"
    || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...keys].sort().join(",")
  ) {
    throw new Error(`${name} contains missing or unknown properties`);
  }
}

function uint(value: unknown, bits: number, name: string, nonzero = false): bigint {
  if (
    typeof value !== "bigint"
    || value < 0n
    || value >= 1n << BigInt(bits)
    || (nonzero && value === 0n)
  ) {
    throw new Error(
      `${name} must be ${nonzero ? "a positive" : "a nonnegative"} bigint fitting uint${bits}`,
    );
  }
  return value;
}

function address(value: unknown, name: string): Address {
  if (typeof value !== "string") {
    throw new Error(`${name} must be an address string`);
  }
  const output = getAddress(value) as Address;
  if (output === ZeroAddress) {
    throw new Error(`${name} must be nonzero`);
  }
  return output;
}

function bytes32(value: unknown, name: string, nonzero = false): Hex {
  if (
    typeof value !== "string"
    || !isHexString(value, 32)
    || (nonzero && value.toLowerCase() === ZERO32)
  ) {
    throw new Error(`${name} must be ${nonzero ? "a nonzero" : "a"} bytes32`);
  }
  return value as Hex;
}

function bytes(value: unknown, name: string): Hex {
  if (
    typeof value !== "string"
    || !isHexString(value, true)
    || (value.length - 2) / 2 > MAX_BYTES
  ) {
    throw new Error(`${name} must be complete bounded hex bytes`);
  }
  return value as Hex;
}

function boolean(value: unknown, name: string): boolean {
  if (typeof value !== "boolean") {
    throw new Error(`${name} must be boolean`);
  }
  return value;
}

function same(left: unknown, right: string): boolean {
  return typeof left === "string" && left.toLowerCase() === right.toLowerCase();
}

function concreteBlock(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw new Error("A concrete nonnegative block number is required");
  }
  return value;
}

function render(value: unknown): string {
  return JSON.stringify(value, (_, item) => typeof item === "bigint" ? item.toString() : item);
}

function call(
  adapter: Address,
  method: string,
  args: readonly unknown[],
  value = 0n,
): UnsignedCall {
  return Object.freeze({
    to: address(adapter, "adapter"),
    data: dutchAbi.encodeFunctionData(method, args) as Hex,
    value: uint(value, 256, "call value"),
  });
}

function normalizeSchedule(value: NativeDutchPriceSchedule): NativeDutchPriceSchedule {
  exactKeys(value, [
    "startPrice",
    "restingPrice",
    "startTime",
    "endTime",
    "decayKind",
    "stepSeconds",
    "stepAmount",
  ], "Dutch schedule");
  const output = Object.freeze({
    startPrice: uint(value.startPrice, 96, "startPrice", true),
    restingPrice: uint(value.restingPrice, 96, "restingPrice"),
    startTime: uint(value.startTime, 64, "startTime"),
    endTime: uint(value.endTime, 64, "endTime"),
    decayKind: uint(value.decayKind, 8, "decayKind"),
    stepSeconds: uint(value.stepSeconds, 32, "stepSeconds"),
    stepAmount: uint(value.stepAmount, 96, "stepAmount"),
  });
  if (output.startPrice < output.restingPrice || output.endTime <= output.startTime) {
    throw new Error("Invalid Dutch price or time range");
  }
  if (output.decayKind === 0n) {
    if (output.stepSeconds !== 0n || output.stepAmount !== 0n) {
      throw new Error("Linear Dutch schedules require zero step fields");
    }
  } else if (output.decayKind === 1n) {
    if (output.stepSeconds === 0n || output.stepAmount === 0n) {
      throw new Error("Stepped Dutch schedules require positive step fields");
    }
  } else {
    throw new Error("Unsupported Dutch decay kind");
  }
  return output;
}

function normalizeConfig(value: NativeAllowlistDutchConfig): NativeAllowlistDutchConfig {
  exactKeys(value, [
    "collectionId",
    "phaseId",
    "schedule",
    "maxSaleQuantity",
    "closesAt",
    "declaredFree",
    "mintPolicyHash",
  ], "Dutch sale config");
  const schedule = normalizeSchedule(value.schedule);
  const output = Object.freeze({
    collectionId: uint(value.collectionId, 256, "collectionId", true),
    phaseId: bytes32(value.phaseId, "phaseId", true),
    schedule,
    maxSaleQuantity: uint(value.maxSaleQuantity, 64, "maxSaleQuantity", true),
    closesAt: uint(value.closesAt, 64, "closesAt"),
    declaredFree: boolean(value.declaredFree, "declaredFree"),
    mintPolicyHash: bytes32(value.mintPolicyHash, "mintPolicyHash", true),
  });
  if (output.closesAt < schedule.endTime) {
    throw new Error("Dutch sale closesAt precedes its schedule end");
  }
  if (schedule.restingPrice === 0n && !output.declaredFree) {
    throw new Error("A zero Dutch resting price must be declared free");
  }
  return output;
}

function normalizeHashFacts(
  value: NativeDutchRegistrationHashFacts,
): NativeDutchRegistrationHashFacts {
  exactKeys(value, ["expectedPrimaryPolicyHash", "primaryAssignmentHash"], "Dutch hash facts");
  return Object.freeze({
    expectedPrimaryPolicyHash: bytes32(
      value.expectedPrimaryPolicyHash,
      "expectedPrimaryPolicyHash",
      true,
    ),
    primaryAssignmentHash: bytes32(value.primaryAssignmentHash, "primaryAssignmentHash", true),
  });
}

function normalizeAuthorization(value: NativeDutchAuthorization): NativeDutchAuthorization {
  exactKeys(value, authorizationFields.map(field => field.name), "Dutch authorization");
  return Object.freeze({
    saleId: bytes32(value.saleId, "saleId", true),
    saleConfigHash: bytes32(value.saleConfigHash, "saleConfigHash", true),
    payer: address(value.payer, "payer"),
    executor: address(value.executor, "executor"),
    recipient: address(value.recipient, "recipient"),
    artist: address(value.artist, "artist"),
    tokenDataHash: bytes32(value.tokenDataHash, "tokenDataHash"),
    mintCommitment: bytes32(value.mintCommitment, "mintCommitment", true),
    executionNonce: uint(value.executionNonce, 256, "executionNonce", true),
    nonce: bytes32(value.nonce, "nonce"),
    deadline: uint(value.deadline, 64, "deadline"),
    expectedPrimaryPolicyHash: bytes32(
      value.expectedPrimaryPolicyHash,
      "expectedPrimaryPolicyHash",
    ),
    unitPrice: uint(value.unitPrice, 256, "unitPrice"),
  });
}

function normalizeProof(value: MintAllowlistProof, name: string): MintAllowlistProof {
  exactKeys(value, ["maxCount", "hasPriceOverride", "priceOverride", "proof"], name);
  if (!Array.isArray(value.proof) || value.proof.length > 256) {
    throw new Error(`${name}.proof exceeds the client boundary`);
  }
  const hasPriceOverride = boolean(value.hasPriceOverride, `${name}.hasPriceOverride`);
  const priceOverride = uint(value.priceOverride, 256, `${name}.priceOverride`);
  if (!hasPriceOverride && priceOverride !== 0n) {
    throw new Error("A disabled Dutch price override must be zero");
  }
  return Object.freeze({
    maxCount: uint(value.maxCount, 64, `${name}.maxCount`, true),
    hasPriceOverride,
    priceOverride,
    proof: Object.freeze(
      value.proof.map((item, index) => bytes32(item, `${name}.proof[${index}]`)),
    ),
  });
}

function normalizeProofGroups(
  value: readonly NativeAllowlistDutchProofGroup[],
  selectedId: Hex,
): readonly NativeAllowlistDutchProofGroup[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > NATIVE_ALLOWLIST_DUTCH_MAX_GROUPS) {
    throw new Error("proofGroups must contain 1 through 16 filtered Merkle groups");
  }
  const seen = new Set<string>();
  let selectedCount = 0;
  const output = value.map((group, index) => {
    exactKeys(group, ["counterId", "proof"], `proofGroups[${index}]`);
    const counterId = bytes32(group.counterId, `proofGroups[${index}].counterId`, true);
    const key = counterId.toLowerCase();
    if (seen.has(key)) {
      throw new Error("Dutch proof counter IDs must be unique");
    }
    seen.add(key);
    const proof = normalizeProof(
      group.proof as unknown as MintAllowlistProof,
      `proofGroups[${index}].proof`,
    );
    if (same(counterId, selectedId)) {
      selectedCount++;
    } else if (proof.hasPriceOverride) {
      throw new Error("Only the selected Dutch price counter may enable a price override");
    }
    return Object.freeze({ counterId, proof });
  });
  if (selectedCount !== 1) {
    throw new Error("proofGroups must contain the selected Dutch price counter exactly once");
  }
  return Object.freeze(output);
}

export function nativeAllowlistDutchSaleId(
  chainId: bigint,
  adapter: Address,
  collectionId: bigint,
  phaseId: Hex,
  expectedNonce: bigint,
): Hex {
  const encoded = coder.encode(
    ["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [
      domains.sale,
      uint(chainId, 256, "chainId", true),
      address(adapter, "adapter"),
      3n,
      uint(collectionId, 256, "collectionId", true),
      bytes32(phaseId, "phaseId", true),
      uint(expectedNonce, 256, "expectedNonce", true),
    ],
  );
  return keccak256(encoded) as Hex;
}

export function nativeDutchScheduleHash(
  chainId: bigint,
  adapter: Address,
  saleId: Hex,
  schedule: NativeDutchPriceSchedule,
): Hex {
  const s = normalizeSchedule(schedule);
  const encoded = coder.encode(
    [
      "bytes32",
      "uint256",
      "address",
      "bytes32",
      "uint96",
      "uint96",
      "uint64",
      "uint64",
      "uint8",
      "uint32",
      "uint96",
    ],
    [
      domains.schedule,
      uint(chainId, 256, "chainId", true),
      address(adapter, "adapter"),
      bytes32(saleId, "saleId", true),
      s.startPrice,
      s.restingPrice,
      s.startTime,
      s.endTime,
      s.decayKind,
      s.stepSeconds,
      s.stepAmount,
    ],
  );
  return keccak256(encoded) as Hex;
}

export function nativeDutchOriginalConfigHash(
  saleId: Hex,
  config: NativeAllowlistDutchConfig,
  scheduleHash: Hex,
  hashFacts: NativeDutchRegistrationHashFacts,
): Hex {
  const encoded = coder.encode(
    ["bytes32", "bytes32", configTuple, "bytes32", "bytes32", "bytes32", "uint8", "address"],
    [
      domains.originalConfig,
      bytes32(saleId, "saleId", true),
      normalizeConfig(config),
      bytes32(scheduleHash, "scheduleHash", true),
      normalizeHashFacts(hashFacts).expectedPrimaryPolicyHash,
      normalizeHashFacts(hashFacts).primaryAssignmentHash,
      0n,
      ZeroAddress,
    ],
  );
  return keccak256(encoded) as Hex;
}

export function nativeAllowlistDutchConfigHash(
  originalConfigHash: Hex,
  counterId: Hex,
): Hex {
  const encoded = coder.encode(
    ["bytes32", "bytes32", "bytes32"],
    [
      domains.allowlistConfig,
      bytes32(originalConfigHash, "originalConfigHash", true),
      bytes32(counterId, "counterId", true),
    ],
  );
  return keccak256(encoded) as Hex;
}

export function nativeDutchAuthorizationPayload(
  chainId: bigint,
  adapter: Address,
  authorization: NativeDutchAuthorization,
): SigningPayload<NativeDutchAuthorization> {
  return buildSigningPayload(
    chainId,
    adapter,
    "6529StreamNativeDutchSale",
    "DutchAuthorization",
    authorizationFields,
    normalizeAuthorization(authorization),
  );
}

export function nativeDutchSchedulePrice(
  schedule: NativeDutchPriceSchedule,
  timestamp: bigint,
): bigint {
  const s = normalizeSchedule(schedule);
  const time = uint(timestamp, 256, "timestamp");
  if (time <= s.startTime) {
    return s.startPrice;
  }
  if (time >= s.endTime) {
    return s.restingPrice;
  }
  const elapsed = time - s.startTime;
  const delta = s.startPrice - s.restingPrice;
  if (s.decayKind === 0n) {
    return s.startPrice - delta * elapsed / (s.endTime - s.startTime);
  }
  const reduction = elapsed / s.stepSeconds * s.stepAmount;
  return reduction >= delta ? s.restingPrice : s.startPrice - reduction;
}

export function nativeAllowlistDutchCharge(
  schedulePrice: bigint,
  declaredFree: boolean,
  selectedProof: MintAllowlistProof,
): NativeAllowlistDutchCharge {
  const current = uint(schedulePrice, 256, "schedulePrice");
  const free = boolean(declaredFree, "declaredFree");
  const proof = normalizeProof(selectedProof, "selectedProof");
  if (proof.hasPriceOverride && proof.priceOverride === 0n && !free) {
    throw new Error("A zero Dutch allowlist price was not declared free at registration");
  }
  const chargedAmount = proof.hasPriceOverride && proof.priceOverride < current
    ? proof.priceOverride
    : current;
  return Object.freeze({
    overridden: proof.hasPriceOverride,
    schedulePrice: current,
    chargedAmount,
  });
}

export function prepareNativeAllowlistDutchRegistration(
  chainId: bigint,
  adapter: Address,
  owner: Address,
  expectedNonce: bigint,
  config: NativeAllowlistDutchConfig,
  counterId: Hex,
  hashFacts: NativeDutchRegistrationHashFacts,
): PreparedNativeAllowlistDutchRegistration {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedOwner = address(owner, "owner");
  const nonce = uint(expectedNonce, 256, "expectedNonce", true);
  const normalizedConfig = normalizeConfig(config);
  const normalizedCounterId = bytes32(counterId, "counterId", true);
  const normalizedFacts = normalizeHashFacts(hashFacts);
  const saleId = nativeAllowlistDutchSaleId(
    normalizedChainId,
    normalizedAdapter,
    normalizedConfig.collectionId,
    normalizedConfig.phaseId,
    nonce,
  );
  const scheduleHash = nativeDutchScheduleHash(
    normalizedChainId,
    normalizedAdapter,
    saleId,
    normalizedConfig.schedule,
  );
  const originalConfigHash = nativeDutchOriginalConfigHash(
    saleId,
    normalizedConfig,
    scheduleHash,
    normalizedFacts,
  );
  const configHash = nativeAllowlistDutchConfigHash(originalConfigHash, normalizedCounterId);
  return Object.freeze({
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: normalizedOwner,
    expectedNonce: nonce,
    config: normalizedConfig,
    counterId: normalizedCounterId,
    hashFacts: normalizedFacts,
    saleId,
    scheduleHash,
    originalConfigHash,
    configHash,
    expectedNonceMustBeLiveChecked: true,
    expectedHashFactsRequirePostRegistrationReadback: true,
    call: call(
      normalizedAdapter,
      "registerAllowlistDutchSale",
      [normalizedConfig, normalizedCounterId],
    ),
  });
}

function normalizePurchaseInput(
  value: NativeAllowlistDutchPurchaseInput,
  counterId: Hex,
): NativeAllowlistDutchPurchaseInput {
  exactKeys(value, [
    "tokenData",
    "platformSignature",
    "artistSignature",
    "saleFundingMaximum",
    "revealFeeAllowance",
    "proofGroups",
  ], "Dutch purchase input");
  return Object.freeze({
    tokenData: bytes(value.tokenData, "tokenData"),
    platformSignature: bytes(value.platformSignature, "platformSignature"),
    artistSignature: bytes(value.artistSignature, "artistSignature"),
    saleFundingMaximum: uint(value.saleFundingMaximum, 256, "saleFundingMaximum"),
    revealFeeAllowance: uint(value.revealFeeAllowance, 256, "revealFeeAllowance"),
    proofGroups: normalizeProofGroups(value.proofGroups, counterId),
  });
}

export function prepareNativeAllowlistDutchPurchase(
  chainId: bigint,
  adapter: Address,
  config: NativeAllowlistDutchConfig,
  counterId: Hex,
  hashFacts: NativeDutchRegistrationHashFacts,
  authorization: NativeDutchAuthorization,
  input: NativeAllowlistDutchPurchaseInput,
): PreparedNativeAllowlistDutchPurchase {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedConfig = normalizeConfig(config);
  const normalizedCounterId = bytes32(counterId, "counterId", true);
  const normalizedFacts = normalizeHashFacts(hashFacts);
  const normalizedAuthorization = normalizeAuthorization(authorization);
  const normalizedInput = normalizePurchaseInput(input, normalizedCounterId);
  if (!same(normalizedAuthorization.payer, normalizedAuthorization.executor)) {
    throw new Error("Dutch allowlist purchase requires payer, executor and actual caller to match");
  }
  if (!same(keccak256(normalizedInput.tokenData), normalizedAuthorization.tokenDataHash)) {
    throw new Error("Dutch token data differs from the signed hash");
  }
  const scheduleHash = nativeDutchScheduleHash(
    normalizedChainId,
    normalizedAdapter,
    normalizedAuthorization.saleId,
    normalizedConfig.schedule,
  );
  const originalConfigHash = nativeDutchOriginalConfigHash(
    normalizedAuthorization.saleId,
    normalizedConfig,
    scheduleHash,
    normalizedFacts,
  );
  const expectedConfigHash = nativeAllowlistDutchConfigHash(
    originalConfigHash,
    normalizedCounterId,
  );
  if (!same(normalizedAuthorization.saleConfigHash, expectedConfigHash)) {
    throw new Error("Dutch authorization differs from the wrapped allowlist configuration");
  }
  const payload = nativeDutchAuthorizationPayload(
    normalizedChainId,
    normalizedAdapter,
    normalizedAuthorization,
  );
  const resolverData = mintAllowlistResolverData(
    normalizedInput.proofGroups.map(group => [group.proof]),
  );
  const purchaseData = Object.freeze({
    authorization: normalizedAuthorization,
    tokenData: normalizedInput.tokenData,
    platformSignature: normalizedInput.platformSignature,
    artistSignature: normalizedInput.artistSignature,
  });
  return Object.freeze({
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: normalizedAuthorization.payer,
    config: normalizedConfig,
    counterId: normalizedCounterId,
    hashFacts: normalizedFacts,
    authorization: normalizedAuthorization,
    input: normalizedInput,
    payload,
    resolverData,
    call: call(
      normalizedAdapter,
      "purchaseWithAllowlist",
      [purchaseData, resolverData],
      normalizedInput.saleFundingMaximum + normalizedInput.revealFeeAllowance,
    ),
  });
}

function samePreparedRegistration(
  value: PreparedNativeAllowlistDutchRegistration,
): PreparedNativeAllowlistDutchRegistration {
  exactKeys(value, [
    "chainId",
    "adapter",
    "caller",
    "expectedNonce",
    "config",
    "counterId",
    "hashFacts",
    "saleId",
    "scheduleHash",
    "originalConfigHash",
    "configHash",
    "expectedNonceMustBeLiveChecked",
    "expectedHashFactsRequirePostRegistrationReadback",
    "call",
  ], "prepared Dutch registration");
  const rebuilt = prepareNativeAllowlistDutchRegistration(
    value.chainId,
    value.adapter,
    value.caller,
    value.expectedNonce,
    value.config,
    value.counterId,
    value.hashFacts,
  );
  if (render(rebuilt) !== render(value)) {
    throw new Error("Prepared Dutch registration differs from canonical reconstruction");
  }
  return rebuilt;
}

function samePreparedPurchase(
  value: PreparedNativeAllowlistDutchPurchase,
): PreparedNativeAllowlistDutchPurchase {
  exactKeys(value, [
    "chainId",
    "adapter",
    "caller",
    "config",
    "counterId",
    "hashFacts",
    "authorization",
    "input",
    "payload",
    "resolverData",
    "call",
  ], "prepared Dutch purchase");
  const rebuilt = prepareNativeAllowlistDutchPurchase(
    value.chainId,
    value.adapter,
    value.config,
    value.counterId,
    value.hashFacts,
    value.authorization,
    value.input,
  );
  if (render(rebuilt) !== render(value)) {
    throw new Error("Prepared Dutch purchase differs from canonical reconstruction");
  }
  return rebuilt;
}

async function read(
  provider: Pick<Provider, "call">,
  target: Address,
  iface: Interface,
  method: string,
  args: readonly unknown[],
  blockTag: number,
): Promise<readonly unknown[]> {
  const raw = await provider.call({
    to: target,
    data: iface.encodeFunctionData(method, args),
    blockTag,
  });
  if (typeof raw !== "string" || !isHexString(raw, true)) {
    throw new Error(`Malformed ${method} return`);
  }
  const decoded = iface.decodeFunctionResult(method, raw);
  const canonical = iface.encodeFunctionResult(method, decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error(`Noncanonical ${method} return`);
  }
  return decoded;
}

function tuple(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== "object") {
    throw new Error("Expected ABI tuple");
  }
  return value as Record<string, unknown>;
}

function sameSchedule(decoded: unknown, expected: NativeDutchPriceSchedule): boolean {
  const value = tuple(decoded);
  return BigInt(value.startPrice as bigint) === expected.startPrice
    && BigInt(value.restingPrice as bigint) === expected.restingPrice
    && BigInt(value.startTime as bigint) === expected.startTime
    && BigInt(value.endTime as bigint) === expected.endTime
    && BigInt(value.decayKind as bigint) === expected.decayKind
    && BigInt(value.stepSeconds as bigint) === expected.stepSeconds
    && BigInt(value.stepAmount as bigint) === expected.stepAmount;
}

function sameConfig(decoded: unknown, expected: NativeAllowlistDutchConfig): boolean {
  const value = tuple(decoded);
  return BigInt(value.collectionId as bigint) === expected.collectionId
    && same(value.phaseId, expected.phaseId)
    && sameSchedule(value.schedule, expected.schedule)
    && BigInt(value.maxSaleQuantity as bigint) === expected.maxSaleQuantity
    && BigInt(value.closesAt as bigint) === expected.closesAt
    && Boolean(value.declaredFree) === expected.declaredFree
    && same(value.mintPolicyHash, expected.mintPolicyHash);
}

function recordInspection(value: unknown): NativeAllowlistDutchRecordInspection {
  const record = tuple(value);
  return Object.freeze({
    saleNonce: BigInt(record.saleNonce as bigint),
    configHash: bytes32(record.configHash, "record configHash"),
    scheduleHash: bytes32(record.priceScheduleHash, "record priceScheduleHash"),
    expectedPrimaryPolicyHash: bytes32(
      record.expectedPrimaryPolicyHash,
      "record expectedPrimaryPolicyHash",
    ),
    primaryAssignmentHash: bytes32(record.primaryAssignmentHash, "record primaryAssignmentHash"),
    mintedQuantity: BigInt(record.mintedQuantity as bigint),
    closed: Boolean(record.closed),
    paused: Boolean(record.paused),
  });
}

function decodeResult(value: unknown): NativeAllowlistDutchPurchaseResult {
  const result = tuple(value);
  return Object.freeze({
    revenueOutcome: BigInt(result.revenueOutcome as bigint),
    tokenId: BigInt(result.tokenId as bigint),
    chargedAmount: BigInt(result.chargedAmount as bigint),
    revealFeeForwarded: BigInt(result.revealFeeForwarded as bigint),
    excessCredited: BigInt(result.excessCredited as bigint),
    executionId: bytes32(result.executionId, "executionId"),
    operationRoot: bytes32(result.operationRoot, "operationRoot"),
    operationId: bytes32(result.operationId, "operationId"),
    settlementKey: bytes32(result.settlementKey, "settlementKey"),
    escrowed: Boolean(result.escrowed),
  });
}

function selectedProof(
  groups: readonly NativeAllowlistDutchProofGroup[],
  counterId: Hex,
): MintAllowlistProof {
  const selected = groups.find(group => same(group.counterId, counterId));
  if (selected === undefined) {
    throw new Error("Missing selected Dutch price proof");
  }
  return selected.proof;
}

function assertRecord(
  recordValue: unknown,
  config: NativeAllowlistDutchConfig,
  counter: unknown,
  expected: {
    readonly chainId: bigint;
    readonly adapter: Address;
    readonly saleId: Hex;
    readonly scheduleHash: Hex;
    readonly configHash: Hex;
    readonly counterId: Hex;
    readonly hashFacts: NativeDutchRegistrationHashFacts;
  },
): NativeAllowlistDutchRecordInspection {
  const raw = tuple(recordValue);
  const record = recordInspection(raw);
  const saleId = nativeAllowlistDutchSaleId(
    expected.chainId,
    expected.adapter,
    config.collectionId,
    config.phaseId,
    record.saleNonce,
  );
  const mismatch = record.saleNonce === 0n
    || !sameConfig(raw.config, config)
    || !same(saleId, expected.saleId)
    || !same(record.scheduleHash, expected.scheduleHash)
    || !same(record.configHash, expected.configHash)
    || !same(record.expectedPrimaryPolicyHash, expected.hashFacts.expectedPrimaryPolicyHash)
    || !same(record.primaryAssignmentHash, expected.hashFacts.primaryAssignmentHash)
    || !same(counter, expected.counterId);
  if (mismatch) {
    throw new Error("Stored Dutch allowlist record differs from reviewed configuration");
  }
  return record;
}

export async function inspectNativeAllowlistDutchRegistration(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistDutchRegistration,
  options: { readonly blockTag: number },
): Promise<{
  readonly prepared: PreparedNativeAllowlistDutchRegistration;
  readonly core: Address;
  readonly mintManager: Address;
  readonly entropyCoordinator: Address;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}> {
  const prepared = samePreparedRegistration(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from Dutch registration coordinates");
  }
  const [[owner], [nonce], [saleId], [core], [manager], [entropy]] = await Promise.all([
    read(provider, prepared.adapter, dutchAbi, "owner", [], blockTag),
    read(provider, prepared.adapter, dutchAbi, "nextSaleNonce", [], blockTag),
    read(
      provider,
      prepared.adapter,
      dutchAbi,
      "saleIdFor",
      [prepared.config.collectionId, prepared.config.phaseId, prepared.expectedNonce],
      blockTag,
    ),
    read(provider, prepared.adapter, dutchAbi, "core", [], blockTag),
    read(provider, prepared.adapter, dutchAbi, "mintManager", [], blockTag),
    read(provider, prepared.adapter, dutchAbi, "entropyCoordinator", [], blockTag),
  ]);
  if (!same(owner, prepared.caller)) {
    throw new Error("Prepared caller is not the current Dutch adapter owner");
  }
  if (BigInt(nonce as bigint) !== prepared.expectedNonce) {
    throw new Error("Live Dutch sale nonce differs from the reviewed registration preimage");
  }
  if (!same(saleId, prepared.saleId)) {
    throw new Error("Canonical Dutch sale ID getter differs from local recomputation");
  }
  return Object.freeze({
    prepared,
    core: address(core, "core"),
    mintManager: address(manager, "mintManager"),
    entropyCoordinator: address(entropy, "entropyCoordinator"),
    checked: Object.freeze([
      "RPC chain and adapter owner",
      "live next sale nonce and canonical sale ID",
      "configured Core, Mint Manager and entropy coordinator addresses",
    ]),
    limitations: Object.freeze([
      "expected baseline and assignment hash facts require post-registration saleRecord readback",
      ...limitations,
    ]),
  });
}

export async function simulateNativeAllowlistDutchRegistration(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistDutchRegistration,
  options: { readonly blockTag: number },
): Promise<Hex> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectNativeAllowlistDutchRegistration(
    provider,
    preparedInput,
    { blockTag },
  );
  const prepared = inspected.prepared;
  const raw = await provider.call({
    ...prepared.call,
    from: prepared.caller,
    blockTag,
  });
  if (typeof raw !== "string" || !isHexString(raw, true)) {
    throw new Error("Malformed Dutch registration simulation return");
  }
  const decoded = dutchAbi.decodeFunctionResult("registerAllowlistDutchSale", raw);
  const canonical = dutchAbi.encodeFunctionResult("registerAllowlistDutchSale", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical Dutch registration simulation return");
  }
  const saleId = bytes32(decoded[0], "registered saleId", true);
  if (!same(saleId, prepared.saleId)) {
    throw new Error("Dutch registration simulation returned an unexpected sale ID");
  }
  return saleId;
}

export async function inspectRegisteredNativeAllowlistDutchSale(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistDutchRegistration,
  options: { readonly blockTag: number },
): Promise<NativeAllowlistDutchRecordInspection> {
  const prepared = samePreparedRegistration(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from Dutch registration coordinates");
  }
  const [[record], [counter]] = await Promise.all([
    read(provider, prepared.adapter, dutchAbi, "saleRecord", [prepared.saleId], blockTag),
    read(
      provider,
      prepared.adapter,
      dutchAbi,
      "allowlistPriceCounter",
      [prepared.saleId],
      blockTag,
    ),
  ]);
  return assertRecord(record, prepared.config, counter, prepared);
}

export async function inspectNativeAllowlistDutchPurchase(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistDutchPurchase,
  options: { readonly blockTag: number },
): Promise<NativeAllowlistDutchPurchaseInspection> {
  const prepared = samePreparedPurchase(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from Dutch signing domain");
  }
  const saleId = prepared.authorization.saleId;
  const [
    [recordValue],
    [counter],
    [schedulePriceValue],
    [digest],
    [core],
    [manager],
    [entropy],
    [adapterPaused],
  ] = await Promise.all([
    read(provider, prepared.adapter, dutchAbi, "saleRecord", [saleId], blockTag),
    read(provider, prepared.adapter, dutchAbi, "allowlistPriceCounter", [saleId], blockTag),
    read(provider, prepared.adapter, dutchAbi, "currentPrice", [saleId], blockTag),
    read(
      provider,
      prepared.adapter,
      dutchAbi,
      "authorizationDigest",
      [prepared.authorization],
      blockTag,
    ),
    read(provider, prepared.adapter, dutchAbi, "core", [], blockTag),
    read(provider, prepared.adapter, dutchAbi, "mintManager", [], blockTag),
    read(provider, prepared.adapter, dutchAbi, "entropyCoordinator", [], blockTag),
    read(provider, prepared.adapter, dutchAbi, "paused", [], blockTag),
  ]);
  const scheduleHash = nativeDutchScheduleHash(
    prepared.chainId,
    prepared.adapter,
    saleId,
    prepared.config.schedule,
  );
  const originalConfigHash = nativeDutchOriginalConfigHash(
    saleId,
    prepared.config,
    scheduleHash,
    prepared.hashFacts,
  );
  const configHash = nativeAllowlistDutchConfigHash(originalConfigHash, prepared.counterId);
  const record = assertRecord(recordValue, prepared.config, counter, {
    chainId: prepared.chainId,
    adapter: prepared.adapter,
    saleId,
    scheduleHash,
    configHash,
    counterId: prepared.counterId,
    hashFacts: prepared.hashFacts,
  });
  if (Boolean(adapterPaused) || record.closed || record.paused) {
    throw new Error("Dutch sale or adapter is paused or closed");
  }
  if (record.mintedQuantity >= prepared.config.maxSaleQuantity) {
    throw new Error("Dutch sale has reached its quantity limit");
  }
  if (!same(digest, prepared.payload.digest)) {
    throw new Error("Current Dutch digest getter differs from the signing payload");
  }
  const currentSchedulePrice = uint(
    BigInt(schedulePriceValue as bigint),
    256,
    "current schedule price",
  );
  if (
    currentSchedulePrice < prepared.config.schedule.restingPrice
    || currentSchedulePrice > prepared.config.schedule.startPrice
  ) {
    throw new Error("Current Dutch price is outside the configured schedule range");
  }
  const expectedCharge = nativeAllowlistDutchCharge(
    currentSchedulePrice,
    prepared.config.declaredFree,
    selectedProof(prepared.input.proofGroups, prepared.counterId),
  );
  if (prepared.authorization.unitPrice < expectedCharge.chargedAmount) {
    throw new Error("Signed Dutch maximum is below the expected allowlist charge");
  }
  const entropyCoordinator = address(entropy, "entropyCoordinator");
  const [policyValue] = await read(
    provider,
    entropyCoordinator,
    entropyAbi,
    "collectionRevealPolicy",
    [prepared.config.collectionId],
    blockTag,
  );
  const policy = tuple(policyValue);
  if (!Boolean(policy.declared) || BigInt(policy.requestMode as bigint) > 1n) {
    throw new Error("Missing or unsupported Dutch reveal policy");
  }
  const revealFeePerTokenWei = uint(
    BigInt(policy.revealFeePerTokenWei as bigint),
    256,
    "reveal fee",
  );
  if (prepared.input.revealFeeAllowance < revealFeePerTokenWei) {
    throw new Error("Dutch reveal fee allowance is below the pinned quote");
  }
  if (prepared.call.value < expectedCharge.chargedAmount + revealFeePerTokenWei) {
    throw new Error("Attached Dutch funding maximum is below the pinned charge and fee");
  }
  return Object.freeze({
    prepared,
    record,
    core: address(core, "core"),
    mintManager: address(manager, "mintManager"),
    entropyCoordinator,
    currentSchedulePrice,
    expectedCharge,
    revealFeePerTokenWei,
    effectiveSaleFundingMaximum: prepared.call.value - revealFeePerTokenWei,
    checked: purchaseChecked,
    limitations,
  });
}

export async function simulateNativeAllowlistDutchPurchase(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistDutchPurchase,
  options: { readonly blockTag: number },
): Promise<NativeAllowlistDutchPurchaseResult> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectNativeAllowlistDutchPurchase(
    provider,
    preparedInput,
    { blockTag },
  );
  const prepared = inspected.prepared;
  const raw = await provider.call({
    ...prepared.call,
    from: prepared.caller,
    blockTag,
  });
  if (typeof raw !== "string" || !isHexString(raw, true)) {
    throw new Error("Malformed Dutch purchase simulation return");
  }
  const decoded = dutchAbi.decodeFunctionResult("purchaseWithAllowlist", raw);
  const canonical = dutchAbi.encodeFunctionResult("purchaseWithAllowlist", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical Dutch purchase simulation return");
  }
  const result = decodeResult(decoded[0]);
  const expectedExcess = prepared.call.value
    - inspected.revealFeePerTokenWei
    - inspected.expectedCharge.chargedAmount;
  if (
    result.chargedAmount !== inspected.expectedCharge.chargedAmount
    || result.revealFeeForwarded !== inspected.revealFeePerTokenWei
    || result.excessCredited !== expectedExcess
  ) {
    throw new Error("Dutch simulation payment result differs from pinned expectations");
  }
  return result;
}

export function prepareNativeDutchRefund(
  adapter: Address,
  saleId: Hex,
  creditedPayer: Address,
  recipient: Address,
): PreparedNativeDutchRefund {
  const target = address(adapter, "adapter");
  const caller = address(creditedPayer, "credited payer");
  const destination = address(recipient, "refund recipient");
  if (same(destination, target)) {
    throw new Error("Dutch refund recipient cannot be the adapter");
  }
  const normalizedSaleId = bytes32(saleId, "saleId", true);
  return Object.freeze({
    adapter: target,
    saleId: normalizedSaleId,
    caller,
    recipient: destination,
    call: call(target, "claimRefund", [normalizedSaleId, destination]),
  });
}

function samePreparedRefund(value: PreparedNativeDutchRefund): PreparedNativeDutchRefund {
  exactKeys(value, ["adapter", "saleId", "caller", "recipient", "call"], "prepared refund");
  const rebuilt = prepareNativeDutchRefund(
    value.adapter,
    value.saleId,
    value.caller,
    value.recipient,
  );
  if (render(rebuilt) !== render(value)) {
    throw new Error("Prepared Dutch refund differs from canonical reconstruction");
  }
  return rebuilt;
}

export async function inspectNativeDutchRefund(
  provider: Pick<Provider, "call">,
  preparedInput: PreparedNativeDutchRefund,
  options: { readonly blockTag: number },
): Promise<{
  readonly prepared: PreparedNativeDutchRefund;
  readonly refundableBalance: bigint;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}> {
  const prepared = samePreparedRefund(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const [balance] = await read(
    provider,
    prepared.adapter,
    dutchAbi,
    "refundableBalance",
    [prepared.saleId, prepared.caller],
    blockTag,
  );
  const refundableBalance = uint(BigInt(balance as bigint), 256, "refundable balance", true);
  return Object.freeze({
    prepared,
    refundableBalance,
    checked: Object.freeze(["credited payer's retained per-sale refundable balance"]),
    limitations: Object.freeze([
      "refund inspection deliberately does not reapply sale, artist, proof or mint admission",
      "numeric block pin has no reorg hash check and future transaction acceptance is not claimed",
    ]),
  });
}

export async function simulateNativeDutchRefund(
  provider: Pick<Provider, "call">,
  preparedInput: PreparedNativeDutchRefund,
  options: { readonly blockTag: number },
): Promise<bigint> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectNativeDutchRefund(provider, preparedInput, { blockTag });
  const prepared = inspected.prepared;
  const raw = await provider.call({
    ...prepared.call,
    from: prepared.caller,
    blockTag,
  });
  if (raw !== "0x") {
    const decoded = dutchAbi.decodeFunctionResult("claimRefund", raw);
    const canonical = dutchAbi.encodeFunctionResult("claimRefund", decoded);
    if (canonical.toLowerCase() !== raw.toLowerCase()) {
      throw new Error("Noncanonical Dutch refund simulation return");
    }
  }
  return inspected.refundableBalance;
}
