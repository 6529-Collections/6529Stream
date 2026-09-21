import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, hexlify, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type * as shared from "./current-scoped-policy-publication-v2.js";

/** ABI146 token preservation family. Values alone do not prove original Registry or current output admission. */
export const TOKEN_PRESERVATION_OUTPUT_V2_SOURCE = "9381dd999075693a4f63092d9924856a0dd72834";
export const TOKEN_PRESERVATION_OUTPUT_V2_FAMILY = id("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2") as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_ORIGINAL_PRODUCER = id("6529STREAM_PRESERVATION_RENDER_V1") as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_CURRENT_ARTIST_PRODUCER = id("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1") as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_COLLECTION_PROFILE = id("6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2") as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_SCOPED_PROFILE = id("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2") as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_PROFILE = id("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2") as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA = id("STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2") as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION = id("STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2") as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_LEAF_SCHEMA = id("STREAM_PRESERVATION_POLICY_TOKEN_CONTENT_LEAF_V1") as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_MAX_MANIFEST_BYTES = 524288;
export const TOKEN_PRESERVATION_OUTPUT_V2_MAX_OUTPUTS = 454;
export const TOKEN_PRESERVATION_OUTPUT_V2_MAX_RENDER_BYTES = 16777216;
export const TOKEN_PRESERVATION_OUTPUT_V2_MAX_CALL_BYTES = 67125248;
export const TOKEN_PRESERVATION_OUTPUT_V2_MAX_APPEND = 4;
export const TOKEN_PRESERVATION_OUTPUT_V2_MAX_VERIFY = 16;
/** Client allocation ceiling for full in-memory row/tree helpers; original Plan counts remain uint64. */
export const TOKEN_PRESERVATION_OUTPUT_V2_MAX_CHECKPOINT_TOKENS = 16384;
export type TokenPreservationOutputV2ScopeKind = "collection" | "scoped";
export interface TokenPreservationOutputV2Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly metadataRouter: Address;
  readonly checkpoint: Address;
  readonly output: Address;
  readonly scopeKind: TokenPreservationOutputV2ScopeKind;
}
export interface TokenPreservationOutputV2Scope {
  readonly scopeType: 0n | 1n | 2n | 3n | 4n;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly scopeId: Hex;
}
export interface TokenPreservationOutputV2SelectionPlan {
  readonly scope: TokenPreservationOutputV2Scope;
  readonly membershipHash: Hex;
  readonly collectionStateHash: Hex;
  readonly tokenCount: bigint;
  readonly nextIndex: bigint;
  readonly selectionRoot: Hex;
}
// These unchanged original structures are shared by the full-output and preservation consumers.
export type TokenPreservationOutputV2RendererSelection = shared.ScopedPolicyPublicationV2RendererSelection;
export type TokenPreservationOutputV2TokenSelection = shared.ScopedPolicyPublicationV2TokenSelection;
export type TokenPreservationOutputV2TokenReadiness = shared.ScopedPolicyPublicationV2TokenReadiness;
export type TokenPreservationOutputV2TerminalEvidence = shared.ScopedPolicyPublicationV2TerminalEvidence;
export type TokenPreservationOutputV2Leaf = shared.ScopedPolicyPublicationV2Leaf;
export type TokenPreservationOutputV2Coverage = shared.ScopedPolicyPublicationV2Coverage;
export interface TokenPreservationOutputV2ProducerBinding {
  readonly core: Address;
  readonly metadataRouter: Address;
  readonly liveRenderer: Address;
  readonly liveRendererCodeHash: Hex;
  readonly attribution: Address;
  readonly attributionCodeHash: Hex;
}
export interface TokenPreservationOutputV2Binding extends TokenPreservationOutputV2ProducerBinding {
  readonly producer: Address;
  readonly producerCodeHash: Hex;
  readonly profile: Hex;
}
/** The Registry's original field is `router`; output Binding uses `metadataRouter`. */
export interface TokenPreservationOutputV2RegistryBinding {
  readonly producer: Address;
  readonly producerCodeHash: Hex;
  readonly profile: Hex;
  readonly core: Address;
  readonly router: Address;
  readonly liveRenderer: Address;
  readonly liveRendererCodeHash: Hex;
  readonly attribution: Address;
  readonly attributionCodeHash: Hex;
}
export interface TokenPreservationOutputV2Admission {
  readonly registry: Address;
  readonly registryCodeHash: Hex;
  readonly versionKey: Hex;
  readonly registrationHash: Hex;
  readonly readSetHash: Hex;
  readonly analysisHash: Hex;
  readonly goldenHash: Hex;
}
export interface TokenPreservationOutputV2RegistryRegistration {
  readonly versionKey: Hex;
  readonly binding: TokenPreservationOutputV2RegistryBinding;
  readonly schemaDocument: Hex;
  readonly analysisDocument: Hex;
  readonly goldenDocument: Hex;
}
export interface TokenPreservationOutputV2RegistryRecord {
  readonly registration: TokenPreservationOutputV2RegistryRegistration;
  readonly registrationHash: Hex;
  readonly readSetHash: Hex;
  readonly analysisHash: Hex;
  readonly goldenHash: Hex;
  readonly actionId: Hex;
}
export interface TokenPreservationOutputV2RegistryAnalysis {
  readonly analysisProfile: Hex;
  readonly binding: TokenPreservationOutputV2RegistryBinding;
  readonly originalRegistrationHash: Hex;
  readonly schemaHash: Hex;
  readonly readSetHash: Hex;
  readonly toolHash: Hex;
  readonly findingsHash: Hex;
  readonly passed: boolean;
}
export interface TokenPreservationOutputV2RegistryRead {
  readonly targetIndex: bigint;
  readonly selector: Hex;
  readonly maxReturnBytes: bigint;
  readonly exact: boolean;
}
export interface TokenPreservationOutputV2ContentPlan {
  readonly selectionId: Hex;
  readonly selectionHash: Hex;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly scope: TokenPreservationOutputV2Scope;
  readonly tokenCount: bigint;
  readonly nextIndex: bigint;
  readonly leafChainHash: Hex;
  readonly contentRoot: Hex;
  readonly outputRoot: Hex;
  readonly preservationProfile: Hex;
}
export interface TokenPreservationOutputV2Payload {
  readonly tokenId: bigint;
  readonly producer: Address;
  readonly image: Hex;
  readonly animation: Hex;
}
export interface TokenPreservationOutputV2Output {
  readonly leaf: TokenPreservationOutputV2Leaf;
  readonly selectionRowHash: Hex;
  readonly sourceFactsHash: Hex;
  readonly htmlHash: Hex;
  readonly entropy: TokenPreservationOutputV2TokenReadiness;
  readonly terminalAdmissionHash: Hex;
  readonly preservation: TokenPreservationOutputV2Binding;
  readonly preservationAdmission: TokenPreservationOutputV2Admission;
}
export interface TokenPreservationOutputV2Manifest {
  readonly checkpointHash: Hex;
  readonly checkpointStateHash: Hex;
  readonly entropySourceSet: Address;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly metadataRouter: Address;
  readonly preservationProfile: Hex;
  readonly artifactHash: Hex;
  readonly coverageHash: Hex;
  readonly artistId: Hex;
  readonly contentRoot: Hex;
  readonly outputRoot: Hex;
  readonly manifestHash: Hex;
  readonly scope: TokenPreservationOutputV2Scope;
  readonly tokenCount: bigint;
  readonly byteLength: bigint;
}
export interface TokenPreservationOutputV2OutputPlan {
  readonly manifest: TokenPreservationOutputV2Manifest;
  readonly nextIndex: bigint;
  readonly recordHash: Hex;
}

export const TOKEN_PRESERVATION_OUTPUT_V2_SCOPE_TUPLE = "tuple(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId)";
export const TOKEN_PRESERVATION_OUTPUT_V2_SELECTION_PLAN_TUPLE = `tuple(${TOKEN_PRESERVATION_OUTPUT_V2_SCOPE_TUPLE} scope,bytes32 membershipHash,bytes32 collectionStateHash,uint64 tokenCount,uint64 nextIndex,bytes32 selectionRoot)`;
export const TOKEN_PRESERVATION_OUTPUT_V2_RENDERER_SELECTION_TUPLE = "tuple(address registry,bytes32 registryCodeHash,bytes32 versionKey,address renderer,bytes32 rendererCodeHash,bytes32 rendererId,bytes32 rendererVersion,bytes32 contextVersion,bytes32 schemaHash,bytes32 readSetHash,bytes32 registrationHash)";
export const TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_SELECTION_TUPLE = `tuple(uint256 tokenId,bytes32 configRecordHash,bytes32 configHash,bytes32 sourceSnapshotHash,bytes32 rawSourceHash,${TOKEN_PRESERVATION_OUTPUT_V2_RENDERER_SELECTION_TUPLE} selection,address[6] sources,bytes32[6] sourceCodeHashes)`;
export const TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_READINESS_TUPLE = "tuple(address coordinator,bytes32 coordinatorCodeHash,bytes32 policyHash,uint8 status,uint8 mode,uint8 securityClass,uint8 renderRequirement,bool terminal,bool finalized,bytes32 seed)";
export const TOKEN_PRESERVATION_OUTPUT_V2_TERMINAL_EVIDENCE_TUPLE = `tuple(${TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_READINESS_TUPLE} entropy,bytes32 configRecordHash,bytes32 versionKey,address renderer,bytes32 rendererCodeHash,address registry,bytes32 registryCodeHash,bytes32 admissionHash,bytes32 policyChainHash,bytes32 evidenceHash)`;
export const TOKEN_PRESERVATION_OUTPUT_V2_LEAF_TUPLE = "tuple(uint256 tokenId,bytes32 metadataHash,bytes32 imageHash,bytes32 animationHash,bytes32 contentHash,bytes32 tokenDataHash)";
export const TOKEN_PRESERVATION_OUTPUT_V2_PRODUCER_BINDING_TUPLE = "tuple(address core,address metadataRouter,address liveRenderer,bytes32 liveRendererCodeHash,address attribution,bytes32 attributionCodeHash)";
export const TOKEN_PRESERVATION_OUTPUT_V2_BINDING_TUPLE = "tuple(address producer,bytes32 producerCodeHash,bytes32 profile,address core,address metadataRouter,address liveRenderer,bytes32 liveRendererCodeHash,address attribution,bytes32 attributionCodeHash)";
export const TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_BINDING_TUPLE = "tuple(address producer,bytes32 producerCodeHash,bytes32 profile,address core,address router,address liveRenderer,bytes32 liveRendererCodeHash,address attribution,bytes32 attributionCodeHash)";
export const TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE = "tuple(address registry,bytes32 registryCodeHash,bytes32 versionKey,bytes32 registrationHash,bytes32 readSetHash,bytes32 analysisHash,bytes32 goldenHash)";
export const TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_REGISTRATION_TUPLE = `tuple(bytes32 versionKey,${TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_BINDING_TUPLE} binding,bytes32 schemaDocument,bytes32 analysisDocument,bytes32 goldenDocument)`;
export const TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_RECORD_TUPLE = `tuple(${TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_REGISTRATION_TUPLE} registration,bytes32 registrationHash,bytes32 readSetHash,bytes32 analysisHash,bytes32 goldenHash,bytes32 actionId)`;
export const TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_ANALYSIS_TUPLE = `tuple(bytes32 analysisProfile,${TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_BINDING_TUPLE} binding,bytes32 originalRegistrationHash,bytes32 schemaHash,bytes32 readSetHash,bytes32 toolHash,bytes32 findingsHash,bool passed)`;
export const TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_READ_TUPLE = "tuple(uint16 targetIndex,bytes4 selector,uint32 maxReturnBytes,bool exact)";
export const TOKEN_PRESERVATION_OUTPUT_V2_CONTENT_PLAN_TUPLE = `tuple(bytes32 selectionId,bytes32 selectionHash,bytes32 inventoryHash,bytes32 policyChainHash,${TOKEN_PRESERVATION_OUTPUT_V2_SCOPE_TUPLE} scope,uint64 tokenCount,uint64 nextIndex,bytes32 leafChainHash,bytes32 contentRoot,bytes32 outputRoot,bytes32 preservationProfile)`;
export const TOKEN_PRESERVATION_OUTPUT_V2_PAYLOAD_TUPLE = "tuple(uint256 tokenId,address producer,bytes image,bytes animation)";
export const TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_TUPLE = `tuple(${TOKEN_PRESERVATION_OUTPUT_V2_LEAF_TUPLE} leaf,bytes32 selectionRowHash,bytes32 sourceFactsHash,bytes32 htmlHash,${TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_READINESS_TUPLE} entropy,bytes32 terminalAdmissionHash,${TOKEN_PRESERVATION_OUTPUT_V2_BINDING_TUPLE} preservation,${TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE} preservationAdmission)`;
export const TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE = `tuple(bytes32 checkpointHash,bytes32 checkpointStateHash,address entropySourceSet,bytes32 inventoryHash,bytes32 policyChainHash,address metadataRouter,bytes32 preservationProfile,bytes32 artifactHash,bytes32 coverageHash,bytes32 artistId,bytes32 contentRoot,bytes32 outputRoot,bytes32 manifestHash,${TOKEN_PRESERVATION_OUTPUT_V2_SCOPE_TUPLE} scope,uint64 tokenCount,uint64 byteLength)`;
export const TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_PLAN_TUPLE = `tuple(${TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE} manifest,uint64 nextIndex,bytes32 recordHash)`;
export const TOKEN_PRESERVATION_OUTPUT_V2_COVERAGE_TUPLE = "tuple(bytes32 completionHash,bytes32 artifactHash,bytes32 artistId,bytes32 schemaId,bytes32 canonicalizationId,bytes32 contentHash,uint64 byteLength,uint32 chunkCount,bytes32 firstFamilyRecordHash,bytes32 secondFamilyRecordHash,uint64 validationEpoch,bytes32 evidenceChainHash)";

const coder = AbiCoder.defaultAbiCoder();
const Z = ZeroHash as Hex;
function exact(value: unknown, keys: readonly string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || Reflect.ownKeys(value).length !== keys.length
    || keys.some(k => !Object.prototype.hasOwnProperty.call(value, k))) throw Error("Invalid exact shape");
}
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Invalid uint${bits}`);
  return value;
}
function address(value: unknown, required = false): Address {
  if (typeof value !== "string" || !isHexString(value, 20)) throw Error("Invalid address");
  const result = getAddress(value) as Address;
  if (required && result === ZeroAddress) throw Error("Zero address");
  return result;
}
function bytes(value: unknown, length?: number, maximum = TOKEN_PRESERVATION_OUTPUT_V2_MAX_CALL_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, length ?? true) || (value.length - 2) / 2 > maximum) throw Error("Invalid bytes or allocation bound");
  return value.toLowerCase() as Hex;
}
function nonzero(value: unknown): Hex {
  const r = bytes(value, 32);
  if (r === Z) throw Error("Zero commitment");
  return r;
}
function list(value: unknown, maximum: number, size?: number): readonly unknown[] {
  if (!Array.isArray(value) || value.length > maximum || (size !== undefined && value.length !== size)
    || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.prototype.hasOwnProperty.call(value, i))) throw Error("Invalid dense array");
  return value;
}
function valueOf(t: ParamType, v: unknown, decoded = false): unknown {
  if (t.baseType === "array") {
    const size = t.arrayLength === -1 ? undefined : t.arrayLength!;
    return Object.freeze(list(v, size ?? TOKEN_PRESERVATION_OUTPUT_V2_MAX_CHECKPOINT_TOKENS, size).map(x => valueOf(t.arrayChildren!, x, decoded)));
  }
  if (t.baseType === "tuple") {
    if (!decoded) exact(v, t.components!.map(c => c.name));
    const result = Object.fromEntries(t.components!.map((c, i) => [c.name, valueOf(c, decoded ? (v as readonly unknown[])[i] : (v as Record<string, unknown>)[c.name], decoded)]));
    if (t.components!.some(c => c.name === "scopeType") && (result.scopeType as bigint) > 4n) throw Error("Invalid original scope enum");
    return Object.freeze(result);
  }
  if (t.type.startsWith("uint")) return uint(v, Number(t.type.slice(4)));
  if (t.type === "address") return address(v);
  if (t.type === "bool") {
    if (typeof v !== "boolean") throw Error("Invalid bool");
    return v;
  }
  if (t.type === "bytes") return bytes(v);
  if (t.type.startsWith("bytes")) return bytes(v, Number(t.type.slice(5)));
  throw Error("Unsupported original ABI type");
}
function normalize<T>(tuple: string, value: unknown, decoded = false): T {
  return valueOf(ParamType.from(tuple), value, decoded) as T;
}
function encode(tuple: string, value: unknown): Hex {
  return bytes(coder.encode([tuple], [normalize(tuple, value)]));
}
function decode<T>(tuple: string, value: Hex): T {
  const raw = bytes(value);
  const result = normalize<T>(tuple, coder.decode([tuple], raw)[0], true);
  if (encode(tuple, result) !== raw) throw Error("Noncanonical original ABI");
  return result;
}
function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}
function same(a: unknown, b: unknown, label: string): void {
  const text = (v: unknown) => JSON.stringify(v, (_, x: unknown) => typeof x === "bigint" ? `${x}n` : x);
  if (text(a) !== text(b)) throw Error(label + " differs");
}
function pin(a: Address, h: Hex): void {
  address(a, true);
  nonzero(h);
}

export function normalizeTokenPreservationOutputV2Coordinates(value: TokenPreservationOutputV2Coordinates): TokenPreservationOutputV2Coordinates {
  exact(value, ["chainId", "core", "metadataRouter", "checkpoint", "output", "scopeKind"]);
  if (value.scopeKind !== "collection" && value.scopeKind !== "scoped") throw Error("Unknown V2 scope profile");
  if (!uint(value.chainId)) throw Error("Zero chain");
  return Object.freeze({ chainId: value.chainId, core: address(value.core, true), metadataRouter: address(value.metadataRouter, true),
    checkpoint: address(value.checkpoint, true), output: address(value.output, true), scopeKind: value.scopeKind });
}
export function tokenPreservationOutputV2CheckpointProfile(kind: TokenPreservationOutputV2ScopeKind): Hex {
  if (kind === "collection") return TOKEN_PRESERVATION_OUTPUT_V2_COLLECTION_PROFILE;
  if (kind === "scoped") return TOKEN_PRESERVATION_OUTPUT_V2_SCOPED_PROFILE;
  throw Error("Unknown V2 scope profile");
}

export function normalizeTokenPreservationOutputV2Scope(value: TokenPreservationOutputV2Scope): TokenPreservationOutputV2Scope {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_SCOPE_TUPLE, value);
}
export function encodeTokenPreservationOutputV2Scope(value: TokenPreservationOutputV2Scope): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_SCOPE_TUPLE, value);
}
export function decodeTokenPreservationOutputV2Scope(value: Hex): TokenPreservationOutputV2Scope {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_SCOPE_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2SelectionPlan(value: TokenPreservationOutputV2SelectionPlan): TokenPreservationOutputV2SelectionPlan {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_SELECTION_PLAN_TUPLE, value);
}
export function encodeTokenPreservationOutputV2SelectionPlan(value: TokenPreservationOutputV2SelectionPlan): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_SELECTION_PLAN_TUPLE, value);
}
export function decodeTokenPreservationOutputV2SelectionPlan(value: Hex): TokenPreservationOutputV2SelectionPlan {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_SELECTION_PLAN_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2RendererSelection(value: TokenPreservationOutputV2RendererSelection): TokenPreservationOutputV2RendererSelection {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_RENDERER_SELECTION_TUPLE, value);
}
export function encodeTokenPreservationOutputV2RendererSelection(value: TokenPreservationOutputV2RendererSelection): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_RENDERER_SELECTION_TUPLE, value);
}
export function decodeTokenPreservationOutputV2RendererSelection(value: Hex): TokenPreservationOutputV2RendererSelection {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_RENDERER_SELECTION_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2TokenSelection(value: TokenPreservationOutputV2TokenSelection): TokenPreservationOutputV2TokenSelection {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_SELECTION_TUPLE, value);
}
export function encodeTokenPreservationOutputV2TokenSelection(value: TokenPreservationOutputV2TokenSelection): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_SELECTION_TUPLE, value);
}
export function decodeTokenPreservationOutputV2TokenSelection(value: Hex): TokenPreservationOutputV2TokenSelection {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_SELECTION_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2TokenReadiness(value: TokenPreservationOutputV2TokenReadiness): TokenPreservationOutputV2TokenReadiness {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_READINESS_TUPLE, value);
}
export function encodeTokenPreservationOutputV2TokenReadiness(value: TokenPreservationOutputV2TokenReadiness): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_READINESS_TUPLE, value);
}
export function decodeTokenPreservationOutputV2TokenReadiness(value: Hex): TokenPreservationOutputV2TokenReadiness {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_READINESS_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2TerminalEvidence(value: TokenPreservationOutputV2TerminalEvidence): TokenPreservationOutputV2TerminalEvidence {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_TERMINAL_EVIDENCE_TUPLE, value);
}
export function encodeTokenPreservationOutputV2TerminalEvidence(value: TokenPreservationOutputV2TerminalEvidence): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_TERMINAL_EVIDENCE_TUPLE, value);
}
export function decodeTokenPreservationOutputV2TerminalEvidence(value: Hex): TokenPreservationOutputV2TerminalEvidence {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_TERMINAL_EVIDENCE_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2Leaf(value: TokenPreservationOutputV2Leaf): TokenPreservationOutputV2Leaf {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_LEAF_TUPLE, value);
}
export function encodeTokenPreservationOutputV2Leaf(value: TokenPreservationOutputV2Leaf): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_LEAF_TUPLE, value);
}
export function decodeTokenPreservationOutputV2Leaf(value: Hex): TokenPreservationOutputV2Leaf {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_LEAF_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2ProducerBinding(value: TokenPreservationOutputV2ProducerBinding): TokenPreservationOutputV2ProducerBinding {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_PRODUCER_BINDING_TUPLE, value);
}
export function encodeTokenPreservationOutputV2ProducerBinding(value: TokenPreservationOutputV2ProducerBinding): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_PRODUCER_BINDING_TUPLE, value);
}
export function decodeTokenPreservationOutputV2ProducerBinding(value: Hex): TokenPreservationOutputV2ProducerBinding {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_PRODUCER_BINDING_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2Binding(value: TokenPreservationOutputV2Binding): TokenPreservationOutputV2Binding {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_BINDING_TUPLE, value);
}
export function encodeTokenPreservationOutputV2Binding(value: TokenPreservationOutputV2Binding): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_BINDING_TUPLE, value);
}
export function decodeTokenPreservationOutputV2Binding(value: Hex): TokenPreservationOutputV2Binding {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_BINDING_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2RegistryBinding(value: TokenPreservationOutputV2RegistryBinding): TokenPreservationOutputV2RegistryBinding {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_BINDING_TUPLE, value);
}
export function encodeTokenPreservationOutputV2RegistryBinding(value: TokenPreservationOutputV2RegistryBinding): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_BINDING_TUPLE, value);
}
export function decodeTokenPreservationOutputV2RegistryBinding(value: Hex): TokenPreservationOutputV2RegistryBinding {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_BINDING_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2Admission(value: TokenPreservationOutputV2Admission): TokenPreservationOutputV2Admission {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE, value);
}
export function encodeTokenPreservationOutputV2Admission(value: TokenPreservationOutputV2Admission): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE, value);
}
export function decodeTokenPreservationOutputV2Admission(value: Hex): TokenPreservationOutputV2Admission {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2RegistryRegistration(value: TokenPreservationOutputV2RegistryRegistration): TokenPreservationOutputV2RegistryRegistration {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_REGISTRATION_TUPLE, value);
}
export function encodeTokenPreservationOutputV2RegistryRegistration(value: TokenPreservationOutputV2RegistryRegistration): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_REGISTRATION_TUPLE, value);
}
export function decodeTokenPreservationOutputV2RegistryRegistration(value: Hex): TokenPreservationOutputV2RegistryRegistration {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_REGISTRATION_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2RegistryRecord(value: TokenPreservationOutputV2RegistryRecord): TokenPreservationOutputV2RegistryRecord {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_RECORD_TUPLE, value);
}
export function encodeTokenPreservationOutputV2RegistryRecord(value: TokenPreservationOutputV2RegistryRecord): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_RECORD_TUPLE, value);
}
export function decodeTokenPreservationOutputV2RegistryRecord(value: Hex): TokenPreservationOutputV2RegistryRecord {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_RECORD_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2RegistryAnalysis(value: TokenPreservationOutputV2RegistryAnalysis): TokenPreservationOutputV2RegistryAnalysis {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_ANALYSIS_TUPLE, value);
}
export function encodeTokenPreservationOutputV2RegistryAnalysis(value: TokenPreservationOutputV2RegistryAnalysis): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_ANALYSIS_TUPLE, value);
}
export function decodeTokenPreservationOutputV2RegistryAnalysis(value: Hex): TokenPreservationOutputV2RegistryAnalysis {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_ANALYSIS_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2RegistryRead(value: TokenPreservationOutputV2RegistryRead): TokenPreservationOutputV2RegistryRead {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_READ_TUPLE, value);
}
export function encodeTokenPreservationOutputV2RegistryRead(value: TokenPreservationOutputV2RegistryRead): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_READ_TUPLE, value);
}
export function decodeTokenPreservationOutputV2RegistryRead(value: Hex): TokenPreservationOutputV2RegistryRead {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_READ_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2ContentPlan(value: TokenPreservationOutputV2ContentPlan): TokenPreservationOutputV2ContentPlan {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_CONTENT_PLAN_TUPLE, value);
}
export function encodeTokenPreservationOutputV2ContentPlan(value: TokenPreservationOutputV2ContentPlan): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_CONTENT_PLAN_TUPLE, value);
}
export function decodeTokenPreservationOutputV2ContentPlan(value: Hex): TokenPreservationOutputV2ContentPlan {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_CONTENT_PLAN_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2Payload(value: TokenPreservationOutputV2Payload): TokenPreservationOutputV2Payload {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_PAYLOAD_TUPLE, value);
}
export function encodeTokenPreservationOutputV2Payload(value: TokenPreservationOutputV2Payload): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_PAYLOAD_TUPLE, value);
}
export function decodeTokenPreservationOutputV2Payload(value: Hex): TokenPreservationOutputV2Payload {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_PAYLOAD_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2Output(value: TokenPreservationOutputV2Output): TokenPreservationOutputV2Output {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_TUPLE, value);
}
export function encodeTokenPreservationOutputV2Output(value: TokenPreservationOutputV2Output): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_TUPLE, value);
}
export function decodeTokenPreservationOutputV2Output(value: Hex): TokenPreservationOutputV2Output {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2Manifest(value: TokenPreservationOutputV2Manifest): TokenPreservationOutputV2Manifest {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE, value);
}
export function encodeTokenPreservationOutputV2Manifest(value: TokenPreservationOutputV2Manifest): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE, value);
}
export function decodeTokenPreservationOutputV2Manifest(value: Hex): TokenPreservationOutputV2Manifest {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2OutputPlan(value: TokenPreservationOutputV2OutputPlan): TokenPreservationOutputV2OutputPlan {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_PLAN_TUPLE, value);
}
export function encodeTokenPreservationOutputV2OutputPlan(value: TokenPreservationOutputV2OutputPlan): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_PLAN_TUPLE, value);
}
export function decodeTokenPreservationOutputV2OutputPlan(value: Hex): TokenPreservationOutputV2OutputPlan {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_PLAN_TUPLE, value);
}

export function normalizeTokenPreservationOutputV2Coverage(value: TokenPreservationOutputV2Coverage): TokenPreservationOutputV2Coverage {
  return normalize(TOKEN_PRESERVATION_OUTPUT_V2_COVERAGE_TUPLE, value);
}
export function encodeTokenPreservationOutputV2Coverage(value: TokenPreservationOutputV2Coverage): Hex {
  return encode(TOKEN_PRESERVATION_OUTPUT_V2_COVERAGE_TUPLE, value);
}
export function decodeTokenPreservationOutputV2Coverage(value: Hex): TokenPreservationOutputV2Coverage {
  return decode(TOKEN_PRESERVATION_OUTPUT_V2_COVERAGE_TUPLE, value);
}

/** Structural raw scopes include zero and VIEW; this finite token admission helper does not. */
export function validateTokenPreservationOutputV2Scope(
  kind: TokenPreservationOutputV2ScopeKind,
  value: TokenPreservationOutputV2Scope,
): TokenPreservationOutputV2Scope {
  tokenPreservationOutputV2CheckpointProfile(kind);
  const s = normalizeTokenPreservationOutputV2Scope(value);
  if (!s.collectionId || (kind === "collection" ? s.scopeType !== 0n : s.scopeType < 1n || s.scopeType > 3n)) {
    throw Error("V2 profile requires COLLECTION or TOKEN/RELEASE/SEASON");
  }
  if (s.scopeType === 0n ? s.tokenId !== 0n || s.scopeId !== Z
    : s.scopeType === 1n ? s.tokenId === 0n || s.scopeId !== Z : s.tokenId !== 0n || s.scopeId === Z) {
    throw Error("Invalid original scope coordinates");
  }
  return s;
}
export function tokenPreservationOutputV2IsProducerProfile(value: Hex): boolean {
  const p = bytes(value, 32);
  return p === TOKEN_PRESERVATION_OUTPUT_V2_ORIGINAL_PRODUCER || p === TOKEN_PRESERVATION_OUTPUT_V2_CURRENT_ARTIST_PRODUCER;
}
/** Supplied identity only. Runtime, complete Registry admission and golden execution remain unproved. */
export function validateTokenPreservationOutputV2Binding(value: TokenPreservationOutputV2Binding): TokenPreservationOutputV2Binding {
  const b = normalizeTokenPreservationOutputV2Binding(value);
  if (!tokenPreservationOutputV2IsProducerProfile(b.profile)) throw Error("Unsupported token producer profile");
  pin(b.producer, b.producerCodeHash);
  pin(b.liveRenderer, b.liveRendererCodeHash);
  pin(b.attribution, b.attributionCodeHash);
  address(b.core, true);
  address(b.metadataRouter, true);
  return b;
}
export function tokenPreservationOutputV2BindingHash(value: TokenPreservationOutputV2Binding): Hex {
  return hash(["bytes32", TOKEN_PRESERVATION_OUTPUT_V2_BINDING_TUPLE],
    [id("6529STREAM_PRESERVATION_OUTPUT_BINDING_V1"), normalizeTokenPreservationOutputV2Binding(value)]);
}
export function tokenPreservationOutputV2RegistryKey(versionKey: Hex, producer: Address, profile: Hex): Hex {
  return hash(["bytes32", "bytes32", "address", "bytes32"],
    [id("6529STREAM_PRESERVATION_KEY_V1"), bytes(versionKey, 32), address(producer), bytes(profile, 32)]);
}
export function tokenPreservationOutputV2RegistryReadSetHash(
  targetSetHash: Hex,
  values: readonly TokenPreservationOutputV2RegistryRead[],
): Hex {
  const rows = list(values, 128).map(v => normalizeTokenPreservationOutputV2RegistryRead(v as TokenPreservationOutputV2RegistryRead));
  return hash(["bytes32", "bytes32", `${TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_READ_TUPLE}[]`],
    [id("6529STREAM_RENDERER_READ_SET_V1"), bytes(targetSetHash, 32), rows]);
}
export function encodeTokenPreservationOutputV2RegistryReads(values: readonly TokenPreservationOutputV2RegistryRead[]): Hex {
  const rows = list(values, 128).map(v => normalizeTokenPreservationOutputV2RegistryRead(v as TokenPreservationOutputV2RegistryRead));
  return bytes(coder.encode([`${TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_READ_TUPLE}[]`], [rows]), undefined, 16448);
}
export function decodeTokenPreservationOutputV2RegistryReads(value: Hex): readonly TokenPreservationOutputV2RegistryRead[] {
  const raw = bytes(value, undefined, 16448);
  const rows = normalize<readonly TokenPreservationOutputV2RegistryRead[]>(`${TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_READ_TUPLE}[]`, coder.decode([`${TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_READ_TUPLE}[]`], raw)[0], true);
  if (encodeTokenPreservationOutputV2RegistryReads(rows) !== raw) throw Error("Noncanonical Registry reads");
  return rows;
}
/** Original two flat return tuples, exactly 512 bytes. No outer wrapper and no field-name rewrite. */
export function encodeTokenPreservationOutputV2RegistryAdmission(
  binding: TokenPreservationOutputV2RegistryBinding,
  admission: TokenPreservationOutputV2Admission,
): Hex {
  return bytes(coder.encode([TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_BINDING_TUPLE, TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE],
    [normalizeTokenPreservationOutputV2RegistryBinding(binding), normalizeTokenPreservationOutputV2Admission(admission)]), 512);
}
export function decodeTokenPreservationOutputV2RegistryAdmission(value: Hex) {
  const raw = bytes(value, 512);
  const result = coder.decode([TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_BINDING_TUPLE, TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE], raw);
  const binding = normalize<TokenPreservationOutputV2RegistryBinding>(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_BINDING_TUPLE, result[0], true);
  const admission = normalize<TokenPreservationOutputV2Admission>(TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE, result[1], true);
  if (encodeTokenPreservationOutputV2RegistryAdmission(binding, admission) !== raw) throw Error("Noncanonical Registry admission");
  return Object.freeze({ binding, admission });
}
/** Rejoins supplied original selection and actual Registry reply; it does not authenticate their RPC origin. */
export function validateTokenPreservationOutputV2Admission(
  inputBinding: TokenPreservationOutputV2Binding,
  inputAdmission: TokenPreservationOutputV2Admission,
  inputSelection: TokenPreservationOutputV2TokenSelection,
  inputRegistryBinding?: TokenPreservationOutputV2RegistryBinding,
) {
  const binding = validateTokenPreservationOutputV2Binding(inputBinding);
  const admission = normalizeTokenPreservationOutputV2Admission(inputAdmission);
  const row = normalizeTokenPreservationOutputV2TokenSelection(inputSelection);
  pin(admission.registry, admission.registryCodeHash);
  [admission.versionKey, admission.registrationHash, admission.readSetHash, admission.analysisHash, admission.goldenHash].forEach(nonzero);
  same([binding.core, binding.metadataRouter, binding.liveRenderer, binding.liveRendererCodeHash],
    [row.sources[0], row.sources[1], row.selection.renderer, row.selection.rendererCodeHash], "Selected producer");
  same([admission.registry, admission.registryCodeHash, admission.versionKey],
    [row.selection.registry, row.selection.registryCodeHash, row.selection.versionKey], "Selected Registry admission");
  if (inputRegistryBinding !== undefined) {
    const r = normalizeTokenPreservationOutputV2RegistryBinding(inputRegistryBinding);
    same(encodeTokenPreservationOutputV2Binding(binding), encodeTokenPreservationOutputV2RegistryBinding(r), "Original Registry binding");
  }
  return Object.freeze({ binding, admission, selection: row, factsVerified: false as const });
}

export interface TokenPreservationOutputV2CheckpointIdentity {
  readonly selectionCheckpoint: Address;
  readonly selectionId: Hex;
  readonly selection: TokenPreservationOutputV2SelectionPlan;
  readonly entropySourceSet: Address;
  readonly entropySourceSetCodeHash: Hex;
  readonly terminalReadiness: Address;
  readonly terminalReadinessCodeHash: Hex;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly salt: Hex;
}
function identity(input: TokenPreservationOutputV2CheckpointIdentity) {
  exact(input, ["selectionCheckpoint", "selectionId", "selection", "entropySourceSet", "entropySourceSetCodeHash", "terminalReadiness", "terminalReadinessCodeHash", "inventoryHash", "policyChainHash", "salt"]);
  return Object.freeze({ selectionCheckpoint: address(input.selectionCheckpoint), selectionId: bytes(input.selectionId, 32),
    selection: normalizeTokenPreservationOutputV2SelectionPlan(input.selection), entropySourceSet: address(input.entropySourceSet),
    entropySourceSetCodeHash: bytes(input.entropySourceSetCodeHash, 32), terminalReadiness: address(input.terminalReadiness),
    terminalReadinessCodeHash: bytes(input.terminalReadinessCodeHash, 32), inventoryHash: bytes(input.inventoryHash, 32),
    policyChainHash: bytes(input.policyChainHash, 32), salt: bytes(input.salt, 32) });
}
export function tokenPreservationOutputV2SelectionHash(value: TokenPreservationOutputV2SelectionPlan): Hex {
  return keccak256(encodeTokenPreservationOutputV2SelectionPlan(value)) as Hex;
}
export function tokenPreservationOutputV2CheckpointId(
  inputCoordinates: TokenPreservationOutputV2Coordinates,
  input: TokenPreservationOutputV2CheckpointIdentity,
): Hex {
  const c = normalizeTokenPreservationOutputV2Coordinates(inputCoordinates);
  const i = identity(input);
  return hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "address", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [tokenPreservationOutputV2CheckpointProfile(c.scopeKind), c.chainId, c.checkpoint, i.selectionCheckpoint, i.selectionId,
      tokenPreservationOutputV2SelectionHash(i.selection), i.entropySourceSet, i.entropySourceSetCodeHash, i.terminalReadiness,
      i.terminalReadinessCodeHash, i.inventoryHash, i.policyChainHash, TOKEN_PRESERVATION_OUTPUT_V2_FAMILY, i.salt]);
}
/** Expected new plan only. An idempotent begin leaves all existing progress unchanged. */
export function tokenPreservationOutputV2InitialContentPlan(
  scopeKind: TokenPreservationOutputV2ScopeKind,
  input: TokenPreservationOutputV2CheckpointIdentity,
): TokenPreservationOutputV2ContentPlan {
  const i = identity(input);
  const s = i.selection;
  validateTokenPreservationOutputV2Scope(scopeKind, s.scope);
  if (!s.tokenCount || s.nextIndex !== s.tokenCount
    || (s.scope.scopeType === 1n && s.tokenCount !== 1n)) throw Error("Incomplete original selection");
  nonzero(s.selectionRoot);
  pin(i.entropySourceSet, i.entropySourceSetCodeHash);
  pin(i.terminalReadiness, i.terminalReadinessCodeHash);
  address(i.selectionCheckpoint, true);
  return normalizeTokenPreservationOutputV2ContentPlan({ selectionId: nonzero(i.selectionId), selectionHash: tokenPreservationOutputV2SelectionHash(s),
    inventoryHash: nonzero(i.inventoryHash), policyChainHash: nonzero(i.policyChainHash), scope: s.scope, tokenCount: s.tokenCount,
    nextIndex: 0n, leafChainHash: Z, contentRoot: Z, outputRoot: Z, preservationProfile: TOKEN_PRESERVATION_OUTPUT_V2_FAMILY });
}
export function tokenPreservationOutputV2SelectionRowHash(
  chainId: bigint, core: Address, metadataRouter: Address, value: TokenPreservationOutputV2TokenSelection,
): Hex {
  return hash(["bytes32", "uint256", "address", "address", TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_SELECTION_TUPLE],
    [id("6529STREAM_STATIC_SELECTION_ROW_V1"), uint(chainId), address(core), address(metadataRouter), normalizeTokenPreservationOutputV2TokenSelection(value)]);
}
export function tokenPreservationOutputV2LeafHash(chainId: bigint, core: Address, value: TokenPreservationOutputV2Leaf): Hex {
  const l = normalizeTokenPreservationOutputV2Leaf(value);
  return hash(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    ["0x61d75cd1a57d24657b860f99f77c15e5f8556fb725b56a96dd770205f9352b0d", uint(chainId), address(core),
      l.tokenId, l.metadataHash, l.imageHash, l.animationHash, l.contentHash, l.tokenDataHash]);
}
export function tokenPreservationOutputV2NodeHash(left: Hex, right: Hex): Hex {
  return hash(["bytes32", "bytes32", "bytes32"],
    ["0x7239fc0713b7ccc92b7eef3087150a1f32037aff6ab05f5bf78db4f8ab71a6ea", bytes(left, 32), bytes(right, 32)]);
}
/** Original ordered tree. Odd nodes carry forward without sorting or duplication. */
export function tokenPreservationOutputV2ContentRoot(chainId: bigint, core: Address, values: readonly TokenPreservationOutputV2Leaf[]): Hex {
  const rows = list(values, TOKEN_PRESERVATION_OUTPUT_V2_MAX_CHECKPOINT_TOKENS).map(v => normalizeTokenPreservationOutputV2Leaf(v as TokenPreservationOutputV2Leaf));
  if (!rows.length) throw Error("Empty content tree");
  let level = rows.map((l, i) => {
    if (!l.tokenId || l.metadataHash === Z || (i && l.tokenId <= rows[i - 1]!.tokenId)) throw Error("Invalid ordered content leaves");
    return tokenPreservationOutputV2LeafHash(chainId, core, l);
  });
  while (level.length > 1) {
    const next: Hex[] = [];
    for (let i = 0; i < level.length; i += 2) next.push(i + 1 === level.length ? level[i]! : tokenPreservationOutputV2NodeHash(level[i]!, level[i + 1]!));
    level = next;
  }
  return level[0]!;
}
export function tokenPreservationOutputV2LeafChain(previous: Hex, index: bigint, leafHash: Hex): Hex {
  return hash(["bytes32", "bytes32", "uint256", "bytes32"],
    [id("6529STREAM_PRESERVATION_POLICY_CONTENT_LEAVES_V1"), bytes(previous, 32), uint(index), bytes(leafHash, 32)]);
}
export function tokenPreservationOutputV2OutputChain(previous: Hex, index: bigint, output: TokenPreservationOutputV2Output): Hex {
  return hash(["bytes32", "bytes32", "uint256", TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_TUPLE],
    [id("6529STREAM_PRESERVATION_POLICY_OUTPUTS_V1"), bytes(previous, 32), uint(index), normalizeTokenPreservationOutputV2Output(output)]);
}
export interface TokenPreservationOutputV2SourceFacts {
  readonly preservation: TokenPreservationOutputV2Binding;
  readonly admission: TokenPreservationOutputV2Admission;
  readonly configHash: Hex;
  readonly rawSourceHash: Hex;
  readonly coordinator: Address;
  readonly entropy: TokenPreservationOutputV2TokenReadiness;
  readonly entropySourceSet: Address;
  readonly entropySourceSetCodeHash: Hex;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly terminalReadiness: Address;
  readonly terminalReadinessCodeHash: Hex;
  readonly terminalAdmissionHash: Hex;
}
export function tokenPreservationOutputV2SourceFactsHash(kind: TokenPreservationOutputV2ScopeKind, value: TokenPreservationOutputV2SourceFacts): Hex {
  exact(value, ["preservation", "admission", "configHash", "rawSourceHash", "coordinator", "entropy", "entropySourceSet", "entropySourceSetCodeHash", "inventoryHash", "policyChainHash", "terminalReadiness", "terminalReadinessCodeHash", "terminalAdmissionHash"]);
  return hash(["bytes32", "bytes32", TOKEN_PRESERVATION_OUTPUT_V2_BINDING_TUPLE, TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE,
    "bytes32", "bytes32", "address", "bytes", "address", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32"],
  [tokenPreservationOutputV2CheckpointProfile(kind), TOKEN_PRESERVATION_OUTPUT_V2_FAMILY, normalizeTokenPreservationOutputV2Binding(value.preservation),
    normalizeTokenPreservationOutputV2Admission(value.admission), bytes(value.configHash, 32), bytes(value.rawSourceHash, 32), address(value.coordinator),
    encodeTokenPreservationOutputV2TokenReadiness(value.entropy), address(value.entropySourceSet), bytes(value.entropySourceSetCodeHash, 32),
    bytes(value.inventoryHash, 32), bytes(value.policyChainHash, 32), address(value.terminalReadiness), bytes(value.terminalReadinessCodeHash, 32), bytes(value.terminalAdmissionHash, 32)]);
}
export function validateTokenPreservationOutputV2Readiness(
  value: TokenPreservationOutputV2TokenReadiness,
  terminalAdmissionHash: Hex,
): TokenPreservationOutputV2TokenReadiness {
  const e = normalizeTokenPreservationOutputV2TokenReadiness(value);
  const terminal = bytes(terminalAdmissionHash, 32);
  pin(e.coordinator, e.coordinatorCodeHash);
  nonzero(e.policyHash);
  if (e.terminal) {
    if (e.finalized || e.seed !== Z || e.renderRequirement !== 1n || terminal === Z
      || !((e.status === 1n && e.mode === 0n) || (e.status === 2n && e.mode === 2n))) throw Error("Invalid terminal output");
  } else if (!e.finalized || e.status !== 5n || e.mode !== 2n || e.renderRequirement !== 0n || terminal !== Z) {
    throw Error("Invalid finalized output");
  }
  return e;
}
export function validateTokenPreservationOutputV2Output(value: TokenPreservationOutputV2Output): TokenPreservationOutputV2Output {
  const o = normalizeTokenPreservationOutputV2Output(value);
  validateTokenPreservationOutputV2Binding(o.preservation);
  pin(o.preservationAdmission.registry, o.preservationAdmission.registryCodeHash);
  [o.preservationAdmission.versionKey, o.preservationAdmission.registrationHash, o.preservationAdmission.readSetHash,
    o.preservationAdmission.analysisHash, o.preservationAdmission.goldenHash].forEach(nonzero);
  validateTokenPreservationOutputV2Readiness(o.entropy, o.terminalAdmissionHash);
  if (!o.leaf.tokenId || o.leaf.metadataHash === Z || o.leaf.animationHash === Z || o.leaf.contentHash !== Z
    || o.htmlHash !== o.leaf.animationHash || o.selectionRowHash === Z || o.sourceFactsHash === Z) throw Error("Invalid supplied output commitments");
  return o;
}

export interface TokenPreservationOutputV2ManifestBytes {
  readonly schemaId: Hex;
  readonly chainId: bigint;
  readonly core: Address;
  readonly checkpoint: Address;
  readonly checkpointHash: Hex;
  readonly checkpointStateHash: Hex;
  readonly entropySourceSet: Address;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly metadataRouter: Address;
  readonly preservationProfile: Hex;
  readonly scope: TokenPreservationOutputV2Scope;
  readonly contentRoot: Hex;
  readonly outputRoot: Hex;
  readonly tokenCount: bigint;
  readonly rows: readonly TokenPreservationOutputV2Output[];
}
const manifestFields = [
  "bytes32 schemaId", "uint256 chainId", "address core", "address checkpoint", "bytes32 checkpointHash",
  "bytes32 checkpointStateHash", "address entropySourceSet", "bytes32 inventoryHash", "bytes32 policyChainHash",
  "address metadataRouter", "bytes32 preservationProfile", `${TOKEN_PRESERVATION_OUTPUT_V2_SCOPE_TUPLE} scope`,
  "bytes32 contentRoot", "bytes32 outputRoot", "uint64 tokenCount", `${TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_TUPLE}[] rows`,
];
function flatEncode(fields: readonly string[], value: unknown, maximum: number): Hex {
  const types = fields.map(f => ParamType.from(f));
  exact(value, types.map(t => t.name));
  return bytes(coder.encode(types, types.map(t => valueOf(t, value[t.name]))), undefined, maximum);
}
function flatDecode<T>(fields: readonly string[], value: Hex, maximum: number): T {
  const raw = bytes(value, undefined, maximum);
  const types = fields.map(f => ParamType.from(f));
  const decoded = coder.decode(types, raw);
  const result = Object.freeze(Object.fromEntries(types.map((t, i) => [t.name, valueOf(t, decoded[i], true)]))) as T;
  if (flatEncode(fields, result, maximum) !== raw) throw Error("Noncanonical flat ABI");
  return result;
}
function completedPlan(kind: TokenPreservationOutputV2ScopeKind, value: TokenPreservationOutputV2ContentPlan) {
  const p = normalizeTokenPreservationOutputV2ContentPlan(value);
  validateTokenPreservationOutputV2Scope(kind, p.scope);
  if (!p.tokenCount || p.nextIndex !== p.tokenCount || p.preservationProfile !== TOKEN_PRESERVATION_OUTPUT_V2_FAMILY
    || (p.scope.scopeType === 1n && p.tokenCount !== 1n)) throw Error("Incomplete V2 checkpoint");
  [p.selectionId, p.selectionHash, p.inventoryHash, p.policyChainHash, p.contentRoot, p.outputRoot].forEach(nonzero);
  return p;
}
function rowsCommitments(chainId: bigint, core: Address, rows: readonly TokenPreservationOutputV2Output[]) {
  let outputRoot = Z;
  let leafChainHash = Z;
  rows.forEach((row, i) => {
    outputRoot = tokenPreservationOutputV2OutputChain(outputRoot, BigInt(i), row);
    leafChainHash = tokenPreservationOutputV2LeafChain(leafChainHash, BigInt(i), tokenPreservationOutputV2LeafHash(chainId, core, row.leaf));
  });
  return { contentRoot: tokenPreservationOutputV2ContentRoot(chainId, core, rows.map(row => row.leaf)), outputRoot, leafChainHash };
}
/** Exact flat ABI, with a 608-byte dynamic array offset and 640-byte header including count. */
export function tokenPreservationOutputV2ManifestBytes(
  inputCoordinates: TokenPreservationOutputV2Coordinates,
  checkpointHash: Hex,
  inputContent: TokenPreservationOutputV2ContentPlan,
  entropySourceSet: Address,
  values: readonly TokenPreservationOutputV2Output[],
): Hex {
  const c = normalizeTokenPreservationOutputV2Coordinates(inputCoordinates);
  const p = completedPlan(c.scopeKind, inputContent);
  const rows = list(values, TOKEN_PRESERVATION_OUTPUT_V2_MAX_OUTPUTS).map(row => validateTokenPreservationOutputV2Output(row as TokenPreservationOutputV2Output));
  if (p.tokenCount !== BigInt(rows.length)) throw Error("Incomplete manifest rows");
  if (p.scope.scopeType === 1n && rows[0]!.leaf.tokenId !== p.scope.tokenId) throw Error("TOKEN manifest member differs");
  rows.forEach(row => same([row.preservation.core, row.preservation.metadataRouter], [c.core, c.metadataRouter], "Common producer hosts"));
  const committed = rowsCommitments(c.chainId, c.core, rows);
  same([p.contentRoot, p.outputRoot, p.leafChainHash], [committed.contentRoot, committed.outputRoot, committed.leafChainHash], "Complete row roots");
  return flatEncode(manifestFields, { schemaId: TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA, chainId: c.chainId, core: c.core,
    checkpoint: c.checkpoint, checkpointHash: nonzero(checkpointHash), checkpointStateHash: keccak256(encodeTokenPreservationOutputV2ContentPlan(p)),
    entropySourceSet: address(entropySourceSet, true), inventoryHash: p.inventoryHash, policyChainHash: p.policyChainHash,
    metadataRouter: c.metadataRouter, preservationProfile: TOKEN_PRESERVATION_OUTPUT_V2_FAMILY, scope: p.scope,
    contentRoot: p.contentRoot, outputRoot: p.outputRoot, tokenCount: p.tokenCount, rows }, TOKEN_PRESERVATION_OUTPUT_V2_MAX_MANIFEST_BYTES);
}
/** Canonical token-family document integrity, not Registry admission, coverage or currentness evidence. */
export function decodeTokenPreservationOutputV2ManifestBytes(value: Hex): TokenPreservationOutputV2ManifestBytes {
  const raw = bytes(value, undefined, TOKEN_PRESERVATION_OUTPUT_V2_MAX_MANIFEST_BYTES);
  if ((raw.length - 2) / 2 < 640) throw Error("Truncated output manifest");
  const result = flatDecode<TokenPreservationOutputV2ManifestBytes>(manifestFields, raw, TOKEN_PRESERVATION_OUTPUT_V2_MAX_MANIFEST_BYTES);
  validateTokenPreservationOutputV2Scope(result.scope.scopeType === 0n ? "collection" : "scoped", result.scope);
  if (result.schemaId !== TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA || result.preservationProfile !== TOKEN_PRESERVATION_OUTPUT_V2_FAMILY
    || !result.tokenCount || result.tokenCount !== BigInt(result.rows.length) || result.rows.length > TOKEN_PRESERVATION_OUTPUT_V2_MAX_OUTPUTS
    || (result.scope.scopeType === 1n && result.tokenCount !== 1n) || (raw.length - 2) / 2 !== 640 + 1152 * result.rows.length) {
    throw Error("Invalid V2 output manifest header");
  }
  if (!result.chainId) throw Error("Zero chain");
  [result.core, result.checkpoint, result.entropySourceSet, result.metadataRouter].forEach(a => address(a, true));
  [result.checkpointHash, result.checkpointStateHash, result.inventoryHash, result.policyChainHash].forEach(nonzero);
  result.rows.forEach(row => {
    validateTokenPreservationOutputV2Output(row);
    same([row.preservation.core, row.preservation.metadataRouter], [result.core, result.metadataRouter], "Common producer hosts");
  });
  if (result.scope.scopeType === 1n && result.rows[0]!.leaf.tokenId !== result.scope.tokenId) throw Error("TOKEN manifest member differs");
  const committed = rowsCommitments(result.chainId, result.core, result.rows);
  same([result.contentRoot, result.outputRoot], [committed.contentRoot, committed.outputRoot], "Manifest row roots");
  return result;
}
/** Supplied genuine FinalityArtifactCoverage facts, separate from ExternalArtifactCoverage. */
export function tokenPreservationOutputV2Manifest(
  inputCoordinates: TokenPreservationOutputV2Coordinates,
  checkpointHash: Hex,
  inputContent: TokenPreservationOutputV2ContentPlan,
  entropySourceSet: Address,
  inputCoverage: TokenPreservationOutputV2Coverage,
): TokenPreservationOutputV2Manifest {
  const c = normalizeTokenPreservationOutputV2Coordinates(inputCoordinates);
  const p = completedPlan(c.scopeKind, inputContent);
  const coverage = normalizeTokenPreservationOutputV2Coverage(inputCoverage);
  const length = 640n + 1152n * p.tokenCount;
  if (length > BigInt(TOKEN_PRESERVATION_OUTPUT_V2_MAX_MANIFEST_BYTES) || coverage.byteLength !== length
    || coverage.chunkCount !== (length + 8191n) / 8192n || coverage.schemaId !== TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA
    || coverage.canonicalizationId !== TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION
    || coverage.firstFamilyRecordHash === coverage.secondFamilyRecordHash) throw Error("Invalid supplied output coverage");
  [coverage.completionHash, coverage.artifactHash, coverage.artistId, coverage.contentHash, coverage.firstFamilyRecordHash,
    coverage.secondFamilyRecordHash].forEach(nonzero);
  return normalizeTokenPreservationOutputV2Manifest({ checkpointHash: nonzero(checkpointHash),
    checkpointStateHash: keccak256(encodeTokenPreservationOutputV2ContentPlan(p)) as Hex, entropySourceSet: address(entropySourceSet, true),
    inventoryHash: p.inventoryHash, policyChainHash: p.policyChainHash, metadataRouter: c.metadataRouter,
    preservationProfile: TOKEN_PRESERVATION_OUTPUT_V2_FAMILY, artifactHash: coverage.artifactHash, coverageHash: coverage.completionHash,
    artistId: coverage.artistId, contentRoot: p.contentRoot, outputRoot: p.outputRoot, manifestHash: coverage.contentHash,
    scope: p.scope, tokenCount: p.tokenCount, byteLength: length });
}
export function tokenPreservationOutputV2ManifestPlanHash(
  inputCoordinates: TokenPreservationOutputV2Coordinates,
  artifactCoverage: Address,
  value: TokenPreservationOutputV2Manifest,
): Hex {
  const c = normalizeTokenPreservationOutputV2Coordinates(inputCoordinates);
  return hash(["bytes32", "uint256", "address", "address", "address", "address", TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE],
    [id("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_PLAN_V2"), c.chainId, c.output, c.core, c.checkpoint,
      address(artifactCoverage), normalizeTokenPreservationOutputV2Manifest(value)]);
}
export function tokenPreservationOutputV2RecordHash(planHash: Hex): Hex {
  return hash(["bytes32", "bytes32"], [id("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V2"), bytes(planHash, 32)]);
}
/** Immutable stored manifest commitment only; no current pins, grants or source reads. */
export function authenticateTokenPreservationOutputV2History(
  inputCoordinates: TokenPreservationOutputV2Coordinates,
  artifactCoverage: Address,
  planHash: Hex,
  input: TokenPreservationOutputV2OutputPlan,
) {
  const c = normalizeTokenPreservationOutputV2Coordinates(inputCoordinates);
  const p = normalizeTokenPreservationOutputV2OutputPlan(input);
  const m = p.manifest;
  validateTokenPreservationOutputV2Scope(c.scopeKind, m.scope);
  if (m.preservationProfile !== TOKEN_PRESERVATION_OUTPUT_V2_FAMILY || !m.tokenCount || p.nextIndex !== m.tokenCount
    || m.byteLength !== 640n + 1152n * m.tokenCount || m.byteLength > BigInt(TOKEN_PRESERVATION_OUTPUT_V2_MAX_MANIFEST_BYTES)
    || (m.scope.scopeType === 1n && m.tokenCount !== 1n)) throw Error("Invalid completed manifest history");
  same(m.metadataRouter, c.metadataRouter, "Historical Router");
  address(m.entropySourceSet, true);
  [m.checkpointHash, m.checkpointStateHash, m.inventoryHash, m.policyChainHash, m.artifactHash, m.coverageHash,
    m.artistId, m.contentRoot, m.outputRoot, m.manifestHash].forEach(nonzero);
  same(nonzero(planHash), tokenPreservationOutputV2ManifestPlanHash(c, artifactCoverage, m), "Manifest plan hash");
  same(nonzero(p.recordHash), tokenPreservationOutputV2RecordHash(planHash), "Verified manifest hash");
  return Object.freeze({ coordinates: c, artifactCoverage: address(artifactCoverage, true), planHash: bytes(planHash, 32), plan: p,
    currentnessChecked: false as const, factsVerified: false as const });
}

export const TOKEN_PRESERVATION_OUTPUT_V2_CHECKPOINT_ABI = Object.freeze([
  "function begin(bytes32 selectionId,bytes32 salt) returns (bytes32 id)",
  `function append(bytes32 id,${TOKEN_PRESERVATION_OUTPUT_V2_PAYLOAD_TUPLE}[] payloads)`,
  `function checkpoint(bytes32 id) view returns (${TOKEN_PRESERVATION_OUTPUT_V2_CONTENT_PLAN_TUPLE})`,
  `function outputAt(bytes32 id,uint256 index) view returns (${TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_TUPLE})`,
  `function requireCurrentCheckpoint(bytes32 id) view returns (${TOKEN_PRESERVATION_OUTPUT_V2_CONTENT_PLAN_TUPLE})`,
  "function preservationPolicyProfile() view returns (bytes32)",
  "function preservationOutputProfile() pure returns (bytes32)",
  "function core() view returns (address)", "function metadataRouter() view returns (address)",
  "function selectionCheckpoint() view returns (address)", "function entropySourceSet() view returns (address)",
  "function terminalReadiness() view returns (address)", "function sourceFactory() view returns (address)",
  "function factoryDependenciesHash() view returns (bytes32)", "function supportsInterface(bytes4 id) pure returns (bool)",
  `event StaticContentStarted(uint16 schemaVersion,bytes32 indexed id,bytes32 salt,${TOKEN_PRESERVATION_OUTPUT_V2_CONTENT_PLAN_TUPLE} plan)`,
  `event StaticContentAppended(uint16 schemaVersion,bytes32 indexed id,uint64 indexed index,${TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_TUPLE} output,bytes32 leafHash)`,
  "event StaticContentCompleted(uint16 schemaVersion,bytes32 indexed id,bytes32 contentRoot,bytes32 outputRoot,uint64 count)",
]);
export const TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_ABI = Object.freeze([
  "function beginManifest(bytes32 checkpointHash,bytes32 artifactHash,bytes32 coverageHash,bytes32 artistId) returns (bytes32 planHash)",
  "function verifyNextOutputs(bytes32 planHash,uint256 count) returns (bytes32 recordHash)",
  `function manifestPlan(bytes32 planHash) view returns (${TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_PLAN_TUPLE})`,
  `function manifestRecord(bytes32 recordHash) view returns (${TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE})`,
  `function requireCurrentManifest(bytes32 recordHash,bytes32 artistId) view returns (${TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE} m)`,
  "function outputProfile() view returns (bytes32)", "function core() view returns (address)",
  "function contentCheckpoint() view returns (address)", "function artifactCoverage() view returns (address)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  `event OutputManifestStarted(uint16 schemaVersion,bytes32 indexed planHash,${TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE} manifest)`,
  "event OutputManifestAdvanced(uint16 schemaVersion,bytes32 indexed planHash,uint64 firstIndex,uint64 nextIndex)",
  `event OutputManifestVerified(uint16 schemaVersion,bytes32 indexed recordHash,bytes32 indexed planHash,${TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE} manifest)`,
]);
export const TOKEN_PRESERVATION_OUTPUT_V2_PRODUCER_ABI = Object.freeze([
  "function preservationProfile() pure returns (bytes32)",
  "function preservationBinding() view returns (address core,address router,address liveRenderer,bytes32 liveRendererRuntimeHash,address preservationAttribution,bytes32 preservationAttributionRuntimeHash)",
  "function preservationTokenJSON(uint256 tokenId) view returns (string)",
  "function preservationTokenHTML(uint256 tokenId) view returns (string)",
]);
export const TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_ABI = Object.freeze([
  "function preservationKey(bytes32 versionKey,address producer,bytes32 profile) pure returns (bytes32)",
  `function preservationRecord(bytes32 key) view returns (${TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_RECORD_TUPLE})`,
  `function preservationReads(bytes32 key) view returns (${TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_READ_TUPLE}[])`,
  `function requirePreservation(bytes32 versionKey,address producer,bytes32 profile) view returns (${TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_BINDING_TUPLE},${TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE})`,
]);
export type TokenPreservationOutputV2Host = "checkpoint" | "output" | "producer" | "registry";
export function tokenPreservationOutputV2Interface(host: TokenPreservationOutputV2Host): Interface {
  switch (host) {
    case "checkpoint": return new Interface(TOKEN_PRESERVATION_OUTPUT_V2_CHECKPOINT_ABI);
    case "output": return new Interface(TOKEN_PRESERVATION_OUTPUT_V2_OUTPUT_ABI);
    case "producer": return new Interface(TOKEN_PRESERVATION_OUTPUT_V2_PRODUCER_ABI);
    case "registry": return new Interface(TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_ABI);
    default: throw Error("Unsupported original host");
  }
}
export type TokenPreservationOutputV2Request =
  | { readonly kind: "begin"; readonly selectionId: Hex; readonly salt: Hex }
  | { readonly kind: "append"; readonly id: Hex; readonly payloads: readonly TokenPreservationOutputV2Payload[] }
  | { readonly kind: "beginManifest"; readonly checkpointHash: Hex; readonly artifactHash: Hex; readonly coverageHash: Hex; readonly artistId: Hex }
  | { readonly kind: "verifyNextOutputs"; readonly planHash: Hex; readonly count: bigint };
export interface TokenPreservationOutputV2Call {
  readonly coordinates: TokenPreservationOutputV2Coordinates;
  readonly caller: Address;
  readonly request: TokenPreservationOutputV2Request;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}
export function normalizeTokenPreservationOutputV2Request(value: TokenPreservationOutputV2Request): TokenPreservationOutputV2Request {
  switch (value.kind) {
    case "begin":
      exact(value, ["kind", "selectionId", "salt"]);
      return Object.freeze({ kind: value.kind, selectionId: nonzero(value.selectionId), salt: bytes(value.salt, 32) });
    case "append": {
      exact(value, ["kind", "id", "payloads"]);
      const rows = list(value.payloads, TOKEN_PRESERVATION_OUTPUT_V2_MAX_APPEND).map(v => normalizeTokenPreservationOutputV2Payload(v as TokenPreservationOutputV2Payload));
      if (!rows.length) throw Error("Empty append batch");
      rows.forEach(row => {
        if (!row.tokenId || row.animation === "0x") throw Error("Invalid append payload");
        address(row.producer, true);
        bytes(row.image, undefined, 2048);
        bytes(row.animation, undefined, TOKEN_PRESERVATION_OUTPUT_V2_MAX_RENDER_BYTES);
      });
      return Object.freeze({ kind: value.kind, id: nonzero(value.id), payloads: Object.freeze(rows) });
    }
    case "beginManifest":
      exact(value, ["kind", "checkpointHash", "artifactHash", "coverageHash", "artistId"]);
      return Object.freeze({ kind: value.kind, checkpointHash: nonzero(value.checkpointHash), artifactHash: nonzero(value.artifactHash),
        coverageHash: nonzero(value.coverageHash), artistId: nonzero(value.artistId) });
    case "verifyNextOutputs":
      exact(value, ["kind", "planHash", "count"]);
      if (!uint(value.count) || value.count > 16n) throw Error("Invalid verification batch");
      return Object.freeze({ kind: value.kind, planHash: nonzero(value.planHash), count: value.count });
    default: throw Error("Unsupported original output mutation");
  }
}
export function prepareTokenPreservationOutputV2Call(
  inputCoordinates: TokenPreservationOutputV2Coordinates,
  caller: Address,
  input: TokenPreservationOutputV2Request,
): TokenPreservationOutputV2Call {
  const coordinates = normalizeTokenPreservationOutputV2Coordinates(inputCoordinates);
  const request = normalizeTokenPreservationOutputV2Request(input);
  let host: "checkpoint" | "output";
  let args: readonly unknown[];
  switch (request.kind) {
    case "begin": host = "checkpoint"; args = [request.selectionId, request.salt]; break;
    case "append": host = "checkpoint"; args = [request.id, request.payloads]; break;
    case "beginManifest": host = "output"; args = [request.checkpointHash, request.artifactHash, request.coverageHash, request.artistId]; break;
    case "verifyNextOutputs": host = "output"; args = [request.planHash, request.count]; break;
  }
  const data = bytes(tokenPreservationOutputV2Interface(host).encodeFunctionData(request.kind, args));
  return Object.freeze({ coordinates, caller: address(caller, true), request,
    call: Object.freeze({ to: coordinates[host], data, value: 0n }), factsVerified: false });
}
export function normalizeTokenPreservationOutputV2Call(value: TokenPreservationOutputV2Call): TokenPreservationOutputV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"]);
  exact(value.call, ["to", "data", "value"]);
  const r = prepareTokenPreservationOutputV2Call(value.coordinates, value.caller, value.request);
  same([address(value.call.to), bytes(value.call.data), uint(value.call.value), value.factsVerified], [r.call.to, r.call.data, 0n, false], "Original output call");
  return r;
}
export type TokenPreservationOutputV2ReadRequest =
  | { readonly host: "checkpoint"; readonly kind: "checkpoint" | "requireCurrentCheckpoint"; readonly id: Hex }
  | { readonly host: "checkpoint"; readonly kind: "outputAt"; readonly id: Hex; readonly index: bigint }
  | { readonly host: "checkpoint"; readonly kind: "preservationPolicyProfile" | "preservationOutputProfile" | "core" | "metadataRouter" | "selectionCheckpoint" | "entropySourceSet" | "terminalReadiness" | "sourceFactory" | "factoryDependenciesHash" }
  | { readonly host: "output"; readonly kind: "manifestPlan"; readonly planHash: Hex }
  | { readonly host: "output"; readonly kind: "manifestRecord"; readonly recordHash: Hex }
  | { readonly host: "output"; readonly kind: "requireCurrentManifest"; readonly recordHash: Hex; readonly artistId: Hex }
  | { readonly host: "output"; readonly kind: "outputProfile" | "core" | "contentCheckpoint" | "artifactCoverage" }
  | { readonly host: "producer"; readonly target: Address; readonly kind: "preservationProfile" | "preservationBinding" }
  | { readonly host: "producer"; readonly target: Address; readonly kind: "preservationTokenJSON" | "preservationTokenHTML"; readonly tokenId: bigint }
  | { readonly host: "registry"; readonly target: Address; readonly kind: "preservationRecord" | "preservationReads"; readonly key: Hex }
  | { readonly host: "registry"; readonly target: Address; readonly kind: "preservationKey" | "requirePreservation"; readonly versionKey: Hex; readonly producer: Address; readonly profile: Hex };
export interface TokenPreservationOutputV2Read {
  readonly coordinates: TokenPreservationOutputV2Coordinates;
  readonly request: TokenPreservationOutputV2ReadRequest;
  readonly call: UnsignedCall;
}
export function prepareTokenPreservationOutputV2Read(
  inputCoordinates: TokenPreservationOutputV2Coordinates,
  input: TokenPreservationOutputV2ReadRequest,
): TokenPreservationOutputV2Read {
  const coordinates = normalizeTokenPreservationOutputV2Coordinates(inputCoordinates);
  let target: Address;
  let fields: readonly string[];
  const normalized: Record<string, unknown> = { host: input.host, kind: input.kind };
  let args: readonly unknown[] = [];
  if (input.host === "checkpoint") {
    target = coordinates.checkpoint;
    if (input.kind === "checkpoint" || input.kind === "requireCurrentCheckpoint") {
      fields = ["id"]; normalized.id = bytes(input.id, 32); args = [normalized.id];
    } else if (input.kind === "outputAt") {
      fields = ["id", "index"]; normalized.id = bytes(input.id, 32); normalized.index = uint(input.index); args = [normalized.id, normalized.index];
    } else if (["preservationPolicyProfile", "preservationOutputProfile", "core", "metadataRouter", "selectionCheckpoint", "entropySourceSet", "terminalReadiness", "sourceFactory", "factoryDependenciesHash"].includes(input.kind)) fields = [];
    else throw Error("Unsupported checkpoint read");
  } else if (input.host === "output") {
    target = coordinates.output;
    if (input.kind === "manifestPlan") {
      fields = ["planHash"]; normalized.planHash = bytes(input.planHash, 32); args = [normalized.planHash];
    } else if (input.kind === "manifestRecord" || input.kind === "requireCurrentManifest") {
      fields = input.kind === "manifestRecord" ? ["recordHash"] : ["recordHash", "artistId"];
      normalized.recordHash = bytes(input.recordHash, 32); args = [normalized.recordHash];
      if (input.kind === "requireCurrentManifest") { normalized.artistId = bytes(input.artistId, 32); args = [...args, normalized.artistId]; }
    } else if (["outputProfile", "core", "contentCheckpoint", "artifactCoverage"].includes(input.kind)) fields = [];
    else throw Error("Unsupported output read");
  } else if (input.host === "producer") {
    target = address(input.target, true); normalized.target = target;
    if (input.kind === "preservationProfile" || input.kind === "preservationBinding") fields = ["target"];
    else if (input.kind === "preservationTokenJSON" || input.kind === "preservationTokenHTML") {
      fields = ["target", "tokenId"]; normalized.tokenId = uint(input.tokenId); args = [normalized.tokenId];
    } else throw Error("Unsupported producer read");
  } else if (input.host === "registry") {
    target = address(input.target, true); normalized.target = target;
    if (input.kind === "preservationRecord" || input.kind === "preservationReads") {
      fields = ["target", "key"]; normalized.key = bytes(input.key, 32); args = [normalized.key];
    } else if (input.kind === "preservationKey" || input.kind === "requirePreservation") {
      fields = ["target", "versionKey", "producer", "profile"];
      normalized.versionKey = bytes(input.versionKey, 32); normalized.producer = address(input.producer); normalized.profile = bytes(input.profile, 32);
      args = [normalized.versionKey, normalized.producer, normalized.profile];
    } else throw Error("Unsupported Registry read");
  } else throw Error("Unsupported read host");
  exact(input, ["host", "kind", ...fields]);
  const request = Object.freeze(normalized) as unknown as TokenPreservationOutputV2ReadRequest;
  return Object.freeze({ coordinates, request, call: Object.freeze({ to: target,
    data: bytes(tokenPreservationOutputV2Interface(input.host).encodeFunctionData(input.kind, args)), value: 0n }) });
}
export function normalizeTokenPreservationOutputV2Read(value: TokenPreservationOutputV2Read): TokenPreservationOutputV2Read {
  exact(value, ["coordinates", "request", "call"]);
  exact(value.call, ["to", "data", "value"]);
  const r = prepareTokenPreservationOutputV2Read(value.coordinates, value.request);
  same([address(value.call.to), bytes(value.call.data), uint(value.call.value)], [r.call.to, r.call.data, 0n], "Original output read");
  return r;
}

const SCHEMA_DOCUMENT = "{\"name\":\"STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2\",\"version\":2,\"profiles\":[\"6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2\",\"6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2\"],\"familyProfile\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2\",\"producerProfiles\":[\"6529STREAM_PRESERVATION_RENDER_V1\",\"6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1\"],\"outputProfile\":\"6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2\",\"format\":\"Solidity ABI\",\"scope\":\"Exact complete COLLECTION, TOKEN, RELEASE or SEASON checkpoint; VIEW and non-ONCHAIN modes refused\",\"rows\":\"Every IStreamPreservationPolicyContentCheckpointV1.Output in exact authoritative checkpoint order\",\"fields\":[\"StreamTokenContentLeaf(uint256 tokenId,bytes32 metadataHash,bytes32 imageHash,bytes32 animationHash,bytes32 contentHash,bytes32 tokenDataHash)\",\"bytes32 selectionRowHash\",\"bytes32 sourceFactsHash\",\"bytes32 htmlHash\",\"TokenReadiness(address coordinator,bytes32 coordinatorCodeHash,bytes32 policyHash,uint8 status,uint8 mode,uint8 securityClass,uint8 renderRequirement,bool terminal,bool finalized,bytes32 seed)\",\"bytes32 terminalAdmissionHash\",\"Binding(address producer,bytes32 producerCodeHash,bytes32 profile,address core,address metadataRouter,address liveRenderer,bytes32 liveRendererCodeHash,address attribution,bytes32 attributionCodeHash)\",\"Admission(address registry,bytes32 registryCodeHash,bytes32 versionKey,bytes32 registrationHash,bytes32 readSetHash,bytes32 analysisHash,bytes32 goldenHash)\"],\"projection\":\"Exact public preservationTokenJSON and preservationTokenHTML from the admitted producer. Only sanction lookup and derived displayed state, record hash and authority class are excluded. Existing live tokenURI remains separately readable and unchanged.\",\"preservedFacts\":\"All artwork, full executable code, media, token data, citation, C2PA, original entropy and non-sanction Artist facts remain in the canonical output.\",\"admission\":\"Every row binds the original selected Registry and version, complete governed preservation read roster, source analysis and executed golden vectors. Capability or constructor pins alone are insufficient.\",\"entropy\":\"Original coordinatorAtMint and complete frozen policy set; terminal rows require actual admitted terminal profile and zero seed; finalized rows require exact original native seed.\",\"preservation\":\"Hashes and source commitments only; complete output and source bytes, sanction and signature require separate exact archive coverage.\",\"current\":\"Every current read revalidates the complete original membership, policy set, selected configuration, producer binding and governed admission, then re-renders every completed row. No sampled freshness or immutable-currentness claim.\",\"authority\":\"Evidence only; original Artist consent, canonical root publication, snapshots, references and finality are independent obligations.\",\"producerSelection\":\"Each member supplies a producer admitted by its actual selected Registry/version for its exact saved token producer profile in the closed two-profile family. VIEW and unknown producer profiles are refused. The actual marker is retained without substitution. Currentness reuses the exact saved producer and complete pins; different members may select different admitted renderers. No member is omitted.\"}";
export const TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA_HASH = keccak256(toUtf8Bytes(SCHEMA_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA_BYTES = 3298n;

const CANONICALIZATION_DOCUMENT = "{\"name\":\"STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2\",\"version\":2,\"encoding\":\"abi.encode(bytes32 schemaId,uint256 chainId,address core,address checkpoint,bytes32 checkpointHash,bytes32 checkpointStateHash,address entropySourceSet,bytes32 inventoryHash,bytes32 policyChainHash,address metadataRouter,bytes32 preservationProfile,StreamFinalityScope scope,bytes32 contentRoot,bytes32 outputRoot,uint64 tokenCount,IStreamPreservationPolicyContentCheckpointV1.Output[] rows)\",\"schemaId\":\"keccak256(STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2)\",\"Binding\":\"address producer,bytes32 producerCodeHash,bytes32 profile,address core,address metadataRouter,address liveRenderer,bytes32 liveRendererCodeHash,address attribution,bytes32 attributionCodeHash\",\"checkpointStateHash\":\"keccak256(abi.encode(complete preservation Plan including fixed preservationProfile))\",\"scope\":\"uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId\",\"headBytes\":608,\"arrayOffset\":608,\"headerBytesIncludingArrayCount\":640,\"rowBytes\":1152,\"length\":\"640+1152*tokenCount\",\"arrayCount\":\"Exactly positive tokenCount\",\"words\":\"32-byte big-endian; addresses and narrow integers zero-extended; booleans exactly0or1\",\"trailingBytes\":\"Forbidden\",\"alternateOffsets\":\"Forbidden\",\"rowOrder\":\"Exact original checkpoint order, including every retained burned-token identity\",\"hash\":\"Keccak-256 of complete exact manifest bytes; not JCS\",\"preservationProfile\":\"keccak256(6529STREAM_TOKEN_PRESERVATION_FAMILY_V2); every row has either keccak256(6529STREAM_PRESERVATION_RENDER_V1) or keccak256(6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1) and the common Core/Router; VIEW and all other profiles are forbidden\"}";
export const TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION_HASH = keccak256(toUtf8Bytes(CANONICALIZATION_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION_BYTES = 1686n;

const LEAF_SCHEMA_DOCUMENT = "{\"name\":\"STREAM_PRESERVATION_POLICY_TOKEN_CONTENT_LEAF_V1\",\"version\":1,\"fields\":[\"uint256 tokenId\",\"bytes32 metadataHash\",\"bytes32 imageHash\",\"bytes32 animationHash\",\"bytes32 contentHash\",\"bytes32 tokenDataHash\"],\"encoding\":\"Original CMC ordered six-field content leaf/tree; no preimage change\",\"metadata\":\"Exact admitted preservationTokenJSON bytes, explicitly distinct from live Router tokenJSON and tokenURI\",\"animation\":\"Exact admitted preservationTokenHTML bytes; nonempty\",\"image\":\"Exact decoded admitted inline bytes; zero only if absent\",\"content\":\"No separate content asset in this finite profile; zero\",\"tokenData\":\"Exact retained Core tokenData bytes\",\"interpretation\":\"Only the ADR0054 sanction display projection is allowed; no JSON filtering, unavailable fallback or substitution of stale live facts\",\"admission\":\"Source and output interpretation are authenticated by the new manifest and each row's original governed preservation admission\",\"authority\":\"Leaf hash alone is not original root adoption, Artist consent, snapshot, archive coverage or finality\"}";
export const TOKEN_PRESERVATION_OUTPUT_V2_LEAF_SCHEMA_HASH = keccak256(toUtf8Bytes(LEAF_SCHEMA_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_OUTPUT_V2_LEAF_SCHEMA_BYTES = 1072n;

/** Frozen Solidity definition bytes, including their original lack of a final newline. */
export function tokenPreservationOutputV2Definition(documentId: Hex): Hex {
  const key = bytes(documentId, 32);
  const text = key === TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA ? SCHEMA_DOCUMENT
    : key === TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION ? CANONICALIZATION_DOCUMENT
    : key === TOKEN_PRESERVATION_OUTPUT_V2_LEAF_SCHEMA ? LEAF_SCHEMA_DOCUMENT : undefined;
  if (text === undefined) throw Error("Unknown preservation output definition");
  return hexlify(toUtf8Bytes(text)) as Hex;
}
