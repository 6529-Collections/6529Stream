// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArchivalTypes as A } from "./StreamArchivalTypes.sol";

/// @notice Versioned actual-byte chunks and invalidation state for bounded artifact coverage.
interface IStreamArchivalChunkCoverage {
    error ArchivalValidationEpochOverflow();
    event ArchivalChunkEnvelopeRecorded(
        uint16 schemaVersion,
        bytes32 indexed envelopeHash,
        address indexed pointer,
        bytes32 codeHash
    );
    event ArchivalValidationEpochAdvanced(uint16 schemaVersion, uint64 epoch);

    function recordChunkEnvelope(A.Envelope calldata envelope, address pointer)
        external
        returns (bytes32 envelopeHash);
    function chunkEnvelopePointer(bytes32 envelopeHash)
        external
        view
        returns (address pointer, bytes32 codeHash);
    function coverageValidationEpoch() external view returns (uint64);
    /// @notice Fresh canonical Core/artist/provider/checkpoint binding, without replaying old signatures.
    function requireCoverageEnvironment() external view returns (bytes32 environmentHash);
}
