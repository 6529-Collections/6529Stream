// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./IStreamRevealFeeEscrow.sol";

/// @notice Explicit collection entropy and render requirements, independent of renderer labels.
/// @dev Additive capability. Original configuration tuples and permanent interfaces are unchanged.
interface IStreamEntropyCollectionPolicy is IERC165 {
    enum Mode {
        DISABLED,
        INSTANT,
        ASYNC
    }
    enum SecurityClass {
        HIGH_ASSURANCE,
        LOW_SECURITY
    }
    enum RenderRequirement {
        REQUIRED,
        NOT_REQUIRED
    }

    struct PolicyInput {
        Mode mode;
        SecurityClass securityClass;
        RenderRequirement renderRequirement;
        address provider;
        bytes32 collectionSalt;
        bool publicRequests;
        uint64 timeoutBlocks;
        IStreamRevealFeeEscrow.CollectionRevealPolicy reveal;
        uint16 maxFreshRecoveryAttempts;
        bytes32 recoveryPolicyId;
    }

    struct PolicyRecord {
        bool configured;
        bool explicitPolicy;
        bool frozen;
        Mode mode;
        SecurityClass securityClass;
        RenderRequirement renderRequirement;
        uint64 revision;
        uint32 providerEpoch;
        bytes32 policyHash;
        bytes32 contentStateHash;
        bytes32 lastActionId;
        bytes32 artistConsentRecord;
    }

    error InvalidCollectionPolicy(uint256 collectionId);
    error UnsupportedEntropyMode(Mode mode);
    error ExplicitCollectionPolicyRequired(uint256 collectionId);
    error CollectionPolicyReplay(bytes32 record);
    error CollectionPolicyArtistRequired(uint256 collectionId);
    error CollectionPolicyDependency(address target);
    error CollectionPolicyEscrowOutstanding(uint256 collectionId);

    event CollectionEntropyPolicyConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed policyHash,
        uint64 revision,
        uint32 providerEpoch,
        PolicyInput policy,
        bytes32 providerCodeHash,
        bytes32 providerConfigHash,
        bytes32 recoveryPolicyHash,
        bytes32 actionId,
        bytes32 artistConsentRecord
    );
    event CollectionEntropyPolicyFrozen(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed policyHash,
        uint64 revision,
        bytes32 actionId,
        bytes32 artistConsentRecord
    );
    event TokenEntropyPolicyRegistered(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bytes32 indexed policyHash,
        uint8 status
    );

    /// @notice Requires an already-bound Artist, exact op17 consent and executing governance action.
    function configureCollectionEntropyPolicy(uint256 collectionId, PolicyInput calldata policy)
        external;
    /// @notice Undeclared original configurations resolve to legacy ASYNC/REQUIRED/HIGH_ASSURANCE.
    function collectionEntropyPolicy(uint256 collectionId)
        external
        view
        returns (PolicyRecord memory);
    /// @notice The fourth word is the exact op17 newStateHash; operational fee is excluded from it.
    function collectionEntropyPolicyTransition(uint256 collectionId, PolicyInput calldata policy)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 artistContentStateHash);
    function freezeCollectionEntropyPolicy(uint256 collectionId) external;
    function freezeCollectionEntropyPolicyTransition(uint256 collectionId)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 artistContentStateHash);
}
