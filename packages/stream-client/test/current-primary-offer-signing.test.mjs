import test from "node:test";
import assert from "node:assert/strict";
import {
  AbiCoder,
  TypedDataEncoder,
  ZeroAddress,
  ZeroHash,
  id,
  keccak256,
} from "ethers";
import {
  primaryOfferBatchHashes,
  primaryOfferBuyerAuthorizationId,
  primaryOfferBuyerRevocationPayload,
  primaryOfferConfigurationHash,
  primaryOfferPurchaseId,
  primaryOfferSaleId,
  primaryOfferSaleOfferPayload,
  primaryOfferSellerAuthorizationPayload,
  primaryOfferSellerReplayDigest,
  primaryOfferSellerRevocationPayload,
  primaryOfferSigningSnapshot,
} from "../dist/current-primary-offer-signing.js";
import { curatedContentLeaf } from "../dist/current-curated-content.js";

const coder = AbiCoder.defaultAbiCoder();
const A = value => `0x${BigInt(value).toString(16).padStart(40, "0")}`;
const chainId = (1n << 200n) + 31337n;
const adapter = A(1), core = A(2), manager = A(3), ledger = A(4), buyer = A(5);
const executor = A(6), seller = A(7), poster = A(8), authority = A(9);
const collectionId = (1n << 180n) + 44n, phaseId = id("offer phase"), saleNonce = 9n;
const saleId = primaryOfferSaleId(chainId, adapter, collectionId, phaseId, saleNonce);
const contentId = id("selected work"), tokenData = "0x123456", tokenDataHash = keccak256(tokenData);
const leaf = curatedContentLeaf(chainId, adapter, saleId, contentId, tokenDataHash);
const mintCommitment = id("mint commitment"), price = (1n << 190n) + 100n;
const domain = { name: "6529Stream Sales", version: "1", chainId, verifyingContract: adapter };
const offerFields = [
  { name: "chainId", type: "uint256" }, { name: "saleAdapter", type: "address" },
  { name: "core", type: "address" }, { name: "collectionId", type: "uint256" },
  { name: "tokenId", type: "uint256" }, { name: "contentSelectionHash", type: "bytes32" },
  { name: "buyer", type: "address" }, { name: "asset", type: "address" },
  { name: "price", type: "uint256" }, { name: "nonce", type: "bytes32" },
  { name: "deadline", type: "uint64" }, { name: "finalizeBy", type: "uint64" },
];
const sellerFields = [
  ["chainId", "uint256"], ["saleAdapter", "address"], ["mintManager", "address"],
  ["collectionId", "uint256"], ["phaseId", "bytes32"], ["saleId", "bytes32"],
  ["saleKind", "uint8"], ["revenueClass", "bytes32"], ["expectedPrimaryPolicyHash", "bytes32"],
  ["primaryPolicyMode", "uint8"], ["initialRecipientsHash", "bytes32"],
  ["beneficiariesHash", "bytes32"], ["tokenDataArrayHash", "bytes32"],
  ["mintCommitmentsHash", "bytes32"], ["payer", "address"], ["executor", "address"],
  ["asset", "address"], ["unitPrice", "uint256"], ["quantity", "uint256"],
  ["contentSelectionHash", "bytes32"], ["policyHash", "bytes32"], ["nonce", "bytes32"],
  ["deadline", "uint64"], ["finalizeBy", "uint64"],
].map(([name, type]) => ({ name, type }));

function literalBatch(raw = tokenData) {
  return {
    initialRecipientsHash: keccak256(coder.encode(["bytes32", "address[]"],
      [id("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), [adapter]])),
    beneficiariesHash: keccak256(coder.encode(["bytes32", "address[]"],
      [id("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), [buyer]])),
    tokenDataArrayHash: keccak256(coder.encode(["bytes32", "bytes[]"],
      [id("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), [raw]])),
    mintCommitmentsHash: keccak256(coder.encode(["bytes32", "bytes32[]"],
      [id("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), [mintCommitment]])),
  };
}
function offer(contentSelectionHash = leaf) {
  return { chainId, saleAdapter: adapter, core, collectionId, tokenId: 0n, contentSelectionHash,
    buyer, asset: ZeroAddress, price, nonce: id("buyer offer nonce"), deadline: 9_000n, finalizeBy: 0n };
}
function sale(root = leaf) {
  return { collectionId, phaseId, price, poster, startsAt: 1_000n, endsAt: 8_000n,
    mintPolicyHash: id("mint policy"), expectedPrimaryPolicyHash: id("primary policy"),
    primaryPolicyMode: 0n, contentManifestRoot: root };
}
function configuration(selected = true, offerDigest = TypedDataEncoder.hash(domain, { SaleOffer: offerFields }, offer(selected ? leaf : ZeroHash))) {
  return { sale: sale(selected ? leaf : ZeroHash), buyer, offerDigest,
    contentId: selected ? contentId : ZeroHash, tokenDataHash: selected ? tokenDataHash : ZeroHash,
    signer: seller, signerKind: 2n, signerEvidenceHash: id("seller evidence"),
    signerRevision: 3n, signerAuthority: authority };
}
function authorization(contentSelectionHash = leaf, raw = tokenData) {
  return { chainId, saleAdapter: adapter, mintManager: manager, collectionId, phaseId, saleId,
    saleKind: 6n, revenueClass: id("PRIMARY_SALE"), expectedPrimaryPolicyHash: sale().expectedPrimaryPolicyHash,
    primaryPolicyMode: 0n, ...literalBatch(raw), payer: buyer, executor, asset: ZeroAddress,
    unitPrice: price, quantity: 1n, contentSelectionHash, policyHash: sale().mintPolicyHash,
    nonce: id("seller authorization nonce"), deadline: 7_000n, finalizeBy: 0n };
}

test("literal full SaleOffer digest is wrapped once into the durable buyer TICKET", () => {
  const message = offer();
  const expectedDigest = TypedDataEncoder.hash(domain, { SaleOffer: offerFields }, message);
  const expectedId = keccak256(coder.encode(["bytes32", "bytes32"],
    [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), expectedDigest]));
  const payload = primaryOfferSaleOfferPayload(chainId, adapter, message);
  assert.equal(payload.digest, expectedDigest);
  assert.equal(primaryOfferBuyerAuthorizationId(chainId, adapter, message), expectedId);
  assert.notEqual(expectedDigest, expectedId);
  assert.equal(payload.message.price, price);
});

test("literal seller digest remains a distinct full 24-field carrier replay key", () => {
  const message = authorization();
  const expected = TypedDataEncoder.hash(domain, { SaleAuthorization: sellerFields }, message);
  const payload = primaryOfferSellerAuthorizationPayload(chainId, adapter, message);
  assert.equal(payload.digest, expected);
  assert.equal(primaryOfferSellerReplayDigest(chainId, adapter, message), expected);
  assert.notEqual(expected, primaryOfferBuyerAuthorizationId(chainId, adapter, offer()));
  assert.deepEqual(primaryOfferBatchHashes(adapter, buyer, tokenData, mintCommitment), literalBatch());
});

test("buyer and seller revocations retain distinct original Sales structs", () => {
  const offerId = primaryOfferBuyerAuthorizationId(chainId, adapter, offer());
  const sellerDigest = primaryOfferSellerReplayDigest(chainId, adapter, authorization());
  const buyerPayload = primaryOfferBuyerRevocationPayload(chainId, adapter, manager, ledger, offerId);
  const sellerPayload = primaryOfferSellerRevocationPayload(chainId, adapter, seller, sellerDigest);
  const expectedBuyer = TypedDataEncoder.hash(domain, { MintTicketRevocation: [
    { name: "chainId", type: "uint256" }, { name: "manager", type: "address" },
    { name: "ledger", type: "address" }, { name: "authorizationId", type: "bytes32" },
  ] }, buyerPayload.message);
  const expectedSeller = TypedDataEncoder.hash(domain, { SaleAuthorizationRevocation: [
    { name: "chainId", type: "uint256" }, { name: "saleAdapter", type: "address" },
    { name: "authorizer", type: "address" }, { name: "authorizationDigest", type: "bytes32" },
  ] }, sellerPayload.message);
  assert.equal(buyerPayload.digest, expectedBuyer);
  assert.equal(sellerPayload.digest, expectedSeller);
  assert.equal(buyerPayload.primaryType, "MintTicketRevocation");
  assert.equal(sellerPayload.primaryType, "SaleAuthorizationRevocation");
});

test("selected snapshot binds leaf while collection route remains genuinely unselected", () => {
  const selected = primaryOfferSigningSnapshot(chainId, adapter, core, manager,
    configuration(), saleId, offer(), authorization(), tokenData, mintCommitment);
  assert.equal(selected.selected, true);
  assert.equal(selected.contentSelectionHash, leaf);
  assert.equal(selected.configuration.offerDigest, selected.offerPayload.digest);

  const unselectedOffer = offer(ZeroHash), unselectedAuthorization = authorization(ZeroHash, "0xabcdef");
  const unselected = primaryOfferSigningSnapshot(chainId, adapter, core, manager,
    configuration(false), saleId, unselectedOffer, unselectedAuthorization, "0xabcdef", mintCommitment);
  assert.equal(unselected.selected, false);
  assert.equal(unselected.contentSelectionHash, ZeroHash);
  assert.notEqual(unselected.batchHashes.tokenDataArrayHash, selected.batchHashes.tokenDataArrayHash);
  assert.throws(() => primaryOfferSigningSnapshot(chainId, adapter, core, manager,
    configuration(false), saleId, offer(leaf), unselectedAuthorization, "0xabcdef", mintCommitment), /differ/);
  assert.throws(() => primaryOfferSigningSnapshot(chainId, adapter, core, manager,
    configuration(), saleId, offer(), authorization(leaf, "0xabcdef"), "0xabcdef", mintCommitment), /differ/);
});

test("normalization snapshots nested inputs and rejects later mutation or schema widening", () => {
  const mutableOffer = offer(), mutableAuthorization = authorization(), mutableConfiguration = configuration();
  const snapshot = primaryOfferSigningSnapshot(chainId, adapter, core, manager,
    mutableConfiguration, saleId, mutableOffer, mutableAuthorization, tokenData, mintCommitment);
  mutableOffer.price = 1n;
  mutableAuthorization.initialRecipientsHash = ZeroHash;
  mutableConfiguration.sale.price = 2n;
  assert.equal(snapshot.offer.price, price);
  assert.equal(snapshot.sellerAuthorization.initialRecipientsHash, literalBatch().initialRecipientsHash);
  assert.equal(snapshot.configuration.sale.price, price);
  assert.throws(() => primaryOfferSaleOfferPayload(chainId, adapter, { ...offer(), extra: 1n }), /unknown/);
  assert.throws(() => primaryOfferSaleOfferPayload(chainId, adapter, { ...offer(), tokenId: 1n }), /tokenId/);
  assert.throws(() => primaryOfferSellerAuthorizationPayload(chainId, adapter,
    { ...authorization(), saleKind: 5n }), /kind 6/);
  assert.equal(primaryOfferPurchaseId(chainId, adapter, saleId, buyer, 1n).length, 66);
  assert.equal(primaryOfferConfigurationHash(chainId, adapter, configuration()).length, 66);
});
