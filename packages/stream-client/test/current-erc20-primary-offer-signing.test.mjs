import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import {
  encodeERC20PrimaryOfferAcceptance, erc20PrimaryOfferBatchHashes,
  erc20PrimaryOfferBuyerAuthorizationId, erc20PrimaryOfferConfigurationHash,
  erc20PrimaryOfferPaymentIntentPayload, erc20PrimaryOfferSaleId,
  erc20PrimaryOfferSaleOfferPayload, erc20PrimaryOfferSellerAuthorizationPayload,
  erc20PrimaryOfferSellerReplayDigest, erc20PrimaryOfferSigningSnapshot,
  normalizeERC20PrimaryOfferAcceptance, normalizeERC20PrimaryOfferConfiguration,
  normalizeERC20PrimaryOfferSaleOffer, normalizeERC20PrimaryOfferSelection,
} from "../dist/current-erc20-primary-offer-signing.js";
import { buildCuratedManifest, curatedContentContextHash, curatedContentLeaf } from "../dist/current-curated-content.js";
import { erc20PrimaryOfferGateConfigHash, inspectERC20PrimaryOfferManifest } from "../dist/current-erc20-primary-offer-content.js";
import {
  normalizePrimaryOfferSaleOffer, primaryOfferBatchHashes, primaryOfferBuyerRevocationPayload,
  primaryOfferSellerRevocationPayload,
} from "../dist/current-primary-offer-signing.js";
import { paymentIntentRevocationTypedData } from "../dist/signing.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-erc20-primary-offer-abi.json", import.meta.url)));
const coder = AbiCoder.defaultAbiCoder(), saleAbi = new Interface(fixture.abis.sale), gateAbi = new Interface(fixture.abis.gate);
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const adapter = A(1), buyer = A(2), asset = A(3), paymentAdapter = A(4), core = A(5), manager = A(6);
const seller = A(7), executor = A(8), poster = A(9), authority = A(10), ledger = A(11);
const chainId = (1n << 200n) + 31337n, collectionId = (1n << 180n) + 9n;
const phaseId = id("erc20 offer phase"), saleNonce = 8n, price = (1n << 190n) + 34n;
const saleId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
  [id("6529STREAM_SALE_V1"), chainId, adapter, 6n, collectionId, phaseId, saleNonce]));
const raw = "0x001234aabb", mintCommitment = id("mint commitment"), contentId = id("selected work");
const tokenDataHash = keccak256(raw), leaf = curatedContentLeaf(chainId, adapter, saleId, contentId, tokenDataHash);
const domain = { name: "6529Stream Sales", version: "1", chainId, verifyingContract: adapter };
const parameter = (abi, name, index = 0) => ParamType.from(abi.find(x => x.type === "function" && x.name === name).inputs[index]);
const fields = (abi, name) => parameter(abi, name).components.map(x => ({ name: x.name, type: x.type }));
const offerFields = fields(fixture.abis.sale, "offerDigest"), sellerFields = fields(fixture.abis.sale, "authorizationDigest");
const acceptanceType = parameter(fixture.abis.sale, "previewExecution");
const configurationType = parameter(fixture.abis.sale, "primaryOfferConfigurationHash");

function offer(selected = true) {
  return { chainId, saleAdapter: adapter, core, collectionId, tokenId: 0n,
    contentSelectionHash: selected ? leaf : ZeroHash, buyer, asset, price, nonce: id("offer nonce"),
    deadline: 9999n, finalizeBy: 0n };
}
function configuration(selected = true) {
  return { collectionId, phaseId, asset, paymentAdapter, price, poster, startsAt: 100n, endsAt: 900n,
    mintPolicyHash: id("mint policy"), expectedPrimaryPolicyHash: id("primary policy"), primaryPolicyMode: 0n,
    contentManifestRoot: selected ? leaf : ZeroHash, buyer,
    offerDigest: TypedDataEncoder.hash(domain, { SaleOffer: offerFields }, offer(selected)),
    contentId: selected ? contentId : ZeroHash, tokenDataHash: selected ? tokenDataHash : ZeroHash,
    signer: seller, signerKind: 2n, signerEvidenceHash: id("signer evidence"), signerRevision: (1n << 63n) + 3n,
    signerAuthority: authority };
}
function literalBatch(data = raw) {
  return {
    initialRecipientsHash: keccak256(coder.encode(["bytes32", "address[]"], [id("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), [buyer]])),
    beneficiariesHash: keccak256(coder.encode(["bytes32", "address[]"], [id("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), [buyer]])),
    tokenDataArrayHash: keccak256(coder.encode(["bytes32", "bytes[]"], [id("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), [data]])),
    mintCommitmentsHash: keccak256(coder.encode(["bytes32", "bytes32[]"], [id("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), [mintCommitment]])),
  };
}
function authorization(selected = true, data = raw) {
  return { chainId, saleAdapter: adapter, mintManager: manager, collectionId, phaseId, saleId,
    saleKind: 6n, revenueClass: id("PRIMARY_SALE"), expectedPrimaryPolicyHash: id("primary policy"),
    primaryPolicyMode: 0n, ...literalBatch(data), payer: buyer, executor, asset, unitPrice: price, quantity: 1n,
    contentSelectionHash: selected ? leaf : ZeroHash, policyHash: id("mint policy"), nonce: id("seller nonce"),
    deadline: 850n, finalizeBy: 0n };
}
function acceptance(selected = true) {
  return { offer: offer(selected), buyerProof: { authorizer: buyer, kind: 2n, signature: "0xaabb" },
    authorization: authorization(selected), sellerProof: { authorizer: seller, kind: 2n, signature: "0xccdd" },
    selection: { content: { contentId: selected ? contentId : ZeroHash, tokenDataHash: selected ? tokenDataHash : ZeroHash,
      proof: [] }, tokenData: raw, mintCommitment, executionNonce: (1n << 150n) + 3n },
    signerDelegation: { walletWide: false, index: 0n }, executorDelegation: { walletWide: true, index: 9n } };
}
function snapshot(selected = true, c = configuration(selected), o = offer(selected), a = authorization(selected), data = raw) {
  return erc20PrimaryOfferSigningSnapshot(chainId, adapter, core, manager, c, saleId, o, a, data, mintCommitment);
}
function intent() {
  return { payer: buyer, asset, maxAmount: price + 20n, saleRef: saleId, expectedPrimaryPolicyHash: id("primary policy"),
    nonce: id("payer nonce"), deadline: (1n << 63n) + 1n };
}

test("ERC20 keeps the complete compiled 12/24-field Sales domains and separate replay identities", () => {
  assert.equal(offerFields.length, 12); assert.equal(sellerFields.length, 24);
  const offerPayload = erc20PrimaryOfferSaleOfferPayload(chainId, adapter, offer());
  const sellerPayload = erc20PrimaryOfferSellerAuthorizationPayload(chainId, adapter, authorization());
  assert.equal(offerPayload.digest, TypedDataEncoder.hash(domain, { SaleOffer: offerFields }, offer()));
  assert.equal(sellerPayload.digest, TypedDataEncoder.hash(domain, { SaleAuthorization: sellerFields }, authorization()));
  const ticket = keccak256(coder.encode(["bytes32", "bytes32"], [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), offerPayload.digest]));
  assert.equal(erc20PrimaryOfferBuyerAuthorizationId(chainId, adapter, offer()), ticket);
  assert.equal(erc20PrimaryOfferSellerReplayDigest(chainId, adapter, authorization()), sellerPayload.digest);
  assert.equal(new Set([offerPayload.digest, sellerPayload.digest, ticket]).size, 3);
  assert.throws(() => erc20PrimaryOfferSaleOfferPayload(chainId, paymentAdapter, offer()), /coordinates/);
  assert.throws(() => erc20PrimaryOfferSellerAuthorizationPayload(chainId + 1n, adapter, authorization()), /coordinates/);
});

test("ERC20 configuration is the flat 21-field tuple with its own domain and original kind-6 sale ID", () => {
  assert.equal(configurationType.components.length, 21);
  const c = configuration();
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", configurationType],
    [id("6529STREAM_ERC20_PRIMARY_OFFER_CONFIG_V1"), chainId, adapter, c]));
  assert.equal(erc20PrimaryOfferConfigurationHash(chainId, adapter, c), expected);
  assert.equal(erc20PrimaryOfferSaleId(chainId, adapter, collectionId, phaseId, saleNonce), saleId);
  assert.notEqual(erc20PrimaryOfferConfigurationHash(chainId, adapter, { ...c, paymentAdapter: A(33) }), expected);
  assert.throws(() => normalizeERC20PrimaryOfferConfiguration({ ...c, sale: {} }), /unknown/);
  assert.throws(() => normalizeERC20PrimaryOfferConfiguration({ ...c, primaryPolicyMode: 1n }), /strict/);
  assert.throws(() => normalizeERC20PrimaryOfferConfiguration({ ...c, asset: ZeroAddress }), /nonzero/);
});

test("both ERC20 mint arrays bind the buyer, never the carrier", () => {
  const expected = literalBatch();
  assert.deepEqual(erc20PrimaryOfferBatchHashes(buyer, raw, mintCommitment), expected);
  assert.notEqual(expected.initialRecipientsHash, primaryOfferBatchHashes(adapter, buyer, raw, mintCommitment).initialRecipientsHash);
  const wrong = { ...authorization(), initialRecipientsHash: primaryOfferBatchHashes(adapter, buyer, raw, mintCommitment).initialRecipientsHash };
  assert.throws(() => snapshot(true, configuration(), offer(), wrong), /arrays differ/);
});

test("selected and collection-level contexts preserve original identities and signed raw data", () => {
  const selected = snapshot(), unselected = snapshot(false);
  assert.equal(selected.contentSelectionHash, leaf);
  assert.equal(selected.contextHash, curatedContentContextHash(chainId, adapter, saleId, contentId));
  assert.equal(unselected.contentSelectionHash, ZeroHash);
  assert.equal(unselected.contextHash, unselected.sellerReplayDigest);
  assert.equal(unselected.offer.deadline, 9999n); // Buyer deadline may exceed sale end.
  assert.equal(unselected.configuration.endsAt, 900n);
  assert.throws(() => snapshot(true, configuration(), offer(), { ...authorization(), deadline: 901n }), /differ/);
  assert.throws(() => snapshot(false, configuration(false), offer(false), authorization(false), "0x00"), /differ/);
  assert.throws(() => snapshot(true, configuration(), offer(), authorization(), "0x00"), /differ/);
  for (const key of ["payer", "asset", "mintManager"]) {
    assert.throws(() => snapshot(true, configuration(), offer(), { ...authorization(), [key]: A(77) }), /differ/);
  }
});

test("ERC20 profile rejects native asset, widened payloads, nonzero finalizeBy, wrong quantity and tokenId", () => {
  assert.throws(() => normalizePrimaryOfferSaleOffer(offer()), /asset/); // Existing native API stays native.
  for (const changed of [{ asset: ZeroAddress }, { tokenId: 1n }, { finalizeBy: 1n }, { nonce: ZeroHash }, { price: 0n }, { chainId: 1 }]) {
    assert.throws(() => erc20PrimaryOfferSaleOfferPayload(chainId, adapter, { ...offer(), ...changed }));
  }
  for (const changed of [{ asset: ZeroAddress }, { finalizeBy: 1n }, { saleKind: 5n }, { quantity: 2n }, { primaryPolicyMode: 1n }]) {
    assert.throws(() => erc20PrimaryOfferSellerAuthorizationPayload(chainId, adapter, { ...authorization(), ...changed }));
  }
  assert.throws(() => normalizeERC20PrimaryOfferSaleOffer({ ...offer(), extra: true }), /unknown/);
});

test("full nested Acceptance encodes identically to the frozen compiler for selected and empty collection branches", () => {
  for (const selected of [true, false]) {
    const a = acceptance(selected);
    const canonical = coder.encode([acceptanceType], [a]);
    assert.equal(encodeERC20PrimaryOfferAcceptance(a), canonical);
    assert.equal(saleAbi.encodeFunctionData("previewExecution", [a]).slice(10), canonical.slice(2));
    const stored = normalizeERC20PrimaryOfferAcceptance(a);
    assert.deepEqual(stored.selection, a.selection);
    assert.equal(stored.selection.executionNonce, (1n << 150n) + 3n);
  }
});

test("Acceptance snapshot preserves explicit signature kinds, separate witnesses, strict fields and local bounds", () => {
  const a = acceptance(), saved = normalizeERC20PrimaryOfferAcceptance(a), encoded = encodeERC20PrimaryOfferAcceptance(a);
  a.offer.price = 1n; a.authorization.unitPrice = 2n; a.selection.content.proof.push(id("late proof"));
  a.buyerProof.signature = "0x"; a.signerDelegation.index = 88n; a.executorDelegation.walletWide = false;
  assert.equal(encodeERC20PrimaryOfferAcceptance(saved), encoded);
  assert.equal(saved.selection.content.proof.length, 0);
  assert(Object.isFrozen(saved.selection.content.proof)); assert(Object.isFrozen(saved.buyerProof));
  assert.notDeepEqual(saved.signerDelegation, saved.executorDelegation);
  const base = acceptance();
  assert.throws(() => normalizeERC20PrimaryOfferAcceptance({ ...base, buyerProof: { ...base.buyerProof, kind: 0n } }), /kind/);
  assert.throws(() => normalizeERC20PrimaryOfferAcceptance({ ...base, sellerProof: { ...base.sellerProof, signature: `0x${"00".repeat(65537)}` } }), /65536/);
  assert.throws(() => normalizeERC20PrimaryOfferAcceptance({ ...base, revealFeeAllowance: 1n }), /unknown/);
  assert.throws(() => normalizeERC20PrimaryOfferSelection({ ...base.selection, executionNonce: 0n }), /execution nonce/);
  assert.throws(() => normalizeERC20PrimaryOfferSelection({ ...base.selection, recipient: buyer }), /unknown/);
  assert.throws(() => normalizeERC20PrimaryOfferSelection({ ...base.selection, tokenData: `0x${"00".repeat(8193)}` }), /8192/);
  assert.throws(() => normalizeERC20PrimaryOfferSelection({ ...base.selection, content: { ...base.selection.content, proof: Array(257).fill(ZeroHash) } }), /256/);
});

test("signing snapshots copy mutable configuration, full messages and typed-data schemas", () => {
  const c = configuration(), o = offer(), a = authorization();
  const saved = snapshot(true, c, o, a);
  c.price = 1n; c.paymentAdapter = adapter; o.asset = ZeroAddress; a.executor = buyer;
  assert.equal(saved.configuration.price, price); assert.equal(saved.configuration.paymentAdapter, paymentAdapter);
  assert.equal(saved.offer.asset, asset); assert.equal(saved.sellerAuthorization.executor, executor);
  assert(Object.isFrozen(saved.offerPayload.domain)); assert(Object.isFrozen(saved.sellerPayload.types.SaleAuthorization));
});

test("PaymentIntent keeps the original payer-owned type and actual contract20 domain", () => {
  const i = intent(), payload = erc20PrimaryOfferPaymentIntentPayload(chainId, configuration(), saleId, i);
  const paymentFields = fields(fixture.abis.payment, "paymentIntentDigest");
  assert.equal(payload.digest, TypedDataEncoder.hash({ name: "6529StreamPaymentIntentVerifier", version: "1", chainId, verifyingContract: paymentAdapter },
    { StreamPaymentIntent: paymentFields }, i));
  assert.equal(payload.message.payer, buyer); assert.equal(payload.domain.verifyingContract, paymentAdapter);
  assert.notEqual(payload.digest, TypedDataEncoder.hash({ ...payload.domain, verifyingContract: adapter }, payload.types, i));
  i.maxAmount = 1n; assert.equal(payload.message.maxAmount, price + 20n);
  for (const changed of [{ payer: executor }, { asset: A(77) }, { maxAmount: price - 1n }, { saleRef: id("other") },
    { expectedPrimaryPolicyHash: id("other policy") }, { deadline: 1n << 64n }]) {
    assert.throws(() => erc20PrimaryOfferPaymentIntentPayload(chainId, configuration(), saleId, { ...intent(), ...changed }));
  }
  assert.equal(erc20PrimaryOfferPaymentIntentPayload(chainId, configuration(), saleId, { ...intent(), nonce: ZeroHash }).message.nonce, ZeroHash);
});

test("buyer, historical seller and payer revocations keep three independent original families", () => {
  const s = snapshot(), ticketRevocation = primaryOfferBuyerRevocationPayload(chainId, adapter, manager, ledger, s.buyerAuthorizationId);
  const sellerRevocation = primaryOfferSellerRevocationPayload(chainId, adapter, seller, s.sellerReplayDigest);
  const payerRevocation = paymentIntentRevocationTypedData(chainId, paymentAdapter, { payer: buyer, nonce: intent().nonce, deadline: 999n });
  assert.equal(ticketRevocation.primaryType, "MintTicketRevocation");
  assert.equal(sellerRevocation.primaryType, "SaleAuthorizationRevocation");
  assert.equal(payerRevocation.primaryType, "StreamPaymentIntentRevocation");
  assert.equal(new Set([ticketRevocation.digest, sellerRevocation.digest, payerRevocation.digest]).size, 3);
  assert.equal(ticketRevocation.domain.verifyingContract, adapter); assert.equal(payerRevocation.domain.verifyingContract, paymentAdapter);
});

test("selected ERC20 gate hashes the complete original publication with its distinct capability", async () => {
  const manifest = buildCuratedManifest({ chainId, manager, adapter, saleId, collectionId, phaseId, counterId: id("counter"),
    rows: [{ contentId, tokenDataHash, previewURI: "ipfs://reviewed-work" }] });
  const managerCode = "0x60006001", adapterCode = "0x60026003", managerHash = keccak256(managerCode), adapterHash = keccak256(adapterCode);
  const publicationType = ParamType.from(fixture.abis.gate.find(x => x.name === "publication").outputs[0]);
  const expected = keccak256(coder.encode(["bytes32", publicationType, "bytes32", "bytes32"],
    [id("6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1"), manifest.publication, managerHash, adapterHash]));
  assert.equal(erc20PrimaryOfferGateConfigHash(manifest, managerHash, adapterHash), expected);
  const values = { publication: manifest.publication, manifestBytes: manifest.manifestBytes, itemCount: 1n,
    gateConfigHash: expected, managerCodeHash: managerHash, houseCodeHash: adapterHash,
    offerPurchaseVersion: id("6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1") };
  const provider = {
    getNetwork: async () => ({ chainId }),
    getCode: async (target, block) => { assert.equal(block, 123); return target === manager ? managerCode : adapterCode; },
    call: async request => { assert.equal(request.to.toLowerCase(), A(12)); assert.equal(request.blockTag, 123);
      const fn = gateAbi.parseTransaction({ data: request.data }).name;
      return gateAbi.encodeFunctionResult(fn, [values[fn]]); },
  };
  assert.equal((await inspectERC20PrimaryOfferManifest(provider, A(12), manifest, { blockTag: 123 })).gateConfigHash, expected);
  values.offerPurchaseVersion = id("6529STREAM_NATIVE_PRIMARY_OFFER_GATE_V1");
  await assert.rejects(inspectERC20PrimaryOfferManifest(provider, A(12), manifest, { blockTag: 123 }), /ERC20 primary offer capability/);
});
