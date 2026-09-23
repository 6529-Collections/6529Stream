import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { BurnMintProgramConfig } from "./current-burn-mint.js";
import { burnMintNullifier } from "./current-burn-mint.js";
import type { PaymentIntent } from "./signing.js";
import type { ERC20SettlementCandidate, ERC20PrimarySettlementResult, ERC20SaleLifecycleBinding, ERC20EIP2612Permit, ERC20Permit2Transfer } from "./current-erc20-primary-offer.js";
import { normalizeERC20BurnMintSaleConfig, normalizeERC20BurnMintProgramConfig, normalizeERC20BurnMintCandidate, erc20BurnMintSaleId, erc20BurnMintConfigurationHash, erc20BurnMintSigningSnapshot, erc20BurnMintProgramConfigHash, validateERC20BurnMintProgram, erc20BurnMintExecutionId, erc20BurnMintCandidateCommitment, erc20BurnMintSettlementKey, erc20BurnMintPaymentIntentPayload } from "./current-erc20-burn-mint-signing.js";
import type { ERC20BurnMintSaleConfig, ERC20BurnMintExecution, ERC20BurnMintSigningSnapshot } from "./current-erc20-burn-mint-signing.js";

// Exact selected current interfaces, frozen at c717a3e1; transport callbacks are intentionally absent.
const saleAbi = new Interface([
  "event EIP712DomainChanged()",
  "event GasParameterRegistered(uint16 schemaVersion, bytes32 indexed parameterId, string name, uint256 genesisValue, uint256 floor, uint8 failureClass)",
  "event GasParameterUpdated(uint16 schemaVersion, bytes32 indexed parameterId, address indexed host, bytes32 indexed actionId, uint256 oldValue, uint256 newValue, uint256 floor)",
  "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)",
  "event UniversalAuthorizationCancelled(address indexed artist, bytes32 indexed nonce, uint16 schemaVersion)",
  "event UniversalSaleCancelled(bytes32 indexed saleId, uint16 schemaVersion)",
  "event UniversalSaleConfigured(bytes32 indexed saleId, uint256 indexed collectionId, bytes32 indexed phaseId, uint16 schemaVersion, uint256 saleNonce, bytes32 configHash, address paymentAdapter)",
  "event UniversalSaleExecution(bytes32 indexed saleId, bytes32 indexed executionId, bytes32 indexed operationRoot, uint16 schemaVersion, uint8 status, bytes32 settlementKey, uint256 tokenId)",
  "event UniversalSalesPaused(uint16 schemaVersion, bool paused)",
  "function authorizationDigest((bytes32 saleId, bytes32 saleConfigHash, address payer, address executor, address recipient, address artist, bytes32 tokenDataHash, bytes32 mintCommitment, uint256 executionNonce, bytes32 nonce, uint64 deadline) authorization) view returns (bytes32)",
  "function authorizationUsed(address artist, bytes32 nonce) view returns (bool)",
  "function cancelAuthorization(bytes32 nonce)",
  "function cancelSale(bytes32 id)",
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function executionIdByNonce(bytes32 id, uint256 nonce) view returns (bytes32)",
  "function executionStatus(bytes32 id) view returns (uint8)",
  "function mintManager() view returns (address)",
  "function mintManagerCodeHash() view returns (bytes32)",
  "function moduleRegistry() view returns (address)",
  "function moduleRegistryCodeHash() view returns (bytes32)",
  "function nextSaleNonce() view returns (uint256)",
  "function owner() view returns (address)",
  "function paused() view returns (bool)",
  "function previewExecution((((bytes32 saleId, bytes32 saleConfigHash, address payer, address executor, address recipient, address artist, bytes32 tokenDataHash, bytes32 mintCommitment, uint256 executionNonce, bytes32 nonce, uint64 deadline) authorization, bytes tokenData, bytes platformSignature, bytes artistSignature) sale, uint256[] sourceTokenIds) e) returns ((address saleAdapter, address executor, (bytes32 settlementId, bytes32 revenueClass, uint8 policyMode, uint256 collectionId, uint256 tokenId, uint256 saleNonce, address payer, address poster, address beneficiary, uint256 amount, bytes32 expectedPrimaryPolicyHash) sale, (address paymentAdapter, uint64 saleCreatedAt, uint64 saleAdapterRegistryRevision, uint64 paymentAdapterRegistryRevision) lifecycleBinding, (bytes32 executionId, uint256 executionNonce, uint8 authorityMode, bytes32 saleAuthorizationDigest) executionBinding, address asset, uint8 orchestrationOrder, address mintManager, bytes32 operationIdentityCommitment, bytes32 operationId, bytes32 currentPolicyHash, bytes32 boundPolicyHash, (bytes32 profileId, address wallet, bytes32 templateId, bytes32 assignmentHash, bytes32 entriesHash) rights, bytes32 saleExecutionHash) c)",
  "function primarySaleSettlement() view returns (address)",
  "function raiseGasParameter(bytes32 parameterId, uint256 newValue)",
  "function registerSale((address paymentAdapter, uint256 collectionId, bytes32 phaseId, address asset, uint256 price, uint64 startsAt, uint64 endsAt, bytes32 mintPolicyHash, bytes32 expectedPrimaryPolicyHash) config) returns (bytes32 saleId)",
  "function renounceOwnership()",
  "function saleBurnGate(bytes32 id) view returns (address gate, bytes32 codeHash, bytes32 configHash)",
  "function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 nonce) view returns (bytes32)",
  "function saleLifecycleBinding(bytes32 id) view returns ((address paymentAdapter, uint64 saleCreatedAt, uint64 saleAdapterRegistryRevision, uint64 paymentAdapterRegistryRevision))",
  "function saleRecord(bytes32 id) view returns (((address paymentAdapter, uint256 collectionId, bytes32 phaseId, address asset, uint256 price, uint64 startsAt, uint64 endsAt, bytes32 mintPolicyHash, bytes32 expectedPrimaryPolicyHash) config, uint256 saleNonce, bytes32 configHash, (address paymentAdapter, uint64 saleCreatedAt, uint64 saleAdapterRegistryRevision, uint64 paymentAdapterRegistryRevision) lifecycle, bool cancelled))",
  "function setPaused(bool value)",
  "function settlementCodeHash() view returns (bytes32)",
  "function transferOwnership(address newOwner)"
]);
const gateAbi = new Interface([
  "event BurnMintBatchExecuted(uint16 schemaVersion, uint256 indexed targetCollectionId, bytes32 indexed operationRoot, address indexed burnCaller, uint256[] sourceTokenIds, address[] sourceOwners, uint256[] mintedTokenIds)",
  "event BurnMintExecuted(uint16 schemaVersion, uint256 indexed sourceTokenId, uint256 indexed mintedTokenId, uint256 indexed targetCollectionId, bytes32 burnNullifier, address redeemer)",
  "event BurnMintProgramConfigured(uint16 schemaVersion, uint256 indexed targetCollectionId, address indexed manager, bytes32 indexed phaseId, bytes32 configHash, (address manager, uint256 targetCollectionId, bytes32 phaseId, uint256[] sourceCollectionIds, uint8 sourcesPerMint, uint64 startsAt, uint64 endsAt, bool prepared, address nativeSaleAdapter) config)",
  "event GasParameterRegistered(uint16 schemaVersion, bytes32 indexed parameterId, string name, uint256 genesisValue, uint256 floor, uint8 failureClass)",
  "event GasParameterUpdated(uint16 schemaVersion, bytes32 indexed parameterId, address indexed host, bytes32 indexed actionId, uint256 oldValue, uint256 newValue, uint256 floor)",
  "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)",
  "function allowedSourceCollections(uint256 targetCollectionId) view returns (uint256[])",
  "function burnNullifier(uint256 sourceTokenId) view returns (bytes32)",
  "function configureProgram((address manager, uint256 targetCollectionId, bytes32 phaseId, uint256[] sourceCollectionIds, uint8 sourcesPerMint, uint64 startsAt, uint64 endsAt, bool prepared, address nativeSaleAdapter) c) returns (bytes32 hash)",
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function erc20SaleAdapter() view returns (address)",
  "function erc20SaleCodeHash() view returns (bytes32)",
  "function moduleRegistry() view returns (address)",
  "function owner() view returns (address)",
  "function program(uint256 targetCollectionId) view returns (((address manager, uint256 targetCollectionId, bytes32 phaseId, uint256[] sourceCollectionIds, uint8 sourcesPerMint, uint64 startsAt, uint64 endsAt, bool prepared, address nativeSaleAdapter) config, bytes32 configHash, bytes32 managerCodeHash, bytes32 nativeSaleCodeHash))",
  "function programConfigHash((address manager, uint256 targetCollectionId, bytes32 phaseId, uint256[] sourceCollectionIds, uint8 sourcesPerMint, uint64 startsAt, uint64 endsAt, bool prepared, address nativeSaleAdapter) c) view returns (bytes32)",
  "function raiseGasParameter(bytes32 parameterId, uint256 newValue)",
  "function registryCodeHash() view returns (bytes32)",
  "function renounceOwnership()",
  "function transferOwnership(address newOwner)"
]);
const paymentAbi = new Interface([
  "event PaymentIntentConsumed(address indexed payer, bytes32 indexed saleRef, bytes32 indexed nonce, uint16 schemaVersion, address asset, uint256 amount)",
  "event PaymentIntentRevoked(address indexed payer, bytes32 indexed nonce, uint16 schemaVersion)",
  "function core() view returns (address)",
  "function isPaymentIntentNonceUsed(address payer, bytes32 nonce) view returns (bool)",
  "function paymentIntentDigest((address payer, address asset, uint256 maxAmount, bytes32 saleRef, bytes32 expectedPrimaryPolicyHash, bytes32 nonce, uint64 deadline) intent) view returns (bytes32)",
  "function primarySaleSettlement() view returns (address)",
  "function revokePaymentIntent(bytes32 nonce)",
  "function revokePaymentIntentWithSignature((address payer, bytes32 nonce, uint64 deadline) r, bytes signature)",
  "function settleERC20PrimarySaleByPayer((address saleAdapter, address executor, (bytes32 settlementId, bytes32 revenueClass, uint8 policyMode, uint256 collectionId, uint256 tokenId, uint256 saleNonce, address payer, address poster, address beneficiary, uint256 amount, bytes32 expectedPrimaryPolicyHash) sale, (address paymentAdapter, uint64 saleCreatedAt, uint64 saleAdapterRegistryRevision, uint64 paymentAdapterRegistryRevision) lifecycleBinding, (bytes32 executionId, uint256 executionNonce, uint8 authorityMode, bytes32 saleAuthorizationDigest) executionBinding, address asset, uint8 orchestrationOrder, address mintManager, bytes32 operationIdentityCommitment, bytes32 operationId, bytes32 currentPolicyHash, bytes32 boundPolicyHash, (bytes32 profileId, address wallet, bytes32 templateId, bytes32 assignmentHash, bytes32 entriesHash) rights, bytes32 saleExecutionHash) c, bytes data) returns ((bytes32 candidateCommitment, bytes32 settlementKey, bytes32 profileId, address wallet, address asset, uint256 amount, address executor, bytes32 executionId, bool escrowed, bytes32 operationIdentityCommitment, bytes32 currentPolicyHash, bytes32 boundPolicyHash))",
  "function settleERC20PrimarySaleWithEIP2612Permit((address saleAdapter, address executor, (bytes32 settlementId, bytes32 revenueClass, uint8 policyMode, uint256 collectionId, uint256 tokenId, uint256 saleNonce, address payer, address poster, address beneficiary, uint256 amount, bytes32 expectedPrimaryPolicyHash) sale, (address paymentAdapter, uint64 saleCreatedAt, uint64 saleAdapterRegistryRevision, uint64 paymentAdapterRegistryRevision) lifecycleBinding, (bytes32 executionId, uint256 executionNonce, uint8 authorityMode, bytes32 saleAuthorizationDigest) executionBinding, address asset, uint8 orchestrationOrder, address mintManager, bytes32 operationIdentityCommitment, bytes32 operationId, bytes32 currentPolicyHash, bytes32 boundPolicyHash, (bytes32 profileId, address wallet, bytes32 templateId, bytes32 assignmentHash, bytes32 entriesHash) rights, bytes32 saleExecutionHash) c, (uint256 deadline, uint8 v, bytes32 r, bytes32 s) permit, bytes data) returns ((bytes32 candidateCommitment, bytes32 settlementKey, bytes32 profileId, address wallet, address asset, uint256 amount, address executor, bytes32 executionId, bool escrowed, bytes32 operationIdentityCommitment, bytes32 currentPolicyHash, bytes32 boundPolicyHash))",
  "function settleERC20PrimarySaleWithIntent((address saleAdapter, address executor, (bytes32 settlementId, bytes32 revenueClass, uint8 policyMode, uint256 collectionId, uint256 tokenId, uint256 saleNonce, address payer, address poster, address beneficiary, uint256 amount, bytes32 expectedPrimaryPolicyHash) sale, (address paymentAdapter, uint64 saleCreatedAt, uint64 saleAdapterRegistryRevision, uint64 paymentAdapterRegistryRevision) lifecycleBinding, (bytes32 executionId, uint256 executionNonce, uint8 authorityMode, bytes32 saleAuthorizationDigest) executionBinding, address asset, uint8 orchestrationOrder, address mintManager, bytes32 operationIdentityCommitment, bytes32 operationId, bytes32 currentPolicyHash, bytes32 boundPolicyHash, (bytes32 profileId, address wallet, bytes32 templateId, bytes32 assignmentHash, bytes32 entriesHash) rights, bytes32 saleExecutionHash) c, (address payer, address asset, uint256 maxAmount, bytes32 saleRef, bytes32 expectedPrimaryPolicyHash, bytes32 nonce, uint64 deadline) intent, bytes signature, bytes data) returns ((bytes32 candidateCommitment, bytes32 settlementKey, bytes32 profileId, address wallet, address asset, uint256 amount, address executor, bytes32 executionId, bool escrowed, bytes32 operationIdentityCommitment, bytes32 currentPolicyHash, bytes32 boundPolicyHash))",
  "function settleERC20PrimarySaleWithPermit2((address saleAdapter, address executor, (bytes32 settlementId, bytes32 revenueClass, uint8 policyMode, uint256 collectionId, uint256 tokenId, uint256 saleNonce, address payer, address poster, address beneficiary, uint256 amount, bytes32 expectedPrimaryPolicyHash) sale, (address paymentAdapter, uint64 saleCreatedAt, uint64 saleAdapterRegistryRevision, uint64 paymentAdapterRegistryRevision) lifecycleBinding, (bytes32 executionId, uint256 executionNonce, uint8 authorityMode, bytes32 saleAuthorizationDigest) executionBinding, address asset, uint8 orchestrationOrder, address mintManager, bytes32 operationIdentityCommitment, bytes32 operationId, bytes32 currentPolicyHash, bytes32 boundPolicyHash, (bytes32 profileId, address wallet, bytes32 templateId, bytes32 assignmentHash, bytes32 entriesHash) rights, bytes32 saleExecutionHash) c, (uint256 nonce, uint256 deadline, bytes signature) permit, bytes data) returns ((bytes32 candidateCommitment, bytes32 settlementKey, bytes32 profileId, address wallet, address asset, uint256 amount, address executor, bytes32 executionId, bool escrowed, bytes32 operationIdentityCommitment, bytes32 currentPolicyHash, bytes32 boundPolicyHash))"
]);
const coreAbi = new Interface([
  "event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)",
  "event ApprovalForAll(address indexed owner, address indexed operator, bool approved)",
  "event StreamTokenBurned(uint256 indexed tokenId, uint256 indexed collectionId, uint256 collectionSerial, uint16 schemaVersion)",
  "event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)",
  "function approve(address to, uint256 tokenId)",
  "function collectionBurnsBlocked(uint256 collectionId) view returns (bool)",
  "function collectionBurnsBlockedAtBlock(uint256 collectionId) view returns (uint64)",
  "function collectionExists(uint256 collectionId) view returns (bool)",
  "function collectionFreezeStatus(uint256 collectionId) view returns (bool)",
  "function collectionHasMaxSupply(uint256 collectionId) view returns (bool)",
  "function collectionMaxSupply(uint256 collectionId) view returns (uint256)",
  "function collectionMintedEver(uint256 collectionId) view returns (uint256)",
  "function collectionStatus(uint256 collectionId) view returns (uint8)",
  "function collectionSupplyMode(uint256 collectionId) view returns (uint8)",
  "function getApproved(uint256 tokenId) view returns (address)",
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "function isApprovedForAll(address owner, address operator) view returns (bool)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function setApprovalForAll(address operator, bool approved)",
  "function tokenCollectionIdentity(uint256 tokenId) view returns (bool mappingExists, uint256 collectionId, uint256 collectionSerial, bool burned)",
  "function tokenLifecycle(uint256 tokenId) view returns (uint8 lifecycle)"
]);
const managerAbi = new Interface([
  "function isOperationRootUsed(bytes32 operationRoot) view returns(bool)",
  "event MintAuthorizationConsumed(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed phaseId, bytes32 indexed authorizationId, bytes32 boundPolicyHash, bytes32 operationRoot)",
  "event MintAuthorizationVoided(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed phaseId, bytes32 indexed authorizationId, address authorizer, address verifyingContract, uint8 family)",
  "event MintBatchExecuted(uint16 schemaVersion, bytes32 indexed operationRoot, uint256 indexed collectionId, bytes32 indexed phaseId, address executor, address payer, address authorizer, uint256 firstTokenId, uint256 quantity, bytes32 contextHash, bytes32 gateHash, bytes32 currentPolicyHash, bytes32 boundPolicyHash)",
  "event MintGateValidated(uint256 indexed collectionId, bytes32 indexed phaseId, address indexed gate, bytes32 authorizationId, address authorizer, uint256 quantity, bytes32 contextHash, bytes32 gateHash, bytes32 policyHash)",
  "event MintTokenExecuted(uint16 schemaVersion, bytes32 indexed operationId, uint256 indexed tokenId, bytes32 indexed operationRoot, uint256 collectionId, bytes32 phaseId, uint256 tokenIndex, address initialRecipient, address beneficiary, bytes32 tokenDataHash, bytes32 mintCommitment)",
  "function core() view returns (address)",
  "function isAuthorizationUsed(bytes32 authorizationId) view returns (bool)",
  "function isNullifierUsed(bytes32 nullifier) view returns (bool)",
  "function mintLedger() view returns (address)",
  "function mintTicketAuthorizationId((uint256 chainId, address manager, address ledger, uint256 collectionId, bytes32 phaseId, address executor, address payer, address authorizer, uint8 authorizerKind, bytes32 initialRecipientsHash, bytes32 beneficiariesHash, bytes32 tokenDataArrayHash, bytes32 mintCommitmentsHash, uint256 quantity, bytes32 contextHash, bytes32 policyHash, bytes32 nonce, uint64 deadline) ticket, address verifyingGate) view returns (bytes32)",
  "function moduleRegistry() view returns (address)",
  "function nextOperationNonce() view returns (uint256)",
  "function phase(uint256 collectionId, bytes32 phaseId) view returns (bool exists, (bool paused, uint64 startTime, uint64 endTime, uint32 maxBatchQuantity, bytes32 configHash, bytes32 metadataHash) config)",
  "function phaseExecutor(uint256, bytes32, address) view returns (bool)",
  "function phaseGate(uint256 collectionId, bytes32 phaseId) view returns ((address gate, bytes32 gateConfigHash, bytes32 gateCodehash, bytes32 gateMetadataHash, uint32 gateSemanticVersion, uint32 gateGasLimit))",
  "function phasePolicyHash(uint256, bytes32) view returns (bytes32)"
]);
const ledgerAbi = new Interface([
  "function isManagerOperationRootUsed(address manager,bytes32 operationRoot) view returns(bool)",
  "event MintLedgerAuthorizationConsumed(uint16 schemaVersion, bytes32 indexed authorizationId, bytes32 indexed operationRoot, address indexed manager, bytes32 boundPolicyHash)",
  "event MintLedgerAuthorizationVoided(uint16 schemaVersion, bytes32 indexed authorizationId, address indexed manager)",
  "event MintLedgerNullifierConsumed(uint16 schemaVersion, bytes32 indexed nullifier, bytes32 indexed operationRoot, address indexed manager, bytes32 boundPolicyHash)",
  "event MintLedgerOperationRootConsumed(uint16 schemaVersion, bytes32 indexed operationRoot, address indexed manager, bytes32 currentPolicyHash, bytes32 indexed boundPolicyHash, bytes32 authorizationId)",
  "function isManagerAuthorizationUsed(address manager, bytes32 authorizationId) view returns (bool)",
  "function isManagerNullifierUsed(address manager, bytes32 nullifier) view returns (bool)"
]);
const recorderAbi = new Interface([
  "event PrimaryRevenueExecutionBound(bytes32 indexed settlementKey, address indexed saleAdapter, bytes32 indexed executionId, uint16 schemaVersion, address executor, address paymentAdapter, bytes32 candidateCommitment, bytes32 currentPolicyHash, bytes32 boundPolicyHash)",
  "event PrimaryRevenueSettled(bytes32 indexed settlementKey, bytes32 indexed revenueClass, bytes32 indexed profileId, uint16 schemaVersion, address wallet, address asset, address payer, uint256 amount, bytes32 saleContextHash, bool policyDrift, uint8 assignmentType)",
  "event PrimaryRevenueSettlementContext(bytes32 indexed settlementKey, bytes32 indexed revenueClass, bytes32 indexed profileId, uint16 schemaVersion, address settlementCaller, bytes32 settlementId, uint8 policyMode, uint256 collectionId, uint256 tokenId, bytes32 operationRoot, bytes32 operationId, uint256 saleNonce, address poster, address beneficiary, bytes32 templateId)",
  "event PrimaryRevenueSettlementPolicy(bytes32 indexed settlementKey, bytes32 indexed revenueClass, bytes32 indexed profileId, uint16 schemaVersion, bytes32 expectedPrimaryPolicyHash, bytes32 resolvedPrimaryPolicyHash, bytes32 resolvedAssignmentHash, bytes32 templateId)",
  "function core() view returns (address)",
  "function officialSettled(bytes32 revenueClass, bytes32 profileId, address wallet, address asset) view returns (uint256)",
  "function settlementConsumed(bytes32) view returns (bool)",
  "function settlementKey(address saleAdapter, bytes32 executionId) view returns (bytes32)",
  "function settlementResult(bytes32 key) view returns ((bytes32 candidateCommitment, bytes32 settlementKey, bytes32 profileId, address wallet, address asset, uint256 amount, address executor, bytes32 executionId, bool escrowed, bytes32 operationIdentityCommitment, bytes32 currentPolicyHash, bytes32 boundPolicyHash))"
]);
const tokenAbi = new Interface([
  "event Approval(address indexed owner, address indexed spender, uint256 value)",
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function balanceOf(address account) view returns (uint256)"
]);

export interface ERC20BurnMintCodePin { readonly address: Address; readonly codeHash: Hex }
export interface ERC20BurnMintDeployment {
  readonly chainId: bigint;
  readonly adapter: ERC20BurnMintCodePin; readonly core: ERC20BurnMintCodePin;
  readonly moduleRegistry: ERC20BurnMintCodePin; readonly manager: ERC20BurnMintCodePin;
  readonly ledger: ERC20BurnMintCodePin; readonly gate: ERC20BurnMintCodePin;
  readonly payment: ERC20BurnMintCodePin; readonly recorder: ERC20BurnMintCodePin;
  readonly asset: ERC20BurnMintCodePin;
}
export interface PreparedERC20BurnMintExecution {
  readonly deployment: ERC20BurnMintDeployment; readonly caller: Address;
  readonly signing: ERC20BurnMintSigningSnapshot;
  /** Nonpayable simulation only. Never submit this preview as a transaction. */
  readonly previewCall: UnsignedCall;
}
export interface ERC20BurnMintSaleRecord {
  readonly config: ERC20BurnMintSaleConfig; readonly saleNonce: bigint; readonly configHash: Hex;
  readonly lifecycle: ERC20SaleLifecycleBinding; readonly cancelled: boolean;
}
export interface ERC20BurnMintProgram {
  readonly config: BurnMintProgramConfig; readonly configHash: Hex;
  readonly managerCodeHash: Hex; readonly nativeSaleCodeHash: Hex;
}
export interface ERC20BurnMintSource {
  readonly tokenId: bigint; readonly collectionId: bigint; readonly collectionSerial: bigint;
  readonly owner: Address; readonly approved: Address; readonly executorOperatorApproved: boolean;
  readonly gateOperatorApproved: boolean; readonly nullifier: Hex;
}
export interface ERC20BurnMintCapture {
  readonly prepared: PreparedERC20BurnMintExecution; readonly blockNumber: number; readonly blockHash: Hex;
  readonly sale: ERC20BurnMintSaleRecord; readonly program: ERC20BurnMintProgram;
  readonly sources: readonly ERC20BurnMintSource[]; readonly candidate: ERC20SettlementCandidate;
}
export type ERC20BurnMintFundingRoute =
  | { readonly kind: "payer" }
  | { readonly kind: "intent"; readonly intent: PaymentIntent; readonly signature: Hex }
  | { readonly kind: "eip2612"; readonly permit: ERC20EIP2612Permit }
  | { readonly kind: "permit2"; readonly permit: ERC20Permit2Transfer };
export interface PreparedERC20BurnMintFunding {
  readonly capture: ERC20BurnMintCapture; readonly caller: Address; readonly route: ERC20BurnMintFundingRoute;
  readonly candidateCommitment: Hex; readonly settlementKey: Hex; readonly call: UnsignedCall;
}
/** Configuration, admin and approval actions. The four funding routes are prepared separately. */
export type ERC20BurnMintAction =
  | { readonly target: "sale"; readonly kind: "registerSale"; readonly configuration: ERC20BurnMintSaleConfig; readonly expectedNonce: bigint }
  | { readonly target: "sale"; readonly kind: "cancelSale"; readonly saleId: Hex }
  | { readonly target: "sale"; readonly kind: "setPaused"; readonly paused: boolean }
  | { readonly target: "sale"; readonly kind: "cancelAuthorization"; readonly nonce: Hex }
  | { readonly target: "gate"; readonly kind: "configureProgram"; readonly configuration: BurnMintProgramConfig }
  | { readonly target: "sale" | "gate"; readonly kind: "raiseGasParameter"; readonly parameterId: Hex; readonly value: bigint }
  | { readonly target: "sale" | "gate"; readonly kind: "transferOwnership"; readonly newOwner: Address }
  | { readonly target: "sale" | "gate"; readonly kind: "renounceOwnership" }
  | { readonly target: "payment"; readonly kind: "revokePaymentIntent"; readonly nonce: Hex }
  | { readonly target: "payment"; readonly kind: "revokePaymentIntentWithSignature"; readonly revocation: { readonly payer: Address; readonly nonce: Hex; readonly deadline: bigint }; readonly signature: Hex }
  | { readonly target: "core"; readonly kind: "approve"; readonly approved: Address; readonly tokenId: bigint }
  | { readonly target: "core"; readonly kind: "setApprovalForAll"; readonly operator: Address; readonly approved: boolean }
  | { readonly target: "asset"; readonly kind: "approve"; readonly spender: Address; readonly amount: bigint };
export interface PreparedERC20BurnMintAction {
  readonly deployment: ERC20BurnMintDeployment; readonly caller: Address; readonly action: ERC20BurnMintAction;
  readonly call: UnsignedCall; readonly expectedIdentity: Hex | null;
}
export interface ERC20BurnMintEventReference {
  readonly address: Address; readonly event: string; readonly logIndex: number;
  readonly transactionHash: Hex; readonly blockHash: Hex;
}
export interface ERC20BurnMintCompleted {
  readonly prepared: PreparedERC20BurnMintFunding; readonly transactionHash: Hex;
  readonly blockNumber: number; readonly blockHash: Hex; readonly tokenId: bigint;
  readonly operationRoot: Hex; readonly operationId: Hex; readonly settlement: ERC20PrimarySettlementResult;
  readonly events: readonly ERC20BurnMintEventReference[];
}
type Reader = Pick<Provider, "call" | "getNetwork" | "getBlock" | "getCode">;
type ReceiptReader = Reader & Pick<Provider, "getTransactionReceipt" | "getTransaction">;
const coder = AbiCoder.defaultAbiCoder();
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safeEvents = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const indexedSafeEvents = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
const pinNames = ["adapter", "core", "moduleRegistry", "manager", "ledger", "gate", "payment", "recorder", "asset"] as const;
const interfaces = { sale: saleAbi, gate: gateAbi, payment: paymentAbi, core: coreAbi, asset: tokenAbi };
function address(v: unknown, zero = false): Address { if (typeof v !== "string") throw Error("Expected address"); const a = getAddress(v) as Address; if (!zero && a === ZeroAddress) throw Error("Zero address"); return a; }
function hash(v: unknown, zero = false): Hex { if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32"); return v.toLowerCase() as Hex; }
function bytes(v: unknown, max = 16384): Hex { if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed or oversized bytes"); return v.toLowerCase() as Hex; }
function uint(v: unknown, bits = 256, positive = false): bigint { if (typeof v !== "bigint" || v < (positive ? 1n : 0n) || v >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`); return v; }
function boolean(v: unknown): boolean { if (typeof v !== "boolean") throw Error("Expected boolean"); return v; }
function integer(v: number): number { if (!Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete block number/index"); return v; }
function same(a: unknown, b: unknown): boolean { return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase(); }
function stable(v: unknown): string { return JSON.stringify(v, (_, x: unknown) => typeof x === "bigint" ? `${x}n` : x && typeof x === "object" && !Array.isArray(x) ? Object.fromEntries(Object.entries(x).sort(([a], [b]) => a.localeCompare(b))) : x); }
function equal(a: unknown, b: unknown, message = "Prepared data differs from canonical reconstruction"): void { if (stable(a) !== stable(b)) throw Error(message); }
function keys(v: unknown, names: readonly string[]): asserts v is Record<string, unknown> { if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join() !== [...names].sort().join()) throw Error("Missing or unknown properties"); }
function frozen<T>(v: T): T { if (v && typeof v === "object") { for (const x of Object.values(v)) frozen(x); Object.freeze(v); } return v; }
function tuple(p: ParamType, v: unknown, decoded = false): unknown {
  if (p.baseType === "tuple") { if (!decoded) keys(v, p.components!.map(x => x.name)); return Object.freeze(Object.fromEntries(p.components!.map((x, i) => [x.name, tuple(x, decoded ? (v as unknown[])[i] : (v as Record<string, unknown>)[x.name], decoded)]))); }
  if (p.baseType === "array") { if (!Array.isArray(v) || v.length > 256) throw Error("Oversized array"); return Object.freeze(v.map(x => tuple(p.arrayChildren!, x, decoded))); }
  if (p.type.startsWith("uint")) return uint(v, Number(p.type.slice(4)));
  if (p.type === "address") return address(v, true);
  if (p.type === "bool") return boolean(v);
  if (p.type === "bytes32") return hash(v, true);
  if (p.type === "bytes4") { const b = bytes(v); if (b.length !== 10) throw Error("Expected bytes4"); return b; }
  if (p.type === "bytes") return bytes(v, 65536);
  throw Error("Unsupported ABI scalar");
}
function resultTuple<T>(abi: Interface, method: string, value: unknown, decoded = false): T { return tuple(abi.getFunction(method)!.outputs[0]!, value, decoded) as T; }
function call(to: Address, abi: Interface, method: string, args: readonly unknown[]): UnsignedCall { return Object.freeze({ to, value: 0n, data: abi.encodeFunctionData(method, args) as Hex }); }
function deployment(value: ERC20BurnMintDeployment): ERC20BurnMintDeployment {
  keys(value, ["chainId", ...pinNames]); const out: Record<string, unknown> = { chainId: uint(value.chainId, 256, true) };
  for (const name of pinNames) { keys(value[name], ["address", "codeHash"]); out[name] = Object.freeze({ address: address(value[name].address), codeHash: hash(value[name].codeHash) }); }
  if (new Set(pinNames.map(n => (out[n] as ERC20BurnMintCodePin).address)).size !== pinNames.length) throw Error("Deployment roles must be distinct");
  return Object.freeze(out) as unknown as ERC20BurnMintDeployment;
}
async function rpc(p: Pick<Provider, "call">, target: Address, abi: Interface, method: string, args: readonly unknown[], tag: number, from?: Address): Promise<readonly unknown[]> {
  const raw = bytes(await p.call({ ...call(target, abi, method, args), blockTag: tag, ...(from ? { from } : {}) }));
  const result = abi.decodeFunctionResult(method, raw); if (!same(abi.encodeFunctionResult(method, result), raw)) throw Error(`Noncanonical ${method} return`);
  // Visiting every field forces lazy decoder errors and validates client bounds.
  abi.getFunction(method)!.outputs.forEach((field, i) => tuple(field, result[i], true)); return result;
}
async function header(p: Pick<Provider, "getBlock">, tag: number): Promise<{ readonly number: number; readonly hash: Hex; readonly timestamp: bigint }> {
  const b = await p.getBlock(tag); if (!b || b.number !== tag || !Number.isSafeInteger(b.timestamp) || b.timestamp < 0) throw Error("Missing/mismatched block"); return Object.freeze({ number: tag, hash: hash(b.hash), timestamp: BigInt(b.timestamp) });
}
async function pin(p: Reader, d: ERC20BurnMintDeployment, tag: number): Promise<Awaited<ReturnType<typeof header>>> {
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain mismatch"); const h = await header(p, tag);
  await Promise.all(pinNames.map(async n => { const code = bytes(await p.getCode(d[n].address, tag), 65536); if (code === "0x" || !same(keccak256(code), d[n].codeHash)) throw Error(`Runtime code mismatch: ${n}`); })); return h;
}
async function unchanged(p: Pick<Provider, "getBlock">, h: Awaited<ReturnType<typeof header>>): Promise<void> { equal(await header(p, h.number), h, "Inspection block changed"); }
export function prepareERC20BurnMintExecution(input: ERC20BurnMintDeployment, configuration: ERC20BurnMintSaleConfig, execution: ERC20BurnMintExecution): PreparedERC20BurnMintExecution {
  const d = deployment(input), c = normalizeERC20BurnMintSaleConfig(configuration);
  if (!same(c.paymentAdapter, d.payment.address) || !same(c.asset, d.asset.address)) throw Error("Configured payment/asset differs from deployment");
  const signing = erc20BurnMintSigningSnapshot(d.chainId, d.adapter.address, c, execution.sale.authorization.saleId, execution);
  return frozen({ deployment: d, caller: signing.execution.sale.authorization.executor, signing, previewCall: call(d.adapter.address, saleAbi, "previewExecution", [signing.execution]) });
}
function prepared(value: PreparedERC20BurnMintExecution): PreparedERC20BurnMintExecution { const p = prepareERC20BurnMintExecution(value.deployment, value.signing.configuration, value.signing.execution); equal(value, p); return p; }
async function dependencies(p: Reader, d: ERC20BurnMintDeployment, tag: number): Promise<void> {
  const bindings: [Address, Interface, string, unknown][] = [
    [d.adapter.address, saleAbi, "core", d.core.address], [d.adapter.address, saleAbi, "coreCodeHash", d.core.codeHash],
    [d.adapter.address, saleAbi, "moduleRegistry", d.moduleRegistry.address], [d.adapter.address, saleAbi, "moduleRegistryCodeHash", d.moduleRegistry.codeHash],
    [d.adapter.address, saleAbi, "mintManager", d.manager.address], [d.adapter.address, saleAbi, "mintManagerCodeHash", d.manager.codeHash],
    [d.adapter.address, saleAbi, "primarySaleSettlement", d.recorder.address], [d.adapter.address, saleAbi, "settlementCodeHash", d.recorder.codeHash],
    [d.gate.address, gateAbi, "core", d.core.address], [d.gate.address, gateAbi, "coreCodeHash", d.core.codeHash],
    [d.gate.address, gateAbi, "moduleRegistry", d.moduleRegistry.address], [d.gate.address, gateAbi, "registryCodeHash", d.moduleRegistry.codeHash],
    [d.gate.address, gateAbi, "erc20SaleAdapter", d.adapter.address], [d.gate.address, gateAbi, "erc20SaleCodeHash", d.adapter.codeHash],
    [d.manager.address, managerAbi, "core", d.core.address], [d.manager.address, managerAbi, "moduleRegistry", d.moduleRegistry.address],
    [d.manager.address, managerAbi, "mintLedger", d.ledger.address], [d.payment.address, paymentAbi, "core", d.core.address],
    [d.payment.address, paymentAbi, "primarySaleSettlement", d.recorder.address], [d.recorder.address, recorderAbi, "core", d.core.address],
  ];
  await Promise.all(bindings.map(async ([target, abi, method, expected]) => { const [actual] = await rpc(p, target, abi, method, [], tag); if (!same(actual, expected)) throw Error(`Dependency mismatch: ${method}`); }));
  for (const [name, expected] of [["MODULE_REGISTRY", d.moduleRegistry], ["MINT_MANAGER", d.manager]] as const) { const ptr = await rpc(p, d.core.address, coreAbi, "getSatellitePointer", [id(name)], tag); if (!same(ptr[0], expected.address) || !same(ptr[1], expected.codeHash)) throw Error(`Current ${name} differs`); }
}
function validateCandidate(p: PreparedERC20BurnMintExecution, sale: ERC20BurnMintSaleRecord, value: ERC20SettlementCandidate): ERC20SettlementCandidate {
  const c = normalizeERC20BurnMintCandidate(value), d = p.deployment, a = p.signing.execution.sale.authorization, config = p.signing.configuration;
  if (!same(c.saleAdapter, d.adapter.address) || !same(c.executor, p.caller) || !same(c.mintManager, d.manager.address) || !same(c.asset, config.asset)
    || !same(c.sale.settlementId, a.saleId) || c.sale.collectionId !== config.collectionId || c.sale.saleNonce !== sale.saleNonce
    || c.sale.amount !== config.price || !same(c.sale.payer, a.payer) || !same(c.sale.beneficiary, a.recipient)
    || !same(c.sale.expectedPrimaryPolicyHash, config.expectedPrimaryPolicyHash) || !same(c.boundPolicyHash, config.mintPolicyHash)
    || !same(c.saleExecutionHash, p.signing.saleExecutionHash) || !same(c.executionBinding.saleAuthorizationDigest, p.signing.contextHash)
    || c.executionBinding.executionNonce !== a.executionNonce || !same(c.executionBinding.executionId, erc20BurnMintExecutionId(d.chainId, c))) throw Error("Preview candidate differs from signed execution");
  equal(c.lifecycleBinding, sale.lifecycle, "Candidate lifecycle differs"); return c;
}
async function records(p: Reader, plan: PreparedERC20BurnMintExecution, tag: number): Promise<{ sale: ERC20BurnMintSaleRecord; program: ERC20BurnMintProgram }> {
  const d = plan.deployment, c = plan.signing.configuration, a = plan.signing.execution.sale.authorization;
  const [[s], [g], allowed, gate, [digest]] = await Promise.all([
    rpc(p, d.adapter.address, saleAbi, "saleRecord", [a.saleId], tag), rpc(p, d.gate.address, gateAbi, "program", [c.collectionId], tag),
    rpc(p, d.gate.address, gateAbi, "allowedSourceCollections", [c.collectionId], tag), rpc(p, d.adapter.address, saleAbi, "saleBurnGate", [a.saleId], tag),
    rpc(p, d.adapter.address, saleAbi, "authorizationDigest", [a], tag),
  ]);
  const sale = resultTuple<ERC20BurnMintSaleRecord>(saleAbi, "saleRecord", s, true), program = resultTuple<ERC20BurnMintProgram>(gateAbi, "program", g, true);
  equal(sale.config, c, "Stored sale configuration differs");
  if (sale.saleNonce === 0n || !same(sale.configHash, a.saleConfigHash) || !same(a.saleId, erc20BurnMintSaleId(d.chainId, d.adapter.address, c.collectionId, c.phaseId, sale.saleNonce)) || !same(digest, plan.signing.contextHash)) throw Error("Stored sale or digest identity differs");
  validateERC20BurnMintProgram(c, program.config, plan.signing.execution.sourceTokenIds);
  if (!same(program.config.manager, d.manager.address) || !same(program.managerCodeHash, d.manager.codeHash) || program.nativeSaleCodeHash !== ZeroHash
    || !same(program.configHash, erc20BurnMintProgramConfigHash(d.chainId, d.gate.address, d.core.address, d.moduleRegistry.address, program.config))
    || !same(gate[0], d.gate.address) || !same(gate[1], d.gate.codeHash) || !same(gate[2], program.configHash)) throw Error("Stored burn program/binding differs");
  equal([...allowed[0] as bigint[]], program.config.sourceCollectionIds, "Allowed sources differ");
  if (!same(sale.lifecycle.paymentAdapter, d.payment.address)) throw Error("Lifecycle payment adapter differs");
  return { sale, program };
}
/** A single-block capture; successful preview proves current onchain admission, PROFILE and zero declared native fee. */
export async function inspectERC20BurnMintExecution(provider: Reader, input: PreparedERC20BurnMintExecution, options: { readonly blockTag: number }): Promise<ERC20BurnMintCapture> {
  const plan = prepared(input), tag = integer(options.blockTag), d = plan.deployment, a = plan.signing.execution.sale.authorization, c = plan.signing.configuration;
  const h = await pin(provider, d, tag); await dependencies(provider, d, tag); const { sale, program } = await records(provider, plan, tag);
  const [[paused], [artistUsed], [executionId], [used], [ledgerUsed]] = await Promise.all([
    rpc(provider, d.adapter.address, saleAbi, "paused", [], tag), rpc(provider, d.adapter.address, saleAbi, "authorizationUsed", [a.artist, a.nonce], tag),
    rpc(provider, d.adapter.address, saleAbi, "executionIdByNonce", [a.saleId, a.executionNonce], tag),
    rpc(provider, d.manager.address, managerAbi, "isAuthorizationUsed", [plan.signing.authorizationId], tag),
    rpc(provider, d.ledger.address, ledgerAbi, "isManagerAuthorizationUsed", [d.manager.address, plan.signing.authorizationId], tag),
  ]);
  if (paused || sale.cancelled || artistUsed || used || ledgerUsed || executionId !== ZeroHash || h.timestamp < c.startsAt || h.timestamp > c.endsAt || h.timestamp > a.deadline) throw Error("Sale unavailable or authorization/execution already consumed");
  const sources: ERC20BurnMintSource[] = [];
  for (const tokenId of plan.signing.execution.sourceTokenIds) {
    const [identity, [owner], [approved]] = await Promise.all([
      rpc(provider, d.core.address, coreAbi, "tokenCollectionIdentity", [tokenId], tag), rpc(provider, d.core.address, coreAbi, "ownerOf", [tokenId], tag), rpc(provider, d.core.address, coreAbi, "getApproved", [tokenId], tag),
    ]);
    if (!identity[0] || identity[3] || !program.config.sourceCollectionIds.includes(identity[1] as bigint)) throw Error("Source identity is absent, burned or not permitted");
    const holder = address(owner), approvedTo = address(approved, true), collectionId = uint(identity[1], 256, true), collectionSerial = uint(identity[2], 256, true), nullifier = burnMintNullifier(d.chainId, d.core.address, tokenId);
    const [[executorOp], [gateOp], [blocked], [isFrozen], [managerUsed], [nullifierUsed], [onchainNullifier]] = await Promise.all([
      rpc(provider, d.core.address, coreAbi, "isApprovedForAll", [holder, plan.caller], tag), rpc(provider, d.core.address, coreAbi, "isApprovedForAll", [holder, d.gate.address], tag),
      rpc(provider, d.core.address, coreAbi, "collectionBurnsBlocked", [collectionId], tag), rpc(provider, d.core.address, coreAbi, "collectionFreezeStatus", [collectionId], tag),
      rpc(provider, d.manager.address, managerAbi, "isNullifierUsed", [nullifier], tag), rpc(provider, d.ledger.address, ledgerAbi, "isManagerNullifierUsed", [d.manager.address, nullifier], tag),
      rpc(provider, d.gate.address, gateAbi, "burnNullifier", [tokenId], tag),
    ]);
    if ((!same(holder, plan.caller) && !same(approvedTo, plan.caller) && !executorOp) || (!same(approvedTo, d.gate.address) && !gateOp)) throw Error("Executor and gate require independent NFT authority");
    if (blocked || isFrozen || managerUsed || nullifierUsed || !same(onchainNullifier, nullifier)) throw Error("Source burn blocked or nullifier consumed");
    sources.push(Object.freeze({ tokenId, collectionId, collectionSerial, owner: holder, approved: approvedTo, executorOperatorApproved: boolean(executorOp), gateOperatorApproved: boolean(gateOp), nullifier }));
  }
  const [preview] = await rpc(provider, d.adapter.address, saleAbi, "previewExecution", [plan.signing.execution], tag, plan.caller);
  const candidate = validateCandidate(plan, sale, resultTuple<ERC20SettlementCandidate>(saleAbi, "previewExecution", preview, true));
  await unchanged(provider, h); return frozen({ prepared: plan, blockNumber: tag, blockHash: h.hash, sale, program, sources, candidate });
}

function capture(value: ERC20BurnMintCapture): ERC20BurnMintCapture {
  keys(value, ["prepared", "blockNumber", "blockHash", "sale", "program", "sources", "candidate"]);
  const p = prepared(value.prepared), sale = resultTuple<ERC20BurnMintSaleRecord>(saleAbi, "saleRecord", value.sale), program = resultTuple<ERC20BurnMintProgram>(gateAbi, "program", value.program);
  equal(sale.config, p.signing.configuration); validateERC20BurnMintProgram(sale.config, program.config, p.signing.execution.sourceTokenIds);
  const d = p.deployment, a = p.signing.execution.sale.authorization;
  if (sale.cancelled || sale.saleNonce === 0n || !same(sale.configHash, a.saleConfigHash)
    || !same(a.saleId, erc20BurnMintSaleId(d.chainId, d.adapter.address, sale.config.collectionId, sale.config.phaseId, sale.saleNonce))
    || !same(sale.lifecycle.paymentAdapter, d.payment.address) || !same(program.config.manager, d.manager.address)
    || !same(program.managerCodeHash, d.manager.codeHash) || program.nativeSaleCodeHash !== ZeroHash) throw Error("Capture sale/program binding differs");
  if (!same(program.configHash, erc20BurnMintProgramConfigHash(p.deployment.chainId, p.deployment.gate.address, p.deployment.core.address, p.deployment.moduleRegistry.address, program.config))) throw Error("Capture program hash differs");
  if (!Array.isArray(value.sources) || value.sources.length !== p.signing.execution.sourceTokenIds.length) throw Error("Capture source count differs");
  const sources = value.sources.map((s, i) => {
    keys(s, ["tokenId", "collectionId", "collectionSerial", "owner", "approved", "executorOperatorApproved", "gateOperatorApproved", "nullifier"]);
    const out = Object.freeze({ tokenId: uint(s.tokenId, 256, true), collectionId: uint(s.collectionId, 256, true), collectionSerial: uint(s.collectionSerial, 256, true), owner: address(s.owner), approved: address(s.approved, true), executorOperatorApproved: boolean(s.executorOperatorApproved), gateOperatorApproved: boolean(s.gateOperatorApproved), nullifier: hash(s.nullifier) });
    if (out.tokenId !== p.signing.execution.sourceTokenIds[i] || !program.config.sourceCollectionIds.includes(out.collectionId) || !same(out.nullifier, burnMintNullifier(p.deployment.chainId, p.deployment.core.address, out.tokenId))) throw Error("Capture source identity differs");
    if ((!same(out.owner, p.caller) && !same(out.approved, p.caller) && !out.executorOperatorApproved)
      || (!same(out.approved, d.gate.address) && !out.gateOperatorApproved)) throw Error("Capture lacks independent source authorities"); return out;
  });
  return frozen({ prepared: p, blockNumber: integer(value.blockNumber), blockHash: hash(value.blockHash), sale, program, sources, candidate: validateCandidate(p, sale, value.candidate) });
}
export function prepareERC20BurnMintFunding(input: ERC20BurnMintCapture, route: ERC20BurnMintFundingRoute): PreparedERC20BurnMintFunding {
  const cap = capture(input), p = cap.prepared, d = p.deployment, a = p.signing.execution.sale.authorization;
  let r: ERC20BurnMintFundingRoute, method: string, args: unknown[];
  switch (route.kind) {
    case "payer": keys(route, ["kind"]); r = Object.freeze({ kind: "payer" }); method = "settleERC20PrimarySaleByPayer"; args = [cap.candidate, p.signing.saleExecutionData]; break;
    case "intent": {
      keys(route, ["kind", "intent", "signature"]);
      const payload = erc20BurnMintPaymentIntentPayload(d.chainId, p.signing.configuration, a, route.intent);
      r = frozen({ kind: "intent", intent: payload.message, signature: bytes(route.signature, 65536) });
      method = "settleERC20PrimarySaleWithIntent"; args = [cap.candidate, r.intent, r.signature, p.signing.saleExecutionData]; break;
    }
    case "eip2612": {
      keys(route, ["kind", "permit"]); keys(route.permit, ["deadline", "v", "r", "s"]);
      const permit = Object.freeze({ deadline: uint(route.permit.deadline), v: uint(route.permit.v, 8), r: hash(route.permit.r, true), s: hash(route.permit.s, true) });
      if (permit.v !== 27n && permit.v !== 28n) throw Error("EIP2612 requires v 27 or 28");
      r = Object.freeze({ kind: "eip2612", permit }); method = "settleERC20PrimarySaleWithEIP2612Permit"; args = [cap.candidate, permit, p.signing.saleExecutionData]; break;
    }
    case "permit2": {
      keys(route, ["kind", "permit"]); keys(route.permit, ["nonce", "deadline", "signature"]);
      r = frozen({ kind: "permit2", permit: { nonce: uint(route.permit.nonce), deadline: uint(route.permit.deadline), signature: bytes(route.permit.signature, 65536) } });
      method = "settleERC20PrimarySaleWithPermit2"; args = [cap.candidate, r.permit, p.signing.saleExecutionData]; break;
    }
    default: throw Error("Unknown funding route");
  }
  if (r.kind !== "intent" && !same(a.payer, p.caller)) throw Error("This funding route requires the actual executor caller to be payer");
  return frozen({ capture: cap, caller: p.caller, route: r, candidateCommitment: erc20BurnMintCandidateCommitment(d.chainId, d.payment.address, d.recorder.address, cap.candidate), settlementKey: erc20BurnMintSettlementKey(d.chainId, d.recorder.address, d.adapter.address, cap.candidate.executionBinding.executionId), call: call(d.payment.address, paymentAbi, method, args) });
}
function funding(value: PreparedERC20BurnMintFunding): PreparedERC20BurnMintFunding { const p = prepareERC20BurnMintFunding(value.capture, value.route); equal(value, p); return p; }
function settlement(p: PreparedERC20BurnMintFunding, value: ERC20PrimarySettlementResult): ERC20PrimarySettlementResult {
  const r = resultTuple<ERC20PrimarySettlementResult>(recorderAbi, "settlementResult", value), c = p.capture.candidate;
  equal(r, { candidateCommitment: p.candidateCommitment, settlementKey: p.settlementKey, profileId: c.rights.profileId, wallet: c.rights.wallet, asset: c.asset, amount: c.sale.amount, executor: c.executor, executionId: c.executionBinding.executionId, escrowed: r.escrowed, operationIdentityCommitment: c.operationIdentityCommitment, currentPolicyHash: c.currentPolicyHash, boundPolicyHash: c.boundPolicyHash }, "Settlement result differs from candidate"); return r;
}
/** Re-preview at one pinned block, compare the complete candidate, then eth_call the exact contract20 route. */
export async function simulateERC20BurnMintFunding(provider: Reader, input: PreparedERC20BurnMintFunding, options: { readonly blockTag: number }): Promise<ERC20PrimarySettlementResult> {
  const p = funding(input), tag = integer(options.blockTag), d = p.capture.prepared.deployment;
  const current = await inspectERC20BurnMintExecution(provider, p.capture.prepared, { blockTag: tag });
  equal(current.candidate, p.capture.candidate, "Current preview differs from frozen funding candidate");
  equal(current.sources, p.capture.sources, "Current source approval/identity evidence differs from capture");
  equal(current.program, p.capture.program, "Current program differs from capture");
  equal(current.sale, p.capture.sale, "Current sale differs from capture");
  if (p.route.kind === "intent") {
    const payload = erc20BurnMintPaymentIntentPayload(d.chainId, p.capture.prepared.signing.configuration, p.capture.prepared.signing.execution.sale.authorization, p.route.intent);
    const [[used], [digest]] = await Promise.all([rpc(provider, d.payment.address, paymentAbi, "isPaymentIntentNonceUsed", [p.route.intent.payer, p.route.intent.nonce], tag), rpc(provider, d.payment.address, paymentAbi, "paymentIntentDigest", [p.route.intent], tag)]);
    if (used || !same(digest, payload.digest)) throw Error("Payment intent nonce or digest differs");
  }
  const method = paymentAbi.getFunction(p.call.data.slice(0, 10))!, args = paymentAbi.decodeFunctionData(method, p.call.data);
  const [raw] = await rpc(provider, d.payment.address, paymentAbi, method.name, [...args], tag, p.caller);
  const result = settlement(p, resultTuple<ERC20PrimarySettlementResult>(paymentAbi, method.name, raw, true));
  if (!same((await header(provider, tag)).hash, current.blockHash)) throw Error("Funding block changed"); return result;
}
export function prepareERC20BurnMintAction(input: ERC20BurnMintDeployment, caller: Address, value: ERC20BurnMintAction): PreparedERC20BurnMintAction {
  const d = deployment(input), actor = address(caller); let action: ERC20BurnMintAction, args: unknown[], expectedIdentity: Hex | null = null;
  const common = ["target", "kind"];
  switch (value.kind) {
    case "registerSale": {
      keys(value, [...common, "configuration", "expectedNonce"]); if (value.target !== "sale") throw Error("Wrong action target");
      const configuration = normalizeERC20BurnMintSaleConfig(value.configuration), expectedNonce = uint(value.expectedNonce, 256, true);
      if (!same(configuration.asset, d.asset.address) || !same(configuration.paymentAdapter, d.payment.address)) throw Error("Registration asset/payment differs");
      action = { target: "sale", kind: value.kind, configuration, expectedNonce }; args = [configuration]; expectedIdentity = erc20BurnMintSaleId(d.chainId, d.adapter.address, configuration.collectionId, configuration.phaseId, expectedNonce); break;
    }
    case "configureProgram": {
      keys(value, [...common, "configuration"]); if (value.target !== "gate") throw Error("Wrong action target"); const configuration = normalizeERC20BurnMintProgramConfig(value.configuration);
      if (!same(configuration.manager, d.manager.address)) throw Error("Program manager differs"); action = { target: "gate", kind: value.kind, configuration }; args = [configuration];
      expectedIdentity = erc20BurnMintProgramConfigHash(d.chainId, d.gate.address, d.core.address, d.moduleRegistry.address, configuration); break;
    }
    case "cancelSale": keys(value, [...common, "saleId"]); if (value.target !== "sale") throw Error("Wrong action target"); action = { target: "sale", kind: value.kind, saleId: hash(value.saleId) }; args = [action.saleId]; break;
    case "setPaused": keys(value, [...common, "paused"]); if (value.target !== "sale") throw Error("Wrong action target"); action = { target: "sale", kind: value.kind, paused: boolean(value.paused) }; args = [action.paused]; break;
    case "cancelAuthorization": case "revokePaymentIntent": {
      keys(value, [...common, "nonce"]); const target = value.kind === "cancelAuthorization" ? "sale" : "payment"; if (value.target !== target) throw Error("Wrong action target");
      action = value.kind === "cancelAuthorization" ? { target: "sale", kind: value.kind, nonce: hash(value.nonce, true) } : { target: "payment", kind: value.kind, nonce: hash(value.nonce, true) }; args = [action.nonce]; break;
    }
    case "revokePaymentIntentWithSignature": {
      keys(value, [...common, "revocation", "signature"]); if (value.target !== "payment") throw Error("Wrong action target"); keys(value.revocation, ["payer", "nonce", "deadline"]);
      action = { target: "payment", kind: value.kind, revocation: { payer: address(value.revocation.payer), nonce: hash(value.revocation.nonce, true), deadline: uint(value.revocation.deadline, 64) }, signature: bytes(value.signature, 65536) }; args = [action.revocation, action.signature]; break;
    }
    case "approve": {
      if (value.target === "asset") { keys(value, [...common, "spender", "amount"]); action = { target: "asset", kind: value.kind, spender: address(value.spender), amount: uint(value.amount) }; args = [action.spender, action.amount]; }
      else { keys(value, [...common, "approved", "tokenId"]); if (value.target !== "core") throw Error("Wrong action target"); action = { target: "core", kind: value.kind, approved: address(value.approved, true), tokenId: uint(value.tokenId, 256, true) }; args = [action.approved, action.tokenId]; } break;
    }
    case "setApprovalForAll": keys(value, [...common, "operator", "approved"]); if (value.target !== "core") throw Error("Wrong action target"); action = { target: "core", kind: value.kind, operator: address(value.operator), approved: boolean(value.approved) }; args = [action.operator, action.approved]; break;
    case "transferOwnership": case "renounceOwnership": case "raiseGasParameter": {
      if (value.target !== "sale" && value.target !== "gate") throw Error("Wrong admin target");
      if (value.kind === "transferOwnership") { keys(value, [...common, "newOwner"]); action = { target: value.target, kind: value.kind, newOwner: address(value.newOwner) }; args = [action.newOwner]; }
      else if (value.kind === "raiseGasParameter") { keys(value, [...common, "parameterId", "value"]); action = { target: value.target, kind: value.kind, parameterId: hash(value.parameterId), value: uint(value.value) }; args = [action.parameterId, action.value]; }
      else { keys(value, common); action = { target: value.target, kind: value.kind }; args = []; } break;
    }
    default: throw Error("Unknown action; callbacks and preview are not user transaction plans");
  }
  const target = action.target === "sale" ? d.adapter : d[action.target];
  return frozen({ deployment: d, caller: actor, action, expectedIdentity, call: call(target.address, interfaces[action.target], action.kind, args) });
}
function actionPlan(input: PreparedERC20BurnMintAction): PreparedERC20BurnMintAction { const p = prepareERC20BurnMintAction(input.deployment, input.caller, input.action); equal(input, p); return p; }
export async function simulateERC20BurnMintAction(provider: Reader, input: PreparedERC20BurnMintAction, options: { readonly blockTag: number }): Promise<void> {
  const p = actionPlan(input), tag = integer(options.blockTag), h = await pin(provider, p.deployment, tag), abi = interfaces[p.action.target];
  if (p.action.kind === "registerSale") { const [nonce] = await rpc(provider, p.deployment.adapter.address, saleAbi, "nextSaleNonce", [], tag); if (nonce !== p.action.expectedNonce) throw Error("Registration nonce changed"); }
  const args = abi.decodeFunctionData(p.action.kind, p.call.data), result = await rpc(provider, p.call.to, abi, p.action.kind, [...args], tag, p.caller);
  if (p.expectedIdentity !== null && !same(result[0], p.expectedIdentity)) throw Error("Simulated configuration identity differs");
  if (p.action.target === "asset" && result[0] !== true) throw Error("Token approval did not succeed"); await unchanged(provider, h);
}

type MinedLog = { readonly address: Address; readonly topics: readonly Hex[]; readonly data: Hex; readonly index: number };
type Mined = { readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex; readonly logs: readonly MinedLog[]; readonly safeEvent: ERC20BurnMintEventReference | null };
type ReceiptEvidence = { readonly transactionHash: Hex; readonly execution: "direct" | "safe" };
async function mined(provider: ReceiptReader, caller: Address, expected: UnsignedCall, evidence: ReceiptEvidence): Promise<Mined> {
  keys(evidence, ["transactionHash", "execution"]); const transactionHash = hash(evidence.transactionHash), mode = evidence.execution;
  if (mode !== "direct" && mode !== "safe") throw Error("Unknown receipt execution mode");
  const [tx, receipt] = await Promise.all([provider.getTransaction(transactionHash), provider.getTransactionReceipt(transactionHash)]);
  if (!tx || !receipt || !same(tx.hash, transactionHash) || !same(receipt.hash, transactionHash) || receipt.status !== 1 || tx.blockNumber === null || tx.blockHash === null
    || receipt.blockNumber !== tx.blockNumber || !same(receipt.blockHash, tx.blockHash) || tx.value !== 0n || !tx.to) throw Error("Successful mined transaction/receipt identity differs");
  const data = bytes(tx.data, 524288), blockNumber = integer(receipt.blockNumber), blockHash = hash(receipt.blockHash);
  if (mode === "direct") { if (!same(tx.from, caller) || !same(tx.to, expected.to) || !same(data, expected.data)) throw Error("Direct funding/action CALL differs"); }
  else {
    if (!same(tx.to, caller)) throw Error("Safe target differs from actual caller");
    const q = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(safeAbi.encodeFunctionData("execTransaction", q), data) || !same(q.to, expected.to) || q.value !== 0n || q.operation !== 0n || !same(q.data, expected.data)) throw Error("Safe envelope differs from exact ordinary zero CALL");
  }
  if (!Array.isArray(receipt.logs) || receipt.logs.length > 512) throw Error("Receipt exceeds 512-log client bound");
  let previous = -1;
  const logs = receipt.logs.map(l => {
    if (l.removed || !same(l.transactionHash, transactionHash) || l.blockNumber !== blockNumber || !same(l.blockHash, blockHash) || integer(l.index) <= previous || l.topics.length < 1 || l.topics.length > 4) throw Error("Receipt log identity/order differs");
    previous = l.index; return Object.freeze({ address: address(l.address), topics: Object.freeze(l.topics.map((t: string) => hash(t, true))), data: bytes(l.data), index: l.index });
  });
  const out: Mined = { transactionHash, blockNumber, blockHash, logs, safeEvent: null };
  if (mode === "safe") {
    const successes = logs.filter(l => same(l.address, caller) && same(l.topics[0], safeEvents.getEvent("ExecutionSuccess")!.topicHash));
    if (logs.some(l => same(l.address, caller) && same(l.topics[0], safeEvents.getEvent("ExecutionFailure")!.topicHash)) || successes.length !== 1) throw Error("Expected one Safe ExecutionSuccess and no ExecutionFailure");
    const abi = successes[0]!.topics.length === 2 ? indexedSafeEvents : safeEvents, success = events(out, caller, abi, "ExecutionSuccess")[0]!;
    hash(success.args.txHash); return frozen({ ...out, safeEvent: success.ref });
  }
  return frozen(out);
}
function events(m: Mined, target: Address, abi: Interface, name: string): { readonly args: Record<string, unknown>; readonly ref: ERC20BurnMintEventReference }[] {
  const fragment = abi.getEvent(name)!;
  return m.logs.filter(l => same(l.address, target) && same(l.topics[0], fragment.topicHash)).map(l => {
    const values = abi.decodeEventLog(fragment, l.data, [...l.topics]), canonical = abi.encodeEventLog(fragment, values);
    if (!same(canonical.data, l.data)) throw Error(`Noncanonical ${name} event`); equal(canonical.topics.map(t => t.toLowerCase()), l.topics, `Noncanonical ${name} topics`);
    const args = Object.fromEntries(fragment.inputs.map((p, i) => [p.name, tuple(p, values[i], true)]));
    return { args: Object.freeze(args), ref: Object.freeze({ address: target, event: name, logIndex: l.index, transactionHash: m.transactionHash, blockHash: m.blockHash }) };
  });
}
function one(m: Mined, target: Address, abi: Interface, name: string, expected: Record<string, unknown>, refs: ERC20BurnMintEventReference[]): Record<string, unknown> {
  const found = events(m, target, abi, name); if (found.length !== 1) throw Error(`Expected one ${name} event`);
  for (const [key, value] of Object.entries(expected)) equal(found[0]!.args[key], value, `${name}.${key} differs`); refs.push(found[0]!.ref); return found[0]!.args;
}
function gateHash(p: PreparedERC20BurnMintFunding): Hex {
  const cap = p.capture, plan = cap.prepared, d = plan.deployment, a = plan.signing.execution.sale.authorization, c = plan.signing.configuration;
  const batch = [c.collectionId, c.phaseId, a.payer, ZeroAddress, [a.recipient], [a.recipient], [plan.signing.execution.sale.tokenData], [a.mintCommitment], c.mintPolicyHash, plan.signing.authorizationId, plan.signing.contextHash, "0x"];
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "address", "tuple(uint256,bytes32,address,address,address[],address[],bytes[],bytes32[],bytes32,bytes32,bytes32,bytes)", "uint256[]", "address[]", "uint256[]", "uint256[]", "bytes32[]"],
    [id("6529STREAM_BURN_MINT_RESULT_V1"), d.chainId, d.gate.address, d.core.address, cap.program.configHash, a.executor, batch, cap.sources.map(s => s.tokenId), cap.sources.map(s => s.owner), cap.sources.map(s => s.collectionId), cap.sources.map(s => s.collectionSerial), cap.sources.map(s => s.nullifier)])) as Hex;
}
/** Exact mined result evidence. Historical validation deliberately does not run new-execution admission checks. */
export async function inspectERC20BurnMintFundingReceipt(provider: ReceiptReader, input: PreparedERC20BurnMintFunding, evidence: ReceiptEvidence): Promise<ERC20BurnMintCompleted> {
  const p = funding(input), plan = p.capture.prepared, d = plan.deployment, c = p.capture.candidate, a = plan.signing.execution.sale.authorization;
  const m = await mined(provider, p.caller, p.call, evidence), h = await pin(provider, d, m.blockNumber);
  if (!same(h.hash, m.blockHash)) throw Error("Receipt block is not canonical");
  const refs: ERC20BurnMintEventReference[] = m.safeEvent ? [m.safeEvent] : [], executions = events(m, d.adapter.address, saleAbi, "UniversalSaleExecution");
  if (executions.length !== 2) throw Error("Expected active and completed UniversalSaleExecution events");
  const tokenId = uint(executions[1]!.args.tokenId, 256, true), root = c.operationIdentityCommitment, operationId = c.operationId, executionId = c.executionBinding.executionId;
  for (let i = 0; i < 2; i++) {
    equal(executions[i]!.args, { saleId: a.saleId, executionId, operationRoot: root, schemaVersion: 1n, status: BigInt(i + 1), settlementKey: i === 0 ? ZeroHash : p.settlementKey, tokenId: i === 0 ? 0n : tokenId }, "Universal execution event differs"); refs.push(executions[i]!.ref);
  }
  const schema = { schemaVersion: 1n }, mint = { collectionId: c.sale.collectionId, phaseId: plan.signing.configuration.phaseId }, policies = { currentPolicyHash: c.currentPolicyHash, boundPolicyHash: c.boundPolicyHash };
  if (p.route.kind === "intent") one(m, d.payment.address, paymentAbi, "PaymentIntentConsumed", { payer: p.route.intent.payer, saleRef: a.saleId, nonce: p.route.intent.nonce, ...schema, asset: c.asset, amount: c.sale.amount }, refs);
  const gate = gateHash(p), auth = plan.signing.authorizationId;
  one(m, d.gate.address, gateAbi, "BurnMintBatchExecuted", { ...schema, targetCollectionId: c.sale.collectionId, operationRoot: root, burnCaller: p.caller, sourceTokenIds: p.capture.sources.map(s => s.tokenId), sourceOwners: p.capture.sources.map(s => s.owner), mintedTokenIds: [tokenId] }, refs);
  const burns = events(m, d.gate.address, gateAbi, "BurnMintExecuted"), transfers = events(m, d.core.address, coreAbi, "Transfer"), coreBurns = events(m, d.core.address, coreAbi, "StreamTokenBurned").filter(e => p.capture.sources.some(s => s.tokenId === e.args.tokenId)), nullifierEvents = events(m, d.ledger.address, ledgerAbi, "MintLedgerNullifierConsumed");
  if (burns.length !== p.capture.sources.length || coreBurns.length !== p.capture.sources.length || nullifierEvents.length !== p.capture.sources.length) throw Error("Source burn/nullifier event count differs");
  for (const [i, s] of p.capture.sources.entries()) {
    equal(burns[i]!.args, { ...schema, sourceTokenId: s.tokenId, mintedTokenId: tokenId, targetCollectionId: c.sale.collectionId, burnNullifier: s.nullifier, redeemer: p.caller }, "BurnMintExecuted differs"); refs.push(burns[i]!.ref);
    equal(coreBurns[i]!.args, { tokenId: s.tokenId, collectionId: s.collectionId, collectionSerial: s.collectionSerial, ...schema }, "Core burn differs"); refs.push(coreBurns[i]!.ref);
    equal(nullifierEvents[i]!.args, { ...schema, nullifier: s.nullifier, operationRoot: root, manager: d.manager.address, boundPolicyHash: c.boundPolicyHash }, "Ledger nullifier differs"); refs.push(nullifierEvents[i]!.ref);
    const burnTransfer = transfers.filter(t => t.args.tokenId === s.tokenId && same(t.args.from, s.owner) && same(t.args.to, ZeroAddress));
    if (burnTransfer.length !== 1) throw Error("Missing/duplicate original source burn Transfer"); refs.push(burnTransfer[0]!.ref);
  }
  const mintTransfer = transfers.filter(t => t.args.tokenId === tokenId && same(t.args.from, ZeroAddress) && same(t.args.to, a.recipient));
  if (mintTransfer.length !== 1) throw Error("Missing/duplicate original mint Transfer"); refs.push(mintTransfer[0]!.ref);
  one(m, d.manager.address, managerAbi, "MintGateValidated", { ...mint, gate: d.gate.address, authorizationId: auth, authorizer: ZeroAddress, quantity: 1n, contextHash: plan.signing.contextHash, gateHash: gate, policyHash: c.boundPolicyHash }, refs);
  one(m, d.manager.address, managerAbi, "MintAuthorizationConsumed", { ...schema, ...mint, authorizationId: auth, boundPolicyHash: c.boundPolicyHash, operationRoot: root }, refs);
  one(m, d.manager.address, managerAbi, "MintTokenExecuted", { ...schema, operationId, tokenId, operationRoot: root, ...mint, tokenIndex: 0n, initialRecipient: a.recipient, beneficiary: a.recipient, tokenDataHash: a.tokenDataHash, mintCommitment: a.mintCommitment }, refs);
  one(m, d.manager.address, managerAbi, "MintBatchExecuted", { ...schema, operationRoot: root, ...mint, executor: d.adapter.address, payer: a.payer, authorizer: ZeroAddress, firstTokenId: tokenId, quantity: 1n, contextHash: plan.signing.contextHash, gateHash: gate, ...policies }, refs);
  one(m, d.ledger.address, ledgerAbi, "MintLedgerAuthorizationConsumed", { ...schema, authorizationId: auth, operationRoot: root, manager: d.manager.address, boundPolicyHash: c.boundPolicyHash }, refs);
  one(m, d.ledger.address, ledgerAbi, "MintLedgerOperationRootConsumed", { ...schema, operationRoot: root, manager: d.manager.address, ...policies, authorizationId: auth }, refs);
  const revenue = { ...schema, settlementKey: p.settlementKey, revenueClass: c.sale.revenueClass, profileId: c.rights.profileId };
  one(m, d.recorder.address, recorderAbi, "PrimaryRevenueExecutionBound", { ...schema, settlementKey: p.settlementKey, saleAdapter: d.adapter.address, executionId, executor: p.caller, paymentAdapter: d.payment.address, candidateCommitment: p.candidateCommitment, ...policies }, refs);
  const candidateParam = saleAbi.getFunction("previewExecution")!.outputs[0]!, saleParam = candidateParam.components!.find(v => v.name === "sale")!;
  one(m, d.recorder.address, recorderAbi, "PrimaryRevenueSettled", { ...revenue, wallet: c.rights.wallet, asset: c.asset, payer: a.payer, amount: c.sale.amount, saleContextHash: keccak256(coder.encode([saleParam], [c.sale])), policyDrift: false, assignmentType: 1n }, refs);
  one(m, d.recorder.address, recorderAbi, "PrimaryRevenueSettlementPolicy", { ...revenue, expectedPrimaryPolicyHash: c.sale.expectedPrimaryPolicyHash, resolvedPrimaryPolicyHash: c.sale.expectedPrimaryPolicyHash, resolvedAssignmentHash: c.rights.assignmentHash, templateId: ZeroHash }, refs);
  one(m, d.recorder.address, recorderAbi, "PrimaryRevenueSettlementContext", { ...revenue, settlementCaller: d.adapter.address, settlementId: a.saleId, policyMode: 0n, collectionId: c.sale.collectionId, tokenId: 0n, operationRoot: root, operationId, saleNonce: c.sale.saleNonce, poster: ZeroAddress, beneficiary: a.recipient, templateId: ZeroHash }, refs);
  const tag = m.blockNumber, [[storedId], [status], [artistUsed], [managerAuth], [ledgerAuth], [managerRoot], [ledgerRoot], [consumed], [storedResult], identity] = await Promise.all([
    rpc(provider, d.adapter.address, saleAbi, "executionIdByNonce", [a.saleId, a.executionNonce], tag), rpc(provider, d.adapter.address, saleAbi, "executionStatus", [executionId], tag),
    rpc(provider, d.adapter.address, saleAbi, "authorizationUsed", [a.artist, a.nonce], tag), rpc(provider, d.manager.address, managerAbi, "isAuthorizationUsed", [auth], tag),
    rpc(provider, d.ledger.address, ledgerAbi, "isManagerAuthorizationUsed", [d.manager.address, auth], tag), rpc(provider, d.manager.address, managerAbi, "isOperationRootUsed", [root], tag),
    rpc(provider, d.ledger.address, ledgerAbi, "isManagerOperationRootUsed", [d.manager.address, root], tag), rpc(provider, d.recorder.address, recorderAbi, "settlementConsumed", [p.settlementKey], tag),
    rpc(provider, d.recorder.address, recorderAbi, "settlementResult", [p.settlementKey], tag), rpc(provider, d.core.address, coreAbi, "tokenCollectionIdentity", [tokenId], tag),
  ]);
  if (!same(storedId, executionId) || status !== 2n || !artistUsed || !managerAuth || !ledgerAuth || !managerRoot || !ledgerRoot || !consumed || !identity[0] || identity[1] !== c.sale.collectionId || uint(identity[2]) === 0n) throw Error("Completed execution/replay/mint identity readback differs");
  // A later transaction in this block may transfer or burn the output; original mint evidence remains authoritative.
  const result = settlement(p, resultTuple<ERC20PrimarySettlementResult>(recorderAbi, "settlementResult", storedResult, true));
  for (const s of p.capture.sources) {
    const [retained, [managerNullifier], [ledgerNullifier]] = await Promise.all([rpc(provider, d.core.address, coreAbi, "tokenCollectionIdentity", [s.tokenId], tag), rpc(provider, d.manager.address, managerAbi, "isNullifierUsed", [s.nullifier], tag), rpc(provider, d.ledger.address, ledgerAbi, "isManagerNullifierUsed", [d.manager.address, s.nullifier], tag)]);
    equal([...retained], [true, s.collectionId, s.collectionSerial, true], "Retained burned source identity differs"); if (!managerNullifier || !ledgerNullifier) throw Error("Source nullifier missing");
  }
  if (p.route.kind === "intent") { const [used] = await rpc(provider, d.payment.address, paymentAbi, "isPaymentIntentNonceUsed", [p.route.intent.payer, p.route.intent.nonce], tag); if (!used) throw Error("Completed payer intent not consumed"); }
  const bound = await records(provider, plan, tag); equal(bound.program, p.capture.program, "Historical program differs"); equal({ ...bound.sale, cancelled: p.capture.sale.cancelled }, p.capture.sale, "Historical sale differs");
  await unchanged(provider, h); return frozen({ prepared: p, transactionHash: m.transactionHash, blockNumber: tag, blockHash: m.blockHash, tokenId, operationRoot: root, operationId, settlement: result, events: refs.sort((x, y) => x.logIndex - y.logIndex) });
}

/** Mined configuration evidence is supported for immutable program creation and sale registration. */
export async function inspectERC20BurnMintActionReceipt(provider: ReceiptReader, input: PreparedERC20BurnMintAction, evidence: ReceiptEvidence): Promise<{ readonly prepared: PreparedERC20BurnMintAction; readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex; readonly events: readonly ERC20BurnMintEventReference[] }> {
  const p = actionPlan(input), a = p.action, d = p.deployment;
  if (a.kind !== "registerSale" && a.kind !== "configureProgram") throw Error("Action receipt readback supports registerSale/configureProgram only");
  const m = await mined(provider, p.caller, p.call, evidence), h = await pin(provider, d, m.blockNumber), refs: ERC20BurnMintEventReference[] = m.safeEvent ? [m.safeEvent] : [];
  if (!same(h.hash, m.blockHash)) throw Error("Configuration receipt block is not canonical");
  if (a.kind === "registerSale") {
    const configHash = erc20BurnMintConfigurationHash(p.expectedIdentity!, a.configuration);
    one(m, d.adapter.address, saleAbi, "UniversalSaleConfigured", { saleId: p.expectedIdentity, collectionId: a.configuration.collectionId, phaseId: a.configuration.phaseId, schemaVersion: 1n, saleNonce: a.expectedNonce, configHash, paymentAdapter: d.payment.address }, refs);
    const [raw] = await rpc(provider, d.adapter.address, saleAbi, "saleRecord", [p.expectedIdentity], m.blockNumber), sale = resultTuple<ERC20BurnMintSaleRecord>(saleAbi, "saleRecord", raw, true);
    equal(sale.config, a.configuration, "Registered sale differs"); if (sale.saleNonce !== a.expectedNonce || !same(sale.configHash, configHash) || !same(sale.lifecycle.paymentAdapter, d.payment.address) || sale.lifecycle.saleCreatedAt !== h.timestamp) throw Error("Registered sale identity/lifecycle differs");
  } else {
    one(m, d.gate.address, gateAbi, "BurnMintProgramConfigured", { schemaVersion: 1n, targetCollectionId: a.configuration.targetCollectionId, manager: d.manager.address, phaseId: a.configuration.phaseId, configHash: p.expectedIdentity, config: a.configuration }, refs);
    const [[raw], [allowed]] = await Promise.all([rpc(provider, d.gate.address, gateAbi, "program", [a.configuration.targetCollectionId], m.blockNumber), rpc(provider, d.gate.address, gateAbi, "allowedSourceCollections", [a.configuration.targetCollectionId], m.blockNumber)]);
    const program = resultTuple<ERC20BurnMintProgram>(gateAbi, "program", raw, true);
    equal(program, { config: a.configuration, configHash: p.expectedIdentity, managerCodeHash: d.manager.codeHash, nativeSaleCodeHash: ZeroHash }, "Configured program readback differs"); equal([...allowed as bigint[]], a.configuration.sourceCollectionIds, "Configured allowed sources differ");
  }
  await unchanged(provider, h); return frozen({ prepared: p, transactionHash: m.transactionHash, blockNumber: m.blockNumber, blockHash: m.blockHash, events: refs });
}
