import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_HASH } from "./current-scoped-policy-publication-v2.js";

/** Frozen ABI129; excludes later current-authority and VIEW finality profiles. */
export const SCOPED_POLICY_FINALITY_V2_SOURCE = "896899f7ca4130f86e066587f780a3b1f755a25d";
/** Original profile document digest returned in Sources, distinct from its capability ID. */
export const SCOPED_POLICY_FINALITY_V2_PROFILE = SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE_HASH;
export const SCOPED_POLICY_FINALITY_V2_MANIFEST_MAX_BYTES = 8192;
export const SCOPED_POLICY_FINALITY_V2_REGISTRY_MAX_BYTES = 32768;
/** Client allocation bound for codecs and outer governance calldata. */
export const SCOPED_POLICY_FINALITY_V2_MAX_BYTES = 262144;
export const SCOPED_POLICY_FINALITY_V2_MAX_COMPONENTS = 32;

export interface ScopedPolicyFinalityV2Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly metadata: Address;
  readonly registry: Address;
  readonly executor: Address;
  readonly artist: Address;
  readonly artifactCoverage: Address;
}

export interface ScopedPolicyFinalityV2Scope {
  readonly scopeType: 0n | 1n | 2n | 3n | 4n;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly scopeId: Hex;
}

export interface ScopedPolicyFinalityV2Component {
  readonly componentType: Hex;
  readonly component: Address;
  readonly interfaceId: Hex;
  readonly codeHash: Hex;
  readonly moduleVersion: Hex;
  readonly manifestHash: Hex;
  readonly dataHash: Hex;
}

export interface ScopedPolicyFinalityV2ComponentState {
  readonly frozen: boolean;
  readonly componentType: Hex;
  readonly component: Address;
  readonly interfaceId: Hex;
  readonly codeHash: Hex;
  readonly moduleVersion: Hex;
  readonly manifestHash: Hex;
  readonly dataHash: Hex;
}

export interface ScopedPolicyFinalityV2Inputs {
  readonly rootRecordHash: Hex;
  readonly snapshotRecordHash: Hex;
  readonly referenceRenderRecordHash: Hex;
  readonly intentRecordHash: Hex;
  readonly intentWaiverRecordHash: Hex;
  readonly interviewEvidenceHash: Hex;
  readonly rightsStatementRecordHash: Hex;
  readonly workDescriptionRecordHash: Hex;
  readonly renderCriticalEvidenceHash: Hex;
  readonly bundleCoverageHash: Hex;
}

export interface ScopedPolicyFinalityV2Statement {
  readonly scope: ScopedPolicyFinalityV2Scope;
  readonly coreFactsHash: Hex;
  readonly contentRoot: Hex;
  readonly leafCount: bigint;
  readonly contentRootSchemaId: Hex;
  readonly snapshotManifestHash: Hex;
  readonly referenceRenderManifestHash: Hex;
  readonly inputs: ScopedPolicyFinalityV2Inputs;
  readonly nonSanctionComponents: readonly ScopedPolicyFinalityV2Component[];
  readonly entropyPolicy: bigint;
  readonly postFreezePolicy: bigint;
  readonly sanctionPolicy: bigint;
}

export interface ScopedPolicyFinalityV2ManifestRef {
  readonly uri: string;
  readonly uriHash: Hex;
  readonly contentHash: Hex;
  readonly schemaId: Hex;
  readonly canonicalizationHash: Hex;
}

export interface ScopedPolicyFinalityV2Profile {
  readonly profileHash: Hex;
  readonly referenceRender: Address;
  readonly referenceRenderCodeHash: Hex;
  readonly snapshots: Address;
  readonly snapshotsCodeHash: Hex;
  readonly entropyFactory: Address;
  readonly entropyFactoryCodeHash: Hex;
  readonly configurationHash: Hex;
}

export interface ScopedPolicyFinalityV2Sources {
  readonly scope: ScopedPolicyFinalityV2Scope;
  readonly profile: ScopedPolicyFinalityV2Profile;
}

export interface ScopedPolicyFinalityV2NativeConfiguration {
  readonly targets: readonly [Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address];
  readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex];
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly componentSourceGas: bigint;
  readonly inventoryDependencyHash: Hex;
}

export interface ScopedPolicyFinalityV2DiscoveryConfiguration {
  readonly core: Address;
  readonly metadata: Address;
  readonly router: Address;
  readonly provider: Address;
  readonly membership: Address;
  readonly entropyFactory: Address;
  readonly metadataAdapter: Address;
  readonly referenceRender: Address;
  readonly artist: Address;
  readonly finalityRegistry: Address;
  readonly finalityRegistryCodeHash: Hex;
  readonly routerAdapters: readonly [Address, Address, Address, Address, Address, Address];
  readonly readGas: bigint;
  readonly componentGas: bigint;
  readonly entropyGas: bigint;
}

export interface ScopedPolicyFinalityV2FactoryBinding {
  readonly factory: Address;
  readonly factoryCodeHash: Hex;
  readonly recipeHash: Hex;
  readonly sourceFactoryDependenciesHash: Hex;
  readonly graphGas: bigint;
  readonly configurationHash: Hex;
}

export interface ScopedPolicyFinalityV2SourceConfiguration {
  readonly core: Address;
  readonly router: Address;
  readonly routerCodeHash: Hex;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly policyOutput: Address;
  readonly policyOutputCodeHash: Hex;
  readonly profiles: readonly [ScopedPolicyFinalityV2Profile, ScopedPolicyFinalityV2Profile, ScopedPolicyFinalityV2Profile];
}

export interface ScopedPolicyFinalityV2ExecutionContext {
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
  readonly finalityRecordHash: Hex;
  readonly coreFactsHash: Hex;
  readonly componentsHash: Hex;
  readonly inputsHash: Hex;
}

export interface ScopedPolicyFinalityV2ExecutionWitness {
  readonly actionId: Hex;
  readonly proposer: Address;
  readonly reasonHash: Hex;
  readonly roleMutationHash: Hex;
  readonly roleRevision: bigint;
}

export interface ScopedPolicyFinalityV2ArchiveProof {
  readonly sanctionRecordHash: Hex;
  readonly artifactHash: Hex;
  readonly completionHash: Hex;
}

export interface ScopedPolicyFinalityV2ArchiveWitness {
  readonly evidenceHash: Hex;
  readonly proof: ScopedPolicyFinalityV2ArchiveProof;
}

export interface ScopedPolicyFinalityV2ScopedRecord {
  readonly finalized: boolean;
  readonly scope: ScopedPolicyFinalityV2Scope;
  readonly finalityRecordHash: Hex;
  readonly manifestContentHash: Hex;
  readonly manifestURIHash: Hex;
  readonly componentsHash: Hex;
  readonly finalityManifestURI: string;
  readonly manifestPointer: Address;
  readonly finalizedAt: bigint;
}

export interface ScopedPolicyFinalityV2SanctionPreparation {
  readonly sanctionSubjectHash: Hex;
  readonly coreFactsHash: Hex;
  readonly nonSanctionComponentsHash: Hex;
  readonly scopeInputsHash: Hex;
}

export interface ScopedPolicyFinalityV2Review {
  readonly schemaVersion: bigint;
  readonly profile: bigint;
  readonly contentRoot: Hex;
  readonly mediaContentHashes: readonly Hex[];
  readonly referenceRenderContentHashes: readonly Hex[];
}

export interface ScopedPolicyFinalityV2ScopedCoreFacts {
  readonly scopeExists: boolean;
  readonly scopeType: bigint;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly scopeId: Hex;
  readonly tokenMappingExists: boolean;
  readonly collectionSerial: bigint;
  readonly tokenLifecycle: bigint;
  readonly burned: boolean;
  readonly collectionStatus: bigint;
  readonly collectionSupplyMode: bigint;
  readonly collectionConfigHash: Hex;
  readonly scopeManifestHash: Hex;
}

export interface ScopedPolicyFinalityV2GovernanceCall {
  readonly target: Address;
  readonly value: bigint;
  readonly selector: Hex;
  readonly callDataHash: Hex;
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
}

export interface ScopedPolicyFinalityV2GovernanceAction {
  readonly status: bigint;
  readonly actionClass: bigint;
  readonly target: Address;
  readonly value: bigint;
  readonly selector: Hex;
  readonly callHash: Hex;
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
  readonly notBefore: bigint;
  readonly expiresAfter: bigint;
  readonly proposer: Address;
  readonly executor: Address;
  readonly canceller: Address;
  readonly vetoer: Address;
  readonly reasonHash: Hex;
  readonly reasonURI: string;
  readonly manifestHash: Hex;
}

export const SCOPED_POLICY_FINALITY_V2_SCOPE_TUPLE = "(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId)";
export const SCOPED_POLICY_FINALITY_V2_COMPONENT_TUPLE = "(bytes32 componentType,address component,bytes4 interfaceId,bytes32 codeHash,bytes32 moduleVersion,bytes32 manifestHash,bytes32 dataHash)";
export const SCOPED_POLICY_FINALITY_V2_COMPONENT_STATE_TUPLE = "(bool frozen,bytes32 componentType,address component,bytes4 interfaceId,bytes32 codeHash,bytes32 moduleVersion,bytes32 manifestHash,bytes32 dataHash)";
export const SCOPED_POLICY_FINALITY_V2_INPUTS_TUPLE = "(bytes32 rootRecordHash,bytes32 snapshotRecordHash,bytes32 referenceRenderRecordHash,bytes32 intentRecordHash,bytes32 intentWaiverRecordHash,bytes32 interviewEvidenceHash,bytes32 rightsStatementRecordHash,bytes32 workDescriptionRecordHash,bytes32 renderCriticalEvidenceHash,bytes32 bundleCoverageHash)";
export const SCOPED_POLICY_FINALITY_V2_STATEMENT_TUPLE = "((uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId) scope,bytes32 coreFactsHash,bytes32 contentRoot,uint64 leafCount,bytes32 contentRootSchemaId,bytes32 snapshotManifestHash,bytes32 referenceRenderManifestHash,(bytes32 rootRecordHash,bytes32 snapshotRecordHash,bytes32 referenceRenderRecordHash,bytes32 intentRecordHash,bytes32 intentWaiverRecordHash,bytes32 interviewEvidenceHash,bytes32 rightsStatementRecordHash,bytes32 workDescriptionRecordHash,bytes32 renderCriticalEvidenceHash,bytes32 bundleCoverageHash) inputs,(bytes32 componentType,address component,bytes4 interfaceId,bytes32 codeHash,bytes32 moduleVersion,bytes32 manifestHash,bytes32 dataHash)[] nonSanctionComponents,uint8 entropyPolicy,uint8 postFreezePolicy,uint8 sanctionPolicy)";
export const SCOPED_POLICY_FINALITY_V2_MANIFEST_REF_TUPLE = "(string uri,bytes32 uriHash,bytes32 contentHash,bytes32 schemaId,bytes32 canonicalizationHash)";
export const SCOPED_POLICY_FINALITY_V2_PROFILE_TUPLE = "(bytes32 profileHash,address referenceRender,bytes32 referenceRenderCodeHash,address snapshots,bytes32 snapshotsCodeHash,address entropyFactory,bytes32 entropyFactoryCodeHash,bytes32 configurationHash)";
export const SCOPED_POLICY_FINALITY_V2_SOURCES_TUPLE = "((uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId) scope,(bytes32 profileHash,address referenceRender,bytes32 referenceRenderCodeHash,address snapshots,bytes32 snapshotsCodeHash,address entropyFactory,bytes32 entropyFactoryCodeHash,bytes32 configurationHash) profile)";
export const SCOPED_POLICY_FINALITY_V2_NATIVE_CONFIGURATION_TUPLE = "(address[22] targets,bytes32[22] codeHashes,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 componentSourceGas,bytes32 inventoryDependencyHash)";
export const SCOPED_POLICY_FINALITY_V2_DISCOVERY_CONFIGURATION_TUPLE = "(address core,address metadata,address router,address provider,address membership,address entropyFactory,address metadataAdapter,address referenceRender,address artist,address finalityRegistry,bytes32 finalityRegistryCodeHash,address[6] routerAdapters,uint32 readGas,uint32 componentGas,uint32 entropyGas)";
export const SCOPED_POLICY_FINALITY_V2_FACTORY_BINDING_TUPLE = "(address factory,bytes32 factoryCodeHash,bytes32 recipeHash,bytes32 sourceFactoryDependenciesHash,uint256 graphGas,bytes32 configurationHash)";
export const SCOPED_POLICY_FINALITY_V2_SOURCE_CONFIGURATION_TUPLE = "(address core,address router,bytes32 routerCodeHash,uint256 chainId,uint256 readGas,address policyOutput,bytes32 policyOutputCodeHash,(bytes32 profileHash,address referenceRender,bytes32 referenceRenderCodeHash,address snapshots,bytes32 snapshotsCodeHash,address entropyFactory,bytes32 entropyFactoryCodeHash,bytes32 configurationHash)[3] profiles)";
export const SCOPED_POLICY_FINALITY_V2_EXECUTION_CONTEXT_TUPLE = "(bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,bytes32 finalityRecordHash,bytes32 coreFactsHash,bytes32 componentsHash,bytes32 inputsHash)";
export const SCOPED_POLICY_FINALITY_V2_EXECUTION_WITNESS_TUPLE = "(bytes32 actionId,address proposer,bytes32 reasonHash,bytes32 roleMutationHash,uint64 roleRevision)";
export const SCOPED_POLICY_FINALITY_V2_ARCHIVE_PROOF_TUPLE = "(bytes32 sanctionRecordHash,bytes32 artifactHash,bytes32 completionHash)";
export const SCOPED_POLICY_FINALITY_V2_ARCHIVE_WITNESS_TUPLE = "(bytes32 evidenceHash,(bytes32 sanctionRecordHash,bytes32 artifactHash,bytes32 completionHash) proof)";
export const SCOPED_POLICY_FINALITY_V2_SCOPED_RECORD_TUPLE = "(bool finalized,(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId) scope,bytes32 finalityRecordHash,bytes32 manifestContentHash,bytes32 manifestURIHash,bytes32 componentsHash,string finalityManifestURI,address manifestPointer,uint64 finalizedAt)";
export const SCOPED_POLICY_FINALITY_V2_SANCTION_PREPARATION_TUPLE = "(bytes32 sanctionSubjectHash,bytes32 coreFactsHash,bytes32 nonSanctionComponentsHash,bytes32 scopeInputsHash)";
export const SCOPED_POLICY_FINALITY_V2_REVIEW_TUPLE = "(uint16 schemaVersion,uint8 profile,bytes32 contentRoot,bytes32[] mediaContentHashes,bytes32[] referenceRenderContentHashes)";
export const SCOPED_POLICY_FINALITY_V2_SCOPED_CORE_FACTS_TUPLE = "(bool scopeExists,uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId,bool tokenMappingExists,uint256 collectionSerial,uint8 tokenLifecycle,bool burned,uint8 collectionStatus,uint8 collectionSupplyMode,bytes32 collectionConfigHash,bytes32 scopeManifestHash)";
export const SCOPED_POLICY_FINALITY_V2_GOVERNANCE_CALL_TUPLE = "(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
export const SCOPED_POLICY_FINALITY_V2_GOVERNANCE_ACTION_TUPLE = "(uint8 status,uint8 actionClass,address target,uint256 value,bytes4 selector,bytes32 callHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint64 notBefore,uint64 expiresAfter,address proposer,address executor,address canceller,address vetoer,bytes32 reasonHash,string reasonURI,bytes32 manifestHash)";

export const SCOPED_POLICY_FINALITY_V2_REGISTRY_ABI: readonly string[] = Object.freeze([
  "error FinalityAdapterBindingMismatch(address expectedCore, address actualCore, address expectedMetadata, address actualMetadata)",
  "error FinalityAdapterInterfaceUnsupported(address adapter)",
  "error FinalityAdapterReturnShapeInvalid(bytes4 selector, uint256 byteLength)",
  "error FinalityAdapterSemanticProbeInvalid(bytes4 selector)",
  "error FinalityAlreadyFinalized(bytes32 scopeKey)",
  "error FinalityCalldataTooLarge(uint256 size, uint256 maxSize)",
  "error FinalityCallerNotFinalityAdmin(address caller)",
  "error FinalityCallerNotVetoGuardian(address caller, address guardian)",
  "error FinalityCollectionBurnsNotBlocked(uint256 collectionId)",
  "error FinalityCollectionNotClosed(uint256 collectionId, uint8 status)",
  "error FinalityCollectionNotFrozen(uint256 collectionId)",
  "error FinalityCollectionStatusInvalid(uint256 collectionId, uint8 status)",
  "error FinalityCollectionSupplyModeInvalid(uint256 collectionId, uint8 supplyMode)",
  "error FinalityCollectionUnknown(uint256 collectionId)",
  "error FinalityComponentCodeHashMismatch(uint256 index)",
  "error FinalityComponentCountInvalid(uint256 count, uint256 maxCount)",
  "error FinalityComponentMismatch(uint256 index)",
  "error FinalityComponentUnreadable(uint256 index)",
  "error FinalityComponentsUnsorted(uint256 index)",
  "error FinalityContentRootLeafCountMismatch(uint256 expectedLeafCount, uint256 actualLeafCount)",
  "error FinalityContentRootMissing(bytes32 scopeSubject)",
  "error FinalityCurrentBindingInvalid(address target)",
  "error FinalityDependencyHasNoCode(address dependency)",
  "error FinalityDiscoveryComponentMismatch(uint256 index)",
  "error FinalityDiscoveryComponentUnreadable(uint256 index)",
  "error FinalityDiscoveryCountMismatch(uint256 discoveredCount, uint256 submittedCount)",
  "error FinalityDiscoveryFactsUnreadable()",
  "error FinalityDiscoveryHashMismatch(bytes32 discoveredHash, bytes32 submittedHash)",
  "error FinalityExecutorOnly(address actor)",
  "error FinalityExpectedRecordHashMismatch(bytes32 expected, bytes32 computed)",
  "error FinalityExpectedRecordHashZero()",
  "error FinalityFreezeAlreadyScheduled(bytes32 scopeKey)",
  "error FinalityFreezeDelayTooShort(uint64 notBefore, uint64 earliestAllowed)",
  "error FinalityFreezeGuardianUnset(bytes32 scopeKey)",
  "error FinalityFreezeNotExpired(bytes32 scopeKey)",
  "error FinalityFreezeNotOpen(uint64 notBefore, uint64 expiresAfter)",
  "error FinalityFreezeNotScheduled(bytes32 scopeKey)",
  "error FinalityFreezeVetoWindowClosed(uint64 notBefore)",
  "error FinalityFreezeWindowTooShort(uint64 expiresAfter, uint64 earliestAllowed)",
  "error FinalityLocalLifecycleRetired()",
  "error FinalityManifestBytesInvalid()",
  "error FinalityManifestBytesMissing(bytes32 contentHash)",
  "error FinalityManifestFieldZero()",
  "error FinalityManifestURIHashMismatch(bytes32 expected, bytes32 actual)",
  "error FinalityMetadataModeInvalid(uint8 metadataMode)",
  "error FinalityMissingRequiredComponent(bytes32 componentType)",
  "error FinalityModuleConfigurationInvalid()",
  "error FinalitySanctionArchiveInvalid()",
  "error FinalitySanctionArchiveReadFailed(address target)",
  "error FinalitySanctionArchiveRequired()",
  "error FinalitySanctionComponentDuplicated()",
  "error FinalitySanctionComponentMissing()",
  "error FinalitySanctionComponentWrongType(bytes32 requiredType, bytes32 suppliedType)",
  "error FinalitySanctionInvalid(bytes32 sanctionSubjectHash)",
  "error FinalitySanctionRecordHashMismatch(bytes32 componentDataHash, bytes32 sanctionRecordHash)",
  "error FinalityScopeInputsInvalid()",
  "error FinalityScopeShapeInvalid()",
  "error FinalityScopeUnknown()",
  "error FinalityScopeUsesCollectionEntry()",
  "error FinalityScopedFactsMismatch()",
  "error FinalitySnapshotManifestMissing(uint256 collectionId, uint8 metadataMode)",
  "error FinalityStagedHashMismatch(bytes32 staged, bytes32 supplied)",
  "error FinalityTokenNotInScope()",
  "error FinalityZeroAddress()",
  "error GasParameterActionAlreadyApplied(bytes32 parameterId, bytes32 actionId)",
  "error GasParameterActionClassMismatch(uint8 expectedClass, uint8 actualClass)",
  "error GasParameterActionContextInvalid()",
  "error GasParameterActionIdZero()",
  "error GasParameterActionNotExecuting()",
  "error GasParameterAlreadyRegistered(bytes32 parameterId)",
  "error GasParameterInvalidAuthority(address authority)",
  "error GasParameterInvalidConfig(bytes32 parameterId)",
  "error GasParameterNewStateHashMismatch(bytes32 expectedHash, bytes32 actualHash)",
  "error GasParameterNotARaise(bytes32 parameterId, uint256 currentValue, uint256 newValue)",
  "error GasParameterNotAuthority(address caller)",
  "error GasParameterOldStateHashMismatch(bytes32 expectedHash, bytes32 actualHash)",
  "error GasParameterRaiseBoundExceeded(bytes32 parameterId, uint256 currentValue, uint256 newValue)",
  "error GasParameterRevisionOverflow(bytes32 parameterId)",
  "error GasParameterScopeHashMismatch(bytes32 expectedHash, bytes32 actualHash)",
  "error GasParameterUnknown(bytes32 parameterId)",
  "event ArtworkScopeFinalized(uint16 schemaVersion, uint8 indexed scopeType, uint256 indexed collectionId, bytes32 indexed finalityRecordHash, uint256 tokenId, bytes32 scopeId, bytes32 componentsHash, bytes32 manifestContentHash, string finalityManifestURI)",
  "event ArtworkTerminalFreezeCancelled(uint16 schemaVersion, bytes32 indexed scopeKey, bytes32 expectedFinalityRecordHash, bytes32 reasonHash, address indexed canceller)",
  "event ArtworkTerminalFreezeExecuted(uint16 schemaVersion, bytes32 indexed scopeKey, bytes32 indexed finalityRecordHash, address executor)",
  "event ArtworkTerminalFreezeExpired(uint16 schemaVersion, bytes32 indexed scopeKey, bytes32 expectedFinalityRecordHash)",
  "event ArtworkTerminalFreezeScheduled(uint16 schemaVersion, uint8 indexed scopeType, uint256 indexed collectionId, bytes32 indexed scopeKey, uint256 tokenId, bytes32 scopeId, bytes32 expectedFinalityRecordHash, uint64 notBefore, uint64 expiresAfter, address vetoGuardian, address scheduler)",
  "event ArtworkTerminalFreezeVetoed(uint16 schemaVersion, bytes32 indexed scopeKey, bytes32 expectedFinalityRecordHash, bytes32 reasonHash, address indexed guardian)",
  "event CollectionArtworkFinalized(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed finalityRecordHash, address indexed actor, bytes32 componentsHash, bytes32 manifestContentHash, string finalityManifestURI)",
  "event FinalityExecutionWitnessRecorded(uint16 schemaVersion, bytes32 indexed finalityRecordHash, bytes32 indexed actionId, address indexed proposer, bytes32 reasonHash, bytes32 roleMutationHash, uint64 roleRevision, bytes32 inputsHash)",
  "event FinalityManifestPointerRecorded(uint16 schemaVersion, bytes32 indexed finalityRecordHash, address manifestPointer, bytes32 manifestContentHash)",
  "event FinalityManifestStaged(uint16 schemaVersion, bytes32 indexed manifestContentHash, uint256 byteLength, address actor)",
  "event FinalitySanctionArchiveWitnessRecorded(uint16 schemaVersion, bytes32 indexed finalityRecordHash, bytes32 indexed evidenceHash, bytes32 indexed sanctionRecordHash, bytes32 artifactHash, bytes32 completionHash)",
  "event GasParameterRegistered(uint16 schemaVersion, bytes32 indexed parameterId, string name, uint256 genesisValue, uint256 floor, uint8 failureClass)",
  "event GasParameterUpdated(uint16 schemaVersion, bytes32 indexed parameterId, address indexed host, bytes32 indexed actionId, uint256 oldValue, uint256 newValue, uint256 floor)",
  "function artifactCoverage() view returns (address)",
  "function artworkFreezeMode((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint8)",
  "function artworkScopeFinalityRecord((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bool finalized, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 finalityRecordHash, bytes32 manifestContentHash, bytes32 manifestURIHash, bytes32 componentsHash, string finalityManifestURI, address manifestPointer, uint64 finalizedAt) out)",
  "function computeComponentsHash((bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash)[] components) pure returns (bytes32)",
  "function computeFinalityRecordHash((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 coreFactsHash, bytes32 componentsHash, (string uri, bytes32 uriHash, bytes32 contentHash, bytes32 schemaId, bytes32 canonicalizationHash) manifest) view returns (bytes32)",
  "function computeNonSanctionComponentsHash((bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash)[] components) pure returns (bytes32)",
  "function computeSanctionSubjectHash((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 coreFactsHash, bytes32 nonSanctionComponentsHash, (string uri, bytes32 uriHash, bytes32 contentHash, bytes32 schemaId, bytes32 canonicalizationHash) manifest) view returns (bytes32)",
  "function computeScopedCoreFactsHash((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32)",
  "function contentRootScopeSubject((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32)",
  "function core() view returns (address)",
  "function coreFinalityAdapter() view returns (address)",
  "function coreReads() view returns (address)",
  "function finalityComponentCountForScope((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint256)",
  "function finalityComponentsForScope((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint256 start, uint256 limit) view returns ((bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash)[])",
  "function finalityDiscovery() view returns (address)",
  "function finalityExecutionContextWithArchive((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash)[] components, bytes32 expectedFinalityRecordHash, (string uri, bytes32 uriHash, bytes32 contentHash, bytes32 schemaId, bytes32 canonicalizationHash) manifest, (bytes32 sanctionRecordHash, bytes32 artifactHash, bytes32 completionHash) proof) view returns ((bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, bytes32 finalityRecordHash, bytes32 coreFactsHash, bytes32 componentsHash, bytes32 inputsHash) execution)",
  "function finalityExecutionWitness(bytes32 finalityRecordHash) view returns ((bytes32 actionId, address proposer, bytes32 reasonHash, bytes32 roleMutationHash, uint64 roleRevision))",
  "function finalityManifestBytes(bytes32 contentHash) view returns (bytes)",
  "function finalityManifestStored(bytes32 contentHash) view returns (bool)",
  "function finalityRoleRegistry() view returns (address)",
  "function finalitySanctionArchiveWitness(bytes32 recordHash) view returns ((bytes32 evidenceHash, (bytes32 sanctionRecordHash, bytes32 artifactHash, bytes32 completionHash) proof))",
  "function finalizeArtworkScopeWithArchive((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash)[] components, bytes32 expectedFinalityRecordHash, (string uri, bytes32 uriHash, bytes32 contentHash, bytes32 schemaId, bytes32 canonicalizationHash) manifest, (bytes32 sanctionRecordHash, bytes32 artifactHash, bytes32 completionHash) proof)",
  "function governanceAuthority() view returns (address)",
  "function metadataReads() view returns (address)",
  "function prepareSanction((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash)[] nonSanctionComponents, (string uri, bytes32 uriHash, bytes32 contentHash, bytes32 schemaId, bytes32 canonicalizationHash) manifest) view returns ((bytes32 sanctionSubjectHash, bytes32 coreFactsHash, bytes32 nonSanctionComponentsHash, bytes32 scopeInputsHash))",
  "function prepareSanctionWithReview((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash)[] nonSanctionComponents, (string uri, bytes32 uriHash, bytes32 contentHash, bytes32 schemaId, bytes32 canonicalizationHash) manifest) view returns ((bytes32 sanctionSubjectHash, bytes32 coreFactsHash, bytes32 nonSanctionComponentsHash, bytes32 scopeInputsHash), (uint16 schemaVersion, uint8 profile, bytes32 contentRoot, bytes32[] mediaContentHashes, bytes32[] referenceRenderContentHashes))",
  "function sanctionReads() view returns (address)",
  "function scopeEvidenceProvider() view returns (address)",
  "function scopeEvidenceProviderCodeHash() view returns (bytes32)",
  "function stageFinalityManifest(bytes manifestBytes) returns (bytes32 contentHash)",
  "function supportsInterface(bytes4 id) view returns (bool)",
  "function verifyArtworkScopeFinality((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bool currentRouteMatches, bytes32 finalityRecordHash, bytes32 componentsHash)",
  "function verifyArtworkScopeFinalityRange((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint256 start, uint256 limit) view returns (bool rangeMatches, bytes32 finalityRecordHash, bytes32 expectedRangeHash, bytes32 observedRangeHash, uint256 nextStart)",
]);

export const SCOPED_POLICY_FINALITY_V2_PROVIDER_ABI: readonly string[] = Object.freeze([
  "error FinalityReadFailed(address target)",
  "error InvalidFinalitySourceProfile()",
  "error InvalidMetadataScope()",
  "error NativeProviderConfiguration()",
  "error NativeProviderConfiguration()",
  "error NativeProviderDependency(address target)",
  "error NativeProviderOriginalRegistryOnly()",
  "error NativeProviderSource()",
  "error RouterEvidenceFamily(bytes32 family)",
  "error RouterEvidenceGas(uint256 available, uint256 required)",
  "error RouterEvidenceRead(address target, bytes4 selector)",
  "error RouterProviderAnchor(address registry)",
  "error RouterProviderConfiguration()",
  "error RouterProviderDependency(address target)",
  "error RouterProviderScope()",
  "error ScopedPolicyGraphConfiguration()",
  "function collectionMetadataMode(uint256 cid) view returns (uint8)",
  "function collectionRecordTypeLocked(uint256 cid, bytes32) view returns (bool)",
  "function componentHost(bytes32 family) view returns (address)",
  "function contentLeafManifest() view returns (address)",
  "function contentLeafManifestCodeHash() view returns (bytes32)",
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function deploymentChainId() view returns (uint256)",
  "function entropySourceFactory() view returns (address)",
  "function finalityComponentFacts(bytes32 family, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bool frozen, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash) f)",
  "function finalitySourceConfigurationHash() view returns (bytes32)",
  "function finalitySourceProfile(uint8 index) view returns ((bytes32 profileHash, address referenceRender, bytes32 referenceRenderCodeHash, address snapshots, bytes32 snapshotsCodeHash, address entropyFactory, bytes32 entropyFactoryCodeHash, bytes32 configurationHash))",
  "function finalitySourcesForScope((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 profileHash, address referenceRender, bytes32 referenceRenderCodeHash, address snapshots, bytes32 snapshotsCodeHash, address entropyFactory, bytes32 entropyFactoryCodeHash, bytes32 configurationHash) profile))",
  "function inputManifestBytes((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes)",
  "function latestCollectionSnapshotHash(uint256 cid) view returns (bytes32)",
  "function metadataHost() view returns (address)",
  "function metadataHostCodeHash() view returns (bytes32)",
  "function metadataModuleManifestHash() view returns (bytes32)",
  "function metadataModuleVersion() view returns (bytes32)",
  "function metadataRouter() view returns (address)",
  "function metadataRouterCodeHash() view returns (bytes32)",
  "function nativeConfiguration() view returns ((address[22] targets, bytes32[22] codeHashes, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 componentSourceGas, bytes32 inventoryDependencyHash))",
  "function policyConfiguration() view returns ((address[22] targets, bytes32[22] codeHashes, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 componentSourceGas, bytes32 inventoryDependencyHash))",
  "function policyOutputManifestV2() view returns (address)",
  "function policyOutputManifestV2CodeHash() view returns (bytes32)",
  "function policyReferencePublicationV2() view returns (address)",
  "function policyReferencePublicationV2CodeHash() view returns (bytes32)",
  "function policySnapshotPublicationV2() view returns (address)",
  "function policySnapshotPublicationV2CodeHash() view returns (bytes32)",
  "function readGas() view returns (uint32)",
  "function referenceRenderHost() view returns (address)",
  "function requireCurrentRouterCandidate(uint256 collectionId, address registry) view",
  "function requireFinalityScopeInputs((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 manifestHash) view returns ((bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash, bytes32 renderCriticalEvidenceHash, bytes32 bundleCoverageHash), bytes32, bytes32)",
  "function requirePreparedFinalityScopeInputs((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 manifestHash, (bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash)[] components) view returns ((bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash, bytes32 renderCriticalEvidenceHash, bytes32 bundleCoverageHash), bytes32, bytes32)",
  "function requirePreparedFinalityScopeInputsAndReview((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 manifestHash, (bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash)[] components) view returns ((bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash, bytes32 renderCriticalEvidenceHash, bytes32 bundleCoverageHash), bytes32, bytes32, (uint16 schemaVersion, uint8 profile, bytes32 contentRoot, bytes32[] mediaContentHashes, bytes32[] referenceRenderContentHashes))",
  "function requireSanctionReviewFacts((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 manifestHash) view returns ((uint16 schemaVersion, uint8 profile, bytes32 contentRoot, bytes32[] mediaContentHashes, bytes32[] referenceRenderContentHashes))",
  "function routerModuleManifestHash() view returns (bytes32)",
  "function routerModuleVersion() view returns (bytes32)",
  "function schemaRegistry() view returns (address)",
  "function schemaRegistryCodeHash() view returns (bytes32)",
  "function scopeManifest(uint256 cid, bytes32 scopeId) view returns (bool, bytes32)",
  "function scopeMembershipHost() view returns (address)",
  "function scopeMembershipHostCodeHash() view returns (bytes32)",
  "function scopedConfiguration() view returns ((address[22] targets, bytes32[22] codeHashes, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 componentSourceGas, bytes32 inventoryDependencyHash))",
  "function scopedContentRoot((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32, uint64, bytes32)",
  "function scopedManifest((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bool, bytes32)",
  "function scopedPolicyPublicationBinding() view returns ((address factory, bytes32 factoryCodeHash, bytes32 recipeHash, bytes32 sourceFactoryDependenciesHash, uint256 graphGas, bytes32 configurationHash))",
  "function scopedPolicySnapshotCodeHash((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32)",
  "function scopedPolicySnapshotHost((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (address)",
  "function scopedPolicySnapshotProfile() pure returns (bytes32)",
  "function scopedPolicySnapshotValidationGas((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint256)",
  "function scopedSnapshotCodeHash() view returns (bytes32)",
  "function scopedSnapshotHash((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32)",
  "function scopedSnapshotHost() view returns (address)",
  "function scopedSnapshotValidationGas() view returns (uint256)",
  "function snapshotHost() view returns (address)",
  "function sourceGas() view returns (uint32)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function tokenContentRoot(uint256 cid, bytes32 subject) view returns (bytes32, uint64, bytes32)",
]);

export const SCOPED_POLICY_FINALITY_V2_DISCOVERY_ABI: readonly string[] = Object.freeze([
  "error DiscoveryComponent(address target, bytes32 family)",
  "error DiscoveryConfiguration(address target)",
  "error DiscoveryDependency(address target)",
  "error DiscoveryIndex(uint256 index)",
  "error DiscoveryUnsupportedProfile()",
  "error InvalidFinalitySourceProfile()",
  "error InvalidMetadataScope()",
  "error RouterEvidenceGas(uint256 available, uint256 required)",
  "error RouterEvidenceRead(address target, bytes4 selector)",
  "function configuration() view returns ((address core, address metadata, address router, address provider, address membership, address entropyFactory, address metadataAdapter, address referenceRender, address artist, address finalityRegistry, bytes32 finalityRegistryCodeHash, address[6] routerAdapters, uint32 readGas, uint32 componentGas, uint32 entropyGas))",
  "function core() view returns (address)",
  "function dependencyCodeHash(address target) view returns (bytes32)",
  "function deploymentChainId() view returns (uint256)",
  "function finalityComponentAt(uint256 cid, uint256 index) view returns ((bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash))",
  "function finalityComponentAtForScope((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint256 index) view returns ((bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash))",
  "function finalityComponentCount(uint256 cid) view returns (uint256)",
  "function finalityComponentCountForScope((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint256)",
  "function finalityDiscoveryHash(uint256 cid) view returns (bytes32)",
  "function finalityDiscoveryHashForScope((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32)",
  "function metadataHost() view returns (address)",
  "function nonSanctionComponentAt((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint256 index) view returns ((bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash, bytes32 moduleVersion, bytes32 manifestHash, bytes32 dataHash))",
  "function nonSanctionDiscoveryFacts((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint256 count, bytes32 hash)",
  "function requireCurrentRoutes((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bool includeSanction) view returns ((bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash)[] routes)",
  "function scopeEvidenceProvider() view returns (address)",
  "function sourceConfigurationHash() view returns (bytes32)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
]);

export const SCOPED_POLICY_FINALITY_V2_EXECUTOR_ABI: readonly string[] = Object.freeze([
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
  "event ApprovedNativeReceiverUpdated(uint16 schemaVersion, address indexed receiver, bool approved, uint64 revision, bytes32 indexed actionId)",
  "event FreezeSelectorUpdated(uint16 schemaVersion, address indexed target, bytes4 indexed selector, bool freeze, bytes32 targetCodeHash, uint64 revision, bytes32 indexed actionId)",
  "event GenesisInitialized(bytes32 indexed planHash, uint256 batchCount)",
  "event GenesisPlanCommitted(bytes32 indexed planHash, address indexed authority)",
  "event GenesisPrepared(bytes32 indexed planHash)",
  "event GovernanceActionCancelled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, bytes4 selector, bytes32 callHash, bytes32 scopeHash, address canceller, bytes32 reasonHash, string reasonURI)",
  "event GovernanceActionExecuted(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, address executor, bytes32 manifestHash)",
  "event GovernanceActionExpired(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address materializer)",
  "event GovernanceActionPolicyBound(uint16 schemaVersion, bytes32 indexed candidateProfileHash, bytes32 indexed catalogHash, uint256 entryCount)",
  "event GovernanceActionPolicyExtended(uint64 indexed revision, bytes32 indexed oldCatalogHash, bytes32 indexed newCatalogHash, uint256 oldEntryCount, uint256 newEntryCount)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed phase, bytes32 indexed candidateProfileHash, bytes32 catalogHash)",
  "event GovernanceActionScheduled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, uint256 nonce, address proposer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash)",
  "event GovernanceActionVetoed(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed vetoer, bytes32 scopeHash, bytes32 reasonHash)",
  "event GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed callDataKey, address pointer, address publisher)",
  "event GovernanceCancellerUpdated(uint16 schemaVersion, address indexed account, bool enabled, uint64 revision, bytes32 indexed actionId)",
  "event GovernanceProposerUpdated(uint16 schemaVersion, address indexed account, bool enabled, uint64 revision, bytes32 indexed actionId)",
  "event GovernanceRootRotated(uint16 schemaVersion, address indexed oldRoot, address indexed newRoot, bytes32 newRootCodeHash, uint64 revision, bytes32 indexed actionId)",
  "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)",
  "event StateExportChallenged(uint16 schemaVersion, bytes32 indexed exportHash, bytes32 indexed challengeHash, address indexed challenger, string challengeURI)",
  "event StateExportPublished(uint16 schemaVersion, uint256 indexed blockNumber, bytes32 indexed exportHash, bytes32 indexed manifestHash, bytes32 blockHash, string manifestURI)",
  "event StateExportSuperseded(uint16 schemaVersion, bytes32 indexed oldExportHash, bytes32 indexed newExportHash, bytes32 indexed reasonHash, string reasonURI)",
  "event SystemManifestBootstrapBound(uint16 schemaVersion, address indexed core, address indexed systemManifestSatellite, bytes32 coreCodeHash, bytes32 systemManifestSatelliteCodeHash, bytes32 indexed expectedManifestHash, bytes32 expectedInventoryStateRoot, bytes32 expectedTriggerSetHash, uint256 triggerCount, address genesisBootstrapAuthority, address roleRegistry, bytes32 roleRegistryCodeHash, address governanceRoot, bytes32 governanceRootCodeHash, bytes32 initialGuardianSetHash, uint256 initialGuardianCount, bytes32 terminalFreezeVetoMutationChain, uint64 terminalFreezeVetoMutationRevision)",
  "event SystemManifestBootstrapSealed(uint16 schemaVersion, bytes32 indexed triggerSetHash, uint256 triggerCount, address indexed payloadPointer, bytes32 manifestHash, bytes32 indexed actionId)",
  "event SystemManifestTailTriggerRegistered(uint16 schemaVersion, address indexed triggerTarget, bytes4 indexed triggerSelector, bytes32 triggerCodeHash, uint8 allowedActionClassMask, address tailTarget, bytes4 tailSelector, bytes32 indexed actionId)",
  "event TerminalFreezeActionMembershipUpdated(uint16 schemaVersion, bytes32 indexed scopeHash, bytes32 indexed actionId, address indexed proposer, bool present, uint8 mutationCause, bool usesRootCapacity, uint64 vetoDeadline, uint256 rawIndex, uint256 remainingCount)",
  "event TerminalFreezeGuardianConfigCommitted(uint16 schemaVersion, bytes32 indexed actionId, bytes32 indexed commitment)",
  "event TighteningCallUpdated(uint16 schemaVersion, address indexed target, bytes4 indexed selector, bool tightening, bytes32 targetCodeHash, uint64 revision, bytes32 indexed actionId)",
  "function currentAction() view returns (bool executing, bytes32 actionId, uint8 actionClass, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)",
  "function executeGovernanceBatch(bytes32 actionId, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes[] callDatas) payable",
  "function freezeSelectorConfig(address target, bytes4 selector) view returns (bool freeze, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash)",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function governanceActionFacts(bytes32 id) view returns ((uint8 status, uint8 actionClass, bytes32 callHash, uint64 notBefore, uint64 expiresAfter) facts)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function governanceNonce() view returns (uint256)",
  "function isFreezeSelector(address target, bytes4 selector) view returns (bool)",
  "function isProposer(address account) view returns (bool)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function publishGovernanceCallData(bytes[] callDatas) returns (address pointer)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function roleRegistry() view returns (address)",
  "function scheduleGovernanceBatch(uint8 actionClass, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, bytes32 reasonHash, string reasonURI, bytes32 manifestHash) returns (bytes32 actionId)",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function terminalFreezeGuardianConfigCommitment(bytes32 actionId) view returns (bytes32 commitment)",
  "function terminalFreezeLiveActionCaps() pure returns (uint256 totalCap, uint256 nonRootCap, uint256 perNonRootProposerCap)",
  "function terminalFreezeLiveActionUsage(bytes32 scopeHash, address proposer) view returns (uint256 totalMemberships, uint256 nonRootMemberships, uint256 proposerMemberships)",
]);

export const SCOPED_POLICY_FINALITY_V2_SCHEMA = id("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1") as Hex;
export const SCOPED_POLICY_FINALITY_V2_SCHEMA_DOCUMENT = "{\"name\":\"6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1\",\"version\":1,\"format\":\"Solidity ABI\",\"profile\":\"native STATIC ONCHAIN artist-bound TOKEN/RELEASE/SEASON\",\"statement\":\"StreamScopedFinalityInputManifestTypes.Statement\",\"fields\":[\"StreamFinalityScope scope\",\"bytes32 coreFactsHash\",\"bytes32 contentRoot\",\"uint64 leafCount\",\"bytes32 contentRootSchemaId\",\"bytes32 snapshotManifestHash\",\"bytes32 referenceRenderManifestHash\",\"StreamFinalityScopeInputs inputs\",\"StreamFinalityComponentExpectation[] nonSanctionComponents\",\"uint8 entropyPolicy\",\"uint8 postFreezePolicy\",\"uint8 sanctionPolicy\"],\"inputOrder\":[\"rootRecordHash\",\"snapshotRecordHash\",\"referenceRenderRecordHash\",\"intentRecordHash\",\"intentWaiverRecordHash\",\"interviewEvidenceHash\",\"rightsStatementRecordHash\",\"workDescriptionRecordHash\",\"renderCriticalEvidenceHash\",\"bundleCoverageHash\"],\"components\":\"Exactly the nine required independent families in ascending family order; all seven original expectation fields retained\",\"policies\":{\"entropyPolicy\":1,\"postFreezePolicy\":1,\"sanctionPolicy\":1},\"policyMeaning\":\"All members have terminal entropy; no artwork-byte mutation exceptions; actual artist sanction and its archival proof are separate execution requirements\",\"originalEvidence\":\"Distinct scoped Router root, scoped snapshot and scoped reference records resolve complete source/membership/selection/output commitments; samples never substitute for membership; original renderer/context/native policies/runtime environment and archive receipt identities retained\",\"excluded\":\"Own content hash, finality record, sanction record and signature; no mutable fixity head is substituted into original evidence\",\"authority\":\"Only the fixed provider rederives and validates current facts; encoding or byte publication grants no authority or readiness\"}";
export const SCOPED_POLICY_FINALITY_V2_SCHEMA_HASH = keccak256(toUtf8Bytes(SCOPED_POLICY_FINALITY_V2_SCHEMA_DOCUMENT)) as Hex;
export const SCOPED_POLICY_FINALITY_V2_SCHEMA_BYTES = BigInt(toUtf8Bytes(SCOPED_POLICY_FINALITY_V2_SCHEMA_DOCUMENT).length);
export const SCOPED_POLICY_FINALITY_V2_CANONICALIZATION = id("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1") as Hex;
export const SCOPED_POLICY_FINALITY_V2_CANONICALIZATION_DOCUMENT = "{\"name\":\"6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1\",\"version\":1,\"encoding\":\"abi.encode(bytes32 schemaId,bytes32 canonicalizationId,uint256 chainId,address core,address metadataHost,address finalityRegistry,StreamScopedFinalityInputManifestTypes.Statement statement)\",\"schemaId\":\"keccak256(6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1)\",\"canonicalizationId\":\"keccak256(6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1)\",\"scope\":\"TOKEN=1: nonzero collectionId/tokenId and zero scopeId; RELEASE=2 or SEASON=3: nonzero collectionId/scopeId and zero tokenId; no COLLECTION or VIEW\",\"scopeTuple\":[\"uint8 scopeType\",\"uint256 collectionId\",\"uint256 tokenId\",\"bytes32 scopeId\"],\"inputTuple\":[\"bytes32 rootRecordHash\",\"bytes32 snapshotRecordHash\",\"bytes32 referenceRenderRecordHash\",\"bytes32 intentRecordHash\",\"bytes32 intentWaiverRecordHash\",\"bytes32 interviewEvidenceHash\",\"bytes32 rightsStatementRecordHash\",\"bytes32 workDescriptionRecordHash\",\"bytes32 renderCriticalEvidenceHash\",\"bytes32 bundleCoverageHash\"],\"componentTuple\":[\"bytes32 componentType\",\"address component\",\"bytes4 interfaceId\",\"bytes32 codeHash\",\"bytes32 moduleVersion\",\"bytes32 manifestHash\",\"bytes32 dataHash\"],\"expandedEnvelope\":\"(bytes32,bytes32,uint256,address,address,address,((uint8,uint256,uint256,bytes32),bytes32,bytes32,uint64,bytes32,bytes32,bytes32,(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32)[],uint8,uint8,uint8))\",\"componentCount\":9,\"componentWords\":7,\"words\":\"Solidity 0.8.19 canonical ABI; uint64/uint8 and addresses zero extended, bytes4 right padded\",\"arrays\":\"Exact fixed family order, no duplicate or omitted family\",\"trailingBytes\":\"Forbidden\",\"alternateOffsets\":\"Forbidden\",\"maximumBytes\":8192,\"hash\":\"Keccak-256 of all exact bytes\",\"scopeInputCommitment\":\"Existing 6529STREAM_FINALITY_SCOPE_INPUTS_V1 domain with chainId, actual Core, actual generic metadataHost, scope and ten inputs; never provider address\",\"retention\":\"The actual schema Store and original Registry staging must both retain identical complete bytes under this content hash\"}";
export const SCOPED_POLICY_FINALITY_V2_CANONICALIZATION_HASH = keccak256(toUtf8Bytes(SCOPED_POLICY_FINALITY_V2_CANONICALIZATION_DOCUMENT)) as Hex;
export const SCOPED_POLICY_FINALITY_V2_CANONICALIZATION_BYTES = BigInt(toUtf8Bytes(SCOPED_POLICY_FINALITY_V2_CANONICALIZATION_DOCUMENT).length);

const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;
const registryInterface = new Interface(SCOPED_POLICY_FINALITY_V2_REGISTRY_ABI);
const providerInterface = new Interface(SCOPED_POLICY_FINALITY_V2_PROVIDER_ABI);
const discoveryInterface = new Interface(SCOPED_POLICY_FINALITY_V2_DISCOVERY_ABI);
const executorInterface = new Interface(SCOPED_POLICY_FINALITY_V2_EXECUTOR_ABI);

function exact(value: unknown, keys: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).length !== keys.length
    || keys.some(key => !Object.prototype.hasOwnProperty.call(value, key))) {
    throw Error(label + " has an invalid exact shape");
  }
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) {
    throw Error("Invalid uint" + bits);
  }
  return value;
}

function address(value: unknown, required = false): Address {
  if (typeof value !== "string" || !isHexString(value, 20)) throw Error("Invalid address");
  const result = getAddress(value) as Address;
  if (required && result === ZeroAddress) throw Error("Zero address");
  return result;
}

function bytes(value: unknown, length?: number, maximum = SCOPED_POLICY_FINALITY_V2_MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, length ?? true)
    || (value.length - 2) / 2 > maximum) throw Error("Invalid bytes or byte bound");
  return value.toLowerCase() as Hex;
}

function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === ZERO) throw Error("Zero commitment");
  return result;
}

function text(value: unknown): string {
  if (typeof value !== "string"
    || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)
    || toUtf8Bytes(value).length > SCOPED_POLICY_FINALITY_V2_MAX_BYTES) throw Error("Invalid UTF8 text or byte bound");
  return value;
}

function list(value: unknown, maximum: number): readonly unknown[] {
  if (!Array.isArray(value) || value.length > maximum || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.prototype.hasOwnProperty.call(value, i))) {
    throw Error("Invalid bounded dense array");
  }
  return value;
}

function valueOf(type: ParamType, value: unknown, decoded = false): unknown {
  if (type.baseType === "array") {
    const values = list(value, type.arrayLength! >= 0 ? type.arrayLength! : 4096);
    if (type.arrayLength! >= 0 && values.length !== type.arrayLength) throw Error("Wrong fixed array length");
    return Object.freeze(values.map(entry => valueOf(type.arrayChildren!, entry, decoded)));
  }
  if (type.baseType === "tuple") {
    if (!decoded) exact(value, type.components!.map(field => field.name), "Tuple");
    return Object.freeze(Object.fromEntries(type.components!.map((field, index) => [
      field.name,
      valueOf(field, decoded ? (value as readonly unknown[])[index] : (value as Record<string, unknown>)[field.name], decoded),
    ])));
  }
  if (type.type.startsWith("uint")) return uint(value, Number(type.type.slice(4)));
  if (type.type === "address") return address(value);
  if (type.type.startsWith("bytes")) return bytes(value, type.type === "bytes" ? undefined : Number(type.type.slice(5)));
  if (type.type === "string") return text(value);
  if (type.type === "bool" && typeof value === "boolean") return value;
  throw Error("Invalid ABI value: " + type.type);
}

function normalized<T>(tuple: string, value: unknown, decoded = false): T {
  const result = valueOf(ParamType.from(tuple), value, decoded);
  // Only the actual enum fields are restricted; raw ScopedCoreFacts.scopeType is uint8.
  function enums(type: ParamType, data: unknown): void {
    if (type.baseType === "array") {
      (data as readonly unknown[]).forEach(entry => enums(type.arrayChildren!, entry));
    } else if (type.baseType === "tuple") {
      const row = data as Record<string, unknown>;
      if (type.format("sighash") === ParamType.from(SCOPED_POLICY_FINALITY_V2_SCOPE_TUPLE).format("sighash")
        && (row.scopeType as bigint) > 4n) throw Error("Unknown scope enum");
      for (const field of type.components!) enums(field, row[field.name]);
    }
  }
  enums(ParamType.from(tuple), result);
  if (tuple === SCOPED_POLICY_FINALITY_V2_GOVERNANCE_ACTION_TUPLE
    && (result as ScopedPolicyFinalityV2GovernanceAction).status > 5n) throw Error("Unknown governance status enum");
  return result as T;
}

function encode(tuple: string, value: unknown): Hex {
  return bytes(coder.encode([tuple], [normalized(tuple, value)]));
}

function decode<T>(tuple: string, value: Hex): T {
  const raw = bytes(value);
  const result = normalized<T>(tuple, coder.decode([tuple], raw)[0], true);
  if (encode(tuple, result) !== raw) throw Error("Noncanonical ABI encoding");
  return result;
}

function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

function same(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (!a || !b || typeof a !== "object" || typeof b !== "object" || Array.isArray(a) !== Array.isArray(b)) return false;
  const ak = Reflect.ownKeys(a), bk = Reflect.ownKeys(b);
  return ak.length === bk.length && ak.every(key => bk.includes(key)
    && same((a as Record<PropertyKey, unknown>)[key], (b as Record<PropertyKey, unknown>)[key]));
}

export function scopedPolicyFinalityV2Interface(host: "registry" | "provider" | "discovery" | "executor"): Interface {
  switch (host) {
    case "registry": return new Interface(SCOPED_POLICY_FINALITY_V2_REGISTRY_ABI);
    case "provider": return new Interface(SCOPED_POLICY_FINALITY_V2_PROVIDER_ABI);
    case "discovery": return new Interface(SCOPED_POLICY_FINALITY_V2_DISCOVERY_ABI);
    case "executor": return new Interface(SCOPED_POLICY_FINALITY_V2_EXECUTOR_ABI);
    default: throw Error("Unknown original finality host");
  }
}

export function normalizeScopedPolicyFinalityV2Coordinates(value: ScopedPolicyFinalityV2Coordinates): ScopedPolicyFinalityV2Coordinates {
  exact(value, ["chainId", "core", "metadata", "registry", "executor", "artist", "artifactCoverage"], "Coordinates");
  const chainId = uint(value.chainId);
  if (chainId === 0n) throw Error("Manifest requires positive chainId");
  return Object.freeze({ chainId, core: address(value.core, true), metadata: address(value.metadata, true),
    registry: address(value.registry, true), executor: address(value.executor, true),
    artist: address(value.artist, true), artifactCoverage: address(value.artifactCoverage, true) });
}

export function normalizeScopedPolicyFinalityV2Scope(
  value: ScopedPolicyFinalityV2Scope,
): ScopedPolicyFinalityV2Scope {
  return normalized(SCOPED_POLICY_FINALITY_V2_SCOPE_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2Scope(
  value: ScopedPolicyFinalityV2Scope,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_SCOPE_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2Scope(
  value: Hex,
): ScopedPolicyFinalityV2Scope {
  return decode(SCOPED_POLICY_FINALITY_V2_SCOPE_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2Component(
  value: ScopedPolicyFinalityV2Component,
): ScopedPolicyFinalityV2Component {
  return normalized(SCOPED_POLICY_FINALITY_V2_COMPONENT_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2Component(
  value: ScopedPolicyFinalityV2Component,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_COMPONENT_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2Component(
  value: Hex,
): ScopedPolicyFinalityV2Component {
  return decode(SCOPED_POLICY_FINALITY_V2_COMPONENT_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2ComponentState(
  value: ScopedPolicyFinalityV2ComponentState,
): ScopedPolicyFinalityV2ComponentState {
  return normalized(SCOPED_POLICY_FINALITY_V2_COMPONENT_STATE_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2ComponentState(
  value: ScopedPolicyFinalityV2ComponentState,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_COMPONENT_STATE_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2ComponentState(
  value: Hex,
): ScopedPolicyFinalityV2ComponentState {
  return decode(SCOPED_POLICY_FINALITY_V2_COMPONENT_STATE_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2Inputs(
  value: ScopedPolicyFinalityV2Inputs,
): ScopedPolicyFinalityV2Inputs {
  return normalized(SCOPED_POLICY_FINALITY_V2_INPUTS_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2Inputs(
  value: ScopedPolicyFinalityV2Inputs,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_INPUTS_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2Inputs(
  value: Hex,
): ScopedPolicyFinalityV2Inputs {
  return decode(SCOPED_POLICY_FINALITY_V2_INPUTS_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2Statement(
  value: ScopedPolicyFinalityV2Statement,
): ScopedPolicyFinalityV2Statement {
  return normalized(SCOPED_POLICY_FINALITY_V2_STATEMENT_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2Statement(
  value: ScopedPolicyFinalityV2Statement,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_STATEMENT_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2Statement(
  value: Hex,
): ScopedPolicyFinalityV2Statement {
  return decode(SCOPED_POLICY_FINALITY_V2_STATEMENT_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2ManifestRef(
  value: ScopedPolicyFinalityV2ManifestRef,
): ScopedPolicyFinalityV2ManifestRef {
  return normalized(SCOPED_POLICY_FINALITY_V2_MANIFEST_REF_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2ManifestRef(
  value: ScopedPolicyFinalityV2ManifestRef,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_MANIFEST_REF_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2ManifestRef(
  value: Hex,
): ScopedPolicyFinalityV2ManifestRef {
  return decode(SCOPED_POLICY_FINALITY_V2_MANIFEST_REF_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2Profile(
  value: ScopedPolicyFinalityV2Profile,
): ScopedPolicyFinalityV2Profile {
  return normalized(SCOPED_POLICY_FINALITY_V2_PROFILE_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2Profile(
  value: ScopedPolicyFinalityV2Profile,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_PROFILE_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2Profile(
  value: Hex,
): ScopedPolicyFinalityV2Profile {
  return decode(SCOPED_POLICY_FINALITY_V2_PROFILE_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2Sources(
  value: ScopedPolicyFinalityV2Sources,
): ScopedPolicyFinalityV2Sources {
  return normalized(SCOPED_POLICY_FINALITY_V2_SOURCES_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2Sources(
  value: ScopedPolicyFinalityV2Sources,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_SOURCES_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2Sources(
  value: Hex,
): ScopedPolicyFinalityV2Sources {
  return decode(SCOPED_POLICY_FINALITY_V2_SOURCES_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2NativeConfiguration(
  value: ScopedPolicyFinalityV2NativeConfiguration,
): ScopedPolicyFinalityV2NativeConfiguration {
  return normalized(SCOPED_POLICY_FINALITY_V2_NATIVE_CONFIGURATION_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2NativeConfiguration(
  value: ScopedPolicyFinalityV2NativeConfiguration,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_NATIVE_CONFIGURATION_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2NativeConfiguration(
  value: Hex,
): ScopedPolicyFinalityV2NativeConfiguration {
  return decode(SCOPED_POLICY_FINALITY_V2_NATIVE_CONFIGURATION_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2DiscoveryConfiguration(
  value: ScopedPolicyFinalityV2DiscoveryConfiguration,
): ScopedPolicyFinalityV2DiscoveryConfiguration {
  return normalized(SCOPED_POLICY_FINALITY_V2_DISCOVERY_CONFIGURATION_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2DiscoveryConfiguration(
  value: ScopedPolicyFinalityV2DiscoveryConfiguration,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_DISCOVERY_CONFIGURATION_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2DiscoveryConfiguration(
  value: Hex,
): ScopedPolicyFinalityV2DiscoveryConfiguration {
  return decode(SCOPED_POLICY_FINALITY_V2_DISCOVERY_CONFIGURATION_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2FactoryBinding(
  value: ScopedPolicyFinalityV2FactoryBinding,
): ScopedPolicyFinalityV2FactoryBinding {
  return normalized(SCOPED_POLICY_FINALITY_V2_FACTORY_BINDING_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2FactoryBinding(
  value: ScopedPolicyFinalityV2FactoryBinding,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_FACTORY_BINDING_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2FactoryBinding(
  value: Hex,
): ScopedPolicyFinalityV2FactoryBinding {
  return decode(SCOPED_POLICY_FINALITY_V2_FACTORY_BINDING_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2SourceConfiguration(
  value: ScopedPolicyFinalityV2SourceConfiguration,
): ScopedPolicyFinalityV2SourceConfiguration {
  return normalized(SCOPED_POLICY_FINALITY_V2_SOURCE_CONFIGURATION_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2SourceConfiguration(
  value: ScopedPolicyFinalityV2SourceConfiguration,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_SOURCE_CONFIGURATION_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2SourceConfiguration(
  value: Hex,
): ScopedPolicyFinalityV2SourceConfiguration {
  return decode(SCOPED_POLICY_FINALITY_V2_SOURCE_CONFIGURATION_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2ExecutionContext(
  value: ScopedPolicyFinalityV2ExecutionContext,
): ScopedPolicyFinalityV2ExecutionContext {
  return normalized(SCOPED_POLICY_FINALITY_V2_EXECUTION_CONTEXT_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2ExecutionContext(
  value: ScopedPolicyFinalityV2ExecutionContext,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_EXECUTION_CONTEXT_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2ExecutionContext(
  value: Hex,
): ScopedPolicyFinalityV2ExecutionContext {
  return decode(SCOPED_POLICY_FINALITY_V2_EXECUTION_CONTEXT_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2ExecutionWitness(
  value: ScopedPolicyFinalityV2ExecutionWitness,
): ScopedPolicyFinalityV2ExecutionWitness {
  return normalized(SCOPED_POLICY_FINALITY_V2_EXECUTION_WITNESS_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2ExecutionWitness(
  value: ScopedPolicyFinalityV2ExecutionWitness,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_EXECUTION_WITNESS_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2ExecutionWitness(
  value: Hex,
): ScopedPolicyFinalityV2ExecutionWitness {
  return decode(SCOPED_POLICY_FINALITY_V2_EXECUTION_WITNESS_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2ArchiveProof(
  value: ScopedPolicyFinalityV2ArchiveProof,
): ScopedPolicyFinalityV2ArchiveProof {
  return normalized(SCOPED_POLICY_FINALITY_V2_ARCHIVE_PROOF_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2ArchiveProof(
  value: ScopedPolicyFinalityV2ArchiveProof,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_ARCHIVE_PROOF_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2ArchiveProof(
  value: Hex,
): ScopedPolicyFinalityV2ArchiveProof {
  return decode(SCOPED_POLICY_FINALITY_V2_ARCHIVE_PROOF_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2ArchiveWitness(
  value: ScopedPolicyFinalityV2ArchiveWitness,
): ScopedPolicyFinalityV2ArchiveWitness {
  return normalized(SCOPED_POLICY_FINALITY_V2_ARCHIVE_WITNESS_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2ArchiveWitness(
  value: ScopedPolicyFinalityV2ArchiveWitness,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_ARCHIVE_WITNESS_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2ArchiveWitness(
  value: Hex,
): ScopedPolicyFinalityV2ArchiveWitness {
  return decode(SCOPED_POLICY_FINALITY_V2_ARCHIVE_WITNESS_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2ScopedRecord(
  value: ScopedPolicyFinalityV2ScopedRecord,
): ScopedPolicyFinalityV2ScopedRecord {
  return normalized(SCOPED_POLICY_FINALITY_V2_SCOPED_RECORD_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2ScopedRecord(
  value: ScopedPolicyFinalityV2ScopedRecord,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_SCOPED_RECORD_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2ScopedRecord(
  value: Hex,
): ScopedPolicyFinalityV2ScopedRecord {
  return decode(SCOPED_POLICY_FINALITY_V2_SCOPED_RECORD_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2SanctionPreparation(
  value: ScopedPolicyFinalityV2SanctionPreparation,
): ScopedPolicyFinalityV2SanctionPreparation {
  return normalized(SCOPED_POLICY_FINALITY_V2_SANCTION_PREPARATION_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2SanctionPreparation(
  value: ScopedPolicyFinalityV2SanctionPreparation,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_SANCTION_PREPARATION_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2SanctionPreparation(
  value: Hex,
): ScopedPolicyFinalityV2SanctionPreparation {
  return decode(SCOPED_POLICY_FINALITY_V2_SANCTION_PREPARATION_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2Review(
  value: ScopedPolicyFinalityV2Review,
): ScopedPolicyFinalityV2Review {
  return normalized(SCOPED_POLICY_FINALITY_V2_REVIEW_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2Review(
  value: ScopedPolicyFinalityV2Review,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_REVIEW_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2Review(
  value: Hex,
): ScopedPolicyFinalityV2Review {
  return decode(SCOPED_POLICY_FINALITY_V2_REVIEW_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2ScopedCoreFacts(
  value: ScopedPolicyFinalityV2ScopedCoreFacts,
): ScopedPolicyFinalityV2ScopedCoreFacts {
  return normalized(SCOPED_POLICY_FINALITY_V2_SCOPED_CORE_FACTS_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2ScopedCoreFacts(
  value: ScopedPolicyFinalityV2ScopedCoreFacts,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_SCOPED_CORE_FACTS_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2ScopedCoreFacts(
  value: Hex,
): ScopedPolicyFinalityV2ScopedCoreFacts {
  return decode(SCOPED_POLICY_FINALITY_V2_SCOPED_CORE_FACTS_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2GovernanceCall(
  value: ScopedPolicyFinalityV2GovernanceCall,
): ScopedPolicyFinalityV2GovernanceCall {
  return normalized(SCOPED_POLICY_FINALITY_V2_GOVERNANCE_CALL_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2GovernanceCall(
  value: ScopedPolicyFinalityV2GovernanceCall,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_GOVERNANCE_CALL_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2GovernanceCall(
  value: Hex,
): ScopedPolicyFinalityV2GovernanceCall {
  return decode(SCOPED_POLICY_FINALITY_V2_GOVERNANCE_CALL_TUPLE, value);
}

export function normalizeScopedPolicyFinalityV2GovernanceAction(
  value: ScopedPolicyFinalityV2GovernanceAction,
): ScopedPolicyFinalityV2GovernanceAction {
  return normalized(SCOPED_POLICY_FINALITY_V2_GOVERNANCE_ACTION_TUPLE, value);
}

export function encodeScopedPolicyFinalityV2GovernanceAction(
  value: ScopedPolicyFinalityV2GovernanceAction,
): Hex {
  return encode(SCOPED_POLICY_FINALITY_V2_GOVERNANCE_ACTION_TUPLE, value);
}

export function decodeScopedPolicyFinalityV2GovernanceAction(
  value: Hex,
): ScopedPolicyFinalityV2GovernanceAction {
  return decode(SCOPED_POLICY_FINALITY_V2_GOVERNANCE_ACTION_TUPLE, value);
}

export const SCOPED_POLICY_FINALITY_V2_ARTIST_COMPONENT = id("ARTIST_SANCTION") as Hex;
export const SCOPED_POLICY_FINALITY_V2_COMPONENT_INTERFACE = "0x8004d4f5" as Hex;
export const SCOPED_POLICY_FINALITY_V2_INDEPENDENT_FAMILIES: readonly Hex[] = Object.freeze([
  "METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT", "MEDIA_MANIFEST", "SCRIPT_SOURCE",
  "DEPENDENCY_SOURCE", "COLLECTION_METADATA", "ENTROPY_COORDINATOR", "REFERENCE_RENDER",
].map((name) => id(name) as Hex).sort());

/** Supplied structural facts only; this does not establish current source admission. */
export function validateScopedPolicyFinalityV2Scope(
  value: ScopedPolicyFinalityV2Scope,
): ScopedPolicyFinalityV2Scope {
  const s = normalizeScopedPolicyFinalityV2Scope(value);
  if (s.collectionId === 0n || (s.scopeType === 1n
    ? s.tokenId === 0n || s.scopeId !== ZERO
    : (s.scopeType !== 2n && s.scopeType !== 3n) || s.tokenId !== 0n || s.scopeId === ZERO)) {
    throw new Error("Unsupported historical finality scope");
  }
  return s;
}

function components(
  values: readonly ScopedPolicyFinalityV2Component[],
  admitted: boolean,
): readonly ScopedPolicyFinalityV2Component[] {
  const rows = list(values, SCOPED_POLICY_FINALITY_V2_MAX_COMPONENTS)
    .map((v) => normalizeScopedPolicyFinalityV2Component(v as ScopedPolicyFinalityV2Component));
  if (admitted) {
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i]!;
      address(row.component, true);
      for (const h of [row.componentType, row.codeHash, row.moduleVersion, row.manifestHash, row.dataHash]) nonzero(h);
      if (row.interfaceId === "0x00000000" || (i !== 0 && row.componentType <= rows[i - 1]!.componentType)) {
        throw new Error("Finality components must have nonzero interfaces and strict family order");
      }
    }
  }
  return Object.freeze(rows);
}

export function validateScopedPolicyFinalityV2Statement(
  value: ScopedPolicyFinalityV2Statement,
): ScopedPolicyFinalityV2Statement {
  const s = normalizeScopedPolicyFinalityV2Statement(value);
  validateScopedPolicyFinalityV2Scope(s.scope);
  for (const h of [s.coreFactsHash, s.contentRoot, s.contentRootSchemaId, s.snapshotManifestHash, s.referenceRenderManifestHash]) nonzero(h);
  if (s.leafCount === 0n || (s.scope.scopeType === 1n && s.leafCount !== 1n)
    || s.entropyPolicy !== 1n || s.postFreezePolicy !== 1n || s.sanctionPolicy !== 1n) {
    throw new Error("Unsupported historical native finality statement");
  }
  const e = s.inputs;
  for (const h of [e.rootRecordHash, e.snapshotRecordHash, e.referenceRenderRecordHash,
    e.interviewEvidenceHash, e.rightsStatementRecordHash, e.workDescriptionRecordHash,
    e.renderCriticalEvidenceHash, e.bundleCoverageHash]) nonzero(h);
  if ((e.intentRecordHash === ZERO) === (e.intentWaiverRecordHash === ZERO)) {
    throw new Error("Exactly one Intent or waiver is required");
  }
  const rows = components(s.nonSanctionComponents, true);
  if (rows.length !== 9 || rows.some((row, i) => row.componentType !== SCOPED_POLICY_FINALITY_V2_INDEPENDENT_FAMILIES[i])) {
    throw new Error("The original nine independent component families are required");
  }
  return s;
}

export interface ScopedPolicyFinalityV2Manifest {
  readonly schemaId: Hex;
  readonly canonicalizationId: Hex;
  readonly chainId: bigint;
  readonly core: Address;
  readonly metadata: Address;
  readonly registry: Address;
  readonly statement: ScopedPolicyFinalityV2Statement;
}

const MANIFEST_TYPES = ["bytes32", "bytes32", "uint256", "address", "address", "address", SCOPED_POLICY_FINALITY_V2_STATEMENT_TUPLE];

export function scopedPolicyFinalityV2ManifestBytes(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  statement: ScopedPolicyFinalityV2Statement,
): Hex {
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates);
  const s = validateScopedPolicyFinalityV2Statement(statement);
  return bytes(coder.encode(MANIFEST_TYPES, [SCOPED_POLICY_FINALITY_V2_SCHEMA,
    SCOPED_POLICY_FINALITY_V2_CANONICALIZATION, c.chainId, c.core, c.metadata, c.registry, s]),
  undefined, SCOPED_POLICY_FINALITY_V2_MANIFEST_MAX_BYTES);
}

/** The original flat seven-field envelope, not a tuple-wrapped encoding. */
export function decodeScopedPolicyFinalityV2Manifest(value: Hex): ScopedPolicyFinalityV2Manifest {
  const raw = bytes(value, undefined, SCOPED_POLICY_FINALITY_V2_MANIFEST_MAX_BYTES);
  const v = coder.decode(MANIFEST_TYPES, raw);
  const result = Object.freeze({
    schemaId: bytes(v[0], 32), canonicalizationId: bytes(v[1], 32), chainId: uint(v[2]),
    core: address(v[3], true), metadata: address(v[4], true), registry: address(v[5], true),
    statement: normalized<ScopedPolicyFinalityV2Statement>(SCOPED_POLICY_FINALITY_V2_STATEMENT_TUPLE, v[6], true),
  });
  if (result.schemaId !== SCOPED_POLICY_FINALITY_V2_SCHEMA
    || result.canonicalizationId !== SCOPED_POLICY_FINALITY_V2_CANONICALIZATION || result.chainId === 0n
    || coder.encode(MANIFEST_TYPES, [result.schemaId, result.canonicalizationId, result.chainId,
      result.core, result.metadata, result.registry, result.statement]).toLowerCase() !== raw) {
    throw new Error("Noncanonical or unsupported scoped finality manifest");
  }
  validateScopedPolicyFinalityV2Statement(result.statement);
  return result;
}

function manifestFor(c: ScopedPolicyFinalityV2Coordinates, raw: Hex): ScopedPolicyFinalityV2Manifest {
  const m = decodeScopedPolicyFinalityV2Manifest(raw);
  if (m.chainId !== c.chainId || m.core !== c.core || m.metadata !== c.metadata || m.registry !== c.registry) {
    throw new Error("Manifest deployment does not match coordinates");
  }
  return m;
}

export function scopedPolicyFinalityV2ComponentsHash(
  values: readonly ScopedPolicyFinalityV2Component[],
): Hex {
  return hash(["bytes32", `${SCOPED_POLICY_FINALITY_V2_COMPONENT_TUPLE}[]`],
    [id("6529STREAM_FINALITY_COMPONENTS_V1"), components(values, false)]);
}

export function scopedPolicyFinalityV2ScopeKey(value: ScopedPolicyFinalityV2Scope): Hex {
  const s = normalizeScopedPolicyFinalityV2Scope(value);
  return hash(["uint8", "uint256", "uint256", "bytes32"], [s.scopeType, s.collectionId, s.tokenId, s.scopeId]);
}

export function scopedPolicyFinalityV2ScopeInputsHash(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  scope: ScopedPolicyFinalityV2Scope,
  inputs: ScopedPolicyFinalityV2Inputs,
): Hex {
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", SCOPED_POLICY_FINALITY_V2_SCOPE_TUPLE, SCOPED_POLICY_FINALITY_V2_INPUTS_TUPLE],
    [id("6529STREAM_FINALITY_SCOPE_INPUTS_V1"), c.chainId, c.core, c.metadata,
      normalizeScopedPolicyFinalityV2Scope(scope), normalizeScopedPolicyFinalityV2Inputs(inputs)]);
}

export function scopedPolicyFinalityV2ScopedCoreFactsHash(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  scope: ScopedPolicyFinalityV2Scope,
  facts: ScopedPolicyFinalityV2ScopedCoreFacts,
): Hex {
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates);
  const s = normalizeScopedPolicyFinalityV2Scope(scope);
  const f = normalizeScopedPolicyFinalityV2ScopedCoreFacts(facts);
  return hash(["bytes32", "uint256", "address", "uint8", "uint256", "uint256", "bytes32",
    "bool", "bool", "uint256", "uint8", "bool", "uint8", "uint8", "bytes32", "bytes32"],
  [id("6529STREAM_SCOPED_CORE_FINALITY_FACTS_V1"), c.chainId, c.core, s.scopeType, s.collectionId,
    s.tokenId, s.scopeId, f.scopeExists, f.tokenMappingExists, f.collectionSerial, f.tokenLifecycle,
    f.burned, f.collectionStatus, f.collectionSupplyMode, f.collectionConfigHash, f.scopeManifestHash]);
}

export function scopedPolicyFinalityV2RecordHash(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  scope: ScopedPolicyFinalityV2Scope,
  coreFactsHash: Hex,
  componentsHash: Hex,
  manifest: ScopedPolicyFinalityV2ManifestRef,
): Hex {
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates);
  const s = validateScopedPolicyFinalityV2Scope(scope);
  const m = normalizeScopedPolicyFinalityV2ManifestRef(manifest);
  return hash(["bytes32", "uint256", "address", "uint8", "uint256", "uint256", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
  [id("6529STREAM_SCOPED_FINALITY_V1"), c.chainId, c.core, s.scopeType, s.collectionId, s.tokenId,
    s.scopeId, bytes(coreFactsHash, 32), bytes(componentsHash, 32), m.uriHash, m.contentHash, m.schemaId, m.canonicalizationHash]);
}

export function scopedPolicyFinalityV2SanctionSubjectHash(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  scope: ScopedPolicyFinalityV2Scope,
  coreFactsHash: Hex,
  nonSanctionComponentsHash: Hex,
  manifest: ScopedPolicyFinalityV2ManifestRef,
): Hex {
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates);
  const s = validateScopedPolicyFinalityV2Scope(scope);
  const m = normalizeScopedPolicyFinalityV2ManifestRef(manifest);
  return hash(["bytes32", "uint256", "address", "address", "uint8", "uint256", "uint256", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
  [id("6529STREAM_ARTIST_SANCTION_SUBJECT_V1"), c.chainId, c.core, c.registry, s.scopeType,
    s.collectionId, s.tokenId, s.scopeId, bytes(coreFactsHash, 32), bytes(nonSanctionComponentsHash, 32),
    m.uriHash, m.contentHash, m.schemaId, m.canonicalizationHash]);
}

export function scopedPolicyFinalityV2ArchiveEvidenceHash(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  proof: ScopedPolicyFinalityV2ArchiveProof,
): Hex {
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", "address", SCOPED_POLICY_FINALITY_V2_ARCHIVE_PROOF_TUPLE],
    [id("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1"), c.chainId, c.core, c.registry,
      c.artifactCoverage, normalizeScopedPolicyFinalityV2ArchiveProof(proof)]);
}

export function scopedPolicyFinalityV2ExecutionContext(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  scope: ScopedPolicyFinalityV2Scope,
  coreFactsHash: Hex,
  componentsHash: Hex,
  inputsHash: Hex,
  finalityRecordHash: Hex,
  archiveEvidenceHash: Hex,
): ScopedPolicyFinalityV2ExecutionContext {
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates);
  const s = validateScopedPolicyFinalityV2Scope(scope);
  const scopeHash = hash(["bytes32", "uint256", "address", SCOPED_POLICY_FINALITY_V2_SCOPE_TUPLE],
    [id("6529STREAM_FINALITY_EXECUTION_SCOPE_V1"), c.chainId, c.registry, s]);
  return normalizeScopedPolicyFinalityV2ExecutionContext({
    scopeHash, coreFactsHash, componentsHash, inputsHash, finalityRecordHash,
    oldValueHash: hash(["bytes32", "bytes32", "bool", "bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_FINALITY_EXECUTION_OLD_V1"), scopeHash, false,
        bytes(coreFactsHash, 32), bytes(componentsHash, 32), bytes(inputsHash, 32)]),
    newValueHash: hash(["bytes32", "bytes32", "bool", "bytes32", "bytes32"],
      [id("6529STREAM_FINALITY_EXECUTION_ARCHIVED_NEW_V1"), scopeHash, true,
        bytes(finalityRecordHash, 32), bytes(archiveEvidenceHash, 32)]),
  });
}

/** Exact original provider commitments; supplied configuration is not a deployment proof. */
export function scopedPolicyFinalityV2ProviderConfigurationHash(
  provider: Address,
  original: ScopedPolicyFinalityV2NativeConfiguration,
  binding: ScopedPolicyFinalityV2FactoryBinding,
): Hex {
  const c = normalizeScopedPolicyFinalityV2NativeConfiguration(original);
  const b = normalizeScopedPolicyFinalityV2FactoryBinding(binding);
  return hash(["bytes32", "uint256", "address", SCOPED_POLICY_FINALITY_V2_NATIVE_CONFIGURATION_TUPLE,
    "address", "bytes32", "bytes32", "bytes32", "uint256"],
  [id("6529STREAM_SCOPED_POLICY_PROVIDER_CONFIGURATION_V2"), c.chainId, address(provider, true), c,
    b.factory, b.factoryCodeHash, b.recipeHash, b.sourceFactoryDependenciesHash, b.graphGas]);
}

export function scopedPolicyFinalityV2SourceConfigurationHash(
  provider: Address,
  configuration: ScopedPolicyFinalityV2SourceConfiguration,
  binding: ScopedPolicyFinalityV2FactoryBinding,
): Hex {
  const c = normalizeScopedPolicyFinalityV2SourceConfiguration(configuration);
  const b = normalizeScopedPolicyFinalityV2FactoryBinding(binding);
  const original = hash(["bytes32", "uint256", "address", SCOPED_POLICY_FINALITY_V2_SOURCE_CONFIGURATION_TUPLE],
    [id("6529STREAM_FINALITY_SOURCE_CONFIGURATION_V1"), c.chainId, address(provider, true), c]);
  return hash(["bytes32", "bytes32", SCOPED_POLICY_FINALITY_V2_FACTORY_BINDING_TUPLE],
    [id("6529STREAM_FINALITY_SOURCE_CONFIGURATION_SCOPED_POLICY_V2"), original, b]);
}

export function validateScopedPolicyFinalityV2NativeConfiguration(
  value: ScopedPolicyFinalityV2NativeConfiguration,
): ScopedPolicyFinalityV2NativeConfiguration {
  const c = normalizeScopedPolicyFinalityV2NativeConfiguration(value);
  if (c.chainId === 0n || c.readGas < 50000n || c.componentSourceGas < c.readGas
    || c.componentSourceGas > 0xffffffffn
    || c.sourceGas <= c.componentSourceGas + c.componentSourceGas / 63n + 100000n) {
    throw new Error("Invalid original native provider gas configuration");
  }
  nonzero(c.inventoryDependencyHash);
  c.targets.forEach(target => address(target, true));
  c.codeHashes.forEach(nonzero);
  return c;
}

export function validateScopedPolicyFinalityV2Sources(
  value: ScopedPolicyFinalityV2Sources,
  expectedScope: ScopedPolicyFinalityV2Scope,
): ScopedPolicyFinalityV2Sources {
  const s = normalizeScopedPolicyFinalityV2Sources(value);
  const scope = validateScopedPolicyFinalityV2Scope(expectedScope);
  if (!same(s.scope, scope) || s.profile.profileHash !== SCOPED_POLICY_FINALITY_V2_PROFILE) {
    throw new Error("Unsupported or mismatched historical scoped policy profile");
  }
  for (const target of [s.profile.referenceRender, s.profile.snapshots, s.profile.entropyFactory]) address(target, true);
  for (const h of [s.profile.referenceRenderCodeHash, s.profile.snapshotsCodeHash,
    s.profile.entropyFactoryCodeHash, s.profile.configurationHash]) nonzero(h);
  return s;
}

export interface ScopedPolicyFinalityV2FinalizationInput {
  readonly manifestBytes: Hex;
  readonly manifestURI: string;
  readonly components: readonly ScopedPolicyFinalityV2Component[];
  readonly proof: ScopedPolicyFinalityV2ArchiveProof;
}

/** The target call is Executor-only. It is not a wallet-authorized finalization. */
export interface ScopedPolicyFinalityV2Finalization {
  readonly coordinates: ScopedPolicyFinalityV2Coordinates;
  readonly scope: ScopedPolicyFinalityV2Scope;
  readonly statement: ScopedPolicyFinalityV2Statement;
  readonly manifestBytes: Hex;
  readonly components: readonly ScopedPolicyFinalityV2Component[];
  readonly manifest: ScopedPolicyFinalityV2ManifestRef;
  readonly proof: ScopedPolicyFinalityV2ArchiveProof;
  readonly execution: ScopedPolicyFinalityV2ExecutionContext;
  readonly targetCall: UnsignedCall;
  readonly contextCall: UnsignedCall;
  readonly governanceCall: ScopedPolicyFinalityV2GovernanceCall;
  readonly factsVerified: false;
}

function completeComponents(
  c: ScopedPolicyFinalityV2Coordinates,
  s: ScopedPolicyFinalityV2Statement,
  values: readonly ScopedPolicyFinalityV2Component[],
  sanctionRecordHash?: Hex,
): readonly ScopedPolicyFinalityV2Component[] {
  const rows = components(values, true);
  const artist = rows.filter(row => row.componentType === SCOPED_POLICY_FINALITY_V2_ARTIST_COMPONENT);
  const independent = rows.filter(row => row.componentType !== SCOPED_POLICY_FINALITY_V2_ARTIST_COMPONENT);
  if (rows.length !== 10 || artist.length !== 1 || !same(independent, s.nonSanctionComponents)
    || artist[0]!.component !== c.artist || artist[0]!.interfaceId !== SCOPED_POLICY_FINALITY_V2_COMPONENT_INTERFACE
    || (sanctionRecordHash !== undefined && artist[0]!.dataHash !== sanctionRecordHash)) {
    throw new Error("Full components must retain the nine manifest rows and the actual Artist sanction");
  }
  return rows;
}

function call(iface: Interface, to: Address, method: string, args: readonly unknown[], maximum = SCOPED_POLICY_FINALITY_V2_MAX_BYTES): UnsignedCall {
  return Object.freeze({ to, data: bytes(iface.encodeFunctionData(method, args), undefined, maximum), value: 0n });
}

export function prepareScopedPolicyFinalityV2Finalization(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  input: ScopedPolicyFinalityV2FinalizationInput,
): ScopedPolicyFinalityV2Finalization {
  exact(input, ["manifestBytes", "manifestURI", "components", "proof"], "Finalization input");
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates);
  const manifestBytes = bytes(input.manifestBytes, undefined, SCOPED_POLICY_FINALITY_V2_MANIFEST_MAX_BYTES);
  const s = manifestFor(c, manifestBytes).statement;
  const proof = normalizeScopedPolicyFinalityV2ArchiveProof(input.proof);
  Object.values(proof).forEach(nonzero);
  const rows = completeComponents(c, s, input.components, proof.sanctionRecordHash);
  const manifest = normalizeScopedPolicyFinalityV2ManifestRef({
    uri: text(input.manifestURI), uriHash: keccak256(toUtf8Bytes(input.manifestURI)) as Hex,
    contentHash: keccak256(manifestBytes) as Hex, schemaId: SCOPED_POLICY_FINALITY_V2_SCHEMA,
    canonicalizationHash: SCOPED_POLICY_FINALITY_V2_CANONICALIZATION,
  });
  const componentsHash = scopedPolicyFinalityV2ComponentsHash(rows);
  const record = scopedPolicyFinalityV2RecordHash(c, s.scope, s.coreFactsHash, componentsHash, manifest);
  const execution = scopedPolicyFinalityV2ExecutionContext(c, s.scope, s.coreFactsHash, componentsHash,
    scopedPolicyFinalityV2ScopeInputsHash(c, s.scope, s.inputs), record, scopedPolicyFinalityV2ArchiveEvidenceHash(c, proof));
  const args = [s.scope, rows, record, manifest, proof];
  const targetCall = call(registryInterface, c.registry, "finalizeArtworkScopeWithArchive", args, SCOPED_POLICY_FINALITY_V2_REGISTRY_MAX_BYTES);
  const contextCall = call(registryInterface, c.registry, "finalityExecutionContextWithArchive", args, SCOPED_POLICY_FINALITY_V2_REGISTRY_MAX_BYTES);
  const governanceCall = normalizeScopedPolicyFinalityV2GovernanceCall({
    target: c.registry, value: 0n, selector: targetCall.data.slice(0, 10) as Hex,
    callDataHash: keccak256(targetCall.data) as Hex, scopeHash: execution.scopeHash,
    oldValueHash: execution.oldValueHash, newValueHash: execution.newValueHash,
  });
  return Object.freeze({ coordinates: c, scope: s.scope, statement: s, manifestBytes,
    components: rows, manifest, proof, execution, targetCall, contextCall, governanceCall, factsVerified: false });
}

export function normalizeScopedPolicyFinalityV2Finalization(
  value: ScopedPolicyFinalityV2Finalization,
): ScopedPolicyFinalityV2Finalization {
  exact(value, ["coordinates", "scope", "statement", "manifestBytes", "components", "manifest", "proof",
    "execution", "targetCall", "contextCall", "governanceCall", "factsVerified"], "Finalization");
  const expected = prepareScopedPolicyFinalityV2Finalization(value.coordinates, {
    manifestBytes: value.manifestBytes, manifestURI: value.manifest.uri, components: value.components, proof: value.proof,
  });
  if (!same(value, expected)) throw new Error("Finalization reconstruction mismatch");
  return expected;
}

export interface ScopedPolicyFinalityV2HistoryInput {
  readonly manifestBytes: Hex;
  readonly record: ScopedPolicyFinalityV2ScopedRecord;
  readonly components: readonly ScopedPolicyFinalityV2Component[];
}

/** Authenticates supplied retained bytes; does not establish storage provenance or current liveness. */
export function authenticateScopedPolicyFinalityV2History(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  input: ScopedPolicyFinalityV2HistoryInput,
) {
  exact(input, ["manifestBytes", "record", "components"], "History");
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates);
  const manifestBytes = bytes(input.manifestBytes, undefined, SCOPED_POLICY_FINALITY_V2_MANIFEST_MAX_BYTES);
  const statement = manifestFor(c, manifestBytes).statement;
  const record = normalizeScopedPolicyFinalityV2ScopedRecord(input.record);
  const rows = completeComponents(c, statement, input.components);
  const manifest = normalizeScopedPolicyFinalityV2ManifestRef({
    uri: record.finalityManifestURI, uriHash: keccak256(toUtf8Bytes(record.finalityManifestURI)) as Hex,
    contentHash: keccak256(manifestBytes) as Hex, schemaId: SCOPED_POLICY_FINALITY_V2_SCHEMA,
    canonicalizationHash: SCOPED_POLICY_FINALITY_V2_CANONICALIZATION,
  });
  const componentsHash = scopedPolicyFinalityV2ComponentsHash(rows);
  const expectedRecord = scopedPolicyFinalityV2RecordHash(c, statement.scope, statement.coreFactsHash, componentsHash, manifest);
  if (!record.finalized || !same(record.scope, statement.scope) || record.manifestPointer !== c.registry
    || record.componentsHash !== componentsHash || record.manifestURIHash !== manifest.uriHash
    || record.manifestContentHash !== manifest.contentHash || record.finalityRecordHash !== expectedRecord) {
    throw new Error("Retained finality record does not match its canonical manifest and components");
  }
  return Object.freeze({ coordinates: c, manifestBytes, statement, record, components: rows, manifest, factsVerified: false as const });
}

export interface ScopedPolicyFinalityV2GovernanceWindow {
  readonly notBefore: bigint;
  readonly expiresAfter: bigint;
  readonly reasonHash: Hex;
  readonly reasonURI: string;
  readonly manifestHash: Hex;
}

export function normalizeScopedPolicyFinalityV2GovernanceWindow(
  value: ScopedPolicyFinalityV2GovernanceWindow,
): ScopedPolicyFinalityV2GovernanceWindow {
  exact(value, ["notBefore", "expiresAfter", "reasonHash", "reasonURI", "manifestHash"], "Governance window");
  const w = Object.freeze({ notBefore: uint(value.notBefore, 64), expiresAfter: uint(value.expiresAfter, 64),
    reasonHash: bytes(value.reasonHash, 32), reasonURI: text(value.reasonURI), manifestHash: bytes(value.manifestHash, 32) });
  if (w.expiresAfter < w.notBefore + 7n * 86400n) throw new Error("Original class2 window must be open for at least seven days");
  return w;
}

/** Original scheduling predicate, evaluated against a supplied scheduling timestamp. */
export function assertScopedPolicyFinalityV2GovernanceWindow(
  value: ScopedPolicyFinalityV2GovernanceWindow,
  schedulingTimestamp: bigint,
): void {
  const w = normalizeScopedPolicyFinalityV2GovernanceWindow(value);
  const now = uint(schedulingTimestamp, 64), year = 365n * 86400n;
  if (now > (1n << 64n) - 1n - year || w.notBefore < now + 72n * 3600n || w.expiresAfter > now + year) {
    throw new Error("Original class2 scheduling window is invalid at the supplied timestamp");
  }
}

export interface ScopedPolicyFinalityV2GovernanceBatch {
  readonly plan: ScopedPolicyFinalityV2Finalization;
  readonly nonce: bigint;
  readonly window: ScopedPolicyFinalityV2GovernanceWindow;
  readonly calls: readonly ScopedPolicyFinalityV2GovernanceCall[];
  readonly callDatas: readonly Hex[];
  readonly callsHash: Hex;
  readonly scopeHash: Hex;
  readonly oldValueHash: Hex;
  readonly newValueHash: Hex;
  readonly actionId: Hex;
  readonly publicationKey: Hex;
  readonly publicationCall: UnsignedCall;
  readonly scheduleCall: UnsignedCall;
  readonly executionCall: UnsignedCall;
}

export const SCOPED_POLICY_FINALITY_V2_ACTION_IDENTITY_TUPLE = "(uint8 actionClass,bytes32 callsHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint256 nonce,uint64 notBefore,uint64 expiresAfter,bytes32 reasonHash,bytes32 manifestHash)";

export function scopedPolicyFinalityV2GovernanceBatch(
  inputPlan: ScopedPolicyFinalityV2Finalization,
  nonce: bigint,
  window: ScopedPolicyFinalityV2GovernanceWindow,
): ScopedPolicyFinalityV2GovernanceBatch {
  const plan = normalizeScopedPolicyFinalityV2Finalization(inputPlan);
  const n = uint(nonce), w = normalizeScopedPolicyFinalityV2GovernanceWindow(window);
  const calls = Object.freeze([plan.governanceCall]), callDatas = Object.freeze([plan.targetCall.data]);
  const callsHash = hash(["bytes32", `${SCOPED_POLICY_FINALITY_V2_GOVERNANCE_CALL_TUPLE}[]`],
    ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain: Hex, field: "scopeHash" | "oldValueHash" | "newValueHash") =>
    hash(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, calls.map(row => row[field])]);
  const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash");
  const oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash");
  const newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
  const actionId = hash(["bytes32", "uint256", "address", SCOPED_POLICY_FINALITY_V2_ACTION_IDENTITY_TUPLE],
    ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", plan.coordinates.chainId,
      plan.coordinates.executor, { actionClass: 2n, callsHash, scopeHash, oldValueHash, newValueHash,
        nonce: n, notBefore: w.notBefore, expiresAfter: w.expiresAfter, reasonHash: w.reasonHash, manifestHash: w.manifestHash }]);
  const publicationKey = keccak256(plan.governanceCall.callDataHash) as Hex;
  const target = plan.coordinates.executor;
  return Object.freeze({ plan, nonce: n, window: w, calls, callDatas, callsHash, scopeHash, oldValueHash, newValueHash,
    actionId, publicationKey,
    publicationCall: call(executorInterface, target, "publishGovernanceCallData", [callDatas]),
    scheduleCall: call(executorInterface, target, "scheduleGovernanceBatch", [2n, calls, scopeHash, oldValueHash,
      newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash]),
    executionCall: call(executorInterface, target, "executeGovernanceBatch", [actionId, calls, callDatas]),
  });
}

export function normalizeScopedPolicyFinalityV2GovernanceBatch(
  value: ScopedPolicyFinalityV2GovernanceBatch,
): ScopedPolicyFinalityV2GovernanceBatch {
  exact(value, ["plan", "nonce", "window", "calls", "callDatas", "callsHash", "scopeHash", "oldValueHash",
    "newValueHash", "actionId", "publicationKey", "publicationCall", "scheduleCall", "executionCall"], "Governance batch");
  const expected = scopedPolicyFinalityV2GovernanceBatch(value.plan, value.nonce, value.window);
  if (!same(expected, value)) throw new Error("Governance batch reconstruction mismatch");
  return expected;
}

export type ScopedPolicyFinalityV2Request =
  | { readonly kind: "stageFinalityManifest"; readonly manifestBytes: Hex }
  | {
    readonly kind: "publishGovernanceCallData" | "scheduleGovernanceBatch" | "executeGovernanceBatch";
    readonly batch: ScopedPolicyFinalityV2GovernanceBatch;
  };

export interface ScopedPolicyFinalityV2Call {
  readonly coordinates: ScopedPolicyFinalityV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyFinalityV2Request;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function prepareScopedPolicyFinalityV2Call(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  caller: Address,
  request: ScopedPolicyFinalityV2Request,
): ScopedPolicyFinalityV2Call {
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates), actor = address(caller, true);
  let r: ScopedPolicyFinalityV2Request, outer: UnsignedCall;
  switch (request.kind) {
    case "stageFinalityManifest": {
      exact(request, ["kind", "manifestBytes"], "Manifest staging");
      const manifestBytes = bytes(request.manifestBytes, undefined, SCOPED_POLICY_FINALITY_V2_MANIFEST_MAX_BYTES);
      manifestFor(c, manifestBytes);
      r = Object.freeze({ kind: request.kind, manifestBytes });
      outer = call(registryInterface, c.registry, request.kind, [manifestBytes]);
      break;
    }
    case "publishGovernanceCallData":
    case "scheduleGovernanceBatch":
    case "executeGovernanceBatch": {
      exact(request, ["kind", "batch"], "Governance stage");
      const batch = normalizeScopedPolicyFinalityV2GovernanceBatch(request.batch);
      if (!same(batch.plan.coordinates, c)) throw new Error("Governance deployment mismatch");
      r = Object.freeze({ kind: request.kind, batch });
      outer = request.kind === "publishGovernanceCallData" ? batch.publicationCall
        : request.kind === "scheduleGovernanceBatch" ? batch.scheduleCall : batch.executionCall;
      break;
    }
    default: throw new Error("Unsupported outer finality wallet operation");
  }
  return Object.freeze({ coordinates: c, caller: actor, request: r, call: outer, factsVerified: false });
}

export function normalizeScopedPolicyFinalityV2Call(value: ScopedPolicyFinalityV2Call): ScopedPolicyFinalityV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared outer call");
  const expected = prepareScopedPolicyFinalityV2Call(value.coordinates, value.caller, value.request);
  if (!same(expected, value)) throw new Error("Prepared outer call reconstruction mismatch");
  return expected;
}

export interface ScopedPolicyFinalityV2ReadTargets {
  readonly provider: Address;
  readonly discovery: Address;
}

export type ScopedPolicyFinalityV2ReadRequest =
  | { readonly host: "registry"; readonly kind: "artworkScopeFinalityRecord" | "finalityComponentCountForScope" | "verifyArtworkScopeFinality" | "artworkFreezeMode" | "computeScopedCoreFactsHash" | "contentRootScopeSubject"; readonly scope: ScopedPolicyFinalityV2Scope }
  | { readonly host: "registry"; readonly kind: "finalityComponentsForScope" | "verifyArtworkScopeFinalityRange"; readonly scope: ScopedPolicyFinalityV2Scope; readonly start: bigint; readonly limit: bigint }
  | { readonly host: "registry"; readonly kind: "finalityManifestBytes" | "finalityManifestStored" | "finalityExecutionWitness" | "finalitySanctionArchiveWitness"; readonly hash: Hex }
  | { readonly host: "registry"; readonly kind: "finalityExecutionContextWithArchive"; readonly plan: ScopedPolicyFinalityV2Finalization }
  | { readonly host: "registry"; readonly kind: "prepareSanction" | "prepareSanctionWithReview"; readonly manifestBytes: Hex; readonly manifestURI: string }
  | { readonly host: "provider"; readonly kind: "finalitySourcesForScope" | "inputManifestBytes" | "scopedPolicySnapshotHost" | "scopedPolicySnapshotCodeHash" | "scopedPolicySnapshotValidationGas"; readonly scope: ScopedPolicyFinalityV2Scope }
  | { readonly host: "provider"; readonly kind: "requireFinalityScopeInputs" | "requireSanctionReviewFacts"; readonly scope: ScopedPolicyFinalityV2Scope; readonly manifestHash: Hex }
  | { readonly host: "provider"; readonly kind: "requirePreparedFinalityScopeInputs" | "requirePreparedFinalityScopeInputsAndReview"; readonly plan: ScopedPolicyFinalityV2Finalization }
  | { readonly host: "provider"; readonly kind: "finalitySourceProfile"; readonly index: bigint }
  | { readonly host: "provider"; readonly kind: "nativeConfiguration" | "scopedConfiguration" | "policyConfiguration" | "scopedPolicyPublicationBinding" | "finalitySourceConfigurationHash" | "scopedPolicySnapshotProfile" }
  | { readonly host: "discovery"; readonly kind: "nonSanctionDiscoveryFacts" | "finalityComponentCountForScope" | "finalityDiscoveryHashForScope"; readonly scope: ScopedPolicyFinalityV2Scope }
  | { readonly host: "discovery"; readonly kind: "nonSanctionComponentAt" | "finalityComponentAtForScope"; readonly scope: ScopedPolicyFinalityV2Scope; readonly index: bigint }
  | { readonly host: "discovery"; readonly kind: "requireCurrentRoutes"; readonly scope: ScopedPolicyFinalityV2Scope; readonly includeSanction: boolean }
  | { readonly host: "discovery"; readonly kind: "configuration" | "sourceConfigurationHash" }
  | { readonly host: "executor"; readonly kind: "governanceAction" | "governanceActionFacts" | "scheduledCallData"; readonly actionId: Hex }
  | { readonly host: "executor"; readonly kind: "publishedCallData"; readonly publicationKey: Hex }
  | { readonly host: "executor"; readonly kind: "currentAction" | "governanceNonce" | "roleRegistry" | "governanceActionPolicyState" };

export interface ScopedPolicyFinalityV2ReadCall {
  readonly coordinates: ScopedPolicyFinalityV2Coordinates;
  readonly targets: ScopedPolicyFinalityV2ReadTargets;
  readonly caller: Address;
  readonly request: ScopedPolicyFinalityV2ReadRequest;
  readonly call: UnsignedCall;
  readonly callerBoundary: "public-read" | "registry-only-read";
  readonly factsVerified: false;
}

export function prepareScopedPolicyFinalityV2Read(
  coordinates: ScopedPolicyFinalityV2Coordinates,
  targets: ScopedPolicyFinalityV2ReadTargets,
  caller: Address,
  request: ScopedPolicyFinalityV2ReadRequest,
): ScopedPolicyFinalityV2ReadCall {
  const c = normalizeScopedPolicyFinalityV2Coordinates(coordinates);
  exact(targets, ["provider", "discovery"], "Read targets");
  const t = Object.freeze({ provider: address(targets.provider, true), discovery: address(targets.discovery, true) });
  const actor = address(caller);
  let r: ScopedPolicyFinalityV2ReadRequest, args: readonly unknown[] = [];
  let callerBoundary: ScopedPolicyFinalityV2ReadCall["callerBoundary"] = "public-read";
  const method = request.kind, host = request.host;
  const simpleScope = {
    registry: ["artworkScopeFinalityRecord", "finalityComponentCountForScope", "verifyArtworkScopeFinality", "artworkFreezeMode", "computeScopedCoreFactsHash", "contentRootScopeSubject"],
    provider: ["finalitySourcesForScope", "inputManifestBytes", "scopedPolicySnapshotHost", "scopedPolicySnapshotCodeHash", "scopedPolicySnapshotValidationGas"],
    discovery: ["nonSanctionDiscoveryFacts", "finalityComponentCountForScope", "finalityDiscoveryHashForScope"],
    executor: [],
  } as const;
  const simpleEmpty = {
    registry: [],
    provider: ["nativeConfiguration", "scopedConfiguration", "policyConfiguration", "scopedPolicyPublicationBinding", "finalitySourceConfigurationHash", "scopedPolicySnapshotProfile"],
    discovery: ["configuration", "sourceConfigurationHash"],
    executor: ["currentAction", "governanceNonce", "roleRegistry", "governanceActionPolicyState"],
  } as const;
  if (!Object.hasOwn(simpleScope, host)) throw new Error("Unknown read host");
  if ((simpleScope[host] as readonly string[]).includes(method)) {
    exact(request, ["host", "kind", "scope"], "Scope read");
    if (!("scope" in request)) throw new Error("Missing read scope");
    const scope = validateScopedPolicyFinalityV2Scope(request.scope);
    r = Object.freeze({ host, kind: method, scope }) as ScopedPolicyFinalityV2ReadRequest;
    args = [scope];
  } else if ((simpleEmpty[host] as readonly string[]).includes(method)) {
    exact(request, ["host", "kind"], "Configuration read");
    r = Object.freeze({ host, kind: method }) as ScopedPolicyFinalityV2ReadRequest;
  } else if (host === "registry" && (method === "finalityComponentsForScope" || method === "verifyArtworkScopeFinalityRange")) {
    exact(request, ["host", "kind", "scope", "start", "limit"], "Range read");
    const scope = validateScopedPolicyFinalityV2Scope(request.scope), start = uint(request.start), limit = uint(request.limit);
    if (limit > 32n) throw new Error("Client component range bound exceeded");
    r = Object.freeze({ host, kind: method, scope, start, limit }); args = [scope, start, limit];
  } else if (host === "registry" && ["finalityManifestBytes", "finalityManifestStored", "finalityExecutionWitness", "finalitySanctionArchiveWitness"].includes(method)) {
    exact(request, ["host", "kind", "hash"], "Historical read");
    if (!("hash" in request)) throw new Error("Missing historical hash");
    const h = bytes(request.hash, 32);
    r = Object.freeze({ host, kind: method, hash: h }) as ScopedPolicyFinalityV2ReadRequest; args = [h];
  } else if ((host === "registry" && method === "finalityExecutionContextWithArchive")
    || (host === "provider" && (method === "requirePreparedFinalityScopeInputs" || method === "requirePreparedFinalityScopeInputsAndReview"))) {
    exact(request, ["host", "kind", "plan"], "Prepared context read");
    const plan = normalizeScopedPolicyFinalityV2Finalization(request.plan);
    if (!same(plan.coordinates, c)) throw new Error("Read plan deployment mismatch");
    r = Object.freeze({ host, kind: method, plan }) as ScopedPolicyFinalityV2ReadRequest;
    if (host === "registry") args = [plan.scope, plan.components, plan.execution.finalityRecordHash, plan.manifest, plan.proof];
    else {
      if (actor !== c.registry) throw new Error("Prepared provider read requires original Registry caller");
      callerBoundary = "registry-only-read";
      args = [plan.scope, plan.manifest.contentHash, plan.components];
    }
  } else if (host === "registry" && (method === "prepareSanction" || method === "prepareSanctionWithReview")) {
    exact(request, ["host", "kind", "manifestBytes", "manifestURI"], "Sanction preparation read");
    const raw = bytes(request.manifestBytes, undefined, SCOPED_POLICY_FINALITY_V2_MANIFEST_MAX_BYTES);
    const s = manifestFor(c, raw).statement, uri = text(request.manifestURI);
    const m = normalizeScopedPolicyFinalityV2ManifestRef({ uri, uriHash: keccak256(toUtf8Bytes(uri)) as Hex,
      contentHash: keccak256(raw) as Hex, schemaId: SCOPED_POLICY_FINALITY_V2_SCHEMA, canonicalizationHash: SCOPED_POLICY_FINALITY_V2_CANONICALIZATION });
    r = Object.freeze({ host, kind: method, manifestBytes: raw, manifestURI: uri }); args = [s.scope, s.nonSanctionComponents, m];
  } else if (host === "provider" && (method === "requireFinalityScopeInputs" || method === "requireSanctionReviewFacts")) {
    exact(request, ["host", "kind", "scope", "manifestHash"], "Manifest source read");
    const scope = validateScopedPolicyFinalityV2Scope(request.scope), manifestHash = bytes(request.manifestHash, 32);
    r = Object.freeze({ host, kind: method, scope, manifestHash }); args = [scope, manifestHash];
  } else if (host === "provider" && method === "finalitySourceProfile") {
    exact(request, ["host", "kind", "index"], "Profile read");
    const index = uint(request.index, 8);
    if (index > 2n) throw new Error("Original source catalogue has three entries");
    r = Object.freeze({ host, kind: method, index }); args = [index];
  } else if (host === "discovery" && (method === "nonSanctionComponentAt" || method === "finalityComponentAtForScope")) {
    exact(request, ["host", "kind", "scope", "index"], "Component read");
    const scope = validateScopedPolicyFinalityV2Scope(request.scope), index = uint(request.index);
    r = Object.freeze({ host, kind: method, scope, index }); args = [scope, index];
  } else if (host === "discovery" && method === "requireCurrentRoutes") {
    exact(request, ["host", "kind", "scope", "includeSanction"], "Current route read");
    const scope = validateScopedPolicyFinalityV2Scope(request.scope), includeSanction = request.includeSanction;
    if (typeof includeSanction !== "boolean") throw new Error("Invalid includeSanction boolean");
    r = Object.freeze({ host, kind: method, scope, includeSanction }); args = [scope, includeSanction];
  } else if (host === "executor" && (method === "governanceAction" || method === "governanceActionFacts" || method === "scheduledCallData")) {
    exact(request, ["host", "kind", "actionId"], "Action read");
    const actionId = bytes(request.actionId, 32);
    r = Object.freeze({ host, kind: method, actionId }); args = [actionId];
  } else if (host === "executor" && method === "publishedCallData") {
    exact(request, ["host", "kind", "publicationKey"], "Publication read");
    const publicationKey = bytes(request.publicationKey, 32);
    r = Object.freeze({ host, kind: method, publicationKey }); args = [publicationKey];
  } else throw new Error("Unsupported original scoped finality read");
  const target = host === "registry" ? c.registry : host === "executor" ? c.executor : t[host];
  return Object.freeze({ coordinates: c, targets: t, caller: actor, request: r,
    call: call(scopedPolicyFinalityV2Interface(host), target, method, args), callerBoundary, factsVerified: false });
}

export function normalizeScopedPolicyFinalityV2Read(value: ScopedPolicyFinalityV2ReadCall): ScopedPolicyFinalityV2ReadCall {
  exact(value, ["coordinates", "targets", "caller", "request", "call", "callerBoundary", "factsVerified"], "Prepared read");
  const expected = prepareScopedPolicyFinalityV2Read(value.coordinates, value.targets, value.caller, value.request);
  if (!same(expected, value)) throw new Error("Prepared read reconstruction mismatch");
  return expected;
}
