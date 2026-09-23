import {
  AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress,
  id, isHexString, keccak256, toUtf8Bytes,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { ArtistHydrationBinding } from "./current-artist-authority-hydration.js";
import { prepareArtistContentConsent } from "./current-manifests.js";
import * as graph from "./current-scoped-policy-graph-v2.js";
import * as publication from "./current-scoped-policy-publication-v2.js";

/** Original ABI129 profile. Pure helpers validate supplied facts, never live authority/currentness. */
export const SCOPED_POLICY_ROOT_V2_SOURCE = "896899f7ca4130f86e066587f780a3b1f755a25d";
export const SCOPED_POLICY_ROOT_V2_PROFILE = id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2") as Hex;
export const SCOPED_POLICY_ROOT_V2_FAMILY = id("CONTENT_ROOT") as Hex;
export const SCOPED_POLICY_ROOT_V2_SCHEMA = id("STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2") as Hex;
export const SCOPED_POLICY_ROOT_V2_CANONICALIZATION = id("STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2") as Hex;
export const SCOPED_POLICY_ROOT_V2_SCHEMA_HASH = "0x08c8b24b7d562d1bc02006689159be8dd018d43256514068a9a31bbb78e26c28" as Hex;
export const SCOPED_POLICY_ROOT_V2_CANONICALIZATION_HASH = "0x63eb48213fc4a7a2f90cdfe576c86f2d26785f5637f11906dcdd1877c9948143" as Hex;
export const SCOPED_POLICY_ROOT_V2_SCHEMA_BYTES = 1856n;
export const SCOPED_POLICY_ROOT_V2_CANONICALIZATION_BYTES = 1373n;
export const SCOPED_POLICY_ROOT_V2_MAX_URI_BYTES = 2048;
export const SCOPED_POLICY_ROOT_V2_MAX_SIGNATURE_BYTES = 4096;
/** Client allocation/transport bound, not an additional protocol limit. */
export const SCOPED_POLICY_ROOT_V2_MAX_BYTES = 16384;

export type ScopedPolicyRootV2Scope = graph.ScopedPolicyGraphV2Scope;
export type ScopedPolicyRootV2Source = publication.ScopedPolicyPublicationV2Source;
export type ScopedPolicyRootV2Dependencies = publication.ScopedPolicyPublicationV2Dependencies;
export type ScopedPolicyRootV2Receipt = publication.ScopedPolicyPublicationV2Receipt;
export type ScopedPolicyRootV2ArtistBinding = ArtistHydrationBinding["item"];

export interface ScopedPolicyRootV2Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly router: Address;
  readonly artistRegistry: Address;
}

export interface ScopedPolicyRootV2Publication {
  readonly scope: ScopedPolicyRootV2Scope;
  readonly expectedPredecessor: Hex;
  readonly snapshotRecordHash: Hex;
  readonly snapshotRevision: bigint;
  readonly manifestURI: string;
}

export interface ScopedPolicyRootV2Record {
  readonly publication: ScopedPolicyRootV2Publication;
  readonly snapshotHost: Address;
  readonly snapshotCodeHash: Hex;
  readonly snapshotManifestHash: Hex;
  readonly snapshotSourceHash: Hex;
  readonly contentRoot: Hex;
  readonly leafCount: bigint;
  readonly outputManifestHash: Hex;
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

export interface ScopedPolicyRootV2Binding {
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
  readonly sourceFactory: Address;
  readonly sourceFactoryCodeHash: Hex;
  readonly factoryDependenciesHash: Hex;
  readonly snapshotSchemaHash: Hex;
  readonly snapshotProfileHash: Hex;
  readonly snapshotCanonicalizationHash: Hex;
}

export interface ScopedPolicyRootV2Aggregate {
  readonly revision: bigint;
  readonly transitionChain: Hex;
}

export interface ScopedPolicyRootV2RouteFacts {
  readonly finality: Address;
  readonly provider: Address;
  readonly snapshot: Address;
  /** Original order: Core, Artist Registry, Router, Finality, Provider, Snapshot. */
  readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex];
  readonly metadata: Address;
  readonly metadataCodeHash: Hex;
  readonly scope: ScopedPolicyRootV2Scope;
}

export interface ScopedPolicyRootV2ConsentTerms {
  readonly collectionId: bigint;
  readonly metadataContract: Address;
  readonly familyId: Hex;
  readonly newStateHash: Hex;
}

export interface ScopedPolicyRootV2Authorization {
  readonly nonce: bigint;
  readonly deadline: bigint;
  readonly signature: Hex;
}

export interface ScopedPolicyRootV2SignerApproval {
  readonly signer: Address;
  readonly digest: Hex;
  readonly direct: boolean;
}

export interface ScopedPolicyRootV2ConsentPayload {
  readonly binding: ScopedPolicyRootV2ArtistBinding;
  readonly terms: ScopedPolicyRootV2ConsentTerms;
  readonly authorization: ScopedPolicyRootV2Authorization;
  readonly proof: ScopedPolicyRootV2SignerApproval;
  readonly currentFamilyState: Hex;
}

export const SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE;
export const SCOPED_POLICY_ROOT_V2_PUBLICATION_TUPLE = `tuple(${SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE} scope,bytes32 expectedPredecessor,bytes32 snapshotRecordHash,uint64 snapshotRevision,string manifestURI)`;
export const SCOPED_POLICY_ROOT_V2_RECORD_TUPLE = `tuple(${SCOPED_POLICY_ROOT_V2_PUBLICATION_TUPLE} publication,address snapshotHost,bytes32 snapshotCodeHash,bytes32 snapshotManifestHash,bytes32 snapshotSourceHash,bytes32 contentRoot,uint64 leafCount,bytes32 outputManifestHash,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address publisher,uint8 authorizationClass,uint64 grantRevision,bytes32 routeHash,bytes32 stateHash,bytes32 artistConsent,uint64 publishedAt)`;
export const SCOPED_POLICY_ROOT_V2_BINDING_TUPLE = "tuple(bytes32 profileId,address outputManifest,bytes32 outputManifestCodeHash,address checkpoint,bytes32 checkpointCodeHash,bytes32 checkpointHash,bytes32 checkpointStateHash,address entropySourceSet,bytes32 entropySourceSetCodeHash,bytes32 inventoryHash,bytes32 policyChainHash,bytes32 outputRoot,bytes32 outputSchemaHash,bytes32 outputCanonicalizationHash,bytes32 leafSchemaHash,bytes32 rootSchemaHash,bytes32 rootCanonicalizationHash,address sourceFactory,bytes32 sourceFactoryCodeHash,bytes32 factoryDependenciesHash,bytes32 snapshotSchemaHash,bytes32 snapshotProfileHash,bytes32 snapshotCanonicalizationHash)";
export const SCOPED_POLICY_ROOT_V2_AGGREGATE_TUPLE = "tuple(uint64 revision,bytes32 transitionChain)";
export const SCOPED_POLICY_ROOT_V2_CONSENT_TERMS_TUPLE = "tuple(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
export const SCOPED_POLICY_ROOT_V2_AUTHORIZATION_TUPLE = "tuple(uint256 nonce,uint64 time,bytes signature)";
export const SCOPED_POLICY_ROOT_V2_SIGNER_APPROVAL_TUPLE = "tuple(address signer,bytes32 digest,bool direct)";
export const SCOPED_POLICY_ROOT_V2_ARTIST_BINDING_TUPLE = "tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted)";

const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;

function exact(value: unknown, keys: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).length !== keys.length
    || keys.some(key => !Object.hasOwn(value, key))) throw Error(`${label}: missing or unknown fields`);
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`);
  return value;
}

function address(value: unknown, required = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (required && result === ZeroAddress) throw Error("Expected nonzero address");
  return result;
}

function bytes(value: unknown, fixed?: number, maximum = SCOPED_POLICY_ROOT_V2_MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, fixed ?? true)
    || (value.length - 2) / 2 > maximum) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}

function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === ZERO) throw Error("Expected nonzero commitment");
  return result;
}

function text(value: unknown): string {
  if (typeof value !== "string"
    || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)
    || toUtf8Bytes(value).length > SCOPED_POLICY_ROOT_V2_MAX_URI_BYTES) throw Error("Invalid UTF8 URI or byte bound");
  return value;
}

function valueOf(type: ParamType, value: unknown, decoded = false): unknown {
  if (type.baseType === "tuple") {
    if (!decoded) exact(value, type.components!.map(field => field.name), "Tuple");
    return Object.freeze(Object.fromEntries(type.components!.map((field, index) => [field.name,
      valueOf(field, decoded ? (value as readonly unknown[])[index] : (value as Record<string, unknown>)[field.name], decoded)])));
  }
  if (type.type.startsWith("uint")) {
    const result = uint(value, Number(type.type.slice(4)));
    if (type.name === "scopeType" && result > 4n) throw Error("Unknown scope enum");
    return result;
  }
  if (type.type === "address") return address(value);
  if (type.type.startsWith("bytes")) return bytes(value, type.type === "bytes" ? undefined : Number(type.type.slice(5)));
  if (type.type === "string") return text(value);
  if (type.type === "bool" && typeof value === "boolean") return value;
  throw Error(`Invalid ABI value: ${type.type}`);
}

function normalized<T>(tuple: string, value: unknown): T {
  return valueOf(ParamType.from(tuple), value) as T;
}

function encode(tuple: string, value: unknown): Hex {
  return bytes(coder.encode([tuple], [normalized(tuple, value)]));
}

function decode<T>(tuple: string, value: Hex): T {
  const raw = bytes(value);
  const result = valueOf(ParamType.from(tuple), coder.decode([tuple], raw)[0], true) as T;
  if (encode(tuple, result) !== raw) throw Error("Noncanonical ABI encoding");
  return result;
}

function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

export function normalizeScopedPolicyRootV2Coordinates(value: ScopedPolicyRootV2Coordinates): ScopedPolicyRootV2Coordinates {
  exact(value, ["chainId", "core", "router", "artistRegistry"], "Coordinates");
  return Object.freeze({ chainId: uint(value.chainId), core: address(value.core, true),
    router: address(value.router, true), artistRegistry: address(value.artistRegistry, true) });
}

/** Structural codecs retain original zero-valued historical fields; these are not admission checks. */
export function normalizeScopedPolicyRootV2Publication(value: ScopedPolicyRootV2Publication): ScopedPolicyRootV2Publication {
  return normalized(SCOPED_POLICY_ROOT_V2_PUBLICATION_TUPLE, value);
}
export function encodeScopedPolicyRootV2Publication(value: ScopedPolicyRootV2Publication): Hex {
  return encode(SCOPED_POLICY_ROOT_V2_PUBLICATION_TUPLE, value);
}
export function decodeScopedPolicyRootV2Publication(value: Hex): ScopedPolicyRootV2Publication {
  return decode(SCOPED_POLICY_ROOT_V2_PUBLICATION_TUPLE, value);
}
export function normalizeScopedPolicyRootV2Record(value: ScopedPolicyRootV2Record): ScopedPolicyRootV2Record {
  return normalized(SCOPED_POLICY_ROOT_V2_RECORD_TUPLE, value);
}
export function encodeScopedPolicyRootV2Record(value: ScopedPolicyRootV2Record): Hex {
  return encode(SCOPED_POLICY_ROOT_V2_RECORD_TUPLE, value);
}
export function decodeScopedPolicyRootV2Record(value: Hex): ScopedPolicyRootV2Record {
  return decode(SCOPED_POLICY_ROOT_V2_RECORD_TUPLE, value);
}
export function normalizeScopedPolicyRootV2Binding(value: ScopedPolicyRootV2Binding): ScopedPolicyRootV2Binding {
  return normalized(SCOPED_POLICY_ROOT_V2_BINDING_TUPLE, value);
}
export function encodeScopedPolicyRootV2Binding(value: ScopedPolicyRootV2Binding): Hex {
  return encode(SCOPED_POLICY_ROOT_V2_BINDING_TUPLE, value);
}
export function decodeScopedPolicyRootV2Binding(value: Hex): ScopedPolicyRootV2Binding {
  return decode(SCOPED_POLICY_ROOT_V2_BINDING_TUPLE, value);
}
export function normalizeScopedPolicyRootV2Aggregate(value: ScopedPolicyRootV2Aggregate): ScopedPolicyRootV2Aggregate {
  return normalized(SCOPED_POLICY_ROOT_V2_AGGREGATE_TUPLE, value);
}
export function encodeScopedPolicyRootV2Aggregate(value: ScopedPolicyRootV2Aggregate): Hex {
  return encode(SCOPED_POLICY_ROOT_V2_AGGREGATE_TUPLE, value);
}
export function decodeScopedPolicyRootV2Aggregate(value: Hex): ScopedPolicyRootV2Aggregate {
  return decode(SCOPED_POLICY_ROOT_V2_AGGREGATE_TUPLE, value);
}

export function validateScopedPolicyRootV2Publication(value: ScopedPolicyRootV2Publication): ScopedPolicyRootV2Publication {
  const p = normalizeScopedPolicyRootV2Publication(value);
  graph.validateScopedPolicyGraphV2Scope(p.scope);
  nonzero(p.snapshotRecordHash);
  if (p.snapshotRevision === 0n) throw Error("Snapshot revision must be positive");
  const uri = p.manifestURI;
  const valid = uri.startsWith("https://") ? uri.length > 8 && !"/?#".includes(uri[8]!)
    : uri.startsWith("ipfs://") ? uri.length > 7 : uri.startsWith("ar://") && uri.length > 5;
  if (!valid || /[\u0000-\u0020\u007f]/u.test(uri)) throw Error("Invalid original content URI");
  return p;
}

export function normalizeScopedPolicyRootV2RouteFacts(value: ScopedPolicyRootV2RouteFacts): ScopedPolicyRootV2RouteFacts {
  exact(value, ["finality", "provider", "snapshot", "codeHashes", "metadata", "metadataCodeHash", "scope"], "Route facts");
  const pins = value.codeHashes;
  if (!Array.isArray(pins) || pins.length !== 6 || Reflect.ownKeys(pins).length !== 7
    || Array.from({ length: 6 }, (_, i) => i).some(i => !Object.hasOwn(pins, i))) throw Error("Expected six dense runtime hashes");
  return Object.freeze({ finality: address(value.finality, true), provider: address(value.provider, true),
    snapshot: address(value.snapshot, true), codeHashes: Object.freeze(pins.map(nonzero)) as ScopedPolicyRootV2RouteFacts["codeHashes"],
    metadata: address(value.metadata, true), metadataCodeHash: nonzero(value.metadataCodeHash),
    scope: graph.validateScopedPolicyGraphV2Scope(value.scope) });
}

export function scopedPolicyRootV2RouteHash(
  coordinates: ScopedPolicyRootV2Coordinates,
  facts: ScopedPolicyRootV2RouteFacts,
): Hex {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  const r = normalizeScopedPolicyRootV2RouteFacts(facts);
  return hash(["bytes32", "uint256", "address[6]", "bytes32[6]", "address", "bytes32", SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_ROUTE_V2"), c.chainId,
      [c.core, c.artistRegistry, c.router, r.finality, r.provider, r.snapshot], r.codeHashes, r.metadata, r.metadataCodeHash, r.scope]);
}

/** Reconstructs only the original Binding projection; snapshot authenticity is a workflow prerequisite. */
export function scopedPolicyRootV2BindingFromSnapshot(
  dependencies: ScopedPolicyRootV2Dependencies,
  source: ScopedPolicyRootV2Source,
  receipt: ScopedPolicyRootV2Receipt,
): ScopedPolicyRootV2Binding {
  const d = graph.normalizeScopedPolicyGraphV2SnapshotDependencies(dependencies);
  const s = publication.normalizeScopedPolicyPublicationV2Source(source);
  const r = publication.normalizeScopedPolicyPublicationV2Receipt(receipt);
  return normalizeScopedPolicyRootV2Binding({
    profileId: SCOPED_POLICY_ROOT_V2_PROFILE,
    outputManifest: d.targets[8], outputManifestCodeHash: d.codeHashes[8],
    checkpoint: d.targets[7], checkpointCodeHash: d.codeHashes[7],
    checkpointHash: s.outputs.checkpointHash, checkpointStateHash: s.outputs.checkpointStateHash,
    entropySourceSet: d.targets[10], entropySourceSetCodeHash: d.codeHashes[10],
    inventoryHash: s.outputs.inventoryHash, policyChainHash: s.outputs.policyChainHash, outputRoot: s.outputs.outputRoot,
    outputSchemaHash: publication.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA_HASH,
    outputCanonicalizationHash: publication.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION_HASH,
    leafSchemaHash: publication.SCOPED_POLICY_PUBLICATION_V2_LEAF_SCHEMA_HASH,
    rootSchemaHash: SCOPED_POLICY_ROOT_V2_SCHEMA_HASH,
    rootCanonicalizationHash: SCOPED_POLICY_ROOT_V2_CANONICALIZATION_HASH,
    sourceFactory: s.sourceFactory, sourceFactoryCodeHash: s.sourceFactoryCodeHash,
    factoryDependenciesHash: s.factoryDependenciesHash, snapshotSchemaHash: r.schemaHash,
    snapshotProfileHash: r.profileHash, snapshotCanonicalizationHash: r.canonicalizationHash,
  });
}

function v2Binding(value: ScopedPolicyRootV2Binding): ScopedPolicyRootV2Binding {
  const b = normalizeScopedPolicyRootV2Binding(value);
  if (b.profileId !== SCOPED_POLICY_ROOT_V2_PROFILE) throw Error("Expected original V2 profile");
  return b;
}

export function scopedPolicyRootV2StateHash(
  coordinates: ScopedPolicyRootV2Coordinates,
  record: ScopedPolicyRootV2Record,
  binding: ScopedPolicyRootV2Binding,
): Hex {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  const r = normalizeScopedPolicyRootV2Record(record);
  return hash(["bytes32", "uint256", "address", "address", SCOPED_POLICY_ROOT_V2_RECORD_TUPLE, SCOPED_POLICY_ROOT_V2_BINDING_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_STATE_V2"), c.chainId, c.router, c.core,
      { ...r, stateHash: ZERO, artistConsent: ZERO, publishedAt: 0n }, v2Binding(binding)]);
}

export function scopedPolicyRootV2NextAggregate(
  coordinates: ScopedPolicyRootV2Coordinates,
  prior: ScopedPolicyRootV2Aggregate,
  oldHead: Hex,
  prepared: ScopedPolicyRootV2Record,
): ScopedPolicyRootV2Aggregate {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  const a = normalizeScopedPolicyRootV2Aggregate(prior);
  const r = normalizeScopedPolicyRootV2Record(prepared);
  const head = bytes(oldHead, 32);
  if (r.publication.expectedPredecessor !== head) throw Error("Scoped predecessor changed");
  const state = nonzero(r.stateHash);
  const revision = uint(a.revision + 1n, 64);
  const subject = graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, graph.validateScopedPolicyGraphV2Scope(r.publication.scope));
  return Object.freeze({ revision, transitionChain: hash(
    ["bytes32", "uint256", "address", "address", "uint256", "bytes32", "uint64", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1"), c.chainId, c.router, c.core,
      r.publication.scope.collectionId, a.transitionChain, revision, subject, head, state]) });
}

export function scopedPolicyRootV2EmptyLegacyFamily(coordinates: ScopedPolicyRootV2Coordinates, collectionId: bigint): Hex {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", "uint256"],
    [id("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"), c.chainId, c.router, c.core, uint(collectionId)]);
}

export function scopedPolicyRootV2FamilyHash(
  coordinates: ScopedPolicyRootV2Coordinates,
  collectionId: bigint,
  legacy: Hex,
  aggregate: ScopedPolicyRootV2Aggregate,
): Hex {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  const a = normalizeScopedPolicyRootV2Aggregate(aggregate);
  const cid = uint(collectionId);
  const original = bytes(legacy, 32);
  if (a.revision === 0n) return original;
  return hash(["bytes32", "uint256", "address", "address", "uint256", "bytes32", SCOPED_POLICY_ROOT_V2_AGGREGATE_TUPLE],
    [id("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"), c.chainId, c.router, c.core, cid, original, a]);
}

export function scopedPolicyRootV2RecordHash(
  coordinates: ScopedPolicyRootV2Coordinates,
  completed: ScopedPolicyRootV2Record,
  binding: ScopedPolicyRootV2Binding,
  historicalAggregate: ScopedPolicyRootV2Aggregate,
): Hex {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", SCOPED_POLICY_ROOT_V2_RECORD_TUPLE,
    SCOPED_POLICY_ROOT_V2_BINDING_TUPLE, SCOPED_POLICY_ROOT_V2_AGGREGATE_TUPLE],
  [id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"), c.chainId, c.router, c.core,
    normalizeScopedPolicyRootV2Record(completed), v2Binding(binding), normalizeScopedPolicyRootV2Aggregate(historicalAggregate)]);
}

export function scopedPolicyRootV2LegacyRecordHash(
  coordinates: ScopedPolicyRootV2Coordinates,
  completed: ScopedPolicyRootV2Record,
  historicalAggregate: ScopedPolicyRootV2Aggregate,
): Hex {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", SCOPED_POLICY_ROOT_V2_RECORD_TUPLE, SCOPED_POLICY_ROOT_V2_AGGREGATE_TUPLE],
    [id("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"), c.chainId, c.router, c.core,
      normalizeScopedPolicyRootV2Record(completed), normalizeScopedPolicyRootV2Aggregate(historicalAggregate)]);
}

export function scopedPolicyRootV2LegacyStateHash(
  coordinates: ScopedPolicyRootV2Coordinates,
  record: ScopedPolicyRootV2Record,
): Hex {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  const r = normalizeScopedPolicyRootV2Record(record);
  return hash(["bytes32", "uint256", "address", "address", SCOPED_POLICY_ROOT_V2_RECORD_TUPLE],
    [id("6529STREAM_SCOPED_CONTENT_ROOT_STATE_V1"), c.chainId, c.router, c.core,
      { ...r, stateHash: ZERO, artistConsent: ZERO, publishedAt: 0n }]);
}

/** Requires a known completed record and its publication-event aggregate; never substitutes today's aggregate. */
export function authenticateScopedPolicyRootV2History(
  coordinates: ScopedPolicyRootV2Coordinates,
  recordHash: Hex,
  record: ScopedPolicyRootV2Record,
  binding: ScopedPolicyRootV2Binding,
  historicalAggregate: ScopedPolicyRootV2Aggregate,
): "v1" | "v2" {
  const r = normalizeScopedPolicyRootV2Record(record);
  const b = normalizeScopedPolicyRootV2Binding(binding);
  if (r.publisher === ZeroAddress || r.publishedAt === 0n || r.artistConsent === ZERO) throw Error("Unknown or incomplete historical record");
  const expected = nonzero(recordHash);
  if (b.profileId === ZERO) {
    if (Object.values(b).some(value => value !== ZERO && value !== ZeroAddress)) throw Error("Partial zero-tag binding");
    if (scopedPolicyRootV2LegacyStateHash(coordinates, r) !== r.stateHash
      || scopedPolicyRootV2LegacyRecordHash(coordinates, r, historicalAggregate) !== expected) throw Error("V1 historical record mismatch");
    return "v1";
  }
  if (scopedPolicyRootV2StateHash(coordinates, r, b) !== r.stateHash
    || scopedPolicyRootV2RecordHash(coordinates, r, b, historicalAggregate) !== expected) throw Error("V2 historical record mismatch");
  return "v2";
}

export interface ScopedPolicyRootV2PreparedRecordFacts {
  readonly publication: ScopedPolicyRootV2Publication;
  readonly route: ScopedPolicyRootV2RouteFacts;
  readonly source: ScopedPolicyRootV2Source;
  readonly dependencies: ScopedPolicyRootV2Dependencies;
  readonly receipt: ScopedPolicyRootV2Receipt;
  readonly publisher: Address;
  readonly authorizationClass: 7n | 8n;
  readonly grantRevision: bigint;
}

/** Reconstructs original source-visible joins from supplied facts, without claiming live provenance. */
export function scopedPolicyRootV2PreparedRecord(
  coordinates: ScopedPolicyRootV2Coordinates,
  facts: ScopedPolicyRootV2PreparedRecordFacts,
): Readonly<{ record: ScopedPolicyRootV2Record; binding: ScopedPolicyRootV2Binding; factsVerified: false }> {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  exact(facts, ["publication", "route", "source", "dependencies", "receipt", "publisher", "authorizationClass", "grantRevision"], "Prepared facts");
  const p = validateScopedPolicyRootV2Publication(facts.publication);
  const route = normalizeScopedPolicyRootV2RouteFacts(facts.route);
  const s = publication.normalizeScopedPolicyPublicationV2Source(facts.source);
  const d = graph.normalizeScopedPolicyGraphV2SnapshotDependencies(facts.dependencies);
  const receipt = publication.normalizeScopedPolicyPublicationV2Receipt(facts.receipt);
  const scopeBytes = encode(SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE, p.scope);
  if (scopeBytes !== encode(SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE, route.scope)
    || scopeBytes !== encode(SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE, s.scope)
    || scopeBytes !== encode(SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE, s.outputs.scope)) throw Error("Full snapshot scope differs");
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.targets[1] !== route.metadata || d.targets[4] !== c.router
    || d.codeHashes[0] !== route.codeHashes[0] || d.codeHashes[1] !== route.metadataCodeHash
    || d.codeHashes[4] !== route.codeHashes[2]) throw Error("Snapshot dependencies differ from route");
  for (let i = 0; i < 11; i++) { address(d.targets[i], true); nonzero(d.codeHashes[i]); }
  if (receipt.recordHash !== p.snapshotRecordHash || receipt.revision !== p.snapshotRevision
    || receipt.scopeSubject !== graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, p.scope)
    || receipt.recordedAt === 0n || receipt.manifestBytes === 0n
    || receipt.schemaHash !== publication.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_SCHEMA_HASH
    || receipt.profileHash !== publication.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_HASH
    || receipt.canonicalizationHash !== publication.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_CANONICALIZATION_HASH) throw Error("Snapshot receipt association differs");
  nonzero(receipt.manifestHash);
  nonzero(receipt.chainHash);
  const sourceHash = hash(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", publication.SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"), c.chainId, route.snapshot, d.targets, d.codeHashes, s]);
  if (sourceHash !== receipt.sourceHash) throw Error("Snapshot source hash differs");
  for (const value of [s.outputs.contentRoot, s.outputs.manifestHash, s.outputs.outputRoot,
    s.outputs.checkpointHash, s.outputs.checkpointStateHash, s.outputs.inventoryHash, s.outputs.policyChainHash,
    s.sourceFactoryCodeHash, s.factoryDependenciesHash, s.artist.artistId, s.artist.bindingHash]) nonzero(value);
  address(s.sourceFactory, true);
  if (s.outputs.tokenCount === 0n || s.outputs.entropySourceSet !== d.targets[10]
    || s.artist.bindingGeneration === 0n) throw Error("Incomplete root source");
  if (facts.authorizationClass !== 7n && facts.authorizationClass !== 8n) throw Error("Root requires SNAPSHOT class7 or class8");
  const grantRevision = uint(facts.grantRevision, 64);
  if (grantRevision === 0n) throw Error("Publisher grant revision must be positive");
  const binding = scopedPolicyRootV2BindingFromSnapshot(d, s, receipt);
  const base = normalizeScopedPolicyRootV2Record({
    publication: p, snapshotHost: route.snapshot, snapshotCodeHash: route.codeHashes[5],
    snapshotManifestHash: receipt.manifestHash, snapshotSourceHash: receipt.sourceHash,
    contentRoot: s.outputs.contentRoot, leafCount: s.outputs.tokenCount, outputManifestHash: s.outputs.manifestHash,
    artistId: s.artist.artistId, bindingGeneration: s.artist.bindingGeneration, bindingHash: s.artist.bindingHash,
    publisher: address(facts.publisher, true), authorizationClass: facts.authorizationClass, grantRevision,
    routeHash: scopedPolicyRootV2RouteHash(c, route), stateHash: ZERO, artistConsent: ZERO, publishedAt: 0n,
  });
  const record = normalizeScopedPolicyRootV2Record({ ...base, stateHash: scopedPolicyRootV2StateHash(c, base, binding) });
  return Object.freeze({ record, binding, factsVerified: false });
}

export function normalizeScopedPolicyRootV2Authorization(value: ScopedPolicyRootV2Authorization): ScopedPolicyRootV2Authorization {
  exact(value, ["nonce", "deadline", "signature"], "Authorization");
  return Object.freeze({ nonce: uint(value.nonce), deadline: uint(value.deadline, 64),
    signature: bytes(value.signature, undefined, SCOPED_POLICY_ROOT_V2_MAX_SIGNATURE_BYTES) });
}

function originalAuthorization(value: ScopedPolicyRootV2Authorization) {
  const a = normalizeScopedPolicyRootV2Authorization(value);
  return Object.freeze({ nonce: a.nonce, time: a.deadline, signature: a.signature });
}

export function normalizeScopedPolicyRootV2ConsentTerms(value: ScopedPolicyRootV2ConsentTerms): ScopedPolicyRootV2ConsentTerms {
  return normalized(SCOPED_POLICY_ROOT_V2_CONSENT_TERMS_TUPLE, value);
}

function consentTerms(coordinates: ScopedPolicyRootV2Coordinates, collectionId: bigint, newFamilyStateHash: Hex): ScopedPolicyRootV2ConsentTerms {
  const cid = uint(collectionId);
  if (cid === 0n) throw Error("Expected collection");
  return Object.freeze({ collectionId: cid, metadataContract: coordinates.router,
    familyId: SCOPED_POLICY_ROOT_V2_FAMILY, newStateHash: nonzero(newFamilyStateHash) });
}

export interface ScopedPolicyRootV2ConsentRecordFacts {
  readonly terms: ScopedPolicyRootV2ConsentTerms;
  readonly artistId: Hex;
  readonly signer: Address;
  readonly authorityClass: 1n | 3n;
  readonly nonce: bigint;
  readonly observedAt: bigint;
}

export function scopedPolicyRootV2ConsentRecordHash(
  coordinates: ScopedPolicyRootV2Coordinates,
  facts: ScopedPolicyRootV2ConsentRecordFacts,
): Hex {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  exact(facts, ["terms", "artistId", "signer", "authorityClass", "nonce", "observedAt"], "Consent record facts");
  const p = normalizeScopedPolicyRootV2ConsentTerms(facts.terms);
  if (p.metadataContract !== c.router || p.familyId !== SCOPED_POLICY_ROOT_V2_FAMILY) throw Error("Expected Router CONTENT_ROOT consent");
  consentTerms(c, p.collectionId, p.newStateHash);
  if (facts.authorityClass !== 1n && facts.authorityClass !== 3n) throw Error("Root consumes authority class1 or class3");
  const observedAt = uint(facts.observedAt, 64);
  if (observedAt === 0n) throw Error("Expected mined timestamp");
  return hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32",
    "bytes32", "address", "uint8", "uint256", "uint64"],
  [id("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"), c.chainId, c.artistRegistry, p.metadataContract, c.core,
    p.collectionId, p.familyId, p.newStateHash, nonzero(facts.artistId), address(facts.signer, true),
    facts.authorityClass, uint(facts.nonce), observedAt]);
}

export function scopedPolicyRootV2ConsentEvidenceId(
  coordinates: ScopedPolicyRootV2Coordinates,
  coordinator: Address,
  actor: Address,
  recordHash: Hex,
): Hex {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), c.chainId, c.artistRegistry,
      address(coordinator, true), 17n, address(actor, true), nonzero(recordHash)]);
}

export function normalizeScopedPolicyRootV2ConsentPayload(value: ScopedPolicyRootV2ConsentPayload): ScopedPolicyRootV2ConsentPayload {
  exact(value, ["binding", "terms", "authorization", "proof", "currentFamilyState"], "Consent payload");
  return Object.freeze({ binding: normalized<ScopedPolicyRootV2ArtistBinding>(SCOPED_POLICY_ROOT_V2_ARTIST_BINDING_TUPLE, value.binding),
    terms: normalizeScopedPolicyRootV2ConsentTerms(value.terms), authorization: normalizeScopedPolicyRootV2Authorization(value.authorization),
    proof: normalized<ScopedPolicyRootV2SignerApproval>(SCOPED_POLICY_ROOT_V2_SIGNER_APPROVAL_TUPLE, value.proof),
    currentFamilyState: bytes(value.currentFamilyState, 32) });
}

const consentPayloadTypes = [SCOPED_POLICY_ROOT_V2_ARTIST_BINDING_TUPLE, SCOPED_POLICY_ROOT_V2_CONSENT_TERMS_TUPLE,
  SCOPED_POLICY_ROOT_V2_AUTHORIZATION_TUPLE, SCOPED_POLICY_ROOT_V2_SIGNER_APPROVAL_TUPLE, "bytes32"];

/** Original flat five-field operation17 payload, not an added wrapping tuple. */
export function encodeScopedPolicyRootV2ConsentPayload(value: ScopedPolicyRootV2ConsentPayload): Hex {
  const p = normalizeScopedPolicyRootV2ConsentPayload(value);
  return bytes(coder.encode(consentPayloadTypes, [p.binding, p.terms, originalAuthorization(p.authorization), p.proof, p.currentFamilyState]));
}

export function decodeScopedPolicyRootV2ConsentPayload(value: Hex): ScopedPolicyRootV2ConsentPayload {
  const raw = bytes(value);
  const d = coder.decode(consentPayloadTypes, raw);
  const authorization = valueOf(ParamType.from(SCOPED_POLICY_ROOT_V2_AUTHORIZATION_TUPLE), d[2], true) as {
    nonce: bigint; time: bigint; signature: Hex;
  };
  const result = normalizeScopedPolicyRootV2ConsentPayload({
    binding: valueOf(ParamType.from(SCOPED_POLICY_ROOT_V2_ARTIST_BINDING_TUPLE), d[0], true) as ScopedPolicyRootV2ArtistBinding,
    terms: valueOf(ParamType.from(SCOPED_POLICY_ROOT_V2_CONSENT_TERMS_TUPLE), d[1], true) as ScopedPolicyRootV2ConsentTerms,
    authorization: { nonce: authorization.nonce, deadline: authorization.time, signature: authorization.signature },
    proof: valueOf(ParamType.from(SCOPED_POLICY_ROOT_V2_SIGNER_APPROVAL_TUPLE), d[3], true) as ScopedPolicyRootV2SignerApproval,
    currentFamilyState: d[4] as Hex,
  });
  if (encodeScopedPolicyRootV2ConsentPayload(result) !== raw) throw Error("Noncanonical operation17 payload");
  return result;
}

export const SCOPED_POLICY_ROOT_V2_ROUTER_ABI = Object.freeze([
  `function previewScopedPolicyContentRootPublication(${SCOPED_POLICY_ROOT_V2_PUBLICATION_TUPLE} publication,address publisher) view returns (bytes32)`,
  `function publishScopedPolicyContentRootPublication(${SCOPED_POLICY_ROOT_V2_PUBLICATION_TUPLE} publication) returns (bytes32 recordHash)`,
  `function scopedPolicyContentRootBinding(bytes32 recordHash) view returns (${SCOPED_POLICY_ROOT_V2_BINDING_TUPLE})`,
  `function scopedContentRootHead(${SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE}) view returns (bytes32)`,
  `function scopedContentRootRecord(bytes32) view returns (${SCOPED_POLICY_ROOT_V2_RECORD_TUPLE})`,
  `function scopedContentRootAggregate(uint256 collectionId) view returns (${SCOPED_POLICY_ROOT_V2_AGGREGATE_TUPLE})`,
  `function scopedTokenContentRoot(${SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE}) view returns (bytes32,uint64,bytes32)`,
  "function artistContentFamilyState(uint256 collectionId,bytes32 familyId) view returns (bool supported,bytes32 currentStateHash)",
  "function consumedArtistContentConsent(bytes32) view returns (bool)",
  "function artistContentEvolution(uint256 collectionId) view returns (bytes32,bytes32)",
  "function currentArtistContentState(uint256 collectionId) view returns (address metadataContract,bytes32 contentStateHash)",
  `event ScopedContentRootPublished(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed scopeSubject,bytes32 indexed recordHash,${SCOPED_POLICY_ROOT_V2_RECORD_TUPLE} record,${SCOPED_POLICY_ROOT_V2_AGGREGATE_TUPLE} collectionAggregate)`,
  `event ScopedPolicyContentRootBindingPublished(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed scopeSubject,bytes32 indexed recordHash,${SCOPED_POLICY_ROOT_V2_BINDING_TUPLE} binding)`,
]);

export const SCOPED_POLICY_ROOT_V2_ARTIST_ABI = Object.freeze([
  `function recordContentConsent(${SCOPED_POLICY_ROOT_V2_CONSENT_TERMS_TUPLE} p,${SCOPED_POLICY_ROOT_V2_AUTHORIZATION_TUPLE} a) returns (bytes32)`,
  `function contentConsentDigest(${SCOPED_POLICY_ROOT_V2_CONSENT_TERMS_TUPLE} p,${SCOPED_POLICY_ROOT_V2_AUTHORIZATION_TUPLE} a) view returns (bytes32)`,
  "function contentConsentEvidence(uint256 collectionId,bytes32 familyId,bytes32 newStateHash) view returns (bytes32)",
  "function contentConsentEvidenceForHost(uint256 collectionId,address contentHost,bytes32 familyId,bytes32 newStateHash) view returns (bytes32)",
  "function firstReleaseRatification(uint256 collectionId) view returns (bool,bytes32,bytes32)",
]);

export const SCOPED_POLICY_ROOT_V2_PROVIDER_ABI = Object.freeze([
  `function scopedPolicySnapshotCodeHash(${SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE} scope) view returns (bytes32)`,
  `function scopedPolicySnapshotHost(${SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE} scope) view returns (address)`,
  "function scopedPolicySnapshotProfile() view returns (bytes32)",
  `function scopedPolicySnapshotValidationGas(${SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE} scope) view returns (uint256)`,
]);

const routerInterface = new Interface(SCOPED_POLICY_ROOT_V2_ROUTER_ABI);
const artistInterface = new Interface(SCOPED_POLICY_ROOT_V2_ARTIST_ABI);
const providerInterface = new Interface(SCOPED_POLICY_ROOT_V2_PROVIDER_ABI);

function ownId(iface: Interface, names: readonly string[]): Hex {
  let result = 0n;
  for (const name of names) result ^= BigInt(iface.getFunction(name)!.selector);
  return `0x${result.toString(16).padStart(8, "0")}` as Hex;
}

export const SCOPED_POLICY_ROOT_V2_PROVIDER_INTERFACE_ID = ownId(providerInterface,
  ["scopedPolicySnapshotCodeHash", "scopedPolicySnapshotHost", "scopedPolicySnapshotProfile", "scopedPolicySnapshotValidationGas"]);
export const SCOPED_POLICY_ROOT_V2_INTERFACE_ID = ownId(routerInterface,
  ["previewScopedPolicyContentRootPublication", "publishScopedPolicyContentRootPublication", "scopedPolicyContentRootBinding"]);
export const SCOPED_POLICY_ROOT_V2_SNAPSHOT_INTERFACE_ID = ownId(new Interface([
  ...publication.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_ABI,
  `function lockTransition(${SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE} scope) view returns (bytes32 actionScope,bytes32 oldState,bytes32 newState)`,
  `function lockSnapshot(${SCOPED_POLICY_ROOT_V2_SCOPE_TUPLE} scope)`,
]), ["scopedPolicySnapshotProfile", "core", "metadataHost", "dependencies", "previewSnapshot", "publishSnapshot",
  "currentSnapshot", "snapshotRecord", "snapshotPayload", "requireCurrent", "lockTransition", "lockSnapshot", "snapshotLock", "snapshotCount", "snapshotAt"]);

export function scopedPolicyRootV2Interface(host: "router" | "artist" | "provider"): Interface {
  if (host === "router") return new Interface(SCOPED_POLICY_ROOT_V2_ROUTER_ABI);
  if (host === "artist") return new Interface(SCOPED_POLICY_ROOT_V2_ARTIST_ABI);
  if (host === "provider") return new Interface(SCOPED_POLICY_ROOT_V2_PROVIDER_ABI);
  throw Error("Unknown root host");
}

export type ScopedPolicyRootV2Request =
  | Readonly<{
    kind: "recordContentConsent";
    collectionId: bigint;
    newFamilyStateHash: Hex;
    signer: Address;
    authorityClass: 1n | 3n;
    authorization: ScopedPolicyRootV2Authorization;
  }>
  | Readonly<{
    kind: "publishScopedPolicyContentRootPublication";
    publication: ScopedPolicyRootV2Publication;
  }>;

export interface ScopedPolicyRootV2ConsentPreparation {
  readonly payload: ReturnType<typeof prepareArtistContentConsent>["payload"];
  readonly digestCall: UnsignedCall;
  readonly signer: Address;
  readonly direct: boolean;
}

export interface ScopedPolicyRootV2Call {
  readonly coordinates: ScopedPolicyRootV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyRootV2Request;
  readonly call: UnsignedCall;
  readonly consent: ScopedPolicyRootV2ConsentPreparation | null;
  readonly factsVerified: false;
}

function call(target: Address, iface: Interface, method: string, args: readonly unknown[]): UnsignedCall {
  return Object.freeze({ to: target, value: 0n, data: bytes(iface.encodeFunctionData(method, args)) });
}

/** Two unsigned original CALLs only. The signing payload binds the next family returned by Router preview. */
export function prepareScopedPolicyRootV2Call(
  coordinates: ScopedPolicyRootV2Coordinates,
  caller: Address,
  request: ScopedPolicyRootV2Request,
): ScopedPolicyRootV2Call {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  const actor = address(caller, true);
  if (request.kind === "publishScopedPolicyContentRootPublication") {
    exact(request, ["kind", "publication"], "Publish request");
    const p = validateScopedPolicyRootV2Publication(request.publication);
    return Object.freeze({ coordinates: c, caller: actor,
      request: Object.freeze({ kind: request.kind, publication: p }),
      call: call(c.router, routerInterface, request.kind, [p]), consent: null, factsVerified: false });
  }
  if (request.kind === "recordContentConsent") {
    exact(request, ["kind", "collectionId", "newFamilyStateHash", "signer", "authorityClass", "authorization"], "Consent request");
    if (request.authorityClass !== 1n && request.authorityClass !== 3n) throw Error("Root consumes authority class1 or class3");
    const terms = consentTerms(c, request.collectionId, request.newFamilyStateHash);
    const signer = address(request.signer, true);
    const authorization = normalizeScopedPolicyRootV2Authorization(request.authorization);
    const prepared = prepareArtistContentConsent(c.chainId, c.artistRegistry, c.core,
      { collectionId: terms.collectionId, contract: c.router, familyId: terms.familyId }, terms.newStateHash, authorization);
    const preparedCall = call(c.artistRegistry, artistInterface, request.kind, [terms, originalAuthorization(authorization)]);
    if (preparedCall.data !== prepared.call.data) throw Error("Original content-consent transport mismatch");
    return Object.freeze({ coordinates: c, caller: actor,
      request: Object.freeze({ kind: request.kind, collectionId: terms.collectionId, newFamilyStateHash: terms.newStateHash,
        signer, authorityClass: request.authorityClass, authorization }), call: preparedCall,
      consent: Object.freeze({ payload: prepared.payload, digestCall: Object.freeze({ ...prepared.digestCall }),
        signer, direct: signer === actor && authorization.signature === "0x" }), factsVerified: false });
  }
  throw Error("Unsupported scoped root write");
}

export function normalizeScopedPolicyRootV2Call(value: ScopedPolicyRootV2Call): ScopedPolicyRootV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "consent", "factsVerified"], "Prepared call");
  exact(value.call, ["to", "data", "value"], "Unsigned call");
  const expected = prepareScopedPolicyRootV2Call(value.coordinates, value.caller, value.request);
  if (value.factsVerified !== false || address(value.call.to) !== expected.call.to
    || bytes(value.call.data) !== expected.call.data || value.call.value !== 0n) throw Error("Prepared call differs");
  // Reconstruct all derivative signing fields rather than trusting a supplied digest or direct flag.
  if (!samePreparation(value.consent, expected.consent)) throw Error("Consent preparation differs");
  return expected;
}

function samePreparation(value: unknown, expected: unknown): boolean {
  if (expected === null || typeof expected !== "object") return value === expected;
  if (!value || typeof value !== "object" || Array.isArray(value) !== Array.isArray(expected)) return false;
  const keys = Reflect.ownKeys(expected);
  if (Reflect.ownKeys(value).length !== keys.length || keys.some(key => !Object.hasOwn(value, key))) return false;
  return keys.every(key => samePreparation(Reflect.get(value, key), Reflect.get(expected, key)));
}

export type ScopedPolicyRootV2ReadRequest =
  | Readonly<{ kind: "previewScopedPolicyContentRootPublication"; publication: ScopedPolicyRootV2Publication; publisher: Address }>
  | Readonly<{ kind: "scopedContentRootHead" | "scopedTokenContentRoot"; scope: ScopedPolicyRootV2Scope }>
  | Readonly<{ kind: "scopedContentRootRecord" | "scopedPolicyContentRootBinding"; recordHash: Hex }>
  | Readonly<{ kind: "consumedArtistContentConsent"; recordHash: Hex }>
  | Readonly<{ kind: "scopedContentRootAggregate" | "artistContentEvolution" | "currentArtistContentState" | "artistContentFamilyState" | "firstReleaseRatification"; collectionId: bigint }>
  | Readonly<{ kind: "contentConsentEvidence" | "contentConsentEvidenceForHost"; collectionId: bigint; newFamilyStateHash: Hex }>;

export interface ScopedPolicyRootV2Read {
  readonly coordinates: ScopedPolicyRootV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyRootV2ReadRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

/** Read transport does not turn preview, historical evidence or current serving into interchangeable facts. */
export function prepareScopedPolicyRootV2Read(
  coordinates: ScopedPolicyRootV2Coordinates,
  caller: Address,
  request: ScopedPolicyRootV2ReadRequest,
): ScopedPolicyRootV2Read {
  const c = normalizeScopedPolicyRootV2Coordinates(coordinates);
  const actor = address(caller);
  let target = c.router;
  let iface = routerInterface;
  let args: readonly unknown[];
  let copied: ScopedPolicyRootV2ReadRequest;
  switch (request.kind) {
    case "previewScopedPolicyContentRootPublication": {
      exact(request, ["kind", "publication", "publisher"], "Preview");
      const p = validateScopedPolicyRootV2Publication(request.publication);
      const publisher = address(request.publisher, true);
      copied = Object.freeze({ kind: request.kind, publication: p, publisher });
      args = [p, publisher];
      break;
    }
    case "scopedContentRootHead":
    case "scopedTokenContentRoot": {
      exact(request, ["kind", "scope"], "Scope read");
      const scope = graph.validateScopedPolicyGraphV2Scope(request.scope);
      copied = Object.freeze({ kind: request.kind, scope });
      args = [scope];
      break;
    }
    case "scopedContentRootRecord":
    case "scopedPolicyContentRootBinding":
    case "consumedArtistContentConsent": {
      exact(request, ["kind", "recordHash"], "Record read");
      const recordHash = bytes(request.recordHash, 32);
      copied = Object.freeze({ kind: request.kind, recordHash });
      args = [recordHash];
      break;
    }
    case "contentConsentEvidence":
    case "contentConsentEvidenceForHost": {
      exact(request, ["kind", "collectionId", "newFamilyStateHash"], "Evidence read");
      const cid = uint(request.collectionId);
      const state = bytes(request.newFamilyStateHash, 32);
      copied = Object.freeze({ kind: request.kind, collectionId: cid, newFamilyStateHash: state });
      args = request.kind === "contentConsentEvidence" ? [cid, SCOPED_POLICY_ROOT_V2_FAMILY, state]
        : [cid, c.router, SCOPED_POLICY_ROOT_V2_FAMILY, state];
      target = c.artistRegistry;
      iface = artistInterface;
      break;
    }
    case "scopedContentRootAggregate":
    case "artistContentEvolution":
    case "currentArtistContentState":
    case "artistContentFamilyState":
    case "firstReleaseRatification": {
      exact(request, ["kind", "collectionId"], "Collection read");
      const cid = uint(request.collectionId);
      copied = Object.freeze({ kind: request.kind, collectionId: cid });
      args = request.kind === "artistContentFamilyState" ? [cid, SCOPED_POLICY_ROOT_V2_FAMILY] : [cid];
      if (request.kind === "firstReleaseRatification") { target = c.artistRegistry; iface = artistInterface; }
      break;
    }
    default: throw Error("Unsupported scoped root read");
  }
  return Object.freeze({ coordinates: c, caller: actor, request: copied,
    call: call(target, iface, request.kind, args), factsVerified: false });
}

export function normalizeScopedPolicyRootV2Read(value: ScopedPolicyRootV2Read): ScopedPolicyRootV2Read {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared read");
  exact(value.call, ["to", "data", "value"], "Read call");
  const expected = prepareScopedPolicyRootV2Read(value.coordinates, value.caller, value.request);
  if (value.factsVerified !== false || address(value.call.to) !== expected.call.to
    || bytes(value.call.data) !== expected.call.data || value.call.value !== 0n) throw Error("Prepared read differs");
  return expected;
}
