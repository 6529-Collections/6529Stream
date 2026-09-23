import {
  AbiCoder,
  Interface,
  ParamType,
  ZeroAddress,
  ZeroHash,
  getAddress,
  id,
  isHexString,
  keccak256,
  toUtf8Bytes,
  type Provider,
} from "ethers";
import type { Address, Hex } from "../generated/contracts.js";
import {
  ARTIST_HYDRATION_CHECKPOINT_TUPLE,
  ARTIST_HYDRATION_NATIVE_RECEIPT_TUPLE,
  ARTIST_HYDRATION_REPLAY_CELL_TUPLE,
  ARTIST_HYDRATION_SNAPSHOT_TUPLE,
  ARTIST_HYDRATION_SUITE_TUPLE,
  type ArtistHydrationCheckpoint,
  type ArtistHydrationSnapshot,
  type ArtistHydrationSuite,
  type ArtistHydrationSeven,
  type ArtistHydrationOwnerIndex,
} from "../current-artist-authority-hydration.js";
import { requireSafeExecution } from "../safe.js";
import * as rh from "../current-artist-recovered-hydration.js";

export interface ArtistRecoveredHydrationCodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}

/** Original order: owners[7], Registry, Archive, Core, Manager, roles, metadata, resolvers, validator. */
export interface ArtistRecoveredHydrationSuitePins {
  readonly registry: ArtistRecoveredHydrationCodePin;
  readonly coordinator: ArtistRecoveredHydrationCodePin;
  readonly components: readonly ArtistRecoveredHydrationCodePin[];
}

/**
 * Pins must come from reviewed release deployment and link metadata. Supplied runtime
 * hashes are trust inputs, not a proof that arbitrary deployed code implements this source.
 */
export interface ArtistRecoveredHydrationDeployment {
  readonly chainId: bigint;
  readonly source: ArtistRecoveredHydrationSuitePins;
  readonly destination: ArtistRecoveredHydrationSuitePins;
  readonly preparationLibrary: ArtistRecoveredHydrationCodePin;
  readonly preparationDependencies: readonly ArtistRecoveredHydrationCodePin[];
}

export type ArtistRecoveredHydrationReader = Pick<
  Provider,
  "getNetwork" | "getBlock" | "getCode" | "call"
>;

export type ArtistRecoveredHydrationReceiptReader = ArtistRecoveredHydrationReader &
  Pick<Provider, "getTransaction" | "getTransactionReceipt">;

export interface ArtistRecoveredHydrationObservation {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}

export interface ArtistRecoveredHydrationPayloadRow {
  readonly pointer: Address;
  readonly payloadType: Hex;
  readonly payloadHash: Hex;
}

export interface ArtistRecoveredHydrationPayloadCatalog {
  readonly host: Address;
  readonly rows: readonly ArtistRecoveredHydrationPayloadRow[];
}

export type ArtistRecoveredHydrationReceiptOptions =
  | { readonly execution: "direct" }
  | { readonly execution: "safe"; readonly expectedSafeTxHash: Hex };

/** Internal only: public wrappers choose one fixed, source-pinned codec and transport. */
export interface RecoveredHydrationWorkflowProtocol<I, C extends rh.ArtistRecoveredHydrationCall> {
  readonly normalizeInputDraft: (input: I) => I;
  readonly request: (input: I) => rh.ArtistRecoveredHydrationRequest;
  readonly finalizeInput: (input: I, inventory: Hex) => I;
  readonly inputFromCall: (call: C) => I;
  readonly prepareCall: (registry: Address, caller: Address, input: I) => C;
  readonly normalizeCall: (call: C) => C;
  readonly preparationCalldata: (destination: ArtistHydrationSuite, input: I) => Hex;
  readonly normalizePrepared: typeof rh.normalizeArtistRecoveredHydrationPrepared;
  readonly decodeOwnerPayload: typeof rh.decodeArtistRecoveredHydrationOwnerPayload;
  readonly semanticInventory: typeof rh.artistRecoveredHydrationSemanticInventory;
  readonly commitment: typeof rh.artistRecoveredHydrationCommitment;
  readonly ownerAfter: typeof rh.artistRecoveredHydrationOwnerAfter;
  readonly profileEvidence: typeof rh.encodeArtistRecoveredHydrationProfileEvidence;
  readonly freshIdentity?: (input: I) => Readonly<{ revision: bigint; replayCount: bigint }>;
  readonly validateInput?: (input: I, certificate: rh.ArtistRecoveredHydrationPrepared) => void;
  readonly validateSource?: (
    reader: ArtistRecoveredHydrationReader,
    source: ArtistHydrationSuite,
    input: I,
    certificate: rh.ArtistRecoveredHydrationPrepared,
    blockTag: number,
  ) => Promise<void>;
  readonly validateReceipt?: (
    reader: ArtistRecoveredHydrationReader,
    capture: ArtistRecoveredHydrationCapture<C>,
    snapshots: readonly ArtistHydrationSnapshot[],
    blockTag: number,
  ) => Promise<void>;
}

const coder = AbiCoder.defaultAbiCoder();
const MAX_RPC_BYTES = 16_777_216;
const MAX_CALL_BYTES = 2_097_152;
const MAX_RUNTIME_BYTES = 131_072;
const MAX_GAS = 100_000_000n;
const MAX_PAYLOAD_BYTES = 24_575;
const MAX_CATALOG_ROWS = 16_384;
const MAX_LOGS = 65_536;
const DOMAINS = [
  "binding_lifecycle",
  "collaborator_lifecycle",
  "identity_authority",
  "acceptance_lifecycle",
  "attribution_lifecycle",
  "payout_lifecycle",
  "consent_finality",
].map(name => id(`domain:${name}`) as Hex);

const abi = new Interface([
  "function core() view returns(address)",
  "function mintManager() view returns(address)",
  "function operationCoordinator() view returns(address)",
  "function artistRegistry() view returns(address)",
  "function archiveV2() view returns(address)",
  "function deploymentChainId() view returns(uint256)",
  "function domainId() view returns(bytes32)",
  "function configurationHash() view returns(bytes32)",
  `function authorityHydrationSuite() view returns(${ARTIST_HYDRATION_SUITE_TUPLE})`,
  "function supportsInterface(bytes4) view returns(bool)",
  "function gasParameterInfo(bytes32) view returns(uint256,uint256,uint8,uint64)",
  "function getSatellitePointer(bytes32) view returns(address,bytes32,bool,bytes32,bytes4,address,uint8,bytes32,bytes32,uint64)",
  "function importedHistoryBindingCount() view returns(uint256)",
  "function importedHistoryBinding(uint256) view returns(address,uint64,bytes32,bytes32)",
  "function artistHistoryPredecessorBinding(address) view returns(bool,bytes32,uint256)",
  "function artistRegistryCutover() view returns(bool,address,uint64)",
  "function importedLaneVerified(uint8,bytes32) view returns(bool,bytes32,uint64)",
  "function artistHistoryLane(uint8,bytes32) view returns(bytes32,uint64)",
  `function ownerStateSnapshotV2() view returns(${ARTIST_HYDRATION_SNAPSHOT_TUPLE})`,
  `function authorityCheckpoint() view returns(${ARTIST_HYDRATION_CHECKPOINT_TUPLE})`,
  `function authorityReplayAt(uint256) view returns(bytes32,${ARTIST_HYDRATION_REPLAY_CELL_TUPLE})`,
  `function replayCell(bytes32) view returns(${ARTIST_HYDRATION_REPLAY_CELL_TUPLE})`,
  `function importedAuthorityReplayCell(bytes32) view returns(${ARTIST_HYDRATION_REPLAY_CELL_TUPLE})`,
  "function authorityNonceIndexAt(uint256) view returns((uint8 kind,bytes32 key,uint256 prefixCount))",
  "function authorityNonceWordAt(uint8,bytes32,uint256) view returns(uint256,uint256[32],bool)",
  "function authorityHydrationCommitment() view returns(bytes32)",
  "function artistNativeReceiptCount() view returns(uint256)",
  `function artistNativeReceiptAt(uint256) view returns(${ARTIST_HYDRATION_NATIVE_RECEIPT_TUPLE})`,
  "function artistNativeReceiptRevisionAt(uint256) view returns(uint64)",
  `function recoveredAuthorityHydrationCapability() view returns(${rh.ARTIST_RECOVERED_HYDRATION_CAPABILITY_TUPLE})`,
  `function recoveredHydrationImportedPrefix() view returns(${rh.ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE},bytes32,uint64)`,
  `function recoveredHydrationOrigin(bytes32) view returns(${rh.ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE})`,
  `function recoveredHydrationReplayPoint(bytes32) view returns(${rh.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE})`,
  `function recoveredHydrationAuxiliaryPoint(bytes32,bytes32) view returns(${rh.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE})`,
  `function recoveredTimingCheckpoint() view returns(${rh.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE})`,
  `function recoveredTimingEntryAt(uint256) view returns(${rh.ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE})`,
  `function governanceActionFacts(bytes32) view returns(${rh.ARTIST_RECOVERED_HYDRATION_ACTION_FACTS_TUPLE})`,
  "function governanceAuthority() view returns(address)",
  `function finalityRecoveryRecord(bytes32) view returns(${rh.ARTIST_RECOVERED_HYDRATION_FINALITY_RECORD_TUPLE})`,
  "function entropyRecoveryIntentTerminal(bytes32) view returns(bool)",
  `function freshRecoveryReceipt(bytes32) view returns(${rh.ARTIST_RECOVERED_HYDRATION_ENTROPY_RECEIPT_TUPLE})`,
  "function entropyUnavailabilityEvidence(bytes32) view returns(bytes32 findingRecordHash,bytes32 intentHash,uint64 noticeEndsAt)",
  "function artistArchiveMaxEvidenceBytesV2() pure returns(uint256)",
  "function artistEvidenceMetadataV2(bytes32,uint64) view returns(bytes32,address,uint32,uint64)",
  "function artistEvidenceBytesV2(bytes32,uint64) view returns(bytes)",
  "function storedPayloadCount() view returns(uint256)",
  "function storedPayloadAt(uint256) view returns(address,bytes32,bytes32)",
  "event RecoveredArtistAuthorityHydrated(uint16 schemaVersion,address indexed predecessorRegistry,bytes32 indexed commitment,bytes32 indexed semanticInventory,bytes32 evidencePayloadHash)",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId,uint64 indexed evidenceVersion,bytes32 indexed contentHash,address pointer,uint256 payloadSize)",
  "event ArtistStoredPayload(uint16 schemaVersion,uint256 indexed index,bytes32 indexed payloadType,bytes32 indexed payloadHash,address pointer)",
]);

const safeAbi = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);
const indexedSafeAbi = new Interface([
  "event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)",
]);

const preparationAbi = new Interface([
  `function prepare(${ARTIST_HYDRATION_SUITE_TUPLE},${rh.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE}) view returns(${rh.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE})`,
]);
// Both original preparation overloads return this same tuple. Call selectors
// and arguments come only from the fixed public wrapper's compiler-bound adapter.

function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}

function stable(value: unknown): string {
  if (typeof value === "bigint") return `bigint:${value}`;
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map(key =>
      `${key}:${stable((value as Record<string, unknown>)[key])}`).join(",")}}`;
  }
  if (value === undefined) throw Error("Unsupported undefined captured value");
  return JSON.stringify(value);
}

function equal(a: unknown, b: unknown, message: string): void {
  if (stable(a) !== stable(b)) throw Error(message);
}

function freeze<T>(value: T): T {
  if (value && typeof value === "object") {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}

function keys(value: unknown, expected: readonly string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join() !== [...expected].sort().join()) {
    throw Error("Unexpected object fields");
  }
}

function dense(value: unknown, maximum: number): asserts value is unknown[] {
  if (!Array.isArray(value) || value.length > maximum
    || Object.keys(value).join() !== Array.from({ length: value.length }, (_, i) => String(i)).join()) {
    throw Error("Dense bounded array required");
  }
}

function address(value: unknown): Address {
  if (typeof value !== "string") throw Error("Address required");
  const result = getAddress(value);
  if (result === ZeroAddress) throw Error("Nonzero address required");
  return result as Address;
}

function bytes(value: unknown, maximum: number): Hex {
  if (typeof value !== "string" || !isHexString(value, true)
    || (value.length - 2) / 2 > maximum) throw Error("Malformed or excessive bytes");
  return value.toLowerCase() as Hex;
}

function hash(value: unknown, allowZero = false): Hex {
  const result = bytes(value, 32);
  if (result.length !== 66 || (!allowZero && result === ZeroHash)) throw Error("Invalid bytes32");
  return result;
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) {
    throw Error("Unsigned bigint required");
  }
  return value;
}

function blockNumber(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw Error("Concrete block number required");
  }
  return value;
}

function gas(value: unknown): bigint {
  const result = uint(value);
  if (result === 0n || result > MAX_GAS) throw Error("Explicit gas bound required");
  return result;
}

function codePin(value: unknown): ArtistRecoveredHydrationCodePin {
  keys(value, ["address", "codeHash"]);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}

function suitePins(value: unknown): ArtistRecoveredHydrationSuitePins {
  keys(value, ["registry", "coordinator", "components"]);
  dense(value.components, 16);
  if (value.components.length !== 16) throw Error("Sixteen original component pins required");
  const result = {
    registry: codePin(value.registry),
    coordinator: codePin(value.coordinator),
    components: value.components.map(codePin),
  };
  equal(result.registry, result.components[7], "Registry component pin differs");
  if (new Set([...result.components.map(item => item.address), result.coordinator.address]).size !== 17) {
    throw Error("Distinct original suite components required");
  }
  return result;
}

function deployment(input: ArtistRecoveredHydrationDeployment): ArtistRecoveredHydrationDeployment {
  keys(input, ["chainId", "source", "destination", "preparationLibrary", "preparationDependencies"]);
  dense(input.preparationDependencies, 256);
  const result = {
    chainId: uint(input.chainId),
    source: suitePins(input.source),
    destination: suitePins(input.destination),
    preparationLibrary: codePin(input.preparationLibrary),
    preparationDependencies: input.preparationDependencies.map(codePin),
  };
  if (result.chainId === 0n || same(result.source.registry.address, result.destination.registry.address)
    || same(result.source.coordinator.address, result.destination.coordinator.address)) {
    throw Error("Distinct source and destination deployments required");
  }
  for (let i = 9; i < 16; i++) {
    equal(result.source.components[i], result.destination.components[i], "Non-Artist dependencies differ");
  }
  const libraries = [result.preparationLibrary, ...result.preparationDependencies];
  if (new Set(libraries.map(item => item.address)).size !== libraries.length) {
    throw Error("Duplicate preparation library pin");
  }
  return freeze(result);
}

function plain(type: ParamType, value: any): any {
  if (type.baseType === "array") return Array.from(value, item => plain(type.arrayChildren!, item));
  if (type.baseType === "tuple") {
    return Object.fromEntries(type.components!.map((item, i) => [item.name, plain(item, value[i])]));
  }
  return typeof value === "string" && value.startsWith("0x") && type.type !== "address"
    ? value.toLowerCase() : value;
}

async function read(
  reader: ArtistRecoveredHydrationReader,
  target: Address,
  method: string,
  args: readonly unknown[],
  tag: number,
  iface = abi,
): Promise<any[]> {
  const fragment = iface.getFunction(method)!;
  const raw = bytes(await reader.call({
    to: target,
    data: iface.encodeFunctionData(fragment, args),
    blockTag: tag,
  }), MAX_RPC_BYTES);
  const decoded = iface.decodeFunctionResult(fragment, raw);
  if (!same(iface.encodeFunctionResult(fragment, decoded), raw)) {
    throw Error(`Noncanonical ${method} result`);
  }
  return fragment.outputs.map((type, i) => plain(type, decoded[i]));
}

async function header(
  reader: ArtistRecoveredHydrationReader,
  tag: number,
): Promise<ArtistRecoveredHydrationObservation> {
  const block = await reader.getBlock(tag);
  if (!block || block.number !== tag || !Number.isSafeInteger(block.timestamp) || block.timestamp < 0) {
    throw Error("Concrete block unavailable");
  }
  return { blockNumber: tag, blockHash: hash(block.hash), timestamp: BigInt(block.timestamp) };
}

async function unchanged(
  reader: ArtistRecoveredHydrationReader,
  observed: ArtistRecoveredHydrationObservation,
): Promise<void> {
  equal(await header(reader, observed.blockNumber), observed, "Observed block changed");
}

async function runtime(
  reader: ArtistRecoveredHydrationReader,
  pin: ArtistRecoveredHydrationCodePin,
  tag: number,
): Promise<void> {
  const code = bytes(await reader.getCode(pin.address, tag), MAX_RUNTIME_BYTES);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100"))
    || !same(keccak256(code), pin.codeHash)) throw Error("Pinned runtime differs");
}

async function suite(
  reader: ArtistRecoveredHydrationReader,
  pins: ArtistRecoveredHydrationSuitePins,
  chainId: bigint,
  tag: number,
): Promise<ArtistHydrationSuite> {
  for (const pin of [pins.coordinator, ...pins.components]) await runtime(reader, pin, tag);
  const result = (await read(reader, pins.coordinator.address, "authorityHydrationSuite", [], tag))[0] as ArtistHydrationSuite;
  const targets = [
    ...result.owners, result.registry, result.archive, result.core, result.mintManager,
    result.roleRegistry, result.metadata, result.primaryResolver, result.royaltyResolver, result.validator,
  ];
  if (targets.some((target, i) => !same(target, pins.components[i]!.address))) {
    throw Error("Actual suite differs from reviewed pins");
  }
  if ((await read(reader, pins.coordinator.address, "deploymentChainId", [], tag))[0] !== chainId) {
    throw Error("Coordinator deployment chain differs");
  }
  for (const [method, expected] of [
    ["core", result.core], ["mintManager", result.mintManager], ["operationCoordinator", pins.coordinator.address],
  ]) {
    if (!same((await read(reader, result.registry, method!, [], tag))[0], expected)) {
      throw Error("Registry reciprocal binding differs");
    }
  }
  for (const [method, expected] of [
    ["artistRegistry", result.registry], ["operationCoordinator", pins.coordinator.address],
  ]) {
    if (!same((await read(reader, result.archive, method!, [], tag))[0], expected)) {
      throw Error("Archive reciprocal binding differs");
    }
  }
  for (let i = 0; i < 7; i++) {
    for (const [method, expected] of [
      ["core", result.core], ["mintManager", result.mintManager], ["artistRegistry", result.registry],
      ["operationCoordinator", pins.coordinator.address], ["archiveV2", result.archive], ["domainId", DOMAINS[i]],
    ]) {
      if (!same((await read(reader, result.owners[i]!, method!, [], tag))[0], expected)) {
        throw Error("Owner reciprocal binding differs");
      }
    }
    if ((await read(reader, result.owners[i]!, "deploymentChainId", [], tag))[0] !== chainId) {
      throw Error("Owner deployment chain differs");
    }
  }
  return result;
}

async function payloadBytes(
  reader: ArtistRecoveredHydrationReader,
  row: ArtistRecoveredHydrationPayloadRow,
  tag: number,
): Promise<Hex> {
  const code = bytes(await reader.getCode(row.pointer, tag), MAX_PAYLOAD_BYTES + 1);
  if (!code.startsWith("0x00")) throw Error("Original STOP payload carrier required");
  const payload = `0x${code.slice(4)}` as Hex;
  if (!same(keccak256(payload), row.payloadHash)) throw Error("Payload carrier hash differs");
  return payload;
}

async function catalog(
  reader: ArtistRecoveredHydrationReader,
  host: Address,
  tag: number,
  maximum = MAX_CATALOG_ROWS,
): Promise<ArtistRecoveredHydrationPayloadCatalog> {
  const count = uint((await read(reader, host, "storedPayloadCount", [], tag))[0]);
  if (count > BigInt(maximum)) throw Error("Original publication catalog bound exceeded");
  const rows: ArtistRecoveredHydrationPayloadRow[] = [];
  const unique = new Set<string>();
  for (let i = 0n; i < count; i++) {
    const [pointer, type, contentHash] = await read(reader, host, "storedPayloadAt", [i], tag);
    const row = { pointer: address(pointer), payloadType: hash(type), payloadHash: hash(contentHash) };
    const key = `${row.payloadType}:${row.payloadHash}`;
    if (unique.has(key)) throw Error("Duplicate publication content key");
    unique.add(key);
    await payloadBytes(reader, row, tag);
    rows.push(row);
  }
  return { host, rows };
}

async function context(
  reader: ArtistRecoveredHydrationReader,
  pins: ArtistRecoveredHydrationDeployment,
  tag: number,
  liveAdmission: boolean,
) {
  if ((await reader.getNetwork()).chainId !== pins.chainId) throw Error("Wrong chain");
  const observed = await header(reader, tag);
  const source = await suite(reader, pins.source, pins.chainId, tag);
  const destination = await suite(reader, pins.destination, pins.chainId, tag);
  if (!same(source.primaryRevenueClass, destination.primaryRevenueClass)) {
    throw Error("Original primary revenue class differs");
  }
  const configurationHash = hash((await read(
    reader, pins.destination.coordinator.address, "configurationHash", [], tag,
  ))[0]);
  const archiveLimit = uint((await read(
    reader, destination.archive, "artistArchiveMaxEvidenceBytesV2", [], tag,
  ))[0]);
  if (archiveLimit < 20_480n || archiveLimit > BigInt(MAX_PAYLOAD_BYTES)) {
    throw Error("Unsupported original paged Archive capacity");
  }
  if (liveAdmission) {
    const gasInfo = await read(reader, destination.registry, "gasParameterInfo", [
      id("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS"),
    ], tag);
    if (gasInfo[0] === 0n || gasInfo[0] === (1n << 256n) - 1n
      || gasInfo[2] !== 2n || gasInfo[3] === 0n) {
      throw Error("Invalid original history read gas profile");
    }
    const pointer = await read(reader, destination.core, "getSatellitePointer", [id("ARTIST_REGISTRY")], tag);
    if (!same(pointer[0], destination.registry)
      || !same(pointer[1], pins.destination.registry.codeHash) || pointer[9] === 0n) {
      throw Error("Destination Registry is not currently selected");
    }
    if ((await read(reader, destination.owners[2]!, "artistRegistryCutover", [], tag))[0]) {
      throw Error("Destination Registry already cut over");
    }
    if ((await read(reader, destination.owners[2]!, "importedHistoryBindingCount", [], tag))[0] !== 1n) {
      throw Error("Exactly one original operation55 binding required");
    }
    const binding = await read(reader, destination.owners[2]!, "importedHistoryBinding", [0n], tag);
    const predecessor = await read(reader, destination.owners[2]!, "artistHistoryPredecessorBinding", [source.registry], tag);
    if (!same(binding[0], source.registry) || predecessor[0] !== true
      || !same(predecessor[1], pins.source.registry.codeHash)) {
      throw Error("Original predecessor binding differs");
    }
    const cutover = await read(reader, source.registry, "artistRegistryCutover", [], tag);
    if (cutover[0] !== true || !same(cutover[1], destination.registry) || cutover[2] === 0n) {
      throw Error("Source operation57 does not name this destination");
    }
    for (const library of [pins.preparationLibrary, ...pins.preparationDependencies]) {
      await runtime(reader, library, tag);
    }
  }
  return { observed, source, destination, configurationHash, archiveLimit };
}

async function freshDestination(
  reader: ArtistRecoveredHydrationReader,
  destination: ArtistHydrationSuite,
  tag: number,
  identity: Readonly<{ revision: bigint; replayCount: bigint }> = { revision: 3n, replayCount: 6n },
): Promise<readonly ArtistHydrationSnapshot[]> {
  const before: ArtistHydrationSnapshot[] = [];
  for (let i = 0; i < 7; i++) {
    const owner = destination.owners[i]!;
    const snapshot = (await read(reader, owner, "ownerStateSnapshotV2", [], tag))[0] as ArtistHydrationSnapshot;
    const checkpoint = (await read(reader, owner, "authorityCheckpoint", [], tag))[0] as ArtistHydrationCheckpoint;
    if (snapshot.domainId !== DOMAINS[i] || snapshot.revision !== (i === 2 ? identity.revision : 0n)
      || checkpoint.schema !== id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1")
      || checkpoint.replayCount !== (i === 2 ? identity.replayCount : 0n) || checkpoint.nonceIndexCount !== 0n
      || (await read(reader, owner, "artistNativeReceiptCount", [], tag))[0] !== 0n
      || (await read(reader, owner, "authorityHydrationCommitment", [], tag))[0] !== ZeroHash) {
      throw Error("Destination is not the original fresh seven-owner profile");
    }
    equal(checkpoint.ownerState, snapshot, "Destination checkpoint snapshot differs");
    hash(snapshot.stateRoot);
    hash(snapshot.recordChainTip);
    before.push(snapshot);
  }
  return before;
}

async function lane(
  reader: ArtistRecoveredHydrationReader,
  destination: ArtistHydrationSuite,
  source: ArtistHydrationSuite,
  kind: bigint,
  key: Hex,
  expectedCount: bigint,
  tag: number,
) {
  const imported = await read(reader, destination.owners[2]!, "importedLaneVerified", [kind, key], tag);
  const original = await read(reader, source.registry, "artistHistoryLane", [kind, key], tag);
  if (imported[0] !== true || original[1] === 0n || original[1] !== expectedCount
    || imported[2] !== original[1] || !same(imported[1], original[0])) {
    throw Error("Complete original operation56 lane proof required");
  }
  return { kind, key, tip: hash(original[0]), count: uint(original[1], 64) };
}

function destinationOrigin(
  pins: ArtistRecoveredHydrationDeployment,
  selected: ArtistHydrationSuite,
): rh.ArtistRecoveredHydrationOriginEnvironment {
  return {
    chainId: pins.chainId,
    registry: selected.registry,
    coordinator: pins.destination.coordinator.address,
    archive: selected.archive,
    owners: selected.owners,
    ownerCodeHashes: pins.destination.components.slice(0, 7).map(pin => pin.codeHash) as unknown as ArtistHydrationSeven<Hex>,
    core: selected.core,
    manager: selected.mintManager,
    suiteConfigurationHash: keccak256(coder.encode([ARTIST_HYDRATION_SUITE_TUPLE], [selected])) as Hex,
  };
}

function replayKey(
  origin: rh.ArtistRecoveredHydrationOriginEnvironment,
  owner: number,
  surface: Hex,
  scope: Hex,
): Hex {
  return keccak256(coder.encode([
    "bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32",
  ], [
    id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), origin.chainId, origin.registry,
    origin.coordinator, origin.archive, origin.owners[owner], DOMAINS[owner], surface, scope,
  ])) as Hex;
}

function historicalSurface(owner: number, surface: Hex): boolean {
  return owner === 2 && [
    "one_way_cutover_latch", "verified_lane_key", "import_binding",
  ].some(name => same(surface, id(`identity_authority.replay.${name}`)));
}

function priorPrefix(
  provenance: rh.ArtistRecoveredHydrationProvenance,
  owner: number,
): rh.ArtistRecoveredHydrationOwnerProvenance {
  const last = provenance.eras.length - 1;
  const current = provenance.eras[last]!.originHash;
  return {
    origins: provenance.origins.slice(0, last),
    eras: provenance.eras.slice(0, last).map(era => ({
      originHash: era.originHash,
      checkpoint: era.checkpoints[owner]!,
      nativeCount: era.nativeCounts[owner]!,
      lowerRevision: era.lowerRevisions[owner]!,
      priorImportCommitment: era.priorImportCommitment,
    })),
    journal: provenance.journals[owner]!.filter(entry => entry.position.point.environmentHash !== current),
    aliases: provenance.aliases[owner]!.filter(alias => alias.originHash !== current),
  };
}

async function originBindings(
  reader: ArtistRecoveredHydrationReader,
  origin: rh.ArtistRecoveredHydrationOriginEnvironment,
  tag: number,
): Promise<void> {
  const selected = (await read(reader, origin.coordinator, "authorityHydrationSuite", [], tag))[0] as ArtistHydrationSuite;
  if (!same(keccak256(coder.encode([ARTIST_HYDRATION_SUITE_TUPLE], [selected])), origin.suiteConfigurationHash)
    || !same(selected.registry, origin.registry) || !same(selected.archive, origin.archive)
    || !same(selected.core, origin.core) || !same(selected.mintManager, origin.manager)) {
    throw Error("Original era suite differs");
  }
  equal(selected.owners, origin.owners, "Original era owners differ");
  for (let i = 0; i < 7; i++) {
    const owner = origin.owners[i]!;
    await runtime(reader, { address: owner, codeHash: origin.ownerCodeHashes[i]! }, tag);
    for (const [method, expected] of [
      ["artistRegistry", origin.registry], ["operationCoordinator", origin.coordinator],
      ["archiveV2", origin.archive], ["core", origin.core], ["mintManager", origin.manager],
      ["domainId", DOMAINS[i]],
    ]) {
      if (!same((await read(reader, owner, method!, [], tag))[0], expected)) {
        throw Error("Original era reciprocal binding differs");
      }
    }
    if ((await read(reader, owner, "deploymentChainId", [], tag))[0] !== origin.chainId) {
      throw Error("Original era chain differs");
    }
  }
}

async function externalGuards(
  reader: ArtistRecoveredHydrationReader,
  snapshot: rh.ArtistRecoveredHydrationExternalGuards,
  tag: number,
): Promise<void> {
  for (const entry of snapshot.actions) {
    await runtime(reader, { address: entry.witness.executor, codeHash: entry.witness.executorCodeHash }, tag);
    const [facts] = await read(reader, entry.witness.executor, "governanceActionFacts", [entry.witness.actionId], tag);
    equal(facts, entry.facts, "Original external action state differs");
    if (facts.status === 0n || facts.actionClass !== 2n || !same(facts.callHash, entry.witness.callsHash)
      || facts.notBefore !== entry.witness.notBefore || facts.expiresAfter !== entry.witness.expiresAfter) {
      throw Error("Original external action witness differs");
    }
  }
  for (const entry of snapshot.finality) {
    const target = entry.target.recoveryRegistry;
    await runtime(reader, { address: target, codeHash: entry.registryCodeHash }, tag);
    await runtime(reader, { address: entry.executor, codeHash: entry.executorCodeHash }, tag);
    if (!same((await read(reader, target, "core", [], tag))[0], entry.core)
      || !same((await read(reader, target, "governanceAuthority", [], tag))[0], entry.executor)) {
      throw Error("Original external finality binding differs");
    }
    const [action] = await read(reader, entry.executor, "governanceActionFacts", [entry.target.recoveryActionId], tag);
    const [record] = await read(reader, target, "finalityRecoveryRecord", [entry.target.recoveryActionId], tag);
    equal(action, entry.action, "Original finality action differs");
    equal(record, entry.record, "Original finality recovery record differs");
    if (action.actionClass !== 2n || entry.actionTerminal !== [2n, 3n, 4n, 5n].includes(action.status)) {
      throw Error("Original finality terminal observation differs");
    }
  }
  for (const entry of snapshot.entropy) {
    await runtime(reader, { address: entry.coordinator, codeHash: entry.coordinatorCodeHash }, tag);
    if (!same((await read(reader, entry.coordinator, "core", [], tag))[0], entry.core)) {
      throw Error("Original entropy recovery Core differs");
    }
    equal((await read(reader, entry.coordinator, "entropyRecoveryIntentTerminal", [entry.oldRequestKey], tag))[0],
      entry.terminal, "Original entropy terminal observation differs");
    equal((await read(reader, entry.coordinator, "freshRecoveryReceipt", [entry.newRequestKey], tag))[0],
      entry.receipt, "Original entropy recovery receipt differs");
    equal(await read(reader, entry.coordinator, "entropyUnavailabilityEvidence", [entry.newRequestKey], tag),
      [entry.evidence.findingRecordHash, entry.evidence.intentHash, entry.evidence.noticeEndsAt],
      "Original entropy recovery evidence differs");
  }
}

async function timingInventory(
  reader: ArtistRecoveredHydrationReader,
  owner: Address,
  expected: rh.ArtistRecoveredHydrationTimingCheckpoint,
  tag: number,
): Promise<readonly rh.ArtistRecoveredHydrationTimingEntry[]> {
  equal((await read(reader, owner, "recoveredTimingCheckpoint", [], tag))[0], expected,
    "Original timing checkpoint differs");
  if (expected.count > 1024n) throw Error("Original timing inventory bound exceeded");
  const entries: rh.ArtistRecoveredHydrationTimingEntry[] = [];
  let previous = ZeroHash as Hex;
  for (let i = 0n; i < expected.count; i++) {
    const [entry] = await read(reader, owner, "recoveredTimingEntryAt", [i], tag);
    const commitment = keccak256(coder.encode([
      "bytes32", "uint16", rh.ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE,
    ], [expected.schema, expected.version, { ...entry, commitment: ZeroHash }]));
    if (entry.index !== i || !same(entry.previousCommitment, previous)
      || !same(entry.commitment, commitment)) throw Error("Original timing entry chain differs");
    previous = hash(entry.commitment);
    entries.push(entry);
  }
  if (!same(previous, expected.root)) throw Error("Original timing root differs");
  return entries;
}

export interface ArtistRecoveredHydrationOwnerObservation {
  readonly ownerIndex: bigint;
  readonly sourceCapability: rh.ArtistRecoveredHydrationCapability;
  readonly destinationCapability: rh.ArtistRecoveredHydrationCapability;
  readonly payload: rh.ArtistRecoveredHydrationOwnerPayload;
  readonly historicalCells: readonly rh.ArtistRecoveredHydrationHistoricalCell[];
}

async function sourceInventories<I, C extends rh.ArtistRecoveredHydrationCall>(
  protocol: RecoveredHydrationWorkflowProtocol<I, C>,
  reader: ArtistRecoveredHydrationReader,
  pins: ArtistRecoveredHydrationDeployment,
  destination: ArtistHydrationSuite,
  request: rh.ArtistRecoveredHydrationRequest,
  certificate: rh.ArtistRecoveredHydrationPrepared,
  tag: number,
): Promise<readonly ArtistRecoveredHydrationOwnerObservation[]> {
  const provenance = certificate.admission.provenance;
  const last = provenance.eras.length - 1;
  const era = provenance.eras[last]!;
  const source = provenance.origins[last]!;
  const next = destinationOrigin(pins, destination);
  for (const origin of provenance.origins) await originBindings(reader, origin, tag);
  const observations: ArtistRecoveredHydrationOwnerObservation[] = [];
  let requiredFeatures: bigint | null = null;
  for (let i = 0; i < 7; i++) {
    const host = source.owners[i]!;
    const { header: exportHeader, payload } = protocol.decodeOwnerPayload(certificate.data[i]!.typedState, i as ArtistHydrationOwnerIndex);
    if (requiredFeatures !== null && exportHeader.requiredFeatures !== requiredFeatures) {
      throw Error("Seven owners must carry one complete feature requirement");
    }
    requiredFeatures = exportHeader.requiredFeatures;
    const [sourceCapability] = await read(reader, host, "recoveredAuthorityHydrationCapability", [], tag);
    const [destinationCapability] = await read(reader, destination.owners[i]!, "recoveredAuthorityHydrationCapability", [], tag);
    equal(sourceCapability, request.expectedCapabilities[i], "Expected source capability differs");
    for (const capability of [sourceCapability, destinationCapability]) {
      if (capability.profile !== rh.ARTIST_RECOVERED_HYDRATION_PROFILE || capability.version !== 1n
        || capability.ownerIndex !== BigInt(i) || capability.ownerDomain !== DOMAINS[i]
        || capability.checkpointSchema !== rh.ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA
        || capability.stateSchema !== id(`6529STREAM_ARTIST_RECOVERED_${[
          "BINDING", "COLLABORATOR", "IDENTITY", "ACCEPTANCE", "ATTRIBUTION", "PAYOUT", "CONSENT",
        ][i]}_STATE_V1`)
        || (capability.supportedFeatures & exportHeader.requiredFeatures) !== exportHeader.requiredFeatures) {
        throw Error("Original fixed-owner capability does not admit the complete features");
      }
    }
    const [prefix, importCommitment, importedAt] = await read(reader, host, "recoveredHydrationImportedPrefix", [], tag);
    equal(prefix, priorPrefix(provenance, i), "Source imported prefix differs");
    if (!same(importCommitment, era.priorImportCommitment)
      || importedAt !== era.lowerRevisions[i]
      || !same((await read(reader, host, "authorityHydrationCommitment", [], tag))[0], importCommitment)) {
      throw Error("Source imported commitment or local revision differs");
    }
    equal((await read(reader, host, "authorityCheckpoint", [], tag))[0], era.checkpoints[i], "Source checkpoint differs");
    if ((await read(reader, host, "artistNativeReceiptCount", [], tag))[0] !== era.nativeCounts[i]) {
      throw Error("Complete source native count differs");
    }
    for (const entry of provenance.journals[i]!) {
      if (entry.position.point.environmentHash !== era.originHash) continue;
      equal((await read(reader, host, "artistNativeReceiptAt", [entry.position.nativeIndex], tag))[0],
        entry.receipt, "Original native occurrence differs");
      if ((await read(reader, host, "artistNativeReceiptRevisionAt", [entry.position.nativeIndex], tag))[0]
        !== entry.position.point.ownerRevision) throw Error("Original native chronology differs");
    }
    const data = certificate.data[i]!;
    if (data.nonces.length !== 0) throw Error("Recovered nonce trees belong inside the owner payload");
    const historicalCells: rh.ArtistRecoveredHydrationHistoricalCell[] = [];
    for (let j = 0; j < data.origins.length; j++) {
      const logical = data.origins[j]!;
      const key = replayKey(source, i, logical.surface, logical.scope);
      const [actualKey, cell] = await read(reader, host, "authorityReplayAt", [BigInt(j)], tag);
      if (!same(key, actualKey) || !same(key, data.sourceKeys[j])) throw Error("Source replay insertion order differs");
      equal(cell, data.cells[j], "Source replay cell differs");
      equal((await read(reader, host, "replayCell", [key], tag))[0], cell, "Source live replay cell differs");
      const alias = provenance.aliases[i]!.find(item => item.originalKey === key);
      if (!alias) throw Error("Source replay alias missing");
      equal((await read(reader, host, "recoveredHydrationReplayPoint", [key], tag))[0],
        alias.admittedAt, "Source replay original mutation point differs");
      if (historicalSurface(i, logical.surface)) {
        const [current] = await read(reader, destination.owners[i]!, "replayCell", [
          replayKey(next, i, logical.surface, logical.scope),
        ], tag);
        if (logical.surface === id("identity_authority.replay.one_way_cutover_latch")) {
          if (logical.scope !== ZeroHash || current.status !== 0n) throw Error("Destination cutover latch is not unused");
        } else if (current.commitment === ZeroHash || current.kind !== 1n || current.status !== 2n) {
          throw Error("Actual destination history admission cell missing");
        }
        historicalCells.push({ sourceKey: key, cell: current });
      }
    }
    for (let j = 0; j < payload.nonces.length; j++) {
      const nonce = payload.nonces[j]!;
      equal((await read(reader, host, "authorityNonceIndexAt", [BigInt(j)], tag))[0], nonce.index,
        "Complete original nonce index differs");
      for (let k = 0; k < nonce.words.length; k++) {
        const word = nonce.words[k]!;
        equal(await read(reader, host, "authorityNonceWordAt", [nonce.index.kind, nonce.index.key, BigInt(k)], tag),
          [word.prefix, word.words, word.exhausted], "Original nonce prefix or exhaustion differs");
      }
    }
    if ([2, 4, 6].includes(i)) {
      const publications = await catalog(reader, host, tag);
      equal(publications.rows, payload.publications, "Complete source publication catalog differs");
    } else if (payload.publications.length !== 0) {
      throw Error("This owner has no original publication catalog transport");
    }
    observations.push({ ownerIndex: BigInt(i), sourceCapability, destinationCapability, payload, historicalCells });
  }
  return observations;
}

export interface ArtistRecoveredHydrationCapture<C extends rh.ArtistRecoveredHydrationCall = rh.ArtistRecoveredHydrationCall> {
  readonly deployment: ArtistRecoveredHydrationDeployment;
  readonly observed: ArtistRecoveredHydrationObservation;
  readonly prepared: C;
  readonly certificate: rh.ArtistRecoveredHydrationPrepared;
  readonly sourceSuite: ArtistHydrationSuite;
  readonly destinationSuite: ArtistHydrationSuite;
  readonly configurationHash: Hex;
  readonly archiveLimit: bigint;
  readonly preparationGasLimit: bigint;
  readonly owners: readonly ArtistRecoveredHydrationOwnerObservation[];
  readonly timingEntries: readonly rh.ArtistRecoveredHydrationTimingEntry[];
  readonly destinationCatalogs: readonly ArtistRecoveredHydrationPayloadCatalog[];
  readonly after: readonly ArtistHydrationSnapshot[];
  readonly commitment: Hex;
  readonly profileEvidence: Hex;
  readonly descriptor: rh.ArtistRecoveredHydrationEvidenceDescriptor;
  readonly evidenceId: Hex;
  readonly operationEvidence: Hex;
  readonly registrySimulated: false;
  readonly captureHash: Hex;
}

function coordinates(pins: ArtistRecoveredHydrationDeployment): rh.ArtistRecoveredHydrationCoordinates {
  return {
    chainId: pins.chainId,
    registry: pins.destination.registry.address,
    coordinator: pins.destination.coordinator.address,
  };
}

async function collectCertificate<I, C extends rh.ArtistRecoveredHydrationCall>(
  protocol: RecoveredHydrationWorkflowProtocol<I, C>,
  reader: ArtistRecoveredHydrationReader,
  pins: ArtistRecoveredHydrationDeployment,
  destination: ArtistHydrationSuite,
  input: I,
  caller: Address,
  tag: number,
  gasLimit: bigint,
): Promise<rh.ArtistRecoveredHydrationPrepared> {
  const data = bytes(protocol.preparationCalldata(destination, input), MAX_CALL_BYTES);
  const raw = bytes(await reader.call({
    to: pins.preparationLibrary.address,
    from: caller,
    data,
    value: 0n,
    gasLimit,
    blockTag: tag,
  }), MAX_RPC_BYTES);
  const decoded = preparationAbi.decodeFunctionResult("prepare", raw);
  if (!same(preparationAbi.encodeFunctionResult("prepare", decoded), raw)) {
    throw Error("Noncanonical original preparation certificate");
  }
  return protocol.normalizePrepared(plain(preparationAbi.getFunction("prepare")!.outputs[0]!, decoded[0]));
}

function captureHash(value: Omit<ArtistRecoveredHydrationCapture, "captureHash">): Hex {
  return keccak256(toUtf8Bytes(stable(value))) as Hex;
}

function captured<I, C extends rh.ArtistRecoveredHydrationCall>(
  protocol: RecoveredHydrationWorkflowProtocol<I, C>,
  input: ArtistRecoveredHydrationCapture<C>,
): ArtistRecoveredHydrationCapture<C> {
  keys(input, [
    "deployment", "observed", "prepared", "certificate", "sourceSuite", "destinationSuite",
    "configurationHash", "archiveLimit", "preparationGasLimit", "owners", "timingEntries",
    "destinationCatalogs", "after", "commitment", "profileEvidence", "descriptor", "evidenceId",
    "operationEvidence", "registrySimulated", "captureHash",
  ]);
  const copied = structuredClone(input);
  const { captureHash: expected, ...body } = copied;
  if (!same(captureHash(body), expected)) throw Error("Captured recovered certificate was changed");
  deployment(copied.deployment);
  protocol.normalizeCall(copied.prepared);
  protocol.normalizePrepared(copied.certificate);
  protocol.validateInput?.(protocol.inputFromCall(copied.prepared), copied.certificate);
  blockNumber(copied.observed.blockNumber);
  gas(copied.preparationGasLimit);
  return freeze(copied);
}

function reviewedFacts(capture: ArtistRecoveredHydrationCapture): unknown {
  const { observed: _observed, preparationGasLimit: _gas, captureHash: _hash, ...body } = capture;
  return body;
}

/** Collects the full original source certificate. It does not execute a Registry mutation. */
async function captureArtistRecoveredHydration<I, C extends rh.ArtistRecoveredHydrationCall>(
  protocol: RecoveredHydrationWorkflowProtocol<I, C>,
  reader: ArtistRecoveredHydrationReader,
  inputDeployment: ArtistRecoveredHydrationDeployment,
  inputCaller: Address,
  inputRequest: I,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<ArtistRecoveredHydrationCapture<C>> {
  const pins = deployment(inputDeployment);
  const caller = address(inputCaller);
  const input = protocol.normalizeInputDraft(inputRequest);
  const request = protocol.request(input);
  const tag = blockNumber(options.blockTag);
  const gasLimit = gas(options.gasLimit);
  const ctx = await context(reader, pins, tag, true);
  const before = await freshDestination(reader, ctx.destination, tag, protocol.freshIdentity?.(input));
  const certificate = await collectCertificate(protocol, reader, pins, ctx.destination, input, caller, tag, gasLimit);
  equal(certificate.admission.before_, before, "Prepared destination snapshots differ");
  equal(certificate.admission.source, ctx.source, "Prepared source suite differs");
  if (!same(certificate.admission.prior, pins.source.registry.address)
    || !same(certificate.admission.sourceCoordinator, pins.source.coordinator.address)) {
    throw Error("Prepared predecessor coordinates differ");
  }
  const semanticInventory = protocol.semanticInventory(certificate);
  if (request.expectedSemanticInventory !== ZeroHash && request.expectedSemanticInventory !== semanticInventory) {
    throw Error("Expected recovered semantic inventory changed");
  }
  const finalInput = protocol.finalizeInput(input, semanticInventory);
  const finalRequest = protocol.request(finalInput);
  const prepared = protocol.prepareCall(pins.destination.registry.address, caller, finalInput);
  protocol.validateInput?.(finalInput, certificate);
  bytes(prepared.call.data, MAX_CALL_BYTES);
  // The hash/codec validator also binds request selectors, ordered witnesses and complete query partitions.
  const commitment = protocol.commitment(coordinates(pins), finalRequest, certificate);
  for (const artist of certificate.admission.artists) {
    await lane(reader, ctx.destination, ctx.source, 1n, artist.artistId, BigInt(artist.records.length), tag);
  }
  for (const collection of certificate.admission.collections) {
    const key = coder.encode(["uint256"], [collection.collectionId]) as Hex;
    await lane(reader, ctx.destination, ctx.source, 2n, key, BigInt(collection.records.length), tag);
  }
  const owners = await sourceInventories(protocol, reader, pins, ctx.destination, finalRequest, certificate, tag);
  const timingEntries = await timingInventory(reader, ctx.source.owners[2]!, certificate.timing, tag);
  await externalGuards(reader, certificate.externalGuards, tag);
  await protocol.validateSource?.(reader, ctx.source, finalInput, certificate, tag);
  const destinationCatalogs: ArtistRecoveredHydrationPayloadCatalog[] = [];
  for (const i of [2, 4, 6]) destinationCatalogs.push(await catalog(reader, ctx.destination.owners[i]!, tag));
  destinationCatalogs.push(await catalog(reader, ctx.destination.archive, tag, MAX_LOGS));
  const origin = destinationOrigin(pins, ctx.destination);
  const after = before.map((snapshot, i) => protocol.ownerAfter(
    origin, i as ArtistHydrationOwnerIndex, snapshot, certificate.query, certificate.data[i]!, commitment, caller, owners[i]!.historicalCells,
  ));
  const profileEvidence = protocol.profileEvidence(finalRequest, certificate);
  const descriptor = rh.artistRecoveredHydrationEvidenceDescriptor(profileEvidence);
  const evidenceId = rh.artistRecoveredHydrationEvidenceId(coordinates(pins), caller, commitment);
  const operationEvidence = rh.encodeArtistRecoveredHydrationOperationEvidence({
    schemaVersion: 1n,
    configurationHash: ctx.configurationHash,
    operationId: 60n,
    actor: caller,
    commitment,
    before: before as ArtistHydrationSeven<ArtistHydrationSnapshot>,
    after: after as unknown as ArtistHydrationSeven<ArtistHydrationSnapshot>,
    profileData: coder.encode(["bytes32", rh.ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE],
      [rh.ARTIST_RECOVERED_HYDRATION_PROFILE, descriptor]) as Hex,
  });
  if (BigInt((operationEvidence.length - 2) / 2) > ctx.archiveLimit) {
    throw Error("Complete original operation header exceeds Archive capacity");
  }
  // This repeats the original producer after all independent reads, including its external rechecks.
  equal(await collectCertificate(protocol, reader, pins, ctx.destination, finalInput, caller, tag, gasLimit),
    certificate, "Original preparation certificate changed during collection");
  await unchanged(reader, ctx.observed);
  const body: Omit<ArtistRecoveredHydrationCapture<C>, "captureHash"> = {
    deployment: pins,
    observed: ctx.observed,
    prepared,
    certificate,
    sourceSuite: ctx.source,
    destinationSuite: ctx.destination,
    configurationHash: ctx.configurationHash,
    archiveLimit: ctx.archiveLimit,
    preparationGasLimit: gasLimit,
    owners,
    timingEntries,
    destinationCatalogs,
    after,
    commitment,
    profileEvidence,
    descriptor,
    evidenceId,
    operationEvidence,
    registrySimulated: false,
  };
  return freeze({ ...body, captureHash: captureHash(body) });
}

export interface ArtistRecoveredHydrationSimulation<C extends rh.ArtistRecoveredHydrationCall = rh.ArtistRecoveredHydrationCall> {
  readonly capture: ArtistRecoveredHydrationCapture<C>;
  readonly observed: ArtistRecoveredHydrationObservation;
  readonly gasLimit: bigint;
  readonly returnData: Hex;
  readonly commitment: Hex;
  readonly registrySimulated: true;
  readonly futureExecutionGuaranteed: false;
}

/** The original Registry is called from the exact intended caller, with zero native value. */
async function simulateArtistRecoveredHydration<I, C extends rh.ArtistRecoveredHydrationCall>(
  protocol: RecoveredHydrationWorkflowProtocol<I, C>,
  reader: ArtistRecoveredHydrationReader,
  input: ArtistRecoveredHydrationCapture<C>,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<ArtistRecoveredHydrationSimulation<C>> {
  const saved = captured(protocol, input);
  const tag = blockNumber(options.blockTag);
  const gasLimit = gas(options.gasLimit);
  if (tag < saved.observed.blockNumber) throw Error("Simulation precedes reviewed capture");
  const historical = await captureArtistRecoveredHydration(protocol, reader, saved.deployment, saved.prepared.caller,
    protocol.inputFromCall(saved.prepared), { blockTag: saved.observed.blockNumber, gasLimit: saved.preparationGasLimit });
  equal(historical, saved, "Historical recovered capture no longer reproduces");
  const current = tag === saved.observed.blockNumber ? historical : await captureArtistRecoveredHydration(
    protocol, reader, saved.deployment, saved.prepared.caller, protocol.inputFromCall(saved.prepared),
    { blockTag: tag, gasLimit: saved.preparationGasLimit },
  );
  equal(reviewedFacts(current), reviewedFacts(saved), "Reviewed recovered source or destination changed; recapture required");
  const returnData = bytes(await reader.call({
    ...current.prepared.call,
    from: current.prepared.caller,
    gasLimit,
    blockTag: tag,
  }), 32);
  if (returnData !== coder.encode(["bytes32"], [saved.commitment])) {
    throw Error("Original Registry returned another commitment");
  }
  await unchanged(reader, current.observed);
  return freeze({ capture: current, observed: current.observed, gasLimit, returnData,
    commitment: saved.commitment, registrySimulated: true, futureExecutionGuaranteed: false });
}

interface ReceiptLog {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}

export interface ArtistRecoveredHydrationReceipt {
  readonly transactionHash: Hex;
  readonly observed: ArtistRecoveredHydrationObservation;
  readonly commitment: Hex;
  readonly evidenceId: Hex;
  readonly descriptor: rh.ArtistRecoveredHydrationEvidenceDescriptor;
  readonly profileEvidence: Hex;
  readonly operationEvidence: Hex;
  readonly ownerSnapshots: readonly ArtistHydrationSnapshot[];
  readonly events: readonly { readonly address: Address; readonly event: string; readonly logIndex: number }[];
  readonly historicalImportProven: true;
  readonly currentAuthorityClaimed: false;
}

function receiptLogs(
  receipt: Awaited<ReturnType<ArtistRecoveredHydrationReceiptReader["getTransactionReceipt"]>>,
  transactionHash: Hex,
  tag: number,
  blockHash: Hex,
): readonly ReceiptLog[] {
  if (!receipt || receipt.status !== 1) throw Error("Successful original transaction receipt required");
  dense(receipt.logs, MAX_LOGS);
  let previous = -1;
  let totalBytes = 0;
  return receipt.logs.map(entry => {
    if (entry.removed || !Number.isSafeInteger(entry.index) || entry.index < 0
      || entry.index <= previous || entry.blockNumber !== tag
      || !same(entry.blockHash, blockHash) || !same(entry.transactionHash, transactionHash)) {
      throw Error("Removed, unordered or inconsistent receipt log");
    }
    previous = entry.index;
    dense(entry.topics, 4);
    const data = bytes(entry.data, MAX_PAYLOAD_BYTES + 4096);
    totalBytes += (data.length - 2) / 2 + entry.topics.length * 32;
    if (totalBytes > MAX_RPC_BYTES) throw Error("Aggregate receipt log bound exceeded");
    return freeze({ address: address(entry.address), topics: entry.topics.map(topic => hash(topic, true)),
      data, index: entry.index });
  });
}

function matching(logs: readonly ReceiptLog[], host: Address, event: string) {
  const fragment = abi.getEvent(event)!;
  return logs.filter(log => same(log.address, host) && same(log.topics[0], fragment.topicHash)).map(log => {
    const args = abi.decodeEventLog(fragment, log.data, [...log.topics]);
    const canonical = abi.encodeEventLog(fragment, args);
    equal(canonical.data.toLowerCase(), log.data, `Noncanonical ${event} event`);
    equal(canonical.topics.map(topic => topic.toLowerCase()), log.topics, `Noncanonical ${event} topics`);
    return { log, args: fragment.inputs.map((input, i) => plain(input, args[i])) };
  });
}

async function retainedEvidence(
  reader: ArtistRecoveredHydrationReader,
  archive: Address,
  evidenceId: Hex,
  payload: Hex,
  tag: number,
): Promise<ArtistRecoveredHydrationPayloadRow> {
  const contentHash = keccak256(payload) as Hex;
  const [observedHash, pointer, length, appendedAt] = await read(reader, archive, "artistEvidenceMetadataV2", [evidenceId, 1n], tag);
  if (!same(observedHash, contentHash) || length !== BigInt((payload.length - 2) / 2) || appendedAt !== BigInt(tag)) {
    throw Error("Original Archive page/header metadata differs");
  }
  const row = { pointer: address(pointer), payloadType: id("ARTIST_OPERATION_EVIDENCE") as Hex, payloadHash: contentHash };
  equal((await read(reader, archive, "artistEvidenceBytesV2", [evidenceId, 1n], tag))[0], payload,
    "Original Archive bytes differ");
  equal(await payloadBytes(reader, row, tag), payload, "Original Archive carrier differs");
  return row;
}

async function catalogAdditions(
  reader: ArtistRecoveredHydrationReader,
  host: Address,
  before: readonly ArtistRecoveredHydrationPayloadRow[],
  intended: readonly {
    readonly row: ArtistRecoveredHydrationPayloadRow;
    readonly afterIndex: number;
    readonly beforeIndex: number;
  }[],
  logs: readonly ReceiptLog[],
  tag: number,
) {
  const keys = new Set(before.map(row => `${row.payloadType}:${row.payloadHash}`));
  const additions = intended.filter(({ row }) => {
    const key = `${row.payloadType}:${row.payloadHash}`;
    if (keys.has(key)) return false;
    keys.add(key);
    return true;
  });
  const found = matching(logs, host, "ArtistStoredPayload");
  if (found.length !== additions.length) throw Error("Complete original payload catalog events required");
  let last = -1;
  for (let i = 0; i < additions.length; i++) {
    const expected = additions[i]!;
    const event = found[i]!;
    const index = BigInt(before.length + i);
    equal(event.args, [1n, index, expected.row.payloadType, expected.row.payloadHash, expected.row.pointer],
      "Original payload catalog event differs");
    if (event.log.index <= last || event.log.index <= expected.afterIndex || event.log.index >= expected.beforeIndex) {
      throw Error("Original payload catalog ordering differs");
    }
    equal(await read(reader, host, "storedPayloadAt", [index], tag),
      [expected.row.pointer, expected.row.payloadType, expected.row.payloadHash], "Stored payload catalog row differs");
    await payloadBytes(reader, expected.row, tag);
    last = event.log.index;
  }
  if ((await read(reader, host, "storedPayloadCount", [], tag))[0] < BigInt(before.length + additions.length)) {
    throw Error("Stored payload count regressed");
  }
  return found.map(event => ({ address: host, event: "ArtistStoredPayload", logIndex: event.log.index }));
}

/**
 * Reconciles the exact prior-block reviewed import against immutable pages, owner
 * prefixes and one atomic operation header. Later owner writes do not erase that history.
 */
async function reconcileArtistRecoveredHydrationReceipt<I, C extends rh.ArtistRecoveredHydrationCall>(
  protocol: RecoveredHydrationWorkflowProtocol<I, C>,
  reader: ArtistRecoveredHydrationReceiptReader,
  input: ArtistRecoveredHydrationCapture<C>,
  inputTransactionHash: Hex,
  inputOptions: ArtistRecoveredHydrationReceiptOptions,
): Promise<ArtistRecoveredHydrationReceipt> {
  const saved = captured(protocol, input);
  const transactionHash = hash(inputTransactionHash);
  if (inputOptions.execution !== "direct" && inputOptions.execution !== "safe") throw Error("Unsupported receipt execution");
  const execution = inputOptions.execution;
  const expectedSafeTxHash = execution === "safe"
    ? hash((inputOptions as Extract<ArtistRecoveredHydrationReceiptOptions, { execution: "safe" }>).expectedSafeTxHash) : null;
  const [transaction, receipt] = await Promise.all([
    reader.getTransaction(transactionHash), reader.getTransactionReceipt(transactionHash),
  ]);
  if (!transaction || !receipt || receipt.status !== 1 || transaction.blockNumber === null
    || !same(transaction.hash, transactionHash) || !same(receipt.hash, transactionHash)
    || transaction.chainId !== saved.deployment.chainId || receipt.blockNumber !== transaction.blockNumber
    || !same(receipt.blockHash, transaction.blockHash)) throw Error("Successful mined original transaction required");
  const tag = blockNumber(transaction.blockNumber);
  if (tag <= saved.observed.blockNumber || tag === 0) throw Error("Receipt must follow the reviewed capture block");
  const blockHash = hash(transaction.blockHash);
  const tx = freeze({ from: address(transaction.from), to: address(transaction.to),
    value: uint(transaction.value), data: bytes(transaction.data, MAX_CALL_BYTES + 16_384) });
  // Snapshot provider-owned logs before any further awaited readback.
  const logs = receiptLogs(receipt, transactionHash, tag, blockHash);
  if (tx.value !== 0n) throw Error("Original hydration transport requires zero native value");
  if (execution === "direct") {
    if (!same(tx.from, saved.prepared.caller) || !same(tx.to, saved.prepared.registry)
      || !same(tx.data, saved.prepared.call.data)) throw Error("Direct hydration transaction differs");
  } else {
    if (!same(tx.to, saved.prepared.caller)) throw Error("Safe is not the intended original caller");
    const decoded = safeAbi.decodeFunctionData("execTransaction", tx.data);
    if (!same(safeAbi.encodeFunctionData("execTransaction", decoded), tx.data)
      || !same(decoded[0], saved.prepared.registry) || decoded[1] !== 0n
      || !same(decoded[2], saved.prepared.call.data) || decoded[3] !== 0n) {
      throw Error("Exact original ordinary Safe CALL required");
    }
  }
  const historical = await captureArtistRecoveredHydration(protocol, reader, saved.deployment, saved.prepared.caller,
    protocol.inputFromCall(saved.prepared), { blockTag: saved.observed.blockNumber, gasLimit: saved.preparationGasLimit });
  equal(historical, saved, "Historical reviewed capture differs");
  const prior = await captureArtistRecoveredHydration(protocol, reader, saved.deployment, saved.prepared.caller,
    protocol.inputFromCall(saved.prepared), { blockTag: tag - 1, gasLimit: saved.preparationGasLimit });
  equal(reviewedFacts(prior), reviewedFacts(saved), "Prior-block import context changed; recapture required");
  if ((await reader.getNetwork()).chainId !== saved.deployment.chainId) throw Error("Wrong receipt chain");
  const observed = await header(reader, tag);
  if (!same(observed.blockHash, blockHash)) throw Error("Receipt block changed");
  const destination = await suite(reader, saved.deployment.destination, saved.deployment.chainId, tag);
  equal(destination, saved.destinationSuite, "Destination receipt suite differs");
  if (!same((await read(reader, saved.deployment.destination.coordinator.address, "configurationHash", [], tag))[0], saved.configurationHash)) {
    throw Error("Destination receipt configuration differs");
  }
  const committed = matching(logs, saved.deployment.destination.coordinator.address, "RecoveredArtistAuthorityHydrated");
  if (committed.length !== 1) throw Error("One original recovered hydration event required");
  const committedEvent = committed[0]!;
  equal(committedEvent.args, [1n, saved.deployment.source.registry.address, saved.commitment,
    saved.prepared.request.expectedSemanticInventory, saved.descriptor.payloadHash], "Recovered hydration event differs");
  const appended = matching(logs, destination.archive, "ArtistArchiveEvidenceAppendedV2");
  if (appended.length !== saved.descriptor.pageHashes.length + 1) throw Error("Complete fresh Archive pages and header required");
  const events = [{ address: saved.deployment.destination.coordinator.address,
    event: "RecoveredArtistAuthorityHydrated", logIndex: committedEvent.log.index }];
  const archiveWrites: { row: ArtistRecoveredHydrationPayloadRow; afterIndex: number; beforeIndex: number }[] = [];
  let previousAppend = -1;
  for (let i = 0; i < appended.length; i++) {
    const isHeader = i === saved.descriptor.pageHashes.length;
    const payload = isHeader ? saved.operationEvidence : `0x${saved.profileEvidence.slice(
      2 + i * rh.ARTIST_RECOVERED_HYDRATION_PAGE_BYTES * 2,
      2 + (i + 1) * rh.ARTIST_RECOVERED_HYDRATION_PAGE_BYTES * 2,
    )}` as Hex;
    const evidenceId = isHeader ? saved.evidenceId : rh.artistRecoveredHydrationPageId(
      coordinates(saved.deployment), saved.commitment, saved.descriptor, BigInt(i),
    );
    const row = await retainedEvidence(reader, destination.archive, evidenceId, payload, tag);
    const event = appended[i]!;
    equal(event.args, [evidenceId, 1n, row.payloadHash, row.pointer, BigInt((payload.length - 2) / 2)],
      "Original Archive append event differs");
    if (event.log.index <= previousAppend || event.log.index >= committedEvent.log.index) {
      throw Error("Original paged Archive/header ordering differs");
    }
    archiveWrites.push({ row, afterIndex: previousAppend, beforeIndex: event.log.index });
    previousAppend = event.log.index;
    events.push({ address: destination.archive, event: "ArtistArchiveEvidenceAppendedV2", logIndex: event.log.index });
  }
  const ownerSnapshots: ArtistHydrationSnapshot[] = [];
  const firstAppend = appended[0]!.log.index;
  for (let i = 0; i < 7; i++) {
    const owner = destination.owners[i]!;
    const expected = saved.after[i]!;
    const [snapshot] = await read(reader, owner, "ownerStateSnapshotV2", [], tag);
    if (snapshot.domainId !== expected.domainId || snapshot.revision < expected.revision) {
      throw Error("Owner did not complete its original hydration commit");
    }
    if (snapshot.revision === expected.revision) equal(snapshot, expected, "Original owner after-root differs");
    const [prefix, commitment, importedAt] = await read(reader, owner, "recoveredHydrationImportedPrefix", [], tag);
    equal(prefix, saved.owners[i]!.payload.provenance, "Immutable imported owner prefix differs");
    if (!same(commitment, saved.commitment) || importedAt !== expected.revision
      || !same((await read(reader, owner, "authorityHydrationCommitment", [], tag))[0], saved.commitment)) {
      throw Error("Seven original owner commitments and import revisions required");
    }
    if (snapshot.revision === expected.revision) {
      if ((await read(reader, owner, "artistNativeReceiptCount", [], tag))[0] !== 0n) {
        throw Error("Hydration must not append synthetic native receipts");
      }
      for (const nonce of saved.owners[i]!.payload.nonces) {
        for (let k = 0; k < nonce.words.length; k++) {
          const word = nonce.words[k]!;
          equal(await read(reader, owner, "authorityNonceWordAt", [nonce.index.kind, nonce.index.key, BigInt(k)], tag),
            [word.prefix, word.words, word.exhausted], "Imported nonce words differ");
        }
      }
      const origin = destinationOrigin(saved.deployment, destination);
      const data = saved.certificate.data[i]!;
      for (let j = 0; j < data.origins.length; j++) {
        const logical = data.origins[j]!;
        const expectedCell = historicalSurface(i, logical.surface)
          ? saved.owners[i]!.historicalCells.find(cell => cell.sourceKey === data.sourceKeys[j])!.cell : data.cells[j];
        equal((await read(reader, owner, "replayCell", [replayKey(origin, i, logical.surface, logical.scope)], tag))[0],
          expectedCell, "Imported active replay projection differs");
      }
    }
    ownerSnapshots.push(snapshot);
    if ([2, 4, 6].includes(i)) {
      const before = saved.destinationCatalogs.find(item => item.host === owner)!;
      const intended = saved.owners[i]!.payload.publications.map(row => ({ row, afterIndex: -1, beforeIndex: firstAppend }));
      const added = await catalogAdditions(reader, owner, before.rows, intended, logs, tag);
      const earlierOwnerRows = events.filter(event => event.event === "ArtistStoredPayload"
        && destination.owners.includes(event.address));
      const previousOwnerIndex = Math.max(-1, ...earlierOwnerRows.map(event => event.logIndex));
      if (added.some(event => event.logIndex <= previousOwnerIndex)) {
        throw Error("Original owner payload apply ordering differs");
      }
      events.push(...added);
      archiveWrites.push(...saved.owners[i]!.payload.publications.map(row => ({
        row, afterIndex: committedEvent.log.index, beforeIndex: Number.MAX_SAFE_INTEGER,
      })));
    }
  }
  await protocol.validateReceipt?.(reader, saved, ownerSnapshots, tag);
  const priorArchive = saved.destinationCatalogs.find(item => item.host === destination.archive)!;
  events.push(...await catalogAdditions(reader, destination.archive, priorArchive.rows, archiveWrites, logs, tag));
  if (execution === "safe") {
    requireSafeExecution({ status: 1, logs: logs.map(log => ({ address: log.address,
      topics: [...log.topics], data: log.data })) }, saved.prepared.caller, expectedSafeTxHash!);
    const successes = logs.filter(log => same(log.address, saved.prepared.caller)
      && same(log.topics[0], safeAbi.getEvent("ExecutionSuccess")!.topicHash));
    if (successes.length !== 1) throw Error("Exactly one Safe success required");
    const success = successes[0]!;
    const iface = success.topics.length === 2 ? indexedSafeAbi : safeAbi;
    const values = iface.decodeEventLog("ExecutionSuccess", success.data, [...success.topics]);
    const canonical = iface.encodeEventLog(iface.getEvent("ExecutionSuccess")!, values);
    equal(canonical.data.toLowerCase(), success.data, "Noncanonical Safe success data");
    equal(canonical.topics.map(topic => topic.toLowerCase()), success.topics, "Noncanonical Safe success topics");
    if (events.some(event => event.logIndex >= success.index)) throw Error("Safe success precedes complete original import evidence");
    events.push({ address: saved.prepared.caller, event: "ExecutionSuccess", logIndex: success.index });
  }
  await unchanged(reader, observed);
  return freeze({ transactionHash, observed, commitment: saved.commitment, evidenceId: saved.evidenceId,
    descriptor: saved.descriptor, profileEvidence: saved.profileEvidence, operationEvidence: saved.operationEvidence,
    ownerSnapshots, events: events.sort((a, b) => a.logIndex - b.logIndex),
    historicalImportProven: true, currentAuthorityClaimed: false });
}

/** Not barrel-exported: callers use one of the closed public profile wrappers. */
export function createRecoveredHydrationWorkflow<I, C extends rh.ArtistRecoveredHydrationCall>(
  inputProtocol: RecoveredHydrationWorkflowProtocol<I, C>,
) {
  const protocol = Object.freeze({ ...inputProtocol });
  return Object.freeze({
    capture: (
      reader: ArtistRecoveredHydrationReader,
      deployment: ArtistRecoveredHydrationDeployment,
      caller: Address,
      input: I,
      options: { readonly blockTag: number; readonly gasLimit: bigint },
    ) => captureArtistRecoveredHydration(protocol, reader, deployment, caller, input, options),
    simulate: (
      reader: ArtistRecoveredHydrationReader,
      capture: ArtistRecoveredHydrationCapture<C>,
      options: { readonly blockTag: number; readonly gasLimit: bigint },
    ) => simulateArtistRecoveredHydration(protocol, reader, capture, options),
    reconcile: (
      reader: ArtistRecoveredHydrationReceiptReader,
      capture: ArtistRecoveredHydrationCapture<C>,
      transactionHash: Hex,
      options: ArtistRecoveredHydrationReceiptOptions,
    ) => reconcileArtistRecoveredHydrationReceipt(protocol, reader, capture, transactionHash, options),
  });
}
