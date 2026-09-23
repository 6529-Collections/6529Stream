import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { PaymentIntent, SigningPayload } from "./signing.js";
import { paymentIntentTypedData } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";
import { burnMintProgramConfigHash, normalizeBurnMintProgramConfig, normalizeBurnMintSources,
  type BurnMintProgramConfig } from "./current-burn-mint.js";
import type { ERC20SettlementCandidate } from "./current-erc20-primary-offer.js";
import { erc20PrimaryOfferSettlementKey } from "./current-erc20-primary-offer.js";
import { normalizeERC20PrimaryOfferPaymentIntent } from "./current-erc20-primary-offer-signing.js";

/** Original universal SaleConfig, with a positive ERC20 price. */
export interface ERC20BurnMintSaleConfig {
  readonly paymentAdapter: Address; readonly collectionId: bigint; readonly phaseId: Hex;
  readonly asset: Address; readonly price: bigint; readonly startsAt: bigint; readonly endsAt: bigint;
  readonly mintPolicyHash: Hex; readonly expectedPrimaryPolicyHash: Hex;
}
/** Original eleven-field UniversalSaleAuthorization, signed by both platform and Artist. */
export interface ERC20BurnMintSaleAuthorization {
  readonly saleId: Hex; readonly saleConfigHash: Hex; readonly payer: Address; readonly executor: Address;
  readonly recipient: Address; readonly artist: Address; readonly tokenDataHash: Hex;
  readonly mintCommitment: Hex; readonly executionNonce: bigint; readonly nonce: Hex; readonly deadline: bigint;
}
export interface ERC20BurnMintSaleExecutionData {
  readonly authorization: ERC20BurnMintSaleAuthorization; readonly tokenData: Hex;
  readonly platformSignature: Hex; readonly artistSignature: Hex;
}
export interface ERC20BurnMintExecution {
  readonly sale: ERC20BurnMintSaleExecutionData; readonly sourceTokenIds: readonly bigint[];
}
export interface ERC20BurnMintSigningSnapshot {
  readonly configuration: ERC20BurnMintSaleConfig; readonly execution: ERC20BurnMintExecution;
  readonly authorizationPayload: SigningPayload<ERC20BurnMintSaleAuthorization>;
  readonly authorizationId: Hex; readonly contextHash: Hex;
  readonly saleExecutionData: Hex; readonly saleExecutionHash: Hex;
}

const coder = AbiCoder.defaultAbiCoder();
const configTuple = "tuple(address paymentAdapter,uint256 collectionId,bytes32 phaseId,address asset,uint256 price,uint64 startsAt,uint64 endsAt,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash)";
const authorizationTuple = "tuple(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline)";
const saleTuple = `tuple(${authorizationTuple} authorization,bytes tokenData,bytes platformSignature,bytes artistSignature)`;
const executionTuple = `tuple(${saleTuple} sale,uint256[] sourceTokenIds)`;
const primarySaleTuple = "tuple(bytes32 settlementId,bytes32 revenueClass,uint8 policyMode,uint256 collectionId,uint256 tokenId,uint256 saleNonce,address payer,address poster,address beneficiary,uint256 amount,bytes32 expectedPrimaryPolicyHash)";
const lifecycleTuple = "tuple(address paymentAdapter,uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision,uint64 paymentAdapterRegistryRevision)";
const bindingTuple = "tuple(bytes32 executionId,uint256 executionNonce,uint8 authorityMode,bytes32 saleAuthorizationDigest)";
const rightsTuple = "tuple(bytes32 profileId,address wallet,bytes32 templateId,bytes32 assignmentHash,bytes32 entriesHash)";
const candidateTuple = `tuple(address saleAdapter,address executor,${primarySaleTuple} sale,${lifecycleTuple} lifecycleBinding,${bindingTuple} executionBinding,address asset,uint8 orchestrationOrder,address mintManager,bytes32 operationIdentityCommitment,bytes32 operationId,bytes32 currentPolicyHash,bytes32 boundPolicyHash,${rightsTuple} rights,bytes32 saleExecutionHash)`;
const authorizationFields = ParamType.from(authorizationTuple).components!.map(field => ({ name: field.name, type: field.type }));

function keys(value: unknown, fields: readonly string[]): asserts value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...fields].sort().join(",")) throw Error("ABI tuple contains missing or unknown properties");
}
function uint(value: unknown, bits = 256, positive = false): bigint {
  if (typeof value !== "bigint" || value < (positive ? 1n : 0n) || value >= 1n << BigInt(bits)) throw Error(`Expected ${positive ? "positive " : ""}uint${bits} bigint`);
  return value;
}
function address(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const out = getAddress(value) as Address;
  if (!zero && out === ZeroAddress) throw Error("Expected nonzero address");
  return out;
}
function hash(value: unknown, zero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (!zero && value.toLowerCase() === ZeroHash)) throw Error("Expected nonzero bytes32");
  return value.toLowerCase() as Hex;
}
function bytes(value: unknown, max: number): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > max) throw Error(`Expected complete bytes within ${max}-byte bound`);
  return value.toLowerCase() as Hex;
}
function same(a: string, b: string): boolean { return a.toLowerCase() === b.toLowerCase(); }
function normalizeTuple<T>(shape: string, value: unknown): T {
  function visit(type: ParamType, input: unknown): unknown {
    if (type.baseType === "tuple") {
      keys(input, type.components!.map(field => field.name));
      return Object.freeze(Object.fromEntries(type.components!.map(field => [field.name, visit(field, input[field.name])])));
    }
    if (type.type.startsWith("uint")) return uint(input, Number(type.type.slice(4)));
    if (type.type === "address") return address(input, true);
    if (type.type === "bytes32") return hash(input, true);
    throw Error("Unsupported scalar in fixed tuple");
  }
  return visit(ParamType.from(shape), value) as T;
}

export function normalizeERC20BurnMintSaleConfig(value: ERC20BurnMintSaleConfig): ERC20BurnMintSaleConfig {
  const c = normalizeTuple<ERC20BurnMintSaleConfig>(configTuple, value);
  address(c.paymentAdapter); address(c.asset); uint(c.collectionId, 256, true); uint(c.price, 256, true);
  hash(c.phaseId); hash(c.mintPolicyHash); hash(c.expectedPrimaryPolicyHash);
  if (c.endsAt <= c.startsAt) throw Error("Sale window must increase");
  return c;
}
export function normalizeERC20BurnMintSaleAuthorization(value: ERC20BurnMintSaleAuthorization): ERC20BurnMintSaleAuthorization {
  const a = normalizeTuple<ERC20BurnMintSaleAuthorization>(authorizationTuple, value);
  for (const v of [a.payer, a.executor, a.recipient, a.artist]) address(v);
  for (const v of [a.saleId, a.saleConfigHash, a.tokenDataHash, a.mintCommitment]) hash(v);
  uint(a.executionNonce, 256, true);
  // Original authorization nonce and deadline are uint/bytes values; zero is not excluded by the schema.
  return a;
}
export function normalizeERC20BurnMintSaleExecutionData(value: ERC20BurnMintSaleExecutionData): ERC20BurnMintSaleExecutionData {
  keys(value, ["authorization", "tokenData", "platformSignature", "artistSignature"]);
  const authorization = normalizeERC20BurnMintSaleAuthorization(value.authorization);
  const tokenData = bytes(value.tokenData, 8192);
  if (!same(keccak256(tokenData), authorization.tokenDataHash)) throw Error("Raw token data differs from signed hash");
  return Object.freeze({ authorization, tokenData, platformSignature: bytes(value.platformSignature, 65_536),
    artistSignature: bytes(value.artistSignature, 65_536) });
}
export function normalizeERC20BurnMintExecution(value: ERC20BurnMintExecution): ERC20BurnMintExecution {
  keys(value, ["sale", "sourceTokenIds"]);
  if (!Array.isArray(value.sourceTokenIds) || value.sourceTokenIds.length < 1 || value.sourceTokenIds.length > 16) throw Error("Burn sources must contain 1..16 token IDs");
  return Object.freeze({ sale: normalizeERC20BurnMintSaleExecutionData(value.sale),
    sourceTokenIds: normalizeBurnMintSources(value.sourceTokenIds, BigInt(value.sourceTokenIds.length), 1n) });
}
/** Whole Execution, including the ordered sources; not merely the inner SaleExecutionData. */
export function encodeERC20BurnMintExecution(value: ERC20BurnMintExecution): Hex {
  return coder.encode([executionTuple], [normalizeERC20BurnMintExecution(value)]) as Hex;
}
export function erc20BurnMintSaleId(chainId: bigint, adapter: Address, collectionId: bigint, phaseId: Hex, nonce: bigint): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), uint(chainId, 256, true), address(adapter), 8n, uint(collectionId, 256, true), hash(phaseId), uint(nonce, 256, true)])) as Hex;
}
export function erc20BurnMintConfigurationHash(saleId: Hex, config: ERC20BurnMintSaleConfig): Hex {
  return keccak256(coder.encode(["bytes32", "bytes32", configTuple],
    [id("6529STREAM_UNIVERSAL_FIXED_PRICE_CONFIG_V1"), hash(saleId), normalizeERC20BurnMintSaleConfig(config)])) as Hex;
}
export function erc20BurnMintAuthorizationPayload(chainId: bigint, adapter: Address, authorization: ERC20BurnMintSaleAuthorization): SigningPayload<ERC20BurnMintSaleAuthorization> {
  return buildSigningPayload(uint(chainId, 256, true), address(adapter), "6529StreamUniversalFixedPriceSaleAdapter",
    "UniversalSaleAuthorization", authorizationFields, normalizeERC20BurnMintSaleAuthorization(authorization));
}
export function erc20BurnMintAuthorizationId(chainId: bigint, adapter: Address, authorization: ERC20BurnMintSaleAuthorization): Hex {
  return keccak256(coder.encode(["bytes32", "bytes32"],
    [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), erc20BurnMintAuthorizationPayload(chainId, adapter, authorization).digest])) as Hex;
}
export function erc20BurnMintSigningSnapshot(
  chainId: bigint, adapter: Address, config: ERC20BurnMintSaleConfig, saleId: Hex, value: ERC20BurnMintExecution,
): ERC20BurnMintSigningSnapshot {
  const configuration = normalizeERC20BurnMintSaleConfig(config), execution = normalizeERC20BurnMintExecution(value);
  const a = execution.sale.authorization;
  if (!same(a.saleId, hash(saleId)) || !same(a.saleConfigHash, erc20BurnMintConfigurationHash(saleId, configuration))
    || a.deadline < configuration.startsAt || a.deadline > configuration.endsAt) throw Error("Authorization differs from sale identity, configuration or window");
  const authorizationPayload = erc20BurnMintAuthorizationPayload(chainId, adapter, a);
  const saleExecutionData = encodeERC20BurnMintExecution(execution);
  return Object.freeze({ configuration, execution, authorizationPayload,
    authorizationId: erc20BurnMintAuthorizationId(chainId, adapter, a), contextHash: authorizationPayload.digest,
    saleExecutionData, saleExecutionHash: keccak256(saleExecutionData) as Hex });
}

export function normalizeERC20BurnMintProgramConfig(value: BurnMintProgramConfig): BurnMintProgramConfig {
  const c = normalizeBurnMintProgramConfig(value);
  if (c.prepared || c.nativeSaleAdapter !== ZeroAddress) throw Error("ERC20 burn program requires prepared false and nativeSaleAdapter zero");
  return c;
}
export function erc20BurnMintProgramConfigHash(chainId: bigint, gate: Address, core: Address, registry: Address, config: BurnMintProgramConfig): Hex {
  return burnMintProgramConfigHash(chainId, gate, core, registry, normalizeERC20BurnMintProgramConfig(config));
}
/** Check immutable program compatibility. Source collection membership and independent approvals need live reads. */
export function validateERC20BurnMintProgram(config: ERC20BurnMintSaleConfig, program: BurnMintProgramConfig, sourceTokenIds: readonly bigint[]): BurnMintProgramConfig {
  const c = normalizeERC20BurnMintSaleConfig(config), p = normalizeERC20BurnMintProgramConfig(program);
  normalizeBurnMintSources(sourceTokenIds, p.sourcesPerMint, 1n);
  if (p.targetCollectionId !== c.collectionId || !same(p.phaseId, c.phaseId) || p.startsAt > c.startsAt
    || (p.endsAt !== 0n && p.endsAt < c.endsAt)) throw Error("Burn program target, phase, ratio or inclusive window differs from sale");
  return p;
}
export function erc20BurnMintPaymentIntentPayload(chainId: bigint, config: ERC20BurnMintSaleConfig, authorization: ERC20BurnMintSaleAuthorization, value: PaymentIntent): SigningPayload<PaymentIntent> {
  const c = normalizeERC20BurnMintSaleConfig(config), a = normalizeERC20BurnMintSaleAuthorization(authorization);
  const intent = normalizeERC20PrimaryOfferPaymentIntent(value);
  if (!same(a.saleConfigHash, erc20BurnMintConfigurationHash(a.saleId, c)) || !same(intent.payer, a.payer)
    || !same(intent.asset, c.asset) || intent.maxAmount < c.price || !same(intent.saleRef, a.saleId)
    || !same(intent.expectedPrimaryPolicyHash, c.expectedPrimaryPolicyHash)) throw Error("PaymentIntent differs from payer, asset, price, sale or primary policy");
  return paymentIntentTypedData(chainId, c.paymentAdapter, intent);
}

/** Burn profile uses zero poster and independently authorized payer/executor/output recipient. */
export function normalizeERC20BurnMintCandidate(value: ERC20SettlementCandidate): ERC20SettlementCandidate {
  const c = normalizeTuple<ERC20SettlementCandidate>(candidateTuple, value);
  for (const a of [c.saleAdapter, c.executor, c.asset, c.mintManager, c.sale.payer, c.sale.beneficiary, c.lifecycleBinding.paymentAdapter, c.rights.wallet]) address(a);
  for (const h of [c.sale.settlementId, c.sale.expectedPrimaryPolicyHash, c.executionBinding.saleAuthorizationDigest,
    c.operationIdentityCommitment, c.operationId, c.currentPolicyHash, c.boundPolicyHash,
    c.rights.profileId, c.rights.assignmentHash, c.rights.entriesHash, c.saleExecutionHash]) hash(h);
  if (c.orchestrationOrder !== 1n || c.executionBinding.authorityMode !== 1n || c.sale.policyMode !== 0n
    || c.sale.tokenId !== 0n || c.sale.poster !== ZeroAddress || !same(c.sale.revenueClass, id("PRIMARY_SALE"))
    || c.rights.templateId !== ZeroHash) throw Error("Unsupported order-one strict PROFILE burn candidate");
  for (const n of [c.sale.collectionId, c.sale.saleNonce, c.sale.amount, c.executionBinding.executionNonce]) uint(n, 256, true);
  for (const n of [c.lifecycleBinding.saleCreatedAt, c.lifecycleBinding.saleAdapterRegistryRevision, c.lifecycleBinding.paymentAdapterRegistryRevision]) uint(n, 64, true);
  return c;
}
export function erc20BurnMintExecutionId(chainId: bigint, candidate: ERC20SettlementCandidate): Hex {
  const c = normalizeERC20BurnMintCandidate(candidate);
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ERC20_SALE_EXECUTION_V1"), uint(chainId, 256, true), c.saleAdapter, c.sale.settlementId, c.sale.payer,
      c.executor, c.executionBinding.executionNonce, c.executionBinding.authorityMode, c.executionBinding.saleAuthorizationDigest,
      c.currentPolicyHash, c.boundPolicyHash, c.operationIdentityCommitment])) as Hex;
}
export function erc20BurnMintCandidateCommitment(chainId: bigint, paymentAdapter: Address, recorder: Address, candidate: ERC20SettlementCandidate): Hex {
  const c = normalizeERC20BurnMintCandidate(candidate);
  if (!same(c.lifecycleBinding.paymentAdapter, address(paymentAdapter))
    || !same(c.executionBinding.executionId, erc20BurnMintExecutionId(chainId, c))) throw Error("Candidate identity or payment adapter differs");
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", candidateTuple],
    [id("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2"), uint(chainId, 256, true), address(paymentAdapter), address(recorder), c])) as Hex;
}
/** Original universal settlement key preimage is shared without profile-specific normalization. */
export const erc20BurnMintSettlementKey = erc20PrimaryOfferSettlementKey;
