// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Original apply evidence omitted from the V3 Payout read interface.
/// @dev The recovered collector enumerates these keys through the complete continuation chain.
interface IStreamArtistRecoveredPayoutHydration {
    function payoutRecoveryAppliedCommitmentV3(bytes32 recoveryRecordHash)
        external
        view
        returns (bytes32);
}
