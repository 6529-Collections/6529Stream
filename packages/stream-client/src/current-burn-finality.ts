import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Log, Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { burnMintProgramConfigHash, normalizeBurnMintProgramConfig } from "./current-burn-mint.js";
import type { BurnMintProgram, BurnMintProgramConfig } from "./current-burn-mint.js";

export interface BurnFinalityCodePin { readonly address: Address; readonly codeHash: Hex }
export interface BurnFinalityDiscoveryPin extends BurnFinalityCodePin { readonly fromBlock: number }
export interface BurnFinalityERC20DiscoveryPin extends BurnFinalityDiscoveryPin {
  /** The dedicated gate's immutable ERC20 sale carrier, independently code-pinned. */
  readonly saleAdapter: BurnFinalityCodePin;
}
export type BurnFinalityProgramKind = "burn-mint" | "erc20-burn-mint" | "burn-redemption";
/** Deliberately collection-only: narrower artwork scopes do not imply collection closure. */
export interface BurnFinalityAction {
  readonly kind: "block-burns" | "freeze" | "collection-finality";
  readonly collectionId: bigint;
}
export interface BurnFinalityRequest {
  readonly chainId: bigint;
  readonly core: BurnFinalityCodePin;
  readonly moduleRegistry: BurnFinalityCodePin;
  readonly finality: BurnFinalityCodePin;
  readonly burnMintDeployments: readonly BurnFinalityDiscoveryPin[];
  readonly erc20BurnMintDeployments?: readonly BurnFinalityERC20DiscoveryPin[];
  readonly redemptionDeployments: readonly BurnFinalityDiscoveryPin[];
  readonly action: BurnFinalityAction;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly limits: {
    readonly maxBlockSpan: number; readonly maxLogs: number;
    readonly maxPrograms: number; readonly maxCollections: number;
  };
}
export interface BurnCollectionFinalityRecord {
  readonly finalized: boolean; readonly finalityRecordHash: Hex;
  readonly manifestContentHash: Hex; readonly manifestURIHash: Hex;
  readonly finalityManifestURI: string; readonly componentsHash: Hex;
  readonly manifestPointer: Address; readonly finalizedAt: bigint;
}
export interface BurnFinalityCollectionState {
  readonly collectionId: bigint; readonly supplyMode: bigint; readonly status: bigint;
  readonly hasMaxSupply: boolean; readonly maxSupply: bigint; readonly mintedEver: bigint;
  readonly frozen: boolean; readonly burnsBlocked: boolean; readonly burnsBlockedAtBlock: bigint;
  readonly collectionFinality: BurnCollectionFinalityRecord; readonly collectionFreezeMode: bigint;
  readonly sourceBurnsAllowedByCollection: boolean;
  readonly targetMintCapacityAvailable: boolean;
}
export interface BurnRedemptionProgram {
  readonly config: { readonly collectionId: bigint; readonly startTime: bigint; readonly endTime: bigint; readonly termsHash: Hex };
  readonly saleConfigHash: Hex; readonly saleNonce: bigint; readonly createdAt: bigint;
  readonly registryRevision: bigint; readonly cancelled: boolean;
}
export interface BurnFinalityWarning {
  readonly role: "program" | "source" | "target";
  readonly collectionId: bigint | null;
  readonly code: string;
  readonly message: string;
}
export interface BurnFinalityProgramImpact {
  readonly kind: BurnFinalityProgramKind;
  readonly deployment: Address;
  readonly programId: bigint | Hex;
  readonly configuredAtBlock: number;
  readonly program: BurnMintProgram | BurnRedemptionProgram;
  readonly sources: readonly BurnFinalityCollectionState[];
  readonly target: BurnFinalityCollectionState | null;
  /** Observed collection/window/cancellation blockers; not a full execution simulation. */
  readonly observedBlockers: readonly BurnFinalityWarning[];
  /** Consequences and prerequisites of the proposed action, separate from current blockers. */
  readonly sourceWarnings: readonly BurnFinalityWarning[];
  readonly targetWarnings: readonly BurnFinalityWarning[];
}
export interface BurnFinalityImpact {
  readonly request: BurnFinalityRequest;
  readonly chainId: bigint; readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly action: BurnFinalityAction;
  readonly coverage: {
    readonly kind: "supplied-deployments-and-block-ranges-only";
    readonly deployments: readonly { readonly kind: BurnFinalityProgramKind; readonly address: Address; readonly fromBlock: number; readonly toBlock: number; readonly logCount: number; readonly programCount: number }[];
    readonly inventoryComplete: false;
    readonly executionReadinessChecked: false;
  };
  readonly collections: readonly BurnFinalityCollectionState[];
  readonly programs: readonly BurnFinalityProgramImpact[];
  /** Core/finality-state prerequisites only; governance, manifests and component checks are outside this read. */
  readonly actionPreconditions: readonly BurnFinalityWarning[];
}

const coder = AbiCoder.defaultAbiCoder();
const mintConfig = "tuple(address manager,uint256 targetCollectionId,bytes32 phaseId,uint256[] sourceCollectionIds,uint8 sourcesPerMint,uint64 startsAt,uint64 endsAt,bool prepared,address nativeSaleAdapter)";
const mintProgram = `tuple(${mintConfig} config,bytes32 configHash,bytes32 managerCodeHash,bytes32 nativeSaleCodeHash)`;
const redemptionConfig = "tuple(uint256 collectionId,uint64 startTime,uint64 endTime,bytes32 termsHash)";
const redemptionProgram = `tuple(${redemptionConfig} config,bytes32 saleConfigHash,uint256 saleNonce,uint64 createdAt,uint64 registryRevision,bool cancelled)`;
const finalityRecord = "tuple(bool finalized,bytes32 finalityRecordHash,bytes32 manifestContentHash,bytes32 manifestURIHash,string finalityManifestURI,bytes32 componentsHash,address manifestPointer,uint64 finalizedAt)";
const scopeTuple = "tuple(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId)";
const bindings = ["function core() view returns (address)", "function moduleRegistry() view returns (address)", "function coreCodeHash() view returns (bytes32)", "function registryCodeHash() view returns (bytes32)"];
const gateAbi = new Interface([...bindings,
  `function program(uint256) view returns (${mintProgram})`,
  "function allowedSourceCollections(uint256) view returns (uint256[])",
  `event BurnMintProgramConfigured(uint16 schemaVersion,uint256 indexed targetCollectionId,address indexed manager,bytes32 indexed phaseId,bytes32 configHash,${mintConfig} config)`,
]);
const redemptionAbi = new Interface([...bindings,
  `function program(bytes32) view returns (${redemptionProgram})`,
  "event SaleConfigured(uint16 schemaVersion,bytes32 indexed saleId,uint256 indexed collectionId,bytes32 indexed phaseId,uint8 saleKind,address asset,bytes32 saleConfigHash,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode)",
  "event RedemptionTermsRecorded(uint16 schemaVersion,bytes32 indexed saleId,bytes32 indexed termsHash,uint64 startTime,uint64 endTime,uint256 saleNonce,address operator)",
]);
const coreAbi = new Interface([
  "function collectionExists(uint256) view returns (bool)",
  "function collectionSupplyMode(uint256) view returns (uint8)",
  "function collectionStatus(uint256) view returns (uint8)",
  "function collectionHasMaxSupply(uint256) view returns (bool)",
  "function collectionMaxSupply(uint256) view returns (uint256)",
  "function collectionMintedEver(uint256) view returns (uint256)",
  "function collectionFreezeStatus(uint256) view returns (bool)",
  "function collectionBurnsBlocked(uint256) view returns (bool)",
  "function collectionBurnsBlockedAtBlock(uint256) view returns (uint64)",
  "function getSatellitePointer(bytes32) view returns (address,bytes32,bool,bytes32,bytes4,address,uint8,bytes32,bytes32,uint64)",
]);
const finalityAbi = new Interface([
  "function core() view returns (address)",
  `function collectionFinalityRecord(uint256) view returns (${finalityRecord})`,
  `function artworkFreezeMode(${scopeTuple}) view returns (uint8)`,
]);
const dependencyAbi = new Interface(["function core() view returns (address)", "function moduleRegistry() view returns (address)", "function mintManager() view returns (address)"]);
const erc20GateAbi = new Interface([...gateAbi.fragments,
  "function erc20SaleAdapter() view returns (address)", "function erc20SaleCodeHash() view returns (bytes32)",
]);
const erc20SaleAbi = new Interface([...dependencyAbi.fragments,
  "function coreCodeHash() view returns (bytes32)", "function moduleRegistryCodeHash() view returns (bytes32)",
  "function mintManagerCodeHash() view returns (bytes32)",
]);
const interfaceAbi = new Interface(["function supportsInterface(bytes4) view returns (bool)"]);
// IStreamERC20BurnMintGate's own selectors, excluding inherited IStreamMintGate selectors.
// The retained compiled ERC20 ABI oracle independently checks this identifier.
const ERC20_GATE_INTERFACE = "0xdf1ac32a";
type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "getLogs" | "call">;
type Raw = Record<string, unknown>;
const MAX_RETURN_BYTES = 8192;
const MAX_CODE_BYTES = 49_152;

function keys(value: unknown, wanted: readonly string[], name: string): asserts value is Raw {
  if (!value || typeof value !== "object" || Array.isArray(value) || Object.keys(value).sort().join() !== [...wanted].sort().join()) throw Error(`${name} has missing or unknown fields`);
}
function uint(value: unknown, bits = 256, positive = false): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits) || (positive && value === 0n)) throw Error(`Expected ${positive ? "positive " : ""}uint${bits} bigint`); return value;
}
function integer(value: unknown, minimum: number, maximum: number): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < minimum || value > maximum) throw Error("Integer bound or block number is invalid"); return value;
}
function address(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Expected address"); const a = getAddress(value) as Address;
  if (!zero && a === ZeroAddress) throw Error("Zero address is invalid"); return a;
}
function hash(value: unknown, zero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (!zero && value.toLowerCase() === ZeroHash)) throw Error("Invalid bytes32 hash"); return value.toLowerCase() as Hex;
}
function bytes(value: unknown, max: number): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > max) throw Error("Malformed or oversized bytes"); return value.toLowerCase() as Hex;
}
function boolean(value: unknown): boolean { if (typeof value !== "boolean") throw Error("Noncanonical boolean"); return value; }
function same(a: unknown, b: unknown): boolean { return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase(); }
function pin(value: unknown): BurnFinalityCodePin {
  keys(value, ["address", "codeHash"], "deployment pin"); return Object.freeze({ address: address(value.address), codeHash: hash(value.codeHash) });
}
function discoveryPins(values: readonly BurnFinalityDiscoveryPin[], blockNumber: number, maxSpan: number): readonly BurnFinalityDiscoveryPin[] {
  if (!Array.isArray(values) || values.length > 16) throw Error("Discovery accepts at most 16 deployments per program kind");
  return Object.freeze(values.map(value => {
    keys(value, ["address", "codeHash", "fromBlock"], "discovery deployment");
    const fromBlock = integer(value.fromBlock, 0, blockNumber);
    if (blockNumber - fromBlock + 1 > maxSpan) throw Error("Discovery block range exceeds maxBlockSpan");
    return Object.freeze({ address: address(value.address), codeHash: hash(value.codeHash), fromBlock });
  }));
}
function erc20DiscoveryPins(values: readonly BurnFinalityERC20DiscoveryPin[], blockNumber: number, maxSpan: number): readonly BurnFinalityERC20DiscoveryPin[] {
  if (!Array.isArray(values) || values.length > 16) throw Error("Discovery accepts at most 16 deployments per program kind");
  return Object.freeze(values.map(value => {
    keys(value, ["address", "codeHash", "fromBlock", "saleAdapter"], "ERC20 discovery deployment");
    const fromBlock = integer(value.fromBlock, 0, blockNumber);
    if (blockNumber - fromBlock + 1 > maxSpan) throw Error("Discovery block range exceeds maxBlockSpan");
    return Object.freeze({ address: address(value.address), codeHash: hash(value.codeHash), fromBlock, saleAdapter: pin(value.saleAdapter) });
  }));
}
function request(input: BurnFinalityRequest): BurnFinalityRequest {
  const hasERC20 = Object.prototype.hasOwnProperty.call(input, "erc20BurnMintDeployments");
  keys(input, ["chainId", "core", "moduleRegistry", "finality", "burnMintDeployments", "redemptionDeployments", "action", "blockNumber", "blockHash", "limits", ...(hasERC20 ? ["erc20BurnMintDeployments"] : [])], "burn/finality request");
  keys(input.action, ["kind", "collectionId"], "collection action");
  if (!["block-burns", "freeze", "collection-finality"].includes(input.action.kind)) throw Error("Only collection-scoped burn block, freeze, and finality actions are supported");
  keys(input.limits, ["maxBlockSpan", "maxLogs", "maxPrograms", "maxCollections"], "inspection limits");
  const limits = Object.freeze({ maxBlockSpan: integer(input.limits.maxBlockSpan, 1, 1_000_000), maxLogs: integer(input.limits.maxLogs, 1, 4096), maxPrograms: integer(input.limits.maxPrograms, 1, 256), maxCollections: integer(input.limits.maxCollections, 1, 256) });
  const blockNumber = integer(input.blockNumber, 0, Number.MAX_SAFE_INTEGER);
  const result = Object.freeze({ chainId: uint(input.chainId, 256, true), core: pin(input.core), moduleRegistry: pin(input.moduleRegistry), finality: pin(input.finality), burnMintDeployments: discoveryPins(input.burnMintDeployments, blockNumber, limits.maxBlockSpan), ...(hasERC20 ? { erc20BurnMintDeployments: erc20DiscoveryPins(input.erc20BurnMintDeployments!, blockNumber, limits.maxBlockSpan) } : {}), redemptionDeployments: discoveryPins(input.redemptionDeployments, blockNumber, limits.maxBlockSpan), action: Object.freeze({ kind: input.action.kind, collectionId: uint(input.action.collectionId, 256, true) }), blockNumber, blockHash: hash(input.blockHash), limits });
  const addresses = [result.core.address, result.moduleRegistry.address, result.finality.address, ...result.burnMintDeployments.map(p => p.address), ...(result.erc20BurnMintDeployments ?? []).map(p => p.address), ...result.redemptionDeployments.map(p => p.address)].map(a => a.toLowerCase());
  if (new Set(addresses).size !== addresses.length) throw Error("Deployment addresses must be distinct");
  const carriers = new Map<string, Hex>();
  for (const { saleAdapter } of result.erc20BurnMintDeployments ?? []) {
    const carrier = saleAdapter.address.toLowerCase();
    if (addresses.includes(carrier)) throw Error("ERC20 carrier must be distinct from program hosts and Core registries");
    if (carriers.has(carrier) && carriers.get(carrier) !== saleAdapter.codeHash) throw Error("Shared ERC20 carrier code pins differ");
    carriers.set(carrier, saleAdapter.codeHash);
  }
  return result;
}
async function rpc(provider: Reader, target: Address, abi: Interface, name: string, args: readonly unknown[], blockNumber: number, size?: number): Promise<readonly unknown[]> {
  const raw = bytes(await provider.call({ to: target, data: abi.encodeFunctionData(name, args), blockTag: blockNumber }), MAX_RETURN_BYTES);
  if (size !== undefined && (raw.length - 2) / 2 !== size) throw Error(`Malformed ${name} return length`);
  const decoded = abi.decodeFunctionResult(name, raw);
  if (!same(raw, abi.encodeFunctionResult(name, decoded))) throw Error(`Noncanonical ${name} return`); return decoded;
}
async function code(provider: Reader, p: BurnFinalityCodePin, blockNumber: number): Promise<void> {
  const runtime = bytes(await provider.getCode(p.address, blockNumber), MAX_CODE_BYTES);
  if (runtime === "0x" || !same(keccak256(runtime), p.codeHash)) throw Error(`Deployment code differs at ${p.address}`);
}
async function stableBlock(provider: Reader, r: BurnFinalityRequest): Promise<bigint> {
  const value = await provider.getBlock(r.blockNumber);
  if (!value || value.number !== r.blockNumber || !same(value.hash, r.blockHash)) throw Error("Pinned inspection block changed or is unavailable");
  return BigInt(integer(value.timestamp, 0, Number.MAX_SAFE_INTEGER));
}
async function pointer(provider: Reader, r: BurnFinalityRequest, name: string, target: BurnFinalityCodePin): Promise<void> {
  const value = await rpc(provider, r.core.address, coreAbi, "getSatellitePointer", [id(name)], r.blockNumber, 320);
  if (!same(value[0], target.address) || !same(value[1], target.codeHash)) throw Error(`${name} Core pointer differs from the deployment binding`);
}
async function deploymentBindings(provider: Reader, r: BurnFinalityRequest, p: BurnFinalityDiscoveryPin, abi: Interface): Promise<void> {
  const [[core], [registry], [coreHash], [registryHash]] = await Promise.all([
    rpc(provider, p.address, abi, "core", [], r.blockNumber, 32), rpc(provider, p.address, abi, "moduleRegistry", [], r.blockNumber, 32),
    rpc(provider, p.address, abi, "coreCodeHash", [], r.blockNumber, 32), rpc(provider, p.address, abi, "registryCodeHash", [], r.blockNumber, 32),
  ]);
  if (!same(core, r.core.address) || !same(registry, r.moduleRegistry.address) || !same(coreHash, r.core.codeHash) || !same(registryHash, r.moduleRegistry.codeHash)) throw Error("Burn deployment immutable dependencies differ");
}
async function gateKind(provider: Reader, r: BurnFinalityRequest, p: BurnFinalityDiscoveryPin, erc20: boolean): Promise<void> {
  const [supported] = await rpc(provider, p.address, interfaceAbi, "supportsInterface", [ERC20_GATE_INTERFACE], r.blockNumber, 32);
  if (boolean(supported) !== erc20) throw Error("Burn gate kind differs; supply dedicated ERC20 gates with their carrier in erc20BurnMintDeployments");
}
async function erc20Bindings(provider: Reader, r: BurnFinalityRequest, p: BurnFinalityERC20DiscoveryPin): Promise<void> {
  const [[carrier], [carrierHash], [core], [coreHash], [registry], [registryHash]] = await Promise.all([
    rpc(provider, p.address, erc20GateAbi, "erc20SaleAdapter", [], r.blockNumber, 32),
    rpc(provider, p.address, erc20GateAbi, "erc20SaleCodeHash", [], r.blockNumber, 32),
    rpc(provider, p.saleAdapter.address, erc20SaleAbi, "core", [], r.blockNumber, 32),
    rpc(provider, p.saleAdapter.address, erc20SaleAbi, "coreCodeHash", [], r.blockNumber, 32),
    rpc(provider, p.saleAdapter.address, erc20SaleAbi, "moduleRegistry", [], r.blockNumber, 32),
    rpc(provider, p.saleAdapter.address, erc20SaleAbi, "moduleRegistryCodeHash", [], r.blockNumber, 32),
  ]);
  if (!same(carrier, p.saleAdapter.address) || !same(carrierHash, p.saleAdapter.codeHash) || !same(core, r.core.address) || !same(coreHash, r.core.codeHash) || !same(registry, r.moduleRegistry.address) || !same(registryHash, r.moduleRegistry.codeHash)) throw Error("ERC20 burn gate/carrier immutable dependencies differ");
}
function mintConfigFrom(value: unknown): BurnMintProgramConfig {
  const v = value as readonly unknown[];
  if (!Array.isArray(v) || v.length !== 9 || !Array.isArray(v[3]) || v[3].length > 64) throw Error("Malformed or unknown burn-mint program configuration");
  return normalizeBurnMintProgramConfig({ manager: address(v[0]), targetCollectionId: uint(v[1], 256, true), phaseId: hash(v[2]), sourceCollectionIds: v[3].map(x => uint(x, 256, true)), sourcesPerMint: uint(v[4], 8, true), startsAt: uint(v[5], 64), endsAt: uint(v[6], 64), prepared: boolean(v[7]), nativeSaleAdapter: address(v[8], true) });
}
function mintProgramFrom(value: unknown): BurnMintProgram {
  const v = value as readonly unknown[];
  return Object.freeze({ config: mintConfigFrom(v[0]), configHash: hash(v[1]), managerCodeHash: hash(v[2]), nativeSaleCodeHash: hash(v[3], true) });
}
function redemptionProgramFrom(value: unknown): BurnRedemptionProgram {
  const v = value as readonly unknown[]; const c = v[0] as readonly unknown[];
  const config = Object.freeze({ collectionId: uint(c[0], 256, true), startTime: uint(c[1], 64), endTime: uint(c[2], 64), termsHash: hash(c[3]) });
  if (config.endTime <= config.startTime) throw Error("Redemption program window is invalid");
  return Object.freeze({ config, saleConfigHash: hash(v[1]), saleNonce: uint(v[2], 256, true), createdAt: uint(v[3], 64, true), registryRevision: uint(v[4], 64, true), cancelled: boolean(v[5]) });
}
function redemptionSaleId(r: BurnFinalityRequest, deployment: Address, p: BurnRedemptionProgram): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"], [id("6529STREAM_SALE_V1"), r.chainId, deployment, 9n, p.config.collectionId, ZeroHash, p.saleNonce])) as Hex;
}
function redemptionConfigHash(r: BurnFinalityRequest, deployment: Address, saleId: Hex, p: BurnRedemptionProgram): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "uint256", "uint8", redemptionConfig, "bytes32", "address", "uint256", "bytes32", "uint8", "bytes32"], [id("6529STREAM_BURN_REDEMPTION_CONFIG_V1"), r.chainId, deployment, r.core.address, saleId, p.saleNonce, 9n, p.config, ZeroHash, ZeroAddress, 0n, ZeroHash, 0n, ZeroHash])) as Hex;
}
interface Discovered { readonly pin: BurnFinalityDiscoveryPin; readonly log: Log; readonly values: readonly unknown[] }
async function discover(provider: Reader, r: BurnFinalityRequest, p: BurnFinalityDiscoveryPin, abi: Interface, event: string): Promise<readonly Discovered[]> {
  const fragment = abi.getEvent(event)!;
  const logs = await provider.getLogs({ address: p.address, topics: [fragment.topicHash], fromBlock: p.fromBlock, toBlock: r.blockNumber });
  if (!Array.isArray(logs) || logs.length > r.limits.maxLogs) throw Error("Discovery log count exceeds maxLogs");
  const seen = new Set<string>();
  const result = logs.map(log => {
    if (!same(log.address, p.address) || log.removed !== false || !same(log.topics[0], fragment.topicHash) || log.topics.length !== fragment.inputs.filter(p => p.indexed).length + 1) throw Error("Discovery returned a removed, wrong-address or malformed event");
    integer(log.blockNumber, p.fromBlock, r.blockNumber); integer(log.index, 0, Number.MAX_SAFE_INTEGER); integer(log.transactionIndex, 0, Number.MAX_SAFE_INTEGER);
    hash(log.blockHash); hash(log.transactionHash); log.topics.forEach(t => hash(t, true));
    if (log.blockNumber === r.blockNumber && !same(log.blockHash, r.blockHash)) throw Error("Discovery event differs from pinned block");
    const key = `${log.blockHash.toLowerCase()}:${log.index}`;
    if (seen.has(key)) throw Error("Duplicate discovery event"); seen.add(key);
    const data = bytes(log.data, MAX_RETURN_BYTES); const values = abi.decodeEventLog(fragment, data, [...log.topics]);
    const encoded = abi.encodeEventLog(fragment, values);
    if (!same(encoded.data, data) || encoded.topics.some((t, i) => !same(t, log.topics[i]))) throw Error("Noncanonical discovery event");
    if (values[0] !== 1n) throw Error("Unsupported discovery event schema");
    return Object.freeze({ pin: p, log: Object.freeze({ ...log, topics: Object.freeze([...log.topics]) }) as unknown as Log, values: Object.freeze([...values]) });
  });
  result.sort((a, b) => a.log.blockNumber - b.log.blockNumber || a.log.index - b.log.index);
  return Object.freeze(result);
}
function warning(role: BurnFinalityWarning["role"], collectionId: bigint | null, code: string, message: string): BurnFinalityWarning {
  return Object.freeze({ role, collectionId, code, message });
}
function collectionRecord(value: unknown, timestamp: bigint): BurnCollectionFinalityRecord {
  const v = value as readonly unknown[]; const uri = v[4];
  if (typeof uri !== "string" || toUtf8Bytes(uri).length > 2048) throw Error("Finality record URI exceeds bound");
  const result = Object.freeze({ finalized: boolean(v[0]), finalityRecordHash: hash(v[1], true), manifestContentHash: hash(v[2], true), manifestURIHash: hash(v[3], true), finalityManifestURI: uri, componentsHash: hash(v[5], true), manifestPointer: address(v[6], true), finalizedAt: uint(v[7], 64) });
  if (result.finalized) {
    for (const h of [result.finalityRecordHash, result.manifestContentHash, result.manifestURIHash, result.componentsHash]) hash(h);
    address(result.manifestPointer); uint(result.finalizedAt, 64, true);
    if (result.finalizedAt > timestamp || !same(keccak256(toUtf8Bytes(uri)), result.manifestURIHash)) throw Error("Finality record timestamp or URI hash differs");
  } else if (result.finalityRecordHash !== ZeroHash || result.manifestContentHash !== ZeroHash || result.manifestURIHash !== ZeroHash || result.componentsHash !== ZeroHash || result.manifestPointer !== ZeroAddress || result.finalizedAt !== 0n || uri !== "") throw Error("Unfinalized collection has nonempty finality record");
  return result;
}
async function collection(provider: Reader, r: BurnFinalityRequest, collectionId: bigint, timestamp: bigint): Promise<BurnFinalityCollectionState> {
  const names = ["collectionExists", "collectionSupplyMode", "collectionStatus", "collectionHasMaxSupply", "collectionMaxSupply", "collectionMintedEver", "collectionFreezeStatus", "collectionBurnsBlocked", "collectionBurnsBlockedAtBlock"];
  const results = await Promise.all(names.map(name => rpc(provider, r.core.address, coreAbi, name, [collectionId], r.blockNumber, 32)));
  if (results[0]![0] !== true) throw Error(`Unknown collection ${collectionId}`);
  const supplyMode = uint(results[1]![0], 8), status = uint(results[2]![0], 8), hasMaxSupply = boolean(results[3]![0]);
  const maxSupply = uint(results[4]![0]), mintedEver = uint(results[5]![0]);
  const frozen = boolean(results[6]![0]), burnsBlocked = boolean(results[7]![0]), burnsBlockedAtBlock = uint(results[8]![0], 64);
  if (supplyMode > 2n || status > 2n || (supplyMode === 2n ? hasMaxSupply || maxSupply !== 0n : !hasMaxSupply || maxSupply === 0n || mintedEver > maxSupply) || burnsBlocked !== (burnsBlockedAtBlock !== 0n) || burnsBlockedAtBlock > BigInt(r.blockNumber) || (burnsBlocked && status !== 2n) || (frozen && (!burnsBlocked || status !== 2n))) throw Error("Inconsistent Core collection domains or lifecycle");
  const [[record], [mode]] = await Promise.all([
    rpc(provider, r.finality.address, finalityAbi, "collectionFinalityRecord", [collectionId], r.blockNumber),
    rpc(provider, r.finality.address, finalityAbi, "artworkFreezeMode", [{ scopeType: 0n, collectionId, tokenId: 0n, scopeId: ZeroHash }], r.blockNumber, 32),
  ]);
  const finality = collectionRecord(record, timestamp); const collectionFreezeMode = uint(mode, 8);
  if (collectionFreezeMode !== (finality.finalized ? 2n : 0n) || (finality.finalized && (!frozen || !burnsBlocked || status !== 2n || !same(finality.manifestPointer, r.finality.address)))) throw Error("Collection finality record and collection freeze mode or registry pointer disagree");
  return Object.freeze({ collectionId, supplyMode, status, hasMaxSupply, maxSupply, mintedEver, frozen, burnsBlocked, burnsBlockedAtBlock, collectionFinality: finality, collectionFreezeMode, sourceBurnsAllowedByCollection: !burnsBlocked && !frozen, targetMintCapacityAvailable: status === 0n && !frozen && (!hasMaxSupply || mintedEver < maxSupply) });
}
function observedSources(sources: readonly BurnFinalityCollectionState[]): BurnFinalityWarning[] {
  return sources.flatMap(s => {
    const out: BurnFinalityWarning[] = [];
    if (s.burnsBlocked) out.push(warning("source", s.collectionId, "source-burns-blocked", "Core permanently blocks burns from this source collection."));
    if (s.frozen) out.push(warning("source", s.collectionId, "source-frozen", "The source collection is frozen and Core rejects its burns."));
    return out;
  });
}
function observedTarget(target: BurnFinalityCollectionState): BurnFinalityWarning[] {
  const out: BurnFinalityWarning[] = [];
  if (target.status !== 0n) out.push(warning("target", target.collectionId, target.status === 2n ? "target-closed" : "target-paused", target.status === 2n ? "The target is irreversibly CLOSED; Core cannot mint further tokens into it." : "The target is PAUSED, which reversibly prevents new mints until an authorized status change restores ACTIVE."));
  if (target.frozen) out.push(warning("target", target.collectionId, "target-frozen", "Core rejects new mints into a frozen target collection."));
  if (target.hasMaxSupply && target.mintedEver >= target.maxSupply) out.push(warning("target", target.collectionId, "target-cap-reached", target.supplyMode === 0n ? "The FIXED target's immutable cap is exhausted; burns do not restore minted-ever capacity." : "The CAPPED_OPEN target has reached its current cap; burns do not restore capacity. A permitted cap increase may reopen capacity while the collection remains open and unfrozen."));
  return out;
}
function consequences(action: BurnFinalityAction, sources: readonly BurnFinalityCollectionState[], target: BurnFinalityCollectionState | null): { sourceWarnings: readonly BurnFinalityWarning[]; targetWarnings: readonly BurnFinalityWarning[] } {
  const sourceWarnings: BurnFinalityWarning[] = [], targetWarnings: BurnFinalityWarning[] = [];
  if (sources.some(s => s.collectionId === action.collectionId)) {
    const messages = {
      "block-burns": ["source-burns-will-stop", "Blocking this source collection's burns permanently removes it from this program's usable sources; other allowed sources are assessed separately."],
      freeze: ["source-freeze-requires-blocked-burns", "Freezing requires this source's burns already blocked and keeps them permanently unavailable; freeze is not the first burn-disabling step."],
      "collection-finality": ["source-finality-requires-burn-closure", "Collection finality requires this source already CLOSED, burn-blocked and frozen. Finality records that boundary; it does not perform those Core transitions."],
    } as const;
    const message = messages[action.kind]; sourceWarnings.push(warning("source", action.collectionId, message[0], message[1]));
  }
  if (target?.collectionId === action.collectionId) {
    const messages = {
      "block-burns": ["target-closure-required", "Blocking the target's own burns requires it already CLOSED, which prevents further target mints. The burn-block flag is not an independent mint-capacity condition."],
      freeze: ["target-freeze-requires-closure", "Freezing requires this target already CLOSED and burn-blocked, and permanently prevents further target mints."],
      "collection-finality": ["target-finality-requires-closure", "Collection finality requires this target already CLOSED, burn-blocked and frozen. Minting must have stopped before finality is recorded."],
    } as const;
    const message = messages[action.kind]; targetWarnings.push(warning("target", action.collectionId, message[0], message[1]));
  }
  return { sourceWarnings: Object.freeze(sourceWarnings), targetWarnings: Object.freeze(targetWarnings) };
}
function actionPreconditions(action: BurnFinalityAction, c: BurnFinalityCollectionState): readonly BurnFinalityWarning[] {
  const out: BurnFinalityWarning[] = [];
  const add = (code: string, message: string) => out.push(warning("program", c.collectionId, code, message));
  if (c.status !== 2n) add("collection-not-closed", "The proposed collection action requires CLOSED Core status first.");
  if (action.kind === "block-burns") {
    if (c.burnsBlocked) add("burns-already-blocked", "blockCollectionBurns cannot repeat an existing burn block.");
    if (c.frozen) add("collection-already-frozen", "blockCollectionBurns cannot run after collection freeze.");
  } else {
    if (!c.burnsBlocked) add("burns-not-blocked", "The collection's burns must already be blocked.");
    if (action.kind === "freeze" && c.frozen) add("collection-already-frozen", "freezeCollection cannot repeat a freeze.");
    if (action.kind === "collection-finality" && !c.frozen) add("collection-not-frozen", "Collection finality requires the Core collection already frozen.");
    if (action.kind === "collection-finality" && c.collectionFinality.finalized) add("collection-already-finalized", "The collection already has an immutable finality record.");
  }
  return Object.freeze(out);
}

/**
 * Bounded deployment/range inventory joined to exact immutable programs and collection facts.
 * This is not an execution simulation, chain-wide inventory, or approval of a finality action.
 */
export async function inspectBurnFinalityImpact(provider: Reader, input: BurnFinalityRequest): Promise<BurnFinalityImpact> {
  const r = request(input);
  const erc20Deployments = r.erc20BurnMintDeployments ?? [];
  if ((await provider.getNetwork()).chainId !== r.chainId) throw Error("RPC chain differs from requested chain");
  const timestamp = await stableBlock(provider, r);
  await Promise.all([r.core, r.moduleRegistry, r.finality, ...r.burnMintDeployments, ...erc20Deployments, ...erc20Deployments.map(p => p.saleAdapter), ...r.redemptionDeployments].map(p => code(provider, p, r.blockNumber)));
  const [[finalityCore]] = await Promise.all([
    rpc(provider, r.finality.address, finalityAbi, "core", [], r.blockNumber, 32),
    pointer(provider, r, "MODULE_REGISTRY", r.moduleRegistry), pointer(provider, r, "ARTWORK_FINALITY_REGISTRY", r.finality),
    ...r.burnMintDeployments.map(p => deploymentBindings(provider, r, p, gateAbi)),
    ...r.burnMintDeployments.map(p => gateKind(provider, r, p, false)),
    ...erc20Deployments.map(p => deploymentBindings(provider, r, p, erc20GateAbi)),
    ...erc20Deployments.map(p => gateKind(provider, r, p, true)),
    ...erc20Deployments.map(p => erc20Bindings(provider, r, p)),
    ...r.redemptionDeployments.map(p => deploymentBindings(provider, r, p, redemptionAbi)),
  ]);
  if (!same(finalityCore, r.core.address)) throw Error("Finality registry Core differs");
  const discovered = await Promise.all([
    ...r.burnMintDeployments.map(async p => ({ kind: "burn-mint" as const, pin: p, events: await discover(provider, r, p, gateAbi, "BurnMintProgramConfigured"), terms: [] as readonly Discovered[] })),
    ...erc20Deployments.map(async p => ({ kind: "erc20-burn-mint" as const, pin: p, events: await discover(provider, r, p, erc20GateAbi, "BurnMintProgramConfigured"), terms: [] as readonly Discovered[] })),
    ...r.redemptionDeployments.map(async p => { const [events, terms] = await Promise.all([discover(provider, r, p, redemptionAbi, "SaleConfigured"), discover(provider, r, p, redemptionAbi, "RedemptionTermsRecorded")]); return { kind: "burn-redemption" as const, pin: p, events, terms }; }),
  ]);
  const count = discovered.reduce((n, d) => n + d.events.length, 0);
  const logCount = discovered.reduce((n, d) => n + d.events.length + d.terms.length, 0);
  if (logCount > r.limits.maxLogs || count > r.limits.maxPrograms) throw Error("Total discovered log/program count exceeds the requested bound");
  const historicalBlocks = new Map<number, { readonly hash: Hex; readonly timestamp: bigint }>();
  for (const e of discovered.flatMap(d => [...d.events, ...d.terms])) {
    let historical = historicalBlocks.get(e.log.blockNumber);
    if (!historical) {
      const value = await provider.getBlock(e.log.blockNumber);
      if (!value || value.number !== e.log.blockNumber) throw Error("Discovery event block is unavailable");
      historical = Object.freeze({ hash: hash(value.hash), timestamp: BigInt(integer(value.timestamp, 0, Number.MAX_SAFE_INTEGER)) });
      historicalBlocks.set(e.log.blockNumber, historical);
    }
    if (!same(e.log.blockHash, historical.hash)) throw Error("Discovery event is not in its canonical block");
  }
  const collectionIds = new Set<bigint>([r.action.collectionId]);
  const knownPrograms = new Set<string>();
  for (const d of discovered) if (d.kind === "burn-redemption") {
    const saleIds = new Set(d.events.map(e => String(e.values[1])));
    const termIds = d.terms.map(e => String(e.values[1]));
    if (d.terms.length !== d.events.length || new Set(termIds).size !== termIds.length || termIds.some(id => !saleIds.has(id))) throw Error("Redemption configuration requires exactly one matching terms event");
  }
  const entries: { kind: BurnFinalityProgramKind; deployment: Address; programId: bigint | Hex; configuredAtBlock: number; program: BurnMintProgram | BurnRedemptionProgram; sourceIds: readonly bigint[]; targetId: bigint | null; dependencyBlockers: readonly BurnFinalityWarning[] }[] = [];
  for (const d of discovered) for (const e of d.events) {
    const values = e.values; const programKey = `${d.pin.address}:${values[1]}`;
    if (knownPrograms.has(programKey)) throw Error("Duplicate immutable program configuration"); knownPrograms.add(programKey);
    if (d.kind !== "burn-redemption") {
      const targetId = uint(values[1], 256, true); const eventConfig = mintConfigFrom(values[5]);
      const [[raw], [allowed]] = await Promise.all([
        rpc(provider, d.pin.address, gateAbi, "program", [targetId], r.blockNumber), rpc(provider, d.pin.address, gateAbi, "allowedSourceCollections", [targetId], r.blockNumber),
      ]);
      const p = mintProgramFrom(raw);
      if (!Array.isArray(allowed) || allowed.length > 64 || allowed.length !== p.config.sourceCollectionIds.length || allowed.some((x, i) => x !== p.config.sourceCollectionIds[i]) || !same(coder.encode([mintConfig], [eventConfig]), coder.encode([mintConfig], [p.config])) || p.config.targetCollectionId !== targetId || !same(values[2], p.config.manager) || !same(values[3], p.config.phaseId) || !same(values[4], p.configHash) || !same(p.configHash, burnMintProgramConfigHash(r.chainId, d.pin.address, r.core.address, r.moduleRegistry.address, p.config))) throw Error("Burn-mint event, immutable program or allowed source list differs");
      const managerPin = { address: p.config.manager, codeHash: p.managerCodeHash };
      await code(provider, managerPin, r.blockNumber);
      const managerPointer = await rpc(provider, r.core.address, coreAbi, "getSatellitePointer", [id("MINT_MANAGER")], r.blockNumber, 320);
      const dependencyBlockers = same(managerPointer[0], managerPin.address) && same(managerPointer[1], managerPin.codeHash) ? [] : [warning("program", targetId, "program-manager-not-selected", "The immutable program Manager is not the currently selected Core Manager; the retained program cannot execute through this gate.")];
      const [[managerCore], [managerRegistry]] = await Promise.all([rpc(provider, p.config.manager, dependencyAbi, "core", [], r.blockNumber, 32), rpc(provider, p.config.manager, dependencyAbi, "moduleRegistry", [], r.blockNumber, 32)]);
      if (!same(managerCore, r.core.address) || !same(managerRegistry, r.moduleRegistry.address)) throw Error("Burn-mint Manager dependencies differ");
      if (d.kind === "erc20-burn-mint") {
        if (p.config.prepared || p.config.nativeSaleAdapter !== ZeroAddress || p.nativeSaleCodeHash !== ZeroHash) throw Error("ERC20 burn-mint program must be immediate with zero native-sale fields");
        const [[saleManager], [saleManagerHash]] = await Promise.all([
          rpc(provider, d.pin.saleAdapter.address, erc20SaleAbi, "mintManager", [], r.blockNumber, 32),
          rpc(provider, d.pin.saleAdapter.address, erc20SaleAbi, "mintManagerCodeHash", [], r.blockNumber, 32),
        ]);
        if (!same(saleManager, p.config.manager) || !same(saleManagerHash, p.managerCodeHash)) throw Error("ERC20 burn carrier Manager binding differs from immutable program");
      }
      else if (p.config.nativeSaleAdapter === ZeroAddress) { if (p.nativeSaleCodeHash !== ZeroHash) throw Error("Free burn-mint program has an unexpected native-sale code hash"); }
      else {
        await code(provider, { address: p.config.nativeSaleAdapter, codeHash: p.nativeSaleCodeHash }, r.blockNumber);
        const [[saleCore], [saleManager], [saleRegistry]] = await Promise.all([rpc(provider, p.config.nativeSaleAdapter, dependencyAbi, "core", [], r.blockNumber, 32), rpc(provider, p.config.nativeSaleAdapter, dependencyAbi, "mintManager", [], r.blockNumber, 32), rpc(provider, p.config.nativeSaleAdapter, dependencyAbi, "moduleRegistry", [], r.blockNumber, 32)]);
        if (!same(saleCore, r.core.address) || !same(saleManager, p.config.manager) || !same(saleRegistry, r.moduleRegistry.address)) throw Error("Paid burn-mint sale dependencies differ");
      }
      p.config.sourceCollectionIds.forEach(c => collectionIds.add(c)); collectionIds.add(targetId);
      entries.push({ kind: d.kind, deployment: d.pin.address, programId: targetId, configuredAtBlock: e.log.blockNumber, program: p, sourceIds: p.config.sourceCollectionIds, targetId, dependencyBlockers });
    } else {
      const saleId = hash(values[1]);
      if (values[4] !== 9n || values[3] !== ZeroHash || values[5] !== ZeroAddress || values[7] !== ZeroHash || values[8] !== 0n) throw Error("Redemption SaleConfigured must be original kind 9 with zero phase/payment fields");
      const [raw] = await rpc(provider, d.pin.address, redemptionAbi, "program", [saleId], r.blockNumber, 288);
      const p = redemptionProgramFrom(raw);
      if (p.createdAt > timestamp || p.config.startTime < p.createdAt || p.config.collectionId !== values[2] || !same(p.saleConfigHash, values[6]) || !same(redemptionSaleId(r, d.pin.address, p), saleId) || !same(redemptionConfigHash(r, d.pin.address, saleId, p), p.saleConfigHash)) throw Error("Redemption event and immutable program commitment differ");
      const terms = d.terms.find(t => same(t.values[1], saleId))!;
      if (terms.log.blockNumber !== e.log.blockNumber || !same(terms.log.blockHash, e.log.blockHash) || !same(terms.log.transactionHash, e.log.transactionHash) || terms.log.transactionIndex !== e.log.transactionIndex || terms.log.index <= e.log.index || !same(terms.values[2], p.config.termsHash) || terms.values[3] !== p.config.startTime || terms.values[4] !== p.config.endTime || terms.values[5] !== p.saleNonce || p.createdAt !== historicalBlocks.get(e.log.blockNumber)!.timestamp) throw Error("Redemption terms event, configuration transaction or creation timestamp differs");
      address(terms.values[6]);
      collectionIds.add(p.config.collectionId);
      entries.push({ kind: d.kind, deployment: d.pin.address, programId: saleId, configuredAtBlock: e.log.blockNumber, program: p, sourceIds: [p.config.collectionId], targetId: null, dependencyBlockers: [] });
    }
    if (collectionIds.size > r.limits.maxCollections) throw Error("Joined collection count exceeds maxCollections");
  }
  const collections = await Promise.all([...collectionIds].sort((a, b) => a < b ? -1 : a > b ? 1 : 0).map(c => collection(provider, r, c, timestamp)));
  const byId = new Map(collections.map(c => [c.collectionId, c]));
  const programs = entries.map(e => {
    const sources = Object.freeze(e.sourceIds.map(c => byId.get(c)!)); const target = e.targetId === null ? null : byId.get(e.targetId)!;
    const observedBlockers = [...e.dependencyBlockers, ...observedSources(sources)]; if (target) observedBlockers.push(...observedTarget(target));
    const start = e.kind !== "burn-redemption" ? (e.program as BurnMintProgram).config.startsAt : (e.program as BurnRedemptionProgram).config.startTime;
    const end = e.kind !== "burn-redemption" ? (e.program as BurnMintProgram).config.endsAt : (e.program as BurnRedemptionProgram).config.endTime;
    if (timestamp < start) observedBlockers.push(warning("program", null, "program-not-started", "The configured program window has not started."));
    if (end !== 0n && timestamp > end) observedBlockers.push(warning("program", null, "program-ended", "The configured program window has ended."));
    if (e.kind === "burn-redemption" && (e.program as BurnRedemptionProgram).cancelled) observedBlockers.push(warning("program", null, "program-cancelled", "The immutable redemption program has been cancelled."));
    return Object.freeze({ kind: e.kind, deployment: e.deployment, programId: e.programId, configuredAtBlock: e.configuredAtBlock, program: e.program, sources, target, observedBlockers: Object.freeze(observedBlockers), ...consequences(r.action, sources, target) });
  });
  for (const [number, expected] of historicalBlocks) {
    const value = await provider.getBlock(number);
    if (!value || value.number !== number || !same(value.hash, expected.hash) || BigInt(integer(value.timestamp, 0, Number.MAX_SAFE_INTEGER)) !== expected.timestamp) throw Error("Discovery block changed during inspection");
  }
  if (await stableBlock(provider, r) !== timestamp) throw Error("Pinned block timestamp changed during inspection");
  return Object.freeze({ request: r, chainId: r.chainId, blockNumber: r.blockNumber, blockHash: r.blockHash, timestamp, action: r.action,
    coverage: Object.freeze({ kind: "supplied-deployments-and-block-ranges-only", deployments: Object.freeze(discovered.map(d => Object.freeze({ kind: d.kind, address: d.pin.address, fromBlock: d.pin.fromBlock, toBlock: r.blockNumber, logCount: d.events.length + d.terms.length, programCount: d.events.length }))), inventoryComplete: false, executionReadinessChecked: false }),
    collections: Object.freeze(collections), programs: Object.freeze(programs), actionPreconditions: actionPreconditions(r.action, byId.get(r.action.collectionId)!),
  });
}
