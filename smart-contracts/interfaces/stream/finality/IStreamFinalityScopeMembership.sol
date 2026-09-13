// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./IStreamFinalityRecoveryScopeEvidence.sol";
import "./StreamScopeMembershipTypes.sol";
import "../metadata/IStreamCollectionMetadataV1.sol";

/// @notice Fixed, record-authenticated scope membership shared by Router and finality consumers.
/// @dev Scope publication establishes metadata provenance, not artist or recovery authorization.
interface IStreamFinalityScopeMembership is IERC165, IStreamFinalityRecoveryScopeEvidence {
    struct Publication {
        bytes32 recordHash;
        bytes32 manifestHash;
        bytes32 schemaId;
        bytes32 canonicalizationId;
        address payloadPointer;
        bytes32 payloadCodeHash;
        uint64 effectiveAt;
        IStreamCollectionMetadataV1.RecordReceipt receipt;
    }

    struct Progress {
        bool exists;
        bool complete;
        uint256 processedTokens;
        uint256 totalTokens;
        uint256 processedParts;
        uint256 totalParts;
    }

    error InvalidScopeMembershipConfiguration();
    error ScopeMembershipDependencyChanged(address target);
    error ScopeMembershipReadFailed(address target, bytes4 selector);
    error ScopeMembershipParentGas(uint256 available, uint256 required);
    error InvalidScopeMembershipRecord(bytes32 recordHash);
    error ScopeMembershipUnknown(bytes32 scopeId);
    error ScopeMembershipIncomplete(bytes32 scopeId);
    error ScopeMembershipPartInvalid(uint256 index);
    error ScopeMembershipTokenInvalid(uint256 tokenId);
    error ScopeMembershipIndexOutOfBounds(uint256 index);
    error ScopeMembershipProgressInvalid();

    event ScopeMembershipAdmitted(
        bytes32 indexed scopeId,
        uint256 indexed collectionId,
        uint8 indexed scopeType,
        bytes32 recordHash,
        bytes32 manifestHash,
        bytes32 tokenListHash,
        uint256 tokenCount,
        address recorder,
        uint8 authorizationClass
    );
    event ScopeMembershipProgressed(
        bytes32 indexed scopeId, uint256 processedParts, uint256 processedTokens
    );
    event ScopeMembershipSealed(
        bytes32 indexed scopeId, bytes32 membershipHash, uint256 tokenCount
    );

    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function tokenInventory() external view returns (address);

    /// @notice Authenticate a retained record and derive its unique scope. No caller authority is added.
    function beginScopeMembership(bytes32 recordHash)
        external
        returns (StreamFinalityScope memory scope);
    /// @notice Validate exact next parts and seal only the full committed list; all progress is atomic.
    function continueScopeMembership(StreamFinalityScope calldata scope, uint256 maximumParts)
        external;

    /// @notice Historical progress and original publication; neither getter asserts current validity.
    function scopeMembershipProgress(StreamFinalityScope calldata scope)
        external
        view
        returns (Progress memory);
    function scopeMembershipPublication(StreamFinalityScope calldata scope)
        external
        view
        returns (Publication memory);

    /// @notice Validating read with fixed-runtime/source pins and exact scope membership.
    function requireScopeMembership(StreamFinalityScope calldata scope)
        external
        view
        returns (StreamScopeMembershipFacts memory);
    function scopeTokenAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        returns (uint256);
    function scopeCoversToken(StreamFinalityScope calldata scope, uint256 tokenId)
        external
        view
        returns (bool);
}
