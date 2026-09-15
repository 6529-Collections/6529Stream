// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./StreamRightsRecordTypes.sol";

/// @notice Authorized current rights selection with immutable original record history.
/// @dev This auxiliary does not publish records, grant rights or establish legal ownership.
interface IStreamRightsRecordSelection is IERC165 {
    struct Selection {
        bytes32 recordHash;
        bytes32 predecessor;
        bytes32 payloadHash;
        address selector;
        uint256 grantScope;
        uint64 grantRevision;
        uint64 revision;
        uint64 recordIndex;
        uint64 selectedAt;
        uint8 authorizationClass;
        address recorder;
        uint8 recorderAuthorizationClass;
        bytes32 artistIdentityRecordHash;
        bytes32 selectionHash;
    }

    error InvalidRightsConfiguration();
    error RightsDependencyChanged(address dependency);
    error RightsDependencyReadFailed(address dependency);
    error RightsHostNotSelected();
    error RightsDefinitionUnavailable(bytes32 documentId);
    error InvalidRightsRecord(bytes32 recordHash);
    error RightsSelectionAuthorityRequired();
    error RightsSelectionConflict();

    event RightsRecordSelected(
        uint256 indexed collectionId,
        bytes32 indexed subjectId,
        bytes32 indexed recordHash,
        Selection selection
    );

    function core() external view returns (address);
    function metadata() external view returns (address);
    function schemaRegistry() external view returns (address);
    function chunkStore() external view returns (address);
    function deploymentChainId() external view returns (uint256);

    /// @notice Select an existing record using the caller's current RIGHTS-family grant.
    /// @dev The witness must reproduce every stored JSON byte. A new selection requires
    ///      the exact old head/revision and advances original record order and predecessor.
    function selectCurrent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        StreamRightsRecordTypes.Statement calldata witness
    ) external returns (Selection memory);

    /// @notice Durable selected state; later revocation or definition retirement does not erase it.
    /// @dev Use requireCurrent for new consuming operations, which checks current dependencies.
    function currentRights(uint256 collectionId, bytes32 subjectId)
        external
        view
        returns (Selection memory);

    /// @notice Every original selection remains addressable by its one-based revision.
    function rightsSelectionAt(uint256 collectionId, bytes32 subjectId, uint64 revision)
        external
        view
        returns (Selection memory);

    /// @notice Require the exact selected revision under the currently selected host/definitions.
    /// @dev Original publisher and selector grant revocation do not invalidate historical facts.
    function requireCurrent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedRecord,
        uint64 expectedRevision
    ) external view returns (Selection memory);
}
