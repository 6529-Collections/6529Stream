// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";

/// @notice OwnerRecords-owned action/scope/manifest notice evidence from ADR0020.
/// @dev Selector and interface ID are 0x20279cd8. The producer authenticates the
///      notice and its full 72-hour interval; the consumer validates the exact
///      six-word result and snapshots it only during recovery execution.
interface IStreamFinalityRecoveryOwnerEvidence {
    function verifyRecoveryOwnerEvidence(
        StreamFinalityScope calldata scope,
        bytes32 recoveryId,
        bytes32 recoveryManifestHash
    )
        external
        view
        returns (
            bool valid,
            bytes32 evidenceHash,
            uint64 revision,
            uint64 ownerNoticeEndsAt,
            uint32 acknowledgementCount,
            uint32 objectionCount
        );
}
