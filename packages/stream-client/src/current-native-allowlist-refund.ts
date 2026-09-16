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

export const NATIVE_ALLOWLIST_REFUND_MAX_GROUPS = 16;

export interface NativeAllowlistRefundConfig {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly price: bigint;
  readonly maxSaleQuantity: bigint;
  readonly startsAt: bigint;
  readonly endsAt: bigint;
  readonly refundWindowSeconds: bigint;
  readonly finalizationWindowSeconds: bigint;
  readonly primaryPolicyMode: bigint;
  readonly mintPolicyHash: Hex;
}

export interface NativeAllowlistRefundPolicy {
  readonly counterId: Hex;
  readonly allowFree: boolean;
}

export interface NativeRefundPurchaseAuthorization {
  readonly saleId: Hex;
  readonly saleConfigHash: Hex;
  readonly payer: Address;
  readonly recipient: Address;
  readonly artist: Address;
  readonly tokenDataHash: Hex;
  readonly mintCommitment: Hex;
  readonly purchaseNonce: bigint;
  readonly nonce: Hex;
  readonly price: bigint;
  readonly deadline: bigint;
  readonly windowPolicyHash: Hex;
  readonly maximumNominalFinalizeBy: bigint;
  readonly absoluteEscapeDeadline: bigint;
  readonly expectedPrimaryPolicyHash: Hex;
}

/** Counter IDs are unchecked caller labels. The payable simulation validates witness positions. */
export interface NativeAllowlistRefundProofGroup {
  readonly counterId: Hex;
  readonly proof: MintAllowlistProof;
}

export interface NativeAllowlistRefundCharge {
  readonly overridden: boolean;
  readonly publicPrice: bigint;
  readonly chargedPrice: bigint;
}

export interface PreparedNativeAllowlistRefundRegistration {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly expectedNonce: bigint;
  readonly config: NativeAllowlistRefundConfig;
  readonly policy: NativeAllowlistRefundPolicy;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly saleId: Hex;
  readonly windowPolicyHash: Hex;
  readonly originalConfigHash: Hex;
  readonly configHash: Hex;
  readonly expectedNonceMustBeLiveChecked: true;
  readonly expectedPolicyRequiresPostRegistrationReadback: true;
  readonly call: UnsignedCall;
}

export interface NativeAllowlistRefundPurchaseInput {
  readonly tokenData: Hex;
  readonly platformSignature: Hex;
  readonly artistSignature: Hex;
  readonly priceFundingMaximum: bigint;
  readonly revealFeeAllowance: bigint;
  readonly proofGroups: readonly NativeAllowlistRefundProofGroup[];
}

export interface PreparedNativeAllowlistRefundPurchase {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly config: NativeAllowlistRefundConfig;
  readonly policy: NativeAllowlistRefundPolicy;
  readonly expectedRegistrationPolicyHash: Hex;
  readonly authorization: NativeRefundPurchaseAuthorization;
  readonly input: NativeAllowlistRefundPurchaseInput;
  readonly payload: SigningPayload<NativeRefundPurchaseAuthorization>;
  readonly expectedCharge: NativeAllowlistRefundCharge;
  readonly resolverData: Hex;
  readonly expectedPurchaseId: Hex;
  readonly call: UnsignedCall;
}

export interface NativeAllowlistRefundSaleRecordInspection {
  readonly saleNonce: bigint;
  readonly configHash: Hex;
  readonly windowPolicyHash: Hex;
  readonly purchasedQuantity: bigint;
  readonly expectedPrimaryPolicyHash: Hex;
}

export interface NativeAllowlistRefundPurchaseInspection {
  readonly prepared: PreparedNativeAllowlistRefundPurchase;
  readonly record: NativeAllowlistRefundSaleRecordInspection;
  readonly core: Address;
  readonly mintManager: Address;
  readonly entropyCoordinator: Address;
  readonly revealFeePerTokenWei: bigint;
  readonly effectivePriceFundingMaximum: bigint;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}

export type NativeRefundLifecycleActionKind =
  | "finalize"
  | "refund"
  | "unlock"
  | "synchronize"
  | "claim";

export interface PreparedNativeRefundLifecycleAction {
  readonly kind: NativeRefundLifecycleActionKind;
  readonly adapter: Address;
  readonly caller: Address;
  readonly purchaseId: Hex | null;
  readonly saleId: Hex | null;
  readonly recipient: Address | null;
  readonly unlockReason: bigint | null;
  readonly call: UnsignedCall;
}

const coder = AbiCoder.defaultAbiCoder();
const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const MAX_BYTES = 4_194_304;
const configTuple = "tuple(uint256 collectionId,bytes32 phaseId,uint256 price,uint64 maxSaleQuantity,uint64 startsAt,uint64 endsAt,uint64 refundWindowSeconds,uint64 finalizationWindowSeconds,uint8 primaryPolicyMode,bytes32 mintPolicyHash)";
const policyTuple = "tuple(bytes32 counterId,bool allowFree)";
const authorizationTuple = "tuple(bytes32 saleId,bytes32 saleConfigHash,address payer,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 purchaseNonce,bytes32 nonce,uint256 price,uint64 deadline,bytes32 windowPolicyHash,uint64 maximumNominalFinalizeBy,uint64 absoluteEscapeDeadline,bytes32 expectedPrimaryPolicyHash)";
const purchaseTuple = `tuple(${authorizationTuple} authorization,bytes tokenData,bytes platformSignature,bytes artistSignature)`;
const lifecycleTuple = "tuple(uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision)";
const saleRecordTuple = `tuple(${configTuple} config,uint256 saleNonce,bytes32 configHash,bytes32 windowPolicyHash,${lifecycleTuple} lifecycle,uint64 purchasedQuantity,bytes32 expectedPrimaryPolicyHash)`;
const finalizationResultTuple = "tuple(bytes32 executionId,bytes32 operationRoot,bytes32 operationId,uint256 tokenId,bytes32 settlementKey,uint256 amount,uint256 revealFeeForwarded,uint256 revealFeeRefunded,bool escrowed)";
const refundAbi = new Interface([
  `function registerAllowlistRefundSale(${configTuple},${policyTuple}) returns (bytes32)`,
  `function purchaseAllowlistRefundWindow(${purchaseTuple},bytes) payable returns (bytes32)`,
  `function allowlistRefundSalePolicy(bytes32) view returns (${policyTuple})`,
  `function refundSaleRecord(bytes32) view returns (${saleRecordTuple})`,
  `function refundPurchaseAuthorizationDigest(${authorizationTuple}) view returns (bytes32)`,
  "function nextSaleNonce() view returns (uint256)",
  "function nextPurchaseNonce(bytes32,address) view returns (uint256)",
  "function refundableBalance(bytes32,address) view returns (uint256)",
  `function finalizeRefundWindow(bytes32) returns (${finalizationResultTuple})`,
  "function refundPurchase(bytes32)",
  "function unlockRefund(bytes32,uint8)",
  "function synchronizePurchaseWindow(bytes32)",
  "function claimRefund(bytes32,address) returns (uint256)",
  "function purchaseDeadlines(bytes32) view returns (uint64,uint64,uint64)",
  "function owner() view returns (address)",
  "function core() view returns (address)",
  "function mintManager() view returns (address)",
  "function entropyCoordinator() view returns (address)",
]);
const entropyAbi = new Interface([
  "function collectionRevealPolicy(uint256) view returns (tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei))",
]);
const domains = Object.freeze({
  sale: id("6529STREAM_SALE_V1") as Hex,
  windowPolicy: id("6529STREAM_REFUND_WINDOW_POLICY_V1") as Hex,
  pauseUnion: id("OBSERVED_GLOBAL_OR_LOCAL_PAUSE_UNION") as Hex,
  equality: id("ABSOLUTE_ESCAPE_PAUSED_EQUALITY_UNPAUSED_FINALIZE_EQUALITY") as Hex,
  originalConfig: id("6529STREAM_NATIVE_REFUND_SALE_CONFIG_V1") as Hex,
  allowlistConfig: id("6529STREAM_NATIVE_ALLOWLIST_REFUND_CONFIG_V1") as Hex,
  purchase: id("6529STREAM_SALE_PURCHASE_V1") as Hex,
});
const authorizationFields = Object.freeze([
  { name: "saleId", type: "bytes32" },
  { name: "saleConfigHash", type: "bytes32" },
  { name: "payer", type: "address" },
  { name: "recipient", type: "address" },
  { name: "artist", type: "address" },
  { name: "tokenDataHash", type: "bytes32" },
  { name: "mintCommitment", type: "bytes32" },
  { name: "purchaseNonce", type: "uint256" },
  { name: "nonce", type: "bytes32" },
  { name: "price", type: "uint256" },
  { name: "deadline", type: "uint64" },
  { name: "windowPolicyHash", type: "bytes32" },
  { name: "maximumNominalFinalizeBy", type: "uint64" },
  { name: "absoluteEscapeDeadline", type: "uint64" },
  { name: "expectedPrimaryPolicyHash", type: "bytes32" },
]);
const purchaseChecked = Object.freeze([
  "RPC chain and exact stored refund sale record",
  "allowlist policy and next payer purchase nonce",
  "original authorization digest and public signed price",
  "declared reveal policy and attached price/fee funding",
  "configured Core, Mint Manager and entropy coordinator addresses",
]);
const limitations = Object.freeze([
  "numeric block pin has no reorg hash check",
  "proof counter IDs are unchecked caller metadata; only exact payable simulation validates positional witnesses against live Manager state",
  "read-only inspection does not validate signatures, Artist consent, phase timing, live admission or runtime code identity",
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
    data: refundAbi.encodeFunctionData(method, args) as Hex,
    value: uint(value, 256, "call value"),
  });
}

function normalizeConfig(value: NativeAllowlistRefundConfig): NativeAllowlistRefundConfig {
  exactKeys(value, [
    "collectionId",
    "phaseId",
    "price",
    "maxSaleQuantity",
    "startsAt",
    "endsAt",
    "refundWindowSeconds",
    "finalizationWindowSeconds",
    "primaryPolicyMode",
    "mintPolicyHash",
  ], "refund sale config");
  const output = Object.freeze({
    collectionId: uint(value.collectionId, 256, "collectionId", true),
    phaseId: bytes32(value.phaseId, "phaseId", true),
    price: uint(value.price, 256, "price", true),
    maxSaleQuantity: uint(value.maxSaleQuantity, 64, "maxSaleQuantity", true),
    startsAt: uint(value.startsAt, 64, "startsAt"),
    endsAt: uint(value.endsAt, 64, "endsAt"),
    refundWindowSeconds: uint(value.refundWindowSeconds, 64, "refundWindowSeconds"),
    finalizationWindowSeconds: uint(
      value.finalizationWindowSeconds,
      64,
      "finalizationWindowSeconds",
    ),
    primaryPolicyMode: uint(value.primaryPolicyMode, 8, "primaryPolicyMode"),
    mintPolicyHash: bytes32(value.mintPolicyHash, "mintPolicyHash", true),
  });
  if (output.endsAt <= output.startsAt) {
    throw new Error("Refund sale endsAt must follow startsAt");
  }
  if (output.refundWindowSeconds < 3_600n || output.refundWindowSeconds > 2_592_000n) {
    throw new Error("refundWindowSeconds is outside the protocol range");
  }
  if (
    output.finalizationWindowSeconds < 86_400n
    || output.finalizationWindowSeconds > 7_776_000n
  ) {
    throw new Error("finalizationWindowSeconds is outside the protocol range");
  }
  if (output.primaryPolicyMode !== 1n) {
    throw new Error("Refund sale primaryPolicyMode must be ALLOW_CURRENT (1)");
  }
  return output;
}

function normalizePolicy(value: NativeAllowlistRefundPolicy): NativeAllowlistRefundPolicy {
  exactKeys(value, ["counterId", "allowFree"], "refund allowlist policy");
  return Object.freeze({
    counterId: bytes32(value.counterId, "counterId", true),
    allowFree: boolean(value.allowFree, "allowFree"),
  });
}

function normalizeAuthorization(
  value: NativeRefundPurchaseAuthorization,
): NativeRefundPurchaseAuthorization {
  exactKeys(value, authorizationFields.map(field => field.name), "refund authorization");
  return Object.freeze({
    saleId: bytes32(value.saleId, "saleId", true),
    saleConfigHash: bytes32(value.saleConfigHash, "saleConfigHash", true),
    payer: address(value.payer, "payer"),
    recipient: address(value.recipient, "recipient"),
    artist: address(value.artist, "artist"),
    tokenDataHash: bytes32(value.tokenDataHash, "tokenDataHash"),
    mintCommitment: bytes32(value.mintCommitment, "mintCommitment", true),
    purchaseNonce: uint(value.purchaseNonce, 256, "purchaseNonce", true),
    nonce: bytes32(value.nonce, "nonce"),
    price: uint(value.price, 256, "price", true),
    deadline: uint(value.deadline, 64, "deadline"),
    windowPolicyHash: bytes32(value.windowPolicyHash, "windowPolicyHash", true),
    maximumNominalFinalizeBy: uint(
      value.maximumNominalFinalizeBy,
      64,
      "maximumNominalFinalizeBy",
    ),
    absoluteEscapeDeadline: uint(
      value.absoluteEscapeDeadline,
      64,
      "absoluteEscapeDeadline",
    ),
    expectedPrimaryPolicyHash: bytes32(
      value.expectedPrimaryPolicyHash,
      "expectedPrimaryPolicyHash",
      true,
    ),
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
    throw new Error("A disabled refund price override must be zero");
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

function normalizeGroups(
  value: readonly NativeAllowlistRefundProofGroup[],
  selectedId: Hex,
): readonly NativeAllowlistRefundProofGroup[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > NATIVE_ALLOWLIST_REFUND_MAX_GROUPS) {
    throw new Error("proofGroups must contain 1 through 16 filtered Merkle groups");
  }
  const seen = new Set<string>();
  let selectedCount = 0;
  const output = value.map((group, index) => {
    exactKeys(group, ["counterId", "proof"], `proofGroups[${index}]`);
    const counterId = bytes32(group.counterId, `proofGroups[${index}].counterId`, true);
    const key = counterId.toLowerCase();
    if (seen.has(key)) {
      throw new Error("Refund proof counter IDs must be unique");
    }
    seen.add(key);
    const proof = normalizeProof(
      group.proof as unknown as MintAllowlistProof,
      `proofGroups[${index}].proof`,
    );
    if (same(counterId, selectedId)) {
      selectedCount++;
    } else if (proof.hasPriceOverride) {
      throw new Error("Only the selected refund price counter may enable a price override");
    }
    return Object.freeze({ counterId, proof });
  });
  if (selectedCount !== 1) {
    throw new Error("proofGroups must contain the selected refund price counter exactly once");
  }
  return Object.freeze(output);
}

export function nativeAllowlistRefundSaleId(
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
      7n,
      uint(collectionId, 256, "collectionId", true),
      bytes32(phaseId, "phaseId", true),
      uint(expectedNonce, 256, "expectedNonce", true),
    ],
  );
  return keccak256(encoded) as Hex;
}

export function nativeRefundWindowPolicyHash(
  config: NativeAllowlistRefundConfig,
): Hex {
  const normalized = normalizeConfig(config);
  const encoded = coder.encode(
    ["bytes32", "uint64", "uint64", "bytes32", "bytes32"],
    [
      domains.windowPolicy,
      normalized.refundWindowSeconds,
      normalized.finalizationWindowSeconds,
      domains.pauseUnion,
      domains.equality,
    ],
  );
  return keccak256(encoded) as Hex;
}

export function nativeRefundOriginalConfigHash(
  saleId: Hex,
  config: NativeAllowlistRefundConfig,
  expectedPrimaryPolicyHash: Hex,
): Hex {
  const encoded = coder.encode(
    ["bytes32", "bytes32", configTuple, "bytes32"],
    [
      domains.originalConfig,
      bytes32(saleId, "saleId", true),
      normalizeConfig(config),
      bytes32(expectedPrimaryPolicyHash, "expectedPrimaryPolicyHash", true),
    ],
  );
  return keccak256(encoded) as Hex;
}

export function nativeAllowlistRefundConfigHash(
  originalConfigHash: Hex,
  policy: NativeAllowlistRefundPolicy,
): Hex {
  const encoded = coder.encode(
    ["bytes32", "bytes32", policyTuple],
    [
      domains.allowlistConfig,
      bytes32(originalConfigHash, "originalConfigHash", true),
      normalizePolicy(policy),
    ],
  );
  return keccak256(encoded) as Hex;
}

export function nativeRefundPurchaseAuthorizationPayload(
  chainId: bigint,
  adapter: Address,
  authorization: NativeRefundPurchaseAuthorization,
): SigningPayload<NativeRefundPurchaseAuthorization> {
  return buildSigningPayload(
    chainId,
    adapter,
    "6529StreamNativeRefundWindowSale",
    "RefundPurchaseAuthorization",
    authorizationFields,
    normalizeAuthorization(authorization),
  );
}

export function nativeRefundPurchaseId(
  chainId: bigint,
  adapter: Address,
  saleId: Hex,
  payer: Address,
  purchaseNonce: bigint,
): Hex {
  const encoded = coder.encode(
    ["bytes32", "uint256", "address", "bytes32", "address", "uint256"],
    [
      domains.purchase,
      uint(chainId, 256, "chainId", true),
      address(adapter, "adapter"),
      bytes32(saleId, "saleId", true),
      address(payer, "payer"),
      uint(purchaseNonce, 256, "purchaseNonce", true),
    ],
  );
  return keccak256(encoded) as Hex;
}

export function nativeAllowlistRefundCharge(
  publicPrice: bigint,
  policy: NativeAllowlistRefundPolicy,
  selectedProof: MintAllowlistProof,
): NativeAllowlistRefundCharge {
  const original = uint(publicPrice, 256, "publicPrice", true);
  const normalizedPolicy = normalizePolicy(policy);
  const proof = normalizeProof(selectedProof, "selectedProof");
  const chargedPrice = proof.hasPriceOverride ? proof.priceOverride : original;
  if (chargedPrice === 0n && !normalizedPolicy.allowFree) {
    throw new Error("A zero refund allowlist price was not declared free at registration");
  }
  return Object.freeze({
    overridden: proof.hasPriceOverride,
    publicPrice: original,
    chargedPrice,
  });
}

export function prepareNativeAllowlistRefundRegistration(
  chainId: bigint,
  adapter: Address,
  owner: Address,
  expectedNonce: bigint,
  config: NativeAllowlistRefundConfig,
  policy: NativeAllowlistRefundPolicy,
  expectedPrimaryPolicyHash: Hex,
): PreparedNativeAllowlistRefundRegistration {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedOwner = address(owner, "owner");
  const nonce = uint(expectedNonce, 256, "expectedNonce", true);
  const normalizedConfig = normalizeConfig(config);
  const normalizedPolicy = normalizePolicy(policy);
  const baseline = bytes32(
    expectedPrimaryPolicyHash,
    "expectedPrimaryPolicyHash",
    true,
  );
  const saleId = nativeAllowlistRefundSaleId(
    normalizedChainId,
    normalizedAdapter,
    normalizedConfig.collectionId,
    normalizedConfig.phaseId,
    nonce,
  );
  const windowPolicyHash = nativeRefundWindowPolicyHash(normalizedConfig);
  const originalConfigHash = nativeRefundOriginalConfigHash(
    saleId,
    normalizedConfig,
    baseline,
  );
  const configHash = nativeAllowlistRefundConfigHash(originalConfigHash, normalizedPolicy);
  return Object.freeze({
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: normalizedOwner,
    expectedNonce: nonce,
    config: normalizedConfig,
    policy: normalizedPolicy,
    expectedPrimaryPolicyHash: baseline,
    saleId,
    windowPolicyHash,
    originalConfigHash,
    configHash,
    expectedNonceMustBeLiveChecked: true,
    expectedPolicyRequiresPostRegistrationReadback: true,
    call: call(
      normalizedAdapter,
      "registerAllowlistRefundSale",
      [normalizedConfig, normalizedPolicy],
    ),
  });
}

function normalizePurchaseInput(
  value: NativeAllowlistRefundPurchaseInput,
  counterId: Hex,
): NativeAllowlistRefundPurchaseInput {
  exactKeys(value, [
    "tokenData",
    "platformSignature",
    "artistSignature",
    "priceFundingMaximum",
    "revealFeeAllowance",
    "proofGroups",
  ], "refund purchase input");
  return Object.freeze({
    tokenData: bytes(value.tokenData, "tokenData"),
    platformSignature: bytes(value.platformSignature, "platformSignature"),
    artistSignature: bytes(value.artistSignature, "artistSignature"),
    priceFundingMaximum: uint(value.priceFundingMaximum, 256, "priceFundingMaximum"),
    revealFeeAllowance: uint(value.revealFeeAllowance, 256, "revealFeeAllowance"),
    proofGroups: normalizeGroups(value.proofGroups, counterId),
  });
}

function selectedProof(
  groups: readonly NativeAllowlistRefundProofGroup[],
  counterId: Hex,
): MintAllowlistProof {
  const selected = groups.find(group => same(group.counterId, counterId));
  if (selected === undefined) {
    throw new Error("Missing selected refund price proof");
  }
  return selected.proof;
}

export function prepareNativeAllowlistRefundPurchase(
  chainId: bigint,
  adapter: Address,
  config: NativeAllowlistRefundConfig,
  policy: NativeAllowlistRefundPolicy,
  expectedRegistrationPolicyHash: Hex,
  authorization: NativeRefundPurchaseAuthorization,
  input: NativeAllowlistRefundPurchaseInput,
): PreparedNativeAllowlistRefundPurchase {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedConfig = normalizeConfig(config);
  const normalizedPolicy = normalizePolicy(policy);
  const registrationBaseline = bytes32(
    expectedRegistrationPolicyHash,
    "expectedRegistrationPolicyHash",
    true,
  );
  const normalizedAuthorization = normalizeAuthorization(authorization);
  const normalizedInput = normalizePurchaseInput(input, normalizedPolicy.counterId);
  if (!same(keccak256(normalizedInput.tokenData), normalizedAuthorization.tokenDataHash)) {
    throw new Error("Refund token data differs from the signed hash");
  }
  if (normalizedAuthorization.price !== normalizedConfig.price) {
    throw new Error("Signed refund price must remain the public configured price");
  }
  const expectedWindowHash = nativeRefundWindowPolicyHash(normalizedConfig);
  if (!same(normalizedAuthorization.windowPolicyHash, expectedWindowHash)) {
    throw new Error("Refund authorization window policy differs from the configuration");
  }
  const originalConfigHash = nativeRefundOriginalConfigHash(
    normalizedAuthorization.saleId,
    normalizedConfig,
    registrationBaseline,
  );
  const expectedConfigHash = nativeAllowlistRefundConfigHash(
    originalConfigHash,
    normalizedPolicy,
  );
  if (!same(normalizedAuthorization.saleConfigHash, expectedConfigHash)) {
    throw new Error("Refund authorization differs from the wrapped allowlist configuration");
  }
  const charge = nativeAllowlistRefundCharge(
    normalizedConfig.price,
    normalizedPolicy,
    selectedProof(normalizedInput.proofGroups, normalizedPolicy.counterId),
  );
  const payload = nativeRefundPurchaseAuthorizationPayload(
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
  const expectedPurchaseId = nativeRefundPurchaseId(
    normalizedChainId,
    normalizedAdapter,
    normalizedAuthorization.saleId,
    normalizedAuthorization.payer,
    normalizedAuthorization.purchaseNonce,
  );
  return Object.freeze({
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: normalizedAuthorization.payer,
    config: normalizedConfig,
    policy: normalizedPolicy,
    expectedRegistrationPolicyHash: registrationBaseline,
    authorization: normalizedAuthorization,
    input: normalizedInput,
    payload,
    expectedCharge: charge,
    resolverData,
    expectedPurchaseId,
    call: call(
      normalizedAdapter,
      "purchaseAllowlistRefundWindow",
      [purchaseData, resolverData],
      normalizedInput.priceFundingMaximum + normalizedInput.revealFeeAllowance,
    ),
  });
}

function samePreparedRegistration(
  value: PreparedNativeAllowlistRefundRegistration,
): PreparedNativeAllowlistRefundRegistration {
  exactKeys(value, [
    "chainId",
    "adapter",
    "caller",
    "expectedNonce",
    "config",
    "policy",
    "expectedPrimaryPolicyHash",
    "saleId",
    "windowPolicyHash",
    "originalConfigHash",
    "configHash",
    "expectedNonceMustBeLiveChecked",
    "expectedPolicyRequiresPostRegistrationReadback",
    "call",
  ], "prepared refund registration");
  const rebuilt = prepareNativeAllowlistRefundRegistration(
    value.chainId,
    value.adapter,
    value.caller,
    value.expectedNonce,
    value.config,
    value.policy,
    value.expectedPrimaryPolicyHash,
  );
  if (render(rebuilt) !== render(value)) {
    throw new Error("Prepared refund registration differs from canonical reconstruction");
  }
  return rebuilt;
}

function samePreparedPurchase(
  value: PreparedNativeAllowlistRefundPurchase,
): PreparedNativeAllowlistRefundPurchase {
  exactKeys(value, [
    "chainId",
    "adapter",
    "caller",
    "config",
    "policy",
    "expectedRegistrationPolicyHash",
    "authorization",
    "input",
    "payload",
    "expectedCharge",
    "resolverData",
    "expectedPurchaseId",
    "call",
  ], "prepared refund purchase");
  const rebuilt = prepareNativeAllowlistRefundPurchase(
    value.chainId,
    value.adapter,
    value.config,
    value.policy,
    value.expectedRegistrationPolicyHash,
    value.authorization,
    value.input,
  );
  if (render(rebuilt) !== render(value)) {
    throw new Error("Prepared refund purchase differs from canonical reconstruction");
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

function sameConfig(decoded: unknown, expected: NativeAllowlistRefundConfig): boolean {
  const value = tuple(decoded);
  return BigInt(value.collectionId as bigint) === expected.collectionId
    && same(value.phaseId, expected.phaseId)
    && BigInt(value.price as bigint) === expected.price
    && BigInt(value.maxSaleQuantity as bigint) === expected.maxSaleQuantity
    && BigInt(value.startsAt as bigint) === expected.startsAt
    && BigInt(value.endsAt as bigint) === expected.endsAt
    && BigInt(value.refundWindowSeconds as bigint) === expected.refundWindowSeconds
    && BigInt(value.finalizationWindowSeconds as bigint) === expected.finalizationWindowSeconds
    && BigInt(value.primaryPolicyMode as bigint) === expected.primaryPolicyMode
    && same(value.mintPolicyHash, expected.mintPolicyHash);
}

function recordInspection(value: unknown): NativeAllowlistRefundSaleRecordInspection {
  const record = tuple(value);
  return Object.freeze({
    saleNonce: BigInt(record.saleNonce as bigint),
    configHash: bytes32(record.configHash, "record configHash"),
    windowPolicyHash: bytes32(record.windowPolicyHash, "record windowPolicyHash"),
    purchasedQuantity: BigInt(record.purchasedQuantity as bigint),
    expectedPrimaryPolicyHash: bytes32(
      record.expectedPrimaryPolicyHash,
      "record expectedPrimaryPolicyHash",
    ),
  });
}

function assertSaleRecord(
  recordValue: unknown,
  policyValue: unknown,
  expected: {
    readonly chainId: bigint;
    readonly adapter: Address;
    readonly saleId: Hex;
    readonly config: NativeAllowlistRefundConfig;
    readonly policy: NativeAllowlistRefundPolicy;
    readonly expectedPrimaryPolicyHash: Hex;
    readonly configHash: Hex;
    readonly windowPolicyHash: Hex;
  },
): NativeAllowlistRefundSaleRecordInspection {
  const raw = tuple(recordValue);
  const policy = tuple(policyValue);
  const record = recordInspection(raw);
  const saleId = nativeAllowlistRefundSaleId(
    expected.chainId,
    expected.adapter,
    expected.config.collectionId,
    expected.config.phaseId,
    record.saleNonce,
  );
  const mismatch = record.saleNonce === 0n
    || !sameConfig(raw.config, expected.config)
    || !same(saleId, expected.saleId)
    || !same(record.configHash, expected.configHash)
    || !same(record.windowPolicyHash, expected.windowPolicyHash)
    || !same(record.expectedPrimaryPolicyHash, expected.expectedPrimaryPolicyHash)
    || !same(policy.counterId, expected.policy.counterId)
    || Boolean(policy.allowFree) !== expected.policy.allowFree;
  if (mismatch) {
    throw new Error("Stored refund allowlist sale differs from reviewed configuration");
  }
  return record;
}

export async function inspectNativeAllowlistRefundRegistration(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistRefundRegistration,
  options: { readonly blockTag: number },
): Promise<{
  readonly prepared: PreparedNativeAllowlistRefundRegistration;
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
    throw new Error("RPC chain differs from refund registration coordinates");
  }
  const [[owner], [nonce], [core], [manager], [entropy]] = await Promise.all([
    read(provider, prepared.adapter, refundAbi, "owner", [], blockTag),
    read(provider, prepared.adapter, refundAbi, "nextSaleNonce", [], blockTag),
    read(provider, prepared.adapter, refundAbi, "core", [], blockTag),
    read(provider, prepared.adapter, refundAbi, "mintManager", [], blockTag),
    read(provider, prepared.adapter, refundAbi, "entropyCoordinator", [], blockTag),
  ]);
  if (!same(owner, prepared.caller)) {
    throw new Error("Prepared caller is not the current refund adapter owner");
  }
  if (BigInt(nonce as bigint) !== prepared.expectedNonce) {
    throw new Error("Live refund sale nonce differs from the reviewed registration preimage");
  }
  return Object.freeze({
    prepared,
    core: address(core, "core"),
    mintManager: address(manager, "mintManager"),
    entropyCoordinator: address(entropy, "entropyCoordinator"),
    checked: Object.freeze([
      "RPC chain, adapter owner and live next sale nonce",
      "configured Core, Mint Manager and entropy coordinator addresses",
    ]),
    limitations: Object.freeze([
      "the expected registration primary policy requires post-registration refundSaleRecord readback",
      ...limitations,
    ]),
  });
}

export async function simulateNativeAllowlistRefundRegistration(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistRefundRegistration,
  options: { readonly blockTag: number },
): Promise<Hex> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectNativeAllowlistRefundRegistration(
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
    throw new Error("Malformed refund registration simulation return");
  }
  const decoded = refundAbi.decodeFunctionResult("registerAllowlistRefundSale", raw);
  const canonical = refundAbi.encodeFunctionResult("registerAllowlistRefundSale", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical refund registration simulation return");
  }
  const saleId = bytes32(decoded[0], "registered saleId", true);
  if (!same(saleId, prepared.saleId)) {
    throw new Error("Refund registration simulation returned an unexpected sale ID");
  }
  return saleId;
}

export async function inspectRegisteredNativeAllowlistRefundSale(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistRefundRegistration,
  options: { readonly blockTag: number },
): Promise<NativeAllowlistRefundSaleRecordInspection> {
  const prepared = samePreparedRegistration(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from refund registration coordinates");
  }
  const [[record], [policy]] = await Promise.all([
    read(provider, prepared.adapter, refundAbi, "refundSaleRecord", [prepared.saleId], blockTag),
    read(
      provider,
      prepared.adapter,
      refundAbi,
      "allowlistRefundSalePolicy",
      [prepared.saleId],
      blockTag,
    ),
  ]);
  return assertSaleRecord(record, policy, prepared);
}

export async function inspectNativeAllowlistRefundPurchase(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistRefundPurchase,
  options: { readonly blockTag: number },
): Promise<NativeAllowlistRefundPurchaseInspection> {
  const prepared = samePreparedPurchase(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from refund signing domain");
  }
  const saleId = prepared.authorization.saleId;
  const windowPolicyHash = nativeRefundWindowPolicyHash(prepared.config);
  const originalConfigHash = nativeRefundOriginalConfigHash(
    saleId,
    prepared.config,
    prepared.expectedRegistrationPolicyHash,
  );
  const configHash = nativeAllowlistRefundConfigHash(originalConfigHash, prepared.policy);
  const [[recordValue], [policyValue], [digest], [nextNonce], [core], [manager], [entropy]] = await Promise.all([
    read(provider, prepared.adapter, refundAbi, "refundSaleRecord", [saleId], blockTag),
    read(provider, prepared.adapter, refundAbi, "allowlistRefundSalePolicy", [saleId], blockTag),
    read(
      provider,
      prepared.adapter,
      refundAbi,
      "refundPurchaseAuthorizationDigest",
      [prepared.authorization],
      blockTag,
    ),
    read(
      provider,
      prepared.adapter,
      refundAbi,
      "nextPurchaseNonce",
      [saleId, prepared.authorization.payer],
      blockTag,
    ),
    read(provider, prepared.adapter, refundAbi, "core", [], blockTag),
    read(provider, prepared.adapter, refundAbi, "mintManager", [], blockTag),
    read(provider, prepared.adapter, refundAbi, "entropyCoordinator", [], blockTag),
  ]);
  const record = assertSaleRecord(recordValue, policyValue, {
    chainId: prepared.chainId,
    adapter: prepared.adapter,
    saleId,
    config: prepared.config,
    policy: prepared.policy,
    expectedPrimaryPolicyHash: prepared.expectedRegistrationPolicyHash,
    configHash,
    windowPolicyHash,
  });
  if (record.purchasedQuantity >= prepared.config.maxSaleQuantity) {
    throw new Error("Refund sale has reached its quantity limit");
  }
  if (!same(digest, prepared.payload.digest)) {
    throw new Error("Current refund digest getter differs from the signing payload");
  }
  if (BigInt(nextNonce as bigint) !== prepared.authorization.purchaseNonce) {
    throw new Error("Live payer purchase nonce differs from the signed refund nonce");
  }
  const entropyCoordinator = address(entropy, "entropyCoordinator");
  const [revealPolicyValue] = await read(
    provider,
    entropyCoordinator,
    entropyAbi,
    "collectionRevealPolicy",
    [prepared.config.collectionId],
    blockTag,
  );
  const revealPolicy = tuple(revealPolicyValue);
  if (!Boolean(revealPolicy.declared) || BigInt(revealPolicy.requestMode as bigint) > 1n) {
    throw new Error("Missing or unsupported refund reveal policy");
  }
  const revealFeePerTokenWei = uint(
    BigInt(revealPolicy.revealFeePerTokenWei as bigint),
    256,
    "reveal fee",
  );
  if (prepared.input.revealFeeAllowance < revealFeePerTokenWei) {
    throw new Error("Refund reveal fee allowance is below the pinned quote");
  }
  if (prepared.call.value < prepared.expectedCharge.chargedPrice + revealFeePerTokenWei) {
    throw new Error("Attached refund funding is below the selected charge and fee");
  }
  return Object.freeze({
    prepared,
    record,
    core: address(core, "core"),
    mintManager: address(manager, "mintManager"),
    entropyCoordinator,
    revealFeePerTokenWei,
    effectivePriceFundingMaximum: prepared.call.value - revealFeePerTokenWei,
    checked: purchaseChecked,
    limitations,
  });
}

export async function simulateNativeAllowlistRefundPurchase(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistRefundPurchase,
  options: { readonly blockTag: number },
): Promise<Hex> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectNativeAllowlistRefundPurchase(
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
    throw new Error("Malformed refund purchase simulation return");
  }
  const decoded = refundAbi.decodeFunctionResult("purchaseAllowlistRefundWindow", raw);
  const canonical = refundAbi.encodeFunctionResult("purchaseAllowlistRefundWindow", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical refund purchase simulation return");
  }
  const purchaseId = bytes32(decoded[0], "purchaseId", true);
  if (!same(purchaseId, prepared.expectedPurchaseId)) {
    throw new Error("Refund purchase simulation returned an unexpected purchase ID");
  }
  return purchaseId;
}

function lifecycleAction(
  kind: NativeRefundLifecycleActionKind,
  adapter: Address,
  caller: Address,
  method: string,
  args: readonly unknown[],
  fields: {
    readonly purchaseId?: Hex;
    readonly saleId?: Hex;
    readonly recipient?: Address;
    readonly unlockReason?: bigint;
  },
): PreparedNativeRefundLifecycleAction {
  return Object.freeze({
    kind,
    adapter: address(adapter, "adapter"),
    caller: address(caller, "caller"),
    purchaseId: fields.purchaseId ?? null,
    saleId: fields.saleId ?? null,
    recipient: fields.recipient ?? null,
    unlockReason: fields.unlockReason ?? null,
    call: call(adapter, method, args),
  });
}

export function prepareNativeRefundFinalize(
  adapter: Address,
  purchaseId: Hex,
  caller: Address,
): PreparedNativeRefundLifecycleAction {
  const id = bytes32(purchaseId, "purchaseId", true);
  return lifecycleAction("finalize", adapter, caller, "finalizeRefundWindow", [id], {
    purchaseId: id,
  });
}

export function prepareNativeRefundRefund(
  adapter: Address,
  purchaseId: Hex,
  payer: Address,
): PreparedNativeRefundLifecycleAction {
  const id = bytes32(purchaseId, "purchaseId", true);
  return lifecycleAction("refund", adapter, payer, "refundPurchase", [id], {
    purchaseId: id,
  });
}

export function prepareNativeRefundUnlock(
  adapter: Address,
  purchaseId: Hex,
  reason: bigint,
  caller: Address,
): PreparedNativeRefundLifecycleAction {
  const id = bytes32(purchaseId, "purchaseId", true);
  const normalizedReason = uint(reason, 8, "unlock reason");
  if (normalizedReason > 5n) {
    throw new Error("Unsupported refund unlock reason");
  }
  return lifecycleAction(
    "unlock",
    adapter,
    caller,
    "unlockRefund",
    [id, normalizedReason],
    { purchaseId: id, unlockReason: normalizedReason },
  );
}

export function prepareNativeRefundSynchronize(
  adapter: Address,
  purchaseId: Hex,
  caller: Address,
): PreparedNativeRefundLifecycleAction {
  const id = bytes32(purchaseId, "purchaseId", true);
  return lifecycleAction("synchronize", adapter, caller, "synchronizePurchaseWindow", [id], {
    purchaseId: id,
  });
}

export function prepareNativeRefundClaim(
  adapter: Address,
  saleId: Hex,
  creditedPayer: Address,
  recipient: Address,
): PreparedNativeRefundLifecycleAction {
  const id = bytes32(saleId, "saleId", true);
  const destination = address(recipient, "refund recipient");
  if (same(destination, adapter)) {
    throw new Error("Refund recipient cannot be the adapter");
  }
  return lifecycleAction(
    "claim",
    adapter,
    creditedPayer,
    "claimRefund",
    [id, destination],
    { saleId: id, recipient: destination },
  );
}

export async function readNativeRefundCredit(
  provider: Pick<Provider, "call">,
  adapter: Address,
  saleId: Hex,
  creditedPayer: Address,
  options: { readonly blockTag: number },
): Promise<bigint> {
  const blockTag = concreteBlock(options.blockTag);
  const [balance] = await read(
    provider,
    address(adapter, "adapter"),
    refundAbi,
    "refundableBalance",
    [bytes32(saleId, "saleId", true), address(creditedPayer, "credited payer")],
    blockTag,
  );
  return uint(BigInt(balance as bigint), 256, "refundable balance");
}
