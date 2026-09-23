import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, concat, id, keccak256 } from "ethers";
import * as signing from "../dist/current-primary-offer-signing.js";
import { buildCuratedManifest } from "../dist/current-curated-content.js";
import { preparePrimaryOfferRegistration, preparePrimaryOfferAcceptance,
  preparePrimaryOfferBuyerRevocation, preparePrimaryOfferSellerRevocation,
  preparePrimaryOfferRefundClaim, preparePrimaryOfferDelegatedRefundClaim } from "../dist/current-primary-offer.js";
import { createSafeCallPlan, verifySafeCallPlan, simulateSafePlanStep } from "../dist/safe-plan.js";

const fixture = JSON.parse(await readFile(new URL("./fixtures/current-primary-offer-abi.json", import.meta.url), "utf8"));
const abi = new Interface(fixture.abis.sale), managerAbi = new Interface(fixture.abis.manager), coder = AbiCoder.defaultAbiCoder();
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chain = 31337n, adapter = A(1), manager = A(2), core = A(3), buyer = A(4), executor = A(5), seller = A(6), ledger = A(7);
const phase = id("offer phase"), price = (1n << 180n) + 100n, raw = "0x1234", commitment = id("original commitment");
const saleId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
  [id("6529STREAM_SALE_V1"), chain, adapter, 6n, 13n, phase, 8n]));
const offerType = "SaleOffer(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const authorizationType = "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
function digest(type, message, verifier = adapter) {
  const fields = type.slice(type.indexOf("(") + 1, -1).split(",").map(field => field.split(" "));
  const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529Stream Sales"), id("1"), chain, verifier]));
  const body = keccak256(coder.encode(["bytes32", ...fields.map(field => field[0])], [id(type), ...fields.map(field => message[field[1]])]));
  return keccak256(concat(["0x1901", domain, body]));
}
function arrays() {
  return Object.fromEntries([
    ["initialRecipientsHash", "6529STREAM_MINT_BATCH_RECIPIENTS_V1", "address[]", [adapter]],
    ["beneficiariesHash", "6529STREAM_MINT_BATCH_BENEFICIARIES_V1", "address[]", [buyer]],
    ["tokenDataArrayHash", "6529STREAM_MINT_BATCH_TOKEN_DATA_V1", "bytes[]", [raw]],
    ["mintCommitmentsHash", "6529STREAM_MINT_BATCH_COMMITMENTS_V1", "bytes32[]", [commitment]],
  ].map(([key, domain, type, value]) => [key, keccak256(coder.encode(["bytes32", type], [id(domain), value]))]));
}
function packet(selected) {
  const manifest = buildCuratedManifest({ chainId: chain, manager, adapter, saleId, collectionId: 13n, phaseId: phase,
    counterId: id("once"), rows: [{ contentId: ZeroHash, tokenDataHash: keccak256(raw), previewURI: "ipfs://work" }] });
  const content = selected ? manifest.publication.manifestRoot : ZeroHash;
  const offer = { chainId: chain, saleAdapter: adapter, core, collectionId: 13n, tokenId: 0n,
    contentSelectionHash: content, buyer, asset: ZeroAddress, price, nonce: id("offer nonce"), deadline: 900n, finalizeBy: 0n };
  const authorization = { chainId: chain, saleAdapter: adapter, mintManager: manager, collectionId: 13n, phaseId: phase,
    saleId, saleKind: 6n, revenueClass: id("PRIMARY_SALE"), expectedPrimaryPolicyHash: id("primary policy"), primaryPolicyMode: 0n,
    ...arrays(), payer: buyer, executor, asset: ZeroAddress, unitPrice: price, quantity: 1n,
    contentSelectionHash: content, policyHash: id("mint policy"), nonce: id("seller nonce"), deadline: 800n, finalizeBy: 0n };
  const configuration = { sale: { collectionId: 13n, phaseId: phase, price, poster: seller, startsAt: 100n, endsAt: 800n,
    mintPolicyHash: authorization.policyHash, expectedPrimaryPolicyHash: authorization.expectedPrimaryPolicyHash,
    primaryPolicyMode: 0n, contentManifestRoot: selected ? manifest.publication.manifestRoot : ZeroHash },
    buyer, offerDigest: digest(offerType, offer), contentId: ZeroHash, tokenDataHash: selected ? keccak256(raw) : ZeroHash,
    signer: seller, signerKind: 2n, signerEvidenceHash: id("historical evidence"), signerRevision: 2n, signerAuthority: A(8) };
  return { manifest, offer, authorization, configuration };
}

test("compiled offer fixtures preserve complete 12/24-field tuples and both historical replay surfaces", () => {
  assert.equal(fixture.sourceCommit, "cf268d24bd0098c90ece4cd2b9d306802d9c1b62");
  assert.equal(fixture.sourceCount, 396); assert.equal(Object.keys(fixture.sources).length, 396);
  assert.equal(fixture.carrierCommit, "6d69483cc7eeee748271f531821ed2bf7643a787");
  for (const [method, type] of [["offerDigest", offerType], ["authorizationDigest", authorizationType]]) {
    const compiled = abi.getFunction(method).inputs[0].components.map(field => `${field.type} ${field.name}`).join(",");
    assert.equal(type.slice(type.indexOf("(") + 1, -1), compiled);
  }
  assert.equal(managerAbi.getFunction("voidMintOffer").inputs[0].components.length, 12);
  assert.equal(abi.getFunction("revokeAuthorization").inputs[0].components.length, 24);
  assert.equal(abi.getFunction("primaryOfferAuthorizationBinding").outputs.length, 5);
  assert.equal(abi.getFunction("acceptPrimaryOffer").stateMutability, "payable");
  assert.equal(fixture.abis.manager.some(item => item.name === "voidMintSaleAuthorization"), false);
});

test("selected and unselected offers retain literal original identities and separate dual replay keys", () => {
  for (const selected of [false, true]) {
    const { offer, authorization, configuration } = packet(selected);
    const buyerDigest = digest(offerType, offer), sellerDigest = digest(authorizationType, authorization);
    const ticket = keccak256(coder.encode(["bytes32", "bytes32"], [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), buyerDigest]));
    const snapshot = signing.primaryOfferSigningSnapshot(chain, adapter, core, manager, configuration, saleId, offer, authorization, raw, commitment);
    assert.equal(snapshot.offerPayload.digest, buyerDigest); assert.equal(snapshot.sellerPayload.digest, sellerDigest);
    assert.equal(snapshot.buyerAuthorizationId, ticket); assert.equal(snapshot.sellerReplayDigest, sellerDigest);
    assert.notEqual(ticket, buyerDigest); assert.notEqual(ticket, sellerDigest);
    assert.equal(signing.primaryOfferSaleId(chain, adapter, 13n, phase, 8n), saleId);
    assert.equal(signing.primaryOfferBuyerAuthorizationId(chain, adapter, offer), ticket);
    assert.deepEqual(signing.primaryOfferBatchHashes(adapter, buyer, raw, commitment), arrays());
    assert.equal(snapshot.selected, selected);
    assert.equal(snapshot.sellerAuthorization.executor, executor); assert.equal(snapshot.sellerAuthorization.payer, buyer);
    assert(offer.deadline > configuration.sale.endsAt);
    const purchaseId = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "uint256"],
      [id("6529STREAM_SALE_PURCHASE_V1"), chain, adapter, saleId, buyer, 9n]));
    assert.equal(signing.primaryOfferPurchaseId(chain, adapter, saleId, buyer, 9n), purchaseId);
    assert.notEqual(purchaseId, ticket);
    const changedSeller = { ...authorization, nonce: id("fresh seller nonce") };
    assert.notEqual(signing.primaryOfferSellerReplayDigest(chain, adapter, changedSeller), sellerDigest);
    assert.equal(signing.primaryOfferBuyerAuthorizationId(chain, adapter, offer), ticket);
  }
});

test("whole primary offer configuration hash matches the compiled tuple with the original kind-6 domain", () => {
  for (const selected of [false, true]) {
    const { configuration } = packet(selected);
    const tuple = abi.getFunction("primaryOfferConfigurationHash").inputs[0];
    const expected = keccak256(coder.encode(["bytes32", "uint256", "address", tuple],
      [id("6529STREAM_NATIVE_PRIMARY_OFFER_CONFIG_V1"), chain, adapter, configuration]));
    assert.equal(signing.primaryOfferConfigurationHash(chain, adapter, configuration), expected);
  }
});

test("buyer mint revocation and seller authorization revocation keep original distinct signing families", () => {
  const { offer, authorization } = packet(false), offerDigest = digest(offerType, offer);
  const authorizationId = keccak256(coder.encode(["bytes32", "bytes32"], [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), offerDigest]));
  const buyerPayload = signing.primaryOfferBuyerRevocationPayload(chain, adapter, manager, ledger, authorizationId);
  const sellerPayload = signing.primaryOfferSellerRevocationPayload(chain, adapter, seller, digest(authorizationType, authorization));
  assert.equal(buyerPayload.digest, digest("MintTicketRevocation(uint256 chainId,address manager,address ledger,bytes32 authorizationId)", buyerPayload.message));
  assert.equal(sellerPayload.digest, digest("SaleAuthorizationRevocation(uint256 chainId,address saleAdapter,address authorizer,bytes32 authorizationDigest)", sellerPayload.message));
  assert.equal(buyerPayload.domain.verifyingContract, adapter); assert.equal(sellerPayload.domain.verifyingContract, adapter);
  assert.notEqual(buyerPayload.digest, digest("MintTicketRevocation(uint256 chainId,address manager,address ledger,bytes32 authorizationId)", buyerPayload.message, manager));
  assert.notEqual(buyerPayload.digest, offerDigest); assert.notEqual(sellerPayload.digest, digest(authorizationType, authorization));
});

function prepare(selected) {
  const source = packet(selected);
  const selection = { content: selected ? source.manifest.selections[0] : { contentId: ZeroHash, tokenDataHash: ZeroHash, proof: [] },
    tokenData: raw, mintCommitment: commitment, recipient: buyer, purchaseNonce: 9n };
  const input = { offer: source.offer, buyerProof: { authorizer: A(9), kind: 2n, signature: "0x1234" },
    sellerAuthorization: source.authorization, sellerProof: { authorizer: seller, kind: 2n, signature: "0xabcd" }, selection,
    signerDelegation: { walletWide: true, index: 10n }, executorDelegation: { walletWide: false, index: 11n }, revealFeeAllowance: 7n };
  const registration = preparePrimaryOfferRegistration(chain, adapter, A(8), 8n, source.configuration, selected ? source.manifest.selections[0].proof : []);
  const acceptance = preparePrimaryOfferAcceptance(chain, adapter, core, manager, source.configuration, input);
  return { ...source, input, registration, acceptance };
}

test("compiled acceptance encodes separate signer/executor witnesses and value from the actual executor", () => {
  for (const selected of [false, true]) {
    const { input, registration, acceptance, configuration } = prepare(selected);
    assert.equal(registration.expectedSaleId, saleId); assert.equal(registration.caller, A(8));
    assert.equal(registration.call.value, 0n);
    assert.equal(registration.call.data, abi.encodeFunctionData("registerPrimaryOffer", [configuration, registration.selectedProof]));
    assert.equal(acceptance.caller, executor); assert.notEqual(acceptance.caller, buyer);
    assert.equal(acceptance.call.value, price + 7n);
    assert.equal(acceptance.call.data, abi.encodeFunctionData("acceptPrimaryOffer", [{ offer: input.offer,
      buyerProof: input.buyerProof, authorization: input.sellerAuthorization, sellerProof: input.sellerProof,
      selection: input.selection, signerDelegation: input.signerDelegation, executorDelegation: input.executorDelegation }]));
    assert.equal(abi.decodeFunctionData("acceptPrimaryOffer", acceptance.call.data)[0].authorization.payer, buyer);
    const callBytes = acceptance.call.data;
    input.sellerAuthorization.executor = buyer; input.executorDelegation.index = 99n; input.buyerProof.signature = "0x";
    assert.equal(acceptance.caller, executor); assert.equal(acceptance.call.data, callBytes);
    assert.equal(acceptance.executorDelegation.index, 11n);
  }
});

test("ordinary Safe CALL plans retain owner/executor roles and identical acceptance retry bytes/value", async () => {
  const { registration, acceptance } = prepare(true), prepared = [registration, acceptance];
  const catalog = prepared.map(() => fixture.abis.sale);
  const plan = createSafeCallPlan(chain, "Register and accept a native primary offer", prepared.map((p, i) => ({
    safe: p.caller, intent: i ? "Executor funds price and reveal allowance; buyer receives token and excess" : "Owner registers immutable offer terms",
    call: p.call, abi: fixture.abis.sale,
  })));
  assert.deepEqual(verifySafeCallPlan(plan, catalog), plan);
  assert.deepEqual(plan.steps.map(step => step.safe), [A(8), executor]);
  assert.deepEqual(plan.steps.map(step => step.transaction.value), ["0", (price + 7n).toString()]);
  assert(plan.steps.every(step => step.transaction.operation === 0));
  let reject = true; const calls = [];
  const provider = { getNetwork: async () => ({ chainId: chain }), call: async tx => {
    calls.push(tx); if (reject) throw Error("buyer signature unavailable"); return "0x";
  } };
  await assert.rejects(simulateSafePlanStep(provider, plan, catalog, 1), /signature unavailable/);
  reject = false; await simulateSafePlanStep(provider, plan, catalog, 1);
  assert.deepEqual(calls[0], calls[1]); assert.equal(calls[0].from, executor); assert.equal(calls[0].value, price + 7n);
});

test("Safe revocations target separate historical stores and refund calls preserve the original buyer", () => {
  const { offer, authorization, configuration } = packet(false);
  const buyerVoid = preparePrimaryOfferBuyerRevocation(chain, adapter, manager, ledger, buyer, offer, 2n, "0x");
  const sellerVoid = preparePrimaryOfferSellerRevocation(chain, adapter, seller, configuration, authorization,
    { authorizer: seller, kind: 2n, signature: "0x" });
  const buyerClaim = preparePrimaryOfferRefundClaim(adapter, buyer, saleId, A(10));
  const delegatedClaim = preparePrimaryOfferDelegatedRefundClaim(adapter, executor, saleId, buyer, { walletWide: true, index: 99n });
  assert.equal(buyerVoid.call.to, manager); assert.equal(buyerVoid.call.data, managerAbi.encodeFunctionData("voidMintOffer", [offer, 2n, "0x"]));
  assert.equal(sellerVoid.call.to, adapter); assert.equal(sellerVoid.call.data, abi.encodeFunctionData("revokeAuthorization", [authorization,
    { authorizer: seller, kind: 2n, signature: "0x" }]));
  assert.equal(buyerClaim.call.data, abi.encodeFunctionData("claimRefund", [saleId, A(10)]));
  assert.equal(delegatedClaim.call.data, abi.encodeFunctionData("claimRefundFor", [saleId, buyer, { walletWide: true, index: 99n }]));
  const prepared = [buyerVoid, sellerVoid, buyerClaim, delegatedClaim];
  const catalog = [fixture.abis.manager, fixture.abis.sale, fixture.abis.sale, fixture.abis.sale];
  const plan = createSafeCallPlan(chain, "Historical revocation and buyer credit recovery", prepared.map((p, i) => ({
    safe: p.caller, intent: ["Buyer voids original full offer", "Historical seller revokes original authorization",
      "Buyer claims to chosen recipient", "Delegate triggers credit delivery to original buyer"][i], call: p.call, abi: catalog[i],
  })));
  assert.deepEqual(verifySafeCallPlan(plan, catalog), plan);
  assert.deepEqual(plan.steps.map(step => step.safe), [buyer, seller, buyer, executor]);
  assert(plan.steps.every(step => step.transaction.operation === 0 && step.transaction.value === "0"));
});
