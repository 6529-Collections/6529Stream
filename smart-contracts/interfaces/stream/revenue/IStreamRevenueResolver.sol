// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamSplitWallet.sol";

/// @notice Interface for outside-Core primary revenue assignment resolution.
interface IStreamRevenueResolver {
    /// @notice Template entry before dynamic account sources are materialized.
    struct PrimaryTemplateEntry {
        address account;
        bytes32 accountSource;
        uint32 sharePpm;
        bytes32 labelId;
    }

    /// @notice Resolved assignment selected for a primary sale context.
    struct ResolvedPrimaryAssignment {
        bool exists;
        uint8 scope;
        uint256 scopeId;
        uint8 assignmentType;
        bytes32 profileId;
        bytes32 templateId;
        bytes32 policyHash;
        bytes32 assignmentHash;
        bool frozen;
    }

    /// @notice Reverts when a revenue class is zero.
    error InvalidRevenueClass(bytes32 revenueClass);
    /// @notice Reverts when an assignment scope is unsupported or has invalid identity.
    error InvalidAssignmentScope(uint8 scope, uint256 scopeId);
    /// @notice Reverts when an assignment type is unsupported.
    error InvalidAssignmentType(uint8 assignmentType);
    /// @notice This implementation supports only the canonical zero no-loosening policy.
    error InvalidPrimaryPolicyHash();
    error InvalidPrimaryResolverConfiguration();
    error InvalidPrimaryArtistRegistry(address selected);
    error InvalidPrimaryCollection(uint256 collectionId);
    error InvalidPrimaryTokenIdentity(uint256 tokenId, uint256 suppliedCollectionId);
    error PrimaryArtistConsentRequired(uint256 collectionId);
    error UnsupportedArtistPrimaryAssignment(uint256 collectionId);
    /// @notice Reverts when a split profile is unknown or lacks a verified wallet.
    error UnverifiedSplitProfile(bytes32 profileId);
    /// @notice Reverts when a template entry is invalid.
    error InvalidPrimaryTemplateEntry(uint256 index);
    /// @notice Reverts when template shares do not sum to the share denominator.
    error InvalidPrimaryTemplateTotal(uint256 totalSharePpm);
    /// @notice Reverts when the template does not exist.
    error UnknownPrimaryTemplate(bytes32 templateId);
    /// @notice Reverts when a dynamic account source is unsupported.
    error UnsupportedAccountSource(bytes32 accountSource);
    /// @notice Reverts when a dynamic account source materializes to zero.
    error InvalidMaterializedAccount(bytes32 accountSource);
    error MissingArtistMaterializationContext();
    error UnresolvableArtistBeneficiary(uint256 collectionId);
    error InsufficientArtistBeneficiaryGas(uint256 requiredCap, uint256 available);
    /// @notice Reverts when a frozen assignment would be changed or cleared.
    error PrimaryAssignmentFrozen(bytes32 revenueClass, uint8 scope, uint256 scopeId);
    /// @notice Reverts when freezing a missing assignment.
    error PrimaryAssignmentMissing(bytes32 revenueClass, uint8 scope, uint256 scopeId);

    /// @notice Emitted once when a primary split template is created.
    event PrimaryTemplateCreated(
        bytes32 indexed templateId,
        bytes32 indexed entriesHash,
        bytes32 indexed metadataURIHash,
        uint16 schemaVersion,
        uint16 templateVersion
    );
    /// @notice Emitted for each canonical template entry.
    event PrimaryTemplateEntryRecorded(
        bytes32 indexed templateId,
        uint16 indexed index,
        address indexed account,
        bytes32 accountSource,
        uint32 sharePpm,
        bytes32 labelId
    );
    /// @notice Emitted when a primary assignment is set.
    event PrimaryAssignmentSet(
        bytes32 indexed revenueClass,
        uint8 indexed scope,
        uint256 indexed scopeId,
        uint8 assignmentType,
        bytes32 profileId,
        bytes32 templateId,
        bytes32 policyHash,
        bytes32 assignmentHash,
        address admin
    );
    /// @notice Emitted when a primary assignment is cleared.
    event PrimaryAssignmentCleared(
        bytes32 indexed revenueClass,
        uint8 indexed scope,
        uint256 indexed scopeId,
        bytes32 previousAssignmentHash,
        address admin
    );
    /// @notice Emitted when a primary assignment is frozen against later mutation.
    event PrimaryAssignmentFrozenEvent(
        bytes32 indexed revenueClass,
        uint8 indexed scope,
        uint256 indexed scopeId,
        bytes32 previousAssignmentHash,
        bytes32 frozenAssignmentHash,
        address admin
    );
    /// @notice Emitted when a dynamic template is materialized into a fixed split profile.
    event PrimaryTemplateMaterialized(
        bytes32 indexed templateId,
        bytes32 indexed profileId,
        address indexed wallet,
        bytes32 entriesHash,
        bytes32 metadataURIHash,
        address salePoster
    );

    /// @notice Current-read witness for a public cache operation, never official sale evidence.
    event CollectionTemplateMaterialized(
        bytes32 indexed templateId,
        bytes32 indexed profileId,
        uint256 indexed collectionId,
        uint16 schemaVersion,
        bytes32 artistId,
        address payoutAccount,
        bytes32 designationRecordHash,
        address wallet,
        bytes32 entriesHash,
        bool walletDeployed
    );

    /// @notice Default resolver scope.
    function SCOPE_DEFAULT() external pure returns (uint8);
    /// @notice Collection resolver scope.
    function SCOPE_COLLECTION() external pure returns (uint8);
    /// @notice Token resolver scope.
    function SCOPE_TOKEN() external pure returns (uint8);
    /// @notice Fixed split profile assignment type.
    function ASSIGNMENT_TYPE_PROFILE() external pure returns (uint8);
    /// @notice Dynamic primary template assignment type.
    function ASSIGNMENT_TYPE_TEMPLATE() external pure returns (uint8);
    /// @notice Dynamic account source for the poster attached to a sale.
    function ACCOUNT_SOURCE_SALE_POSTER() external pure returns (bytes32);
    function ACCOUNT_SOURCE_COLLECTION_ARTIST() external pure returns (bytes32);
    function ARTIST_LABEL() external pure returns (bytes32);
    function ARTIST_BENEFICIARY_READ_GAS() external pure returns (bytes32);
    /// @notice The split factory used to verify and materialize profiles.
    function splitFactory() external view returns (address);
    /// @notice Permanent Core whose collection and token identity govern this resolver.
    function core() external view returns (address);
    /// @notice Explicit immutable facade pin, required to be Core-selected for assignment writes/resolution.
    function artistRegistry() external view returns (address);
    function coreCodeHash() external view returns (bytes32);
    function artistRegistryCodeHash() external view returns (bytes32);
    /// @notice Returns true for deployment validation.
    function isStreamRevenueResolver() external pure returns (bool);
    /// @notice Creates or reuses a primary split template.
    function createPrimaryTemplate(PrimaryTemplateEntry[] calldata entries, bytes32 metadataURIHash)
        external
        returns (bytes32 templateId);
    /// @notice Sets a fixed-profile primary assignment with zero no-loosening policy.
    /// @dev The current profile closes collection/token mutation at initial artist nomination.
    function setPrimaryProfileAssignment(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 profileId,
        bytes32 policyHash
    ) external returns (bytes32 assignmentHash);
    /// @notice Sets a zero-policy dynamic template before artist nomination.
    /// @dev Artist-bound collections currently require an explicit collection fixed profile.
    function setPrimaryTemplateAssignment(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 templateId,
        bytes32 policyHash
    ) external returns (bytes32 assignmentHash);
    /// @notice Clears a mutable primary assignment.
    function clearPrimaryAssignment(bytes32 revenueClass, uint8 scope, uint256 scopeId) external;
    /// @notice Freezes an existing primary assignment before artist nomination.
    function freezePrimaryAssignment(bytes32 revenueClass, uint8 scope, uint256 scopeId)
        external
        returns (bytes32 frozenAssignmentHash);
    /// @notice Resolves assignments against the pinned, currently Core-selected artist facade.
    /// @dev Nonzero token IDs must match Core's retained collection identity, including burns.
    ///      Artist-bound contexts support only explicit collection fixed profiles. This read
    ///      exposes current terms; it does not itself assert that artist consent was recorded.
    function resolvePrimaryAssignment(uint256 collectionId, uint256 tokenId, bytes32 revenueClass)
        external
        view
        returns (ResolvedPrimaryAssignment memory assignment);
    /// @notice Materializes a dynamic template into a deterministic split profile.
    function materializePrimaryProfile(bytes32 templateId, address salePoster)
        external
        returns (bytes32 profileId, address wallet, bytes32 entriesHash);
    /// @notice Collection-aware public cache; reads the currently accepted explicit artist payout.
    /// @dev Registration-only returns a predicted wallet, which is not proof of deployment.
    ///      This does not authorize TEMPLATE assignment or a sale; old fixed profiles keep their payees.
    function materializeCollectionPrimaryProfile(
        bytes32 templateId,
        uint256 collectionId,
        address salePoster,
        bool deployWallet
    ) external returns (bytes32 profileId, address wallet, bytes32 entriesHash);
    /// @notice Returns deterministic template metadata.
    function primaryTemplate(bytes32 templateId)
        external
        view
        returns (bool exists, bytes32 entriesHash, bytes32 metadataURIHash);
    /// @notice Returns the number of canonical entries in a template.
    function primaryTemplateEntryCount(bytes32 templateId) external view returns (uint256);
    /// @notice Returns one canonical template entry.
    function primaryTemplateEntry(bytes32 templateId, uint256 index)
        external
        view
        returns (address account, bytes32 accountSource, uint32 sharePpm, bytes32 labelId);
    /// @notice Computes a zero-policy assignment hash for explicit inputs, not a live selection.
    function primaryAssignmentHash(
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        uint8 assignmentType,
        bytes32 profileId,
        bytes32 templateId,
        bytes32 policyHash,
        bool frozen
    ) external view returns (bytes32);
}
