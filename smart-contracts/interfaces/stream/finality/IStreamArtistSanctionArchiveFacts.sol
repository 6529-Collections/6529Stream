// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact immutable byte identity produced from a recorded sanction and its retained evidence.
interface IStreamArtistSanctionArchiveFacts {
    struct Facts {
        bytes32 sanctionRecordHash;
        bytes32 artistId;
        bytes32 schemaId;
        bytes32 canonicalizationId;
        bytes32 contentHash;
        uint64 byteLength;
    }

    /// @dev This historical read does not grant current authority or assert present archival health.
    ///      Unknown records revert. Finality separately verifies the saved sanction for its current subject.
    function sanctionArchiveFacts(bytes32 sanctionRecordHash) external view returns (Facts memory);
}
