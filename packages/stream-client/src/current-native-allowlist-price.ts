import { AbiCoder, Interface, ZeroAddress, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { SigningPayload } from "./signing.js";
import type { NativePriceProgramAuthorization } from "./current-signing.js";
import { prepareNativeImmediateSale } from "./current-native-sales.js";
import { mintAllowlistResolverData } from "./current-mint-gates.js";
import type { MintAllowlistProof } from "./current-mint-gates.js";

export const NATIVE_ALLOWLIST_PRICE_KIND = Object.freeze({
  FIXED: 0n,
  OPEN_EDITION: 1n,
  ZERO_PRICE: 12n,
  PAY_WHAT_YOU_WANT: 13n,
} as const);
export const NATIVE_ALLOWLIST_PRICE_MAX_GROUPS = 16;

export interface NativeAllowlistPriceProgramConfig {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly kind: bigint;
  readonly minUnitPrice: bigint;
  readonly maxUnitPrice: bigint;
  readonly maxSaleQuantity: bigint;
  readonly startsAt: bigint;
  readonly endsAt: bigint;
  readonly closeRule: bigint;
  readonly mintPolicyHash: Hex;
  readonly primaryAssignmentHash: Hex;
}

export interface NativeAllowlistPricePolicy {
  readonly counterId: Hex;
  readonly allowFree: boolean;
}

/** Counter IDs are unchecked caller labels used for local price selection; resolver witness positions are what the contract validates. */
export interface NativeAllowlistPriceProofGroup {
  readonly counterId: Hex;
  readonly proof: MintAllowlistProof;
}

export interface NativeAllowlistPriceMatrix {
  readonly overridden: boolean;
  readonly effectiveMinimum: bigint;
  readonly effectiveMaximum: bigint;
}

export interface PreparedNativeAllowlistPriceRegistration {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly expectedNonce: bigint;
  readonly config: NativeAllowlistPriceProgramConfig;
  readonly policy: NativeAllowlistPricePolicy;
  readonly saleId: Hex;
  readonly originalConfigHash: Hex;
  readonly configHash: Hex;
  readonly expectedNonceMustBeLiveChecked: true;
  readonly call: UnsignedCall;
}

export interface NativeAllowlistPricePurchaseInput {
  readonly chosenUnitPrice: bigint;
  readonly tokenData: Hex;
  readonly platformSignature: Hex;
  readonly artistSignature: Hex;
  readonly revealFeeAllowance: bigint;
  readonly proofGroups: readonly NativeAllowlistPriceProofGroup[];
}

export interface PreparedNativeAllowlistPricePurchase {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly config: NativeAllowlistPriceProgramConfig;
  readonly policy: NativeAllowlistPricePolicy;
  readonly authorization: NativePriceProgramAuthorization;
  readonly input: NativeAllowlistPricePurchaseInput;
  readonly payload: SigningPayload<NativePriceProgramAuthorization>;
  readonly resolverData: Hex;
  readonly chargedAmount: bigint;
  readonly call: UnsignedCall;
}

export interface NativeAllowlistPriceProgramResult {
  readonly revenueOutcome: bigint;
  readonly executionId: Hex;
  readonly operationRoot: Hex;
  readonly operationId: Hex;
  readonly tokenId: bigint;
  readonly chargedAmount: bigint;
  readonly settlementKey: Hex;
  readonly escrowed: boolean;
}

export interface NativeAllowlistPriceRegistrationInspection {
  readonly prepared: PreparedNativeAllowlistPriceRegistration;
  readonly core: Address;
  readonly mintManager: Address;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}

export interface NativeAllowlistPricePurchaseInspection {
  readonly prepared: PreparedNativeAllowlistPricePurchase;
  readonly core: Address;
  readonly mintManager: Address;
  readonly revealFeePerTokenWei: bigint;
  readonly preview: NativeAllowlistPriceProgramResult;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}

const coder = AbiCoder.defaultAbiCoder();
const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const MAX_BYTES = 4_194_304;
const configTuple = "tuple(uint256 collectionId,bytes32 phaseId,uint8 kind,uint256 minUnitPrice,uint256 maxUnitPrice,uint64 maxSaleQuantity,uint64 startsAt,uint64 endsAt,uint8 closeRule,bytes32 mintPolicyHash,bytes32 primaryAssignmentHash)";
const policyTuple = "tuple(bytes32 counterId,bool allowFree)";
const authorizationTuple = "tuple(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice)";
const executionTuple = `tuple(${authorizationTuple} authorization,uint256 chosenUnitPrice,bytes tokenData,bytes platformSignature,bytes artistSignature)`;
const resultTuple = "tuple(uint8 revenueOutcome,bytes32 executionId,bytes32 operationRoot,bytes32 operationId,uint256 tokenId,uint256 chargedAmount,bytes32 settlementKey,bool escrowed)";
const recordTuple = `tuple(${configTuple} config,uint256 saleNonce,bytes32 configHash,tuple(uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision) lifecycle,uint64 mintedQuantity,bool closed)`;
const revealTuple = "tuple(address coordinator,bytes32 coordinatorCodeHash,tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei) policy)";
const abi = new Interface([
  `function registerAllowlistPriceProgram(${configTuple},${policyTuple}) returns (bytes32)`,
  `function allowlistPricePolicy(bytes32) view returns (${policyTuple})`,
  `function previewAllowlistPriceProgram(${executionTuple},bytes) view returns (${resultTuple})`,
  `function executeAllowlistPriceProgram(${executionTuple},bytes) payable returns (${resultTuple})`,
  "function priceProgramIdFor(uint256,bytes32,uint8,uint256) view returns (bytes32)",
  `function priceProgramRecord(bytes32) view returns (${recordTuple})`,
  `function priceProgramAuthorizationDigest(${authorizationTuple}) view returns (bytes32)`,
  `function saleRevealQuote(bytes32) view returns (${revealTuple})`,
  "function nextSaleNonce() view returns (uint256)",
  "function owner() view returns (address)",
  "function core() view returns (address)",
  "function mintManager() view returns (address)",
]);
const domains = Object.freeze({
  sale: id("6529STREAM_SALE_V1") as Hex,
  originalConfig: id("6529STREAM_NATIVE_PRICE_PROGRAM_CONFIG_V1") as Hex,
  allowlistConfig: id("6529STREAM_NATIVE_ALLOWLIST_PRICE_PROGRAM_CONFIG_V1") as Hex,
});
const registrationChecked = Object.freeze([
  "RPC chain and adapter owner",
  "live next sale nonce",
  "canonical sale ID getter",
  "configured Core and Mint Manager addresses",
]);
const purchaseChecked = Object.freeze([
  "RPC chain",
  "stored price-program config, policy, nonce and ID",
  "current authorization digest",
  "declared reveal quote and fee allowance",
  "canonical allowlist preview including current signature, proof, phase and price validation",
]);
const limitations = Object.freeze([
  "numeric block pin has no reorg hash check",
  "proof counter IDs are unchecked caller metadata; canonical preview validates only each positional witness against the live filtered Merkle-counter order",
  "runtime code identity, Safe threshold authority, inclusion-time state and transaction acceptance are outside read-only inspection",
]);

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
  if (typeof value !== "string" || !isHexString(value, 32) || (nonzero && value.toLowerCase() === ZERO32)) {
    throw new Error(`${name} must be ${nonzero ? "a nonzero" : "a"} bytes32`);
  }
  return value as Hex;
}
function bytes(value: unknown, name: string): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > MAX_BYTES) {
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
function same(a: unknown, b: string): boolean {
  return typeof a === "string" && a.toLowerCase() === b.toLowerCase();
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
function call(adapter: Address, method: string, args: readonly unknown[], value = 0n): UnsignedCall {
  return Object.freeze({
    to: address(adapter, "adapter"),
    data: abi.encodeFunctionData(method, args) as Hex,
    value: uint(value, 256, "call value"),
  });
}
function normalizeConfig(value: NativeAllowlistPriceProgramConfig): NativeAllowlistPriceProgramConfig {
  exactKeys(value, [
    "collectionId",
    "phaseId",
    "kind",
    "minUnitPrice",
    "maxUnitPrice",
    "maxSaleQuantity",
    "startsAt",
    "endsAt",
    "closeRule",
    "mintPolicyHash",
    "primaryAssignmentHash",
  ], "price program config");
  const output = Object.freeze({
    collectionId: uint(value.collectionId, 256, "collectionId", true),
    phaseId: bytes32(value.phaseId, "phaseId", true),
    kind: uint(value.kind, 8, "kind"),
    minUnitPrice: uint(value.minUnitPrice, 256, "minUnitPrice"),
    maxUnitPrice: uint(value.maxUnitPrice, 256, "maxUnitPrice"),
    maxSaleQuantity: uint(value.maxSaleQuantity, 64, "maxSaleQuantity"),
    startsAt: uint(value.startsAt, 64, "startsAt"),
    endsAt: uint(value.endsAt, 64, "endsAt"),
    closeRule: uint(value.closeRule, 8, "closeRule"),
    mintPolicyHash: bytes32(value.mintPolicyHash, "mintPolicyHash", true),
    primaryAssignmentHash: bytes32(value.primaryAssignmentHash, "primaryAssignmentHash"),
  });
  if (![0n, 1n, 12n, 13n].includes(output.kind)) {
    throw new Error("Unsupported native price program kind");
  }
  if ((output.kind === 1n) !== (output.maxSaleQuantity === 0n)) {
    throw new Error("Only open edition uses a zero maximum sale quantity");
  }
  if (output.closeRule !== 1n && output.closeRule !== 2n) {
    throw new Error("closeRule must be TIME (1) or MANUAL (2)");
  }
  const invalidTimeWindow = output.closeRule === 1n
    ? output.endsAt <= output.startsAt
    : output.endsAt !== 0n;
  if (invalidTimeWindow) {
    throw new Error("Invalid price program time window");
  }
  if (output.kind === 12n) {
    if (output.minUnitPrice !== 0n || output.maxUnitPrice !== 0n || output.primaryAssignmentHash !== ZERO32) {
      throw new Error("Zero-price kind requires a zero band and assignment");
    }
  } else if (output.maxUnitPrice === 0n || output.minUnitPrice > output.maxUnitPrice
    || (output.kind !== 13n && (output.minUnitPrice === 0n || output.minUnitPrice !== output.maxUnitPrice))) {
    throw new Error("Invalid native price program band");
  }
  return output;
}
function normalizePolicy(value: NativeAllowlistPricePolicy, kind?: bigint): NativeAllowlistPricePolicy {
  exactKeys(value, ["counterId", "allowFree"], "allowlist price policy");
  const output = Object.freeze({
    counterId: bytes32(value.counterId, "counterId", true),
    allowFree: boolean(value.allowFree, "allowFree"),
  });
  if (kind !== undefined && output.allowFree && kind !== 0n && kind !== 1n) {
    throw new Error("allowFree is supported only for fixed/open-edition kinds");
  }
  return output;
}
function normalizeAuthorization(value: NativePriceProgramAuthorization): NativePriceProgramAuthorization {
  exactKeys(value, [
    "saleId",
    "saleConfigHash",
    "payer",
    "executor",
    "recipient",
    "artist",
    "tokenDataHash",
    "mintCommitment",
    "executionNonce",
    "nonce",
    "deadline",
    "expectedPrimaryPolicyHash",
    "unitPrice",
  ], "native price authorization");
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
    expectedPrimaryPolicyHash: bytes32(value.expectedPrimaryPolicyHash, "expectedPrimaryPolicyHash"),
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
    throw new Error("A disabled price override must be zero");
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
function normalizeGroups(value: readonly NativeAllowlistPriceProofGroup[], selectedId: Hex): readonly NativeAllowlistPriceProofGroup[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > NATIVE_ALLOWLIST_PRICE_MAX_GROUPS) {
    throw new Error("proofGroups must contain 1 through 16 filtered Merkle groups");
  }
  const seen = new Set<string>();
  let selected = 0;
  const output = value.map((group, index) => {
    exactKeys(group, ["counterId", "proof"], `proofGroups[${index}]`);
    const counterId = bytes32(group.counterId, `proofGroups[${index}].counterId`, true);
    const key = counterId.toLowerCase();
    if (seen.has(key)) {
      throw new Error("Proof counter IDs must be unique");
    }
    seen.add(key);
    const proof = normalizeProof(
      group.proof as unknown as MintAllowlistProof,
      `proofGroups[${index}].proof`,
    );
    if (same(counterId, selectedId)) {
      selected++;
    } else if (proof.hasPriceOverride) {
      throw new Error("Only the selected price counter may enable a price override");
    }
    return Object.freeze({ counterId, proof });
  });
  if (selected !== 1) {
    throw new Error("proofGroups must contain the selected price counter exactly once");
  }
  return Object.freeze(output);
}

export function nativeAllowlistPriceSaleId(
  chainId: bigint,
  adapter: Address,
  config: NativeAllowlistPriceProgramConfig,
  expectedNonce: bigint,
): Hex {
  const c = normalizeConfig(config);
  const encoded = coder.encode(
    ["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [
      domains.sale,
      uint(chainId, 256, "chainId", true),
      address(adapter, "adapter"),
      c.kind,
      c.collectionId,
      c.phaseId,
      uint(expectedNonce, 256, "expectedNonce", true),
    ],
  );
  return keccak256(encoded) as Hex;
}
export function nativePriceProgramOriginalConfigHash(saleId: Hex, config: NativeAllowlistPriceProgramConfig): Hex {
  const encoded = coder.encode(
    ["bytes32", "bytes32", configTuple],
    [domains.originalConfig, bytes32(saleId, "saleId", true), normalizeConfig(config)],
  );
  return keccak256(encoded) as Hex;
}
export function nativeAllowlistPriceProgramConfigHash(originalConfigHash: Hex, policy: NativeAllowlistPricePolicy): Hex {
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
export function nativeAllowlistPriceMatrix(
  config: NativeAllowlistPriceProgramConfig,
  policy: NativeAllowlistPricePolicy,
  authorizationUnitPrice: bigint,
  selectedProof: MintAllowlistProof,
): NativeAllowlistPriceMatrix {
  const c = normalizeConfig(config);
  const p = normalizePolicy(policy, c.kind);
  const signed = uint(authorizationUnitPrice, 256, "authorizationUnitPrice");
  const proof = normalizeProof(selectedProof, "selectedProof");
  let minimum = c.minUnitPrice;
  let maximum = c.maxUnitPrice;
  if (c.kind === 13n) {
    const authorizedMinimum = proof.hasPriceOverride ? proof.priceOverride : signed;
    if (authorizedMinimum > minimum) {
      minimum = authorizedMinimum;
    }
  } else {
    if (signed !== minimum) {
      throw new Error("Signed unit price differs from the original public price");
    }
    if (proof.hasPriceOverride) {
      if (c.kind === 12n && proof.priceOverride !== 0n) {
        throw new Error("Zero-price kind accepts only a zero leaf price");
      }
      const undeclaredFreeOverride = (c.kind === 0n || c.kind === 1n)
        && proof.priceOverride === 0n
        && !p.allowFree;
      if (undeclaredFreeOverride) {
        throw new Error("Zero fixed/open override was not declared at creation");
      }
      minimum = proof.priceOverride;
      maximum = proof.priceOverride;
    }
  }
  return Object.freeze({
    overridden: proof.hasPriceOverride,
    effectiveMinimum: minimum,
    effectiveMaximum: maximum,
  });
}

export function prepareNativeAllowlistPriceRegistration(
  chainId: bigint,
  adapter: Address,
  owner: Address,
  expectedNonce: bigint,
  config: NativeAllowlistPriceProgramConfig,
  policy: NativeAllowlistPricePolicy,
): PreparedNativeAllowlistPriceRegistration {
  const c = normalizeConfig(config);
  const p = normalizePolicy(policy, c.kind);
  const normalizedChain = uint(chainId, 256, "chainId", true);
  const target = address(adapter, "adapter");
  const caller = address(owner, "owner");
  const nonce = uint(expectedNonce, 256, "expectedNonce", true);
  const saleId = nativeAllowlistPriceSaleId(normalizedChain, target, c, nonce);
  const originalConfigHash = nativePriceProgramOriginalConfigHash(saleId, c);
  const configHash = nativeAllowlistPriceProgramConfigHash(originalConfigHash, p);
  return Object.freeze({
    chainId: normalizedChain,
    adapter: target,
    caller,
    expectedNonce: nonce,
    config: c,
    policy: p,
    saleId,
    originalConfigHash,
    configHash,
    expectedNonceMustBeLiveChecked: true,
    call: call(target, "registerAllowlistPriceProgram", [c, p]),
  });
}

function normalizePurchaseInput(
  value: NativeAllowlistPricePurchaseInput,
  policy: NativeAllowlistPricePolicy,
): NativeAllowlistPricePurchaseInput {
  exactKeys(value, [
    "chosenUnitPrice",
    "tokenData",
    "platformSignature",
    "artistSignature",
    "revealFeeAllowance",
    "proofGroups",
  ], "allowlist price purchase input");
  return Object.freeze({
    chosenUnitPrice: uint(value.chosenUnitPrice, 256, "chosenUnitPrice"),
    tokenData: bytes(value.tokenData, "tokenData"),
    platformSignature: bytes(value.platformSignature, "platformSignature"),
    artistSignature: bytes(value.artistSignature, "artistSignature"),
    revealFeeAllowance: uint(value.revealFeeAllowance, 256, "revealFeeAllowance"),
    proofGroups: normalizeGroups(value.proofGroups, policy.counterId),
  });
}
export function prepareNativeAllowlistPricePurchase(
  chainId: bigint,
  adapter: Address,
  config: NativeAllowlistPriceProgramConfig,
  policy: NativeAllowlistPricePolicy,
  authorization: NativePriceProgramAuthorization,
  input: NativeAllowlistPricePurchaseInput,
): PreparedNativeAllowlistPricePurchase {
  const c = normalizeConfig(config);
  const p = normalizePolicy(policy, c.kind);
  const a = normalizeAuthorization(authorization);
  const x = normalizePurchaseInput(input, p);
  if (!same(a.payer, a.executor)) {
    throw new Error("Allowlist price purchase requires payer, executor and actual caller to match");
  }
  const original = nativePriceProgramOriginalConfigHash(a.saleId, c);
  const expectedHash = nativeAllowlistPriceProgramConfigHash(original, p);
  if (!same(a.saleConfigHash, expectedHash)) {
    throw new Error("Authorization saleConfigHash differs from the wrapped allowlist price configuration");
  }
  const selected = x.proofGroups.find(group => same(group.counterId, p.counterId))!;
  const matrix = nativeAllowlistPriceMatrix(c, p, a.unitPrice, selected.proof);
  if (x.chosenUnitPrice < matrix.effectiveMinimum || x.chosenUnitPrice > matrix.effectiveMaximum) {
    throw new Error("Chosen price is outside the effective allowlist price band");
  }
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const base = prepareNativeImmediateSale(
    "nativePriceProgram",
    normalizedChainId,
    normalizedAdapter,
    a,
    {
      tokenData: x.tokenData,
      platformSignature: x.platformSignature,
      artistSignature: x.artistSignature,
      saleAmount: x.chosenUnitPrice,
      revealFeeAllowance: x.revealFeeAllowance,
    },
  );
  const resolverData = mintAllowlistResolverData(x.proofGroups.map(group => [group.proof]));
  const execution = Object.freeze({
    authorization: a,
    chosenUnitPrice: x.chosenUnitPrice,
    tokenData: x.tokenData,
    platformSignature: x.platformSignature,
    artistSignature: x.artistSignature,
  });
  return Object.freeze({
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: a.payer,
    config: c,
    policy: p,
    authorization: a,
    input: x,
    payload: base.payload,
    resolverData,
    chargedAmount: x.chosenUnitPrice,
    call: call(
      normalizedAdapter,
      "executeAllowlistPriceProgram",
      [execution, resolverData],
      x.chosenUnitPrice + x.revealFeeAllowance,
    ),
  });
}

function samePreparedRegistration(value: PreparedNativeAllowlistPriceRegistration): PreparedNativeAllowlistPriceRegistration {
  exactKeys(value, [
    "chainId",
    "adapter",
    "caller",
    "expectedNonce",
    "config",
    "policy",
    "saleId",
    "originalConfigHash",
    "configHash",
    "expectedNonceMustBeLiveChecked",
    "call",
  ], "prepared registration");
  const rebuilt = prepareNativeAllowlistPriceRegistration(
    value.chainId,
    value.adapter,
    value.caller,
    value.expectedNonce,
    value.config,
    value.policy,
  );
  if (render(rebuilt) !== render(value)) {
    throw new Error("Prepared registration differs from canonical reconstruction");
  }
  return rebuilt;
}
function samePreparedPurchase(value: PreparedNativeAllowlistPricePurchase): PreparedNativeAllowlistPricePurchase {
  exactKeys(value, [
    "chainId",
    "adapter",
    "caller",
    "config",
    "policy",
    "authorization",
    "input",
    "payload",
    "resolverData",
    "chargedAmount",
    "call",
  ], "prepared purchase");
  const rebuilt = prepareNativeAllowlistPricePurchase(
    value.chainId,
    value.adapter,
    value.config,
    value.policy,
    value.authorization,
    value.input,
  );
  if (render(rebuilt) !== render(value)) {
    throw new Error("Prepared purchase differs from canonical reconstruction");
  }
  return rebuilt;
}
async function read(
  provider: Pick<Provider, "call">,
  target: Address,
  method: string,
  args: readonly unknown[],
  blockTag: number,
  from?: Address,
): Promise<readonly unknown[]> {
  const transaction = {
    to: target,
    data: abi.encodeFunctionData(method, args),
    blockTag,
    ...(from === undefined ? {} : { from }),
  };
  const raw = await provider.call(transaction);
  if (typeof raw !== "string" || !isHexString(raw, true)) {
    throw new Error(`Malformed ${method} return`);
  }
  const decoded = abi.decodeFunctionResult(method, raw);
  const canonical = abi.encodeFunctionResult(method, decoded);
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
function sameConfig(decoded: unknown, expected: NativeAllowlistPriceProgramConfig): boolean {
  const x = tuple(decoded);
  return BigInt(x.collectionId as bigint) === expected.collectionId
    && same(x.phaseId, expected.phaseId)
    && BigInt(x.kind as bigint) === expected.kind
    && BigInt(x.minUnitPrice as bigint) === expected.minUnitPrice
    && BigInt(x.maxUnitPrice as bigint) === expected.maxUnitPrice
    && BigInt(x.maxSaleQuantity as bigint) === expected.maxSaleQuantity
    && BigInt(x.startsAt as bigint) === expected.startsAt
    && BigInt(x.endsAt as bigint) === expected.endsAt
    && BigInt(x.closeRule as bigint) === expected.closeRule
    && same(x.mintPolicyHash, expected.mintPolicyHash)
    && same(x.primaryAssignmentHash, expected.primaryAssignmentHash);
}
function decodeResult(value: unknown): NativeAllowlistPriceProgramResult {
  const x = tuple(value);
  return Object.freeze({
    revenueOutcome: BigInt(x.revenueOutcome as bigint),
    executionId: bytes32(x.executionId, "executionId"),
    operationRoot: bytes32(x.operationRoot, "operationRoot"),
    operationId: bytes32(x.operationId, "operationId"),
    tokenId: BigInt(x.tokenId as bigint),
    chargedAmount: BigInt(x.chargedAmount as bigint),
    settlementKey: bytes32(x.settlementKey, "settlementKey"),
    escrowed: Boolean(x.escrowed),
  });
}
function executionFor(prepared: PreparedNativeAllowlistPricePurchase): object {
  return Object.freeze({
    authorization: prepared.authorization,
    chosenUnitPrice: prepared.input.chosenUnitPrice,
    tokenData: prepared.input.tokenData,
    platformSignature: prepared.input.platformSignature,
    artistSignature: prepared.input.artistSignature,
  });
}

export async function inspectNativeAllowlistPriceRegistration(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistPriceRegistration,
  options: { readonly blockTag: number },
): Promise<NativeAllowlistPriceRegistrationInspection> {
  const prepared = samePreparedRegistration(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from registration coordinates");
  }
  const [[owner], [nonce], [saleId], [core], [manager]] = await Promise.all([
    read(provider, prepared.adapter, "owner", [], blockTag),
    read(provider, prepared.adapter, "nextSaleNonce", [], blockTag),
    read(
      provider,
      prepared.adapter,
      "priceProgramIdFor",
      [
        prepared.config.collectionId,
        prepared.config.phaseId,
        prepared.config.kind,
        prepared.expectedNonce,
      ],
      blockTag,
    ),
    read(provider, prepared.adapter, "core", [], blockTag),
    read(provider, prepared.adapter, "mintManager", [], blockTag),
  ]);
  if (!same(owner, prepared.caller)) {
    throw new Error("Prepared caller is not the current adapter owner");
  }
  if (BigInt(nonce as bigint) !== prepared.expectedNonce) {
    throw new Error("Live sale nonce differs from the reviewed registration preimage");
  }
  if (!same(saleId, prepared.saleId)) {
    throw new Error("Canonical sale ID getter differs from local recomputation");
  }
  return Object.freeze({
    prepared,
    core: address(core, "core"),
    mintManager: address(manager, "mintManager"),
    checked: registrationChecked,
    limitations,
  });
}
export async function simulateNativeAllowlistPriceRegistration(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistPriceRegistration,
  options: { readonly blockTag: number },
): Promise<Hex> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectNativeAllowlistPriceRegistration(
    provider,
    preparedInput,
    { blockTag },
  );
  const prepared = inspected.prepared;
  const raw = await provider.call({ ...prepared.call, from: prepared.caller, blockTag });
  if (typeof raw !== "string" || !isHexString(raw, true)) {
    throw new Error("Malformed registration simulation return");
  }
  const decoded = abi.decodeFunctionResult("registerAllowlistPriceProgram", raw);
  const canonical = abi.encodeFunctionResult("registerAllowlistPriceProgram", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical registration simulation return");
  }
  const saleId = bytes32(decoded[0], "registered saleId", true);
  if (!same(saleId, prepared.saleId)) {
    throw new Error("Registration simulation returned an unexpected sale ID");
  }
  return saleId;
}

export async function inspectNativeAllowlistPricePurchase(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistPricePurchase,
  options: { readonly blockTag: number },
): Promise<NativeAllowlistPricePurchaseInspection> {
  const prepared = samePreparedPurchase(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const execution = executionFor(prepared);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from purchase signing domain");
  }
  const [[recordValue], [policyValue], [digest], [quoteValue], [previewValue], [core], [manager]] = await Promise.all([
    read(provider, prepared.adapter, "priceProgramRecord", [prepared.authorization.saleId], blockTag),
    read(provider, prepared.adapter, "allowlistPricePolicy", [prepared.authorization.saleId], blockTag),
    read(provider, prepared.adapter, "priceProgramAuthorizationDigest", [prepared.authorization], blockTag),
    read(provider, prepared.adapter, "saleRevealQuote", [prepared.authorization.saleId], blockTag),
    read(
      provider,
      prepared.adapter,
      "previewAllowlistPriceProgram",
      [execution, prepared.resolverData],
      blockTag,
      prepared.caller,
    ),
    read(provider, prepared.adapter, "core", [], blockTag),
    read(provider, prepared.adapter, "mintManager", [], blockTag),
  ]);
  const record = tuple(recordValue);
  const saleNonce = BigInt(record.saleNonce as bigint);
  const recordMismatch = saleNonce === 0n
    || !sameConfig(record.config, prepared.config)
    || !same(record.configHash, prepared.authorization.saleConfigHash)
    || Boolean(record.closed);
  if (recordMismatch) {
    throw new Error("Stored price program differs from the prepared current record");
  }
  const soldOut = prepared.config.maxSaleQuantity !== 0n
    && BigInt(record.mintedQuantity as bigint) >= prepared.config.maxSaleQuantity;
  if (soldOut) {
    throw new Error("Stored price program has reached its sale quantity");
  }
  const livePolicy = tuple(policyValue);
  const policyMismatch = !same(livePolicy.counterId, prepared.policy.counterId)
    || Boolean(livePolicy.allowFree) !== prepared.policy.allowFree;
  if (policyMismatch) {
    throw new Error("Stored allowlist price policy differs from the prepared policy");
  }
  const expectedId = nativeAllowlistPriceSaleId(prepared.chainId, prepared.adapter, prepared.config, saleNonce);
  if (!same(expectedId, prepared.authorization.saleId)) {
    throw new Error("Stored sale nonce does not reconstruct the authorized sale ID");
  }
  const [actualCanonicalId] = await read(
    provider,
    prepared.adapter,
    "priceProgramIdFor",
    [
      prepared.config.collectionId,
      prepared.config.phaseId,
      prepared.config.kind,
      saleNonce,
    ],
    blockTag,
  );
  if (!same(actualCanonicalId, expectedId)) {
    throw new Error("Canonical price program ID getter differs from current record");
  }
  if (!same(digest, prepared.payload.digest)) {
    throw new Error("Current digest getter differs from the reviewed signing payload");
  }
  const quote = tuple(quoteValue);
  const quotePolicy = tuple(quote.policy);
  const unsupportedRevealPolicy = !Boolean(quotePolicy.declared)
    || BigInt(quotePolicy.requestMode as bigint) > 1n;
  if (unsupportedRevealPolicy) {
    throw new Error("Missing or unsupported reveal policy");
  }
  const revealFee = BigInt(quotePolicy.revealFeePerTokenWei as bigint);
  if (prepared.input.revealFeeAllowance < revealFee) {
    throw new Error("Reveal fee allowance is below the pinned quote");
  }
  const preview = decodeResult(previewValue);
  if (preview.chargedAmount !== prepared.chargedAmount) {
    throw new Error("Canonical preview charged amount differs from the prepared price");
  }
  return Object.freeze({
    prepared,
    core: address(core, "core"),
    mintManager: address(manager, "mintManager"),
    revealFeePerTokenWei: revealFee,
    preview,
    checked: purchaseChecked,
    limitations,
  });
}
export async function simulateNativeAllowlistPricePurchase(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedNativeAllowlistPricePurchase,
  options: { readonly blockTag: number },
): Promise<NativeAllowlistPriceProgramResult> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectNativeAllowlistPricePurchase(
    provider,
    preparedInput,
    { blockTag },
  );
  const prepared = inspected.prepared;
  const raw = await provider.call({ ...prepared.call, from: prepared.caller, blockTag });
  if (typeof raw !== "string" || !isHexString(raw, true)) {
    throw new Error("Malformed purchase simulation return");
  }
  const decoded = abi.decodeFunctionResult("executeAllowlistPriceProgram", raw);
  const canonical = abi.encodeFunctionResult("executeAllowlistPriceProgram", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical purchase simulation return");
  }
  const result = decodeResult(decoded[0]);
  if (result.chargedAmount !== prepared.chargedAmount) {
    throw new Error("Execution simulation charged amount differs from the prepared price");
  }
  return result;
}
