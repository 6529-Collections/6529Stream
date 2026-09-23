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
import type { UnsignedCall } from "./client.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";
import {
  curatedContentLeaf,
  curatedPurchaseId,
  curatedSaleId,
  normalizeCuratedDelegationWitness,
  normalizeCuratedSelection,
  validateCuratedSaleConfiguration,
  verifyCuratedContentProof,
  type CuratedDelegationWitness,
  type CuratedSaleConfiguration,
  type CuratedSelection,
} from "./current-curated-content.js";

export interface CuratedPrivateConfiguration {
  readonly sale: CuratedSaleConfiguration;
  readonly buyer: Address;
  readonly contentId: Hex;
  readonly tokenDataHash: Hex;
  readonly signer: Address;
  readonly signerKind: bigint;
  readonly signerEvidenceHash: Hex;
  readonly signerRevision: bigint;
  readonly signerAuthority: Address;
}

export interface CuratedPrivateSaleAuthorization {
  readonly chainId: bigint;
  readonly saleAdapter: Address;
  readonly mintManager: Address;
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly saleId: Hex;
  readonly saleKind: bigint;
  readonly revenueClass: Hex;
  readonly expectedPrimaryPolicyHash: Hex;
  readonly primaryPolicyMode: bigint;
  readonly initialRecipientsHash: Hex;
  readonly beneficiariesHash: Hex;
  readonly tokenDataArrayHash: Hex;
  readonly mintCommitmentsHash: Hex;
  readonly payer: Address;
  readonly executor: Address;
  readonly asset: Address;
  readonly unitPrice: bigint;
  readonly quantity: bigint;
  readonly contentSelectionHash: Hex;
  readonly policyHash: Hex;
  readonly nonce: Hex;
  readonly deadline: bigint;
  readonly finalizeBy: bigint;
}

export interface CuratedPrivateSignature {
  readonly authorizer: Address;
  readonly kind: bigint;
  readonly signature: Hex;
}

export interface CuratedPrivatePurchaseInput {
  readonly authorization: CuratedPrivateSaleAuthorization;
  readonly signature: CuratedPrivateSignature;
  readonly selection: CuratedSelection;
  readonly witness: CuratedDelegationWitness;
  readonly revealFeeAllowance: bigint;
}

export interface CuratedPrivateBatchHashes {
  readonly initialRecipientsHash: Hex;
  readonly beneficiariesHash: Hex;
  readonly tokenDataArrayHash: Hex;
  readonly mintCommitmentsHash: Hex;
}

export interface CuratedPrivateCollectionSigner {
  readonly evidenceHash: Hex;
  readonly revision: bigint;
  readonly enabled: boolean;
  readonly authority: Address;
}

export interface CuratedPrivateSaleInspection {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly blockTimestamp: bigint;
  readonly runtimeHash: Hex;
  readonly owner: Address;
  readonly mintManager: Address;
  readonly mintLedger: Address;
  readonly saleId: Hex;
  readonly configuration: CuratedPrivateConfiguration;
  readonly configurationHash: Hex;
  readonly saleNonce: bigint;
  readonly saleKind: bigint;
  readonly status: bigint;
  readonly signerMembership: CuratedPrivateCollectionSigner;
  readonly nextPurchaseNonce: bigint;
  readonly revealFeePerTokenWei: bigint;
  readonly revealCoordinator: Address;
  readonly revealCoordinatorCodeHash: Hex;
  readonly revealRequestMode: bigint;
}

export interface CuratedPrivateExecutionRecord {
  readonly saleId: Hex;
  readonly buyer: Address;
  readonly recipient: Address;
  readonly purchaseNonce: bigint;
  readonly authorizationId: Hex;
  readonly authorizationDigest: Hex;
  readonly contentLeaf: Hex;
  readonly tokenDataHash: Hex;
  readonly mintCommitment: Hex;
  readonly price: bigint;
  readonly tokenId: bigint;
  readonly settlementKey: Hex;
  readonly operationRoot: Hex;
  readonly operationId: Hex;
}

export interface PreparedCuratedPrivateCall {
  readonly caller: Address;
  readonly intent: string;
  readonly call: UnsignedCall;
}

export interface PreparedCuratedPrivateSignerConfiguration extends PreparedCuratedPrivateCall {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly signer: CuratedPrivateCollectionSigner;
}

export interface PreparedCuratedPrivateRegistration extends PreparedCuratedPrivateCall {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly runtimeHash: Hex;
  readonly saleId: Hex;
  readonly expectedNonce: bigint;
  readonly configuration: CuratedPrivateConfiguration;
  readonly configurationHash: Hex;
  readonly selectedProof: readonly Hex[];
}

export interface PreparedCuratedPrivatePurchase {
  readonly caller: Address;
  readonly inspection: CuratedPrivateSaleInspection;
  readonly authorization: CuratedPrivateSaleAuthorization;
  readonly payload: SigningPayload<CuratedPrivateSaleAuthorization>;
  readonly authorizationId: Hex;
  readonly purchaseId: Hex;
  readonly signature: CuratedPrivateSignature;
  readonly selection: CuratedSelection;
  readonly witness: CuratedDelegationWitness;
  readonly requiredValue: bigint;
  readonly expectedExcessCredit: bigint;
  readonly call: UnsignedCall;
  readonly simulation: CuratedPrivateExecutionRecord;
}

export interface CuratedPrivateHistoricalAuthorization {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly manager: Address;
  readonly ledger: Address;
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly signer: Address;
  readonly signerKind: bigint;
  readonly configurationHash: Hex;
  readonly payload: SigningPayload<CuratedPrivateSaleAuthorization>;
  readonly authorizationId: Hex;
  readonly managerUsed: boolean;
  readonly ledgerUsed: boolean;
}

export interface PreparedCuratedPrivateRevocation extends PreparedCuratedPrivateCall {
  readonly historical: CuratedPrivateHistoricalAuthorization;
  readonly revocationPayload: SigningPayload<CuratedPrivateMintTicketRevocation>;
  readonly directAuthorizer: boolean;
}

export interface CuratedPrivateMintTicketRevocation {
  readonly chainId: bigint;
  readonly manager: Address;
  readonly ledger: Address;
  readonly authorizationId: Hex;
}

const coder = AbiCoder.defaultAbiCoder();
const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const MAX_SIGNATURE_BYTES = 65_536;
const MAX_RETURN_BYTES = 8_388_608;
const PRIVATE_KIND = 5n;
const PRIMARY_SALE = id("PRIMARY_SALE") as Hex;
const CONFIG_DOMAIN = id("6529STREAM_NATIVE_CURATED_PRIVATE_CONFIG_V1") as Hex;
const TICKET_DOMAIN = id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1") as Hex;
const RECIPIENTS_DOMAIN = id("6529STREAM_MINT_BATCH_RECIPIENTS_V1") as Hex;
const BENEFICIARIES_DOMAIN = id("6529STREAM_MINT_BATCH_BENEFICIARIES_V1") as Hex;
const TOKEN_DATA_DOMAIN = id("6529STREAM_MINT_BATCH_TOKEN_DATA_V1") as Hex;
const COMMITMENTS_DOMAIN = id("6529STREAM_MINT_BATCH_COMMITMENTS_V1") as Hex;

const saleConfigTuple = "tuple(uint256 collectionId,bytes32 phaseId,uint256 price,address poster,uint64 startsAt,uint64 endsAt,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 contentManifestRoot)";
const privateConfigTuple = `tuple(${saleConfigTuple} sale,address buyer,bytes32 contentId,bytes32 tokenDataHash,address signer,uint8 signerKind,bytes32 signerEvidenceHash,uint64 signerRevision,address signerAuthority)`;
const contentSelectionTuple = "tuple(bytes32 contentId,bytes32 tokenDataHash,bytes32[] proof)";
const selectionTuple = `tuple(${contentSelectionTuple} content,bytes tokenData,bytes32 mintCommitment,address recipient,uint256 purchaseNonce)`;
const signatureTuple = "tuple(address authorizer,uint8 kind,bytes signature)";
const witnessTuple = "tuple(bool walletWide,uint256 index)";
const authorizationTuple = "tuple(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const lifecycleTuple = "tuple(uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision)";
const saleRecordTuple = `tuple(${saleConfigTuple} config,uint256 saleNonce,uint8 saleKind,bytes32 configHash,${lifecycleTuple} lifecycle,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address gate,bytes32 gateCodeHash,bytes32 gateConfigHash,bytes32 manifestHash,bytes32 contentCounterId,bytes32 contentCounterConfigHash,uint8 status)`;
const executionTuple = "tuple(bytes32 saleId,address buyer,address recipient,uint256 purchaseNonce,bytes32 authorizationId,bytes32 authorizationDigest,bytes32 contentLeaf,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 price,uint256 tokenId,bytes32 settlementKey,bytes32 operationRoot,bytes32 operationId)";
const revealQuoteTuple = "tuple(address coordinator,bytes32 coordinatorCodeHash,tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei) policy)";

const privateAbi = new Interface([
  "function owner() view returns (address)",
  "function mintManager() view returns (address)",
  "function nextSaleNonce() view returns (uint256)",
  "function saleIdFor(uint8,uint256,bytes32,uint256) view returns (bytes32)",
  "function nextPurchaseNonce(bytes32,address) view returns (uint256)",
  "function configureCollectionSigner(uint256,address,uint8,bytes32,bool)",
  "function collectionSigner(uint256,address,uint8) view returns (tuple(bytes32 evidenceHash,uint64 revision,bool enabled,address authority))",
  `function privateConfigurationHash(${privateConfigTuple}) view returns (bytes32)`,
  `function registerCuratedPrivateSale(${privateConfigTuple},bytes32[]) returns (bytes32)`,
  `function privateSaleConfiguration(bytes32) view returns (${privateConfigTuple})`,
  `function saleRecord(bytes32) view returns (${saleRecordTuple})`,
  "function eip712Domain() view returns (bytes1,string,string,uint256,address,bytes32,uint256[])",
  `function saleRevealQuote(bytes32) view returns (${revealQuoteTuple})`,
  `function purchasePrivateContent(${authorizationTuple},${signatureTuple},${selectionTuple},${witnessTuple}) payable returns (${executionTuple})`,
  "function curatedSaleAuthorizationBinding(bytes32) view returns (uint256,bytes32,address,uint8,bytes32)",
  `function executionRecord(bytes32) view returns (${executionTuple})`,
  "function refundableBalance(bytes32,address) view returns (uint256)",
  "function claimRefund(bytes32,address) returns (uint256)",
  `function claimRefundFor(bytes32,address,${witnessTuple}) returns (uint256)`,
  "function expirePrivateSale(bytes32)",
]);
const managerAbi = new Interface([
  "function mintLedger() view returns (address)",
  `function mintSaleAuthorizationId(${authorizationTuple}) view returns (bytes32)`,
  `function voidMintSaleAuthorization(${authorizationTuple},bytes) returns (bytes32)`,
  "function isAuthorizationUsed(bytes32) view returns (bool)",
]);
const ledgerAbi = new Interface([
  "function isManagerAuthorizationUsed(address,bytes32) view returns (bool)",
]);

const authorizationFields = [
  { name: "chainId", type: "uint256" },
  { name: "saleAdapter", type: "address" },
  { name: "mintManager", type: "address" },
  { name: "collectionId", type: "uint256" },
  { name: "phaseId", type: "bytes32" },
  { name: "saleId", type: "bytes32" },
  { name: "saleKind", type: "uint8" },
  { name: "revenueClass", type: "bytes32" },
  { name: "expectedPrimaryPolicyHash", type: "bytes32" },
  { name: "primaryPolicyMode", type: "uint8" },
  { name: "initialRecipientsHash", type: "bytes32" },
  { name: "beneficiariesHash", type: "bytes32" },
  { name: "tokenDataArrayHash", type: "bytes32" },
  { name: "mintCommitmentsHash", type: "bytes32" },
  { name: "payer", type: "address" },
  { name: "executor", type: "address" },
  { name: "asset", type: "address" },
  { name: "unitPrice", type: "uint256" },
  { name: "quantity", type: "uint256" },
  { name: "contentSelectionHash", type: "bytes32" },
  { name: "policyHash", type: "bytes32" },
  { name: "nonce", type: "bytes32" },
  { name: "deadline", type: "uint64" },
  { name: "finalizeBy", type: "uint64" },
] as const;
const revocationFields = [
  { name: "chainId", type: "uint256" },
  { name: "manager", type: "address" },
  { name: "ledger", type: "address" },
  { name: "authorizationId", type: "bytes32" },
] as const;

function exactKeys(value: unknown, expected: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...expected].sort().join(",")) {
    throw new Error(`${label} contains missing or unknown properties`);
  }
}

function uint(value: unknown, bits: number, label: string, positive = false): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)
    || (positive && value === 0n)) {
    throw new Error(`${label} must be ${positive ? "a positive" : "a nonnegative"} bigint fitting uint${bits}`);
  }
  return value;
}

function address(value: unknown, label: string, allowZero = false): Address {
  if (typeof value !== "string") throw new Error(`${label} must be an address string`);
  const result = getAddress(value) as Address;
  if (!allowZero && result === ZeroAddress) throw new Error(`${label} must be nonzero`);
  return result;
}

function hash(value: unknown, label: string, allowZero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)
    || (!allowZero && value.toLowerCase() === ZERO32)) {
    throw new Error(`${label} must be ${allowZero ? "a" : "a nonzero"} bytes32`);
  }
  return value.toLowerCase() as Hex;
}

function bytes(value: unknown, label: string, maximum = MAX_SIGNATURE_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, true)
    || (value.length - 2) / 2 > maximum) {
    throw new Error(`${label} must be complete hex bytes no longer than ${maximum} bytes`);
  }
  return value.toLowerCase() as Hex;
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

function runtimeHash(code: unknown): Hex {
  if (typeof code !== "string" || !isHexString(code, true) || code === "0x") {
    throw new Error("Curated private adapter has no runtime");
  }
  return keccak256(code) as Hex;
}

function frozenCall(to: Address, data: Hex, value = 0n): UnsignedCall {
  return Object.freeze({
    to: address(to, "call target"),
    data: bytes(data, "call data", MAX_RETURN_BYTES),
    value: uint(value, 256, "call value"),
  });
}

function normalizeProof(value: readonly Hex[], label: string): readonly Hex[] {
  if (!Array.isArray(value) || value.length > 256) throw new Error(`${label} exceeds 256 nodes`);
  return Object.freeze(value.map((node, index) => hash(node, `${label}[${index}]`, true)));
}

function configEncoding(value: CuratedPrivateConfiguration): string {
  return coder.encode([privateConfigTuple], [value]);
}

export function normalizeCuratedPrivateConfiguration(value: CuratedPrivateConfiguration): CuratedPrivateConfiguration {
  exactKeys(value, ["sale", "buyer", "contentId", "tokenDataHash", "signer", "signerKind",
    "signerEvidenceHash", "signerRevision", "signerAuthority"], "private configuration");
  const sale = validateCuratedSaleConfiguration(value.sale);
  if (sale.primaryPolicyMode !== 0n) throw new Error("Curated private sales require strict primary policy mode 0");
  const signerKind = uint(value.signerKind, 8, "signerKind", true);
  if (signerKind !== 1n && signerKind !== 2n) throw new Error("signerKind must be EOA 1 or ERC1271 2");
  return Object.freeze({
    sale,
    buyer: address(value.buyer, "buyer"),
    contentId: hash(value.contentId, "contentId", true),
    tokenDataHash: hash(value.tokenDataHash, "tokenDataHash"),
    signer: address(value.signer, "signer"),
    signerKind,
    signerEvidenceHash: hash(value.signerEvidenceHash, "signerEvidenceHash"),
    signerRevision: uint(value.signerRevision, 64, "signerRevision", true),
    signerAuthority: address(value.signerAuthority, "signerAuthority"),
  });
}

export function normalizeCuratedPrivateSaleAuthorization(value: CuratedPrivateSaleAuthorization): CuratedPrivateSaleAuthorization {
  exactKeys(value, authorizationFields.map(field => field.name), "curated private authorization");
  return Object.freeze({
    chainId: uint(value.chainId, 256, "chainId", true),
    saleAdapter: address(value.saleAdapter, "saleAdapter"),
    mintManager: address(value.mintManager, "mintManager"),
    collectionId: uint(value.collectionId, 256, "collectionId", true),
    phaseId: hash(value.phaseId, "phaseId"),
    saleId: hash(value.saleId, "saleId"),
    saleKind: uint(value.saleKind, 8, "saleKind"),
    revenueClass: hash(value.revenueClass, "revenueClass"),
    expectedPrimaryPolicyHash: hash(value.expectedPrimaryPolicyHash, "expectedPrimaryPolicyHash"),
    primaryPolicyMode: uint(value.primaryPolicyMode, 8, "primaryPolicyMode"),
    initialRecipientsHash: hash(value.initialRecipientsHash, "initialRecipientsHash"),
    beneficiariesHash: hash(value.beneficiariesHash, "beneficiariesHash"),
    tokenDataArrayHash: hash(value.tokenDataArrayHash, "tokenDataArrayHash"),
    mintCommitmentsHash: hash(value.mintCommitmentsHash, "mintCommitmentsHash"),
    payer: address(value.payer, "payer"),
    executor: address(value.executor, "executor"),
    asset: address(value.asset, "asset", true),
    unitPrice: uint(value.unitPrice, 256, "unitPrice", true),
    quantity: uint(value.quantity, 256, "quantity", true),
    contentSelectionHash: hash(value.contentSelectionHash, "contentSelectionHash"),
    policyHash: hash(value.policyHash, "policyHash"),
    nonce: hash(value.nonce, "nonce"),
    deadline: uint(value.deadline, 64, "deadline"),
    finalizeBy: uint(value.finalizeBy, 64, "finalizeBy"),
  });
}

export function normalizeCuratedPrivateSignature(value: CuratedPrivateSignature): CuratedPrivateSignature {
  exactKeys(value, ["authorizer", "kind", "signature"], "curated private signature");
  const kind = uint(value.kind, 8, "signature kind", true);
  if (kind !== 1n && kind !== 2n) throw new Error("signature kind must be EOA 1 or ERC1271 2");
  return Object.freeze({
    authorizer: address(value.authorizer, "signature authorizer"),
    kind,
    signature: bytes(value.signature, "signature"),
  });
}

export function curatedPrivateConfigurationHash(
  chainId: bigint,
  adapter: Address,
  configuration: CuratedPrivateConfiguration,
): Hex {
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", privateConfigTuple],
    [CONFIG_DOMAIN, uint(chainId, 256, "chainId", true), address(adapter, "adapter"),
      normalizeCuratedPrivateConfiguration(configuration)],
  )) as Hex;
}

export function curatedPrivateBatchHashes(
  adapter: Address,
  buyer: Address,
  selection: CuratedSelection,
): CuratedPrivateBatchHashes {
  const host = address(adapter, "adapter");
  const account = address(buyer, "buyer");
  const chosen = normalizeCuratedSelection(selection);
  if (same(chosen.recipient, host)) throw new Error("Curated private recipient cannot be the adapter");
  return Object.freeze({
    initialRecipientsHash: keccak256(coder.encode(
      ["bytes32", "address[]"], [RECIPIENTS_DOMAIN, [host]],
    )) as Hex,
    beneficiariesHash: keccak256(coder.encode(
      ["bytes32", "address[]"], [BENEFICIARIES_DOMAIN, [account]],
    )) as Hex,
    tokenDataArrayHash: keccak256(coder.encode(
      ["bytes32", "bytes[]"], [TOKEN_DATA_DOMAIN, [chosen.tokenData]],
    )) as Hex,
    mintCommitmentsHash: keccak256(coder.encode(
      ["bytes32", "bytes32[]"], [COMMITMENTS_DOMAIN, [chosen.mintCommitment]],
    )) as Hex,
  });
}

export function curatedPrivateSaleAuthorizationPayload(
  chainId: bigint,
  adapter: Address,
  authorization: CuratedPrivateSaleAuthorization,
): SigningPayload<CuratedPrivateSaleAuthorization> {
  const normalized = normalizeCuratedPrivateSaleAuthorization(authorization);
  const expectedChain = uint(chainId, 256, "chainId", true);
  const host = address(adapter, "adapter");
  if (normalized.chainId !== expectedChain || !same(normalized.saleAdapter, host)) {
    throw new Error("Authorization coordinates differ from the Sales signing domain");
  }
  return buildSigningPayload(
    expectedChain,
    host,
    "6529Stream Sales",
    "SaleAuthorization",
    authorizationFields,
    normalized,
  );
}

export function curatedPrivateMintTicketAuthorizationId(
  chainId: bigint,
  adapter: Address,
  authorization: CuratedPrivateSaleAuthorization,
): Hex {
  const digest = curatedPrivateSaleAuthorizationPayload(chainId, adapter, authorization).digest;
  return keccak256(coder.encode(["bytes32", "bytes32"], [TICKET_DOMAIN, digest])) as Hex;
}

export function curatedPrivateMintTicketRevocationPayload(
  chainId: bigint,
  adapter: Address,
  manager: Address,
  ledger: Address,
  authorizationId: Hex,
): SigningPayload<CuratedPrivateMintTicketRevocation> {
  const message = Object.freeze({
    chainId: uint(chainId, 256, "chainId", true),
    manager: address(manager, "manager"),
    ledger: address(ledger, "ledger"),
    authorizationId: hash(authorizationId, "authorizationId"),
  });
  return buildSigningPayload(
    message.chainId,
    address(adapter, "adapter"),
    "6529Stream Sales",
    "MintTicketRevocation",
    revocationFields,
    message,
  );
}

function normalizeSignerResult(value: any): CuratedPrivateCollectionSigner {
  if (typeof value.enabled !== "boolean") throw new Error("Invalid collection signer enabled flag");
  return Object.freeze({
    evidenceHash: hash(value.evidenceHash, "signer evidenceHash", true),
    revision: uint(value.revision, 64, "signer revision"),
    enabled: value.enabled,
    authority: address(value.authority, "signer authority", true),
  });
}

function privateConfigurationFromResult(value: any): CuratedPrivateConfiguration {
  return normalizeCuratedPrivateConfiguration({
    sale: {
      collectionId: value.sale.collectionId,
      phaseId: value.sale.phaseId,
      price: value.sale.price,
      poster: value.sale.poster,
      startsAt: value.sale.startsAt,
      endsAt: value.sale.endsAt,
      mintPolicyHash: value.sale.mintPolicyHash,
      expectedPrimaryPolicyHash: value.sale.expectedPrimaryPolicyHash,
      primaryPolicyMode: value.sale.primaryPolicyMode,
      contentManifestRoot: value.sale.contentManifestRoot,
    },
    buyer: value.buyer,
    contentId: value.contentId,
    tokenDataHash: value.tokenDataHash,
    signer: value.signer,
    signerKind: value.signerKind,
    signerEvidenceHash: value.signerEvidenceHash,
    signerRevision: value.signerRevision,
    signerAuthority: value.signerAuthority,
  });
}

function normalizeExecution(value: any): CuratedPrivateExecutionRecord {
  return Object.freeze({
    saleId: hash(value.saleId, "execution saleId"),
    buyer: address(value.buyer, "execution buyer"),
    recipient: address(value.recipient, "execution recipient"),
    purchaseNonce: uint(value.purchaseNonce, 256, "execution purchaseNonce", true),
    authorizationId: hash(value.authorizationId, "execution authorizationId"),
    authorizationDigest: hash(value.authorizationDigest, "execution authorizationDigest"),
    contentLeaf: hash(value.contentLeaf, "execution contentLeaf"),
    tokenDataHash: hash(value.tokenDataHash, "execution tokenDataHash"),
    mintCommitment: hash(value.mintCommitment, "execution mintCommitment"),
    price: uint(value.price, 256, "execution price", true),
    tokenId: uint(value.tokenId, 256, "execution tokenId", true),
    settlementKey: hash(value.settlementKey, "execution settlementKey"),
    operationRoot: hash(value.operationRoot, "execution operationRoot"),
    operationId: hash(value.operationId, "execution operationId"),
  });
}

export class CurrentCuratedPrivateClient {
  readonly provider: Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
  readonly chainId: bigint;
  readonly adapter: Address;

  constructor(
    provider: Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">,
    chainId: bigint,
    adapter: Address,
  ) {
    this.provider = provider;
    this.chainId = uint(chainId, 256, "chainId", true);
    this.adapter = address(adapter, "adapter");
    Object.freeze(this);
  }

  async #block(blockTag: BlockTag): Promise<{ number: number; hash: Hex; timestamp: bigint }> {
    if ((await this.provider.getNetwork()).chainId !== this.chainId) {
      throw new Error("RPC chain differs from curated private client");
    }
    const block = await this.provider.getBlock(blockTag);
    if (!block || !block.hash) throw new Error("RPC did not return a concrete block");
    return Object.freeze({
      number: concreteBlock(block.number),
      hash: hash(block.hash, "block hash"),
      timestamp: uint(BigInt(block.timestamp), 64, "block timestamp"),
    });
  }

  async #read(
    target: Address,
    abi: Interface,
    method: string,
    args: readonly unknown[],
    blockTag: BlockTag,
  ): Promise<any> {
    const raw = await this.provider.call({
      to: address(target, "read target"),
      data: abi.encodeFunctionData(method, args),
      blockTag,
    });
    if (typeof raw !== "string" || !isHexString(raw, true)
      || (raw.length - 2) / 2 > MAX_RETURN_BYTES) {
      throw new Error(`${method} returned invalid or oversized data`);
    }
    const decoded = abi.decodeFunctionResult(method, raw);
    if (!same(abi.encodeFunctionResult(method, decoded), raw)) {
      throw new Error(`${method} returned noncanonical ABI data`);
    }
    return decoded;
  }

  #decodeResult(abi: Interface, method: string, raw: unknown): any {
    if (typeof raw !== "string" || !isHexString(raw, true)
      || (raw.length - 2) / 2 > MAX_RETURN_BYTES) {
      throw new Error(`${method} simulation returned invalid or oversized data`);
    }
    const decoded = abi.decodeFunctionResult(method, raw);
    if (!same(abi.encodeFunctionResult(method, decoded), raw)) {
      throw new Error(`${method} simulation returned noncanonical ABI data`);
    }
    return decoded;
  }

  async #unchanged(block: { number: number; hash: Hex }): Promise<void> {
    const after = await this.provider.getBlock(block.number);
    if (!after?.hash || !same(after.hash, block.hash)) {
      throw new Error("Pinned curated private block changed during preparation");
    }
  }

  async prepareCollectionSignerConfiguration(
    input: {
      readonly caller: Address;
      readonly collectionId: bigint;
      readonly signer: Address;
      readonly signerKind: bigint;
      readonly evidenceHash: Hex;
      readonly enabled: boolean;
    },
    blockTag: BlockTag = "latest",
  ): Promise<PreparedCuratedPrivateSignerConfiguration> {
    exactKeys(input, ["caller", "collectionId", "signer", "signerKind", "evidenceHash", "enabled"], "signer configuration input");
    const caller = address(input.caller, "owner caller");
    const collectionId = uint(input.collectionId, 256, "collectionId", true);
    const signer = address(input.signer, "signer");
    const signerKind = uint(input.signerKind, 8, "signerKind", true);
    if (signerKind !== 1n && signerKind !== 2n) throw new Error("signerKind must be EOA 1 or ERC1271 2");
    const evidenceHash = hash(input.evidenceHash, "evidenceHash");
    if (typeof input.enabled !== "boolean") throw new Error("enabled must be boolean");
    const enabled = input.enabled;
    const block = await this.#block(blockTag);
    const [ownerRaw, currentRaw] = await Promise.all([
      this.#read(this.adapter, privateAbi, "owner", [], block.number),
      this.#read(this.adapter, privateAbi, "collectionSigner", [collectionId, signer, signerKind], block.number),
    ]);
    const owner = address(ownerRaw[0], "owner");
    if (!same(owner, caller)) throw new Error("Collection signer configuration caller is not the current owner");
    const current = normalizeSignerResult(currentRaw[0]);
    if (current.revision === (1n << 64n) - 1n) throw new Error("Collection signer revision would overflow uint64");
    const data = privateAbi.encodeFunctionData("configureCollectionSigner", [
      collectionId, signer, signerKind, evidenceHash, enabled,
    ]) as Hex;
    await this.provider.call({ to: this.adapter, from: caller, data, blockTag: block.number });
    await this.#unchanged(block);
    return Object.freeze({
      caller,
      intent: "Current owner configures one collection sale signer membership",
      call: frozenCall(this.adapter, data),
      blockNumber: block.number,
      blockHash: block.hash,
      signer: Object.freeze({
        evidenceHash,
        revision: current.revision + 1n,
        enabled,
        authority: caller,
      }),
    });
  }

  async prepareRegistration(
    callerInput: Address,
    configurationInput: CuratedPrivateConfiguration,
    selectedProofInput: readonly Hex[],
    blockTag: BlockTag = "latest",
  ): Promise<PreparedCuratedPrivateRegistration> {
    const caller = address(callerInput, "registration caller");
    const configuration = normalizeCuratedPrivateConfiguration(configurationInput);
    const selectedProof = normalizeProof(selectedProofInput, "selected proof");
    const block = await this.#block(blockTag);
    if (configuration.sale.startsAt <= block.timestamp) {
      throw new Error("Curated private registration requires a future start time");
    }
    const [ownerRaw, nonceRaw, hashRaw, signerRaw, code] = await Promise.all([
      this.#read(this.adapter, privateAbi, "owner", [], block.number),
      this.#read(this.adapter, privateAbi, "nextSaleNonce", [], block.number),
      this.#read(this.adapter, privateAbi, "privateConfigurationHash", [configuration], block.number),
      this.#read(this.adapter, privateAbi, "collectionSigner", [configuration.sale.collectionId,
        configuration.signer, configuration.signerKind], block.number),
      this.provider.getCode(this.adapter, block.number),
    ]);
    const owner = address(ownerRaw[0], "owner");
    if (!same(owner, caller)) throw new Error("Curated private registration caller is not the current owner");
    const expectedNonce = uint(nonceRaw[0], 256, "next sale nonce", true);
    const saleId = curatedSaleId(this.chainId, this.adapter, PRIVATE_KIND,
      configuration.sale.collectionId, configuration.sale.phaseId, expectedNonce);
    if (!verifyCuratedContentProof(this.chainId, this.adapter, saleId,
      configuration.sale.contentManifestRoot, {
        contentId: configuration.contentId,
        tokenDataHash: configuration.tokenDataHash,
        proof: selectedProof,
      })) {
      throw new Error("Selected private content proof does not match the configured manifest root");
    }
    const configurationHash = curatedPrivateConfigurationHash(this.chainId, this.adapter, configuration);
    if (!same(hashRaw[0], configurationHash)) throw new Error("Adapter private configuration hash differs from the source preimage");
    const signerMembership = normalizeSignerResult(signerRaw[0]);
    if (!signerMembership.enabled || signerMembership.revision !== configuration.signerRevision
      || !same(signerMembership.evidenceHash, configuration.signerEvidenceHash)
      || !same(signerMembership.authority, configuration.signerAuthority)) {
      throw new Error("Configured signer membership differs from the pinned private configuration");
    }
    const data = privateAbi.encodeFunctionData("registerCuratedPrivateSale", [configuration, selectedProof]) as Hex;
    const simulatedRaw = await this.provider.call({ to: this.adapter, from: caller, data, blockTag: block.number });
    const simulated = this.#decodeResult(privateAbi, "registerCuratedPrivateSale", simulatedRaw);
    if (!same(simulated[0], saleId)) throw new Error("Registration simulation returned an unexpected sale ID");
    await this.#unchanged(block);
    return Object.freeze({
      caller,
      intent: "Current owner registers one immutable curated private sale",
      call: frozenCall(this.adapter, data),
      blockNumber: block.number,
      blockHash: block.hash,
      runtimeHash: runtimeHash(code),
      saleId,
      expectedNonce,
      configuration,
      configurationHash,
      selectedProof,
    });
  }

  async inspectSale(
    saleIdInput: Hex,
    buyerInput: Address,
    blockTag: BlockTag = "latest",
  ): Promise<CuratedPrivateSaleInspection> {
    const saleId = hash(saleIdInput, "saleId");
    const buyer = address(buyerInput, "buyer");
    const block = await this.#block(blockTag);
    const [configRaw, recordRaw, managerRaw, ownerRaw, nonceRaw, domainRaw, quoteRaw, code] = await Promise.all([
      this.#read(this.adapter, privateAbi, "privateSaleConfiguration", [saleId], block.number),
      this.#read(this.adapter, privateAbi, "saleRecord", [saleId], block.number),
      this.#read(this.adapter, privateAbi, "mintManager", [], block.number),
      this.#read(this.adapter, privateAbi, "owner", [], block.number),
      this.#read(this.adapter, privateAbi, "nextPurchaseNonce", [saleId, buyer], block.number),
      this.#read(this.adapter, privateAbi, "eip712Domain", [], block.number),
      this.#read(this.adapter, privateAbi, "saleRevealQuote", [saleId], block.number),
      this.provider.getCode(this.adapter, block.number),
    ]);
    const configuration = privateConfigurationFromResult(configRaw[0]);
    if (!same(configuration.buyer, buyer)) throw new Error("Inspected buyer differs from immutable private buyer");
    const record = recordRaw[0];
    const saleNonce = uint(record.saleNonce, 256, "sale nonce", true);
    const saleKind = uint(record.saleKind, 8, "sale kind");
    const status = uint(record.status, 8, "sale status");
    const expectedSaleId = curatedSaleId(this.chainId, this.adapter, PRIVATE_KIND,
      configuration.sale.collectionId, configuration.sale.phaseId, saleNonce);
    const configurationHash = curatedPrivateConfigurationHash(this.chainId, this.adapter, configuration);
    if (!same(expectedSaleId, saleId) || saleKind !== PRIVATE_KIND
      || !same(record.configHash, configurationHash)
      || coder.encode([saleConfigTuple], [record.config]).toLowerCase()
        !== coder.encode([saleConfigTuple], [configuration.sale]).toLowerCase()) {
      throw new Error("Stored private sale identity or immutable configuration is inconsistent");
    }
    const manager = address(managerRaw[0], "mintManager");
    const [ledgerRaw, signerRaw] = await Promise.all([
      this.#read(manager, managerAbi, "mintLedger", [], block.number),
      this.#read(this.adapter, privateAbi, "collectionSigner", [configuration.sale.collectionId,
        configuration.signer, configuration.signerKind], block.number),
    ]);
    if (domainRaw[0] !== "0x0f" || domainRaw[1] !== "6529Stream Sales" || domainRaw[2] !== "1"
      || domainRaw[3] !== this.chainId || !same(domainRaw[4], this.adapter)
      || !same(domainRaw[5], ZERO32) || domainRaw[6].length !== 0) {
      throw new Error("Adapter ERC5267 Sales domain differs from the original domain");
    }
    const quote = quoteRaw[0];
    if (quote.policy.declared !== true || quote.policy.requestMode > 1n) {
      throw new Error("Sale has no supported live reveal fee policy");
    }
    await this.#unchanged(block);
    return Object.freeze({
      chainId: this.chainId,
      adapter: this.adapter,
      blockNumber: block.number,
      blockHash: block.hash,
      blockTimestamp: block.timestamp,
      runtimeHash: runtimeHash(code),
      owner: address(ownerRaw[0], "owner", true),
      mintManager: manager,
      mintLedger: address(ledgerRaw[0], "mintLedger"),
      saleId,
      configuration,
      configurationHash,
      saleNonce,
      saleKind,
      status,
      signerMembership: normalizeSignerResult(signerRaw[0]),
      nextPurchaseNonce: uint(nonceRaw[0], 256, "next purchase nonce", true),
      revealFeePerTokenWei: uint(quote.policy.revealFeePerTokenWei, 256, "reveal fee"),
      revealCoordinator: address(quote.coordinator, "reveal coordinator"),
      revealCoordinatorCodeHash: hash(quote.coordinatorCodeHash, "reveal coordinator code hash"),
      revealRequestMode: uint(quote.policy.requestMode, 8, "reveal request mode"),
    });
  }

  async preparePurchase(
    callerInput: Address,
    inputValue: CuratedPrivatePurchaseInput,
    blockTag: BlockTag = "latest",
  ): Promise<PreparedCuratedPrivatePurchase> {
    exactKeys(inputValue, ["authorization", "signature", "selection", "witness", "revealFeeAllowance"], "purchase input");
    const caller = address(callerInput, "purchase executor");
    const authorization = normalizeCuratedPrivateSaleAuthorization(inputValue.authorization);
    const signature = normalizeCuratedPrivateSignature(inputValue.signature);
    const selection = normalizeCuratedSelection(inputValue.selection);
    const witness = normalizeCuratedDelegationWitness(inputValue.witness);
    const revealFeeAllowance = uint(inputValue.revealFeeAllowance, 256, "revealFeeAllowance");
    if (same(selection.recipient, this.adapter)) throw new Error("Curated private recipient cannot be the adapter");
    const block = await this.#block(blockTag);
    const inspection = await this.inspectSale(authorization.saleId, authorization.payer, block.number);
    const config = inspection.configuration;
    if (inspection.status !== 1n) throw new Error("Curated private sale is not active");
    if (block.timestamp < config.sale.startsAt || block.timestamp > config.sale.endsAt) {
      throw new Error("Curated private sale is outside its inclusive purchase window");
    }
    if (!inspection.signerMembership.enabled
      || inspection.signerMembership.revision !== config.signerRevision
      || !same(inspection.signerMembership.evidenceHash, config.signerEvidenceHash)
      || !same(inspection.signerMembership.authority, config.signerAuthority)) {
      throw new Error("Live collection signer membership differs from immutable sale membership");
    }
    if (selection.purchaseNonce !== inspection.nextPurchaseNonce
      || !same(selection.recipient, config.buyer)
      || !same(selection.content.contentId, config.contentId)
      || !same(selection.content.tokenDataHash, config.tokenDataHash)
      || !verifyCuratedContentProof(this.chainId, this.adapter, authorization.saleId,
        config.sale.contentManifestRoot, selection.content)) {
      throw new Error("Selection differs from the declared private leaf, buyer, proof or next nonce");
    }
    const leaf = curatedContentLeaf(this.chainId, this.adapter, authorization.saleId,
      selection.content.contentId, selection.content.tokenDataHash);
    const batchHashes = curatedPrivateBatchHashes(this.adapter, config.buyer, selection);
    if (authorization.chainId !== this.chainId || !same(authorization.saleAdapter, this.adapter)
      || !same(authorization.mintManager, inspection.mintManager)
      || authorization.collectionId !== config.sale.collectionId
      || !same(authorization.phaseId, config.sale.phaseId)
      || !same(authorization.saleId, inspection.saleId)
      || authorization.saleKind !== PRIVATE_KIND || !same(authorization.revenueClass, PRIMARY_SALE)
      || !same(authorization.expectedPrimaryPolicyHash, config.sale.expectedPrimaryPolicyHash)
      || authorization.primaryPolicyMode !== 0n
      || !same(authorization.initialRecipientsHash, batchHashes.initialRecipientsHash)
      || !same(authorization.beneficiariesHash, batchHashes.beneficiariesHash)
      || !same(authorization.tokenDataArrayHash, batchHashes.tokenDataArrayHash)
      || !same(authorization.mintCommitmentsHash, batchHashes.mintCommitmentsHash)
      || !same(authorization.payer, config.buyer) || !same(authorization.executor, caller)
      || authorization.asset !== ZeroAddress || authorization.unitPrice !== config.sale.price
      || authorization.quantity !== 1n || !same(authorization.contentSelectionHash, leaf)
      || !same(authorization.policyHash, config.sale.mintPolicyHash)
      || authorization.deadline < block.timestamp || authorization.deadline > config.sale.endsAt
      || authorization.finalizeBy !== 0n) {
      throw new Error("Signed private authorization differs from immutable sale, selection, arrays or executor");
    }
    if (!same(signature.authorizer, config.signer) || signature.kind !== config.signerKind) {
      throw new Error("Signature authorizer differs from immutable collection signer membership");
    }
    if (revealFeeAllowance < inspection.revealFeePerTokenWei) {
      throw new Error("Reveal fee allowance is below the live fee");
    }
    const payload = curatedPrivateSaleAuthorizationPayload(this.chainId, this.adapter, authorization);
    const authorizationId = curatedPrivateMintTicketAuthorizationId(this.chainId, this.adapter, authorization);
    const [managerIdRaw, managerUsedRaw, ledgerUsedRaw] = await Promise.all([
      this.#read(inspection.mintManager, managerAbi, "mintSaleAuthorizationId", [authorization], block.number),
      this.#read(inspection.mintManager, managerAbi, "isAuthorizationUsed", [authorizationId], block.number),
      this.#read(inspection.mintLedger, ledgerAbi, "isManagerAuthorizationUsed",
        [inspection.mintManager, authorizationId], block.number),
    ]);
    if (!same(managerIdRaw[0], authorizationId)) throw new Error("Manager TICKET ID differs from the source preimage");
    if (managerUsedRaw[0] !== false || ledgerUsedRaw[0] !== false) {
      throw new Error("Curated private authorization TICKET is already consumed or voided");
    }
    const requiredValue = config.sale.price + revealFeeAllowance;
    if (requiredValue >= 1n << 256n) throw new Error("Purchase value overflows uint256");
    const data = privateAbi.encodeFunctionData("purchasePrivateContent", [
      authorization, signature, selection, witness,
    ]) as Hex;
    const rawSimulation = await this.provider.call({
      to: this.adapter,
      from: caller,
      data,
      value: requiredValue,
      blockTag: block.number,
    });
    const decoded = this.#decodeResult(privateAbi, "purchasePrivateContent", rawSimulation);
    const simulation = normalizeExecution(decoded[0]);
    const purchaseId = curatedPurchaseId(this.chainId, this.adapter, inspection.saleId,
      config.buyer, selection.purchaseNonce);
    if (!same(simulation.saleId, inspection.saleId) || !same(simulation.buyer, config.buyer)
      || !same(simulation.recipient, config.buyer) || simulation.purchaseNonce !== selection.purchaseNonce
      || !same(simulation.authorizationId, authorizationId)
      || !same(simulation.authorizationDigest, payload.digest)
      || !same(simulation.contentLeaf, leaf)
      || !same(simulation.tokenDataHash, selection.content.tokenDataHash)
      || !same(simulation.mintCommitment, selection.mintCommitment)
      || simulation.price !== config.sale.price) {
      throw new Error("Purchase simulation transcript differs from the reviewed packet");
    }
    await this.#unchanged(block);
    return Object.freeze({
      caller,
      inspection,
      authorization,
      payload,
      authorizationId,
      purchaseId,
      signature,
      selection,
      witness,
      requiredValue,
      expectedExcessCredit: revealFeeAllowance - inspection.revealFeePerTokenWei,
      call: frozenCall(this.adapter, data, requiredValue),
      simulation,
    });
  }

  async inspectHistoricalAuthorization(
    authorizationInput: CuratedPrivateSaleAuthorization,
    blockTag: BlockTag = "latest",
  ): Promise<CuratedPrivateHistoricalAuthorization> {
    const authorization = normalizeCuratedPrivateSaleAuthorization(authorizationInput);
    if (authorization.chainId !== this.chainId || !same(authorization.saleAdapter, this.adapter)
      || authorization.saleKind !== PRIVATE_KIND || !same(authorization.revenueClass, PRIMARY_SALE)) {
      throw new Error("Historical authorization is not this client's original curated private family");
    }
    const block = await this.#block(blockTag);
    const [managerRaw, bindingRaw] = await Promise.all([
      this.#read(this.adapter, privateAbi, "mintManager", [], block.number),
      this.#read(this.adapter, privateAbi, "curatedSaleAuthorizationBinding", [authorization.saleId], block.number),
    ]);
    const manager = address(managerRaw[0], "mintManager");
    if (!same(manager, authorization.mintManager)) throw new Error("Historical authorization names a different Manager");
    const collectionId = uint(bindingRaw[0], 256, "binding collectionId", true);
    const phaseId = hash(bindingRaw[1], "binding phaseId");
    const signer = address(bindingRaw[2], "binding signer");
    const signerKind = uint(bindingRaw[3], 8, "binding signerKind", true);
    const configurationHash = hash(bindingRaw[4], "binding configurationHash");
    if (collectionId !== authorization.collectionId || !same(phaseId, authorization.phaseId)
      || (signerKind !== 1n && signerKind !== 2n)) {
      throw new Error("Historical private sale binding differs from the full authorization payload");
    }
    const payload = curatedPrivateSaleAuthorizationPayload(this.chainId, this.adapter, authorization);
    const authorizationId = curatedPrivateMintTicketAuthorizationId(this.chainId, this.adapter, authorization);
    const ledger = address((await this.#read(manager, managerAbi, "mintLedger", [], block.number))[0], "mintLedger");
    const [managerIdRaw, managerUsedRaw, ledgerUsedRaw] = await Promise.all([
      this.#read(manager, managerAbi, "mintSaleAuthorizationId", [authorization], block.number),
      this.#read(manager, managerAbi, "isAuthorizationUsed", [authorizationId], block.number),
      this.#read(ledger, ledgerAbi, "isManagerAuthorizationUsed", [manager, authorizationId], block.number),
    ]);
    if (!same(managerIdRaw[0], authorizationId)) throw new Error("Manager historical TICKET ID differs from the source preimage");
    if (managerUsedRaw[0] !== ledgerUsedRaw[0]) throw new Error("Manager and Ledger historical replay reads disagree");
    await this.#unchanged(block);
    return Object.freeze({
      blockNumber: block.number,
      blockHash: block.hash,
      manager,
      ledger,
      collectionId,
      phaseId,
      signer,
      signerKind,
      configurationHash,
      payload,
      authorizationId,
      managerUsed: managerUsedRaw[0],
      ledgerUsed: ledgerUsedRaw[0],
    });
  }

  async prepareVoidAuthorization(
    callerInput: Address,
    authorizationInput: CuratedPrivateSaleAuthorization,
    revocationSignatureInput: Hex,
    blockTag: BlockTag = "latest",
  ): Promise<PreparedCuratedPrivateRevocation> {
    const caller = address(callerInput, "revocation caller");
    const authorization = normalizeCuratedPrivateSaleAuthorization(authorizationInput);
    const revocationSignature = bytes(revocationSignatureInput, "revocation signature");
    const historical = await this.inspectHistoricalAuthorization(authorization, blockTag);
    if (historical.managerUsed || historical.ledgerUsed) throw new Error("Authorization TICKET is already consumed or voided");
    const directAuthorizer = same(caller, historical.signer);
    if (directAuthorizer && revocationSignature !== "0x") {
      throw new Error("Direct historical signer revocation uses an empty revocation signature");
    }
    if (!directAuthorizer && revocationSignature === "0x") {
      throw new Error("Relayed historical revocation requires the original signer signature");
    }
    const revocationPayload = curatedPrivateMintTicketRevocationPayload(
      this.chainId,
      this.adapter,
      historical.manager,
      historical.ledger,
      historical.authorizationId,
    );
    const data = managerAbi.encodeFunctionData("voidMintSaleAuthorization", [authorization, revocationSignature]) as Hex;
    const raw = await this.provider.call({
      to: historical.manager,
      from: caller,
      data,
      blockTag: historical.blockNumber,
    });
    const decoded = this.#decodeResult(managerAbi, "voidMintSaleAuthorization", raw);
    if (!same(decoded[0], historical.authorizationId)) {
      throw new Error("Revocation simulation returned a different authorization ID");
    }
    await this.#unchanged({ number: historical.blockNumber, hash: historical.blockHash });
    return Object.freeze({
      caller,
      intent: directAuthorizer
        ? "Historical configured signer directly voids the full original private authorization"
        : "Relayer submits the historical signer's Sales-domain MintTicketRevocation",
      call: frozenCall(historical.manager, data),
      historical,
      revocationPayload,
      directAuthorizer,
    });
  }

  expirePrivateSaleCall(callerInput: Address, saleIdInput: Hex): PreparedCuratedPrivateCall {
    const caller = address(callerInput, "expiry caller");
    const saleId = hash(saleIdInput, "saleId");
    return Object.freeze({
      caller,
      intent: "Permissionless expiry after the private sale end time",
      call: frozenCall(this.adapter, privateAbi.encodeFunctionData("expirePrivateSale", [saleId]) as Hex),
    });
  }

  async refundableBalance(
    saleIdInput: Hex,
    buyerInput: Address,
    blockTag: BlockTag = "latest",
  ): Promise<bigint> {
    const saleId = hash(saleIdInput, "saleId");
    const buyer = address(buyerInput, "credited buyer");
    if ((await this.provider.getNetwork()).chainId !== this.chainId) {
      throw new Error("RPC chain differs from curated private client");
    }
    const raw = await this.#read(this.adapter, privateAbi, "refundableBalance", [saleId, buyer], blockTag);
    return uint(raw[0], 256, "refundable balance");
  }

  claimRefundCall(
    callerInput: Address,
    saleIdInput: Hex,
    recipientInput: Address,
  ): PreparedCuratedPrivateCall {
    const caller = address(callerInput, "credited buyer");
    const saleId = hash(saleIdInput, "saleId");
    const recipient = address(recipientInput, "refund recipient");
    if (same(recipient, this.adapter)) throw new Error("Refund recipient cannot be the adapter");
    return Object.freeze({
      caller,
      intent: "Credited buyer withdraws existing native excess to the selected recipient",
      call: frozenCall(this.adapter, privateAbi.encodeFunctionData("claimRefund", [saleId, recipient]) as Hex),
    });
  }

  claimRefundForCall(
    callerInput: Address,
    saleIdInput: Hex,
    buyerInput: Address,
    witnessInput: CuratedDelegationWitness,
  ): PreparedCuratedPrivateCall {
    const caller = address(callerInput, "delegated refund caller");
    const saleId = hash(saleIdInput, "saleId");
    const buyer = address(buyerInput, "credited buyer");
    const witness = normalizeCuratedDelegationWitness(witnessInput);
    return Object.freeze({
      caller,
      intent: "Live native delegate withdraws existing excess only to the credited buyer",
      call: frozenCall(this.adapter, privateAbi.encodeFunctionData("claimRefundFor", [saleId, buyer, witness]) as Hex),
    });
  }
}
