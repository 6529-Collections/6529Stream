import {
  AbiCoder,
  Interface,
  ZeroAddress,
  ZeroHash,
  getAddress,
  isHexString,
  keccak256,
} from "ethers";
import type { Provider } from "ethers";
import type { UnsignedCall } from "./client.js";
import type { Address, Hex } from "./generated/contracts.js";
import {
  normalizeCuratedDelegationWitness,
  normalizeCuratedSelection,
  verifyCuratedContentProof,
} from "./current-curated-content.js";
import type {
  CuratedDelegationWitness,
  CuratedSelection,
} from "./current-curated-content.js";
import {
  normalizePrimaryOfferConfiguration,
  normalizePrimaryOfferSaleOffer,
  normalizePrimaryOfferSellerAuthorization,
  normalizePrimaryOfferSignature,
  primaryOfferBuyerAuthorizationId,
  primaryOfferBuyerRevocationPayload,
  primaryOfferConfigurationHash,
  primaryOfferPurchaseId,
  primaryOfferSaleId,
  primaryOfferSellerReplayDigest,
  primaryOfferSellerRevocationPayload,
  primaryOfferSigningSnapshot,
} from "./current-primary-offer-signing.js";
import type {
  PrimaryOfferBuyerMintTicketRevocation,
  PrimaryOfferConfiguration,
  PrimaryOfferSaleOffer,
  PrimaryOfferSellerAuthorization,
  PrimaryOfferSellerAuthorizationRevocation,
  PrimaryOfferSignature,
  PrimaryOfferSigningSnapshot,
} from "./current-primary-offer-signing.js";

export interface PrimaryOfferCollectionSigner {
  readonly evidenceHash: Hex;
  readonly revision: bigint;
  readonly enabled: boolean;
  readonly authority: Address;
}

export interface PreparedPrimaryOfferSignerConfiguration {
  readonly adapter: Address;
  readonly caller: Address;
  readonly collectionId: bigint;
  readonly signer: Address;
  readonly signerKind: bigint;
  readonly evidenceHash: Hex;
  readonly enabled: boolean;
  readonly call: UnsignedCall;
}

export interface PreparedPrimaryOfferRegistration {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly expectedNonce: bigint;
  readonly configuration: PrimaryOfferConfiguration;
  readonly selectedProof: readonly Hex[];
  readonly expectedSaleId: Hex;
  readonly configurationHash: Hex;
  readonly call: UnsignedCall;
}

export interface PrimaryOfferAcceptanceInput {
  readonly offer: PrimaryOfferSaleOffer;
  readonly buyerProof: PrimaryOfferSignature;
  readonly sellerAuthorization: PrimaryOfferSellerAuthorization;
  readonly sellerProof: PrimaryOfferSignature;
  readonly selection: CuratedSelection;
  readonly signerDelegation: CuratedDelegationWitness;
  readonly executorDelegation: CuratedDelegationWitness;
  readonly revealFeeAllowance: bigint;
}

export interface PreparedPrimaryOfferAcceptance {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly core: Address;
  readonly manager: Address;
  readonly caller: Address;
  readonly configuration: PrimaryOfferConfiguration;
  readonly signing: PrimaryOfferSigningSnapshot;
  readonly buyerProof: PrimaryOfferSignature;
  readonly sellerProof: PrimaryOfferSignature;
  readonly selection: CuratedSelection;
  readonly signerDelegation: CuratedDelegationWitness;
  readonly executorDelegation: CuratedDelegationWitness;
  readonly revealFeeAllowance: bigint;
  readonly expectedPurchaseId: Hex;
  readonly call: UnsignedCall;
}

export interface PrimaryOfferSaleRecord {
  readonly saleNonce: bigint;
  readonly saleKind: bigint;
  readonly configHash: Hex;
  readonly saleCreatedAt: bigint;
  readonly saleAdapterRegistryRevision: bigint;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly gate: Address | null;
  readonly gateCodeHash: Hex;
  readonly gateConfigHash: Hex;
  readonly manifestHash: Hex;
  readonly contentCounterId: Hex;
  readonly contentCounterConfigHash: Hex;
  readonly status: bigint;
}

export interface PrimaryOfferExecutionRecord {
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

export interface PreparedPrimaryOfferBuyerRevocation {
  readonly chainId: bigint;
  readonly manager: Address;
  readonly ledger: Address;
  readonly caller: Address;
  readonly offer: PrimaryOfferSaleOffer;
  readonly buyerKind: bigint;
  readonly revocationSignature: Hex;
  readonly authorizationId: Hex;
  readonly payload: ReturnType<typeof primaryOfferBuyerRevocationPayload>;
  readonly call: UnsignedCall;
}

export interface PreparedPrimaryOfferSellerRevocation {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly configuration: PrimaryOfferConfiguration;
  readonly authorization: PrimaryOfferSellerAuthorization;
  readonly proof: PrimaryOfferSignature;
  readonly authorizationDigest: Hex;
  readonly payload: ReturnType<typeof primaryOfferSellerRevocationPayload>;
  readonly call: UnsignedCall;
}

export interface PreparedPrimaryOfferAction {
  readonly kind: "refund" | "delegated-refund" | "cancel" | "expire" | "contest-sync";
  readonly target: Address;
  readonly caller: Address;
  readonly call: UnsignedCall;
}

const coder = AbiCoder.defaultAbiCoder();
const MAX_DYNAMIC_BYTES = 65_536;
const MAX_PROOF_NODES = 256;
const saleTuple = "tuple(uint256 collectionId,bytes32 phaseId,uint256 price,address poster,uint64 startsAt,uint64 endsAt,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 contentManifestRoot)";
const configurationTuple = `tuple(${saleTuple} sale,address buyer,bytes32 offerDigest,bytes32 contentId,bytes32 tokenDataHash,address signer,uint8 signerKind,bytes32 signerEvidenceHash,uint64 signerRevision,address signerAuthority)`;
const offerTuple = "tuple(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const authorizationTuple = "tuple(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const signatureTuple = "tuple(address authorizer,uint8 kind,bytes signature)";
const contentTuple = "tuple(bytes32 contentId,bytes32 tokenDataHash,bytes32[] proof)";
const selectionTuple = `tuple(${contentTuple} content,bytes tokenData,bytes32 mintCommitment,address recipient,uint256 purchaseNonce)`;
const witnessTuple = "tuple(bool walletWide,uint256 index)";
const acceptanceTuple = `tuple(${offerTuple} offer,${signatureTuple} buyerProof,${authorizationTuple} authorization,${signatureTuple} sellerProof,${selectionTuple} selection,${witnessTuple} signerDelegation,${witnessTuple} executorDelegation)`;
const lifecycleTuple = "tuple(uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision)";
const saleRecordTuple = `tuple(${saleTuple} config,uint256 saleNonce,uint8 saleKind,bytes32 configHash,${lifecycleTuple} lifecycle,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address gate,bytes32 gateCodeHash,bytes32 gateConfigHash,bytes32 manifestHash,bytes32 contentCounterId,bytes32 contentCounterConfigHash,uint8 status)`;
const executionTuple = "tuple(bytes32 saleId,address buyer,address recipient,uint256 purchaseNonce,bytes32 authorizationId,bytes32 authorizationDigest,bytes32 contentLeaf,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 price,uint256 tokenId,bytes32 settlementKey,bytes32 operationRoot,bytes32 operationId)";
const quoteTuple = "tuple(address coordinator,bytes32 coordinatorCodeHash,tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei) policy)";

const offerAbi = new Interface([
  "function configureCollectionSigner(uint256,address,uint8,bytes32,bool)",
  "function collectionSigner(uint256,address,uint8) view returns (tuple(bytes32 evidenceHash,uint64 revision,bool enabled,address authority))",
  "function owner() view returns (address)",
  "function nextSaleNonce() view returns (uint256)",
  "function saleIdFor(uint8,uint256,bytes32,uint256) view returns (bytes32)",
  `function primaryOfferConfigurationHash(${configurationTuple}) view returns (bytes32)`,
  `function registerPrimaryOffer(${configurationTuple},bytes32[]) returns (bytes32)`,
  `function primaryOfferConfiguration(bytes32) view returns (${configurationTuple})`,
  `function saleRecord(bytes32) view returns (${saleRecordTuple})`,
  "function nextPurchaseNonce(bytes32,address) view returns (uint256)",
  "function purchaseIdFor(bytes32,address,uint256) view returns (bytes32)",
  `function authorizationDigest(${authorizationTuple}) view returns (bytes32)`,
  `function offerDigest(${offerTuple}) view returns (bytes32)`,
  "function digestConsumed(bytes32) view returns (bool)",
  "function digestRevoked(bytes32) view returns (bool)",
  `function saleRevealQuote(bytes32) view returns (${quoteTuple})`,
  "function primaryOfferAuthorizationBinding(bytes32) view returns (uint256,bytes32,address,uint8,bytes32)",
  `function acceptPrimaryOffer(${acceptanceTuple}) payable returns (${executionTuple})`,
  `function executionRecord(bytes32) view returns (${executionTuple})`,
  "function refundableBalance(bytes32,address) view returns (uint256)",
  "function claimRefund(bytes32,address) returns (uint256)",
  `function claimRefundFor(bytes32,address,${witnessTuple}) returns (uint256)`,
  `function revokeAuthorization(${authorizationTuple},${signatureTuple})`,
  "function cancelSale(bytes32)",
  "function expirePrimaryOffer(bytes32)",
  "function syncCollectionContest(uint256)",
  "function core() view returns (address)",
  "function mintManager() view returns (address)",
  "function revenueResolver() view returns (address)",
  "function artistRegistry() view returns (address)",
  "function moduleRegistry() view returns (address)",
  "function eip712Domain() view returns (bytes1,string,string,uint256,address,bytes32,uint256[])",
]);

const managerAbi = new Interface([
  `function mintOfferAuthorizationId(${offerTuple}) view returns (bytes32)`,
  `function voidMintOffer(${offerTuple},uint8,bytes) returns (bytes32)`,
  "function isAuthorizationUsed(bytes32) view returns (bool)",
  "function core() view returns (address)",
  "function mintLedger() view returns (address)",
]);

function exactKeys(
  value: unknown,
  expected: readonly string[],
  label: string,
): asserts value is Record<string, unknown> {
  if (
    value === null
    || typeof value !== "object"
    || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...expected].sort().join(",")
  ) {
    throw new Error(`${label} contains missing or unknown properties`);
  }
}

function uint(value: unknown, bits: number, label: string, positive = false): bigint {
  if (
    typeof value !== "bigint"
    || value < 0n
    || value >= 1n << BigInt(bits)
    || (positive && value === 0n)
  ) {
    throw new Error(`${label} must be a ${positive ? "positive" : "nonnegative"} uint${bits} bigint`);
  }
  return value;
}

function address(value: unknown, label: string, allowZero = false): Address {
  if (typeof value !== "string") {
    throw new Error(`${label} must be an address string`);
  }
  const normalized = getAddress(value) as Address;
  if (!allowZero && normalized === ZeroAddress) {
    throw new Error(`${label} must be nonzero`);
  }
  return normalized;
}

function hash(value: unknown, label: string, allowZero = false): Hex {
  if (
    typeof value !== "string"
    || !isHexString(value, 32)
    || (!allowZero && value.toLowerCase() === ZeroHash)
  ) {
    throw new Error(`${label} must be ${allowZero ? "a" : "a nonzero"} bytes32`);
  }
  return value.toLowerCase() as Hex;
}

function bytes(value: unknown, label: string): Hex {
  if (
    typeof value !== "string"
    || !isHexString(value, true)
    || (value.length - 2) / 2 > MAX_DYNAMIC_BYTES
  ) {
    throw new Error(`${label} must be complete bounded hex bytes`);
  }
  return value.toLowerCase() as Hex;
}

function bool(value: unknown, label: string): boolean {
  if (typeof value !== "boolean") {
    throw new Error(`${label} must be boolean`);
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
  target: Address,
  iface: Interface,
  method: string,
  args: readonly unknown[],
  value = 0n,
): UnsignedCall {
  return Object.freeze({
    to: address(target, "call target"),
    data: iface.encodeFunctionData(method, args) as Hex,
    value: uint(value, 256, "call value"),
  });
}

function normalizeProof(value: readonly Hex[]): readonly Hex[] {
  if (!Array.isArray(value) || value.length > MAX_PROOF_NODES) {
    throw new Error("Primary offer proof exceeds the client bound");
  }
  return Object.freeze(
    value.map((item, index) => hash(item, `proof[${index}]`, true)),
  );
}

function normalizeSelection(
  chainId: bigint,
  adapter: Address,
  saleId: Hex,
  configuration: PrimaryOfferConfiguration,
  value: CuratedSelection,
): CuratedSelection {
  const selected = configuration.sale.contentManifestRoot !== ZeroHash;
  if (selected) {
    const normalized = normalizeCuratedSelection(value);
    if (
      !same(normalized.content.contentId, configuration.contentId)
      || !same(normalized.content.tokenDataHash, configuration.tokenDataHash)
      || !verifyCuratedContentProof(
        chainId,
        adapter,
        saleId,
        configuration.sale.contentManifestRoot,
        normalized.content,
      )
    ) {
      throw new Error("Selected primary offer content differs from the registered work");
    }
    if (!same(normalized.recipient, configuration.buyer)) {
      throw new Error("Primary offer recipient must be the immutable buyer");
    }
    return normalized;
  }
  exactKeys(
    value,
    ["content", "tokenData", "mintCommitment", "recipient", "purchaseNonce"],
    "collection-level primary offer selection",
  );
  exactKeys(
    value.content,
    ["contentId", "tokenDataHash", "proof"],
    "collection-level primary offer content",
  );
  const proof = normalizeProof(value.content.proof);
  if (
    hash(value.content.contentId, "contentId", true) !== ZeroHash
    || hash(value.content.tokenDataHash, "tokenDataHash", true) !== ZeroHash
    || proof.length !== 0
  ) {
    throw new Error("Collection-level primary offers require genuinely empty content selection");
  }
  const tokenData = bytes(value.tokenData, "tokenData");
  if ((tokenData.length - 2) / 2 > 8192) {
    throw new Error("Primary offer token data exceeds the carrier byte limit");
  }
  const recipient = address(value.recipient, "recipient");
  if (!same(recipient, configuration.buyer)) {
    throw new Error("Primary offer recipient must be the immutable buyer");
  }
  return Object.freeze({
    content: Object.freeze({
      contentId: ZeroHash as Hex,
      tokenDataHash: ZeroHash as Hex,
      proof,
    }),
    tokenData,
    mintCommitment: hash(value.mintCommitment, "mintCommitment"),
    recipient,
    purchaseNonce: uint(value.purchaseNonce, 256, "purchaseNonce", true),
  });
}

function registrationProof(
  chainId: bigint,
  adapter: Address,
  saleId: Hex,
  configuration: PrimaryOfferConfiguration,
  value: readonly Hex[],
): readonly Hex[] {
  const proof = normalizeProof(value);
  const selected = configuration.sale.contentManifestRoot !== ZeroHash;
  if (!selected) {
    if (proof.length !== 0) {
      throw new Error("Collection-level primary offer registration proof must be empty");
    }
    return proof;
  }
  if (!verifyCuratedContentProof(
    chainId,
    adapter,
    saleId,
    configuration.sale.contentManifestRoot,
    {
      contentId: configuration.contentId,
      tokenDataHash: configuration.tokenDataHash,
      proof,
    },
  )) {
    throw new Error("Primary offer registration proof differs from the manifest root");
  }
  return proof;
}

export function preparePrimaryOfferSignerConfiguration(
  adapter: Address,
  owner: Address,
  collectionId: bigint,
  signer: Address,
  signerKind: bigint,
  evidenceHash: Hex,
  enabled: boolean,
): PreparedPrimaryOfferSignerConfiguration {
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedCollectionId = uint(collectionId, 256, "collectionId", true);
  const normalizedSigner = address(signer, "signer");
  const kind = uint(signerKind, 8, "signerKind", true);
  if (kind !== 1n && kind !== 2n) {
    throw new Error("Primary offer signer kind must be EOA 1 or ERC1271 2");
  }
  const evidence = hash(evidenceHash, "evidenceHash");
  const active = bool(enabled, "enabled");
  return Object.freeze({
    adapter: normalizedAdapter,
    caller: address(owner, "owner"),
    collectionId: normalizedCollectionId,
    signer: normalizedSigner,
    signerKind: kind,
    evidenceHash: evidence,
    enabled: active,
    call: call(
      normalizedAdapter,
      offerAbi,
      "configureCollectionSigner",
      [normalizedCollectionId, normalizedSigner, kind, evidence, active],
    ),
  });
}

export function preparePrimaryOfferRegistration(
  chainId: bigint,
  adapter: Address,
  owner: Address,
  expectedNonce: bigint,
  configuration: PrimaryOfferConfiguration,
  selectedProof: readonly Hex[],
): PreparedPrimaryOfferRegistration {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedConfiguration = normalizePrimaryOfferConfiguration(configuration);
  const nonce = uint(expectedNonce, 256, "expectedNonce", true);
  const expectedSaleId = primaryOfferSaleId(
    normalizedChainId,
    normalizedAdapter,
    normalizedConfiguration.sale.collectionId,
    normalizedConfiguration.sale.phaseId,
    nonce,
  );
  const proof = registrationProof(
    normalizedChainId,
    normalizedAdapter,
    expectedSaleId,
    normalizedConfiguration,
    selectedProof,
  );
  const configurationHash = primaryOfferConfigurationHash(
    normalizedChainId,
    normalizedAdapter,
    normalizedConfiguration,
  );
  return Object.freeze({
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: address(owner, "owner"),
    expectedNonce: nonce,
    configuration: normalizedConfiguration,
    selectedProof: proof,
    expectedSaleId,
    configurationHash,
    call: call(
      normalizedAdapter,
      offerAbi,
      "registerPrimaryOffer",
      [normalizedConfiguration, proof],
    ),
  });
}

export function preparePrimaryOfferAcceptance(
  chainId: bigint,
  adapter: Address,
  core: Address,
  manager: Address,
  configuration: PrimaryOfferConfiguration,
  input: PrimaryOfferAcceptanceInput,
): PreparedPrimaryOfferAcceptance {
  exactKeys(
    input,
    [
      "offer",
      "buyerProof",
      "sellerAuthorization",
      "sellerProof",
      "selection",
      "signerDelegation",
      "executorDelegation",
      "revealFeeAllowance",
    ],
    "primary offer acceptance",
  );
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedCore = address(core, "core");
  const normalizedManager = address(manager, "manager");
  const normalizedConfiguration = normalizePrimaryOfferConfiguration(configuration);
  const saleId = input.sellerAuthorization.saleId;
  const selection = normalizeSelection(
    normalizedChainId,
    normalizedAdapter,
    saleId,
    normalizedConfiguration,
    input.selection,
  );
  const signing = primaryOfferSigningSnapshot(
    normalizedChainId,
    normalizedAdapter,
    normalizedCore,
    normalizedManager,
    normalizedConfiguration,
    saleId,
    input.offer,
    input.sellerAuthorization,
    selection.tokenData,
    selection.mintCommitment,
  );
  const buyerProof = normalizePrimaryOfferSignature(input.buyerProof);
  const sellerProof = normalizePrimaryOfferSignature(input.sellerProof);
  if (
    !same(sellerProof.authorizer, normalizedConfiguration.signer)
    || sellerProof.kind !== normalizedConfiguration.signerKind
  ) {
    throw new Error("Seller proof differs from the immutable collection signer");
  }
  const signerDelegation = normalizeCuratedDelegationWitness(input.signerDelegation);
  const executorDelegation = normalizeCuratedDelegationWitness(input.executorDelegation);
  const allowance = uint(input.revealFeeAllowance, 256, "revealFeeAllowance");
  const caller = signing.sellerAuthorization.executor;
  const expectedPurchaseId = primaryOfferPurchaseId(
    normalizedChainId,
    normalizedAdapter,
    signing.saleId,
    signing.configuration.buyer,
    selection.purchaseNonce,
  );
  const acceptance = Object.freeze({
    offer: signing.offer,
    buyerProof,
    authorization: signing.sellerAuthorization,
    sellerProof,
    selection,
    signerDelegation,
    executorDelegation,
  });
  return Object.freeze({
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    core: normalizedCore,
    manager: normalizedManager,
    caller,
    configuration: normalizedConfiguration,
    signing,
    buyerProof,
    sellerProof,
    selection,
    signerDelegation,
    executorDelegation,
    revealFeeAllowance: allowance,
    expectedPurchaseId,
    call: call(
      normalizedAdapter,
      offerAbi,
      "acceptPrimaryOffer",
      [acceptance],
      normalizedConfiguration.sale.price + allowance,
    ),
  });
}

function samePreparedRegistration(
  value: PreparedPrimaryOfferRegistration,
): PreparedPrimaryOfferRegistration {
  exactKeys(
    value,
    [
      "chainId",
      "adapter",
      "caller",
      "expectedNonce",
      "configuration",
      "selectedProof",
      "expectedSaleId",
      "configurationHash",
      "call",
    ],
    "prepared primary offer registration",
  );
  const rebuilt = preparePrimaryOfferRegistration(
    value.chainId,
    value.adapter,
    value.caller,
    value.expectedNonce,
    value.configuration,
    value.selectedProof,
  );
  if (render(value) !== render(rebuilt)) {
    throw new Error("Prepared primary offer registration differs from canonical reconstruction");
  }
  return rebuilt;
}

function samePreparedAcceptance(
  value: PreparedPrimaryOfferAcceptance,
): PreparedPrimaryOfferAcceptance {
  exactKeys(
    value,
    [
      "chainId",
      "adapter",
      "core",
      "manager",
      "caller",
      "configuration",
      "signing",
      "buyerProof",
      "sellerProof",
      "selection",
      "signerDelegation",
      "executorDelegation",
      "revealFeeAllowance",
      "expectedPurchaseId",
      "call",
    ],
    "prepared primary offer acceptance",
  );
  const rebuilt = preparePrimaryOfferAcceptance(
    value.chainId,
    value.adapter,
    value.core,
    value.manager,
    value.configuration,
    {
      offer: value.signing.offer,
      buyerProof: value.buyerProof,
      sellerAuthorization: value.signing.sellerAuthorization,
      sellerProof: value.sellerProof,
      selection: value.selection,
      signerDelegation: value.signerDelegation,
      executorDelegation: value.executorDelegation,
      revealFeeAllowance: value.revealFeeAllowance,
    },
  );
  if (render(value) !== render(rebuilt)) {
    throw new Error("Prepared primary offer acceptance differs from canonical reconstruction");
  }
  return rebuilt;
}

async function rpc(
  provider: Pick<Provider, "call">,
  target: Address,
  iface: Interface,
  method: string,
  args: readonly unknown[],
  blockTag: number,
  maximumBytes = 262_144,
): Promise<readonly unknown[]> {
  const raw = await provider.call({
    to: target,
    data: iface.encodeFunctionData(method, args),
    blockTag,
  });
  if (
    typeof raw !== "string"
    || !isHexString(raw, true)
    || (raw.length - 2) / 2 > maximumBytes
  ) {
    throw new Error(`Malformed or oversized ${method} return`);
  }
  const decoded = iface.decodeFunctionResult(method, raw);
  const canonical = iface.encodeFunctionResult(method, decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error(`Noncanonical ${method} return`);
  }
  return decoded;
}

function tuple(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object") {
    throw new Error(`Malformed ${label} tuple`);
  }
  return value as Record<string, unknown>;
}

function decodedSale(value: unknown): PrimaryOfferConfiguration["sale"] {
  const sale = tuple(value, "primary offer sale configuration");
  return {
    collectionId: BigInt(sale.collectionId as bigint),
    phaseId: hash(sale.phaseId, "phaseId"),
    price: BigInt(sale.price as bigint),
    poster: address(sale.poster, "poster"),
    startsAt: BigInt(sale.startsAt as bigint),
    endsAt: BigInt(sale.endsAt as bigint),
    mintPolicyHash: hash(sale.mintPolicyHash, "mintPolicyHash"),
    expectedPrimaryPolicyHash: hash(
      sale.expectedPrimaryPolicyHash,
      "expectedPrimaryPolicyHash",
    ),
    primaryPolicyMode: BigInt(sale.primaryPolicyMode as bigint),
    contentManifestRoot: hash(
      sale.contentManifestRoot,
      "contentManifestRoot",
      true,
    ),
  };
}

function decodedConfiguration(value: unknown): PrimaryOfferConfiguration {
  const configuration = tuple(value, "primary offer configuration");
  return normalizePrimaryOfferConfiguration({
    sale: decodedSale(configuration.sale),
    buyer: address(configuration.buyer, "buyer"),
    offerDigest: hash(configuration.offerDigest, "offerDigest"),
    contentId: hash(configuration.contentId, "contentId", true),
    tokenDataHash: hash(configuration.tokenDataHash, "tokenDataHash", true),
    signer: address(configuration.signer, "signer"),
    signerKind: BigInt(configuration.signerKind as bigint),
    signerEvidenceHash: hash(configuration.signerEvidenceHash, "signerEvidenceHash"),
    signerRevision: BigInt(configuration.signerRevision as bigint),
    signerAuthority: address(configuration.signerAuthority, "signerAuthority"),
  });
}

function decodedSigner(value: unknown): PrimaryOfferCollectionSigner {
  const signer = tuple(value, "primary offer collection signer");
  return Object.freeze({
    evidenceHash: hash(signer.evidenceHash, "signer evidenceHash"),
    revision: uint(BigInt(signer.revision as bigint), 64, "signer revision", true),
    enabled: Boolean(signer.enabled),
    authority: address(signer.authority, "signer authority"),
  });
}

function decodedRecord(value: unknown): {
  readonly sale: PrimaryOfferConfiguration["sale"];
  readonly record: PrimaryOfferSaleRecord;
} {
  const source = tuple(value, "primary offer sale record");
  const lifecycle = tuple(source.lifecycle, "primary offer lifecycle");
  const rawGate = address(source.gate, "gate", true);
  return Object.freeze({
    sale: decodedSale(source.config),
    record: Object.freeze({
      saleNonce: uint(BigInt(source.saleNonce as bigint), 256, "saleNonce", true),
      saleKind: uint(BigInt(source.saleKind as bigint), 8, "saleKind"),
      configHash: hash(source.configHash, "configHash"),
      saleCreatedAt: uint(
        BigInt(lifecycle.saleCreatedAt as bigint),
        64,
        "saleCreatedAt",
      ),
      saleAdapterRegistryRevision: uint(
        BigInt(lifecycle.saleAdapterRegistryRevision as bigint),
        64,
        "saleAdapterRegistryRevision",
      ),
      artistId: hash(source.artistId, "artistId"),
      bindingGeneration: uint(
        BigInt(source.bindingGeneration as bigint),
        64,
        "bindingGeneration",
        true,
      ),
      bindingHash: hash(source.bindingHash, "bindingHash"),
      gate: rawGate === ZeroAddress ? null : rawGate,
      gateCodeHash: hash(source.gateCodeHash, "gateCodeHash", true),
      gateConfigHash: hash(source.gateConfigHash, "gateConfigHash", true),
      manifestHash: hash(source.manifestHash, "manifestHash", true),
      contentCounterId: hash(source.contentCounterId, "contentCounterId", true),
      contentCounterConfigHash: hash(
        source.contentCounterConfigHash,
        "contentCounterConfigHash",
        true,
      ),
      status: uint(BigInt(source.status as bigint), 8, "status"),
    }),
  });
}

function assertStoredSale(
  configurationValue: unknown,
  recordValue: unknown,
  expected: {
    readonly chainId: bigint;
    readonly adapter: Address;
    readonly saleId: Hex;
    readonly configuration: PrimaryOfferConfiguration;
    readonly expectedNonce: bigint | null;
    readonly expectedStatus?: bigint;
  },
): PrimaryOfferSaleRecord {
  const configuration = decodedConfiguration(configurationValue);
  const decoded = decodedRecord(recordValue);
  const configurationHash = primaryOfferConfigurationHash(
    expected.chainId,
    expected.adapter,
    expected.configuration,
  );
  const saleId = primaryOfferSaleId(
    expected.chainId,
    expected.adapter,
    expected.configuration.sale.collectionId,
    expected.configuration.sale.phaseId,
    decoded.record.saleNonce,
  );
  const selected = expected.configuration.sale.contentManifestRoot !== ZeroHash;
  if (
    render(configuration) !== render(expected.configuration)
    || render(decoded.sale) !== render(expected.configuration.sale)
    || decoded.record.saleKind !== 6n
    || decoded.record.status !== (expected.expectedStatus ?? 1n)
    || !same(decoded.record.configHash, configurationHash)
    || !same(saleId, expected.saleId)
    || (expected.expectedNonce !== null && decoded.record.saleNonce !== expected.expectedNonce)
    || (selected && decoded.record.gate === null)
    || (!selected && (
      decoded.record.gate !== null
      || decoded.record.gateCodeHash !== ZeroHash
      || decoded.record.gateConfigHash !== ZeroHash
      || decoded.record.manifestHash !== ZeroHash
      || decoded.record.contentCounterId !== ZeroHash
      || decoded.record.contentCounterConfigHash !== ZeroHash
    ))
  ) {
    throw new Error("Stored primary offer differs from the reviewed configuration");
  }
  return decoded.record;
}

function decodedExecution(value: unknown): PrimaryOfferExecutionRecord {
  const execution = tuple(value, "primary offer execution");
  return Object.freeze({
    saleId: hash(execution.saleId, "execution saleId"),
    buyer: address(execution.buyer, "execution buyer"),
    recipient: address(execution.recipient, "execution recipient"),
    purchaseNonce: uint(
      BigInt(execution.purchaseNonce as bigint),
      256,
      "execution purchaseNonce",
      true,
    ),
    authorizationId: hash(execution.authorizationId, "authorizationId"),
    authorizationDigest: hash(execution.authorizationDigest, "authorizationDigest"),
    contentLeaf: hash(execution.contentLeaf, "contentLeaf", true),
    tokenDataHash: hash(execution.tokenDataHash, "tokenDataHash"),
    mintCommitment: hash(execution.mintCommitment, "mintCommitment"),
    price: uint(BigInt(execution.price as bigint), 256, "execution price", true),
    tokenId: uint(BigInt(execution.tokenId as bigint), 256, "execution tokenId", true),
    settlementKey: hash(execution.settlementKey, "settlementKey"),
    operationRoot: hash(execution.operationRoot, "operationRoot"),
    operationId: hash(execution.operationId, "operationId"),
  });
}

async function timestamp(
  provider: Pick<Provider, "getBlock">,
  blockTag: number,
): Promise<bigint> {
  const value = await provider.getBlock(blockTag);
  if (
    value === null
    || typeof value.timestamp !== "number"
    || !Number.isSafeInteger(value.timestamp)
    || value.timestamp < 0
  ) {
    throw new Error("Pinned primary offer block timestamp is unavailable");
  }
  return BigInt(value.timestamp);
}

async function readDependencies(
  provider: Pick<Provider, "call">,
  adapter: Address,
  blockTag: number,
): Promise<{
  readonly core: Address;
  readonly mintManager: Address;
  readonly revenueResolver: Address;
  readonly artistRegistry: Address;
  readonly moduleRegistry: Address;
}> {
  const [[core], [manager], [resolver], [artists], [modules]] = await Promise.all([
    rpc(provider, adapter, offerAbi, "core", [], blockTag, 32),
    rpc(provider, adapter, offerAbi, "mintManager", [], blockTag, 32),
    rpc(provider, adapter, offerAbi, "revenueResolver", [], blockTag, 32),
    rpc(provider, adapter, offerAbi, "artistRegistry", [], blockTag, 32),
    rpc(provider, adapter, offerAbi, "moduleRegistry", [], blockTag, 32),
  ]);
  return Object.freeze({
    core: address(core, "core"),
    mintManager: address(manager, "mintManager"),
    revenueResolver: address(resolver, "revenueResolver"),
    artistRegistry: address(artists, "artistRegistry"),
    moduleRegistry: address(modules, "moduleRegistry"),
  });
}

async function readSigner(
  provider: Pick<Provider, "call">,
  adapter: Address,
  collectionId: bigint,
  signer: Address,
  signerKind: bigint,
  blockTag: number,
): Promise<PrimaryOfferCollectionSigner> {
  const [value] = await rpc(
    provider,
    adapter,
    offerAbi,
    "collectionSigner",
    [collectionId, signer, signerKind],
    blockTag,
    128,
  );
  return decodedSigner(value);
}

function assertSigner(
  actual: PrimaryOfferCollectionSigner,
  expected: PrimaryOfferConfiguration,
): void {
  if (
    !actual.enabled
    || actual.revision !== expected.signerRevision
    || !same(actual.evidenceHash, expected.signerEvidenceHash)
    || !same(actual.authority, expected.signerAuthority)
  ) {
    throw new Error("Current collection signer differs from the immutable primary offer signer");
  }
}

async function readAndAssertSale(
  provider: Pick<Provider, "call">,
  expected: {
    readonly chainId: bigint;
    readonly adapter: Address;
    readonly saleId: Hex;
    readonly configuration: PrimaryOfferConfiguration;
    readonly expectedNonce: bigint | null;
    readonly expectedStatus?: bigint;
  },
  blockTag: number,
): Promise<PrimaryOfferSaleRecord> {
  const [[configuration], [record]] = await Promise.all([
    rpc(
      provider,
      expected.adapter,
      offerAbi,
      "primaryOfferConfiguration",
      [expected.saleId],
      blockTag,
      640,
    ),
    rpc(
      provider,
      expected.adapter,
      offerAbi,
      "saleRecord",
      [expected.saleId],
      blockTag,
      1_024,
    ),
  ]);
  return assertStoredSale(configuration, record, expected);
}

export async function readPrimaryOfferCollectionSigner(
  provider: Pick<Provider, "call">,
  adapter: Address,
  collectionId: bigint,
  signer: Address,
  signerKind: bigint,
  options: { readonly blockTag: number },
): Promise<PrimaryOfferCollectionSigner> {
  const blockTag = concreteBlock(options.blockTag);
  const kind = uint(signerKind, 8, "signerKind", true);
  if (kind !== 1n && kind !== 2n) {
    throw new Error("Primary offer signer kind must be EOA 1 or ERC1271 2");
  }
  return readSigner(
    provider,
    address(adapter, "adapter"),
    uint(collectionId, 256, "collectionId", true),
    address(signer, "signer"),
    kind,
    blockTag,
  );
}

export async function inspectPrimaryOfferSignerConfiguration(
  provider: Pick<Provider, "call">,
  preparedInput: PreparedPrimaryOfferSignerConfiguration,
  options: { readonly blockTag: number },
): Promise<{
  readonly prepared: PreparedPrimaryOfferSignerConfiguration;
  readonly current: PrimaryOfferCollectionSigner | null;
}> {
  exactKeys(
    preparedInput,
    [
      "adapter",
      "caller",
      "collectionId",
      "signer",
      "signerKind",
      "evidenceHash",
      "enabled",
      "call",
    ],
    "prepared primary offer signer configuration",
  );
  const prepared = preparePrimaryOfferSignerConfiguration(
    preparedInput.adapter,
    preparedInput.caller,
    preparedInput.collectionId,
    preparedInput.signer,
    preparedInput.signerKind,
    preparedInput.evidenceHash,
    preparedInput.enabled,
  );
  if (render(prepared) !== render(preparedInput)) {
    throw new Error("Prepared primary offer signer configuration differs from canonical reconstruction");
  }
  const blockTag = concreteBlock(options.blockTag);
  const [[owner], currentValue] = await Promise.all([
    rpc(provider, prepared.adapter, offerAbi, "owner", [], blockTag, 32),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "collectionSigner",
      [prepared.collectionId, prepared.signer, prepared.signerKind],
      blockTag,
      128,
    ),
  ]);
  if (!same(owner, prepared.caller)) {
    throw new Error("Prepared caller is not the current primary offer owner");
  }
  const raw = tuple(currentValue[0], "primary offer collection signer");
  const revision = BigInt(raw.revision as bigint);
  const current = revision === 0n ? null : decodedSigner(raw);
  return Object.freeze({ prepared, current });
}

export async function simulatePrimaryOfferSignerConfiguration(
  provider: Pick<Provider, "call">,
  preparedInput: PreparedPrimaryOfferSignerConfiguration,
  options: { readonly blockTag: number },
): Promise<void> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectPrimaryOfferSignerConfiguration(
    provider,
    preparedInput,
    { blockTag },
  );
  const raw = await provider.call({
    ...inspected.prepared.call,
    from: inspected.prepared.caller,
    blockTag,
  });
  if (raw !== "0x") {
    throw new Error("Primary offer signer configuration simulation returned unexpected data");
  }
}

export async function inspectPrimaryOfferRegistration(
  provider: Pick<Provider, "getNetwork" | "getBlock" | "call">,
  preparedInput: PreparedPrimaryOfferRegistration,
  options: { readonly blockTag: number },
): Promise<{
  readonly prepared: PreparedPrimaryOfferRegistration;
  readonly signer: PrimaryOfferCollectionSigner;
  readonly dependencies: Awaited<ReturnType<typeof readDependencies>>;
  readonly limitations: readonly string[];
}> {
  const prepared = samePreparedRegistration(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from primary offer registration coordinates");
  }
  const [[owner], [nonce], [saleId], [configurationHash], signer, dependencies, observedAt] = await Promise.all([
    rpc(provider, prepared.adapter, offerAbi, "owner", [], blockTag, 32),
    rpc(provider, prepared.adapter, offerAbi, "nextSaleNonce", [], blockTag, 32),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "saleIdFor",
      [
        6n,
        prepared.configuration.sale.collectionId,
        prepared.configuration.sale.phaseId,
        prepared.expectedNonce,
      ],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "primaryOfferConfigurationHash",
      [prepared.configuration],
      blockTag,
      32,
    ),
    readSigner(
      provider,
      prepared.adapter,
      prepared.configuration.sale.collectionId,
      prepared.configuration.signer,
      prepared.configuration.signerKind,
      blockTag,
    ),
    readDependencies(provider, prepared.adapter, blockTag),
    timestamp(provider, blockTag),
  ]);
  if (!same(owner, prepared.caller)) {
    throw new Error("Prepared caller is not the current primary offer owner");
  }
  if (BigInt(nonce as bigint) !== prepared.expectedNonce) {
    throw new Error("Live primary offer sale nonce differs from the reviewed preimage");
  }
  if (!same(saleId, prepared.expectedSaleId)) {
    throw new Error("Primary offer sale ID getter differs from local recomputation");
  }
  if (!same(configurationHash, prepared.configurationHash)) {
    throw new Error("Primary offer configuration getter differs from local recomputation");
  }
  if (observedAt >= prepared.configuration.sale.startsAt) {
    throw new Error("Primary offer registration requires a strictly future start");
  }
  assertSigner(signer, prepared.configuration);
  return Object.freeze({
    prepared,
    signer,
    dependencies,
    limitations: Object.freeze([
      "numeric block pin has no reorg hash check",
      "registration simulation does not establish current phase, gate, Artist consent or runtime identity",
    ]),
  });
}

export async function simulatePrimaryOfferRegistration(
  provider: Pick<Provider, "getNetwork" | "getBlock" | "call">,
  preparedInput: PreparedPrimaryOfferRegistration,
  options: { readonly blockTag: number },
): Promise<Hex> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectPrimaryOfferRegistration(
    provider,
    preparedInput,
    { blockTag },
  );
  const raw = await provider.call({
    ...inspected.prepared.call,
    from: inspected.prepared.caller,
    blockTag,
  });
  if (typeof raw !== "string" || !isHexString(raw, 32)) {
    throw new Error("Malformed primary offer registration simulation return");
  }
  const decoded = offerAbi.decodeFunctionResult("registerPrimaryOffer", raw);
  const canonical = offerAbi.encodeFunctionResult("registerPrimaryOffer", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical primary offer registration simulation return");
  }
  const saleId = hash(decoded[0], "registered primary offer saleId");
  if (!same(saleId, inspected.prepared.expectedSaleId)) {
    throw new Error("Primary offer registration returned an unexpected sale ID");
  }
  return saleId;
}

export async function inspectRegisteredPrimaryOffer(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedPrimaryOfferRegistration,
  options: { readonly blockTag: number },
): Promise<PrimaryOfferSaleRecord> {
  const prepared = samePreparedRegistration(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  if ((await provider.getNetwork()).chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from primary offer registration coordinates");
  }
  return readAndAssertSale(provider, {
    chainId: prepared.chainId,
    adapter: prepared.adapter,
    saleId: prepared.expectedSaleId,
    configuration: prepared.configuration,
    expectedNonce: prepared.expectedNonce,
  }, blockTag);
}

function revealFee(value: unknown): bigint {
  const quote = tuple(value, "primary offer reveal quote");
  address(quote.coordinator, "reveal coordinator");
  hash(quote.coordinatorCodeHash, "reveal coordinator code hash");
  const policy = tuple(quote.policy, "primary offer reveal policy");
  if (!Boolean(policy.declared) || BigInt(policy.requestMode as bigint) > 1n) {
    throw new Error("Missing or unsupported primary offer reveal policy");
  }
  return uint(
    BigInt(policy.revealFeePerTokenWei as bigint),
    256,
    "revealFeePerTokenWei",
  );
}

function assertDomain(
  value: readonly unknown[],
  chainId: bigint,
  adapter: Address,
): void {
  const [fields, name, version, chain, verifyingContract, salt, extensions] = value;
  if (
    fields !== "0x0f"
    || name !== "6529Stream Sales"
    || version !== "1"
    || BigInt(chain as bigint) !== chainId
    || !same(verifyingContract, adapter)
    || !same(salt, ZeroHash)
    || !Array.isArray(extensions)
    || extensions.length !== 0
  ) {
    throw new Error("Primary offer EIP-712 domain differs from the original Sales domain");
  }
}

function assertExecution(
  value: unknown,
  prepared: PreparedPrimaryOfferAcceptance,
): PrimaryOfferExecutionRecord {
  const execution = decodedExecution(value);
  if (
    !same(execution.saleId, prepared.signing.saleId)
    || !same(execution.buyer, prepared.configuration.buyer)
    || !same(execution.recipient, prepared.configuration.buyer)
    || execution.purchaseNonce !== prepared.selection.purchaseNonce
    || !same(execution.authorizationId, prepared.signing.buyerAuthorizationId)
    || !same(execution.authorizationDigest, prepared.signing.sellerReplayDigest)
    || !same(execution.contentLeaf, prepared.signing.contentSelectionHash)
    || !same(execution.tokenDataHash, keccak256(prepared.selection.tokenData))
    || !same(execution.mintCommitment, prepared.selection.mintCommitment)
    || execution.price !== prepared.configuration.sale.price
  ) {
    throw new Error("Primary offer execution differs from the reviewed acceptance");
  }
  return execution;
}

const acceptanceLimitations = Object.freeze([
  "numeric block pin has no reorg hash check",
  "read-only checks do not establish either signature, live delegation, Artist consent, gate authority, phase admission or runtime identity",
  "exact payable simulation does not establish Safe threshold authority, transaction inclusion or future-state acceptance",
]);

export async function inspectPrimaryOfferAcceptance(
  provider: Pick<Provider, "getNetwork" | "getBlock" | "call">,
  preparedInput: PreparedPrimaryOfferAcceptance,
  options: { readonly blockTag: number },
): Promise<{
  readonly prepared: PreparedPrimaryOfferAcceptance;
  readonly record: PrimaryOfferSaleRecord;
  readonly signer: PrimaryOfferCollectionSigner;
  readonly revealFeePerTokenWei: bigint;
  readonly dependencies: Awaited<ReturnType<typeof readDependencies>>;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}> {
  const prepared = samePreparedAcceptance(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  if ((await provider.getNetwork()).chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from primary offer acceptance coordinates");
  }
  const saleId = prepared.signing.saleId;
  const [record, signer, [nextNonce], [purchaseId], [offerDigest], [sellerDigest], [sellerConsumed], [sellerRevoked], [buyerUsed], [quote], binding, domain, dependencies, observedAt] = await Promise.all([
    readAndAssertSale(provider, {
      chainId: prepared.chainId,
      adapter: prepared.adapter,
      saleId,
      configuration: prepared.configuration,
      expectedNonce: null,
    }, blockTag),
    readSigner(
      provider,
      prepared.adapter,
      prepared.configuration.sale.collectionId,
      prepared.configuration.signer,
      prepared.configuration.signerKind,
      blockTag,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "nextPurchaseNonce",
      [saleId, prepared.configuration.buyer],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "purchaseIdFor",
      [saleId, prepared.configuration.buyer, prepared.selection.purchaseNonce],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "offerDigest",
      [prepared.signing.offer],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "authorizationDigest",
      [prepared.signing.sellerAuthorization],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "digestConsumed",
      [prepared.signing.sellerReplayDigest],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "digestRevoked",
      [prepared.signing.sellerReplayDigest],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.manager,
      managerAbi,
      "isAuthorizationUsed",
      [prepared.signing.buyerAuthorizationId],
      blockTag,
      32,
    ),
    rpc(provider, prepared.adapter, offerAbi, "saleRevealQuote", [saleId], blockTag, 256),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "primaryOfferAuthorizationBinding",
      [saleId],
      blockTag,
      160,
    ),
    rpc(provider, prepared.adapter, offerAbi, "eip712Domain", [], blockTag, 512),
    readDependencies(provider, prepared.adapter, blockTag),
    timestamp(provider, blockTag),
  ]);
  assertSigner(signer, prepared.configuration);
  const fee = revealFee(quote);
  const [bindingCollection, bindingPhase, bindingSigner, bindingKind, bindingConfigHash] = binding;
  if (
    BigInt(nextNonce as bigint) !== prepared.selection.purchaseNonce
    || !same(purchaseId, prepared.expectedPurchaseId)
    || !same(offerDigest, prepared.signing.offerPayload.digest)
    || !same(sellerDigest, prepared.signing.sellerReplayDigest)
    || Boolean(sellerConsumed)
    || Boolean(sellerRevoked)
    || Boolean(buyerUsed)
    || BigInt(bindingCollection as bigint) !== prepared.configuration.sale.collectionId
    || !same(bindingPhase, prepared.configuration.sale.phaseId)
    || !same(bindingSigner, prepared.configuration.signer)
    || BigInt(bindingKind as bigint) !== prepared.configuration.signerKind
    || !same(
      bindingConfigHash,
      primaryOfferConfigurationHash(
        prepared.chainId,
        prepared.adapter,
        prepared.configuration,
      ),
    )
    || !same(dependencies.core, prepared.core)
    || !same(dependencies.mintManager, prepared.manager)
  ) {
    throw new Error("Current primary offer acceptance facts differ from the reviewed packet");
  }
  assertDomain(domain, prepared.chainId, prepared.adapter);
  if (
    observedAt < prepared.configuration.sale.startsAt
    || observedAt > prepared.configuration.sale.endsAt
    || observedAt > prepared.signing.offer.deadline
    || observedAt > prepared.signing.sellerAuthorization.deadline
  ) {
    throw new Error("Primary offer acceptance is outside an inclusive signed or sale window");
  }
  if (
    prepared.revealFeeAllowance < fee
    || prepared.call.value !== prepared.configuration.sale.price + prepared.revealFeeAllowance
  ) {
    throw new Error("Primary offer attached value does not cover price and pinned reveal fee");
  }
  return Object.freeze({
    prepared,
    record,
    signer,
    revealFeePerTokenWei: fee,
    dependencies,
    checked: Object.freeze([
      "stored configuration, active sale, historical signer binding and current signer membership",
      "original buyer/seller digests, independent unused replay lanes and purchase nonce/ID",
      "original Sales domain, inclusive windows, configured dependencies and attached funding",
    ]),
    limitations: acceptanceLimitations,
  });
}

export async function simulatePrimaryOfferAcceptance(
  provider: Pick<Provider, "getNetwork" | "getBlock" | "call">,
  preparedInput: PreparedPrimaryOfferAcceptance,
  options: { readonly blockTag: number },
): Promise<PrimaryOfferExecutionRecord> {
  const blockTag = concreteBlock(options.blockTag);
  const inspected = await inspectPrimaryOfferAcceptance(
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
  if (typeof raw !== "string" || !isHexString(raw, 448)) {
    throw new Error("Malformed primary offer acceptance simulation return");
  }
  const decoded = offerAbi.decodeFunctionResult("acceptPrimaryOffer", raw);
  const canonical = offerAbi.encodeFunctionResult("acceptPrimaryOffer", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical primary offer acceptance simulation return");
  }
  return assertExecution(decoded[0], prepared);
}

export async function inspectCompletedPrimaryOffer(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedPrimaryOfferAcceptance,
  options: { readonly blockTag: number },
): Promise<{
  readonly record: PrimaryOfferSaleRecord;
  readonly execution: PrimaryOfferExecutionRecord;
  readonly buyerAuthorizationUsed: true;
  readonly sellerDigestConsumed: true;
  readonly sellerDigestRevoked: false;
}> {
  const prepared = samePreparedAcceptance(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  if ((await provider.getNetwork()).chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from completed primary offer coordinates");
  }
  const [record, [executionValue], [buyerUsed], [sellerConsumed], [sellerRevoked]] = await Promise.all([
    readAndAssertSale(provider, {
      chainId: prepared.chainId,
      adapter: prepared.adapter,
      saleId: prepared.signing.saleId,
      configuration: prepared.configuration,
      expectedNonce: null,
      expectedStatus: 4n,
    }, blockTag),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "executionRecord",
      [prepared.expectedPurchaseId],
      blockTag,
      448,
    ),
    rpc(
      provider,
      prepared.manager,
      managerAbi,
      "isAuthorizationUsed",
      [prepared.signing.buyerAuthorizationId],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "digestConsumed",
      [prepared.signing.sellerReplayDigest],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "digestRevoked",
      [prepared.signing.sellerReplayDigest],
      blockTag,
      32,
    ),
  ]);
  const execution = assertExecution(executionValue, prepared);
  if (!Boolean(buyerUsed) || !Boolean(sellerConsumed) || Boolean(sellerRevoked)) {
    throw new Error("Completed primary offer replay loci are not both consumed");
  }
  return Object.freeze({
    record,
    execution,
    buyerAuthorizationUsed: true,
    sellerDigestConsumed: true,
    sellerDigestRevoked: false,
  });
}

export function preparePrimaryOfferBuyerRevocation(
  chainId: bigint,
  adapter: Address,
  manager: Address,
  ledger: Address,
  caller: Address,
  offer: PrimaryOfferSaleOffer,
  buyerKind: bigint,
  revocationSignature: Hex,
): PreparedPrimaryOfferBuyerRevocation {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedManager = address(manager, "manager");
  const normalizedLedger = address(ledger, "ledger");
  const normalizedOffer = normalizePrimaryOfferSaleOffer(offer);
  const kind = uint(buyerKind, 8, "buyerKind", true);
  if (kind !== 1n && kind !== 2n) {
    throw new Error("Buyer revocation kind must be EOA 1 or ERC1271 2");
  }
  const signature = bytes(revocationSignature, "buyer revocation signature");
  const authorizationId = primaryOfferBuyerAuthorizationId(
    normalizedChainId,
    normalizedAdapter,
    normalizedOffer,
  );
  const payload = primaryOfferBuyerRevocationPayload(
    normalizedChainId,
    normalizedAdapter,
    normalizedManager,
    normalizedLedger,
    authorizationId,
  );
  return Object.freeze({
    chainId: normalizedChainId,
    manager: normalizedManager,
    ledger: normalizedLedger,
    caller: address(caller, "caller"),
    offer: normalizedOffer,
    buyerKind: kind,
    revocationSignature: signature,
    authorizationId,
    payload,
    call: call(
      normalizedManager,
      managerAbi,
      "voidMintOffer",
      [normalizedOffer, kind, signature],
    ),
  });
}

export function preparePrimaryOfferSellerRevocation(
  chainId: bigint,
  adapter: Address,
  caller: Address,
  configuration: PrimaryOfferConfiguration,
  authorization: PrimaryOfferSellerAuthorization,
  proof: PrimaryOfferSignature,
): PreparedPrimaryOfferSellerRevocation {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedConfiguration = normalizePrimaryOfferConfiguration(configuration);
  const normalizedAuthorization = normalizePrimaryOfferSellerAuthorization(authorization);
  const normalizedProof = normalizePrimaryOfferSignature(proof);
  if (
    normalizedAuthorization.chainId !== normalizedChainId
    || !same(normalizedAuthorization.saleAdapter, normalizedAdapter)
    || normalizedAuthorization.collectionId !== normalizedConfiguration.sale.collectionId
    || !same(normalizedAuthorization.phaseId, normalizedConfiguration.sale.phaseId)
    || !same(normalizedAuthorization.payer, normalizedConfiguration.buyer)
    || normalizedAuthorization.unitPrice !== normalizedConfiguration.sale.price
    || normalizedAuthorization.primaryPolicyMode !== normalizedConfiguration.sale.primaryPolicyMode
    || !same(
      normalizedAuthorization.expectedPrimaryPolicyHash,
      normalizedConfiguration.sale.expectedPrimaryPolicyHash,
    )
    || !same(normalizedAuthorization.policyHash, normalizedConfiguration.sale.mintPolicyHash)
    || !same(normalizedProof.authorizer, normalizedConfiguration.signer)
    || normalizedProof.kind !== normalizedConfiguration.signerKind
  ) {
    throw new Error("Seller revocation differs from the immutable primary offer binding");
  }
  const authorizationDigest = primaryOfferSellerReplayDigest(
    normalizedChainId,
    normalizedAdapter,
    normalizedAuthorization,
  );
  const payload = primaryOfferSellerRevocationPayload(
    normalizedChainId,
    normalizedAdapter,
    normalizedProof.authorizer,
    authorizationDigest,
  );
  return Object.freeze({
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: address(caller, "caller"),
    configuration: normalizedConfiguration,
    authorization: normalizedAuthorization,
    proof: normalizedProof,
    authorizationDigest,
    payload,
    call: call(
      normalizedAdapter,
      offerAbi,
      "revokeAuthorization",
      [normalizedAuthorization, normalizedProof],
    ),
  });
}

function sameBuyerRevocation(
  value: PreparedPrimaryOfferBuyerRevocation,
): PreparedPrimaryOfferBuyerRevocation {
  exactKeys(
    value,
    [
      "chainId",
      "manager",
      "ledger",
      "caller",
      "offer",
      "buyerKind",
      "revocationSignature",
      "authorizationId",
      "payload",
      "call",
    ],
    "prepared buyer offer revocation",
  );
  const rebuilt = preparePrimaryOfferBuyerRevocation(
    value.chainId,
    value.offer.saleAdapter,
    value.manager,
    value.ledger,
    value.caller,
    value.offer,
    value.buyerKind,
    value.revocationSignature,
  );
  if (render(value) !== render(rebuilt)) {
    throw new Error("Prepared buyer offer revocation differs from canonical reconstruction");
  }
  return rebuilt;
}

function sameSellerRevocation(
  value: PreparedPrimaryOfferSellerRevocation,
): PreparedPrimaryOfferSellerRevocation {
  exactKeys(
    value,
    [
      "chainId",
      "adapter",
      "caller",
      "configuration",
      "authorization",
      "proof",
      "authorizationDigest",
      "payload",
      "call",
    ],
    "prepared seller authorization revocation",
  );
  const rebuilt = preparePrimaryOfferSellerRevocation(
    value.chainId,
    value.adapter,
    value.caller,
    value.configuration,
    value.authorization,
    value.proof,
  );
  if (render(value) !== render(rebuilt)) {
    throw new Error("Prepared seller authorization revocation differs from canonical reconstruction");
  }
  return rebuilt;
}

export async function inspectPrimaryOfferBuyerRevocation(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedPrimaryOfferBuyerRevocation,
  options: { readonly blockTag: number },
): Promise<PreparedPrimaryOfferBuyerRevocation> {
  const prepared = sameBuyerRevocation(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  if ((await provider.getNetwork()).chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from buyer offer revocation coordinates");
  }
  const [[authorizationId], [used], [managerCore], [managerLedger]] = await Promise.all([
    rpc(
      provider,
      prepared.manager,
      managerAbi,
      "mintOfferAuthorizationId",
      [prepared.offer],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.manager,
      managerAbi,
      "isAuthorizationUsed",
      [prepared.authorizationId],
      blockTag,
      32,
    ),
    rpc(provider, prepared.manager, managerAbi, "core", [], blockTag, 32),
    rpc(provider, prepared.manager, managerAbi, "mintLedger", [], blockTag, 32),
  ]);
  if (
    !same(authorizationId, prepared.authorizationId)
    || Boolean(used)
    || !same(managerCore, prepared.offer.core)
    || !same(managerLedger, prepared.ledger)
  ) {
    throw new Error("Buyer offer authorization is already used or differs from the historical payload");
  }
  return prepared;
}

export async function simulatePrimaryOfferBuyerRevocation(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedPrimaryOfferBuyerRevocation,
  options: { readonly blockTag: number },
): Promise<Hex> {
  const blockTag = concreteBlock(options.blockTag);
  const prepared = await inspectPrimaryOfferBuyerRevocation(
    provider,
    preparedInput,
    { blockTag },
  );
  const raw = await provider.call({
    ...prepared.call,
    from: prepared.caller,
    blockTag,
  });
  if (typeof raw !== "string" || !isHexString(raw, 32)) {
    throw new Error("Malformed buyer offer revocation simulation return");
  }
  const decoded = managerAbi.decodeFunctionResult("voidMintOffer", raw);
  const canonical = managerAbi.encodeFunctionResult("voidMintOffer", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical buyer offer revocation simulation return");
  }
  const authorizationId = hash(decoded[0], "voided buyer authorizationId");
  if (!same(authorizationId, prepared.authorizationId)) {
    throw new Error("Buyer offer revocation returned an unexpected authorization ID");
  }
  return authorizationId;
}

export async function inspectPrimaryOfferSellerRevocation(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedPrimaryOfferSellerRevocation,
  options: { readonly blockTag: number },
): Promise<PreparedPrimaryOfferSellerRevocation> {
  const prepared = sameSellerRevocation(preparedInput);
  const blockTag = concreteBlock(options.blockTag);
  if ((await provider.getNetwork()).chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from seller authorization revocation coordinates");
  }
  const saleId = prepared.authorization.saleId;
  const [[digest], [consumed], binding, [manager]] = await Promise.all([
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "authorizationDigest",
      [prepared.authorization],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "digestConsumed",
      [prepared.authorizationDigest],
      blockTag,
      32,
    ),
    rpc(
      provider,
      prepared.adapter,
      offerAbi,
      "primaryOfferAuthorizationBinding",
      [saleId],
      blockTag,
      160,
    ),
    rpc(provider, prepared.adapter, offerAbi, "mintManager", [], blockTag, 32),
  ]);
  const [collectionId, phaseId, signer, signerKind, configurationHash] = binding;
  if (
    !same(digest, prepared.authorizationDigest)
    || Boolean(consumed)
    || !same(manager, prepared.authorization.mintManager)
    || BigInt(collectionId as bigint) !== prepared.configuration.sale.collectionId
    || !same(phaseId, prepared.configuration.sale.phaseId)
    || !same(signer, prepared.configuration.signer)
    || BigInt(signerKind as bigint) !== prepared.configuration.signerKind
    || !same(
      configurationHash,
      primaryOfferConfigurationHash(
        prepared.chainId,
        prepared.adapter,
        prepared.configuration,
      ),
    )
  ) {
    throw new Error("Historical seller authorization binding differs from the reviewed revocation");
  }
  return prepared;
}

export async function simulatePrimaryOfferSellerRevocation(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedPrimaryOfferSellerRevocation,
  options: { readonly blockTag: number },
): Promise<void> {
  const blockTag = concreteBlock(options.blockTag);
  const prepared = await inspectPrimaryOfferSellerRevocation(
    provider,
    preparedInput,
    { blockTag },
  );
  const raw = await provider.call({
    ...prepared.call,
    from: prepared.caller,
    blockTag,
  });
  if (raw !== "0x") {
    throw new Error("Seller authorization revocation simulation returned unexpected data");
  }
}

export async function readPrimaryOfferBuyerAuthorizationUsed(
  provider: Pick<Provider, "call">,
  manager: Address,
  authorizationId: Hex,
  options: { readonly blockTag: number },
): Promise<boolean> {
  const blockTag = concreteBlock(options.blockTag);
  const [used] = await rpc(
    provider,
    address(manager, "manager"),
    managerAbi,
    "isAuthorizationUsed",
    [hash(authorizationId, "authorizationId")],
    blockTag,
    32,
  );
  return Boolean(used);
}

export async function readPrimaryOfferSellerReplay(
  provider: Pick<Provider, "call">,
  adapter: Address,
  authorizationDigest: Hex,
  options: { readonly blockTag: number },
): Promise<{ readonly consumed: boolean; readonly revoked: boolean }> {
  const blockTag = concreteBlock(options.blockTag);
  const target = address(adapter, "adapter");
  const digest = hash(authorizationDigest, "authorizationDigest");
  const [[consumed], [revoked]] = await Promise.all([
    rpc(provider, target, offerAbi, "digestConsumed", [digest], blockTag, 32),
    rpc(provider, target, offerAbi, "digestRevoked", [digest], blockTag, 32),
  ]);
  return Object.freeze({ consumed: Boolean(consumed), revoked: Boolean(revoked) });
}

function action(
  kind: PreparedPrimaryOfferAction["kind"],
  target: Address,
  caller: Address,
  method: string,
  args: readonly unknown[],
): PreparedPrimaryOfferAction {
  const normalizedTarget = address(target, "target");
  return Object.freeze({
    kind,
    target: normalizedTarget,
    caller: address(caller, "caller"),
    call: call(normalizedTarget, offerAbi, method, args),
  });
}

function refundRecipient(adapter: Address, recipient: Address): Address {
  const normalized = address(recipient, "refund recipient");
  if (same(normalized, adapter)) {
    throw new Error("Primary offer refund recipient cannot be the adapter");
  }
  return normalized;
}

export function preparePrimaryOfferRefundClaim(
  adapter: Address,
  buyer: Address,
  saleId: Hex,
  recipient: Address,
): PreparedPrimaryOfferAction {
  const target = address(adapter, "adapter");
  return action(
    "refund",
    target,
    buyer,
    "claimRefund",
    [hash(saleId, "saleId"), refundRecipient(target, recipient)],
  );
}

export function preparePrimaryOfferDelegatedRefundClaim(
  adapter: Address,
  delegate: Address,
  saleId: Hex,
  buyer: Address,
  witness: CuratedDelegationWitness,
): PreparedPrimaryOfferAction {
  return action(
    "delegated-refund",
    adapter,
    delegate,
    "claimRefundFor",
    [
      hash(saleId, "saleId"),
      address(buyer, "buyer"),
      normalizeCuratedDelegationWitness(witness),
    ],
  );
}

export function preparePrimaryOfferCancel(
  adapter: Address,
  owner: Address,
  saleId: Hex,
): PreparedPrimaryOfferAction {
  return action(
    "cancel",
    adapter,
    owner,
    "cancelSale",
    [hash(saleId, "saleId")],
  );
}

export function preparePrimaryOfferExpire(
  adapter: Address,
  caller: Address,
  saleId: Hex,
): PreparedPrimaryOfferAction {
  return action(
    "expire",
    adapter,
    caller,
    "expirePrimaryOffer",
    [hash(saleId, "saleId")],
  );
}

export function preparePrimaryOfferContestSync(
  adapter: Address,
  caller: Address,
  collectionId: bigint,
): PreparedPrimaryOfferAction {
  return action(
    "contest-sync",
    adapter,
    caller,
    "syncCollectionContest",
    [uint(collectionId, 256, "collectionId", true)],
  );
}

export async function readPrimaryOfferRefundCredit(
  provider: Pick<Provider, "call">,
  adapter: Address,
  saleId: Hex,
  buyer: Address,
  options: { readonly blockTag: number },
): Promise<bigint> {
  const blockTag = concreteBlock(options.blockTag);
  const [amount] = await rpc(
    provider,
    address(adapter, "adapter"),
    offerAbi,
    "refundableBalance",
    [hash(saleId, "saleId"), address(buyer, "buyer")],
    blockTag,
    32,
  );
  return uint(BigInt(amount as bigint), 256, "primary offer refund credit");
}

export async function readPrimaryOfferExecution(
  provider: Pick<Provider, "call">,
  adapter: Address,
  purchaseId: Hex,
  options: { readonly blockTag: number },
): Promise<PrimaryOfferExecutionRecord> {
  const blockTag = concreteBlock(options.blockTag);
  const [execution] = await rpc(
    provider,
    address(adapter, "adapter"),
    offerAbi,
    "executionRecord",
    [hash(purchaseId, "purchaseId")],
    blockTag,
    448,
  );
  return decodedExecution(execution);
}
