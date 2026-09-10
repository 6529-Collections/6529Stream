// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct StreamStateExportRecord {
    uint256 blockNumber;
    bytes32 blockHash;
    bytes32 exportHash;
    bytes32 manifestHash;
    string manifestURI;
    uint256 sequence;
}

/// @notice Historical state-export discovery remains available after publisher replacement.
interface IStreamStateExportHistory {
    /// @notice An immutable published claim and its optional forward supersession link.
    /// @dev Unknown hashes return a zero record; sequence numbers start at one.
    function stateExport(bytes32 exportHash)
        external
        view
        returns (StreamStateExportRecord memory record, bytes32 supersededBy);

    function stateExportCount() external view returns (uint256);

    /// @notice Published hash at the zero-based append index; out-of-range indices revert.
    function stateExportHashAt(uint256 index) external view returns (bytes32);

    function stateExportChallengeExists(bytes32 exportHash, bytes32 challengeHash)
        external
        view
        returns (bool);
}
