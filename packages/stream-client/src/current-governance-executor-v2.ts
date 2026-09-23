import { AbiCoder, Interface, ParamType, ZeroAddress, concat, getAddress, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";

/** ABI164 lifecycle encodings. Pure supplied-fact checks do not establish a sealed deployment,
 * actor authority, catalog admission, selected target runtime, or successful target effects. */
export const GOVERNANCE_EXECUTOR_V2_SOURCE = "eda052c75dc9fd5c4e2e658bdf453ab01f5b7c0e";
/** Local allocation/display/transport limits, not general Solidity URI or call-count limits. */
export const GOVERNANCE_EXECUTOR_V2_LIMITS = Object.freeze({ calls: 256, reasonUriBytes: 2048, bytes: 2097152, publicationBytes: 24575, terminalPage: 64 });
export const GOVERNANCE_EXECUTOR_V2_CALL_TUPLE = "tuple(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
export const GOVERNANCE_EXECUTOR_V2_ACTION_TUPLE = "tuple(uint8 status,uint8 actionClass,address target,uint256 value,bytes4 selector,bytes32 callHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint64 notBefore,uint64 expiresAfter,address proposer,address executor,address canceller,address vetoer,bytes32 reasonHash,string reasonURI,bytes32 manifestHash)";
export const GOVERNANCE_EXECUTOR_V2_ACTION_FACTS_TUPLE = "tuple(uint8 status,uint8 actionClass,bytes32 callHash,uint64 notBefore,uint64 expiresAfter)";
export const GOVERNANCE_EXECUTOR_V2_ACTION_IDENTITY_TUPLE = "tuple(uint8 actionClass,bytes32 callsHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint256 nonce,uint64 notBefore,uint64 expiresAfter,bytes32 reasonHash,bytes32 manifestHash)";
export const GOVERNANCE_EXECUTOR_V2_SCHEDULE_ACTION_TUPLE = "tuple(uint8 actionClass,address target,uint256 value,bytes4 selector,bytes callData,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint64 notBefore,uint64 expiresAfter,bytes32 reasonHash,string reasonURI,bytes32 manifestHash)";
export const GOVERNANCE_EXECUTOR_V2_DOMAINS = Object.freeze({
  calls: "0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70",
  action: "0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b",
  scope: "0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c",
  oldValue: "0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7",
  newValue: "0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b",
});

export const GOVERNANCE_EXECUTOR_V2_ABI = [
  "function publishGovernanceCallData(bytes[] callDatas) returns (address pointer)",
  "function scheduleGovernanceAction((uint8 actionClass, address target, uint256 value, bytes4 selector, bytes callData, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, bytes32 reasonHash, string reasonURI, bytes32 manifestHash) request) returns (bytes32 actionId)",
  "function scheduleGovernanceBatch(uint8 actionClass, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, bytes32 reasonHash, string reasonURI, bytes32 manifestHash) returns (bytes32 actionId)",
  "function executeGovernanceAction(bytes32 actionId, bytes callData) payable",
  "function executeGovernanceBatch(bytes32 actionId, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes[] callDatas) payable",
  "function cancelGovernanceAction(bytes32 actionId, bytes32 reasonHash)",
  "function vetoTerminalFreeze(bytes32 actionId, bytes32 reasonHash)",
  "function materializeExpiredAction(bytes32 actionId)",
  "function pruneElapsedTerminalFreezeActions(bytes32 scopeHash) returns (uint256 prunedCount)",
  "function owner() view returns (address)",
  "function roleRegistry() view returns (address)",
  "function supportsInterface(bytes4 interfaceId) pure returns (bool)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function governanceRootState() view returns (address governanceRoot_, bytes32 codeHash, uint64 revision)",
  "function currentAction() view returns (bool executing, bytes32 actionId, uint8 actionClass, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)",
  "function governanceNonce() view returns (uint256)",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function governanceActionFacts(bytes32 id) view returns ((uint8 status, uint8 actionClass, bytes32 callHash, uint64 notBefore, uint64 expiresAfter) facts)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function isProposer(address account) view returns (bool)",
  "function proposerConfig(address account) view returns (bool enabled, uint64 revision, bytes32 stateHash)",
  "function isCanceller(address account) view returns (bool)",
  "function cancellerConfig(address account) view returns (bool enabled, uint64 revision, bytes32 stateHash)",
  "function terminalFreezeGuardianConfigCommitment(bytes32 actionId) view returns (bytes32 commitment)",
  "function terminalFreezeActionPage(bytes32 scopeHash, uint256 cursor, uint256 limit) view returns (bytes32[] actionIds, uint64[] vetoDeadlines, uint256 nextCursor)",
  "function terminalFreezeLiveActionCaps() pure returns (uint256 totalCap, uint256 nonRootCap, uint256 perNonRootProposerCap)",
  "function terminalFreezeLiveActionUsage(bytes32 scopeHash, address proposer) view returns (uint256 totalMemberships, uint256 nonRootMemberships, uint256 proposerMemberships)",
  "function terminalFreezeVetoGuardian(bytes32 scopeHash) view returns (address guardian, uint64 vetoDeadline)",
  "function terminalFreezeVetoGuardianSet(bytes32 scopeHash) view returns (address roleRegistryAddress, bytes32 scopedRole, uint256 scopedHolderCount, bytes32 globalRole, uint256 globalHolderCount, uint64 vetoDeadline)",
  "function terminalFreezeVetoRole(bytes32 scopeHash) pure returns (bytes32)",
  "function liveTerminalFreezeActionCount(bytes32 scopeHash) view returns (uint256)",
  "function liveTerminalFreezeActionAt(bytes32 scopeHash, uint256 index) view returns (bytes32 actionId, uint64 vetoDeadline)",
  "function systemManifestBatchTailRule(address triggerTarget, bytes4 triggerSelector) view returns (bool registered, bytes32 triggerCodeHash, uint8 allowedActionClassMask, address tailTarget, bytes4 tailSelector, bytes32 tailCodeHash)",
  "function tighteningCallConfig(address target, bytes4 selector) view returns (bool tightening, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash)",
  "function freezeSelectorConfig(address target, bytes4 selector) view returns (bool freeze, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash)",
  "function approvedNativeReceiverConfig(address receiver) view returns (bool approved, uint64 revision, bytes32 stateHash)",
  "function isTighteningCall(address target, bytes4 selector) view returns (bool)",
  "function isFreezeSelector(address target, bytes4 selector) view returns (bool)",
  "function isApprovedNativeReceiver(address receiver) view returns (bool)",
  "function pendingScheduledActionCount() view returns (uint256)",
  "event GovernanceActionScheduled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, uint256 nonce, address proposer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash)",
  "event GovernanceActionExecuted(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, address executor, bytes32 manifestHash)",
  "event GovernanceActionCancelled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, bytes4 selector, bytes32 callHash, bytes32 scopeHash, address canceller, bytes32 reasonHash, string reasonURI)",
  "event GovernanceActionVetoed(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed vetoer, bytes32 scopeHash, bytes32 reasonHash)",
  "event GovernanceActionExpired(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address materializer)",
  "event GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed callDataKey, address pointer, address publisher)",
  "event TerminalFreezeActionMembershipUpdated(uint16 schemaVersion, bytes32 indexed scopeHash, bytes32 indexed actionId, address indexed proposer, bool present, uint8 mutationCause, bool usesRootCapacity, uint64 vetoDeadline, uint256 rawIndex, uint256 remainingCount)",
  "event TerminalFreezeGuardianConfigCommitted(uint16 schemaVersion, bytes32 indexed actionId, bytes32 indexed commitment)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed phase, bytes32 indexed candidateProfileHash, bytes32 catalogHash)",
  "error ActionIdMismatch(bytes32 actionId)",
  "error BatchNewValueHashMismatch(bytes32 expected, bytes32 supplied)",
  "error BatchOldValueHashMismatch(bytes32 expected, bytes32 supplied)",
  "error BatchScopeHashMismatch(bytes32 expected, bytes32 supplied)",
  "error BatchValueMismatch(uint256 expected, uint256 supplied)",
  "error BatchValueSurplus(uint256 surplus)",
  "error BootstrapActionNotPermitted()",
  "error CallDataCountMismatch(uint256 callCount, uint256 callDataCount)",
  "error CallDataHashMismatch(uint256 callIndex)",
  "error CallDataNotPublished(bytes32 callDataKey)",
  "error CallDataTooShort(uint256 callIndex)",
  "error CallSelectorMismatch(uint256 callIndex)",
  "error CallsHashMismatch(bytes32 actionId)",
  "error DelayBelowClassMinimum(uint8 actionClass, uint64 notBefore, uint64 earliest)",
  "error DirectOwnershipMutationDisabled()",
  "error EmptyGovernanceBatch()",
  "error ExecutorConfigActionClassMismatch(address target, bytes4 selector, bool enabled, uint8 expectedClass, uint8 actualClass)",
  "error ExecutorControlActionClassMismatch(address target, bytes4 selector, uint8 expectedClass, uint8 actualClass)",
  "error FreezeSelectorSelfTargetForbidden(bytes4 selector)",
  "error GenesisAlreadyInitialized()",
  "error GenesisBootstrapActorRequired(address actor)",
  "error GenesisDidNotSeal()",
  "error GenesisPlanAlreadyCommitted()",
  "error GenesisPlanHashMismatch(bytes32 expected, bytes32 actual)",
  "error GenesisPreparationAlreadyBound()",
  "error GovernanceActionExpiredWindow(bytes32 actionId, uint64 expiresAfter)",
  "error GovernanceActionNotExecutable(bytes32 actionId, uint64 notBefore)",
  "error GovernanceActionNotExpired(bytes32 actionId, uint64 expiresAfter)",
  "error GovernanceActionNotScheduled(bytes32 actionId)",
  "error GovernanceActionPolicyCallTypeMismatch(uint256 callIndex, uint8 expectedCallType, uint8 actualCallType)",
  "error GovernanceActionPolicyCatalogHashMismatch(bytes32 expected, bytes32 actual)",
  "error GovernanceActionPolicyEntriesNotSorted(uint256 index)",
  "error GovernanceActionPolicyEntryHashMismatch(uint256 callIndex, bytes32 expected, bytes32 actual)",
  "error GovernanceActionPolicyNotBound()",
  "error GovernanceActionPolicySnapshotMismatch(bytes32 actionId, bytes32 scheduledCatalogHash, bytes32 currentCatalogHash)",
  "error GovernanceActionPolicyTargetCodeHashMismatch(uint256 callIndex, address target, bytes32 expected, bytes32 actual)",
  "error GovernanceActionPolicyUnknown(uint256 callIndex, uint8 actionClass, address target, bytes4 selector)",
  "error GovernanceActionPolicyValueRejected(uint256 callIndex, uint8 valuePolicy, uint256 value, uint256 valueLimit)",
  "error GovernanceActionUnknown(bytes32 actionId)",
  "error GovernanceActorNotAuthorized(address actor)",
  "error GovernanceCallFailed(bytes32 actionId, uint256 callIndex)",
  "error GovernanceCallReturndataTooLarge(bytes32 actionId, uint256 callIndex, uint256 returnDataBytes, uint256 maxReturnDataBytes)",
  "error GovernanceCatalogDuplicateEntry(bytes32 key)",
  "error GovernanceCatalogExtensionComposition()",
  "error GovernanceCatalogExtensionSize(uint256 additions, uint256 total)",
  "error GovernanceCatalogRevisionMismatch(uint64 expected, uint64 actual)",
  "error GovernanceConfigNoOp(bytes32 configKind, address key, bool enabled)",
  "error GovernanceIdentityRoleOverlap(address account, bytes32 role)",
  "error GovernancePolicyCodeHashMismatch(address target, bytes4 selector, bytes32 expected, bytes32 actual)",
  "error GovernanceProposerAuthorizationDrift(bytes32 actionId, address proposer, uint64 expected, uint64 actual, bool enabled)",
  "error GovernanceRevisionOverflow(bytes32 configKind, address key)",
  "error GovernanceRootCodeHashMismatch(bytes32 expected, bytes32 actual)",
  "error GovernanceRootNoOp(address governanceRoot)",
  "error GovernanceRootProposerRequired(address proposer, address governanceRoot, address target, bytes4 selector)",
  "error GovernanceRootRevisionMismatch(bytes32 actionId, uint64 expected, uint64 actual)",
  "error GovernanceSchedulingDuringExecution()",
  "error GovernanceSelfCallContextRequired()",
  "error GovernanceTimestampOverflow(uint256 timestamp)",
  "error GovernanceTransitionContextMismatch()",
  "error InvalidActionWindow(uint64 notBefore, uint64 expiresAfter)",
  "error InvalidExecutorConfigCall(address target, bytes4 selector)",
  "error InvalidGenesisBootstrapAuthority(address authority)",
  "error InvalidGenesisPlan()",
  "error InvalidGovernanceActionPolicyCandidate(bytes32 candidateProfileHash)",
  "error InvalidGovernanceActionPolicyEntry(uint256 index)",
  "error InvalidGovernanceRoot(address governanceRoot)",
  "error InvalidManifestTail()",
  "error InvalidManifestTailTrigger(address target, bytes4 selector)",
  "error InvalidModuleRegistryStatusCall(address target)",
  "error InvalidRoleManagerConfigCall(address target)",
  "error InvalidRoleRegistry(address registry)",
  "error InvalidSystemManifestBootstrap()",
  "error LiveTerminalFreezeIndexOutOfBounds(bytes32 scopeHash, uint256 index)",
  "error ManifestTailActionClassNotAllowed(address target, bytes4 selector, uint8 actionClass)",
  "error ManifestTailCodeHashMismatch(bytes32 expected, bytes32 actual)",
  "error ManifestTailRequired()",
  "error ManifestTailTriggerAlreadyRegistered(address target, bytes4 selector)",
  "error ManifestTailTriggerIndexOutOfBounds(uint256 index)",
  "error ManifestTailTriggerRegistrationNotIsolated()",
  "error ModuleRegistryStatusActionClassMismatch(address target, address module, uint8 currentStatus, uint8 requestedStatus, uint8 expectedClass, uint8 actualClass)",
  "error NativeReceiverNotApproved(address target)",
  "error NoTerminalFreezeVetoGuardianConfigured(bytes32 scopeHash)",
  "error NonCanonicalCallDataPublication()",
  "error NotClassifiedTightening(address target, bytes4 selector)",
  "error NotTerminalFreezeAction(bytes32 actionId)",
  "error NotTerminalFreezeVetoGuardian(address actor)",
  "error OpenWindowBelowFloor(uint64 notBefore, uint64 expiresAfter)",
  "error PendingGovernanceActionExists(uint256 count)",
  "error ReentrancyGuardReentrantCall()",
  "error RoleManagerConfigActionClassMismatch(address target, address account, bool enabled, uint8 expectedClass, uint8 actualClass)",
  "error RoleRegistryCodeHashMismatch(bytes32 expected, bytes32 actual)",
  "error RoleRegistryDelayedActionRequired(uint8 actionClass)",
  "error ScheduledCallDataMismatch(uint256 callIndex)",
  "error StateExportAlreadyPublished(bytes32 exportHash)",
  "error StateExportAnchorNotIncreasing(uint256 previousBlock, uint256 proposedBlock)",
  "error StateExportChallengeAlreadyRecorded(bytes32 exportHash, bytes32 challengeHash)",
  "error StateExportDuringGovernanceExecution()",
  "error StateExportIndexOutOfBounds(uint256 index)",
  "error StateExportInvalidAnchor(uint256 blockNumber, bytes32 blockHash)",
  "error StateExportInvalidHash()",
  "error StateExportInvalidSupersession(bytes32 oldExportHash, bytes32 newExportHash)",
  "error StateExportInvalidURI()",
  "error StateExportPublisherInactive()",
  "error StateExportPublisherUnauthorized(address caller)",
  "error StateExportUnknown(bytes32 exportHash)",
  "error SystemManifestBootstrapAlreadyBound()",
  "error SystemManifestBootstrapAlreadySealed()",
  "error SystemManifestBootstrapNotBound()",
  "error SystemManifestBootstrapNotSealed()",
  "error TargetHasNoCode(uint256 callIndex, address target)",
  "error TerminalFreezeClassRequired(address target, bytes4 selector)",
  "error TerminalFreezeGuardianConfigDrift(bytes32 actionId, bytes32 expectedCommitment, bytes32 actualCommitment)",
  "error TerminalFreezeLiveActionCapExceeded(bytes32 scopeHash, uint256 cap)",
  "error TerminalFreezeNonRootLiveActionCapExceeded(bytes32 scopeHash, uint256 cap)",
  "error TerminalFreezePageCursorOutOfBounds(bytes32 scopeHash, uint256 cursor, uint256 membershipCount)",
  "error TerminalFreezePageLimitExceeded(uint256 limit, uint256 maxLimit)",
  "error TerminalFreezeProposerLiveActionCapExceeded(bytes32 scopeHash, address proposer, uint256 cap)",
  "error TighteningCallSelfTargetForbidden(bytes4 selector)",
  "error UnknownActionClass(uint8 actionClass)",
  "error VetoDeadlinePassed(bytes32 actionId, uint64 vetoDeadline)",
  "error ZeroCanceller()",
  "error ZeroFreezeSelector()",
  "error ZeroFreezeTarget()",
  "error ZeroGovernanceTarget(uint256 callIndex)",
  "error ZeroNativeReceiver()",
  "error ZeroProposer()",
  "error ZeroTighteningSelector()",
  "error ZeroTighteningTarget()",
] as const;

export interface GovernanceExecutorV2Coordinates { readonly chainId: bigint; readonly executor: Address }
export interface GovernanceExecutorV2CallDescriptor {
  readonly target: Address;
  readonly value: bigint;
  readonly selector: Hex;
  readonly callDataHash: Hex;
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
}
export interface GovernanceExecutorV2ActionFacts {
  readonly status: bigint;
  readonly actionClass: bigint;
  readonly callHash: Hex;
  readonly notBefore: bigint;
  readonly expiresAfter: bigint;
}
export interface GovernanceExecutorV2Action extends GovernanceExecutorV2ActionFacts {
  readonly target: Address;
  readonly value: bigint;
  readonly selector: Hex;
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
  readonly proposer: Address;
  readonly executor: Address;
  readonly canceller: Address;
  readonly vetoer: Address;
  readonly reasonHash: Hex;
  readonly reasonURI: string;
  readonly manifestHash: Hex;
}
export interface GovernanceExecutorV2ActionIdentity {
  readonly actionClass: bigint;
  readonly callsHash: Hex;
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
  readonly nonce: bigint;
  readonly notBefore: bigint;
  readonly expiresAfter: bigint;
  readonly reasonHash: Hex;
  readonly manifestHash: Hex;
}
export interface GovernanceExecutorV2ScheduleAction {
  readonly actionClass: bigint;
  readonly target: Address;
  readonly value: bigint;
  readonly selector: Hex;
  readonly callData: Hex;
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
  readonly notBefore: bigint;
  readonly expiresAfter: bigint;
  readonly reasonHash: Hex;
  readonly reasonURI: string;
  readonly manifestHash: Hex;
}
export interface GovernanceExecutorV2BatchHashes {
  readonly callsHash: Hex;
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
}
export interface GovernanceExecutorV2ScheduleBatch {
  readonly actionClass: bigint;
  readonly calls: readonly GovernanceExecutorV2CallDescriptor[];
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
  readonly notBefore: bigint;
  readonly expiresAfter: bigint;
  readonly reasonHash: Hex;
  readonly reasonURI: string;
  readonly manifestHash: Hex;
}
export type GovernanceExecutorV2Request =
  | { readonly method: "publishGovernanceCallData"; readonly callDatas: readonly Hex[] }
  | { readonly method: "scheduleGovernanceAction"; readonly request: GovernanceExecutorV2ScheduleAction }
  | ({ readonly method: "scheduleGovernanceBatch" } & GovernanceExecutorV2ScheduleBatch)
  | { readonly method: "executeGovernanceAction"; readonly actionId: Hex; readonly call: GovernanceExecutorV2CallDescriptor; readonly callData: Hex }
  | { readonly method: "executeGovernanceBatch"; readonly actionId: Hex; readonly calls: readonly GovernanceExecutorV2CallDescriptor[]; readonly callDatas: readonly Hex[] }
  | { readonly method: "cancelGovernanceAction" | "vetoTerminalFreeze"; readonly actionId: Hex; readonly reasonHash: Hex }
  | { readonly method: "materializeExpiredAction"; readonly actionId: Hex }
  | { readonly method: "pruneElapsedTerminalFreezeActions"; readonly scopeHash: Hex };
export interface GovernanceExecutorV2PreparedCall {
  readonly coordinates: GovernanceExecutorV2Coordinates;
  readonly caller: Address;
  readonly request: GovernanceExecutorV2Request;
  readonly call: UnsignedCall & { readonly operation: 0 };
  readonly authorityIndependentlyVerified: false;
  readonly targetEffectsIndependentlyVerified: false;
}

const coder = AbiCoder.defaultAbiCoder();
const iface = new Interface(GOVERNANCE_EXECUTOR_V2_ABI);
const maxUint = (bits: number): bigint => (1n << BigInt(bits)) - 1n;
const day = 86400n;
function fail(message: string): never { throw new Error(`Governance Executor V2: ${message}`); }
function exact(value: unknown, keys: readonly string[], label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) fail(`${label} must be an object`);
  const own = Reflect.ownKeys(value);
  if (own.length !== keys.length || own.some(k => typeof k !== "string" || !keys.includes(k))) fail(`${label} has unexpected or missing fields`);
  for (const key of keys) if (!Object.hasOwn(value, key)) fail(`${label}.${key} is missing`);
  return value as Record<string, unknown>;
}
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value > maxUint(bits)) fail(`value must be uint${bits} bigint`);
  return value;
}
function hex(value: unknown, bytes?: number, limit: number = GOVERNANCE_EXECUTOR_V2_LIMITS.bytes): Hex {
  if (typeof value !== "string" || value.length > 2 + 2 * limit || !isHexString(value, bytes ?? true)) fail("invalid or oversized hex bytes");
  return value.toLowerCase() as Hex;
}
function address(value: unknown, nonzero = false): Address {
  if (typeof value !== "string") fail("address must be a string");
  const result = getAddress(value) as Address;
  if (nonzero && result === ZeroAddress) fail("address must be nonzero");
  return result;
}
function utf8Size(value: unknown): number {
  if (typeof value !== "string" || value.length > GOVERNANCE_EXECUTOR_V2_LIMITS.reasonUriBytes) fail("reasonURI exceeds client UTF-8 bound");
  let size = 0;
  for (let i = 0; i < value.length; i++) {
    const c = value.charCodeAt(i);
    if (c >= 0xd800 && c <= 0xdbff) {
      const d = value.charCodeAt(++i);
      if (!(d >= 0xdc00 && d <= 0xdfff)) fail("reasonURI must be Unicode scalar text");
      size += 4;
    } else if (c >= 0xdc00 && c <= 0xdfff) fail("reasonURI must be Unicode scalar text");
    else size += c < 0x80 ? 1 : c < 0x800 ? 2 : 3;
  }
  if (size > GOVERNANCE_EXECUTOR_V2_LIMITS.reasonUriBytes) fail("reasonURI exceeds client UTF-8 bound");
  return size;
}
function list(value: unknown, maximum = GOVERNANCE_EXECUTOR_V2_LIMITS.calls): readonly unknown[] {
  if (!Array.isArray(value) || value.length > maximum || Reflect.ownKeys(value).length !== value.length + 1) fail("invalid bounded dense array");
  for (let i = 0; i < value.length; i++) if (!Object.hasOwn(value, i)) fail("sparse array");
  return value;
}
/** Check aggregate encoded allocation before cloning any nested values. */
function measure(p: ParamType, value: unknown): number {
  if (p.baseType === "array") {
    const a = list(value);
    if (p.arrayLength !== -1 && a.length !== p.arrayLength) fail("array length mismatch");
    let bytes = 32 + a.length * 32;
    for (const v of a) {
      bytes += measure(p.arrayChildren!, v);
      if (bytes > GOVERNANCE_EXECUTOR_V2_LIMITS.bytes) fail("aggregate allocation exceeds client bound");
    }
    return bytes;
  }
  if (p.baseType === "tuple") {
    const fields = p.components!;
    const o = exact(value, fields.map(c => c.name), "tuple");
    let bytes = fields.length * 32;
    for (const field of fields) {
      bytes += measure(field, o[field.name]);
      if (bytes > GOVERNANCE_EXECUTOR_V2_LIMITS.bytes) fail("aggregate allocation exceeds client bound");
    }
    return bytes;
  }
  if (p.type === "bytes") return 32 + Math.ceil((hex(value).length - 2) / 64) * 32;
  if (p.type === "string") return 32 + Math.ceil(utf8Size(value) / 32) * 32;
  return 32;
}
function valueOf(p: ParamType, value: unknown): unknown {
  if (p.baseType === "array") return Object.freeze(list(value).map(v => valueOf(p.arrayChildren!, v)));
  if (p.baseType === "tuple") {
    const o = value as Record<string, unknown>;
    return Object.freeze(Object.fromEntries(p.components!.map(c => [c.name, valueOf(c, o[c.name])])));
  }
  if (p.type === "address") return address(value);
  if (p.type === "string") { utf8Size(value); return value; }
  if (p.type === "bool") { if (typeof value !== "boolean") fail("expected boolean"); return value; }
  if (p.type.startsWith("uint")) {
    const n = uint(value, Number(p.type.slice(4)));
    if (p.name === "status" && n > 5n) fail("invalid original status enum");
    return n;
  }
  if (p.type.startsWith("bytes")) return hex(value, p.type === "bytes" ? undefined : Number(p.type.slice(5)));
  return fail(`unsupported codec ${p.type}`);
}
function normalize<T>(tuple: string, value: unknown): T {
  const p = ParamType.from(tuple);
  if (measure(p, value) > GOVERNANCE_EXECUTOR_V2_LIMITS.bytes) fail("aggregate allocation exceeds client bound");
  return valueOf(p, value) as T;
}
function fromResult(p: ParamType, value: unknown): unknown {
  if (p.baseType === "array") return (value as readonly unknown[]).map(v => fromResult(p.arrayChildren!, v));
  if (p.baseType === "tuple") return Object.fromEntries(p.components!.map((c, i) => [c.name, fromResult(c, (value as readonly unknown[])[i])]));
  return value;
}
/** Inspect offsets/counts and cumulative materialization before ethers allocates arrays or strings.
 * Canonical padding/offset equality is separately enforced by full re-encoding. */
function preflight(types: readonly ParamType[], data: Hex): void {
  const length = (data.length - 2) / 2;
  let nodes = 0, materialized = 0;
  const bounded = (start: number, size: number): void => {
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(size) || start < 0 || size < 0 || start > length || size > length - start) fail("ABI offset or length out of bounds");
  };
  const word = (start: number): number => {
    bounded(start, 32);
    const value = BigInt(`0x${data.slice(2 + start * 2, 66 + start * 2)}`);
    if (value > BigInt(GOVERNANCE_EXECUTOR_V2_LIMITS.bytes)) fail("ABI allocation exceeds client bound");
    return Number(value);
  };
  const dynamic = (p: ParamType): boolean => p.type === "bytes" || p.type === "string" || (p.baseType === "array" && (p.arrayLength === -1 || dynamic(p.arrayChildren!))) || (p.baseType === "tuple" && p.components!.some(dynamic));
  const width = (p: ParamType): number => dynamic(p) ? 32 : p.baseType === "array" ? p.arrayLength! * width(p.arrayChildren!) : p.baseType === "tuple" ? p.components!.reduce((sum, c) => sum + width(c), 0) : 32;
  const charge = (size: number): void => {
    materialized += size;
    if (++nodes > 8192 || materialized > GOVERNANCE_EXECUTOR_V2_LIMITS.bytes) fail("aggregate ABI allocation exceeds client bound");
  };
  const sequence = (parts: readonly ParamType[], base: number, depth: number): void => {
    let offset = base;
    bounded(base, parts.reduce((sum, p) => sum + width(p), 0));
    for (const p of parts) {
      visit(p, dynamic(p) ? base + word(offset) : offset, depth + 1);
      offset += width(p);
    }
  };
  const visit = (p: ParamType, start: number, depth: number): void => {
    if (depth > 16) fail("ABI nesting exceeds client bound");
    charge(32);
    if (p.baseType === "tuple") { sequence(p.components!, start, depth); return; }
    if (p.baseType === "array") {
      const count = p.arrayLength === -1 ? word(start) : p.arrayLength!;
      if (count > GOVERNANCE_EXECUTOR_V2_LIMITS.calls) fail("ABI array exceeds client bound");
      const base = start + (p.arrayLength === -1 ? 32 : 0), child = p.arrayChildren!;
      bounded(base, count * width(child));
      for (let i = 0; i < count; i++) visit(child, dynamic(child) ? base + word(base + i * 32) : base + i * width(child), depth + 1);
    } else if (p.type === "bytes" || p.type === "string") {
      const size = word(start);
      if (p.type === "string" && size > GOVERNANCE_EXECUTOR_V2_LIMITS.reasonUriBytes) fail("reasonURI exceeds client UTF-8 bound");
      bounded(start + 32, Math.ceil(size / 32) * 32);
      charge(size);
    } else bounded(start, 32);
  };
  sequence(types, 0, 0);
}
function decode<T>(tuple: string, input: Hex): T {
  const data = hex(input);
  preflight([ParamType.from(tuple)], data);
  const value = normalize<T>(tuple, fromResult(ParamType.from(tuple), coder.decode([tuple], data)[0]));
  if (coder.encode([tuple], [value]).toLowerCase() !== data) fail("noncanonical ABI encoding");
  return value;
}
export function governanceExecutorV2Interface(): Interface { return new Interface(GOVERNANCE_EXECUTOR_V2_ABI); }
export function normalizeGovernanceExecutorV2Coordinates(value: GovernanceExecutorV2Coordinates): GovernanceExecutorV2Coordinates {
  const o = exact(value, ["chainId", "executor"], "coordinates");
  return Object.freeze({ chainId: uint(o.chainId), executor: address(o.executor, true) });
}
export const normalizeGovernanceExecutorV2CallDescriptor = (v: GovernanceExecutorV2CallDescriptor): GovernanceExecutorV2CallDescriptor => normalize(GOVERNANCE_EXECUTOR_V2_CALL_TUPLE, v);
export const normalizeGovernanceExecutorV2Action = (v: GovernanceExecutorV2Action): GovernanceExecutorV2Action => normalize(GOVERNANCE_EXECUTOR_V2_ACTION_TUPLE, v);
export const normalizeGovernanceExecutorV2ActionFacts = (v: GovernanceExecutorV2ActionFacts): GovernanceExecutorV2ActionFacts => normalize(GOVERNANCE_EXECUTOR_V2_ACTION_FACTS_TUPLE, v);
export const normalizeGovernanceExecutorV2ActionIdentity = (v: GovernanceExecutorV2ActionIdentity): GovernanceExecutorV2ActionIdentity => normalize(GOVERNANCE_EXECUTOR_V2_ACTION_IDENTITY_TUPLE, v);
export const normalizeGovernanceExecutorV2ScheduleAction = (v: GovernanceExecutorV2ScheduleAction): GovernanceExecutorV2ScheduleAction => normalize(GOVERNANCE_EXECUTOR_V2_SCHEDULE_ACTION_TUPLE, v);
export const encodeGovernanceExecutorV2CallDescriptor = (v: GovernanceExecutorV2CallDescriptor): Hex => coder.encode([GOVERNANCE_EXECUTOR_V2_CALL_TUPLE], [normalizeGovernanceExecutorV2CallDescriptor(v)]) as Hex;
export const encodeGovernanceExecutorV2Action = (v: GovernanceExecutorV2Action): Hex => coder.encode([GOVERNANCE_EXECUTOR_V2_ACTION_TUPLE], [normalizeGovernanceExecutorV2Action(v)]) as Hex;
export const encodeGovernanceExecutorV2ActionFacts = (v: GovernanceExecutorV2ActionFacts): Hex => coder.encode([GOVERNANCE_EXECUTOR_V2_ACTION_FACTS_TUPLE], [normalizeGovernanceExecutorV2ActionFacts(v)]) as Hex;
export const encodeGovernanceExecutorV2ActionIdentity = (v: GovernanceExecutorV2ActionIdentity): Hex => coder.encode([GOVERNANCE_EXECUTOR_V2_ACTION_IDENTITY_TUPLE], [normalizeGovernanceExecutorV2ActionIdentity(v)]) as Hex;
export const encodeGovernanceExecutorV2ScheduleAction = (v: GovernanceExecutorV2ScheduleAction): Hex => coder.encode([GOVERNANCE_EXECUTOR_V2_SCHEDULE_ACTION_TUPLE], [normalizeGovernanceExecutorV2ScheduleAction(v)]) as Hex;
export const decodeGovernanceExecutorV2CallDescriptor = (v: Hex): GovernanceExecutorV2CallDescriptor => decode(GOVERNANCE_EXECUTOR_V2_CALL_TUPLE, v);
export const decodeGovernanceExecutorV2Action = (v: Hex): GovernanceExecutorV2Action => decode(GOVERNANCE_EXECUTOR_V2_ACTION_TUPLE, v);
export const decodeGovernanceExecutorV2ActionFacts = (v: Hex): GovernanceExecutorV2ActionFacts => decode(GOVERNANCE_EXECUTOR_V2_ACTION_FACTS_TUPLE, v);
export const decodeGovernanceExecutorV2ActionIdentity = (v: Hex): GovernanceExecutorV2ActionIdentity => decode(GOVERNANCE_EXECUTOR_V2_ACTION_IDENTITY_TUPLE, v);
export const decodeGovernanceExecutorV2ScheduleAction = (v: Hex): GovernanceExecutorV2ScheduleAction => decode(GOVERNANCE_EXECUTOR_V2_SCHEDULE_ACTION_TUPLE, v);

function callsOf(input: readonly GovernanceExecutorV2CallDescriptor[]): readonly GovernanceExecutorV2CallDescriptor[] {
  return normalize(`${GOVERNANCE_EXECUTOR_V2_CALL_TUPLE}[]`, input);
}
function datasOf(input: readonly Hex[]): readonly Hex[] {
  return normalize("bytes[]", input);
}
export function governanceExecutorV2CallsHash(input: readonly GovernanceExecutorV2CallDescriptor[]): Hex {
  return keccak256(coder.encode(["bytes32", `${GOVERNANCE_EXECUTOR_V2_CALL_TUPLE}[]`], [GOVERNANCE_EXECUTOR_V2_DOMAINS.calls, callsOf(input)])) as Hex;
}
export function governanceExecutorV2BatchHashes(input: readonly GovernanceExecutorV2CallDescriptor[]): GovernanceExecutorV2BatchHashes {
  const calls = callsOf(input);
  const callsHash = governanceExecutorV2CallsHash(calls);
  const h = (domain: string, field: "scopeHash" | "oldValueHash" | "newValueHash"): Hex => keccak256(coder.encode(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, calls.map(c => c[field])])) as Hex;
  return Object.freeze({ callsHash, scopeHash: h(GOVERNANCE_EXECUTOR_V2_DOMAINS.scope, "scopeHash"), oldValueHash: h(GOVERNANCE_EXECUTOR_V2_DOMAINS.oldValue, "oldValueHash"), newValueHash: h(GOVERNANCE_EXECUTOR_V2_DOMAINS.newValue, "newValueHash") });
}
/** Raw original preimage. Class admission and authenticated nonce provenance are separate. */
export function governanceExecutorV2ActionId(c: GovernanceExecutorV2Coordinates, input: GovernanceExecutorV2ActionIdentity): Hex {
  const coordinates = normalizeGovernanceExecutorV2Coordinates(c);
  return keccak256(coder.encode(["bytes32", "uint256", "address", GOVERNANCE_EXECUTOR_V2_ACTION_IDENTITY_TUPLE], [GOVERNANCE_EXECUTOR_V2_DOMAINS.action, coordinates.chainId, coordinates.executor, normalizeGovernanceExecutorV2ActionIdentity(input)])) as Hex;
}
export function governanceExecutorV2PublicationKey(input: readonly Hex[]): Hex {
  return keccak256(concat(datasOf(input).map(v => keccak256(v)))) as Hex;
}
export function governanceExecutorV2CallDataPublication(input: readonly Hex[]): Hex {
  const callDatas = datasOf(input);
  if (!callDatas.length) fail("empty governance batch");
  const bytes = coder.encode(["bytes[]"], [callDatas]) as Hex;
  if ((bytes.length - 2) / 2 > GOVERNANCE_EXECUTOR_V2_LIMITS.publicationBytes) fail("SSTORE2 publication exceeds 24575 bytes");
  return bytes;
}
export function decodeGovernanceExecutorV2CallDataPublication(bytes: Hex): readonly Hex[] {
  const data = hex(bytes, undefined, GOVERNANCE_EXECUTOR_V2_LIMITS.publicationBytes);
  const decoded = decode<readonly Hex[]>("bytes[]", data);
  if (governanceExecutorV2CallDataPublication(decoded) !== data) fail("noncanonical publication");
  return decoded;
}
export function governanceExecutorV2DistinctScopes(input: readonly GovernanceExecutorV2CallDescriptor[]): readonly Hex[] {
  return Object.freeze([...new Set(callsOf(input).map(c => c.scopeHash))]);
}
export function governanceExecutorV2MinimumDelay(actionClass: bigint): bigint {
  const n = uint(actionClass, 8);
  if (n > 5n) fail("unknown or retired action class");
  return [0n, 2n * day, 3n * day, 2n * day, 14n * day, 30n * day][Number(n)]!;
}
export function governanceExecutorV2ValidateWindow(actionClass: bigint, notBefore: bigint, expiresAfter: bigint, timestamp: bigint): void {
  const delay = governanceExecutorV2MinimumDelay(actionClass);
  uint(notBefore, 64); uint(expiresAfter, 64); uint(timestamp);
  if (timestamp > maxUint(64) - 365n * day) fail("timestamp exceeds original uint64 headroom");
  if (notBefore < timestamp + delay) fail("delay below class minimum");
  if (expiresAfter <= notBefore || expiresAfter > timestamp + 365n * day) fail("invalid action window");
  if (delay > 0n && expiresAfter - notBefore < 7n * day) fail("open window below seven-day floor");
}
/** Only available structural call predicates. Runtime/code, approval, catalog and direction
 * classifiers remain the original Executor's responsibility, including EOA native receivers. */
export function validateGovernanceExecutorV2Calls(input: readonly GovernanceExecutorV2CallDescriptor[], inputDatas: readonly Hex[], actionClass?: bigint): Readonly<{ calls: readonly GovernanceExecutorV2CallDescriptor[]; callDatas: readonly Hex[]; totalValue: bigint }> {
  const calls = callsOf(input), callDatas = datasOf(inputDatas);
  if (!calls.length || calls.length !== callDatas.length) fail("empty or mismatched governance batch");
  if (actionClass !== undefined) governanceExecutorV2MinimumDelay(actionClass);
  governanceExecutorV2CallDataPublication(callDatas);
  let totalValue = 0n;
  calls.forEach((call, i) => {
    address(call.target, true);
    const data = callDatas[i]!;
    if (keccak256(data) !== call.callDataHash) fail("callDataHash mismatch");
    if (data === "0x") {
      if (call.selector !== "0x00000000" || call.value === 0n || actionClass === 0n) fail("invalid empty native transfer");
    } else if (data.length < 10 || data.slice(0, 10) !== call.selector) fail("call selector mismatch or too short");
    totalValue += call.value;
    uint(totalValue);
  });
  return Object.freeze({ calls, callDatas, totalValue });
}
export function governanceExecutorV2SingleCall(input: GovernanceExecutorV2ScheduleAction): GovernanceExecutorV2CallDescriptor {
  const r = normalizeGovernanceExecutorV2ScheduleAction(input);
  return Object.freeze({ target: r.target, value: r.value, selector: r.selector, callDataHash: keccak256(r.callData) as Hex, scopeHash: r.scopeHash, oldValueHash: r.oldValueHash, newValueHash: r.newValueHash });
}

const batchKeys = ["actionClass", "calls", "scopeHash", "oldValueHash", "newValueHash", "notBefore", "expiresAfter", "reasonHash", "reasonURI", "manifestHash"] as const;
function batchOf(input: unknown): GovernanceExecutorV2ScheduleBatch {
  const o = exact(input, batchKeys, "batch");
  const calls = callsOf(o.calls as readonly GovernanceExecutorV2CallDescriptor[]);
  if (!calls.length) fail("empty governance batch");
  let total = 0n;
  for (const call of calls) { address(call.target, true); total += call.value; uint(total); }
  const h = governanceExecutorV2BatchHashes(calls);
  for (const key of ["scopeHash", "oldValueHash", "newValueHash"] as const) if (hex(o[key], 32) !== h[key]) fail(`aggregate ${key} mismatch`);
  const result = Object.freeze({ actionClass: uint(o.actionClass, 8), calls, scopeHash: h.scopeHash, oldValueHash: h.oldValueHash, newValueHash: h.newValueHash, notBefore: uint(o.notBefore, 64), expiresAfter: uint(o.expiresAfter, 64), reasonHash: hex(o.reasonHash, 32), reasonURI: o.reasonURI as string, manifestHash: hex(o.manifestHash, 32) });
  utf8Size(result.reasonURI);
  governanceExecutorV2MinimumDelay(result.actionClass);
  return result;
}
export function normalizeGovernanceExecutorV2Request(input: GovernanceExecutorV2Request): GovernanceExecutorV2Request {
  if (!input || typeof input !== "object") fail("request must be an object");
  switch (input.method) {
    case "publishGovernanceCallData": {
      const r = exact(input, ["method", "callDatas"], "request");
      const callDatas = datasOf(r.callDatas as readonly Hex[]);
      governanceExecutorV2CallDataPublication(callDatas);
      return Object.freeze({ method: input.method, callDatas });
    }
    case "scheduleGovernanceAction": {
      exact(input, ["method", "request"], "request");
      const request = normalizeGovernanceExecutorV2ScheduleAction(input.request);
      validateGovernanceExecutorV2Calls([governanceExecutorV2SingleCall(request)], [request.callData], request.actionClass);
      return Object.freeze({ method: input.method, request });
    }
    case "scheduleGovernanceBatch": {
      exact(input, ["method", ...batchKeys], "request");
      return Object.freeze({ method: input.method, ...batchOf(Object.fromEntries(batchKeys.map(k => [k, input[k]]))) });
    }
    case "executeGovernanceAction": {
      exact(input, ["method", "actionId", "call", "callData"], "request");
      const checked = validateGovernanceExecutorV2Calls([input.call], [input.callData]);
      return Object.freeze({ method: input.method, actionId: hex(input.actionId, 32), call: checked.calls[0]!, callData: checked.callDatas[0]! });
    }
    case "executeGovernanceBatch": {
      exact(input, ["method", "actionId", "calls", "callDatas"], "request");
      const checked = validateGovernanceExecutorV2Calls(input.calls, input.callDatas);
      return Object.freeze({ method: input.method, actionId: hex(input.actionId, 32), calls: checked.calls, callDatas: checked.callDatas });
    }
    case "cancelGovernanceAction":
    case "vetoTerminalFreeze":
      exact(input, ["method", "actionId", "reasonHash"], "request");
      return Object.freeze({ method: input.method, actionId: hex(input.actionId, 32), reasonHash: hex(input.reasonHash, 32) });
    case "materializeExpiredAction":
      exact(input, ["method", "actionId"], "request");
      return Object.freeze({ method: input.method, actionId: hex(input.actionId, 32) });
    case "pruneElapsedTerminalFreezeActions":
      exact(input, ["method", "scopeHash"], "request");
      return Object.freeze({ method: input.method, scopeHash: hex(input.scopeHash, 32) });
    default: return fail("unsupported lifecycle method");
  }
}
/** Computes the original identity from supplied scheduling inputs and the original nonce.
 * The nonce must come from an authenticated schedule event for historical use. */
export function governanceExecutorV2ScheduleIdentity(input: Extract<GovernanceExecutorV2Request, { method: "scheduleGovernanceAction" | "scheduleGovernanceBatch" }>, nonce: bigint): GovernanceExecutorV2ActionIdentity {
  const request = normalizeGovernanceExecutorV2Request(input);
  if (request.method !== "scheduleGovernanceAction" && request.method !== "scheduleGovernanceBatch") return fail("expected scheduling request");
  const r = request.method === "scheduleGovernanceAction" ? request.request : request;
  const calls = request.method === "scheduleGovernanceAction" ? [governanceExecutorV2SingleCall(request.request)] : request.calls;
  return Object.freeze({ actionClass: r.actionClass, ...governanceExecutorV2BatchHashes(calls), nonce: uint(nonce), notBefore: r.notBefore, expiresAfter: r.expiresAfter, reasonHash: r.reasonHash, manifestHash: r.manifestHash });
}
export function prepareGovernanceExecutorV2Call(c: GovernanceExecutorV2Coordinates, from: Address, input: GovernanceExecutorV2Request): GovernanceExecutorV2PreparedCall {
  const coordinates = normalizeGovernanceExecutorV2Coordinates(c), caller = address(from, true);
  const request = normalizeGovernanceExecutorV2Request(input);
  let args: readonly unknown[], value = 0n;
  switch (request.method) {
    case "publishGovernanceCallData": args = [request.callDatas]; break;
    case "scheduleGovernanceAction": args = [request.request]; break;
    case "scheduleGovernanceBatch": args = batchKeys.map(k => request[k]); break;
    case "executeGovernanceAction": args = [request.actionId, request.callData]; value = request.call.value; break;
    case "executeGovernanceBatch": args = [request.actionId, request.calls, request.callDatas]; value = request.calls.reduce((sum, call) => sum + call.value, 0n); break;
    case "cancelGovernanceAction":
    case "vetoTerminalFreeze": args = [request.actionId, request.reasonHash]; break;
    case "materializeExpiredAction": args = [request.actionId]; break;
    case "pruneElapsedTerminalFreezeActions": args = [request.scopeHash]; break;
  }
  const data = hex(iface.encodeFunctionData(request.method, args));
  return Object.freeze({ coordinates, caller, request, call: Object.freeze({ to: coordinates.executor, value, data, operation: 0 as const }), authorityIndependentlyVerified: false, targetEffectsIndependentlyVerified: false });
}
export function verifyGovernanceExecutorV2Call(input: GovernanceExecutorV2PreparedCall): GovernanceExecutorV2PreparedCall {
  exact(input, ["coordinates", "caller", "request", "call", "authorityIndependentlyVerified", "targetEffectsIndependentlyVerified"], "prepared call");
  const rebuilt = prepareGovernanceExecutorV2Call(input.coordinates, input.caller, input.request);
  exact(input.call, ["to", "value", "data", "operation"], "call");
  if (address(input.call.to) !== rebuilt.call.to || input.call.value !== rebuilt.call.value || hex(input.call.data) !== rebuilt.call.data || input.call.operation !== 0 || input.authorityIndependentlyVerified !== false || input.targetEffectsIndependentlyVerified !== false) fail("prepared call was substituted");
  return rebuilt;
}
export interface GovernanceExecutorV2DecodedCall {
  readonly method: GovernanceExecutorV2Request["method"];
  readonly args: readonly unknown[];
  /** executeAction calldata alone cannot recover its value or private per-call transitions. */
  readonly valueIndependentlyRecovered: false;
}
export function decodeGovernanceExecutorV2Call(input: Hex): GovernanceExecutorV2DecodedCall {
  const data = hex(input);
  if (data.length < 10) fail("missing lifecycle selector");
  const fragment = iface.getFunction(data.slice(0, 10));
  const names: readonly string[] = ["publishGovernanceCallData", "scheduleGovernanceAction", "scheduleGovernanceBatch", "executeGovernanceAction", "executeGovernanceBatch", "cancelGovernanceAction", "vetoTerminalFreeze", "materializeExpiredAction", "pruneElapsedTerminalFreezeActions"];
  if (!fragment || !names.includes(fragment.name)) fail("unsupported lifecycle selector");
  preflight(fragment.inputs, `0x${data.slice(10)}` as Hex);
  const values = iface.decodeFunctionData(fragment, data);
  if (iface.encodeFunctionData(fragment, values).toLowerCase() !== data) fail("noncanonical lifecycle calldata");
  const args = Object.freeze(fragment.inputs.map((p, i) => {
    const v = fromResult(p, values[i]);
    if (measure(p, v) > GOVERNANCE_EXECUTOR_V2_LIMITS.bytes) fail("aggregate allocation exceeds client bound");
    return valueOf(p, v);
  }));
  return Object.freeze({ method: fragment.name as GovernanceExecutorV2Request["method"], args, valueIndependentlyRecovered: false });
}
/** Reconstructs immutable schedule commitments only. Does not authenticate the event/nonce,
 * current catalog, actors, target code, current state, or target-specific effects. */
export function authenticateGovernanceExecutorV2Action(c: GovernanceExecutorV2Coordinates, actionId: Hex, nonce: bigint, input: GovernanceExecutorV2Action, inputCalls: readonly GovernanceExecutorV2CallDescriptor[], callDatas: readonly Hex[]): Readonly<{ action: GovernanceExecutorV2Action; identity: GovernanceExecutorV2ActionIdentity; calls: readonly GovernanceExecutorV2CallDescriptor[]; callDatas: readonly Hex[]; provenanceIndependentlyVerified: false }> {
  const action = normalizeGovernanceExecutorV2Action(input);
  if (action.status === 0n) fail("unknown action");
  const checked = validateGovernanceExecutorV2Calls(inputCalls, callDatas, action.actionClass);
  const h = governanceExecutorV2BatchHashes(checked.calls), first = checked.calls[0]!;
  if (action.callHash !== h.callsHash || action.scopeHash !== h.scopeHash || action.oldValueHash !== h.oldValueHash || action.newValueHash !== h.newValueHash || action.target !== first.target || action.selector !== first.selector || action.value !== checked.totalValue) fail("stored action differs from supplied calls");
  const identity = Object.freeze({ actionClass: action.actionClass, ...h, nonce: uint(nonce), notBefore: action.notBefore, expiresAfter: action.expiresAfter, reasonHash: action.reasonHash, manifestHash: action.manifestHash });
  if (governanceExecutorV2ActionId(c, identity) !== hex(actionId, 32)) fail("actionId mismatch");
  return Object.freeze({ action, identity, calls: checked.calls, callDatas: checked.callDatas, provenanceIndependentlyVerified: false });
}
/** Time and raw-status eligibility only. A true flag is not caller authorization or simulation. */
export function governanceExecutorV2Lifecycle(input: GovernanceExecutorV2ActionFacts, timestamp: bigint): Readonly<{ storedStatus: bigint; virtualStatus: bigint; executionWindow: boolean; cancellationWindow: boolean; vetoWindow: boolean; canMaterializeExpiry: boolean; elapsedVetoMembership: boolean }> {
  const facts = normalizeGovernanceExecutorV2ActionFacts(input);
  uint(timestamp);
  governanceExecutorV2MinimumDelay(facts.actionClass);
  const scheduled = facts.status === 1n;
  return Object.freeze({ storedStatus: facts.status, virtualStatus: scheduled && timestamp > facts.expiresAfter ? 4n : facts.status, executionWindow: scheduled && timestamp >= facts.notBefore && timestamp <= facts.expiresAfter, cancellationWindow: scheduled && timestamp <= facts.expiresAfter, vetoWindow: scheduled && facts.actionClass === 2n && timestamp < facts.notBefore, canMaterializeExpiry: scheduled && timestamp > facts.expiresAfter, elapsedVetoMembership: facts.actionClass === 2n && timestamp >= facts.notBefore });
}

export interface GovernanceExecutorV2ReadArgs {
  readonly owner: readonly [];
  readonly roleRegistry: readonly [];
  readonly supportsInterface: readonly [Hex];
  readonly systemManifestBootstrapState: readonly [];
  readonly governanceActionPolicyState: readonly [];
  readonly governanceRootState: readonly [];
  readonly currentAction: readonly [];
  readonly governanceNonce: readonly [];
  readonly governanceAction: readonly [Hex];
  readonly governanceActionFacts: readonly [Hex];
  readonly publishedCallData: readonly [Hex];
  readonly scheduledCallData: readonly [Hex];
  readonly scheduledCallDataPointer: readonly [Hex];
  readonly minimumDelay: readonly [bigint];
  readonly isProposer: readonly [Address];
  readonly proposerConfig: readonly [Address];
  readonly isCanceller: readonly [Address];
  readonly cancellerConfig: readonly [Address];
  readonly terminalFreezeGuardianConfigCommitment: readonly [Hex];
  readonly terminalFreezeActionPage: readonly [Hex, bigint, bigint];
  readonly terminalFreezeLiveActionCaps: readonly [];
  readonly terminalFreezeLiveActionUsage: readonly [Hex, Address];
  readonly terminalFreezeVetoGuardian: readonly [Hex];
  readonly terminalFreezeVetoGuardianSet: readonly [Hex];
  readonly terminalFreezeVetoRole: readonly [Hex];
  readonly liveTerminalFreezeActionCount: readonly [Hex];
  readonly liveTerminalFreezeActionAt: readonly [Hex, bigint];
  readonly systemManifestBatchTailRule: readonly [Address, Hex];
  readonly tighteningCallConfig: readonly [Address, Hex];
  readonly freezeSelectorConfig: readonly [Address, Hex];
  readonly approvedNativeReceiverConfig: readonly [Address];
  readonly isTighteningCall: readonly [Address, Hex];
  readonly isFreezeSelector: readonly [Address, Hex];
  readonly isApprovedNativeReceiver: readonly [Address];
  readonly pendingScheduledActionCount: readonly [];
}
export type GovernanceExecutorV2Read = { [K in keyof GovernanceExecutorV2ReadArgs]: { readonly method: K; readonly args: GovernanceExecutorV2ReadArgs[K] } }[keyof GovernanceExecutorV2ReadArgs];
export function prepareGovernanceExecutorV2Read(c: GovernanceExecutorV2Coordinates, input: GovernanceExecutorV2Read): Readonly<{ coordinates: GovernanceExecutorV2Coordinates; request: GovernanceExecutorV2Read; call: UnsignedCall }> {
  const coordinates = normalizeGovernanceExecutorV2Coordinates(c);
  exact(input, ["method", "args"], "read");
  if (typeof input.method !== "string") fail("invalid read method");
  const fn = iface.getFunction(input.method);
  if (!fn || (fn.stateMutability !== "view" && fn.stateMutability !== "pure")) fail("unsupported lifecycle read");
  const supplied = list(input.args);
  if (supplied.length !== fn.inputs.length) fail("read argument count mismatch");
  const args = Object.freeze(fn.inputs.map((p, i) => { measure(p, supplied[i]); return valueOf(p, supplied[i]); }));
  if (input.method === "terminalFreezeActionPage" && (args[2] as bigint) > 64n) fail("terminal page exceeds original 64 bound");
  if (input.method === "minimumDelay") governanceExecutorV2MinimumDelay(args[0] as bigint);
  const request = Object.freeze({ method: input.method, args }) as GovernanceExecutorV2Read;
  return Object.freeze({ coordinates, request, call: Object.freeze({ to: coordinates.executor, value: 0n, data: hex(iface.encodeFunctionData(fn, args)) }) });
}
/** Returns immutable positional outputs, with named tuple members preserved. Ordinary getters
 * are observations: governanceAction may virtualize expiry while ActionFacts is raw storage. */
export function decodeGovernanceExecutorV2Read(method: keyof GovernanceExecutorV2ReadArgs, input: Hex): readonly unknown[] {
  const fn = iface.getFunction(method);
  if (!fn || (fn.stateMutability !== "view" && fn.stateMutability !== "pure")) fail("unsupported lifecycle read");
  const bytes = hex(input);
  preflight(fn.outputs, bytes);
  const decoded = iface.decodeFunctionResult(fn, bytes);
  if (iface.encodeFunctionResult(fn, decoded).toLowerCase() !== bytes) fail("noncanonical read result");
  return Object.freeze(fn.outputs.map((p, i) => {
    const value = fromResult(p, decoded[i]);
    if (measure(p, value) > GOVERNANCE_EXECUTOR_V2_LIMITS.bytes) fail("aggregate allocation exceeds client bound");
    return valueOf(p, value);
  }));
}
