// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import "./StreamPrimaryAssignmentHash.sol";
import { StreamPrimaryIdentityReads } from "./StreamPrimaryIdentityReads.sol";
import { StreamPrimaryResolverState } from "./StreamPrimaryResolverState.sol";
import {
    StreamPrimaryTemplateRuntime as TemplateRuntime
} from "./StreamPrimaryTemplateRuntime.sol";
import {
    StreamDynamicPrimaryTemplateRules as DynamicRules
} from "./StreamDynamicPrimaryTemplateRules.sol";
import {
    IStreamArtistDynamicPrimaryTemplateFacts
} from "../../interfaces/stream/artist/IStreamArtistDynamicPrimaryTemplateFacts.sol";
import {
    IStreamDynamicPrimaryTemplates
} from "../../interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";

import "../../interfaces/stream/revenue/IStreamAssetPolicyRegistry.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryScopeFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistScopedPrimaryTemplateFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistDefaultPrimaryTemplateFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateConsentFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistTemplateEconomicsAuthority.sol";
import "../../interfaces/stream/artist/IStreamArtistTemplateMutationAuthority.sol";
import "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../vendor/openzeppelin/Ownable.sol";

/// @notice Core-bound primary assignments with immutable artist-facade admission.
/// @dev Bound collections and mapped tokens support fixed PRIMARY_SALE profiles with prospective artist
///      consent and independent governance admission. Inherited/default selected rights need their own
///      applicable consent in token contexts. Explicit template sets require prospective consent;
///      positive-share low-take reads also require that exact current consent. Initial facts stay strict.
contract StreamRevenueResolver is
    IStreamRevenueResolver,
    IStreamDynamicPrimaryTemplates,
    IStreamArtistDynamicPrimaryTemplateFacts,
    IStreamArtistPrimaryFacts,
    IStreamArtistPrimaryScopeFacts,
    IStreamArtistScopedPrimaryTemplateFacts,
    IStreamArtistDefaultPrimaryTemplateFacts,
    IStreamArtistPrimaryTemplateFacts,
    IStreamArtistPrimaryTemplateConsentFacts,
    ERC165,
    Ownable,
    StreamPrimaryResolverState,
    StreamGasParameterHost
{
    bytes32 private constant _PRIMARY_TEMPLATE_DOMAIN = keccak256("6529STREAM_PRIMARY_TEMPLATE_V1");
    bytes32 private constant _PRIMARY_ASSIGNMENT_DOMAIN =
        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_V1");
    bytes32 private constant _PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_DOMAIN =
        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1");
    bytes32 private constant _PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_DOMAIN =
        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1");
    bytes32 private constant _PRIMARY_ASSIGNMENT_POINTER_CONTEXT_DOMAIN =
        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_POINTER_CONTEXT_V1");
    bytes32 private constant _PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_DOMAIN =
        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1");
    bytes32 private constant _PRIMARY_ASSIGNMENT_TEMPLATE_CONTEXT_DOMAIN =
        keccak256("6529STREAM_PRIMARY_ASSIGNMENT_TEMPLATE_CONTEXT_V1");
    bytes32 private constant _MATERIALIZED_PROFILE_METADATA_DOMAIN =
        keccak256("6529STREAM_MATERIALIZED_PRIMARY_PROFILE_METADATA_V1");

    uint16 public constant SCHEMA_VERSION = 1;
    uint16 public constant TEMPLATE_VERSION = 1;
    uint8 public constant override SCOPE_DEFAULT = 0;
    uint8 public constant override SCOPE_COLLECTION = 1;
    uint8 public constant override SCOPE_TOKEN = 2;
    uint8 public constant override ASSIGNMENT_TYPE_PROFILE = 1;
    uint8 public constant override ASSIGNMENT_TYPE_TEMPLATE = 2;
    uint16 public constant MAX_TEMPLATE_ENTRIES = 64;
    uint16 public constant MAX_DYNAMIC_ACCOUNT_SOURCES = 8;
    uint32 public constant SHARE_DENOMINATOR_PPM = 1_000_000;
    bytes32 public constant override ACCOUNT_SOURCE_SALE_POSTER = keccak256("SALE_POSTER");
    bytes32 public constant override ACCOUNT_SOURCE_COLLECTION_ARTIST =
        keccak256("COLLECTION_ARTIST");
    bytes32 public constant override ARTIST_LABEL = keccak256("artist");
    bytes32 public constant override ARTIST_BENEFICIARY_READ_GAS =
        keccak256("6529STREAM_GGP_ARTIST_BENEFICIARY_READ_GAS");

    IStreamSplitFactory public immutable splitFactoryContract;
    IStreamAssetPolicyRegistry private immutable _assetPolicyRegistry;
    bytes32 private immutable _splitWalletRuntimeCodeHash;
    address public immutable override core;
    address public immutable override artistRegistry;
    bytes32 public immutable override coreCodeHash;
    bytes32 public immutable override artistRegistryCodeHash;

    event DynamicCollectionTemplateMaterialized(
        uint16 schemaVersion,
        bytes32 indexed templateId,
        bytes32 indexed profileId,
        uint256 indexed collectionId,
        bytes32 beneficiaryHash,
        address salePoster
    );

    /// @notice Reverts when the configured split factory cannot support resolver invariants.
    error InvalidSplitFactory(address splitFactory);

    /// @dev The explicit facade pin permits deployment before genesis installs Core pointers.
    ///      Assignment configuration still requires this facade to be selected by Core.
    constructor(
        IStreamCore core_,
        IStreamSplitFactory splitFactory_,
        address governanceExecutor_,
        IStreamArtistAttribution artistRegistry_,
        GasParameterConfig memory beneficiaryReadGas
    ) StreamGasParameterHost(governanceExecutor_) {
        if (
            keccak256(bytes(beneficiaryReadGas.name)) != keccak256("ARTIST_BENEFICIARY_READ_GAS")
                || beneficiaryReadGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || beneficiaryReadGas.genesisValue > type(uint64).max
        ) {
            revert GasParameterInvalidConfig(ARTIST_BENEFICIARY_READ_GAS);
        }
        _registerGasParameter(beneficiaryReadGas);
        if (address(core_).code.length == 0 || governanceExecutor_.code.length == 0) {
            revert InvalidPrimaryResolverConfiguration();
        }
        address artist = address(artistRegistry_);
        if (
            artist.code.length == 0 || IStreamArtistAttribution(artist).core() != address(core_)
                || !IERC165(artist).supportsInterface(type(IStreamArtistAttribution).interfaceId)
                || IERC165(artist).supportsInterface(0xffffffff)
        ) revert InvalidPrimaryArtistRegistry(artist);
        core = address(core_);
        coreCodeHash = address(core_).codehash;
        artistRegistry = artist;
        artistRegistryCodeHash = artist.codehash;
        if (address(splitFactory_).code.length == 0) {
            revert InvalidSplitFactory(address(splitFactory_));
        }
        try splitFactory_.SHARE_DENOMINATOR_PPM() returns (uint32 denominator) {
            if (denominator != SHARE_DENOMINATOR_PPM) {
                revert InvalidSplitFactory(address(splitFactory_));
            }
        } catch {
            revert InvalidSplitFactory(address(splitFactory_));
        }
        IStreamAssetPolicyRegistry registry;
        try splitFactory_.assetPolicyRegistry() returns (IStreamAssetPolicyRegistry registry_) {
            registry = registry_;
            if (address(registry).code.length == 0) {
                revert InvalidSplitFactory(address(splitFactory_));
            }
        } catch {
            revert InvalidSplitFactory(address(splitFactory_));
        }
        bytes32 runtimeCodeHash;
        try splitFactory_.splitWalletRuntimeCodeHash() returns (bytes32 runtimeCodeHash_) {
            runtimeCodeHash = runtimeCodeHash_;
            if (runtimeCodeHash == bytes32(0)) {
                revert InvalidSplitFactory(address(splitFactory_));
            }
        } catch {
            revert InvalidSplitFactory(address(splitFactory_));
        }
        splitFactoryContract = splitFactory_;
        _assetPolicyRegistry = registry;
        _splitWalletRuntimeCodeHash = runtimeCodeHash;
        _transferOwnership(governanceExecutor_);
    }

    /// @notice Returns true for deployment validation.
    function isStreamRevenueResolver() external pure override returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamDynamicPrimaryTemplates).interfaceId
            || id == type(IStreamArtistDynamicPrimaryTemplateFacts).interfaceId
            || id == type(IStreamArtistPrimaryTemplateConsentFacts).interfaceId
            || id == type(IStreamArtistPrimaryTemplateFacts).interfaceId
            || id == type(IStreamArtistPrimaryScopeFacts).interfaceId
            || id == type(IStreamArtistScopedPrimaryTemplateFacts).interfaceId
            || id == type(IStreamArtistDefaultPrimaryTemplateFacts).interfaceId
            || id == type(IStreamArtistPrimaryFacts).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
    }

    /// @inheritdoc IStreamArtistPrimaryTemplateFacts
    function primaryTemplateEconomicsFacts(bytes32 templateId)
        external
        view
        override
        returns (bytes32 entriesHash, bytes32 metadataURIHash, uint32 artistSharePpm)
    {
        _requireSelectedArtistRegistry();
        PrimaryTemplate storage template = _templates[templateId];
        artistSharePpm = _requireArtistTemplate(templateId);
        return (template.entriesHash, template.metadataURIHash, artistSharePpm);
    }

    /// @inheritdoc IStreamArtistPrimaryTemplateFacts
    function previewArtistPrimaryTemplateAssignment(
        uint256 collectionId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view override returns (StreamArtistOnboardingTypes.AssignmentFact memory fact) {
        _requireSelectedArtistRegistry();
        _requireScope(SCOPE_COLLECTION, collectionId);
        _resolveCollectionIdentity(collectionId, 0);
        if (policyHash != bytes32(0)) revert InvalidPrimaryPolicyHash();
        _requireArtistTemplate(templateId);
        bytes32 revenueClass = keccak256("PRIMARY_SALE");
        return StreamArtistOnboardingTypes.AssignmentFact(
            address(this),
            revenueClass,
            SCOPE_COLLECTION,
            collectionId,
            _primaryAssignmentHash(
                revenueClass,
                SCOPE_COLLECTION,
                collectionId,
                ASSIGNMENT_TYPE_TEMPLATE,
                bytes32(0),
                templateId,
                policyHash,
                frozen
            )
        );
    }

    /// @dev Existing initial capability remains at its original floor.
    function _requireArtistTemplate(bytes32 templateId) private view returns (uint32) {
        return _requireTemplateShare(templateId, 500_000);
    }

    function _requireTemplateShare(bytes32 templateId, uint32 minimum)
        private
        view
        returns (uint32)
    {
        PrimaryTemplate storage template = _templates[templateId];
        if (!template.exists) revert UnsupportedArtistPrimaryTemplate(templateId);
        return TemplateRuntime.artistShare(template, templateId, minimum);
    }

    /// @inheritdoc IStreamArtistPrimaryTemplateConsentFacts
    function primaryTemplateConsentFacts(bytes32 templateId)
        external
        view
        override
        returns (bytes32 entriesHash, bytes32 metadataURIHash, uint32 artistSharePpm)
    {
        _requireSelectedArtistRegistry();
        PrimaryTemplate storage template = _templates[templateId];
        artistSharePpm = _requireTemplateShare(templateId, 1);
        return (template.entriesHash, template.metadataURIHash, artistSharePpm);
    }

    /// @inheritdoc IStreamArtistPrimaryTemplateConsentFacts
    function previewArtistPrimaryTemplateConsentAssignment(
        uint256 collectionId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view override returns (StreamArtistOnboardingTypes.AssignmentFact memory fact) {
        _requireSelectedArtistRegistry();
        _requireScope(SCOPE_COLLECTION, collectionId);
        _resolveCollectionIdentity(collectionId, 0);
        if (policyHash != bytes32(0)) revert InvalidPrimaryPolicyHash();
        _requireTemplateShare(templateId, 1);
        bytes32 revenueClass = keccak256("PRIMARY_SALE");
        return StreamArtistOnboardingTypes.AssignmentFact(
            address(this),
            revenueClass,
            SCOPE_COLLECTION,
            collectionId,
            _primaryAssignmentHash(
                revenueClass,
                SCOPE_COLLECTION,
                collectionId,
                ASSIGNMENT_TYPE_TEMPLATE,
                bytes32(0),
                templateId,
                policyHash,
                frozen
            )
        );
    }

    function isDynamicPrimaryTemplate(bytes32 templateId) external view override returns (bool) {
        PrimaryTemplate storage t = _templates[templateId];
        if (!t.exists) revert UnknownPrimaryTemplate(templateId);
        return TemplateRuntime.isDynamic(t);
    }

    function dynamicPrimaryTemplateFacts(uint256 collectionId, bytes32 templateId)
        external
        view
        override
        returns (
            bytes32 entriesHash,
            bytes32 metadataURIHash,
            uint32 artistSharePpm,
            bytes32 beneficiaryHash
        )
    {
        _requireSelectedArtistRegistry();
        _resolveCollectionIdentity(collectionId, 0);
        return _dynamicFacts(collectionId, templateId);
    }

    function _dynamicFacts(uint256 collectionId, bytes32 templateId)
        private
        view
        returns (
            bytes32 entriesHash,
            bytes32 metadataURIHash,
            uint32 artistSharePpm,
            bytes32 beneficiaryHash
        )
    {
        return TemplateRuntime.dynamicFacts(
            _templates, _templateContext(true), collectionId, templateId
        );
    }

    function previewArtistDynamicPrimaryTemplateAssignment(
        uint256 collectionId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view override returns (StreamArtistOnboardingTypes.AssignmentFact memory) {
        _requireSelectedArtistRegistry();
        _requireScope(SCOPE_COLLECTION, collectionId);
        _resolveCollectionIdentity(collectionId, 0);
        if (policyHash != 0) revert InvalidPrimaryPolicyHash();
        _dynamicFacts(collectionId, templateId);
        bytes32 revenueClass = keccak256("PRIMARY_SALE");
        return StreamArtistOnboardingTypes.AssignmentFact(
            address(this),
            revenueClass,
            SCOPE_COLLECTION,
            collectionId,
            _primaryAssignmentHash(
                revenueClass,
                SCOPE_COLLECTION,
                collectionId,
                ASSIGNMENT_TYPE_TEMPLATE,
                bytes32(0),
                templateId,
                policyHash,
                frozen
            )
        );
    }

    /// @notice Does not resolve current rights or require the approval being proposed.
    function previewArtistDefaultPrimaryTemplateAssignment(
        uint256 collectionId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view override returns (StreamArtistOnboardingTypes.AssignmentFact memory) {
        _requireArtistScopeIdentity(collectionId, SCOPE_DEFAULT, 0);
        if (policyHash != 0) revert InvalidPrimaryPolicyHash();
        if (TemplateRuntime.isDynamic(_templates[templateId])) {
            _dynamicFacts(collectionId, templateId);
        } else {
            _requireTemplateShare(templateId, 1);
        }
        bytes32 cls = keccak256("PRIMARY_SALE");
        return StreamArtistOnboardingTypes.AssignmentFact(
            address(this),
            cls,
            SCOPE_DEFAULT,
            0,
            _primaryAssignmentHash(
                cls, SCOPE_DEFAULT, 0, ASSIGNMENT_TYPE_TEMPLATE, 0, templateId, policyHash, frozen
            )
        );
    }

    /// @notice The token-scoped preview uses actual Core identity and the original assignment hash.
    function previewArtistScopedPrimaryTemplateAssignment(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view override returns (StreamArtistOnboardingTypes.AssignmentFact memory) {
        _requireSelectedArtistRegistry();
        if (scope != SCOPE_COLLECTION && scope != SCOPE_TOKEN) {
            revert InvalidAssignmentScope(scope, scopeId);
        }
        _requireArtistScopeIdentity(collectionId, scope, scopeId);
        if (policyHash != 0) revert InvalidPrimaryPolicyHash();
        if (TemplateRuntime.isDynamic(_templates[templateId])) {
            _dynamicFacts(collectionId, templateId);
        } else {
            _requireTemplateShare(templateId, 1);
        }
        bytes32 revenueClass = keccak256("PRIMARY_SALE");
        return StreamArtistOnboardingTypes.AssignmentFact(
            address(this),
            revenueClass,
            scope,
            scopeId,
            _primaryAssignmentHash(
                revenueClass,
                scope,
                scopeId,
                ASSIGNMENT_TYPE_TEMPLATE,
                bytes32(0),
                templateId,
                policyHash,
                frozen
            )
        );
    }

    /// @inheritdoc IStreamArtistPrimaryFacts
    function previewArtistPrimaryAssignment(
        uint256 collectionId,
        bytes32 profileHash,
        bytes32 policyHash,
        bool frozen
    ) external view override returns (StreamArtistOnboardingTypes.AssignmentFact memory fact) {
        return _previewArtistPrimaryProfile(
            collectionId, SCOPE_COLLECTION, collectionId, profileHash, policyHash, frozen
        );
    }

    /// @inheritdoc IStreamArtistPrimaryScopeFacts
    function primaryEconomicsFacts(uint256 collectionId, uint8 scope, uint256 scopeId)
        external
        view
        override
        returns (ResolvedPrimaryAssignment memory)
    {
        _requireArtistScopeIdentity(collectionId, scope, scopeId);
        return _resolvedAt(keccak256("PRIMARY_SALE"), scope, scopeId);
    }

    /// @inheritdoc IStreamArtistPrimaryScopeFacts
    function previewArtistPrimaryAssignmentForScope(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 profileHash,
        bytes32 policyHash,
        bool frozen
    ) external view override returns (StreamArtistOnboardingTypes.AssignmentFact memory fact) {
        return _previewArtistPrimaryProfile(
            collectionId, scope, scopeId, profileHash, policyHash, frozen
        );
    }

    function _previewArtistPrimaryProfile(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 profileHash,
        bytes32 policyHash,
        bool frozen
    ) private view returns (StreamArtistOnboardingTypes.AssignmentFact memory) {
        _requireArtistScopeIdentity(collectionId, scope, scopeId);
        if (policyHash != bytes32(0)) revert InvalidPrimaryPolicyHash();
        if (
            profileHash == bytes32(0) || !splitFactoryContract.profileExists(profileHash)
                || !splitFactoryContract.splitWalletExists(profileHash)
        ) revert UnverifiedSplitProfile(profileHash);
        bytes32 revenueClass = keccak256("PRIMARY_SALE");
        return StreamArtistOnboardingTypes.AssignmentFact(
            address(this),
            revenueClass,
            scope,
            scopeId,
            _primaryAssignmentHash(
                revenueClass,
                scope,
                scopeId,
                ASSIGNMENT_TYPE_PROFILE,
                profileHash,
                bytes32(0),
                policyHash,
                frozen
            )
        );
    }

    /// @inheritdoc IStreamArtistPrimaryScopeFacts
    function previewArtistPrimaryClear(uint256 collectionId, uint8 scope, uint256 scopeId)
        external
        view
        override
        returns (StreamArtistOnboardingTypes.AssignmentFact memory fact, bytes32 previousHash)
    {
        _requireArtistScopeIdentity(collectionId, scope, scopeId);
        if (scope == SCOPE_DEFAULT) revert InvalidAssignmentScope(scope, scopeId);
        bytes32 revenueClass = keccak256("PRIMARY_SALE");
        ResolvedPrimaryAssignment memory current = _resolvedAt(revenueClass, scope, scopeId);
        if (!current.exists) revert PrimaryAssignmentMissing(revenueClass, scope, scopeId);
        if (current.frozen) revert PrimaryAssignmentFrozen(revenueClass, scope, scopeId);
        if (
            current.assignmentType != ASSIGNMENT_TYPE_PROFILE
                && current.assignmentType != ASSIGNMENT_TYPE_TEMPLATE
        ) {
            revert UnsupportedArtistPrimaryAssignment(collectionId);
        }
        fact = StreamArtistOnboardingTypes.AssignmentFact(
            address(this), revenueClass, scope, scopeId, bytes32(0)
        );
        return (fact, current.assignmentHash);
    }

    /// @dev Supplemental collection context is always joined to actual Core identity.
    function _requireArtistScopeIdentity(uint256 collectionId, uint8 scope, uint256 scopeId)
        private
        view
    {
        _requireSelectedArtistRegistry();
        _requireScope(scope, scopeId);
        if (collectionId == 0) revert InvalidPrimaryCollection(collectionId);
        if (scope == SCOPE_COLLECTION && scopeId != collectionId) {
            revert InvalidAssignmentScope(scope, scopeId);
        }
        _resolveCollectionIdentity(collectionId, scope == SCOPE_TOKEN ? scopeId : 0);
    }

    /// @notice The split factory used to verify and materialize profiles.
    function splitFactory() external view override returns (address) {
        return address(splitFactoryContract);
    }

    /// @notice Creates or reuses a primary split template.
    function createPrimaryTemplate(PrimaryTemplateEntry[] calldata entries, bytes32 metadataURIHash)
        external
        override
        onlyOwner
        returns (bytes32 templateId)
    {
        return TemplateRuntime.registerTemplate(
            _templates,
            entries,
            metadataURIHash,
            new IStreamDynamicPrimaryTemplates.CollaboratorReference[](0),
            false
        );
    }

    function createDynamicPrimaryTemplate(
        PrimaryTemplateEntry[] calldata entries,
        bytes32 metadataURIHash,
        IStreamDynamicPrimaryTemplates.CollaboratorReference[] calldata references
    ) external override onlyOwner returns (bytes32) {
        return
            TemplateRuntime.registerTemplate(_templates, entries, metadataURIHash, references, true);
    }

    function collaboratorAccountSource(
        IStreamDynamicPrimaryTemplates.CollaboratorReference calldata reference_
    ) external pure override returns (bytes32) {
        return DynamicRules.source(reference_);
    }

    /// @notice Sets a fixed-profile primary assignment.
    function setPrimaryProfileAssignment(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 profileId,
        bytes32 policyHash
    ) external override onlyOwner returns (bytes32 assignmentHash) {
        _requireAssignmentInput(revenueClass, scope, scopeId, policyHash);
        if (
            !splitFactoryContract.profileExists(profileId)
                || !splitFactoryContract.splitWalletExists(profileId)
        ) {
            revert UnverifiedSplitProfile(profileId);
        }
        assignmentHash = _setPrimaryAssignment(
            revenueClass, scope, scopeId, ASSIGNMENT_TYPE_PROFILE, profileId, bytes32(0), policyHash
        );
    }

    /// @notice Sets a dynamic-template primary assignment.
    function setPrimaryTemplateAssignment(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 templateId,
        bytes32 policyHash
    ) external override onlyOwner returns (bytes32 assignmentHash) {
        _requireAssignmentInput(revenueClass, scope, scopeId, policyHash);
        if (!_templates[templateId].exists) {
            revert UnknownPrimaryTemplate(templateId);
        }
        assignmentHash = _setPrimaryAssignment(
            revenueClass,
            scope,
            scopeId,
            ASSIGNMENT_TYPE_TEMPLATE,
            bytes32(0),
            templateId,
            policyHash
        );
    }

    /// @notice Clears a mutable primary assignment.
    function clearPrimaryAssignment(bytes32 revenueClass, uint8 scope, uint256 scopeId)
        external
        override
        onlyOwner
    {
        _requireRevenueClass(revenueClass);
        _requireScope(scope, scopeId);
        _requireSelectedArtistRegistry();
        bytes32 key = _assignmentKey(revenueClass, scope, scopeId);
        PrimaryAssignment storage assignment = _primaryAssignments[key];
        if (!assignment.exists) {
            revert PrimaryAssignmentMissing(revenueClass, scope, scopeId);
        }
        if (assignment.frozen) {
            revert PrimaryAssignmentFrozen(revenueClass, scope, scopeId);
        }
        bytes32 previousHash = _assignmentHash(revenueClass, scope, scopeId, assignment);
        _requireArtistEconomics(revenueClass, scope, scopeId, assignment.assignmentType, bytes32(0));
        delete _primaryAssignments[key];
        emit PrimaryAssignmentCleared(revenueClass, scope, scopeId, previousHash, msg.sender);
    }

    /// @notice Freezes an existing primary assignment.
    function freezePrimaryAssignment(bytes32 revenueClass, uint8 scope, uint256 scopeId)
        external
        override
        onlyOwner
        returns (bytes32 frozenAssignmentHash)
    {
        _requireRevenueClass(revenueClass);
        _requireScope(scope, scopeId);
        _requireSelectedArtistRegistry();
        bytes32 key = _assignmentKey(revenueClass, scope, scopeId);
        PrimaryAssignment storage assignment = _primaryAssignments[key];
        if (!assignment.exists) {
            revert PrimaryAssignmentMissing(revenueClass, scope, scopeId);
        }
        if (assignment.frozen) {
            revert PrimaryAssignmentFrozen(revenueClass, scope, scopeId);
        }
        bytes32 previousHash = _assignmentHash(revenueClass, scope, scopeId, assignment);
        frozenAssignmentHash = _primaryAssignmentHash(
            revenueClass,
            scope,
            scopeId,
            assignment.assignmentType,
            assignment.profileId,
            assignment.templateId,
            assignment.policyHash,
            true
        );
        _requireArtistEconomics(
            revenueClass, scope, scopeId, assignment.assignmentType, frozenAssignmentHash
        );
        assignment.frozen = true;
        emit PrimaryAssignmentFrozenEvent(
            revenueClass, scope, scopeId, previousHash, frozenAssignmentHash, msg.sender
        );
    }

    /// @notice Resolves token, collection, then default primary assignment for a sale context.
    function resolvePrimaryAssignment(uint256 collectionId, uint256 tokenId, bytes32 revenueClass)
        external
        view
        override
        returns (ResolvedPrimaryAssignment memory resolved)
    {
        _requireRevenueClass(revenueClass);
        address currentArtist = _requireSelectedArtistRegistry();
        collectionId = _resolveCollectionIdentity(collectionId, tokenId);
        if (tokenId != 0) {
            resolved = _resolvedAt(revenueClass, SCOPE_TOKEN, tokenId);
        }
        if (!resolved.exists && collectionId != 0) {
            resolved = _resolvedAt(revenueClass, SCOPE_COLLECTION, collectionId);
        }
        if (!resolved.exists) resolved = _resolvedAt(revenueClass, SCOPE_DEFAULT, 0);
        if (
            collectionId != 0
                && IStreamArtistAttribution(currentArtist).attribution(collectionId).nominationHash
                    != bytes32(0)
        ) {
            if (!resolved.exists) {
                revert UnsupportedArtistPrimaryAssignment(collectionId);
            }
            bool templateConsentRequired;
            if (
                resolved.assignmentType == ASSIGNMENT_TYPE_TEMPLATE
                    && revenueClass == keccak256("PRIMARY_SALE")
                    && ((resolved.scope == SCOPE_COLLECTION && resolved.scopeId == collectionId)
                        || (resolved.scope == SCOPE_TOKEN
                            && resolved.scopeId == tokenId
                            && tokenId != 0)
                        || (resolved.scope == SCOPE_DEFAULT && resolved.scopeId == 0))
            ) {
                if (TemplateRuntime.isDynamic(_templates[resolved.templateId])) {
                    _dynamicFacts(collectionId, resolved.templateId);
                    templateConsentRequired = true;
                } else {
                    templateConsentRequired = _requireTemplateShare(resolved.templateId, 1)
                            < 500_000 || resolved.scope == SCOPE_TOKEN
                        || resolved.scope == SCOPE_DEFAULT;
                }
                if (templateConsentRequired) {
                    // Old Artist implementations retain the initial unsupported-template error.
                    if (!IERC165(currentArtist)
                            .supportsInterface(
                                type(IStreamArtistTemplateEconomicsAuthority).interfaceId
                            )) {
                        revert UnsupportedArtistPrimaryTemplate(resolved.templateId);
                    }
                    _requireTemplateConsentCapability(collectionId);
                }
            } else if (resolved.assignmentType != ASSIGNMENT_TYPE_PROFILE) {
                revert UnsupportedArtistPrimaryAssignment(collectionId);
            }
            if (tokenId != 0 || resolved.scope != SCOPE_COLLECTION || templateConsentRequired) {
                if (revenueClass != keccak256("PRIMARY_SALE")) {
                    revert UnsupportedArtistPrimaryAssignment(collectionId);
                }
                _requireConsent(
                    collectionId,
                    revenueClass,
                    resolved.scope,
                    resolved.scopeId,
                    resolved.assignmentHash
                );
            }
        }
    }

    /// @notice Legacy context-free cache for static and SALE_POSTER templates only.
    function materializePrimaryProfile(bytes32 templateId, address salePoster)
        external
        override
        returns (bytes32 profileId, address wallet, bytes32 entriesHash)
    {
        TemplateRuntime.MaterializationContext memory context;
        context.salePoster = salePoster;
        context.deploy = true;
        return _materialize(templateId, context);
    }

    /// @notice Resolves current explicit artist payout before any profile registration.
    function materializeCollectionPrimaryProfile(
        bytes32 templateId,
        uint256 collectionId,
        address salePoster,
        bool deployWallet
    ) external override returns (bytes32 profileId, address wallet, bytes32 entriesHash) {
        _requireSelectedArtistRegistry();
        if (collectionId == 0) revert InvalidPrimaryCollection(collectionId);
        _resolveCollectionIdentity(collectionId, 0);
        TemplateRuntime.MaterializationContext memory context;
        context.collectionId = collectionId;
        context.salePoster = salePoster;
        context.deploy = deployWallet;
        return _materialize(templateId, context);
    }

    function _materialize(bytes32 templateId, TemplateRuntime.MaterializationContext memory context)
        private
        returns (bytes32 profileId, address wallet, bytes32 entriesHash)
    {
        (profileId, wallet, entriesHash, context.beneficiaryHash) = TemplateRuntime.materialize(
            _templates, _templateContext(context.collectionId != 0), templateId, context
        );
    }

    function materializeDynamicCollectionPrimaryProfile(
        bytes32 templateId,
        uint256 collectionId,
        address salePoster,
        bool deployWallet
    )
        external
        override
        returns (bytes32 profileId, address wallet, bytes32 entriesHash, bytes32 beneficiaryHash)
    {
        _requireSelectedArtistRegistry();
        if (collectionId == 0) revert InvalidPrimaryCollection(collectionId);
        _resolveCollectionIdentity(collectionId, 0);
        TemplateRuntime.MaterializationContext memory context;
        context.collectionId = collectionId;
        context.salePoster = salePoster;
        context.deploy = deployWallet;
        context.dynamicTemplate = true;
        (profileId, wallet, entriesHash) = _materialize(templateId, context);
        return (profileId, wallet, entriesHash, context.beneficiaryHash);
    }

    function previewDynamicCollectionPrimaryProfile(
        bytes32 templateId,
        uint256 collectionId,
        address salePoster
    )
        external
        view
        override
        returns (bytes32 profileId, address wallet, bytes32 entriesHash, bytes32 beneficiaryHash)
    {
        _requireSelectedArtistRegistry();
        if (collectionId == 0) revert InvalidPrimaryCollection(collectionId);
        _resolveCollectionIdentity(collectionId, 0);
        TemplateRuntime.MaterializationContext memory context;
        context.collectionId = collectionId;
        context.salePoster = salePoster;
        context.dynamicTemplate = true;
        return TemplateRuntime.preview(
            _templates, _templateContext(context.collectionId != 0), templateId, context
        );
    }

    /// @notice Same concrete derivation as materialization, without registration or deployment.
    function previewCollectionPrimaryProfile(
        bytes32 templateId,
        uint256 collectionId,
        address salePoster
    ) external view override returns (bytes32 profileId, address wallet, bytes32 entriesHash) {
        _requireSelectedArtistRegistry();
        if (collectionId == 0) revert InvalidPrimaryCollection(collectionId);
        _resolveCollectionIdentity(collectionId, 0);
        TemplateRuntime.MaterializationContext memory context;
        context.collectionId = collectionId;
        context.salePoster = salePoster;
        (profileId, wallet, entriesHash,) = TemplateRuntime.preview(
            _templates, _templateContext(context.collectionId != 0), templateId, context
        );
    }

    function _templateContext(bool collectionBound)
        private
        view
        returns (TemplateRuntime.Context memory)
    {
        return TemplateRuntime.Context(
            splitFactoryContract,
            collectionBound ? _requireSelectedArtistRegistry() : artistRegistry
        );
    }

    /// @notice Returns deterministic template metadata.
    function primaryTemplate(bytes32 templateId)
        external
        view
        override
        returns (bool exists, bytes32 entriesHash, bytes32 metadataURIHash)
    {
        PrimaryTemplate storage template = _templates[templateId];
        return (template.exists, template.entriesHash, template.metadataURIHash);
    }

    /// @notice Returns the number of canonical entries in a template.
    function primaryTemplateEntryCount(bytes32 templateId)
        external
        view
        override
        returns (uint256)
    {
        return _templates[templateId].entries.length;
    }

    /// @notice Returns one canonical template entry.
    function primaryTemplateEntry(bytes32 templateId, uint256 index)
        external
        view
        override
        returns (address account, bytes32 accountSource, uint32 sharePpm, bytes32 labelId)
    {
        PrimaryTemplateEntry storage entry = _templates[templateId].entries[index];
        return (entry.account, entry.accountSource, entry.sharePpm, entry.labelId);
    }

    /// @notice Computes the current assignment hash for explicit inputs.
    function primaryAssignmentHash(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        uint8 assignmentType,
        bytes32 profileId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view override returns (bytes32) {
        if (policyHash != bytes32(0)) revert InvalidPrimaryPolicyHash();
        return _primaryAssignmentHash(
            revenueClass, scope, scopeId, assignmentType, profileId, templateId, policyHash, frozen
        );
    }

    function _setPrimaryAssignment(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        uint8 assignmentType,
        bytes32 profileId,
        bytes32 templateId,
        bytes32 policyHash
    ) private returns (bytes32 assignmentHash) {
        bytes32 key = _assignmentKey(revenueClass, scope, scopeId);
        PrimaryAssignment storage previous = _primaryAssignments[key];
        if (previous.frozen) {
            revert PrimaryAssignmentFrozen(revenueClass, scope, scopeId);
        }
        assignmentHash = _primaryAssignmentHash(
            revenueClass, scope, scopeId, assignmentType, profileId, templateId, policyHash, false
        );
        if (assignmentType == ASSIGNMENT_TYPE_TEMPLATE) {
            _requireTemplateSetConsent(revenueClass, scope, scopeId, templateId, assignmentHash);
        } else {
            _requireArtistEconomics(revenueClass, scope, scopeId, assignmentType, assignmentHash);
        }
        _primaryAssignments[key] = PrimaryAssignment({
            exists: true,
            assignmentType: assignmentType,
            profileId: profileId,
            templateId: templateId,
            policyHash: policyHash,
            frozen: false
        });
        emit PrimaryAssignmentSet(
            revenueClass,
            scope,
            scopeId,
            assignmentType,
            profileId,
            templateId,
            policyHash,
            assignmentHash,
            msg.sender
        );
    }

    function _resolvedAt(bytes32 revenueClass, uint8 scope, uint256 scopeId)
        private
        view
        returns (ResolvedPrimaryAssignment memory resolved)
    {
        PrimaryAssignment storage assignment =
            _primaryAssignments[_assignmentKey(revenueClass, scope, scopeId)];
        if (!assignment.exists) {
            return resolved;
        }
        return ResolvedPrimaryAssignment({
            exists: true,
            scope: scope,
            scopeId: scopeId,
            assignmentType: assignment.assignmentType,
            profileId: assignment.profileId,
            templateId: assignment.templateId,
            policyHash: assignment.policyHash,
            assignmentHash: _assignmentHash(revenueClass, scope, scopeId, assignment),
            frozen: assignment.frozen
        });
    }

    function _assignmentHash(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        PrimaryAssignment storage assignment
    ) private view returns (bytes32) {
        if (!assignment.exists) {
            return bytes32(0);
        }
        return _primaryAssignmentHash(
            revenueClass,
            scope,
            scopeId,
            assignment.assignmentType,
            assignment.profileId,
            assignment.templateId,
            assignment.policyHash,
            assignment.frozen
        );
    }

    function _primaryAssignmentHash(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        uint8 assignmentType,
        bytes32 profileId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) private view returns (bytes32) {
        StreamPrimaryAssignmentHash.Input memory input;
        input.revenueClass = revenueClass;
        input.scope = scope;
        input.scopeId = scopeId;
        input.assignmentType = assignmentType;
        input.profileId = profileId;
        input.templateId = templateId;
        input.policyHash = policyHash;
        input.frozen = frozen;
        return _primaryAssignmentHash(input);
    }

    function _primaryAssignmentHash(StreamPrimaryAssignmentHash.Input memory input)
        private
        view
        returns (bytes32)
    {
        bytes32 entries;
        bytes32 metadata;
        if (input.assignmentType == ASSIGNMENT_TYPE_TEMPLATE && input.templateId != bytes32(0)) {
            entries = _templates[input.templateId].entriesHash;
            metadata = _templates[input.templateId].metadataURIHash;
        }
        return StreamPrimaryAssignmentHash.hash(
            splitFactoryContract,
            address(_assetPolicyRegistry),
            _splitWalletRuntimeCodeHash,
            input,
            entries,
            metadata
        );
    }

    function _requireAssignmentInput(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 policyHash
    ) private view {
        _requireRevenueClass(revenueClass);
        _requireScope(scope, scopeId);
        if (policyHash != bytes32(0)) {
            revert InvalidPrimaryPolicyHash();
        }
        _requireSelectedArtistRegistry();
    }

    /// @dev Consent precedes writes. Template clear/freeze require the explicit mutation capability;
    ///      default configuration remains global, with independently collection-admitted use.
    function _requireArtistEconomics(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        uint8 assignmentType,
        bytes32 assignmentHash
    ) private view {
        address currentArtist = _requireSelectedArtistRegistry();
        if (scope == SCOPE_DEFAULT) return;
        uint256 collectionId = scope == SCOPE_COLLECTION
            ? _resolveCollectionIdentity(scopeId, 0)
            : _resolveCollectionIdentity(0, scopeId);
        if (
            IStreamArtistAttribution(currentArtist).attribution(collectionId).nominationHash
                == bytes32(0)
        ) return;
        if (
            (assignmentType != ASSIGNMENT_TYPE_PROFILE
                    && assignmentType != ASSIGNMENT_TYPE_TEMPLATE)
                || revenueClass != keccak256("PRIMARY_SALE")
                || !IERC165(currentArtist)
                    .supportsInterface(type(IStreamArtistEconomicsAuthority).interfaceId)
        ) revert PrimaryArtistConsentRequired(collectionId);
        if (
            assignmentType == ASSIGNMENT_TYPE_TEMPLATE
                && !IERC165(currentArtist)
                    .supportsInterface(type(IStreamArtistTemplateMutationAuthority).interfaceId)
        ) revert PrimaryArtistConsentRequired(collectionId);
        _requireConsent(collectionId, revenueClass, scope, scopeId, assignmentHash);
    }

    /// @dev Explicit set-only consent path; no preview calls this admission check.
    function _requireTemplateSetConsent(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 templateId,
        bytes32 assignmentHash
    ) private view {
        address currentArtist = _requireSelectedArtistRegistry();
        if (scope == SCOPE_DEFAULT) return;
        uint256 collectionId = scope == SCOPE_COLLECTION
            ? _resolveCollectionIdentity(scopeId, 0)
            : _resolveCollectionIdentity(0, scopeId);
        if (
            IStreamArtistAttribution(currentArtist).attribution(collectionId).nominationHash
                == bytes32(0)
        ) return;
        if (
            revenueClass != keccak256("PRIMARY_SALE")
                || (scope != SCOPE_COLLECTION && scope != SCOPE_TOKEN)
        ) {
            revert PrimaryArtistConsentRequired(collectionId);
        }
        _requireTemplateConsentCapability(collectionId);
        if (TemplateRuntime.isDynamic(_templates[templateId])) {
            _dynamicFacts(collectionId, templateId);
        } else {
            _requireTemplateShare(templateId, 1);
        }
        _requireConsent(collectionId, revenueClass, scope, scopeId, assignmentHash);
    }

    function _requireTemplateConsentCapability(uint256 collectionId) private view {
        address currentArtist = _requireSelectedArtistRegistry();
        if (
            !IERC165(currentArtist)
                    .supportsInterface(type(IStreamArtistTemplateEconomicsAuthority).interfaceId)
                || !IERC165(currentArtist)
                    .supportsInterface(type(IStreamArtistEconomicsAuthority).interfaceId)
        ) {
            revert PrimaryArtistConsentRequired(collectionId);
        }
    }

    function _requireConsent(
        uint256 collectionId,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 assignmentHash
    ) private view {
        address currentArtist = _requireSelectedArtistRegistry();
        IStreamArtistEconomicsAuthority(currentArtist)
            .requireEconomicsConsent(collectionId, revenueClass, scope, scopeId, assignmentHash);
    }

    function _requireSelectedArtistRegistry() private view returns (address) {
        return StreamPrimaryIdentityReads.requireSelectedArtistRegistry(
            core, coreCodeHash, artistRegistry, artistRegistryCodeHash
        );
    }

    function _requireMutableArtistScope(uint8 scope, uint256 scopeId) private view {
        address currentArtist = _requireSelectedArtistRegistry();
        if (scope == SCOPE_DEFAULT) return;
        uint256 collectionId = scope == SCOPE_COLLECTION
            ? _resolveCollectionIdentity(scopeId, 0)
            : _resolveCollectionIdentity(0, scopeId);
        if (
            IStreamArtistAttribution(currentArtist).attribution(collectionId).nominationHash
                != bytes32(0)
        ) {
            revert PrimaryArtistConsentRequired(collectionId);
        }
    }

    function _resolveCollectionIdentity(uint256 suppliedCollectionId, uint256 tokenId)
        private
        view
        returns (uint256 collectionId)
    {
        return StreamPrimaryIdentityReads.resolveCollectionIdentity(
            core, suppliedCollectionId, tokenId
        );
    }

    function _requireRevenueClass(bytes32 revenueClass) private pure {
        if (revenueClass == bytes32(0)) {
            revert InvalidRevenueClass(revenueClass);
        }
    }

    function _requireScope(uint8 scope, uint256 scopeId) private pure {
        if (
            scope > SCOPE_TOKEN || (scope == SCOPE_DEFAULT && scopeId != 0)
                || (scope != SCOPE_DEFAULT && scopeId == 0)
        ) {
            revert InvalidAssignmentScope(scope, scopeId);
        }
    }

    function _assignmentKey(bytes32 revenueClass, uint8 scope, uint256 scopeId)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(revenueClass, scope, scopeId));
    }
}
