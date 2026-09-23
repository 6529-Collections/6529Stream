import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, concat, id, keccak256 } from "ethers";
import * as fixed from "../dist/current-curated-fixed.js";
import * as priv from "../dist/current-curated-private.js";
import { buildCuratedManifest, curatedPurchaseId } from "../dist/current-curated-content.js";
import { createSafeCallPlan, verifySafeCallPlan, simulateSafePlanStep } from "../dist/safe-plan.js";

const fixture = JSON.parse(await readFile(new URL("./fixtures/current-curated-abi.json", import.meta.url), "utf8"));
const abi = new Interface(fixture.abis.fixed), coder = AbiCoder.defaultAbiCoder();
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chain = 31337n, adapter = A(1), owner = A(2), buyer = A(3), recipient = A(4), manager = A(5), phase = id("phase");
const saleId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
  [id("6529STREAM_SALE_V1"), chain, adapter, 0n, 3n, phase, 7n]));
const manifest = buildCuratedManifest({ chainId: chain, adapter, manager, saleId, collectionId: 3n, phaseId: phase,
  counterId: id("counter"), rows: [{ contentId: ZeroHash, tokenDataHash: keccak256("0x"), previewURI: "ipfs://empty" }] });
const common = { collectionId: 3n, phaseId: phase, price: (1n << 200n) + 900n, poster: owner, startsAt: 100n,
  endsAt: 200n, mintPolicyHash: id("mint-policy"), expectedPrimaryPolicyHash: id("primary-policy"),
  primaryPolicyMode: 0n, contentManifestRoot: manifest.publication.manifestRoot };
const publicConfig = { sale: common, mode: 1n, differentiatedContent: false, publicSelectionDisclosure: true,
  windows: { commitOpen: 0n, commitClose: 0n, revealOpen: 0n, revealClose: 0n, absoluteEscape: 0n } };
const commitConfig = { sale: { ...common, primaryPolicyMode: 1n }, mode: 0n, differentiatedContent: true, publicSelectionDisclosure: false,
  windows: { commitOpen: 100n, commitClose: 120n, revealOpen: 140n, revealClose: 200n, absoluteEscape: 200n } };
const selection = { content: manifest.selections[0], tokenData: "0x", mintCommitment: id("mint"), recipient, purchaseNonce: (1n << 160n) + 5n };
const configTuple = "tuple(tuple(uint256 collectionId,bytes32 phaseId,uint256 price,address poster,uint64 startsAt,uint64 endsAt,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 contentManifestRoot) sale,uint8 mode,bool differentiatedContent,bool publicSelectionDisclosure,tuple(uint64 commitOpen,uint64 commitClose,uint64 revealOpen,uint64 revealClose,uint64 absoluteEscape) windows)";

test("fixed registration hashes whole immutable configuration and preserves original sale identity", () => {
  for (const config of [publicConfig, commitConfig]) {
    const expected = keccak256(coder.encode(["bytes32", "uint256", "address", configTuple],
      [id("6529STREAM_NATIVE_CURATED_FIXED_CONFIG_V1"), chain, adapter, config]));
    assert.equal(fixed.curatedFixedConfigurationHash(chain, adapter, config), expected);
    const prepared = fixed.prepareCuratedFixedRegistration(chain, adapter, owner, 7n, config);
    assert.equal(prepared.expectedSaleId, saleId); assert.equal(prepared.configurationHash, expected);
    assert.deepEqual(prepared.call, { to: adapter, value: 0n, data: abi.encodeFunctionData("registerCuratedFixedSale", [config]) });
    assert.equal(prepared.caller, owner);
  }
  assert.throws(() => fixed.curatedFixedConfigurationHash(chain, adapter, { ...publicConfig, differentiatedContent: true }));
  assert.throws(() => fixed.curatedFixedConfigurationHash(chain, adapter, { ...publicConfig, publicSelectionDisclosure: false }));
  assert.throws(() => fixed.curatedFixedConfigurationHash(chain, adapter, { ...commitConfig, windows: { ...commitConfig.windows, absoluteEscape: 199n } }));
});

test("public full-price CALL differs from price-only commitment and fee-only reveal", () => {
  const purchase = fixed.prepareCuratedPublicPurchase(chain, adapter, buyer, saleId, publicConfig, selection, 11n);
  const commit = fixed.prepareCuratedSelectionCommit(chain, adapter, buyer, saleId, commitConfig, selection.content, ZeroHash, selection.purchaseNonce);
  const reveal = fixed.prepareCuratedSelectionReveal(chain, adapter, buyer, saleId, commitConfig, selection, ZeroHash, 11n);
  assert.equal(purchase.call.value, common.price + 11n);
  assert.equal(commit.call.value, common.price); assert.equal(reveal.call.value, 11n);
  assert.equal(purchase.call.data, abi.encodeFunctionData("purchaseSelectedContent", [saleId, selection]));
  const literalCommit = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "bytes32", "bytes32"],
    [id("6529STREAM_CONTENT_COMMIT_V1"), chain, adapter, saleId, buyer, manifest.publication.manifestRoot, ZeroHash]));
  assert.equal(commit.commitment, literalCommit); assert.equal(reveal.commitment, literalCommit);
  assert.equal(commit.call.data, abi.encodeFunctionData("commitSelection", [saleId, literalCommit, selection.purchaseNonce]));
  assert.equal(reveal.call.data, abi.encodeFunctionData("revealSelection", [saleId, selection, ZeroHash]));
  assert.equal(reveal.expectedPurchaseId, curatedPurchaseId(chain, adapter, saleId, buyer, selection.purchaseNonce));
  assert.equal(commit.expectedPurchaseId, reveal.expectedPurchaseId);
  assert.throws(() => fixed.prepareCuratedPublicPurchase(chain, adapter, buyer, saleId, publicConfig, { ...selection, recipient: adapter }, 11n));
});

test("selection and excess credits keep distinct selectors and delegated recipient ownership", () => {
  const witness = { walletWide: false, index: 1n << 180n }, delegate = A(6);
  const cases = [
    [fixed.prepareCuratedSelectionRefundClaim(adapter, buyer, saleId, recipient), "claimSelectionRefund", [saleId, recipient], buyer],
    [fixed.prepareCuratedExcessRefundClaim(adapter, buyer, saleId, recipient), "claimRefund", [saleId, recipient], buyer],
    [fixed.prepareCuratedSelectionRefundDelegatedClaim(adapter, delegate, saleId, buyer, witness), "claimSelectionRefundDelegated", [saleId, buyer, witness], delegate],
    [fixed.prepareCuratedExcessRefundDelegatedClaim(adapter, delegate, saleId, buyer, witness), "claimRefundFor", [saleId, buyer, witness], delegate],
  ];
  for (const [prepared, method, args, caller] of cases) {
    assert.equal(prepared.caller, caller); assert.equal(prepared.call.value, 0n);
    assert.equal(prepared.call.data, abi.encodeFunctionData(method, args));
  }
  assert.notEqual(cases[0][0].call.data.slice(0, 10), cases[1][0].call.data.slice(0, 10));
});

test("maturity refund and typed early unlock retain exact separate evidence presentations", () => {
  const commit = fixed.prepareCuratedSelectionCommit(chain, adapter, buyer, saleId, commitConfig, selection.content, ZeroHash, selection.purchaseNonce);
  const maturity = fixed.prepareCuratedMaturityUnlock(adapter, recipient, saleId, buyer, commit.commitment);
  assert.equal(maturity.call.data, abi.encodeFunctionData("unlockSelectionRefund", [saleId, buyer, commit.commitment]));
  for (const reason of [1n, 2n, 3n, 4n, 5n]) {
    const early = fixed.prepareCuratedReasonUnlock(chain, adapter, recipient, saleId, buyer, commitConfig, selection, ZeroHash, reason);
    assert.equal(early.call.data, abi.encodeFunctionData("unlockSelectionRefundForReason", [saleId, buyer, commit.commitment, selection, ZeroHash, reason]));
  }
  for (const reason of [0n, 6n]) assert.throws(() => fixed.prepareCuratedReasonUnlock(chain, adapter, recipient, saleId, buyer, commitConfig, selection, ZeroHash, reason));
});

test("curated Safe review plans preserve role, CALL value and failed-retry payloads without advancing state", async () => {
  const registration = fixed.prepareCuratedFixedRegistration(chain, adapter, owner, 7n, commitConfig);
  const commit = fixed.prepareCuratedSelectionCommit(chain, adapter, buyer, saleId, commitConfig, selection.content, ZeroHash, selection.purchaseNonce);
  const reveal = fixed.prepareCuratedSelectionReveal(chain, adapter, buyer, saleId, commitConfig, selection, ZeroHash, 11n);
  const prepared = [registration, commit, reveal];
  const catalog = prepared.map(() => fixture.abis.fixed);
  const plan = createSafeCallPlan(chain, "Review separate curated transactions", prepared.map((packet, index) => ({
    safe: packet.caller, intent: ["Register immutable manifest terms", "Commit full fixed price", "Reveal selection and pay live fee"][index],
    call: packet.call, abi: fixture.abis.fixed,
  })));
  assert.deepEqual(verifySafeCallPlan(plan, catalog), plan);
  assert.deepEqual(plan.steps.map(step => step.safe), [owner, buyer, buyer]);
  assert.deepEqual(plan.steps.map(step => step.transaction.value), ["0", common.price.toString(), "11"]);
  assert(plan.steps.every(step => step.transaction.operation === 0));
  const calls = []; let fail = true;
  const provider = { getNetwork: async () => ({ chainId: chain }), call: async tx => { calls.push(tx); if (fail) throw Error("reveal not admitted"); return "0x"; } };
  await assert.rejects(simulateSafePlanStep(provider, plan, catalog, 2), /not admitted/);
  fail = false; await simulateSafePlanStep(provider, plan, catalog, 2);
  assert.deepEqual(calls[0], calls[1]); assert.equal(calls[0].from, buyer); assert.equal(calls[0].value, 11n);
});

const authType = "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)";
const privateSelection = { ...selection, recipient: buyer };
const privateConfig = { sale: common, buyer, contentId: ZeroHash, tokenDataHash: keccak256("0x"), signer: A(6),
  signerKind: 2n, signerEvidenceHash: id("membership evidence"), signerRevision: (1n << 63n) + 1n, signerAuthority: owner };
function batchOracle() {
  return Object.fromEntries([
    ["initialRecipientsHash", "6529STREAM_MINT_BATCH_RECIPIENTS_V1", "address[]", [adapter]],
    ["beneficiariesHash", "6529STREAM_MINT_BATCH_BENEFICIARIES_V1", "address[]", [buyer]],
    ["tokenDataArrayHash", "6529STREAM_MINT_BATCH_TOKEN_DATA_V1", "bytes[]", [privateSelection.tokenData]],
    ["mintCommitmentsHash", "6529STREAM_MINT_BATCH_COMMITMENTS_V1", "bytes32[]", [privateSelection.mintCommitment]],
  ].map(([key, domain, type, value]) => [key, keccak256(coder.encode(["bytes32", type], [id(domain), value]))]));
}
function authorization() {
  return { chainId: chain, saleAdapter: adapter, mintManager: manager, collectionId: common.collectionId,
    phaseId: phase, saleId, saleKind: 5n, revenueClass: id("PRIMARY_SALE"), expectedPrimaryPolicyHash: common.expectedPrimaryPolicyHash,
    primaryPolicyMode: 0n, ...batchOracle(), payer: buyer, executor: A(7), asset: ZeroAddress, unitPrice: common.price,
    quantity: 1n, contentSelectionHash: manifest.publication.manifestRoot, policyHash: common.mintPolicyHash,
    nonce: id("authorization nonce"), deadline: (1n << 63n) + 100n, finalizeBy: 0n };
}
function originalSalesDigest(type, message, domainAdapter = adapter) {
  const fields = type.slice(type.indexOf("(") + 1, -1).split(",").map(field => field.split(" "));
  const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529Stream Sales"), id("1"), chain, domainAdapter]));
  const body = keccak256(coder.encode(["bytes32", ...fields.map(field => field[0])], [id(type), ...fields.map(field => message[field[1]])]));
  return keccak256(concat(["0x1901", domain, body]));
}

test("private original 24-field Sales signature and TICKET bind complete literal batch hashes", () => {
  const auth = authorization();
  assert.deepEqual(priv.curatedPrivateBatchHashes(adapter, buyer, privateSelection), batchOracle());
  const digest = originalSalesDigest(authType, auth), payload = priv.curatedPrivateSaleAuthorizationPayload(chain, adapter, auth);
  assert.equal(payload.digest, digest); assert.equal(payload.domain.name, "6529Stream Sales");
  assert.equal(payload.types.SaleAuthorization.length, 24);
  const ticket = keccak256(coder.encode(["bytes32", "bytes32"], [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest]));
  assert.equal(priv.curatedPrivateMintTicketAuthorizationId(chain, adapter, auth), ticket);
  assert.notEqual(ticket, digest); assert.notEqual(ticket, curatedPurchaseId(chain, adapter, saleId, buyer, selection.purchaseNonce));
  for (const field of ["initialRecipientsHash", "beneficiariesHash", "tokenDataArrayHash", "mintCommitmentsHash"]) {
    const changed = { ...auth, [field]: id(`changed ${field}`) };
    assert.equal(priv.curatedPrivateSaleAuthorizationPayload(chain, adapter, changed).digest, originalSalesDigest(authType, changed));
    assert.notEqual(priv.curatedPrivateMintTicketAuthorizationId(chain, adapter, changed), ticket);
  }
});

test("private configuration and historical revocation preserve separate original domains", () => {
  const tuple = "tuple(tuple(uint256 collectionId,bytes32 phaseId,uint256 price,address poster,uint64 startsAt,uint64 endsAt,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 contentManifestRoot) sale,address buyer,bytes32 contentId,bytes32 tokenDataHash,address signer,uint8 signerKind,bytes32 signerEvidenceHash,uint64 signerRevision,address signerAuthority)";
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", tuple], [id("6529STREAM_NATIVE_CURATED_PRIVATE_CONFIG_V1"), chain, adapter, privateConfig]));
  assert.equal(priv.curatedPrivateConfigurationHash(chain, adapter, privateConfig), expected);
  assert.throws(() => priv.curatedPrivateConfigurationHash(chain, adapter, { ...privateConfig, sale: { ...common, primaryPolicyMode: 1n } }), /strict/);
  const ledger = A(8), authorizationId = priv.curatedPrivateMintTicketAuthorizationId(chain, adapter, authorization());
  const message = { chainId: chain, manager, ledger, authorizationId };
  const type = "MintTicketRevocation(uint256 chainId,address manager,address ledger,bytes32 authorizationId)";
  const payload = priv.curatedPrivateMintTicketRevocationPayload(chain, adapter, manager, ledger, authorizationId);
  assert.equal(payload.digest, originalSalesDigest(type, message));
  assert.notEqual(payload.digest, originalSalesDigest(type, message, manager));
  assert.notEqual(payload.digest, priv.curatedPrivateSaleAuthorizationPayload(chain, adapter, authorization()).digest);
});

test("historical Manager and Ledger methods retain separate committed compiler provenance", async () => {
  const capture = JSON.parse(await readFile(new URL("./fixtures/current-curated-revocation-abi.json", import.meta.url), "utf8"));
  assert.equal(capture.sourceCommit, "33ddd13251716f5409d66c1bd22544ed1cb9cb3a");
  assert.equal(capture.sourceCount, 1989); assert.equal(Object.keys(capture.sources).length, 11);
  assert.equal(capture.inputSha256, "fc38c3ca352512ac8e86c515c031e9c9e280cca2e941996fedfaf03d7024c822");
  assert.equal(capture.outputSha256, "de02dfa841cd9b7333159f810f1bddf26e0d60e5e4fa7d1b0661b2346bd76f2a");
  const managerABI = new Interface(capture.abis.manager), ledgerABI = new Interface(capture.abis.ledger);
  const fn = managerABI.getFunction("voidMintSaleAuthorization");
  assert.equal(fn.inputs[0].components.map(c => `${c.type} ${c.name}`).join(","), authType.slice(authType.indexOf("(") + 1, -1));
  assert.equal(fn.inputs[1].type, "bytes"); assert.equal(fn.stateMutability, "nonpayable");
  assert.equal(ledgerABI.getFunction("isManagerAuthorizationUsed").inputs.map(p => p.type).join(","), "address,bytes32");
});
