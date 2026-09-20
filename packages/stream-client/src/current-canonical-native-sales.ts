import {
  AbiCoder,
  Interface,
  ParamType,
  ZeroAddress,
  ZeroHash,
  getAddress,
  id,
  isHexString,
  keccak256,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";
import {
  primaryOfferBatchHashes,
  primaryOfferBuyerRevocationPayload,
} from "./current-primary-offer-signing.js";
import type {
  PrimaryOfferSellerAuthorization,
  PrimaryOfferBuyerMintTicketRevocation,
} from "./current-primary-offer-signing.js";
import {
  mintCounterAllowlistLeaf,
  normalizeMintCounterReadPolicy,
  verifyMintCounterAllowlistProof,
} from "./current-mint-counter-reads.js";
import type { MintCounterAllowlistProof } from "./current-mint-counter-reads.js";
import type { MintCounterDefinition } from "./current-mint-continuity.js";
import type { MintPolicyCounterConfig } from "./current-mint-policy-grace.js";

export const CANONICAL_NATIVE_SALES_SOURCE = "4fa32ae1c9206b05be848c7553c6492f516a7bfe";
export const CANONICAL_NATIVE_SALES_PRIMARY_SALE = id("PRIMARY_SALE") as Hex;
/** Allocation limits of this client; only tokenData's 8192 bound is a carrier rule. */
export const CANONICAL_NATIVE_SALES_MAX_BYTES = 262144;
export const CANONICAL_NATIVE_SALES_MAX_SIGNATURE_BYTES = 65536;
export const CANONICAL_NATIVE_SALES_MAX_PROOF_DEPTH = 64;
export type CanonicalNativeSalesFamily = "immediate" | "claim";
/** Exactly the original 24-field Sales-v1 struct; no offer-specific validation is reused. */
export type CanonicalNativeSalesAuthorization = PrimaryOfferSellerAuthorization;
export type CanonicalNativeSalesAllowlistProof = MintCounterAllowlistProof;

export interface CanonicalNativeSalesCoordinates {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly manager: Address;
  readonly ledger: Address;
  readonly recorder: Address;
}
export interface CanonicalNativeSalesSignerBinding {
  readonly authorizer: Address;
  readonly kind: bigint;
  readonly evidenceHash: Hex;
  readonly revision: bigint;
  readonly installingAuthority: Address;
}
export interface CanonicalNativeSalesSignature {
  readonly authorizer: Address;
  readonly kind: bigint;
  readonly signature: Hex;
}
export interface CanonicalNativeSalesConfiguration {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly saleKind: bigint;
  readonly authorityMode: bigint;
  readonly unitPrice: bigint;
  readonly startsAt: bigint;
  readonly endsAt: bigint;
  readonly manualClose: boolean;
  readonly saleSupplyLimit: bigint;
  readonly mintPolicyHash: Hex;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly primaryPolicyMode: bigint;
  readonly priceCounterId: Hex;
  readonly signer: CanonicalNativeSalesSignerBinding;
}
export interface CanonicalNativeClaimConfiguration {
  readonly sale: CanonicalNativeSalesConfiguration;
  readonly maxUnitPrice: bigint;
}
export interface CanonicalNativeSalesPurchase {
  readonly saleId: Hex;
  readonly payer: Address;
  readonly executor: Address;
  readonly initialRecipient: Address;
  readonly beneficiary: Address;
  readonly tokenData: Hex;
  readonly mintCommitment: Hex;
  readonly resolverData: Hex;
  readonly executionNonce: bigint;
}
export interface CanonicalNativeClaimPurchase {
  readonly mint: CanonicalNativeSalesPurchase;
  readonly chosenUnitPrice: bigint;
}
export interface CanonicalNativeSalesLifecycle {
  readonly saleCreatedAt: bigint;
  readonly saleAdapterRegistryRevision: bigint;
}
export interface CanonicalNativeSalesRecord {
  readonly config: CanonicalNativeSalesConfiguration;
  readonly configHash: Hex;
  readonly saleNonce: bigint;
  readonly soldQuantity: bigint;
  readonly closed: boolean;
  readonly lifecycle: CanonicalNativeSalesLifecycle;
  readonly artistId: Hex;
  readonly artistGeneration: bigint;
  readonly artistBindingHash: Hex;
}
export interface CanonicalNativeClaimRecord {
  readonly sale: CanonicalNativeSalesRecord;
  readonly maxUnitPrice: bigint;
}
export interface CanonicalNativeSalesReceipt {
  readonly saleId: Hex;
  readonly executionId: Hex;
  readonly authorizationId: Hex;
  readonly saleAuthorizationDigest: Hex;
  readonly operationRoot: Hex;
  readonly operationId: Hex;
  readonly tokenId: bigint;
  readonly settlementKey: Hex;
  readonly chargedAmount: bigint;
  readonly revealFee: bigint;
  readonly revealCredit: bigint;
}
export interface CanonicalNativeSalesPrimarySale {
  readonly settlementId: Hex;
  readonly revenueClass: Hex;
  readonly policyMode: bigint;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly saleNonce: bigint;
  readonly payer: Address;
  readonly poster: Address;
  readonly beneficiary: Address;
  readonly amount: bigint;
  readonly expectedPrimaryPolicyHash: Hex;
}
export interface CanonicalNativeSalesExecutionBinding {
  readonly executionId: Hex;
  readonly executionNonce: bigint;
  readonly authorityMode: bigint;
  readonly saleAuthorizationDigest: Hex;
}
export interface CanonicalNativeSalesRights {
  readonly profileId: Hex;
  readonly wallet: Address;
  readonly templateId: Hex;
  readonly assignmentHash: Hex;
  readonly entriesHash: Hex;
}
export interface CanonicalNativeSalesCandidate {
  readonly saleAdapter: Address;
  readonly executor: Address;
  readonly sale: CanonicalNativeSalesPrimarySale;
  readonly lifecycleBinding: CanonicalNativeSalesLifecycle;
  readonly executionBinding: CanonicalNativeSalesExecutionBinding;
  readonly orchestrationOrder: bigint;
  readonly mintManager: Address;
  readonly operationIdentityCommitment: Hex;
  readonly operationId: Hex;
  readonly currentPolicyHash: Hex;
  readonly boundPolicyHash: Hex;
  readonly rights: CanonicalNativeSalesRights;
  readonly saleExecutionHash: Hex;
}
export interface CanonicalNativeSalesSettlementResult {
  readonly candidateCommitment: Hex;
  readonly settlementKey: Hex;
  readonly profileId: Hex;
  readonly wallet: Address;
  readonly asset: Address;
  readonly amount: bigint;
  readonly executor: Address;
  readonly executionId: Hex;
  readonly escrowed: boolean;
  readonly operationIdentityCommitment: Hex;
  readonly currentPolicyHash: Hex;
  readonly boundPolicyHash: Hex;
}
export interface CanonicalNativeSalesRevealPolicy {
  readonly declared: boolean;
  readonly requestMode: bigint;
  readonly revealOwnerRole: Hex;
  readonly requestSLOBlocks: bigint;
  readonly revealFeePerTokenWei: bigint;
}
export interface CanonicalNativeSalesRevealQuote {
  readonly coordinator: Address;
  readonly coordinatorCodeHash: Hex;
  readonly policy: CanonicalNativeSalesRevealPolicy;
}
export interface CanonicalNativeSalesHistoricalBinding {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly saleKind: bigint;
  readonly authorityMode: bigint;
  readonly configHash: Hex;
  readonly authorizer: Address;
  readonly authorizerKind: bigint;
}
export interface CanonicalNativeSalesMintBatch {
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

export const CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE = "tuple(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
export const CANONICAL_NATIVE_SALES_SIGNATURE_TUPLE = "tuple(address authorizer,uint8 kind,bytes signature)";
export const CANONICAL_NATIVE_SALES_SIGNER_TUPLE = "tuple(address authorizer,uint8 kind,bytes32 evidenceHash,uint64 revision,address installingAuthority)";
export const CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE = `tuple(uint256 collectionId,bytes32 phaseId,uint8 saleKind,uint8 authorityMode,uint256 unitPrice,uint64 startsAt,uint64 endsAt,bool manualClose,uint64 saleSupplyLimit,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 priceCounterId,${CANONICAL_NATIVE_SALES_SIGNER_TUPLE} signer)`;
export const CANONICAL_NATIVE_CLAIM_CONFIGURATION_TUPLE = `tuple(${CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE} sale,uint256 maxUnitPrice)`;
export const CANONICAL_NATIVE_SALES_PURCHASE_TUPLE = "tuple(bytes32 saleId,address payer,address executor,address initialRecipient,address beneficiary,bytes tokenData,bytes32 mintCommitment,bytes resolverData,uint256 executionNonce)";
export const CANONICAL_NATIVE_CLAIM_PURCHASE_TUPLE = `tuple(${CANONICAL_NATIVE_SALES_PURCHASE_TUPLE} mint,uint256 chosenUnitPrice)`;
export const CANONICAL_NATIVE_SALES_LIFECYCLE_TUPLE = "tuple(uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision)";
export const CANONICAL_NATIVE_SALES_RECORD_TUPLE = `tuple(${CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE} config,bytes32 configHash,uint256 saleNonce,uint64 soldQuantity,bool closed,${CANONICAL_NATIVE_SALES_LIFECYCLE_TUPLE} lifecycle,bytes32 artistId,uint64 artistGeneration,bytes32 artistBindingHash)`;
export const CANONICAL_NATIVE_CLAIM_RECORD_TUPLE = `tuple(${CANONICAL_NATIVE_SALES_RECORD_TUPLE} sale,uint256 maxUnitPrice)`;
export const CANONICAL_NATIVE_SALES_RECEIPT_TUPLE = "tuple(bytes32 saleId,bytes32 executionId,bytes32 authorizationId,bytes32 saleAuthorizationDigest,bytes32 operationRoot,bytes32 operationId,uint256 tokenId,bytes32 settlementKey,uint256 chargedAmount,uint256 revealFee,uint256 revealCredit)";
export const CANONICAL_NATIVE_SALES_PRIMARY_SALE_TUPLE = "tuple(bytes32 settlementId,bytes32 revenueClass,uint8 policyMode,uint256 collectionId,uint256 tokenId,uint256 saleNonce,address payer,address poster,address beneficiary,uint256 amount,bytes32 expectedPrimaryPolicyHash)";
export const CANONICAL_NATIVE_SALES_EXECUTION_BINDING_TUPLE = "tuple(bytes32 executionId,uint256 executionNonce,uint8 authorityMode,bytes32 saleAuthorizationDigest)";
export const CANONICAL_NATIVE_SALES_RIGHTS_TUPLE = "tuple(bytes32 profileId,address wallet,bytes32 templateId,bytes32 assignmentHash,bytes32 entriesHash)";
export const CANONICAL_NATIVE_SALES_CANDIDATE_TUPLE = `tuple(address saleAdapter,address executor,${CANONICAL_NATIVE_SALES_PRIMARY_SALE_TUPLE} sale,${CANONICAL_NATIVE_SALES_LIFECYCLE_TUPLE} lifecycleBinding,${CANONICAL_NATIVE_SALES_EXECUTION_BINDING_TUPLE} executionBinding,uint8 orchestrationOrder,address mintManager,bytes32 operationIdentityCommitment,bytes32 operationId,bytes32 currentPolicyHash,bytes32 boundPolicyHash,${CANONICAL_NATIVE_SALES_RIGHTS_TUPLE} rights,bytes32 saleExecutionHash)`;
export const CANONICAL_NATIVE_SALES_SETTLEMENT_RESULT_TUPLE = "tuple(bytes32 candidateCommitment,bytes32 settlementKey,bytes32 profileId,address wallet,address asset,uint256 amount,address executor,bytes32 executionId,bool escrowed,bytes32 operationIdentityCommitment,bytes32 currentPolicyHash,bytes32 boundPolicyHash)";
export const CANONICAL_NATIVE_SALES_REVEAL_POLICY_TUPLE = "tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei)";
export const CANONICAL_NATIVE_SALES_REVEAL_QUOTE_TUPLE = `tuple(address coordinator,bytes32 coordinatorCodeHash,${CANONICAL_NATIVE_SALES_REVEAL_POLICY_TUPLE} policy)`;
export const CANONICAL_NATIVE_SALES_HISTORICAL_BINDING_TUPLE = "tuple(uint256 collectionId,bytes32 phaseId,uint8 saleKind,uint8 authorityMode,bytes32 configHash,address authorizer,uint8 authorizerKind)";
export const CANONICAL_NATIVE_SALES_MINT_BATCH_TUPLE = "tuple(uint256 collectionId,bytes32 phaseId,address payer,address authorizer,address[] initialRecipients,address[] beneficiaries,bytes[] tokenData,bytes32[] mintCommitments,bytes32 expectedPolicyHash,bytes32 authorizationId,bytes32 contextHash,bytes resolverData)";
/** Source-derived internal proof tuple; resolver bytes contain Proof[][], not one Proof. */
export const CANONICAL_NATIVE_SALES_ALLOWLIST_PROOF_TUPLE = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)";

const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;
const ZERO_ADDRESS = ZeroAddress as Address;

function exact(value: unknown, keys: readonly string[], label: string): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw Error(`${label} must be an object`);
  }
  const actual = Reflect.ownKeys(value);
  if (actual.length !== keys.length || actual.some(key => typeof key !== "string" || !keys.includes(key))) {
    throw Error(`${label} has missing or unknown fields`);
  }
}
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) {
    throw Error(`Expected uint${bits} bigint`);
  }
  return value;
}
function address(value: unknown, nonzero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (nonzero && result === ZERO_ADDRESS) throw Error("Expected nonzero address");
  return result;
}
function bytes(value: unknown, maximum = CANONICAL_NATIVE_SALES_MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > maximum) {
    throw Error("Invalid bytes or client byte limit exceeded");
  }
  return value.toLowerCase() as Hex;
}
function hash(value: unknown, nonzero = false): Hex {
  const result = bytes(value, 32);
  if (result.length !== 66 || (nonzero && result === ZERO)) throw Error("Expected bytes32");
  return result;
}
function dense(value: unknown, maximum: number): readonly unknown[] {
  if (!Array.isArray(value) || value.length > maximum || Reflect.ownKeys(value).length !== value.length + 1) {
    throw Error("Expected bounded dense array");
  }
  for (let i = 0; i < value.length; i++) {
    if (!Object.hasOwn(value, i)) throw Error("Expected dense array");
  }
  return value;
}
function tupleValue(param: ParamType, value: unknown, decoded = false): unknown {
  if (param.baseType === "tuple") {
    const fields = param.components!;
    if (!decoded) exact(value, fields.map(field => field.name), "Tuple");
    return Object.freeze(Object.fromEntries(fields.map((field, i) => [
      field.name,
      tupleValue(field, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[field.name], decoded),
    ])));
  }
  if (param.baseType === "array") {
    const values = decoded ? Array.from(value as readonly unknown[]) : dense(value, 1024);
    if (values.length > 1024) throw Error("Client array limit exceeded");
    return Object.freeze(values.map(item => tupleValue(param.arrayChildren!, item, decoded)));
  }
  if (param.type === "address") return address(value);
  if (param.type === "bytes32") return hash(value);
  if (param.type === "bytes") return bytes(value);
  if (param.type === "bool") {
    if (typeof value !== "boolean") throw Error("Expected bool");
    return value;
  }
  if (/^uint\d+$/.test(param.type)) return uint(value, Number(param.type.slice(4)));
  throw Error(`Unsupported codec type ${param.type}`);
}
function normalize<T>(shape: string, value: T): T {
  return tupleValue(ParamType.from(shape), value) as T;
}
function encode<T>(shape: string, value: T): Hex {
  return bytes(coder.encode([shape], [normalize(shape, value)]));
}
function decode<T>(shape: string, value: Hex): T {
  const raw = bytes(value);
  const result = tupleValue(ParamType.from(shape), coder.decode([shape], raw)[0], true) as T;
  if (encode(shape, result) !== raw) throw Error("Noncanonical ABI encoding");
  return result;
}
function digest(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}
function family(value: CanonicalNativeSalesFamily): CanonicalNativeSalesFamily {
  if (value !== "immediate" && value !== "claim") throw Error("Unknown canonical native sale family");
  return value;
}
function domain(value: CanonicalNativeSalesFamily, suffix: string): Hex {
  return id(`6529STREAM_NATIVE_${family(value) === "immediate" ? "IMMEDIATE" : "CLAIM"}_SALES_${suffix}_V1`) as Hex;
}

/** Structural codecs retain empty getter results; write admission is checked separately. */
export function normalizeCanonicalNativeSalesAuthorization(
  value: CanonicalNativeSalesAuthorization,
): CanonicalNativeSalesAuthorization {
  return normalize(CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE, value);
}
export function encodeCanonicalNativeSalesAuthorization(value: CanonicalNativeSalesAuthorization): Hex {
  return encode(CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE, value);
}
export function decodeCanonicalNativeSalesAuthorization(value: Hex): CanonicalNativeSalesAuthorization {
  return decode(CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE, value);
}

export function normalizeCanonicalNativeSalesSignature(
  value: CanonicalNativeSalesSignature,
): CanonicalNativeSalesSignature {
  return normalize(CANONICAL_NATIVE_SALES_SIGNATURE_TUPLE, value);
}
export function encodeCanonicalNativeSalesSignature(value: CanonicalNativeSalesSignature): Hex {
  return encode(CANONICAL_NATIVE_SALES_SIGNATURE_TUPLE, value);
}
export function decodeCanonicalNativeSalesSignature(value: Hex): CanonicalNativeSalesSignature {
  return decode(CANONICAL_NATIVE_SALES_SIGNATURE_TUPLE, value);
}

export function normalizeCanonicalNativeSalesSignerBinding(
  value: CanonicalNativeSalesSignerBinding,
): CanonicalNativeSalesSignerBinding {
  return normalize(CANONICAL_NATIVE_SALES_SIGNER_TUPLE, value);
}
export function encodeCanonicalNativeSalesSignerBinding(value: CanonicalNativeSalesSignerBinding): Hex {
  return encode(CANONICAL_NATIVE_SALES_SIGNER_TUPLE, value);
}
export function decodeCanonicalNativeSalesSignerBinding(value: Hex): CanonicalNativeSalesSignerBinding {
  return decode(CANONICAL_NATIVE_SALES_SIGNER_TUPLE, value);
}

export function normalizeCanonicalNativeSalesConfiguration(
  value: CanonicalNativeSalesConfiguration,
): CanonicalNativeSalesConfiguration {
  return normalize(CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE, value);
}
export function encodeCanonicalNativeSalesConfiguration(value: CanonicalNativeSalesConfiguration): Hex {
  return encode(CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE, value);
}
export function decodeCanonicalNativeSalesConfiguration(value: Hex): CanonicalNativeSalesConfiguration {
  return decode(CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE, value);
}

export function normalizeCanonicalNativeSalesClaimConfiguration(
  value: CanonicalNativeClaimConfiguration,
): CanonicalNativeClaimConfiguration {
  return normalize(CANONICAL_NATIVE_CLAIM_CONFIGURATION_TUPLE, value);
}
export function encodeCanonicalNativeSalesClaimConfiguration(value: CanonicalNativeClaimConfiguration): Hex {
  return encode(CANONICAL_NATIVE_CLAIM_CONFIGURATION_TUPLE, value);
}
export function decodeCanonicalNativeSalesClaimConfiguration(value: Hex): CanonicalNativeClaimConfiguration {
  return decode(CANONICAL_NATIVE_CLAIM_CONFIGURATION_TUPLE, value);
}

export function normalizeCanonicalNativeSalesPurchase(
  value: CanonicalNativeSalesPurchase,
): CanonicalNativeSalesPurchase {
  return normalize(CANONICAL_NATIVE_SALES_PURCHASE_TUPLE, value);
}
export function encodeCanonicalNativeSalesPurchase(value: CanonicalNativeSalesPurchase): Hex {
  return encode(CANONICAL_NATIVE_SALES_PURCHASE_TUPLE, value);
}
export function decodeCanonicalNativeSalesPurchase(value: Hex): CanonicalNativeSalesPurchase {
  return decode(CANONICAL_NATIVE_SALES_PURCHASE_TUPLE, value);
}

export function normalizeCanonicalNativeSalesClaimPurchase(
  value: CanonicalNativeClaimPurchase,
): CanonicalNativeClaimPurchase {
  return normalize(CANONICAL_NATIVE_CLAIM_PURCHASE_TUPLE, value);
}
export function encodeCanonicalNativeSalesClaimPurchase(value: CanonicalNativeClaimPurchase): Hex {
  return encode(CANONICAL_NATIVE_CLAIM_PURCHASE_TUPLE, value);
}
export function decodeCanonicalNativeSalesClaimPurchase(value: Hex): CanonicalNativeClaimPurchase {
  return decode(CANONICAL_NATIVE_CLAIM_PURCHASE_TUPLE, value);
}

export function normalizeCanonicalNativeSalesRecord(
  value: CanonicalNativeSalesRecord,
): CanonicalNativeSalesRecord {
  return normalize(CANONICAL_NATIVE_SALES_RECORD_TUPLE, value);
}
export function encodeCanonicalNativeSalesRecord(value: CanonicalNativeSalesRecord): Hex {
  return encode(CANONICAL_NATIVE_SALES_RECORD_TUPLE, value);
}
export function decodeCanonicalNativeSalesRecord(value: Hex): CanonicalNativeSalesRecord {
  return decode(CANONICAL_NATIVE_SALES_RECORD_TUPLE, value);
}

export function normalizeCanonicalNativeSalesClaimRecord(
  value: CanonicalNativeClaimRecord,
): CanonicalNativeClaimRecord {
  return normalize(CANONICAL_NATIVE_CLAIM_RECORD_TUPLE, value);
}
export function encodeCanonicalNativeSalesClaimRecord(value: CanonicalNativeClaimRecord): Hex {
  return encode(CANONICAL_NATIVE_CLAIM_RECORD_TUPLE, value);
}
export function decodeCanonicalNativeSalesClaimRecord(value: Hex): CanonicalNativeClaimRecord {
  return decode(CANONICAL_NATIVE_CLAIM_RECORD_TUPLE, value);
}

export function normalizeCanonicalNativeSalesReceipt(
  value: CanonicalNativeSalesReceipt,
): CanonicalNativeSalesReceipt {
  return normalize(CANONICAL_NATIVE_SALES_RECEIPT_TUPLE, value);
}
export function encodeCanonicalNativeSalesReceipt(value: CanonicalNativeSalesReceipt): Hex {
  return encode(CANONICAL_NATIVE_SALES_RECEIPT_TUPLE, value);
}
export function decodeCanonicalNativeSalesReceipt(value: Hex): CanonicalNativeSalesReceipt {
  return decode(CANONICAL_NATIVE_SALES_RECEIPT_TUPLE, value);
}

export function normalizeCanonicalNativeSalesCandidate(
  value: CanonicalNativeSalesCandidate,
): CanonicalNativeSalesCandidate {
  return normalize(CANONICAL_NATIVE_SALES_CANDIDATE_TUPLE, value);
}
export function encodeCanonicalNativeSalesCandidate(value: CanonicalNativeSalesCandidate): Hex {
  return encode(CANONICAL_NATIVE_SALES_CANDIDATE_TUPLE, value);
}
export function decodeCanonicalNativeSalesCandidate(value: Hex): CanonicalNativeSalesCandidate {
  return decode(CANONICAL_NATIVE_SALES_CANDIDATE_TUPLE, value);
}

export function normalizeCanonicalNativeSalesResult(
  value: CanonicalNativeSalesSettlementResult,
): CanonicalNativeSalesSettlementResult {
  return normalize(CANONICAL_NATIVE_SALES_SETTLEMENT_RESULT_TUPLE, value);
}
export function encodeCanonicalNativeSalesResult(value: CanonicalNativeSalesSettlementResult): Hex {
  return encode(CANONICAL_NATIVE_SALES_SETTLEMENT_RESULT_TUPLE, value);
}
export function decodeCanonicalNativeSalesResult(value: Hex): CanonicalNativeSalesSettlementResult {
  return decode(CANONICAL_NATIVE_SALES_SETTLEMENT_RESULT_TUPLE, value);
}

export function normalizeCanonicalNativeSalesRevealQuote(
  value: CanonicalNativeSalesRevealQuote,
): CanonicalNativeSalesRevealQuote {
  return normalize(CANONICAL_NATIVE_SALES_REVEAL_QUOTE_TUPLE, value);
}
export function encodeCanonicalNativeSalesRevealQuote(value: CanonicalNativeSalesRevealQuote): Hex {
  return encode(CANONICAL_NATIVE_SALES_REVEAL_QUOTE_TUPLE, value);
}
export function decodeCanonicalNativeSalesRevealQuote(value: Hex): CanonicalNativeSalesRevealQuote {
  return decode(CANONICAL_NATIVE_SALES_REVEAL_QUOTE_TUPLE, value);
}

export function normalizeCanonicalNativeSalesHistoricalBinding(
  value: CanonicalNativeSalesHistoricalBinding,
): CanonicalNativeSalesHistoricalBinding {
  return normalize(CANONICAL_NATIVE_SALES_HISTORICAL_BINDING_TUPLE, value);
}
export function encodeCanonicalNativeSalesHistoricalBinding(value: CanonicalNativeSalesHistoricalBinding): Hex {
  return encode(CANONICAL_NATIVE_SALES_HISTORICAL_BINDING_TUPLE, value);
}
export function decodeCanonicalNativeSalesHistoricalBinding(value: Hex): CanonicalNativeSalesHistoricalBinding {
  return decode(CANONICAL_NATIVE_SALES_HISTORICAL_BINDING_TUPLE, value);
}

export const CANONICAL_NATIVE_SALES_IMMEDIATE_CONFIGURATION_TUPLE = CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE;
export const CANONICAL_NATIVE_SALES_CLAIM_CONFIGURATION_TUPLE = CANONICAL_NATIVE_CLAIM_CONFIGURATION_TUPLE;
export const CANONICAL_NATIVE_SALES_CLAIM_PURCHASE_TUPLE = CANONICAL_NATIVE_CLAIM_PURCHASE_TUPLE;
export const CANONICAL_NATIVE_SALES_CLAIM_RECORD_TUPLE = CANONICAL_NATIVE_CLAIM_RECORD_TUPLE;
export const CANONICAL_NATIVE_SALES_RESULT_TUPLE = CANONICAL_NATIVE_SALES_SETTLEMENT_RESULT_TUPLE;

export function normalizeCanonicalNativeSalesCoordinates(
  value: CanonicalNativeSalesCoordinates,
): CanonicalNativeSalesCoordinates {
  exact(value, ["chainId", "adapter", "manager", "ledger", "recorder"], "Coordinates");
  const chainId = uint(value.chainId);
  if (chainId === 0n) throw Error("Expected nonzero chainId");
  return Object.freeze({
    chainId,
    adapter: address(value.adapter, true),
    manager: address(value.manager, true),
    ledger: address(value.ledger, true),
    recorder: address(value.recorder, true),
  });
}

/** Static original registration constraints only; live membership, phase and rights remain unverified. */
export function validateCanonicalNativeSalesConfiguration(
  selectedFamily: "immediate",
  value: CanonicalNativeSalesConfiguration,
): CanonicalNativeSalesConfiguration;
export function validateCanonicalNativeSalesConfiguration(
  selectedFamily: "claim",
  value: CanonicalNativeClaimConfiguration,
): CanonicalNativeClaimConfiguration;
export function validateCanonicalNativeSalesConfiguration(
  selectedFamily: CanonicalNativeSalesFamily,
  value: CanonicalNativeSalesConfiguration | CanonicalNativeClaimConfiguration,
): CanonicalNativeSalesConfiguration | CanonicalNativeClaimConfiguration;
export function validateCanonicalNativeSalesConfiguration(
  selectedFamily: CanonicalNativeSalesFamily,
  value: CanonicalNativeSalesConfiguration | CanonicalNativeClaimConfiguration,
): CanonicalNativeSalesConfiguration | CanonicalNativeClaimConfiguration {
  const f = family(selectedFamily);
  const normalized = f === "immediate"
    ? normalizeCanonicalNativeSalesConfiguration(value as CanonicalNativeSalesConfiguration)
    : normalizeCanonicalNativeSalesClaimConfiguration(value as CanonicalNativeClaimConfiguration);
  const config = f === "immediate"
    ? normalized as CanonicalNativeSalesConfiguration
    : (normalized as CanonicalNativeClaimConfiguration).sale;
  if (config.collectionId === 0n || config.phaseId === ZERO || config.mintPolicyHash === ZERO
      || config.primaryPolicyMode !== 0n
      || (config.manualClose ? config.endsAt !== 0n : config.endsAt <= config.startsAt)) {
    throw Error("Invalid original sale configuration");
  }
  if (f === "immediate") {
    if ((config.saleKind !== 0n && config.saleKind !== 1n) || config.unitPrice === 0n
        || config.expectedPrimaryPolicyHash === ZERO
        || (config.saleKind === 0n ? config.saleSupplyLimit === 0n : config.saleSupplyLimit !== 0n)) {
      throw Error("Invalid immediate configuration");
    }
  } else {
    const maximum = (normalized as CanonicalNativeClaimConfiguration).maxUnitPrice;
    if (config.saleSupplyLimit === 0n || (config.saleKind !== 12n && config.saleKind !== 13n)) {
      throw Error("Invalid claim configuration");
    }
    if (config.saleKind === 12n
        ? config.unitPrice !== 0n || maximum !== 0n || config.expectedPrimaryPolicyHash !== ZERO
        : maximum === 0n || maximum < config.unitPrice || config.expectedPrimaryPolicyHash === ZERO) {
      throw Error("Invalid claim price configuration");
    }
  }
  const signer = config.signer;
  if (config.authorityMode === 2n) {
    if (signer.authorizer !== ZERO_ADDRESS || signer.kind !== 0n || signer.evidenceHash !== ZERO
        || signer.revision !== 0n || signer.installingAuthority !== ZERO_ADDRESS) {
      throw Error("Public sale signer binding must be empty");
    }
  } else if (config.authorityMode !== 1n || signer.authorizer === ZERO_ADDRESS
      || (signer.kind !== 1n && signer.kind !== 2n) || signer.evidenceHash === ZERO
      || signer.revision === 0n || signer.installingAuthority === ZERO_ADDRESS) {
    throw Error("Invalid signed sale binding");
  }
  return normalized;
}

export function canonicalNativeSalesConfigurationHash(
  coordinates: CanonicalNativeSalesCoordinates,
  selectedFamily: CanonicalNativeSalesFamily,
  value: CanonicalNativeSalesConfiguration | CanonicalNativeClaimConfiguration,
): Hex {
  const c = normalizeCanonicalNativeSalesCoordinates(coordinates);
  const f = family(selectedFamily);
  const shape = f === "immediate" ? CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE : CANONICAL_NATIVE_CLAIM_CONFIGURATION_TUPLE;
  return digest(["bytes32", "uint256", "address", shape], [domain(f, "CONFIG"), c.chainId, c.adapter, normalize(shape, value)]);
}

export function canonicalNativeSalesSaleId(
  coordinates: CanonicalNativeSalesCoordinates,
  selectedFamily: CanonicalNativeSalesFamily,
  collectionId: bigint,
  phaseId: Hex,
  saleNonce: bigint,
): Hex {
  const c = normalizeCanonicalNativeSalesCoordinates(coordinates);
  return digest(
    ["bytes32", "uint256", "address", "uint256", "bytes32", "uint256"],
    [domain(selectedFamily, "ID"), c.chainId, c.adapter, uint(collectionId), hash(phaseId), uint(saleNonce)],
  );
}

export function canonicalNativeSalesRequestHash(
  coordinates: CanonicalNativeSalesCoordinates,
  selectedFamily: CanonicalNativeSalesFamily,
  configHash: Hex,
  purchase: CanonicalNativeSalesPurchase | CanonicalNativeClaimPurchase,
): Hex {
  const c = normalizeCanonicalNativeSalesCoordinates(coordinates);
  const f = family(selectedFamily);
  const shape = f === "immediate" ? CANONICAL_NATIVE_SALES_PURCHASE_TUPLE : CANONICAL_NATIVE_CLAIM_PURCHASE_TUPLE;
  return digest(["bytes32", "uint256", "address", "bytes32", shape], [
    domain(f, "REQUEST"), c.chainId, c.adapter, hash(configHash), normalize(shape, purchase),
  ]);
}

const authorizationFields = Object.freeze(ParamType.from(CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE)
  .components!.map(field => Object.freeze({ name: field.name, type: field.type })));

/** Exact typed digest, including payloads no longer eligible for purchase. */
export function canonicalNativeSalesAuthorizationPayload(
  coordinates: CanonicalNativeSalesCoordinates,
  authorization: CanonicalNativeSalesAuthorization,
): SigningPayload<CanonicalNativeSalesAuthorization> {
  const c = normalizeCanonicalNativeSalesCoordinates(coordinates);
  const a = normalizeCanonicalNativeSalesAuthorization(authorization);
  if (a.chainId !== c.chainId || a.saleAdapter !== c.adapter || a.mintManager !== c.manager) {
    throw Error("Authorization deployment binding mismatch");
  }
  return buildSigningPayload(c.chainId, c.adapter, "6529Stream Sales", "SaleAuthorization", authorizationFields, a);
}

export function canonicalNativeSalesAuthorizationId(
  coordinates: CanonicalNativeSalesCoordinates,
  authorization: CanonicalNativeSalesAuthorization,
): Hex {
  return digest(["bytes32", "bytes32"], [
    id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
    canonicalNativeSalesAuthorizationPayload(coordinates, authorization).digest,
  ]);
}

export function canonicalNativeSalesRevocationPayload(
  coordinates: CanonicalNativeSalesCoordinates,
  authorization: CanonicalNativeSalesAuthorization,
): SigningPayload<PrimaryOfferBuyerMintTicketRevocation> {
  const c = normalizeCanonicalNativeSalesCoordinates(coordinates);
  return primaryOfferBuyerRevocationPayload(
    c.chainId, c.adapter, c.manager, c.ledger,
    canonicalNativeSalesAuthorizationId(c, authorization),
  );
}

export function canonicalNativeSalesPublicAuthorizationId(
  coordinates: CanonicalNativeSalesCoordinates,
  selectedFamily: CanonicalNativeSalesFamily,
  configHash: Hex,
  requestHash: Hex,
): Hex {
  const c = normalizeCanonicalNativeSalesCoordinates(coordinates);
  const label = family(selectedFamily) === "immediate"
    ? "6529STREAM_NATIVE_PUBLIC_MINT_AUTHORIZATION_V1"
    : "6529STREAM_NATIVE_PUBLIC_CLAIM_MINT_AUTHORIZATION_V1";
  return digest(["bytes32", "uint256", "address", "address", "bytes32", "bytes32"], [
    id(label), c.chainId, c.adapter, c.manager, hash(configHash), hash(requestHash),
  ]);
}

export function canonicalNativeSalesExecutionHash(
  selectedFamily: CanonicalNativeSalesFamily,
  requestHash: Hex,
  authorizationDigest: Hex,
  authorizationId: Hex,
): Hex {
  return digest(["bytes32", "bytes32", "bytes32", "bytes32"], [
    domain(selectedFamily, "EXECUTION"), hash(requestHash), hash(authorizationDigest), hash(authorizationId),
  ]);
}

export function canonicalNativeSalesExecutionId(
  chainId: bigint,
  candidate: CanonicalNativeSalesCandidate,
): Hex {
  const c = normalizeCanonicalNativeSalesCandidate(candidate);
  return digest([
    "bytes32", "uint256", "address", "bytes32", "address", "address", "uint256", "uint8",
    "bytes32", "bytes32", "bytes32", "bytes32",
  ], [
    id("6529STREAM_NATIVE_SALE_EXECUTION_V1"), uint(chainId), c.saleAdapter, c.sale.settlementId,
    c.sale.payer, c.executor, c.executionBinding.executionNonce, c.executionBinding.authorityMode,
    c.executionBinding.saleAuthorizationDigest, c.currentPolicyHash, c.boundPolicyHash,
    c.operationIdentityCommitment,
  ]);
}

export function canonicalNativeSalesCandidateCommitment(
  chainId: bigint,
  recorder: Address,
  candidate: CanonicalNativeSalesCandidate,
): Hex {
  return digest(["bytes32", "uint256", "address", CANONICAL_NATIVE_SALES_CANDIDATE_TUPLE], [
    id("6529STREAM_NATIVE_SETTLEMENT_CANDIDATE_V1"), uint(chainId), address(recorder),
    normalizeCanonicalNativeSalesCandidate(candidate),
  ]);
}

export function canonicalNativeSalesSettlementKey(
  chainId: bigint,
  recorder: Address,
  adapter: Address,
  executionId: Hex,
): Hex {
  return digest(["bytes32", "uint256", "address", "address", "bytes32"], [
    id("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2"), uint(chainId), address(recorder), address(adapter), hash(executionId),
  ]);
}

export interface CanonicalNativeSalesAccountingContext extends Omit<CanonicalNativeSalesCandidate, "lifecycleBinding"> {
  readonly asset: Address;
  readonly lifecycleBinding: {
    readonly paymentAdapter: Address;
    readonly saleCreatedAt: bigint;
    readonly saleAdapterRegistryRevision: bigint;
    readonly paymentAdapterRegistryRevision: bigint;
  };
}
export const CANONICAL_NATIVE_SALES_ACCOUNTING_CONTEXT_TUPLE = `tuple(address saleAdapter,address executor,${CANONICAL_NATIVE_SALES_PRIMARY_SALE_TUPLE} sale,tuple(address paymentAdapter,uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision,uint64 paymentAdapterRegistryRevision) lifecycleBinding,${CANONICAL_NATIVE_SALES_EXECUTION_BINDING_TUPLE} executionBinding,address asset,uint8 orchestrationOrder,address mintManager,bytes32 operationIdentityCommitment,bytes32 operationId,bytes32 currentPolicyHash,bytes32 boundPolicyHash,${CANONICAL_NATIVE_SALES_RIGHTS_TUPLE} rights,bytes32 saleExecutionHash)`;

/** Original accounting projection deliberately leaves every ERC20 lifecycle word zero. */
export function canonicalNativeSalesAccountingContext(
  candidate: CanonicalNativeSalesCandidate,
): CanonicalNativeSalesAccountingContext {
  const c = normalizeCanonicalNativeSalesCandidate(candidate);
  return Object.freeze({
    ...c,
    asset: ZERO_ADDRESS,
    lifecycleBinding: Object.freeze({
      paymentAdapter: ZERO_ADDRESS,
      saleCreatedAt: 0n,
      saleAdapterRegistryRevision: 0n,
      paymentAdapterRegistryRevision: 0n,
    }),
  });
}

export function canonicalNativeSalesAccountingContextHash(candidate: CanonicalNativeSalesCandidate): Hex {
  return digest([CANONICAL_NATIVE_SALES_ACCOUNTING_CONTEXT_TUPLE], [canonicalNativeSalesAccountingContext(candidate)]);
}

export type CanonicalNativeSalesResult = CanonicalNativeSalesSettlementResult;
export interface CanonicalNativeSalesCounterObservation {
  readonly counterId: Hex;
  readonly config: MintPolicyCounterConfig;
  readonly definitionExists: boolean;
  readonly definition: MintCounterDefinition;
}
export interface CanonicalNativeSalesPriceOverride {
  readonly hasOverride: boolean;
  readonly overridePrice: bigint;
}
export interface CanonicalNativeSalesPrice {
  readonly amount: bigint;
  readonly minimum: bigint;
  readonly maximum: bigint;
}

export function normalizeCanonicalNativeSalesAllowlistProof(
  value: CanonicalNativeSalesAllowlistProof,
): CanonicalNativeSalesAllowlistProof {
  const p = normalize(CANONICAL_NATIVE_SALES_ALLOWLIST_PROOF_TUPLE, value);
  dense(p.proof, CANONICAL_NATIVE_SALES_MAX_PROOF_DEPTH);
  return p;
}

/** One singleton row per Merkle counter in original phase-counter order. */
export function encodeCanonicalNativeSalesAllowlistProofs(
  value: readonly (readonly CanonicalNativeSalesAllowlistProof[])[],
): Hex {
  const rows = dense(value, 16).map(row => {
    const proofs = dense(row, 1);
    if (proofs.length !== 1) throw Error("Each Merkle counter requires exactly one proof");
    return Object.freeze(proofs.map(proof => normalizeCanonicalNativeSalesAllowlistProof(proof as CanonicalNativeSalesAllowlistProof)));
  });
  return bytes(coder.encode([`${CANONICAL_NATIVE_SALES_ALLOWLIST_PROOF_TUPLE}[][]`], [rows]));
}

export function decodeCanonicalNativeSalesAllowlistProofs(
  value: Hex,
): readonly (readonly CanonicalNativeSalesAllowlistProof[])[] {
  const raw = bytes(value);
  const rows = tupleValue(
    ParamType.from(`${CANONICAL_NATIVE_SALES_ALLOWLIST_PROOF_TUPLE}[][]`),
    coder.decode([`${CANONICAL_NATIVE_SALES_ALLOWLIST_PROOF_TUPLE}[][]`], raw)[0],
    true,
  ) as readonly (readonly CanonicalNativeSalesAllowlistProof[])[];
  if (encodeCanonicalNativeSalesAllowlistProofs(rows) !== raw) throw Error("Noncanonical allowlist proof array");
  return rows;
}

/** Checks supplied complete policy observations, not their RPC provenance or remaining capacity. */
export function canonicalNativeSalesAllowlistPrice(
  coordinates: CanonicalNativeSalesCoordinates,
  configuration: CanonicalNativeSalesConfiguration,
  purchase: CanonicalNativeSalesPurchase,
  observations: readonly CanonicalNativeSalesCounterObservation[],
): CanonicalNativeSalesPriceOverride {
  const c = normalizeCanonicalNativeSalesCoordinates(coordinates);
  const config = normalizeCanonicalNativeSalesConfiguration(configuration);
  const p = normalizeCanonicalNativeSalesPurchase(purchase);
  const counters = dense(observations, 16).map(input => {
    const row = input as CanonicalNativeSalesCounterObservation;
    exact(row, ["counterId", "config", "definitionExists", "definition"], "Counter observation");
    const policy = normalizeMintCounterReadPolicy({ phaseExists: true, ...rowToPolicy(row) });
    return Object.freeze({ counterId: hash(row.counterId), ...policy });
  });
  const seen = new Set<string>();
  for (const row of counters) {
    if (row.counterId === ZERO || seen.has(row.counterId)) throw Error("Invalid complete counter inventory");
    seen.add(row.counterId);
  }
  if (config.priceCounterId === ZERO) {
    if (p.resolverData !== "0x" || counters.some(row => row.config.capMode === 3n)) {
      throw Error("Unselected price policy cannot contain Merkle counters or resolver bytes");
    }
    return Object.freeze({ hasOverride: false, overridePrice: 0n });
  }
  const merkle = counters.filter(row => row.config.capMode === 3n);
  if (!merkle.some(row => row.counterId === config.priceCounterId)) throw Error("Selected price counter is absent");
  const proofs = decodeCanonicalNativeSalesAllowlistProofs(p.resolverData);
  if (proofs.length !== merkle.length) throw Error("Merkle counter proof count mismatch");
  let hasOverride = false;
  let overridePrice = 0n;
  for (let i = 0; i < merkle.length; i++) {
    const row = merkle[i]!;
    const d = row.definition;
    const counter = row.config;
    const definitionHash = digest([
      "bytes32", "tuple(uint8 scope,uint8 keyMode,bytes32 capRoot,bytes32 metadataHash)",
    ], [id("6529STREAM_MINT_COUNTER_DEFINITION_V1"), d]);
    if (!counter.enabled || counter.staticCap === 0n || !row.definitionExists
        || (counter.keyMode !== 2n && counter.keyMode !== 3n)
        || d.keyMode !== counter.keyMode || d.capRoot === ZERO || d.scope === 0n
        || definitionHash !== counter.counterConfigHash) {
      throw Error("Invalid sale allowlist policy");
    }
    const proof = proofs[i]![0]!;
    const account = counter.keyMode === 2n ? p.payer : p.beneficiary;
    const leaf = mintCounterAllowlistLeaf(
      { chainId: c.chainId, manager: c.manager, ledger: c.ledger },
      config.collectionId, config.phaseId, row.counterId, account, proof,
    );
    if (proof.maxCount === 0n || proof.maxCount > counter.staticCap
        || !verifyMintCounterAllowlistProof(d.capRoot, leaf, proof.proof)) {
      throw Error("Invalid sale allowlist proof");
    }
    if (!proof.hasPriceOverride && proof.priceOverride !== 0n) throw Error("Invalid allowlist price declaration");
    if (row.counterId === config.priceCounterId) {
      hasOverride = proof.hasPriceOverride;
      overridePrice = proof.priceOverride;
    } else if (proof.hasPriceOverride) {
      throw Error("Only the selected price counter may override price");
    }
  }
  return Object.freeze({ hasOverride, overridePrice });
}

function rowToPolicy(row: CanonicalNativeSalesCounterObservation) {
  return { config: row.config, definitionExists: row.definitionExists, definition: row.definition };
}

/** Source price arithmetic; a claimed override must separately pass the same-leaf verifier. */
export function canonicalNativeSalesPrice(
  selectedFamily: CanonicalNativeSalesFamily,
  configuration: CanonicalNativeSalesConfiguration | CanonicalNativeClaimConfiguration,
  purchase: CanonicalNativeSalesPurchase | CanonicalNativeClaimPurchase,
  signedMinimum: bigint | null,
  override: CanonicalNativeSalesPriceOverride,
): CanonicalNativeSalesPrice {
  const f = family(selectedFamily);
  const normalized = validateCanonicalNativeSalesConfiguration(f, configuration);
  const config = f === "immediate"
    ? normalized as CanonicalNativeSalesConfiguration
    : (normalized as CanonicalNativeClaimConfiguration).sale;
  exact(override, ["hasOverride", "overridePrice"], "Price override");
  if (typeof override.hasOverride !== "boolean") throw Error("Expected boolean override flag");
  const proven = uint(override.overridePrice);
  if (!override.hasOverride && proven !== 0n) throw Error("Unused override price must be zero");
  if (signedMinimum !== null) uint(signedMinimum);
  if ((signedMinimum === null ? 2n : 1n) !== config.authorityMode) throw Error("Price authority mode mismatch");
  if (f === "immediate") {
    normalizeCanonicalNativeSalesPurchase(purchase as CanonicalNativeSalesPurchase);
    if (signedMinimum !== null && signedMinimum !== config.unitPrice) throw Error("Signed immediate price must match configuration");
    const amount = override.hasOverride ? proven : config.unitPrice;
    if (amount === 0n) throw Error("Immediate paid price must be positive");
    return Object.freeze({ amount, minimum: amount, maximum: amount });
  }
  const claim = normalizeCanonicalNativeSalesClaimPurchase(purchase as CanonicalNativeClaimPurchase);
  const maximum = (normalized as CanonicalNativeClaimConfiguration).maxUnitPrice;
  if (config.saleKind === 12n) {
    if (claim.chosenUnitPrice !== 0n || (signedMinimum !== null && signedMinimum !== 0n)
        || (override.hasOverride && proven !== 0n)) throw Error("Zero-price claim cannot charge a price");
    return Object.freeze({ amount: 0n, minimum: 0n, maximum: 0n });
  }
  let minimum = override.hasOverride ? proven : signedMinimum ?? config.unitPrice;
  if (minimum < config.unitPrice) minimum = config.unitPrice;
  if (claim.chosenUnitPrice < minimum || claim.chosenUnitPrice > maximum) throw Error("Chosen claim price is outside bounds");
  return Object.freeze({ amount: claim.chosenUnitPrice, minimum, maximum });
}

type CanonicalNativeSalesPurchaseRequest<P, F extends CanonicalNativeSalesFamily> =
  | {
    readonly family: F;
    readonly kind: "purchaseSigned";
    readonly purchase: P;
    readonly authorization: CanonicalNativeSalesAuthorization;
    readonly signature: CanonicalNativeSalesSignature;
    readonly value: bigint;
  }
  | {
    readonly family: F;
    readonly kind: "purchasePublic";
    readonly purchase: P;
    readonly value: bigint;
  };

export type CanonicalNativeSalesRequest =
  | CanonicalNativeSalesPurchaseRequest<CanonicalNativeSalesPurchase, "immediate">
  | CanonicalNativeSalesPurchaseRequest<CanonicalNativeClaimPurchase, "claim">
  | {
    readonly family: CanonicalNativeSalesFamily;
    readonly kind: "claimRefund";
    readonly saleId: Hex;
    readonly recipient: Address;
  }
  | {
    readonly family: CanonicalNativeSalesFamily;
    readonly kind: "voidMintImmediateSaleAuthorization";
    readonly authorization: CanonicalNativeSalesAuthorization;
    readonly authorizer: Address;
    readonly authorizerKind: bigint;
    readonly revocationSignature: Hex;
  };

export interface CanonicalNativeSalesCall {
  readonly coordinates: CanonicalNativeSalesCoordinates;
  readonly caller: Address;
  readonly request: CanonicalNativeSalesRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

function abiFor(selectedFamily: CanonicalNativeSalesFamily): readonly string[] {
  const f = family(selectedFamily);
  const purchase = f === "immediate" ? CANONICAL_NATIVE_SALES_PURCHASE_TUPLE : CANONICAL_NATIVE_CLAIM_PURCHASE_TUPLE;
  const config = f === "immediate" ? CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE : CANONICAL_NATIVE_CLAIM_CONFIGURATION_TUPLE;
  const record = f === "immediate" ? CANONICAL_NATIVE_SALES_RECORD_TUPLE : CANONICAL_NATIVE_CLAIM_RECORD_TUPLE;
  return Object.freeze([
    `function purchaseSigned(${purchase} purchase,${CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE} authorization,${CANONICAL_NATIVE_SALES_SIGNATURE_TUPLE} signature) payable returns(${CANONICAL_NATIVE_SALES_RECEIPT_TUPLE})`,
    `function purchasePublic(${purchase} purchase) payable returns(${CANONICAL_NATIVE_SALES_RECEIPT_TUPLE})`,
    "function claimRefund(bytes32 saleId,address recipient)",
    `function previewSignedPurchase(${purchase} purchase,${CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE} authorization,${CANONICAL_NATIVE_SALES_SIGNATURE_TUPLE} signature) view returns(${CANONICAL_NATIVE_SALES_CANDIDATE_TUPLE})`,
    `function previewPublicPurchase(${purchase} purchase) view returns(${CANONICAL_NATIVE_SALES_CANDIDATE_TUPLE} candidate,bytes32 managerAuthorizationId)`,
    "function saleIdFor(uint256 collectionId,bytes32 phaseId,uint256 saleNonce) view returns(bytes32)",
    `function saleConfigurationHash(${config} config) view returns(bytes32)`,
    `function saleRecord(bytes32 saleId) view returns(${record})`,
    "function nextSaleNonce() view returns(uint256)",
    "function nextExecutionNonce(bytes32 saleId,address payer) view returns(uint256)",
    `function collectionSigner(uint256 collectionId,address signer,uint8 kind) view returns(${CANONICAL_NATIVE_SALES_SIGNER_TUPLE} binding,bool enabled)`,
    `function authorizationDigest(${CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE} authorization) view returns(bytes32)`,
    "function saleConsentFacts(bytes32 saleId) view returns(uint256,bytes32)",
    `function nativeSaleLifecycleBinding(bytes32 saleId) view returns(${CANONICAL_NATIVE_SALES_LIFECYCLE_TUPLE})`,
    "function publicNativeSaleBinding(bytes32 saleId) view returns(uint256,bytes32,bytes32,uint8)",
    "function activePublicNativeCandidate(bytes32 executionId) view returns(bytes32)",
    "function immediateSaleAuthorizationBinding(bytes32 saleId) view returns(uint256,bytes32,uint8,uint8,bytes32,address,uint8)",
    `function executionReceipt(bytes32 executionId) view returns(${CANONICAL_NATIVE_SALES_RECEIPT_TUPLE})`,
    "function executionStatus(bytes32 executionId) view returns(uint8)",
    `function saleRevealQuote(bytes32 saleId) view returns(${CANONICAL_NATIVE_SALES_REVEAL_QUOTE_TUPLE})`,
    "function refundableBalance(bytes32 saleId,address payer) view returns(uint256)",
    "function refundLiability() view returns(uint256)",
    "function refundAccountCount() view returns(uint256)",
    "function refundAccountAt(uint256 index) view returns(bytes32 saleId,address payer)",
    "function eip712Domain() view returns(bytes1,string,string,uint256,address,bytes32,uint256[])",
  ]);
}

export const CURRENT_CANONICAL_NATIVE_IMMEDIATE_SALES_ABI = abiFor("immediate");
export const CURRENT_CANONICAL_NATIVE_CLAIM_SALES_ABI = abiFor("claim");
export const CURRENT_CANONICAL_NATIVE_SALES_REVOCATION_ABI = Object.freeze([
  `function voidMintImmediateSaleAuthorization(${CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE} authorization,address authorizer,uint8 kind,bytes revocationSignature) returns(bytes32 authorizationId)`,
]);
const immediateAbi = new Interface(CURRENT_CANONICAL_NATIVE_IMMEDIATE_SALES_ABI);
const claimAbi = new Interface(CURRENT_CANONICAL_NATIVE_CLAIM_SALES_ABI);
const revocationAbi = new Interface(CURRENT_CANONICAL_NATIVE_SALES_REVOCATION_ABI);

export function canonicalNativeSalesInterface(selectedFamily: CanonicalNativeSalesFamily): Interface {
  return family(selectedFamily) === "immediate" ? immediateAbi : claimAbi;
}

function requireKind(selectedFamily: CanonicalNativeSalesFamily, saleKind: bigint): void {
  if (family(selectedFamily) === "immediate"
      ? saleKind !== 0n && saleKind !== 1n
      : saleKind !== 12n && saleKind !== 13n) throw Error("Sale kind is outside this family");
}

function requirePurchase(
  c: CanonicalNativeSalesCoordinates,
  caller: Address,
  p: CanonicalNativeSalesPurchase,
): void {
  if (p.saleId === ZERO || p.payer === ZERO_ADDRESS || p.payer !== p.executor
      || p.payer !== caller || p.payer === c.adapter || p.initialRecipient === ZERO_ADDRESS
      || p.initialRecipient === c.adapter || p.beneficiary === ZERO_ADDRESS
      || p.mintCommitment === ZERO || p.executionNonce === 0n) throw Error("Invalid purchase actor or mint binding");
  bytes(p.tokenData, 8192);
}

function requirePurchaseAuthorization(
  c: CanonicalNativeSalesCoordinates,
  f: CanonicalNativeSalesFamily,
  p: CanonicalNativeSalesPurchase,
  a: CanonicalNativeSalesAuthorization,
): void {
  canonicalNativeSalesAuthorizationPayload(c, a);
  requireKind(f, a.saleKind);
  const batch = primaryOfferBatchHashes(p.initialRecipient, p.beneficiary, p.tokenData, p.mintCommitment);
  if (a.collectionId === 0n || a.phaseId === ZERO || a.saleId !== p.saleId
      || a.revenueClass !== CANONICAL_NATIVE_SALES_PRIMARY_SALE || a.primaryPolicyMode !== 0n
      || a.payer !== p.payer || a.executor !== p.executor || a.asset !== ZERO_ADDRESS
      || a.quantity !== 1n || a.contentSelectionHash !== ZERO || a.policyHash === ZERO
      || a.nonce === ZERO || a.finalizeBy !== 0n
      || a.initialRecipientsHash !== batch.initialRecipientsHash
      || a.beneficiariesHash !== batch.beneficiariesHash
      || a.tokenDataArrayHash !== batch.tokenDataArrayHash
      || a.mintCommitmentsHash !== batch.mintCommitmentsHash
      || (a.saleKind === 12n
        ? a.unitPrice !== 0n || a.expectedPrimaryPolicyHash !== ZERO
        : a.expectedPrimaryPolicyHash === ZERO)
      || (f === "immediate" && a.unitPrice === 0n)) {
    throw Error("Authorization differs from canonical purchase terms");
  }
}

export function normalizeCanonicalNativeSalesRequest(
  value: CanonicalNativeSalesRequest,
): CanonicalNativeSalesRequest {
  family(value.family);
  switch (value.kind) {
    case "purchaseSigned":
    case "purchasePublic": {
      exact(value, value.kind === "purchaseSigned"
        ? ["family", "kind", "purchase", "authorization", "signature", "value"]
        : ["family", "kind", "purchase", "value"], "Purchase request");
      const purchase = value.family === "immediate"
        ? normalizeCanonicalNativeSalesPurchase(value.purchase)
        : normalizeCanonicalNativeSalesClaimPurchase(value.purchase);
      if (value.kind === "purchasePublic") {
        return Object.freeze({ family: value.family, kind: value.kind, purchase, value: uint(value.value) }) as CanonicalNativeSalesRequest;
      }
      const signature = normalizeCanonicalNativeSalesSignature(value.signature);
      if (signature.authorizer === ZERO_ADDRESS || (signature.kind !== 1n && signature.kind !== 2n)) {
        throw Error("Signature requires explicit original authorizer kind");
      }
      bytes(signature.signature, CANONICAL_NATIVE_SALES_MAX_SIGNATURE_BYTES);
      return Object.freeze({
        family: value.family,
        kind: value.kind,
        purchase,
        authorization: normalizeCanonicalNativeSalesAuthorization(value.authorization),
        signature,
        value: uint(value.value),
      }) as CanonicalNativeSalesRequest;
    }
    case "claimRefund":
      exact(value, ["family", "kind", "saleId", "recipient"], "Refund request");
      return Object.freeze({ ...value, saleId: hash(value.saleId), recipient: address(value.recipient, true) });
    case "voidMintImmediateSaleAuthorization":
      exact(value, ["family", "kind", "authorization", "authorizer", "authorizerKind", "revocationSignature"], "Revocation request");
      if (value.authorizerKind !== 1n && value.authorizerKind !== 2n) throw Error("Unsupported revocation kind");
      return Object.freeze({
        ...value,
        authorization: normalizeCanonicalNativeSalesAuthorization(value.authorization),
        authorizer: address(value.authorizer, true),
        revocationSignature: bytes(value.revocationSignature, CANONICAL_NATIVE_SALES_MAX_SIGNATURE_BYTES),
      });
    default:
      throw Error("Unsupported canonical native sales operation");
  }
}

export function prepareCanonicalNativeSalesCall(
  coordinates: CanonicalNativeSalesCoordinates,
  caller: Address,
  input: CanonicalNativeSalesRequest,
): CanonicalNativeSalesCall {
  const c = normalizeCanonicalNativeSalesCoordinates(coordinates);
  const actor = address(caller, true);
  const request = normalizeCanonicalNativeSalesRequest(input);
  let to = c.adapter;
  let value = 0n;
  let data: Hex;
  const abi = canonicalNativeSalesInterface(request.family);
  if (request.kind === "purchasePublic" || request.kind === "purchaseSigned") {
    const p = request.family === "immediate" ? request.purchase : request.purchase.mint;
    requirePurchase(c, actor, p);
    value = request.value;
    if (request.kind === "purchaseSigned") {
      requirePurchaseAuthorization(c, request.family, p, request.authorization);
      data = bytes(abi.encodeFunctionData(request.kind, [request.purchase, request.authorization, request.signature]));
    } else {
      data = bytes(abi.encodeFunctionData(request.kind, [request.purchase]));
    }
  } else if (request.kind === "claimRefund") {
    if (request.recipient === c.adapter) throw Error("Refund recipient cannot be carrier");
    data = bytes(abi.encodeFunctionData(request.kind, [request.saleId, request.recipient]));
  } else {
    const a = request.authorization;
    canonicalNativeSalesAuthorizationPayload(c, a);
    requireKind(request.family, a.saleKind);
    if (a.collectionId === 0n || a.phaseId === ZERO || a.saleId === ZERO
        || a.revenueClass !== CANONICAL_NATIVE_SALES_PRIMARY_SALE) throw Error("Invalid historical revocation binding");
    to = c.manager;
    data = bytes(revocationAbi.encodeFunctionData(request.kind, [a, request.authorizer, request.authorizerKind, request.revocationSignature]));
  }
  return Object.freeze({
    coordinates: c,
    caller: actor,
    request,
    call: Object.freeze({ to, value, data }),
    factsVerified: false,
  });
}

export function normalizeCanonicalNativeSalesCall(value: CanonicalNativeSalesCall): CanonicalNativeSalesCall {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared call");
  exact(value.call, ["to", "value", "data"], "Call");
  const result = prepareCanonicalNativeSalesCall(value.coordinates, value.caller, value.request);
  if (value.factsVerified !== false || address(value.call.to) !== result.call.to
      || uint(value.call.value) !== result.call.value || bytes(value.call.data) !== result.call.data) {
    throw Error("Prepared call differs from original inputs");
  }
  return result;
}

/** Historical membership only. No current sale, signer, expiry, price, or Artist admission is implied. */
export function validateCanonicalNativeSalesHistoricalBinding(
  prepared: CanonicalNativeSalesCall,
  binding: CanonicalNativeSalesHistoricalBinding,
): CanonicalNativeSalesHistoricalBinding {
  const plan = normalizeCanonicalNativeSalesCall(prepared);
  if (plan.request.kind !== "voidMintImmediateSaleAuthorization") throw Error("Expected historical revocation");
  const b = normalizeCanonicalNativeSalesHistoricalBinding(binding);
  const r = plan.request;
  if (b.collectionId !== r.authorization.collectionId || b.phaseId !== r.authorization.phaseId
      || b.saleKind !== r.authorization.saleKind || b.authorityMode !== 1n || b.configHash === ZERO
      || b.authorizer !== r.authorizer || b.authorizerKind !== r.authorizerKind) {
    throw Error("Historical signed binding mismatch");
  }
  return b;
}

export function canonicalNativeSalesMintBatch(
  prepared: CanonicalNativeSalesCall,
  record: CanonicalNativeSalesRecord | CanonicalNativeClaimRecord,
): CanonicalNativeSalesMintBatch {
  const plan = normalizeCanonicalNativeSalesCall(prepared);
  const request = plan.request;
  if (request.kind !== "purchasePublic" && request.kind !== "purchaseSigned") throw Error("Expected purchase");
  const wrapped = request.family === "immediate"
    ? normalizeCanonicalNativeSalesRecord(record as CanonicalNativeSalesRecord)
    : normalizeCanonicalNativeSalesClaimRecord(record as CanonicalNativeClaimRecord);
  const r = request.family === "immediate" ? wrapped as CanonicalNativeSalesRecord : (wrapped as CanonicalNativeClaimRecord).sale;
  const configuration = request.family === "immediate"
    ? r.config : { sale: r.config, maxUnitPrice: (wrapped as CanonicalNativeClaimRecord).maxUnitPrice };
  validateCanonicalNativeSalesConfiguration(request.family, configuration);
  const p = request.family === "immediate" ? request.purchase : request.purchase.mint;
  if (r.saleNonce === 0n
      || r.configHash !== canonicalNativeSalesConfigurationHash(plan.coordinates, request.family, configuration)
      || p.saleId !== canonicalNativeSalesSaleId(plan.coordinates, request.family, r.config.collectionId, r.config.phaseId, r.saleNonce)
      || r.config.authorityMode !== (request.kind === "purchaseSigned" ? 1n : 2n)) {
    throw Error("Retained sale identity mismatch");
  }
  const contextHash = canonicalNativeSalesRequestHash(plan.coordinates, request.family, r.configHash, request.purchase);
  let authorizationId: Hex;
  if (request.kind === "purchaseSigned") {
    const a = request.authorization;
    const config = r.config;
    if (a.collectionId !== config.collectionId || a.phaseId !== config.phaseId || a.saleKind !== config.saleKind
        || a.expectedPrimaryPolicyHash !== config.expectedPrimaryPolicyHash || a.policyHash !== config.mintPolicyHash
        || (request.family === "immediate" && a.unitPrice !== config.unitPrice)
        || request.signature.authorizer !== config.signer.authorizer || request.signature.kind !== config.signer.kind) {
      throw Error("Authorization differs from retained configuration");
    }
    authorizationId = canonicalNativeSalesAuthorizationId(plan.coordinates, a);
  } else {
    authorizationId = canonicalNativeSalesPublicAuthorizationId(plan.coordinates, request.family, r.configHash, contextHash);
  }
  return Object.freeze({
    collectionId: r.config.collectionId,
    phaseId: r.config.phaseId,
    payer: p.payer,
    authorizer: ZERO_ADDRESS,
    initialRecipients: Object.freeze([p.initialRecipient]),
    beneficiaries: Object.freeze([p.beneficiary]),
    tokenData: Object.freeze([p.tokenData]),
    mintCommitments: Object.freeze([p.mintCommitment]),
    expectedPolicyHash: r.config.mintPolicyHash,
    authorizationId,
    contextHash,
    resolverData: p.resolverData,
  });
}

export interface CanonicalNativeSalesSigningTerms {
  readonly nonce: Hex;
  readonly deadline: bigint;
  /** Original signed minimum for Claim13; Immediate requires its configured price. */
  readonly unitPrice: bigint;
}

export function canonicalNativeSalesExpectedAuthorization(
  coordinates: CanonicalNativeSalesCoordinates,
  selectedFamily: CanonicalNativeSalesFamily,
  configuration: CanonicalNativeSalesConfiguration | CanonicalNativeClaimConfiguration,
  purchase: CanonicalNativeSalesPurchase | CanonicalNativeClaimPurchase,
  terms: CanonicalNativeSalesSigningTerms,
): CanonicalNativeSalesAuthorization {
  const c = normalizeCanonicalNativeSalesCoordinates(coordinates);
  const f = family(selectedFamily);
  const cfg = validateCanonicalNativeSalesConfiguration(f, configuration);
  const config = f === "immediate" ? cfg as CanonicalNativeSalesConfiguration : (cfg as CanonicalNativeClaimConfiguration).sale;
  const p = f === "immediate"
    ? normalizeCanonicalNativeSalesPurchase(purchase as CanonicalNativeSalesPurchase)
    : normalizeCanonicalNativeSalesClaimPurchase(purchase as CanonicalNativeClaimPurchase).mint;
  exact(terms, ["nonce", "deadline", "unitPrice"], "Signing terms");
  if (config.authorityMode !== 1n) throw Error("Public mode has no seller authorization");
  requirePurchase(c, p.payer, p);
  if (f === "immediate" && uint(terms.unitPrice) !== config.unitPrice) throw Error("Immediate signed price mismatch");
  const result: CanonicalNativeSalesAuthorization = Object.freeze({
    chainId: c.chainId,
    saleAdapter: c.adapter,
    mintManager: c.manager,
    collectionId: config.collectionId,
    phaseId: config.phaseId,
    saleId: p.saleId,
    saleKind: config.saleKind,
    revenueClass: CANONICAL_NATIVE_SALES_PRIMARY_SALE,
    expectedPrimaryPolicyHash: config.expectedPrimaryPolicyHash,
    primaryPolicyMode: 0n,
    ...primaryOfferBatchHashes(p.initialRecipient, p.beneficiary, p.tokenData, p.mintCommitment),
    payer: p.payer,
    executor: p.executor,
    asset: ZERO_ADDRESS,
    unitPrice: uint(terms.unitPrice),
    quantity: 1n,
    contentSelectionHash: ZERO,
    policyHash: config.mintPolicyHash,
    nonce: hash(terms.nonce, true),
    deadline: uint(terms.deadline, 64),
    finalizeBy: 0n,
  });
  requirePurchaseAuthorization(c, f, p, result);
  return result;
}

/** Deadline equality is admitted. Sale clock tolls do not extend this timestamp. */
export function validateCanonicalNativeSalesAuthorizationDeadline(
  authorization: CanonicalNativeSalesAuthorization,
  timestamp: bigint,
): void {
  const a = normalizeCanonicalNativeSalesAuthorization(authorization);
  if (a.nonce === ZERO || a.deadline < uint(timestamp)) throw Error("Expired authorization or zero nonce");
}

/** Pure native-value arithmetic; a quote remains a supplied observation. */
export function canonicalNativeSalesRevealFunding(
  chargedAmount: bigint,
  suppliedValue: bigint,
  quote: CanonicalNativeSalesRevealQuote,
): Readonly<{ chargedAmount: bigint; revealFee: bigint; revealCredit: bigint }> {
  const amount = uint(chargedAmount);
  const value = uint(suppliedValue);
  const q = normalizeCanonicalNativeSalesRevealQuote(quote);
  if (!q.policy.declared) {
    if (value !== amount) throw Error("Undeclared reveal policy requires exact sale value");
    return Object.freeze({ chargedAmount: amount, revealFee: 0n, revealCredit: 0n });
  }
  const total = uint(amount + q.policy.revealFeePerTokenWei);
  if (value < total) throw Error("Native value is below price plus reveal fee");
  return Object.freeze({ chargedAmount: amount, revealFee: q.policy.revealFeePerTokenWei, revealCredit: value - total });
}

export type CanonicalNativeSalesReadRequest =
  | { readonly kind: "nextSaleNonce" | "refundLiability" | "refundAccountCount" | "eip712Domain" }
  | {
    readonly kind: "saleRecord" | "saleConsentFacts" | "nativeSaleLifecycleBinding"
      | "publicNativeSaleBinding" | "immediateSaleAuthorizationBinding" | "saleRevealQuote";
    readonly saleId: Hex;
  }
  | {
    readonly kind: "executionReceipt" | "executionStatus" | "activePublicNativeCandidate";
    readonly executionId: Hex;
  }
  | { readonly kind: "nextExecutionNonce" | "refundableBalance"; readonly saleId: Hex; readonly payer: Address }
  | { readonly kind: "refundAccountAt"; readonly index: bigint }
  | { readonly kind: "saleIdFor"; readonly collectionId: bigint; readonly phaseId: Hex; readonly saleNonce: bigint }
  | { readonly kind: "collectionSigner"; readonly collectionId: bigint; readonly signer: Address; readonly signerKind: bigint }
  | {
    readonly kind: "saleConfigurationHash";
    readonly configuration: CanonicalNativeSalesConfiguration | CanonicalNativeClaimConfiguration;
  }
  | { readonly kind: "authorizationDigest"; readonly authorization: CanonicalNativeSalesAuthorization };

/** Reads preserve zero keys and zero-return histories; they do not establish purchase readiness. */
export function prepareCanonicalNativeSalesRead(
  adapter: Address,
  selectedFamily: CanonicalNativeSalesFamily,
  input: CanonicalNativeSalesReadRequest,
): UnsignedCall {
  const abi = canonicalNativeSalesInterface(selectedFamily);
  let args: readonly unknown[];
  switch (input.kind) {
    case "nextSaleNonce":
    case "refundLiability":
    case "refundAccountCount":
    case "eip712Domain":
      exact(input, ["kind"], "Read");
      args = [];
      break;
    case "saleRecord":
    case "saleConsentFacts":
    case "nativeSaleLifecycleBinding":
    case "publicNativeSaleBinding":
    case "immediateSaleAuthorizationBinding":
    case "saleRevealQuote":
      exact(input, ["kind", "saleId"], "Read");
      args = [hash(input.saleId)];
      break;
    case "executionReceipt":
    case "executionStatus":
    case "activePublicNativeCandidate":
      exact(input, ["kind", "executionId"], "Read");
      args = [hash(input.executionId)];
      break;
    case "nextExecutionNonce":
    case "refundableBalance":
      exact(input, ["kind", "saleId", "payer"], "Read");
      args = [hash(input.saleId), address(input.payer)];
      break;
    case "refundAccountAt":
      exact(input, ["kind", "index"], "Read");
      args = [uint(input.index)];
      break;
    case "saleIdFor":
      exact(input, ["kind", "collectionId", "phaseId", "saleNonce"], "Read");
      args = [uint(input.collectionId), hash(input.phaseId), uint(input.saleNonce)];
      break;
    case "collectionSigner":
      exact(input, ["kind", "collectionId", "signer", "signerKind"], "Read");
      args = [uint(input.collectionId), address(input.signer), uint(input.signerKind, 8)];
      break;
    case "authorizationDigest":
      exact(input, ["kind", "authorization"], "Read");
      args = [normalizeCanonicalNativeSalesAuthorization(input.authorization)];
      break;
    case "saleConfigurationHash":
      exact(input, ["kind", "configuration"], "Read");
      args = [selectedFamily === "immediate"
        ? normalizeCanonicalNativeSalesConfiguration(input.configuration as CanonicalNativeSalesConfiguration)
        : normalizeCanonicalNativeSalesClaimConfiguration(input.configuration as CanonicalNativeClaimConfiguration)];
      break;
    default:
      throw Error("Unsupported canonical native read");
  }
  return Object.freeze({ to: address(adapter, true), value: 0n, data: bytes(abi.encodeFunctionData(input.kind, args)) });
}

export function prepareCanonicalNativeSalesPreview(prepared: CanonicalNativeSalesCall): UnsignedCall {
  const p = normalizeCanonicalNativeSalesCall(prepared);
  const r = p.request;
  if (r.kind !== "purchaseSigned" && r.kind !== "purchasePublic") throw Error("Only purchases have previews");
  const abi = canonicalNativeSalesInterface(r.family);
  return Object.freeze({
    to: p.coordinates.adapter,
    value: 0n,
    data: bytes(abi.encodeFunctionData(r.kind === "purchaseSigned" ? "previewSignedPurchase" : "previewPublicPurchase",
      r.kind === "purchaseSigned" ? [r.purchase, r.authorization, r.signature] : [r.purchase])),
  });
}
