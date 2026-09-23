import {
  AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress,
  id, isHexString, keccak256, toUtf8Bytes,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type {
  TaggedPolicyViewV2Membership, TaggedPolicyViewV2Policy, TaggedPolicyViewV2CoordinatorPolicy,
} from "./current-tagged-policy-view-v2.js";

/** Independent ABI129 profile; preparation confers no publication or finality authority. */
export const SCOPED_POLICY_GRAPH_V2_SOURCE = "896899f7ca4130f86e066587f780a3b1f755a25d";
export const SCOPED_POLICY_GRAPH_V2_PROFILE = id("6529STREAM_SCOPED_POLICY_PUBLICATION_FACTORY_V2") as Hex;
export const SCOPED_POLICY_GRAPH_V2_SOURCE_FACTORY_PROFILE = id("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2") as Hex;
export const SCOPED_POLICY_GRAPH_V2_SOURCE_SET_PROFILE = id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2") as Hex;
/** Client allocation limits; these are not protocol limits on a complete policy inventory. */
export const SCOPED_POLICY_GRAPH_V2_MAX_CODEC_BYTES = 524288;
export const SCOPED_POLICY_GRAPH_V2_MAX_POLICIES = 1024;

type Four<T> = readonly [T, T, T, T];
type Five<T> = readonly [T, T, T, T, T];
type Six<T> = readonly [T, T, T, T, T, T];
type Seven<T> = readonly [T, T, T, T, T, T, T];
type Eleven<T> = readonly [...Seven<T>, ...Four<T>];
type Twelve<T> = readonly [...Seven<T>, ...Five<T>];

export interface ScopedPolicyGraphV2Coordinates {
  readonly chainId: bigint;
  readonly sourceFactory: Address;
  readonly publicationFactory: Address;
}

/** Raw original enum includes zero for the canonical missing Graph. Operations admit only 1/2/3. */
export interface ScopedPolicyGraphV2Scope {
  readonly scopeType: 0n | 1n | 2n | 3n | 4n;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly scopeId: Hex;
}

export interface ScopedPolicyGraphV2SourceDependencies {
  readonly targets: Four<Address>;
  readonly codeHashes: Four<Hex>;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly inventoryGas: bigint;
}

export interface ScopedPolicyGraphV2InventoryDependencies {
  readonly targets: Twelve<Address>;
  readonly codeHashes: Twelve<Hex>;
  readonly artistTargets: Five<Address>;
  readonly artistCodeHashes: Five<Hex>;
  readonly artistContentOwner: Address;
  readonly artistContentOwnerCodeHash: Hex;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly selectionGas: bigint;
  readonly snapshotGas: bigint;
  readonly referenceGas: bigint;
}

export interface ScopedPolicyGraphV2GasParameterConfig {
  readonly name: string;
  readonly genesisValue: bigint;
  readonly floor: bigint;
  readonly failureClass: bigint;
}

export interface ScopedPolicyGraphV2Recipe {
  readonly inventory: ScopedPolicyGraphV2InventoryDependencies;
  readonly targets: Four<Address>;
  readonly codeHashes: Four<Hex>;
  readonly readinessReadGas: bigint;
  readonly readinessSourceGas: bigint;
  readonly factorySourceGas: bigint;
  readonly bundleReadGas: bigint;
  readonly bundleArchiveGas: bigint;
  readonly checkpointGas: readonly [ScopedPolicyGraphV2GasParameterConfig, ScopedPolicyGraphV2GasParameterConfig];
  readonly outputGas: ScopedPolicyGraphV2GasParameterConfig;
  readonly snapshotGas: readonly [ScopedPolicyGraphV2GasParameterConfig, ScopedPolicyGraphV2GasParameterConfig, ScopedPolicyGraphV2GasParameterConfig];
  readonly referenceGas: Four<ScopedPolicyGraphV2GasParameterConfig>;
}

export interface ScopedPolicyGraphV2Graph {
  readonly scope: ScopedPolicyGraphV2Scope;
  readonly inventoryPlan: Hex;
  readonly sourceSet: Address;
  readonly sourceSetCodeHash: Hex;
  readonly graphId: Hex;
  readonly children: Seven<Address>;
  readonly codeHashes: Seven<Hex>;
  readonly preparedChildren: bigint;
}

export interface ScopedPolicyGraphV2FactoryBinding {
  readonly factory: Address;
  readonly factoryCodeHash: Hex;
  readonly recipeHash: Hex;
  readonly sourceFactoryDependenciesHash: Hex;
  readonly graphGas: bigint;
  readonly configurationHash: Hex;
}

export interface ScopedPolicyGraphV2SnapshotDependencies {
  readonly targets: Eleven<Address>;
  readonly codeHashes: Eleven<Hex>;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly inventoryGas: bigint;
}

export interface ScopedPolicyGraphV2ReferenceDependencies {
  readonly targets: Seven<Address>;
  readonly codeHashes: Seven<Hex>;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly snapshotGas: bigint;
  readonly archiveGas: bigint;
}

export interface ScopedPolicyGraphV2BundleDependencies {
  readonly targets: Six<Address>;
  readonly codeHashes: Six<Hex>;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly archiveGas: bigint;
}

/** The three original shared type declarations are byte-identical to the previous source profile. */
export type ScopedPolicyGraphV2Membership = TaggedPolicyViewV2Membership;
export type ScopedPolicyGraphV2Policy = TaggedPolicyViewV2Policy;
export type ScopedPolicyGraphV2CoordinatorPolicy = TaggedPolicyViewV2CoordinatorPolicy;

export interface ScopedPolicyGraphV2Coordinator {
  readonly coordinator: Address;
  readonly indexedCodeHash: Hex;
  readonly firstTokenIndex: bigint;
}

export interface ScopedPolicyGraphV2InventoryProgress {
  readonly exists: boolean;
  readonly complete: boolean;
  readonly processedTokens: bigint;
  readonly tokenCount: bigint;
  readonly coordinatorCount: bigint;
  readonly tokenChain: Hex;
  readonly coordinatorChain: Hex;
  readonly commitment: Hex;
}

export interface ScopedPolicyGraphV2PolicyEvidence {
  readonly planId: Hex;
  readonly inventoryHash: Hex;
  readonly policyChainHash: Hex;
  readonly policyCount: bigint;
  readonly allFrozen: boolean;
  readonly policies: readonly ScopedPolicyGraphV2CoordinatorPolicy[];
}

export interface ScopedPolicyGraphV2CurrentRoute {
  readonly componentType: Hex;
  readonly component: Address;
  readonly interfaceId: Hex;
  readonly codeHash: Hex;
}

export interface ScopedPolicyGraphV2ComponentExpectation extends ScopedPolicyGraphV2CurrentRoute {
  readonly moduleVersion: Hex;
  readonly manifestHash: Hex;
  readonly dataHash: Hex;
}

export const SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE = "tuple(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId)";
export const SCOPED_POLICY_GRAPH_V2_SOURCE_DEPENDENCIES_TUPLE = "tuple(address[4] targets,bytes32[4] codeHashes,uint256 chainId,uint32 readGas,uint32 inventoryGas)";
export const SCOPED_POLICY_GRAPH_V2_INVENTORY_DEPENDENCIES_TUPLE = "tuple(address[12] targets,bytes32[12] codeHashes,address[5] artistTargets,bytes32[5] artistCodeHashes,address artistContentOwner,bytes32 artistContentOwnerCodeHash,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 selectionGas,uint256 snapshotGas,uint256 referenceGas)";
export const SCOPED_POLICY_GRAPH_V2_GAS_PARAMETER_CONFIG_TUPLE = "tuple(string name,uint256 genesisValue,uint256 floor,uint8 failureClass)";
export const SCOPED_POLICY_GRAPH_V2_RECIPE_TUPLE = `tuple(${SCOPED_POLICY_GRAPH_V2_INVENTORY_DEPENDENCIES_TUPLE} inventory,address[4] targets,bytes32[4] codeHashes,uint32 readinessReadGas,uint32 readinessSourceGas,uint256 factorySourceGas,uint256 bundleReadGas,uint256 bundleArchiveGas,${SCOPED_POLICY_GRAPH_V2_GAS_PARAMETER_CONFIG_TUPLE}[2] checkpointGas,${SCOPED_POLICY_GRAPH_V2_GAS_PARAMETER_CONFIG_TUPLE} outputGas,${SCOPED_POLICY_GRAPH_V2_GAS_PARAMETER_CONFIG_TUPLE}[3] snapshotGas,${SCOPED_POLICY_GRAPH_V2_GAS_PARAMETER_CONFIG_TUPLE}[4] referenceGas)`;
export const SCOPED_POLICY_GRAPH_V2_GRAPH_TUPLE = `tuple(${SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE} scope,bytes32 inventoryPlan,address sourceSet,bytes32 sourceSetCodeHash,bytes32 graphId,address[7] children,bytes32[7] codeHashes,uint8 preparedChildren)`;
export const SCOPED_POLICY_GRAPH_V2_FACTORY_BINDING_TUPLE = "tuple(address factory,bytes32 factoryCodeHash,bytes32 recipeHash,bytes32 sourceFactoryDependenciesHash,uint256 graphGas,bytes32 configurationHash)";
export const SCOPED_POLICY_GRAPH_V2_SNAPSHOT_DEPENDENCIES_TUPLE = "tuple(address[11] targets,bytes32[11] codeHashes,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 inventoryGas)";
export const SCOPED_POLICY_GRAPH_V2_REFERENCE_DEPENDENCIES_TUPLE = "tuple(address[7] targets,bytes32[7] codeHashes,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 snapshotGas,uint256 archiveGas)";
export const SCOPED_POLICY_GRAPH_V2_BUNDLE_DEPENDENCIES_TUPLE = "tuple(address[6] targets,bytes32[6] codeHashes,uint256 chainId,uint256 readGas,uint256 archiveGas)";
export const SCOPED_POLICY_GRAPH_V2_MEMBERSHIP_TUPLE = "tuple(bytes32 scopeSubject,bytes32 scopeManifestHash,bytes32 sourceRecordHash,uint256 tokenCount,bytes32 tokenListHash,bytes32 membershipHash,uint256 inventoryCount,bytes32 inventoryPrefixHash)";
export const SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE = "tuple(bool configured,bool explicitPolicy,bool frozen,uint8 mode,uint8 securityClass,uint8 renderRequirement,uint64 revision,uint32 providerEpoch,bytes32 policyHash,bytes32 contentStateHash,bytes32 lastActionId,bytes32 artistConsentRecord)";
export const SCOPED_POLICY_GRAPH_V2_COORDINATOR_POLICY_TUPLE = `tuple(address coordinator,bytes32 indexedCodeHash,uint256 firstTokenIndex,bool frozen,bytes32 moduleVersion,bytes32 moduleManifestHash,bytes32 moduleSchemaHash,bytes32 deploymentManifestHash,bytes32 policyHash,address provider,uint32 epoch,bytes32 salt,bytes32 componentDataHash,bool explicitPolicy,${SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE} collectionPolicy)`;
export const SCOPED_POLICY_GRAPH_V2_COORDINATOR_TUPLE = "tuple(address coordinator,bytes32 indexedCodeHash,uint256 firstTokenIndex)";
export const SCOPED_POLICY_GRAPH_V2_INVENTORY_PROGRESS_TUPLE = "tuple(bool exists,bool complete,uint256 processedTokens,uint256 tokenCount,uint256 coordinatorCount,bytes32 tokenChain,bytes32 coordinatorChain,bytes32 commitment)";
export const SCOPED_POLICY_GRAPH_V2_POLICY_EVIDENCE_TUPLE = `tuple(bytes32 planId,bytes32 inventoryHash,bytes32 policyChainHash,uint256 policyCount,bool allFrozen,${SCOPED_POLICY_GRAPH_V2_COORDINATOR_POLICY_TUPLE}[] policies)`;
export const SCOPED_POLICY_GRAPH_V2_CURRENT_ROUTE_TUPLE = "tuple(bytes32 componentType,address component,bytes4 interfaceId,bytes32 codeHash)";
export const SCOPED_POLICY_GRAPH_V2_COMPONENT_EXPECTATION_TUPLE = "tuple(bytes32 componentType,address component,bytes4 interfaceId,bytes32 codeHash,bytes32 moduleVersion,bytes32 manifestHash,bytes32 dataHash)";

export const SCOPED_POLICY_GRAPH_V2_SOURCE_FACTORY_ABI = Object.freeze([
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function scopedPolicyFactoryProfile() pure returns (bytes32)",
  `function dependencies() view returns (${SCOPED_POLICY_GRAPH_V2_SOURCE_DEPENDENCIES_TUPLE})`,
  "function core() view returns (address)",
  "function metadataHost() view returns (address)",
  "function scopeMembershipHost() view returns (address)",
  "function coordinatorInventory() view returns (address)",
  `function currentInventoryPlan(${SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE} scope) view returns (bytes32)`,
  `function prepareSourceSet(${SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE} scope) returns (address sourceSet)`,
  "function sourceSetForPlan(bytes32 plan) view returns (address sourceSet,bytes32 codeHash)",
  `function requireCurrentComponent(${SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE} scope) view returns (${SCOPED_POLICY_GRAPH_V2_COMPONENT_EXPECTATION_TUPLE})`,
  `function requireCurrentRoute(${SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE} scope) view returns (${SCOPED_POLICY_GRAPH_V2_CURRENT_ROUTE_TUPLE})`,
  "event EntropySourceSetPrepared(bytes32 indexed planId,address indexed sourceSet,bytes32 indexed scopeSubject,bytes32 sourceSetCodeHash,bytes32 dataHash)",
]);

export const SCOPED_POLICY_GRAPH_V2_PUBLICATION_FACTORY_ABI = Object.freeze([
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function scopedPolicyPublicationFactoryProfile() pure returns (bytes32)",
  "function core() view returns (address)",
  "function metadataHost() view returns (address)",
  "function entropySourceFactory() view returns (address)",
  "function recipeHash() view returns (bytes32)",
  "function sourceFactoryDependenciesHash() view returns (bytes32)",
  `function recipe() view returns (${SCOPED_POLICY_GRAPH_V2_RECIPE_TUPLE})`,
  `function prepareGraph(${SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE} scope,uint8 maximumChildren) returns (${SCOPED_POLICY_GRAPH_V2_GRAPH_TUPLE})`,
  `function graphForPlan(bytes32 plan) view returns (${SCOPED_POLICY_GRAPH_V2_GRAPH_TUPLE})`,
  `function requireCurrentGraph(${SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE} scope) view returns (${SCOPED_POLICY_GRAPH_V2_GRAPH_TUPLE} g)`,
  "event ScopedPolicyPublicationChildPrepared(uint16 schemaVersion,bytes32 indexed graphId,bytes32 indexed inventoryPlan,uint8 indexed childIndex,address child,bytes32 codeHash)",
]);

export const SCOPED_POLICY_GRAPH_V2_PROVIDER_BINDING_ABI = Object.freeze([
  `function scopedPolicyPublicationBinding() view returns (${SCOPED_POLICY_GRAPH_V2_FACTORY_BINDING_TUPLE})`,
]);

const coder = AbiCoder.defaultAbiCoder();
const sourceInterface = new Interface(SCOPED_POLICY_GRAPH_V2_SOURCE_FACTORY_ABI);
const publicationInterface = new Interface(SCOPED_POLICY_GRAPH_V2_PUBLICATION_FACTORY_ABI);

export function scopedPolicyGraphV2SourceFactoryInterface(): Interface {
  return new Interface(SCOPED_POLICY_GRAPH_V2_SOURCE_FACTORY_ABI);
}

export function scopedPolicyGraphV2PublicationFactoryInterface(): Interface {
  return new Interface(SCOPED_POLICY_GRAPH_V2_PUBLICATION_FACTORY_ABI);
}

function exact(value: unknown, keys: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).length !== keys.length
    || Reflect.ownKeys(value).some(key => typeof key !== "string" || !keys.includes(key))) {
    throw Error(`${label} has missing or unknown fields`);
  }
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) throw Error(`Expected uint${bits} bigint`);
  return value;
}

function bytes(value: unknown, size?: number): Hex {
  if (typeof value !== "string" || !isHexString(value, size) || value.length % 2 !== 0) throw Error("Invalid bytes");
  return value.toLowerCase() as Hex;
}

function address(value: unknown, required = false): Address {
  if (typeof value !== "string") throw Error("Invalid address");
  const result = getAddress(value) as Address;
  if (required && result === ZeroAddress) throw Error("Expected nonzero address");
  return result;
}

function commitment(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === ZeroHash) throw Error("Expected nonzero commitment");
  return result;
}

function list(value: unknown, length: number, decoded: boolean): readonly unknown[] {
  if (!Array.isArray(value) || (length >= 0 ? value.length !== length : value.length > SCOPED_POLICY_GRAPH_V2_MAX_POLICIES)
    || (!decoded && Reflect.ownKeys(value).length !== value.length + 1)
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) throw Error("Expected dense bounded array");
  return value;
}

function normalizeValue(type: ParamType, value: unknown, decoded = false): unknown {
  if (type.baseType === "tuple") {
    const fields = type.components!;
    if (!decoded) exact(value, fields.map(field => field.name), "Tuple");
    return Object.freeze(Object.fromEntries(fields.map((field, index) => [field.name,
      normalizeValue(field, decoded ? (value as readonly unknown[])[index]
        : (value as Record<string, unknown>)[field.name], decoded)])));
  }
  if (type.baseType === "array") return Object.freeze(list(value, type.arrayLength!, decoded)
    .map(item => normalizeValue(type.arrayChildren!, item, decoded)));
  if (type.type.startsWith("uint")) {
    const result = uint(value, Number(type.type.slice(4)));
    if (type.name === "scopeType" && result > 4n) throw Error("Unknown original scope enum");
    return result;
  }
  if (type.type.startsWith("bytes")) return bytes(value, Number(type.type.slice(5)));
  if (type.type === "address") return address(value);
  if (type.type === "bool") {
    if (typeof value !== "boolean") throw Error("Expected boolean");
    return value;
  }
  if (type.type === "string") {
    if (typeof value !== "string" || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)
      || toUtf8Bytes(value).length > 256) throw Error("Gas parameter name exceeds client text bound");
    return value;
  }
  throw Error(`Unsupported ABI type ${type.type}`);
}

function normalize<T>(tuple: string, value: unknown): T {
  return normalizeValue(ParamType.from(tuple), value) as T;
}

function encode(tuple: string, value: unknown): Hex {
  const raw = coder.encode([tuple], [normalize(tuple, value)]) as Hex;
  if ((raw.length - 2) / 2 > SCOPED_POLICY_GRAPH_V2_MAX_CODEC_BYTES) throw Error("Complete codec byte bound");
  return raw;
}

function decode<T>(tuple: string, input: Hex): T {
  const raw = bytes(input);
  if (raw.length <= 2 || (raw.length - 2) / 2 > SCOPED_POLICY_GRAPH_V2_MAX_CODEC_BYTES) throw Error("Complete codec byte bound");
  const value = normalizeValue(ParamType.from(tuple), coder.decode([tuple], raw)[0], true) as T;
  if (encode(tuple, value) !== raw) throw Error("Noncanonical ABI encoding");
  return value;
}

function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

function equal(tuple: string, a: unknown, b: unknown): boolean {
  return encode(tuple, a) === encode(tuple, b);
}

export function normalizeScopedPolicyGraphV2Coordinates(value: ScopedPolicyGraphV2Coordinates): ScopedPolicyGraphV2Coordinates {
  exact(value, ["chainId", "sourceFactory", "publicationFactory"], "Coordinates");
  return Object.freeze({ chainId: uint(value.chainId), sourceFactory: address(value.sourceFactory, true),
    publicationFactory: address(value.publicationFactory, true) });
}

export function normalizeScopedPolicyGraphV2Scope(value: ScopedPolicyGraphV2Scope): ScopedPolicyGraphV2Scope {
  const result = normalize<ScopedPolicyGraphV2Scope>(SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, value);
  if (result.scopeType > 4n) throw Error("Unknown original scope enum");
  return result;
}

export function validateScopedPolicyGraphV2Scope(value: ScopedPolicyGraphV2Scope): ScopedPolicyGraphV2Scope {
  const s = normalizeScopedPolicyGraphV2Scope(value);
  if (s.collectionId === 0n || (s.scopeType === 1n ? s.tokenId === 0n || s.scopeId !== ZeroHash
    : (s.scopeType !== 2n && s.scopeType !== 3n) || s.tokenId !== 0n || s.scopeId === ZeroHash)) {
    throw Error("This publication profile requires TOKEN, RELEASE or SEASON");
  }
  return s;
}

export function normalizeScopedPolicyGraphV2SourceDependencies(
  value: ScopedPolicyGraphV2SourceDependencies,
): ScopedPolicyGraphV2SourceDependencies {
  return normalize(SCOPED_POLICY_GRAPH_V2_SOURCE_DEPENDENCIES_TUPLE, value);
}

export function encodeScopedPolicyGraphV2SourceDependencies(value: ScopedPolicyGraphV2SourceDependencies): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_SOURCE_DEPENDENCIES_TUPLE, value);
}

export function decodeScopedPolicyGraphV2SourceDependencies(value: Hex): ScopedPolicyGraphV2SourceDependencies {
  return decode(SCOPED_POLICY_GRAPH_V2_SOURCE_DEPENDENCIES_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2InventoryDependencies(
  value: ScopedPolicyGraphV2InventoryDependencies,
): ScopedPolicyGraphV2InventoryDependencies {
  return normalize(SCOPED_POLICY_GRAPH_V2_INVENTORY_DEPENDENCIES_TUPLE, value);
}

export function encodeScopedPolicyGraphV2InventoryDependencies(value: ScopedPolicyGraphV2InventoryDependencies): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_INVENTORY_DEPENDENCIES_TUPLE, value);
}

export function decodeScopedPolicyGraphV2InventoryDependencies(value: Hex): ScopedPolicyGraphV2InventoryDependencies {
  return decode(SCOPED_POLICY_GRAPH_V2_INVENTORY_DEPENDENCIES_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2GasParameterConfig(
  value: ScopedPolicyGraphV2GasParameterConfig,
): ScopedPolicyGraphV2GasParameterConfig {
  return normalize(SCOPED_POLICY_GRAPH_V2_GAS_PARAMETER_CONFIG_TUPLE, value);
}

export function encodeScopedPolicyGraphV2GasParameterConfig(value: ScopedPolicyGraphV2GasParameterConfig): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_GAS_PARAMETER_CONFIG_TUPLE, value);
}

export function decodeScopedPolicyGraphV2GasParameterConfig(value: Hex): ScopedPolicyGraphV2GasParameterConfig {
  return decode(SCOPED_POLICY_GRAPH_V2_GAS_PARAMETER_CONFIG_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2Recipe(
  value: ScopedPolicyGraphV2Recipe,
): ScopedPolicyGraphV2Recipe {
  return normalize(SCOPED_POLICY_GRAPH_V2_RECIPE_TUPLE, value);
}

export function encodeScopedPolicyGraphV2Recipe(value: ScopedPolicyGraphV2Recipe): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_RECIPE_TUPLE, value);
}

export function decodeScopedPolicyGraphV2Recipe(value: Hex): ScopedPolicyGraphV2Recipe {
  return decode(SCOPED_POLICY_GRAPH_V2_RECIPE_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2Graph(
  value: ScopedPolicyGraphV2Graph,
): ScopedPolicyGraphV2Graph {
  return normalize(SCOPED_POLICY_GRAPH_V2_GRAPH_TUPLE, value);
}

export function encodeScopedPolicyGraphV2Graph(value: ScopedPolicyGraphV2Graph): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_GRAPH_TUPLE, value);
}

export function decodeScopedPolicyGraphV2Graph(value: Hex): ScopedPolicyGraphV2Graph {
  return decode(SCOPED_POLICY_GRAPH_V2_GRAPH_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2FactoryBinding(
  value: ScopedPolicyGraphV2FactoryBinding,
): ScopedPolicyGraphV2FactoryBinding {
  return normalize(SCOPED_POLICY_GRAPH_V2_FACTORY_BINDING_TUPLE, value);
}

export function encodeScopedPolicyGraphV2FactoryBinding(value: ScopedPolicyGraphV2FactoryBinding): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_FACTORY_BINDING_TUPLE, value);
}

export function decodeScopedPolicyGraphV2FactoryBinding(value: Hex): ScopedPolicyGraphV2FactoryBinding {
  return decode(SCOPED_POLICY_GRAPH_V2_FACTORY_BINDING_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2SnapshotDependencies(
  value: ScopedPolicyGraphV2SnapshotDependencies,
): ScopedPolicyGraphV2SnapshotDependencies {
  return normalize(SCOPED_POLICY_GRAPH_V2_SNAPSHOT_DEPENDENCIES_TUPLE, value);
}

export function encodeScopedPolicyGraphV2SnapshotDependencies(value: ScopedPolicyGraphV2SnapshotDependencies): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_SNAPSHOT_DEPENDENCIES_TUPLE, value);
}

export function decodeScopedPolicyGraphV2SnapshotDependencies(value: Hex): ScopedPolicyGraphV2SnapshotDependencies {
  return decode(SCOPED_POLICY_GRAPH_V2_SNAPSHOT_DEPENDENCIES_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2ReferenceDependencies(
  value: ScopedPolicyGraphV2ReferenceDependencies,
): ScopedPolicyGraphV2ReferenceDependencies {
  return normalize(SCOPED_POLICY_GRAPH_V2_REFERENCE_DEPENDENCIES_TUPLE, value);
}

export function encodeScopedPolicyGraphV2ReferenceDependencies(value: ScopedPolicyGraphV2ReferenceDependencies): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_REFERENCE_DEPENDENCIES_TUPLE, value);
}

export function decodeScopedPolicyGraphV2ReferenceDependencies(value: Hex): ScopedPolicyGraphV2ReferenceDependencies {
  return decode(SCOPED_POLICY_GRAPH_V2_REFERENCE_DEPENDENCIES_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2BundleDependencies(
  value: ScopedPolicyGraphV2BundleDependencies,
): ScopedPolicyGraphV2BundleDependencies {
  return normalize(SCOPED_POLICY_GRAPH_V2_BUNDLE_DEPENDENCIES_TUPLE, value);
}

export function encodeScopedPolicyGraphV2BundleDependencies(value: ScopedPolicyGraphV2BundleDependencies): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_BUNDLE_DEPENDENCIES_TUPLE, value);
}

export function decodeScopedPolicyGraphV2BundleDependencies(value: Hex): ScopedPolicyGraphV2BundleDependencies {
  return decode(SCOPED_POLICY_GRAPH_V2_BUNDLE_DEPENDENCIES_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2Membership(
  value: ScopedPolicyGraphV2Membership,
): ScopedPolicyGraphV2Membership {
  return normalize(SCOPED_POLICY_GRAPH_V2_MEMBERSHIP_TUPLE, value);
}

export function encodeScopedPolicyGraphV2Membership(value: ScopedPolicyGraphV2Membership): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_MEMBERSHIP_TUPLE, value);
}

export function decodeScopedPolicyGraphV2Membership(value: Hex): ScopedPolicyGraphV2Membership {
  return decode(SCOPED_POLICY_GRAPH_V2_MEMBERSHIP_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2Policy(
  value: ScopedPolicyGraphV2Policy,
): ScopedPolicyGraphV2Policy {
  return normalize(SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE, value);
}

export function encodeScopedPolicyGraphV2Policy(value: ScopedPolicyGraphV2Policy): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE, value);
}

export function decodeScopedPolicyGraphV2Policy(value: Hex): ScopedPolicyGraphV2Policy {
  return decode(SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2CoordinatorPolicy(
  value: ScopedPolicyGraphV2CoordinatorPolicy,
): ScopedPolicyGraphV2CoordinatorPolicy {
  return normalize(SCOPED_POLICY_GRAPH_V2_COORDINATOR_POLICY_TUPLE, value);
}

export function encodeScopedPolicyGraphV2CoordinatorPolicy(value: ScopedPolicyGraphV2CoordinatorPolicy): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_COORDINATOR_POLICY_TUPLE, value);
}

export function decodeScopedPolicyGraphV2CoordinatorPolicy(value: Hex): ScopedPolicyGraphV2CoordinatorPolicy {
  return decode(SCOPED_POLICY_GRAPH_V2_COORDINATOR_POLICY_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2Coordinator(
  value: ScopedPolicyGraphV2Coordinator,
): ScopedPolicyGraphV2Coordinator {
  return normalize(SCOPED_POLICY_GRAPH_V2_COORDINATOR_TUPLE, value);
}

export function encodeScopedPolicyGraphV2Coordinator(value: ScopedPolicyGraphV2Coordinator): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_COORDINATOR_TUPLE, value);
}

export function decodeScopedPolicyGraphV2Coordinator(value: Hex): ScopedPolicyGraphV2Coordinator {
  return decode(SCOPED_POLICY_GRAPH_V2_COORDINATOR_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2InventoryProgress(
  value: ScopedPolicyGraphV2InventoryProgress,
): ScopedPolicyGraphV2InventoryProgress {
  return normalize(SCOPED_POLICY_GRAPH_V2_INVENTORY_PROGRESS_TUPLE, value);
}

export function encodeScopedPolicyGraphV2InventoryProgress(value: ScopedPolicyGraphV2InventoryProgress): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_INVENTORY_PROGRESS_TUPLE, value);
}

export function decodeScopedPolicyGraphV2InventoryProgress(value: Hex): ScopedPolicyGraphV2InventoryProgress {
  return decode(SCOPED_POLICY_GRAPH_V2_INVENTORY_PROGRESS_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2PolicyEvidence(
  value: ScopedPolicyGraphV2PolicyEvidence,
): ScopedPolicyGraphV2PolicyEvidence {
  return normalize(SCOPED_POLICY_GRAPH_V2_POLICY_EVIDENCE_TUPLE, value);
}

export function encodeScopedPolicyGraphV2PolicyEvidence(value: ScopedPolicyGraphV2PolicyEvidence): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_POLICY_EVIDENCE_TUPLE, value);
}

export function decodeScopedPolicyGraphV2PolicyEvidence(value: Hex): ScopedPolicyGraphV2PolicyEvidence {
  return decode(SCOPED_POLICY_GRAPH_V2_POLICY_EVIDENCE_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2CurrentRoute(
  value: ScopedPolicyGraphV2CurrentRoute,
): ScopedPolicyGraphV2CurrentRoute {
  return normalize(SCOPED_POLICY_GRAPH_V2_CURRENT_ROUTE_TUPLE, value);
}

export function encodeScopedPolicyGraphV2CurrentRoute(value: ScopedPolicyGraphV2CurrentRoute): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_CURRENT_ROUTE_TUPLE, value);
}

export function decodeScopedPolicyGraphV2CurrentRoute(value: Hex): ScopedPolicyGraphV2CurrentRoute {
  return decode(SCOPED_POLICY_GRAPH_V2_CURRENT_ROUTE_TUPLE, value);
}

export function normalizeScopedPolicyGraphV2ComponentExpectation(
  value: ScopedPolicyGraphV2ComponentExpectation,
): ScopedPolicyGraphV2ComponentExpectation {
  return normalize(SCOPED_POLICY_GRAPH_V2_COMPONENT_EXPECTATION_TUPLE, value);
}

export function encodeScopedPolicyGraphV2ComponentExpectation(value: ScopedPolicyGraphV2ComponentExpectation): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_COMPONENT_EXPECTATION_TUPLE, value);
}

export function decodeScopedPolicyGraphV2ComponentExpectation(value: Hex): ScopedPolicyGraphV2ComponentExpectation {
  return decode(SCOPED_POLICY_GRAPH_V2_COMPONENT_EXPECTATION_TUPLE, value);
}

/** Validate supplied constructor facts. Runtime identities and current routes require RPC evidence. */
export function validateScopedPolicyGraphV2Recipe(
  chainId: bigint,
  value: ScopedPolicyGraphV2Recipe,
): ScopedPolicyGraphV2Recipe {
  const r = normalizeScopedPolicyGraphV2Recipe(value);
  const d = r.inventory;
  if (d.chainId !== uint(chainId) || d.readGas < 50000n
    || [d.sourceGas, d.selectionGas, d.snapshotGas, d.referenceGas].some(gas => gas < d.readGas)
    || r.readinessReadGas < 50000n || r.readinessSourceGas < r.readinessReadGas
    || r.factorySourceGas < d.readGas || r.bundleReadGas < 50000n
    || r.bundleArchiveGas < r.bundleReadGas) throw Error("Invalid recipe gas configuration");
  d.targets.forEach((target, i) => {
    if (i === 5 || i === 6) {
      if (target !== ZeroAddress || d.codeHashes[i] !== ZeroHash) throw Error("Recipe holes 5/6 must be zero");
    } else { address(target, true); commitment(d.codeHashes[i]); }
  });
  d.artistTargets.forEach((target, i) => { address(target, true); commitment(d.artistCodeHashes[i]); });
  address(d.artistContentOwner, true);
  commitment(d.artistContentOwnerCodeHash);
  r.targets.forEach((target, i) => { address(target, true); commitment(r.codeHashes[i]); });
  const checkGas = (g: ScopedPolicyGraphV2GasParameterConfig, name: string, failureClass: bigint): void => {
    if (g.name !== name || g.floor === 0n || g.genesisValue < g.floor
      || g.genesisValue < 50000n || g.genesisValue > 0xffffffffn || g.failureClass !== failureClass) {
      throw Error(`Invalid recipe gas parameter ${name}`);
    }
  };
  checkGas(r.checkpointGas[0], "STATIC_CONTENT_READ_GAS", 2n);
  checkGas(r.checkpointGas[1], "STATIC_CONTENT_RENDER_GAS", 2n);
  checkGas(r.outputGas, "STATIC_OUTPUT_MANIFEST_READ_GAS", 2n);
  ["READ", "SOURCE", "INVENTORY"].forEach((name, i) => {
    checkGas(r.snapshotGas[i]!, `SCOPED_POLICY_SNAPSHOT_${name}_GAS`, 2n);
  });
  ["READ", "SOURCE", "SNAPSHOT", "ARCHIVE"].forEach((name, i) => {
    checkGas(r.referenceGas[i]!, `SCOPED_POLICY_REFERENCE_${name}_GAS`, 1n);
  });
  if (r.snapshotGas[1].genesisValue < r.snapshotGas[0].genesisValue
    || r.snapshotGas[2].genesisValue < r.snapshotGas[0].genesisValue
    || r.referenceGas[1].genesisValue < r.referenceGas[0].genesisValue
    || r.referenceGas[2].genesisValue < r.referenceGas[1].genesisValue
    || r.referenceGas[3].genesisValue < r.referenceGas[0].genesisValue) {
    throw Error("Invalid recipe gas ordering");
  }
  return r;
}

export function validateScopedPolicyGraphV2SourceDependencies(
  chainId: bigint,
  value: ScopedPolicyGraphV2SourceDependencies,
): ScopedPolicyGraphV2SourceDependencies {
  const d = normalizeScopedPolicyGraphV2SourceDependencies(value);
  if (d.chainId !== uint(chainId) || d.readGas < 50000n || d.inventoryGas < d.readGas) {
    throw Error("Invalid source dependencies gas/chain");
  }
  d.targets.forEach((target, i) => { address(target, true); commitment(d.codeHashes[i]); });
  return d;
}

export function scopedPolicyGraphV2RecipeHash(chainId: bigint, recipe: ScopedPolicyGraphV2Recipe): Hex {
  return hash(["bytes32", "uint256", SCOPED_POLICY_GRAPH_V2_RECIPE_TUPLE],
    [SCOPED_POLICY_GRAPH_V2_PROFILE, uint(chainId), normalizeScopedPolicyGraphV2Recipe(recipe)]);
}

export function scopedPolicyGraphV2DependenciesHash(dependencies: ScopedPolicyGraphV2SourceDependencies): Hex {
  return keccak256(encodeScopedPolicyGraphV2SourceDependencies(dependencies)) as Hex;
}

export function scopedPolicyGraphV2GraphId(
  coordinates: ScopedPolicyGraphV2Coordinates,
  recipeHash: Hex,
  sourceFactoryDependenciesHash: Hex,
  scope: ScopedPolicyGraphV2Scope,
  inventoryPlan: Hex,
  sourceSet: Address,
  sourceSetCodeHash: Hex,
): Hex {
  const c = normalizeScopedPolicyGraphV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "bytes32", "bytes32",
    SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, "bytes32", "address", "bytes32"],
  [id("6529STREAM_SCOPED_POLICY_PUBLICATION_GRAPH_V2"), c.chainId, c.publicationFactory,
    bytes(recipeHash, 32), bytes(sourceFactoryDependenciesHash, 32), normalizeScopedPolicyGraphV2Scope(scope),
    bytes(inventoryPlan, 32), address(sourceSet), bytes(sourceSetCodeHash, 32)]);
}

export interface ScopedPolicyGraphV2GraphValidation {
  readonly status: "missing" | "partial" | "complete";
  readonly graph: ScopedPolicyGraphV2Graph;
  readonly recipeHash: Hex;
  readonly sourceFactoryDependenciesHash: Hex;
  readonly factsVerified: false;
}

/** Authenticate a persistent graph against supplied facts; this does not establish currentness. */
export function validateScopedPolicyGraphV2Graph(
  coordinates: ScopedPolicyGraphV2Coordinates,
  recipe: ScopedPolicyGraphV2Recipe,
  sourceDependencies: ScopedPolicyGraphV2SourceDependencies,
  value: ScopedPolicyGraphV2Graph,
  expected: { readonly expectedPlan?: Hex; readonly expectedScope?: ScopedPolicyGraphV2Scope } = {},
): ScopedPolicyGraphV2GraphValidation {
  exact(expected, Object.keys(expected), "Expected graph identity");
  if (Object.keys(expected).some(key => key !== "expectedPlan" && key !== "expectedScope")) {
    throw Error("Unknown graph identity constraint");
  }
  const c = normalizeScopedPolicyGraphV2Coordinates(coordinates);
  const r = validateScopedPolicyGraphV2Recipe(c.chainId, recipe);
  const d = validateScopedPolicyGraphV2SourceDependencies(c.chainId, sourceDependencies);
  if (r.targets[2] !== c.sourceFactory || d.targets[0] !== r.inventory.targets[0]
    || d.codeHashes[0] !== r.inventory.codeHashes[0] || d.targets[1] !== r.inventory.targets[1]
    || d.codeHashes[1] !== r.inventory.codeHashes[1] || d.targets[2] !== r.targets[0]
    || d.codeHashes[2] !== r.codeHashes[0]) throw Error("Recipe/source dependency mismatch");
  const g = normalizeScopedPolicyGraphV2Graph(value);
  const recipeHash = scopedPolicyGraphV2RecipeHash(c.chainId, r);
  const sourceFactoryDependenciesHash = scopedPolicyGraphV2DependenciesHash(d);
  let status: ScopedPolicyGraphV2GraphValidation["status"];
  if (g.graphId === ZeroHash) {
    if (!/^0x0+$/.test(encodeScopedPolicyGraphV2Graph(g))) throw Error("Noncanonical missing graph");
    status = "missing";
  } else {
    validateScopedPolicyGraphV2Scope(g.scope);
    commitment(g.inventoryPlan); address(g.sourceSet, true); commitment(g.sourceSetCodeHash);
    if (g.preparedChildren < 1n || g.preparedChildren > 7n) throw Error("Invalid persistent graph child count");
    if (expected.expectedPlan !== undefined && g.inventoryPlan !== bytes(expected.expectedPlan, 32)) {
      throw Error("Unexpected inventory plan");
    }
    if (expected.expectedScope !== undefined && !equal(SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE,
      g.scope, normalizeScopedPolicyGraphV2Scope(expected.expectedScope))) throw Error("Unexpected graph scope");
    const expectedId = scopedPolicyGraphV2GraphId(c, recipeHash, sourceFactoryDependenciesHash,
      g.scope, g.inventoryPlan, g.sourceSet, g.sourceSetCodeHash);
    if (g.graphId !== expectedId) throw Error("Graph identity mismatch");
    g.children.forEach((child, i) => {
      if (BigInt(i) < g.preparedChildren) { address(child, true); commitment(g.codeHashes[i]); }
      else if (child !== ZeroAddress || g.codeHashes[i] !== ZeroHash) throw Error("Noncontiguous graph child prefix");
    });
    status = g.preparedChildren === 7n ? "complete" : "partial";
  }
  return Object.freeze({ status, graph: g, recipeHash, sourceFactoryDependenciesHash, factsVerified: false });
}

export function scopedPolicyGraphV2SnapshotDependencies(
  recipe: ScopedPolicyGraphV2Recipe,
  graph: ScopedPolicyGraphV2Graph,
): ScopedPolicyGraphV2SnapshotDependencies {
  const r = normalizeScopedPolicyGraphV2Recipe(recipe);
  const g = normalizeScopedPolicyGraphV2Graph(graph);
  return normalizeScopedPolicyGraphV2SnapshotDependencies({
    targets: [...r.inventory.targets.slice(0, 5), r.targets[0], r.targets[1], g.children[1],
      g.children[2], r.inventory.targets[10], g.sourceSet] as unknown as Eleven<Address>,
    codeHashes: [...r.inventory.codeHashes.slice(0, 5), r.codeHashes[0], r.codeHashes[1], g.codeHashes[1],
      g.codeHashes[2], r.inventory.codeHashes[10], g.sourceSetCodeHash] as unknown as Eleven<Hex>,
    chainId: r.inventory.chainId, readGas: r.snapshotGas[0].genesisValue,
    sourceGas: r.snapshotGas[1].genesisValue, inventoryGas: r.snapshotGas[2].genesisValue,
  });
}

export function scopedPolicyGraphV2ReferenceDependencies(
  recipe: ScopedPolicyGraphV2Recipe,
  graph: ScopedPolicyGraphV2Graph,
): ScopedPolicyGraphV2ReferenceDependencies {
  const r = normalizeScopedPolicyGraphV2Recipe(recipe);
  const g = normalizeScopedPolicyGraphV2Graph(graph);
  return normalizeScopedPolicyGraphV2ReferenceDependencies({
    targets: [...r.inventory.targets.slice(0, 5), g.children[3], r.inventory.targets[11]] as unknown as Seven<Address>,
    codeHashes: [...r.inventory.codeHashes.slice(0, 5), g.codeHashes[3], r.inventory.codeHashes[11]] as unknown as Seven<Hex>,
    chainId: r.inventory.chainId, readGas: r.referenceGas[0].genesisValue,
    sourceGas: r.referenceGas[1].genesisValue, snapshotGas: r.referenceGas[2].genesisValue,
    archiveGas: r.referenceGas[3].genesisValue,
  });
}

export function scopedPolicyGraphV2InventoryDependencies(
  recipe: ScopedPolicyGraphV2Recipe,
  graph: ScopedPolicyGraphV2Graph,
): ScopedPolicyGraphV2InventoryDependencies {
  const r = normalizeScopedPolicyGraphV2Recipe(recipe);
  const g = normalizeScopedPolicyGraphV2Graph(graph);
  const targets = [...r.inventory.targets];
  const codeHashes = [...r.inventory.codeHashes];
  targets[5] = g.children[3]; targets[6] = g.children[4];
  codeHashes[5] = g.codeHashes[3]; codeHashes[6] = g.codeHashes[4];
  return normalizeScopedPolicyGraphV2InventoryDependencies({ ...r.inventory,
    targets: targets as unknown as Twelve<Address>, codeHashes: codeHashes as unknown as Twelve<Hex> });
}

export function scopedPolicyGraphV2BundleDependencies(
  recipe: ScopedPolicyGraphV2Recipe,
  graph: ScopedPolicyGraphV2Graph,
): ScopedPolicyGraphV2BundleDependencies {
  const r = normalizeScopedPolicyGraphV2Recipe(recipe);
  const g = normalizeScopedPolicyGraphV2Graph(graph);
  return normalizeScopedPolicyGraphV2BundleDependencies({
    targets: [r.inventory.targets[0], r.inventory.targets[1], g.children[5], r.inventory.targets[10],
      r.inventory.targets[11], r.inventory.artistTargets[4]],
    codeHashes: [r.inventory.codeHashes[0], r.inventory.codeHashes[1], g.codeHashes[5], r.inventory.codeHashes[10],
      r.inventory.codeHashes[11], r.inventory.artistCodeHashes[4]],
    chainId: r.inventory.chainId, readGas: r.bundleReadGas, archiveGas: r.bundleArchiveGas,
  });
}

export function validateScopedPolicyGraphV2SnapshotDependencies(
  recipe: ScopedPolicyGraphV2Recipe,
  graph: ScopedPolicyGraphV2Graph,
  actual: ScopedPolicyGraphV2SnapshotDependencies,
): ScopedPolicyGraphV2SnapshotDependencies {
  const expected = scopedPolicyGraphV2SnapshotDependencies(recipe, graph);
  const a = normalizeScopedPolicyGraphV2SnapshotDependencies(actual);
  if (a.readGas < expected.readGas || a.sourceGas < expected.sourceGas || a.inventoryGas < expected.inventoryGas
    || !equal(SCOPED_POLICY_GRAPH_V2_SNAPSHOT_DEPENDENCIES_TUPLE, expected,
      { ...a, readGas: expected.readGas, sourceGas: expected.sourceGas, inventoryGas: expected.inventoryGas })) {
    throw Error("Snapshot dependency mismatch or gas decrease");
  }
  return a;
}

export function validateScopedPolicyGraphV2ReferenceDependencies(
  recipe: ScopedPolicyGraphV2Recipe,
  graph: ScopedPolicyGraphV2Graph,
  actual: ScopedPolicyGraphV2ReferenceDependencies,
): ScopedPolicyGraphV2ReferenceDependencies {
  const expected = scopedPolicyGraphV2ReferenceDependencies(recipe, graph);
  const a = normalizeScopedPolicyGraphV2ReferenceDependencies(actual);
  if (a.readGas < expected.readGas || a.sourceGas < expected.sourceGas
    || a.snapshotGas < expected.snapshotGas || a.archiveGas < expected.archiveGas
    || !equal(SCOPED_POLICY_GRAPH_V2_REFERENCE_DEPENDENCIES_TUPLE, expected, {
      ...a, readGas: expected.readGas, sourceGas: expected.sourceGas,
      snapshotGas: expected.snapshotGas, archiveGas: expected.archiveGas,
    })) throw Error("Reference dependency mismatch or gas decrease");
  return a;
}

/** Review descriptors for the seven fixed workers, never caller-selected deployment calldata. */
export type ScopedPolicyGraphV2ChildConstructor =
  | { readonly kind: "readiness"; readonly index: 0n; readonly core: Address; readonly router: Address;
      readonly sourceSet: Address; readonly readGas: bigint; readonly sourceGas: bigint }
  | { readonly kind: "checkpoint"; readonly index: 1n; readonly selection: Address; readonly sourceSet: Address;
      readonly readiness: Address; readonly executor: Address; readonly gas: ScopedPolicyGraphV2Recipe["checkpointGas"] }
  | { readonly kind: "output"; readonly index: 2n; readonly core: Address; readonly checkpoint: Address;
      readonly coverage: Address; readonly executor: Address; readonly gas: ScopedPolicyGraphV2GasParameterConfig }
  | { readonly kind: "snapshot"; readonly index: 3n; readonly dependencies: ScopedPolicyGraphV2SnapshotDependencies;
      readonly executor: Address; readonly gas: ScopedPolicyGraphV2Recipe["snapshotGas"] }
  | { readonly kind: "reference"; readonly index: 4n; readonly dependencies: ScopedPolicyGraphV2ReferenceDependencies;
      readonly executor: Address; readonly gas: ScopedPolicyGraphV2Recipe["referenceGas"] }
  | { readonly kind: "inventory"; readonly index: 5n; readonly dependencies: ScopedPolicyGraphV2InventoryDependencies }
  | { readonly kind: "bundle"; readonly index: 6n; readonly dependencies: ScopedPolicyGraphV2BundleDependencies };

export function scopedPolicyGraphV2ChildConstructor(
  recipe: ScopedPolicyGraphV2Recipe,
  graph: ScopedPolicyGraphV2Graph,
  index: bigint,
): ScopedPolicyGraphV2ChildConstructor {
  const r = normalizeScopedPolicyGraphV2Recipe(recipe);
  const g = normalizeScopedPolicyGraphV2Graph(graph);
  switch (uint(index, 8)) {
    case 0n: return Object.freeze({ kind: "readiness", index: 0n, core: r.inventory.targets[0],
      router: r.inventory.targets[4], sourceSet: g.sourceSet, readGas: r.readinessReadGas, sourceGas: r.readinessSourceGas });
    case 1n: return Object.freeze({ kind: "checkpoint", index: 1n, selection: r.targets[1],
      sourceSet: g.sourceSet, readiness: g.children[0], executor: r.targets[3], gas: r.checkpointGas });
    case 2n: return Object.freeze({ kind: "output", index: 2n, core: r.inventory.targets[0],
      checkpoint: g.children[1], coverage: r.inventory.targets[10], executor: r.targets[3], gas: r.outputGas });
    case 3n: return Object.freeze({ kind: "snapshot", index: 3n,
      dependencies: scopedPolicyGraphV2SnapshotDependencies(r, g), executor: r.targets[3], gas: r.snapshotGas });
    case 4n: return Object.freeze({ kind: "reference", index: 4n,
      dependencies: scopedPolicyGraphV2ReferenceDependencies(r, g), executor: r.targets[3], gas: r.referenceGas });
    case 5n: return Object.freeze({ kind: "inventory", index: 5n, dependencies: scopedPolicyGraphV2InventoryDependencies(r, g) });
    case 6n: return Object.freeze({ kind: "bundle", index: 6n, dependencies: scopedPolicyGraphV2BundleDependencies(r, g) });
    default: throw Error("Unknown fixed deployment worker");
  }
}

export function scopedPolicyGraphV2ScopeSubject(
  chainId: bigint,
  core: Address,
  scope: ScopedPolicyGraphV2Scope,
): Hex {
  const s = validateScopedPolicyGraphV2Scope(scope);
  return s.scopeType === 1n
    ? hash(["bytes32", "uint256", "address", "uint256"],
      [id("6529STREAM_SUBJECT_TOKEN_V1"), uint(chainId), address(core, true), s.tokenId])
    : hash(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
      [id("6529STREAM_SUBJECT_SCOPE_V1"), uint(chainId), address(core, true), s.collectionId, s.scopeType, s.scopeId]);
}

export function scopedPolicyGraphV2InventoryPlan(
  dependencies: ScopedPolicyGraphV2SourceDependencies,
  scope: ScopedPolicyGraphV2Scope,
  membership: ScopedPolicyGraphV2Membership,
): Hex {
  const d = normalizeScopedPolicyGraphV2SourceDependencies(dependencies);
  const s = validateScopedPolicyGraphV2Scope(scope);
  const f = normalizeScopedPolicyGraphV2Membership(membership);
  if (f.membershipHash === ZeroHash || f.scopeSubject !== scopedPolicyGraphV2ScopeSubject(d.chainId, d.targets[0], s)) {
    throw Error("Membership subject/hash mismatch");
  }
  return hash(["bytes32", "uint256", "address", "address", "bytes32", "address", "bytes32",
    SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, SCOPED_POLICY_GRAPH_V2_MEMBERSHIP_TUPLE],
  [id("6529STREAM_COORDINATOR_INVENTORY_PLAN_V1"), d.chainId, d.targets[3], d.targets[0], d.codeHashes[0],
    d.targets[2], d.codeHashes[2], s, f]);
}

export function scopedPolicyGraphV2InventoryCommitment(
  plan: Hex,
  progress: ScopedPolicyGraphV2InventoryProgress,
): Hex {
  const p = normalizeScopedPolicyGraphV2InventoryProgress(progress);
  return hash(["bytes32", "bytes32", "uint256", "uint256", "bytes32", "bytes32"],
    [id("6529STREAM_COORDINATOR_INVENTORY_COMPLETE_V1"), bytes(plan, 32), p.tokenCount,
      p.coordinatorCount, p.tokenChain, p.coordinatorChain]);
}

export function scopedPolicyGraphV2CoordinatorChain(
  plan: Hex,
  coordinators: readonly ScopedPolicyGraphV2Coordinator[],
): Hex {
  let result = hash(["bytes32", "bytes32"], [id("6529STREAM_COORDINATOR_SOURCE_CHAIN_V1"), bytes(plan, 32)]);
  list(coordinators, -1, false).forEach((value, i) => {
    result = hash(["bytes32", "bytes32", "uint256", SCOPED_POLICY_GRAPH_V2_COORDINATOR_TUPLE],
      [id("6529STREAM_COORDINATOR_SOURCE_APPEND_V1"), result, BigInt(i),
        normalizeScopedPolicyGraphV2Coordinator(value as ScopedPolicyGraphV2Coordinator)]);
  });
  return result;
}

export function scopedPolicyGraphV2PolicyChain(
  dependencies: ScopedPolicyGraphV2SourceDependencies,
  scope: ScopedPolicyGraphV2Scope,
  plan: Hex,
  inventoryHash: Hex,
  policies: readonly ScopedPolicyGraphV2CoordinatorPolicy[],
): Hex {
  const d = normalizeScopedPolicyGraphV2SourceDependencies(dependencies);
  list(policies, -1, false);
  let result = hash(["bytes32", "uint256", "address[4]", "bytes32[4]", SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE,
    "bytes32", "bytes32", "uint256"], [id("6529STREAM_ORIGINAL_COORDINATOR_POLICIES_V2"), d.chainId,
    d.targets, d.codeHashes, normalizeScopedPolicyGraphV2Scope(scope), bytes(plan, 32), bytes(inventoryHash, 32), BigInt(policies.length)]);
  policies.forEach((value, i) => {
    result = hash(["bytes32", "bytes32", "uint256", SCOPED_POLICY_GRAPH_V2_COORDINATOR_POLICY_TUPLE],
      [id("6529STREAM_ORIGINAL_COORDINATOR_POLICY_APPEND_V2"), result, BigInt(i),
        normalizeScopedPolicyGraphV2CoordinatorPolicy(value)]);
  });
  return result;
}

export function scopedPolicyGraphV2EmptyPolicy(): ScopedPolicyGraphV2Policy {
  return decodeScopedPolicyGraphV2Policy(("0x" + "00".repeat(384)) as Hex);
}

/** Checks original supplied policy fields, never source inventory membership or live module authority. */
export function validateScopedPolicyGraphV2CoordinatorPolicy(
  chainId: bigint,
  core: Address,
  scope: ScopedPolicyGraphV2Scope,
  value: ScopedPolicyGraphV2CoordinatorPolicy,
): ScopedPolicyGraphV2CoordinatorPolicy {
  const p = normalizeScopedPolicyGraphV2CoordinatorPolicy(value);
  const s = validateScopedPolicyGraphV2Scope(scope);
  address(p.coordinator, true); commitment(p.indexedCodeHash);
  commitment(p.moduleVersion); commitment(p.moduleManifestHash);
  commitment(p.moduleSchemaHash); commitment(p.deploymentManifestHash);
  let expected: Hex;
  if (p.explicitPolicy) {
    const policy = p.collectionPolicy;
    if (!policy.configured || !policy.explicitPolicy || !policy.frozen
      || policy.mode > 2n || policy.securityClass > 1n || policy.renderRequirement > 1n
      || policy.revision === 0n || policy.policyHash === ZeroHash || policy.lastActionId === ZeroHash
      || policy.artistConsentRecord === ZeroHash || !p.frozen || p.policyHash !== policy.policyHash
      || p.provider !== ZeroAddress || p.epoch !== 0n || p.salt !== ZeroHash
      || policy.contentStateHash !== hash(["bytes32", "bytes32", "bool"],
        [id("6529STREAM_ENTROPY_CONFIGURATION_V1"), policy.policyHash, policy.frozen])) {
      throw Error("Invalid explicit coordinator policy");
    }
    expected = hash(["bytes32", "uint256", "address", "address", SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE,
      SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE], [id("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V2"), uint(chainId),
      address(core, true), p.coordinator, s, policy]);
  } else {
    commitment(p.policyHash); address(p.provider, true); commitment(p.salt);
    if (p.epoch === 0n || !equal(SCOPED_POLICY_GRAPH_V2_POLICY_TUPLE, p.collectionPolicy,
      scopedPolicyGraphV2EmptyPolicy())) throw Error("Invalid legacy coordinator policy");
    expected = hash(["bytes32", "uint256", "address", "address", SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE,
      "bytes32", "address", "uint32", "bytes32"], [id("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1"),
      uint(chainId), address(core, true), p.coordinator, s, p.policyHash, p.provider, p.epoch, p.salt]);
  }
  if (p.componentDataHash !== expected) throw Error("Coordinator component data hash mismatch");
  return p;
}

/** Complete supplied rows in original coordinator order; RPC provenance remains unverified. */
export function validateScopedPolicyGraphV2PolicyEvidence(
  dependencies: ScopedPolicyGraphV2SourceDependencies,
  scope: ScopedPolicyGraphV2Scope,
  membership: ScopedPolicyGraphV2Membership,
  progress: ScopedPolicyGraphV2InventoryProgress,
  policies: readonly ScopedPolicyGraphV2CoordinatorPolicy[],
): ScopedPolicyGraphV2PolicyEvidence {
  const d = validateScopedPolicyGraphV2SourceDependencies(dependencies.chainId, dependencies);
  const s = validateScopedPolicyGraphV2Scope(scope);
  const f = normalizeScopedPolicyGraphV2Membership(membership);
  const p = normalizeScopedPolicyGraphV2InventoryProgress(progress);
  const planId = scopedPolicyGraphV2InventoryPlan(d, s, f);
  const rows = list(policies, -1, false).map(value => validateScopedPolicyGraphV2CoordinatorPolicy(
    d.chainId, d.targets[0], s, value as ScopedPolicyGraphV2CoordinatorPolicy));
  if (!p.exists || !p.complete || p.processedTokens !== p.tokenCount || p.tokenCount !== f.tokenCount
    || p.coordinatorCount > p.tokenCount || (p.tokenCount !== 0n && p.coordinatorCount === 0n)
    || BigInt(rows.length) !== p.coordinatorCount || p.commitment !== scopedPolicyGraphV2InventoryCommitment(planId, p)) {
    throw Error("Incomplete or mismatched supplied inventory");
  }
  const seen = new Set<string>();
  rows.forEach((row, i) => {
    if (row.firstTokenIndex >= p.tokenCount || (i === 0 ? row.firstTokenIndex !== 0n
      : row.firstTokenIndex <= rows[i - 1]!.firstTokenIndex) || seen.has(row.coordinator)) {
      throw Error("Invalid original coordinator ordering");
    }
    seen.add(row.coordinator);
  });
  const coordinators = rows.map(row => ({ coordinator: row.coordinator,
    indexedCodeHash: row.indexedCodeHash, firstTokenIndex: row.firstTokenIndex }));
  if (scopedPolicyGraphV2CoordinatorChain(planId, coordinators) !== p.coordinatorChain) {
    throw Error("Coordinator chain mismatch");
  }
  return normalizeScopedPolicyGraphV2PolicyEvidence({ planId, inventoryHash: p.commitment,
    policyChainHash: scopedPolicyGraphV2PolicyChain(d, s, planId, p.commitment, rows),
    policyCount: p.coordinatorCount, allFrozen: rows.length > 0 && rows.every(row => row.frozen), policies: rows });
}

export function scopedPolicyGraphV2SourceSetManifestHash(
  dependencies: ScopedPolicyGraphV2SourceDependencies,
  tokenInventory: Address,
  tokenInventoryCodeHash: Hex,
): Hex {
  return hash(["bytes32", SCOPED_POLICY_GRAPH_V2_SOURCE_DEPENDENCIES_TUPLE, "address", "bytes32"],
    [SCOPED_POLICY_GRAPH_V2_SOURCE_SET_PROFILE, normalizeScopedPolicyGraphV2SourceDependencies(dependencies),
      address(tokenInventory), bytes(tokenInventoryCodeHash, 32)]);
}

export function scopedPolicyGraphV2SourceSetDataHash(
  scope: ScopedPolicyGraphV2Scope,
  plan: Hex,
  inventoryHash: Hex,
  policyChainHash: Hex,
  membership: ScopedPolicyGraphV2Membership,
  tokenInventory: Address,
  tokenInventoryCodeHash: Hex,
): Hex {
  return hash(["bytes32", SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE, "bytes32", "bytes32", "bytes32",
    SCOPED_POLICY_GRAPH_V2_MEMBERSHIP_TUPLE, "address", "bytes32"], [SCOPED_POLICY_GRAPH_V2_SOURCE_SET_PROFILE,
    normalizeScopedPolicyGraphV2Scope(scope), bytes(plan, 32), bytes(inventoryHash, 32), bytes(policyChainHash, 32),
      normalizeScopedPolicyGraphV2Membership(membership), address(tokenInventory), bytes(tokenInventoryCodeHash, 32)]);
}

export interface ScopedPolicyGraphV2NativeConfiguration {
  readonly targets: readonly [...Eleven<Address>, ...Eleven<Address>];
  readonly codeHashes: readonly [...Eleven<Hex>, ...Eleven<Hex>];
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly componentSourceGas: bigint;
  readonly inventoryDependencyHash: Hex;
}

export const SCOPED_POLICY_GRAPH_V2_NATIVE_CONFIGURATION_TUPLE = "tuple(address[22] targets,bytes32[22] codeHashes,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 componentSourceGas,bytes32 inventoryDependencyHash)";

export function normalizeScopedPolicyGraphV2NativeConfiguration(
  value: ScopedPolicyGraphV2NativeConfiguration,
): ScopedPolicyGraphV2NativeConfiguration {
  return normalize(SCOPED_POLICY_GRAPH_V2_NATIVE_CONFIGURATION_TUPLE, value);
}

export function encodeScopedPolicyGraphV2NativeConfiguration(value: ScopedPolicyGraphV2NativeConfiguration): Hex {
  return encode(SCOPED_POLICY_GRAPH_V2_NATIVE_CONFIGURATION_TUPLE, value);
}

export function decodeScopedPolicyGraphV2NativeConfiguration(value: Hex): ScopedPolicyGraphV2NativeConfiguration {
  return decode(SCOPED_POLICY_GRAPH_V2_NATIVE_CONFIGURATION_TUPLE, value);
}

/** Original stored commitment: the computed configurationHash field itself is excluded. */
export function scopedPolicyGraphV2ProviderConfigurationHash(
  provider: Address,
  original: ScopedPolicyGraphV2NativeConfiguration,
  binding: ScopedPolicyGraphV2FactoryBinding,
): Hex {
  const c = normalizeScopedPolicyGraphV2NativeConfiguration(original);
  const b = normalizeScopedPolicyGraphV2FactoryBinding(binding);
  return hash(["bytes32", "uint256", "address", SCOPED_POLICY_GRAPH_V2_NATIVE_CONFIGURATION_TUPLE,
    "address", "bytes32", "bytes32", "bytes32", "uint256"],
  [id("6529STREAM_SCOPED_POLICY_PROVIDER_CONFIGURATION_V2"), c.chainId, address(provider), c,
    b.factory, b.factoryCodeHash, b.recipeHash, b.sourceFactoryDependenciesHash, b.graphGas]);
}

/** Supplied stored binding validation; runtime pins, current roots and actual source branch are separate. */
export function validateScopedPolicyGraphV2FactoryBinding(
  coordinates: ScopedPolicyGraphV2Coordinates,
  provider: Address,
  original: ScopedPolicyGraphV2NativeConfiguration,
  recipe: ScopedPolicyGraphV2Recipe,
  sourceDependencies: ScopedPolicyGraphV2SourceDependencies,
  binding: ScopedPolicyGraphV2FactoryBinding,
): ScopedPolicyGraphV2FactoryBinding {
  const c = normalizeScopedPolicyGraphV2Coordinates(coordinates);
  const o = normalizeScopedPolicyGraphV2NativeConfiguration(original);
  const r = validateScopedPolicyGraphV2Recipe(c.chainId, recipe);
  const d = validateScopedPolicyGraphV2SourceDependencies(c.chainId, sourceDependencies);
  const b = normalizeScopedPolicyGraphV2FactoryBinding(binding);
  address(provider, true); commitment(b.factoryCodeHash); commitment(b.configurationHash);
  if (o.chainId !== c.chainId || b.factory !== c.publicationFactory || r.targets[2] !== c.sourceFactory
    || d.targets[0] !== r.inventory.targets[0] || d.codeHashes[0] !== r.inventory.codeHashes[0]
    || d.targets[1] !== r.inventory.targets[1] || d.codeHashes[1] !== r.inventory.codeHashes[1]
    || d.targets[2] !== r.targets[0] || d.codeHashes[2] !== r.codeHashes[0]
    || b.recipeHash !== scopedPolicyGraphV2RecipeHash(c.chainId, r)
    || b.sourceFactoryDependenciesHash !== scopedPolicyGraphV2DependenciesHash(d)
    || b.graphGas < o.readGas || b.graphGas > 0xffffffffn
    || o.componentSourceGas <= b.graphGas + b.graphGas / 63n + o.readGas + 200000n
    || b.configurationHash !== scopedPolicyGraphV2ProviderConfigurationHash(provider, o, b)) {
    throw Error("Stored provider binding mismatch");
  }
  [0, 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21].forEach((index, i) => {
    if (i !== 5 && i !== 6 && (r.inventory.targets[i] !== o.targets[index]
      || r.inventory.codeHashes[i] !== o.codeHashes[index])) throw Error("Provider/recipe inventory mismatch");
  });
  if (r.targets[0] !== o.targets[3] || r.codeHashes[0] !== o.codeHashes[3]
    || r.inventory.artistTargets[0] !== o.targets[11] || r.inventory.artistCodeHashes[0] !== o.codeHashes[11]) {
    throw Error("Provider/recipe fixed target mismatch");
  }
  return b;
}

function ownInterfaceId(iface: Interface, methods: readonly string[]): Hex {
  let value = 0n;
  methods.forEach(method => { value ^= BigInt(iface.getFunction(method)!.selector); });
  return ("0x" + value.toString(16).padStart(8, "0")) as Hex;
}

/** Own declarations only; inherited ERC165/generic source selectors are excluded. */
export const SCOPED_POLICY_GRAPH_V2_SOURCE_FACTORY_INTERFACE_ID = ownInterfaceId(sourceInterface,
  ["scopedPolicyFactoryProfile", "dependencies"]);
export const SCOPED_POLICY_GRAPH_V2_PUBLICATION_FACTORY_INTERFACE_ID = ownInterfaceId(publicationInterface,
  ["scopedPolicyPublicationFactoryProfile", "core", "metadataHost", "entropySourceFactory", "recipeHash",
    "sourceFactoryDependenciesHash", "recipe", "prepareGraph", "graphForPlan", "requireCurrentGraph"]);
export const SCOPED_POLICY_GRAPH_V2_PROVIDER_BINDING_INTERFACE_ID = ownInterfaceId(
  new Interface(SCOPED_POLICY_GRAPH_V2_PROVIDER_BINDING_ABI), ["scopedPolicyPublicationBinding"]);

export type ScopedPolicyGraphV2Request =
  | { readonly kind: "prepareSourceSet"; readonly scope: ScopedPolicyGraphV2Scope }
  | { readonly kind: "prepareGraph"; readonly scope: ScopedPolicyGraphV2Scope; readonly maximumChildren: bigint };

export interface ScopedPolicyGraphV2Call {
  readonly coordinates: ScopedPolicyGraphV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyGraphV2Request;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function prepareScopedPolicyGraphV2Call(
  coordinates: ScopedPolicyGraphV2Coordinates,
  caller: Address,
  request: ScopedPolicyGraphV2Request,
): ScopedPolicyGraphV2Call {
  const c = normalizeScopedPolicyGraphV2Coordinates(coordinates);
  const actor = address(caller, true);
  let normalized: ScopedPolicyGraphV2Request;
  let call: UnsignedCall;
  if (request.kind === "prepareSourceSet") {
    exact(request, ["kind", "scope"], "Prepare source set");
    const scope = validateScopedPolicyGraphV2Scope(request.scope);
    normalized = Object.freeze({ kind: request.kind, scope });
    call = Object.freeze({ to: c.sourceFactory, value: 0n,
      data: sourceInterface.encodeFunctionData(request.kind, [scope]) as Hex });
  } else if (request.kind === "prepareGraph") {
    exact(request, ["kind", "scope", "maximumChildren"], "Prepare graph");
    const scope = validateScopedPolicyGraphV2Scope(request.scope);
    const maximumChildren = uint(request.maximumChildren, 8);
    if (maximumChildren < 1n || maximumChildren > 7n) throw Error("maximumChildren must be 1..7");
    normalized = Object.freeze({ kind: request.kind, scope, maximumChildren });
    call = Object.freeze({ to: c.publicationFactory, value: 0n,
      data: publicationInterface.encodeFunctionData(request.kind, [scope, maximumChildren]) as Hex });
  } else throw Error("Unknown publication preparation method");
  return Object.freeze({ coordinates: c, caller: actor, request: normalized, call, factsVerified: false });
}

export function normalizeScopedPolicyGraphV2Call(value: ScopedPolicyGraphV2Call): ScopedPolicyGraphV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared call");
  const expected = prepareScopedPolicyGraphV2Call(value.coordinates, value.caller, value.request);
  exact(value.call, ["to", "value", "data"], "CALL");
  if (value.factsVerified !== false || address(value.call.to) !== expected.call.to
    || value.call.value !== 0n || bytes(value.call.data) !== expected.call.data) throw Error("Prepared call mismatch");
  return expected;
}

export type ScopedPolicyGraphV2ReadRequest =
  | { readonly host: "sourceFactory"; readonly kind: "supportsInterface"; readonly interfaceId: Hex }
  | { readonly host: "sourceFactory"; readonly kind: "scopedPolicyFactoryProfile" | "dependencies" | "core"
      | "metadataHost" | "scopeMembershipHost" | "coordinatorInventory" }
  | { readonly host: "sourceFactory"; readonly kind: "currentInventoryPlan" | "requireCurrentComponent"
      | "requireCurrentRoute"; readonly scope: ScopedPolicyGraphV2Scope }
  | { readonly host: "sourceFactory"; readonly kind: "sourceSetForPlan"; readonly plan: Hex }
  | { readonly host: "publicationFactory"; readonly kind: "supportsInterface"; readonly interfaceId: Hex }
  | { readonly host: "publicationFactory"; readonly kind: "scopedPolicyPublicationFactoryProfile" | "core"
      | "metadataHost" | "entropySourceFactory" | "recipeHash" | "sourceFactoryDependenciesHash" | "recipe" }
  | { readonly host: "publicationFactory"; readonly kind: "graphForPlan"; readonly plan: Hex }
  | { readonly host: "publicationFactory"; readonly kind: "requireCurrentGraph"; readonly scope: ScopedPolicyGraphV2Scope };

export interface ScopedPolicyGraphV2Read {
  readonly coordinates: ScopedPolicyGraphV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyGraphV2ReadRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function prepareScopedPolicyGraphV2Read(
  coordinates: ScopedPolicyGraphV2Coordinates,
  caller: Address,
  request: ScopedPolicyGraphV2ReadRequest,
): ScopedPolicyGraphV2Read {
  const c = normalizeScopedPolicyGraphV2Coordinates(coordinates);
  if (request.host !== "sourceFactory" && request.host !== "publicationFactory") throw Error("Unknown factory host");
  const iface = request.host === "sourceFactory" ? sourceInterface : publicationInterface;
  const fragment = iface.getFunction(request.kind);
  if (!fragment || (fragment.stateMutability !== "view" && fragment.stateMutability !== "pure")) {
    throw Error("Not an original factory read");
  }
  let normalized: ScopedPolicyGraphV2ReadRequest;
  let args: readonly unknown[];
  if (request.kind === "supportsInterface") {
    exact(request, ["host", "kind", "interfaceId"], "Interface read");
    const interfaceId = bytes(request.interfaceId, 4);
    normalized = Object.freeze({ ...request, interfaceId }); args = [interfaceId];
  } else if ("scope" in request) {
    exact(request, ["host", "kind", "scope"], "Scope read");
    if (!["currentInventoryPlan", "requireCurrentComponent", "requireCurrentRoute", "requireCurrentGraph"].includes(request.kind)) {
      throw Error("Unexpected scope argument");
    }
    const scope = validateScopedPolicyGraphV2Scope(request.scope);
    normalized = Object.freeze({ ...request, scope }); args = [scope];
  } else if ("plan" in request) {
    exact(request, ["host", "kind", "plan"], "Plan read");
    if (request.kind !== "sourceSetForPlan" && request.kind !== "graphForPlan") throw Error("Unexpected plan argument");
    const plan = bytes(request.plan, 32);
    normalized = Object.freeze({ ...request, plan }); args = [plan];
  } else {
    exact(request, ["host", "kind"], "Factory read");
    if (fragment.inputs.length !== 0) throw Error("Missing read argument");
    normalized = Object.freeze({ ...request }); args = [];
  }
  return Object.freeze({ coordinates: c, caller: address(caller), request: normalized, factsVerified: false,
    call: Object.freeze({ to: c[request.host], value: 0n, data: iface.encodeFunctionData(fragment, args) as Hex }) });
}

export function normalizeScopedPolicyGraphV2Read(value: ScopedPolicyGraphV2Read): ScopedPolicyGraphV2Read {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared read");
  const expected = prepareScopedPolicyGraphV2Read(value.coordinates, value.caller, value.request);
  exact(value.call, ["to", "value", "data"], "Read call");
  if (value.factsVerified !== false || address(value.call.to) !== expected.call.to
    || value.call.value !== 0n || bytes(value.call.data) !== expected.call.data) throw Error("Prepared read mismatch");
  return expected;
}
