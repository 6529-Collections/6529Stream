import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";

/** Original ABI146 shared binding. No VIEW finality or deployment admission is inferred. */
export const VIEW_COMPLETE_BINDING_SOURCE = "9381dd999075693a4f63092d9924856a0dd72834";
export const VIEW_COMPLETE_BINDING_PROFILE = id("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_BINDING_V1") as Hex;
export const VIEW_COMPLETE_BINDING_BASIC_PROFILE = id("6529STREAM_FINALITY_VIEW_PRESERVATION_BINDING_V1") as Hex;
export const VIEW_COMPLETE_BINDING_MAX_BYTES = 262144;
export const VIEW_COMPLETE_BINDING_ACTION_CLASS = 2n;
export type ViewCompleteBindingHost = "preservation" | "current-authority-preservation";
export type ViewCompleteBindingArray<T, N extends number, A extends readonly T[] = readonly []> =
  A["length"] extends N ? A : ViewCompleteBindingArray<T, N, readonly [...A, T]>;

export interface ViewCompleteBindingCoordinates {
  readonly chainId: bigint;
  readonly provider: Address;
}
export interface ViewCompleteBindingConfiguration {
  readonly snapshotHost: Address;
  readonly snapshotCodeHash: Hex;
  readonly validationGas: bigint;
  readonly checkpointHost: Address;
  readonly checkpointCodeHash: Hex;
  readonly manifestHost: Address;
  readonly manifestCodeHash: Hex;
}
export interface ViewCompleteBindingDeclaration {
  readonly views: Address;
  readonly viewsCodeHash: Hex;
  readonly membership: Address;
  readonly membershipCodeHash: Hex;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
}
export interface ViewCompleteBindingSnapshotDependencies {
  readonly targets: ViewCompleteBindingArray<Address, 10>;
  readonly codeHashes: ViewCompleteBindingArray<Hex, 10>;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly inventoryGas: bigint;
}
export interface ViewCompleteBindingCapability {
  readonly authority: Address;
  readonly authorityCodeHash: Hex;
  readonly originalHash: Hex;
  readonly capabilityHash: Hex;
}
export interface ViewCompleteBindingBasicReceipt {
  readonly capabilityHash: Hex;
  readonly configuration: ViewCompleteBindingConfiguration;
  readonly declaration: ViewCompleteBindingDeclaration;
  readonly dependencies: ViewCompleteBindingSnapshotDependencies;
  readonly dependenciesHash: Hex;
  readonly workersHash: Hex;
  readonly actionId: Hex;
  readonly boundAt: bigint;
  readonly recordHash: Hex;
}
export interface ViewCompleteBindingSelection {
  readonly referencePublication: Address;
  readonly referencePublicationCodeHash: Hex;
  readonly renderCriticalInventory: Address;
  readonly renderCriticalInventoryCodeHash: Hex;
  readonly bundleArchiveCoverage: Address;
  readonly bundleArchiveCoverageCodeHash: Hex;
}
export interface ViewCompleteBindingReceipt {
  readonly selection: ViewCompleteBindingSelection;
  readonly referenceDependenciesHash: Hex;
  readonly inventoryDependenciesHash: Hex;
  readonly bundleDependenciesHash: Hex;
  readonly basicBindingRecordHash: Hex;
  readonly actionId: Hex;
  readonly boundAt: bigint;
  readonly recordHash: Hex;
}
export interface ViewCompleteBindingTransition {
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
}
export interface ViewCompleteBindingNativeConfiguration {
  readonly targets: ViewCompleteBindingArray<Address, 22>;
  readonly codeHashes: ViewCompleteBindingArray<Hex, 22>;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly componentSourceGas: bigint;
  readonly inventoryDependencyHash: Hex;
}
export interface ViewCompleteBindingFactoryBinding {
  readonly factory: Address;
  readonly factoryCodeHash: Hex;
  readonly recipeHash: Hex;
  readonly sourceFactoryDependenciesHash: Hex;
  readonly graphGas: bigint;
  readonly configurationHash: Hex;
}
export interface ViewCompleteBindingReferenceDependencies {
  readonly targets: ViewCompleteBindingArray<Address, 7>;
  readonly codeHashes: ViewCompleteBindingArray<Hex, 7>;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly snapshotGas: bigint;
  readonly archiveGas: bigint;
}
export interface ViewCompleteBindingInventoryDependencies {
  readonly targets: ViewCompleteBindingArray<Address, 12>;
  readonly codeHashes: ViewCompleteBindingArray<Hex, 12>;
  readonly artistTargets: ViewCompleteBindingArray<Address, 5>;
  readonly artistCodeHashes: ViewCompleteBindingArray<Hex, 5>;
  readonly artistContentOwner: Address;
  readonly artistContentOwnerCodeHash: Hex;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly selectionGas: bigint;
  readonly snapshotGas: bigint;
  readonly referenceGas: bigint;
}
export interface ViewCompleteBindingBundleDependencies {
  readonly targets: ViewCompleteBindingArray<Address, 6>;
  readonly codeHashes: ViewCompleteBindingArray<Hex, 6>;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly archiveGas: bigint;
}
export interface ViewCompleteBindingExpected {
  readonly targets: ViewCompleteBindingArray<Address, 12>;
  readonly codeHashes: ViewCompleteBindingArray<Hex, 12>;
  readonly artistTargets: ViewCompleteBindingArray<Address, 5>;
  readonly artistCodeHashes: ViewCompleteBindingArray<Hex, 5>;
  readonly artistContentOwner: Address;
  readonly artistContentOwnerCodeHash: Hex;
  readonly chainId: bigint;
}
export interface ViewCompleteBindingCandidate {
  readonly configuration: ViewCompleteBindingConfiguration;
  readonly declaration: ViewCompleteBindingDeclaration;
  readonly selection: ViewCompleteBindingSelection;
}

export const VIEW_COMPLETE_BINDING_CONFIGURATION_TUPLE = "tuple(address snapshotHost,bytes32 snapshotCodeHash,uint256 validationGas,address checkpointHost,bytes32 checkpointCodeHash,address manifestHost,bytes32 manifestCodeHash)";
export const VIEW_COMPLETE_BINDING_DECLARATION_TUPLE = "tuple(address views,bytes32 viewsCodeHash,address membership,bytes32 membershipCodeHash,uint32 readGas,uint32 sourceGas)";
export const VIEW_COMPLETE_BINDING_SNAPSHOT_DEPENDENCIES_TUPLE = "tuple(address[10] targets,bytes32[10] codeHashes,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 inventoryGas)";
export const VIEW_COMPLETE_BINDING_CAPABILITY_TUPLE = "tuple(address authority,bytes32 authorityCodeHash,bytes32 originalHash,bytes32 capabilityHash)";
export const VIEW_COMPLETE_BINDING_BASIC_RECEIPT_TUPLE = `tuple(bytes32 capabilityHash,${VIEW_COMPLETE_BINDING_CONFIGURATION_TUPLE} configuration,${VIEW_COMPLETE_BINDING_DECLARATION_TUPLE} declaration,${VIEW_COMPLETE_BINDING_SNAPSHOT_DEPENDENCIES_TUPLE} dependencies,bytes32 dependenciesHash,bytes32 workersHash,bytes32 actionId,uint64 boundAt,bytes32 recordHash)`;
export const VIEW_COMPLETE_BINDING_SELECTION_TUPLE = "tuple(address referencePublication,bytes32 referencePublicationCodeHash,address renderCriticalInventory,bytes32 renderCriticalInventoryCodeHash,address bundleArchiveCoverage,bytes32 bundleArchiveCoverageCodeHash)";
export const VIEW_COMPLETE_BINDING_RECEIPT_TUPLE = `tuple(${VIEW_COMPLETE_BINDING_SELECTION_TUPLE} selection,bytes32 referenceDependenciesHash,bytes32 inventoryDependenciesHash,bytes32 bundleDependenciesHash,bytes32 basicBindingRecordHash,bytes32 actionId,uint64 boundAt,bytes32 recordHash)`;
export const VIEW_COMPLETE_BINDING_TRANSITION_TUPLE = "tuple(bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
export const VIEW_COMPLETE_BINDING_NATIVE_CONFIGURATION_TUPLE = "tuple(address[22] targets,bytes32[22] codeHashes,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 componentSourceGas,bytes32 inventoryDependencyHash)";
export const VIEW_COMPLETE_BINDING_FACTORY_BINDING_TUPLE = "tuple(address factory,bytes32 factoryCodeHash,bytes32 recipeHash,bytes32 sourceFactoryDependenciesHash,uint256 graphGas,bytes32 configurationHash)";
export const VIEW_COMPLETE_BINDING_REFERENCE_DEPENDENCIES_TUPLE = "tuple(address[7] targets,bytes32[7] codeHashes,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 snapshotGas,uint256 archiveGas)";
export const VIEW_COMPLETE_BINDING_INVENTORY_DEPENDENCIES_TUPLE = "tuple(address[12] targets,bytes32[12] codeHashes,address[5] artistTargets,bytes32[5] artistCodeHashes,address artistContentOwner,bytes32 artistContentOwnerCodeHash,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 selectionGas,uint256 snapshotGas,uint256 referenceGas)";
export const VIEW_COMPLETE_BINDING_BUNDLE_DEPENDENCIES_TUPLE = "tuple(address[6] targets,bytes32[6] codeHashes,uint256 chainId,uint256 readGas,uint256 archiveGas)";
export const VIEW_COMPLETE_BINDING_EXPECTED_TUPLE = "tuple(address[12] targets,bytes32[12] codeHashes,address[5] artistTargets,bytes32[5] artistCodeHashes,address artistContentOwner,bytes32 artistContentOwnerCodeHash,uint256 chainId)";

export const VIEW_COMPLETE_BINDING_ABI = Object.freeze([
  "function completeViewPreservationBindingProfile() pure returns (bytes32)",
  `function completeViewPreservationBindingTransition(${VIEW_COMPLETE_BINDING_CONFIGURATION_TUPLE} configuration,${VIEW_COMPLETE_BINDING_DECLARATION_TUPLE} declaration,${VIEW_COMPLETE_BINDING_SELECTION_TUPLE} selection) view returns (${VIEW_COMPLETE_BINDING_TRANSITION_TUPLE})`,
  `function bindCompleteViewPreservation(${VIEW_COMPLETE_BINDING_CONFIGURATION_TUPLE} configuration,${VIEW_COMPLETE_BINDING_DECLARATION_TUPLE} declaration,${VIEW_COMPLETE_BINDING_SELECTION_TUPLE} selection) returns (bytes32 completeRecordHash)`,
  `function viewFinalitySources() view returns (${VIEW_COMPLETE_BINDING_SELECTION_TUPLE})`,
  `function viewFinalitySourcesReceipt() view returns (${VIEW_COMPLETE_BINDING_RECEIPT_TUPLE})`,
  "event ViewPreservationCompleteBound(bytes32 indexed completeRecordHash,bytes32 indexed basicRecordHash,bytes32 indexed actionId,bytes32 fullProposalHash)"
]);
/** Supporting observations do not expose the separate basic mutation. */
export const VIEW_COMPLETE_BINDING_OBSERVATION_ABI = Object.freeze([
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function viewPreservationBindingProfile() pure returns (bytes32)",
  "function viewPreservationBindingStatus() view returns (uint8)",
  `function viewPreservationBindingCapability() view returns (${VIEW_COMPLETE_BINDING_CAPABILITY_TUPLE})`,
  `function viewPreservationBindingReceipt() view returns (${VIEW_COMPLETE_BINDING_BASIC_RECEIPT_TUPLE})`,
  `function nativeConfiguration() view returns (${VIEW_COMPLETE_BINDING_NATIVE_CONFIGURATION_TUPLE})`,
  `function scopedPreservationPolicyPublicationBinding() view returns (${VIEW_COMPLETE_BINDING_FACTORY_BINDING_TUPLE})`,
  "function finalitySourceConfigurationHash() view returns (bytes32)"
]);
const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;
function exact(value: unknown, keys: readonly string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || Reflect.ownKeys(value).length !== keys.length
    || keys.some(key => !Object.prototype.hasOwnProperty.call(value, key))) throw Error("Invalid exact shape");
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
function bytes(value: unknown, length?: number): Hex {
  if (typeof value !== "string" || !isHexString(value, length ?? true)
    || (value.length - 2) / 2 > VIEW_COMPLETE_BINDING_MAX_BYTES) throw Error("Invalid bytes or allocation bound");
  return value.toLowerCase() as Hex;
}
function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === ZERO) throw Error("Zero commitment");
  return result;
}
function list(value: unknown, length: number): readonly unknown[] {
  if (!Array.isArray(value) || value.length !== length || Reflect.ownKeys(value).length !== length + 1
    || Array.from({ length }, (_, i) => i).some(i => !Object.prototype.hasOwnProperty.call(value, i))) {
    throw Error("Invalid exact dense array");
  }
  return value;
}
function valueOf(type: ParamType, value: unknown, decoded: boolean): unknown {
  if (type.baseType === "array") return Object.freeze(list(value, type.arrayLength!).map(v => valueOf(type.arrayChildren!, v, decoded)));
  if (type.baseType === "tuple") {
    if (!decoded) exact(value, type.components!.map(f => f.name));
    return Object.freeze(Object.fromEntries(type.components!.map((f, i) => [f.name,
      valueOf(f, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[f.name], decoded)])));
  }
  if (type.type.startsWith("uint")) return uint(value, Number(type.type.slice(4)));
  if (type.type === "address") return address(value);
  if (type.type.startsWith("bytes")) return bytes(value, Number(type.type.slice(5)));
  throw Error("Unsupported original value type");
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
function equal(a: unknown, b: unknown, label: string): void {
  const stable = (v: unknown): string => JSON.stringify(v, (_, x: unknown) => typeof x === "bigint" ? `${x}n` : x);
  if (stable(a) !== stable(b)) throw Error(label + " differs");
}
function pin(target: Address, codeHash: Hex): void {
  address(target, true);
  nonzero(codeHash);
}

export function viewCompleteBindingInterface(): Interface {
  return new Interface(VIEW_COMPLETE_BINDING_ABI);
}
export function viewCompleteBindingObservationInterface(): Interface {
  return new Interface(VIEW_COMPLETE_BINDING_OBSERVATION_ABI);
}
export function normalizeViewCompleteBindingCoordinates(value: ViewCompleteBindingCoordinates): ViewCompleteBindingCoordinates {
  exact(value, ["chainId", "provider"]);
  const chainId = uint(value.chainId);
  if (!chainId) throw Error("Zero chain");
  return Object.freeze({ chainId, provider: address(value.provider, true) });
}

// Structural codecs intentionally preserve all-zero pending records. Admission is separate.

export function normalizeViewCompleteBindingConfiguration(value: ViewCompleteBindingConfiguration): ViewCompleteBindingConfiguration {
  return normalize(VIEW_COMPLETE_BINDING_CONFIGURATION_TUPLE, value);
}
export function encodeViewCompleteBindingConfiguration(value: ViewCompleteBindingConfiguration): Hex {
  return encode(VIEW_COMPLETE_BINDING_CONFIGURATION_TUPLE, value);
}
export function decodeViewCompleteBindingConfiguration(value: Hex): ViewCompleteBindingConfiguration {
  return decode(VIEW_COMPLETE_BINDING_CONFIGURATION_TUPLE, value);
}

export function normalizeViewCompleteBindingDeclaration(value: ViewCompleteBindingDeclaration): ViewCompleteBindingDeclaration {
  return normalize(VIEW_COMPLETE_BINDING_DECLARATION_TUPLE, value);
}
export function encodeViewCompleteBindingDeclaration(value: ViewCompleteBindingDeclaration): Hex {
  return encode(VIEW_COMPLETE_BINDING_DECLARATION_TUPLE, value);
}
export function decodeViewCompleteBindingDeclaration(value: Hex): ViewCompleteBindingDeclaration {
  return decode(VIEW_COMPLETE_BINDING_DECLARATION_TUPLE, value);
}

export function normalizeViewCompleteBindingSnapshotDependencies(value: ViewCompleteBindingSnapshotDependencies): ViewCompleteBindingSnapshotDependencies {
  return normalize(VIEW_COMPLETE_BINDING_SNAPSHOT_DEPENDENCIES_TUPLE, value);
}
export function encodeViewCompleteBindingSnapshotDependencies(value: ViewCompleteBindingSnapshotDependencies): Hex {
  return encode(VIEW_COMPLETE_BINDING_SNAPSHOT_DEPENDENCIES_TUPLE, value);
}
export function decodeViewCompleteBindingSnapshotDependencies(value: Hex): ViewCompleteBindingSnapshotDependencies {
  return decode(VIEW_COMPLETE_BINDING_SNAPSHOT_DEPENDENCIES_TUPLE, value);
}

export function normalizeViewCompleteBindingCapability(value: ViewCompleteBindingCapability): ViewCompleteBindingCapability {
  return normalize(VIEW_COMPLETE_BINDING_CAPABILITY_TUPLE, value);
}
export function encodeViewCompleteBindingCapability(value: ViewCompleteBindingCapability): Hex {
  return encode(VIEW_COMPLETE_BINDING_CAPABILITY_TUPLE, value);
}
export function decodeViewCompleteBindingCapability(value: Hex): ViewCompleteBindingCapability {
  return decode(VIEW_COMPLETE_BINDING_CAPABILITY_TUPLE, value);
}

export function normalizeViewCompleteBindingBasicReceipt(value: ViewCompleteBindingBasicReceipt): ViewCompleteBindingBasicReceipt {
  return normalize(VIEW_COMPLETE_BINDING_BASIC_RECEIPT_TUPLE, value);
}
export function encodeViewCompleteBindingBasicReceipt(value: ViewCompleteBindingBasicReceipt): Hex {
  return encode(VIEW_COMPLETE_BINDING_BASIC_RECEIPT_TUPLE, value);
}
export function decodeViewCompleteBindingBasicReceipt(value: Hex): ViewCompleteBindingBasicReceipt {
  return decode(VIEW_COMPLETE_BINDING_BASIC_RECEIPT_TUPLE, value);
}

export function normalizeViewCompleteBindingSelection(value: ViewCompleteBindingSelection): ViewCompleteBindingSelection {
  return normalize(VIEW_COMPLETE_BINDING_SELECTION_TUPLE, value);
}
export function encodeViewCompleteBindingSelection(value: ViewCompleteBindingSelection): Hex {
  return encode(VIEW_COMPLETE_BINDING_SELECTION_TUPLE, value);
}
export function decodeViewCompleteBindingSelection(value: Hex): ViewCompleteBindingSelection {
  return decode(VIEW_COMPLETE_BINDING_SELECTION_TUPLE, value);
}

export function normalizeViewCompleteBindingReceipt(value: ViewCompleteBindingReceipt): ViewCompleteBindingReceipt {
  return normalize(VIEW_COMPLETE_BINDING_RECEIPT_TUPLE, value);
}
export function encodeViewCompleteBindingReceipt(value: ViewCompleteBindingReceipt): Hex {
  return encode(VIEW_COMPLETE_BINDING_RECEIPT_TUPLE, value);
}
export function decodeViewCompleteBindingReceipt(value: Hex): ViewCompleteBindingReceipt {
  return decode(VIEW_COMPLETE_BINDING_RECEIPT_TUPLE, value);
}

export function normalizeViewCompleteBindingTransition(value: ViewCompleteBindingTransition): ViewCompleteBindingTransition {
  return normalize(VIEW_COMPLETE_BINDING_TRANSITION_TUPLE, value);
}
export function encodeViewCompleteBindingTransition(value: ViewCompleteBindingTransition): Hex {
  return encode(VIEW_COMPLETE_BINDING_TRANSITION_TUPLE, value);
}
export function decodeViewCompleteBindingTransition(value: Hex): ViewCompleteBindingTransition {
  return decode(VIEW_COMPLETE_BINDING_TRANSITION_TUPLE, value);
}

export function normalizeViewCompleteBindingNativeConfiguration(value: ViewCompleteBindingNativeConfiguration): ViewCompleteBindingNativeConfiguration {
  return normalize(VIEW_COMPLETE_BINDING_NATIVE_CONFIGURATION_TUPLE, value);
}
export function encodeViewCompleteBindingNativeConfiguration(value: ViewCompleteBindingNativeConfiguration): Hex {
  return encode(VIEW_COMPLETE_BINDING_NATIVE_CONFIGURATION_TUPLE, value);
}
export function decodeViewCompleteBindingNativeConfiguration(value: Hex): ViewCompleteBindingNativeConfiguration {
  return decode(VIEW_COMPLETE_BINDING_NATIVE_CONFIGURATION_TUPLE, value);
}

export function normalizeViewCompleteBindingFactoryBinding(value: ViewCompleteBindingFactoryBinding): ViewCompleteBindingFactoryBinding {
  return normalize(VIEW_COMPLETE_BINDING_FACTORY_BINDING_TUPLE, value);
}
export function encodeViewCompleteBindingFactoryBinding(value: ViewCompleteBindingFactoryBinding): Hex {
  return encode(VIEW_COMPLETE_BINDING_FACTORY_BINDING_TUPLE, value);
}
export function decodeViewCompleteBindingFactoryBinding(value: Hex): ViewCompleteBindingFactoryBinding {
  return decode(VIEW_COMPLETE_BINDING_FACTORY_BINDING_TUPLE, value);
}

export function normalizeViewCompleteBindingReferenceDependencies(value: ViewCompleteBindingReferenceDependencies): ViewCompleteBindingReferenceDependencies {
  return normalize(VIEW_COMPLETE_BINDING_REFERENCE_DEPENDENCIES_TUPLE, value);
}
export function encodeViewCompleteBindingReferenceDependencies(value: ViewCompleteBindingReferenceDependencies): Hex {
  return encode(VIEW_COMPLETE_BINDING_REFERENCE_DEPENDENCIES_TUPLE, value);
}
export function decodeViewCompleteBindingReferenceDependencies(value: Hex): ViewCompleteBindingReferenceDependencies {
  return decode(VIEW_COMPLETE_BINDING_REFERENCE_DEPENDENCIES_TUPLE, value);
}

export function normalizeViewCompleteBindingInventoryDependencies(value: ViewCompleteBindingInventoryDependencies): ViewCompleteBindingInventoryDependencies {
  return normalize(VIEW_COMPLETE_BINDING_INVENTORY_DEPENDENCIES_TUPLE, value);
}
export function encodeViewCompleteBindingInventoryDependencies(value: ViewCompleteBindingInventoryDependencies): Hex {
  return encode(VIEW_COMPLETE_BINDING_INVENTORY_DEPENDENCIES_TUPLE, value);
}
export function decodeViewCompleteBindingInventoryDependencies(value: Hex): ViewCompleteBindingInventoryDependencies {
  return decode(VIEW_COMPLETE_BINDING_INVENTORY_DEPENDENCIES_TUPLE, value);
}

export function normalizeViewCompleteBindingBundleDependencies(value: ViewCompleteBindingBundleDependencies): ViewCompleteBindingBundleDependencies {
  return normalize(VIEW_COMPLETE_BINDING_BUNDLE_DEPENDENCIES_TUPLE, value);
}
export function encodeViewCompleteBindingBundleDependencies(value: ViewCompleteBindingBundleDependencies): Hex {
  return encode(VIEW_COMPLETE_BINDING_BUNDLE_DEPENDENCIES_TUPLE, value);
}
export function decodeViewCompleteBindingBundleDependencies(value: Hex): ViewCompleteBindingBundleDependencies {
  return decode(VIEW_COMPLETE_BINDING_BUNDLE_DEPENDENCIES_TUPLE, value);
}

export function normalizeViewCompleteBindingExpected(value: ViewCompleteBindingExpected): ViewCompleteBindingExpected {
  return normalize(VIEW_COMPLETE_BINDING_EXPECTED_TUPLE, value);
}
export function encodeViewCompleteBindingExpected(value: ViewCompleteBindingExpected): Hex {
  return encode(VIEW_COMPLETE_BINDING_EXPECTED_TUPLE, value);
}
export function decodeViewCompleteBindingExpected(value: Hex): ViewCompleteBindingExpected {
  return decode(VIEW_COMPLETE_BINDING_EXPECTED_TUPLE, value);
}

export function normalizeViewCompleteBindingCandidate(value: ViewCompleteBindingCandidate): ViewCompleteBindingCandidate {
  exact(value, ["configuration", "declaration", "selection"]);
  return Object.freeze({ configuration: normalizeViewCompleteBindingConfiguration(value.configuration),
    declaration: normalizeViewCompleteBindingDeclaration(value.declaration), selection: normalizeViewCompleteBindingSelection(value.selection) });
}

/** Original preimages only: neither hashes nor normalized values establish deployment authority. */
export function viewCompleteBindingCapabilityHash(
  inputCoordinates: ViewCompleteBindingCoordinates,
  input: ViewCompleteBindingCapability
): Hex {
  const c = normalizeViewCompleteBindingCoordinates(inputCoordinates), r = normalizeViewCompleteBindingCapability(input);
  return hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32"],
    [VIEW_COMPLETE_BINDING_BASIC_PROFILE, c.chainId, c.provider, r.authority, r.authorityCodeHash, r.originalHash]);
}
export function viewCompleteBindingBasicProposalHash(input: ViewCompleteBindingBasicReceipt): Hex {
  const r = normalizeViewCompleteBindingBasicReceipt(input);
  return hash(["bytes32", "bytes32", VIEW_COMPLETE_BINDING_CONFIGURATION_TUPLE, VIEW_COMPLETE_BINDING_DECLARATION_TUPLE,
    VIEW_COMPLETE_BINDING_SNAPSHOT_DEPENDENCIES_TUPLE, "bytes32", "bytes32"],
  [id("6529STREAM_FINALITY_VIEW_PRESERVATION_PROPOSAL_V1"), r.capabilityHash, r.configuration, r.declaration,
    r.dependencies, r.dependenciesHash, r.workersHash]);
}
export function viewCompleteBindingBasicReceiptHash(input: ViewCompleteBindingBasicReceipt): Hex {
  const r = normalizeViewCompleteBindingBasicReceipt(input);
  return hash(["bytes32", "bytes32", "bytes32", "uint64"],
    [id("6529STREAM_FINALITY_VIEW_PRESERVATION_RECEIPT_V1"), viewCompleteBindingBasicProposalHash(r), r.actionId, r.boundAt]);
}
export function viewCompleteBindingProposalHash(
  inputBasic: ViewCompleteBindingBasicReceipt,
  inputComplete: ViewCompleteBindingReceipt
): Hex {
  const basic = normalizeViewCompleteBindingBasicReceipt(inputBasic), complete = normalizeViewCompleteBindingReceipt(inputComplete);
  return hash(["bytes32", "bytes32", VIEW_COMPLETE_BINDING_SELECTION_TUPLE, "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_PROPOSAL_V1"), viewCompleteBindingBasicProposalHash(basic),
      complete.selection, complete.referenceDependenciesHash, complete.inventoryDependenciesHash, complete.bundleDependenciesHash]);
}
export function viewCompleteBindingReceiptHash(
  inputCoordinates: ViewCompleteBindingCoordinates,
  input: ViewCompleteBindingReceipt
): Hex {
  const c = normalizeViewCompleteBindingCoordinates(inputCoordinates), r = normalizeViewCompleteBindingReceipt(input);
  return hash(["bytes32", "uint256", "address", VIEW_COMPLETE_BINDING_SELECTION_TUPLE,
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"],
  [id("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"), c.chainId, c.provider, r.selection,
    r.referenceDependenciesHash, r.inventoryDependenciesHash, r.bundleDependenciesHash, r.basicBindingRecordHash, r.actionId, r.boundAt]);
}
export function viewCompleteBindingTransition(
  inputCoordinates: ViewCompleteBindingCoordinates,
  inputBasic: ViewCompleteBindingBasicReceipt,
  inputComplete: ViewCompleteBindingReceipt
): ViewCompleteBindingTransition {
  const c = normalizeViewCompleteBindingCoordinates(inputCoordinates), basic = normalizeViewCompleteBindingBasicReceipt(inputBasic);
  const complete = normalizeViewCompleteBindingReceipt(inputComplete);
  return Object.freeze({
    scopeHash: hash(["bytes32", "uint256", "address", "bytes32"], [VIEW_COMPLETE_BINDING_PROFILE, c.chainId, c.provider, basic.capabilityHash]),
    oldValueHash: hash(["bytes32", "bytes32", "bool"], [VIEW_COMPLETE_BINDING_PROFILE, basic.capabilityHash, false]),
    newValueHash: viewCompleteBindingProposalHash(basic, complete)
  });
}
export function viewCompleteBindingWorkersHash(
  targets: ViewCompleteBindingArray<Address, 5>,
  codeHashes: ViewCompleteBindingArray<Hex, 5>
): Hex {
  const a = list(targets, 5).map(v => address(v)), h = list(codeHashes, 5).map(v => bytes(v, 32));
  return hash(["address[5]", "bytes32[5]"], [a, h]);
}
export interface ViewCompleteBindingSourceConfiguration {
  readonly original: ViewCompleteBindingNativeConfiguration;
  readonly scoped: ViewCompleteBindingNativeConfiguration;
  readonly collectionFactory: ViewCompleteBindingFactoryBinding;
  readonly publicationFactory: ViewCompleteBindingFactoryBinding;
}
/** Both hosts share binding preimages; their constructor source commitments use distinct domains. */
export function viewCompleteBindingSourceConfigurationHash(
  host: ViewCompleteBindingHost,
  inputCoordinates: ViewCompleteBindingCoordinates,
  input: ViewCompleteBindingSourceConfiguration
): Hex {
  exact(input, ["original", "scoped", "collectionFactory", "publicationFactory"]);
  const c = normalizeViewCompleteBindingCoordinates(inputCoordinates);
  const domains = {
    preservation: "6529STREAM_FINALITY_PRESERVATION_FACTORY_SOURCE_CONFIGURATION_V1",
    "current-authority-preservation": "6529STREAM_CURRENT_AUTHORITY_PRESERVATION_FACTORY_SOURCE_CONFIGURATION_V1"
  } as const;
  if (!Object.prototype.hasOwnProperty.call(domains, host)) throw Error("Unsupported genuine provider profile");
  return hash(["bytes32", "uint256", "address", VIEW_COMPLETE_BINDING_NATIVE_CONFIGURATION_TUPLE,
    VIEW_COMPLETE_BINDING_NATIVE_CONFIGURATION_TUPLE, VIEW_COMPLETE_BINDING_FACTORY_BINDING_TUPLE, VIEW_COMPLETE_BINDING_FACTORY_BINDING_TUPLE],
  [id(domains[host]), c.chainId, c.provider, normalizeViewCompleteBindingNativeConfiguration(input.original),
    normalizeViewCompleteBindingNativeConfiguration(input.scoped), normalizeViewCompleteBindingFactoryBinding(input.collectionFactory),
    normalizeViewCompleteBindingFactoryBinding(input.publicationFactory)]);
}

/** The source's strict necessary forwarding inequality, not a gas-capacity estimate. */
export function viewCompleteBindingFits(outer: bigint, inner: bigint): boolean {
  uint(outer); uint(inner);
  const required = inner + inner / 63n + 10000n;
  return required < 1n << 256n && outer > required;
}
export function validateViewCompleteBindingCapability(
  inputCoordinates: ViewCompleteBindingCoordinates,
  inputOriginal: ViewCompleteBindingNativeConfiguration,
  inputCapability: ViewCompleteBindingCapability
) {
  const c = normalizeViewCompleteBindingCoordinates(inputCoordinates);
  const original = normalizeViewCompleteBindingNativeConfiguration(inputOriginal), capability = normalizeViewCompleteBindingCapability(inputCapability);
  pin(capability.authority, capability.authorityCodeHash);
  equal(original.chainId, c.chainId, "Original chain");
  equal(capability.originalHash, keccak256(encodeViewCompleteBindingNativeConfiguration(original)), "Original configuration hash");
  equal(nonzero(capability.capabilityHash), viewCompleteBindingCapabilityHash(c, capability), "Capability hash");
  if (original.readGas < 50000n) throw Error("Original read gas too small");
  return Object.freeze({ coordinates: c, original, capability, factsVerified: false as const });
}

/** Supplied fixed basic joins only; genuine declaration, worker and source admission remains on-chain. */
export function validateViewCompleteBindingBasicCandidate(
  inputCoordinates: ViewCompleteBindingCoordinates,
  inputOriginal: ViewCompleteBindingNativeConfiguration,
  inputCapability: ViewCompleteBindingCapability,
  input: ViewCompleteBindingBasicReceipt
): ViewCompleteBindingBasicReceipt {
  const { original, capability } = validateViewCompleteBindingCapability(inputCoordinates, inputOriginal, inputCapability);
  const r = normalizeViewCompleteBindingBasicReceipt(input), c = r.configuration, d = r.dependencies, v = r.declaration;
  equal(r.capabilityHash, capability.capabilityHash, "Basic capability");
  equal([r.actionId, r.boundAt, r.recordHash], [ZERO, 0n, ZERO], "Candidate future receipt fields");
  pin(c.snapshotHost, c.snapshotCodeHash); pin(c.checkpointHost, c.checkpointCodeHash); pin(c.manifestHost, c.manifestCodeHash);
  pin(v.views, v.viewsCodeHash); pin(v.membership, v.membershipCodeHash);
  if (c.validationGas < original.readGas || c.validationGas > 16777216n || v.readGas < 50000n
    || v.readGas > 16777216n || v.sourceGas < v.readGas) throw Error("Binding gas relationships differ");
  equal([v.membership, v.membershipCodeHash], [original.targets[3], original.codeHashes[3]], "Declaration membership");
  equal(d.chainId, original.chainId, "Snapshot chain");
  const maximum = [d.readGas, d.sourceGas, d.inventoryGas].reduce((a, b) => a > b ? a : b);
  if (!viewCompleteBindingFits(c.validationGas, maximum)) throw Error("Snapshot forwarding bound differs");
  d.targets.forEach((target, i) => pin(target, d.codeHashes[i]!));
  for (const [destination, source] of [[0, 0], [1, 1], [2, 4], [3, 5], [4, 2], [5, 3], [8, 20]] as const) {
    equal([d.targets[destination], d.codeHashes[destination]], [original.targets[source], original.codeHashes[source]], "Snapshot original roster");
  }
  equal([d.targets[6], d.codeHashes[6], d.targets[7], d.codeHashes[7], d.targets[9], d.codeHashes[9]],
    [c.checkpointHost, c.checkpointCodeHash, c.manifestHost, c.manifestCodeHash, capability.authority, capability.authorityCodeHash], "Snapshot producer/authority roster");
  equal(r.dependenciesHash, keccak256(encodeViewCompleteBindingSnapshotDependencies(d)), "Snapshot dependencies hash");
  nonzero(r.workersHash);
  return r;
}

/** Original 12-role/5-Artist/Content roster projection; no caller-selected replacement roster. */
export function deriveViewCompleteBindingExpected(
  inputOriginal: ViewCompleteBindingNativeConfiguration,
  inputBasic: ViewCompleteBindingBasicReceipt,
  inputSelection: ViewCompleteBindingSelection,
  inputInventory: ViewCompleteBindingInventoryDependencies
): ViewCompleteBindingExpected {
  const original = normalizeViewCompleteBindingNativeConfiguration(inputOriginal), basic = normalizeViewCompleteBindingBasicReceipt(inputBasic);
  const selection = normalizeViewCompleteBindingSelection(inputSelection), d = normalizeViewCompleteBindingInventoryDependencies(inputInventory);
  equal(d.chainId, original.chainId, "Original inventory chain");
  equal(keccak256(encodeViewCompleteBindingInventoryDependencies(d)), original.inventoryDependencyHash, "Original inventory dependency hash");
  equal([d.artistTargets[0], d.artistCodeHashes[0]], [original.targets[11], original.codeHashes[11]], "Original Artist anchor");
  const indexes = [0, 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21] as const;
  indexes.forEach((source, i) => equal([d.targets[i], d.codeHashes[i]], [original.targets[source], original.codeHashes[source]], "Original inventory roster"));
  const targets = [...d.targets], codeHashes = [...d.codeHashes];
  targets[5] = basic.configuration.snapshotHost; codeHashes[5] = basic.configuration.snapshotCodeHash;
  targets[6] = selection.referencePublication; codeHashes[6] = selection.referencePublicationCodeHash;
  targets[10] = basic.dependencies.targets[8]; codeHashes[10] = basic.dependencies.codeHashes[8];
  return normalize(VIEW_COMPLETE_BINDING_EXPECTED_TUPLE, { targets, codeHashes, artistTargets: d.artistTargets,
    artistCodeHashes: d.artistCodeHashes, artistContentOwner: d.artistContentOwner,
    artistContentOwnerCodeHash: d.artistContentOwnerCodeHash, chainId: d.chainId });
}

/** Exact dependency projections only. Runtime, ERC165, profile and reciprocal getters remain required. */
export function validateViewCompleteBindingProducerDependencies(
  inputExpected: ViewCompleteBindingExpected,
  inputSelection: ViewCompleteBindingSelection,
  inputReference: ViewCompleteBindingReferenceDependencies,
  inputInventory: ViewCompleteBindingInventoryDependencies,
  inputBundle: ViewCompleteBindingBundleDependencies
) {
  const e = normalizeViewCompleteBindingExpected(inputExpected), s = normalizeViewCompleteBindingSelection(inputSelection);
  const r = normalizeViewCompleteBindingReferenceDependencies(inputReference), i = normalizeViewCompleteBindingInventoryDependencies(inputInventory);
  const b = normalizeViewCompleteBindingBundleDependencies(inputBundle);
  if (!e.chainId) throw Error("Zero expected chain");
  e.targets.forEach((target, index) => pin(target, e.codeHashes[index]!));
  e.artistTargets.forEach((target, index) => pin(target, e.artistCodeHashes[index]!));
  pin(e.artistContentOwner, e.artistContentOwnerCodeHash);
  pin(s.renderCriticalInventory, s.renderCriticalInventoryCodeHash); pin(s.bundleArchiveCoverage, s.bundleArchiveCoverageCodeHash);
  equal([s.referencePublication, s.referencePublicationCodeHash], [e.targets[6], e.codeHashes[6]], "Reference selection");
  equal([r.chainId, i.chainId, b.chainId], [e.chainId, e.chainId, e.chainId], "Producer chain");
  if (r.readGas < 50000n || r.sourceGas < r.readGas || r.snapshotGas < r.sourceGas || r.archiveGas < r.readGas
    || i.readGas < 50000n || [i.sourceGas, i.selectionGas, i.snapshotGas, i.referenceGas].some(v => v < i.readGas)
    || b.readGas < 50000n || b.archiveGas < b.readGas) throw Error("Producer gas relationships differ");
  [0, 1, 2, 3, 4, 5, 11].forEach((source, index) => equal([r.targets[index], r.codeHashes[index]], [e.targets[source], e.codeHashes[source]], "Reference roster"));
  equal([i.targets, i.codeHashes, i.artistTargets, i.artistCodeHashes, i.artistContentOwner, i.artistContentOwnerCodeHash],
    [e.targets, e.codeHashes, e.artistTargets, e.artistCodeHashes, e.artistContentOwner, e.artistContentOwnerCodeHash], "Inventory roster");
  equal([b.targets, b.codeHashes], [
    [e.targets[0], e.targets[1], s.renderCriticalInventory, e.targets[10], e.targets[11], e.artistTargets[4]],
    [e.codeHashes[0], e.codeHashes[1], s.renderCriticalInventoryCodeHash, e.codeHashes[10], e.codeHashes[11], e.artistCodeHashes[4]]
  ], "Bundle roster");
  return Object.freeze({ referenceDependenciesHash: keccak256(encodeViewCompleteBindingReferenceDependencies(r)) as Hex,
    inventoryDependenciesHash: keccak256(encodeViewCompleteBindingInventoryDependencies(i)) as Hex,
    bundleDependenciesHash: keccak256(encodeViewCompleteBindingBundleDependencies(b)) as Hex, factsVerified: false as const });
}

/** Local immutable paired receipt integrity; never calls today's authority or selected producers. */
export function authenticateViewCompleteBindingHistory(
  inputCoordinates: ViewCompleteBindingCoordinates,
  inputBasic: ViewCompleteBindingBasicReceipt,
  inputComplete: ViewCompleteBindingReceipt
) {
  const coordinates = normalizeViewCompleteBindingCoordinates(inputCoordinates);
  const basic = normalizeViewCompleteBindingBasicReceipt(inputBasic), complete = normalizeViewCompleteBindingReceipt(inputComplete);
  equal(nonzero(basic.recordHash), viewCompleteBindingBasicReceiptHash(basic), "Basic receipt commitment");
  equal(nonzero(complete.recordHash), viewCompleteBindingReceiptHash(coordinates, complete), "Complete receipt commitment");
  equal(complete.basicBindingRecordHash, basic.recordHash, "Complete basic receipt link");
  equal(nonzero(complete.actionId), basic.actionId, "Complete action link");
  equal(complete.boundAt, basic.boundAt, "Complete time link");
  return Object.freeze({ coordinates, basic, complete, proposalHash: viewCompleteBindingProposalHash(basic, complete),
    currentnessChecked: false as const, transactionAuthenticated: false as const, factsVerified: false as const });
}

export interface ViewCompleteBindingCall {
  readonly coordinates: ViewCompleteBindingCoordinates;
  readonly candidate: ViewCompleteBindingCandidate;
  readonly call: UnsignedCall;
  readonly governanceTargetOnly: true;
  readonly requiredActionClass: 2n;
}
/** Inner original nonpayable target call only. A wallet cannot acquire executing-governor authority. */
export function prepareViewCompleteBindingCall(
  inputCoordinates: ViewCompleteBindingCoordinates,
  inputCandidate: ViewCompleteBindingCandidate
): ViewCompleteBindingCall {
  const coordinates = normalizeViewCompleteBindingCoordinates(inputCoordinates), candidate = normalizeViewCompleteBindingCandidate(inputCandidate);
  const data = bytes(viewCompleteBindingInterface().encodeFunctionData("bindCompleteViewPreservation",
    [candidate.configuration, candidate.declaration, candidate.selection]));
  return Object.freeze({ coordinates, candidate, call: Object.freeze({ to: coordinates.provider, data, value: 0n }),
    governanceTargetOnly: true, requiredActionClass: VIEW_COMPLETE_BINDING_ACTION_CLASS });
}
export function normalizeViewCompleteBindingCall(value: ViewCompleteBindingCall): ViewCompleteBindingCall {
  exact(value, ["coordinates", "candidate", "call", "governanceTargetOnly", "requiredActionClass"]);
  exact(value.call, ["to", "data", "value"]);
  const rebuilt = prepareViewCompleteBindingCall(value.coordinates, value.candidate);
  equal([address(value.call.to), bytes(value.call.data), uint(value.call.value), value.governanceTargetOnly, value.requiredActionClass],
    [rebuilt.call.to, rebuilt.call.data, 0n, true, 2n], "Original governed target call");
  return rebuilt;
}
export type ViewCompleteBindingReadRequest =
  | { readonly kind: "completeViewPreservationBindingProfile" | "viewFinalitySources" | "viewFinalitySourcesReceipt" }
  | { readonly kind: "completeViewPreservationBindingTransition"; readonly candidate: ViewCompleteBindingCandidate };
export interface ViewCompleteBindingReadCall {
  readonly coordinates: ViewCompleteBindingCoordinates;
  readonly request: ViewCompleteBindingReadRequest;
  readonly call: UnsignedCall;
}
export function prepareViewCompleteBindingRead(
  inputCoordinates: ViewCompleteBindingCoordinates,
  request: ViewCompleteBindingReadRequest
): ViewCompleteBindingReadCall {
  const coordinates = normalizeViewCompleteBindingCoordinates(inputCoordinates);
  let normalized: ViewCompleteBindingReadRequest;
  let args: readonly unknown[];
  if (request.kind === "completeViewPreservationBindingTransition") {
    exact(request, ["kind", "candidate"]);
    const candidate = normalizeViewCompleteBindingCandidate(request.candidate);
    normalized = Object.freeze({ kind: request.kind, candidate });
    args = [candidate.configuration, candidate.declaration, candidate.selection];
  } else if (["completeViewPreservationBindingProfile", "viewFinalitySources", "viewFinalitySourcesReceipt"].includes(request.kind)) {
    exact(request, ["kind"]);
    normalized = Object.freeze({ kind: request.kind });
    args = [];
  } else throw Error("Unsupported shared binding read");
  return Object.freeze({ coordinates, request: normalized, call: Object.freeze({ to: coordinates.provider,
    data: bytes(viewCompleteBindingInterface().encodeFunctionData(normalized.kind, args)), value: 0n }) });
}
export function normalizeViewCompleteBindingRead(value: ViewCompleteBindingReadCall): ViewCompleteBindingReadCall {
  exact(value, ["coordinates", "request", "call"]);
  exact(value.call, ["to", "data", "value"]);
  const rebuilt = prepareViewCompleteBindingRead(value.coordinates, value.request);
  equal([address(value.call.to), bytes(value.call.data), uint(value.call.value)], [rebuilt.call.to, rebuilt.call.data, 0n], "Original binding read");
  return rebuilt;
}
