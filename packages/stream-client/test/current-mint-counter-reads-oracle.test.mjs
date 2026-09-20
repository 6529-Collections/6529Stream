import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as client from "../dist/current-mint-counter-reads.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-mint-counter-reads-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(["manager", "fallback", "ledger", "counterReadsInterface"]
  .map(key => [key, new Interface(fixture.abis[key])]));
const coder = AbiCoder.defaultAbiCoder(), address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const hash = (types, values) => keccak256(coder.encode(types, values));
const contextType = abi.counterReadsInterface.getFunction("resolveCounter").inputs[0];
const resolutionType = abi.counterReadsInterface.getFunction("resolveCounter").outputs[0];
const configType = abi.manager.getFunction("counterConfig").outputs[0];
const definitionType = abi.ledger.getFunction("counterDefinitionForManager").outputs[1];
const policySource = fixture.sourceTexts["smart-contracts/interfaces/stream/mint/IStreamMintCounterPolicy.sol"];
// This internal struct has no exported compiler ABI. Derive it from retained Solidity.
const proofFields = [...policySource.match(/struct AllowlistProof\s*\{([^}]+)\}/)[1]
  .matchAll(/\b(uint64|bool|uint256|bytes32\[\])\s+(\w+)\s*;/g)].map(([, type, name]) => ({ type, name }));
const proofType = ParamType.from({ type: "tuple", components: proofFields });
const MAX64 = (1n << 64n) - 1n, MAX256 = (1n << 256n) - 1n;
function input(keyMode = 1n, scope = 1n) {
  return {
    binding: { chainId: (1n << 230n) + 31337n, manager: address(11), ledger: address(12) },
    context: { collectionId: (1n << 201n) + 19n, phaseId: id("original phase"), counterId: id("original counter"),
      payer: address(21), initialRecipient: address(22), beneficiary: address(23), executor: address(24), authorizer: address(25),
      tokenIndex: keyMode === 6n ? MAX256 : 2n, contextHash: id("original context"), resolverData: "0xdeadbeef" },
    policy: { phaseExists: true, config: { enabled: true, keyMode, capMode: 1n, deltaMode: keyMode === 6n ? 1n : 0n,
      staticCap: MAX64, staticIncrement: 3n, counterConfigHash: id("original counter config") },
    definitionExists: true, definition: { scope, keyMode, capRoot: ZeroHash, metadataHash: id("original definition") } },
  };
}
function subject(b, x, mode, cid, phase) {
  const types = ["bytes32", "uint256", "address", "uint8"], values = [id("6529STREAM_MINT_COUNTER_SUBJECT_V1"), b.chainId, b.ledger, mode];
  if (mode === 1n) return hash([...types, "uint256", "bytes32", "bytes32"], [...values, cid, phase, x.counterId]);
  if (mode === 6n) return hash([...types, "bytes32"], [...values, x.contextHash]);
  const account = { 2: x.payer, 3: x.beneficiary, 4: x.executor, 5: x.authorizer }[mode];
  return hash([...types, "address"], [...values, account]);
}
function original(p, proof) {
  const { binding: b, context: x, policy: { config: c, definition: d, definitionExists } } = p;
  const scope = definitionExists ? d.scope : 2n;
  const cid = scope === 0n ? 0n : x.collectionId, phase = scope === 2n ? x.phaseId : ZeroHash;
  const before = subject(b, x, c.keyMode, x.collectionId, x.phaseId);
  const after = c.keyMode === 1n ? subject(b, x, c.keyMode, cid, phase) : before;
  let resolutionHash = hash(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint256", "bytes32"],
    [id("6529STREAM_MINT_COUNTER_RESOLUTION_V1"), b.chainId, b.manager, b.ledger, x.collectionId, x.phaseId, x.counterId, before, x.tokenIndex, c.counterConfigHash]);
  let cap = c.capMode === 1n ? c.staticCap : 0n;
  if (proof) { cap = proof.maxCount; resolutionHash = hash(["bytes32", "bytes32", "bytes32"], [id("6529STREAM_MINT_ALLOWLIST_RESOLUTION_V1"), resolutionHash, leaf(p, proof)]); }
  return { resolution: { subjectKey: after, effectiveCap: cap, increment: c.staticIncrement, resolutionHash },
    valueKey: hash(["bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"), b.manager, cid, phase, x.counterId, after]),
    preScopeSubjectKey: before, scopedCollectionId: cid, scopedPhaseId: phase };
}
function leaf(p, proof) {
  const { binding: b, context: x, policy: { config: c } } = p;
  const account = c.keyMode === 2n ? x.payer : c.keyMode === 6n ? ZeroAddress : x.beneficiary;
  return keccak256(hash(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256"],
    [id("6529STREAM_MINT_ALLOWLIST_LEAF_V1"), b.chainId, b.manager, x.collectionId, x.phaseId, x.counterId, account,
      proof.maxCount, proof.hasPriceOverride, proof.priceOverride]));
}
function pair(a, b) { return hash(["bytes32", "bytes32"], BigInt(a) < BigInt(b) ? [a, b] : [b, a]); }
const resolve = p => client.resolveMintCounterRead(p.binding, p.policy, p.context);

test("CounterReads fixture retains exact ABI65 provenance and source-derived proof declaration", () => {
  assert.equal(fixture.sourceCommit, "ea92b7d41ae9e9eede2a00f2c12b70543f125307");
  assert.equal(fixture.sourceCount, 2309);
  assert.equal(fixture.inputSha256, "dc9032a36b5a9d54c9a6f75259ad15057131dede213bbb6a315f2129154c8f13");
  assert.equal(fixture.outputSha256, "557bfe82dd881dc2f3db2b624219ecdf8d67512f4ed3f4cd5b2215728d97205f");
  assert.equal(Object.values(fixture.abis).flat().length, 58);
  assert.equal(Object.keys(fixture.sourceHashes).length, 115);
  assert.equal(Object.keys(fixture.sourceTexts).length, 12);
  for (const [path, source] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(source).digest("hex"), fixture.sourceHashes[path]);
  assert.deepEqual(proofFields, [ { type: "uint64", name: "maxCount" }, { type: "bool", name: "hasPriceOverride" },
    { type: "uint256", name: "priceOverride" }, { type: "bytes32[]", name: "proof" } ]);
  assert.match(fixture.qualification, /do not establish native/);
});

test("all five caller fragments and exact result layouts match both original Manager facades", () => {
  let interfaceId = 0n;
  const selectors = { rawCounterValue: "0x9dec2d63", counterValue: "0x28795416", remainingForCounter: "0x3921c74c",
    resolveCounter: "0x2b30d626", remainingForResolvedCounter: "0x4ee83aeb" };
  for (const f of new Interface(client.CURRENT_MINT_COUNTER_READS_ABI).fragments) {
    interfaceId ^= BigInt(f.selector);
    for (const host of [abi.manager, abi.fallback, abi.counterReadsInterface]) {
      const compiled = host.getFunction(f.name);
      assert.equal(f.selector, selectors[f.name]);
      assert.equal(f.format("sighash"), compiled.format("sighash"));
      assert.equal(f.stateMutability, compiled.stateMutability);
      assert.deepEqual(f.outputs.map(x => x.format("sighash")), compiled.outputs.map(x => x.format("sighash")));
    }
  }
  assert.equal(`0x${interfaceId.toString(16).padStart(8, "0")}`, client.MINT_COUNTER_READS_INTERFACE_ID);
  assert.equal(ParamType.from(client.MINT_COUNTER_READ_CONTEXT_TUPLE).format("sighash"), contextType.format("sighash"));
  assert.equal(ParamType.from(client.MINT_COUNTER_READ_RESOLUTION_TUPLE).format("sighash"), resolutionType.format("sighash"));
  const r = original(input()).resolution;
  for (const [method, values, length] of [ ["rawCounterValue", [MAX64], 32], ["counterValue", [MAX64], 32],
    ["remainingForCounter", [MAX64], 32], ["resolveCounter", [r], 128], ["remainingForResolvedCounter", [r, MAX64, 0n], 192],
    ["phasePolicyGrace", [id("previous"), MAX64], 64] ]) {
    const encoded = abi.manager.encodeFunctionResult(method, values);
    assert.equal((encoded.length - 2) / 2, length);
    assert.equal(abi.fallback.encodeFunctionResult(method, values), encoded);
  }
});

test("compiled eleven-field context encodes original caller-independent calldata at wide integers", () => {
  const p = input(), subjectKey = id("supplied subject");
  for (const request of [ { method: "rawCounterValue", valueKey: ZeroHash },
    ...["counterValue", "remainingForCounter"].map(method => ({ method, collectionId: p.context.collectionId, phaseId: p.context.phaseId, counterId: p.context.counterId, subjectKey })),
    ...["resolveCounter", "remainingForResolvedCounter"].map(method => ({ method, context: p.context })) ]) {
    const args = request.method === "rawCounterValue" ? [ZeroHash] : "context" in request ? [p.context]
      : [p.context.collectionId, p.context.phaseId, p.context.counterId, subjectKey];
    const prepared = client.prepareMintCounterReadCall(p.binding.manager, ZeroAddress, request);
    assert.deepEqual(prepared.call, { to: p.binding.manager, data: abi.manager.encodeFunctionData(request.method, args), value: 0n });
    assert.equal(prepared.call.data, client.prepareMintCounterReadCall(p.binding.manager, address(99), request).call.data);
  }
  assert.deepEqual(contextType.components.map(x => x.name), Object.keys(p.context));
  assert.equal(coder.encode([configType], [p.policy.config]), coder.encode([configType], [client.normalizeMintCounterReadPolicy(p.policy).config]));
  assert.equal(coder.encode([definitionType], [p.policy.definition]), coder.encode([definitionType], [client.normalizeMintCounterReadPolicy(p.policy).definition]));
});

test("original scope and pre-scope recipes agree across all eighteen key/scope profiles", () => {
  for (let mode = 1n; mode <= 6n; mode++) for (let scope = 0n; scope <= 2n; scope++) {
    const p = input(mode, scope), result = resolve(p);
    assert.deepEqual(result, original(p), `mode=${mode}, scope=${scope}`);
    if (mode === 1n && scope !== 2n) assert.notEqual(result.preScopeSubjectKey, result.resolution.subjectKey);
    const scalar = { collectionId: p.context.collectionId, phaseId: p.context.phaseId, counterId: p.context.counterId, subjectKey: result.resolution.subjectKey };
    assert.equal(client.mintCounterReadValueKey(p.binding, p.policy, scalar), result.valueKey);
    const absent = structuredClone(p); absent.policy.definitionExists = false;
    assert.deepEqual(resolve(absent), original(absent));
    assert.equal(resolve(absent).scopedPhaseId, p.context.phaseId);
  }
});

test("accounting domains retain actual Manager, Ledger and original phase independently of inactive context", () => {
  const p = input(3n, 1n), expected = resolve(p);
  for (const field of ["payer", "initialRecipient", "executor", "authorizer"]) {
    const changed = structuredClone(p); changed.context[field] = ZeroAddress;
    assert.deepEqual(resolve(changed), expected, field);
  }
  for (const [section, field, value] of [ ["binding", "manager", address(101)], ["binding", "ledger", address(102)],
    ["binding", "chainId", p.binding.chainId + 1n], ["context", "phaseId", id("new phase")], ["context", "beneficiary", address(103)] ]) {
    const changed = structuredClone(p); changed[section][field] = value;
    assert.deepEqual(resolve(changed), original(changed));
    assert.notEqual(resolve(changed).resolution.resolutionHash, expected.resolution.resolutionHash);
  }
  const changed = structuredClone(p); changed.context.phaseId = id("another collection-scoped phase");
  assert.equal(resolve(changed).valueKey, expected.valueKey);
});

test("single proof encoding and double-hashed leaves retain original domain, price and cap presentation", () => {
  for (const mode of [2n, 3n, 6n]) {
    const p = input(mode, 1n); p.policy.config.capMode = 3n;
    const proofs = [ { maxCount: 7n, hasPriceOverride: false, priceOverride: 0n, proof: [] },
      { maxCount: 19n, hasPriceOverride: true, priceOverride: (1n << 200n) + 4n, proof: [] } ];
    const leaves = proofs.map(proof => leaf(p, proof));
    p.policy.definition.capRoot = pair(...leaves);
    const results = proofs.map((proof, i) => {
      proof.proof = [leaves[1 - i]];
      p.context.resolverData = coder.encode([proofType], [proof]);
      assert.equal(client.encodeMintCounterAllowlistProof(proof), p.context.resolverData);
      assert.deepEqual(client.decodeMintCounterAllowlistProof(p.context.resolverData), proof);
      assert.equal(client.mintCounterAllowlistLeaf(p.binding, p.context.collectionId, p.context.phaseId, p.context.counterId,
        mode === 2n ? p.context.payer : mode === 6n ? ZeroAddress : p.context.beneficiary, proof), leaves[i]);
      assert.equal(client.verifyMintCounterAllowlistProof(p.policy.definition.capRoot, leaves[i], proof.proof), true);
      assert.deepEqual(resolve(p), original(p, proof));
      return resolve(p);
    });
    assert.equal(results[0].valueKey, results[1].valueKey);
    assert.notEqual(results[0].resolution.resolutionHash, results[1].resolution.resolutionHash);
    assert.equal(client.mintCounterReadRemaining(3n, results[0].resolution.effectiveCap, 10n), 0n);
    assert.equal(client.mintCounterReadRemaining(3n, results[1].resolution.effectiveCap, 10n), 9n);
  }
});

test("invalid proof presentation cannot become the configured ceiling or a batch proof", () => {
  const p = input(2n, 2n); p.policy.config.capMode = 3n; p.policy.config.staticCap = 20n;
  const proof = { maxCount: 7n, hasPriceOverride: true, priceOverride: 0n, proof: [] };
  p.policy.definition.capRoot = leaf(p, proof); p.context.resolverData = coder.encode([proofType], [proof]);
  assert.equal(resolve(p).resolution.effectiveCap, 7n);
  for (const encoded of [ "0x", `${p.context.resolverData}${"00".repeat(32)}`,
    coder.encode([`${proofType.format("full")}[][]`], [[[proof]]]) ]) {
    const changed = structuredClone(p); changed.context.resolverData = encoded; assert.throws(() => resolve(changed));
  }
  for (const override of [ { maxCount: 0n }, { maxCount: 21n }, { hasPriceOverride: false, priceOverride: 1n }, { proof: [id("wrong sibling")] } ]) {
    const changed = structuredClone(p); changed.context.resolverData = coder.encode([proofType], [{ ...proof, ...override }]);
    assert.throws(() => resolve(changed));
  }
  for (const [section, field, value] of [ ["binding", "chainId", 1n], ["binding", "manager", address(99)],
    ["context", "collectionId", 22n], ["context", "phaseId", id("wrong phase")], ["context", "counterId", id("wrong counter")],
    ["context", "payer", address(99)] ]) {
    const changed = structuredClone(p); changed[section][field] = value; assert.throws(() => resolve(changed), /ProofInvalid/);
  }
  assert.throws(() => client.mintCounterProoflessRemaining(p.policy, 0n), /ProofRequired/);
});

test("original remaining units saturate and NONE reports only uint64 headroom", () => {
  for (const current of [0n, 6n, 7n, 8n, MAX64]) {
    assert.equal(client.mintCounterReadRemaining(0n, 7n, current), MAX64 - current);
    for (const mode of [1n, 2n, 3n]) assert.equal(client.mintCounterReadRemaining(mode, 7n, current), current >= 7n ? 0n : 7n - current);
  }
  const p = input(); p.policy.config.capMode = 2n;
  assert.equal(resolve(p).resolution.effectiveCap, 0n);
  assert.equal(client.mintCounterProoflessRemaining(p.policy, 6n), MAX64 - 6n);
  p.policy.config.capMode = 0n;
  assert.equal(resolve(p).resolution.effectiveCap, 0n);
});

test("frozen worker has only the five views plus four retained selectors and original metered policy path", () => {
  const src = name => fixture.sourceTexts[`smart-contracts/domains/mint/${name}.sol`];
  const selectors = [...src("StreamMintCounterReads").matchAll(/IStreamMint(?:CounterReads|Reads)\.(\w+)\.selector/g)].map(x => x[1]);
  assert.deepEqual([...new Set(selectors)].sort(), ["isAuthorizationUsed", "isNullifierUsed", "isOperationRootUsed", "phasePolicyGrace",
    "rawCounterValue", "counterValue", "remainingForCounter", "resolveCounter", "remainingForResolvedCounter"].sort());
  assert.match(src("StreamMintCounterReads"), /bytes4 selector = bytes4\(callData\[:4\]\)/);
  assert.match(src("StreamMintCounterReads"), /batchScoped \? address\(0\) : x\.beneficiary/);
  assert.match(src("StreamMintCounterPolicy"), /staticcall\{ gas: 30_000 \}/);
  assert.match(src("StreamMintCounterPolicy"), /result\.length != 32 \|\| abi\.decode\(result, \(uint256\)\) != 1/);
  assert.match(src("StreamMintCounterPolicy"), /counterDefinitionForManager\(address\(this\), hash\)/);
  assert.match(src("StreamMintCounterPreparation"), /keccak256\(resolverData\) != keccak256\(abi\.encode\(proof\)\)/);
});
