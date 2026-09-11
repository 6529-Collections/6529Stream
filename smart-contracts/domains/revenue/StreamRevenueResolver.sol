// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import "../../interfaces/stream/revenue/IStreamAssetPolicyRegistry.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryFacts.sol";
import "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../vendor/openzeppelin/Ownable.sol";

/// @notice Core-bound primary assignments with immutable artist-facade admission.
/// @dev Bound artist collections support fixed PRIMARY_SALE profiles with prospective artist
///      consent and independent governance admission. Other bound assignment modes stay closed.
contract StreamRevenueResolver is
    IStreamRevenueResolver,
    IStreamArtistPrimaryFacts,
    ERC165,
    Ownable
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

    IStreamSplitFactory public immutable splitFactoryContract;
    IStreamAssetPolicyRegistry private immutable _assetPolicyRegistry;
    bytes32 private immutable _splitWalletRuntimeCodeHash;
    address public immutable override core;
    address public immutable override artistRegistry;
    bytes32 public immutable override coreCodeHash;
    bytes32 public immutable override artistRegistryCodeHash;

    /// @notice Reverts when the configured split factory cannot support resolver invariants.
    error InvalidSplitFactory(address splitFactory);

    struct PrimaryTemplate {
        bool exists;
        bytes32 entriesHash;
        bytes32 metadataURIHash;
        PrimaryTemplateEntry[] entries;
    }

    struct PrimaryAssignment {
        bool exists;
        uint8 assignmentType;
        bytes32 profileId;
        bytes32 templateId;
        bytes32 policyHash;
        bool frozen;
    }

    struct PrimaryAssignmentHashInput {
        bytes32 revenueClass;
        uint8 scope;
        uint256 scopeId;
        uint8 assignmentType;
        bytes32 profileId;
        bytes32 templateId;
        bytes32 policyHash;
        bool frozen;
    }

    mapping(bytes32 => PrimaryTemplate) private _templates;
    mapping(bytes32 => PrimaryAssignment) private _primaryAssignments;

    /// @dev The explicit facade pin permits deployment before genesis installs Core pointers.
    ///      Assignment configuration still requires this facade to be selected by Core.
    constructor(
        IStreamCore core_,
        IStreamSplitFactory splitFactory_,
        address governanceExecutor_,
        IStreamArtistAttribution artistRegistry_
    ) {
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
        return id == type(IStreamArtistPrimaryFacts).interfaceId || super.supportsInterface(id);
    }

    /// @inheritdoc IStreamArtistPrimaryFacts
    function previewArtistPrimaryAssignment(
        uint256 collectionId,
        bytes32 profileHash,
        bytes32 policyHash,
        bool frozen
    ) external view override returns (StreamArtistOnboardingTypes.AssignmentFact memory fact) {
        _requireSelectedArtistRegistry();
        _requireScope(SCOPE_COLLECTION, collectionId);
        _resolveCollectionIdentity(collectionId, 0);
        if (policyHash != bytes32(0)) revert InvalidPrimaryPolicyHash();
        if (
            profileHash == bytes32(0) || !splitFactoryContract.profileExists(profileHash)
                || !splitFactoryContract.splitWalletExists(profileHash)
        ) revert UnverifiedSplitProfile(profileHash);
        bytes32 revenueClass = keccak256("PRIMARY_SALE");
        fact = StreamArtistOnboardingTypes.AssignmentFact(
            address(this),
            revenueClass,
            SCOPE_COLLECTION,
            collectionId,
            _primaryAssignmentHash(
                revenueClass,
                SCOPE_COLLECTION,
                collectionId,
                ASSIGNMENT_TYPE_PROFILE,
                profileHash,
                bytes32(0),
                policyHash,
                frozen
            )
        );
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
        (PrimaryTemplateEntry[] memory canonicalEntries, bytes32 entriesHash) =
            _canonicalizeTemplate(entries);
        templateId = keccak256(
            abi.encode(
                _PRIMARY_TEMPLATE_DOMAIN,
                uint256(block.chainid),
                address(this),
                SCHEMA_VERSION,
                TEMPLATE_VERSION,
                entriesHash,
                metadataURIHash
            )
        );

        PrimaryTemplate storage template = _templates[templateId];
        if (template.exists) {
            return templateId;
        }
        template.exists = true;
        template.entriesHash = entriesHash;
        template.metadataURIHash = metadataURIHash;
        for (uint256 i = 0; i < canonicalEntries.length; i++) {
            template.entries.push(canonicalEntries[i]);
        }

        emit PrimaryTemplateCreated(
            templateId, entriesHash, metadataURIHash, SCHEMA_VERSION, TEMPLATE_VERSION
        );
        for (uint256 i = 0; i < canonicalEntries.length; i++) {
            PrimaryTemplateEntry memory entry = canonicalEntries[i];
            emit PrimaryTemplateEntryRecorded(
                templateId,
                // Safe because MAX_TEMPLATE_ENTRIES is 64.
                // forge-lint: disable-next-line(unsafe-typecast)
                uint16(i),
                entry.account,
                entry.accountSource,
                entry.sharePpm,
                entry.labelId
            );
        }
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
        _requireMutableArtistScope(scope, scopeId);
        bytes32 key = _assignmentKey(revenueClass, scope, scopeId);
        PrimaryAssignment storage assignment = _primaryAssignments[key];
        if (!assignment.exists) {
            revert PrimaryAssignmentMissing(revenueClass, scope, scopeId);
        }
        if (assignment.frozen) {
            revert PrimaryAssignmentFrozen(revenueClass, scope, scopeId);
        }
        bytes32 previousHash = _assignmentHash(revenueClass, scope, scopeId, assignment);
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
        if (scope == SCOPE_COLLECTION && revenueClass == keccak256("PRIMARY_SALE")) {
            _requireSelectedArtistRegistry();
        } else {
            _requireMutableArtistScope(scope, scopeId);
        }
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
        _requireSelectedArtistRegistry();
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
                && IStreamArtistAttribution(artistRegistry).attribution(collectionId).nominationHash
                    != bytes32(0)
                && (!resolved.exists
                    || resolved.scope != SCOPE_COLLECTION
                    || resolved.scopeId != collectionId
                    || resolved.assignmentType != ASSIGNMENT_TYPE_PROFILE)
        ) revert UnsupportedArtistPrimaryAssignment(collectionId);
    }

    /// @notice Materializes a dynamic template into a deterministic split profile.
    function materializePrimaryProfile(bytes32 templateId, address salePoster)
        external
        override
        returns (bytes32 profileId, address wallet, bytes32 entriesHash)
    {
        PrimaryTemplate storage template = _templates[templateId];
        if (!template.exists) {
            revert UnknownPrimaryTemplate(templateId);
        }

        IStreamSplitWallet.SplitEntry[] memory concreteEntries =
            new IStreamSplitWallet.SplitEntry[](template.entries.length);
        for (uint256 i = 0; i < template.entries.length; i++) {
            PrimaryTemplateEntry storage templateEntry = template.entries[i];
            address account = templateEntry.account;
            if (account == address(0)) {
                if (templateEntry.accountSource != ACCOUNT_SOURCE_SALE_POSTER) {
                    revert UnsupportedAccountSource(templateEntry.accountSource);
                }
                account = salePoster;
                if (account == address(0)) {
                    revert InvalidMaterializedAccount(templateEntry.accountSource);
                }
            }
            concreteEntries[i] = IStreamSplitWallet.SplitEntry({
                account: account, sharePpm: templateEntry.sharePpm, labelId: templateEntry.labelId
            });
        }
        concreteEntries = _canonicalizeConcreteEntries(concreteEntries);
        entriesHash = keccak256(abi.encode(concreteEntries));
        bytes32 metadataURIHash = keccak256(
            abi.encode(
                _MATERIALIZED_PROFILE_METADATA_DOMAIN,
                uint256(block.chainid),
                address(this),
                templateId,
                entriesHash
            )
        );

        (profileId, wallet) = splitFactoryContract.createProfile(concreteEntries, metadataURIHash);
        emit PrimaryTemplateMaterialized(
            templateId, profileId, wallet, entriesHash, metadataURIHash, salePoster
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
        _requireArtistEconomics(revenueClass, scope, scopeId, assignmentType, assignmentHash);
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
        PrimaryAssignmentHashInput memory input;
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

    function _primaryAssignmentHash(PrimaryAssignmentHashInput memory input)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                _PRIMARY_ASSIGNMENT_DOMAIN,
                uint256(block.chainid),
                _assignmentResolverContextHash(),
                _assignmentScopeContextHash(
                    input.revenueClass, input.scope, input.scopeId, input.assignmentType
                ),
                _assignmentPointerContextHash(
                    input.assignmentType, input.profileId, input.templateId
                ),
                input.policyHash,
                input.frozen
            )
        );
    }

    function _assignmentResolverContextHash() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_DOMAIN,
                address(this),
                address(splitFactoryContract),
                address(_assetPolicyRegistry),
                _splitWalletRuntimeCodeHash
            )
        );
    }

    function _assignmentScopeContextHash(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        uint8 assignmentType
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_DOMAIN,
                revenueClass,
                scope,
                scopeId,
                assignmentType
            )
        );
    }

    function _assignmentPointerContextHash(
        uint8 assignmentType,
        bytes32 profileId,
        bytes32 templateId
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _PRIMARY_ASSIGNMENT_POINTER_CONTEXT_DOMAIN,
                profileId,
                _assignmentProfileContextHash(assignmentType, profileId),
                templateId,
                _assignmentTemplateContextHash(assignmentType, templateId)
            )
        );
    }

    function _assignmentProfileContextHash(uint8 assignmentType, bytes32 profileId)
        private
        view
        returns (bytes32)
    {
        if (assignmentType != ASSIGNMENT_TYPE_PROFILE || profileId == bytes32(0)) {
            return bytes32(0);
        }
        return keccak256(
            abi.encode(
                _PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_DOMAIN,
                _assignmentWallet(assignmentType, profileId),
                _assignmentProfileEntriesHash(assignmentType, profileId),
                _assignmentProfileMetadataURIHash(assignmentType, profileId)
            )
        );
    }

    function _assignmentTemplateContextHash(uint8 assignmentType, bytes32 templateId)
        private
        view
        returns (bytes32)
    {
        if (assignmentType != ASSIGNMENT_TYPE_TEMPLATE || templateId == bytes32(0)) {
            return bytes32(0);
        }
        return keccak256(
            abi.encode(
                _PRIMARY_ASSIGNMENT_TEMPLATE_CONTEXT_DOMAIN,
                _assignmentTemplateEntriesHash(assignmentType, templateId),
                _assignmentTemplateMetadataURIHash(assignmentType, templateId)
            )
        );
    }

    function _assignmentWallet(uint8 assignmentType, bytes32 profileId)
        private
        view
        returns (address)
    {
        if (assignmentType != ASSIGNMENT_TYPE_PROFILE || profileId == bytes32(0)) {
            return address(0);
        }
        return splitFactoryContract.walletFor(profileId);
    }

    function _assignmentProfileEntriesHash(uint8 assignmentType, bytes32 profileId)
        private
        view
        returns (bytes32)
    {
        if (assignmentType != ASSIGNMENT_TYPE_PROFILE || profileId == bytes32(0)) {
            return bytes32(0);
        }
        return splitFactoryContract.profileEntriesHash(profileId);
    }

    function _assignmentProfileMetadataURIHash(uint8 assignmentType, bytes32 profileId)
        private
        view
        returns (bytes32)
    {
        if (assignmentType != ASSIGNMENT_TYPE_PROFILE || profileId == bytes32(0)) {
            return bytes32(0);
        }
        return splitFactoryContract.profileMetadataURIHash(profileId);
    }

    function _assignmentTemplateEntriesHash(uint8 assignmentType, bytes32 templateId)
        private
        view
        returns (bytes32)
    {
        if (assignmentType != ASSIGNMENT_TYPE_TEMPLATE || templateId == bytes32(0)) {
            return bytes32(0);
        }
        return _templates[templateId].entriesHash;
    }

    function _assignmentTemplateMetadataURIHash(uint8 assignmentType, bytes32 templateId)
        private
        view
        returns (bytes32)
    {
        if (assignmentType != ASSIGNMENT_TYPE_TEMPLATE || templateId == bytes32(0)) {
            return bytes32(0);
        }
        return _templates[templateId].metadataURIHash;
    }

    function _canonicalizeTemplate(PrimaryTemplateEntry[] calldata entries)
        private
        pure
        returns (PrimaryTemplateEntry[] memory canonicalEntries, bytes32 entriesHash)
    {
        uint256 length = entries.length;
        if (length == 0 || length > MAX_TEMPLATE_ENTRIES) {
            revert InvalidPrimaryTemplateEntry(length);
        }
        canonicalEntries = new PrimaryTemplateEntry[](length);
        for (uint256 i = 0; i < length; i++) {
            canonicalEntries[i] = entries[i];
        }
        _sortTemplateEntries(canonicalEntries);

        uint256 totalShare = 0;
        uint256 dynamicSourceCount = 0;
        bytes32[MAX_DYNAMIC_ACCOUNT_SOURCES] memory dynamicSources;
        for (uint256 i = 0; i < length; i++) {
            PrimaryTemplateEntry memory entry = canonicalEntries[i];
            bool hasAccount = entry.account != address(0);
            bool hasSource = entry.accountSource != bytes32(0);
            if (hasAccount == hasSource || entry.sharePpm == 0) {
                revert InvalidPrimaryTemplateEntry(i);
            }
            if (i != 0 && _sameTemplateIdentity(canonicalEntries[i - 1], entry)) {
                revert InvalidPrimaryTemplateEntry(i);
            }
            if (hasSource) {
                if (entry.accountSource != ACCOUNT_SOURCE_SALE_POSTER) {
                    revert UnsupportedAccountSource(entry.accountSource);
                }
                bool seen = false;
                for (uint256 j = 0; j < dynamicSourceCount; j++) {
                    if (dynamicSources[j] == entry.accountSource) {
                        seen = true;
                        break;
                    }
                }
                if (!seen) {
                    if (dynamicSourceCount == MAX_DYNAMIC_ACCOUNT_SOURCES) {
                        revert InvalidPrimaryTemplateEntry(i);
                    }
                    dynamicSources[dynamicSourceCount] = entry.accountSource;
                    dynamicSourceCount++;
                }
            }
            totalShare += entry.sharePpm;
        }
        if (totalShare != SHARE_DENOMINATOR_PPM) {
            revert InvalidPrimaryTemplateTotal(totalShare);
        }
        entriesHash = keccak256(abi.encode(canonicalEntries));
    }

    function _canonicalizeConcreteEntries(IStreamSplitWallet.SplitEntry[] memory entries)
        private
        pure
        returns (IStreamSplitWallet.SplitEntry[] memory canonicalEntries)
    {
        _sortSplitEntries(entries);
        uint256 uniqueCount = 0;
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                i == 0 || entries[i].account != entries[i - 1].account
                    || entries[i].labelId != entries[i - 1].labelId
            ) {
                uniqueCount++;
            }
        }
        canonicalEntries = new IStreamSplitWallet.SplitEntry[](uniqueCount);
        uint256 cursor = 0;
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                i == 0 || entries[i].account != entries[i - 1].account
                    || entries[i].labelId != entries[i - 1].labelId
            ) {
                if (i != 0) {
                    cursor++;
                }
                canonicalEntries[cursor] = entries[i];
            } else {
                canonicalEntries[cursor].sharePpm += entries[i].sharePpm;
            }
        }
    }

    function _sortTemplateEntries(PrimaryTemplateEntry[] memory entries) private pure {
        for (uint256 i = 1; i < entries.length; i++) {
            PrimaryTemplateEntry memory current = entries[i];
            uint256 j = i;
            while (j > 0 && _templateEntryLess(current, entries[j - 1])) {
                entries[j] = entries[j - 1];
                j--;
            }
            entries[j] = current;
        }
    }

    function _templateEntryLess(PrimaryTemplateEntry memory left, PrimaryTemplateEntry memory right)
        private
        pure
        returns (bool)
    {
        if (left.account != right.account) {
            return uint160(left.account) < uint160(right.account);
        }
        if (left.accountSource != right.accountSource) {
            return uint256(left.accountSource) < uint256(right.accountSource);
        }
        if (left.labelId != right.labelId) {
            return uint256(left.labelId) < uint256(right.labelId);
        }
        return left.sharePpm < right.sharePpm;
    }

    function _sameTemplateIdentity(
        PrimaryTemplateEntry memory left,
        PrimaryTemplateEntry memory right
    ) private pure returns (bool) {
        return left.account == right.account && left.accountSource == right.accountSource
            && left.labelId == right.labelId;
    }

    function _sortSplitEntries(IStreamSplitWallet.SplitEntry[] memory entries) private pure {
        for (uint256 i = 1; i < entries.length; i++) {
            IStreamSplitWallet.SplitEntry memory current = entries[i];
            uint256 j = i;
            while (j > 0 && _splitEntryLess(current, entries[j - 1])) {
                entries[j] = entries[j - 1];
                j--;
            }
            entries[j] = current;
        }
    }

    function _splitEntryLess(
        IStreamSplitWallet.SplitEntry memory left,
        IStreamSplitWallet.SplitEntry memory right
    ) private pure returns (bool) {
        if (left.account != right.account) {
            return uint160(left.account) < uint160(right.account);
        }
        if (left.labelId != right.labelId) {
            return uint256(left.labelId) < uint256(right.labelId);
        }
        return left.sharePpm < right.sharePpm;
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

    /// @dev The consent read happens before any assignment write. A bound collection's
    ///      unsupported token/template/other-class mutations remain unavailable.
    function _requireArtistEconomics(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        uint8 assignmentType,
        bytes32 assignmentHash
    ) private view {
        if (scope == SCOPE_DEFAULT) return;
        uint256 collectionId = scope == SCOPE_COLLECTION
            ? _resolveCollectionIdentity(scopeId, 0)
            : _resolveCollectionIdentity(0, scopeId);
        if (
            IStreamArtistAttribution(artistRegistry).attribution(collectionId).nominationHash
                == bytes32(0)
        ) return;
        if (
            scope != SCOPE_COLLECTION || assignmentType != ASSIGNMENT_TYPE_PROFILE
                || revenueClass != keccak256("PRIMARY_SALE")
                || !IERC165(artistRegistry)
                    .supportsInterface(type(IStreamArtistEconomicsAuthority).interfaceId)
        ) revert PrimaryArtistConsentRequired(collectionId);
        IStreamArtistEconomicsAuthority(artistRegistry)
            .requireEconomicsConsent(collectionId, revenueClass, scope, scopeId, assignmentHash);
    }

    function _requireSelectedArtistRegistry() private view {
        if (core.codehash != coreCodeHash) revert InvalidPrimaryResolverConfiguration();
        (address selected, bytes32 selectedCodeHash,,,,,,,,) =
            IStreamCore(core).getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (
            selected != artistRegistry || selected.codehash != artistRegistryCodeHash
                || selectedCodeHash != artistRegistryCodeHash
                || IStreamArtistAttribution(selected).core() != core
        ) revert InvalidPrimaryArtistRegistry(selected);
    }

    function _requireMutableArtistScope(uint8 scope, uint256 scopeId) private view {
        _requireSelectedArtistRegistry();
        if (scope == SCOPE_DEFAULT) return;
        uint256 collectionId = scope == SCOPE_COLLECTION
            ? _resolveCollectionIdentity(scopeId, 0)
            : _resolveCollectionIdentity(0, scopeId);
        if (
            IStreamArtistAttribution(artistRegistry).attribution(collectionId).nominationHash
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
        collectionId = suppliedCollectionId;
        if (tokenId != 0) {
            (bool exists, uint256 mappedCollection,,) =
                IStreamCore(core).tokenCollectionIdentity(tokenId);
            if (
                !exists || mappedCollection == 0
                    || (collectionId != 0 && collectionId != mappedCollection)
            ) {
                revert InvalidPrimaryTokenIdentity(tokenId, suppliedCollectionId);
            }
            collectionId = mappedCollection;
        }
        if (collectionId != 0 && !IStreamCore(core).collectionExists(collectionId)) {
            revert InvalidPrimaryCollection(collectionId);
        }
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
