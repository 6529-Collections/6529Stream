import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { MintCounterDefinition } from "./current-mint-continuity.js";
import type { MintPolicyCounterConfig } from "./current-mint-policy-grace.js";

/** Original single-row context. The read caller is independent of every address here. */
export interface MintCounterKeyContext {
  readonly collectionId: bigint; readonly phaseId: Hex; readonly counterId: Hex;
  readonly payer: Address; readonly initialRecipient: Address; readonly beneficiary: Address;
  readonly executor: Address; readonly authorizer: Address; readonly tokenIndex: bigint;
  readonly contextHash: Hex; readonly resolverData: Hex;
}
export interface MintCounterResolution {
  readonly subjectKey: Hex; readonly effectiveCap: bigint; readonly increment: bigint; readonly resolutionHash: Hex;
}
export interface MintCounterReadBinding { readonly chainId: bigint; readonly manager: Address; readonly ledger: Address }
/** Supplied observations, not a claim of live configuration or definition admission. */
export interface MintCounterReadPolicy {
  readonly phaseExists: boolean; readonly config: MintPolicyCounterConfig;
  readonly definitionExists: boolean; readonly definition: MintCounterDefinition;
}
export interface MintCounterAllowlistProof {
  readonly maxCount: bigint; readonly hasPriceOverride: boolean; readonly priceOverride: bigint; readonly proof: readonly Hex[];
}
export interface MintCounterReadScope { readonly collectionId: bigint; readonly phaseId: Hex }
export interface MintCounterReadSubject extends MintCounterReadScope { readonly counterId: Hex; readonly subjectKey: Hex }
export interface MintCounterReadResolution {
  readonly resolution: MintCounterResolution; readonly valueKey: Hex; readonly preScopeSubjectKey: Hex;
  readonly scopedCollectionId: bigint; readonly scopedPhaseId: Hex;
}
export type MintCounterReadRequest =
  | { readonly method: "rawCounterValue"; readonly valueKey: Hex }
  | ({ readonly method: "counterValue" | "remainingForCounter" } & MintCounterReadSubject)
  | { readonly method: "resolveCounter" | "remainingForResolvedCounter"; readonly context: MintCounterKeyContext };
/** An eth_call description only; there is no transaction, signature or admission result. */
export interface MintCounterReadCall {
  readonly manager: Address; readonly caller: Address; readonly request: MintCounterReadRequest; readonly call: UnsignedCall;
}

export const MINT_COUNTER_READS_INTERFACE_ID = "0xe96c52f4" as const;
export const MINT_COUNTER_READ_CONTEXT_TUPLE = "tuple(uint256 collectionId,bytes32 phaseId,bytes32 counterId,address payer,address initialRecipient,address beneficiary,address executor,address authorizer,uint256 tokenIndex,bytes32 contextHash,bytes resolverData)";
export const MINT_COUNTER_READ_RESOLUTION_TUPLE = "tuple(bytes32 subjectKey,uint64 effectiveCap,uint64 increment,bytes32 resolutionHash)";
export const MINT_COUNTER_ALLOWLIST_PROOF_TUPLE = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)";
export const CURRENT_MINT_COUNTER_READS_ABI: readonly string[] = Object.freeze([
  "function rawCounterValue(bytes32 valueKey) view returns(uint64)",
  "function counterValue(uint256 collectionId,bytes32 phaseId,bytes32 counterId,bytes32 subjectKey) view returns(uint64)",
  "function remainingForCounter(uint256 collectionId,bytes32 phaseId,bytes32 counterId,bytes32 subjectKey) view returns(uint64)",
  `function resolveCounter(${MINT_COUNTER_READ_CONTEXT_TUPLE} context) view returns(${MINT_COUNTER_READ_RESOLUTION_TUPLE} resolution)`,
  `function remainingForResolvedCounter(${MINT_COUNTER_READ_CONTEXT_TUPLE} context) view returns(${MINT_COUNTER_READ_RESOLUTION_TUPLE} resolution,uint64 current,uint64 remaining)`,
]);
const abi = new Interface(CURRENT_MINT_COUNTER_READS_ABI), coder = AbiCoder.defaultAbiCoder();
const MAX64 = (1n << 64n) - 1n, MAX256 = (1n << 256n) - 1n;
const contextKeys = ["collectionId", "phaseId", "counterId", "payer", "initialRecipient", "beneficiary", "executor", "authorizer", "tokenIndex", "contextHash", "resolverData"];
const subjectKeys = ["collectionId", "phaseId", "counterId", "subjectKey"];
function exact(value: unknown, keys: readonly string[], label: string): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error(`${label} must be an object`);
  const actual = Reflect.ownKeys(value);
  if (actual.length !== keys.length || actual.some(key => typeof key !== "string" || !keys.includes(key))) throw Error(`${label} has missing or unknown fields`);
}
function uint(value: unknown, bits: number, label: string): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`${label} must be uint${bits} bigint`);
  return value;
}
function enumeration(value: unknown, max: bigint, label: string): bigint {
  const result = uint(value, 8, label); if (result > max) throw Error(`${label} exceeds original enum`); return result;
}
function bool(value: unknown): boolean { if (typeof value !== "boolean") throw Error("Expected boolean"); return value; }
function address(value: unknown, allowZero = true): Address {
  if (typeof value !== "string") throw Error("Expected address"); const result = getAddress(value) as Address;
  if (!allowZero && result === ZeroAddress) throw Error("Expected nonzero address"); return result;
}
function hash(value: unknown): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)) throw Error("Expected bytes32"); return value.toLowerCase() as Hex;
}
function bytes(value: unknown): Hex {
  if (typeof value !== "string" || !isHexString(value, true)) throw Error("Expected byte string"); return value.toLowerCase() as Hex;
}
function hashes(value: readonly Hex[]): readonly Hex[] {
  if (!Array.isArray(value) || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) throw Error("Proof must be a dense array");
  return Object.freeze(value.map(hash));
}
function digest(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(coder.encode(types, values)) as Hex; }

export function normalizeMintCounterKeyContext(input: MintCounterKeyContext): MintCounterKeyContext {
  exact(input, contextKeys, "Counter context");
  return Object.freeze({ collectionId: uint(input.collectionId, 256, "collectionId"), phaseId: hash(input.phaseId), counterId: hash(input.counterId),
    payer: address(input.payer), initialRecipient: address(input.initialRecipient), beneficiary: address(input.beneficiary),
    executor: address(input.executor), authorizer: address(input.authorizer), tokenIndex: uint(input.tokenIndex, 256, "tokenIndex"),
    contextHash: hash(input.contextHash), resolverData: bytes(input.resolverData) });
}
export function normalizeMintCounterResolution(input: MintCounterResolution): MintCounterResolution {
  exact(input, ["subjectKey", "effectiveCap", "increment", "resolutionHash"], "Counter resolution");
  return Object.freeze({ subjectKey: hash(input.subjectKey), effectiveCap: uint(input.effectiveCap, 64, "effectiveCap"),
    increment: uint(input.increment, 64, "increment"), resolutionHash: hash(input.resolutionHash) });
}
export function normalizeMintCounterReadBinding(input: MintCounterReadBinding): MintCounterReadBinding {
  exact(input, ["chainId", "manager", "ledger"], "Counter binding");
  return Object.freeze({ chainId: uint(input.chainId, 256, "chainId"), manager: address(input.manager, false), ledger: address(input.ledger, false) });
}
/** Structural ABI normalization deliberately does not apply counter-registration restrictions. */
export function normalizeMintCounterReadPolicy(input: MintCounterReadPolicy): MintCounterReadPolicy {
  exact(input, ["phaseExists", "config", "definitionExists", "definition"], "Counter policy");
  const c = input.config, d = input.definition;
  exact(c, ["enabled", "keyMode", "capMode", "deltaMode", "staticCap", "staticIncrement", "counterConfigHash"], "Counter config");
  exact(d, ["scope", "keyMode", "capRoot", "metadataHash"], "Counter definition");
  return Object.freeze({ phaseExists: bool(input.phaseExists), definitionExists: bool(input.definitionExists),
    config: Object.freeze({ enabled: bool(c.enabled), keyMode: enumeration(c.keyMode, 6n, "keyMode"), capMode: enumeration(c.capMode, 3n, "capMode"),
      deltaMode: enumeration(c.deltaMode, 1n, "deltaMode"), staticCap: uint(c.staticCap, 64, "staticCap"),
      staticIncrement: uint(c.staticIncrement, 64, "staticIncrement"), counterConfigHash: hash(c.counterConfigHash) }),
    definition: Object.freeze({ scope: enumeration(d.scope, 2n, "scope"), keyMode: enumeration(d.keyMode, 6n, "definition.keyMode"),
      capRoot: hash(d.capRoot), metadataHash: hash(d.metadataHash) }) });
}
export function normalizeMintCounterAllowlistProof(input: MintCounterAllowlistProof): MintCounterAllowlistProof {
  exact(input, ["maxCount", "hasPriceOverride", "priceOverride", "proof"], "Allowlist proof");
  return Object.freeze({ maxCount: uint(input.maxCount, 64, "maxCount"), hasPriceOverride: bool(input.hasPriceOverride),
    priceOverride: uint(input.priceOverride, 256, "priceOverride"), proof: hashes(input.proof) });
}
/** Encodes exactly one proof. Mint-batch resolverData has a different nested-array format. */
export function encodeMintCounterAllowlistProof(input: MintCounterAllowlistProof): Hex {
  return coder.encode([MINT_COUNTER_ALLOWLIST_PROOF_TUPLE], [normalizeMintCounterAllowlistProof(input)]) as Hex;
}
export function decodeMintCounterAllowlistProof(encoded: Hex): MintCounterAllowlistProof {
  const canonical = bytes(encoded);
  const value = coder.decode([MINT_COUNTER_ALLOWLIST_PROOF_TUPLE], canonical)[0];
  const proof = normalizeMintCounterAllowlistProof({ maxCount: value[0], hasPriceOverride: value[1], priceOverride: value[2], proof: Array.from(value[3]) });
  if (encodeMintCounterAllowlistProof(proof) !== canonical) throw Error("MintCounterProofEncodingInvalid: expected canonical single proof");
  return proof;
}
/** The leaf helper hashes structural inputs; resolution separately validates price and cap. */
export function mintCounterAllowlistLeaf(binding: MintCounterReadBinding, collectionId: bigint, phaseId: Hex, counterId: Hex,
  account: Address, input: MintCounterAllowlistProof): Hex {
  const b = normalizeMintCounterReadBinding(binding), p = normalizeMintCounterAllowlistProof(input);
  return keccak256(digest(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256"],
    [id("6529STREAM_MINT_ALLOWLIST_LEAF_V1"), b.chainId, b.manager, uint(collectionId, 256, "collectionId"), hash(phaseId), hash(counterId),
      address(account), p.maxCount, p.hasPriceOverride, p.priceOverride])) as Hex;
}
export function verifyMintCounterAllowlistProof(root: Hex, leaf: Hex, proof: readonly Hex[]): boolean {
  const expected = hash(root); let computed = hash(leaf);
  for (const sibling of hashes(proof)) computed = digest(["bytes32", "bytes32"], BigInt(computed) < BigInt(sibling) ? [computed, sibling] : [sibling, computed]);
  return computed === expected;
}
export function mintCounterReadScope(policy: MintCounterReadPolicy, collectionId: bigint, phaseId: Hex): MintCounterReadScope {
  const p = normalizeMintCounterReadPolicy(policy), cid = uint(collectionId, 256, "collectionId"), phase = hash(phaseId);
  const scope = p.definitionExists ? p.definition.scope : 2n;
  return Object.freeze({ collectionId: scope === 0n ? 0n : cid, phaseId: scope === 2n ? phase : ZeroHash as Hex });
}
function assertConfigured(p: MintCounterReadPolicy, collectionId: bigint, phaseId: Hex): void {
  if (collectionId === 0n || phaseId === ZeroHash) throw Error("InvalidMintPhase");
  if (!p.phaseExists) throw Error("MintPhaseDoesNotExist");
  if (!p.config.enabled) throw Error("InvalidMintCounter: disabled");
}
function valueKey(manager: Address, scope: MintCounterReadScope, counterId: Hex, subject: Hex): Hex {
  return digest(["bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"), manager, scope.collectionId, scope.phaseId, counterId, subject]);
}
/** Supplied subject is preserved, including for CONSTANT; only collection/phase are scoped. */
export function mintCounterReadValueKey(binding: MintCounterReadBinding, policy: MintCounterReadPolicy, input: MintCounterReadSubject): Hex {
  const b = normalizeMintCounterReadBinding(binding), p = normalizeMintCounterReadPolicy(policy);
  exact(input, subjectKeys, "Counter subject");
  const cid = uint(input.collectionId, 256, "collectionId"), phase = hash(input.phaseId), counter = hash(input.counterId), subject = hash(input.subjectKey);
  assertConfigured(p, cid, phase); if (subject === ZeroHash) throw Error("InvalidMintCounter: zero subject");
  return valueKey(b.manager, mintCounterReadScope(p, cid, phase), counter, subject);
}
function subjectKey(b: MintCounterReadBinding, keyMode: bigint, x: MintCounterKeyContext, scope: MintCounterReadScope): Hex {
  const prefix = [id("6529STREAM_MINT_COUNTER_SUBJECT_V1"), b.chainId, b.ledger, keyMode];
  const types = ["bytes32", "uint256", "address", "uint8"];
  if (keyMode === 1n) return digest([...types, "uint256", "bytes32", "bytes32"], [...prefix, scope.collectionId, scope.phaseId, x.counterId]);
  if (keyMode === 6n) {
    if (x.contextHash === ZeroHash) throw Error("MintCounterSubjectMissing: contextHash");
    return digest([...types, "bytes32"], [...prefix, x.contextHash]);
  }
  const account = keyMode === 2n ? x.payer : keyMode === 3n ? x.beneficiary : keyMode === 4n ? x.executor : keyMode === 5n ? x.authorizer : ZeroAddress;
  if (account === ZeroAddress) throw Error("MintCounterSubjectMissing: account or keyMode");
  return digest([...types, "address"], [...prefix, account]);
}
/** Replays only the original single-row accounting resolver, not mint admission or a batch proof. */
export function resolveMintCounterRead(binding: MintCounterReadBinding, policy: MintCounterReadPolicy, context: MintCounterKeyContext): MintCounterReadResolution {
  const b = normalizeMintCounterReadBinding(binding), p = normalizeMintCounterReadPolicy(policy), x = normalizeMintCounterKeyContext(context), c = p.config;
  assertConfigured(p, x.collectionId, x.phaseId);
  if (c.keyMode === 6n ? x.tokenIndex !== MAX256 : x.tokenIndex >= 10n) throw Error("MintCounterTokenIndexInvalid");
  const originalScope = { collectionId: x.collectionId, phaseId: x.phaseId }, scope = mintCounterReadScope(p, x.collectionId, x.phaseId);
  const preScopeSubjectKey = subjectKey(b, c.keyMode, x, originalScope);
  let resolutionHash = digest(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint256", "bytes32"],
    [id("6529STREAM_MINT_COUNTER_RESOLUTION_V1"), b.chainId, b.manager, b.ledger, x.collectionId, x.phaseId, x.counterId, preScopeSubjectKey, x.tokenIndex, c.counterConfigHash]);
  const subject = c.keyMode === 1n ? subjectKey(b, c.keyMode, x, scope) : preScopeSubjectKey;
  let effectiveCap = c.capMode === 1n ? c.staticCap : 0n;
  if (c.capMode === 3n) {
    const proof = decodeMintCounterAllowlistProof(x.resolverData);
    if (!proof.hasPriceOverride && proof.priceOverride !== 0n) throw Error("MintAllowlistPriceOverrideUnsupported");
    const account = c.keyMode === 2n ? x.payer : c.keyMode === 6n ? ZeroAddress as Address : x.beneficiary;
    const leaf = mintCounterAllowlistLeaf(b, x.collectionId, x.phaseId, x.counterId, account, proof);
    if (proof.maxCount === 0n || proof.maxCount > c.staticCap || !verifyMintCounterAllowlistProof(p.definition.capRoot, leaf, proof.proof)) throw Error("MintAllowlistProofInvalid");
    effectiveCap = proof.maxCount;
    resolutionHash = digest(["bytes32", "bytes32", "bytes32"], [id("6529STREAM_MINT_ALLOWLIST_RESOLUTION_V1"), resolutionHash, leaf]);
  }
  return Object.freeze({ resolution: Object.freeze({ subjectKey: subject, effectiveCap, increment: c.staticIncrement, resolutionHash }),
    valueKey: valueKey(b.manager, scope, x.counterId, subject), preScopeSubjectKey, scopedCollectionId: scope.collectionId, scopedPhaseId: scope.phaseId });
}
export function mintCounterReadRemaining(capMode: bigint, effectiveCap: bigint, current: bigint): bigint {
  const mode = enumeration(capMode, 3n, "capMode"), cap = uint(effectiveCap, 64, "effectiveCap"), value = uint(current, 64, "current");
  return mode === 0n ? MAX64 - value : value >= cap ? 0n : cap - value;
}
export function mintCounterProoflessRemaining(policy: MintCounterReadPolicy, current: bigint): bigint {
  const p = normalizeMintCounterReadPolicy(policy);
  if (!p.phaseExists) throw Error("MintPhaseDoesNotExist"); if (!p.config.enabled) throw Error("InvalidMintCounter: disabled");
  if (p.config.capMode === 3n) throw Error("MintCounterProofRequired");
  return mintCounterReadRemaining(p.config.capMode, p.config.staticCap, current);
}
/** Normalizes ABI inputs only; disabled/missing phases or invalid subjects can still be queried. */
export function normalizeMintCounterReadRequest(input: MintCounterReadRequest): MintCounterReadRequest {
  if (!input || typeof input !== "object") throw Error("Expected counter read request");
  if (input.method === "rawCounterValue") {
    exact(input, ["method", "valueKey"], "Raw counter read"); return Object.freeze({ method: input.method, valueKey: hash(input.valueKey) });
  }
  if (input.method === "counterValue" || input.method === "remainingForCounter") {
    exact(input, ["method", ...subjectKeys], "Subject counter read");
    return Object.freeze({ method: input.method, collectionId: uint(input.collectionId, 256, "collectionId"), phaseId: hash(input.phaseId),
      counterId: hash(input.counterId), subjectKey: hash(input.subjectKey) });
  }
  if (input.method === "resolveCounter" || input.method === "remainingForResolvedCounter") {
    exact(input, ["method", "context"], "Resolved counter read"); return Object.freeze({ method: input.method, context: normalizeMintCounterKeyContext(input.context) });
  }
  throw Error("Unknown counter read method");
}
export function prepareMintCounterReadCall(manager: Address, caller: Address, input: MintCounterReadRequest): MintCounterReadCall {
  const target = address(manager, false), actor = address(caller), request = normalizeMintCounterReadRequest(input);
  const args = request.method === "rawCounterValue" ? [request.valueKey] : "context" in request ? [request.context]
    : [request.collectionId, request.phaseId, request.counterId, request.subjectKey];
  return Object.freeze({ manager: target, caller: actor, request,
    call: Object.freeze({ to: target, data: abi.encodeFunctionData(request.method, args) as Hex, value: 0n }) });
}
/** Rebuilds all derived calldata before async use and rejects a substituted call. */
export function normalizeMintCounterReadCall(input: MintCounterReadCall): MintCounterReadCall {
  exact(input, ["manager", "caller", "request", "call"], "Counter read call");
  exact(input.call, ["to", "data", "value"], "Counter view call");
  const rebuilt = prepareMintCounterReadCall(input.manager, input.caller, input.request);
  if (address(input.call.to, false) !== rebuilt.call.to || bytes(input.call.data) !== rebuilt.call.data || input.call.value !== 0n) throw Error("Counter read call differs from request");
  return rebuilt;
}
