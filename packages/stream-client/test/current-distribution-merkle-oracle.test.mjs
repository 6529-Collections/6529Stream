import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import { AbiCoder, FunctionFragment, Interface, getAddress, id, keccak256 } from "ethers";
import ts from "typescript";
import { fixture, compiledInterfaces as compiled } from "./current-distribution-merkle-fixture.mjs";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { operatorDistributionProgramHash, operatorDistributionSliceHash, operatorDistributionSliceAuthorization } from "../dist/current-distribution.js";
import { mintCounterAllowlistLeaf } from "../dist/current-mint-counter-reads.js";
import * as merkle from "../dist/current-distribution-merkle.js";

const sha = value => createHash("sha256").update(value).digest("hex");
const coder = AbiCoder.defaultAbiCoder();
const hash = (types, values) => keccak256(coder.encode(types, values));
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const source = path => fixture.sourceTexts[`smart-contracts/${path}.sol`];

test("ABI117 retains its committed all-source bridge and separate runtime qualification", () => {
  assert.equal(fixture.sourceCommit, "5d1756eb53a28ebc5ecd24513493ce6bfe7ef62f");
  assert.equal(fixture.sourceTree, "b0d30c650c1e55d3b213a3e0159dcb54d0a17c42");
  assert.equal(fixture.compilerReportedCommit, "c686a29f4ba6031cccfe8fd60a0b0aef296aa85a");
  assert.equal(fixture.sourceCount, 3000);
  assert.equal(fixture.literalBytes, 35_100_884);
  assert.equal(fixture.inputSha256, "d922340003209b74572b9f047c68143400d96a7b8bf2f0dc6466cc071ba3f970");
  assert.equal(fixture.outputSha256, "b6d298b26e2f0c004f7f7193f679f115093d71705ff777108b7f5cc7a9dafcc7");
  assert.equal(fixture.committedSourceBridge.sourceCommit, fixture.sourceCommit);
  assert.equal(fixture.committedSourceBridge.sources, 3000);
  assert.equal(fixture.committedSourceBridge.inputSHA256, fixture.inputSha256);
  assert.deepEqual(fixture.committedSourceBridge.mismatches, []);
  assert.equal(fixture.committedSourceBridge.sha256, "e0ff406d3dfb43e2048b9e09ac3576ece23071a1eb832c0a9da4051d81fa7738");
  assert.match(fixture.sourceBinding, /byte-for-byte/);
  assert.match(fixture.qualification, /actual Manager-selected recipient definition/);
  assert.match(fixture.qualification, /native execution.*full rollback proofs.*separately qualified/);
});

test("all 34 complete ABIs preserve 763 original compiler method identifiers", () => {
  assert.equal(Object.keys(fixture.abis).length, 34);
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 1449);
  let count = 0;
  for (const [key, abi] of Object.entries(fixture.abis)) {
    assert.equal(fixture.selections[key].full, true);
    const functions = abi.filter(x => x.type === "function");
    assert.equal(functions.length, Object.keys(fixture.methodIdentifiers[key]).length);
    for (const entry of functions) {
      const fragment = FunctionFragment.from(entry), signature = fragment.format("sighash");
      assert.equal(fixture.methodIdentifiers[key][signature], id(signature).slice(2, 10), `${key}/${signature}`);
      assert.equal(compiled[key].getFunction(signature).format("full"), fragment.format("full"));
      count++;
    }
  }
  assert.equal(count, 763);
});

test("selected source closure and seven original documents are complete and byte-hashed", () => {
  const visited = new Set();
  function visit(path) {
    if (visited.has(path)) return;
    const text = fixture.sourceTexts[path];
    assert.equal(typeof text, "string", path);
    assert.equal(sha(text), fixture.sourceHashes[path], path);
    visited.add(path);
    for (const dependency of solidityImports(text)) visit(dependency.startsWith(".")
      ? posix.normalize(posix.join(posix.dirname(path), dependency)) : dependency);
  }
  for (const selection of Object.values(fixture.selections)) visit(selection.source);
  assert.equal(visited.size, 296);
  assert.deepEqual([...visited].sort(), Object.keys(fixture.sourceTexts).sort());
  assert.deepEqual(Object.keys(fixture.sourceHashes), Object.keys(fixture.sourceTexts));
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, text) => n + Buffer.byteLength(text), 0), 1_859_591);
  assert.equal(Object.keys(fixture.documents).length, 7);
  for (const [path, document] of Object.entries(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256, path);
    assert.equal(Buffer.byteLength(document.text), document.byteLength, path);
  }
});

test("the additive interface preserves original STATIC methods and the eight-field Program", () => {
  const old = JSON.parse(readFileSync(new URL("./fixtures/current-distribution-abi.json", import.meta.url), "utf8"));
  assert.equal(old.compilerCommit, "57d70b58209a1c7f54cfbf6715967489fef28c31");
  assert.equal(old.sourceCount, 1014);
  for (const contract of old.contracts) for (const entry of contract.abi) {
    const fragment = FunctionFragment.from(entry), signature = fragment.format("sighash");
    const candidates = Object.values(compiled).map(abi => abi.getFunction(signature)).filter(Boolean);
    assert.ok(candidates.some(current => current.format("minimal") === fragment.format("minimal")), signature);
  }
  const ifaceId = iface => `0x${iface.fragments.filter(x => x.type === "function")
    .reduce((v, f) => v ^ BigInt(f.selector), 0n).toString(16).padStart(8, "0")}`;
  assert.equal(ifaceId(compiled.distributionInterface), "0xe1ceb09a");
  assert.equal(ifaceId(compiled.merkleInterface), "0x9f2d3027");
  const merkle = compiled.merkleInterface.getFunction("merkleProgramHash");
  assert.equal(merkle.selector, "0x9f2d3027");
  assert.equal(merkle.stateMutability, "view");
  assert.deepEqual(merkle.inputs[2].components.map(p => [p.name, p.type]), [
    ["operator", "address"], ["slicesRoot", "bytes32"], ["supplyCounterId", "bytes32"], ["recipientCounterId", "bytes32"],
    ["totalQuantity", "uint64"], ["perRecipientCap", "uint64"], ["deliveryMode", "uint8"], ["prepared", "bool"],
  ]);
  const writes = fixture.abis.distributor.filter(x => x.type === "function" && !["pure", "view"].includes(x.stateMutability));
  assert.deepEqual(writes.map(x => [x.name, x.stateMutability]).sort(), [
    ["claimNft", "nonpayable"], ["claimNftFor", "nonpayable"], ["distribute", "payable"], ["raiseGasParameter", "nonpayable"],
  ]);
});

test("preserved STATIC hashes match compiler-owned Program and original dynamic array preimages", () => {
  const context = { chainId: (1n << 200n) + 6529n, distributor: address(1), core: address(2), manager: address(3) };
  const collection = (1n << 128n) + 5n, phase = id("distribution phase"), index = 2n;
  const program = { operator: address(4), slicesRoot: id("slices"), supplyCounterId: id("supply"),
    recipientCounterId: id("recipient"), totalQuantity: 5n, perRecipientCap: 4n, deliveryMode: 1n, prepared: true };
  const original = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32",
    compiled.distributor.getFunction("programHash").inputs[2]], [id("6529STREAM_OPERATOR_DISTRIBUTION_CONFIG_V1"),
    context.chainId, context.distributor, context.core, context.manager, collection, phase, program]);
  assert.equal(operatorDistributionProgramHash(context, collection, phase, program), original);
  const input = { collectionId: collection, phaseId: phase, beneficiaries: [address(8), address(8), address(9)],
    tokenData: ["0x000100", "0x", "0xffff00"], mintCommitments: [id("a"), id("b"), id("c")] };
  const slice = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "uint256", "address[]", "bytes[]", "bytes32[]"],
    [id("6529STREAM_OPERATOR_DISTRIBUTION_SLICE_V1"), context.chainId, context.distributor, context.core, context.manager,
      collection, phase, index, input.beneficiaries, input.tokenData, input.mintCommitments]);
  assert.equal(operatorDistributionSliceHash(context, index, input), slice);
  assert.notEqual(operatorDistributionSliceHash(context, index + 1n, input), slice);
  const authorization = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_OPERATOR_DISTRIBUTION_AUTHORIZATION_V1"), context.chainId, context.distributor, context.core, context.manager, collection, phase, index]);
  assert.equal(operatorDistributionSliceAuthorization(context, collection, phase, index), authorization);
});

test("reused allowlist helper retains original double hashing and all domain fields", () => {
  const binding = { chainId: 6529n, manager: address(30), ledger: address(31) };
  const collection = 19n, phase = id("phase"), counter = id("counter"), account = address(32);
  const proof = { maxCount: 7n, hasPriceOverride: false, priceOverride: 0n, proof: [] };
  const inner = hash(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256"],
    [id("6529STREAM_MINT_ALLOWLIST_LEAF_V1"), binding.chainId, binding.manager, collection, phase, counter, account, 7n, false, 0n]);
  assert.equal(mintCounterAllowlistLeaf(binding, collection, phase, counter, account, proof), keccak256(inner));
  assert.notEqual(inner, keccak256(inner));
  assert.notEqual(mintCounterAllowlistLeaf(binding, collection, phase, counter, account, { ...proof, maxCount: 8n }), keccak256(inner));
  assert.notEqual(mintCounterAllowlistLeaf(binding, collection, phase, counter, address(33), proof), keccak256(inner));
  assert.notEqual(mintCounterAllowlistLeaf({ ...binding, manager: address(34) }, collection, phase, counter, account, proof), keccak256(inner));
  assert.equal(mintCounterAllowlistLeaf({ ...binding, ledger: address(35) }, collection, phase, counter, account, proof), keccak256(inner));
  const original = source("domains/mint/StreamMintCounterPolicy");
  assert.match(original, /6529STREAM_MINT_ALLOWLIST_LEAF_V1/);
  assert.match(original, /bytes\.concat\(/);
});

test("source retains actual-Manager publication binding and original local claim semantics", () => {
  const original = source("domains/mint/StreamOperatorDistribution");
  assert.match(original, /counterDefinitionForManager\(address\(manager\), recipientCounterConfigHash\)/);
  assert.match(original, /MERKLE_PROGRAM_DOMAIN,[\s\S]*?programHash\(collectionId, phaseId, p\),[\s\S]*?recipientCounterConfigHash,[\s\S]*?definition\.metadataHash/);
  assert.match(original, /definition\.scope == IStreamMintCounterPolicy\.CounterScope\.GLOBAL/);
  assert.match(original, /definition\.capRoot == 0 \|\| definition\.metadataHash == 0/);
  assert.match(original, /if \(!_deliver\(tokenId, receiver\)\) \{\s*_claims\[tokenId\] = claim;\s*return false;/);
  const delegation = source("domains/auctions/StreamNativeAuctionDelegation");
  assert.match(delegation, /if \(caller == account\)/);
  assert.match(original, /claimRecipient\([\s\S]*?beneficiary,[\s\S]*?msg\.sender,[\s\S]*?beneficiary,/);
  assert.equal(compiled.distributor.getFunction("claimNft").outputs[0].type, "bool");
  assert.equal(compiled.distributor.getFunction("claimNftFor").outputs[0].type, "bool");
});

test("exported Merkle operational ABI preserves compiler mutability and full tuple fields", () => {
  for (const fragment of new Interface(merkle.CURRENT_DISTRIBUTION_MERKLE_ABI).fragments) {
    const original = compiled.distributor.getFunction(fragment.format("sighash"));
    assert.ok(original);
    assert.equal(fragment.format("minimal"), original.format("minimal"));
    function fields(actual, expected, tuple = false) {
      assert.equal(actual.length, expected.length);
      for (let i = 0; i < expected.length; i++) {
        const a = actual[i], e = expected[i];
        if (tuple) assert.equal(a.name, e.name);
        if (e.baseType === "array") fields([a.arrayChildren], [e.arrayChildren]);
        if (e.baseType === "tuple") fields(a.components, e.components, true);
      }
    }
    fields(fragment.inputs, original.inputs);
    fields(fragment.outputs, original.outputs);
  }
});

test("literal MPA-MERKLE.7 preimage binds the full selected definition and publication independently of root", () => {
  const context = { chainId: (1n << 128n) + 6529n, distributor: address(61), core: address(62), manager: address(63) };
  const collection = 31n, phase = id("published phase");
  const program = { operator: address(64), slicesRoot: id("slices"), supplyCounterId: id("supply"),
    recipientCounterId: id("recipients"), totalQuantity: 8n, perRecipientCap: 3n, deliveryMode: 1n, prepared: false };
  const definition = { scope: 2n, keyMode: 3n, capRoot: id("same allowance root"), metadataHash: id("published content") };
  const definitionType = compiled.counterPolicy.getFunction("registerCounterDefinition").inputs[0];
  const definitionHash = hash(["bytes32", definitionType], [id("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition]);
  const selected = { counterConfigHash: definitionHash, exists: true, definition };
  const original = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32",
    compiled.distributor.getFunction("programHash").inputs[2]], [id("6529STREAM_OPERATOR_DISTRIBUTION_CONFIG_V1"),
    context.chainId, context.distributor, context.core, context.manager, collection, phase, program]);
  const expected = hash(["bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_OPERATOR_DISTRIBUTION_MERKLE_CONFIG_V1"), original, definitionHash, definition.metadataHash]);
  assert.equal(merkle.distributionMerkleDefinitionHash(definition), definitionHash);
  assert.equal(merkle.distributionMerkleOriginalProgramHash(context, collection, phase, program), original);
  assert.equal(merkle.distributionMerkleProgramHash(context, collection, phase, program, selected), expected);
  assert.notEqual(expected, original);
  const call = merkle.prepareDistributionMerkleProgramRead(context, collection, phase, program, definitionHash);
  assert.deepEqual(call, { to: context.distributor, value: 0n,
    data: compiled.distributor.encodeFunctionData("merkleProgramHash", [collection, phase, program, definitionHash]) });
  const nextDefinition = { ...definition, metadataHash: id("changed publication same root") };
  const nextHash = hash(["bytes32", definitionType], [id("6529STREAM_MINT_COUNTER_DEFINITION_V1"), nextDefinition]);
  assert.notEqual(nextHash, definitionHash);
  assert.notEqual(merkle.distributionMerkleProgramHash(context, collection, phase, program,
    { counterConfigHash: nextHash, exists: true, definition: nextDefinition }), expected);
  assert.throws(() => merkle.distributionMerkleProgramHash(context, collection, phase, program,
    { ...selected, definition: nextDefinition }), /hash mismatch/);
  assert.throws(() => merkle.distributionMerkleProgramHash(context, collection, phase, program,
    { ...selected, exists: false }), /absent/);
});

test("new allowance leaf and ordered nested proof bytes retain the original free-proof preimage", () => {
  const context = { chainId: 6529n, distributor: address(71), core: address(72), manager: address(73), ledger: address(74) };
  const collection = 32n, phase = id("phase"), counter = id("recipient counter"), beneficiary = address(75);
  const proof = { maxCount: 3n, hasPriceOverride: false, priceOverride: 0n, proof: [id("sibling")] };
  const expected = keccak256(hash(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256"],
    [id("6529STREAM_MINT_ALLOWLIST_LEAF_V1"), context.chainId, context.manager, collection, phase, counter, beneficiary, 3n, false, 0n]));
  assert.equal(merkle.distributionMerkleAllowanceLeaf(context, collection, phase, counter, beneficiary, proof), expected);
  const rows = [[proof, proof], [{ ...proof, maxCount: 4n, proof: [] }, { ...proof, maxCount: 5n, proof: [] }]];
  // This internal source struct is carried through resolverData bytes, not as a
  // public function tuple. Keep its literal source field widths independent.
  const tuple = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)[][]";
  const encoded = coder.encode([tuple], [rows]);
  assert.equal(merkle.encodeDistributionMerkleProofs(rows), encoded);
  assert.deepEqual(merkle.decodeDistributionMerkleProofs(encoded), rows);
  assert.notEqual(merkle.encodeDistributionMerkleProofs([...rows].reverse()), encoded);
  const definition = source("interfaces/stream/mint/IStreamMintCounterPolicy");
  assert.match(definition, /struct AllowlistProof \{\s*uint64 maxCount;\s*bool hasPriceOverride;\s*uint256 priceOverride;\s*bytes32\[\] proof;\s*\}/);
});

test("workflow read and event ABI matches complete compiler output including tuple names", () => {
  const url = new URL("../src/current-distribution-merkle-workflow.ts", import.meta.url);
  const parsed = ts.createSourceFile(url.href, readFileSync(url, "utf8"), ts.ScriptTarget.Latest, true);
  const declaration = parsed.statements.filter(ts.isVariableStatement).flatMap(s => [...s.declarationList.declarations])
    .find(d => ts.isIdentifier(d.name) && d.name.text === "abi");
  assert.ok(declaration && ts.isNewExpression(declaration.initializer));
  const array = declaration.initializer.arguments[0];
  assert.ok(ts.isArrayLiteralExpression(array));
  const fragments = array.elements.map(node => {
    assert.ok(ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node), "ABI must remain independently readable literals");
    return node.text;
  });
  for (const fragment of new Interface(fragments).fragments) {
    const signature = fragment.format("sighash");
    const candidates = Object.values(compiled).map(iface => fragment.type === "event"
      ? iface.getEvent(signature) : fragment.type === "error" ? iface.getError(signature) : iface.getFunction(signature)).filter(Boolean);
    assert.ok(candidates.length, signature);
    const original = candidates.find(candidate => candidate.format("minimal") === fragment.format("minimal"));
    assert.ok(original, `${signature}: output, mutability or indexing differs`);
    function fields(actual, expected, tuple = false) {
      assert.equal(actual.length, expected.length);
      for (let i = 0; i < expected.length; i++) {
        const a = actual[i], e = expected[i];
        if (tuple || fragment.type === "event") assert.equal(a.name, e.name, `${signature}/${e.name}`);
        if (e.baseType === "array") fields([a.arrayChildren], [e.arrayChildren]);
        if (e.baseType === "tuple") fields(a.components, e.components, true);
      }
    }
    fields(fragment.inputs, original.inputs);
    if (original.outputs) fields(fragment.outputs, original.outputs);
  }
});
