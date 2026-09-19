import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { PrimaryOfferSaleOffer, PrimaryOfferSellerAuthorization, PrimaryOfferSignature } from "./current-primary-offer-signing.js";
import { normalizePrimaryOfferSignature, primaryOfferBuyerRevocationPayload, primaryOfferSellerRevocationPayload } from "./current-primary-offer-signing.js";
import { paymentIntentRevocationTypedData } from "./signing.js";
import type { PaymentIntent } from "./signing.js";
import {
  normalizeERC20PrimaryOfferConfiguration, normalizeERC20PrimaryOfferAcceptance,
  normalizeERC20PrimaryOfferSaleOffer, normalizeERC20PrimaryOfferSellerAuthorization,
  normalizeERC20PrimaryOfferPaymentIntent, encodeERC20PrimaryOfferAcceptance,
  erc20PrimaryOfferConfigurationHash, erc20PrimaryOfferSaleId, erc20PrimaryOfferSigningSnapshot,
  erc20PrimaryOfferBuyerAuthorizationId, erc20PrimaryOfferSellerAuthorizationPayload,
  erc20PrimaryOfferPaymentIntentPayload,
} from "./current-erc20-primary-offer-signing.js";
import type { ERC20PrimaryOfferConfiguration, ERC20PrimaryOfferAcceptance, ERC20PrimaryOfferSigningSnapshot } from "./current-erc20-primary-offer-signing.js";
import { verifyCuratedContentProof } from "./current-curated-content.js";

export interface ERC20PrimarySale {
  readonly settlementId: Hex; readonly revenueClass: Hex; readonly policyMode: bigint;
  readonly collectionId: bigint; readonly tokenId: bigint; readonly saleNonce: bigint;
  readonly payer: Address; readonly poster: Address; readonly beneficiary: Address;
  readonly amount: bigint; readonly expectedPrimaryPolicyHash: Hex;
}
export interface ERC20SaleLifecycleBinding {
  readonly paymentAdapter: Address; readonly saleCreatedAt: bigint;
  readonly saleAdapterRegistryRevision: bigint; readonly paymentAdapterRegistryRevision: bigint;
}
export interface ERC20SaleExecutionBinding {
  readonly executionId: Hex; readonly executionNonce: bigint; readonly authorityMode: bigint;
  readonly saleAuthorizationDigest: Hex;
}
export interface ERC20PrimaryRights {
  readonly profileId: Hex; readonly wallet: Address; readonly templateId: Hex;
  readonly assignmentHash: Hex; readonly entriesHash: Hex;
}
/** The original order-one candidate. This atomic flow has no purchaseId. */
export interface ERC20SettlementCandidate {
  readonly saleAdapter: Address; readonly executor: Address; readonly sale: ERC20PrimarySale;
  readonly lifecycleBinding: ERC20SaleLifecycleBinding; readonly executionBinding: ERC20SaleExecutionBinding;
  readonly asset: Address; readonly orchestrationOrder: bigint; readonly mintManager: Address;
  readonly operationIdentityCommitment: Hex; readonly operationId: Hex;
  readonly currentPolicyHash: Hex; readonly boundPolicyHash: Hex; readonly rights: ERC20PrimaryRights;
  readonly saleExecutionHash: Hex;
}
export interface ERC20PrimarySettlementResult {
  readonly candidateCommitment: Hex; readonly settlementKey: Hex; readonly profileId: Hex;
  readonly wallet: Address; readonly asset: Address; readonly amount: bigint; readonly executor: Address;
  readonly executionId: Hex; readonly escrowed: boolean; readonly operationIdentityCommitment: Hex;
  readonly currentPolicyHash: Hex; readonly boundPolicyHash: Hex;
}
export interface ERC20PrimaryOfferSaleRecord {
  readonly config: ERC20PrimaryOfferConfiguration; readonly saleNonce: bigint; readonly configHash: Hex;
  readonly lifecycle: ERC20SaleLifecycleBinding; readonly artistId: Hex; readonly bindingGeneration: bigint;
  readonly bindingHash: Hex; readonly gate: Address; readonly gateCodeHash: Hex; readonly gateConfigHash: Hex;
  readonly manifestHash: Hex; readonly contentCounterId: Hex; readonly contentCounterConfigHash: Hex;
  readonly status: bigint;
}
export interface ERC20PrimaryOfferExecutionRecord {
  readonly saleId: Hex; readonly buyer: Address; readonly executor: Address; readonly executionNonce: bigint;
  readonly offerDigest: Hex; readonly authorizationDigest: Hex; readonly authorizationId: Hex;
  readonly contentLeaf: Hex; readonly tokenDataHash: Hex; readonly tokenId: bigint;
  readonly settlementKey: Hex; readonly operationRoot: Hex; readonly operationId: Hex;
}
export interface PreparedERC20PrimaryOfferRegistration {
  readonly chainId: bigint; readonly adapter: Address; readonly caller: Address; readonly expectedNonce: bigint;
  readonly configuration: ERC20PrimaryOfferConfiguration; readonly selectedProof: readonly Hex[];
  readonly expectedSaleId: Hex; readonly configurationHash: Hex; readonly call: UnsignedCall;
}
export interface PreparedERC20PrimaryOfferAcceptance {
  readonly chainId: bigint; readonly adapter: Address; readonly core: Address; readonly manager: Address;
  readonly recorder: Address; readonly caller: Address; readonly configuration: ERC20PrimaryOfferConfiguration;
  readonly acceptance: ERC20PrimaryOfferAcceptance; readonly signing: ERC20PrimaryOfferSigningSnapshot;
  readonly saleExecutionData: Hex; readonly previewCall: UnsignedCall;
}
export interface ERC20EIP2612Permit { readonly deadline: bigint; readonly v: bigint; readonly r: Hex; readonly s: Hex }
export interface ERC20Permit2Transfer { readonly nonce: bigint; readonly deadline: bigint; readonly signature: Hex }
export type ERC20PrimaryOfferFundingRoute =
  | { readonly kind: "payer" }
  | { readonly kind: "intent"; readonly intent: PaymentIntent; readonly signature: Hex }
  | { readonly kind: "eip2612"; readonly permit: ERC20EIP2612Permit }
  | { readonly kind: "permit2"; readonly permit: ERC20Permit2Transfer };
export interface PreparedERC20PrimaryOfferFunding {
  readonly caller: Address;
  readonly prepared: PreparedERC20PrimaryOfferAcceptance; readonly candidate: ERC20SettlementCandidate;
  readonly route: ERC20PrimaryOfferFundingRoute; readonly candidateCommitment: Hex;
  readonly settlementKey: Hex; readonly call: UnsignedCall;
}
export interface PreparedERC20PrimaryOfferAction {
  readonly target: Address; readonly caller: Address; readonly method: string;
  readonly args: readonly unknown[]; readonly call: UnsignedCall;
}
export interface PreparedERC20PrimaryOfferBuyerRevocation {
  readonly chainId: bigint; readonly manager: Address; readonly ledger: Address; readonly caller: Address;
  readonly offer: PrimaryOfferSaleOffer; readonly buyerKind: bigint; readonly signature: Hex;
  readonly authorizationId: Hex; readonly payload: ReturnType<typeof primaryOfferBuyerRevocationPayload>;
  readonly call: UnsignedCall;
}
export interface PreparedERC20PrimaryOfferSellerRevocation {
  readonly chainId: bigint; readonly adapter: Address; readonly caller: Address;
  readonly configuration: ERC20PrimaryOfferConfiguration; readonly authorization: PrimaryOfferSellerAuthorization;
  readonly proof: PrimaryOfferSignature; readonly authorizationDigest: Hex;
  readonly payload: ReturnType<typeof primaryOfferSellerRevocationPayload>; readonly call: UnsignedCall;
}
export interface ERC20PrimaryOfferPaymentRevocation { readonly payer: Address; readonly nonce: Hex; readonly deadline: bigint }
export interface PreparedERC20PrimaryOfferPaymentRevocation {
  readonly chainId: bigint; readonly paymentAdapter: Address; readonly caller: Address;
  readonly revocation: ERC20PrimaryOfferPaymentRevocation; readonly signature: Hex | null;
  readonly payload: ReturnType<typeof paymentIntentRevocationTypedData>; readonly call: UnsignedCall;
}

const coder = AbiCoder.defaultAbiCoder();
const configTuple = "tuple(uint256 collectionId,bytes32 phaseId,address asset,address paymentAdapter,uint256 price,address poster,uint64 startsAt,uint64 endsAt,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 contentManifestRoot,address buyer,bytes32 offerDigest,bytes32 contentId,bytes32 tokenDataHash,address signer,uint8 signerKind,bytes32 signerEvidenceHash,uint64 signerRevision,address signerAuthority)";
const offerTuple = "tuple(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const authorizationTuple = "tuple(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const signatureTuple = "tuple(address authorizer,uint8 kind,bytes signature)";
const selectionTuple = "tuple(tuple(bytes32 contentId,bytes32 tokenDataHash,bytes32[] proof) content,bytes tokenData,bytes32 mintCommitment,uint256 executionNonce)";
const witnessTuple = "tuple(bool walletWide,uint256 index)";
const acceptanceTuple = `tuple(${offerTuple} offer,${signatureTuple} buyerProof,${authorizationTuple} authorization,${signatureTuple} sellerProof,${selectionTuple} selection,${witnessTuple} signerDelegation,${witnessTuple} executorDelegation)`;
const primarySaleTuple = "tuple(bytes32 settlementId,bytes32 revenueClass,uint8 policyMode,uint256 collectionId,uint256 tokenId,uint256 saleNonce,address payer,address poster,address beneficiary,uint256 amount,bytes32 expectedPrimaryPolicyHash)";
const lifecycleTuple = "tuple(address paymentAdapter,uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision,uint64 paymentAdapterRegistryRevision)";
const executionBindingTuple = "tuple(bytes32 executionId,uint256 executionNonce,uint8 authorityMode,bytes32 saleAuthorizationDigest)";
const rightsTuple = "tuple(bytes32 profileId,address wallet,bytes32 templateId,bytes32 assignmentHash,bytes32 entriesHash)";
const candidateTuple = `tuple(address saleAdapter,address executor,${primarySaleTuple} sale,${lifecycleTuple} lifecycleBinding,${executionBindingTuple} executionBinding,address asset,uint8 orchestrationOrder,address mintManager,bytes32 operationIdentityCommitment,bytes32 operationId,bytes32 currentPolicyHash,bytes32 boundPolicyHash,${rightsTuple} rights,bytes32 saleExecutionHash)`;
const resultTuple = "tuple(bytes32 candidateCommitment,bytes32 settlementKey,bytes32 profileId,address wallet,address asset,uint256 amount,address executor,bytes32 executionId,bool escrowed,bytes32 operationIdentityCommitment,bytes32 currentPolicyHash,bytes32 boundPolicyHash)";
const recordTuple = `tuple(${configTuple} config,uint256 saleNonce,bytes32 configHash,${lifecycleTuple} lifecycle,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address gate,bytes32 gateCodeHash,bytes32 gateConfigHash,bytes32 manifestHash,bytes32 contentCounterId,bytes32 contentCounterConfigHash,uint8 status)`;
const executionTuple = "tuple(bytes32 saleId,address buyer,address executor,uint256 executionNonce,bytes32 offerDigest,bytes32 authorizationDigest,bytes32 authorizationId,bytes32 contentLeaf,bytes32 tokenDataHash,uint256 tokenId,bytes32 settlementKey,bytes32 operationRoot,bytes32 operationId)";
const intentTuple = "tuple(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)";
const revocationTuple = "tuple(address payer,bytes32 nonce,uint64 deadline)";
const eip2612Tuple = "tuple(uint256 deadline,uint8 v,bytes32 r,bytes32 s)";
const permit2Tuple = "tuple(uint256 nonce,uint256 deadline,bytes signature)";
const carrierAbi = new Interface([
  `function registerPrimaryOffer(${configTuple},bytes32[]) returns (bytes32)`,
  `function primaryOfferConfigurationHash(${configTuple}) view returns (bytes32)`,
  `function primaryOfferConfiguration(bytes32) view returns (${configTuple})`,
  `function previewExecution(${acceptanceTuple}) view returns (${candidateTuple})`,
  `function saleRecord(bytes32) view returns (${recordTuple})`,
  `function executionRecord(bytes32) view returns (${executionTuple})`,
  "function primaryOfferAuthorizationBinding(bytes32) view returns (uint256,bytes32,address,uint8,bytes32)",
  "function primaryOfferSettlementBinding(bytes32) view returns (uint256,address,bytes32)",
  "function configureCollectionSigner(uint256,address,uint8,bytes32,bool)",
  "function collectionSigner(uint256,address,uint8) view returns (tuple(bytes32 evidenceHash,uint64 revision,bool enabled,address authority))",
  `function offerDigest(${offerTuple}) view returns (bytes32)`,
  `function authorizationDigest(${authorizationTuple}) view returns (bytes32)`,
  `function revokeAuthorization(${authorizationTuple},${signatureTuple})`,
  "function nextSaleNonce() view returns (uint256)",
  "function saleIdFor(uint256,bytes32,uint256) view returns (bytes32)",
  "function nextExecutionNonce(bytes32,address) view returns (uint256)",
  "function digestConsumed(bytes32) view returns (bool)", "function digestRevoked(bytes32) view returns (bool)",
  "function core() view returns (address)", "function mintManager() view returns (address)",
  "function primarySaleSettlement() view returns (address)", "function owner() view returns (address)",
  "function cancelPrimaryOffer(bytes32)", "function expirePrimaryOffer(bytes32)",
  "function setPaused(bool,bytes32)", "function setSalePaused(bytes32,bool,bytes32)",
  "function syncCollectionContest(uint256)", "function raiseGasParameter(bytes32,uint256)",
  "function transferOwnership(address)", "function renounceOwnership()",
  `event PrimaryOfferExecution(bytes32 indexed executionId,${executionTuple} execution)`,
]);
const paymentAbi = new Interface([
  `function settleERC20PrimarySaleByPayer(${candidateTuple},bytes) returns (${resultTuple})`,
  `function settleERC20PrimarySaleWithIntent(${candidateTuple},${intentTuple},bytes,bytes) returns (${resultTuple})`,
  `function settleERC20PrimarySaleWithEIP2612Permit(${candidateTuple},${eip2612Tuple},bytes) returns (${resultTuple})`,
  `function settleERC20PrimarySaleWithPermit2(${candidateTuple},${permit2Tuple},bytes) returns (${resultTuple})`,
  "function core() view returns (address)", "function primarySaleSettlement() view returns (address)",
  "function isPaymentIntentNonceUsed(address,bytes32) view returns (bool)",
  `function paymentIntentDigest(${intentTuple}) view returns (bytes32)`,
  `function paymentIntentRevocationDigest(${revocationTuple}) view returns (bytes32)`,
  "function revokePaymentIntent(bytes32)", `function revokePaymentIntentWithSignature(${revocationTuple},bytes)`,
]);
const managerAbi = new Interface([
  `function voidMintOffer(${offerTuple},uint8,bytes) returns (bytes32)`,
  `function mintOfferAuthorizationId(${offerTuple}) view returns (bytes32)`,
  "function isAuthorizationUsed(bytes32) view returns (bool)", "function core() view returns (address)",
  "function mintLedger() view returns (address)",
]);
const recorderAbi = new Interface([
  "function core() view returns (address)", "function settlementConsumed(bytes32) view returns (bool)",
  `function settlementResult(bytes32) view returns (${resultTuple})`,
]);
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns (bool success)"]);
const tokenAbi = new Interface(["function approve(address,uint256) returns (bool)"]);
const MAX_RPC_BYTES = 262_144;
type Reader = Pick<Provider, "getNetwork" | "call">;
type BlockOptions = { readonly blockTag: number };

function exact(value: unknown, keys: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || Object.keys(value).sort().join() !== [...keys].sort().join()) throw Error(`${label} has missing or unknown properties`);
}
function uint(value: unknown, bits = 256, positive = false): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits) || (positive && value === 0n)) throw Error(`Expected ${positive ? "positive " : ""}uint${bits} bigint`);
  return value;
}
function addr(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const out = getAddress(value) as Address; if (!zero && out === ZeroAddress) throw Error("Zero address"); return out;
}
function hash(value: unknown, zero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (!zero && value.toLowerCase() === ZeroHash)) throw Error("Expected nonzero bytes32");
  return value.toLowerCase() as Hex;
}
function bytes(value: unknown, max = 65_536): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > max) throw Error("Malformed or oversized bytes"); return value.toLowerCase() as Hex;
}
function bool(value: unknown): boolean { if (typeof value !== "boolean") throw Error("Expected boolean"); return value; }
function same(a: unknown, b: unknown): boolean { return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase(); }
function render(value: unknown): string { return JSON.stringify(value, (_, v: unknown) => typeof v === "bigint" ? `${v}n` : v); }
function equal(a: unknown, b: unknown, message: string): void { if (render(a) !== render(b)) throw Error(message); }
function block(value: number): number { if (!Number.isSafeInteger(value) || value < 0) throw Error("A concrete nonnegative blockTag is required"); return value; }
function tuple(param: ParamType, value: unknown, decoded = false): unknown {
  if (param.baseType === "tuple") {
    const components = param.components!;
    if (!decoded) exact(value, components.map(p => p.name), "ABI tuple");
    return Object.freeze(Object.fromEntries(components.map((p, i) => [p.name, tuple(p, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[p.name], decoded)])));
  }
  if (param.baseType === "array") {
    if (!Array.isArray(value) || value.length > 256) throw Error("Oversized or malformed ABI array");
    return Object.freeze(value.map(v => tuple(param.arrayChildren!, v, decoded)));
  }
  if (param.type.startsWith("uint")) return uint(value, Number(param.type.slice(4)));
  if (param.type === "address") return addr(value, true);
  if (param.type === "bytes32") return hash(value, true);
  if (param.type === "bool") return bool(value);
  if (param.type === "bytes") return bytes(value);
  throw Error("Unsupported ABI scalar");
}
function normalize<T>(shape: string, value: unknown, decoded = false): T { return tuple(ParamType.from(shape), value, decoded) as T; }
function call(target: Address, abi: Interface, method: string, args: readonly unknown[]): UnsignedCall {
  return Object.freeze({ to: addr(target), value: 0n, data: abi.encodeFunctionData(method, args) as Hex });
}
async function rpc(provider: Pick<Provider, "call">, target: Address, abi: Interface, method: string, args: readonly unknown[], tag: number, exactBytes: number): Promise<readonly unknown[]> {
  const raw = bytes(await provider.call({ ...call(target, abi, method, args), blockTag: tag }), MAX_RPC_BYTES);
  if ((raw.length - 2) / 2 !== exactBytes) throw Error(`Malformed ${method} return length`);
  const decoded = abi.decodeFunctionResult(method, raw);
  if (!same(abi.encodeFunctionResult(method, decoded), raw)) throw Error(`Noncanonical ${method} return`);
  return decoded;
}
async function network(provider: Pick<Provider, "getNetwork">, chainId: bigint): Promise<void> {
  if ((await provider.getNetwork()).chainId !== chainId) throw Error("RPC chain differs from reviewed coordinates");
}

export function normalizeERC20SettlementCandidate(value: ERC20SettlementCandidate): ERC20SettlementCandidate {
  const c = normalize<ERC20SettlementCandidate>(candidateTuple, value);
  for (const a of [c.saleAdapter, c.executor, c.asset, c.mintManager, c.sale.payer, c.sale.poster, c.sale.beneficiary, c.lifecycleBinding.paymentAdapter, c.rights.wallet]) addr(a);
  for (const h of [c.sale.settlementId, c.sale.expectedPrimaryPolicyHash, c.executionBinding.saleAuthorizationDigest, c.operationIdentityCommitment, c.operationId, c.currentPolicyHash, c.boundPolicyHash, c.rights.profileId, c.rights.assignmentHash, c.rights.entriesHash, c.saleExecutionHash]) hash(h);
  if (c.orchestrationOrder !== 1n || c.executionBinding.authorityMode !== 1n || c.sale.policyMode !== 0n || c.sale.tokenId !== 0n || !same(c.sale.revenueClass, id("PRIMARY_SALE")) || c.rights.templateId !== ZeroHash || !same(c.sale.payer, c.sale.beneficiary)) throw Error("Unsupported order-one strict PROFILE primary candidate");
  uint(c.sale.collectionId, 256, true); uint(c.sale.saleNonce, 256, true); uint(c.sale.amount, 256, true);
  uint(c.executionBinding.executionNonce, 256, true);
  for (const n of [c.lifecycleBinding.saleCreatedAt, c.lifecycleBinding.saleAdapterRegistryRevision, c.lifecycleBinding.paymentAdapterRegistryRevision]) uint(n, 64, true);
  return c;
}
export function erc20PrimaryOfferExecutionId(chainId: bigint, candidate: ERC20SettlementCandidate): Hex {
  const c = normalizeERC20SettlementCandidate(candidate);
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", "bytes32", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ERC20_SALE_EXECUTION_V1"), uint(chainId, 256, true), c.saleAdapter, c.sale.settlementId, c.sale.payer, c.executor, c.executionBinding.executionNonce, c.executionBinding.authorityMode, c.executionBinding.saleAuthorizationDigest, c.currentPolicyHash, c.boundPolicyHash, c.operationIdentityCommitment],
  )) as Hex;
}
export function erc20PrimaryOfferCandidateCommitment(chainId: bigint, paymentAdapter: Address, recorder: Address, candidate: ERC20SettlementCandidate): Hex {
  const c = normalizeERC20SettlementCandidate(candidate);
  if (!same(c.lifecycleBinding.paymentAdapter, addr(paymentAdapter)) || !same(c.executionBinding.executionId, erc20PrimaryOfferExecutionId(chainId, c))) throw Error("Candidate identity or payment adapter differs");
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", candidateTuple], [id("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2"), uint(chainId, 256, true), addr(paymentAdapter), addr(recorder), c])) as Hex;
}
export function erc20PrimaryOfferSettlementKey(chainId: bigint, recorder: Address, adapter: Address, executionId: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32"], [id("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2"), uint(chainId, 256, true), addr(recorder), addr(adapter), hash(executionId)])) as Hex;
}

export function prepareERC20PrimaryOfferRegistration(chainId: bigint, adapter: Address, caller: Address, expectedNonce: bigint, configuration: ERC20PrimaryOfferConfiguration, selectedProof: readonly Hex[]): PreparedERC20PrimaryOfferRegistration {
  const c = normalizeERC20PrimaryOfferConfiguration(configuration);
  const chain = uint(chainId, 256, true); const host = addr(adapter); const nonce = uint(expectedNonce, 256, true);
  const saleId = erc20PrimaryOfferSaleId(chain, host, c.collectionId, c.phaseId, nonce);
  if (!Array.isArray(selectedProof) || selectedProof.length > 256) throw Error("Invalid selected registration proof");
  const proof = Object.freeze(selectedProof.map(p => hash(p, true)));
  if (c.contentManifestRoot === ZeroHash ? proof.length !== 0 : !verifyCuratedContentProof(chain, host, saleId, c.contentManifestRoot, { contentId: c.contentId, tokenDataHash: c.tokenDataHash, proof })) throw Error("Registration proof differs from selected content");
  return Object.freeze({ chainId: chain, adapter: host, caller: addr(caller), expectedNonce: nonce, configuration: c, selectedProof: proof, expectedSaleId: saleId, configurationHash: erc20PrimaryOfferConfigurationHash(chain, host, c), call: call(host, carrierAbi, "registerPrimaryOffer", [c, proof]) });
}
function registration(value: PreparedERC20PrimaryOfferRegistration): PreparedERC20PrimaryOfferRegistration {
  const p = prepareERC20PrimaryOfferRegistration(value.chainId, value.adapter, value.caller, value.expectedNonce, value.configuration, value.selectedProof);
  equal(value, p, "Registration plan differs from canonical reconstruction"); return p;
}
export async function inspectERC20PrimaryOfferRegistration(provider: Reader, input: PreparedERC20PrimaryOfferRegistration, options: BlockOptions): Promise<PreparedERC20PrimaryOfferRegistration> {
  const p = registration(input); const tag = block(options.blockTag); await network(provider, p.chainId);
  const [[owner], [nonce], [saleId], [configHash], [signer]] = await Promise.all([
    rpc(provider, p.adapter, carrierAbi, "owner", [], tag, 32),
    rpc(provider, p.adapter, carrierAbi, "nextSaleNonce", [], tag, 32),
    rpc(provider, p.adapter, carrierAbi, "saleIdFor", [p.configuration.collectionId, p.configuration.phaseId, p.expectedNonce], tag, 32),
    rpc(provider, p.adapter, carrierAbi, "primaryOfferConfigurationHash", [p.configuration], tag, 32),
    rpc(provider, p.adapter, carrierAbi, "collectionSigner", [p.configuration.collectionId, p.configuration.signer, p.configuration.signerKind], tag, 128),
  ]);
  const s = normalize<{ evidenceHash: Hex; revision: bigint; enabled: boolean; authority: Address }>("tuple(bytes32 evidenceHash,uint64 revision,bool enabled,address authority)", signer, true);
  if (!same(owner, p.caller) || nonce !== p.expectedNonce || !same(saleId, p.expectedSaleId) || !same(configHash, p.configurationHash) || !s.enabled || s.revision !== p.configuration.signerRevision || !same(s.evidenceHash, p.configuration.signerEvidenceHash) || !same(s.authority, p.configuration.signerAuthority)) throw Error("Registration nonce, owner, configuration, or current signer differs");
  return p;
}
export async function simulateERC20PrimaryOfferRegistration(provider: Reader, input: PreparedERC20PrimaryOfferRegistration, options: BlockOptions): Promise<Hex> {
  const tag = block(options.blockTag); const p = await inspectERC20PrimaryOfferRegistration(provider, input, { blockTag: tag });
  const raw = bytes(await provider.call({ ...p.call, from: p.caller, blockTag: tag }), 32);
  if (!same(raw, p.expectedSaleId)) throw Error("Registration simulation returned unexpected saleId"); return p.expectedSaleId;
}

export function prepareERC20PrimaryOfferAcceptance(chainId: bigint, adapter: Address, core: Address, manager: Address, recorder: Address, caller: Address, configuration: ERC20PrimaryOfferConfiguration, acceptance: ERC20PrimaryOfferAcceptance): PreparedERC20PrimaryOfferAcceptance {
  const chain = uint(chainId, 256, true); const host = addr(adapter); const c = normalizeERC20PrimaryOfferConfiguration(configuration); const q = normalizeERC20PrimaryOfferAcceptance(acceptance);
  const coreAddress = addr(core); const managerAddress = addr(manager); const recorderAddress = addr(recorder); const executor = addr(caller);
  const signing = erc20PrimaryOfferSigningSnapshot(chain, host, coreAddress, managerAddress, c, q.authorization.saleId, q.offer, q.authorization, q.selection.tokenData, q.selection.mintCommitment);
  if (!same(q.authorization.executor, executor) || !same(q.sellerProof.authorizer, c.signer) || q.sellerProof.kind !== c.signerKind || same(c.buyer, c.paymentAdapter) || same(c.buyer, recorderAddress)) throw Error("Acceptance caller, seller membership, or payer binding differs");
  if (signing.selected ? !same(q.selection.content.contentId, c.contentId) || !same(q.selection.content.tokenDataHash, c.tokenDataHash) || !verifyCuratedContentProof(chain, host, signing.saleId, c.contentManifestRoot, q.selection.content) : q.selection.content.contentId !== ZeroHash || q.selection.content.tokenDataHash !== ZeroHash || q.selection.content.proof.length !== 0) throw Error("Acceptance selected content proof differs");
  const data = encodeERC20PrimaryOfferAcceptance(q);
  return Object.freeze({ chainId: chain, adapter: host, core: coreAddress, manager: managerAddress, recorder: recorderAddress, caller: executor, configuration: c, acceptance: q, signing, saleExecutionData: data, previewCall: call(host, carrierAbi, "previewExecution", [q]) });
}
function acceptance(value: PreparedERC20PrimaryOfferAcceptance): PreparedERC20PrimaryOfferAcceptance {
  const p = prepareERC20PrimaryOfferAcceptance(value.chainId, value.adapter, value.core, value.manager, value.recorder, value.caller, value.configuration, value.acceptance);
  equal(value, p, "Acceptance plan differs from canonical reconstruction"); return p;
}
function bindCandidate(p: PreparedERC20PrimaryOfferAcceptance, input: ERC20SettlementCandidate): ERC20SettlementCandidate {
  const c = normalizeERC20SettlementCandidate(input); const t = p.configuration; const q = p.acceptance;
  if (!same(c.saleAdapter, p.adapter) || !same(c.executor, p.caller) || !same(c.asset, t.asset) || !same(c.mintManager, p.manager) || !same(c.lifecycleBinding.paymentAdapter, t.paymentAdapter) || !same(c.sale.settlementId, p.signing.saleId) || c.sale.collectionId !== t.collectionId || !same(c.sale.payer, t.buyer) || !same(c.sale.poster, t.poster) || c.sale.amount !== t.price || !same(c.sale.expectedPrimaryPolicyHash, t.expectedPrimaryPolicyHash) || !same(c.boundPolicyHash, t.mintPolicyHash) || c.executionBinding.executionNonce !== q.selection.executionNonce || !same(c.executionBinding.saleAuthorizationDigest, p.signing.sellerReplayDigest) || !same(c.saleExecutionHash, keccak256(p.saleExecutionData)) || !same(c.executionBinding.executionId, erc20PrimaryOfferExecutionId(p.chainId, c))) throw Error("Candidate differs from the complete reviewed acceptance");
  return c;
}
async function dependencies(provider: Pick<Provider, "call">, p: PreparedERC20PrimaryOfferAcceptance, tag: number): Promise<void> {
  const [[core], [manager], [recorder], [paymentCore], [paymentRecorder], [managerCore], [recorderCore]] = await Promise.all([
    rpc(provider, p.adapter, carrierAbi, "core", [], tag, 32), rpc(provider, p.adapter, carrierAbi, "mintManager", [], tag, 32), rpc(provider, p.adapter, carrierAbi, "primarySaleSettlement", [], tag, 32),
    rpc(provider, p.configuration.paymentAdapter, paymentAbi, "core", [], tag, 32), rpc(provider, p.configuration.paymentAdapter, paymentAbi, "primarySaleSettlement", [], tag, 32),
    rpc(provider, p.manager, managerAbi, "core", [], tag, 32), rpc(provider, p.recorder, recorderAbi, "core", [], tag, 32),
  ]);
  if (!same(core, p.core) || !same(manager, p.manager) || !same(recorder, p.recorder) || !same(paymentCore, p.core) || !same(paymentRecorder, p.recorder) || !same(managerCore, p.core) || !same(recorderCore, p.core)) throw Error("Carrier, Manager, recorder, or contract20 deployment binding differs");
}
async function readBoundSale(provider: Pick<Provider, "call">, p: PreparedERC20PrimaryOfferAcceptance, tag: number, status: bigint): Promise<ERC20PrimaryOfferSaleRecord> {
  const [[raw], binding] = await Promise.all([rpc(provider, p.adapter, carrierAbi, "saleRecord", [p.signing.saleId], tag, 1184), rpc(provider, p.adapter, carrierAbi, "primaryOfferSettlementBinding", [p.signing.saleId], tag, 96)]);
  const s = normalize<ERC20PrimaryOfferSaleRecord>(recordTuple, raw, true);
  equal(normalizeERC20PrimaryOfferConfiguration(s.config), p.configuration, "Stored immutable configuration differs");
  const expectedHash = erc20PrimaryOfferConfigurationHash(p.chainId, p.adapter, p.configuration);
  if (s.status !== status || !same(s.configHash, expectedHash) || !same(erc20PrimaryOfferSaleId(p.chainId, p.adapter, s.config.collectionId, s.config.phaseId, s.saleNonce), p.signing.saleId) || !same(s.lifecycle.paymentAdapter, p.configuration.paymentAdapter) || binding[0] !== s.saleNonce || !same(binding[1], p.configuration.poster) || !same(binding[2], expectedHash)) throw Error("Stored sale status or historical settlement binding differs");
  return s;
}
/** Live permissions, Artist consent, phase/gate/counter, ACTIVE asset and zero fee are checked by preview. */
export async function inspectERC20PrimaryOfferAcceptance(provider: Reader, input: PreparedERC20PrimaryOfferAcceptance, options: BlockOptions): Promise<ERC20SettlementCandidate> {
  const p = acceptance(input); const tag = block(options.blockTag); await network(provider, p.chainId);
  const [record, , [nonce], [used], [consumed], [raw]] = await Promise.all([
    readBoundSale(provider, p, tag, 1n), dependencies(provider, p, tag),
    rpc(provider, p.adapter, carrierAbi, "nextExecutionNonce", [p.signing.saleId, p.configuration.buyer], tag, 32),
    rpc(provider, p.manager, managerAbi, "isAuthorizationUsed", [p.signing.buyerAuthorizationId], tag, 32),
    rpc(provider, p.adapter, carrierAbi, "digestConsumed", [p.signing.sellerReplayDigest], tag, 32),
    rpc(provider, p.adapter, carrierAbi, "previewExecution", [p.acceptance], tag, 1088),
  ]);
  if (nonce !== p.acceptance.selection.executionNonce || used !== false || consumed !== false) throw Error("Offer execution nonce or independent replay state is unavailable");
  const c = bindCandidate(p, normalize<ERC20SettlementCandidate>(candidateTuple, raw, true));
  if (c.sale.saleNonce !== record.saleNonce) throw Error("Candidate sale nonce differs");
  equal(c.lifecycleBinding, record.lifecycle, "Candidate lifecycle differs from registered sale"); return c;
}

function route(value: ERC20PrimaryOfferFundingRoute): ERC20PrimaryOfferFundingRoute {
  if (value.kind === "payer") { exact(value, ["kind"], "funding route"); return Object.freeze({ kind: "payer" }); }
  if (value.kind === "intent") { exact(value, ["kind", "intent", "signature"], "funding route"); return Object.freeze({ kind: "intent", intent: normalizeERC20PrimaryOfferPaymentIntent(value.intent), signature: bytes(value.signature) }); }
  if (value.kind === "eip2612") { exact(value, ["kind", "permit"], "funding route"); const permit = normalize<ERC20EIP2612Permit>(eip2612Tuple, value.permit); if (permit.v !== 27n && permit.v !== 28n) throw Error("EIP2612 v must be 27 or 28"); hash(permit.r); hash(permit.s); return Object.freeze({ kind: "eip2612", permit }); }
  if (value.kind === "permit2") { exact(value, ["kind", "permit"], "funding route"); return Object.freeze({ kind: "permit2", permit: normalize<ERC20Permit2Transfer>(permit2Tuple, value.permit) }); }
  throw Error("Unknown ERC20 offer funding route");
}
function fundingMethod(kind: ERC20PrimaryOfferFundingRoute["kind"]): string {
  return { payer: "settleERC20PrimarySaleByPayer", intent: "settleERC20PrimarySaleWithIntent", eip2612: "settleERC20PrimarySaleWithEIP2612Permit", permit2: "settleERC20PrimarySaleWithPermit2" }[kind];
}
export function prepareERC20PrimaryOfferFunding(input: PreparedERC20PrimaryOfferAcceptance, candidateInput: ERC20SettlementCandidate, routeInput: ERC20PrimaryOfferFundingRoute): PreparedERC20PrimaryOfferFunding {
  const p = acceptance(input); const c = bindCandidate(p, candidateInput); const r = route(routeInput);
  if (r.kind !== "intent" && !same(p.caller, p.configuration.buyer)) throw Error("Direct and permit routes require the actual contract20 caller to be the buyer/payer");
  if (r.kind === "intent") erc20PrimaryOfferPaymentIntentPayload(p.chainId, p.configuration, p.signing.saleId, r.intent);
  const args = r.kind === "payer" ? [c, p.saleExecutionData] : r.kind === "intent" ? [c, r.intent, r.signature, p.saleExecutionData] : [c, r.permit, p.saleExecutionData];
  return Object.freeze({ caller: p.caller, prepared: p, candidate: c, route: r, candidateCommitment: erc20PrimaryOfferCandidateCommitment(p.chainId, p.configuration.paymentAdapter, p.recorder, c), settlementKey: erc20PrimaryOfferSettlementKey(p.chainId, p.recorder, p.adapter, c.executionBinding.executionId), call: call(p.configuration.paymentAdapter, paymentAbi, fundingMethod(r.kind), args) });
}
function funding(value: PreparedERC20PrimaryOfferFunding): PreparedERC20PrimaryOfferFunding {
  const p = prepareERC20PrimaryOfferFunding(value.prepared, value.candidate, value.route); equal(value, p, "Funding plan differs from canonical reconstruction"); return p;
}
function checkedResult(p: PreparedERC20PrimaryOfferFunding, value: unknown, decoded = false): ERC20PrimarySettlementResult {
  const r = normalize<ERC20PrimarySettlementResult>(resultTuple, value, decoded); const c = p.candidate;
  if (!same(r.candidateCommitment, p.candidateCommitment) || !same(r.settlementKey, p.settlementKey) || !same(r.profileId, c.rights.profileId) || !same(r.wallet, c.rights.wallet) || !same(r.asset, c.asset) || r.amount !== c.sale.amount || !same(r.executor, c.executor) || !same(r.executionId, c.executionBinding.executionId) || !same(r.operationIdentityCommitment, c.operationIdentityCommitment) || !same(r.currentPolicyHash, c.currentPolicyHash) || !same(r.boundPolicyHash, c.boundPolicyHash)) throw Error("Official settlement result differs from candidate"); return r;
}
export async function simulateERC20PrimaryOfferFunding(provider: Reader, input: PreparedERC20PrimaryOfferFunding, options: BlockOptions): Promise<ERC20PrimarySettlementResult> {
  const p = funding(input); const tag = block(options.blockTag);
  const current = await inspectERC20PrimaryOfferAcceptance(provider, p.prepared, { blockTag: tag }); equal(current, p.candidate, "Candidate changed since preparation");
  if (p.route.kind === "intent") {
    const [[used], [digest]] = await Promise.all([
      rpc(provider, p.prepared.configuration.paymentAdapter, paymentAbi, "isPaymentIntentNonceUsed", [p.route.intent.payer, p.route.intent.nonce], tag, 32),
      rpc(provider, p.prepared.configuration.paymentAdapter, paymentAbi, "paymentIntentDigest", [p.route.intent], tag, 32),
    ]);
    if (used !== false || !same(digest, erc20PrimaryOfferPaymentIntentPayload(p.prepared.chainId, p.prepared.configuration, p.prepared.signing.saleId, p.route.intent).digest)) throw Error("PaymentIntent nonce or original digest differs");
  }
  const raw = bytes(await provider.call({ ...p.call, from: p.prepared.caller, blockTag: tag }), 384);
  if ((raw.length - 2) / 2 !== 384) throw Error("Settlement simulation must return exactly 384 bytes");
  const result = paymentAbi.decodeFunctionResult(fundingMethod(p.route.kind), raw);
  if (!same(paymentAbi.encodeFunctionResult(fundingMethod(p.route.kind), result), raw)) throw Error("Noncanonical settlement simulation");
  return checkedResult(p, result[0], true);
}

export async function readERC20PrimaryOfferExecution(provider: Pick<Provider, "call">, adapter: Address, executionId: Hex, options: BlockOptions): Promise<ERC20PrimaryOfferExecutionRecord> {
  const target = addr(adapter); const key = hash(executionId); const tag = block(options.blockTag);
  const [raw] = await rpc(provider, target, carrierAbi, "executionRecord", [key], tag, 416); return normalize(executionTuple, raw, true);
}
export async function readERC20PrimaryOfferSettlementBinding(provider: Pick<Provider, "call">, adapter: Address, saleId: Hex, options: BlockOptions): Promise<{ readonly saleNonce: bigint; readonly poster: Address; readonly configHash: Hex }> {
  const target = addr(adapter); const key = hash(saleId); const tag = block(options.blockTag);
  const [saleNonce, poster, configHash] = await rpc(provider, target, carrierAbi, "primaryOfferSettlementBinding", [key], tag, 96);
  return Object.freeze({ saleNonce: uint(saleNonce, 256, true), poster: addr(poster), configHash: hash(configHash) });
}
function checkedExecution(p: PreparedERC20PrimaryOfferFunding, value: ERC20PrimaryOfferExecutionRecord): ERC20PrimaryOfferExecutionRecord {
  const e = normalize<ERC20PrimaryOfferExecutionRecord>(executionTuple, value); const c = p.candidate; const a = p.prepared;
  if (!same(e.saleId, a.signing.saleId) || !same(e.buyer, a.configuration.buyer) || !same(e.executor, a.caller) || e.executionNonce !== c.executionBinding.executionNonce || !same(e.offerDigest, a.configuration.offerDigest) || !same(e.authorizationDigest, a.signing.sellerReplayDigest) || !same(e.authorizationId, a.signing.buyerAuthorizationId) || !same(e.contentLeaf, a.signing.contentSelectionHash) || !same(e.tokenDataHash, keccak256(a.acceptance.selection.tokenData)) || e.tokenId === 0n || !same(e.settlementKey, p.settlementKey) || !same(e.operationRoot, c.operationIdentityCommitment) || !same(e.operationId, c.operationId)) throw Error("Completed execution differs from reviewed acceptance and candidate"); return e;
}
export async function inspectCompletedERC20PrimaryOffer(provider: Reader, input: PreparedERC20PrimaryOfferFunding, options: BlockOptions): Promise<{ readonly record: ERC20PrimaryOfferSaleRecord; readonly execution: ERC20PrimaryOfferExecutionRecord; readonly settlement: ERC20PrimarySettlementResult }> {
  const p = funding(input); const a = p.prepared; const tag = block(options.blockTag); await network(provider, a.chainId);
  const [record, , execution, [buyerUsed], [sellerUsed], [sellerRevoked], [settled], [result]] = await Promise.all([
    readBoundSale(provider, a, tag, 4n), dependencies(provider, a, tag), readERC20PrimaryOfferExecution(provider, a.adapter, p.candidate.executionBinding.executionId, { blockTag: tag }),
    rpc(provider, a.manager, managerAbi, "isAuthorizationUsed", [a.signing.buyerAuthorizationId], tag, 32), rpc(provider, a.adapter, carrierAbi, "digestConsumed", [a.signing.sellerReplayDigest], tag, 32), rpc(provider, a.adapter, carrierAbi, "digestRevoked", [a.signing.sellerReplayDigest], tag, 32),
    rpc(provider, a.recorder, recorderAbi, "settlementConsumed", [p.settlementKey], tag, 32), rpc(provider, a.recorder, recorderAbi, "settlementResult", [p.settlementKey], tag, 384),
  ]);
  if (buyerUsed !== true || sellerUsed !== true || sellerRevoked !== false || settled !== true) throw Error("Completed execution replay or recorder state differs");
  if (record.saleNonce !== p.candidate.sale.saleNonce) throw Error("Completed sale nonce differs"); equal(record.lifecycle, p.candidate.lifecycleBinding, "Completed lifecycle differs");
  if (p.route.kind === "intent") {
    const [used] = await rpc(provider, a.configuration.paymentAdapter, paymentAbi, "isPaymentIntentNonceUsed", [p.route.intent.payer, p.route.intent.nonce], tag, 32);
    if (used !== true) throw Error("Completed buyer PaymentIntent nonce is not consumed");
  }
  return Object.freeze({ record, execution: checkedExecution(p, execution), settlement: checkedResult(p, result, true) });
}

/** Exact carrier writes, ready for toSafeCall. Authority and live preconditions require simulation. */
function action(adapter: Address, caller: Address, method: string, args: readonly unknown[]): PreparedERC20PrimaryOfferAction {
  const target = addr(adapter); const input = Object.freeze([...args]); return Object.freeze({ target, caller: addr(caller), method, args: input, call: call(target, carrierAbi, method, input) });
}
export function prepareERC20PrimaryOfferSignerConfiguration(adapter: Address, caller: Address, collectionId: bigint, signer: Address, signerKind: bigint, evidenceHash: Hex, enabled: boolean): PreparedERC20PrimaryOfferAction {
  if (signerKind !== 1n && signerKind !== 2n) throw Error("Explicit signer kind must be 1 or 2");
  return action(adapter, caller, "configureCollectionSigner", [uint(collectionId, 256, true), addr(signer), signerKind, hash(evidenceHash), bool(enabled)]);
}
export const prepareERC20PrimaryOfferCancel = (adapter: Address, caller: Address, saleId: Hex) => action(adapter, caller, "cancelPrimaryOffer", [hash(saleId)]);
export const prepareERC20PrimaryOfferExpire = (adapter: Address, caller: Address, saleId: Hex) => action(adapter, caller, "expirePrimaryOffer", [hash(saleId)]);
export const prepareERC20PrimaryOfferPause = (adapter: Address, caller: Address, paused: boolean, reason: Hex) => action(adapter, caller, "setPaused", [bool(paused), hash(reason)]);
export const prepareERC20PrimaryOfferSalePause = (adapter: Address, caller: Address, saleId: Hex, paused: boolean, reason: Hex) => action(adapter, caller, "setSalePaused", [hash(saleId), bool(paused), hash(reason)]);
export const prepareERC20PrimaryOfferContestSync = (adapter: Address, caller: Address, collectionId: bigint) => action(adapter, caller, "syncCollectionContest", [uint(collectionId, 256, true)]);
export const prepareERC20PrimaryOfferGasRaise = (adapter: Address, caller: Address, parameterId: Hex, newValue: bigint) => action(adapter, caller, "raiseGasParameter", [hash(parameterId), uint(newValue, 256, true)]);
export const prepareERC20PrimaryOfferOwnershipTransfer = (adapter: Address, caller: Address, nextOwner: Address) => action(adapter, caller, "transferOwnership", [addr(nextOwner)]);
export const prepareERC20PrimaryOfferOwnershipRenunciation = (adapter: Address, caller: Address) => action(adapter, caller, "renounceOwnership", []);
export function prepareERC20PrimaryOfferTokenApproval(asset: Address, buyer: Address, paymentAdapter: Address, amount: bigint): { readonly caller: Address; readonly call: UnsignedCall } {
  return Object.freeze({ caller: addr(buyer), call: call(addr(asset), tokenAbi, "approve", [addr(paymentAdapter), uint(amount)]) });
}
export async function simulateERC20PrimaryOfferAction(provider: Reader, chainId: bigint, input: PreparedERC20PrimaryOfferAction, options: BlockOptions): Promise<void> {
  const allowed = ["configureCollectionSigner", "cancelPrimaryOffer", "expirePrimaryOffer", "setPaused", "setSalePaused", "syncCollectionContest", "raiseGasParameter", "transferOwnership", "renounceOwnership"];
  if (!allowed.includes(input.method)) throw Error("Unknown public carrier action");
  const method = carrierAbi.getFunction(input.method)!;
  if (!Array.isArray(input.args) || input.args.length !== method.inputs.length) throw Error("Carrier action argument length differs");
  const args = method.inputs.map((p, i) => tuple(p, input.args[i]));
  const p = action(input.target, input.caller, input.method, args); equal(input, p, "Carrier action differs from canonical reconstruction");
  const chain = uint(chainId, 256, true); const tag = block(options.blockTag); await network(provider, chain);
  if (await provider.call({ ...p.call, from: p.caller, blockTag: tag }) !== "0x") throw Error("Carrier action returned unexpected bytes");
}

export function prepareERC20PrimaryOfferBuyerRevocation(chainId: bigint, adapter: Address, manager: Address, ledger: Address, caller: Address, offer: PrimaryOfferSaleOffer, buyerKind: bigint, signature: Hex): PreparedERC20PrimaryOfferBuyerRevocation {
  const chain = uint(chainId, 256, true); const host = addr(adapter); const managerAddress = addr(manager); const ledgerAddress = addr(ledger); const o = normalizeERC20PrimaryOfferSaleOffer(offer);
  if (buyerKind !== 1n && buyerKind !== 2n) throw Error("Buyer kind must be explicit 1 or 2");
  const sig = bytes(signature); const authorizationId = erc20PrimaryOfferBuyerAuthorizationId(chain, host, o);
  return Object.freeze({ chainId: chain, manager: managerAddress, ledger: ledgerAddress, caller: addr(caller), offer: o, buyerKind, signature: sig, authorizationId, payload: primaryOfferBuyerRevocationPayload(chain, host, managerAddress, ledgerAddress, authorizationId), call: call(managerAddress, managerAbi, "voidMintOffer", [o, buyerKind, sig]) });
}
function buyerRevocation(value: PreparedERC20PrimaryOfferBuyerRevocation): PreparedERC20PrimaryOfferBuyerRevocation {
  const p = prepareERC20PrimaryOfferBuyerRevocation(value.chainId, value.offer.saleAdapter, value.manager, value.ledger, value.caller, value.offer, value.buyerKind, value.signature); equal(value, p, "Buyer revocation plan differs"); return p;
}
export async function inspectERC20PrimaryOfferBuyerRevocation(provider: Reader, input: PreparedERC20PrimaryOfferBuyerRevocation, options: BlockOptions): Promise<PreparedERC20PrimaryOfferBuyerRevocation> {
  const p = buyerRevocation(input); const tag = block(options.blockTag); await network(provider, p.chainId);
  const [[authorizationId], [used], [core], [ledger]] = await Promise.all([
    rpc(provider, p.manager, managerAbi, "mintOfferAuthorizationId", [p.offer], tag, 32), rpc(provider, p.manager, managerAbi, "isAuthorizationUsed", [p.authorizationId], tag, 32), rpc(provider, p.manager, managerAbi, "core", [], tag, 32), rpc(provider, p.manager, managerAbi, "mintLedger", [], tag, 32),
  ]);
  if (!same(authorizationId, p.authorizationId) || used !== false || !same(core, p.offer.core) || !same(ledger, p.ledger)) throw Error("Buyer revocation historical Manager binding or replay differs"); return p;
}
export async function simulateERC20PrimaryOfferBuyerRevocation(provider: Reader, input: PreparedERC20PrimaryOfferBuyerRevocation, options: BlockOptions): Promise<Hex> {
  const tag = block(options.blockTag); const p = await inspectERC20PrimaryOfferBuyerRevocation(provider, input, { blockTag: tag });
  if (!same(await provider.call({ ...p.call, from: p.caller, blockTag: tag }), p.authorizationId)) throw Error("Unexpected voidMintOffer authorizationId"); return p.authorizationId;
}
export function prepareERC20PrimaryOfferSellerRevocation(chainId: bigint, adapter: Address, caller: Address, configuration: ERC20PrimaryOfferConfiguration, authorization: PrimaryOfferSellerAuthorization, proof: PrimaryOfferSignature): PreparedERC20PrimaryOfferSellerRevocation {
  const chain = uint(chainId, 256, true); const host = addr(adapter); const c = normalizeERC20PrimaryOfferConfiguration(configuration); const a = normalizeERC20PrimaryOfferSellerAuthorization(authorization); const s = normalizePrimaryOfferSignature(proof);
  if (a.chainId !== chain || !same(a.saleAdapter, host) || a.collectionId !== c.collectionId || !same(a.phaseId, c.phaseId) || !same(a.payer, c.buyer) || !same(a.asset, c.asset) || a.unitPrice !== c.price || a.primaryPolicyMode !== c.primaryPolicyMode || !same(a.expectedPrimaryPolicyHash, c.expectedPrimaryPolicyHash) || !same(a.policyHash, c.mintPolicyHash) || !same(s.authorizer, c.signer) || s.kind !== c.signerKind) throw Error("Seller revocation differs from immutable membership and terms");
  const digest = erc20PrimaryOfferSellerAuthorizationPayload(chain, host, a).digest;
  return Object.freeze({ chainId: chain, adapter: host, caller: addr(caller), configuration: c, authorization: a, proof: s, authorizationDigest: digest, payload: primaryOfferSellerRevocationPayload(chain, host, s.authorizer, digest), call: call(host, carrierAbi, "revokeAuthorization", [a, s]) });
}
function sellerRevocation(value: PreparedERC20PrimaryOfferSellerRevocation): PreparedERC20PrimaryOfferSellerRevocation {
  const p = prepareERC20PrimaryOfferSellerRevocation(value.chainId, value.adapter, value.caller, value.configuration, value.authorization, value.proof); equal(value, p, "Seller revocation plan differs"); return p;
}
export async function inspectERC20PrimaryOfferSellerRevocation(provider: Reader, input: PreparedERC20PrimaryOfferSellerRevocation, options: BlockOptions): Promise<PreparedERC20PrimaryOfferSellerRevocation> {
  const p = sellerRevocation(input); const tag = block(options.blockTag); await network(provider, p.chainId);
  const [[digest], [used], binding, [manager]] = await Promise.all([
    rpc(provider, p.adapter, carrierAbi, "authorizationDigest", [p.authorization], tag, 32), rpc(provider, p.adapter, carrierAbi, "digestConsumed", [p.authorizationDigest], tag, 32), rpc(provider, p.adapter, carrierAbi, "primaryOfferAuthorizationBinding", [p.authorization.saleId], tag, 160), rpc(provider, p.adapter, carrierAbi, "mintManager", [], tag, 32),
  ]);
  const c = p.configuration;
  if (!same(digest, p.authorizationDigest) || used !== false || !same(manager, p.authorization.mintManager) || binding[0] !== c.collectionId || !same(binding[1], c.phaseId) || !same(binding[2], c.signer) || binding[3] !== c.signerKind || !same(binding[4], erc20PrimaryOfferConfigurationHash(p.chainId, p.adapter, c))) throw Error("Historical seller revocation binding or replay differs"); return p;
}
export async function simulateERC20PrimaryOfferSellerRevocation(provider: Reader, input: PreparedERC20PrimaryOfferSellerRevocation, options: BlockOptions): Promise<void> {
  const tag = block(options.blockTag); const p = await inspectERC20PrimaryOfferSellerRevocation(provider, input, { blockTag: tag });
  if (await provider.call({ ...p.call, from: p.caller, blockTag: tag }) !== "0x") throw Error("Seller revocation returned unexpected bytes");
}
export function prepareERC20PrimaryOfferPaymentRevocation(chainId: bigint, paymentAdapter: Address, caller: Address, revocation: ERC20PrimaryOfferPaymentRevocation, signature: Hex | null = null): PreparedERC20PrimaryOfferPaymentRevocation {
  const chain = uint(chainId, 256, true); const target = addr(paymentAdapter); const executor = addr(caller); const r = normalize<ERC20PrimaryOfferPaymentRevocation>(revocationTuple, revocation); addr(r.payer);
  const sig = signature === null ? null : bytes(signature); if (sig === null && !same(executor, r.payer)) throw Error("Direct payment revocation requires the payer caller");
  return Object.freeze({ chainId: chain, paymentAdapter: target, caller: executor, revocation: r, signature: sig, payload: paymentIntentRevocationTypedData(chain, target, r), call: sig === null ? call(target, paymentAbi, "revokePaymentIntent", [r.nonce]) : call(target, paymentAbi, "revokePaymentIntentWithSignature", [r, sig]) });
}
export async function simulateERC20PrimaryOfferPaymentRevocation(provider: Reader, input: PreparedERC20PrimaryOfferPaymentRevocation, options: BlockOptions): Promise<void> {
  const p = prepareERC20PrimaryOfferPaymentRevocation(input.chainId, input.paymentAdapter, input.caller, input.revocation, input.signature); equal(input, p, "Payment revocation plan differs"); const tag = block(options.blockTag); await network(provider, p.chainId);
  const [[used], [digest]] = await Promise.all([rpc(provider, p.paymentAdapter, paymentAbi, "isPaymentIntentNonceUsed", [p.revocation.payer, p.revocation.nonce], tag, 32), rpc(provider, p.paymentAdapter, paymentAbi, "paymentIntentRevocationDigest", [p.revocation], tag, 32)]);
  if (used !== false || !same(digest, p.payload.digest)) throw Error("Payment revocation nonce or digest differs");
  if (await provider.call({ ...p.call, from: p.caller, blockTag: tag }) !== "0x") throw Error("Payment revocation returned unexpected bytes");
}

/** Bind a mined direct CALL or a single Safe CALL envelope to the exact execution event and state. */
export async function inspectERC20PrimaryOfferFundingReceipt(provider: Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt" | "getBlock">, input: PreparedERC20PrimaryOfferFunding, evidence: { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }): Promise<{ readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex; readonly execution: ERC20PrimaryOfferExecutionRecord; readonly settlement: ERC20PrimarySettlementResult }> {
  const p = funding(input); exact(evidence, ["transactionHash", "execution"], "receipt evidence"); const transactionHash = hash(evidence.transactionHash); const mode = evidence.execution;
  if (mode !== "direct" && mode !== "safe") throw Error("Unknown receipt execution mode"); await network(provider, p.prepared.chainId);
  const [tx, receipt] = await Promise.all([provider.getTransaction(transactionHash), provider.getTransactionReceipt(transactionHash)]);
  if (!tx || !receipt || !same(tx.hash, transactionHash) || !same(receipt.hash, transactionHash) || receipt.status !== 1 || tx.blockNumber === null || tx.blockHash === null || receipt.blockNumber !== tx.blockNumber || !same(receipt.blockHash, tx.blockHash) || tx.value !== 0n || tx.to === null) throw Error("Transaction receipt identity or successful mined block differs");
  const tag = block(receipt.blockNumber); const minedHash = hash(receipt.blockHash);
  if (mode === "direct") {
    if (!same(tx.from, p.prepared.caller) || !same(tx.to, p.call.to) || !same(tx.data, p.call.data)) throw Error("Mined direct funding CALL differs");
  } else {
    if (!same(tx.to, p.prepared.caller)) throw Error("Safe envelope targets a different actual caller");
    const data = bytes(tx.data, MAX_RPC_BYTES + 65_536); const q = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(safeAbi.encodeFunctionData("execTransaction", q), data) || !same(q.to, p.call.to) || q.value !== 0n || q.operation !== 0n || !same(q.data, p.call.data)) throw Error("Safe funding envelope differs from the exact nonpayable CALL");
  }
  const currentBlock = await provider.getBlock(tag); if (!currentBlock || !same(currentBlock.hash, minedHash)) throw Error("Receipt block is no longer canonical");
  const topic = carrierAbi.getEvent("PrimaryOfferExecution")!.topicHash;
  const events = receipt.logs.filter(l => same(l.address, p.prepared.adapter) && same(l.topics[0], topic));
  if (events.length !== 1) throw Error("Expected exactly one carrier execution event"); const log = events[0]!;
  if (log.topics.length !== 2 || !isHexString(log.data, 416)) throw Error("Malformed carrier execution event");
  const decoded = carrierAbi.decodeEventLog("PrimaryOfferExecution", log.data, [...log.topics]); const encoded = carrierAbi.encodeEventLog("PrimaryOfferExecution", decoded);
  if (!same(encoded.data, log.data) || render(encoded.topics.map(t => t.toLowerCase())) !== render([...log.topics].map(t => t.toLowerCase())) || !same(decoded.executionId, p.candidate.executionBinding.executionId)) throw Error("Noncanonical or mismatched carrier execution event");
  const execution = checkedExecution(p, normalize<ERC20PrimaryOfferExecutionRecord>(executionTuple, decoded.execution, true));
  const completed = await inspectCompletedERC20PrimaryOffer(provider, p, { blockTag: tag }); equal(completed.execution, execution, "Execution event differs from mined stored record");
  const finalBlock = await provider.getBlock(tag); if (!finalBlock || !same(finalBlock.hash, minedHash)) throw Error("Receipt block changed during validation");
  return Object.freeze({ transactionHash, blockNumber: tag, blockHash: minedHash, execution, settlement: completed.settlement });
}
