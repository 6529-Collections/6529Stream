import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, ContractFunctions, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";

export type MintPolicyPhaseConfig = ContractFunctions["manager"]["configurePhase"]["args"][2];
export type MintPolicyGateConfig = ContractFunctions["manager"]["configurePhase"]["args"][3];
export type MintPolicyCounterConfig = ContractFunctions["manager"]["configurePhase"]["args"][5][number];
export type MintPolicyGraceGovernanceCall = ContractFunctions["executor"]["scheduleGovernanceBatch"]["args"][1][number];

/** Original preview coordinates and tuples. Preview hashing is not configuration admission. */
export interface MintPhasePolicyInput {
  readonly chainId: bigint; readonly manager: Address; readonly ledger: Address; readonly moduleRegistry: Address;
  readonly collectionId: bigint; readonly phaseId: Hex;
  readonly config: MintPolicyPhaseConfig; readonly gate: MintPolicyGateConfig;
  readonly counterIds: readonly Hex[]; readonly counterConfigs: readonly MintPolicyCounterConfig[];
  readonly executors: readonly Address[];
}
/** Supplied configured state, including a complete executor inventory; never a claim of live verification. */
export interface MintPolicySnapshot extends MintPhasePolicyInput { readonly currentPolicyHash: Hex }
export interface MintPolicyGraceRequest {
  readonly executor: Address; readonly allowed: boolean; readonly graceUntil: bigint;
}
export interface MintPolicyGracePlan {
  readonly snapshot: MintPolicySnapshot; readonly request: MintPolicyGraceRequest; readonly changed: boolean;
  readonly prospectiveExecutors: readonly Address[]; readonly prospectivePolicyHash: Hex;
  readonly previewCall: UnsignedCall; readonly targetCall: UnsignedCall;
  readonly governanceCall: MintPolicyGraceGovernanceCall; readonly actionClass: 1n; readonly factsVerified: false;
}
export interface MintPolicyGraceGovernanceWindow {
  readonly notBefore: bigint; readonly expiresAfter: bigint; readonly reasonHash: Hex;
  readonly reasonURI: string; readonly manifestHash: Hex;
}
export interface MintPolicyGraceGovernanceBatch {
  readonly plan: MintPolicyGracePlan; readonly governanceExecutor: Address; readonly nonce: bigint;
  readonly window: MintPolicyGraceGovernanceWindow;
  readonly callsHash: Hex; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex;
  readonly actionId: Hex; readonly publicationKey: Hex; readonly publicationCall: UnsignedCall;
  readonly scheduleCall: UnsignedCall; readonly executionCall: UnsignedCall;
}

export const MINT_POLICY_GRACE_INTERFACE_ID = "0xdef72e30" as const;
export const MINT_POLICY_GRACE_MAX_SECONDS = 2_592_000n;
const phaseTuple = "tuple(bool paused,uint64 startTime,uint64 endTime,uint32 maxBatchQuantity,bytes32 configHash,bytes32 metadataHash)";
const gateTuple = "tuple(address gate,bytes32 gateConfigHash,bytes32 gateCodehash,bytes32 gateMetadataHash,uint32 gateSemanticVersion,uint32 gateGasLimit)";
const counterTuple = "tuple(bool enabled,uint8 keyMode,uint8 capMode,uint8 deltaMode,uint64 staticCap,uint64 staticIncrement,bytes32 counterConfigHash)";
const governanceTuple = "tuple(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
export const CURRENT_MINT_POLICY_GRACE_ABI: readonly string[] = Object.freeze([
  `function previewPhasePolicyHash(uint256,bytes32,${phaseTuple},${gateTuple},bytes32[],${counterTuple}[],address[]) view returns(bytes32)`,
  "function setPhaseExecutorWithGrace(uint256 collectionId,bytes32 phaseId,address executor,bool allowed,uint64 graceUntil)",
  "function publishGovernanceCallData(bytes[]) returns(address)",
  `function scheduleGovernanceBatch(uint8,${governanceTuple}[],bytes32,bytes32,bytes32,uint64,uint64,bytes32,string,bytes32) returns(bytes32)`,
  `function executeGovernanceBatch(bytes32,${governanceTuple}[],bytes[]) payable`,
]);
const abi = new Interface(CURRENT_MINT_POLICY_GRACE_ABI), coder = AbiCoder.defaultAbiCoder();
const inputKeys = ["chainId", "manager", "ledger", "moduleRegistry", "collectionId", "phaseId", "config", "gate", "counterIds", "counterConfigs", "executors"];
const phaseKeys = ["paused", "startTime", "endTime", "maxBatchQuantity", "configHash", "metadataHash"];
const gateKeys = ["gate", "gateConfigHash", "gateCodehash", "gateMetadataHash", "gateSemanticVersion", "gateGasLimit"];
const counterKeys = ["enabled", "keyMode", "capMode", "deltaMode", "staticCap", "staticIncrement", "counterConfigHash"];
function exact(value: unknown, keys: readonly string[], label: string): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error(`${label} must be an object`);
  const actual = Reflect.ownKeys(value);
  if (actual.length !== keys.length || actual.some(key => typeof key !== "string" || !keys.includes(key))) throw Error(`${label} has missing or unknown fields`);
}
function uint(value: unknown, bits: number, label: string): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`${label} must be uint${bits} bigint`);
  return value;
}
function address(value: unknown, allowZero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (!allowZero && result === ZeroAddress) throw Error("Expected nonzero address");
  return result;
}
function hash(value: unknown, allowZero = true): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (!allowZero && value.toLowerCase() === ZeroHash)) throw Error("Expected bytes32 with required nonzero value");
  return value.toLowerCase() as Hex;
}
function bool(value: unknown): boolean { if (typeof value !== "boolean") throw Error("Expected boolean"); return value; }
function enumeration(value: unknown, maximum: bigint, label: string): bigint {
  const result = uint(value, 8, label); if (result > maximum) throw Error(`${label} exceeds original enum`); return result;
}
function list<T>(value: readonly T[], maximum: number, label: string): readonly T[] {
  if (!Array.isArray(value) || value.length > maximum || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) throw Error(`${label} must be a dense bounded array`);
  return value;
}
function digest(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(coder.encode(types, values)) as Hex; }
function sorted(executors: readonly Address[]): readonly Address[] {
  return Object.freeze([...executors].sort((a, b) => BigInt(a) < BigInt(b) ? -1 : BigInt(a) > BigInt(b) ? 1 : 0));
}
function policyInput(input: MintPhasePolicyInput): MintPhasePolicyInput {
  exact(input.config, phaseKeys, "Phase config"); exact(input.gate, gateKeys, "Gate config");
  const config = Object.freeze({ paused: bool(input.config.paused), startTime: uint(input.config.startTime, 64, "startTime"),
    endTime: uint(input.config.endTime, 64, "endTime"), maxBatchQuantity: uint(input.config.maxBatchQuantity, 32, "maxBatchQuantity"),
    configHash: hash(input.config.configHash), metadataHash: hash(input.config.metadataHash) });
  const gate = Object.freeze({ gate: address(input.gate.gate, true), gateConfigHash: hash(input.gate.gateConfigHash),
    gateCodehash: hash(input.gate.gateCodehash), gateMetadataHash: hash(input.gate.gateMetadataHash),
    gateSemanticVersion: uint(input.gate.gateSemanticVersion, 32, "gateSemanticVersion"), gateGasLimit: uint(input.gate.gateGasLimit, 32, "gateGasLimit") });
  const counterIds = Object.freeze(list(input.counterIds, 16, "counterIds").map(value => hash(value)));
  const counterConfigs = Object.freeze(list(input.counterConfigs, 16, "counterConfigs").map(value => {
    exact(value, counterKeys, "Counter config");
    return Object.freeze({ enabled: bool(value.enabled), keyMode: enumeration(value.keyMode, 6n, "keyMode"),
      capMode: enumeration(value.capMode, 3n, "capMode"), deltaMode: enumeration(value.deltaMode, 1n, "deltaMode"),
      staticCap: uint(value.staticCap, 64, "staticCap"), staticIncrement: uint(value.staticIncrement, 64, "staticIncrement"),
      counterConfigHash: hash(value.counterConfigHash) });
  }));
  if (counterIds.length !== counterConfigs.length) throw Error("Counter array lengths differ");
  const executors = Object.freeze(list(input.executors, 64, "executors").map(value => address(value, true)));
  return Object.freeze({ chainId: uint(input.chainId, 256, "chainId"), manager: address(input.manager), ledger: address(input.ledger),
    moduleRegistry: address(input.moduleRegistry), collectionId: uint(input.collectionId, 256, "collectionId"), phaseId: hash(input.phaseId),
    config, gate, counterIds, counterConfigs, executors });
}
/** Copies exact ABI inputs. Zero IDs, empty counters and duplicate/zero executors are previewable, not admitted state. */
export function normalizeMintPhasePolicyInput(input: MintPhasePolicyInput): MintPhasePolicyInput {
  exact(input, inputKeys, "Policy input"); return policyInput(input);
}
function policyHash(p: MintPhasePolicyInput): Hex {
  const phaseHash = digest(["bytes32", "uint64", "uint64", "uint32", "bytes32", "bytes32"],
    [id("6529STREAM_MINT_MANAGER_PHASE_CONFIG_V1"), p.config.startTime, p.config.endTime, p.config.maxBatchQuantity, p.config.configHash, p.config.metadataHash]);
  const gateHash = digest(["bytes32", "address", "bytes32", "bytes32", "bytes32", "uint32", "uint32"],
    [id("6529STREAM_MINT_MANAGER_GATE_CONFIG_V1"), p.gate.gate, p.gate.gateConfigHash, p.gate.gateCodehash, p.gate.gateMetadataHash, p.gate.gateSemanticVersion, p.gate.gateGasLimit]);
  const counterHashes = p.counterConfigs.map((c, i) => digest(["bytes32", "bytes32", "bool", "uint8", "uint8", "uint8", "uint64", "uint64", "bytes32"],
    [id("6529STREAM_MINT_MANAGER_COUNTER_CONFIG_V1"), p.counterIds[i], c.enabled, c.keyMode, c.capMode, c.deltaMode, c.staticCap, c.staticIncrement, c.counterConfigHash]));
  const countersHash = digest(["bytes32[]"], [counterHashes]);
  const executorsHash = digest(["bytes32", "address[]"], [id("6529STREAM_MINT_MANAGER_EXECUTOR_SET_V1"), sorted(p.executors)]);
  const preimage = "tuple(uint256 chainId,address manager,address ledger,address moduleRegistry,uint16 schemaVersion,uint256 collectionId,bytes32 phaseId,bytes32 phaseConfigHash,bytes32 gateConfigHash,bytes32 orderedCounterConfigHash,bytes32 executorSetHash)";
  return digest(["bytes32", preimage], [id("6529STREAM_MINT_MANAGER_POLICY_V1"),
    [p.chainId, p.manager, p.ledger, p.moduleRegistry, 1n, p.collectionId, p.phaseId, phaseHash, gateHash, countersHash, executorsHash]]);
}
/** Original preview hash: counter order matters, executor order does not; pause, Core and grace are absent. */
export function mintPhasePolicyHash(input: MintPhasePolicyInput): Hex { return policyHash(normalizeMintPhasePolicyInput(input)); }

/** Checks configured-state invariants and the supplied complete policy identity, not live code, authority or admission. */
export function normalizeMintPolicySnapshot(input: MintPolicySnapshot): MintPolicySnapshot {
  exact(input, [...inputKeys, "currentPolicyHash"], "Policy snapshot");
  const p = policyInput(input), currentPolicyHash = hash(input.currentPolicyHash, false);
  if (p.collectionId === 0n || p.phaseId === ZeroHash) throw Error("Configured phase requires nonzero identity");
  if (p.config.maxBatchQuantity === 0n || p.config.maxBatchQuantity > 10n
    || (p.config.startTime !== 0n && p.config.endTime !== 0n && p.config.endTime < p.config.startTime)) throw Error("Invalid configured phase limits");
  if (p.counterIds.length === 0 || p.counterIds.some(value => value === ZeroHash) || new Set(p.counterIds).size !== p.counterIds.length) throw Error("Configured counters must be nonempty, nonzero and distinct");
  for (const c of p.counterConfigs) {
    if (!c.enabled || c.keyMode === 0n || c.deltaMode !== 0n || c.capMode === 2n || c.staticIncrement === 0n || c.counterConfigHash === ZeroHash
      || (c.capMode === 0n ? c.staticCap !== 0n : c.staticCap === 0n)) throw Error("Unsupported configured counter");
  }
  if (p.gate.gate === ZeroAddress) {
    if (p.gate.gateConfigHash !== ZeroHash || p.gate.gateCodehash !== ZeroHash || p.gate.gateMetadataHash !== ZeroHash
      || p.gate.gateSemanticVersion !== 0n || p.gate.gateGasLimit !== 0n) throw Error("Absent gate requires the original all-zero tuple");
  } else if (p.gate.gateConfigHash === ZeroHash || p.gate.gateCodehash === ZeroHash) throw Error("Configured gate requires original config and runtime hashes");
  if (p.executors.some(value => value === ZeroAddress) || new Set(p.executors).size !== p.executors.length) throw Error("Configured executors must be nonzero and distinct");
  if (policyHash(p) !== currentPolicyHash) throw Error("Supplied complete policy differs from currentPolicyHash");
  return Object.freeze({ ...p, executors: sorted(p.executors), currentPolicyHash });
}
export function normalizeMintPolicyGraceRequest(input: MintPolicyGraceRequest): MintPolicyGraceRequest {
  exact(input, ["executor", "allowed", "graceUntil"], "Grace request");
  return Object.freeze({ executor: address(input.executor), allowed: bool(input.allowed), graceUntil: uint(input.graceUntil, 64, "graceUntil") });
}
/** Explicit execution-time check. Past nonzero deadlines are valid; no local clock or guessed governance execution date. */
export function assertMintPolicyGraceDeadline(graceUntil: bigint, executionTimestamp: bigint): void {
  const until = uint(graceUntil, 64, "graceUntil"), at = uint(executionTimestamp, 256, "executionTimestamp");
  if (until !== 0n && (at > ((1n << 256n) - 1n) - MINT_POLICY_GRACE_MAX_SECONDS || until > at + MINT_POLICY_GRACE_MAX_SECONDS)) throw Error("Grace deadline exceeds execution plus 30 days");
}
function targetCall(to: Address, method: string, args: readonly unknown[]): UnsignedCall {
  return Object.freeze({ to, value: 0n, data: abi.encodeFunctionData(method, args) as Hex });
}
/**
 * Exact one-executor proposal. The setter has no expected-policy guard: this snapshot is not an onchain CAS.
 * Unchanged + zero grace is an event-free no-op preserving any live grace tuple. New policy consent and
 * current Manager admission remain external prerequisites; no Artist signature is invented here.
 */
export function prepareMintPolicyGraceChange(input: MintPolicySnapshot, change: MintPolicyGraceRequest): MintPolicyGracePlan {
  const snapshot = normalizeMintPolicySnapshot(input), request = normalizeMintPolicyGraceRequest(change);
  const present = snapshot.executors.includes(request.executor), changed = present !== request.allowed;
  if (!changed && request.graceUntil !== 0n) throw Error("Unchanged executor cannot set or extend grace");
  const prospectiveExecutors = sorted(!changed ? snapshot.executors : request.allowed
    ? [...snapshot.executors, request.executor] : snapshot.executors.filter(value => value !== request.executor));
  if (prospectiveExecutors.length > 64) throw Error("Configured executor limit exceeds 64");
  const prospectivePolicyHash = policyHash({ ...snapshot, executors: prospectiveExecutors });
  const previewCall = targetCall(snapshot.manager, "previewPhasePolicyHash", [snapshot.collectionId, snapshot.phaseId,
    snapshot.config, snapshot.gate, snapshot.counterIds, snapshot.counterConfigs, prospectiveExecutors]);
  const call = targetCall(snapshot.manager, "setPhaseExecutorWithGrace", [snapshot.collectionId, snapshot.phaseId, request.executor, request.allowed, request.graceUntil]);
  const dataHash = keccak256(call.data) as Hex;
  const governanceCall = Object.freeze({ target: call.to, value: 0n, selector: MINT_POLICY_GRACE_INTERFACE_ID,
    callDataHash: dataHash, scopeHash: digest(["address", "bytes"], [call.to, call.data]), oldValueHash: ZeroHash as Hex, newValueHash: dataHash });
  return Object.freeze({ snapshot, request, changed, prospectiveExecutors, prospectivePolicyHash, previewCall, targetCall: call,
    governanceCall, actionClass: 1n, factsVerified: false });
}
function sameTree(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (!a || !b || typeof a !== "object" || typeof b !== "object" || Array.isArray(a) !== Array.isArray(b)) return false;
  const keys = Reflect.ownKeys(a), other = Reflect.ownKeys(b);
  return keys.length === other.length && keys.every(key => other.includes(key) && sameTree(Reflect.get(a, key), Reflect.get(b, key)));
}
export function normalizeMintPolicyGracePlan(input: MintPolicyGracePlan): MintPolicyGracePlan {
  exact(input, ["snapshot", "request", "changed", "prospectiveExecutors", "prospectivePolicyHash", "previewCall", "targetCall", "governanceCall", "actionClass", "factsVerified"], "Grace plan");
  const result = prepareMintPolicyGraceChange(input.snapshot, input.request);
  if (!sameTree(input, result)) throw Error("Grace plan differs from exact reconstruction"); return result;
}
export function normalizeMintPolicyGraceGovernanceWindow(input: MintPolicyGraceGovernanceWindow): MintPolicyGraceGovernanceWindow {
  exact(input, ["notBefore", "expiresAfter", "reasonHash", "reasonURI", "manifestHash"], "Governance window");
  const notBefore = uint(input.notBefore, 64, "notBefore"), expiresAfter = uint(input.expiresAfter, 64, "expiresAfter");
  if (expiresAfter < notBefore + 604_800n) throw Error("Class 1 requires at least seven days of open execution window");
  if (typeof input.reasonURI !== "string") throw Error("reasonURI must be Unicode text");
  for (const character of input.reasonURI) { const point = character.codePointAt(0)!; if (point >= 0xd800 && point <= 0xdfff) throw Error("reasonURI must contain Unicode scalars"); }
  toUtf8Bytes(input.reasonURI);
  return Object.freeze({ notBefore, expiresAfter, reasonHash: hash(input.reasonHash), reasonURI: input.reasonURI, manifestHash: hash(input.manifestHash) });
}
/** Original batch of one. The supplied Executor/nonce/window are not proof of catalog, proposer or live scheduling admission. */
export function mintPolicyGraceGovernanceBatch(input: MintPolicyGracePlan, governanceExecutor: Address, nonce: bigint,
  window: MintPolicyGraceGovernanceWindow): MintPolicyGraceGovernanceBatch {
  const plan = normalizeMintPolicyGracePlan(input), executor = address(governanceExecutor), n = uint(nonce, 256, "Governance nonce"), w = normalizeMintPolicyGraceGovernanceWindow(window);
  const calls = [plan.governanceCall], data = [plan.targetCall.data];
  const callsHash = digest(["bytes32", `${governanceTuple}[]`], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain: Hex, field: "scopeHash" | "oldValueHash" | "newValueHash") => digest(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, calls.map(call => call[field])]);
  const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash");
  const oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash");
  const newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
  const actionId = digest(["bytes32", "uint256", "address", "tuple(uint8,bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64,bytes32,bytes32)"],
    ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", plan.snapshot.chainId, executor,
      [1n, callsHash, scopeHash, oldValueHash, newValueHash, n, w.notBefore, w.expiresAfter, w.reasonHash, w.manifestHash]]);
  const publicationKey = keccak256(plan.governanceCall.callDataHash) as Hex;
  return Object.freeze({ plan, governanceExecutor: executor, nonce: n, window: w, callsHash, scopeHash, oldValueHash, newValueHash, actionId, publicationKey,
    publicationCall: targetCall(executor, "publishGovernanceCallData", [data]),
    scheduleCall: targetCall(executor, "scheduleGovernanceBatch", [1n, calls, scopeHash, oldValueHash, newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash]),
    executionCall: targetCall(executor, "executeGovernanceBatch", [actionId, calls, data]) });
}
export function normalizeMintPolicyGraceGovernanceBatch(input: MintPolicyGraceGovernanceBatch): MintPolicyGraceGovernanceBatch {
  exact(input, ["plan", "governanceExecutor", "nonce", "window", "callsHash", "scopeHash", "oldValueHash", "newValueHash", "actionId", "publicationKey", "publicationCall", "scheduleCall", "executionCall"], "Grace governance batch");
  const result = mintPolicyGraceGovernanceBatch(input.plan, input.governanceExecutor, input.nonce, input.window);
  if (!sameTree(input, result)) throw Error("Grace governance batch differs from exact reconstruction"); return result;
}
