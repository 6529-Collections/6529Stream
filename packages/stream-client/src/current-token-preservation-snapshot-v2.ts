import {
  AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress,
  hexlify, id, isHexString, keccak256, toUtf8Bytes,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as output from "./current-token-preservation-output-v2.js";
import * as graph from "./current-scoped-policy-graph-v2.js";
import type * as publication from "./current-scoped-policy-publication-v2.js";

/** ABI146 fixed token-preservation family. Pure values never establish live source or writer authority. */
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SOURCE = "9381dd999075693a4f63092d9924856a0dd72834";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_FAMILY = output.TOKEN_PRESERVATION_OUTPUT_V2_FAMILY;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PROFILE = id("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V2") as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PROFILE = id("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2") as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_PAYLOAD_BYTES = 524288;
/** Client raw-codec allocation ceiling, distinct from the original complete payload limit. */
export const TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_CODEC_BYTES = 1048576;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_POLICIES = 630;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_URI_BYTES = 2048;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SEGMENT_BYTES = 8192;
export type TokenPreservationSnapshotV2ScopeKind = output.TokenPreservationOutputV2ScopeKind;
export type TokenPreservationSnapshotV2Scope = output.TokenPreservationOutputV2Scope;
export type TokenPreservationSnapshotV2Dependencies = graph.ScopedPolicyGraphV2SnapshotDependencies;
export type TokenPreservationSnapshotV2Membership = graph.ScopedPolicyGraphV2Membership;
export type TokenPreservationSnapshotV2Policy = graph.ScopedPolicyGraphV2Policy;
export type TokenPreservationSnapshotV2CoordinatorPolicy = graph.ScopedPolicyGraphV2CoordinatorPolicy;
export type TokenPreservationSnapshotV2PolicyEvidence = graph.ScopedPolicyGraphV2PolicyEvidence;
export type TokenPreservationSnapshotV2ArtistPresentation = publication.ScopedPolicyPublicationV2ArtistPresentation;
export type TokenPreservationSnapshotV2SelectionPlan = output.TokenPreservationOutputV2SelectionPlan;
export type TokenPreservationSnapshotV2ContentPlan = output.TokenPreservationOutputV2ContentPlan;
export type TokenPreservationSnapshotV2Manifest = output.TokenPreservationOutputV2Manifest;

export interface TokenPreservationSnapshotV2Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly metadata: Address;
  readonly snapshot: Address;
  readonly scopeKind: TokenPreservationSnapshotV2ScopeKind;
}
export interface TokenPreservationSnapshotV2ScopedPublication {
  readonly scope: TokenPreservationSnapshotV2Scope;
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
export interface TokenPreservationSnapshotV2CollectionPublication extends TokenPreservationSnapshotV2ScopedPublication {
  readonly contentRootRecord: Hex;
}
export type TokenPreservationSnapshotV2Publication = TokenPreservationSnapshotV2CollectionPublication | TokenPreservationSnapshotV2ScopedPublication;
export interface TokenPreservationSnapshotV2RootPublication {
  readonly collectionId: bigint;
  readonly expectedPredecessor: Hex;
  readonly verifiedManifestRecordHash: Hex;
  readonly manifestURI: string;
}
export interface TokenPreservationSnapshotV2RootRecord {
  readonly publication: TokenPreservationSnapshotV2RootPublication;
  readonly contentRoot: Hex;
  readonly leafCount: bigint;
  readonly manifestHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly publisher: Address;
  readonly authorizationClass: bigint;
  readonly grantRevision: bigint;
  readonly routeHash: Hex;
  readonly stateHash: Hex;
  readonly artistConsent: Hex;
  readonly publishedAt: bigint;
}
export interface TokenPreservationSnapshotV2RootBinding {
  readonly profileId: Hex;
  readonly outputManifest: Address;
  readonly outputManifestCodeHash: Hex;
  readonly checkpoint: Address;
  readonly checkpointCodeHash: Hex;
  readonly checkpointHash: Hex;
  readonly checkpointStateHash: Hex;
  readonly entropySourceSet: Address;
  readonly entropySourceSetCodeHash: Hex;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly outputRoot: Hex;
  readonly outputSchemaHash: Hex;
  readonly outputCanonicalizationHash: Hex;
  readonly leafSchemaHash: Hex;
  readonly rootSchemaHash: Hex;
  readonly rootCanonicalizationHash: Hex;
  readonly metadataRouter: Address;
  readonly preservationOutputProfile: Hex;
}
interface SourceBase {
  readonly scope: TokenPreservationSnapshotV2Scope;
  readonly membership: TokenPreservationSnapshotV2Membership;
  readonly artist: TokenPreservationSnapshotV2ArtistPresentation;
  readonly selection: TokenPreservationSnapshotV2SelectionPlan;
  readonly content: TokenPreservationSnapshotV2ContentPlan;
  readonly outputs: TokenPreservationSnapshotV2Manifest;
  readonly entropy: TokenPreservationSnapshotV2PolicyEvidence;
}
export interface TokenPreservationSnapshotV2CollectionSource extends SourceBase {
  readonly root: TokenPreservationSnapshotV2RootRecord;
  readonly rootBinding: TokenPreservationSnapshotV2RootBinding;
}
export interface TokenPreservationSnapshotV2ScopedSource extends SourceBase {
  readonly sourceFactory: Address;
  readonly sourceFactoryCodeHash: Hex;
  readonly factoryDependenciesHash: Hex;
}
export type TokenPreservationSnapshotV2Source = TokenPreservationSnapshotV2CollectionSource | TokenPreservationSnapshotV2ScopedSource;
export interface TokenPreservationSnapshotV2Receipt {
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
export interface TokenPreservationSnapshotV2Lock {
  readonly recordHash: Hex;
  readonly revision: bigint;
  readonly actionId: Hex;
  readonly lockedAt: bigint;
}
export interface TokenPreservationSnapshotV2Authority {
  readonly authorizationClass: 7n | 8n;
  readonly grantRevision: bigint;
  readonly displayAuthorizationClass: 7n | 8n;
  readonly displayGrantRevision: bigint;
}

export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE = output.TOKEN_PRESERVATION_OUTPUT_V2_SCOPE_TUPLE;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_DEPENDENCIES_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_SNAPSHOT_DEPENDENCIES_TUPLE;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_MEMBERSHIP_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_MEMBERSHIP_TUPLE;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_POLICY_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COORDINATOR_POLICY_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_COORDINATOR_POLICY_TUPLE;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_POLICY_EVIDENCE_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_POLICY_EVIDENCE_TUPLE;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_ARTIST_PRESENTATION_TUPLE = "tuple(bool locked,address registry,bytes32 registryCodeHash,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address nominatedArtist,bytes32 identityRecordHash,bytes32 acceptanceRecordHash,uint64 acceptedAt,uint64 lockedAt,bytes32 snapshotHash)";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SELECTION_PLAN_TUPLE = output.TOKEN_PRESERVATION_OUTPUT_V2_SELECTION_PLAN_TUPLE;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_CONTENT_PLAN_TUPLE = output.TOKEN_PRESERVATION_OUTPUT_V2_CONTENT_PLAN_TUPLE;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_MANIFEST_TUPLE = output.TOKEN_PRESERVATION_OUTPUT_V2_MANIFEST_TUPLE;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PUBLICATION_TUPLE = `tuple(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE} scope,bytes32 snapshotId,bytes32 expectedHead,uint64 expectedRevision,bytes32 outputManifestRecord,bytes32 coordinatorInventoryPlan,bytes32 expectedSourceHash,string manifestURI,uint64 effectiveAt,bytes32 reasonHash)`;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PUBLICATION_TUPLE = `tuple(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE} scope,bytes32 snapshotId,bytes32 expectedHead,uint64 expectedRevision,bytes32 outputManifestRecord,bytes32 contentRootRecord,bytes32 coordinatorInventoryPlan,bytes32 expectedSourceHash,string manifestURI,uint64 effectiveAt,bytes32 reasonHash)`;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_PUBLICATION_TUPLE = "tuple(uint256 collectionId,bytes32 expectedPredecessor,bytes32 verifiedManifestRecordHash,string manifestURI)";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_RECORD_TUPLE = `tuple(${TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_PUBLICATION_TUPLE} publication,bytes32 contentRoot,uint64 leafCount,bytes32 manifestHash,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address publisher,uint8 authorizationClass,uint64 grantRevision,bytes32 routeHash,bytes32 stateHash,bytes32 artistConsent,uint64 publishedAt)`;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_BINDING_TUPLE = "tuple(bytes32 profileId,address outputManifest,bytes32 outputManifestCodeHash,address checkpoint,bytes32 checkpointCodeHash,bytes32 checkpointHash,bytes32 checkpointStateHash,address entropySourceSet,bytes32 entropySourceSetCodeHash,bytes32 inventoryHash,bytes32 policyChainHash,bytes32 outputRoot,bytes32 outputSchemaHash,bytes32 outputCanonicalizationHash,bytes32 leafSchemaHash,bytes32 rootSchemaHash,bytes32 rootCanonicalizationHash,address metadataRouter,bytes32 preservationOutputProfile)";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_SOURCE_TUPLE = `tuple(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE} scope,${TOKEN_PRESERVATION_SNAPSHOT_V2_MEMBERSHIP_TUPLE} membership,${TOKEN_PRESERVATION_SNAPSHOT_V2_ARTIST_PRESENTATION_TUPLE} artist,${TOKEN_PRESERVATION_SNAPSHOT_V2_SELECTION_PLAN_TUPLE} selection,${TOKEN_PRESERVATION_SNAPSHOT_V2_CONTENT_PLAN_TUPLE} content,${TOKEN_PRESERVATION_SNAPSHOT_V2_MANIFEST_TUPLE} outputs,${TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_RECORD_TUPLE} root,${TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_BINDING_TUPLE} rootBinding,${TOKEN_PRESERVATION_SNAPSHOT_V2_POLICY_EVIDENCE_TUPLE} entropy)`;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_SOURCE_TUPLE = `tuple(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE} scope,${TOKEN_PRESERVATION_SNAPSHOT_V2_MEMBERSHIP_TUPLE} membership,${TOKEN_PRESERVATION_SNAPSHOT_V2_ARTIST_PRESENTATION_TUPLE} artist,${TOKEN_PRESERVATION_SNAPSHOT_V2_SELECTION_PLAN_TUPLE} selection,${TOKEN_PRESERVATION_SNAPSHOT_V2_CONTENT_PLAN_TUPLE} content,${TOKEN_PRESERVATION_SNAPSHOT_V2_MANIFEST_TUPLE} outputs,address sourceFactory,bytes32 sourceFactoryCodeHash,bytes32 factoryDependenciesHash,${TOKEN_PRESERVATION_SNAPSHOT_V2_POLICY_EVIDENCE_TUPLE} entropy)`;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE = "tuple(bytes32 recordHash,bytes32 scopeSubject,bytes32 predecessor,uint64 revision,bytes32 chainHash,bytes32 manifestHash,uint32 manifestBytes,bytes32 sourceHash,address publisher,uint8 authorizationClass,uint64 grantRevision,uint8 displayAuthorizationClass,uint64 displayGrantRevision,uint64 recordedAt,bytes32 schemaHash,bytes32 profileHash,bytes32 canonicalizationHash)";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_LOCK_TUPLE = "tuple(bytes32 recordHash,uint64 revision,bytes32 actionId,uint64 lockedAt)";

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
function bytes(value: unknown, length?: number, maximum = TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_CODEC_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, length ?? true) || (value.length - 2) / 2 > maximum) throw Error("Invalid bytes or allocation bound");
  return value.toLowerCase() as Hex;
}
function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === Z) throw Error("Zero commitment");
  return result;
}
function text(value: unknown): string {
  if (typeof value !== "string" || toUtf8Bytes(value).length > TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_URI_BYTES) throw Error("Invalid UTF-8 string bound");
  return value;
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
    return Object.freeze(list(v, size ?? TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_POLICIES, size).map(x => valueOf(t.arrayChildren!, x, decoded)));
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
  if (t.type === "string") return text(v);
  if (t.type.startsWith("bytes")) return bytes(v, t.type === "bytes" ? undefined : Number(t.type.slice(5)));
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
function same(actual: unknown, expected: unknown, label: string): void {
  if (actual !== expected) throw Error(`${label} mismatch`);
}
function kind(value: unknown): TokenPreservationSnapshotV2ScopeKind {
  if (value !== "collection" && value !== "scoped") throw Error("Unknown snapshot profile");
  return value;
}
function domain(scopeKind: TokenPreservationSnapshotV2ScopeKind, purpose: string): Hex {
  return id(`6529STREAM_${kind(scopeKind) === "scoped" ? "SCOPED_" : ""}PRESERVATION_POLICY_SNAPSHOT_${purpose}_V2`) as Hex;
}
function publicationTuple(scopeKind: TokenPreservationSnapshotV2ScopeKind): string {
  return kind(scopeKind) === "collection" ? TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PUBLICATION_TUPLE : TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PUBLICATION_TUPLE;
}
function sourceTuple(scopeKind: TokenPreservationSnapshotV2ScopeKind): string {
  return kind(scopeKind) === "collection" ? TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_SOURCE_TUPLE : TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_SOURCE_TUPLE;
}
export function normalizeTokenPreservationSnapshotV2Coordinates(value: TokenPreservationSnapshotV2Coordinates): TokenPreservationSnapshotV2Coordinates {
  exact(value, ["chainId", "core", "metadata", "snapshot", "scopeKind"]);
  if (!uint(value.chainId)) throw Error("Zero chain ID");
  return Object.freeze({ chainId: value.chainId, core: address(value.core, true), metadata: address(value.metadata, true),
    snapshot: address(value.snapshot, true), scopeKind: kind(value.scopeKind) });
}
export function tokenPreservationSnapshotV2Profile(scopeKind: TokenPreservationSnapshotV2ScopeKind): Hex {
  return kind(scopeKind) === "collection" ? TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PROFILE : TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PROFILE;
}

export function normalizeTokenPreservationSnapshotV2Publication(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: TokenPreservationSnapshotV2Publication,
): TokenPreservationSnapshotV2Publication {
  return normalize(publicationTuple(scopeKind), value);
}
export function encodeTokenPreservationSnapshotV2Publication(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: TokenPreservationSnapshotV2Publication,
): Hex {
  return encode(publicationTuple(scopeKind), value);
}
export function decodeTokenPreservationSnapshotV2Publication(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: Hex,
): TokenPreservationSnapshotV2Publication {
  return decode(publicationTuple(scopeKind), value);
}
export function normalizeTokenPreservationSnapshotV2Source(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: TokenPreservationSnapshotV2Source,
): TokenPreservationSnapshotV2Source {
  return normalize(sourceTuple(scopeKind), value);
}
export function encodeTokenPreservationSnapshotV2Source(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: TokenPreservationSnapshotV2Source,
): Hex {
  return encode(sourceTuple(scopeKind), value);
}
export function decodeTokenPreservationSnapshotV2Source(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: Hex,
): TokenPreservationSnapshotV2Source {
  return decode(sourceTuple(scopeKind), value);
}
export function validateTokenPreservationSnapshotV2Scope(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: TokenPreservationSnapshotV2Scope,
): TokenPreservationSnapshotV2Scope {
  return output.validateTokenPreservationOutputV2Scope(kind(scopeKind), value);
}
export function tokenPreservationSnapshotV2ScopeSubject(
  chainId: bigint,
  core: Address,
  value: TokenPreservationSnapshotV2Scope,
): Hex {
  const s = normalizeTokenPreservationSnapshotV2Scope(value);
  validateTokenPreservationSnapshotV2Scope(s.scopeType === 0n ? "collection" : "scoped", s);
  const c = address(core, true);
  const chain = uint(chainId);
  if (s.scopeType === 0n || s.scopeType === 1n) {
    return hash(["bytes32", "uint256", "address", "uint256"],
      [id(s.scopeType === 0n ? "6529STREAM_SUBJECT_COLLECTION_V1" : "6529STREAM_SUBJECT_TOKEN_V1"), chain, c,
        s.scopeType === 0n ? s.collectionId : s.tokenId]);
  }
  return hash(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
    [id("6529STREAM_SUBJECT_SCOPE_V1"), chain, c, s.collectionId, s.scopeType, s.scopeId]);
}
function coordinateDependencies(c: TokenPreservationSnapshotV2Coordinates, value: TokenPreservationSnapshotV2Dependencies) {
  const d = normalizeTokenPreservationSnapshotV2Dependencies(value);
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.targets[1] !== c.metadata) throw Error("Snapshot coordinates/dependencies mismatch");
  return d;
}
/** Only supplied constructor constraints. Runtime pins and all original host relationships remain unproved. */
export function validateTokenPreservationSnapshotV2Dependencies(
  coordinates: TokenPreservationSnapshotV2Coordinates,
  value: TokenPreservationSnapshotV2Dependencies,
): TokenPreservationSnapshotV2Dependencies {
  const d = coordinateDependencies(normalizeTokenPreservationSnapshotV2Coordinates(coordinates), value);
  d.targets.forEach((a, i) => { address(a, true); nonzero(d.codeHashes[i]); });
  if (d.readGas < 50000n || d.sourceGas < d.readGas || d.inventoryGas < d.readGas
    || [d.readGas, d.sourceGas, d.inventoryGas].some(g => g > 0xffffffffn)) throw Error("Invalid original snapshot gas bounds");
  return d;
}
function validURI(uri: string): void {
  text(uri);
  if (uri !== "" && (/[\u0000-\u0020\u007f]/u.test(uri)
    || !((uri.startsWith("https://") && uri.length > 8 && !"/?#".includes(uri[8]!))
      || (uri.startsWith("ipfs://") && uri.length > 7) || (uri.startsWith("ar://") && uri.length > 5)))) {
    throw Error("Unsafe snapshot manifest URI");
  }
}
/** Preview permits an unset expectedSourceHash; actual publication requires the observed nonzero hash. */
export function validateTokenPreservationSnapshotV2Publication(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: TokenPreservationSnapshotV2Publication,
  requireExpectedSource = true,
): TokenPreservationSnapshotV2Publication {
  if (typeof requireExpectedSource !== "boolean") throw Error("Invalid expected-source flag");
  const p = normalizeTokenPreservationSnapshotV2Publication(scopeKind, value);
  validateTokenPreservationSnapshotV2Scope(scopeKind, p.scope);
  [p.snapshotId, p.reasonHash, p.outputManifestRecord, p.coordinatorInventoryPlan].forEach(nonzero);
  if (scopeKind === "collection") nonzero((p as TokenPreservationSnapshotV2CollectionPublication).contentRootRecord);
  if (requireExpectedSource) nonzero(p.expectedSourceHash);
  if (!p.effectiveAt || p.expectedRevision === 0xffffffffffffffffn) throw Error("Invalid snapshot time or revision");
  validURI(p.manifestURI);
  return p;
}
export interface TokenPreservationSnapshotV2CandidateState {
  readonly timestamp: bigint;
  readonly head: Hex;
  readonly count: bigint;
  readonly snapshotIdUsed: boolean;
  readonly lock: TokenPreservationSnapshotV2Lock;
}
/** Original candidate predicates on supplied state, without any RPC authentication or grant inference. */
export function validateTokenPreservationSnapshotV2Candidate(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: TokenPreservationSnapshotV2Publication,
  state: TokenPreservationSnapshotV2CandidateState,
  requireExpectedSource = true,
): TokenPreservationSnapshotV2Publication {
  const p = validateTokenPreservationSnapshotV2Publication(scopeKind, value, requireExpectedSource);
  exact(state, ["timestamp", "head", "count", "snapshotIdUsed", "lock"]);
  const timestamp = uint(state.timestamp, 64);
  if (typeof state.snapshotIdUsed !== "boolean") throw Error("Invalid used-ID flag");
  if (p.effectiveAt > timestamp || state.snapshotIdUsed || normalizeTokenPreservationSnapshotV2Lock(state.lock).actionId !== Z) {
    throw Error("Snapshot is early, locked or already used");
  }
  if (bytes(state.head, 32) !== p.expectedHead || uint(state.count) !== p.expectedRevision) throw Error("Snapshot lineage mismatch");
  return p;
}

/** Exact supplied preimage; mutable read/source/inventory gas budgets are deliberately excluded. */
export function tokenPreservationSnapshotV2SourceHash(
  coordinates: TokenPreservationSnapshotV2Coordinates,
  dependencies: TokenPreservationSnapshotV2Dependencies,
  source: TokenPreservationSnapshotV2Source,
): Hex {
  const c = normalizeTokenPreservationSnapshotV2Coordinates(coordinates);
  const d = coordinateDependencies(c, dependencies);
  return hash(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", sourceTuple(c.scopeKind)],
    [domain(c.scopeKind, "SOURCES"), c.chainId, c.snapshot, d.targets, d.codeHashes,
      normalizeTokenPreservationSnapshotV2Source(c.scopeKind, source)]);
}
export function tokenPreservationSnapshotV2RootRecordHash(
  chainId: bigint,
  router: Address,
  record: TokenPreservationSnapshotV2RootRecord,
  binding: TokenPreservationSnapshotV2RootBinding,
): Hex {
  return hash(["bytes32", "uint256", "address", TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_RECORD_TUPLE, TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_BINDING_TUPLE],
    [id("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"), uint(chainId), address(router),
      normalizeTokenPreservationSnapshotV2RootRecord(record), normalizeTokenPreservationSnapshotV2RootBinding(binding)]);
}
/** Immutable field joins visible in Source. This is not an independent proof of live original admission. */
export function validateTokenPreservationSnapshotV2Source(
  coordinates: TokenPreservationSnapshotV2Coordinates,
  dependencies: TokenPreservationSnapshotV2Dependencies,
  publication: TokenPreservationSnapshotV2Publication,
  source: TokenPreservationSnapshotV2Source,
): TokenPreservationSnapshotV2Source {
  const c = normalizeTokenPreservationSnapshotV2Coordinates(coordinates);
  const d = coordinateDependencies(c, dependencies);
  const p = validateTokenPreservationSnapshotV2Publication(c.scopeKind, publication, false);
  const f = normalizeTokenPreservationSnapshotV2Source(c.scopeKind, source);
  d.targets.forEach((a, i) => { address(a, true); nonzero(d.codeHashes[i]); });
  for (const scope of [f.scope, f.content.scope, f.outputs.scope, f.selection.scope]) {
    same(encodeTokenPreservationSnapshotV2Scope(scope), encodeTokenPreservationSnapshotV2Scope(p.scope), "Full source scope");
  }
  const membership = f.membership;
  same(membership.scopeSubject, tokenPreservationSnapshotV2ScopeSubject(c.chainId, c.core, p.scope), "Membership subject");
  nonzero(membership.membershipHash);
  if (!membership.tokenCount || membership.tokenCount > 0xffffffffffffffffn
    || (p.scope.scopeType === 1n && membership.tokenCount !== 1n)) throw Error("Invalid complete membership count");
  const a = f.artist;
  if (!a.locked || !a.bindingGeneration || !a.acceptedAt || !a.lockedAt) throw Error("Artist presentation is incomplete");
  [a.artistId, a.snapshotHash, a.registryCodeHash, a.bindingHash, a.identityRecordHash, a.acceptanceRecordHash].forEach(nonzero);
  address(a.registry, true);
  address(a.nominatedArtist, true);
  const m = f.outputs;
  const content = f.content;
  const s = f.selection;
  if (m.tokenCount !== membership.tokenCount || content.tokenCount !== membership.tokenCount || s.tokenCount !== membership.tokenCount
    || content.nextIndex !== content.tokenCount || s.nextIndex !== s.tokenCount) throw Error("Incomplete selection/content/output");
  same(m.artistId, a.artistId, "Output Artist");
  same(m.metadataRouter, d.targets[4], "Output Router");
  same(m.preservationProfile, TOKEN_PRESERVATION_SNAPSHOT_V2_FAMILY, "Output family");
  same(content.preservationProfile, m.preservationProfile, "Content family");
  same(content.contentRoot, m.contentRoot, "Content root");
  same(content.outputRoot, m.outputRoot, "Output root");
  same(m.checkpointStateHash, keccak256(encodeTokenPreservationSnapshotV2ContentPlan(content)), "Checkpoint state");
  same(content.selectionHash, keccak256(encodeTokenPreservationSnapshotV2SelectionPlan(s)), "Selection hash");
  same(s.membershipHash, membership.membershipHash, "Selection membership");
  [m.contentRoot, m.outputRoot, m.manifestHash, m.checkpointStateHash, s.selectionRoot].forEach(nonzero);
  const outCoordinates: output.TokenPreservationOutputV2Coordinates = {
    chainId: c.chainId, core: c.core, metadataRouter: d.targets[4], checkpoint: d.targets[7], output: d.targets[8], scopeKind: c.scopeKind,
  };
  const planHash = output.tokenPreservationOutputV2ManifestPlanHash(outCoordinates, d.targets[9], m);
  output.authenticateTokenPreservationOutputV2History(outCoordinates, d.targets[9], planHash,
    { manifest: m, nextIndex: m.tokenCount, recordHash: p.outputManifestRecord });
  const e = f.entropy;
  if (!e.policyCount || e.policyCount > membership.tokenCount || e.policyCount > BigInt(TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_POLICIES)
    || e.policyCount !== BigInt(e.policies.length) || !e.allFrozen) throw Error("Incomplete frozen policy evidence");
  same(e.planId, p.coordinatorInventoryPlan, "Coordinator inventory plan");
  nonzero(e.inventoryHash);
  nonzero(e.policyChainHash);
  same(m.entropySourceSet, d.targets[10], "Entropy source set");
  for (const row of [m, content]) {
    same(row.inventoryHash, e.inventoryHash, "Inventory hash");
    same(row.policyChainHash, e.policyChainHash, "Policy chain");
  }
  e.policies.forEach(row => {
    if (!row.frozen) throw Error("Policy is not frozen");
    address(row.coordinator, true);
    [row.indexedCodeHash, row.policyHash, row.componentDataHash].forEach(nonzero);
  });
  if (c.scopeKind === "scoped") {
    const scoped = f as TokenPreservationSnapshotV2ScopedSource;
    address(scoped.sourceFactory, true);
    nonzero(scoped.sourceFactoryCodeHash);
    nonzero(scoped.factoryDependenciesHash);
  } else {
    const collection = f as TokenPreservationSnapshotV2CollectionSource;
    const r = collection.root;
    const b = collection.rootBinding;
    const expected = normalizeTokenPreservationSnapshotV2RootBinding({
      profileId: id("6529STREAM_PRESERVATION_POLICY_CONTENT_V2") as Hex,
      outputManifest: d.targets[8], outputManifestCodeHash: d.codeHashes[8],
      checkpoint: d.targets[7], checkpointCodeHash: d.codeHashes[7],
      checkpointHash: m.checkpointHash, checkpointStateHash: m.checkpointStateHash,
      entropySourceSet: d.targets[10], entropySourceSetCodeHash: d.codeHashes[10],
      inventoryHash: e.inventoryHash, policyChainHash: e.policyChainHash, outputRoot: m.outputRoot,
      outputSchemaHash: output.TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA_HASH,
      outputCanonicalizationHash: output.TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION_HASH,
      leafSchemaHash: output.TOKEN_PRESERVATION_OUTPUT_V2_LEAF_SCHEMA_HASH,
      rootSchemaHash: TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_SCHEMA_HASH,
      rootCanonicalizationHash: TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_CANONICALIZATION_HASH,
      metadataRouter: d.targets[4], preservationOutputProfile: m.preservationProfile,
    });
    same(encodeTokenPreservationSnapshotV2RootBinding(b), encodeTokenPreservationSnapshotV2RootBinding(expected), "Root preservation binding");
    if (r.publication.collectionId !== p.scope.collectionId || r.publication.verifiedManifestRecordHash !== p.outputManifestRecord
      || r.contentRoot !== m.contentRoot || r.leafCount !== m.tokenCount || r.manifestHash !== m.manifestHash
      || r.artistId !== a.artistId || r.bindingGeneration !== a.bindingGeneration || r.bindingHash !== a.bindingHash
      || ![7n, 8n].includes(r.authorizationClass) || !r.grantRevision || !r.publishedAt) throw Error("Root source mismatch");
    address(r.publisher, true);
    nonzero(r.artistConsent);
    nonzero(r.routeHash);
    same((p as TokenPreservationSnapshotV2CollectionPublication).contentRootRecord,
      tokenPreservationSnapshotV2RootRecordHash(c.chainId, d.targets[4], r, b), "Root record hash");
  }
  return f;
}

export interface TokenPreservationSnapshotV2Definition {
  readonly id: Hex;
  readonly kind: 0n | 1n | 2n;
  readonly hash: Hex;
  readonly byteLength: bigint;
  readonly data: Hex;
}
function definition(document: string, documentKind: 0n | 1n | 2n): TokenPreservationSnapshotV2Definition {
  const raw = toUtf8Bytes(document);
  const name = (JSON.parse(document) as { name: string }).name;
  return Object.freeze({ id: id(name) as Hex, kind: documentKind, hash: keccak256(raw) as Hex,
    byteLength: BigInt(raw.length), data: hexlify(raw) as Hex });
}
/** Exact source documents, including the collection schema larger than 8 KiB. */
export function tokenPreservationSnapshotV2Definitions(scopeKind: TokenPreservationSnapshotV2ScopeKind): readonly TokenPreservationSnapshotV2Definition[] {
  const docs = kind(scopeKind) === "collection"
    ? [COLLECTION_SCHEMA_DOCUMENT, COLLECTION_PROFILE_DOCUMENT, COLLECTION_CANONICALIZATION_DOCUMENT]
    : [SCOPED_SCHEMA_DOCUMENT, SCOPED_PROFILE_DOCUMENT, SCOPED_CANONICALIZATION_DOCUMENT];
  return Object.freeze([definition(docs[0]!, 0n), definition(docs[1]!, 2n), definition(docs[2]!, 1n)]);
}
/** Additional collection-only prerequisite definitions; this helper creates no root publication. */
export function tokenPreservationSnapshotV2RootDefinitions(): readonly TokenPreservationSnapshotV2Definition[] {
  return Object.freeze([definition(ROOT_SCHEMA_DOCUMENT, 0n), definition(ROOT_CANONICALIZATION_DOCUMENT, 1n)]);
}

function authority(value: TokenPreservationSnapshotV2Authority): TokenPreservationSnapshotV2Authority {
  exact(value, ["authorizationClass", "grantRevision", "displayAuthorizationClass", "displayGrantRevision"]);
  if (![7n, 8n].includes(value.authorizationClass) || ![7n, 8n].includes(value.displayAuthorizationClass)
    || !uint(value.grantRevision, 64) || !uint(value.displayGrantRevision, 64)) throw Error("Invalid independent Metadata grant facts");
  return Object.freeze({ ...value });
}
/** Supplied grant observations only; the original host chooses class 7 before class 8 independently per family. */
export function tokenPreservationSnapshotV2PreviewReceipt(
  coordinates: TokenPreservationSnapshotV2Coordinates,
  publication: TokenPreservationSnapshotV2Publication,
  publisher: Address,
  grants: TokenPreservationSnapshotV2Authority,
  sourceHash: Hex,
): TokenPreservationSnapshotV2Receipt {
  const c = normalizeTokenPreservationSnapshotV2Coordinates(coordinates);
  const p = validateTokenPreservationSnapshotV2Publication(c.scopeKind, publication, false);
  const defs = tokenPreservationSnapshotV2Definitions(c.scopeKind);
  return normalizeTokenPreservationSnapshotV2Receipt({
    recordHash: Z, scopeSubject: tokenPreservationSnapshotV2ScopeSubject(c.chainId, c.core, p.scope),
    predecessor: p.expectedHead, revision: p.expectedRevision + 1n, chainHash: Z, manifestHash: Z, manifestBytes: 0n,
    sourceHash: bytes(sourceHash, 32), publisher: address(publisher, true), ...authority(grants), recordedAt: 0n,
    schemaHash: defs[0]!.hash, profileHash: defs[1]!.hash, canonicalizationHash: defs[2]!.hash,
  });
}
function baseReceipt(r: TokenPreservationSnapshotV2Receipt): TokenPreservationSnapshotV2Receipt {
  return normalizeTokenPreservationSnapshotV2Receipt({ ...r, recordHash: Z, chainHash: Z, manifestHash: Z, manifestBytes: 0n, recordedAt: 0n });
}
export interface TokenPreservationSnapshotV2SnapshotPayload {
  readonly domain: Hex;
  readonly chainId: bigint;
  readonly snapshotHost: Address;
  readonly targets: TokenPreservationSnapshotV2Dependencies["targets"];
  readonly codeHashes: TokenPreservationSnapshotV2Dependencies["codeHashes"];
  readonly publication: TokenPreservationSnapshotV2Publication;
  readonly receipt: TokenPreservationSnapshotV2Receipt;
  readonly source: TokenPreservationSnapshotV2Source;
}
function payloadTypes(scopeKind: TokenPreservationSnapshotV2ScopeKind): readonly string[] {
  return ["bytes32", "uint256", "address", "address[11]", "bytes32[11]", publicationTuple(scopeKind),
    TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE, sourceTuple(scopeKind)];
}
/** Reproduces original preview normalization. Does not inspect grants, chunks or source freshness. */
export function tokenPreservationSnapshotV2SnapshotBytes(
  coordinates: TokenPreservationSnapshotV2Coordinates,
  dependencies: TokenPreservationSnapshotV2Dependencies,
  publication: TokenPreservationSnapshotV2Publication,
  receipt: TokenPreservationSnapshotV2Receipt,
  source: TokenPreservationSnapshotV2Source,
): Hex {
  const c = normalizeTokenPreservationSnapshotV2Coordinates(coordinates);
  const d = coordinateDependencies(c, dependencies);
  const p = normalizeTokenPreservationSnapshotV2Publication(c.scopeKind, publication);
  const f = normalizeTokenPreservationSnapshotV2Source(c.scopeKind, source);
  const r = baseReceipt(normalizeTokenPreservationSnapshotV2Receipt(receipt));
  return bytes(coder.encode(payloadTypes(c.scopeKind), [domain(c.scopeKind, "PAYLOAD"), c.chainId, c.snapshot,
    d.targets, d.codeHashes, { ...p, expectedSourceHash: Z },
    { ...r, sourceHash: tokenPreservationSnapshotV2SourceHash(c, d, f) }, f]), undefined,
  TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_PAYLOAD_BYTES);
}
export function decodeTokenPreservationSnapshotV2SnapshotBytes(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: Hex,
): TokenPreservationSnapshotV2SnapshotPayload {
  const raw = bytes(value, undefined, TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_PAYLOAD_BYTES);
  const types = payloadTypes(scopeKind);
  const decoded = coder.decode(types, raw);
  const values = types.map((t, i) => valueOf(ParamType.from(t), decoded[i], true));
  if (coder.encode(types, values).toLowerCase() !== raw) throw Error("Noncanonical snapshot payload");
  const [tag, chainId, snapshotHost, targets, codeHashes, publication, receipt, source] = values;
  const p = publication as TokenPreservationSnapshotV2Publication;
  const r = receipt as TokenPreservationSnapshotV2Receipt;
  if (tag !== domain(scopeKind, "PAYLOAD") || p.expectedSourceHash !== Z
    || r.recordHash !== Z || r.chainHash !== Z || r.manifestHash !== Z || r.manifestBytes !== 0n || r.recordedAt !== 0n) {
    throw Error("Invalid normalized snapshot payload");
  }
  const expected = hash(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", sourceTuple(scopeKind)],
    [domain(scopeKind, "SOURCES"), chainId, snapshotHost, targets, codeHashes, source]);
  same(r.sourceHash, expected, "Snapshot source hash");
  return Object.freeze({ domain: tag as Hex, chainId: chainId as bigint, snapshotHost: snapshotHost as Address,
    targets: targets as TokenPreservationSnapshotV2Dependencies["targets"], codeHashes: codeHashes as TokenPreservationSnapshotV2Dependencies["codeHashes"],
    publication: p, receipt: r, source: source as TokenPreservationSnapshotV2Source });
}
/** The original record hashes both receipt commitments/time but clears only recordHash and chainHash. */
export function tokenPreservationSnapshotV2RecordHash(
  coordinates: TokenPreservationSnapshotV2Coordinates,
  publication: TokenPreservationSnapshotV2Publication,
  receipt: TokenPreservationSnapshotV2Receipt,
): Hex {
  const c = normalizeTokenPreservationSnapshotV2Coordinates(coordinates);
  const p = normalizeTokenPreservationSnapshotV2Publication(c.scopeKind, publication);
  const r = normalizeTokenPreservationSnapshotV2Receipt(receipt);
  return hash(["bytes32", "uint256", "address", "address", "address", publicationTuple(c.scopeKind), TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE],
    [domain(c.scopeKind, "RECORD"), c.chainId, c.snapshot, c.core, c.metadata, p, { ...r, recordHash: Z, chainHash: Z }]);
}
export function tokenPreservationSnapshotV2ChainHash(
  coordinates: TokenPreservationSnapshotV2Coordinates,
  scope: TokenPreservationSnapshotV2Scope,
  predecessorChainHash: Hex,
  revision: bigint,
  recordHash: Hex,
): Hex {
  const c = normalizeTokenPreservationSnapshotV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE, "bytes32", "uint64", "bytes32"],
    [domain(c.scopeKind, "CHAIN"), c.chainId, c.snapshot, c.core, normalizeTokenPreservationSnapshotV2Scope(scope),
      bytes(predecessorChainHash, 32), uint(revision, 64), bytes(recordHash, 32)]);
}
/** Immutable record/payload/source joins only. The supplied predecessor chain needs its own provenance. */
export function authenticateTokenPreservationSnapshotV2History(
  coordinates: TokenPreservationSnapshotV2Coordinates,
  dependencies: TokenPreservationSnapshotV2Dependencies,
  publication: TokenPreservationSnapshotV2Publication,
  receipt: TokenPreservationSnapshotV2Receipt,
  canonical: Hex,
  predecessorChainHash: Hex,
) {
  const c = normalizeTokenPreservationSnapshotV2Coordinates(coordinates);
  const d = coordinateDependencies(c, dependencies);
  const p = validateTokenPreservationSnapshotV2Publication(c.scopeKind, publication);
  const r = normalizeTokenPreservationSnapshotV2Receipt(receipt);
  const payload = decodeTokenPreservationSnapshotV2SnapshotBytes(c.scopeKind, canonical);
  if ((p.expectedRevision === 0n) !== (p.expectedHead === Z) || (p.expectedHead === Z) !== (bytes(predecessorChainHash, 32) === Z)) {
    throw Error("Invalid snapshot predecessor/revision");
  }
  if (!r.recordedAt || p.effectiveAt > r.recordedAt || r.recordHash === Z || r.sourceHash === Z
    || r.manifestHash === Z || r.manifestBytes === 0n) throw Error("Incomplete historical snapshot receipt");
  const expected = tokenPreservationSnapshotV2PreviewReceipt(c, p, r.publisher, {
    authorizationClass: r.authorizationClass as 7n | 8n, grantRevision: r.grantRevision,
    displayAuthorizationClass: r.displayAuthorizationClass as 7n | 8n, displayGrantRevision: r.displayGrantRevision,
  }, p.expectedSourceHash);
  same(encodeTokenPreservationSnapshotV2Receipt(baseReceipt(r)), encodeTokenPreservationSnapshotV2Receipt(expected), "Recorded receipt fields");
  validateTokenPreservationSnapshotV2Source(c, d, p, payload.source);
  same(r.sourceHash, tokenPreservationSnapshotV2SourceHash(c, d, payload.source), "Historical source hash");
  const raw = tokenPreservationSnapshotV2SnapshotBytes(c, d, p, r, payload.source);
  same(raw, bytes(canonical, undefined, TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_PAYLOAD_BYTES), "Historical canonical payload");
  same(r.manifestHash, keccak256(raw), "Manifest hash");
  same(r.manifestBytes, BigInt((raw.length - 2) / 2), "Manifest length");
  same(r.recordHash, tokenPreservationSnapshotV2RecordHash(c, p, r), "Snapshot record hash");
  same(r.chainHash, tokenPreservationSnapshotV2ChainHash(c, p.scope, predecessorChainHash, r.revision, r.recordHash), "Snapshot chain hash");
  return Object.freeze({ coordinates: c, dependencies: d, publication: p, receipt: r, canonical: raw, payload,
    predecessorChainHash: bytes(predecessorChainHash, 32), currentnessChecked: false as const,
    authorityChecked: false as const, factsVerified: false as const });
}
export interface TokenPreservationSnapshotV2Chunk {
  readonly index: bigint;
  readonly data: Hex;
  readonly hash: Hex;
  readonly byteLength: bigint;
  readonly runtime: Hex;
  readonly runtimeHash: Hex;
}
/** Preupload requirements only. Store availability is enforced by publish, not by preview. */
export function tokenPreservationSnapshotV2Chunks(canonical: Hex): readonly TokenPreservationSnapshotV2Chunk[] {
  const raw = bytes(canonical, undefined, TOKEN_PRESERVATION_SNAPSHOT_V2_MAX_PAYLOAD_BYTES);
  if (raw === "0x") throw Error("Empty snapshot payload");
  const result: TokenPreservationSnapshotV2Chunk[] = [];
  for (let offset = 2; offset < raw.length; offset += TOKEN_PRESERVATION_SNAPSHOT_V2_SEGMENT_BYTES * 2) {
    const data = ("0x" + raw.slice(offset, offset + TOKEN_PRESERVATION_SNAPSHOT_V2_SEGMENT_BYTES * 2)) as Hex;
    const runtime = ("0x00" + data.slice(2)) as Hex;
    result.push(Object.freeze({ index: BigInt(result.length), data, hash: keccak256(data) as Hex,
      byteLength: BigInt((data.length - 2) / 2), runtime, runtimeHash: keccak256(runtime) as Hex }));
  }
  return Object.freeze(result);
}

const COMMON_ABI = Object.freeze([
  `function dependencies() view returns (${TOKEN_PRESERVATION_SNAPSHOT_V2_DEPENDENCIES_TUPLE} d)`,
  "function core() view returns (address)",
  "function metadataHost() view returns (address)",
  "function authorityCodeHash() view returns (bytes32)",
  "function governanceAuthority() view returns (address)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  `function currentSnapshot(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE} scope) view returns (${TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE})`,
  `function requireCurrent(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE} scope,bytes32 hash,uint64 revision) view returns (${TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE} r)`,
  "function snapshotPayload(bytes32 hash) view returns (bytes)",
  `function snapshotLock(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE} scope) view returns (${TOKEN_PRESERVATION_SNAPSHOT_V2_LOCK_TUPLE})`,
  `function snapshotCount(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE} scope) view returns (uint256)`,
  `function snapshotAt(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE} scope,uint256 index) view returns (bytes32)`,
]);
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_ABI = Object.freeze([
  ...COMMON_ABI,
  "function preservationPolicySnapshotProfile() pure returns (bytes32)",
  `function previewSnapshot(${TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PUBLICATION_TUPLE} p,address publisher) view returns (bytes32 sourceHash,bytes canonical)`,
  `function publishSnapshot(${TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PUBLICATION_TUPLE} p) returns (bytes32 hash)`,
  `function snapshotRecord(bytes32 hash) view returns (${TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PUBLICATION_TUPLE},${TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE})`,
  "function snapshotChunkCount(bytes32 hash) view returns (uint256)",
  "function snapshotChunkAt(bytes32 hash,uint256 index) view returns (address pointer,bytes32 chunkHash,uint32 byteLength)",
  `event PolicySnapshotPublished(uint16 schemaVersion,bytes32 indexed scopeSubject,bytes32 indexed snapshotId,bytes32 indexed recordHash,${TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PUBLICATION_TUPLE} publication,${TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE} receipt)`,
]);
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_ABI = Object.freeze([
  ...COMMON_ABI,
  "function scopedPreservationPolicySnapshotProfile() pure returns (bytes32)",
  `function previewSnapshot(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PUBLICATION_TUPLE} p,address publisher) view returns (bytes32 sourceHash,bytes canonical)`,
  `function publishSnapshot(${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PUBLICATION_TUPLE} p) returns (bytes32 hash)`,
  `function snapshotRecord(bytes32 hash) view returns (${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PUBLICATION_TUPLE},${TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE})`,
  `event ScopedPolicySnapshotPublished(uint16 schemaVersion,bytes32 indexed scopeSubject,bytes32 indexed snapshotId,bytes32 indexed recordHash,${TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PUBLICATION_TUPLE} publication,${TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE} receipt)`,
]);
export function tokenPreservationSnapshotV2Interface(scopeKind: TokenPreservationSnapshotV2ScopeKind): Interface {
  return new Interface(kind(scopeKind) === "collection" ? TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_ABI : TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_ABI);
}
export interface TokenPreservationSnapshotV2Request {
  readonly kind: "publishSnapshot";
  readonly publication: TokenPreservationSnapshotV2Publication;
}
export interface TokenPreservationSnapshotV2Call {
  readonly coordinates: TokenPreservationSnapshotV2Coordinates;
  readonly caller: Address;
  readonly request: TokenPreservationSnapshotV2Request;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}
export function normalizeTokenPreservationSnapshotV2Request(
  scopeKind: TokenPreservationSnapshotV2ScopeKind,
  value: TokenPreservationSnapshotV2Request,
): TokenPreservationSnapshotV2Request {
  exact(value, ["kind", "publication"]);
  if (value.kind !== "publishSnapshot") throw Error("Unsupported snapshot mutation");
  return Object.freeze({ kind: value.kind, publication: validateTokenPreservationSnapshotV2Publication(scopeKind, value.publication) });
}
export function prepareTokenPreservationSnapshotV2Call(
  coordinates: TokenPreservationSnapshotV2Coordinates,
  caller: Address,
  input: TokenPreservationSnapshotV2Request,
): TokenPreservationSnapshotV2Call {
  const c = normalizeTokenPreservationSnapshotV2Coordinates(coordinates);
  const request = normalizeTokenPreservationSnapshotV2Request(c.scopeKind, input);
  return Object.freeze({ coordinates: c, caller: address(caller, true), request,
    call: Object.freeze({ to: c.snapshot, data: bytes(tokenPreservationSnapshotV2Interface(c.scopeKind).encodeFunctionData(request.kind, [request.publication])), value: 0n }),
    factsVerified: false });
}
export function normalizeTokenPreservationSnapshotV2Call(value: TokenPreservationSnapshotV2Call): TokenPreservationSnapshotV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"]);
  exact(value.call, ["to", "data", "value"]);
  const result = prepareTokenPreservationSnapshotV2Call(value.coordinates, value.caller, value.request);
  if (address(value.call.to) !== result.call.to || bytes(value.call.data) !== result.call.data
    || uint(value.call.value) !== 0n || value.factsVerified !== false) throw Error("Snapshot call reconstruction mismatch");
  return result;
}
export type TokenPreservationSnapshotV2ReadRequest =
  | { readonly kind: "previewSnapshot"; readonly publication: TokenPreservationSnapshotV2Publication; readonly publisher: Address }
  | { readonly kind: "currentSnapshot" | "snapshotLock" | "snapshotCount"; readonly scope: TokenPreservationSnapshotV2Scope }
  | { readonly kind: "requireCurrent"; readonly scope: TokenPreservationSnapshotV2Scope; readonly recordHash: Hex; readonly revision: bigint }
  | { readonly kind: "snapshotAt"; readonly scope: TokenPreservationSnapshotV2Scope; readonly index: bigint }
  | { readonly kind: "snapshotRecord" | "snapshotPayload" | "snapshotChunkCount"; readonly recordHash: Hex }
  | { readonly kind: "snapshotChunkAt"; readonly recordHash: Hex; readonly index: bigint }
  | { readonly kind: "supportsInterface"; readonly interfaceId: Hex }
  | { readonly kind: "dependencies" | "core" | "metadataHost" | "authorityCodeHash" | "governanceAuthority" | "preservationPolicySnapshotProfile" | "scopedPreservationPolicySnapshotProfile" };
export interface TokenPreservationSnapshotV2Read {
  readonly coordinates: TokenPreservationSnapshotV2Coordinates;
  readonly caller: Address;
  readonly request: TokenPreservationSnapshotV2ReadRequest;
  readonly call: UnsignedCall;
}
export function prepareTokenPreservationSnapshotV2Read(
  coordinates: TokenPreservationSnapshotV2Coordinates,
  caller: Address,
  input: TokenPreservationSnapshotV2ReadRequest,
): TokenPreservationSnapshotV2Read {
  const c = normalizeTokenPreservationSnapshotV2Coordinates(coordinates);
  let fields: readonly string[];
  let args: readonly unknown[] = [];
  const normalized: Record<string, unknown> = { kind: input.kind };
  switch (input.kind) {
    case "previewSnapshot":
      fields = ["publication", "publisher"];
      normalized.publication = validateTokenPreservationSnapshotV2Publication(c.scopeKind, input.publication, false);
      normalized.publisher = address(input.publisher, true);
      args = [normalized.publication, normalized.publisher];
      break;
    case "currentSnapshot": case "snapshotLock": case "snapshotCount": case "requireCurrent": case "snapshotAt":
      fields = ["scope"];
      normalized.scope = validateTokenPreservationSnapshotV2Scope(c.scopeKind, input.scope);
      args = [normalized.scope];
      if (input.kind === "requireCurrent") {
        fields = [...fields, "recordHash", "revision"];
        normalized.recordHash = bytes(input.recordHash, 32);
        normalized.revision = uint(input.revision, 64);
        args = [...args, normalized.recordHash, normalized.revision];
      } else if (input.kind === "snapshotAt") {
        fields = [...fields, "index"];
        normalized.index = uint(input.index);
        args = [...args, normalized.index];
      }
      break;
    case "snapshotRecord": case "snapshotPayload": case "snapshotChunkCount": case "snapshotChunkAt":
      if (input.kind.startsWith("snapshotChunk") && c.scopeKind !== "collection") throw Error("Scoped snapshot has no chunk getters");
      fields = ["recordHash"];
      normalized.recordHash = bytes(input.recordHash, 32);
      args = [normalized.recordHash];
      if (input.kind === "snapshotChunkAt") {
        fields = [...fields, "index"];
        normalized.index = uint(input.index);
        args = [...args, normalized.index];
      }
      break;
    case "supportsInterface":
      fields = ["interfaceId"];
      normalized.interfaceId = bytes(input.interfaceId, 4);
      args = [normalized.interfaceId];
      break;
    case "dependencies": case "core": case "metadataHost": case "authorityCodeHash": case "governanceAuthority":
      fields = [];
      break;
    case "preservationPolicySnapshotProfile": case "scopedPreservationPolicySnapshotProfile":
      if ((input.kind === "preservationPolicySnapshotProfile") !== (c.scopeKind === "collection")) throw Error("Wrong snapshot profile getter");
      fields = [];
      break;
    default: throw Error("Unsupported snapshot read");
  }
  exact(input, ["kind", ...fields]);
  const request = Object.freeze(normalized) as unknown as TokenPreservationSnapshotV2ReadRequest;
  return Object.freeze({ coordinates: c, caller: address(caller), request,
    call: Object.freeze({ to: c.snapshot, data: bytes(tokenPreservationSnapshotV2Interface(c.scopeKind).encodeFunctionData(input.kind, args)), value: 0n }) });
}
export function normalizeTokenPreservationSnapshotV2Read(value: TokenPreservationSnapshotV2Read): TokenPreservationSnapshotV2Read {
  exact(value, ["coordinates", "caller", "request", "call"]);
  exact(value.call, ["to", "data", "value"]);
  const result = prepareTokenPreservationSnapshotV2Read(value.coordinates, value.caller, value.request);
  if (address(value.call.to) !== result.call.to || bytes(value.call.data) !== result.call.data || uint(value.call.value) !== 0n) throw Error("Snapshot read reconstruction mismatch");
  return result;
}

export function normalizeTokenPreservationSnapshotV2Scope(value: TokenPreservationSnapshotV2Scope): TokenPreservationSnapshotV2Scope {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2Scope(value: TokenPreservationSnapshotV2Scope): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2Scope(value: Hex): TokenPreservationSnapshotV2Scope {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPE_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2Dependencies(value: TokenPreservationSnapshotV2Dependencies): TokenPreservationSnapshotV2Dependencies {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_DEPENDENCIES_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2Dependencies(value: TokenPreservationSnapshotV2Dependencies): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_DEPENDENCIES_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2Dependencies(value: Hex): TokenPreservationSnapshotV2Dependencies {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_DEPENDENCIES_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2Membership(value: TokenPreservationSnapshotV2Membership): TokenPreservationSnapshotV2Membership {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_MEMBERSHIP_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2Membership(value: TokenPreservationSnapshotV2Membership): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_MEMBERSHIP_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2Membership(value: Hex): TokenPreservationSnapshotV2Membership {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_MEMBERSHIP_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2Policy(value: TokenPreservationSnapshotV2Policy): TokenPreservationSnapshotV2Policy {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_POLICY_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2Policy(value: TokenPreservationSnapshotV2Policy): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_POLICY_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2Policy(value: Hex): TokenPreservationSnapshotV2Policy {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_POLICY_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2CoordinatorPolicy(value: TokenPreservationSnapshotV2CoordinatorPolicy): TokenPreservationSnapshotV2CoordinatorPolicy {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_COORDINATOR_POLICY_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2CoordinatorPolicy(value: TokenPreservationSnapshotV2CoordinatorPolicy): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_COORDINATOR_POLICY_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2CoordinatorPolicy(value: Hex): TokenPreservationSnapshotV2CoordinatorPolicy {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_COORDINATOR_POLICY_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2PolicyEvidence(value: TokenPreservationSnapshotV2PolicyEvidence): TokenPreservationSnapshotV2PolicyEvidence {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_POLICY_EVIDENCE_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2PolicyEvidence(value: TokenPreservationSnapshotV2PolicyEvidence): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_POLICY_EVIDENCE_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2PolicyEvidence(value: Hex): TokenPreservationSnapshotV2PolicyEvidence {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_POLICY_EVIDENCE_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2ArtistPresentation(value: TokenPreservationSnapshotV2ArtistPresentation): TokenPreservationSnapshotV2ArtistPresentation {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_ARTIST_PRESENTATION_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2ArtistPresentation(value: TokenPreservationSnapshotV2ArtistPresentation): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_ARTIST_PRESENTATION_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2ArtistPresentation(value: Hex): TokenPreservationSnapshotV2ArtistPresentation {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_ARTIST_PRESENTATION_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2SelectionPlan(value: TokenPreservationSnapshotV2SelectionPlan): TokenPreservationSnapshotV2SelectionPlan {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_SELECTION_PLAN_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2SelectionPlan(value: TokenPreservationSnapshotV2SelectionPlan): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_SELECTION_PLAN_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2SelectionPlan(value: Hex): TokenPreservationSnapshotV2SelectionPlan {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_SELECTION_PLAN_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2ContentPlan(value: TokenPreservationSnapshotV2ContentPlan): TokenPreservationSnapshotV2ContentPlan {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_CONTENT_PLAN_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2ContentPlan(value: TokenPreservationSnapshotV2ContentPlan): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_CONTENT_PLAN_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2ContentPlan(value: Hex): TokenPreservationSnapshotV2ContentPlan {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_CONTENT_PLAN_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2Manifest(value: TokenPreservationSnapshotV2Manifest): TokenPreservationSnapshotV2Manifest {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_MANIFEST_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2Manifest(value: TokenPreservationSnapshotV2Manifest): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_MANIFEST_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2Manifest(value: Hex): TokenPreservationSnapshotV2Manifest {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_MANIFEST_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2RootPublication(value: TokenPreservationSnapshotV2RootPublication): TokenPreservationSnapshotV2RootPublication {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_PUBLICATION_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2RootPublication(value: TokenPreservationSnapshotV2RootPublication): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_PUBLICATION_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2RootPublication(value: Hex): TokenPreservationSnapshotV2RootPublication {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_PUBLICATION_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2RootRecord(value: TokenPreservationSnapshotV2RootRecord): TokenPreservationSnapshotV2RootRecord {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_RECORD_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2RootRecord(value: TokenPreservationSnapshotV2RootRecord): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_RECORD_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2RootRecord(value: Hex): TokenPreservationSnapshotV2RootRecord {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_RECORD_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2RootBinding(value: TokenPreservationSnapshotV2RootBinding): TokenPreservationSnapshotV2RootBinding {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_BINDING_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2RootBinding(value: TokenPreservationSnapshotV2RootBinding): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_BINDING_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2RootBinding(value: Hex): TokenPreservationSnapshotV2RootBinding {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_BINDING_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2CollectionPublication(value: TokenPreservationSnapshotV2CollectionPublication): TokenPreservationSnapshotV2CollectionPublication {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PUBLICATION_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2CollectionPublication(value: TokenPreservationSnapshotV2CollectionPublication): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PUBLICATION_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2CollectionPublication(value: Hex): TokenPreservationSnapshotV2CollectionPublication {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PUBLICATION_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2ScopedPublication(value: TokenPreservationSnapshotV2ScopedPublication): TokenPreservationSnapshotV2ScopedPublication {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PUBLICATION_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2ScopedPublication(value: TokenPreservationSnapshotV2ScopedPublication): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PUBLICATION_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2ScopedPublication(value: Hex): TokenPreservationSnapshotV2ScopedPublication {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PUBLICATION_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2CollectionSource(value: TokenPreservationSnapshotV2CollectionSource): TokenPreservationSnapshotV2CollectionSource {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_SOURCE_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2CollectionSource(value: TokenPreservationSnapshotV2CollectionSource): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_SOURCE_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2CollectionSource(value: Hex): TokenPreservationSnapshotV2CollectionSource {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_SOURCE_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2ScopedSource(value: TokenPreservationSnapshotV2ScopedSource): TokenPreservationSnapshotV2ScopedSource {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_SOURCE_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2ScopedSource(value: TokenPreservationSnapshotV2ScopedSource): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_SOURCE_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2ScopedSource(value: Hex): TokenPreservationSnapshotV2ScopedSource {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_SOURCE_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2Receipt(value: TokenPreservationSnapshotV2Receipt): TokenPreservationSnapshotV2Receipt {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2Receipt(value: TokenPreservationSnapshotV2Receipt): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2Receipt(value: Hex): TokenPreservationSnapshotV2Receipt {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE, value);
}

export function normalizeTokenPreservationSnapshotV2Lock(value: TokenPreservationSnapshotV2Lock): TokenPreservationSnapshotV2Lock {
  return normalize(TOKEN_PRESERVATION_SNAPSHOT_V2_LOCK_TUPLE, value);
}
export function encodeTokenPreservationSnapshotV2Lock(value: TokenPreservationSnapshotV2Lock): Hex {
  return encode(TOKEN_PRESERVATION_SNAPSHOT_V2_LOCK_TUPLE, value);
}
export function decodeTokenPreservationSnapshotV2Lock(value: Hex): TokenPreservationSnapshotV2Lock {
  return decode(TOKEN_PRESERVATION_SNAPSHOT_V2_LOCK_TUPLE, value);
}

const COLLECTION_SCHEMA_DOCUMENT = "{\"name\":\"STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V2\",\"version\":2,\"encoding\":\"Solidity ABI\",\"payloadDomain\":\"6529STREAM_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2\",\"payload\":[\"bytes32 domain\",\"uint256 chainId\",\"address snapshotHost\",\"address[11] targets\",\"bytes32[11] codeHashes\",\"Publication publication\",\"Receipt receipt\",\"Source source\"],\"types\":[{\"components\":[{\"internalType\":\"address[11]\",\"name\":\"targets\",\"type\":\"address[11]\"},{\"internalType\":\"bytes32[11]\",\"name\":\"codeHashes\",\"type\":\"bytes32[11]\"},{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"readGas\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"sourceGas\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"inventoryGas\",\"type\":\"uint256\"}],\"internalType\":\"struct StreamPreservationPolicySnapshotTypesV1.Dependencies\",\"name\":\"dependencies\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"expectedHead\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"expectedRevision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"outputManifestRecord\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentRootRecord\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"coordinatorInventoryPlan\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"expectedSourceHash\",\"type\":\"bytes32\"},{\"internalType\":\"string\",\"name\":\"manifestURI\",\"type\":\"string\"},{\"internalType\":\"uint64\",\"name\":\"effectiveAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"reasonHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamPreservationPolicySnapshotTypesV1.Publication\",\"name\":\"publication\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"recordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"scopeSubject\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"predecessor\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"revision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"chainHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"manifestBytes\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"sourceHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"publisher\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"authorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"grantRevision\",\"type\":\"uint64\"},{\"internalType\":\"uint8\",\"name\":\"displayAuthorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"displayGrantRevision\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"recordedAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"schemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profileHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"canonicalizationHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamPreservationPolicySnapshotTypesV1.Receipt\",\"name\":\"receipt\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"scopeSubject\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"scopeManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sourceRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"tokenCount\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"tokenListHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"membershipHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"inventoryCount\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryPrefixHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamScopeMembershipFacts\",\"name\":\"membership\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bool\",\"name\":\"locked\",\"type\":\"bool\"},{\"internalType\":\"address\",\"name\":\"registry\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"registryCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"bindingGeneration\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"bindingHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"nominatedArtist\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"identityRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"acceptanceRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"acceptedAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"lockedAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamMetadataServingFacts.ArtistPresentation\",\"name\":\"artist\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"membershipHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"collectionStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"tokenCount\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nextIndex\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"selectionRoot\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamStaticSelectionCheckpoint.Plan\",\"name\":\"selection\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"selectionId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"selectionHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"uint64\",\"name\":\"tokenCount\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nextIndex\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"leafChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"preservationProfile\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamPreservationPolicyContentCheckpointV1.Plan\",\"name\":\"content\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"entropySourceSet\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"metadataRouter\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"preservationProfile\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artifactHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"uint64\",\"name\":\"tokenCount\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"byteLength\",\"type\":\"uint64\"}],\"internalType\":\"struct IStreamPreservationPolicyOutputManifestV1.Manifest\",\"name\":\"outputs\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"expectedPredecessor\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"verifiedManifestRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"string\",\"name\":\"manifestURI\",\"type\":\"string\"}],\"internalType\":\"struct IStreamContentRootPublication.Publication\",\"name\":\"publication\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"contentRoot\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"leafCount\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"bindingGeneration\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"bindingHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"publisher\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"authorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"grantRevision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"routeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"stateHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistConsent\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"publishedAt\",\"type\":\"uint64\"}],\"internalType\":\"struct IStreamContentRootPublication.Record\",\"name\":\"root\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"profileId\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"outputManifest\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"outputManifestCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"checkpoint\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"entropySourceSet\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"entropySourceSetCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputCanonicalizationHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"leafSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rootSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rootCanonicalizationHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"metadataRouter\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"preservationOutputProfile\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamPreservationPolicyContentRootPublicationV1.Binding\",\"name\":\"rootBinding\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"planId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"policyCount\",\"type\":\"uint256\"},{\"internalType\":\"bool\",\"name\":\"allFrozen\",\"type\":\"bool\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"coordinator\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"indexedCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"firstTokenIndex\",\"type\":\"uint256\"},{\"internalType\":\"bool\",\"name\":\"frozen\",\"type\":\"bool\"},{\"internalType\":\"bytes32\",\"name\":\"moduleVersion\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"moduleManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"moduleSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"deploymentManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"provider\",\"type\":\"address\"},{\"internalType\":\"uint32\",\"name\":\"epoch\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"salt\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"componentDataHash\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"explicitPolicy\",\"type\":\"bool\"},{\"components\":[{\"internalType\":\"bool\",\"name\":\"configured\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"explicitPolicy\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"frozen\",\"type\":\"bool\"},{\"internalType\":\"uint8\",\"name\":\"mode\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"securityClass\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"renderRequirement\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"revision\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"providerEpoch\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"policyHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"lastActionId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistConsentRecord\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamEntropyPolicyConsumerTypes.Policy\",\"name\":\"collectionPolicy\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamFinalityCoordinatorPolicyV2[]\",\"name\":\"policies\",\"type\":\"tuple[]\"}],\"internalType\":\"struct StreamFinalityCoordinatorPolicyEvidenceV2\",\"name\":\"entropy\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamPreservationPolicySnapshotTypesV1.Source\",\"name\":\"source\",\"type\":\"tuple\"}],\"canonical\":\"Compiler encoding exactly; alternate offsets, padding or trailing bytes forbidden. Publication.expectedSourceHash is zero in payload; receipt.sourceHash holds the complete current source commitment. Receipt.recordHash,chainHash,manifestHash,manifestBytes,recordedAt are zero in payload.\",\"preservation\":\"Complete per-member admitted producer bindings and original Registry admissions are committed by the current output root. Only ADR0054 sanction display is projected; original live profiles are unchanged.\",\"preservationFamily\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2\",\"tokenProducerProfiles\":[\"6529STREAM_PRESERVATION_RENDER_V1\",\"6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1\"],\"familySemantics\":\"Checkpoint and complete output manifest carry the fixed family marker; each token row retains exactly one admitted original or current-Artist producer marker. VIEW and all other producer markers are excluded. Existing V1 definitions and tuple shapes remain unchanged.\",\"checkpointProfile\":\"6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2\",\"outputManifestProfile\":\"6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2\"}";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_SCHEMA_ID = id("STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V2") as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_SCHEMA_HASH = keccak256(toUtf8Bytes(COLLECTION_SCHEMA_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_SCHEMA_BYTES = 15067;
const COLLECTION_PROFILE_DOCUMENT = "{\"name\":\"STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_PROFILE_V2\",\"version\":2,\"scope\":\"COLLECTION only; complete admitted preservation output for every original frozen ONCHAIN STATIC selection.\",\"sources\":\"Original Core and selected Metadata/Router; locked original Artist presentation; complete membership and new preservation output manifest, canonical prior preservation Router CONTENT_ROOT, original-source policy inventory and every frozen full policy row. All original V1/V2 records retain their meanings.\",\"authority\":\"Selected Metadata SNAPSHOT and IDENTITY collection class7 or global class8; exact class2 terminal snapshot lock\",\"limits\":{\"payloadBytes\":524288,\"chunkBytes\":8192,\"maximumPolicyRows\":630},\"current\":\"Revalidate all dependency runtimes, exact ACTIVE schemas, current complete output and original-source policy set, canonical Router root and complete retained payload. Historical records remain immutable.\",\"unproven\":\"Snapshot is not complete output-byte archival coverage or reference/finality mode acceptance; those distinct consumers are required.\",\"capability\":\"6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V2\",\"rootTopology\":\"Original Artist-authorized preservation CONTENT_ROOT is adopted before this snapshot. Snapshot writer grants do not replace original root authorization.\",\"preservationFamily\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2\",\"tokenProducerProfiles\":[\"6529STREAM_PRESERVATION_RENDER_V1\",\"6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1\"],\"familySemantics\":\"Checkpoint and complete output manifest carry the fixed family marker; each token row retains exactly one admitted original or current-Artist producer marker. VIEW and all other producer markers are excluded. Existing V1 definitions and tuple shapes remain unchanged.\",\"checkpointProfile\":\"6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2\",\"outputManifestProfile\":\"6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2\"}";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PROFILE_ID = id("STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_PROFILE_V2") as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PROFILE_HASH = keccak256(toUtf8Bytes(COLLECTION_PROFILE_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_PROFILE_BYTES = 1921;
const COLLECTION_CANONICALIZATION_DOCUMENT = "{\"name\":\"STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V2\",\"version\":2,\"encoding\":\"abi.encode(payloadDomain,chainId,snapshotHost,targets,codeHashes,publication,receipt,source)\",\"payloadDomain\":\"keccak256(6529STREAM_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2)\",\"sourceHash\":\"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2),chainId,snapshotHost,targets,codeHashes,source))\",\"recordHash\":\"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_SNAPSHOT_RECORD_V2),chainId,snapshotHost,Core,Metadata,publication,receiptWithRecordHashAndChainHashZero))\",\"chainHash\":\"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_SNAPSHOT_CHAIN_V2),chainId,snapshotHost,Core,scope,previousChainHash,revision,recordHash))\",\"canonical\":\"Exact compiler ABI with original UTF8 strings; no JSON canonicalization of the payload; full ordered chunk reconstruction and Keccak equality.\"}";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_CANONICALIZATION_ID = id("STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V2") as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_CANONICALIZATION_HASH = keccak256(toUtf8Bytes(COLLECTION_CANONICALIZATION_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_CANONICALIZATION_BYTES = 917;
const SCOPED_SCHEMA_DOCUMENT = "{\"name\":\"STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V2\",\"version\":2,\"format\":\"Solidity ABI\",\"scope\":\"Canonical TOKEN, RELEASE or SEASON only; COLLECTION and VIEW are excluded\",\"dependencies\":[\"Core\",\"Metadata\",\"schemas\",\"Store\",\"Router\",\"scope membership\",\"STATIC selection checkpoint\",\"scoped-policy content checkpoint\",\"scoped-policy output manifest\",\"artifact coverage\",\"immutable full-policy source set\"],\"publication\":[\"StreamFinalityScope scope\",\"bytes32 snapshotId\",\"bytes32 expectedHead\",\"uint64 expectedRevision\",\"bytes32 outputManifestRecord\",\"bytes32 coordinatorInventoryPlan\",\"bytes32 expectedSourceHash\",\"string manifestURI\",\"uint64 effectiveAt\",\"bytes32 reasonHash\"],\"receipt\":[\"bytes32 recordHash\",\"bytes32 scopeSubject\",\"bytes32 predecessor\",\"uint64 revision\",\"bytes32 chainHash\",\"bytes32 manifestHash\",\"uint32 manifestBytes\",\"bytes32 sourceHash\",\"address publisher\",\"uint8 authorizationClass\",\"uint64 grantRevision\",\"uint8 displayAuthorizationClass\",\"uint64 displayGrantRevision\",\"uint64 recordedAt\",\"bytes32 schemaHash\",\"bytes32 profileHash\",\"bytes32 canonicalizationHash\"],\"source\":[\"StreamFinalityScope scope\",\"StreamScopeMembershipFacts membership\",\"IStreamMetadataServingFacts.ArtistPresentation artist\",\"IStreamStaticSelectionCheckpoint.Plan selection\",\"IStreamPreservationPolicyContentCheckpointV1.Plan content\",\"IStreamPreservationPolicyOutputManifestV1.Manifest outputs\",\"address sourceFactory\",\"bytes32 sourceFactoryCodeHash\",\"bytes32 factoryDependenciesHash\",\"StreamFinalityCoordinatorPolicyEvidenceV2 entropy\"],\"scopeTuple\":\"uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId\",\"membership\":\"bytes32 scopeSubject,bytes32 scopeManifestHash,bytes32 sourceRecordHash,uint256 tokenCount,bytes32 tokenListHash,bytes32 membershipHash,uint256 inventoryCount,bytes32 inventoryPrefixHash\",\"artist\":\"bool locked,address registry,bytes32 registryCodeHash,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address nominatedArtist,bytes32 identityRecordHash,bytes32 acceptanceRecordHash,uint64 acceptedAt,uint64 lockedAt,bytes32 snapshotHash\",\"selection\":\"StreamFinalityScope scope,bytes32 membershipHash,bytes32 collectionStateHash,uint64 tokenCount,uint64 nextIndex,bytes32 selectionRoot\",\"content\":\"bytes32 selectionId,bytes32 selectionHash,bytes32 inventoryHash,bytes32 policyChainHash,StreamFinalityScope scope,uint64 tokenCount,uint64 nextIndex,bytes32 leafChainHash,bytes32 contentRoot,bytes32 outputRoot,bytes32 preservationProfile\",\"outputs\":\"bytes32 checkpointHash,bytes32 checkpointStateHash,address entropySourceSet,bytes32 inventoryHash,bytes32 policyChainHash,address metadataRouter,bytes32 preservationProfile,bytes32 artifactHash,bytes32 coverageHash,bytes32 artistId,bytes32 contentRoot,bytes32 outputRoot,bytes32 manifestHash,StreamFinalityScope scope,uint64 tokenCount,uint64 byteLength\",\"entropy\":\"bytes32 planId,bytes32 inventoryHash,bytes32 policyChainHash,uint256 policyCount,bool allFrozen,StreamFinalityCoordinatorPolicyV2[] policies\",\"policyRow\":\"address coordinator,bytes32 indexedCodeHash,uint256 firstTokenIndex,bool frozen,bytes32 moduleVersion,bytes32 moduleManifestHash,bytes32 moduleSchemaHash,bytes32 deploymentManifestHash,bytes32 policyHash,address provider,uint32 epoch,bytes32 salt,bytes32 componentDataHash,bool explicitPolicy,Policy collectionPolicy\",\"collectionPolicy\":\"bool configured,bool explicitPolicy,bool frozen,uint8 mode,uint8 securityClass,uint8 renderRequirement,uint64 revision,uint32 providerEpoch,bytes32 policyHash,bytes32 contentStateHash,bytes32 lastActionId,bytes32 artistConsentRecord\",\"root\":\"No root record or authority appears in this source payload; separate scoped CONTENT_ROOT adoption follows publication\",\"preservation\":\"Complete ordered output root binds every member-specific9word producer binding and7word governed admission. Exact current preservation output excludes only sanction display under ADR0054. Mixed selected renderers remain complete members.\",\"preservationFamily\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2\",\"tokenProducerProfiles\":[\"6529STREAM_PRESERVATION_RENDER_V1\",\"6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1\"],\"familySemantics\":\"Checkpoint and complete output manifest carry the fixed family marker; each token row retains exactly one admitted original or current-Artist producer marker. VIEW and all other producer markers are excluded. Existing V1 definitions and tuple shapes remain unchanged.\",\"checkpointProfile\":\"6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2\",\"outputManifestProfile\":\"6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2\"}";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_SCHEMA_ID = id("STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V2") as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_SCHEMA_HASH = keccak256(toUtf8Bytes(SCOPED_SCHEMA_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_SCHEMA_BYTES = 4598;
const SCOPED_PROFILE_DOCUMENT = "{\"name\":\"STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PROFILE_V2\",\"version\":2,\"capability\":\"6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2\",\"scope\":\"Complete positive canonical TOKEN, RELEASE or SEASON membership; no COLLECTION or VIEW reinterpretation\",\"sources\":\"Exact fixed dependencies and new scoped preservation checkpoint/output profiles; complete original factory policy evidence, actual selected per-member producer bindings and immutable governed source/read admissions.\",\"entropy\":\"Original status1/2 terminal evidence remains distinct from actual status5 finalized seed; independent terminal program admission is retained by the complete output record\",\"authority\":\"SNAPSHOT and IDENTITY families each require original Metadata class7 collection or class8 global writer; neither grants Artist CONTENT_ROOT authority\",\"lineage\":\"Exact scope subject, next revision, predecessor and unique snapshotId; current reads reconstruct exact payload and revalidate the complete output/policy sources\",\"lock\":\"Exact governance class2 action and current head; immutable historical receipts/payload remain readable after source drift\",\"preservation\":\"Exact snapshot bytes are retained in the original Store; output manifest covers commitments rather than full rendered bytes\",\"bound\":\"Complete canonical payload at most524288 bytes; policyCount positive and at most630 before allocation\",\"projection\":\"Only sanction lookup and derived display fields are excluded; all other original facts remain current. Live output and every original V2 profile retain their meanings.\",\"preservationFamily\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2\",\"tokenProducerProfiles\":[\"6529STREAM_PRESERVATION_RENDER_V1\",\"6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1\"],\"familySemantics\":\"Checkpoint and complete output manifest carry the fixed family marker; each token row retains exactly one admitted original or current-Artist producer marker. VIEW and all other producer markers are excluded. Existing V1 definitions and tuple shapes remain unchanged.\",\"checkpointProfile\":\"6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2\",\"outputManifestProfile\":\"6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2\"}";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PROFILE_ID = id("STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PROFILE_V2") as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PROFILE_HASH = keccak256(toUtf8Bytes(SCOPED_PROFILE_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_PROFILE_BYTES = 2192;
const SCOPED_CANONICALIZATION_DOCUMENT = "{\"name\":\"STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2\",\"version\":2,\"encoding\":\"abi.encode(bytes32 domain,uint256 chainId,address snapshotHost,address[11] targets,bytes32[11] codeHashes,Publication publication,Receipt receipt,Source source)\",\"domain\":\"keccak256(6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2)\",\"normalization\":\"publication.expectedSourceHash=0; receipt.recordHash,chainHash,manifestHash,manifestBytes,recordedAt=0; receipt.sourceHash is the actual complete source hash; other fields retained exactly\",\"sourceHash\":\"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2),chainId,snapshotHost,targets,codeHashes,source))\",\"bytes\":\"Canonical Solidity0.8.19 ABI; exact tuple re-encoding, array order and complete bytes; no alternate offsets or trailing bytes\",\"hash\":\"Keccak-256 of exact retained payload, not JSON canonicalization\",\"chunks\":\"Contiguous original8192-byte Store segments, final segment exact residual length; at most524288 bytes\"}";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_CANONICALIZATION_ID = id("STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2") as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_CANONICALIZATION_HASH = keccak256(toUtf8Bytes(SCOPED_CANONICALIZATION_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_CANONICALIZATION_BYTES = 1009;
const ROOT_SCHEMA_DOCUMENT = "{\"name\":\"STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2\",\"version\":2,\"record\":\"Original IStreamContentRootPublication.Record tuple plus immutable IStreamPreservationPolicyContentRootPublicationV1.Binding\",\"bindingFields\":[\"bytes32 profileId\",\"address outputManifest\",\"bytes32 outputManifestCodeHash\",\"address checkpoint\",\"bytes32 checkpointCodeHash\",\"bytes32 checkpointHash\",\"bytes32 checkpointStateHash\",\"address entropySourceSet\",\"bytes32 entropySourceSetCodeHash\",\"bytes32 inventoryHash\",\"bytes32 policyChainHash\",\"bytes32 outputRoot\",\"bytes32 outputSchemaHash\",\"bytes32 outputCanonicalizationHash\",\"bytes32 leafSchemaHash\",\"bytes32 rootSchemaHash\",\"bytes32 rootCanonicalizationHash\",\"address metadataRouter\",\"bytes32 preservationOutputProfile\"],\"profile\":\"6529STREAM_PRESERVATION_POLICY_CONTENT_V2\",\"scope\":\"Exact complete COLLECTION; scoped and VIEW records refused\",\"authority\":\"Original selected Metadata SNAPSHOT class7 collection or class8 global grant; exact original Artist operation17 CONTENT_ROOT approval and original one-use consumption,evolution,freeze rules\",\"lineage\":\"Original Router collectionContentRootHead and contentRootRecord append-only history; exact predecessor required\",\"schemas\":\"Exact ACTIVE RAW_BYTES preservation output, canonicalization, leaf and root documents\",\"policy\":\"DISABLED or ASYNC NOT_REQUIRED are truthful terminal states with no finalized seed; independently admitted terminal STATIC profile required; finalized rows retain original status5 seed\",\"root\":\"Original ordered six-field content leaf/tree with the distinct preservation leaf interpretation\",\"availability\":\"Manifest preserves every output hash and source commitment; full artifact bytes and snapshot/reference publication remain independent requirements\",\"checkpointProfile\":\"6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2\",\"preservationOutputProfile\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2\",\"bindingWordCount\":19,\"source\":\"Current complete covered preservation output manifest and checkpoint, selected immutable preservation provider binding or publication graph and full original entropy policy inventory\",\"projection\":\"Canonical public preservation JSON and HTML omit only sanction lookup and its derived displayed state, record hash and authority class. Artwork, executable code, media, token data, citation, C2PA, original entropy and all other Artist facts remain committed. Live presentation and adverse provenance stay separately readable.\",\"producerBinding\":\"Every output row retains its exact independently admitted producer marker: 6529STREAM_PRESERVATION_RENDER_V1 or 6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1 only; VIEW and unknown markers are refused. The family marker is not a row producer marker. Each row binds producer, runtime, actual preservation profile, Core, metadataRouter, selected live renderer and runtime, attribution companion and runtime, and seven-word governed admission. Mixed selected renderers are permitted per row; no global producer substitutes for the complete outputRoot.\",\"publicationOrder\":\"Collection root publication precedes the preservation snapshot that binds that root\",\"legacyCompatibility\":\"Existing live and locked profiles, schema bytes, signing domains, hashes and consumed-content books keep their original meaning. Original operation17 one-use CONTENT_ROOT authority, evolution and freeze rules apply.\",\"events\":\"Common original root publication event schemaVersion3 identifies the preservation interpretation; the distinct preservation binding event uses schemaVersion2\"}";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_SCHEMA_HASH = keccak256(toUtf8Bytes(ROOT_SCHEMA_DOCUMENT)) as Hex;
const ROOT_CANONICALIZATION_DOCUMENT = "{\"name\":\"STREAM_ABI_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2\",\"version\":2,\"encoding\":\"abi.encode(IStreamContentRootPublication.Record,IStreamPreservationPolicyContentRootPublicationV1.Binding)\",\"stateHash\":\"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V2),chainId,router,recordWithStateHashConsentAndPublishedAtZero,binding))\",\"recordHash\":\"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2),chainId,router,completedRecord,binding))\",\"routeHash\":\"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_ROUTE_V2),chainId,Context(core,artist),orderedTenTargets,orderedTenRuntimeHashes))\",\"targets\":\"core,artist,router,selectedFinality,selectedCombinedProvider,selectedMetadata,schemaRegistry,outputManifest,checkpoint,artifactCoverage\",\"strings\":\"Original exact validated UTF-8 URI bytes; no normalization\",\"approval\":\"Original scoped aggregate wraps the candidate state for original CONTENT_ROOT family consent\",\"history\":\"Existing profile bytes and domains remain unchanged. Preservation companion bindings and snapshots are never decoded as legacy profile bindings or snapshots; the original canonical Record history getter remains readable across all profiles\",\"canonical\":\"Solidity ABI only; alternate offsets, trailing bytes and noncanonical words forbidden\",\"bindingWords\":19,\"preservation\":\"Binding.metadataRouter is the actual original Router; preservationOutputProfile is the closed 6529STREAM_TOKEN_PRESERVATION_FAMILY_V2 value. Complete per-row producer and admission bindings are committed by outputRoot.\"}";
export const TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_CANONICALIZATION_HASH = keccak256(toUtf8Bytes(ROOT_CANONICALIZATION_DOCUMENT)) as Hex;
