// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamRightsRecordSelection.sol";
import "../preservation/IStreamPreservationRecords.sol";

/// @notice Bounded selection using an authenticated complete original record witness.
/// @dev Additive entrypoint retains the original selection interface and authority rules.
interface IStreamRightsRecordWitnessSelection {
    struct Witness {
        IStreamPreservationRecords.CollectionRecord original;
        StreamRightsRecordTypes.Statement statement;
    }

    function selectCurrentWithRecord(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        Witness calldata witness
    ) external returns (IStreamRightsRecordSelection.Selection memory);
}
