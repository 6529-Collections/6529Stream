import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ZeroHash, id, keccak256 } from "ethers";
import * as mint from "../dist/current-mint-continuity.js";

// Encoding vectors derived independently from production commit 20cc16a9 and
// checked against the unchanged preimages in successor follow-up bba738e9.
// This does not establish inventory completeness, retirement or runtime admission.
const coder = AbiCoder.defaultAbiCoder();
const address = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const coordinates = { chainId: 31337n, successorLedger: address(1), predecessorLedger: address(2),
  predecessorManager: address(3), successorManager: address(4), snapshotBlock: 9007199254740993n };
const leafType = "tuple(uint256 collectionId,bytes32 phaseId,bytes32 counterId,uint8 keyMode,bytes32 subjectBasis,bytes32 predecessorSubjectKey,uint64 value)";
const definitionType = "tuple(uint8 scope,uint8 keyMode,bytes32 capRoot,bytes32 metadataHash)";
const double = encoded => keccak256(keccak256(encoded));
const subjectDomain = id("6529STREAM_MINT_COUNTER_SUBJECT_V1");
const padded = account => `0x${"0".repeat(24)}${account.slice(2)}`;
function subject(row, ledger = coordinates.predecessorLedger) {
  const prefixTypes = ["bytes32", "uint256", "address", "uint8"];
  const prefix = [subjectDomain, coordinates.chainId, ledger, row.keyMode];
  return row.keyMode === 1n
    ? keccak256(coder.encode([...prefixTypes, "uint256", "bytes32", "bytes32"], [...prefix, row.collectionId, row.phaseId, row.counterId]))
    : row.keyMode === 6n
      ? keccak256(coder.encode([...prefixTypes, "bytes32"], [...prefix, row.subjectBasis]))
      : keccak256(coder.encode([...prefixTypes, "address"], [...prefix, `0x${row.subjectBasis.slice(-40)}`]));
}
function makeLeaf(keyMode, overrides = {}) {
  const row = { collectionId: 9007199254740995n, phaseId: id("phase"), counterId: id("counter"), keyMode,
    subjectBasis: keyMode === 1n ? ZeroHash : keyMode === 6n ? id("context") : padded(address(7)),
    predecessorSubjectKey: ZeroHash, value: (1n << 64n) - 1n, ...overrides };
  row.predecessorSubjectKey = subject(row);
  return row;
}
function counterHash(row) {
  return double(coder.encode(["bytes32", "uint256", "address", "address", leafType],
    [id("6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1"), coordinates.chainId, coordinates.predecessorLedger, coordinates.predecessorManager, row]));
}
function nullifierHash(value) {
  return double(coder.encode(["bytes32", "uint256", "address", "address", "bytes32"],
    [id("6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1"), coordinates.chainId, coordinates.predecessorLedger, coordinates.predecessorManager, value]));
}
function descriptor(manifestHash, counterCount, nullifierCount) {
  return double(coder.encode(["bytes32", "uint256", "address", "address", "address", "address", "uint64", "bytes32", "uint64", "uint64"],
    [id("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"), coordinates.chainId, coordinates.successorLedger, coordinates.predecessorLedger,
      coordinates.predecessorManager, coordinates.successorManager, coordinates.snapshotBlock, manifestHash, counterCount, nullifierCount]));
}
function verifyProof(leaf, proof) {
  return proof.reduce((value, sibling) => keccak256(coder.encode(["bytes32", "bytes32"],
    BigInt(value) < BigInt(sibling) ? [value, sibling] : [sibling, value])), leaf);
}

test("counter definition and all retained subject modes match literal original domains", () => {
  const definition = { scope: 1n, keyMode: 2n, capRoot: id("cap root"), metadataHash: id("metadata") };
  assert.equal(mint.mintCounterDefinitionHash(definition), keccak256(coder.encode(
    ["bytes32", definitionType], [id("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition],
  )));
  assert.equal(mint.mintCounterSubjectBasis(address(7)), padded(address(7)));
  for (const mode of [1n, 2n, 3n, 4n, 5n, 6n]) {
    const row = makeLeaf(mode);
    assert.equal(mint.mintCounterSubjectKey(coordinates.chainId, coordinates.predecessorLedger, row), subject(row));
    assert.equal(mint.mintCounterSubjectKey(coordinates.chainId, coordinates.successorLedger, row), subject(row, coordinates.successorLedger));
    assert.notEqual(subject(row), subject(row, coordinates.successorLedger));
  }
  for (const row of [makeLeaf(1n, { collectionId: 0n, phaseId: ZeroHash }), makeLeaf(1n, { phaseId: ZeroHash })]) {
    assert.equal(mint.mintCounterSubjectKey(coordinates.chainId, coordinates.predecessorLedger, row), subject(row));
  }
});

test("counter, raw-nullifier and descriptor leaves retain the original double hash and exact widths", () => {
  const row = makeLeaf(2n), nullifier = id("raw nullifier"), manifest = id("manifest");
  assert.equal(mint.mintCounterImportLeafHash(coordinates, row), counterHash(row));
  assert.equal(mint.mintNullifierImportLeafHash(coordinates, nullifier), nullifierHash(nullifier));
  assert.equal(mint.mintImportDescriptorLeaf(coordinates, manifest, 1n, 1n), descriptor(manifest, 1n, 1n));
  assert.notEqual(mint.mintCounterImportLeafHash(coordinates, { ...row, value: row.value - 1n }), counterHash(row));
  assert.notEqual(mint.mintImportDescriptorLeaf(coordinates, manifest, 1n, 2n), descriptor(manifest, 1n, 1n));
  assert.throws(() => mint.mintCounterImportLeafHash(coordinates, { ...row, predecessorSubjectKey: id("other subject") }));
  assert.throws(() => mint.mintCounterImportLeafHash(coordinates, { ...row, value: 1n << 64n }));
});

test("governed commitment uses class-1 scope, zero old hash and exact predecessor/successor pair", () => {
  const importRoot = id("root"), manifestHash = id("manifest");
  const scope = keccak256(coder.encode(["bytes32", "uint256", "address", "address"],
    [id("6529STREAM_MINT_IMPORT_SCOPE_V1"), coordinates.chainId, coordinates.successorLedger, coordinates.successorManager]));
  const newHash = keccak256(coder.encode(["bytes32", "bytes32", "address", "address", "address", "uint64", "bytes32", "bytes32"],
    [id("6529STREAM_MINT_IMPORT_COMMITMENT_V1"), scope, coordinates.predecessorLedger, coordinates.predecessorManager,
      coordinates.successorManager, coordinates.snapshotBlock, importRoot, manifestHash]));
  assert.deepEqual(mint.mintImportGovernanceTransition({ ...coordinates, importRoot, manifestHash }), { scope, oldHash: ZeroHash, newHash });
  assert.notEqual(mint.mintImportGovernanceTransition({ ...coordinates, importRoot, manifestHash, snapshotBlock: coordinates.snapshotBlock + 1n }).newHash, newHash);
});

test("every produced proof independently verifies, including the mandatory descriptor and odd tree layers", () => {
  const rows = [makeLeaf(1n), makeLeaf(2n), makeLeaf(6n)], nullifiers = [id("raw A"), id("raw B"), id("raw C")];
  const artifact = mint.buildMintContinuityArtifact({ coordinates, counterLeaves: rows, nullifiers, inventoryCompletenessReviewed: true });
  assert.equal(keccak256(artifact.manifestBytes), artifact.manifestHash);
  artifact.counterLeaves.forEach((row, i) => {
    assert.equal(artifact.counterLeafHashes[i], counterHash(row));
    assert.equal(verifyProof(counterHash(row), artifact.counterProofs[i]), artifact.importRoot);
  });
  artifact.nullifiers.forEach((value, i) => {
    assert.equal(artifact.nullifierLeafHashes[i], nullifierHash(value));
    assert.equal(verifyProof(nullifierHash(value), artifact.nullifierProofs[i]), artifact.importRoot);
  });
  assert.equal(artifact.descriptorLeaf, descriptor(artifact.manifestHash, 3n, 3n));
  assert.equal(verifyProof(artifact.descriptorLeaf, artifact.descriptorProof), artifact.importRoot);
  const sameInput = mint.buildMintContinuityArtifact({ coordinates, counterLeaves: [...rows].reverse(), nullifiers: [...nullifiers].reverse(), inventoryCompletenessReviewed: true });
  assert.equal(sameInput.manifestHash, artifact.manifestHash);
  assert.equal(sameInput.importRoot, artifact.importRoot);
  assert.deepEqual(mint.mintContinuityArtifactFromJSON(mint.mintContinuityArtifactToJSON(artifact)), artifact);
});

test("same-Ledger succession remains supported while duplicate leaves and unreviewed completeness fail", () => {
  const row = makeLeaf(2n), shared = { ...coordinates, successorLedger: coordinates.predecessorLedger };
  const artifact = mint.buildMintContinuityArtifact({ coordinates: shared, counterLeaves: [row], nullifiers: [], inventoryCompletenessReviewed: true });
  assert.equal(verifyProof(artifact.counterLeafHashes[0], artifact.counterProofs[0]), artifact.importRoot);
  assert.throws(() => mint.buildMintContinuityArtifact({ coordinates, counterLeaves: [row, { ...row, value: row.value - 1n }], nullifiers: [], inventoryCompletenessReviewed: true }));
  assert.throws(() => mint.buildMintContinuityArtifact({ coordinates, counterLeaves: [row], nullifiers: [id("same"), id("same")], inventoryCompletenessReviewed: true }));
  assert.throws(() => mint.buildMintContinuityArtifact({ coordinates, counterLeaves: [row], nullifiers: [], inventoryCompletenessReviewed: false }));
});

test("continuity calls retain exact ancestry selector, owner batch wrapper and descriptor counts", () => {
  const artifact = mint.buildMintContinuityArtifact({ coordinates, counterLeaves: [makeLeaf(1n), makeLeaf(2n)],
    nullifiers: [id("raw A"), id("raw B")], inventoryCompletenessReviewed: true });
  const iface = new Interface(["function importMintState(bytes)", "function importMintAncestors(bytes32,uint256)",
    "function completeCounterImport(bytes32,uint64,uint64,bytes32[])"]);
  const row = artifact.counterLeaves[1], raw = artifact.nullifiers[0];
  const payload = coder.encode([`tuple(bytes32 importRoot,${leafType}[] counters,bytes32[][] counterProofs,bytes32[] nullifiers,bytes32[][] nullifierProofs)`],
    [{ importRoot: artifact.importRoot, counters: [row], counterProofs: [artifact.counterProofs[1]],
      nullifiers: [raw], nullifierProofs: [artifact.nullifierProofs[0]] }]);
  const owner = address(10), prepared = mint.prepareMintStateImport(artifact, owner, [1], [0]);
  assert.equal(prepared.caller.toLowerCase(), owner.toLowerCase());
  assert.deepEqual(prepared.call, { to: coordinates.successorManager, value: 0n,
    data: iface.encodeFunctionData("importMintState", [payload]) });
  assert.deepEqual(mint.prepareMintAncestryImport(artifact, 32n).call, { to: coordinates.successorLedger, value: 0n,
    data: iface.encodeFunctionData("importMintAncestors", [artifact.importRoot, 32n]) });
  assert.deepEqual(mint.prepareMintImportCompletion(artifact).call, { to: coordinates.successorLedger, value: 0n,
    data: iface.encodeFunctionData("completeCounterImport", [artifact.importRoot, 2n, 2n, artifact.descriptorProof]) });
  assert.throws(() => mint.prepareMintAncestryImport(artifact, 33n));
});
