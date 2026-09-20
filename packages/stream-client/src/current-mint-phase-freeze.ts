import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { MintCounterDefinition } from "./current-mint-continuity.js";
import { normalizeMintPhasePolicyInput, type MintPhasePolicyInput, type MintPolicyGraceGovernanceCall,
  type MintPolicyGraceGovernanceWindow } from "./current-mint-policy-grace.js";

export interface MintPhaseFreezeCoordinates {
  readonly chainId: bigint; readonly core: Address; readonly manager: Address; readonly ledger: Address;
  readonly governanceExecutor: Address; readonly collectionId: bigint; readonly phaseId: Hex;
}
/** First-frozen policy provenance. It is not necessarily the current successor policy or consent. */
export interface MintPhaseFreezeRecord { readonly policyHash: Hex; readonly configurationHash: Hex }
/** Supplied observations only. An unconfigured successor may have currentPolicyHash=0 and an inherited record. */
export interface MintPhaseFreezeSnapshot extends MintPhaseFreezeCoordinates {
  readonly currentPolicyHash: Hex; readonly record: MintPhaseFreezeRecord;
}
export interface MintPhaseFreezeSelectorConfig {
  readonly enabled: boolean; readonly targetCodeHash: Hex; readonly revision: bigint; readonly stateHash: Hex;
}
export interface MintPhaseFreezeClassifierSnapshot {
  readonly chainId: bigint; readonly governanceExecutor: Address; readonly manager: Address;
  readonly managerCodeHash: Hex; readonly config: MintPhaseFreezeSelectorConfig;
}
export interface MintPhaseFreezeTransition { readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex }
export type MintPhaseFreezeGovernanceCall = MintPolicyGraceGovernanceCall;
interface MintPhaseFreezePlanBase {
  readonly chainId: bigint; readonly governanceExecutor: Address; readonly targetCall: UnsignedCall;
  readonly governanceCall: MintPhaseFreezeGovernanceCall; readonly transition: MintPhaseFreezeTransition; readonly factsVerified: false;
}
export type MintPhaseFreezePlan = MintPhaseFreezePlanBase & (
  { readonly kind: "freeze"; readonly snapshot: MintPhaseFreezeSnapshot; readonly actionClass: 2n }
  | { readonly kind: "classifier"; readonly snapshot: MintPhaseFreezeClassifierSnapshot; readonly actionClass: 0n });
export interface MintPhaseFreezeRoyaltyPolicy {
  readonly configured: boolean; readonly applicationConfigHash: Hex; readonly resolver: Address;
  readonly resolverRuntimeHash: Hex; readonly electionHash: Hex; readonly expectedModeAssignmentHash: Hex;
  readonly expectedSourceRoyaltyPolicyHash: Hex;
}
/** Full ordered effective definitions and raw royalty fields; no supplied value establishes onchain selection. */
export interface MintPhaseFreezeConfigurationInput extends Omit<MintPhasePolicyInput, "executors"> {
  readonly core: Address; readonly defined: readonly boolean[]; readonly definitions: readonly MintCounterDefinition[];
  readonly royalty: MintPhaseFreezeRoyaltyPolicy;
}
export type MintPhaseFreezeGovernanceWindow = MintPolicyGraceGovernanceWindow;
export interface MintPhaseFreezeGovernanceBatch {
  readonly plan: MintPhaseFreezePlan; readonly nonce: bigint; readonly window: MintPhaseFreezeGovernanceWindow;
  readonly callsHash: Hex; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex;
  readonly actionId: Hex; readonly publicationKey: Hex; readonly publicationCall: UnsignedCall;
  readonly scheduleCall: UnsignedCall; readonly executionCall: UnsignedCall;
}
export interface MintPhaseFreezeImportPlan {
  readonly ledger: Address; readonly caller: Address; readonly importRoot: Hex; readonly maxCount: bigint;
  readonly call: UnsignedCall; readonly factsVerified: false;
}

export const MINT_PHASE_FREEZE_INTERFACE_ID = "0x75408bb0" as const;
export const MINT_LEDGER_PHASE_FREEZE_INTERFACE_ID = "0x364317e1" as const;
export const MINT_PHASE_FREEZE_SELECTOR = "0xaf55aad7" as const;
export const MINT_PHASE_FREEZE_MINIMUM_DELAY = 259200n;
export const MINT_PHASE_FREEZE_MINIMUM_OPEN_WINDOW = 604800n;
export const MINT_PHASE_FREEZE_MAXIMUM_LIFETIME = 31536000n;
export const MINT_PHASE_FREEZE_PHASE_TUPLE = "tuple(bool paused,uint64 startTime,uint64 endTime,uint32 maxBatchQuantity,bytes32 configHash,bytes32 metadataHash)";
export const MINT_PHASE_FREEZE_GATE_TUPLE = "tuple(address gate,bytes32 gateConfigHash,bytes32 gateCodehash,bytes32 gateMetadataHash,uint32 gateSemanticVersion,uint32 gateGasLimit)";
export const MINT_PHASE_FREEZE_COUNTER_TUPLE = "tuple(bool enabled,uint8 keyMode,uint8 capMode,uint8 deltaMode,uint64 staticCap,uint64 staticIncrement,bytes32 counterConfigHash)";
export const MINT_PHASE_FREEZE_DEFINITION_TUPLE = "tuple(uint8 scope,uint8 keyMode,bytes32 capRoot,bytes32 metadataHash)";
export const MINT_PHASE_FREEZE_ROYALTY_TUPLE = "tuple(bool configured,bytes32 applicationConfigHash,address resolver,bytes32 resolverRuntimeHash,bytes32 electionHash,bytes32 expectedModeAssignmentHash,bytes32 expectedSourceRoyaltyPolicyHash)";
export const MINT_PHASE_FREEZE_RECORD_TUPLE = "tuple(bytes32 policyHash,bytes32 configurationHash)";
export const MINT_PHASE_FREEZE_GOVERNANCE_CALL_TUPLE = "tuple(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
export const CURRENT_MINT_PHASE_FREEZE_ABI: readonly string[] = Object.freeze([
  "function freezePhase(uint256 collectionId,bytes32 phaseId)",
  "function phaseFrozen(uint256 collectionId,bytes32 phaseId) view returns(bool)",
  "function phaseExecutors(uint256 collectionId,bytes32 phaseId) view returns(address[])",
  "function phaseFreezeTransitionHashes(uint256 collectionId,bytes32 phaseId) view returns(bytes32 scope,bytes32 oldHash,bytes32 newHash)",
  "event MintPhaseFrozen(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed phaseId,bool frozen,bytes32 policyHash)",
  "function freezeSelectorConfig(address target,bytes4 selector) view returns(bool freeze,bytes32 targetCodeHash,uint64 revision,bytes32 stateHash)",
  "function registerFreezeSelector(address target,bytes4 selector,bool freeze)",
  "function publishGovernanceCallData(bytes[] callDatas) returns(address)",
  `function scheduleGovernanceBatch(uint8 actionClass,${MINT_PHASE_FREEZE_GOVERNANCE_CALL_TUPLE}[] calls,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint64 notBefore,uint64 expiresAfter,bytes32 reasonHash,string reasonURI,bytes32 manifestHash) returns(bytes32)`,
  `function executeGovernanceBatch(bytes32 actionId,${MINT_PHASE_FREEZE_GOVERNANCE_CALL_TUPLE}[] calls,bytes[] callDatas) payable`,
]);
export const CURRENT_MINT_LEDGER_PHASE_FREEZE_ABI: readonly string[] = Object.freeze([
  "function freezePhase(uint256 collectionId,bytes32 phaseId,bytes32 policyHash)",
  `function phaseFreeze(address manager,uint256 collectionId,bytes32 phaseId) view returns(${MINT_PHASE_FREEZE_RECORD_TUPLE})`,
  "function frozenPhaseCount(address manager) view returns(uint256)",
  "function frozenPhaseAt(address manager,uint256 index) view returns(uint256 collectionId,bytes32 phaseId)",
  "function frozenPhaseExecutors(address manager,uint256 collectionId,bytes32 phaseId) view returns(address[])",
  "function importPhaseFreezes(bytes32 importRoot,uint256 maxCount)",
  "function mintImportFreezeProgress(bytes32 importRoot) view returns(uint256 imported,uint256 required)",
  "event MintLedgerPhaseFrozen(uint16 schemaVersion,address indexed manager,uint256 indexed collectionId,bytes32 indexed phaseId,bytes32 policyHash,bytes32 configurationHash)",
  "event MintLedgerPhaseFreezeImported(bytes32 indexed importRoot,address indexed predecessorManager,address indexed successorManager,uint256 collectionId,bytes32 phaseId,bytes32 predecessorFrozenPolicyHash,bytes32 successorPolicyHash,bytes32 configurationHash)",
]);
const coder = AbiCoder.defaultAbiCoder(), managerAbi = new Interface(CURRENT_MINT_PHASE_FREEZE_ABI), ledgerAbi = new Interface(CURRENT_MINT_LEDGER_PHASE_FREEZE_ABI);
const coordinateKeys = ["chainId", "core", "manager", "ledger", "governanceExecutor", "collectionId", "phaseId"];
const selectorKind = id("6529STREAM_GOVERNANCE_CONFIG_FREEZE_SELECTOR");
function exact(value: unknown, keys: readonly string[], label: string): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error(`${label} must be an object`);
  const actual = Reflect.ownKeys(value);
  if (actual.length !== keys.length || actual.some(key => typeof key !== "string" || !keys.includes(key))) throw Error(`${label} has missing or unknown fields`);
}
function uint(value: unknown, bits: number, label: string): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`${label} must be uint${bits} bigint`);
  return value;
}
function address(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (!zero && result === ZeroAddress) throw Error("Expected nonzero address"); return result;
}
function hash(value: unknown, zero = true): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (!zero && value.toLowerCase() === ZeroHash)) throw Error("Expected bytes32 with required nonzero value");
  return value.toLowerCase() as Hex;
}
function bool(value: unknown): boolean { if (typeof value !== "boolean") throw Error("Expected boolean"); return value; }
function enumeration(value: unknown, maximum: bigint, label: string): bigint {
  const result = uint(value, 8, label); if (result > maximum) throw Error(`${label} exceeds original enum`); return result;
}
function list<T>(value: readonly T[], maximum: number, label: string): readonly T[] {
  if (!Array.isArray(value) || value.length > maximum || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, index) => index).some(index => !Object.hasOwn(value, index))) throw Error(`${label} must be a dense bounded array`);
  return value;
}
function digest(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(coder.encode(types, values)) as Hex; }
function sameTree(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (!a || !b || typeof a !== "object" || typeof b !== "object" || Array.isArray(a) !== Array.isArray(b)) return false;
  const keys = Reflect.ownKeys(a), other = Reflect.ownKeys(b);
  return keys.length === other.length && keys.every(key => other.includes(key) && sameTree(Reflect.get(a, key), Reflect.get(b, key)));
}
function coordinates(input: MintPhaseFreezeCoordinates): MintPhaseFreezeCoordinates {
  const collectionId = uint(input.collectionId, 256, "collectionId");
  if (collectionId === 0n) throw Error("Phase collection must be nonzero");
  return Object.freeze({ chainId: uint(input.chainId, 256, "chainId"), core: address(input.core), manager: address(input.manager),
    ledger: address(input.ledger), governanceExecutor: address(input.governanceExecutor), collectionId, phaseId: hash(input.phaseId, false) });
}
export function normalizeMintPhaseFreezeCoordinates(input: MintPhaseFreezeCoordinates): MintPhaseFreezeCoordinates {
  exact(input, coordinateKeys, "Phase freeze coordinates"); return coordinates(input);
}
export function normalizeMintPhaseFreezeRecord(input: MintPhaseFreezeRecord): MintPhaseFreezeRecord {
  exact(input, ["policyHash", "configurationHash"], "Phase freeze record");
  return Object.freeze({ policyHash: hash(input.policyHash), configurationHash: hash(input.configurationHash) });
}
export function normalizeMintPhaseFreezeSnapshot(input: MintPhaseFreezeSnapshot): MintPhaseFreezeSnapshot {
  exact(input, [...coordinateKeys, "currentPolicyHash", "record"], "Phase freeze snapshot");
  return Object.freeze({ ...coordinates(input), currentPolicyHash: hash(input.currentPolicyHash), record: normalizeMintPhaseFreezeRecord(input.record) });
}
/** Original Manager getter preimage. It does not reject an already-frozen phase; the write planner does. */
export function mintPhaseFreezeTransition(input: MintPhaseFreezeSnapshot): MintPhaseFreezeTransition {
  const s = normalizeMintPhaseFreezeSnapshot(input), currentPolicyHash = hash(s.currentPolicyHash, false);
  const scopeHash = digest(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32"],
    [id("6529STREAM_MINT_PHASE_FREEZE_SCOPE_V1"), s.chainId, s.core, s.manager, s.ledger, s.collectionId, s.phaseId]);
  const state = (frozen: boolean) => digest(["bytes32", "bytes32", "bool", "bytes32"], [id("6529STREAM_MINT_PHASE_FREEZE_STATE_V1"), scopeHash, frozen, currentPolicyHash]);
  return Object.freeze({ scopeHash, oldValueHash: state(false), newValueHash: state(true) });
}
export function mintPhaseFreezeSelectorStateHash(chainId: bigint, governanceExecutor: Address, manager: Address,
  config: Omit<MintPhaseFreezeSelectorConfig, "stateHash">): Hex {
  exact(config, ["enabled", "targetCodeHash", "revision"], "Freeze selector state");
  return digest(["bytes32", "uint256", "address", "bytes32", "address", "bytes4", "bool", "bytes32", "uint64"],
    [id("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"), uint(chainId, 256, "chainId"), address(governanceExecutor), selectorKind,
      address(manager), MINT_PHASE_FREEZE_SELECTOR, bool(config.enabled), hash(config.targetCodeHash), uint(config.revision, 64, "revision")]);
}
export function normalizeMintPhaseFreezeClassifierSnapshot(input: MintPhaseFreezeClassifierSnapshot): MintPhaseFreezeClassifierSnapshot {
  exact(input, ["chainId", "governanceExecutor", "manager", "managerCodeHash", "config"], "Freeze classifier snapshot");
  exact(input.config, ["enabled", "targetCodeHash", "revision", "stateHash"], "Freeze selector config");
  const chainId = uint(input.chainId, 256, "chainId"), governanceExecutor = address(input.governanceExecutor), manager = address(input.manager);
  const config = Object.freeze({ enabled: bool(input.config.enabled), targetCodeHash: hash(input.config.targetCodeHash),
    revision: uint(input.config.revision, 64, "revision"), stateHash: hash(input.config.stateHash, false) });
  if (config.stateHash !== mintPhaseFreezeSelectorStateHash(chainId, governanceExecutor, manager,
    { enabled: config.enabled, targetCodeHash: config.targetCodeHash, revision: config.revision })) throw Error("Freeze selector state hash differs from original configuration");
  return Object.freeze({ chainId, governanceExecutor, manager, managerCodeHash: hash(input.managerCodeHash, false), config });
}
function targetCall(target: Address, method: string, args: readonly unknown[], abi = managerAbi): UnsignedCall {
  return Object.freeze({ to: target, value: 0n, data: abi.encodeFunctionData(method, args) as Hex });
}
function governanceCall(call: UnsignedCall, transition: MintPhaseFreezeTransition): MintPhaseFreezeGovernanceCall {
  return Object.freeze({ target: call.to, value: 0n, selector: call.data.slice(0, 10) as Hex, callDataHash: keccak256(call.data) as Hex, ...transition });
}
/** Exact class-2 call. Only the actual executing Executor can satisfy the Manager's independent owner/context checks. */
export function prepareMintPhaseFreeze(input: MintPhaseFreezeSnapshot): Extract<MintPhaseFreezePlan, { kind: "freeze" }> {
  const snapshot = normalizeMintPhaseFreezeSnapshot(input);
  if (snapshot.record.configurationHash !== ZeroHash) throw Error("Phase is already frozen");
  const transition = mintPhaseFreezeTransition(snapshot), call = targetCall(snapshot.manager, "freezePhase", [snapshot.collectionId, snapshot.phaseId]);
  return Object.freeze({ kind: "freeze", snapshot, chainId: snapshot.chainId, governanceExecutor: snapshot.governanceExecutor,
    actionClass: 2n, targetCall: call, governanceCall: governanceCall(call, transition), transition, factsVerified: false });
}
/** Separate isolated class-0 Executor self-call; supplied runtime/state facts are not live code verification. */
export function prepareMintPhaseFreezeClassifier(input: MintPhaseFreezeClassifierSnapshot): Extract<MintPhaseFreezePlan, { kind: "classifier" }> {
  const snapshot = normalizeMintPhaseFreezeClassifierSnapshot(input), s = snapshot;
  if (s.config.enabled || s.config.revision === (1n << 64n) - 1n) throw Error("Freeze classifier is already enabled or revision is exhausted");
  if (s.manager === s.governanceExecutor) throw Error("Freeze selector cannot target the Executor itself");
  const scopeHash = digest(["bytes32", "uint256", "address", "bytes32", "address", "bytes4"],
    [id("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"), s.chainId, s.governanceExecutor, selectorKind, s.manager, MINT_PHASE_FREEZE_SELECTOR]);
  const transition = Object.freeze({ scopeHash, oldValueHash: s.config.stateHash,
    newValueHash: mintPhaseFreezeSelectorStateHash(s.chainId, s.governanceExecutor, s.manager,
      { enabled: true, targetCodeHash: s.managerCodeHash, revision: s.config.revision + 1n }) });
  const call = targetCall(s.governanceExecutor, "registerFreezeSelector", [s.manager, MINT_PHASE_FREEZE_SELECTOR, true]);
  return Object.freeze({ kind: "classifier", snapshot, chainId: s.chainId, governanceExecutor: s.governanceExecutor, actionClass: 0n,
    targetCall: call, governanceCall: governanceCall(call, transition), transition, factsVerified: false });
}
export function normalizeMintPhaseFreezePlan(input: MintPhaseFreezePlan): MintPhaseFreezePlan {
  exact(input, ["kind", "snapshot", "chainId", "governanceExecutor", "actionClass", "targetCall", "governanceCall", "transition", "factsVerified"], "Phase freeze plan");
  let result: MintPhaseFreezePlan;
  if (input.kind === "freeze") result = prepareMintPhaseFreeze(input.snapshot);
  else if (input.kind === "classifier") result = prepareMintPhaseFreezeClassifier(input.snapshot);
  else throw Error("Unknown phase freeze plan kind");
  if (!sameTree(input, result)) throw Error("Phase freeze plan differs from exact reconstruction"); return result;
}
export function normalizeMintPhaseFreezeRoyaltyPolicy(input: MintPhaseFreezeRoyaltyPolicy): MintPhaseFreezeRoyaltyPolicy {
  exact(input, ["configured", "applicationConfigHash", "resolver", "resolverRuntimeHash", "electionHash", "expectedModeAssignmentHash", "expectedSourceRoyaltyPolicyHash"], "Freeze royalty policy");
  return Object.freeze({ configured: bool(input.configured), applicationConfigHash: hash(input.applicationConfigHash), resolver: address(input.resolver, true),
    resolverRuntimeHash: hash(input.resolverRuntimeHash), electionHash: hash(input.electionHash), expectedModeAssignmentHash: hash(input.expectedModeAssignmentHash),
    expectedSourceRoyaltyPolicyHash: hash(input.expectedSourceRoyaltyPolicyHash) });
}
export function normalizeMintPhaseFreezeConfigurationInput(input: MintPhaseFreezeConfigurationInput): MintPhaseFreezeConfigurationInput {
  exact(input, ["chainId", "manager", "ledger", "moduleRegistry", "collectionId", "phaseId", "config", "gate", "counterIds", "counterConfigs", "core", "defined", "definitions", "royalty"], "Phase freeze configuration");
  const p = normalizeMintPhasePolicyInput({ chainId: input.chainId, manager: input.manager, ledger: input.ledger, moduleRegistry: input.moduleRegistry,
    collectionId: input.collectionId, phaseId: input.phaseId, config: input.config, gate: input.gate, counterIds: input.counterIds,
    counterConfigs: input.counterConfigs, executors: [] });
  const defined = Object.freeze(list(input.defined, 16, "defined").map(bool));
  const definitions = Object.freeze(list(input.definitions, 16, "definitions").map(definition => {
    exact(definition, ["scope", "keyMode", "capRoot", "metadataHash"], "Counter definition");
    return Object.freeze({ scope: enumeration(definition.scope, 2n, "Definition scope"), keyMode: enumeration(definition.keyMode, 6n, "Definition key mode"),
      capRoot: hash(definition.capRoot), metadataHash: hash(definition.metadataHash) });
  }));
  if (defined.length !== p.counterIds.length || definitions.length !== p.counterIds.length) throw Error("Effective counter definitions must align with the full ordered counter arrays");
  const { executors: _executors, ...original } = p;
  return Object.freeze({ ...original, core: address(input.core), defined, definitions, royalty: normalizeMintPhaseFreezeRoyaltyPolicy(input.royalty) });
}
/** Original Manager-bound royalty config hash, including the source's explicit uint8(2) election mode. */
export function mintPhaseFreezeRoyaltyConfigHash(input: MintPhaseFreezeConfigurationInput): Hex {
  const p = normalizeMintPhaseFreezeConfigurationInput(input), r = p.royalty;
  return digest(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "bytes32", "uint8", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_MINT_PHASE_ROYALTY_CONFIG_V1"), p.chainId, p.manager, p.collectionId, p.phaseId,
      r.applicationConfigHash, r.resolver, r.resolverRuntimeHash, 2n, r.electionHash, r.expectedModeAssignmentHash, r.expectedSourceRoyaltyPolicyHash]);
}
/** Exact Ledger constraint preimage. Pause is excluded; effective definitions and all royalty fields remain ordered and intact. */
export function mintPhaseFreezeConfigurationHash(input: MintPhaseFreezeConfigurationInput): Hex {
  const p = normalizeMintPhaseFreezeConfigurationInput(input), r = p.royalty;
  let config = Object.freeze({ ...p.config, paused: false });
  const branch = id(r.configured ? "6529STREAM_MINT_PHASE_FREEZE_ROYALTY_CONFIGURED_V1" : "6529STREAM_MINT_PHASE_FREEZE_ROYALTY_UNCONFIGURED_V1");
  if (r.configured) {
    if (config.configHash !== mintPhaseFreezeRoyaltyConfigHash(p)) throw Error("Configured royalty differs from the original Manager-bound wrapper");
    config = Object.freeze({ ...config, configHash: r.applicationConfigHash });
  }
  return digest(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", MINT_PHASE_FREEZE_PHASE_TUPLE,
    MINT_PHASE_FREEZE_GATE_TUPLE, "bytes32[]", `${MINT_PHASE_FREEZE_COUNTER_TUPLE}[]`, "bool[]", `${MINT_PHASE_FREEZE_DEFINITION_TUPLE}[]`,
    "bytes32", "bytes32", MINT_PHASE_FREEZE_ROYALTY_TUPLE],
  [id("6529STREAM_MINT_PHASE_FREEZE_CONFIGURATION_V1"), p.chainId, p.core, p.moduleRegistry, p.ledger, p.collectionId, p.phaseId,
    config, p.gate, p.counterIds, p.counterConfigs, p.defined, p.definitions, branch, r.applicationConfigHash, r]);
}
export function normalizeMintPhaseFreezeGovernanceWindow(input: MintPhaseFreezeGovernanceWindow, actionClass: 0n | 2n): MintPhaseFreezeGovernanceWindow {
  exact(input, ["notBefore", "expiresAfter", "reasonHash", "reasonURI", "manifestHash"], "Phase freeze governance window");
  if (actionClass !== 0n && actionClass !== 2n) throw Error("Phase freeze supports only original classes 0 and 2");
  const notBefore = uint(input.notBefore, 64, "notBefore"), expiresAfter = uint(input.expiresAfter, 64, "expiresAfter");
  if (expiresAfter <= notBefore) throw Error("Governance expiry must follow notBefore");
  if (actionClass === 2n && expiresAfter - notBefore < MINT_PHASE_FREEZE_MINIMUM_OPEN_WINDOW) throw Error("Terminal freeze requires at least seven days of open execution window");
  if (typeof input.reasonURI !== "string") throw Error("reasonURI must be Unicode text");
  for (const character of input.reasonURI) { const point = character.codePointAt(0)!; if (point >= 0xd800 && point <= 0xdfff) throw Error("reasonURI must contain Unicode scalars"); }
  toUtf8Bytes(input.reasonURI);
  return Object.freeze({ notBefore, expiresAfter, reasonHash: hash(input.reasonHash), reasonURI: input.reasonURI, manifestHash: hash(input.manifestHash) });
}
/** Exact source scheduling checks at an explicit block timestamp; neither local time nor an estimated mining date is substituted. */
export function assertMintPhaseFreezeGovernanceWindow(actionClass: 0n | 2n, window: MintPhaseFreezeGovernanceWindow, schedulingTimestamp: bigint): void {
  const w = normalizeMintPhaseFreezeGovernanceWindow(window, actionClass), at = uint(schedulingTimestamp, 256, "schedulingTimestamp");
  if (at > (1n << 64n) - 1n - MINT_PHASE_FREEZE_MAXIMUM_LIFETIME) throw Error("Scheduling timestamp exceeds original 365-day uint64 headroom");
  const delay = actionClass === 2n ? MINT_PHASE_FREEZE_MINIMUM_DELAY : 0n;
  if (w.notBefore < at + delay) throw Error("Governance delay is below the original class minimum (terminal freeze: 72 hours)");
  if (w.expiresAfter > at + MINT_PHASE_FREEZE_MAXIMUM_LIFETIME) throw Error("Governance lifetime exceeds scheduling plus 365 days");
}
/** A batch of exactly one original call. Publication, proposer, guardian and live scheduling admission remain workflow checks. */
export function mintPhaseFreezeGovernanceBatch(input: MintPhaseFreezePlan, nonce: bigint, window: MintPhaseFreezeGovernanceWindow): MintPhaseFreezeGovernanceBatch {
  const plan = normalizeMintPhaseFreezePlan(input), n = uint(nonce, 256, "Governance nonce"), w = normalizeMintPhaseFreezeGovernanceWindow(window, plan.actionClass);
  const calls = [plan.governanceCall], data = [plan.targetCall.data], executor = plan.governanceExecutor;
  const callsHash = digest(["bytes32", `${MINT_PHASE_FREEZE_GOVERNANCE_CALL_TUPLE}[]`], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain: Hex, field: "scopeHash" | "oldValueHash" | "newValueHash") => digest(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, calls.map(call => call[field])]);
  const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash");
  const oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash");
  const newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
  const actionId = digest(["bytes32", "uint256", "address", "tuple(uint8,bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64,bytes32,bytes32)"],
    ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", plan.chainId, executor,
      [plan.actionClass, callsHash, scopeHash, oldValueHash, newValueHash, n, w.notBefore, w.expiresAfter, w.reasonHash, w.manifestHash]]);
  return Object.freeze({ plan, nonce: n, window: w, callsHash, scopeHash, oldValueHash, newValueHash, actionId,
    publicationKey: keccak256(plan.governanceCall.callDataHash) as Hex,
    publicationCall: targetCall(executor, "publishGovernanceCallData", [data]),
    scheduleCall: targetCall(executor, "scheduleGovernanceBatch", [plan.actionClass, calls, scopeHash, oldValueHash, newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash]),
    executionCall: targetCall(executor, "executeGovernanceBatch", [actionId, calls, data]) });
}
export function normalizeMintPhaseFreezeGovernanceBatch(input: MintPhaseFreezeGovernanceBatch): MintPhaseFreezeGovernanceBatch {
  exact(input, ["plan", "nonce", "window", "callsHash", "scopeHash", "oldValueHash", "newValueHash", "actionId", "publicationKey", "publicationCall", "scheduleCall", "executionCall"], "Phase freeze governance batch");
  const result = mintPhaseFreezeGovernanceBatch(input.plan, input.nonce, input.window);
  if (!sameTree(input, result)) throw Error("Phase freeze governance batch differs from exact reconstruction"); return result;
}
/** Permissionless bounded copy only. Root commitment, same-Ledger lineage and completion barriers are not inferred. */
export function prepareMintPhaseFreezeImport(ledger: Address, caller: Address, importRoot: Hex, maxCount: bigint): MintPhaseFreezeImportPlan {
  const target = address(ledger), actor = address(caller), root = hash(importRoot, false), count = uint(maxCount, 256, "maxCount");
  if (count < 1n || count > 32n) throw Error("Freeze import maxCount must be 1..32");
  return Object.freeze({ ledger: target, caller: actor, importRoot: root, maxCount: count,
    call: targetCall(target, "importPhaseFreezes", [root, count], ledgerAbi), factsVerified: false });
}
export function normalizeMintPhaseFreezeImport(input: MintPhaseFreezeImportPlan): MintPhaseFreezeImportPlan {
  exact(input, ["ledger", "caller", "importRoot", "maxCount", "call", "factsVerified"], "Phase freeze import");
  const result = prepareMintPhaseFreezeImport(input.ledger, input.caller, input.importRoot, input.maxCount);
  if (!sameTree(input, result)) throw Error("Phase freeze import differs from exact reconstruction"); return result;
}
