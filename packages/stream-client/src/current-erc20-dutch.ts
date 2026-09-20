import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { buildSigningPayload } from "./signing-payload.js";
import * as sales from "./current-canonical-native-sales.js";
import * as native from "./current-canonical-native-dutch.js";
import { primaryOfferBatchHashes } from "./current-primary-offer-signing.js";
import type { ERC20SaleLifecycleBinding, ERC20SettlementCandidate } from "./current-erc20-primary-offer.js";
import type { PaymentIntent } from "./signing.js";

export const ERC20_DUTCH_SOURCE = "6536c25895ae12eb9d702da9361f067152060d9b";
export const ERC20_DUTCH_PROFILE = id("6529STREAM_ERC20_STANDARD_DUTCH_V1") as Hex;
export const ERC20_DUTCH_MAX_BYTES = 262144;
export const ERC20_DUTCH_MAX_SIGNATURE_BYTES = 65536;
export interface ERC20DutchCoordinates extends sales.CanonicalNativeSalesCoordinates {
  readonly paymentAdapter: Address;
}
export interface ERC20DutchConfiguration {
  readonly sale: sales.CanonicalNativeSalesConfiguration;
  readonly asset: Address;
  readonly paymentAdapter: Address;
  readonly schedule: native.CanonicalNativeDutchSchedule;
  readonly declaredFree: boolean;
}
export interface ERC20DutchExecution {
  readonly purchase: sales.CanonicalNativeSalesPurchase;
  readonly authorization: sales.CanonicalNativeSalesAuthorization;
  readonly signature: sales.CanonicalNativeSalesSignature;
}
export interface ERC20DutchRecord {
  readonly config: ERC20DutchConfiguration;
  readonly configHash: Hex;
  readonly priceScheduleHash: Hex;
  readonly saleNonce: bigint;
  readonly soldQuantity: bigint;
  readonly closed: boolean;
  readonly lifecycle: ERC20SaleLifecycleBinding;
  readonly artistId: Hex;
  readonly artistGeneration: bigint;
  readonly artistBindingHash: Hex;
}
/** Structural candidate includes PUBLIC and declared-free outcomes, with independent parties. */
export type ERC20DutchCandidate = ERC20SettlementCandidate;
export type ERC20DutchReceipt = sales.CanonicalNativeSalesReceipt;
export type ERC20DutchSettlementResult = sales.CanonicalNativeSalesSettlementResult;
export interface ERC20DutchResult {
  readonly revenueOutcome: bigint;
  readonly executionId: Hex;
  readonly settlement: ERC20DutchSettlementResult;
}
export interface ERC20DutchPaymentRequest {
  readonly saleAdapter: Address;
  readonly saleAdapterCodeHash: Hex;
  readonly saleId: Hex;
  readonly saleConfigHash: Hex;
  readonly maxAmount: bigint;
  readonly executionData: Hex;
}
export interface ERC20DutchEIP2612Maximum {
  readonly permittedAmount: bigint;
  readonly authorization: {
    readonly deadline: bigint;
    readonly v: bigint;
    readonly r: Hex;
    readonly s: Hex;
  };
}
export interface ERC20DutchPermit2Maximum {
  readonly permittedAmount: bigint;
  readonly authorization: {
    readonly nonce: bigint;
    readonly deadline: bigint;
    readonly signature: Hex;
  };
}
export type ERC20DutchRequest =
  | {
    readonly kind: "settleERC20DutchSaleByPayer";
    readonly request: ERC20DutchPaymentRequest;
    readonly value: bigint;
  }
  | {
    readonly kind: "settleERC20DutchSaleWithIntent";
    readonly request: ERC20DutchPaymentRequest;
    readonly intent: PaymentIntent;
    readonly signature: Hex;
    readonly value: bigint;
  }
  | {
    readonly kind: "settleERC20DutchSaleWithEIP2612Permit";
    readonly request: ERC20DutchPaymentRequest;
    readonly permit: ERC20DutchEIP2612Maximum;
    readonly value: bigint;
  }
  | {
    readonly kind: "settleERC20DutchSaleWithPermit2";
    readonly request: ERC20DutchPaymentRequest;
    readonly permit: ERC20DutchPermit2Maximum;
    readonly value: bigint;
  }
  | Extract<native.CanonicalNativeDutchRequest, { readonly kind: "claimRefund" | "voidMintImmediateSaleAuthorization" }>;
export interface ERC20DutchCall {
  readonly coordinates: ERC20DutchCoordinates;
  readonly caller: Address;
  readonly request: ERC20DutchRequest;
  readonly execution: ERC20DutchExecution | null;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export const ERC20_DUTCH_LIFECYCLE_TUPLE = "tuple(address paymentAdapter,uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision,uint64 paymentAdapterRegistryRevision)";
export const ERC20_DUTCH_CONFIGURATION_TUPLE = `tuple(${sales.CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE} sale,address asset,address paymentAdapter,${native.CANONICAL_NATIVE_DUTCH_SCHEDULE_TUPLE} schedule,bool declaredFree)`;
export const ERC20_DUTCH_EXECUTION_TUPLE = `tuple(${sales.CANONICAL_NATIVE_SALES_PURCHASE_TUPLE} purchase,${sales.CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE} authorization,${sales.CANONICAL_NATIVE_SALES_SIGNATURE_TUPLE} signature)`;
export const ERC20_DUTCH_RECORD_TUPLE = `tuple(${ERC20_DUTCH_CONFIGURATION_TUPLE} config,bytes32 configHash,bytes32 priceScheduleHash,uint256 saleNonce,uint64 soldQuantity,bool closed,${ERC20_DUTCH_LIFECYCLE_TUPLE} lifecycle,bytes32 artistId,uint64 artistGeneration,bytes32 artistBindingHash)`;
export const ERC20_DUTCH_CANDIDATE_TUPLE = sales.CANONICAL_NATIVE_SALES_ACCOUNTING_CONTEXT_TUPLE;
export const ERC20_DUTCH_SETTLEMENT_RESULT_TUPLE = sales.CANONICAL_NATIVE_SALES_SETTLEMENT_RESULT_TUPLE;
export const ERC20_DUTCH_RESULT_TUPLE = `tuple(uint8 revenueOutcome,bytes32 executionId,${ERC20_DUTCH_SETTLEMENT_RESULT_TUPLE} settlement)`;
export const ERC20_DUTCH_PAYMENT_REQUEST_TUPLE = "tuple(address saleAdapter,bytes32 saleAdapterCodeHash,bytes32 saleId,bytes32 saleConfigHash,uint256 maxAmount,bytes executionData)";
export const ERC20_DUTCH_PAYMENT_INTENT_TUPLE = "tuple(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)";
export const ERC20_DUTCH_EIP2612_MAXIMUM_TUPLE = "tuple(uint256 permittedAmount,tuple(uint256 deadline,uint8 v,bytes32 r,bytes32 s) authorization)";
export const ERC20_DUTCH_PERMIT2_MAXIMUM_TUPLE = "tuple(uint256 permittedAmount,tuple(uint256 nonce,uint256 deadline,bytes signature) authorization)";
export const CURRENT_ERC20_DUTCH_ABI = Object.freeze([
  `function dutchSaleRecord(bytes32 saleId) view returns(${ERC20_DUTCH_RECORD_TUPLE})`,
  `function previewDutchExecution(${ERC20_DUTCH_EXECUTION_TUPLE} execution) view returns(${ERC20_DUTCH_CANDIDATE_TUPLE} candidate,bytes executionData)`,
  // Original Payment-only read callback; deliberately absent from the wallet read request union.
  `function resolveERC20DutchExecution(bytes32 saleId,bytes32 saleConfigHash,address executor,bytes executionData) view returns(${ERC20_DUTCH_CANDIDATE_TUPLE})`,
  "function currentDutchPrice(bytes32 saleId) view returns(uint256)",
  `function saleConfigurationHash(${ERC20_DUTCH_CONFIGURATION_TUPLE} config) view returns(bytes32)`,
  `function saleLifecycleBinding(bytes32 saleId) view returns(${ERC20_DUTCH_LIFECYCLE_TUPLE})`,
  "function publicERC20SaleBinding(bytes32 saleId) view returns(uint256,bytes32,bytes32,uint8)",
  "function activePublicERC20Candidate(bytes32 executionId) view returns(bytes32)",
  "function dutchResolutionProfile() pure returns(bytes32)",
  ...sales.CURRENT_CANONICAL_NATIVE_IMMEDIATE_SALES_ABI.filter(fragment =>
    !["purchaseSigned", "purchasePublic", "previewSignedPurchase", "previewPublicPurchase", "saleRecord",
      "saleConfigurationHash", "nativeSaleLifecycleBinding", "publicNativeSaleBinding", "activePublicNativeCandidate"]
      .some(name => fragment.startsWith(`function ${name}(`))),
]);
export const CURRENT_ERC20_DUTCH_PAYMENT_ABI = Object.freeze([
  `function settleERC20DutchSaleByPayer(${ERC20_DUTCH_PAYMENT_REQUEST_TUPLE} request) payable returns(${ERC20_DUTCH_RESULT_TUPLE})`,
  `function settleERC20DutchSaleWithIntent(${ERC20_DUTCH_PAYMENT_REQUEST_TUPLE} request,${ERC20_DUTCH_PAYMENT_INTENT_TUPLE} intent,bytes signature) payable returns(${ERC20_DUTCH_RESULT_TUPLE})`,
  `function settleERC20DutchSaleWithEIP2612Permit(${ERC20_DUTCH_PAYMENT_REQUEST_TUPLE} request,${ERC20_DUTCH_EIP2612_MAXIMUM_TUPLE} permit) payable returns(${ERC20_DUTCH_RESULT_TUPLE})`,
  `function settleERC20DutchSaleWithPermit2(${ERC20_DUTCH_PAYMENT_REQUEST_TUPLE} request,${ERC20_DUTCH_PERMIT2_MAXIMUM_TUPLE} permit) payable returns(${ERC20_DUTCH_RESULT_TUPLE})`,
]);
const abi = new Interface(CURRENT_ERC20_DUTCH_ABI);
const paymentAbi = new Interface(CURRENT_ERC20_DUTCH_PAYMENT_ABI);
const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;
const ZERO_ADDRESS = ZeroAddress as Address;

function exact(value: unknown, keys: readonly string[]): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error("Expected object");
  const actual = Reflect.ownKeys(value);
  if (actual.length !== keys.length || actual.some(key => typeof key !== "string" || !keys.includes(key))) throw Error("Missing or unknown fields");
}
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`);
  return value;
}
function address(value: unknown, nonzero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (nonzero && result === ZERO_ADDRESS) throw Error("Expected nonzero address");
  return result;
}
function bytes(value: unknown, maximum = ERC20_DUTCH_MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > maximum) throw Error("Invalid bytes or client byte limit exceeded");
  return value.toLowerCase() as Hex;
}
function hash(value: unknown, nonzero = false): Hex {
  const result = bytes(value, 32);
  if (result.length !== 66 || (nonzero && result === ZERO)) throw Error("Expected bytes32");
  return result;
}
function tuple(param: ParamType, value: unknown, decoded = false): unknown {
  if (param.baseType === "tuple") {
    if (!decoded) exact(value, param.components!.map(field => field.name));
    return Object.freeze(Object.fromEntries(param.components!.map((field, i) => [field.name,
      tuple(field, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[field.name], decoded)])));
  }
  if (param.type === "address") return address(value);
  if (param.type === "bytes32") return hash(value);
  if (param.type === "bytes") return bytes(value);
  if (param.type === "bool") {
    if (typeof value !== "boolean") throw Error("Expected boolean");
    return value;
  }
  if (/^uint\d+$/.test(param.type)) return uint(value, Number(param.type.slice(4)));
  throw Error("Unsupported ERC20 Dutch codec field");
}
function normalize<T>(shape: string, value: T): T { return tuple(ParamType.from(shape), value) as T; }
function encode<T>(shape: string, value: T): Hex { return bytes(coder.encode([shape], [normalize(shape, value)])); }
function decode<T>(shape: string, value: Hex): T {
  const raw = bytes(value);
  const result = tuple(ParamType.from(shape), coder.decode([shape], raw)[0], true) as T;
  if (encode(shape, result) !== raw) throw Error("Noncanonical ABI encoding");
  return result;
}
function digest(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(coder.encode(types, values)) as Hex; }

export function normalizeERC20DutchCoordinates(value: ERC20DutchCoordinates): ERC20DutchCoordinates {
  exact(value, ["chainId", "adapter", "manager", "ledger", "recorder", "paymentAdapter"]);
  const c = sales.normalizeCanonicalNativeSalesCoordinates({ chainId: value.chainId, adapter: value.adapter,
    manager: value.manager, ledger: value.ledger, recorder: value.recorder });
  const paymentAdapter = address(value.paymentAdapter, true);
  if (paymentAdapter === c.adapter || paymentAdapter === c.recorder) throw Error("Payment adapter must be separate");
  return Object.freeze({ ...c, paymentAdapter });
}

export function erc20DutchSalesCoordinates(
  value: ERC20DutchCoordinates,
): sales.CanonicalNativeSalesCoordinates {
  const c = normalizeERC20DutchCoordinates(value);
  return Object.freeze({ chainId: c.chainId, adapter: c.adapter, manager: c.manager, ledger: c.ledger, recorder: c.recorder });
}

export function erc20DutchInterface(): Interface {
  return abi;
}

export function erc20DutchPaymentInterface(): Interface {
  return paymentAbi;
}

export function normalizeERC20DutchConfiguration(value: ERC20DutchConfiguration): ERC20DutchConfiguration {
  return normalize(ERC20_DUTCH_CONFIGURATION_TUPLE, value);
}

export function encodeERC20DutchConfiguration(value: ERC20DutchConfiguration): Hex {
  return encode(ERC20_DUTCH_CONFIGURATION_TUPLE, value);
}

export function decodeERC20DutchConfiguration(value: Hex): ERC20DutchConfiguration {
  return decode(ERC20_DUTCH_CONFIGURATION_TUPLE, value);
}

export function normalizeERC20DutchRecord(value: ERC20DutchRecord): ERC20DutchRecord {
  return normalize(ERC20_DUTCH_RECORD_TUPLE, value);
}

export function encodeERC20DutchRecord(value: ERC20DutchRecord): Hex {
  return encode(ERC20_DUTCH_RECORD_TUPLE, value);
}

export function decodeERC20DutchRecord(value: Hex): ERC20DutchRecord {
  return decode(ERC20_DUTCH_RECORD_TUPLE, value);
}

export function normalizeERC20DutchExecution(value: ERC20DutchExecution): ERC20DutchExecution {
  return normalize(ERC20_DUTCH_EXECUTION_TUPLE, value);
}

export function encodeERC20DutchExecution(value: ERC20DutchExecution): Hex {
  return encode(ERC20_DUTCH_EXECUTION_TUPLE, value);
}

export function decodeERC20DutchExecution(value: Hex): ERC20DutchExecution {
  return decode(ERC20_DUTCH_EXECUTION_TUPLE, value);
}

export function normalizeERC20DutchCandidate(value: ERC20DutchCandidate): ERC20DutchCandidate {
  return normalize(ERC20_DUTCH_CANDIDATE_TUPLE, value);
}

export function encodeERC20DutchCandidate(value: ERC20DutchCandidate): Hex {
  return encode(ERC20_DUTCH_CANDIDATE_TUPLE, value);
}

export function decodeERC20DutchCandidate(value: Hex): ERC20DutchCandidate {
  return decode(ERC20_DUTCH_CANDIDATE_TUPLE, value);
}

export function normalizeERC20DutchResult(value: ERC20DutchResult): ERC20DutchResult {
  return normalize(ERC20_DUTCH_RESULT_TUPLE, value);
}

export function encodeERC20DutchResult(value: ERC20DutchResult): Hex {
  return encode(ERC20_DUTCH_RESULT_TUPLE, value);
}

export function decodeERC20DutchResult(value: Hex): ERC20DutchResult {
  return decode(ERC20_DUTCH_RESULT_TUPLE, value);
}

export function normalizeERC20DutchPaymentRequest(value: ERC20DutchPaymentRequest): ERC20DutchPaymentRequest {
  return normalize(ERC20_DUTCH_PAYMENT_REQUEST_TUPLE, value);
}

export function normalizeERC20DutchPaymentIntent(value: PaymentIntent): PaymentIntent {
  return normalize(ERC20_DUTCH_PAYMENT_INTENT_TUPLE, value);
}

export function normalizeERC20DutchEIP2612Maximum(value: ERC20DutchEIP2612Maximum): ERC20DutchEIP2612Maximum {
  return normalize(ERC20_DUTCH_EIP2612_MAXIMUM_TUPLE, value);
}

export function normalizeERC20DutchPermit2Maximum(value: ERC20DutchPermit2Maximum): ERC20DutchPermit2Maximum {
  const result = normalize(ERC20_DUTCH_PERMIT2_MAXIMUM_TUPLE, value);
  bytes(result.authorization.signature, ERC20_DUTCH_MAX_SIGNATURE_BYTES);
  return result;
}
export const normalizeERC20DutchReceipt = sales.normalizeCanonicalNativeSalesReceipt;
export const normalizeERC20DutchSettlementResult = sales.normalizeCanonicalNativeSalesResult;

export function validateERC20DutchConfiguration(value: ERC20DutchConfiguration): ERC20DutchConfiguration {
  const c = normalizeERC20DutchConfiguration(value);
  if (c.sale.unitPrice !== 0n || c.asset === ZERO_ADDRESS || c.paymentAdapter === ZERO_ADDRESS
      || (!c.sale.manualClose && c.sale.endsAt <= c.schedule.endTime)) throw Error("Invalid ERC20 Dutch configuration");
  // The common signer and schedule predicates are identical; only the stored price and timed-end inequality differ.
  native.validateCanonicalNativeDutchConfiguration({ sale: { ...c.sale, unitPrice: c.schedule.startPrice },
    schedule: c.schedule, declaredFree: c.declaredFree });
  return c;
}

export function erc20DutchConfigurationHash(
  coordinates: ERC20DutchCoordinates,
  config: ERC20DutchConfiguration,
): Hex {
  const c = normalizeERC20DutchCoordinates(coordinates);
  return digest(["bytes32", "uint256", "address", ERC20_DUTCH_CONFIGURATION_TUPLE], [
    id("6529STREAM_ERC20_STANDARD_DUTCH_CONFIG_V1"), c.chainId, c.adapter, normalizeERC20DutchConfiguration(config),
  ]);
}

export function erc20DutchSaleId(
  coordinates: ERC20DutchCoordinates,
  collectionId: bigint,
  phaseId: Hex,
  nonce: bigint,
): Hex {
  const c = normalizeERC20DutchCoordinates(coordinates);
  return digest(["bytes32", "uint256", "address", "uint256", "bytes32", "uint256"], [
    id("6529STREAM_ERC20_DUTCH_SALE_ID_V1"), c.chainId, c.adapter, uint(collectionId), hash(phaseId), uint(nonce),
  ]);
}

export function erc20DutchRequestHash(
  coordinates: ERC20DutchCoordinates,
  configHash: Hex,
  purchase: sales.CanonicalNativeSalesPurchase,
): Hex {
  const c = normalizeERC20DutchCoordinates(coordinates);
  return digest(["bytes32", "uint256", "address", "bytes32", sales.CANONICAL_NATIVE_SALES_PURCHASE_TUPLE], [
    id("6529STREAM_ERC20_DUTCH_REQUEST_V1"), c.chainId, c.adapter, hash(configHash), sales.normalizeCanonicalNativeSalesPurchase(purchase),
  ]);
}

export function erc20DutchPublicAuthorizationId(
  coordinates: ERC20DutchCoordinates,
  configHash: Hex,
  requestHash: Hex,
): Hex {
  const c = normalizeERC20DutchCoordinates(coordinates);
  return digest(["bytes32", "uint256", "address", "address", "bytes32", "bytes32"], [
    id("6529STREAM_ERC20_DUTCH_PUBLIC_AUTHORIZATION_V1"), c.chainId, c.adapter, c.manager, hash(configHash), hash(requestHash),
  ]);
}

export function erc20DutchSaleExecutionHash(execution: ERC20DutchExecution): Hex {
  return keccak256(encodeERC20DutchExecution(execution)) as Hex;
}

export function erc20DutchExecutionId(chainId: bigint, candidate: ERC20DutchCandidate): Hex {
  const c = normalizeERC20DutchCandidate(candidate);
  return digest(["bytes32", "uint256", "address", "bytes32", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32"], [
    id("6529STREAM_ERC20_SALE_EXECUTION_V1"), uint(chainId), c.saleAdapter, c.sale.settlementId, c.sale.payer, c.executor,
    c.executionBinding.executionNonce, c.executionBinding.authorityMode, c.executionBinding.saleAuthorizationDigest,
    c.currentPolicyHash, c.boundPolicyHash, c.operationIdentityCommitment,
  ]);
}

export function erc20DutchCandidateCommitment(
  chainId: bigint,
  paymentAdapter: Address,
  recorder: Address,
  candidate: ERC20DutchCandidate,
): Hex {
  return digest(["bytes32", "uint256", "address", "address", ERC20_DUTCH_CANDIDATE_TUPLE], [
    id("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2"), uint(chainId), address(paymentAdapter), address(recorder), normalizeERC20DutchCandidate(candidate),
  ]);
}
export const erc20DutchSettlementKey = sales.canonicalNativeSalesSettlementKey;
/** ERC20 conservation accounting retains the complete original lifecycle. */
export const erc20DutchAccountingContext = normalizeERC20DutchCandidate;
export function erc20DutchAccountingContextHash(candidate: ERC20DutchCandidate): Hex {
  return keccak256(encodeERC20DutchCandidate(candidate)) as Hex;
}

export function erc20DutchAuthorizationPayload(
  coordinates: ERC20DutchCoordinates,
  authorization: sales.CanonicalNativeSalesAuthorization,
) {
  return sales.canonicalNativeSalesAuthorizationPayload(erc20DutchSalesCoordinates(coordinates), authorization);
}

export function erc20DutchAuthorizationId(
  coordinates: ERC20DutchCoordinates,
  authorization: sales.CanonicalNativeSalesAuthorization,
): Hex {
  return sales.canonicalNativeSalesAuthorizationId(erc20DutchSalesCoordinates(coordinates), authorization);
}

export function erc20DutchRevocationPayload(
  coordinates: ERC20DutchCoordinates,
  authorization: sales.CanonicalNativeSalesAuthorization,
) {
  return sales.canonicalNativeSalesRevocationPayload(erc20DutchSalesCoordinates(coordinates), authorization);
}

export function erc20DutchPaymentIntentPayload(coordinates: ERC20DutchCoordinates, value: PaymentIntent) {
  const c = normalizeERC20DutchCoordinates(coordinates);
  const intent = normalizeERC20DutchPaymentIntent(value);
  const fields = ParamType.from(ERC20_DUTCH_PAYMENT_INTENT_TUPLE).components!.map(field => ({ name: field.name, type: field.type }));
  return buildSigningPayload(c.chainId, c.paymentAdapter, "6529StreamPaymentIntentVerifier", "StreamPaymentIntent", fields, intent);
}

export function erc20DutchPrice(
  configuration: ERC20DutchConfiguration,
  timestamp: bigint,
  signedMaximum: bigint | null,
  override: sales.CanonicalNativeSalesPriceOverride,
): native.CanonicalNativeDutchPrice {
  const c = validateERC20DutchConfiguration(configuration);
  return native.canonicalNativeDutchPrice({ sale: { ...c.sale, unitPrice: c.schedule.startPrice },
    schedule: c.schedule, declaredFree: c.declaredFree }, timestamp, signedMaximum, override);
}

export function erc20DutchAllowlistPrice(
  coordinates: ERC20DutchCoordinates,
  configuration: ERC20DutchConfiguration,
  purchase: sales.CanonicalNativeSalesPurchase,
  observations: readonly sales.CanonicalNativeSalesCounterObservation[],
): sales.CanonicalNativeSalesPriceOverride {
  return sales.canonicalNativeSalesAllowlistPrice(erc20DutchSalesCoordinates(coordinates),
    normalizeERC20DutchConfiguration(configuration).sale, purchase, observations);
}

function requirePurchase(c: ERC20DutchCoordinates, p: sales.CanonicalNativeSalesPurchase): void {
  if (p.saleId === ZERO || p.payer === ZERO_ADDRESS || p.executor === ZERO_ADDRESS
      || p.payer === c.adapter || p.executor === c.adapter || p.payer === c.paymentAdapter || p.payer === c.recorder
      || p.initialRecipient === ZERO_ADDRESS || p.initialRecipient === c.adapter || p.beneficiary === ZERO_ADDRESS
      || p.mintCommitment === ZERO || p.executionNonce === 0n) throw Error("Invalid ERC20 Dutch purchase binding");
  bytes(p.tokenData, 8192);
}
function emptyAuthorization(value: sales.CanonicalNativeSalesAuthorization): boolean {
  return Object.values(value).every(field => field === ZERO || field === ZERO_ADDRESS || field === 0n);
}
function requireExecution(c: ERC20DutchCoordinates, execution: ERC20DutchExecution): 1n | 2n {
  const p = execution.purchase;
  requirePurchase(c, p);
  const a = execution.authorization;
  const proof = execution.signature;
  bytes(proof.signature, ERC20_DUTCH_MAX_SIGNATURE_BYTES);
  if (emptyAuthorization(a)) {
    if (proof.authorizer !== ZERO_ADDRESS || proof.kind !== 0n || proof.signature !== "0x" || p.payer !== p.executor) {
      throw Error("Public Dutch execution must use literal empty authority and payer executor");
    }
    return 2n;
  }
  erc20DutchAuthorizationPayload(c, a);
  const arrays = primaryOfferBatchHashes(p.initialRecipient, p.beneficiary, p.tokenData, p.mintCommitment);
  if (proof.authorizer === ZERO_ADDRESS || (proof.kind !== 1n && proof.kind !== 2n)
      || a.collectionId === 0n || a.phaseId === ZERO || a.saleId !== p.saleId || a.saleKind !== 3n
      || a.revenueClass !== id("PRIMARY_SALE") || a.expectedPrimaryPolicyHash === ZERO || a.primaryPolicyMode !== 0n
      || a.payer !== p.payer || a.executor !== p.executor || a.asset === ZERO_ADDRESS || a.quantity !== 1n
      || a.contentSelectionHash !== ZERO || a.policyHash === ZERO || a.nonce === ZERO || a.finalizeBy !== 0n
      || Object.entries(arrays).some(([key, value]) => a[key as keyof typeof a] !== value)) {
    throw Error("Authorization differs from ERC20 Dutch purchase");
  }
  return 1n;
}

export function erc20DutchExpectedAuthorization(
  coordinates: ERC20DutchCoordinates,
  configuration: ERC20DutchConfiguration,
  purchase: sales.CanonicalNativeSalesPurchase,
  terms: sales.CanonicalNativeSalesSigningTerms,
): sales.CanonicalNativeSalesAuthorization {
  const c = normalizeERC20DutchCoordinates(coordinates);
  const config = validateERC20DutchConfiguration(configuration);
  const p = sales.normalizeCanonicalNativeSalesPurchase(purchase);
  exact(terms, ["nonce", "deadline", "unitPrice"]);
  if (config.sale.authorityMode !== 1n || config.paymentAdapter !== c.paymentAdapter) throw Error("Expected signed matching payment configuration");
  requirePurchase(c, p);
  return sales.normalizeCanonicalNativeSalesAuthorization({
    chainId: c.chainId, saleAdapter: c.adapter, mintManager: c.manager, collectionId: config.sale.collectionId,
    phaseId: config.sale.phaseId, saleId: p.saleId, saleKind: 3n, revenueClass: id("PRIMARY_SALE") as Hex,
    expectedPrimaryPolicyHash: config.sale.expectedPrimaryPolicyHash, primaryPolicyMode: 0n,
    ...primaryOfferBatchHashes(p.initialRecipient, p.beneficiary, p.tokenData, p.mintCommitment),
    payer: p.payer, executor: p.executor, asset: config.asset, unitPrice: uint(terms.unitPrice), quantity: 1n,
    contentSelectionHash: ZERO, policyHash: config.sale.mintPolicyHash, nonce: hash(terms.nonce, true),
    deadline: uint(terms.deadline, 64), finalizeBy: 0n,
  });
}

export function erc20DutchPublicExecution(purchase: sales.CanonicalNativeSalesPurchase): ERC20DutchExecution {
  const authorization = Object.fromEntries(ParamType.from(sales.CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE).components!.map(field => [
    field.name, field.type === "address" ? ZERO_ADDRESS : field.type === "bytes32" ? ZERO : 0n,
  ])) as unknown as sales.CanonicalNativeSalesAuthorization;
  return normalizeERC20DutchExecution({ purchase, authorization, signature: { authorizer: ZERO_ADDRESS, kind: 0n, signature: "0x" } });
}

export function prepareERC20DutchPaymentRequest(
  coordinates: ERC20DutchCoordinates,
  adapterCodeHash: Hex,
  configHash: Hex,
  maxAmount: bigint,
  execution: ERC20DutchExecution,
): ERC20DutchPaymentRequest {
  const c = normalizeERC20DutchCoordinates(coordinates);
  const e = normalizeERC20DutchExecution(execution);
  requireExecution(c, e);
  return Object.freeze({ saleAdapter: c.adapter, saleAdapterCodeHash: hash(adapterCodeHash, true), saleId: e.purchase.saleId,
    saleConfigHash: hash(configHash, true), maxAmount: uint(maxAmount), executionData: encodeERC20DutchExecution(e) });
}

export function normalizeERC20DutchRequest(value: ERC20DutchRequest): ERC20DutchRequest {
  if (value.kind === "claimRefund" || value.kind === "voidMintImmediateSaleAuthorization") {
    return native.normalizeCanonicalNativeDutchRequest(value) as typeof value;
  }
  switch (value.kind) {
    case "settleERC20DutchSaleByPayer":
      exact(value, ["kind", "request", "value"]);
      return Object.freeze({ kind: value.kind, request: normalizeERC20DutchPaymentRequest(value.request), value: uint(value.value) });
    case "settleERC20DutchSaleWithIntent":
      exact(value, ["kind", "request", "intent", "signature", "value"]);
      return Object.freeze({ kind: value.kind, request: normalizeERC20DutchPaymentRequest(value.request),
        intent: normalizeERC20DutchPaymentIntent(value.intent), signature: bytes(value.signature, ERC20_DUTCH_MAX_SIGNATURE_BYTES), value: uint(value.value) });
    case "settleERC20DutchSaleWithEIP2612Permit":
      exact(value, ["kind", "request", "permit", "value"]);
      return Object.freeze({ kind: value.kind, request: normalizeERC20DutchPaymentRequest(value.request),
        permit: normalizeERC20DutchEIP2612Maximum(value.permit), value: uint(value.value) });
    case "settleERC20DutchSaleWithPermit2":
      exact(value, ["kind", "request", "permit", "value"]);
      return Object.freeze({ kind: value.kind, request: normalizeERC20DutchPaymentRequest(value.request),
        permit: normalizeERC20DutchPermit2Maximum(value.permit), value: uint(value.value) });
    default: throw Error("Unsupported ERC20 Dutch operation");
  }
}

export function prepareERC20DutchCall(
  coordinates: ERC20DutchCoordinates,
  caller: Address,
  input: ERC20DutchRequest,
): ERC20DutchCall {
  const c = normalizeERC20DutchCoordinates(coordinates);
  const actor = address(caller, true);
  const request = normalizeERC20DutchRequest(input);
  if (request.kind === "claimRefund" || request.kind === "voidMintImmediateSaleAuthorization") {
    const local = native.prepareCanonicalNativeDutchCall(erc20DutchSalesCoordinates(c), actor, request);
    return Object.freeze({ coordinates: c, caller: actor, request, execution: null, call: local.call, factsVerified: false });
  }
  const r = request.request;
  if (r.saleAdapter !== c.adapter || r.saleAdapterCodeHash === ZERO || r.saleId === ZERO || r.saleConfigHash === ZERO) {
    throw Error("Dutch payment request binding differs");
  }
  const execution = decodeERC20DutchExecution(r.executionData);
  const mode = requireExecution(c, execution);
  if (execution.purchase.saleId !== r.saleId || execution.purchase.executor !== actor
      || ((mode === 2n || request.kind !== "settleERC20DutchSaleWithIntent") && execution.purchase.payer !== actor)) {
    throw Error("Dutch payment caller must satisfy executor and payer route");
  }
  const args: unknown[] = [r];
  if (request.kind === "settleERC20DutchSaleWithIntent") args.push(request.intent, request.signature);
  if (request.kind === "settleERC20DutchSaleWithEIP2612Permit" || request.kind === "settleERC20DutchSaleWithPermit2") args.push(request.permit);
  return Object.freeze({ coordinates: c, caller: actor, request, execution,
    call: Object.freeze({ to: c.paymentAdapter, value: request.value, data: bytes(paymentAbi.encodeFunctionData(request.kind, args)) }),
    factsVerified: false });
}

export function normalizeERC20DutchCall(value: ERC20DutchCall): ERC20DutchCall {
  exact(value, ["coordinates", "caller", "request", "execution", "call", "factsVerified"]);
  exact(value.call, ["to", "value", "data"]);
  const result = prepareERC20DutchCall(value.coordinates, value.caller, value.request);
  if (value.factsVerified !== false || address(value.call.to) !== result.call.to || uint(value.call.value) !== result.call.value
      || bytes(value.call.data) !== result.call.data || (value.execution === null) !== (result.execution === null)
      || (value.execution !== null && result.execution !== null
        && encodeERC20DutchExecution(value.execution) !== encodeERC20DutchExecution(result.execution))) throw Error("Prepared ERC20 Dutch call differs");
  return result;
}

export function validateERC20DutchHistoricalBinding(
  prepared: ERC20DutchCall,
  binding: sales.CanonicalNativeSalesHistoricalBinding,
) {
  const p = normalizeERC20DutchCall(prepared);
  if (p.request.kind !== "voidMintImmediateSaleAuthorization") throw Error("Expected historical revocation");
  return native.validateCanonicalNativeDutchHistoricalBinding(
    native.prepareCanonicalNativeDutchCall(erc20DutchSalesCoordinates(p.coordinates), p.caller, p.request), binding);
}

export function erc20DutchMintBatch(
  prepared: ERC20DutchCall,
  record: ERC20DutchRecord,
): sales.CanonicalNativeSalesMintBatch {
  const plan = normalizeERC20DutchCall(prepared);
  const e = plan.execution;
  if (!e || !("request" in plan.request)) throw Error("Expected Dutch payment operation");
  const r = normalizeERC20DutchRecord(record);
  const config = validateERC20DutchConfiguration(r.config);
  const c = plan.coordinates;
  const p = e.purchase;
  const mode = requireExecution(c, e);
  if (r.saleNonce === 0n || config.paymentAdapter !== c.paymentAdapter || r.lifecycle.paymentAdapter !== c.paymentAdapter
      || r.configHash !== plan.request.request.saleConfigHash || r.configHash !== erc20DutchConfigurationHash(c, config)
      || p.saleId !== erc20DutchSaleId(c, config.sale.collectionId, config.sale.phaseId, r.saleNonce)
      || r.priceScheduleHash !== native.canonicalNativeDutchScheduleHash(erc20DutchSalesCoordinates(c), p.saleId, config.schedule)
      || config.sale.authorityMode !== mode) throw Error("Retained ERC20 Dutch identity differs");
  const contextHash = erc20DutchRequestHash(c, r.configHash, p);
  let authorizationId: Hex;
  if (mode === 1n) {
    const a = e.authorization;
    const expected = erc20DutchExpectedAuthorization(c, config, p, { nonce: a.nonce, deadline: a.deadline, unitPrice: a.unitPrice });
    if (sales.encodeCanonicalNativeSalesAuthorization(a) !== sales.encodeCanonicalNativeSalesAuthorization(expected)
        || e.signature.authorizer !== config.sale.signer.authorizer || e.signature.kind !== config.sale.signer.kind) {
      throw Error("Authorization differs from retained ERC20 Dutch terms");
    }
    authorizationId = erc20DutchAuthorizationId(c, a);
  } else authorizationId = erc20DutchPublicAuthorizationId(c, r.configHash, contextHash);
  return Object.freeze({ collectionId: config.sale.collectionId, phaseId: config.sale.phaseId, payer: p.payer, authorizer: ZERO_ADDRESS,
    initialRecipients: Object.freeze([p.initialRecipient]), beneficiaries: Object.freeze([p.beneficiary]),
    tokenData: Object.freeze([p.tokenData]), mintCommitments: Object.freeze([p.mintCommitment]),
    expectedPolicyHash: config.sale.mintPolicyHash, authorizationId, contextHash, resolverData: p.resolverData });
}

/** Checks supplied resolved terms; original simulation remains authoritative for signatures, balances and nonce state. */
export function validateERC20DutchFunding(
  prepared: ERC20DutchCall,
  candidate: ERC20DutchCandidate,
  timestamp: bigint,
): Readonly<{ amount: bigint; requestMaximum: bigint; consumesPaymentIntent: boolean; usesPermit: boolean }> {
  const p = normalizeERC20DutchCall(prepared);
  const c = normalizeERC20DutchCandidate(candidate);
  if (!p.execution || !("request" in p.request)) throw Error("Expected Dutch payment");
  const r = p.request;
  const e = p.execution;
  const time = uint(timestamp);
  const mode = requireExecution(p.coordinates, e);
  if (c.saleAdapter !== p.coordinates.adapter || c.executor !== p.caller || c.sale.payer !== e.purchase.payer
      || c.sale.beneficiary !== e.purchase.beneficiary || c.sale.settlementId !== r.request.saleId
      || c.lifecycleBinding.paymentAdapter !== p.coordinates.paymentAdapter || c.asset === ZERO_ADDRESS
      || c.executionBinding.authorityMode !== mode || c.executionBinding.executionNonce !== e.purchase.executionNonce
      || c.executionBinding.saleAuthorizationDigest !== (mode === 1n ? erc20DutchAuthorizationPayload(p.coordinates, e.authorization).digest : ZERO)
      || c.saleExecutionHash !== erc20DutchSaleExecutionHash(e) || c.orchestrationOrder !== 1n
      || c.mintManager !== p.coordinates.manager || c.operationIdentityCommitment === ZERO || c.operationId === ZERO
      || c.sale.expectedPrimaryPolicyHash === ZERO || c.executionBinding.executionId !== erc20DutchExecutionId(p.coordinates.chainId, c)
      || c.sale.amount > r.request.maxAmount) throw Error("Resolved Dutch candidate differs from request");
  if (mode === 1n) {
    sales.validateCanonicalNativeSalesAuthorizationDeadline(e.authorization, time);
    if (c.asset !== e.authorization.asset || c.sale.expectedPrimaryPolicyHash !== e.authorization.expectedPrimaryPolicyHash) {
      throw Error("Resolved token or policy differs from authorization");
    }
  }
  const paid = c.sale.amount !== 0n;
  if (r.kind === "settleERC20DutchSaleWithIntent") {
    const i = r.intent;
    if (i.payer !== c.sale.payer || i.asset !== c.asset || i.saleRef !== c.sale.settlementId
        || i.expectedPrimaryPolicyHash !== c.sale.expectedPrimaryPolicyHash || i.maxAmount < c.sale.amount || i.deadline < time) {
      throw Error("Original payment intent terms or deadline differ");
    }
  } else if (paid && (r.kind === "settleERC20DutchSaleWithEIP2612Permit" || r.kind === "settleERC20DutchSaleWithPermit2")) {
    if (r.permit.permittedAmount < c.sale.amount || r.permit.authorization.deadline < time) throw Error("Permit maximum or deadline insufficient");
  }
  return Object.freeze({ amount: c.sale.amount, requestMaximum: r.request.maxAmount,
    consumesPaymentIntent: paid && r.kind === "settleERC20DutchSaleWithIntent",
    usesPermit: paid && (r.kind === "settleERC20DutchSaleWithEIP2612Permit" || r.kind === "settleERC20DutchSaleWithPermit2") });
}

/** Literal upstream Permit2 inputs: permission maximum differs from the actual requested transfer. */
export function erc20DutchPermit2Transfer(candidate: ERC20DutchCandidate, permit: ERC20DutchPermit2Maximum) {
  const c = normalizeERC20DutchCandidate(candidate);
  const p = normalizeERC20DutchPermit2Maximum(permit);
  if (p.permittedAmount < c.sale.amount) throw Error("Permit maximum below charge");
  return Object.freeze({
    permit: Object.freeze({ permitted: Object.freeze({ token: c.asset, amount: p.permittedAmount }),
      nonce: p.authorization.nonce, deadline: p.authorization.deadline }),
    transferDetails: Object.freeze({ to: c.lifecycleBinding.paymentAdapter, requestedAmount: c.sale.amount }),
    owner: c.sale.payer, signature: p.authorization.signature,
  });
}

export function erc20DutchEIP2612Remaining(maximum: bigint, amount: bigint, observed: bigint): void {
  const max = uint(maximum);
  const charged = uint(amount);
  const remaining = uint(observed);
  if (max < charged || (remaining !== max - charged && !(max === (1n << 256n) - 1n && remaining === max))) {
    throw Error("Permit remaining allowance differs");
  }
}

export function validateERC20DutchResult(
  value: ERC20DutchResult,
  candidate: ERC20DutchCandidate,
): ERC20DutchResult {
  const r = normalizeERC20DutchResult(value);
  const c = normalizeERC20DutchCandidate(candidate);
  if (r.executionId !== c.executionBinding.executionId) throw Error("Dutch result execution differs");
  if (c.sale.amount === 0n) {
    if (r.revenueOutcome !== 1n || Object.values(r.settlement).some(field => field !== ZERO && field !== ZERO_ADDRESS && field !== 0n && field !== false)) {
      throw Error("Free Dutch result must have literal zero settlement");
    }
  } else if (r.revenueOutcome !== 2n || r.settlement.amount !== c.sale.amount || r.settlement.asset !== c.asset
      || r.settlement.executor !== c.executor || r.settlement.executionId !== r.executionId
      || r.settlement.profileId !== c.rights.profileId || r.settlement.wallet !== c.rights.wallet
      || r.settlement.operationIdentityCommitment !== c.operationIdentityCommitment
      || r.settlement.currentPolicyHash !== c.currentPolicyHash || r.settlement.boundPolicyHash !== c.boundPolicyHash) {
    throw Error("Paid Dutch result differs");
  }
  return r;
}

export function prepareERC20DutchPreview(
  coordinates: ERC20DutchCoordinates,
  execution: ERC20DutchExecution,
): UnsignedCall {
  const c = normalizeERC20DutchCoordinates(coordinates);
  const e = normalizeERC20DutchExecution(execution);
  requireExecution(c, e);
  return Object.freeze({ to: c.adapter, value: 0n, data: bytes(abi.encodeFunctionData("previewDutchExecution", [e])) });
}
export type ERC20DutchReadRequest =
  | { readonly kind: "nextSaleNonce" | "refundLiability" | "refundAccountCount" | "eip712Domain" }
  | { readonly kind: "saleConsentFacts" | "immediateSaleAuthorizationBinding" | "saleRevealQuote"; readonly saleId: Hex }
  | { readonly kind: "executionReceipt" | "executionStatus"; readonly executionId: Hex }
  | { readonly kind: "nextExecutionNonce" | "refundableBalance"; readonly saleId: Hex; readonly payer: Address }
  | { readonly kind: "refundAccountAt"; readonly index: bigint }
  | { readonly kind: "saleIdFor"; readonly collectionId: bigint; readonly phaseId: Hex; readonly saleNonce: bigint }
  | { readonly kind: "collectionSigner"; readonly collectionId: bigint; readonly signer: Address; readonly signerKind: bigint }
  | { readonly kind: "authorizationDigest"; readonly authorization: sales.CanonicalNativeSalesAuthorization }
  | { readonly kind: "dutchSaleRecord" | "currentDutchPrice" | "saleLifecycleBinding" | "publicERC20SaleBinding"; readonly saleId: Hex }
  | { readonly kind: "activePublicERC20Candidate"; readonly executionId: Hex }
  | { readonly kind: "dutchResolutionProfile" }
  | { readonly kind: "saleConfigurationHash"; readonly configuration: ERC20DutchConfiguration };
export function prepareERC20DutchRead(adapter: Address, request: ERC20DutchReadRequest): UnsignedCall {
  let args: readonly unknown[] | null = null;
  if (request.kind === "saleConfigurationHash") {
    exact(request, ["kind", "configuration"]);
    args = [normalizeERC20DutchConfiguration(request.configuration)];
  } else if (request.kind === "dutchResolutionProfile") {
    exact(request, ["kind"]);
    args = [];
  } else if (request.kind === "activePublicERC20Candidate") {
    exact(request, ["kind", "executionId"]);
    args = [hash(request.executionId)];
  } else if (request.kind === "dutchSaleRecord" || request.kind === "currentDutchPrice"
      || request.kind === "saleLifecycleBinding" || request.kind === "publicERC20SaleBinding") {
    exact(request, ["kind", "saleId"]);
    args = [hash(request.saleId)];
  }
  if (args !== null) return Object.freeze({ to: address(adapter, true), value: 0n, data: bytes(abi.encodeFunctionData(request.kind, args)) });
  if (!["nextSaleNonce", "refundLiability", "refundAccountCount", "eip712Domain", "saleConsentFacts",
    "immediateSaleAuthorizationBinding", "saleRevealQuote", "executionReceipt", "executionStatus", "nextExecutionNonce",
    "refundableBalance", "refundAccountAt", "saleIdFor", "collectionSigner", "authorizationDigest"].includes(request.kind)) {
    throw Error("Unsupported ERC20 Dutch read");
  }
  return sales.prepareCanonicalNativeSalesRead(adapter, "immediate", request as sales.CanonicalNativeSalesReadRequest);
}
