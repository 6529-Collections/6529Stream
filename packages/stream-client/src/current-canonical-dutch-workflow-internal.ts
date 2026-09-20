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
import * as native from "./current-canonical-native-dutch.js";
import * as erc20 from "./current-erc20-dutch.js";
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

// Protocol fragments are checked against the separate frozen ABI121 compiler fixture.
const abi = new Interface([
  "function phase(uint256 collectionId,bytes32 phaseId) view returns (bool exists,(bool paused,uint64 startTime,uint64 endTime,uint32 maxBatchQuantity,bytes32 configHash,bytes32 metadataHash) config)",
  "function policyGrace(address manager,uint256 collectionId,bytes32 phaseId) view returns (bytes32 previousPolicyHash,uint64 previousPolicyRevision,uint64 previousPolicyGraceUntil)",
  "function phase() view returns (uint8)",
  "function isPaymentIntentNonceUsed(address payer, bytes32 nonce) view returns (bool)",
  "function paymentIntentDigest((address payer, address asset, uint256 maxAmount, bytes32 saleRef, bytes32 expectedPrimaryPolicyHash, bytes32 nonce, uint64 deadline) intent) view returns (bytes32)",
  "function permit2() view returns (address)",
  "function permit2CodeHash() view returns (bytes32)",
  "function permit2ChainId() view returns (uint256)",
  "function assetPolicy(address asset) view returns (uint8 status, bytes32 policyHash, uint64 effectiveAt, uint64 releaseGraceUntil)",
  "function assetPolicyHash(address) view returns (bytes32)",
  "function assetPolicyRevision(address) view returns (uint64)",
  "function assetPermitPolicy(address asset) view returns ((uint8 capabilities, uint8 permit2AllowanceMode, address permit2, bytes32 permit2CodeHash, bytes32 assetCodeHash, bytes32 assetPolicyHash, uint64 assetPolicyRevision, uint64 revision))",
  "function nonceBitmap(address owner, uint256 wordPos) view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "event PaymentIntentConsumed(address indexed payer, bytes32 indexed saleRef, bytes32 indexed nonce, uint16 schemaVersion, address asset, uint256 amount)",
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
  `event DutchSaleExecution(bytes32 indexed saleId,bytes32 indexed executionId,bytes32 indexed operationRoot,uint8 status,${sales.CANONICAL_NATIVE_SALES_RECEIPT_TUPLE} receipt)`,
  `event ERC20DutchExecution(bytes32 indexed saleId,bytes32 indexed executionId,uint8 status,uint8 revenueOutcome,${sales.CANONICAL_NATIVE_SALES_RECEIPT_TUPLE} receipt)`,
  "event FreeDutchExecuted(bytes32 indexed saleId,bytes32 indexed executionId,uint256 indexed tokenId,bytes32 authorizationId)",
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

export type DutchPreparedCall = native.CanonicalNativeDutchCall | erc20.ERC20DutchCall;
export type DutchRecord = native.CanonicalNativeDutchRecord | erc20.ERC20DutchRecord;
export type DutchCandidate = sales.CanonicalNativeSalesCandidate | erc20.ERC20DutchCandidate;
export type DutchReader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "getBalance" | "call">;
export type DutchReceiptReader = DutchReader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;

export interface DutchCodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}

/** Runtime and linked-library pins must come from reviewed deployment metadata. */
export interface DutchDeployment {
  readonly chainId: bigint;
  readonly family: "native" | "erc20";
  readonly adapter: DutchCodePin;
  readonly core: DutchCodePin;
  readonly manager: DutchCodePin;
  readonly ledger: DutchCodePin;
  readonly recorder: DutchCodePin;
  readonly paymentAdapter?: DutchCodePin;
  readonly asset?: DutchCodePin;
  readonly permit2?: DutchCodePin;
  /** Reviewed complete transitive library pins for the purchase route. */
  readonly linkedDependencies: readonly DutchCodePin[];
  /** Route-specific metadata inventories; an empty list explicitly asserts no external helper pins. */
  readonly refundLinkedDependencies: readonly DutchCodePin[];
  readonly historyLinkedDependencies: readonly DutchCodePin[];
  readonly revocationLinkedDependencies: readonly DutchCodePin[];
}

export interface DutchBlock {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}

export interface DutchAdmission {
  readonly status: bigint;
  readonly registeredAt: bigint;
  readonly statusUpdatedAt: bigint;
  readonly revision: bigint;
}

export interface DutchReveal {
  readonly quote: sales.CanonicalNativeSalesRevealQuote;
  readonly collectionPolicy: EntropyCollectionPolicyRecord | null;
  readonly directPolicyProbe: "direct-observation-no-nested-gas-equivalence";
}

export interface DutchCapture {
  readonly deployment: DutchDeployment;
  readonly prepared: DutchPreparedCall;
  readonly observed: DutchBlock;
  readonly record: DutchRecord | null;
  readonly candidate: DutchCandidate | null;
  readonly authorizationId: Hex | null;
  readonly reveal: DutchReveal | null;
  readonly admission: DutchAdmission | null;
  readonly paymentAdmission: DutchAdmission | null;
  readonly funding: DutchFunding | null;
  readonly mintTiming: DutchMintTiming | null;
  readonly counters: readonly sales.CanonicalNativeSalesCounterObservation[];
  readonly floor: DutchCodePin | null;
  readonly dependencies: readonly DutchCodePin[];
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

function pinInput(value: DutchCodePin): DutchCodePin {
  return frozen({ address: address(value.address), codeHash: hash(value.codeHash) });
}

function deployment(value: DutchDeployment): DutchDeployment {
  const input = copy(value);
  if (input.family !== "native" && input.family !== "erc20") throw Error("Unknown canonical family");
  for (const list of [input.linkedDependencies, input.refundLinkedDependencies, input.historyLinkedDependencies, input.revocationLinkedDependencies]) {
    if (!Array.isArray(list) || list.length > 256) throw Error("Reviewed route-specific linked dependency inventory required (max 256)");
  }
  return frozen({
    chainId: uint(input.chainId),
    family: input.family,
    adapter: pinInput(input.adapter),
    core: pinInput(input.core),
    manager: pinInput(input.manager),
    ledger: pinInput(input.ledger),
    recorder: pinInput(input.recorder),
    ...(input.family === "erc20" ? { paymentAdapter: pinInput(input.paymentAdapter!), asset: pinInput(input.asset!),
      ...(input.permit2 === undefined ? {} : { permit2: pinInput(input.permit2) }) } : {}),
    linkedDependencies: input.linkedDependencies.map(pinInput),
    refundLinkedDependencies: input.refundLinkedDependencies.map(pinInput),
    historyLinkedDependencies: input.historyLinkedDependencies.map(pinInput),
    revocationLinkedDependencies: input.revocationLinkedDependencies.map(pinInput),
  });
}

async function block(provider: Reader, tag: number): Promise<DutchBlock> {
  const result = await provider.getBlock(index(tag));
  if (!result || result.number !== tag) throw Error("Concrete block unavailable");
  return frozen({ blockNumber: tag, blockHash: hash(result.hash), timestamp: uint(BigInt(result.timestamp), 64) });
}

async function unchanged(provider: Reader, observed: DutchBlock): Promise<void> {
  equal(await block(provider, observed.blockNumber), observed, "Pinned block/reorg");
}

async function pin(provider: Reader, input: DutchCodePin, tag: number): Promise<void> {
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

function hostInterface(family: "native" | "erc20"): Interface {
  return family === "native" ? native.canonicalNativeDutchInterface() : erc20.erc20DutchInterface();
}

function normalizePrepared(input: DutchPreparedCall): DutchPreparedCall {
  return "paymentAdapter" in input.coordinates
    ? erc20.normalizeERC20DutchCall(input as erc20.ERC20DutchCall)
    : native.normalizeCanonicalNativeDutchCall(input as native.CanonicalNativeDutchCall);
}

function saleRecord(record: DutchRecord) {
  return "sale" in record ? record.sale : { ...record, config: record.config.sale };
}

function configuration(record: DutchRecord) {
  return "sale" in record
    ? { sale: record.sale.config, schedule: record.schedule, declaredFree: record.declaredFree }
    : record.config;
}

function purchaseOf(prepared: DutchPreparedCall): sales.CanonicalNativeSalesPurchase {
  if ("execution" in prepared) {
    if (!prepared.execution) throw Error("Purchase required");
    return prepared.execution.purchase;
  }
  const request = prepared.request;
  if (request.kind !== "purchaseSigned" && request.kind !== "purchasePublic") throw Error("Purchase required");
  return request.purchase;
}

function authorizationOf(prepared: DutchPreparedCall, record: DutchRecord) {
  if (saleRecord(record).config.authorityMode !== 1n) return null;
  if ("execution" in prepared) return prepared.execution!.authorization;
  return prepared.request.kind === "purchaseSigned" ? prepared.request.authorization : null;
}

function mintBatch(prepared: DutchPreparedCall, record: DutchRecord) {
  return "execution" in prepared
    ? erc20.erc20DutchMintBatch(prepared, record as erc20.ERC20DutchRecord)
    : native.canonicalNativeDutchMintBatch(prepared, record as native.CanonicalNativeDutchRecord);
}

function executionId(d: DutchDeployment, candidate: DutchCandidate): Hex {
  return d.family === "native"
    ? sales.canonicalNativeSalesExecutionId(d.chainId, candidate as sales.CanonicalNativeSalesCandidate)
    : erc20.erc20DutchExecutionId(d.chainId, candidate as erc20.ERC20DutchCandidate);
}

function candidateCommitment(d: DutchDeployment, candidate: DutchCandidate): Hex {
  return d.family === "native"
    ? sales.canonicalNativeSalesCandidateCommitment(d.chainId, d.recorder.address, candidate as sales.CanonicalNativeSalesCandidate)
    : erc20.erc20DutchCandidateCommitment(d.chainId, d.paymentAdapter!.address, d.recorder.address, candidate as erc20.ERC20DutchCandidate);
}

function settlementKey(d: DutchDeployment, candidate: DutchCandidate): Hex {
  return candidate.sale.amount === 0n ? ZERO : d.family === "native"
    ? sales.canonicalNativeSalesSettlementKey(d.chainId, d.recorder.address, d.adapter.address, candidate.executionBinding.executionId)
    : erc20.erc20DutchSettlementKey(d.chainId, d.recorder.address, d.adapter.address, candidate.executionBinding.executionId);
}

function quotedPrice(
  prepared: DutchPreparedCall,
  record: DutchRecord,
  observedAt: bigint,
  counterObservations: readonly sales.CanonicalNativeSalesCounterObservation[],
) {
  const config = saleRecord(record).config;
  const p = purchaseOf(prepared);
  const override = "execution" in prepared
    ? erc20.erc20DutchAllowlistPrice(prepared.coordinates, configuration(record) as erc20.ERC20DutchConfiguration, p, counterObservations)
    : sales.canonicalNativeSalesAllowlistPrice(prepared.coordinates, config, p, counterObservations);
  const authorization = authorizationOf(prepared, record);
  return "execution" in prepared
    ? erc20.erc20DutchPrice(configuration(record) as erc20.ERC20DutchConfiguration, observedAt, authorization?.unitPrice ?? null, override)
    : native.canonicalNativeDutchPrice(configuration(record) as native.CanonicalNativeDutchConfiguration, observedAt, authorization?.unitPrice ?? null, override);
}

/** The schedule clock is raw time. This refreshes price, never the immutable request. */
function atInclusion(capture: DutchCapture, timestamp: bigint): DutchCapture {
  const price = quotedPrice(capture.prepared, capture.record!, timestamp, capture.counters);
  const candidate = copy(capture.candidate!);
  const revised = { ...candidate, sale: { ...candidate.sale, amount: price.amount } };
  if (capture.deployment.family === "native" && price.amount === 0n) {
    revised.rights = { profileId: ZERO, wallet: ZERO_ADDRESS, templateId: ZERO, assignmentHash: ZERO, entriesHash: ZERO };
  }
  revised.executionBinding = { ...candidate.executionBinding, executionId: executionId(capture.deployment, revised) };
  return frozen({ ...capture, candidate: revised });
}

async function addDependency(
  provider: Reader,
  dependencies: DutchCodePin[],
  input: DutchCodePin,
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
  dependencies: DutchCodePin[],
  target: Address,
  addressGetter: string,
  hashGetter: string,
  tag: number,
): Promise<DutchCodePin> {
  const [targetAddress] = await read(provider, target, addressGetter, [], tag);
  const [codeHash] = await read(provider, target, hashGetter, [], tag);
  const result = pinInput({ address: targetAddress, codeHash });
  await addDependency(provider, dependencies, result, tag);
  return result;
}

async function managerBindings(
  provider: Reader,
  d: DutchDeployment,
  tag: number,
): Promise<void> {
  await pin(provider, d.manager, tag);
  await pin(provider, d.ledger, tag);
  equal((await read(provider, d.manager.address, "core", [], tag))[0], d.core.address, "Manager Core binding");
  equal((await read(provider, d.manager.address, "mintLedger", [], tag))[0], d.ledger.address, "Manager Ledger binding");
}

async function purchaseContext(
  provider: Reader,
  d: DutchDeployment,
  tag: number,
): Promise<DutchCodePin[]> {
  const dependencies: DutchCodePin[] = [];
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
  if (d.family === "erc20") {
    await addDependency(provider, dependencies, d.paymentAdapter!, tag);
    await addDependency(provider, dependencies, d.asset!, tag);
    for (const [getter, hashGetter, expected] of [
      ["core", "coreCodeHash", d.core], ["primarySaleSettlement", "settlementCodeHash", d.recorder],
      ["moduleRegistry", "moduleRegistryCodeHash", registry], ["revenueResolver", "resolverCodeHash", resolver],
      ["splitFactory", "factoryCodeHash", factory], ["assetPolicyRegistry", "assetRegistryCodeHash", assets],
    ] as const) equal(await binding(provider, dependencies, d.paymentAdapter!.address, getter, hashGetter, tag), expected, `Payment ${getter}`);
  }
  return dependencies;
}

const NATIVE_BINDING_ID = `0x${[
  "core()", "mintManager()", "nativeSaleLifecycleBinding(bytes32)", "primarySaleSettlement()",
].reduce((result, signature) => result ^ BigInt(id(signature).slice(0, 10)), 0n).toString(16).padStart(8, "0")}`;

// Own interface IDs; inherited PrimarySettlementBindings methods are excluded.
const ERC20_EXECUTION_ID = "0x2d8995b3";
const DUTCH_RESOLUTION_ID = "0x878d4ad5";
const PAYMENT_BINDING_ID = "0x1dfe133f";

async function admission(
  provider: Reader,
  d: DutchDeployment,
  record: ReturnType<typeof saleRecord>,
  observed: DutchBlock,
  payment = false,
): Promise<DutchAdmission> {
  const target = payment ? d.paymentAdapter! : d.adapter;
  const [registry] = await read(provider, d.adapter.address, "moduleRegistry", [], observed.blockNumber);
  const [row] = await read(provider, registry, "moduleRecord", [target.address], observed.blockNumber);
  const role = payment ? "ERC20_PRIMARY_SETTLEMENT_ADAPTER"
    : d.family === "native" ? "NATIVE_PRIMARY_SALE_ADAPTER" : "DUTCH_AUCTION_ADAPTER";
  const interfaceId = payment ? PAYMENT_BINDING_ID : d.family === "native" ? NATIVE_BINDING_ID : ERC20_EXECUTION_ID;
  equal([row.moduleType, row.moduleVersion, row.interfaceId, row.runtimeCodeHash],
    [id(role), id("6529STREAM_UNIVERSAL_SETTLEMENT_V1"), interfaceId, target.codeHash], "Original registry row");
  hash(row.moduleManifestHash);
  hash(row.deploymentManifestHash);
  const lifecycle = record.lifecycle;
  const revision = payment ? (lifecycle as erc20.ERC20DutchCandidate["lifecycleBinding"]).paymentAdapterRegistryRevision
    : lifecycle.saleAdapterRegistryRevision;
  if (![1n, 2n].includes(row.status) || row.registeredAt === 0n || row.registeredAt > observed.timestamp
    || row.statusUpdatedAt < row.registeredAt || row.statusUpdatedAt > observed.timestamp || row.revision === 0n
    || lifecycle.saleCreatedAt < row.registeredAt || lifecycle.saleCreatedAt > observed.timestamp
    || revision === 0n || revision > row.revision
    || (row.status === 2n && (lifecycle.saleCreatedAt >= row.statusUpdatedAt || revision >= row.revision))) {
    throw Error("Original ACTIVE/DEPRECATED admission mismatch");
  }
  equal((await read(provider, target.address, "supportsInterface", [interfaceId], observed.blockNumber))[0], true, "Original binding capability");
  if (d.family === "erc20" && !payment) {
    equal((await read(provider, target.address, "supportsInterface", [DUTCH_RESOLUTION_ID], observed.blockNumber))[0], true, "Dutch resolution capability");
    equal((await rpc(provider, target.address, hostInterface("erc20"), "dutchResolutionProfile", [], observed.blockNumber))[0],
      id("6529STREAM_ERC20_STANDARD_DUTCH_V1"), "Original Dutch resolution profile");
  }
  return frozen({ status: row.status, registeredAt: row.registeredAt, statusUpdatedAt: row.statusUpdatedAt, revision: row.revision });
}

async function reveal(
  provider: Reader,
  d: DutchDeployment,
  iface: Interface,
  saleId: Hex,
  collectionId: bigint,
  dependencies: DutchCodePin[],
  tag: number,
): Promise<DutchReveal> {
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
  d: DutchDeployment,
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
  d: DutchDeployment,
  saleId: Hex,
  tag: number,
): Promise<DutchRecord> {
  const [record] = await rpc(provider, d.adapter.address, hostInterface(d.family),
    d.family === "native" ? "saleRecord" : "dutchSaleRecord", [saleId], tag);
  return d.family === "native"
    ? native.normalizeCanonicalNativeDutchRecord(record)
    : erc20.normalizeERC20DutchRecord(record);
}

export interface DutchPermitPolicy {
  readonly capabilities: bigint;
  readonly permit2AllowanceMode: bigint;
  readonly permit2: Address;
  readonly permit2CodeHash: Hex;
  readonly assetCodeHash: Hex;
  readonly assetPolicyHash: Hex;
  readonly assetPolicyRevision: bigint;
  readonly revision: bigint;
}

export interface DutchMintTiming {
  readonly phaseEndTime: bigint;
  readonly previousPolicyHash: Hex;
  readonly previousPolicyRevision: bigint;
  readonly previousPolicyGraceUntil: bigint;
}

export interface DutchFunding {
  readonly assetPolicy: readonly [bigint, Hex, bigint, bigint];
  readonly payerBalance: bigint;
  readonly paymentBalance: bigint;
  readonly recorderBalance: bigint;
  readonly paymentNativeBalance: bigint;
  readonly intentUsed: boolean | null;
  readonly permitPolicy: DutchPermitPolicy | null;
  readonly tokenNonce: bigint | null;
  readonly permitBitmap: bigint | null;
  readonly permitApproval: bigint | null;
}

// Original StreamPermitExecution uses these EIP-2612 token selectors by signature.
const tokenPermitAbi = new Interface(["function nonces(address owner) view returns (uint256)"]);

async function paymentFunding(
  provider: Reader,
  d: DutchDeployment,
  prepared: erc20.ERC20DutchCall,
  candidate: erc20.ERC20DutchCandidate,
  timestamp: bigint,
  dependencies: DutchCodePin[],
  tag: number,
  receiptFree: boolean,
): Promise<DutchFunding> {
  const request = prepared.request;
  if (!("request" in request)) throw Error("Dutch Payment call required");
  // The closed receipt path already derives FREE from the reviewed immutable curve.
  // FREE never enters the source paid-permit branch, even if the prior quote was paid.
  if (receiptFree) candidate = { ...candidate, sale: { ...candidate.sale, amount: 0n } };
  erc20.validateERC20DutchFunding(prepared, candidate, timestamp);
  const amount = candidate.sale.amount;
  const payer = candidate.sale.payer;
  const payment = d.paymentAdapter!.address;
  const asset = d.asset!.address;
  equal(candidate.asset, asset, "Reviewed token");
  equal(candidate.lifecycleBinding.paymentAdapter, payment, "Immutable Payment binding");
  equal((await read(provider, payment, "phase()", [], tag))[0], 0n, "Payment IDLE");
  const [registry] = await read(provider, payment, "assetPolicyRegistry", [], tag);
  const assetPolicy = await read(provider, registry, "assetPolicy", [asset], tag) as [bigint, Hex, bigint, bigint];
  if (assetPolicy[0] !== 1n) throw Error("Original ACTIVE token policy required");
  const balances: bigint[] = [];
  for (const account of [payer, payment, d.recorder.address]) balances.push((await read(provider, asset, "balanceOf", [account], tag))[0]);
  let intentUsed: boolean | null = null;
  let permitPolicy: DutchPermitPolicy | null = null;
  let tokenNonce: bigint | null = null;
  let permitBitmap: bigint | null = null;
  let permitApproval: bigint | null = null;
  if (request.kind === "settleERC20DutchSaleWithIntent") {
    const intent = request.intent;
    equal([intent.payer, intent.asset, intent.saleRef, intent.expectedPrimaryPolicyHash],
      [payer, asset, candidate.sale.settlementId, candidate.sale.expectedPrimaryPolicyHash], "Original payment intent binding");
    if (intent.maxAmount < amount || intent.deadline < timestamp) throw Error("Payment intent maximum/deadline");
    [intentUsed] = await read(provider, payment, "isPaymentIntentNonceUsed", [payer, intent.nonce], tag);
    equal(intentUsed, false, "Unused payment intent, including FREE");
    equal(await read(provider, payment, "eip712Domain", [], tag),
      ["0x0f", "6529StreamPaymentIntentVerifier", "1", d.chainId, payment, ZERO, []], "Payment domain");
    equal((await read(provider, payment, "paymentIntentDigest", [intent], tag))[0],
      erc20.erc20DutchPaymentIntentPayload(prepared.coordinates, intent).digest, "Payment intent digest");
  } else equal(payer, prepared.caller, "Literal payer funding lane");
  if (amount > request.request.maxAmount) throw Error("Request token maximum");
  if (amount !== 0n && "permit" in request) {
    if (request.permit.permittedAmount < amount || request.permit.authorization.deadline < timestamp) throw Error("Paid permit maximum/deadline");
    [permitPolicy] = await read(provider, registry, "assetPermitPolicy", [asset], tag);
    const policy = permitPolicy!;
    equal([policy.assetCodeHash, policy.assetPolicyHash, policy.assetPolicyRevision],
      [d.asset!.codeHash, (await read(provider, registry, "assetPolicyHash", [asset], tag))[0],
        (await read(provider, registry, "assetPolicyRevision", [asset], tag))[0]], "Retained token permit policy");
    if (policy.capabilities < 1n || policy.capabilities > 3n || policy.revision === 0n) throw Error("Permit policy unavailable");
    if (request.kind === "settleERC20DutchSaleWithEIP2612Permit") {
      if ((policy.capabilities & 1n) === 0n) throw Error("EIP-2612 capability unavailable");
      [tokenNonce] = await rpc(provider, asset, tokenPermitAbi, "nonces", [payer], tag);
    } else {
      if (!d.permit2 || (policy.capabilities & 2n) === 0n || ![1n, 2n].includes(policy.permit2AllowanceMode)) throw Error("Pinned Permit2 capability unavailable");
      await addDependency(provider, dependencies, d.permit2, tag);
      equal([policy.permit2, policy.permit2CodeHash], [d.permit2.address, d.permit2.codeHash], "Permit2 policy pin");
      equal([(await read(provider, payment, "permit2", [], tag))[0], (await read(provider, payment, "permit2CodeHash", [], tag))[0],
        (await read(provider, payment, "permit2ChainId", [], tag))[0]], [d.permit2.address, d.permit2.codeHash, d.chainId], "Payment Permit2 pin");
      const permit = request.permit.authorization;
      [permitBitmap] = await read(provider, d.permit2.address, "nonceBitmap", [payer, permit.nonce >> 8n], tag);
      [permitApproval] = await read(provider, asset, "allowance", [payer, d.permit2.address], tag);
      if ((permitBitmap! & (1n << (permit.nonce & 255n))) !== 0n || permitApproval! < amount) throw Error("Permit2 nonce/approval unavailable");
    }
  }
  return frozen({ assetPolicy, payerBalance: balances[0]!, paymentBalance: balances[1]!, recorderBalance: balances[2]!,
    paymentNativeBalance: uint(await provider.getBalance(payment, tag)), intentUsed, permitPolicy, tokenNonce, permitBitmap, permitApproval });
}

function captureBody(value: Omit<DutchCapture, "captureHash"> | DutchCapture) {
  const { captureHash: _hash, ...body } = value as DutchCapture;
  return body;
}

function captureDigest(value: Omit<DutchCapture, "captureHash"> | DutchCapture): Hex {
  return keccak256(toUtf8Bytes(stable(captureBody(value)))) as Hex;
}

async function captureAt(
  provider: Reader,
  deploymentInput: DutchDeployment,
  preparedInput: DutchPreparedCall,
  options: { readonly blockTag: number },
  receiptFree = false,
): Promise<DutchCapture> {
  const d = deployment(deploymentInput);
  const prepared = normalizePrepared(preparedInput);
  const tag = index(options.blockTag);
  equal(prepared.coordinates, {
    chainId: d.chainId, adapter: d.adapter.address, manager: d.manager.address,
    ledger: d.ledger.address, recorder: d.recorder.address,
    ...(d.family === "erc20" ? { paymentAdapter: d.paymentAdapter!.address } : {}),
  }, "Prepared deployment coordinates");
  const observed = await block(provider, tag);
  equal((await provider.getNetwork()).chainId, d.chainId, "Deployment chain");
  await pin(provider, d.adapter, tag);
  const iface = hostInterface(d.family);
  const request = prepared.request;
  let record: DutchRecord | null = null;
  let candidate: DutchCandidate | null = null;
  let authorizationId: Hex | null = null;
  let revealObservation: DutchReveal | null = null;
  let admitted: DutchAdmission | null = null;
  let paymentAdmission: DutchAdmission | null = null;
  let funding: DutchFunding | null = null;
  let mintTiming: DutchMintTiming | null = null;
  let floorPin: DutchCodePin | null = null;
  let counterObservations: sales.CanonicalNativeSalesCounterObservation[] = [];
  let dependencies: DutchCodePin[] = [d.adapter];
  const adapterBalance = uint(await provider.getBalance(d.adapter.address, tag));
  let refundCredit = 0n;
  let refundLiability = 0n;
  if (request.kind === "claimRefund") {
    for (const p of d.refundLinkedDependencies) await addDependency(provider, dependencies, p, tag);
    [refundCredit] = await rpc(provider, d.adapter.address, iface, "refundableBalance", [request.saleId, prepared.caller], tag);
    [refundLiability] = await rpc(provider, d.adapter.address, iface, "refundLiability", [], tag);
    if (refundCredit === 0n || refundCredit > refundLiability || adapterBalance < refundLiability) throw Error("Refund credit/liability unavailable");
  } else if (request.kind === "voidMintImmediateSaleAuthorization") {
    await managerBindings(provider, d, tag);
    dependencies = [d.adapter, d.manager, d.ledger];
    for (const p of d.revocationLinkedDependencies) await addDependency(provider, dependencies, p, tag);
    const a = request.authorization;
    const binding = await read(provider, d.adapter.address, "immediateSaleAuthorizationBinding", [a.saleId], tag);
    equal([binding[0], binding[1], binding[2], binding[3], binding[5], binding[6]],
      [a.collectionId, a.phaseId, 3n, 1n, request.authorizer, request.authorizerKind], "Historical signed Dutch binding");
    hash(binding[4]);
    authorizationId = "execution" in prepared ? erc20.erc20DutchAuthorizationId(prepared.coordinates, a)
      : sales.canonicalNativeSalesAuthorizationId(prepared.coordinates, a);
    equal((await read(provider, d.manager.address, "mintSaleAuthorizationId", [a], tag))[0], authorizationId, "Original Manager authorization ID");
    equal((await read(provider, d.ledger.address, "isManagerAuthorizationUsed", [d.manager.address, authorizationId], tag))[0], false, "Unconsumed revocation");
  } else {
    const p = purchaseOf(prepared);
    equal(p.executor, prepared.caller, "Literal executor");
    if (d.family === "native") equal(p.payer, prepared.caller, "Literal native payer");
    dependencies = await purchaseContext(provider, d, tag);
    record = await recordAt(provider, d, p.saleId, tag);
    const base = saleRecord(record);
    const config = base.config;
    if (base.saleNonce === 0n) throw Error("Unknown Dutch sale");
    equal((await rpc(provider, d.adapter.address, iface, "saleConfigurationHash", [configuration(record)], tag))[0], base.configHash, "Retained full Dutch configuration hash");
    equal((await rpc(provider, d.adapter.address, iface, "nextExecutionNonce", [p.saleId, p.payer], tag))[0], p.executionNonce, "Next execution nonce");
    const authorization = authorizationOf(prepared, record);
    let preview: any[];
    if ("execution" in prepared) {
      const paymentRequest = prepared.request;
      if (!("request" in paymentRequest)) throw Error("Payment request required");
      equal([paymentRequest.request.saleAdapter, paymentRequest.request.saleAdapterCodeHash, paymentRequest.request.saleId, paymentRequest.request.saleConfigHash],
        [d.adapter.address, d.adapter.codeHash, p.saleId, base.configHash], "Immutable Payment request carrier binding");
      preview = await rpc(provider, d.adapter.address, iface, "resolveERC20DutchExecution",
        [p.saleId, base.configHash, prepared.caller, paymentRequest.request.executionData], tag, d.paymentAdapter!.address);
      candidate = erc20.normalizeERC20DutchCandidate(preview[0]);
    } else {
      const r = prepared.request;
      if (r.kind !== "purchaseSigned" && r.kind !== "purchasePublic") throw Error("Native purchase required");
      preview = await rpc(provider, d.adapter.address, iface, r.kind === "purchaseSigned" ? "previewSignedPurchase" : "previewPublicPurchase",
        r.kind === "purchaseSigned" ? [r.purchase, r.authorization, r.signature] : [r.purchase], tag, prepared.caller);
      candidate = sales.normalizeCanonicalNativeSalesCandidate(preview[0]);
    }
    const batch = mintBatch(prepared, record);
    authorizationId = batch.authorizationId;
    const digest = authorization ? ("execution" in prepared
      ? erc20.erc20DutchAuthorizationPayload(prepared.coordinates, authorization).digest
      : sales.canonicalNativeSalesAuthorizationPayload(prepared.coordinates, authorization).digest) : ZERO;
    if (authorization) {
      equal(await read(provider, d.adapter.address, "eip712Domain", [], tag),
        ["0x0f", "6529Stream Sales", "1", d.chainId, d.adapter.address, ZERO, []], "Original Sales-v1 signing domain");
      equal((await read(provider, d.adapter.address, "authorizationDigest", [authorization], tag))[0], digest, "Original signed digest getter");
    } else equal(config.authorityMode, 2n, "Public authority mode");
    equal(candidate.executionBinding, { executionId: candidate.executionBinding.executionId, executionNonce: p.executionNonce,
      authorityMode: config.authorityMode, saleAuthorizationDigest: digest }, "Original execution authority binding");
    const executionHash = "execution" in prepared
      ? keccak256(erc20.encodeERC20DutchExecution(prepared.execution!))
      : native.canonicalNativeDutchSaleExecutionHash(batch.contextHash, digest, authorizationId);
    equal(candidate.saleExecutionHash, executionHash, "Original Dutch execution commitment");
    equal([candidate.orchestrationOrder, candidate.sale.revenueClass, candidate.sale.policyMode, candidate.sale.tokenId, candidate.sale.poster, candidate.sale.expectedPrimaryPolicyHash],
      [1n, id("PRIMARY_SALE"), 0n, 0n, ZERO_ADDRESS, config.expectedPrimaryPolicyHash], "Original candidate fields");
    if (d.family === "native" && !authorization) equal(preview[1], authorizationId, "Public original authorization ID");
    const managerPreview = await read(provider, d.manager.address, "previewSingleStepMintOperation", [batch, "0x"], tag, d.adapter.address);
    equal(managerPreview, [candidate.operationIdentityCommitment, [candidate.operationId]], "Original Manager preview from adapter");
    equal([candidate.saleAdapter, candidate.executor, candidate.mintManager, candidate.sale.settlementId, candidate.sale.collectionId,
      candidate.sale.payer, candidate.sale.beneficiary, candidate.sale.saleNonce, candidate.boundPolicyHash, candidate.lifecycleBinding],
      [d.adapter.address, prepared.caller, d.manager.address, p.saleId, config.collectionId, p.payer, p.beneficiary, base.saleNonce, config.mintPolicyHash, base.lifecycle], "Candidate source joins");
    equal(candidate.currentPolicyHash, (await read(provider, d.manager.address, "phasePolicyHash", [config.collectionId, config.phaseId], tag))[0], "Observed current policy");
    const [phaseExists, phaseConfig] = await read(provider, d.manager.address, "phase(uint256,bytes32)", [config.collectionId, config.phaseId], tag);
    if (!phaseExists || phaseConfig.paused || phaseConfig.startTime > observed.timestamp
      || (phaseConfig.endTime !== 0n && phaseConfig.endTime < observed.timestamp)) throw Error("Manager phase timing unavailable");
    const grace = candidate.currentPolicyHash !== candidate.boundPolicyHash
      ? await read(provider, d.ledger.address, "policyGrace", [d.manager.address, config.collectionId, config.phaseId], tag)
      : [ZERO, 0n, 0n];
    if (candidate.currentPolicyHash !== candidate.boundPolicyHash
      && (grace[0] !== candidate.boundPolicyHash || grace[2] < observed.timestamp)) throw Error("Original bound-policy grace unavailable");
    mintTiming = { phaseEndTime: phaseConfig.endTime, previousPolicyHash: grace[0], previousPolicyRevision: grace[1], previousPolicyGraceUntil: grace[2] };
    equal(candidate.executionBinding.executionId, executionId(d, candidate), "Original execution ID");
    equal((await rpc(provider, d.adapter.address, iface, "executionStatus", [candidate.executionBinding.executionId], tag))[0], 0n, "Fresh execution");
    equal((await read(provider, d.ledger.address, "isManagerAuthorizationUsed", [d.manager.address, authorizationId], tag))[0], false, "Authorization replay");
    equal((await read(provider, d.ledger.address, "isManagerOperationRootUsed", [d.manager.address, candidate.operationIdentityCommitment], tag))[0], false, "Operation replay");
    counterObservations = await counters(provider, d, config, tag);
    const price = quotedPrice(prepared, record, observed.timestamp, counterObservations);
    equal(candidate.sale.amount, price.amount, "Original timestamp-specific Dutch price");
    if (d.family === "native" && price.amount === 0n) equal(candidate.rights,
      { profileId: ZERO, wallet: ZERO_ADDRESS, templateId: ZERO, assignmentHash: ZERO, entriesHash: ZERO }, "Native FREE rights");
    else {
      hash(candidate.rights.profileId);
      address(candidate.rights.wallet);
      hash(candidate.rights.entriesHash);
    }
    admitted = await admission(provider, d, base, observed);
    if (d.family === "erc20") {
      paymentAdmission = await admission(provider, d, base, observed, true);
      funding = await paymentFunding(provider, d, prepared as erc20.ERC20DutchCall, candidate as erc20.ERC20DutchCandidate, observed.timestamp, dependencies, tag, receiptFree);
    }
    revealObservation = await reveal(provider, d, iface, p.saleId, config.collectionId, dependencies, tag);
    const fee = revealObservation.quote.policy.revealFeePerTokenWei;
    const nativePrice = d.family === "native" ? price.amount : 0n;
    if (prepared.call.value < nativePrice + fee) throw Error("Native value/reveal allowance");
    [refundCredit] = await rpc(provider, d.adapter.address, iface, "refundableBalance", [p.saleId, prepared.caller], tag);
    [refundLiability] = await rpc(provider, d.adapter.address, iface, "refundLiability", [], tag);
    if (price.amount !== 0n && !receiptFree) {
      const [target, codeHash] = await read(provider, d.core.address, "conservationFloor", [], tag);
      floorPin = pinInput({ address: target, codeHash });
      await addDependency(provider, dependencies, floorPin, tag);
    }
  }
  await unchanged(provider, observed);
  const body = frozen({ deployment: d, prepared, observed, record, candidate, authorizationId,
    reveal: revealObservation, admission: admitted, paymentAdmission, funding, mintTiming, floor: floorPin, counters: counterObservations,
    dependencies, refundCredit, refundLiability, adapterBalance,
    admissionAuthority: "original-adapter-or-manager-call-simulation" as const });
  return frozen({ ...body, captureHash: captureDigest(body) });
}

/** Public capture always checks admission against its own pinned block quote. */
export async function captureDutch(
  provider: Reader,
  deploymentInput: DutchDeployment,
  preparedInput: DutchPreparedCall,
  options: { readonly blockTag: number },
): Promise<DutchCapture> {
  return captureAt(provider, deploymentInput, preparedInput, options);
}

function normalizeCapture(input: DutchCapture): DutchCapture {
  const cloned = copy(input);
  const result = { ...cloned, deployment: deployment(cloned.deployment), prepared: normalizePrepared(cloned.prepared) };
  equal(captureDigest(result), result.captureHash, "Captured immutable facts");
  return frozen(result);
}

async function validateCapture(provider: Reader, capture: DutchCapture): Promise<void> {
  const current = await captureDutch(provider, capture.deployment, capture.prepared, { blockTag: capture.observed.blockNumber });
  equal(current, capture, "Historical capture reconstruction");
}

export interface DutchSimulation {
  readonly capture: DutchCapture;
  readonly returnData: Hex;
  readonly paymentResult: erc20.ERC20DutchResult | null;
  readonly receipt: sales.CanonicalNativeSalesReceipt | null;
  readonly authorizationId: Hex | null;
}

export async function simulateDutch(
  provider: Reader,
  input: DutchCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<DutchSimulation> {
  const saved = normalizeCapture(input);
  const tag = index(options.blockTag);
  const gasLimit = gas(options.gasLimit);
  if (tag < saved.observed.blockNumber) throw Error("Simulation predates capture");
  await validateCapture(provider, saved);
  const current = await captureDutch(provider, saved.deployment, saved.prepared, { blockTag: tag });
  const p = current.prepared;
  const raw = bytes(await provider.call({ ...p.call, from: p.caller, gasLimit, blockTag: tag }));
  let receipt: sales.CanonicalNativeSalesReceipt | null = null;
  let paymentResult: erc20.ERC20DutchResult | null = null;
  const iface = p.request.kind === "voidMintImmediateSaleAuthorization"
    ? new Interface(sales.CURRENT_CANONICAL_NATIVE_SALES_REVOCATION_ABI)
    : "execution" in p && p.execution ? erc20.erc20DutchPaymentInterface() : hostInterface(current.deployment.family);
  const decoded = iface.decodeFunctionResult(p.request.kind, raw);
  equal(iface.encodeFunctionResult(p.request.kind, decoded), raw, "Original simulation return");
  if (p.request.kind === "purchaseSigned" || p.request.kind === "purchasePublic") {
    receipt = sales.normalizeCanonicalNativeSalesReceipt(plain(iface.getFunction(p.request.kind)!.outputs[0]!, decoded[0]));
    expectedReceipt(current, receipt);
  } else if ("execution" in p && p.execution) {
    paymentResult = erc20.validateERC20DutchResult(plain(iface.getFunction(p.request.kind)!.outputs[0]!, decoded[0]), current.candidate as erc20.ERC20DutchCandidate);
    if (current.candidate!.sale.amount !== 0n) expectedSettlement(current, paymentResult.settlement);
  } else if (p.request.kind === "voidMintImmediateSaleAuthorization") {
    equal(decoded[0], current.authorizationId, "Simulated revoked ID");
  }
  await unchanged(provider, current.observed);
  return frozen({ capture: current, returnData: raw, receipt, paymentResult, authorizationId: current.authorizationId });
}

function expectedReceipt(capture: DutchCapture, receipt: sales.CanonicalNativeSalesReceipt): void {
  const candidate = capture.candidate!;
  const price = candidate.sale.amount;
  const fee = capture.reveal!.quote.policy.revealFeePerTokenWei;
  const key = settlementKey(capture.deployment, candidate);
  equal({ ...receipt, tokenId: 0n }, {
    saleId: candidate.sale.settlementId,
    executionId: candidate.executionBinding.executionId,
    authorizationId: capture.authorizationId,
    saleAuthorizationDigest: candidate.executionBinding.saleAuthorizationDigest,
    operationRoot: candidate.operationIdentityCommitment,
    operationId: candidate.operationId,
    tokenId: 0n,
    settlementKey: key,
    chargedAmount: price,
    revealFee: fee,
    revealCredit: capture.prepared.call.value - (capture.deployment.family === "native" ? price : 0n) - fee,
  }, "Typed canonical purchase receipt");
  if (receipt.tokenId === 0n) throw Error("Minted token ID required");
}

export interface DutchHistory {
  readonly deployment: DutchDeployment;
  readonly observed: DutchBlock;
  readonly record: DutchRecord;
  readonly receipt: sales.CanonicalNativeSalesReceipt | null;
  readonly status: bigint | null;
}

/** Local immutable sale/execution evidence; does not re-admit current commerce dependencies. */
export async function inspectDutch(
  provider: Reader,
  deploymentInput: DutchDeployment,
  query: { readonly saleId: Hex; readonly executionId?: Hex },
  options: { readonly blockTag: number },
): Promise<DutchHistory> {
  const d = deployment(deploymentInput);
  const saleId = hash(query.saleId, true);
  const executionId = query.executionId === undefined ? null : hash(query.executionId, true);
  const tag = index(options.blockTag);
  const observed = await block(provider, tag);
  equal((await provider.getNetwork()).chainId, d.chainId, "History chain");
  await pin(provider, d.adapter, tag);
  for (const p of d.historyLinkedDependencies) await pin(provider, p, tag);
  const record = await recordAt(provider, d, saleId, tag);
  let receipt: sales.CanonicalNativeSalesReceipt | null = null;
  let status: bigint | null = null;
  if (executionId !== null) {
    const iface = hostInterface(d.family);
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

export type DutchReceiptOptions =
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
  readonly observed: DutchBlock;
  readonly logs: readonly ReceiptLog[];
  readonly safeIndex: number | null;
}

async function transport(
  provider: ReceiptReader,
  prepared: DutchPreparedCall,
  transactionHash: Hex,
  inputOptions: DutchReceiptOptions,
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
    data: bytes(rawTx.data, 4 * MAX_BYTES + 16384),
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

export interface DutchFloorReceipt {
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

export interface DutchSettlement {
  readonly result: sales.CanonicalNativeSalesResult;
  readonly floor: DutchFloorReceipt;
  readonly firstSale: floor.DirectConservationFirstSaleReceipt;
  readonly release: floor.DirectConservationReleaseReceipt | null;
}

function expectedSettlement(capture: DutchCapture, result: sales.CanonicalNativeSalesResult): void {
  const d = capture.deployment;
  const n = capture.candidate!;
  equal({ ...result, escrowed: false }, {
    candidateCommitment: candidateCommitment(d, n), settlementKey: settlementKey(d, n),
    profileId: n.rights.profileId, wallet: n.rights.wallet, asset: d.family === "native" ? ZERO_ADDRESS : d.asset!.address,
    amount: n.sale.amount, executor: n.executor, executionId: n.executionBinding.executionId,
    escrowed: false, operationIdentityCommitment: n.operationIdentityCommitment,
    currentPolicyHash: n.currentPolicyHash, boundPolicyHash: n.boundPolicyHash,
  }, "Full original settlement result");
}

async function settlement(
  provider: Reader,
  capture: DutchCapture,
  t: Transport,
  receipt: sales.CanonicalNativeSalesReceipt,
  releaseKey: Hex | null,
): Promise<{
  value: DutchSettlement;
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
  expectedSettlement(capture, result);
  const f = capture.floor!.address;
  const [floorReceipt] = await read(provider, f, "settlementReceipt", [key], tag) as [DutchFloorReceipt];
  equal([floorReceipt.recorder, floorReceipt.recorderCodeHash, floorReceipt.settlementKey,
    floorReceipt.candidatePayloadHash, floorReceipt.candidateCommitment, floorReceipt.resultHash,
    floorReceipt.collectionId, floorReceipt.tokenId, floorReceipt.recordedAt],
  [target, d.recorder.codeHash, key, (d.family === "native" ? sales.canonicalNativeSalesAccountingContextHash(n as sales.CanonicalNativeSalesCandidate) : erc20.erc20DutchAccountingContextHash(n as erc20.ERC20DutchCandidate)), result.candidateCommitment,
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
  const settled = one(t, target, abi, "PrimaryRevenueSettled", { ...common, wallet: result.wallet, asset: d.family === "native" ? ZERO_ADDRESS : d.asset!.address, payer: n.sale.payer,
    amount: n.sale.amount, saleContextHash: keccak256(coder.encode([sales.CANONICAL_NATIVE_SALES_PRIMARY_SALE_TUPLE], [n.sale])),
    policyDrift: false, assignmentType: n.rights.templateId === ZERO ? 1n : 2n });
  const context = one(t, target, abi, "PrimaryRevenueSettlementContext", { ...common, settlementCaller: d.adapter.address,
    settlementId: n.sale.settlementId, policyMode: 0n, collectionId: n.sale.collectionId, tokenId: 0n,
    operationRoot: n.operationIdentityCommitment, operationId: n.operationId, saleNonce: n.sale.saleNonce,
    poster: ZERO_ADDRESS, beneficiary: n.sale.beneficiary, templateId: n.rights.templateId });
  const policy = one(t, target, abi, "PrimaryRevenueSettlementPolicy", { ...common, expectedPrimaryPolicyHash: n.sale.expectedPrimaryPolicyHash,
    resolvedPrimaryPolicyHash: n.sale.expectedPrimaryPolicyHash, resolvedAssignmentHash: n.rights.assignmentHash, templateId: n.rights.templateId });
  const bound = one(t, target, abi, "PrimaryRevenueExecutionBound", { settlementKey: key, saleAdapter: d.adapter.address,
    executionId: receipt.executionId, schemaVersion: 1n, executor: n.executor, paymentAdapter: d.family === "native" ? ZERO_ADDRESS : d.paymentAdapter!.address,
    candidateCommitment: result.candidateCommitment, currentPolicyHash: n.currentPolicyHash, boundPolicyHash: n.boundPolicyHash });
  ordered(floorEvent.index, settled.index, context.index, policy.index, bound.index);
  return { value: frozen({ result, floor: floorReceipt, firstSale, release }), firstEvent: firstIndex, lastEvent: bound.index };
}

export interface DutchRevealAttempt {
  readonly succeeded: boolean;
  readonly requestKey: Hex;
  readonly providerRequestId: bigint;
  readonly returnDataSize: bigint;
  readonly failurePrefix: Hex;
}

export interface DutchReconciliation {
  readonly capture: DutchCapture;
  readonly transactionHash: Hex;
  readonly observed: DutchBlock;
  readonly purchaseReceipt: sales.CanonicalNativeSalesReceipt | null;
  readonly settlement: DutchSettlement | null;
  readonly revealAttempt: DutchRevealAttempt | null;
  readonly refundedAmount: bigint | null;
  readonly revokedAuthorizationId: Hex | null;
}

async function paymentReceipt(
  provider: Reader,
  prior: DutchCapture,
  t: Transport,
  carrierStart: number,
): Promise<void> {
  const d = prior.deployment;
  const plan = prior.prepared as erc20.ERC20DutchCall;
  const request = plan.request;
  if (!("request" in request)) throw Error("Payment request required");
  const n = prior.candidate as erc20.ERC20DutchCandidate;
  const before = prior.funding!;
  const payment = d.paymentAdapter!.address;
  const token = d.asset!.address;
  const payer = n.sale.payer;
  const amount = n.sale.amount;
  const tag = t.observed.blockNumber;
  equal((await read(provider, payment, "phase()", [], tag))[0], 0n, "Payment returned to IDLE");
  equal(await provider.getBalance(payment, tag), before.paymentNativeBalance, "Payment native balance restored");
  equal([(await read(provider, token, "balanceOf", [payer], tag))[0],
    (await read(provider, token, "balanceOf", [payment], tag))[0],
    (await read(provider, token, "balanceOf", [d.recorder.address], tag))[0]],
    [before.payerBalance - amount, before.paymentBalance, before.recorderBalance], "Exact original token funding deltas");
  const consumed = events(t, payment, abi, "PaymentIntentConsumed");
  if (request.kind === "settleERC20DutchSaleWithIntent") {
    const i = request.intent;
    equal((await read(provider, payment, "isPaymentIntentNonceUsed", [payer, i.nonce], tag))[0], amount !== 0n, "Paid-only payment intent consumption");
    if (amount !== 0n) {
      const event = one(t, payment, abi, "PaymentIntentConsumed", { payer, saleRef: i.saleRef, nonce: i.nonce,
        schemaVersion: 1n, asset: token, amount });
      ordered(event.index, carrierStart);
    } else if (consumed.length !== 0) throw Error("FREE intent must remain unconsumed");
  } else if (consumed.length !== 0) throw Error("Unexpected payment intent consumption");
  if (amount !== 0n && "permit" in request) {
    if (request.kind === "settleERC20DutchSaleWithEIP2612Permit") {
      equal((await rpc(provider, token, tokenPermitAbi, "nonces", [payer], tag))[0], before.tokenNonce! + 1n, "EIP-2612 nonce advancement");
      erc20.erc20DutchEIP2612Remaining(request.permit.permittedAmount, amount,
        (await read(provider, token, "allowance", [payer, payment], tag))[0]);
    } else {
      const nonce = request.permit.authorization.nonce;
      equal((await read(provider, d.permit2!.address, "nonceBitmap", [payer, nonce >> 8n], tag))[0],
        before.permitBitmap! | (1n << (nonce & 255n)), "Exact Permit2 nonce bit");
      const approval = before.permitApproval!;
      const remaining = approval === (1n << 256n) - 1n && before.permitPolicy!.permit2AllowanceMode === 2n ? approval : approval - amount;
      equal((await read(provider, token, "allowance", [payer, d.permit2!.address], tag))[0], remaining, "Permit2 token approval remainder");
    }
  }
}

/** Price is refreshed independently. Other observed pre-state remains reviewed, not on-chain CAS. */
function nonPriceFacts(capture: DutchCapture, free: boolean) {
  const { observed: _block, ...body } = copy(captureBody(capture));
  if (!body.candidate) return body;
  const candidate = { ...body.candidate, sale: { ...body.candidate.sale, amount: 0n } };
  if (free && body.deployment.family === "native") {
    candidate.rights = { profileId: ZERO, wallet: ZERO_ADDRESS, templateId: ZERO, assignmentHash: ZERO, entriesHash: ZERO };
  }
  return {
    ...body, candidate,
    floor: free ? null : body.floor,
    funding: free && body.funding ? { ...body.funding, permitPolicy: null, tokenNonce: null, permitBitmap: null, permitApproval: null } : body.funding,
    dependencies: free ? body.dependencies.filter(p => p.address !== body.floor?.address && p.address !== body.deployment.permit2?.address) : body.dependencies,
  };
}

async function purchaseReceipt(
  provider: Reader,
  prior: DutchCapture,
  t: Transport,
  releaseKey: Hex | null,
): Promise<Pick<DutchReconciliation, "purchaseReceipt" | "settlement" | "revealAttempt">> {
  const d = prior.deployment;
  const p = purchaseOf(prior.prepared);
  const n = prior.candidate!;
  const base = saleRecord(prior.record!);
  const config = base.config;
  const timing = prior.mintTiming!;
  if ((timing.phaseEndTime !== 0n && timing.phaseEndTime < t.observed.timestamp)
    || (n.currentPolicyHash !== n.boundPolicyHash && timing.previousPolicyGraceUntil < t.observed.timestamp)) {
    throw Error("Manager phase or bound-policy grace expired at mined timestamp");
  }
  const authorization = authorizationOf(prior.prepared, prior.record!);
  if (authorization && authorization.deadline < t.observed.timestamp) throw Error("Signed purchase expired at mined timestamp");
  if ("execution" in prior.prepared) erc20.validateERC20DutchFunding(prior.prepared, n as erc20.ERC20DutchCandidate, t.observed.timestamp);
  const iface = hostInterface(d.family);
  const tag = t.observed.blockNumber;
  for (const dependency of prior.dependencies) {
    if (n.sale.amount === 0n && (dependency.address === prior.floor?.address || dependency.address === d.permit2?.address)) continue;
    await pin(provider, dependency, tag);
  }
  const name = d.family === "native" ? "DutchSaleExecution" : "ERC20DutchExecution";
  const executions = events(t, d.adapter.address, abi, name);
  if (executions.length !== 2) throw Error("Expected original REQUESTED/completed host receipt pair");
  const first = executions[0]!;
  const final = executions[1]!;
  equal([first.args.status, final.args.status], [1n, 2n], "Host execution status pair");
  const receipt = sales.normalizeCanonicalNativeSalesReceipt(final.args.receipt);
  expectedReceipt(prior, receipt);
  for (const event of [first, final]) {
    equal([event.args.saleId, event.args.executionId], [receipt.saleId, receipt.executionId], "Receipt event keys");
    if (d.family === "native") equal(event.args.operationRoot, receipt.operationRoot, "Native event operation root");
    else equal(event.args.revenueOutcome, receipt.chargedAmount === 0n ? 1n : 2n, "Original revenue outcome");
  }
  equal(first.args.receipt, { ...receipt, tokenId: 0n, settlementKey: ZERO }, "Initial zero-token/zero-settlement receipt");
  const [recordedReceipt] = await rpc(provider, d.adapter.address, iface, "executionReceipt", [receipt.executionId], tag);
  equal(recordedReceipt, receipt, "Immutable adapter receipt readback");
  equal((await rpc(provider, d.adapter.address, iface, "executionStatus", [receipt.executionId], tag))[0], 2n, "Completed adapter execution");
  equal((await rpc(provider, d.adapter.address, iface, "nextExecutionNonce", [p.saleId, p.payer], tag))[0], p.executionNonce + 1n, "Execution nonce advancement");
  if (config.authorityMode === 2n) {
    equal((await rpc(provider, d.adapter.address, iface, d.family === "native" ? "activePublicNativeCandidate" : "activePublicERC20Candidate", [receipt.executionId], tag))[0], ZERO, "Cleared public candidate");
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
  const batch = mintBatch(prior.prepared, prior.record!);
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
  let paid: DutchSettlement | null = null;
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
  let revealAttempt: DutchRevealAttempt | null = null;
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
    const excess = one(t, d.adapter.address, abi, "SalePaymentExcessCredited", { schemaVersion: 1n, saleId: p.saleId, payer: prior.prepared.caller, amount: receipt.revealCredit });
    ordered(last, excess.index, final.index);
    last = excess.index;
  } else if (excessEvents.length !== 0) throw Error("Zero excess must not emit refund credit");
  equal((await rpc(provider, d.adapter.address, iface, "refundableBalance", [p.saleId, prior.prepared.caller], tag))[0], prior.refundCredit + receipt.revealCredit, "Payer pull credit");
  equal((await rpc(provider, d.adapter.address, iface, "refundLiability", [], tag))[0], prior.refundLiability + receipt.revealCredit, "Refund liability");
  equal(await provider.getBalance(d.adapter.address, tag), prior.adapterBalance + receipt.revealCredit, "Native retained excess balance");
  if (closes) {
    const close = one(t, d.adapter.address, abi, "ImmediateSaleClosed", { saleId: p.saleId, soldQuantity: sold });
    ordered(last, close.index, final.index);
    last = close.index;
  } else if (events(t, d.adapter.address, abi, "ImmediateSaleClosed").length !== 0) throw Error("Unexpected sale close");
  if (receipt.chargedAmount === 0n && d.family === "native") {
    const free = one(t, d.adapter.address, abi, "FreeDutchExecuted", { saleId: p.saleId, executionId: receipt.executionId, tokenId: receipt.tokenId, authorizationId: receipt.authorizationId });
    ordered(last, free.index, final.index);
  } else if (events(t, d.adapter.address, abi, "FreeDutchExecuted").length !== 0) throw Error("Paid sale cannot emit free claim");
  if (d.family === "erc20") await paymentReceipt(provider, prior, t, first.index);
  finish(t, final.index);
  return { purchaseReceipt: receipt, settlement: paid, revealAttempt };
}

/** Prior-block and end-block state equality is a conservative receipt attribution profile. */
export async function reconcileDutchReceipt(
  provider: ReceiptReader,
  captureInput: DutchCapture,
  transactionHash: Hex,
  optionsInput: DutchReceiptOptions,
): Promise<DutchReconciliation> {
  const saved = normalizeCapture(captureInput);
  const options = copy(optionsInput);
  const releaseKey = options.releaseKey === undefined ? null : hash(options.releaseKey);
  const t = await transport(provider, saved.prepared, transactionHash, options);
  if (t.observed.blockNumber <= saved.observed.blockNumber) throw Error("Receipt must be strictly later than capture");
  await validateCapture(provider, saved);
  const free = saved.candidate !== null && atInclusion(saved, t.observed.timestamp).candidate!.sale.amount === 0n;
  const prior = await captureAt(provider, saved.deployment, saved.prepared,
    { blockTag: t.observed.blockNumber - 1 }, free);
  equal(nonPriceFacts(prior, free), nonPriceFacts(saved, free), "Reviewed prior-block nonprice state");
  const d = prior.deployment;
  const request = prior.prepared.request;
  const tag = t.observed.blockNumber;
  await pin(provider, d.adapter, tag);
  if (request.kind === "claimRefund" || request.kind === "voidMintImmediateSaleAuthorization") {
    for (const dependency of prior.dependencies) await pin(provider, dependency, tag);
  }
  let purchase: sales.CanonicalNativeSalesReceipt | null = null;
  let paid: DutchSettlement | null = null;
  let attempt: DutchRevealAttempt | null = null;
  let refundedAmount: bigint | null = null;
  let revokedAuthorizationId: Hex | null = null;
  if (request.kind === "claimRefund") {
    const event = one(t, d.adapter.address, abi, "SaleRefundClaimed", { schemaVersion: 1n, saleId: request.saleId,
      payer: prior.prepared.caller, recipient: request.recipient, amount: prior.refundCredit });
    const iface = hostInterface(d.family);
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
    const result = await purchaseReceipt(provider, atInclusion(prior, t.observed.timestamp), t, releaseKey);
    purchase = result.purchaseReceipt;
    paid = result.settlement;
    attempt = result.revealAttempt;
  }
  await unchanged(provider, t.observed);
  return frozen({ capture: saved, transactionHash: t.transactionHash, observed: t.observed,
    purchaseReceipt: purchase, settlement: paid, revealAttempt: attempt, refundedAmount, revokedAuthorizationId });
}
