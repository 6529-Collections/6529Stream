import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { AbiCoder, Interface, id, keccak256, toUtf8Bytes } from "ethers";
import {
  buildMintContinuityArtifact, inspectCounterDefinitionSelection, inspectMintContinuityReadiness, inspectMintContinuitySourceInventory,
  mintContinuityArtifactFromJSON, mintContinuityArtifactToJSON, mintCounterDefinitionHash,
  mintCounterImportLeafHash, mintCounterSubjectBasis, mintCounterSubjectKey,
  mintImportDescriptorLeaf, mintImportGovernanceTransition, mintNullifierImportLeafHash,
  prepareCounterDefinitionImport, prepareCounterDefinitionRegistration, prepareMintImportCommit,
  prepareMintAncestryImport, prepareMintImportCompletion, prepareMintStateImport, verifyMintContinuityArtifact,
} from "../dist/current-mint-continuity.js";

const coder = AbiCoder.defaultAbiCoder(), chainId = 31337n;
const predecessorLedger = "0x1000000000000000000000000000000000000001", successorLedger = "0x2000000000000000000000000000000000000002";
const predecessorManager = "0x3000000000000000000000000000000000000003", successorManager = "0x4000000000000000000000000000000000000004";
const owner = "0x5000000000000000000000000000000000000005", core = "0x6000000000000000000000000000000000000006";
const h = x => keccak256(toUtf8Bytes(x)), zero = `0x${"00".repeat(32)}`;
const coordinates = { chainId, successorLedger, predecessorLedger, predecessorManager, successorManager, snapshotBlock: 900n };
const definition = { scope: 1n, keyMode: 2n, capRoot: h("cap"), metadataHash: h("metadata") };
function leaf(label = "A", overrides = {}) {
  const base = { collectionId: 7n, phaseId: zero, counterId: h(`counter-${label}`), keyMode: 2n, subjectBasis: mintCounterSubjectBasis(owner), predecessorSubjectKey: h("placeholder"), value: 12n, ...overrides };
  return { ...base, predecessorSubjectKey: mintCounterSubjectKey(chainId, predecessorLedger, base) };
}
const counters = [leaf("A"), leaf("B", { keyMode: 1n, subjectBasis: zero })], nullifiers = [h("raw-nullifier-A"), h("raw-nullifier-B")];
const artifact = () => buildMintContinuityArtifact({ coordinates, counterLeaves: counters, nullifiers, inventoryCompletenessReviewed: true });

test("compiler fixture is reproducible and contains exact selected callable shapes", async () => {
  const f = JSON.parse(await readFile(new URL("./fixtures/current-mint-continuity-abi.json", import.meta.url)));
  assert.equal(f.sourceCommit, "bba738e9a9af3f12fdccd2e9cbc825aa555adb08"); assert.equal(f.sourceTree, "236b9e7c52de9701177394f302925788a2bbb695"); assert.equal(f.sourceCount, 130);
  assert.equal(f.provenance.compilerInputSha256, "b2e12eef016901d44188ced46c02fd5893a0554c65dc1cc061c6c9445b6d79ac"); assert.equal(f.provenance.compilerOutputSha256, "736b7dd4955030afb89d3cc9feef1b8eddefc7fbe5d00f905b043b9b07782b59");
  for (const c of f.contracts) { const i = new Interface(c.abi); assert.deepEqual(c.abi.filter(x => x.type === "function").map(x => x.name).sort(), [...c.methods].sort()); for (const name of c.methods) assert.ok(i.getFunction(name).selector); }
});

test("definition hash and registration preserve complete profile preimage", () => {
  const expected = keccak256(coder.encode(["bytes32", "tuple(uint8 scope,uint8 keyMode,bytes32 capRoot,bytes32 metadataHash)"], [id("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition]));
  assert.equal(mintCounterDefinitionHash(definition), expected); const prepared = prepareCounterDefinitionRegistration(successorLedger, definition); assert.equal(prepared.caller, null); assert.equal(prepared.call.value, 0n);
  assert.throws(() => mintCounterDefinitionHash({ ...definition, keyMode: 5n }), /Unsupported/); assert.throws(() => mintCounterDefinitionHash({ ...definition, scope: 0n }), /Unsupported/);
});

test("subject and double-hashed counter/nullifier leaves match literal source preimages", () => {
  const x = counters[0], subject = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "address"], [id("6529STREAM_MINT_COUNTER_SUBJECT_V1"), chainId, predecessorLedger, 2n, owner])); assert.equal(x.predecessorSubjectKey, subject);
  const inner = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "tuple(uint256 collectionId,bytes32 phaseId,bytes32 counterId,uint8 keyMode,bytes32 subjectBasis,bytes32 predecessorSubjectKey,uint64 value)"], [id("6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1"), chainId, predecessorLedger, predecessorManager, x])); assert.equal(mintCounterImportLeafHash(coordinates, x), keccak256(inner));
  const n = nullifiers[0], ni = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32"], [id("6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1"), chainId, predecessorLedger, predecessorManager, n])); assert.equal(mintNullifierImportLeafHash(coordinates, n), keccak256(ni));
});

test("canonical artifact returns manifest bytes, sorted tree, exact descriptor and restart verification", () => {
  const a = artifact(); assert.equal(keccak256(a.manifestBytes), a.manifestHash); assert.equal(a.descriptorLeaf, mintImportDescriptorLeaf(coordinates, a.manifestHash, 2n, 2n));
  const fold = (leaf, proof) => proof.reduce((v, s) => keccak256(coder.encode(["bytes32", "bytes32"], BigInt(v) < BigInt(s) ? [v, s] : [s, v])), leaf);
  a.counterLeafHashes.forEach((x, i) => assert.equal(fold(x, a.counterProofs[i]), a.importRoot)); a.nullifierLeafHashes.forEach((x, i) => assert.equal(fold(x, a.nullifierProofs[i]), a.importRoot)); assert.equal(fold(a.descriptorLeaf, a.descriptorProof), a.importRoot);
  assert.deepEqual(mintContinuityArtifactFromJSON(mintContinuityArtifactToJSON(a)), a); assert.throws(() => mintContinuityArtifactFromJSON(mintContinuityArtifactToJSON({ ...a, importRoot: h("tampered") })), /canonical reconstruction/);
});

test("artifact requires explicit human completeness assertion and rejects impossible duplicates", () => {
  assert.throws(() => buildMintContinuityArtifact({ coordinates, counterLeaves: counters, nullifiers, inventoryCompletenessReviewed: false }), /explicitly attest/);
  assert.throws(() => buildMintContinuityArtifact({ coordinates, counterLeaves: [counters[0], { ...counters[0], value: 13n }], nullifiers, inventoryCompletenessReviewed: true }), /Duplicate counter/);
  assert.throws(() => buildMintContinuityArtifact({ coordinates, counterLeaves: counters, nullifiers: [nullifiers[0], nullifiers[0]], inventoryCompletenessReviewed: true }), /Duplicate raw/);
  assert.throws(() => mintCounterImportLeafHash(coordinates, { ...counters[0], predecessorSubjectKey: h("wrong") }), /canonical predecessor/);
  assert.throws(() => buildMintContinuityArtifact({ coordinates, counterLeaves: [], nullifiers: Array(4097).fill(h("bounded")), inventoryCompletenessReviewed: true }), /4096 combined/);
  assert.throws(() => mintContinuityArtifactFromJSON(" ".repeat(16_777_217)), /16 MiB/);
});

test("same-Ledger continuity is supported while identical Managers are rejected", () => {
  const same = { ...coordinates, successorLedger: predecessorLedger }; assert.doesNotThrow(() => buildMintContinuityArtifact({ coordinates: same, counterLeaves: [leaf()], nullifiers: [], inventoryCompletenessReviewed: true }));
  assert.throws(() => buildMintContinuityArtifact({ coordinates: { ...coordinates, successorManager: predecessorManager }, counterLeaves: [], nullifiers: [], inventoryCompletenessReviewed: true }), /Managers must differ/);
});

test("governed commitment exposes exact class-1 transition without ordinary Safe caller claim", () => {
  const a = artifact(), prepared = prepareMintImportCommit(a), expected = mintImportGovernanceTransition({ ...coordinates, importRoot: a.importRoot, manifestHash: a.manifestHash });
  assert.equal(prepared.governed, true); assert.equal(prepared.actionClass, 1); assert.deepEqual({ scope: prepared.scope, oldHash: prepared.oldHash, newHash: prepared.newHash }, expected); assert.match(prepared.executionBoundary, /not an ordinary/); assert.equal(prepared.targetCall.to, successorLedger);
});

test("definition and ancestry copies, explicit owner batches and completion have bounded exact calls", () => {
  const a = artifact(); assert.equal(prepareCounterDefinitionImport(a, 32n).caller, null); assert.throws(() => prepareCounterDefinitionImport(a, 0n), /1 through 32/);
  const ancestry = prepareMintAncestryImport(a, 32n); assert.equal(ancestry.caller, null); assert.equal(ancestry.call.to, successorLedger); assert.throws(() => prepareMintAncestryImport(a, 33n), /1 through 32/);
  const one = prepareMintStateImport(a, owner, [0], [1]); assert.equal(one.caller, owner); assert.equal(one.call.to, successorManager); assert.equal(one.call.value, 0n);
  assert.throws(() => prepareMintStateImport(a, owner, [0, 0], []), /duplicate counter/); assert.throws(() => prepareMintStateImport(a, owner, [], []), /1 through 32/);
  const complete = prepareMintImportCompletion(a); assert.equal(complete.caller, null); assert.match(complete.intent, /exact reviewed/);
  const fixtureSelectors = [prepareCounterDefinitionImport(a, 1n).call.data.slice(0, 10), ancestry.call.data.slice(0, 10), one.call.data.slice(0, 10), complete.call.data.slice(0, 10)]; assert.equal(new Set(fixtureSelectors).size, 4);
});

test("synthetic effective selection distinguishes registered from permanently legacy first use", async () => {
  const f = JSON.parse(await readFile(new URL("./fixtures/current-mint-continuity-abi.json", import.meta.url))), iface = new Interface(f.contracts.flatMap(x => x.abi));
  const provider = mode => ({ call: async tx => { assert.equal(tx.blockTag, 123); const p = iface.parseTransaction({ data: tx.data }); if (p.name === "counterDefinition") return iface.encodeFunctionResult(p.fragment, [true, definition]); if (p.name === "counterDefinitionForManager") return iface.encodeFunctionResult(p.fragment, mode === "registered" ? [true, definition] : [false, { scope: 2n, keyMode: 0n, capRoot: zero, metadataHash: zero }]); throw Error("unexpected"); } });
  assert.equal((await inspectCounterDefinitionSelection(provider("registered"), successorLedger, successorManager, definition, { blockTag: 123, expectedInterpretation: "defined" })).managerExists, true);
  assert.equal((await inspectCounterDefinitionSelection(provider("legacy"), successorLedger, successorManager, definition, { blockTag: 123, expectedInterpretation: "legacy" })).managerExists, false);
});

test("bounded source inventory reads verify values and raw nullifiers without claiming completeness", async () => {
  const a = artifact(), f = JSON.parse(await readFile(new URL("./fixtures/current-mint-continuity-abi.json", import.meta.url))), iface = new Interface(f.contracts.flatMap(x => x.abi)); let currentValue = 0n;
  const provider = { getNetwork: async () => ({ chainId }), call: async tx => { assert.equal(tx.blockTag, 900); const p = iface.parseTransaction({ data: tx.data }); if (p.name === "deriveCounterValueKey") { const index = a.counterLeaves.findIndex(x => x.counterId === p.args[3]); currentValue = a.counterLeaves[index].value; return iface.encodeFunctionResult(p.fragment, [h(`value-key-${index}`)]); } if (p.name === "counterValue") return iface.encodeFunctionResult(p.fragment, [currentValue]); if (p.name === "isManagerNullifierUsed") return iface.encodeFunctionResult(p.fragment, [true]); throw Error("unexpected"); } };
  const inspected = await inspectMintContinuitySourceInventory(provider, a, [0, 1], [0, 1], { blockTag: 900 }); assert.equal(inspected.completenessProven, false); assert.equal(inspected.counterLeafHashes.length, 2);
  await assert.rejects(inspectMintContinuitySourceInventory(provider, a, [0], [], { blockTag: 901 }), /exact reviewed snapshot/);
});

test("source inspection snapshots caller index arrays before any asynchronous RPC", async () => {
  const a = artifact(), f = JSON.parse(await readFile(new URL("./fixtures/current-mint-continuity-abi.json", import.meta.url))), iface = new Interface(f.contracts.flatMap(x => x.abi));
  let release; const gate = new Promise(resolve => { release = resolve; }), indexes = [0];
  const provider = { getNetwork: async () => { await gate; return { chainId }; }, call: async tx => { const p = iface.parseTransaction({ data: tx.data }); if (p.name === "deriveCounterValueKey") return iface.encodeFunctionResult(p.fragment, [h("value-key")]); if (p.name === "counterValue") return iface.encodeFunctionResult(p.fragment, [a.counterLeaves[0].value]); throw Error("unexpected"); } };
  const pending = inspectMintContinuitySourceInventory(provider, a, indexes, [], { blockTag: 900 }); indexes[0] = 1; indexes.push(1); release(); const result = await pending;
  assert.deepEqual(result.counterLeafHashes, [a.counterLeafHashes[0]]);
});

test("synthetic readiness binds exact pair, retirement, owners, Core and profile progress", async () => {
  const a = artifact(), f = JSON.parse(await readFile(new URL("./fixtures/current-mint-continuity-abi.json", import.meta.url))), iface = new Interface(f.contracts.flatMap(x => x.abi));
  const commitment = { predecessorLedger, predecessorManager, successorManager, snapshotBlock: 900n, manifestHash: a.manifestHash, importedCounters: 2n, importedNullifiers: 2n, complete: true };
  let ancestryProgress = [2n, 2n], descendant = true;
  const provider = { getNetwork: async () => ({ chainId }), call: async tx => { assert.equal(tx.blockTag, 1000); const p = iface.parseTransaction({ data: tx.data }); switch (p.name) {
    case "mintImportCommitment": return iface.encodeFunctionResult(p.fragment, [commitment]); case "mintImportDefinitionProgress": return iface.encodeFunctionResult(p.fragment, [3n, 3n]);
    case "mintImportAncestryProgress": return iface.encodeFunctionResult(p.fragment, ancestryProgress); case "isCompletedMintDescendant": return iface.encodeFunctionResult(p.fragment, [descendant]);
    case "ledgerWriterRetiredAt": return iface.encodeFunctionResult(p.fragment, [899n]); case "ledgerWriter": return iface.encodeFunctionResult(p.fragment, [tx.to.toLowerCase() === successorLedger.toLowerCase()]); case "isMintSuccessorReady": return iface.encodeFunctionResult(p.fragment, [true]);
    case "owner": return iface.encodeFunctionResult(p.fragment, [owner]); case "governanceAuthority": return iface.encodeFunctionResult(p.fragment, [owner]); case "mintLedger": return iface.encodeFunctionResult(p.fragment, [tx.to.toLowerCase() === predecessorManager.toLowerCase() ? predecessorLedger : successorLedger]); case "core": return iface.encodeFunctionResult(p.fragment, [core]); default: throw Error(`unexpected ${p.name}`);
  } } };
  const result = await inspectMintContinuityReadiness(provider, a, { successorLedgerOwner: owner, successorManagerOwner: owner }, { blockTag: 1000 }); assert.equal(result.ready, true); assert.deepEqual(result.definitionProgress, { imported: 3n, required: 3n }); assert.deepEqual(result.ancestryProgress, { imported: 2n, required: 2n }); assert.equal(result.exactDescendant, true); assert.match(result.limitations.join(" "), /completeness/);
  ancestryProgress = [1n, 2n]; await assert.rejects(inspectMintContinuityReadiness(provider, a, { successorLedgerOwner: owner, successorManagerOwner: owner }, { blockTag: 1000 }), /ancestry progress/);
  ancestryProgress = [2n, 2n]; descendant = false; await assert.rejects(inspectMintContinuityReadiness(provider, a, { successorLedgerOwner: owner, successorManagerOwner: owner }, { blockTag: 1000 }), /ready\/descendant state/);
});

test("readiness snapshots expected owners before asynchronous RPC", async () => {
  const a = artifact(), f = JSON.parse(await readFile(new URL("./fixtures/current-mint-continuity-abi.json", import.meta.url))), iface = new Interface(f.contracts.flatMap(x => x.abi));
  const commitment = { predecessorLedger, predecessorManager, successorManager, snapshotBlock: 900n, manifestHash: a.manifestHash, importedCounters: 2n, importedNullifiers: 2n, complete: true };
  let release; const gate = new Promise(resolve => { release = resolve; }); const expected = { successorLedgerOwner: owner, successorManagerOwner: owner };
  const provider = { getNetwork: async () => { await gate; return { chainId }; }, call: async tx => { const p = iface.parseTransaction({ data: tx.data }); switch (p.name) {
    case "mintImportCommitment": return iface.encodeFunctionResult(p.fragment, [commitment]); case "mintImportDefinitionProgress": return iface.encodeFunctionResult(p.fragment, [1n, 1n]); case "mintImportAncestryProgress": return iface.encodeFunctionResult(p.fragment, [0n, 0n]);
    case "ledgerWriterRetiredAt": return iface.encodeFunctionResult(p.fragment, [900n]); case "ledgerWriter": return iface.encodeFunctionResult(p.fragment, [tx.to.toLowerCase() === successorLedger.toLowerCase()]); case "isMintSuccessorReady": case "isCompletedMintDescendant": return iface.encodeFunctionResult(p.fragment, [true]);
    case "owner": case "governanceAuthority": return iface.encodeFunctionResult(p.fragment, [owner]); case "mintLedger": return iface.encodeFunctionResult(p.fragment, [tx.to.toLowerCase() === predecessorManager.toLowerCase() ? predecessorLedger : successorLedger]); case "core": return iface.encodeFunctionResult(p.fragment, [core]); default: throw Error(`unexpected ${p.name}`);
  } } };
  const pending = inspectMintContinuityReadiness(provider, a, expected, { blockTag: 1000 }); expected.successorLedgerOwner = successorLedger; expected.successorManagerOwner = successorManager; release();
  assert.equal((await pending).ready, true);
});

test("manifest and calls never expose retirement or Core activation selectors", () => {
  const a = verifyMintContinuityArtifact(artifact()), calls = [prepareCounterDefinitionRegistration(successorLedger, definition).call, prepareMintImportCommit(a).targetCall, prepareCounterDefinitionImport(a, 1n).call, prepareMintAncestryImport(a, 1n).call, prepareMintStateImport(a, owner, [0], []).call, prepareMintImportCompletion(a).call];
  const forbidden = [new Interface(["function retireLedgerWriter(address)"]).getFunction("retireLedgerWriter").selector, new Interface(["function setSatellitePointer(bytes32,address)"]).getFunction("setSatellitePointer").selector]; assert.ok(calls.every(x => !forbidden.includes(x.data.slice(0, 10))));
});
