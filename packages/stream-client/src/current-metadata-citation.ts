import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { normalizeMintPolicyGraceGovernanceWindow, type MintPolicyGraceGovernanceCall,
  type MintPolicyGraceGovernanceWindow } from "./current-mint-policy-grace.js";

export interface MetadataCitationRegistration {
  readonly versionKey: Hex; readonly profile: Hex; readonly selector: Hex; readonly encoding: Address;
  readonly encodingRuntimeHash: Hex; readonly analysisDocument: Hex; readonly goldenDocument: Hex;
}
/** Original source-declared tuple; no public ABI method returns CurrentAnalysis. */
export interface MetadataCitationAnalysis {
  readonly analysisProfile: Hex; readonly outputProfile: Hex; readonly selector: Hex; readonly renderer: Address;
  readonly runtimeHash: Hex; readonly encoding: Address; readonly encodingRuntimeHash: Hex; readonly readSetHash: Hex;
  readonly originalRegistrationHash: Hex; readonly toolHash: Hex; readonly findingsHash: Hex; readonly passed: boolean;
}
export interface MetadataCitationRenderRequest {
  readonly core: Address; readonly tokenId: bigint; readonly collectionId: bigint; readonly collectionSerial: bigint;
  readonly tokenHash: Hex; readonly state: bigint; readonly mode: bigint; readonly collectionSupplyMode: bigint;
  readonly collectionStatus: bigint; readonly viewId: Hex; readonly viewManifestHash: Hex; readonly metadataSnapshotHash: Hex;
}
export interface MetadataCitationGoldenVector {
  readonly request: MetadataCitationRenderRequest; readonly mode: 0n | 1n | 2n; readonly outputHash: Hex;
}
export interface MetadataCitationRead { readonly targetIndex: bigint; readonly selector: Hex; readonly maxReturnBytes: bigint; readonly exact: boolean }
export interface MetadataCitationTarget { readonly target: Address; readonly codeHash: Hex; readonly role: Hex }
export interface MetadataCitationVersion {
  readonly exists: boolean; readonly deprecated: boolean; readonly renderer: Address; readonly runtimeHash: Hex;
  readonly registrationHash: Hex; readonly readSetHash: Hex; readonly analysisHash: Hex; readonly goldenHash: Hex; readonly actionId: Hex;
}
export interface MetadataCitationRecord {
  readonly registration: MetadataCitationRegistration; readonly registrationHash: Hex; readonly readSetHash: Hex;
  readonly analysisHash: Hex; readonly goldenHash: Hex; readonly actionId: Hex;
}
export interface MetadataCitationCoordinates {
  readonly chainId: bigint; readonly registry: Address; readonly schemaRegistry: Address;
  readonly schemaRegistryCodeHash: Hex; readonly governanceExecutor: Address;
}
/** Caller-supplied observations. Hash consistency does not verify runtime, catalogue or authority. */
export interface MetadataCitationSnapshot extends MetadataCitationCoordinates {
  readonly targets: readonly MetadataCitationTarget[]; readonly originalVersion: MetadataCitationVersion;
  readonly originalReads: readonly MetadataCitationRead[]; readonly currentRecord: MetadataCitationRecord;
}
export interface MetadataCitationTransition { readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex }
export type MetadataCitationGovernanceCall = MintPolicyGraceGovernanceCall;
export type MetadataCitationGovernanceWindow = MintPolicyGraceGovernanceWindow;
export interface MetadataCitationPlan {
  readonly snapshot: MetadataCitationSnapshot; readonly registration: MetadataCitationRegistration; readonly reads: readonly MetadataCitationRead[];
  readonly registrationHash: Hex; readonly readSetHash: Hex; readonly transition: MetadataCitationTransition;
  readonly targetCall: UnsignedCall; readonly governanceCall: MetadataCitationGovernanceCall;
  readonly actionClass: 1n; readonly factsVerified: false;
}
export interface MetadataCitationEvidence {
  readonly analysis: MetadataCitationAnalysis; readonly goldens: readonly MetadataCitationGoldenVector[];
  readonly analysisBytes: Hex; readonly goldenBytes: Hex; readonly analysisHash: Hex; readonly goldenHash: Hex; readonly factsVerified: false;
}
export interface MetadataCitationGovernanceBatch {
  readonly plan: MetadataCitationPlan; readonly nonce: bigint; readonly window: MetadataCitationGovernanceWindow;
  readonly callsHash: Hex; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex;
  readonly actionId: Hex; readonly publicationKey: Hex; readonly publicationCall: UnsignedCall;
  readonly scheduleCall: UnsignedCall; readonly executionCall: UnsignedCall;
}

export const METADATA_CITATION_PROFILE = id("6529STREAM_CURRENT_BASE_CITATION_V1") as Hex;
export const METADATA_CITATION_ANALYSIS_PROFILE = id("6529STREAM_CURRENT_BASE_CITATION_ANALYSIS_ABI_V1") as Hex;
export const METADATA_CITATION_REGISTRATION_TUPLE = "tuple(bytes32 versionKey,bytes32 profile,bytes4 selector,address encoding,bytes32 encodingRuntimeHash,bytes32 analysisDocument,bytes32 goldenDocument)";
export const METADATA_CITATION_ANALYSIS_TUPLE = "tuple(bytes32 analysisProfile,bytes32 outputProfile,bytes4 selector,address renderer,bytes32 runtimeHash,address encoding,bytes32 encodingRuntimeHash,bytes32 readSetHash,bytes32 originalRegistrationHash,bytes32 toolHash,bytes32 findingsHash,bool passed)";
export const METADATA_CITATION_RENDER_REQUEST_TUPLE = "tuple(address core,uint256 tokenId,uint256 collectionId,uint256 collectionSerial,bytes32 tokenHash,uint8 state,uint8 mode,uint8 collectionSupplyMode,uint8 collectionStatus,bytes32 viewId,bytes32 viewManifestHash,bytes32 metadataSnapshotHash)";
export const METADATA_CITATION_GOLDEN_VECTOR_TUPLE = `tuple(${METADATA_CITATION_RENDER_REQUEST_TUPLE} request,uint8 mode,bytes32 outputHash)`;
export const METADATA_CITATION_READ_TUPLE = "tuple(uint16 targetIndex,bytes4 selector,uint32 maxReturnBytes,bool exact)";
export const METADATA_CITATION_TARGET_TUPLE = "tuple(address target,bytes32 codeHash,bytes32 role)";
export const METADATA_CITATION_VERSION_TUPLE = "tuple(bool exists,bool deprecated,address renderer,bytes32 runtimeHash,bytes32 registrationHash,bytes32 readSetHash,bytes32 analysisHash,bytes32 goldenHash,bytes32 actionId)";
export const METADATA_CITATION_RECORD_TUPLE = `tuple(${METADATA_CITATION_REGISTRATION_TUPLE} registration,bytes32 registrationHash,bytes32 readSetHash,bytes32 analysisHash,bytes32 goldenHash,bytes32 actionId)`;
export const METADATA_CITATION_GOVERNANCE_CALL_TUPLE = "tuple(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
export const CURRENT_METADATA_CITATION_ABI: readonly string[] = Object.freeze([
  `function registerCurrentCitation(${METADATA_CITATION_REGISTRATION_TUPLE} registration,${METADATA_CITATION_READ_TUPLE}[] reads)`,
  `function currentCitationTransition(${METADATA_CITATION_REGISTRATION_TUPLE} registration,${METADATA_CITATION_READ_TUPLE}[] reads) view returns(bytes32 scope,bytes32 previous,bytes32 next)`,
  `function currentCitationRecord(bytes32 versionKey) view returns(${METADATA_CITATION_RECORD_TUPLE})`,
  `function currentCitationReads(bytes32 versionKey) view returns(${METADATA_CITATION_READ_TUPLE}[])`,
  "function requireCurrentCitation(bytes32 versionKey) view returns(address renderer,bytes32 runtimeHash,bytes32 profile,bytes4 selector)",
  `event CurrentCitationRegistered(uint16 schemaVersion,bytes32 indexed versionKey,address indexed renderer,bytes32 indexed actionId,bytes32 registrationHash,${METADATA_CITATION_REGISTRATION_TUPLE} registration,${METADATA_CITATION_READ_TUPLE}[] reads)`,
]);
export const CURRENT_METADATA_CITATION_RENDERER_ABI: readonly string[] = Object.freeze([
  "function currentCitationProfile() pure returns(bytes32)",
  `function renderCurrent(${METADATA_CITATION_RENDER_REQUEST_TUPLE} request,uint8 mode) view returns(string)`,
  "function encodingBinding() view returns(address encoding,bytes32 runtimeHash)",
]);
export const CURRENT_METADATA_CITATION_GOVERNANCE_ABI: readonly string[] = Object.freeze([
  "function publishGovernanceCallData(bytes[] callDatas) returns(address)",
  `function scheduleGovernanceBatch(uint8 actionClass,${METADATA_CITATION_GOVERNANCE_CALL_TUPLE}[] calls,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint64 notBefore,uint64 expiresAfter,bytes32 reasonHash,string reasonURI,bytes32 manifestHash) returns(bytes32)`,
  `function executeGovernanceBatch(bytes32 actionId,${METADATA_CITATION_GOVERNANCE_CALL_TUPLE}[] calls,bytes[] callDatas) payable`,
]);
const abi = new Interface(CURRENT_METADATA_CITATION_ABI), rendererAbi = new Interface(CURRENT_METADATA_CITATION_RENDERER_ABI),
  governanceAbi = new Interface(CURRENT_METADATA_CITATION_GOVERNANCE_ABI), coder = AbiCoder.defaultAbiCoder();
export const METADATA_CITATION_RENDER_SELECTOR = rendererAbi.getFunction("renderCurrent")!.selector as Hex;
/** Solidity library selector uses its original qualified struct names, not the contract tuple signature. */
export const METADATA_CITATION_ENCODING_SELECTOR = id("renderCurrent(IStreamRenderer.RenderRequest,StreamStaticRenderEncoding.Prepared,string,address,uint8)").slice(0, 10) as Hex;
function interfaceId(intf: Interface): Hex {
  let result = 0n; intf.forEachFunction(f => { result ^= BigInt(f.selector); }); return `0x${result.toString(16).padStart(8, "0")}`;
}
export const METADATA_CITATION_REGISTRY_INTERFACE_ID = interfaceId(abi);
export const METADATA_CITATION_RENDERER_INTERFACE_ID = interfaceId(rendererAbi);
const coordinateKeys = ["chainId", "registry", "schemaRegistry", "schemaRegistryCodeHash", "governanceExecutor"];
const roles = new Set(["CORE", "COLLECTION_METADATA", "METADATA_COMPANION", "DEPENDENCY_REGISTRY", "ENTROPY_COORDINATOR", "STATIC_C2PA_ATTRIBUTION", "C2PA_RECONCILIATION", "ARTIST_REGISTRY", "ARTIST_STATIC_DISPLAY", "ARTIST_COORDINATOR", "ARTIST_IDENTITY_OWNER", "ARTIST_BINDING_OWNER", "ARTIST_ATTRIBUTION_OWNER", "ARTIST_COLLABORATOR_RECORDS_OWNER", "ARTIST_ACCEPTANCE_OWNER", "ARTIST_SANCTION_OWNER"].map(id));
function exact(value: unknown, keys: readonly string[], label: string): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error(`${label} must be an object`);
  const actual = Reflect.ownKeys(value);
  if (actual.length !== keys.length || actual.some(k => typeof k !== "string" || !keys.includes(k))) throw Error(`${label} has missing or unknown fields`);
}
function uint(value: unknown, bits: number, label: string): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`${label} must be uint${bits} bigint`); return value;
}
function bytes(value: unknown, size?: number): Hex {
  if (typeof value !== "string" || !isHexString(value, size) || value.length % 2 !== 0) throw Error(`Expected ${size === undefined ? "bytes" : `bytes${size}`}`); return value.toLowerCase() as Hex;
}
function address(value: unknown, allowZero = true): Address {
  if (typeof value !== "string") throw Error("Expected address"); const result = getAddress(value) as Address;
  if (!allowZero && result === ZeroAddress) throw Error("Expected nonzero address"); return result;
}
function nonzero(value: Hex): Hex { if (BigInt(value) === 0n) throw Error("Expected nonzero commitment"); return value; }
function list<T>(value: readonly T[], maximum: number, label: string): readonly T[] {
  if (!Array.isArray(value) || value.length > maximum || Reflect.ownKeys(value).length !== value.length + 1 ||
    Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) throw Error(`${label} must be a dense bounded array`); return value;
}
function normalized(p: ParamType, input: unknown, decoded = false): unknown {
  if (p.baseType === "tuple") {
    const fields = p.components!; if (!decoded) exact(input, fields.map(f => f.name), "Tuple");
    return Object.freeze(Object.fromEntries(fields.map((f, i) => [f.name, normalized(f, decoded ? (input as readonly unknown[])[i] : (input as Record<string, unknown>)[f.name], decoded)])));
  }
  if (p.baseType === "array") return Object.freeze(list(input as readonly unknown[], 128, "Tuple array").map(v => normalized(p.arrayChildren!, v, decoded)));
  if (p.type === "address") return address(input);
  if (p.type === "bool") { if (typeof input !== "boolean") throw Error("Expected bool"); return input; }
  if (p.type.startsWith("uint")) return uint(input, Number(p.type.slice(4)), p.name);
  if (p.type.startsWith("bytes")) return bytes(input, Number(p.type.slice(5)));
  throw Error("Unsupported original tuple type");
}
function tuple<T>(type: string, input: T): T { return normalized(ParamType.from(type), input) as T; }
function encode(type: string, value: unknown): Hex { return coder.encode([type], [value]) as Hex; }
function decode<T>(type: string, input: Hex, maximum = 8192): T {
  const raw = bytes(input); if ((raw.length - 2) / 2 > maximum) throw Error("Canonical document exceeds byte limit");
  const value = normalized(ParamType.from(type), coder.decode([type], raw)[0], true) as T;
  if (encode(type, value) !== raw) throw Error("Noncanonical ABI encoding"); return value;
}
function digest(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(coder.encode(types, values)) as Hex; }
function sameTree(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (!a || !b || typeof a !== "object" || typeof b !== "object" || Array.isArray(a) !== Array.isArray(b)) return false;
  const keys = Reflect.ownKeys(a), other = Reflect.ownKeys(b);
  return keys.length === other.length && keys.every(k => other.includes(k) && sameTree(Reflect.get(a, k), Reflect.get(b, k)));
}
function call(to: Address, method: string, args: readonly unknown[], intf = abi): UnsignedCall {
  return Object.freeze({ to: address(to, false), data: intf.encodeFunctionData(method, args) as Hex, value: 0n });
}

/** Display codec only. The Solidity helper permits zero chain, Core and token values. */
export function metadataWorkCitation(originalChainId: bigint, originalCore: Address, globalTokenId: bigint): string {
  return `eip155:${uint(originalChainId, 256, "originalChainId")}/erc721:${address(originalCore).toLowerCase()}/${uint(globalTokenId, 256, "globalTokenId")}`;
}
export function normalizeMetadataCitationRegistration(input: MetadataCitationRegistration): MetadataCitationRegistration { return tuple(METADATA_CITATION_REGISTRATION_TUPLE, input); }
export function normalizeMetadataCitationAnalysis(input: MetadataCitationAnalysis): MetadataCitationAnalysis { return tuple(METADATA_CITATION_ANALYSIS_TUPLE, input); }
export function normalizeMetadataCitationVersion(input: MetadataCitationVersion): MetadataCitationVersion { return tuple(METADATA_CITATION_VERSION_TUPLE, input); }
export function normalizeMetadataCitationRecord(input: MetadataCitationRecord): MetadataCitationRecord { return tuple(METADATA_CITATION_RECORD_TUPLE, input); }
export function normalizeMetadataCitationRenderRequest(input: MetadataCitationRenderRequest): MetadataCitationRenderRequest {
  const result = tuple(METADATA_CITATION_RENDER_REQUEST_TUPLE, input);
  if (result.state > 3n || result.mode > 2n) throw Error("RenderRequest exceeds original Solidity enum"); return result;
}
export function normalizeMetadataCitationReads(input: readonly MetadataCitationRead[]): readonly MetadataCitationRead[] {
  let previous = -1n;
  return Object.freeze(list(input, 128, "Declared reads").map(v => {
    const r = tuple(METADATA_CITATION_READ_TUPLE, v), order = r.targetIndex << 32n | BigInt(r.selector);
    if (BigInt(r.selector) === 0n || order <= previous || r.maxReturnBytes === 0n || r.maxReturnBytes > 16777216n || (r.exact && r.maxReturnBytes % 32n !== 0n)) throw Error("Invalid original ordered read declaration");
    previous = order; return r;
  }));
}
export function normalizeMetadataCitationTargets(input: readonly MetadataCitationTarget[]): readonly MetadataCitationTarget[] {
  let previous = 0n;
  const result = list(input, 64, "Targets").map(v => {
    const t = tuple(METADATA_CITATION_TARGET_TUPLE, v);
    if (BigInt(t.target) <= previous || t.codeHash === ZeroHash || !roles.has(t.role)) throw Error("Invalid original ordered target declaration"); previous = BigInt(t.target); return t;
  });
  if (!result.length) throw Error("Target set cannot be empty"); return Object.freeze(result);
}
export function normalizeMetadataCitationGoldenVectors(input: readonly MetadataCitationGoldenVector[]): readonly MetadataCitationGoldenVector[] {
  let modes = 0n;
  const result = list(input, 16, "Current golden vectors").map(v => {
    exact(v, ["request", "mode", "outputHash"], "Current golden vector");
    const mode = uint(v.mode, 8, "Golden mode"); if (mode > 2n) throw Error("Current goldens cover JSON modes 0, 1, 2 only"); modes |= 1n << mode;
    return Object.freeze({ request: normalizeMetadataCitationRenderRequest(v.request), mode: mode as 0n | 1n | 2n, outputHash: nonzero(bytes(v.outputHash, 32)) });
  });
  if (result.length < 3 || modes !== 7n) throw Error("Current golden vectors must cover all three modes"); return Object.freeze(result);
}
export function encodeMetadataCitationAnalysis(input: MetadataCitationAnalysis): Hex { return encode(METADATA_CITATION_ANALYSIS_TUPLE, normalizeMetadataCitationAnalysis(input)); }
export function decodeMetadataCitationAnalysis(raw: Hex): MetadataCitationAnalysis { return normalizeMetadataCitationAnalysis(decode(METADATA_CITATION_ANALYSIS_TUPLE, raw)); }
export function encodeMetadataCitationGoldenVectors(input: readonly MetadataCitationGoldenVector[]): Hex {
  const raw = encode(`${METADATA_CITATION_GOLDEN_VECTOR_TUPLE}[]`, normalizeMetadataCitationGoldenVectors(input));
  if ((raw.length - 2) / 2 > 8192) throw Error("Golden document exceeds original 8192 bytes"); return raw;
}
export function decodeMetadataCitationGoldenVectors(raw: Hex): readonly MetadataCitationGoldenVector[] {
  return normalizeMetadataCitationGoldenVectors(decode(`${METADATA_CITATION_GOLDEN_VECTOR_TUPLE}[]`, raw));
}
export function encodeMetadataCitationRecord(input: MetadataCitationRecord): Hex { return encode(METADATA_CITATION_RECORD_TUPLE, normalizeMetadataCitationRecord(input)); }
export function decodeMetadataCitationRecord(raw: Hex): MetadataCitationRecord { return normalizeMetadataCitationRecord(decode(METADATA_CITATION_RECORD_TUPLE, raw)); }
export function normalizeMetadataCitationCoordinates(input: MetadataCitationCoordinates): MetadataCitationCoordinates {
  exact(input, coordinateKeys, "Citation coordinates");
  return Object.freeze({ chainId: uint(input.chainId, 256, "chainId"), registry: address(input.registry, false), schemaRegistry: address(input.schemaRegistry, false),
    schemaRegistryCodeHash: nonzero(bytes(input.schemaRegistryCodeHash, 32)), governanceExecutor: address(input.governanceExecutor, false) });
}
export function normalizeMetadataCitationSnapshot(input: MetadataCitationSnapshot): MetadataCitationSnapshot {
  exact(input, [...coordinateKeys, "targets", "originalVersion", "originalReads", "currentRecord"], "Citation snapshot");
  const coords = normalizeMetadataCitationCoordinates({ chainId: input.chainId, registry: input.registry, schemaRegistry: input.schemaRegistry,
    schemaRegistryCodeHash: input.schemaRegistryCodeHash, governanceExecutor: input.governanceExecutor });
  const targets = normalizeMetadataCitationTargets(input.targets), originalReads = normalizeMetadataCitationReads(input.originalReads);
  for (const r of originalReads) if (r.targetIndex >= BigInt(targets.length)) throw Error("Original read index outside target set");
  return Object.freeze({ ...coords, targets, originalVersion: normalizeMetadataCitationVersion(input.originalVersion), originalReads, currentRecord: normalizeMetadataCitationRecord(input.currentRecord) });
}
export function metadataCitationTargetSetHash(targets: readonly MetadataCitationTarget[]): Hex {
  return digest([`${METADATA_CITATION_TARGET_TUPLE}[]`], [normalizeMetadataCitationTargets(targets)]);
}
export function metadataCitationReadSetHash(targets: readonly MetadataCitationTarget[], reads: readonly MetadataCitationRead[]): Hex {
  const ts = normalizeMetadataCitationTargets(targets), rs = normalizeMetadataCitationReads(reads);
  for (const r of rs) if (r.targetIndex >= BigInt(ts.length)) throw Error("Read index outside target set");
  return digest(["bytes32", "bytes32", `${METADATA_CITATION_READ_TUPLE}[]`], [id("6529STREAM_RENDERER_READ_SET_V1"), metadataCitationTargetSetHash(ts), rs]);
}
/** Original getter preimage; unlike the write planner this permits already admitted/deprecated observations. */
export function metadataCitationDeclarationHash(snapshot: MetadataCitationSnapshot, registration: MetadataCitationRegistration, reads: readonly MetadataCitationRead[]): Hex {
  const s = normalizeMetadataCitationSnapshot(snapshot), r = normalizeMetadataCitationRegistration(registration), rs = normalizeMetadataCitationReads(reads);
  return digest(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "bytes32", METADATA_CITATION_REGISTRATION_TUPLE, `${METADATA_CITATION_READ_TUPLE}[]`],
    [id("6529STREAM_CURRENT_CITATION_REGISTRATION_V1"), s.chainId, s.registry, s.schemaRegistry, s.schemaRegistryCodeHash, metadataCitationTargetSetHash(s.targets), s.originalVersion.registrationHash, r, rs]);
}
export function metadataCitationScopeHash(chainId: bigint, registry: Address, versionKey: Hex): Hex {
  return digest(["bytes32", "uint256", "address", "bytes32"], [id("6529STREAM_CURRENT_CITATION_SCOPE_V1"), uint(chainId, 256, "chainId"), address(registry, false), bytes(versionKey, 32)]);
}
export function metadataCitationStateHash(registrationHash: Hex): Hex {
  return digest(["bytes32", "bytes32"], [id("6529STREAM_CURRENT_CITATION_STATE_V1"), bytes(registrationHash, 32)]);
}
export function metadataCitationTransition(snapshot: MetadataCitationSnapshot, registration: MetadataCitationRegistration, reads: readonly MetadataCitationRead[]): MetadataCitationTransition {
  const s = normalizeMetadataCitationSnapshot(snapshot), r = normalizeMetadataCitationRegistration(registration);
  return Object.freeze({ scopeHash: metadataCitationScopeHash(s.chainId, s.registry, r.versionKey), oldValueHash: metadataCitationStateHash(s.currentRecord.registrationHash),
    newValueHash: metadataCitationStateHash(metadataCitationDeclarationHash(s, r, reads)) });
}
function readJoins(s: MetadataCitationSnapshot, r: MetadataCitationRegistration, reads: readonly MetadataCitationRead[]): void {
  let oldIndex = 0, encoder = false;
  for (const item of reads) {
    const previous = s.originalReads[oldIndex];
    if (previous && item.targetIndex === previous.targetIndex && item.selector === previous.selector) {
      if (!sameTree(item, previous)) throw Error("Current declaration must preserve every original read exactly"); ++oldIndex;
    }
    const target = s.targets[Number(item.targetIndex)];
    if (target?.target === r.encoding && item.selector === METADATA_CITATION_ENCODING_SELECTOR) {
      if (target.codeHash !== r.encodingRuntimeHash || target.role !== id("METADATA_COMPANION") || item.exact || item.maxReturnBytes < 64n) throw Error("Invalid current encoder read"); encoder = true;
    }
  }
  if (oldIndex !== s.originalReads.length || !encoder) throw Error("Current declaration is missing original or encoder reads");
}
/** Finite supplied-fact checks only. Runtime, ACTIVE documents, golden execution and governance admission remain unverified. */
export function prepareMetadataCitationRegistration(snapshot: MetadataCitationSnapshot, registration: MetadataCitationRegistration, reads: readonly MetadataCitationRead[]): MetadataCitationPlan {
  const s = normalizeMetadataCitationSnapshot(snapshot), r = normalizeMetadataCitationRegistration(registration), rs = normalizeMetadataCitationReads(reads);
  if (!s.originalVersion.exists || s.originalVersion.deprecated || s.currentRecord.registrationHash !== ZeroHash) throw Error("Original version unavailable or current citation already admitted");
  address(s.originalVersion.renderer, false); nonzero(s.originalVersion.runtimeHash); nonzero(s.originalVersion.registrationHash);
  if (r.profile !== METADATA_CITATION_PROFILE || r.selector !== METADATA_CITATION_RENDER_SELECTOR) throw Error("Wrong current citation profile or renderer selector");
  address(r.encoding, false); nonzero(r.encodingRuntimeHash); nonzero(r.analysisDocument); nonzero(r.goldenDocument);
  const readSetHash = metadataCitationReadSetHash(s.targets, rs); readJoins(s, r, rs);
  if (metadataCitationReadSetHash(s.targets, s.originalReads) !== s.originalVersion.readSetHash) throw Error("Original reads differ from retained original read set hash");
  const registrationHash = metadataCitationDeclarationHash(s, r, rs), transition = metadataCitationTransition(s, r, rs), targetCall = call(s.registry, "registerCurrentCitation", [r, rs]);
  const governanceCall = Object.freeze({ target: targetCall.to, value: 0n, selector: targetCall.data.slice(0, 10) as Hex, callDataHash: keccak256(targetCall.data) as Hex, ...transition });
  return Object.freeze({ snapshot: s, registration: r, reads: rs, registrationHash, readSetHash, transition, targetCall, governanceCall, actionClass: 1n, factsVerified: false });
}
export function normalizeMetadataCitationPlan(input: MetadataCitationPlan): MetadataCitationPlan {
  exact(input, ["snapshot", "registration", "reads", "registrationHash", "readSetHash", "transition", "targetCall", "governanceCall", "actionClass", "factsVerified"], "Citation plan");
  const result = prepareMetadataCitationRegistration(input.snapshot, input.registration, input.reads);
  if (!sameTree(input, result)) throw Error("Citation plan differs from exact reconstruction"); return result;
}
/** Analysis remains an attributed assertion. Expected golden outputs are supplied, never generated from renderCurrent here. */
export function validateMetadataCitationEvidence(plan: MetadataCitationPlan, analysis: MetadataCitationAnalysis, goldens: readonly MetadataCitationGoldenVector[]): MetadataCitationEvidence {
  const p = normalizeMetadataCitationPlan(plan), a = normalizeMetadataCitationAnalysis(analysis), g = normalizeMetadataCitationGoldenVectors(goldens), r = p.registration, v = p.snapshot.originalVersion;
  if (a.analysisProfile !== METADATA_CITATION_ANALYSIS_PROFILE || a.outputProfile !== r.profile || a.selector !== r.selector || a.renderer !== v.renderer || a.runtimeHash !== v.runtimeHash ||
    a.encoding !== r.encoding || a.encodingRuntimeHash !== r.encodingRuntimeHash || a.readSetHash !== p.readSetHash || a.originalRegistrationHash !== v.registrationHash || a.toolHash === ZeroHash || a.findingsHash === ZeroHash || !a.passed) throw Error("Current analysis does not match exact declaration");
  const analysisBytes = encodeMetadataCitationAnalysis(a), goldenBytes = encodeMetadataCitationGoldenVectors(g);
  return Object.freeze({ analysis: a, goldens: g, analysisBytes, goldenBytes, analysisHash: keccak256(analysisBytes) as Hex, goldenHash: keccak256(goldenBytes) as Hex, factsVerified: false });
}
/** Mode 3 is the original current-render HTML entry; admission golden vectors intentionally cover only JSON modes 0..2. */
export function prepareMetadataCitationRenderCall(renderer: Address, request: MetadataCitationRenderRequest, mode: 0n | 1n | 2n | 3n): UnsignedCall {
  const m = uint(mode, 8, "Render mode"); if (m > 3n) throw Error("Current renderer supports modes 0..3");
  return call(renderer, "renderCurrent", [normalizeMetadataCitationRenderRequest(request), m], rendererAbi);
}
export function normalizeMetadataCitationGovernanceWindow(input: MetadataCitationGovernanceWindow): MetadataCitationGovernanceWindow { return normalizeMintPolicyGraceGovernanceWindow(input); }
/** Source timing checks at an explicit scheduling block timestamp: class1 48h, seven-day open window, 365-day lifetime. */
export function assertMetadataCitationGovernanceWindow(input: MetadataCitationGovernanceWindow, schedulingTimestamp: bigint): void {
  const w = normalizeMetadataCitationGovernanceWindow(input), at = uint(schedulingTimestamp, 256, "schedulingTimestamp");
  if (at > (1n << 64n) - 1n - 31536000n || w.notBefore < at + 172800n || w.expiresAfter > at + 31536000n) throw Error("Outside original class1 governance timing bounds");
}
export function metadataCitationGovernanceBatch(input: MetadataCitationPlan, nonce: bigint, window: MetadataCitationGovernanceWindow): MetadataCitationGovernanceBatch {
  const plan = normalizeMetadataCitationPlan(input), n = uint(nonce, 256, "Governance nonce"), w = normalizeMetadataCitationGovernanceWindow(window);
  const calls = [plan.governanceCall], data = [plan.targetCall.data], executor = plan.snapshot.governanceExecutor;
  const callsHash = digest(["bytes32", `${METADATA_CITATION_GOVERNANCE_CALL_TUPLE}[]`], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain: Hex, field: "scopeHash" | "oldValueHash" | "newValueHash") => digest(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, calls.map(c => c[field])]);
  const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash");
  const oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash");
  const newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
  const actionId = digest(["bytes32", "uint256", "address", "tuple(uint8,bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64,bytes32,bytes32)"],
    ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", plan.snapshot.chainId, executor,
      [1n, callsHash, scopeHash, oldValueHash, newValueHash, n, w.notBefore, w.expiresAfter, w.reasonHash, w.manifestHash]]);
  return Object.freeze({ plan, nonce: n, window: w, callsHash, scopeHash, oldValueHash, newValueHash, actionId, publicationKey: keccak256(plan.governanceCall.callDataHash) as Hex,
    publicationCall: call(executor, "publishGovernanceCallData", [data], governanceAbi),
    scheduleCall: call(executor, "scheduleGovernanceBatch", [1n, calls, scopeHash, oldValueHash, newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash], governanceAbi),
    executionCall: call(executor, "executeGovernanceBatch", [actionId, calls, data], governanceAbi) });
}
export function normalizeMetadataCitationGovernanceBatch(input: MetadataCitationGovernanceBatch): MetadataCitationGovernanceBatch {
  exact(input, ["plan", "nonce", "window", "callsHash", "scopeHash", "oldValueHash", "newValueHash", "actionId", "publicationKey", "publicationCall", "scheduleCall", "executionCall"], "Citation governance batch");
  const result = metadataCitationGovernanceBatch(input.plan, input.nonce, input.window);
  if (!sameTree(input, result)) throw Error("Citation governance batch differs from exact reconstruction"); return result;
}
