import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { prepareArtistContentConsent, type ManifestContentConsent } from "./current-manifests.js";
import type { SigningPayload } from "./signing.js";
import { normalizeMintPolicyGraceGovernanceWindow, type MintPolicyGraceGovernanceCall,
  type MintPolicyGraceGovernanceWindow } from "./current-mint-policy-grace.js";

export type EntropyCollectionPolicyMode = 0n | 1n | 2n;
export type EntropyCollectionPolicySecurityClass = 0n | 1n;
export type EntropyCollectionPolicyRenderRequirement = 0n | 1n;
export interface EntropyCollectionPolicyReveal {
  readonly declared: boolean; readonly requestMode: bigint; readonly revealOwnerRole: Hex;
  readonly requestSLOBlocks: bigint; readonly revealFeePerTokenWei: bigint;
}
export interface EntropyCollectionPolicyInput {
  readonly mode: EntropyCollectionPolicyMode; readonly securityClass: EntropyCollectionPolicySecurityClass;
  readonly renderRequirement: EntropyCollectionPolicyRenderRequirement; readonly provider: Address;
  readonly collectionSalt: Hex; readonly publicRequests: boolean; readonly timeoutBlocks: bigint;
  readonly reveal: EntropyCollectionPolicyReveal; readonly maxFreshRecoveryAttempts: bigint; readonly recoveryPolicyId: Hex;
}
export interface EntropyCollectionPolicyConfig {
  readonly provider: Address; readonly publicRequests: boolean; readonly locked: boolean; readonly timeoutBlocks: bigint;
  readonly providerConfigHash: Hex; readonly providerCodeHash: Hex; readonly collectionSalt: Hex;
}
export interface EntropyCollectionPolicyRecovery {
  readonly policyId: Hex; readonly policyHash: Hex; readonly maxFreshRecoveryAttempts: bigint;
  readonly revision: bigint; readonly lastActionId: Hex;
}
/** Original namespace entry; source-derived, not the legacy-substituting public PolicyRecord. */
export interface EntropyCollectionPolicyEntry {
  readonly revision: bigint; readonly mode: EntropyCollectionPolicyMode; readonly securityClass: EntropyCollectionPolicySecurityClass;
  readonly renderRequirement: EntropyCollectionPolicyRenderRequirement; readonly policyHash: Hex;
  readonly lastActionId: Hex; readonly artistConsentRecord: Hex;
}
export interface EntropyCollectionPolicyRecord {
  readonly configured: boolean; readonly explicitPolicy: boolean; readonly frozen: boolean; readonly mode: EntropyCollectionPolicyMode;
  readonly securityClass: EntropyCollectionPolicySecurityClass; readonly renderRequirement: EntropyCollectionPolicyRenderRequirement;
  readonly revision: bigint; readonly providerEpoch: bigint; readonly policyHash: Hex; readonly contentStateHash: Hex;
  readonly lastActionId: Hex; readonly artistConsentRecord: Hex;
}
export interface EntropyCollectionPolicyCoordinates {
  readonly chainId: bigint; readonly coordinator: Address; readonly core: Address; readonly governanceExecutor: Address; readonly collectionId: bigint;
}
export interface EntropyCollectionPolicyState {
  readonly config: EntropyCollectionPolicyConfig; readonly providerEpoch: bigint; readonly reveal: EntropyCollectionPolicyReveal;
  readonly recovery: EntropyCollectionPolicyRecovery; readonly entry: EntropyCollectionPolicyEntry;
}
/** Supplied facts only. Actual selected pointers, provider admission, quotes, recovery steps and Artist evidence are separate checks. */
export interface EntropyCollectionPolicySnapshot extends EntropyCollectionPolicyCoordinates, EntropyCollectionPolicyState {
  readonly collectionExists: boolean; readonly collectionFrozen: boolean; readonly collectionMintedEver: bigint; readonly revealEscrow: bigint;
}
/** Dependency hashes read by the source worker, never parameters added to its original calldata. */
export interface EntropyCollectionPolicyResolution {
  readonly providerCodeHash: Hex; readonly providerConfigHash: Hex; readonly recoveryPolicyHash: Hex;
}
export interface EntropyCollectionPolicyTransition {
  readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; readonly artistContentStateHash: Hex;
}
export type EntropyCollectionPolicyGovernanceCall = MintPolicyGraceGovernanceCall;
export type EntropyCollectionPolicyGovernanceWindow = MintPolicyGraceGovernanceWindow;
interface EntropyCollectionPolicyPlanBase {
  readonly snapshot: EntropyCollectionPolicySnapshot;
  /** Original worker's prepared state before authorization replaces action/consent IDs. */
  readonly next: EntropyCollectionPolicyState; readonly transition: EntropyCollectionPolicyTransition;
  readonly targetCall: UnsignedCall; readonly previewCall: UnsignedCall;
  readonly governanceCall: EntropyCollectionPolicyGovernanceCall; readonly factsVerified: false;
}
export type EntropyCollectionPolicyPlan = EntropyCollectionPolicyPlanBase & (
  { readonly kind: "configure"; readonly actionClass: 1n; readonly input: EntropyCollectionPolicyInput; readonly resolution: EntropyCollectionPolicyResolution }
  | { readonly kind: "freeze"; readonly actionClass: 2n });
export interface EntropyCollectionPolicyGovernanceBatch {
  readonly plan: EntropyCollectionPolicyPlan; readonly nonce: bigint; readonly window: EntropyCollectionPolicyGovernanceWindow;
  readonly callsHash: Hex; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex;
  readonly actionId: Hex; readonly publicationKey: Hex; readonly publicationCall: UnsignedCall;
  readonly scheduleCall: UnsignedCall; readonly executionCall: UnsignedCall;
}
export interface EntropyCollectionPolicyAuthorization { readonly nonce: bigint; readonly deadline: bigint; readonly signature: Hex }
export interface EntropyCollectionPolicyArtistConsent {
  readonly plan: EntropyCollectionPolicyPlan; readonly registry: Address; readonly caller: Address; readonly signer: Address;
  readonly authorization: EntropyCollectionPolicyAuthorization; readonly direct: boolean;
  readonly payload: SigningPayload<ManifestContentConsent>; readonly call: UnsignedCall; readonly digestCall: UnsignedCall; readonly factsVerified: false;
}
export interface EntropyCollectionPolicyArtistRecordInput {
  readonly registry: Address; readonly artistId: Hex; readonly signer: Address; readonly authorityClass: bigint;
  readonly nonce: bigint; readonly observedAt: bigint;
}
export class EntropyCollectionPolicyUnsupportedModeError extends Error {
  readonly mode = 1n;
  constructor() { super("INSTANT entropy collection policy is unsupported by this source profile"); this.name = "EntropyCollectionPolicyUnsupportedModeError"; }
}

export const ENTROPY_COLLECTION_POLICY_INTERFACE_ID = "0x4583f7e1" as const;
export const ENTROPY_COLLECTION_POLICY_FAMILY = id("6529STREAM_ENTROPY_CONFIGURATION_V1") as Hex;
export const ENTROPY_COLLECTION_POLICY_REVEAL_TUPLE = "tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei)";
export const ENTROPY_COLLECTION_POLICY_INPUT_TUPLE = `tuple(uint8 mode,uint8 securityClass,uint8 renderRequirement,address provider,bytes32 collectionSalt,bool publicRequests,uint64 timeoutBlocks,${ENTROPY_COLLECTION_POLICY_REVEAL_TUPLE} reveal,uint16 maxFreshRecoveryAttempts,bytes32 recoveryPolicyId)`;
export const ENTROPY_COLLECTION_POLICY_CONFIG_TUPLE = "tuple(address provider,bool publicRequests,bool locked,uint64 timeoutBlocks,bytes32 providerConfigHash,bytes32 providerCodeHash,bytes32 collectionSalt)";
export const ENTROPY_COLLECTION_POLICY_RECOVERY_TUPLE = "tuple(bytes32 policyId,bytes32 policyHash,uint16 maxFreshRecoveryAttempts,uint64 revision,bytes32 lastActionId)";
export const ENTROPY_COLLECTION_POLICY_ENTRY_TUPLE = "tuple(uint64 revision,uint8 mode,uint8 securityClass,uint8 renderRequirement,bytes32 policyHash,bytes32 lastActionId,bytes32 artistConsentRecord)";
export const ENTROPY_COLLECTION_POLICY_RECORD_TUPLE = "tuple(bool configured,bool explicitPolicy,bool frozen,uint8 mode,uint8 securityClass,uint8 renderRequirement,uint64 revision,uint32 providerEpoch,bytes32 policyHash,bytes32 contentStateHash,bytes32 lastActionId,bytes32 artistConsentRecord)";
export const ENTROPY_COLLECTION_POLICY_GOVERNANCE_CALL_TUPLE = "tuple(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
export const CURRENT_ENTROPY_COLLECTION_POLICY_ABI: readonly string[] = Object.freeze([
  `function configureCollectionEntropyPolicy(uint256 collectionId,${ENTROPY_COLLECTION_POLICY_INPUT_TUPLE} policy)`,
  `function collectionEntropyPolicy(uint256 collectionId) view returns(${ENTROPY_COLLECTION_POLICY_RECORD_TUPLE})`,
  `function collectionEntropyPolicyTransition(uint256 collectionId,${ENTROPY_COLLECTION_POLICY_INPUT_TUPLE} policy) view returns(bytes32 scope,bytes32 oldHash,bytes32 newHash,bytes32 artistContentStateHash)`,
  "function freezeCollectionEntropyPolicy(uint256 collectionId)",
  "function freezeCollectionEntropyPolicyTransition(uint256 collectionId) view returns(bytes32 scope,bytes32 oldHash,bytes32 newHash,bytes32 artistContentStateHash)",
  `event CollectionEntropyPolicyConfigured(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed policyHash,uint64 revision,uint32 providerEpoch,${ENTROPY_COLLECTION_POLICY_INPUT_TUPLE} policy,bytes32 providerCodeHash,bytes32 providerConfigHash,bytes32 recoveryPolicyHash,bytes32 actionId,bytes32 artistConsentRecord)`,
  "event CollectionEntropyPolicyFrozen(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed policyHash,uint64 revision,bytes32 actionId,bytes32 artistConsentRecord)",
  "event TokenEntropyPolicyRegistered(uint16 schemaVersion,uint256 indexed collectionId,uint256 indexed tokenId,bytes32 indexed policyHash,uint8 status)",
]);
export const CURRENT_ENTROPY_COLLECTION_POLICY_GOVERNANCE_ABI: readonly string[] = Object.freeze([
  "function publishGovernanceCallData(bytes[] callDatas) returns(address)",
  `function scheduleGovernanceBatch(uint8 actionClass,${ENTROPY_COLLECTION_POLICY_GOVERNANCE_CALL_TUPLE}[] calls,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint64 notBefore,uint64 expiresAfter,bytes32 reasonHash,string reasonURI,bytes32 manifestHash) returns(bytes32)`,
  `function executeGovernanceBatch(bytes32 actionId,${ENTROPY_COLLECTION_POLICY_GOVERNANCE_CALL_TUPLE}[] calls,bytes[] callDatas) payable`,
]);
const abi = new Interface(CURRENT_ENTROPY_COLLECTION_POLICY_ABI), governanceAbi = new Interface(CURRENT_ENTROPY_COLLECTION_POLICY_GOVERNANCE_ABI), coder = AbiCoder.defaultAbiCoder();
const coordsKeys = ["chainId", "coordinator", "core", "governanceExecutor", "collectionId"], stateKeys = ["config", "providerEpoch", "reveal", "recovery", "entry"];
function exact(value: unknown, keys: readonly string[], label: string): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error(`${label} must be an object`);
  const actual = Reflect.ownKeys(value); if (actual.length !== keys.length || actual.some(k => typeof k !== "string" || !keys.includes(k))) throw Error(`${label} has missing or unknown fields`);
}
function uint(value: unknown, bits: number, label: string): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`${label} must be uint${bits} bigint`); return value;
}
function bytes(value: unknown, size?: number): Hex {
  if (typeof value !== "string" || !isHexString(value, size) || value.length % 2 !== 0) throw Error("Expected canonical hex bytes"); return value.toLowerCase() as Hex;
}
function address(value: unknown, zero = true): Address {
  if (typeof value !== "string") throw Error("Expected address"); const result = getAddress(value) as Address;
  if (!zero && result === ZeroAddress) throw Error("Expected nonzero address"); return result;
}
function bool(value: unknown): boolean { if (typeof value !== "boolean") throw Error("Expected boolean"); return value; }
function normal(p: ParamType, value: unknown, decoded = false): unknown {
  if (p.baseType === "tuple") {
    if (!decoded) exact(value, p.components!.map(f => f.name), "Tuple");
    return Object.freeze(Object.fromEntries(p.components!.map((f, i) => [f.name, normal(f, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[f.name], decoded)])));
  }
  if (p.type === "address") return address(value); if (p.type === "bool") return bool(value);
  if (p.type.startsWith("uint")) return uint(value, Number(p.type.slice(4)), p.name);
  if (p.type.startsWith("bytes")) return bytes(value, Number(p.type.slice(5)));
  throw Error("Unsupported original tuple type");
}
function tuple<T>(type: string, input: T): T { return normal(ParamType.from(type), input) as T; }
function enums(input: { readonly mode: bigint; readonly securityClass: bigint; readonly renderRequirement: bigint }): void {
  if (input.mode > 2n || input.securityClass > 1n || input.renderRequirement > 1n) throw Error("Outside original policy enum");
}
function encoded(type: string, value: unknown): Hex { return coder.encode([type], [value]) as Hex; }
function decoded<T>(type: string, raw: Hex): T {
  const data = bytes(raw); if (data.length > 2 + 1024 * 2) throw Error("Policy tuple exceeds fixed structural bound");
  const value = normal(ParamType.from(type), coder.decode([type], data)[0], true) as T;
  if (encoded(type, value) !== data) throw Error("Noncanonical policy ABI encoding"); return value;
}
function digest(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(coder.encode(types, values)) as Hex; }
function sameTree(a: unknown, b: unknown): boolean {
  if (a === b) return true; if (!a || !b || typeof a !== "object" || typeof b !== "object" || Array.isArray(a) !== Array.isArray(b)) return false;
  const keys = Reflect.ownKeys(a), other = Reflect.ownKeys(b); return keys.length === other.length && keys.every(k => other.includes(k) && sameTree(Reflect.get(a, k), Reflect.get(b, k)));
}
function call(to: Address, method: string, args: readonly unknown[], intf = abi): UnsignedCall { return Object.freeze({ to: address(to, false), data: intf.encodeFunctionData(method, args) as Hex, value: 0n }); }
function coordinateValues(input: EntropyCollectionPolicyCoordinates): EntropyCollectionPolicyCoordinates {
  const collectionId = uint(input.collectionId, 256, "collectionId"); if (collectionId === 0n) throw Error("Collection ID must be positive");
  return Object.freeze({ chainId: uint(input.chainId, 256, "chainId"), coordinator: address(input.coordinator, false), core: address(input.core, false), governanceExecutor: address(input.governanceExecutor, false), collectionId });
}
function stateValues(input: EntropyCollectionPolicyState): EntropyCollectionPolicyState {
  return Object.freeze({ config: normalizeEntropyCollectionPolicyConfig(input.config), providerEpoch: uint(input.providerEpoch, 32, "providerEpoch"),
    reveal: normalizeEntropyCollectionPolicyReveal(input.reveal), recovery: normalizeEntropyCollectionPolicyRecovery(input.recovery), entry: normalizeEntropyCollectionPolicyEntry(input.entry) });
}
export function normalizeEntropyCollectionPolicyCoordinates(input: EntropyCollectionPolicyCoordinates): EntropyCollectionPolicyCoordinates { exact(input, coordsKeys, "Policy coordinates"); return coordinateValues(input); }
export function normalizeEntropyCollectionPolicyInput(input: EntropyCollectionPolicyInput): EntropyCollectionPolicyInput { const r = tuple(ENTROPY_COLLECTION_POLICY_INPUT_TUPLE, input); enums(r); return r; }
export function normalizeEntropyCollectionPolicyReveal(input: EntropyCollectionPolicyReveal): EntropyCollectionPolicyReveal { return tuple(ENTROPY_COLLECTION_POLICY_REVEAL_TUPLE, input); }
export function normalizeEntropyCollectionPolicyConfig(input: EntropyCollectionPolicyConfig): EntropyCollectionPolicyConfig { return tuple(ENTROPY_COLLECTION_POLICY_CONFIG_TUPLE, input); }
export function normalizeEntropyCollectionPolicyRecovery(input: EntropyCollectionPolicyRecovery): EntropyCollectionPolicyRecovery { return tuple(ENTROPY_COLLECTION_POLICY_RECOVERY_TUPLE, input); }
export function normalizeEntropyCollectionPolicyEntry(input: EntropyCollectionPolicyEntry): EntropyCollectionPolicyEntry { const r = tuple(ENTROPY_COLLECTION_POLICY_ENTRY_TUPLE, input); enums(r); return r; }
export function normalizeEntropyCollectionPolicyRecord(input: EntropyCollectionPolicyRecord): EntropyCollectionPolicyRecord { const r = tuple(ENTROPY_COLLECTION_POLICY_RECORD_TUPLE, input); enums(r); return r; }
export function encodeEntropyCollectionPolicyInput(input: EntropyCollectionPolicyInput): Hex { return encoded(ENTROPY_COLLECTION_POLICY_INPUT_TUPLE, normalizeEntropyCollectionPolicyInput(input)); }
export function decodeEntropyCollectionPolicyInput(raw: Hex): EntropyCollectionPolicyInput { return normalizeEntropyCollectionPolicyInput(decoded(ENTROPY_COLLECTION_POLICY_INPUT_TUPLE, raw)); }
export function encodeEntropyCollectionPolicyRecord(input: EntropyCollectionPolicyRecord): Hex { return encoded(ENTROPY_COLLECTION_POLICY_RECORD_TUPLE, normalizeEntropyCollectionPolicyRecord(input)); }
export function decodeEntropyCollectionPolicyRecord(raw: Hex): EntropyCollectionPolicyRecord { return normalizeEntropyCollectionPolicyRecord(decoded(ENTROPY_COLLECTION_POLICY_RECORD_TUPLE, raw)); }
export function normalizeEntropyCollectionPolicyState(input: EntropyCollectionPolicyState): EntropyCollectionPolicyState { exact(input, stateKeys, "Policy state"); return stateValues(input); }
export function normalizeEntropyCollectionPolicySnapshot(input: EntropyCollectionPolicySnapshot): EntropyCollectionPolicySnapshot {
  exact(input, [...coordsKeys, ...stateKeys, "collectionExists", "collectionFrozen", "collectionMintedEver", "revealEscrow"], "Policy snapshot");
  return Object.freeze({ ...coordinateValues(input), ...stateValues(input), collectionExists: bool(input.collectionExists), collectionFrozen: bool(input.collectionFrozen),
    collectionMintedEver: uint(input.collectionMintedEver, 256, "collectionMintedEver"), revealEscrow: uint(input.revealEscrow, 256, "revealEscrow") });
}
export function normalizeEntropyCollectionPolicyResolution(input: EntropyCollectionPolicyResolution): EntropyCollectionPolicyResolution {
  exact(input, ["providerCodeHash", "providerConfigHash", "recoveryPolicyHash"], "Policy resolution");
  return Object.freeze({ providerCodeHash: bytes(input.providerCodeHash, 32), providerConfigHash: bytes(input.providerConfigHash, 32), recoveryPolicyHash: bytes(input.recoveryPolicyHash, 32) });
}
export function entropyCollectionPolicyContentStateHash(policyHash: Hex, frozen: boolean): Hex {
  return digest(["bytes32", "bytes32", "bool"], [ENTROPY_COLLECTION_POLICY_FAMILY, bytes(policyHash, 32), bool(frozen)]);
}
/** The raw entry is absent for a legacy record; do not substitute its public ASYNC default into governance state hashing. */
export function entropyCollectionPolicyEntryFromRecord(input: EntropyCollectionPolicyRecord): EntropyCollectionPolicyEntry {
  const r = normalizeEntropyCollectionPolicyRecord(input);
  if (r.explicitPolicy !== (r.revision !== 0n)) throw Error("Policy record explicit flag disagrees with revision");
  if (!r.explicitPolicy) {
    if (r.mode !== 2n || r.securityClass !== 0n || r.renderRequirement !== 0n || r.lastActionId !== ZeroHash || r.artistConsentRecord !== ZeroHash) throw Error("Invalid legacy PolicyRecord defaults");
    return Object.freeze({ revision: 0n, mode: 0n, securityClass: 0n, renderRequirement: 0n, policyHash: ZeroHash, lastActionId: ZeroHash, artistConsentRecord: ZeroHash });
  }
  return Object.freeze({ revision: r.revision, mode: r.mode, securityClass: r.securityClass, renderRequirement: r.renderRequirement, policyHash: r.policyHash, lastActionId: r.lastActionId, artistConsentRecord: r.artistConsentRecord });
}
/** Original semantic V2 hash. Operational fee, lock, revisions and action/consent identities are excluded. */
export function entropyCollectionPolicyHash(coordinates: EntropyCollectionPolicyCoordinates, state: EntropyCollectionPolicyState): Hex {
  const c = normalizeEntropyCollectionPolicyCoordinates(coordinates), s = normalizeEntropyCollectionPolicyState(state), p = s.config, r = s.reveal, b = s.recovery, e = s.entry;
  return digest(["bytes32", "uint256", "address", "address", "uint256", "uint8", "uint8", "uint8", "address", "bytes32", "bytes32", "uint32", "bytes32", "bool", "uint64", "bool", "uint8", "bytes32", "uint64", "bytes32", "bytes32", "uint16"],
    [id("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"), c.chainId, c.coordinator, c.core, c.collectionId, e.mode, e.securityClass, e.renderRequirement, p.provider, p.providerCodeHash, p.providerConfigHash, s.providerEpoch, p.collectionSalt,
      p.publicRequests, p.timeoutBlocks, r.declared, r.requestMode, r.revealOwnerRole, r.requestSLOBlocks, b.policyId, b.policyHash, b.maxFreshRecoveryAttempts]);
}
/** Exact original no-recovery and fresh-recovery legacy commitment; explicit V2 deliberately makes this unavailable. */
export function entropyCollectionPolicyLegacyHash(coordinates: EntropyCollectionPolicyCoordinates, state: EntropyCollectionPolicyState): Hex {
  const c = normalizeEntropyCollectionPolicyCoordinates(coordinates), s = normalizeEntropyCollectionPolicyState(state), p = s.config, r = s.reveal, b = s.recovery;
  if (s.entry.revision !== 0n || p.provider === ZeroAddress || !r.declared) return ZeroHash as Hex;
  const salt = digest(["bytes32", "uint256", "address", "address", "uint256", "bytes32"], [id("6529STREAM_ENTROPY_COLLECTION_SALT_V1"), c.chainId, c.coordinator, c.core, c.collectionId, p.collectionSalt]);
  const provider = digest(["bytes32", "address", "bytes32", "uint32", "bytes32", "bytes32", "bool", "uint64"], [id("6529STREAM_ENTROPY_SINGLE_PROVIDER_POLICY_V1"), p.provider, p.providerCodeHash, s.providerEpoch, p.providerConfigHash, salt, p.publicRequests, p.timeoutBlocks]);
  const reveal = digest(["bytes32", "uint8", "bytes32", "uint64"], [id("6529STREAM_ENTROPY_DECLARED_REVEAL_POLICY_V1"), r.requestMode, r.revealOwnerRole, r.requestSLOBlocks]);
  return b.maxFreshRecoveryAttempts === 0n
    ? digest(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32"], [id("6529STREAM_ENTROPY_FINALITY_POLICY_V1"), c.chainId, c.coordinator, c.core, c.collectionId, id(s.providerEpoch === 1n ? "6529STREAM_ENTROPY_EPOCH1_NO_FRESH_RECOVERY_V1" : "6529STREAM_ENTROPY_PREMINT_EPOCHS_NO_FRESH_RECOVERY_V1"), provider, reveal])
    : digest(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "uint16"], [id("6529STREAM_ENTROPY_FINALITY_FRESH_POLICY_V1"), c.chainId, c.coordinator, c.core, c.collectionId, provider, reveal, b.policyId, b.policyHash, b.maxFreshRecoveryAttempts]);
}
export function entropyCollectionPolicyRecord(snapshot: EntropyCollectionPolicySnapshot): EntropyCollectionPolicyRecord {
  const s = normalizeEntropyCollectionPolicySnapshot(snapshot), explicitPolicy = s.entry.revision !== 0n;
  const policyHash = explicitPolicy ? s.entry.policyHash : entropyCollectionPolicyLegacyHash(coordinateValues(s), stateValues(s));
  return Object.freeze({ configured: explicitPolicy || s.config.provider !== ZeroAddress, explicitPolicy, frozen: s.config.locked,
    mode: explicitPolicy ? s.entry.mode : 2n, securityClass: explicitPolicy ? s.entry.securityClass : 0n, renderRequirement: explicitPolicy ? s.entry.renderRequirement : 0n,
    revision: s.entry.revision, providerEpoch: s.providerEpoch, policyHash, contentStateHash: entropyCollectionPolicyContentStateHash(policyHash, s.config.locked), lastActionId: s.entry.lastActionId, artistConsentRecord: s.entry.artistConsentRecord });
}
export function entropyCollectionPolicyScopeHash(coordinates: EntropyCollectionPolicyCoordinates, kind: "configure" | "freeze"): Hex {
  const c = normalizeEntropyCollectionPolicyCoordinates(coordinates);
  if (kind !== "configure" && kind !== "freeze") throw Error("Unknown policy operation");
  return digest(["bytes32", "uint256", "address", "address", "uint256", "bytes4"], [id("6529STREAM_ENTROPY_COLLECTION_POLICY_SCOPE_V1"), c.chainId, c.coordinator, c.core, c.collectionId, abi.getFunction(kind === "configure" ? "configureCollectionEntropyPolicy" : "freezeCollectionEntropyPolicy")!.selector]);
}
export function entropyCollectionPolicyStateHash(scope: Hex, state: EntropyCollectionPolicyState): Hex {
  const s = normalizeEntropyCollectionPolicyState(state), r = s.recovery, e = s.entry;
  return digest(["bytes32", "bytes32", ENTROPY_COLLECTION_POLICY_CONFIG_TUPLE, "uint32", ENTROPY_COLLECTION_POLICY_REVEAL_TUPLE, "bytes32", "bytes32", "uint16", "uint64", "uint64", "uint8", "uint8", "uint8", "bytes32"],
    [id("6529STREAM_ENTROPY_COLLECTION_POLICY_STATE_V1"), bytes(scope, 32), s.config, s.providerEpoch, s.reveal, r.policyId, r.policyHash, r.maxFreshRecoveryAttempts, r.revision, e.revision, e.mode, e.securityClass, e.renderRequirement, e.policyHash]);
}
function mutable(s: EntropyCollectionPolicySnapshot): void {
  if (!s.collectionExists || s.config.locked || s.collectionFrozen || s.collectionMintedEver !== 0n || s.entry.revision === (1n << 64n) - 1n) throw Error("Collection policy is unavailable or locked");
}
function resultBase(s: EntropyCollectionPolicySnapshot, next: EntropyCollectionPolicyState, kind: "configure" | "freeze", input?: EntropyCollectionPolicyInput): EntropyCollectionPolicyPlanBase {
  const scopeHash = entropyCollectionPolicyScopeHash(coordinateValues(s), kind);
  const transition = Object.freeze({ scopeHash, oldValueHash: entropyCollectionPolicyStateHash(scopeHash, stateValues(s)), newValueHash: entropyCollectionPolicyStateHash(scopeHash, next), artistContentStateHash: entropyCollectionPolicyContentStateHash(next.entry.policyHash, next.config.locked) });
  const targetCall = call(s.coordinator, kind === "configure" ? "configureCollectionEntropyPolicy" : "freezeCollectionEntropyPolicy", input ? [s.collectionId, input] : [s.collectionId]);
  const previewCall = call(s.coordinator, kind === "configure" ? "collectionEntropyPolicyTransition" : "freezeCollectionEntropyPolicyTransition", input ? [s.collectionId, input] : [s.collectionId]);
  const governanceCall = Object.freeze({ target: targetCall.to, value: 0n, selector: targetCall.data.slice(0, 10) as Hex, callDataHash: keccak256(targetCall.data) as Hex,
    scopeHash, oldValueHash: transition.oldValueHash, newValueHash: transition.newValueHash });
  return Object.freeze({ snapshot: s, next, transition, targetCall, previewCall, governanceCall, factsVerified: false });
}
/** Replays the original worker using supplied dependency hashes. It does not establish provider activity, fee quotes, recovery admission, pointers or Artist authority. */
export function prepareEntropyCollectionPolicyConfigure(snapshot: EntropyCollectionPolicySnapshot, input: EntropyCollectionPolicyInput, resolution: EntropyCollectionPolicyResolution): Extract<EntropyCollectionPolicyPlan, { kind: "configure" }> {
  const s = normalizeEntropyCollectionPolicySnapshot(snapshot), p = normalizeEntropyCollectionPolicyInput(input), d = normalizeEntropyCollectionPolicyResolution(resolution); mutable(s);
  if (p.mode === 1n) throw new EntropyCollectionPolicyUnsupportedModeError();
  if (p.mode === 0n) {
    if (p.renderRequirement !== 1n || p.provider !== ZeroAddress || p.collectionSalt !== ZeroHash || p.publicRequests || p.timeoutBlocks !== 0n || p.reveal.declared || p.reveal.requestMode !== 0n || p.reveal.revealOwnerRole !== ZeroHash || p.reveal.requestSLOBlocks !== 0n || p.reveal.revealFeePerTokenWei !== 0n || p.maxFreshRecoveryAttempts !== 0n || p.recoveryPolicyId !== ZeroHash || d.providerCodeHash !== ZeroHash || d.providerConfigHash !== ZeroHash || s.revealEscrow !== 0n) throw Error("DISABLED requires canonical zero fields and no reveal escrow");
  } else if (p.provider === ZeroAddress || p.timeoutBlocks === 0n || d.providerCodeHash === ZeroHash || d.providerConfigHash === ZeroHash || !p.reveal.declared || p.reveal.requestMode > 1n || p.reveal.revealOwnerRole !== id("ROLE_ENTROPY_REVEAL_OWNER") || p.reveal.requestSLOBlocks === 0n) throw Error("ASYNC requires a provider and declared reveal policy");
  if (p.maxFreshRecoveryAttempts === 0n ? p.recoveryPolicyId !== ZeroHash || d.recoveryPolicyHash !== ZeroHash : p.recoveryPolicyId === ZeroHash || d.recoveryPolicyHash === ZeroHash) throw Error("Invalid supplied recovery binding");
  const recoveryChanged = s.recovery.policyId !== p.recoveryPolicyId || s.recovery.policyHash !== d.recoveryPolicyHash || s.recovery.maxFreshRecoveryAttempts !== p.maxFreshRecoveryAttempts;
  const changedProvider = s.config.provider !== p.provider || s.config.providerConfigHash !== d.providerConfigHash;
  const providerEpoch = uint(s.providerEpoch + (changedProvider || recoveryChanged ? 1n : 0n), 32, "next providerEpoch");
  const config = Object.freeze({ provider: p.provider, publicRequests: p.publicRequests, locked: false, timeoutBlocks: p.timeoutBlocks, providerConfigHash: d.providerConfigHash, providerCodeHash: d.providerCodeHash, collectionSalt: p.collectionSalt });
  const recovery = Object.freeze({ policyId: p.recoveryPolicyId, policyHash: d.recoveryPolicyHash, maxFreshRecoveryAttempts: p.maxFreshRecoveryAttempts,
    revision: uint(s.recovery.revision + (recoveryChanged ? 1n : 0n), 64, "next recovery revision"), lastActionId: s.recovery.lastActionId });
  const entry = Object.freeze({ ...s.entry, revision: s.entry.revision + 1n, mode: p.mode, securityClass: p.securityClass, renderRequirement: p.renderRequirement });
  const preimage = Object.freeze({ config, reveal: p.reveal, recovery, providerEpoch, entry });
  const policyHash = entropyCollectionPolicyHash(coordinateValues(s), preimage);
  if (s.entry.revision !== 0n && s.entry.policyHash === policyHash) throw Error("Explicit semantic no-op; fee-only changes use the original operational path");
  const next = Object.freeze({ ...preimage, entry: Object.freeze({ ...entry, policyHash }) });
  return Object.freeze({ ...resultBase(s, next, "configure", p), kind: "configure", actionClass: 1n, input: p, resolution: d });
}
export function prepareEntropyCollectionPolicyFreeze(snapshot: EntropyCollectionPolicySnapshot): Extract<EntropyCollectionPolicyPlan, { kind: "freeze" }> {
  const s = normalizeEntropyCollectionPolicySnapshot(snapshot); mutable(s); if (s.entry.revision === 0n) throw Error("Explicit policy required before freeze");
  const next = Object.freeze({ ...stateValues(s), config: Object.freeze({ ...s.config, locked: true }), entry: Object.freeze({ ...s.entry, revision: s.entry.revision + 1n }) });
  return Object.freeze({ ...resultBase(s, next, "freeze"), kind: "freeze", actionClass: 2n });
}
export function normalizeEntropyCollectionPolicyPlan(input: EntropyCollectionPolicyPlan): EntropyCollectionPolicyPlan {
  if (!input || (input.kind !== "configure" && input.kind !== "freeze")) throw Error("Unknown policy plan kind");
  exact(input, ["kind", "actionClass", "snapshot", "next", "transition", "targetCall", "previewCall", "governanceCall", "factsVerified", ...(input.kind === "configure" ? ["input", "resolution"] : [])], "Policy plan");
  const result = input.kind === "configure" ? prepareEntropyCollectionPolicyConfigure(input.snapshot, input.input, input.resolution) : prepareEntropyCollectionPolicyFreeze(input.snapshot);
  if (!sameTree(input, result)) throw Error("Policy plan differs from exact reconstruction"); return result;
}
export function prepareEntropyCollectionPolicyArtistConsent(input: EntropyCollectionPolicyPlan, registry: Address, caller: Address, signer: Address, authorization: EntropyCollectionPolicyAuthorization): EntropyCollectionPolicyArtistConsent {
  const plan = normalizeEntropyCollectionPolicyPlan(input), host = address(registry, false), actor = address(caller, false), signing = address(signer, false);
  exact(authorization, ["nonce", "deadline", "signature"], "Artist authorization");
  const auth = Object.freeze({ nonce: uint(authorization.nonce, 256, "Artist nonce"), deadline: uint(authorization.deadline, 64, "Artist deadline"), signature: bytes(authorization.signature) });
  const prepared = prepareArtistContentConsent(plan.snapshot.chainId, host, plan.snapshot.core,
    { collectionId: plan.snapshot.collectionId, contract: plan.snapshot.coordinator, familyId: ENTROPY_COLLECTION_POLICY_FAMILY }, plan.transition.artistContentStateHash, auth);
  return Object.freeze({ plan, registry: host, caller: actor, signer: signing, authorization: auth, direct: actor === signing && auth.signature === "0x", payload: prepared.payload, call: prepared.call, digestCall: prepared.digestCall, factsVerified: false });
}
export function normalizeEntropyCollectionPolicyArtistConsent(input: EntropyCollectionPolicyArtistConsent): EntropyCollectionPolicyArtistConsent {
  exact(input, ["plan", "registry", "caller", "signer", "authorization", "direct", "payload", "call", "digestCall", "factsVerified"], "Policy Artist consent");
  const result = prepareEntropyCollectionPolicyArtistConsent(input.plan, input.registry, input.caller, input.signer, input.authorization);
  if (!sameTree(input, result)) throw Error("Artist consent differs from exact reconstruction"); return result;
}
/** Original op17 record preimage; observedAt is the execution timestamp, not the signed deadline. */
export function entropyCollectionPolicyArtistRecordHash(input: EntropyCollectionPolicyPlan, record: EntropyCollectionPolicyArtistRecordInput): Hex {
  const p = normalizeEntropyCollectionPolicyPlan(input), s = p.snapshot; exact(record, ["registry", "artistId", "signer", "authorityClass", "nonce", "observedAt"], "Artist record facts");
  return digest(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"), s.chainId, address(record.registry, false), s.coordinator, s.core, s.collectionId, ENTROPY_COLLECTION_POLICY_FAMILY, p.transition.artistContentStateHash,
      bytes(record.artistId, 32), address(record.signer, false), uint(record.authorityClass, 8, "authorityClass"), uint(record.nonce, 256, "nonce"), uint(record.observedAt, 64, "observedAt")]);
}
export function normalizeEntropyCollectionPolicyGovernanceWindow(input: EntropyCollectionPolicyGovernanceWindow): EntropyCollectionPolicyGovernanceWindow { return normalizeMintPolicyGraceGovernanceWindow(input); }
export function assertEntropyCollectionPolicyGovernanceWindow(actionClass: 1n | 2n, input: EntropyCollectionPolicyGovernanceWindow, schedulingTimestamp: bigint): void {
  if (actionClass !== 1n && actionClass !== 2n) throw Error("Policy supports only configure class1 and freeze class2");
  const w = normalizeEntropyCollectionPolicyGovernanceWindow(input), at = uint(schedulingTimestamp, 256, "schedulingTimestamp");
  if (at > (1n << 64n) - 1n - 31536000n || w.notBefore < at + (actionClass === 1n ? 172800n : 259200n) || w.expiresAfter > at + 31536000n) throw Error("Outside original governance timing bounds");
}
export function entropyCollectionPolicyGovernanceBatch(input: EntropyCollectionPolicyPlan, nonce: bigint, window: EntropyCollectionPolicyGovernanceWindow): EntropyCollectionPolicyGovernanceBatch {
  const plan = normalizeEntropyCollectionPolicyPlan(input), n = uint(nonce, 256, "Governance nonce"), w = normalizeEntropyCollectionPolicyGovernanceWindow(window), executor = plan.snapshot.governanceExecutor;
  const calls = [plan.governanceCall], data = [plan.targetCall.data];
  const callsHash = digest(["bytes32", `${ENTROPY_COLLECTION_POLICY_GOVERNANCE_CALL_TUPLE}[]`], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain: Hex, field: "scopeHash" | "oldValueHash" | "newValueHash") => digest(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, calls.map(c => c[field])]);
  const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash"), oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash"), newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
  const actionId = digest(["bytes32", "uint256", "address", "tuple(uint8,bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64,bytes32,bytes32)"],
    ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", plan.snapshot.chainId, executor, [plan.actionClass, callsHash, scopeHash, oldValueHash, newValueHash, n, w.notBefore, w.expiresAfter, w.reasonHash, w.manifestHash]]);
  return Object.freeze({ plan, nonce: n, window: w, callsHash, scopeHash, oldValueHash, newValueHash, actionId, publicationKey: keccak256(plan.governanceCall.callDataHash) as Hex,
    publicationCall: call(executor, "publishGovernanceCallData", [data], governanceAbi), scheduleCall: call(executor, "scheduleGovernanceBatch", [plan.actionClass, calls, scopeHash, oldValueHash, newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash], governanceAbi), executionCall: call(executor, "executeGovernanceBatch", [actionId, calls, data], governanceAbi) });
}
export function normalizeEntropyCollectionPolicyGovernanceBatch(input: EntropyCollectionPolicyGovernanceBatch): EntropyCollectionPolicyGovernanceBatch {
  exact(input, ["plan", "nonce", "window", "callsHash", "scopeHash", "oldValueHash", "newValueHash", "actionId", "publicationKey", "publicationCall", "scheduleCall", "executionCall"], "Policy governance batch");
  const result = entropyCollectionPolicyGovernanceBatch(input.plan, input.nonce, input.window); if (!sameTree(input, result)) throw Error("Policy governance batch differs from exact reconstruction"); return result;
}
