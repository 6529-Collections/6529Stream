import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as merkle from "../dist/current-distribution-merkle.js";
import {
  buildOperatorDistributionManifest,
  operatorDistributionBatchForSlice,
  operatorDistributionProgramHash,
  operatorDistributionSliceAuthorization,
  operatorDistributionSliceHash,
  verifyOperatorDistributionManifest,
} from "../dist/current-distribution.js";
import { compiledInterfaces } from "./current-distribution-merkle-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const context = { chainId: (1n << 150n) + 9n, distributor: address(1), core: address(2), manager: address(3), ledger: address(4) };
const originalContext = { chainId: context.chainId, distributor: context.distributor, core: context.core, manager: context.manager };
const operator = address(5);
const a = address(6), b = address(7), c = address(8);
const collectionId = (1n << 140n) + 7n;
const phaseId = id("phase");
const supplyId = id("supply"), recipientId = id("recipient"), extraId = id("extra recipient");
const emptyDefinition = { scope: 2n, keyMode: 0n, capRoot: ZeroHash, metadataHash: ZeroHash };

function setup(deliveryMode = 0n, prepared = false) {
  const manifest = buildOperatorDistributionManifest({
    context: originalContext, collectionId, phaseId, operator, supplyCounterId: supplyId,
    recipientCounterId: recipientId, perRecipientCap: 3n, deliveryMode, prepared,
    sliceQuantity: 3, tokens: [a, a, b, c, a].map((beneficiary, i) => ({
      beneficiary, tokenData: `0x0${i}`, mintCommitment: id(`mint${i}`),
    })), manifestCompletenessReviewed: true,
  });
  const allowances = [{ beneficiary: a, maxCount: 3n }, { beneficiary: b, maxCount: 2n }, { beneficiary: c, maxCount: 1n }];
  const trees = [extraId, recipientId].map(counterId => merkle.buildDistributionMerkleAllowanceTree(
    context, collectionId, phaseId, counterId, 3n, allowances,
  ));
  const definitions = trees.map((tree, i) => ({ scope: i === 0 ? 2n : 1n, keyMode: 3n,
    capRoot: tree.root, metadataHash: id(`published full list ${i}`) }));
  const counter = (counterId, definition) => ({ counterId,
    config: { enabled: true, keyMode: 3n, capMode: 3n, deltaMode: 0n, staticCap: 3n, staticIncrement: 1n,
      counterConfigHash: merkle.distributionMerkleDefinitionHash(definition) }, definitionExists: true, definition });
  const counters = [counter(extraId, definitions[0]), {
    counterId: supplyId, config: { enabled: true, keyMode: 1n, capMode: 1n, deltaMode: 0n,
      staticCap: 5n, staticIncrement: 1n, counterConfigHash: id("latched absent supply") },
    definitionExists: false, definition: emptyDefinition,
  }, counter(recipientId, definitions[1])];
  const selection = { counterConfigHash: counters[2].config.counterConfigHash, exists: true, definition: definitions[1] };
  const program = merkle.prepareDistributionMerkleProgram(manifest, selection);
  const proofs = trees.map(tree => [tree.entries[0].proof, tree.entries[0].proof, tree.entries[1].proof]);
  const input = { program, sliceIndex: 0, counters, proofs, expectedPolicyHash: id("policy"), gateData: "0x1234", revealFeePerTokenWei: 7n };
  return { manifest, trees, definitions, counters, selection, program, proofs, input };
}

test("additive hash binds selected publication without changing original program, slice or authorization", () => {
  const e = setup();
  assert.equal(e.program.factsVerified, false);
  assert.equal(e.program.originalProgramHash, e.manifest.programHash);
  assert.equal(e.program.originalProgramHash, operatorDistributionProgramHash(originalContext, collectionId, phaseId, e.manifest.program));
  assert.notEqual(e.program.applicationConfigHash, e.manifest.programHash);
  const expected = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "bytes32"], [
    id("6529STREAM_OPERATOR_DISTRIBUTION_MERKLE_CONFIG_V1"), e.manifest.programHash,
    e.selection.counterConfigHash, e.selection.definition.metadataHash,
  ]));
  assert.equal(e.program.applicationConfigHash, expected);
  const definition = { ...e.selection.definition, metadataHash: id("another complete file") };
  const next = merkle.prepareDistributionMerkleProgram(e.manifest,
    { exists: true, definition, counterConfigHash: merkle.distributionMerkleDefinitionHash(definition) });
  assert.equal(next.originalProgramHash, e.program.originalProgramHash);
  assert.notEqual(next.applicationConfigHash, e.program.applicationConfigHash);
  assert.deepEqual(verifyOperatorDistributionManifest(e.program.manifest), e.manifest);
  const batch = operatorDistributionBatchForSlice(e.manifest, 0, { expectedPolicyHash: id("policy"), resolverData: "0x" });
  assert.equal(batch.authorizationId, operatorDistributionSliceAuthorization(originalContext, collectionId, phaseId, 0n));
  assert.equal(batch.contextHash, operatorDistributionSliceHash(originalContext, 0n, {
    collectionId, phaseId, beneficiaries: batch.beneficiaries, tokenData: batch.tokenData, mintCommitments: batch.mintCommitments,
  }));
});

test("getter can be prepared before phase configuration and retains original zero Program ABI values", () => {
  const program = { operator: ZeroAddress, slicesRoot: ZeroHash, supplyCounterId: ZeroHash, recipientCounterId: ZeroHash,
    totalQuantity: 0n, perRecipientCap: 0n, deliveryMode: 0n, prepared: false };
  const e = setup();
  const call = merkle.prepareDistributionMerkleProgramRead(originalContext, 0n, ZeroHash, program, e.selection.counterConfigHash);
  assert.equal(call.to, context.distributor);
  assert.equal(call.value, 0n);
  assert.equal(call.data.slice(0, 10), "0x9f2d3027");
  assert.equal(call.data, compiledInterfaces.distributor.encodeFunctionData("merkleProgramHash", [0n, ZeroHash, program, e.selection.counterConfigHash]));
  assert.notEqual(merkle.distributionMerkleProgramHash(originalContext, 0n, ZeroHash, program, e.selection), ZeroHash);
  assert.throws(() => merkle.prepareDistributionMerkleProgramRead(context, 0n, ZeroHash, program, e.selection.counterConfigHash), /unknown/);
  assert.throws(() => merkle.distributionMerkleProgramHash(context, 0n, ZeroHash, program, e.selection), /unknown/);
  const { ledger: _ledger, ...projected } = context;
  assert.equal(merkle.distributionMerkleProgramHash(projected, 0n, ZeroHash, program, e.selection),
    merkle.distributionMerkleProgramHash(originalContext, 0n, ZeroHash, program, e.selection));
  assert.throws(() => merkle.normalizeDistributionMerkleOriginalProgram({ ...program, deliveryMode: 2n }), /mode/);
});

test("actual selected definition rejects absent including latched absence, unbound hash, root and publication gaps", () => {
  const e = setup();
  const invalid = [
    { ...e.selection, exists: false }, { ...e.selection, counterConfigHash: id("other config") },
    ...[{ scope: 0n }, { keyMode: 2n }, { capRoot: ZeroHash }, { metadataHash: ZeroHash }].map(patch => {
      const definition = { ...e.selection.definition, ...patch };
      return { exists: true, definition, counterConfigHash: merkle.distributionMerkleDefinitionHash(definition) };
    }),
  ];
  for (const selection of invalid) assert.throws(() => merkle.prepareDistributionMerkleProgram(e.manifest, selection));
  const normalizedAbsent = merkle.normalizeDistributionMerkleDefinitionSelection({ ...e.selection, exists: false });
  assert.equal(normalizedAbsent.exists, false);
  assert.deepEqual(normalizedAbsent.definition, e.selection.definition);
  assert.equal(merkle.distributionMerklePublicationKeccak("0x010203"), keccak256("0x010203"));
});

test("allowance leaves use exact double hash and preserve distinct domain inputs and duplicate tree rows", () => {
  const e = setup();
  const proof = e.trees[1].entries[0].proof;
  const preimage = coder.encode(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256"], [
    id("6529STREAM_MINT_ALLOWLIST_LEAF_V1"), context.chainId, context.manager, collectionId, phaseId, recipientId, a, 3n, false, 0n,
  ]);
  const leaf = merkle.distributionMerkleAllowanceLeaf(context, collectionId, phaseId, recipientId, a, proof);
  assert.equal(leaf, keccak256(keccak256(preimage)));
  assert.notEqual(leaf, keccak256(preimage));
  assert(merkle.verifyDistributionMerkleAllowanceProof(e.trees[1].root, leaf, proof.proof));
  for (const alternative of [
    merkle.distributionMerkleAllowanceLeaf({ ...context, chainId: context.chainId + 1n }, collectionId, phaseId, recipientId, a, proof),
    merkle.distributionMerkleAllowanceLeaf({ ...context, manager: address(99) }, collectionId, phaseId, recipientId, a, proof),
    merkle.distributionMerkleAllowanceLeaf(context, collectionId, id("other phase"), recipientId, a, proof),
    merkle.distributionMerkleAllowanceLeaf(context, collectionId, phaseId, extraId, a, proof),
    merkle.distributionMerkleAllowanceLeaf(context, collectionId, phaseId, recipientId, b, proof),
    merkle.distributionMerkleAllowanceLeaf(context, collectionId, phaseId, recipientId, a, { ...proof, maxCount: 2n }),
  ]) assert(!merkle.verifyDistributionMerkleAllowanceProof(e.trees[1].root, alternative, proof.proof));
  const duplicate = merkle.buildDistributionMerkleAllowanceTree(context, collectionId, phaseId, recipientId, 3n,
    [{ beneficiary: a, maxCount: 2n }, { beneficiary: a, maxCount: 3n }, { beneficiary: a, maxCount: 2n }]);
  assert.equal(duplicate.entries.length, 3);
  assert.equal(duplicate.entries[0].leaf, duplicate.entries[2].leaf);
  for (const row of duplicate.entries) assert(merkle.verifyDistributionMerkleAllowanceProof(duplicate.root, row.leaf, row.proof.proof));
});

test("complete proof groups omit static counters, keep all duplicate beneficiaries, and preserve actual counter order", () => {
  const e = setup();
  const resolver = merkle.distributionMerkleResolverData(context, collectionId, phaseId, [a, a, b], e.counters, e.proofs);
  assert.deepEqual(merkle.decodeDistributionMerkleProofs(resolver), e.proofs);
  assert.equal(resolver, coder.encode([`${merkle.DISTRIBUTION_MERKLE_PROOF_TUPLE}[][]`], [e.proofs]));
  assert.throws(() => merkle.distributionMerkleResolverData(context, collectionId, phaseId, [a, a, b], e.counters, [...e.proofs].reverse()), /proof/);
  assert.throws(() => merkle.distributionMerkleResolverData(context, collectionId, phaseId, [a, b, a], e.counters, e.proofs), /proof/);
  assert.throws(() => merkle.distributionMerkleResolverData(context, collectionId, phaseId, [a, a, b], e.counters, [e.proofs[0]]), /groups/);
  assert.throws(() => merkle.distributionMerkleResolverData(context, collectionId, phaseId, [a, a, b], e.counters,
    [e.proofs[0].slice(0, 2), e.proofs[1]]), /every ordered/);
  const scoped = e.counters.map((row, i) => i === 0 ? { ...row, definitionExists: false } : row);
  assert.throws(() => merkle.distributionMerkleResolverData(context, collectionId, phaseId, [a, a, b], scoped, e.proofs), /Unsupported/);
  assert.throws(() => merkle.distributionMerkleResolverData(context, collectionId, phaseId, [a, a, b],
    e.counters.map((row, i) => i === 0 ? { ...row, config: { ...row.config, staticCap: 2n } } : row), e.proofs), /ceiling/);
  const optionalPublication = { ...e.counters[0].definition, metadataHash: ZeroHash };
  const optionalCounters = e.counters.map((row, i) => i === 0 ? {
    ...row, definition: optionalPublication,
    config: { ...row.config, counterConfigHash: merkle.distributionMerkleDefinitionHash(optionalPublication) },
  } : row);
  const optional = merkle.prepareDistributionMerkleCall(context, operator, { ...e.input, counters: optionalCounters });
  assert.equal(optional.input.counters[0].definition.metadataHash, ZeroHash);
  assert.equal(optional.batch.resolverData, resolver);
});

test("free canonical proof presentation has explicit stricter client bounds", () => {
  const e = setup();
  const proof = e.proofs[0][0];
  for (const patch of [{ maxCount: 0n }, { maxCount: 1n << 64n }, { maxCount: 1 },
    { hasPriceOverride: true }, { priceOverride: 1n }, { proof: Array(65).fill(ZeroHash) }]) {
    assert.throws(() => merkle.normalizeDistributionMerkleProof({ ...proof, ...patch }));
  }
  assert.throws(() => merkle.normalizeDistributionMerkleProofs([]), /bounded/);
  assert.throws(() => merkle.normalizeDistributionMerkleProofs([Array(1)]), /dense/);
  assert.throws(() => merkle.normalizeDistributionMerkleProofs(Array(17).fill([proof])), /bounded/);
  assert.throws(() => merkle.normalizeDistributionMerkleProofs([Array(11).fill(proof)]), /bounded/);
  const encoded = merkle.encodeDistributionMerkleProofs(e.proofs);
  const decoded = merkle.decodeDistributionMerkleProofs(encoded);
  assert(Object.isFrozen(decoded[0][0].proof));
  assert.throws(() => { decoded[0][0].proof[0] = ZeroHash; }, TypeError);
  assert.throws(() => merkle.decodeDistributionMerkleProofs(`${encoded}${"00".repeat(32)}`), /Noncanonical client/);
  assert.throws(() => merkle.buildDistributionMerkleAllowanceTree(context, collectionId, phaseId, recipientId, 2n,
    [{ beneficiary: a, maxCount: 3n }]), /ceiling/);
});

test("projected accounting applies every mixed cap to all duplicate increments and retained current balance", () => {
  const key = id("one shared COLLECTION value key");
  const rows = [{ valueKey: key, current: 1n, increment: 1n, cap: 3n },
    { valueKey: key, current: 1n, increment: 1n, cap: 4n }];
  assert.deepEqual(merkle.distributionMerkleProjectedCaps(rows).map(row => row.projected), [3n, 3n]);
  assert.throws(() => merkle.distributionMerkleProjectedCaps([{ ...rows[0], cap: 2n }, rows[1]]), /applicable/);
  assert.throws(() => merkle.distributionMerkleProjectedCaps([rows[0], { ...rows[1], current: 0n }]), /Inconsistent/);
  assert.throws(() => merkle.distributionMerkleProjectedCaps([{ valueKey: key, current: (1n << 64n) - 1n, increment: 1n, cap: 0n }]), /uint64/);
  const independent = merkle.distributionMerkleProjectedCaps([rows[0], { ...rows[1], valueKey: id("another key"), current: 0n }]);
  assert.deepEqual(independent.map(row => row.projected), [2n, 1n]);
});

test("prepared distribute retains original full MintBatch, independent slice proof, both delivery modes and exact fee", () => {
  for (const deliveryMode of [0n, 1n]) {
    for (const prepared of [false, true]) {
      const e = setup(deliveryMode, prepared);
      const call = merkle.prepareDistributionMerkleCall(context, operator, e.input);
      assert.equal(call.kind, "distribute");
      assert.equal(call.factsVerified, false);
      assert.equal(call.caller, operator);
      assert.equal(call.call.value, 21n);
      assert.equal(call.batch.payer, ZeroAddress);
      assert.equal(call.batch.authorizer, ZeroAddress);
      assert.deepEqual(call.batch.beneficiaries, [a, a, b]);
      assert.deepEqual(call.batch.initialRecipients, deliveryMode === 0n ? [a, a, b] : Array(3).fill(context.distributor));
      assert.equal(call.batch.expectedPolicyHash, id("policy"));
      assert.equal(call.call.data, compiledInterfaces.distributor.encodeFunctionData("distribute", [
        e.manifest.program, 0n, e.manifest.slices[0].proof, call.batch, "0x1234",
      ]));
      assert.deepEqual(merkle.normalizeDistributionMerklePreparedCall(call), call);
      assert.notDeepEqual(e.manifest.slices[0].proof, e.proofs[0][0].proof);
    }
  }
});

test("distribute rejects invented caller, incompatible selected inventory, wrong supply scope and altered batches", () => {
  const e = setup();
  assert.throws(() => merkle.prepareDistributionMerkleCall(context, a, e.input), /caller/);
  assert.throws(() => merkle.prepareDistributionMerkleCall({ ...context, manager: address(99) }, operator, e.input), /coordinates/);
  const bad = e.counters.map((row, i) => i === 1 ? { ...row, definitionExists: true, definition: { ...row.definition, scope: 1n } } : row);
  assert.throws(() => merkle.prepareDistributionMerkleCall(context, operator, { ...e.input, counters: bad }), /PHASE/);
  assert.throws(() => merkle.prepareDistributionMerkleCall(context, operator, { ...e.input, sliceIndex: -1 }), /index/);
  assert.throws(() => merkle.prepareDistributionMerkleCall(context, operator,
    { ...e.input, revealFeePerTokenWei: 1n << 255n }), /uint256/);
  const call = merkle.prepareDistributionMerkleCall(context, operator, e.input);
  assert.throws(() => merkle.normalizeDistributionMerklePreparedCall({ ...call, batch: { ...call.batch, payer: a } }), /batch differs/);
  assert.throws(() => merkle.normalizeDistributionMerklePreparedCall({ ...call, call: { ...call.call, value: 20n } }), /differs/);
  assert.throws(() => merkle.normalizeDistributionMerklePreparedCall({ ...call, call: { ...call.call, data: `${call.call.data}00` } }), /differs/);
  assert.throws(() => merkle.normalizeDistributionMerklePreparedCall({ ...call, factsVerified: true }), /differs/);
});

test("complete calldata ceiling includes selector, dynamic offsets and padding", () => {
  const e = setup();
  const empty = merkle.prepareDistributionMerkleCall(context, operator, { ...e.input, gateData: "0x" });
  const overhead = (empty.call.data.length - 2) / 2;
  // ABI argument payloads are word aligned; the four-byte selector remains part of the client ceiling.
  const largestGate = Math.floor((merkle.DISTRIBUTION_MERKLE_MAX_BYTES - overhead) / 32) * 32;
  const accepted = merkle.prepareDistributionMerkleCall(context, operator,
    { ...e.input, gateData: `0x${"12".repeat(largestGate)}` });
  assert.equal((accepted.call.data.length - 2) / 2, overhead + largestGate);
  assert.deepEqual(merkle.normalizeDistributionMerklePreparedCall(accepted), accepted);
  assert.throws(() => merkle.prepareDistributionMerkleCall(context, operator,
    { ...e.input, gateData: `0x${"12".repeat(largestGate + 1)}` }), /allocation/);
});

test("claim transports are original zero-value methods and do not invent current phase or owed authority", () => {
  const own = merkle.prepareDistributionMerkleClaim(context, a, { kind: "claimNft", tokenId: 1n << 140n, receiver: b });
  const delegated = merkle.prepareDistributionMerkleClaim(context, c,
    { kind: "claimNftFor", tokenId: 1n << 140n, walletWide: true, delegationIndex: 1n << 170n });
  for (const call of [own, delegated]) {
    assert.equal(call.kind, "claim");
    assert.equal(call.call.to, context.distributor);
    assert.equal(call.call.value, 0n);
    assert.equal(call.factsVerified, false);
    assert.deepEqual(merkle.normalizeDistributionMerklePreparedCall(call), call);
    assert.equal(compiledInterfaces.distributor.parseTransaction({ data: call.call.data }).name, call.input.kind);
  }
  assert.throws(() => merkle.prepareDistributionMerkleClaim(context, a, { kind: "claimNft", tokenId: 1n, receiver: context.distributor }), /receiver/);
  assert.throws(() => merkle.prepareDistributionMerkleClaim(context, a, { kind: "claimNftFor", tokenId: 1n, receiver: b, walletWide: false, delegationIndex: 0n }), /unknown/);
  assert.throws(() => merkle.prepareDistributionMerkleClaim(context, a, { kind: "sweep", tokenId: 1n, receiver: b }), /Unknown/);
});

test("all new artifacts copy mutable nested facts and reject sparse or hidden data", () => {
  const e = setup();
  const mutable = structuredClone(e.input);
  const call = merkle.prepareDistributionMerkleCall({ ...context }, operator, mutable);
  const originalData = call.call.data;
  mutable.program.manifest.tokens[0].tokenData = "0xffff";
  mutable.proofs[0][0].proof[0] = ZeroHash;
  mutable.counters[0].definition.capRoot = ZeroHash;
  assert.equal(call.call.data, originalData);
  assert(Object.isFrozen(call.input.proofs[0][0].proof));
  assert(Object.isFrozen(call.input.program.manifest.tokens[0]));
  assert(Object.isFrozen(call.input.counters[0].definition));
  const manifest = structuredClone(e.manifest);
  Object.defineProperty(manifest, "hidden", { value: 1n });
  assert.throws(() => merkle.prepareDistributionMerkleProgram(manifest, e.selection), /ordinary/);
  const sparse = structuredClone(e.manifest);
  delete sparse.tokens[1];
  assert.throws(() => merkle.prepareDistributionMerkleProgram(sparse, e.selection), /dense/);
  assert.throws(() => merkle.normalizeDistributionMerkleProgram({ ...e.program, applicationConfigHash: e.program.originalProgramHash }), /differs/);
});
