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
import type { Address, Hex } from "./generated/contracts.js";
import { requireSafeExecution } from "./safe.js";
import * as sales from "./current-canonical-native-sales.js";
import * as floor from "./current-direct-conservation.js";
import {
  ENTROPY_COLLECTION_POLICY_INTERFACE_ID,
  ENTROPY_COLLECTION_POLICY_RECORD_TUPLE,
  type EntropyCollectionPolicyRecord,
} from "./current-entropy-collection-policy.js";

const ZERO = ZeroHash as Hex;
const ZERO_ADDRESS = ZeroAddress as Address;
const coder = AbiCoder.defaultAbiCoder();
const MAX_BYTES = 2 * 1024 * 1024;
const FLOOR_TUPLE = "tuple(bytes32 receiptHash,address recorder,bytes32 recorderCodeHash,bytes32 settlementKey,bytes32 candidatePayloadHash,bytes32 candidateCommitment,bytes32 resultHash,uint256 collectionId,uint256 tokenId,bytes32 effectiveTier,bytes32 firstSaleReceiptHash,bytes32 releaseReceiptHash,uint64 recordedAt)";

// Protocol fragments are checked against the separate frozen ABI113 compiler fixture.
const abi = new Interface([
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function moduleRegistry() view returns (address)",
  "function moduleRegistryCodeHash() view returns (bytes32)",
  "function revenueResolver() view returns (address)",
  "function resolverCodeHash() view returns (bytes32)",
  "function splitFactory() view returns (address)",
  "function factoryCodeHash() view returns (bytes32)",
  "function assetPolicyRegistry() view returns (address)",
  "function assetRegistryCodeHash() view returns (bytes32)",
  "function mintManager() view returns (address)",
  "function mintManagerCodeHash() view returns (bytes32)",
  "function mintLedger() view returns (address)",
  "function primarySaleSettlement() view returns (address)",
  "function settlementCodeHash() view returns (bytes32)",
  "function artistRegistry() view returns (address)",
  "function artistRegistryCodeHash() view returns (bytes32)",
  "function revenueEscrow() view returns (address)",
  "function escrowCodeHash() view returns (bytes32)",
  "function supportsInterface(bytes4 interfaceId) view returns (bool)",
  "function eip712Domain() view returns (bytes1,string,string,uint256,address,bytes32,uint256[])",
  `function authorizationDigest(${sales.CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE} a) view returns (bytes32)`,
  "function getSatellitePointer(bytes32 pointerType) view returns (address target,bytes32 codeHash,bool frozen,bytes32 moduleType,bytes4 interfaceId,address registry,uint8 registryStatus,bytes32 moduleManifestHash,bytes32 deploymentManifestHash,uint64 revision)",
  "function moduleRecord(address module) view returns ((uint8 status,bytes32 moduleType,bytes32 moduleVersion,bytes4 interfaceId,uint32 moduleGasLimit,bytes32 runtimeCodeHash,bytes32 deploymentManifestHash,bytes32 moduleManifestHash,string moduleManifestURI,uint64 registeredAt,uint64 statusUpdatedAt,uint64 revision))",
  "function phasePolicyHash(uint256 collectionId,bytes32 phaseId) view returns (bytes32)",
  "function phaseCounterIds(uint256 collectionId,bytes32 phaseId) view returns (bytes32[])",
  "function counterConfig(uint256 collectionId,bytes32 phaseId,bytes32 counterId) view returns ((bool enabled,uint8 keyMode,uint8 capMode,uint8 deltaMode,uint64 staticCap,uint64 staticIncrement,bytes32 counterConfigHash))",
  "function counterDefinitionForManager(address manager,bytes32 definitionHash) view returns (bool exists,(uint8 scope,uint8 keyMode,bytes32 capRoot,bytes32 metadataHash) definition)",
  "function isAuthorizationUsed(bytes32 authorizationId) view returns (bool)",
  "function isOperationRootUsed(bytes32 operationRoot) view returns (bool)",
  "function isManagerAuthorizationUsed(address manager,bytes32 authorizationId) view returns (bool)",
  "function isManagerOperationRootUsed(address manager,bytes32 operationRoot) view returns (bool)",
  `function previewSingleStepMintOperation(${sales.CANONICAL_NATIVE_SALES_MINT_BATCH_TUPLE} batch,bytes gateData) view returns (bytes32 operationRoot,bytes32[] operationIds)`,
  `function mintSaleAuthorizationId(${sales.CANONICAL_NATIVE_SALES_AUTHORIZATION_TUPLE} authorization) view returns (bytes32)`,
  "function immediateSaleAuthorizationBinding(bytes32 saleId) view returns (uint256 collectionId,bytes32 phaseId,uint8 saleKind,uint8 authorityMode,bytes32 configHash,address authorizer,uint8 authorizerKind)",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
  "function conservationFloor() view returns (address ledger,bytes32 runtimeCodeHash)",
  "function tokenCollectionIdentity(uint256 tokenId) view returns (bool mappingExists,uint256 collectionId,uint256 collectionSerial,bool burned)",
  "function tokenLifecycle(uint256 tokenId) view returns (uint8 lifecycle)",
  "function coordinatorAtMint(uint256 tokenId) view returns (address)",
  `function collectionEntropyPolicy(uint256 collectionId) view returns (${ENTROPY_COLLECTION_POLICY_RECORD_TUPLE})`,
  "function tokenEntropyStatus(uint256 tokenId) view returns (uint8)",
  `event ImmediateSaleExecution(bytes32 indexed saleId,bytes32 indexed executionId,bytes32 indexed operationRoot,uint8 status,${sales.CANONICAL_NATIVE_SALES_RECEIPT_TUPLE} receipt)`,
  `event ClaimSaleExecution(bytes32 indexed saleId,bytes32 indexed executionId,bytes32 indexed operationRoot,uint8 status,${sales.CANONICAL_NATIVE_SALES_RECEIPT_TUPLE} receipt)`,
  "event FreeClaimExecuted(bytes32 indexed saleId,bytes32 indexed executionId,uint256 indexed tokenId,bytes32 authorizationId)",
  "event ImmediateSaleClosed(bytes32 indexed saleId,uint64 soldQuantity)",
  "event SalePaymentExcessCredited(uint16 schemaVersion,bytes32 indexed saleId,address indexed payer,uint256 amount)",
  "event SaleRefundClaimed(uint16 schemaVersion,bytes32 indexed saleId,address indexed payer,address indexed recipient,uint256 amount)",
  "event ImmediateRevealAttempt(uint16 schemaVersion,uint256 indexed collectionId,uint256 indexed tokenId,bool succeeded,bytes32 requestKey,uint256 providerRequestId,uint256 returnDataSize,bytes failurePrefix)",
  "function settlementConsumed(bytes32 key) view returns (bool)",
  `function settlementResult(bytes32 key) view returns (${sales.CANONICAL_NATIVE_SALES_RESULT_TUPLE})`,
  "function officialSettled(bytes32 revenueClass,bytes32 profileId,address wallet,address asset) view returns (uint256)",
  "function totalOfficialSettled(address asset) view returns (uint256)",
  `function settlementReceipt(bytes32 settlementKey) view returns (${FLOOR_TUPLE})`,
  `function firstSale(uint256 collectionId) view returns (${floor.DIRECT_CONSERVATION_FIRST_SALE_RECEIPT_TUPLE})`,
  `function releaseFloorReceipt(bytes32 releaseKey) view returns (${floor.DIRECT_CONSERVATION_RELEASE_RECEIPT_TUPLE})`,
  "event MintLedgerAuthorizationConsumed(uint16 schemaVersion,bytes32 indexed authorizationId,bytes32 indexed operationRoot,address indexed manager,bytes32 boundPolicyHash)",
  "event MintLedgerOperationRootConsumed(uint16 schemaVersion,bytes32 indexed operationRoot,address indexed manager,bytes32 currentPolicyHash,bytes32 indexed boundPolicyHash,bytes32 authorizationId)",
  "event MintAuthorizationConsumed(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed phaseId,bytes32 indexed authorizationId,bytes32 boundPolicyHash,bytes32 operationRoot)",
  "event MintBatchExecuted(uint16 schemaVersion,bytes32 indexed operationRoot,uint256 indexed collectionId,bytes32 indexed phaseId,address executor,address payer,address authorizer,uint256 firstTokenId,uint256 quantity,bytes32 contextHash,bytes32 gateHash,bytes32 currentPolicyHash,bytes32 boundPolicyHash)",
  "event MintTokenExecuted(uint16 schemaVersion,bytes32 indexed operationId,uint256 indexed tokenId,bytes32 indexed operationRoot,uint256 collectionId,bytes32 phaseId,uint256 tokenIndex,address initialRecipient,address beneficiary,bytes32 tokenDataHash,bytes32 mintCommitment)",
  "event MintLedgerAuthorizationVoided(uint16 schemaVersion,bytes32 indexed authorizationId,address indexed manager)",
  "event MintAuthorizationVoided(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed phaseId,bytes32 indexed authorizationId,address authorizer,address verifyingContract,uint8 family)",
  "event PrimaryRevenueSettled(bytes32 indexed settlementKey,bytes32 indexed revenueClass,bytes32 indexed profileId,uint16 schemaVersion,address wallet,address asset,address payer,uint256 amount,bytes32 saleContextHash,bool policyDrift,uint8 assignmentType)",
  "event PrimaryRevenueSettlementContext(bytes32 indexed settlementKey,bytes32 indexed revenueClass,bytes32 indexed profileId,uint16 schemaVersion,address settlementCaller,bytes32 settlementId,uint8 policyMode,uint256 collectionId,uint256 tokenId,bytes32 operationRoot,bytes32 operationId,uint256 saleNonce,address poster,address beneficiary,bytes32 templateId)",
  "event PrimaryRevenueSettlementPolicy(bytes32 indexed settlementKey,bytes32 indexed revenueClass,bytes32 indexed profileId,uint16 schemaVersion,bytes32 expectedPrimaryPolicyHash,bytes32 resolvedPrimaryPolicyHash,bytes32 resolvedAssignmentHash,bytes32 templateId)",
  "event PrimaryRevenueExecutionBound(bytes32 indexed settlementKey,address indexed saleAdapter,bytes32 indexed executionId,uint16 schemaVersion,address executor,address paymentAdapter,bytes32 candidateCommitment,bytes32 currentPolicyHash,bytes32 boundPolicyHash)",
  `event ConservationSettlementRecorded(bytes32 indexed settlementKey,bytes32 indexed receiptHash,${FLOOR_TUPLE} receipt,uint16 schemaVersion)`,
  `event ConservationFirstSaleRecorded(uint256 indexed collectionId,bytes32 indexed receiptHash,${floor.DIRECT_CONSERVATION_FIRST_SALE_RECEIPT_TUPLE} receipt,uint16 schemaVersion)`,
  `event ConservationReleaseFloorRecorded(bytes32 indexed releaseKey,bytes32 indexed receiptHash,${floor.DIRECT_CONSERVATION_RELEASE_RECEIPT_TUPLE} receipt,uint16 schemaVersion)`,
]);

const safeAbi = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);

export interface CanonicalNativeSalesCodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}

/** Runtime and linked-library pins must come from reviewed deployment metadata. */
export interface CanonicalNativeSalesDeployment {
  readonly chainId: bigint;
  readonly family: "immediate" | "claim";
  readonly adapter: CanonicalNativeSalesCodePin;
  readonly core: CanonicalNativeSalesCodePin;
  readonly manager: CanonicalNativeSalesCodePin;
  readonly ledger: CanonicalNativeSalesCodePin;
  readonly recorder: CanonicalNativeSalesCodePin;
  readonly linkedDependencies: readonly CanonicalNativeSalesCodePin[];
}

export interface CanonicalNativeSalesBlock {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}

export interface CanonicalNativeSalesAdmission {
  readonly status: bigint;
  readonly registeredAt: bigint;
  readonly statusUpdatedAt: bigint;
  readonly revision: bigint;
}

export interface CanonicalNativeSalesReveal {
  readonly quote: sales.CanonicalNativeSalesRevealQuote;
  readonly collectionPolicy: EntropyCollectionPolicyRecord | null;
  readonly directPolicyProbe: "direct-observation-no-nested-gas-equivalence";
}

export interface CanonicalNativeSalesCapture {
  readonly deployment: CanonicalNativeSalesDeployment;
  readonly prepared: sales.CanonicalNativeSalesCall;
  readonly observed: CanonicalNativeSalesBlock;
  readonly record: sales.CanonicalNativeSalesRecord | sales.CanonicalNativeClaimRecord | null;
  readonly candidate: sales.CanonicalNativeSalesCandidate | null;
  readonly authorizationId: Hex | null;
  readonly reveal: CanonicalNativeSalesReveal | null;
  readonly admission: CanonicalNativeSalesAdmission | null;
  readonly counters: readonly sales.CanonicalNativeSalesCounterObservation[];
  readonly floor: CanonicalNativeSalesCodePin | null;
  readonly dependencies: readonly CanonicalNativeSalesCodePin[];
  readonly refundCredit: bigint;
  readonly refundLiability: bigint;
  readonly adapterBalance: bigint;
  readonly captureHash: Hex;
  readonly admissionAuthority: "original-adapter-or-manager-call-simulation";
}

type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "getBalance" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;

function frozen<T>(value: T): T {
  if (value !== null && typeof value === "object") {
    for (const item of Object.values(value)) frozen(item);
    Object.freeze(value);
  }
  return value;
}

function copy<T>(value: T): T {
  return structuredClone(value);
}

function address(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Address required");
  const result = getAddress(value) as Address;
  if (!zero && result === ZERO_ADDRESS) throw Error("Nonzero address required");
  return result;
}

function bytes(value: unknown, limit = MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > limit) {
    throw Error("Canonical bounded bytes required");
  }
  return value.toLowerCase() as Hex;
}

function hash(value: unknown, zero = false): Hex {
  const result = bytes(value, 32);
  if (!isHexString(result, 32) || (!zero && result === ZERO)) throw Error("bytes32 required");
  return result;
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error("Unsigned bigint required");
  return value;
}

function index(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw Error("Concrete nonnegative safe block/index required");
  return value;
}

function stable(value: any): string {
  if (typeof value === "bigint") return `bigint:${value}`;
  if (typeof value === "string") return /^0x[0-9a-f]*$/i.test(value) ? value.toLowerCase() : JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map(k => `${k}:${stable(value[k])}`).join(",")}}`;
  return JSON.stringify(value);
}

function equal(actual: unknown, expected: unknown, label: string): void {
  if (stable(actual) !== stable(expected)) throw Error(`${label} mismatch`);
}

function pinInput(value: CanonicalNativeSalesCodePin): CanonicalNativeSalesCodePin {
  return frozen({ address: address(value.address), codeHash: hash(value.codeHash) });
}

function deployment(value: CanonicalNativeSalesDeployment): CanonicalNativeSalesDeployment {
  const input = copy(value);
  if (input.family !== "immediate" && input.family !== "claim") throw Error("Unknown canonical family");
  if (!Array.isArray(input.linkedDependencies) || input.linkedDependencies.length > 256) throw Error("Linked dependency bound");
  return frozen({
    chainId: uint(input.chainId),
    family: input.family,
    adapter: pinInput(input.adapter),
    core: pinInput(input.core),
    manager: pinInput(input.manager),
    ledger: pinInput(input.ledger),
    recorder: pinInput(input.recorder),
    linkedDependencies: input.linkedDependencies.map(pinInput),
  });
}

async function block(provider: Reader, tag: number): Promise<CanonicalNativeSalesBlock> {
  const result = await provider.getBlock(index(tag));
  if (!result || result.number !== tag) throw Error("Concrete block unavailable");
  return frozen({ blockNumber: tag, blockHash: hash(result.hash), timestamp: uint(BigInt(result.timestamp), 64) });
}

async function unchanged(provider: Reader, observed: CanonicalNativeSalesBlock): Promise<void> {
  equal(await block(provider, observed.blockNumber), observed, "Pinned block/reorg");
}

async function pin(provider: Reader, input: CanonicalNativeSalesCodePin, tag: number): Promise<void> {
  const code = bytes(await provider.getCode(input.address, tag), 131072);
  if (code === "0x" || /^0xef0100[0-9a-f]{40}$/.test(code) || keccak256(code) !== input.codeHash) {
    throw Error(`Runtime pin mismatch: ${input.address}`);
  }
}

function plain(type: ParamType, value: any): any {
  if (type.baseType === "array") return Array.from(value, item => plain(type.arrayChildren!, item));
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map((field, i) => [field.name, plain(field, value[i])]));
  if (type.type === "address") return address(value, true);
  return typeof value === "string" && value.startsWith("0x") ? value.toLowerCase() : value;
}

async function rpc(
  provider: Reader,
  target: Address,
  iface: Interface,
  method: string,
  args: readonly unknown[],
  tag: number,
  from?: Address,
): Promise<any[]> {
  const raw = bytes(await provider.call({ to: target, ...(from === undefined ? {} : { from }), data: iface.encodeFunctionData(method, args), blockTag: tag }));
  const decoded = iface.decodeFunctionResult(method, raw);
  equal(iface.encodeFunctionResult(method, decoded), raw, `Canonical ${method} return`);
  return iface.getFunction(method)!.outputs.map((field, i) => plain(field, decoded[i]));
}

function gas(value: bigint): bigint {
  if (uint(value) === 0n || value > 100_000_000n) throw Error("Explicit simulation gas must be 1..100000000");
  return value;
}

function read(
  provider: Reader,
  target: Address,
  method: string,
  args: readonly unknown[],
  tag: number,
  from?: Address,
) {
  return rpc(provider, target, abi, method, args, tag, from);
}

function saleRecord(record: sales.CanonicalNativeSalesRecord | sales.CanonicalNativeClaimRecord) {
  return "sale" in record ? record.sale : record;
}

function purchaseOf(prepared: sales.CanonicalNativeSalesCall): sales.CanonicalNativeSalesPurchase {
  const request = prepared.request;
  if (request.kind !== "purchaseSigned" && request.kind !== "purchasePublic") throw Error("Purchase required");
  return request.family === "claim" ? request.purchase.mint : request.purchase;
}

async function addDependency(
  provider: Reader,
  dependencies: CanonicalNativeSalesCodePin[],
  input: CanonicalNativeSalesCodePin,
  tag: number,
): Promise<void> {
  const value = pinInput(input);
  const existing = dependencies.find(item => item.address === value.address);
  if (existing) equal(existing, value, "Conflicting dependency pin");
  else {
    await pin(provider, value, tag);
    dependencies.push(value);
  }
}

async function binding(
  provider: Reader,
  dependencies: CanonicalNativeSalesCodePin[],
  target: Address,
  addressGetter: string,
  hashGetter: string,
  tag: number,
): Promise<CanonicalNativeSalesCodePin> {
  const [targetAddress] = await read(provider, target, addressGetter, [], tag);
  const [codeHash] = await read(provider, target, hashGetter, [], tag);
  const result = pinInput({ address: targetAddress, codeHash });
  await addDependency(provider, dependencies, result, tag);
  return result;
}

async function managerBindings(
  provider: Reader,
  d: CanonicalNativeSalesDeployment,
  tag: number,
): Promise<void> {
  await pin(provider, d.manager, tag);
  await pin(provider, d.ledger, tag);
  equal((await read(provider, d.manager.address, "core", [], tag))[0], d.core.address, "Manager Core binding");
  equal((await read(provider, d.manager.address, "mintLedger", [], tag))[0], d.ledger.address, "Manager Ledger binding");
}

async function purchaseContext(
  provider: Reader,
  d: CanonicalNativeSalesDeployment,
  tag: number,
): Promise<CanonicalNativeSalesCodePin[]> {
  const dependencies: CanonicalNativeSalesCodePin[] = [];
  await managerBindings(provider, d, tag);
  for (const p of [d.adapter, d.core, d.manager, d.ledger, d.recorder, ...d.linkedDependencies]) {
    await addDependency(provider, dependencies, p, tag);
  }
  for (const [addressGetter, hashGetter, expected] of [
    ["core", "coreCodeHash", d.core],
    ["mintManager", "mintManagerCodeHash", d.manager],
    ["primarySaleSettlement", "settlementCodeHash", d.recorder],
  ] as const) equal(await binding(provider, dependencies, d.adapter.address, addressGetter, hashGetter, tag), expected, addressGetter);
  const registry = await binding(provider, dependencies, d.adapter.address, "moduleRegistry", "moduleRegistryCodeHash", tag);
  const resolver = await binding(provider, dependencies, d.adapter.address, "revenueResolver", "resolverCodeHash", tag);
  const factory = await binding(provider, dependencies, d.adapter.address, "splitFactory", "factoryCodeHash", tag);
  const assets = await binding(provider, dependencies, d.adapter.address, "assetPolicyRegistry", "assetRegistryCodeHash", tag);
  const artist = await binding(provider, dependencies, d.adapter.address, "artistRegistry", "artistRegistryCodeHash", tag);
  equal((await read(provider, d.manager.address, "moduleRegistry", [], tag))[0], registry.address, "Manager registry");
  for (const target of [d.recorder.address, resolver.address]) {
    equal((await read(provider, target, "core", [], tag))[0], d.core.address, "Dependency Core");
  }
  for (const [method, expected] of [
    ["moduleRegistry", registry.address],
    ["revenueResolver", resolver.address],
    ["splitFactory", factory.address],
    ["assetPolicyRegistry", assets.address],
  ] as const) equal((await read(provider, d.recorder.address, method, [], tag))[0], expected, `Recorder ${method}`);
  equal((await read(provider, resolver.address, "artistRegistry", [], tag))[0], artist.address, "Resolver Artist");
  const pointer = await read(provider, d.core.address, "getSatellitePointer", [id("ARTIST_REGISTRY")], tag);
  equal(pointer.slice(0, 2), [artist.address, artist.codeHash], "Current Artist pointer");
  const modulePointer = await read(provider, d.core.address, "getSatellitePointer", [id("MODULE_REGISTRY")], tag);
  equal(modulePointer.slice(0, 2), [registry.address, registry.codeHash], "Current ModuleRegistry pointer");
  await binding(provider, dependencies, d.recorder.address, "revenueEscrow", "escrowCodeHash", tag);
  return dependencies;
}

const NATIVE_BINDING_ID = `0x${[
  "core()", "mintManager()", "nativeSaleLifecycleBinding(bytes32)", "primarySaleSettlement()",
].reduce((result, signature) => result ^ BigInt(id(signature).slice(0, 10)), 0n).toString(16).padStart(8, "0")}`;

async function admission(
  provider: Reader,
  d: CanonicalNativeSalesDeployment,
  record: sales.CanonicalNativeSalesRecord,
  observed: CanonicalNativeSalesBlock,
): Promise<CanonicalNativeSalesAdmission> {
  const [registry] = await read(provider, d.adapter.address, "moduleRegistry", [], observed.blockNumber);
  const [row] = await read(provider, registry, "moduleRecord", [d.adapter.address], observed.blockNumber);
  equal([row.moduleType, row.moduleVersion, row.interfaceId, row.runtimeCodeHash],
    [id("NATIVE_PRIMARY_SALE_ADAPTER"), id("6529STREAM_UNIVERSAL_SETTLEMENT_V1"), NATIVE_BINDING_ID, d.adapter.codeHash], "Original native registry row");
  hash(row.moduleManifestHash);
  hash(row.deploymentManifestHash);
  const lifecycle = record.lifecycle;
  if (![1n, 2n].includes(row.status) || row.registeredAt === 0n || row.registeredAt > observed.timestamp
    || row.statusUpdatedAt < row.registeredAt || row.statusUpdatedAt > observed.timestamp || row.revision === 0n
    || lifecycle.saleCreatedAt < row.registeredAt || lifecycle.saleCreatedAt > observed.timestamp
    || lifecycle.saleAdapterRegistryRevision === 0n || lifecycle.saleAdapterRegistryRevision > row.revision
    || (row.status === 2n && (lifecycle.saleCreatedAt >= row.statusUpdatedAt || lifecycle.saleAdapterRegistryRevision >= row.revision))) {
    throw Error("Original native ACTIVE/DEPRECATED admission mismatch");
  }
  equal((await read(provider, d.adapter.address, "supportsInterface", [NATIVE_BINDING_ID], observed.blockNumber))[0], true, "Native binding capability");
  return frozen({ status: row.status, registeredAt: row.registeredAt, statusUpdatedAt: row.statusUpdatedAt, revision: row.revision });
}

async function reveal(
  provider: Reader,
  d: CanonicalNativeSalesDeployment,
  iface: Interface,
  saleId: Hex,
  collectionId: bigint,
  dependencies: CanonicalNativeSalesCodePin[],
  tag: number,
): Promise<CanonicalNativeSalesReveal> {
  const [quote] = await rpc(provider, d.adapter.address, iface, "saleRevealQuote", [saleId], tag);
  await addDependency(provider, dependencies, { address: quote.coordinator, codeHash: quote.coordinatorCodeHash }, tag);
  const pointer = await read(provider, d.core.address, "getSatellitePointer", [id("ENTROPY_COORDINATOR")], tag);
  equal(pointer.slice(0, 2), [quote.coordinator, quote.coordinatorCodeHash], "Reveal coordinator pointer");
  equal((await read(provider, quote.coordinator, "core", [], tag))[0], d.core.address, "Reveal Core");
  let supported = false;
  try {
    const response = bytes(await provider.call({
      to: quote.coordinator,
      data: abi.encodeFunctionData("supportsInterface", [ENTROPY_COLLECTION_POLICY_INTERFACE_ID]),
      blockTag: tag,
    }), 4096);
    if (response !== "0x") {
      if (response.length !== 66 || BigInt(response) > 1n) throw Error("Malformed entropy capability observation");
      supported = BigInt(response) === 1n;
    }
  } catch (error: any) {
    if (error?.code !== "CALL_EXCEPTION") throw error;
  }
  const policy: EntropyCollectionPolicyRecord | null = supported
    ? (await read(provider, quote.coordinator, "collectionEntropyPolicy", [collectionId], tag))[0]
    : null;
  if (!quote.policy.declared) {
    equal(quote.policy, { declared: false, requestMode: 0n, revealOwnerRole: ZERO, requestSLOBlocks: 0n, revealFeePerTokenWei: 0n }, "Undeclared canonical reveal policy");
    if (!policy?.explicitPolicy || policy.mode === 2n) throw Error("Undeclared reveal needs explicit DISABLED/INSTANT policy");
  }
  return frozen({ quote, collectionPolicy: policy, directPolicyProbe: "direct-observation-no-nested-gas-equivalence" });
}

async function counters(
  provider: Reader,
  d: CanonicalNativeSalesDeployment,
  config: sales.CanonicalNativeSalesConfiguration,
  tag: number,
): Promise<sales.CanonicalNativeSalesCounterObservation[]> {
  const [ids] = await read(provider, d.manager.address, "phaseCounterIds", [config.collectionId, config.phaseId], tag);
  if (ids.length > 16 || new Set(ids).size !== ids.length) throw Error("Complete ordered phase counter bound");
  const result: sales.CanonicalNativeSalesCounterObservation[] = [];
  for (const counterId of ids) {
    const [counter] = await read(provider, d.manager.address, "counterConfig", [config.collectionId, config.phaseId, counterId], tag);
    const [exists, definition] = counter.capMode === 3n
      ? await read(provider, d.ledger.address, "counterDefinitionForManager", [d.manager.address, counter.counterConfigHash], tag)
      : [false, { scope: 0n, keyMode: 0n, capRoot: ZERO, metadataHash: ZERO }];
    result.push({ counterId, config: counter, definitionExists: exists, definition });
  }
  return result;
}

async function recordAt(
  provider: Reader,
  d: CanonicalNativeSalesDeployment,
  saleId: Hex,
  tag: number,
) {
  const iface = sales.canonicalNativeSalesInterface(d.family);
  const [record] = await rpc(provider, d.adapter.address, iface, "saleRecord", [saleId], tag);
  return d.family === "immediate"
    ? sales.normalizeCanonicalNativeSalesRecord(record)
    : sales.normalizeCanonicalNativeSalesClaimRecord(record);
}

function captureBody(value: Omit<CanonicalNativeSalesCapture, "captureHash"> | CanonicalNativeSalesCapture) {
  const { captureHash: _hash, ...body } = value as CanonicalNativeSalesCapture;
  return body;
}

function captureDigest(value: Omit<CanonicalNativeSalesCapture, "captureHash"> | CanonicalNativeSalesCapture): Hex {
  return keccak256(toUtf8Bytes(stable(captureBody(value)))) as Hex;
}

export async function captureCanonicalNativeSales(
  provider: Reader,
  deploymentInput: CanonicalNativeSalesDeployment,
  preparedInput: sales.CanonicalNativeSalesCall,
  options: { readonly blockTag: number },
): Promise<CanonicalNativeSalesCapture> {
  const d = deployment(deploymentInput);
  const prepared = sales.normalizeCanonicalNativeSalesCall(preparedInput);
  const tag = index(options.blockTag);
  equal(prepared.coordinates, {
    chainId: d.chainId,
    adapter: d.adapter.address,
    manager: d.manager.address,
    ledger: d.ledger.address,
    recorder: d.recorder.address,
  }, "Prepared deployment coordinates");
  equal(prepared.request.family, d.family, "Prepared family");
  const observed = await block(provider, tag);
  equal((await provider.getNetwork()).chainId, d.chainId, "Deployment chain");
  await pin(provider, d.adapter, tag);
  const iface = sales.canonicalNativeSalesInterface(d.family);
  const request = prepared.request;
  let record: CanonicalNativeSalesCapture["record"] = null;
  let candidate: CanonicalNativeSalesCapture["candidate"] = null;
  let authorizationId: Hex | null = null;
  let revealObservation: CanonicalNativeSalesReveal | null = null;
  let admitted: CanonicalNativeSalesAdmission | null = null;
  let floorPin: CanonicalNativeSalesCodePin | null = null;
  let counterObservations: sales.CanonicalNativeSalesCounterObservation[] = [];
  let dependencies: CanonicalNativeSalesCodePin[] = [d.adapter];
  const adapterBalance = uint(await provider.getBalance(d.adapter.address, tag));
  let refundCredit = 0n;
  let refundLiability = 0n;

  if (request.kind === "claimRefund") {
    [refundCredit] = await rpc(provider, d.adapter.address, iface, "refundableBalance", [request.saleId, prepared.caller], tag);
    [refundLiability] = await rpc(provider, d.adapter.address, iface, "refundLiability", [], tag);
    if (refundCredit === 0n || refundCredit > refundLiability || adapterBalance < refundLiability) throw Error("Refund credit/liability unavailable");
  } else if (request.kind === "voidMintImmediateSaleAuthorization") {
    await managerBindings(provider, d, tag);
    dependencies = [d.adapter, d.manager, d.ledger];
    const a = request.authorization;
    const binding = await read(provider, d.adapter.address, "immediateSaleAuthorizationBinding", [a.saleId], tag);
    equal([binding[0], binding[1], binding[2], binding[3], binding[5], binding[6]],
      [a.collectionId, a.phaseId, a.saleKind, 1n, request.authorizer, request.authorizerKind], "Historical signed authorization binding");
    hash(binding[4]);
    authorizationId = sales.canonicalNativeSalesAuthorizationId(prepared.coordinates, a);
    equal((await read(provider, d.manager.address, "mintSaleAuthorizationId", [a], tag))[0], authorizationId, "Original Manager authorization ID");
    equal((await read(provider, d.ledger.address, "isManagerAuthorizationUsed", [d.manager.address, authorizationId], tag))[0], false, "Unconsumed revocation");
  } else {
    const p = purchaseOf(prepared);
    equal([p.payer, p.executor], [prepared.caller, prepared.caller], "Literal purchase caller");
    dependencies = await purchaseContext(provider, d, tag);
    record = await recordAt(provider, d, p.saleId, tag);
    const base = saleRecord(record);
    if (base.saleNonce === 0n) throw Error("Unknown sale");
    const config = base.config;
    equal((await rpc(provider, d.adapter.address, iface, "saleConfigurationHash", [d.family === "claim" ? { sale: config, maxUnitPrice: (record as sales.CanonicalNativeClaimRecord).maxUnitPrice } : config], tag))[0], base.configHash, "Retained config hash");
    equal((await rpc(provider, d.adapter.address, iface, "nextExecutionNonce", [p.saleId, p.payer], tag))[0], p.executionNonce, "Next execution nonce");
    const method = request.kind === "purchaseSigned" ? "previewSignedPurchase" : "previewPublicPurchase";
    const args = request.kind === "purchaseSigned"
      ? [request.purchase, request.authorization, request.signature]
      : [request.purchase];
    const preview = await rpc(provider, d.adapter.address, iface, method, args, tag, prepared.caller);
    candidate = sales.normalizeCanonicalNativeSalesCandidate(preview[0]);
    const batch = sales.canonicalNativeSalesMintBatch(prepared, record);
    authorizationId = batch.authorizationId;
    const authorizationDigest = request.kind === "purchaseSigned"
      ? sales.canonicalNativeSalesAuthorizationPayload(prepared.coordinates, request.authorization).digest
      : ZERO;
    if (request.kind === "purchaseSigned") {
      equal(await read(provider, d.adapter.address, "eip712Domain", [], tag),
        ["0x0f", "6529Stream Sales", "1", d.chainId, d.adapter.address, ZERO, []], "Original Sales-v1 signing domain");
      equal((await read(provider, d.adapter.address, "authorizationDigest", [request.authorization], tag))[0], authorizationDigest, "Original signed digest getter");
    }
    equal(candidate.executionBinding, {
      executionId: candidate.executionBinding.executionId,
      executionNonce: p.executionNonce,
      authorityMode: config.authorityMode,
      saleAuthorizationDigest: authorizationDigest,
    }, "Original execution authority binding");
    equal(candidate.saleExecutionHash,
      sales.canonicalNativeSalesExecutionHash(d.family, batch.contextHash, authorizationDigest, authorizationId),
      "Original sale execution hash");
    equal([candidate.orchestrationOrder, candidate.sale.revenueClass, candidate.sale.policyMode,
      candidate.sale.tokenId, candidate.sale.poster, candidate.sale.expectedPrimaryPolicyHash],
    [1n, id("PRIMARY_SALE"), 0n, 0n, ZERO_ADDRESS, config.expectedPrimaryPolicyHash], "Original sale candidate fields");
    if (request.kind === "purchasePublic") equal(preview[1], authorizationId, "Public original authorization ID");
    const managerPreview = await read(provider, d.manager.address, "previewSingleStepMintOperation", [batch, "0x"], tag, d.adapter.address);
    equal(managerPreview, [candidate.operationIdentityCommitment, [candidate.operationId]], "Original Manager preview from adapter");
    equal([candidate.saleAdapter, candidate.executor, candidate.mintManager, candidate.sale.settlementId, candidate.sale.collectionId,
      candidate.sale.payer, candidate.sale.beneficiary, candidate.sale.saleNonce, candidate.boundPolicyHash, candidate.lifecycleBinding],
    [d.adapter.address, prepared.caller, d.manager.address, p.saleId, config.collectionId, p.payer, p.beneficiary, base.saleNonce, config.mintPolicyHash, base.lifecycle], "Candidate source joins");
    equal(candidate.currentPolicyHash, (await read(provider, d.manager.address, "phasePolicyHash", [config.collectionId, config.phaseId], tag))[0], "Observed current policy");
    equal(candidate.executionBinding.executionId, sales.canonicalNativeSalesExecutionId(d.chainId, candidate), "Original execution ID");
    equal((await rpc(provider, d.adapter.address, iface, "executionStatus", [candidate.executionBinding.executionId], tag))[0], 0n, "Fresh execution");
    equal((await read(provider, d.ledger.address, "isManagerAuthorizationUsed", [d.manager.address, authorizationId], tag))[0], false, "Authorization replay");
    equal((await read(provider, d.ledger.address, "isManagerOperationRootUsed", [d.manager.address, candidate.operationIdentityCommitment], tag))[0], false, "Operation replay");
    counterObservations = await counters(provider, d, config, tag);
    const override = sales.canonicalNativeSalesAllowlistPrice(prepared.coordinates, config, p, counterObservations);
    const price = sales.canonicalNativeSalesPrice(d.family,
      d.family === "claim" ? { sale: config, maxUnitPrice: (record as sales.CanonicalNativeClaimRecord).maxUnitPrice } : config,
      request.purchase, request.kind === "purchaseSigned" ? request.authorization.unitPrice : null, override);
    equal(candidate.sale.amount, price.amount, "Original authenticated price");
    if (price.amount === 0n) equal(candidate.rights,
      { profileId: ZERO, wallet: ZERO_ADDRESS, templateId: ZERO, assignmentHash: ZERO, entriesHash: ZERO },
      "Zero claim has no paid rights");
    else {
      hash(candidate.rights.profileId);
      address(candidate.rights.wallet);
      hash(candidate.rights.entriesHash);
    }
    admitted = await admission(provider, d, base, observed);
    revealObservation = await reveal(provider, d, iface, p.saleId, config.collectionId, dependencies, tag);
    const fee = revealObservation.quote.policy.revealFeePerTokenWei;
    if (prepared.call.value < price.amount + fee
      || (!revealObservation.quote.policy.declared && prepared.call.value !== price.amount)) throw Error("Native purchase value/reveal allowance");
    [refundCredit] = await rpc(provider, d.adapter.address, iface, "refundableBalance", [p.saleId, p.payer], tag);
    [refundLiability] = await rpc(provider, d.adapter.address, iface, "refundLiability", [], tag);
    if (price.amount !== 0n) {
      const [target, codeHash] = await read(provider, d.core.address, "conservationFloor", [], tag);
      floorPin = pinInput({ address: target, codeHash });
      await addDependency(provider, dependencies, floorPin, tag);
    }
  }
  await unchanged(provider, observed);
  const body = frozen({ deployment: d, prepared, observed, record, candidate, authorizationId,
    reveal: revealObservation, admission: admitted, floor: floorPin, counters: counterObservations,
    dependencies, refundCredit, refundLiability, adapterBalance,
    admissionAuthority: "original-adapter-or-manager-call-simulation" as const });
  return frozen({ ...body, captureHash: captureDigest(body) });
}

function normalizeCapture(input: CanonicalNativeSalesCapture): CanonicalNativeSalesCapture {
  const cloned = copy(input);
  const result = { ...cloned, deployment: deployment(cloned.deployment), prepared: sales.normalizeCanonicalNativeSalesCall(cloned.prepared) };
  equal(captureDigest(result), result.captureHash, "Captured immutable facts");
  return frozen(result);
}

async function validateCapture(provider: Reader, capture: CanonicalNativeSalesCapture): Promise<void> {
  const current = await captureCanonicalNativeSales(provider, capture.deployment, capture.prepared, { blockTag: capture.observed.blockNumber });
  equal(current, capture, "Historical capture reconstruction");
}

export interface CanonicalNativeSalesSimulation {
  readonly capture: CanonicalNativeSalesCapture;
  readonly returnData: Hex;
  readonly receipt: sales.CanonicalNativeSalesReceipt | null;
  readonly authorizationId: Hex | null;
}

export async function simulateCanonicalNativeSales(
  provider: Reader,
  input: CanonicalNativeSalesCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<CanonicalNativeSalesSimulation> {
  const saved = normalizeCapture(input);
  const tag = index(options.blockTag);
  const gasLimit = gas(options.gasLimit);
  if (tag < saved.observed.blockNumber) throw Error("Simulation predates capture");
  await validateCapture(provider, saved);
  const current = await captureCanonicalNativeSales(provider, saved.deployment, saved.prepared, { blockTag: tag });
  const p = current.prepared;
  const raw = bytes(await provider.call({ ...p.call, from: p.caller, gasLimit, blockTag: tag }));
  let receipt: sales.CanonicalNativeSalesReceipt | null = null;
  const iface = p.request.kind === "voidMintImmediateSaleAuthorization"
    ? new Interface(sales.CURRENT_CANONICAL_NATIVE_SALES_REVOCATION_ABI)
    : sales.canonicalNativeSalesInterface(p.request.family);
  const decoded = iface.decodeFunctionResult(p.request.kind, raw);
  equal(iface.encodeFunctionResult(p.request.kind, decoded), raw, "Original simulation return");
  if (p.request.kind === "purchaseSigned" || p.request.kind === "purchasePublic") {
    receipt = sales.normalizeCanonicalNativeSalesReceipt(plain(iface.getFunction(p.request.kind)!.outputs[0]!, decoded[0]));
    expectedReceipt(current, receipt);
  } else if (p.request.kind === "voidMintImmediateSaleAuthorization") {
    equal(decoded[0], current.authorizationId, "Simulated revoked ID");
  }
  await unchanged(provider, current.observed);
  return frozen({ capture: current, returnData: raw, receipt, authorizationId: current.authorizationId });
}

function expectedReceipt(capture: CanonicalNativeSalesCapture, receipt: sales.CanonicalNativeSalesReceipt): void {
  const candidate = capture.candidate!;
  const c = capture.prepared.coordinates;
  const price = candidate.sale.amount;
  const fee = capture.reveal!.quote.policy.revealFeePerTokenWei;
  const settlementKey = price === 0n ? ZERO : sales.canonicalNativeSalesSettlementKey(c.chainId, c.recorder, c.adapter, candidate.executionBinding.executionId);
  equal({ ...receipt, tokenId: 0n }, {
    saleId: candidate.sale.settlementId,
    executionId: candidate.executionBinding.executionId,
    authorizationId: capture.authorizationId,
    saleAuthorizationDigest: candidate.executionBinding.saleAuthorizationDigest,
    operationRoot: candidate.operationIdentityCommitment,
    operationId: candidate.operationId,
    tokenId: 0n,
    settlementKey,
    chargedAmount: price,
    revealFee: fee,
    revealCredit: capture.prepared.call.value - price - fee,
  }, "Typed canonical purchase receipt");
  if (receipt.tokenId === 0n) throw Error("Minted token ID required");
}

export interface CanonicalNativeSalesHistory {
  readonly deployment: CanonicalNativeSalesDeployment;
  readonly observed: CanonicalNativeSalesBlock;
  readonly record: sales.CanonicalNativeSalesRecord | sales.CanonicalNativeClaimRecord;
  readonly receipt: sales.CanonicalNativeSalesReceipt | null;
  readonly status: bigint | null;
}

/** Local immutable sale/execution evidence; does not re-admit current commerce dependencies. */
export async function inspectCanonicalNativeSales(
  provider: Reader,
  deploymentInput: CanonicalNativeSalesDeployment,
  query: { readonly saleId: Hex; readonly executionId?: Hex },
  options: { readonly blockTag: number },
): Promise<CanonicalNativeSalesHistory> {
  const d = deployment(deploymentInput);
  const saleId = hash(query.saleId, true);
  const executionId = query.executionId === undefined ? null : hash(query.executionId, true);
  const tag = index(options.blockTag);
  const observed = await block(provider, tag);
  equal((await provider.getNetwork()).chainId, d.chainId, "History chain");
  await pin(provider, d.adapter, tag);
  const record = await recordAt(provider, d, saleId, tag);
  let receipt: sales.CanonicalNativeSalesReceipt | null = null;
  let status: bigint | null = null;
  if (executionId !== null) {
    const iface = sales.canonicalNativeSalesInterface(d.family);
    [status] = await rpc(provider, d.adapter.address, iface, "executionStatus", [executionId], tag);
    const [value] = await rpc(provider, d.adapter.address, iface, "executionReceipt", [executionId], tag);
    receipt = sales.normalizeCanonicalNativeSalesReceipt(value);
    if (status === 0n) {
      equal(sales.encodeCanonicalNativeSalesReceipt(receipt), `0x${"00".repeat(352)}`, "Empty receipt");
    } else {
      if (status !== 1n && status !== 2n) throw Error("Unknown execution status");
      equal([receipt.saleId, receipt.executionId], [saleId, executionId], "Historical receipt key");
      if (status === 2n && receipt.tokenId === 0n) throw Error("Completed receipt token missing");
      if (receipt.chargedAmount === 0n && receipt.settlementKey !== ZERO) throw Error("Free receipt has paid settlement key");
    }
  }
  await unchanged(provider, observed);
  return frozen({ deployment: d, observed, record, receipt, status });
}

export type CanonicalNativeSalesReceiptOptions =
  | {
    readonly execution: "direct";
    readonly releaseKey?: Hex;
  }
  | {
    readonly execution: "safe";
    readonly expectedSafeTxHash: Hex;
    readonly releaseKey?: Hex;
  };

interface ReceiptLog {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}

interface Transport {
  readonly transactionHash: Hex;
  readonly observed: CanonicalNativeSalesBlock;
  readonly logs: readonly ReceiptLog[];
  readonly safeIndex: number | null;
}

async function transport(
  provider: ReceiptReader,
  prepared: sales.CanonicalNativeSalesCall,
  transactionHash: Hex,
  inputOptions: CanonicalNativeSalesReceiptOptions,
): Promise<Transport> {
  const txHash = hash(transactionHash);
  const options = copy(inputOptions);
  if (options.execution !== "direct" && options.execution !== "safe") throw Error("Unknown receipt transport");
  const expectedSafeTxHash = options.execution === "safe" ? hash(options.expectedSafeTxHash) : null;
  const rawReceipt = await provider.getTransactionReceipt(txHash);
  if (!rawReceipt || rawReceipt.status !== 1 || hash(rawReceipt.hash) !== txHash) throw Error("Successful exact receipt required");
  const tag = index(rawReceipt.blockNumber);
  const receiptHash = hash(rawReceipt.blockHash);
  const receiptFrom = address(rawReceipt.from);
  const receiptTo = rawReceipt.to && address(rawReceipt.to);
  if (rawReceipt.logs.length > 4096) throw Error("Receipt log bound");
  let previous = -1;
  let size = 0;
  const logs = rawReceipt.logs.map(raw => {
    const i = index(raw.index);
    if (raw.removed !== false || i <= previous || hash(raw.transactionHash) !== txHash
      || hash(raw.blockHash) !== receiptHash || raw.blockNumber !== tag) throw Error("Receipt log identity/order differs");
    previous = i;
    if (raw.topics.length > 4) throw Error("Topic bound");
    const data = bytes(raw.data);
    size += (data.length - 2) / 2;
    if (size > 4 * MAX_BYTES) throw Error("Aggregate receipt byte bound");
    return frozen({ address: address(raw.address), topics: raw.topics.map(t => hash(t, true)), data, index: i });
  });
  const rawTx = await provider.getTransaction(txHash);
  if (!rawTx) throw Error("Transaction unavailable");
  const tx = {
    to: rawTx.to && address(rawTx.to),
    from: address(rawTx.from),
    value: uint(rawTx.value),
    data: bytes(rawTx.data, MAX_BYTES + 16384),
    hash: hash(rawTx.hash),
    blockNumber: rawTx.blockNumber,
    blockHash: rawTx.blockHash && hash(rawTx.blockHash),
    chainId: rawTx.chainId,
  };
  if (tx.hash !== txHash || tx.blockNumber !== tag || tx.blockHash !== receiptHash) throw Error("Transaction identity differs");
  equal([receiptFrom, receiptTo], [tx.from, tx.to], "Receipt transaction endpoints");
  let safeIndex: number | null = null;
  const call = prepared.call;
  const caller = prepared.caller;
  if (options.execution === "direct") {
    equal([tx.to, tx.from, tx.value, tx.data], [call.to, caller, call.value, call.data], "Direct original call");
  } else {
    equal([tx.to, tx.value], [caller, 0n], "Safe caller and zero outer funding profile");
    const decoded = safeAbi.decodeFunctionData("execTransaction", tx.data);
    equal(safeAbi.encodeFunctionData("execTransaction", decoded), tx.data, "Canonical Safe calldata");
    equal([decoded[0], decoded[1], decoded[2], decoded[3]], [call.to, call.value, call.data, 0n], "Exact Safe CALL");
    const executionLogs = logs.filter(log => log.address === caller
      && [id("ExecutionSuccess(bytes32,uint256)"), id("ExecutionFailure(bytes32,uint256)")].includes(log.topics[0]!));
    if (executionLogs.length !== 1) throw Error("Expected one Safe terminal event");
    requireSafeExecution({ status: 1, logs: logs.map(log => ({ address: log.address, topics: [...log.topics], data: log.data })) }, caller, expectedSafeTxHash!);
    safeIndex = executionLogs[0]!.index;
  }
  const observed = await block(provider, tag);
  equal(observed.blockHash, receiptHash, "Mined block");
  equal([tx.chainId, (await provider.getNetwork()).chainId], [prepared.coordinates.chainId, prepared.coordinates.chainId], "Transaction chain");
  return frozen({ transactionHash: txHash, observed, logs, safeIndex });
}

function events(t: Transport, target: Address, iface: Interface, name: string) {
  const event = iface.getEvent(name)!;
  return t.logs.filter(log => log.address === target && log.topics[0] === event.topicHash).map(log => {
    const result = iface.decodeEventLog(event, log.data, [...log.topics]);
    const canonical = iface.encodeEventLog(event, result);
    equal([canonical.data, canonical.topics], [log.data, log.topics], "Canonical event");
    return { index: log.index, args: Object.fromEntries(event.inputs.map((field, i) => [field.name, plain(field, result[i])])) };
  });
}

function one(
  t: Transport,
  target: Address,
  iface: Interface,
  name: string,
  expected: Record<string, unknown>,
) {
  const matches = events(t, target, iface, name);
  if (matches.length !== 1) throw Error(`Expected one ${name}`);
  for (const [key, value] of Object.entries(expected)) equal(matches[0]!.args[key], value, `${name}.${key}`);
  return matches[0]!;
}

function ordered(...indices: number[]): void {
  for (let i = 1; i < indices.length; i++) {
    if (indices[i]! <= indices[i - 1]!) throw Error("Required event order mismatch");
  }
}

function finish(t: Transport, last: number): void {
  if (t.safeIndex !== null) ordered(last, t.safeIndex);
}

export interface CanonicalNativeSalesFloorReceipt {
  readonly receiptHash: Hex;
  readonly recorder: Address;
  readonly recorderCodeHash: Hex;
  readonly settlementKey: Hex;
  readonly candidatePayloadHash: Hex;
  readonly candidateCommitment: Hex;
  readonly resultHash: Hex;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly effectiveTier: Hex;
  readonly firstSaleReceiptHash: Hex;
  readonly releaseReceiptHash: Hex;
  readonly recordedAt: bigint;
}

export interface CanonicalNativeSalesSettlement {
  readonly result: sales.CanonicalNativeSalesResult;
  readonly floor: CanonicalNativeSalesFloorReceipt;
  readonly firstSale: floor.DirectConservationFirstSaleReceipt;
  readonly release: floor.DirectConservationReleaseReceipt | null;
}

async function settlement(
  provider: Reader,
  capture: CanonicalNativeSalesCapture,
  t: Transport,
  receipt: sales.CanonicalNativeSalesReceipt,
  releaseKey: Hex | null,
): Promise<{
  value: CanonicalNativeSalesSettlement;
  firstEvent: number;
  lastEvent: number;
}> {
  const d = capture.deployment;
  const n = capture.candidate!;
  const tag = t.observed.blockNumber;
  const target = d.recorder.address;
  const key = receipt.settlementKey;
  await pin(provider, d.recorder, tag);
  await pin(provider, capture.floor!, tag);
  equal((await read(provider, target, "settlementConsumed", [key], tag))[0], true, "Original paid settlement consumed");
  const [resultValue] = await read(provider, target, "settlementResult", [key], tag);
  const result = sales.normalizeCanonicalNativeSalesResult(resultValue);
  equal({ ...result, escrowed: false }, {
    candidateCommitment: sales.canonicalNativeSalesCandidateCommitment(d.chainId, target, n),
    settlementKey: key, profileId: n.rights.profileId, wallet: n.rights.wallet, asset: ZERO_ADDRESS,
    amount: n.sale.amount, executor: n.executor, executionId: n.executionBinding.executionId,
    escrowed: false, operationIdentityCommitment: n.operationIdentityCommitment,
    currentPolicyHash: n.currentPolicyHash, boundPolicyHash: n.boundPolicyHash,
  }, "Full native settlement result");
  const f = capture.floor!.address;
  const [floorReceipt] = await read(provider, f, "settlementReceipt", [key], tag) as [CanonicalNativeSalesFloorReceipt];
  equal([floorReceipt.recorder, floorReceipt.recorderCodeHash, floorReceipt.settlementKey,
    floorReceipt.candidatePayloadHash, floorReceipt.candidateCommitment, floorReceipt.resultHash,
    floorReceipt.collectionId, floorReceipt.tokenId, floorReceipt.recordedAt],
  [target, d.recorder.codeHash, key, sales.canonicalNativeSalesAccountingContextHash(n), result.candidateCommitment,
    keccak256(sales.encodeCanonicalNativeSalesResult(result)), n.sale.collectionId, 0n, t.observed.timestamp], "Original universal floor binding");
  const calculated = keccak256(coder.encode(["bytes32", "uint256", "address", "address", FLOOR_TUPLE],
    [id("6529STREAM_CONSERVATION_SETTLEMENT_RECEIPT_V1"), d.chainId, d.core.address, f, { ...floorReceipt, receiptHash: ZERO }]));
  equal(floorReceipt.receiptHash, calculated, "Original floor receipt hash");
  const floorEvent = one(t, f, abi, "ConservationSettlementRecorded", { settlementKey: key, receiptHash: calculated, receipt: floorReceipt, schemaVersion: 1n });
  const [firstValue] = await read(provider, f, "firstSale", [n.sale.collectionId], tag);
  const firstSale = floor.normalizeDirectConservationFirstSaleReceipt(firstValue);
  const coordinates = { chainId: d.chainId, core: d.core.address, floor: f };
  equal([firstSale.receiptHash, firstSale.collectionId, firstSale.effectiveTier],
    [floorReceipt.firstSaleReceiptHash, n.sale.collectionId, floorReceipt.effectiveTier], "Retained first-sale linkage");
  equal(floor.directConservationFirstSaleReceiptHash(coordinates, firstSale), firstSale.receiptHash, "First-sale hash");
  const firstEvents = events(t, f, abi, "ConservationFirstSaleRecorded");
  const [priorFirst] = await read(provider, f, "firstSale", [n.sale.collectionId], tag - 1);
  const newFirst = priorFirst.receiptHash === ZERO;
  if (newFirst !== (firstEvents.length !== 0)) throw Error("First-sale event/prior receipt mismatch");
  if (!newFirst) equal(priorFirst, firstSale, "Retained immutable first sale");
  let firstIndex = floorEvent.index;
  if (firstEvents.length !== 0) {
    const first = one(t, f, abi, "ConservationFirstSaleRecorded", { collectionId: n.sale.collectionId, receiptHash: firstSale.receiptHash, receipt: firstSale, schemaVersion: 1n });
    ordered(first.index, floorEvent.index);
    firstIndex = first.index;
  }
  let release: floor.DirectConservationReleaseReceipt | null = null;
  const releaseEvents = events(t, f, abi, "ConservationReleaseFloorRecorded");
  if (floorReceipt.releaseReceiptHash !== ZERO) {
    const keyHint = releaseKey ?? (releaseEvents.length === 1 ? hash(releaseEvents[0]!.args.releaseKey) : null);
    if (keyHint === null) throw Error("Retained releaseKey locator required");
    const [releaseValue] = await read(provider, f, "releaseFloorReceipt", [keyHint], tag);
    release = floor.normalizeDirectConservationReleaseReceipt(releaseValue);
    equal([release.receiptHash, release.releaseKey, release.collectionId, release.effectiveTier],
      [floorReceipt.releaseReceiptHash, keyHint, n.sale.collectionId, floorReceipt.effectiveTier], "Retained release linkage");
    equal(floor.directConservationReleaseReceiptHash(coordinates, release), release.receiptHash, "Release hash");
    equal(floor.directConservationReleaseKey(d.chainId, d.core.address, release.collectionId, release.context), keyHint, "Semantic release key");
    const [priorRelease] = await read(provider, f, "releaseFloorReceipt", [keyHint], tag - 1);
    const newRelease = priorRelease.receiptHash === ZERO;
    if (newRelease !== (releaseEvents.length !== 0)) throw Error("Release event/prior receipt mismatch");
    if (!newRelease) equal(priorRelease, release, "Retained immutable release");
    if (releaseEvents.length !== 0) {
      const releaseEvent = one(t, f, abi, "ConservationReleaseFloorRecorded", { releaseKey: keyHint, receiptHash: release.receiptHash, receipt: release, schemaVersion: 1n });
      ordered(releaseEvent.index, floorEvent.index);
      if (firstIndex !== floorEvent.index) ordered(firstIndex, releaseEvent.index);
      else firstIndex = releaseEvent.index;
    }
  } else if (releaseEvents.length !== 0) throw Error("Unexpected release receipt event");
  const tiers = ["MUSEUM_GRADE", "MUSEUM_GRADE_LITE", "CONSERVATION_WAIVED"].map(name => id(name));
  if (!tiers.includes(floorReceipt.effectiveTier) || (floorReceipt.effectiveTier === id("CONSERVATION_WAIVED")) !== (release === null)) throw Error("Paid floor tier/release profile");
  const common = { settlementKey: key, revenueClass: id("PRIMARY_SALE"), profileId: result.profileId, schemaVersion: 1n };
  const settled = one(t, target, abi, "PrimaryRevenueSettled", { ...common, wallet: result.wallet, asset: ZERO_ADDRESS, payer: n.sale.payer,
    amount: n.sale.amount, saleContextHash: keccak256(coder.encode([sales.CANONICAL_NATIVE_SALES_PRIMARY_SALE_TUPLE], [n.sale])),
    policyDrift: false, assignmentType: n.rights.templateId === ZERO ? 1n : 2n });
  const context = one(t, target, abi, "PrimaryRevenueSettlementContext", { ...common, settlementCaller: d.adapter.address,
    settlementId: n.sale.settlementId, policyMode: 0n, collectionId: n.sale.collectionId, tokenId: 0n,
    operationRoot: n.operationIdentityCommitment, operationId: n.operationId, saleNonce: n.sale.saleNonce,
    poster: ZERO_ADDRESS, beneficiary: n.sale.beneficiary, templateId: n.rights.templateId });
  const policy = one(t, target, abi, "PrimaryRevenueSettlementPolicy", { ...common, expectedPrimaryPolicyHash: n.sale.expectedPrimaryPolicyHash,
    resolvedPrimaryPolicyHash: n.sale.expectedPrimaryPolicyHash, resolvedAssignmentHash: n.rights.assignmentHash, templateId: n.rights.templateId });
  const bound = one(t, target, abi, "PrimaryRevenueExecutionBound", { settlementKey: key, saleAdapter: d.adapter.address,
    executionId: receipt.executionId, schemaVersion: 1n, executor: n.executor, paymentAdapter: ZERO_ADDRESS,
    candidateCommitment: result.candidateCommitment, currentPolicyHash: n.currentPolicyHash, boundPolicyHash: n.boundPolicyHash });
  ordered(floorEvent.index, settled.index, context.index, policy.index, bound.index);
  return { value: frozen({ result, floor: floorReceipt, firstSale, release }), firstEvent: firstIndex, lastEvent: bound.index };
}

export interface CanonicalNativeSalesRevealAttempt {
  readonly succeeded: boolean;
  readonly requestKey: Hex;
  readonly providerRequestId: bigint;
  readonly returnDataSize: bigint;
  readonly failurePrefix: Hex;
}

export interface CanonicalNativeSalesReconciliation {
  readonly capture: CanonicalNativeSalesCapture;
  readonly transactionHash: Hex;
  readonly observed: CanonicalNativeSalesBlock;
  readonly purchaseReceipt: sales.CanonicalNativeSalesReceipt | null;
  readonly settlement: CanonicalNativeSalesSettlement | null;
  readonly revealAttempt: CanonicalNativeSalesRevealAttempt | null;
  readonly refundedAmount: bigint | null;
  readonly revokedAuthorizationId: Hex | null;
}

async function purchaseReceipt(
  provider: Reader,
  prior: CanonicalNativeSalesCapture,
  t: Transport,
  releaseKey: Hex | null,
): Promise<Pick<CanonicalNativeSalesReconciliation, "purchaseReceipt" | "settlement" | "revealAttempt">> {
  const d = prior.deployment;
  const p = purchaseOf(prior.prepared);
  const n = prior.candidate!;
  const base = saleRecord(prior.record!);
  const config = base.config;
  if (prior.prepared.request.kind === "purchaseSigned"
    && prior.prepared.request.authorization.deadline < t.observed.timestamp) throw Error("Signed purchase expired at mined timestamp");
  const iface = sales.canonicalNativeSalesInterface(d.family);
  const tag = t.observed.blockNumber;
  for (const dependency of prior.dependencies) await pin(provider, dependency, tag);
  const name = d.family === "immediate" ? "ImmediateSaleExecution" : "ClaimSaleExecution";
  const executions = events(t, d.adapter.address, abi, name);
  if (executions.length !== 2) throw Error("Expected original REQUESTED/completed host receipt pair");
  const first = executions[0]!;
  const final = executions[1]!;
  equal([first.args.status, final.args.status], [1n, 2n], "Host execution status pair");
  const receipt = sales.normalizeCanonicalNativeSalesReceipt(final.args.receipt);
  expectedReceipt(prior, receipt);
  equal([first.args.saleId, first.args.executionId, first.args.operationRoot], [receipt.saleId, receipt.executionId, receipt.operationRoot], "Initial receipt event keys");
  equal([final.args.saleId, final.args.executionId, final.args.operationRoot], [receipt.saleId, receipt.executionId, receipt.operationRoot], "Final receipt event keys");
  equal(first.args.receipt, { ...receipt, tokenId: 0n, settlementKey: ZERO }, "Initial zero-token/zero-settlement receipt");
  const [recordedReceipt] = await rpc(provider, d.adapter.address, iface, "executionReceipt", [receipt.executionId], tag);
  equal(recordedReceipt, receipt, "Immutable adapter receipt readback");
  equal((await rpc(provider, d.adapter.address, iface, "executionStatus", [receipt.executionId], tag))[0], 2n, "Completed adapter execution");
  equal((await rpc(provider, d.adapter.address, iface, "nextExecutionNonce", [p.saleId, p.payer], tag))[0], p.executionNonce + 1n, "Execution nonce advancement");
  if (config.authorityMode === 2n) {
    equal((await rpc(provider, d.adapter.address, iface, "activePublicNativeCandidate", [receipt.executionId], tag))[0], ZERO, "Cleared public candidate");
  }
  const afterRecord = saleRecord(await recordAt(provider, d, p.saleId, tag));
  const sold = base.soldQuantity + 1n;
  const closes = config.saleSupplyLimit !== 0n && sold === config.saleSupplyLimit;
  equal(afterRecord, { ...base, soldQuantity: sold, closed: closes }, "Original sold/cap-close transition");
  const root = one(t, d.ledger.address, abi, "MintLedgerOperationRootConsumed", {
    schemaVersion: 1n, operationRoot: receipt.operationRoot, manager: d.manager.address,
    currentPolicyHash: n.currentPolicyHash, boundPolicyHash: n.boundPolicyHash, authorizationId: receipt.authorizationId,
  });
  const ledgerAuthorization = one(t, d.ledger.address, abi, "MintLedgerAuthorizationConsumed", {
    schemaVersion: 1n, authorizationId: receipt.authorizationId, operationRoot: receipt.operationRoot,
    manager: d.manager.address, boundPolicyHash: n.boundPolicyHash,
  });
  const token = one(t, d.manager.address, abi, "MintTokenExecuted", {
    schemaVersion: 1n, operationId: receipt.operationId, tokenId: receipt.tokenId, operationRoot: receipt.operationRoot,
    collectionId: config.collectionId, phaseId: config.phaseId, tokenIndex: 0n, initialRecipient: p.initialRecipient,
    beneficiary: p.beneficiary, tokenDataHash: keccak256(p.tokenData), mintCommitment: p.mintCommitment,
  });
  const managerAuthorization = one(t, d.manager.address, abi, "MintAuthorizationConsumed", {
    schemaVersion: 1n, collectionId: config.collectionId, phaseId: config.phaseId,
    authorizationId: receipt.authorizationId, boundPolicyHash: n.boundPolicyHash, operationRoot: receipt.operationRoot,
  });
  const batch = sales.canonicalNativeSalesMintBatch(prior.prepared, prior.record!);
  const completed = one(t, d.manager.address, abi, "MintBatchExecuted", {
    schemaVersion: 1n, operationRoot: receipt.operationRoot, collectionId: config.collectionId, phaseId: config.phaseId,
    executor: d.adapter.address, payer: p.payer, authorizer: ZERO_ADDRESS, firstTokenId: receipt.tokenId,
    quantity: 1n, contextHash: batch.contextHash, gateHash: ZERO, currentPolicyHash: n.currentPolicyHash, boundPolicyHash: n.boundPolicyHash,
  });
  ordered(first.index, ledgerAuthorization.index, root.index, token.index, managerAuthorization.index, completed.index, final.index);
  equal((await read(provider, d.ledger.address, "isManagerAuthorizationUsed", [d.manager.address, receipt.authorizationId], tag))[0], true, "Consumed authorization");
  equal((await read(provider, d.ledger.address, "isManagerOperationRootUsed", [d.manager.address, receipt.operationRoot], tag))[0], true, "Consumed operation root");
  const identity = await read(provider, d.core.address, "tokenCollectionIdentity", [receipt.tokenId], tag);
  const [lifecycle] = await read(provider, d.core.address, "tokenLifecycle", [receipt.tokenId], tag);
  if (!identity[0] || identity[1] !== config.collectionId || identity[2] === 0n
    || ![2n, 3n].includes(lifecycle) || identity[3] !== (lifecycle === 3n)) throw Error("Permanent minted token identity mismatch");
  equal((await read(provider, d.core.address, "coordinatorAtMint", [receipt.tokenId], tag))[0], prior.reveal!.quote.coordinator, "Original entropy host");
  let paid: CanonicalNativeSalesSettlement | null = null;
  if (receipt.chargedAmount !== 0n) {
    const result = await settlement(provider, prior, t, receipt, releaseKey);
    paid = result.value;
    ordered(first.index, result.firstEvent, result.lastEvent, ledgerAuthorization.index);
  } else {
    for (const event of ["PrimaryRevenueSettled", "PrimaryRevenueSettlementContext", "PrimaryRevenueSettlementPolicy", "PrimaryRevenueExecutionBound"]) {
      if (events(t, d.recorder.address, abi, event).length !== 0) throw Error("Free claim cannot have official paid settlement events");
    }
  }
  const quote = prior.reveal!.quote;
  const policy = prior.reveal!.collectionPolicy;
  const skipsRequest = policy?.explicitPolicy === true && (policy.mode !== 2n || policy.renderRequirement === 1n);
  const attempts = events(t, d.adapter.address, abi, "ImmediateRevealAttempt");
  const expectsAttempt = !skipsRequest && quote.policy.declared && quote.policy.requestMode === 0n;
  let revealAttempt: CanonicalNativeSalesRevealAttempt | null = null;
  let last = completed.index;
  if (expectsAttempt) {
    const attempt = one(t, d.adapter.address, abi, "ImmediateRevealAttempt", { schemaVersion: 1n, collectionId: config.collectionId, tokenId: receipt.tokenId });
    const a = attempt.args;
    if (a.succeeded) {
      if (a.requestKey === ZERO || a.returnDataSize !== 64n || a.failurePrefix !== "0x") throw Error("Successful reveal attempt shape mismatch");
    } else if (a.requestKey !== ZERO || a.providerRequestId !== 0n
      || BigInt((a.failurePrefix.length - 2) / 2) !== (a.returnDataSize > 256n ? 256n : a.returnDataSize)) throw Error("Failed reveal attempt bounded result mismatch");
    ordered(last, attempt.index, final.index);
    last = attempt.index;
    revealAttempt = frozen({ succeeded: a.succeeded, requestKey: a.requestKey, providerRequestId: a.providerRequestId, returnDataSize: a.returnDataSize, failurePrefix: a.failurePrefix });
  } else if (attempts.length !== 0) throw Error("Unexpected AT_MINT entropy request");
  const excessEvents = events(t, d.adapter.address, abi, "SalePaymentExcessCredited");
  if (receipt.revealCredit !== 0n) {
    const excess = one(t, d.adapter.address, abi, "SalePaymentExcessCredited", { schemaVersion: 1n, saleId: p.saleId, payer: p.payer, amount: receipt.revealCredit });
    ordered(last, excess.index, final.index);
    last = excess.index;
  } else if (excessEvents.length !== 0) throw Error("Zero excess must not emit refund credit");
  equal((await rpc(provider, d.adapter.address, iface, "refundableBalance", [p.saleId, p.payer], tag))[0], prior.refundCredit + receipt.revealCredit, "Payer pull credit");
  equal((await rpc(provider, d.adapter.address, iface, "refundLiability", [], tag))[0], prior.refundLiability + receipt.revealCredit, "Refund liability");
  equal(await provider.getBalance(d.adapter.address, tag), prior.adapterBalance + receipt.revealCredit, "Native retained excess balance");
  if (closes) {
    const close = one(t, d.adapter.address, abi, "ImmediateSaleClosed", { saleId: p.saleId, soldQuantity: sold });
    ordered(last, close.index, final.index);
    last = close.index;
  } else if (events(t, d.adapter.address, abi, "ImmediateSaleClosed").length !== 0) throw Error("Unexpected sale close");
  if (receipt.chargedAmount === 0n) {
    const free = one(t, d.adapter.address, abi, "FreeClaimExecuted", { saleId: p.saleId, executionId: receipt.executionId, tokenId: receipt.tokenId, authorizationId: receipt.authorizationId });
    ordered(last, free.index, final.index);
  } else if (events(t, d.adapter.address, abi, "FreeClaimExecuted").length !== 0) throw Error("Paid sale cannot emit free claim");
  finish(t, final.index);
  return { purchaseReceipt: receipt, settlement: paid, revealAttempt };
}

/** Prior-block and end-block state equality is a conservative receipt attribution profile. */
export async function reconcileCanonicalNativeSalesReceipt(
  provider: ReceiptReader,
  captureInput: CanonicalNativeSalesCapture,
  transactionHash: Hex,
  optionsInput: CanonicalNativeSalesReceiptOptions,
): Promise<CanonicalNativeSalesReconciliation> {
  const saved = normalizeCapture(captureInput);
  const options = copy(optionsInput);
  const releaseKey = options.releaseKey === undefined ? null : hash(options.releaseKey);
  const t = await transport(provider, saved.prepared, transactionHash, options);
  if (t.observed.blockNumber <= saved.observed.blockNumber) throw Error("Receipt must be strictly later than capture");
  await validateCapture(provider, saved);
  const prior = await captureCanonicalNativeSales(provider, saved.deployment, saved.prepared, { blockTag: t.observed.blockNumber - 1 });
  const { observed: _savedBlock, ...savedFacts } = captureBody(saved);
  const { observed: _priorBlock, ...priorFacts } = captureBody(prior);
  equal(priorFacts, savedFacts, "Reviewed prior-block state");
  const d = prior.deployment;
  const request = prior.prepared.request;
  const tag = t.observed.blockNumber;
  await pin(provider, d.adapter, tag);
  let purchase: sales.CanonicalNativeSalesReceipt | null = null;
  let paid: CanonicalNativeSalesSettlement | null = null;
  let attempt: CanonicalNativeSalesRevealAttempt | null = null;
  let refundedAmount: bigint | null = null;
  let revokedAuthorizationId: Hex | null = null;
  if (request.kind === "claimRefund") {
    const event = one(t, d.adapter.address, abi, "SaleRefundClaimed", { schemaVersion: 1n, saleId: request.saleId,
      payer: prior.prepared.caller, recipient: request.recipient, amount: prior.refundCredit });
    const iface = sales.canonicalNativeSalesInterface(d.family);
    equal((await rpc(provider, d.adapter.address, iface, "refundableBalance", [request.saleId, prior.prepared.caller], tag))[0], 0n, "Cleared refund credit");
    equal((await rpc(provider, d.adapter.address, iface, "refundLiability", [], tag))[0], prior.refundLiability - prior.refundCredit, "Reduced refund liability");
    equal(await provider.getBalance(d.adapter.address, tag), prior.adapterBalance - prior.refundCredit, "Exact refund debit");
    refundedAmount = prior.refundCredit;
    finish(t, event.index);
  } else if (request.kind === "voidMintImmediateSaleAuthorization") {
    await managerBindings(provider, d, tag);
    revokedAuthorizationId = prior.authorizationId;
    const ledger = one(t, d.ledger.address, abi, "MintLedgerAuthorizationVoided", { schemaVersion: 1n, authorizationId: revokedAuthorizationId, manager: d.manager.address });
    const manager = one(t, d.manager.address, abi, "MintAuthorizationVoided", { schemaVersion: 1n,
      collectionId: request.authorization.collectionId, phaseId: request.authorization.phaseId,
      authorizationId: revokedAuthorizationId, authorizer: request.authorizer, verifyingContract: d.adapter.address, family: 2n });
    ordered(ledger.index, manager.index);
    equal((await read(provider, d.ledger.address, "isManagerAuthorizationUsed", [d.manager.address, revokedAuthorizationId], tag))[0], true, "Revoked manager-scoped authorization");
    finish(t, manager.index);
  } else {
    const result = await purchaseReceipt(provider, prior, t, releaseKey);
    purchase = result.purchaseReceipt;
    paid = result.settlement;
    attempt = result.revealAttempt;
  }
  await unchanged(provider, t.observed);
  return frozen({ capture: saved, transactionHash: t.transactionHash, observed: t.observed,
    purchaseReceipt: purchase, settlement: paid, revealAttempt: attempt, refundedAmount, revokedAuthorizationId });
}
