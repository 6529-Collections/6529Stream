import {
  AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress,
  id, isHexString, keccak256, toUtf8Bytes,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as graph from "./current-scoped-policy-graph-v2.js";

/** ABI129 original publication profile, separate from root adoption and finality. */
export const SCOPED_POLICY_PUBLICATION_V2_SOURCE = "896899f7ca4130f86e066587f780a3b1f755a25d";
export const SCOPED_POLICY_PUBLICATION_V2_CONTENT_PROFILE = id("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2") as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE = id("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2") as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA = id("STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2") as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION = id("STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2") as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_LEAF_SCHEMA = id("STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2") as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_SCHEMA = id("STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2") as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_DOCUMENT = id("STREAM_SCOPED_POLICY_SNAPSHOT_PROFILE_V2") as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_CANONICALIZATION = id("STREAM_ABI_SCOPED_POLICY_SNAPSHOT_V2") as Hex;
/** Hashes of the exact frozen definition documents, not of their identifier strings. */
export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_SCHEMA_HASH = "0xf2033babe894d0d330b7199fd63eb59f57e1314db0ae56df25b114c95eb43f16" as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_HASH = "0x2a9edb22fe6d8eb7105c2964dbcea97284c317242a3ee0c544dc04e6c3a4870b" as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_CANONICALIZATION_HASH = "0xef2fb02d8cfc42671a863fdf6d4b6d5e2ffa03f053ff9019898ec0711af289a0" as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_SCHEMA_BYTES = 3617n;
export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_BYTES = 1350n;
export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_CANONICALIZATION_BYTES = 970n;
export const SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA_HASH = "0x3da02284034c97434d39902a7be1caa63634ef047d86a2f5c228820ab037e7af" as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION_HASH = "0x800a07f2b4e3828dbaf086aaa07ef87d3beca398fded9d48dcdfe9a98819fcaa" as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_LEAF_SCHEMA_HASH = "0xb6cca3a753fb9cb049d4a401442a41ac58dce6738dae7921c7c77da29fcb1fbd" as Hex;
export const SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA_BYTES = 1608n;
export const SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION_BYTES = 1062n;
export const SCOPED_POLICY_PUBLICATION_V2_LEAF_SCHEMA_BYTES = 816n;
export const SCOPED_POLICY_PUBLICATION_V2_MAX_PAYLOAD_BYTES = 524288;
export const SCOPED_POLICY_PUBLICATION_V2_MAX_POLICIES = 630;
export const SCOPED_POLICY_PUBLICATION_V2_MAX_OUTPUTS = 818;
export const SCOPED_POLICY_PUBLICATION_V2_MAX_RENDER_BYTES = 16777216;
/** Client transport ceiling includes all four maximum original append payloads and ABI overhead. */
export const SCOPED_POLICY_PUBLICATION_V2_MAX_CALL_BYTES = 67125248;

export type ScopedPolicyPublicationV2Scope = graph.ScopedPolicyGraphV2Scope;
export type ScopedPolicyPublicationV2Dependencies = graph.ScopedPolicyGraphV2SnapshotDependencies;
export type ScopedPolicyPublicationV2Membership = graph.ScopedPolicyGraphV2Membership;
export type ScopedPolicyPublicationV2PolicyEvidence = graph.ScopedPolicyGraphV2PolicyEvidence;

export interface ScopedPolicyPublicationV2Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly metadata: Address;
  readonly checkpoint: Address;
  readonly output: Address;
  readonly snapshot: Address;
}

export interface ScopedPolicyPublicationV2SelectionPlan {
  readonly scope: ScopedPolicyPublicationV2Scope;
  readonly membershipHash: Hex;
  readonly collectionStateHash: Hex;
  readonly tokenCount: bigint;
  readonly nextIndex: bigint;
  readonly selectionRoot: Hex;
}

export interface ScopedPolicyPublicationV2RendererSelection {
  readonly registry: Address;
  readonly registryCodeHash: Hex;
  readonly versionKey: Hex;
  readonly renderer: Address;
  readonly rendererCodeHash: Hex;
  readonly rendererId: Hex;
  readonly rendererVersion: Hex;
  readonly contextVersion: Hex;
  readonly schemaHash: Hex;
  readonly readSetHash: Hex;
  readonly registrationHash: Hex;
}

export interface ScopedPolicyPublicationV2TokenSelection {
  readonly tokenId: bigint;
  readonly configRecordHash: Hex;
  readonly configHash: Hex;
  readonly sourceSnapshotHash: Hex;
  readonly rawSourceHash: Hex;
  readonly selection: ScopedPolicyPublicationV2RendererSelection;
  readonly sources: readonly [Address, Address, Address, Address, Address, Address];
  readonly sourceCodeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex];
}

export interface ScopedPolicyPublicationV2TokenReadiness {
  readonly coordinator: Address;
  readonly coordinatorCodeHash: Hex;
  readonly policyHash: Hex;
  readonly status: bigint;
  readonly mode: bigint;
  readonly securityClass: bigint;
  readonly renderRequirement: bigint;
  readonly terminal: boolean;
  readonly finalized: boolean;
  readonly seed: Hex;
}

export interface ScopedPolicyPublicationV2TerminalEvidence {
  readonly entropy: ScopedPolicyPublicationV2TokenReadiness;
  readonly configRecordHash: Hex;
  readonly versionKey: Hex;
  readonly renderer: Address;
  readonly rendererCodeHash: Hex;
  readonly registry: Address;
  readonly registryCodeHash: Hex;
  readonly admissionHash: Hex;
  readonly policyChainHash: Hex;
  readonly evidenceHash: Hex;
}

export interface ScopedPolicyPublicationV2Leaf {
  readonly tokenId: bigint;
  readonly metadataHash: Hex;
  readonly imageHash: Hex;
  readonly animationHash: Hex;
  readonly contentHash: Hex;
  readonly tokenDataHash: Hex;
}

export interface ScopedPolicyPublicationV2ContentPlan {
  readonly selectionId: Hex;
  readonly selectionHash: Hex;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly scope: ScopedPolicyPublicationV2Scope;
  readonly tokenCount: bigint;
  readonly nextIndex: bigint;
  readonly leafChainHash: Hex;
  readonly contentRoot: Hex;
  readonly outputRoot: Hex;
}

export interface ScopedPolicyPublicationV2Payload {
  readonly tokenId: bigint;
  readonly image: Hex;
  readonly animation: Hex;
}

export interface ScopedPolicyPublicationV2Output {
  readonly leaf: ScopedPolicyPublicationV2Leaf;
  readonly selectionRowHash: Hex;
  readonly sourceFactsHash: Hex;
  readonly htmlHash: Hex;
  readonly entropy: ScopedPolicyPublicationV2TokenReadiness;
  readonly terminalAdmissionHash: Hex;
}

export interface ScopedPolicyPublicationV2Manifest {
  readonly checkpointHash: Hex;
  readonly checkpointStateHash: Hex;
  readonly entropySourceSet: Address;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly artifactHash: Hex;
  readonly coverageHash: Hex;
  readonly artistId: Hex;
  readonly contentRoot: Hex;
  readonly outputRoot: Hex;
  readonly manifestHash: Hex;
  readonly scope: ScopedPolicyPublicationV2Scope;
  readonly tokenCount: bigint;
  readonly byteLength: bigint;
}

export interface ScopedPolicyPublicationV2OutputPlan {
  readonly manifest: ScopedPolicyPublicationV2Manifest;
  readonly nextIndex: bigint;
  readonly recordHash: Hex;
}

export interface ScopedPolicyPublicationV2ArtistPresentation {
  readonly locked: boolean;
  readonly registry: Address;
  readonly registryCodeHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly nominatedArtist: Address;
  readonly identityRecordHash: Hex;
  readonly acceptanceRecordHash: Hex;
  readonly acceptedAt: bigint;
  readonly lockedAt: bigint;
  readonly snapshotHash: Hex;
}

export interface ScopedPolicyPublicationV2Publication {
  readonly scope: ScopedPolicyPublicationV2Scope;
  readonly snapshotId: Hex;
  readonly expectedHead: Hex;
  readonly expectedRevision: bigint;
  readonly outputManifestRecord: Hex;
  readonly coordinatorInventoryPlan: Hex;
  readonly expectedSourceHash: Hex;
  readonly manifestURI: string;
  readonly effectiveAt: bigint;
  readonly reasonHash: Hex;
}

export interface ScopedPolicyPublicationV2Source {
  readonly scope: ScopedPolicyPublicationV2Scope;
  readonly membership: ScopedPolicyPublicationV2Membership;
  readonly artist: ScopedPolicyPublicationV2ArtistPresentation;
  readonly selection: ScopedPolicyPublicationV2SelectionPlan;
  readonly content: ScopedPolicyPublicationV2ContentPlan;
  readonly outputs: ScopedPolicyPublicationV2Manifest;
  readonly sourceFactory: Address;
  readonly sourceFactoryCodeHash: Hex;
  readonly factoryDependenciesHash: Hex;
  readonly entropy: ScopedPolicyPublicationV2PolicyEvidence;
}

export interface ScopedPolicyPublicationV2Receipt {
  readonly recordHash: Hex;
  readonly scopeSubject: Hex;
  readonly predecessor: Hex;
  readonly revision: bigint;
  readonly chainHash: Hex;
  readonly manifestHash: Hex;
  readonly manifestBytes: bigint;
  readonly sourceHash: Hex;
  readonly publisher: Address;
  readonly authorizationClass: bigint;
  readonly grantRevision: bigint;
  readonly displayAuthorizationClass: bigint;
  readonly displayGrantRevision: bigint;
  readonly recordedAt: bigint;
  readonly schemaHash: Hex;
  readonly profileHash: Hex;
  readonly canonicalizationHash: Hex;
}

export interface ScopedPolicyPublicationV2Lock {
  readonly recordHash: Hex;
  readonly revision: bigint;
  readonly actionId: Hex;
  readonly lockedAt: bigint;
}

export interface ScopedPolicyPublicationV2Coverage {
  readonly completionHash: Hex;
  readonly artifactHash: Hex;
  readonly artistId: Hex;
  readonly schemaId: Hex;
  readonly canonicalizationId: Hex;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
  readonly chunkCount: bigint;
  readonly firstFamilyRecordHash: Hex;
  readonly secondFamilyRecordHash: Hex;
  readonly validationEpoch: bigint;
  readonly evidenceChainHash: Hex;
}

export const SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE;
export const SCOPED_POLICY_PUBLICATION_V2_DEPENDENCIES_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_SNAPSHOT_DEPENDENCIES_TUPLE;
export const SCOPED_POLICY_PUBLICATION_V2_SELECTION_PLAN_TUPLE = `tuple(${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope,bytes32 membershipHash,bytes32 collectionStateHash,uint64 tokenCount,uint64 nextIndex,bytes32 selectionRoot)`;
export const SCOPED_POLICY_PUBLICATION_V2_RENDERER_SELECTION_TUPLE = "tuple(address registry,bytes32 registryCodeHash,bytes32 versionKey,address renderer,bytes32 rendererCodeHash,bytes32 rendererId,bytes32 rendererVersion,bytes32 contextVersion,bytes32 schemaHash,bytes32 readSetHash,bytes32 registrationHash)";
export const SCOPED_POLICY_PUBLICATION_V2_TOKEN_SELECTION_TUPLE = `tuple(uint256 tokenId,bytes32 configRecordHash,bytes32 configHash,bytes32 sourceSnapshotHash,bytes32 rawSourceHash,${SCOPED_POLICY_PUBLICATION_V2_RENDERER_SELECTION_TUPLE} selection,address[6] sources,bytes32[6] sourceCodeHashes)`;
export const SCOPED_POLICY_PUBLICATION_V2_TOKEN_READINESS_TUPLE = "tuple(address coordinator,bytes32 coordinatorCodeHash,bytes32 policyHash,uint8 status,uint8 mode,uint8 securityClass,uint8 renderRequirement,bool terminal,bool finalized,bytes32 seed)";
export const SCOPED_POLICY_PUBLICATION_V2_TERMINAL_EVIDENCE_TUPLE = `tuple(${SCOPED_POLICY_PUBLICATION_V2_TOKEN_READINESS_TUPLE} entropy,bytes32 configRecordHash,bytes32 versionKey,address renderer,bytes32 rendererCodeHash,address registry,bytes32 registryCodeHash,bytes32 admissionHash,bytes32 policyChainHash,bytes32 evidenceHash)`;
export const SCOPED_POLICY_PUBLICATION_V2_LEAF_TUPLE = "tuple(uint256 tokenId,bytes32 metadataHash,bytes32 imageHash,bytes32 animationHash,bytes32 contentHash,bytes32 tokenDataHash)";
export const SCOPED_POLICY_PUBLICATION_V2_CONTENT_PLAN_TUPLE = `tuple(bytes32 selectionId,bytes32 selectionHash,bytes32 inventoryHash,bytes32 policyChainHash,${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope,uint64 tokenCount,uint64 nextIndex,bytes32 leafChainHash,bytes32 contentRoot,bytes32 outputRoot)`;
export const SCOPED_POLICY_PUBLICATION_V2_PAYLOAD_TUPLE = "tuple(uint256 tokenId,bytes image,bytes animation)";
export const SCOPED_POLICY_PUBLICATION_V2_OUTPUT_TUPLE = `tuple(${SCOPED_POLICY_PUBLICATION_V2_LEAF_TUPLE} leaf,bytes32 selectionRowHash,bytes32 sourceFactsHash,bytes32 htmlHash,${SCOPED_POLICY_PUBLICATION_V2_TOKEN_READINESS_TUPLE} entropy,bytes32 terminalAdmissionHash)`;
export const SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE = `tuple(bytes32 checkpointHash,bytes32 checkpointStateHash,address entropySourceSet,bytes32 inventoryHash,bytes32 policyChainHash,bytes32 artifactHash,bytes32 coverageHash,bytes32 artistId,bytes32 contentRoot,bytes32 outputRoot,bytes32 manifestHash,${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope,uint64 tokenCount,uint64 byteLength)`;
export const SCOPED_POLICY_PUBLICATION_V2_OUTPUT_PLAN_TUPLE = `tuple(${SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE} manifest,uint64 nextIndex,bytes32 recordHash)`;
export const SCOPED_POLICY_PUBLICATION_V2_ARTIST_PRESENTATION_TUPLE = "tuple(bool locked,address registry,bytes32 registryCodeHash,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address nominatedArtist,bytes32 identityRecordHash,bytes32 acceptanceRecordHash,uint64 acceptedAt,uint64 lockedAt,bytes32 snapshotHash)";
export const SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE = `tuple(${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope,bytes32 snapshotId,bytes32 expectedHead,uint64 expectedRevision,bytes32 outputManifestRecord,bytes32 coordinatorInventoryPlan,bytes32 expectedSourceHash,string manifestURI,uint64 effectiveAt,bytes32 reasonHash)`;
export const SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE = `tuple(${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope,${graph.SCOPED_POLICY_GRAPH_V2_MEMBERSHIP_TUPLE} membership,${SCOPED_POLICY_PUBLICATION_V2_ARTIST_PRESENTATION_TUPLE} artist,${SCOPED_POLICY_PUBLICATION_V2_SELECTION_PLAN_TUPLE} selection,${SCOPED_POLICY_PUBLICATION_V2_CONTENT_PLAN_TUPLE} content,${SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE} outputs,address sourceFactory,bytes32 sourceFactoryCodeHash,bytes32 factoryDependenciesHash,${graph.SCOPED_POLICY_GRAPH_V2_POLICY_EVIDENCE_TUPLE} entropy)`;
export const SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE = "tuple(bytes32 recordHash,bytes32 scopeSubject,bytes32 predecessor,uint64 revision,bytes32 chainHash,bytes32 manifestHash,uint32 manifestBytes,bytes32 sourceHash,address publisher,uint8 authorizationClass,uint64 grantRevision,uint8 displayAuthorizationClass,uint64 displayGrantRevision,uint64 recordedAt,bytes32 schemaHash,bytes32 profileHash,bytes32 canonicalizationHash)";
export const SCOPED_POLICY_PUBLICATION_V2_LOCK_TUPLE = "tuple(bytes32 recordHash,uint64 revision,bytes32 actionId,uint64 lockedAt)";
export const SCOPED_POLICY_PUBLICATION_V2_COVERAGE_TUPLE = "tuple(bytes32 completionHash,bytes32 artifactHash,bytes32 artistId,bytes32 schemaId,bytes32 canonicalizationId,bytes32 contentHash,uint64 byteLength,uint32 chunkCount,bytes32 firstFamilyRecordHash,bytes32 secondFamilyRecordHash,uint64 validationEpoch,bytes32 evidenceChainHash)";

const coder = AbiCoder.defaultAbiCoder();

function exact(value: unknown, keys: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).length !== keys.length
    || Reflect.ownKeys(value).some(key => typeof key !== "string" || !keys.includes(key))) {
    throw Error(`${label}: missing or unknown fields`);
  }
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) throw Error(`Expected uint${bits} bigint`);
  return value;
}

function bytes(value: unknown, fixed?: number, maximum = SCOPED_POLICY_PUBLICATION_V2_MAX_CALL_BYTES): Hex {
  if (typeof value !== "string" || value.length % 2 !== 0 || !isHexString(value, fixed)
    || (value.length - 2) / 2 > maximum) throw Error("Invalid or oversized bytes");
  return value.toLowerCase() as Hex;
}

function nonzero(value: Hex): Hex {
  const normalized = bytes(value, 32);
  if (normalized === ZeroHash) throw Error("Expected nonzero commitment");
  return normalized;
}

function address(value: unknown, required = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const normalized = getAddress(value) as Address;
  if (required && normalized === ZeroAddress) throw Error("Expected nonzero address");
  return normalized;
}

function list(value: unknown, maximum: number, fixed?: number): readonly unknown[] {
  if (!Array.isArray(value) || value.length > maximum || (fixed !== undefined && value.length !== fixed)
    || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) {
    throw Error("Expected dense bounded array");
  }
  return value;
}

function text(value: unknown): string {
  if (typeof value !== "string" || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)
    || toUtf8Bytes(value).length > 2048) throw Error("Invalid UTF8 manifest URI or byte bound");
  return value;
}

function normalizeValue(type: ParamType, value: unknown, decoded = false): unknown {
  if (type.baseType === "tuple") {
    if (!decoded) exact(value, type.components!.map(field => field.name), "Tuple");
    return Object.freeze(Object.fromEntries(type.components!.map((field, index) => [field.name,
      normalizeValue(field, decoded ? (value as readonly unknown[])[index]
        : (value as Record<string, unknown>)[field.name], decoded)])));
  }
  if (type.baseType === "array") {
    const array = decoded ? Array.from(value as readonly unknown[]) : value;
    return Object.freeze(list(array, SCOPED_POLICY_PUBLICATION_V2_MAX_OUTPUTS,
      type.arrayLength! < 0 ? undefined : type.arrayLength!).map(row => normalizeValue(type.arrayChildren!, row, decoded)));
  }
  if (type.type.startsWith("uint")) {
    const n = uint(value, Number(type.type.slice(4)));
    if (type.name === "scopeType" && n > 4n) throw Error("Unknown scope enum");
    return n;
  }
  if (type.type.startsWith("bytes")) return bytes(value, type.type === "bytes" ? undefined : Number(type.type.slice(5)));
  if (type.type === "address") return address(value);
  if (type.type === "string") return text(value);
  if (type.type === "bool") {
    if (typeof value !== "boolean") throw Error("Expected boolean");
    return value;
  }
  throw Error(`Unsupported ABI type ${type.type}`);
}

function normalized<T>(tuple: string, value: unknown): T {
  return normalizeValue(ParamType.from(tuple), value) as T;
}

function encode(tuple: string, value: unknown, maximum = SCOPED_POLICY_PUBLICATION_V2_MAX_PAYLOAD_BYTES): Hex {
  return bytes(coder.encode([tuple], [normalized(tuple, value)]), undefined, maximum);
}

function decode<T>(tuple: string, value: Hex, maximum = SCOPED_POLICY_PUBLICATION_V2_MAX_PAYLOAD_BYTES): T {
  const raw = bytes(value, undefined, maximum);
  const result = normalizeValue(ParamType.from(tuple), coder.decode([tuple], raw)[0], true) as T;
  if (encode(tuple, result, maximum) !== raw) throw Error("Noncanonical ABI encoding");
  return result;
}

function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

function same(tuple: string, left: unknown, right: unknown): boolean {
  return encode(tuple, left) === encode(tuple, right);
}

export function normalizeScopedPolicyPublicationV2Coordinates(
  value: ScopedPolicyPublicationV2Coordinates,
): ScopedPolicyPublicationV2Coordinates {
  exact(value, ["chainId", "core", "metadata", "checkpoint", "output", "snapshot"], "Coordinates");
  return Object.freeze({ chainId: uint(value.chainId), core: address(value.core, true),
    metadata: address(value.metadata, true), checkpoint: address(value.checkpoint, true),
    output: address(value.output, true), snapshot: address(value.snapshot, true) });
}

export function normalizeScopedPolicyPublicationV2SelectionPlan(
  value: ScopedPolicyPublicationV2SelectionPlan,
): ScopedPolicyPublicationV2SelectionPlan {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_SELECTION_PLAN_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2SelectionPlan(value: ScopedPolicyPublicationV2SelectionPlan): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_SELECTION_PLAN_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2SelectionPlan(value: Hex): ScopedPolicyPublicationV2SelectionPlan {
  return decode(SCOPED_POLICY_PUBLICATION_V2_SELECTION_PLAN_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2RendererSelection(
  value: ScopedPolicyPublicationV2RendererSelection,
): ScopedPolicyPublicationV2RendererSelection {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_RENDERER_SELECTION_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2RendererSelection(value: ScopedPolicyPublicationV2RendererSelection): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_RENDERER_SELECTION_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2RendererSelection(value: Hex): ScopedPolicyPublicationV2RendererSelection {
  return decode(SCOPED_POLICY_PUBLICATION_V2_RENDERER_SELECTION_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2TokenSelection(
  value: ScopedPolicyPublicationV2TokenSelection,
): ScopedPolicyPublicationV2TokenSelection {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_TOKEN_SELECTION_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2TokenSelection(value: ScopedPolicyPublicationV2TokenSelection): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_TOKEN_SELECTION_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2TokenSelection(value: Hex): ScopedPolicyPublicationV2TokenSelection {
  return decode(SCOPED_POLICY_PUBLICATION_V2_TOKEN_SELECTION_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2TokenReadiness(
  value: ScopedPolicyPublicationV2TokenReadiness,
): ScopedPolicyPublicationV2TokenReadiness {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_TOKEN_READINESS_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2TokenReadiness(value: ScopedPolicyPublicationV2TokenReadiness): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_TOKEN_READINESS_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2TokenReadiness(value: Hex): ScopedPolicyPublicationV2TokenReadiness {
  return decode(SCOPED_POLICY_PUBLICATION_V2_TOKEN_READINESS_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2TerminalEvidence(
  value: ScopedPolicyPublicationV2TerminalEvidence,
): ScopedPolicyPublicationV2TerminalEvidence {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_TERMINAL_EVIDENCE_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2TerminalEvidence(value: ScopedPolicyPublicationV2TerminalEvidence): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_TERMINAL_EVIDENCE_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2TerminalEvidence(value: Hex): ScopedPolicyPublicationV2TerminalEvidence {
  return decode(SCOPED_POLICY_PUBLICATION_V2_TERMINAL_EVIDENCE_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2Leaf(
  value: ScopedPolicyPublicationV2Leaf,
): ScopedPolicyPublicationV2Leaf {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_LEAF_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2Leaf(value: ScopedPolicyPublicationV2Leaf): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_LEAF_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2Leaf(value: Hex): ScopedPolicyPublicationV2Leaf {
  return decode(SCOPED_POLICY_PUBLICATION_V2_LEAF_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2ContentPlan(
  value: ScopedPolicyPublicationV2ContentPlan,
): ScopedPolicyPublicationV2ContentPlan {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_CONTENT_PLAN_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2ContentPlan(value: ScopedPolicyPublicationV2ContentPlan): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_CONTENT_PLAN_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2ContentPlan(value: Hex): ScopedPolicyPublicationV2ContentPlan {
  return decode(SCOPED_POLICY_PUBLICATION_V2_CONTENT_PLAN_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2Payload(
  value: ScopedPolicyPublicationV2Payload,
): ScopedPolicyPublicationV2Payload {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_PAYLOAD_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2Payload(value: ScopedPolicyPublicationV2Payload): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_PAYLOAD_TUPLE, value, SCOPED_POLICY_PUBLICATION_V2_MAX_CALL_BYTES);
}

export function decodeScopedPolicyPublicationV2Payload(value: Hex): ScopedPolicyPublicationV2Payload {
  return decode(SCOPED_POLICY_PUBLICATION_V2_PAYLOAD_TUPLE, value, SCOPED_POLICY_PUBLICATION_V2_MAX_CALL_BYTES);
}

export function normalizeScopedPolicyPublicationV2Output(
  value: ScopedPolicyPublicationV2Output,
): ScopedPolicyPublicationV2Output {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_OUTPUT_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2Output(value: ScopedPolicyPublicationV2Output): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_OUTPUT_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2Output(value: Hex): ScopedPolicyPublicationV2Output {
  return decode(SCOPED_POLICY_PUBLICATION_V2_OUTPUT_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2Manifest(
  value: ScopedPolicyPublicationV2Manifest,
): ScopedPolicyPublicationV2Manifest {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2Manifest(value: ScopedPolicyPublicationV2Manifest): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2Manifest(value: Hex): ScopedPolicyPublicationV2Manifest {
  return decode(SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2OutputPlan(
  value: ScopedPolicyPublicationV2OutputPlan,
): ScopedPolicyPublicationV2OutputPlan {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_OUTPUT_PLAN_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2OutputPlan(value: ScopedPolicyPublicationV2OutputPlan): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_OUTPUT_PLAN_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2OutputPlan(value: Hex): ScopedPolicyPublicationV2OutputPlan {
  return decode(SCOPED_POLICY_PUBLICATION_V2_OUTPUT_PLAN_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2ArtistPresentation(
  value: ScopedPolicyPublicationV2ArtistPresentation,
): ScopedPolicyPublicationV2ArtistPresentation {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_ARTIST_PRESENTATION_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2ArtistPresentation(value: ScopedPolicyPublicationV2ArtistPresentation): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_ARTIST_PRESENTATION_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2ArtistPresentation(value: Hex): ScopedPolicyPublicationV2ArtistPresentation {
  return decode(SCOPED_POLICY_PUBLICATION_V2_ARTIST_PRESENTATION_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2Publication(
  value: ScopedPolicyPublicationV2Publication,
): ScopedPolicyPublicationV2Publication {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2Publication(value: ScopedPolicyPublicationV2Publication): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2Publication(value: Hex): ScopedPolicyPublicationV2Publication {
  return decode(SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2Source(
  value: ScopedPolicyPublicationV2Source,
): ScopedPolicyPublicationV2Source {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2Source(value: ScopedPolicyPublicationV2Source): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2Source(value: Hex): ScopedPolicyPublicationV2Source {
  return decode(SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2Receipt(
  value: ScopedPolicyPublicationV2Receipt,
): ScopedPolicyPublicationV2Receipt {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2Receipt(value: ScopedPolicyPublicationV2Receipt): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2Receipt(value: Hex): ScopedPolicyPublicationV2Receipt {
  return decode(SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2Lock(
  value: ScopedPolicyPublicationV2Lock,
): ScopedPolicyPublicationV2Lock {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_LOCK_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2Lock(value: ScopedPolicyPublicationV2Lock): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_LOCK_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2Lock(value: Hex): ScopedPolicyPublicationV2Lock {
  return decode(SCOPED_POLICY_PUBLICATION_V2_LOCK_TUPLE, value);
}

export function normalizeScopedPolicyPublicationV2Coverage(
  value: ScopedPolicyPublicationV2Coverage,
): ScopedPolicyPublicationV2Coverage {
  return normalized(SCOPED_POLICY_PUBLICATION_V2_COVERAGE_TUPLE, value);
}

export function encodeScopedPolicyPublicationV2Coverage(value: ScopedPolicyPublicationV2Coverage): Hex {
  return encode(SCOPED_POLICY_PUBLICATION_V2_COVERAGE_TUPLE, value);
}

export function decodeScopedPolicyPublicationV2Coverage(value: Hex): ScopedPolicyPublicationV2Coverage {
  return decode(SCOPED_POLICY_PUBLICATION_V2_COVERAGE_TUPLE, value);
}

export const SCOPED_POLICY_PUBLICATION_V2_CHECKPOINT_ABI = Object.freeze([
  "function begin(bytes32 selectionId,bytes32 salt) returns (bytes32 id)",
  `function append(bytes32 id,${SCOPED_POLICY_PUBLICATION_V2_PAYLOAD_TUPLE}[] payloads)`,
  `function checkpoint(bytes32 id) view returns (${SCOPED_POLICY_PUBLICATION_V2_CONTENT_PLAN_TUPLE})`,
  `function outputAt(bytes32 id,uint256 index) view returns (${SCOPED_POLICY_PUBLICATION_V2_OUTPUT_TUPLE})`,
  `function requireCurrentCheckpoint(bytes32 id) view returns (${SCOPED_POLICY_PUBLICATION_V2_CONTENT_PLAN_TUPLE})`,
  "function scopedPolicyProfile() pure returns (bytes32)",
  ...["core", "metadataRouter", "selectionCheckpoint", "entropySourceSet", "terminalReadiness", "sourceFactory"]
    .map(method => `function ${method}() view returns (address)`),
  ...["coreCodeHash", "routerCodeHash", "selectionCodeHash", "entropySourceSetCodeHash",
    "terminalReadinessCodeHash", "sourceFactoryCodeHash", "factoryDependenciesHash"]
    .map(method => `function ${method}() view returns (bytes32)`),
  "function deploymentChainId() view returns (uint256)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  `event StaticContentStarted(uint16 schemaVersion,bytes32 indexed id,bytes32 salt,${SCOPED_POLICY_PUBLICATION_V2_CONTENT_PLAN_TUPLE} plan)`,
  `event StaticContentAppended(uint16 schemaVersion,bytes32 indexed id,uint64 indexed index,${SCOPED_POLICY_PUBLICATION_V2_OUTPUT_TUPLE} output,bytes32 leafHash)`,
  "event StaticContentCompleted(uint16 schemaVersion,bytes32 indexed id,bytes32 contentRoot,bytes32 outputRoot,uint64 count)",
]);

export const SCOPED_POLICY_PUBLICATION_V2_OUTPUT_ABI = Object.freeze([
  "function beginManifest(bytes32 checkpointHash,bytes32 artifactHash,bytes32 coverageHash,bytes32 artistId) returns (bytes32 planHash)",
  "function verifyNextOutputs(bytes32 planHash,uint256 count) returns (bytes32 recordHash)",
  `function manifestPlan(bytes32 planHash) view returns (${SCOPED_POLICY_PUBLICATION_V2_OUTPUT_PLAN_TUPLE})`,
  `function manifestRecord(bytes32 recordHash) view returns (${SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE})`,
  `function requireCurrentManifest(bytes32 recordHash,bytes32 artistId) view returns (${SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE} m)`,
  "function outputProfile() pure returns (bytes32)",
  "function scopedOutputProfile() pure returns (bytes32)",
  ...["core", "contentCheckpoint", "artifactCoverage", "schemaRegistry"]
    .map(method => `function ${method}() view returns (address)`),
  ...["checkpointCodeHash", "coverageCodeHash", "schemaCodeHash"]
    .map(method => `function ${method}() view returns (bytes32)`),
  "function deploymentChainId() view returns (uint256)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  `event OutputManifestStarted(uint16 schemaVersion,bytes32 indexed planHash,${SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE} manifest)`,
  "event OutputManifestAdvanced(uint16 schemaVersion,bytes32 indexed planHash,uint64 firstIndex,uint64 nextIndex)",
  `event OutputManifestVerified(uint16 schemaVersion,bytes32 indexed recordHash,bytes32 indexed planHash,${SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE} manifest)`,
]);

export const SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_ABI = Object.freeze([
  `function previewSnapshot(${SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE} p,address publisher) view returns (bytes32 sourceHash,bytes canonical)`,
  `function publishSnapshot(${SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE} p) returns (bytes32 hash)`,
  `function dependencies() view returns (${SCOPED_POLICY_PUBLICATION_V2_DEPENDENCIES_TUPLE} d)`,
  `function currentSnapshot(${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope) view returns (${SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE})`,
  `function snapshotRecord(bytes32 hash) view returns (${SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE},${SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE})`,
  "function snapshotPayload(bytes32 hash) view returns (bytes)",
  `function snapshotCount(${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope) view returns (uint256)`,
  `function snapshotAt(${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope,uint256 index) view returns (bytes32)`,
  `function snapshotLock(${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope) view returns (${SCOPED_POLICY_PUBLICATION_V2_LOCK_TUPLE})`,
  `function requireCurrent(${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope,bytes32 hash,uint64 revision) view returns (${SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE} r)`,
  "function scopedPolicySnapshotProfile() pure returns (bytes32)",
  "function core() view returns (address)",
  "function metadataHost() view returns (address)",
  "function authorityCodeHash() view returns (bytes32)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  `event ScopedPolicySnapshotPublished(uint16 schemaVersion,bytes32 indexed scopeSubject,bytes32 indexed snapshotId,bytes32 indexed recordHash,${SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE} publication,${SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE} receipt)`,
]);

export type ScopedPolicyPublicationV2Host = "checkpoint" | "output" | "snapshot";

export function scopedPolicyPublicationV2Interface(host: ScopedPolicyPublicationV2Host): Interface {
  if (host === "checkpoint") return new Interface(SCOPED_POLICY_PUBLICATION_V2_CHECKPOINT_ABI);
  if (host === "output") return new Interface(SCOPED_POLICY_PUBLICATION_V2_OUTPUT_ABI);
  if (host === "snapshot") return new Interface(SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_ABI);
  throw Error("Unknown publication host");
}

export interface ScopedPolicyPublicationV2CheckpointIdentity {
  readonly selectionCheckpoint: Address;
  readonly selectionId: Hex;
  readonly selection: ScopedPolicyPublicationV2SelectionPlan;
  readonly entropySourceSet: Address;
  readonly entropySourceSetCodeHash: Hex;
  readonly terminalReadiness: Address;
  readonly terminalReadinessCodeHash: Hex;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly salt: Hex;
}

export function scopedPolicyPublicationV2CheckpointId(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  identity: ScopedPolicyPublicationV2CheckpointIdentity,
): Hex {
  exact(identity, ["selectionCheckpoint", "selectionId", "selection", "entropySourceSet", "entropySourceSetCodeHash",
    "terminalReadiness", "terminalReadinessCodeHash", "inventoryHash", "policyChainHash", "salt"], "Checkpoint identity");
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  const selected = normalizeScopedPolicyPublicationV2SelectionPlan(identity.selection);
  return hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "address",
    "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32"],
  [SCOPED_POLICY_PUBLICATION_V2_CONTENT_PROFILE, c.chainId, c.checkpoint, address(identity.selectionCheckpoint),
    bytes(identity.selectionId, 32), keccak256(encodeScopedPolicyPublicationV2SelectionPlan(selected)),
    address(identity.entropySourceSet), bytes(identity.entropySourceSetCodeHash, 32), address(identity.terminalReadiness),
    bytes(identity.terminalReadinessCodeHash, 32), bytes(identity.inventoryHash, 32), bytes(identity.policyChainHash, 32), bytes(identity.salt, 32)]);
}

export function scopedPolicyPublicationV2InitialContentPlan(
  identity: ScopedPolicyPublicationV2CheckpointIdentity,
): ScopedPolicyPublicationV2ContentPlan {
  exact(identity, ["selectionCheckpoint", "selectionId", "selection", "entropySourceSet", "entropySourceSetCodeHash",
    "terminalReadiness", "terminalReadinessCodeHash", "inventoryHash", "policyChainHash", "salt"], "Checkpoint identity");
  address(identity.selectionCheckpoint, true);
  address(identity.entropySourceSet, true);
  address(identity.terminalReadiness, true);
  nonzero(identity.entropySourceSetCodeHash);
  nonzero(identity.terminalReadinessCodeHash);
  bytes(identity.salt, 32);
  const s = normalizeScopedPolicyPublicationV2SelectionPlan(identity.selection);
  graph.validateScopedPolicyGraphV2Scope(s.scope);
  if (s.tokenCount === 0n || s.nextIndex !== s.tokenCount || s.selectionRoot === ZeroHash) throw Error("Selection must be complete");
  return normalizeScopedPolicyPublicationV2ContentPlan({ selectionId: nonzero(identity.selectionId),
    selectionHash: keccak256(encodeScopedPolicyPublicationV2SelectionPlan(s)) as Hex,
    inventoryHash: nonzero(identity.inventoryHash), policyChainHash: nonzero(identity.policyChainHash), scope: s.scope,
    tokenCount: s.tokenCount, nextIndex: 0n, leafChainHash: ZeroHash as Hex, contentRoot: ZeroHash as Hex, outputRoot: ZeroHash as Hex });
}

export function scopedPolicyPublicationV2LeafHash(chainId: bigint, core: Address, leaf: ScopedPolicyPublicationV2Leaf): Hex {
  const l = normalizeScopedPolicyPublicationV2Leaf(leaf);
  return hash(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    ["0x61d75cd1a57d24657b860f99f77c15e5f8556fb725b56a96dd770205f9352b0d", uint(chainId), address(core),
      l.tokenId, l.metadataHash, l.imageHash, l.animationHash, l.contentHash, l.tokenDataHash]);
}

export function scopedPolicyPublicationV2NodeHash(left: Hex, right: Hex): Hex {
  return hash(["bytes32", "bytes32", "bytes32"],
    ["0x7239fc0713b7ccc92b7eef3087150a1f32037aff6ab05f5bf78db4f8ab71a6ea", bytes(left, 32), bytes(right, 32)]);
}

/** Ordered tree: no sorting or duplicate-last-node padding. */
export function scopedPolicyPublicationV2ContentRoot(
  chainId: bigint,
  core: Address,
  leaves: readonly ScopedPolicyPublicationV2Leaf[],
): Hex {
  const rows = list(leaves, SCOPED_POLICY_PUBLICATION_V2_MAX_OUTPUTS).map(row => normalizeScopedPolicyPublicationV2Leaf(row as ScopedPolicyPublicationV2Leaf));
  if (rows.length === 0) throw Error("Empty content tree");
  let level = rows.map((leaf, i) => {
    if (leaf.tokenId === 0n || leaf.metadataHash === ZeroHash || (i > 0 && leaf.tokenId <= rows[i - 1]!.tokenId)) {
      throw Error("Invalid ordered content leaves");
    }
    return scopedPolicyPublicationV2LeafHash(chainId, core, leaf);
  });
  while (level.length > 1) {
    const next: Hex[] = [];
    for (let i = 0; i < level.length; i += 2) next.push(i + 1 === level.length ? level[i]! : scopedPolicyPublicationV2NodeHash(level[i]!, level[i + 1]!));
    level = next;
  }
  return level[0]!;
}

export function scopedPolicyPublicationV2LeafChain(previous: Hex, index: bigint, leafHash: Hex): Hex {
  return hash(["bytes32", "bytes32", "uint256", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_CONTENT_LEAVES_V2"), bytes(previous, 32), uint(index), bytes(leafHash, 32)]);
}

export function scopedPolicyPublicationV2OutputChain(previous: Hex, index: bigint, output: ScopedPolicyPublicationV2Output): Hex {
  return hash(["bytes32", "bytes32", "uint256", SCOPED_POLICY_PUBLICATION_V2_OUTPUT_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_FULL_OUTPUTS_V2"), bytes(previous, 32), uint(index), normalizeScopedPolicyPublicationV2Output(output)]);
}

export function scopedPolicyPublicationV2SelectionRowHash(
  chainId: bigint,
  core: Address,
  router: Address,
  row: ScopedPolicyPublicationV2TokenSelection,
): Hex {
  return hash(["bytes32", "uint256", "address", "address", SCOPED_POLICY_PUBLICATION_V2_TOKEN_SELECTION_TUPLE],
    [id("6529STREAM_STATIC_SELECTION_ROW_V1"), uint(chainId), address(core), address(router), normalizeScopedPolicyPublicationV2TokenSelection(row)]);
}

export interface ScopedPolicyPublicationV2SourceFacts {
  readonly configHash: Hex;
  readonly rawSourceHash: Hex;
  readonly coordinator: Address;
  readonly entropy: ScopedPolicyPublicationV2TokenReadiness;
  readonly entropySourceSet: Address;
  readonly entropySourceSetCodeHash: Hex;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly terminalReadiness: Address;
  readonly terminalReadinessCodeHash: Hex;
  readonly terminalAdmissionHash: Hex;
}

export function scopedPolicyPublicationV2SourceFactsHash(value: ScopedPolicyPublicationV2SourceFacts): Hex {
  exact(value, ["configHash", "rawSourceHash", "coordinator", "entropy", "entropySourceSet", "entropySourceSetCodeHash",
    "inventoryHash", "policyChainHash", "terminalReadiness", "terminalReadinessCodeHash", "terminalAdmissionHash"], "Source facts");
  return hash(["bytes32", "bytes32", "bytes32", "address", "bytes", "address", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32"],
    [SCOPED_POLICY_PUBLICATION_V2_CONTENT_PROFILE, bytes(value.configHash, 32), bytes(value.rawSourceHash, 32), address(value.coordinator),
      encodeScopedPolicyPublicationV2TokenReadiness(value.entropy), address(value.entropySourceSet), bytes(value.entropySourceSetCodeHash, 32),
      bytes(value.inventoryHash, 32), bytes(value.policyChainHash, 32), address(value.terminalReadiness), bytes(value.terminalReadinessCodeHash, 32), bytes(value.terminalAdmissionHash, 32)]);
}

export function validateScopedPolicyPublicationV2Output(value: ScopedPolicyPublicationV2Output): ScopedPolicyPublicationV2Output {
  const output = normalizeScopedPolicyPublicationV2Output(value);
  const e = output.entropy;
  address(e.coordinator, true); nonzero(e.coordinatorCodeHash); nonzero(e.policyHash);
  if (output.leaf.tokenId === 0n || output.leaf.metadataHash === ZeroHash || output.leaf.animationHash === ZeroHash
    || output.leaf.contentHash !== ZeroHash || output.htmlHash !== output.leaf.animationHash
    || output.selectionRowHash === ZeroHash || output.sourceFactsHash === ZeroHash) throw Error("Invalid supplied output commitments");
  if (e.terminal) {
    if (e.finalized || e.seed !== ZeroHash || e.renderRequirement !== 1n
      || !((e.status === 1n && e.mode === 0n) || (e.status === 2n && e.mode === 2n))
      || output.terminalAdmissionHash === ZeroHash) throw Error("Invalid terminal output");
  } else if (!e.finalized || e.status !== 5n || e.mode !== 2n || e.renderRequirement !== 0n
    || output.terminalAdmissionHash !== ZeroHash) throw Error("Invalid finalized output");
  return output;
}

export interface ScopedPolicyPublicationV2OutputManifestBytes {
  readonly schemaId: Hex;
  readonly chainId: bigint;
  readonly core: Address;
  readonly checkpoint: Address;
  readonly checkpointHash: Hex;
  readonly checkpointStateHash: Hex;
  readonly entropySourceSet: Address;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly scope: ScopedPolicyPublicationV2Scope;
  readonly contentRoot: Hex;
  readonly outputRoot: Hex;
  readonly tokenCount: bigint;
  readonly rows: readonly ScopedPolicyPublicationV2Output[];
}

/** Flat original abi.encode arguments; this is not an outer dynamic tuple wrapper. */
const outputFields = [
  "bytes32 schemaId", "uint256 chainId", "address core", "address checkpoint", "bytes32 checkpointHash",
  "bytes32 checkpointStateHash", "address entropySourceSet", "bytes32 inventoryHash", "bytes32 policyChainHash",
  `${SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE} scope`, "bytes32 contentRoot", "bytes32 outputRoot", "uint64 tokenCount",
  `${SCOPED_POLICY_PUBLICATION_V2_OUTPUT_TUPLE}[] rows`,
];

function flatEncode(fields: readonly string[], value: unknown, maximum: number): Hex {
  const types = fields.map(field => ParamType.from(field));
  exact(value, types.map(type => type.name), "Flat payload");
  return bytes(coder.encode(types, types.map(type => normalizeValue(type, value[type.name]))), undefined, maximum);
}

function flatDecode<T>(fields: readonly string[], value: Hex, maximum: number): T {
  const raw = bytes(value, undefined, maximum);
  const types = fields.map(field => ParamType.from(field));
  const decoded = coder.decode(types, raw);
  const result = Object.freeze(Object.fromEntries(types.map((type, i) => [type.name, normalizeValue(type, decoded[i], true)]))) as T;
  if (flatEncode(fields, result, maximum) !== raw) throw Error("Noncanonical flat ABI payload");
  return result;
}

export function scopedPolicyPublicationV2OutputManifestBytes(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  checkpointHash: Hex,
  content: ScopedPolicyPublicationV2ContentPlan,
  entropySourceSet: Address,
  outputs: readonly ScopedPolicyPublicationV2Output[],
): Hex {
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  const p = normalizeScopedPolicyPublicationV2ContentPlan(content);
  graph.validateScopedPolicyGraphV2Scope(p.scope);
  const rows = list(outputs, SCOPED_POLICY_PUBLICATION_V2_MAX_OUTPUTS)
    .map(row => validateScopedPolicyPublicationV2Output(row as ScopedPolicyPublicationV2Output));
  if (p.tokenCount === 0n || p.nextIndex !== p.tokenCount || BigInt(rows.length) !== p.tokenCount
    || (p.scope.scopeType === 1n && p.tokenCount !== 1n)) throw Error("Incomplete output manifest inventory");
  const contentRoot = scopedPolicyPublicationV2ContentRoot(c.chainId, c.core, rows.map(row => row.leaf));
  let outputRoot = ZeroHash as Hex;
  let leafChain = ZeroHash as Hex;
  rows.forEach((row, i) => {
    outputRoot = scopedPolicyPublicationV2OutputChain(outputRoot, BigInt(i), row);
    leafChain = scopedPolicyPublicationV2LeafChain(leafChain, BigInt(i), scopedPolicyPublicationV2LeafHash(c.chainId, c.core, row.leaf));
  });
  if (p.contentRoot !== contentRoot || p.outputRoot !== outputRoot || p.leafChainHash !== leafChain) {
    throw Error("Output roots do not match complete rows");
  }
  return flatEncode(outputFields, { schemaId: SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA, chainId: c.chainId,
    core: c.core, checkpoint: c.checkpoint, checkpointHash: nonzero(checkpointHash),
    checkpointStateHash: keccak256(encodeScopedPolicyPublicationV2ContentPlan(p)), entropySourceSet: address(entropySourceSet, true),
    inventoryHash: nonzero(p.inventoryHash), policyChainHash: nonzero(p.policyChainHash), scope: p.scope,
    contentRoot, outputRoot, tokenCount: p.tokenCount, rows }, SCOPED_POLICY_PUBLICATION_V2_MAX_PAYLOAD_BYTES);
}

export function decodeScopedPolicyPublicationV2OutputManifestBytes(value: Hex): ScopedPolicyPublicationV2OutputManifestBytes {
  const result = flatDecode<ScopedPolicyPublicationV2OutputManifestBytes>(outputFields, value, SCOPED_POLICY_PUBLICATION_V2_MAX_PAYLOAD_BYTES);
  graph.validateScopedPolicyGraphV2Scope(result.scope);
  if (result.schemaId !== SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA || result.tokenCount === 0n
    || result.tokenCount !== BigInt(result.rows.length) || (result.scope.scopeType === 1n && result.tokenCount !== 1n)
    || (value.length - 2) / 2 !== 576 + 640 * result.rows.length) throw Error("Invalid canonical output manifest header");
  return result;
}

export function scopedPolicyPublicationV2Manifest(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  checkpointHash: Hex,
  content: ScopedPolicyPublicationV2ContentPlan,
  entropySourceSet: Address,
  coverage: ScopedPolicyPublicationV2Coverage,
): ScopedPolicyPublicationV2Manifest {
  normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  const p = normalizeScopedPolicyPublicationV2ContentPlan(content);
  const c = normalizeScopedPolicyPublicationV2Coverage(coverage);
  graph.validateScopedPolicyGraphV2Scope(p.scope);
  const length = 576n + 640n * p.tokenCount;
  if (p.tokenCount === 0n || p.nextIndex !== p.tokenCount || (p.scope.scopeType === 1n && p.tokenCount !== 1n)
    || p.contentRoot === ZeroHash || p.outputRoot === ZeroHash || length > BigInt(SCOPED_POLICY_PUBLICATION_V2_MAX_PAYLOAD_BYTES)
    || c.schemaId !== SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA || c.canonicalizationId !== SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION
    || c.byteLength !== length || c.chunkCount !== (length + 8191n) / 8192n
    || c.firstFamilyRecordHash === ZeroHash || c.secondFamilyRecordHash === ZeroHash
    || c.firstFamilyRecordHash === c.secondFamilyRecordHash) throw Error("Invalid supplied covered output facts");
  return normalizeScopedPolicyPublicationV2Manifest({ checkpointHash: nonzero(checkpointHash),
    checkpointStateHash: keccak256(encodeScopedPolicyPublicationV2ContentPlan(p)) as Hex,
    entropySourceSet: address(entropySourceSet, true), inventoryHash: p.inventoryHash, policyChainHash: p.policyChainHash,
    artifactHash: nonzero(c.artifactHash), coverageHash: nonzero(c.completionHash), artistId: nonzero(c.artistId),
    contentRoot: p.contentRoot, outputRoot: p.outputRoot, manifestHash: nonzero(c.contentHash), scope: p.scope,
    tokenCount: p.tokenCount, byteLength: length });
}

export function scopedPolicyPublicationV2ManifestPlanHash(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  artifactCoverage: Address,
  manifest: ScopedPolicyPublicationV2Manifest,
): Hex {
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", "address", "address", SCOPED_POLICY_PUBLICATION_V2_MANIFEST_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_PLAN_V2"), c.chainId, c.output, c.core, c.checkpoint,
      address(artifactCoverage), normalizeScopedPolicyPublicationV2Manifest(manifest)]);
}

export function scopedPolicyPublicationV2ManifestRecordHash(planHash: Hex): Hex {
  return hash(["bytes32", "bytes32"], [id("6529STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_VERIFIED_V2"), bytes(planHash, 32)]);
}

export function scopedPolicyPublicationV2SourceHash(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  dependencies: ScopedPolicyPublicationV2Dependencies,
  source: ScopedPolicyPublicationV2Source,
): Hex {
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  const d = graph.normalizeScopedPolicyGraphV2SnapshotDependencies(dependencies);
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.targets[1] !== c.metadata) throw Error("Snapshot coordinates/dependencies mismatch");
  return hash(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"), c.chainId, c.snapshot, d.targets, d.codeHashes,
      normalizeScopedPolicyPublicationV2Source(source)]);
}

/** Original joins visible in the complete Source tuple. Live route/coverage/renderer checks remain on-chain. */
export function validateScopedPolicyPublicationV2Source(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  dependencies: ScopedPolicyPublicationV2Dependencies,
  publication: ScopedPolicyPublicationV2Publication,
  source: ScopedPolicyPublicationV2Source,
): ScopedPolicyPublicationV2Source {
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  const d = graph.normalizeScopedPolicyGraphV2SnapshotDependencies(dependencies);
  const p = normalizeScopedPolicyPublicationV2Publication(publication);
  const f = normalizeScopedPolicyPublicationV2Source(source);
  graph.validateScopedPolicyGraphV2Scope(p.scope);
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.targets[1] !== c.metadata
    || d.targets[7] !== c.checkpoint || d.targets[8] !== c.output
    || !same(SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE, f.scope, p.scope)
    || f.membership.scopeSubject !== graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, p.scope)
    || f.membership.membershipHash === ZeroHash || f.membership.tokenCount === 0n
    || f.membership.tokenCount > 0xffffffffffffffffn) throw Error("Snapshot source membership/dependency mismatch");
  const artist = f.artist;
  if (!artist.locked || artist.artistId === ZeroHash || artist.snapshotHash === ZeroHash
    || artist.registry === ZeroAddress || artist.registryCodeHash === ZeroHash || artist.bindingGeneration === 0n
    || artist.bindingHash === ZeroHash || artist.identityRecordHash === ZeroHash || artist.acceptanceRecordHash === ZeroHash
    || artist.nominatedArtist === ZeroAddress || artist.acceptedAt === 0n || artist.lockedAt === 0n) throw Error("Artist presentation must be locked");
  const o = f.outputs, content = f.content, selected = f.selection, entropy = f.entropy;
  const outputRecord = scopedPolicyPublicationV2ManifestRecordHash(
    scopedPolicyPublicationV2ManifestPlanHash(c, d.targets[9], o),
  );
  if (p.outputManifestRecord !== outputRecord || o.artistId !== artist.artistId
    || !same(SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE, o.scope, p.scope)
    || o.tokenCount !== f.membership.tokenCount || o.contentRoot === ZeroHash || o.outputRoot === ZeroHash
    || o.manifestHash === ZeroHash || o.checkpointStateHash !== keccak256(encodeScopedPolicyPublicationV2ContentPlan(content))
    || content.tokenCount !== f.membership.tokenCount || content.nextIndex !== content.tokenCount
    || content.contentRoot !== o.contentRoot || content.outputRoot !== o.outputRoot
    || !same(SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE, content.scope, p.scope)
    || content.selectionHash !== keccak256(encodeScopedPolicyPublicationV2SelectionPlan(selected))
    || selected.tokenCount !== f.membership.tokenCount || selected.nextIndex !== selected.tokenCount
    || selected.selectionRoot === ZeroHash || selected.membershipHash !== f.membership.membershipHash
    || !same(SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE, selected.scope, p.scope)) throw Error("Snapshot selection/content/output join mismatch");
  address(f.sourceFactory, true); nonzero(f.sourceFactoryCodeHash); nonzero(f.factoryDependenciesHash);
  if (p.coordinatorInventoryPlan === ZeroHash || entropy.planId !== p.coordinatorInventoryPlan
    || entropy.inventoryHash === ZeroHash || entropy.policyChainHash === ZeroHash || !entropy.allFrozen
    || entropy.policyCount === 0n || entropy.policyCount > f.membership.tokenCount
    || entropy.policyCount > BigInt(SCOPED_POLICY_PUBLICATION_V2_MAX_POLICIES)
    || entropy.policyCount !== BigInt(entropy.policies.length) || o.entropySourceSet !== d.targets[10]
    || o.inventoryHash !== entropy.inventoryHash || o.policyChainHash !== entropy.policyChainHash
    || content.inventoryHash !== entropy.inventoryHash || content.policyChainHash !== entropy.policyChainHash) {
    throw Error("Snapshot full policy inventory mismatch");
  }
  entropy.policies.forEach(row => {
    if (!row.frozen || row.coordinator === ZeroAddress || row.indexedCodeHash === ZeroHash
      || row.policyHash === ZeroHash || row.componentDataHash === ZeroHash) throw Error("Invalid frozen policy row");
  });
  return f;
}

export interface ScopedPolicyPublicationV2SnapshotPayload {
  readonly domain: Hex;
  readonly chainId: bigint;
  readonly snapshotHost: Address;
  readonly targets: ScopedPolicyPublicationV2Dependencies["targets"];
  readonly codeHashes: ScopedPolicyPublicationV2Dependencies["codeHashes"];
  readonly publication: ScopedPolicyPublicationV2Publication;
  readonly receipt: ScopedPolicyPublicationV2Receipt;
  readonly source: ScopedPolicyPublicationV2Source;
}

const snapshotFields = ["bytes32 domain", "uint256 chainId", "address snapshotHost", "address[11] targets", "bytes32[11] codeHashes",
  `${SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE} publication`, `${SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE} receipt`,
  `${SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE} source`];

export function scopedPolicyPublicationV2SnapshotBytes(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  dependencies: ScopedPolicyPublicationV2Dependencies,
  publication: ScopedPolicyPublicationV2Publication,
  receipt: ScopedPolicyPublicationV2Receipt,
  source: ScopedPolicyPublicationV2Source,
): Hex {
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  const d = graph.normalizeScopedPolicyGraphV2SnapshotDependencies(dependencies);
  const p = normalizeScopedPolicyPublicationV2Publication(publication);
  const r = normalizeScopedPolicyPublicationV2Receipt(receipt);
  const f = normalizeScopedPolicyPublicationV2Source(source);
  if (f.entropy.policies.length > SCOPED_POLICY_PUBLICATION_V2_MAX_POLICIES) throw Error("Snapshot policy count bound");
  const sourceHash = scopedPolicyPublicationV2SourceHash(c, d, f);
  return flatEncode(snapshotFields, { domain: id("6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2"),
    chainId: c.chainId, snapshotHost: c.snapshot, targets: d.targets, codeHashes: d.codeHashes,
    publication: { ...p, expectedSourceHash: ZeroHash }, receipt: { ...r, recordHash: ZeroHash, chainHash: ZeroHash,
      manifestHash: ZeroHash, manifestBytes: 0n, recordedAt: 0n, sourceHash }, source: f }, SCOPED_POLICY_PUBLICATION_V2_MAX_PAYLOAD_BYTES);
}

export function decodeScopedPolicyPublicationV2SnapshotBytes(value: Hex): ScopedPolicyPublicationV2SnapshotPayload {
  const p = flatDecode<ScopedPolicyPublicationV2SnapshotPayload>(snapshotFields, value, SCOPED_POLICY_PUBLICATION_V2_MAX_PAYLOAD_BYTES);
  const r = p.receipt;
  if (p.domain !== id("6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2") || p.publication.expectedSourceHash !== ZeroHash
    || r.recordHash !== ZeroHash || r.chainHash !== ZeroHash || r.manifestHash !== ZeroHash
    || r.manifestBytes !== 0n || r.recordedAt !== 0n || p.source.entropy.policies.length > SCOPED_POLICY_PUBLICATION_V2_MAX_POLICIES) {
    throw Error("Invalid normalized snapshot payload");
  }
  const expected = hash(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"), p.chainId, p.snapshotHost, p.targets, p.codeHashes, p.source]);
  if (r.sourceHash !== expected) throw Error("Snapshot source hash mismatch");
  return p;
}

export interface ScopedPolicyPublicationV2Authority {
  readonly authorizationClass: 7n | 8n;
  readonly grantRevision: bigint;
  readonly displayAuthorizationClass: 7n | 8n;
  readonly displayGrantRevision: bigint;
}

export function scopedPolicyPublicationV2PreviewReceipt(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  publication: ScopedPolicyPublicationV2Publication,
  publisher: Address,
  authority: ScopedPolicyPublicationV2Authority,
  sourceHash: Hex,
): ScopedPolicyPublicationV2Receipt {
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  const p = normalizeScopedPolicyPublicationV2Publication(publication);
  exact(authority, ["authorizationClass", "grantRevision", "displayAuthorizationClass", "displayGrantRevision"], "Authority facts");
  if (![7n, 8n].includes(authority.authorizationClass) || ![7n, 8n].includes(authority.displayAuthorizationClass)
    || uint(authority.grantRevision, 64) === 0n || uint(authority.displayGrantRevision, 64) === 0n
    || p.expectedRevision === 0xffffffffffffffffn) throw Error("Invalid independent Metadata grant facts");
  return normalizeScopedPolicyPublicationV2Receipt({ recordHash: ZeroHash as Hex,
    scopeSubject: graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, p.scope), predecessor: p.expectedHead,
    revision: p.expectedRevision + 1n, chainHash: ZeroHash as Hex, manifestHash: ZeroHash as Hex, manifestBytes: 0n,
    sourceHash: bytes(sourceHash, 32), publisher: address(publisher, true), ...authority, recordedAt: 0n,
    schemaHash: SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_SCHEMA_HASH, profileHash: SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_HASH,
    canonicalizationHash: SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_CANONICALIZATION_HASH });
}

/** Original pre-record hash excludes both fields filled after hashing, not other receipt facts. */
export function scopedPolicyPublicationV2SnapshotRecordHash(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  publication: ScopedPolicyPublicationV2Publication,
  receipt: ScopedPolicyPublicationV2Receipt,
): Hex {
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  const r = normalizeScopedPolicyPublicationV2Receipt(receipt);
  return hash(["bytes32", "uint256", "address", "address", "address", SCOPED_POLICY_PUBLICATION_V2_PUBLICATION_TUPLE,
    SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE], [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_RECORD_V2"), c.chainId,
    c.snapshot, c.core, c.metadata, normalizeScopedPolicyPublicationV2Publication(publication),
    { ...r, recordHash: ZeroHash, chainHash: ZeroHash }]);
}

export function scopedPolicyPublicationV2SnapshotChainHash(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  scope: ScopedPolicyPublicationV2Scope,
  predecessorChainHash: Hex,
  revision: bigint,
  recordHash: Hex,
): Hex {
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", SCOPED_POLICY_PUBLICATION_V2_SCOPE_TUPLE, "bytes32", "uint64", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_CHAIN_V2"), c.chainId, c.snapshot, c.core,
      graph.normalizeScopedPolicyGraphV2Scope(scope), bytes(predecessorChainHash, 32), uint(revision, 64), bytes(recordHash, 32)]);
}

export interface ScopedPolicyPublicationV2Chunk {
  readonly index: bigint;
  readonly data: Hex;
  readonly hash: Hex;
  readonly byteLength: bigint;
  readonly runtime: Hex;
  readonly runtimeHash: Hex;
}

/** Exact existing Store prerequisites; does not upload bytes or claim their availability. */
export function scopedPolicyPublicationV2Chunks(canonical: Hex): readonly ScopedPolicyPublicationV2Chunk[] {
  const raw = bytes(canonical, undefined, SCOPED_POLICY_PUBLICATION_V2_MAX_PAYLOAD_BYTES);
  if (raw === "0x") throw Error("Empty snapshot payload");
  const chunks: ScopedPolicyPublicationV2Chunk[] = [];
  for (let offset = 2; offset < raw.length; offset += 16384) {
    const data = ("0x" + raw.slice(offset, offset + 16384)) as Hex;
    const runtime = ("0x00" + data.slice(2)) as Hex;
    chunks.push(Object.freeze({ index: BigInt(chunks.length), data, hash: keccak256(data) as Hex,
      byteLength: BigInt((data.length - 2) / 2), runtime, runtimeHash: keccak256(runtime) as Hex }));
  }
  return Object.freeze(chunks);
}

/** Tuple-visible admission only; source freshness, authority and Store availability require original calls. */
export function validateScopedPolicyPublicationV2Publication(
  value: ScopedPolicyPublicationV2Publication,
  requireExpectedSource = true,
): ScopedPolicyPublicationV2Publication {
  if (typeof requireExpectedSource !== "boolean") throw Error("Expected source-check flag");
  const p = normalizeScopedPolicyPublicationV2Publication(value);
  graph.validateScopedPolicyGraphV2Scope(p.scope);
  nonzero(p.snapshotId);
  nonzero(p.reasonHash);
  nonzero(p.outputManifestRecord);
  nonzero(p.coordinatorInventoryPlan);
  if (requireExpectedSource) nonzero(p.expectedSourceHash);
  if (p.effectiveAt === 0n || p.expectedRevision === 0xffffffffffffffffn) throw Error("Invalid snapshot time or revision");
  const uri = p.manifestURI;
  if (uri !== "" && (/[\u0000-\u0020\u007f]/u.test(uri)
    || !((uri.startsWith("https://") && uri.length > 8 && !"/?#".includes(uri[8]!))
      || (uri.startsWith("ipfs://") && uri.length > 7) || (uri.startsWith("ar://") && uri.length > 5)))) {
    throw Error("Unsafe snapshot manifest URI");
  }
  return p;
}

export type ScopedPolicyPublicationV2Request =
  | { readonly kind: "begin"; readonly selectionId: Hex; readonly salt: Hex }
  | { readonly kind: "append"; readonly id: Hex; readonly payloads: readonly ScopedPolicyPublicationV2Payload[] }
  | {
    readonly kind: "beginManifest";
    readonly checkpointHash: Hex;
    readonly artifactHash: Hex;
    readonly coverageHash: Hex;
    readonly artistId: Hex;
  }
  | { readonly kind: "verifyNextOutputs"; readonly planHash: Hex; readonly count: bigint }
  | { readonly kind: "publishSnapshot"; readonly publication: ScopedPolicyPublicationV2Publication };

export interface ScopedPolicyPublicationV2Call {
  readonly coordinates: ScopedPolicyPublicationV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyPublicationV2Request;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function normalizeScopedPolicyPublicationV2Request(
  value: ScopedPolicyPublicationV2Request,
): ScopedPolicyPublicationV2Request {
  if (!value || typeof value !== "object") throw Error("Expected publication request");
  switch (value.kind) {
    case "begin":
      exact(value, ["kind", "selectionId", "salt"], "Begin request");
      return Object.freeze({ kind: value.kind, selectionId: nonzero(value.selectionId), salt: bytes(value.salt, 32) });
    case "append": {
      exact(value, ["kind", "id", "payloads"], "Append request");
      const payloads = list(value.payloads, 4).map(row => {
        const p = normalizeScopedPolicyPublicationV2Payload(row as ScopedPolicyPublicationV2Payload);
        if (p.tokenId === 0n || p.animation === "0x") throw Error("Append requires token and animation bytes");
        bytes(p.animation, undefined, SCOPED_POLICY_PUBLICATION_V2_MAX_RENDER_BYTES);
        bytes(p.image, undefined, 2048);
        return p;
      });
      if (payloads.length === 0) throw Error("Append requires one to four rows");
      return Object.freeze({ kind: value.kind, id: nonzero(value.id), payloads: Object.freeze(payloads) });
    }
    case "beginManifest":
      exact(value, ["kind", "checkpointHash", "artifactHash", "coverageHash", "artistId"], "Manifest request");
      return Object.freeze({ kind: value.kind, checkpointHash: nonzero(value.checkpointHash),
        artifactHash: nonzero(value.artifactHash), coverageHash: nonzero(value.coverageHash), artistId: nonzero(value.artistId) });
    case "verifyNextOutputs": {
      exact(value, ["kind", "planHash", "count"], "Verify request");
      const count = uint(value.count);
      if (count < 1n || count > 16n) throw Error("Verification requires one to sixteen outputs");
      return Object.freeze({ kind: value.kind, planHash: nonzero(value.planHash), count });
    }
    case "publishSnapshot":
      exact(value, ["kind", "publication"], "Snapshot request");
      return Object.freeze({ kind: value.kind, publication: validateScopedPolicyPublicationV2Publication(value.publication) });
    default:
      throw Error("Unsupported publication write");
  }
}

export function prepareScopedPolicyPublicationV2Call(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  caller: Address,
  request: ScopedPolicyPublicationV2Request,
): ScopedPolicyPublicationV2Call {
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  const actor = address(caller, true);
  const r = normalizeScopedPolicyPublicationV2Request(request);
  let host: ScopedPolicyPublicationV2Host;
  let args: readonly unknown[];
  switch (r.kind) {
    case "begin": host = "checkpoint"; args = [r.selectionId, r.salt]; break;
    case "append": host = "checkpoint"; args = [r.id, r.payloads]; break;
    case "beginManifest": host = "output"; args = [r.checkpointHash, r.artifactHash, r.coverageHash, r.artistId]; break;
    case "verifyNextOutputs": host = "output"; args = [r.planHash, r.count]; break;
    case "publishSnapshot": host = "snapshot"; args = [r.publication]; break;
  }
  const data = bytes(scopedPolicyPublicationV2Interface(host).encodeFunctionData(r.kind, args),
    undefined, SCOPED_POLICY_PUBLICATION_V2_MAX_CALL_BYTES);
  return Object.freeze({ coordinates: c, caller: actor, request: r,
    call: Object.freeze({ to: c[host], data, value: 0n }), factsVerified: false });
}

export function normalizeScopedPolicyPublicationV2Call(value: ScopedPolicyPublicationV2Call): ScopedPolicyPublicationV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared publication");
  exact(value.call, ["to", "data", "value"], "Unsigned call");
  const fresh = prepareScopedPolicyPublicationV2Call(value.coordinates, value.caller, value.request);
  if (value.factsVerified !== false || address(value.call.to) !== fresh.call.to || value.call.value !== 0n
    || bytes(value.call.data, undefined, SCOPED_POLICY_PUBLICATION_V2_MAX_CALL_BYTES) !== fresh.call.data) {
    throw Error("Prepared publication call changed");
  }
  return fresh;
}

export type ScopedPolicyPublicationV2ReadRequest =
  | { readonly host: "checkpoint"; readonly kind: "checkpoint" | "requireCurrentCheckpoint"; readonly id: Hex }
  | { readonly host: "checkpoint"; readonly kind: "outputAt"; readonly id: Hex; readonly index: bigint }
  | { readonly host: "output"; readonly kind: "manifestPlan"; readonly planHash: Hex }
  | { readonly host: "output"; readonly kind: "manifestRecord"; readonly recordHash: Hex }
  | { readonly host: "output"; readonly kind: "requireCurrentManifest"; readonly recordHash: Hex; readonly artistId: Hex }
  | { readonly host: "snapshot"; readonly kind: "previewSnapshot"; readonly publication: ScopedPolicyPublicationV2Publication; readonly publisher: Address }
  | { readonly host: "snapshot"; readonly kind: "dependencies" }
  | { readonly host: "snapshot"; readonly kind: "currentSnapshot" | "snapshotCount" | "snapshotLock"; readonly scope: ScopedPolicyPublicationV2Scope }
  | { readonly host: "snapshot"; readonly kind: "snapshotAt"; readonly scope: ScopedPolicyPublicationV2Scope; readonly index: bigint }
  | { readonly host: "snapshot"; readonly kind: "snapshotRecord" | "snapshotPayload"; readonly hash: Hex }
  | { readonly host: "snapshot"; readonly kind: "requireCurrent"; readonly scope: ScopedPolicyPublicationV2Scope; readonly hash: Hex; readonly revision: bigint };

export interface ScopedPolicyPublicationV2Read {
  readonly coordinates: ScopedPolicyPublicationV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyPublicationV2ReadRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

/** Read keys may be zero/unknown; the original getter determines missing versus reverting history. */
export function prepareScopedPolicyPublicationV2Read(
  coordinates: ScopedPolicyPublicationV2Coordinates,
  caller: Address,
  request: ScopedPolicyPublicationV2ReadRequest,
): ScopedPolicyPublicationV2Read {
  const c = normalizeScopedPolicyPublicationV2Coordinates(coordinates);
  const actor = address(caller);
  let r: ScopedPolicyPublicationV2ReadRequest;
  let args: readonly unknown[];
  if (!request || typeof request !== "object") throw Error("Expected publication read");
  switch (request.kind) {
    case "checkpoint": case "requireCurrentCheckpoint":
      exact(request, ["host", "kind", "id"], "Checkpoint read");
      if (request.host !== "checkpoint") throw Error("Wrong read host");
      r = Object.freeze({ ...request, id: bytes(request.id, 32) }); args = [r.id]; break;
    case "outputAt":
      exact(request, ["host", "kind", "id", "index"], "Output row read");
      if (request.host !== "checkpoint") throw Error("Wrong read host");
      r = Object.freeze({ ...request, id: bytes(request.id, 32), index: uint(request.index) }); args = [r.id, r.index]; break;
    case "manifestPlan":
      exact(request, ["host", "kind", "planHash"], "Manifest plan read");
      if (request.host !== "output") throw Error("Wrong read host");
      r = Object.freeze({ ...request, planHash: bytes(request.planHash, 32) }); args = [r.planHash]; break;
    case "manifestRecord": case "requireCurrentManifest":
      exact(request, request.kind === "manifestRecord" ? ["host", "kind", "recordHash"]
        : ["host", "kind", "recordHash", "artistId"], "Manifest read");
      if (request.host !== "output") throw Error("Wrong read host");
      r = request.kind === "manifestRecord"
        ? Object.freeze({ ...request, recordHash: bytes(request.recordHash, 32) })
        : Object.freeze({ ...request, recordHash: bytes(request.recordHash, 32), artistId: bytes(request.artistId, 32) });
      args = r.kind === "manifestRecord" ? [r.recordHash] : [r.recordHash, r.artistId]; break;
    case "previewSnapshot":
      exact(request, ["host", "kind", "publication", "publisher"], "Preview read");
      if (request.host !== "snapshot") throw Error("Wrong read host");
      r = Object.freeze({ ...request, publication: validateScopedPolicyPublicationV2Publication(request.publication, false),
        publisher: address(request.publisher, true) }); args = [r.publication, r.publisher]; break;
    case "dependencies":
      exact(request, ["host", "kind"], "Dependencies read");
      if (request.host !== "snapshot") throw Error("Wrong read host");
      r = Object.freeze({ ...request }); args = []; break;
    case "currentSnapshot": case "snapshotCount": case "snapshotLock": case "snapshotAt": case "requireCurrent":
      exact(request, request.kind === "snapshotAt" ? ["host", "kind", "scope", "index"]
        : request.kind === "requireCurrent" ? ["host", "kind", "scope", "hash", "revision"]
          : ["host", "kind", "scope"], "Scoped snapshot read");
      if (request.host !== "snapshot") throw Error("Wrong read host");
      if (request.kind === "snapshotAt") {
        r = Object.freeze({ ...request, scope: graph.validateScopedPolicyGraphV2Scope(request.scope), index: uint(request.index) });
        args = [r.scope, r.index];
      } else if (request.kind === "requireCurrent") {
        r = Object.freeze({ ...request, scope: graph.validateScopedPolicyGraphV2Scope(request.scope),
          hash: bytes(request.hash, 32), revision: uint(request.revision, 64) }); args = [r.scope, r.hash, r.revision];
      } else {
        r = Object.freeze({ ...request, scope: graph.validateScopedPolicyGraphV2Scope(request.scope) }); args = [r.scope];
      }
      break;
    case "snapshotRecord": case "snapshotPayload":
      exact(request, ["host", "kind", "hash"], "Snapshot record read");
      if (request.host !== "snapshot") throw Error("Wrong read host");
      r = Object.freeze({ ...request, hash: bytes(request.hash, 32) }); args = [r.hash]; break;
    default: throw Error("Unsupported publication read");
  }
  return Object.freeze({ coordinates: c, caller: actor, request: r, factsVerified: false,
    call: Object.freeze({ to: c[r.host], value: 0n, data: bytes(scopedPolicyPublicationV2Interface(r.host)
      .encodeFunctionData(r.kind, args), undefined, SCOPED_POLICY_PUBLICATION_V2_MAX_CALL_BYTES) }) });
}

export function normalizeScopedPolicyPublicationV2Read(value: ScopedPolicyPublicationV2Read): ScopedPolicyPublicationV2Read {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared publication read");
  exact(value.call, ["to", "data", "value"], "Unsigned read call");
  const fresh = prepareScopedPolicyPublicationV2Read(value.coordinates, value.caller, value.request);
  if (value.factsVerified !== false || address(value.call.to) !== fresh.call.to || value.call.value !== 0n
    || bytes(value.call.data, undefined, SCOPED_POLICY_PUBLICATION_V2_MAX_CALL_BYTES) !== fresh.call.data) {
    throw Error("Prepared publication read changed");
  }
  return fresh;
}
