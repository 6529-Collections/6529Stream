import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as policy from "./current-entropy-collection-policy.js";
import { prepareArtistContentConsent, type ManifestContentConsent } from "./current-manifests.js";
import type { SigningPayload } from "./signing.js";

export type EntropyInstantPolicySnapshot = policy.EntropyCollectionPolicySnapshot;
export type EntropyInstantPolicyState = policy.EntropyCollectionPolicyState;
export type EntropyInstantPolicyRecord = policy.EntropyCollectionPolicyRecord;
export type EntropyInstantPolicyCoordinates = policy.EntropyCollectionPolicyCoordinates;
export type EntropyInstantPolicyInput = Omit<policy.EntropyCollectionPolicyInput, "mode" | "securityClass"> & { readonly mode: 1n; readonly securityClass: 1n };
export interface EntropyInstantPolicyResolution extends policy.EntropyCollectionPolicyResolution { readonly instantMode: 1n; readonly assumptionsHash: Hex }
export type EntropyInstantPolicyPlan = Omit<policy.EntropyCollectionPolicyPlan, "kind" | "actionClass"> & (
  { readonly kind: "configure"; readonly actionClass: 1n; readonly input: EntropyInstantPolicyInput; readonly resolution: EntropyInstantPolicyResolution }
  | { readonly kind: "freeze"; readonly actionClass: 2n });
export type EntropyInstantPolicyGovernanceWindow = policy.EntropyCollectionPolicyGovernanceWindow;
export interface EntropyInstantPolicyGovernanceBatch extends Omit<policy.EntropyCollectionPolicyGovernanceBatch, "plan"> { readonly plan: EntropyInstantPolicyPlan }
export type EntropyInstantPolicyAuthorization = policy.EntropyCollectionPolicyAuthorization;
export type EntropyInstantPolicyArtistRecordInput = policy.EntropyCollectionPolicyArtistRecordInput;
export interface EntropyInstantPolicyArtistConsent {
  readonly plan: EntropyInstantPolicyPlan; readonly registry: Address; readonly caller: Address; readonly signer: Address;
  readonly authorization: EntropyInstantPolicyAuthorization; readonly direct: boolean; readonly payload: SigningPayload<ManifestContentConsent>;
  readonly call: UnsignedCall; readonly digestCall: UnsignedCall; readonly factsVerified: false;
}
export interface EntropyInstantProviderProfile { readonly mode: 1n; readonly assumptionsHash: Hex }
export interface EntropyInstantRequestCoordinates { readonly chainId: bigint; readonly coordinator: Address; readonly core: Address; readonly collectionId: bigint; readonly tokenId: bigint }
export interface EntropyInstantRequestPolicySnapshot {
  readonly provider: Address; readonly providerCodeHash: Hex; readonly providerEpoch: bigint; readonly providerConfigHash: Hex;
  readonly collectionSalt: Hex; readonly inputsHash: Hex; readonly requestAttempt: bigint;
}
/** Original subject inputsHash remains the mint commitment; it is not copied into the INSTANT request snapshot. */
export interface EntropyInstantSubject { readonly collectionId: bigint; readonly inputsHash: Hex; readonly requestKey: Hex; readonly seed: Hex; readonly status: bigint }
export interface EntropyInstantRequestSnapshot extends EntropyInstantRequestCoordinates {
  readonly config: policy.EntropyCollectionPolicyConfig; readonly policy: EntropyInstantPolicyRecord; readonly subject: EntropyInstantSubject;
  readonly registeredAtBlock: bigint; readonly blockNumber: bigint; readonly tokenLifecycle: bigint; readonly coordinatorAtMint: Address;
}
export interface EntropyInstantRequestPlan {
  readonly snapshot: EntropyInstantRequestSnapshot; readonly caller: Address; readonly value: bigint;
  readonly subjectKey: Hex; readonly requestKey: Hex; readonly providerRequestId: bigint;
  readonly requestPolicy: EntropyInstantRequestPolicySnapshot; readonly context: Hex; readonly call: UnsignedCall;
  readonly providerFee: 0n; readonly callerCredit: bigint; readonly factsVerified: false;
}
/** Exactly the original 16 return words. The getter name does not establish terminal status or finality. */
export interface EntropyInstantTerminalFacts { readonly collectionId: bigint; readonly policy: EntropyInstantPolicyRecord; readonly status: bigint; readonly seed: Hex; readonly requestKey: Hex }

export const ENTROPY_INSTANT_PROVIDER_INTERFACE_ID = "0x5d42f023" as const;
export const ENTROPY_INSTANT_IDENTITY_INTERFACE_ID = "0xb8bedf9e" as const;
export const ENTROPY_INSTANT_TERMINAL_FACTS_INTERFACE_ID = "0x40016975" as const;
export const ENTROPY_INSTANT_ASSUMPTIONS = "LOW_SECURITY: previous-block hash; validator influence; publicly simulatable; request-timing selection; not VRF; mintCommitment excluded";
export const ENTROPY_INSTANT_ASSUMPTIONS_HASH = id(ENTROPY_INSTANT_ASSUMPTIONS) as Hex;
export const ENTROPY_INSTANT_PROVIDER_FAMILY = id("STREAM_INSTANT_DELAYED_BLOCKHASH") as Hex;
export const ENTROPY_INSTANT_PROVIDER_VERSION = id("6529stream.entropy-provider-instant-blockhash.v1") as Hex;
export const ENTROPY_INSTANT_READ_GAS = id("6529STREAM_GGP_ENTROPY_INSTANT_READ_GAS_LIMIT") as Hex;
export const ENTROPY_INSTANT_REQUEST_POLICY_TUPLE = "tuple(address provider,bytes32 providerCodeHash,uint32 providerEpoch,bytes32 providerConfigHash,bytes32 collectionSalt,bytes32 inputsHash,uint16 requestAttempt)";
export const ENTROPY_INSTANT_SUBJECT_TUPLE = "tuple(uint256 collectionId,bytes32 inputsHash,bytes32 requestKey,bytes32 seed,uint8 status)";
export const ENTROPY_INSTANT_TERMINAL_FACTS_TUPLE = `tuple(uint256 collectionId,${policy.ENTROPY_COLLECTION_POLICY_RECORD_TUPLE} policy,uint8 status,bytes32 seed,bytes32 requestKey)`;
export const CURRENT_ENTROPY_INSTANT_POLICY_ABI = policy.CURRENT_ENTROPY_COLLECTION_POLICY_ABI;
export const CURRENT_ENTROPY_INSTANT_GOVERNANCE_ABI = policy.CURRENT_ENTROPY_COLLECTION_POLICY_GOVERNANCE_ABI;
export const CURRENT_ENTROPY_INSTANT_ABI: readonly string[] = Object.freeze([
  "function requestEntropy(uint256 tokenId) payable returns(bytes32 requestKey,uint256 providerRequestId)",
  `function requestPolicySnapshot(bytes32 requestKey) view returns(${ENTROPY_INSTANT_REQUEST_POLICY_TUPLE})`,
  `function staticTerminalEntropyFacts(uint256 tokenId) view returns(uint256 collectionId,${policy.ENTROPY_COLLECTION_POLICY_RECORD_TUPLE} policy,uint8 status,bytes32 seed,bytes32 requestKey)`,
  "function retryMetadataNotification(uint256 tokenId)",
  "event EntropyRequested(bytes32 indexed requestKey,uint256 indexed tokenId,bytes32 indexed scopeId,address provider,uint256 providerRequestId)",
  "event InstantEntropyProduced(uint16 schemaVersion,bytes32 indexed requestKey,uint256 indexed providerRequestId,bytes32 rawRandomness,bytes32 provenanceHash,uint8 mode,bytes32 assumptionsHash)",
  "event EntropyFinalized(bytes32 indexed requestKey,uint256 indexed tokenId,bytes32 indexed scopeId,bytes32 seed,bytes32 rawRandomness)",
  "event EntropyFeeCredited(address indexed payer,uint256 amount)",
  "event MetadataNotificationFailed(uint256 indexed tokenId,bytes32 indexed requestKey)",
]);
export const CURRENT_ENTROPY_INSTANT_PROVIDER_ABI: readonly string[] = Object.freeze([
  "function instantEntropy(bytes32 requestKey,bytes context) view returns(bytes32 rawRandomness,bytes32 provenanceHash)",
  "function isStreamInstantEntropyProvider() view returns(bool)",
  "function streamEntropyProviderFamily() pure returns(bytes32)", "function streamEntropyProviderVersion() pure returns(bytes32)",
  "function streamEntropyProviderConfigHash() view returns(bytes32)", "function instantEntropyProfile() view returns(uint8 mode,bytes32 assumptionsHash)",
]);
const coder = AbiCoder.defaultAbiCoder(), policyAbi = new Interface(CURRENT_ENTROPY_INSTANT_POLICY_ABI), abi = new Interface(CURRENT_ENTROPY_INSTANT_ABI), gov = new Interface(CURRENT_ENTROPY_INSTANT_GOVERNANCE_ABI);
function exact(value: unknown, keys: readonly string[], label: string): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error(`${label} must be an object`);
  const actual = Reflect.ownKeys(value); if (actual.length !== keys.length || actual.some(k => typeof k !== "string" || !keys.includes(k))) throw Error(`${label} has missing or unknown fields`);
}
function uint(value: unknown, bits: number, label: string): bigint { if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`${label} must be uint${bits} bigint`); return value; }
function hex(value: unknown, size?: number): Hex { if (typeof value !== "string" || !isHexString(value, size) || value.length % 2 !== 0) throw Error("Expected hex bytes"); return value.toLowerCase() as Hex; }
function addr(value: unknown, zero = false): Address { if (typeof value !== "string") throw Error("Expected address"); const v = getAddress(value) as Address; if (!zero && v === ZeroAddress) throw Error("Expected nonzero address"); return v; }
function nonzero(value: Hex): Hex { if (BigInt(value) === 0n) throw Error("Expected nonzero commitment"); return value; }
function digest(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(coder.encode(types, values)) as Hex; }
function normal(p: ParamType, value: unknown, decoded = false): unknown {
  if (p.baseType === "tuple") { if (!decoded) exact(value, p.components!.map(f => f.name), "Tuple"); return Object.freeze(Object.fromEntries(p.components!.map((f, i) => [f.name, normal(f, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[f.name], decoded)]))); }
  if (p.type === "address") return addr(value, true);
  if (p.type === "bool") { if (typeof value !== "boolean") throw Error("Expected boolean"); return value; }
  if (p.type.startsWith("uint")) return uint(value, Number(p.type.slice(4)), p.name);
  if (p.type.startsWith("bytes")) return hex(value, Number(p.type.slice(5)));
  throw Error("Unsupported fixed tuple");
}
function tuple<T>(type: string, input: T): T { return normal(ParamType.from(type), input) as T; }
function decode<T>(type: string, input: Hex, length: number): T { const raw = hex(input); if (raw.length !== 2 + length * 2) throw Error("Wrong original tuple byte length"); const value = normal(ParamType.from(type), coder.decode([type], raw)[0], true) as T; if (coder.encode([type], [value]) !== raw) throw Error("Noncanonical ABI encoding"); return value; }
function same(a: unknown, b: unknown): boolean { if (a === b) return true; if (!a || !b || typeof a !== "object" || typeof b !== "object" || Array.isArray(a) !== Array.isArray(b)) return false; const keys = Reflect.ownKeys(a), other = Reflect.ownKeys(b); return keys.length === other.length && keys.every(k => other.includes(k) && same(Reflect.get(a, k), Reflect.get(b, k))); }
function call(to: Address, method: string, args: readonly unknown[], intf = abi, value = 0n): UnsignedCall { return Object.freeze({ to: addr(to), data: intf.encodeFunctionData(method, args) as Hex, value: uint(value, 256, "value") }); }
function coords(s: EntropyInstantPolicySnapshot): EntropyInstantPolicyCoordinates { return { chainId: s.chainId, coordinator: s.coordinator, core: s.core, governanceExecutor: s.governanceExecutor, collectionId: s.collectionId }; }
function state(s: EntropyInstantPolicyState): EntropyInstantPolicyState { return { config: s.config, providerEpoch: s.providerEpoch, reveal: s.reveal, recovery: s.recovery, entry: s.entry }; }
export const normalizeEntropyInstantPolicySnapshot = policy.normalizeEntropyCollectionPolicySnapshot;
export const normalizeEntropyInstantPolicyRecord = policy.normalizeEntropyCollectionPolicyRecord;
export const normalizeEntropyInstantPolicyState = policy.normalizeEntropyCollectionPolicyState;
export const entropyInstantPolicyRecord = policy.entropyCollectionPolicyRecord;
export const entropyInstantPolicyEntryFromRecord = policy.entropyCollectionPolicyEntryFromRecord;
export const entropyInstantPolicyHash = policy.entropyCollectionPolicyHash;
export const entropyInstantPolicyContentStateHash = policy.entropyCollectionPolicyContentStateHash;
export function normalizeEntropyInstantProviderProfile(input: EntropyInstantProviderProfile): EntropyInstantProviderProfile {
  exact(input, ["mode", "assumptionsHash"], "Instant provider profile"); if (input.mode !== 1n) throw Error("Only DELAYED_BLOCKHASH mode1 is supported");
  return Object.freeze({ mode: 1n, assumptionsHash: nonzero(hex(input.assumptionsHash, 32)) });
}
export function normalizeEntropyInstantPolicyInput(input: EntropyInstantPolicyInput): EntropyInstantPolicyInput {
  const v = policy.normalizeEntropyCollectionPolicyInput(input);
  if (v.mode !== 1n || v.securityClass !== 1n) throw Error("This separate profile requires INSTANT and LOW_SECURITY");
  if (v.provider === ZeroAddress || v.timeoutBlocks !== 0n || v.reveal.declared || v.reveal.requestMode !== 0n || v.reveal.revealOwnerRole !== ZeroHash || v.reveal.requestSLOBlocks !== 0n || v.reveal.revealFeePerTokenWei !== 0n || v.maxFreshRecoveryAttempts !== 0n || v.recoveryPolicyId !== ZeroHash) throw Error("INSTANT requires zero timeout, reveal and recovery fields");
  return v as EntropyInstantPolicyInput;
}
export function normalizeEntropyInstantPolicyResolution(input: EntropyInstantPolicyResolution): EntropyInstantPolicyResolution {
  exact(input, ["providerCodeHash", "providerConfigHash", "recoveryPolicyHash", "instantMode", "assumptionsHash"], "Instant policy resolution");
  const p = normalizeEntropyInstantProviderProfile({ mode: input.instantMode, assumptionsHash: input.assumptionsHash });
  const recoveryPolicyHash = hex(input.recoveryPolicyHash, 32); if (recoveryPolicyHash !== ZeroHash) throw Error("INSTANT has no fresh recovery binding");
  return Object.freeze({ providerCodeHash: nonzero(hex(input.providerCodeHash, 32)), providerConfigHash: nonzero(hex(input.providerConfigHash, 32)), recoveryPolicyHash, instantMode: p.mode, assumptionsHash: p.assumptionsHash });
}
/** Exact b4bb worker replay from supplied facts. Capability/runtime/active-provider admission is not proved here. */
export function prepareEntropyInstantPolicyConfigure(snapshot: EntropyInstantPolicySnapshot, input: EntropyInstantPolicyInput, resolution: EntropyInstantPolicyResolution): Extract<EntropyInstantPolicyPlan, { kind: "configure" }> {
  const s = normalizeEntropyInstantPolicySnapshot(snapshot), v = normalizeEntropyInstantPolicyInput(input), d = normalizeEntropyInstantPolicyResolution(resolution);
  if (!s.collectionExists || s.collectionFrozen || s.collectionMintedEver !== 0n || s.config.locked || s.entry.revision === (1n << 64n) - 1n || s.revealEscrow !== 0n) throw Error("Collection policy unavailable, locked or funded");
  const recoveryChanged = s.recovery.policyId !== ZeroHash || s.recovery.policyHash !== ZeroHash || s.recovery.maxFreshRecoveryAttempts !== 0n;
  const changedProvider = s.config.provider !== v.provider || s.config.providerConfigHash !== d.providerConfigHash;
  const providerEpoch = uint(s.providerEpoch + (recoveryChanged || changedProvider ? 1n : 0n), 32, "next provider epoch");
  const config = Object.freeze({ provider: v.provider, publicRequests: v.publicRequests, locked: false, timeoutBlocks: 0n, providerConfigHash: d.providerConfigHash, providerCodeHash: d.providerCodeHash, collectionSalt: v.collectionSalt });
  const recovery = Object.freeze({ policyId: ZeroHash as Hex, policyHash: ZeroHash as Hex, maxFreshRecoveryAttempts: 0n, revision: uint(s.recovery.revision + (recoveryChanged ? 1n : 0n), 64, "next recovery revision"), lastActionId: s.recovery.lastActionId });
  const entry = Object.freeze({ ...s.entry, revision: s.entry.revision + 1n, mode: 1n as const, securityClass: 1n as const, renderRequirement: v.renderRequirement });
  const preimage = Object.freeze({ config, providerEpoch, reveal: v.reveal, recovery, entry });
  const policyHash = policy.entropyCollectionPolicyHash(coords(s), preimage);
  if (s.entry.revision !== 0n && s.entry.policyHash === policyHash) throw Error("Explicit policy semantic no-op");
  const next = Object.freeze({ ...preimage, entry: Object.freeze({ ...entry, policyHash }) });
  const scopeHash = policy.entropyCollectionPolicyScopeHash(coords(s), "configure");
  const transition = Object.freeze({ scopeHash, oldValueHash: policy.entropyCollectionPolicyStateHash(scopeHash, state(s)), newValueHash: policy.entropyCollectionPolicyStateHash(scopeHash, next), artistContentStateHash: policy.entropyCollectionPolicyContentStateHash(policyHash, false) });
  const targetCall = call(s.coordinator, "configureCollectionEntropyPolicy", [s.collectionId, v], policyAbi), previewCall = call(s.coordinator, "collectionEntropyPolicyTransition", [s.collectionId, v], policyAbi);
  const governanceCall = Object.freeze({ target: targetCall.to, value: 0n, selector: targetCall.data.slice(0, 10) as Hex, callDataHash: keccak256(targetCall.data) as Hex, scopeHash, oldValueHash: transition.oldValueHash, newValueHash: transition.newValueHash });
  return Object.freeze({ kind: "configure", actionClass: 1n, snapshot: s, input: v, resolution: d, next, transition, targetCall, previewCall, governanceCall, factsVerified: false });
}
export function prepareEntropyInstantPolicyFreeze(snapshot: EntropyInstantPolicySnapshot): Extract<EntropyInstantPolicyPlan, { kind: "freeze" }> {
  const s = normalizeEntropyInstantPolicySnapshot(snapshot); if (s.entry.mode !== 1n || s.entry.securityClass !== 1n) throw Error("This freeze profile requires an explicit INSTANT policy");
  // The original freeze worker and hashes are unchanged; its normalizer accepts the original enum1.
  return policy.prepareEntropyCollectionPolicyFreeze(s);
}
export function normalizeEntropyInstantPolicyPlan(input: EntropyInstantPolicyPlan): EntropyInstantPolicyPlan {
  if (!input || (input.kind !== "configure" && input.kind !== "freeze")) throw Error("Unknown instant policy operation");
  exact(input, ["kind", "actionClass", "snapshot", "next", "transition", "targetCall", "previewCall", "governanceCall", "factsVerified", ...(input.kind === "configure" ? ["input", "resolution"] : [])], "Instant policy plan");
  const result = input.kind === "configure" ? prepareEntropyInstantPolicyConfigure(input.snapshot, input.input, input.resolution) : prepareEntropyInstantPolicyFreeze(input.snapshot);
  if (!same(input, result)) throw Error("Instant policy plan differs from reconstruction"); return result;
}
export function prepareEntropyInstantPolicyArtistConsent(input: EntropyInstantPolicyPlan, registry: Address, caller: Address, signer: Address, authorization: EntropyInstantPolicyAuthorization): EntropyInstantPolicyArtistConsent {
  const plan = normalizeEntropyInstantPolicyPlan(input), host = addr(registry), actor = addr(caller), signing = addr(signer); exact(authorization, ["nonce", "deadline", "signature"], "Artist authorization");
  const auth = Object.freeze({ nonce: uint(authorization.nonce, 256, "nonce"), deadline: uint(authorization.deadline, 64, "deadline"), signature: hex(authorization.signature) });
  const prepared = prepareArtistContentConsent(plan.snapshot.chainId, host, plan.snapshot.core, { collectionId: plan.snapshot.collectionId, contract: plan.snapshot.coordinator, familyId: policy.ENTROPY_COLLECTION_POLICY_FAMILY }, plan.transition.artistContentStateHash, auth);
  return Object.freeze({ plan, registry: host, caller: actor, signer: signing, authorization: auth, direct: actor === signing && auth.signature === "0x", payload: prepared.payload, call: prepared.call, digestCall: prepared.digestCall, factsVerified: false });
}
export function normalizeEntropyInstantPolicyArtistConsent(input: EntropyInstantPolicyArtistConsent): EntropyInstantPolicyArtistConsent {
  exact(input, ["plan", "registry", "caller", "signer", "authorization", "direct", "payload", "call", "digestCall", "factsVerified"], "Instant policy consent");
  const result = prepareEntropyInstantPolicyArtistConsent(input.plan, input.registry, input.caller, input.signer, input.authorization); if (!same(input, result)) throw Error("Instant consent differs from reconstruction"); return result;
}
export function entropyInstantPolicyArtistRecordHash(input: EntropyInstantPolicyPlan, record: EntropyInstantPolicyArtistRecordInput): Hex {
  const p = normalizeEntropyInstantPolicyPlan(input), s = p.snapshot; exact(record, ["registry", "artistId", "signer", "authorityClass", "nonce", "observedAt"], "Artist record facts");
  return digest(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"], [id("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"), s.chainId, addr(record.registry), s.coordinator, s.core, s.collectionId, policy.ENTROPY_COLLECTION_POLICY_FAMILY, p.transition.artistContentStateHash, hex(record.artistId, 32), addr(record.signer), uint(record.authorityClass, 8, "authorityClass"), uint(record.nonce, 256, "nonce"), uint(record.observedAt, 64, "observedAt")]);
}
export const normalizeEntropyInstantPolicyGovernanceWindow = policy.normalizeEntropyCollectionPolicyGovernanceWindow;
export const assertEntropyInstantPolicyGovernanceWindow = policy.assertEntropyCollectionPolicyGovernanceWindow;
export function entropyInstantPolicyGovernanceBatch(input: EntropyInstantPolicyPlan, nonce: bigint, window: EntropyInstantPolicyGovernanceWindow): EntropyInstantPolicyGovernanceBatch {
  const plan = normalizeEntropyInstantPolicyPlan(input), n = uint(nonce, 256, "Governance nonce"), w = normalizeEntropyInstantPolicyGovernanceWindow(window), executor = plan.snapshot.governanceExecutor;
  const calls = [plan.governanceCall], data = [plan.targetCall.data], callsHash = digest(["bytes32", `${policy.ENTROPY_COLLECTION_POLICY_GOVERNANCE_CALL_TUPLE}[]`], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain: Hex, field: "scopeHash" | "oldValueHash" | "newValueHash") => digest(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, calls.map(c => c[field])]);
  const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash"), oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash"), newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
  const actionId = digest(["bytes32", "uint256", "address", "tuple(uint8,bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64,bytes32,bytes32)"], ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", plan.snapshot.chainId, executor, [plan.actionClass, callsHash, scopeHash, oldValueHash, newValueHash, n, w.notBefore, w.expiresAfter, w.reasonHash, w.manifestHash]]);
  return Object.freeze({ plan, nonce: n, window: w, callsHash, scopeHash, oldValueHash, newValueHash, actionId, publicationKey: keccak256(plan.governanceCall.callDataHash) as Hex, publicationCall: call(executor, "publishGovernanceCallData", [data], gov), scheduleCall: call(executor, "scheduleGovernanceBatch", [plan.actionClass, calls, scopeHash, oldValueHash, newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash], gov), executionCall: call(executor, "executeGovernanceBatch", [actionId, calls, data], gov) });
}
export function normalizeEntropyInstantPolicyGovernanceBatch(input: EntropyInstantPolicyGovernanceBatch): EntropyInstantPolicyGovernanceBatch {
  exact(input, ["plan", "nonce", "window", "callsHash", "scopeHash", "oldValueHash", "newValueHash", "actionId", "publicationKey", "publicationCall", "scheduleCall", "executionCall"], "Instant governance batch");
  const result = entropyInstantPolicyGovernanceBatch(input.plan, input.nonce, input.window); if (!same(input, result)) throw Error("Instant batch differs from reconstruction"); return result;
}

export function normalizeEntropyInstantRequestCoordinates(input: EntropyInstantRequestCoordinates): EntropyInstantRequestCoordinates {
  exact(input, ["chainId", "coordinator", "core", "collectionId", "tokenId"], "Instant request coordinates");
  const collectionId = uint(input.collectionId, 256, "collectionId"), tokenId = uint(input.tokenId, 256, "tokenId"); if (!collectionId || !tokenId) throw Error("Token and collection IDs must be positive");
  return Object.freeze({ chainId: uint(input.chainId, 256, "chainId"), coordinator: addr(input.coordinator), core: addr(input.core), collectionId, tokenId });
}
function requestCoords(s: EntropyInstantRequestCoordinates): EntropyInstantRequestCoordinates { return normalizeEntropyInstantRequestCoordinates({ chainId: s.chainId, coordinator: s.coordinator, core: s.core, collectionId: s.collectionId, tokenId: s.tokenId }); }
/** Original snapshot codec permits the zero unknown-request tuple; INSTANT preparation constructs attempt1/inputsHash0. */
export function normalizeEntropyInstantRequestPolicySnapshot(input: EntropyInstantRequestPolicySnapshot): EntropyInstantRequestPolicySnapshot { return tuple(ENTROPY_INSTANT_REQUEST_POLICY_TUPLE, input); }
export function encodeEntropyInstantRequestPolicySnapshot(input: EntropyInstantRequestPolicySnapshot): Hex { return coder.encode([ENTROPY_INSTANT_REQUEST_POLICY_TUPLE], [normalizeEntropyInstantRequestPolicySnapshot(input)]) as Hex; }
export function decodeEntropyInstantRequestPolicySnapshot(input: Hex): EntropyInstantRequestPolicySnapshot { return normalizeEntropyInstantRequestPolicySnapshot(decode(ENTROPY_INSTANT_REQUEST_POLICY_TUPLE, input, 224)); }
export function normalizeEntropyInstantSubject(input: EntropyInstantSubject): EntropyInstantSubject { const s = tuple(ENTROPY_INSTANT_SUBJECT_TUPLE, input); if (s.status > 7n) throw Error("Unknown original subject status"); return s; }
export function normalizeEntropyInstantRequestSnapshot(input: EntropyInstantRequestSnapshot): EntropyInstantRequestSnapshot {
  exact(input, ["chainId", "coordinator", "core", "collectionId", "tokenId", "config", "policy", "subject", "registeredAtBlock", "blockNumber", "tokenLifecycle", "coordinatorAtMint"], "Instant request snapshot");
  return Object.freeze({ ...requestCoords(input), config: policy.normalizeEntropyCollectionPolicyConfig(input.config), policy: normalizeEntropyInstantPolicyRecord(input.policy), subject: normalizeEntropyInstantSubject(input.subject), registeredAtBlock: uint(input.registeredAtBlock, 64, "registeredAtBlock"), blockNumber: uint(input.blockNumber, 256, "blockNumber"), tokenLifecycle: uint(input.tokenLifecycle, 8, "tokenLifecycle"), coordinatorAtMint: addr(input.coordinatorAtMint, true) });
}
function instantRequestPolicy(input: EntropyInstantRequestPolicySnapshot): EntropyInstantRequestPolicySnapshot {
  const p = normalizeEntropyInstantRequestPolicySnapshot(input); addr(p.provider); nonzero(p.providerCodeHash); nonzero(p.providerConfigHash);
  if (p.inputsHash !== ZeroHash || p.requestAttempt !== 1n) throw Error("INSTANT token request requires inputsHash0 and attempt1"); return p;
}
export function entropyInstantContext(coordinates: EntropyInstantRequestCoordinates, snapshot: EntropyInstantRequestPolicySnapshot): Hex {
  const c = normalizeEntropyInstantRequestCoordinates(coordinates), p = instantRequestPolicy(snapshot);
  return coder.encode(["uint16", "address", "uint256", "uint256", "bytes32", "uint32", "bytes32", "uint16", "bytes32"], [1n, c.core, c.collectionId, c.tokenId, ZeroHash, p.providerEpoch, p.providerConfigHash, p.requestAttempt, p.inputsHash]) as Hex;
}
export function entropyInstantRequestKey(coordinates: EntropyInstantRequestCoordinates, snapshot: EntropyInstantRequestPolicySnapshot): Hex {
  const c = normalizeEntropyInstantRequestCoordinates(coordinates), p = instantRequestPolicy(snapshot);
  return digest(["bytes32", "uint256", "address", "address", "uint256", "uint256", "address", "uint32", "bytes32", "uint16"], [id("6529STREAM_ENTROPY_REQUEST_V1"), c.chainId, c.coordinator, c.core, c.collectionId, c.tokenId, p.provider, p.providerEpoch, p.providerConfigHash, p.requestAttempt]);
}
export function entropyInstantProviderRequestId(requestKey: Hex, snapshot: EntropyInstantRequestPolicySnapshot): bigint {
  const p = instantRequestPolicy(snapshot);
  return BigInt(digest(["bytes32", "bytes32", "uint16", "address", "uint32", "bytes32"], [id("6529STREAM_INSTANT_PROVIDER_REQUEST_V1"), hex(requestKey, 32), p.requestAttempt, p.provider, p.providerEpoch, p.providerConfigHash]));
}
export function entropyInstantSubjectKey(tokenId: bigint): Hex { return digest(["string", "uint256"], ["TOKEN", uint(tokenId, 256, "tokenId")]); }
/** Prepares only the original token request. Supplied facts do not establish caller authority, provider admission or a successful result. */
export function prepareEntropyInstantRequest(snapshot: EntropyInstantRequestSnapshot, caller: Address, value: bigint): EntropyInstantRequestPlan {
  const s = normalizeEntropyInstantRequestSnapshot(snapshot), actor = addr(caller), amount = uint(value, 256, "value"), record = s.policy;
  if (!record.explicitPolicy || !record.configured || record.revision === 0n || record.mode !== 1n || record.securityClass !== 1n || record.renderRequirement !== 0n || s.subject.status !== 3n || s.subject.collectionId !== s.collectionId || s.tokenLifecycle !== 2n || s.coordinatorAtMint !== s.coordinator) throw Error("Not an original registered REQUIRED INSTANT token");
  if (s.blockNumber <= s.registeredAtBlock || s.blockNumber > (1n << 64n) - 1n) throw Error("INSTANT request requires a later representable block");
  const requestPolicy = instantRequestPolicy({ provider: s.config.provider, providerCodeHash: s.config.providerCodeHash, providerEpoch: record.providerEpoch, providerConfigHash: s.config.providerConfigHash, collectionSalt: s.config.collectionSalt, inputsHash: ZeroHash as Hex, requestAttempt: 1n });
  const c = requestCoords(s), context = entropyInstantContext(c, requestPolicy), requestKey = entropyInstantRequestKey(c, requestPolicy), providerRequestId = entropyInstantProviderRequestId(requestKey, requestPolicy);
  return Object.freeze({ snapshot: s, caller: actor, value: amount, subjectKey: entropyInstantSubjectKey(s.tokenId), requestKey, providerRequestId, requestPolicy, context, call: call(s.coordinator, "requestEntropy", [s.tokenId], abi, amount), providerFee: 0n, callerCredit: amount, factsVerified: false });
}
export function normalizeEntropyInstantRequestPlan(input: EntropyInstantRequestPlan): EntropyInstantRequestPlan {
  exact(input, ["snapshot", "caller", "value", "subjectKey", "requestKey", "providerRequestId", "requestPolicy", "context", "call", "providerFee", "callerCredit", "factsVerified"], "Instant request plan");
  const result = prepareEntropyInstantRequest(input.snapshot, input.caller, input.value); if (!same(input, result)) throw Error("Instant request differs from reconstruction"); return result;
}
/** Production previous-block adapter configuration; this hash alone does not attest its runtime. */
export function entropyInstantProviderConfigHash(coordinator: Address, assumptionsHash: Hex = ENTROPY_INSTANT_ASSUMPTIONS_HASH): Hex {
  return digest(["bytes32", "address", "uint8", "bytes32"], [id("6529STREAM_INSTANT_BLOCKHASH_CONFIG_V1"), addr(coordinator), 1n, hex(assumptionsHash, 32)]);
}
/** Uses an explicitly supplied source block/hash. Callers must join these to execution block-1; no future block is predicted. */
export function entropyInstantRawResult(requestKey: Hex, context: Hex, sourceBlock: bigint, sourceBlockHash: Hex, providerConfigHash: Hex, assumptionsHash: Hex): Readonly<{ rawRandomness: Hex; provenanceHash: Hex }> {
  const key = nonzero(hex(requestKey, 32)), contextHash = keccak256(hex(context)), block = uint(sourceBlock, 256, "sourceBlock"), blockHash = hex(sourceBlockHash, 32);
  return Object.freeze({ rawRandomness: digest(["bytes32", "bytes32", "bytes32", "uint256", "bytes32"], [id("6529STREAM_INSTANT_BLOCKHASH_RAW_V1"), key, contextHash, block, blockHash]),
    provenanceHash: digest(["bytes32", "bytes32", "bytes32", "bytes32", "uint256", "bytes32", "bytes32"], [id("6529STREAM_INSTANT_BLOCKHASH_PROVENANCE_V1"), hex(providerConfigHash, 32), key, contextHash, block, blockHash, hex(assumptionsHash, 32)]) });
}
export function entropyInstantSeed(input: EntropyInstantRequestPlan, rawRandomness: Hex): Hex {
  const p = normalizeEntropyInstantRequestPlan(input), s = p.snapshot, q = p.requestPolicy;
  return digest(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "address", "uint32", "bytes32", "bytes32", "uint256", "bytes32", "bytes32", "bytes32"], [id("6529STREAM_ENTROPY_SEED_V1"), s.chainId, s.coordinator, s.core, s.collectionId, `0x${s.tokenId.toString(16).padStart(64, "0")}`, q.provider, q.providerEpoch, q.providerConfigHash, p.requestKey, p.providerRequestId, hex(rawRandomness, 32), q.collectionSalt, q.inputsHash]);
}
export function normalizeEntropyInstantTerminalFacts(input: EntropyInstantTerminalFacts): EntropyInstantTerminalFacts {
  const value = tuple(ENTROPY_INSTANT_TERMINAL_FACTS_TUPLE, input); if (value.status > 7n) throw Error("Unknown original subject status");
  return Object.freeze({ ...value, policy: normalizeEntropyInstantPolicyRecord(value.policy) });
}
export function encodeEntropyInstantTerminalFacts(input: EntropyInstantTerminalFacts): Hex { return coder.encode([ENTROPY_INSTANT_TERMINAL_FACTS_TUPLE], [normalizeEntropyInstantTerminalFacts(input)]) as Hex; }
export function decodeEntropyInstantTerminalFacts(raw: Hex): EntropyInstantTerminalFacts { return normalizeEntropyInstantTerminalFacts(decode(ENTROPY_INSTANT_TERMINAL_FACTS_TUPLE, raw, 512)); }
