import {
  AbiCoder,
  ZeroAddress,
  ZeroHash,
  getAddress,
  id,
  isHexString,
  keccak256,
} from "ethers";
import type { TypedDataField } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";
import {
  curatedContentLeaf,
  type CuratedSaleConfiguration,
} from "./current-curated-content.js";

/** Original permanent 12-field Sales offer. Primary mint offers keep tokenId zero. */
export interface PrimaryOfferSaleOffer {
  readonly chainId: bigint;
  readonly saleAdapter: Address;
  readonly core: Address;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly contentSelectionHash: Hex;
  readonly buyer: Address;
  readonly asset: Address;
  readonly price: bigint;
  readonly nonce: Hex;
  readonly deadline: bigint;
  readonly finalizeBy: bigint;
}

/** Original permanent 24-field seller authorization. */
export interface PrimaryOfferSellerAuthorization {
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

export interface PrimaryOfferConfiguration {
  readonly sale: CuratedSaleConfiguration;
  readonly buyer: Address;
  readonly offerDigest: Hex;
  readonly contentId: Hex;
  readonly tokenDataHash: Hex;
  readonly signer: Address;
  readonly signerKind: bigint;
  readonly signerEvidenceHash: Hex;
  readonly signerRevision: bigint;
  readonly signerAuthority: Address;
}

export interface PrimaryOfferSignature {
  readonly authorizer: Address;
  readonly kind: bigint;
  readonly signature: Hex;
}

export interface PrimaryOfferBatchHashes {
  readonly initialRecipientsHash: Hex;
  readonly beneficiariesHash: Hex;
  readonly tokenDataArrayHash: Hex;
  readonly mintCommitmentsHash: Hex;
}

export interface PrimaryOfferBuyerMintTicketRevocation {
  readonly chainId: bigint;
  readonly manager: Address;
  readonly ledger: Address;
  readonly authorizationId: Hex;
}

export interface PrimaryOfferSellerAuthorizationRevocation {
  readonly chainId: bigint;
  readonly saleAdapter: Address;
  readonly authorizer: Address;
  readonly authorizationDigest: Hex;
}

export interface PrimaryOfferSigningSnapshot {
  readonly selected: boolean;
  readonly configuration: PrimaryOfferConfiguration;
  readonly saleId: Hex;
  readonly offer: PrimaryOfferSaleOffer;
  readonly sellerAuthorization: PrimaryOfferSellerAuthorization;
  readonly batchHashes: PrimaryOfferBatchHashes;
  readonly contentSelectionHash: Hex;
  readonly offerPayload: SigningPayload<PrimaryOfferSaleOffer>;
  readonly sellerPayload: SigningPayload<PrimaryOfferSellerAuthorization>;
  readonly buyerAuthorizationId: Hex;
  readonly sellerReplayDigest: Hex;
}

const coder = AbiCoder.defaultAbiCoder();
const MAX_TOKEN_DATA_BYTES = 8192;
const MAX_SIGNATURE_BYTES = 65_536;
const PRIMARY_SALE = id("PRIMARY_SALE") as Hex;
const SALE_ID_DOMAIN = id("6529STREAM_SALE_V1") as Hex;
const PURCHASE_ID_DOMAIN = id("6529STREAM_SALE_PURCHASE_V1") as Hex;
const CONFIG_DOMAIN = id("6529STREAM_NATIVE_PRIMARY_OFFER_CONFIG_V1") as Hex;
const TICKET_DOMAIN = id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1") as Hex;
const RECIPIENTS_DOMAIN = id("6529STREAM_MINT_BATCH_RECIPIENTS_V1") as Hex;
const BENEFICIARIES_DOMAIN = id("6529STREAM_MINT_BATCH_BENEFICIARIES_V1") as Hex;
const TOKEN_DATA_DOMAIN = id("6529STREAM_MINT_BATCH_TOKEN_DATA_V1") as Hex;
const COMMITMENTS_DOMAIN = id("6529STREAM_MINT_BATCH_COMMITMENTS_V1") as Hex;
const saleConfigTuple = "tuple(uint256 collectionId,bytes32 phaseId,uint256 price,address poster,uint64 startsAt,uint64 endsAt,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 contentManifestRoot)";
const configurationTuple = `tuple(${saleConfigTuple} sale,address buyer,bytes32 offerDigest,bytes32 contentId,bytes32 tokenDataHash,address signer,uint8 signerKind,bytes32 signerEvidenceHash,uint64 signerRevision,address signerAuthority)`;

const offerFields = [
  { name: "chainId", type: "uint256" },
  { name: "saleAdapter", type: "address" },
  { name: "core", type: "address" },
  { name: "collectionId", type: "uint256" },
  { name: "tokenId", type: "uint256" },
  { name: "contentSelectionHash", type: "bytes32" },
  { name: "buyer", type: "address" },
  { name: "asset", type: "address" },
  { name: "price", type: "uint256" },
  { name: "nonce", type: "bytes32" },
  { name: "deadline", type: "uint64" },
  { name: "finalizeBy", type: "uint64" },
] as const satisfies readonly TypedDataField[];

const sellerFields = [
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
] as const satisfies readonly TypedDataField[];

const buyerRevocationFields = [
  { name: "chainId", type: "uint256" },
  { name: "manager", type: "address" },
  { name: "ledger", type: "address" },
  { name: "authorizationId", type: "bytes32" },
] as const satisfies readonly TypedDataField[];

const sellerRevocationFields = [
  { name: "chainId", type: "uint256" },
  { name: "saleAdapter", type: "address" },
  { name: "authorizer", type: "address" },
  { name: "authorizationDigest", type: "bytes32" },
] as const satisfies readonly TypedDataField[];

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
    || (!allowZero && value.toLowerCase() === ZeroHash)) {
    throw new Error(`${label} must be ${allowZero ? "a" : "a nonzero"} bytes32`);
  }
  return value.toLowerCase() as Hex;
}

function bytes(value: unknown, label: string, maximum: number): Hex {
  if (typeof value !== "string" || !isHexString(value, true)
    || (value.length - 2) / 2 > maximum) {
    throw new Error(`${label} must be complete hex bytes no longer than ${maximum} bytes`);
  }
  return value.toLowerCase() as Hex;
}

function same(left: string, right: string): boolean {
  return left.toLowerCase() === right.toLowerCase();
}

function normalizeSaleConfiguration(value: CuratedSaleConfiguration): CuratedSaleConfiguration {
  exactKeys(value, ["collectionId", "phaseId", "price", "poster", "startsAt", "endsAt",
    "mintPolicyHash", "expectedPrimaryPolicyHash", "primaryPolicyMode", "contentManifestRoot"],
  "primary offer sale configuration");
  const startsAt = uint(value.startsAt, 64, "sale startsAt");
  const endsAt = uint(value.endsAt, 64, "sale endsAt");
  const primaryPolicyMode = uint(value.primaryPolicyMode, 8, "sale primaryPolicyMode");
  if (endsAt <= startsAt || primaryPolicyMode !== 0n) {
    throw new Error("Primary offer sale requires an increasing window and strict policy mode zero");
  }
  return Object.freeze({
    collectionId: uint(value.collectionId, 256, "sale collectionId", true),
    phaseId: hash(value.phaseId, "sale phaseId"),
    price: uint(value.price, 256, "sale price", true),
    poster: address(value.poster, "sale poster"),
    startsAt,
    endsAt,
    mintPolicyHash: hash(value.mintPolicyHash, "sale mintPolicyHash"),
    expectedPrimaryPolicyHash: hash(value.expectedPrimaryPolicyHash, "sale expectedPrimaryPolicyHash"),
    primaryPolicyMode,
    contentManifestRoot: hash(value.contentManifestRoot, "sale contentManifestRoot", true),
  });
}

export function normalizePrimaryOfferSaleOffer(value: PrimaryOfferSaleOffer): PrimaryOfferSaleOffer {
  exactKeys(value, offerFields.map(field => field.name), "primary SaleOffer");
  const result = Object.freeze({
    chainId: uint(value.chainId, 256, "offer chainId", true),
    saleAdapter: address(value.saleAdapter, "offer saleAdapter"),
    core: address(value.core, "offer core"),
    collectionId: uint(value.collectionId, 256, "offer collectionId", true),
    tokenId: uint(value.tokenId, 256, "offer tokenId"),
    contentSelectionHash: hash(value.contentSelectionHash, "offer contentSelectionHash", true),
    buyer: address(value.buyer, "offer buyer"),
    asset: address(value.asset, "offer asset", true),
    price: uint(value.price, 256, "offer price", true),
    nonce: hash(value.nonce, "offer nonce"),
    deadline: uint(value.deadline, 64, "offer deadline", true),
    finalizeBy: uint(value.finalizeBy, 64, "offer finalizeBy"),
  });
  if (result.tokenId !== 0n || result.asset !== ZeroAddress || result.finalizeBy !== 0n) {
    throw new Error("Primary native SaleOffer requires tokenId, asset and finalizeBy zero");
  }
  return result;
}

export function normalizePrimaryOfferSellerAuthorization(
  value: PrimaryOfferSellerAuthorization,
): PrimaryOfferSellerAuthorization {
  exactKeys(value, sellerFields.map(field => field.name), "primary seller authorization");
  const result = Object.freeze({
    chainId: uint(value.chainId, 256, "authorization chainId", true),
    saleAdapter: address(value.saleAdapter, "authorization saleAdapter"),
    mintManager: address(value.mintManager, "authorization mintManager"),
    collectionId: uint(value.collectionId, 256, "authorization collectionId", true),
    phaseId: hash(value.phaseId, "authorization phaseId"),
    saleId: hash(value.saleId, "authorization saleId"),
    saleKind: uint(value.saleKind, 8, "authorization saleKind"),
    revenueClass: hash(value.revenueClass, "authorization revenueClass"),
    expectedPrimaryPolicyHash: hash(value.expectedPrimaryPolicyHash, "authorization expectedPrimaryPolicyHash"),
    primaryPolicyMode: uint(value.primaryPolicyMode, 8, "authorization primaryPolicyMode"),
    initialRecipientsHash: hash(value.initialRecipientsHash, "authorization initialRecipientsHash"),
    beneficiariesHash: hash(value.beneficiariesHash, "authorization beneficiariesHash"),
    tokenDataArrayHash: hash(value.tokenDataArrayHash, "authorization tokenDataArrayHash"),
    mintCommitmentsHash: hash(value.mintCommitmentsHash, "authorization mintCommitmentsHash"),
    payer: address(value.payer, "authorization payer"),
    executor: address(value.executor, "authorization executor"),
    asset: address(value.asset, "authorization asset", true),
    unitPrice: uint(value.unitPrice, 256, "authorization unitPrice", true),
    quantity: uint(value.quantity, 256, "authorization quantity", true),
    contentSelectionHash: hash(value.contentSelectionHash, "authorization contentSelectionHash", true),
    policyHash: hash(value.policyHash, "authorization policyHash"),
    nonce: hash(value.nonce, "authorization nonce"),
    deadline: uint(value.deadline, 64, "authorization deadline", true),
    finalizeBy: uint(value.finalizeBy, 64, "authorization finalizeBy"),
  });
  if (result.saleKind !== 6n || !same(result.revenueClass, PRIMARY_SALE)
    || result.primaryPolicyMode !== 0n || result.asset !== ZeroAddress
    || result.quantity !== 1n || result.finalizeBy !== 0n) {
    throw new Error("Seller authorization is not strict native one-token OFFER_SALE kind 6");
  }
  return result;
}

export function normalizePrimaryOfferConfiguration(value: PrimaryOfferConfiguration): PrimaryOfferConfiguration {
  exactKeys(value, ["sale", "buyer", "offerDigest", "contentId", "tokenDataHash", "signer",
    "signerKind", "signerEvidenceHash", "signerRevision", "signerAuthority"], "primary offer configuration");
  const sale = normalizeSaleConfiguration(value.sale);
  const signerKind = uint(value.signerKind, 8, "signerKind", true);
  if (signerKind !== 1n && signerKind !== 2n) throw new Error("signerKind must be EOA 1 or ERC1271 2");
  const contentId = hash(value.contentId, "contentId", true);
  const tokenDataHash = hash(value.tokenDataHash, "tokenDataHash", true);
  const selected = sale.contentManifestRoot !== ZeroHash;
  if (selected ? tokenDataHash === ZeroHash : contentId !== ZeroHash || tokenDataHash !== ZeroHash) {
    throw new Error("Primary offer configuration mixes selected and collection-level content fields");
  }
  return Object.freeze({
    sale,
    buyer: address(value.buyer, "buyer"),
    offerDigest: hash(value.offerDigest, "offerDigest"),
    contentId,
    tokenDataHash,
    signer: address(value.signer, "signer"),
    signerKind,
    signerEvidenceHash: hash(value.signerEvidenceHash, "signerEvidenceHash"),
    signerRevision: uint(value.signerRevision, 64, "signerRevision", true),
    signerAuthority: address(value.signerAuthority, "signerAuthority"),
  });
}

export function normalizePrimaryOfferSignature(value: PrimaryOfferSignature): PrimaryOfferSignature {
  exactKeys(value, ["authorizer", "kind", "signature"], "primary offer signature");
  const kind = uint(value.kind, 8, "signature kind", true);
  if (kind !== 1n && kind !== 2n) throw new Error("signature kind must be EOA 1 or ERC1271 2");
  return Object.freeze({
    authorizer: address(value.authorizer, "signature authorizer"),
    kind,
    signature: bytes(value.signature, "signature", MAX_SIGNATURE_BYTES),
  });
}

export function primaryOfferSaleId(
  chainId: bigint,
  adapter: Address,
  collectionId: bigint,
  phaseId: Hex,
  nonce: bigint,
): Hex {
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [SALE_ID_DOMAIN, uint(chainId, 256, "chainId", true), address(adapter, "adapter"), 6n,
      uint(collectionId, 256, "collectionId", true), hash(phaseId, "phaseId"),
      uint(nonce, 256, "sale nonce", true)],
  )) as Hex;
}

export function primaryOfferPurchaseId(
  chainId: bigint,
  adapter: Address,
  saleId: Hex,
  buyer: Address,
  purchaseNonce: bigint,
): Hex {
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", "bytes32", "address", "uint256"],
    [PURCHASE_ID_DOMAIN, uint(chainId, 256, "chainId", true), address(adapter, "adapter"),
      hash(saleId, "saleId"), address(buyer, "buyer"),
      uint(purchaseNonce, 256, "purchase nonce", true)],
  )) as Hex;
}

export function primaryOfferConfigurationHash(
  chainId: bigint,
  adapter: Address,
  configuration: PrimaryOfferConfiguration,
): Hex {
  const host = address(adapter, "adapter");
  const normalized = normalizePrimaryOfferConfiguration(configuration);
  if (same(normalized.buyer, host) || same(normalized.sale.poster, host)) {
    throw new Error("Primary offer buyer and poster cannot be the carrier");
  }
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", configurationTuple],
    [CONFIG_DOMAIN, uint(chainId, 256, "chainId", true), host, normalized],
  )) as Hex;
}

export function primaryOfferBatchHashes(
  adapter: Address,
  buyer: Address,
  tokenData: Hex,
  mintCommitment: Hex,
): PrimaryOfferBatchHashes {
  const host = address(adapter, "adapter");
  const account = address(buyer, "buyer");
  const rawTokenData = bytes(tokenData, "tokenData", MAX_TOKEN_DATA_BYTES);
  const commitment = hash(mintCommitment, "mintCommitment");
  return Object.freeze({
    initialRecipientsHash: keccak256(coder.encode(
      ["bytes32", "address[]"], [RECIPIENTS_DOMAIN, [host]],
    )) as Hex,
    beneficiariesHash: keccak256(coder.encode(
      ["bytes32", "address[]"], [BENEFICIARIES_DOMAIN, [account]],
    )) as Hex,
    tokenDataArrayHash: keccak256(coder.encode(
      ["bytes32", "bytes[]"], [TOKEN_DATA_DOMAIN, [rawTokenData]],
    )) as Hex,
    mintCommitmentsHash: keccak256(coder.encode(
      ["bytes32", "bytes32[]"], [COMMITMENTS_DOMAIN, [commitment]],
    )) as Hex,
  });
}

export function primaryOfferSaleOfferPayload(
  chainId: bigint,
  adapter: Address,
  offer: PrimaryOfferSaleOffer,
): SigningPayload<PrimaryOfferSaleOffer> {
  const normalized = normalizePrimaryOfferSaleOffer(offer);
  const expectedChain = uint(chainId, 256, "chainId", true);
  const host = address(adapter, "adapter");
  if (normalized.chainId !== expectedChain || !same(normalized.saleAdapter, host)) {
    throw new Error("SaleOffer coordinates differ from the Sales domain");
  }
  return buildSigningPayload(
    expectedChain,
    host,
    "6529Stream Sales",
    "SaleOffer",
    offerFields,
    normalized,
  );
}

export function primaryOfferSellerAuthorizationPayload(
  chainId: bigint,
  adapter: Address,
  authorization: PrimaryOfferSellerAuthorization,
): SigningPayload<PrimaryOfferSellerAuthorization> {
  const normalized = normalizePrimaryOfferSellerAuthorization(authorization);
  const expectedChain = uint(chainId, 256, "chainId", true);
  const host = address(adapter, "adapter");
  if (normalized.chainId !== expectedChain || !same(normalized.saleAdapter, host)) {
    throw new Error("Seller authorization coordinates differ from the Sales domain");
  }
  return buildSigningPayload(
    expectedChain,
    host,
    "6529Stream Sales",
    "SaleAuthorization",
    sellerFields,
    normalized,
  );
}

export function primaryOfferBuyerAuthorizationId(
  chainId: bigint,
  adapter: Address,
  offer: PrimaryOfferSaleOffer,
): Hex {
  const offerDigest = primaryOfferSaleOfferPayload(chainId, adapter, offer).digest;
  return keccak256(coder.encode(["bytes32", "bytes32"], [TICKET_DOMAIN, offerDigest])) as Hex;
}

export function primaryOfferSellerReplayDigest(
  chainId: bigint,
  adapter: Address,
  authorization: PrimaryOfferSellerAuthorization,
): Hex {
  return primaryOfferSellerAuthorizationPayload(chainId, adapter, authorization).digest;
}

export function primaryOfferBuyerRevocationPayload(
  chainId: bigint,
  adapter: Address,
  manager: Address,
  ledger: Address,
  authorizationId: Hex,
): SigningPayload<PrimaryOfferBuyerMintTicketRevocation> {
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
    buyerRevocationFields,
    message,
  );
}

export function primaryOfferSellerRevocationPayload(
  chainId: bigint,
  adapter: Address,
  authorizer: Address,
  authorizationDigest: Hex,
): SigningPayload<PrimaryOfferSellerAuthorizationRevocation> {
  const host = address(adapter, "adapter");
  const message = Object.freeze({
    chainId: uint(chainId, 256, "chainId", true),
    saleAdapter: host,
    authorizer: address(authorizer, "seller authorizer"),
    authorizationDigest: hash(authorizationDigest, "seller authorization digest"),
  });
  return buildSigningPayload(
    message.chainId,
    host,
    "6529Stream Sales",
    "SaleAuthorizationRevocation",
    sellerRevocationFields,
    message,
  );
}

/**
 * Normalize and cross-check one complete offer-signing packet. This performs no
 * signature validation, current-state admission, replay read, or transaction simulation.
 */
export function primaryOfferSigningSnapshot(
  chainId: bigint,
  adapter: Address,
  core: Address,
  manager: Address,
  configurationInput: PrimaryOfferConfiguration,
  saleIdInput: Hex,
  offerInput: PrimaryOfferSaleOffer,
  sellerAuthorizationInput: PrimaryOfferSellerAuthorization,
  tokenDataInput: Hex,
  mintCommitmentInput: Hex,
): PrimaryOfferSigningSnapshot {
  const expectedChain = uint(chainId, 256, "chainId", true);
  const host = address(adapter, "adapter");
  const expectedCore = address(core, "core");
  const expectedManager = address(manager, "manager");
  const configuration = normalizePrimaryOfferConfiguration(configurationInput);
  const saleId = hash(saleIdInput, "saleId");
  const offer = normalizePrimaryOfferSaleOffer(offerInput);
  const sellerAuthorization = normalizePrimaryOfferSellerAuthorization(sellerAuthorizationInput);
  const tokenData = bytes(tokenDataInput, "tokenData", MAX_TOKEN_DATA_BYTES);
  const mintCommitment = hash(mintCommitmentInput, "mintCommitment");
  const selected = configuration.sale.contentManifestRoot !== ZeroHash;
  const contentSelectionHash = selected
    ? curatedContentLeaf(expectedChain, host, saleId, configuration.contentId, configuration.tokenDataHash)
    : ZeroHash as Hex;
  const batchHashes = primaryOfferBatchHashes(host, configuration.buyer, tokenData, mintCommitment);
  const offerPayload = primaryOfferSaleOfferPayload(expectedChain, host, offer);
  const sellerPayload = primaryOfferSellerAuthorizationPayload(expectedChain, host, sellerAuthorization);
  if (same(configuration.buyer, host) || same(configuration.sale.poster, host)
    || (selected && !same(keccak256(tokenData), configuration.tokenDataHash))
    || !same(configuration.offerDigest, offerPayload.digest)
    || offer.chainId !== expectedChain || !same(offer.saleAdapter, host) || !same(offer.core, expectedCore)
    || offer.collectionId !== configuration.sale.collectionId
    || !same(offer.contentSelectionHash, contentSelectionHash)
    || !same(offer.buyer, configuration.buyer) || offer.price !== configuration.sale.price
    || sellerAuthorization.chainId !== expectedChain || !same(sellerAuthorization.saleAdapter, host)
    || !same(sellerAuthorization.mintManager, expectedManager)
    || sellerAuthorization.collectionId !== configuration.sale.collectionId
    || !same(sellerAuthorization.phaseId, configuration.sale.phaseId)
    || !same(sellerAuthorization.saleId, saleId)
    || !same(sellerAuthorization.expectedPrimaryPolicyHash, configuration.sale.expectedPrimaryPolicyHash)
    || !same(sellerAuthorization.initialRecipientsHash, batchHashes.initialRecipientsHash)
    || !same(sellerAuthorization.beneficiariesHash, batchHashes.beneficiariesHash)
    || !same(sellerAuthorization.tokenDataArrayHash, batchHashes.tokenDataArrayHash)
    || !same(sellerAuthorization.mintCommitmentsHash, batchHashes.mintCommitmentsHash)
    || !same(sellerAuthorization.payer, configuration.buyer)
    || sellerAuthorization.unitPrice !== configuration.sale.price
    || !same(sellerAuthorization.contentSelectionHash, contentSelectionHash)
    || !same(sellerAuthorization.policyHash, configuration.sale.mintPolicyHash)
    || offer.deadline < configuration.sale.startsAt
    || sellerAuthorization.deadline < configuration.sale.startsAt
    || sellerAuthorization.deadline > configuration.sale.endsAt) {
    throw new Error("Offer, seller authorization, immutable configuration or actual arrays differ");
  }
  return Object.freeze({
    selected,
    configuration,
    saleId,
    offer,
    sellerAuthorization,
    batchHashes,
    contentSelectionHash,
    offerPayload,
    sellerPayload,
    buyerAuthorizationId: keccak256(coder.encode(
      ["bytes32", "bytes32"], [TICKET_DOMAIN, offerPayload.digest],
    )) as Hex,
    sellerReplayDigest: sellerPayload.digest,
  });
}
