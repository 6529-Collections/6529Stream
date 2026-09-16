import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, id, keccak256 } from "ethers";
import * as distribution from "../dist/current-distribution.js";

// Literal commitment encodings from d8f39826/292cb0f3. These vectors do not
// establish live phase admission, reveal funding, Safe execution or delivery.
const coder = AbiCoder.defaultAbiCoder();
const addr = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const context = { chainId: 31337n, distributor: addr(1), core: addr(2), manager: addr(3) };
const collectionId = 9007199254740993n, phaseId = id("distribution phase");
const programType = "tuple(address operator,bytes32 slicesRoot,bytes32 supplyCounterId,bytes32 recipientCounterId,uint64 totalQuantity,uint64 perRecipientCap,uint8 deliveryMode,bool prepared)";
const program = { operator: addr(4), slicesRoot: id("slices root"), supplyCounterId: id("supply"),
  recipientCounterId: id("recipient"), totalQuantity: (1n << 64n) - 1n, perRecipientCap: 2n,
  deliveryMode: 1n, prepared: true };
const tokens = [
  { beneficiary: addr(5), tokenData: "0xabcd", mintCommitment: id("mint0") },
  { beneficiary: addr(5), tokenData: "0xab", mintCommitment: id("mint1") },
  { beneficiary: addr(6), tokenData: "0xcd", mintCommitment: id("mint2") },
  { beneficiary: addr(7), tokenData: "0x", mintCommitment: id("mint3") },
  { beneficiary: addr(8), tokenData: "0x1234", mintCommitment: id("mint4") },
];
function sliceInput(rows) {
  return { collectionId, phaseId, beneficiaries: rows.map(x => x.beneficiary),
    tokenData: rows.map(x => x.tokenData), mintCommitments: rows.map(x => x.mintCommitment) };
}
function sliceHash(index, input) {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "uint256", "address[]", "bytes[]", "bytes32[]"],
    [id("6529STREAM_OPERATOR_DISTRIBUTION_SLICE_V1"), context.chainId, context.distributor, context.core, context.manager,
      input.collectionId, input.phaseId, index, input.beneficiaries, input.tokenData, input.mintCommitments]));
}
function authorization(index) {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_OPERATOR_DISTRIBUTION_AUTHORIZATION_V1"), context.chainId, context.distributor,
      context.core, context.manager, collectionId, phaseId, index]));
}
function pair(a, b) {
  return keccak256(coder.encode(["bytes32", "bytes32"], BigInt(a) < BigInt(b) ? [a, b] : [b, a]));
}
function manifestInput(overrides = {}) {
  return { context, collectionId, phaseId, operator: program.operator, supplyCounterId: program.supplyCounterId,
    recipientCounterId: program.recipientCounterId, perRecipientCap: 2n, deliveryMode: 1n, prepared: true,
    sliceQuantity: 2, tokens, manifestCompletenessReviewed: true, ...overrides };
}

test("distribution program and slice authorization preserve literal domains and integer widths", () => {
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", programType],
    [id("6529STREAM_OPERATOR_DISTRIBUTION_CONFIG_V1"), context.chainId, context.distributor, context.core, context.manager, collectionId, phaseId, program]));
  assert.equal(distribution.operatorDistributionProgramHash(context, collectionId, phaseId, program), expected);
  assert.equal(distribution.operatorDistributionSliceAuthorization(context, collectionId, phaseId, 9007199254740995n), authorization(9007199254740995n));
  assert.notEqual(distribution.operatorDistributionProgramHash(context, collectionId, phaseId, { ...program, prepared: false }), expected);
  assert.notEqual(distribution.operatorDistributionProgramHash({ ...context, manager: addr(9) }, collectionId, phaseId, program), expected);
  assert.throws(() => distribution.operatorDistributionProgramHash(context, collectionId, phaseId, { ...program, totalQuantity: 1n << 64n }));
});

test("distribution slice hash binds exact ordered duplicate beneficiaries and dynamic artwork boundaries", () => {
  const input = sliceInput(tokens.slice(0, 2)), expected = sliceHash(5n, input);
  assert.equal(distribution.operatorDistributionSliceHash(context, 5n, input), expected);
  assert.notEqual(distribution.operatorDistributionSliceHash(context, 6n, input), expected);
  assert.notEqual(distribution.operatorDistributionSliceHash(context, 5n, { ...input, tokenData: [...input.tokenData].reverse() }), expected);
  assert.notEqual(distribution.operatorDistributionSliceHash(context, 5n, { ...input, beneficiaries: [addr(5), addr(6)] }), expected);
  assert.notEqual(distribution.operatorDistributionSliceHash(context, 5n, { ...input, tokenData: ["0xab", "0xcdab"] }), expected);
});

test("distribution producer builds independently verifiable odd and single-slice trees", () => {
  const artifact = distribution.buildOperatorDistributionManifest(manifestInput());
  const hashes = [sliceHash(0n, sliceInput(tokens.slice(0, 2))), sliceHash(1n, sliceInput(tokens.slice(2, 4))), sliceHash(2n, sliceInput(tokens.slice(4)))];
  const root = pair(pair(hashes[0], hashes[1]), hashes[2]);
  assert.equal(artifact.program.slicesRoot, root);
  assert.equal(artifact.program.totalQuantity, 5n);
  assert.deepEqual(artifact.tokens, tokens);
  artifact.slices.forEach((slice, i) => {
    assert.equal(slice.sliceHash, hashes[i]);
    assert.equal(slice.proof.reduce(pair, hashes[i]), root);
  });
  const single = distribution.buildOperatorDistributionManifest(manifestInput({ sliceQuantity: 10 }));
  assert.equal(single.program.slicesRoot, sliceHash(0n, sliceInput(tokens)));
  assert.deepEqual(single.slices[0].proof, []);
});

test("distribution batches derive direct or isolated delivery without changing beneficiary commitments", () => {
  const binding = { expectedPolicyHash: id("policy"), resolverData: "0xabcd" };
  for (const mode of [0n, 1n]) {
    const artifact = distribution.buildOperatorDistributionManifest(manifestInput({ deliveryMode: mode }));
    const batch = distribution.operatorDistributionBatchForSlice(artifact, 0, binding);
    assert.equal(batch.payer, ZeroAddress);
    assert.equal(batch.authorizer, ZeroAddress);
    assert.deepEqual(batch.beneficiaries, tokens.slice(0, 2).map(x => x.beneficiary));
    assert.deepEqual(batch.initialRecipients, mode === 0n ? batch.beneficiaries : [context.distributor, context.distributor]);
    assert.equal(batch.contextHash, sliceHash(0n, sliceInput(tokens.slice(0, 2))));
    assert.equal(batch.authorizationId, authorization(0n));
    assert.equal(batch.expectedPolicyHash, binding.expectedPolicyHash);
    assert.equal(batch.resolverData, binding.resolverData);
  }
});

test("distribution durable manifest reconstructs commitments and rejects changed facts or unreviewed input", () => {
  const artifact = distribution.buildOperatorDistributionManifest(manifestInput());
  const encoded = distribution.operatorDistributionManifestToJSON(artifact);
  assert.deepEqual(distribution.operatorDistributionManifestFromJSON(encoded), artifact);
  const changed = JSON.parse(encoded);
  changed.tokens[0].tokenData = "0xffff";
  assert.throws(() => distribution.operatorDistributionManifestFromJSON(JSON.stringify(changed)));
  assert.throws(() => distribution.buildOperatorDistributionManifest(manifestInput({ manifestCompletenessReviewed: false })));
  assert.throws(() => distribution.buildOperatorDistributionManifest(manifestInput({ sliceQuantity: 11 })));
  assert.equal(Object.isFrozen(artifact.tokens[0]), true);
});
