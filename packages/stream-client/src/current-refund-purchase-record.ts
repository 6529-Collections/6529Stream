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
import {
  nativeRefundPurchaseAuthorizationPayload,
  nativeRefundPurchaseId,
  type NativeRefundPurchaseAuthorization,
} from "./current-native-allowlist-refund.js";
import type { SigningPayload } from "./signing.js";
import type { MintAllowlistProof } from "./current-mint-gates.js";

export const REFUND_RECORD_MAX_RESOLVER_BYTES = 4_194_304;
export const REFUND_RECORD_MAX_RAW_RETURN_BYTES = REFUND_RECORD_MAX_RESOLVER_BYTES + 65_536;
export const REFUND_RECORD_MAX_PROOF_GROUPS = 16;
export const REFUND_RECORD_MAX_PROOF_NODES = 256;

export interface RefundPurchaseCapture {
  readonly savedRevealFee: bigint;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly referencedGate: Address;
}

export interface StoredNativeRefundPurchaseRecord {
  readonly authorization: NativeRefundPurchaseAuthorization;
  readonly authorizationDigest: Hex;
  readonly purchaseRecordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly referencedGate: Address;
  readonly tokenData: Hex;
  readonly savedRevealFee: bigint;
  readonly purchasedAt: bigint;
  readonly pauseBaseline: bigint;
  readonly nominalRefundDeadline: bigint;
  readonly nominalFinalizeBy: bigint;
  readonly terminalToll: bigint;
  readonly status: bigint;
}

export interface RefundPurchaseRecordCoordinates {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly purchaseId: Hex;
  readonly saleId: Hex;
  readonly payer: Address;
}

export interface DecodedRefundAllowlistResolverData {
  readonly groups: readonly (readonly MintAllowlistProof[])[];
  readonly enabledPriceProof: MintAllowlistProof | null;
  readonly canonicalBytes: Hex;
  readonly hash: Hex;
}

export interface VerifiedNativeRefundPurchaseRecord {
  readonly coordinates: RefundPurchaseRecordCoordinates;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly observedRuntimeHash: Hex;
  readonly record: StoredNativeRefundPurchaseRecord;
  readonly payload: SigningPayload<NativeRefundPurchaseAuthorization>;
  readonly capture: RefundPurchaseCapture;
  readonly resolver: DecodedRefundAllowlistResolverData;
  readonly originalPurchaseRecordHash: Hex;
  readonly allowlistPurchaseRecordHash: Hex;
  readonly chargedPrice: bigint;
  readonly publicPrice: bigint;
  readonly priceSource: "saved-allowlist-override" | "original-public-price";
  readonly mutableLifecycleExcludedFromHash: true;
  readonly evidenceBoundary: string;
}

const coder = AbiCoder.defaultAbiCoder();
const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const authorizationTuple = "tuple(bytes32 saleId,bytes32 saleConfigHash,address payer,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 purchaseNonce,bytes32 nonce,uint256 price,uint64 deadline,bytes32 windowPolicyHash,uint64 maximumNominalFinalizeBy,uint64 absoluteEscapeDeadline,bytes32 expectedPrimaryPolicyHash)";
const captureTuple = "tuple(uint256 savedRevealFee,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address referencedGate)";
const recordTuple = `tuple(${authorizationTuple} authorization,bytes32 authorizationDigest,bytes32 purchaseRecordHash,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address referencedGate,bytes tokenData,uint256 savedRevealFee,uint64 purchasedAt,uint64 pauseBaseline,uint64 nominalRefundDeadline,uint64 nominalFinalizeBy,uint64 terminalToll,uint8 status)`;
const proofTuple = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)";
const refundAbi = new Interface([
  `function refundPurchaseRecord(bytes32) view returns (${recordTuple})`,
  "function refundPurchasePriceFacts(bytes32) view returns (bool captured,uint256 chargedPrice,bytes32 resolverDataHash)",
  "function refundPurchaseResolverData(bytes32) view returns (bytes)",
  `function refundPurchaseAuthorizationDigest(${authorizationTuple}) view returns (bytes32)`,
]);
const domains = Object.freeze({
  original: id("6529STREAM_REFUND_PURCHASE_RECORD_V1") as Hex,
  allowlist: id("6529STREAM_REFUND_ALLOWLIST_PURCHASE_RECORD_V1") as Hex,
});

function exactKeys(value: unknown, keys: readonly string[], name: string): asserts value is Record<string, unknown> {
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
    throw new Error(`${name} must be ${nonzero ? "a positive" : "a nonnegative"} bigint fitting uint${bits}`);
  }
  return value;
}

function address(value: unknown, name: string, allowZero = false): Address {
  if (typeof value !== "string") {
    throw new Error(`${name} must be an address string`);
  }
  const normalized = getAddress(value) as Address;
  if (!allowZero && normalized === ZeroAddress) {
    throw new Error(`${name} must be nonzero`);
  }
  return normalized;
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

function bytes(value: unknown, name: string, maximum: number): Hex {
  if (
    typeof value !== "string"
    || !isHexString(value)
    || (value.length - 2) % 2 !== 0
    || (value.length - 2) / 2 > maximum
  ) {
    throw new Error(`${name} must contain complete hex bytes no longer than ${maximum} bytes`);
  }
  return value as Hex;
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

function normalizeCoordinates(value: RefundPurchaseRecordCoordinates): RefundPurchaseRecordCoordinates {
  exactKeys(value, ["chainId", "adapter", "purchaseId", "saleId", "payer"], "refund purchase coordinates");
  return Object.freeze({
    chainId: uint(value.chainId, 256, "chainId", true),
    adapter: address(value.adapter, "adapter"),
    purchaseId: bytes32(value.purchaseId, "purchaseId", true),
    saleId: bytes32(value.saleId, "saleId", true),
    payer: address(value.payer, "payer"),
  });
}

function normalizeAuthorization(value: any): NativeRefundPurchaseAuthorization {
  const authorization: NativeRefundPurchaseAuthorization = {
    saleId: value.saleId,
    saleConfigHash: value.saleConfigHash,
    payer: value.payer,
    recipient: value.recipient,
    artist: value.artist,
    tokenDataHash: value.tokenDataHash,
    mintCommitment: value.mintCommitment,
    purchaseNonce: value.purchaseNonce,
    nonce: value.nonce,
    price: value.price,
    deadline: value.deadline,
    windowPolicyHash: value.windowPolicyHash,
    maximumNominalFinalizeBy: value.maximumNominalFinalizeBy,
    absoluteEscapeDeadline: value.absoluteEscapeDeadline,
    expectedPrimaryPolicyHash: value.expectedPrimaryPolicyHash,
  };
  return authorization;
}

export function normalizeRefundPurchaseCapture(value: RefundPurchaseCapture): RefundPurchaseCapture {
  exactKeys(
    value,
    ["savedRevealFee", "artistId", "bindingGeneration", "bindingHash", "referencedGate"],
    "refund purchase capture",
  );
  return Object.freeze({
    savedRevealFee: uint(value.savedRevealFee, 256, "savedRevealFee"),
    artistId: bytes32(value.artistId, "artistId", true),
    bindingGeneration: uint(value.bindingGeneration, 64, "bindingGeneration", true),
    bindingHash: bytes32(value.bindingHash, "bindingHash", true),
    referencedGate: address(value.referencedGate, "referencedGate", true),
  });
}

export function nativeRefundOriginalPurchaseRecordHash(
  chainId: bigint,
  adapter: Address,
  purchaseId: Hex,
  authorization: NativeRefundPurchaseAuthorization,
  authorizationDigest: Hex,
  capture: RefundPurchaseCapture,
  purchasedAt: bigint,
  pauseBaseline: bigint,
  nominalRefundDeadline: bigint,
  nominalFinalizeBy: bigint,
): Hex {
  const payload = nativeRefundPurchaseAuthorizationPayload(chainId, adapter, authorization);
  const digest = bytes32(authorizationDigest, "authorizationDigest", true);
  if (!same(payload.digest, digest)) {
    throw new Error("Authorization digest differs from the original signing payload");
  }
  return keccak256(coder.encode(
    [
      "bytes32",
      "uint256",
      "address",
      "bytes32",
      authorizationTuple,
      "bytes32",
      captureTuple,
      "uint64",
      "uint64",
      "uint64",
      "uint64",
    ],
    [
      domains.original,
      uint(chainId, 256, "chainId", true),
      address(adapter, "adapter"),
      bytes32(purchaseId, "purchaseId", true),
      payload.message,
      digest,
      normalizeRefundPurchaseCapture(capture),
      uint(purchasedAt, 64, "purchasedAt", true),
      uint(pauseBaseline, 64, "pauseBaseline"),
      uint(nominalRefundDeadline, 64, "nominalRefundDeadline", true),
      uint(nominalFinalizeBy, 64, "nominalFinalizeBy", true),
    ],
  )) as Hex;
}

export function nativeRefundAllowlistPurchaseRecordHash(
  originalPurchaseRecordHash: Hex,
  chargedPrice: bigint,
  resolverDataHash: Hex,
): Hex {
  return keccak256(coder.encode(
    ["bytes32", "bytes32", "uint256", "bytes32"],
    [
      domains.allowlist,
      bytes32(originalPurchaseRecordHash, "originalPurchaseRecordHash", true),
      uint(chargedPrice, 256, "chargedPrice"),
      bytes32(resolverDataHash, "resolverDataHash"),
    ],
  )) as Hex;
}

export function decodeCanonicalRefundAllowlistResolverData(
  resolverDataInput: Hex,
): DecodedRefundAllowlistResolverData {
  const resolverData = bytes(
    resolverDataInput,
    "refund resolverData",
    REFUND_RECORD_MAX_RESOLVER_BYTES,
  );
  if (resolverData === "0x") {
    throw new Error("Captured allowlist resolverData must be nonempty");
  }
  const decoded = coder.decode([`${proofTuple}[][]`], resolverData);
  const rawGroups = decoded[0] as readonly (readonly any[])[];
  if (
    !Array.isArray(rawGroups)
    || rawGroups.length === 0
    || rawGroups.length > REFUND_RECORD_MAX_PROOF_GROUPS
  ) {
    throw new Error("Resolver must contain 1 through 16 proof groups");
  }
  let enabledPriceProof: MintAllowlistProof | null = null;
  const groups = rawGroups.map((rawGroup, groupIndex) => {
    if (!Array.isArray(rawGroup) || rawGroup.length !== 1) {
      throw new Error(`Resolver proof group ${groupIndex} must contain exactly one proof`);
    }
    const raw = rawGroup[0];
    if (!Array.isArray(raw.proof) || raw.proof.length > REFUND_RECORD_MAX_PROOF_NODES) {
      throw new Error(`Resolver proof group ${groupIndex} exceeds the sibling boundary`);
    }
    if (typeof raw.hasPriceOverride !== "boolean") {
      throw new Error(`Resolver proof group ${groupIndex} has a non-boolean price flag`);
    }
    const proof = Object.freeze({
      maxCount: uint(raw.maxCount, 64, `groups[${groupIndex}].maxCount`, true),
      hasPriceOverride: raw.hasPriceOverride,
      priceOverride: uint(raw.priceOverride, 256, `groups[${groupIndex}].priceOverride`),
      proof: Object.freeze(raw.proof.map((node: unknown, nodeIndex: number) => bytes32(
        node,
        `groups[${groupIndex}].proof[${nodeIndex}]`,
      ))),
    });
    if (!proof.hasPriceOverride && proof.priceOverride !== 0n) {
      throw new Error(`Resolver proof group ${groupIndex} has a disabled nonzero price`);
    }
    if (proof.hasPriceOverride) {
      if (enabledPriceProof !== null) {
        throw new Error("Resolver contains more than one enabled price proof");
      }
      enabledPriceProof = proof;
    }
    return Object.freeze([proof]);
  });
  const canonicalBytes = coder.encode([`${proofTuple}[][]`], [groups]) as Hex;
  if (!same(canonicalBytes, resolverData)) {
    throw new Error("Saved resolverData is not canonical ABI encoding");
  }
  return Object.freeze({
    groups: Object.freeze(groups),
    enabledPriceProof,
    canonicalBytes: resolverData,
    hash: keccak256(resolverData) as Hex,
  });
}

async function read(
  provider: Pick<Provider, "call">,
  adapter: Address,
  method: string,
  args: readonly unknown[],
  blockTag: number,
): Promise<any> {
  const data = refundAbi.encodeFunctionData(method, args);
  const raw = await provider.call({ to: adapter, data, blockTag });
  const boundedRaw = bytes(raw, `${method} raw return`, REFUND_RECORD_MAX_RAW_RETURN_BYTES);
  const decoded = refundAbi.decodeFunctionResult(method, boundedRaw);
  if (!same(refundAbi.encodeFunctionResult(method, decoded), boundedRaw)) {
    throw new Error(`Noncanonical ${method} return`);
  }
  return decoded;
}

export async function verifyCurrentRefundPurchaseRecord(
  provider: Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">,
  coordinatesInput: RefundPurchaseRecordCoordinates,
  blockTag: BlockTag = "latest",
): Promise<VerifiedNativeRefundPurchaseRecord> {
  const coordinates = normalizeCoordinates(coordinatesInput);
  const block = await provider.getBlock(blockTag);
  if (!block?.hash) {
    throw new Error("Pinned refund purchase block is unavailable");
  }
  const blockNumber = concreteBlock(block.number);
  const blockHash = bytes32(block.hash, "block hash", true);
  if ((await provider.getNetwork()).chainId !== coordinates.chainId) {
    throw new Error("RPC chain differs from expected refund purchase coordinates");
  }
  const code = await provider.getCode(coordinates.adapter, blockNumber);
  if (typeof code !== "string" || !isHexString(code) || code === "0x") {
    throw new Error("Refund adapter has no observed runtime");
  }
  const observedRuntimeHash = keccak256(code) as Hex;
  const [recordResult, priceFacts, resolverResult] = await Promise.all([
    read(provider, coordinates.adapter, "refundPurchaseRecord", [coordinates.purchaseId], blockNumber),
    read(provider, coordinates.adapter, "refundPurchasePriceFacts", [coordinates.purchaseId], blockNumber),
    read(provider, coordinates.adapter, "refundPurchaseResolverData", [coordinates.purchaseId], blockNumber),
  ]);
  const rawRecord = recordResult[0];
  const authorization = normalizeAuthorization(rawRecord.authorization);
  const payload = nativeRefundPurchaseAuthorizationPayload(
    coordinates.chainId,
    coordinates.adapter,
    authorization,
  );
  const record: StoredNativeRefundPurchaseRecord = Object.freeze({
    authorization: payload.message,
    authorizationDigest: bytes32(rawRecord.authorizationDigest, "stored authorizationDigest", true),
    purchaseRecordHash: bytes32(rawRecord.purchaseRecordHash, "stored purchaseRecordHash", true),
    artistId: bytes32(rawRecord.artistId, "stored artistId", true),
    bindingGeneration: uint(rawRecord.bindingGeneration, 64, "stored bindingGeneration", true),
    bindingHash: bytes32(rawRecord.bindingHash, "stored bindingHash", true),
    referencedGate: address(rawRecord.referencedGate, "stored referencedGate", true),
    tokenData: bytes(rawRecord.tokenData, "stored tokenData", REFUND_RECORD_MAX_RESOLVER_BYTES),
    savedRevealFee: uint(rawRecord.savedRevealFee, 256, "stored savedRevealFee"),
    purchasedAt: uint(rawRecord.purchasedAt, 64, "stored purchasedAt", true),
    pauseBaseline: uint(rawRecord.pauseBaseline, 64, "stored pauseBaseline"),
    nominalRefundDeadline: uint(rawRecord.nominalRefundDeadline, 64, "stored nominalRefundDeadline", true),
    nominalFinalizeBy: uint(rawRecord.nominalFinalizeBy, 64, "stored nominalFinalizeBy", true),
    terminalToll: uint(rawRecord.terminalToll, 64, "stored terminalToll"),
    status: uint(rawRecord.status, 8, "stored status", true),
  });
  if (record.status > 4n) {
    throw new Error("Stored refund purchase status is unsupported");
  }
  const invalidEnvelope = record.nominalRefundDeadline <= record.purchasedAt
    || record.nominalFinalizeBy <= record.nominalRefundDeadline
    || record.nominalFinalizeBy > authorization.maximumNominalFinalizeBy
    || record.nominalFinalizeBy > authorization.absoluteEscapeDeadline;
  if (invalidEnvelope) {
    throw new Error("Stored refund purchase has an invalid immutable deadline envelope");
  }
  if (!same(authorization.saleId, coordinates.saleId) || !same(authorization.payer, coordinates.payer)) {
    throw new Error("Stored authorization differs from expected sale or payer coordinates");
  }
  const expectedPurchaseId = nativeRefundPurchaseId(
    coordinates.chainId,
    coordinates.adapter,
    coordinates.saleId,
    coordinates.payer,
    authorization.purchaseNonce,
  );
  if (!same(expectedPurchaseId, coordinates.purchaseId)) {
    throw new Error("Expected purchase ID differs from stored authorization coordinates");
  }
  if (!same(record.authorizationDigest, payload.digest)) {
    throw new Error("Stored authorization digest differs from original signing preimage");
  }
  const digestResult = await read(
    provider,
    coordinates.adapter,
    "refundPurchaseAuthorizationDigest",
    [authorization],
    blockNumber,
  );
  if (!same(digestResult[0], payload.digest)) {
    throw new Error("Current digest getter differs from stored original authorization");
  }
  if (!same(keccak256(record.tokenData), authorization.tokenDataHash)) {
    throw new Error("Saved tokenData differs from its original signed hash");
  }
  const captured = priceFacts[0];
  if (captured !== true) {
    throw new Error("Stored purchase is not an allowlist price capture");
  }
  const chargedPrice = uint(priceFacts[1], 256, "stored chargedPrice");
  const resolverDataHash = bytes32(priceFacts[2], "stored resolverDataHash", true);
  const resolverData = bytes(
    resolverResult[0],
    "stored resolverData",
    REFUND_RECORD_MAX_RESOLVER_BYTES,
  );
  const resolver = decodeCanonicalRefundAllowlistResolverData(resolverData);
  if (!same(resolver.hash, resolverDataHash)) {
    throw new Error("Saved resolverData differs from its stored hash");
  }
  const publicPrice = uint(authorization.price, 256, "original public price", true);
  const priceSource = resolver.enabledPriceProof === null
    ? "original-public-price"
    : "saved-allowlist-override";
  const expectedCharge = resolver.enabledPriceProof?.priceOverride ?? publicPrice;
  if (chargedPrice !== expectedCharge) {
    throw new Error("Saved charged price differs from the exact captured proof/public price");
  }
  const capture = normalizeRefundPurchaseCapture({
    savedRevealFee: record.savedRevealFee,
    artistId: record.artistId,
    bindingGeneration: record.bindingGeneration,
    bindingHash: record.bindingHash,
    referencedGate: record.referencedGate,
  });
  const originalPurchaseRecordHash = nativeRefundOriginalPurchaseRecordHash(
    coordinates.chainId,
    coordinates.adapter,
    coordinates.purchaseId,
    authorization,
    record.authorizationDigest,
    capture,
    record.purchasedAt,
    record.pauseBaseline,
    record.nominalRefundDeadline,
    record.nominalFinalizeBy,
  );
  const allowlistPurchaseRecordHash = nativeRefundAllowlistPurchaseRecordHash(
    originalPurchaseRecordHash,
    chargedPrice,
    resolverDataHash,
  );
  if (!same(allowlistPurchaseRecordHash, record.purchaseRecordHash)) {
    throw new Error("Stored purchase record hash differs from immutable reconstruction");
  }
  if (!same((await provider.getBlock(blockNumber))?.hash ?? "", blockHash)) {
    throw new Error("Pinned refund purchase readback block changed");
  }
  return Object.freeze({
    coordinates,
    blockNumber,
    blockHash,
    observedRuntimeHash,
    record,
    payload,
    capture,
    resolver,
    originalPurchaseRecordHash,
    allowlistPurchaseRecordHash,
    chargedPrice,
    publicPrice,
    priceSource,
    mutableLifecycleExcludedFromHash: true,
    evidenceBoundary: "Stored commitment consistency only; no historical admission, Merkle-root, deployed-code identity or full-stack proof.",
  });
}
