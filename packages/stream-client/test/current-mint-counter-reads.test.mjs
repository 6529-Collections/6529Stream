import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256, toBeHex } from "ethers";
import * as reads from "../dist/current-mint-counter-reads.js";

const coder = AbiCoder.defaultAbiCoder();
const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-mint-counter-reads-abi.json", import.meta.url), "utf8"));
const original = new Interface(fixture.abis.counterReadsInterface);
const addr = n => getAddress(toBeHex(n, 20));
const max64 = (1n << 64n) - 1n, max256 = (1n << 256n) - 1n;
const binding = { chainId: (1n << 180n) + 7n, manager: addr(11), ledger: addr(12) };
const context = { collectionId: (1n << 160n) + 9n, phaseId: id("phase"), counterId: id("counter"),
  payer: addr(21), initialRecipient: addr(22), beneficiary: addr(23), executor: addr(24), authorizer: addr(25),
  tokenIndex: 9n, contextHash: id("context"), resolverData: "0xabcdef" };
const policy = { phaseExists: true, definitionExists: true,
  config: { enabled: true, keyMode: 2n, capMode: 1n, deltaMode: 0n, staticCap: max64, staticIncrement: (1n << 55n) + 1n, counterConfigHash: id("config") },
  definition: { scope: 2n, keyMode: 2n, capRoot: ZeroHash, metadataHash: id("metadata") } };
const pol = (c = {}, d = {}, rest = {}) => ({ ...policy, ...rest, config: { ...policy.config, ...c }, definition: { ...policy.definition, ...d } });
const h = (types, values) => keccak256(coder.encode(types, values));
function independentSubject(keyMode, x, cid = x.collectionId, phase = x.phaseId, b = binding) {
  const types = ["bytes32", "uint256", "address", "uint8"];
  const values = [id("6529STREAM_MINT_COUNTER_SUBJECT_V1"), b.chainId, b.ledger, keyMode];
  if (keyMode === 1n) return h([...types, "uint256", "bytes32", "bytes32"], [...values, cid, phase, x.counterId]);
  if (keyMode === 6n) return h([...types, "bytes32"], [...values, x.contextHash]);
  return h([...types, "address"], [...values, [null, null, x.payer, x.beneficiary, x.executor, x.authorizer][Number(keyMode)]]);
}
function independentResolution(x, p = policy, b = binding) {
  return h(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint256", "bytes32"],
    [id("6529STREAM_MINT_COUNTER_RESOLUTION_V1"), b.chainId, b.manager, b.ledger, x.collectionId, x.phaseId, x.counterId,
      independentSubject(p.config.keyMode, x, x.collectionId, x.phaseId, b), x.tokenIndex, p.config.counterConfigHash]);
}
const proofTuple = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)"; // Original source struct, not an ABI output.
const proof = (patch = {}) => ({ maxCount: (1n << 55n) + 3n, hasPriceOverride: false, priceOverride: 0n, proof: [], ...patch });
function leaf(p, x = context, b = binding, account = x.payer) {
  return keccak256(h(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256"],
    [id("6529STREAM_MINT_ALLOWLIST_LEAF_V1"), b.chainId, b.manager, x.collectionId, x.phaseId, x.counterId, account, p.maxCount, p.hasPriceOverride, p.priceOverride]));
}

test("five original compiler view calls keep target, explicit caller and context actors separate", () => {
  let ownId = 0n;
  const requests = [ { method: "rawCounterValue", valueKey: ZeroHash },
    ...["counterValue", "remainingForCounter"].map(method => ({ method, collectionId: context.collectionId, phaseId: context.phaseId, counterId: context.counterId, subjectKey: id("arbitrary") })),
    ...["resolveCounter", "remainingForResolvedCounter"].map(method => ({ method, context })) ];
  for (const request of requests) {
    const prepared = reads.prepareMintCounterReadCall(binding.manager, ZeroAddress, request);
    const args = "valueKey" in request ? [request.valueKey] : "context" in request ? [request.context]
      : [request.collectionId, request.phaseId, request.counterId, request.subjectKey];
    assert.equal(prepared.call.data, original.encodeFunctionData(request.method, args));
    assert.equal(prepared.call.to, binding.manager); assert.equal(prepared.caller, ZeroAddress); assert.equal(prepared.call.value, 0n);
    assert.equal(original.getFunction(request.method).stateMutability, "view");
    ownId ^= BigInt(original.getFunction(request.method).selector);
    assert.deepEqual(reads.normalizeMintCounterReadCall(prepared), prepared);
  }
  assert.equal(toBeHex(ownId, 4), reads.MINT_COUNTER_READS_INTERFACE_ID);
  assert.equal(new Interface(reads.CURRENT_MINT_COUNTER_READS_ABI).getFunction("resolveCounter").format("sighash"), original.getFunction("resolveCounter").format("sighash"));
  assert.equal(coder.encode([reads.MINT_COUNTER_READ_RESOLUTION_TUPLE], [{ subjectKey: ZeroHash, effectiveCap: 0n, increment: max64, resolutionHash: ZeroHash }]).length, 2 + 128 * 2);
});

test("all original subject modes use full-width coordinates and the beneficiary for RECIPIENT", () => {
  for (let keyMode = 1n; keyMode <= 6n; keyMode++) {
    const x = { ...context, tokenIndex: keyMode === 6n ? max256 : 9n }, p = pol({ keyMode });
    const result = reads.resolveMintCounterRead(binding, p, x);
    assert.equal(result.resolution.subjectKey, independentSubject(keyMode, x));
    assert.equal(result.preScopeSubjectKey, result.resolution.subjectKey);
    assert.equal(result.resolution.resolutionHash, independentResolution(x, p));
    assert.equal(result.resolution.increment, policy.config.staticIncrement);
  }
  const recipient = reads.resolveMintCounterRead(binding, pol({ keyMode: 3n }), context);
  assert.deepEqual(reads.resolveMintCounterRead(binding, pol({ keyMode: 3n }), { ...context, initialRecipient: ZeroAddress }), recipient);
  assert.notEqual(recipient.resolution.subjectKey, independentSubject(3n, { ...context, beneficiary: context.initialRecipient }));
});

test("CONSTANT scoped subject changes while its original resolution identity stays pre-scope", () => {
  const hashes = new Set(), subjects = new Set(), keys = new Set();
  for (const scope of [0n, 1n, 2n]) {
    const p = pol({ keyMode: 1n }, { scope }), result = reads.resolveMintCounterRead(binding, p, context);
    const cid = scope === 0n ? 0n : context.collectionId, phase = scope === 2n ? context.phaseId : ZeroHash;
    assert.equal(result.resolution.subjectKey, independentSubject(1n, context, cid, phase));
    assert.equal(result.preScopeSubjectKey, independentSubject(1n, context));
    assert.equal(result.resolution.resolutionHash, independentResolution(context, p));
    assert.equal(result.valueKey, h(["bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"), binding.manager, cid, phase, context.counterId, result.resolution.subjectKey]));
    hashes.add(result.resolution.resolutionHash); subjects.add(result.resolution.subjectKey); keys.add(result.valueKey);
  }
  assert.equal(hashes.size, 1); assert.equal(subjects.size, 3); assert.equal(keys.size, 3);
});

test("Manager namespaces values and resolution, but address subjects retain chain/Ledger identity", () => {
  const a = reads.resolveMintCounterRead(binding, policy, context), b = reads.resolveMintCounterRead({ ...binding, manager: addr(99) }, policy, context);
  assert.equal(a.resolution.subjectKey, b.resolution.subjectKey);
  assert.notEqual(a.valueKey, b.valueKey); assert.notEqual(a.resolution.resolutionHash, b.resolution.resolutionHash);
  for (const changed of [{ chainId: binding.chainId + 1n }, { ledger: addr(98) }])
    assert.notEqual(a.resolution.subjectKey, reads.resolveMintCounterRead({ ...binding, ...changed }, policy, context).resolution.subjectKey);
});

test("legacy absent definition overrides only scope and supplied scalar subject remains unchanged", () => {
  const p = pol({ keyMode: 1n }, { scope: 0n, keyMode: 5n, capRoot: id("retained root") }, { definitionExists: false });
  const snapshot = reads.normalizeMintCounterReadPolicy(p);
  assert.deepEqual(snapshot.definition, p.definition);
  assert.deepEqual(reads.mintCounterReadScope(snapshot, context.collectionId, context.phaseId), { collectionId: context.collectionId, phaseId: context.phaseId });
  const supplied = { collectionId: context.collectionId, phaseId: context.phaseId, counterId: context.counterId, subjectKey: id("caller supplied subject") };
  const key = reads.mintCounterReadValueKey(binding, pol({ keyMode: 1n }, { scope: 0n }), supplied);
  assert.equal(key, h(["bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32"], [id("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"), binding.manager, 0n, ZeroHash, supplied.counterId, supplied.subjectKey]));
  assert.notEqual(key, reads.resolveMintCounterRead(binding, pol({ keyMode: 1n }, { scope: 0n }), context).valueKey);
});

test("structural inputs preserve zero and unusual stored tuples; resolution applies only actual read checks", () => {
  const zero = { ...context, payer: ZeroAddress, initialRecipient: ZeroAddress, beneficiary: ZeroAddress,
    executor: ZeroAddress, authorizer: ZeroAddress, contextHash: ZeroHash, counterId: ZeroHash, resolverData: "0xfe" };
  assert.doesNotThrow(() => reads.resolveMintCounterRead(binding, pol({ keyMode: 1n, staticIncrement: 0n }, { keyMode: 0n }), zero));
  for (const [mode, field] of [[2n, "payer"], [3n, "beneficiary"], [4n, "executor"], [5n, "authorizer"]]) {
    assert.throws(() => reads.resolveMintCounterRead(binding, pol({ keyMode: mode }), zero), /SubjectMissing/);
    assert.doesNotThrow(() => reads.resolveMintCounterRead(binding, pol({ keyMode: mode }), { ...zero, [field]: addr(80) }));
  }
  assert.doesNotThrow(() => reads.resolveMintCounterRead(binding, pol({ keyMode: 6n }, { scope: 0n, keyMode: 5n }), { ...zero, contextHash: id("batch"), tokenIndex: max256 }));
  for (const bad of [{ collectionId: 0n }, { phaseId: ZeroHash }]) assert.throws(() => reads.resolveMintCounterRead(binding, policy, { ...context, ...bad }), /InvalidMintPhase/);
  assert.throws(() => reads.resolveMintCounterRead(binding, pol({}, {}, { phaseExists: false }), context), /DoesNotExist/);
  assert.throws(() => reads.resolveMintCounterRead(binding, pol({ enabled: false }), context), /disabled/);
  assert.throws(() => reads.resolveMintCounterRead(binding, pol({ keyMode: 0n }), context), /SubjectMissing/);
  assert.throws(() => reads.mintCounterReadValueKey(binding, policy, { collectionId: context.collectionId, phaseId: context.phaseId, counterId: context.counterId, subjectKey: ZeroHash }), /zero subject/);
});

test("token index rules and ignored context fields follow single-row resolution", () => {
  assert.throws(() => reads.resolveMintCounterRead(binding, policy, { ...context, tokenIndex: 10n }), /TokenIndexInvalid/);
  assert.throws(() => reads.resolveMintCounterRead(binding, pol({ keyMode: 6n }), context), /TokenIndexInvalid/);
  assert.throws(() => reads.resolveMintCounterRead(binding, pol({ keyMode: 6n }), { ...context, tokenIndex: max256, contextHash: ZeroHash }), /SubjectMissing/);
  const before = reads.resolveMintCounterRead(binding, policy, context);
  assert.deepEqual(reads.resolveMintCounterRead(binding, policy, { ...context, initialRecipient: ZeroAddress, beneficiary: ZeroAddress,
    executor: ZeroAddress, authorizer: ZeroAddress, contextHash: ZeroHash, resolverData: "0x1234" }), before);
  assert.notEqual(reads.resolveMintCounterRead(binding, policy, { ...context, tokenIndex: 0n }).resolution.resolutionHash, before.resolution.resolutionHash);
});

test("single AllowlistProof canonical encoding rejects nested batch, tail, padding and alternate offsets", () => {
  const p = proof({ proof: [id("a"), id("b")] }), data = reads.encodeMintCounterAllowlistProof(p);
  assert.equal(data, coder.encode([proofTuple], [p])); assert.deepEqual(reads.decodeMintCounterAllowlistProof(data), p);
  const invalid = ["0x", `${data}00`, coder.encode([`${proofTuple}[][]`], [[[p]]]),
    `${data.slice(0, 2 + 2 * 32)}01${data.slice(2 + 2 * 33)}`,
    `${toBeHex(64, 32)}${toBeHex(0, 32).slice(2)}${data.slice(66)}` ];
  for (const value of invalid) assert.throws(() => reads.decodeMintCounterAllowlistProof(value));
  assert.throws(() => reads.normalizeMintCounterAllowlistProof({ ...p, proof: new Array(2) }), /dense/);
  assert.throws(() => reads.normalizeMintCounterAllowlistProof({ ...p, proof: Object.assign([id("x")], { extra: 1 }) }), /dense/);
});

test("Merkle leaves bind original unscope coordinates and verify sorted pairs plus exact cap", () => {
  const p = proof(), q = proof({ maxCount: p.maxCount + 1n }), a = leaf(p), b = leaf(q);
  const root = h(["bytes32", "bytes32"], BigInt(a) < BigInt(b) ? [a, b] : [b, a]);
  assert.equal(reads.mintCounterAllowlistLeaf(binding, context.collectionId, context.phaseId, context.counterId, context.payer, p), a);
  const results = [];
  for (const [entry, sibling] of [[p, b], [q, a]]) {
    const encoded = reads.encodeMintCounterAllowlistProof({ ...entry, proof: [sibling] });
    const cp = pol({ capMode: 3n }, { scope: 0n, capRoot: root });
    const result = reads.resolveMintCounterRead(binding, cp, { ...context, resolverData: encoded }); results.push(result);
    assert.equal(result.resolution.effectiveCap, entry.maxCount);
    assert.equal(result.resolution.resolutionHash, h(["bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_MINT_ALLOWLIST_RESOLUTION_V1"), independentResolution(context, cp), leaf(entry)]));
    assert.equal(result.scopedCollectionId, 0n); assert.equal(result.scopedPhaseId, ZeroHash);
    assert.throws(() => reads.resolveMintCounterRead(binding, cp, { ...context, collectionId: context.collectionId + 1n, resolverData: encoded }), /ProofInvalid/);
    assert.throws(() => reads.resolveMintCounterRead({ ...binding, manager: addr(77) }, cp, { ...context, resolverData: encoded }), /ProofInvalid/);
    assert.throws(() => reads.resolveMintCounterRead(binding, pol({ capMode: 3n, staticCap: entry.maxCount - 1n }, { capRoot: root }), { ...context, resolverData: encoded }), /ProofInvalid/);
  }
  assert.equal(results[0].valueKey, results[1].valueKey); assert.notEqual(results[0].resolution.resolutionHash, results[1].resolution.resolutionHash);
});

test("Merkle price declaration, zero ceiling, proof roots and recipient account follow source", () => {
  for (const priceOverride of [0n, max256]) {
    const p = proof({ hasPriceOverride: true, priceOverride }), x = { ...context, resolverData: reads.encodeMintCounterAllowlistProof(p) };
    assert.doesNotThrow(() => reads.resolveMintCounterRead(binding, pol({ capMode: 3n }, { capRoot: leaf(p) }), x));
  }
  const badPrice = proof({ priceOverride: 1n });
  assert.throws(() => reads.resolveMintCounterRead(binding, pol({ capMode: 3n }, { capRoot: leaf(badPrice) }), { ...context, resolverData: reads.encodeMintCounterAllowlistProof(badPrice) }), /PriceOverrideUnsupported/);
  const zero = proof({ maxCount: 0n });
  assert.throws(() => reads.resolveMintCounterRead(binding, pol({ capMode: 3n }, { capRoot: leaf(zero) }), { ...context, resolverData: reads.encodeMintCounterAllowlistProof(zero) }), /ProofInvalid/);
  const p = proof(), data = reads.encodeMintCounterAllowlistProof(p);
  assert.throws(() => reads.resolveMintCounterRead(binding, pol({ capMode: 3n }, { capRoot: ZeroHash }), { ...context, resolverData: data }), /ProofInvalid/);
  const cp = pol({ keyMode: 3n, capMode: 3n }, { capRoot: leaf(p, context, binding, context.beneficiary) });
  assert.doesNotThrow(() => reads.resolveMintCounterRead(binding, cp, { ...context, initialRecipient: ZeroAddress, resolverData: data }));
  assert.throws(() => reads.resolveMintCounterRead(binding, cp, { ...context, beneficiary: context.initialRecipient, resolverData: data }), /ProofInvalid/);
});

test("remaining reports consumptions or uint64 headroom, saturates and requires a Merkle proof", () => {
  assert.equal(reads.mintCounterReadRemaining(0n, 2n, 3n), max64 - 3n);
  for (const mode of [1n, 2n, 3n]) {
    assert.equal(reads.mintCounterReadRemaining(mode, 7n, 3n), 4n);
    assert.equal(reads.mintCounterReadRemaining(mode, 7n, 7n), 0n);
    assert.equal(reads.mintCounterReadRemaining(mode, 7n, 8n), 0n);
  }
  assert.equal(reads.mintCounterProoflessRemaining(pol({ staticCap: 8n, staticIncrement: 5n }), 3n), 5n);
  assert.throws(() => reads.mintCounterProoflessRemaining(pol({ capMode: 3n }), 0n), /ProofRequired/);
  const dynamic = pol({ capMode: 2n }); // Structural read path is separate from config admission.
  assert.equal(reads.resolveMintCounterRead(binding, dynamic, context).resolution.effectiveCap, 0n);
  assert.equal(reads.mintCounterProoflessRemaining(dynamic, 3n), max64 - 3n);
  assert.throws(() => reads.mintCounterReadRemaining(0n, 0n, max64 + 1n), /uint64/);
});

test("immutable inputs, exact keys and full-width validation prevent escaped read-plan mutation", () => {
  const mutable = structuredClone(context), request = { method: "resolveCounter", context: mutable };
  const prepared = reads.prepareMintCounterReadCall(binding.manager, addr(90), request), originalData = prepared.call.data;
  mutable.payer = addr(91); mutable.resolverData = "0x"; request.method = "remainingForResolvedCounter";
  assert.equal(prepared.call.data, originalData); assert.equal(prepared.request.method, "resolveCounter"); assert.equal(prepared.request.context.payer, context.payer);
  assert.ok(Object.isFrozen(prepared)); assert.ok(Object.isFrozen(prepared.request.context)); assert.ok(Object.isFrozen(prepared.call));
  assert.throws(() => reads.normalizeMintCounterReadCall({ ...prepared, call: { ...prepared.call, data: "0x" } }), /differs/);
  assert.throws(() => reads.normalizeMintCounterReadCall({ ...prepared, call: { ...prepared.call, value: 1n } }), /differs/);
  assert.throws(() => reads.prepareMintCounterReadCall(binding.manager, addr(90), { method: "mint", context }));
  assert.throws(() => reads.prepareMintCounterReadCall(binding.manager, addr(90), { method: "resolveCounter", context, signature: "0x" }));
  assert.throws(() => reads.normalizeMintCounterKeyContext({ ...context, collectionId: Number.MAX_SAFE_INTEGER }), /bigint/);
  assert.throws(() => reads.normalizeMintCounterKeyContext({ ...context, tokenIndex: max256 + 1n }), /uint256/);
  assert.throws(() => reads.normalizeMintCounterKeyContext({ ...context, resolverData: "0x0" }), /byte string/);
  assert.throws(() => reads.normalizeMintCounterReadPolicy(pol({ staticCap: max64 + 1n })), /uint64/);
  assert.throws(() => reads.normalizeMintCounterReadPolicy(pol({ keyMode: 7n })), /enum/);
  const mp = proof({ proof: [id("sibling")] }), frozen = reads.normalizeMintCounterAllowlistProof(mp); mp.proof[0] = ZeroHash;
  assert.notEqual(frozen.proof[0], ZeroHash); assert.ok(Object.isFrozen(frozen.proof));
  assert.throws(() => reads.normalizeMintCounterResolution({ subjectKey: ZeroHash, effectiveCap: 0n, increment: 0n, resolutionHash: ZeroHash, current: 0n }), /unknown/);
});
