import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as sales from "./current-canonical-native-sales.js";
import { primaryOfferBatchHashes } from "./current-primary-offer-signing.js";
import { nativeDutchScheduleHash, nativeDutchSchedulePrice } from "./current-native-allowlist-dutch.js";
import type { NativeDutchPriceSchedule } from "./current-native-allowlist-dutch.js";

export const CANONICAL_NATIVE_DUTCH_SOURCE = "6536c25895ae12eb9d702da9361f067152060d9b";
/** Client allocation bounds; the original carrier separately limits tokenData to 8192 bytes. */
export const CANONICAL_NATIVE_DUTCH_MAX_BYTES = 262144;
export const CANONICAL_NATIVE_DUTCH_MAX_SIGNATURE_BYTES = 65536;
export type CanonicalNativeDutchCoordinates = sales.CanonicalNativeSalesCoordinates;
export type CanonicalNativeDutchAuthorization = sales.CanonicalNativeSalesAuthorization;
export type CanonicalNativeDutchPurchase = sales.CanonicalNativeSalesPurchase;
export type CanonicalNativeDutchSignature = sales.CanonicalNativeSalesSignature;
export type CanonicalNativeDutchReceipt = sales.CanonicalNativeSalesReceipt;
export type CanonicalNativeDutchCandidate = sales.CanonicalNativeSalesCandidate;
export type CanonicalNativeDutchSettlementResult = sales.CanonicalNativeSalesSettlementResult;
export type CanonicalNativeDutchSchedule = NativeDutchPriceSchedule;
export type CanonicalNativeDutchCounterObservation = sales.CanonicalNativeSalesCounterObservation;
export type CanonicalNativeDutchPriceOverride = sales.CanonicalNativeSalesPriceOverride;
export interface CanonicalNativeDutchConfiguration {
  readonly sale: sales.CanonicalNativeSalesConfiguration;
  readonly schedule: CanonicalNativeDutchSchedule;
  readonly declaredFree: boolean;
}
export interface CanonicalNativeDutchRecord {
  readonly sale: sales.CanonicalNativeSalesRecord;
  readonly schedule: CanonicalNativeDutchSchedule;
  readonly priceScheduleHash: Hex;
  readonly declaredFree: boolean;
}
export interface CanonicalNativeDutchPrice {
  readonly schedulePrice: bigint;
  readonly amount: bigint;
  readonly overridden: boolean;
}
export type CanonicalNativeDutchRequest =
  | {
    readonly kind: "purchaseSigned";
    readonly purchase: CanonicalNativeDutchPurchase;
    readonly authorization: CanonicalNativeDutchAuthorization;
    readonly signature: CanonicalNativeDutchSignature;
    readonly value: bigint;
  }
  | {
    readonly kind: "purchasePublic";
    readonly purchase: CanonicalNativeDutchPurchase;
    readonly value: bigint;
  }
  | {
    readonly kind: "claimRefund";
    readonly saleId: Hex;
    readonly recipient: Address;
  }
  | {
    readonly kind: "voidMintImmediateSaleAuthorization";
    readonly authorization: CanonicalNativeDutchAuthorization;
    readonly authorizer: Address;
    readonly authorizerKind: bigint;
    readonly revocationSignature: Hex;
  };
export interface CanonicalNativeDutchCall {
  readonly coordinates: CanonicalNativeDutchCoordinates;
  readonly caller: Address;
  readonly request: CanonicalNativeDutchRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export const CANONICAL_NATIVE_DUTCH_SCHEDULE_TUPLE = "tuple(uint96 startPrice,uint96 restingPrice,uint64 startTime,uint64 endTime,uint8 decayKind,uint32 stepSeconds,uint96 stepAmount)";
export const CANONICAL_NATIVE_DUTCH_CONFIGURATION_TUPLE = `tuple(${sales.CANONICAL_NATIVE_SALES_CONFIGURATION_TUPLE} sale,${CANONICAL_NATIVE_DUTCH_SCHEDULE_TUPLE} schedule,bool declaredFree)`;
export const CANONICAL_NATIVE_DUTCH_RECORD_TUPLE = `tuple(${sales.CANONICAL_NATIVE_SALES_RECORD_TUPLE} sale,${CANONICAL_NATIVE_DUTCH_SCHEDULE_TUPLE} schedule,bytes32 priceScheduleHash,bool declaredFree)`;
export const CANONICAL_NATIVE_DUTCH_AUTHORIZATION_TUPLE = sales.CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE;
export const CANONICAL_NATIVE_DUTCH_PURCHASE_TUPLE = sales.CANONICAL_NATIVE_SALES_PURCHASE_TUPLE;
export const CANONICAL_NATIVE_DUTCH_SIGNATURE_TUPLE = sales.CANONICAL_NATIVE_SALES_SIGNATURE_TUPLE;
export const CANONICAL_NATIVE_DUTCH_RECEIPT_TUPLE = sales.CANONICAL_NATIVE_SALES_RECEIPT_TUPLE;
export const CANONICAL_NATIVE_DUTCH_CANDIDATE_TUPLE = sales.CANONICAL_NATIVE_SALES_CANDIDATE_TUPLE;
export const CANONICAL_NATIVE_DUTCH_RESULT_TUPLE = sales.CANONICAL_NATIVE_SALES_SETTLEMENT_RESULT_TUPLE;
export const CANONICAL_NATIVE_DUTCH_MINT_BATCH_TUPLE = sales.CANONICAL_NATIVE_SALES_MINT_BATCH_TUPLE;
export const CANONICAL_NATIVE_DUTCH_REVEAL_QUOTE_TUPLE = sales.CANONICAL_NATIVE_SALES_REVEAL_QUOTE_TUPLE;
export const CURRENT_CANONICAL_NATIVE_DUTCH_ABI = Object.freeze([
  ...sales.CURRENT_CANONICAL_NATIVE_IMMEDIATE_SALES_ABI.filter(fragment =>
    !fragment.startsWith("function saleConfigurationHash(") && !fragment.startsWith("function saleRecord(")),
  `function saleConfigurationHash(${CANONICAL_NATIVE_DUTCH_CONFIGURATION_TUPLE} config) view returns(bytes32)`,
  `function saleRecord(bytes32 id) view returns(${CANONICAL_NATIVE_DUTCH_RECORD_TUPLE})`,
  "function schedulePrice(bytes32 id) view returns(uint256)",
]);
const abi = new Interface(CURRENT_CANONICAL_NATIVE_DUTCH_ABI);
const revocationAbi = new Interface(sales.CURRENT_CANONICAL_NATIVE_SALES_REVOCATION_ABI);
const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;
const ZERO_ADDRESS = ZeroAddress as Address;

function exact(value: unknown, keys: readonly string[]): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error("Expected object");
  const actual = Reflect.ownKeys(value);
  if (actual.length !== keys.length || actual.some(key => typeof key !== "string" || !keys.includes(key))) {
    throw Error("Missing or unknown fields");
  }
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
function bytes(value: unknown, maximum = CANONICAL_NATIVE_DUTCH_MAX_BYTES): Hex {
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
function tuple(param: ParamType, value: unknown, decoded = false): unknown {
  if (param.baseType === "tuple") {
    if (!decoded) exact(value, param.components!.map(field => field.name));
    return Object.freeze(Object.fromEntries(param.components!.map((field, i) => [field.name,
      tuple(field, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[field.name], decoded)])));
  }
  if (param.type === "address") return address(value);
  if (param.type === "bytes32") return hash(value);
  if (param.type === "bool") {
    if (typeof value !== "boolean") throw Error("Expected boolean");
    return value;
  }
  if (/^uint\d+$/.test(param.type)) return uint(value, Number(param.type.slice(4)));
  throw Error("Unsupported Dutch codec field");
}
function normalize<T>(shape: string, value: T): T {
  return tuple(ParamType.from(shape), value) as T;
}
function encode<T>(shape: string, value: T): Hex {
  return bytes(coder.encode([shape], [normalize(shape, value)]));
}
function decode<T>(shape: string, value: Hex): T {
  const raw = bytes(value);
  const result = tuple(ParamType.from(shape), coder.decode([shape], raw)[0], true) as T;
  if (encode(shape, result) !== raw) throw Error("Noncanonical ABI encoding");
  return result;
}
function digest(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

export const normalizeCanonicalNativeDutchCoordinates = sales.normalizeCanonicalNativeSalesCoordinates;
export const normalizeCanonicalNativeDutchAuthorization = sales.normalizeCanonicalNativeSalesAuthorization;
export const normalizeCanonicalNativeDutchPurchase = sales.normalizeCanonicalNativeSalesPurchase;
export const normalizeCanonicalNativeDutchSignature = sales.normalizeCanonicalNativeSalesSignature;
export const normalizeCanonicalNativeDutchReceipt = sales.normalizeCanonicalNativeSalesReceipt;
export const normalizeCanonicalNativeDutchCandidate = sales.normalizeCanonicalNativeSalesCandidate;
export const normalizeCanonicalNativeDutchResult = sales.normalizeCanonicalNativeSalesResult;
export const canonicalNativeDutchAuthorizationPayload = sales.canonicalNativeSalesAuthorizationPayload;
export const canonicalNativeDutchAuthorizationId = sales.canonicalNativeSalesAuthorizationId;
export const canonicalNativeDutchRevocationPayload = sales.canonicalNativeSalesRevocationPayload;
export const canonicalNativeDutchExecutionId = sales.canonicalNativeSalesExecutionId;
export const canonicalNativeDutchCandidateCommitment = sales.canonicalNativeSalesCandidateCommitment;
export const canonicalNativeDutchSettlementKey = sales.canonicalNativeSalesSettlementKey;
export const canonicalNativeDutchAccountingContext = sales.canonicalNativeSalesAccountingContext;
export const canonicalNativeDutchAllowlistPrice = sales.canonicalNativeSalesAllowlistPrice;
export const validateCanonicalNativeDutchAuthorizationDeadline = sales.validateCanonicalNativeSalesAuthorizationDeadline;

/** Structural getter codecs deliberately retain canonical empty records. */
export function normalizeCanonicalNativeDutchSchedule(
  value: CanonicalNativeDutchSchedule,
): CanonicalNativeDutchSchedule {
  return normalize(CANONICAL_NATIVE_DUTCH_SCHEDULE_TUPLE, value);
}

export function normalizeCanonicalNativeDutchConfiguration(
  value: CanonicalNativeDutchConfiguration,
): CanonicalNativeDutchConfiguration {
  return normalize(CANONICAL_NATIVE_DUTCH_CONFIGURATION_TUPLE, value);
}

export function encodeCanonicalNativeDutchConfiguration(value: CanonicalNativeDutchConfiguration): Hex {
  return encode(CANONICAL_NATIVE_DUTCH_CONFIGURATION_TUPLE, value);
}

export function decodeCanonicalNativeDutchConfiguration(value: Hex): CanonicalNativeDutchConfiguration {
  return decode(CANONICAL_NATIVE_DUTCH_CONFIGURATION_TUPLE, value);
}

export function normalizeCanonicalNativeDutchRecord(
  value: CanonicalNativeDutchRecord,
): CanonicalNativeDutchRecord {
  return normalize(CANONICAL_NATIVE_DUTCH_RECORD_TUPLE, value);
}

export function encodeCanonicalNativeDutchRecord(value: CanonicalNativeDutchRecord): Hex {
  return encode(CANONICAL_NATIVE_DUTCH_RECORD_TUPLE, value);
}

export function decodeCanonicalNativeDutchRecord(value: Hex): CanonicalNativeDutchRecord {
  return decode(CANONICAL_NATIVE_DUTCH_RECORD_TUPLE, value);
}

export function canonicalNativeDutchInterface(): Interface {
  return abi;
}

export function validateCanonicalNativeDutchSchedule(
  value: CanonicalNativeDutchSchedule,
  declaredFree: boolean,
): CanonicalNativeDutchSchedule {
  const s = normalizeCanonicalNativeDutchSchedule(value);
  if (typeof declaredFree !== "boolean" || s.startPrice === 0n || s.startPrice < s.restingPrice
      || s.endTime <= s.startTime || (s.restingPrice === 0n && !declaredFree)
      || s.decayKind > 1n || (s.decayKind === 0n && (s.stepSeconds !== 0n || s.stepAmount !== 0n))
      || (s.decayKind === 1n && (s.stepSeconds === 0n || s.stepAmount === 0n))) {
    throw Error("Invalid immutable Dutch schedule");
  }
  return s;
}

export function validateCanonicalNativeDutchConfiguration(
  value: CanonicalNativeDutchConfiguration,
): CanonicalNativeDutchConfiguration {
  const result = normalizeCanonicalNativeDutchConfiguration(value);
  const c = result.sale;
  const s = validateCanonicalNativeDutchSchedule(result.schedule, result.declaredFree);
  if (c.collectionId === 0n || c.phaseId === ZERO || c.saleKind !== 3n || c.saleSupplyLimit === 0n
      || c.mintPolicyHash === ZERO || c.expectedPrimaryPolicyHash === ZERO || c.primaryPolicyMode !== 0n
      || c.unitPrice !== s.startPrice || c.startsAt !== s.startTime
      || (c.manualClose ? c.endsAt !== 0n : c.endsAt < s.endTime)) throw Error("Invalid native Dutch configuration");
  const signer = c.signer;
  if (c.authorityMode === 2n) {
    if (signer.authorizer !== ZERO_ADDRESS || signer.kind !== 0n || signer.evidenceHash !== ZERO
        || signer.revision !== 0n || signer.installingAuthority !== ZERO_ADDRESS) throw Error("Public signer must be empty");
  } else if (c.authorityMode !== 1n || signer.authorizer === ZERO_ADDRESS
      || (signer.kind !== 1n && signer.kind !== 2n) || signer.evidenceHash === ZERO
      || signer.revision === 0n || signer.installingAuthority === ZERO_ADDRESS) throw Error("Invalid signer binding");
  return result;
}

export function canonicalNativeDutchConfigurationHash(
  coordinates: CanonicalNativeDutchCoordinates,
  value: CanonicalNativeDutchConfiguration,
): Hex {
  const c = normalizeCanonicalNativeDutchCoordinates(coordinates);
  return digest(["bytes32", "uint256", "address", CANONICAL_NATIVE_DUTCH_CONFIGURATION_TUPLE], [
    id("6529STREAM_NATIVE_DUTCH_SALES_CONFIG_V1"), c.chainId, c.adapter, normalizeCanonicalNativeDutchConfiguration(value),
  ]);
}

export function canonicalNativeDutchSaleId(
  coordinates: CanonicalNativeDutchCoordinates,
  collectionId: bigint,
  phaseId: Hex,
  nonce: bigint,
): Hex {
  const c = normalizeCanonicalNativeDutchCoordinates(coordinates);
  return digest(["bytes32", "uint256", "address", "uint256", "bytes32", "uint256"], [
    id("6529STREAM_NATIVE_DUTCH_SALES_ID_V1"), c.chainId, c.adapter, uint(collectionId), hash(phaseId), uint(nonce),
  ]);
}

export function canonicalNativeDutchScheduleHash(
  coordinates: CanonicalNativeDutchCoordinates,
  saleId: Hex,
  schedule: CanonicalNativeDutchSchedule,
): Hex {
  const c = normalizeCanonicalNativeDutchCoordinates(coordinates);
  return nativeDutchScheduleHash(c.chainId, c.adapter, saleId, schedule);
}

export function canonicalNativeDutchRequestHash(
  coordinates: CanonicalNativeDutchCoordinates,
  configHash: Hex,
  purchase: CanonicalNativeDutchPurchase,
): Hex {
  const c = normalizeCanonicalNativeDutchCoordinates(coordinates);
  return digest(["bytes32", "uint256", "address", "bytes32", CANONICAL_NATIVE_DUTCH_PURCHASE_TUPLE], [
    id("6529STREAM_NATIVE_DUTCH_SALES_REQUEST_V1"), c.chainId, c.adapter, hash(configHash), normalizeCanonicalNativeDutchPurchase(purchase),
  ]);
}

export function canonicalNativeDutchPublicAuthorizationId(
  coordinates: CanonicalNativeDutchCoordinates,
  configHash: Hex,
  requestHash: Hex,
): Hex {
  const c = normalizeCanonicalNativeDutchCoordinates(coordinates);
  return digest(["bytes32", "uint256", "address", "address", "bytes32", "bytes32"], [
    id("6529STREAM_NATIVE_PUBLIC_DUTCH_MINT_AUTHORIZATION_V1"), c.chainId, c.adapter, c.manager,
    hash(configHash), hash(requestHash),
  ]);
}

export function canonicalNativeDutchSaleExecutionHash(
  requestHash: Hex,
  authorizationDigest: Hex,
  authorizationId: Hex,
): Hex {
  return digest(["bytes32", "bytes32", "bytes32", "bytes32"], [
    id("6529STREAM_NATIVE_DUTCH_SALES_EXECUTION_V1"), hash(requestHash), hash(authorizationDigest), hash(authorizationId),
  ]);
}

/** Raw-time curve. A verified leaf replaces the original signed maximum; it never rewrites the signed message. */
export function canonicalNativeDutchPrice(
  configuration: CanonicalNativeDutchConfiguration,
  timestamp: bigint,
  signedMaximum: bigint | null,
  override: CanonicalNativeDutchPriceOverride,
): CanonicalNativeDutchPrice {
  const c = validateCanonicalNativeDutchConfiguration(configuration);
  exact(override, ["hasOverride", "overridePrice"]);
  if (typeof override.hasOverride !== "boolean" || (!override.hasOverride && override.overridePrice !== 0n)) {
    throw Error("Invalid price override declaration");
  }
  const proven = uint(override.overridePrice);
  if (signedMaximum !== null) uint(signedMaximum);
  if (c.sale.authorityMode !== (signedMaximum === null ? 2n : 1n)) throw Error("Price authority mode differs");
  const schedulePrice = nativeDutchSchedulePrice(c.schedule, uint(timestamp));
  const amount = override.hasOverride && proven < schedulePrice ? proven : schedulePrice;
  if (!override.hasOverride && signedMaximum !== null && signedMaximum < amount) throw Error("Signed maximum below current price");
  if (amount === 0n && !c.declaredFree) throw Error("Zero outcome was not declared free");
  return Object.freeze({ schedulePrice, amount, overridden: override.hasOverride });
}

export function canonicalNativeDutchFunding(
  value: bigint,
  revealFee: bigint,
  chargedAmount: bigint,
): Readonly<{ maximum: bigint; revealCredit: bigint }> {
  const supplied = uint(value);
  const fee = uint(revealFee);
  const amount = uint(chargedAmount);
  if (supplied < fee) throw Error("Native value below reveal fee");
  const maximum = supplied - fee;
  if (maximum < amount) throw Error("Native maximum below Dutch price");
  return Object.freeze({ maximum, revealCredit: maximum - amount });
}

function requirePurchase(c: CanonicalNativeDutchCoordinates, caller: Address, p: CanonicalNativeDutchPurchase): void {
  if (p.saleId === ZERO || p.payer === ZERO_ADDRESS || p.payer !== p.executor || p.payer !== caller
      || p.payer === c.adapter || p.initialRecipient === ZERO_ADDRESS || p.initialRecipient === c.adapter
      || p.beneficiary === ZERO_ADDRESS || p.mintCommitment === ZERO || p.executionNonce === 0n) {
    throw Error("Invalid native Dutch purchase actor or mint binding");
  }
  bytes(p.tokenData, 8192);
}
function requireAuthorization(c: CanonicalNativeDutchCoordinates, p: CanonicalNativeDutchPurchase, a: CanonicalNativeDutchAuthorization): void {
  canonicalNativeDutchAuthorizationPayload(c, a);
  const arrays = primaryOfferBatchHashes(p.initialRecipient, p.beneficiary, p.tokenData, p.mintCommitment);
  if (a.saleKind !== 3n || a.collectionId === 0n || a.phaseId === ZERO || a.saleId !== p.saleId
      || a.revenueClass !== id("PRIMARY_SALE") || a.expectedPrimaryPolicyHash === ZERO || a.primaryPolicyMode !== 0n
      || a.payer !== p.payer || a.executor !== p.executor || a.asset !== ZERO_ADDRESS || a.quantity !== 1n
      || a.contentSelectionHash !== ZERO || a.policyHash === ZERO || a.nonce === ZERO || a.finalizeBy !== 0n
      || Object.entries(arrays).some(([key, value]) => a[key as keyof CanonicalNativeDutchAuthorization] !== value)) {
    throw Error("Authorization differs from Dutch purchase");
  }
}

export function normalizeCanonicalNativeDutchRequest(
  input: CanonicalNativeDutchRequest,
): CanonicalNativeDutchRequest {
  if (input.kind === "purchaseSigned" || input.kind === "purchasePublic") {
    exact(input, input.kind === "purchaseSigned" ? ["kind", "purchase", "authorization", "signature", "value"] : ["kind", "purchase", "value"]);
    const purchase = normalizeCanonicalNativeDutchPurchase(input.purchase);
    const value = uint(input.value);
    if (input.kind === "purchasePublic") return Object.freeze({ kind: input.kind, purchase, value });
    const signature = normalizeCanonicalNativeDutchSignature(input.signature);
    if (signature.authorizer === ZERO_ADDRESS || (signature.kind !== 1n && signature.kind !== 2n)) throw Error("Invalid explicit authorizer kind");
    bytes(signature.signature, CANONICAL_NATIVE_DUTCH_MAX_SIGNATURE_BYTES);
    return Object.freeze({ kind: input.kind, purchase, authorization: normalizeCanonicalNativeDutchAuthorization(input.authorization), signature, value });
  }
  if (input.kind === "claimRefund") {
    exact(input, ["kind", "saleId", "recipient"]);
    return Object.freeze({ kind: input.kind, saleId: hash(input.saleId), recipient: address(input.recipient, true) });
  }
  if (input.kind === "voidMintImmediateSaleAuthorization") {
    exact(input, ["kind", "authorization", "authorizer", "authorizerKind", "revocationSignature"]);
    if (input.authorizerKind !== 1n && input.authorizerKind !== 2n) throw Error("Invalid revocation authorizer kind");
    return Object.freeze({ kind: input.kind, authorization: normalizeCanonicalNativeDutchAuthorization(input.authorization),
      authorizer: address(input.authorizer, true), authorizerKind: input.authorizerKind,
      revocationSignature: bytes(input.revocationSignature, CANONICAL_NATIVE_DUTCH_MAX_SIGNATURE_BYTES) });
  }
  throw Error("Unsupported native Dutch operation");
}

export function prepareCanonicalNativeDutchCall(
  coordinates: CanonicalNativeDutchCoordinates,
  caller: Address,
  input: CanonicalNativeDutchRequest,
): CanonicalNativeDutchCall {
  const c = normalizeCanonicalNativeDutchCoordinates(coordinates);
  const actor = address(caller, true);
  const request = normalizeCanonicalNativeDutchRequest(input);
  let target = c.adapter;
  let value = 0n;
  let data: string;
  if (request.kind === "purchaseSigned" || request.kind === "purchasePublic") {
    requirePurchase(c, actor, request.purchase);
    value = request.value;
    if (request.kind === "purchaseSigned") {
      requireAuthorization(c, request.purchase, request.authorization);
      data = abi.encodeFunctionData(request.kind, [request.purchase, request.authorization, request.signature]);
    } else data = abi.encodeFunctionData(request.kind, [request.purchase]);
  } else if (request.kind === "claimRefund") {
    if (request.recipient === c.adapter) throw Error("Refund recipient cannot be adapter");
    data = abi.encodeFunctionData(request.kind, [request.saleId, request.recipient]);
  } else {
    const a = request.authorization;
    canonicalNativeDutchAuthorizationPayload(c, a);
    if (a.saleKind !== 3n || a.collectionId === 0n || a.phaseId === ZERO || a.saleId === ZERO || a.revenueClass !== id("PRIMARY_SALE")) {
      throw Error("Invalid historical Dutch binding");
    }
    target = c.manager;
    data = revocationAbi.encodeFunctionData(request.kind, [a, request.authorizer, request.authorizerKind, request.revocationSignature]);
  }
  return Object.freeze({ coordinates: c, caller: actor, request,
    call: Object.freeze({ to: target, value, data: bytes(data) }), factsVerified: false });
}

export function normalizeCanonicalNativeDutchCall(value: CanonicalNativeDutchCall): CanonicalNativeDutchCall {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"]);
  exact(value.call, ["to", "value", "data"]);
  const result = prepareCanonicalNativeDutchCall(value.coordinates, value.caller, value.request);
  if (value.factsVerified !== false || address(value.call.to) !== result.call.to || uint(value.call.value) !== result.call.value
      || bytes(value.call.data) !== result.call.data) throw Error("Prepared Dutch call differs from inputs");
  return result;
}

export function validateCanonicalNativeDutchHistoricalBinding(
  prepared: CanonicalNativeDutchCall,
  binding: sales.CanonicalNativeSalesHistoricalBinding,
): sales.CanonicalNativeSalesHistoricalBinding {
  const p = normalizeCanonicalNativeDutchCall(prepared);
  if (p.request.kind !== "voidMintImmediateSaleAuthorization") throw Error("Expected historical revocation");
  const b = sales.normalizeCanonicalNativeSalesHistoricalBinding(binding);
  const r = p.request;
  if (b.collectionId !== r.authorization.collectionId || b.phaseId !== r.authorization.phaseId || b.saleKind !== 3n
      || b.authorityMode !== 1n || b.configHash === ZERO || b.authorizer !== r.authorizer || b.authorizerKind !== r.authorizerKind) {
    throw Error("Historical Dutch signer membership differs");
  }
  return b;
}

export function canonicalNativeDutchExpectedAuthorization(
  coordinates: CanonicalNativeDutchCoordinates,
  configuration: CanonicalNativeDutchConfiguration,
  purchase: CanonicalNativeDutchPurchase,
  terms: sales.CanonicalNativeSalesSigningTerms,
): CanonicalNativeDutchAuthorization {
  const c = normalizeCanonicalNativeDutchCoordinates(coordinates);
  const config = validateCanonicalNativeDutchConfiguration(configuration).sale;
  const p = normalizeCanonicalNativeDutchPurchase(purchase);
  exact(terms, ["nonce", "deadline", "unitPrice"]);
  if (config.authorityMode !== 1n) throw Error("Public mode has no seller signature");
  requirePurchase(c, p.payer, p);
  const result = normalizeCanonicalNativeDutchAuthorization({
    chainId: c.chainId, saleAdapter: c.adapter, mintManager: c.manager, collectionId: config.collectionId,
    phaseId: config.phaseId, saleId: p.saleId, saleKind: 3n, revenueClass: id("PRIMARY_SALE") as Hex,
    expectedPrimaryPolicyHash: config.expectedPrimaryPolicyHash, primaryPolicyMode: 0n,
    ...primaryOfferBatchHashes(p.initialRecipient, p.beneficiary, p.tokenData, p.mintCommitment),
    payer: p.payer, executor: p.executor, asset: ZERO_ADDRESS, unitPrice: uint(terms.unitPrice), quantity: 1n,
    contentSelectionHash: ZERO, policyHash: config.mintPolicyHash, nonce: hash(terms.nonce, true),
    deadline: uint(terms.deadline, 64), finalizeBy: 0n,
  });
  requireAuthorization(c, p, result);
  return result;
}

export function canonicalNativeDutchMintBatch(
  prepared: CanonicalNativeDutchCall,
  record: CanonicalNativeDutchRecord,
): sales.CanonicalNativeSalesMintBatch {
  const plan = normalizeCanonicalNativeDutchCall(prepared);
  const request = plan.request;
  if (request.kind !== "purchasePublic" && request.kind !== "purchaseSigned") throw Error("Expected Dutch purchase");
  const r = normalizeCanonicalNativeDutchRecord(record);
  const configuration = validateCanonicalNativeDutchConfiguration({ sale: r.sale.config, schedule: r.schedule, declaredFree: r.declaredFree });
  const c = plan.coordinates;
  const p = request.purchase;
  const config = configuration.sale;
  if (r.sale.saleNonce === 0n || r.sale.configHash !== canonicalNativeDutchConfigurationHash(c, configuration)
      || p.saleId !== canonicalNativeDutchSaleId(c, config.collectionId, config.phaseId, r.sale.saleNonce)
      || r.priceScheduleHash !== canonicalNativeDutchScheduleHash(c, p.saleId, r.schedule)
      || config.authorityMode !== (request.kind === "purchaseSigned" ? 1n : 2n)) throw Error("Retained Dutch identity differs");
  const contextHash = canonicalNativeDutchRequestHash(c, r.sale.configHash, p);
  let authorizationId: Hex;
  if (request.kind === "purchaseSigned") {
    const expected = canonicalNativeDutchExpectedAuthorization(c, configuration, p, {
      nonce: request.authorization.nonce, deadline: request.authorization.deadline, unitPrice: request.authorization.unitPrice,
    });
    if (sales.encodeCanonicalNativeSalesAuthorization(expected) !== sales.encodeCanonicalNativeSalesAuthorization(request.authorization)
        || request.signature.authorizer !== config.signer.authorizer || request.signature.kind !== config.signer.kind) {
      throw Error("Authorization differs from retained Dutch configuration");
    }
    authorizationId = canonicalNativeDutchAuthorizationId(c, request.authorization);
  } else authorizationId = canonicalNativeDutchPublicAuthorizationId(c, r.sale.configHash, contextHash);
  return Object.freeze({ collectionId: config.collectionId, phaseId: config.phaseId, payer: p.payer, authorizer: ZERO_ADDRESS,
    initialRecipients: Object.freeze([p.initialRecipient]), beneficiaries: Object.freeze([p.beneficiary]),
    tokenData: Object.freeze([p.tokenData]), mintCommitments: Object.freeze([p.mintCommitment]),
    expectedPolicyHash: config.mintPolicyHash, authorizationId, contextHash, resolverData: p.resolverData });
}

export function prepareCanonicalNativeDutchPreview(prepared: CanonicalNativeDutchCall): UnsignedCall {
  const p = normalizeCanonicalNativeDutchCall(prepared);
  const r = p.request;
  if (r.kind !== "purchaseSigned" && r.kind !== "purchasePublic") throw Error("Expected Dutch purchase");
  return Object.freeze({ to: p.coordinates.adapter, value: 0n, data: bytes(r.kind === "purchaseSigned"
    ? abi.encodeFunctionData("previewSignedPurchase", [r.purchase, r.authorization, r.signature])
    : abi.encodeFunctionData("previewPublicPurchase", [r.purchase])) });
}
export type CanonicalNativeDutchReadRequest =
  | Exclude<sales.CanonicalNativeSalesReadRequest, { readonly kind: "saleConfigurationHash" }>
  | { readonly kind: "saleConfigurationHash"; readonly configuration: CanonicalNativeDutchConfiguration }
  | { readonly kind: "schedulePrice"; readonly saleId: Hex };
export function prepareCanonicalNativeDutchRead(
  adapter: Address,
  request: CanonicalNativeDutchReadRequest,
): UnsignedCall {
  if (request.kind === "schedulePrice" || request.kind === "saleConfigurationHash") {
    exact(request, request.kind === "schedulePrice" ? ["kind", "saleId"] : ["kind", "configuration"]);
    const args = request.kind === "schedulePrice" ? [hash(request.saleId)] : [normalizeCanonicalNativeDutchConfiguration(request.configuration)];
    return Object.freeze({ to: address(adapter, true), value: 0n, data: bytes(abi.encodeFunctionData(request.kind, args)) });
  }
  return sales.prepareCanonicalNativeSalesRead(adapter, "immediate", request);
}
