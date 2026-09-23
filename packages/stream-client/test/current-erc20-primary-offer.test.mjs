import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import * as workflow from "../dist/current-erc20-primary-offer.js";
import { erc20PrimaryOfferBatchHashes, erc20PrimaryOfferSaleId, erc20PrimaryOfferSaleOfferPayload, erc20PrimaryOfferConfigurationHash, erc20PrimaryOfferPaymentIntentPayload } from "../dist/current-erc20-primary-offer-signing.js";
import { curatedContentLeaf } from "../dist/current-curated-content.js";
import { toSafeCall } from "../dist/safe.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-erc20-primary-offer-abi.json", import.meta.url)));
const saleAbi = new Interface(fixture.abis.sale), paymentAbi = new Interface(fixture.abis.payment);
const managerAbi = new Interface(fixture.abis.manager), recorderAbi = new Interface(fixture.abis.recorder);
const coder = AbiCoder.defaultAbiCoder();
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const adapter = A(1), paymentAdapter = A(2), recorder = A(3), core = A(4), manager = A(5);
const buyer = A(6), seller = A(7), owner = A(8), asset = A(9), delegate = A(10), ledger = A(11);
const chainId = 31337n, collectionId = 12n, phaseId = id("erc20 workflow phase"), saleNonce = 17n;
const saleId = erc20PrimaryOfferSaleId(chainId, adapter, collectionId, phaseId, saleNonce);
const blockTag = 30, timestamp = 200n, rawTokenData = "0x001234", mintCommitment = id("workflow mint");
const price = (1n << 180n) + 100n;

function packet({ selected = false, executor = buyer, buyerSigner = buyer } = {}) {
  const contentId = selected ? id("selected artwork") : ZeroHash;
  const tokenDataHash = selected ? keccak256(rawTokenData) : ZeroHash;
  const leaf = selected ? curatedContentLeaf(chainId, adapter, saleId, contentId, tokenDataHash) : ZeroHash;
  const offer = { chainId, saleAdapter: adapter, core, collectionId, tokenId: 0n, contentSelectionHash: leaf,
    buyer, asset, price, nonce: id("workflow offer nonce"), deadline: 990n, finalizeBy: 0n };
  const config = { collectionId, phaseId, asset, paymentAdapter, price, poster: seller, startsAt: 100n, endsAt: 900n,
    mintPolicyHash: id("bound mint policy"), expectedPrimaryPolicyHash: id("primary PROFILE policy"), primaryPolicyMode: 0n,
    contentManifestRoot: leaf, buyer, offerDigest: erc20PrimaryOfferSaleOfferPayload(chainId, adapter, offer).digest,
    contentId, tokenDataHash, signer: seller, signerKind: 2n, signerEvidenceHash: id("signer evidence"),
    signerRevision: 3n, signerAuthority: owner };
  const authorization = { chainId, saleAdapter: adapter, mintManager: manager, collectionId, phaseId, saleId,
    saleKind: 6n, revenueClass: id("PRIMARY_SALE"), expectedPrimaryPolicyHash: config.expectedPrimaryPolicyHash,
    primaryPolicyMode: 0n, ...erc20PrimaryOfferBatchHashes(buyer, rawTokenData, mintCommitment), payer: buyer,
    executor, asset, unitPrice: price, quantity: 1n, contentSelectionHash: leaf, policyHash: config.mintPolicyHash,
    nonce: id("workflow seller nonce"), deadline: 800n, finalizeBy: 0n };
  const acceptance = { offer, buyerProof: { authorizer: buyerSigner, kind: 2n, signature: "0xaabb" },
    authorization, sellerProof: { authorizer: seller, kind: 2n, signature: "0xccdd" },
    selection: { content: { contentId, tokenDataHash, proof: [] }, tokenData: rawTokenData, mintCommitment, executionNonce: 4n },
    signerDelegation: { walletWide: true, index: 3n }, executorDelegation: { walletWide: false, index: 7n } };
  const prepared = workflow.prepareERC20PrimaryOfferAcceptance(chainId, adapter, core, manager, recorder, executor, config, acceptance);
  const lifecycle = { paymentAdapter, saleCreatedAt: 50n, saleAdapterRegistryRevision: 2n, paymentAdapterRegistryRevision: 8n };
  const candidate = { saleAdapter: adapter, executor, sale: { settlementId: saleId, revenueClass: id("PRIMARY_SALE"), policyMode: 0n,
    collectionId, tokenId: 0n, saleNonce, payer: buyer, poster: seller, beneficiary: buyer, amount: price,
    expectedPrimaryPolicyHash: config.expectedPrimaryPolicyHash }, lifecycleBinding: lifecycle,
    executionBinding: { executionId: ZeroHash, executionNonce: 4n, authorityMode: 1n, saleAuthorizationDigest: prepared.signing.sellerReplayDigest },
    asset, orchestrationOrder: 1n, mintManager: manager, operationIdentityCommitment: id("mint operation root"),
    operationId: id("mint operation id"), currentPolicyHash: id("current policy in a valid grace window"),
    boundPolicyHash: config.mintPolicyHash, rights: { profileId: id("PROFILE"), wallet: A(12), templateId: ZeroHash,
      assignmentHash: id("profile assignment"), entriesHash: id("profile entries") }, saleExecutionHash: keccak256(prepared.saleExecutionData) };
  candidate.executionBinding.executionId = workflow.erc20PrimaryOfferExecutionId(chainId, candidate);
  const record = { config, saleNonce, configHash: erc20PrimaryOfferConfigurationHash(chainId, adapter, config), lifecycle,
    artistId: id("artist"), bindingGeneration: 3n, bindingHash: id("artist binding"), gate: selected ? A(13) : ZeroAddress,
    gateCodeHash: selected ? id("gate code") : ZeroHash, gateConfigHash: selected ? id("gate config") : ZeroHash,
    manifestHash: selected ? id("manifest") : ZeroHash, contentCounterId: selected ? id("counter") : ZeroHash,
    contentCounterConfigHash: selected ? id("counter config") : ZeroHash, status: 1n };
  const intent = { payer: buyer, asset, maxAmount: price + 1n, saleRef: saleId, expectedPrimaryPolicyHash: config.expectedPrimaryPolicyHash, nonce: id("payer nonce"), deadline: 700n };
  return { config, acceptance, prepared, candidate, record, intent };
}
function settlement(plan) {
  const c = plan.candidate;
  return { candidateCommitment: plan.candidateCommitment, settlementKey: plan.settlementKey, profileId: c.rights.profileId,
    wallet: c.rights.wallet, asset, amount: price, executor: c.executor, executionId: c.executionBinding.executionId,
    escrowed: false, operationIdentityCommitment: c.operationIdentityCommitment, currentPolicyHash: c.currentPolicyHash, boundPolicyHash: c.boundPolicyHash };
}
function execution(plan) {
  const p = plan.prepared, c = plan.candidate;
  return { saleId, buyer, executor: p.caller, executionNonce: 4n, offerDigest: p.configuration.offerDigest,
    authorizationDigest: p.signing.sellerReplayDigest, authorizationId: p.signing.buyerAuthorizationId,
    contentLeaf: p.signing.contentSelectionHash, tokenDataHash: keccak256(rawTokenData), tokenId: 500n,
    settlementKey: plan.settlementKey, operationRoot: c.operationIdentityCommitment, operationId: c.operationId };
}
function funding(p, kind = "payer") {
  const route = kind === "payer" ? { kind } : kind === "intent" ? { kind, intent: p.intent, signature: "0xaabb" }
    : kind === "eip2612" ? { kind, permit: { deadline: 700n, v: 27n, r: id("r"), s: id("s") } }
    : { kind, permit: { nonce: 12n, deadline: 700n, signature: "0x1122" } };
  return workflow.prepareERC20PrimaryOfferFunding(p.prepared, p.candidate, route);
}
function provider(p, plan = funding(p), options = {}) {
  const calls = [];
  const result = settlement(plan), executed = execution(plan);
  const output = {
    async getNetwork() { options.onNetwork?.(); return { chainId: options.chainId ?? chainId }; },
    async call(request) {
      calls.push(request); assert.equal(request.blockTag, blockTag); assert.equal(request.value, 0n);
      const abi = request.to.toLowerCase() === adapter ? saleAbi : request.to.toLowerCase() === paymentAdapter ? paymentAbi
        : request.to.toLowerCase() === manager ? managerAbi : recorderAbi;
      const parsed = abi.parseTransaction({ data: request.data }); assert.ok(parsed);
      const name = parsed.name;
      if (options.reject?.(name, request)) throw Error(`dependency rejected ${name}`);
      if (options.raw?.[name]) return options.raw[name];
      let values;
      switch (name) {
        case "core": values = [core]; break;
        case "mintManager": values = [manager]; break;
        case "mintLedger": values = [ledger]; break;
        case "primarySaleSettlement": values = [recorder]; break;
        case "owner": values = [owner]; break;
        case "nextSaleNonce": values = [saleNonce]; break;
        case "saleIdFor": values = [saleId]; break;
        case "primaryOfferConfigurationHash": values = [p.record.configHash]; break;
        case "collectionSigner": values = [{ evidenceHash: p.config.signerEvidenceHash, revision: p.config.signerRevision, enabled: true, authority: owner }]; break;
        case "registerPrimaryOffer": assert.equal(request.from, owner); values = [saleId]; break;
        case "saleRecord": values = [{ ...p.record, status: options.completed ? 4n : 1n }]; break;
        case "primaryOfferSettlementBinding": values = [saleNonce, seller, p.record.configHash]; break;
        case "primaryOfferAuthorizationBinding": values = [collectionId, phaseId, seller, 2n, p.record.configHash]; break;
        case "authorizationDigest": values = [p.prepared.signing.sellerReplayDigest]; break;
        case "nextExecutionNonce": values = [4n]; break;
        case "isAuthorizationUsed": case "digestConsumed": case "isPaymentIntentNonceUsed": case "settlementConsumed": values = [Boolean(options.completed)]; break;
        case "digestRevoked": values = [false]; break;
        case "previewExecution": values = [p.candidate]; break;
        case "paymentIntentDigest": values = [erc20PrimaryOfferPaymentIntentPayload(chainId, p.config, saleId, p.intent).digest]; break;
        case "mintOfferAuthorizationId": case "voidMintOffer": values = [p.prepared.signing.buyerAuthorizationId]; break;
        case "executionRecord": values = [executed]; break;
        case "settlementResult": values = [result]; break;
        case "revokeAuthorization": values = []; break;
        default:
          if (name.startsWith("settleERC20PrimarySale")) { assert.equal(request.from, p.prepared.caller); values = [result]; }
          else throw Error(`unhandled ${name}`);
      }
      return abi.encodeFunctionResult(name, values);
    },
  };
  return { ...output, calls, result, executed };
}

test("registration and preview use exact compiled flat tuples and bounded 1184/1088-byte reads", async () => {
  for (const selected of [false, true]) {
    const p = packet({ selected }), rpc = provider(p);
    const registration = workflow.prepareERC20PrimaryOfferRegistration(chainId, adapter, owner, saleNonce, p.config, []);
    assert.equal(registration.call.data, saleAbi.encodeFunctionData("registerPrimaryOffer", [p.config, []]));
    assert.equal(await workflow.simulateERC20PrimaryOfferRegistration(rpc, registration, { blockTag }), saleId);
    const candidate = await workflow.inspectERC20PrimaryOfferAcceptance(rpc, p.prepared, { blockTag });
    assert.deepEqual(candidate, workflow.normalizeERC20SettlementCandidate(p.candidate));
    assert.equal((saleAbi.encodeFunctionResult("saleRecord", [p.record]).length - 2) / 2, 1184);
    assert.equal((saleAbi.encodeFunctionResult("previewExecution", [p.candidate]).length - 2) / 2, 1088);
    assert.notEqual(candidate.currentPolicyHash, candidate.boundPolicyHash);
  }
});

test("four funding routes target contract20 with exact canonical acceptance and zero value", async () => {
  const p = packet();
  for (const kind of ["payer", "intent", "eip2612", "permit2"]) {
    const plan = funding(p, kind), rpc = provider(p, plan);
    assert.equal(plan.call.to.toLowerCase(), paymentAdapter); assert.equal(plan.caller.toLowerCase(), buyer);
    assert.equal(plan.call.value, 0n); assert.equal(toSafeCall(plan.call).operation, 0);
    const parsed = paymentAbi.parseTransaction({ data: plan.call.data });
    assert.equal(parsed.args.at(-1), p.prepared.saleExecutionData);
    assert.deepEqual(await workflow.simulateERC20PrimaryOfferFunding(rpc, plan, { blockTag }), settlement(plan));
  }
});

test("nonpayer executor requires intent even with buyer offer signature; live delegation remains checked", async () => {
  const p = packet({ executor: delegate }), intentPlan = funding(p, "intent");
  for (const kind of ["payer", "eip2612", "permit2"]) assert.throws(() => funding(p, kind), /actual contract20 caller/);
  const rpc = provider(p, intentPlan, { reject: name => name === "previewExecution" });
  await assert.rejects(workflow.simulateERC20PrimaryOfferFunding(rpc, intentPlan, { blockTag }), /dependency rejected previewExecution/);
  assert.ok(!rpc.calls.some(c => c.data === intentPlan.call.data));
  assert.throws(() => workflow.prepareERC20PrimaryOfferFunding(p.prepared, p.candidate, { kind: "intent", intent: { ...p.intent, payer: delegate }, signature: "0xaabb" }), /PaymentIntent/);
  const sameBuyer = packet(); const samePlan = funding(sameBuyer, "intent");
  await assert.rejects(workflow.simulateERC20PrimaryOfferFunding(provider(sameBuyer, samePlan, { reject: name => name === "settleERC20PrimarySaleWithIntent" }), samePlan, { blockTag }), /dependency rejected/);
});

test("candidate binding rejects carrier funding, recipient substitutions, wrong profile/order and execution bytes", () => {
  const p = packet();
  for (const change of [
    { executor: delegate }, { asset: A(30) }, { saleAdapter: paymentAdapter }, { orchestrationOrder: 2n },
    { saleExecutionHash: id("different execution bytes") }, { rights: { ...p.candidate.rights, templateId: id("template") } },
    { sale: { ...p.candidate.sale, beneficiary: adapter } },
    { lifecycleBinding: { ...p.candidate.lifecycleBinding, paymentAdapter: adapter } },
    { executionBinding: { ...p.candidate.executionBinding, executionId: id("invented purchase") } },
  ]) assert.throws(() => workflow.prepareERC20PrimaryOfferFunding(p.prepared, { ...p.candidate, ...change }, { kind: "payer" }));
  assert.throws(() => workflow.prepareERC20PrimaryOfferAcceptance(chainId, adapter, core, manager, recorder, buyer, p.config,
    { ...p.acceptance, sellerProof: { ...p.acceptance.sellerProof, authorizer: owner } }), /membership/);
});

test("selected proof and collection empty-selection branches are enforced before RPC", () => {
  const p = packet({ selected: true });
  assert.throws(() => workflow.prepareERC20PrimaryOfferAcceptance(chainId, adapter, core, manager, recorder, buyer, p.config,
    { ...p.acceptance, selection: { ...p.acceptance.selection, content: { ...p.acceptance.selection.content, proof: [id("wrong sibling")] } } }), /proof/);
  const unselected = packet();
  assert.throws(() => workflow.prepareERC20PrimaryOfferAcceptance(chainId, adapter, core, manager, recorder, buyer, unselected.config,
    { ...unselected.acceptance, selection: { ...unselected.acceptance.selection, content: p.acceptance.selection.content } }), /proof/);
});

test("mutated plans are rejected and caller-owned inputs are captured before any await", async () => {
  const p = packet(), original = funding(p, "intent");
  const forged = structuredClone(original); forged.call.value = 1n;
  await assert.rejects(workflow.simulateERC20PrimaryOfferFunding(provider(p, original), forged, { blockTag }), /canonical reconstruction/);
  const clone = structuredClone(original);
  const rpc = provider(p, original, { onNetwork() { clone.route.intent.maxAmount = 1n; clone.prepared.acceptance.selection.executionNonce = 90n; clone.call.data = "0x"; } });
  assert.deepEqual(await workflow.simulateERC20PrimaryOfferFunding(rpc, clone, { blockTag }), settlement(original));
  assert.throws(() => workflow.prepareERC20PrimaryOfferFunding(p.prepared, p.candidate, { kind: "payer", nativeFee: 1n }), /unknown/);
});

test("malformed and noncanonical bounded RPC returns fail closed", async () => {
  const p = packet();
  for (const name of ["saleRecord", "previewExecution", "primaryOfferSettlementBinding"]) {
    const correct = name === "saleRecord" ? saleAbi.encodeFunctionResult(name, [p.record]) : name === "previewExecution" ? saleAbi.encodeFunctionResult(name, [p.candidate]) : saleAbi.encodeFunctionResult(name, [saleNonce, seller, p.record.configHash]);
    for (const raw of [correct + "00", correct.slice(0, -2), "0x" + "00".repeat(262145)]) {
      await assert.rejects(workflow.inspectERC20PrimaryOfferAcceptance(provider(p, funding(p), { raw: { [name]: raw } }), p.prepared, { blockTag }), /length|oversized/);
    }
  }
  const wrongBoolean = "0x" + "0".repeat(63) + "2";
  await assert.rejects(workflow.inspectERC20PrimaryOfferAcceptance(provider(p, funding(p), { raw: { isAuthorizationUsed: wrongBoolean } }), p.prepared, { blockTag }), /Noncanonical/);
  await assert.rejects(workflow.inspectERC20PrimaryOfferAcceptance(provider(p), p.prepared, { blockTag: "latest" }), /concrete/);
});

test("failed dependencies preserve exact funding payload and independent replay for retry", async () => {
  const p = packet({ executor: delegate }), plan = funding(p, "intent"); let failed = true;
  const originalData = plan.call.data, originalIntent = plan.route.intent.nonce;
  const rpc = provider(p, plan, { reject: name => failed && name === "settleERC20PrimarySaleWithIntent" });
  await assert.rejects(workflow.simulateERC20PrimaryOfferFunding(rpc, plan, { blockTag }), /dependency/);
  failed = false;
  assert.deepEqual(await workflow.simulateERC20PrimaryOfferFunding(rpc, plan, { blockTag }), settlement(plan));
  assert.equal(plan.call.data, originalData); assert.equal(plan.route.intent.nonce, originalIntent);
  const fundingCalls = rpc.calls.filter(c => c.data === originalData); assert.equal(fundingCalls.length, 2);
});

test("completed reads bind original executionId, historical96-byte binding and recorder receipt", async () => {
  const p = packet({ executor: delegate }), plan = funding(p, "intent"), rpc = provider(p, plan, { completed: true });
  const complete = await workflow.inspectCompletedERC20PrimaryOffer(rpc, plan, { blockTag });
  assert.deepEqual(complete.execution, execution(plan)); assert.deepEqual(complete.settlement, settlement(plan));
  assert.deepEqual(await workflow.readERC20PrimaryOfferSettlementBinding(rpc, adapter, saleId, { blockTag }), { saleNonce, poster: seller, configHash: p.record.configHash });
  const wrong = { ...settlement(plan), operationIdentityCommitment: id("wrong root") };
  await assert.rejects(workflow.inspectCompletedERC20PrimaryOffer(provider(p, plan, { completed: true, raw: { settlementResult: recorderAbi.encodeFunctionResult("settlementResult", [wrong]) } }), plan, { blockTag }), /result differs/);
});

test("buyer and seller historical revocations use original domains without live sale dependencies", async () => {
  const p = packet(), rpc = provider(p);
  const b = workflow.prepareERC20PrimaryOfferBuyerRevocation(chainId, adapter, manager, ledger, buyer, p.acceptance.offer, 2n, "0x");
  assert.equal(b.call.data, managerAbi.encodeFunctionData("voidMintOffer", [p.acceptance.offer, 2n, "0x"]));
  assert.equal(await workflow.simulateERC20PrimaryOfferBuyerRevocation(rpc, b, { blockTag }), p.prepared.signing.buyerAuthorizationId);
  const s = workflow.prepareERC20PrimaryOfferSellerRevocation(chainId, adapter, seller, p.config, p.acceptance.authorization, { authorizer: seller, kind: 2n, signature: "0x" });
  await workflow.simulateERC20PrimaryOfferSellerRevocation(rpc, s, { blockTag });
  assert.equal(s.payload.primaryType, "SaleAuthorizationRevocation");
  assert.ok(rpc.calls.every(c => !["previewExecution", "collectionSigner", "saleRecord"].includes(saleAbi.parseTransaction({ data: c.data })?.name)));
  await assert.rejects(workflow.inspectERC20PrimaryOfferSellerRevocation(provider(p, funding(p), { completed: true }), s, { blockTag }), /replay/);
});

test("payment revocation uses current tuple selector and payer-owned nonce independently", async () => {
  const revocation = { payer: buyer, nonce: ZeroHash, deadline: 700n };
  for (const signature of [null, "0xaabb"]) {
    const caller = signature === null ? buyer : delegate;
    const plan = workflow.prepareERC20PrimaryOfferPaymentRevocation(chainId, paymentAdapter, caller, revocation, signature);
    const method = signature === null ? "revokePaymentIntent" : "revokePaymentIntentWithSignature";
    assert.equal(plan.call.data, paymentAbi.encodeFunctionData(method, signature === null ? [ZeroHash] : [revocation, signature]));
    const rpc = { async getNetwork() { return { chainId }; }, async call(request) {
      const p = paymentAbi.parseTransaction({ data: request.data });
      assert.equal(request.blockTag, blockTag);
      return paymentAbi.encodeFunctionResult(p.name, p.name === "isPaymentIntentNonceUsed" ? [false] : p.name === "paymentIntentRevocationDigest" ? [plan.payload.digest] : []);
    } };
    await workflow.simulateERC20PrimaryOfferPaymentRevocation(rpc, plan, { blockTag });
  }
  assert.throws(() => workflow.prepareERC20PrimaryOfferPaymentRevocation(chainId, paymentAdapter, delegate, revocation), /payer caller/);
});

test("single Safe CALL mined receipt binds inner calldata, actual caller, execution event and exact block", async () => {
  const p = packet(), plan = funding(p), rpc = provider(p, plan, { completed: true });
  const transactionHash = id("mined offer transaction"), blockHash = id("mined block");
  const event = saleAbi.encodeEventLog("PrimaryOfferExecution", [plan.candidate.executionBinding.executionId, execution(plan)]);
  const safeAbi = new Interface(["function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns (bool)"]);
  const tx = { hash: transactionHash, from: owner, to: buyer, data: safeAbi.encodeFunctionData("execTransaction", [paymentAdapter, 0n, plan.call.data, 0, 0, 0, 0, ZeroAddress, ZeroAddress, "0xaabb"]), value: 0n, blockNumber: blockTag, blockHash };
  const receipt = { hash: transactionHash, status: 1, blockNumber: blockTag, blockHash, logs: [{ address: adapter, ...event }] };
  const mined = { ...rpc, async getTransaction() { return tx; }, async getTransactionReceipt() { return receipt; }, async getBlock() { return { hash: blockHash, number: blockTag, timestamp: Number(timestamp) }; } };
  const found = await workflow.inspectERC20PrimaryOfferFundingReceipt(mined, plan, { transactionHash, execution: "safe" });
  assert.equal(found.execution.tokenId, 500n);
  tx.data = safeAbi.encodeFunctionData("execTransaction", [paymentAdapter, 0n, plan.call.data, 1, 0, 0, 0, ZeroAddress, ZeroAddress, "0xaabb"]);
  await assert.rejects(workflow.inspectERC20PrimaryOfferFundingReceipt(mined, plan, { transactionHash, execution: "safe" }), /envelope differs/);
  tx.data = plan.call.data; tx.to = paymentAdapter; tx.from = buyer;
  assert.equal((await workflow.inspectERC20PrimaryOfferFundingReceipt(mined, plan, { transactionHash, execution: "direct" })).execution.tokenId, 500n);
  receipt.logs = [];
  await assert.rejects(workflow.inspectERC20PrimaryOfferFundingReceipt(mined, plan, { transactionHash, execution: "direct" }), /exactly one/);
  receipt.logs = [{ address: adapter, ...event, data: event.data + "00" }];
  await assert.rejects(workflow.inspectERC20PrimaryOfferFundingReceipt(mined, plan, { transactionHash, execution: "direct" }), /Malformed/);
  receipt.logs = [{ address: adapter, ...event }];
  await assert.rejects(workflow.inspectERC20PrimaryOfferFundingReceipt({ ...mined, async getBlock() { return { hash: id("replacement block") }; } }, plan, { transactionHash, execution: "direct" }), /canonical/);
});

test("all administrative carrier writes preserve original selector and ordinary CALL roles", async () => {
  const plans = [
    workflow.prepareERC20PrimaryOfferSignerConfiguration(adapter, owner, collectionId, seller, 2n, id("evidence"), true),
    workflow.prepareERC20PrimaryOfferCancel(adapter, owner, saleId),
    workflow.prepareERC20PrimaryOfferExpire(adapter, buyer, saleId),
    workflow.prepareERC20PrimaryOfferPause(adapter, owner, true, id("reason")),
    workflow.prepareERC20PrimaryOfferSalePause(adapter, owner, saleId, false, id("reason")),
    workflow.prepareERC20PrimaryOfferContestSync(adapter, buyer, collectionId),
    workflow.prepareERC20PrimaryOfferGasRaise(adapter, owner, id("gas row"), 100000n),
    workflow.prepareERC20PrimaryOfferOwnershipTransfer(adapter, owner, seller),
    workflow.prepareERC20PrimaryOfferOwnershipRenunciation(adapter, owner),
  ];
  for (const plan of plans) {
    assert.equal(plan.call.data, saleAbi.encodeFunctionData(plan.method, plan.args));
    assert.equal(toSafeCall(plan.call).operation, 0); assert.equal(plan.call.value, 0n);
    const clone = structuredClone(plan);
    const rpc = { async getNetwork() { clone.args[0] = false; clone.call.data = "0x"; return { chainId }; },
      async call(request) { assert.equal(request.data, plan.call.data); assert.equal(request.from, plan.caller); assert.equal(request.blockTag, blockTag); return "0x"; } };
    await workflow.simulateERC20PrimaryOfferAction(rpc, chainId, clone, { blockTag });
  }
  const approval = workflow.prepareERC20PrimaryOfferTokenApproval(asset, buyer, paymentAdapter, price);
  assert.equal(new Interface(fixture.abis.token).decodeFunctionData("approve", approval.call.data)[0].toLowerCase(), paymentAdapter);
});
