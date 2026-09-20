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
  solidityPackedKeccak256,
  toUtf8Bytes,
  type Provider,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { requireSafeExecution } from "./safe.js";
import * as merkle from "./current-distribution-merkle.js";
import * as accounting from "./current-mint-counter-reads.js";
import type { OperatorDistributionManifest } from "./current-distribution.js";
import {
  ENTROPY_COLLECTION_POLICY_INTERFACE_ID,
  type EntropyCollectionPolicyRecord,
  type EntropyCollectionPolicyReveal,
} from "./current-entropy-collection-policy.js";

const ZERO = ZeroHash as Hex;
const ADDRESS_ZERO = ZeroAddress as Address;
const MAX_BYTES = 2 * 1024 * 1024;
const MAX_CALL_BYTES = 4 * 1024 * 1024;
const coder = AbiCoder.defaultAbiCoder();

// Exact ordinary contract/interface fragments from the separate ABI117 witness.
const abi = new Interface([
  "function policyGrace(address manager, uint256 collectionId, bytes32 phaseId) view returns (bytes32 previousPolicyHash, uint64 previousPolicyRevision, uint64 previousPolicyGraceUntil)",
  "function phaseGate(uint256 collectionId, bytes32 phaseId) view returns ((address gate, bytes32 gateConfigHash, bytes32 gateCodehash, bytes32 gateMetadataHash, uint32 gateSemanticVersion, uint32 gateGasLimit))",
  "event MintGateValidated(uint256 indexed collectionId, bytes32 indexed phaseId, address indexed gate, bytes32 authorizationId, address authorizer, uint256 quantity, bytes32 contextHash, bytes32 gateHash, bytes32 policyHash)",
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function manager() view returns (address)",
  "function managerCodeHash() view returns (bytes32)",
  "function moduleRegistry() view returns (address)",
  "function registryCodeHash() view returns (bytes32)",
  "function delegateRegistry() view returns (address)",
  "function delegateRegistryCodeHash() view returns (bytes32)",
  "function delegationUsecase() view returns (uint256)",
  "function baseManifestHash() view returns (bytes32)",
  "function moduleManifestBytes() view returns (bytes)",
  "function supportsInterface(bytes4 id) view returns (bool)",
  "function merkleProgramHash(uint256 collectionId, bytes32 phaseId, (address operator, bytes32 slicesRoot, bytes32 supplyCounterId, bytes32 recipientCounterId, uint64 totalQuantity, uint64 perRecipientCap, uint8 deliveryMode, bool prepared) p, bytes32 recipientCounterConfigHash) view returns (bytes32)",
  "function programHash(uint256 collectionId, bytes32 phaseId, (address operator, bytes32 slicesRoot, bytes32 supplyCounterId, bytes32 recipientCounterId, uint64 totalQuantity, uint64 perRecipientCap, uint8 deliveryMode, bool prepared) p) view returns (bytes32)",
  "function sliceHash(uint256 index, (uint256 collectionId, bytes32 phaseId, address payer, address authorizer, address[] initialRecipients, address[] beneficiaries, bytes[] tokenData, bytes32[] mintCommitments, bytes32 expectedPolicyHash, bytes32 authorizationId, bytes32 contextHash, bytes resolverData) b) view returns (bytes32)",
  "function sliceAuthorization(uint256 collectionId, bytes32 phaseId, uint256 index) view returns (bytes32)",
  "function sliceUsed(uint256, bytes32, uint256) view returns (bool)",
  "function nftClaim(uint256 tokenId) view returns ((uint256 collectionId, bytes32 phaseId, address beneficiary))",
  "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
  "function distribute((address operator, bytes32 slicesRoot, bytes32 supplyCounterId, bytes32 recipientCounterId, uint64 totalQuantity, uint64 perRecipientCap, uint8 deliveryMode, bool prepared) p, uint256 index, bytes32[] proof, (uint256 collectionId, bytes32 phaseId, address payer, address authorizer, address[] initialRecipients, address[] beneficiaries, bytes[] tokenData, bytes32[] mintCommitments, bytes32 expectedPolicyHash, bytes32 authorizationId, bytes32 contextHash, bytes resolverData) b, bytes gateData) payable returns (uint256[] tokenIds, bytes32 root)",
  "function claimNft(uint256 tokenId, address receiver) returns (bool)",
  "function claimNftFor(uint256 tokenId, bool walletWide, uint256 index) returns (bool)",
  "event DistributionSliceExecuted(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed phaseId, uint256 indexed sliceIndex, bytes32 sliceHash, bytes32 operationRoot, uint256 quantity)",
  "event AirdropDeliveryDiverted(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed phaseId, uint256 indexed tokenId, address beneficiary)",
  "event AirdropNftClaimCompleted(uint16 schemaVersion, uint256 indexed collectionId, uint256 indexed tokenId, address indexed receiver)",
  "function mintLedger() view returns (address)",
  "function phase(uint256 collectionId, bytes32 phaseId) view returns (bool exists, (bool paused, uint64 startTime, uint64 endTime, uint32 maxBatchQuantity, bytes32 configHash, bytes32 metadataHash) config)",
  "function phaseExecutor(uint256, bytes32, address) view returns (bool)",
  "function phasePolicyHash(uint256, bytes32) view returns (bytes32)",
  "function phaseCounterIds(uint256 collectionId, bytes32 phaseId) view returns (bytes32[])",
  "function counterConfig(uint256 collectionId, bytes32 phaseId, bytes32 counterId) view returns ((bool enabled, uint8 keyMode, uint8 capMode, uint8 deltaMode, uint64 staticCap, uint64 staticIncrement, bytes32 counterConfigHash))",
  "function nextOperationNonce() view returns (uint256)",
  "function previewSingleStepMintOperation((uint256 collectionId, bytes32 phaseId, address payer, address authorizer, address[] initialRecipients, address[] beneficiaries, bytes[] tokenData, bytes32[] mintCommitments, bytes32 expectedPolicyHash, bytes32 authorizationId, bytes32 contextHash, bytes resolverData) batch, bytes gateData) view returns (bytes32 operationRoot, bytes32[] operationIds)",
  "function previewPreparedNativeMintOperation((uint256 collectionId, bytes32 phaseId, address payer, address authorizer, address[] initialRecipients, address[] beneficiaries, bytes[] tokenData, bytes32[] mintCommitments, bytes32 expectedPolicyHash, bytes32 authorizationId, bytes32 contextHash, bytes resolverData) batch, bytes gateData) view returns (bytes32 operationRoot, bytes32[] operationIds)",
  "function canMint((uint256 collectionId, bytes32 phaseId, address payer, address authorizer, address[] initialRecipients, address[] beneficiaries, bytes[] tokenData, bytes32[] mintCommitments, bytes32 expectedPolicyHash, bytes32 authorizationId, bytes32 contextHash, bytes resolverData) batch, address executor, bytes gateData) view returns ((bool allowed, bytes4 reason, bytes32 policyHash, bytes32 gateHash, uint256 quantity, (bytes32 counterId, bytes32 subjectKey, bytes32 valueKey, uint64 current, uint64 increment, uint64 projected, uint64 cap, bool allowed, bytes32 resolutionHash)[] counters))",
  "event MintTokenExecuted(uint16 schemaVersion, bytes32 indexed operationId, uint256 indexed tokenId, bytes32 indexed operationRoot, uint256 collectionId, bytes32 phaseId, uint256 tokenIndex, address initialRecipient, address beneficiary, bytes32 tokenDataHash, bytes32 mintCommitment)",
  "event PreparedMintStarted(uint16 schemaVersion, bytes32 indexed operationId, uint256 indexed tokenId, uint256 indexed collectionId, bytes32 operationRoot, uint256 collectionSerial, address beneficiary, bytes32 tokenDataHash, bytes32 mintCommitment)",
  "event PreparedMintCompleted(uint16 schemaVersion, bytes32 indexed operationId, uint256 indexed tokenId, uint256 indexed collectionId, bytes32 operationRoot, address initialRecipient)",
  "event MintAuthorizationConsumed(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed phaseId, bytes32 indexed authorizationId, bytes32 boundPolicyHash, bytes32 operationRoot)",
  "event MintBatchExecuted(uint16 schemaVersion, bytes32 indexed operationRoot, uint256 indexed collectionId, bytes32 indexed phaseId, address executor, address payer, address authorizer, uint256 firstTokenId, uint256 quantity, bytes32 contextHash, bytes32 gateHash, bytes32 currentPolicyHash, bytes32 boundPolicyHash)",
  "function resolveCounter((uint256 collectionId, bytes32 phaseId, bytes32 counterId, address payer, address initialRecipient, address beneficiary, address executor, address authorizer, uint256 tokenIndex, bytes32 contextHash, bytes resolverData) context) view returns ((bytes32 subjectKey, uint64 effectiveCap, uint64 increment, bytes32 resolutionHash))",
  "function remainingForResolvedCounter((uint256 collectionId, bytes32 phaseId, bytes32 counterId, address payer, address initialRecipient, address beneficiary, address executor, address authorizer, uint256 tokenIndex, bytes32 contextHash, bytes resolverData) context) view returns ((bytes32 subjectKey, uint64 effectiveCap, uint64 increment, bytes32 resolutionHash) resolution, uint64 current, uint64 remaining)",
  "function counterDefinitionForManager(address manager, bytes32 definitionHash) view returns (bool exists, (uint8 scope, uint8 keyMode, bytes32 capRoot, bytes32 metadataHash) definition)",
  "function phaseRoyaltyPolicy(uint256 collectionId, bytes32 phaseId) view returns ((bool configured, bytes32 applicationConfigHash, address resolver, bytes32 resolverRuntimeHash, bytes32 electionHash, bytes32 expectedModeAssignmentHash, bytes32 expectedSourceRoyaltyPolicyHash))",
  "function phaseRoyaltyConfigHash(uint256 collectionId, bytes32 phaseId, (bool configured, bytes32 applicationConfigHash, address resolver, bytes32 resolverRuntimeHash, bytes32 electionHash, bytes32 expectedModeAssignmentHash, bytes32 expectedSourceRoyaltyPolicyHash) policy) view returns (bytes32)",
  "function counterValue(bytes32) view returns (uint64)",
  "function isManagerAuthorizationUsed(address manager, bytes32 authorizationId) view returns (bool)",
  "function isManagerOperationRootUsed(address manager, bytes32 operationRoot) view returns (bool)",
  "event MintLedgerAuthorizationConsumed(uint16 schemaVersion, bytes32 indexed authorizationId, bytes32 indexed operationRoot, address indexed manager, bytes32 boundPolicyHash)",
  "event MintLedgerOperationRootConsumed(uint16 schemaVersion, bytes32 indexed operationRoot, address indexed manager, bytes32 currentPolicyHash, bytes32 indexed boundPolicyHash, bytes32 authorizationId)",
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function tokenCollectionIdentity(uint256 tokenId) view returns (bool mappingExists, uint256 collectionId, uint256 collectionSerial, bool burned)",
  "function tokenLifecycle(uint256 tokenId) view returns (uint8 lifecycle)",
  "function coordinatorAtMint(uint256 tokenId) view returns (address)",
  "event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)",
  "function isModuleEligible(address module, bytes32 expectedModuleType, bytes4 expectedInterfaceId) view returns (bool)",
  "function moduleRecord(address module) view returns ((uint8 status, bytes32 moduleType, bytes32 moduleVersion, bytes4 interfaceId, uint32 moduleGasLimit, bytes32 runtimeCodeHash, bytes32 deploymentManifestHash, bytes32 moduleManifestHash, string moduleManifestURI, uint64 registeredAt, uint64 statusUpdatedAt, uint64 revision))",
  "function globalDelegationHashes(bytes32, uint256) view returns (address delegatorAddress, address delegationAddress, uint256 registeredDate, uint256 expiryDate, bool allTokens, uint256 tokens)",
  "function collectionRevealPolicy(uint256 collectionId) view returns ((bool declared, uint8 requestMode, bytes32 revealOwnerRole, uint64 requestSLOBlocks, uint256 revealFeePerTokenWei))",
  "function collectionEntropyPolicy(uint256) view returns ((bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord))",
  "function revealFeeEscrow(uint256) view returns (uint256)",
  "event RevealFeeEscrowFunded(uint16 schemaVersion, uint256 indexed collectionId, address indexed funder, uint256 amountWei, uint256 escrowWei)",
  "event RevealFeeEscrowSpent(uint16 schemaVersion, uint256 indexed collectionId, uint256 indexed tokenId, uint256 amountWei, uint256 escrowWei)",
  "event ImmediateRevealAttempt(uint16 schemaVersion, uint256 indexed collectionId, uint256 indexed tokenId, bool succeeded, bytes32 requestKey, uint256 providerRequestId, uint256 returnDataSize, bytes failurePrefix)",
  "function royaltySnapshot(uint256 tokenId) view returns ((bool exists, uint256 collectionId, uint256 tokenId, address manager, bytes32 operationRoot, bytes32 operationId, bytes32 preparedProofHash, bytes32 electionHash, bytes32 sourceAssignmentHash, bytes32 modeAssignmentHash, bytes32 sourceRoyaltyPolicyHash, bytes32 tokenAssignmentHash, bytes32 tokenRoyaltyPolicyHash, bytes32 tokenConfigHash))",
]);

const safeAbi = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);


export interface DistributionMerkleCodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}

/** Acquire runtime/link pins from reviewed release deployment metadata. */
export interface DistributionMerkleDeployment {
  readonly chainId: bigint;
  readonly distributor: DistributionMerkleCodePin;
  readonly core: DistributionMerkleCodePin;
  readonly manager: DistributionMerkleCodePin;
  readonly ledger: DistributionMerkleCodePin;
  readonly moduleRegistry: DistributionMerkleCodePin;
  readonly delegateRegistry: DistributionMerkleCodePin;
  readonly linkedDependencies: readonly DistributionMerkleCodePin[];
  /** Reviewed fixed libraries reachable by claimNftFor, including its self alias. */
  readonly delegationLinkedDependencies: readonly DistributionMerkleCodePin[];
}

export interface DistributionMerkleBlock {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}

export interface DistributionMerkleNftClaim {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly beneficiary: Address;
}

/** Original globalDelegationHashes six-word row; no boolean-getter substitution. */
export type DistributionMerkleDelegationRow = readonly [
  delegatorAddress: Address,
  delegationAddress: Address,
  registeredDate: bigint,
  expiryDate: bigint,
  allTokens: boolean,
  tokens: bigint,
];

export interface DistributionMerkleGate {
  readonly gate: Address;
  readonly gateConfigHash: Hex;
  readonly gateCodehash: Hex;
  readonly gateMetadataHash: Hex;
  readonly gateSemanticVersion: bigint;
  readonly gateGasLimit: bigint;
}

export interface DistributionMerkleRoyaltyPolicy {
  readonly configured: boolean;
  readonly applicationConfigHash: Hex;
  readonly resolver: Address;
  readonly resolverRuntimeHash: Hex;
  readonly electionHash: Hex;
  readonly expectedModeAssignmentHash: Hex;
  readonly expectedSourceRoyaltyPolicyHash: Hex;
}

export interface DistributionMerkleCounterRow {
  readonly counterId: Hex;
  readonly subjectKey: Hex;
  readonly valueKey: Hex;
  readonly current: bigint;
  readonly increment: bigint;
  readonly projected: bigint;
  readonly cap: bigint;
  readonly allowed: boolean;
  readonly resolutionHash: Hex;
}

export interface DistributionMerklePreview {
  readonly allowed: boolean;
  readonly reason: Hex;
  readonly policyHash: Hex;
  readonly gateHash: Hex;
  readonly quantity: bigint;
  readonly counters: readonly DistributionMerkleCounterRow[];
}

export interface DistributionMerkleReveal {
  readonly coordinator: DistributionMerkleCodePin;
  readonly policy: EntropyCollectionPolicyReveal;
  readonly collectionPolicy: EntropyCollectionPolicyRecord | null;
  readonly escrow: bigint;
  readonly directObservation: "no-nested-gas-equivalence";
}

export interface DistributionMerkleCapture {
  readonly deployment: DistributionMerkleDeployment;
  readonly prepared: merkle.DistributionMerklePreparedCall;
  readonly observed: DistributionMerkleBlock;
  readonly preview: DistributionMerklePreview | null;
  readonly counters: readonly merkle.DistributionMerkleCounterObservation[];
  readonly royalty: DistributionMerkleRoyaltyPolicy | null;
  readonly gate: DistributionMerkleGate | null;
  readonly reveal: DistributionMerkleReveal | null;
  readonly firstOperationNonce: bigint | null;
  /** The original prepared preview supports only one token; larger batches retain null. */
  readonly operationRoot: Hex | null;
  readonly operationIds: readonly Hex[];
  readonly claim: DistributionMerkleNftClaim | null;
  readonly claimOwner: Address | null;
  readonly delegation: DistributionMerkleDelegationRow | null;
  readonly gasParameters: Readonly<Record<string, bigint>>;
  readonly dependencies: readonly DistributionMerkleCodePin[];
  readonly captureHash: Hex;
  readonly admissionAuthority: "original-distributor-call-simulation";
}

type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransactionReceipt" | "getTransaction">;

function freeze<T>(value: T): T {
  if (value !== null && typeof value === "object") {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}

function copy<T>(value: T): T {
  return structuredClone(value);
}

function bytes(value: unknown, limit = MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > limit) {
    throw Error("Bounded canonical bytes required");
  }
  return value.toLowerCase() as Hex;
}

function hash(value: unknown, zero = false): Hex {
  const result = bytes(value, 32);
  if (!isHexString(result, 32) || (!zero && result === ZERO)) throw Error("Nonzero bytes32 required");
  return result;
}

function address(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Address required");
  const result = getAddress(value) as Address;
  if (!zero && result === ADDRESS_ZERO) throw Error("Nonzero address required");
  return result;
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error("Unsigned bigint required");
  return value;
}

function index(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw Error("Concrete block/index required");
  return value;
}

function gas(value: unknown): bigint {
  const result = uint(value);
  if (result === 0n || result > 100_000_000n) throw Error("Explicit bounded simulation gas required");
  return result;
}

function stable(value: any): string {
  if (typeof value === "bigint") return `bigint:${value}`;
  if (typeof value === "string") return /^0x[0-9a-f]*$/i.test(value) ? value.toLowerCase() : JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map(key => `${key}:${stable(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}

function equal(actual: unknown, expected: unknown, label: string): void {
  if (stable(actual) !== stable(expected)) throw Error(`${label} mismatch`);
}

function pinInput(value: DistributionMerkleCodePin): DistributionMerkleCodePin {
  return freeze({ address: address(value.address), codeHash: hash(value.codeHash) });
}

function deployment(value: DistributionMerkleDeployment): DistributionMerkleDeployment {
  const input = copy(value);
  if (!Array.isArray(input.linkedDependencies) || input.linkedDependencies.length > 256) throw Error("Linked dependency bound");
  if (!Array.isArray(input.delegationLinkedDependencies) || input.delegationLinkedDependencies.length > 256) throw Error("Delegated claim library bound");
  return freeze({
    chainId: uint(input.chainId),
    distributor: pinInput(input.distributor),
    core: pinInput(input.core),
    manager: pinInput(input.manager),
    ledger: pinInput(input.ledger),
    moduleRegistry: pinInput(input.moduleRegistry),
    delegateRegistry: pinInput(input.delegateRegistry),
    linkedDependencies: input.linkedDependencies.map(pinInput),
    delegationLinkedDependencies: input.delegationLinkedDependencies.map(pinInput),
  });
}

function context(d: DistributionMerkleDeployment): merkle.DistributionMerkleContext {
  return {
    chainId: d.chainId,
    distributor: d.distributor.address,
    core: d.core.address,
    manager: d.manager.address,
    ledger: d.ledger.address,
  };
}

async function block(provider: Reader, tag: number): Promise<DistributionMerkleBlock> {
  const found = await provider.getBlock(index(tag));
  if (!found || found.number !== tag) throw Error("Exact block unavailable");
  return freeze({ blockNumber: tag, blockHash: hash(found.hash), timestamp: BigInt(found.timestamp) });
}

async function unchanged(provider: Reader, observed: DistributionMerkleBlock): Promise<void> {
  equal(await block(provider, observed.blockNumber), observed, "Reorg block");
}

async function pin(provider: Reader, p: DistributionMerkleCodePin, tag: number): Promise<void> {
  const code = bytes(await provider.getCode(p.address, tag), 131072);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || keccak256(code) !== p.codeHash) {
    throw Error("Reviewed runtime pin mismatch");
  }
}

function plain(type: ParamType, value: any): any {
  if (type.baseType === "array") return Array.from(value, child => plain(type.arrayChildren!, child));
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map((child, i) => [child.name, plain(child, value[i])]));
  return value;
}

async function read(
  provider: Reader,
  target: Address,
  method: string,
  args: readonly unknown[],
  tag: number,
  from?: Address,
): Promise<any[]> {
  const raw = bytes(await provider.call({ to: target, data: abi.encodeFunctionData(method, args), blockTag: tag,
    ...(from === undefined ? {} : { from }) }));
  const decoded = abi.decodeFunctionResult(method, raw);
  equal(abi.encodeFunctionResult(method, decoded), raw, "Canonical original return");
  return abi.getFunction(method)!.outputs.map((type, i) => plain(type, decoded[i]));
}

async function addPin(
  provider: Reader,
  dependencies: DistributionMerkleCodePin[],
  p: DistributionMerkleCodePin,
  tag: number,
): Promise<void> {
  const value = pinInput(p);
  const existing = dependencies.find(row => row.address === value.address);
  if (existing) equal(existing, value, "Repeated dependency runtime");
  else dependencies.push(value);
  await pin(provider, value, tag);
}

async function bindings(provider: Reader, d: DistributionMerkleDeployment, tag: number): Promise<void> {
  for (const p of [d.distributor, d.core, d.manager, d.ledger]) await pin(provider, p, tag);
  equal((await read(provider, d.distributor.address, "core", [], tag))[0], d.core.address, "Distributor Core");
  equal((await read(provider, d.distributor.address, "coreCodeHash", [], tag))[0], d.core.codeHash, "Distributor Core runtime");
  equal((await read(provider, d.distributor.address, "manager", [], tag))[0], d.manager.address, "Distributor Manager");
  equal((await read(provider, d.distributor.address, "managerCodeHash", [], tag))[0], d.manager.codeHash, "Distributor Manager runtime");
  equal((await read(provider, d.manager.address, "core", [], tag))[0], d.core.address, "Manager Core");
  equal((await read(provider, d.manager.address, "mintLedger", [], tag))[0], d.ledger.address, "Actual Manager Ledger");
}

export interface DistributionMerkleProgramInspection {
  readonly deployment: DistributionMerkleDeployment;
  readonly observed: DistributionMerkleBlock;
  readonly program: merkle.DistributionMerkleProgram;
  readonly phaseAdmissionChecked: false;
}

/** The original getter permits a registered definition before phase configuration. */
export async function inspectDistributionMerkleProgram(
  provider: Reader,
  deploymentInput: DistributionMerkleDeployment,
  manifestInput: OperatorDistributionManifest,
  recipientCounterConfigHash: Hex,
  options: { readonly blockTag: number },
): Promise<DistributionMerkleProgramInspection> {
  const d = deployment(deploymentInput);
  const manifest = copy(manifestInput);
  const definitionHash = hash(recipientCounterConfigHash);
  const tag = index(options.blockTag);
  const observed = await block(provider, tag);
  equal((await provider.getNetwork()).chainId, d.chainId, "Deployment chain");
  await bindings(provider, d, tag);
  equal(manifest.context, { chainId: d.chainId, distributor: d.distributor.address, core: d.core.address, manager: d.manager.address }, "Manifest deployment");
  const [exists, definition] = await read(provider, d.ledger.address, "counterDefinitionForManager", [d.manager.address, definitionHash], tag);
  const program = merkle.prepareDistributionMerkleProgram(manifest, { counterConfigHash: definitionHash, exists, definition });
  equal((await read(provider, d.distributor.address, "merkleProgramHash", [manifest.collectionId, manifest.phaseId, manifest.program, definitionHash], tag))[0],
    program.applicationConfigHash, "Actual Manager-selected Merkle program hash");
  await unchanged(provider, observed);
  return freeze({ deployment: d, observed, program, phaseAdmissionChecked: false });
}

/** A local claim read imposes no current Manager, phase, module or delegation admission. */
export async function inspectDistributionMerkleClaim(
  provider: Reader,
  deploymentInput: DistributionMerkleDeployment,
  tokenId: bigint,
  options: { readonly blockTag: number },
): Promise<{ readonly observed: DistributionMerkleBlock; readonly claim: DistributionMerkleNftClaim }> {
  const d = deployment(deploymentInput);
  const token = uint(tokenId);
  const tag = index(options.blockTag);
  const observed = await block(provider, tag);
  equal((await provider.getNetwork()).chainId, d.chainId, "Claim chain");
  await pin(provider, d.distributor, tag);
  const [claim] = await read(provider, d.distributor.address, "nftClaim", [token], tag);
  if (claim.beneficiary === ADDRESS_ZERO) equal(claim, { collectionId: 0n, phaseId: ZERO, beneficiary: ADDRESS_ZERO }, "Empty claim");
  await unchanged(provider, observed);
  return freeze({ observed, claim });
}


async function reveal(
  provider: Reader,
  d: DistributionMerkleDeployment,
  collectionId: bigint,
  dependencies: DistributionMerkleCodePin[],
  tag: number,
): Promise<DistributionMerkleReveal> {
  const pointer = await read(provider, d.core.address, "getSatellitePointer", [id("ENTROPY_COORDINATOR")], tag);
  const coordinator = pinInput({ address: pointer[0], codeHash: pointer[1] });
  await addPin(provider, dependencies, coordinator, tag);
  equal((await read(provider, coordinator.address, "core", [], tag))[0], d.core.address, "Reveal Core");
  const [policy] = await read(provider, coordinator.address, "collectionRevealPolicy", [collectionId], tag);
  let supported = false;
  try {
    const response = bytes(await provider.call({ to: coordinator.address,
      data: abi.encodeFunctionData("supportsInterface", [ENTROPY_COLLECTION_POLICY_INTERFACE_ID]), blockTag: tag }), 4096);
    if (response !== "0x") {
      if (response.length !== 66 || BigInt(response) > 1n) throw Error("Malformed entropy capability observation");
      supported = BigInt(response) === 1n;
    }
  } catch (error: any) {
    if (error?.code !== "CALL_EXCEPTION") throw error;
  }
  const collectionPolicy: EntropyCollectionPolicyRecord | null = supported
    ? (await read(provider, coordinator.address, "collectionEntropyPolicy", [collectionId], tag))[0]
    : null;
  if (collectionPolicy?.explicitPolicy && collectionPolicy.mode !== 2n) {
    equal(policy, { declared: false, requestMode: 0n, revealOwnerRole: ZERO, requestSLOBlocks: 0n, revealFeePerTokenWei: 0n }, "Canonical no-reveal policy");
  } else if (!policy.declared || policy.requestMode > 1n) {
    throw Error("Original ASYNC declaration required");
  }
  const [escrow] = await read(provider, coordinator.address, "revealFeeEscrow", [collectionId], tag);
  return freeze({ coordinator, policy, collectionPolicy, escrow, directObservation: "no-nested-gas-equivalence" });
}

async function moduleAdmission(
  provider: Reader,
  d: DistributionMerkleDeployment,
  observed: DistributionMerkleBlock,
  dependencies: DistributionMerkleCodePin[],
): Promise<void> {
  const tag = observed.blockNumber;
  const target = d.distributor.address;
  for (const p of [d.moduleRegistry, d.delegateRegistry, ...d.linkedDependencies]) await addPin(provider, dependencies, p, tag);
  equal((await read(provider, target, "moduleRegistry", [], tag))[0], d.moduleRegistry.address, "Distributor registry");
  equal((await read(provider, target, "registryCodeHash", [], tag))[0], d.moduleRegistry.codeHash, "Distributor registry runtime");
  equal((await read(provider, d.manager.address, "moduleRegistry", [], tag))[0], d.moduleRegistry.address, "Manager registry");
  for (const [kind, p] of [["MINT_MANAGER", d.manager], ["MODULE_REGISTRY", d.moduleRegistry]] as const) {
    equal((await read(provider, d.core.address, "getSatellitePointer", [id(kind)], tag)).slice(0, 2), [p.address, p.codeHash], "Core selected dependency");
  }
  equal((await read(provider, target, "supportsInterface", ["0xe1ceb09a"], tag))[0], true, "Original distribution interface");
  equal((await read(provider, target, "supportsInterface", ["0x9f2d3027"], tag))[0], true, "Additive Merkle interface");
  equal((await read(provider, d.moduleRegistry.address, "isModuleEligible", [target, id("OPERATOR_DISTRIBUTION"), "0xe1ceb09a"], tag))[0], true, "Distribution module eligibility");
  const [delegate, runtime, usecase, base] = await Promise.all([
    read(provider, target, "delegateRegistry", [], tag), read(provider, target, "delegateRegistryCodeHash", [], tag),
    read(provider, target, "delegationUsecase", [], tag), read(provider, target, "baseManifestHash", [], tag),
  ]);
  equal([delegate[0], runtime[0]], [d.delegateRegistry.address, d.delegateRegistry.codeHash], "Original delegation binding");
  if (usecase[0] === 0n || usecase[0] === 998n || usecase[0] === 999n) throw Error("Original delegation usecase invalid");
  hash(base[0]);
  const manifest = coder.encode(["bytes32", "uint256", "address", "bytes32", "address", "address", "bytes32", "uint256"],
    [id("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"), d.chainId, target, base[0], d.core.address, delegate[0], runtime[0], usecase[0]]);
  equal((await read(provider, target, "moduleManifestBytes", [], tag))[0], manifest, "Original complete module manifest");
  const [record] = await read(provider, d.moduleRegistry.address, "moduleRecord", [target], tag);
  if (record.status !== 1n || record.runtimeCodeHash !== d.distributor.codeHash
    || record.moduleManifestHash !== keccak256(manifest) || record.deploymentManifestHash === ZERO
    || record.registeredAt === 0n || record.registeredAt > observed.timestamp
    || record.statusUpdatedAt < record.registeredAt || record.statusUpdatedAt > observed.timestamp || record.revision === 0n) {
    throw Error("Active original distribution manifest admission");
  }
}

async function counterObservations(
  provider: Reader,
  d: DistributionMerkleDeployment,
  collectionId: bigint,
  phaseId: Hex,
  tag: number,
): Promise<merkle.DistributionMerkleCounterObservation[]> {
  const [ids] = await read(provider, d.manager.address, "phaseCounterIds", [collectionId, phaseId], tag);
  if (ids.length > 16 || new Set(ids).size !== ids.length) throw Error("Complete ordered counter inventory bound");
  const observations: merkle.DistributionMerkleCounterObservation[] = [];
  for (const counterId of ids) {
    const [config] = await read(provider, d.manager.address, "counterConfig", [collectionId, phaseId, counterId], tag);
    const [definitionExists, definition] = await read(provider, d.ledger.address, "counterDefinitionForManager", [d.manager.address, config.counterConfigHash], tag);
    observations.push({ counterId, config, definitionExists, definition });
  }
  return observations;
}

function operationIds(
  batch: { readonly tokenData: readonly Hex[]; readonly mintCommitments: readonly Hex[] },
  root: Hex,
  firstNonce: bigint,
): Hex[] {
  return batch.tokenData.map((data, i) => keccak256(coder.encode(
    ["bytes32", "bytes32", "uint256", "uint256", "bytes32", "bytes32"],
    [id("6529STREAM_MINT_TOKEN_OPERATION_ID_V1"), root, firstNonce + BigInt(i), BigInt(i), keccak256(data), batch.mintCommitments[i]],
  )) as Hex);
}

async function checkCounterRows(
  provider: Reader,
  d: DistributionMerkleDeployment,
  prepared: Extract<merkle.DistributionMerklePreparedCall, { kind: "distribute" }>,
  observations: readonly merkle.DistributionMerkleCounterObservation[],
  preview: DistributionMerklePreview,
  tag: number,
): Promise<void> {
  const b = prepared.batch;
  let cursor = 0;
  let proofIndex = 0;
  for (const observation of observations) {
    const config = observation.config;
    const count = config.keyMode === 6n ? 1 : b.beneficiaries.length;
    const merkleCounter = config.capMode === 3n;
    for (let i = 0; i < count; i++) {
      const row = preview.counters[cursor++];
      if (!row || row.counterId !== observation.counterId) throw Error("Original counter row ordering");
      // Original gate validation preserves batch.authorizer, which is zero here.
      // Replay every original row, including the CONTEXT batch sentinel.
      {
        const x: accounting.MintCounterKeyContext = {
          collectionId: b.collectionId, phaseId: b.phaseId, counterId: observation.counterId,
          payer: b.payer, initialRecipient: b.initialRecipients[i]!, beneficiary: b.beneficiaries[i]!,
          executor: d.distributor.address, authorizer: b.authorizer,
          tokenIndex: config.keyMode === 6n ? (1n << 256n) - 1n : BigInt(i), contextHash: b.contextHash,
          resolverData: merkleCounter ? accounting.encodeMintCounterAllowlistProof(prepared.input.proofs[proofIndex]![i]!) : "0x",
        };
        const expected = accounting.resolveMintCounterRead({ chainId: d.chainId, manager: d.manager.address, ledger: d.ledger.address },
          { phaseExists: true, config: observation.config, definitionExists: observation.definitionExists, definition: observation.definition }, x);
        const [resolution, current, remaining] = await read(provider, d.manager.address, "remainingForResolvedCounter", [x], tag, d.distributor.address);
        equal(resolution, expected.resolution, "Original Manager counter resolution");
        equal([row.subjectKey, row.valueKey, row.current, row.increment, row.cap, row.resolutionHash],
          [resolution.subjectKey, expected.valueKey, current, resolution.increment, resolution.effectiveCap, resolution.resolutionHash], "Actual counter preview/read joins");
        equal(remaining, accounting.mintCounterReadRemaining(config.capMode, row.cap, current), "Counter headroom");
      }
      equal((await read(provider, d.ledger.address, "counterValue", [row.valueKey], tag))[0], row.current, "Ledger current counter");
      const projected = row.current + preview.counters.filter(other => other.valueKey === row.valueKey).reduce((sum, other) => sum + other.increment, 0n);
      if (projected >= 1n << 64n || (row.cap !== 0n && projected > row.cap)) throw Error("Projected duplicate cap exceeded");
      equal([row.projected, row.allowed], [projected, true], "Complete batch projected allowance");
    }
    if (merkleCounter) proofIndex++;
  }
  if (cursor !== preview.counters.length) throw Error("Unexpected preview counter rows");
}

function captureBody(value: Omit<DistributionMerkleCapture, "captureHash"> | DistributionMerkleCapture) {
  const { captureHash: _ignored, ...body } = value as DistributionMerkleCapture;
  return body;
}

function captureHash(value: Omit<DistributionMerkleCapture, "captureHash"> | DistributionMerkleCapture): Hex {
  return keccak256(toUtf8Bytes(stable(captureBody(value)))) as Hex;
}

export async function captureDistributionMerkle(
  provider: Reader,
  deploymentInput: DistributionMerkleDeployment,
  preparedInput: merkle.DistributionMerklePreparedCall,
  options: { readonly blockTag: number },
): Promise<DistributionMerkleCapture> {
  const d = deployment(deploymentInput);
  const prepared = merkle.normalizeDistributionMerklePreparedCall(preparedInput);
  const tag = index(options.blockTag);
  const observed = await block(provider, tag);
  equal((await provider.getNetwork()).chainId, d.chainId, "Deployment chain");
  equal(prepared.context, context(d), "Prepared runtime coordinates");
  const dependencies: DistributionMerkleCodePin[] = [];
  await addPin(provider, dependencies, d.distributor, tag);
  await addPin(provider, dependencies, d.core, tag);
  equal((await read(provider, d.distributor.address, "core", [], tag))[0], d.core.address, "Distributor Core");
  equal((await read(provider, d.distributor.address, "coreCodeHash", [], tag))[0], d.core.codeHash, "Distributor Core runtime");
  let preview: DistributionMerklePreview | null = null;
  let counters: merkle.DistributionMerkleCounterObservation[] = [];
  let royalty: DistributionMerkleRoyaltyPolicy | null = null;
  let gate: DistributionMerkleGate | null = null;
  let quote: DistributionMerkleReveal | null = null;
  let firstOperationNonce: bigint | null = null;
  let operationRoot: Hex | null = null;
  let ids: Hex[] = [];
  let claim: DistributionMerkleNftClaim | null = null;
  let claimOwner: Address | null = null;
  let delegation: DistributionMerkleDelegationRow | null = null;
  const gasParameters: Record<string, bigint> = {};
  const gasRead = async (name: string) => {
    const [value] = await read(provider, d.distributor.address, "gasParameter", [id(`6529STREAM_GGP_${name}`)], tag);
    gasParameters[name] = uint(value);
    if (value === 0n) throw Error("Original gas parameter required");
  };
  await gasRead("SALE_NFT_DELIVERY_GAS_LIMIT");
  if (prepared.kind === "claim") {
    const input = prepared.input;
    if (input.kind === "claimNftFor") {
      for (const dependency of d.delegationLinkedDependencies) await addPin(provider, dependencies, dependency, tag);
    }
    [claim] = await read(provider, d.distributor.address, "nftClaim", [input.tokenId], tag);
    if (claim!.beneficiary === ADDRESS_ZERO || claim!.collectionId === 0n || claim!.phaseId === ZERO) throw Error("Owed claim unavailable");
    [claimOwner] = await read(provider, d.core.address, "ownerOf", [input.tokenId], tag);
    equal(claimOwner, d.distributor.address, "Retained claim custody");
    if (input.kind === "claimNft") {
      equal(prepared.caller, claim!.beneficiary, "Own claim principal");
    } else if (prepared.caller !== claim!.beneficiary) {
      await gasRead("DELEGATE_REGISTRY_GAS_LIMIT");
      await addPin(provider, dependencies, d.delegateRegistry, tag);
      equal((await read(provider, d.distributor.address, "delegateRegistry", [], tag))[0], d.delegateRegistry.address, "Pinned original delegation registry");
      equal((await read(provider, d.distributor.address, "delegateRegistryCodeHash", [], tag))[0], d.delegateRegistry.codeHash, "Pinned delegation runtime");
      const [usecase] = await read(provider, d.distributor.address, "delegationUsecase", [], tag);
      if (usecase === 0n || usecase === 998n || usecase === 999n) throw Error("Original delegation usecase");
      const scope = input.walletWide ? "0x8888888888888888888888888888888888888888" : d.core.address;
      const key = solidityPackedKeccak256(["address", "address", "address", "uint256"], [claim!.beneficiary, scope, prepared.caller, usecase]);
      const row = await read(provider, d.delegateRegistry.address, "globalDelegationHashes", [key, input.delegationIndex], tag);
      delegation = [row[0], row[1], row[2], row[3], row[4], row[5]];
      if (delegation[0] !== claim!.beneficiary || delegation[1] !== prepared.caller || delegation[2] > observed.timestamp
        || delegation[3] <= observed.timestamp || delegation[4] !== true || delegation[5] !== 0n) throw Error("Live original delegation row invalid");
    }
  } else {
    await bindings(provider, d, tag);
    await addPin(provider, dependencies, d.manager, tag);
    await addPin(provider, dependencies, d.ledger, tag);
    await moduleAdmission(provider, d, observed, dependencies);
    await gasRead("REVEAL_ATTEMPT_GAS_LIMIT");
    await gasRead("DELEGATE_REGISTRY_GAS_LIMIT");
    const b = prepared.batch;
    const manifest = prepared.input.program.manifest;
    const program = manifest.program;
    equal(prepared.caller, program.operator, "Committed operator principal");
    equal((await read(provider, d.distributor.address, "sliceUsed", [b.collectionId, b.phaseId, BigInt(prepared.input.sliceIndex)], tag))[0], false, "Unused distribution slice");
    const [exists, phase] = await read(provider, d.manager.address, "phase", [b.collectionId, b.phaseId], tag);
    if (!exists || phase.paused || b.beneficiaries.length > Number(phase.maxBatchQuantity)
      || (phase.startTime !== 0n && phase.startTime > observed.timestamp)
      || (phase.endTime !== 0n && phase.endTime < observed.timestamp)) throw Error("Current phase admission");
    equal((await read(provider, d.manager.address, "phaseExecutor", [b.collectionId, b.phaseId, d.distributor.address], tag))[0], true, "Distribution phase executor");
    [gate] = await read(provider, d.manager.address, "phaseGate", [b.collectionId, b.phaseId], tag);
    if (gate!.gate !== ADDRESS_ZERO) await addPin(provider, dependencies, { address: gate!.gate, codeHash: gate!.gateCodehash }, tag);
    counters = await counterObservations(provider, d, b.collectionId, b.phaseId, tag);
    equal(counters, prepared.input.counters, "Actual ordered counter observations");
    const recipient = counters.find(row => row.counterId === program.recipientCounterId);
    const supply = counters.find(row => row.counterId === program.supplyCounterId);
    if (!recipient || !supply) throw Error("Required counter inventory");
    const actualProgram = merkle.prepareDistributionMerkleProgram(manifest, {
      counterConfigHash: recipient.config.counterConfigHash, exists: recipient.definitionExists, definition: recipient.definition,
    });
    equal(actualProgram, prepared.input.program, "Actual configured recipient definition");
    equal((await read(provider, d.distributor.address, "merkleProgramHash", [b.collectionId, b.phaseId, program, recipient.config.counterConfigHash], tag))[0],
      actualProgram.applicationConfigHash, "Actual Merkle publication commitment");
    [royalty] = await read(provider, d.manager.address, "phaseRoyaltyPolicy", [b.collectionId, b.phaseId], tag);
    let phaseCommitment = actualProgram.applicationConfigHash;
    if (royalty!.configured) {
      if (!program.prepared) throw Error("Royalty snapshot requires prepared path");
      equal(royalty!.applicationConfigHash, phaseCommitment, "Royalty application commitment");
      await addPin(provider, dependencies, { address: royalty!.resolver, codeHash: royalty!.resolverRuntimeHash }, tag);
      [phaseCommitment] = await read(provider, d.manager.address, "phaseRoyaltyConfigHash", [b.collectionId, b.phaseId, royalty], tag);
    }
    equal(phase.configHash, phaseCommitment, "Original phase/royalty Merkle config");
    equal((await read(provider, d.distributor.address, "sliceHash", [BigInt(prepared.input.sliceIndex), b], tag))[0], b.contextHash, "Original independent slice commitment");
    equal((await read(provider, d.distributor.address, "sliceAuthorization", [b.collectionId, b.phaseId, BigInt(prepared.input.sliceIndex)], tag))[0], b.authorizationId, "Original slice authorization");
    [preview] = await read(provider, d.manager.address, "canMint", [b, d.distributor.address, prepared.input.gateData], tag, d.distributor.address);
    if (!preview!.allowed || preview!.reason !== "0x00000000" || preview!.quantity !== BigInt(b.beneficiaries.length)
      || preview!.counters.length > 160) throw Error("Original Manager eligibility preview refusal");
    equal(preview!.policyHash, (await read(provider, d.manager.address, "phasePolicyHash", [b.collectionId, b.phaseId], tag))[0], "Current Manager policy");
    await checkCounterRows(provider, d, prepared, counters, preview!, tag);
    const supplySubject = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "bytes32"],
      [id("6529STREAM_MINT_COUNTER_SUBJECT_V1"), d.chainId, d.ledger.address, 1n, b.collectionId, b.phaseId, program.supplyCounterId]));
    const supplyRows = preview!.counters.filter(row => row.counterId === program.supplyCounterId);
    if (supplyRows.length !== b.beneficiaries.length || supplyRows.some(row => row.subjectKey !== supplySubject)) throw Error("Original PHASE supply subject required");
    [firstOperationNonce] = await read(provider, d.manager.address, "nextOperationNonce", [], tag);
    if (!program.prepared || b.beneficiaries.length === 1) {
      const method = program.prepared ? "previewPreparedNativeMintOperation" : "previewSingleStepMintOperation";
      const values = await read(provider, d.manager.address, method, [b, prepared.input.gateData], tag, d.distributor.address);
      operationRoot = hash(values[0]);
      ids = values[1].map((value: unknown) => hash(value));
      equal(ids, operationIds(b, operationRoot, firstOperationNonce!), "Original operation ID preimages");
      equal((await read(provider, d.ledger.address, "isManagerOperationRootUsed", [d.manager.address, operationRoot], tag))[0], false, "Unused operation root");
    }
    equal((await read(provider, d.ledger.address, "isManagerAuthorizationUsed", [d.manager.address, b.authorizationId], tag))[0], false, "Unused Manager authorization");
    quote = await reveal(provider, d, b.collectionId, dependencies, tag);
    equal([prepared.input.revealFeePerTokenWei, prepared.call.value],
      [quote.policy.revealFeePerTokenWei, quote.policy.revealFeePerTokenWei * BigInt(b.beneficiaries.length)], "Exact pre-mint reveal fee quantity");
  }
  await unchanged(provider, observed);
  const body = freeze({ deployment: d, prepared, observed, preview, counters, royalty, gate, reveal: quote,
    firstOperationNonce, operationRoot, operationIds: ids, claim, claimOwner, delegation, gasParameters,
    dependencies, admissionAuthority: "original-distributor-call-simulation" as const });
  return freeze({ ...body, captureHash: captureHash(body) });
}


function normalizeCapture(input: DistributionMerkleCapture): DistributionMerkleCapture {
  const value = copy(input);
  const result = { ...value, deployment: deployment(value.deployment), prepared: merkle.normalizeDistributionMerklePreparedCall(value.prepared) };
  equal(captureHash(result), value.captureHash, "Saved immutable capture");
  return freeze(result);
}

async function validateHistorical(provider: Reader, saved: DistributionMerkleCapture): Promise<void> {
  equal(await captureDistributionMerkle(provider, saved.deployment, saved.prepared, { blockTag: saved.observed.blockNumber }), saved, "Historical capture reconstruction");
}

/** Fail closed on changed reviewed observations; recapture to review a new context. */
export async function revalidateDistributionMerkle(
  provider: Reader,
  captureInput: DistributionMerkleCapture,
  options: { readonly blockTag: number },
): Promise<DistributionMerkleCapture> {
  const saved = normalizeCapture(captureInput);
  const tag = index(options.blockTag);
  if (tag < saved.observed.blockNumber) throw Error("Revalidation predates capture");
  await validateHistorical(provider, saved);
  const current = await captureDistributionMerkle(provider, saved.deployment, saved.prepared, { blockTag: tag });
  const { observed: _oldBlock, ...oldFacts } = captureBody(saved);
  const { observed: _newBlock, ...newFacts } = captureBody(current);
  equal(newFacts, oldFacts, "Reviewed distribution currentness");
  return current;
}

export interface DistributionMerkleSimulation {
  readonly capture: DistributionMerkleCapture;
  readonly returnData: Hex;
  readonly tokenIds: readonly bigint[];
  readonly operationRoot: Hex | null;
  readonly delivered: boolean | null;
}

export async function simulateDistributionMerkle(
  provider: Reader,
  captureInput: DistributionMerkleCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint },
): Promise<DistributionMerkleSimulation> {
  const saved = normalizeCapture(captureInput);
  const tag = index(options.blockTag);
  const limit = gas(options.gasLimit);
  const capture = await revalidateDistributionMerkle(provider, saved, { blockTag: tag });
  const p = capture.prepared;
  const method = p.kind === "distribute" ? "distribute" : p.input.kind;
  const raw = bytes(await provider.call({ ...p.call, from: p.caller, blockTag: tag, gasLimit: limit }));
  const result = abi.decodeFunctionResult(method, raw);
  equal(abi.encodeFunctionResult(method, result), raw, "Canonical original simulation result");
  let tokenIds: bigint[] = [];
  let operationRoot: Hex | null = null;
  let delivered: boolean | null = null;
  if (p.kind === "distribute") {
    tokenIds = Array.from(result[0]);
    operationRoot = hash(result[1]);
    if (tokenIds.length !== p.batch.beneficiaries.length || tokenIds.some(token => token === 0n)
      || new Set(tokenIds).size !== tokenIds.length) throw Error("Original distribution simulation token inventory");
    if (capture.operationRoot !== null) equal(operationRoot, capture.operationRoot, "Original operation preview");
  } else delivered = result[0];
  await unchanged(provider, capture.observed);
  return freeze({ capture, returnData: raw, tokenIds, operationRoot, delivered });
}

export type DistributionMerkleReceiptOptions =
  | { readonly execution: "direct" }
  | { readonly execution: "safe"; readonly expectedSafeTxHash: Hex };

interface ReceiptLog {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}

interface Transport {
  readonly transactionHash: Hex;
  readonly observed: DistributionMerkleBlock;
  readonly logs: readonly ReceiptLog[];
  readonly safeIndex: number | null;
}

async function transport(
  provider: ReceiptReader,
  prepared: merkle.DistributionMerklePreparedCall,
  transactionHash: Hex,
  inputOptions: DistributionMerkleReceiptOptions,
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
    return freeze({ address: address(raw.address), topics: raw.topics.map(t => hash(t, true)), data, index: i });
  });
  const rawTx = await provider.getTransaction(txHash);
  if (!rawTx) throw Error("Transaction unavailable");
  const tx = {
    to: rawTx.to && address(rawTx.to),
    from: address(rawTx.from),
    value: uint(rawTx.value),
    data: bytes(rawTx.data, MAX_CALL_BYTES + 16384),
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
  equal([tx.chainId, (await provider.getNetwork()).chainId], [prepared.context.chainId, prepared.context.chainId], "Transaction chain");
  return freeze({ transactionHash: txHash, observed, logs, safeIndex });
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



export interface DistributionMerkleTokenReceipt {
  readonly tokenId: bigint;
  readonly operationId: Hex;
  readonly beneficiary: Address;
  readonly delivery: "direct" | "delivered" | "diverted";
  readonly claim: DistributionMerkleNftClaim;
  readonly revealAttempt: {
    readonly succeeded: boolean;
    readonly requestKey: Hex;
    readonly providerRequestId: bigint;
    readonly returnDataSize: bigint;
    readonly failurePrefix: Hex;
  } | null;
}

export interface DistributionMerkleReconciliation {
  readonly capture: DistributionMerkleCapture;
  readonly transactionHash: Hex;
  readonly observed: DistributionMerkleBlock;
  readonly operationRoot: Hex | null;
  readonly tokens: readonly DistributionMerkleTokenReceipt[];
  readonly claimOutcome: "completed" | "retained" | null;
  /** Transaction receipts do not expose the original function's EVM return bytes. */
  readonly functionReturnObserved: false;
}

function matching(
  t: Transport,
  target: Address,
  name: string,
  expected: Record<string, unknown>,
) {
  return events(t, target, abi, name).filter(event => Object.entries(expected).every(([key, value]) => stable(event.args[key]) === stable(value)));
}

function exactEvent(
  t: Transport,
  target: Address,
  name: string,
  expected: Record<string, unknown>,
) {
  const rows = matching(t, target, name, expected);
  if (rows.length !== 1) throw Error(`Expected exact ${name}`);
  return rows[0]!;
}

const emptyClaim: DistributionMerkleNftClaim = freeze({ collectionId: 0n, phaseId: ZERO, beneficiary: ADDRESS_ZERO });

async function royaltyReceipt(
  provider: Reader,
  capture: DistributionMerkleCapture,
  tokenId: bigint,
  root: Hex,
  operationId: Hex,
  tag: number,
): Promise<void> {
  const p = capture.royalty!;
  if (!p.configured) return;
  const [snapshot] = await read(provider, p.resolver, "royaltySnapshot", [tokenId], tag);
  equal([snapshot.exists, snapshot.collectionId, snapshot.tokenId, snapshot.manager, snapshot.operationRoot,
    snapshot.operationId, snapshot.electionHash, snapshot.modeAssignmentHash, snapshot.sourceRoyaltyPolicyHash],
  [true, (capture.prepared as Extract<merkle.DistributionMerklePreparedCall, { kind: "distribute" }>).batch.collectionId,
    tokenId, capture.deployment.manager.address, root, operationId, p.electionHash, p.expectedModeAssignmentHash, p.expectedSourceRoyaltyPolicyHash], "Retained original royalty snapshot");
  for (const key of ["preparedProofHash", "sourceAssignmentHash", "tokenAssignmentHash", "tokenRoyaltyPolicyHash", "tokenConfigHash"]) hash(snapshot[key]);
}

async function distributionReceipt(
  provider: Reader,
  prior: DistributionMerkleCapture,
  t: Transport,
): Promise<{ operationRoot: Hex; tokens: DistributionMerkleTokenReceipt[] }> {
  const p = prior.prepared;
  if (p.kind !== "distribute") throw Error("Distribution capture required");
  const d = prior.deployment;
  const b = p.batch;
  const program = p.input.program.manifest.program;
  const tag = t.observed.blockNumber;
  const quantity = BigInt(b.beneficiaries.length);
  const [, phase] = await read(provider, d.manager.address, "phase", [b.collectionId, b.phaseId], tag - 1);
  if (phase.endTime !== 0n && t.observed.timestamp > phase.endTime) throw Error("Phase expired at mined timestamp");
  if (prior.preview!.policyHash !== b.expectedPolicyHash) {
    const grace = await read(provider, d.ledger.address, "policyGrace", [d.manager.address, b.collectionId, b.phaseId], tag - 1);
    if (grace[0] !== b.expectedPolicyHash || t.observed.timestamp > grace[2]) throw Error("Bound policy grace expired at mined timestamp");
  }
  for (const dependency of prior.dependencies) await pin(provider, dependency, tag);
  const slice = one(t, d.distributor.address, abi, "DistributionSliceExecuted", {
    schemaVersion: 1n, collectionId: b.collectionId, phaseId: b.phaseId,
    sliceIndex: BigInt(p.input.sliceIndex), sliceHash: b.contextHash, quantity,
  });
  const root = hash(slice.args.operationRoot);
  if (prior.operationRoot !== null) equal(root, prior.operationRoot, "Reviewed operation preview");
  const ids = operationIds(b, root, prior.firstOperationNonce!);
  equal((await read(provider, d.distributor.address, "sliceUsed", [b.collectionId, b.phaseId, BigInt(p.input.sliceIndex)], tag))[0], true, "Consumed original slice");
  equal((await read(provider, d.ledger.address, "isManagerAuthorizationUsed", [d.manager.address, b.authorizationId], tag))[0], true, "Consumed original authorization");
  equal((await read(provider, d.ledger.address, "isManagerOperationRootUsed", [d.manager.address, root], tag))[0], true, "Consumed operation root");
  // For prepared multi-token batches the root has no public preview, but must still
  // be unused in the historical prestate before this exact original transaction.
  equal((await read(provider, d.ledger.address, "isManagerOperationRootUsed", [d.manager.address, root], tag - 1))[0], false, "Previously unused root");
  equal((await read(provider, d.manager.address, "nextOperationNonce", [], tag))[0], prior.firstOperationNonce! + quantity, "Exact operation nonce advancement");
  for (const row of prior.preview!.counters) {
    equal((await read(provider, d.ledger.address, "counterValue", [row.valueKey], tag))[0], row.projected, "Complete batch counter result");
  }
  const authorization = one(t, d.ledger.address, abi, "MintLedgerAuthorizationConsumed", {
    schemaVersion: 1n, authorizationId: b.authorizationId, operationRoot: root, manager: d.manager.address, boundPolicyHash: b.expectedPolicyHash,
  });
  const consumed = one(t, d.ledger.address, abi, "MintLedgerOperationRootConsumed", {
    schemaVersion: 1n, operationRoot: root, manager: d.manager.address, currentPolicyHash: prior.preview!.policyHash,
    boundPolicyHash: b.expectedPolicyHash, authorizationId: b.authorizationId,
  });
  ordered(authorization.index, consumed.index);
  let last = consumed.index;
  const gateEvents = events(t, d.manager.address, abi, "MintGateValidated");
  if (prior.gate!.gate !== ADDRESS_ZERO) {
    const gate = one(t, d.manager.address, abi, "MintGateValidated", {
      collectionId: b.collectionId, phaseId: b.phaseId, gate: prior.gate!.gate, authorizationId: b.authorizationId,
      authorizer: b.authorizer, quantity, contextHash: b.contextHash, gateHash: prior.preview!.gateHash, policyHash: b.expectedPolicyHash,
    });
    ordered(last, gate.index);
    last = gate.index;
  } else if (gateEvents.length !== 0) throw Error("Unexpected gate event");
  const tokenIds: bigint[] = [];
  const starts = events(t, d.manager.address, abi, program.prepared ? "PreparedMintStarted" : "MintTokenExecuted");
  const ends = events(t, d.manager.address, abi, "PreparedMintCompleted");
  if (starts.length !== b.beneficiaries.length || (program.prepared ? ends.length !== starts.length : ends.length !== 0)) throw Error("Complete Manager token event inventory");
  if (program.prepared && events(t, d.manager.address, abi, "MintTokenExecuted").length !== 0) throw Error("Prepared path cannot substitute single-step events");
  if (!program.prepared && events(t, d.manager.address, abi, "PreparedMintStarted").length !== 0) throw Error("Single-step path cannot include prepared events");
  for (let i = 0; i < starts.length; i++) {
    const start = starts[i]!;
    const tokenId = uint(start.args.tokenId);
    if (tokenId === 0n || tokenIds.includes(tokenId)) throw Error("Unique minted token inventory required");
    tokenIds.push(tokenId);
    const common = { schemaVersion: 1n, operationId: ids[i], tokenId, collectionId: b.collectionId, operationRoot: root,
      beneficiary: b.beneficiaries[i], tokenDataHash: keccak256(b.tokenData[i]!), mintCommitment: b.mintCommitments[i] };
    const event = exactEvent(t, d.manager.address, program.prepared ? "PreparedMintStarted" : "MintTokenExecuted",
      program.prepared ? common : { ...common, phaseId: b.phaseId, tokenIndex: BigInt(i), initialRecipient: b.initialRecipients[i] });
    ordered(last, event.index);
    last = event.index;
    if (program.prepared) {
      const completed = exactEvent(t, d.manager.address, "PreparedMintCompleted", {
        schemaVersion: 1n, operationId: ids[i], tokenId, collectionId: b.collectionId, operationRoot: root, initialRecipient: b.initialRecipients[i],
      });
      ordered(last, completed.index);
      last = completed.index;
      await royaltyReceipt(provider, prior, tokenId, root, ids[i]!, tag);
    }
    const identity = await read(provider, d.core.address, "tokenCollectionIdentity", [tokenId], tag);
    const [lifecycle] = await read(provider, d.core.address, "tokenLifecycle", [tokenId], tag);
    if (!identity[0] || identity[1] !== b.collectionId || identity[2] === 0n
      || ![2n, 3n].includes(lifecycle) || identity[3] !== (lifecycle === 3n)) throw Error("Permanent minted identity mismatch");
    if (program.prepared) equal(identity[2], event.args.collectionSerial, "Prepared collection serial");
    equal((await read(provider, d.core.address, "coordinatorAtMint", [tokenId], tag))[0], prior.reveal!.coordinator.address, "Original token entropy coordinator");
  }
  const managerAuthorization = one(t, d.manager.address, abi, "MintAuthorizationConsumed", {
    schemaVersion: 1n, collectionId: b.collectionId, phaseId: b.phaseId, authorizationId: b.authorizationId,
    boundPolicyHash: b.expectedPolicyHash, operationRoot: root,
  });
  const batch = one(t, d.manager.address, abi, "MintBatchExecuted", {
    schemaVersion: 1n, operationRoot: root, collectionId: b.collectionId, phaseId: b.phaseId,
    executor: d.distributor.address, payer: ADDRESS_ZERO, authorizer: ADDRESS_ZERO, firstTokenId: tokenIds[0], quantity,
    contextHash: b.contextHash, gateHash: prior.preview!.gateHash,
    currentPolicyHash: prior.preview!.policyHash, boundPolicyHash: b.expectedPolicyHash,
  });
  ordered(last, managerAuthorization.index, batch.index);
  last = batch.index;
  const quote = prior.reveal!;
  const policy = quote.collectionPolicy;
  const skipRequest = policy?.explicitPolicy === true && (policy.mode !== 2n || policy.renderRequirement === 1n);
  const attempts = events(t, d.distributor.address, abi, "ImmediateRevealAttempt");
  const expectsAttempt = !skipRequest && quote.policy.requestMode === 0n;
  if (attempts.length !== (expectsAttempt ? tokenIds.length : 0)) throw Error("Complete reveal attempt inventory");
  const funding = events(t, quote.coordinator.address, abi, "RevealFeeEscrowFunded");
  const spending = events(t, quote.coordinator.address, abi, "RevealFeeEscrowSpent");
  const fee = quote.policy.revealFeePerTokenWei;
  if (funding.length !== (fee === 0n ? 0 : tokenIds.length)) throw Error("Exact per-token reveal funding inventory");
  let escrow = quote.escrow;
  const accountEvents = [...funding, ...spending].sort((a, b) => a.index - b.index);
  for (const event of accountEvents) {
    equal([event.args.schemaVersion, event.args.collectionId], [1n, b.collectionId], "Reveal escrow event domain");
    if (Object.hasOwn(event.args, "funder")) {
      equal([event.args.funder, event.args.amountWei], [d.distributor.address, fee], "Exact distribution reveal funding");
      escrow += fee;
    } else {
      if (!tokenIds.includes(event.args.tokenId) || event.args.amountWei > escrow) throw Error("Original reveal spend mismatch");
      escrow -= event.args.amountWei;
    }
    equal(event.args.escrowWei, escrow, "Reveal event balance chain");
  }
  equal((await read(provider, quote.coordinator.address, "revealFeeEscrow", [b.collectionId], tag))[0], escrow, "Reveal custody end-block observation");
  const diverted = events(t, d.distributor.address, abi, "AirdropDeliveryDiverted");
  const tokens: DistributionMerkleTokenReceipt[] = [];
  for (let i = 0; i < tokenIds.length; i++) {
    const tokenId = tokenIds[i]!;
    let revealAttempt: DistributionMerkleTokenReceipt["revealAttempt"] = null;
    if (fee !== 0n) {
      ordered(last, funding[i]!.index);
      last = funding[i]!.index;
    }
    const tokenSpending = spending.filter(row => row.args.tokenId === tokenId);
    if (tokenSpending.length > 1) throw Error("Repeated per-token reveal spend");
    if (tokenSpending.length) {
      ordered(last, tokenSpending[0]!.index);
      last = tokenSpending[0]!.index;
    }
    if (expectsAttempt) {
      const event = exactEvent(t, d.distributor.address, "ImmediateRevealAttempt", { schemaVersion: 1n, collectionId: b.collectionId, tokenId });
      const a = event.args;
      if (a.succeeded) {
        if (a.requestKey === ZERO || a.returnDataSize !== 64n || a.failurePrefix !== "0x") throw Error("Successful reveal result shape");
      } else if (a.requestKey !== ZERO || a.providerRequestId !== 0n
        || BigInt((a.failurePrefix.length - 2) / 2) !== (a.returnDataSize > 256n ? 256n : a.returnDataSize)) throw Error("Failed reveal bounded result shape");
      ordered(last, event.index);
      last = event.index;
      revealAttempt = { succeeded: a.succeeded, requestKey: a.requestKey, providerRequestId: a.providerRequestId,
        returnDataSize: a.returnDataSize, failurePrefix: a.failurePrefix };
    }
    const [claim] = await read(provider, d.distributor.address, "nftClaim", [tokenId], tag);
    let delivery: DistributionMerkleTokenReceipt["delivery"] = "direct";
    const failed = diverted.filter(row => row.args.tokenId === tokenId);
    if (program.deliveryMode === 1n) {
      const transfers = matching(t, d.core.address, "Transfer", { from: d.distributor.address, to: b.beneficiaries[i], tokenId });
      if (failed.length === 1) {
        const event = exactEvent(t, d.distributor.address, "AirdropDeliveryDiverted", {
          schemaVersion: 1n, collectionId: b.collectionId, phaseId: b.phaseId, tokenId, beneficiary: b.beneficiaries[i],
        });
        if (transfers.length !== 0) throw Error("Diverted token cannot have successful delivery transfer");
        equal(claim, { collectionId: b.collectionId, phaseId: b.phaseId, beneficiary: b.beneficiaries[i] }, "Retained owed NFT claim");
        equal((await read(provider, d.core.address, "ownerOf", [tokenId], tag))[0], d.distributor.address, "Diverted NFT custody");
        ordered(last, event.index);
        last = event.index;
        delivery = "diverted";
      } else {
        if (failed.length !== 0 || transfers.length !== 1) throw Error("Successful isolated delivery evidence");
        ordered(last, transfers[0]!.index);
        last = transfers[0]!.index;
        equal(claim, emptyClaim, "Delivered token has no owed claim");
        delivery = "delivered";
      }
    } else {
      if (failed.length !== 0) throw Error("DIRECT cannot divert");
      equal(claim, emptyClaim, "DIRECT has no owed claim");
    }
    tokens.push({ tokenId, operationId: ids[i]!, beneficiary: b.beneficiaries[i]!, delivery, claim, revealAttempt });
  }
  if (diverted.some(row => !tokenIds.includes(row.args.tokenId))) throw Error("Unrelated diverted token");
  ordered(last, slice.index);
  finish(t, slice.index);
  return { operationRoot: root, tokens };
}

/** Exact transaction plus historical prestate/end-block observations; no trace-based rollback claim. */
export async function reconcileDistributionMerkleReceipt(
  provider: ReceiptReader,
  captureInput: DistributionMerkleCapture,
  transactionHash: Hex,
  optionsInput: DistributionMerkleReceiptOptions,
): Promise<DistributionMerkleReconciliation> {
  const saved = normalizeCapture(captureInput);
  const options = copy(optionsInput);
  const t = await transport(provider, saved.prepared, transactionHash, options);
  if (t.observed.blockNumber <= saved.observed.blockNumber) throw Error("Receipt must follow capture block");
  const prior = await revalidateDistributionMerkle(provider, saved, { blockTag: t.observed.blockNumber - 1 });
  const d = prior.deployment;
  const p = prior.prepared;
  await pin(provider, d.distributor, t.observed.blockNumber);
  await pin(provider, d.core, t.observed.blockNumber);
  let operationRoot: Hex | null = null;
  let tokens: DistributionMerkleTokenReceipt[] = [];
  let claimOutcome: "completed" | "retained" | null = null;
  if (p.kind === "distribute") {
    const result = await distributionReceipt(provider, prior, t);
    operationRoot = result.operationRoot;
    tokens = result.tokens;
  } else {
    const input = p.input;
    if (prior.delegation !== null && (prior.delegation[2] > t.observed.timestamp
      || prior.delegation[3] <= t.observed.timestamp)) throw Error("Original delegation expired at mined timestamp");
    for (const dependency of prior.dependencies) await pin(provider, dependency, t.observed.blockNumber);
    const receiver = input.kind === "claimNft" ? input.receiver : prior.claim!.beneficiary;
    const completed = events(t, d.distributor.address, abi, "AirdropNftClaimCompleted");
    const [claim] = await read(provider, d.distributor.address, "nftClaim", [input.tokenId], t.observed.blockNumber);
    const transfers = matching(t, d.core.address, "Transfer", { from: d.distributor.address, to: receiver, tokenId: input.tokenId });
    if (completed.length === 1) {
      const event = one(t, d.distributor.address, abi, "AirdropNftClaimCompleted", {
        schemaVersion: 1n, collectionId: prior.claim!.collectionId, tokenId: input.tokenId, receiver,
      });
      if (transfers.length !== 1) throw Error("Claim delivery transfer required");
      equal(claim, emptyClaim, "Cleared original claim");
      ordered(transfers[0]!.index, event.index);
      finish(t, event.index);
      claimOutcome = "completed";
    } else {
      if (completed.length !== 0 || transfers.length !== 0) throw Error("Contradictory retained claim evidence");
      equal(claim, prior.claim, "Unchanged owed claim");
      equal((await read(provider, d.core.address, "ownerOf", [input.tokenId], t.observed.blockNumber))[0], d.distributor.address, "Retained claim custody");
      if (t.safeIndex !== null && t.logs.some(log => log.index > t.safeIndex!)) throw Error("Safe completion must follow original claim logs");
      claimOutcome = "retained";
    }
  }
  await unchanged(provider, t.observed);
  return freeze({ capture: saved, transactionHash: t.transactionHash, observed: t.observed, operationRoot,
    tokens, claimOutcome, functionReturnObserved: false });
}
