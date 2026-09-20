import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import {
  encodeERC20BurnMintExecution, erc20BurnMintAuthorizationId, erc20BurnMintAuthorizationPayload,
  erc20BurnMintCandidateCommitment, erc20BurnMintConfigurationHash, erc20BurnMintExecutionId,
  erc20BurnMintPaymentIntentPayload, erc20BurnMintProgramConfigHash, erc20BurnMintSaleId,
  erc20BurnMintSettlementKey, erc20BurnMintSigningSnapshot, normalizeERC20BurnMintCandidate,
  normalizeERC20BurnMintExecution, normalizeERC20BurnMintProgramConfig,
  normalizeERC20BurnMintSaleAuthorization, normalizeERC20BurnMintSaleConfig,
  validateERC20BurnMintProgram,
} from "../dist/current-erc20-burn-mint-signing.js";
import { normalizeERC20SettlementCandidate } from "../dist/current-erc20-primary-offer.js";
import { burnMintNullifier, burnMintProgramConfigHash } from "../dist/current-burn-mint.js";

const f = JSON.parse(readFileSync(new URL("./fixtures/current-erc20-burn-mint-abi.json", import.meta.url)));
const coder = AbiCoder.defaultAbiCoder(), saleAbi = new Interface(f.abis.sale);
const parameter = (abi, name, side = "inputs", index = 0) => ParamType.from(abi.find(x => x.name === name && x.type === "function")[side][index]);
const configType = parameter(f.abis.sale, "registerSale"), authType = parameter(f.abis.sale, "authorizationDigest");
const executionType = parameter(f.abis.sale, "previewExecution"), candidateType = parameter(f.abis.sale, "previewExecution", "outputs");
const programType = parameter(f.abis.gate, "programConfigHash");
const fields = authType.components.map(c => ({ name: c.name, type: c.type }));
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chain = (1n << 200n) + 31337n, adapter = A(1), payment = A(2), recorder = A(3), core = A(4);
const payer = A(5), executor = A(6), recipient = A(7), artist = A(8), manager = A(9), asset = A(10);
const registry = A(11), gate = A(12), wallet = A(13), phase = id("burn phase");
const collection = (1n << 170n) + 9n, saleNonce = 7n, price = (1n << 190n) + 1000n;
const raw = "0x123400aabb", tokenHash = keccak256(raw), commitment = id("burn mint commitment");
const sources = [(1n << 180n) + 1n, (1n << 180n) + 9n];
const domain = { name: "6529StreamUniversalFixedPriceSaleAdapter", version: "1", chainId: chain, verifyingContract: adapter };
const saleId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
  [id("6529STREAM_SALE_V1"), chain, adapter, 8n, collection, phase, saleNonce]));
function config() {
  return { paymentAdapter: payment, collectionId: collection, phaseId: phase, asset, price,
    startsAt: 100n, endsAt: 1000n, mintPolicyHash: id("mint policy"), expectedPrimaryPolicyHash: id("primary policy") };
}
function configHash(c = config()) {
  return keccak256(coder.encode(["bytes32", "bytes32", configType], [id("6529STREAM_UNIVERSAL_FIXED_PRICE_CONFIG_V1"), saleId, c]));
}
function auth() {
  return { saleId, saleConfigHash: configHash(), payer, executor, recipient, artist, tokenDataHash: tokenHash,
    mintCommitment: commitment, executionNonce: (1n << 150n) + 3n, nonce: ZeroHash, deadline: 999n };
}
function execution() {
  return { sale: { authorization: auth(), tokenData: raw, platformSignature: "0xaabb", artistSignature: "0x1234" }, sourceTokenIds: [...sources] };
}
function program() {
  return { manager, targetCollectionId: collection, phaseId: phase, sourceCollectionIds: [1n, collection],
    sourcesPerMint: 2n, startsAt: 0n, endsAt: 0n, prepared: false, nativeSaleAdapter: ZeroAddress };
}
function literalExecutionId(c) {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ERC20_SALE_EXECUTION_V1"), chain, c.saleAdapter, c.sale.settlementId, c.sale.payer, c.executor,
      c.executionBinding.executionNonce, c.executionBinding.authorityMode, c.executionBinding.saleAuthorizationDigest,
      c.currentPolicyHash, c.boundPolicyHash, c.operationIdentityCommitment]));
}
function candidate() {
  const c = { saleAdapter: adapter, executor,
    sale: { settlementId: saleId, revenueClass: id("PRIMARY_SALE"), policyMode: 0n, collectionId: collection, tokenId: 0n,
      saleNonce, payer, poster: ZeroAddress, beneficiary: recipient, amount: price, expectedPrimaryPolicyHash: config().expectedPrimaryPolicyHash },
    lifecycleBinding: { paymentAdapter: payment, saleCreatedAt: 90n, saleAdapterRegistryRevision: (1n << 63n) + 1n, paymentAdapterRegistryRevision: 3n },
    executionBinding: { executionId: ZeroHash, executionNonce: auth().executionNonce, authorityMode: 1n,
      saleAuthorizationDigest: TypedDataEncoder.hash(domain, { UniversalSaleAuthorization: fields }, auth()) },
    asset, orchestrationOrder: 1n, mintManager: manager, operationIdentityCommitment: id("burn-proof-bound operation root"),
    operationId: id("operation ID"), currentPolicyHash: id("live mint policy"), boundPolicyHash: config().mintPolicyHash,
    rights: { profileId: id("profile"), wallet, templateId: ZeroHash, assignmentHash: id("assignment"), entriesHash: id("entries") },
    saleExecutionHash: keccak256(coder.encode([executionType], [execution()])) };
  c.executionBinding.executionId = literalExecutionId(c);
  return c;
}
function intent() {
  return { payer, asset, maxAmount: price, saleRef: saleId, expectedPrimaryPolicyHash: config().expectedPrimaryPolicyHash,
    nonce: ZeroHash, deadline: 999n };
}

test("burn keeps original eleven-field Universal authorization, platform/Artist digest and TICKET", () => {
  assert.equal(f.sourceCount, 2108); assert.equal(authType.components.length, 11);
  const a = auth(), expected = TypedDataEncoder.hash(domain, { UniversalSaleAuthorization: fields }, a);
  const payload = erc20BurnMintAuthorizationPayload(chain, adapter, a);
  assert.equal(payload.digest, expected); assert.equal(payload.message.nonce, ZeroHash);
  assert.equal(payload.message.executionNonce, a.executionNonce);
  assert.equal(erc20BurnMintAuthorizationId(chain, adapter, a), keccak256(coder.encode(["bytes32", "bytes32"],
    [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), expected])));
  assert.notEqual(payload.digest, erc20BurnMintAuthorizationPayload(chain, payment, a).digest);
  assert.notEqual(payload.digest, erc20BurnMintAuthorizationPayload(chain + 1n, adapter, a).digest);
  assert.throws(() => normalizeERC20BurnMintSaleAuthorization({ ...a, sourceTokenIds: sources }), /unknown/);
  assert.throws(() => normalizeERC20BurnMintSaleAuthorization({ ...a, executionNonce: 0n }), /positive/);
});

test("kind-eight sale ID and original config hash use exact compiled nine-field config", () => {
  assert.equal(configType.components.length, 9);
  assert.equal(erc20BurnMintSaleId(chain, adapter, collection, phase, saleNonce), saleId);
  assert.equal(erc20BurnMintConfigurationHash(saleId, config()), configHash());
  assert.notEqual(erc20BurnMintConfigurationHash(id("other sale"), config()), configHash());
  for (const changed of [{ asset: ZeroAddress }, { paymentAdapter: ZeroAddress }, { price: 0n }, { endsAt: 100n }, { collectionId: 1 }]) {
    assert.throws(() => normalizeERC20BurnMintSaleConfig({ ...config(), ...changed }));
  }
});

test("whole execution commits ordered source IDs while original authorization remains unchanged", () => {
  const e = execution(), canonical = coder.encode([executionType], [e]);
  assert.equal(encodeERC20BurnMintExecution(e), canonical);
  assert.equal(saleAbi.encodeFunctionData("previewExecution", [e]).slice(10), canonical.slice(2));
  assert.equal(saleAbi.getFunction("previewExecution").stateMutability, "nonpayable");
  const s = erc20BurnMintSigningSnapshot(chain, adapter, config(), saleId, e);
  assert.equal(s.saleExecutionData, canonical); assert.equal(s.saleExecutionHash, keccak256(canonical));
  assert.equal(s.contextHash, s.authorizationPayload.digest);
  const altered = erc20BurnMintSigningSnapshot(chain, adapter, config(), saleId, { ...e, sourceTokenIds: [sources[0], sources[1] + 1n] });
  assert.equal(altered.authorizationId, s.authorizationId);
  assert.notEqual(altered.saleExecutionHash, s.saleExecutionHash);
  assert.notEqual(s.saleExecutionHash, keccak256(coder.encode([executionType.components[0]], [e.sale])));
});

test("signing packet keeps independent payer, executor and recipient but rejects changed terms and raw data", () => {
  const e = execution(), s = erc20BurnMintSigningSnapshot(chain, adapter, config(), saleId, e);
  assert.equal(new Set([s.execution.sale.authorization.payer, s.execution.sale.authorization.executor, s.execution.sale.authorization.recipient]).size, 3);
  for (const changed of [{ saleId: id("other") }, { saleConfigHash: id("wrong") }, { deadline: 1001n }, { deadline: 99n }]) {
    assert.throws(() => erc20BurnMintSigningSnapshot(chain, adapter, config(), saleId, { ...e, sale: { ...e.sale, authorization: { ...auth(), ...changed } } }), /differs/);
  }
  assert.throws(() => normalizeERC20BurnMintExecution({ ...e, sale: { ...e.sale, tokenData: "0x00" } }), /Raw token data/);
});

test("burn source order, exact integer type, size and nested byte bounds fail closed", () => {
  const e = execution();
  for (const ids of [[], [2n, 1n], [1n, 1n], [0n], [1], [1n << 256n], Array.from({ length: 17 }, (_, i) => BigInt(i + 1))]) {
    assert.throws(() => normalizeERC20BurnMintExecution({ ...e, sourceTokenIds: ids }));
  }
  const data = `0x${"aa".repeat(8192)}`;
  assert.equal(normalizeERC20BurnMintExecution({ ...e, sale: { ...e.sale, tokenData: data,
    authorization: { ...auth(), tokenDataHash: keccak256(data) } } }).sale.tokenData, data);
  assert.throws(() => normalizeERC20BurnMintExecution({ ...e, sale: { ...e.sale, tokenData: `${data}aa` } }), /8192/);
  assert.throws(() => normalizeERC20BurnMintExecution({ ...e, sale: { ...e.sale, platformSignature: `0x${"aa".repeat(65537)}` } }), /65536/);
  assert.throws(() => normalizeERC20BurnMintExecution({ ...e, sale: { ...e.sale, artistSignature: "0xa" } }), /complete/);
  assert.throws(() => normalizeERC20BurnMintExecution({ ...e, revealFeeAllowance: 1n }), /unknown/);
});

test("program retains original hash and inclusive window with mandatory ERC20 compatibility", () => {
  const p = program();
  assert.equal(programType.components.length, 9);
  const literal = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", programType],
    [id("6529STREAM_BURN_MINT_CONFIG_V1"), chain, gate, core, registry, p]));
  assert.equal(erc20BurnMintProgramConfigHash(chain, gate, core, registry, p), literal);
  assert.equal(burnMintProgramConfigHash(chain, gate, core, registry, p), literal);
  assert.equal(validateERC20BurnMintProgram(config(), p, sources).endsAt, 0n);
  assert.equal(validateERC20BurnMintProgram(config(), { ...p, startsAt: 100n, endsAt: 1000n }, sources).endsAt, 1000n);
  for (const changed of [{ prepared: true }, { nativeSaleAdapter: adapter }, { sourceCollectionIds: [2n, 1n] },
    { sourcesPerMint: 17n }, { sourceCollectionIds: Array.from({ length: 65 }, (_, i) => BigInt(i + 1)) }]) {
    assert.throws(() => normalizeERC20BurnMintProgramConfig({ ...p, ...changed }));
  }
  for (const changed of [{ targetCollectionId: 1n }, { phaseId: id("other phase") }, { sourcesPerMint: 1n }, { startsAt: 101n }, { endsAt: 999n }]) {
    assert.throws(() => validateERC20BurnMintProgram(config(), { ...p, ...changed }, sources));
  }
  assert.equal(burnMintNullifier(chain, core, sources[0]), keccak256(coder.encode(["bytes32", "uint256", "address", "uint256"],
    [id("6529STREAM_BURN_NULLIFIER_V1"), chain, core, sources[0]])));
});

test("burn candidate retains original settlement domains with zero poster and independent recipient", () => {
  const c = candidate();
  const normalized = normalizeERC20BurnMintCandidate(c);
  assert.equal(normalized.sale.poster, ZeroAddress); assert.notEqual(normalized.sale.payer, normalized.sale.beneficiary);
  assert.throws(() => normalizeERC20SettlementCandidate(c)); // Existing primary-offer profile remains unchanged.
  assert.equal((coder.encode([candidateType], [c]).length - 2) / 2, 1088);
  assert.equal(erc20BurnMintExecutionId(chain, c), literalExecutionId(c));
  const commitment = keccak256(coder.encode(["bytes32", "uint256", "address", "address", candidateType],
    [id("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2"), chain, payment, recorder, c]));
  assert.equal(erc20BurnMintCandidateCommitment(chain, payment, recorder, c), commitment);
  const key = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32"],
    [id("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2"), chain, recorder, adapter, c.executionBinding.executionId]));
  assert.equal(erc20BurnMintSettlementKey(chain, recorder, adapter, c.executionBinding.executionId), key);
  assert.notEqual(erc20BurnMintCandidateCommitment(chain, payment, recorder, { ...c, saleExecutionHash: id("different full execution") }), commitment);
  assert.throws(() => erc20BurnMintCandidateCommitment(chain, A(20), recorder, c), /payment adapter/);
  assert.throws(() => erc20BurnMintCandidateCommitment(chain + 1n, payment, recorder, c), /identity/);
  assert.throws(() => normalizeERC20BurnMintCandidate({ ...c, sale: { ...c.sale, poster: payer } }), /PROFILE/);
  assert.throws(() => normalizeERC20BurnMintCandidate({ ...c, orchestrationOrder: 2n }), /PROFILE/);
});

test("independent payment intent binds contract20 and payer without granting burn-source authority", () => {
  const p = erc20BurnMintPaymentIntentPayload(chain, config(), auth(), intent());
  const intentType = parameter(f.abis.payment, "paymentIntentDigest");
  const intentFields = intentType.components.map(c => ({ name: c.name, type: c.type }));
  const expected = TypedDataEncoder.hash({ name: "6529StreamPaymentIntentVerifier", version: "1", chainId: chain, verifyingContract: payment },
    { StreamPaymentIntent: intentFields }, intent());
  assert.equal(p.digest, expected); assert.equal(p.message.payer, payer);
  assert.notEqual(p.digest, erc20BurnMintAuthorizationPayload(chain, adapter, auth()).digest);
  assert.equal(p.message.nonce, ZeroHash);
  for (const changed of [{ payer: executor }, { payer: recipient }, { asset: A(20) }, { maxAmount: price - 1n }, { saleRef: id("other") }, { expectedPrimaryPolicyHash: id("other") }]) {
    assert.throws(() => erc20BurnMintPaymentIntentPayload(chain, config(), auth(), { ...intent(), ...changed }), /differs/);
  }
});

test("all nested signing, execution, source, program and candidate inputs are copied and frozen", () => {
  const c = config(), e = execution(), p = program(), candidateInput = candidate();
  const saved = erc20BurnMintSigningSnapshot(chain, adapter, c, saleId, e), savedProgram = normalizeERC20BurnMintProgramConfig(p);
  const savedCandidate = normalizeERC20BurnMintCandidate(candidateInput);
  c.price = 1n; e.sourceTokenIds[0] = 2n; e.sale.authorization.recipient = payer; e.sale.platformSignature = "0x";
  p.sourceCollectionIds[0] = 8n; candidateInput.sale.beneficiary = payer; candidateInput.rights.wallet = payer;
  assert.equal(saved.configuration.price, price); assert.equal(saved.execution.sourceTokenIds[0], sources[0]);
  assert.equal(saved.execution.sale.authorization.recipient, recipient); assert.equal(saved.execution.sale.platformSignature, "0xaabb");
  assert.equal(savedProgram.sourceCollectionIds[0], 1n); assert.equal(savedCandidate.sale.beneficiary, recipient);
  assert.notEqual(savedCandidate.rights.wallet, payer);
  for (const v of [saved.execution, saved.execution.sale, saved.execution.sourceTokenIds, saved.authorizationPayload.types.UniversalSaleAuthorization,
    savedProgram.sourceCollectionIds, savedCandidate.sale, savedCandidate.rights]) assert(Object.isFrozen(v));
});
