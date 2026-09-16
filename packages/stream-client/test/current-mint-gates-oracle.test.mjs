import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, concat, id, keccak256 } from "ethers";
import * as gates from "../dist/current-mint-gates.js";

// Independent literal encodings from bba738e9. These do not prove live eligibility,
// signature acceptance, Manager admission, or counter/replay consumption.
const coder = AbiCoder.defaultAbiCoder();
const addr = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chain = 31337n, gate = addr(1), manager = addr(2), ledger = addr(3);
const payer = addr(4), executor = addr(5), vault = addr(6), signer = addr(7);
const batch = { collectionId: 9007199254740993n, phaseId: id("phase"), payer,
  authorizer: signer, initialRecipients: [addr(8), addr(9)], beneficiaries: [addr(9), addr(8)],
  tokenData: ["0xabcd", "0x"], mintCommitments: [id("mint A"), ZeroHash],
  expectedPolicyHash: id("policy"), authorizationId: ZeroHash, contextHash: id("context"), resolverData: "0x" };
const hashArray = (domain, type, values) => keccak256(coder.encode(["bytes32", `${type}[]`], [id(domain), values]));
function batchHashes(b) {
  return { initialRecipientsHash: hashArray("6529STREAM_MINT_BATCH_RECIPIENTS_V1", "address", b.initialRecipients),
    beneficiariesHash: hashArray("6529STREAM_MINT_BATCH_BENEFICIARIES_V1", "address", b.beneficiaries),
    tokenDataArrayHash: hashArray("6529STREAM_MINT_BATCH_TOKEN_DATA_V1", "bytes", b.tokenData),
    mintCommitmentsHash: hashArray("6529STREAM_MINT_BATCH_COMMITMENTS_V1", "bytes32", b.mintCommitments) };
}
const ticketType = "tuple(uint256 chainId,address manager,address ledger,uint256 collectionId,bytes32 phaseId,address executor,address payer,address authorizer,uint8 authorizerKind,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,uint256 quantity,bytes32 contextHash,bytes32 policyHash,bytes32 nonce,uint64 deadline)";
const ticketTypeHash = id("MintTicket(uint256 chainId,address manager,address ledger,uint256 collectionId,bytes32 phaseId,address executor,address payer,address authorizer,uint8 authorizerKind,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,uint256 quantity,bytes32 contextHash,bytes32 policyHash,bytes32 nonce,uint64 deadline)");
const ticket = { chainId: chain, manager, ledger, collectionId: batch.collectionId, phaseId: batch.phaseId,
  executor, payer, authorizer: signer, authorizerKind: 2n, ...batchHashes(batch), quantity: 2n,
  contextHash: batch.contextHash, policyHash: batch.expectedPolicyHash, nonce: id("ticket nonce"), deadline: (1n << 64n) - 1n };
function ticketDigest(t, verifyingContract = gate) {
  const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529Stream Mint Tickets"), id("1"), chain, verifyingContract]));
  const body = keccak256(coder.encode(["bytes32", ticketType], [ticketTypeHash, t]));
  return keccak256(concat(["0x1901", domain, body]));
}

test("mint batch arrays retain distinct domains and dynamic element boundaries", () => {
  assert.deepEqual(gates.mintBatchHashes(batch), batchHashes(batch));
  const equalAccounts = { ...batch, beneficiaries: [...batch.initialRecipients] };
  const hashes = gates.mintBatchHashes(equalAccounts);
  assert.notEqual(hashes.initialRecipientsHash, hashes.beneficiariesHash);
  assert.notEqual(gates.mintBatchHashes({ ...batch, tokenData: ["0xab", "0xcd"] }).tokenDataArrayHash, hashes.tokenDataArrayHash);
});

test("ticket EIP712, authorization ID, config and gate data match literal source layouts", () => {
  const payload = gates.mintTicketTypedData(chain, gate, ticket), digest = ticketDigest(ticket);
  assert.equal(payload.digest, digest);
  assert.equal(gates.mintTicketAuthorizationId(digest), keccak256(coder.encode(["bytes32", "bytes32"], [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest])));
  assert.equal(gates.mintTicketGateConfigHash(signer, 2n), keccak256(coder.encode(["bytes32", "address", "uint8"], [id("6529STREAM_MINT_TICKET_GATE_CONFIG_V1"), signer, 2n])));
  const signature = `0x${"11".repeat(130)}`;
  assert.equal(gates.mintTicketGateData(ticket, signature), coder.encode([ticketType, "bytes"], [ticket, signature]));
  assert.equal(gates.mintTicketSafeMessageBytes(digest), coder.encode(["bytes32"], [digest]));
  for (const changed of [{ ...ticket, ledger: addr(11) }, { ...ticket, tokenDataArrayHash: id("changed") }, { ...ticket, quantity: 1n }]) {
    assert.notEqual(gates.mintTicketTypedData(chain, gate, changed).digest, digest);
  }
  assert.notEqual(gates.mintTicketTypedData(chain, addr(11), ticket).digest, digest);
  assert.throws(() => gates.mintTicketTypedData(chain, gate, { ...ticket, deadline: 1n << 64n }));
});

test("delegated request uses the retained narrow tuple and stable vault nonce", () => {
  const core = addr(10), registry = addr(11), code = id("registry code"), usecase = id("rights"), nonce = id("vault nonce");
  const config = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "bytes32"],
    [id("6529STREAM_DELEGATE_XYZ_V2_GATE_V1"), chain, core, registry, code, usecase]));
  assert.equal(gates.delegateGateConfigHash(chain, core, registry, code, usecase), config);
  assert.equal(gates.delegateCollectionRights(chain, core, usecase, batch.collectionId), keccak256(coder.encode(
    ["bytes32", "uint256", "address", "bytes32", "uint256"], [id("6529STREAM_DELEGATE_COLLECTION_RIGHTS_V1"), chain, core, usecase, batch.collectionId])));
  const b = { ...batch, authorizer: ZeroAddress, initialRecipients: [vault, vault], beneficiaries: [vault, vault] };
  const request = { manager, executor, collectionId: b.collectionId, phaseId: b.phaseId, payer,
    authorizer: ZeroAddress, initialRecipients: b.initialRecipients, beneficiaries: b.beneficiaries,
    contextHash: b.contextHash, expectedPolicyHash: b.expectedPolicyHash, gateData: coder.encode(["address", "bytes32"], [vault, nonce]) };
  assert.deepEqual(gates.delegateMintRequest(manager, executor, b, vault, nonce), request);
  assert.equal(gates.delegateGateData(vault, nonce), request.gateData);
  const type = "tuple(address manager,address executor,uint256 collectionId,bytes32 phaseId,address payer,address authorizer,address[] initialRecipients,address[] beneficiaries,bytes32 contextHash,bytes32 expectedPolicyHash,bytes gateData)";
  const auth = r => keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", type], [id("6529STREAM_DELEGATE_MINT_AUTHORIZATION_V1"), chain, gate, config, r]));
  assert.equal(gates.delegateMintAuthorizationId(chain, gate, config, request), auth(request));
  assert.notEqual(gates.delegateMintAuthorizationId(chain, gate, config, { ...request, executor: addr(12) }), auth(request));
  assert.equal(gates.delegateMintNullifier(chain, gate, manager, b.collectionId, b.phaseId, payer, vault, nonce), keccak256(coder.encode(
    ["bytes32", "uint256", "address", "address", "uint256", "bytes32", "address", "address", "bytes32"],
    [id("6529STREAM_DELEGATE_MINT_NONCE_V1"), chain, gate, manager, b.collectionId, b.phaseId, payer, vault, nonce])));
  assert.deepEqual(gates.delegateMintRequest(manager, executor, { ...b, tokenData: ["0x11", "0x22"], mintCommitments: [id("other"), id("other2")] }, vault, nonce), request);
});

test("allowlist leaves double hash exact uint64 caps, and current price overrides fail", () => {
  const input = { chainId: chain, manager, collectionId: batch.collectionId, phaseId: batch.phaseId,
    counterId: id("counter"), account: vault, maxCount: (1n << 64n) - 1n, hasPriceOverride: false, priceOverride: 0n };
  const expected = keccak256(keccak256(coder.encode(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256"],
    [id("6529STREAM_MINT_ALLOWLIST_LEAF_V1"), chain, manager, input.collectionId, input.phaseId, input.counterId, vault, input.maxCount, false, 0n])));
  assert.equal(gates.mintAllowlistLeaf(input), expected);
  const sibling = id("sibling"), root = keccak256(coder.encode(["bytes32", "bytes32"], BigInt(expected) < BigInt(sibling) ? [expected, sibling] : [sibling, expected]));
  assert.equal(gates.verifyMintAllowlistProof(root, expected, [sibling]), true);
  assert.equal(gates.verifyMintAllowlistProof(root, id("wrong"), [sibling]), false);
  assert.throws(() => gates.mintAllowlistLeaf({ ...input, hasPriceOverride: true }));
  assert.throws(() => gates.mintAllowlistLeaf({ ...input, priceOverride: 1n }));
  assert.throws(() => gates.mintAllowlistLeaf({ ...input, maxCount: 1n << 64n }));
});

test("allowlist resolver encoding and policy-value commitment preserve group order and omit siblings", () => {
  const groups = [[{ maxCount: 9n, hasPriceOverride: false, priceOverride: 0n, proof: [id("proof A")] }],
    [{ maxCount: 13n, hasPriceOverride: false, priceOverride: 0n, proof: [] }]], ids = [id("counter A"), id("counter B")];
  const values = groups.map((group, i) => keccak256(coder.encode(["bytes32", "bytes32[]"], [ids[i], group.map(p => keccak256(coder.encode(["uint64", "bool", "uint256"], [p.maxCount, p.hasPriceOverride, p.priceOverride])))])));
  const expected = keccak256(coder.encode(["bytes32", "bytes32[]"], [id("6529STREAM_MINT_ALLOWLIST_GATE_PROOF_VALUES_V1"), values]));
  assert.equal(gates.mintAllowlistProofValuesHash(ids, groups), expected);
  assert.equal(gates.mintAllowlistResolverData(groups), coder.encode(["tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)[][]"], [groups]));
  const changedWitness = [[{ ...groups[0][0], proof: [id("another sibling")] }], groups[1]];
  assert.equal(gates.mintAllowlistProofValuesHash(ids, changedWitness), expected);
  assert.notEqual(gates.mintAllowlistResolverData(changedWitness), gates.mintAllowlistResolverData(groups));
  assert.notEqual(gates.mintAllowlistProofValuesHash([...ids].reverse(), groups), expected);
});

test("allowlist authorization and nullifier independently bind their distinct static fields", () => {
  const root = id("root"), counter = id("counter"), nonce = id("allowlist nonce");
  const config = keccak256(coder.encode(["bytes32", "bytes32", "bytes32"], [id("6529STREAM_MINT_ALLOWLIST_GATE_CONFIG_V1"), root, counter]));
  assert.equal(gates.mintAllowlistGateConfigHash(root, counter), config);
  const arrays = batchHashes(batch), binding = { manager, ledger, executor, collectionId: batch.collectionId,
    phaseId: batch.phaseId, payer, expectedPolicyHash: batch.expectedPolicyHash, contextHash: batch.contextHash,
    initialRecipientsHash: arrays.initialRecipientsHash, beneficiariesHash: arrays.beneficiariesHash,
    tokenDataHash: arrays.tokenDataArrayHash, mintCommitmentsHash: arrays.mintCommitmentsHash,
    proofValuesHash: id("proof values"), nonce };
  const type = "tuple(address manager,address ledger,address executor,uint256 collectionId,bytes32 phaseId,address payer,bytes32 expectedPolicyHash,bytes32 contextHash,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataHash,bytes32 mintCommitmentsHash,bytes32 proofValuesHash,bytes32 nonce)";
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", type], [id("6529STREAM_MINT_ALLOWLIST_GATE_AUTHORIZATION_V1"), chain, gate, config, binding]));
  assert.equal(gates.mintAllowlistAuthorizationId(chain, gate, config, binding), expected);
  assert.notEqual(gates.mintAllowlistAuthorizationId(chain, gate, config, { ...binding, proofValuesHash: id("different") }), expected);
  assert.equal(gates.mintAllowlistGateData(nonce), coder.encode(["bytes32"], [nonce]));
  assert.equal(gates.mintAllowlistNullifier(chain, gate, manager, ledger, batch.collectionId, batch.phaseId, payer, nonce), keccak256(coder.encode(
    ["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "address", "bytes32"],
    [id("6529STREAM_MINT_ALLOWLIST_GATE_NONCE_V1"), chain, gate, manager, ledger, batch.collectionId, batch.phaseId, payer, nonce])));
});
