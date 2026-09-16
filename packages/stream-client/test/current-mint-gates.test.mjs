import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id } from "ethers";
import * as gates from "../dist/current-mint-gates.js";
import { currentMintGatesFixture } from "../scripts/generate-current-mint-gates-fixture.mjs";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-mint-gates-abi.json", import.meta.url), "utf8"));
const coder = AbiCoder.defaultAbiCoder();
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chainId = 31337n, manager = A(1), ledger = A(2), executor = A(3), payer = A(4), signer = A(5), gate = A(6), vault = A(7);
const batch = Object.freeze({ collectionId: 9007199254740993n, phaseId: id("phase"), payer, authorizer: signer,
  initialRecipients: Object.freeze([A(8), A(9)]), beneficiaries: Object.freeze([A(9), A(8)]),
  tokenData: Object.freeze(["0xabcd", "0x"]), mintCommitments: Object.freeze([id("mint-a"), ZeroHash]),
  expectedPolicyHash: id("policy"), authorizationId: ZeroHash, contextHash: id("context"), resolverData: "0x" });

test("ticket builder copies and freezes full-width batch values before producing EIP-712", () => {
  const ticket = gates.mintTicketForBatch({ chainId, manager, ledger, executor, authorizerKind: 2n,
    nonce: id("nonce"), deadline: (1n << 64n) - 1n }, batch);
  assert.equal(ticket.collectionId, 9007199254740993n);
  assert.equal(ticket.quantity, 2n);
  assert(Object.isFrozen(ticket));
  const payload = gates.mintTicketTypedData(chainId, gate, ticket);
  assert(Object.isFrozen(payload));
  assert(Object.isFrozen(payload.message));
  assert.equal(gates.mintTicketAuthorizationId(payload.digest).length, 66);
  assert.throws(() => gates.mintTicketForBatch({ chainId, manager, ledger, executor, authorizerKind: 2n,
    nonce: id("nonce"), deadline: 0n }, { ...batch, authorizer: ZeroAddress }), /authorizer/);
  assert.throws(() => gates.mintTicketTypedData(1n, gate, ticket), /chainId differs/);
});

test("strict byte and integer boundaries reject coercion and malformed hex", () => {
  assert.throws(() => gates.mintBatchHashes({ ...batch, resolverData: "0x0" }), /hex bytes/);
  const oversized = Array(gates.MINT_GATE_CLIENT_MAX_BATCH + 1).fill("not-an-address");
  assert.throws(() => gates.mintBatchHashes({ initialRecipients: oversized, beneficiaries: oversized,
    tokenData: oversized, mintCommitments: oversized }), /same length/);
  const invalidProof = { maxCount: "not-a-bigint", hasPriceOverride: false, priceOverride: 0n, proof: [] };
  assert.throws(() => gates.mintAllowlistResolverData([Array(2049).fill(invalidProof), Array(2049).fill(invalidProof)]), /client boundary/);
  assert.throws(() => gates.mintTicketGateData({ ...gates.mintTicketForBatch({ chainId, manager, ledger, executor,
    authorizerKind: 2n, nonce: id("nonce"), deadline: 1n }, batch), quantity: 2 }), /bigint/);
  assert.throws(() => gates.mintAllowlistLeaf({ chainId, manager, collectionId: 1n, phaseId: id("phase"), counterId: id("counter"),
    account: payer, maxCount: 1n, hasPriceOverride: false, priceOverride: 1n }), /do not support price overrides/);
  assert.throws(() => gates.mintAllowlistLeaf({ chainId, manager, collectionId: 1n, phaseId: id("phase"), counterId: id("counter"),
    account: payer, maxCount: 1n, hasPriceOverride: true, priceOverride: 0n }), /do not support price overrides/);
});

test("delegate request makes its retained narrow commitment boundary visible", () => {
  const routed = { ...batch, authorizer: ZeroAddress, initialRecipients: [vault, vault], beneficiaries: [vault, vault] };
  const request = gates.delegateMintRequest(manager, executor, routed, vault, id("delegate nonce"));
  assert.deepEqual(Object.keys(request), ["manager", "executor", "collectionId", "phaseId", "payer", "authorizer",
    "initialRecipients", "beneficiaries", "contextHash", "expectedPolicyHash", "gateData"]);
  assert(Object.isFrozen(request.initialRecipients));
  assert.equal(gates.delegateMintAuthorizationId(chainId, gate, id("config"), request).length, 66);
  assert.throws(() => gates.delegateMintRequest(manager, executor, { ...routed, initialRecipients: [vault, payer] }, vault, id("nonce")), /equal vault/);
  assert.throws(() => gates.delegateMintRequest(manager, executor, { ...routed, payer: vault }, vault, id("nonce")), /differ from vault/);
});

test("allowlist resolver output remains consumable by the full-batch binding helper", () => {
  const proof = { maxCount: 10n, hasPriceOverride: false, priceOverride: 0n, proof: [id("sibling")] };
  const resolverData = gates.mintAllowlistResolverData([[proof]]);
  const proofValuesHash = gates.mintAllowlistProofValuesHash([id("counter")], [[proof]]);
  const binding = gates.mintAllowlistAuthorizationBinding(manager, ledger, executor,
    { ...batch, authorizer: ZeroAddress, resolverData }, proofValuesHash, id("allowlist nonce"));
  assert.equal(binding.tokenDataHash, gates.mintBatchHashes(batch).tokenDataArrayHash);
  assert(Object.isFrozen(binding));
  assert.equal(gates.mintAllowlistAuthorizationId(chainId, gate, id("config"), binding).length, 66);
  const largeProof = { ...proof, proof: Array(gates.MINT_GATE_CLIENT_MAX_PROOF_NODES).fill(id("node")) };
  assert.throws(() => gates.mintAllowlistResolverData(Array(512).fill([largeProof])), /resolverData/);
});

test("compiler ABI decodes produced ticket and allowlist payloads with exact current structs", () => {
  const ticket = gates.mintTicketForBatch({ chainId, manager, ledger, executor, authorizerKind: 2n,
    nonce: id("nonce"), deadline: 99n }, batch);
  const signature = "0x1234", ticketData = gates.mintTicketGateData(ticket, signature);
  const ticketDecoded = coder.decode([
    "tuple(uint256 chainId,address manager,address ledger,uint256 collectionId,bytes32 phaseId,address executor,address payer,address authorizer,uint8 authorizerKind,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,uint256 quantity,bytes32 contextHash,bytes32 policyHash,bytes32 nonce,uint64 deadline)", "bytes"], ticketData);
  assert.equal(ticketDecoded[0].tokenDataArrayHash, ticket.tokenDataArrayHash);
  assert.equal(ticketDecoded[1], signature);
  const ticketAbi = new Interface(fixture.abis.ticket), allowlistAbi = new Interface(fixture.abis.allowlist), delegateAbi = new Interface(fixture.abis.delegate);
  assert.equal(ticketAbi.getFunction("validateMintBatch").inputs[2].components.length, 12);
  assert.equal(allowlistAbi.getFunction("previewAuthorizationId").inputs[2].components.at(-1).name, "resolverData");
  assert.equal(delegateAbi.getFunction("validateMint").inputs.length, 11);
});

test("fixture is locked to bba source and the exact clean compiler capture", () => {
  assert.equal(fixture.sourceCommit, "bba738e9a9af3f12fdccd2e9cbc825aa555adb08");
  assert.equal(fixture.sourceTree, "236b9e7c52de9701177394f302925788a2bbb695");
  assert.equal(fixture.sourceCount, 130);
  assert.match(fixture.qualification, /no native-runtime/);
  assert.throws(() => currentMintGatesFixture("{}", "{}"), /differs from the reviewed canonical/);
});
