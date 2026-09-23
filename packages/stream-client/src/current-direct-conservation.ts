import {
  AbiCoder,
  Interface,
  ParamType,
  TypedDataEncoder,
  ZeroAddress,
  ZeroHash,
  getAddress,
  id,
  isHexString,
  keccak256
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";

/** Original products and historical floor evidence from the independent ABI98 profile. */
export const DIRECT_CONSERVATION_SOURCE = "8bb6dfe2957542f641b0d558e1cfd48e1b39ae98";
export const DIRECT_CONSERVATION_PROFILE = "DIRECT_CONSERVATION";
/** Client allocation ceilings; signature length does not identify the signer kind. */
export const DIRECT_CONSERVATION_MAX_BYTES = 131072;
export const DIRECT_CONSERVATION_MAX_SIGNATURE_BYTES = 16384;
/** Deliberately narrower client input bound; this is not the Core's original tokenData maximum. */
export const DIRECT_CONSERVATION_MAX_TOKEN_DATA_BYTES = 8192;
export const DIRECT_CONSERVATION_MODULE_TYPE = id("DIRECT_PRIMARY_SALE_ADAPTER") as Hex;
export const DIRECT_CONSERVATION_MODULE_VERSION = id("6529STREAM_DIRECT_PRIMARY_SALE_V1") as Hex;
export const DIRECT_CONSERVATION_PRIMARY_SALE = id("PRIMARY_SALE") as Hex;
export const DIRECT_CONSERVATION_PRODUCT_KINDS = Object.freeze({
  "native-fixed": id("6529STREAM_DIRECT_NATIVE_FIXED_PRICE_V1") as Hex,
  "erc20-fixed": id("6529STREAM_DIRECT_ERC20_FIXED_PRICE_V1") as Hex,
  "english-auction": id("6529STREAM_DIRECT_ENGLISH_AUCTION_V1") as Hex
});
export type DirectConservationProductKind = keyof typeof DIRECT_CONSERVATION_PRODUCT_KINDS;

export interface DirectConservationCoordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly product: Address;
  readonly productKind: DirectConservationProductKind;
}

export interface DirectConservationFloorCoordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly floor: Address;
}

export interface DirectConservationBindings {
  readonly core: Address;
  readonly coreCodeHash: Hex;
  readonly mintManager: Address;
  readonly mintManagerCodeHash: Hex;
  readonly deploymentChainId: bigint;
  readonly productKind: Hex;
}

export interface DirectConservationReceipt {
  readonly authorizationDigest: Hex;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly operationRoot: Hex;
  readonly operationId: Hex;
  readonly boundMintPolicyHash: Hex;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly profileId: Hex;
  readonly wallet: Address;
  readonly createdAt: bigint;
  readonly escrowed: boolean;
  readonly payer: Address;
  readonly registryRevision: bigint;
  readonly beneficiary: Address;
  readonly asset: Address;
  readonly amount: bigint;
}

export interface DirectConservationFloorReceipt {
  readonly receiptHash: Hex;
  readonly adapter: Address;
  readonly adapterCodeHash: Hex;
  readonly directKey: Hex;
  readonly authorizationId: Hex;
  readonly originalReceiptHash: Hex;
  readonly bindings: DirectConservationBindings;
  readonly sale: DirectConservationReceipt;
  readonly effectiveTier: Hex;
  readonly firstSaleReceiptHash: Hex;
  readonly releaseReceiptHash: Hex;
  readonly recordedAt: bigint;
}

export interface DirectConservationCollectionFacts {
  readonly artistId: Hex;
  readonly identityRecordHash: Hex;
  readonly intentRecordHash: Hex;
  readonly intentWaiverRecordHash: Hex;
  readonly interviewEvidenceHash: Hex;
  readonly rightsRecordHash: Hex;
  readonly personhoodEvidenceHash: Hex;
  readonly platformWorks: boolean;
}

export interface DirectConservationReleaseContext {
  readonly scopeSubject: Hex;
  readonly membershipHash: Hex;
  readonly mediaInventoryHash: Hex;
  readonly scriptSourceHash: Hex;
  readonly sourceContextHash: Hex;
  readonly scriptWork: boolean;
}

export interface DirectConservationReleaseFacts {
  readonly sourceContextHash: Hex;
  readonly mediaEvidenceHash: Hex;
  readonly referenceEvidenceHash: Hex;
}

export interface DirectConservationSource {
  readonly metadata: Address;
  readonly metadataCodeHash: Hex;
  readonly provider: Address;
  readonly providerCodeHash: Hex;
  readonly configurationHash: Hex;
  readonly predecessor: bigint;
  readonly admittedAt: bigint;
  readonly actionId: Hex;
}

export interface DirectConservationFirstSaleReceipt {
  readonly receiptHash: Hex;
  readonly collectionId: bigint;
  readonly effectiveTier: Hex;
  readonly recorder: Address;
  readonly settlementKey: Hex;
  readonly recordedAt: bigint;
  readonly sourceId: bigint;
  readonly sourceSetHash: Hex;
  readonly facts: DirectConservationCollectionFacts;
}

export interface DirectConservationReleaseReceipt {
  readonly receiptHash: Hex;
  readonly releaseKey: Hex;
  readonly collectionId: bigint;
  readonly effectiveTier: Hex;
  readonly recorder: Address;
  readonly settlementKey: Hex;
  readonly recordedAt: bigint;
  readonly sourceId: bigint;
  readonly sourceSetHash: Hex;
  readonly context: DirectConservationReleaseContext;
  readonly facts: DirectConservationReleaseFacts;
}

export interface DirectConservationNativeAuthorization {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly payer: Address;
  readonly recipient: Address;
  readonly artist: Address;
  readonly profileId: Hex;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly tokenDataHash: Hex;
  readonly mintCommitment: Hex;
  readonly mintPolicyHash: Hex;
  readonly price: bigint;
  readonly nonce: Hex;
  readonly deadline: bigint;
  readonly signerEpoch: bigint;
}

export interface DirectConservationERC20Authorization {
  readonly saleId: Hex;
  readonly saleConfigHash: Hex;
  readonly payer: Address;
  readonly recipient: Address;
  readonly artist: Address;
  readonly tokenDataHash: Hex;
  readonly mintCommitment: Hex;
  readonly nonce: Hex;
  readonly deadline: bigint;
  readonly signerEpoch: bigint;
}

export interface DirectConservationERC20Config {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly asset: Address;
  readonly revenueClass: Hex;
  readonly price: bigint;
  readonly mintPolicyHash: Hex;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly startsAt: bigint;
  readonly endsAt: bigint;
}

export interface DirectConservationERC20SaleRecord {
  readonly config: DirectConservationERC20Config;
  readonly saleNonce: bigint;
  readonly configHash: Hex;
  readonly cancelled: boolean;
}

export interface DirectConservationAuctionAuthorization {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly artist: Address;
  readonly profileId: Hex;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly tokenDataHash: Hex;
  readonly mintCommitment: Hex;
  readonly mintPolicyHash: Hex;
  readonly reservePrice: bigint;
  readonly startTime: bigint;
  readonly endTime: bigint;
  readonly extensionWindow: bigint;
  readonly minBidIncrementBps: bigint;
  readonly nonce: Hex;
  readonly deadline: bigint;
  readonly signerEpoch: bigint;
}

export interface DirectConservationAuction {
  readonly artist: Address;
  readonly wallet: Address;
  readonly profileId: Hex;
  readonly reservePrice: bigint;
  readonly startTime: bigint;
  readonly endTime: bigint;
  readonly extensionWindow: bigint;
  readonly minBidIncrementBps: bigint;
  readonly highestBidder: Address;
  readonly deliveryRecipient: Address;
  readonly highestBid: bigint;
  readonly settled: boolean;
  readonly cancelled: boolean;
  readonly pendingNoBidNftClaimant: Address;
  readonly authorizationId: Hex;
  readonly operationRoot: Hex;
  readonly primaryPolicyHash: Hex;
}

export interface DirectConservationPaymentIntent {
  readonly payer: Address;
  readonly asset: Address;
  readonly maxAmount: bigint;
  readonly saleRef: Hex;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly nonce: Hex;
  readonly deadline: bigint;
}

export interface DirectConservationPaymentRevocation {
  readonly payer: Address;
  readonly nonce: Hex;
  readonly deadline: bigint;
}

export interface DirectConservationMintBatch {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly payer: Address;
  readonly authorizer: Address;
  readonly initialRecipients: readonly Address[];
  readonly beneficiaries: readonly Address[];
  readonly tokenData: readonly Hex[];
  readonly mintCommitments: readonly Hex[];
  readonly expectedPolicyHash: Hex;
  readonly authorizationId: Hex;
  readonly contextHash: Hex;
  readonly resolverData: Hex;
}

export const DIRECT_CONSERVATION_BINDINGS_TUPLE = "tuple(address core,bytes32 coreCodeHash,address mintManager,bytes32 mintManagerCodeHash,uint256 deploymentChainId,bytes32 productKind)";
export const DIRECT_CONSERVATION_RECEIPT_TUPLE = "tuple(bytes32 authorizationDigest,uint256 collectionId,uint256 tokenId,bytes32 operationRoot,bytes32 operationId,bytes32 boundMintPolicyHash,bytes32 expectedPrimaryPolicyHash,bytes32 profileId,address wallet,uint64 createdAt,bool escrowed,address payer,uint64 registryRevision,address beneficiary,address asset,uint256 amount)";
export const DIRECT_CONSERVATION_COLLECTION_FACTS_TUPLE = "tuple(bytes32 artistId,bytes32 identityRecordHash,bytes32 intentRecordHash,bytes32 intentWaiverRecordHash,bytes32 interviewEvidenceHash,bytes32 rightsRecordHash,bytes32 personhoodEvidenceHash,bool platformWorks)";
export const DIRECT_CONSERVATION_RELEASE_CONTEXT_TUPLE = "tuple(bytes32 scopeSubject,bytes32 membershipHash,bytes32 mediaInventoryHash,bytes32 scriptSourceHash,bytes32 sourceContextHash,bool scriptWork)";
export const DIRECT_CONSERVATION_RELEASE_FACTS_TUPLE = "tuple(bytes32 sourceContextHash,bytes32 mediaEvidenceHash,bytes32 referenceEvidenceHash)";
export const DIRECT_CONSERVATION_SOURCE_TUPLE = "tuple(address metadata,bytes32 metadataCodeHash,address provider,bytes32 providerCodeHash,bytes32 configurationHash,uint64 predecessor,uint64 admittedAt,bytes32 actionId)";
export const DIRECT_CONSERVATION_FLOOR_RECEIPT_TUPLE = `tuple(bytes32 receiptHash,address adapter,bytes32 adapterCodeHash,bytes32 directKey,bytes32 authorizationId,bytes32 originalReceiptHash,${DIRECT_CONSERVATION_BINDINGS_TUPLE} bindings,${DIRECT_CONSERVATION_RECEIPT_TUPLE} sale,bytes32 effectiveTier,bytes32 firstSaleReceiptHash,bytes32 releaseReceiptHash,uint64 recordedAt)`;
export const DIRECT_CONSERVATION_FIRST_SALE_RECEIPT_TUPLE = `tuple(bytes32 receiptHash,uint256 collectionId,bytes32 effectiveTier,address recorder,bytes32 settlementKey,uint64 recordedAt,uint64 sourceId,bytes32 sourceSetHash,${DIRECT_CONSERVATION_COLLECTION_FACTS_TUPLE} facts)`;
export const DIRECT_CONSERVATION_RELEASE_RECEIPT_TUPLE = `tuple(bytes32 receiptHash,bytes32 releaseKey,uint256 collectionId,bytes32 effectiveTier,address recorder,bytes32 settlementKey,uint64 recordedAt,uint64 sourceId,bytes32 sourceSetHash,${DIRECT_CONSERVATION_RELEASE_CONTEXT_TUPLE} context,${DIRECT_CONSERVATION_RELEASE_FACTS_TUPLE} facts)`;
export const DIRECT_CONSERVATION_NATIVE_AUTHORIZATION_TUPLE = "tuple(uint256 collectionId,bytes32 phaseId,address payer,address recipient,address artist,bytes32 profileId,bytes32 expectedPrimaryPolicyHash,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 price,bytes32 nonce,uint64 deadline,uint64 signerEpoch)";
export const DIRECT_CONSERVATION_ERC20_AUTHORIZATION_TUPLE = "tuple(bytes32 saleId,bytes32 saleConfigHash,address payer,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 nonce,uint64 deadline,uint64 signerEpoch)";
export const DIRECT_CONSERVATION_ERC20_CONFIG_TUPLE = "tuple(uint256 collectionId,bytes32 phaseId,address asset,bytes32 revenueClass,uint256 price,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash,uint64 startsAt,uint64 endsAt)";
export const DIRECT_CONSERVATION_ERC20_SALE_RECORD_TUPLE = `tuple(${DIRECT_CONSERVATION_ERC20_CONFIG_TUPLE} config,uint256 saleNonce,bytes32 configHash,bool cancelled)`;
export const DIRECT_CONSERVATION_AUCTION_AUTHORIZATION_TUPLE = "tuple(uint256 collectionId,bytes32 phaseId,address artist,bytes32 profileId,bytes32 expectedPrimaryPolicyHash,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 reservePrice,uint64 startTime,uint64 endTime,uint32 extensionWindow,uint16 minBidIncrementBps,bytes32 nonce,uint64 deadline,uint64 signerEpoch)";
export const DIRECT_CONSERVATION_AUCTION_TUPLE = "tuple(address artist,address wallet,bytes32 profileId,uint256 reservePrice,uint64 startTime,uint64 endTime,uint32 extensionWindow,uint16 minBidIncrementBps,address highestBidder,address deliveryRecipient,uint256 highestBid,bool settled,bool cancelled,address pendingNoBidNftClaimant,bytes32 authorizationId,bytes32 operationRoot,bytes32 primaryPolicyHash)";
export const DIRECT_CONSERVATION_PAYMENT_INTENT_TUPLE = "tuple(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)";
export const DIRECT_CONSERVATION_PAYMENT_REVOCATION_TUPLE = "tuple(address payer,bytes32 nonce,uint64 deadline)";

const coder = AbiCoder.defaultAbiCoder();

function exact(value: unknown, keys: readonly string[], label: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  const own = Reflect.ownKeys(value);
  if (own.length !== keys.length || own.some(key => typeof key !== "string" || !keys.includes(key))) {
    throw new Error(`${label} must contain exactly: ${keys.join(", ")}`);
  }
  return value as Record<string, unknown>;
}

function uint(value: unknown, bits = 256, label = "value"): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) {
    throw new Error(`${label} must be an exact uint${bits} bigint`);
  }
  return value;
}

function address(value: unknown, label: string, nonzero = false): Address {
  if (typeof value !== "string") throw new Error(`${label} must be an address`);
  const result = getAddress(value) as Address;
  if (nonzero && result === ZeroAddress) throw new Error(`${label} must be nonzero`);
  return result;
}

function bytes(value: unknown, label: string, maximum = DIRECT_CONSERVATION_MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > maximum) {
    throw new Error(`${label} must be bounded hex bytes`);
  }
  return value.toLowerCase() as Hex;
}

function hash(value: unknown, label: string, nonzero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)) {
    throw new Error(`${label} must contain 32 bytes`);
  }
  const result = value.toLowerCase() as Hex;
  if (nonzero && result === ZeroHash) throw new Error(`${label} must be nonzero`);
  return result;
}

function structural(param: ParamType, value: unknown, label: string): unknown {
  if (param.baseType === "tuple") {
    const fields = param.components!;
    const input = exact(value, fields.map(field => field.name), label);
    const output: Record<string, unknown> = {};
    for (const field of fields) {
      output[field.name] = structural(field, input[field.name], `${label}.${field.name}`);
    }
    return Object.freeze(output);
  }
  if (param.type === "address") return address(value, label);
  if (param.type === "bytes32") return hash(value, label);
  if (param.type === "bool") {
    if (typeof value !== "boolean") throw new Error(`${label} must be boolean`);
    return value;
  }
  if (/^uint\d+$/.test(param.type)) return uint(value, Number(param.type.slice(4)), label);
  throw new Error(`Unsupported original field ${param.type}`);
}

function normalize<T>(tuple: string, value: unknown): T {
  return structural(ParamType.from(tuple), value, "record") as T;
}

function fromDecoded(param: ParamType, value: unknown): unknown {
  if (param.baseType !== "tuple") return value;
  const result: Record<string, unknown> = {};
  param.components!.forEach((field, index) => {
    result[field.name] = fromDecoded(field, (value as readonly unknown[])[index]);
  });
  return result;
}

function encode<T>(tuple: string, value: T): Hex {
  return coder.encode([tuple], [normalize<T>(tuple, value)]) as Hex;
}

function decode<T>(tuple: string, value: Hex): T {
  const raw = bytes(value, "canonical ABI");
  const decoded = coder.decode([tuple], raw)[0];
  const result = normalize<T>(tuple, fromDecoded(ParamType.from(tuple), decoded));
  if (encode(tuple, result) !== raw) throw new Error("Noncanonical original ABI encoding");
  return result;
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationBindings(
  value: DirectConservationBindings
): DirectConservationBindings {
  return normalize(DIRECT_CONSERVATION_BINDINGS_TUPLE, value);
}

export function encodeDirectConservationBindings(value: DirectConservationBindings): Hex {
  return encode(DIRECT_CONSERVATION_BINDINGS_TUPLE, value);
}

export function decodeDirectConservationBindings(value: Hex): DirectConservationBindings {
  return decode(DIRECT_CONSERVATION_BINDINGS_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationReceipt(
  value: DirectConservationReceipt
): DirectConservationReceipt {
  return normalize(DIRECT_CONSERVATION_RECEIPT_TUPLE, value);
}

export function encodeDirectConservationReceipt(value: DirectConservationReceipt): Hex {
  return encode(DIRECT_CONSERVATION_RECEIPT_TUPLE, value);
}

export function decodeDirectConservationReceipt(value: Hex): DirectConservationReceipt {
  return decode(DIRECT_CONSERVATION_RECEIPT_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationFloorReceipt(
  value: DirectConservationFloorReceipt
): DirectConservationFloorReceipt {
  return normalize(DIRECT_CONSERVATION_FLOOR_RECEIPT_TUPLE, value);
}

export function encodeDirectConservationFloorReceipt(value: DirectConservationFloorReceipt): Hex {
  return encode(DIRECT_CONSERVATION_FLOOR_RECEIPT_TUPLE, value);
}

export function decodeDirectConservationFloorReceipt(value: Hex): DirectConservationFloorReceipt {
  return decode(DIRECT_CONSERVATION_FLOOR_RECEIPT_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationCollectionFacts(
  value: DirectConservationCollectionFacts
): DirectConservationCollectionFacts {
  return normalize(DIRECT_CONSERVATION_COLLECTION_FACTS_TUPLE, value);
}

export function encodeDirectConservationCollectionFacts(value: DirectConservationCollectionFacts): Hex {
  return encode(DIRECT_CONSERVATION_COLLECTION_FACTS_TUPLE, value);
}

export function decodeDirectConservationCollectionFacts(value: Hex): DirectConservationCollectionFacts {
  return decode(DIRECT_CONSERVATION_COLLECTION_FACTS_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationReleaseContext(
  value: DirectConservationReleaseContext
): DirectConservationReleaseContext {
  return normalize(DIRECT_CONSERVATION_RELEASE_CONTEXT_TUPLE, value);
}

export function encodeDirectConservationReleaseContext(value: DirectConservationReleaseContext): Hex {
  return encode(DIRECT_CONSERVATION_RELEASE_CONTEXT_TUPLE, value);
}

export function decodeDirectConservationReleaseContext(value: Hex): DirectConservationReleaseContext {
  return decode(DIRECT_CONSERVATION_RELEASE_CONTEXT_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationReleaseFacts(
  value: DirectConservationReleaseFacts
): DirectConservationReleaseFacts {
  return normalize(DIRECT_CONSERVATION_RELEASE_FACTS_TUPLE, value);
}

export function encodeDirectConservationReleaseFacts(value: DirectConservationReleaseFacts): Hex {
  return encode(DIRECT_CONSERVATION_RELEASE_FACTS_TUPLE, value);
}

export function decodeDirectConservationReleaseFacts(value: Hex): DirectConservationReleaseFacts {
  return decode(DIRECT_CONSERVATION_RELEASE_FACTS_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationSource(
  value: DirectConservationSource
): DirectConservationSource {
  return normalize(DIRECT_CONSERVATION_SOURCE_TUPLE, value);
}

export function encodeDirectConservationSource(value: DirectConservationSource): Hex {
  return encode(DIRECT_CONSERVATION_SOURCE_TUPLE, value);
}

export function decodeDirectConservationSource(value: Hex): DirectConservationSource {
  return decode(DIRECT_CONSERVATION_SOURCE_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationFirstSaleReceipt(
  value: DirectConservationFirstSaleReceipt
): DirectConservationFirstSaleReceipt {
  return normalize(DIRECT_CONSERVATION_FIRST_SALE_RECEIPT_TUPLE, value);
}

export function encodeDirectConservationFirstSaleReceipt(value: DirectConservationFirstSaleReceipt): Hex {
  return encode(DIRECT_CONSERVATION_FIRST_SALE_RECEIPT_TUPLE, value);
}

export function decodeDirectConservationFirstSaleReceipt(value: Hex): DirectConservationFirstSaleReceipt {
  return decode(DIRECT_CONSERVATION_FIRST_SALE_RECEIPT_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationReleaseReceipt(
  value: DirectConservationReleaseReceipt
): DirectConservationReleaseReceipt {
  return normalize(DIRECT_CONSERVATION_RELEASE_RECEIPT_TUPLE, value);
}

export function encodeDirectConservationReleaseReceipt(value: DirectConservationReleaseReceipt): Hex {
  return encode(DIRECT_CONSERVATION_RELEASE_RECEIPT_TUPLE, value);
}

export function decodeDirectConservationReleaseReceipt(value: Hex): DirectConservationReleaseReceipt {
  return decode(DIRECT_CONSERVATION_RELEASE_RECEIPT_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationNativeAuthorization(
  value: DirectConservationNativeAuthorization
): DirectConservationNativeAuthorization {
  return normalize(DIRECT_CONSERVATION_NATIVE_AUTHORIZATION_TUPLE, value);
}

export function encodeDirectConservationNativeAuthorization(
  value: DirectConservationNativeAuthorization
): Hex {
  return encode(DIRECT_CONSERVATION_NATIVE_AUTHORIZATION_TUPLE, value);
}

export function decodeDirectConservationNativeAuthorization(
  value: Hex
): DirectConservationNativeAuthorization {
  return decode(DIRECT_CONSERVATION_NATIVE_AUTHORIZATION_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationERC20Authorization(
  value: DirectConservationERC20Authorization
): DirectConservationERC20Authorization {
  return normalize(DIRECT_CONSERVATION_ERC20_AUTHORIZATION_TUPLE, value);
}

export function encodeDirectConservationERC20Authorization(
  value: DirectConservationERC20Authorization
): Hex {
  return encode(DIRECT_CONSERVATION_ERC20_AUTHORIZATION_TUPLE, value);
}

export function decodeDirectConservationERC20Authorization(
  value: Hex
): DirectConservationERC20Authorization {
  return decode(DIRECT_CONSERVATION_ERC20_AUTHORIZATION_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationERC20Config(
  value: DirectConservationERC20Config
): DirectConservationERC20Config {
  return normalize(DIRECT_CONSERVATION_ERC20_CONFIG_TUPLE, value);
}

export function encodeDirectConservationERC20Config(value: DirectConservationERC20Config): Hex {
  return encode(DIRECT_CONSERVATION_ERC20_CONFIG_TUPLE, value);
}

export function decodeDirectConservationERC20Config(value: Hex): DirectConservationERC20Config {
  return decode(DIRECT_CONSERVATION_ERC20_CONFIG_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationERC20SaleRecord(
  value: DirectConservationERC20SaleRecord
): DirectConservationERC20SaleRecord {
  return normalize(DIRECT_CONSERVATION_ERC20_SALE_RECORD_TUPLE, value);
}

export function encodeDirectConservationERC20SaleRecord(value: DirectConservationERC20SaleRecord): Hex {
  return encode(DIRECT_CONSERVATION_ERC20_SALE_RECORD_TUPLE, value);
}

export function decodeDirectConservationERC20SaleRecord(value: Hex): DirectConservationERC20SaleRecord {
  return decode(DIRECT_CONSERVATION_ERC20_SALE_RECORD_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationAuctionAuthorization(
  value: DirectConservationAuctionAuthorization
): DirectConservationAuctionAuthorization {
  return normalize(DIRECT_CONSERVATION_AUCTION_AUTHORIZATION_TUPLE, value);
}

export function encodeDirectConservationAuctionAuthorization(
  value: DirectConservationAuctionAuthorization
): Hex {
  return encode(DIRECT_CONSERVATION_AUCTION_AUTHORIZATION_TUPLE, value);
}

export function decodeDirectConservationAuctionAuthorization(
  value: Hex
): DirectConservationAuctionAuthorization {
  return decode(DIRECT_CONSERVATION_AUCTION_AUTHORIZATION_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationAuction(
  value: DirectConservationAuction
): DirectConservationAuction {
  return normalize(DIRECT_CONSERVATION_AUCTION_TUPLE, value);
}

export function encodeDirectConservationAuction(value: DirectConservationAuction): Hex {
  return encode(DIRECT_CONSERVATION_AUCTION_TUPLE, value);
}

export function decodeDirectConservationAuction(value: Hex): DirectConservationAuction {
  return decode(DIRECT_CONSERVATION_AUCTION_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationPaymentIntent(
  value: DirectConservationPaymentIntent
): DirectConservationPaymentIntent {
  return normalize(DIRECT_CONSERVATION_PAYMENT_INTENT_TUPLE, value);
}

export function encodeDirectConservationPaymentIntent(value: DirectConservationPaymentIntent): Hex {
  return encode(DIRECT_CONSERVATION_PAYMENT_INTENT_TUPLE, value);
}

export function decodeDirectConservationPaymentIntent(value: Hex): DirectConservationPaymentIntent {
  return decode(DIRECT_CONSERVATION_PAYMENT_INTENT_TUPLE, value);
}

/** Structural original tuple; zero-valued unknown records remain representable. */
export function normalizeDirectConservationPaymentRevocation(
  value: DirectConservationPaymentRevocation
): DirectConservationPaymentRevocation {
  return normalize(DIRECT_CONSERVATION_PAYMENT_REVOCATION_TUPLE, value);
}

export function encodeDirectConservationPaymentRevocation(value: DirectConservationPaymentRevocation): Hex {
  return encode(DIRECT_CONSERVATION_PAYMENT_REVOCATION_TUPLE, value);
}

export function decodeDirectConservationPaymentRevocation(value: Hex): DirectConservationPaymentRevocation {
  return decode(DIRECT_CONSERVATION_PAYMENT_REVOCATION_TUPLE, value);
}

function productKind(value: unknown): DirectConservationProductKind {
  if (typeof value !== "string" || !Object.hasOwn(DIRECT_CONSERVATION_PRODUCT_KINDS, value)) {
    throw new Error("Unknown DIRECT product kind");
  }
  return value as DirectConservationProductKind;
}

export function normalizeDirectConservationCoordinates(
  value: DirectConservationCoordinates
): DirectConservationCoordinates {
  const input = exact(value, ["chainId", "core", "product", "productKind"], "coordinates");
  return Object.freeze({
    chainId: uint(input.chainId),
    core: address(input.core, "core", true),
    product: address(input.product, "product", true),
    productKind: productKind(input.productKind)
  });
}

export function normalizeDirectConservationFloorCoordinates(
  value: DirectConservationFloorCoordinates
): DirectConservationFloorCoordinates {
  const input = exact(value, ["chainId", "core", "floor"], "floor coordinates");
  return Object.freeze({
    chainId: uint(input.chainId),
    core: address(input.core, "core", true),
    floor: address(input.floor, "floor", true)
  });
}

function digest(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

/** The original DIRECT key. This is never a universal settlement or consumed key. */
export function directConservationKey(
  bindings: DirectConservationBindings,
  adapter: Address,
  authorizationId: Hex
): Hex {
  const b = normalizeDirectConservationBindings(bindings);
  return digest(
    ["bytes32", "uint256", "address", "address", "bytes32", "bytes32"],
    [id("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"), b.deploymentChainId, b.core,
      address(adapter, "adapter"), b.productKind, hash(authorizationId, "authorizationId")]
  );
}

/** Raw original hash preimage. The product's getter separately returns zero when amount is zero. */
export function directConservationReceiptHash(
  bindings: DirectConservationBindings,
  adapter: Address,
  authorizationId: Hex,
  receipt: DirectConservationReceipt
): Hex {
  const b = normalizeDirectConservationBindings(bindings);
  const r = normalizeDirectConservationReceipt(receipt);
  return digest(
    ["bytes32", "uint256", "address", "address", "bytes32", "bytes32", DIRECT_CONSERVATION_RECEIPT_TUPLE],
    [id("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"), b.deploymentChainId, b.core,
      address(adapter, "adapter"), b.productKind, hash(authorizationId, "authorizationId"), r]
  );
}

export function directConservationReceiptLookupHash(
  bindings: DirectConservationBindings,
  adapter: Address,
  authorizationId: Hex,
  receipt: DirectConservationReceipt
): Hex {
  const r = normalizeDirectConservationReceipt(receipt);
  const computed = directConservationReceiptHash(bindings, adapter, authorizationId, r);
  return r.amount === 0n ? ZeroHash as Hex : computed;
}

function floorHash(
  coordinates: DirectConservationFloorCoordinates,
  domain: string,
  tuple: string,
  record: object
): Hex {
  const c = normalizeDirectConservationFloorCoordinates(coordinates);
  return digest(
    ["bytes32", "uint256", "address", "address", tuple],
    [id(domain), c.chainId, c.core, c.floor, { ...record, receiptHash: ZeroHash }]
  );
}

export function directConservationFloorReceiptHash(
  coordinates: DirectConservationFloorCoordinates,
  receipt: DirectConservationFloorReceipt
): Hex {
  return floorHash(coordinates, "6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1",
    DIRECT_CONSERVATION_FLOOR_RECEIPT_TUPLE, normalizeDirectConservationFloorReceipt(receipt));
}

export function directConservationFirstSaleReceiptHash(
  coordinates: DirectConservationFloorCoordinates,
  receipt: DirectConservationFirstSaleReceipt
): Hex {
  return floorHash(coordinates, "6529STREAM_CONSERVATION_FIRST_SALE_V1",
    DIRECT_CONSERVATION_FIRST_SALE_RECEIPT_TUPLE, normalizeDirectConservationFirstSaleReceipt(receipt));
}

export function directConservationReleaseReceiptHash(
  coordinates: DirectConservationFloorCoordinates,
  receipt: DirectConservationReleaseReceipt
): Hex {
  return floorHash(coordinates, "6529STREAM_CONSERVATION_RELEASE_RECEIPT_V1",
    DIRECT_CONSERVATION_RELEASE_RECEIPT_TUPLE, normalizeDirectConservationReleaseReceipt(receipt));
}

/** Semantic release identity deliberately excludes provider identity and sourceContextHash. */
export function directConservationReleaseKey(
  chainId: bigint,
  core: Address,
  collectionId: bigint,
  context: DirectConservationReleaseContext
): Hex {
  const r = normalizeDirectConservationReleaseContext(context);
  return digest(
    ["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bool"],
    [id("6529STREAM_CONSERVATION_RELEASE_V1"), uint(chainId), address(core, "core"), uint(collectionId),
      r.scopeSubject, r.membershipHash, r.mediaInventoryHash, r.scriptSourceHash, r.scriptWork]
  );
}

export function directConservationSourceInitialHash(coordinates: DirectConservationFloorCoordinates): Hex {
  const c = normalizeDirectConservationFloorCoordinates(coordinates);
  return digest(["bytes32", "uint256", "address", "address"],
    [id("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1"), c.chainId, c.core, c.floor]);
}

export function directConservationSourceAppendHash(
  previousHead: Hex,
  sourceId: bigint,
  source: DirectConservationSource
): Hex {
  const s = normalizeDirectConservationSource(source);
  return digest(
    ["bytes32", "bytes32", "uint64", "address", "bytes32", "address", "bytes32", "bytes32", "uint64"],
    [id("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1"), hash(previousHead, "previousHead"), uint(sourceId, 64),
      s.metadata, s.metadataCodeHash, s.provider, s.providerCodeHash, s.configurationHash, s.predecessor]
  );
}

export function directConservationAuthorizationId(
  coordinates: DirectConservationCoordinates,
  artist: Address,
  nonce: Hex
): Hex {
  const c = normalizeDirectConservationCoordinates(coordinates);
  const names = {
    "native-fixed": "6529STREAM_NATIVE_SALE_NONCE_V1",
    "erc20-fixed": "6529STREAM_ERC20_SALE_NONCE_V1",
    "english-auction": "6529STREAM_ENGLISH_AUCTION_NONCE_V1"
  } as const;
  return digest(["bytes32", "uint256", "address", "address", "bytes32"],
    [id(names[c.productKind]), c.chainId, c.product, address(artist, "artist"), hash(nonce, "nonce")]);
}

function requireKind(
  coordinates: DirectConservationCoordinates,
  expected: DirectConservationProductKind
): DirectConservationCoordinates {
  const c = normalizeDirectConservationCoordinates(coordinates);
  if (c.productKind !== expected) throw new Error(`Expected ${expected} product`);
  return c;
}

export function directConservationERC20SaleId(
  coordinates: DirectConservationCoordinates,
  collectionId: bigint,
  phaseId: Hex,
  saleNonce: bigint
): Hex {
  const c = requireKind(coordinates, "erc20-fixed");
  return digest(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), c.chainId, c.product, 0n, uint(collectionId), hash(phaseId, "phaseId"), uint(saleNonce)]);
}

export function directConservationERC20ConfigHash(saleId: Hex, config: DirectConservationERC20Config): Hex {
  return digest(["bytes32", "bytes32", DIRECT_CONSERVATION_ERC20_CONFIG_TUPLE],
    [id("6529STREAM_CURRENT_ERC20_FIXED_PRICE_CONFIG_V1"), hash(saleId, "saleId"), normalizeDirectConservationERC20Config(config)]);
}

function typedPayload<T extends object>(
  coordinates: DirectConservationCoordinates,
  expected: DirectConservationProductKind,
  name: string,
  version: "1" | "2",
  primaryType: string,
  tuple: string,
  message: T
): SigningPayload<T> {
  const c = requireKind(coordinates, expected);
  const fields = ParamType.from(tuple).components!.map(field => ({ name: field.name, type: field.type }));
  const payload = buildSigningPayload(c.chainId, c.product, name, primaryType, fields, message);
  if (version === "1") return payload;
  const domain = Object.freeze({ ...payload.domain, version });
  return Object.freeze({ ...payload, domain, digest: TypedDataEncoder.hash(domain, payload.types, payload.message) as Hex });
}

export function directConservationNativeTypedData(
  coordinates: DirectConservationCoordinates,
  message: DirectConservationNativeAuthorization
): SigningPayload<DirectConservationNativeAuthorization> {
  return typedPayload(coordinates, "native-fixed", "6529StreamFixedPriceSale", "2", "SaleAuthorization",
    DIRECT_CONSERVATION_NATIVE_AUTHORIZATION_TUPLE, normalizeDirectConservationNativeAuthorization(message));
}

export function directConservationERC20TypedData(
  coordinates: DirectConservationCoordinates,
  message: DirectConservationERC20Authorization
): SigningPayload<DirectConservationERC20Authorization> {
  return typedPayload(coordinates, "erc20-fixed", "6529StreamPaymentIntentVerifier", "1", "ERC20SaleAuthorization",
    DIRECT_CONSERVATION_ERC20_AUTHORIZATION_TUPLE, normalizeDirectConservationERC20Authorization(message));
}

export function directConservationAuctionTypedData(
  coordinates: DirectConservationCoordinates,
  message: DirectConservationAuctionAuthorization
): SigningPayload<DirectConservationAuctionAuthorization> {
  return typedPayload(coordinates, "english-auction", "6529StreamEnglishAuction", "2", "AuctionAuthorization",
    DIRECT_CONSERVATION_AUCTION_AUTHORIZATION_TUPLE, normalizeDirectConservationAuctionAuthorization(message));
}

export function directConservationPaymentIntentTypedData(
  coordinates: DirectConservationCoordinates,
  message: DirectConservationPaymentIntent
): SigningPayload<DirectConservationPaymentIntent> {
  return typedPayload(coordinates, "erc20-fixed", "6529StreamPaymentIntentVerifier", "1", "StreamPaymentIntent",
    DIRECT_CONSERVATION_PAYMENT_INTENT_TUPLE, normalizeDirectConservationPaymentIntent(message));
}

export function directConservationPaymentRevocationTypedData(
  coordinates: DirectConservationCoordinates,
  message: DirectConservationPaymentRevocation
): SigningPayload<DirectConservationPaymentRevocation> {
  return typedPayload(coordinates, "erc20-fixed", "6529StreamPaymentIntentVerifier", "1", "StreamPaymentIntentRevocation",
    DIRECT_CONSERVATION_PAYMENT_REVOCATION_TUPLE, normalizeDirectConservationPaymentRevocation(message));
}

const receiptReads = [
  `function directPrimaryBindings() view returns (${DIRECT_CONSERVATION_BINDINGS_TUPLE})`,
  `function directPrimarySaleReceipt(bytes32 authorizationId) view returns (${DIRECT_CONSERVATION_RECEIPT_TUPLE})`,
  "function directPrimarySaleReceiptHash(bytes32 authorizationId) view returns (bytes32)",
  "function authorizationId(address artist,bytes32 nonce) view returns (bytes32)",
  "function authorizationUsed(address artist,bytes32 nonce) view returns (bool)",
  "function cancelAuthorization(bytes32 nonce)"
] as const;

const controlCallsAndReads = [
  "function setPaused(bool paused_)",
  "function setPlatformSigner(address signer)",
  "function transferOwnership(address newOwner)",
  "function renounceOwnership()",
  "function owner() view returns (address)",
  "function paused() view returns (bool)",
  "function platformSigner() view returns (address)",
  "function signerEpoch() view returns (uint64)"
] as const;

export const DIRECT_CONSERVATION_NATIVE_ABI = Object.freeze([
  ...receiptReads,
  ...controlCallsAndReads,
  `function buy(${DIRECT_CONSERVATION_NATIVE_AUTHORIZATION_TUPLE} sale,bytes tokenData,bytes platformSignature,bytes artistSignature) payable returns (uint256 tokenId,bytes32 operationRoot)`,
  `function authorizationDigest(${DIRECT_CONSERVATION_NATIVE_AUTHORIZATION_TUPLE} sale) view returns (bytes32)`,
  "function primaryPolicy(uint256 collectionId) view returns (bytes32 policyHash,bytes32 profileId,address wallet)"
]);

export const DIRECT_CONSERVATION_ERC20_ABI = Object.freeze([
  ...receiptReads,
  ...controlCallsAndReads,
  "function raiseSignatureGasLimit(uint256 value)",
  "function signatureGasLimit() view returns (uint256)",
  `function buy(${DIRECT_CONSERVATION_ERC20_AUTHORIZATION_TUPLE} authorization,bytes tokenData,bytes platformSignature,bytes artistSignature,${DIRECT_CONSERVATION_PAYMENT_INTENT_TUPLE} intent,bytes payerSignature) returns (uint256 tokenId,bytes32 operationRoot)`,
  `function registerSale(${DIRECT_CONSERVATION_ERC20_CONFIG_TUPLE} config) returns (bytes32 saleId)`,
  "function cancelSale(bytes32 saleId)",
  `function saleRecord(bytes32 saleId) view returns (${DIRECT_CONSERVATION_ERC20_SALE_RECORD_TUPLE})`,
  "function saleIdFor(uint256 collectionId,bytes32 phaseId,uint256 saleNonce) view returns (bytes32)",
  `function authorizationDigest(${DIRECT_CONSERVATION_ERC20_AUTHORIZATION_TUPLE} authorization) view returns (bytes32)`,
  "function primaryPolicy(uint256 collectionId,bytes32 revenueClass) view returns (bytes32 policyHash,bytes32 profileId,address wallet)",
  `function paymentIntentDigest(${DIRECT_CONSERVATION_PAYMENT_INTENT_TUPLE} intent) view returns (bytes32)`,
  "function paymentIntentRevocationDigest(address payer,bytes32 nonce,uint64 deadline) view returns (bytes32)",
  "function isPaymentIntentNonceUsed(address payer,bytes32 nonce) view returns (bool)",
  "function revokePaymentIntent(bytes32 nonce)",
  "function revokePaymentIntentBySignature(address payer,bytes32 nonce,uint64 deadline,bytes signature)"
]);

export const DIRECT_CONSERVATION_AUCTION_ABI = Object.freeze([
  ...receiptReads,
  ...controlCallsAndReads,
  `function createAuction(${DIRECT_CONSERVATION_AUCTION_AUTHORIZATION_TUPLE} authorization,bytes tokenData,bytes platformSignature,bytes artistSignature) returns (uint256 tokenId)`,
  "function bid(uint256 tokenId,address recipient) payable",
  "function settle(uint256 tokenId)",
  "function cancel(uint256 tokenId)",
  "function setDeliveryRecipient(uint256 tokenId,address recipient)",
  "function claimNoBidNFT(uint256 tokenId,address recipient)",
  "function withdrawRefund(address recipient)",
  `function auction(uint256 tokenId) view returns (${DIRECT_CONSERVATION_AUCTION_TUPLE})`,
  "function auctionStatus(uint256 tokenId) view returns (uint8)",
  "function minimumBid(uint256 tokenId) view returns (uint256)",
  `function authorizationDigest(${DIRECT_CONSERVATION_AUCTION_AUTHORIZATION_TUPLE} authorization) view returns (bytes32)`,
  "function primaryPolicy(uint256 collectionId) view returns (bytes32 policyHash,bytes32 profileId,address wallet)"
]);

/** Read-only floor surface. The product-authenticated recordDirectPrimarySale write is deliberately absent. */
export const DIRECT_CONSERVATION_FLOOR_ABI = Object.freeze([
  `function directPrimarySaleFloorReceipt(bytes32 directKey) view returns (${DIRECT_CONSERVATION_FLOOR_RECEIPT_TUPLE})`,
  `function firstSale(uint256 collectionId) view returns (${DIRECT_CONSERVATION_FIRST_SALE_RECEIPT_TUPLE})`,
  `function releaseFloorReceipt(bytes32 releaseKey) view returns (${DIRECT_CONSERVATION_RELEASE_RECEIPT_TUPLE})`,
  `function sourceAt(uint64 sourceId) view returns (${DIRECT_CONSERVATION_SOURCE_TUPLE})`,
  "function sourceCount() view returns (uint64)",
  "function sourceSetHead() view returns (uint64 count,bytes32 head)",
  "function sourceSetHashAt(uint64 count) view returns (bytes32)"
]);

const interfaces = Object.freeze({
  "native-fixed": new Interface(DIRECT_CONSERVATION_NATIVE_ABI),
  "erc20-fixed": new Interface(DIRECT_CONSERVATION_ERC20_ABI),
  "english-auction": new Interface(DIRECT_CONSERVATION_AUCTION_ABI)
});
const floorInterface = new Interface(DIRECT_CONSERVATION_FLOOR_ABI);

export function directConservationInterface(kind: DirectConservationProductKind): Interface {
  return new Interface(interfaces[productKind(kind)].fragments);
}

function interfaceId(abi: readonly string[]): Hex {
  const iface = new Interface(abi);
  let value = 0n;
  for (const fragment of iface.fragments) {
    if (fragment.type === "function") value ^= BigInt(iface.getFunction(fragment.format("sighash"))!.selector);
  }
  return `0x${value.toString(16).padStart(8, "0")}` as Hex;
}

export const DIRECT_CONSERVATION_RECEIPT_INTERFACE_ID = interfaceId(receiptReads.slice(0, 3));
/** Includes the protocol-only writer in the original capability identity, but exposes no writer builder. */
export const DIRECT_CONSERVATION_FLOOR_INTERFACE_ID = interfaceId([
  "function recordDirectPrimarySale(bytes32 authorizationId) returns (bytes32 receiptHash)",
  DIRECT_CONSERVATION_FLOOR_ABI[0]!
]);

interface DirectConservationSignedData {
  readonly tokenData: Hex;
  readonly platformSignature: Hex;
  readonly artistSignature: Hex;
}

/** Original one-step Ownable and product controls; no new governance/signature transport. */
export type DirectConservationCommonControlRequest =
  | Readonly<{
      kind: "setPaused";
      paused: boolean;
    }>
  | Readonly<{
      kind: "setPlatformSigner";
      signer: Address;
    }>
  | Readonly<{
      kind: "transferOwnership";
      newOwner: Address;
    }>
  | Readonly<{
      kind: "renounceOwnership";
    }>;

export type DirectConservationSignatureGasRequest = Readonly<{
  kind: "raiseSignatureGasLimit";
  value: bigint;
}>;

export type DirectConservationNativeRequest = Readonly<{ productKind: "native-fixed" }> & (
  | DirectConservationCommonControlRequest
  | (Readonly<{
    kind: "buy";
    authorization: DirectConservationNativeAuthorization;
  }> & DirectConservationSignedData)
  | Readonly<{
    kind: "cancelAuthorization";
    nonce: Hex;
  }>
);

export type DirectConservationERC20Request = Readonly<{ productKind: "erc20-fixed" }> & (
  | DirectConservationCommonControlRequest
  | DirectConservationSignatureGasRequest
  | (Readonly<{
      kind: "buy";
      authorization: DirectConservationERC20Authorization;
      intent: DirectConservationPaymentIntent;
      payerSignature: Hex;
    }> & DirectConservationSignedData)
  | Readonly<{
    kind: "registerSale";
    config: DirectConservationERC20Config;
  }>
  | Readonly<{
    kind: "cancelSale";
    saleId: Hex;
  }>
  | Readonly<{
    kind: "cancelAuthorization" | "revokePaymentIntent";
    nonce: Hex;
  }>
  | Readonly<{
      kind: "revokePaymentIntentBySignature";
      payer: Address;
      nonce: Hex;
      deadline: bigint;
      signature: Hex;
    }>
);

export type DirectConservationAuctionRequest = Readonly<{ productKind: "english-auction" }> & (
  | DirectConservationCommonControlRequest
  | (Readonly<{
    kind: "createAuction";
    authorization: DirectConservationAuctionAuthorization;
  }> & DirectConservationSignedData)
  | Readonly<{
    kind: "bid";
    tokenId: bigint;
    recipient: Address;
    amount: bigint;
  }>
  | Readonly<{
    kind: "settle" | "cancel";
    tokenId: bigint;
  }>
  | Readonly<{
    kind: "setDeliveryRecipient" | "claimNoBidNFT";
    tokenId: bigint;
    recipient: Address;
  }>
  | Readonly<{
    kind: "withdrawRefund";
    recipient: Address;
  }>
  | Readonly<{
    kind: "cancelAuthorization";
    nonce: Hex;
  }>
);

export type DirectConservationRequest =
  | DirectConservationNativeRequest
  | DirectConservationERC20Request
  | DirectConservationAuctionRequest;

export interface DirectConservationCall {
  readonly coordinates: DirectConservationCoordinates;
  readonly caller: Address;
  readonly request: DirectConservationRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

function positive(value: bigint, label: string): bigint {
  if (value === 0n) throw new Error(`${label} must be nonzero`);
  return value;
}

function signedData(input: Record<string, unknown>, expectedHash: Hex): DirectConservationSignedData {
  const tokenData = bytes(input.tokenData, "tokenData", DIRECT_CONSERVATION_MAX_TOKEN_DATA_BYTES);
  if (keccak256(tokenData) !== expectedHash) throw new Error("tokenDataHash mismatch");
  return Object.freeze({
    tokenData,
    platformSignature: bytes(input.platformSignature, "platformSignature", DIRECT_CONSERVATION_MAX_SIGNATURE_BYTES),
    artistSignature: bytes(input.artistSignature, "artistSignature", DIRECT_CONSERVATION_MAX_SIGNATURE_BYTES)
  });
}

function requireMintAuthorization(
  a: DirectConservationNativeAuthorization | DirectConservationAuctionAuthorization
): void {
  positive(a.collectionId, "collectionId");
  for (const field of ["phaseId", "profileId", "expectedPrimaryPolicyHash", "mintCommitment", "mintPolicyHash", "nonce"] as const) {
    hash(a[field], field, true);
  }
  address(a.artist, "artist", true);
}

function requireERC20Config(config: DirectConservationERC20Config): void {
  positive(config.collectionId, "collectionId");
  positive(config.price, "price");
  address(config.asset, "asset", true);
  hash(config.phaseId, "phaseId", true);
  hash(config.mintPolicyHash, "mintPolicyHash", true);
  hash(config.expectedPrimaryPolicyHash, "expectedPrimaryPolicyHash", true);
  if (config.revenueClass !== DIRECT_CONSERVATION_PRIMARY_SALE || config.endsAt <= config.startsAt) {
    throw new Error("Invalid original ERC20 configuration");
  }
}

export function normalizeDirectConservationRequest(
  value: DirectConservationRequest
): DirectConservationRequest {
  if (!value || typeof value !== "object") throw new Error("Expected DIRECT request");
  const p = productKind(value.productKind);
  const kind = value.kind;
  const base = { productKind: p, kind };
  const fields = (names: readonly string[]) => exact(value, ["productKind", "kind", ...names], "request");
  if (kind === "setPaused") {
    const input = fields(["paused"]);
    if (typeof input.paused !== "boolean") {
      throw new Error("paused must be boolean");
    }
    return Object.freeze({ productKind: p, kind, paused: input.paused });
  }
  if (kind === "setPlatformSigner") {
    const input = fields(["signer"]);
    return Object.freeze({
      productKind: p,
      kind,
      signer: address(input.signer, "signer", true)
    });
  }
  if (kind === "transferOwnership") {
    const input = fields(["newOwner"]);
    return Object.freeze({
      productKind: p,
      kind,
      newOwner: address(input.newOwner, "newOwner", true)
    });
  }
  if (kind === "renounceOwnership") {
    fields([]);
    return Object.freeze({ productKind: p, kind });
  }
  if (kind === "raiseSignatureGasLimit" && p === "erc20-fixed") {
    const input = fields(["value"]);
    return Object.freeze({
      productKind: p,
      kind,
      value: positive(uint(input.value, 64, "signature gas limit"), "signature gas limit")
    });
  }
  if (kind === "cancelAuthorization") {
    const input = fields(["nonce"]);
    return Object.freeze({ ...base, nonce: hash(input.nonce, "nonce", p !== "erc20-fixed") }) as DirectConservationRequest;
  }
  if (kind === "buy" && p === "native-fixed") {
    const input = fields(["authorization", "tokenData", "platformSignature", "artistSignature"]);
    const a = normalizeDirectConservationNativeAuthorization(input.authorization as DirectConservationNativeAuthorization);
    requireMintAuthorization(a);
    address(a.payer, "payer", true);
    address(a.recipient, "recipient", true);
    return Object.freeze({ productKind: p, kind, authorization: a, ...signedData(input, a.tokenDataHash) });
  }
  if (kind === "buy" && p === "erc20-fixed") {
    const input = fields(["authorization", "tokenData", "platformSignature", "artistSignature", "intent", "payerSignature"]);
    const a = normalizeDirectConservationERC20Authorization(input.authorization as DirectConservationERC20Authorization);
    address(a.payer, "payer", true);
    address(a.recipient, "recipient", true);
    address(a.artist, "artist", true);
    hash(a.mintCommitment, "mintCommitment", true);
    return Object.freeze({
      productKind: p,
      kind,
      authorization: a,
      ...signedData(input, a.tokenDataHash),
      intent: normalizeDirectConservationPaymentIntent(input.intent as DirectConservationPaymentIntent),
      payerSignature: bytes(input.payerSignature, "payerSignature", DIRECT_CONSERVATION_MAX_SIGNATURE_BYTES)
    });
  }
  if (p === "erc20-fixed") {
    if (kind === "registerSale") {
      const input = fields(["config"]);
      const config = normalizeDirectConservationERC20Config(input.config as DirectConservationERC20Config);
      requireERC20Config(config);
      return Object.freeze({ productKind: p, kind, config });
    }
    if (kind === "cancelSale") {
      const input = fields(["saleId"]);
      return Object.freeze({ productKind: p, kind, saleId: hash(input.saleId, "saleId") });
    }
    if (kind === "revokePaymentIntent") {
      const input = fields(["nonce"]);
      return Object.freeze({ productKind: p, kind, nonce: hash(input.nonce, "nonce") });
    }
    if (kind === "revokePaymentIntentBySignature") {
      const input = fields(["payer", "nonce", "deadline", "signature"]);
      return Object.freeze({
        productKind: p,
        kind,
        payer: address(input.payer, "payer", true),
        nonce: hash(input.nonce, "nonce"),
        deadline: uint(input.deadline, 64),
        signature: bytes(input.signature, "signature", DIRECT_CONSERVATION_MAX_SIGNATURE_BYTES)
      });
    }
  }
  if (p === "english-auction") {
    if (kind === "createAuction") {
      const input = fields(["authorization", "tokenData", "platformSignature", "artistSignature"]);
      const a = normalizeDirectConservationAuctionAuthorization(input.authorization as DirectConservationAuctionAuthorization);
      requireMintAuthorization(a);
      if (a.endTime <= a.startTime || a.extensionWindow > 86400n || a.minBidIncrementBps === 0n || a.minBidIncrementBps > 10000n) {
        throw new Error("Invalid original auction terms");
      }
      return Object.freeze({ productKind: p, kind, authorization: a, ...signedData(input, a.tokenDataHash) });
    }
    if (kind === "withdrawRefund") {
      const input = fields(["recipient"]);
      return Object.freeze({ productKind: p, kind, recipient: address(input.recipient, "recipient", true) });
    }
    if (kind === "settle" || kind === "cancel") {
      const input = fields(["tokenId"]);
      return Object.freeze({ productKind: p, kind, tokenId: positive(uint(input.tokenId), "tokenId") });
    }
    if (kind === "bid" || kind === "setDeliveryRecipient" || kind === "claimNoBidNFT") {
      const input = fields(kind === "bid" ? ["tokenId", "recipient", "amount"] : ["tokenId", "recipient"]);
      const result = {
        productKind: p,
        kind,
        tokenId: positive(uint(input.tokenId), "tokenId"),
        recipient: address(input.recipient, "recipient", true)
      };
      return Object.freeze(kind === "bid"
        ? { ...result, amount: positive(uint(input.amount), "amount") }
        : result) as DirectConservationAuctionRequest;
    }
  }
  throw new Error("Unsupported original DIRECT product method");
}

function callArguments(request: DirectConservationRequest): readonly unknown[] {
  switch (request.kind) {
    case "setPaused":
      return [request.paused];
    case "setPlatformSigner":
      return [request.signer];
    case "transferOwnership":
      return [request.newOwner];
    case "renounceOwnership":
      return [];
    case "raiseSignatureGasLimit":
      return [request.value];
    case "buy":
      return request.productKind === "native-fixed"
        ? [request.authorization, request.tokenData, request.platformSignature, request.artistSignature]
        : [request.authorization, request.tokenData, request.platformSignature, request.artistSignature, request.intent, request.payerSignature];
    case "createAuction":
      return [request.authorization, request.tokenData, request.platformSignature, request.artistSignature];
    case "cancelAuthorization":
    case "revokePaymentIntent":
      return [request.nonce];
    case "revokePaymentIntentBySignature":
      return [request.payer, request.nonce, request.deadline, request.signature];
    case "registerSale":
      return [request.config];
    case "cancelSale":
      return [request.saleId];
    case "bid":
    case "setDeliveryRecipient":
    case "claimNoBidNFT":
      return [request.tokenId, request.recipient];
    case "settle":
    case "cancel":
      return [request.tokenId];
    case "withdrawRefund":
      return [request.recipient];
  }
}

/** Permissionless, principal, and owner admission remain the original contract's responsibility. */
export function prepareDirectConservationCall(
  coordinates: DirectConservationCoordinates,
  caller: Address,
  request: DirectConservationRequest
): DirectConservationCall {
  const c = normalizeDirectConservationCoordinates(coordinates);
  const actor = address(caller, "caller", true);
  const r = normalizeDirectConservationRequest(request);
  if (r.productKind !== c.productKind) throw new Error("Request product kind differs from coordinates");
  let value = 0n;
  if (r.kind === "buy" && r.productKind === "native-fixed") {
    if (r.authorization.payer !== actor) throw new Error("Native payer must be the literal caller");
    value = r.authorization.price;
  }
  if (r.kind === "buy" && r.productKind === "erc20-fixed" && r.authorization.payer === c.product) {
    throw new Error("ERC20 payer cannot be the pulling adapter");
  }
  if (r.kind === "bid") value = r.amount;
  const data = bytes(interfaces[c.productKind].encodeFunctionData(r.kind, callArguments(r)), "call data");
  return Object.freeze({
    coordinates: c,
    caller: actor,
    request: r,
    call: Object.freeze({ to: c.product, data, value }),
    factsVerified: false
  });
}

export function normalizeDirectConservationCall(value: DirectConservationCall): DirectConservationCall {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "prepared call");
  exact(value.call, ["to", "data", "value"], "call");
  const result = prepareDirectConservationCall(value.coordinates, value.caller, value.request);
  if (value.factsVerified !== false || address(value.call.to, "call.to") !== result.call.to
      || bytes(value.call.data, "call.data") !== result.call.data || uint(value.call.value) !== result.call.value) {
    throw new Error("Prepared DIRECT call differs from its original request");
  }
  return result;
}

export type DirectConservationControlRequest =
  | (DirectConservationCommonControlRequest & Readonly<{
      productKind: DirectConservationProductKind;
    }>)
  | (DirectConservationSignatureGasRequest & Readonly<{
      productKind: "erc20-fixed";
    }>);

/** Supplied product-local observations, including a zero owner after renunciation. */
export interface DirectConservationControlState {
  readonly owner: Address;
  readonly paused: boolean;
  readonly platformSigner: Address;
  readonly signerEpoch: bigint;
  /** Original ERC20 uint256 getter; null for native fixed price and auction products. */
  readonly signatureGasLimit: bigint | null;
}

export type DirectConservationControlEvent =
  | Readonly<{
      name: "SalesPauseChanged" | "AuctionsPauseChanged";
      args: readonly [boolean];
    }>
  | Readonly<{
      name: "SalePlatformSignerChanged" | "PlatformSignerChanged" | "AuctionPlatformSignerChanged";
      args: readonly [Address, bigint];
    }>
  | Readonly<{
      name: "OwnershipTransferred";
      args: readonly [Address, Address];
    }>
  | Readonly<{
      name: "SignatureGasLimitRaised";
      args: readonly [bigint, bigint];
    }>;

export interface DirectConservationControlTransition {
  readonly before: DirectConservationControlState;
  readonly after: DirectConservationControlState;
  readonly expectedEvent: DirectConservationControlEvent;
  readonly factsVerified: false;
}

export function isDirectConservationControlRequest(
  request: DirectConservationRequest
): request is DirectConservationControlRequest {
  return request.kind === "setPaused"
    || request.kind === "setPlatformSigner"
    || request.kind === "transferOwnership"
    || request.kind === "renounceOwnership"
    || request.kind === "raiseSignatureGasLimit";
}

export function normalizeDirectConservationControlState(
  kind: DirectConservationProductKind,
  state: DirectConservationControlState
): DirectConservationControlState {
  const p = productKind(kind);
  const input = exact(state, [
    "owner",
    "paused",
    "platformSigner",
    "signerEpoch",
    "signatureGasLimit"
  ], "control state");
  if (typeof input.paused !== "boolean") {
    throw new Error("control state paused must be boolean");
  }
  if (p !== "erc20-fixed" && input.signatureGasLimit !== null) {
    throw new Error("Only the original ERC20 product has signatureGasLimit");
  }
  return Object.freeze({
    owner: address(input.owner, "owner"),
    paused: input.paused,
    platformSigner: address(input.platformSigner, "platformSigner"),
    signerEpoch: uint(input.signerEpoch, 64, "signerEpoch"),
    signatureGasLimit: p === "erc20-fixed"
      ? uint(input.signatureGasLimit, 256, "signatureGasLimit")
      : null
  });
}

/**
 * Predicts one original control call from supplied state. These calls have no expected-state
 * argument; recapture before execution rather than treating this snapshot as a concurrency guard.
 * Every accepted call emits its event, including same-value pause and self-ownership transfer.
 */
export function directConservationControlTransition(
  prepared: DirectConservationCall,
  state: DirectConservationControlState
): DirectConservationControlTransition {
  const plan = normalizeDirectConservationCall(prepared);
  const request = plan.request;
  if (!isDirectConservationControlRequest(request)) {
    throw new Error("Expected an original product control call");
  }
  const before = normalizeDirectConservationControlState(plan.coordinates.productKind, state);
  if (before.owner !== plan.caller) {
    throw new Error("Control call requires the supplied current owner as literal caller");
  }
  let after: DirectConservationControlState;
  let expectedEvent: DirectConservationControlEvent;
  switch (request.kind) {
    case "setPaused":
      after = Object.freeze({ ...before, paused: request.paused });
      expectedEvent = Object.freeze({
        name: request.productKind === "english-auction" ? "AuctionsPauseChanged" : "SalesPauseChanged",
        args: Object.freeze([request.paused] as const)
      });
      break;
    case "setPlatformSigner": {
      const nextEpoch = uint(before.signerEpoch + 1n, 64, "next signerEpoch");
      after = Object.freeze({ ...before, platformSigner: request.signer, signerEpoch: nextEpoch });
      const name = request.productKind === "native-fixed"
        ? "SalePlatformSignerChanged"
        : request.productKind === "erc20-fixed"
          ? "PlatformSignerChanged"
          : "AuctionPlatformSignerChanged";
      expectedEvent = Object.freeze({
        name,
        args: Object.freeze([request.signer, nextEpoch] as const)
      });
      break;
    }
    case "transferOwnership":
      after = Object.freeze({ ...before, owner: request.newOwner });
      expectedEvent = Object.freeze({
        name: "OwnershipTransferred",
        args: Object.freeze([before.owner, request.newOwner] as const)
      });
      break;
    case "renounceOwnership":
      after = Object.freeze({ ...before, owner: ZeroAddress as Address });
      expectedEvent = Object.freeze({
        name: "OwnershipTransferred",
        args: Object.freeze([before.owner, ZeroAddress as Address] as const)
      });
      break;
    case "raiseSignatureGasLimit": {
      const previous = before.signatureGasLimit!;
      if (request.value <= previous) {
        throw new Error("Signature gas limit must strictly increase");
      }
      after = Object.freeze({ ...before, signatureGasLimit: request.value });
      expectedEvent = Object.freeze({
        name: "SignatureGasLimitRaised",
        args: Object.freeze([previous, request.value] as const)
      });
      break;
    }
  }
  return Object.freeze({ before, after, expectedEvent, factsVerified: false });
}

function checkedSaleRecord(
  coordinates: DirectConservationCoordinates,
  authorization: DirectConservationERC20Authorization,
  supplied: DirectConservationERC20SaleRecord | undefined
): DirectConservationERC20SaleRecord {
  if (!supplied) throw new Error("Original ERC20 sale record is required");
  const record = normalizeDirectConservationERC20SaleRecord(supplied);
  const config = record.config;
  const saleId = directConservationERC20SaleId(coordinates, config.collectionId, config.phaseId, record.saleNonce);
  positive(record.saleNonce, "saleNonce");
  requireERC20Config(config);
  if (saleId !== authorization.saleId || record.configHash !== authorization.saleConfigHash
      || directConservationERC20ConfigHash(saleId, config) !== record.configHash) {
    throw new Error("Original sale ID/configuration commitment mismatch");
  }
  return record;
}

/** Exact original Manager input; operation root/ID must come from the Manager's original preview. */
export function directConservationMintBatch(
  prepared: DirectConservationCall,
  saleRecord?: DirectConservationERC20SaleRecord
): DirectConservationMintBatch {
  const plan = normalizeDirectConservationCall(prepared);
  const request = plan.request;
  const c = plan.coordinates;
  if (request.kind !== "buy" && request.kind !== "createAuction") {
    throw new Error("This original product call does not mint");
  }
  let collectionId: bigint;
  let phaseId: Hex;
  let expectedPolicyHash: Hex;
  let payer: Address;
  let initialRecipient: Address;
  let beneficiary: Address;
  let contextHash: Hex;
  if (request.productKind === "erc20-fixed") {
    const record = checkedSaleRecord(c, request.authorization, saleRecord);
    collectionId = record.config.collectionId;
    phaseId = record.config.phaseId;
    expectedPolicyHash = record.config.mintPolicyHash;
    payer = request.authorization.payer;
    initialRecipient = request.authorization.recipient;
    beneficiary = initialRecipient;
    contextHash = directConservationERC20TypedData(c, request.authorization).digest;
  } else {
    const a = request.authorization;
    collectionId = a.collectionId;
    phaseId = a.phaseId;
    expectedPolicyHash = a.mintPolicyHash;
    if (request.productKind === "native-fixed") {
      payer = request.authorization.payer;
      initialRecipient = request.authorization.recipient;
      beneficiary = initialRecipient;
      contextHash = directConservationNativeTypedData(c, request.authorization).digest;
    } else {
      payer = ZeroAddress as Address;
      initialRecipient = c.product;
      beneficiary = a.artist;
      contextHash = directConservationAuctionTypedData(c, request.authorization).digest;
    }
  }
  return Object.freeze({
    collectionId,
    phaseId,
    payer,
    authorizer: ZeroAddress as Address,
    initialRecipients: Object.freeze([initialRecipient]),
    beneficiaries: Object.freeze([beneficiary]),
    tokenData: Object.freeze([request.tokenData]),
    mintCommitments: Object.freeze([request.authorization.mintCommitment]),
    expectedPolicyHash,
    authorizationId: directConservationAuthorizationId(c, request.authorization.artist, request.authorization.nonce),
    contextHash,
    resolverData: "0x" as Hex
  });
}

export interface DirectConservationExecutionFacts {
  readonly timestamp: bigint;
  readonly signerEpoch: bigint;
}

/** Only public term checks from supplied facts. Signatures, authority, replay, funding and mint admission remain unverified. */
export function validateDirectConservationExecutionTerms(
  prepared: DirectConservationCall,
  facts: DirectConservationExecutionFacts,
  suppliedSaleRecord?: DirectConservationERC20SaleRecord
): Readonly<{
  factsVerified: false;
  paymentLane: "caller" | "signature" | null;
}> {
  const plan = normalizeDirectConservationCall(prepared);
  exact(facts, ["timestamp", "signerEpoch"], "execution facts");
  const timestamp = uint(facts.timestamp);
  const epoch = uint(facts.signerEpoch, 64);
  const request = plan.request;
  let paymentLane: "caller" | "signature" | null = null;
  if (request.kind === "buy" || request.kind === "createAuction") {
    const a = request.authorization;
    if (a.signerEpoch !== epoch || timestamp > a.deadline) throw new Error("Expired authorization or signer epoch mismatch");
  }
  if (request.kind === "createAuction") {
    if (request.authorization.endTime <= timestamp || request.authorization.endTime > timestamp + 365n * 86400n) {
      throw new Error("Auction end is outside the original execution window");
    }
  }
  if (request.kind === "registerSale" && request.config.endsAt < timestamp) {
    throw new Error("Original sale configuration has ended");
  }
  if (request.kind === "revokePaymentIntentBySignature" && request.deadline < timestamp) {
    throw new Error("Payment revocation expired");
  }
  if (request.kind === "buy" && request.productKind === "erc20-fixed") {
    const record = checkedSaleRecord(plan.coordinates, request.authorization, suppliedSaleRecord);
    const config = record.config;
    if (record.cancelled || timestamp < config.startsAt || timestamp > config.endsAt) {
      throw new Error("Original ERC20 sale is unavailable");
    }
    paymentLane = request.authorization.payer === plan.caller && request.payerSignature === "0x" ? "caller" : "signature";
    if (paymentLane === "signature") {
      const intent = request.intent;
      if (intent.payer !== request.authorization.payer || intent.asset !== config.asset
          || intent.maxAmount < config.price || intent.saleRef !== request.authorization.saleId
          || intent.expectedPrimaryPolicyHash !== config.expectedPrimaryPolicyHash || timestamp > intent.deadline) {
        throw new Error("Original payer intent does not authorize these terms");
      }
    }
  }
  return Object.freeze({ factsVerified: false, paymentLane });
}

export interface DirectConservationAdmissionFacts {
  readonly status: bigint;
  readonly registeredAt: bigint;
  readonly statusUpdatedAt: bigint;
  readonly revision: bigint;
  readonly timestamp: bigint;
}

/** Temporal registry rules only; this does not prove module admission or runtime bindings. */
export function validateDirectConservationAdmission(
  kind: DirectConservationProductKind,
  createdAt: bigint,
  registryRevision: bigint,
  facts: DirectConservationAdmissionFacts
): Readonly<{ factsVerified: false }> {
  const p = productKind(kind);
  exact(facts, ["status", "registeredAt", "statusUpdatedAt", "revision", "timestamp"], "admission facts");
  const status = uint(facts.status, 8);
  const registered = positive(uint(facts.registeredAt, 64), "registeredAt");
  const updated = uint(facts.statusUpdatedAt, 64);
  const revision = positive(uint(facts.revision, 64), "revision");
  const now = uint(facts.timestamp, 64);
  const created = positive(uint(createdAt, 64), "createdAt");
  const originRevision = positive(uint(registryRevision, 64), "registryRevision");
  if ((status !== 1n && status !== 2n) || registered > now || updated < registered || updated > now
      || created < registered || created > now || originRevision > revision) {
    throw new Error("Invalid original DIRECT registry time/revision facts");
  }
  if (p !== "english-auction" && (status !== 1n || created !== now || originRevision !== revision)) {
    throw new Error("Fixed-price paid receipt requires current ACTIVE admission");
  }
  if (status === 2n && (created >= updated || originRevision >= revision)) {
    throw new Error("Auction creation time and revision must both strictly precede deprecation");
  }
  return Object.freeze({ factsVerified: false });
}

export function directConservationAuctionStatus(
  value: DirectConservationAuction,
  timestamp: bigint
): bigint {
  const auction = normalizeDirectConservationAuction(value);
  const now = uint(timestamp);
  if (auction.artist === ZeroAddress) return 0n;
  if (auction.cancelled) return 7n;
  if (auction.settled) return auction.highestBid === 0n ? 5n : 6n;
  if (now < auction.startTime) return 1n;
  if (now < auction.endTime) return 2n;
  return auction.highestBid === 0n ? 3n : 4n;
}

export function directConservationMinimumBid(value: DirectConservationAuction): bigint {
  const auction = normalizeDirectConservationAuction(value);
  address(auction.artist, "auction.artist", true);
  if (auction.highestBid === 0n) return auction.reservePrice === 0n ? 1n : auction.reservePrice;
  const increment = (auction.highestBid * auction.minBidIncrementBps + 9999n) / 10000n;
  return uint(auction.highestBid + increment);
}

export interface DirectConservationHistory {
  readonly receipt: DirectConservationFloorReceipt;
  readonly firstSale: DirectConservationFirstSaleReceipt;
  readonly release: DirectConservationReleaseReceipt | null;
  readonly factsVerified: false;
}

/** Checks immutable history joins without consulting or authorizing any former/current provider. */
export function validateDirectConservationHistory(
  coordinates: DirectConservationFloorCoordinates,
  receipt: DirectConservationFloorReceipt,
  firstSale: DirectConservationFirstSaleReceipt,
  release: DirectConservationReleaseReceipt | null
): DirectConservationHistory {
  const c = normalizeDirectConservationFloorCoordinates(coordinates);
  const r = normalizeDirectConservationFloorReceipt(receipt);
  const first = normalizeDirectConservationFirstSaleReceipt(firstSale);
  const next = release === null ? null : normalizeDirectConservationReleaseReceipt(release);
  if (r.sale.amount === 0n || r.bindings.core !== c.core || r.bindings.deploymentChainId !== c.chainId
      || directConservationKey(r.bindings, r.adapter, r.authorizationId) !== r.directKey
      || directConservationReceiptHash(r.bindings, r.adapter, r.authorizationId, r.sale) !== r.originalReceiptHash
      || directConservationFloorReceiptHash(c, r) !== r.receiptHash) {
    throw new Error("DIRECT history original receipt/key mismatch");
  }
  if (first.receiptHash !== r.firstSaleReceiptHash || directConservationFirstSaleReceiptHash(c, first) !== first.receiptHash
      || first.collectionId !== r.sale.collectionId || first.effectiveTier !== r.effectiveTier) {
    throw new Error("Historical first-sale receipt mismatch");
  }
  if (next === null) {
    if (r.releaseReceiptHash !== ZeroHash) throw new Error("Historical release receipt required");
  } else if (next.receiptHash !== r.releaseReceiptHash || directConservationReleaseReceiptHash(c, next) !== next.receiptHash
      || next.collectionId !== r.sale.collectionId || next.effectiveTier !== r.effectiveTier
      || directConservationReleaseKey(c.chainId, c.core, next.collectionId, next.context) !== next.releaseKey) {
    throw new Error("Historical release receipt mismatch");
  }
  return Object.freeze({ receipt: r, firstSale: first, release: next, factsVerified: false });
}

export type DirectConservationReadRequest =
  | Readonly<{
    kind: "owner" | "paused" | "platformSigner" | "signerEpoch" | "signatureGasLimit";
  }>
  | Readonly<{ kind: "directPrimaryBindings" }>
  | Readonly<{
    kind: "directPrimarySaleReceipt" | "directPrimarySaleReceiptHash";
    authorizationId: Hex;
  }>
  | Readonly<{
    kind: "authorizationId" | "authorizationUsed";
    artist: Address;
    nonce: Hex;
  }>
  | Readonly<{
      kind: "authorizationDigest";
      authorization: DirectConservationNativeAuthorization | DirectConservationERC20Authorization | DirectConservationAuctionAuthorization;
    }>
  | Readonly<{
    kind: "primaryPolicy";
    collectionId: bigint;
  }>
  | Readonly<{
    kind: "saleRecord";
    saleId: Hex;
  }>
  | Readonly<{
    kind: "saleIdFor";
    collectionId: bigint;
    phaseId: Hex;
    saleNonce: bigint;
  }>
  | Readonly<{
    kind: "paymentIntentDigest";
    intent: DirectConservationPaymentIntent;
  }>
  | Readonly<{
    kind: "paymentIntentRevocationDigest";
    payer: Address;
    nonce: Hex;
    deadline: bigint;
  }>
  | Readonly<{
    kind: "isPaymentIntentNonceUsed";
    payer: Address;
    nonce: Hex;
  }>
  | Readonly<{
    kind: "auction" | "auctionStatus" | "minimumBid";
    tokenId: bigint;
  }>;

/** Raw read coordinates may be zero/unknown. No paid, available or authorized conclusion follows. */
export function prepareDirectConservationRead(
  coordinates: DirectConservationCoordinates,
  request: DirectConservationReadRequest
): UnsignedCall {
  const c = normalizeDirectConservationCoordinates(coordinates);
  if (!request || typeof request !== "object") throw new Error("Expected original read request");
  const fields = (names: readonly string[]) => exact(request, ["kind", ...names], "read request");
  let args: readonly unknown[];
  switch (request.kind) {
    case "signatureGasLimit":
      requireKind(c, "erc20-fixed");
      fields([]);
      args = [];
      break;
    case "owner":
    case "paused":
    case "platformSigner":
    case "signerEpoch":
    case "directPrimaryBindings":
      fields([]);
      args = [];
      break;
    case "directPrimarySaleReceipt":
    case "directPrimarySaleReceiptHash":
      fields(["authorizationId"]);
      args = [hash(request.authorizationId, "authorizationId")];
      break;
    case "authorizationId":
    case "authorizationUsed":
      fields(["artist", "nonce"]);
      args = [address(request.artist, "artist"), hash(request.nonce, "nonce")];
      break;
    case "authorizationDigest": {
      fields(["authorization"]);
      const tuple = c.productKind === "native-fixed" ? DIRECT_CONSERVATION_NATIVE_AUTHORIZATION_TUPLE
        : c.productKind === "erc20-fixed" ? DIRECT_CONSERVATION_ERC20_AUTHORIZATION_TUPLE : DIRECT_CONSERVATION_AUCTION_AUTHORIZATION_TUPLE;
      args = [normalize(tuple, request.authorization)];
      break;
    }
    case "primaryPolicy":
      fields(["collectionId"]);
      args = c.productKind === "erc20-fixed" ? [uint(request.collectionId), DIRECT_CONSERVATION_PRIMARY_SALE] : [uint(request.collectionId)];
      break;
    case "saleRecord":
      requireKind(c, "erc20-fixed");
      fields(["saleId"]);
      args = [hash(request.saleId, "saleId")];
      break;
    case "saleIdFor":
      requireKind(c, "erc20-fixed");
      fields(["collectionId", "phaseId", "saleNonce"]);
      args = [uint(request.collectionId), hash(request.phaseId, "phaseId"), uint(request.saleNonce)];
      break;
    case "paymentIntentDigest":
      requireKind(c, "erc20-fixed");
      fields(["intent"]);
      args = [normalizeDirectConservationPaymentIntent(request.intent)];
      break;
    case "paymentIntentRevocationDigest":
      requireKind(c, "erc20-fixed");
      fields(["payer", "nonce", "deadline"]);
      args = [address(request.payer, "payer"), hash(request.nonce, "nonce"), uint(request.deadline, 64)];
      break;
    case "isPaymentIntentNonceUsed":
      requireKind(c, "erc20-fixed");
      fields(["payer", "nonce"]);
      args = [address(request.payer, "payer"), hash(request.nonce, "nonce")];
      break;
    case "auction":
    case "auctionStatus":
    case "minimumBid":
      requireKind(c, "english-auction");
      fields(["tokenId"]);
      args = [uint(request.tokenId)];
      break;
    default:
      throw new Error("Unsupported original product read");
  }
  return Object.freeze({ to: c.product, data: interfaces[c.productKind].encodeFunctionData(request.kind, args) as Hex, value: 0n });
}

export type DirectConservationFloorReadRequest =
  | Readonly<{
    kind: "directPrimarySaleFloorReceipt";
    directKey: Hex;
  }>
  | Readonly<{
    kind: "firstSale";
    collectionId: bigint;
  }>
  | Readonly<{
    kind: "releaseFloorReceipt";
    releaseKey: Hex;
  }>
  | Readonly<{
    kind: "sourceAt";
    sourceId: bigint;
  }>
  | Readonly<{
    kind: "sourceSetHashAt";
    count: bigint;
  }>
  | Readonly<{ kind: "sourceCount" | "sourceSetHead" }>;

export function prepareDirectConservationFloorRead(
  coordinates: DirectConservationFloorCoordinates,
  request: DirectConservationFloorReadRequest
): UnsignedCall {
  const c = normalizeDirectConservationFloorCoordinates(coordinates);
  if (!request || typeof request !== "object") throw new Error("Expected floor read request");
  let args: readonly unknown[];
  switch (request.kind) {
    case "directPrimarySaleFloorReceipt":
      exact(request, ["kind", "directKey"], "floor read");
      args = [hash(request.directKey, "directKey")];
      break;
    case "firstSale":
      exact(request, ["kind", "collectionId"], "floor read");
      args = [uint(request.collectionId)];
      break;
    case "releaseFloorReceipt":
      exact(request, ["kind", "releaseKey"], "floor read");
      args = [hash(request.releaseKey, "releaseKey")];
      break;
    case "sourceAt":
      exact(request, ["kind", "sourceId"], "floor read");
      args = [uint(request.sourceId, 64)];
      break;
    case "sourceSetHashAt":
      exact(request, ["kind", "count"], "floor read");
      args = [uint(request.count, 64)];
      break;
    case "sourceCount":
    case "sourceSetHead":
      exact(request, ["kind"], "floor read");
      args = [];
      break;
    default:
      throw new Error("Unsupported historical floor read");
  }
  return Object.freeze({ to: c.floor, data: floorInterface.encodeFunctionData(request.kind, args) as Hex, value: 0n });
}
