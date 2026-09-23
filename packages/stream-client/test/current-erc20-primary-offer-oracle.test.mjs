import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, concat, id, keccak256 } from "ethers";
import { erc20PrimaryOfferSafeInventory, createERC20PrimaryOfferSafeReview } from "../examples/current-erc20-primary-offer.mjs";
import { verifySafeCallPlan, simulateSafePlanStep } from "../dist/safe-plan.js";
import * as signing from "../dist/current-erc20-primary-offer-signing.js";
import * as workflow from "../dist/current-erc20-primary-offer.js";

const fixture = JSON.parse(await readFile(new URL("./fixtures/current-erc20-primary-offer-abi.json", import.meta.url), "utf8"));
const saleAbi = new Interface(fixture.abis.sale), paymentAbi = new Interface(fixture.abis.payment);
const managerAbi = new Interface(fixture.abis.manager), tokenAbi = new Interface(fixture.abis.token);
const coder = AbiCoder.defaultAbiCoder(), A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chainId = 31337n, carrier = A(1), core = A(2), manager = A(3), payment = A(4), recorder = A(5);
const buyer = A(6), executor = A(7), seller = A(8), asset = A(9), owner = A(10);
const price = (1n << 190n) + 100n, raw = "0x123456", commitment = id("erc20 original mint commitment");
const offerType = "SaleOffer(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const authorizationType = "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
function digest(type, message, verifier = carrier, name = "6529Stream Sales") {
  const fields = type.slice(type.indexOf("(") + 1, -1).split(",").map(field => field.split(" "));
  const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id(name), id("1"), chainId, verifier]));
  const body = keccak256(coder.encode(["bytes32", ...fields.map(field => field[0])], [id(type), ...fields.map(field => message[field[1]])]));
  return keccak256(concat(["0x1901", domain, body]));
}
function packet(selected = false, actualExecutor = executor) {
  const phaseId = id("ERC20 offer phase"), collectionId = 73n, saleNonce = 8n;
  const saleId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), chainId, carrier, 6n, collectionId, phaseId, saleNonce]));
  const contentId = selected ? id("selected work") : ZeroHash;
  const leaf = selected ? keccak256(keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_CONTENT_LEAF_V1"), chainId, carrier, saleId, contentId, keccak256(raw)]))) : ZeroHash;
  const offer = { chainId, saleAdapter: carrier, core, collectionId, tokenId: 0n, contentSelectionHash: leaf,
    buyer, asset, price, nonce: id("original offer nonce"), deadline: 900n, finalizeBy: 0n };
  const hashes = Object.fromEntries([
    ["initialRecipientsHash", "6529STREAM_MINT_BATCH_RECIPIENTS_V1", "address[]", [buyer]],
    ["beneficiariesHash", "6529STREAM_MINT_BATCH_BENEFICIARIES_V1", "address[]", [buyer]],
    ["tokenDataArrayHash", "6529STREAM_MINT_BATCH_TOKEN_DATA_V1", "bytes[]", [raw]],
    ["mintCommitmentsHash", "6529STREAM_MINT_BATCH_COMMITMENTS_V1", "bytes32[]", [commitment]],
  ].map(([key, domain, type, value]) => [key, keccak256(coder.encode(["bytes32", type], [id(domain), value]))]));
  const authorization = { chainId, saleAdapter: carrier, mintManager: manager, collectionId, phaseId, saleId,
    saleKind: 6n, revenueClass: id("PRIMARY_SALE"), expectedPrimaryPolicyHash: id("primary policy"), primaryPolicyMode: 0n,
    ...hashes, payer: buyer, executor: actualExecutor, asset, unitPrice: price, quantity: 1n, contentSelectionHash: leaf,
    policyHash: id("bound mint policy"), nonce: id("original seller nonce"), deadline: 800n, finalizeBy: 0n };
  const configuration = { collectionId, phaseId, asset, paymentAdapter: payment, price, poster: seller, startsAt: 100n, endsAt: 800n,
    mintPolicyHash: authorization.policyHash, expectedPrimaryPolicyHash: authorization.expectedPrimaryPolicyHash,
    primaryPolicyMode: 0n, contentManifestRoot: leaf, buyer, offerDigest: digest(offerType, offer), contentId,
    tokenDataHash: selected ? keccak256(raw) : ZeroHash, signer: seller, signerKind: 2n,
    signerEvidenceHash: id("historical signer evidence"), signerRevision: 3n, signerAuthority: owner };
  const acceptance = { offer, buyerProof: { authorizer: buyer, kind: 2n, signature: "0x1234" }, authorization,
    sellerProof: { authorizer: seller, kind: 2n, signature: "0xabcd" }, selection: {
      content: { contentId, tokenDataHash: selected ? keccak256(raw) : ZeroHash, proof: [] },
      tokenData: raw, mintCommitment: commitment, executionNonce: 7n },
    signerDelegation: { walletWide: false, index: 0n }, executorDelegation: { walletWide: true, index: 11n } };
  return { configuration, acceptance, offer, authorization, saleId, saleNonce, hashes };
}
function candidate(p) {
  const executionData = coder.encode([saleAbi.getFunction("previewExecution").inputs[0]], [p.acceptance]);
  const c = { saleAdapter: carrier, executor: p.authorization.executor,
    sale: { settlementId: p.saleId, revenueClass: id("PRIMARY_SALE"), policyMode: 0n,
      collectionId: p.configuration.collectionId, tokenId: 0n, saleNonce: p.saleNonce, payer: buyer,
      poster: seller, beneficiary: buyer, amount: price, expectedPrimaryPolicyHash: p.configuration.expectedPrimaryPolicyHash },
    lifecycleBinding: { paymentAdapter: payment, saleCreatedAt: 50n, saleAdapterRegistryRevision: 3n, paymentAdapterRegistryRevision: 4n },
    executionBinding: { executionId: ZeroHash, executionNonce: p.acceptance.selection.executionNonce,
      authorityMode: 1n, saleAuthorizationDigest: digest(authorizationType, p.authorization) },
    asset, orchestrationOrder: 1n, mintManager: manager, operationIdentityCommitment: id("manager operation root"),
    operationId: id("single token operation id"), currentPolicyHash: id("current allowed phase policy"),
    boundPolicyHash: p.configuration.mintPolicyHash,
    rights: { profileId: id("concrete PROFILE"), wallet: A(15), templateId: ZeroHash,
      assignmentHash: id("strict original assignment"), entriesHash: id("wallet entries") },
    saleExecutionHash: keccak256(executionData) };
  c.executionBinding.executionId = keccak256(coder.encode(
    ["bytes32", "uint256", "address", "bytes32", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ERC20_SALE_EXECUTION_V1"), chainId, carrier, p.saleId, buyer, c.executor,
      c.executionBinding.executionNonce, 1n, c.executionBinding.saleAuthorizationDigest,
      c.currentPolicyHash, c.boundPolicyHash, c.operationIdentityCommitment]));
  const candidateCommitment = keccak256(coder.encode(["bytes32", "uint256", "address", "address", paymentAbi.getFunction("settleERC20PrimarySaleByPayer").inputs[0]],
    [id("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2"), chainId, payment, recorder, c]));
  const settlementKey = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32"],
    [id("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2"), chainId, recorder, carrier, c.executionBinding.executionId]));
  return { candidate: c, executionData, candidateCommitment, settlementKey };
}

test("ERC20 compiled fixture preserves full original signatures, flat configuration and four nonpayable funding routes", () => {
  assert.equal(fixture.sourceCommit, "2e0fca1aef41a023d76a9717651a699bbd7db155");
  assert.equal(fixture.sourceCount, 2098); assert.equal(Object.keys(fixture.sources).length, 2098);
  assert.equal(saleAbi.getFunction("primaryOfferConfigurationHash").inputs[0].components.length, 21);
  for (const [method, type] of [["offerDigest", offerType], ["authorizationDigest", authorizationType]]) {
    assert.equal(saleAbi.getFunction(method).inputs[0].components.map(field => `${field.type} ${field.name}`).join(","), type.slice(type.indexOf("(") + 1, -1));
  }
  for (const method of ["settleERC20PrimarySaleByPayer", "settleERC20PrimarySaleWithIntent", "settleERC20PrimarySaleWithEIP2612Permit", "settleERC20PrimarySaleWithPermit2"]) {
    assert.equal(paymentAbi.getFunction(method).stateMutability, "nonpayable");
    assert.equal(paymentAbi.getFunction(method).outputs[0].components.length, 12);
  }
  assert.equal(saleAbi.getFunction("primaryOfferSettlementBinding").outputs.length, 3);
  assert.equal(saleAbi.getFunction("purchaseIdFor"), null);
  assert.equal(paymentAbi.getFunction("revokePaymentIntentWithSignature").inputs[0].components.length, 3);
  for (const [method, expectedBytes] of [["saleRecord", 1184], ["previewExecution", 1088], ["executionRecord", 416]]) {
    const outputs = saleAbi.getFunction(method).outputs;
    assert.equal((coder.encode(outputs, coder.getDefaultValue(outputs)).length - 2) / 2, expectedBytes);
  }
});

test("all user-entry Safe methods are inventoried separately from transport callbacks", () => {
  const inventory = erc20PrimaryOfferSafeInventory(fixture.abis);
  assert.equal(inventory.length, 19); assert(inventory.every(row => !row.payable));
  assert.equal(inventory.filter(row => row.kind === "sale").length, 11);
  assert.equal(inventory.filter(row => row.kind === "payment").length, 6);
  assert(!inventory.some(row => /executeERC20PreRevenueSingleStep|fundERC20PrimarySale/.test(row.method)));
});

test("selected and collection ERC20 offers preserve original literal Sales identities and buyer-bound arrays", () => {
  for (const selected of [false, true]) {
    const p = packet(selected), buyerDigest = digest(offerType, p.offer), sellerDigest = digest(authorizationType, p.authorization);
    const snapshot = signing.erc20PrimaryOfferSigningSnapshot(chainId, carrier, core, manager, p.configuration,
      p.saleId, p.offer, p.authorization, raw, commitment);
    const ticket = keccak256(coder.encode(["bytes32", "bytes32"], [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), buyerDigest]));
    assert.equal(snapshot.offerPayload.digest, buyerDigest); assert.equal(snapshot.sellerPayload.digest, sellerDigest);
    assert.equal(snapshot.buyerAuthorizationId, ticket); assert.equal(snapshot.sellerReplayDigest, sellerDigest);
    assert.deepEqual(snapshot.batchHashes, p.hashes); assert.equal(snapshot.selected, selected);
    const expectedContext = selected ? keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "bytes32"],
      [id("6529STREAM_CONTENT_CONTEXT_V1"), chainId, carrier, p.saleId, p.configuration.contentId])) : sellerDigest;
    assert.equal(snapshot.contextHash, expectedContext);
    assert.equal(signing.erc20PrimaryOfferSaleId(chainId, carrier, p.configuration.collectionId, p.configuration.phaseId, p.saleNonce), p.saleId);
    const expectedConfig = keccak256(coder.encode(["bytes32", "uint256", "address", saleAbi.getFunction("primaryOfferConfigurationHash").inputs[0]],
      [id("6529STREAM_ERC20_PRIMARY_OFFER_CONFIG_V1"), chainId, carrier, p.configuration]));
    assert.equal(signing.erc20PrimaryOfferConfigurationHash(chainId, carrier, p.configuration), expectedConfig);
    assert.equal(signing.encodeERC20PrimaryOfferAcceptance(p.acceptance), coder.encode([saleAbi.getFunction("previewExecution").inputs[0]], [p.acceptance]));
    assert.notEqual(ticket, buyerDigest); assert.notEqual(ticket, sellerDigest);
  }
});

test("ERC20 payment consent binds the configured puller and independent payer nonce, never the offer signer", () => {
  const p = packet(), type = "StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)";
  const intent = { payer: buyer, asset, maxAmount: price, saleRef: p.saleId,
    expectedPrimaryPolicyHash: p.configuration.expectedPrimaryPolicyHash, nonce: id("separate payer nonce"), deadline: 700n };
  const payload = signing.erc20PrimaryOfferPaymentIntentPayload(chainId, p.configuration, p.saleId, intent);
  assert.equal(payload.digest, digest(type, intent, payment, "6529StreamPaymentIntentVerifier"));
  assert.notEqual(payload.digest, digest(type, intent, carrier, "6529StreamPaymentIntentVerifier"));
  assert.notEqual(payload.digest, digest(offerType, p.offer));
  assert.equal(payload.domain.verifyingContract, payment);
  assert.throws(() => signing.erc20PrimaryOfferPaymentIntentPayload(chainId, p.configuration, p.saleId, { ...intent, payer: executor }));
  assert.throws(() => signing.erc20PrimaryOfferPaymentIntentPayload(chainId, p.configuration, p.saleId, { ...intent, maxAmount: price - 1n }));
  assert.equal(signing.erc20PrimaryOfferPaymentIntentPayload(chainId, p.configuration, p.saleId, { ...intent, nonce: ZeroHash }).message.nonce, ZeroHash);
});

test("all 19 Safe CALLs retain actual authorities, original payloads and zero value; callbacks stay restricted", async () => {
  const p = packet(false, buyer), q = candidate(p), intent = { payer: buyer, asset, maxAmount: price,
    saleRef: p.saleId, expectedPrimaryPolicyHash: p.configuration.expectedPrimaryPolicyHash,
    nonce: id("separate payment consent"), deadline: 700n };
  const actions = [];
  const add = (kind, target, caller, iface, method, args) => actions.push({ kind, safe: caller,
    intent: `Review ${method}`, prepared: { caller, call: { to: target, value: 0n, data: iface.encodeFunctionData(method, args) } } });
  add("sale", carrier, owner, saleAbi, "configureCollectionSigner", [73n, seller, 2n, id("signer evidence"), true]);
  add("sale", carrier, owner, saleAbi, "registerPrimaryOffer", [p.configuration, []]);
  add("sale", carrier, owner, saleAbi, "cancelPrimaryOffer", [p.saleId]);
  add("sale", carrier, executor, saleAbi, "expirePrimaryOffer", [p.saleId]);
  add("sale", carrier, executor, saleAbi, "syncCollectionContest", [73n]);
  add("sale", carrier, A(16), saleAbi, "setPaused", [true, id("pause reason")]);
  add("sale", carrier, A(17), saleAbi, "setSalePaused", [p.saleId, false, id("unpause reason")]);
  add("sale", carrier, A(18), saleAbi, "raiseGasParameter", [id("governed gas id"), 400000n]);
  add("sale", carrier, owner, saleAbi, "transferOwnership", [A(19)]);
  add("sale", carrier, owner, saleAbi, "renounceOwnership", []);
  add("sale", carrier, seller, saleAbi, "revokeAuthorization", [p.authorization, { authorizer: seller, kind: 2n, signature: "0x" }]);
  add("payment", payment, buyer, paymentAbi, "settleERC20PrimarySaleByPayer", [q.candidate, q.executionData]);
  add("payment", payment, buyer, paymentAbi, "settleERC20PrimarySaleWithIntent", [q.candidate, intent, "0x1234", q.executionData]);
  add("payment", payment, buyer, paymentAbi, "settleERC20PrimarySaleWithEIP2612Permit", [q.candidate, { deadline: 700n, v: 27n, r: id("r"), s: id("s") }, q.executionData]);
  add("payment", payment, buyer, paymentAbi, "settleERC20PrimarySaleWithPermit2", [q.candidate, { nonce: 55n, deadline: 700n, signature: "0xabcd" }, q.executionData]);
  add("payment", payment, buyer, paymentAbi, "revokePaymentIntent", [intent.nonce]);
  add("payment", payment, executor, paymentAbi, "revokePaymentIntentWithSignature", [{ payer: buyer, nonce: intent.nonce, deadline: 700n }, "0x1234"]);
  add("manager", manager, buyer, managerAbi, "voidMintOffer", [p.offer, 2n, "0x"]);
  add("token", asset, buyer, tokenAbi, "approve", [payment, price]);
  const review = createERC20PrimaryOfferSafeReview({ chainId, title: "Independent role and calldata inventory", catalog: fixture.abis, actions });
  assert.equal(review.plan.steps.length, 19); assert.deepEqual(verifySafeCallPlan(review.plan, review.abis), review.plan);
  assert.deepEqual(new Set(review.plan.steps.map(step => step.method)), new Set(review.inventory.map(row => row.method)));
  review.plan.steps.forEach((step, i) => {
    assert.equal(step.safe.toLowerCase(), actions[i].safe.toLowerCase()); assert.equal(step.transaction.data, actions[i].prepared.call.data);
    assert.equal(step.transaction.operation, 0); assert.equal(step.transaction.value, "0");
  });
  const seen = [], rpc = { getNetwork: async () => ({ chainId }), call: async tx => { seen.push(tx); throw Error("dependency unavailable"); } };
  await assert.rejects(simulateSafePlanStep(rpc, review.plan, review.abis, 11), /dependency unavailable/);
  await assert.rejects(simulateSafePlanStep(rpc, review.plan, review.abis, 11), /dependency unavailable/);
  assert.deepEqual(seen[0], seen[1]); assert.equal(seen.length, 2); assert.equal(seen[0].from, buyer);
  const badRole = structuredClone(actions); badRole[11].safe = executor;
  assert.throws(() => createERC20PrimaryOfferSafeReview({ chainId, title: "role swap", catalog: fixture.abis, actions: badRole }), /actual caller/);
  const value = structuredClone(actions); value[11].prepared.call.value = 1n;
  assert.throws(() => createERC20PrimaryOfferSafeReview({ chainId, title: "native funding", catalog: fixture.abis, actions: value }), /zero native value/);
  const callback = { kind: "payment", safe: recorder, intent: "invalid direct callback", prepared: { caller: recorder,
    call: { to: payment, value: 0n, data: paymentAbi.encodeFunctionData("fundERC20PrimarySale", [q.candidateCommitment, q.settlementKey, asset, price]) } } };
  assert.throws(() => createERC20PrimaryOfferSafeReview({ chainId, title: "callback", catalog: fixture.abis, actions: [callback] }), /not a user-entry/);
});

function preparedPacket(selected = false, actualExecutor = buyer) {
  const p = packet(selected, actualExecutor), q = candidate(p);
  const prepared = workflow.prepareERC20PrimaryOfferAcceptance(chainId, carrier, core, manager, recorder,
    actualExecutor, p.configuration, p.acceptance);
  return { ...p, ...q, prepared };
}

test("order-one execution, candidate and settlement preimages match literal domains and full compiled tuples", () => {
  const p = preparedPacket(true), c = p.candidate;
  assert.equal(workflow.erc20PrimaryOfferExecutionId(chainId, c), c.executionBinding.executionId);
  assert.equal(workflow.erc20PrimaryOfferCandidateCommitment(chainId, payment, recorder, c), p.candidateCommitment);
  assert.equal(workflow.erc20PrimaryOfferSettlementKey(chainId, recorder, carrier, c.executionBinding.executionId), p.settlementKey);
  assert.notEqual(c.currentPolicyHash, c.boundPolicyHash); // A still-admitted phase-policy grace is not a new signing domain.
  assert.equal(p.prepared.saleExecutionData, p.executionData);
  assert.equal(new Set([p.configuration.offerDigest, p.prepared.signing.buyerAuthorizationId,
    p.prepared.signing.sellerReplayDigest, c.executionBinding.executionId, p.candidateCommitment, p.settlementKey]).size, 6);
  assert.equal(Object.hasOwn(p.prepared, "purchaseId"), false);
  assert.notEqual(workflow.erc20PrimaryOfferSettlementKey(chainId + 1n, recorder, carrier, c.executionBinding.executionId), p.settlementKey);
  // Alternative asset/destination labels cannot create a second official key for one execution.
  const alternate = { ...c, asset: A(21), rights: { ...c.rights, wallet: A(22) } };
  assert.equal(workflow.erc20PrimaryOfferExecutionId(chainId, alternate), c.executionBinding.executionId);
  assert.notEqual(workflow.erc20PrimaryOfferCandidateCommitment(chainId, payment, recorder, alternate), p.candidateCommitment);
  assert.equal(workflow.erc20PrimaryOfferSettlementKey(chainId, recorder, carrier, alternate.executionBinding.executionId), p.settlementKey);
  assert.throws(() => workflow.prepareERC20PrimaryOfferFunding(p.prepared, alternate, { kind: "payer" }));
  assert.throws(() => workflow.prepareERC20PrimaryOfferFunding(p.prepared, { ...c, orchestrationOrder: 2n }, { kind: "payer" }));
  assert.throws(() => workflow.prepareERC20PrimaryOfferFunding(p.prepared, { ...c, saleExecutionHash: id("changed nested acceptance") }, { kind: "payer" }));
});

test("all four typed funding routes match exact contract20 calldata and actual buyer or delegated caller rules", () => {
  const p = preparedPacket(true), intent = { payer: buyer, asset, maxAmount: price, saleRef: p.saleId,
    expectedPrimaryPolicyHash: p.configuration.expectedPrimaryPolicyHash, nonce: id("payer nonce"), deadline: 700n };
  const routes = [
    ["settleERC20PrimarySaleByPayer", { kind: "payer" }, [p.candidate, p.executionData]],
    ["settleERC20PrimarySaleWithIntent", { kind: "intent", intent, signature: "0x1234" }, [p.candidate, intent, "0x1234", p.executionData]],
    ["settleERC20PrimarySaleWithEIP2612Permit", { kind: "eip2612", permit: { deadline: 700n, v: 27n, r: id("r"), s: id("s") } }, null],
    ["settleERC20PrimarySaleWithPermit2", { kind: "permit2", permit: { nonce: 55n, deadline: 700n, signature: "0xabcd" } }, null],
  ];
  for (const [method, route, args] of routes) {
    const funding = workflow.prepareERC20PrimaryOfferFunding(p.prepared, p.candidate, route);
    assert.equal(funding.call.to, payment); assert.equal(funding.call.value, 0n); assert.equal(funding.caller, buyer);
    assert.equal(funding.call.data, paymentAbi.encodeFunctionData(method, args ?? [p.candidate, route.permit, p.executionData]));
    assert.equal(funding.candidateCommitment, p.candidateCommitment); assert.equal(funding.settlementKey, p.settlementKey);
    const review = createERC20PrimaryOfferSafeReview({ chainId, title: method, catalog: fixture.abis,
      actions: [{ kind: "payment", safe: buyer, intent: method, prepared: funding }] });
    assert.equal(review.plan.steps[0].transaction.data, funding.call.data);
  }
  const delegated = preparedPacket(false, executor);
  for (const route of [routes[0][1], routes[2][1], routes[3][1]]) {
    assert.throws(() => workflow.prepareERC20PrimaryOfferFunding(delegated.prepared, delegated.candidate, route), /actual contract20 caller/);
  }
  const viaIntent = workflow.prepareERC20PrimaryOfferFunding(delegated.prepared, delegated.candidate, routes[1][1]);
  assert.equal(viaIntent.caller, executor); assert.equal(viaIntent.route.intent.payer, buyer);
  assert.throws(() => workflow.prepareERC20PrimaryOfferFunding(delegated.prepared, delegated.candidate,
    { ...routes[1][1], intent: { ...intent, payer: executor } }));
});

test("typed registration, approval and independent revocations retain compiled calls and historical payloads", () => {
  const p = preparedPacket(), approval = workflow.prepareERC20PrimaryOfferTokenApproval(asset, buyer, payment, price);
  assert.equal(approval.call.data, tokenAbi.encodeFunctionData("approve", [payment, price]));
  assert.notEqual(tokenAbi.decodeFunctionData("approve", approval.call.data)[0], carrier);
  const registration = workflow.prepareERC20PrimaryOfferRegistration(chainId, carrier, owner, p.saleNonce, p.configuration, []);
  assert.equal(registration.call.data, saleAbi.encodeFunctionData("registerPrimaryOffer", [p.configuration, []]));
  const buyerRevocation = workflow.prepareERC20PrimaryOfferBuyerRevocation(chainId, carrier, manager, A(20), buyer, p.offer, 2n, "0x");
  assert.equal(buyerRevocation.call.data, managerAbi.encodeFunctionData("voidMintOffer", [p.offer, 2n, "0x"]));
  const proof = { authorizer: seller, kind: 2n, signature: "0x" };
  const sellerRevocation = workflow.prepareERC20PrimaryOfferSellerRevocation(chainId, carrier, seller, p.configuration, p.authorization, proof);
  assert.equal(sellerRevocation.call.data, saleAbi.encodeFunctionData("revokeAuthorization", [p.authorization, proof]));
  const revocation = { payer: buyer, nonce: id("independent payment revocation"), deadline: 700n };
  const direct = workflow.prepareERC20PrimaryOfferPaymentRevocation(chainId, payment, buyer, revocation);
  const relayed = workflow.prepareERC20PrimaryOfferPaymentRevocation(chainId, payment, executor, revocation, "0x1234");
  assert.equal(direct.call.data, paymentAbi.encodeFunctionData("revokePaymentIntent", [revocation.nonce]));
  assert.equal(relayed.call.data, paymentAbi.encodeFunctionData("revokePaymentIntentWithSignature", [revocation, "0x1234"]));
  assert.equal(new Set([buyerRevocation.payload.digest, sellerRevocation.payload.digest, relayed.payload.digest]).size, 3);
});
