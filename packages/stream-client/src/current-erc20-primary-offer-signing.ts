import { AbiCoder, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { buildSigningPayload } from "./signing-payload.js";
import { paymentIntentTypedData, type PaymentIntent, type SigningPayload } from "./signing.js";
import {
  curatedContentContextHash, curatedContentLeaf, normalizeCuratedDelegationWitness,
  type CuratedContentSelection, type CuratedDelegationWitness,
} from "./current-curated-content.js";
import {
  normalizePrimaryOfferConfiguration, normalizePrimaryOfferSaleOffer,
  normalizePrimaryOfferSellerAuthorization, normalizePrimaryOfferSignature,
  primaryOfferSaleId, primaryOfferSaleOfferPayload, primaryOfferSellerAuthorizationPayload,
  type PrimaryOfferBatchHashes, type PrimaryOfferSaleOffer,
  type PrimaryOfferSellerAuthorization, type PrimaryOfferSignature,
} from "./current-primary-offer-signing.js";

/** Frozen flat contract Configuration. Asset and sole payment adapter are explicit. */
export interface ERC20PrimaryOfferConfiguration {
  readonly collectionId: bigint; readonly phaseId: Hex; readonly asset: Address;
  readonly paymentAdapter: Address; readonly price: bigint; readonly poster: Address;
  readonly startsAt: bigint; readonly endsAt: bigint; readonly mintPolicyHash: Hex;
  readonly expectedPrimaryPolicyHash: Hex; readonly primaryPolicyMode: bigint;
  readonly contentManifestRoot: Hex; readonly buyer: Address; readonly offerDigest: Hex;
  readonly contentId: Hex; readonly tokenDataHash: Hex; readonly signer: Address;
  readonly signerKind: bigint; readonly signerEvidenceHash: Hex;
  readonly signerRevision: bigint; readonly signerAuthority: Address;
}
export interface ERC20PrimaryOfferSelection {
  readonly content: CuratedContentSelection; readonly tokenData: Hex;
  readonly mintCommitment: Hex; readonly executionNonce: bigint;
}
/** Exact ABI shape; an offer signer witness never authorizes payment. */
export interface ERC20PrimaryOfferAcceptance {
  readonly offer: PrimaryOfferSaleOffer; readonly buyerProof: PrimaryOfferSignature;
  readonly authorization: PrimaryOfferSellerAuthorization; readonly sellerProof: PrimaryOfferSignature;
  readonly selection: ERC20PrimaryOfferSelection;
  readonly signerDelegation: CuratedDelegationWitness; readonly executorDelegation: CuratedDelegationWitness;
}
export interface ERC20PrimaryOfferSigningSnapshot {
  readonly selected: boolean; readonly configuration: ERC20PrimaryOfferConfiguration; readonly saleId: Hex;
  readonly offer: PrimaryOfferSaleOffer; readonly sellerAuthorization: PrimaryOfferSellerAuthorization;
  readonly batchHashes: PrimaryOfferBatchHashes; readonly contentSelectionHash: Hex; readonly contextHash: Hex;
  readonly offerPayload: SigningPayload<PrimaryOfferSaleOffer>;
  readonly sellerPayload: SigningPayload<PrimaryOfferSellerAuthorization>;
  readonly buyerAuthorizationId: Hex; readonly sellerReplayDigest: Hex;
}

const coder = AbiCoder.defaultAbiCoder();
const configurationFields = ["collectionId", "phaseId", "asset", "paymentAdapter", "price", "poster",
  "startsAt", "endsAt", "mintPolicyHash", "expectedPrimaryPolicyHash", "primaryPolicyMode",
  "contentManifestRoot", "buyer", "offerDigest", "contentId", "tokenDataHash", "signer", "signerKind",
  "signerEvidenceHash", "signerRevision", "signerAuthority"] as const;
const configurationTuple = "tuple(uint256 collectionId,bytes32 phaseId,address asset,address paymentAdapter,uint256 price,address poster,uint64 startsAt,uint64 endsAt,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 contentManifestRoot,address buyer,bytes32 offerDigest,bytes32 contentId,bytes32 tokenDataHash,address signer,uint8 signerKind,bytes32 signerEvidenceHash,uint64 signerRevision,address signerAuthority)";
const offerTuple = "tuple(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const authorizationTuple = "tuple(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const signatureTuple = "tuple(address authorizer,uint8 kind,bytes signature)";
const witnessTuple = "tuple(bool walletWide,uint256 index)";
const selectionTuple = "tuple(tuple(bytes32 contentId,bytes32 tokenDataHash,bytes32[] proof) content,bytes tokenData,bytes32 mintCommitment,uint256 executionNonce)";
const acceptanceTuple = `tuple(${offerTuple} offer,${signatureTuple} buyerProof,${authorizationTuple} authorization,${signatureTuple} sellerProof,${selectionTuple} selection,${witnessTuple} signerDelegation,${witnessTuple} executorDelegation)`;

function keys(value: unknown, fields: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...fields].sort().join(",")) throw Error(`${label} contains missing or unknown properties`);
}
function address(value: unknown, label: string): Address {
  if (typeof value !== "string") throw Error(`${label} must be an address`);
  const out = getAddress(value) as Address;
  if (out === ZeroAddress) throw Error(`${label} must be nonzero`);
  return out;
}
function uint(value: unknown, bits: number, label: string, positive = false): bigint {
  if (typeof value !== "bigint" || value < (positive ? 1n : 0n) || value >= 1n << BigInt(bits)) throw Error(`${label} must fit uint${bits} as bigint`);
  return value;
}
function hash(value: unknown, label: string, zero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (!zero && value.toLowerCase() === ZeroHash)) throw Error(`${label} must be ${zero ? "" : "nonzero "}bytes32`);
  return value.toLowerCase() as Hex;
}
function same(left: string, right: string): boolean { return left.toLowerCase() === right.toLowerCase(); }

/** Reuses the permanent twelve-field validation, changing only the required asset profile. */
export function normalizeERC20PrimaryOfferSaleOffer(value: PrimaryOfferSaleOffer): PrimaryOfferSaleOffer {
  const asset = address(value?.asset, "ERC20 offer asset");
  return Object.freeze({ ...normalizePrimaryOfferSaleOffer({ ...value, asset: ZeroAddress as Address }), asset });
}
/** Original 24 fields: strict policy, one token, kind 6, PRIMARY_SALE and finalizeBy zero. */
export function normalizeERC20PrimaryOfferSellerAuthorization(value: PrimaryOfferSellerAuthorization): PrimaryOfferSellerAuthorization {
  const asset = address(value?.asset, "ERC20 authorization asset");
  return Object.freeze({ ...normalizePrimaryOfferSellerAuthorization({ ...value, asset: ZeroAddress as Address }), asset });
}
export function normalizeERC20PrimaryOfferConfiguration(value: ERC20PrimaryOfferConfiguration): ERC20PrimaryOfferConfiguration {
  keys(value, configurationFields, "ERC20 offer configuration");
  const legacy = normalizePrimaryOfferConfiguration({
    sale: { collectionId: value.collectionId, phaseId: value.phaseId, price: value.price, poster: value.poster,
      startsAt: value.startsAt, endsAt: value.endsAt, mintPolicyHash: value.mintPolicyHash,
      expectedPrimaryPolicyHash: value.expectedPrimaryPolicyHash, primaryPolicyMode: value.primaryPolicyMode,
      contentManifestRoot: value.contentManifestRoot },
    buyer: value.buyer, offerDigest: value.offerDigest, contentId: value.contentId, tokenDataHash: value.tokenDataHash,
    signer: value.signer, signerKind: value.signerKind, signerEvidenceHash: value.signerEvidenceHash,
    signerRevision: value.signerRevision, signerAuthority: value.signerAuthority,
  });
  const { sale, ...signer } = legacy;
  return Object.freeze({ ...sale, asset: address(value.asset, "ERC20 asset"),
    paymentAdapter: address(value.paymentAdapter, "ERC20 payment adapter"), ...signer });
}
export const erc20PrimaryOfferSaleId = primaryOfferSaleId;
export function erc20PrimaryOfferConfigurationHash(chainId: bigint, adapter: Address, input: ERC20PrimaryOfferConfiguration): Hex {
  const c = normalizeERC20PrimaryOfferConfiguration(input), host = address(adapter, "adapter");
  if (same(c.buyer, host) || same(c.poster, host)) throw Error("Buyer and poster cannot be the ERC20 offer carrier");
  return keccak256(coder.encode(["bytes32", "uint256", "address", configurationTuple],
    [id("6529STREAM_ERC20_PRIMARY_OFFER_CONFIG_V1"), uint(chainId, 256, "chainId", true), host, c])) as Hex;
}
export function erc20PrimaryOfferSaleOfferPayload(chainId: bigint, adapter: Address, value: PrimaryOfferSaleOffer): SigningPayload<PrimaryOfferSaleOffer> {
  const message = normalizeERC20PrimaryOfferSaleOffer(value);
  const original = primaryOfferSaleOfferPayload(chainId, adapter, { ...message, asset: ZeroAddress as Address });
  return buildSigningPayload(chainId, adapter, "6529Stream Sales", "SaleOffer", original.types.SaleOffer!, message);
}
export function erc20PrimaryOfferSellerAuthorizationPayload(chainId: bigint, adapter: Address, value: PrimaryOfferSellerAuthorization): SigningPayload<PrimaryOfferSellerAuthorization> {
  const message = normalizeERC20PrimaryOfferSellerAuthorization(value);
  const original = primaryOfferSellerAuthorizationPayload(chainId, adapter, { ...message, asset: ZeroAddress as Address });
  return buildSigningPayload(chainId, adapter, "6529Stream Sales", "SaleAuthorization", original.types.SaleAuthorization!, message);
}
export function erc20PrimaryOfferBuyerAuthorizationId(chainId: bigint, adapter: Address, value: PrimaryOfferSaleOffer): Hex {
  return keccak256(coder.encode(["bytes32", "bytes32"],
    [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), erc20PrimaryOfferSaleOfferPayload(chainId, adapter, value).digest])) as Hex;
}
export function erc20PrimaryOfferSellerReplayDigest(chainId: bigint, adapter: Address, value: PrimaryOfferSellerAuthorization): Hex {
  return erc20PrimaryOfferSellerAuthorizationPayload(chainId, adapter, value).digest;
}
export function erc20PrimaryOfferBatchHashes(buyer: Address, tokenData: Hex, mintCommitment: Hex): PrimaryOfferBatchHashes {
  const account = address(buyer, "buyer");
  if (!isHexString(tokenData, true) || (tokenData.length - 2) / 2 > 8192) throw Error("Token data exceeds the 8192-byte carrier bound");
  const commitment = hash(mintCommitment, "mint commitment");
  return Object.freeze({
    initialRecipientsHash: keccak256(coder.encode(["bytes32", "address[]"], [id("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), [account]])) as Hex,
    beneficiariesHash: keccak256(coder.encode(["bytes32", "address[]"], [id("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), [account]])) as Hex,
    tokenDataArrayHash: keccak256(coder.encode(["bytes32", "bytes[]"], [id("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), [tokenData]])) as Hex,
    mintCommitmentsHash: keccak256(coder.encode(["bytes32", "bytes32[]"], [id("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), [commitment]])) as Hex,
  });
}
/** Pure signed-field agreement; current PROFILE rights, zero reveal fee and signatures require live inspection. */
export function erc20PrimaryOfferSigningSnapshot(
  chainId: bigint, adapter: Address, core: Address, manager: Address, configurationInput: ERC20PrimaryOfferConfiguration,
  saleIdInput: Hex, offerInput: PrimaryOfferSaleOffer, authorizationInput: PrimaryOfferSellerAuthorization,
  tokenData: Hex, mintCommitment: Hex,
): ERC20PrimaryOfferSigningSnapshot {
  const host = address(adapter, "adapter"), c = normalizeERC20PrimaryOfferConfiguration(configurationInput);
  const expectedCore = address(core, "core"), expectedManager = address(manager, "manager");
  const saleId = hash(saleIdInput, "saleId"), offer = normalizeERC20PrimaryOfferSaleOffer(offerInput);
  const authorization = normalizeERC20PrimaryOfferSellerAuthorization(authorizationInput);
  const selected = c.contentManifestRoot !== ZeroHash;
  const leaf = selected ? curatedContentLeaf(chainId, host, saleId, c.contentId, c.tokenDataHash) : ZeroHash as Hex;
  const batchHashes = erc20PrimaryOfferBatchHashes(c.buyer, tokenData, mintCommitment);
  const offerPayload = erc20PrimaryOfferSaleOfferPayload(chainId, host, offer);
  const sellerPayload = erc20PrimaryOfferSellerAuthorizationPayload(chainId, host, authorization);
  if (same(c.buyer, host) || same(c.poster, host) || (selected && !same(keccak256(tokenData), c.tokenDataHash))
    || !same(c.offerDigest, offerPayload.digest) || !same(offer.core, expectedCore)
    || offer.collectionId !== c.collectionId || !same(offer.buyer, c.buyer) || !same(offer.asset, c.asset)
    || offer.price !== c.price || !same(offer.contentSelectionHash, leaf) || offer.deadline < c.startsAt
    || !same(authorization.mintManager, expectedManager) || authorization.collectionId !== c.collectionId
    || !same(authorization.phaseId, c.phaseId) || !same(authorization.saleId, saleId)
    || !same(authorization.expectedPrimaryPolicyHash, c.expectedPrimaryPolicyHash)
    || !same(authorization.policyHash, c.mintPolicyHash) || !same(authorization.payer, c.buyer)
    || !same(authorization.asset, c.asset) || authorization.unitPrice !== c.price
    || !same(authorization.contentSelectionHash, leaf) || authorization.deadline < c.startsAt
    || authorization.deadline > c.endsAt
    || Object.keys(batchHashes).some(key => !same(authorization[key as keyof PrimaryOfferBatchHashes], batchHashes[key as keyof PrimaryOfferBatchHashes]))) {
    throw Error("ERC20 offer, seller authorization, immutable configuration or buyer-bound arrays differ");
  }
  return Object.freeze({ selected, configuration: c, saleId, offer, sellerAuthorization: authorization, batchHashes,
    contentSelectionHash: leaf, contextHash: selected ? curatedContentContextHash(chainId, host, saleId, c.contentId) : sellerPayload.digest,
    offerPayload, sellerPayload, buyerAuthorizationId: erc20PrimaryOfferBuyerAuthorizationId(chainId, host, offer),
    sellerReplayDigest: sellerPayload.digest });
}

export function normalizeERC20PrimaryOfferSelection(value: ERC20PrimaryOfferSelection): ERC20PrimaryOfferSelection {
  keys(value, ["content", "tokenData", "mintCommitment", "executionNonce"], "ERC20 selection");
  keys(value.content, ["contentId", "tokenDataHash", "proof"], "ERC20 content selection");
  if (!Array.isArray(value.content.proof) || value.content.proof.length > 256) throw Error("Content proof exceeds the 256-node client bound");
  if (!isHexString(value.tokenData, true) || (value.tokenData.length - 2) / 2 > 8192) throw Error("Token data exceeds the 8192-byte carrier bound");
  return Object.freeze({ content: Object.freeze({ contentId: hash(value.content.contentId, "contentId", true),
    tokenDataHash: hash(value.content.tokenDataHash, "tokenDataHash", true),
    proof: Object.freeze(value.content.proof.map(node => hash(node, "proof node", true))) }),
  tokenData: value.tokenData.toLowerCase() as Hex, mintCommitment: hash(value.mintCommitment, "mint commitment"),
  executionNonce: uint(value.executionNonce, 256, "execution nonce", true) });
}
/** Strict encoding snapshot only. Selected proof, configured signer and live delegates are checked by the workflow. */
export function normalizeERC20PrimaryOfferAcceptance(value: ERC20PrimaryOfferAcceptance): ERC20PrimaryOfferAcceptance {
  keys(value, ["offer", "buyerProof", "authorization", "sellerProof", "selection", "signerDelegation", "executorDelegation"], "ERC20 acceptance");
  return Object.freeze({ offer: normalizeERC20PrimaryOfferSaleOffer(value.offer), buyerProof: normalizePrimaryOfferSignature(value.buyerProof),
    authorization: normalizeERC20PrimaryOfferSellerAuthorization(value.authorization), sellerProof: normalizePrimaryOfferSignature(value.sellerProof),
    selection: normalizeERC20PrimaryOfferSelection(value.selection), signerDelegation: normalizeCuratedDelegationWitness(value.signerDelegation),
    executorDelegation: normalizeCuratedDelegationWitness(value.executorDelegation) });
}
/** Canonical abi.encode(Acceptance), used unchanged as contract 20's execution data. */
export function encodeERC20PrimaryOfferAcceptance(value: ERC20PrimaryOfferAcceptance): Hex {
  return coder.encode([acceptanceTuple], [normalizeERC20PrimaryOfferAcceptance(value)]) as Hex;
}

export function normalizeERC20PrimaryOfferPaymentIntent(value: PaymentIntent): PaymentIntent {
  keys(value, ["payer", "asset", "maxAmount", "saleRef", "expectedPrimaryPolicyHash", "nonce", "deadline"], "PaymentIntent");
  return Object.freeze({ payer: address(value.payer, "payment payer"), asset: address(value.asset, "payment asset"),
    maxAmount: uint(value.maxAmount, 256, "payment maxAmount", true), saleRef: hash(value.saleRef, "payment saleRef"),
    expectedPrimaryPolicyHash: hash(value.expectedPrimaryPolicyHash, "payment policy hash"),
    nonce: hash(value.nonce, "payment nonce", true), deadline: uint(value.deadline, 64, "payment deadline") });
}
/** Original payer-owned PaymentIntent, verified by the configured contract 20, never by the offer carrier. */
export function erc20PrimaryOfferPaymentIntentPayload(
  chainId: bigint, configuration: ERC20PrimaryOfferConfiguration, saleId: Hex, value: PaymentIntent,
): SigningPayload<PaymentIntent> {
  const c = normalizeERC20PrimaryOfferConfiguration(configuration), intent = normalizeERC20PrimaryOfferPaymentIntent(value);
  if (!same(intent.payer, c.buyer) || !same(intent.asset, c.asset) || intent.maxAmount < c.price
    || !same(intent.saleRef, hash(saleId, "saleId")) || !same(intent.expectedPrimaryPolicyHash, c.expectedPrimaryPolicyHash)) {
    throw Error("PaymentIntent must bind the buyer, asset, price bound, original saleId and primary policy");
  }
  return paymentIntentTypedData(chainId, c.paymentAdapter, intent);
}
