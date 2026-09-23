import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { AbiCoder, Interface, ZeroAddress, id, keccak256, toUtf8Bytes } from "ethers";
import {
  OPERATOR_DISTRIBUTION_DELIVERY_MODE,
  buildOperatorDistributionManifest,
  inspectAndPrepareOperatorDistribution,
  inspectDistributionClaim,
  operatorDistributionBatchForSlice,
  operatorDistributionManifestFromJSON,
  operatorDistributionManifestToJSON,
  operatorDistributionProgramHash,
  operatorDistributionSliceAuthorization,
  operatorDistributionSliceHash,
  prepareDelegatedDistributionClaim,
  prepareOwnDistributionClaim,
  simulatePreparedDistributionClaim,
  simulatePreparedOperatorDistribution,
  verifyOperatorDistributionManifest,
} from "../dist/current-distribution.js";

const coder = AbiCoder.defaultAbiCoder(), chainId = 31337n;
const A = n => `0x${n.toString(16).padStart(40, "0")}`;
const distributor = A(1), core = A(2), manager = A(3), operator = A(4), ledger = A(5), coordinator = A(6), beneficiaryA = A(10), beneficiaryB = A(11), delegate = A(12), receiver = A(13);
const h = value => keccak256(toUtf8Bytes(value)), zero32 = `0x${"00".repeat(32)}`, phaseId = h("phase"), supplyCounterId = h("supply"), recipientCounterId = h("recipient"), policyHash = h("policy");
const context = { chainId, distributor, core, manager };
const tokens = [
  { beneficiary: beneficiaryA, tokenData: "0x0102", mintCommitment: h("art-0") },
  { beneficiary: beneficiaryA, tokenData: "0x0102", mintCommitment: h("art-1") },
  { beneficiary: beneficiaryB, tokenData: "0x03", mintCommitment: h("art-2") },
  { beneficiary: beneficiaryA, tokenData: "0x0405", mintCommitment: h("art-3") },
  { beneficiary: beneficiaryB, tokenData: "0x06", mintCommitment: h("art-4") },
];
function artifact(deliveryMode = OPERATOR_DISTRIBUTION_DELIVERY_MODE.DIRECT, prepared = false) {
  return buildOperatorDistributionManifest({ context, collectionId: 7n, phaseId, operator, supplyCounterId, recipientCounterId,
    perRecipientCap: 3n, deliveryMode, prepared, sliceQuantity: 2, tokens, manifestCompletenessReviewed: true });
}

test("compiler fixture is pinned to the accepted normalized source binding and exact callable shapes", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-distribution-abi.json", import.meta.url)));
  assert.equal(fixture.compilerCommit, "57d70b58209a1c7f54cfbf6715967489fef28c31");
  assert.equal(fixture.compilerTree, "1ab689164d36de0b610ef20c980e0db423f3a20f");
  assert.equal(fixture.targetCommit, "d8f3982603c2b19cef6dc953e5b4969e5295408f");
  assert.equal(fixture.targetTree, "51ecfa45406ab8a030175357aebd04c4ccab42f5");
  assert.equal(fixture.sourceCount, 1014);
  assert.equal(fixture.provenance.compilerInputSha256, "1abdcd09b08dfd45b5b3f807d5f51776cc381250d56ba0ea6473ea8b68373345");
  assert.equal(fixture.provenance.compilerOutputSha256, "60baf05d47d79f1023c3b2539a22946838a6046521130bad751f9161e5c72530");
  for (const contract of fixture.contracts) {
    const iface = new Interface(contract.abi), names = contract.abi.filter(item => item.type === "function").map(item => item.name).sort();
    assert.deepEqual(names, [...contract.methods].sort()); for (const name of contract.methods) assert.ok(iface.getFunction(name).selector);
  }
});

test("program, slice and authorization hashes match literal abi.encode preimages", () => {
  const a = artifact(), p = a.program;
  const expectedProgram = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "tuple(address operator,bytes32 slicesRoot,bytes32 supplyCounterId,bytes32 recipientCounterId,uint64 totalQuantity,uint64 perRecipientCap,uint8 deliveryMode,bool prepared)"],
    [id("6529STREAM_OPERATOR_DISTRIBUTION_CONFIG_V1"), chainId, distributor, core, manager, 7n, phaseId, p]));
  assert.equal(operatorDistributionProgramHash(context, 7n, phaseId, p), expectedProgram);
  const selected = tokens.slice(0, 2), expectedSlice = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "uint256", "address[]", "bytes[]", "bytes32[]"],
    [id("6529STREAM_OPERATOR_DISTRIBUTION_SLICE_V1"), chainId, distributor, core, manager, 7n, phaseId, 0n, selected.map(x => x.beneficiary), selected.map(x => x.tokenData), selected.map(x => x.mintCommitment)]));
  assert.equal(operatorDistributionSliceHash(context, 0n, { collectionId: 7n, phaseId, beneficiaries: selected.map(x => x.beneficiary), tokenData: selected.map(x => x.tokenData), mintCommitments: selected.map(x => x.mintCommitment) }), expectedSlice);
  assert.equal(operatorDistributionSliceAuthorization(context, 7n, phaseId, 0n), keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "uint256"], [id("6529STREAM_OPERATOR_DISTRIBUTION_AUTHORIZATION_V1"), chainId, distributor, core, manager, 7n, phaseId, 0n])));
});

test("manifest preserves duplicates and artwork order across an odd sorted-pair tree and durable restart", () => {
  const a = artifact(); assert.equal(a.slices.length, 3); assert.deepEqual(a.tokens.map(item => item.beneficiary.toLowerCase()), tokens.map(item => item.beneficiary.toLowerCase()));
  assert.deepEqual(a.tokens.map(item => item.tokenData), tokens.map(item => item.tokenData)); assert.equal(a.program.totalQuantity, 5n);
  const fold = (leaf, proof) => proof.reduce((node, sibling) => keccak256(coder.encode(["bytes32", "bytes32"], BigInt(node) < BigInt(sibling) ? [node, sibling] : [sibling, node])), leaf);
  for (const slice of a.slices) assert.equal(fold(slice.sliceHash, slice.proof), a.program.slicesRoot);
  assert.deepEqual(operatorDistributionManifestFromJSON(operatorDistributionManifestToJSON(a)), a);
  assert.throws(() => operatorDistributionManifestFromJSON(operatorDistributionManifestToJSON({ ...a, program: { ...a.program, perRecipientCap: 2n } })), /canonical reconstruction/);
  assert.throws(() => buildOperatorDistributionManifest({ context, collectionId: 7n, phaseId, operator, supplyCounterId, recipientCounterId, perRecipientCap: 1n, deliveryMode: 0n, prepared: false, sliceQuantity: 11, tokens, manifestCompletenessReviewed: true }), /1 to 10/);
  assert.throws(() => buildOperatorDistributionManifest({ context, collectionId: 7n, phaseId, operator, supplyCounterId, recipientCounterId, perRecipientCap: 1n, deliveryMode: 0n, prepared: false, sliceQuantity: 2, tokens, manifestCompletenessReviewed: false }), /explicitly attest/);
});

test("DIRECT and FAILURE_ISOLATED batches route recipients exactly and keep free identities zero", () => {
  const direct = operatorDistributionBatchForSlice(artifact(), 0, { expectedPolicyHash: policyHash, resolverData: "0x1234" });
  assert.deepEqual(direct.initialRecipients, direct.beneficiaries); assert.equal(direct.payer, ZeroAddress); assert.equal(direct.authorizer, ZeroAddress);
  const isolated = operatorDistributionBatchForSlice(artifact(OPERATOR_DISTRIBUTION_DELIVERY_MODE.FAILURE_ISOLATED), 0, { expectedPolicyHash: policyHash, resolverData: "0x" });
  assert.deepEqual(isolated.initialRecipients.map(value => value.toLowerCase()), [distributor, distributor]); assert.deepEqual(isolated.beneficiaries.map(value => value.toLowerCase()), [beneficiaryA, beneficiaryA]);
  assert.equal(isolated.contextHash, artifact(OPERATOR_DISTRIBUTION_DELIVERY_MODE.FAILURE_ISOLATED).slices[0].sliceHash);
});

async function fixtureInterface() {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/current-distribution-abi.json", import.meta.url)));
  return new Interface(fixture.contracts.flatMap(contract => contract.abi));
}

function inspectionProvider(iface, a, controls = {}) {
  const programHash = operatorDistributionProgramHash(a.context, a.collectionId, a.phaseId, a.program), royaltyConfigHash = h("royalty-config"), batch = operatorDistributionBatchForSlice(a, 0, { expectedPolicyHash: policyHash, resolverData: "0x1234" });
  return { getNetwork: async () => ({ chainId }), call: async tx => {
    assert.equal(tx.blockTag, 123); const parsed = iface.parseTransaction({ data: tx.data }); const name = parsed.name;
    switch (name) {
      case "core": return iface.encodeFunctionResult(parsed.fragment, [tx.to.toLowerCase() === coordinator.toLowerCase() ? core : core]);
      case "manager": return iface.encodeFunctionResult(parsed.fragment, [manager]);
      case "mintLedger": return iface.encodeFunctionResult(parsed.fragment, [ledger]);
      case "getSatellitePointer": {
        const target = parsed.args[0] === id("MINT_MANAGER") ? (controls.wrongManager ? A(99) : manager) : coordinator;
        return iface.encodeFunctionResult(parsed.fragment, [target, h(`runtime-${target}`), false, h("module"), "0x12345678", A(20), 2, h("manifest"), h("deployment"), 1n]);
      }
      case "phase": return iface.encodeFunctionResult(parsed.fragment, [true, [false, 1n, 999999n, 10, controls.royalty ? royaltyConfigHash : programHash, h("metadata")]]);
      case "phasePolicyHash": return iface.encodeFunctionResult(parsed.fragment, [policyHash]);
      case "phaseExecutor": return iface.encodeFunctionResult(parsed.fragment, [true]);
      case "counterConfig": {
        const supply = parsed.args[2].toLowerCase() === supplyCounterId.toLowerCase();
        return iface.encodeFunctionResult(parsed.fragment, [[true, supply ? 1 : 3, 1, controls.wrongDelta ? 1 : 0, supply ? 5 : 3, 1, h("counter-config")]]);
      }
      case "phaseRoyaltyPolicy": return iface.encodeFunctionResult(parsed.fragment, [controls.royalty
        ? [true, programHash, A(30), h("resolver-runtime"), h("election"), h("assignment"), h("source-policy")]
        : [false, zero32, ZeroAddress, zero32, zero32, zero32, zero32]]);
      case "phaseRoyaltyConfigHash": return iface.encodeFunctionResult(parsed.fragment, [royaltyConfigHash]);
      case "sliceUsed": return iface.encodeFunctionResult(parsed.fragment, [Boolean(controls.used)]);
      case "programHash": return iface.encodeFunctionResult(parsed.fragment, [programHash]);
      case "sliceHash": return iface.encodeFunctionResult(parsed.fragment, [a.slices[0].sliceHash]);
      case "sliceAuthorization": return iface.encodeFunctionResult(parsed.fragment, [batch.authorizationId]);
      case "collectionRevealPolicy": return iface.encodeFunctionResult(parsed.fragment, [[true, 0, h("reveal-role"), 40n, controls.fee ?? 7n]]);
      case "distribute": return iface.encodeFunctionResult(parsed.fragment, [[101n, 102n], h("operation-root")]);
      default: throw new Error(`unexpected ${name}`);
    }
  } };
}

test("pinned inspection builds the exact payable operator CALL and simulation rechecks live facts", async () => {
  const a = artifact(), iface = await fixtureInterface(), provider = inspectionProvider(iface, a);
  const prepared = await inspectAndPrepareOperatorDistribution(provider, a, 0, { resolverData: "0x1234", gateData: "0xabcd" }, { blockTag: 123 });
  assert.equal(prepared.caller, operator); assert.equal(prepared.call.value, 14n); assert.equal(prepared.revealFeePerTokenWei, 7n);
  const parsed = iface.parseTransaction({ data: prepared.call.data }); assert.equal(parsed.name, "distribute"); assert.equal(parsed.args[3].payer, ZeroAddress); assert.equal(parsed.args[3].authorizer, ZeroAddress);
  assert.deepEqual(await simulatePreparedOperatorDistribution(provider, prepared, { blockTag: 123 }), { tokenIds: [101n, 102n], operationRoot: h("operation-root") });
  await assert.rejects(inspectAndPrepareOperatorDistribution(inspectionProvider(iface, a, { wrongManager: true }), a, 0, { resolverData: "0x1234", gateData: "0xabcd" }, { blockTag: 123 }), /selected Manager/);
  await assert.rejects(inspectAndPrepareOperatorDistribution(inspectionProvider(iface, a, { used: true }), a, 0, { resolverData: "0x1234", gateData: "0xabcd" }, { blockTag: 123 }), /phase, counters/);
  await assert.rejects(inspectAndPrepareOperatorDistribution(inspectionProvider(iface, a, { wrongDelta: true }), a, 0, { resolverData: "0x1234", gateData: "0xabcd" }, { blockTag: 123 }), /phase, counters/);
  await assert.rejects(simulatePreparedOperatorDistribution(provider, { ...prepared, call: { ...prepared.call, value: 13n } }, { blockTag: 123 }), /canonical reconstruction/);
  const preparedArtifact = artifact(OPERATOR_DISTRIBUTION_DELIVERY_MODE.FAILURE_ISOLATED, true);
  assert.equal((await inspectAndPrepareOperatorDistribution(inspectionProvider(iface, preparedArtifact, { royalty: true }), preparedArtifact, 0, { resolverData: "0x1234", gateData: "0xabcd" }, { blockTag: 123 })).call.value, 14n);
  await assert.rejects(inspectAndPrepareOperatorDistribution(inspectionProvider(iface, a, { royalty: true }), a, 0, { resolverData: "0x1234", gateData: "0xabcd" }, { blockTag: 123 }), /prepared distribution program/);
});

test("inspection copies presentation and block pin before the first asynchronous read", async () => {
  const a = artifact(), iface = await fixtureInterface(), base = inspectionProvider(iface, a); let release;
  const gate = new Promise(resolve => { release = resolve; }), presentation = { resolverData: "0x1234", gateData: "0xabcd" }, options = { blockTag: 123 };
  const provider = { ...base, getNetwork: async () => { await gate; return { chainId }; } };
  const pending = inspectAndPrepareOperatorDistribution(provider, a, 0, presentation, options); presentation.resolverData = "0xffff"; options.blockTag = 124; release();
  const prepared = await pending; assert.deepEqual(prepared.presentation, { resolverData: "0x1234", gateData: "0xabcd" });
});

test("own and delegated claims bind the live fixed beneficiary and simulate exact CALLs", async () => {
  const iface = await fixtureInterface(), expectedClaim = { collectionId: 7n, phaseId, beneficiary: beneficiaryA };
  const own = prepareOwnDistributionClaim(chainId, distributor, 42n, expectedClaim, receiver);
  const delegated = prepareDelegatedDistributionClaim(chainId, distributor, delegate, 42n, expectedClaim, true, 3n);
  assert.equal(own.caller.toLowerCase(), beneficiaryA); assert.equal(delegated.receiver.toLowerCase(), beneficiaryA); assert.equal(delegated.caller.toLowerCase(), delegate);
  let delivered = true;
  const provider = { getNetwork: async () => ({ chainId }), call: async tx => { assert.equal(tx.blockTag, 456); const parsed = iface.parseTransaction({ data: tx.data });
    if (parsed.name === "nftClaim") return iface.encodeFunctionResult(parsed.fragment, [[7n, phaseId, beneficiaryA]]);
    if (parsed.name === "claimNft" || parsed.name === "claimNftFor") return iface.encodeFunctionResult(parsed.fragment, [delivered]);
    throw new Error(`unexpected ${parsed.name}`); } };
  assert.equal((await inspectDistributionClaim(provider, delegated, { blockTag: 456 })).claim.receiver.toLowerCase(), beneficiaryA);
  assert.equal(await simulatePreparedDistributionClaim(provider, own, { blockTag: 456 }), true); delivered = false;
  assert.equal(await simulatePreparedDistributionClaim(provider, delegated, { blockTag: 456 }), false);
  await assert.rejects(inspectDistributionClaim(provider, { ...delegated, receiver }, { blockTag: 456 }), /canonical reconstruction/);
  await assert.rejects(inspectDistributionClaim({ ...provider, call: async tx => { const parsed = iface.parseTransaction({ data: tx.data }); return iface.encodeFunctionResult(parsed.fragment, [[7n, phaseId, beneficiaryB]]); } }, own, { blockTag: 456 }), /fixed beneficiary/);
});

test("manifest and claim builders reject coercion, oversized inputs and invented authority fields", () => {
  const a = artifact(); assert.doesNotThrow(() => verifyOperatorDistributionManifest(a));
  assert.throws(() => buildOperatorDistributionManifest({ context, collectionId: 7n, phaseId, operator, supplyCounterId, recipientCounterId, perRecipientCap: 3n, deliveryMode: 0n, prepared: "false", sliceQuantity: 2, tokens, manifestCompletenessReviewed: true }), /boolean/);
  assert.throws(() => operatorDistributionSliceHash(context, 0n, { collectionId: 7n, phaseId, beneficiaries: [beneficiaryA], tokenData: ["0x1"], mintCommitments: [h("x")] }), /hex bytes/);
  assert.throws(() => prepareDelegatedDistributionClaim(chainId, distributor, delegate, 42n, { collectionId: 7n, phaseId, beneficiary: beneficiaryA }, "false", 0n), /boolean/);
  assert.throws(() => operatorDistributionManifestFromJSON(" ".repeat(16_777_217)), /16 MiB/);
});
