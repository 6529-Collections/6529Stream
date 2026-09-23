// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamMintManager } from "../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    StreamCollectionManifestTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    GovernanceActionPolicyEntry
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    ModuleRegistryStatus
} from "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    StreamSystemManifestUpdate
} from "../../smart-contracts/interfaces/stream/governance/IStreamSystemManifest.sol";
import {
    IStreamRevenueResolver
} from "../../smart-contracts/interfaces/stream/revenue/IStreamRevenueResolver.sol";
import {
    IStreamDynamicPrimaryTemplates
} from "../../smart-contracts/interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";

// These test-only views name the exact production functions used as selectors by
// StreamCurrentTestSetupPlans. They add no implementation, deployment, or dispatch.
// Structs and enums retain their canonical interface owners; Targets still encodes
// the original seventeen addresses in the original field order.

interface IStreamSetupPlansMintManager {
    function configurePhase(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintManager.MintPhaseConfig calldata config,
        IStreamMintManager.MintGateConfig calldata gateConfig,
        bytes32[] calldata counterIds,
        IStreamMintManager.MintCounterConfig[] calldata counterConfigs
    ) external returns (bytes32 policyHash);

    function freezePhase(uint256 collectionId, bytes32 phaseId) external;

    function raiseGasParameter(bytes32 parameterId, uint256 newValue) external;

    function setPhaseExecutor(
        uint256 collectionId,
        bytes32 phaseId,
        address executor,
        bool allowed
    ) external;

    function setPhaseExecutorWithGrace(
        uint256 collectionId,
        bytes32 phaseId,
        address executor,
        bool allowed,
        uint64 graceUntil
    ) external;

    function setPhasePaused(uint256 collectionId, bytes32 phaseId, bool paused) external;
}

interface IStreamSetupPlansMintLedger {
    function importPhaseFreezes(bytes32 root, uint256 maxCount) external;

    function setLedgerWriter(address writer, bool allowed) external;
}

interface IStreamSetupPlansFixedPriceSaleAdapter {
    function setPaused(bool paused_) external;

    function setPlatformSigner(address signer) external;
}

interface IStreamSetupPlansEnglishAuctionHouse {
    function setPaused(bool paused_) external;

    function setPlatformSigner(address signer) external;
}

interface IStreamSetupPlansEntropyCoordinator {
    function activateEntropyProvider(address provider, string calldata reasonURI) external;

    function deprecateEntropyProvider(address provider, string calldata reasonURI) external;

    function markRequestFailed(bytes32 requestKey) external;

    function markRequestStale(bytes32 requestKey) external;

    function raiseTimeParameter(bytes32 parameterId, uint256 newValue) external;

    function revokeEntropyProvider(address provider, string calldata reasonURI) external;

    function setProviderRevoked(address provider, bool revoked) external;

    function setRequester(address requester, bool allowed) external;
}

interface IStreamSetupPlansMetadataRouter {
    function raiseGasParameter(bytes32 id, uint256 next) external;

    function setCollectionMediaManifest(
        uint256 collectionId,
        StreamCollectionManifestTypes.MediaManifest calldata value
    ) external;

    function setCollectionScript(uint256 collectionId, string calldata script) external;

    function setCollectionScriptManifest(
        uint256 collectionId,
        StreamCollectionManifestTypes.ScriptManifest calldata value
    ) external;

    function setContractMetadataURI(string calldata uri) external;
}

interface IStreamSetupPlansAssetPolicyRegistry {
    function setAssetPermitPolicy(
        address asset,
        uint8 capabilities,
        uint8 allowanceMode,
        address permit2,
        bytes32 expectedCodeHash
    ) external;

    function setAssetStatus(address asset, uint8 status, bytes32 policyHash, uint64 grace) external;
}

interface IStreamSetupPlansCore {
    function blockCollectionBurns(uint256 collectionId) external;

    function freezeCollection(uint256 collectionId) external;

    function raiseGasParameter(bytes32 parameterId, uint256 newValue) external;

    function setCollectionMaxSupply(uint256 collectionId, uint256 newMaxSupply) external;

    function setCollectionStatus(uint256 collectionId, uint8 newStatus) external;
}

interface IStreamSetupPlansRoyaltyResolver {
    function configureCollectionRoyalty(
        uint256 collectionId,
        bytes32 profileId,
        uint16 royaltyBps
    ) external;

    function configureDefaultRoyalty(bytes32 profileId, uint16 royaltyBps) external;

    function freezeCollectionRoyalty(uint256 collectionId) external;

    function freezeDefaultRoyalty() external;
}

interface IStreamSetupPlansGovernanceExecutor {
    function extendGovernanceActionPolicy(
        uint64 expectedRevision,
        bytes32 expectedOldCatalogHash,
        bytes32 expectedNewCatalogHash,
        GovernanceActionPolicyEntry[] calldata additions
    ) external;

    function registerCanceller(address account, bool enabled) external;

    function registerFreezeSelector(address target, bytes4 selector, bool freeze) external;

    function registerProposer(address account, bool enabled) external;

    function registerSystemManifestTailTrigger(
        address triggerTarget,
        bytes4 triggerSelector,
        uint8 allowedActionClassMask
    ) external;

    function rotateGovernanceRoot(address newRoot, bytes32 expectedCodeHash) external;

    function setApprovedNativeReceiver(address receiver, bool approved) external;

    function setTighteningCall(address target, bytes4 selector, bool tightening) external;
}

interface IStreamSetupPlansRoleRegistry {
    function grantRole(bytes32 role, address holder) external;

    function grantScopedRole(bytes32 baseRole, bytes32 scopeHash, address holder) external;

    function registerRoleManager(address account, bool enabled) external;

    function revokeRole(bytes32 role, address holder) external;

    function revokeScopedRole(bytes32 baseRole, bytes32 scopeHash, address holder) external;
}

interface IStreamSetupPlansModuleRegistry {
    function setModuleRegistryManifest(bytes32 manifestHash, string calldata manifestURI) external;

    function setModuleStatus(
        address module,
        ModuleRegistryStatus newStatus,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external;
}

interface IStreamSetupPlansSystemManifest {
    function publishStreamSystemManifest(
        address payloadPointer,
        StreamSystemManifestUpdate calldata update
    ) external;
}

interface IStreamSetupPlansSplitFactory {
    function raiseGasParameter(bytes32 parameterId, uint256 newValue) external;
}

interface IStreamSetupPlansArtistOnboardingRegistry {
    function raiseGasParameter(bytes32 parameterId, uint256 newValue) external;
}

interface IStreamSetupPlansRevenueEscrow {
    function raiseGasParameter(bytes32 parameterId, uint256 newValue) external;

    function setCreditProducer(address producer, bool enabled) external;
}

interface IStreamSetupPlansRevenueResolver {
    function createDynamicPrimaryTemplate(
        IStreamRevenueResolver.PrimaryTemplateEntry[] calldata entries,
        bytes32 metadataURIHash,
        IStreamDynamicPrimaryTemplates.CollaboratorReference[] calldata references
    ) external returns (bytes32);

    function createPrimaryTemplate(
        IStreamRevenueResolver.PrimaryTemplateEntry[] calldata entries,
        bytes32 metadataURIHash
    ) external returns (bytes32 templateId);

    function raiseGasParameter(bytes32 parameterId, uint256 newValue) external;

    function setPrimaryTemplateAssignment(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 templateId,
        bytes32 policyHash
    ) external returns (bytes32 assignmentHash);
}
